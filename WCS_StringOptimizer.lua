--[[
    WCS_StringOptimizer.lua - Optimizaciones de String Operations
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 6.4.2 - Optimización de Rendimiento
]]--

WCS_StringOptimizer = WCS_StringOptimizer or {}
WCS_StringOptimizer.VERSION = "6.4.2"

-- ============================================================================
-- CACHÉ DE PATRONES COMPILADOS
-- ============================================================================

WCS_StringOptimizer.PatternCache = {
    -- Patrones de texturas de mascotas
    imp_patterns = {"FireBolt", "FireShield"},
    voidwalker_patterns = {"Torment", "Sacrifice", "ConsumeShadows"},
    succubus_patterns = {"LashOfPain", "Seduction"},
    felhunter_patterns = {"SpellLock", "DevourMagic"},
    
    -- Patrones de items
    soul_shard_pattern = "Soul Shard",
    healthstone_pattern = "Healthstone",
    
    -- Caché de resultados de búsqueda
    texture_cache = {},
    item_cache = {}
}

-- ============================================================================
-- FUNCIONES OPTIMIZADAS DE STRING
-- ============================================================================

-- Función optimizada para detectar tipo de mascota por textura
function WCS_StringOptimizer:GetPetTypeByTexture(texture)
    if not texture then return "unknown" end
    
    -- Verificar caché primero
    if self.PatternCache.texture_cache[texture] then
        return self.PatternCache.texture_cache[texture]
    end
    
    local petType = "unknown"
    
    -- Usar búsquedas optimizadas
    for i, pattern in ipairs(self.PatternCache.imp_patterns) do
        if string.find(texture, pattern) then
            petType = "imp"
            break
        end
    end
    
    if petType == "unknown" then
        for i, pattern in ipairs(self.PatternCache.voidwalker_patterns) do
            if string.find(texture, pattern) then
                petType = "voidwalker"
                break
            end
        end
    end
    
    if petType == "unknown" then
        for i, pattern in ipairs(self.PatternCache.succubus_patterns) do
            if string.find(texture, pattern) then
                petType = "succubus"
                break
            end
        end
    end
    
    if petType == "unknown" then
        for i, pattern in ipairs(self.PatternCache.felhunter_patterns) do
            if string.find(texture, pattern) then
                petType = "felhunter"
                break
            end
        end
    end
    
    -- Guardar en caché
    self.PatternCache.texture_cache[texture] = petType
    return petType
end

-- Función optimizada para verificar Soul Shards
function WCS_StringOptimizer:IsSoulShard(link)
    if not link then return false end
    
    -- Verificar caché
    if self.PatternCache.item_cache[link] ~= nil then
        return self.PatternCache.item_cache[link]
    end
    
    local result = string.find(link, self.PatternCache.soul_shard_pattern) ~= nil
    self.PatternCache.item_cache[link] = result
    return result
end

-- Función optimizada para verificar Healthstones
function WCS_StringOptimizer:IsHealthstone(link)
    if not link then return false end
    
    -- Verificar caché
    if self.PatternCache.item_cache[link] ~= nil then
        return self.PatternCache.item_cache[link]
    end
    
    local result = string.find(link, self.PatternCache.healthstone_pattern) ~= nil
    self.PatternCache.item_cache[link] = result
    return result
end

-- Función optimizada para comandos (case-insensitive)
function WCS_StringOptimizer:ParseCommand(msg)
    if not msg then return "" end
    
    -- Convertir a minúsculas una sola vez
    local cmd = string.lower(msg)
    
    -- Eliminar espacios al inicio y final
    cmd = string.gsub(cmd, "^%s*(.-)%s*$", "%1")
    
    return cmd
end

-- ============================================================================
-- FUNCIONES DE UTILIDAD OPTIMIZADAS
-- ============================================================================

-- Función para limpiar caché cuando sea necesario
function WCS_StringOptimizer:ClearCache()
    self.PatternCache.texture_cache = {}
    self.PatternCache.item_cache = {}
end

-- Función para obtener estadísticas de caché
function WCS_StringOptimizer:GetCacheStats()
    local textureCount = 0
    local itemCount = 0
    
    for k, v in pairs(self.PatternCache.texture_cache) do
        textureCount = textureCount + 1
    end
    
    for k, v in pairs(self.PatternCache.item_cache) do
        itemCount = itemCount + 1
    end
    
    return {
        textureCache = textureCount,
        itemCache = itemCount,
        totalEntries = textureCount + itemCount
    }
end

-- Función para limitar el tamaño del caché
function WCS_StringOptimizer:LimitCacheSize(maxEntries)
    maxEntries = maxEntries or 100
    
    local stats = self:GetCacheStats()
    if stats.totalEntries > maxEntries then
        -- Limpiar caché más antiguo (simple: limpiar todo)
        self:ClearCache()
    end
end

-- ============================================================================
-- INTEGRACIÓN CON SISTEMA EXISTENTE
-- ============================================================================

-- Reemplazar funciones existentes con versiones optimizadas
function WCS_StringOptimizer:Initialize()
    -- Backup de funciones originales si existen
    if WCS_Brain and WCS_Brain.GetPetTypeByTexture then
        WCS_Brain.GetPetTypeByTexture_Original = WCS_Brain.GetPetTypeByTexture
        WCS_Brain.GetPetTypeByTexture = function(self, texture)
            return WCS_StringOptimizer:GetPetTypeByTexture(texture)
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00WCS String Optimizer inicializado")
end

-- Auto-inicializar
if WCS_Brain then
    WCS_StringOptimizer:Initialize()
end
