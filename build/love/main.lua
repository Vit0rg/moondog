-- ==========================================================
-- moondog: Lua Code-Smell Detector & Anti-Pattern Indicator
-- Paradigm: Hack and Harden (H2) / Lexical Data-Oriented Design (L-DOD)
-- Target: love
-- Built: 2026-09-09T12:39:55Z
-- Manifest: scripts/manifests/love_manifest.txt
-- ==========================================================

-- ==========================================
-- FILE: src/main.lua
-- ==========================================
-- ============================================
-- PHASE 1: THE HACK — Lua Code-Smell Detector
-- Mindset: Extreme velocity. Zero abstractions.
-- ============================================

-- Naive pattern rules (Cold Path — ugly is fine)
local rules = {
    { pattern = "table%.insert",   severity = "warning",  msg = "Prefer t[#t+1] = val for append" },
    { pattern = "table%.remove",   severity = "critical", msg = "O(N) shift — consider swap-and-pop" },
    { pattern = "pairs%(",         severity = "warning",  msg = "Dict iteration — prefer numeric for in hot paths" },
    { pattern = "ipairs%(",        severity = "info",     msg = "Consider numeric for i=1,#t for performance" },
    { pattern = "%.%.%.",          severity = "warning",  msg = "Varargs cause hidden allocations in hot paths" },
    { pattern = "string%.format",  severity = "info",     msg = "Allocates a new string — avoid in hot loops" },
    { pattern = "setmetatable",    severity = "info",     msg = "OOP abstraction — verify it's not in a hot path" },
    { pattern = "collectgarbage",  severity = "warning",  msg = "Manual GC call — usually a band-aid" },
    { pattern = "%-%- @hotpath",   severity = "info",     msg = "Hot path marker found — lint strictly" },
}

local results = {}       -- Naive result table (will allocate like crazy)
local scroll_y = 0
local scanned_file = ""

-- NAIVE SCANNER — allocations everywhere, string concat, table.insert
function scan_file(filepath)
    results = {}  -- FATAL: throws away old table, GC pressure
    scanned_file = filepath

    local file = io.open(filepath, "r")
    if not file then return end

    local line_num = 0
    local in_hotpath = false

    for line in file:lines() do
        line_num = line_num + 1

        if line:find("%-%- @hotpath") then in_hotpath = true end
        if line:find("%-%- @coldpath") then in_hotpath = false end

        for _, rule in ipairs(rules) do  -- ipairs in a loop: fine for cold path
            if line:find(rule.pattern) then
                -- FATAL: table.insert shifts memory, string.format allocates
                table.insert(results, {
                    line = line_num,
                    severity = rule.severity,
                    msg = rule.msg,
                    source = line,
                    hot = in_hotpath
                })
            end
        end
    end
    file:close()
end

-- NAIVE RENDERER — runs every frame, allocates strings, uses pairs
function love.draw()
    love.graphics.setColor(0.1, 0.1, 0.12)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Lua Code-Smell Detector (HACK PHASE)", 20, 10)
    love.graphics.print("Drop a .lua file to scan | Scrolling: mouse wheel", 20, 30)

    if scanned_file ~= "" then
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.print("File: " .. scanned_file .. " | Findings: " .. #results, 20, 55)
    end

    local y = 80 - scroll_y
    for i, r in ipairs(results) do  -- ipairs every frame: fine for now
        if y > 60 and y < love.graphics.getHeight() then
            -- Color by severity (allocates nothing, but string concat does)
            if r.severity == "critical" then
                love.graphics.setColor(1, 0.3, 0.3)
            elseif r.severity == "warning" then
                love.graphics.setColor(1, 0.8, 0.2)
            else
                love.graphics.setColor(0.5, 0.7, 1)
            end

            local prefix = r.hot and "[HOT] " or ""
            -- FATAL: string concatenation every frame = GC pressure
            love.graphics.print(
                prefix .. "L" .. r.line .. ": [" .. r.severity:upper() .. "] " .. r.msg,
                30, y
            )
            love.graphics.setColor(0.4, 0.4, 0.45)
            love.graphics.print(r.source, 50, y + 16)
        end
        y = y + 40
    end
end

function love.filedropped(file)
    file:open("r")
    local path = file:getFilename()
    file:close()
    scan_file(path)
end

function love.wheelmoved(x, y)
    scroll_y = scroll_y - y * 40
    if scroll_y < 0 then scroll_y = 0 end
end



-- ==========================================
-- FILE: src/rules.lua
-- ==========================================


-- ==========================================
-- FILE: src/scanner.lua
-- ==========================================


-- ==========================================
-- FILE: src/ui.lua
-- ==========================================


-- ==========================================
-- FILE: src/renderer.lua
-- ==========================================



-- [BUILD-TIME OVERRIDE] LÖVE Environment Initialization
_G.ctx = _G.ctx or {}
ctx.is_love = true
