
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