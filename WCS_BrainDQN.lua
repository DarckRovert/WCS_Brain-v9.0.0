--[[
    WCS_BrainDQN.lua - Deep Q-Network para Warlock
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 6.7.0 - Sin mensajes DEBUG
]]--

WCS_BrainDQN = WCS_BrainDQN or {}
WCS_BrainDQN.VERSION = "6.7.0"
WCS_BrainDQN.enabled = false

WCS_BrainDQN.Config = WCS_BrainDQN.Config or {}
WCS_BrainDQN.ReplayBuffer = WCS_BrainDQN.ReplayBuffer or {}
WCS_BrainDQN.QNetwork = WCS_BrainDQN.QNetwork or {}
WCS_BrainDQN.TargetNetwork = WCS_BrainDQN.TargetNetwork or {}
WCS_BrainDQN.Stats = WCS_BrainDQN.Stats or {}

-- ============================================================================
-- REPLAY BUFFER
-- ============================================================================
function WCS_BrainDQN.ReplayBuffer:Add(state, action, reward, nextState, done)
    if not self.buffer then self.buffer = {} end
    if not self.index then self.index = 1 end
    if not self.size then self.size = 0 end
    
    self.buffer[self.index] = {
        state = state,
        action = action,
        reward = reward,
        nextState = nextState,
        done = done
    }
    
    -- Límite optimizado de memoria: 1000 entradas máximo
    local bufSize = WCS_BrainDQN.Config.bufferSize or 1000

    -- avanzar índice de escritura (circular)
    self.index = self.index + 1
    if self.index > bufSize then
        self.index = 1
    end

    -- mantener tamaño real (hasta bufSize)
    if self.size < bufSize then
        self.size = self.size + 1
    end

    -- contador de operaciones para limpieza periódica (evita usar operadores no-portables)
    self._addCount = (self._addCount or 0) + 1
    local ops = self._addCount
    if math.floor(ops / 100) * 100 == ops then
        self:Cleanup()
    end
end

-- Función de limpieza de memoria
function WCS_BrainDQN.ReplayBuffer:Cleanup()
    -- Eliminar entradas nulas o corruptas
    local cleanBuffer = {}
    local cleanIndex = 1
    
    for i = 1, self.size do
        local entry = self.buffer[i]
        if entry and entry.state and entry.action then
            cleanBuffer[cleanIndex] = entry
            cleanIndex = cleanIndex + 1
        end
    end
    
    self.buffer = cleanBuffer
    self.size = cleanIndex - 1
    self.index = self.size + 1
end

function WCS_BrainDQN.ReplayBuffer:Sample(batchSize)
    if not batchSize or batchSize <= 0 then return nil end
    if not self.size or self.size <= 0 then return nil end
    if self.size < batchSize then batchSize = self.size end
    local batch = {}
        for i = 1, batchSize do
        local idx = math.random(self.size)
        table.insert(batch, self.buffer[idx])
    end
    return batch
end

function WCS_BrainDQN.ReplayBuffer:Clear()
    self.buffer = {}
    self.index = 1
    self.size = 0
end

-- ============================================================================
-- RED NEURONAL (Q-Network)
-- ============================================================================
local function relu(x)
    if x > 0 then return x else return 0 end
end

function WCS_BrainDQN.QNetwork:Initialize()
    local cfg = WCS_BrainDQN.Config
    local stateSize = cfg.stateSize or 50
    local hiddenSize = cfg.hiddenSize or 128
    local actionSize = cfg.actionSize or 30
    
    self.weightsInputHidden = {}
    for i = 1, stateSize do
        self.weightsInputHidden[i] = {}
        for j = 1, hiddenSize do
            local limit = math.sqrt(6 / (stateSize + hiddenSize))
            self.weightsInputHidden[i][j] = (math.random() * 2 - 1) * limit
        end
    end
    
    self.biasHidden = {}
    for i = 1, hiddenSize do
        self.biasHidden[i] = 0
    end
    
    self.weightsHiddenOutput = {}
    for i = 1, hiddenSize do
        self.weightsHiddenOutput[i] = {}
        for j = 1, actionSize do
            local limit = math.sqrt(6 / (hiddenSize + actionSize))
            self.weightsHiddenOutput[i][j] = (math.random() * 2 - 1) * limit
        end
    end
    
    self.biasOutput = {}
    for i = 1, actionSize do
        self.biasOutput[i] = 0
    end
end

function WCS_BrainDQN.QNetwork:Forward(state)
    local cfg = WCS_BrainDQN.Config
    local hiddenSize = cfg.hiddenSize or 128
    local stateSize = cfg.stateSize or 50
    local actionSize = cfg.actionSize or 30
    
    local hidden = {}
    for j = 1, hiddenSize do
        local sum = self.biasHidden[j] or 0
        for i = 1, stateSize do
            local w = self.weightsInputHidden[i] and self.weightsInputHidden[i][j] or 0
            sum = sum + (state[i] or 0) * w
        end
        hidden[j] = relu(sum)
    end
    
    local qValues = {}
    for j = 1, actionSize do
        local sum = self.biasOutput[j] or 0
        for i = 1, hiddenSize do
            local w = self.weightsHiddenOutput[i] and self.weightsHiddenOutput[i][j] or 0
            sum = sum + hidden[i] * w
        end
        qValues[j] = sum
    end
    
    return qValues, hidden
end

function WCS_BrainDQN.QNetwork:CopyTo(targetNetwork)
    local cfg = WCS_BrainDQN.Config
    local stateSize = cfg.stateSize or 50
    local hiddenSize = cfg.hiddenSize or 128
    local actionSize = cfg.actionSize or 30
    
    targetNetwork.weightsInputHidden = {}
    for i = 1, stateSize do
        targetNetwork.weightsInputHidden[i] = {}
        for j = 1, hiddenSize do
            targetNetwork.weightsInputHidden[i][j] = self.weightsInputHidden[i][j]
        end
    end
    
    targetNetwork.biasHidden = {}
    for i = 1, hiddenSize do
        targetNetwork.biasHidden[i] = self.biasHidden[i]
    end
    
    targetNetwork.weightsHiddenOutput = {}
    for i = 1, hiddenSize do
        targetNetwork.weightsHiddenOutput[i] = {}
        for j = 1, actionSize do
            targetNetwork.weightsHiddenOutput[i][j] = self.weightsHiddenOutput[i][j]
        end
    end
    
    targetNetwork.biasOutput = {}
    for i = 1, actionSize do
        targetNetwork.biasOutput[i] = self.biasOutput[i]
    end
end

-- ============================================================================
-- TARGET NETWORK
-- ============================================================================
function WCS_BrainDQN.TargetNetwork:Forward(state)
    local cfg = WCS_BrainDQN.Config
    local hiddenSize = cfg.hiddenSize or 128
    local stateSize = cfg.stateSize or 50
    local actionSize = cfg.actionSize or 30
    
    local hidden = {}
    for j = 1, hiddenSize do
        local sum = self.biasHidden and self.biasHidden[j] or 0
        for i = 1, stateSize do
            local w = self.weightsInputHidden and self.weightsInputHidden[i] and self.weightsInputHidden[i][j] or 0
            sum = sum + (state[i] or 0) * w
        end
        if sum > 0 then hidden[j] = sum else hidden[j] = 0 end
    end
    
    local qValues = {}
    for j = 1, actionSize do
        local sum = self.biasOutput and self.biasOutput[j] or 0
        for i = 1, hiddenSize do
            local w = self.weightsHiddenOutput and self.weightsHiddenOutput[i] and self.weightsHiddenOutput[i][j] or 0
            sum = sum + hidden[i] * w
        end
        qValues[j] = sum
    end
    return qValues, hidden
end

-- ============================================================================
-- FUNCIONES PRINCIPALES
-- ============================================================================
function WCS_BrainDQN:SelectAction(state)
    if not state then return 1 end
    
    if math.random() < self.Config.epsilon then
        return math.random(self.Config.actionSize or 30)
    end
    
    local qValues = self.QNetwork:Forward(state)
    local bestAction = 1
    local bestValue = qValues[1] or 0
    
    local actionSize = self.Config.actionSize or 30
    for i = 2, actionSize do
        if (qValues[i] or 0) > bestValue then
            bestValue = qValues[i]
            bestAction = i
        end
    end
    
    return bestAction
end

function WCS_BrainDQN:StoreTransition(state, action, reward, nextState, done)
    self.ReplayBuffer:Add(state, action, reward, nextState, done)
end

-- Obtener estado codificado directamente del mundo (WCS_BrainState)
function WCS_BrainDQN:GetStateFromWorld()
    if WCS_BrainState and WCS_BrainState.CaptureState then
        return WCS_BrainState:CaptureState()
    end
    return nil
end

-- Actuar usando el estado real del juego y devolver una tabla compatible con WCS_Brain
function WCS_BrainDQN:ActFromWorld()
    local state = self:GetStateFromWorld()
    if not state then return nil end
    local idx = self:SelectAction(state)
    local actionName = nil
    if WCS_BrainActions and WCS_BrainActions.ActionMap then
        actionName = WCS_BrainActions.ActionMap[idx]
    end
    if not actionName then return nil end
    return { action = "CAST", spell = actionName, priority = 1, reason = "DQN Agent" }
end

-- Encode a simple state vector from a mock state (used for simulated training)
function WCS_BrainDQN:EncodeStateFromMock(mock)
    local cfg = self.Config
    local stateSize = cfg.stateSize or 50
    local s = {}
    for i = 1, stateSize do s[i] = 0 end
    -- Basic normalized vitals
    s[1] = (mock.playerHP or 100) / 100
    s[2] = (mock.playerMana or 100) / 100
    s[3] = (mock.targetHP or 100) / 100
    s[4] = (mock.petHP or 100) / 100
    -- Flags
    s[5] = mock.inCombat and 1 or 0
    s[6] = mock.moving and 1 or 0
    s[7] = ((mock.enemyCount or 1) / 10)
    s[8] = mock.hasHealthstone and 1 or 0
    s[9] = mock.hasSoulShards and 1 or 0
    s[10] = mock.targetIsPlayer and 1 or 0
    -- Heuristics: prefer execute phase
    s[11] = (mock.targetHP and mock.targetHP < 25) and 1 or 0
    -- Pet info
    s[12] = (mock.petType and mock.petType == "Voidwalker") and 1 or 0
    -- Target caster heuristic
    s[13] = mock.targetIsCaster and 1 or 0

    -- Encode first expected action as index fraction (helps learning mapping)
    if mock.expectedActions and WCS_BrainActions and WCS_BrainActions.GetActionIndex then
        local first = mock.expectedActions[1]
        local idx = WCS_BrainActions:GetActionIndex(first)
        if idx then
            s[14] = idx / (self.Config.actionSize or 30)
        else
            s[14] = 0
        end
    end

    -- Leave remaining entries zero (network can learn)
    return s
end

-- Simulated training using scenarios from WCS_BrainTesting
function WCS_BrainDQN:StopSimulatedTrain()
    if self._simFrame then
        self._simFrame:SetScript("OnUpdate", nil)
        self._simFrame = nil
    end
    self._simRunning = nil
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[DQN]|r Entrenamiento simulado detenido")
end

function WCS_BrainDQN:SimulatedTrain(episodes, stepsPerEpisode)
    episodes = tonumber(episodes) or 10
    stepsPerEpisode = tonumber(stepsPerEpisode) or 3
    if not WCS_BrainTesting or not WCS_BrainTesting.Scenarios then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DQN]|r No hay escenarios de testing disponibles para el entrenamiento simulado")
        return
    end

    -- Stop existing sim if running
    if self._simRunning then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[DQN]|r Ya hay un entrenamiento simulado en ejecución")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DQN]|r Iniciando entrenamiento simulado: " .. episodes .. " episodios x " .. stepsPerEpisode .. " pasos...")

    self._simRunning = true
    local total = episodes
    local completed = 0

    local simFrame = CreateFrame("Frame")
    self._simFrame = simFrame
    simFrame.elapsed = 0

    simFrame:SetScript("OnUpdate", function()
        if not self._simRunning then
            simFrame:SetScript("OnUpdate", nil)
            self._simFrame = nil
            return
        end

        simFrame.elapsed = simFrame.elapsed + arg1
        if simFrame.elapsed < 0.02 then return end
        simFrame.elapsed = 0

        -- Perform one episode per tick (keeps UI responsive)
        completed = completed + 1
        -- select scenario (cycle through) - Lua5.0 safe
        local n = WCS_TableCount(WCS_BrainTesting.Scenarios)
        if n == 0 then
            simFrame:SetScript("OnUpdate", nil)
            self._simFrame = nil
            self._simRunning = nil
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DQN]|r No hay escenarios de testing.")
            return
        end
        local idx = math.mod(completed - 1, n) + 1
        local scenario = WCS_BrainTesting.Scenarios[idx]

        local cumulativeReward = 0
        local state = nil
        for step = 1, stepsPerEpisode do
            local mock = WCS_BrainTesting:CreateMockState(scenario)
            mock.expectedActions = scenario.expectedActions
            mock.targetIsCaster = scenario.targetIsPlayer -- best effort fallback
            state = self:EncodeStateFromMock(mock)
            local actionIdx = self:SelectAction(state)
            local spell = (WCS_BrainActions and WCS_BrainActions:GetSpellName(actionIdx)) or tostring(actionIdx)

            -- shaped reward
            local reward = -0.1
            if WCS_BrainTesting and WCS_BrainTesting.ValidateDecision then
                if WCS_BrainTesting:ValidateDecision(spell, scenario.expectedActions) then
                    reward = 1.0
                    if scenario.priority == "high" then reward = reward + 0.5 end
                else
                    -- small penalty
                    reward = -0.2
                end
            else
                for _, e in ipairs(scenario.expectedActions or {}) do
                    if e == spell then reward = 1.0 break end
                end
            end

            -- Extra bonus for execute-phase correct actions
            if scenario.category == "execute" and (spell == "Shadowburn" or spell == "Drain Soul") then
                reward = reward + 0.5
            end

            cumulativeReward = cumulativeReward + reward
            local done = (step == stepsPerEpisode)
            local nextState = state
            self:StoreTransition(state, actionIdx, reward, nextState, done)
        end

        -- train after each episode
        self:Train()
        self.Stats.lastEpisodeReward = (self.Stats.lastEpisodeReward or 0) + cumulativeReward
        self:EndEpisode()

        if completed >= total then
            self._simRunning = nil
            if self._simFrame then
                self._simFrame:SetScript("OnUpdate", nil)
                self._simFrame = nil
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DQN]|r Entrenamiento simulado completado: " .. total .. " episodios. Buffer: " .. (self.ReplayBuffer.size or 0))
        end
    end)
end

function WCS_BrainDQN:Train()
    if self.ReplayBuffer.size < (self.Config.minBufferSize or 100) then
        return
    end
    
    local batch = self.ReplayBuffer:Sample(self.Config.batchSize or 32)
    if not batch then return end
    
    local cfg = self.Config
    local lr = cfg.learningRate or 0.001
    local gamma = cfg.gamma or 0.99
    local actionSize = cfg.actionSize or 30
    local hiddenSize = cfg.hiddenSize or 128
    local stateSize = cfg.stateSize or 50
    
    for idx = 1, WCS_TableCount(batch) do
        local transition = batch[idx]
        if transition then
            local state = transition.state
            local action = transition.action
            local reward = transition.reward
            local nextState = transition.nextState
            local done = transition.done
            
            local targetQ = reward
            if not done then
                local nextQValues = self.TargetNetwork:Forward(nextState)
                local maxNextQ = nextQValues[1] or 0
                for i = 2, actionSize do
                    if (nextQValues[i] or 0) > maxNextQ then
                        maxNextQ = nextQValues[i]
                    end
                end
                targetQ = reward + gamma * maxNextQ
            end
            
            local qValues, hidden = self.QNetwork:Forward(state)
            local predictedQ = qValues[action] or 0
            local err = targetQ - predictedQ
            
            for i = 1, hiddenSize do
                if self.QNetwork.weightsHiddenOutput[i] then
                    self.QNetwork.weightsHiddenOutput[i][action] = 
                        (self.QNetwork.weightsHiddenOutput[i][action] or 0) + lr * err * (hidden[i] or 0)
                end
            end
            if self.QNetwork.biasOutput then
                self.QNetwork.biasOutput[action] = (self.QNetwork.biasOutput[action] or 0) + lr * err
            end
            
            for i = 1, stateSize do
                for j = 1, hiddenSize do
                    if hidden[j] and hidden[j] > 0 then
                        local gradient = err * (self.QNetwork.weightsHiddenOutput[j] and self.QNetwork.weightsHiddenOutput[j][action] or 0)
                        if self.QNetwork.weightsInputHidden[i] then
                            self.QNetwork.weightsInputHidden[i][j] = 
                                (self.QNetwork.weightsInputHidden[i][j] or 0) + lr * gradient * (state[i] or 0)
                        end
                    end
                end
            end
        end
    end
    
    self.Stats.trainingSteps = (self.Stats.trainingSteps or 0) + 1
end

function WCS_BrainDQN:EndEpisode()
    self.Stats.episodes = (self.Stats.episodes or 0) + 1
    
    if self.Stats.episodes > 0 then
        self.Stats.avgReward = (self.Stats.totalReward or 0) / self.Stats.episodes
    end
    
    if (self.Stats.lastEpisodeReward or 0) > (self.Stats.bestEpisodeReward or -999999) then
        self.Stats.bestEpisodeReward = self.Stats.lastEpisodeReward
    end
    
    local epsilonMin = self.Config.epsilonMin or 0.1
    local epsilonDecay = self.Config.epsilonDecay or 0.995
    if self.Config.epsilon > epsilonMin then
        self.Config.epsilon = self.Config.epsilon * epsilonDecay
    end
    
    local trainInterval = self.Config.trainInterval or 5
    local function divisible(a, b)
        if not a or not b or b == 0 then return false end
        return math.floor(a / b) * b == a
    end

    if divisible(self.Stats.episodes, trainInterval) then
        self:Train()
    end

    local targetUpdateInterval = self.Config.targetUpdateInterval or 10
    if divisible(self.Stats.episodes, targetUpdateInterval) then
        self.QNetwork:CopyTo(self.TargetNetwork)
    end
end

-- ============================================================================
-- GUARDADO Y CARGA
-- ============================================================================
local function SerializeMatrix(matrix, rows, cols)
    local flat = {}
    local index = 1
    for i = 1, rows do
        for j = 1, cols do
            if matrix and matrix[i] and matrix[i][j] then
                flat[index] = matrix[i][j]
            else
                flat[index] = 0
            end
            index = index + 1
        end
    end
    return flat
end

local function DeserializeMatrix(flat, rows, cols)
    local matrix = {}
    local index = 1
    for i = 1, rows do
        matrix[i] = {}
        for j = 1, cols do
            matrix[i][j] = flat[index] or 0
            index = index + 1
        end
    end
    return matrix
end

function WCS_BrainDQN:Save()
    if not WCS_BrainSaved then WCS_BrainSaved = {} end
    
    local cfg = self.Config
    local stateSize = cfg.stateSize or 50
    local hiddenSize = cfg.hiddenSize or 128
    local actionSize = cfg.actionSize or 30
    
    local networkData = {
        wih = SerializeMatrix(self.QNetwork.weightsInputHidden, stateSize, hiddenSize),
        bh = {},
        who = SerializeMatrix(self.QNetwork.weightsHiddenOutput, hiddenSize, actionSize),
        bo = {}
    }
    
    for i = 1, hiddenSize do
        networkData.bh[i] = self.QNetwork.biasHidden[i] or 0
    end
    for i = 1, actionSize do
        networkData.bo[i] = self.QNetwork.biasOutput[i] or 0
    end
    
    local bufferData = {
        index = self.ReplayBuffer.index or 1,
        size = self.ReplayBuffer.size or 0,
        transitions = {}
    }
    local maxSave = self.ReplayBuffer.size or 0
    if maxSave > 1000 then maxSave = 1000 end
    local bufCap = WCS_BrainDQN.Config.bufferSize or 10000
    local start = (self.ReplayBuffer.index or 1) - (self.ReplayBuffer.size or 0)
    for i = 1, maxSave do
        local idx = start + i - 1
        while idx < 1 do idx = idx + bufCap end
        while idx > bufCap do idx = idx - bufCap end
        local t = self.ReplayBuffer.buffer and self.ReplayBuffer.buffer[idx]
        if t then
            bufferData.transitions[i] = {
                s = t.state,
                a = t.action,
                r = t.reward,
                ns = t.nextState,
                d = t.done and 1 or 0
            }
        end
    end
    
    WCS_BrainSaved.DQN = {
        version = self.VERSION,
            tag = (WCS_Helpers and WCS_Helpers.VersionTag) and WCS_Helpers.VersionTag("WCS_BrainDQN", self.VERSION) or self.VERSION,
        config = {
            stateSize = stateSize,
            epsilon = self.Config.epsilon,
            learningRate = self.Config.learningRate,
            gamma = self.Config.gamma,
            hiddenSize = hiddenSize,
            actionSize = actionSize
        },
        stats = {
            episodes = self.Stats.episodes or 0,
            totalReward = self.Stats.totalReward or 0,
            avgReward = self.Stats.avgReward or 0,
            wins = self.Stats.wins or 0,
            losses = self.Stats.losses or 0,
            trainingSteps = self.Stats.trainingSteps or 0,
            lastEpisodeReward = self.Stats.lastEpisodeReward or 0,
            bestEpisodeReward = self.Stats.bestEpisodeReward or -999999
        },
        enabled = self.enabled,
        network = networkData,
        buffer = bufferData
    }
end

function WCS_BrainDQN:Load()
    if not WCS_BrainSaved or not WCS_BrainSaved.DQN then
        return false
    end
    
    local data = WCS_BrainSaved.DQN
    
    if data.config then
        self.Config.epsilon = data.config.epsilon or 1.0
        self.Config.learningRate = data.config.learningRate or 0.001
        self.Config.gamma = data.config.gamma or 0.99
    end
    
    if data.stats then
        self.Stats.episodes = data.stats.episodes or 0
        self.Stats.totalReward = data.stats.totalReward or 0
        self.Stats.avgReward = data.stats.avgReward or 0
        self.Stats.wins = data.stats.wins or 0
        self.Stats.losses = data.stats.losses or 0
        self.Stats.trainingSteps = data.stats.trainingSteps or 0
        self.Stats.lastEpisodeReward = data.stats.lastEpisodeReward or 0
        self.Stats.bestEpisodeReward = data.stats.bestEpisodeReward or -999999
    end
    
    if data.enabled ~= nil then
        self.enabled = data.enabled
    end
    
    local stateSize = self.Config.stateSize or 50
    local savedHiddenSize = data.config and data.config.hiddenSize or 128
    local savedActionSize = data.config and data.config.actionSize or 30
    local currentActionSize = self.Config.actionSize or 30
    
    local networkLoaded = false
    
    if savedActionSize == currentActionSize and data.network and data.network.wih and data.network.who then
        self.QNetwork.weightsInputHidden = DeserializeMatrix(data.network.wih, stateSize, savedHiddenSize)
        self.QNetwork.weightsHiddenOutput = DeserializeMatrix(data.network.who, savedHiddenSize, savedActionSize)
        
        self.QNetwork.biasHidden = {}
        self.QNetwork.biasOutput = {}
        
        for i = 1, savedHiddenSize do
            self.QNetwork.biasHidden[i] = data.network.bh[i] or 0
        end
        for i = 1, savedActionSize do
            self.QNetwork.biasOutput[i] = data.network.bo[i] or 0
        end
        
        self.Config.hiddenSize = savedHiddenSize
        networkLoaded = true
    end
    
    if data.buffer and data.buffer.transitions then
        local bufCap = self.Config.bufferSize or 10000
        local tmp = {}
        local maxk = 0
        for k, v in pairs(data.buffer.transitions) do
            if type(k) == "number" and v then
                tmp[k] = v
                if k > maxk then maxk = k end
            end
        end

        self.ReplayBuffer.buffer = {}

        for i = 1, maxk do
            local t = tmp[i]
            if t then
                table.insert(self.ReplayBuffer.buffer, {
                    state = t.s,
                    action = t.a,
                    reward = t.r,
                    nextState = t.ns,
                    done = (t.d == 1)
                })
                local curSize = WCS_TableCount(self.ReplayBuffer.buffer)
                if curSize >= bufCap then break end
            end
        end

        self.ReplayBuffer.size = WCS_TableCount(self.ReplayBuffer.buffer)
        self.ReplayBuffer.index = self.ReplayBuffer.size + 1
        while self.ReplayBuffer.index > bufCap do self.ReplayBuffer.index = self.ReplayBuffer.index - bufCap end
    end
    
    return networkLoaded
end

function WCS_BrainDQN:Reset()
    self.QNetwork:Initialize()
    self.QNetwork:CopyTo(self.TargetNetwork)
    self.ReplayBuffer:Clear()
    
    self.Stats = {
        episodes = 0,
        totalReward = 0,
        avgReward = 0,
        wins = 0,
        losses = 0,
        trainingSteps = 0,
        lastEpisodeReward = 0,
        bestEpisodeReward = -999999
    }
    
    self.Config.epsilon = 1.0
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DQN]|r Red neuronal reseteada (" .. (self.Config.actionSize or 30) .. " acciones)")
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_BRAINDQN1 = "/braindqn"
SlashCmdList["BRAINDQN"] = function(msg)
    local cmd = msg or ""
    local arg = ""
    
    local spacePos = string.find(msg, " ")
    if spacePos then
        cmd = string.sub(msg, 1, spacePos - 1)
        arg = string.sub(msg, spacePos + 1)
    end
    
    cmd = string.lower(cmd)
    
    if cmd == "on" then
        WCS_BrainDQN.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DQN]|r ACTIVADO")
    elseif cmd == "off" then
        WCS_BrainDQN.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DQN]|r DESACTIVADO")
    elseif cmd == "status" then
        local status = WCS_BrainDQN.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[DQN]|r " .. status .. " | Ep:" .. (WCS_BrainDQN.Stats.episodes or 0) .. " | Buf:" .. (WCS_BrainDQN.ReplayBuffer.size or 0))
    elseif cmd == "reset" then
        WCS_BrainDQN:Reset()
    elseif cmd == "save" then
        WCS_BrainDQN:Save()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DQN]|r Guardado")
    elseif cmd == "epsilon" and arg then
        local value = tonumber(arg)
        if value and value >= 0 and value <= 1 then
            WCS_BrainDQN.Config.epsilon = value
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DQN]|r Epsilon: " .. value)
        end
    elseif cmd == "trainsim" then
        if arg == "stop" then
            WCS_BrainDQN:StopSimulatedTrain()
        else
            local n = tonumber(arg) or 10
            WCS_BrainDQN:SimulatedTrain(n, 3)
        end
    elseif cmd == "trainsim" then
        local n = tonumber(arg) or 10
        WCS_BrainDQN:SimulatedTrain(n)
    elseif cmd == "print" or cmd == "printaction" then
        local a = WCS_BrainDQN:ActFromWorld()
        if not a then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[DQN]|r Acción desde mundo: nil")
        else
            local msg = "|cFFFFFF00[DQN]|r Action=" .. tostring(a.action) .. " Spell=" .. tostring(a.spell)
            if a.priority then msg = msg .. " Pri=" .. tostring(a.priority) end
            if a.reason then msg = msg .. " (" .. tostring(a.reason) .. ")" end
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[DQN]|r on/off/status/reset/save/epsilon <0-1>")
    end
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
local function EnsureDefaults()
    local cfg = WCS_BrainDQN.Config
    if not cfg.learningRate then cfg.learningRate = 0.001 end
    if not cfg.gamma then cfg.gamma = 0.99 end
    if not cfg.epsilon then cfg.epsilon = 1.0 end
    if not cfg.epsilonMin then cfg.epsilonMin = 0.1 end
    if not cfg.epsilonDecay then cfg.epsilonDecay = 0.995 end
    if not cfg.bufferSize then cfg.bufferSize = 10000 end
    if not cfg.batchSize then cfg.batchSize = 32 end
    if not cfg.minBufferSize then cfg.minBufferSize = 100 end
    if not cfg.stateSize then cfg.stateSize = 50 end
    if not cfg.actionSize then cfg.actionSize = 30 end
    if not cfg.hiddenSize then cfg.hiddenSize = 128 end
    if not cfg.trainInterval then cfg.trainInterval = 5 end
    if not cfg.targetUpdateInterval then cfg.targetUpdateInterval = 10 end
    if not cfg.autoSaveInterval then cfg.autoSaveInterval = 300 end
    if not cfg.saveOnLogout then cfg.saveOnLogout = true end
    
    local buf = WCS_BrainDQN.ReplayBuffer
    if buf.buffer == nil then buf.buffer = {} end
    if buf.index == nil then buf.index = 1 end
    if buf.size == nil then buf.size = 0 end
    
    local stats = WCS_BrainDQN.Stats
    if not stats.episodes then stats.episodes = 0 end
    if not stats.totalReward then stats.totalReward = 0 end
    if not stats.avgReward then stats.avgReward = 0 end
    if not stats.wins then stats.wins = 0 end
    if not stats.losses then stats.losses = 0 end
    if not stats.trainingSteps then stats.trainingSteps = 0 end
    if not stats.lastEpisodeReward then stats.lastEpisodeReward = 0 end
    if not stats.bestEpisodeReward then stats.bestEpisodeReward = -999999 end
end

function WCS_BrainDQN:Initialize()
    local loaded = self:Load()
    EnsureDefaults()
    
    if not loaded then
        self.QNetwork:Initialize()
    end
    
    self.QNetwork:CopyTo(self.TargetNetwork)
end

-- ============================================================================
-- AUTO-INICIALIZACION
-- ============================================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGOUT")
initFrame:RegisterEvent("PLAYER_LEAVING_WORLD")

local autoSaveElapsed = 0

initFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainDQN:Initialize()
        
        initFrame:SetScript("OnUpdate", function()
            autoSaveElapsed = autoSaveElapsed + arg1
            if autoSaveElapsed >= (WCS_BrainDQN.Config.autoSaveInterval or 300) then
                autoSaveElapsed = 0
                if WCS_BrainDQN.enabled and (WCS_BrainDQN.Stats.episodes or 0) > 0 then
                    WCS_BrainDQN:Save()
                end
            end
        end)
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        if WCS_BrainDQN.Config.saveOnLogout then
            WCS_BrainDQN:Save()
        end
    end
end)

