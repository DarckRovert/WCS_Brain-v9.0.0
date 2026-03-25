--[[
WCS_BrainMajorDemons.lua v6.5.0
Sistema de Deteccion y Manejo de Demonios Mayores (Infernal y Doomguard)

Compatible con Lua 5.0 (Turtle WoW / WoW 1.12)

Este modulo extiende WCS_BrainPetAI con soporte mejorado para:
- Infernal: Invocado con Inferno, dura 5 minutos
- Doomguard: Invocado con Ritual of Doom

v6.5.0: Alertas visuales mejoradas (60s, 30s, 15s)
]]

WCS_BrainMajorDemons = WCS_BrainMajorDemons or {}
local MajorDemons = WCS_BrainMajorDemons

MajorDemons.VERSION = "6.5.0"
MajorDemons.debug = false

-- Estado de tracking
MajorDemons.State = {
    currentDemon = nil,
    summonTime = nil,
    warning60Shown = false,
    warning30Shown = false,
    warning15Shown = false,
    lastPetName = nil
}

-- Duraciones conocidas (en segundos)
MajorDemons.DURATIONS = {
    Infernal = 300,
    Doomguard = 300
}

-- ============================================================================
-- FUNCIONES DE UTILIDAD (Lua 5.0 compatible)
-- ============================================================================

function MajorDemons:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[MajorDemons]|r " .. tostring(msg))
end

function MajorDemons:DebugPrint(msg)
    if self.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6600[MajorDemons Debug]|r " .. tostring(msg))
    end
end

local function GetTime_Safe()
    if GetTime then
        return GetTime()
    end
    return 0
end

-- ============================================================================
-- DETECCION AVANZADA DE DEMONIOS MAYORES
-- ============================================================================

function MajorDemons:DetectMajorDemon()
    if not UnitExists("pet") then 
        return nil 
    end
    
    local petName = UnitName("pet")
    if not petName then 
        return nil 
    end
    
    petName = string.lower(petName)
    
    -- ========================================================================
    -- DETECCION POR NOMBRE
    -- ========================================================================
    
    -- Infernal (EN: Infernal, ES: Infernal)
    if string.find(petName, "infernal") then
        return "Infernal"
    end
    if string.find(petName, "inferno") then
        return "Infernal"
    end
    
    -- Doomguard (EN: Doomguard, ES: Guardia apocaliptico)
    if string.find(petName, "doomguard") then
        return "Doomguard"
    end
    if string.find(petName, "doom") then
        return "Doomguard"
    end
    if string.find(petName, "apocal") then
        return "Doomguard"
    end
    if string.find(petName, "destino") then
        return "Doomguard"
    end
    
    -- Caso especial: "guardia" sin "fel" = Doomguard
    if string.find(petName, "guardia") then
        if not string.find(petName, "fel") then
            if not string.find(petName, "vil") then
                return "Doomguard"
            end
        end
    end
    
    -- ========================================================================
    -- DETECCION POR HABILIDADES EN BARRA DE MASCOTA
    -- ========================================================================
    local i = 1
    while i <= 10 do
        local name = GetPetActionInfo(i)
        if name then
            name = string.lower(name)
            
            -- Infernal: Immolation Aura
            if string.find(name, "immolation") then
                return "Infernal"
            end
            if string.find(name, "inmolacion") then
                return "Infernal"
            end
            
            -- Doomguard: War Stomp, Cripple, Rain of Fire
            if string.find(name, "war stomp") then
                return "Doomguard"
            end
            if string.find(name, "cripple") then
                return "Doomguard"
            end
            if string.find(name, "rain of fire") then
                return "Doomguard"
            end
            if string.find(name, "pisoteon") then
                return "Doomguard"
            end
            if string.find(name, "tullir") then
                return "Doomguard"
            end
            if string.find(name, "lluvia") then
                return "Doomguard"
            end
        end
        i = i + 1
    end
    
    -- ========================================================================
    -- DETECCION POR CARACTERISTICAS (fallback)
    -- ========================================================================
    local petMana = UnitManaMax("pet")
    if not petMana then
        petMana = 0
    end
    
    -- Los demonios mayores no tienen mana
    if petMana == 0 then
        local petHP = UnitHealthMax("pet")
        if petHP and petHP > 0 then
            self:DebugPrint("Pet sin mana detectado - posible demonio mayor")
            -- Verificar que no sea un demonio normal
            -- Los demonios normales siempre tienen mana
            return "Infernal"
        end
    end
    
    return nil
end

-- ============================================================================
-- TRACKING DE TIEMPO
-- ============================================================================

function MajorDemons:OnDemonSummoned(demonType)
    self.State.currentDemon = demonType
    self.State.summonTime = GetTime_Safe()
    self.State.warning60Shown = false
    self.State.warning30Shown = false
    self.State.warning15Shown = false
    self.State.lastPetName = UnitName("pet")
    
    self:Print("|cff00ff00" .. demonType .. " INVOCADO!|r")
    
    local duration = self.DURATIONS[demonType]
    if not duration then
        duration = 300
    end
    self:Print("  Duracion estimada: " .. duration .. " segundos")
    
    -- Notificar a PetAI si existe
    if WCS_BrainPetAI then
        WCS_BrainPetAI.majorDemonSummonTime = self.State.summonTime
        WCS_BrainPetAI.majorDemonType = demonType
    end
end

function MajorDemons:GetTimeRemaining()
    if not self.State.summonTime then
        return 0
    end
    if not self.State.currentDemon then
        return 0
    end
    
    local elapsed = GetTime_Safe() - self.State.summonTime
    local duration = self.DURATIONS[self.State.currentDemon]
    if not duration then
        duration = 300
    end
    
    local remaining = duration - elapsed
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

function MajorDemons:ResetState()
    if self.State.currentDemon then
        self:DebugPrint("Demonio mayor perdido: " .. self.State.currentDemon)
    end
    self.State.currentDemon = nil
    self.State.summonTime = nil
    self.State.warning60Shown = false
    self.State.warning30Shown = false
    self.State.warning15Shown = false
    self.State.lastPetName = nil
    
    -- Limpiar en PetAI
    if WCS_BrainPetAI then
        WCS_BrainPetAI.majorDemonSummonTime = nil
        WCS_BrainPetAI.majorDemonType = nil
    end
end

-- ============================================================================
-- EVALUACION DE INFERNAL
-- ============================================================================

function MajorDemons:EvaluateInfernal()
    local timeRemaining = self:GetTimeRemaining()
    
    -- Alertas múltiples con sistema visual
    if timeRemaining > 0 then
        -- Alerta 60 segundos
        if timeRemaining <= 60 and timeRemaining > 59 and not self.State.warning60Shown then
            self.State.warning60Shown = true
            if WCS_BrainMajorDemonAlerts then
                WCS_BrainMajorDemonAlerts:ShowAlert("Infernal", 60, "normal")
            else
                self:Print("|cffFFFF00AVISO:|r Infernal expira en 60 segundos!")
            end
        end
        
        -- Alerta 30 segundos
        if timeRemaining <= 30 and timeRemaining > 29 and not self.State.warning30Shown then
            self.State.warning30Shown = true
            if WCS_BrainMajorDemonAlerts then
                WCS_BrainMajorDemonAlerts:ShowAlert("Infernal", 30, "high")
            else
                self:Print("|cffFF8800AVISO:|r Infernal expira en 30 segundos!")
            end
        end
        
        -- Alerta 15 segundos (CRÍTICA)
        if timeRemaining <= 15 and timeRemaining > 14 and not self.State.warning15Shown then
            self.State.warning15Shown = true
            if WCS_BrainMajorDemonAlerts then
                WCS_BrainMajorDemonAlerts:ShowAlert("Infernal", 15, "critical")
            else
                self:Print("|cffFF0000ALERTA CRÍTICA:|r Infernal expira en 15 segundos!")
            end
        end
    end
    
    -- Debug
    if self.debug then
        if timeRemaining > 0 then
            self:DebugPrint("Infernal - Tiempo restante: " .. string.format("%.0f", timeRemaining) .. "s")
        end
    end
    
    return false
end

-- ============================================================================
-- EVALUACION DE DOOMGUARD
-- ============================================================================

function MajorDemons:EvaluateDoomguard()
    local timeRemaining = self:GetTimeRemaining()
    
    -- Alertas múltiples con sistema visual
    if timeRemaining > 0 then
        -- Alerta 60 segundos
        if timeRemaining <= 60 and timeRemaining > 59 and not self.State.warning60Shown then
            self.State.warning60Shown = true
            if WCS_BrainMajorDemonAlerts then
                WCS_BrainMajorDemonAlerts:ShowAlert("Doomguard", 60, "normal")
            else
                self:Print("|cffFFFF00AVISO:|r Doomguard expira en 60 segundos!")
            end
        end
        
        -- Alerta 30 segundos
        if timeRemaining <= 30 and timeRemaining > 29 and not self.State.warning30Shown then
            self.State.warning30Shown = true
            if WCS_BrainMajorDemonAlerts then
                WCS_BrainMajorDemonAlerts:ShowAlert("Doomguard", 30, "high")
            else
                self:Print("|cffFF8800AVISO:|r Doomguard expira en 30 segundos!")
            end
        end
        
        -- Alerta 15 segundos (CRÍTICA)
        if timeRemaining <= 15 and timeRemaining > 14 and not self.State.warning15Shown then
            self.State.warning15Shown = true
            if WCS_BrainMajorDemonAlerts then
                WCS_BrainMajorDemonAlerts:ShowAlert("Doomguard", 15, "critical")
            else
                self:Print("|cffFF0000ALERTA CRÍTICA:|r Doomguard expira en 15 segundos!")
            end
        end
    end
    
    -- Debug
    if self.debug then
        if timeRemaining > 0 then
            self:DebugPrint("Doomguard - Tiempo restante: " .. string.format("%.0f", timeRemaining) .. "s")
        end
    end
    
    return false
end

-- ============================================================================
-- UPDATE PRINCIPAL
-- ============================================================================

function MajorDemons:Update()
    local detectedDemon = self:DetectMajorDemon()
    
    -- Nuevo demonio mayor detectado
    if detectedDemon then
        if detectedDemon ~= self.State.currentDemon then
            self:OnDemonSummoned(detectedDemon)
        end
    end
    
    -- Demonio mayor perdido (pet murio o expiro)
    if not detectedDemon then
        if self.State.currentDemon then
            self:ResetState()
        end
    end
    
    -- Evaluar demonio actual
    if self.State.currentDemon == "Infernal" then
        self:EvaluateInfernal()
    elseif self.State.currentDemon == "Doomguard" then
        self:EvaluateDoomguard()
    end
end

-- ============================================================================
-- FUNCIONES PUBLICAS PARA INTEGRACION
-- ============================================================================

-- ============================================================================
-- METODOS DE INTEGRACION (encapsulados)
-- ============================================================================

function WCS_BrainMajorDemons:IsMajorDemon()
    if self.State.currentDemon then
        return true
    end
    return false
end

function WCS_BrainMajorDemons:GetDemonTypePublic()
    return self.State.currentDemon
end

function WCS_BrainMajorDemons:GetTimeRemainingPublic()
    return self:GetTimeRemaining()
end

-- ============================================================================
-- ALIASES GLOBALES PARA COMPATIBILIDAD
-- ============================================================================

function WCS_BrainMajorDemons_IsMajorDemon()
    return WCS_BrainMajorDemons:IsMajorDemon()
end

function WCS_BrainMajorDemons_GetDemonType()
    return WCS_BrainMajorDemons:GetDemonTypePublic()
end

function WCS_BrainMajorDemons_GetTimeRemaining()
    return WCS_BrainMajorDemons:GetTimeRemainingPublic()
end

-- ============================================================================
-- FRAME DE ACTUALIZACION
-- ============================================================================

MajorDemons.frame = CreateFrame("Frame", "WCS_BrainMajorDemonsFrame")
MajorDemons.frame.elapsed = 0

MajorDemons.frame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 1.0 then
        this.elapsed = 0
        MajorDemons:Update()
    end
end)

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================

SLASH_MAJORDEMONS1 = "/majordemons"
SLASH_MAJORDEMONS2 = "/md"
SlashCmdList["MAJORDEMONS"] = function(msg)
    if not msg then
        msg = ""
    end
    local cmd = string.lower(msg)
    
    if cmd == "" or cmd == "status" then
        if MajorDemons.State.currentDemon then
            local timeLeft = MajorDemons:GetTimeRemaining()
            MajorDemons:Print("Demonio actual: |cff00ff00" .. MajorDemons.State.currentDemon .. "|r")
            MajorDemons:Print("Tiempo restante: " .. string.format("%.0f", timeLeft) .. " segundos")
        else
            MajorDemons:Print("No hay demonio mayor activo")
        end
        
    elseif cmd == "debug" then
        MajorDemons.debug = not MajorDemons.debug
        local status = "OFF"
        if MajorDemons.debug then
            status = "ON"
        end
        MajorDemons:Print("Debug: " .. status)
        
    elseif cmd == "test" then
        MajorDemons:Print("=== Test de Deteccion de Demonios Mayores ===")
        local detected = MajorDemons:DetectMajorDemon()
        if detected then
            MajorDemons:Print("Detectado: |cff00ff00" .. detected .. "|r")
        else
            MajorDemons:Print("Detectado: |cffff0000Ninguno|r")
        end
        if UnitExists("pet") then
            local petName = UnitName("pet")
            if petName then
                MajorDemons:Print("Nombre pet: " .. petName)
            end
            local petMana = UnitManaMax("pet")
            if petMana then
                MajorDemons:Print("Mana max pet: " .. petMana)
            end
            local petHP = UnitHealthMax("pet")
            if petHP then
                MajorDemons:Print("HP max pet: " .. petHP)
            end
        else
            MajorDemons:Print("No hay mascota activa")
        end
        
    elseif cmd == "help" then
        MajorDemons:Print("Comandos disponibles:")
        MajorDemons:Print("  /md status - Ver estado actual")
        MajorDemons:Print("  /md debug - Toggle modo debug")
        MajorDemons:Print("  /md test - Probar deteccion")
        
    else
        MajorDemons:Print("Comando desconocido. Usa /md help")
    end
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================

MajorDemons:Print("v" .. MajorDemons.VERSION .. " cargado")
