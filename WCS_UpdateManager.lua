--[[
    WCS_UpdateManager.lua - Sistema Central de Actualizaciones Optimizado
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 6.4.2 - Optimización de Rendimiento
]]--

WCS_UpdateManager = WCS_UpdateManager or {}
WCS_UpdateManager.VERSION = "6.4.2"

-- ============================================================================
-- CONFIGURACIÓN DE FRECUENCIAS
-- ============================================================================

WCS_UpdateManager.Config = {
    -- Frecuencias de actualización (en segundos)
    CORE = 0.1,        -- 10 FPS - Funciones críticas
    UI = 0.2,          -- 5 FPS - Interfaz de usuario
    ANIMATIONS = 0.05, -- 20 FPS - Animaciones suaves
    ML_DQN = 0.5,      -- 2 FPS - Machine Learning/DQN
    CLEANUP = 30,      -- 30s - Limpieza de memoria
    AUTOSAVE = 60      -- 60s - Guardado automático
}

-- ============================================================================
-- SISTEMA DE REGISTRO DE CALLBACKS
-- ============================================================================

WCS_UpdateManager.Callbacks = {
    core = {},
    ui = {},
    animation = {},
    animations = {},
    ml_dqn = {},
    cleanup = {},
    autosave = {}
}

WCS_UpdateManager.Timers = {
    core = 0,
    ui = 0,
    animations = 0,
    ml_dqn = 0,
    cleanup = 0,
    autosave = 0
}

-- ============================================================================
-- FUNCIONES DE REGISTRO
-- ============================================================================

function WCS_UpdateManager:RegisterCallback(category, name, func)
    if not self.Callbacks[category] then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000WCS_UpdateManager: Categoría inválida: " .. tostring(category))
        return false
    end
    
    self.Callbacks[category][name] = func
    return true
end

function WCS_UpdateManager:UnregisterCallback(category, name)
    if self.Callbacks[category] then
        self.Callbacks[category][name] = nil
    end
end

-- ============================================================================
-- SISTEMA PRINCIPAL DE UPDATES
-- ============================================================================

function WCS_UpdateManager:ProcessAll(elapsed)
    -- Actualizar timers
    for category, timer in pairs(self.Timers) do
        self.Timers[category] = timer + elapsed
    end
    
    -- Procesar cada categoría según su frecuencia
    self:ProcessCategory("core", self.Config.CORE)
    self:ProcessCategory("ui", self.Config.UI)
    self:ProcessCategory("animations", self.Config.ANIMATIONS)
    self:ProcessCategory("ml_dqn", self.Config.ML_DQN)
    self:ProcessCategory("cleanup", self.Config.CLEANUP)
    self:ProcessCategory("autosave", self.Config.AUTOSAVE)
end

function WCS_UpdateManager:ProcessCategory(category, frequency)
    if self.Timers[category] >= frequency then
        self.Timers[category] = 0
        
        -- Ejecutar todos los callbacks de esta categoría
        for name, func in pairs(self.Callbacks[category]) do
            local success, err = pcall(func, frequency)
            if not success then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000WCS_UpdateManager Error en " .. category .. "." .. name .. ": " .. tostring(err))
                -- Desregistrar callback problemático
                self.Callbacks[category][name] = nil
            end
        end
    end
end

-- ============================================================================
-- FUNCIONES DE UTILIDAD
-- ============================================================================

function WCS_UpdateManager:GetStats()
    local stats = {
        totalCallbacks = 0,
        categories = {}
    }
    
    for category, callbacks in pairs(self.Callbacks) do
        local count = 0
        for name, func in pairs(callbacks) do
            count = count + 1
        end
        stats.categories[category] = count
        stats.totalCallbacks = stats.totalCallbacks + count
    end
    
    return stats
end

function WCS_UpdateManager:SetFrequency(category, frequency)
    if self.Config[string.upper(category)] then
        self.Config[string.upper(category)] = frequency
        return true
    end
    return false
end

-- ============================================================================
-- COMANDOS DE DEBUG
-- ============================================================================

function WCS_UpdateManager:PrintStats()
    local stats = self:GetStats()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== WCS Update Manager Stats ===")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Total Callbacks: " .. stats.totalCallbacks)
    
    for category, count in pairs(stats.categories) do
        local freq = self.Config[string.upper(category)] or "N/A"
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF" .. category .. ": " .. count .. " callbacks (" .. freq .. "s)")
    end
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================

function WCS_UpdateManager:Initialize()
    -- Crear frame principal
    if not self.MasterFrame then
        self.MasterFrame = CreateFrame("Frame", "WCS_MasterUpdateFrame")
        self.MasterFrame:SetScript("OnUpdate", function()
            WCS_UpdateManager:ProcessAll(arg1)
        end)
    end
    
    -- Registrar callbacks por defecto del sistema existente
    self:RegisterDefaultCallbacks()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00WCS Update Manager inicializado - Versión " .. self.VERSION)
end

function WCS_UpdateManager:RegisterDefaultCallbacks()
    -- Core system callbacks
    if WCS_BrainCore and WCS_BrainCore.OnUpdate then
        self:RegisterCallback("core", "BrainCore", function()
            WCS_BrainCore:OnUpdate()
        end)
    end
    
    -- ML callbacks
    if WCS_BrainML and WCS_BrainML.OnUpdate then
        self:RegisterCallback("ml_dqn", "BrainML", function(elapsed)
            WCS_BrainML:OnUpdate(elapsed)
        end)
    end
    
    -- Cleanup callbacks
    if WCS_BrainAI and WCS_BrainAI.CleanupExpiredDoTs then
        self:RegisterCallback("cleanup", "DoTCleanup", function()
            WCS_BrainAI:CleanupExpiredDoTs()
        end)
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================

SLASH_WCSUPDATEMGR1 = "/wcsupdates"
SlashCmdList["WCSUPDATEMGR"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "stats" then
        WCS_UpdateManager:PrintStats()
    elseif cmd == "init" then
        WCS_UpdateManager:Initialize()
    elseif string.find(cmd, "freq ") then
        local _, _, category, freq = string.find(cmd, "freq (%w+) ([%d%.]+)")
        if category and freq then
            if WCS_UpdateManager:SetFrequency(category, tonumber(freq)) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Frecuencia de " .. category .. " cambiada a " .. freq .. "s")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Categoría inválida: " .. category)
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00WCS Update Manager Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsupdates stats - Ver estadísticas")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsupdates init - Reinicializar")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsupdates freq <category> <seconds> - Cambiar frecuencia")
    end
end

-- Auto-inicializar cuando se carga el archivo
if WCS_Brain then
    WCS_UpdateManager:Initialize()
end
