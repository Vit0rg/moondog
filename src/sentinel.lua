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