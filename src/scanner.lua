-- src/scanner.lua

ctx = ctx or {}
ctx.state = ctx.state or {}

ctx.state.results = ctx.state.results or {}
ctx.state.scroll_y = ctx.state.scroll_y or 0
ctx.state.scanned_file = ctx.state.scanned_file or ""

local function trim(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Harden: normalize the ruleset once per scan.
-- Guards against leading/trailing whitespace in rules.lua string fields.
-- Untrimmed patterns under-match (e.g. "table%.insert " would require a
-- trailing space that real code never has). Untrimmed msg/id/category
-- would otherwise pollute the JSON/TXT export and CLI output.
local function build_active_rules()
    local active = {}

    for _, rule in ipairs(ctx.rules or {}) do
        local pat = trim(rule.pattern)

        if pat ~= "" then
            local id = trim(rule.id)
            local category = trim(rule.category)

            active[#active + 1] = {
                pattern  = pat,
                severity = trim(rule.severity or "info"),
                msg      = trim(rule.msg),
                id       = (id ~= "" and id or pat),
                category = (category ~= "" and category or "Unknown"),
            }
        end
    end

    return active
end

function ctx.scan_file(filepath)
    local findings = {}

    local file = io.open(filepath, "r")
    if not file then
        ctx.state.scanned_file = filepath
        ctx.state.results = findings
        ctx.state.scroll_y = 0
        return
    end

    local active_rules = build_active_rules()

    local line_num = 0
    local in_hotpath = false

    for line in file:lines() do
        line_num = line_num + 1

        if line:find("%-%- @hotpath") then
            in_hotpath = true
        end

        if line:find("%-%- @coldpath") then
            in_hotpath = false
        end

        for _, rule in ipairs(active_rules) do
            if line:find(rule.pattern) then
                findings[#findings + 1] = {
                    line     = line_num,
                    severity = rule.severity,
                    msg      = rule.msg,
                    source   = line,
                    hot      = in_hotpath,
                    rule_id  = rule.id,
                    category = rule.category,
                }
            end
        end
    end

    file:close()

    ctx.state.scanned_file = filepath
    ctx.state.results = findings
    ctx.state.scroll_y = 0
end