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