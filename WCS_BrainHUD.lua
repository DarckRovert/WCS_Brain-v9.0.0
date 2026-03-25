--[[
    WCS_BrainHUD.lua - Interfaz Holográfica "Iron Man" (v7.0)
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Proporciona información visual inmediata cerca del personaje sobre
    el estado de la IA, recursos (shards) y decisiones.
]]--

WCS_BrainHUD = WCS_BrainHUD or {}
WCS_BrainHUD.VERSION = "1.0.0"

-- Configuración visual
WCS_BrainHUD.Config = {
    scale = 0.8,
    alpha = 0.6,
    xOffset = 0,
    yOffset = -150, -- Debajo del personaje por defecto
    enabled = true
}

-- ============================================================================
-- CREACIÓN DE FRAMES
-- ============================================================================

function WCS_BrainHUD:CreateHUD()
    if self.Frame then return end

    -- Frame Padre (320x150px)
    self.Frame = CreateFrame("Frame", "WCS_HUD_Main", UIParent)
    self.Frame:SetWidth(320)
    self.Frame:SetHeight(150)
    self.Frame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -210, 200)
    self.Frame:SetScale(self.Config.scale)
    self.Frame:SetAlpha(self.Config.alpha)
    self.Frame:SetFrameStrata("MEDIUM")

    -- Fondo glassmorphism oscuro
    self.Frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    self.Frame:SetBackdropColor(0.04, 0.02, 0.10, 0.80)
    self.Frame:SetBackdropBorderColor(0.0, 1.0, 0.5, 0.7)

    -- === ICONO DE DECISION (izquierda) ===
    self.IconFrame = CreateFrame("Frame", "WCS_HUD_Icon", self.Frame)
    self.IconFrame:SetWidth(56)
    self.IconFrame:SetHeight(56)
    self.IconFrame:SetPoint("LEFT", self.Frame, "LEFT", 12, 10)

    self.IconTexture = self.IconFrame:CreateTexture(nil, "ARTWORK")
    self.IconTexture:SetAllPoints(self.IconFrame)
    self.IconTexture:SetTexture("Interface\\Icons\\Spell_Shadow_ScourgeBuild")

    self.IconBorder = self.IconFrame:CreateTexture(nil, "OVERLAY")
    self.IconBorder:SetWidth(90)
    self.IconBorder:SetHeight(90)
    self.IconBorder:SetPoint("CENTER", self.IconFrame, "CENTER", 0, 0)
    self.IconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    self.IconBorder:SetVertexColor(0.0, 1.0, 0.5, 0.8)
    self.IconBorder:SetBlendMode("ADD")

    -- Nombre del hechizo bajo el icono
    self.ActionText = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.ActionText:SetPoint("TOP", self.IconFrame, "BOTTOM", 0, -3)
    self.ActionText:SetWidth(90)
    self.ActionText:SetText("|cFFFFD700Esperando...|r")

    -- === PANEL DERECHO: HP/Mana/Shards ===
    -- HP Bar
    local hpLabel = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpLabel:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 82, -15)
    hpLabel:SetText("|cFF00FF00HP|r")

    self.HPBar = CreateFrame("StatusBar", nil, self.Frame)
    self.HPBar:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 105, -12)
    self.HPBar:SetWidth(190)
    self.HPBar:SetHeight(12)
    self.HPBar:SetMinMaxValues(0, 100)
    self.HPBar:SetValue(100)
    self.HPBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    self.HPBar:SetStatusBarColor(0.1, 0.9, 0.1, 1)

    self.HPText = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.HPText:SetPoint("CENTER", self.HPBar, "CENTER", 0, 0)
    self.HPText:SetText("100%")

    -- Mana Bar
    local manaLabel = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manaLabel:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 82, -33)
    manaLabel:SetText("|cFF0088FFMana|r")

    self.ManaBar = CreateFrame("StatusBar", nil, self.Frame)
    self.ManaBar:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 105, -30)
    self.ManaBar:SetWidth(190)
    self.ManaBar:SetHeight(12)
    self.ManaBar:SetMinMaxValues(0, 100)
    self.ManaBar:SetValue(100)
    self.ManaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    self.ManaBar:SetStatusBarColor(0.1, 0.5, 1.0, 1)

    self.ManaText = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.ManaText:SetPoint("CENTER", self.ManaBar, "CENTER", 0, 0)
    self.ManaText:SetText("100%")

    -- Shards
    local shardIcon = self.Frame:CreateTexture(nil, "ARTWORK")
    shardIcon:SetWidth(18)
    shardIcon:SetHeight(18)
    shardIcon:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 83, -50)
    shardIcon:SetTexture("Interface\\Icons\\Inv_Misc_Gem_Amethyst_02")

    self.ShardCount = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.ShardCount:SetPoint("LEFT", shardIcon, "RIGHT", 4, 0)
    self.ShardCount:SetText("|cFF9482C90 fragmentos|r")

    -- Fase de combate
    self.PhaseText = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.PhaseText:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 83, -70)
    self.PhaseText:SetText("|cFFAAAAAASistema listo|r")

    -- Texto de objetivo
    self.TargetText = self.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.TargetText:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 83, -88)
    self.TargetText:SetText("|cFF888888Sin objetivo|r")

    -- Drag
    self.Frame:EnableMouse(true)
    self.Frame:SetMovable(true)
    self.Frame:RegisterForDrag("LeftButton")
    self.Frame:SetScript("OnDragStart", function() this:StartMoving() end)
    self.Frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- OnUpdate
    self.Frame:SetScript("OnUpdate", function() WCS_BrainHUD:OnUpdate(arg1) end)
end


-- ============================================================================
-- LÓGICA DE ACTUALIZACIÓN
-- ============================================================================

local updateTimer = 0
function WCS_BrainHUD:OnUpdate(elapsed)
    updateTimer = updateTimer + (elapsed or 0)
    if updateTimer < 0.15 then return end
    updateTimer = 0

    if not self.Config.enabled then
        if self.Frame:IsVisible() then self.Frame:Hide() end
        return
    end

    -- === HP del jugador ===
    if self.HPBar then
        local maxHP = UnitHealthMax("player") or 1
        local curHP = UnitHealth("player") or 0
        local pct = math.floor((curHP / maxHP) * 100)
        self.HPBar:SetValue(pct)
        self.HPText:SetText(pct .. "%")
        if pct < 30 then
            self.HPBar:SetStatusBarColor(1, 0.1, 0.1, 1)
        elseif pct < 60 then
            self.HPBar:SetStatusBarColor(1, 0.7, 0.1, 1)
        else
            self.HPBar:SetStatusBarColor(0.1, 0.9, 0.1, 1)
        end
    end

    -- === Mana del jugador ===
    if self.ManaBar then
        local maxMana = UnitManaMax("player") or 1
        local curMana = UnitMana("player") or 0
        local pct = math.floor((curMana / maxMana) * 100)
        self.ManaBar:SetValue(pct)
        self.ManaText:SetText(pct .. "%")
        if pct < 20 then
            self.ManaBar:SetStatusBarColor(1, 0.2, 0.2, 1)
        elseif pct < 50 then
            self.ManaBar:SetStatusBarColor(1, 0.7, 0.0, 1)
        else
            self.ManaBar:SetStatusBarColor(0.1, 0.5, 1.0, 1)
        end
    end

    -- === Shards ===
    if self.ShardCount then
        local shards = 0
        if WCS_ResourceManager and WCS_ResourceManager.GetShardCount then
            shards = WCS_ResourceManager:GetShardCount() or 0
        end
        local color = shards < 3 and "FF4444" or "9482C9"
        self.ShardCount:SetText("|cFF" .. color .. shards .. " shards|r")
    end

    -- === Decision de IA ===
    if WCS_Brain and WCS_Brain.CurrentDecision then
        local action = WCS_Brain.CurrentDecision
        if action and action.spell then
            local icon = self:GetSpellTexture(action.spell)
            self.IconTexture:SetTexture(icon or "Interface\\Icons\\Inv_Misc_QuestionMark")
            self.ActionText:SetText("|cFFFFD700" .. action.spell .. "|r")

            if action.priority == 1 then
                self.IconBorder:SetVertexColor(1, 0, 0, 1)         -- Emergencia: Rojo
            elseif action.priority == 9 then
                self.IconBorder:SetVertexColor(0.58, 0.51, 0.79, 0.5) -- Filler: Purpura
            else
                self.IconBorder:SetVertexColor(0.0, 1.0, 0.5, 0.8) -- Normal: Fel Green
            end
        else
            self.IconTexture:SetTexture("Interface\\Icons\\Spell_Shadow_ScourgeBuild")
            self.ActionText:SetText("|cFFAAAAAAIdle|r")
            self.IconBorder:SetVertexColor(0.3, 0.3, 0.3, 0.5)
        end
    end

    -- === Fase de combate ===
    if self.PhaseText then
        local phase = (WCS_Brain and WCS_Brain.Context and WCS_Brain.Context.phase) or "idle"
        local phaseColors = {
            idle      = "888888",
            opener    = "FFCC00",
            sustain   = "00FF00",
            execute   = "FF4400",
            emergency = "FF0000",
            aoe       = "FF8800",
        }
        local color = phaseColors[phase] or "AAAAAA"
        self.PhaseText:SetText("|cFF" .. color .. "Fase: " .. string.upper(phase) .. "|r")
    end

    -- === Objetivo activo ===
    if self.TargetText then
        if UnitExists("target") then
            local tname = UnitName("target") or "?"
            local thp = math.floor(((UnitHealth("target") or 0) / (UnitHealthMax("target") or 1)) * 100)
            local col = UnitIsEnemy("player", "target") and "FF4444" or "00FF00"
            self.TargetText:SetText("|cFF" .. col .. tname .. "|r |cFFAAAAAA" .. thp .. "%|r")
        else
            self.TargetText:SetText("|cFF666666Sin objetivo|r")
        end
    end

    -- Opacidad segun combate o no
    local targetAlpha = (UnitExists("target") or UnitAffectingCombat("player")) and self.Config.alpha or (self.Config.alpha * 0.4)
    local curAlpha = self.Frame:GetAlpha()
    local delta = targetAlpha - curAlpha
    if math.abs(delta) > 0.02 then
        self.Frame:SetAlpha(curAlpha + delta * 0.15)
    end
end


-- Helper para obtener icono
function WCS_BrainHUD:GetSpellTexture(spellName)
    if not spellName then return nil end
    -- Intentar obtener del SpellDB si existe
    if WCS_SpellDB and WCS_SpellDB.GetSpellTexture then
        return WCS_SpellDB:GetSpellTexture(spellName)
    end
    -- Fallback: GetSpellTexture necesita ID, no nombre en 1.12 standard
    -- pero podemos usar WCS_BrainCore:FindSpellSlot
    if WCS_BrainCore then
        local slot = WCS_BrainCore:FindSpellSlot(spellName)
        if slot then
            return GetSpellTexture(slot, BOOKTYPE_SPELL)
        end
    end
    return nil
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================

function WCS_BrainHUD:Initialize()
    self:CreateHUD()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_BrainHUD]|r Interfaz Holografica cargado. /brainhud toggle")
end

-- Evento de carga
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() WCS_BrainHUD:Initialize() end)

-- Comando Slash
SLASH_WCSBRAINHUD1 = "/brainhud"
SlashCmdList["WCSBRAINHUD"] = function(msg)
    WCS_BrainHUD.Config.enabled = not WCS_BrainHUD.Config.enabled
    DEFAULT_CHAT_FRAME:AddMessage("WCS_BrainHUD: " .. (WCS_BrainHUD.Config.enabled and "ON" or "OFF"))
end
