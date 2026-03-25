--[[
    WCS_BrainLogger.lua - Sistema de Logging Mejorado v6.6.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema de logging con niveles, colores y filtros
    
    Autor: Elnazzareno (DarckRovert)
    Twitch: twitch.tv/darckrovert
    Kick: kick.com/darckrovert
]]--

WCS_BrainLogger = WCS_BrainLogger or {}
WCS_BrainLogger.VERSION = "6.6.0"

-- ============================================================================
-- NIVELES DE LOG
-- ============================================================================
WCS_BrainLogger.Levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    CRITICAL = 5
}

WCS_BrainLogger.LevelNames = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "CRITICAL"
}

-- ============================================================================
-- COLORES POR NIVEL
-- ============================================================================
WCS_BrainLogger.Colors = {
    [1] = { r = 0.5, g = 0.5, b = 0.5 },  -- DEBUG: Gris
    [2] = { r = 0.0, g = 1.0, b = 0.0 },  -- INFO: Verde
    [3] = { r = 1.0, g = 1.0, b = 0.0 },  -- WARN: Amarillo
    [4] = { r = 1.0, g = 0.5, b = 0.0 },  -- ERROR: Naranja
    [5] = { r = 1.0, g = 0.0, b = 0.0 }   -- CRITICAL: Rojo
}

-- ============================================================================
-- CONFIGURACIÓN
-- ============================================================================
WCS_BrainLogger.Config = {
    currentLevel = 2,  -- INFO por defecto
    showTimestamp = true,
    showModule = true,
    showLevel = true,
    maxHistorySize = 100,
    enableFileLog = false,  -- Para futuro
    filters = {}  -- Módulos a filtrar
}

-- ============================================================================
-- HISTORIAL DE LOGS
-- ============================================================================
WCS_BrainLogger.History = {}

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainLogger:Initialize()
    self.History = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS_BrainLogger]|r v" .. self.VERSION .. " inicializado")
end

-- ============================================================================
-- FUNCIÓN PRINCIPAL DE LOG
-- ============================================================================
function WCS_BrainLogger:Log(level, module, message)
    -- Convertir level a numero si es string
    if type(level) == "string" then
        level = self.Levels[level] or self.Levels.INFO
    end
    
    -- Verificar nivel
    if level < self.Config.currentLevel then
        return
    end
    
    -- Verificar filtros
    if self.Config.filters[module] then
        return
    end
    
    -- Construir mensaje
    local logMessage = ""
    
    -- Timestamp
    if self.Config.showTimestamp then
        local hour, minute = GetGameTime()
        local second = mod(time(), 60) -- Obtener segundos del timestamp actual
        logMessage = logMessage .. string.format("[%02d:%02d:%02d] ", hour, minute, second)
    end
    
    -- Nivel
    if self.Config.showLevel then
        logMessage = logMessage .. "[" .. self.LevelNames[level] .. "] "
    end
    
    -- Módulo
    if self.Config.showModule and module then
        logMessage = logMessage .. "[" .. module .. "] "
    end
    
    -- Validar mensaje
    if not message then
        message = "(no message)"
    end
    
    -- Mensaje
    logMessage = logMessage .. message
    
    -- Obtener color
    local color = self.Colors[level]
    
    -- Mostrar en chat
    DEFAULT_CHAT_FRAME:AddMessage(logMessage, color.r, color.g, color.b)
    
    -- Guardar en historial
    self:AddToHistory(level, module, message)
end

-- ============================================================================
-- MÉTODOS DE CONVENIENCIA
-- ============================================================================
function WCS_BrainLogger:Debug(module, message)
    self:Log(self.Levels.DEBUG, module, message)
end

function WCS_BrainLogger:Info(module, message)
    self:Log(self.Levels.INFO, module, message)
end

function WCS_BrainLogger:Warn(module, message)
    self:Log(self.Levels.WARN, module, message)
end

function WCS_BrainLogger:Error(module, message)
    self:Log(self.Levels.ERROR, module, message)
end

function WCS_BrainLogger:Critical(module, message)
    self:Log(self.Levels.CRITICAL, module, message)
end

-- ============================================================================
-- HISTORIAL
-- ============================================================================
function WCS_BrainLogger:AddToHistory(level, module, message)
    local entry = {
        level = level,
        module = module,
        message = message,
        timestamp = time()
    }
    
    table.insert(self.History, entry)
    
    -- Limitar tamaño del historial
    while table.getn(self.History) > self.Config.maxHistorySize do
        table.remove(self.History, 1)
    end
end

function WCS_BrainLogger:GetHistory(count)
    count = count or 10
    local history = {}
    local total = table.getn(self.History)
    local start = total - count + 1
    if start < 1 then start = 1 end
    
    for i = start, total do
        table.insert(history, self.History[i])
    end
    
    return history
end

function WCS_BrainLogger:ClearHistory()
    self.History = {}
    self:Info("Logger", "Historial limpiado")
end

-- ============================================================================
-- CONFIGURACIÓN
-- ============================================================================
function WCS_BrainLogger:SetLevel(level)
    if type(level) == "string" then
        -- Convertir nombre a número
        for num, name in pairs(self.LevelNames) do
            if name == level then
                level = num
                break
            end
        end
    end
    
    if type(level) == "number" and level >= 1 and level <= 5 then
        self.Config.currentLevel = level
        self:Info("Logger", "Nivel de log cambiado a: " .. self.LevelNames[level])
    end
end

function WCS_BrainLogger:AddFilter(module)
    self.Config.filters[module] = true
    self:Info("Logger", "Filtro agregado: " .. module)
end

function WCS_BrainLogger:RemoveFilter(module)
    self.Config.filters[module] = nil
    self:Info("Logger", "Filtro removido: " .. module)
end

function WCS_BrainLogger:ClearFilters()
    self.Config.filters = {}
    self:Info("Logger", "Todos los filtros limpiados")
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSLOGGER1 = "/wcslog"
SLASH_WCSLOGGER2 = "/brainlog"

SlashCmdList["WCSLOGGER"] = function(msg)
    local args = {}
    for word in string.gfind(msg, "%S+") do
        table.insert(args, word)
    end
    
    local cmd = args[1]
    
    if not cmd or cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Logger]|r Comandos disponibles:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainlog level [DEBUG|INFO|WARN|ERROR|CRITICAL]|r - Cambiar nivel")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainlog history [count]|r - Ver historial")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainlog clear|r - Limpiar historial")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainlog filter add [module]|r - Agregar filtro")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainlog filter remove [module]|r - Remover filtro")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainlog filter clear|r - Limpiar filtros")
        return
    end
    
    if cmd == "level" then
        local level = args[2]
        if level then
            WCS_BrainLogger:SetLevel(level)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Logger]|r Nivel actual: " .. WCS_BrainLogger.LevelNames[WCS_BrainLogger.Config.currentLevel])
        end
        
    elseif cmd == "history" then
        local count = tonumber(args[2]) or 10
        local history = WCS_BrainLogger:GetHistory(count)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Logger]|r Últimos " .. count .. " logs:")
        for i = 1, table.getn(history) do
            local entry = history[i]
            local color = WCS_BrainLogger.Colors[entry.level]
            DEFAULT_CHAT_FRAME:AddMessage(
                "[" .. WCS_BrainLogger.LevelNames[entry.level] .. "] [" .. entry.module .. "] " .. entry.message,
                color.r, color.g, color.b
            )
        end
        
    elseif cmd == "clear" then
        WCS_BrainLogger:ClearHistory()
        
    elseif cmd == "filter" then
        local subcmd = args[2]
        if subcmd == "add" then
            local module = args[3]
            if module then
                WCS_BrainLogger:AddFilter(module)
            end
        elseif subcmd == "remove" then
            local module = args[3]
            if module then
                WCS_BrainLogger:RemoveFilter(module)
            end
        elseif subcmd == "clear" then
            WCS_BrainLogger:ClearFilters()
        end
    end
end

-- ============================================================================
-- AUTO-INICIALIZACIÓN
-- ============================================================================
local function OnLoad()
    WCS_BrainLogger:Initialize()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        OnLoad()
    end
end)

