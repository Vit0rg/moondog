-- ==========================================================
-- moondog: Lua Code-Smell Detector & Anti-Pattern Indicator
-- Paradigm: Hack and Harden (H2) / Lexical Data-Oriented Design (L-DOD)
-- Target: cli
-- Built: 2026-10-19T22:21:38Z
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
-- src/rules.lua

ctx = ctx or {}

ctx.rules = {
    {
        id = "table_insert",
        category = "Memory",
        pattern = "table%.insert",
        severity = "warning",
        msg = "Prefer t[#t+1] = val for append"
    },
    {
        id = "table_remove",
        category = "Algorithmic",
        pattern = "table%.remove",
        severity = "critical",
        msg = "O(N) shift -- consider swap-and-pop"
    },
    {
        id = "pairs_iteration",
        category = "Algorithmic",
        pattern = "pairs%(",
        severity = "warning",
        msg = "Dict iteration -- prefer numeric for in hot paths"
    },
    {
        id = "ipairs_iteration",
        category = "Algorithmic",
        pattern = "ipairs%(",
        severity = "info",
        msg = "Consider numeric for i=1,#t for performance"
    },
    {
        id = "varargs",
        category = "Memory",
        pattern = "%.%.%.",
        severity = "warning",
        msg = "Varargs cause hidden allocations in hot paths"
    },
    {
        id = "string_format",
        category = "Memory",
        pattern = "string%.format",
        severity = "info",
        msg = "Allocates a new string -- avoid in hot loops"
    },
    {
        id = "setmetatable",
        category = "Architecture",
        pattern = "setmetatable",
        severity = "info",
        msg = "OOP abstraction -- verify it is not in a hot path"
    },
    {
        id = "collectgarbage",
        category = "Memory",
        pattern = "collectgarbage",
        severity = "warning",
        msg = "Manual GC call -- usually a band-aid"
    },
    {
        id = "hotpath_marker",
        category = "Marker",
        pattern = "%-%- @hotpath",
        severity = "info",
        msg = "Hot path marker found -- lint strictly"
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
-- Included only in cli_manifest.txt. Stripped from LÖVE builds.
--
-- CI exit-code contract:
--   0 = scan completed, no critical smells
--   1 = scan completed, one or more critical smells present
--   2 = usage error or unreadable input file
--
-- Runtime dependencies (loaded earlier in the concatenation):
--   ctx.scan_file      (src/scanner.lua)
--   ctx.state.results  (src/scanner.lua)
--   ctx.exporter.save  (src/exporter.lua, used by --save)
--   ANSI_* constants   (injected by build.sh CLI preamble)

-- Resolve ANSI colors from the builder preamble, with standalone fallbacks.
local C_RED    = ANSI_RED    or "\27[38;5;196m"
local C_YELLOW = ANSI_YELLOW or "\27[38;5;226m"
local C_CYAN   = ANSI_CYAN   or "\27[38;5;51m"
local C_GREEN  = ANSI_GREEN  or "\27[38;5;46m"
local C_RESET  = ANSI_RESET  or "\27[0m"
local C_BOLD   = ANSI_BOLD   or "\27[1m"
local C_DIM    = ANSI_DIM    or "\27[2m"

local function severity_color(sev)
    if sev == "critical" then
        return C_RED
    elseif sev == "warning" then
        return C_YELLOW
    end
    return C_CYAN
end

local function usage()
    print(C_BOLD .. "moondog" .. C_RESET .. " - Lua code-smell detector (headless)")
    print("Usage: moondog <file.lua> [--save=json|txt]")
    print("  <file.lua>        Path to the Lua source file to scan.")
    print("  --save=json|txt   Also write a report artifact to the CWD.")
    print("")
    print("Exit codes: 0 clean | 1 critical smells found | 2 usage/IO error")
end

-- Prints findings to stdout.
-- Returns critical_count, warning_count, info_count.
function ctx.print_results()
    local results = ctx.state.results or {}
    local scanned = ctx.state.scanned_file or "<none>"

    print(C_BOLD .. "=== Moondog Report ===" .. C_RESET)
    print(C_DIM .. "target: " .. scanned .. C_RESET)
    print(C_DIM .. string.rep("-", 48) .. C_RESET)

    local crit, warn, info = 0, 0, 0

    for _, r in ipairs(results) do
        local color = severity_color(r.severity)
        local hot = r.hot and (C_RED .. "[HOT]" .. C_RESET .. " ") or ""

        io.write(
            color,
            string.format("L%-5d", r.line or 0),
            string.format("[%-8s]", string.upper(r.severity or "info")),
            C_RESET, " ", hot, r.msg or "", "\n"
        )

        if r.severity == "critical" then
            crit = crit + 1
        elseif r.severity == "warning" then
            warn = warn + 1
        else
            info = info + 1
        end
    end

    print(C_DIM .. string.rep("-", 48) .. C_RESET)
    print(string.format(
        "%s%d critical%s  %s%d warning%s  %s%d info%s",
        C_RED, crit, C_RESET,
        C_YELLOW, warn, C_RESET,
        C_CYAN, info, C_RESET
    ))

    return crit, warn, info
end

-- Full CLI flow. `args` is the Lua `arg` table. Returns an exit code.
function ctx.cli_run(args)
    args = args or {}

    local filepath = nil
    local save_format = nil

    for _, a in ipairs(args) do
        if type(a) == "string" then
            if a:sub(1, 7) == "--save=" then
                save_format = a:sub(8)
            elseif a:sub(1, 2) ~= "--" and not filepath then
                filepath = a
            end
        end
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
    local crit = ctx.print_results()

    -- Optional artifact export for CI pipelines.
    if save_format and ctx.exporter and ctx.exporter.save then
        local ok, err = ctx.exporter.save(save_format)
        if ok then
            print(C_GREEN .. "report saved (" .. save_format .. ")" .. C_RESET)
        else
            io.stderr:write("moondog: save failed: " .. tostring(err) .. "\n")
        end
    end

    if crit > 0 then
        return 1
    end
    return 0
end

-- Back-compat facade for any tooling still referencing the `moondog` namespace.
moondog = ctx

-- [BUILD-TIME OVERRIDE] CLI Environment Initialization
_G.ctx = _G.ctx or {}
ctx.is_cli = true

-- Auto-execute if a file path is provided
if arg and arg[1] then
    if moondog and moondog.scan_file then
        moondog.scan_file(arg[1])
        if moondog.print_results then moondog.print_results() end
    else
        print('Error: moondog module or scan_file function not found.')
    end
else
    print(ANSI_YELLOW .. 'Usage: lua moondog.lua <file.lua>' .. ANSI_RESET)
end

-- [BUILD-TIME OVERRIDE] CLI Environment Initialization
_G.ctx = _G.ctx or {}
ctx.is_cli = true

-- CLI entry: delegate to ctx.cli_run (src/cli_runner.lua).
-- Exit codes: 0 clean | 1 critical smells | 2 usage/IO error.
local cli_exit_code = 2
if ctx and ctx.cli_run then
    cli_exit_code = ctx.cli_run(arg or {})
else
    io.stderr:write('moondog: fatal: ctx.cli_run missing (cli_runner.lua not in manifest)\n')
end
os.exit(cli_exit_code)
