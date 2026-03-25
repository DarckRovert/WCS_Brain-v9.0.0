-- WCS_BrainBossMods.lua
-- Integración con BigWigs y DBM para WCS_Brain v6.9.0
-- Reacciona automáticamente a alertas de boss mods

if not WCS_Brain then return end

WCS_Brain.BossMods = {
    -- Estado de integración
    isBigWigsLoaded = false,
    isDBMLoaded = false,
    
    -- Configuración
    config = {
        autoReact = true, -- Reaccionar automáticamente a alertas
        reactToSpells = true, -- Reaccionar a spell alerts
        reactToPhases = true, -- Reaccionar a cambios de fase
        reactToPulls = true, -- Reaccionar a pull timers
        notifyPlayer = true, -- Notificar al jugador
    },
    
    -- Alertas activas
    activeAlerts = {},
    
    -- Historial de alertas (últimas 50)
    alertHistory = {},
    maxHistory = 50,
    
    -- Callbacks registrados
    callbacks = {},
    
    -- Estadísticas
    stats = {
        totalAlerts = 0,
        alertsByType = {},
        reactionsTriggered = 0,
    },
}

local BossMods = WCS_Brain.BossMods

-- Inicializar integración
function BossMods:Initialize()
    -- Crear frame para eventos
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" then
            if arg1 == "BigWigs" then
                BossMods:OnBigWigsLoaded()
            elseif arg1 == "DBM-Core" then
                BossMods:OnDBMLoaded()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            BossMods:CheckBossMods()
        end
    end)
    
    self.frame = frame
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Info("Integración Boss Mods inicializada")
    end
end

-- Verificar qué boss mods están cargados
function BossMods:CheckBossMods()
    -- Verificar BigWigs
    if BigWigs then
        self.isBigWigsLoaded = true
        self:SetupBigWigsHooks()
    end
    
    -- Verificar DBM
    if DBM then
        self.isDBMLoaded = true
        self:SetupDBMHooks()
    end
    
    if not self.isBigWigsLoaded and not self.isDBMLoaded then
        if WCS_Brain.Notifications then
            WCS_Brain.Notifications:Info("No se detectó BigWigs ni DBM")
        end
    end
end

-- Cuando BigWigs se carga
function BossMods:OnBigWigsLoaded()
    self.isBigWigsLoaded = true
    self:SetupBigWigsHooks()
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Success("BigWigs detectado - Integración activa")
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS Brain: BigWigs detectado", 0, 1, 0)
    end
end

-- Cuando DBM se carga
function BossMods:OnDBMLoaded()
    self.isDBMLoaded = true
    self:SetupDBMHooks()
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Success("DBM detectado - Integración activa")
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS Brain: DBM detectado", 0, 1, 0)
    end
end

-- Configurar hooks para BigWigs
function BossMods:SetupBigWigsHooks()
    if not BigWigs then return end
    
    -- Hook para mensajes de BigWigs
    local oldBigWigsMessage = BigWigs.Message
    if oldBigWigsMessage then
        BigWigs.Message = function(...)
            -- Llamar función original
            oldBigWigsMessage(unpack(arg))
            
            -- Procesar alerta
            BossMods:OnBigWigsAlert(arg)
        end
    end
    
    -- Hook para bars de BigWigs
    local oldBigWigsBar = BigWigs.StartBar
    if oldBigWigsBar then
        BigWigs.StartBar = function(...)
            -- Llamar función original
            oldBigWigsBar(unpack(arg))
            
            -- Procesar bar
            BossMods:OnBigWigsBar(arg)
        end
    end
end

-- Configurar hooks para DBM
function BossMods:SetupDBMHooks()
    if not DBM then return end
    
    -- Hook para announces de DBM
    local oldDBMAnnounce = DBM.AddMsg
    if oldDBMAnnounce then
        DBM.AddMsg = function(...)
            -- Llamar función original
            oldDBMAnnounce(unpack(arg))
            
            -- Procesar announce
            BossMods:OnDBMAnnounce(arg)
        end
    end
    
    -- Hook para timers de DBM
    local oldDBMTimer = DBM.CreatePizzaTimer
    if oldDBMTimer then
        DBM.CreatePizzaTimer = function(...)
            -- Llamar función original
            oldDBMTimer(unpack(arg))
            
            -- Procesar timer
            BossMods:OnDBMTimer(arg)
        end
    end
end

-- Procesar alerta de BigWigs
function BossMods:OnBigWigsAlert(args)
    if not self.config.autoReact then return end
    
    local message = args[1] or "Unknown"
    local color = args[2] or {1, 1, 1}
    
    local alert = {
        source = "BigWigs",
        type = "message",
        message = message,
        timestamp = GetTime(),
        color = color,
    }
    
    self:ProcessAlert(alert)
end

-- Procesar bar de BigWigs
function BossMods:OnBigWigsBar(args)
    if not self.config.autoReact then return end
    
    local text = args[1] or "Unknown"
    local duration = args[2] or 0
    
    local alert = {
        source = "BigWigs",
        type = "bar",
        message = text,
        duration = duration,
        timestamp = GetTime(),
    }
    
    self:ProcessAlert(alert)
end

-- Procesar announce de DBM
function BossMods:OnDBMAnnounce(args)
    if not self.config.autoReact then return end
    
    local message = args[1] or "Unknown"
    
    local alert = {
        source = "DBM",
        type = "announce",
        message = message,
        timestamp = GetTime(),
    }
    
    self:ProcessAlert(alert)
end

-- Procesar timer de DBM
function BossMods:OnDBMTimer(args)
    if not self.config.autoReact then return end
    
    local duration = args[1] or 0
    local text = args[2] or "Unknown"
    
    local alert = {
        source = "DBM",
        type = "timer",
        message = text,
        duration = duration,
        timestamp = GetTime(),
    }
    
    self:ProcessAlert(alert)
end

-- Procesar alerta genérica
function BossMods:ProcessAlert(alert)
    -- Agregar a alertas activas
    table.insert(self.activeAlerts, alert)
    
    -- Agregar a historial
    table.insert(self.alertHistory, alert)
    while table.getn(self.alertHistory) > self.maxHistory do
        table.remove(self.alertHistory, 1)
    end
    
    -- Actualizar estadísticas
    self.stats.totalAlerts = self.stats.totalAlerts + 1
    
    local alertType = alert.type or "unknown"
    if not self.stats.alertsByType[alertType] then
        self.stats.alertsByType[alertType] = 0
    end
    self.stats.alertsByType[alertType] = self.stats.alertsByType[alertType] + 1
    
    -- Analizar y reaccionar
    self:AnalyzeAlert(alert)
    
    -- Notificar al jugador si está configurado
    if self.config.notifyPlayer and WCS_Brain.Notifications then
        local source = alert.source or "Boss Mod"
        WCS_Brain.Notifications:Info(source .. ": " .. alert.message)
    end
    
    -- Ejecutar callbacks registrados
    self:ExecuteCallbacks(alert)
end

-- Analizar alerta y tomar acciones
function BossMods:AnalyzeAlert(alert)
    local message = string.lower(alert.message or "")
    
    -- Detectar tipos de alertas comunes
    
    -- 1. Alertas de AoE / Daño de área
    if string.find(message, "aoe") or 
       string.find(message, "explosion") or
       string.find(message, "bomb") or
       string.find(message, "fire") then
        self:ReactToAoE(alert)
    end
    
    -- 2. Alertas de interrupciones
    if string.find(message, "interrupt") or
       string.find(message, "cast") or
       string.find(message, "spell") then
        self:ReactToInterrupt(alert)
    end
    
    -- 3. Alertas de dispel
    if string.find(message, "dispel") or
       string.find(message, "cleanse") or
       string.find(message, "remove") then
        self:ReactToDispel(alert)
    end
    
    -- 4. Alertas de adds
    if string.find(message, "add") or
       string.find(message, "spawn") then
        self:ReactToAdds(alert)
    end
    
    -- 5. Alertas de fase
    if string.find(message, "phase") then
        self:ReactToPhase(alert)
    end
    
    -- 6. Alertas de pull
    if string.find(message, "pull") or
       string.find(message, "engage") then
        self:ReactToPull(alert)
    end
end

-- Reaccionar a AoE
function BossMods:ReactToAoE(alert)
    if not self.config.reactToSpells then return end
    
    -- Notificar a PetAI para que mueva la mascota
    if WCS_Brain.PetAI and WCS_Brain.PetAI.isEnabled then
        -- Aquí se podría implementar lógica para mover la mascota
        -- Por ahora solo registramos la reacción
        self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
    end
    
    -- Notificar a BrainAI
    if WCS_Brain.BrainAI and WCS_Brain.BrainAI.isEnabled then
        -- La IA podría usar habilidades defensivas
        self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
    end
end

-- Reaccionar a interrupciones
function BossMods:ReactToInterrupt(alert)
    if not self.config.reactToSpells then return end
    
    if WCS_Brain.BrainAI and WCS_Brain.BrainAI.isEnabled then
        -- La IA podría priorizar interrupciones
        self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
    end
end

-- Reaccionar a dispel
function BossMods:ReactToDispel(alert)
    if not self.config.reactToSpells then return end
    
    if WCS_Brain.BrainAI and WCS_Brain.BrainAI.isEnabled then
        -- La IA podría usar dispel si está disponible
        self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
    end
end

-- Reaccionar a adds
function BossMods:ReactToAdds(alert)
    if not self.config.reactToSpells then return end
    
    if WCS_Brain.PetAI and WCS_Brain.PetAI.isEnabled then
        -- PetAI podría cambiar de target a los adds
        self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
    end
end

-- Reaccionar a cambio de fase
function BossMods:ReactToPhase(alert)
    if not self.config.reactToPhases then return end
    
    -- Limpiar alertas antiguas
    self.activeAlerts = {}
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Warning("Cambio de fase detectado")
    end
    
    self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
end

-- Reaccionar a pull
function BossMods:ReactToPull(alert)
    if not self.config.reactToPulls then return end
    
    -- Preparar sistemas para combate
    if WCS_Brain.BrainAI then
        -- Activar modo de combate
    end
    
    if WCS_Brain.PetAI then
        -- Preparar mascota
    end
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Warning("Pull detectado - Preparando combate")
    end
    
    self.stats.reactionsTriggered = self.stats.reactionsTriggered + 1
end

-- Registrar callback personalizado
function BossMods:RegisterCallback(name, func)
    if not name or not func then return false end
    
    self.callbacks[name] = func
    return true
end

-- Eliminar callback
function BossMods:UnregisterCallback(name)
    if not name then return false end
    
    self.callbacks[name] = nil
    return true
end

-- Ejecutar callbacks
function BossMods:ExecuteCallbacks(alert)
    for name, func in pairs(self.callbacks) do
        local success, err = pcall(func, alert)
        if not success then
            if WCS_Brain.Notifications then
                WCS_Brain.Notifications:Error("Error en callback " .. name .. ": " .. tostring(err))
            end
        end
    end
end

-- Limpiar alertas antiguas (más de 30 segundos)
function BossMods:CleanupAlerts()
    local currentTime = GetTime()
    local newAlerts = {}
    
    for i = 1, table.getn(self.activeAlerts) do
        local alert = self.activeAlerts[i]
        if currentTime - alert.timestamp < 30 then
            table.insert(newAlerts, alert)
        end
    end
    
    self.activeAlerts = newAlerts
end

-- Obtener alertas activas
function BossMods:GetActiveAlerts()
    self:CleanupAlerts()
    return self.activeAlerts
end

-- Obtener estadísticas
function BossMods:GetStats()
    return self.stats
end

-- Comando slash
SlashCmdList["WCSBOSSMODS"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("=== WCS Boss Mods Status ===", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("BigWigs: " .. (BossMods.isBigWigsLoaded and "ACTIVO" or "INACTIVO"), 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("DBM: " .. (BossMods.isDBMLoaded and "ACTIVO" or "INACTIVO"), 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Auto React: " .. (BossMods.config.autoReact and "ON" or "OFF"), 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Alertas Activas: " .. table.getn(BossMods.activeAlerts), 1, 1, 1)
        
    elseif msg == "stats" then
        local stats = BossMods:GetStats()
        DEFAULT_CHAT_FRAME:AddMessage("=== WCS Boss Mods Stats ===", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("Total Alertas: " .. stats.totalAlerts, 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Reacciones: " .. stats.reactionsTriggered, 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Alertas por Tipo:", 0, 1, 1)
        for alertType, count in pairs(stats.alertsByType) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. alertType .. ": " .. count, 1, 1, 1)
        end
        
    elseif msg == "alerts" then
        local alerts = BossMods:GetActiveAlerts()
        DEFAULT_CHAT_FRAME:AddMessage("=== Alertas Activas ===", 1, 1, 0)
        if table.getn(alerts) == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("No hay alertas activas", 1, 1, 1)
        else
            for i = 1, table.getn(alerts) do
                local alert = alerts[i]
                local age = GetTime() - alert.timestamp
                DEFAULT_CHAT_FRAME:AddMessage(string.format("[%s] %s (%.1fs)", alert.source, alert.message, age), 1, 1, 1)
            end
        end
        
    elseif msg == "history" then
        DEFAULT_CHAT_FRAME:AddMessage("=== Historial de Alertas (últimas 10) ===", 1, 1, 0)
        local count = table.getn(BossMods.alertHistory)
        local start = math.max(1, count - 9)
        for i = start, count do
            local alert = BossMods.alertHistory[i]
            DEFAULT_CHAT_FRAME:AddMessage(string.format("[%s] %s", alert.source, alert.message), 1, 1, 1)
        end
        
    elseif msg == "toggle" then
        BossMods.config.autoReact = not BossMods.config.autoReact
        local status = BossMods.config.autoReact and "ACTIVADO" or "DESACTIVADO"
        if WCS_Brain.Notifications then
            WCS_Brain.Notifications:Success("Auto React " .. status)
        else
            DEFAULT_CHAT_FRAME:AddMessage("WCS Boss Mods: Auto React " .. status, 0, 1, 0)
        end
        
    elseif msg == "clear" then
        BossMods.activeAlerts = {}
        if WCS_Brain.Notifications then
            WCS_Brain.Notifications:Success("Alertas limpiadas")
        else
            DEFAULT_CHAT_FRAME:AddMessage("WCS Boss Mods: Alertas limpiadas", 0, 1, 0)
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS Boss Mods - Comandos:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsbm status - Ver estado", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsbm stats - Ver estadísticas", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsbm alerts - Ver alertas activas", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsbm history - Ver historial", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsbm toggle - Toggle auto react", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsbm clear - Limpiar alertas", 1, 1, 1)
    end
end
SLASH_WCSBOSSMODS1 = "/wcsbm"
SLASH_WCSBOSSMODS2 = "/wcsbossmods"

-- Inicializar al cargar
BossMods:Initialize()

if WCS_Brain.Notifications then
    WCS_Brain.Notifications:Info("Integración Boss Mods lista. Usa /wcsbm")
end
