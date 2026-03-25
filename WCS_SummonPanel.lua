--[[
    WCS_SummonPanel.lua
    Panel de Invocaciones para "El Séquito del Terror"
    
    Sistema coordinado de summons para el clan
]]--

WCS_SummonPanel = WCS_SummonPanel or {}

local panel = nil
local summonQueue = {}
local summonHistory = {}
local summonActive = false
local currentSummonTarget = nil

function WCS_SummonPanel:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_SummonPanelFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff9370DBSistema de Invocaciones|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Panel de estado actual
    local statusPanel = CreateFrame("Frame", nil, panel)
    statusPanel:SetPoint("TOPLEFT", 10, -50)
    statusPanel:SetWidth(760)
    statusPanel:SetHeight(100)
    statusPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    statusPanel:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    statusPanel:SetBackdropBorderColor(0.5, 0.0, 0.5, 0.8)
    
    local statusTitle = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusTitle:SetPoint("TOP", 0, -10)
    statusTitle:SetText("|cff00ff00Estado Actual|r")
    
    -- Ubicación actual
    local locationText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    locationText:SetPoint("TOPLEFT", 10, -35)
    locationText:SetText("|cffffaa00Ubicación:|r Desconocida")
    panel.locationText = locationText
    
    -- Shards disponibles
    local shardsText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shardsText:SetPoint("TOPLEFT", 10, -55)
    shardsText:SetText("|cffffaa00Soul Shards:|r 0")
    panel.shardsText = shardsText
    
    -- Estado de ritual
    local ritualText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ritualText:SetPoint("TOPLEFT", 10, -75)
    ritualText:SetText("|cffffaa00Ritual de Invocación:|r No disponible")
    panel.ritualText = ritualText
    
    -- Estado del sistema
    local systemText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    systemText:SetPoint("TOPRIGHT", -10, -35)
    systemText:SetText("|cffffaa00Sistema:|r Inactivo")
    panel.systemText = systemText
    
    -- Cola de summons
    local queuePanel = CreateFrame("Frame", nil, panel)
    queuePanel:SetPoint("TOPLEFT", 10, -160)
    queuePanel:SetWidth(370)
    queuePanel:SetHeight(250)
    queuePanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    queuePanel:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    queuePanel:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.5)
    
    local queueTitle = queuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    queueTitle:SetPoint("TOP", 0, -10)
    queueTitle:SetText("|cff00ff00Cola de Summons|r")
    
    -- Scroll frame para cola (para hacer botones clickeables)
    local queueScrollFrame = CreateFrame("ScrollFrame", "WCS_SummonQueueScrollFrame", queuePanel)
    queueScrollFrame:SetPoint("TOPLEFT", 5, -30)
    queueScrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    
    local queueScrollChild = CreateFrame("Frame", nil, queueScrollFrame)
    queueScrollChild:SetWidth(350)
    queueScrollChild:SetHeight(1)
    queueScrollFrame:SetScrollChild(queueScrollChild)
    
    self.queueScrollChild = queueScrollChild
    self.queueButtons = {}
    
    -- Historial de summons
    local historyPanel = CreateFrame("Frame", nil, panel)
    historyPanel:SetPoint("TOPRIGHT", -10, -160)
    historyPanel:SetWidth(370)
    historyPanel:SetHeight(250)
    historyPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    historyPanel:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    historyPanel:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.5)
    
    local historyTitle = historyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    historyTitle:SetPoint("TOP", 0, -10)
    historyTitle:SetText("|cff00ff00Historial Reciente|r")
    
    local historyList = historyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    historyList:SetPoint("TOPLEFT", 10, -35)
    historyList:SetWidth(350)
    historyList:SetJustifyH("LEFT")
    historyList:SetText("Sin historial")
    panel.historyList = historyList
    
    -- Botones de acción
    local btnY = -420
    
    local activateBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    activateBtn:SetWidth(180)
    activateBtn:SetHeight(30)
    activateBtn:SetPoint("TOPLEFT", 10, btnY)
    activateBtn:SetText("Activar Sistema")
    activateBtn:SetScript("OnClick", function()
        WCS_SummonPanel:ToggleSystem()
    end)
    self.activateBtn = activateBtn
    
    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetWidth(180)
    clearBtn:SetHeight(30)
    clearBtn:SetPoint("LEFT", activateBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Limpiar Cola")
    clearBtn:SetScript("OnClick", function()
        summonQueue = {}
        WCS_SummonPanel:UpdateDisplay()
    end)
    
    local shareBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    shareBtn:SetWidth(180)
    shareBtn:SetHeight(30)
    shareBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    shareBtn:SetText("Compartir en Guild")
    shareBtn:SetScript("OnClick", function()
        WCS_SummonPanel:ShareToGuild()
    end)
    
    local summonBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    summonBtn:SetWidth(180)
    summonBtn:SetHeight(30)
    summonBtn:SetPoint("LEFT", shareBtn, "RIGHT", 10, 0)
    summonBtn:SetText("Summon Siguiente")
    summonBtn:SetScript("OnClick", function()
        WCS_SummonPanel:SummonNext()
    end)
    
    self.panel = panel
    
    -- Registrar eventos
    panel:RegisterEvent("CHAT_MSG_GUILD")
    panel:RegisterEvent("CHAT_MSG_RAID")
    panel:RegisterEvent("CHAT_MSG_PARTY")
    panel:RegisterEvent("BAG_UPDATE")
    panel:SetScript("OnEvent", function()
        if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_PARTY" then
            WCS_SummonPanel:OnChatMessage(arg1, arg2)
        elseif event == "BAG_UPDATE" then
            WCS_SummonPanel:UpdateDisplay()
        end
    end)
    
    self:UpdateDisplay()
end

function WCS_SummonPanel:ToggleSystem()
    summonActive = not summonActive
    
    if summonActive then
        self.activateBtn:SetText("Desactivar Sistema")
        
        -- Anunciar en todos los canales disponibles
        local msg = "[Summon] Sistema ACTIVADO. Escribe 123 en chat para pedir summon"
        
        -- Guild
        if GetGuildInfo("player") then
            SendChatMessage(msg, "GUILD")
        end
        
        -- Raid
        if GetNumRaidMembers() > 0 then
            SendChatMessage(msg, "RAID")
        end
        
        -- Party
        if GetNumPartyMembers() > 0 then
            SendChatMessage(msg, "PARTY")
        end
        
        -- Say (local)
        SendChatMessage(msg, "SAY")
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Summon]|r Sistema ACTIVADO. Detectando '123' en chat")
    else
        self.activateBtn:SetText("Activar Sistema")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Summon]|r Sistema DESACTIVADO")
    end
    
    self:UpdateDisplay()
end

function WCS_SummonPanel:OnChatMessage(message, sender)
    if not summonActive then return end
    
    -- Detectar "123" en el mensaje
    if string.find(message, "123") then
        -- Verificar que no sea el propio jugador
        local playerName = UnitName("player")
        if sender == playerName then return end
        
        -- Verificar si ya está en cola
        for i = 1, table.getn(summonQueue) do
            if summonQueue[i].name == sender then
                DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Summon]|r " .. sender .. " ya está en cola")
                return
            end
        end
        
        -- Agregar a cola
        table.insert(summonQueue, {
            name = sender,
            time = date("%H:%M")
        })
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Summon]|r " .. sender .. " agregado a cola (" .. table.getn(summonQueue) .. " en espera)")
        self:UpdateDisplay()
    end
end

function WCS_SummonPanel:SummonNext()
    if table.getn(summonQueue) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Summon]|r No hay nadie en cola")
        return
    end
    
    -- Verificar shards
    local shardCount = self:CountShards()
    if shardCount < 1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Summon]|r No tienes Soul Shards!")
        return
    end
    
    -- Verificar que tiene Ritual of Summoning
    local ritualSlot = nil
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        if spellName == "Ritual of Summoning" or spellName == "Ritual de invocación" then
            ritualSlot = i
            break
        end
        i = i + 1
    end
    
    if not ritualSlot then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Summon]|r No tienes Ritual of Summoning!")
        return
    end
    
    -- Obtener siguiente en cola
    local nextPerson = summonQueue[1]
    currentSummonTarget = nextPerson.name
    
    -- Target al jugador
    TargetByName(nextPerson.name)
    
    -- Anunciar en todos los canales disponibles
    local msg = "[Summon] Invocando a " .. nextPerson.name .. ". Ayuden con el ritual!"
    
    -- Raid (prioridad)
    if GetNumRaidMembers() > 0 then
        SendChatMessage(msg, "RAID")
    end
    
    -- Party
    if GetNumPartyMembers() > 0 then
        SendChatMessage(msg, "PARTY")
    end
    
    -- Guild
    if GetGuildInfo("player") then
        SendChatMessage(msg, "GUILD")
    end
    
    -- Say (local)
    SendChatMessage(msg, "SAY")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Summon]|r Iniciando Ritual of Summoning para " .. nextPerson.name)
    
    -- Lanzar Ritual of Summoning automáticamente
    CastSpell(ritualSlot, BOOKTYPE_SPELL)
    
    -- Remover de cola
    table.remove(summonQueue, 1)
    
    -- Agregar a historial
    table.insert(summonHistory, 1, {
        name = nextPerson.name,
        time = date("%H:%M")
    })
    
    -- Limitar historial a 20
    while table.getn(summonHistory) > 20 do
        table.remove(summonHistory)
    end
    
    self:UpdateDisplay()
end

function WCS_SummonPanel:UpdateDisplay()
    if not self.panel then return end
    
    -- Actualizar ubicación
    local zone = GetZoneText()
    local subzone = GetSubZoneText()
    local location = zone
    if subzone and subzone ~= "" then
        location = zone .. " - " .. subzone
    end
    self.panel.locationText:SetText("|cffffaa00Ubicación:|r " .. location)
    
    -- Actualizar shards
    local shardCount = self:CountShards()
    local shardColor = "|cff00ff00"
    if shardCount < 3 then
        shardColor = "|cffff0000"
    elseif shardCount < 10 then
        shardColor = "|cffffaa00"
    end
    self.panel.shardsText:SetText("|cffffaa00Soul Shards:|r " .. shardColor .. shardCount .. "|r")
    
    -- Verificar si tiene Ritual of Summoning
    local hasRitual = false
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        if spellName == "Ritual of Summoning" or spellName == "Ritual de invocación" then
            hasRitual = true
            break
        end
        i = i + 1
    end
    
    if hasRitual then
        self.panel.ritualText:SetText("|cffffaa00Ritual de Invocación:|r |cff00ff00Disponible|r")
    else
        self.panel.ritualText:SetText("|cffffaa00Ritual de Invocación:|r |cffff0000No disponible|r")
    end
    
    -- Estado del sistema
    if summonActive then
        self.panel.systemText:SetText("|cffffaa00Sistema:|r |cff00ff00ACTIVO|r")
    else
        self.panel.systemText:SetText("|cffffaa00Sistema:|r |cffff0000Inactivo|r")
    end
    
    -- Actualizar cola con botones clickeables
    -- Limpiar botones anteriores
    for i = 1, table.getn(self.queueButtons) do
        self.queueButtons[i]:Hide()
    end
    
    if table.getn(summonQueue) == 0 then
        -- Mostrar mensaje de cola vacía
        if not self.emptyQueueText then
            self.emptyQueueText = self.queueScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self.emptyQueueText:SetPoint("TOP", 0, -10)
        end
        self.emptyQueueText:SetText("|cff888888Cola vacía|r")
        self.emptyQueueText:Show()
    else
        if self.emptyQueueText then
            self.emptyQueueText:Hide()
        end
        
        -- Crear botones para cada persona en cola
        for i = 1, table.getn(summonQueue) do
            local entry = summonQueue[i]
            local btn = self.queueButtons[i]
            
            if not btn then
                btn = CreateFrame("Button", nil, self.queueScrollChild)
                btn:SetWidth(340)
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
                
                self.queueButtons[i] = btn
            end
            
            btn.playerName = entry.name
            btn.text:SetText(string.format("%d. |cff00ff00%s|r (%s)", i, entry.name, entry.time))
            
            btn:SetScript("OnClick", function()
                TargetByName(this.playerName)
                DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[Summon]|r Targeteo a " .. this.playerName)
            end)
            
            btn:SetScript("OnEnter", function()
                this.bg:SetTexture(0.3, 0.2, 0.4, 0.9)
            end)
            
            btn:SetScript("OnLeave", function()
                this.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
            end)
            
            btn:Show()
        end
        
        self.queueScrollChild:SetHeight(math.max(1, table.getn(summonQueue) * 27))
    end
    
    -- Actualizar historial
    if table.getn(summonHistory) == 0 then
        self.panel.historyList:SetText("|cff888888Sin historial|r")
    else
        local historyText = ""
        local maxHistory = math.min(10, table.getn(summonHistory))
        for i = 1, maxHistory do
            local entry = summonHistory[i]
            historyText = historyText .. entry.time .. " - " .. entry.name .. "\n"
        end
        self.panel.historyList:SetText(historyText)
    end
end

function WCS_SummonPanel:CountShards()
    local count = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    -- Buscar por nombre del item
                    local itemName = GetItemInfo(link)
                    if itemName then
                        -- Buscar "Soul Shard" o "Fragmento de alma" (español)
                        if string.find(itemName, "Soul Shard") or string.find(itemName, "Fragmento") then
                            local _, itemCount = GetContainerItemInfo(bag, slot)
                            count = count + (itemCount or 1)
                        end
                    end
                    
                    -- También buscar por ID del item (más confiable)
                    -- Soul Shard ID = 6265
                    if string.find(link, "item:6265:") then
                        local _, itemCount = GetContainerItemInfo(bag, slot)
                        count = count + (itemCount or 1)
                    end
                end
            end
        end
    end
    return count
end

function WCS_SummonPanel:ShareToGuild()
    if table.getn(summonQueue) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No hay summons en cola para compartir|r")
        return
    end
    
    -- Determinar mejor canal
    local channel = "SAY"
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        channel = "PARTY"
    elseif GetGuildInfo("player") then
        channel = "GUILD"
    end
    
    SendChatMessage("[Summon Queue] Cola actual:", channel)
    for i = 1, table.getn(summonQueue) do
        local entry = summonQueue[i]
        SendChatMessage(i .. ". " .. entry.name, channel)
    end
end

function WCS_SummonPanel:Show()
    if self.panel then
        self.panel:Show()
        self:UpdateDisplay()
    end
end

function WCS_SummonPanel:Hide()
    if self.panel then
        self.panel:Hide()
    end
end

_G["WCS_SummonPanel"] = WCS_SummonPanel

