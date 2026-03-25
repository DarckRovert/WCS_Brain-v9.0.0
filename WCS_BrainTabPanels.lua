--[[
    WCS_BrainTabPanels.lua - Paneles de UI para Tabs 5-14 del Panel Maestro
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)

    Crea los constructores CreateUI() de cada modulo que lo necesite
    para integrarse en el ecosistema de pestanas del Cerebro.

    Autor: Elnazzareno (DarckRovert)
    Version: 9.0.0
]]--

-- ============================================================================
-- HELPER LOCAL: Crea un panel de contenedor estandar para el panel maestro
-- ============================================================================
local function MakeTabFrame(name, r, g, b)
    if _G[name] then return end
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(680)
    f:SetHeight(520)
    f:Hide()
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0.04, 0.02, 0.10, 0.97)
    f:SetBackdropBorderColor(r or 0.58, g or 0.51, b or 0.79, 0.85)
    return f
end

local function MakeSectionPanel(parent, x, y, w, h, title, r, g, b)
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(w)
    p:SetHeight(h)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    p:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    p:SetBackdropColor(0.07, 0.04, 0.12, 0.90)
    p:SetBackdropBorderColor(r or 0.58, g or 0.51, b or 0.79, 0.75)
    if title then
        local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", p, "TOP", 0, -10)
        t:SetText(title)
        t:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end
    return p
end

local function MakeLabel(parent, txt, x, y, template)
    local l = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    l:SetText(txt)
    return l
end

-- ============================================================================
-- TAB 5: MASCOTA (WCS_BrainPetUI)
-- ============================================================================
if WCS_BrainPetUI then
    function WCS_BrainPetUI:CreateUI()
        if _G["WCSBrainConfigWindow"] then return end

        local f = MakeTabFrame("WCSBrainConfigWindow", 1, 0.5, 0)  -- Naranja magen (pets)
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFFFF8800SISTEMA DE MASCOTA|r")

        -- Panel Izquierdo: Estado de mascota actual
        local leftPanel = MakeSectionPanel(f, 15, -45, 320, 460, "|cFFFF8800Estado de la Mascota|r", 1, 0.5, 0)

        -- Info de mascota
        local petStatusTexts = {}
        local petFields = {
            { label = "|cFFAAAAAATipo:|r",      key = "type" },
            { label = "|cFF00FF00HP:|r",         key = "hp" },
            { label = "|cFF0088FFMana:|r",        key = "mana" },
            { label = "|cFFFFAA00En Combate:|r",  key = "combat" },
            { label = "|cFFCC99FFEstado PetAI:|r",key = "ai" },
        }
        for i, fld in ipairs(petFields) do
            MakeLabel(leftPanel, fld.label, 12, -38 - (i-1)*22)
            local v = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            v:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 130, -38 - (i-1)*22)
            v:SetText("|cFF666666------|r")
            petStatusTexts[fld.key] = v
        end

        -- Checkbox PetAI
        local enableLabel = MakeLabel(leftPanel, "|cFFCC99FFActivar PetAI|r", 12, -155)

        local enableCheck = CreateFrame("CheckButton", nil, leftPanel, "UICheckButtonTemplate")
        enableCheck:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 120, -148)
        enableCheck:SetChecked(WCS_BrainPetAI_IsEnabled and WCS_BrainPetAI_IsEnabled() or false)
        enableCheck:SetScript("OnClick", function()
            if WCS_BrainPetAI_SetEnabled then
                WCS_BrainPetAI_SetEnabled(this:GetChecked())
            end
        end)

        -- Panel Derecho: Historial de habilidades disponibles
        local rightPanel = MakeSectionPanel(f, 345, -45, 320, 460, "|cFF00FF80Habilidades de Mascota|r", 0, 1, 0.5)

        -- Lista de hasta 14 habilidades detectadas
        local abilityRows = {}
        for i = 1, 14 do
            local row = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -35 - (i-1)*28)
            row:SetText("|cFF666666[" .. i .. "]: ------|r")
            abilityRows[i] = row
        end

        -- OnUpdate: refrescar estado mascota
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 1.0 or not f:IsVisible() then return end
            elapsed = 0

            if UnitExists("pet") then
                local pname = UnitName("pet") or "---"
                local ptype = ""
                if WCS_BrainPetAI and WCS_BrainPetAI.GetPetType then
                    ptype = WCS_BrainPetAI:GetPetType() or "---"
                end
                local maxhp = UnitHealthMax("pet") or 1
                local curhp = UnitHealth("pet") or 0
                local hpPct = math.floor((curhp / maxhp) * 100)
                local maxmp = UnitManaMax("pet") or 0
                local curmp = UnitMana("pet") or 0
                local mpPct = maxmp > 0 and math.floor((curmp / maxmp) * 100) or 0

                petStatusTexts.type:SetText("|cFFFFFFFF" .. pname .. " (" .. ptype .. ")|r")
                petStatusTexts.hp:SetText("|cFF00FF00" .. hpPct .. "%|r")
                petStatusTexts.mana:SetText("|cFF0088FF" .. mpPct .. "%|r")
                petStatusTexts.combat:SetText(UnitAffectingCombat("pet") and "|cFFFF0000Sí|r" or "|cFF00FF00No|r")

                local aiEnabled = WCS_BrainPetAI_IsEnabled and WCS_BrainPetAI_IsEnabled() or false
                petStatusTexts.ai:SetText(aiEnabled and "|cFF00FF00ACTIVO|r" or "|cFFFF0000INACTIVO|r")

                -- Escanear habilidades de la barra de mascota
                for i = 1, 14 do
                    local name, subtext, texture, isToken, isActive = GetPetActionInfo(i)
                    if name then
                        local color = isActive and "FFCC00" or "AAAAAA"
                        abilityRows[i]:SetText("|cFF" .. color .. i .. ": " .. name .. "|r")
                    else
                        abilityRows[i]:SetText("|cFF444444[" .. i .. "]: ------|r")
                    end
                end
            else
                petStatusTexts.type:SetText("|cFF666666Sin mascota|r")
                petStatusTexts.hp:SetText("|cFF666666--|r")
                petStatusTexts.mana:SetText("|cFF666666--|r")
                petStatusTexts.combat:SetText("|cFF666666--|r")
                petStatusTexts.ai:SetText("|cFF666666--|r")
                for i = 1, 14 do
                    abilityRows[i]:SetText("|cFF444444[" .. i .. "]: ------|r")
                end
            end
        end)
    end
end

-- ============================================================================
-- TAB 6: PET SOCIAL
-- ============================================================================
if WCS_BrainPetSocial or true then
    if not WCS_BrainPetSocial then WCS_BrainPetSocial = {} end
    function WCS_BrainPetSocial:CreateUI()
        if _G["WCSBrainPetSocialFrame"] then return end
        local f = MakeTabFrame("WCSBrainPetSocialFrame", 0.8, 0, 0.8) -- Magenta
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFFFF44FFPET SOCIAL ENGINE|r")

        -- Panel de emociones
        local emotPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFFFF44FFEstado Emocional|r", 0.8, 0, 0.8)
        local emotions = {"Feliz", "Triste", "Hambriento", "Cansado", "Ansioso", "Agresivo", "Curioso"}
        local emotBars = {}
        for i, em in ipairs(emotions) do
            local label = emotPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPLEFT", emotPanel, "TOPLEFT", 12, -32 - (i-1)*45)
            label:SetText("|cFFCC99FF" .. em .. ":|r")

            local bar = CreateFrame("StatusBar", nil, emotPanel)
            bar:SetPoint("TOPLEFT", emotPanel, "TOPLEFT", 12, -46 - (i-1)*45)
            bar:SetWidth(270)
            bar:SetHeight(12)
            bar:SetMinMaxValues(0, 100)
            bar:SetValue(50)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(0.8, 0, 0.8, 1)
            emotBars[em] = bar
        end

        -- Panel de mensajes recientes
        local chatPanel = MakeSectionPanel(f, 345, -45, 320, 460, "|cFF00FF80Mensajes de Mascota|r", 0, 1, 0.5)
        local chatLines = {}
        for i = 1, 15 do
            local line = chatPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", chatPanel, "TOPLEFT", 8, -30 - (i-1)*26)
            line:SetWidth(290)
            line:SetText("")
            chatLines[i] = line
        end

        -- Actualizar emociones desde WCS_BrainPetSocial si existen
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 1.5 or not f:IsVisible() then return end
            elapsed = 0

            if WCS_BrainPetSocial and WCS_BrainPetSocial.Emotions then
                for em, bar in pairs(emotBars) do
                    local val = WCS_BrainPetSocial.Emotions[string.lower(em)] or 50
                    bar:SetValue(val)
                end
            end
        end)
    end
end

-- ============================================================================
-- TAB 7: PERFILES (WCS_BrainProfilesUI)
-- ============================================================================
WCS_BrainProfilesUI = WCS_BrainProfilesUI or {}
function WCS_BrainProfilesUI:CreateUI()
        if _G["WCSBrainProfilesFrame"] then return end
        -- Si ya hay un CreateMainFrame, usarlo
        if WCS_BrainProfilesUI.CreateMainFrame then
            WCS_BrainProfilesUI:CreateMainFrame()
            return
        end
        local f = MakeTabFrame("WCSBrainProfilesFrame", 1, 0.82, 0)
        if not f then return end
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFFFFD700PERFILES DE CONFIGURACION|r")
        
        local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFFFFD700Perfiles Disponibles|r", 1, 0.82, 0)
        local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFF888888Detalles del Perfil|r", 0.5, 0.5, 0.5)

        local profileButtons = {}
        local selectedProfile = nil

        local detailsText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        detailsText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -30)
        detailsText:SetWidth(285)
        detailsText:SetJustifyH("LEFT")
        detailsText:SetText("|cFF888888Selecciona un perfil para ver detalles|r")

        for i = 1, 10 do
            local btn = CreateFrame("Button", nil, leftPanel)
            btn:SetWidth(280)
            btn:SetHeight(25)
            btn:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -30 - (i-1)*28)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(btn)
            bg:SetTexture(1, 1, 1, 0)
            btn.bg = bg
            
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", btn, "LEFT", 5, 0)
            txt:SetJustifyH("LEFT")
            btn.txt = txt
            
            btn:SetScript("OnEnter", function() this.bg:SetTexture(1, 0.82, 0, 0.2) end)
            btn:SetScript("OnLeave", function() 
                if selectedProfile ~= this.profileName then this.bg:SetTexture(1, 1, 1, 0) end 
            end)
            btn:SetScript("OnClick", function()
                if not this.profileName then return end
                selectedProfile = this.profileName
                for j = 1, 10 do profileButtons[j].bg:SetTexture(1, 1, 1, 0) end
                this.bg:SetTexture(1, 0.82, 0, 0.4)
                
                if WCS_BrainProfiles and WCS_BrainProfiles.GetProfileDetails then
                    local p = WCS_BrainProfiles.GetProfileDetails(selectedProfile)
                    if p then
                        local d = "|cFFFFD700" .. selectedProfile .. "|r\n\n"
                        d = d .. (p.description or "Sin descripción") .. "\n\n"
                        if p.ai then
                            d = d .. "|cFF00FF80=== IA Principal ===|r\nActivado: " .. (p.ai.enabled and "Si" or "No") .. "\n"
                            if p.ai.aggressiveness then d = d .. "Agresividad: " .. (p.ai.aggressiveness * 100) .. "%\n" end
                        end
                        if p.petAI then
                            d = d .. "\n|cFF00FF80=== IA Mascota ===|r\nActivado: " .. (p.petAI.enabled and "Si" or "No") .. "\n"
                        end
                        detailsText:SetText(d)
                    end
                end
            end)
            profileButtons[i] = btn
        end

        local function RefreshProfiles()
            if not WCS_BrainProfiles then return end
            local profiles = WCS_BrainProfiles.GetProfileList()
            local current = WCS_BrainProfiles.GetCurrentProfileName()
            for i = 1, 10 do
                local pName = profiles[i]
                local btn = profileButtons[i]
                if pName then
                    btn.profileName = pName
                    local prefix = (pName == current) and "|cFF00FF00> |r" or ""
                    btn.txt:SetText(prefix .. "|cFFFFFFFF" .. pName .. "|r")
                    if pName == selectedProfile then btn.bg:SetTexture(1, 0.82, 0, 0.4) else btn.bg:SetTexture(1, 1, 1, 0) end
                    btn:Show()
                else
                    btn.profileName = nil
                    btn:Hide()
                end
            end
        end

        f:SetScript("OnShow", function() RefreshProfiles() end)
        
        -- Fix OnUpdate to auto-refresh details text occasionally if needed
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed > 2 then
                elapsed = 0
                if f:IsVisible() then RefreshProfiles() end
            end
        end)

        local loadBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
        loadBtn:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 15, 15)
        loadBtn:SetWidth(85)
        loadBtn:SetHeight(25)
        loadBtn:SetText("Cargar")
        loadBtn:SetScript("OnClick", function()
            if selectedProfile and WCS_BrainProfiles then
                WCS_BrainProfiles.LoadProfile(selectedProfile)
                RefreshProfiles()
            end
        end)

        local saveBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
        saveBtn:SetPoint("LEFT", loadBtn, "RIGHT", 10, 0)
        saveBtn:SetWidth(85)
        saveBtn:SetHeight(25)
        saveBtn:SetText("Guardar")
        saveBtn:SetScript("OnClick", function()
            if WCS_BrainProfiles then
                local target = selectedProfile or WCS_BrainProfiles.GetCurrentProfileName()
                if target then
                    local config = WCS_BrainProfiles.CaptureCurrentConfig()
                    WCS_BrainProfiles.UpdateProfile(target, config)
                    RefreshProfiles()
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Perfiles]|r Guardado: " .. target)
                end
            end
        end)
        
        local newBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
        newBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
        newBtn:SetWidth(85)
        newBtn:SetHeight(25)
        newBtn:SetText("Nuevo")
        newBtn:SetScript("OnClick", function()
            if WCS_BrainProfilesUI and WCS_BrainProfilesUI.ShowCreateDialog then
                WCS_BrainProfilesUI:ShowCreateDialog()
            end
        end)
    end

-- ============================================================================
-- TAB 8: METRICAS (WCS_BrainMetrics)
-- ============================================================================
if WCS_BrainMetrics then
    function WCS_BrainMetrics:CreateUI()
        if _G["WCSBrainMetricsFrame"] then return end
        local f = MakeTabFrame("WCSBrainMetricsFrame", 0, 0.8, 1)
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFF00CCFFMETRICAS DE COMBATE|r")

        -- Panel de metricas en dos columnas
        local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFF00CCFFRendimiento Actual|r", 0, 0.8, 1)
        local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFFFF8800Historial de Encuentros|r", 1, 0.53, 0)

        -- Labels de métricas en vivo
        local metricKeys = {
            { key = "dps",       label = "|cFFFFCC00DPS en vivo:|r" },
            { key = "hps",       label = "|cFF00FF00HPS (curada):|r" },
            { key = "casts",     label = "|cFFAAAAAACasts/min:|r" },
            { key = "hits",      label = "|cFF00FF00Golpes:|r" },
            { key = "crits",     label = "|cFFFF6600Críticos:|r" },
            { key = "misses",    label = "|cFFFF4444Fallas:|r" },
        }

        local metricTexts = {}
        for i, m in ipairs(metricKeys) do
            MakeLabel(leftPanel, m.label, 12, -35 - (i-1)*25)
            local v = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            v:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 150, -35 - (i-1)*25)
            v:SetText("|cFF666666--|r")
            metricTexts[m.key] = v
        end

        -- Historial últimos 10 combates
        local historyRows = {}
        MakeLabel(rightPanel, "|cFFFFAA00# | Duración | DPS | Tipo|r", 12, -32)
        for i = 1, 10 do
            local row = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -52 - (i-1)*34)
            row:SetWidth(285)
            row:SetText("|cFF444444" .. i .. ". -------|r")
            historyRows[i] = row
        end

        -- Actualizar
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 1.0 or not f:IsVisible() then return end
            elapsed = 0

            -- Leer datos de WCS_BrainMetrics si disponible
            if WCS_BrainMetrics and WCS_BrainMetrics.GetLiveStats then
                local live = WCS_BrainMetrics:GetLiveStats() or {}
                metricTexts.dps:SetText("|cFFFFCC00" .. string.format("%.1f", live.dps or 0) .. "|r")
                metricTexts.hps:SetText("|cFF00FF00" .. string.format("%.1f", live.hps or 0) .. "|r")
                metricTexts.casts:SetText("|cFFFFFFFF" .. (live.casts or 0) .. "|r")
                metricTexts.hits:SetText("|cFF00FF00" .. (live.hits or 0) .. "|r")
                metricTexts.crits:SetText("|cFFFF6600" .. (live.crits or 0) .. "|r")
                metricTexts.misses:SetText("|cFFFF4444" .. (live.misses or 0) .. "|r")
            elseif WCS_BrainML and WCS_BrainML.Data then
                local stats = WCS_BrainML.Data.globalStats
                metricTexts.dps:SetText("|cFFFFCC00" .. string.format("%.1f", stats.avgDPS or 0) .. "|r")
                metricTexts.hps:SetText("|cFF666666--|r")
                metricTexts.casts:SetText("|cFF666666--|r")
                metricTexts.hits:SetText("|cFF666666--|r")
                metricTexts.crits:SetText("|cFF666666--|r")
                metricTexts.misses:SetText("|cFF666666--|r")
            end

            -- Historial
            if WCS_BrainML and WCS_BrainML.Data and WCS_BrainML.Data.combatHistory then
                local hist = WCS_BrainML.Data.combatHistory
                local total = table.getn(hist)
                for i = 1, 10 do
                    local row = historyRows[i]
                    local idx = total - i + 1
                    if idx >= 1 and hist[idx] then
                        local c = hist[idx]
                        local durSec = math.floor(c.duration or 0)
                        local survived = c.survived and "|cFF00FF00Vic|r" or "|cFFFF4444Der|r"
                        row:SetText("|cFFAAAAAA" .. i .. ".|r " .. survived .. " |cFFFFFFFF" .. durSec .. "s|r |cFFFFCC00" .. string.format("%.0f", c.dps or 0) .. "dps|r")
                    else
                        row:SetText("|cFF444444" .. i .. ". -------|r")
                    end
                end
            end
        end)
    end
end

-- ============================================================================
-- TAB 9: THINKING UI (WCS_BrainThinkingUI)
-- ============================================================================
if WCS_BrainThinkingUI then
    -- ThinkingUI ya tiene CreateFrame() - asegurarnos de que su frame sea visible
    -- No necesitamos CreateUI, CreateFrame ya crea "WCS_BrainThinkingUIFrame"
    -- El adaptador en CreateTabs llama a WCS_BrainThinkingUI:CreateFrame()
    -- => Nada que hacer
end

-- ============================================================================
-- TAB 10: AUTO-EJECUCION (WCS_BrainAutoExecute)
-- ============================================================================
WCS_BrainAutoExecute = WCS_BrainAutoExecute or {}
function WCS_BrainAutoExecute:CreateUI()
        if _G["WCSBrainAutoFrame"] then return end
        local f = MakeTabFrame("WCSBrainAutoFrame", 0, 1, 0.3)
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFF00FF4DAUTO-EJECUCION|r")

        local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFF00FF4DControl de Auto-Cast|r", 0, 1, 0.3)
        local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFFFFCC00Log de Acciones|r", 1, 0.8, 0)

        -- Toggle principal
        local enableLabel = MakeLabel(leftPanel, "|cFFFFFFFFActivar auto-ejecucion:|r", 12, -35)
        local enableCheck = CreateFrame("CheckButton", nil, leftPanel, "UICheckButtonTemplate")
        enableCheck:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 195, -28)
        local isEnabled = WCS_BrainAutoExecute.enabled or false
        enableCheck:SetChecked(isEnabled)
        enableCheck:SetScript("OnClick", function()
            WCS_BrainAutoExecute.enabled = this:GetChecked()
        end)

        -- Intervalo de casteo
        MakeLabel(leftPanel, "|cFFAAAAAACooldown min (seg):|r", 12, -65)
        local intervalSlider = CreateFrame("Slider", "WCS_BrainAutoIntervalSlider", leftPanel, "OptionsSliderTemplate")
        intervalSlider:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -90)
        intervalSlider:SetWidth(280)
        intervalSlider:SetMinMaxValues(0.5, 5.0)
        intervalSlider:SetValueStep(0.1)
        intervalSlider:SetValue(WCS_BrainAutoExecute.interval or 1.5)
        _G[intervalSlider:GetName() .. "Text"]:SetText("")
        _G[intervalSlider:GetName() .. "Low"]:SetText("0.5")
        _G[intervalSlider:GetName() .. "High"]:SetText("5.0")
        local iValText = MakeLabel(leftPanel, "1.5s", 140, -112)
        intervalSlider:SetScript("OnValueChanged", function()
            local v = this:GetValue()
            WCS_BrainAutoExecute.interval = v
            iValText:SetText(string.format("%.1fs", v))
        end)

        -- Log de acciones recientes
        local logLines = {}
        MakeLabel(rightPanel, "|cFFFFAA00Ultima accion ejecutada:|r", 12, -30)
        for i = 1, 15 do
            local row = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -50 - (i-1)*24)
            row:SetWidth(290)
            row:SetText("")
            logLines[i] = row
        end

        -- Actualizar log desde WCS_BrainAutoExecute.Log
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 0.8 or not f:IsVisible() then return end
            elapsed = 0
            enableCheck:SetChecked(WCS_BrainAutoExecute.enabled or false)
            if WCS_BrainAutoExecute.Log then
                local log = WCS_BrainAutoExecute.Log
                local total = table.getn(log)
                for i = 1, 15 do
                    local idx = total - i + 1
                    if idx >= 1 and log[idx] then
                        local e = log[idx]
                        logLines[i]:SetText("|cFFFFCC00" .. (e.spell or "?") .. "|r |cFF888888" .. (e.reason or "") .. "|r")
                    else
                        logLines[i]:SetText("")
                    end
                end
            end
        end)
end

-- ============================================================================
-- TAB 11: INTEGRACIONES (WCS_BrainIntegrations/BossMods/WeakAuras)
-- ============================================================================
WCS_BrainIntegrations = WCS_BrainIntegrations or {}
function WCS_BrainIntegrations:CreateUI()
        if _G["WCSBrainIntegrationsFrame"] then return end
        local f = MakeTabFrame("WCSBrainIntegrationsFrame", 0, 0.7, 1)
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFF00AAFF INTEGRACIONES EXTERNAS|r")

        local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFF00AAFFDeteccion de Addons|r", 0, 0.7, 1)
        local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFFFFCC00Estado de Bosses|r", 1, 0.8, 0)

        -- Lista de addons detectados
        local addonList = {
            { label = "BigWigs",       check = function() return BigWigsLoader ~= nil or BWLC ~= nil end },
            { label = "DBM",           check = function() return DBM ~= nil end },
            { label = "WeakAuras",     check = function() return WeakAuras ~= nil end },
            { label = "HealBot",       check = function() return HealBot ~= nil end },
            { label = "Recount",       check = function() return Recount ~= nil end },
            { label = "Atlas",         check = function() return Atlas ~= nil end },
            { label = "TerrorMeter",   check = function() return TerrorMeter ~= nil end },
            { label = "DoTimer",       check = function() return DoTimerFrame ~= nil end },
        }

        local addonIndicators = {}
        MakeLabel(leftPanel, "|cFFFFCC00Addon               Estado|r", 12, -30)
        for i, a in ipairs(addonList) do
            local nameTxt = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -52 - (i-1)*32)
            nameTxt:SetText("|cFFAAAAAA" .. a.label .. "|r")

            local statusTxt = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusTxt:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 160, -52 - (i-1)*32)
            statusTxt:SetText("|cFF888888[?]|r")
            addonIndicators[i] = { check = a.check, txt = statusTxt }
        end

        -- Panel derecho: info de BossMods activos
        local bossInfoText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bossInfoText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -35)
        bossInfoText:SetWidth(285)
        bossInfoText:SetText("|cFF666666Sin modulo de boss activo|r")

        -- Actualizar
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 2.0 or not f:IsVisible() then return end
            elapsed = 0
            for _, ind in ipairs(addonIndicators) do
                local ok, result = pcall(ind.check)
                if ok and result then
                    ind.txt:SetText("|cFF00FF00[OK]|r")
                else
                    ind.txt:SetText("|cFFFF4444[NO]|r")
                end
            end
        end)
    end

-- ============================================================================
-- TAB 12: DIAGNOSTICO (WCS_BrainDiagnostics)
-- ============================================================================
WCS_BrainDiagnostics = WCS_BrainDiagnostics or {}
function WCS_BrainDiagnostics:CreateUI()
        if _G["WCSBrainDiagnosticsTabFrame"] then return end
        local f = MakeTabFrame("WCSBrainDiagnosticsTabFrame", 1, 0.3, 0)
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFFFF4400DIAGNOSTICO DEL SISTEMA|r")

        local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFFFF4400Modulos del Sistema|r", 1, 0.3, 0)
        local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFF00FF80Acciones de Reparacion|r", 0, 1, 0.5)

        -- Lista de modulos del sistema (extraida desde WCS_BrainDiagnostics si existe)
        local moduleList = {
            "WCS_Brain", "WCS_BrainAI", "WCS_BrainCore", "WCS_BrainML",
            "WCS_BrainDQN", "WCS_BrainState", "WCS_BrainReward", "WCS_SpellDB",
            "WCS_BrainPetAI", "WCS_BrainSmartAI", "WCS_BrainIntegrations",
            "WCS_BrainMetrics", "WCS_BrainAchievements"
        }

        local indicators = {}
        for i, mod in ipairs(moduleList) do
            local row = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -30 - (i-1)*28)
            row:SetText("|cFF888888[?] " .. mod .. "|r")
            indicators[mod] = row
        end

        -- Botones de reparación
        local repairButtons = {
            { label = "Reiniciar ML", fn = function() if WCS_BrainML and WCS_BrainML.Initialize then WCS_BrainML:Initialize() end end },
            { label = "Limpiar DQN",  fn = function() if WCS_BrainDQN and WCS_BrainDQN.Reset then WCS_BrainDQN:Reset() end end },
            { label = "Reload UI",    fn = function() ReloadUI() end },
        }
        for i, btn in ipairs(repairButtons) do
            local b = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
            b:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 30, -30 - (i-1)*40)
            b:SetWidth(200)
            b:SetHeight(28)
            b:SetText(btn.label)
            local bFn = btn.fn
            b:SetScript("OnClick", bFn)
        end

        -- FPS y Memory
        local fpsText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fpsText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -160)
        fpsText:SetText("|cFFFFCC00FPS: --|r")
        local memText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        memText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -185)
        memText:SetText("|cFF00CCFF MEM: --|r")

        -- Actualizar
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 1.5 or not f:IsVisible() then return end
            elapsed = 0

            for mod, row in pairs(indicators) do
                local ok = _G[mod] ~= nil
                if ok then
                    row:SetText("|cFF00FF00[OK]|r " .. mod)
                else
                    row:SetText("|cFFFF0000[ERR]|r " .. mod)
                end
            end

            local fps = math.floor(GetFramerate() or 0)
            fpsText:SetText("|cFFFFCC00FPS: " .. fps .. "|r")
            UpdateAddOnMemoryUsage()
            local mem = math.floor(GetAddOnMemoryUsage("WCS_Brain") or 0)
            memText:SetText("|cFF00CCFFMEM: " .. mem .. " KB|r")
        end)
    end

-- ============================================================================
-- TAB 13: LOGROS (WCS_BrainAchievements)
-- ============================================================================
WCS_BrainAchievements = WCS_BrainAchievements or {}
function WCS_BrainAchievements:CreateUI()
        if _G["WCSBrainAchievementsFrame"] then return end
        local f = MakeTabFrame("WCSBrainAchievementsFrame", 1, 0.82, 0)
        if not f then return end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -15)
        title:SetText("|cFFFFD700LOGROS DEL SEQUITO|r")

        local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFFFFD700Logros Desbloqueados|r", 1, 0.82, 0)
        local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFF888888Proximos Objetivos|r", 0.5, 0.5, 0.5)

        -- Lista de logros
        local achRows = {}
        for i = 1, 14 do
            local row = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -30 - (i-1)*28)
            row:SetWidth(285)
            row:SetText("|cFF444444 " .. i .. ". -------|r")
            achRows[i] = row
        end

        -- Proximos logros
        local nextRows = {}
        for i = 1, 10 do
            local row = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 12, -35 - (i-1)*35)
            row:SetWidth(285)
            row:SetText("|cFF666666" .. i .. ". -------|r")
            nextRows[i] = row
        end

        -- Botón de recarga de logros
        local reloadBtn = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
        reloadBtn:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 15)
        reloadBtn:SetWidth(160)
        reloadBtn:SetHeight(24)
        reloadBtn:SetText("Actualizar Logros")
        reloadBtn:SetScript("OnClick", function()
            if WCS_BrainAchievements and WCS_BrainAchievements.CheckAll then
                WCS_BrainAchievements:CheckAll()
            end
        end)

        -- Rellenar logros
        local elapsed = 0
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 2.0 or not f:IsVisible() then return end
            elapsed = 0

            if WCS_BrainAchievements and WCS_BrainAchievements.GetUnlocked then
                local unlocked = WCS_BrainAchievements:GetUnlocked() or {}
                local count = table.getn(unlocked)
                for i = 1, 14 do
                    if i <= count then
                        local ach = unlocked[i]
                        achRows[i]:SetText("|cFFFFD700★ " .. (ach.name or "?") .. "|r")
                    else
                        achRows[i]:SetText("|cFF444444 " .. i .. ". ------|r")
                    end
                end
            elseif WCS_BrainAchievements and WCS_BrainAchievements.Achievements then
                local count = 0
                for id, ach in pairs(WCS_BrainAchievements.Achievements) do
                    count = count + 1
                    if count <= 14 then
                        local color = ach.unlocked and "FFD700" or "444444"
                        local star = ach.unlocked and "★ " or "  "
                        achRows[count]:SetText("|cFF" .. color .. star .. (ach.name or "?") .. "|r")
                    end
                end
            end
        end)
    end

-- ============================================================================
-- TAB 14: ROTACIONES WARLOCK (WCS_ClassRotations)
-- ============================================================================
if not WCS_ClassRotations then
    WCS_ClassRotations = {}
end
function WCS_ClassRotations:CreateUI()
    if _G["WCSBrainRotationsFrame"] then return end
    local f = MakeTabFrame("WCSBrainRotationsFrame", 0.58, 0.51, 0.79)
    if not f then return end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("|cFF9482C9ROTACIONES DEL BRUJO|r")

    local leftPanel = MakeSectionPanel(f, 15, -45, 310, 460, "|cFF9482C9Rotacion Activa|r", 0.58, 0.51, 0.79)
    local rightPanel = MakeSectionPanel(f, 345, -45, 310, 460, "|cFF00FF80Configuracion|r", 0, 1, 0.5)

    -- Rotaciones disponibles
    local rotations = {
        {name = "Destruccion", desc = "SB Spam + Inmo + CoA + CoD"},
        {name = "Affliction",  desc = "Corrupcion + CoA + SL + SB"},
        {name = "Demonologia", desc = "Demonio + SB + Maledicion"},
        {name = "Hibrida",     desc = "Auto-detectada por Cerebro"},
    }

    local rotButtons = {}
    for i, rot in ipairs(rotations) do
        local btn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -30 - (i-1)*65)
        btn:SetWidth(270)
        btn:SetHeight(40)
        btn:SetText("|cFFFFCC00" .. rot.name .. "|r\n|cFFAAAAAA" .. rot.desc .. "|r")
        local rotName = rot.name
        btn:SetScript("OnClick", function()
            if WCS_BrainAI and WCS_BrainAI.SetRotation then
                WCS_BrainAI:SetRotation(rotName)
                DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[Rotacion]|r Cambiado a: |cFFFFCC00" .. rotName .. "|r")
            end
        end)
        rotButtons[i] = btn
    end

    -- Panel derecho: ajustes de timing
    MakeLabel(rightPanel, "|cFFAAAAAATiempo de reaccion (ms):|r", 12, -35)
    local reactionSlider = CreateFrame("Slider", "WCS_BrainReactionSlider", rightPanel, "OptionsSliderTemplate")
    reactionSlider:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, -60)
    reactionSlider:SetWidth(270)
    reactionSlider:SetMinMaxValues(100, 2000)
    reactionSlider:SetValueStep(50)
    reactionSlider:SetValue(500)
    _G[reactionSlider:GetName() .. "Text"]:SetText("")
    _G[reactionSlider:GetName() .. "Low"]:SetText("100ms")
    _G[reactionSlider:GetName() .. "High"]:SetText("2000ms")

    local reactionVal = MakeLabel(rightPanel, "|cFFFFCC00500ms|r", 130, -80)
    reactionSlider:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue())
        reactionVal:SetText("|cFFFFCC00" .. v .. "ms|r")
        if WCS_Brain then
            WCS_Brain.REACTION_TIME = v / 1000
        end
    end)
end

DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS_BrainTabPanels]|r v9.0 - Paneles de UI para Tabs 5-14 cargados")
