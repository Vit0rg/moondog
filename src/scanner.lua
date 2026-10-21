-- src/scanner.lua
ctx = ctx or {}
ctx.state = ctx.state or {}
ctx.state.results = ctx.state.results or {}
ctx.state.scroll_y = ctx.state.scroll_y or 0
ctx.state.scanned_file = ctx.state.scanned_file or ""

ctx.config = ctx.config or {}
ctx.config.platform = ctx.config.platform or "lua51"

local function trim(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Phase 1 guard: `ldod_module_call` overmatches function declarations.
-- Lua patterns have no lookbehind, so exclusions are resolved at the
-- line level. Declarations are never table lookups and are not findings.
local DECL_PATTERN = "^%s*(local%s+)?function[%w_%.:]*%s*%("

-- Phase 1 naive loop tracker. Whole-word keyword counting per line.
-- Ugly by design: false positives inside strings or comments are
-- acceptable until Sentinel and fixtures prove a better approach is needed.
-- Increment on: for, while, repeat. Decrement on: end, until.
local function count_matches(s, pat)
    local n = 0
    for _ in s:gmatch(pat) do
        n = n + 1
    end
    return n
end

local function loop_open_count(line)
    return count_matches(line, "%f[%w]for%f[%W]")
         + count_matches(line, "%f[%w]while%f[%W]")
         + count_matches(line, "%f[%w]repeat%f[%W]")
end

local function loop_close_count(line)
    return count_matches(line, "%f[%w]end%f[%W]")
         + count_matches(line, "%f[%w]until%f[%W]")
end

-- Harden: normalize the ruleset once per scan and resolve platform severities.
-- Guards against leading/trailing whitespace in rules.lua string fields.
-- Untrimmed patterns under-match (e.g. "table%.insert " would require a
-- trailing space that real code never has). Untrimmed msg/id/category
-- would otherwise pollute the JSON/TXT export and CLI output.
local function build_active_rules()
    local active = {}
    local platform = ctx.config.platform
    local profile = ctx.rule_profiles and ctx.rule_profiles[platform] or {}

    for _, rule in ipairs(ctx.rules or {}) do
        local id = trim(rule.id)

        -- Resolve severity: platform profile overrides the rule default.
        local severity = trim(rule.severity or "info")
        if id ~= "" and profile[id] then
            severity = trim(profile[id])
        end

        -- Profile opt-out: strip the pattern so the rule can never match.
        local pat = trim(rule.pattern or "")
        if severity == "ignore" then
            pat = ""
        end

        if pat ~= "" then
            local msg = trim(rule.msg)
            if msg == "" then
                msg = trim(rule.description)
            end
            if msg == "" then
                msg = "Performance anti-pattern detected."
            end

            active[#active + 1] = {
                pattern   = pat,
                severity  = severity,
                msg       = msg,
                id        = (id ~= "" and id or pat),
                category  = (trim(rule.category) ~= "" and trim(rule.category) or "Unknown"),
                -- Priority 3: loop-context rules are no longer stripped at
                -- build time. Gating moved to scan time via loop_depth.
                requires_loop = rule.requires_loop and true or false,
                guard_decl = (id == "ldod_module_call"),
            }
        end
    end
    return active
end

function ctx.scan_file(filepath)
    if ctx.sentinel and ctx.sentinel.start_phase then
        ctx.sentinel.start_phase("scan")
    end

    local findings = {}
    local file = io.open(filepath, "r")
    if not file then
        ctx.state.scanned_file = filepath
        ctx.state.results = findings
        ctx.state.scroll_y = 0
        if ctx.sentinel and ctx.sentinel.end_phase then ctx.sentinel.end_phase("scan") end
        return
    end

    local active_rules = build_active_rules()
    local line_num = 0
    local in_hotpath = false
    local loop_depth = 0

    for line in file:lines() do
        line_num = line_num + 1
        if line:find("%-%- @hotpath") then in_hotpath = true end
        if line:find("%-%- @coldpath") then in_hotpath = false end

        local is_decl = line:find(DECL_PATTERN) ~= nil
        loop_depth = loop_depth + loop_open_count(line)

        for _, rule in ipairs(active_rules) do
            local matched = line:find(rule.pattern) ~= nil
            if matched and rule.guard_decl and is_decl then matched = false end
            if matched and rule.requires_loop and loop_depth < 1 then matched = false end
            if matched then
                findings[#findings + 1] = {
                    line = line_num, severity = rule.severity, msg = rule.msg,
                    source = line, hot = in_hotpath, rule_id = rule.id, category = rule.category,
                }
            end
        end

        loop_depth = loop_depth - loop_close_count(line)
        if loop_depth < 0 then loop_depth = 0 end
    end
    file:close()

    ctx.state.scanned_file = filepath
    ctx.state.results = findings
    ctx.state.scroll_y = 0

    if ctx.sentinel and ctx.sentinel.end_phase then
        ctx.sentinel.end_phase("scan")
    end
end