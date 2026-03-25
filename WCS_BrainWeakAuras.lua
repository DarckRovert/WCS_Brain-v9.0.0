-- WCS_BrainWeakAuras.lua
-- Integración con WeakAuras para WCS_Brain v6.9.0
-- Exporta datos del addon para uso en WeakAuras custom triggers

if not WCS_Brain then return end

WCS_Brain.WeakAuras = {
    -- Estado de integración
    isWeakAurasLoaded = false,
    lastUpdate = 0,
    updateInterval = 0.1, -- Actualizar cada 100ms para WeakAuras
    
    -- Datos exportados (accesibles desde WeakAuras)
    exports = {
        -- Estado del jugador
        player = {
            inCombat = false,
            health = 0,
            healthPercent = 0,
            mana = 0,
            manaPercent = 0,
            target = nil,
            targetHealth = 0,
            targetHealthPercent = 0,
        },
        
        -- Estado de la mascota
        pet = {
            exists = false,
            health = 0,
            healthPercent = 0,
            mana = 0,
            manaPercent = 0,
            happiness = 0,
            isActive = false,
            currentAction = "idle",
        },
        
        -- Estado de IA
        ai = {
            isEnabled = false,
            currentMode = "manual",
            lastDecision = "none",
            decisionCount = 0,
            confidence = 0,
        },
        
        -- Cooldowns importantes
        cooldowns = {
            -- Se llenará dinámicamente
        },
        
        -- Métricas de rendimiento
        performance = {
            fps = 0,
            latency = 0,
            memoryUsage = 0,
            eventsThrottled = 0,
        },
        
        -- Alertas activas
        alerts = {
            -- Array de alertas: {type, message, timestamp}
        },
    },
}

local WeakAuras = WCS_Brain.WeakAuras

-- Función para verificar si WeakAuras está cargado
function WeakAuras:CheckWeakAuras()
    if WeakAuras_LoadedAddons then
        self.isWeakAurasLoaded = true
        return true
    end
    return false
end

-- Inicializar integración
function WeakAuras:Initialize()
    -- Crear frame de actualización
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "WeakAuras" then
            WeakAuras:OnWeakAurasLoaded()
        elseif event == "PLAYER_ENTERING_WORLD" then
            WeakAuras:CheckWeakAuras()
        end
    end)
    
    frame:SetScript("OnUpdate", function()
        WeakAuras:OnUpdate(arg1)
    end)
    
    self.frame = frame
    
    -- Exponer datos globalmente para WeakAuras
    _G["WCS_WeakAurasData"] = self.exports
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Info("Integración WeakAuras inicializada")
    end
end

-- Cuando WeakAuras se carga
function WeakAuras:OnWeakAurasLoaded()
    self.isWeakAurasLoaded = true
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Success("WeakAuras detectado - Integración activa")
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS Brain: WeakAuras detectado", 0, 1, 0)
    end
end

-- Actualizar datos exportados
function WeakAuras:OnUpdate(elapsed)
    self.lastUpdate = self.lastUpdate + elapsed
    if self.lastUpdate < self.updateInterval then return end
    self.lastUpdate = 0
    
    -- Actualizar datos del jugador
    self:UpdatePlayerData()
    
    -- Actualizar datos de la mascota
    self:UpdatePetData()
    
    -- Actualizar estado de IA
    self:UpdateAIData()
    
    -- Actualizar cooldowns
    self:UpdateCooldowns()
    
    -- Actualizar métricas de rendimiento
    self:UpdatePerformance()
    
    -- Actualizar alertas
    self:UpdateAlerts()
end

-- Actualizar datos del jugador
function WeakAuras:UpdatePlayerData()
    local player = self.exports.player
    
    player.inCombat = UnitAffectingCombat("player")
    player.health = UnitHealth("player")
    player.healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
    player.mana = UnitMana("player")
    player.manaPercent = (UnitMana("player") / UnitManaMax("player")) * 100
    
    if UnitExists("target") then
        player.target = UnitName("target")
        player.targetHealth = UnitHealth("target")
        player.targetHealthPercent = (UnitHealth("target") / UnitHealthMax("target")) * 100
    else
        player.target = nil
        player.targetHealth = 0
        player.targetHealthPercent = 0
    end
end

-- Actualizar datos de la mascota
function WeakAuras:UpdatePetData()
    local pet = self.exports.pet
    
    pet.exists = UnitExists("pet")
    
    if pet.exists then
        pet.health = UnitHealth("pet")
        pet.healthPercent = (UnitHealth("pet") / UnitHealthMax("pet")) * 100
        pet.mana = UnitMana("pet")
        pet.manaPercent = (UnitMana("pet") / UnitManaMax("pet")) * 100
        
        -- Happiness (solo para hunters)
        local happiness, damagePercent, loyaltyRate = GetPetHappiness()
        pet.happiness = happiness or 0
        
        -- Estado de PetAI
        if WCS_Brain.PetAI then
            pet.isActive = WCS_Brain.PetAI.isEnabled or false
            pet.currentAction = WCS_Brain.PetAI.currentAction or "idle"
        end
    else
        pet.health = 0
        pet.healthPercent = 0
        pet.mana = 0
        pet.manaPercent = 0
        pet.happiness = 0
        pet.isActive = false
        pet.currentAction = "idle"
    end
end

-- Actualizar estado de IA
function WeakAuras:UpdateAIData()
    local ai = self.exports.ai
    
    if WCS_Brain.BrainAI then
        ai.isEnabled = WCS_Brain.BrainAI.isEnabled or false
        ai.currentMode = WCS_Brain.BrainAI.currentMode or "manual"
        ai.lastDecision = WCS_Brain.BrainAI.lastDecision or "none"
        ai.decisionCount = WCS_Brain.BrainAI.decisionCount or 0
        ai.confidence = WCS_Brain.BrainAI.confidence or 0
    else
        ai.isEnabled = false
        ai.currentMode = "manual"
        ai.lastDecision = "none"
        ai.decisionCount = 0
        ai.confidence = 0
    end
end

-- Actualizar cooldowns importantes
function WeakAuras:UpdateCooldowns()
    local cooldowns = {}
    
    if WCS_Brain.Cooldowns then
        for spellName, cdData in pairs(WCS_Brain.Cooldowns) do
            local endTime = nil
            local duration = 0
            
            -- cdData puede ser un número (timestamp) o una tabla
            if type(cdData) == "table" and cdData.endTime then
                endTime = cdData.endTime
                duration = cdData.duration or 0
            elseif type(cdData) == "number" then
                endTime = cdData
                duration = 0
            end
            
            if endTime then
                local remaining = endTime - GetTime()
                if remaining > 0 then
                    cooldowns[spellName] = {
                        remaining = remaining,
                        duration = duration,
                        percent = duration > 0 and ((remaining / duration) * 100) or 0,
                    }
                end
            end
        end
    end
    
    self.exports.cooldowns = cooldowns
end

-- Actualizar métricas de rendimiento
function WeakAuras:UpdatePerformance()
    local perf = self.exports.performance
    
    perf.fps = GetFramerate()
    
    local _, _, latency = GetNetStats()
    perf.latency = latency or 0
    
    -- UpdateAddOnMemoryUsage() no existe en WoW 1.12
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        perf.memoryUsage = GetAddOnMemoryUsage("WCS_Brain") or 0
    else
        perf.memoryUsage = 0
    end
    
    if WCS_Brain.EventThrottle then
        perf.eventsThrottled = WCS_Brain.EventThrottle.stats.totalThrottled or 0
    end
end

-- Actualizar alertas
function WeakAuras:UpdateAlerts()
    local alerts = {}
    
    -- Alertas de salud baja
    if self.exports.player.healthPercent < 30 then
        table.insert(alerts, {
            type = "warning",
            message = "Salud baja del jugador",
            timestamp = GetTime(),
        })
    end
    
    if self.exports.pet.exists and self.exports.pet.healthPercent < 30 then
        table.insert(alerts, {
            type = "warning",
            message = "Salud baja de la mascota",
            timestamp = GetTime(),
        })
    end
    
    -- Alertas de happiness baja (hunters)
    if self.exports.pet.exists and self.exports.pet.happiness == 1 then
        table.insert(alerts, {
            type = "error",
            message = "Mascota infeliz",
            timestamp = GetTime(),
        })
    end
    
    -- Alertas de rendimiento
    if self.exports.performance.fps < 20 then
        table.insert(alerts, {
            type = "critical",
            message = "FPS crítico",
            timestamp = GetTime(),
        })
    end
    
    if self.exports.performance.latency > 500 then
        table.insert(alerts, {
            type = "warning",
            message = "Latencia alta",
            timestamp = GetTime(),
        })
    end
    
    self.exports.alerts = alerts
end

-- Funciones helper para WeakAuras custom code

-- Obtener cooldown de un spell específico
function WeakAuras:GetSpellCooldown(spellName)
    if self.exports.cooldowns[spellName] then
        return self.exports.cooldowns[spellName].remaining
    end
    return 0
end

-- Verificar si un spell está en cooldown
function WeakAuras:IsSpellOnCooldown(spellName)
    return self.exports.cooldowns[spellName] ~= nil
end

-- Obtener estado de la IA
function WeakAuras:GetAIStatus()
    return self.exports.ai.isEnabled, self.exports.ai.currentMode
end

-- Obtener alertas activas de un tipo
function WeakAuras:GetAlertsByType(alertType)
    local result = {}
    for i = 1, table.getn(self.exports.alerts) do
        local alert = self.exports.alerts[i]
        if alert.type == alertType then
            table.insert(result, alert)
        end
    end
    return result
end

-- Exportar string de configuración para WeakAuras
function WeakAuras:ExportWeakAurasConfig()
    local config = {
        ["WCS Brain - Estado IA"] = {
            trigger = {
                type = "custom",
                custom = "function()\n  local data = WCS_WeakAurasData\n  if not data then return false end\n  return data.ai.isEnabled\nend",
                custom_type = "status",
            },
            display = {
                text = "IA: %s",
                text_format = "function()\n  local data = WCS_WeakAurasData\n  return data.ai.currentMode\nend",
            },
        },
        
        ["WCS Brain - Salud Mascota"] = {
            trigger = {
                type = "custom",
                custom = "function()\n  local data = WCS_WeakAurasData\n  if not data or not data.pet.exists then return false end\n  return data.pet.healthPercent < 50\nend",
                custom_type = "event",
            },
            display = {
                text = "Mascota: %.0f%%",
                text_format = "function()\n  local data = WCS_WeakAurasData\n  return data.pet.healthPercent\nend",
            },
        },
        
        ["WCS Brain - Cooldowns"] = {
            trigger = {
                type = "custom",
                custom = "function()\n  local data = WCS_WeakAurasData\n  if not data then return false end\n  -- Verificar cooldowns específicos\n  return data.cooldowns['SpellName'] ~= nil\nend",
                custom_type = "status",
            },
        },
        
        ["WCS Brain - Alertas"] = {
            trigger = {
                type = "custom",
                custom = "function()\n  local data = WCS_WeakAurasData\n  if not data then return false end\n  return #data.alerts > 0\nend",
                custom_type = "event",
            },
        },
    }
    
    return config
end

-- Comando slash para exportar configuración
SlashCmdList["WCSWEAKAURAS"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "status" then
        local status = WeakAuras.isWeakAurasLoaded and "ACTIVO" or "INACTIVO"
        DEFAULT_CHAT_FRAME:AddMessage("WCS WeakAuras: " .. status, 1, 1, 0)
        
        if WeakAuras.isWeakAurasLoaded then
            DEFAULT_CHAT_FRAME:AddMessage("Datos exportados en: WCS_WeakAurasData", 1, 1, 1)
        end
        
    elseif msg == "test" then
        DEFAULT_CHAT_FRAME:AddMessage("=== WCS WeakAuras Test ===", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("Player Health: " .. WeakAuras.exports.player.healthPercent .. "%", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Pet Exists: " .. tostring(WeakAuras.exports.pet.exists), 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("AI Enabled: " .. tostring(WeakAuras.exports.ai.isEnabled), 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Active Cooldowns: " .. WeakAuras:CountCooldowns(), 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Active Alerts: " .. table.getn(WeakAuras.exports.alerts), 1, 1, 1)
        
    elseif msg == "export" then
        DEFAULT_CHAT_FRAME:AddMessage("=== WCS WeakAuras - Ejemplos de Configuración ===", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("Copia estos ejemplos en WeakAuras > Custom Trigger:", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage(" ", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("1. Estado de IA:", 0, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("return WCS_WeakAurasData.ai.isEnabled", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage(" ", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("2. Salud de Mascota < 50%:", 0, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("return WCS_WeakAurasData.pet.healthPercent < 50", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage(" ", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("3. Cooldown específico:", 0, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("return WCS_WeakAurasData.cooldowns['SpellName'] ~= nil", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage(" ", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Ver documentación completa en: /wcswa help", 1, 0.82, 0)
        
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("=== WCS WeakAuras - Ayuda ===", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage(" ", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Datos Disponibles:", 0, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_WeakAurasData.player - Datos del jugador", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_WeakAurasData.pet - Datos de la mascota", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_WeakAurasData.ai - Estado de IA", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_WeakAurasData.cooldowns - Cooldowns activos", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_WeakAurasData.performance - Métricas", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_WeakAurasData.alerts - Alertas activas", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage(" ", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("Comandos:", 0, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /wcswa status - Ver estado", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /wcswa test - Test de datos", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /wcswa export - Ejemplos de config", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /wcswa help - Esta ayuda", 1, 1, 1)
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS WeakAuras - Comandos:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/wcswa status - Ver estado de integración", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcswa test - Test de datos exportados", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcswa export - Exportar ejemplos de config", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcswa help - Ayuda completa", 1, 1, 1)
    end
end
SLASH_WCSWEAKAURAS1 = "/wcswa"
SLASH_WCSWEAKAURAS2 = "/wcsweakauras"

-- Helper: Contar cooldowns activos
function WeakAuras:CountCooldowns()
    local count = 0
    for _ in pairs(self.exports.cooldowns) do
        count = count + 1
    end
    return count
end

-- Inicializar al cargar
WeakAuras:Initialize()

if WCS_Brain.Notifications then
    WCS_Brain.Notifications:Info("Integración WeakAuras lista. Usa /wcswa")
end
