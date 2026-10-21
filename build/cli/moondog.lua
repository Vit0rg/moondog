-- ==========================================================
-- moondog: Lua Code-Smell Detector & Anti-Pattern Indicator
-- Paradigm: Hack and Harden (H2) / Lexical Data-Oriented Design (L-DOD)
-- Target: cli
-- Built: 2026-10-21T04:33:29Z
-- Manifest: scripts/manifests/cli_manifest.txt
-- ==========================================================

-- ==========================================================
-- AUTO-GENERATED CLI RUNTIME
-- Standardized ANSI Color Constants injected by Builder
-- ==========================================================
local ANSI_GREEN  = "\27[38;5;46m"
local ANSI_RED    = "\27[38;5;196m"
local ANSI_CYAN   = "\27[38;5;51m"
local ANSI_YELLOW = "\27[38;5;226m"
local ANSI_RESET  = "\27[0m"
local ANSI_DIM    = "\27[2m"
local ANSI_BOLD   = "\27[1m"
-- ==========================================
-- FILE: src/rules.lua
-- ==========================================

ctx = ctx or {}

ctx.config = ctx.config or {
    platform = "lua51"
}

ctx.rule_profiles = {
    lua51 = {
        ldod_hash_iteration = "critical",
        ldod_string_key_loop = "critical",
        ldod_table_remove_loop = "critical",
        ldod_coroutine_hotpath = "fatal",
        ldod_alloc_in_loop = "critical",
        ldod_module_call = "warning",
        ldod_upvalue_heavy_loop = "info"
    },
    lua54 = {
        ldod_hash_iteration = "warning",
        ldod_string_key_loop = "warning",
        ldod_table_remove_loop = "warning",
        ldod_coroutine_hotpath = "critical",
        ldod_alloc_in_loop = "warning",
        ldod_upvalue_heavy_loop = "ignore"
    },
    luajit = {
        ldod_coroutine_hotpath = "fatal",
        ldod_upvalue_heavy_loop = "warning",
        ldod_dynamic_key_concat = "critical",
        ldod_hash_iteration = "warning",
        ldod_module_call = "ignore",
        ldod_string_key_loop = "info"
    },
    luajit_openresty = {
        ldod_alloc_in_loop = "critical",
        ldod_coroutine_hotpath = "fatal",
        ldod_upvalue_heavy_loop = "warning",
        ldod_dynamic_key_concat = "critical",
        ldod_module_call = "ignore"
    }
}

ctx.rules = {
    -- ==========================================
    -- Legacy Rules (v0.2.0 baseline preserved)
    -- ==========================================
    {
        id = "table_insert",
        category = "Memory",
        pattern = "table%.insert%s*%(",
        requires_loop = false,
        severity = "warning",
        msg = "table.insert shifts elements (O(N)). Consider swap-and-pop.",
        description = "table.insert shifts elements (O(N)).",
        fix = "Consider swap-and-pop or Pool-Array-Map."
    },
    {
        id = "table_remove",
        category = "Algorithmic",
        pattern = "table%.remove%s*%(",
        requires_loop = false,
        severity = "critical",
        msg = "table.remove shifts elements (O(N)). Consider swap-and-pop.",
        description = "table.remove shifts elements (O(N)).",
        fix = "Consider swap-and-pop."
    },
    {
        id = "pairs_iteration",
        category = "Algorithmic",
        pattern = "for%s+.-%s+in%s+pairs%s*%(",
        requires_loop = false,
        severity = "info",
        msg = "pairs() incurs hash iteration overhead.",
        description = "pairs() incurs hash iteration overhead.",
        fix = "Prefer numeric for loops over flat arrays."
    },
    {
        id = "ipairs_iteration",
        category = "Algorithmic",
        pattern = "for%s+.-%s+in%s+ipairs%s*%(",
        requires_loop = false,
        severity = "info",
        msg = "ipairs() function call overhead.",
        description = "ipairs() function call overhead.",
        fix = "Prefer numeric for loops."
    },
    {
        id = "varargs",
        category = "Architecture",
        pattern = "%.%.%.",
        requires_loop = false,
        severity = "info",
        msg = "Varargs (...) allocation overhead.",
        description = "Varargs (...) allocation overhead.",
        fix = "Avoid in hot paths."
    },
    {
        id = "string_format",
        category = "Architecture",
        pattern = "string%.format%s*%(",
        requires_loop = false,
        severity = "warning",
        msg = "string.format allocates new strings.",
        description = "string.format allocates new strings.",
        fix = "Avoid in hot paths."
    },
    {
        id = "setmetatable",
        category = "Architecture",
        pattern = "setmetatable%s*%(",
        requires_loop = false,
        severity = "warning",
        msg = "setmetatable can break trace stability in JIT.",
        description = "setmetatable can break trace stability in JIT.",
        fix = "Apply metatables at instantiation, not in hot paths."
    },
    {
        id = "collectgarbage",
        category = "Architecture",
        pattern = "collectgarbage%s*%(",
        requires_loop = false,
        severity = "critical",
        msg = "collectgarbage forces GC pause.",
        description = "collectgarbage forces GC pause.",
        fix = "Do not call in hot paths."
    },
    {
        id = "hotpath_marker",
        category = "Marker",
        pattern = "--%s*@hotpath",
        requires_loop = false,
        severity = "info",
        msg = "Hot path marker detected.",
        description = "Hot path marker detected.",
        fix = "Optimize this block."
    },

    -- ==========================================
    -- Empirical L-DOD Rules (v0.3.0 Phase 1)
    -- ==========================================
    {
        id = "ldod_hash_iteration",
        category = "Algorithmic",
        pattern = "for%s+.-%s+in%s+pairs%s*%(",
        requires_loop = false,
        description = "pairs() incurs hash iteration overhead.",
        fix = "Prefer numeric for loops over flat arrays."
    },
    {
        id = "ldod_table_remove_loop",
        category = "Algorithmic",
        pattern = "table%.remove%s*%(",
        requires_loop = true,                                 -- Disabled until loop tracker exists
        description = "table.remove inside loop causes O(N^2) shifts.",
        fix = "Use swap-and-pop or defer removals."
    },
    {
        id = "ldod_coroutine_hotpath",
        category = "Architecture",
        pattern = "coroutine%.[a-z]+%s*%(",
        requires_loop = false,
        description = "Coroutine creation/resume overhead in hot paths.",
        fix = "Use persistent coroutines or direct function calls."
    },
    {
        id = "ldod_module_call",
        category = "Architecture",
        pattern = "[%w_]+%.[%w_]+%s*%(",
        requires_loop = false,                                  -- Broad Phase 1 pattern
        description = "Module table lookup overhead.",
        fix = "Cache module functions as upvalues locally."
    },
    {
        id = "ldod_dynamic_key_concat",
        category = "Memory",
        pattern = "%.%.%s*[%w_]+%s*%]%s*=",
        requires_loop = false,
        description = "Dynamic key concatenation allocates strings.",
        fix = "Use numeric IDs or cache string keys."
    },

    -- Loop-Context Rules (Disabled until Priority 3)
    {
        id = "ldod_alloc_in_loop",
        category = "Memory",
        pattern = "local%s+[%w_]+%s*=%s*{",
        requires_loop = true,
        description = "Table allocation inside loop causes GC pressure.",
        fix = "Pre-allocate or reuse tables."
    },
    {
        id = "ldod_string_key_loop",
        category = "Algorithmic",
        pattern = "[%w_]+%[[\"'][^\"']+[\"']%]",
        requires_loop = true,
        description = "String key lookup in loop incurs hashing overhead.",
        fix = "Use numeric indices or upvalues."
    },
    {
        id = "ldod_upvalue_heavy_loop",
        category = "Architecture",
        pattern = "function%s*%(",
        requires_loop = true,
        description = "Heavy upvalue access in loop.",
        fix = "Localize upvalues before the loop."
    }
}

-- ==========================================
-- FILE: src/scanner.lua
-- ==========================================
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
-- ==========================================
-- FILE: src/exporter.lua
-- ==========================================
-- src/exporter.lua

ctx = ctx or {}
ctx.state = ctx.state or {}
ctx.exporter = ctx.exporter or {}

ctx.state.save_status = ctx.state.save_status or {
    message = "",
    timer = 0,
    is_error = false
}

local function base_name(path)
    path = tostring(path or "")
    path = path:gsub("\\", "/")

    local name = path:match("([^/]+)$") or path
    name = name:gsub("%.lua$", "")

    if name == "" then
        name = "unknown"
    end

    return name
end

local function json_escape(value)
    value = tostring(value or "")

    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")

    return value
end

local function set_status(message, is_error)
    ctx.state.save_status.message = message
    ctx.state.save_status.is_error = is_error
    ctx.state.save_status.timer = 3.0
end

local function write_json(filename, findings, scanned_file)
    local f, err = io.open(filename, "w")
    if not f then
        return false, err
    end

    f:write("{\n")
    f:write('  "target_file": "' .. json_escape(base_name(scanned_file)) .. '",\n')
    f:write('  "timestamp": "' .. json_escape(os.date("%Y-%m-%dT%H:%M:%S")) .. '",\n')
    f:write('  "total_findings": ' .. tostring(#findings) .. ',\n')
    f:write('  "findings": [\n')

    for i, r in ipairs(findings) do
        f:write("    {\n")
        f:write('      "line": ' .. tostring(r.line or 0) .. ",\n")
        f:write('      "severity": "' .. json_escape(r.severity or "info") .. '",\n')
        f:write('      "category": "' .. json_escape(r.category or "Unknown") .. '",\n')
        f:write('      "rule_id": "' .. json_escape(r.rule_id or "unknown") .. '",\n')
        f:write('      "message": "' .. json_escape(r.msg or "") .. '",\n')
        f:write('      "hot_path": ' .. (r.hot and "true" or "false") .. ",\n")
        f:write('      "source": "' .. json_escape(r.source or "") .. '"\n')
        f:write("    }")

        if i < #findings then
            f:write(",")
        end

        f:write("\n")
    end

    f:write("  ]\n")
    f:write("}\n")

    f:close()
    return true
end

local function write_txt(filename, findings, scanned_file)
    local f, err = io.open(filename, "w")
    if not f then
        return false, err
    end

    f:write("Moondog Report\n")
    f:write("target_file: " .. base_name(scanned_file) .. "\n")
    f:write("timestamp: " .. os.date("%Y-%m-%dT%H:%M:%S") .. "\n")
    f:write("total_findings: " .. tostring(#findings) .. "\n")
    f:write("\n")

    for _, r in ipairs(findings) do
        f:write(
            string.format(
                "L%d [%s] [%s] [%s] %s\n",
                r.line or 0,
                tostring(r.severity or "info"),
                tostring(r.category or "Unknown"),
                tostring(r.rule_id or "unknown"),
                tostring(r.msg or "")
            )
        )

        f:write("  " .. tostring(r.source or "") .. "\n")
    end

    f:close()
    return true
end

function ctx.exporter.save(format)
    local findings = ctx.state.results or {}
    local scanned_file = ctx.state.scanned_file or ""

    if scanned_file == "" then
        set_status("Scan a file before exporting.", true)
        return false, "No scanned file"
    end

    local stamp = os.date("%Y%m%d_%H%M%S")
    local name = base_name(scanned_file)

    local filename
    local ok, err

    if format == "txt" then
        filename = string.format("moondog_%s_%s.txt", name, stamp)
        ok, err = write_txt(filename, findings, scanned_file)
    else
        filename = string.format("moondog_%s_%s.json", name, stamp)
        ok, err = write_json(filename, findings, scanned_file)
    end

    if ok then
        set_status("Saved " .. filename, false)
    else
        set_status("Export failed: " .. tostring(err), true)
    end

    return ok, err
end
-- ==========================================
-- FILE: src/cli_runner.lua
-- ==========================================
-- src/cli_runner.lua
-- CLI-only entrypoint and reporter.
-- Included only in cli_manifest.txt. Stripped from LOVE builds.
-- CI exit-code contract:
--   0 = scan completed, no critical or fatal smells
--   1 = scan completed, one or more critical or fatal smells present
--   2 = usage error or unreadable input file
-- Runtime dependencies (loaded earlier in the concatenation):
--   ctx.scan_file       (src/scanner.lua)
--   ctx.state.results   (src/scanner.lua)
--   ctx.rule_profiles   (src/rules.lua, used by --platform validation)
--   ctx.exporter.save   (src/exporter.lua, used by --save)
--   ctx.sentinel        (src/sentinel.lua, used by --sentinel)
--   ANSI_* constants    (injected by build.sh CLI preamble)

-- Resolve ANSI colors from the builder preamble, with standalone fallbacks.
local C_RED    = ANSI_RED    or "\27[38;5;196m"
local C_YELLOW = ANSI_YELLOW or "\27[38;5;226m"
local C_CYAN   = ANSI_CYAN   or "\27[38;5;51m"
local C_GREEN  = ANSI_GREEN  or "\27[38;5;46m"
local C_RESET  = ANSI_RESET  or "\27[0m"
local C_BOLD   = ANSI_BOLD   or "\27[1m"
local C_DIM    = ANSI_DIM    or "\27[2m"

local KNOWN_SEVERITIES = { critical = true, fatal = true, warning = true, info = true }

local function severity_color(sev)
    if sev == "critical" or sev == "fatal" then
        return C_RED
    elseif sev == "warning" then
        return C_YELLOW
    end
    return C_CYAN
end

local function known_platforms()
    local names = {}
    for name in pairs(ctx.rule_profiles or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function usage()
    print(C_BOLD .. "moondog " .. C_RESET .. "- Lua code-smell detector (headless)")
    print("Usage: moondog <file.lua> [--save=json|txt] [--platform=<vm>] [--sentinel]")
    print("  <file.lua>        Path to the Lua source file to scan.")
    print("  --save=json|txt   Also write a report artifact to the CWD.")
    print("  --platform=<vm>   Severity profile: " .. table.concat(known_platforms(), ", ") .. " (default: lua51).")
    print("  --sentinel        Print Micro-Sentinel telemetry (max time, GC delta) at the end.")
    print("")
    print("Exit codes: 0 clean | 1 critical or fatal smells found | 2 usage/IO error")
end

-- Prints findings to stdout.
-- Returns critical_count (includes fatal), warning_count, info_count.
function ctx.print_results()
    local results = ctx.state.results or {}
    local scanned = ctx.state.scanned_file or "<none>"
    local platform = (ctx.config and ctx.config.platform) or "lua51"

    print(C_BOLD .. "=== Moondog Report ===" .. C_RESET)
    print(C_DIM .. "target:  " .. scanned .. C_RESET)
    print(C_DIM .. "profile: " .. platform .. C_RESET)
    print(C_DIM .. string.rep("-", 48) .. C_RESET)

    local crit, fatal, warn, info = 0, 0, 0, 0
    for _, r in ipairs(results) do
        local sev = r.severity or "info"
        if not KNOWN_SEVERITIES[sev] then
            sev = "info"
        end
        local color = severity_color(sev)
        local hot = r.hot and (C_RED .. "[HOT]" .. C_RESET .. " ") or ""
        io.write(
            color,
            string.format("L%-5d", r.line or 0),
            string.format("[%-8s]", string.upper(sev)),
            " [" .. (r.category or "Unknown") .. "] ",
            "[" .. (r.rule_id or "?") .. "] ",
            C_RESET, " ", hot, r.msg or "", "\n"
        )
        if sev == "critical" then
            crit = crit + 1
        elseif sev == "fatal" then
            fatal = fatal + 1
        elseif sev == "warning" then
            warn = warn + 1
        else
            info = info + 1
        end
    end

    print(C_DIM .. string.rep("-", 48) .. C_RESET)
    print(string.format(
        "%s%d critical%s  %s%d fatal%s  %s%d warning%s  %s%d info%s",
        C_RED, crit, C_RESET,
        C_RED, fatal, C_RESET,
        C_YELLOW, warn, C_RESET,
        C_CYAN, info, C_RESET
    ))
    return crit + fatal, warn, info
end

-- Full CLI flow. `args` is the Lua `arg` table. Returns an exit code.
function ctx.cli_run(args)
    args = args or {}
    local filepath = nil
    local save_format = nil
    local platform = nil
    local show_sentinel = false

    for _, a in ipairs(args) do
        if type(a) == "string" then
            if a:sub(1, 7) == "--save=" then
                save_format = a:sub(8)
            elseif a:sub(1, 11) == "--platform=" then
                platform = a:sub(12)
            elseif a == "--sentinel" then
                show_sentinel = true
            elseif a:sub(1, 2) ~= "--" and not filepath then
                filepath = a
            end
        end
    end

    -- Inject config before scan. Unknown platforms fail as usage errors (exit 2)
    -- so CI distinguishes a bad flag from a dirty or clean scan.
    ctx.config = ctx.config or {}
    if platform then
        if ctx.rule_profiles and ctx.rule_profiles[platform] then
            ctx.config.platform = platform
        else
            io.stderr:write("moondog: unknown platform: " .. platform .. "\n")
            io.stderr:write("known platforms: " .. table.concat(known_platforms(), ", ") .. "\n")
            return 2
        end
    else
        ctx.config.platform = ctx.config.platform or "lua51"
    end

    if not filepath then
        usage()
        return 2
    end

    -- Fail fast on unreadable input so CI can distinguish IO error from a clean scan.
    local probe = io.open(filepath, "r")
    if not probe then
        io.stderr:write("moondog: cannot open file: " .. filepath .. "\n")
        return 2
    end
    probe:close()

    ctx.scan_file(filepath)
    local gating = ctx.print_results()

    -- Optional artifact export for CI pipelines.
    if save_format and ctx.exporter and ctx.exporter.save then
        local ok, err = ctx.exporter.save(save_format)
        if ok then
            print(C_GREEN .. "report saved (" .. save_format .. ")" .. C_RESET)
        else
            io.stderr:write("moondog: save failed: " .. tostring(err) .. "\n")
        end
    end

    -- Phase 6: Sentinel telemetry dump.
    if show_sentinel and ctx.sentinel and ctx.sentinel.get_report then
        local report = ctx.sentinel.get_report()
        print("\n--- Sentinel Telemetry ---")
        for name, data in pairs(report) do
            print(string.format(
                "[%s] max_time: %.4fs | max_gc_delta: %.2f KB | calls: %d",
                name, data.max_time, data.max_gc_delta, data.count
            ))
        end
    end

    if gating > 0 then
        return 1
    end
    return 0
end

-- Back-compat facade for any tooling still referencing the `moondog` namespace.
moondog = ctx
-- ==========================================
-- FILE: src/sentinel.lua
-- ==========================================
-- src/sentinel.lua
-- Micro-Sentinel for Hack & Harden Phase 2 profiling.
-- Measures max execution time and max GC delta per named phase.
-- The Sentinel decides, not intuition.
ctx = ctx or {}
ctx.sentinel = ctx.sentinel or {}

-- Portable clock: prefer love.timer.getTime for wall-clock accuracy in LÖVE,
-- fall back to os.clock for headless CLI builds.
local clock = (love and love.timer and love.timer.getTime) or os.clock

local phases = {}

function ctx.sentinel.start_phase(name)
    phases[name] = phases[name] or {
        max_time = 0,
        max_gc_delta = 0,
        count = 0
    }
    local p = phases[name]
    p.start_time = clock()
    p.start_gc = collectgarbage("count")
end

function ctx.sentinel.end_phase(name)
    local p = phases[name]
    if not p or not p.start_time then return end

    local dt = clock() - p.start_time
    local dgc = collectgarbage("count") - p.start_gc

    if dt > p.max_time then p.max_time = dt end
    if dgc > p.max_gc_delta then p.max_gc_delta = dgc end
    p.count = p.count + 1

    p.start_time = nil
    p.start_gc = nil
end

function ctx.sentinel.get_report()
    return phases
end

-- [BUILD-TIME OVERRIDE] CLI Environment Initialization
_G.ctx = _G.ctx or {}
ctx.is_cli = true

-- CLI entry: delegate to ctx.cli_run (src/cli_runner.lua).
-- Exit codes: 0 clean | 1 critical/fatal smells | 2 usage/IO error.
local cli_exit_code = 2
if ctx and ctx.cli_run then
    cli_exit_code = ctx.cli_run(arg or {})
else
    io.stderr:write('moondog: fatal: ctx.cli_run missing (cli_runner.lua not in manifest)\n')
end
os.exit(cli_exit_code)
