--[[
    WCS_BrainML.lua - Sistema de Machine Learning v6.4.2
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    SISTEMAS INCLUIDOS:
    - Memoria Persistente (SavedVariables)
    - Aprendizaje por Combate
    - Pesos Dinamicos
    - Decay Temporal
    - Estadisticas de Rendimiento
]]--

WCS_BrainML = WCS_BrainML or {}
WCS_BrainML.VERSION = "6.4.2"

-- ============================================================================
-- UTILIDADES LUA 5.0
-- ============================================================================
local function getTime()
    return GetTime and GetTime() or 0
end

local function debugPrint(msg)
    if WCS_Brain and WCS_Brain.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r " .. tostring(msg))
    end
end

-- ============================================================================
-- CONFIGURACION DEL SISTEMA DE APRENDIZAJE
-- ============================================================================
WCS_BrainML.Config = {
    -- Tasa de aprendizaje (que tan rapido cambian los pesos)
    learningRate = 0.1,
    
    -- Decay temporal (half-life en minutos)
    decayHalfLife = 30,
    
    -- Minimo de combates para empezar a ajustar pesos
    minCombatsForLearning = 3,
    
    -- Peso minimo y maximo para evitar extremos
    minWeight = 0.1,
    maxWeight = 3.0,
    
    -- Intervalo de auto-guardado (segundos)
    autoSaveInterval = 300, -- 5 minutos
    
    -- Maximo de registros de combate a guardar
    maxCombatHistory = 100
}

-- ============================================================================
-- ESTRUCTURA DE DATOS PERSISTENTE
-- ============================================================================
-- Esta estructura se guarda en WCS_BrainSaved
WCS_BrainML.DefaultData = {
    version = "1.0.0",
    
    -- Pesos dinamicos por hechizo (modifican el scoring)
    spellWeights = {
        -- Formato: [spellName] = weight (1.0 = neutral)
        ["Shadow Bolt"] = 1.0,
        ["Corruption"] = 1.0,
        ["Curse of Agony"] = 1.0,
        ["Immolate"] = 1.0,
        ["Siphon Life"] = 1.0,
        ["Life Tap"] = 1.0,
        ["Dark Pact"] = 1.0,
        ["Drain Life"] = 1.0,
        ["Death Coil"] = 1.0,
        ["Fear"] = 1.0,
        ["Shadowburn"] = 1.0,
        ["Conflagrate"] = 1.0,
        ["Health Funnel"] = 1.0
    },
    
    -- Estadisticas por hechizo
    spellStats = {
        -- Formato: [spellName] = {casts, successes, totalDamage, avgDamage}
    },
    
    -- Historial de combates
    combatHistory = {
        -- Formato: {timestamp, duration, dps, survived, spellsUsed, context}
    },
    
    -- Estadisticas globales
    globalStats = {
        totalCombats = 0,
        wins = 0,
        losses = 0,
        totalDamage = 0,
        totalTime = 0,
        avgDPS = 0,
        lastUpdate = 0
    },
    
    -- Pesos por contexto (fase de combate)
    contextWeights = {
        ["opener"] = {},
        ["sustain"] = {},
        ["execute"] = {},
        ["emergency"] = {},
        ["aoe"] = {}
    }
}

-- Datos en memoria (cargados de SavedVariables)
WCS_BrainML.Data = nil

-- ============================================================================
-- TRACKING DE COMBATE ACTUAL
-- ============================================================================
WCS_BrainML.CurrentCombat = {
    active = false,
    startTime = 0,
    startHealth = 100,
    startMana = 100,
    spellsCast = {},      -- {spellName = count}
    damageDealt = 0,
    damageTaken = 0,
    context = "sustain",
    targetType = "normal"
}

-- ============================================================================
-- INICIALIZACION Y PERSISTENCIA
-- ============================================================================

function WCS_BrainML:Initialize()
    -- Cargar datos guardados o usar defaults
    if WCS_BrainSaved and WCS_BrainSaved.ML then
        self.Data = WCS_BrainSaved.ML
        debugPrint("Datos ML cargados desde SavedVariables")
        
        -- Migrar si es version antigua
        self:MigrateData()
    else
        self.Data = self:DeepCopy(self.DefaultData)
        debugPrint("Usando datos ML por defecto")
    end
    
    -- Asegurar que WCS_BrainSaved existe
    if not WCS_BrainSaved then
        WCS_BrainSaved = {}
    end
    
    -- Registrar eventos
    self:RegisterEvents()
    
    -- Integrar con WCS_BrainAI si existe
    self:IntegrateWithBrainAI()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_BrainML]|r v" .. self.VERSION .. " - Sistema de Aprendizaje cargado")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[BrainML]|r Combates registrados: " .. (self.Data.globalStats.totalCombats or 0))
end

function WCS_BrainML:ToggleUI()
    -- Por ahora, solo mostrar un mensaje
    -- En el futuro se puede crear una UI dedicada para ML
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r UI de Machine Learning no implementada aún")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Usa /brain status para ver estadísticas")
    
    -- Mostrar estadísticas básicas
    if self.Data and self.Data.globalStats then
        local stats = self.Data.globalStats
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ML Stats]|r Combates: " .. (stats.totalCombats or 0))
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ML Stats]|r Victorias: " .. (stats.wins or 0))
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ML Stats]|r DPS Promedio: " .. string.format("%.1f", stats.avgDPS or 0))
    end
end

function WCS_BrainML:DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = self:DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

function WCS_BrainML:MigrateData()
    -- Migrar datos de versiones anteriores si es necesario
    if not self.Data.version then
        self.Data.version = "1.0.0"
    end
    
    -- Asegurar que todas las estructuras existen
    if not self.Data.spellWeights then
        self.Data.spellWeights = self:DeepCopy(self.DefaultData.spellWeights)
    end
    if not self.Data.spellStats then
        self.Data.spellStats = {}
    end
    if not self.Data.combatHistory then
        self.Data.combatHistory = {}
    end
    if not self.Data.globalStats then
        self.Data.globalStats = self:DeepCopy(self.DefaultData.globalStats)
    end
    if not self.Data.contextWeights then
        self.Data.contextWeights = self:DeepCopy(self.DefaultData.contextWeights)
    end
end

function WCS_BrainML:Save()
    if not self.Data then return end
    
    -- Actualizar timestamp
    self.Data.globalStats.lastUpdate = time()
    
    -- Guardar en SavedVariables
    WCS_BrainSaved.ML = self.Data
    
    debugPrint("Datos ML guardados")
end

-- ============================================================================
-- REGISTRO DE EVENTOS
-- ============================================================================

function WCS_BrainML:RegisterEvents()
    if self.EventFrame then return end
    
    self.EventFrame = CreateFrame("Frame", "WCS_BrainML_EventFrame")
    
    -- Eventos de combate
    self.EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entramos en combate
    self.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Salimos de combate
    self.EventFrame:RegisterEvent("PLAYER_DEAD")           -- Morimos
    self.EventFrame:RegisterEvent("PLAYER_LOGOUT")         -- Guardar al salir
    self.EventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")  -- Guardar al cambiar zona
    
    -- Eventos de dano (para tracking)
    self.EventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    self.EventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
    
    -- Eventos de casteo manual del jugador (para aprender de decisiones)
    self.EventFrame:RegisterEvent("SPELLCAST_START")       -- Inicio de casteo
    self.EventFrame:RegisterEvent("SPELLCAST_STOP")        -- Casteo completado
    self.EventFrame:RegisterEvent("SPELLCAST_FAILED")      -- Casteo fallido
    self.EventFrame:RegisterEvent("SPELLCAST_INTERRUPTED") -- Casteo interrumpido
    
    -- Eventos adicionales para capturar hechizos instantaneos
    self.EventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")  -- Buffs propios (Life Tap, etc)
    
    self.EventFrame:SetScript("OnEvent", function()
        WCS_BrainML:OnEvent(event, arg1, arg2, arg3)
    end)
    
    -- Timer para auto-guardado
    self.LastAutoSave = getTime()
    self.EventFrame:SetScript("OnUpdate", function()
        WCS_BrainML:OnUpdate(arg1)
    end)
end

function WCS_BrainML:OnEvent(event, arg1, arg2, arg3)
    if event == "PLAYER_REGEN_DISABLED" then
        self:StartCombat()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:EndCombat(true) -- Sobrevivimos
        
    elseif event == "PLAYER_DEAD" then
        self:EndCombat(false) -- Morimos
        
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        self:Save()
        
    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        self:ParseDamageMessage(arg1)
    
    -- Eventos de casteo manual
    -- En WoW Vanilla, SPELLCAST_START no pasa el nombre del hechizo
    -- Hay que leerlo de CastingBarFrame.spellName o de la barra de casteo
    elseif event == "SPELLCAST_START" then
        local spellName = self:GetCurrentCastingSpell()
        if spellName then
            self:OnManualCastStart(spellName)
            -- Tambien registrar para el combate actual
            self:RegisterSpellCast(spellName)
        end
    elseif event == "SPELLCAST_STOP" then
        self:OnManualCastComplete()
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        self:OnManualCastFailed()
    
    -- Capturar hechizos instantaneos via mensajes de chat
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" then
        self:ParseSelfBuffMessage(arg1)
    end
end

-- Parsear mensajes de buffs propios para detectar hechizos instantaneos
function WCS_BrainML:ParseSelfBuffMessage(msg)
    if not msg then return end
    
    local spellName = nil
    local _, _, s
    
    -- Patron: "You gain X" o "Ganas X"
    _, _, s = string.find(msg, "You cast ([%w%s]+)")
    if s then spellName = s end
    
    if not spellName then
        _, _, s = string.find(msg, "You gain ([%w%s]+)")
        if s then spellName = s end
    end
    
    -- Patron espanol
    if not spellName then
        _, _, s = string.find(msg, "Lanzas ([%w%s]+)")
        if s then spellName = s end
    end
    
    if spellName then
        -- Limpiar el nombre (quitar puntos, numeros de rango, etc)
        spellName = string.gsub(spellName, "%.$", "")
        spellName = string.gsub(spellName, "%s*%(%d+%)$", "")
        
        -- Registrar si es un hechizo conocido de Warlock
        local warlockSpells = {
            ["Life Tap"] = true,
            ["Dark Pact"] = true,
            ["Corruption"] = true,
            ["Curse of Agony"] = true,
            ["Curse of Doom"] = true,
            ["Curse of Tongues"] = true,
            ["Curse of Weakness"] = true,
            ["Curse of the Elements"] = true,
            ["Curse of Shadow"] = true,
            ["Siphon Life"] = true,
            ["Death Coil"] = true,
            ["Shadowburn"] = true,
            ["Conflagrate"] = true
        }
        
        if warlockSpells[spellName] then
            self:RegisterSpellCast(spellName)
            debugPrint("Instant detectado: " .. spellName)
        end
    end
end

-- Obtener el nombre del hechizo que se esta casteando actualmente
function WCS_BrainML:GetCurrentCastingSpell()
    -- Metodo 1: CastingBarFrame (mas confiable)
    if CastingBarFrame and CastingBarFrame:IsVisible() then
        -- En algunos clientes el nombre esta en .spellName
        if CastingBarFrame.spellName then
            return CastingBarFrame.spellName
        end
        -- En otros esta en el texto de la barra
        if CastingBarFrameText then
            local text = CastingBarFrameText:GetText()
            if text and text ~= "" then
                return text
            end
        end
    end
    
    -- Metodo 2: Variable global (algunos addons la setean)
    if CURRENT_SPELL_NAME then
        return CURRENT_SPELL_NAME
    end
    
    return nil
end

function WCS_BrainML:OnUpdate(elapsed)
    -- Auto-guardado periodico
    local now = getTime()
    
    -- Inicializar LastAutoSave si no existe (fix para llamadas antes de Initialize)
    if not self.LastAutoSave then
        self.LastAutoSave = now
        return
    end

    if (now - self.LastAutoSave) > self.Config.autoSaveInterval then
        self.LastAutoSave = now
        self:Save()
    end
end

-- ============================================================================
-- TRACKING DE COMBATE
-- ============================================================================

function WCS_BrainML:StartCombat()
    local ctx = WCS_Brain and WCS_Brain.Context or {}
    
    self.CurrentCombat = {
        active = true,
        startTime = getTime(),
        startHealth = ctx.player and ctx.player.healthPct or 100,
        startMana = ctx.player and ctx.player.manaPct or 100,
        spellsCast = {},
        damageDealt = 0,
        damageTaken = 0,
        context = WCS_BrainAI and WCS_BrainAI:GetOptimalRotation() or "sustain",
        targetType = WCS_BrainAI and WCS_BrainAI:GetCombatType() or "normal"
    }
    
    debugPrint("Combate iniciado - Contexto: " .. self.CurrentCombat.context)
end

function WCS_BrainML:EndCombat(survived)
    if not self.CurrentCombat.active then return end
    
    local combat = self.CurrentCombat
    combat.active = false
    
    local duration = getTime() - combat.startTime
    
    -- Ignorar combates muy cortos (menos de 3 segundos)
    if duration < 3 then
        debugPrint("Combate ignorado (muy corto)")
        return
    end
    
    -- Calcular metricas
    local dps = 0
    if duration > 0 then
        dps = combat.damageDealt / duration
    end
    
    -- Registrar resultado
    local result = {
        timestamp = time(),
        duration = duration,
        dps = dps,
        survived = survived,
        spellsUsed = combat.spellsCast,
        context = combat.context,
        targetType = combat.targetType,
        damageDealt = combat.damageDealt,
        healthLost = combat.startHealth - (WCS_Brain and WCS_Brain.Context.player.healthPct or 100)
    }
    
    -- Agregar al historial
    table.insert(self.Data.combatHistory, result)
    
    -- Limitar tamano del historial
    while WCS_TableCount(self.Data.combatHistory) > self.Config.maxCombatHistory do
        table.remove(self.Data.combatHistory, 1)
    end
    
    -- Actualizar estadisticas globales
    self.Data.globalStats.totalCombats = self.Data.globalStats.totalCombats + 1
    if survived then
        self.Data.globalStats.wins = self.Data.globalStats.wins + 1
    else
        self.Data.globalStats.losses = self.Data.globalStats.losses + 1
    end
    self.Data.globalStats.totalDamage = self.Data.globalStats.totalDamage + combat.damageDealt
    self.Data.globalStats.totalTime = self.Data.globalStats.totalTime + duration
    
    -- Recalcular DPS promedio
    if self.Data.globalStats.totalTime > 0 then
        self.Data.globalStats.avgDPS = self.Data.globalStats.totalDamage / self.Data.globalStats.totalTime
    end
    
    -- Aprender de este combate
    self:LearnFromCombat(result)
    
    debugPrint("Combate terminado - " .. (survived and "Victoria" or "Derrota") .. " - DPS: " .. string.format("%.1f", dps))
    
    -- Auto-guardar despues de cada combate
    self:Save()
end

-- ============================================================================
-- REGISTRO DE HECHIZOS USADOS
-- ============================================================================

function WCS_BrainML:RegisterSpellCast(spellName)
    if not self.CurrentCombat.active then return end
    if not spellName then return end
    
    -- Incrementar contador de uso
    if not self.CurrentCombat.spellsCast[spellName] then
        self.CurrentCombat.spellsCast[spellName] = 0
    end
    self.CurrentCombat.spellsCast[spellName] = self.CurrentCombat.spellsCast[spellName] + 1
    
    -- Actualizar estadisticas globales del hechizo
    if not self.Data.spellStats[spellName] then
        self.Data.spellStats[spellName] = {
            casts = 0,
            successes = 0,
            totalDamage = 0,
            avgDamage = 0
        }
    end
    self.Data.spellStats[spellName].casts = self.Data.spellStats[spellName].casts + 1
end

function WCS_BrainML:RegisterSpellDamage(spellName, damage)
    if not spellName or not damage then return end
    
    -- Actualizar dano del combate actual
    if self.CurrentCombat.active then
        self.CurrentCombat.damageDealt = self.CurrentCombat.damageDealt + damage
    end
    
    -- Actualizar estadisticas del hechizo
    if self.Data.spellStats[spellName] then
        local stats = self.Data.spellStats[spellName]
        stats.totalDamage = stats.totalDamage + damage
        if stats.casts > 0 then
            stats.avgDamage = stats.totalDamage / stats.casts
        end
    end
end

-- ============================================================================
-- APRENDIZAJE DE DECISIONES MANUALES DEL JUGADOR
-- ============================================================================

-- Almacena el hechizo que el jugador esta casteando manualmente
WCS_BrainML.PendingManualCast = nil
WCS_BrainML.ManualCastContext = nil

function WCS_BrainML:OnManualCastStart(spellName)
    if not spellName then return end
    
    -- Guardar el hechizo y el contexto actual
    self.PendingManualCast = spellName
    
    -- Capturar contexto actual para aprender
    local ctx = WCS_Brain and WCS_Brain.Context or {}
    self.ManualCastContext = {
        phase = ctx.phase or "idle",
        playerHP = ctx.player and ctx.player.healthPct or 100,
        playerMana = ctx.player and ctx.player.manaPct or 100,
        targetHP = ctx.target and ctx.target.healthPct or 100,
        targetExists = ctx.target and ctx.target.exists or false,
        inCombat = UnitAffectingCombat("player"),
        isMoving = ctx.player and ctx.player.isMoving or false,
        timestamp = getTime()
    }
    
    debugPrint("Casteo manual detectado: " .. spellName)
end

function WCS_BrainML:OnManualCastComplete()
    if not self.PendingManualCast then return end
    
    local spellName = self.PendingManualCast
    local context = self.ManualCastContext
    
    -- Registrar el casteo exitoso
    self:RegisterManualDecision(spellName, context, true)
    
    -- Limpiar
    self.PendingManualCast = nil
    self.ManualCastContext = nil
end

function WCS_BrainML:OnManualCastFailed()
    -- Limpiar sin registrar (el casteo fallo)
    if self.PendingManualCast then
        debugPrint("Casteo manual fallido: " .. self.PendingManualCast)
    end
    self.PendingManualCast = nil
    self.ManualCastContext = nil
end

function WCS_BrainML:RegisterManualDecision(spellName, context, success)
    if not spellName or not context then return end
    
    -- Inicializar estructura de decisiones manuales si no existe
    if not self.Data.manualDecisions then
        self.Data.manualDecisions = {}
    end
    
    -- Inicializar para este hechizo
    if not self.Data.manualDecisions[spellName] then
        self.Data.manualDecisions[spellName] = {
            totalCasts = 0,
            contexts = {
                emergency = 0,  -- HP < 30%
                execute = 0,    -- Target HP < 25%
                sustain = 0,    -- Normal combat
                opener = 0,     -- Inicio de combate
                moving = 0      -- Mientras se mueve
            },
            avgPlayerHP = 0,
            avgTargetHP = 0,
            successRate = 0
        }
    end
    
    local data = self.Data.manualDecisions[spellName]
    data.totalCasts = data.totalCasts + 1
    
    -- Clasificar el contexto
    if context.playerHP < 30 then
        data.contexts.emergency = data.contexts.emergency + 1
    elseif context.targetHP < 25 and context.targetExists then
        data.contexts.execute = data.contexts.execute + 1
    elseif context.isMoving then
        data.contexts.moving = data.contexts.moving + 1
    elseif not context.inCombat then
        data.contexts.opener = data.contexts.opener + 1
    else
        data.contexts.sustain = data.contexts.sustain + 1
    end
    
    -- Actualizar promedios
    local n = data.totalCasts
    data.avgPlayerHP = ((data.avgPlayerHP * (n-1)) + context.playerHP) / n
    data.avgTargetHP = ((data.avgTargetHP * (n-1)) + context.targetHP) / n
    
    -- Aumentar peso del hechizo (el jugador lo prefiere)
    self:AdjustWeightFromManual(spellName, context)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[BrainML]|r Aprendido: |cFFFFCC00" .. spellName .. "|r en contexto " .. context.phase)
end

function WCS_BrainML:AdjustWeightFromManual(spellName, context)
    if not self.Data.spellWeights[spellName] then
        self.Data.spellWeights[spellName] = 1.0
    end
    
    local currentWeight = self.Data.spellWeights[spellName]
    local adjustment = self.Config.learningRate * 0.5 -- Ajuste mas suave para decisiones manuales
    
    -- Aumentar peso (el jugador eligio este hechizo)
    local newWeight = currentWeight + adjustment
    
    -- Bonus si fue en un contexto especifico
    if context.phase == "emergency" and context.playerHP < 30 then
        -- El jugador uso este hechizo en emergencia, darle mas peso en emergencias
        newWeight = newWeight + adjustment
    end
    
    -- Limitar
    if newWeight > self.Config.maxWeight then
        newWeight = self.Config.maxWeight
    end
    
    self.Data.spellWeights[spellName] = newWeight
    
    debugPrint("Peso ajustado: " .. spellName .. " = " .. string.format("%.2f", newWeight))
end

-- Funcion para ver estadisticas de decisiones manuales
function WCS_BrainML:GetManualStats(spellName)
    if not self.Data.manualDecisions then return nil end
    if spellName then
        return self.Data.manualDecisions[spellName]
    end
    return self.Data.manualDecisions
end

-- ============================================================================
-- PARSING DE MENSAJES DE DANO
-- ============================================================================

function WCS_BrainML:ParseDamageMessage(msg)
    if not msg then return end
    
    local spell, damage
    local _, _, s, d
    
    -- Patrones en ingles
    -- "Your Shadow Bolt hits Target for 500."
    _, _, s, d = string.find(msg, "Your ([%w%s]+) hits .+ for (%d+)")
    if s and d then
        spell = s
        damage = d
    end
    
    if not spell then
        -- "Your Shadow Bolt crits Target for 1000."
        _, _, s, d = string.find(msg, "Your ([%w%s]+) crits .+ for (%d+)")
        if s and d then
            spell = s
            damage = d
        end
    end
    
    -- Patrones en espanol
    if not spell then
        -- "Tu Descarga de las Sombras golpea a Objetivo por 500."
        _, _, s, d = string.find(msg, "Tu ([%w%s]+) golpea .+ por (%d+)")
        if s and d then
            spell = s
            damage = d
        end
    end
    
    if not spell then
        -- "Tu Descarga de las Sombras causa un golpe critico a Objetivo por 1000."
        _, _, s, d = string.find(msg, "Tu ([%w%s]+) causa .+ por (%d+)")
        if s and d then
            spell = s
            damage = d
        end
    end
    
    if spell and damage then
        damage = tonumber(damage) or 0
        self:RegisterSpellDamage(spell, damage)
    end
end

-- ============================================================================
-- SISTEMA DE APRENDIZAJE
-- ============================================================================

function WCS_BrainML:LearnFromCombat(result)
    -- No aprender si no tenemos suficientes combates
    if self.Data.globalStats.totalCombats < self.Config.minCombatsForLearning then
        return
    end
    
    local learningRate = self.Config.learningRate
    
    -- Calcular "exito" del combate (0 a 1)
    local success = 0
    
    -- Factor 1: Sobrevivir (40% del peso)
    if result.survived then
        success = success + 0.4
    end
    
    -- Factor 2: DPS relativo al promedio (30% del peso)
    local avgDPS = self.Data.globalStats.avgDPS
    if avgDPS > 0 and result.dps > 0 then
        local dpsRatio = result.dps / avgDPS
        -- Normalizar entre 0 y 0.3
        success = success + math.min(0.3, dpsRatio * 0.15)
    end
    
    -- Factor 3: Eficiencia (poca vida perdida) (30% del peso)
    local healthEfficiency = 1 - (result.healthLost / 100)
    if healthEfficiency < 0 then healthEfficiency = 0 end
    success = success + (healthEfficiency * 0.3)
    
    debugPrint("Score de combate: " .. string.format("%.2f", success))
    
    -- Ajustar pesos de los hechizos usados
    for spellName, count in pairs(result.spellsUsed) do
        self:AdjustSpellWeight(spellName, success, count, result.context)
    end
end

function WCS_BrainML:AdjustSpellWeight(spellName, success, usageCount, context)
    if not self.Data.spellWeights[spellName] then
        self.Data.spellWeights[spellName] = 1.0
    end
    
    local currentWeight = self.Data.spellWeights[spellName]
    local learningRate = self.Config.learningRate
    
    -- Calcular ajuste basado en exito
    -- success > 0.5 = aumentar peso, success < 0.5 = disminuir
    local adjustment = (success - 0.5) * learningRate
    
    -- Escalar por cantidad de usos (mas usos = mas confianza en el ajuste)
    local usageFactor = math.min(1.0, usageCount / 5)
    adjustment = adjustment * usageFactor
    
    -- Aplicar ajuste
    local newWeight = currentWeight + adjustment
    
    -- Limitar a rango valido
    newWeight = math.max(self.Config.minWeight, math.min(self.Config.maxWeight, newWeight))
    
    self.Data.spellWeights[spellName] = newWeight
    
    -- Tambien guardar peso por contexto
    if context and self.Data.contextWeights[context] then
        if not self.Data.contextWeights[context][spellName] then
            self.Data.contextWeights[context][spellName] = 1.0
        end
        -- Ajuste mas agresivo para contexto especifico
        local contextAdjustment = adjustment * 1.5
        local contextWeight = self.Data.contextWeights[context][spellName] + contextAdjustment
        contextWeight = math.max(self.Config.minWeight, math.min(self.Config.maxWeight, contextWeight))
        self.Data.contextWeights[context][spellName] = contextWeight
    end
    
    if WCS_Brain and WCS_Brain.DEBUG then
        debugPrint(spellName .. ": " .. string.format("%.2f", currentWeight) .. " -> " .. string.format("%.2f", newWeight))
    end
end

-- ============================================================================
-- DECAY TEMPORAL
-- ============================================================================

function WCS_BrainML:ApplyDecay()
    local now = time()
    local halfLife = self.Config.decayHalfLife * 60 -- Convertir a segundos
    
    -- Aplicar decay a los pesos (acercarlos a 1.0)
    for spellName, weight in pairs(self.Data.spellWeights) do
        if weight ~= 1.0 then
            -- Calcular decay basado en tiempo desde ultima actualizacion
            local timeSinceUpdate = now - (self.Data.globalStats.lastUpdate or now)
            local decayFactor = math.pow(0.5, timeSinceUpdate / halfLife)
            
            -- Mover peso hacia 1.0
            local diff = weight - 1.0
            local newWeight = 1.0 + (diff * decayFactor)
            
            self.Data.spellWeights[spellName] = newWeight
        end
    end
    
    debugPrint("Decay temporal aplicado")
end

-- ============================================================================
-- INTEGRACION CON WCS_BRAINAI
-- ============================================================================

function WCS_BrainML:IntegrateWithBrainAI()
    if not WCS_BrainAI then
        debugPrint("WCS_BrainAI no encontrado, integracion pendiente")
        return
    end
    
    -- Guardar referencia a la funcion original de scoring
    local originalScoreAction = WCS_BrainAI.ScoreAction
    
    -- Reemplazar con nuestra version que aplica pesos aprendidos
    WCS_BrainAI.ScoreAction = function(ai, action, context)
        -- Obtener score base
        local baseScore = originalScoreAction(ai, action, context)
        
        if not action or not action.spell then
            return baseScore
        end
        
        -- Aplicar peso aprendido
        local spellWeight = WCS_BrainML:GetSpellWeight(action.spell, context.rotation)
        local finalScore = baseScore * spellWeight
        
        return finalScore
    end
    
    -- Hook para registrar hechizos casteados deshabilitado
    -- (WCS_BrainAI ya hace el hook, evitamos duplicados)
    
    debugPrint("Integrado con WCS_BrainAI")
end

function WCS_BrainML:GetSpellWeight(spellName, context)
    if not self.Data then return 1.0 end
    
    -- Primero buscar peso especifico del contexto
    if context and self.Data.contextWeights[context] then
        local contextWeight = self.Data.contextWeights[context][spellName]
        if contextWeight then
            return contextWeight
        end
    end
    
    -- Fallback a peso global
    return self.Data.spellWeights[spellName] or 1.0
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================

SLASH_WCSBRAINML1 = "/brainml"
SlashCmdList["WCSBRAINML"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "stats" then
        local stats = WCS_BrainML.Data.globalStats
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Estadisticas Globales:")
        DEFAULT_CHAT_FRAME:AddMessage("  Combates: " .. stats.totalCombats)
        DEFAULT_CHAT_FRAME:AddMessage("  Victorias: " .. stats.wins .. " (" .. string.format("%.1f", (stats.wins / math.max(1, stats.totalCombats)) * 100) .. "%)")
        DEFAULT_CHAT_FRAME:AddMessage("  Derrotas: " .. stats.losses)
        DEFAULT_CHAT_FRAME:AddMessage("  DPS Promedio: " .. string.format("%.1f", stats.avgDPS))
        DEFAULT_CHAT_FRAME:AddMessage("  Tiempo Total: " .. string.format("%.1f", stats.totalTime / 60) .. " min")
        
    elseif cmd == "weights" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Pesos de Hechizos:")
        for spell, weight in pairs(WCS_BrainML.Data.spellWeights) do
            local color = "|cFFFFFFFF"
            if weight > 1.1 then
                color = "|cFF00FF00" -- Verde = bueno
            elseif weight < 0.9 then
                color = "|cFFFF0000" -- Rojo = malo
            end
            DEFAULT_CHAT_FRAME:AddMessage("  " .. spell .. ": " .. color .. string.format("%.2f", weight) .. "|r")
        end
        
    elseif cmd == "spells" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Estadisticas de Hechizos:")
        for spell, stats in pairs(WCS_BrainML.Data.spellStats) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. spell .. ": " .. stats.casts .. " casts, " .. string.format("%.0f", stats.avgDamage) .. " avg dmg")
        end
        
    elseif cmd == "reset" then
        WCS_BrainML.Data = WCS_BrainML:DeepCopy(WCS_BrainML.DefaultData)
        WCS_BrainML:Save()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Datos reseteados")
        
    elseif cmd == "save" then
        WCS_BrainML:Save()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Datos guardados manualmente")
        
    elseif cmd == "decay" then
        WCS_BrainML:ApplyDecay()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Decay temporal aplicado")
        
    elseif cmd == "history" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Ultimos 5 combates:")
        local history = WCS_BrainML.Data.combatHistory
        local count = WCS_TableCount(history)
        local start = math.max(1, count - 4)
        for i = start, count do
            local c = history[i]
            if c then
                local status = c.survived and "|cFF00FF00Win|r" or "|cFFFF0000Loss|r"
                DEFAULT_CHAT_FRAME:AddMessage("  " .. status .. " - DPS: " .. string.format("%.1f", c.dps) .. " - " .. string.format("%.0f", c.duration) .. "s - " .. c.context)
            end
        end
        
    elseif cmd == "manual" or cmd == "decisions" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Decisiones Manuales Aprendidas:")
        if WCS_BrainML.Data.manualDecisions then
            for spell, data in pairs(WCS_BrainML.Data.manualDecisions) do
                DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00" .. spell .. "|r: " .. data.totalCasts .. " usos")
                DEFAULT_CHAT_FRAME:AddMessage("    Contextos: E:" .. data.contexts.emergency .. " X:" .. data.contexts.execute .. " S:" .. data.contexts.sustain .. " O:" .. data.contexts.opener .. " M:" .. data.contexts.moving)
                DEFAULT_CHAT_FRAME:AddMessage("    HP Prom: " .. string.format("%.0f", data.avgPlayerHP) .. "% | Target: " .. string.format("%.0f", data.avgTargetHP) .. "%")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  Sin datos aun. Castea hechizos manualmente para que aprenda.")
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[BrainML]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml stats - Ver estadisticas globales")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml weights - Ver pesos de hechizos")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml spells - Ver stats de hechizos")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml manual - Ver decisiones manuales aprendidas")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml history - Ver ultimos combates")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml decay - Aplicar decay temporal")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml save - Guardar manualmente")
        DEFAULT_CHAT_FRAME:AddMessage("  /brainml reset - Resetear todos los datos")
    end
end

-- ============================================================================
-- AUTO-INICIALIZACION
-- ============================================================================

local initFrame = CreateFrame("Frame", "WCS_BrainML_InitFrame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    -- Esperar a que otros sistemas carguen
    this.elapsed = 0
    this:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 1.5 then
            this:SetScript("OnUpdate", nil)
            WCS_BrainML:Initialize()
        end
    end)
end)

-- Resetea los datos de aprendizaje y estadísticas globales
function WCS_BrainML:ResetStats()
    self.Data = self:DeepCopy(self.DefaultData)
    WCS_BrainSaved.ML = self.Data
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[BrainML]|r Estadísticas de aprendizaje reseteadas.")
end

-- ============================================================================
-- INTERFAZ DE USUARIO (Tab 4: Aprendizaje ML)
-- ============================================================================
function WCS_BrainML:CreateUI()
    if _G["WCSBrainMLFrame"] then return end

    local f = CreateFrame("Frame", "WCSBrainMLFrame", UIParent)
    f:SetWidth(680)
    f:SetHeight(540)
    f:Hide()

    -- Fondo principal
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.04, 0.02, 0.10, 0.95)
    f:SetBackdropBorderColor(0.58, 0.51, 0.79, 0.9)

    -- Título
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("|cFFCC99FFMACHINE LEARNING ENGINE|r")

    -- Columna Izquierda: Estadísticas Globales
    local leftPanel = CreateFrame("Frame", nil, f)
    leftPanel:SetWidth(320)
    leftPanel:SetHeight(460)
    leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -45)
    leftPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    leftPanel:SetBackdropColor(0.08, 0.05, 0.15, 0.85)
    leftPanel:SetBackdropBorderColor(0.58, 0.51, 0.79, 0.7)

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOP", leftPanel, "TOP", 0, -12)
    leftTitle:SetText("|cFFFFCC00Rendimiento de Combate|r")

    local statLabels = {
        {key = "totalCombats", label = "|cFFAAAAAACombates Tot.:|r", color = "FFFFFF"},
        {key = "wins", label = "|cFF00FF00Victorias:|r", color = "00FF00"},
        {key = "losses", label = "|cFFFF4444Derrotas:|r", color = "FF4444"},
        {key = "avgDPS", label = "|cFFFFAA00DPS Promedio:|r", color = "FFAA00"},
        {key = "totalDamage", label = "|cFFFF8888Daño Total:|r", color = "FF8888"},
        {key = "totalTime", label = "|cFF8888FFT. Combate:|r", color = "8888FF"},
    }

    f.statTexts = {}
    for i, item in ipairs(statLabels) do
        local lbl = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -30 - (i - 1) * 22)
        lbl:SetText(item.label)

        local val = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 160, -30 - (i - 1) * 22)
        val:SetText("|cFF" .. item.color .. "0|r")

        f.statTexts[item.key] = val
    end

    -- Tasa de aprendizaje y configuración
    local configSep = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    configSep:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -175)
    configSep:SetText("|cFFCC99FFConfiguración de Aprendizaje|r")

    local lrLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lrLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -200)
    lrLabel:SetText("|cFFAAAAAATasa de Aprendizaje:|r")

    local lrSlider = CreateFrame("Slider", "WCS_BrainMLLRSlider", leftPanel, "OptionsSliderTemplate")
    lrSlider:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -225)
    lrSlider:SetWidth(280)
    lrSlider:SetMinMaxValues(0.01, 0.5)
    lrSlider:SetValueStep(0.01)
    lrSlider:SetValue(WCS_BrainML.Config.learningRate)

    _G[lrSlider:GetName().."Text"]:SetText("")
    _G[lrSlider:GetName().."Low"]:SetText("0.01")
    _G[lrSlider:GetName().."High"]:SetText("0.5")

    local lrValText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lrValText:SetPoint("TOP", lrSlider, "BOTTOM", 0, -3)
    lrValText:SetText(string.format("|cFFFFCC00%.2f|r", WCS_BrainML.Config.learningRate))

    lrSlider:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        WCS_BrainML.Config.learningRate = v
        lrValText:SetText(string.format("|cFFFFCC00%.2f|r", v))
    end)

    -- Botón Reset Stats
    local resetBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("BOTTOM", leftPanel, "BOTTOM", 0, 15)
    resetBtn:SetWidth(160)
    resetBtn:SetHeight(24)
    resetBtn:SetText("|cFFFF6666Reset Estadísticas|r")
    resetBtn:SetScript("OnClick", function()
        WCS_BrainML:ResetStats()
        if f:IsVisible() then
            -- Refrescar UI
        end
    end)

    -- Columna Derecha: Top Hechizos
    local rightPanel = CreateFrame("Frame", nil, f)
    rightPanel:SetWidth(320)
    rightPanel:SetHeight(460)
    rightPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -45)
    rightPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    rightPanel:SetBackdropColor(0.08, 0.05, 0.15, 0.85)
    rightPanel:SetBackdropBorderColor(0.0, 1.0, 0.5, 0.7)

    local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightTitle:SetPoint("TOP", rightPanel, "TOP", 0, -12)
    rightTitle:SetText("|cFF00FF80Pesos de Hechizos Aprendidos|r")

    -- 12 filas de hechizos con su peso
    f.spellRows = {}
    for i = 1, 12 do
        local nameTxt = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameTxt:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -30 - (i - 1) * 32)
        nameTxt:SetText("|cFF666666------|r")
        nameTxt:SetWidth(160)

        local weightBar = CreateFrame("StatusBar", nil, rightPanel)
        weightBar:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -42 - (i - 1) * 32)
        weightBar:SetWidth(280)
        weightBar:SetHeight(8)
        weightBar:SetMinMaxValues(0, 3)
        weightBar:SetValue(1)
        weightBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        weightBar:SetStatusBarColor(0.58, 0.51, 0.79, 1)

        f.spellRows[i] = { name = nameTxt, bar = weightBar }
    end

    -- OnUpdate: refrescar datos cada segundo
    local elapsed = 0
    f:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed < 1.0 then return end
        elapsed = 0

        if not f:IsVisible() then return end
        if not WCS_BrainML.Data then return end

        -- Actualizar estadísticas globales
        local stats = WCS_BrainML.Data.globalStats
        if f.statTexts["totalCombats"] then
            f.statTexts["totalCombats"]:SetText("|cFFFFFFFF" .. (stats.totalCombats or 0) .. "|r")
        end
        if f.statTexts["wins"] then
            f.statTexts["wins"]:SetText("|cFF00FF00" .. (stats.wins or 0) .. "|r")
        end
        if f.statTexts["losses"] then
            f.statTexts["losses"]:SetText("|cFFFF4444" .. (stats.losses or 0) .. "|r")
        end
        if f.statTexts["avgDPS"] then
            f.statTexts["avgDPS"]:SetText("|cFFFFAA00" .. string.format("%.1f", stats.avgDPS or 0) .. "|r")
        end
        if f.statTexts["totalDamage"] then
            f.statTexts["totalDamage"]:SetText("|cFFFF8888" .. math.floor(stats.totalDamage or 0) .. "|r")
        end
        if f.statTexts["totalTime"] then
            local mins = math.floor((stats.totalTime or 0) / 60)
            local secs = math.floor(math.mod((stats.totalTime or 0), 60))
            f.statTexts["totalTime"]:SetText("|cFF8888FF" .. mins .. "m " .. secs .. "s|r")
        end

        -- Actualizar pesos de hechizos (ordenados por valor desc)
        local spells = {}
        for name, w in pairs(WCS_BrainML.Data.spellWeights or {}) do
            table.insert(spells, {name = name, w = w})
        end
        table.sort(spells, function(a, b) return a.w > b.w end)

        local rowCount = math.min(table.getn(spells), 12)
        for i = 1, 12 do
            local row = f.spellRows[i]
            if i <= rowCount then
                local sp = spells[i]
                local color = sp.w >= 1.5 and "00FF00" or (sp.w >= 1.0 and "FFCC00" or "FF6666")
                row.name:SetText("|cFF" .. color .. sp.name .. "|r |cFFAAAAAA(" .. string.format("%.2f", sp.w) .. ")|r")
                row.bar:SetValue(sp.w)
                row.bar:SetStatusBarColor(
                    sp.w >= 1.5 and 0 or (sp.w >= 1.0 and 1 or 1),
                    sp.w >= 1.5 and 1 or (sp.w >= 1.0 and 0.8 or 0.2),
                    0, 1
                )
            else
                row.name:SetText("|cFF666666------|r")
                row.bar:SetValue(0)
            end
        end
    end)
end

