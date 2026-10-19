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