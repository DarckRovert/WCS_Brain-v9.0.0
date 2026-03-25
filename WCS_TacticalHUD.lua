--[[
    WCS_TacticalHUD.lua - Visual Intelligence v8.0.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
]]--

WCS = WCS or {}
WCS.TacticalHUD = WCS.TacticalHUD or {}
local HUD = WCS.TacticalHUD

HUD.Config = { x = 0, y = -120, scale = 1.1, locked = true }

function HUD:CreateFrame()
    if self.Main then return end
    if WCS_BrainSaved and WCS_BrainSaved.HUD then self.Config = WCS_BrainSaved.HUD end

    self.Main = CreateFrame("Frame", "WCS_TacticalHUD_Main", UIParent)
    self.Main:SetWidth(200) self.Main:SetHeight(85)
    -- [1.12 Fix] Use UIParent global instead of string
    self.Main:SetPoint("CENTER", UIParent, "CENTER", self.Config.x, self.Config.y)
    self.Main:SetScale(self.Config.scale)
    
    self.Main:SetMovable(true)
    self.Main:EnableMouse(not self.Config.locked)
    self.Main:RegisterForDrag("LeftButton")
    self.Main:SetScript("OnDragStart", function() if not HUD.Config.locked then HUD.Main:StartMoving() end end)
    self.Main:SetScript("OnDragStop", function() 
        HUD.Main:StopMovingOrSizing() 
        local _, _, _, x, y = HUD.Main:GetPoint()
        HUD.Config.x, HUD.Config.y = x, y
        if WCS_BrainSaved then WCS_BrainSaved.HUD = HUD.Config end
    end)

    self.Main:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    self.Main:SetBackdropColor(0.08, 0.06, 0.12, 0.85)
    self.Main:SetBackdropBorderColor(0.58, 0.51, 0.79, 1) -- Séquito Purple
    
    self.IconTex = self.Main:CreateTexture(nil, "ARTWORK")
    self.IconTex:SetWidth(40) self.IconTex:SetHeight(40)
    self.IconTex:SetPoint("LEFT", self.Main, "LEFT", 10, 0)
    
    self.Label = self.Main:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Label:SetPoint("TOPLEFT", self.IconTex, "TOPRIGHT", 10, 2)
    self.Label:SetTextColor(1, 0.82, 0) -- Dorado
    
    self.Reason = self.Main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.Reason:SetPoint("TOPLEFT", self.Label, "BOTTOMLEFT", 0, -2)
    self.Reason:SetTextColor(0.6, 0.6, 0.6)

    self.Bar = CreateFrame("StatusBar", nil, self.Main)
    self.Bar:SetWidth(120) self.Bar:SetHeight(5)
    self.Bar:SetPoint("BOTTOMLEFT", self.IconTex, "BOTTOMRIGHT", 10, 2)
    self.Bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    self.Bar:SetStatusBarColor(0.58, 0.51, 0.79) -- Séquito Purple
    self.Bar:SetMinMaxValues(0, 32)

    self.Main:Hide()
end

function HUD:Update()
    if not self.Main then return end
    local action = WCS.DecisionEngine and WCS.DecisionEngine:GetBestAction()
    
    if action then
        self.Label:SetText(string.upper(action.spell))
        self.Reason:SetText(action.reason or "Logic")
        self.IconTex:SetTexture(WCS.SpellManager and WCS.SpellManager:GetIcon(action.spell) or "Interface\\Icons\\Inv_Misc_QuestionMark")
    end

    if WCS.DataManager then self.Bar:SetValue(WCS.DataManager:GetShardCount()) end
    if UnitAffectingCombat("player") or UnitExists("target") then self.Main:Show() else self.Main:Hide() end
end

WCS:Log("Tactical HUD v8.0.0 (Hardened API) Aligned.")
