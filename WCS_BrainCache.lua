--[[
    WCS_BrainCache.lua - Sistema de Cache y Optimización v6.6.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema de cache para optimizar llamadas costosas
    
    Autor: Elnazzareno (DarckRovert)
    Twitch: twitch.tv/darckrovert
    Kick: kick.com/darckrovert
]]--

WCS_BrainCache = WCS_BrainCache or {}
WCS_BrainCache.VERSION = "6.6.0"

-- ============================================================================
-- CONFIGURACIÓN
-- ============================================================================
WCS_BrainCache.Config = {
    enabled = true,
    defaultTTL = 0.5,  -- 500ms por defecto
    maxCacheSize = 100,
    autoCleanup = true,
    cleanupInterval = 60  -- Limpiar cada 60 segundos
}

-- ============================================================================
-- ALMACENAMIENTO DE CACHE
-- ============================================================================
WCS_BrainCache.Storage = {}
WCS_BrainCache.Stats = {
    hits = 0,
    misses = 0,
    evictions = 0
}

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainCache:Initialize()
    self.Storage = {}
    self.Stats = { hits = 0, misses = 0, evictions = 0 }
    
    -- Iniciar limpieza automática
    if self.Config.autoCleanup then
        self:StartAutoCleanup()
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Cache", "Sistema de cache inicializado")
    end
end

-- ============================================================================
-- OPERACIONES DE CACHE
-- ============================================================================
function WCS_BrainCache:Get(key)
    if not self.Config.enabled then
        return nil
    end
    
    local entry = self.Storage[key]
    
    if not entry then
        self.Stats.misses = self.Stats.misses + 1
        return nil
    end
    
    -- Verificar TTL
    local now = GetTime()
    if entry.expiry and now > entry.expiry then
        -- Cache expirado
        self.Storage[key] = nil
        self.Stats.misses = self.Stats.misses + 1
        return nil
    end
    
    -- Cache hit
    self.Stats.hits = self.Stats.hits + 1
    entry.lastAccess = now
    return entry.data
end

function WCS_BrainCache:Set(key, data, ttl)
    if not self.Config.enabled then
        return
    end
    
    ttl = ttl or self.Config.defaultTTL
    local now = GetTime()
    
    self.Storage[key] = {
        data = data,
        timestamp = now,
        expiry = ttl and (now + ttl) or nil,
        lastAccess = now
    }
    
    -- Verificar tamaño del cache
    self:CheckCacheSize()
end

function WCS_BrainCache:Has(key)
    return self:Get(key) ~= nil
end

function WCS_BrainCache:Delete(key)
    if self.Storage[key] then
        self.Storage[key] = nil
        return true
    end
    return false
end

function WCS_BrainCache:Clear()
    self.Storage = {}
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Cache", "Cache limpiado")
    end
end

-- ============================================================================
-- GESTIÓN DE TAMAÑO
-- ============================================================================
function WCS_BrainCache:CheckCacheSize()
    local count = 0
    for _ in pairs(self.Storage) do
        count = count + 1
    end
    
    if count > self.Config.maxCacheSize then
        self:EvictOldest()
    end
end

function WCS_BrainCache:EvictOldest()
    local oldest = nil
    local oldestTime = nil
    
    for key, entry in pairs(self.Storage) do
        if not oldestTime or entry.lastAccess < oldestTime then
            oldest = key
            oldestTime = entry.lastAccess
        end
    end
    
    if oldest then
        self.Storage[oldest] = nil
        self.Stats.evictions = self.Stats.evictions + 1
    end
end

-- ============================================================================
-- LIMPIEZA AUTOMÁTICA
-- ============================================================================
function WCS_BrainCache:StartAutoCleanup()
    if not self.cleanupFrame then
        self.cleanupFrame = CreateFrame("Frame")
        self.cleanupFrame.elapsed = 0
        
        self.cleanupFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= WCS_BrainCache.Config.cleanupInterval then
                this.elapsed = 0
                WCS_BrainCache:CleanupExpired()
            end
        end)
    end
end

function WCS_BrainCache:CleanupExpired()
    local now = GetTime()
    local cleaned = 0
    
    for key, entry in pairs(self.Storage) do
        if entry.expiry and now > entry.expiry then
            self.Storage[key] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 and WCS_BrainLogger then
        WCS_BrainLogger:Debug("Cache", "Limpiadas " .. cleaned .. " entradas expiradas")
    end
end

-- ============================================================================
-- ESTADÍSTICAS
-- ============================================================================
function WCS_BrainCache:GetStats()
    local total = self.Stats.hits + self.Stats.misses
    local hitRate = total > 0 and (self.Stats.hits / total * 100) or 0
    
    return {
        hits = self.Stats.hits,
        misses = self.Stats.misses,
        evictions = self.Stats.evictions,
        hitRate = hitRate,
        size = self:GetSize()
    }
end

function WCS_BrainCache:GetSize()
    local count = 0
    for _ in pairs(self.Storage) do
        count = count + 1
    end
    return count
end

function WCS_BrainCache:ResetStats()
    self.Stats = { hits = 0, misses = 0, evictions = 0 }
end

-- ============================================================================
-- FUNCIONES HELPER PARA CACHEAR FUNCIONES
-- ============================================================================
function WCS_BrainCache:Memoize(func, ttl)
    return function(...)
        local args = arg
        local key = "memoize_" .. tostring(func)
        for i = 1, table.getn(args) do
            key = key .. "_" .. tostring(args[i])
        end
        
        local cached = self:Get(key)
        if cached ~= nil then
            return cached
        end
        
        local result = func(unpack(args))
        self:Set(key, result, ttl)
        return result
    end
end

-- ============================================================================
-- CACHE ESPECÍFICO PARA WCS_BRAIN
-- ============================================================================

-- Cache de información del target
function WCS_BrainCache:GetTargetInfo()
    local cached = self:Get("targetInfo")
    if cached then return cached end
    
    if not UnitExists("target") then
        return nil
    end
    
    local info = {
        exists = true,
        name = UnitName("target"),
        level = UnitLevel("target"),
        health = UnitHealth("target"),
        healthMax = UnitHealthMax("target"),
        healthPct = (UnitHealth("target") / UnitHealthMax("target")) * 100,
        isHostile = UnitCanAttack("player", "target"),
        isDead = UnitIsDead("target"),
        classification = UnitClassification("target"),
        isPlayer = UnitIsPlayer("target"),
        class = UnitClass("target")
    }
    
    self:Set("targetInfo", info, 0.1)  -- Cache por 100ms
    return info
end

-- Cache de información del jugador
function WCS_BrainCache:GetPlayerInfo()
    local cached = self:Get("playerInfo")
    if cached then return cached end
    
    local info = {
        health = UnitHealth("player"),
        healthMax = UnitHealthMax("player"),
        healthPct = (UnitHealth("player") / UnitHealthMax("player")) * 100,
        mana = UnitMana("player"),
        manaMax = UnitManaMax("player"),
        manaPct = (UnitMana("player") / UnitManaMax("player")) * 100,
        inCombat = UnitAffectingCombat("player"),
        isDead = UnitIsDead("player")
    }
    
    self:Set("playerInfo", info, 0.1)  -- Cache por 100ms
    return info
end

-- Cache de información de la mascota
function WCS_BrainCache:GetPetInfo()
    local cached = self:Get("petInfo")
    if cached then return cached end
    
    if not UnitExists("pet") then
        return nil
    end
    
    local info = {
        exists = true,
        name = UnitName("pet"),
        health = UnitHealth("pet"),
        healthMax = UnitHealthMax("pet"),
        healthPct = (UnitHealth("pet") / UnitHealthMax("pet")) * 100,
        mana = UnitMana("pet"),
        manaMax = UnitManaMax("pet"),
        manaPct = UnitManaMax("pet") > 0 and (UnitMana("pet") / UnitManaMax("pet")) * 100 or 0,
        isDead = UnitIsDead("pet")
    }
    
    self:Set("petInfo", info, 0.1)  -- Cache por 100ms
    return info
end

-- Cache de costos de hechizos
function WCS_BrainCache:GetSpellCost(spellName)
    -- NOTA: GetSpellInfo no existe en WoW 1.12
    -- No hay forma directa de obtener el costo de mana desde la API
    -- Retornar 0 por ahora (se puede implementar una tabla manual si es necesario)
    return 0
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSCACHE1 = "/wcscache"
SLASH_WCSCACHE2 = "/braincache"

SlashCmdList["WCSCACHE"] = function(msg)
    if msg == "stats" then
        local stats = WCS_BrainCache:GetStats()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Cache]|r Estadísticas:")
        DEFAULT_CHAT_FRAME:AddMessage("  Hits: " .. stats.hits)
        DEFAULT_CHAT_FRAME:AddMessage("  Misses: " .. stats.misses)
        DEFAULT_CHAT_FRAME:AddMessage("  Hit Rate: " .. string.format("%.1f%%", stats.hitRate))
        DEFAULT_CHAT_FRAME:AddMessage("  Evictions: " .. stats.evictions)
        DEFAULT_CHAT_FRAME:AddMessage("  Size: " .. stats.size .. "/" .. WCS_BrainCache.Config.maxCacheSize)
        
    elseif msg == "clear" then
        WCS_BrainCache:Clear()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Cache]|r Cache limpiado")
        
    elseif msg == "reset" then
        WCS_BrainCache:ResetStats()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Cache]|r Estadísticas reseteadas")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Cache]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braincache stats|r - Ver estadísticas")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braincache clear|r - Limpiar cache")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braincache reset|r - Resetear estadísticas")
    end
end

-- ============================================================================
-- AUTO-INICIALIZACIÓN
-- ============================================================================
local function OnLoad()
    WCS_BrainCache:Initialize()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        OnLoad()
    end
end)

