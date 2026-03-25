-- WCS_BrainThinkingUI.lua
-- UI que muestra el "pensamiento" del Brain en tiempo real
-- Version: 6.5.0
-- Author: Elnazzareno (DarckRovert)

WCS_BrainThinkingUI = {
    VERSION = "6.5.0",
    
    -- Configuracion
    Config = {
        width = 400,
        height = 300,
        updateInterval = 0.5, -- segundos
        maxThoughts = 10,
        showDPS = true,
        showTTK = true,
        showDebate = true,
    },
    
    -- Estado
    frame = nil,
    isShowing = false,
    lastUpdate = 0,
    thoughts = {},
    dpsHistory = {},
}

local TUI = WCS_BrainThinkingUI

-- Inicializar
function TUI:Initialize()
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ThinkingUI", "Inicializando UI de pensamiento v" .. self.VERSION)
    end
    
    -- Cargar saved variables
    if not WCS_BrainThinkingUISaved then
        WCS_BrainThinkingUISaved = {
            position = { x = 0, y = 0 },
            isShowing = false,
        }
    end
    
    self.Data = WCS_BrainThinkingUISaved
    
    -- Registrar comandos
    self:RegisterCommands()
    
    -- Mostrar si estaba visible
    if self.Data.isShowing then
        self:Show()
    end
end

-- Crear frame
function TUI:CreateFrame()
    if self.frame then return end
    
    local frame = CreateFrame("Frame", "WCS_BrainThinkingUIFrame", UIParent)
    frame:SetWidth(self.Config.width)
    frame:SetHeight(self.Config.height)
    frame:SetPoint("CENTER", self.Data.position.x, self.Data.position.y)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        TUI.Data.position.x = x - GetScreenWidth() / 2
        TUI.Data.position.y = y - GetScreenHeight() / 2
    end)
    
    -- Titulo
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cFF9482C9WCS Brain|r |cFF00FF00Thinking|r")
    frame.title = title
    
    -- Boton cerrar
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        TUI:Hide()
    end)
    
    -- Scroll frame para pensamientos
    local scrollFrame = CreateFrame("ScrollFrame", "WCS_BrainThinkingScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 100)
    
    -- Crear slider para scroll
    local scrollBar = CreateFrame("Slider", "WCS_BrainThinkingScrollBar", scrollFrame)
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -4, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -4, 16)
    scrollBar:SetWidth(16)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 100)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 3, right = 3, top = 6, bottom = 6}
    })
    scrollBar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)
    scrollFrame.scrollBar = scrollBar
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(self.Config.width - 60)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    
    -- Area de pensamientos
    local thoughtsText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    thoughtsText:SetPoint("TOPLEFT", 5, -5)
    thoughtsText:SetWidth(self.Config.width - 70)
    thoughtsText:SetJustifyH("LEFT")
    thoughtsText:SetText("")
    frame.thoughtsText = thoughtsText
    
    -- DPS actual
    local dpsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dpsLabel:SetPoint("BOTTOMLEFT", 20, 70)
    dpsLabel:SetText("DPS:")
    
    local dpsValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dpsValue:SetPoint("LEFT", dpsLabel, "RIGHT", 5, 0)
    dpsValue:SetText("|cFF00FF000|r")
    frame.dpsValue = dpsValue
    
    -- TTK (Time To Kill)
    local ttkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ttkLabel:SetPoint("BOTTOMLEFT", 20, 50)
    ttkLabel:SetText("TTK:")
    
    local ttkValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ttkValue:SetPoint("LEFT", ttkLabel, "RIGHT", 5, 0)
    ttkValue:SetText("|cFFFFFF00--")
    frame.ttkValue = ttkValue
    
    -- Estado del Brain
    local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("BOTTOMLEFT", 20, 30)
    statusLabel:SetText("Estado:")
    
    local statusValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusValue:SetPoint("LEFT", statusLabel, "RIGHT", 5, 0)
    statusValue:SetText("|cFF00FF00Idle|r")
    frame.statusValue = statusValue
    
    -- Boton de opciones
    local optionsButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    optionsButton:SetWidth(80)
    optionsButton:SetHeight(25)
    optionsButton:SetPoint("BOTTOMRIGHT", -20, 10)
    optionsButton:SetText("Opciones")
    optionsButton:SetScript("OnClick", function()
        TUI:ShowOptions()
    end)
    
    -- Update loop
    frame:SetScript("OnUpdate", function()
        TUI:OnUpdate()
    end)
    
    self.frame = frame
    frame:Hide()
end

-- Mostrar
function TUI:Show()
    if not self.frame then
        self:CreateFrame()
    end
    self.frame:Show()
    self.isShowing = true
    self.Data.isShowing = true
end

-- Ocultar
function TUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.isShowing = false
    self.Data.isShowing = false
end

-- Toggle
function TUI:Toggle()
    if self.isShowing then
        self:Hide()
    else
        self:Show()
    end
end

-- Update
function TUI:OnUpdate()
    local now = GetTime()
    if now - self.lastUpdate < self.Config.updateInterval then
        return
    end
    self.lastUpdate = now
    
    -- Actualizar DPS
    if self.Config.showDPS then
        self:UpdateDPS()
    end
    
    -- Actualizar TTK
    if self.Config.showTTK then
        self:UpdateTTK()
    end
    
    -- Actualizar estado
    self:UpdateStatus()
    
    -- Actualizar pensamientos
    if self.Config.showDebate then
        self:UpdateThoughts()
    end
end

-- Actualizar DPS
function TUI:UpdateDPS()
    if not WCS_BrainMetrics or not WCS_BrainMetrics.Data then
        self.frame.dpsValue:SetText("|cFFFF00000|r")
        return
    end
    
    local dps = 0
    
    -- Calcular DPS del combate actual
    if WCS_BrainMetrics.Data.currentCombat then
        local combat = WCS_BrainMetrics.Data.currentCombat
        if combat.startTime and combat.totalDamage then
            local duration = GetTime() - combat.startTime
            if duration > 0 then
                dps = combat.totalDamage / duration
            end
        end
    end
    
    -- Color segun DPS
    local color = "|cFF00FF00"
    if dps < 50 then
        color = "|cFFFF0000"
    elseif dps < 100 then
        color = "|cFFFFFF00"
    end
    
    self.frame.dpsValue:SetText(color .. string.format("%.1f", dps) .. "|r")
end

-- Actualizar TTK
function TUI:UpdateTTK()
    if not UnitExists("target") or UnitIsDead("target") then
        self.frame.ttkValue:SetText("|cFFFFFF00--")
        return
    end
    
    local targetHP = UnitHealth("target")
    local targetMaxHP = UnitHealthMax("target")
    
    -- Obtener DPS actual
    local dps = 0
    if WCS_BrainMetrics and WCS_BrainMetrics.Data and WCS_BrainMetrics.Data.currentCombat then
        local combat = WCS_BrainMetrics.Data.currentCombat
        if combat.startTime and combat.totalDamage then
            local duration = GetTime() - combat.startTime
            if duration > 0 then
                dps = combat.totalDamage / duration
            end
        end
    end
    
    if dps > 0 then
        local ttk = targetHP / dps
        local color = "|cFF00FF00"
        if ttk > 30 then
            color = "|cFFFF0000"
        elseif ttk > 15 then
            color = "|cFFFFFF00"
        end
        self.frame.ttkValue:SetText(color .. string.format("%.1fs", ttk) .. "|r")
    else
        self.frame.ttkValue:SetText("|cFFFFFF00--")
    end
end

-- Actualizar estado
function TUI:UpdateStatus()
    local status = "Idle"
    local color = "|cFFFFFF00"
    
    if UnitAffectingCombat("player") then
        status = "In Combat"
        color = "|cFFFF0000"
    elseif UnitExists("target") and not UnitIsDead("target") then
        status = "Target Acquired"
        color = "|cFF00FF00"
    end
    
    -- Agregar modo activo
    if WCS_Brain and WCS_Brain.Config then
        if WCS_Brain.Config.useDQN then
            status = status .. " (DQN)"
        elseif WCS_BrainSmartAI and WCS_BrainSmartAI.Config and WCS_BrainSmartAI.Config.enabled then
            status = status .. " (SmartAI)"
        end
    end
    
    self.frame.statusValue:SetText(color .. status .. "|r")
end

-- Actualizar pensamientos
function TUI:UpdateThoughts()
    -- Obtener pensamientos recientes
    local thoughts = self:GetRecentThoughts()
    
    -- Construir texto
    local text = ""
    for i = 1, table.getn(thoughts) do
        local thought = thoughts[i]
        text = text .. "|cFF888888[" .. thought.time .. "]|r "
        text = text .. thought.source .. ": "
        text = text .. thought.text .. "\n\n"
    end
    
    if text == "" then
        text = "|cFF888888No hay pensamientos recientes...|r"
    end
    
    self.frame.thoughtsText:SetText(text)
    
    -- Ajustar altura del scroll child
    local height = self.frame.thoughtsText:GetHeight() + 20
    self.frame.scrollChild:SetHeight(height)
end

-- Obtener pensamientos recientes
function TUI:GetRecentThoughts()
    -- Por ahora, generar pensamientos simulados
    -- En el futuro, estos vendran de WCS_Brain, SmartAI, DQN, etc.
    
    local thoughts = {}
    
    -- Pensamiento de SmartAI
    if WCS_BrainSmartAI and UnitAffectingCombat("player") then
        table.insert(thoughts, {
            time = date("%H:%M:%S"),
            source = "|cFF00FF00SmartAI|r",
            text = "Analizando objetivo... HP: " .. (UnitExists("target") and UnitHealth("target") or "N/A"),
        })
    end
    
    -- Pensamiento de DQN
    if WCS_Brain and WCS_Brain.Config.useDQN then
        table.insert(thoughts, {
            time = date("%H:%M:%S"),
            source = "|cFF9482C9DQN|r",
            text = "Calculando mejor accion basada en Q-values...",
        })
    end
    
    -- Pensamiento de PetAI
    if WCS_BrainPetAI and UnitExists("pet") then
        table.insert(thoughts, {
            time = date("%H:%M:%S"),
            source = "|cFFFF00FFPetAI|r",
            text = "Mascota en modo: " .. (WCS_BrainPetAI.currentMode or "Unknown"),
        })
    end
    
    return thoughts
end

-- Agregar pensamiento
function TUI:AddThought(source, text)
    table.insert(self.thoughts, {
        time = date("%H:%M:%S"),
        source = source,
        text = text,
        timestamp = GetTime(),
    })
    
    -- Mantener solo los ultimos N pensamientos
    while table.getn(self.thoughts) > self.Config.maxThoughts do
        table.remove(self.thoughts, 1)
    end
end

-- Mostrar opciones
function TUI:ShowOptions()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain Thinking UI]|r Opciones:")
    DEFAULT_CHAT_FRAME:AddMessage("DPS: " .. (self.Config.showDPS and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("TTK: " .. (self.Config.showTTK and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
    DEFAULT_CHAT_FRAME:AddMessage("Debate: " .. (self.Config.showDebate and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
end

-- Registrar comandos
function TUI:RegisterCommands()
    SLASH_BRAINTHINKINGUI1 = "/brainthinking"
    SLASH_BRAINTHINKINGUI2 = "/bthink"
    SlashCmdList["BRAINTHINKINGUI"] = function(msg)
        TUI:HandleCommand(msg)
    end
end

function TUI:HandleCommand(msg)
    local args = {}
    for word in string.gfind(msg, "%S+") do
        table.insert(args, word)
    end
    
    local cmd = args[1] or "toggle"
    
    if cmd == "show" then
        self:Show()
    elseif cmd == "hide" then
        self:Hide()
    elseif cmd == "toggle" then
        self:Toggle()
    elseif cmd == "dps" then
        self.Config.showDPS = not self.Config.showDPS
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r DPS: " .. (self.Config.showDPS and "ON" or "OFF"))
    elseif cmd == "ttk" then
        self.Config.showTTK = not self.Config.showTTK
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r TTK: " .. (self.Config.showTTK and "ON" or "OFF"))
    elseif cmd == "debate" then
        self.Config.showDebate = not self.Config.showDebate
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Debate: " .. (self.Config.showDebate and "ON" or "OFF"))
    else
        self:ShowHelp()
    end
end

function TUI:ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== Brain Thinking UI - Comandos ===")
    DEFAULT_CHAT_FRAME:AddMessage("/brainthinking show - Mostrar ventana")
    DEFAULT_CHAT_FRAME:AddMessage("/brainthinking hide - Ocultar ventana")
    DEFAULT_CHAT_FRAME:AddMessage("/brainthinking toggle - Alternar ventana")
    DEFAULT_CHAT_FRAME:AddMessage("/brainthinking dps - Toggle DPS")
    DEFAULT_CHAT_FRAME:AddMessage("/brainthinking ttk - Toggle TTK")
    DEFAULT_CHAT_FRAME:AddMessage("/brainthinking debate - Toggle debate")
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        TUI:Initialize()
    end
end)

