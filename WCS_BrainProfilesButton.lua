--[[
    WCS_BrainProfilesButton.lua - Boton Flotante para Gestor de Perfiles
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
]]--

WCS_BrainProfilesButton = WCS_BrainProfilesButton or {}
WCS_BrainProfilesButton.VERSION = "6.4.2"

-- Variables locales
local button = nil
local pulseTimer = 0
local PULSE_SPEED = 2

-- Colores
local COLOR_GOLD = {r=1, g=0.82, b=0}
local COLOR_GREEN = {r=0, g=1, b=0}
local COLOR_WHITE = {r=1, g=1, b=1}

-- Configuracion por defecto
local defaultConfig = {
    point = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    xOffset = 200,
    yOffset = 0,
    visible = true
}

-- Funcion para obtener configuracion
local function GetConfig()
    if not WCS_BrainSaved then
        WCS_BrainSaved = {}
    end
    if not WCS_BrainSaved.profilesButtonPos then
        WCS_BrainSaved.profilesButtonPos = {}
        for k, v in pairs(defaultConfig) do
            WCS_BrainSaved.profilesButtonPos[k] = v
        end
    end
    return WCS_BrainSaved.profilesButtonPos
end

-- Funcion para guardar posicion
local function SavePosition()
    if not button then return end
    
    local config = GetConfig()
    local point, relativeTo, relativePoint, xOffset, yOffset = button:GetPoint()
    
    config.point = point or "CENTER"
    config.relativeTo = "UIParent"
    config.relativePoint = relativePoint or "CENTER"
    config.xOffset = xOffset or 0
    config.yOffset = yOffset or 0
end

-- ============================================================================
-- CREAR BOTON FLOTANTE
-- ============================================================================
function WCS_BrainProfilesButton:Create()
    if button then return button end
    
    -- Frame principal
    button = CreateFrame("Button", "WCSBrainProfilesFloatingButton", UIParent)
    button:SetWidth(64)
    button:SetHeight(64)
    button:SetFrameStrata("HIGH")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("RightButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Restaurar posicion guardada
    local config = GetConfig()
    button:ClearAllPoints()
    button:SetPoint(
        config.point,
        config.relativeTo,
        config.relativePoint,
        config.xOffset,
        config.yOffset
    )
    
    -- Textura de fondo (icono de libro)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    button.bg = bg
    
    -- Borde brillante
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(72)
    border:SetHeight(72)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.8)
    button.border = border
    
    -- Texto de estado debajo
    local statusText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOP", button, "BOTTOM", 0, -2)
    statusText:SetText("PERFILES")
    statusText:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
    button.statusText = statusText
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cFFFFD700WCS Brain - Perfiles|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFFFFFClick:|r Abrir gestor de perfiles", 1, 1, 1)
        GameTooltip:AddLine("|cFFFFFFFFShift+Click:|r Menu rapido", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Click Derecho: Mover boton|r", 0.5, 0.5, 0.5)
        GameTooltip:AddLine(" ")
        
        -- Mostrar perfil actual
        if WCS_BrainProfiles then
            local currentProfile = WCS_BrainProfiles.GetCurrentProfileName()
            if currentProfile then
                GameTooltip:AddLine("Perfil actual: |cFF00FF00" .. currentProfile .. "|r")
            else
                GameTooltip:AddLine("Perfil actual: |cFF888888Ninguno|r")
            end
        end
        
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click izquierdo: Abrir UI o menu rapido
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            if IsShiftKeyDown() then
                -- Shift+Click: Menu rapido
                WCS_BrainProfilesButton:ShowQuickMenu()
            else
                -- Click normal: Abrir UI
                if WCS_BrainProfilesUI then
                    WCS_BrainProfilesUI:Toggle()
                end
            end
        end
    end)
    
    -- Arrastre
    button:SetScript("OnDragStart", function()
        if arg1 == "RightButton" then
            this:StartMoving()
        end
    end)
    
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        SavePosition()
    end)
    
    -- Efecto de pulso
    button:SetScript("OnUpdate", function()
        pulseTimer = pulseTimer + arg1
        if pulseTimer >= PULSE_SPEED then
            pulseTimer = 0
        end
        
        local alpha = 0.5 + (math.sin(pulseTimer * math.pi / PULSE_SPEED) * 0.3)
        button.border:SetAlpha(alpha)
    end)
    
    -- Mostrar/ocultar segun configuracion
    if config.visible then
        button:Show()
    else
        button:Hide()
    end
    
    return button
end

-- ============================================================================
-- MENU RAPIDO (Shift+Click)
-- ============================================================================
function WCS_BrainProfilesButton:ShowQuickMenu()
    if not WCS_BrainProfiles then return end
    
    -- Crear menu contextual
    local menu = CreateFrame("Frame", "WCSBrainProfilesQuickMenu", UIParent)
    menu:SetWidth(200)
    menu:SetFrameStrata("DIALOG")
    menu:SetPoint("LEFT", button, "RIGHT", 5, 0)
    
    -- Backdrop
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    menu:SetBackdropColor(0, 0, 0, 0.9)
    
    -- Titulo
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", menu, "TOP", 0, -15)
    title:SetText("|cFFFFD700Cargar Perfil|r")
    
    -- Obtener lista de perfiles
    local profiles = WCS_BrainProfiles.GetProfileList()
    local currentProfile = WCS_BrainProfiles.GetCurrentProfileName()
    
    local yOffset = -40
    local buttonHeight = 25
    local buttons = {}
    
    -- Crear boton para cada perfil
    for i = 1, table.getn(profiles) do
        local profileName = profiles[i]
        
        local btn = CreateFrame("Button", nil, menu)
        btn:SetWidth(180)
        btn:SetHeight(buttonHeight)
        btn:SetPoint("TOP", menu, "TOP", 0, yOffset)
        
        -- Texto del boton
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("LEFT", btn, "LEFT", 10, 0)
        
        -- Resaltar perfil actual
        if profileName == currentProfile then
            btnText:SetText("|cFF00FF00" .. profileName .. " (Actual)|r")
        else
            btnText:SetText("|cFFFFFFFF" .. profileName .. "|r")
        end
        
        -- Highlight al pasar mouse
        local highlight = btn:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints(btn)
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0)
        btn.highlight = highlight
        
        btn:SetScript("OnEnter", function()
            this.highlight:SetAlpha(0.3)
        end)
        
        btn:SetScript("OnLeave", function()
            this.highlight:SetAlpha(0)
        end)
        
        -- Click: Cargar perfil
        btn:SetScript("OnClick", function()
            WCS_BrainProfiles.LoadProfile(profileName)
            menu:Hide()
        end)
        
        table.insert(buttons, btn)
        yOffset = yOffset - buttonHeight - 2
    end
    
    -- Boton "Abrir Gestor Completo"
    yOffset = yOffset - 10
    local openBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    openBtn:SetWidth(180)
    openBtn:SetHeight(25)
    openBtn:SetPoint("TOP", menu, "TOP", 0, yOffset)
    openBtn:SetText("Abrir Gestor Completo")
    openBtn:SetScript("OnClick", function()
        menu:Hide()
        if WCS_BrainProfilesUI then
            WCS_BrainProfilesUI:Show()
        end
    end)
    
    yOffset = yOffset - 35
    
    -- Ajustar altura del menu
    menu:SetHeight(math.abs(yOffset) + 20)
    
    -- Cerrar al hacer click fuera
    menu:EnableMouse(true)
    menu:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            this:Hide()
        end
    end)
    
    -- Auto-cerrar despues de 10 segundos
    menu:SetScript("OnUpdate", function()
        if not this.timer then
            this.timer = 0
        end
        this.timer = this.timer + arg1
        if this.timer > 10 then
            this:Hide()
        end
    end)
    
    menu:Show()
end

-- ============================================================================
-- MOSTRAR/OCULTAR BOTON
-- ============================================================================
function WCS_BrainProfilesButton:Show()
    if button then
        button:Show()
        local config = GetConfig()
        config.visible = true
    end
end

function WCS_BrainProfilesButton:Hide()
    if button then
        button:Hide()
        local config = GetConfig()
        config.visible = false
    end
end

function WCS_BrainProfilesButton:Toggle()
    if button and button:IsVisible() then
        WCS_BrainProfilesButton:Hide()
    else
        WCS_BrainProfilesButton:Show()
    end
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
local function OnLoad()
    WCS_BrainProfilesButton:Create()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700WCS Brain Profiles Button|r v" .. WCS_BrainProfilesButton.VERSION .. " cargado")
end

-- Registrar evento de carga
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnLoad)

