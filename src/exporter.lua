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