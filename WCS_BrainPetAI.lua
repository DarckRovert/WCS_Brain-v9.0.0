
-- ============================================================================
-- SOPORTE EXTENSIBLE PARA NUEVAS MASCOTAS Y HABILIDADES
-- ============================================================================
-- (Moved below PetAI initialization)

--[[
    WCS_BrainPetAI.lua v8.0.0
    Sistema de IA Inteligente para Mascotas de Warlock

    Caracteristicas:
    - Mascotas menores: Imp, Voidwalker, Succubus, Felhunter, Felguard
    - Demonios mayores: Infernal, Doomguard
    - Sistema de Enslave con auto-reenslave
    - Soporte party/raid para Fire Shield
    Compatible con Lua 5.0 (Turtle WoW)
]]

WCS_BrainPetAI = WCS_BrainPetAI or {}
local PetAI = WCS_BrainPetAI
-- Permite registrar lógica personalizada para futuras mascotas o demonios especiales
PetAI.CustomPetLogic = {}

-- Registrar una nueva mascota personalizada
function PetAI:RegisterCustomPet(petType, logicFunc)
    if not petType or type(logicFunc) ~= "function" then return end
    self.CustomPetLogic[petType] = logicFunc
end

-- Ejemplo de plantilla para una nueva mascota (puedes copiar y adaptar)
--[[
PetAI:RegisterCustomPet("Fel Imp", function(self)
    -- Lógica específica para Fel Imp
    -- Ejemplo: priorizar Firebolt y Dispel
    local abilities = self:ScanPetAbilities()
    for i, ab in ipairs(abilities) do
        if ab.name == "Firebolt" and not self:IsOnCooldown("Firebolt") then
            self:SetCooldown("Firebolt", 2)
            return self:ExecuteAbility("Firebolt")
        end
        if ab.name == "Dispel Magic" and not self:IsOnCooldown("Dispel Magic") then
            self:SetCooldown("Dispel Magic", 8)
            return self:ExecuteAbility("Dispel Magic")
        end
    end
    return false
end)
]]

-- ============================================================================
-- SISTEMA DE EVENTOS INTERNO PARA MASCOTAS (modular, extensible)
-- Permite registrar y disparar callbacks para eventos clave (daño, muerte, cambio de estado, etc)
-- Uso: PetAI:RegisterEvent(event, callback), PetAI:TriggerEvent(event, ...)
-- ============================================================================
PetAI._eventCallbacks = {}

-- Registra un callback para un evento interno de la IA de mascota
function PetAI:RegisterEvent(event, callback)
    if not event or type(callback) ~= "function" then return end
    self._eventCallbacks[event] = self._eventCallbacks[event] or {}
    table.insert(self._eventCallbacks[event], callback)
end

-- Dispara un evento interno, llamando a todos los callbacks registrados
function PetAI:TriggerEvent(event, ...)
    if not event or not self._eventCallbacks[event] then return end
    local args = arg
    for i, cb in ipairs(self._eventCallbacks[event]) do
        if cb then
            local ok, err = pcall(function() cb(unpack(args)) end)
            if not ok and self.debug then
                self:DebugPrint("[EventSystem] Error en callback de '"..event.."': "..tostring(err))
            end
        end
    end
end

-- Ejemplo de integración: disparar eventos en situaciones clave
-- (Puedes expandir esto en los métodos de combate, muerte, cambio de estado, etc)

PetAI.VERSION = "8.0.0"  -- Mascotas inteligentes mejoradas + Sistema de ejecución corregido
PetAI.ENABLED = true
PetAI.debug = false
PetAI.lastUpdate = 0
PetAI.updateInterval = 0.5
PetAI.isThinking = false  -- Guard para prevenir race conditions

PetAI.cooldowns = {}

PetAI.Enslave = {
    enabled = true,
    lastDemonName = nil,
    enslaveTime = 0,
    enslaveDuration = 300,
    warningShown = false,
    isEnslaved = false,
    needReenslave = false
}

PetAI.Config = {
    aggressiveMode = false,
    autoSacrifice = true,
    autoFireShield = true,
    emergencyThreshold = 25,
    fireShieldRange = 30,           -- Rango maximo para Fire Shield (yards)
    fireShieldCooldown = 10,        -- Cooldown entre aplicaciones de Fire Shield
    voidwalkerSacrificeHP = 15,     -- HP% del Voidwalker para auto-sacrificio
    smartSacrifice = true           -- Sacrificio inteligente cuando va a morir
}

-- ============================================================================
PetAI.currentMode = 1  -- 1=Agresivo, 2=Defensivo, 3=Soporte, 4=Guardián

-- Variables para modo Guardián
PetAI.GuardianTarget = nil  -- Nombre del jugador a proteger
PetAI.GuardianLastCheck = 0
PetAI.GuardianCheckInterval = 0.5  -- Revisar cada 0.5 segundos

-- Tabla para rastrear casteos enemigos en 1.12 (Combat Log fallback)
PetAI.EnemyCastingTable = {}

-- Configuración de comportamiento por modo
PetAI.ModeConfig = {
    [1] = {  -- Agresivo
        name = "Agresivo",
        attackPriority = "high",      -- Prioridad de ataque
        defensePriority = "low",      -- Prioridad de defensa
        supportPriority = "low",      -- Prioridad de soporte
        autoAttack = true,            -- Atacar automáticamente
        useOffensive = true,          -- Usar habilidades ofensivas
        useDefensive = false,         -- Usar habilidades defensivas
        useSupport = false,           -- Usar habilidades de soporte
        aggressiveMode = true         -- Modo agresivo legacy
    },
    [2] = {  -- Defensivo
        name = "Defensivo",
        attackPriority = "medium",
        defensePriority = "high",
        supportPriority = "medium",
        autoAttack = true,
        useOffensive = false,
        useDefensive = true,
        useSupport = true,
        aggressiveMode = false
    },
    [3] = {  -- Soporte
        name = "Soporte",
        attackPriority = "low",
        defensePriority = "medium",
        supportPriority = "high",
        autoAttack = false,
        useOffensive = false,
        useDefensive = true,
        useSupport = true,
        aggressiveMode = false
    },
    [4] = {  -- Guardián
        name = "Guardian",
        attackPriority = "high",
        defensePriority = "high",
        supportPriority = "high",
        autoAttack = true,
        useOffensive = true,
        useDefensive = true,
        useSupport = true,
        aggressiveMode = false
    }
}

-- Función para cambiar el modo de IA
function PetAI:SetMode(mode)
    -- Convertir a numero si es string
    if type(mode) == "string" then
        mode = tonumber(mode)
    end
    
    if not mode or mode < 1 or mode > 4 then
        self:Print("Modo inválido. Usa 1 (Agresivo), 2 (Defensivo), 3 (Soporte) o 4 (Guardián)")
        return false
    end
    -- Si cambia a modo Guardián sin target asignado, avisar
    if mode == 4 and not self.GuardianTarget then
        self:Print("Modo Guardián activado. Usa /petguard [nombre] para asignar a quién proteger")
    end
    
    self.currentMode = mode
    local config = self.ModeConfig[mode]
    
    if not config then
        self:Print("ERROR: Configuración de modo no encontrada")
        return false
    end
    
    -- Actualizar configuración legacy
    self.Config.aggressiveMode = config.aggressiveMode
    
    -- Mensaje de confirmación
    local modeNames = {
        [1] = "|cFFFF0000Agresivo|r",
        [2] = "|cFF00FF00Defensivo|r",
        [3] = "|cFF00CCFFSoporte|r",
        [4] = "|cFFFFD700Guardián|r"
    }
    
    self:Print("Modo de IA cambiado a: " .. modeNames[mode])
    
    -- Disparar evento para otros módulos
    if self.TriggerEvent then
        self:TriggerEvent("MODE_CHANGED", mode, config.name)
    end
    
    return true
end

-- Función para obtener el modo actual
function PetAI:GetMode()
    return self.currentMode or 1
end

-- Función para obtener el nombre del modo actual
function PetAI:GetModeName()
    local config = self.ModeConfig[self.currentMode]
    return config and config.name or "Desconocido"
end

-- Función helper para verificar si debe usar habilidades ofensivas
function PetAI:ShouldUseOffensive()
    local config = self.ModeConfig[self.currentMode]
    return config and config.useOffensive or false
end

-- Función helper para verificar si debe usar habilidades defensivas
function PetAI:ShouldUseDefensive()
    local config = self.ModeConfig[self.currentMode]
    return config and config.useDefensive or false
end

-- Función helper para verificar si debe usar habilidades de soporte
function PetAI:ShouldUseSupport()
    local config = self.ModeConfig[self.currentMode]
    return config and config.useSupport or false
end


-- Cache de Fire Shield para evitar spam
PetAI.FireShieldCache = {
    lastTarget = nil,
    lastTime = 0,
    appliedTo = {}  -- {unitName = timestamp}
}

function PetAI:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[PetAI]|r " .. tostring(msg))
    end
end

function PetAI:DebugPrint(msg)
    if self.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[PetAI Debug]|r " .. tostring(msg))
    end
end

function PetAI:GetPlayerHealthPercent()
    local current = UnitHealth("player") or 0
    local max = UnitHealthMax("player") or 1
    if max == 0 then max = 1 end
    return (current / max) * 100
end

function PetAI:GetPetHealthPercent()
    if not UnitExists("pet") then return 0 end
    local current = UnitHealth("pet") or 0
    local max = UnitHealthMax("pet") or 1
    if max == 0 then max = 1 end
    return (current / max) * 100
end

function PetAI:GetPetManaPercent()
    if not UnitExists("pet") then return 0 end
    local current = UnitMana("pet") or 0
    local max = UnitManaMax("pet") or 1
    if max == 0 then max = 1 end
    return (current / max) * 100
end

function PetAI:PetHasBuff(pattern)
    if not UnitExists("pet") then return false end
    if not pattern then return false end
    local patternLower = string.lower(pattern)
    for i = 1, 32 do
        local texture = UnitBuff("pet", i)
        if not texture then break end
        if string.find(string.lower(texture), patternLower) then
            return true
        end
    end
    return false
end

function PetAI:HasImmolationAura()
    return self:PetHasBuff("incinerate") or self:PetHasBuff("immolat")
end

function PetAI:ListPetBuffs()
    if not UnitExists("pet") then 
        self:Print("No hay pet activo")
        return 
    end
    self:Print("Buffs del pet:")
    local count = 0
    for i = 1, 32 do
        local texture = UnitBuff("pet", i)
        if not texture then break end
        count = count + 1
        self:Print("  " .. tostring(i) .. ": " .. tostring(texture))
    end
    if count == 0 then
        self:Print("  (ninguno)")
    end
end

function PetAI:GetPetType()
    if not UnitExists("pet") then return nil end
    
    -- Metodo 1: Usar UnitCreatureFamily (mas confiable)
    local family = UnitCreatureFamily("pet")
    if family then
        family = string.lower(family)
        if family == "imp" or string.find(family, "imp") then return "Imp" end
        if family == "voidwalker" or string.find(family, "void") then return "Voidwalker" end
        if family == "succubus" or string.find(family, "succub") then return "Succubus" end
        if family == "felhunter" or string.find(family, "felhunter") then return "Felhunter" end
        if family == "felguard" or string.find(family, "felguard") then return "Felguard" end
        if family == "infernal" or string.find(family, "infernal") then return "Infernal" end
        if family == "doomguard" or string.find(family, "doomguard") then return "Doomguard" end
    end
    
    -- Metodo 2: Detectar por habilidades del pet
    for i = 1, 10 do
        local name = GetPetActionInfo(i)
        if name then
            local nameLower = string.lower(name)
            -- Imp: Fire Shield, Firebolt
            if string.find(nameLower, "fire shield") or string.find(nameLower, "firebolt") then
                return "Imp"
            end
            -- Voidwalker: Torment, Sacrifice, Suffering, Consume Shadows
            if string.find(nameLower, "torment") or string.find(nameLower, "sacrifice") or string.find(nameLower, "suffering") then
                return "Voidwalker"
            end
            -- Succubus: Seduction, Lash of Pain, Soothing Kiss
            if string.find(nameLower, "seduction") or string.find(nameLower, "lash of pain") or string.find(nameLower, "soothing") then
                return "Succubus"
            end
            -- Felhunter: Devour Magic, Spell Lock, Tainted Blood
            if string.find(nameLower, "devour") or string.find(nameLower, "spell lock") or string.find(nameLower, "tainted") then
                return "Felhunter"
            end
            -- Felguard: Cleave, Intercept, Anguish
            if string.find(nameLower, "intercept") or string.find(nameLower, "anguish") then
                return "Felguard"
            end
            -- Infernal: Immolation
            if string.find(nameLower, "immolation") then
                return "Infernal"
            end
            -- Doomguard: War Stomp, Cripple, Rain of Fire
            if string.find(nameLower, "war stomp") or string.find(nameLower, "cripple") then
                return "Doomguard"
            end
        end
    end
    
    -- Metodo 3: Fallback por nombre (algunos servers usan nombres genericos)
    local petName = UnitName("pet")
    if petName then
        petName = string.lower(petName)
        if string.find(petName, "imp") then return "Imp" end
        if string.find(petName, "void") then return "Voidwalker" end
        if string.find(petName, "succub") then return "Succubus" end
        if string.find(petName, "felhunter") then return "Felhunter" end
        if string.find(petName, "felguard") then return "Felguard" end
        if string.find(petName, "infernal") then return "Infernal" end
        if string.find(petName, "doomguard") then return "Doomguard" end
    end
    
    return "Unknown"
end

function PetAI:IsEnslavedDemon()
    if not UnitExists("pet") then return false end
    local petType = self:GetPetType()
    if petType == "Unknown" then
        return true
    end
    return false
end

function PetAI:ClassifyAbility(name, texture)
    if not name then return "unknown" end
    local nameLower = string.lower(tostring(name))
    
    if string.find(nameLower, "fire") then return "damage" end
    if string.find(nameLower, "bolt") then return "damage" end
    if string.find(nameLower, "blast") then return "damage" end
    if string.find(nameLower, "strike") then return "damage" end
    if string.find(nameLower, "cleave") then return "damage" end
    if string.find(nameLower, "lash") then return "damage" end
    if string.find(nameLower, "rain") then return "damage" end
    if string.find(nameLower, "stun") then return "cc" end
    if string.find(nameLower, "stomp") then return "cc" end
    if string.find(nameLower, "fear") then return "cc" end
    if string.find(nameLower, "seduc") then return "cc" end
    if string.find(nameLower, "cripple") then return "debuff" end
    if string.find(nameLower, "slow") then return "debuff" end
    if string.find(nameLower, "curse") then return "debuff" end
    return "utility"
end

function PetAI:ScanPetAbilities()
    local abilities = {}
    if not UnitExists("pet") then return abilities end
    
    for i = 1, 10 do
        local name, subtext, texture = GetPetActionInfo(i)
        if name and name ~= "" then
            local cat = self:ClassifyAbility(name, texture)
            local ab = {}
            ab.slot = i
            ab.name = tostring(name)
            ab.texture = tostring(texture or "")
            ab.category = cat
            table.insert(abilities, ab)
        end
    end
    return abilities
end

function PetAI:GetMajorDemonTimeRemaining()
    if WCS_BrainMajorDemons and WCS_BrainMajorDemons.GetTimeRemaining then
        return WCS_BrainMajorDemons:GetTimeRemaining()
    end
    return nil
end

function PetAI:IsOnCooldown(spellName)
    local cd = self.cooldowns[spellName]
    if not cd then return false end
    return (GetTime() - cd.start) < cd.duration
end

function PetAI:SetCooldown(spellName, duration)
    self.cooldowns[spellName] = { start = GetTime(), duration = duration }
end
-- ============================================================================
-- NUEVAS FUNCIONES v8.0.0 - Sistema mejorado de ejecución
-- ============================================================================

-- Obtener slot de habilidad por nombre
function PetAI:GetPetAbilitySlot(spellName)
    if not UnitExists("pet") or not spellName then return nil end
    for i = 1, 10 do
        local name = GetPetActionInfo(i)
        if name and string.lower(name) == string.lower(spellName) then
            return i
        end
    end
    return nil
end

-- Verificar si la mascota tiene la habilidad
function PetAI:PetHasAbility(spellName)
    return self:GetPetAbilitySlot(spellName) ~= nil
end

-- Verificar si se puede castear (habilidad existe + no en CD + suficiente mana)
function PetAI:CanCastPetAbility(spellName)
    if not UnitExists("pet") or not spellName then return false end
    local slot = self:GetPetAbilitySlot(spellName)
    if not slot then 
        self:DebugPrint("[CanCast] " .. spellName .. " - NO ENCONTRADA")
        return false 
    end
    local start, duration, enable = GetPetActionCooldown(slot)
    if start and duration and duration > 0 then
        local remaining = duration - (GetTime() - start)
        if remaining > 0 then
            self:DebugPrint("[CanCast] " .. spellName .. " - EN CD (" .. string.format("%.1f", remaining) .. "s)")
            return false
        end
    end
    local isUsable, notEnoughMana = GetPetActionInfo(slot)
    if notEnoughMana then
        self:DebugPrint("[CanCast] " .. spellName .. " - SIN MANA")
        return false
    end
    return true
end

function PetAI:ExecuteAbility(spellName)
    if not spellName then return false end
    if not self:CanCastPetAbility(spellName) then return false end
    
    local success = false
    local slot = self:GetPetAbilitySlot(spellName)
    
    -- PRIORIDAD 1: CastPetAction (Nativo y robusto para 1.12)
    if slot then
        CastPetAction(slot)
        success = true
        self:DebugPrint("[Execute] " .. spellName .. " - CastPetAction(" .. slot .. ")")
    -- PRIORIDAD 2: CastSpellByName (Solo como fallback para hechizos del jugador como Enslave)
    elseif CastSpellByName then
        CastSpellByName(spellName)
        success = true
        self:DebugPrint("[Execute] " .. spellName .. " - CastSpellByName")
    end
    
    if success then
        -- Cooldown interno: Respetar 1s de GCD global de pets en 1.12
        self:SetCooldown(spellName, 1.0)
    end
    return success
end

function PetAI:CastEnslaveDemon()
    self:Print("|cffff00ffRe-esclavizando demonio!|r")
    if CastSpellByName then
        CastSpellByName("Enslave Demon")
        return
    end
    if ChatFrameEditBox then
        local cmd = "/cast Enslave Demon"
        ChatFrameEditBox:SetText(cmd)
        ChatEdit_SendText(ChatFrameEditBox)
    end
end

function PetAI:EvaluateEnslaved()
    local abilities = self:ScanPetAbilities()
    local inCombat = UnitAffectingCombat("pet")
    local playerHP = self:GetPlayerHealthPercent()
    local numAbs = WCS_TableCount(abilities)
    
    if playerHP < 30 then
        for i = 1, numAbs do
            local ab = abilities[i]
            if ab and ab.category == "cc" and ab.name then
                if not self:IsOnCooldown(ab.name) then
                    self:SetCooldown(ab.name, 15)
                    self:Print("|cffff6600Enslaved:|r Usando " .. ab.name .. " (emergencia)")
                    return self:ExecuteAbility(ab.name)
                end
            end
        end
    end
    
    if inCombat then
        for i = 1, numAbs do
            local ab = abilities[i]
            if ab and ab.category == "damage" and ab.name then
                if not self:IsOnCooldown(ab.name) then
                    self:SetCooldown(ab.name, 6)
                    return self:ExecuteAbility(ab.name)
                end
            end
        end
        for i = 1, numAbs do
            local ab = abilities[i]
            if ab and ab.category == "debuff" and ab.name then
                if not self:IsOnCooldown(ab.name) then
                    self:SetCooldown(ab.name, 10)
                    return self:ExecuteAbility(ab.name)
                end
            end
        end
    end
    return false
end

function PetAI:CheckEnslaveStatus()
    if not self.Enslave.enabled then return end
    
    if self.Enslave.isEnslaved and not UnitExists("pet") then
        self:Print("|cffff0000El demonio se escapo!|r Intentando re-esclavizar...")
        if self.Enslave.lastDemonName then
            TargetByName(self.Enslave.lastDemonName)
            self.Enslave.needReenslave = true
        end
        self.Enslave.isEnslaved = false
    end
    
    if self.Enslave.needReenslave and UnitExists("target") then
        self:CastEnslaveDemon()
        self.Enslave.needReenslave = false
    end
    
    if self.Enslave.isEnslaved then
        local elapsed = GetTime() - self.Enslave.enslaveTime
        local remaining = self.Enslave.enslaveDuration - elapsed
        if remaining < 30 and not self.Enslave.warningShown then
            self:Print("|cffff6600ADVERTENCIA:|r Enslave expira en 30 segundos!")
            self.Enslave.warningShown = true
        end
    end
end

function PetAI:OnPetChanged()
    if UnitExists("pet") then
        local petType = self:GetPetType()
        if petType == "Unknown" then
            self.Enslave.isEnslaved = true
            self.Enslave.lastDemonName = UnitName("pet")
            self.Enslave.enslaveTime = GetTime()
            self.Enslave.warningShown = false
            self:Print("|cff00ff00Demonio esclavizado:|r " .. tostring(self.Enslave.lastDemonName))
        end
    end
end

-- ============================================================================
-- FUNCIONES DE SOPORTE PARA MASCOTAS MENORES
-- ============================================================================

function PetAI:HasFireShield(unit)
    if not UnitExists(unit) then return false end
    for i = 1, 32 do
        local texture = UnitBuff(unit, i)
        if not texture then break end
        local texLower = string.lower(texture)
        if string.find(texLower, "fire_firearmor") or string.find(texLower, "firearmor") then
            return true
        end
    end
    return false
end

function PetAI:HasDebuff(unit, pattern)
    if not UnitExists(unit) then return false end
    for i = 1, 16 do
        local texture = UnitDebuff(unit, i)
        if not texture then break end
        if pattern then
            if string.find(string.lower(texture), string.lower(pattern)) then
                return true
            end
        else
            return true
        end
    end
    return false
end

function PetAI:GetGroupMembers()
    local members = {}
    table.insert(members, {unit = "player", name = UnitName("player")})
    
    local numRaid = GetNumRaidMembers()
    if numRaid and numRaid > 0 then
        for i = 1, numRaid do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                table.insert(members, {unit = unit, name = UnitName(unit)})
            end
        end
        return members
    end
    
    local numParty = GetNumPartyMembers()
    if numParty and numParty > 0 then
        for i = 1, numParty do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(members, {unit = unit, name = UnitName(unit)})
            end
        end
    end
    return members
end

function PetAI:FindMemberNeedingFireShield()
    local members = self:GetGroupMembers()
    local numMembers = WCS_TableCount(members)
    local now = GetTime()
    local cfg = self.Config
    local cache = self.FireShieldCache
    
    for i = 1, numMembers do
        local member = members[i]
        if member and UnitExists(member.unit) and not UnitIsDead(member.unit) then
            -- Verificar si ya tiene Fire Shield (buff activo)
            if not self:HasFireShield(member.unit) then
                -- Verificar cache para evitar spam al mismo objetivo
                local memberName = member.name or ""
                local lastApplied = cache.appliedTo[memberName] or 0
                
                -- Solo aplicar si paso suficiente tiempo desde ultima aplicacion
                if (now - lastApplied) > (cfg.fireShieldCooldown or 10) then
                    -- Verificar rango: player siempre en rango, otros verificar distancia
                    local inRange = false
                    if member.unit == "player" then
                        inRange = true
                    else
                        -- CheckInteractDistance: 1=10yd, 2=11yd, 3=10yd, 4=28yd
                        -- Usamos 4 que es ~28 yards (cercano a 30)
                        inRange = CheckInteractDistance(member.unit, 4)
                    end
                    
                    if inRange then
                        return member
                    end
                end
            end
        end
    end
    return nil
end

-- Marcar que aplicamos Fire Shield a un miembro
function PetAI:MarkFireShieldApplied(memberName)
    if not memberName then return end
    self.FireShieldCache.appliedTo[memberName] = GetTime()
    self.FireShieldCache.lastTarget = memberName
    self.FireShieldCache.lastTime = GetTime()
end

-- Limpiar cache de Fire Shield (llamar periodicamente)
function PetAI:CleanFireShieldCache()
    local now = GetTime()
    local cache = self.FireShieldCache
    local expireTime = 60  -- Limpiar entradas mas viejas de 60 segundos
    
    for name, timestamp in pairs(cache.appliedTo) do
        if (now - timestamp) > expireTime then
            cache.appliedTo[name] = nil
        end
    end
end

function PetAI:ScheduleTargetRestore(targetName)
    if not targetName then return end
    if not self.RestoreFrame then
        self.RestoreFrame = CreateFrame("Frame")
    end
    self.RestoreTargetName = targetName
    self.RestoreFrame.elapsed = 0
    self.RestoreFrame:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed > 0.5 then
            this:SetScript("OnUpdate", nil)
            if PetAI.RestoreTargetName then
                TargetByName(PetAI.RestoreTargetName)
                PetAI.RestoreTargetName = nil
            end
        end
    end)
end

function PetAI:ScheduleClearTarget()
    if not self.ClearFrame then
        self.ClearFrame = CreateFrame("Frame")
    end
    self.ClearFrame.elapsed = 0
    self.ClearFrame:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed > 0.5 then
            this:SetScript("OnUpdate", nil)
            ClearTarget()
        end
    end)
end

function PetAI:ExecutePetAbilityOnTarget(spellName, targetUnit, targetName)
    if self:IsOnCooldown(spellName) then
        return false
    end
    
    local hadTarget = UnitExists("target")
    local oldTargetName = nil
    if hadTarget then
        oldTargetName = UnitName("target")
    end
    
    if targetUnit == "player" then
        TargetUnit("player")
    else
        TargetUnit(targetUnit)
    end
    
    if not UnitExists("target") then
        return false
    end
    
    local cmd = "/cast " .. tostring(spellName)
    ChatFrameEditBox:SetText(cmd)
    ChatEdit_SendText(ChatFrameEditBox)
    
    self:Print("|cff00ff00" .. tostring(spellName) .. "|r -> " .. tostring(targetName or targetUnit))
    self:SetCooldown(spellName, 4)
    
    if hadTarget and oldTargetName then
        self:ScheduleTargetRestore(oldTargetName)
    elseif not hadTarget then
        self:ScheduleClearTarget()
    end
    return true
end

-- ============================================================================
-- EVALUACION DE MASCOTAS MENORES
-- ============================================================================

function PetAI:EvaluateImp()
    local petMana = self:GetPetManaPercent()
    
    -- Verificar modo: Fire Shield es habilidad de SOPORTE
    if not self:ShouldUseSupport() then
        self:DebugPrint("[Imp] Modo actual no permite habilidades de soporte")
        return false
    end
    
    -- Limpiar cache periodicamente
    self:CleanFireShieldCache()
    
    -- Solo buscar objetivo si tiene mana suficiente
    if petMana > 20 then
        local member = self:FindMemberNeedingFireShield()
        if member then
            -- Marcar en cache ANTES de ejecutar
            self:MarkFireShieldApplied(member.name)
            
            local success = self:ExecutePetAbilityOnTarget("Fire Shield", member.unit, member.name)
            if success then
                self:DebugPrint("Fire Shield aplicado a " .. tostring(member.name))
            end
            return success
        end
    end
    return false
end

function PetAI:EvaluateVoidwalker()
    local playerHP = self:GetPlayerHealthPercent()
    local petHP = self:GetPetHealthPercent()
    local cfg = self.Config
    local inCombat = UnitAffectingCombat("player") or UnitAffectingCombat("pet")
    
    -- PRIORIDAD 1: Emergencia del jugador - sacrificio inmediato
    if playerHP < (cfg.emergencyThreshold or 25) and inCombat then
        -- Verificar modo: Sacrifice es habilidad DEFENSIVA
        if not self:ShouldUseDefensive() then
            self:DebugPrint("[Voidwalker] Modo actual no permite Sacrifice")
            return false
        end
        self:Print("|cffff0000EMERGENCIA!|r Tu HP: " .. string.format("%.0f", playerHP) .. "% - Sacrificando para salvarte!")
        return self:ExecuteAbility("Sacrifice")
    end
    
        -- PRIORIDAD 2: Peeling - Proteger al jugador de atacantes directos
    if inCombat and not self:IsOnCooldown("Suffering") then
        if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
             if self:ShouldUseDefensive() then
                self:SetCooldown("Suffering", 120)
                self:Print("|cffff6600¡PEELING!|r Quitando aggro de tu atacante")
                return self:ExecuteAbility("Suffering")
             end
        end
    end
    -- PRIORIDAD 3: Suffering para quitar aggro del jugador
    if playerHP < 50 and inCombat then
        if not self:IsOnCooldown("Suffering") then
            -- Verificar modo: Suffering es habilidad DEFENSIVA
            if not self:ShouldUseDefensive() then
                self:DebugPrint("[Voidwalker] Modo actual no permite Suffering")
                return false
            end
            self:SetCooldown("Suffering", 120)
            self:Print("|cffFFFF00Suffering!|r Quitando aggro del jugador")
            return self:ExecuteAbility("Suffering")
        end
    end
    
    -- PRIORIDAD 4: Torment para mantener aggro
    if playerHP < 70 and inCombat then
        if not self:IsOnCooldown("Torment") then
            -- Verificar modo: Torment es habilidad OFENSIVA
            if not self:ShouldUseOffensive() then
                self:DebugPrint("[Voidwalker] Modo actual no permite Torment")
                return false
            end
            self:SetCooldown("Torment", 5)
            return self:ExecuteAbility("Torment")
        end
    end
    
    -- PRIORIDAD 5: Curarse fuera de combate
    if petHP < 50 and not inCombat then
        if not self:IsOnCooldown("Consume Shadows") then
            self:SetCooldown("Consume Shadows", 30)
            self:DebugPrint("Consume Shadows - curando fuera de combate")
            return self:ExecuteAbility("Consume Shadows")
        end
    end
    
    return false
end

function PetAI:EvaluateSuccubus()
    local playerHP = self:GetPlayerHealthPercent()
    local petHP = self:GetPetHealthPercent()
    local isAggressive = self.Config and self.Config.aggressiveMode
    local inCombat = UnitAffectingCombat("player") or UnitAffectingCombat("pet")
    
    -- PRIORIDAD 1: Seduction de emergencia cuando hay multiples enemigos
    -- o cuando el jugador esta en peligro
    if inCombat and playerHP < 50 then
        -- Intentar seducir un enemigo que NO sea el target actual del pet
        if not self:IsOnCooldown("Seduction") then
                -- Verificar modo: Seduction es habilidad DEFENSIVA (CC)
                if not self:ShouldUseDefensive() then
                    self:DebugPrint("[Succubus] Modo actual no permite Seduction")
                    return false
                end
            -- Verificar si hay un segundo enemigo atacandonos
            local secondEnemy = self:FindSecondaryEnemy()
            if secondEnemy then
                self:SetCooldown("Seduction", 18)  -- Seduction dura 15s, CD real
                self:Print("|cffFF69B4Seduction!|r CC en enemigo secundario")
                return self:ExecuteAbility("Seduction")
            end
        end
    end
    
    -- PRIORIDAD 2: Soothing Kiss para reducir aggro/dano
    if not isAggressive and playerHP < 40 and inCombat then
        if not self:IsOnCooldown("Soothing Kiss") then
            self:SetCooldown("Soothing Kiss", 4)
            self:DebugPrint("Soothing Kiss - reduciendo amenaza")
            return self:ExecuteAbility("Soothing Kiss")
        end
    end
    
    -- PRIORIDAD 3: Lash of Pain para DPS
    if inCombat and UnitExists("pettarget") then
        if not self:IsOnCooldown("Lash of Pain") then
            -- Verificar modo: Lash of Pain es habilidad OFENSIVA
            if not self:ShouldUseOffensive() then
                self:DebugPrint("[Succubus] Modo actual no permite Lash of Pain")
                return false
            end
            local cd = 6
            if isAggressive then cd = 3 end
            self:SetCooldown("Lash of Pain", cd)
            return self:ExecuteAbility("Lash of Pain")
        end
    end
    
    -- PRIORIDAD 4: Lesser Invisibility si esta muy herida fuera de combate
    if petHP < 30 and not inCombat then
        if not self:IsOnCooldown("Lesser Invisibility") then
            self:SetCooldown("Lesser Invisibility", 300)
            self:DebugPrint("Lesser Invisibility - escapando")
            return self:ExecuteAbility("Lesser Invisibility")
        end
    end
    
    return false
end

-- Buscar un enemigo secundario para CC
function PetAI:FindSecondaryEnemy()
    -- En WoW 1.12/Turtle, no podemos iterar enemigos facilmente
    -- Pero podemos verificar si el target del target no es el pet
    if UnitExists("target") and UnitExists("targettarget") then
        -- Si el target del enemigo es el jugador (no el pet), hay peligro
        if UnitIsUnit("targettarget", "player") then
            return true
        end
    end
    
    -- Verificar si el jugador tiene aggro de algo que no es el pettarget
    if UnitExists("pettarget") and UnitExists("target") then
        if not UnitIsUnit("pettarget", "target") then
            -- Hay al menos 2 enemigos diferentes
            return true
        end
    end
    
    return false
end

function PetAI:EvaluateFelhunter()
    local playerHP = self:GetPlayerHealthPercent()
    local inCombat = UnitAffectingCombat("player") or UnitAffectingCombat("pet")
    
    -- PRIORIDAD 1: Spell Lock - Interrumpir casts enemigos
    if inCombat and UnitExists("pettarget") then
        if self:IsEnemyCasting("pettarget") then
            if not self:IsOnCooldown("Spell Lock") then
                -- Verificar modo: Spell Lock es habilidad OFENSIVA
                if not self:ShouldUseOffensive() then
                    self:DebugPrint("[Felhunter] Modo actual no permite Spell Lock")
                    return false
                end
                self:SetCooldown("Spell Lock", 24)
                self:Print("|cff00FFFFSpell Lock!|r Interrumpiendo cast enemigo")
                return self:ExecuteAbility("Spell Lock")
            end
        end
    end
    
        -- PRIORIDAD 2: Devour Magic Inteligente (Jugador o Aliado Protegido)
    local protectUnits = {"player"}
    if self.GuardianTarget then table.insert(protectUnits, self.GuardianTarget) end
    
    for _, unit in pairs(protectUnits) do
        local priority = self:GetDebuffPriority(unit)
        if priority > 0 then
            if not self:IsOnCooldown("Devour Magic") then
                if self:ShouldUseSupport() then
                    self:SetCooldown("Devour Magic", 8)
                    local name = UnitName(unit) or "Aliado"
                    if priority == 3 then self:Print("|cffff0000¡EMERGENCIA!|r Quitando CC de " .. name) end
                    return self:ExecutePetAbilityOnTarget("Devour Magic", unit, name)
                end
            end
        end
    end
    
    -- PRIORIDAD 4: Devour Magic ofensivo - quitar buffs del enemigo
    if inCombat and UnitExists("pettarget") then
        if self:EnemyHasMagicBuff("pettarget") then
            if not self:IsOnCooldown("Devour Magic") then
                -- Verificar modo: Devour Magic (ofensivo) es habilidad OFENSIVA
                if not self:ShouldUseOffensive() then
                    self:DebugPrint("[Felhunter] Modo actual no permite Devour Magic ofensivo")
                    return false
                end
                self:SetCooldown("Devour Magic", 8)
                self:DebugPrint("Devour Magic ofensivo - quitando buff enemigo")
                return self:ExecuteAbility("Devour Magic")
            end
        end
    end
    
    -- PRIORIDAD 5: Tainted Blood cuando el pet esta siendo atacado
    local petHP = self:GetPetHealthPercent()
    if petHP < 70 and inCombat then
        if not self:IsOnCooldown("Tainted Blood") then
            self:SetCooldown("Tainted Blood", 30)
            self:DebugPrint("Tainted Blood activado")
            return self:ExecuteAbility("Tainted Blood")
        end
    end
    
    return false
end

-- Verificar si el enemigo esta casteando
function PetAI:IsEnemyCasting(unit)
    if not UnitExists(unit) then return false end
    
    -- 1. Intentar usar API extendida (addons como ClassicCastBars la proveen)
    if UnitCastingInfo then
        local spellName = UnitCastingInfo(unit)
        if spellName then return true end
    end
    
    -- 2. Fallback: Verificación vía Combat Log (Propio de WCS_Brain)
    local name = UnitName(unit)
    if name and self.EnemyCastingTable and self.EnemyCastingTable[name] then
        local castData = self.EnemyCastingTable[name]
        if GetTime() < castData.endTime then
            return true
        end
        -- Limpiar entrada expirada
        self.EnemyCastingTable[name] = nil
    end
    
    return false
end

-- Verificar si tiene debuff magico (dispeleable)
function PetAI:GetDebuffPriority(unit)
    if not UnitExists(unit) then return 0 end
    
    local ccDebuffs = {"polymorph", "sheep", "fear", "horror", "charm", "sleep", "banish"}
    local ctlDebuffs = {"silence", "pacify", "root", "nova", "stun", "hammer"}
    local softDebuffs = {"slow", "frost", "curse", "hex", "immolate", "corruption"}

    for i = 1, 16 do
        local texture = UnitDebuff(unit, i)
        if not texture then break end
        local texLower = string.lower(texture)
        for _, p in pairs(ccDebuffs) do if string.find(texLower, p, 1, true) then return 3 end end
        for _, p in pairs(ctlDebuffs) do if string.find(texLower, p, 1, true) then return 2 end end
        for _, p in pairs(softDebuffs) do if string.find(texLower, p, 1, true) then return 1 end end
    end
    return 0
end

function PetAI:HasMagicDebuff(unit)
    return self:GetDebuffPriority(unit) > 0
end

-- Buscar miembro del grupo con debuff magico
function PetAI:FindGroupMemberWithMagicDebuff()
    local members = self:GetGroupMembers()
    local numMembers = WCS_TableCount(members)
    
    for i = 1, numMembers do
        local member = members[i]
        if member and UnitExists(member.unit) and not UnitIsDead(member.unit) then
            if member.unit ~= "player" then  -- Player ya lo checkeamos antes
                if self:HasMagicDebuff(member.unit) then
                    -- Verificar rango
                    if CheckInteractDistance(member.unit, 4) then
                        return member
                    end
                end
            end
        end
    end
    
    return nil
end

-- Verificar si enemigo tiene buff magico
function PetAI:EnemyHasMagicBuff(unit)
    if not UnitExists(unit) then return false end
    
    -- Buffs que vale la pena quitar
    local valuableBuffs = {
        "shield", "ward", "armor", "protection",
        "power", "might", "strength", "intellect",
        "regenerat", "heal", "renew"
    }
    
    for i = 1, 16 do
        local texture = UnitBuff(unit, i)
        if not texture then break end
        local texLower = string.lower(texture)
        
        for j = 1, WCS_TableCount(valuableBuffs) do
            if string.find(texLower, valuableBuffs[j], 1, true) then
                return true
            end
        end
    end
    
    return false
end

function PetAI:EvaluateFelguard()
    local playerHP = self:GetPlayerHealthPercent()
    local petHP = self:GetPetHealthPercent()
    local isAggressive = self.Config and self.Config.aggressiveMode
    local inCombat = UnitAffectingCombat("player") or UnitAffectingCombat("pet")
    
    -- PRIORIDAD 1: Intercept de emergencia - enemigo atacando al jugador
    if inCombat and playerHP < 70 then
        -- Verificar si el jugador esta siendo atacado directamente
        if self:IsPlayerBeingAttacked() then
            if not self:IsOnCooldown("Intercept") then
                -- Verificar modo: Intercept (defensivo) es habilidad DEFENSIVA
                if not self:ShouldUseDefensive() then
                    self:DebugPrint("[Felguard] Modo actual no permite Intercept defensivo")
                    return false
                end
                self:SetCooldown("Intercept", 30)
                self:Print("|cffFF4500Intercept!|r Protegiendo al jugador")
                return self:ExecuteAbility("Intercept")
            end
        end
    end
    
    -- PRIORIDAD 2: Anguish para tomar aggro cuando jugador en peligro
    if playerHP < 60 and inCombat then
        if not self:IsOnCooldown("Anguish") then
            -- Verificar modo: Anguish es habilidad DEFENSIVA
            if not self:ShouldUseDefensive() then
                self:DebugPrint("[Felguard] Modo actual no permite Anguish")
                return false
            end
            self:SetCooldown("Anguish", 5)
            self:Print("|cffFFFF00Anguish!|r Tomando aggro del jugador")
            return self:ExecuteAbility("Anguish")
        end
    end
    
    -- PRIORIDAD 3: Intercept ofensivo en modo agresivo
    if isAggressive and UnitExists("pettarget") then
        if not self:IsOnCooldown("Intercept") then
            -- Verificar modo: Intercept (ofensivo) es habilidad OFENSIVA
            if not self:ShouldUseOffensive() then
                self:DebugPrint("[Felguard] Modo actual no permite Intercept ofensivo")
                return false
            end
            self:SetCooldown("Intercept", 30)
            self:DebugPrint("Intercept ofensivo")
            return self:ExecuteAbility("Intercept")
        end
    end
    
    -- PRIORIDAD 4: Cleave - usar siempre en combate (es AOE)
    if inCombat and UnitExists("pettarget") then
        if not self:IsOnCooldown("Cleave") then
            -- Verificar modo: Cleave es habilidad OFENSIVA
            if not self:ShouldUseOffensive() then
                self:DebugPrint("[Felguard] Modo actual no permite Cleave")
                return false
            end
            local cd = 6
            if isAggressive then cd = 3 end
            -- Cleave es mas util cuando hay multiples enemigos
            -- pero lo usamos siempre porque hace buen dano
            self:SetCooldown("Cleave", cd)
            return self:ExecuteAbility("Cleave")
        end
    end
    
    -- PRIORIDAD 5: Demonic Frenzy - buff de dano (si existe en Turtle)
    if inCombat and petHP > 50 then
        if not self:IsOnCooldown("Demonic Frenzy") then
            self:SetCooldown("Demonic Frenzy", 60)
            self:DebugPrint("Demonic Frenzy activado")
            return self:ExecuteAbility("Demonic Frenzy")
        end
    end
    
    return false
end

-- Verificar si el jugador esta siendo atacado directamente
function PetAI:IsPlayerBeingAttacked()
    -- Metodo 1: Verificar si el target del enemigo es el jugador
    if UnitExists("target") and UnitCanAttack("target", "player") then
        if UnitExists("targettarget") then
            if UnitIsUnit("targettarget", "player") then
                return true
            end
        end
    end
    
    -- Metodo 2: Verificar si el pettarget tiene al jugador como target
    if UnitExists("pettarget") then
        if UnitExists("pettargettarget") then
            if UnitIsUnit("pettargettarget", "player") then
                return true
            end
        end
    end
    
    -- Metodo 3: Si el jugador esta en combate y perdiendo vida rapido
    -- (esto es una heuristica, no 100% precisa)
    if UnitAffectingCombat("player") then
        local playerHP = self:GetPlayerHealthPercent()
        if playerHP < 50 then
            return true  -- Asumir que esta siendo atacado si HP bajo
        end
    end
    
    return false
end

-- ============================================================================
-- EVALUACION DE DEMONIOS MAYORES
-- ============================================================================

function PetAI:EvaluateInfernal()
    -- Verificar modo: Infernal es puramente OFENSIVO
    if not self:ShouldUseOffensive() then
        self:DebugPrint("[Infernal] Modo actual no permite habilidades ofensivas")
        return false
    end
    local timeRemaining = self:GetMajorDemonTimeRemaining()
    if timeRemaining and timeRemaining < 10 then
        self:DebugPrint("Infernal: " .. string.format("%.0f", timeRemaining) .. "s restantes!")
    end
    if not self:HasImmolationAura() then
        if not self:IsOnCooldown("Immolation") then
            self:SetCooldown("Immolation", 2)
            self:Print("|cffff6600Infernal:|r Activando Immolation Aura")
            return self:ExecuteAbility("Immolation")
        end
    end
    return false
end

function PetAI:EvaluateDoomguard()
    local playerHP = self:GetPlayerHealthPercent()
    local timeRemaining = self:GetMajorDemonTimeRemaining()
    
    if timeRemaining and timeRemaining < 10 then
        self:DebugPrint("Doomguard: " .. string.format("%.0f", timeRemaining) .. "s restantes!")
    end
    
    if playerHP < 30 then
        if not self:IsOnCooldown("War Stomp") then
            -- Verificar modo: War Stomp es habilidad DEFENSIVA (CC emergencia)
            if not self:ShouldUseDefensive() then
                self:DebugPrint("[Doomguard] Modo actual no permite War Stomp")
                return false
            end
            self:SetCooldown("War Stomp", 30)
            self:Print("|cffff0000EMERGENCIA:|r War Stomp!")
            return self:ExecuteAbility("War Stomp")
        end
    end
    
    if UnitAffectingCombat("pet") then
        if not self:IsOnCooldown("Rain of Fire") then
            -- Verificar modo: Rain of Fire es habilidad OFENSIVA
            if not self:ShouldUseOffensive() then
                self:DebugPrint("[Doomguard] Modo actual no permite Rain of Fire")
                return false
            end
            self:SetCooldown("Rain of Fire", 15)
            return self:ExecuteAbility("Rain of Fire")
        end
    end
    
    if UnitExists("pettarget") then
        if not self:IsOnCooldown("Cripple") then
            -- Verificar modo: Cripple es habilidad OFENSIVA (debuff)
            if not self:ShouldUseOffensive() then
                self:DebugPrint("[Doomguard] Modo actual no permite Cripple")
                return false
            end
            self:SetCooldown("Cripple", 10)
            return self:ExecuteAbility("Cripple")
        end
    end
    return false
end


-- ============================================================================
-- DECISION LOOP AUTÓNOMO CENTRALIZADO
-- Refactorizado para máxima claridad, modularidad y futura expansión por eventos
-- ============================================================================
-- ============================================================================
-- FUNCIONES DEL MODO GUARDIÁN
-- ============================================================================

-- Función principal de evaluación del modo Guardián
function PetAI:EvaluateGuardianMode()
    if not self.GuardianTarget then return false end
    
    -- Buscar el unit ID del objetivo protegido
    local guardianUnit = self:FindGuardianUnit()
    if not guardianUnit then
        self:Print("|cffff0000Advertencia:|r " .. self.GuardianTarget .. " no está en party/raid")
        return false
    end
    
    -- Verificar si el protegido existe y está vivo
    if not UnitExists(guardianUnit) or UnitIsDead(guardianUnit) then
        return false
    end
    
    local guardianHP = self:GetUnitHealthPercent(guardianUnit)
    local petType = self:GetPetType()
    
    -- PRIORIDAD 1: Sacrificio de emergencia (Voidwalker)
    if petType == "Voidwalker" and guardianHP < 20 then
        if self:GuardianSacrifice(guardianUnit) then
            return true
        end
    end
    
    -- PRIORIDAD 2: Fire Shield automático (Imp)
    if petType == "Imp" then
        if self:GuardianFireShield(guardianUnit) then
            return true
        end
    end
    
    -- PRIORIDAD 3: Defender al protegido (atacar lo que lo ataca)
    if self:GuardianDefend(guardianUnit) then
        return true
    end
    
    -- PRIORIDAD 4: Asistir al protegido (atacar lo que ataca)
    if self:GuardianAssist(guardianUnit) then
        return true
    end
    
    return false
end

-- Encontrar el unit ID del objetivo protegido
function PetAI:FindGuardianUnit()
    if not self.GuardianTarget then return nil end
    
    -- Buscar en party
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitName(unit) == self.GuardianTarget then
            return unit
        end
    end
    
    -- Buscar en raid
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitName(unit) == self.GuardianTarget then
            return unit
        end
    end
    
    return nil
end

-- Asistir al protegido: atacar lo que él ataca
function PetAI:GuardianAssist(guardianUnit)
    if not guardianUnit then return false end
    
    -- Verificar si el protegido tiene un target
    local guardianTarget = guardianUnit .. "target"
    
    if UnitExists(guardianTarget) and UnitCanAttack("player", guardianTarget) then
        -- Si la pet no está atacando el mismo objetivo
        if not UnitExists("pettarget") or not UnitIsUnit("pettarget", guardianTarget) then
            -- Asistir al protegido
            TargetUnit(guardianTarget)
            PetAttack()
            self:Print("|cFFFFD700[GUARDIÁN]|r Asistiendo a " .. self.GuardianTarget)
            self:DebugPrint("[Guardián] Asistiendo a " .. self.GuardianTarget)
            return true
        end
    end
    
    return false
end

-- Defender al protegido: atacar lo que lo está atacando
function PetAI:GuardianDefend(guardianUnit)
    if not guardianUnit then return false end
    
    -- Verificar si el protegido está en combate
    if not UnitAffectingCombat(guardianUnit) then
        return false
    end
    
    -- Buscar enemigos que estén atacando al protegido
    -- En WoW 1.12 no hay API directa para esto, así que usamos heurística:
    -- Si el protegido está en combate y tiene bajo HP, atacar su target
    local guardianHP = self:GetUnitHealthPercent(guardianUnit)
    
    if guardianHP < 50 then
        local guardianTarget = guardianUnit .. "target"
        if UnitExists(guardianTarget) and UnitCanAttack("player", guardianTarget) then
            if not UnitExists("pettarget") or not UnitIsUnit("pettarget", guardianTarget) then
                TargetUnit(guardianTarget)
                PetAttack()
                self:Print("|cFFFF0000[GUARDIÁN]|r Defendiendo a " .. self.GuardianTarget .. " (HP: " .. string.format("%.0f", guardianHP) .. "%)")
                self:DebugPrint("[Guardián] Defendiendo a " .. self.GuardianTarget .. " (HP: " .. string.format("%.0f", guardianHP) .. "%)")
                return true
            end
        end
    end
    
    return false
end

-- Sacrificio de emergencia (Voidwalker)
function PetAI:GuardianSacrifice(guardianUnit)
    if not guardianUnit then return false end
    
    local petType = self:GetPetType()
    if petType ~= "Voidwalker" then return false end
    
    local guardianHP = self:GetUnitHealthPercent(guardianUnit)
    
    -- Solo sacrificarse si el protegido está en peligro crítico
    if guardianHP < 20 and UnitAffectingCombat(guardianUnit) then
        -- Verificar que Sacrifice esté disponible
        if not self:IsOnCooldown("Sacrifice") then
            -- Targetear al protegido y usar Sacrifice
            TargetUnit(guardianUnit)
            if self:ExecuteAbility("Sacrifice") then
                self:Print("|cFFFF0000[GUARDIÁN]|r ¡Sacrificándose por " .. self.GuardianTarget .. "!")
                self:SetCooldown("Sacrifice", 300)
                return true
            end
        end
    end
    
    return false
end

-- Fire Shield automático (Imp)
function PetAI:GuardianFireShield(guardianUnit)
    if not guardianUnit then return false end
    
    local petType = self:GetPetType()
    if petType ~= "Imp" then return false end
    
    -- Verificar si el protegido ya tiene Fire Shield
    if self:HasFireShield(guardianUnit) then
        return false
    end
    
    -- Verificar cooldown de Fire Shield
    local now = GetTime()
    if self.FireShieldCache.appliedTo[self.GuardianTarget] then
        local lastApplied = self.FireShieldCache.appliedTo[self.GuardianTarget]
        if (now - lastApplied) < self.Config.fireShieldCooldown then
            return false
        end
    end
    
    -- Verificar si está en combate o tiene bajo HP
    local guardianHP = self:GetUnitHealthPercent(guardianUnit)
    if UnitAffectingCombat(guardianUnit) or guardianHP < 70 then
        -- Aplicar Fire Shield
        TargetUnit(guardianUnit)
        if self:ExecuteAbility("Fire Shield") then
            self:Print("|cFFFFD700[GUARDIÁN]|r Fire Shield aplicado a " .. self.GuardianTarget)
            self.FireShieldCache.appliedTo[self.GuardianTarget] = now
            return true
        end
    end
    
    return false
end

-- Helper: Obtener HP% de cualquier unidad
function PetAI:GetUnitHealthPercent(unit)
    if not UnitExists(unit) then return 0 end
    local current = UnitHealth(unit) or 0
    local max = UnitHealthMax(unit) or 1
    if max == 0 then max = 1 end
    return (current / max) * 100
end

function PetAI:Evaluate()
    -- Guard: Prevenir race conditions
    if self.isThinking then return end
    self.isThinking = true
    
    -- 1. Verificaciones básicas
    if not self.ENABLED then
        self.isThinking = false
        return
    end
    if not UnitExists("pet") then
        self.isThinking = false
        return
    end
    if UnitIsDead("pet") then
        self.isThinking = false
        return
    end

    -- 2. Actualizar y verificar estado de Enslave Demon
    self:CheckEnslaveStatus()

    -- 3. Hook: Pre-evaluación (para eventos o módulos externos)
    if self.OnPreEvaluate then
        local handled = self:OnPreEvaluate()
        if handled then
            self.isThinking = false
            return
        end
    end


    -- ============================================================================
    -- MODO GUARDIÁN: Proteger a un compañero específico
    -- ============================================================================
    if self.currentMode == 4 and self.GuardianTarget then
        local now = GetTime()
        
        -- Revisar cada 0.5 segundos para no sobrecargar
        if (now - self.GuardianLastCheck) >= self.GuardianCheckInterval then
            self.GuardianLastCheck = now
            
            if self:EvaluateGuardianMode() then
                self.isThinking = false
                return  -- Si el modo Guardián manejó la situación, salir
            end
        end
    end

    -- 4. Detectar tipo de mascota y contexto
    local petType = self:GetPetType()
    if not petType then
        self.isThinking = false
        return
    end

    -- 5. Hook: Permitir override de decisión por módulos externos
    if self.OnOverrideDecision then
        local handled = self:OnOverrideDecision(petType)
        if handled then
            self.isThinking = false
            return
        end
    end

    -- 6. Evaluar demonios esclavizados (Enslave)
    if self:IsEnslavedDemon() then
        if self:EvaluateEnslaved() then
            self.isThinking = false
            return
        end
    end


    -- 7. Integración con otros addons: priorizar defensas si hay amenaza alta o alerta de boss
    local threatHigh = false
    local bossAlert = false
    if WCS_BrainIntegrations and WCS_BrainIntegrations.ThreatMeters and WCS_BrainIntegrations.ThreatMeters.IsThreatHigh then
        threatHigh = WCS_BrainIntegrations.ThreatMeters:IsThreatHigh(80)
    end
    if WCS_BrainIntegrations and WCS_BrainIntegrations.BossMods and WCS_BrainIntegrations.BossMods.HasActiveBossAlert then
        bossAlert = WCS_BrainIntegrations.BossMods:HasActiveBossAlert()
    end

    self:DebugPrint("[DecisionLoop] Evaluando tipo: " .. tostring(petType) .. (threatHigh and " | THREAT ALTO" or "") .. (bossAlert and " | BOSS ALERTA" or ""))
    local evaluated = false
    -- Lógica personalizada para futuras mascotas
    if self.CustomPetLogic[petType] then
        evaluated = self.CustomPetLogic[petType](self)
    elseif petType == "Imp" then
        if threatHigh or bossAlert then
            -- Priorizar Fire Shield defensivo
            self.Config.autoFireShield = true
        end
        evaluated = self:EvaluateImp()
    elseif petType == "Voidwalker" then
        if threatHigh or bossAlert then
            -- Priorizar Sacrifice defensivo
            self.Config.smartSacrifice = true
        end
        evaluated = self:EvaluateVoidwalker()
    elseif petType == "Succubus" then
        evaluated = self:EvaluateSuccubus()
    elseif petType == "Felhunter" then
        evaluated = self:EvaluateFelhunter()
    elseif petType == "Felguard" then
        evaluated = self:EvaluateFelguard()
    elseif petType == "Infernal" then
        evaluated = self:EvaluateInfernal()
    elseif petType == "Doomguard" then
        evaluated = self:EvaluateDoomguard()
    end

    -- 8. Hook: Post-evaluación (para logging, aprendizaje, etc)
    if self.OnPostEvaluate then
        self:OnPostEvaluate(petType, evaluated)
    end
    
    -- Liberar guard
    self.isThinking = false
end

PetAI.frame = CreateFrame("Frame", "WCS_BrainPetAIFrame")
PetAI.frame:RegisterEvent("PLAYER_LOGIN")
PetAI.frame:RegisterEvent("UNIT_PET")

local function PetAI_OnEvent()
    if event == "PLAYER_LOGIN" then
        PetAI:Print("v" .. PetAI.VERSION .. " cargado. Auto-Reenslave: ON")
    elseif event == "UNIT_PET" and arg1 == "player" then
        PetAI:OnPetChanged()
    -- RASTREO DE CASTEO PARA 1.12
    elseif event == "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE" or 
           event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE" then
        -- Formato: "Enemy begins to cast Spell."
        local _, _, enemy, spell = string.find(arg1, "(.+) comienza a lanzar (.+)%.")
        if not enemy then
            _, _, enemy, spell = string.find(arg1, "(.+) begins to cast (.+)%.")
        end
        
        if enemy and spell then
            PetAI.EnemyCastingTable[enemy] = {
                spell = spell,
                endTime = GetTime() + 2.5 -- Asumimos 2.5s si no hay más info
            }
        end
    end
end
PetAI.frame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
PetAI.frame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
PetAI.frame:SetScript("OnEvent", PetAI_OnEvent)

PetAI.frame:SetScript("OnUpdate", function()
    if not PetAI.ENABLED then return end
    local now = GetTime()
    if (now - PetAI.lastUpdate) < PetAI.updateInterval then return end
    PetAI.lastUpdate = now
    PetAI:Evaluate()
end)

SLASH_PETAI1 = "/petai"
SlashCmdList["PETAI"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "status" or cmd == "info" then
        PetAI:Print("=== Estado de PetAI v" .. PetAI.VERSION .. " ===")
        PetAI:Print("  Activado: " .. (PetAI.ENABLED and "|cff00ff00SI|r" or "|cffff0000NO|r"))
        PetAI:Print("  Debug: " .. (PetAI.debug and "ON" or "OFF"))
        if UnitExists("pet") then
            local petName = UnitName("pet") or "?"
            local petType = PetAI:GetPetType() or "?"
            local petFamily = UnitCreatureFamily("pet") or "nil"
            local petHP = PetAI:GetPetHealthPercent()
            local petMana = PetAI:GetPetManaPercent()
            PetAI:Print("  Pet: " .. petName)
            PetAI:Print("  Tipo detectado: |cff00ff00" .. petType .. "|r")
            PetAI:Print("  Family API: " .. petFamily)
            PetAI:Print("  HP: " .. string.format("%.0f", petHP) .. "% | Mana: " .. string.format("%.0f", petMana) .. "%")
            local isEnslaved = PetAI:IsEnslavedDemon()
            PetAI:Print("  Esclavizado: " .. (isEnslaved and "SI" or "NO"))
        else
            PetAI:Print("  Pet: |cffff0000No hay mascota activa|r")
        end
    elseif cmd == "scan" then
        local abs = PetAI:ScanPetAbilities()
        PetAI:Print("Habilidades del pet:")
        local numAbs = WCS_TableCount(abs)
        for i = 1, numAbs do
            local ab = abs[i]
            if ab then
                local cat = ab.category or "unknown"
                local nm = ab.name or "?"
                local sl = ab.slot or 0
                PetAI:Print("  [" .. tostring(sl) .. "] " .. tostring(nm) .. " (" .. tostring(cat) .. ")")
            end
        end
    elseif cmd == "petbuffs" then
        PetAI:ListPetBuffs()
    elseif cmd == "enslaved" then
        local isEnsl = PetAI:IsEnslavedDemon()
        PetAI:Print("Es esclavizado: " .. (isEnsl and "SI" or "NO"))
    elseif cmd == "reenslave" then
        PetAI.Enslave.enabled = not PetAI.Enslave.enabled
        PetAI:Print("Auto-Reenslave: " .. (PetAI.Enslave.enabled and "ON" or "OFF"))
    elseif cmd == "on" then
        PetAI.ENABLED = true
        PetAI:Print("PetAI ACTIVADA")
    elseif cmd == "off" then
        PetAI.ENABLED = false
        PetAI:Print("PetAI DESACTIVADA")
    elseif cmd == "debug" then
        PetAI.debug = not PetAI.debug
        PetAI:Print("Debug: " .. (PetAI.debug and "ON" or "OFF"))
    elseif cmd == "test" then
        PetAI:Print("Forzando evaluacion...")
        PetAI.debug = true
        PetAI:Evaluate()
        PetAI.debug = false
    else
        PetAI:Print("=== Comandos PetAI v" .. PetAI.VERSION .. " ===")
        PetAI:Print("  /petai status - Ver estado y tipo de mascota")
        PetAI:Print("  /petai on/off - Activar/desactivar")
        PetAI:Print("  /petai scan - Escanear habilidades del pet")
        PetAI:Print("  /petai test - Forzar evaluacion (debug)")
        PetAI:Print("  /petai debug - Toggle modo debug")
        PetAI:Print("  /petai petbuffs - Ver buffs del pet")
        PetAI:Print("  /petai enslaved - Ver si es esclavizado")
        PetAI:Print("  /petai reenslave - Toggle auto-reenslave")
    end
end

-- ============================================================================
-- FUNCIONES DE INTEGRACION CON UI
-- ============================================================================

WCS_Brain = WCS_Brain or {}
WCS_Brain.Pet = WCS_Brain.Pet or {}
WCS_Brain.Pet.AI = PetAI

function WCS_Brain.Pet.AI:IsEnabled()
    return self.ENABLED
end
function WCS_BrainPetAI_IsEnabled()
    return WCS_Brain.Pet.AI:IsEnabled()
end

function WCS_Brain.Pet.AI:SetEnabled(value)
    if value == 1 then value = true end
    if value == nil or value == 0 then value = false end
    self.ENABLED = value
    self:Print("PetAI " .. (value and "ACTIVADA" or "DESACTIVADA"))
end
function WCS_BrainPetAI_SetEnabled(value)
    return WCS_Brain.Pet.AI:SetEnabled(value)
end

function WCS_Brain.Pet.AI:Toggle()
    self.ENABLED = not self.ENABLED
    self:Print("PetAI " .. (self.ENABLED and "ACTIVADA" or "DESACTIVADA"))
    return self.ENABLED
end
function WCS_BrainPetAI_Toggle()
    return WCS_Brain.Pet.AI:Toggle()
end

function WCS_Brain.Pet.AI:GetPetTypePublic()
    return self:GetPetType()
end
function WCS_BrainPetAI_GetPetType()
    return WCS_Brain.Pet.AI:GetPetTypePublic()
end

-- Hook para coordinacion con CombatController
function PetAI:OnPlayerAction(playerDecision)
    if not playerDecision then return end
    if playerDecision.spell == "Fear" then
        self.lastPlayerFear = GetTime()
    elseif playerDecision.spell == "Death Coil" then
        self.playerInDanger = true
    elseif playerDecision.spell == "Health Funnel" then
        self.receivingHealing = true
    end
end

-- ============================================================================
-- COMANDO /PETGUARD - MODO GUARDIÁN
-- ============================================================================

SLASH_PETGUARD1 = "/petguard"
SlashCmdList["PETGUARD"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "" or cmd == "help" then
        PetAI:Print("=== Comandos /petguard ===")
        PetAI:Print("  /petguard [nombre] - Asignar jugador a proteger")
        PetAI:Print("  /petguard clear - Limpiar objetivo protegido")
        PetAI:Print("  /petguard show - Ver quién está protegiendo")
        PetAI:Print("  /petguard help - Mostrar esta ayuda")
        return
    end
    
    if cmd == "clear" then
        if PetAI.GuardianTarget then
            PetAI:Print("Ya no protegiendo a: " .. PetAI.GuardianTarget)
            PetAI.GuardianTarget = nil
        else
            PetAI:Print("No hay objetivo protegido actualmente")
        end
        return
    end
    
    if cmd == "show" then
        if PetAI.GuardianTarget then
            PetAI:Print("Protegiendo a: |cff00ff00" .. PetAI.GuardianTarget .. "|r")
            if PetAI.currentMode == 4 then
                PetAI:Print("Modo: |cFFFFD700Guardián|r (Activo)")
            else
                PetAI:Print("Modo: " .. PetAI:GetModeName() .. " (Usa /run WCS_BrainPetAI:SetMode(4) para activar Guardián)")
            end
        else
            PetAI:Print("No hay objetivo protegido. Usa /petguard [nombre]")
        end
        return
    end
    
    -- Si no es un comando especial, es un nombre de jugador
    local targetName = msg
    
    -- Verificar que el jugador existe en party/raid
    local found = false
    local unitID = nil
    
    -- Buscar en party
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitName(unit) == targetName then
            found = true
            unitID = unit
            break
        end
    end
    
    -- Buscar en raid si no está en party
    if not found then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitName(unit) == targetName then
                found = true
                unitID = unit
                break
            end
        end
    end
    
    if found then
        PetAI.GuardianTarget = targetName
        PetAI:Print("Ahora protegiendo a: |cff00ff00" .. targetName .. "|r")
        
        -- Si no está en modo Guardián, sugerir activarlo
        if PetAI.currentMode ~= 4 then
            PetAI:SetMode(4)
            PetAI:Print("|cFFFFD700Modo Guardián activado automáticamente|r")
        end
    else
        PetAI:Print("|cffff0000Error:|r '" .. targetName .. "' no encontrado en party/raid")
        PetAI:Print("Asegúrate de escribir el nombre exacto del jugador")
    end
end

PetAI:Print("v" .. PetAI.VERSION .. " - Sistema de IA con Auto-Reenslave y Coordinacion")


-- ============================================
-- NUEVAS FUNCIONES v8.0.0
-- ============================================

-- Encuentra el slot de una habilidad de mascota por nombre
function WCS_BrainPetAI:GetPetAbilitySlot(abilityName)
    if not abilityName then return nil end
    
    for i = 1, 10 do
        local name, rank = GetPetActionInfo(i)
        if name and name == abilityName then
            return i
        end
    end
    return nil
end

-- Verifica si la mascota tiene una habilidad especÃ­fica
function WCS_BrainPetAI:PetHasAbility(abilityName)
    return self:GetPetAbilitySlot(abilityName) ~= nil
end

-- Verifica si se puede usar una habilidad (existe, no estÃ¡ en CD, hay mana)
function WCS_BrainPetAI:CanCastPetAbility(abilityName)
    local slot = self:GetPetAbilitySlot(abilityName)
    if not slot then
        if self.DEBUG then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CanCast]|r " .. abilityName .. " - NO ENCONTRADA")
        end
        return false
    end
    
    local name, rank, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(slot)
    local start, duration, enable = GetPetActionCooldown(slot)
    
    -- Verificar cooldown
    if start and start > 0 and duration and duration > 0 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            if self.DEBUG then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFAA00[CanCast]|r %s - EN CD (%.1fs)", abilityName, remaining))
            end
            return false
        end
    end
    
    -- Verificar mana de la mascota
    local petMana = UnitMana("pet")
    local petMaxMana = UnitManaMax("pet")
    if petMana and petMaxMana and petMana < (petMaxMana * 0.1) then
        if self.DEBUG then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[CanCast]|r " .. abilityName .. " - SIN MANA")
        end
        return false
    end
    
    if self.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[CanCast]|r " .. abilityName .. " - OK")
    end
    return true
end