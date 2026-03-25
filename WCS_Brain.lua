--[[
    WCS_Brain.lua - Cerebro Central Unificado v6.7.0
    Sistema de IA Independiente para Warlock
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    SISTEMA COMPLETAMENTE AUTOSUFICIENTE
    Solo requiere: WCS_SpellDB.lua, WCS_BrainCore.lua, WCS_BrainUI.lua
    
    v6.4.0 - Cerebro Unificado:
    - Sistema de votacion integrado (no depende de WCS_DemonologyAI)
    - DemonKnowledge completo (Imp, Voidwalker, Succubus, Felhunter)
    - Deteccion inteligente (casters, CC, amenaza)
    - Sinergias Warlock-Mascota completas
    - Sistema de personalidad y emociones
    - Chat social integrado
]]--

WCS_Brain = WCS_Brain or {}
WCS_Brain.VERSION = "7.0.0"
WCS_Brain.ENABLED = true
WCS_Brain.DEBUG = false

-- ===========================================
-- FUNCIONES HELPER PARA COMPATIBILIDAD LUA 5.0
-- ===========================================

-- WCS_TableCount ya está definido en WCS_Helpers.lua
-- (Función duplicada eliminada - ver WCS_Helpers.lua)
-- Helper para contar elementos en tabla (reemplazo de #table en Lua 5.1+) [COMENTADO]
--function WCS_TableCount(t)
--    if not t then return 0 end
--    if table.getn then
--        return table.getn(t)
--    else
--        local count = 0
--        for _ in pairs(t) do
--            count = count + 1
--        end
--        return count
--    end
--end

-- Helper para concatenar tabla (reemplazo mejorado de table.concat)
function WCS_TableConcat(t, sep)
    if not t then return "" end
    sep = sep or ""
    local result = ""
    for i = 1, WCS_TableCount(t) do
        if i > 1 then result = result .. sep end
        result = result .. tostring(t[i])
    end
    return result
end

-- Helper para verificar si tabla está vacía
function WCS_TableIsEmpty(t)
    if not t then return true end
    return WCS_TableCount(t) == 0
end

-- Helper para buscar en strings (wrapper de string.find)
function WCS_StringFind(str, pattern, plain)
    if not str or not pattern then return nil end
    return string.find(str, pattern, 1, plain)
end

-- Sistema de tracking de sugerencias para evitar repeticiones
WCS_Brain.LastSuggestion = {
    spell = nil,
    time = 0,
    count = 0,
    maxRepeats = 3,  -- Maximo de veces que se sugiere el mismo hechizo
    timeout = 2.0    -- Tiempo maximo para considerar repeticion (segundos)
}

-- ============================================================================
-- CONFIGURACION
-- ============================================================================
WCS_Brain.Config = {
    spec = "affliction",
    healthCritical = 20,
    healthLow = 35,
    healthMedium = 60,
    manaCritical = 15,
    manaLow = 30,
    manaMedium = 50,
    petHealthCritical = 20,
    petHealthLow = 35,
    targetExecute = 25,
    useLifeTap = true,
    lifeTapMinHealth = 40,
    useDarkPact = true
}

-- ============================================================================
-- PRIORIDADES
-- ============================================================================
WCS_Brain.Priority = {
    EMERGENCY = 1, INTERRUPT = 2, DEFENSIVE = 3, PET_SAVE = 4,
    PET_ACTION = 5, SYNERGY = 6, DOTS = 7, CURSE = 8, FILLER = 9, MANA = 10
}

-- ============================================================================
-- FUNCIONES AUXILIARES
-- ============================================================================
local function getTime()
    return GetTime and GetTime() or 0
end

local function debugPrint(msg)
    if WCS_Brain.DEBUG and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r " .. tostring(msg))
    end
end

-- ============================================================================
-- SISTEMA DE DETECCION DE HECHIZOS APRENDIDOS
-- ============================================================================
WCS_Brain.LearnedSpells = {}
WCS_Brain.SpellCache = {
    lastUpdate = 0,
    updateInterval = 5 -- Actualizar cada 5 segundos maximo
}

-- Escanea el spellbook y cachea los hechizos aprendidos (optimizado)
function WCS_Brain:ScanSpellbook()
    local now = getTime()
    -- No escanear muy frecuentemente (optimizado a 5 segundos)
    if (now - self.SpellCache.lastUpdate) < 5 then
        return
    end
    
    -- Usar hash table optimizada para búsquedas O(1)
    self.LearnedSpells = {}
    self.SpellIndexCache = {}  -- Caché adicional para índices
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        
        -- Guardar el hechizo con su rango mas alto
        if not self.LearnedSpells[spellName] then
            self.LearnedSpells[spellName] = {
                index = i,
                rank = spellRank,
                maxRankIndex = i
            }
            -- Caché directo para búsquedas rápidas de índice
            self.SpellIndexCache[spellName] = i
        else
            -- Actualizar al rango mas alto (ultimo encontrado)
            self.LearnedSpells[spellName].maxRankIndex = i
            self.LearnedSpells[spellName].rank = spellRank
            self.SpellIndexCache[spellName] = i
        end
        i = i + 1
    end
    
    self.SpellCache.lastUpdate = now
    self.SpellCache.spellCount = i - 1
    debugPrint("Spellbook escaneado: " .. self.SpellCache.spellCount .. " hechizos")
end

-- Verifica si un hechizo esta aprendido (optimizado)
function WCS_Brain:IsSpellLearned(spellName)
    if not spellName then return false end
    
    -- Búsqueda O(1) en caché de índices
    if self.SpellIndexCache and self.SpellIndexCache[spellName] then
        return true
    end
    
    -- Casos especiales que siempre estan disponibles
    if spellName == "Shoot" or spellName == "Attack" then
        return true
    end
    
    -- Habilidades de mascota - verificar de forma diferente
    if spellName == "Torment" or spellName == "Sacrifice" or 
       spellName == "Spell Lock" or spellName == "Devour Magic" or
       spellName == "Seduction" or spellName == "Fire Shield" or
       spellName == "Phase Shift" then
        return UnitExists("pet") -- Si hay mascota, asumimos que tiene sus habilidades
    end
    
    -- Items especiales
    if spellName == "Healthstone" then
        return true -- La verificacion real se hace en WCS_BrainCore:FindHealthstone()
    end
    
    -- Escanear si el cache esta vacio o desactualizado
    if not self.LearnedSpells or next(self.LearnedSpells) == nil then
        self:ScanSpellbook()
    end
    
    return self.LearnedSpells[spellName] ~= nil
end

-- Obtiene el indice del hechizo en el spellbook (para CastSpell)
function WCS_Brain:GetSpellIndex(spellName)
    if not self.LearnedSpells[spellName] then
        self:ScanSpellbook()
    end
    
    local spell = self.LearnedSpells[spellName]
    if spell then
        return spell.maxRankIndex
    end
    return nil
end

-- Fuerza re-escaneo del spellbook (llamar al cambiar talentos)
function WCS_Brain:RefreshSpellbook()
    self.SpellCache.lastUpdate = 0
    self:ScanSpellbook()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Spellbook actualizado")
end

-- ============================================================================
-- SISTEMA DE COOLDOWNS
-- ============================================================================
WCS_Brain.Cooldowns = {}

-- Cooldowns conocidos de hechizos (en segundos)
WCS_Brain.SpellCooldowns = {
    ["Death Coil"] = 120,      -- 2 minutos
    ["Howl of Terror"] = 40,   -- 40 segundos
    ["Shadowburn"] = 15,       -- 15 segundos
    ["Conflagrate"] = 10,      -- 10 segundos
    ["Soul Fire"] = 60,        -- 1 minuto (aprox)
    ["Spell Lock"] = 24,       -- 24 segundos
    ["Devour Magic"] = 8,      -- 8 segundos
    ["Seduction"] = 15,        -- 15 segundos (DR)
    ["Sacrifice"] = 300,       -- 5 minutos
    ["Fel Domination"] = 900   -- 15 minutos
}

-- Registra cuando se lanza un hechizo con cooldown
function WCS_Brain:RegisterSpellCast(spellName)
    if not spellName then return end
    local cd = self.SpellCooldowns[spellName]
    if cd then
        self.Cooldowns[spellName] = getTime() + cd
        debugPrint("CD registrado: " .. spellName .. " (" .. cd .. "s)")
    end
end

-- Verifica si un hechizo esta en cooldown
function WCS_Brain:IsSpellOnCooldown(spellName)
    if not spellName then return false end
    
    -- Primero intentar usar la API del juego
    local spellIndex = self:GetSpellIndex(spellName)
    if spellIndex then
        local start, duration = GetSpellCooldown(spellIndex, BOOKTYPE_SPELL)
        if start and duration and start > 0 and duration > 1.5 then
            -- Cooldown real del juego (ignorar GCD de 1.5s)
            return true
        end
    end
    
    -- Fallback: usar nuestro tracking manual
    local cdEnd = self.Cooldowns[spellName]
    if cdEnd and getTime() < cdEnd then
        return true
    end
    
    return false
end

-- Obtiene el tiempo restante de cooldown
function WCS_Brain:GetSpellCooldownRemaining(spellName)
    if not spellName then return 0 end
    
    -- Intentar API del juego
    local spellIndex = self:GetSpellIndex(spellName)
    if spellIndex then
        local start, duration = GetSpellCooldown(spellIndex, BOOKTYPE_SPELL)
        if start and duration and start > 0 then
            local remaining = (start + duration) - getTime()
            if remaining > 0 then
                return remaining
            end
        end
    end
    
    -- Fallback manual
    local cdEnd = self.Cooldowns[spellName]
    if cdEnd then
        local remaining = cdEnd - getTime()
        if remaining > 0 then
            return remaining
        end
    end
    
    return 0
end

-- Limpia cooldowns expirados
function WCS_Brain:CleanupCooldowns()
    local now = getTime()
    for spell, cdEnd in pairs(self.Cooldowns) do
        if now >= cdEnd then
            self.Cooldowns[spell] = nil
        end
    end
end

-- ============================================================================
-- CONTEXTO UNIFICADO
-- ============================================================================
WCS_Brain.Context = {
    lastUpdate = 0,
    updateInterval = 0.1,
    player = {
        health = 100, healthMax = 100, healthPct = 100,
        mana = 100, manaMax = 100, manaPct = 100,
        inCombat = false, isCasting = false, isMoving = false
    },
    target = {
        exists = false, health = 0, healthPct = 100,
        isHostile = false, isDead = false, classification = "normal",
        isCaster = false, hasMana = false,
        hasCorruption = false, hasImmolate = false,
        hasCurseOfAgony = false, hasSiphonLife = false, hasAnyCurse = false
    },
    pet = {
        exists = false, health = 0, healthPct = 100,
        mana = 0, manaPct = 100, isActive = false, type = nil
    },
    phase = "idle"
}

-- ============================================================================
-- CONOCIMIENTO DE DEMONIOS
-- ============================================================================
WCS_Brain.DemonKnowledge = {
    imp = {
        abilities = {
            ["Fire Bolt"] = {type = "offense", priority = 70},
            ["Fire Shield"] = {type = "utility", priority = 85},
            ["Phase Shift"] = {type = "survival", priority = 95}
        },
        role = "ranged_dps"
    },
    voidwalker = {
        abilities = {
            ["Torment"] = {type = "defense", priority = 90},
            ["Consume Shadows"] = {type = "survival", priority = 80},
            ["Sacrifice"] = {type = "emergency", priority = 100}
        },
        role = "tank"
    },
    succubus = {
        abilities = {
            ["Lash of Pain"] = {type = "offense", priority = 75},
            ["Seduction"] = {type = "cc", priority = 95}
        },
        role = "cc_dps"
    },
    felhunter = {
        abilities = {
            ["Shadow Bite"] = {type = "offense", priority = 70},
            ["Devour Magic"] = {type = "utility", priority = 90},
            ["Spell Lock"] = {type = "interrupt", priority = 98}
        },
        role = "anti_caster"
    }
}

-- ============================================================================
-- SINERGIAS WARLOCK-MASCOTA
-- ============================================================================
WCS_Brain.PetSynergies = {
    imp = {["Dark Pact"] = 1.40, ["Shadow Bolt"] = 1.10},
    voidwalker = {["Health Funnel"] = 1.30, ["Shadow Bolt"] = 1.15},
    succubus = {["Shadow Bolt"] = 1.20, ["Drain Life"] = 1.10},
    felhunter = {["Drain Mana"] = 1.30, ["Dark Pact"] = 1.25}
}

-- ============================================================================
-- SISTEMA DE PERSONALIDAD
-- ============================================================================
WCS_Brain.Pet = {
    PersonalityTypes = {
        ["Timido"] = {aggression = 20, loyalty = 90},
        ["Agresivo"] = {aggression = 95, loyalty = 60},
        ["Protector"] = {aggression = 70, loyalty = 95},
        ["Sabio"] = {aggression = 40, loyalty = 80},
        ["Rebelde"] = {aggression = 80, loyalty = 30}
    },
    State = {
        personalityType = "Protector",
        emotions = {joy = 50, fear = 0, anger = 0},
        mood = {happiness = 75, stress = 0, energy = 100},
        lastMoodUpdate = 0
    },
    ChatResponses = {
        ["Timido"] = {combat_start = {"O-oh no..."}, idle = {"..."}},
        ["Agresivo"] = {combat_start = {"A DESTRUIR!"}, idle = {"Aburrido..."}},
        ["Protector"] = {combat_start = {"Te protegere."}, idle = {"Vigilando."}},
        ["Sabio"] = {combat_start = {"Interesante..."}, idle = {"Meditando..."}},
        ["Rebelde"] = {combat_start = {"Ugh, otra vez?"}, idle = {"*bosteza*"}}
    }
}

-- ============================================================================
-- DETECCION INTELIGENTE
-- ============================================================================

-- Detectar tipo de mascota por habilidades de la action bar
function WCS_Brain:DetectPetType()
    if not UnitExists("pet") then return nil end
    
    -- Verificar habilidades en la pet action bar
    -- Slot 1-10 son las acciones de mascota
    for i = 1, 10 do
        local name, subtext, texture = GetPetActionInfo(i)
        if name then
            -- Imp: Fire Bolt, Fire Shield, Blood Pact
            if name == "Fire Bolt" or name == "Fire Shield" or name == "Blood Pact" or
               name == "Descarga de Fuego" or name == "Escudo de Fuego" then
                return "imp"
            end
            -- Voidwalker: Torment, Sacrifice, Consume Shadows
            if name == "Torment" or name == "Sacrifice" or name == "Consume Shadows" or
               name == "Tormento" or name == "Sacrificio" or name == "Consumir Sombras" then
                return "voidwalker"
            end
            -- Succubus: Lash of Pain, Seduction, Soothing Kiss
            if name == "Lash of Pain" or name == "Seduction" or name == "Soothing Kiss" or
               name == "Latigo de Dolor" or name == "Seduccion" then
                return "succubus"
            end
            -- Felhunter: Spell Lock, Devour Magic, Shadow Bite
            if name == "Spell Lock" or name == "Devour Magic" or name == "Shadow Bite" or
               name == "Bloqueo de Hechizo" or name == "Devorar Magia" then
                return "felhunter"
            end
        end
        -- Tambien verificar por textura si el nombre no coincide
        if texture then
            if string.find(texture, "FireBolt") or string.find(texture, "FireShield") then
                return "imp"
            end
            if string.find(texture, "Torment") or string.find(texture, "Sacrifice") or string.find(texture, "ConsumeShadows") then
                return "voidwalker"
            end
            if string.find(texture, "LashOfPain") or string.find(texture, "Seduction") then
                return "succubus"
            end
            if string.find(texture, "SpellLock") or string.find(texture, "DevourMagic") then
                return "felhunter"
            end
        end
    end
    
    -- Fallback: detectar por creatureFamily si esta disponible
    local family = UnitCreatureFamily("pet")
    if family then
        if family == "Imp" or family == "Diablillo" then return "imp" end
        if family == "Voidwalker" or family == "Abisario" then return "voidwalker" end
        if family == "Succubus" or family == "Sucubo" then return "succubus" end
        if family == "Felhunter" or family == "Manafago" then return "felhunter" end
    end
    
    return "unknown"
end

function WCS_Brain:IsTargetCaster()
    if not UnitExists("target") then return false end
    local maxMana = UnitManaMax("target") or 0
    return maxMana > 0
end

-- Detectar si el target esta casteando (para interrupts)
function WCS_Brain:IsTargetCasting()
    -- En Vanilla/Turtle WoW no hay API directa para esto
    -- Usamos la barra de casteo del target si existe
    if TargetFrameSpellBar and TargetFrameSpellBar:IsVisible() then
        return true
    end
    -- Fallback: verificar si es caster y esta en combate
    return false
end

-- Detectar si el jugador tiene un debuff magico (para Devour Magic)
function WCS_Brain:PlayerHasMagicDebuff()
    -- Escanear debuffs del jugador
    local i = 1
    while true do
        local texture, count, debuffType = UnitDebuff("player", i)
        if not texture then break end
        -- debuffType puede ser: "Magic", "Curse", "Disease", "Poison"
        if debuffType == "Magic" then
            return true
        end
        i = i + 1
    end
    return false
end

-- Detectar si el jugador tiene una maldicion (para Devour Magic)
function WCS_Brain:PlayerHasCurse()
    local i = 1
    while true do
        local texture, count, debuffType = UnitDebuff("player", i)
        if not texture then break end
        if debuffType == "Curse" then
            return true
        end
        i = i + 1
    end
    return false
end

function WCS_Brain:PlayerHasAggro()
    if not UnitExists("target") then return false end
    return UnitIsUnit("targettarget", "player")
end

-- ============================================================================
-- ACTUALIZACION DE CONTEXTO
-- ============================================================================
function WCS_Brain:UpdateContext()
    local now = getTime()
    if now - self.Context.lastUpdate < self.Context.updateInterval then return false end
    self.Context.lastUpdate = now
    
    local ctx = self.Context
    
    -- PLAYER
    ctx.player.healthMax = UnitHealthMax("player") or 1
    ctx.player.health = UnitHealth("player") or 0
    ctx.player.healthPct = (ctx.player.health / ctx.player.healthMax) * 100
    ctx.player.manaMax = UnitManaMax("player") or 1
    ctx.player.mana = UnitMana("player") or 0
    ctx.player.manaPct = (ctx.player.mana / ctx.player.manaMax) * 100
    ctx.player.inCombat = UnitAffectingCombat("player") or false
    ctx.player.isCasting = WCS_BrainCore and WCS_BrainCore:IsCasting() or false
    ctx.player.isMoving = WCS_BrainCore and WCS_BrainCore:IsMoving() or false
    
    -- TARGET
    ctx.target.exists = UnitExists("target") or false
    if ctx.target.exists then
        local maxHp = UnitHealthMax("target") or 1
        ctx.target.health = UnitHealth("target") or 0
        ctx.target.healthPct = (ctx.target.health / maxHp) * 100
        ctx.target.isHostile = UnitCanAttack("player", "target") or false
        ctx.target.isDead = UnitIsDeadOrGhost("target") or false
        ctx.target.classification = UnitClassification("target") or "normal"
        ctx.target.isCaster = self:IsTargetCaster()
        ctx.target.hasMana = (UnitManaMax("target") or 0) > 0
        if WCS_BrainCore then
            ctx.target.hasCorruption = WCS_BrainCore:HasCorruption()
            ctx.target.hasImmolate = WCS_BrainCore:HasImmolate()
            ctx.target.hasCurseOfAgony = WCS_BrainCore:HasCurseOfAgony()
            ctx.target.hasSiphonLife = WCS_BrainCore:HasSiphonLife()
            ctx.target.hasAnyCurse = WCS_BrainCore:HasAnyCurse()
        end
    end
    
    -- PET
    ctx.pet.exists = UnitExists("pet") or false
    if ctx.pet.exists then
        local maxPetHp = UnitHealthMax("pet") or 1
        ctx.pet.health = UnitHealth("pet") or 0
        ctx.pet.healthPct = (ctx.pet.health / maxPetHp) * 100
        ctx.pet.mana = UnitMana("pet") or 0
        local maxPetMana = UnitManaMax("pet") or 1
        ctx.pet.manaPct = maxPetMana > 0 and (ctx.pet.mana / maxPetMana) * 100 or 100
        ctx.pet.isActive = not UnitIsDeadOrGhost("pet")
        
        -- Detectar tipo de mascota por habilidades (mas confiable que por nombre)
        ctx.pet.type = self:DetectPetType()
    end
    
    self:DeterminePhase()
    return true
end

function WCS_Brain:DeterminePhase()
    local ctx = self.Context
    if not ctx.player.inCombat then ctx.phase = "idle" return end
    if ctx.player.healthPct < self.Config.healthCritical then ctx.phase = "emergency" return end
    if ctx.target.exists and ctx.target.healthPct < self.Config.targetExecute then ctx.phase = "execute" return end
    ctx.phase = "sustain"
end

-- ============================================================================
-- SISTEMA DE IA AUTONOMA DE MASCOTA
-- La mascota toma decisiones y actua por su cuenta, sin intervencion del jugador
-- ============================================================================
WCS_Brain.PetAI = {
    enabled = true,
    lastAction = 0,
    actionInterval = 1.5,  -- Evaluar cada 1.5 segundos (GCD)
    lastAbility = nil,
    debug = false
}

-- Cooldowns de habilidades de mascota
WCS_Brain.PetAbilityCooldowns = {
    -- Felhunter
    ["Spell Lock"] = 24,
    ["Devour Magic"] = 8,
    ["Tainted Blood"] = 10,
    -- Succubus
    ["Seduction"] = 15,
    ["Soothing Kiss"] = 4,
    ["Lesser Invisibility"] = 30,
    ["Lash of Pain"] = 6,
    -- Voidwalker
    ["Torment"] = 5,
    ["Sacrifice"] = 300,
    ["Consume Shadows"] = 10,
    ["Suffering"] = 120,
    -- Imp
    ["Fire Shield"] = 30,
    ["Phase Shift"] = 1,
    ["Blood Pact"] = 0
}
WCS_Brain.PetCooldowns = {}

-- Registra cooldown de habilidad de mascota
function WCS_Brain:RegisterPetAbility(abilityName)
    local cd = self.PetAbilityCooldowns[abilityName]
    if cd then
        self.PetCooldowns[abilityName] = getTime() + cd
    end
end

-- Verifica si habilidad de mascota esta en CD
function WCS_Brain:IsPetAbilityOnCooldown(abilityName)
    local cdEnd = self.PetCooldowns[abilityName]
    if cdEnd and getTime() < cdEnd then
        return true
    end
    return false
end

-- Encuentra el indice de una habilidad en la barra de mascota
function WCS_Brain:FindPetAbilityIndex(abilityName)
    for i = 1, 10 do
        local name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)
        if name and name == abilityName then
            return i
        end
    end
    return nil
end

-- Ejecuta una habilidad de mascota automaticamente
function WCS_Brain:ExecutePetAbility(abilityName)
    if not abilityName then return false end
    if self:IsPetAbilityOnCooldown(abilityName) then return false end
    
    local index = self:FindPetAbilityIndex(abilityName)
    if index then
        CastPetAction(index)
        self:RegisterPetAbility(abilityName)
        if self.PetAI.debug then
            debugPrint("[PetAI] Ejecutando: " .. abilityName)
        end
        return true
    end
    return false
end

-- IA de la mascota - evalua y ejecuta acciones automaticamente
function WCS_Brain:PetAIThink()
    if not self.PetAI.enabled then return end
    
    local ctx = self.Context
    if not ctx.pet.exists or not ctx.pet.isActive then return end
    
    local now = getTime()
    if (now - self.PetAI.lastAction) < self.PetAI.actionInterval then return end
    
    -- Actualizar contexto si es necesario
    self:UpdateContext()
    
    local action = nil
    local reason = nil
    
    -- === PRIORIDAD 1: EMERGENCIA DEL WARLOCK ===
    -- Voidwalker: Sacrifice si el warlock esta muy bajo
    if ctx.pet.type == "voidwalker" and ctx.player.healthPct < 20 and ctx.player.inCombat then
        action = "Sacrifice"
        reason = "Warlock en peligro mortal"
    end
    
    -- === PRIORIDAD 2: INTERRUMPIR ===
    -- Felhunter: Spell Lock vs casters que estan casteando
    if not action and ctx.pet.type == "felhunter" and ctx.target.exists then
        if ctx.target.isCaster and not self:IsPetAbilityOnCooldown("Spell Lock") then
            -- Verificar si el target esta casteando (si es posible)
            action = "Spell Lock"
            reason = "Interrumpir caster"
        end
    end
    
    -- === PRIORIDAD 3: CONTROL DE AMENAZA ===
    -- Voidwalker: Torment si el warlock tiene aggro
    if not action and ctx.pet.type == "voidwalker" and ctx.target.exists and ctx.target.isHostile then
        if self:PlayerHasAggro() and not self:IsPetAbilityOnCooldown("Torment") then
            action = "Torment"
            reason = "Recuperar aggro"
        end
    end
    
    -- === PRIORIDAD 4: UTILIDAD ===
    -- Felhunter: Devour Magic si el warlock tiene debuff magico
    if not action and ctx.pet.type == "felhunter" then
        if self:PlayerHasMagicDebuff() and not self:IsPetAbilityOnCooldown("Devour Magic") then
            action = "Devour Magic"
            reason = "Limpiar debuff magico"
        end
    end
    
    -- Imp: Fire Shield si no esta activo
    if not action and ctx.pet.type == "imp" then
        -- Fire Shield es un buff, verificar si esta activo
        if not self:IsPetAbilityOnCooldown("Fire Shield") then
            -- Solo usar si estamos en combate
            if ctx.player.inCombat then
                action = "Fire Shield"
                reason = "Proteccion de fuego"
            end
        end
    end
    
    -- === PRIORIDAD 5: SUPERVIVENCIA DE MASCOTA ===
    -- Voidwalker: Consume Shadows fuera de combate si esta herido
    if not action and ctx.pet.type == "voidwalker" and not ctx.player.inCombat then
        if ctx.pet.healthPct < 70 and not self:IsPetAbilityOnCooldown("Consume Shadows") then
            action = "Consume Shadows"
            reason = "Curarse fuera de combate"
        end
    end
    
    -- Imp: Phase Shift si esta en peligro y no en combate activo
    if not action and ctx.pet.type == "imp" and ctx.pet.healthPct < 30 then
        if not self:IsPetAbilityOnCooldown("Phase Shift") then
            action = "Phase Shift"
            reason = "Escapar de peligro"
        end
    end
    
    -- Ejecutar la accion si hay una
    if action then
        if self:ExecutePetAbility(action) then
            self.PetAI.lastAction = now
            self.PetAI.lastAbility = action
            if self.PetAI.debug or self.DEBUG then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r " .. action .. " - " .. reason)
            end
        end
    end
end

-- Frame para el loop de IA de mascota
WCS_Brain.PetAIFrame = CreateFrame("Frame", "WCS_BrainPetAIFrame", UIParent)
WCS_Brain.PetAIFrame.elapsed = 0
WCS_Brain.PetAIFrame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 0.5 then  -- Evaluar cada 0.5 segundos
        this.elapsed = 0
        WCS_Brain:PetAIThink()
    end
end)

-- Funcion legacy para compatibilidad (ya no sugiere, solo retorna nil)
function WCS_Brain:GetPetActionVote()
    -- La mascota ahora actua autonomamente, no necesita sugerir al jugador
    return nil
end

-- ============================================================================
-- ARBOL DE DECISION
-- ============================================================================
function WCS_Brain:CheckEmergency()
    local ctx = self.Context
    if ctx.player.healthPct >= self.Config.healthCritical then return nil end
    
    -- Healthstone es INSTANT - se puede usar en movimiento
    if WCS_BrainCore then
        local bag, slot = WCS_BrainCore:FindHealthstone()
        if bag then
            return {action = "USE_ITEM", spell = "Healthstone", priority = self.Priority.EMERGENCY, reason = "HP Critico"}
        end
    end
    
    -- Death Coil es INSTANT - se puede usar en movimiento (si lo tiene Y no esta en CD)
    if self:IsSpellLearned("Death Coil") and not self:IsSpellOnCooldown("Death Coil") then
        return {action = "CAST", spell = "Death Coil", priority = self.Priority.EMERGENCY, reason = "HP Critico - Death Coil"}
    end
    
    -- Drain Life es CANALIZADO - NO usar en movimiento
    if not ctx.player.isMoving and ctx.target.exists and ctx.target.isHostile then
        return {action = "CAST", spell = "Drain Life", priority = self.Priority.EMERGENCY, reason = "HP Critico - Drain"}
    end
    return nil
end

function WCS_Brain:CheckDefensive()
    local ctx = self.Context
    if ctx.player.healthPct >= self.Config.healthLow then return nil end
    
    -- Sacrifice ahora lo maneja la PetAI automaticamente
    -- Aqui solo sugerimos hechizos del Warlock
    
    -- Howl of Terror si hay multiples enemigos (emergencia)
    if self:IsSpellLearned("Howl of Terror") and not self:IsSpellOnCooldown("Howl of Terror") then
        -- Solo si estamos muy bajos
        if ctx.player.healthPct < 25 then
            return {action = "CAST", spell = "Howl of Terror", priority = self.Priority.DEFENSIVE, reason = "Emergencia - Fear AoE"}
        end
    end
    
    -- Fear al target si estamos bajos y no es inmune
    if ctx.target.exists and ctx.target.isHostile and not ctx.player.isMoving then
        if self:IsSpellLearned("Fear") and ctx.player.healthPct < 30 then
            return {action = "CAST", spell = "Fear", priority = self.Priority.DEFENSIVE, reason = "Fear defensivo"}
        end
    end
    
    return nil
end

-- ============================================================================
-- INTERRUPT - Controlar casters enemigos
-- ============================================================================
function WCS_Brain:CheckInterrupt()
    local ctx = self.Context
    if not ctx.target.exists or not ctx.target.isHostile then return nil end
    
    -- Solo intentar interrupt si el target es caster
    if not ctx.target.isCaster then return nil end
    
    -- Verificar si el target esta casteando
    local targetCasting = self:IsTargetCasting()
    
    -- SPELL LOCK del Felhunter - Lo maneja PetAI automaticamente
    -- Aqui manejamos los interrupts del Warlock
    
    -- DEATH COIL - Instant, 3s horror (no es fear, no rompe con daño)
    if targetCasting and self:IsSpellLearned("Death Coil") and not self:IsSpellOnCooldown("Death Coil") then
        return {action = "CAST", spell = "Death Coil", priority = self.Priority.INTERRUPT, reason = "Interrupt - Death Coil"}
    end
    
    -- FEAR - 1.5s cast, pero util si no tenemos Death Coil
    -- Solo si no estamos en movimiento
    if targetCasting and not ctx.player.isMoving then
        if self:IsSpellLearned("Fear") and ctx.player.healthPct > 40 then
            return {action = "CAST", spell = "Fear", priority = self.Priority.INTERRUPT, reason = "Interrupt - Fear"}
        end
    end
    
    return nil
end

function WCS_Brain:CheckPetSave()
    local ctx = self.Context
    if not ctx.pet.exists or ctx.pet.healthPct >= self.Config.petHealthCritical then return nil end
    
    -- Health Funnel es CANALIZADO - NO usar en movimiento
    if ctx.player.isMoving then return nil end
    
    if ctx.player.healthPct > self.Config.healthMedium then
        return {action = "CAST", spell = "Health Funnel", priority = self.Priority.PET_SAVE, reason = "Curar mascota"}
    end
    return nil
end

function WCS_Brain:CheckPetActions()
    -- La mascota ahora actua autonomamente via PetAI
    -- Esta funcion ya no sugiere acciones de mascota al jugador
    return nil
end

function WCS_Brain:CheckPetSynergy()
    local ctx = self.Context
    if not ctx.pet.exists then return nil end
    
    -- Dark Pact es INSTANT - se puede usar en movimiento
    -- Funciona con cualquier mascota que tenga mana (Imp, Felhunter, Succubus)
    -- Voidwalker NO tiene mana, usa rage
    if self.Config.useDarkPact and self:IsSpellLearned("Dark Pact") then
        local petHasMana = ctx.pet.type == "imp" or ctx.pet.type == "felhunter" or ctx.pet.type == "succubus"
        if petHasMana and ctx.player.manaPct < 40 and ctx.pet.manaPct > 40 then
            return {action = "CAST", spell = "Dark Pact", priority = self.Priority.SYNERGY, reason = "Dark Pact (" .. ctx.pet.type .. ")"}
        end
    end
    
    -- Health Funnel es CANALIZADO - NO usar en movimiento
    if not ctx.player.isMoving and self:IsSpellLearned("Health Funnel") then
        -- Prioridad alta si mascota esta baja
        if ctx.pet.healthPct < 50 and ctx.player.healthPct > 50 then
            return {action = "CAST", spell = "Health Funnel", priority = self.Priority.SYNERGY, reason = "Curar " .. (ctx.pet.type or "mascota")}
        end
    end
    
    -- Drain Mana es CANALIZADO - NO usar en movimiento
    -- Solo contra targets con mana
    if not ctx.player.isMoving and self:IsSpellLearned("Drain Mana") then
        if ctx.target.exists and ctx.target.isCaster and ctx.player.manaPct < 50 then
            return {action = "CAST", spell = "Drain Mana", priority = self.Priority.SYNERGY, reason = "Robar mana"}
        end
    end
    
    return nil
end

function WCS_Brain:CheckDoTs()
    local ctx = self.Context
    if not ctx.target.exists or not ctx.target.isHostile or ctx.target.isDead then return nil end
    
    -- No aplicar DoTs si el target va a morir pronto (menos de 10% HP)
    if ctx.target.healthPct < 10 then return nil end
    
    -- No aplicar DoTs si estamos muy bajos de mana (excepto Corruption que es eficiente)
    local lowMana = ctx.player.manaPct < self.Config.manaLow
    
    -- CORRUPTION - Instant, se puede usar en movimiento
    -- Prioridad maxima porque es instant y muy eficiente
    if not ctx.target.hasCorruption and self:IsSpellLearned("Corruption") then
        return {action = "CAST", spell = "Corruption", priority = self.Priority.DOTS, reason = "Aplicar Corruption"}
    end
    
    -- SIPHON LIFE - Instant, se puede usar en movimiento (TALENTO Affliction)
    -- Solo si el target tiene suficiente vida para que valga la pena
    if not ctx.target.hasSiphonLife and ctx.target.healthPct > 40 and not lowMana then
        if self:IsSpellLearned("Siphon Life") then
            return {action = "CAST", spell = "Siphon Life", priority = self.Priority.DOTS, reason = "Aplicar Siphon Life"}
        end
    end
    
    -- IMMOLATE - Tiene cast time, NO usar en movimiento
    -- Solo si el target tiene suficiente vida y tenemos mana
    if not ctx.player.isMoving and not ctx.target.hasImmolate and ctx.target.healthPct > 30 and not lowMana then
        if self:IsSpellLearned("Immolate") then
            return {action = "CAST", spell = "Immolate", priority = self.Priority.DOTS, reason = "Aplicar Immolate"}
        end
    end
    
    return nil
end

function WCS_Brain:CheckCurse()
    local ctx = self.Context
    if not ctx.target.exists or not ctx.target.isHostile or ctx.target.isDead then return nil end
    
    -- No aplicar curse si ya tiene una (solo puede tener 1 curse por warlock)
    if ctx.target.hasAnyCurse then return nil end
    
    -- No aplicar si el target va a morir pronto
    if ctx.target.healthPct < 15 then return nil end
    
    -- CURSE OF TONGUES - Contra casters, muy util
    if ctx.target.isCaster and self:IsSpellLearned("Curse of Tongues") then
        return {action = "CAST", spell = "Curse of Tongues", priority = self.Priority.CURSE, reason = "CoT vs Caster"}
    end
    
    -- CURSE OF AGONY - Default para DPS
    if self:IsSpellLearned("Curse of Agony") then
        return {action = "CAST", spell = "Curse of Agony", priority = self.Priority.CURSE, reason = "Aplicar CoA"}
    end
    
    -- CURSE OF WEAKNESS - Si no tenemos CoA (bajo nivel)
    if self:IsSpellLearned("Curse of Weakness") then
        return {action = "CAST", spell = "Curse of Weakness", priority = self.Priority.CURSE, reason = "Aplicar CoW"}
    end
    
    return nil
end

function WCS_Brain:CheckFiller()
    local ctx = self.Context
    if not ctx.target.exists or not ctx.target.isHostile then return nil end
    
    -- Si estamos en movimiento, solo hechizos instantaneos
    if ctx.player.isMoving then
        -- Corruption es instant
        if not ctx.target.hasCorruption and self:IsSpellLearned("Corruption") then
            return {action = "CAST", spell = "Corruption", priority = self.Priority.FILLER, reason = "Corruption (moviendo)"}
        end
        -- Curse of Agony es instant
        if not ctx.target.hasAnyCurse and self:IsSpellLearned("Curse of Agony") then
            return {action = "CAST", spell = "Curse of Agony", priority = self.Priority.FILLER, reason = "CoA (moviendo)"}
        end
        -- Siphon Life es instant (talento)
        if not ctx.target.hasSiphonLife and self:IsSpellLearned("Siphon Life") then
            return {action = "CAST", spell = "Siphon Life", priority = self.Priority.FILLER, reason = "Siphon Life (moviendo)"}
        end
        -- Life Tap es instant (si necesitamos mana y tenemos HP)
        if ctx.player.manaPct < 30 and ctx.player.healthPct > 50 and self:IsSpellLearned("Life Tap") then
            return {action = "CAST", spell = "Life Tap", priority = self.Priority.FILLER, reason = "Life Tap (moviendo)"}
        end
        -- En movimiento sin instants disponibles: no sugerir nada
        -- El jugador debe detenerse para usar Shadow Bolt
        return nil
    end
    
    -- QUIETO: podemos usar hechizos con cast time
    
    -- EXECUTE PHASE: Priorizar Shadowburn o Shadow Bolt
    if ctx.target.healthPct < self.Config.targetExecute then
        -- Shadowburn es instant y hace buen daño en execute
        if self:IsSpellLearned("Shadowburn") and not self:IsSpellOnCooldown("Shadowburn") then
            return {action = "CAST", spell = "Shadowburn", priority = self.Priority.FILLER, reason = "Shadowburn (execute)"}
        end
        -- Drain Soul para farmear shards si el mob va a morir
        if ctx.target.healthPct < 10 and self:IsSpellLearned("Drain Soul") then
            local shards = WCS_BrainCore and WCS_BrainCore.State.soulShards or 0
            if shards < 5 then
                return {action = "CAST", spell = "Drain Soul", priority = self.Priority.FILLER, reason = "Drain Soul (shard)"}
            end
        end
    end
    
    -- Shadow Bolt - filler principal
    if ctx.player.manaPct > self.Config.manaCritical and self:IsSpellLearned("Shadow Bolt") then
        return {action = "CAST", spell = "Shadow Bolt", priority = self.Priority.FILLER, reason = "Shadow Bolt"}
    end
    
    -- Sin mana: usar Wand
    return {action = "CAST", spell = "Shoot", priority = self.Priority.FILLER, reason = "Wand (sin mana)"}
end

function WCS_Brain:CheckMana()
    local ctx = self.Context
    if ctx.player.manaPct >= self.Config.manaLow then return nil end
    
    if self.Config.useDarkPact and ctx.pet.exists and ctx.pet.manaPct > 30 then
        return {action = "CAST", spell = "Dark Pact", priority = self.Priority.MANA, reason = "Dark Pact"}
    end
    
    if self.Config.useLifeTap and ctx.player.healthPct > self.Config.lifeTapMinHealth then
        return {action = "CAST", spell = "Life Tap", priority = self.Priority.MANA, reason = "Life Tap"}
    end
    return nil
end

-- ============================================================================
-- DECISION PRINCIPAL
-- ============================================================================

-- Valida que una decision tenga un hechizo aprendido
function WCS_Brain:ValidateDecision(decision)
    if not decision then return nil end
    
    -- Si es accion de item, no necesita validacion de spellbook
    if decision.action == "USE_ITEM" then
        return decision
    end
    
    -- Si es habilidad de mascota, verificar que la mascota exista
    if decision.action == "PET_ABILITY" then
        if UnitExists("pet") then
            return decision
        end
        debugPrint("Mascota no existe para: " .. (decision.spell or "?"))
        return nil
    end
    
    -- Verificar que el hechizo este aprendido
    if decision.spell and not self:IsSpellLearned(decision.spell) then
        debugPrint("Hechizo NO aprendido: " .. decision.spell)
        return nil
    end
    
    return decision
end

-- Verifica si un hechizo se ha sugerido demasiadas veces seguidas
function WCS_Brain:IsSuggestionStuck(spellName)
    local ls = self.LastSuggestion
    local now = getTime()
    
    -- Si ha pasado mucho tiempo, resetear
    if (now - ls.time) > ls.timeout then
        return false
    end
    
    -- Si es el mismo hechizo y se ha sugerido muchas veces
    if ls.spell == spellName and ls.count >= ls.maxRepeats then
        return true
    end
    
    return false
end

-- Registra una sugerencia
function WCS_Brain:TrackSuggestion(spellName)
    local ls = self.LastSuggestion
    local now = getTime()
    
    -- Si ha pasado mucho tiempo o es diferente hechizo, resetear
    if (now - ls.time) > ls.timeout or ls.spell ~= spellName then
        ls.spell = spellName
        ls.count = 1
        ls.time = now
    else
        -- Mismo hechizo, incrementar contador
        ls.count = ls.count + 1
        ls.time = now
    end
end

-- Resetea el tracking cuando un hechizo se lanza exitosamente
function WCS_Brain:ResetSuggestionTracking()
    self.LastSuggestion.spell = nil
    self.LastSuggestion.count = 0
    self.LastSuggestion.time = 0
end

function WCS_Brain:GetNextAction()
    if not self.ENABLED then return nil end
    self:UpdateContext()
    
    -- Solo bloquear si estamos CASTEANDO (no por GCD)
    -- Esto permite seguir sugiriendo hechizos mientras el GCD esta activo
    if self.Context.player.isCasting then return nil end
    if WCS_BrainCore and WCS_BrainCore:IsCasting() then return nil end
    
    -- Asegurar que el spellbook este escaneado
    self:ScanSpellbook()
    
    local decision = nil
    local skipSpell = nil
    
    -- Si un hechizo se ha sugerido muchas veces sin exito, saltarlo temporalmente
    if self.LastSuggestion.spell and self:IsSuggestionStuck(self.LastSuggestion.spell) then
        skipSpell = self.LastSuggestion.spell
        debugPrint("Saltando hechizo atascado: " .. skipSpell)
    end
    
    -- Funcion auxiliar para validar y verificar si debemos saltar
    local function validateAndCheck(dec)
        dec = self:ValidateDecision(dec)
        if dec and dec.spell == skipSpell then
            return nil -- Saltar este hechizo
        end
        return dec
    end
    
    -- Cada decision se valida antes de retornarla
    -- PRIORIDAD 1: EMERGENCIA (HP critico)
    decision = validateAndCheck(self:CheckEmergency())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 2: INTERRUPT (casters enemigos)
    decision = validateAndCheck(self:CheckInterrupt())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 3: DEFENSIVO (HP bajo)
    decision = validateAndCheck(self:CheckDefensive())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 4: SALVAR MASCOTA
    decision = validateAndCheck(self:CheckPetSave())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 5: ACCIONES DE MASCOTA (legacy, ahora PetAI es autonoma)
    decision = validateAndCheck(self:CheckPetActions())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 6: SINERGIAS (Dark Pact, Health Funnel, Drain Mana)
    decision = validateAndCheck(self:CheckPetSynergy())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 7: DoTs (Corruption, CoA, Siphon Life, Immolate)
    decision = validateAndCheck(self:CheckDoTs())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 8: CURSE (si no tiene DoTs con curse)
    decision = validateAndCheck(self:CheckCurse())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 9: FILLER (Shadow Bolt, Wand)
    decision = validateAndCheck(self:CheckFiller())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    -- PRIORIDAD 10: MANA (Life Tap, Dark Pact)
    decision = validateAndCheck(self:CheckMana())
    if decision then self:TrackSuggestion(decision.spell) return decision end
    
    return nil
end

function WCS_Brain:Execute()
    local action = self:GetNextAction()

    if not action then
        if self.DEBUG and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Brain]|r No action selected by GetNextAction()")
        end
        return false
    end

    -- Validar la decision antes de ejecutar (puede venir de hooks externos)
    local validAction = self:ValidateDecision(action)
    if not validAction then
        if self.DEBUG and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Brain]|r Decision invalida o hechizo no aprendido: " .. tostring(action.spell or "nil"))
        end
        return false
    end

    if not WCS_BrainCore then
        if self.DEBUG and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r WCS_BrainCore no disponible para ejecutar accion")
        end
        return false
    end

    -- Registrar intento de casteo
    if validAction.spell and validAction.action == "CAST" then
        self.LastCastAttempt = validAction.spell
    end

    -- Ejecutar de forma segura usando pcall para evitar rompimientos en runtime
    local ok, result = pcall(function()
        return WCS_BrainCore:ExecuteAction(validAction)
    end)
    if not ok then
        if self.DEBUG and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r Error al ejecutar accion: " .. tostring(result))
        end
        return false
    end
    return result
end

-- ============================================================================
-- FUNCIONES DE MASCOTA
-- ============================================================================
function WCS_Brain:InitPetPersonality()
    if not UnitExists("pet") then return end
    local personalities = {"Timido", "Agresivo", "Protector", "Sabio", "Rebelde"}
    self.Pet.State.personalityType = personalities[math.random(1, 5)]
    debugPrint("Personalidad: " .. self.Pet.State.personalityType)
end

function WCS_Brain:GetPetChatResponse(situation)
    local responses = self.Pet.ChatResponses[self.Pet.State.personalityType]
    if not responses or not responses[situation] then return nil end
    local list = responses[situation]
    local count = WCS_TableCount(list)
    if count == 0 then return nil end
    return list[math.random(1, count)]
end

function WCS_Brain:PetSay(situation)
    if not UnitExists("pet") then return end
    local msg = self:GetPetChatResponse(situation)
    if msg then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[" .. (UnitName("pet") or "Pet") .. "]|r " .. msg)
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSBRAIN1 = "/brain"
SlashCmdList["WCSBRAIN"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "on" then
        WCS_Brain.ENABLED = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r ACTIVADO")
    elseif cmd == "off" then
        WCS_Brain.ENABLED = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r DESACTIVADO")
    elseif cmd == "debug" then
        WCS_Brain.DEBUG = not WCS_Brain.DEBUG
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Brain]|r Debug: " .. (WCS_Brain.DEBUG and "ON" or "OFF"))
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Brain]|r v" .. WCS_Brain.VERSION .. " | Fase: " .. WCS_Brain.Context.phase)
    elseif cmd == "cast" then
        WCS_Brain:Execute()
    elseif cmd == "scan" or cmd == "refresh" then
        WCS_Brain:RefreshSpellbook()
    elseif cmd == "spells" then
        WCS_Brain:RefreshSpellbook()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Brain]|r Hechizos aprendidos:")
        for name, data in pairs(WCS_Brain.LearnedSpells) do
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. name .. " (" .. (data.rank or "?") .. ")")
        end
    elseif cmd == "cd" or cmd == "cooldowns" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Brain]|r Cooldowns activos:")
        local hasCDs = false
        for spell, cdEnd in pairs(WCS_Brain.Cooldowns) do
            local remaining = cdEnd - getTime()
            if remaining > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  - " .. spell .. ": " .. math.floor(remaining) .. "s")
                hasCDs = true
            end
        end
        if not hasCDs then
            DEFAULT_CHAT_FRAME:AddMessage("  (ninguno)")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[Brain]|r /brain on|off|debug|status|cast|scan|spells|cd")
    end
end

SLASH_WCSPET1 = "/brainpet"
SLASH_WCSPET2 = "/pet"
SlashCmdList["WCSPET"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "on" then
        WCS_Brain.PetAI.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r IA de mascota ACTIVADA")
    elseif cmd == "off" then
        WCS_Brain.PetAI.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r IA de mascota DESACTIVADA")
    elseif cmd == "debug" then
        WCS_Brain.PetAI.debug = not WCS_Brain.PetAI.debug
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r Debug: " .. (WCS_Brain.PetAI.debug and "ON" or "OFF"))
    elseif cmd == "status" then
        local status = WCS_Brain.PetAI.enabled and "ACTIVA" or "INACTIVA"
        local petType = WCS_Brain.Context.pet.type or "ninguna"
        local lastAbility = WCS_Brain.PetAI.lastAbility or "ninguna"
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r Estado: " .. status)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r Mascota: " .. petType)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r Ultima habilidad: " .. lastAbility)
    elseif cmd == "p" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[Pet]|r Personalidad: " .. WCS_Brain.Pet.State.personalityType)
    elseif cmd == "init" then
        WCS_Brain:InitPetPersonality()
    elseif cmd == "say" then
        WCS_Brain:PetSay("idle")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[PetAI]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainpet on|off - Activar/desactivar IA")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainpet debug - Toggle debug")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainpet status - Ver estado")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainpet p|init|say - Personalidad")
    end
end

-- ============================================================================
-- EVENTOS PARA DETECTAR CAMBIOS DE TALENTOS/HECHIZOS Y COOLDOWNS
-- ============================================================================
WCS_Brain.EventFrame = CreateFrame("Frame", "WCS_BrainEventFrame", UIParent)
WCS_Brain.EventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
WCS_Brain.EventFrame:RegisterEvent("SPELLS_CHANGED")
WCS_Brain.EventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
WCS_Brain.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
WCS_Brain.EventFrame:RegisterEvent("PET_BAR_UPDATE")
WCS_Brain.EventFrame:RegisterEvent("SPELLCAST_STOP")
WCS_Brain.EventFrame:RegisterEvent("SPELLCAST_SUCCEEDED")
WCS_Brain.EventFrame:RegisterEvent("SPELLCAST_FAILED")
WCS_Brain.EventFrame:RegisterEvent("SPELLCAST_INTERRUPTED")

-- Variable para trackear el ultimo hechizo que se intento castear
WCS_Brain.LastCastAttempt = nil

WCS_Brain.EventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Escanear al entrar al mundo
        WCS_Brain.SpellCache.lastUpdate = 0
        WCS_Brain:ScanSpellbook()
        WCS_Brain:CleanupCooldowns()
        debugPrint("Spellbook escaneado al entrar")
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" then
        -- Nuevo hechizo aprendido o cambio de hechizos
        WCS_Brain.SpellCache.lastUpdate = 0
        WCS_Brain:ScanSpellbook()
        debugPrint("Spellbook actualizado: nuevo hechizo")
    elseif event == "CHARACTER_POINTS_CHANGED" then
        -- Cambio de talentos
        WCS_Brain.SpellCache.lastUpdate = 0
        WCS_Brain:ScanSpellbook()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Talentos cambiados - Spellbook actualizado")
    elseif event == "PET_BAR_UPDATE" then
        -- Mascota invocada/cambiada
        debugPrint("Mascota actualizada")
    elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_SUCCEEDED" then
        -- Hechizo lanzado exitosamente - registrar cooldown
        if WCS_Brain.LastCastAttempt then
            WCS_Brain:RegisterSpellCast(WCS_Brain.LastCastAttempt)
            debugPrint("Hechizo completado: " .. WCS_Brain.LastCastAttempt)
            WCS_Brain.LastCastAttempt = nil
        end
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        -- Hechizo fallido - no registrar cooldown
        if WCS_Brain.LastCastAttempt then
            debugPrint("Hechizo fallido: " .. WCS_Brain.LastCastAttempt)
            WCS_Brain.LastCastAttempt = nil
        end
    end
end)

-- Escaneo inicial al cargar
WCS_Brain:ScanSpellbook()

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_Brain]|r v" .. WCS_Brain.VERSION .. " Cerebro Unificado + PetAI Autonoma cargado")

-- Fallback: asegurar que el comando /wcshotfix631 esté disponible aun si el hotfix no cargó
if not SlashCmdList then SlashCmdList = {} end
if not SlashCmdList["WCSHOTFIX631"] then
    SlashCmdList["WCSHOTFIX631"] = function(msg)
        local m = string.lower(msg or "")
        if m == "verify" then
            if WCS_HotFix_v631 and WCS_HotFix_v631.VerifyFixes then
                local issues = WCS_HotFix_v631:VerifyFixes()
                if WCS_TableCount(issues) == 0 then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS HotFix v6.3.1]|r ✓ Todas las correcciones funcionan correctamente")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS HotFix v6.3.1]|r ✗ Se encontraron " .. WCS_TableCount(issues) .. " problemas:")
                    for i = 1, WCS_TableCount(issues) do
                        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFF0000- " .. issues[i] .. "|r")
                    end
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS HotFix v6.3.1]|r No cargado o no disponible")
            end
        elseif m == "reapply" then
            if WCS_HotFix_v631 and WCS_HotFix_v631.Apply then
                WCS_HotFix_v631.applied = false
                WCS_HotFix_v631:Apply()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS HotFix v6.3.1]|r No cargado: no se puede reaplicar")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS HotFix v6.3.1]|r Comandos disponibles:")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/wcshotfix631 verify|r - Verificar correcciones")
            DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/wcshotfix631 reapply|r - Reaplicar correcciones")
        end
    end
    SLASH_WCSHOTFIX631_1 = "/wcshotfix631"
    SLASH_WCSHOTFIX631_2 = "/wcshotfix"
end

-- Resetea la memoria principal del módulo WCS_Brain
function WCS_Brain:ResetMemory()
    -- Limpiar variables globales y de instancia
    WCS_Brain.LearnedSpells = {}
    WCS_Brain.SpellCache = { lastUpdate = 0, updateInterval = 5 }
    WCS_Brain.Cooldowns = {}
    self.LearnedSpells = WCS_Brain.LearnedSpells
    self.SpellCache = WCS_Brain.SpellCache
    self.Cooldowns = WCS_Brain.Cooldowns
    self.SpellIndexCache = {}
    self.Context = {
        lastUpdate = 0,
        updateInterval = 0.1,
        player = { health = 100, healthMax = 100, healthPct = 100, mana = 100, manaMax = 100, manaPct = 100, inCombat = false, isCasting = false, isMoving = false },
        target = { exists = false, health = 0, healthPct = 100, isHostile = false, isDead = false, classification = "normal" },
        pet = { exists = false, health = 0, healthPct = 100, mana = 0, manaPct = 100, type = nil }
    }
    if self.Pet and self.Pet.State then
        self.Pet.State.personalityType = "Protector"
        self.Pet.State.emotions = {joy = 50, fear = 0, anger = 0}
        self.Pet.State.mood = {happiness = 75, stress = 0, energy = 100}
        self.Pet.State.lastMoodUpdate = 0
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Memoria principal reseteada.")
end

