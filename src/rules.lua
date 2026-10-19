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