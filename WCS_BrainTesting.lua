--[[
    WCS_BrainTesting.lua - Sistema de Testing Automatizado v1.0.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema completo de testing para validar decisiones de IA
    - Escenarios predefinidos de combate
    - Validación automática de decisiones
    - Métricas de precisión de IA
    - Testing de regresión
]]--

WCS_BrainTesting = WCS_BrainTesting or {}
WCS_BrainTesting.VERSION = "6.4.2"
WCS_BrainTesting.enabled = false

-- ============================================================================
-- CONFIGURACIÓN DE TESTING
-- ============================================================================
WCS_BrainTesting.Config = {
    autoRun = false,
    verboseOutput = true,
    logResults = true,
    maxTestTime = 30, -- segundos máximo por test
    minAccuracy = 0.75 -- 75% precisión mínima esperada
}

-- ============================================================================
-- ESCENARIOS DE TESTING
-- ============================================================================
WCS_BrainTesting.Scenarios = {
    -- Escenarios de Supervivencia
    {
        name = "Salud Crítica",
        category = "survival",
        playerHP = 15,
        playerMana = 50,
        targetHP = 80,
        inCombat = true,
        hasHealthstone = true,
        expectedActions = {"Healthstone", "Death Coil", "Drain Life"},
        priority = "high",
        description = "Jugador con salud crítica debe priorizar supervivencia"
    },
    {
        name = "Sin Mana Crítico",
        category = "mana",
        playerHP = 60,
        playerMana = 5,
        targetHP = 70,
        inCombat = true,
        canLifeTap = true,
        expectedActions = {"Life Tap", "Dark Pact", "Drain Mana"},
        priority = "high",
        description = "Sin mana debe usar habilidades de recuperación"
    },
    
    -- Escenarios de DPS
    {
        name = "DPS Óptimo Alto Mana",
        category = "dps",
        playerHP = 80,
        playerMana = 90,
        targetHP = 100,
        inCombat = true,
        moving = false,
        expectedActions = {"Shadow Bolt", "Immolate", "Corruption"},
        priority = "medium",
        description = "Con recursos altos debe maximizar DPS"
    },
    {
        name = "DPS Mientras Se Mueve",
        category = "movement",
        playerHP = 70,
        playerMana = 60,
        targetHP = 80,
        inCombat = true,
        moving = true,
        expectedActions = {"Corruption", "Curse of Agony", "Life Tap"},
        priority = "medium",
        description = "Mientras se mueve solo hechizos instantáneos"
    },
    
    -- Escenarios de Execute
    {
        name = "Execute Phase",
        category = "execute",
        playerHP = 70,
        playerMana = 40,
        targetHP = 20,
        inCombat = true,
        hasSoulShards = true,
        expectedActions = {"Shadowburn", "Drain Soul", "Shadow Bolt"},
        priority = "high",
        description = "En fase execute debe usar habilidades de finalización"
    },
    
    -- Escenarios de AoE
    {
        name = "Múltiples Enemigos",
        category = "aoe",
        playerHP = 60,
        playerMana = 70,
        targetHP = 80,
        inCombat = true,
        enemyCount = 4,
        expectedActions = {"Rain of Fire", "Hellfire", "Howl of Terror"},
        priority = "medium",
        description = "Con múltiples enemigos debe usar AoE"
    },
    
    -- Escenarios de Mascota
    {
        name = "Mascota Herida",
        category = "pet",
        playerHP = 80,
        playerMana = 60,
        petHP = 15,
        petType = "Voidwalker",
        inCombat = true,
        expectedActions = {"Health Funnel", "PET_PASSIVE", "Consume Shadows"},
        priority = "high",
        description = "Mascota crítica necesita curación"
    },
    
    -- Escenarios de Control
    {
        name = "Control de Multitudes",
        category = "cc",
        playerHP = 50,
        playerMana = 60,
        targetHP = 90,
        enemyCount = 2,
        inCombat = true,
        expectedActions = {"Fear", "Banish", "Howl of Terror"},
        priority = "high",
        description = "Múltiples enemigos requieren control"
    },
    
    -- Escenarios de PvP
    {
        name = "PvP Burst",
        category = "pvp",
        playerHP = 70,
        playerMana = 80,
        targetHP = 60,
        targetIsPlayer = true,
        inCombat = true,
        expectedActions = {"Curse of Doom", "Immolate", "Conflagrate"},
        priority = "high",
        description = "Contra jugadores debe hacer burst damage"
    }
}

-- ============================================================================
-- SISTEMA DE TESTING
-- ============================================================================
WCS_BrainTesting.Results = {
    totalTests = 0,
    passedTests = 0,
    failedTests = 0,
    accuracy = 0,
    lastRun = 0,
    detailedResults = {}
}

-- Función principal de testing
function WCS_BrainTesting:RunAllTests()
    if not WCS_Brain or not WCS_BrainAI then
        self:Log("ERROR: WCS_Brain o WCS_BrainAI no están cargados")
        return false
    end
    
    self:Log("=== INICIANDO TESTING AUTOMATIZADO ===")
    self:Log("Ejecutando " .. WCS_TableCount(self.Scenarios) .. " escenarios de testing...")
    
    -- Resetear resultados
    self.Results.totalTests = 0
    self.Results.passedTests = 0
    self.Results.failedTests = 0
    self.Results.detailedResults = {}
    self.Results.lastRun = GetTime()
    
    -- Ejecutar cada escenario
    for i, scenario in ipairs(self.Scenarios) do
        self:RunScenario(scenario, i)
    end
    
    -- Calcular precisión final
    if self.Results.totalTests > 0 then
        self.Results.accuracy = self.Results.passedTests / self.Results.totalTests
    end
    
    self:ShowResults()
    return self.Results.accuracy >= self.Config.minAccuracy
end

-- Ejecutar un escenario específico
function WCS_BrainTesting:RunScenario(scenario, index)
    self.Results.totalTests = self.Results.totalTests + 1
    
    self:Log("Ejecutando: " .. scenario.name .. " (" .. scenario.category .. ")")
    
    -- Simular estado del juego
    local mockState = self:CreateMockState(scenario)
    
    -- Obtener decisión de la IA
    local decision = self:GetAIDecision(mockState)
    
    -- Validar decisión
    local isValid = self:ValidateDecision(decision, scenario.expectedActions)
    
    -- Registrar resultado
    local result = {
        scenario = scenario.name,
        category = scenario.category,
        priority = scenario.priority,
        decision = decision,
        expected = scenario.expectedActions,
        passed = isValid,
        timestamp = GetTime()
    }
    
    table.insert(self.Results.detailedResults, result)
    
    if isValid then
        self.Results.passedTests = self.Results.passedTests + 1
        self:Log("✓ PASS: " .. decision .. " (esperado: " .. table.concat(scenario.expectedActions, "/") .. ")")
    else
        self.Results.failedTests = self.Results.failedTests + 1
        self:Log("✗ FAIL: " .. decision .. " (esperado: " .. table.concat(scenario.expectedActions, "/") .. ")")
        -- Diagnostics: show best candidate and top candidates if available
        if self.lastActionData and type(self.lastActionData) == "table" then
            local ad = self.lastActionData
            self:Log("  > Mejor candidato: " .. tostring(ad.spell or "?") .. " (score: " .. tostring(ad.score or "?") .. ")")
        end
        if WCS_BrainAI and WCS_BrainAI.GetAllCandidateActions then
            local cands = WCS_BrainAI:GetAllCandidateActions()
            if cands and type(cands) == "table" then
                self:Log("  > Top candidatos:")
                local count = 0
                for _, c in ipairs(cands) do
                    self:Log("    - " .. tostring(c.spell or "?") .. " (" .. tostring(c.score or "?") .. ")")
                    count = count + 1
                    if count >= 3 then break end
                end
            end
        end
    end
end

-- Crear estado simulado del juego
function WCS_BrainTesting:CreateMockState(scenario)
    return {
        playerHP = scenario.playerHP or 100,
        playerMana = scenario.playerMana or 100,
        targetHP = scenario.targetHP or 100,
        petHP = scenario.petHP or 100,
        petType = scenario.petType or "none",
        inCombat = scenario.inCombat or false,
        moving = scenario.moving or false,
        enemyCount = scenario.enemyCount or 1,
        targetIsPlayer = scenario.targetIsPlayer or false,
        hasHealthstone = scenario.hasHealthstone or false,
        hasSoulShards = scenario.hasSoulShards or false,
        canLifeTap = scenario.canLifeTap or true
    }
end

-- Obtener decisión de la IA usando el estado simulado
function WCS_BrainTesting:GetAIDecision(mockState)
    -- Guardar estado real
    local realState = self:SaveRealState()
    
    -- Aplicar estado simulado
    self:ApplyMockState(mockState)
    
    -- Obtener decisión de WCS_BrainAI
    local decision = "NONE"
    if WCS_BrainAI and WCS_BrainAI.GetBestAction then
        local actionData = WCS_BrainAI:GetBestAction()
        if type(actionData) == "table" then
            decision = actionData.spell or decision
            self.lastActionData = actionData
        elseif type(actionData) == "string" then
            decision = actionData
        end
    end
    
    -- Restaurar estado real
    self:RestoreRealState(realState)
    
    return decision
end

-- Guardar estado real del juego
function WCS_BrainTesting:SaveRealState()
    return {
        playerHP = UnitHealth("player"),
        playerMana = UnitMana("player"),
        targetExists = UnitExists("target"),
        petExists = UnitExists("pet"),
        inCombat = UnitAffectingCombat("player")
    }
end

-- Aplicar estado simulado (mock)
function WCS_BrainTesting:ApplyMockState(mockState)
    -- Crear funciones mock temporales
    self.originalUnitHealth = UnitHealth
    self.originalUnitMana = UnitMana
    self.originalUnitExists = UnitExists
    self.originalUnitAffectingCombat = UnitAffectingCombat
    
    -- Override funciones del juego
    UnitHealth = function(unit)
        if unit == "player" then return mockState.playerHP end
        if unit == "target" then return mockState.targetHP end
        if unit == "pet" then return mockState.petHP end
        return self.originalUnitHealth(unit)
    end
    
    UnitMana = function(unit)
        if unit == "player" then return mockState.playerMana end
        return self.originalUnitMana(unit)
    end
    
    UnitExists = function(unit)
        if unit == "target" then return mockState.targetHP > 0 end
        if unit == "pet" then return mockState.petType ~= "none" end
        return self.originalUnitExists(unit)
    end
    
    UnitAffectingCombat = function(unit)
        if unit == "player" then return mockState.inCombat end
        return self.originalUnitAffectingCombat(unit)
    end
end

-- Restaurar estado real del juego
function WCS_BrainTesting:RestoreRealState(realState)
    -- Restaurar funciones originales
    if self.originalUnitHealth then UnitHealth = self.originalUnitHealth end
    if self.originalUnitMana then UnitMana = self.originalUnitMana end
    if self.originalUnitExists then UnitExists = self.originalUnitExists end
    if self.originalUnitAffectingCombat then UnitAffectingCombat = self.originalUnitAffectingCombat end
end

-- Validar si la decisión es correcta
function WCS_BrainTesting:ValidateDecision(decision, expectedActions)
    expectedActions = expectedActions or {}
    if not decision or decision == "NONE" then
        for _, exp in ipairs(expectedActions) do
            if exp == "NONE" then return true end
        end
        return false
    end

    -- Direct match
    for _, expected in ipairs(expectedActions) do
        if decision == expected then return true end
    end

    -- Match by action index via WCS_BrainActions
    if WCS_BrainActions and WCS_BrainActions.GetActionIndex then
        local dIdx = WCS_BrainActions:GetActionIndex(decision)
        if dIdx then
            for _, expected in ipairs(expectedActions) do
                local eIdx = WCS_BrainActions:GetActionIndex(expected)
                if eIdx and eIdx == dIdx then return true end
            end
        end
    end

    -- Fuzzy substring match
    for _, expected in ipairs(expectedActions) do
        if string.find(string.lower(tostring(decision)), string.lower(tostring(expected)), 1, true) or string.find(string.lower(tostring(expected)), string.lower(tostring(decision)), 1, true) then
            return true
        end
    end

    return false
end

-- Mostrar resultados del testing
function WCS_BrainTesting:ShowResults()
    self:Log("=== RESULTADOS DEL TESTING ===")
    self:Log("Total de tests: " .. self.Results.totalTests)
    self:Log("Tests exitosos: " .. self.Results.passedTests)
    self:Log("Tests fallidos: " .. self.Results.failedTests)
    self:Log("Precisión: " .. string.format("%.1f%%", self.Results.accuracy * 100))
    
    if self.Results.accuracy >= self.Config.minAccuracy then
        self:Log("✓ TESTING EXITOSO - IA funcionando correctamente")
    else
        self:Log("✗ TESTING FALLIDO - IA necesita ajustes")
    end
    
    -- Mostrar fallos por categoría
    self:ShowFailuresByCategory()
end

-- Mostrar fallos agrupados por categoría
function WCS_BrainTesting:ShowFailuresByCategory()
    local failuresByCategory = {}
    
    for _, result in ipairs(self.Results.detailedResults) do
        if not result.passed then
            if not failuresByCategory[result.category] then
                failuresByCategory[result.category] = 0
            end
            failuresByCategory[result.category] = failuresByCategory[result.category] + 1
        end
    end
    
    if WCS_TableCount(failuresByCategory) > 0 then
        self:Log("=== FALLOS POR CATEGORÍA ===")
        for category, count in pairs(failuresByCategory) do
            self:Log(category .. ": " .. count .. " fallos")
        end
    end
end

-- Testing específico por categoría
function WCS_BrainTesting:RunCategoryTests(category)
    self:Log("=== TESTING CATEGORÍA: " .. string.upper(category) .. " ===")
    
    local categoryTests = 0
    local categoryPassed = 0
    
    for i, scenario in ipairs(self.Scenarios) do
        if scenario.category == category then
            categoryTests = categoryTests + 1
            self:RunScenario(scenario, i)
            if self.Results.detailedResults[WCS_TableCount(self.Results.detailedResults)].passed then
                categoryPassed = categoryPassed + 1
            end
        end
    end
    
    local categoryAccuracy = categoryTests > 0 and (categoryPassed / categoryTests) or 0
    self:Log("Precisión en " .. category .. ": " .. string.format("%.1f%%", categoryAccuracy * 100))
    
    return categoryAccuracy
end

-- Sistema de logging
function WCS_BrainTesting:Log(message)
    if self.Config.verboseOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Testing]|r " .. message)
    end
end

-- ============================================================================
-- COMANDOS DE TESTING
-- ============================================================================
function WCS_BrainTesting:RegisterCommands()
    SLASH_WCSTEST1 = "/wcstest"
    SlashCmdList["WCSTEST"] = function(msg)
        local args = {}
        for word in string.gfind(msg, "%S+") do
            table.insert(args, string.lower(word))
        end
        
        if not args[1] or args[1] == "help" then
            self:ShowHelp()
        elseif args[1] == "run" then
            self:RunAllTests()
        elseif args[1] == "category" and args[2] then
            self:RunCategoryTests(args[2])
        elseif args[1] == "results" then
            self:ShowResults()
        elseif args[1] == "config" then
            self:ShowConfig()
        elseif args[1] == "verbose" then
            self.Config.verboseOutput = not self.Config.verboseOutput
            self:Log("Verbose output: " .. (self.Config.verboseOutput and "ON" or "OFF"))
        elseif args[1] == "accuracy" and args[2] then
            local newAccuracy = tonumber(args[2])
            if newAccuracy and newAccuracy >= 0 and newAccuracy <= 1 then
                self.Config.minAccuracy = newAccuracy
                self:Log("Precisión mínima establecida en: " .. string.format("%.1f%%", newAccuracy * 100))
            end
        else
            self:Log("Comando desconocido. Usa /wcstest help")
        end
    end
end

function WCS_BrainTesting:ShowHelp()
    self:Log("=== COMANDOS DE TESTING ===")
    self:Log("/wcstest run - Ejecutar todos los tests")
    self:Log("/wcstest category <nombre> - Ejecutar tests de una categoría")
    self:Log("/wcstest results - Mostrar últimos resultados")
    self:Log("/wcstest config - Mostrar configuración")
    self:Log("/wcstest verbose - Toggle output verbose")
    self:Log("/wcstest accuracy <0-1> - Establecer precisión mínima")
    self:Log("Categorías: survival, mana, dps, movement, execute, aoe, pet, cc, pvp")
end

function WCS_BrainTesting:ShowConfig()
    self:Log("=== CONFIGURACIÓN DE TESTING ===")
    self:Log("Verbose output: " .. (self.Config.verboseOutput and "ON" or "OFF"))
    self:Log("Log results: " .. (self.Config.logResults and "ON" or "OFF"))
    self:Log("Precisión mínima: " .. string.format("%.1f%%", self.Config.minAccuracy * 100))
    self:Log("Tiempo máximo por test: " .. self.Config.maxTestTime .. "s")
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainTesting:Initialize()
    self:RegisterCommands()
    self:Log("Sistema de Testing v" .. self.VERSION .. " inicializado")
    self:Log("Usa /wcstest help para ver comandos disponibles")
end

-- Auto-inicialización
if WCS_BrainCore and WCS_BrainCore.RegisterModule then
    WCS_BrainCore:RegisterModule("Testing", WCS_BrainTesting)
end

-- Inicialización manual si no hay sistema de módulos
local function InitializeTesting()
    if WCS_BrainTesting then
        WCS_BrainTesting:Initialize()
    end
end

-- Registrar evento de carga
if not WCS_BrainTesting.initialized then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
            InitializeTesting()
            WCS_BrainTesting.initialized = true
        end
    end)
end
