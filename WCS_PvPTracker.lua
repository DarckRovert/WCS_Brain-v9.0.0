--[[
    WCS_PvPTracker.lua
    Tracker de PvP - Kills, Deaths, Enemigos, Duelos
]]--

WCS_PvPTracker = WCS_PvPTracker or {}

local panel = nil
local pvpData = {
    kills = 0,
    deaths = 0,
    honorableKills = 0,
    duelWins = 0,
    duelLosses = 0,
    enemies = {},
    recentKills = {}
}

function WCS_PvPTracker:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_PvPTrackerFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffff0000Tracker de PvP|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Panel de estadísticas generales (arriba)
    local statsBg = CreateFrame("Frame", nil, panel)
    statsBg:SetPoint("TOP", 0, -40)
    statsBg:SetWidth(760)
    statsBg:SetHeight(120)
    local statsBgTex = statsBg:CreateTexture(nil, "BACKGROUND")
    statsBgTex:SetAllPoints()
    statsBgTex:SetTexture(0, 0, 0, 0.5)
    
    local statsTitle = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsTitle:SetPoint("TOP", 0, -5)
    statsTitle:SetText("|cffFFD700Estadísticas Generales|r")
    
    -- Estadísticas en grid
    self.killsText = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.killsText:SetPoint("TOPLEFT", 20, -30)
    self.killsText:SetText("|cff00ff00Kills:|r 0")
    
    self.deathsText = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.deathsText:SetPoint("TOP", -100, -30)
    self.deathsText:SetText("|cffff0000Deaths:|r 0")
    
    self.kdText = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.kdText:SetPoint("TOPRIGHT", -20, -30)
    self.kdText:SetText("|cffffaa00K/D:|r 0.00")
    
    self.hkText = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hkText:SetPoint("TOPLEFT", 20, -60)
    self.hkText:SetText("|cffaa00aaHonorable Kills:|r 0")
    
    self.duelWinsText = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.duelWinsText:SetPoint("TOP", -100, -60)
    self.duelWinsText:SetText("|cff00ff00Duel Wins:|r 0")
    
    self.duelLossesText = statsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.duelLossesText:SetPoint("TOPRIGHT", -20, -60)
    self.duelLossesText:SetText("|cffff0000Duel Losses:|r 0")
    
    -- Botón de reset
    local resetBtn = CreateFrame("Button", nil, statsBg)
    resetBtn:SetPoint("BOTTOM", 0, 5)
    resetBtn:SetWidth(120)
    resetBtn:SetHeight(20)
    local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
    resetBg:SetAllPoints()
    resetBg:SetTexture(0.5, 0.2, 0.2, 0.8)
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetText("Reset Stats")
    resetBtn:SetScript("OnClick", function()
        WCS_PvPTracker:ResetStats()
    end)
    
    -- Panel de enemigos (izquierda)
    local enemiesBg = CreateFrame("Frame", nil, panel)
    enemiesBg:SetPoint("TOPLEFT", 10, -170)
    enemiesBg:SetWidth(370)
    enemiesBg:SetHeight(355)
    local enemiesBgTex = enemiesBg:CreateTexture(nil, "BACKGROUND")
    enemiesBgTex:SetAllPoints()
    enemiesBgTex:SetTexture(0, 0, 0, 0.5)
    
    local enemiesTitle = enemiesBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemiesTitle:SetPoint("TOP", 0, -5)
    enemiesTitle:SetText("|cffFFD700Enemigos Encontrados|r")
    
    -- Scroll frame para enemigos
    local scrollFrame = CreateFrame("ScrollFrame", "WCS_PvPEnemiesScrollFrame", enemiesBg)
    scrollFrame:SetPoint("TOPLEFT", 5, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(350)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    self.enemiesScrollChild = scrollChild
    self.enemyButtons = {}
    
    -- Panel de kills recientes (derecha)
    local killsBg = CreateFrame("Frame", nil, panel)
    killsBg:SetPoint("TOPRIGHT", -10, -170)
    killsBg:SetWidth(370)
    killsBg:SetHeight(355)
    local killsBgTex = killsBg:CreateTexture(nil, "BACKGROUND")
    killsBgTex:SetAllPoints()
    killsBgTex:SetTexture(0, 0, 0, 0.5)
    
    local killsTitle = killsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killsTitle:SetPoint("TOP", 0, -5)
    killsTitle:SetText("|cffFFD700Kills Recientes|r")
    
    -- Scroll frame para kills
    local killsScrollFrame = CreateFrame("ScrollFrame", "WCS_PvPKillsScrollFrame", killsBg)
    killsScrollFrame:SetPoint("TOPLEFT", 5, -25)
    killsScrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    
    local killsScrollChild = CreateFrame("Frame", nil, killsScrollFrame)
    killsScrollChild:SetWidth(350)
    killsScrollChild:SetHeight(1)
    killsScrollFrame:SetScrollChild(killsScrollChild)
    
    self.killsScrollChild = killsScrollChild
    self.killsText2 = killsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.killsText2:SetPoint("TOPLEFT", 5, -5)
    self.killsText2:SetWidth(340)
    self.killsText2:SetJustifyH("LEFT")
    self.killsText2:SetText("No hay kills recientes")
    
    self.panel = panel
    
    -- Registrar eventos
    panel:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
    panel:RegisterEvent("PLAYER_DEAD")
    panel:RegisterEvent("DUEL_FINISHED")
    panel:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    
    panel:SetScript("OnEvent", function()
        if event == "PLAYER_PVP_KILLS_CHANGED" then
            WCS_PvPTracker:OnKill()
        elseif event == "PLAYER_DEAD" then
            WCS_PvPTracker:OnDeath()
        elseif event == "DUEL_FINISHED" then
            WCS_PvPTracker:OnDuelFinished()
        elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
            WCS_PvPTracker:OnEnemyDeath(arg1)
        end
    end)
    
    self:UpdateStats()
    self:UpdateEnemies()
    self:UpdateKills()
end

function WCS_PvPTracker:OnKill()
    pvpData.kills = pvpData.kills + 1
    pvpData.honorableKills = pvpData.honorableKills + 1
    
    local target = UnitName("target")
    if target then
        table.insert(pvpData.recentKills, 1, {
            name = target,
            time = date("%H:%M"),
            class = UnitClass("target") or "Unknown"
        })
        
        -- Limitar a 20 kills recientes
        if table.getn(pvpData.recentKills) > 20 then
            table.remove(pvpData.recentKills, 21)
        end
        
        -- Agregar a lista de enemigos
        self:AddEnemy(target, UnitClass("target") or "Unknown")
    end
    
    self:UpdateStats()
    self:UpdateKills()
    self:UpdateEnemies()
end

function WCS_PvPTracker:OnDeath()
    pvpData.deaths = pvpData.deaths + 1
    self:UpdateStats()
end

function WCS_PvPTracker:OnDuelFinished()
    -- Detectar si ganamos o perdimos
    if UnitHealth("player") > 0 then
        pvpData.duelWins = pvpData.duelWins + 1
    else
        pvpData.duelLosses = pvpData.duelLosses + 1
    end
    self:UpdateStats()
end

function WCS_PvPTracker:OnEnemyDeath(msg)
    -- Parsear mensaje de muerte
    local _, _, name = string.find(msg, "(.+) dies")
    if name then
        table.insert(pvpData.recentKills, 1, {
            name = name,
            time = date("%H:%M"),
            class = "Unknown"
        })
        
        if table.getn(pvpData.recentKills) > 20 then
            table.remove(pvpData.recentKills, 21)
        end
        
        self:UpdateKills()
    end
end

function WCS_PvPTracker:AddEnemy(name, class)
    -- Buscar si ya existe
    local found = false
    for i = 1, table.getn(pvpData.enemies) do
        if pvpData.enemies[i].name == name then
            pvpData.enemies[i].encounters = pvpData.enemies[i].encounters + 1
            pvpData.enemies[i].lastSeen = date("%H:%M")
            found = true
            break
        end
    end
    
    if not found then
        table.insert(pvpData.enemies, {
            name = name,
            class = class,
            encounters = 1,
            lastSeen = date("%H:%M")
        })
    end
end

function WCS_PvPTracker:UpdateStats()
    self.killsText:SetText(string.format("|cff00ff00Kills:|r %d", pvpData.kills))
    self.deathsText:SetText(string.format("|cffff0000Deaths:|r %d", pvpData.deaths))
    
    local kd = pvpData.deaths > 0 and (pvpData.kills / pvpData.deaths) or pvpData.kills
    self.kdText:SetText(string.format("|cffffaa00K/D:|r %.2f", kd))
    
    self.hkText:SetText(string.format("|cffaa00aaHonorable Kills:|r %d", pvpData.honorableKills))
    self.duelWinsText:SetText(string.format("|cff00ff00Duel Wins:|r %d", pvpData.duelWins))
    self.duelLossesText:SetText(string.format("|cffff0000Duel Losses:|r %d", pvpData.duelLosses))
end

function WCS_PvPTracker:UpdateEnemies()
    -- Limpiar botones anteriores
    for i = 1, table.getn(self.enemyButtons) do
        self.enemyButtons[i]:Hide()
    end
    
    -- Ordenar por encounters (bubble sort)
    for i = 1, table.getn(pvpData.enemies) do
        for j = i+1, table.getn(pvpData.enemies) do
            if pvpData.enemies[j].encounters > pvpData.enemies[i].encounters then
                local temp = pvpData.enemies[i]
                pvpData.enemies[i] = pvpData.enemies[j]
                pvpData.enemies[j] = temp
            end
        end
    end
    
    -- Crear/actualizar botones
    for i = 1, table.getn(pvpData.enemies) do
        local enemy = pvpData.enemies[i]
        local btn = self.enemyButtons[i]
        
        if not btn then
            btn = CreateFrame("Frame", nil, self.enemiesScrollChild)
            btn:SetWidth(350)
            btn:SetHeight(30)
            btn:SetPoint("TOPLEFT", 5, -(i-1)*32)
            
            local btnBg = btn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            btnBg:SetTexture(0.1, 0.1, 0.1, 0.8)
            
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btnText:SetPoint("LEFT", 5, 0)
            btnText:SetJustifyH("LEFT")
            btn.text = btnText
            
            self.enemyButtons[i] = btn
        end
        
        local classColor = RAID_CLASS_COLORS[enemy.class] or {r=1, g=1, b=1}
        btn.text:SetText(string.format("|cff%02x%02x%02x%s|r - %s - Encounters: %d - Last: %s",
            classColor.r*255, classColor.g*255, classColor.b*255,
            enemy.name, enemy.class, enemy.encounters, enemy.lastSeen))
        
        btn:Show()
    end
    
    self.enemiesScrollChild:SetHeight(math.max(1, table.getn(pvpData.enemies) * 32))
end

function WCS_PvPTracker:UpdateKills()
    if table.getn(pvpData.recentKills) == 0 then
        self.killsText2:SetText("No hay kills recientes")
        self.killsScrollChild:SetHeight(1)
        return
    end
    
    local text = ""
    for i = 1, math.min(20, table.getn(pvpData.recentKills)) do
        local kill = pvpData.recentKills[i]
        local classColor = RAID_CLASS_COLORS[kill.class] or {r=1, g=1, b=1}
        text = text .. string.format("[%s] |cff%02x%02x%02x%s|r\n",
            kill.time,
            classColor.r*255, classColor.g*255, classColor.b*255,
            kill.name)
    end
    
    self.killsText2:SetText(text)
    self.killsScrollChild:SetHeight(math.max(1, math.min(20, table.getn(pvpData.recentKills)) * 15))
end

function WCS_PvPTracker:ResetStats()
    pvpData.kills = 0
    pvpData.deaths = 0
    pvpData.honorableKills = 0
    pvpData.duelWins = 0
    pvpData.duelLosses = 0
    pvpData.enemies = {}
    pvpData.recentKills = {}
    
    self:UpdateStats()
    self:UpdateEnemies()
    self:UpdateKills()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PvP Tracker]|r Estadísticas reseteadas")
end

function WCS_PvPTracker:Show()
    if self.panel then 
        self.panel:Show()
        self:UpdateStats()
        self:UpdateEnemies()
        self:UpdateKills()
    end
end

function WCS_PvPTracker:Hide()
    if self.panel then self.panel:Hide() end
end

_G["WCS_PvPTracker"] = WCS_PvPTracker

