-- ==========================================================
-- moondog: Lua Code-Smell Detector & Anti-Pattern Indicator
-- Paradigm: Hack and Harden (H2) / Lexical Data-Oriented Design (L-DOD)
-- Target: love
-- Built: 2026-10-21T04:33:53Z
-- Manifest: scripts/manifests/love_manifest.txt
-- ==========================================================

-- ==========================================
-- FILE: src/rules.lua
-- ==========================================

ctx = ctx or {}

ctx.config = ctx.config or {
    platform = "lua51"
}

ctx.rule_profiles = {
    lua51 = {
        ldod_hash_iteration = "critical",
        ldod_string_key_loop = "critical",
        ldod_table_remove_loop = "critical",
        ldod_coroutine_hotpath = "fatal",
        ldod_alloc_in_loop = "critical",
        ldod_module_call = "warning",
        ldod_upvalue_heavy_loop = "info"
    },
    lua54 = {
        ldod_hash_iteration = "warning",
        ldod_string_key_loop = "warning",
        ldod_table_remove_loop = "warning",
        ldod_coroutine_hotpath = "critical",
        ldod_alloc_in_loop = "warning",
        ldod_upvalue_heavy_loop = "ignore"
    },
    luajit = {
        ldod_coroutine_hotpath = "fatal",
        ldod_upvalue_heavy_loop = "warning",
        ldod_dynamic_key_concat = "critical",
        ldod_hash_iteration = "warning",
        ldod_module_call = "ignore",
        ldod_string_key_loop = "info"
    },
    luajit_openresty = {
        ldod_alloc_in_loop = "critical",
        ldod_coroutine_hotpath = "fatal",
        ldod_upvalue_heavy_loop = "warning",
        ldod_dynamic_key_concat = "critical",
        ldod_module_call = "ignore"
    }
}

ctx.rules = {
    -- ==========================================
    -- Legacy Rules (v0.2.0 baseline preserved)
    -- ==========================================
    {
        id = "table_insert",
        category = "Memory",
        pattern = "table%.insert%s*%(",
        requires_loop = false,
        severity = "warning",
        msg = "table.insert shifts elements (O(N)). Consider swap-and-pop.",
        description = "table.insert shifts elements (O(N)).",
        fix = "Consider swap-and-pop or Pool-Array-Map."
    },
    {
        id = "table_remove",
        category = "Algorithmic",
        pattern = "table%.remove%s*%(",
        requires_loop = false,
        severity = "critical",
        msg = "table.remove shifts elements (O(N)). Consider swap-and-pop.",
        description = "table.remove shifts elements (O(N)).",
        fix = "Consider swap-and-pop."
    },
    {
        id = "pairs_iteration",
        category = "Algorithmic",
        pattern = "for%s+.-%s+in%s+pairs%s*%(",
        requires_loop = false,
        severity = "info",
        msg = "pairs() incurs hash iteration overhead.",
        description = "pairs() incurs hash iteration overhead.",
        fix = "Prefer numeric for loops over flat arrays."
    },
    {
        id = "ipairs_iteration",
        category = "Algorithmic",
        pattern = "for%s+.-%s+in%s+ipairs%s*%(",
        requires_loop = false,
        severity = "info",
        msg = "ipairs() function call overhead.",
        description = "ipairs() function call overhead.",
        fix = "Prefer numeric for loops."
    },
    {
        id = "varargs",
        category = "Architecture",
        pattern = "%.%.%.",
        requires_loop = false,
        severity = "info",
        msg = "Varargs (...) allocation overhead.",
        description = "Varargs (...) allocation overhead.",
        fix = "Avoid in hot paths."
    },
    {
        id = "string_format",
        category = "Architecture",
        pattern = "string%.format%s*%(",
        requires_loop = false,
        severity = "warning",
        msg = "string.format allocates new strings.",
        description = "string.format allocates new strings.",
        fix = "Avoid in hot paths."
    },
    {
        id = "setmetatable",
        category = "Architecture",
        pattern = "setmetatable%s*%(",
        requires_loop = false,
        severity = "warning",
        msg = "setmetatable can break trace stability in JIT.",
        description = "setmetatable can break trace stability in JIT.",
        fix = "Apply metatables at instantiation, not in hot paths."
    },
    {
        id = "collectgarbage",
        category = "Architecture",
        pattern = "collectgarbage%s*%(",
        requires_loop = false,
        severity = "critical",
        msg = "collectgarbage forces GC pause.",
        description = "collectgarbage forces GC pause.",
        fix = "Do not call in hot paths."
    },
    {
        id = "hotpath_marker",
        category = "Marker",
        pattern = "--%s*@hotpath",
        requires_loop = false,
        severity = "info",
        msg = "Hot path marker detected.",
        description = "Hot path marker detected.",
        fix = "Optimize this block."
    },

    -- ==========================================
    -- Empirical L-DOD Rules (v0.3.0 Phase 1)
    -- ==========================================
    {
        id = "ldod_hash_iteration",
        category = "Algorithmic",
        pattern = "for%s+.-%s+in%s+pairs%s*%(",
        requires_loop = false,
        description = "pairs() incurs hash iteration overhead.",
        fix = "Prefer numeric for loops over flat arrays."
    },
    {
        id = "ldod_table_remove_loop",
        category = "Algorithmic",
        pattern = "table%.remove%s*%(",
        requires_loop = true,                                 -- Disabled until loop tracker exists
        description = "table.remove inside loop causes O(N^2) shifts.",
        fix = "Use swap-and-pop or defer removals."
    },
    {
        id = "ldod_coroutine_hotpath",
        category = "Architecture",
        pattern = "coroutine%.[a-z]+%s*%(",
        requires_loop = false,
        description = "Coroutine creation/resume overhead in hot paths.",
        fix = "Use persistent coroutines or direct function calls."
    },
    {
        id = "ldod_module_call",
        category = "Architecture",
        pattern = "[%w_]+%.[%w_]+%s*%(",
        requires_loop = false,                                  -- Broad Phase 1 pattern
        description = "Module table lookup overhead.",
        fix = "Cache module functions as upvalues locally."
    },
    {
        id = "ldod_dynamic_key_concat",
        category = "Memory",
        pattern = "%.%.%s*[%w_]+%s*%]%s*=",
        requires_loop = false,
        description = "Dynamic key concatenation allocates strings.",
        fix = "Use numeric IDs or cache string keys."
    },

    -- Loop-Context Rules (Disabled until Priority 3)
    {
        id = "ldod_alloc_in_loop",
        category = "Memory",
        pattern = "local%s+[%w_]+%s*=%s*{",
        requires_loop = true,
        description = "Table allocation inside loop causes GC pressure.",
        fix = "Pre-allocate or reuse tables."
    },
    {
        id = "ldod_string_key_loop",
        category = "Algorithmic",
        pattern = "[%w_]+%[[\"'][^\"']+[\"']%]",
        requires_loop = true,
        description = "String key lookup in loop incurs hashing overhead.",
        fix = "Use numeric indices or upvalues."
    },
    {
        id = "ldod_upvalue_heavy_loop",
        category = "Architecture",
        pattern = "function%s*%(",
        requires_loop = true,
        description = "Heavy upvalue access in loop.",
        fix = "Localize upvalues before the loop."
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

ctx.config = ctx.config or {}
ctx.config.platform = ctx.config.platform or "lua51"

local function trim(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Phase 1 guard: `ldod_module_call` overmatches function declarations.
-- Lua patterns have no lookbehind, so exclusions are resolved at the
-- line level. Declarations are never table lookups and are not findings.
local DECL_PATTERN = "^%s*(local%s+)?function[%w_%.:]*%s*%("

-- Phase 1 naive loop tracker. Whole-word keyword counting per line.
-- Ugly by design: false positives inside strings or comments are
-- acceptable until Sentinel and fixtures prove a better approach is needed.
-- Increment on: for, while, repeat. Decrement on: end, until.
local function count_matches(s, pat)
    local n = 0
    for _ in s:gmatch(pat) do
        n = n + 1
    end
    return n
end

local function loop_open_count(line)
    return count_matches(line, "%f[%w]for%f[%W]")
         + count_matches(line, "%f[%w]while%f[%W]")
         + count_matches(line, "%f[%w]repeat%f[%W]")
end

local function loop_close_count(line)
    return count_matches(line, "%f[%w]end%f[%W]")
         + count_matches(line, "%f[%w]until%f[%W]")
end

-- Harden: normalize the ruleset once per scan and resolve platform severities.
-- Guards against leading/trailing whitespace in rules.lua string fields.
-- Untrimmed patterns under-match (e.g. "table%.insert " would require a
-- trailing space that real code never has). Untrimmed msg/id/category
-- would otherwise pollute the JSON/TXT export and CLI output.
local function build_active_rules()
    local active = {}
    local platform = ctx.config.platform
    local profile = ctx.rule_profiles and ctx.rule_profiles[platform] or {}

    for _, rule in ipairs(ctx.rules or {}) do
        local id = trim(rule.id)

        -- Resolve severity: platform profile overrides the rule default.
        local severity = trim(rule.severity or "info")
        if id ~= "" and profile[id] then
            severity = trim(profile[id])
        end

        -- Profile opt-out: strip the pattern so the rule can never match.
        local pat = trim(rule.pattern or "")
        if severity == "ignore" then
            pat = ""
        end

        if pat ~= "" then
            local msg = trim(rule.msg)
            if msg == "" then
                msg = trim(rule.description)
            end
            if msg == "" then
                msg = "Performance anti-pattern detected."
            end

            active[#active + 1] = {
                pattern   = pat,
                severity  = severity,
                msg       = msg,
                id        = (id ~= "" and id or pat),
                category  = (trim(rule.category) ~= "" and trim(rule.category) or "Unknown"),
                -- Priority 3: loop-context rules are no longer stripped at
                -- build time. Gating moved to scan time via loop_depth.
                requires_loop = rule.requires_loop and true or false,
                guard_decl = (id == "ldod_module_call"),
            }
        end
    end
    return active
end

function ctx.scan_file(filepath)
    if ctx.sentinel and ctx.sentinel.start_phase then
        ctx.sentinel.start_phase("scan")
    end

    local findings = {}
    local file = io.open(filepath, "r")
    if not file then
        ctx.state.scanned_file = filepath
        ctx.state.results = findings
        ctx.state.scroll_y = 0
        if ctx.sentinel and ctx.sentinel.end_phase then ctx.sentinel.end_phase("scan") end
        return
    end

    local active_rules = build_active_rules()
    local line_num = 0
    local in_hotpath = false
    local loop_depth = 0

    for line in file:lines() do
        line_num = line_num + 1
        if line:find("%-%- @hotpath") then in_hotpath = true end
        if line:find("%-%- @coldpath") then in_hotpath = false end

        local is_decl = line:find(DECL_PATTERN) ~= nil
        loop_depth = loop_depth + loop_open_count(line)

        for _, rule in ipairs(active_rules) do
            local matched = line:find(rule.pattern) ~= nil
            if matched and rule.guard_decl and is_decl then matched = false end
            if matched and rule.requires_loop and loop_depth < 1 then matched = false end
            if matched then
                findings[#findings + 1] = {
                    line = line_num, severity = rule.severity, msg = rule.msg,
                    source = line, hot = in_hotpath, rule_id = rule.id, category = rule.category,
                }
            end
        end

        loop_depth = loop_depth - loop_close_count(line)
        if loop_depth < 0 then loop_depth = 0 end
    end
    file:close()

    ctx.state.scanned_file = filepath
    ctx.state.results = findings
    ctx.state.scroll_y = 0

    if ctx.sentinel and ctx.sentinel.end_phase then
        ctx.sentinel.end_phase("scan")
    end
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
-- ==========================================
-- FILE: src/sentinel.lua
-- ==========================================
-- src/sentinel.lua
-- Micro-Sentinel for Hack & Harden Phase 2 profiling.
-- Measures max execution time and max GC delta per named phase.
-- The Sentinel decides, not intuition.
ctx = ctx or {}
ctx.sentinel = ctx.sentinel or {}

-- Portable clock: prefer love.timer.getTime for wall-clock accuracy in LÖVE,
-- fall back to os.clock for headless CLI builds.
local clock = (love and love.timer and love.timer.getTime) or os.clock

local phases = {}

function ctx.sentinel.start_phase(name)
    phases[name] = phases[name] or {
        max_time = 0,
        max_gc_delta = 0,
        count = 0
    }
    local p = phases[name]
    p.start_time = clock()
    p.start_gc = collectgarbage("count")
end

function ctx.sentinel.end_phase(name)
    local p = phases[name]
    if not p or not p.start_time then return end

    local dt = clock() - p.start_time
    local dgc = collectgarbage("count") - p.start_gc

    if dt > p.max_time then p.max_time = dt end
    if dgc > p.max_gc_delta then p.max_gc_delta = dgc end
    p.count = p.count + 1

    p.start_time = nil
    p.start_gc = nil
end

function ctx.sentinel.get_report()
    return phases
end
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

-- [BUILD-TIME OVERRIDE] LOVE Environment Initialization
_G.ctx = _G.ctx or {}
ctx.is_love = true
