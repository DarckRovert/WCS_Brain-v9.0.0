--[[
    WCS_RaidManager.lua
    Gestor de Raid - Asignaciones, healthstones, soulstones
]]--

WCS_RaidManager = WCS_RaidManager or {}

local panel = nil
local raidMembers = {}
local assignments = {}
local distributionActive = false
local tradeQueue = {}

function WCS_RaidManager:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_RaidManagerFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffff0000Gestor de Raid|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Panel de miembros de raid (izquierda)
    local membersBg = CreateFrame("Frame", nil, panel)
    membersBg:SetPoint("TOPLEFT", 10, -40)
    membersBg:SetWidth(360)
    membersBg:SetHeight(485)
    local membersBgTex = membersBg:CreateTexture(nil, "BACKGROUND")
    membersBgTex:SetAllPoints()
    membersBgTex:SetTexture(0, 0, 0, 0.5)
    
    local membersTitle = membersBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    membersTitle:SetPoint("TOP", 0, -5)
    membersTitle:SetText("|cffFFD700Miembros de Raid|r")
    
    -- Scroll frame para miembros
    local scrollFrame = CreateFrame("ScrollFrame", "WCS_RaidScrollFrame", membersBg)
    scrollFrame:SetPoint("TOPLEFT", 5, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(340)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    self.memberScrollChild = scrollChild
    self.memberButtons = {}
    
    -- Panel de asignaciones (derecha arriba)
    local assignBg = CreateFrame("Frame", nil, panel)
    assignBg:SetPoint("TOPRIGHT", -10, -40)
    assignBg:SetWidth(400)
    assignBg:SetHeight(230)
    local assignBgTex = assignBg:CreateTexture(nil, "BACKGROUND")
    assignBgTex:SetAllPoints()
    assignBgTex:SetTexture(0, 0, 0, 0.5)
    
    local assignTitle = assignBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    assignTitle:SetPoint("TOP", 0, -5)
    assignTitle:SetText("|cffFFD700Asignaciones de Soulstone|r")
    
    self.assignText = assignBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.assignText:SetPoint("TOPLEFT", 10, -30)
    self.assignText:SetWidth(380)
    self.assignText:SetJustifyH("LEFT")
    self.assignText:SetText("Tanques y Healers prioritarios:\n\nNo hay asignaciones activas")
    
    -- Botones de asignación
    local assignTankBtn = CreateFrame("Button", nil, assignBg)
    assignTankBtn:SetPoint("BOTTOMLEFT", assignBg, "BOTTOMLEFT", 10, 10)
    assignTankBtn:SetWidth(120)
    assignTankBtn:SetHeight(25)
    local assignTankBg = assignTankBtn:CreateTexture(nil, "BACKGROUND")
    assignTankBg:SetAllPoints()
    assignTankBg:SetTexture(0.2, 0.5, 0.2, 0.8)
    local assignTankText = assignTankBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    assignTankText:SetPoint("CENTER", assignTankBtn, "CENTER", 0, 0)
    assignTankText:SetText("Asignar Tanks")
    assignTankBtn:SetScript("OnClick", function()
        WCS_RaidManager:AssignSoulstones("TANK")
    end)
    
    local assignHealBtn = CreateFrame("Button", nil, assignBg)
    assignHealBtn:SetPoint("BOTTOM", assignBg, "BOTTOM", 0, 10)
    assignHealBtn:SetWidth(120)
    assignHealBtn:SetHeight(25)
    local assignHealBg = assignHealBtn:CreateTexture(nil, "BACKGROUND")
    assignHealBg:SetAllPoints()
    assignHealBg:SetTexture(0.2, 0.5, 0.2, 0.8)
    local assignHealText = assignHealBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    assignHealText:SetPoint("CENTER", assignHealBtn, "CENTER", 0, 0)
    assignHealText:SetText("Asignar Healers")
    assignHealBtn:SetScript("OnClick", function()
        WCS_RaidManager:AssignSoulstones("HEALER")
    end)
    
    local clearBtn = CreateFrame("Button", nil, assignBg)
    clearBtn:SetPoint("BOTTOMRIGHT", assignBg, "BOTTOMRIGHT", -10, 10)
    clearBtn:SetWidth(120)
    clearBtn:SetHeight(25)
    local clearBg = clearBtn:CreateTexture(nil, "BACKGROUND")
    clearBg:SetAllPoints()
    clearBg:SetTexture(0.5, 0.2, 0.2, 0.8)
    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearText:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
    clearText:SetText("Limpiar")
    clearBtn:SetScript("OnClick", function()
        assignments = {}
        WCS_RaidManager:UpdateAssignments()
    end)
    
    -- Panel de distribución de healthstones (derecha abajo)
    local healthBg = CreateFrame("Frame", nil, panel)
    healthBg:SetPoint("TOPRIGHT", -10, -280)
    healthBg:SetWidth(400)
    healthBg:SetHeight(245)
    local healthBgTex = healthBg:CreateTexture(nil, "BACKGROUND")
    healthBgTex:SetAllPoints()
    healthBgTex:SetTexture(0, 0, 0, 0.5)
    
    local healthTitle = healthBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    healthTitle:SetPoint("TOP", 0, -5)
    healthTitle:SetText("|cffFFD700Distribución de Healthstones|r")
    
    self.healthText = healthBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.healthText:SetPoint("TOPLEFT", 10, -30)
    self.healthText:SetWidth(380)
    self.healthText:SetJustifyH("LEFT")
    
    -- Botones de distribución
    local distributeBtn = CreateFrame("Button", nil, healthBg)
    distributeBtn:SetPoint("BOTTOM", healthBg, "BOTTOM", 0, 10)
    distributeBtn:SetWidth(180)
    distributeBtn:SetHeight(25)
    local distributeBg = distributeBtn:CreateTexture(nil, "BACKGROUND")
    distributeBg:SetAllPoints()
    distributeBg:SetTexture(0.2, 0.5, 0.2, 0.8)
    local distributeText = distributeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    distributeText:SetPoint("CENTER", distributeBtn, "CENTER", 0, 0)
    distributeText:SetText("Distribuir Healthstones")
    distributeBtn:SetScript("OnClick", function()
        WCS_RaidManager:DistributeHealthstones()
    end)
    
    self.panel = panel
    
    -- Registrar eventos
    panel:RegisterEvent("RAID_ROSTER_UPDATE")
    panel:RegisterEvent("PARTY_MEMBERS_CHANGED")
    panel:RegisterEvent("CHAT_MSG_WHISPER")
    panel:RegisterEvent("TRADE_SHOW")
    panel:RegisterEvent("TRADE_ACCEPT_UPDATE")
    panel:SetScript("OnEvent", function()
        if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
            WCS_RaidManager:UpdateRaidMembers()
        elseif event == "CHAT_MSG_WHISPER" then
            WCS_RaidManager:OnWhisper(arg1, arg2)
        elseif event == "TRADE_SHOW" then
            WCS_RaidManager:OnTradeShow()
        elseif event == "TRADE_ACCEPT_UPDATE" then
            WCS_RaidManager:OnTradeAccept()
        end
    end)
    
    -- Actualización periódica
    panel:SetScript("OnUpdate", function()
        if not this.lastUpdate then this.lastUpdate = 0 end
        this.lastUpdate = this.lastUpdate + arg1
        if this.lastUpdate >= 2.0 then
            this.lastUpdate = 0
            WCS_RaidManager:UpdateHealthstoneInfo()
        end
        
        -- Procesar siguiente trade si hay cola
        if this.nextTradeTime and GetTime() >= this.nextTradeTime then
            this.nextTradeTime = nil
            WCS_RaidManager:ProcessNextTrade()
        end
    end)
    
    self:UpdateRaidMembers()
    self:UpdateHealthstoneInfo()
end

function WCS_RaidManager:UpdateRaidMembers()
    raidMembers = {}
    
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, rank, subgroup, level, class = GetRaidRosterInfo(i)
            if name then
                table.insert(raidMembers, {
                    name = name,
                    class = class or "Unknown",
                    subgroup = subgroup or 1,
                    level = level or 60
                })
            end
        end
    else
        -- Modo party
        local numParty = GetNumPartyMembers()
        if numParty > 0 then
            for i = 1, numParty do
                local name = UnitName("party"..i)
                if name then
                    table.insert(raidMembers, {
                        name = name,
                        class = UnitClass("party"..i) or "Unknown",
                        subgroup = 1,
                        level = UnitLevel("party"..i) or 60
                    })
                end
            end
        end
    end
    
    self:UpdateMemberList()
end

function WCS_RaidManager:UpdateMemberList()
    -- Limpiar botones anteriores
    for i = 1, table.getn(self.memberButtons) do
        self.memberButtons[i]:Hide()
    end
    
    -- Crear/actualizar botones
    for i = 1, table.getn(raidMembers) do
        local member = raidMembers[i]
        local btn = self.memberButtons[i]
        
        if not btn then
            btn = CreateFrame("Button", nil, self.memberScrollChild)
            btn:SetWidth(330)
            btn:SetHeight(25)
            btn:SetPoint("TOPLEFT", 5, -(i-1)*27)
            
            local btnBg = btn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            btnBg:SetTexture(0.1, 0.1, 0.1, 0.8)
            btn.bg = btnBg
            
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btnText:SetPoint("LEFT", 5, 0)
            btnText:SetJustifyH("LEFT")
            btn.text = btnText
            
            self.memberButtons[i] = btn
        end
        
        local classColor = RAID_CLASS_COLORS[member.class] or {r=1, g=1, b=1}
        btn.text:SetText(string.format("|cff%02x%02x%02x%s|r - Grupo %d", 
            classColor.r*255, classColor.g*255, classColor.b*255,
            member.name, member.subgroup))
        
        btn:Show()
    end
    
    self.memberScrollChild:SetHeight(math.max(1, table.getn(raidMembers) * 27))
end

function WCS_RaidManager:AssignSoulstones(role)
    -- Actualizar lista de miembros primero
    self:UpdateRaidMembers()
    
    assignments = {}
    
    -- Priorizar por clase según rol
    local priority = {}
    if role == "TANK" then
        priority = {Warrior = 1, Druid = 2, Paladin = 3}
    else -- HEALER
        priority = {Priest = 1, Druid = 2, Paladin = 3, Shaman = 4}
    end
    
    for i = 1, table.getn(raidMembers) do
        local member = raidMembers[i]
        if priority[member.class] then
            table.insert(assignments, {
                name = member.name,
                class = member.class,
                priority = priority[member.class]
            })
        end
    end
    
    -- Ordenar por prioridad (bubble sort para Lua 5.0)
    for i = 1, table.getn(assignments) do
        for j = i+1, table.getn(assignments) do
            if assignments[j].priority < assignments[i].priority then
                local temp = assignments[i]
                assignments[i] = assignments[j]
                assignments[j] = temp
            end
        end
    end
    
    self:UpdateAssignments()
end

function WCS_RaidManager:UpdateAssignments()
    if table.getn(assignments) == 0 then
        self.assignText:SetText("Tanques y Healers prioritarios:\n\nNo hay asignaciones activas")
        return
    end
    
    local text = "Asignaciones de Soulstone:\n\n"
    for i = 1, math.min(5, table.getn(assignments)) do
        local assign = assignments[i]
        local classColor = RAID_CLASS_COLORS[assign.class] or {r=1, g=1, b=1}
        text = text .. string.format("%d. |cff%02x%02x%02x%s|r (%s)\n",
            i,
            classColor.r*255, classColor.g*255, classColor.b*255,
            assign.name, assign.class)
    end
    
    self.assignText:SetText(text)
end

function WCS_RaidManager:UpdateHealthstoneInfo()
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    local total = numRaid > 0 and numRaid or (numParty > 0 and numParty + 1 or 1)
    
    -- Contar healthstones en inventario
    local healthstones = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "Healthstone") then
                local _, count = GetContainerItemInfo(bag, slot)
                healthstones = healthstones + (count or 1)
            end
        end
    end
    
    local text = string.format(
        "Miembros en raid/party: %d\n" ..
        "Healthstones disponibles: %d\n" ..
        "Healthstones necesarias: %d\n\n" ..
        "%s",
        total,
        healthstones,
        total,
        healthstones >= total and "|cff00ff00Suficientes healthstones|r" or "|cffff0000Faltan healthstones|r"
    )
    
    self.healthText:SetText(text)
end

function WCS_RaidManager:DistributeHealthstones()
    if distributionActive then
        distributionActive = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r Distribución de healthstones DESACTIVADA")
        return
    end
    
    distributionActive = true
    tradeQueue = {}
    
    -- Obtener nombre del jugador
    local playerName = UnitName("player")
    
    -- Anunciar en raid
    SendChatMessage("Healthstones disponibles! Susurrame (whisper) !hs para recibir una", "RAID")
    SendChatMessage("Ejemplo: /w " .. playerName .. " !hs", "RAID")
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r Distribución ACTIVADA. Los miembros deben susurrarte !hs")
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r Presiona el botón nuevamente para DESACTIVAR")
end

function WCS_RaidManager:OnWhisper(message, sender)
    if not distributionActive then return end
    
    -- Detectar comando !hs
    local msg = string.lower(message)
    if msg == "!hs" or msg == "hs" or string.find(msg, "!hs") then
        -- Verificar que el sender esté en el raid
        local inRaid = false
        for i = 1, table.getn(raidMembers) do
            if raidMembers[i].name == sender then
                inRaid = true
                break
            end
        end
        
        if inRaid then
            -- Verificar si ya está en cola
            local alreadyQueued = false
            for i = 1, table.getn(tradeQueue) do
                if tradeQueue[i] == sender then
                    alreadyQueued = true
                    break
                end
            end
            
            if not alreadyQueued then
                table.insert(tradeQueue, sender)
                DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r " .. sender .. " agregado a cola (" .. table.getn(tradeQueue) .. " en espera)")
                
                -- Si no hay trade activo, iniciar trade
                if table.getn(tradeQueue) == 1 then
                    WCS_RaidManager:ProcessNextTrade()
                end
            end
        end
    end
end

function WCS_RaidManager:ProcessNextTrade()
    if table.getn(tradeQueue) == 0 then return end
    
    local nextPlayer = tradeQueue[1]
    
    -- Iniciar trade
    InitiateTrade(nextPlayer)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r Iniciando trade con " .. nextPlayer)
end

function WCS_RaidManager:OnTradeShow()
    if not distributionActive then return end
    if table.getn(tradeQueue) == 0 then return end
    
    -- Buscar healthstone en inventario
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "Healthstone") then
                -- Colocar healthstone en trade
                PickupContainerItem(bag, slot)
                ClickTradeButton(1)
                DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r Healthstone colocada. Acepta el trade.")
                return
            end
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Raid Manager]|r No tienes healthstones!")
end

function WCS_RaidManager:OnTradeAccept()
    if not distributionActive then return end
    if table.getn(tradeQueue) == 0 then return end
    
    -- Remover de cola
    local player = table.remove(tradeQueue, 1)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Raid Manager]|r Trade completado con " .. player .. ". Quedan " .. table.getn(tradeQueue))
    
    -- Procesar siguiente en cola después de un pequeño delay
    if table.getn(tradeQueue) > 0 then
        -- Esperar 1 segundo antes del siguiente trade
        this.nextTradeTime = GetTime() + 1.0
    end
end

function WCS_RaidManager:Show()
    if self.panel then 
        self.panel:Show()
        self:UpdateRaidMembers()
        self:UpdateHealthstoneInfo()
    end
end

function WCS_RaidManager:Hide()
    if self.panel then self.panel:Hide() end
end

_G["WCS_RaidManager"] = WCS_RaidManager

