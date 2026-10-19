-- ==========================================================
-- moondog: Lua Code-Smell Detector & Anti-Pattern Indicator
-- Paradigm: Hack and Harden (H2) / Lexical Data-Oriented Design (L-DOD)
-- Target: love
-- Built: 2026-10-19T21:17:35Z
-- Manifest: scripts/manifests/love_manifest.txt
-- ==========================================================

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

function ctx.scan_file(filepath)
    local findings = {}

    local file = io.open(filepath, "r")
    if not file then
        ctx.state.scanned_file = filepath
        ctx.state.results = findings
        ctx.state.scroll_y = 0
        return
    end

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

        for _, rule in ipairs(ctx.rules or {}) do
            if rule.pattern and line:find(rule.pattern) then
                findings[#findings + 1] = {
                    line = line_num,
                    severity = trim(rule.severity or "info"),
                    msg = rule.msg or "",
                    source = line,
                    hot = in_hotpath,
                    rule_id = rule.id or rule.pattern or "unknown",
                    category = rule.category or "Unknown"
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
-- FILE: src/renderer.lua
-- ==========================================
-- src/renderer.lua

ctx = ctx or {}
ctx.state = ctx.state or {}
ctx.renderer = ctx.renderer or {}

ctx.renderer.buttons = {}

local function short_path(path)
    path = tostring(path or "")
    path = path:gsub("\\", "/")
    return path:match("([^/]+)$") or path
end

local function register_button(id, x, y, w, h)
    ctx.renderer.buttons[#ctx.renderer.buttons + 1] = {
        id = id,
        x = x,
        y = y,
        w = w,
        h = h
    }
end

local function draw_button(label, x, y, w, h)
    love.graphics.setColor(0.16, 0.16, 0.18, 1.0)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(0.45, 0.45, 0.50, 1.0)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.printf(label, x, y + 8, w, "center")
end

local function severity_color(severity)
    if severity == "critical" then
        love.graphics.setColor(1.0, 0.3, 0.3, 1.0)
    elseif severity == "warning" then
        love.graphics.setColor(1.0, 0.8, 0.2, 1.0)
    else
        love.graphics.setColor(0.5, 0.7, 1.0, 1.0)
    end
end

function ctx.renderer.draw()
    ctx.renderer.buttons = {}

    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()

    love.graphics.setColor(0.1, 0.1, 0.12, 1.0)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)

    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.print("Lua Code-Smell Detector (HACK PHASE)", 20, 10)
    love.graphics.print("Drop a .lua file to scan | Wheel scrolls | Save JSON/TXT", 20, 30)

    if ctx.state.scanned_file ~= "" then
        love.graphics.setColor(0.6, 0.8, 1.0, 1.0)

        local findings = ctx.state.results or {}
        local label = string.format(
            "File: %s | Findings: %d",
            short_path(ctx.state.scanned_file),
            #findings
        )

        love.graphics.print(label, 20, 55)
    end

    local findings = ctx.state.results or {}
    local y = 80 - (ctx.state.scroll_y or 0)

    for _, r in ipairs(findings) do
        if y > 60 and y < screen_h then
            severity_color(r.severity)

            local prefix = r.hot and "[HOT] " or ""

            local line_label = string.format(
                "%sL%d: [%s] %s",
                prefix,
                r.line or 0,
                tostring(r.severity or "info"):upper(),
                r.msg or ""
            )

            love.graphics.print(line_label, 30, y)

            love.graphics.setColor(0.4, 0.4, 0.45, 1.0)
            love.graphics.print(r.source or "", 50, y + 16)
        end

        y = y + 40
    end

    local button_y = screen_h - 50

    local json_x = 20
    local json_w = 110
    local json_h = 30
    draw_button("Save JSON", json_x, button_y, json_w, json_h)
    register_button("save_json", json_x, button_y, json_w, json_h)

    local txt_x = json_x + json_w + 10
    local txt_w = 110
    local txt_h = 30
    draw_button("Save TXT", txt_x, button_y, txt_w, txt_h)
    register_button("save_txt", txt_x, button_y, txt_w, txt_h)

    if ctx.state.save_status and ctx.state.save_status.message ~= "" then
        if ctx.state.save_status.is_error then
            love.graphics.setColor(1.0, 0.3, 0.3, 1.0)
        else
            love.graphics.setColor(0.3, 1.0, 0.3, 1.0)
        end

        love.graphics.print(
            ctx.state.save_status.message,
            txt_x + txt_w + 20,
            button_y + 8
        )
    end
end

function ctx.renderer.click(x, y, button)
    if button ~= 1 then
        return
    end

    for _, b in ipairs(ctx.renderer.buttons or {}) do
        local inside =
            x >= b.x and
            x <= b.x + b.w and
            y >= b.y and
            y <= b.y + b.h

        if inside then
            if b.id == "save_json" then
                if ctx.exporter and ctx.exporter.save then
                    ctx.exporter.save("json")
                end
            elseif b.id == "save_txt" then
                if ctx.exporter and ctx.exporter.save then
                    ctx.exporter.save("txt")
                end
            end
        end
    end
end
-- ==========================================
-- FILE: src/sentinel.lua
-- ==========================================

-- Cold Path — setup
local Sentinel = {
    reports = {},
    gc_start = 0,
    time_start = 0
}
function Sentinel:start_tick(name)
    self.gc_start = collectgarbage("count")
    self.time_start = love.timer.getTime()
end
function Sentinel:end_tick(name)
    local gc_delta = collectgarbage("count") - self.gc_start
    local time_delta = love.timer.getTime() - self.time_start
    if not self.reports[name] then
        self.reports[name] = { max_gc = 0, max_time = 0, allocations = 0 }
    end
    local r = self.reports[name]
    if gc_delta > 0 then
        r.allocations = r.allocations + 1
        r.max_gc = math.max(r.max_gc, gc_delta)
    end
    r.max_time = math.max(r.max_time, time_delta)
end

-- src/sentinel.lua

ctx = ctx or {}
ctx.sentinel = Sentinel
-- ==========================================
-- FILE: src/main.lua
-- ==========================================
-- src/main.lua

ctx = ctx or {}
ctx.state = ctx.state or {}

ctx.state.results = ctx.state.results or {}
ctx.state.scroll_y = ctx.state.scroll_y or 0
ctx.state.scanned_file = ctx.state.scanned_file or ""

ctx.state.save_status = ctx.state.save_status or {
    message = "",
    timer = 0,
    is_error = false
}

function love.update(dt)
    if ctx.state.save_status.timer > 0 then
        ctx.state.save_status.timer = ctx.state.save_status.timer - dt

        if ctx.state.save_status.timer <= 0 then
            ctx.state.save_status.message = ""
        end
    end
end

function love.draw()
    if ctx.renderer and ctx.renderer.draw then
        ctx.renderer.draw()
    end
end

function love.filedropped(file)
    file:open("r")
    local path = file:getFilename()
    file:close()

    if ctx.scan_file then
        ctx.scan_file(path)
    end
end

function love.wheelmoved(x, y)
    ctx.state.scroll_y = (ctx.state.scroll_y or 0) - y * 40

    if ctx.state.scroll_y < 0 then
        ctx.state.scroll_y = 0
    end
end

function love.mousereleased(x, y, button)
    if ctx.renderer and ctx.renderer.click then
        ctx.renderer.click(x, y, button)
    end
end

-- [BUILD-TIME OVERRIDE] LÖVE Environment Initialization
_G.ctx = _G.ctx or {}
ctx.is_love = true
