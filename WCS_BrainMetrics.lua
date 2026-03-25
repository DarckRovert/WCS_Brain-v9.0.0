--[[
    WCS_BrainMetrics.lua - Sistema de Métricas Avanzadas v6.4.2
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema completo de métricas de rendimiento:
    - DPS promedio por hechizo
    - Tiempo de supervivencia
    - Eficiencia de mana
    - Win rate por tipo de enemigo
    - Análisis de patrones de combate
]]--

WCS_BrainMetrics = WCS_BrainMetrics or {}
WCS_BrainMetrics.VERSION = "6.4.2"
WCS_BrainMetrics.enabled = true

-- ============================================================================
-- CONFIGURACIÓN DE MÉTRICAS
-- ============================================================================
WCS_BrainMetrics.Config = {
    trackDPS = true,
    trackSurvival = true,
    trackManaEfficiency = true,
    trackSpellUsage = true,
    trackEnemyTypes = true,
    maxCombatHistory = 100, -- Máximo de combates a recordar
    updateInterval = 1.0,   -- Intervalo de actualización en segundos
    autoSave = true,        -- Auto-guardar métricas
    saveInterval = 300      -- Guardar cada 5 minutos
}

-- ============================================================================
-- ESTRUCTURAS DE DATOS
-- ============================================================================
WCS_BrainMetrics.Data = {
    -- Métricas de DPS
    spellDPS = {},          -- DPS por hechizo
    totalDamage = 0,        -- Daño total acumulado
    totalCombatTime = 0,    -- Tiempo total en combate
    averageDPS = 0,         -- DPS promedio global
    
    -- Métricas de Supervivencia
    combatsWon = 0,         -- Combates ganados
    combatsLost = 0,        -- Combates perdidos
    totalDeaths = 0,        -- Muertes totales
    averageSurvivalTime = 0,-- Tiempo promedio de supervivencia
    
    -- Métricas de Mana
    manaUsed = 0,           -- Mana total usado
    manaEfficiency = 0,     -- Daño por mana
    lifeTapUsage = 0,       -- Veces que usó Life Tap
    darkPactUsage = 0,      -- Veces que usó Dark Pact
    
    -- Métricas de Hechizos
    spellUsage = {},        -- Contador de uso por hechizo
    spellSuccessRate = {},  -- Tasa de éxito por hechizo
    spellDamageTotal = {},  -- Daño total por hechizo
    
    -- Métricas de Enemigos
    enemyTypes = {},        -- Tipos de enemigos enfrentados
    enemyWinRate = {},      -- Win rate por tipo de enemigo
    
    -- Historial de Combates
    combatHistory = {},     -- Historial detallado de combates
    
    -- Métricas de Tiempo
    sessionStartTime = 0,   -- Inicio de sesión
    totalPlayTime = 0,      -- Tiempo total jugado
    lastUpdate = 0          -- Última actualización
}

-- ============================================================================
-- TRACKING DE COMBATE
-- ============================================================================
WCS_BrainMetrics.Combat = {
    active = false,
    startTime = 0,
    endTime = 0,
    damageDealt = 0,
    manaSpent = 0,
    spellsCast = {},
    enemyName = "",
    enemyType = "",
    result = "unknown" -- "won", "lost", "fled"
}

-- Iniciar tracking de combate
function WCS_BrainMetrics:StartCombat()
    if self.Combat.active then return end
    
    self.Combat.active = true
    self.Combat.startTime = GetTime()
    self.Combat.damageDealt = 0
    self.Combat.manaSpent = 0
    self.Combat.spellsCast = {}
    self.Combat.enemyName = UnitName("target") or "Unknown"
    self.Combat.enemyType = UnitCreatureType("target") or "Unknown"
    self.Combat.result = "unknown"
    
    self:Log("Combate iniciado contra: " .. self.Combat.enemyName)
end

-- Finalizar tracking de combate
function WCS_BrainMetrics:EndCombat(result)
    if not self.Combat.active then return end
    
    self.Combat.active = false
    self.Combat.endTime = GetTime()
    self.Combat.result = result or "unknown"
    
    local combatDuration = self.Combat.endTime - self.Combat.startTime
    
    -- Registrar combate en historial
    self:RecordCombat(combatDuration)
    
    -- Actualizar métricas globales
    self:UpdateGlobalMetrics(combatDuration)
    
    self:Log("Combate finalizado: " .. self.Combat.result .. " (" .. string.format("%.1f", combatDuration) .. "s)")
end

-- Registrar combate en historial
function WCS_BrainMetrics:RecordCombat(duration)
    local combatRecord = {
        timestamp = GetTime(),
        duration = duration,
        damageDealt = self.Combat.damageDealt,
        manaSpent = self.Combat.manaSpent,
        dps = duration > 0 and (self.Combat.damageDealt / duration) or 0,
        manaEfficiency = self.Combat.manaSpent > 0 and (self.Combat.damageDealt / self.Combat.manaSpent) or 0,
        enemyName = self.Combat.enemyName,
        enemyType = self.Combat.enemyType,
        result = self.Combat.result,
        spellsCast = self:CopyTable(self.Combat.spellsCast)
    }
    
    table.insert(self.Data.combatHistory, combatRecord)
    
    -- Mantener solo los últimos N combates
    while WCS_TableCount(self.Data.combatHistory) > self.Config.maxCombatHistory do
        table.remove(self.Data.combatHistory, 1)
    end
end

-- Actualizar métricas globales
function WCS_BrainMetrics:UpdateGlobalMetrics(duration)
    -- Métricas de combate
    self.Data.totalCombatTime = self.Data.totalCombatTime + duration
    self.Data.totalDamage = self.Data.totalDamage + self.Combat.damageDealt
    
    if self.Data.totalCombatTime > 0 then
        self.Data.averageDPS = self.Data.totalDamage / self.Data.totalCombatTime
    end
    
    -- Métricas de supervivencia
    if self.Combat.result == "won" then
        self.Data.combatsWon = self.Data.combatsWon + 1
    elseif self.Combat.result == "lost" then
        self.Data.combatsLost = self.Data.combatsLost + 1
        self.Data.totalDeaths = self.Data.totalDeaths + 1
    end
    
    -- Métricas de mana
    self.Data.manaUsed = self.Data.manaUsed + self.Combat.manaSpent
    if self.Data.manaUsed > 0 then
        self.Data.manaEfficiency = self.Data.totalDamage / self.Data.manaUsed
    end
    
    -- Métricas por tipo de enemigo
    local enemyType = self.Combat.enemyType
    if not self.Data.enemyTypes[enemyType] then
        self.Data.enemyTypes[enemyType] = {
            encounters = 0,
            wins = 0,
            losses = 0,
            totalDamage = 0,
            totalTime = 0
        }
    end
    
    local enemyData = self.Data.enemyTypes[enemyType]
    enemyData.encounters = enemyData.encounters + 1
    enemyData.totalDamage = enemyData.totalDamage + self.Combat.damageDealt
    enemyData.totalTime = enemyData.totalTime + duration
    
    if self.Combat.result == "won" then
        enemyData.wins = enemyData.wins + 1
    elseif self.Combat.result == "lost" then
        enemyData.losses = enemyData.losses + 1
    end
    
    -- Calcular win rate
    if enemyData.encounters > 0 then
        self.Data.enemyWinRate[enemyType] = enemyData.wins / enemyData.encounters
    end
    
    -- Actualizar métricas de hechizos
    self:UpdateSpellMetrics()
end

-- Actualizar métricas de hechizos
function WCS_BrainMetrics:UpdateSpellMetrics()
    for spell, data in pairs(self.Combat.spellsCast) do
        -- Inicializar si no existe
        if not self.Data.spellUsage[spell] then
            self.Data.spellUsage[spell] = 0
            self.Data.spellDamageTotal[spell] = 0
            self.Data.spellDPS[spell] = 0
        end
        
        -- Actualizar contadores
        self.Data.spellUsage[spell] = self.Data.spellUsage[spell] + data.casts
        self.Data.spellDamageTotal[spell] = self.Data.spellDamageTotal[spell] + data.damage
        
        -- Calcular DPS del hechizo
        if data.castTime > 0 then
            local spellDPS = data.damage / data.castTime
            -- Promedio ponderado
            local totalCasts = self.Data.spellUsage[spell]
            self.Data.spellDPS[spell] = ((self.Data.spellDPS[spell] * (totalCasts - data.casts)) + (spellDPS * data.casts)) / totalCasts
        end
    end
end

-- ============================================================================
-- TRACKING DE EVENTOS
-- ============================================================================

-- Registrar daño de hechizo
function WCS_BrainMetrics:RecordSpellDamage(spell, damage, castTime)
    if not self.Combat.active then return end
    
    if not self.Combat.spellsCast[spell] then
        self.Combat.spellsCast[spell] = {
            casts = 0,
            damage = 0,
            castTime = 0
        }
    end
    
    local spellData = self.Combat.spellsCast[spell]
    spellData.casts = spellData.casts + 1
    spellData.damage = spellData.damage + damage
    spellData.castTime = spellData.castTime + (castTime or 0)
    
    self.Combat.damageDealt = self.Combat.damageDealt + damage
end

-- Registrar uso de mana
function WCS_BrainMetrics:RecordManaUsage(amount, spell)
    if not self.Combat.active then return end
    
    self.Combat.manaSpent = self.Combat.manaSpent + amount
    
    -- Tracking especial para Life Tap y Dark Pact
    if spell == "Life Tap" then
        self.Data.lifeTapUsage = self.Data.lifeTapUsage + 1
    elseif spell == "Dark Pact" then
        self.Data.darkPactUsage = self.Data.darkPactUsage + 1
    end
end

-- ============================================================================
-- ANÁLISIS Y REPORTES
-- ============================================================================

-- Obtener top hechizos por DPS
function WCS_BrainMetrics:GetTopSpellsByDPS(limit)
    limit = limit or 5
    local spells = {}
    
    for spell, dps in pairs(self.Data.spellDPS) do
        table.insert(spells, {spell = spell, dps = dps})
    end
    
    -- Ordenar por DPS descendente
    table.sort(spells, function(a, b) return a.dps > b.dps end)
    
    -- Retornar solo los primeros N
    local result = {}
    for i = 1, math.min(limit, WCS_TableCount(spells)) do
        table.insert(result, spells[i])
    end
    
    return result
end

-- Obtener estadísticas de supervivencia
function WCS_BrainMetrics:GetSurvivalStats()
    local totalCombats = self.Data.combatsWon + self.Data.combatsLost
    local winRate = totalCombats > 0 and (self.Data.combatsWon / totalCombats) or 0
    
    -- Calcular tiempo promedio de supervivencia
    local totalSurvivalTime = 0
    local survivalCombats = 0
    
    for _, combat in self.Data.combatHistory do
        if combat.result ~= "fled" then
            totalSurvivalTime = totalSurvivalTime + combat.duration
            survivalCombats = survivalCombats + 1
        end
    end
    
    local avgSurvivalTime = survivalCombats > 0 and (totalSurvivalTime / survivalCombats) or 0
    
    return {
        totalCombats = totalCombats,
        wins = self.Data.combatsWon,
        losses = self.Data.combatsLost,
        winRate = winRate,
        deaths = self.Data.totalDeaths,
        avgSurvivalTime = avgSurvivalTime
    }
end

-- Obtener estadísticas de mana
function WCS_BrainMetrics:GetManaStats()
    return {
        totalManaUsed = self.Data.manaUsed,
        manaEfficiency = self.Data.manaEfficiency,
        lifeTapUsage = self.Data.lifeTapUsage,
        darkPactUsage = self.Data.darkPactUsage,
        avgManaPerCombat = (self.Data.combatsWon + self.Data.combatsLost) > 0 and 
                          (self.Data.manaUsed / (self.Data.combatsWon + self.Data.combatsLost)) or 0
    }
end

-- Obtener estadísticas por tipo de enemigo
function WCS_BrainMetrics:GetEnemyTypeStats()
    local stats = {}
    
    for enemyType, data in pairs(self.Data.enemyTypes) do
        local winRate = data.encounters > 0 and (data.wins / data.encounters) or 0
        local avgDPS = data.totalTime > 0 and (data.totalDamage / data.totalTime) or 0
        
        stats[enemyType] = {
            encounters = data.encounters,
            wins = data.wins,
            losses = data.losses,
            winRate = winRate,
            totalDamage = data.totalDamage,
            avgDPS = avgDPS
        }
    end
    
    return stats
end

-- ============================================================================
-- REPORTES Y VISUALIZACIÓN
-- ============================================================================

-- Mostrar reporte completo
function WCS_BrainMetrics:ShowFullReport()
    self:Log("=== REPORTE COMPLETO DE MÉTRICAS ===")
    
    -- DPS Global
    self:Log("DPS Promedio Global: " .. string.format("%.1f", self.Data.averageDPS))
    self:Log("Daño Total: " .. self.Data.totalDamage)
    self:Log("Tiempo en Combate: " .. string.format("%.1f", self.Data.totalCombatTime) .. "s")
    
    -- Top hechizos
    self:Log("\n=== TOP 5 HECHIZOS POR DPS ===")
    local topSpells = self:GetTopSpellsByDPS(5)
    for i, spellData in ipairs(topSpells) do
        self:Log(i .. ". " .. spellData.spell .. ": " .. string.format("%.1f", spellData.dps) .. " DPS")
    end
    
    -- Supervivencia
    local survivalStats = self:GetSurvivalStats()
    self:Log("\n=== ESTADÍSTICAS DE SUPERVIVENCIA ===")
    self:Log("Win Rate: " .. string.format("%.1f%%", survivalStats.winRate * 100))
    self:Log("Combates Ganados: " .. survivalStats.wins)
    self:Log("Combates Perdidos: " .. survivalStats.losses)
    self:Log("Tiempo Promedio de Supervivencia: " .. string.format("%.1f", survivalStats.avgSurvivalTime) .. "s")
    
    -- Mana
    local manaStats = self:GetManaStats()
    self:Log("\n=== ESTADÍSTICAS DE MANA ===")
    self:Log("Eficiencia de Mana: " .. string.format("%.2f", manaStats.manaEfficiency) .. " daño/mana")
    self:Log("Life Tap usado: " .. manaStats.lifeTapUsage .. " veces")
    self:Log("Dark Pact usado: " .. manaStats.darkPactUsage .. " veces")
end

-- Mostrar estadísticas rápidas
function WCS_BrainMetrics:ShowQuickStats()
    local survivalStats = self:GetSurvivalStats()
    local manaStats = self:GetManaStats()
    
    self:Log("=== ESTADÍSTICAS RÁPIDAS ===")
    self:Log("DPS: " .. string.format("%.1f", self.Data.averageDPS) .. 
             " | Win Rate: " .. string.format("%.1f%%", survivalStats.winRate * 100) ..
             " | Eficiencia Mana: " .. string.format("%.2f", manaStats.manaEfficiency))
end

-- ============================================================================
-- COMANDOS
-- ============================================================================
function WCS_BrainMetrics:RegisterCommands()
    SLASH_WCSMETRICS1 = "/wcsmetrics"
    SlashCmdList["WCSMETRICS"] = function(msg)
        local args = {}
        for word in string.gfind(msg, "%S+") do
            table.insert(args, string.lower(word))
        end
        
        if not args[1] or args[1] == "help" then
            self:ShowHelp()
        elseif args[1] == "report" then
            self:ShowFullReport()
        elseif args[1] == "quick" then
            self:ShowQuickStats()
        elseif args[1] == "dps" then
            self:ShowDPSReport()
        elseif args[1] == "survival" then
            self:ShowSurvivalReport()
        elseif args[1] == "mana" then
            self:ShowManaReport()
        elseif args[1] == "enemies" then
            self:ShowEnemyReport()
        elseif args[1] == "reset" then
            self:ResetMetrics()
        elseif args[1] == "save" then
            self:SaveMetrics()
        else
            self:Log("Comando desconocido. Usa /wcsmetrics help")
        end
    end
end

function WCS_BrainMetrics:ShowHelp()
    self:Log("=== COMANDOS DE MÉTRICAS ===")
    self:Log("/wcsmetrics report - Reporte completo")
    self:Log("/wcsmetrics quick - Estadísticas rápidas")
    self:Log("/wcsmetrics dps - Reporte de DPS")
    self:Log("/wcsmetrics survival - Reporte de supervivencia")
    self:Log("/wcsmetrics mana - Reporte de mana")
    self:Log("/wcsmetrics enemies - Reporte por tipo de enemigo")
    self:Log("/wcsmetrics reset - Resetear todas las métricas")
    self:Log("/wcsmetrics save - Guardar métricas manualmente")
end

-- ============================================================================
-- UTILIDADES
-- ============================================================================
function WCS_BrainMetrics:CopyTable(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = self:CopyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function WCS_BrainMetrics:Log(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Metrics]|r " .. message)
end

function WCS_BrainMetrics:ResetMetrics()
    self.Data = {
        spellDPS = {},
        totalDamage = 0,
        totalCombatTime = 0,
        averageDPS = 0,
        combatsWon = 0,
        combatsLost = 0,
        totalDeaths = 0,
        averageSurvivalTime = 0,
        manaUsed = 0,
        manaEfficiency = 0,
        lifeTapUsage = 0,
        darkPactUsage = 0,
        spellUsage = {},
        spellSuccessRate = {},
        spellDamageTotal = {},
        enemyTypes = {},
        enemyWinRate = {},
        combatHistory = {},
        sessionStartTime = GetTime(),
        totalPlayTime = 0,
        lastUpdate = GetTime()
    }
    self:Log("Todas las métricas han sido reseteadas")
end

function WCS_BrainMetrics:SaveMetrics()
    -- Guardar en SavedVariables
    if WCS_BrainSaved then
        WCS_BrainSaved.Metrics = self.Data
        self:Log("Métricas guardadas exitosamente")
    end
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainMetrics:Initialize()
    self.Data.sessionStartTime = GetTime()
    self.Data.lastUpdate = GetTime()
    
    -- Cargar métricas guardadas
    if WCS_BrainSaved and WCS_BrainSaved.Metrics then
        self.Data = WCS_BrainSaved.Metrics
    end
    
    self:RegisterCommands()
    self:Log("Sistema de Métricas v" .. self.VERSION .. " inicializado")
end

-- Auto-inicialización
if WCS_BrainCore and WCS_BrainCore.RegisterModule then
    WCS_BrainCore:RegisterModule("Metrics", WCS_BrainMetrics)
end

-- Inicialización manual
local function InitializeMetrics()
    if WCS_BrainMetrics then
        WCS_BrainMetrics:Initialize()
    end
end

-- Registrar eventos
if not WCS_BrainMetrics.initialized then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entrar en combate
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Salir de combate
    frame:RegisterEvent("PLAYER_DEAD")           -- Muerte del jugador
    
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
            InitializeMetrics()
            WCS_BrainMetrics.initialized = true
        elseif event == "PLAYER_REGEN_DISABLED" then
            WCS_BrainMetrics:StartCombat()
        elseif event == "PLAYER_REGEN_ENABLED" then
            WCS_BrainMetrics:EndCombat("won")
        elseif event == "PLAYER_DEAD" then
            WCS_BrainMetrics:EndCombat("lost")
        end
    end)
end
