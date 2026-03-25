--[[
    WCS_Helpers.lua - Centralized Lua 5.0 Compatibility Helpers
    
    PURPOSE:
    This module provides a single point of definition for Lua 5.0 compatibility
    helpers used throughout the WCS_Brain addon. By centralizing these functions,
    we reduce code duplication, improve maintainability, and ensure consistent
    behavior across the codebase.
    
    HELPERS PROVIDED:
    - WCS_TableCount(t): Safe table element count (replaces table.getn)
    - WCS_Helpers.Unpack(tbl): Safe unpack wrapper (Lua 5.0 compat)
    - WCS_Helpers.SafeArg(argtable): Validate and return arg table safely
    - WCS_Helpers.VersionTag(name, ver): Generate version tag string
    
    GLOBAL EXPORTS (for convenience):
    - WCS_TableCount: Alias for WCS_Helpers.TableCount
    - WCS_UnpackSafe: Alias for WCS_Helpers.Unpack
    
    CONSOLIDATION NOTE (December 2024):
    All Lua 5.0 compatibility shims that were previously scattered in hotfix
    files (WCS_HotFix_v6.*.lua) are now centralized here. Hotfix files should
    fallback to this module before trying inline implementations.
    
    LOAD ORDER:
    This file should be loaded EARLY, before hotfixes and before most game code,
    so that all modules can depend on WCS_TableCount being available.
    
    IMPLEMENTATION:
    - WCS_TableCount: Uses table.getn if available, else iterates pairs()
    - Unpack/SafeArg: Defensive fallbacks for Lua 5.0
    - VersionTag: Simple string utility
]]--

-- Helpers for Lua 5.0 compatibility and small utilities
WCS_Helpers = WCS_Helpers or {}
WCS_Helpers.VERSION = "6.6.0"

function WCS_Helpers.TableCount(t)
    if not t then return 0 end
    if table.getn then return table.getn(t) end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function WCS_Helpers.Unpack(tbl)
    if not tbl then return end
    if unpack then return unpack(tbl) end
    -- fallback: return nil (caller should handle)
    return nil
end

function WCS_Helpers.SafeArg(argtable)
    if type(argtable) == "table" then return argtable end
    return {}
end

function WCS_Helpers.VersionTag(name, ver)
    return (name or "") .. "::v" .. (ver or "0")
end

-- Export short aliases for convenience
WCS_TableCount = WCS_Helpers.TableCount
WCS_UnpackSafe = WCS_Helpers.Unpack
