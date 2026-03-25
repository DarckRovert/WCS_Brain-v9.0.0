--[[
    WCS_BrainReward.lua - Sistema de Recompensas para DQN
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Calcula recompensas inmediatas y finales para el aprendizaje
]]--

WCS_BrainReward = WCS_BrainReward or {}
WCS_BrainReward.VERSION = "6.4.2"

-- ============================================================================
-- CONFIGURACION DE RECOMPENSAS
-- ============================================================================
WCS_BrainReward.Config = {
    -- Recompensas inmediatas
    damageDealt = 0.1,
    dotApplied = 5,
    dotRefreshed = 2,
    curseApplied = 4,
    lifeTapGood = 3,
    lifeTapBad = -10,
    darkPactGood = 5,
    healthstoneUsed = 10,
    fearUsed = 8,
    
    -- Penalizaciones
    manaDesperdiciado = -5,
    dotSobrescrito = -3,
    hechizoCancelado = -2,
    movimientoMalo = -1,
    
    -- Recompensas finales
    combatWon = 50,
    combatLost = -100,
    survivalBonus = 20,
    efficiencyBonus = 15,
    speedBonus = 10
}

-- ============================================================================
-- TRACKING DE COMBATE
-- ============================================================================
WCS_BrainReward.CombatStats = {
    damageDealt = 0,
    damageTaken = 0,
    manaUsed = 0,
    healthUsed = 0,
    dotsApplied = 0,
    cursesApplied = 0,
    castsCancelled = 0,
    combatStartTime = 0,
    combatDuration = 0,
    lastDotTimes = {}
}

-- ============================================================================
-- RESETEAR STATS DE COMBATE
-- ============================================================================
function WCS_BrainReward:ResetCombatStats()
    self.CombatStats = {
        damageDealt = 0,
        damageTaken = 0,
        manaUsed = 0,
        healthUsed = 0,
        dotsApplied = 0,
        cursesApplied = 0,
        castsCancelled = 0,
        combatStartTime = GetTime(),
        combatDuration = 0,
        lastDotTimes = {}
    }
end

-- ============================================================================
-- CALCULAR RECOMPENSA INMEDIATA
-- ============================================================================
function WCS_BrainReward:CalculateImmediateReward(action, prevState, newState)
    local reward = 0
    local cfg = self.Config
    
    if not prevState or not newState or not action then
        return 0
    end
    
    -- Acción 1: Shadow Bolt
    if action == 1 then
        -- Recompensa por daño (estimado)
        reward = reward + cfg.damageDealt * 10
        
        -- Penalización si el target está muy bajo de HP (mejor usar Shadowburn)
        if newState[11] < 0.2 then
            reward = reward - 2
        end
    end
    
    -- Acción 2: Corruption
    if action == 2 then
        -- Recompensa por aplicar DoT
        if prevState[21] < 0.1 then
            reward = reward + cfg.dotApplied
            self.CombatStats.dotsApplied = self.CombatStats.dotsApplied + 1
        -- Recompensa menor por refrescar
        elseif prevState[21] < 0.3 then
            reward = reward + cfg.dotRefreshed
        -- Penalización por sobrescribir DoT con mucho tiempo
        else
            reward = reward + cfg.dotSobrescrito
        end
    end
    
    -- Acción 3: Curse of Agony
    if action == 3 then
        if prevState[22] < 0.1 then
            reward = reward + cfg.curseApplied
            self.CombatStats.cursesApplied = self.CombatStats.cursesApplied + 1
        elseif prevState[22] < 0.3 then
            reward = reward + cfg.dotRefreshed
        else
            reward = reward + cfg.dotSobrescrito
        end
    end
    
    -- Acción 4: Immolate
    if action == 4 then
        if prevState[23] < 0.1 then
            reward = reward + cfg.dotApplied
            self.CombatStats.dotsApplied = self.CombatStats.dotsApplied + 1
        elseif prevState[23] < 0.3 then
            reward = reward + cfg.dotRefreshed
        else
            reward = reward + cfg.dotSobrescrito
        end
    end
    
    -- Acción 5: Siphon Life
    if action == 5 then
        if prevState[24] < 0.1 then
            reward = reward + cfg.dotApplied + 2
            self.CombatStats.dotsApplied = self.CombatStats.dotsApplied + 1
        elseif prevState[24] < 0.3 then
            reward = reward + cfg.dotRefreshed
        else
            reward = reward + cfg.dotSobrescrito
        end
    end
    
    -- Acción 6: Life Tap
    if action == 6 then
        -- Bueno si mana está bajo
        if prevState[2] < 0.3 then
            reward = reward + cfg.lifeTapGood
        -- Malo si mana está alto
        elseif prevState[2] > 0.7 then
            reward = reward + cfg.lifeTapBad
        end
        
        -- Penalización si HP está muy bajo
        if prevState[1] < 0.3 then
            reward = reward - 5
        end
    end
    
    -- Acción 7: Dark Pact
    if action == 7 then
        -- Bueno si pet tiene mana y jugador necesita
        if prevState[33] > 0.5 and prevState[2] < 0.5 then
            reward = reward + cfg.darkPactGood
        else
            reward = reward - 3
        end
    end
    
    -- Acción 8: Death Coil
    if action == 8 then
        -- Bueno en emergencias
        if prevState[1] < 0.4 then
            reward = reward + 8
        else
            reward = reward - 2
        end
    end
    
    -- Acción 9: Shadowburn
    if action == 9 then
        -- Muy bueno si target está bajo de HP
        if prevState[11] < 0.2 then
            reward = reward + 15
        else
            reward = reward - 5
        end
    end
    
    -- Acción 10: Fear
    if action == 10 then
        -- Bueno si puede ser feared y hay peligro
        if prevState[18] > 0.5 and prevState[1] < 0.5 then
            reward = reward + cfg.fearUsed
        else
            reward = reward - 3
        end
    end
    
    -- Acción 11: Drain Life
    if action == 11 then
        -- Bueno si HP está bajo
        if prevState[1] < 0.5 then
            reward = reward + 5
        else
            reward = reward - 1
        end
    end
    
    -- Acción 12: Healthstone
    if action == 12 then
        -- Muy bueno en emergencias
        if prevState[1] < 0.3 and prevState[48] > 0.5 then
            reward = reward + cfg.healthstoneUsed
        else
            reward = reward - 5
        end
    end
    
    -- Acción 13: Wait/Wand
    if action == 13 then
        -- Bueno si está regenerando mana
        if prevState[2] < 0.2 then
            reward = reward + 1
        -- Malo si tiene mana y target tiene HP
        elseif prevState[2] > 0.5 and prevState[11] > 0.3 then
            reward = reward - 2
        end
    end
    
    -- Penalización por castear mientras se mueve (si tiene cast time)
    if prevState[5] > 0.5 and (action == 1 or action == 4 or action == 8 or action == 11) then
        reward = reward + cfg.movimientoMalo
    end
    
    -- Penalización por desperdiciar mana (castear con mana lleno)
    if prevState[2] > 0.95 and action ~= 13 then
        reward = reward + cfg.manaDesperdiciado
    end
    
    -- Bonus por mantener múltiples DoTs
    local activeDots = 0
    if newState[21] > 0.1 then activeDots = activeDots + 1 end
    if newState[22] > 0.1 then activeDots = activeDots + 1 end
    if newState[23] > 0.1 then activeDots = activeDots + 1 end
    if newState[24] > 0.1 then activeDots = activeDots + 1 end
    
    if activeDots >= 3 then
        reward = reward + 3
    elseif activeDots >= 2 then
        reward = reward + 1
    end
    
    return reward
end

-- ============================================================================
-- CALCULAR RECOMPENSA FINAL (al terminar combate)
-- ============================================================================
function WCS_BrainReward:CalculateFinalReward(won, finalState)
    local reward = 0
    local cfg = self.Config
    
    -- Recompensa base por ganar/perder
    if won then
        reward = reward + cfg.combatWon
    else
        reward = reward + cfg.combatLost
    end
    
    -- Bonus por supervivencia (HP restante)
    if finalState and finalState[1] then
        local hpBonus = finalState[1] * cfg.survivalBonus
        reward = reward + hpBonus
    end
    
    -- Bonus por eficiencia (mana restante)
    if finalState and finalState[2] then
        local manaBonus = finalState[2] * cfg.efficiencyBonus
        reward = reward + manaBonus
    end
    
    -- Bonus por velocidad (combate corto)
    self.CombatStats.combatDuration = GetTime() - self.CombatStats.combatStartTime
    if self.CombatStats.combatDuration < 30 and won then
        reward = reward + cfg.speedBonus
    end
    
    -- Bonus por uso efectivo de DoTs
    if self.CombatStats.dotsApplied >= 3 then
        reward = reward + 10
    end
    
    -- Penalización por muchos casts cancelados
    if self.CombatStats.castsCancelled > 3 then
        reward = reward - (self.CombatStats.castsCancelled * 2)
    end
    
    return reward
end

-- ============================================================================
-- DETECTAR COMBOS EFECTIVOS
-- ============================================================================
function WCS_BrainReward:DetectCombo(actionSequence)
    if not actionSequence or WCS_TableCount(actionSequence) < 3 then
        return 0
    end
    
    local reward = 0
    local len = WCS_TableCount(actionSequence)
    
    -- Combo: Corruption -> Curse -> Immolate -> Shadow Bolt
    if len >= 4 then
        if actionSequence[len-3] == 2 and 
           actionSequence[len-2] == 3 and 
           actionSequence[len-1] == 4 and 
           actionSequence[len] == 1 then
            reward = reward + 15
        end
    end
    
    -- Combo: Life Tap -> Dark Pact (recuperación de mana)
    if len >= 2 then
        if actionSequence[len-1] == 6 and actionSequence[len] == 7 then
            reward = reward + 8
        end
    end
    
    -- Combo: Fear -> DoTs (mientras está feared)
    if len >= 3 then
        if actionSequence[len-2] == 10 and 
           (actionSequence[len-1] == 2 or actionSequence[len-1] == 3) then
            reward = reward + 10
        end
    end
    
    return reward
end

-- ============================================================================
-- TRACKING DE DAÑO
-- ============================================================================
function WCS_BrainReward:OnDamageDealt(amount)
    self.CombatStats.damageDealt = self.CombatStats.damageDealt + amount
end

function WCS_BrainReward:OnDamageTaken(amount)
    self.CombatStats.damageTaken = self.CombatStats.damageTaken + amount
end

function WCS_BrainReward:OnCastCancelled()
    self.CombatStats.castsCancelled = self.CombatStats.castsCancelled + 1
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
WCS_BrainReward:ResetCombatStats()
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS Brain Reward]|r Loaded v" .. WCS_BrainReward.VERSION)

-- ============================================================================
-- TERRORMETER INTEGRATION (v6.5.0)
-- ============================================================================

function WCS_BrainReward:AddDPSBonus(bonus)
    if not self.Config.enableTerrorMeterBonus then return end
    self.Config.dpsBonus = bonus or 0
end

function WCS_BrainReward:GetTerrorMeterBonus()
    if not self.Config.enableTerrorMeterBonus then return 0 end
    return self.Config.dpsBonus or 0
end

function WCS_BrainReward:ApplyTerrorMeterBonus(baseReward)
    if not self.Config.enableTerrorMeterBonus then return baseReward end
    local bonus = self:GetTerrorMeterBonus()
    if bonus > 0 then
        return baseReward * (1 + bonus)
    end
    return baseReward
end

if not WCS_BrainReward.Config.enableTerrorMeterBonus then
    WCS_BrainReward.Config.enableTerrorMeterBonus = true
end
if not WCS_BrainReward.Config.dpsBonus then
    WCS_BrainReward.Config.dpsBonus = 0
end
