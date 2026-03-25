-- WCS_BrainSmartAI.lua
-- Sistema de IA Ultra-Inteligente para WCS_Brain
-- Mejora las decisiones del addon con análisis avanzado de combate

WCS_BrainSmartAI = {}

-- ============================================
-- CONFIGURACIÓN Y CONSTANTES
-- ============================================

local SMART_AI_VERSION = "6.7.0"
local DEBUG_MODE = false

-- Constantes de combate
local GLOBAL_COOLDOWN = 1.5
local CAST_TIME_BUFFER = 0.3
local THREAT_THRESHOLD_HIGH = 80
local THREAT_THRESHOLD_MEDIUM = 60

-- Pesos para scoring de hechizos
WCS_BrainSmartAI.Weights = {
    DPS = 1.0,              -- Daño por segundo
    EFFICIENCY = 0.8,       -- Daño por mana
    THREAT = 0.6,           -- Generación de amenaza
    UTILITY = 0.7,          -- Utilidad (CC, debuffs)
    URGENCY = 1.2,          -- Urgencia de la situación
    SURVIVABILITY = 1.5     -- Supervivencia del jugador
}

-- Cache de datos de combate
local CombatCache = {
    lastUpdate = 0,
    targetHealth = {},
    targetDPS = {},
    encounterStart = 0,
    spellHistory = {},
    manaHistory = {},
    threatHistory = {},
    playerThreat = 0,  -- Amenaza acumulada del jugador
    lastThreatReset = 0
}

-- Tabla de multiplicadores de amenaza por stance/forma
local THREAT_MULTIPLIERS = {
    ["Defensive Stance"] = 1.3,
    ["Bear Form"] = 1.3,
    ["Dire Bear Form"] = 1.3,
    ["Righteous Fury"] = 1.6
}

-- Tabla de amenaza base por tipo de hechizo
local SPELL_THREAT_MODIFIERS = {
    -- Hechizos de alto aggro
    ["Taunt"] = 1000,
    ["Growl"] = 1000,
    ["Mocking Blow"] = 500,
    ["Challenging Shout"] = 1000,
    ["Challenging Roar"] = 1000,
    
    -- Hechizos de daño con amenaza extra
    ["Sunder Armor"] = 260,
    ["Revenge"] = 355,
    ["Shield Slam"] = 250,
    ["Heroic Strike"] = 145,
    ["Maul"] = 322,
    ["Swipe"] = 260,
    
    -- Hechizos que reducen amenaza
    ["Feint"] = -600,
    ["Fade"] = -1000,
    ["Vanish"] = -2000,
    
    -- Curación (50% de la cantidad curada)
    ["Flash Heal"] = 0.5,
    ["Greater Heal"] = 0.5,
    ["Healing Touch"] = 0.5,
    ["Holy Light"] = 0.5,
    ["Chain Heal"] = 0.5,
    ["Prayer of Healing"] = 0.5,
    
    -- Daño directo (100% del daño)
    ["Fireball"] = 1.0,
    ["Frostbolt"] = 1.0,
    ["Shadow Bolt"] = 1.0,
    ["Lightning Bolt"] = 1.0,
    ["Wrath"] = 1.0,
    ["Starfire"] = 1.0,
    ["Mind Blast"] = 1.0,
    ["Smite"] = 1.0,
    
    -- DoTs (100% del daño total)
    ["Corruption"] = 1.0,
    ["Curse of Agony"] = 1.0,
    ["Immolate"] = 1.0,
    ["Moonfire"] = 1.0,
    ["Insect Swarm"] = 1.0,
    ["Shadow Word: Pain"] = 1.0,
    ["Flame Shock"] = 1.0,
    
    -- AoE (amenaza dividida)
    ["Blizzard"] = 0.8,
    ["Rain of Fire"] = 0.8,
    ["Flamestrike"] = 0.8,
    ["Consecration"] = 0.8,
    ["Hurricane"] = 0.8,
    
    -- Buffs/Debuffs (amenaza fija baja)
    ["Power Word: Fortitude"] = 20,
    ["Mark of the Wild"] = 20,
    ["Arcane Intellect"] = 20,
    ["Blessing of Might"] = 20
}

-- ============================================
-- FUNCIONES DE ANÁLISIS DE OBJETIVO
-- ============================================

-- Predice cuánto tiempo tardará en morir el objetivo
function WCS_BrainSmartAI:PredictTimeToKill(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then
        return 0
    end
    
    local currentHP = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    local currentTime = GetTime()
    
    -- Inicializar cache si es necesario
    if not CombatCache.targetHealth[unit] then
        CombatCache.targetHealth[unit] = {
            {time = currentTime, hp = currentHP}
        }
        return 999 -- No hay suficientes datos
    end
    
    -- Agregar punto de datos actual
    table.insert(CombatCache.targetHealth[unit], {time = currentTime, hp = currentHP})
    
    -- Mantener solo los últimos 10 segundos de datos
    local history = CombatCache.targetHealth[unit]
    while table.getn(history) > 0 and (currentTime - history[1].time) > 10 do
        table.remove(history, 1)
    end
    
    -- Necesitamos al menos 2 puntos de datos
    if table.getn(history) < 2 then
        return 999
    end
    
    -- Calcular DPS promedio
    local oldestData = history[1]
    local newestData = history[table.getn(history)]
    local timeDiff = newestData.time - oldestData.time
    local hpDiff = oldestData.hp - newestData.hp
    
    if timeDiff <= 0 or hpDiff <= 0 then
        return 999
    end
    
    local dps = hpDiff / timeDiff
    local timeToKill = currentHP / dps
    
    -- Guardar DPS para uso posterior
    CombatCache.targetDPS[unit] = dps
    
    return timeToKill
end

-- Calcula el valor de usar DoTs en el objetivo
function WCS_BrainSmartAI:CalculateDotValue(unit, dotDuration, dotDamage)
    local ttk = self:PredictTimeToKill(unit)
    
    if ttk < dotDuration * 0.3 then
        -- Objetivo morirá muy pronto, DoT no vale la pena
        return 0
    elseif ttk < dotDuration then
        -- DoT se aprovechará parcialmente
        return (ttk / dotDuration) * dotDamage
    else
        -- DoT se aprovechará completamente
        return dotDamage
    end
end

-- Analiza la salud del objetivo y recomienda estrategia
function WCS_BrainSmartAI:AnalyzeTargetHealth(unit)
    if not UnitExists(unit) then
        return "none"
    end
    
    local healthPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
    local ttk = self:PredictTimeToKill(unit)
    
    if healthPercent < 20 then
        return "execute" -- Fase de ejecución
    elseif healthPercent < 35 and ttk < 15 then
        return "burst" -- Burst final
    elseif ttk > 30 then
        return "sustained" -- Combate prolongado
    else
        return "normal" -- Combate normal
    end
end

-- ============================================
-- FUNCIONES DE GESTIÓN DE RECURSOS
-- ============================================

-- Predice el mana disponible en X segundos
function WCS_BrainSmartAI:PredictManaIn(seconds)
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local currentTime = GetTime()
    
    -- Calcular regeneración de mana
    local spirit = UnitStat("player", 5) -- Spirit
    local intellect = UnitStat("player", 4) -- Intellect
    
    -- Fórmula aproximada de regeneración de mana (varía por clase)
    local manaRegen = (spirit / 5) + (intellect * 0.1)
    
    -- Si estamos en combate, la regeneración es menor
    if UnitAffectingCombat("player") then
        manaRegen = manaRegen * 0.3
    end
    
    local predictedMana = currentMana + (manaRegen * seconds)
    return math.min(predictedMana, maxMana)
end

-- Calcula si podemos permitirnos gastar mana en un hechizo
function WCS_BrainSmartAI:CanAffordSpell(spellCost, priority)
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercent = (currentMana / maxMana) * 100
    
    -- Si tenemos mucho mana, siempre podemos
    if manaPercent > 70 then
        return true
    end
    
    -- Si tenemos poco mana, solo hechizos de alta prioridad
    if manaPercent < 30 then
        return priority == "high" or priority == "emergency"
    end
    
    -- Calcular si tendremos suficiente mana después
    local manaAfterCast = currentMana - spellCost
    local manaIn10Sec = self:PredictManaIn(10)
    
    -- Asegurarnos de que no nos quedemos sin mana
    if manaAfterCast < (maxMana * 0.15) then
        return priority == "emergency"
    end
    
    return true
end

-- Recomienda estrategia de mana basada en el contexto
function WCS_BrainSmartAI:GetManaStrategy()
    local manaPercent = (UnitMana("player") / UnitManaMax("player")) * 100
    local ttk = self:PredictTimeToKill("target")
    local inCombat = UnitAffectingCombat("player")
    
    if not inCombat then
        return "conserve" -- Conservar fuera de combate
    end
    
    if manaPercent < 20 then
        return "emergency" -- Modo emergencia
    elseif manaPercent < 40 and ttk > 20 then
        return "conserve" -- Conservar en combate largo
    elseif manaPercent > 70 or ttk < 10 then
        return "aggressive" -- Gastar libremente
    else
        return "balanced" -- Balance normal
    end
end

-- ============================================
-- FUNCIONES DE ANÁLISIS DE AMENAZA
-- ============================================

-- Función auxiliar para verificar si el jugador tiene un buff específico
local function HasBuff(buffName)
    local i = 1
    while UnitBuff("player", i) do
        local name = UnitBuff("player", i)
        if name and string.find(name, buffName) then
            return true
        end
        i = i + 1
        if i > 32 then break end -- Límite de seguridad
    end
    return false
end

-- Calcula el multiplicador de amenaza actual del jugador
function WCS_BrainSmartAI:GetThreatMultiplier()
    local multiplier = 1.0
    local _, class = UnitClass("player")
    
    -- Warrior stances
    if class == "WARRIOR" then
        if HasBuff("Defensive Stance") then
            multiplier = multiplier * THREAT_MULTIPLIERS.DEFENSIVE_STANCE
        elseif HasBuff("Battle Stance") then
            multiplier = multiplier * THREAT_MULTIPLIERS.BATTLE_STANCE
        elseif HasBuff("Berserker Stance") then
            multiplier = multiplier * THREAT_MULTIPLIERS.BERSERKER_STANCE
        end
    end
    
    -- Druid forms
    if class == "DRUID" then
        if HasBuff("Bear Form") or HasBuff("Dire Bear Form") then
            multiplier = multiplier * THREAT_MULTIPLIERS.BEAR_FORM
        end
    end
    
    -- Paladin Righteous Fury
    if class == "PALADIN" then
        if HasBuff("Righteous Fury") then
            multiplier = multiplier * THREAT_MULTIPLIERS.RIGHTEOUS_FURY
        end
    end
    
    return multiplier
end

-- Registra amenaza generada por una acción
function WCS_BrainSmartAI:AddThreat(amount, threatType, spellName)
    if not amount then
        amount = 0
    end
    
    local multiplier = self:GetThreatMultiplier()
    local finalThreat = 0
    
    -- Verificar si el hechizo tiene modificador especial
    if spellName and SPELL_THREAT_MODIFIERS[spellName] then
        local modifier = SPELL_THREAT_MODIFIERS[spellName]
        
        if modifier > 1 then
            -- Amenaza fija (ej: Taunt = 1000)
            finalThreat = modifier * multiplier
        elseif modifier < 0 then
            -- Reducción de amenaza (ej: Feint = -600)
            finalThreat = modifier
        else
            -- Multiplicador de daño/curación (ej: 0.5 para curación, 1.0 para daño)
            finalThreat = amount * modifier * multiplier
        end
    else
        -- Sin modificador especial, usar tipo genérico
        if threatType == "healing" then
            finalThreat = amount * 0.5 * multiplier
        elseif threatType == "damage" then
            finalThreat = amount * 1.0 * multiplier
        else
            finalThreat = amount * multiplier
        end
    end
    
    CombatCache.playerThreat = CombatCache.playerThreat + finalThreat
    
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("[SmartAI] %s: Amenaza %+.0f (Total: %.0f)", 
            spellName or "Acción", finalThreat, CombatCache.playerThreat))
    end
end

-- Estima el nivel de amenaza del jugador
function WCS_BrainSmartAI:EstimateThreatLevel()
    local playerRole = self:GetPlayerRole()
    
    if playerRole == "tank" then
        return 100 -- Los tanks quieren amenaza alta
    end
    
    -- Resetear amenaza si no estamos en combate
    if not UnitAffectingCombat("player") then
        local currentTime = GetTime()
        if currentTime - CombatCache.lastThreatReset > 5 then
            CombatCache.playerThreat = 0
            CombatCache.lastThreatReset = currentTime
        end
        return 0
    end
    
    -- Calcular porcentaje basado en amenaza acumulada
    local groupSize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
    
    if groupSize == 0 then
        return 0 -- Solo, no hay amenaza relativa
    end
    
    -- Estimar amenaza como porcentaje
    -- Asumimos que el tank tiene ~150% de nuestra amenaza base
    local estimatedTankThreat = CombatCache.playerThreat * 1.5
    local threatPercent = (CombatCache.playerThreat / estimatedTankThreat) * 100
    
    return math.min(threatPercent, 100)
end

-- Recomienda si debemos reducir amenaza
function WCS_BrainSmartAI:ShouldReduceThreat()
    local threatLevel = self:EstimateThreatLevel()
    local playerRole = self:GetPlayerRole()
    
    if playerRole == "tank" then
        return false -- Tanks nunca reducen amenaza
    end
    
    return threatLevel > THREAT_THRESHOLD_HIGH
end

-- ============================================
-- FUNCIONES DE ANÁLISIS DE ROL Y CLASE
-- ============================================

-- Determina el rol del jugador
function WCS_BrainSmartAI:GetPlayerRole()
    local _, class = UnitClass("player")
    
    -- Detectar rol basado en stance/forma/aura
    if class == "WARRIOR" then
        local stance = GetShapeshiftForm(true)
        if stance == 2 then -- Defensive Stance
            return "tank"
        else
            return "dps"
        end
    elseif class == "DRUID" then
        local stance = GetShapeshiftForm(true)
        if stance == 1 then -- Bear Form
            return "tank"
        elseif stance == 3 then -- Cat Form
            return "dps"
        else
            return "healer"
        end
    elseif class == "PALADIN" then
        -- Paladines pueden ser tank, healer o dps
        -- Detectar por buffs o equipo (simplificado)
        if UnitBuff("player", "Righteous Fury") then
            return "tank"
        else
            return "healer" -- Por defecto
        end
    elseif class == "PRIEST" or class == "SHAMAN" then
        return "healer"
    else
        return "dps"
    end
end

-- Obtiene el daño reciente del jugador
function WCS_BrainSmartAI:GetRecentDamageDealt()
    local currentTime = GetTime()
    local recentDamage = 0
    
    if CombatCache.spellHistory then
        for i = table.getn(CombatCache.spellHistory), 1, -1 do
            local entry = CombatCache.spellHistory[i]
            if currentTime - entry.time < 5 then
                recentDamage = recentDamage + (entry.damage or 0)
            else
                break
            end
        end
    end
    
    return recentDamage
end

-- Registra un hechizo lanzado para tracking de amenaza
function WCS_BrainSmartAI:RecordSpellCast(spellName, damage, spellType)
    local currentTime = GetTime()
    
    -- Agregar a historial
    table.insert(CombatCache.spellHistory, {
        time = currentTime,
        spell = spellName,
        damage = damage or 0,
        type = spellType or "damage"
    })
    
    -- Registrar amenaza con el nombre del hechizo
    if damage and damage > 0 then
        self:AddThreat(damage, spellType or "damage", spellName)
    elseif spellName then
        -- Hechizos sin daño pero con amenaza (buffs, taunts, etc)
        self:AddThreat(0, spellType, spellName)
    end
    
    -- Limpiar historial viejo (mantener últimos 30 segundos)
    while table.getn(CombatCache.spellHistory) > 0 and 
          (currentTime - CombatCache.spellHistory[1].time) > 30 do
        table.remove(CombatCache.spellHistory, 1)
    end
end

-- ============================================
-- SISTEMA DE SCORING DE HECHIZOS
-- ============================================

-- Calcula el score de un hechizo basado en múltiples factores
function WCS_BrainSmartAI:CalculateSpellScore(spellData)
    if not spellData then
        return 0
    end
    
    local score = 0
    local situation = self:AnalyzeCurrentSituation()
    
    -- Factor 1: DPS del hechizo
    if spellData.damage and spellData.castTime then
        local dps = spellData.damage / math.max(spellData.castTime, GLOBAL_COOLDOWN)
        score = score + (dps * WCS_BrainSmartAI.Weights.DPS * situation.dpsMultiplier)
    end
    
    -- Factor 2: Eficiencia de mana
    if spellData.damage and spellData.cost then
        local efficiency = spellData.damage / math.max(spellData.cost, 1)
        score = score + (efficiency * WCS_BrainSmartAI.Weights.EFFICIENCY * situation.efficiencyMultiplier)
    end
    
    -- Factor 3: Amenaza
    if spellData.threat then
        local threatModifier = situation.shouldReduceThreat and -1 or 1
        score = score + (spellData.threat * WCS_BrainSmartAI.Weights.THREAT * threatModifier)
    end
    
    -- Factor 4: Utilidad
    if spellData.utility then
        score = score + (spellData.utility * WCS_BrainSmartAI.Weights.UTILITY)
    end
    
    -- Factor 5: Urgencia
    if spellData.urgent then
        score = score + (100 * WCS_BrainSmartAI.Weights.URGENCY)
    end
    
    -- Factor 6: Supervivencia
    if spellData.defensive then
        score = score + (situation.dangerLevel * WCS_BrainSmartAI.Weights.SURVIVABILITY)
    end
    
    -- Penalización si no podemos pagar el mana
    if spellData.cost then
        local canAfford = self:CanAffordSpell(spellData.cost, spellData.priority or "normal")
        if not canAfford then
            score = score * 0.1
        end
    end
    
    -- Bonus si el hechizo es apropiado para la fase del combate
    local targetStrategy = self:AnalyzeTargetHealth("target")
    if spellData.phase and spellData.phase == targetStrategy then
        score = score * 1.3
    end
    
    return score
end

-- Analiza la situación actual del combate
function WCS_BrainSmartAI:AnalyzeCurrentSituation()
    local situation = {
        dpsMultiplier = 1.0,
        efficiencyMultiplier = 1.0,
        shouldReduceThreat = false,
        dangerLevel = 0
    }
    
    -- Analizar salud del jugador
    local healthPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
    if healthPercent < 30 then
        situation.dangerLevel = 100
        situation.dpsMultiplier = 0.5 -- Priorizar supervivencia
    elseif healthPercent < 50 then
        situation.dangerLevel = 50
    end
    
    -- Analizar estrategia de mana
    local manaStrategy = self:GetManaStrategy()
    if manaStrategy == "conserve" or manaStrategy == "emergency" then
        situation.efficiencyMultiplier = 2.0
        situation.dpsMultiplier = 0.7
    elseif manaStrategy == "aggressive" then
        situation.dpsMultiplier = 1.5
        situation.efficiencyMultiplier = 0.5
    end
    
    -- Analizar amenaza
    situation.shouldReduceThreat = self:ShouldReduceThreat()
    
    -- Analizar número de enemigos
    local enemyCount = self:CountNearbyEnemies()
    if enemyCount > 3 then
        situation.aoeMultiplier = 2.0
    elseif enemyCount > 1 then
        situation.aoeMultiplier = 1.5
    else
        situation.aoeMultiplier = 1.0
    end
    
    return situation
end

-- Cuenta enemigos cercanos
function WCS_BrainSmartAI:CountNearbyEnemies()
    local count = 0
    
    -- Verificar target
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
        count = count + 1
    end
    
    -- En WoW 1.12, no hay forma fácil de contar todos los enemigos
    -- Podríamos usar nameplate detection o combat log parsing
    -- Por ahora, retornamos un valor conservador
    
    return count
end

-- ============================================
-- FUNCIONES DE DETECCIÓN DE PATRONES
-- ============================================

-- Detecta patrones en el encuentro actual
function WCS_BrainSmartAI:DetectEncounterPatterns()
    local patterns = {
        isAoE = false,
        isBurst = false,
        isSustained = false,
        hasPhases = false
    }
    
    local encounterDuration = GetTime() - CombatCache.encounterStart
    local enemyCount = self:CountNearbyEnemies()
    
    -- Detectar AoE
    if enemyCount > 2 then
        patterns.isAoE = true
    end
    
    -- Detectar burst vs sustained
    local ttk = self:PredictTimeToKill("target")
    if ttk < 15 then
        patterns.isBurst = true
    elseif ttk > 30 or encounterDuration > 60 then
        patterns.isSustained = true
    end
    
    return patterns
end

-- Aprende de encuentros previos
function WCS_BrainSmartAI:LearnFromEncounter()
    -- Guardar estadísticas del encuentro
    local encounterData = {
        duration = GetTime() - CombatCache.encounterStart,
        manaUsed = UnitManaMax("player") - UnitMana("player"),
        spellsCast = table.getn(CombatCache.spellHistory),
        survived = not UnitIsDead("player")
    }
    
    -- Aquí podríamos guardar en SavedVariables para aprendizaje a largo plazo
    -- Por ahora solo limpiamos el cache
    
    return encounterData
end

-- ============================================
-- FUNCIONES DE INTEGRACIÓN CON WCS_BRAIN
-- ============================================

-- Hook para mejorar las decisiones del sistema principal
function WCS_BrainSmartAI:EnhanceDecision(originalDecision)
    if not originalDecision then
        return nil
    end
    
    -- Analizar si la decisión original es óptima
    local situation = self:AnalyzeCurrentSituation()
    local targetStrategy = self:AnalyzeTargetHealth("target")
    
    -- Si estamos en peligro, priorizar supervivencia
    if situation.dangerLevel > 70 then
        -- Buscar hechizos defensivos
        local defensiveSpell = self:FindBestDefensiveSpell()
        if defensiveSpell then
            return defensiveSpell
        end
    end
    
    -- Si debemos reducir amenaza, evitar hechizos de alto daño
    if situation.shouldReduceThreat then
        if originalDecision.threat and originalDecision.threat > 50 then
            -- Buscar alternativa de menor amenaza
            local lowThreatSpell = self:FindLowThreatAlternative(originalDecision)
            if lowThreatSpell then
                return lowThreatSpell
            end
        end
    end
    
    -- Si la estrategia de mana dice conservar, verificar eficiencia
    local manaStrategy = self:GetManaStrategy()
    if manaStrategy == "conserve" or manaStrategy == "emergency" then
        if originalDecision.cost then
            local efficiency = (originalDecision.damage or 0) / originalDecision.cost
            if efficiency < 2 then -- Umbral de eficiencia
                local efficientSpell = self:FindMoreEfficientSpell(originalDecision)
                if efficientSpell then
                    return efficientSpell
                end
            end
        end
    end
    
    -- La decisión original es buena
    return originalDecision
end

-- Encuentra el mejor hechizo defensivo disponible
function WCS_BrainSmartAI:FindBestDefensiveSpell()
    -- Esto dependería de la clase del jugador
    -- Por ahora retornamos nil (el sistema principal manejará esto)
    return nil
end

-- Encuentra alternativa de baja amenaza
function WCS_BrainSmartAI:FindLowThreatAlternative(originalSpell)
    -- Buscar hechizos similares con menor amenaza
    return nil
end

-- Encuentra hechizo más eficiente
function WCS_BrainSmartAI:FindMoreEfficientSpell(originalSpell)
    -- Buscar hechizos con mejor ratio daño/mana
    return nil
end

-- ============================================
-- FUNCIONES DE INICIALIZACIÓN Y EVENTOS
-- ============================================

-- Inicializa el sistema SmartAI
function WCS_BrainSmartAI:Initialize()
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Inicializando v" .. SMART_AI_VERSION)
    end
    
    -- Registrar eventos
    self:RegisterEvents()
    
    -- Inicializar cache
    CombatCache.encounterStart = GetTime()
    
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Sistema inicializado correctamente")
    end
end

-- Registra eventos necesarios
function WCS_BrainSmartAI:RegisterEvents()
    -- Crear frame para eventos si no existe
    if not WCS_SmartAI_EventFrame then
        WCS_SmartAI_EventFrame = CreateFrame("Frame")
    end
    
    -- Registrar eventos
    WCS_SmartAI_EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entrar en combate
    WCS_SmartAI_EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Salir de combate
    WCS_SmartAI_EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- Handler de eventos
    local function WCS_SmartAI_OnEvent()
        if event == "PLAYER_REGEN_DISABLED" then
            WCS_BrainSmartAI:OnEnterCombat()
        elseif event == "PLAYER_REGEN_ENABLED" then
            WCS_BrainSmartAI:OnLeaveCombat()
        elseif event == "PLAYER_TARGET_CHANGED" then
            WCS_BrainSmartAI:OnTargetChanged()
        end
    end
    WCS_SmartAI_EventFrame:SetScript("OnEvent", WCS_SmartAI_OnEvent)
end

-- Evento: Entrar en combate
function WCS_BrainSmartAI:OnEnterCombat()
    CombatCache.encounterStart = GetTime()
    CombatCache.spellHistory = {}
    CombatCache.manaHistory = {}
    
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Combate iniciado")
    end
end

-- Evento: Salir de combate
function WCS_BrainSmartAI:OnLeaveCombat()
    -- Aprender del encuentro
    local encounterData = self:LearnFromEncounter()
    
    -- Limpiar cache de objetivo
    CombatCache.targetHealth = {}
    CombatCache.targetDPS = {}
    
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Combate finalizado - Duración: " .. 
            string.format("%.1f", encounterData.duration) .. "s")
    end
end

-- Evento: Cambio de objetivo
function WCS_BrainSmartAI:OnTargetChanged()
    -- Limpiar cache del objetivo anterior
    if CombatCache.targetHealth["target"] then
        CombatCache.targetHealth["target"] = nil
    end
    if CombatCache.targetDPS["target"] then
        CombatCache.targetDPS["target"] = nil
    end
end

-- ============================================
-- FUNCIONES DE UTILIDAD Y DEBUG
-- ============================================

-- Activa/desactiva modo debug
function WCS_BrainSmartAI:ToggleDebug()
    DEBUG_MODE = not DEBUG_MODE
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Modo debug: " .. 
        (DEBUG_MODE and "ACTIVADO" or "DESACTIVADO"))
end

-- Muestra estadísticas del sistema
function WCS_BrainSmartAI:ShowStats()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r === Estadísticas ===")
    DEFAULT_CHAT_FRAME:AddMessage("Versión: " .. SMART_AI_VERSION)
    DEFAULT_CHAT_FRAME:AddMessage("Rol detectado: " .. self:GetPlayerRole())
    DEFAULT_CHAT_FRAME:AddMessage("Estrategia de mana: " .. self:GetManaStrategy())
    DEFAULT_CHAT_FRAME:AddMessage("Nivel de amenaza: " .. self:EstimateThreatLevel() .. "%")
    
    if UnitExists("target") then
        local ttk = self:PredictTimeToKill("target")
        local strategy = self:AnalyzeTargetHealth("target")
        DEFAULT_CHAT_FRAME:AddMessage("Tiempo hasta muerte del objetivo: " .. 
            string.format("%.1f", ttk) .. "s")
        DEFAULT_CHAT_FRAME:AddMessage("Estrategia recomendada: " .. strategy)
    end
end

-- ============================================
-- INICIALIZACIÓN AUTOMÁTICA
-- ============================================

-- Inicializar cuando el addon se carga
WCS_BrainSmartAI:Initialize()

-- Comandos de slash
SLASH_WCSSMARTAI1 = "/smartai"
SlashCmdList["WCSSMARTAI"] = function(msg)
    if msg == "debug" then
        WCS_BrainSmartAI:ToggleDebug()
    elseif msg == "stats" then
        WCS_BrainSmartAI:ShowStats()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Comandos disponibles:")
        DEFAULT_CHAT_FRAME:AddMessage("/smartai debug - Activa/desactiva modo debug")
        DEFAULT_CHAT_FRAME:AddMessage("/smartai stats - Muestra estadísticas del sistema")
    end
end

-- ============================================
-- SISTEMA DE EVENTOS PARA TRACKING
-- ============================================

-- Frame para eventos
local SmartAIFrame = CreateFrame("Frame")

-- Handler de eventos de combate
local function SmartAI_CombatEventHandler()
    if event == "CHAT_MSG_SPELL_SELF_DAMAGE" or 
       event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        -- Extraer nombre del hechizo y daño del mensaje
        local _, _, spellName, damage = string.find(arg1, "Your (.+) hits .+ for (%d+)")
        if not spellName then
            _, _, spellName, damage = string.find(arg1, "Your (.+) crits .+ for (%d+)")
        end
        if spellName and damage then
            WCS_BrainSmartAI:RecordSpellCast(spellName, tonumber(damage), "damage")
        end
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" or
           event == "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE" then
        -- DoT ticks
        local _, _, target, damage, spellName = string.find(arg1, "(.+) suffers (%d+) .+ damage from your (.+)")
        if spellName and damage then
            WCS_BrainSmartAI:RecordSpellCast(spellName, tonumber(damage), "damage")
        end
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" then
        -- Buffs propios
        local _, _, spellName = string.find(arg1, "You gain (.+)%.")
        if spellName then
            WCS_BrainSmartAI:RecordSpellCast(spellName, 0, "buff")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entrando en combate
        CombatCache.encounterStart = GetTime()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Saliendo de combate
        local currentTime = GetTime()
        if currentTime - CombatCache.lastThreatReset > 5 then
            CombatCache.playerThreat = 0
            CombatCache.lastThreatReset = currentTime
        end
    end
end
SmartAIFrame:SetScript("OnEvent", SmartAI_CombatEventHandler)

-- Registrar eventos
SmartAIFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
SmartAIFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
SmartAIFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
SmartAIFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
SmartAIFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
SmartAIFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
SmartAIFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Cargado v" .. SMART_AI_VERSION .. " - Usa /smartai para ayuda")
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS SmartAI]|r Tracking de amenaza activado")

-- ============================================
-- INTERFAZ DE USUARIO (Tab 2)
-- ============================================

function WCS_BrainSmartAI:CreateUI()
    if _G["WCSBrainSmartAIFrame"] then return end
    
    local f = CreateFrame("Frame", "WCSBrainSmartAIFrame", UIParent)
    f:SetWidth(680)
    f:SetHeight(490)
    f:Hide()
    
    -- Contenedor interior oscuro
    local bg = CreateFrame("Frame", nil, f)
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0.04, 0.02, 0.08, 0.9)   -- Fondo oscuro (BG_DARK)
    bg:SetBackdropBorderColor(0, 1, 0.5, 0.8)    -- Borde fel green (AI)
    
    -- Título Central
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", bg, "TOP", 0, -15)
    title:SetText("|cFF00FF80SMART AI ENGINE|r")
    
    -- Info del Motor
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetText("|cFFAAAAAAAnálisis de contexto, DPS, Eficiencia y Resiliencia|r")
    
    -- Checkbox ON/OFF
    local enableCheck = CreateFrame("CheckButton", nil, bg, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", bg, "TOPLEFT", 20, -20)
    enableCheck:SetChecked(true)
    
    local enableLabel = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
    enableLabel:SetText("Activar Smart AI Override")
    
    -- Panel de Análisis en Vivo (top-right, sin solapar el checkbox)
    local analysisPanel = CreateFrame("Frame", nil, bg)
    analysisPanel:SetWidth(285)
    analysisPanel:SetHeight(110)
    analysisPanel:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -20, -45)
    analysisPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    analysisPanel:SetBackdropColor(0.1, 0.1, 0.2, 0.8)
    analysisPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
    
    local analysisTitle = analysisPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    analysisTitle:SetPoint("TOP", analysisPanel, "TOP", 0, -10)
    analysisTitle:SetText("|cFFFFFF00Análisis de Combate en Vivo|r")
    
    local roleText = analysisPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleText:SetPoint("TOPLEFT", analysisPanel, "TOPLEFT", 15, -35)
    roleText:SetText("Role Detectado: |cFFFFFFFF" .. WCS_BrainSmartAI:GetPlayerRole() .. "|r")
    f.roleText = roleText
    
    local manaStrat = analysisPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manaStrat:SetPoint("TOPLEFT", roleText, "BOTTOMLEFT", 0, -15)
    manaStrat:SetText("Mana Strategy: |cFF0088FF" .. WCS_BrainSmartAI:GetManaStrategy() .. "|r")
    f.manaStrat = manaStrat
    
    local threatLevel = analysisPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    threatLevel:SetPoint("TOPLEFT", manaStrat, "BOTTOMLEFT", 0, -15)
    threatLevel:SetText("Nivel Amenaza: |cFFFF6600" .. math.floor(WCS_BrainSmartAI:EstimateThreatLevel()) .. "%|r")
    f.threatLevel = threatLevel
    
    -- Panel de Ajuste de Pesos (Weights) - debajo del checkbox y título
    local weightsTitle = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    weightsTitle:SetPoint("TOPLEFT", bg, "TOPLEFT", 25, -85)
    weightsTitle:SetText("|cFFCC99FFPonderación de Hechizos|r")
    
    local descWeights = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descWeights:SetPoint("TOPLEFT", weightsTitle, "BOTTOMLEFT", 0, -4)
    descWeights:SetText("|cFF888888Ajusta cómo la IA valora diferentes factores al decidir qué hechizo lanzar|r")
    
    local function CreateWeightSlider(parent, name, key, id, x, y)
        local slider = CreateFrame("Slider", "WCS_BrainSmartAISlider" .. id, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        slider:SetMinMaxValues(0.0, 3.0)
        slider:SetValueStep(0.1)
        slider:SetWidth(180)
        
        local text = _G[slider:GetName().."Text"]
        text:SetText(name)
        
        local low = _G[slider:GetName().."Low"]
        low:SetText("0.0")
        
        local high = _G[slider:GetName().."High"]
        high:SetText("3.0")
        
        -- Valor actual
        local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valText:SetPoint("TOP", slider, "BOTTOM", 0, -3)
        valText:SetText(string.format("%.1f", WCS_BrainSmartAI.Weights[key]))
        
        slider:SetValue(WCS_BrainSmartAI.Weights[key])
        
        slider:SetScript("OnValueChanged", function()
            local val = this:GetValue()
            valText:SetText(string.format("%.1f", val))
            WCS_BrainSmartAI.Weights[key] = val
        end)
    end
    
    -- Columna 1 (izquierda) - offset Y ajustado para 490px
    CreateWeightSlider(bg, "|cFFFF3333DPS|r (Daño Neto)",             "DPS",           1, 20,  -140)
    CreateWeightSlider(bg, "|cFF3388FFEficiencia|r (Daño/Mana)",       "EFFICIENCY",    2, 20,  -195)
    CreateWeightSlider(bg, "|cFFFF8833Amenaza|r (Aggro)",              "THREAT",        3, 20,  -250)
    
    -- Columna 2 (derecha)
    CreateWeightSlider(bg, "|cFF33FF33Utilidad|r (CC/Debuffs)",        "UTILITY",       4, 340, -140)
    CreateWeightSlider(bg, "|cFFFFFF33Urgencia|r (Ejecución)",          "URGENCY",       5, 340, -195)
    CreateWeightSlider(bg, "|cFFFF33FFSupervivencia|r (Defensa)",       "SURVIVABILITY", 6, 340, -250)
    
    local resetDefaultsBtn = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    resetDefaultsBtn:SetPoint("TOPLEFT", bg, "TOPLEFT", 240, -310)
    resetDefaultsBtn:SetWidth(150)
    resetDefaultsBtn:SetHeight(25)
    resetDefaultsBtn:SetText("Restaurar Valores")
    resetDefaultsBtn:SetScript("OnClick", function()
        WCS_BrainSmartAI.Weights = {
            DPS = 1.0, EFFICIENCY = 0.8, THREAT = 0.6,
            UTILITY = 0.7, URGENCY = 1.2, SURVIVABILITY = 1.5
        }
        _G["WCS_BrainSmartAISlider1"]:SetValue(1.0)
        _G["WCS_BrainSmartAISlider2"]:SetValue(0.8)
        _G["WCS_BrainSmartAISlider3"]:SetValue(0.6)
        _G["WCS_BrainSmartAISlider4"]:SetValue(0.7)
        _G["WCS_BrainSmartAISlider5"]:SetValue(1.2)
        _G["WCS_BrainSmartAISlider6"]:SetValue(1.5)
    end)
    
    -- Evento OnUpdate para el análisis en vivo
    local updateTimer = 0
    f:SetScript("OnUpdate", function()
        updateTimer = updateTimer + arg1
        if updateTimer > 0.5 then
            updateTimer = 0
            if f:IsVisible() then
                f.roleText:SetText("Role Detectado: |cFFFFFFFF" .. WCS_BrainSmartAI:GetPlayerRole() .. "|r")
                f.manaStrat:SetText("Mana Strategy: |cFF0088FF" .. WCS_BrainSmartAI:GetManaStrategy() .. "|r")
                f.threatLevel:SetText("Nivel Amenaza: |cFFFF6600" .. math.floor(WCS_BrainSmartAI:EstimateThreatLevel()) .. "%|r")
            end
        end
    end)
end

