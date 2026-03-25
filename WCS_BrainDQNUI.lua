--[[
    WCS_BrainDQNUI.lua - Interfaz Grafica Deep Q-Network v1.0.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Diseno Warlock con tema purpura/verde fel
    Estilo consistente con WCS_BrainUI
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainDQNUI = WCS_BrainDQNUI or {}
WCS_BrainDQNUI.VERSION = "6.4.2"

-- ============================================================================
-- COLORES WARLOCK (consistente con WCS_BrainUI)
-- ============================================================================
local COLORS = {
    -- Tema principal
    WARLOCK_PURPLE = {0.58, 0.51, 0.79},
    FEL_GREEN = {0.0, 1.0, 0.5},
    SHADOW = {0.4, 0.2, 0.6},
    
    -- Estados
    ACTIVE = {0.0, 1.0, 0.5},
    INACTIVE = {1.0, 0.2, 0.2},
    WARNING = {1.0, 0.7, 0.0},
    
    -- UI
    BG_DARK = {0.08, 0.06, 0.12},
    BG_SECTION = {0.12, 0.10, 0.18},
    BORDER = {0.5, 0.4, 0.7},
    TEXT_DIM = {0.6, 0.6, 0.6},
    TEXT_BRIGHT = {1.0, 1.0, 1.0},
    GOLD = {1.0, 0.82, 0.0},
    CYAN = {0.0, 0.8, 1.0}
}

-- Frame principal y referencias
local mainFrame = nil
local updateTimer = 0
local UPDATE_INTERVAL = 0.5

-- Referencias a elementos UI
local statusText = nil
local episodesText = nil
local rewardText = nil
local epsilonText = nil
local lossText = nil
local qValueText = nil
local replayText = nil
local archText1 = nil
local archText2 = nil
local archText3 = nil
local archText4 = nil
local epsilonSlider = nil
local toggleButton = nil
local statusSection = nil

-- ============================================================================
-- UTILIDADES
-- ============================================================================
local function CreateSection(parent, x, y, width, height, title)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    frame:SetBackdropColor(COLORS.BG_SECTION[1], COLORS.BG_SECTION[2], COLORS.BG_SECTION[3], 0.95)
    frame:SetBackdropBorderColor(COLORS.BORDER[1], COLORS.BORDER[2], COLORS.BORDER[3], 0.8)
    
    if title then
        local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
        titleText:SetText("|cFF9482C9" .. title .. "|r")
    end
    
    return frame
end

-- ============================================================================
-- CREAR FRAME PRINCIPAL
-- ============================================================================
function WCS_BrainDQNUI:CreateMainFrame()
    if mainFrame then
        return mainFrame
    end
    
    -- Frame principal
    mainFrame = CreateFrame("Frame", "WCS_BrainDQNMainFrame", UIParent)
    mainFrame:SetWidth(680)
    mainFrame:SetHeight(540)
    mainFrame:SetMovable(false)
    mainFrame:SetFrameStrata("MEDIUM")
    WCS_BrainDQNUI.MainFrame = mainFrame
    
    -- Fondo principal oscuro
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    mainFrame:SetBackdropColor(COLORS.BG_DARK[1], COLORS.BG_DARK[2], COLORS.BG_DARK[3], 0.97)
    mainFrame:SetBackdropBorderColor(COLORS.WARLOCK_PURPLE[1], COLORS.WARLOCK_PURPLE[2], COLORS.WARLOCK_PURPLE[3], 1)
    mainFrame:Hide()
    
    -- Crear secciones
    self:CreateHeader(mainFrame)
    self:CreateStatusSection(mainFrame)
    self:CreateStatsSection(mainFrame)
    self:CreateArchitectureSection(mainFrame)
    self:CreateConfigSection(mainFrame)
    
    -- Script de actualizacion optimizado
    if WCS_UpdateManager then
        -- Usar UpdateManager centralizado
        WCS_UpdateManager:RegisterCallback("ui", "DQN_UI", function()
            WCS_BrainDQNUI:UpdateUI()
        end)
    else
        -- Fallback: OnUpdate local con throttling mejorado
        mainFrame:SetScript("OnUpdate", function()
            updateTimer = updateTimer + arg1
            -- Optimizado: DQN UI actualiza cada 1s (no necesita alta frecuencia)
            if updateTimer >= 1.0 then
                updateTimer = 0
                WCS_BrainDQNUI:UpdateUI()
            end
        end)
    end
    
    return mainFrame
end

-- ============================================================================
-- HEADER
-- ============================================================================
function WCS_BrainDQNUI:CreateHeader(parent)
    -- Titulo principal
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", parent, "TOP", 0, -12)
    title:SetText("|cFF9482C9WCS|r |cFF00FF00DQN|r")
    
    -- Subtitulo
    local subtitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("|cFF666666Deep Q-Network v" .. self.VERSION .. "|r")
    
    -- Boton cerrar
    local closeBtn = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)
    
    -- Linea separadora
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -42)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -42)
    line:SetHeight(1)
    line:SetTexture(1, 1, 1, 0.2)
end

-- ============================================================================
-- SECCION: ESTADO Y CONTROLES
-- ============================================================================
function WCS_BrainDQNUI:CreateStatusSection(parent)
    statusSection = CreateSection(parent, 10, -50, 300, 70, nil)
    
    -- Estado (izquierda)
    statusText = statusSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("LEFT", statusSection, "LEFT", 15, 10)
    statusText:SetText("|cFFFF0000INACTIVO|r")
    
    -- Botones de control
    toggleButton = CreateFrame("Button", "WCS_DQNToggleBtn", statusSection, "UIPanelButtonTemplate")
    toggleButton:SetWidth(85)
    toggleButton:SetHeight(24)
    toggleButton:SetPoint("TOPLEFT", statusSection, "TOPLEFT", 10, -35)
    toggleButton:SetText("Activar")
    toggleButton:SetScript("OnClick", function()
        if WCS_BrainDQN then
            if WCS_BrainDQN.enabled then
                WCS_BrainDQN.enabled = false
                DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[DQN]|r Sistema |cFFFF0000desactivado|r")
            else
                WCS_BrainDQN.enabled = true
                DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[DQN]|r Sistema |cFF00FF00activado|r")
            end
            WCS_BrainDQNUI:UpdateUI()
        end
    end)
    
    local resetButton = CreateFrame("Button", "WCS_DQNResetBtn", statusSection, "UIPanelButtonTemplate")
    resetButton:SetWidth(85)
    resetButton:SetHeight(24)
    resetButton:SetPoint("LEFT", toggleButton, "RIGHT", 5, 0)
    resetButton:SetText("Reset")
    resetButton:SetScript("OnClick", function()
        if WCS_BrainDQN and WCS_BrainDQN.Reset then
            WCS_BrainDQN:Reset()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[DQN]|r Red neuronal |cFFFFAA00reseteada|r")
            WCS_BrainDQNUI:UpdateUI()
        end
    end)
    
    local saveButton = CreateFrame("Button", "WCS_DQNSaveBtn", statusSection, "UIPanelButtonTemplate")
    saveButton:SetWidth(85)
    saveButton:SetHeight(24)
    saveButton:SetPoint("LEFT", resetButton, "RIGHT", 5, 0)
    saveButton:SetText("Guardar")
    saveButton:SetScript("OnClick", function()
        if WCS_BrainDQN and WCS_BrainDQN.Save then
            WCS_BrainDQN:Save()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[DQN]|r Datos |cFF00FF00guardados|r")
        end
    end)
end

-- ============================================================================
-- SECCION: ESTADISTICAS DE ENTRENAMIENTO
-- ============================================================================
function WCS_BrainDQNUI:CreateStatsSection(parent)
    local section = CreateSection(parent, 10, -130, 300, 130, "Entrenamiento")
    
    local yOffset = -22
    local spacing = 18
    
    -- Episodios
    episodesText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    episodesText:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    episodesText:SetText("|cFFAAAAAA Episodios:|r |cFFFFFFFF0|r")
    
    -- Recompensa Total
    yOffset = yOffset - spacing
    rewardText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardText:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    rewardText:SetText("|cFFAAAAAA Recompensa:|r |cFFFFFFFF0.00|r")
    
    -- Epsilon
    yOffset = yOffset - spacing
    epsilonText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epsilonText:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    epsilonText:SetText("|cFFAAAAAA Epsilon:|r |cFFFFFFFF1.00|r |cFF666666(100% exploracion)|r")
    
    -- Loss Promedio
    yOffset = yOffset - spacing
    lossText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lossText:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    lossText:SetText("|cFFAAAAAA Loss Avg:|r |cFFFFFFFF0.0000|r")
    
    -- Q-Value Promedio
    yOffset = yOffset - spacing
    qValueText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qValueText:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    qValueText:SetText("|cFFAAAAAA Q-Value Avg:|r |cFFFFFFFF0.00|r")
    
    -- Replay Buffer
    yOffset = yOffset - spacing
    replayText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    replayText:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    replayText:SetText("|cFFAAAAAA Buffer:|r |cFFFFFFFF0|r / |cFF88888810000|r")
end

-- ============================================================================
-- SECCION: ARQUITECTURA DE RED
-- ============================================================================
function WCS_BrainDQNUI:CreateArchitectureSection(parent)
    local section = CreateSection(parent, 10, -270, 300, 95, "Arquitectura Neural")
    
    local yOffset = -22
    local spacing = 18
    
    -- Capa de Entrada
    archText1 = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    archText1:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    archText1:SetText("|cFF00CCFF Input:|r  |cFFFFFFFF50 neuronas|r")
    
    -- Capa Oculta
    yOffset = yOffset - spacing
    archText2 = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    archText2:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    archText2:SetText("|cFF00FF00 Hidden:|r |cFFFFFFFF128 neuronas|r |cFF888888(ReLU)|r")
    
    -- Capa de Salida
    yOffset = yOffset - spacing
    archText3 = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    archText3:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    archText3:SetText("|cFFFF6600 Output:|r |cFFFFFFFF13 acciones|r")
    
    -- Parametros Totales
    yOffset = yOffset - spacing
    archText4 = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    archText4:SetPoint("TOPLEFT", section, "TOPLEFT", 10, yOffset)
    archText4:SetText("|cFFAAAAAA Params:|r |cFFFFCC000|r")
end

-- ============================================================================
-- SECCION: CONFIGURACION
-- ============================================================================
function WCS_BrainDQNUI:CreateConfigSection(parent)
    local section = CreateSection(parent, 10, -375, 300, 90, "Configuracion")
    
    -- Label del slider
    local epsilonLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epsilonLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -22)
    epsilonLabel:SetText("|cFFAAAAAA Ajustar Epsilon (Exploracion):|r")
    
    -- Slider de Epsilon
    epsilonSlider = CreateFrame("Slider", "WCS_BrainDQNEpsilonSlider", section, "OptionsSliderTemplate")
    epsilonSlider:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -45)
    epsilonSlider:SetWidth(270)
    epsilonSlider:SetHeight(17)
    epsilonSlider:SetMinMaxValues(0, 1)
    epsilonSlider:SetValue(1)
    epsilonSlider:SetValueStep(0.01)
    
    getglobal(epsilonSlider:GetName().."Low"):SetText("|cFF00FF000.0|r")
    getglobal(epsilonSlider:GetName().."High"):SetText("|cFFFF00001.0|r")
    getglobal(epsilonSlider:GetName().."Text"):SetText("|cFFFFCC00Epsilon: 1.00|r")
    
    epsilonSlider:SetScript("OnValueChanged", function()
        local value = this:GetValue()
        getglobal(this:GetName().."Text"):SetText("|cFFFFCC00Epsilon: " .. string.format("%.2f", value) .. "|r")
        if WCS_BrainDQN and WCS_BrainDQN.Config then
            WCS_BrainDQN.Config.epsilon = value
        end
    end)
end

-- ============================================================================
-- ACTUALIZACION DE UI
-- ============================================================================
function WCS_BrainDQNUI:UpdateUI()
    if not mainFrame or not mainFrame:IsVisible() then
        return
    end
    
    if not WCS_BrainDQN then
        return
    end
    
    -- === ESTADO ===
    if statusText then
        if WCS_BrainDQN.enabled then
            statusText:SetText("|cFF00FF00ACTIVO|r")
            if statusSection then
                statusSection:SetBackdropColor(0.0, 0.15, 0.05, 0.95)
            end
            if toggleButton then
                toggleButton:SetText("Desactivar")
            end
        else
            statusText:SetText("|cFFFF0000INACTIVO|r")
            if statusSection then
                statusSection:SetBackdropColor(COLORS.BG_SECTION[1], COLORS.BG_SECTION[2], COLORS.BG_SECTION[3], 0.95)
            end
            if toggleButton then
                toggleButton:SetText("Activar")
            end
        end
    end
    
    -- === ESTADISTICAS ===
    if WCS_BrainDQN.Stats then
        local stats = WCS_BrainDQN.Stats
        
        if episodesText then
            local eps = stats.episodes or 0
            local color = eps > 0 and "00FF00" or "FFFFFF"
            episodesText:SetText("|cFFAAAAAA Episodios:|r |cFF" .. color .. eps .. "|r")
        end
        
        if rewardText then
            local reward = stats.totalReward or 0
            local color = reward > 0 and "00FF00" or (reward < 0 and "FF0000" or "FFFFFF")
            rewardText:SetText("|cFFAAAAAA Recompensa:|r |cFF" .. color .. string.format("%.2f", reward) .. "|r")
        end
        
        if lossText then
            lossText:SetText("|cFFAAAAAA Loss Avg:|r |cFFFFFFFF" .. string.format("%.4f", stats.avgLoss or 0) .. "|r")
        end
        
        if qValueText then
            qValueText:SetText("|cFFAAAAAA Q-Value Avg:|r |cFFFFFFFF" .. string.format("%.2f", stats.avgQValue or 0) .. "|r")
        end
    end
    
    -- === EPSILON ===
    if WCS_BrainDQN.Config then
        local epsilon = WCS_BrainDQN.Config.epsilon or 1
        local explorePercent = math.floor(epsilon * 100)
        local exploitPercent = 100 - explorePercent
        
        if epsilonText then
            local color = epsilon > 0.5 and "FFAA00" or "00FF00"
            epsilonText:SetText("|cFFAAAAAA Epsilon:|r |cFF" .. color .. string.format("%.2f", epsilon) .. "|r |cFF666666(" .. explorePercent .. "% explora)|r")
        end
        
        if epsilonSlider and not epsilonSlider.dragging then
            epsilonSlider:SetValue(epsilon)
        end
    end
    
    -- === REPLAY BUFFER ===
    if WCS_BrainDQN.ReplayBuffer and replayText then
        local size = WCS_BrainDQN.ReplayBuffer.size or 0
        local maxSize = WCS_BrainDQN.Config.bufferSize or 10000
        local pct = (size / maxSize) * 100
        local color = pct > 10 and "00FF00" or "FFAA00"
        replayText:SetText("|cFFAAAAAA Buffer:|r |cFF" .. color .. size .. "|r / |cFF888888" .. maxSize .. "|r")
    end
    
    -- === ARQUITECTURA ===
    if WCS_BrainDQN.Config then
        local cfg = WCS_BrainDQN.Config
        local stateSize = cfg.stateSize or 50
        local hiddenSize = cfg.hiddenSize or 128
        local actionSize = cfg.actionSize or (WCS_BrainDQN and WCS_BrainDQN.Config and WCS_BrainDQN.Config.actionSize) or 30
        
        if archText1 then
            archText1:SetText("|cFF00CCFF Input:|r  |cFFFFFFFF" .. stateSize .. " neuronas|r")
        end
        if archText2 then
            archText2:SetText("|cFF00FF00 Hidden:|r |cFFFFFFFF" .. hiddenSize .. " neuronas|r |cFF888888(ReLU)|r")
        end
        if archText3 then
            archText3:SetText("|cFFFF6600 Output:|r |cFFFFFFFF" .. actionSize .. " acciones|r")
        end
        if archText4 then
            local paramsIH = stateSize * hiddenSize + hiddenSize
            local paramsHO = hiddenSize * actionSize + actionSize
            local totalParams = paramsIH + paramsHO
            archText4:SetText("|cFFAAAAAA Params:|r |cFFFFCC00" .. totalParams .. "|r |cFF666666(" .. paramsIH .. " + " .. paramsHO .. ")|r")
        end
    end
end

-- ============================================================================
-- TOGGLE Y SHOW
-- ============================================================================
function WCS_BrainDQNUI:Toggle()
    if WCS_BrainUI and WCS_BrainUI.MainFrame and WCS_BrainUI.MainFrame:IsVisible() and WCS_BrainUI.tabDataList and WCS_BrainUI.MainFrame.currentTab then
        if WCS_BrainUI.tabDataList[WCS_BrainUI.MainFrame.currentTab].name == "DQN" then
            WCS_BrainUI:Toggle()
            return
        end
    end
    
    if mainFrame and mainFrame:IsVisible() and (not WCS_BrainUI or not WCS_BrainUI.MainFrame or not WCS_BrainUI.MainFrame:IsVisible()) then
        self:Hide()
    else
        self:Show()
    end
end

function WCS_BrainDQNUI:Show()
    if WCS_BrainUI and WCS_BrainUI.SelectTabByName then
        WCS_BrainUI:SelectTabByName("DQN")
        if not mainFrame then self:CreateMainFrame() end
        self:UpdateUI()
    else
        if not mainFrame then
            self:CreateMainFrame()
        end
        mainFrame:Show()
        self:UpdateUI()
    end
end

function WCS_BrainDQNUI:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_DQNUI1 = "/dqnui"
SLASH_DQNUI2 = "/braindqnui"
SlashCmdList["DQNUI"] = function()
    WCS_BrainDQNUI:Toggle()
end

-- Mensaje de carga
DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS_BrainDQNUI]|r v" .. WCS_BrainDQNUI.VERSION .. " cargado. Usa |cFFFFCC00/dqnui|r para abrir.")