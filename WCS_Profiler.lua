--[[
    WCS_Profiler.lua - Sistema de Profiling y Monitoreo de Rendimiento
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 6.4.2 - Optimización de Rendimiento
]]--

WCS_Profiler = WCS_Profiler or {}
WCS_Profiler.VERSION = "6.4.2"
WCS_Profiler.enabled = false

-- ============================================================================
-- CONFIGURACIÓN Y DATOS
-- ============================================================================

WCS_Profiler.Stats = {
    startTime = 0,
    totalTime = 0,
    frameCount = 0,
    avgFPS = 0,
    memoryUsage = 0,
    callCounts = {},
    executionTimes = {},
    errors = {}
}

WCS_Profiler.Config = {
    sampleInterval = 1,    -- Muestrear cada segundo
    maxSamples = 300,      -- Mantener 5 minutos de datos
    trackMemory = true,
    trackFPS = true,
    trackCalls = true
}

-- ============================================================================
-- FUNCIONES DE PROFILING
-- ============================================================================

function WCS_Profiler:Start()
    if self.enabled then return end
    
    self.enabled = true
    self.Stats.startTime = getTime()
    self.Stats.frameCount = 0
    self.Stats.callCounts = {}
    self.Stats.executionTimes = {}
    self.Stats.errors = {}
    
    -- Crear frame de profiling
    if not self.ProfileFrame then
        self.ProfileFrame = CreateFrame("Frame", "WCS_ProfileFrame")
        self.ProfileFrame.elapsed = 0
        self.ProfileFrame:SetScript("OnUpdate", function()
            WCS_Profiler:OnUpdate(arg1)
        end)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00WCS Profiler iniciado")
end

function WCS_Profiler:Stop()
    if not self.enabled then return end
    
    self.enabled = false
    self.Stats.totalTime = getTime() - self.Stats.startTime
    
    if self.ProfileFrame then
        self.ProfileFrame:SetScript("OnUpdate", nil)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000WCS Profiler detenido")
    self:PrintSummary()
end

function WCS_Profiler:OnUpdate(elapsed)
    if not self.enabled then return end
    
    self.ProfileFrame.elapsed = self.ProfileFrame.elapsed + elapsed
    self.Stats.frameCount = self.Stats.frameCount + 1
    
    -- Muestrear cada segundo
    if self.ProfileFrame.elapsed >= self.Config.sampleInterval then
        self:TakeSample()
        self.ProfileFrame.elapsed = 0
    end
end

function WCS_Profiler:TakeSample()
    local currentTime = getTime()
    local deltaTime = currentTime - self.Stats.startTime
    
    -- Calcular FPS promedio
    if deltaTime > 0 then
        self.Stats.avgFPS = self.Stats.frameCount / deltaTime
    end
    
    -- Medir uso de memoria (aproximado)
    if self.Config.trackMemory then
        self:MeasureMemoryUsage()
    end
end

function WCS_Profiler:MeasureMemoryUsage()
    -- Contar estructuras de datos principales
    local memUsage = 0
    
    -- WCS_Brain structures
    if WCS_Brain then
        memUsage = memUsage + self:CountTableSize(WCS_Brain.LearnedSpells or {})
        memUsage = memUsage + self:CountTableSize(WCS_Brain.Cooldowns or {})
    end
    
    -- WCS_BrainAI structures
    if WCS_BrainAI then
        memUsage = memUsage + self:CountTableSize(WCS_BrainAI.DoTTimers or {})
        memUsage = memUsage + self:CountTableSize(WCS_BrainAI.CombatTargets or {})
    end
    
    -- WCS_BrainDQN structures
    if WCS_BrainDQN and WCS_BrainDQN.ReplayBuffer then
        memUsage = memUsage + (WCS_BrainDQN.ReplayBuffer.size or 0) * 50 -- Estimación
    end
    
    self.Stats.memoryUsage = memUsage
end

function WCS_Profiler:CountTableSize(tbl)
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
        if type(v) == "table" then
            count = count + self:CountTableSize(v)
        end
    end
    return count
end

-- ============================================================================
-- TRACKING DE FUNCIONES
-- ============================================================================

function WCS_Profiler:TrackFunction(funcName, func)
    if not self.enabled then return func end
    
    return function()
        local startTime = getTime()

        -- Incrementar contador de llamadas
        self.Stats.callCounts[funcName] = (self.Stats.callCounts[funcName] or 0) + 1

        -- Capturar argumentos de forma segura usando la tabla 'arg' (Lua 5.0)
        local args = {}
        if arg then
            local n = WCS_TableCount(arg)
            if n == 0 and arg and type(arg) == "table" then
                for k, _ in pairs(arg) do
                    if type(k) == "number" and k > n then n = k end
                end
            end
            for i = 1, n do args[i] = arg[i] end
        end

        local nargs = WCS_TableCount(args)
        local success, result
        if nargs > 0 and unpack then
            success, result = pcall(func, unpack(args))
        else
            success, result = pcall(func)
        end
        
        -- Medir tiempo de ejecución
        local execTime = getTime() - startTime
        if not self.Stats.executionTimes[funcName] then
            self.Stats.executionTimes[funcName] = {total = 0, count = 0, avg = 0, max = 0}
        end
        
        local stats = self.Stats.executionTimes[funcName]
        stats.total = stats.total + execTime
        stats.count = stats.count + 1
        stats.avg = stats.total / stats.count
        if execTime > stats.max then
            stats.max = execTime
        end
        
        -- Registrar errores
        if not success then
            table.insert(self.Stats.errors, {
                func = funcName,
                error = result,
                time = getTime()
            })
        end
        
        return result
    end
end

-- ============================================================================
-- REPORTES Y ESTADÍSTICAS
-- ============================================================================

function WCS_Profiler:PrintSummary()
    local stats = self.Stats
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== WCS Profiler Summary ===")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Tiempo total: " .. string.format("%.2f", stats.totalTime) .. "s")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00FPS promedio: " .. string.format("%.1f", stats.avgFPS))
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Uso de memoria: ~" .. stats.memoryUsage .. " entradas")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Errores: " .. WCS_TableCount(stats.errors))
    
    -- Top 5 funciones más llamadas
    local sortedCalls = {}
    for funcName, count in pairs(stats.callCounts) do
        table.insert(sortedCalls, {name = funcName, count = count})
    end
    table.sort(sortedCalls, function(a, b) return a.count > b.count end)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF=== Top 5 Funciones Más Llamadas ===")
    for i = 1, math.min(5, WCS_TableCount(sortedCalls)) do
        local item = sortedCalls[i]
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFF" .. i .. ". " .. item.name .. ": " .. item.count .. " llamadas")
    end
    
    -- Top 5 funciones más lentas
    local sortedTimes = {}
    for funcName, timeStats in pairs(stats.executionTimes) do
        table.insert(sortedTimes, {name = funcName, avg = timeStats.avg, max = timeStats.max})
    end
    table.sort(sortedTimes, function(a, b) return a.avg > b.avg end)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF=== Top 5 Funciones Más Lentas ===")
    for i = 1, math.min(5, WCS_TableCount(sortedTimes)) do
        local item = sortedTimes[i]
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFF" .. i .. ". " .. item.name .. ": " .. 
                                    string.format("%.4f", item.avg*1000) .. "ms avg, " ..
                                    string.format("%.4f", item.max*1000) .. "ms max")
    end
end

function WCS_Profiler:PrintMemoryReport()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== WCS Memory Report ===")
    
    -- Detalles de memoria por componente
    if WCS_Brain then
        local spellCount = 0
        for k, v in pairs(WCS_Brain.LearnedSpells or {}) do spellCount = spellCount + 1 end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Spells cached: " .. spellCount)
        
        local cdCount = 0
        for k, v in pairs(WCS_Brain.Cooldowns or {}) do cdCount = cdCount + 1 end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Cooldowns tracked: " .. cdCount)
    end
    
    if WCS_BrainAI then
        local dotTargets = 0
        local totalDots = 0
        for targetID, dots in pairs(WCS_BrainAI.DoTTimers or {}) do
            dotTargets = dotTargets + 1
            for dotName, data in pairs(dots) do
                totalDots = totalDots + 1
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00DoT targets: " .. dotTargets .. " (" .. totalDots .. " DoTs)")
    end
    
    if WCS_BrainDQN and WCS_BrainDQN.ReplayBuffer then
        local bufferSize = WCS_BrainDQN.ReplayBuffer.size or 0
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00DQN buffer: " .. bufferSize .. " entradas")
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================

SLASH_WCSPROFILE1 = "/wcsprofile"
SlashCmdList["WCSPROFILE"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "start" then
        WCS_Profiler:Start()
    elseif cmd == "stop" then
        WCS_Profiler:Stop()
    elseif cmd == "status" then
        if WCS_Profiler.enabled then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Profiler activo - " .. 
                                        string.format("%.1f", WCS_Profiler.Stats.avgFPS) .. " FPS")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Profiler inactivo")
        end
    elseif cmd == "memory" then
        WCS_Profiler:PrintMemoryReport()
    elseif cmd == "reset" then
        WCS_Profiler.Stats = {
            startTime = 0, totalTime = 0, frameCount = 0, avgFPS = 0,
            memoryUsage = 0, callCounts = {}, executionTimes = {}, errors = {}
        }
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Estadísticas reseteadas")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00WCS Profiler Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsprofile start - Iniciar profiling")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsprofile stop - Detener y mostrar resumen")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsprofile status - Ver estado actual")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsprofile memory - Reporte de memoria")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF/wcsprofile reset - Resetear estadísticas")
    end
end
