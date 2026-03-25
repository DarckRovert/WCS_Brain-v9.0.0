--[[
    WCS_BrainState.lua - Captura de Estado para DQN
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    v2.1 - Corregida deteccion de DoTs usando texturas reales
    No depende de WCS_Brain.Context
]]--

WCS_BrainState = WCS_BrainState or {}
WCS_BrainState.VERSION = "6.6.0"

-- ============================================================================
-- FUNCIONES AUXILIARES (Lua 5.0 compatible)
-- ============================================================================
local function SafeDivide(a, b)
    if not b or b == 0 then return 0 end
    return a / b
end

local function GetUnitHealthPercent(unit)
    if not UnitExists(unit) then return 0 end
    local max = UnitHealthMax(unit) or 1
    local cur = UnitHealth(unit) or 0
    if max == 0 then return 0 end
    return cur / max
end

local function GetUnitManaPercent(unit)
    if not UnitExists(unit) then return 0 end
    local max = UnitManaMax(unit) or 1
    local cur = UnitMana(unit) or 0
    if max == 0 then return 0 end
    return cur / max
end

-- Contar Soul Shards en el inventario
local function CountSoulShards()
    local count = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots then
            for slot = 1, slots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    if string.find(itemLink, "Soul Shard") or string.find(itemLink, "Fragmento de alma") then
                        local _, itemCount = GetContainerItemInfo(bag, slot)
                        count = count + (itemCount or 1)
                    end
                end
            end
        end
    end
    return count
end

-- Verificar si tenemos Healthstone
local function HasHealthstone()
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots then
            for slot = 1, slots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    if string.find(itemLink, "Healthstone") or string.find(itemLink, "Piedra de salud") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- DETECCION DE DEBUFFS (Corregida para texturas reales de Vanilla)
-- ============================================================================
-- Las texturas de WoW Vanilla son rutas como:
-- Interface\\Icons\\Spell_Shadow_AbominationExplosion (Corruption)
-- Interface\\Icons\\Spell_Shadow_CurseOfSargeras (Curse of Agony)
-- Interface\\Icons\\Spell_Fire_Immolation (Immolate)

local WARLOCK_DEBUFF_TEXTURES = {
    corruption = {"abominationexplosion", "unholystrength"},
    agony = {"curseofsargeras", "curseofmannoroth"},
    immolate = {"immolation", "immolate"},
    siphonlife = {"siphonlife", "requiem", "hauntingspirits"},
    curse = {"curse", "tongues", "weakness", "recklessness", "elements", "shadow", "doom", "exhaustion"},
    fear = {"fear", "possession", "deathcoil"},
}

-- Verificar si el target tiene un debuff especifico
local function HasDebuff(unit, debuffName)
    if not UnitExists(unit) then return false end
    
    -- Obtener los patrones de textura para este debuff
    local patterns = WARLOCK_DEBUFF_TEXTURES[debuffName]
    if not patterns then
        patterns = {debuffName}
    end
    
    for i = 1, 16 do
        local texture = UnitDebuff(unit, i)
        if not texture then break end
        local textureLower = string.lower(texture)
        
        -- Buscar cualquiera de los patrones (Lua 5.0 compatible)
        for j = 1, WCS_TableCount(patterns) do
            local pattern = patterns[j]
            if string.find(textureLower, pattern) then
                return true
            end
        end
    end
    return false
end

-- Verificar si el jugador tiene un buff
local function HasBuff(unit, textureName)
    if not UnitExists(unit) then return false end
    for i = 1, 32 do
        local texture = UnitBuff(unit, i)
        if not texture then break end
        if string.find(string.lower(texture), textureName) then
            return true
        end
    end
    return false
end

-- Detectar tipo de mascota (v2.0 - incluye demonios mayores)
-- Valores: Imp=0.2, Voidwalker=0.4, Succubus=0.6, Felhunter=0.8, Felguard=0.85, Infernal=0.9, Doomguard=1.0
local function GetPetType()
    if not UnitExists("pet") then return 0 end
    
    -- Primero verificar si es un demonio mayor usando WCS_BrainMajorDemons
    if WCS_BrainMajorDemons_IsMajorDemon then
        if WCS_BrainMajorDemons_IsMajorDemon() then
            local demonType = WCS_BrainMajorDemons_GetDemonType()
            if demonType == "Infernal" then return 0.9 end
            if demonType == "Doomguard" then return 1.0 end
        end
    end
    
    -- Detectar por habilidades en la barra de mascota
    local i = 1
    while i <= 10 do
        local name = GetPetActionInfo(i)
        if name then
            -- Imp (Fire Bolt, Blood Pact, Fire Shield)
            if name == "Fire Bolt" or name == "Descarga de Fuego" then return 0.2 end
            if name == "Blood Pact" or name == "Pacto de Sangre" then return 0.2 end
            
            -- Voidwalker (Torment, Sacrifice, Suffering)
            if name == "Torment" or name == "Tormento" then return 0.4 end
            if name == "Sacrifice" or name == "Sacrificio" then return 0.4 end
            
            -- Succubus (Lash of Pain, Seduction)
            if name == "Lash of Pain" or name == "Latigo de Dolor" then return 0.6 end
            if name == "Seduction" or name == "Seduccion" then return 0.6 end
            
            -- Felhunter (Spell Lock, Devour Magic)
            if name == "Spell Lock" or name == "Bloqueo de Hechizo" then return 0.8 end
            if name == "Devour Magic" or name == "Devorar Magia" then return 0.8 end
            
            -- Felguard (Cleave, Intercept, Anguish)
            if name == "Cleave" or name == "Hender" then return 0.85 end
            if name == "Intercept" or name == "Interceptar" then return 0.85 end
            if name == "Anguish" or name == "Angustia" then return 0.85 end
            
            -- Infernal (Immolation)
            if name == "Immolation" or name == "Inmolacion" then return 0.9 end
            
            -- Doomguard (War Stomp, Cripple, Rain of Fire)
            if name == "War Stomp" or name == "Pisoteo de Guerra" then return 1.0 end
            if name == "Cripple" or name == "Tullir" then return 1.0 end
            if name == "Rain of Fire" or name == "Lluvia de Fuego" then return 1.0 end
        end
        i = i + 1
    end
    
    -- Fallback: verificar si no tiene mana (posible demonio mayor)
    local petMana = UnitManaMax("pet")
    if petMana and petMana == 0 then
        return 0.9 -- Asumir Infernal por defecto
    end
    
    return 0.5 -- Desconocido
end

-- ============================================================================
-- CAPTURA DE ESTADO COMPLETO (50 valores)
-- ============================================================================
function WCS_BrainState:CaptureState()
    local state = {}
    
    -- ========== PLAYER (10 valores) ==========
    state[1] = GetUnitHealthPercent("player")
    state[2] = GetUnitManaPercent("player")
    state[3] = UnitAffectingCombat("player") and 1 or 0
    
    local isCasting = 0
    if CastingBarFrame and CastingBarFrame:IsVisible() then isCasting = 1 end
    if ChannelBarFrame and ChannelBarFrame:IsVisible() then isCasting = 1 end
    state[4] = isCasting
    
    local onGCD = 0
    if WCS_BrainCore and WCS_BrainCore.IsOnGCD then
        onGCD = WCS_BrainCore:IsOnGCD() and 1 or 0
    end
    state[5] = onGCD
    
    state[6] = (UnitLevel("player") or 60) / 60
    state[7] = math.min(CountSoulShards() / 5, 1)
    
    local hasAggro = 0
    if UnitExists("target") and UnitExists("targettarget") then
        if UnitIsUnit("targettarget", "player") then hasAggro = 1 end
    end
    state[8] = hasAggro
    state[9] = HasHealthstone() and 1 or 0
    
    local petAlive = 0
    if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then petAlive = 1 end
    state[10] = petAlive
    
    -- ========== TARGET (10 valores) ==========
    state[11] = GetUnitHealthPercent("target")
    state[12] = UnitExists("target") and 1 or 0
    
    local canAttack = 0
    if UnitExists("target") and UnitCanAttack("player", "target") then canAttack = 1 end
    state[13] = canAttack
    
    local targetDead = 0
    if UnitExists("target") and UnitIsDeadOrGhost("target") then targetDead = 1 end
    state[14] = targetDead
    
    local targetHasMana = 0
    if UnitExists("target") and (UnitManaMax("target") or 0) > 0 then targetHasMana = 1 end
    state[15] = targetHasMana
    
    local isElite = 0
    if UnitExists("target") then
        local class = UnitClassification("target")
        if class == "elite" or class == "rareelite" or class == "worldboss" then isElite = 1 end
    end
    state[16] = isElite
    
    local levelDiff = 0
    if UnitExists("target") then
        local playerLevel = UnitLevel("player") or 60
        local targetLevel = UnitLevel("target") or playerLevel
        levelDiff = (targetLevel - playerLevel) / 10
        levelDiff = math.max(-1, math.min(1, levelDiff))
    end
    state[17] = (levelDiff + 1) / 2
    
    local targetLowHP = 0
    if UnitExists("target") and GetUnitHealthPercent("target") < 0.25 then targetLowHP = 1 end
    state[18] = targetLowHP
    state[19] = GetUnitManaPercent("target")
    
    local targetCasting = 0
    if TargetFrameSpellBar and TargetFrameSpellBar:IsVisible() then targetCasting = 1 end
    state[20] = targetCasting
    
    -- ========== DEBUFFS EN TARGET (10 valores) ==========
    state[21] = HasDebuff("target", "corruption") and 0.7 or 0
    state[22] = HasDebuff("target", "agony") and 0.7 or 0
    state[23] = HasDebuff("target", "immolate") and 0.7 or 0
    state[24] = HasDebuff("target", "siphonlife") and 0.7 or 0
    state[25] = HasDebuff("target", "curse") and 1 or 0
    state[26] = HasDebuff("target", "fear") and 0.7 or 0
    
    local dotCount = 0
    if state[21] > 0 then dotCount = dotCount + 1 end
    if state[22] > 0 then dotCount = dotCount + 1 end
    if state[23] > 0 then dotCount = dotCount + 1 end
    if state[24] > 0 then dotCount = dotCount + 1 end
    state[27] = dotCount / 4
    -- Movement flag (compatible con WCS_BrainCore:IsMoving)
    local isMoving = 0
    if WCS_BrainCore and WCS_BrainCore.IsMoving then
        if WCS_BrainCore:IsMoving() then isMoving = 1 end
    end
    state[28] = isMoving
    state[29] = 0
    state[30] = 0
    
    -- ========== BUFFS DEL JUGADOR (5 valores) ==========
    state[31] = HasBuff("player", "shadowtrance") and 1 or 0
    local hasArmor = HasBuff("player", "demonarmor") or HasBuff("player", "demonskin")
    state[32] = hasArmor and 1 or 0
    state[33] = 0
    state[34] = HasBuff("player", "sacrifice") and 1 or 0
    state[35] = HasBuff("player", "soullink") and 1 or 0
    
    -- ========== PET (5 valores) ==========
    state[36] = GetUnitHealthPercent("pet")
    state[37] = GetUnitManaPercent("pet")
    state[38] = GetPetType()
    local petInCombat = 0
    if UnitExists("pet") and UnitAffectingCombat("pet") then petInCombat = 1 end
    state[39] = petInCombat
    local canDarkPact = 0
    if UnitExists("pet") and GetUnitManaPercent("pet") > 0.2 then canDarkPact = 1 end
    state[40] = canDarkPact
    
    -- ========== SITUACION (10 valores) ==========
    state[41] = (state[2] < 0.3) and 1 or 0
    state[42] = (state[1] < 0.35) and 1 or 0
    state[43] = (state[1] < 0.2) and 1 or 0
    state[44] = (state[2] > 0.7) and 1 or 0
    state[45] = (state[11] > 0.7) and 1 or 0
    state[46] = (state[11] > 0.3 and state[11] <= 0.7) and 1 or 0
    local needLifeTap = 0
    if state[2] < 0.4 and state[1] > 0.5 then needLifeTap = 1 end
    state[47] = needLifeTap
    local needDarkPact = 0
    if state[2] < 0.4 and state[40] > 0 then needDarkPact = 1 end
    state[48] = needDarkPact
    local emergency = 0
    if state[1] < 0.25 or (state[10] > 0 and state[36] < 0.2) then emergency = 1 end
    state[49] = emergency
    state[50] = (dotCount >= 3) and 1 or 0
    
    -- Validar 50 valores
    for i = 1, 50 do
        if not state[i] then state[i] = 0 end
        state[i] = math.max(0, math.min(1, state[i]))
    end
    
    return state
end

-- ============================================================================
-- DEBUG
-- ============================================================================
function WCS_BrainState:PrintState(state)
    if not state then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[State]|r HP=" .. string.format("%.0f%%", state[1]*100) .. 
        " Mana=" .. string.format("%.0f%%", state[2]*100) ..
        " TgtHP=" .. string.format("%.0f%%", state[11]*100) ..
        " DoTs=" .. string.format("%.0f", state[27]*4))
end

-- Comando para ver las texturas de debuffs del target (debug)
SLASH_DEBUGDEBUFFS1 = "/debugdebuffs"
SlashCmdList["DEBUGDEBUFFS"] = function(msg)
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Debug]|r No target")
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Debug]|r Debuffs en target:")
    for i = 1, 16 do
        local texture = UnitDebuff("target", i)
        if not texture then break end
        DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ": " .. texture)
    end
end

SLASH_BRAINSTATE1 = "/brainstate"
SlashCmdList["BRAINSTATE"] = function(msg)
    local state = WCS_BrainState:CaptureState()
    WCS_BrainState:PrintState(state)
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS_BrainState]|r v" .. WCS_BrainState.VERSION .. " cargado")

