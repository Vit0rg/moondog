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

-- Window mode. MUST be a BORDERED windowed window at desktop resolution.
-- Not exclusive fullscreen, and not borderless. A normal decorated window
-- sized to the desktop so the title bar and borders stay visible.
-- setFullscreen (any type) strips decorations, so it is deliberately NOT used.
-- Phase 1 (Hack): hard-coded default. A runtime toggle is a Sentinel-era
-- GUI decision, not a Hack-phase one.
function love.load()
    if love.window and love.window.getDesktopDimensions and love.window.setMode then
        local dw, dh = love.window.getDesktopDimensions()
        love.window.setMode(dw, dh, {
            fullscreen = false,
            borderless = false,
            resizable = true,
            vsync = 1
        })
    end
end

function love.update(dt)
    if ctx.state.save_status.timer > 0 then
        ctx.state.save_status.timer = ctx.state.save_status.timer - dt
        if ctx.state.save_status.timer <= 0 then
            ctx.state.save_status.message = ""
        end
    end
end

function love.draw()
    if ctx.sentinel and ctx.sentinel.start_phase then
        ctx.sentinel.start_phase("draw")
    end
    if ctx.renderer and ctx.renderer.draw then
        ctx.renderer.draw()
    end
    if ctx.sentinel and ctx.sentinel.end_phase then
        ctx.sentinel.end_phase("draw")
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
    local mx = 0
    if love.mouse and love.mouse.getX then
        mx = love.mouse.getX()
    end
    if ctx.renderer and ctx.renderer.is_over_browser and ctx.renderer.is_over_browser(mx, 0) then
        if ctx.renderer.scroll_browser then
            ctx.renderer.scroll_browser(-y * 40)
        end
    else
        ctx.state.scroll_y = (ctx.state.scroll_y or 0) - y * 40
        if ctx.state.scroll_y < 0 then
            ctx.state.scroll_y = 0
        end
    end
end

function love.mousereleased(x, y, button)
    if ctx.renderer and ctx.renderer.click then
        ctx.renderer.click(x, y, button)
    end
end