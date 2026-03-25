--[[
    WCS_Statistics.lua
    Panel de Estadísticas para "El Séquito del Terror"
    
    Tracking de combate, DPS, hechizos usados, etc.
]]--

WCS_Statistics = WCS_Statistics or {}

local panel = nil
local combatStats = {
    totalDamage = 0,
    totalHealing = 0,
    spellsCast = {},
    combatTime = 0,
    kills = 0,
    deaths = 0,
    sessionStart = 0,
    lastCombatStart = 0,
    inCombat = false
}

function WCS_Statistics:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_StatisticsFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff9370DBEstadísticas de Combate|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Panel de resumen
    local summaryPanel = CreateFrame("Frame", nil, panel)
    summaryPanel:SetPoint("TOPLEFT", 10, -50)
    summaryPanel:SetWidth(760)
    summaryPanel:SetHeight(150)
    summaryPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    summaryPanel:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    summaryPanel:SetBackdropBorderColor(0.5, 0.0, 0.5, 0.8)
    
    local summaryTitle = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryTitle:SetPoint("TOP", 0, -10)
    summaryTitle:SetText("|cff00ff00Resumen de Sesión|r")
    
    -- Daño total
    local damageText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    damageText:SetPoint("TOPLEFT", 20, -40)
    damageText:SetText("|cffffaa00Daño Total:|r 0")
    panel.damageText = damageText
    
    -- DPS
    local dpsText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dpsText:SetPoint("TOPLEFT", 20, -65)
    dpsText:SetText("|cffffaa00DPS Promedio:|r 0")
    panel.dpsText = dpsText
    
    -- Curación
    local healingText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    healingText:SetPoint("TOPLEFT", 20, -90)
    healingText:SetText("|cffffaa00Curación Total:|r 0")
    panel.healingText = healingText
    
    -- Tiempo en combate
    local timeText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeText:SetPoint("TOPLEFT", 20, -115)
    timeText:SetText("|cffffaa00Tiempo en Combate:|r 0s")
    panel.timeText = timeText
    
    -- Kills
    local killsText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killsText:SetPoint("TOPLEFT", 400, -40)
    killsText:SetText("|cff00ff00Kills:|r 0")
    panel.killsText = killsText
    
    -- Deaths
    local deathsText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deathsText:SetPoint("TOPLEFT", 400, -65)
    deathsText:SetText("|cffff0000Deaths:|r 0")
    panel.deathsText = deathsText
    
    -- K/D Ratio
    local kdText = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    kdText:SetPoint("TOPLEFT", 400, -90)
    kdText:SetText("|cffffaa00K/D Ratio:|r 0.00")
    panel.kdText = kdText
    
    -- Panel de hechizos más usados
    local spellsPanel = CreateFrame("Frame", nil, panel)
    spellsPanel:SetPoint("TOPLEFT", 10, -220)
    spellsPanel:SetWidth(760)
    spellsPanel:SetHeight(300)
    spellsPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    spellsPanel:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    spellsPanel:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.5)
    
    local spellsTitle = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellsTitle:SetPoint("TOP", 0, -10)
    spellsTitle:SetText("|cff00ff00Hechizos Más Usados|r")
    
    -- Lista de hechizos
    local spellsList = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellsList:SetPoint("TOPLEFT", 20, -40)
    spellsList:SetWidth(720)
    spellsList:SetJustifyH("LEFT")
    spellsList:SetText("Sin datos de combate aún...")
    panel.spellsList = spellsList
    
    -- Botón de reset
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetWidth(150)
    resetBtn:SetHeight(30)
    resetBtn:SetPoint("BOTTOM", 0, 20)
    resetBtn:SetText("Reset Estadísticas")
    resetBtn:SetScript("OnClick", function()
        WCS_Statistics:ResetStats()
    end)
    
    -- Guardar referencia
    self.panel = panel
    
    -- Inicializar tiempo de sesión
    combatStats.sessionStart = time()
    
    -- Registrar eventos
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    panel:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    panel:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
    panel:RegisterEvent("PLAYER_DEAD")
    panel:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    
    panel:SetScript("OnEvent", function()
        WCS_Statistics:OnEvent(event, arg1)
    end)
    
    -- Actualizar cada segundo
    panel:SetScript("OnUpdate", function()
        if not this.lastUpdate then
            this.lastUpdate = 0
        end
        
        this.lastUpdate = this.lastUpdate + arg1
        if this.lastUpdate >= 1.0 then
            WCS_Statistics:UpdateDisplay()
            this.lastUpdate = 0
        end
    end)
end

function WCS_Statistics:OnEvent(event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        combatStats.inCombat = true
        combatStats.lastCombatStart = time()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        if combatStats.inCombat then
            local combatDuration = time() - combatStats.lastCombatStart
            combatStats.combatTime = combatStats.combatTime + combatDuration
            combatStats.inCombat = false
        end
        
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or 
           event == "CHAT_MSG_SPELL_SELF_DAMAGE" or
           event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        self:ParseDamage(arg1)
        
    elseif event == "PLAYER_DEAD" then
        combatStats.deaths = combatStats.deaths + 1
        
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        if string.find(arg1, "dies") or string.find(arg1, "muere") then
            combatStats.kills = combatStats.kills + 1
        end
    end
end

function WCS_Statistics:ParseDamage(msg)
    local _, _, damage = string.find(msg, "for (%d+)")
    if damage then
        combatStats.totalDamage = combatStats.totalDamage + tonumber(damage)
    end
    
    local _, _, spell = string.find(msg, "Your (.-) hits")
    if not spell then
        _, _, spell = string.find(msg, "Your (.-) crits")
    end
    
    if spell then
        if not combatStats.spellsCast[spell] then
            combatStats.spellsCast[spell] = {count = 0, damage = 0}
        end
        combatStats.spellsCast[spell].count = combatStats.spellsCast[spell].count + 1
        if damage then
            combatStats.spellsCast[spell].damage = combatStats.spellsCast[spell].damage + tonumber(damage)
        end
    end
end

function WCS_Statistics:UpdateDisplay()
    if not self.panel or not self.panel:IsVisible() then return end
    
    self.panel.damageText:SetText("|cffffaa00Daño Total:|r " .. combatStats.totalDamage)
    
    local dps = 0
    if combatStats.combatTime > 0 then
        dps = math.floor(combatStats.totalDamage / combatStats.combatTime)
    end
    self.panel.dpsText:SetText("|cffffaa00DPS Promedio:|r " .. dps)
    
    self.panel.healingText:SetText("|cffffaa00Curación Total:|r " .. combatStats.totalHealing)
    
    local minutes = math.floor(combatStats.combatTime / 60)
    local seconds = math.mod(combatStats.combatTime, 60)
    self.panel.timeText:SetText("|cffffaa00Tiempo en Combate:|r " .. minutes .. "m " .. seconds .. "s")
    
    self.panel.killsText:SetText("|cff00ff00Kills:|r " .. combatStats.kills)
    self.panel.deathsText:SetText("|cffff0000Deaths:|r " .. combatStats.deaths)
    
    local kd = 0
    if combatStats.deaths > 0 then
        kd = combatStats.kills / combatStats.deaths
    else
        kd = combatStats.kills
    end
    self.panel.kdText:SetText(string.format("|cffffaa00K/D Ratio:|r %.2f", kd))
    
    local spellList = {}
    for spell, data in combatStats.spellsCast do
        table.insert(spellList, {name = spell, count = data.count, damage = data.damage})
    end
    
    table.sort(spellList, function(a, b) return a.damage > b.damage end)
    
    local spellText = ""
    for i = 1, math.min(10, table.getn(spellList)) do
        local spell = spellList[i]
        local avgDmg = 0
        if spell.count > 0 then
            avgDmg = math.floor(spell.damage / spell.count)
        end
        spellText = spellText .. string.format("%d. %s: %d usos, %d daño (avg: %d)\n", 
            i, spell.name, spell.count, spell.damage, avgDmg)
    end
    
    if spellText == "" then
        spellText = "Sin datos de combate aún..."
    end
    
    self.panel.spellsList:SetText(spellText)
end

function WCS_Statistics:ResetStats()
    combatStats.totalDamage = 0
    combatStats.totalHealing = 0
    combatStats.spellsCast = {}
    combatStats.combatTime = 0
    combatStats.kills = 0
    combatStats.deaths = 0
    combatStats.sessionStart = time()
    combatStats.inCombat = false
    
    self:UpdateDisplay()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WCS Statistics]|r Estadísticas reseteadas")
end

function WCS_Statistics:Show()
    if self.panel then
        self.panel:Show()
        self:UpdateDisplay()
    end
end

function WCS_Statistics:Hide()
    if self.panel then
        self.panel:Hide()
    end
end

_G["WCS_Statistics"] = WCS_Statistics

