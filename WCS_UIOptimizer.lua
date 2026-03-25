--[[
    WCS_UIOptimizer.lua - Optimizador de Interfaces Gráficas
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 6.4.2 - Optimización de UI
]]--

WCS_UIOptimizer = WCS_UIOptimizer or {}
WCS_UIOptimizer.VERSION = "6.4.2"

-- ============================================================================
-- SISTEMA DE CACHÉ DE UI
-- ============================================================================

WCS_UIOptimizer.Cache = {
    -- Caché de elementos UI creados
    frames = {},
    fontStrings = {},
    textures = {},
    buttons = {},
    
    -- Caché de colores calculados
    colors = {},
    
    -- Caché de posiciones y tamaños
    layouts = {},
    
    -- Estadísticas
    stats = {
        cacheHits = 0,
        cacheMisses = 0,
        elementsCreated = 0,
        elementsReused = 0
    }
}

-- ============================================================================
-- FUNCIONES DE CACHÉ
-- ============================================================================

-- Función para obtener o crear un frame
function WCS_UIOptimizer:GetFrame(name, frameType, parent, template)
    local cacheKey = name or (frameType .. "_" .. tostring(parent))
    
    if self.Cache.frames[cacheKey] then
        self.Cache.stats.cacheHits = self.Cache.stats.cacheHits + 1
        self.Cache.stats.elementsReused = self.Cache.stats.elementsReused + 1
        return self.Cache.frames[cacheKey]
    end
    
    -- Crear nuevo frame
    local frame = CreateFrame(frameType or "Frame", name, parent, template)
    self.Cache.frames[cacheKey] = frame
    self.Cache.stats.cacheMisses = self.Cache.stats.cacheMisses + 1
    self.Cache.stats.elementsCreated = self.Cache.stats.elementsCreated + 1
    
    return frame
end

-- Función para obtener o crear un FontString
function WCS_UIOptimizer:GetFontString(parent, layer, font, cacheKey)
    cacheKey = cacheKey or (tostring(parent) .. "_" .. (layer or "OVERLAY") .. "_" .. (font or "GameFontNormal"))
    
    if self.Cache.fontStrings[cacheKey] then
        self.Cache.stats.cacheHits = self.Cache.stats.cacheHits + 1
        return self.Cache.fontStrings[cacheKey]
    end
    
    local fontString = parent:CreateFontString(nil, layer, font)
    self.Cache.fontStrings[cacheKey] = fontString
    self.Cache.stats.cacheMisses = self.Cache.stats.cacheMisses + 1
    
    return fontString
end

-- Función para obtener color cacheado
function WCS_UIOptimizer:GetColor(r, g, b, a)
    local colorKey = string.format("%.2f_%.2f_%.2f_%.2f", r or 1, g or 1, b or 1, a or 1)
    
    if self.Cache.colors[colorKey] then
        self.Cache.stats.cacheHits = self.Cache.stats.cacheHits + 1
        return self.Cache.colors[colorKey]
    end
    
    local color = {r = r or 1, g = g or 1, b = b or 1, a = a or 1}
    self.Cache.colors[colorKey] = color
    self.Cache.stats.cacheMisses = self.Cache.stats.cacheMisses + 1
    
    return color
end

-- ============================================================================
-- OPTIMIZACIONES DE LAYOUT
-- ============================================================================

-- Función para aplicar layout optimizado
function WCS_UIOptimizer:ApplyLayout(frame, layout)
    if not frame or not layout then return end
    
    -- Aplicar posición
    if layout.point and layout.x and layout.y then
        frame:ClearAllPoints()
        frame:SetPoint(layout.point, layout.relativeTo, layout.relativePoint or layout.point, layout.x, layout.y)
    end
    
    -- Aplicar tamaño
    if layout.width and layout.height then
        frame:SetWidth(layout.width)
        frame:SetHeight(layout.height)
    end
    
    -- Aplicar propiedades adicionales
    if layout.alpha then frame:SetAlpha(layout.alpha) end
    if layout.scale then frame:SetScale(layout.scale) end
    if layout.strata then frame:SetFrameStrata(layout.strata) end
    if layout.level then frame:SetFrameLevel(layout.level) end
end

-- Función para crear layout responsivo
function WCS_UIOptimizer:CreateResponsiveLayout(baseWidth, baseHeight)
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    -- Calcular escala basada en resolución
    local scaleX = screenWidth / 1024  -- Base: 1024x768
    local scaleY = screenHeight / 768
    local scale = math.min(scaleX, scaleY) -- Usar la menor para mantener proporciones
    
    return {
        width = baseWidth * scale,
        height = baseHeight * scale,
        scale = scale,
        screenWidth = screenWidth,
        screenHeight = screenHeight
    }
end

-- ============================================================================
-- OPTIMIZACIONES DE COLORES
-- ============================================================================

-- Paleta de colores Warlock optimizada
WCS_UIOptimizer.WarlockPalette = {
    -- Colores principales
    PRIMARY = {0.58, 0.51, 0.79, 1.0},      -- Púrpura Warlock
    SECONDARY = {0.0, 1.0, 0.5, 1.0},       -- Verde Fel
    ACCENT = {0.4, 0.2, 0.6, 1.0},          -- Sombra
    
    -- Estados de salud
    HEALTH_FULL = {0.0, 0.9, 0.3, 1.0},
    HEALTH_HIGH = {0.5, 0.9, 0.3, 1.0},
    HEALTH_MED = {1.0, 0.7, 0.0, 1.0},
    HEALTH_LOW = {1.0, 0.4, 0.0, 1.0},
    HEALTH_CRITICAL = {1.0, 0.2, 0.2, 1.0},
    
    -- Estados de maná
    MANA_FULL = {0.0, 0.5, 1.0, 1.0},
    MANA_HIGH = {0.2, 0.6, 1.0, 1.0},
    MANA_MED = {0.4, 0.7, 1.0, 1.0},
    MANA_LOW = {0.6, 0.8, 1.0, 1.0},
    MANA_CRITICAL = {0.8, 0.9, 1.0, 1.0},
    
    -- Backgrounds
    BG_DARK = {0.08, 0.06, 0.12, 0.9},
    BG_SECTION = {0.12, 0.10, 0.18, 0.8},
    BG_BUTTON = {0.15, 0.13, 0.20, 0.7},
    
    -- Borders
    BORDER_NORMAL = {0.5, 0.4, 0.7, 1.0},
    BORDER_HIGHLIGHT = {0.8, 0.7, 1.0, 1.0},
    BORDER_ACTIVE = {0.0, 1.0, 0.5, 1.0},
    
    -- Text
    TEXT_NORMAL = {1.0, 1.0, 1.0, 1.0},
    TEXT_DIM = {0.6, 0.6, 0.6, 1.0},
    TEXT_HIGHLIGHT = {1.0, 0.82, 0.0, 1.0},
    TEXT_ERROR = {1.0, 0.2, 0.2, 1.0},
    TEXT_SUCCESS = {0.0, 1.0, 0.5, 1.0}
}

-- Función para obtener color por estado
function WCS_UIOptimizer:GetHealthColor(healthPercent)
    if healthPercent >= 0.8 then
        return self.WarlockPalette.HEALTH_FULL
    elseif healthPercent >= 0.6 then
        return self.WarlockPalette.HEALTH_HIGH
    elseif healthPercent >= 0.4 then
        return self.WarlockPalette.HEALTH_MED
    elseif healthPercent >= 0.2 then
        return self.WarlockPalette.HEALTH_LOW
    else
        return self.WarlockPalette.HEALTH_CRITICAL
    end
end

function WCS_UIOptimizer:GetManaColor(manaPercent)
    if manaPercent >= 0.8 then
        return self.WarlockPalette.MANA_FULL
    elseif manaPercent >= 0.6 then
        return self.WarlockPalette.MANA_HIGH
    elseif manaPercent >= 0.4 then
        return self.WarlockPalette.MANA_MED
    elseif manaPercent >= 0.2 then
        return self.WarlockPalette.MANA_LOW
    else
        return self.WarlockPalette.MANA_CRITICAL
    end
end

-- ============================================================================
-- OPTIMIZACIONES DE EVENTOS
-- ============================================================================

-- Pool de eventos para evitar crear múltiples listeners
WCS_UIOptimizer.EventPool = {}

function WCS_UIOptimizer:RegisterOptimizedEvent(frame, event, handler)
    if not self.EventPool[event] then
        self.EventPool[event] = {}
    end
    
    -- Agregar handler al pool
    table.insert(self.EventPool[event], {frame = frame, handler = handler})
    
    -- Si es el primer handler para este evento, registrarlo
    if WCS_TableCount(self.EventPool[event]) == 1 then
        frame:RegisterEvent(event)
        frame:SetScript("OnEvent", function()
            -- Ejecutar todos los handlers para este evento
            for i, entry in ipairs(WCS_UIOptimizer.EventPool[event] or {}) do
                if entry.frame and entry.handler then
                    entry.handler(event, arg1, arg2, arg3, arg4, arg5)
                end
            end
        end)
    end
end

-- ============================================================================
-- FUNCIONES DE UTILIDAD
-- ============================================================================

-- Función para limpiar caché
function WCS_UIOptimizer:ClearCache()
    self.Cache.frames = {}
    self.Cache.fontStrings = {}
    self.Cache.textures = {}
    self.Cache.buttons = {}
    self.Cache.colors = {}
    self.Cache.layouts = {}
    
    -- Resetear estadísticas
    self.Cache.stats = {
        cacheHits = 0,
        cacheMisses = 0,
        elementsCreated = 0,
        elementsReused = 0
    }
end

-- Función para obtener estadísticas de caché
function WCS_UIOptimizer:GetCacheStats()
    local stats = self.Cache.stats
    local hitRate = 0
    
    if (stats.cacheHits + stats.cacheMisses) > 0 then
        hitRate = stats.cacheHits / (stats.cacheHits + stats.cacheMisses) * 100
    end
    
    return {
        hitRate = hitRate,
        totalElements = stats.elementsCreated,
        reusedElements = stats.elementsReused,
        cacheSize = self:GetCacheSize()
    }
end

function WCS_UIOptimizer:GetCacheSize()
    local size = 0
    for k, v in pairs(self.Cache.frames) do size = size + 1 end
    for k, v in pairs(self.Cache.fontStrings) do size = size + 1 end
    for k, v in pairs(self.Cache.textures) do size = size + 1 end
    for k, v in pairs(self.Cache.buttons) do size = size + 1 end
    return size
end

-- ============================================================================
-- COMANDOS DE DEBUG
-- ============================================================================

function WCS_UIOptimizer:PrintStats()
    local stats = self:GetCacheStats()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== WCS UI Optimizer Stats ===")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Cache Hit Rate: " .. string.format("%.1f", stats.hitRate) .. "%")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Total Elements: " .. stats.totalElements)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Reused Elements: " .. stats.reusedElements)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Cache Size: " .. stats.cacheSize .. " elementos")
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================

SLASH_WCSUIOPT1 = "/wcsuiopt"
SlashCmdList["WCSUIOPT"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "stats" then
        WCS_UIOptimizer:PrintStats()
    elseif cmd == "clear" then
        WCS_UIOptimizer:ClearCache()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00UI Cache limpiado")
    elseif cmd == "test" then
        -- Crear elementos de prueba para testear caché
        for i = 1, 10 do
            local frame = WCS_UIOptimizer:GetFrame("TestFrame" .. i, "Frame")
            local text = WCS_UIOptimizer:GetFontString(frame, "OVERLAY", "GameFontNormal")
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Test de caché completado")
        WCS_UIOptimizer:PrintStats()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00WCS UI Optimizer Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsuiopt stats - Ver estadísticas de caché")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsuiopt clear - Limpiar caché")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsuiopt test - Test de rendimiento")
    end
end

-- Auto-inicializar
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00WCS UI Optimizer cargado - Versión " .. WCS_UIOptimizer.VERSION)
