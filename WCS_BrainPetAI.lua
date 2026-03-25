
-- ============================================================================
-- SOPORTE EXTENSIBLE PARA NUEVAS MASCOTAS Y HABILIDADES
-- ============================================================================
-- (Moved below PetAI initialization)

--[[
    WCS_BrainPetAI.lua v6.7.1
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
-- Permite registrar lÃƒÂ³gica personalizada para futuras mascotas o demonios especiales
PetAI.CustomPetLogic = {}

-- Registrar una nueva mascota personalizada
function PetAI:RegisterCustomPet(petType, logicFunc)
    if not petType or type(logicFunc) ~= "function" then return end
    self.CustomPetLogic[petType] = logicFunc
end

-- Ejemplo de plantilla para una nueva mascota (puedes copiar y adaptar)
--[[
PetAI:RegisterCustomPet("Fel Imp", function(self)
    -- LÃƒÂ³gica especÃƒÂ­fica para Fel Imp
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
-- Permite registrar y disparar callbacks para eventos clave (daÃƒÂ±o, muerte, cambio de estado, etc)
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

-- Ejemplo de integraciÃƒÂ³n: disparar eventos en situaciones clave
-- (Puedes expandir esto en los mÃƒÂ©todos de combate, muerte, cambio de estado, etc)

PetAI.VERSION = "6.7.1"  -- Mascotas inteligentes mejoradas + Sistema de ejecuciÃƒÂ³n corregido
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
PetAI.currentMode = 1  -- 1=Agresivo, 2=Defensivo, 3=Soporte, 4=GuardiÃƒÂ¡n

-- Variables para modo GuardiÃƒÂ¡n
PetAI.GuardianTarget = nil  -- Nombre del jugador a proteger
PetAI.GuardianLastCheck = 0
PetAI.GuardianCheckInterval = 0.5  -- Revisar cada 0.5 segundos

-- ConfiguraciÃƒÂ³n de comportamiento por modo
PetAI.ModeConfig = {
    [1] = {  -- Agresivo
        name = "Agresivo",
        attackPriority = "high",      -- Prioridad de ataque
        defensePriority = "low",      -- Prioridad de defensa
        supportPriority = "low",      -- Prioridad de soporte
        autoAttack = true,            -- Atacar automÃƒÂ¡ticamente
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
    [4] = {  -- GuardiÃƒÂ¡n
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

-- FunciÃƒÂ³n para cambiar el modo de IA
function PetAI:SetMode(mode)
    -- Convertir a numero si es string
    if type(mode) == "string" then
        mode = tonumber(mode)
    end
    
    if not mode or mode < 1 or mode > 4 then
        self:Print("Modo invÃƒÂ¡lido. Usa 1 (Agresivo), 2 (Defensivo), 3 (Soporte) o 4 (GuardiÃƒÂ¡n)")
        return false
    end
    -- Si cambia a modo GuardiÃƒÂ¡n sin target asignado, avisar
    if mode == 4 and not self.GuardianTarget then
        self:Print("Modo GuardiÃƒÂ¡n activado. Usa /petguard [nombre] para asignar a quiÃƒÂ©n proteger")
    end
    
    self.currentMode = mode
    local config = self.ModeConfig[mode]
    
    if not config then
        self:Print("ERROR: ConfiguraciÃƒÂ³n de modo no encontrada")
        return false
    end
    
    -- Actualizar configuraciÃƒÂ³n legacy
    self.Config.aggressiveMode = config.aggressiveMode
    
    -- Mensaje de confirmaciÃƒÂ³n
    local modeNames = {
        [1] = "|cFFFF0000Agresivo|r",
        [2] = "|cFF00FF00Defensivo|r",
        [3] = "|cFF00CCFFSoporte|r",
        [4] = "|cFFFFD700GuardiÃƒÂ¡n|r"
    }
    
    self:Print("Modo de IA cambiado a: " .. modeNames[mode])
    
    -- Disparar evento para otros mÃƒÂ³dulos
    if self.TriggerEvent then
        self:TriggerEvent("MODE_CHANGED", mode, config.name)
    end
    
    return true
end

-- FunciÃƒÂ³n para obtener el modo actual
function PetAI:GetMode()
    return self.currentMode or 1
end

-- FunciÃƒÂ³n para obtener el nombre del modo actual
function PetAI:GetModeName()
    local config = self.ModeConfig[self.currentMode]
    return config and config.name or "Desconocido"
end

-- FunciÃƒÂ³n helper para verificar si debe usar habilidades ofensivas
function PetAI:ShouldUseOffensive()
    local config = self.ModeConfig[self.currentMode]
    return config and config.useOffensive or false
end

-- FunciÃƒÂ³n helper para verificar si debe usar habilidades defensivas
function PetAI:ShouldUseDefensive()
    local config = self.ModeConfig[self.currentMode]
    return config and config.useDefensive or false
end

-- FunciÃƒÂ³n helper para verificar si debe usar habilidades de soporte
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
    
    -- Metodo 1: UnitCreatureFamily (El mas confiable para WoW Vanilla/Turtle)
    local family = UnitCreatureFamily("pet")
    if family then
        local famLower = string.lower(family)
        if string.find(famLower, "imp") or string.find(famLower, "diablillo") then return "Imp" end
        if string.find(famLower, "void") or string.find(famLower, "abisario") then return "Voidwalker" end
        if string.find(famLower, "succub") or string.find(famLower, "súcubo") or string.find(famLower, "sucubo") then return "Succubus" end
        if string.find(famLower, "felhunter") or string.find(famLower, "sabueso") then return "Felhunter" end
        if string.find(famLower, "felguard") or string.find(famLower, "guardia vil") then return "Felguard" end
        if string.find(famLower, "infernal") then return "Infernal" end
        if string.find(famLower, "doomguard") or string.find(famLower, "apocalíptic") or string.find(famLower, "apocaliptic") then return "Doomguard" end
    end
    
    -- Metodo 2: Analisis de libro de hechizos (Fallback hiper robusto y bilingüe)
    for i = 1, 10 do
        local name = GetPetActionInfo(i)
        if name then
            local nameLower = string.lower(name)
            if string.find(nameLower, "fire") or string.find(nameLower, "fuego") or string.find(nameLower, "pacto") then return "Imp" end
            if string.find(nameLower, "torment") or string.find(nameLower, "sacrifi") or string.find(nameLower, "suffer") or string.find(nameLower, "sufrimi") then return "Voidwalker" end
            if string.find(nameLower, "seduc") or string.find(nameLower, "lash") or string.find(nameLower, "latigazo") or string.find(nameLower, "soothing") or string.find(nameLower, "beso") then return "Succubus" end
            if string.find(nameLower, "devour") or string.find(nameLower, "devorar") or string.find(nameLower, "spell lock") or string.find(nameLower, "bloqueo") or string.find(nameLower, "taint") or string.find(nameLower, "corrupta") then return "Felhunter" end
            if string.find(nameLower, "intercept") or string.find(nameLower, "anguish") or string.find(nameLower, "angustia") or string.find(nameLower, "brutal") then return "Felguard" end
        end
    end
    
    -- Metodo 3: Fallback estricto por nombre (ej. test env)
    local petName = UnitName("pet")
    if petName then
        local pName = string.lower(petName)
        if string.find(pName, "imp") then return "Imp" end
        if string.find(pName, "void") then return "Voidwalker" end
        if string.find(pName, "succ") then return "Succubus" end
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
-- NUEVAS FUNCIONES v6.7.1 - Sistema mejorado de ejecuciÃƒÂ³n
-- ============================================================================

-- Tabla de traduccion EN <-> ES para habilidades de mascota
-- Permite que la IA funcione con cliente en Ingles Y Espanol
PetAI.SpellAliases = {
    ["fire shield"]         = "escudo de fuego",
    ["firebolt"]            = "bola de fuego",
    ["phase shift"]         = "cambio de fase",
    ["sacrifice"]           = "sacrificio",
    ["torment"]             = "tormento",
    ["suffering"]           = "sufrimiento",
    ["consume shadows"]     = "consumir sombras",
    ["seduction"]           = "seduccion",
    ["lash of pain"]        = "latigazo de dolor",
    ["soothing kiss"]       = "beso calmante",
    ["lesser invisibility"] = "invisibilidad menor",
    ["spell lock"]          = "bloqueo de hechizo",
    ["devour magic"]        = "devorar magia",
    ["tainted blood"]       = "sangre corrupta",
    ["intercept"]           = "interceptar",
    ["anguish"]             = "angustia",
    ["cleave"]              = "golpe brutal",
    ["war stomp"]           = "pisoton de guerra",
    ["cripple"]             = "lisiar",
    ["rain of fire"]        = "lluvia de fuego",
    ["immolation"]          = "inmolacion",
}

PetAI.AbilityTextures = {
    ["fire shield"]         = "Spell_Fire_FireArmor",
    ["firebolt"]            = "Spell_Fire_FireBolt",
    ["phase shift"]         = "Spell_Shadow_AuraOfDarkness",
    ["sacrifice"]           = "Spell_Shadow_SacrificialShield",
    ["torment"]             = "Spell_Shadow_GatherShadows",
    ["suffering"]           = "Spell_Shadow_BlackPlague",
    ["consume shadows"]     = "Spell_Shadow_AntiShadow",
    ["seduction"]           = "Spell_Shadow_MindSteal",
    ["lash of pain"]        = "Spell_Shadow_Curse",
    ["soothing kiss"]       = "Spell_Shadow_SoothingKiss",
    ["lesser invisibility"] = "Spell_Magic_LesserInvisibilty",
    ["spell lock"]          = "Spell_Shadow_MindRot",
    ["devour magic"]        = "Spell_Nature_Purge",
    ["tainted blood"]       = "Spell_Shadow_LifeDrain",
    ["intercept"]           = "Ability_Rogue_Sprint",
    ["anguish"]             = "Spell_Shadow_GatherShadows",
    ["cleave"]              = "Ability_Warrior_Cleave",
    ["war stomp"]           = "Ability_WarStomp",
    ["cripple"]             = "Spell_Shadow_Cripple",
    ["rain of fire"]        = "Spell_Shadow_RainOfFire",
    ["immolation"]          = "Spell_Shadow_Immolation"
}

-- Obtener slot de habilidad por nombre (bilingue EN/ES + Soporte Texturas Custom Servers)
function PetAI:GetPetAbilitySlot(spellName)
    if not UnitExists("pet") or not spellName then return nil end
    local s = string.lower(spellName)
    
    -- 1. Preparar alias de idioma
    local alias = self.SpellAliases[s] or ""
    if alias == "" then
        for en, es in pairs(self.SpellAliases) do
            if es == s then alias = en break end
        end
    end
    
    -- 2. Preparar textura (fallback maestro)
    local targetTexture = self.AbilityTextures[s]
    if not targetTexture and alias ~= "" then
        targetTexture = self.AbilityTextures[alias]
    end
    if targetTexture then targetTexture = string.lower(targetTexture) end
    
    -- 3. Escaneo del libro de macotas
    for i = 1, 10 do
        local name, _, texture = GetPetActionInfo(i)
        if name then
            local n = string.lower(name)
            
            -- Match parcial de nombre (soporta sufijos como "(Rango 4)")
            if string.find(n, s) or (alias ~= "" and string.find(n, alias)) then
                return i
            end
            
            -- Match por textura (inmune a cualquier idioma o alteración de server custom)
            if targetTexture and texture and string.find(string.lower(texture), targetTexture) then
                return i
            end
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
    if CastSpellByName then
        CastSpellByName(spellName)
        success = true
        self:DebugPrint("[Execute] " .. spellName .. " - CastSpellByName")
    else
        local slot = self:GetPetAbilitySlot(spellName)
        if slot then
            CastPetAction(slot)
            success = true
            self:DebugPrint("[Execute] " .. spellName .. " - CastPetAction(" .. slot .. ")")
        else
            local cmd = "/cast " .. tostring(spellName)
            if ChatFrameEditBox then
                ChatFrameEditBox:SetText(cmd)
                ChatEdit_SendText(ChatFrameEditBox)
                success = true
                self:DebugPrint("[Execute] " .. spellName .. " - ChatFrame (obsoleto)")
            end
        end
    end
    if success then
        self:SetCooldown(spellName, 1.5)
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
    
    local slot = self:GetPetAbilitySlot(spellName)
    if slot then
        CastPetAction(slot)
    end
    
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
    
    -- PRIORIDAD 2: Sacrificio inteligente - Voidwalker a punto de morir
    -- Mejor convertirse en escudo util que morir sin dar nada
    if cfg.smartSacrifice then
        local sacrificeThreshold = cfg.voidwalkerSacrificeHP or 15
        
        if petHP < sacrificeThreshold and inCombat then
            -- Verificar que el sacrificio sea util (jugador no esta al 100%)
            if playerHP < 90 then
                self:Print("|cffff6600SACRIFICIO INTELIGENTE!|r Voidwalker HP: " .. string.format("%.0f", petHP) .. "% - Convirtiendome en escudo!")
                return self:ExecuteAbility("Sacrifice")
            else
                self:DebugPrint("Voidwalker moribundo pero jugador al " .. string.format("%.0f", playerHP) .. "% - no sacrifico")
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
    
    -- PRIORIDAD 2: Devour Magic en jugador (debuffs magicos)
    if self:HasMagicDebuff("player") then
        if not self:IsOnCooldown("Devour Magic") then
            -- Verificar modo: Devour Magic (aliado) es habilidad de SOPORTE
            if not self:ShouldUseSupport() then
                self:DebugPrint("[Felhunter] Modo actual no permite Devour Magic en aliados")
                return false
            end
            self:SetCooldown("Devour Magic", 8)
            self:Print("|cff9370DBDevour Magic!|r Quitando debuff del jugador")
            return self:ExecuteAbility("Devour Magic")
        end
    end
    
    -- PRIORIDAD 3: Devour Magic en miembros del grupo
    local debuffedMember = self:FindGroupMemberWithMagicDebuff()
    if debuffedMember then
        if not self:IsOnCooldown("Devour Magic") then
            -- Verificar modo: Devour Magic (grupo) es habilidad de SOPORTE
            if not self:ShouldUseSupport() then
                self:DebugPrint("[Felhunter] Modo actual no permite Devour Magic en grupo")
                return false
            end
            self:SetCooldown("Devour Magic", 8)
            self:Print("|cff9370DBDevour Magic!|r Quitando debuff de " .. tostring(debuffedMember.name))
            return self:ExecutePetAbilityOnTarget("Devour Magic", debuffedMember.unit, debuffedMember.name)
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
    
    -- En WoW 1.12, usamos CastingInfo si esta disponible
    -- o verificamos el nombre del spell siendo casteado
    local spellName = UnitCastingInfo and UnitCastingInfo(unit)
    if spellName then
        return true
    end
    
    -- Fallback: verificar por textura de casting bar (menos confiable)
    -- Algunos addons exponen esta info
    if CastingBarFrame and CastingBarFrame:IsVisible() then
        -- Esto es para el jugador, no enemigos
    end
    
    return false
end

-- Verificar si tiene debuff magico (dispeleable)
function PetAI:HasMagicDebuff(unit)
    if not UnitExists(unit) then return false end
    
    -- Debuffs peligrosos que queremos quitar
    local dangerousDebuffs = {
        "polymorph", "sheep", "fear", "horror", "charm",
        "slow", "frost", "frozen", "root", "nova",
        "curse", "hex", "silence", "pacify"
    }
    
    for i = 1, 16 do
        local texture = UnitDebuff(unit, i)
        if not texture then break end
        local texLower = string.lower(texture)
        
        for j = 1, WCS_TableCount(dangerousDebuffs) do
            if string.find(texLower, dangerousDebuffs[j], 1, true) then
                return true
            end
        end
    end
    
    return false
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
-- DECISION LOOP AUTÃƒâ€œNOMO CENTRALIZADO
-- Refactorizado para mÃƒÂ¡xima claridad, modularidad y futura expansiÃƒÂ³n por eventos
-- ============================================================================
-- ============================================================================
-- FUNCIONES DEL MODO GUARDIÃƒÂN
-- ============================================================================

-- FunciÃƒÂ³n principal de evaluaciÃƒÂ³n del modo GuardiÃƒÂ¡n
function PetAI:EvaluateGuardianMode()
    if not self.GuardianTarget then return false end
    
    -- Buscar el unit ID del objetivo protegido
    local guardianUnit = self:FindGuardianUnit()
    if not guardianUnit then
        self:Print("|cffff0000Advertencia:|r " .. self.GuardianTarget .. " no estÃƒÂ¡ en party/raid")
        return false
    end
    
    -- Verificar si el protegido existe y estÃƒÂ¡ vivo
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
    
    -- PRIORIDAD 2: Fire Shield automÃƒÂ¡tico (Imp)
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

-- Asistir al protegido: atacar lo que ÃƒÂ©l ataca
function PetAI:GuardianAssist(guardianUnit)
    if not guardianUnit then return false end
    
    -- Verificar si el protegido tiene un target
    local guardianTarget = guardianUnit .. "target"
    
    if UnitExists(guardianTarget) and UnitCanAttack("player", guardianTarget) then
        -- Si la pet no estÃƒÂ¡ atacando el mismo objetivo
        if not UnitExists("pettarget") or not UnitIsUnit("pettarget", guardianTarget) then
            -- Asistir al protegido
            TargetUnit(guardianTarget)
            PetAttack()
            self:Print("|cFFFFD700[GUARDIÃƒÂN]|r Asistiendo a " .. self.GuardianTarget)
            self:DebugPrint("[GuardiÃƒÂ¡n] Asistiendo a " .. self.GuardianTarget)
            return true
        end
    end
    
    return false
end

-- Defender al protegido: atacar lo que lo estÃƒÂ¡ atacando
function PetAI:GuardianDefend(guardianUnit)
    if not guardianUnit then return false end
    
    -- Verificar si el protegido estÃƒÂ¡ en combate
    if not UnitAffectingCombat(guardianUnit) then
        return false
    end
    
    -- Buscar enemigos que estÃƒÂ©n atacando al protegido
    -- En WoW 1.12 no hay API directa para esto, asÃƒÂ­ que usamos heurÃƒÂ­stica:
    -- Si el protegido estÃƒÂ¡ en combate y tiene bajo HP, atacar su target
    local guardianHP = self:GetUnitHealthPercent(guardianUnit)
    
    if guardianHP < 50 then
        local guardianTarget = guardianUnit .. "target"
        if UnitExists(guardianTarget) and UnitCanAttack("player", guardianTarget) then
            if not UnitExists("pettarget") or not UnitIsUnit("pettarget", guardianTarget) then
                TargetUnit(guardianTarget)
                PetAttack()
                self:Print("|cFFFF0000[GUARDIÃƒÂN]|r Defendiendo a " .. self.GuardianTarget .. " (HP: " .. string.format("%.0f", guardianHP) .. "%)")
                self:DebugPrint("[GuardiÃƒÂ¡n] Defendiendo a " .. self.GuardianTarget .. " (HP: " .. string.format("%.0f", guardianHP) .. "%)")
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
    
    -- Solo sacrificarse si el protegido estÃƒÂ¡ en peligro crÃƒÂ­tico
    if guardianHP < 20 and UnitAffectingCombat(guardianUnit) then
        -- Verificar que Sacrifice estÃƒÂ© disponible
        if not self:IsOnCooldown("Sacrifice") then
            -- Targetear al protegido y usar Sacrifice
            TargetUnit(guardianUnit)
            if self:ExecuteAbility("Sacrifice") then
                self:Print("|cFFFF0000[GUARDIÃƒÂN]|r Ã‚Â¡SacrificÃƒÂ¡ndose por " .. self.GuardianTarget .. "!")
                self:SetCooldown("Sacrifice", 300)
                return true
            end
        end
    end
    
    return false
end

-- Fire Shield automÃƒÂ¡tico (Imp)
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
    
    -- Verificar si estÃƒÂ¡ en combate o tiene bajo HP
    local guardianHP = self:GetUnitHealthPercent(guardianUnit)
    if UnitAffectingCombat(guardianUnit) or guardianHP < 70 then
        -- Aplicar Fire Shield
        TargetUnit(guardianUnit)
        if self:ExecuteAbility("Fire Shield") then
            self:Print("|cFFFFD700[GUARDIÃƒÂN]|r Fire Shield aplicado a " .. self.GuardianTarget)
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
    
    -- 1. Verificaciones bÃƒÂ¡sicas
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

    -- 3. Hook: Pre-evaluaciÃƒÂ³n (para eventos o mÃƒÂ³dulos externos)
    if self.OnPreEvaluate then
        local handled = self:OnPreEvaluate()
        if handled then
            self.isThinking = false
            return
        end
    end


    -- ============================================================================
    -- MODO GUARDIÃƒÂN: Proteger a un compaÃƒÂ±ero especÃƒÂ­fico
    -- ============================================================================
    if self.currentMode == 4 and self.GuardianTarget then
        local now = GetTime()
        
        -- Revisar cada 0.5 segundos para no sobrecargar
        if (now - self.GuardianLastCheck) >= self.GuardianCheckInterval then
            self.GuardianLastCheck = now
            
            if self:EvaluateGuardianMode() then
                self.isThinking = false
                return  -- Si el modo GuardiÃƒÂ¡n manejÃƒÂ³ la situaciÃƒÂ³n, salir
            end
        end
    end

    -- 4. Detectar tipo de mascota y contexto
    local petType = self:GetPetType()
    if not petType then
        self.isThinking = false
        return
    end

    -- 5. Hook: Permitir override de decisiÃƒÂ³n por mÃƒÂ³dulos externos
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


    -- 7. IntegraciÃƒÂ³n con otros addons: priorizar defensas si hay amenaza alta o alerta de boss
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
    -- LÃƒÂ³gica personalizada para futuras mascotas
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

    -- 8. Hook: Post-evaluaciÃƒÂ³n (para logging, aprendizaje, etc)
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
    end
end
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
-- COMANDO /PETGUARD - MODO GUARDIÃƒÂN
-- ============================================================================

SLASH_PETGUARD1 = "/petguard"
SlashCmdList["PETGUARD"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "" or cmd == "help" then
        PetAI:Print("=== Comandos /petguard ===")
        PetAI:Print("  /petguard [nombre] - Asignar jugador a proteger")
        PetAI:Print("  /petguard clear - Limpiar objetivo protegido")
        PetAI:Print("  /petguard show - Ver quiÃƒÂ©n estÃƒÂ¡ protegiendo")
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
                PetAI:Print("Modo: |cFFFFD700GuardiÃƒÂ¡n|r (Activo)")
            else
                PetAI:Print("Modo: " .. PetAI:GetModeName() .. " (Usa /run WCS_BrainPetAI:SetMode(4) para activar GuardiÃƒÂ¡n)")
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
    
    -- Buscar en raid si no estÃƒÂ¡ en party
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
        
        -- Si no estÃƒÂ¡ en modo GuardiÃƒÂ¡n, sugerir activarlo
        if PetAI.currentMode ~= 4 then
            PetAI:SetMode(4)
            PetAI:Print("|cFFFFD700Modo GuardiÃƒÂ¡n activado automÃƒÂ¡ticamente|r")
        end
    else
        PetAI:Print("|cffff0000Error:|r '" .. targetName .. "' no encontrado en party/raid")
        PetAI:Print("AsegÃƒÂºrate de escribir el nombre exacto del jugador")
    end
end

PetAI:Print("v" .. PetAI.VERSION .. " - Sistema de IA con Auto-Reenslave y Coordinacion")





