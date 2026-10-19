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