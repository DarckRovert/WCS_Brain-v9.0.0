--[[
    WCS_ClanPanel.lua
    Panel de Miembros del Clan para "El Séquito del Terror"
    
    Muestra lista de miembros, estado online/offline, rangos, etc.
]]--

WCS_ClanPanel = WCS_ClanPanel or {}

local panel = nil
local memberList = {}
local scrollFrame = nil

function WCS_ClanPanel:Initialize()
    if panel then return end
    
    -- Crear panel principal
    panel = CreateFrame("Frame", "WCS_ClanPanelFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff00ff00Miembros del Séquito|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Estadísticas rápidas
    local statsFrame = CreateFrame("Frame", nil, panel)
    statsFrame:SetPoint("TOPLEFT", 10, -40)
    statsFrame:SetWidth(760)
    statsFrame:SetHeight(60)
    statsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    statsFrame:SetBackdropColor(0.1, 0.0, 0.15, 0.8)
    statsFrame:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.5)
    
    -- Total de miembros
    local totalText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalText:SetPoint("TOPLEFT", 10, -10)
    totalText:SetText("|cff00ff00Total:|r 0")
    panel.totalText = totalText
    
    -- Miembros online
    local onlineText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    onlineText:SetPoint("TOPLEFT", 10, -30)
    onlineText:SetText("|cff00ff00Online:|r 0")
    panel.onlineText = onlineText
    
    -- Nivel promedio
    local avgLevelText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    avgLevelText:SetPoint("TOPLEFT", 200, -10)
    avgLevelText:SetText("|cff00ff00Nivel Promedio:|r 0")
    panel.avgLevelText = avgLevelText
    
    -- Brujos en el clan
    local warlocksText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warlocksText:SetPoint("TOPLEFT", 200, -30)
    warlocksText:SetText("|cff00ff00Brujos:|r 0")
    panel.warlocksText = warlocksText
    
    -- Botón de actualizar
    local refreshBtn = CreateFrame("Button", nil, statsFrame, "UIPanelButtonTemplate")
    refreshBtn:SetWidth(100)
    refreshBtn:SetHeight(25)
    refreshBtn:SetPoint("RIGHT", -10, 0)
    refreshBtn:SetText("Actualizar")
    refreshBtn:SetScript("OnClick", function()
        WCS_ClanPanel:UpdateMemberList()
    end)
    
    -- Crear scroll frame para lista de miembros
    scrollFrame = CreateFrame("ScrollFrame", "WCS_ClanPanel_ScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -110)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Contenido del scroll
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(730)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild
    
    -- Guardar referencia
    self.panel = panel
    
    -- Actualizar lista inicial
    self:UpdateMemberList()
end

function WCS_ClanPanel:UpdateMemberList()
    if not self.panel then return end
    
    -- Limpiar lista anterior
    if self.panel.scrollChild then
        -- En Lua 5.0, simplemente recreamos el scroll child
        local oldChild = self.panel.scrollChild
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(730)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        self.panel.scrollChild = scrollChild
    end
    
    -- Obtener información del clan
    GuildRoster()
    local numTotal, numOnline = GetNumGuildMembers()
    
    -- Asegurar que los valores no sean nil
    numTotal = numTotal or 0
    numOnline = numOnline or 0
    
    if numTotal == 0 then
        -- No hay clan o no hay miembros
        local noGuildText = self.panel.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noGuildText:SetPoint("TOP", 0, -20)
        noGuildText:SetText("|cffff0000No estás en un clan o el roster no está cargado.|r")
        return
    end
    
    -- Actualizar estadísticas
    self.panel.totalText:SetText("|cff00ff00Total:|r " .. numTotal)
    self.panel.onlineText:SetText("|cff00ff00Online:|r " .. numOnline)
    
    -- Calcular nivel promedio y contar brujos
    local totalLevel = 0
    local numWarlocks = 0
    local yOffset = -5
    
    memberList = {}
    
    for i = 1, numTotal do
        local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
        
        if name then
            level = level or 1
            class = class or "Unknown"
            rank = rank or "Member"
            zone = zone or "Unknown"
            online = online or false
            
            totalLevel = totalLevel + level
            if class == "Warlock" or class == "WARLOCK" or class == "Brujo" then
                numWarlocks = numWarlocks + 1
            end
            
            table.insert(memberList, {
                name = name,
                rank = rank,
                level = level,
                class = class,
                zone = zone,
                online = online
            })
        end
    end
    
    local avgLevel = math.floor(totalLevel / numTotal)
    self.panel.avgLevelText:SetText("|cff00ff00Nivel Promedio:|r " .. avgLevel)
    self.panel.warlocksText:SetText("|cff00ff00Brujos:|r " .. numWarlocks)
    
    -- Ordenar por online primero, luego por nivel
    table.sort(memberList, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        return a.level > b.level
    end)
    
    -- Crear entradas de miembros
    for i = 1, table.getn(memberList) do
        local member = memberList[i]
        local entry = CreateFrame("Frame", nil, self.panel.scrollChild)
        entry:SetWidth(720)
        entry:SetHeight(30)
        entry:SetPoint("TOPLEFT", 5, yOffset)
        
        -- Fondo alternado
        local bg = entry:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(entry)
        if math.mod(i, 2) == 0 then
            bg:SetTexture(0.1, 0.1, 0.1, 0.5)
        else
            bg:SetTexture(0.15, 0.15, 0.15, 0.5)
        end
        
        -- Color según estado online
        local nameColor = member.online and "|cff00ff00" or "|cff888888"
        
        -- Nombre
        local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", 10, 0)
        nameText:SetText(nameColor .. member.name .. "|r")
        
        -- Nivel
        local levelText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelText:SetPoint("LEFT", 200, 0)
        levelText:SetText(nameColor .. "Nv " .. member.level .. "|r")
        
        -- Clase
        local classText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        classText:SetPoint("LEFT", 270, 0)
        local classColor = RAID_CLASS_COLORS[member.class] or {r=1, g=1, b=1}
        classText:SetTextColor(classColor.r, classColor.g, classColor.b)
        classText:SetText(member.class or "Unknown")
        
        -- Rango
        local rankText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rankText:SetPoint("LEFT", 380, 0)
        rankText:SetText(nameColor .. member.rank .. "|r")
        
        -- Zona
        local zoneText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zoneText:SetPoint("LEFT", 520, 0)
        zoneText:SetText(nameColor .. (member.zone or "Desconocido") .. "|r")
        
        yOffset = yOffset - 30
    end
    
    -- Ajustar altura del scroll child
    self.panel.scrollChild:SetHeight(math.abs(yOffset) + 10)
end

function WCS_ClanPanel:Show()
    if self.panel then
        self.panel:Show()
        self:UpdateMemberList()
    end
end

function WCS_ClanPanel:Hide()
    if self.panel then
        self.panel:Hide()
    end
end

-- Retornar el frame global para que WCS_ClanUI pueda acceder
_G["WCS_ClanPanel"] = WCS_ClanPanel

