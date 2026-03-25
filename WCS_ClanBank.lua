--[[
    WCS_ClanBank.lua
    Inventario Personal - Tracking de recursos del brujo
]]--

WCS_ClanBank = WCS_ClanBank or {}

local panel = nil
local bankData = {
    transactions = {}
}

-- Items comunes de brujo para trackear
local TRACKED_ITEMS = {
    {name = "Soul Shard", icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02"},
    {name = "Healthstone", icon = "Interface\\Icons\\INV_Stone_04"},
    {name = "Manastone", icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01"},
    {name = "Soulstone", icon = "Interface\\Icons\\Spell_Shadow_SoulGem"},
    {name = "Spellstone", icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01"},
    {name = "Firestone", icon = "Interface\\Icons\\INV_Ammo_FireTar"},
    {name = "Elixir of Shadow Power", icon = "Interface\\Icons\\INV_Potion_46"},
    {name = "Flask of Supreme Power", icon = "Interface\\Icons\\INV_Potion_41"},
}

function WCS_ClanBank:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_ClanBankFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffffaa00Inventario Personal|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Panel de oro (arriba)
    local goldBg = CreateFrame("Frame", nil, panel)
    goldBg:SetPoint("TOP", 0, -40)
    goldBg:SetWidth(760)
    goldBg:SetHeight(60)
    local goldBgTex = goldBg:CreateTexture(nil, "BACKGROUND")
    goldBgTex:SetAllPoints()
    goldBgTex:SetTexture(0, 0, 0, 0.5)
    
    self.goldText = goldBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.goldText:SetPoint("CENTER", 0, 10)
    self.goldText:SetText("Tu Oro: |cffffaa000g 0s 0c|r")
    
    -- Botón de actualizar
    local refreshBtn = CreateFrame("Button", nil, goldBg)
    refreshBtn:SetPoint("BOTTOM", 0, 5)
    refreshBtn:SetWidth(120)
    refreshBtn:SetHeight(20)
    local refreshBg = refreshBtn:CreateTexture(nil, "BACKGROUND")
    refreshBg:SetAllPoints()
    refreshBg:SetTexture(0.2, 0.5, 0.2, 0.8)
    local refreshText = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    refreshText:SetPoint("CENTER", refreshBtn, "CENTER", 0, 0)
    refreshText:SetText("Actualizar")
    refreshBtn:SetScript("OnClick", function()
        WCS_ClanBank:UpdateGold()
        WCS_ClanBank:UpdateItems()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[Inventario]|r Actualizado")
    end)
    
    -- Panel de items (izquierda)
    local itemsBg = CreateFrame("Frame", nil, panel)
    itemsBg:SetPoint("TOPLEFT", 10, -110)
    itemsBg:SetWidth(370)
    itemsBg:SetHeight(415)
    local itemsBgTex = itemsBg:CreateTexture(nil, "BACKGROUND")
    itemsBgTex:SetAllPoints()
    itemsBgTex:SetTexture(0, 0, 0, 0.5)
    
    local itemsTitle = itemsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemsTitle:SetPoint("TOP", 0, -5)
    itemsTitle:SetText("|cffFFD700Tu Inventario|r")
    
    -- Grid de items
    self.itemFrames = {}
    for i = 1, table.getn(TRACKED_ITEMS) do
        local item = TRACKED_ITEMS[i]
        local row = math.mod(i-1, 4)
        local col = math.floor((i-1) / 4)
        
        local frame = CreateFrame("Frame", nil, itemsBg)
        frame:SetPoint("TOPLEFT", 10 + row*90, -30 - col*100)
        frame:SetWidth(80)
        frame:SetHeight(90)
        
        local frameBg = frame:CreateTexture(nil, "BACKGROUND")
        frameBg:SetAllPoints()
        frameBg:SetTexture(0.1, 0.1, 0.1, 0.8)
        
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOP", 0, -5)
        icon:SetWidth(50)
        icon:SetHeight(50)
        icon:SetTexture(item.icon)
        
        local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("BOTTOM", 0, 20)
        nameText:SetWidth(75)
        nameText:SetText(item.name)
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 8)
        
        local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countText:SetPoint("BOTTOM", 0, 5)
        countText:SetText("0")
        
        frame.countText = countText
        frame.itemName = item.name
        self.itemFrames[i] = frame
    end
    
    -- Panel de historial (derecha)
    local transBg = CreateFrame("Frame", nil, panel)
    transBg:SetPoint("TOPRIGHT", -10, -110)
    transBg:SetWidth(370)
    transBg:SetHeight(415)
    local transBgTex = transBg:CreateTexture(nil, "BACKGROUND")
    transBgTex:SetAllPoints()
    transBgTex:SetTexture(0, 0, 0, 0.5)
    
    local transTitle = transBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    transTitle:SetPoint("TOP", 0, -5)
    transTitle:SetText("|cffFFD700Historial de Cambios|r")
    
    -- Scroll frame para historial
    local scrollFrame = CreateFrame("ScrollFrame", "WCS_BankScrollFrame", transBg)
    scrollFrame:SetPoint("TOPLEFT", 5, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 35)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(350)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    self.transScrollChild = scrollChild
    self.transText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.transText:SetPoint("TOPLEFT", 5, -5)
    self.transText:SetWidth(340)
    self.transText:SetJustifyH("LEFT")
    self.transText:SetText("Sin cambios registrados")
    
    -- Botón de limpiar historial
    local clearBtn = CreateFrame("Button", nil, transBg)
    clearBtn:SetPoint("BOTTOM", 0, 5)
    clearBtn:SetWidth(150)
    clearBtn:SetHeight(20)
    local clearBg = clearBtn:CreateTexture(nil, "BACKGROUND")
    clearBg:SetAllPoints()
    clearBg:SetTexture(0.5, 0.2, 0.2, 0.8)
    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearText:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
    clearText:SetText("Limpiar Historial")
    clearBtn:SetScript("OnClick", function()
        bankData.transactions = {}
        WCS_ClanBank:UpdateTransactions()
    end)
    
    self.panel = panel
    
    -- Registrar evento para actualizar automáticamente
    panel:RegisterEvent("BAG_UPDATE")
    panel:RegisterEvent("PLAYER_MONEY")
    panel:SetScript("OnEvent", function()
        if event == "BAG_UPDATE" then
            WCS_ClanBank:UpdateItems()
        elseif event == "PLAYER_MONEY" then
            WCS_ClanBank:UpdateGold()
        end
    end)
    
    -- Actualizar datos iniciales
    self:UpdateGold()
    self:UpdateItems()
    self:UpdateTransactions()
end

function WCS_ClanBank:UpdateGold()
    -- Obtener oro real del jugador
    local totalCopper = GetMoney()
    local gold = math.floor(totalCopper / 10000)
    local silver = math.floor(math.mod(totalCopper, 10000) / 100)
    local copper = math.mod(totalCopper, 100)
    
    self.goldText:SetText(string.format("Tu Oro: |cffffaa00%dg %ds %dc|r", gold, silver, copper))
end

function WCS_ClanBank:UpdateItems()
    -- Escanear inventario real del jugador
    local itemCounts = {}
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemName = GetItemInfo(link)
                if itemName then
                    local _, count = GetContainerItemInfo(bag, slot)
                    count = count or 1
                    
                    -- Buscar coincidencias parciales con items trackeados
                    for i = 1, table.getn(TRACKED_ITEMS) do
                        local trackedName = TRACKED_ITEMS[i].name
                        if string.find(itemName, trackedName) or string.find(trackedName, itemName) then
                            itemCounts[trackedName] = (itemCounts[trackedName] or 0) + count
                        end
                    end
                end
            end
        end
    end
    
    -- Actualizar frames
    for i = 1, table.getn(self.itemFrames) do
        local frame = self.itemFrames[i]
        local count = itemCounts[frame.itemName] or 0
        frame.countText:SetText(tostring(count))
        
        -- Color según cantidad
        if count == 0 then
            frame.countText:SetTextColor(0.5, 0.5, 0.5)
        elseif count < 5 then
            frame.countText:SetTextColor(1, 0, 0)
        elseif count < 20 then
            frame.countText:SetTextColor(1, 1, 0)
        else
            frame.countText:SetTextColor(0, 1, 0)
        end
    end
end

function WCS_ClanBank:UpdateTransactions()
    if table.getn(bankData.transactions) == 0 then
        self.transText:SetText("Sin cambios registrados")
        self.transScrollChild:SetHeight(1)
        return
    end
    
    local text = ""
    local maxShow = math.min(20, table.getn(bankData.transactions))
    
    for i = table.getn(bankData.transactions), table.getn(bankData.transactions) - maxShow + 1, -1 do
        local trans = bankData.transactions[i]
        if trans then
            local color = trans.type == "gain" and "|cff00ff00" or "|cffff0000"
            text = text .. string.format("%s[%s] %s|r\n", 
                color, trans.time or "--:--", trans.desc or "")
        end
    end
    
    self.transText:SetText(text)
    self.transScrollChild:SetHeight(math.max(1, maxShow * 15))
end

function WCS_ClanBank:Show()
    if self.panel then 
        self.panel:Show()
        self:UpdateGold()
        self:UpdateItems()
        self:UpdateTransactions()
    end
end

function WCS_ClanBank:Hide()
    if self.panel then self.panel:Hide() end
end

_G["WCS_ClanBank"] = WCS_ClanBank

