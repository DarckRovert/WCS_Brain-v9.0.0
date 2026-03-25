--[[
    WCS_BrainTutorialUI.lua - Interfaz Gráfica del Tutorial v6.5.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Ventana visual para el tutorial interactivo
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainTutorialUI = WCS_BrainTutorialUI or {}
WCS_BrainTutorialUI.frame = nil
WCS_BrainTutorialUI.isShowing = false

-- ============================================================================
-- CREAR VENTANA
-- ============================================================================
function WCS_BrainTutorialUI:CreateFrame()
    if self.frame then return end
    
    -- Frame principal
    local frame = CreateFrame("Frame", "WCS_TutorialFrame", UIParent)
    frame:SetWidth(450)
    frame:SetHeight(300)
    frame:SetPoint("CENTER", 0, 100)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    
    -- Título
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cFF9482C9WCS Brain|r |cFF00FF00Tutorial|r")
    frame.title = title
    
    -- Número de paso
    local stepNumber = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stepNumber:SetPoint("TOP", 0, -45)
    stepNumber:SetTextColor(1, 0.82, 0)
    frame.stepNumber = stepNumber
    
    -- Título del paso
    local stepTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stepTitle:SetPoint("TOP", 0, -70)
    stepTitle:SetTextColor(0.58, 0.51, 0.79)
    frame.stepTitle = stepTitle
    
    -- Descripción
    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOP", 0, -100)
    description:SetWidth(400)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    frame.description = description
    
    -- Botón Anterior
    local prevButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    prevButton:SetWidth(100)
    prevButton:SetHeight(30)
    prevButton:SetPoint("BOTTOMLEFT", 20, 20)
    prevButton:SetText("< Anterior")
    prevButton:SetScript("OnClick", function()
        if WCS_BrainTutorial then
            WCS_BrainTutorial:PreviousStep()
        end
    end)
    frame.prevButton = prevButton
    
    -- Botón Siguiente
    local nextButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    nextButton:SetWidth(100)
    nextButton:SetHeight(30)
    nextButton:SetPoint("BOTTOM", 0, 20)
    nextButton:SetText("Siguiente >")
    nextButton:SetScript("OnClick", function()
        if WCS_BrainTutorial then
            WCS_BrainTutorial:Next()
        end
    end)
    frame.nextButton = nextButton
    
    -- Botón Cerrar
    local closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    closeButton:SetWidth(100)
    closeButton:SetHeight(30)
    closeButton:SetPoint("BOTTOMRIGHT", -20, 20)
    closeButton:SetText("Cerrar")
    closeButton:SetScript("OnClick", function()
        WCS_BrainTutorialUI:Hide()
    end)
    frame.closeButton = closeButton
    
    -- Botón X (esquina superior derecha)
    local xButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    xButton:SetPoint("TOPRIGHT", -5, -5)
    xButton:SetScript("OnClick", function()
        WCS_BrainTutorialUI:Hide()
    end)
    
    -- Barra de progreso
    local progressBar = CreateFrame("StatusBar", nil, frame)
    progressBar:SetWidth(400)
    progressBar:SetHeight(20)
    progressBar:SetPoint("BOTTOM", 0, 60)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetStatusBarColor(0.58, 0.51, 0.79)
    progressBar:SetMinMaxValues(0, 11)
    progressBar:SetValue(0)
    
    -- Fondo de la barra
    local progressBg = progressBar:CreateTexture(nil, "BACKGROUND")
    progressBg:SetAllPoints(progressBar)
    progressBg:SetTexture(0, 0, 0, 0.5)
    
    -- Texto de la barra
    local progressText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("CENTER", progressBar, "CENTER", 0, 0)
    progressBar.text = progressText
    
    frame.progressBar = progressBar
    
    self.frame = frame
end

-- ============================================================================
-- MOSTRAR/OCULTAR
-- ============================================================================
function WCS_BrainTutorialUI:Show()
    if not self.frame then
        self:CreateFrame()
    end
    self.frame:Show()
    self.isShowing = true
end

function WCS_BrainTutorialUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.isShowing = false
end

function WCS_BrainTutorialUI:Toggle()
    if self.isShowing then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- ACTUALIZAR CONTENIDO
-- ============================================================================
function WCS_BrainTutorialUI:UpdateStep(stepNumber, stepData)
    if not self.frame then
        self:CreateFrame()
    end
    
    -- Actualizar textos
    self.frame.stepNumber:SetText("Paso " .. stepNumber .. " de 11")
    self.frame.stepTitle:SetText(stepData.title or "")
    self.frame.description:SetText(stepData.text or "")
    
    -- Actualizar barra de progreso
    self.frame.progressBar:SetValue(stepNumber)
    self.frame.progressBar.text:SetText(stepNumber .. "/11")
    
    -- Habilitar/deshabilitar botones
    if stepNumber <= 1 then
        self.frame.prevButton:Disable()
    else
        self.frame.prevButton:Enable()
    end
    
    if stepNumber >= 11 then
        self.frame.nextButton:SetText("Finalizar")
    else
        self.frame.nextButton:SetText("Siguiente >")
    end
    
    -- Mostrar si está oculto
    if not self.isShowing then
        self:Show()
    end
end

-- ============================================================================
-- INTEGRACIÓN CON WCS_BrainTutorial
-- ============================================================================
if WCS_BrainTutorial then
    -- Sobrescribir la función ShowStep para usar la UI
    local originalShowStep = WCS_BrainTutorial.ShowStep
    
    WCS_BrainTutorial.ShowStep = function(self)
        -- Llamar a la función original (muestra en chat)
        originalShowStep(self)
        
        -- Mostrar en la UI gráfica
        local step = self.Steps[self.currentStep]
        if step then
            WCS_BrainTutorialUI:UpdateStep(self.currentStep, step)
        end
    end
    
    -- Agregar función para ir al paso anterior
    WCS_BrainTutorial.PreviousStep = function(self)
        if self.currentStep > 1 then
            self.currentStep = self.currentStep - 1
            self:ShowStep()
        end
    end
end

-- ============================================================================
-- COMANDO SLASH
-- ============================================================================
SLASH_WCSTUTORIALUI1 = "/tutorialui"
SlashCmdList["WCSTUTORIALUI"] = function(msg)
    if msg == "show" then
        WCS_BrainTutorialUI:Show()
    elseif msg == "hide" then
        WCS_BrainTutorialUI:Hide()
    else
        WCS_BrainTutorialUI:Toggle()
    end
end

-- ============================================================================
-- AUTO-INICIALIZACIÓN
-- ============================================================================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainTutorialUI:CreateFrame()
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("TutorialUI", "Interfaz gráfica del tutorial inicializada")
        end
    end
end)
