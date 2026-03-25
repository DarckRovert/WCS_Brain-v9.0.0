--[[
    WCS_LazyLoader.lua - Sistema de Carga Diferida de Módulos
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 6.4.2 - Optimización de Rendimiento
]]--

WCS_LazyLoader = WCS_LazyLoader or {}
WCS_LazyLoader.VERSION = "6.4.2"

-- ============================================================================
-- FUNCIONES AUXILIARES COMPATIBLES CON LUA 5.0
-- ============================================================================
local function getTime()
    return GetTime and GetTime() or 0
end

-- ============================================================================
-- CONFIGURACIÓN DE MÓDULOS
-- ============================================================================

WCS_LazyLoader.Modules = {
    -- Módulos críticos (cargar inmediatamente)
    core = {
        files = {"WCS_Brain.lua", "WCS_BrainCore.lua"},
        loaded = false,
        required = true,
        priority = 1
    },
    
    -- Módulos de IA (cargar cuando se active IA)
    ai = {
        files = {"WCS_BrainAI.lua"},
        loaded = false,
        required = false,
        priority = 2,
        condition = function() return WCS_Brain and WCS_Brain.Config and WCS_Brain.Config.aiEnabled end
    },
    
    -- Módulos de Machine Learning (cargar cuando se use)
    ml = {
        files = {"WCS_BrainML.lua", "WCS_BrainDQN.lua"},
        loaded = false,
        required = false,
        priority = 3,
        condition = function() return WCS_Brain and WCS_Brain.Config and WCS_Brain.Config.mlEnabled end
    },
    
    -- Módulos de interfaz (cargar cuando se necesite)
    ui = {
        files = {"WCS_BrainButton.lua", "WCS_BrainPetSocial.lua"},
        loaded = false,
        required = false,
        priority = 4,
        condition = function() return WCS_Brain and WCS_Brain.Config and WCS_Brain.Config.showButton end
    },
    
    -- Módulos de optimización (cargar bajo demanda)
    optimization = {
        files = {"WCS_UpdateManager.lua", "WCS_Profiler.lua", "WCS_StringOptimizer.lua"},
        loaded = false,
        required = false,
        priority = 5,
        condition = function() return false end -- Solo cargar manualmente
    }
}

WCS_LazyLoader.LoadQueue = {}
WCS_LazyLoader.LoadedModules = {}

-- ============================================================================
-- FUNCIONES DE CARGA
-- ============================================================================

function WCS_LazyLoader:LoadModule(moduleName)
    local module = self.Modules[moduleName]
    if not module then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000WCS_LazyLoader: Módulo desconocido: " .. tostring(moduleName))
        return false
    end
    
    if module.loaded then
        return true -- Ya está cargado
    end
    
    -- Verificar condición si existe
    if module.condition and not module.condition() then
        return false -- Condición no cumplida
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Cargando módulo: " .. moduleName)
    
    -- Cargar archivos del módulo
    for i, filename in ipairs(module.files) do
        local success = self:LoadFile(filename)
        if not success then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error cargando: " .. filename)
            return false
        end
    end
    
    module.loaded = true
    self.LoadedModules[moduleName] = getTime()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Módulo cargado: " .. moduleName)
    return true
end

function WCS_LazyLoader:LoadFile(filename)
    -- En WoW 1.12, los archivos ya están cargados por el TOC
    -- Esta función simula la carga diferida verificando si el módulo existe
    
    if filename == "WCS_Brain.lua" then
        return WCS_Brain ~= nil
    elseif filename == "WCS_BrainCore.lua" then
        return WCS_BrainCore ~= nil
    elseif filename == "WCS_BrainAI.lua" then
        return WCS_BrainAI ~= nil
    elseif filename == "WCS_BrainML.lua" then
        return WCS_BrainML ~= nil
    elseif filename == "WCS_BrainDQN.lua" then
        return WCS_BrainDQN ~= nil
    elseif filename == "WCS_BrainButton.lua" then
        return WCS_BrainButton ~= nil
    elseif filename == "WCS_BrainPetSocial.lua" then
        return WCS_Brain and WCS_Brain.Pet ~= nil
    elseif filename == "WCS_UpdateManager.lua" then
        return WCS_UpdateManager ~= nil
    elseif filename == "WCS_Profiler.lua" then
        return WCS_Profiler ~= nil
    elseif filename == "WCS_StringOptimizer.lua" then
        return WCS_StringOptimizer ~= nil
    end
    
    return false
end

-- ============================================================================
-- SISTEMA DE INICIALIZACIÓN DIFERIDA
-- ============================================================================

function WCS_LazyLoader:Initialize()
    -- Cargar módulos críticos inmediatamente
    for moduleName, module in pairs(self.Modules) do
        if module.required then
            self:LoadModule(moduleName)
        end
    end
    
    -- Configurar verificación periódica para módulos condicionales
    if not self.CheckFrame then
        self.CheckFrame = CreateFrame("Frame", "WCS_LazyLoaderFrame")
        self.CheckFrame.elapsed = 0
        self.CheckFrame:SetScript("OnUpdate", function()
            WCS_LazyLoader:CheckConditions(arg1)
        end)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00WCS Lazy Loader inicializado")
end

function WCS_LazyLoader:CheckConditions(elapsed)
    self.CheckFrame.elapsed = self.CheckFrame.elapsed + elapsed
    
    -- Verificar cada 5 segundos
    if self.CheckFrame.elapsed < 5 then return end
    self.CheckFrame.elapsed = 0
    
    -- Verificar condiciones de módulos no cargados
    for moduleName, module in pairs(self.Modules) do
        if not module.loaded and not module.required and module.condition then
            if module.condition() then
                self:LoadModule(moduleName)
            end
        end
    end
end

-- ============================================================================
-- FUNCIONES DE GESTIÓN
-- ============================================================================

function WCS_LazyLoader:UnloadModule(moduleName)
    local module = self.Modules[moduleName]
    if not module or not module.loaded then
        return false
    end
    
    -- En WoW 1.12 no podemos realmente descargar módulos,
    -- pero podemos marcarlos como no cargados y limpiar referencias
    module.loaded = false
    self.LoadedModules[moduleName] = nil
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Módulo marcado como descargado: " .. moduleName)
    return true
end

function WCS_LazyLoader:GetLoadedModules()
    local loaded = {}
    for moduleName, module in pairs(self.Modules) do
        if module.loaded then
            table.insert(loaded, moduleName)
        end
    end
    return loaded
end

function WCS_LazyLoader:GetModuleStats()
    local stats = {
        total = 0,
        loaded = 0,
        required = 0,
        optional = 0
    }
    
    for moduleName, module in pairs(self.Modules) do
        stats.total = stats.total + 1
        if module.loaded then
            stats.loaded = stats.loaded + 1
        end
        if module.required then
            stats.required = stats.required + 1
        else
            stats.optional = stats.optional + 1
        end
    end
    
    return stats
end

-- ============================================================================
-- COMANDOS DE DEBUG
-- ============================================================================

function WCS_LazyLoader:PrintStatus()
    local stats = self:GetModuleStats()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== WCS Lazy Loader Status ===")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Módulos totales: " .. stats.total)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Módulos cargados: " .. stats.loaded)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Módulos requeridos: " .. stats.required)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Módulos opcionales: " .. stats.optional)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF=== Estado por Módulo ===")
    for moduleName, module in pairs(self.Modules) do
        local status = module.loaded and "|cFF00FF00CARGADO" or "|cFFFF0000NO CARGADO"
        local required = module.required and " (REQUERIDO)" or " (OPCIONAL)"
        DEFAULT_CHAT_FRAME:AddMessage(status .. "|cFFFFFFFF " .. moduleName .. required)
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================

SLASH_WCSLOADER1 = "/wcsloader"
SlashCmdList["WCSLOADER"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "status" then
        WCS_LazyLoader:PrintStatus()
    elseif cmd == "init" then
        WCS_LazyLoader:Initialize()
    elseif string.find(cmd, "load ") then
        local _, _, moduleName = string.find(cmd, "load (%w+)")
        if moduleName then
            if WCS_LazyLoader:LoadModule(moduleName) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Módulo " .. moduleName .. " cargado exitosamente")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error cargando módulo " .. moduleName)
            end
        end
    elseif string.find(cmd, "unload ") then
        local _, _, moduleName = string.find(cmd, "unload (%w+)")
        if moduleName then
            if WCS_LazyLoader:UnloadModule(moduleName) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Módulo " .. moduleName .. " descargado")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error descargando módulo " .. moduleName)
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00WCS Lazy Loader Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsloader status - Ver estado de módulos")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsloader init - Reinicializar sistema")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsloader load <module> - Cargar módulo específico")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsloader unload <module> - Descargar módulo")
    end
end

-- Auto-inicializar si WCS_Brain existe
if WCS_Brain then
    WCS_LazyLoader:Initialize()
end
