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