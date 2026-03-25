--[[
    WCS_BrainAI.lua - Sistema de IA Inteligente v6.7.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    SISTEMAS INCLUIDOS:
    - Sistema de Puntuacion (Scoring)
    - Tracking de DoTs con tiempo
    - Deteccion Multi-Target
    - Clasificacion de Combate
    - PetAI Mejorada
]]--

WCS_BrainAI = WCS_BrainAI or {}
WCS_BrainAI.VERSION = "6.7.0"

-- ============================================================================
-- UTILIDADES LUA 5.0
-- ============================================================================
local function getTime()
    return GetTime and GetTime() or 0
end

local function tableLength(t)
    local count = 0
    for k, v in pairs(t) do count = count + 1 end
    return count
end

local function debugPrint(msg)
    if WCS_Brain and WCS_Brain.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FF[BrainAI]|r " .. tostring(msg))
    end
end

-- ============================================================================
-- SISTEMA DE TRACKING DE DoTs CON TIEMPO
-- ============================================================================
WCS_BrainAI.DoTTimers = {
    -- Estructura: [targetGUID] = { [dotName] = {applied = time, duration = dur} }
}

-- Target actual (usamos nombre+nivel como pseudo-GUID en Vanilla)
WCS_BrainAI.CurrentTargetID = nil

function WCS_BrainAI:GetTargetID()
    if not UnitExists("target") then return nil end
    local name = UnitName("target") or "Unknown"
    local level = UnitLevel("target") or 0
    local maxHp = UnitHealthMax("target") or 0
    return name .. "_" .. level .. "_" .. maxHp
end

-- Duraciones base de DoTs (sin talentos)
WCS_BrainAI.DoTDurations = {
    ["Corruption"] = 18,
    ["Immolate"] = 15,
    ["Curse of Agony"] = 24,
    ["Siphon Life"] = 30,
    ["Curse of Doom"] = 60,
    ["Curse of Tongues"] = 30,
    ["Curse of Weakness"] = 120,
    ["Curse of the Elements"] = 300,
    ["Curse of Shadow"] = 300
}

-- Registrar aplicacion de DoT
function WCS_BrainAI:RegisterDoTApplied(dotName, targetID)
    if not targetID then targetID = self:GetTargetID() end
    if not targetID then return end
    
    if not self.DoTTimers[targetID] then
        self.DoTTimers[targetID] = {}
    end
    
    local duration = self.DoTDurations[dotName] or 18
    self.DoTTimers[targetID][dotName] = {
        applied = getTime(),
        duration = duration
    }
    debugPrint("DoT registrado: " .. dotName .. " en " .. targetID)
end

-- Registrar remocion de DoT
function WCS_BrainAI:RegisterDoTRemoved(dotName, targetID)
    if not targetID then targetID = self:GetTargetID() end
    if not targetID then return end
    
    if self.DoTTimers[targetID] then
        self.DoTTimers[targetID][dotName] = nil
    end
end

-- Obtener tiempo restante de un DoT
function WCS_BrainAI:GetDoTTimeRemaining(dotName, targetID)
    if not targetID then targetID = self:GetTargetID() end
    if not targetID then return 0 end
    
    local targetDots = self.DoTTimers[targetID]
    if not targetDots then return 0 end
    
    local dot = targetDots[dotName]
    if not dot then return 0 end
    
    local elapsed = getTime() - dot.applied
    local remaining = dot.duration - elapsed
    
    if remaining < 0 then
        -- DoT expirado, limpiar
        targetDots[dotName] = nil
        return 0
    end
    
    return remaining
end

-- Verificar si debemos refrescar un DoT (pandemic window = 30% de duracion)
function WCS_BrainAI:ShouldRefreshDoT(dotName, targetID)
    local remaining = self:GetDoTTimeRemaining(dotName, targetID)
    local baseDuration = self.DoTDurations[dotName] or 18
    local pandemicWindow = baseDuration * 0.3 -- 30% de la duracion
    
    -- Refrescar si queda menos del 30% o si no esta aplicado
    return remaining < pandemicWindow
end

-- Limpiar DoTs de targets viejos (optimizado)
WCS_BrainAI.LastCleanup = 0
WCS_BrainAI.MaxTrackedTargets = 20  -- Límite de targets tracked
function WCS_BrainAI:CleanupExpiredDoTs()
    local now = getTime()
    local expiredTargets = {}
    local expiredDoTs = {}
    
    -- Primera pasada: identificar DoTs expirados
    for targetID, dots in pairs(self.DoTTimers) do
        for dotName, data in pairs(dots) do
            local remaining = data.duration - (now - data.applied)
            if remaining <= 0 then
                if not expiredDoTs[targetID] then
                    expiredDoTs[targetID] = {}
                end
                table.insert(expiredDoTs[targetID], dotName)
            end
        end
    end
    
    -- Segunda pasada: limpiar DoTs expirados
    for targetID, dotList in pairs(expiredDoTs) do
        for i, dotName in ipairs(dotList) do
            self.DoTTimers[targetID][dotName] = nil
        end
        
        -- Si no quedan DoTs activos, marcar target para eliminación
        local hasActiveDots = false
        for dotName, data in pairs(self.DoTTimers[targetID]) do
            hasActiveDots = true
            break
        end
        
        if not hasActiveDots then
            table.insert(expiredTargets, targetID)
        end
    end
    
    -- Tercera pasada: eliminar targets sin DoTs
    for i, targetID in ipairs(expiredTargets) do
        self.DoTTimers[targetID] = nil
    end
    
    -- Limitar número de targets tracked
    self:EnforceTargetLimit()
end

-- Función para limitar número de targets tracked
function WCS_BrainAI:EnforceTargetLimit()
    local targetCount = 0
    local oldestTargets = {}
    
    -- Contar targets y encontrar los más antiguos
    for targetID, dots in pairs(self.DoTTimers) do
        targetCount = targetCount + 1
        
        -- Encontrar el DoT más antiguo de este target
        local oldestTime = getTime()
        for dotName, data in pairs(dots) do
            if data.applied < oldestTime then
                oldestTime = data.applied
            end
        end
        
        table.insert(oldestTargets, {id = targetID, time = oldestTime})
    end
    
    -- Si excedemos el límite, eliminar los más antiguos
    if targetCount > self.MaxTrackedTargets then
        -- Ordenar por tiempo (más antiguos primero)
        table.sort(oldestTargets, function(a, b) return a.time < b.time end)
        
        local toRemove = targetCount - self.MaxTrackedTargets
        for i = 1, toRemove do
            self.DoTTimers[oldestTargets[i].id] = nil
        end
    end
end

-- ============================================================================
-- SISTEMA DE DETECCION MULTI-TARGET
-- ============================================================================
WCS_BrainAI.CombatTargets = {}
WCS_BrainAI.LastCombatScan = 0

-- Registrar un enemigo en combate
function WCS_BrainAI:RegisterCombatTarget(targetID)
    if not targetID then return end
    self.CombatTargets[targetID] = {
        lastSeen = getTime(),
        hasDots = false
    }
end

-- Contar enemigos en combate (aproximado)
function WCS_BrainAI:CountEnemiesInCombat()
    -- Metodo 1: Contar targets registrados recientemente
    local count = 0
    local now = getTime()
    
    for targetID, data in pairs(self.CombatTargets) do
        -- Solo contar si fue visto en los ultimos 10 segundos
        if (now - data.lastSeen) < 10 then
            count = count + 1
        else
            self.CombatTargets[targetID] = nil
        end
    end
    
    -- Minimo 1 si tenemos target hostil
    if count == 0 and UnitExists("target") and UnitCanAttack("player", "target") then
        count = 1
    end
    
    return count
end

-- Verificar si es situacion AoE (3+ enemigos)
function WCS_BrainAI:IsAoESituation()
    return self:CountEnemiesInCombat() >= 3
end

-- Actualizar lista de enemigos (llamar en combate)
function WCS_BrainAI:UpdateCombatTargets()
    local now = getTime()
    if (now - self.LastCombatScan) < 0.5 then return end
    self.LastCombatScan = now
    
    -- Registrar target actual
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
        local targetID = self:GetTargetID()
        self:RegisterCombatTarget(targetID)
    end
    
    -- Tambien verificar targettarget si nos ataca algo diferente
    if UnitExists("targettarget") then
        if UnitIsUnit("targettarget", "player") then
            -- El target nos esta atacando, ya lo contamos
        end
    end
end

-- ============================================================================
-- CLASIFICACION DE COMBATE
-- ============================================================================
WCS_BrainAI.CombatType = "normal" -- normal, elite, boss, pvp

function WCS_BrainAI:GetCombatType()
    if not UnitExists("target") then return "idle" end
    
    -- Detectar PvP
    if UnitIsPlayer("target") then
        return "pvp"
    end
    
    -- Detectar clasificacion
    local classification = UnitClassification("target") or "normal"
    
    if classification == "worldboss" then
        return "boss"
    elseif classification == "rareelite" or classification == "elite" then
        return "elite"
    elseif classification == "rare" then
        return "rare"
    else
        return "normal"
    end
end

-- Obtener rotacion optima basada en contexto
function WCS_BrainAI:GetOptimalRotation()
    local combatType = self:GetCombatType()
    local isAoE = self:IsAoESituation()
    local targetHealthPct = 100
    
    if UnitExists("target") then
        local maxHp = UnitHealthMax("target") or 1
        local hp = UnitHealth("target") or 0
        targetHealthPct = (hp / maxHp) * 100
    end
    
    -- Fase de execute
    if targetHealthPct < 25 then
        return "execute"
    end
    
    -- AoE
    if isAoE then
        return "aoe"
    end
    
    -- Por tipo de combate
    if combatType == "boss" then
        return "sustained" -- Todos los DoTs, maximizar uptime
    elseif combatType == "elite" then
        return "standard" -- Rotacion normal completa
    elseif combatType == "pvp" then
        return "pvp" -- Burst + CC
    else
        return "quick" -- Pelea corta, menos DoTs
    end
end

-- ============================================================================
-- SISTEMA DE PUNTUACION (SCORING)
-- ============================================================================
WCS_BrainAI.ScoringWeights = {
    -- Pesos base por tipo de accion
    emergency = 10000,    -- Siempre maxima prioridad
    interrupt = 5000,     -- Muy alta prioridad
    defensive = 3000,     -- Alta prioridad
    dot_missing = 500,    -- DoT no aplicado
    dot_refresh = 300,    -- DoT por expirar
    curse = 400,          -- Curse no aplicada
    synergy = 350,        -- Dark Pact, etc
    filler = 100,         -- Shadow Bolt
    mana = 200,           -- Life Tap
    
    -- Modificadores contextuales
    boss_dot_bonus = 1.5,      -- Bonus a DoTs en boss
    aoe_dot_bonus = 1.3,       -- Bonus a DoTs en AoE
    execute_burst_bonus = 2.0, -- Bonus a burst en execute
    low_mana_penalty = 0.5,    -- Penalidad si bajo mana
    moving_instant_bonus = 2.0 -- Bonus a instants si moviendo
}

-- Calcular puntuacion de una accion
function WCS_BrainAI:ScoreAction(action, context)
    if not action then return 0 end
    
    local score = 0
    local weights = self.ScoringWeights
    local rotation = context.rotation or "standard"
    
    -- Puntuacion base por prioridad
    if action.priority == 1 then -- EMERGENCY
        score = weights.emergency
    elseif action.priority == 2 then -- INTERRUPT
        score = weights.interrupt
    elseif action.priority == 3 then -- DEFENSIVE
        score = weights.defensive
    elseif action.priority == 7 then -- DOTS
        -- USAR SIMULADOR: Calcular valor real del DoT
        local simScore = 0
        if WCS_BrainSim and WCS_BrainSim.GetScore then
            simScore = WCS_BrainSim:GetScore(action.spell)
        end
        
        -- Verificar si es DoT faltante o refresh
        local dotName = action.spell
        local remaining = self:GetDoTTimeRemaining(dotName)
        
        if simScore > 0 then
            -- Convertir DPS del sim a Score (Factor x100 para escala)
            score = simScore * 10 
        else
            -- Fallback si sim falla
            score = 300
        end
        
        if remaining == 0 then
            score = score + 200 -- Bonus por aplicar nuevo
        end
        
    elseif action.priority == 8 then -- CURSE
        score = weights.curse
    elseif action.priority == 6 then -- SYNERGY
        score = weights.synergy
    elseif action.priority == 9 then -- FILLER ("Shadow Bolt", "Searing Pain")
        -- USAR SIMULADOR: El filler compite por DPCT puro
        if WCS_BrainSim and WCS_BrainSim.GetScore then
            local simScore = WCS_BrainSim:GetScore(action.spell)
            if simScore > 0 then
                score = simScore * 10 -- Escala consistente con DoTs
            else
                score = weights.filler
            end
        else
            score = weights.filler
        end
        
    elseif action.priority == 10 then -- MANA
        score = weights.mana
    else
        score = 100 -- Default
    end
    
    -- Aplicar modificadores contextuales
    -- (El resto de la función se mantiene igual para respetar lógica de movimiento/execute)
    
    -- Bonus en boss para DoTs
    if rotation == "sustained" and (action.priority == 7 or action.priority == 8) then
        score = score * weights.boss_dot_bonus
    end
    
    -- Bonus en AoE para DoTs
    if rotation == "aoe" and action.priority == 7 then
        score = score * weights.aoe_dot_bonus
    end
    
    -- Bonus en execute para burst
    if rotation == "execute" then
        if action.spell == "Shadowburn" or action.spell == "Death Coil" then
            score = score * weights.execute_burst_bonus
        end
        -- Penalizar DoTs largos en execute
        if action.spell == "Corruption" or action.spell == "Siphon Life" then
            score = score * 0.5
        end
    end
    
    -- Filtrar hechizos segun movimiento
    if context.isMoving then
        -- Lista de hechizos CON CAST TIME que NO se pueden usar mientras caminas
        -- Es mas seguro listar los que tienen cast time que los instant
        local castTimeSpells = {
            -- Hechizos de daño con cast time
            ["Shadow Bolt"] = true,
            ["Immolate"] = true,
            ["Soul Fire"] = true,
            ["Searing Pain"] = true,
            -- Hechizos canalizados
            ["Drain Life"] = true,
            ["Drain Soul"] = true,
            ["Drain Mana"] = true,
            ["Health Funnel"] = true,
            ["Hellfire"] = true,
            ["Rain of Fire"] = true,
            -- Invocaciones
            ["Summon Imp"] = true,
            ["Summon Voidwalker"] = true,
            ["Summon Succubus"] = true,
            ["Summon Felhunter"] = true,
            ["Summon Felsteed"] = true,
            ["Summon Dreadsteed"] = true,
            ["Ritual of Summoning"] = true,
            -- Otros con cast time
            ["Create Healthstone"] = true,
            ["Create Soulstone"] = true,
            ["Create Firestone"] = true,
            ["Create Spellstone"] = true,
            ["Banish"] = true,
            ["Enslave Demon"] = true,
            ["Shoot"] = true -- Wand tambien requiere estar quieto
        }
        
        if castTimeSpells[action.spell] then
            -- BLOQUEAR completamente hechizos con cast time mientras nos movemos
            score = 0
            debugPrint("Bloqueado " .. (action.spell or "?") .. " - requiere estar quieto")
        else
            -- Bonus a hechizos instant mientras nos movemos
            score = score * weights.moving_instant_bonus
        end
    end
    
    -- Penalizar si bajo mana (excepto mana recovery)
    if context.manaPct and context.manaPct < 20 and action.priority ~= 10 then
        score = score * weights.low_mana_penalty
    end
    
    -- Bonus si el DoT esta por caer (urgencia)
    if action.priority == 7 then
        local remaining = self:GetDoTTimeRemaining(action.spell)
        if remaining > 0 and remaining < 3 then
            score = score * 1.5 -- Urgente refrescar
        end
    end
    
    return score
end

-- ============================================================================
-- RECOLECTAR TODAS LAS ACCIONES CANDIDATAS
-- ============================================================================
function WCS_BrainAI:GetAllCandidateActions()
    local candidates = {}
    local brain = WCS_Brain
    
    if not brain then return candidates end
    
    -- Recolectar todas las acciones posibles
    local actions = {
        brain:CheckEmergency(),
        brain:CheckInterrupt(),
        brain:CheckDefensive(),
        brain:CheckPetSave(),
        brain:CheckPetSynergy(),
        brain:CheckDoTs(),
        brain:CheckCurse(),
        brain:CheckFiller(),
        brain:CheckMana()
    }
    
    -- Filtrar nils y validar
    for i = 1, 9 do
        local action = actions[i]
        if action then
            action = brain:ValidateDecision(action)
            if action then
                table.insert(candidates, action)
            end
        end
    end
    
    return candidates
end

-- ============================================================================
-- OBTENER MEJOR ACCION (REEMPLAZA GetNextAction)
-- ============================================================================
function WCS_BrainAI:GetBestAction()
    local brain = WCS_Brain
    if not brain or not brain.ENABLED then return nil end
    
    -- Actualizar contexto
    brain:UpdateContext()
    self:UpdateCombatTargets()
    self:CleanupExpiredDoTs()
    
    -- No actuar si estamos casteando
    if brain.Context.player.isCasting then return nil end
    if WCS_BrainCore and WCS_BrainCore:IsCasting() then return nil end
    
    -- Construir contexto para scoring
    local context = {
        rotation = self:GetOptimalRotation(),
        combatType = self:GetCombatType(),
        isAoE = self:IsAoESituation(),
        isMoving = brain.Context.player.isMoving,
        healthPct = brain.Context.player.healthPct,
        manaPct = brain.Context.player.manaPct,
        targetHealthPct = brain.Context.target.healthPct,
        enemyCount = self:CountEnemiesInCombat()
    }
    
    -- Obtener todas las acciones candidatas
    local candidates = self:GetAllCandidateActions()
    
    if tableLength(candidates) == 0 then
        return nil
    end
    
    -- Puntuar cada accion
    for i, action in ipairs(candidates) do
        action.score = self:ScoreAction(action, context)
    end
    
    -- Ordenar por puntuacion (mayor primero) - Lua 5.0 compatible
    for i = 1, tableLength(candidates) - 1 do
        for j = i + 1, tableLength(candidates) do
            if candidates[j].score > candidates[i].score then
                local temp = candidates[i]
                candidates[i] = candidates[j]
                candidates[j] = temp
            end
        end
    end
    
    -- Retornar la mejor accion (solo si tiene score > 0)
    local best = candidates[1]
    
    -- No retornar acciones con score 0 (bloqueadas por movimiento u otra razon)
    if best and best.score and best.score <= 0 then
        if brain.DEBUG then
            debugPrint("Accion bloqueada (score=0): " .. (best.spell or "?") .. " - moviendose, solo instants")
        end
        return nil
    end
    
    if best and brain.DEBUG then
        debugPrint("Mejor accion: " .. (best.spell or "?") .. " (score: " .. (best.score or 0) .. ") [" .. context.rotation .. "]")
    end
    
    return best
end

-- ============================================================================
-- INTEGRACION CON WCS_BRAIN
-- ============================================================================
function WCS_BrainAI:Initialize()
    if not WCS_Brain then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[BrainAI]|r Error: WCS_Brain no encontrado")
        return
    end
    
    -- Guardar referencia a la funcion original
    WCS_Brain.OriginalGetNextAction = WCS_Brain.GetNextAction
    
    -- Reemplazar con nuestra version inteligente
    -- Primero consulta a Integration (DQN), si no está activo usa scoring
    WCS_Brain.GetNextAction = function(self)
        local decision = nil
        
        -- Si WCS_BrainIntegration está cargado y DQN activo, usarlo
        if WCS_BrainIntegration and WCS_BrainIntegration.GetDQNAction then
            local dqnAction = WCS_BrainIntegration:GetDQNAction()
            if dqnAction then
                decision = dqnAction
            end
        end
        
        -- Si DQN no está activo o no disponible, usar sistema de scoring
        if not decision then
            decision = WCS_BrainAI:GetBestAction()
        end
        
        -- Guardar para HUD y otros clientes
        self.CurrentDecision = decision
        return decision
    end
    
    -- Hook para registrar DoTs cuando se castean
    local originalExecute = WCS_Brain.Execute
    WCS_Brain.Execute = function(self)
        local action = self:GetNextAction()
        if action and action.spell then
            -- Registrar si es un DoT
            if WCS_BrainAI.DoTDurations[action.spell] then
                WCS_BrainAI:RegisterDoTApplied(action.spell)
            end
        end
        if action and WCS_BrainCore then
            return WCS_BrainCore:ExecuteAction(action)
        end
        return false
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_BrainAI]|r v" .. self.VERSION .. " - Sistema de IA Inteligente cargado")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[BrainAI]|r Sistemas: Scoring, DoT Tracking, Multi-Target, Combat Classification")
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSBRAINAI1 = "/brainai"
SlashCmdList["WCSBRAINAI"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "status" then
        local rotation = WCS_BrainAI:GetOptimalRotation()
        local combatType = WCS_BrainAI:GetCombatType()
        local enemies = WCS_BrainAI:CountEnemiesInCombat()
        local isAoE = WCS_BrainAI:IsAoESituation()
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BrainAI]|r Estado:")
        DEFAULT_CHAT_FRAME:AddMessage("  Rotacion: " .. rotation)
        DEFAULT_CHAT_FRAME:AddMessage("  Tipo combate: " .. combatType)
        DEFAULT_CHAT_FRAME:AddMessage("  Enemigos: " .. enemies .. (isAoE and " (AoE)" or ""))
        
    elseif cmd == "dots" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BrainAI]|r DoTs activos:")
        local targetID = WCS_BrainAI:GetTargetID()
        if targetID and WCS_BrainAI.DoTTimers[targetID] then
            for dotName, data in pairs(WCS_BrainAI.DoTTimers[targetID]) do
                local remaining = WCS_BrainAI:GetDoTTimeRemaining(dotName)
                DEFAULT_CHAT_FRAME:AddMessage("  " .. dotName .. ": " .. string.format("%.1f", remaining) .. "s")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  (ninguno)")
        end
        
    elseif cmd == "test" then
        local best = WCS_BrainAI:GetBestAction()
        if best then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BrainAI]|r Mejor accion: " .. (best.spell or "?") .. " (score: " .. (best.score or 0) .. ")")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BrainAI]|r No hay accion disponible")
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BrainAI]|r Comandos: /brainai status|dots|test")
    end
end

-- Auto-inicializar cuando WCS_Brain este listo
local initFrame = CreateFrame("Frame", "WCS_BrainAI_InitFrame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    -- Esperar un momento para asegurar que WCS_Brain este cargado
    this.elapsed = 0
    this:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 1 then
            this:SetScript("OnUpdate", nil)
            WCS_BrainAI:Initialize()
        end
    end)
end)


