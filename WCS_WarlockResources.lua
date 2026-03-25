--[[
    WCS_WarlockResources.lua
    Panel de Recursos de Brujo para "El Séquito del Terror"
    
    Tracking de Soul Shards, Healthstones, Soulstones, etc.
]]--

WCS_WarlockResources = WCS_WarlockResources or {}

local panel = nil
local updateTimer = 0
local UPDATE_INTERVAL = 1.0

function WCS_WarlockResources:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_WarlockResourcesFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff9370DBRecursos de Brujo|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Fila 1: Soul Shards y Healthstones
    local shardPanel = self:CreateResourcePanel(panel, "Soul Shards", 10, -50, "Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
    panel.shardPanel = shardPanel
    
    local healthPanel = self:CreateResourcePanel(panel, "Healthstones", 400, -50, "Interface\\Icons\\INV_Stone_04", "Crear", function()
        WCS_WarlockResources:CastHighestRank("Create Healthstone")
    end)
    panel.healthPanel = healthPanel
    
    -- Fila 2: Soulstones y Firestones
    local soulPanel = self:CreateResourcePanel(panel, "Soulstones", 10, -160, "Interface\\Icons\\Spell_Shadow_SoulGem", "Crear", function()
        WCS_WarlockResources:CastHighestRank("Create Soulstone")
    end)
    panel.soulPanel = soulPanel
    
    local firePanel = self:CreateResourcePanel(panel, "Firestones", 400, -160, "Interface\\Icons\\INV_Ammo_FireTar", "Crear", function()
        WCS_WarlockResources:CastHighestRank("Create Firestone")
    end)
    panel.firePanel = firePanel
    
    -- Fila 3: Spellstones y Felstones
    local spellPanel = self:CreateResourcePanel(panel, "Spellstones", 10, -270, "Interface\\Icons\\INV_Misc_Gem_Sapphire_01", "Crear", function()
        WCS_WarlockResources:CastHighestRank("Create Spellstone")
    end)
    panel.spellPanel = spellPanel
    
    local felPanel = self:CreateResourcePanel(panel, "Felstones", 400, -270, "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01", "Crear", function()
        CastSpellByName("Create Felstone")
    end)
    panel.felPanel = felPanel
    
    -- Información de mascota (más compacta)
    local petPanel = CreateFrame("Frame", nil, panel)
    petPanel:SetPoint("TOPLEFT", 10, -380)
    petPanel:SetWidth(760)
    petPanel:SetHeight(70)
    petPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    petPanel:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    petPanel:SetBackdropBorderColor(0.5, 0.0, 0.5, 0.8)
    
    local petTitle = petPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petTitle:SetPoint("TOP", 0, -8)
    petTitle:SetText("|cff9370DBMascota Actual|r")
    
    local petInfo = petPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petInfo:SetPoint("CENTER", 0, -5)
    petInfo:SetText("Sin mascota invocada")
    panel.petInfo = petInfo
    
    -- Los botones ahora están dentro de cada panel
    
    -- OnUpdate para actualizar recursos
    panel:SetScript("OnUpdate", function()
        updateTimer = updateTimer + arg1
        if updateTimer >= UPDATE_INTERVAL then
            updateTimer = 0
            WCS_WarlockResources:UpdateResources()
        end
    end)
    
    self.panel = panel
    self:UpdateResources()
end

function WCS_WarlockResources:CreateResourcePanel(parent, title, x, y, icon, buttonText, buttonCallback)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetWidth(370)
    frame:SetHeight(100)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    frame:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.5)
    
    -- Icono
    local iconTexture = frame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetWidth(32)
    iconTexture:SetHeight(32)
    iconTexture:SetPoint("TOPLEFT", 8, -8)
    iconTexture:SetTexture(icon)
    
    -- Título
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", iconTexture, "RIGHT", 8, 0)
    titleText:SetText("|cff00ff00" .. title .. "|r")
    
    -- Contador
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countText:SetPoint("TOPLEFT", 10, -45)
    countText:SetText("|cffffaa000|r")
    countText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    frame.countText = countText
    
    -- Información adicional
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 10, -70)
    infoText:SetText("")
    frame.infoText = infoText
    
    -- Botón de creación (si se proporciona)
    if buttonText and buttonCallback then
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetWidth(100)
        btn:SetHeight(22)
        btn:SetPoint("BOTTOMRIGHT", -8, 8)
        btn:SetText(buttonText)
        btn:SetScript("OnClick", buttonCallback)
        frame.createButton = btn
    end
    
    return frame
end

function WCS_WarlockResources:UpdateResources()
    if not self.panel then return end
    
    -- Contar Soul Shards
    local shardCount = self:CountItem("Soul Shard")
    self.panel.shardPanel.countText:SetText("|cffffaa00" .. shardCount .. "|r / 32")
    if shardCount < 5 then
        self.panel.shardPanel.infoText:SetText("|cffff0000¡Necesitas más shards!|r")
    elseif shardCount > 25 then
        self.panel.shardPanel.infoText:SetText("|cff00ff00Inventario lleno|r")
    else
        self.panel.shardPanel.infoText:SetText("|cff00ff00Stock adecuado|r")
    end
    
    -- Contar Healthstones
    local healthCount = self:CountItem("Healthstone")
    self.panel.healthPanel.countText:SetText("|cffffaa00" .. healthCount .. "|r")
    self.panel.healthPanel.infoText:SetText("En inventario")
    
    -- Contar Soulstones
    local soulCount = self:CountItem("Soulstone")
    self.panel.soulPanel.countText:SetText("|cffffaa00" .. soulCount .. "|r")
    self.panel.soulPanel.infoText:SetText("En inventario")
    
    -- Contar Firestones
    local fireCount = self:CountItem("Firestone")
    self.panel.firePanel.countText:SetText("|cffffaa00" .. fireCount .. "|r")
    self.panel.firePanel.infoText:SetText("En inventario")
    
    -- Contar Spellstones
    local spellCount = self:CountItem("Spellstone")
    self.panel.spellPanel.countText:SetText("|cffffaa00" .. spellCount .. "|r")
    self.panel.spellPanel.infoText:SetText("En inventario")
    
    -- Contar Felstones
    local felCount = self:CountItem("Felstone")
    self.panel.felPanel.countText:SetText("|cffffaa00" .. felCount .. "|r")
    self.panel.felPanel.infoText:SetText("En inventario")
    
    -- Actualizar info de mascota
    if UnitExists("pet") then
        local petName = UnitName("pet")
        local petHealth = UnitHealth("pet")
        local petHealthMax = UnitHealthMax("pet")
        local petMana = UnitMana("pet")
        local petManaMax = UnitManaMax("pet")
        local petLevel = UnitLevel("pet")
        
        local healthPercent = math.floor((petHealth / petHealthMax) * 100)
        local manaPercent = math.floor((petMana / petManaMax) * 100)
        
        local infoStr = string.format(
            "|cff9370DB%s|r (Nv %d)\nHP: %d/%d (%d%%) | Mana: %d/%d (%d%%)",
            petName, petLevel,
            petHealth, petHealthMax, healthPercent,
            petMana, petManaMax, manaPercent
        )
        
        self.panel.petInfo:SetText(infoStr)
    else
        self.panel.petInfo:SetText("|cff888888Sin mascota invocada|r")
    end
end

-- IDs de items de brujo
local ITEM_IDS = {
    ["Soul Shard"] = 6265,
    ["Healthstone"] = {5512, 19004, 19005, 5511, 5509, 5510}, -- Minor a Major
    ["Soulstone"] = {5232, 16892, 16893, 16895, 16896}, -- Minor a Major
    ["Firestone"] = {1254, 13699, 13700, 13701}, -- Lesser a Major
    ["Spellstone"] = {5522, 13602, 13603} -- Lesser a Major
}

-- Función para castear el rango más alto de un hechizo
function WCS_WarlockResources:CastHighestRank(spellBaseName)
    local highestRank = -1  -- Empezar en -1 para detectar hechizos sin rango
    local highestSlot = nil
    
    -- Buscar en el spellbook
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        
        -- Verificar si el nombre contiene el hechizo que buscamos
        if string.find(spellName, spellBaseName) then
            local rank = 0
            if spellRank then
                local _, _, rankNum = string.find(spellRank, "(%d+)")
                if rankNum then
                    rank = tonumber(rankNum)
                end
            end
            
            -- Guardar el de mayor rango
            if rank > highestRank then
                highestRank = rank
                highestSlot = i
            end
        end
        
        i = i + 1
    end
    
    -- Castear el rango más alto encontrado
    if highestSlot then
        CastSpell(highestSlot, BOOKTYPE_SPELL)
        if highestRank > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("Casteando " .. spellBaseName .. " (Rank " .. highestRank .. ")", 0.2, 1.0, 0.2)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Casteando " .. spellBaseName, 0.2, 1.0, 0.2)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("No tienes " .. spellBaseName .. " aprendido", 1.0, 0.2, 0.2)
    end
end

function WCS_WarlockResources:CountItem(itemName)
    local count = 0
    local itemIDs = ITEM_IDS[itemName]
    
    if not itemIDs then return 0 end
    
    -- Convertir a tabla si es un solo ID
    if type(itemIDs) == "number" then
        itemIDs = {itemIDs}
    end
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Extraer itemID del link
                local _, _, itemID = string.find(link, "item:(%d+)")
                if itemID then
                    itemID = tonumber(itemID)
                    -- Verificar si el itemID está en nuestra lista
                    for i = 1, table.getn(itemIDs) do
                        if itemIDs[i] == itemID then
                            local _, itemCount = GetContainerItemInfo(bag, slot)
                            count = count + (itemCount or 1)
                            break
                        end
                    end
                end
            end
        end
    end
    return count
end

function WCS_WarlockResources:Show()
    if self.panel then
        self.panel:Show()
        self:UpdateResources()
    end
end

function WCS_WarlockResources:Hide()
    if self.panel then
        self.panel:Hide()
    end
end

_G["WCS_WarlockResources"] = WCS_WarlockResources

