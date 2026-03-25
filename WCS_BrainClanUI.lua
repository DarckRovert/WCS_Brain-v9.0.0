--[[
    WCS_BrainClanUI.lua
    UI Completa para "El Séquito del Terror"
    
    Creado por: Elnazzareno (DarckRovert)
    Guild Master de El Séquito del Terror
    
    Versión: 1.0.0
    Fecha: Enero 2, 2026
    
    Temática: Brujo/Warlock - Oscura y Demoníaca
    
    Descripción:
    Sistema completo de UI para el clan con temática de grimorio oscuro,
    incluyendo gestión de miembros, recursos de brujo, raids, estadísticas,
    y mucho más.
]]--

-- Namespace global
WCS_ClanUI = WCS_ClanUI or {}
WCS_ClanUI.Version = "1.0.0"
WCS_ClanUI.GuildName = "El Séquito del Terror"
WCS_ClanUI.GuildMaster = "Elnazzareno"
WCS_ClanUI.Creator = "DarckRovert"

-- Colores temáticos del clan
WCS_ClanUI.Colors = {
    FelGreen = {r = 0.2, g = 1.0, b = 0.2},      -- Verde Fel
    DarkPurple = {r = 0.5, g = 0.0, b = 0.5},    -- Púrpura Oscuro
    BloodRed = {r = 0.8, g = 0.0, b = 0.0},      -- Rojo Sangre
    ShadowBlack = {r = 0.1, g = 0.1, b = 0.1},   -- Negro Sombra
    GoldText = {r = 1.0, g = 0.8, b = 0.0},      -- Dorado para texto
    SoulBlue = {r = 0.3, g = 0.3, b = 0.8},      -- Azul Alma
}

-- Variables guardadas
WCS_ClanUI_SavedVars = WCS_ClanUI_SavedVars or {
    version = "1.0.0",
    firstRun = true,
    mainFrame = {
        point = "CENTER",
        x = 0,
        y = 0,
        width = 800,
        height = 600,
        shown = false,
    },
    panels = {
        clanPanel = true,
        warlockResources = true,
        raidManager = true,
        statistics = true,
        grimoire = true,
        summonPanel = true,
        clanBank = true,
        pvpTracker = true,
    },
    settings = {
        autoAcceptSummons = true,
        autoShareQuests = true,
        soundEnabled = true,
        animationsEnabled = true,
        showMinimapButton = true,
        debugMode = false,  -- Mensajes de debug desactivados por defecto
    },
    members = {},
    events = {},
    achievements = {},
    statistics = {},
}

-- Frame principal
local MainFrame = nil

-- Inicialización
function WCS_ClanUI:Initialize()
    if self.Initialized then return end
    
    self:Print("Inicializando UI de " .. self.GuildName .. "...")
    
    -- Crear frame principal
    self:CreateMainFrame()
    
    -- Registrar eventos
    self:RegisterEvents()
    
    -- Registrar comandos slash
    self:RegisterSlashCommands()
    
    -- Cargar módulos
    self:LoadModules()
    
    -- Mensaje de bienvenida
    if WCS_ClanUI_SavedVars.firstRun then
        self:ShowWelcomeMessage()
        WCS_ClanUI_SavedVars.firstRun = false
    end
    
    self.Initialized = true
    self:Print("UI inicializada correctamente. Usa /sequito o /clan para abrir el panel.")
end

-- Colores refinados del Sequito v9
local CLAN_COLORS = {
    BG_DARK    = {0.03, 0.01, 0.06},
    BG_SECTION = {0.08, 0.05, 0.12},
    BORDER     = {0.2, 1.0, 0.2, 0.9},   -- Fel Green
    GOLD       = {1.0, 0.82, 0.0},
    PURPLE     = {0.58, 0.51, 0.79},
    FEL        = {0.0, 1.0, 0.5},
    TEXT_DIM   = {0.55, 0.55, 0.55},
}

-- Crear frame principal
function WCS_ClanUI:CreateMainFrame()
    if MainFrame then return end

    MainFrame = CreateFrame("Frame", "WCS_ClanUI_MainFrame", UIParent)
    MainFrame:SetWidth(700)
    MainFrame:SetHeight(650)
    MainFrame:SetFrameStrata("HIGH")
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:SetClampedToScreen(true)
    MainFrame:SetPoint("CENTER", 0, 0)
    MainFrame:Hide()

    -- Fondo oscuro premium
    MainFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 20,
        insets = {left = 5, right = 5, top = 5, bottom = 5}
    })
    MainFrame:SetBackdropColor(
        CLAN_COLORS.BG_DARK[1],
        CLAN_COLORS.BG_DARK[2],
        CLAN_COLORS.BG_DARK[3], 0.97)
    MainFrame:SetBackdropBorderColor(
        CLAN_COLORS.BORDER[1],
        CLAN_COLORS.BORDER[2],
        CLAN_COLORS.BORDER[3],
        CLAN_COLORS.BORDER[4])

    -- Header decorativo (mas compacto)
    local headerBg = CreateFrame("Frame", nil, MainFrame)
    headerBg:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -8)
    headerBg:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -8, -8)
    headerBg:SetHeight(44)
    headerBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    headerBg:SetBackdropColor(0.0, 0.05, 0.01, 0.95)
    headerBg:SetBackdropBorderColor(0.0, 1.0, 0.3, 0.8)

    -- Icono del clan
    local clanIcon = headerBg:CreateTexture(nil, "ARTWORK")
    clanIcon:SetWidth(30)
    clanIcon:SetHeight(30)
    clanIcon:SetPoint("LEFT", headerBg, "LEFT", 8, 0)
    clanIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")

    -- Titulo del clan
    local clanTitle = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    clanTitle:SetPoint("LEFT", clanIcon, "RIGHT", 6, 4)
    clanTitle:SetText("|cFF00FF00El Sequito del Terror|r")
    clanTitle:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    local clanSub = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clanSub:SetPoint("LEFT", clanIcon, "RIGHT", 6, -10)
    clanSub:SetText("|cFFFFD700Grimorio del Sequito v9.0|r")

    -- Info jugador
    local playerInfo = headerBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    playerInfo:SetPoint("RIGHT", headerBg, "RIGHT", -36, 0)
    playerInfo:SetText("|cFFAAAAAA" .. (UnitName("player") or "?") .. "|r")
    MainFrame.playerInfo = playerInfo

    -- Boton cerrar
    local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function() WCS_ClanUI:ToggleMainFrame() end)

    -- Drag por header
    headerBg:EnableMouse(true)
    headerBg:RegisterForDrag("LeftButton")
    headerBg:SetScript("OnDragStart", function() MainFrame:StartMoving() end)
    headerBg:SetScript("OnDragStop", function()
        MainFrame:StopMovingOrSizing()
        local point, _, _, x, y = MainFrame:GetPoint()
        if WCS_ClanUI_SavedVars and WCS_ClanUI_SavedVars.mainFrame then
            WCS_ClanUI_SavedVars.mainFrame.point = point
            WCS_ClanUI_SavedVars.mainFrame.x = x
            WCS_ClanUI_SavedVars.mainFrame.y = y
        end
    end)

    -- Marco de contenido (bajo las pestanas, posicion calculada despues de crear tabs)
    MainFrame.content = CreateFrame("Frame", nil, MainFrame)
    MainFrame.content:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    MainFrame.content:SetBackdropColor(
        CLAN_COLORS.BG_SECTION[1],
        CLAN_COLORS.BG_SECTION[2],
        CLAN_COLORS.BG_SECTION[3], 0.95)
    MainFrame.content:SetBackdropBorderColor(
        CLAN_COLORS.BORDER[1], CLAN_COLORS.BORDER[2], CLAN_COLORS.BORDER[3], 0.4)

    -- Crear pestanas
    self:CreateTabs()

    self.MainFrame = MainFrame
end

-- Sistema de pestanas
function WCS_ClanUI:CreateTabs()
    local _, playerClass = UnitClass("player")
    local isWarlock = (playerClass == "WARLOCK")

    local allTabs = {}

    -- Pestanas Universales
    table.insert(allTabs, {
        name = "Clan",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
        getPanel = function() return _G["WCS_ClanPanelFrame"] end,
        createFn  = function() if WCS_ClanPanel and WCS_ClanPanel.Initialize then WCS_ClanPanel:Initialize() end end
    })
    table.insert(allTabs, {
        name = "Stats",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        getPanel = function() return _G["WCS_StatisticsFrame"] end,
        createFn  = function() if WCS_Statistics and WCS_Statistics.Initialize then WCS_Statistics:Initialize() end end
    })
    table.insert(allTabs, {
        name = "Banco",
        icon = "Interface\\Icons\\INV_Misc_Bag_10",
        getPanel = function() return _G["WCS_ClanBankFrame"] end,
        createFn  = function() if WCS_ClanBank and WCS_ClanBank.Initialize then WCS_ClanBank:Initialize() end end
    })
    table.insert(allTabs, {
        name = "Raid",
        icon = "Interface\\Icons\\Ability_Warlock_DemonicEmpowerment",
        getPanel = function() return _G["WCS_RaidManagerFrame"] end,
        createFn  = function() if WCS_RaidManager and WCS_RaidManager.Initialize then WCS_RaidManager:Initialize() end end
    })
    table.insert(allTabs, {
        name = "PvP",
        icon = "Interface\\Icons\\Ability_DualWield",
        getPanel = function() return _G["WCS_PvPTrackerFrame"] end,
        createFn  = function() if WCS_PvPTracker and WCS_PvPTracker.Initialize then WCS_PvPTracker:Initialize() end end
    })

    -- Pestanas de Brujo
    if isWarlock then
        table.insert(allTabs, {
            name = "Grimorio",
            icon = "Interface\\Icons\\INV_Misc_Book_09",
            getPanel = function() return _G["WCS_GrimoireFrame"] end,
            createFn  = function() if WCS_Grimoire and WCS_Grimoire.Initialize then WCS_Grimoire:Initialize() end end
        })
        table.insert(allTabs, {
            name = "Recursos",
            icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
            getPanel = function() return _G["WCS_WarlockResourcesFrame"] end,
            createFn  = function() if WCS_WarlockResources and WCS_WarlockResources.Initialize then WCS_WarlockResources:Initialize() end end
        })
        table.insert(allTabs, {
            name = "Summons",
            icon = "Interface\\Icons\\Spell_Shadow_Twilight",
            getPanel = function() return _G["WCS_SummonPanelFrame"] end,
            createFn  = function() if WCS_SummonPanel and WCS_SummonPanel.Initialize then WCS_SummonPanel:Initialize() end end
        })
    end

    self.tabDataList = allTabs
    MainFrame.tabs = {}

    local tabWidth  = 82
    local tabHeight = 26
    local tabGap    = 3
    local startX    = 10
    local startY    = -58  -- despues del header de 44px + 8px margen + 6px gap
    local maxPerRow = 8

    for i = 1, table.getn(allTabs) do
        local tabData = allTabs[i]
        local tab = CreateFrame("Button", "WCS_ClanUI_Tab" .. i, MainFrame)
        tab:SetWidth(tabWidth)
        tab:SetHeight(tabHeight)

        local row = math.floor((i - 1) / maxPerRow)
        local col = math.mod(i - 1, maxPerRow)
        tab:SetPoint("TOPLEFT", startX + col * (tabWidth + tabGap), startY - row * (tabHeight + tabGap))

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints(tab)
        tab.bg:SetTexture(
            CLAN_COLORS.BG_SECTION[1],
            CLAN_COLORS.BG_SECTION[2],
            CLAN_COLORS.BG_SECTION[3], 0.85)

        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetWidth(16)
        tab.icon:SetHeight(16)
        tab.icon:SetPoint("LEFT", 4, 0)
        tab.icon:SetTexture(tabData.icon)

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 3, 0)
        tab.text:SetText(tabData.name)
        tab.text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        tab.text:SetTextColor(
            CLAN_COLORS.TEXT_DIM[1],
            CLAN_COLORS.TEXT_DIM[2],
            CLAN_COLORS.TEXT_DIM[3])

        tab:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        tab.index = i
        tab:SetScript("OnClick", function() WCS_ClanUI:SelectTab(this.index) end)

        MainFrame.tabs[i] = tab
    end

    -- Calcular area de contenido correctamente
    local rowsUsed    = math.floor((table.getn(allTabs) - 1) / maxPerRow) + 1
    local contentTopY = -58 - (rowsUsed * (tabHeight + tabGap)) - 6
    MainFrame.content:SetPoint("TOPLEFT",     MainFrame, "TOPLEFT",     10, contentTopY)
    MainFrame.content:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)
end

-- Seleccionar pestana
function WCS_ClanUI:SelectTab(index)
    if not MainFrame or not MainFrame.content then return end

    for i = 1, table.getn(MainFrame.tabs) do
        local tab = MainFrame.tabs[i]
        if i == index then
            tab.bg:SetTexture(
                CLAN_COLORS.FEL[1], CLAN_COLORS.FEL[2], CLAN_COLORS.FEL[3], 0.45)
            tab.text:SetTextColor(1, 1, 1)
        else
            tab.bg:SetTexture(
                CLAN_COLORS.BG_SECTION[1], CLAN_COLORS.BG_SECTION[2],
                CLAN_COLORS.BG_SECTION[3], 0.85)
            tab.text:SetTextColor(
                CLAN_COLORS.TEXT_DIM[1], CLAN_COLORS.TEXT_DIM[2], CLAN_COLORS.TEXT_DIM[3])
        end
    end

    self:HideAllPanels()
    self:ShowPanel(index)
    MainFrame.currentTab = index
end

-- Ocultar todos los paneles
function WCS_ClanUI:HideAllPanels()
    if self.tabDataList then
        for i = 1, table.getn(self.tabDataList) do
            local p = self.tabDataList[i].getPanel and self.tabDataList[i].getPanel() or nil
            if p and p.Hide then p:Hide() end
        end
    end
end

-- Mostrar panel con lazy loading (similar a WCS_BrainUI)
function WCS_ClanUI:ShowPanel(index)
    if not self.MainFrame or not self.MainFrame.content then return end
    if not self.tabDataList or not self.tabDataList[index] then return end

    local tabData = self.tabDataList[index]
    local p = tabData.getPanel and tabData.getPanel() or nil

    -- Lazy load: crear el panel si no existe
    if not p and tabData.createFn then
        tabData.createFn()
        p = tabData.getPanel and tabData.getPanel() or nil
    end

    if p and p.Show then
        -- Reparentar y fijar al area de contenido
        p:SetParent(self.MainFrame.content)
        p:ClearAllPoints()
        p:SetAllPoints(self.MainFrame.content)
        p:SetMovable(false)
        p:SetBackdropBorderColor(0, 0, 0, 0)
        p:Show()
    end
end

-- Registrar eventos
function WCS_ClanUI:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("CHAT_MSG_GUILD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            WCS_ClanUI:OnPlayerEnteringWorld()
        elseif event == "GUILD_ROSTER_UPDATE" then
            WCS_ClanUI:OnGuildRosterUpdate()
        elseif event == "CHAT_MSG_GUILD" then
            WCS_ClanUI:OnGuildChat(arg1, arg2)
        elseif event == "PLAYER_LOGOUT" then
            WCS_ClanUI:OnPlayerLogout()
        end
    end)
    
    self.EventFrame = frame
end

-- Eventos
function WCS_ClanUI:OnPlayerEnteringWorld()
    -- Verificar si el jugador está en el clan
    if GetGuildInfo("player") == self.GuildName then
        self:Print("¡Bienvenido al " .. self.GuildName .. "!")
    end
end

function WCS_ClanUI:OnGuildRosterUpdate()
    -- Actualizar lista de miembros
    if WCS_ClanPanel then
        WCS_ClanPanel:UpdateMemberList()
    end
end

function WCS_ClanUI:OnGuildChat(message, sender)
    -- Procesar mensajes del chat del clan
    -- Aquí se pueden agregar comandos especiales, etc.
end

function WCS_ClanUI:OnPlayerLogout()
    -- Guardar datos antes de salir
    self:SaveData()
end

-- Registrar comandos slash
function WCS_ClanUI:RegisterSlashCommands()
    -- Comando principal
    SLASH_WCSCLANUI1 = "/sequito"
    SLASH_WCSCLANUI2 = "/wcsui"
    SLASH_WCSCLANUI3 = "/terror"
    SLASH_WCSCLANUI4 = "/clan"
    
    SlashCmdList["WCSCLANUI"] = function(msg)
        WCS_ClanUI:HandleSlashCommand(msg)
    end
    
    -- Comando para abrir directamente el banco
    SLASH_WCSCLANBANK1 = "/clanbank"
    SLASH_WCSCLANBANK2 = "/bank"
    
    SlashCmdList["WCSCLANBANK"] = function(msg)
        WCS_ClanUI:ToggleMainFrame()
        WCS_ClanUI:SelectTab(7) -- Tab del banco
    end
    
    -- Comando para abrir directamente raid manager
    SLASH_WCSRAIDMGR1 = "/raidmanager"
    SLASH_WCSRAIDMGR2 = "/raidmgr"
    SLASH_WCSRAIDMGR3 = "/rm"
    
    SlashCmdList["WCSRAIDMGR"] = function(msg)
        WCS_ClanUI:ToggleMainFrame()
        WCS_ClanUI:SelectTab(3) -- Tab de raid manager
    end
    
    -- Comando para abrir directamente summon panel
    SLASH_WCSSUMMON1 = "/summonpanel"
    SLASH_WCSSUMMON2 = "/summon"
    SLASH_WCSSUMMON3 = "/sp"
    
    SlashCmdList["WCSSUMMON"] = function(msg)
        WCS_ClanUI:ToggleMainFrame()
        WCS_ClanUI:SelectTab(6) -- Tab de summon panel
    end
    
    -- Comando para abrir directamente statistics
    SLASH_WCSSTATS1 = "/warlockstats"
    SLASH_WCSSTATS2 = "/wstats"
    
    SlashCmdList["WCSSTATS"] = function(msg)
        WCS_ClanUI:ToggleMainFrame()
        WCS_ClanUI:SelectTab(4) -- Tab de statistics
    end
    
    -- Comando para abrir directamente grimoire
    SLASH_WCSGRIMOIRE1 = "/grimoire"
    SLASH_WCSGRIMOIRE2 = "/grim"
    
    SlashCmdList["WCSGRIMOIRE"] = function(msg)
        WCS_ClanUI:ToggleMainFrame()
        WCS_ClanUI:SelectTab(5) -- Tab de grimoire
    end
    
    -- Comando para abrir directamente PvP tracker
    SLASH_WCSPVP1 = "/pvptracker"
    SLASH_WCSPVP2 = "/pvpt"
    
    SlashCmdList["WCSPVP"] = function(msg)
        WCS_ClanUI:ToggleMainFrame()
        WCS_ClanUI:SelectTab(8) -- Tab de PvP tracker
    end
end

-- Manejar comandos slash
function WCS_ClanUI:HandleSlashCommand(msg)
    msg = string.lower(msg or "")
    
    if msg == "" or msg == "show" then
        self:ToggleMainFrame()
    elseif msg == "hide" then
        if MainFrame then MainFrame:Hide() end
    elseif msg == "reset" then
        self:ResetPosition()
    elseif msg == "help" then
        self:ShowHelp()
    elseif msg == "version" then
        self:Print("Versión: " .. self.Version)
    else
        self:Print("Comando desconocido. Usa /sequito help para ver los comandos disponibles.")
    end
end

-- Toggle frame principal
function WCS_ClanUI:ToggleMainFrame()
    if not MainFrame then
        self:CreateMainFrame()
    end
    
    if MainFrame:IsShown() then
        MainFrame:Hide()
        WCS_ClanUI_SavedVars.mainFrame.shown = false
    else
        MainFrame:Show()
        WCS_ClanUI_SavedVars.mainFrame.shown = true
        -- Refrescar el panel actual cuando se muestra
        self:SelectTab(1)
    end
end

-- Resetear posición
function WCS_ClanUI:ResetPosition()
    if MainFrame then
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("CENTER", 0, 0)
        WCS_ClanUI_SavedVars.mainFrame.point = "CENTER"
        WCS_ClanUI_SavedVars.mainFrame.x = 0
        WCS_ClanUI_SavedVars.mainFrame.y = 0
        self:Print("Posición reseteada al centro de la pantalla.")
    end
end

-- Mostrar ayuda
function WCS_ClanUI:ShowHelp()
    self:Print("=== Comandos de El Séquito del Terror ===")
    self:Print("|cffffaa00Comandos principales:|r")
    self:Print("/sequito, /clan, /terror - Abrir/cerrar el panel principal")
    self:Print("/sequito show - Mostrar el panel")
    self:Print("/sequito hide - Ocultar el panel")
    self:Print("/sequito reset - Resetear posición del panel")
    self:Print("/sequito version - Mostrar versión")
    self:Print("/sequito help - Mostrar esta ayuda")
    self:Print(" ")
    self:Print("|cffffaa00Accesos directos a módulos:|r")
    self:Print("/clanbank, /bank - Abrir banco del clan")
    self:Print("/raidmanager, /raidmgr, /rm - Abrir gestión de raid")
    self:Print("/summonpanel, /summon, /sp - Abrir panel de summon")
    self:Print("/warlockstats, /wstats - Abrir estadísticas")
    self:Print("/grimoire, /grim - Abrir grimorio")
    self:Print("/pvptracker, /pvpt - Abrir tracker de PvP")
end

-- Cargar módulos
function WCS_ClanUI:LoadModules()
    -- Los módulos se cargarán desde archivos separados
    self:Print("Cargando módulos...")
    
    -- Verificar que los módulos existan
    if WCS_ClanPanel then
        WCS_ClanPanel:Initialize()
    end
    
    if WCS_WarlockResources then
        WCS_WarlockResources:Initialize()
    end
    
    if WCS_RaidManager then
        WCS_RaidManager:Initialize()
    end
    
    if WCS_Statistics then
        WCS_Statistics:Initialize()
    end
    
    if WCS_Grimoire then
        WCS_Grimoire:Initialize()
    end
    
    if WCS_SummonPanel then
        WCS_SummonPanel:Initialize()
    end
    
    if WCS_ClanBank then
        WCS_ClanBank:Initialize()
    end
    
    if WCS_PvPTracker then
        WCS_PvPTracker:Initialize()
    end
end

-- Mensaje de bienvenida
function WCS_ClanUI:ShowWelcomeMessage()
    self:Print("==============================================")
    self:Print("|cff00ff00El Séquito del Terror - UI v" .. self.Version .. "|r")
    self:Print("Creado por: |cffffaa00" .. self.GuildMaster .. "|r (" .. self.Creator .. ")")
    self:Print("¡Bienvenido al grimorio del clan!")
    self:Print("Usa |cff00ff00/sequito|r para abrir el panel principal")
    self:Print("==============================================")
end

-- Guardar datos
function WCS_ClanUI:SaveData()
    -- Los datos se guardan automáticamente en WCS_ClanUI_SavedVars
    self:Print("Datos guardados correctamente.")
end

-- Función de print personalizada
function WCS_ClanUI:Print(msg)
    -- Siempre mostrar mensajes importantes
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Séquito del Terror]|r " .. msg)
end

-- Inicializar cuando el addon se carga
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_ClanUI:Initialize()
    elseif event == "PLAYER_LOGIN" then
        -- Fallback: inicializar en login si no se inicializó antes
        if not WCS_ClanUI.Initialized then
            WCS_ClanUI:Initialize()
        end
    end
end)

