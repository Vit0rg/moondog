-- src/renderer.lua
ctx = ctx or {}
ctx.state = ctx.state or {}
ctx.renderer = ctx.renderer or {}
ctx.renderer.buttons = {}
ctx.browser = ctx.browser or {}

-- Phase 1 GUI layout. The left browser panel is collapsible; the findings
-- panel expands to reclaim the space when the browser is hidden.
local BROWSER_W = 300
local COLLAPSED_W = 26
local HEADER_H = 80
local BOTTOM_BAR = 60
local ROW_H = 24
local FINDING_H = 40
local GROUP_H = 24

-- Canonical profile order and display labels for the GUI selector.
-- The authoritative profile set still comes from ctx.rule_profiles.
local PROFILE_ORDER = { "lua51", "lua54", "luajit", "luajit_openresty" }
local PROFILE_LABELS = {
    lua51 = "Lua 5.1",
    lua54 = "Lua 5.4",
    luajit = "LuaJIT",
    luajit_openresty = "OpenResty",
}

-- Fixed category ordering for grouped findings. Unknown categories are
-- appended alphabetically after these.
local CATEGORY_ORDER = { "Memory", "Algorithmic", "Architecture", "Marker" }

local function short_path(path)
    path = tostring(path or "")
    path = path:gsub("\\", "/")
    return path:match("([^/]+)$") or path
end

local function truncate_left(s, max)
    s = tostring(s or "")
    if #s <= max then
        return s
    end
    return "..." .. s:sub(-(max - 3))
end

local function text_width(s)
    local font = love.graphics.getFont()
    if font then
        return font:getWidth(s)
    end
    return #s * 7
end

local function is_collapsed()
    return ctx.state.browser ~= nil and ctx.state.browser.collapsed == true
end

local function browser_panel_w()
    if is_collapsed() then
        return COLLAPSED_W
    end
    return BROWSER_W
end

local function register_button(id, x, y, w, h, payload)
    ctx.renderer.buttons[#ctx.renderer.buttons + 1] = {
        id = id,
        x = x,
        y = y,
        w = w,
        h = h,
        payload = payload
    }
end

local function draw_button(label, x, y, w, h, active)
    if active then
        love.graphics.setColor(0.10, 0.24, 0.14, 1.0)
    else
        love.graphics.setColor(0.16, 0.16, 0.18, 1.0)
    end
    love.graphics.rectangle("fill", x, y, w, h)
    if active then
        love.graphics.setColor(0.30, 1.0, 0.40, 1.0)
    else
        love.graphics.setColor(0.45, 0.45, 0.50, 1.0)
    end
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.printf(label, x, y + (h - 14) / 2, w, "center")
end

local function severity_color(severity)
    if severity == "critical" or severity == "fatal" then
        love.graphics.setColor(1.0, 0.3, 0.3, 1.0)
    elseif severity == "warning" then
        love.graphics.setColor(1.0, 0.8, 0.2, 1.0)
    else
        love.graphics.setColor(0.5, 0.7, 1.0, 1.0)
    end
end

-- Bucket findings by category. Returns an ordered category list and a
-- map of category -> findings. Phase 1: rebuilt every frame, which is
-- fine at this data size and avoids cache-invalidation bugs.
local function build_category_groups(findings)
    local by_cat = {}
    local present = {}
    for _, r in ipairs(findings) do
        local cat = r.category or "Unknown"
        if not by_cat[cat] then
            by_cat[cat] = {}
            present[#present + 1] = cat
        end
        local bucket = by_cat[cat]
        bucket[#bucket + 1] = r
    end

    local ordered = {}
    local seen = {}
    for _, cat in ipairs(CATEGORY_ORDER) do
        if by_cat[cat] then
            ordered[#ordered + 1] = cat
            seen[cat] = true
        end
    end
    local extras = {}
    for _, cat in ipairs(present) do
        if not seen[cat] then
            extras[#extras + 1] = cat
        end
    end
    table.sort(extras)
    for _, cat in ipairs(extras) do
        ordered[#ordered + 1] = cat
    end
    return ordered, by_cat
end

-- Build the ordered profile list for the selector from ctx.rule_profiles.
local function build_profile_list()
    local profiles = {}
    local present = {}
    if ctx.rule_profiles then
        for _, pid in ipairs(PROFILE_ORDER) do
            if ctx.rule_profiles[pid] then
                profiles[#profiles + 1] = pid
                present[pid] = true
            end
        end
        local extras = {}
        for pid in pairs(ctx.rule_profiles) do
            if not present[pid] then
                extras[#extras + 1] = pid
            end
        end
        table.sort(extras)
        for _, pid in ipairs(extras) do
            profiles[#profiles + 1] = pid
        end
    end
    return profiles
end

-- ==========================================================
-- Phase 1 file browser. Directory listing with two backends:
--   1. love.filesystem.getDirectoryItems (source/save tree paths)
--   2. io.popen("ls -A -p") fallback for absolute paths outside
--      the sandbox. POSIX only; Windows gets an empty list plus
--      an error line, not a crash.
-- ==========================================================

local function normalize_dir(p)
    p = tostring(p or ""):gsub("\\", "/")
    if p == "" then
        p = "."
    end
    return p
end

local function join_path(dir, name)
    dir = normalize_dir(dir)
    if dir:sub(-1) == "/" then
        return dir .. name
    end
    return dir .. "/" .. name
end

local function parent_dir(p)
    p = normalize_dir(p):gsub("/+$", "")
    if p == "" or p == "." then
        return nil
    end
    local parent = p:match("^(.*)/[^/]*$")
    if parent == "" then
        return "/"
    end
    return parent
end

local function list_love(path)
    local items = {}
    if not (love and love.filesystem and love.filesystem.getDirectoryItems) then
        return items
    end
    local ok, entries = pcall(love.filesystem.getDirectoryItems, path)
    if not ok or not entries then
        return items
    end
    for _, name in ipairs(entries) do
        local info = love.filesystem.getInfo(join_path(path, name))
        local kind = (info and info.type == "directory") and "dir" or "file"
        items[#items + 1] = { name = name, kind = kind, path = join_path(path, name) }
    end
    return items
end

local function list_popen(path)
    local items = {}
    local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
    local pipe = io.popen("ls -A -p " .. quoted .. " 2>/dev/null")
    if not pipe then
        return items
    end
    for name in pipe:lines() do
        if name ~= "" then
            local kind = (name:sub(-1) == "/") and "dir" or "file"
            local clean = (kind == "dir") and name:sub(1, -2) or name
            if clean ~= "." and clean ~= ".." then
                items[#items + 1] = { name = clean, kind = kind, path = join_path(path, clean) }
            end
        end
    end
    pipe:close()
    return items
end

function ctx.browser.list(path)
    path = normalize_dir(path)
    local items = list_love(path)
    if #items == 0 then
        items = list_popen(path)
    end
    table.sort(items, function(a, b)
        if a.kind ~= b.kind then
            return a.kind == "dir"
        end
        return a.name < b.name
    end)
    ctx.state.browser = ctx.state.browser or {}
    ctx.state.browser.path = path
    ctx.state.browser.entries = items
    ctx.state.browser.scroll_y = 0
    ctx.state.browser.error = ""
    if #items == 0 then
        ctx.state.browser.error = "empty or unreadable directory"
    end
end

function ctx.browser.up()
    local current = (ctx.state.browser and ctx.state.browser.path) or "."
    local parent = parent_dir(current)
    if parent then
        ctx.browser.list(parent)
    end
end

function ctx.browser.activate(entry)
    if not entry then
        return
    end
    if entry.kind == "dir" then
        ctx.browser.list(entry.path)
        return
    end
    if entry.name:sub(-4) ~= ".lua" then
        ctx.state.save_status = ctx.state.save_status or { message = "", timer = 0, is_error = false }
        ctx.state.save_status.message = "not a .lua file: " .. entry.name
        ctx.state.save_status.is_error = true
        ctx.state.save_status.timer = 3
        return
    end
    if ctx.scan_file then
        ctx.scan_file(entry.path)
    end
end

function ctx.renderer.is_over_browser(x, _)
    if is_collapsed() then
        return false
    end
    return x <= browser_panel_w()
end

function ctx.renderer.scroll_browser(dy)
    ctx.state.browser = ctx.state.browser or { scroll_y = 0 }
    ctx.state.browser.scroll_y = math.max(0, (ctx.state.browser.scroll_y or 0) + dy)
end

function ctx.renderer.draw()
    ctx.renderer.buttons = {}
    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()

    -- Lazy browser init: start at the working directory.
    if not ctx.state.browser then
        local start = "."
        if love.filesystem and love.filesystem.getWorkingDirectory then
            local wd = love.filesystem.getWorkingDirectory()
            if wd and wd ~= "" then
                start = wd
            end
        end
        ctx.state.browser = {
            path = start,
            entries = {},
            scroll_y = 0,
            error = "",
            collapsed = false
        }
        ctx.browser.list(start)
    end

    local panel_w = browser_panel_w()
    local findings_x = panel_w + 20
    local active_platform = (ctx.config and ctx.config.platform) or "lua51"

    love.graphics.setColor(0.1, 0.1, 0.12, 1.0)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)

    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.print("Lua Code-Smell Detector (HACK PHASE)", 20, 10)
    love.graphics.print("Browse or drop a .lua file | Wheel scrolls | Click a profile to re-scan", 20, 30)

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

    -- ===== Profile selector (right side of header) =====
    local profiles = build_profile_list()
    local btn_h = 24
    local gap = 6
    local pad = 16
    local widths = {}
    local total_w = 0
    for i, pid in ipairs(profiles) do
        local label = PROFILE_LABELS[pid] or pid
        local w = text_width(label) + pad
        widths[i] = w
        total_w = total_w + w + (i > 1 and gap or 0)
    end
    local bx = screen_w - total_w - 20
    local by = 26
    for i, pid in ipairs(profiles) do
        local label = PROFILE_LABELS[pid] or pid
        draw_button(label, bx, by, widths[i], btn_h, pid == active_platform)
        register_button("profile_select", bx, by, widths[i], btn_h, pid)
        bx = bx + widths[i] + gap
    end

    -- ===== Browser panel (left, collapsible) =====
    love.graphics.setColor(0.13, 0.13, 0.15, 1.0)
    love.graphics.rectangle("fill", 0, HEADER_H, panel_w, screen_h - HEADER_H)
    love.graphics.setColor(0.45, 0.45, 0.50, 1.0)
    love.graphics.line(panel_w, HEADER_H, panel_w, screen_h)

    local browser = ctx.state.browser
    local toggle_w, toggle_h = 18, 22
    local toggle_y = HEADER_H + 8

    if is_collapsed() then
        draw_button(">", 4, toggle_y, toggle_w, toggle_h)
        register_button("browser_toggle", 4, toggle_y, toggle_w, toggle_h)
    else
        local up_x, up_y, up_w, up_h = 10, HEADER_H + 8, 40, 22
        draw_button("..", up_x, up_y, up_w, up_h)
        register_button("browser_up", up_x, up_y, up_w, up_h)

        love.graphics.setColor(0.7, 0.8, 0.9, 1.0)
        love.graphics.print(truncate_left(browser.path or ".", 26), up_x + up_w + 8, up_y + 6)

        local cx = BROWSER_W - toggle_w - 6
        draw_button("<", cx, toggle_y, toggle_w, toggle_h)
        register_button("browser_toggle", cx, toggle_y, toggle_w, toggle_h)

        local list_top = HEADER_H + 40
        local list_bottom = screen_h - BOTTOM_BAR
        local y = list_top - (browser.scroll_y or 0)
        for _, entry in ipairs(browser.entries or {}) do
            if y > list_top - ROW_H and y < list_bottom then
                local label = entry.kind == "dir" and (entry.name .. "/") or entry.name
                if entry.kind == "dir" then
                    love.graphics.setColor(0.5, 0.8, 1.0, 1.0)
                elseif entry.name:sub(-4) == ".lua" then
                    love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
                else
                    love.graphics.setColor(0.4, 0.4, 0.45, 1.0)
                end
                love.graphics.print(label, 18, y + 4)
                if entry.kind == "dir" or entry.name:sub(-4) == ".lua" then
                    register_button("browser_entry", 8, y, BROWSER_W - 16, ROW_H, entry)
                end
            end
            y = y + ROW_H
        end

        if browser.error ~= "" then
            love.graphics.setColor(1.0, 0.6, 0.3, 1.0)
            love.graphics.print(browser.error, 18, list_top + 4)
        end
    end

    -- ===== Findings panel (right), grouped by category =====
    local findings = ctx.state.results or {}
    local clip_top = HEADER_H
    local clip_bottom = screen_h - BOTTOM_BAR

    if ctx.state.scanned_file ~= "" and #findings == 0 then
        love.graphics.setColor(0.5, 0.7, 0.5, 1.0)
        love.graphics.print("No findings for profile: " .. active_platform, findings_x, HEADER_H + 12)
    end

    local ordered_cats, by_cat = build_category_groups(findings)
    ctx.state.category_collapsed = ctx.state.category_collapsed or {}

    local cy = HEADER_H + 8 - (ctx.state.scroll_y or 0)
    for _, cat in ipairs(ordered_cats) do
        local rows = by_cat[cat]
        local collapsed = ctx.state.category_collapsed[cat] == true
        local marker = collapsed and "[+]" or "[-]"

        if cy > clip_top - GROUP_H and cy < clip_bottom then
            love.graphics.setColor(0.8, 0.85, 1.0, 1.0)
            love.graphics.print(
                string.format("%s %s (%d)", marker, cat, #rows),
                findings_x, cy + 4
            )
        end
        register_button("category_toggle", findings_x - 10, cy, screen_w - findings_x - 10, GROUP_H, cat)
        cy = cy + GROUP_H

        if not collapsed then
            for _, r in ipairs(rows) do
                if cy > clip_top - FINDING_H and cy < clip_bottom then
                    severity_color(r.severity)
                    local prefix = r.hot and "[HOT] " or ""
                    local line_label = string.format(
                        "%sL%d: [%s] [%s] %s",
                        prefix,
                        r.line or 0,
                        tostring(r.severity or "info"):upper(),
                        tostring(r.rule_id or "?"),
                        r.msg or ""
                    )
                    love.graphics.print(line_label, findings_x, cy)
                    love.graphics.setColor(0.4, 0.4, 0.45, 1.0)
                    love.graphics.print(r.source or "", findings_x + 20, cy + 16)
                end
                cy = cy + FINDING_H
            end
        end
        cy = cy + 6
    end

    -- ===== Bottom buttons (right of the browser panel) =====
    local button_y = screen_h - 50
    local json_x = findings_x
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

    -- ===== Sentinel Telemetry Overlay =====
    if ctx.sentinel and ctx.sentinel.get_report then
        local report = ctx.sentinel.get_report()
        local tx = screen_w - 280
        local ty = screen_h - 100
        love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
        love.graphics.print("--- Sentinel Telemetry ---", tx, ty)
        ty = ty + 16
        for name, data in pairs(report) do
            love.graphics.print(string.format(
                "[%s] max: %.4fs | gc: %.2fKB | n: %d",
                name, data.max_time, data.max_gc_delta, data.count
            ), tx, ty)
            ty = ty + 16
        end
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
            elseif b.id == "profile_select" then
                ctx.config = ctx.config or {}
                local new_platform = b.payload
                if ctx.config.platform ~= new_platform then
                    ctx.config.platform = new_platform
                    if ctx.state.scanned_file ~= "" and ctx.scan_file then
                        ctx.scan_file(ctx.state.scanned_file)
                    end
                end
                return
            elseif b.id == "category_toggle" then
                ctx.state.category_collapsed = ctx.state.category_collapsed or {}
                local cat = b.payload
                ctx.state.category_collapsed[cat] = not (ctx.state.category_collapsed[cat] == true)
                return
            elseif b.id == "browser_toggle" then
                ctx.state.browser = ctx.state.browser or {}
                ctx.state.browser.collapsed = not (ctx.state.browser.collapsed == true)
                return
            elseif b.id == "browser_up" then
                ctx.browser.up()
                return
            elseif b.id == "browser_entry" then
                ctx.browser.activate(b.payload)
                return
            end
        end
    end
end