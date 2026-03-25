--[[
    WCS_BrainButton.lua - Boton Flotante para Cerebro Central
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Estilo visual mejorado con luz indicadora y pulso
]]--

WCS_BrainButton = WCS_BrainButton or {}
WCS_BrainButton.VERSION = "6.4.2"

-- Variables locales
local button = nil
local pulseTimer = 0
local PULSE_SPEED = 2

-- Colores Warlock
local COLOR_PURPLE = {r=0.58, g=0.51, b=0.79}
local COLOR_FEL = {r=0, g=1, b=0.5}
local COLOR_GREEN = {r=0, g=1, b=0}
local COLOR_RED = {r=1, g=0, b=0}
local COLOR_ORANGE = {r=1, g=0.5, b=0}
local COLOR_CYAN = {r=0, g=0.8, b=1}

-- ============================================================================
-- CREAR BOTON FLOTANTE
-- ============================================================================
function WCS_BrainButton:Create()
    if button then return button end
    
    -- Frame principal
    button = CreateFrame("Button", "WCSBrainFloatingButton", UIParent)
    button:SetWidth(64)
    button:SetHeight(64)
    button:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    button:SetFrameStrata("HIGH")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("RightButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Textura de fondo (icono de cerebro/warlock)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetTexture("Interface\\Icons\\Spell_Shadow_Possession")
    button.bg = bg
    
    -- Borde brillante con efecto de pulso
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(72)
    border:SetHeight(72)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.8)
    button.border = border
    
    -- Luz indicadora (esquina superior derecha)
    local light = button:CreateTexture(nil, "OVERLAY")
    light:SetWidth(14)
    light:SetHeight(14)
    light:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    light:SetTexture("Interface\\COMMON\\Indicator-Green")
    button.light = light
    
    -- Texto de estado debajo
    local statusText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOP", button, "BOTTOM", 0, -2)
    statusText:SetText("BRAIN")
    statusText:SetTextColor(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    button.statusText = statusText
    
    -- Texto de fase (debajo del nombre)
    local phaseText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    phaseText:SetPoint("TOP", statusText, "BOTTOM", 0, -1)
    phaseText:SetText("IDLE")
    phaseText:SetTextColor(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b)
    button.phaseText = phaseText
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cFF9482C9WCS Brain|r |cFF00FF80v" .. WCS_BrainButton.VERSION .. "|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFFFFFClick Izquierdo:|r Abrir UI", 1, 1, 1)
        GameTooltip:AddLine("|cFFFFFFFFClick Derecho:|r Ejecutar hechizo", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Arrastrar: Mover boton|r", 0.5, 0.5, 0.5)
        GameTooltip:AddLine(" ")
        if WCS_Brain then
            local estado = WCS_Brain.ENABLED and "|cFF00FF00ACTIVO|r" or "|cFFFF0000INACTIVO|r"
            GameTooltip:AddLine("Estado: " .. estado)
            GameTooltip:AddLine("Fase: |cFFFFFF00" .. string.upper(WCS_Brain.Context.phase or "idle") .. "|r")
            if WCS_Brain.Context.lastDecision then
                GameTooltip:AddLine("Siguiente: |cFF00FFFF" .. (WCS_Brain.Context.lastDecision.spell or "?") .. "|r")
            end
        end
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click handlers
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            if WCS_BrainUI then
                WCS_BrainUI:Toggle()
            end
        elseif arg1 == "RightButton" then
            if WCS_Brain then
                WCS_Brain:Execute()
            end
        end
    end)
    
    -- Drag handlers
    button:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        WCS_BrainButton:SavePosition()
    end)
    
    -- OnUpdate para animacion de pulso con throttling
    button.elapsed = 0
    button:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        -- Throttling: actualizar solo cada 0.05s (20 FPS)
        if this.elapsed < 0.05 then return end
        this.elapsed = 0
        
        pulseTimer = pulseTimer + this.elapsed
        WCS_BrainButton:UpdateVisuals()
    end)
    
    self.Button = button
    
    -- Cargar posicion guardada
    self:LoadPosition()
    
    return button
end

-- ============================================================================
-- ACTUALIZAR VISUALES (pulso y colores)
-- ============================================================================
function WCS_BrainButton:UpdateVisuals()
    if not button then return end
    
    local isActive = WCS_Brain and WCS_Brain.ENABLED
    local phase = WCS_Brain and WCS_Brain.Context and WCS_Brain.Context.phase or "idle"
    
    -- Determinar color segun estado
    local color = COLOR_PURPLE
    local phaseColor = COLOR_CYAN
    
    if not isActive then
        -- Inactivo - gris/apagado
        color = {r=0.4, g=0.4, b=0.4}
        phaseColor = COLOR_RED
        button.light:SetTexture("Interface\\COMMON\\Indicator-Red")
    elseif phase == "emergency" then
        color = COLOR_RED
        phaseColor = COLOR_RED
        button.light:SetTexture("Interface\\COMMON\\Indicator-Red")
    elseif phase == "execute" then
        color = COLOR_ORANGE
        phaseColor = COLOR_ORANGE
        button.light:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    elseif phase == "sustain" then
        color = COLOR_FEL
        phaseColor = COLOR_GREEN
        button.light:SetTexture("Interface\\COMMON\\Indicator-Green")
    else
        -- idle
        color = COLOR_PURPLE
        phaseColor = COLOR_CYAN
        button.light:SetTexture("Interface\\COMMON\\Indicator-Gray")
    end
    
    -- Animacion de pulso cuando esta activo
    if isActive then
        local alpha = 0.5 + 0.5 * math.sin(pulseTimer * PULSE_SPEED)
        button.border:SetAlpha(alpha)
        button.border:SetVertexColor(color.r, color.g, color.b, alpha)
        button.light:SetAlpha(0.7 + 0.3 * math.sin(pulseTimer * PULSE_SPEED * 2))
    else
        button.border:SetAlpha(0.3)
        button.border:SetVertexColor(color.r, color.g, color.b, 0.3)
        button.light:SetAlpha(0.5)
    end
    
    -- Actualizar texto de estado
    button.statusText:SetTextColor(color.r, color.g, color.b)
    button.phaseText:SetText(string.upper(phase))
    button.phaseText:SetTextColor(phaseColor.r, phaseColor.g, phaseColor.b)
end

-- ============================================================================
-- GUARDAR/CARGAR POSICION
-- ============================================================================
function WCS_BrainButton:SavePosition()
    if not button then return end
    
    local point, _, relPoint, x, y = button:GetPoint()
    
    if not WCS_BrainCharSaved then
        WCS_BrainCharSaved = {}
    end
    
    WCS_BrainCharSaved.buttonPos = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y
    }
end

function WCS_BrainButton:LoadPosition()
    if not button then return end
    if not WCS_BrainCharSaved or not WCS_BrainCharSaved.buttonPos then return end
    
    local pos = WCS_BrainCharSaved.buttonPos
    button:ClearAllPoints()
    button:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
end

-- ============================================================================
-- TOGGLE VISIBILIDAD
-- ============================================================================
function WCS_BrainButton:Toggle()
    if not button then
        self:Create()
    end
    
    if button:IsVisible() then
        button:Hide()
    else
        button:Show()
    end
end

function WCS_BrainButton:Show()
    if not button then
        self:Create()
    end
    button:Show()
end

function WCS_BrainButton:Hide()
    if button then
        button:Hide()
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSBUTTON1 = "/brainbtn"
SlashCmdList["WCSBUTTON"] = function(msg)
    WCS_BrainButton:Toggle()
end

-- ============================================================================
-- AUTO-CREAR AL CARGAR
-- ============================================================================
WCS_BrainButton:Create()
