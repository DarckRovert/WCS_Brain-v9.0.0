--[[
    WCS_BrainProfilesUI.lua - Interfaz Gráfica para Gestor de Perfiles
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
]]--

WCS_BrainProfilesUI = WCS_BrainProfilesUI or {}
WCS_BrainProfilesUI.VERSION = "1.0.0"

-- Variables locales
local mainFrame = nil
local selectedProfile = nil
local profileButtons = {}

-- Colores
local COLOR_GOLD = {r=1, g=0.82, b=0}
local COLOR_GREEN = {r=0, g=1, b=0}
local COLOR_WHITE = {r=1, g=1, b=1}
local COLOR_GRAY = {r=0.5, g=0.5, b=0.5}
local COLOR_RED = {r=1, g=0, b=0}

-- ============================================================================
-- CREAR VENTANA PRINCIPAL
-- ============================================================================
function WCS_BrainProfilesUI:Create()
    if mainFrame then return mainFrame end
    
    -- Frame principal
    mainFrame = CreateFrame("Frame", "WCSBrainProfilesMainFrame", UIParent)
    mainFrame:SetWidth(500)
    mainFrame:SetHeight(600)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    
    -- Backdrop
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.95)
    
    -- Titulo
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -20)
    title:SetText("|cFFFFD700WCS Brain - Gestor de Perfiles|r")
    mainFrame.title = title
    
    -- Boton cerrar
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    -- Hacer arrastrable desde el titulo
    local dragArea = CreateFrame("Frame", nil, mainFrame)
    dragArea:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    dragArea:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, -40)
    dragArea:SetHeight(40)
    dragArea:EnableMouse(true)
    dragArea:RegisterForDrag("LeftButton")
    dragArea:SetScript("OnDragStart", function()
        mainFrame:StartMoving()
    end)
    dragArea:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
    end)
    
    -- ========================================================================
    -- SECCION: LISTA DE PERFILES (Izquierda)
    -- ========================================================================
    
    local listFrame = CreateFrame("Frame", nil, mainFrame)
    listFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -80)
    listFrame:SetWidth(220)
    listFrame:SetHeight(450)
    listFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    listFrame:SetBackdropColor(0, 0, 0, 0.8)
    mainFrame.listFrame = listFrame
    
    -- Titulo de la lista
    local listTitle = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOP", listFrame, "TOP", 0, -10)
    listTitle:SetText("|cFFFFD700Perfiles Disponibles|r")
    
    -- ScrollFrame para la lista
    local scrollFrame = CreateFrame("ScrollFrame", "WCSBrainProfilesScrollFrame", listFrame)
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -28, 8)
    
    -- Crear slider para scroll
    local scrollBar = CreateFrame("Slider", "WCSBrainProfilesScrollBar", scrollFrame)
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -4, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -4, 16)
    scrollBar:SetWidth(16)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 100)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 3, right = 3, top = 6, bottom = 6}
    })
    scrollBar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    scrollBar:SetScript("OnValueChanged", function()
        scrollFrame:SetVerticalScroll(this:GetValue())
    end)
    scrollFrame.scrollBar = scrollBar
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(180)
    scrollChild:SetHeight(400)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild
    
    -- ========================================================================
    -- SECCION: DETALLES DEL PERFIL (Derecha)
    -- ========================================================================
    
    local detailsFrame = CreateFrame("Frame", nil, mainFrame)
    detailsFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 10, 0)
    detailsFrame:SetWidth(240)
    detailsFrame:SetHeight(450)
    detailsFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    detailsFrame:SetBackdropColor(0, 0, 0, 0.8)
    mainFrame.detailsFrame = detailsFrame
    
    -- Titulo de detalles
    local detailsTitle = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailsTitle:SetPoint("TOP", detailsFrame, "TOP", 0, -10)
    detailsTitle:SetText("|cFFFFD700Detalles del Perfil|r")
    
    -- Texto de detalles (ScrollFrame)
    local detailsScroll = CreateFrame("ScrollFrame", "WCSBrainProfilesDetailsScroll", detailsFrame)
    detailsScroll:SetPoint("TOPLEFT", detailsFrame, "TOPLEFT", 8, -35)
    detailsScroll:SetPoint("BOTTOMRIGHT", detailsFrame, "BOTTOMRIGHT", -28, 50)
    
    -- Crear slider para scroll de detalles
    local detailsScrollBar = CreateFrame("Slider", "WCSBrainProfilesDetailsScrollBar", detailsScroll)
    detailsScrollBar:SetPoint("TOPRIGHT", detailsScroll, "TOPRIGHT", -4, -16)
    detailsScrollBar:SetPoint("BOTTOMRIGHT", detailsScroll, "BOTTOMRIGHT", -4, 16)
    detailsScrollBar:SetWidth(16)
    detailsScrollBar:SetOrientation("VERTICAL")
    detailsScrollBar:SetMinMaxValues(0, 100)
    detailsScrollBar:SetValueStep(1)
    detailsScrollBar:SetValue(0)
    detailsScrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 3, right = 3, top = 6, bottom = 6}
    })
    detailsScrollBar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    detailsScrollBar:SetScript("OnValueChanged", function()
        detailsScroll:SetVerticalScroll(this:GetValue())
    end)
    detailsScroll.scrollBar = detailsScrollBar
    
    local detailsChild = CreateFrame("Frame", nil, detailsScroll)
    detailsChild:SetWidth(200)
    detailsChild:SetHeight(350)
    detailsScroll:SetScrollChild(detailsChild)
    
    local detailsText = detailsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailsText:SetPoint("TOPLEFT", detailsChild, "TOPLEFT", 5, -5)
    detailsText:SetWidth(190)
    detailsText:SetJustifyH("LEFT")
    detailsText:SetText("|cFF888888Selecciona un perfil para ver detalles|r")
    mainFrame.detailsText = detailsText
    
    -- Botones de accion en detalles
    local loadBtn = CreateFrame("Button", nil, detailsFrame, "UIPanelButtonTemplate")
    loadBtn:SetWidth(100)
    loadBtn:SetHeight(25)
    loadBtn:SetPoint("BOTTOMLEFT", detailsFrame, "BOTTOMLEFT", 10, 10)
    loadBtn:SetText("Cargar")
    loadBtn:SetScript("OnClick", function()
        if selectedProfile then
            WCS_BrainProfiles.LoadProfile(selectedProfile)
            WCS_BrainProfilesUI:RefreshProfileList()
        end
    end)
    mainFrame.loadBtn = loadBtn
    
    local deleteBtn = CreateFrame("Button", nil, detailsFrame, "UIPanelButtonTemplate")
    deleteBtn:SetWidth(100)
    deleteBtn:SetHeight(25)
    deleteBtn:SetPoint("BOTTOMRIGHT", detailsFrame, "BOTTOMRIGHT", -10, 10)
    deleteBtn:SetText("Eliminar")
    deleteBtn:SetScript("OnClick", function()
        if selectedProfile then
            WCS_BrainProfilesUI:ShowDeleteConfirmation(selectedProfile)
        end
    end)
    mainFrame.deleteBtn = deleteBtn
    
    -- ========================================================================
    -- TABS: Perfiles / Auto-Perfiles
    -- ========================================================================
    
    local tabPerfiles = CreateFrame("Button", nil, mainFrame)
    tabPerfiles:SetWidth(120)
    tabPerfiles:SetHeight(30)
    tabPerfiles:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -45)
    tabPerfiles:SetNormalTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left")
    tabPerfiles:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    
    local tabPerfilesText = tabPerfiles:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabPerfilesText:SetPoint("CENTER", tabPerfiles, "CENTER", 0, 0)
    tabPerfilesText:SetText("Perfiles")
    
    local tabAuto = CreateFrame("Button", nil, mainFrame)
    tabAuto:SetWidth(120)
    tabAuto:SetHeight(30)
    tabAuto:SetPoint("LEFT", tabPerfiles, "RIGHT", 5, 0)
    tabAuto:SetNormalTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left")
    tabAuto:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    
    local tabAutoText = tabAuto:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabAutoText:SetPoint("CENTER", tabAuto, "CENTER", 0, 0)
    tabAutoText:SetText("Auto-Perfiles")
    
    mainFrame.tabPerfiles = tabPerfiles
    mainFrame.tabAuto = tabAuto
    mainFrame.currentTab = "perfiles"
    
    -- ========================================================================
    -- SECCION: AUTO-PERFILES (Frame oculto inicialmente)
    -- ========================================================================
    
    local autoFrame = CreateFrame("Frame", nil, mainFrame)
    autoFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -80)
    autoFrame:SetWidth(470)
    autoFrame:SetHeight(450)
    autoFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    autoFrame:SetBackdropColor(0, 0, 0, 0.8)
    autoFrame:Hide()
    mainFrame.autoFrame = autoFrame
    
    -- Checkbox: Activar Sistema
    local enableCheck = CreateFrame("CheckButton", nil, autoFrame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", autoFrame, "TOPLEFT", 15, -15)
    enableCheck:SetWidth(24)
    enableCheck:SetHeight(24)
    
    local enableText = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableText:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
    enableText:SetText("|cFF00FF00Activar Sistema Automático|r")
    
    enableCheck:SetScript("OnClick", function()
        if this:GetChecked() then
            if WCS_BrainAutoProfiles then
                WCS_BrainAutoProfiles:Enable()
            end
        else
            if WCS_BrainAutoProfiles then
                WCS_BrainAutoProfiles:Disable()
            end
        end
    end)
    
    autoFrame.enableCheck = enableCheck
    
    -- Slider: Delay
    local delaySlider = CreateFrame("Slider", "WCSBrainAutoProfilesDelaySlider", autoFrame, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -20)
    delaySlider:SetWidth(200)
    delaySlider:SetHeight(15)
    delaySlider:SetMinMaxValues(1, 10)
    delaySlider:SetValueStep(1)
    delaySlider:SetValue(3)
    
    getglobal(delaySlider:GetName() .. "Low"):SetText("1s")
    getglobal(delaySlider:GetName() .. "High"):SetText("10s")
    getglobal(delaySlider:GetName() .. "Text"):SetText("Delay antes de cambiar: 3 segundos")
    
    delaySlider:SetScript("OnValueChanged", function()
        local value = this:GetValue()
        getglobal(this:GetName() .. "Text"):SetText("Delay antes de cambiar: " .. value .. " segundos")
        if WCS_BrainSaved and WCS_BrainSaved.autoProfiles then
            WCS_BrainSaved.autoProfiles.delay = value
        end
    end)
    
    autoFrame.delaySlider = delaySlider
    
    -- Checkbox: Notificaciones
    local notifCheck = CreateFrame("CheckButton", nil, autoFrame, "UICheckButtonTemplate")
    notifCheck:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -15)
    notifCheck:SetWidth(24)
    notifCheck:SetHeight(24)
    notifCheck:SetChecked(true)
    
    local notifText = notifCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notifText:SetPoint("LEFT", notifCheck, "RIGHT", 5, 0)
    notifText:SetText("Mostrar notificaciones")
    
    notifCheck:SetScript("OnClick", function()
        if WCS_BrainSaved and WCS_BrainSaved.autoProfiles then
            WCS_BrainSaved.autoProfiles.notifications = this:GetChecked()
        end
    end)
    
    autoFrame.notifCheck = notifCheck
    
    -- Titulo de reglas
    local rulesTitle = autoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rulesTitle:SetPoint("TOPLEFT", notifCheck, "BOTTOMLEFT", 0, -20)
    rulesTitle:SetText("|cFFFFD700Reglas (orden de prioridad):|r")
    
    -- Frame de reglas
    local rulesFrame = CreateFrame("Frame", nil, autoFrame)
    rulesFrame:SetPoint("TOPLEFT", rulesTitle, "BOTTOMLEFT", 0, -10)
    rulesFrame:SetWidth(440)
    rulesFrame:SetHeight(250)
    rulesFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    rulesFrame:SetBackdropColor(0, 0, 0, 0.5)
    autoFrame.rulesFrame = rulesFrame
    
    -- Crear 6 reglas
    local ruleNames = {"Raid", "Dungeon", "Battleground", "Party", "Ciudad", "Solo"}
    local ruleButtons = {}
    
    for i = 1, 6 do
        local ruleFrame = CreateFrame("Frame", nil, rulesFrame)
        ruleFrame:SetPoint("TOPLEFT", rulesFrame, "TOPLEFT", 10, -10 - (i-1) * 40)
        ruleFrame:SetWidth(420)
        ruleFrame:SetHeight(35)
        
        -- Checkbox
        local check = CreateFrame("CheckButton", nil, ruleFrame, "UICheckButtonTemplate")
        check:SetPoint("LEFT", ruleFrame, "LEFT", 0, 0)
        check:SetWidth(24)
        check:SetHeight(24)
        check:SetChecked(i ~= 5) -- Ciudad desactivado por defecto
        check.ruleIndex = i
        
        check:SetScript("OnClick", function()
            if WCS_BrainSaved and WCS_BrainSaved.autoProfiles and WCS_BrainSaved.autoProfiles.rules[this.ruleIndex] then
                WCS_BrainSaved.autoProfiles.rules[this.ruleIndex].enabled = this:GetChecked()
            end
        end)
        
        -- Nombre de la regla
        local nameText = ruleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", check, "RIGHT", 5, 0)
        nameText:SetWidth(100)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(ruleNames[i])
        
        -- Flecha
        local arrow = ruleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrow:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
        arrow:SetText("→")
        
        -- Dropdown (simulado con botones)
        local dropdown = CreateFrame("Button", nil, ruleFrame, "UIPanelButtonTemplate")
        dropdown:SetPoint("LEFT", arrow, "RIGHT", 5, 0)
        dropdown:SetWidth(200)
        dropdown:SetHeight(25)
        dropdown:SetText("Affliction Solo")
        dropdown.ruleIndex = i
        
        dropdown:SetScript("OnClick", function()
            -- Aquí iría el menú dropdown, por ahora solo cicla entre perfiles
            WCS_BrainProfilesUI:ShowProfileDropdown(this, this.ruleIndex)
        end)
        
        ruleFrame.check = check
        ruleFrame.dropdown = dropdown
        ruleButtons[i] = ruleFrame
    end
    
    autoFrame.ruleButtons = ruleButtons
    
    -- Botones de acción
    local applyBtn = CreateFrame("Button", nil, autoFrame, "UIPanelButtonTemplate")
    applyBtn:SetWidth(150)
    applyBtn:SetHeight(30)
    applyBtn:SetPoint("BOTTOMLEFT", autoFrame, "BOTTOMLEFT", 15, 15)
    applyBtn:SetText("Aplicar Cambios")
    applyBtn:SetScript("OnClick", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto-Perfiles]|r Configuración guardada")
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    
    local resetBtn = CreateFrame("Button", nil, autoFrame, "UIPanelButtonTemplate")
    resetBtn:SetWidth(180)
    resetBtn:SetHeight(30)
    resetBtn:SetPoint("BOTTOMRIGHT", autoFrame, "BOTTOMRIGHT", -15, 15)
    resetBtn:SetText("Restaurar Valores")
    resetBtn:SetScript("OnClick", function()
        WCS_BrainProfilesUI:ResetAutoProfilesConfig()
    end)
    
    -- Scripts de tabs
    tabPerfiles:SetScript("OnClick", function()
        mainFrame.currentTab = "perfiles"
        listFrame:Show()
        detailsFrame:Show()
        autoFrame:Hide()
        tabPerfilesText:SetTextColor(1, 0.82, 0)
        tabAutoText:SetTextColor(1, 1, 1)
    end)
    
    tabAuto:SetScript("OnClick", function()
        mainFrame.currentTab = "auto"
        listFrame:Hide()
        detailsFrame:Hide()
        autoFrame:Show()
        WCS_BrainProfilesUI:RefreshAutoProfilesTab()
        tabPerfilesText:SetTextColor(1, 1, 1)
        tabAutoText:SetTextColor(1, 0.82, 0)
    end)
    
    -- Inicializar tab de perfiles como activo
    tabPerfilesText:SetTextColor(1, 0.82, 0)
    tabAutoText:SetTextColor(1, 1, 1)
    
    -- ========================================================================
    -- SECCION: BOTONES DE ACCION (Abajo)
    -- ========================================================================
    
    local newBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    newBtn:SetWidth(120)
    newBtn:SetHeight(30)
    newBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, 15)
    newBtn:SetText("Nuevo Perfil")
    newBtn:SetScript("OnClick", function()
        WCS_BrainProfilesUI:ShowCreateDialog()
    end)
    
    local saveBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    saveBtn:SetWidth(140)
    saveBtn:SetHeight(30)
    saveBtn:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 15)
    saveBtn:SetText("Guardar Actual")
    saveBtn:SetScript("OnClick", function()
        local currentProfile = WCS_BrainProfiles.GetCurrentProfileName()
        if currentProfile then
            WCS_BrainProfilesUI:ShowSaveDialog(currentProfile)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Perfiles]|r No hay perfil activo")
        end
    end)
    
    local closeBtn2 = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    closeBtn2:SetWidth(120)
    closeBtn2:SetHeight(30)
    closeBtn2:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -15, 15)
    closeBtn2:SetText("Cerrar")
    closeBtn2:SetScript("OnClick", function()
        mainFrame:Hide()
    end)
    
    -- Inicialmente oculto
    mainFrame:Hide()
    
    return mainFrame
end

-- ============================================================================
-- REFRESCAR LISTA DE PERFILES
-- ============================================================================
function WCS_BrainProfilesUI:RefreshProfileList()
    if not mainFrame then return end
    
    -- Limpiar botones anteriores
    for i = 1, table.getn(profileButtons) do
        profileButtons[i]:Hide()
        profileButtons[i] = nil
    end
    profileButtons = {}
    
    -- Obtener lista de perfiles
    local profiles = WCS_BrainProfiles.GetProfileList()
    local currentProfile = WCS_BrainProfiles.GetCurrentProfileName()
    
    -- Crear boton para cada perfil
    local yOffset = 0
    for i = 1, table.getn(profiles) do
        local profileName = profiles[i]
        
        local btn = CreateFrame("Button", nil, mainFrame.scrollChild)
        btn:SetWidth(180)
        btn:SetHeight(30)
        btn:SetPoint("TOPLEFT", mainFrame.scrollChild, "TOPLEFT", 0, -yOffset)
        
        -- Fondo del boton
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        bg:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        bg:SetAlpha(0)
        btn.bg = bg
        
        -- Texto del boton
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        text:SetJustifyH("LEFT")
        text:SetWidth(170)
        
        -- Resaltar perfil actual
        if profileName == currentProfile then
            text:SetText("|cFF00FF00" .. profileName .. " *|r")
        else
            text:SetText("|cFFFFFFFF" .. profileName .. "|r")
        end
        
        -- Highlight al pasar mouse
        btn:SetScript("OnEnter", function()
            this.bg:SetAlpha(0.3)
        end)
        
        btn:SetScript("OnLeave", function()
            if selectedProfile ~= profileName then
                this.bg:SetAlpha(0)
            end
        end)
        
        -- Click: Seleccionar perfil
        btn:SetScript("OnClick", function()
            selectedProfile = profileName
            WCS_BrainProfilesUI:ShowProfileDetails(profileName)
            
            -- Actualizar highlights
            for j = 1, table.getn(profileButtons) do
                profileButtons[j].bg:SetAlpha(0)
            end
            this.bg:SetAlpha(0.5)
        end)
        
        table.insert(profileButtons, btn)
        yOffset = yOffset + 32
    end
    
    -- Ajustar altura del scroll child
    mainFrame.scrollChild:SetHeight(math.max(400, yOffset))
end

-- ============================================================================
-- MOSTRAR DETALLES DEL PERFIL
-- ============================================================================
function WCS_BrainProfilesUI:ShowProfileDetails(profileName)
    if not mainFrame then return end
    
    local profile = WCS_BrainProfiles.GetProfileDetails(profileName)
    if not profile then
        mainFrame.detailsText:SetText("|cFFFF0000Error: Perfil no encontrado|r")
        return
    end
    
    -- Construir texto de detalles
    local details = "|cFFFFD700" .. profileName .. "|r\\n\\n"
    
    if profile.description then
        details = details .. "|cFFFFFFFF" .. profile.description .. "|r\\n\\n"
    end
    
    -- AI Settings
    if profile.ai then
        details = details .. "|cFF00FF80=== IA Principal ===|r\\n"
        details = details .. "Activado: " .. (profile.ai.enabled and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        if profile.ai.aggressiveness then
            details = details .. "Agresividad: |cFFFFFF00" .. (profile.ai.aggressiveness * 100) .. "%|r\\n"
        end
        if profile.ai.manaConservation then
            details = details .. "Conservacion Mana: |cFFFFFF00" .. (profile.ai.manaConservation * 100) .. "%|r\\n"
        end
        details = details .. "\\n"
    end
    
    -- Pet AI Settings
    if profile.petAI then
        details = details .. "|cFF00FF80=== IA de Mascota ===|r\\n"
        details = details .. "Activado: " .. (profile.petAI.enabled and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        if profile.petAI.mode then
            details = details .. "Modo: |cFFFFFF00" .. profile.petAI.mode .. "|r\\n"
        end
        if profile.petAI.preferredPet then
            details = details .. "Mascota: |cFFFFFF00" .. profile.petAI.preferredPet .. "|r\\n"
        end
        details = details .. "Auto-Seguir: " .. (profile.petAI.autoFollow and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        details = details .. "Notificaciones: " .. (profile.petAI.notifications and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        details = details .. "\\n"
    end
    
    -- Pet UI Settings
    if profile.petUI then
        details = details .. "|cFF00FF80=== UI de Mascota ===|r\\n"
        details = details .. "Modo Compacto: " .. (profile.petUI.compactMode and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        details = details .. "Mostrar Buffs: " .. (profile.petUI.showBuffs and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        details = details .. "Monitor Eventos: " .. (profile.petUI.monitorEvents and "|cFF00FF00Si|r" or "|cFFFF0000No|r") .. "\\n"
        details = details .. "\\n"
    end
    
    -- Spell Priorities
    if profile.spellPriorities then
        details = details .. "|cFF00FF80=== Prioridades de Hechizos ===|r\\n"
        for spell, priority in pairs(profile.spellPriorities) do
            details = details .. spell .. ": |cFFFFFF00" .. priority .. "|r\\n"
        end
    end
    
    mainFrame.detailsText:SetText(details)
end

-- ============================================================================
-- DIALOGO: CREAR NUEVO PERFIL
-- ============================================================================
function WCS_BrainProfilesUI:ShowCreateDialog()
    -- Crear dialogo
    local dialog = CreateFrame("Frame", "WCSBrainProfilesCreateDialog", UIParent)
    dialog:SetWidth(350)
    dialog:SetHeight(200)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    dialog:SetBackdropColor(0, 0, 0, 0.95)
    
    -- Titulo
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -20)
    title:SetText("|cFFFFD700Crear Nuevo Perfil|r")
    
    -- Label nombre
    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -60)
    nameLabel:SetText("Nombre del perfil:")
    
    -- Input nombre
    local nameInput = CreateFrame("EditBox", nil, dialog)
    nameInput:SetWidth(300)
    nameInput:SetHeight(30)
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -5)
    nameInput:SetAutoFocus(false)
    nameInput:SetFontObject("GameFontHighlight")
    nameInput:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    nameInput:SetBackdropColor(0, 0, 0, 0.8)
    nameInput:SetTextInsets(8, 8, 0, 0)
    nameInput:SetMaxLetters(50)
    
    -- Label descripcion
    local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("Descripcion (opcional):")
    
    -- Input descripcion
    local descInput = CreateFrame("EditBox", nil, dialog)
    descInput:SetWidth(300)
    descInput:SetHeight(30)
    descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descInput:SetAutoFocus(false)
    descInput:SetFontObject("GameFontHighlight")
    descInput:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    descInput:SetBackdropColor(0, 0, 0, 0.8)
    descInput:SetTextInsets(8, 8, 0, 0)
    descInput:SetMaxLetters(100)
    
    -- Boton Crear
    local createBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    createBtn:SetWidth(100)
    createBtn:SetHeight(25)
    createBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 15)
    createBtn:SetText("Crear")
    createBtn:SetScript("OnClick", function()
        local name = nameInput:GetText()
        local desc = descInput:GetText()
        
        if WCS_BrainProfiles.CreateNewProfile(name, desc) then
            dialog:Hide()
            WCS_BrainProfilesUI:RefreshProfileList()
        end
    end)
    
    -- Boton Cancelar
    local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelBtn:SetWidth(100)
    cancelBtn:SetHeight(25)
    cancelBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 15)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)
    
    dialog:Show()
end

-- ============================================================================
-- DIALOGO: GUARDAR PERFIL ACTUAL
-- ============================================================================
function WCS_BrainProfilesUI:ShowSaveDialog(profileName)
    -- Crear dialogo de confirmacion
    local dialog = CreateFrame("Frame", "WCSBrainProfilesSaveDialog", UIParent)
    dialog:SetWidth(350)
    dialog:SetHeight(150)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    dialog:SetBackdropColor(0, 0, 0, 0.95)
    
    -- Titulo
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -20)
    title:SetText("|cFFFFD700Guardar Perfil|r")
    
    -- Mensaje
    local msg = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOP", dialog, "TOP", 0, -60)
    msg:SetWidth(300)
    msg:SetText("Guardar configuracion actual en:\\n|cFFFFFF00" .. profileName .. "|r?")
    
    -- Boton Guardar
    local saveBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveBtn:SetWidth(100)
    saveBtn:SetHeight(25)
    saveBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 15)
    saveBtn:SetText("Guardar")
    saveBtn:SetScript("OnClick", function()
        local config = WCS_BrainProfiles.CaptureCurrentConfig()
        WCS_BrainProfiles.UpdateProfile(profileName, config)
        dialog:Hide()
        WCS_BrainProfilesUI:RefreshProfileList()
    end)
    
    -- Boton Cancelar
    local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelBtn:SetWidth(100)
    cancelBtn:SetHeight(25)
    cancelBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 15)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)
    
    dialog:Show()
end

-- ============================================================================
-- DIALOGO: CONFIRMAR ELIMINACION
-- ============================================================================
function WCS_BrainProfilesUI:ShowDeleteConfirmation(profileName)
    -- No permitir eliminar perfil activo
    local currentProfile = WCS_BrainProfiles.GetCurrentProfileName()
    if profileName == currentProfile then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Perfiles]|r No puedes eliminar el perfil activo")
        return
    end
    
    -- Crear dialogo de confirmacion
    local dialog = CreateFrame("Frame", "WCSBrainProfilesDeleteDialog", UIParent)
    dialog:SetWidth(350)
    dialog:SetHeight(150)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    dialog:SetBackdropColor(0, 0, 0, 0.95)
    
    -- Titulo
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -20)
    title:SetText("|cFFFF0000Eliminar Perfil|r")
    
    -- Mensaje
    local msg = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOP", dialog, "TOP", 0, -60)
    msg:SetWidth(300)
    msg:SetText("Estas seguro de eliminar:\\n|cFFFFFF00" .. profileName .. "|r?\\n\\n|cFFFF0000Esta accion no se puede deshacer|r")
    
    -- Boton Eliminar
    local deleteBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    deleteBtn:SetWidth(100)
    deleteBtn:SetHeight(25)
    deleteBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 15)
    deleteBtn:SetText("Eliminar")
    deleteBtn:SetScript("OnClick", function()
        WCS_BrainProfiles.DeleteProfile(profileName)
        selectedProfile = nil
        dialog:Hide()
        WCS_BrainProfilesUI:RefreshProfileList()
        mainFrame.detailsText:SetText("|cFF888888Selecciona un perfil para ver detalles|r")
    end)
    
    -- Boton Cancelar
    local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelBtn:SetWidth(100)
    cancelBtn:SetHeight(25)
    cancelBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 15)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)
    
    dialog:Show()
end

-- ============================================================================
-- MOSTRAR/OCULTAR/TOGGLE
-- ============================================================================
function WCS_BrainProfilesUI:Show()
    if WCS_BrainUI and WCS_BrainUI.SelectTabByName then
        WCS_BrainUI:SelectTabByName("Perfiles")
        if not mainFrame then WCS_BrainProfilesUI:Create() end
        WCS_BrainProfilesUI:RefreshProfileList()
    else
        if not mainFrame then
            WCS_BrainProfilesUI:Create()
        end
        mainFrame:Show()
        WCS_BrainProfilesUI:RefreshProfileList()
    end
end

function WCS_BrainProfilesUI:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function WCS_BrainProfilesUI:Toggle()
    if WCS_BrainUI and WCS_BrainUI.MainFrame and WCS_BrainUI.MainFrame:IsVisible() and WCS_BrainUI.tabDataList and WCS_BrainUI.MainFrame.currentTab then
        if WCS_BrainUI.tabDataList[WCS_BrainUI.MainFrame.currentTab].name == "Perfiles" then
            WCS_BrainUI:Toggle()
            return
        end
    end
    
    if mainFrame and mainFrame:IsVisible() and (not WCS_BrainUI or not WCS_BrainUI.MainFrame or not WCS_BrainUI.MainFrame:IsVisible()) then
        WCS_BrainProfilesUI:Hide()
    else
        WCS_BrainProfilesUI:Show()
    end
end

-- ============================================================================
-- FUNCIONES PARA AUTO-PERFILES
-- ============================================================================

function WCS_BrainProfilesUI:RefreshAutoProfilesTab()
    if not mainFrame or not mainFrame.autoFrame then return end
    
    local autoFrame = mainFrame.autoFrame
    
    -- Actualizar checkbox de activación
    if WCS_BrainAutoProfiles then
        autoFrame.enableCheck:SetChecked(WCS_BrainAutoProfiles:IsEnabled())
    end
    
    -- Actualizar slider de delay
    if WCS_BrainSaved and WCS_BrainSaved.autoProfiles then
        autoFrame.delaySlider:SetValue(WCS_BrainSaved.autoProfiles.delay or 3)
        autoFrame.notifCheck:SetChecked(WCS_BrainSaved.autoProfiles.notifications)
        
        -- Actualizar reglas
        for i = 1, 6 do
            if autoFrame.ruleButtons[i] and WCS_BrainSaved.autoProfiles.rules[i] then
                local rule = WCS_BrainSaved.autoProfiles.rules[i]
                autoFrame.ruleButtons[i].check:SetChecked(rule.enabled)
                autoFrame.ruleButtons[i].dropdown:SetText(rule.profile)
            end
        end
    end
end

function WCS_BrainProfilesUI:ShowProfileDropdown(button, ruleIndex)
    -- Menú simple para seleccionar perfil
    if not WCS_BrainProfiles then return end
    
    local profiles = WCS_BrainProfiles:GetProfileList()
    if not profiles or table.getn(profiles) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Auto-Perfiles]|r No hay perfiles disponibles")
        return
    end
    
    -- Crear menú contextual
    local menu = CreateFrame("Frame", "WCSBrainProfileDropdownMenu", UIParent)
    menu:SetWidth(200)
    menu:SetHeight(math.min(table.getn(profiles) * 25 + 10, 300))
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, 0)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    menu:SetBackdropColor(0, 0, 0, 0.95)
    menu:EnableMouse(true)
    
    -- Crear botones para cada perfil
    for i = 1, table.getn(profiles) do
        local btn = CreateFrame("Button", nil, menu)
        btn:SetWidth(180)
        btn:SetHeight(20)
        btn:SetPoint("TOP", menu, "TOP", 0, -5 - (i-1) * 25)
        
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        text:SetText(profiles[i])
        
        btn:SetScript("OnEnter", function()
            btn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
            })
            btn:SetBackdropColor(0.3, 0.3, 0.3, 0.8)
        end)
        
        btn:SetScript("OnLeave", function()
            btn:SetBackdrop(nil)
        end)
        
        btn:SetScript("OnClick", function()
            button:SetText(profiles[i])
            if WCS_BrainSaved and WCS_BrainSaved.autoProfiles and WCS_BrainSaved.autoProfiles.rules[ruleIndex] then
                WCS_BrainSaved.autoProfiles.rules[ruleIndex].profile = profiles[i]
            end
            menu:Hide()
            PlaySound("igMainMenuOptionCheckBoxOn")
        end)
    end
    
    -- Auto-cerrar al hacer click fuera
    menu:SetScript("OnHide", function()
        this:SetScript("OnUpdate", nil)
    end)
    
    menu:SetScript("OnUpdate", function()
        if not MouseIsOver(menu) and not MouseIsOver(button) then
            if GetTime() > (menu.closeTime or 0) then
                menu:Hide()
            end
        else
            menu.closeTime = GetTime() + 0.5
        end
    end)
    
    menu.closeTime = GetTime() + 0.5
    menu:Show()
end

function WCS_BrainProfilesUI:ResetAutoProfilesConfig()
    -- Confirmación
    StaticPopupDialogs["WCS_BRAIN_RESET_AUTO_PROFILES"] = {
        text = "¿Restaurar configuración de Auto-Perfiles a valores por defecto?",
        button1 = "Sí",
        button2 = "No",
        OnAccept = function()
            if WCS_BrainSaved then
                WCS_BrainSaved.autoProfiles = {
                    enabled = false,
                    delay = 3,
                    notifications = true,
                    checkInterval = 2,
                    rules = {
                        {name = "Raid", priority = 1, condition = "IN_RAID", profile = "Affliction Raid", enabled = true},
                        {name = "Dungeon", priority = 2, condition = "IN_DUNGEON", profile = "Destruction Dungeon", enabled = true},
                        {name = "Battleground", priority = 3, condition = "IN_BATTLEGROUND", profile = "Destruction PvP", enabled = true},
                        {name = "Party", priority = 4, condition = "IN_PARTY", profile = "Affliction Solo", enabled = true},
                        {name = "Ciudad", priority = 5, condition = "IN_CITY", profile = "Affliction Solo", enabled = false},
                        {name = "Solo", priority = 6, condition = "SOLO", profile = "Affliction Solo", enabled = true}
                    }
                }
                WCS_BrainProfilesUI:RefreshAutoProfilesTab()
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Auto-Perfiles]|r Configuración restaurada")
                PlaySound("igMainMenuOptionCheckBoxOn")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true
    }
    StaticPopup_Show("WCS_BRAIN_RESET_AUTO_PROFILES")
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
local function OnLoad()
    WCS_BrainProfilesUI:Create()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700WCS Brain Profiles UI|r v" .. WCS_BrainProfilesUI.VERSION .. " cargado")
end

-- Registrar evento de carga
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnLoad)

