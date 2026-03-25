--[[
    WCS_BrainThoughts.lua - Ventana de Pensamientos del DQN
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Muestra en tiempo real lo que el DQN esta "pensando"
]]--

WCS_BrainThoughts = WCS_BrainThoughts or {}
WCS_BrainThoughts.VERSION = "6.4.2"

-- ============================================================================
-- CONFIGURACION
-- ============================================================================
WCS_BrainThoughts.Config = {
    width = 300,
    height = 320,  -- Mas alto para mostrar mas datos
    updateInterval = 0.1,  -- Actualizar cada 100ms
    maxLines = 12,
    showQValues = true,
    showState = true,
    showReward = true,
    showStats = true,
    showBuffer = true
}

-- ============================================================================
-- MAPEO DE ACCIONES (para mostrar nombres)
-- ============================================================================
local ActionNames = {
    [1] = "Shadow Bolt",
    [2] = "Corruption",
    [3] = "Curse of Agony",
    [4] = "Immolate",
    [5] = "Siphon Life",
    [6] = "Life Tap",
    [7] = "Dark Pact",
    [8] = "Death Coil",
    [9] = "Shadowburn",
    [10] = "Fear",
    [11] = "Drain Life",
    [12] = "Healthstone",
    [13] = "WAIT"
}

-- Iconos de acciones (texturas de WoW)
local ActionIcons = {
    [1] = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    [2] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
    [3] = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    [4] = "Interface\\Icons\\Spell_Fire_Immolation",
    [5] = "Interface\\Icons\\Spell_Shadow_Requiem",
    [6] = "Interface\\Icons\\Spell_Shadow_BurningSpirit",
    [7] = "Interface\\Icons\\Spell_Shadow_SiphonMana",
    [8] = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    [9] = "Interface\\Icons\\Spell_Shadow_ScourgeBuild",
    [10] = "Interface\\Icons\\Spell_Shadow_Possession",
    [11] = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
    [12] = "Interface\\Icons\\INV_Stone_04",
    [13] = "Interface\\Icons\\Spell_Holy_BorrowedTime"
}

-- ============================================================================
-- UTILIDADES LUA 5.0
-- ============================================================================
local function Round(num, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function FormatPercent(value)
    return string.format("%.0f%%", (value or 0) * 100)
end

local function GetColorForValue(value, inverse)
    -- Retorna color basado en valor (0-1)
    -- inverse: true si valores bajos son buenos (ej: HP enemigo)
    if inverse then value = 1 - value end
    
    if value > 0.7 then
        return "|cFF00FF00"  -- Verde
    elseif value > 0.4 then
        return "|cFFFFFF00"  -- Amarillo
    else
        return "|cFFFF0000"  -- Rojo
    end
end

-- ============================================================================
-- CREAR FRAME PRINCIPAL
-- ============================================================================
function WCS_BrainThoughts:CreateFrame()
    if self.MainFrame then return end
    
    local cfg = self.Config
    
    -- Frame principal
    local frame = CreateFrame("Frame", "WCS_BrainThoughtsFrame", UIParent)
    frame:SetWidth(cfg.width)
    frame:SetHeight(cfg.height)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -150)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    
    -- Fondo semi-transparente
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.6, 0.2, 0.8, 1)  -- Borde morado (warlock)
    
    -- Hacer draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    -- Titulo
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", frame, "TOP", 0, -8)
    title:SetText("|cFF9370DBWCS Brain - Pensamientos|r")
    self.TitleText = title
    
    -- Boton cerrar
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetWidth(20)
    closeBtn:SetHeight(20)
    closeBtn:SetScript("OnClick", function() WCS_BrainThoughts:Hide() end)
    
    -- Icono de accion actual
    local actionIcon = frame:CreateTexture(nil, "ARTWORK")
    actionIcon:SetWidth(32)
    actionIcon:SetHeight(32)
    actionIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -25)
    actionIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.ActionIcon = actionIcon
    
    -- Nombre de accion actual
    local actionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionText:SetPoint("LEFT", actionIcon, "RIGHT", 8, 0)
    actionText:SetText("Esperando...")
    actionText:SetTextColor(1, 1, 1)
    self.ActionText = actionText
    
    -- Linea separadora
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -62)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -62)
    sep:SetTexture(0.5, 0.3, 0.7, 0.5)
    
    -- Area de texto para info
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -68)
    infoText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -68)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    infoText:SetText("")
    self.InfoText = infoText
    
    -- Stats display (nueva seccion)
    local statsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -100)
    statsText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -100)
    statsText:SetJustifyH("LEFT")
    statsText:SetJustifyV("TOP")
    statsText:SetText("")
    self.StatsText = statsText
    
    -- Linea separadora 2
    local sep2 = frame:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -145)
    sep2:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -145)
    sep2:SetTexture(0.5, 0.3, 0.7, 0.5)
    
    -- Q-Values label
    local qLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -150)
    qLabel:SetText("|cFF9370DBTop Q-Values:|r")
    
    -- Q-Values display (barras)
    self.QValueBars = {}
    self.QValueLabels = {}
    self.QValueNumbers = {}
    local barStartY = -165
    local barHeight = 8
    local barSpacing = 14
    
    -- Solo mostrar top 5 acciones
    for i = 1, 5 do
        -- Barra de fondo (dejar espacio para numeros a la derecha)
        local bgBar = frame:CreateTexture(nil, "BACKGROUND")
        bgBar:SetHeight(barHeight)
        bgBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, barStartY - (i-1) * barSpacing)
        bgBar:SetWidth(160)  -- Ancho fijo para dejar espacio al numero
        bgBar:SetTexture(0.2, 0.2, 0.2, 0.8)
        
        -- Barra de valor
        local bar = frame:CreateTexture(nil, "ARTWORK")
        bar:SetHeight(barHeight)
        bar:SetPoint("TOPLEFT", bgBar, "TOPLEFT", 0, 0)
        bar:SetWidth(1)
        bar:SetTexture(0.6, 0.2, 0.8, 1)
        self.QValueBars[i] = bar
        
        -- Label (nombre de accion)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("RIGHT", bgBar, "LEFT", -4, 0)
        label:SetText("")
        label:SetTextColor(0.8, 0.8, 0.8)
        self.QValueLabels[i] = label
        
        -- Numero Q-value
        local qNum = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qNum:SetPoint("LEFT", bgBar, "RIGHT", 2, 0)
        qNum:SetText("")
        qNum:SetTextColor(0.7, 0.7, 0.7)
        self.QValueNumbers[i] = qNum
    end
    
    -- Linea separadora 3
    local sep3 = frame:CreateTexture(nil, "ARTWORK")
    sep3:SetHeight(1)
    sep3:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -240)
    sep3:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -240)
    sep3:SetTexture(0.5, 0.3, 0.7, 0.5)
    
    -- Buffer info
    local bufferText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bufferText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -248)
    bufferText:SetText("")
    self.BufferText = bufferText
    
    -- Training info
    local trainText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trainText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -262)
    trainText:SetText("")
    self.TrainText = trainText
    
    -- Combat state
    local combatText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    combatText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -276)
    combatText:SetText("")
    self.CombatText = combatText
    
    -- Estado DQN
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    statusText:SetText("|cFF888888DQN: OFF|r")
    self.StatusText = statusText
    
    -- Epsilon
    local epsilonText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epsilonText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    epsilonText:SetText("")
    self.EpsilonText = epsilonText
    
    self.MainFrame = frame
    
    -- Iniciar actualizacion
    self:StartUpdate()
end

-- ============================================================================
-- ACTUALIZAR DISPLAY
-- ============================================================================
function WCS_BrainThoughts:Update()
    if not self.MainFrame or not self.MainFrame:IsVisible() then return end
    
    -- Verificar si DQN existe y esta activo
    local dqnActive = WCS_BrainDQN and WCS_BrainDQN.enabled
    
    if dqnActive then
        self.StatusText:SetText("|cFF00FF00DQN: ON|r")
    else
        self.StatusText:SetText("|cFFFF0000DQN: OFF|r")
    end
    
    -- Mostrar epsilon
    if WCS_BrainDQN and WCS_BrainDQN.Config then
        local eps = WCS_BrainDQN.Config.epsilon or 1
        local epsColor = eps > 0.5 and "|cFFFF6600" or "|cFF00FF00"
        self.EpsilonText:SetText(epsColor .. "e=" .. string.format("%.2f", eps) .. "|r")
    end
    
    -- Obtener accion actual
    local currentAction = nil
    local qValues = nil
    
    if WCS_BrainIntegration then
        currentAction = WCS_BrainIntegration.CurrentAction
    end
    
    -- Obtener Q-values si hay estado
    if dqnActive and WCS_BrainState and WCS_BrainDQN.QNetwork then
        local state = WCS_BrainState:CaptureState()
        if state then
            qValues = WCS_BrainDQN.QNetwork:Forward(state)
        end
    end
    
    -- Actualizar icono y texto de accion
    if currentAction and ActionNames[currentAction] then
        self.ActionIcon:SetTexture(ActionIcons[currentAction] or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.ActionText:SetText("|cFFFFFFFF" .. ActionNames[currentAction] .. "|r")
    else
        self.ActionIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.ActionText:SetText("|cFF888888Esperando...|r")
    end
    
    -- Construir texto de info
    local infoLines = {}
    
    -- Estado del jugador
    if WCS_BrainState then
        local state = WCS_BrainState:CaptureState()
        if state then
            local hpColor = GetColorForValue(state[1], false)
            local manaColor = GetColorForValue(state[2], false)
            local tgtColor = GetColorForValue(state[11], true)
            
            table.insert(infoLines, hpColor .. "HP: " .. FormatPercent(state[1]) .. "|r  " ..
                         manaColor .. "Mana: " .. FormatPercent(state[2]) .. "|r")
            
            if state[12] > 0 then  -- Tiene target
                table.insert(infoLines, tgtColor .. "Target: " .. FormatPercent(state[11]) .. "|r  " ..
                             "|cFFFFFF00DoTs: " .. string.format("%.0f", state[27] * 4) .. "|r")
            else
                table.insert(infoLines, "|cFF888888Sin target|r")
            end
        end
    end
    
    self.InfoText:SetText(table.concat(infoLines, "\n"))
    
    -- ================================================================
    -- ESTADISTICAS DQN
    -- ================================================================
    local statsLines = {}
    
    if WCS_BrainDQN and WCS_BrainDQN.Stats then
        local stats = WCS_BrainDQN.Stats
        
        -- Episodios y Win/Loss
        local episodes = stats.episodes or 0
        local wins = stats.wins or 0
        local losses = stats.losses or 0
        local winRate = 0
        if (wins + losses) > 0 then
            winRate = (wins / (wins + losses)) * 100
        end
        
        table.insert(statsLines, "|cFFFFFFFFEp:|r " .. episodes .. "  |cFF00FF00W:|r" .. wins .. " |cFFFF0000L:|r" .. losses .. " (" .. string.format("%.0f", winRate) .. "%%)")
        
        -- Recompensas
        local lastReward = stats.lastEpisodeReward or 0
        local avgReward = stats.avgReward or 0
        local bestReward = stats.bestEpisodeReward or 0
        local lastColor = lastReward >= 0 and "|cFF00FF00" or "|cFFFF0000"
        local avgColor = avgReward >= 0 and "|cFF00FF00" or "|cFFFF0000"
        
        table.insert(statsLines, lastColor .. "Last:|r " .. string.format("%.1f", lastReward) .. "  " .. avgColor .. "Avg:|r " .. string.format("%.1f", avgReward) .. "  |cFFFFD700Best:|r " .. string.format("%.1f", bestReward))
    else
        table.insert(statsLines, "|cFF888888Sin estadisticas|r")
    end
    
    self.StatsText:SetText(table.concat(statsLines, "\n"))
    
    -- Actualizar barras de Q-values
    if qValues then
        -- Ordenar acciones por Q-value
        local sorted = {}
        for i = 1, 13 do
            table.insert(sorted, {action = i, qvalue = qValues[i] or 0})
        end
        
        -- Bubble sort (Lua 5.0 compatible)
        for i = 1, WCS_TableCount(sorted) - 1 do
            for j = 1, WCS_TableCount(sorted) - i do
                if sorted[j].qvalue < sorted[j+1].qvalue then
                    local temp = sorted[j]
                    sorted[j] = sorted[j+1]
                    sorted[j+1] = temp
                end
            end
        end
        
        -- Encontrar min/max para normalizar
        local minQ = sorted[WCS_TableCount(sorted)].qvalue
        local maxQ = sorted[1].qvalue
        local range = maxQ - minQ
        if range < 0.001 then range = 1 end
        
        -- Mostrar top 5
        for i = 1, 5 do
            local data = sorted[i]
            if data then
                local normalized = (data.qvalue - minQ) / range
                local barWidth = math.max(1, normalized * 158)  -- 160 - 2 de margen
                
                self.QValueBars[i]:SetWidth(barWidth)
                
                -- Color basado en si es la accion elegida
                if data.action == currentAction then
                    self.QValueBars[i]:SetTexture(0.2, 1, 0.2, 1)  -- Verde brillante
                else
                    self.QValueBars[i]:SetTexture(0.6, 0.2, 0.8, 0.8)  -- Morado
                end
                
                -- Abreviar nombre
                local shortName = ActionNames[data.action] or "?"
                if string.len(shortName) > 6 then
                    shortName = string.sub(shortName, 1, 5) .. "."
                end
                self.QValueLabels[i]:SetText(shortName)
                
                -- Mostrar valor Q numerico
                if self.QValueNumbers and self.QValueNumbers[i] then
                    self.QValueNumbers[i]:SetText(string.format("%.2f", data.qvalue))
                end
            end
        end
    else
        -- Sin Q-values, limpiar barras
        for i = 1, 5 do
            self.QValueBars[i]:SetWidth(1)
            self.QValueLabels[i]:SetText("")
            if self.QValueNumbers and self.QValueNumbers[i] then
                self.QValueNumbers[i]:SetText("")
            end
        end
    end
    
    -- ================================================================
    -- BUFFER INFO
    -- ================================================================
    if self.BufferText then
        if WCS_BrainDQN and WCS_BrainDQN.ReplayBuffer then
            local bufSize = WCS_BrainDQN.ReplayBuffer.size or 0
            local bufMax = WCS_BrainDQN.Config.bufferSize or 10000
            local bufPercent = (bufSize / bufMax) * 100
            local bufColor = bufPercent > 50 and "|cFF00FF00" or "|cFFFFFF00"
            self.BufferText:SetText("|cFF9370DBBuffer:|r " .. bufColor .. bufSize .. "|r/" .. bufMax .. " (" .. string.format("%.0f", bufPercent) .. "%%)")
        else
            self.BufferText:SetText("|cFF888888Buffer: N/A|r")
        end
    end
    
    -- ================================================================
    -- TRAINING INFO
    -- ================================================================
    if self.TrainText then
        if WCS_BrainDQN and WCS_BrainDQN.Stats then
            local steps = WCS_BrainDQN.Stats.trainingSteps or 0
            local avgLoss = WCS_BrainDQN.Stats.avgLoss or 0
            local avgQ = WCS_BrainDQN.Stats.avgQValue or 0
            self.TrainText:SetText("|cFF9370DBTrain:|r " .. steps .. " steps  |cFFFFAA00Loss:|r" .. string.format("%.3f", avgLoss) .. "  |cFF00FFFFAvgQ:|r" .. string.format("%.2f", avgQ))
        else
            self.TrainText:SetText("|cFF888888Training: N/A|r")
        end
    end
    
    -- ================================================================
    -- COMBAT STATE
    -- ================================================================
    if self.CombatText then
        local inCombat = UnitAffectingCombat("player")
        local hasPet = UnitExists("pet")
        local petHP = 0
        if hasPet then
            local petMax = UnitHealthMax("pet") or 1
            local petCur = UnitHealth("pet") or 0
            if petMax > 0 then petHP = (petCur / petMax) * 100 end
        end
        
        local combatStr = inCombat and "|cFFFF0000[COMBAT]|r" or "|cFF00FF00[IDLE]|r"
        local petStr = ""
        if hasPet then
            local petColor = petHP > 50 and "|cFF00FF00" or (petHP > 25 and "|cFFFFFF00" or "|cFFFF0000")
            petStr = "  |cFF9370DBPet:|r" .. petColor .. string.format("%.0f", petHP) .. "%%|r"
        end
        
        self.CombatText:SetText(combatStr .. petStr)
    end
end

-- ============================================================================
-- CONTROL DE ACTUALIZACION
-- ============================================================================
function WCS_BrainThoughts:StartUpdate()
    if not self.UpdateFrame then
        self.UpdateFrame = CreateFrame("Frame")
    end
    
    local elapsed = 0
    local interval = self.Config.updateInterval
    
    self.UpdateFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= interval then
            elapsed = 0
            WCS_BrainThoughts:Update()
        end
    end)
end

function WCS_BrainThoughts:StopUpdate()
    if self.UpdateFrame then
        self.UpdateFrame:SetScript("OnUpdate", nil)
    end
end

-- ============================================================================
-- MOSTRAR/OCULTAR
-- ============================================================================
function WCS_BrainThoughts:Show()
    if not self.MainFrame then
        self:CreateFrame()
    end
    self.MainFrame:Show()
    self:StartUpdate()
end

function WCS_BrainThoughts:Hide()
    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

function WCS_BrainThoughts:Toggle()
    if self.MainFrame and self.MainFrame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_BRAINTHOUGHTS1 = "/brainthoughts"
SLASH_BRAINTHOUGHTS2 = "/thoughts"
SlashCmdList["BRAINTHOUGHTS"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "show" then
        WCS_BrainThoughts:Show()
    elseif cmd == "hide" then
        WCS_BrainThoughts:Hide()
    else
        WCS_BrainThoughts:Toggle()
    end
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    -- Auto-mostrar si DQN esta activo
    if WCS_BrainDQN and WCS_BrainDQN.enabled then
        WCS_BrainThoughts:Show()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[WCS_BrainThoughts]|r v" .. WCS_BrainThoughts.VERSION .. " cargado. Usa /thoughts para toggle")
end)

