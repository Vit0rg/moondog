
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
