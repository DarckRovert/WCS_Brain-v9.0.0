-- WCS_BrainTutorialButton.lua
-- Boton flotante para acceder al tutorial rapidamente
-- Version: 6.5.0
-- Compatible con Lua 5.0 (WoW 1.12)

WCS_BrainTutorialButton = {
    VERSION = "6.5.0",
    button = nil,
    isShowing = false
}

function WCS_BrainTutorialButton:Initialize()
    -- Crear el boton flotante
    self:CreateButton()
    
    -- Registrar comandos
    self:RegisterCommands()
    
    -- Cargar posicion guardada
    self:LoadPosition()
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("TutorialButton inicializado v" .. self.VERSION)
    end
end

function WCS_BrainTutorialButton:CreateButton()
    if self.button then return end
    
    -- Crear frame del boton
    local button = CreateFrame("Button", "WCS_TutorialButton", UIParent)
    button:SetWidth(40)
    button:SetHeight(40)
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    
    -- Hacer el boton movible
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        WCS_BrainTutorialButton:SavePosition()
    end)
    
    -- Textura de fondo (icono de libro/tutorial)
    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(button)
    texture:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    button.texture = texture
    
    -- Borde
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints(button)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(0.58, 0.51, 0.79, 1) -- COLOR_PURPLE
    button.border = border
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tutorial WCS Brain", 1, 0.82, 0) -- Dorado
        GameTooltip:AddLine("Click: Abrir tutorial", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Shift+Click: Reiniciar tutorial", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Arrastra para mover", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click handler
    button:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            -- Shift+Click: Reiniciar tutorial
            if WCS_BrainTutorial then
                WCS_BrainTutorial:Start()
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain Tutorial]|r Tutorial reiniciado")
            end
        else
            -- Click normal: Abrir/continuar tutorial
            if WCS_BrainTutorial then
                if WCS_BrainTutorial.currentStep and WCS_BrainTutorial.currentStep > 0 then
                    -- Continuar tutorial
                    if WCS_BrainTutorialUI then
                        WCS_BrainTutorialUI:Show()
                    else
                        WCS_BrainTutorial:ShowStep(WCS_BrainTutorial.currentStep)
                    end
                else
                    -- Iniciar tutorial
                    WCS_BrainTutorial:Start()
                end
            end
        end
    end)
    
    self.button = button
    self.isShowing = true
end

function WCS_BrainTutorialButton:Show()
    if not self.button then
        self:CreateButton()
    end
    self.button:Show()
    self.isShowing = true
end

function WCS_BrainTutorialButton:Hide()
    if self.button then
        self.button:Hide()
    end
    self.isShowing = false
end

function WCS_BrainTutorialButton:Toggle()
    if self.isShowing then
        self:Hide()
    else
        self:Show()
    end
end

function WCS_BrainTutorialButton:SavePosition()
    if not self.button then return end
    
    local point, relativeTo, relativePoint, xOfs, yOfs = self.button:GetPoint()
    
    if not WCS_BrainTutorialButtonSaved then
        WCS_BrainTutorialButtonSaved = {}
    end
    
    WCS_BrainTutorialButtonSaved.point = point
    WCS_BrainTutorialButtonSaved.relativePoint = relativePoint
    WCS_BrainTutorialButtonSaved.xOfs = xOfs
    WCS_BrainTutorialButtonSaved.yOfs = yOfs
end

function WCS_BrainTutorialButton:LoadPosition()
    if not self.button then return end
    if not WCS_BrainTutorialButtonSaved then return end
    
    local saved = WCS_BrainTutorialButtonSaved
    if saved.point and saved.xOfs and saved.yOfs then
        self.button:ClearAllPoints()
        self.button:SetPoint(
            saved.point or "CENTER",
            UIParent,
            saved.relativePoint or "CENTER",
            saved.xOfs or 0,
            saved.yOfs or -200
        )
    end
end

function WCS_BrainTutorialButton:RegisterCommands()
    SLASH_TUTORIALBUTTON1 = "/tutorialbutton"
    SLASH_TUTORIALBUTTON2 = "/tutbtn"
    SlashCmdList["TUTORIALBUTTON"] = function(msg)
        msg = string.lower(msg or "")
        
        if msg == "show" then
            WCS_BrainTutorialButton:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain Tutorial]|r Boton mostrado")
        elseif msg == "hide" then
            WCS_BrainTutorialButton:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain Tutorial]|r Boton ocultado")
        elseif msg == "toggle" then
            WCS_BrainTutorialButton:Toggle()
        elseif msg == "reset" then
            if WCS_BrainTutorialButton.button then
                WCS_BrainTutorialButton.button:ClearAllPoints()
                WCS_BrainTutorialButton.button:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
                WCS_BrainTutorialButton:SavePosition()
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain Tutorial]|r Posicion reseteada")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain Tutorial Button]|r Comandos:")
            DEFAULT_CHAT_FRAME:AddMessage("  /tutorialbutton show - Mostrar boton")
            DEFAULT_CHAT_FRAME:AddMessage("  /tutorialbutton hide - Ocultar boton")
            DEFAULT_CHAT_FRAME:AddMessage("  /tutorialbutton toggle - Alternar visibilidad")
            DEFAULT_CHAT_FRAME:AddMessage("  /tutorialbutton reset - Resetear posicion")
        end
    end
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainTutorialButton:Initialize()
    end
end)
