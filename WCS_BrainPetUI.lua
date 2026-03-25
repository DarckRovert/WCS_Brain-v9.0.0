--[[
    WCS_BrainPetUI.lua - Ventana de Gestion de Mascota
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version 6.4.2 - Boton mejorado con luz indicadora y pulso
]]--

WCS_BrainPetUI = WCS_BrainPetUI or {}
WCS_BrainPetUI.VERSION = "6.4.2"

-- Variables locales para el boton
local petPulseTimer = 0
-- Modo de IA disponible
local IA_MODES = { "Agresivo", "Defensivo", "Soporte", "Guardian" }
WCS_BrainPetUI.IAMode = 1  -- 1=Agresivo, 2=Defensivo, 3=Soporte, 4=Guardian
-- Variables para nuevas funcionalidades Fase 4
WCS_BrainPetUI.compactMode = false  -- Modo compacto/expandido
WCS_BrainPetUI.lastPetHealth = 0    -- Para detectar cambios bruscos
WCS_BrainPetUI.buffIcons = {}       -- Iconos de buffs
WCS_BrainPetUI.lowHealthWarned = false  -- Flag para advertencia de salud baja

-- Colores (definidos antes de usarse)
local PET_COLOR_PURPLE = {r=0.58, g=0.51, b=0.79} -- #9482C9
local PET_COLOR_GREEN = {r=0.0, g=1.0, b=0.5} -- Fel Green
local PET_COLOR_RED = {r=1.0, g=0.2, b=0.2} -- Emergency Red
local PET_COLOR_CYAN = {r=0.2, g=0.4, b=0.8} -- Magic Blue
local PET_COLOR_GOLD = {r=1.0, g=0.8, b=0.0} -- Prestige Gold


-- Funcion para flash de color al cambiar modo IA
function WCS_BrainPetUI:FlashModeChange()
    if not self.Button then return end
    
    local btn = self.Button
    local flashCount = 0
    local maxFlashes = 3
    
    local flashFrame = CreateFrame("Frame")
    local elapsed = 0
    flashFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 0.15 then
            elapsed = 0
            flashCount = flashCount + 1
            
            -- Alternar entre color normal y blanco
            if mod(flashCount, 2) == 0 then
                btn.border:SetVertexColor(1, 1, 1, 1)
            else
                local color = PET_COLOR_GREEN
                if WCS_BrainPetUI.IAMode == 1 then
                    color = PET_COLOR_RED
                elseif WCS_BrainPetUI.IAMode == 2 then
                    color = PET_COLOR_GREEN
                else
                    color = PET_COLOR_CYAN
                end
                btn.border:SetVertexColor(color.r, color.g, color.b, 1)
            end
            
            if flashCount >= maxFlashes * 2 then
                flashFrame:SetScript("OnUpdate", nil)
            end
        end
    end)
end


local PET_PULSE_SPEED = 2.5

-- Cache de datos de mascota para optimizacion
local petDataCache = {
    exists = false,
    name = "",
    health = 0,
    maxHealth = 0,
    mana = 0,
    maxMana = 0,
    lastUpdate = 0
}

local function UpdatePetDataCache()
    local now = GetTime()
    if now - petDataCache.lastUpdate < 0.5 then
        return -- No actualizar mas de 2 veces por segundo
    end
    
    petDataCache.exists = UnitExists("pet")
    if petDataCache.exists then
        petDataCache.name = UnitName("pet") or "Pet"
        petDataCache.health = UnitHealth("pet") or 0
        petDataCache.maxHealth = UnitHealthMax("pet") or 1
        petDataCache.mana = UnitMana("pet") or 0
        petDataCache.maxMana = UnitManaMax("pet") or 1
    end
    petDataCache.lastUpdate = now
end

-- ============================================================================
-- FASE 4: FUNCIONALIDAD 1 - Cambiar Modo IA con Click Derecho
-- ============================================================================
function WCS_BrainPetUI:CycleModeIA()
    if not UnitExists("pet") then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6666[WCS]|r No tienes mascota invocada")
        return
    end
    
    -- NUEVO: Detectar si target es un aliado
    if UnitExists("target") and UnitIsFriend("player", "target") and not UnitIsUnit("player", "target") then
        -- Target es un aliado (no el jugador mismo) -> Activar Modo Guardian
        local allyName = UnitName("target")
        
        if allyName then
            self.IAMode = 4  -- Modo Guardian
            
            -- Guardar el nombre del protegido
            if WCS_BrainPetAI then
                if WCS_BrainPetAI.SetGuardianTarget then
                    WCS_BrainPetAI:SetGuardianTarget(allyName)
                else
                    WCS_BrainPetAI.GuardianTarget = allyName
                end
            end
            
            -- Actualizar texto del indicador
            if self.Button and self.Button.iaModeText then
                self.Button.iaModeText:SetText("IA: Guardian")
            end
            
            -- Flash visual
            self:FlashModeChange()
            
            -- Mensaje en chat
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[WCS]|r Modo |cFFFFD700Guardian|r activado")
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[WCS]|r Pet protegiendo a: |cFF00FF00" .. allyName .. "|r")
            
            -- Integrar con WCS_BrainPetAI
            if WCS_BrainPetAI and WCS_BrainPetAI.SetMode then
                WCS_BrainPetAI:SetMode(4)
            end
            
            -- Hacer que la pet vaya al lado del aliado
            PetFollow()
            
            return
        end
    end
    
    -- Si no hay target aliado, ciclar entre modos normales (1, 2, 3)
    if self.IAMode == 4 then
        -- Si estaba en modo Guardian, volver a Agresivo
        self.IAMode = 1
    else
        -- Ciclar modo: 1 -> 2 -> 3 -> 1
        self.IAMode = self.IAMode + 1
        if self.IAMode > 3 then
            self.IAMode = 1
        end
    end
    
    local modeName = IA_MODES[self.IAMode]
    local modeColor = "|cFFFF0000"  -- Rojo para Agresivo
    if self.IAMode == 2 then
        modeColor = "|cFF00FF00"  -- Verde para Defensivo
    elseif self.IAMode == 3 then
        modeColor = "|cFF00CCFF"  -- Cyan para Soporte
    end
    
    -- Actualizar texto del indicador
    if self.Button and self.Button.iaModeText then
        self.Button.iaModeText:SetText("IA: " .. modeName)
    end
    
    -- Flash visual
    self:FlashModeChange()
    
    -- Mensaje en chat
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[WCS]|r Modo IA cambiado a: " .. modeColor .. modeName .. "|r")
    
    -- Limpiar GuardianTarget si salimos del modo Guardian
    if self.IAMode ~= 4 and WCS_BrainPetAI then
        WCS_BrainPetAI.GuardianTarget = nil
    end
    
    -- Integrar con WCS_BrainPetAI
    if WCS_BrainPetAI and WCS_BrainPetAI.SetMode then
        WCS_BrainPetAI:SetMode(self.IAMode)
    end
end

-- MENU CONTEXTUAL DEL BOTON
-- ============================================================================
function WCS_BrainPetUI:CreateContextMenu()
    if self.ContextMenu then
        if self.ContextMenu:IsVisible() then
            self.ContextMenu:Hide()
            return
        else
            self.ContextMenu:Show()
            return
        end
    end
    
    local menu = CreateFrame("Frame", "WCSBrainPetContextMenu", UIParent)
    menu:SetWidth(160)
    menu:SetHeight(90)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(200)
    
    if self.Button then
        menu:SetPoint("TOPLEFT", self.Button, "TOPRIGHT", 5, 0)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    menu:SetBackdropColor(0.1, 0.05, 0.15, 0.95)
    menu:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)
    
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", menu, "TOP", 0, -8)
    title:SetText("|cFFCC66FFOpciones|r")
    
    local configBtn = CreateFrame("Button", nil, menu)
    configBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -25)
    configBtn:SetWidth(140)
    configBtn:SetHeight(20)
    configBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    configBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    configBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    local configText = configBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configText:SetPoint("CENTER", configBtn, "CENTER", 0, 0)
    configText:SetText("ConfiguraciÃ³n")
    configBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowConfigWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    configBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    configBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    local statsBtn = CreateFrame("Button", nil, menu)
    statsBtn:SetPoint("TOPLEFT", configBtn, "BOTTOMLEFT", 0, -3)
    statsBtn:SetWidth(140)
    statsBtn:SetHeight(20)
    statsBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    statsBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    statsBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    local statsText = statsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("CENTER", statsBtn, "CENTER", 0, 0)
    statsText:SetText("EstadÃ­sticas")
    statsBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowStatsWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    statsBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    statsBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    local resetBtn = CreateFrame("Button", nil, menu)
    resetBtn:SetPoint("TOPLEFT", statsBtn, "BOTTOMLEFT", 0, -3)
    resetBtn:SetWidth(140)
    resetBtn:SetHeight(20)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    resetBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    resetBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetText("Resetear PosiciÃ³n")
    resetBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ResetButtonPosition()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    resetBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    resetBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    menu:EnableMouse(true)
    self.ContextMenu = menu
    menu:Show()
    
    local hideTimer = 0
    menu:SetScript("OnUpdate", function()
        hideTimer = hideTimer + arg1
        if hideTimer >= 10 then
            menu:Hide()
            hideTimer = 0
        end
    end)
    
    return menu
end

-- ============================================================================
-- VENTANA DE CONFIGURACION
-- ============================================================================
function WCS_BrainPetUI:LoadConfig()
    -- Inicializar tabla de configuraciÃ³n si no existe
    if not WCS_BrainCharSaved then
        WCS_BrainCharSaved = {}
    end
    
    if not WCS_BrainCharSaved.petUIConfig then
        WCS_BrainCharSaved.petUIConfig = {
            showNotifications = true,
            playSounds = true,
            autoFollow = false,
            compactMode = false
        }
    end
    
    -- Cargar configuraciÃ³n guardada
    local cfg = WCS_BrainCharSaved.petUIConfig
    self.showNotifications = cfg.showNotifications
    self.playSounds = cfg.playSounds
    self.autoFollow = cfg.autoFollow
    self.compactMode = cfg.compactMode
end

function WCS_BrainPetUI:SaveConfig()
    if not WCS_BrainCharSaved then
        WCS_BrainCharSaved = {}
    end
    
    WCS_BrainCharSaved.petUIConfig = {
        showNotifications = self.showNotifications or true,
        playSounds = self.playSounds or true,
        autoFollow = self.autoFollow or false,
        compactMode = self.compactMode or false
    }
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS Brain]|r ConfiguraciÃ³n guardada exitosamente")
    
    -- Aplicar configuraciones al sistema
    self:ApplyConfig()
end

function WCS_BrainPetUI:ApplyConfig()
    -- Aplicar modo compacto
    if self.Button then
        self:ToggleCompactMode(self.compactMode)
    end
    
    -- Aplicar auto-seguir si estÃ¡ activado
    if self.autoFollow and UnitExists("pet") then
        -- Integrar con PetAI para auto-seguir
        if WCS_BrainPetAI and WCS_BrainPetAI.SetAutoFollow then
            WCS_BrainPetAI:SetAutoFollow(true)
        else
            -- Fallback: usar comando bÃ¡sico de WoW
            PetFollow()
        end
    end
end

-- ============================================================================
-- ICONOS DE BUFFS - Muestra buffs activos en la mascota
-- ============================================================================
function WCS_BrainPetUI:CreateBuffIcons()
    if not self.Button then return end
    
    local btn = self.Button
    
    -- Crear contenedor para iconos de buffs
    self.buffIcons = {}
    
    -- Crear hasta 4 iconos de buffs pequeÃ±os
    for i = 1, 4 do
        local buffIcon = btn:CreateTexture(nil, "OVERLAY")
        buffIcon:SetWidth(12)
        buffIcon:SetHeight(12)
        
        -- Posicionar en fila horizontal arriba del botÃ³n
        local xOffset = -30 + (i - 1) * 14
        buffIcon:SetPoint("TOP", btn, "TOP", xOffset, 2)
        
        buffIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        buffIcon:Hide()
        
        self.buffIcons[i] = buffIcon
    end
end

function WCS_BrainPetUI:UpdateBuffIcons()
    if not self.buffIcons or not UnitExists("pet") then
        -- Ocultar todos los iconos si no hay mascota
        if self.buffIcons then
            for i = 1, 4 do
                if self.buffIcons[i] then
                    self.buffIcons[i]:Hide()
                end
            end
        end
        return
    end
    
    -- Escanear buffs de la mascota
    local buffCount = 0
    for i = 1, 16 do  -- MÃ¡ximo 16 buffs en WoW 1.12
        local buffTexture = UnitBuff("pet", i)
        if buffTexture then
            buffCount = buffCount + 1
            if buffCount <= 4 then
                self.buffIcons[buffCount]:SetTexture(buffTexture)
                self.buffIcons[buffCount]:Show()
            end
        end
    end
    
    -- Ocultar iconos no usados
    for i = buffCount + 1, 4 do
        self.buffIcons[i]:Hide()
    end
end

-- ============================================================================
-- BARRA DE FELICIDAD - Muestra felicidad de la mascota (para Hunters)
-- ============================================================================
function WCS_BrainPetUI:CreateHappinessBar()
    if not self.Button then return end
    
    local btn = self.Button
    
    -- Crear barra de felicidad pequeÃ±a
    local happyBar = CreateFrame("StatusBar", nil, btn)
    happyBar:SetWidth(50)
    happyBar:SetHeight(3)
    happyBar:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
    happyBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    happyBar:SetMinMaxValues(0, 3)  -- 1=Infeliz, 2=Contento, 3=Feliz
    happyBar:SetValue(3)
    happyBar:Hide()
    
    -- Fondo de la barra
    local bg = happyBar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetAllPoints(happyBar)
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
    
    self.happinessBar = happyBar
end

function WCS_BrainPetUI:UpdateHappinessBar()
    if not self.happinessBar or not UnitExists("pet") then
        if self.happinessBar then
            self.happinessBar:Hide()
        end
        return
    end
    
    -- GetPetHappiness() solo funciona para Hunters en WoW Classic
    -- Para Warlocks, no aplica, asÃ­ que ocultamos la barra
    local happiness, damagePercentage, loyaltyRate = GetPetHappiness()
    
    if happiness then
        self.happinessBar:SetValue(happiness)
        
        -- Colores segÃºn felicidad
        if happiness == 1 then
            -- Infeliz - Rojo
            self.happinessBar:SetStatusBarColor(1, 0, 0)
        elseif happiness == 2 then
            -- Contento - Amarillo
            self.happinessBar:SetStatusBarColor(1, 1, 0)
        else
            -- Feliz - Verde
            self.happinessBar:SetStatusBarColor(0, 1, 0)
        end
        
        self.happinessBar:Show()
    else
        -- No aplica (Warlock), ocultar
        self.happinessBar:Hide()
    end
end

-- ============================================================================
-- MONITOR DE EVENTOS - Detecta eventos importantes de la mascota
-- ============================================================================
function WCS_BrainPetUI:MonitorPetEvents()
    if not UnitExists("pet") then return end
    
    local currentHealth = UnitHealth("pet")
    local maxHealth = UnitHealthMax("pet")
    local healthPercent = (currentHealth / maxHealth) * 100
    
    -- Detectar cambio brusco de salud (daÃ±o crÃ­tico)
    if self.lastPetHealth > 0 then
        local healthDiff = self.lastPetHealth - currentHealth
        local healthDiffPercent = (healthDiff / maxHealth) * 100
        
        -- Si perdiÃ³ mÃ¡s del 30% de salud de golpe
        if healthDiffPercent > 30 then
            if self.showNotifications then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS]|r Â¡Mascota recibiÃ³ daÃ±o crÃ­tico! (" .. math.floor(healthDiffPercent) .. "%)")
            end
            if self.playSounds then
                PlaySound("RaidWarning")
            end
        end
    end
    
    -- Detectar salud crÃ­tica (< 20%)
    if healthPercent < 20 and healthPercent > 0 then
        -- Solo notificar una vez cuando baja de 20%
        if not self.lowHealthWarned then
            if self.showNotifications then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS]|r Â¡Mascota en peligro! Salud: " .. math.floor(healthPercent) .. "%")
            end
            if self.playSounds then
                PlaySound("RaidWarning")
            end
            self.lowHealthWarned = true
        end
    else
        self.lowHealthWarned = false
    end
    
    -- Guardar salud actual para prÃ³xima comparaciÃ³n
    self.lastPetHealth = currentHealth
end

-- ============================================================================
-- MODO COMPACTO - Reduce tamaÃ±o del botÃ³n y oculta elementos
-- ============================================================================
function WCS_BrainPetUI:ToggleCompactMode(enable)
    if not self.Button then return end
    
    local btn = self.Button
    
    if enable then
        -- MODO COMPACTO: BotÃ³n pequeÃ±o, solo Ã­cono y luz
        btn:SetWidth(40)
        btn:SetHeight(40)
        
        -- Ocultar elementos no esenciales
        if btn.petNameText then btn.petNameText:Hide() end
        if btn.statusText then btn.statusText:Hide() end
        if btn.iaModeText then btn.iaModeText:Hide() end
        if btn.hpBar then btn.hpBar:Hide() end
        if btn.manaBar then btn.manaBar:Hide() end
        
        -- Ajustar tamaÃ±o del Ã­cono
        if btn.bg then
            btn.bg:SetWidth(32)
            btn.bg:SetHeight(32)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[WCS]|r Modo Compacto activado")
    else
        -- MODO NORMAL: BotÃ³n grande con todos los elementos
        btn:SetWidth(64)
        btn:SetHeight(64)
        
        -- Mostrar todos los elementos
        if btn.petNameText then btn.petNameText:Show() end
        if btn.statusText then btn.statusText:Show() end
        if btn.iaModeText then btn.iaModeText:Show() end
        if btn.hpBar then btn.hpBar:Show() end
        if btn.manaBar then btn.manaBar:Show() end
        
        -- Restaurar tamaÃ±o del Ã­cono
        if btn.bg then
            btn.bg:SetWidth(56)
            btn.bg:SetHeight(56)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9370DB[WCS]|r Modo Normal activado")
    end
    
    -- Reproducir sonido
    PlaySound("igMainMenuOptionCheckBoxOn")
end

function WCS_BrainPetUI:ShowConfigWindow()
    if self.ConfigWindow then
        if self.ConfigWindow:IsVisible() then
            self.ConfigWindow:Hide()
        else
            -- Actualizar checkboxes con valores actuales antes de mostrar
            self:UpdateConfigWindow()
            self.ConfigWindow:Show()
        end
        return
    end
    
    -- Cargar configuraciÃ³n guardada
    self:LoadConfig()
    
    local window = CreateFrame("Frame", "WCSBrainConfigWindow", UIParent)
    window:SetWidth(300)
    window:SetHeight(250)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(100)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function() this:StartMoving() end)
    window:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    window:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    window:SetBackdropColor(0.05, 0.05, 0.1, 1)
    
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", window, "TOP", 0, -15)
    title:SetText("|cFFCC66FFConfiguraciÃ³n WCS Brain|r")
    
    local closeBtn = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() window:Hide() end)
    
    local yOffset = -50
    
    -- OpciÃ³n 1: Mostrar notificaciones
    local notifCheck = CreateFrame("CheckButton", "WCSConfigNotif", window, "UICheckButtonTemplate")
    notifCheck:SetPoint("TOPLEFT", window, "TOPLEFT", 20, yOffset)
    notifCheck:SetWidth(24)
    notifCheck:SetHeight(24)
    getglobal(notifCheck:GetName().."Text"):SetText("Mostrar notificaciones")
    notifCheck:SetChecked(self.showNotifications)
    notifCheck:SetScript("OnClick", function()
        WCS_BrainPetUI.showNotifications = this:GetChecked()
    end)
    window.notifCheck = notifCheck
    
    yOffset = yOffset - 35
    
    -- OpciÃ³n 2: Sonido de alerta
    local soundCheck = CreateFrame("CheckButton", "WCSConfigSound", window, "UICheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", window, "TOPLEFT", 20, yOffset)
    soundCheck:SetWidth(24)
    soundCheck:SetHeight(24)
    getglobal(soundCheck:GetName().."Text"):SetText("Sonido de alerta")
    soundCheck:SetChecked(self.playSounds)
    soundCheck:SetScript("OnClick", function()
        WCS_BrainPetUI.playSounds = this:GetChecked()
        -- Reproducir sonido de prueba
        if WCS_BrainPetUI.playSounds then
            PlaySound("igMainMenuOptionCheckBoxOn")
        end
    end)
    window.soundCheck = soundCheck
    
    yOffset = yOffset - 35
    
    -- OpciÃ³n 3: Auto-seguir al jugador
    local followCheck = CreateFrame("CheckButton", "WCSConfigFollow", window, "UICheckButtonTemplate")
    followCheck:SetPoint("TOPLEFT", window, "TOPLEFT", 20, yOffset)
    followCheck:SetWidth(24)
    followCheck:SetHeight(24)
    getglobal(followCheck:GetName().."Text"):SetText("Auto-seguir al jugador")
    followCheck:SetChecked(self.autoFollow)
    followCheck:SetScript("OnClick", function()
        WCS_BrainPetUI.autoFollow = this:GetChecked()
    end)
    window.followCheck = followCheck
    
    yOffset = yOffset - 35
    
    -- OpciÃ³n 4: Modo compacto
    local compactCheck = CreateFrame("CheckButton", "WCSConfigCompact", window, "UICheckButtonTemplate")
    compactCheck:SetPoint("TOPLEFT", window, "TOPLEFT", 20, yOffset)
    compactCheck:SetWidth(24)
    compactCheck:SetHeight(24)
    getglobal(compactCheck:GetName().."Text"):SetText("Modo compacto")
    compactCheck:SetChecked(self.compactMode)
    compactCheck:SetScript("OnClick", function()
        WCS_BrainPetUI.compactMode = this:GetChecked()
    end)
    window.compactCheck = compactCheck
    
    yOffset = yOffset - 50
    
    -- BotÃ³n Guardar
    local saveBtn = CreateFrame("Button", nil, window, "GameMenuButtonTemplate")
    saveBtn:SetPoint("BOTTOM", window, "BOTTOM", 0, 20)
    saveBtn:SetWidth(120)
    saveBtn:SetHeight(25)
    saveBtn:SetText("Guardar")
    saveBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:SaveConfig()
        -- Efecto visual de guardado
        PlaySound("igMainMenuOptionCheckBoxOn")
        window:Hide()
    end)
    
    self.ConfigWindow = window
    window:Show()
end

function WCS_BrainPetUI:UpdateConfigWindow()
    if not self.ConfigWindow then return end
    
    local win = self.ConfigWindow
    if win.notifCheck then win.notifCheck:SetChecked(self.showNotifications) end
    if win.soundCheck then win.soundCheck:SetChecked(self.playSounds) end
    if win.followCheck then win.followCheck:SetChecked(self.autoFollow) end
    if win.compactCheck then win.compactCheck:SetChecked(self.compactMode) end
end

-- ============================================================================
-- VENTANA DE ESTADISTICAS
-- ============================================================================
function WCS_BrainPetUI:ShowStatsWindow()
    if self.StatsWindow then
        if self.StatsWindow:IsVisible() then
            self.StatsWindow:Hide()
            -- Detener actualizaciÃ³n automÃ¡tica
            if self.statsUpdateTimer then
                self.statsUpdateTimer = nil
            end
        else
            self:UpdateStatsWindow()
            self.StatsWindow:Show()
            -- Iniciar actualizaciÃ³n automÃ¡tica
            self:StartStatsAutoUpdate()
        end
        return
    end
    
    local window = CreateFrame("Frame", "WCSBrainStatsWindow", UIParent)
    window:SetWidth(300)
    window:SetHeight(380)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(100)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function() this:StartMoving() end)
    window:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    window:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    window:SetBackdropColor(0.05, 0.05, 0.1, 1)
    
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", window, "TOP", 0, -15)
    title:SetText("|cFFCC66FFEstadÃ­sticas de Mascota|r")
    
    local closeBtn = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() 
        window:Hide()
        WCS_BrainPetUI.statsUpdateTimer = nil
    end)
    
    -- Crear textos de estadÃ­sticas
    local yOffset = -50
    local stats = {}
    
    local function CreateStatLine(label, value)
        local line = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetPoint("TOPLEFT", window, "TOPLEFT", 20, yOffset)
        line:SetText(label .. ": |cFFFFFFFF" .. value .. "|r")
        line:SetJustifyH("LEFT")
        yOffset = yOffset - 22
        return line
    end
    
    stats.name = CreateStatLine("Nombre", "---")
    stats.level = CreateStatLine("Nivel", "---")
    stats.health = CreateStatLine("Salud", "---")
    stats.mana = CreateStatLine("ManÃ¡/EnergÃ­a", "---")
    stats.happiness = CreateStatLine("Felicidad", "---")
    stats.loyalty = CreateStatLine("Lealtad", "---")
    stats.damage = CreateStatLine("DaÃ±o", "---")
    stats.armor = CreateStatLine("Armadura", "---")
    stats.attackSpeed = CreateStatLine("Vel. Ataque", "---")
    stats.mode = CreateStatLine("Modo IA", "---")
    stats.kills = CreateStatLine("Asesinatos", "---")
    stats.uptime = CreateStatLine("Tiempo activo", "---")
    
    yOffset = yOffset - 15
    
    -- Texto de actualizaciÃ³n automÃ¡tica
    local autoUpdateText = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoUpdateText:SetPoint("TOPLEFT", window, "TOPLEFT", 20, yOffset)
    autoUpdateText:SetText("|cFF888888ActualizaciÃ³n automÃ¡tica: 2s|r")
    autoUpdateText:SetJustifyH("LEFT")
    window.autoUpdateText = autoUpdateText
    
    yOffset = yOffset - 25
    
    local refreshBtn = CreateFrame("Button", nil, window, "GameMenuButtonTemplate")
    refreshBtn:SetPoint("BOTTOM", window, "BOTTOM", 0, 20)
    refreshBtn:SetWidth(120)
    refreshBtn:SetHeight(25)
    refreshBtn:SetText("Actualizar Ahora")
    refreshBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:UpdateStatsWindow()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    
    window.stats = stats
    self.StatsWindow = window
    self:UpdateStatsWindow()
    self:StartStatsAutoUpdate()
    window:Show()
end

function WCS_BrainPetUI:StartStatsAutoUpdate()
    if not self.StatsWindow or not self.StatsWindow:IsVisible() then return end
    
    self.statsUpdateTimer = 0
    local updateInterval = 2 -- Actualizar cada 2 segundos
    
    self.StatsWindow:SetScript("OnUpdate", function()
        WCS_BrainPetUI.statsUpdateTimer = (WCS_BrainPetUI.statsUpdateTimer or 0) + arg1
        
        if WCS_BrainPetUI.statsUpdateTimer >= updateInterval then
            WCS_BrainPetUI.statsUpdateTimer = 0
            WCS_BrainPetUI:UpdateStatsWindow()
        end
    end)
end

function WCS_BrainPetUI:UpdateStatsWindow()
    if not self.StatsWindow or not self.StatsWindow:IsVisible() then return end
    
    local stats = self.StatsWindow.stats
    if not stats then return end
    
    if not UnitExists("pet") then
        -- Sin mascota
        stats.name:SetText("Nombre: |cFFFF6666Sin mascota invocada|r")
        stats.level:SetText("Nivel: |cFF888888---|r")
        stats.health:SetText("Salud: |cFF888888---|r")
        stats.mana:SetText("ManÃ¡/EnergÃ­a: |cFF888888---|r")
        stats.happiness:SetText("Felicidad: |cFF888888---|r")
        stats.loyalty:SetText("Lealtad: |cFF888888---|r")
        stats.damage:SetText("DaÃ±o: |cFF888888---|r")
        stats.armor:SetText("Armadura: |cFF888888---|r")
        stats.attackSpeed:SetText("Vel. Ataque: |cFF888888---|r")
        stats.mode:SetText("Modo IA: |cFF888888---|r")
        stats.kills:SetText("Asesinatos: |cFF888888---|r")
        stats.uptime:SetText("Tiempo activo: |cFF888888---|r")
        return
    end
    
    -- Obtener informaciÃ³n de la mascota
    local petName = UnitName("pet") or "Mascota"
    local petLevel = UnitLevel("pet") or 0
    local petHealth = UnitHealth("pet") or 0
    local petHealthMax = UnitHealthMax("pet") or 1
    local petMana = UnitMana("pet") or 0
    local petManaMax = UnitManaMax("pet") or 1
    local petHappiness = GetPetHappiness() or 0
    local petLoyalty = GetPetLoyalty() or 0
    
    -- Actualizar nombre con color segÃºn clase
    local petClass = UnitClass("pet") or "Pet"
    stats.name:SetText("Nombre: |cFFFFD700" .. petName .. "|r")
    stats.level:SetText("Nivel: |cFFFFFFFF" .. petLevel .. "|r")
    
    -- Salud con color segÃºn porcentaje
    local hpPercent = math.floor((petHealth / petHealthMax) * 100)
    local hpColor = "|cFF00FF00"
    if hpPercent < 30 then
        hpColor = "|cFFFF0000"
    elseif hpPercent < 70 then
        hpColor = "|cFFFFFF00"
    end
    stats.health:SetText("Salud: " .. hpColor .. petHealth .. " / " .. petHealthMax .. " (" .. hpPercent .. "%)|r")
    
    -- ManÃ¡/EnergÃ­a
    if petManaMax > 0 then
        local manaPercent = math.floor((petMana / petManaMax) * 100)
        stats.mana:SetText("ManÃ¡/EnergÃ­a: |cFF00CCFF" .. petMana .. " / " .. petManaMax .. " (" .. manaPercent .. "%)|r")
    else
        stats.mana:SetText("ManÃ¡/EnergÃ­a: |cFF888888N/A|r")
    end
    
    -- Felicidad
    local happinessText = "Desconocida"
    if petHappiness == 1 then 
        happinessText = "|cFFFF0000Infeliz|r"
    elseif petHappiness == 2 then 
        happinessText = "|cFFFFFF00Contenta|r"
    elseif petHappiness == 3 then 
        happinessText = "|cFF00FF00Feliz|r"
    end
    stats.happiness:SetText("Felicidad: " .. happinessText)
    
    -- Lealtad
    local loyaltyText = petLoyalty > 0 and ("Nivel " .. petLoyalty) or "Desconocida"
    stats.loyalty:SetText("Lealtad: |cFFFFFFFF" .. loyaltyText .. "|r")
    
    -- EstadÃ­sticas de combate (intentar obtener reales)
    local baseDamage = UnitDamage("pet") or (petLevel * 2)
    local damageMax = baseDamage * 1.5
    stats.damage:SetText("DaÃ±o: |cFFFFFFFF" .. math.floor(baseDamage) .. " - " .. math.floor(damageMax) .. "|r")
    
    local armor = UnitArmor("pet") or (petLevel * 10)
    stats.armor:SetText("Armadura: |cFFFFFFFF" .. math.floor(armor) .. "|r")
    
    local attackSpeed = UnitAttackSpeed("pet") or 2.0
    stats.attackSpeed:SetText("Vel. Ataque: |cFFFFFFFF" .. string.format("%.2f", attackSpeed) .. "s|r")
    
    -- Modo IA
    local modeText = IA_MODES[WCS_BrainPetUI.IAMode] or "Desconocido"
    local modeColor = "|cFFFF0000"
    if WCS_BrainPetUI.IAMode == 2 then 
        modeColor = "|cFF00FF00"
    elseif WCS_BrainPetUI.IAMode == 3 then 
        modeColor = "|cFF00FFFF"
    end
    stats.mode:SetText("Modo IA: " .. modeColor .. modeText .. "|r")
    
    -- Asesinatos (intentar obtener de PetAI)
    local kills = 0
    if WCS_BrainPetAI and WCS_BrainPetAI.Stats and WCS_BrainPetAI.Stats.kills then
        kills = WCS_BrainPetAI.Stats.kills
    end
    stats.kills:SetText("Asesinatos: |cFFFFD700" .. kills .. "|r")
    
    -- Tiempo activo
    local uptime = GetTime() or 0
    local hours = math.floor(uptime / 3600)
    local minutes = math.floor((uptime - (hours * 3600)) / 60)
    local seconds = math.floor(uptime - (hours * 3600) - (minutes * 60))
    
    local uptimeStr = ""
    if hours > 0 then
        uptimeStr = hours .. "h " .. minutes .. "m " .. seconds .. "s"
    elseif minutes > 0 then
        uptimeStr = minutes .. "m " .. seconds .. "s"
    else
        uptimeStr = seconds .. "s"
    end
    stats.uptime:SetText("Tiempo activo: |cFFFFFFFF" .. uptimeStr .. "|r")
end

-- ============================================================================
-- RESETEAR POSICION DEL BOTON
-- ============================================================================
function WCS_BrainPetUI:ResetButtonPosition()
    if not self.Button then return end
    
    self.Button:ClearAllPoints()
    self.Button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS Brain]|r PosiciÃ³n del botÃ³n reseteada al centro")
    
    -- Flash visual para confirmar
    local btn = self.Button
    local flashCount = 0
    local flashFrame = CreateFrame("Frame")
    local elapsed = 0
    flashFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 0.1 then
            elapsed = 0
            flashCount = flashCount + 1
            
            if mod(flashCount, 2) == 0 then
                btn.border:SetVertexColor(1, 1, 1, 1)
            else
                btn.border:SetVertexColor(0, 1, 0, 1)
            end
            
            if flashCount >= 6 then
                flashFrame:SetScript("OnUpdate", nil)
                local color = PET_COLOR_GREEN
                if WCS_BrainPetUI.IAMode == 1 then
                    color = PET_COLOR_RED
                elseif WCS_BrainPetUI.IAMode == 2 then
                    color = PET_COLOR_GREEN
                elseif WCS_BrainPetUI.IAMode == 3 then
                    color = PET_COLOR_CYAN
                end
                btn.border:SetVertexColor(color.r, color.g, color.b, 1)
            end
        end
    end)
end


-- ============================================================================
-- MENU CONTEXTUAL DEL BOTON
-- ============================================================================
function WCS_BrainPetUI:CreateContextMenu()
    if self.ContextMenu then
        -- Si ya existe, solo mostrarlo/ocultarlo
        if self.ContextMenu:IsVisible() then
            self.ContextMenu:Hide()
            return
        else
            self.ContextMenu:Show()
            return
        end
    end
    
    -- Crear el frame del menu contextual
    local menu = CreateFrame("Frame", "WCSBrainPetContextMenu", UIParent)
    menu:SetWidth(160)
    menu:SetHeight(90)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(200)
    
    -- Posicionar cerca del boton
    if self.Button then
        menu:SetPoint("TOPLEFT", self.Button, "TOPRIGHT", 5, 0)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Backdrop del menu
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    menu:SetBackdropColor(0.1, 0.05, 0.15, 0.95)
    menu:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)
    
    -- Titulo del menu
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", menu, "TOP", 0, -8)
    title:SetText("|cFFCC66FFOpciones|r")
    
    -- Opcion 1: Configuracion
    local configBtn = CreateFrame("Button", nil, menu)
    configBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -25)
    configBtn:SetWidth(140)
    configBtn:SetHeight(20)
    
    configBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    configBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    configBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    
    local configText = configBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configText:SetPoint("CENTER", configBtn, "CENTER", 0, 0)
    configText:SetText("ConfiguraciÃ³n")
    
    configBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowConfigWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    
    configBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    
    configBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    -- Opcion 2: Estadisticas
    local statsBtn = CreateFrame("Button", nil, menu)
    statsBtn:SetPoint("TOPLEFT", configBtn, "BOTTOMLEFT", 0, -3)
    statsBtn:SetWidth(140)
    statsBtn:SetHeight(20)
    
    statsBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    statsBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    statsBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    
    local statsText = statsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("CENTER", statsBtn, "CENTER", 0, 0)
    statsText:SetText("EstadÃ­sticas")
    
    statsBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowStatsWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    
    statsBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    
    statsBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    -- Opcion 3: Resetear Posicion
    local resetBtn = CreateFrame("Button", nil, menu)
    resetBtn:SetPoint("TOPLEFT", statsBtn, "BOTTOMLEFT", 0, -3)
    resetBtn:SetWidth(140)
    resetBtn:SetHeight(20)
    
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    resetBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    resetBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetText("Resetear PosiciÃ³n")
    
    resetBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ResetButtonPosition()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    
    resetBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    
    resetBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    -- Cerrar menu al hacer click fuera
    menu:EnableMouse(true)
    menu:SetScript("OnMouseDown", function()
        -- No hacer nada, solo capturar el click
    end)
    
    -- Guardar referencia
    self.ContextMenu = menu
    menu:Show()
    
    -- Auto-ocultar despues de 10 segundos
    local hideTimer = 0
    menu:SetScript("OnUpdate", function()
        hideTimer = hideTimer + arg1
        if hideTimer >= 10 then
            menu:Hide()
            hideTimer = 0
        end
    end)
    
    return menu
end

-- ============================================================================
-- MENU CONTEXTUAL DEL BOTON
-- ============================================================================
function WCS_BrainPetUI:CreateContextMenu()
    if self.ContextMenu then
        -- Si ya existe, solo mostrarlo/ocultarlo
        if self.ContextMenu:IsVisible() then
            self.ContextMenu:Hide()
            return
        else
            self.ContextMenu:Show()
            return
        end
    end
    
    -- Crear el frame del menu contextual
    local menu = CreateFrame("Frame", "WCSBrainPetContextMenu", UIParent)
    menu:SetWidth(160)
    menu:SetHeight(90)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(200)
    
    -- Posicionar cerca del boton
    if self.Button then
        menu:SetPoint("TOPLEFT", self.Button, "TOPRIGHT", 5, 0)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Backdrop del menu
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    menu:SetBackdropColor(0.1, 0.05, 0.15, 0.95)
    menu:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)
    
    -- Titulo del menu
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", menu, "TOP", 0, -8)
    title:SetText("|cFFCC66FFOpciones|r")
    
    -- Opcion 1: Configuracion
    local configBtn = CreateFrame("Button", nil, menu)
    configBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -25)
    configBtn:SetWidth(140)
    configBtn:SetHeight(20)
    
    configBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    configBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    configBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    
    local configText = configBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configText:SetPoint("CENTER", configBtn, "CENTER", 0, 0)
    configText:SetText("ConfiguraciÃ³n")
    
    configBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowConfigWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    
    configBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    
    configBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    -- Opcion 2: Estadisticas
    local statsBtn = CreateFrame("Button", nil, menu)
    statsBtn:SetPoint("TOPLEFT", configBtn, "BOTTOMLEFT", 0, -3)
    statsBtn:SetWidth(140)
    statsBtn:SetHeight(20)
    
    statsBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    statsBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    statsBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    
    local statsText = statsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("CENTER", statsBtn, "CENTER", 0, 0)
    statsText:SetText("EstadÃ­sticas")
    
    statsBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowStatsWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    
    statsBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    
    statsBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    -- Opcion 3: Resetear Posicion
    local resetBtn = CreateFrame("Button", nil, menu)
    resetBtn:SetPoint("TOPLEFT", statsBtn, "BOTTOMLEFT", 0, -3)
    resetBtn:SetWidth(140)
    resetBtn:SetHeight(20)
    
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    resetBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    resetBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetText("Resetear PosiciÃ³n")
    
    resetBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ResetButtonPosition()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    
    resetBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    
    resetBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    -- Cerrar menu al hacer click fuera
    menu:EnableMouse(true)
    menu:SetScript("OnMouseDown", function()
        -- No hacer nada, solo capturar el click
    end)
    
    -- Guardar referencia
    self.ContextMenu = menu
    menu:Show()
    
    -- Auto-ocultar despues de 10 segundos
    local hideTimer = 0
    menu:SetScript("OnUpdate", function()
        hideTimer = hideTimer + arg1
        if hideTimer >= 10 then
            menu:Hide()
            hideTimer = 0
        end
    end)
    
    return menu
end

-- ============================================================================
-- MENU CONTEXTUAL DEL BOTON
-- ============================================================================
function WCS_BrainPetUI:CreateContextMenu()
    if self.ContextMenu then
        if self.ContextMenu:IsVisible() then
            self.ContextMenu:Hide()
            return
        else
            self.ContextMenu:Show()
            return
        end
    end
    
    local menu = CreateFrame("Frame", "WCSBrainPetContextMenu", UIParent)
    menu:SetWidth(160)
    menu:SetHeight(90)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(200)
    
    if self.Button then
        menu:SetPoint("TOPLEFT", self.Button, "TOPRIGHT", 5, 0)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    menu:SetBackdropColor(0.1, 0.05, 0.15, 0.95)
    menu:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)
    
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", menu, "TOP", 0, -8)
    title:SetText("|cFFCC66FFOpciones|r")
    
    local configBtn = CreateFrame("Button", nil, menu)
    configBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -25)
    configBtn:SetWidth(140)
    configBtn:SetHeight(20)
    configBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    configBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    configBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    local configText = configBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configText:SetPoint("CENTER", configBtn, "CENTER", 0, 0)
    configText:SetText("ConfiguraciÃ³n")
    configBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowConfigWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    configBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    configBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    local statsBtn = CreateFrame("Button", nil, menu)
    statsBtn:SetPoint("TOPLEFT", configBtn, "BOTTOMLEFT", 0, -3)
    statsBtn:SetWidth(140)
    statsBtn:SetHeight(20)
    statsBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    statsBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    statsBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    local statsText = statsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("CENTER", statsBtn, "CENTER", 0, 0)
    statsText:SetText("EstadÃ­sticas")
    statsBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ShowStatsWindow()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    statsBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    statsBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    local resetBtn = CreateFrame("Button", nil, menu)
    resetBtn:SetPoint("TOPLEFT", statsBtn, "BOTTOMLEFT", 0, -3)
    resetBtn:SetWidth(140)
    resetBtn:SetHeight(20)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    resetBtn:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    resetBtn:SetBackdropBorderColor(0.4, 0.3, 0.5, 1)
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetText("Resetear PosiciÃ³n")
    resetBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:ResetButtonPosition()
        WCS_BrainPetUI.ContextMenu:Hide()
    end)
    resetBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.35, 1)
    end)
    resetBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.2, 0.9)
    end)
    
    menu:EnableMouse(true)
    self.ContextMenu = menu
    menu:Show()
    
    local hideTimer = 0
    menu:SetScript("OnUpdate", function()
        hideTimer = hideTimer + arg1
        if hideTimer >= 10 then
            menu:Hide()
            hideTimer = 0
        end
    end)
    
    return menu
end





-- ============================================================================
-- BOTON FLOTANTE DE MASCOTA (Estilo mejorado)
-- ============================================================================
function WCS_BrainPetUI:CreatePetButton()
    if self.Button then return self.Button end
    
    local btn = CreateFrame("Button", "WCSBrainPetButton", UIParent)
    btn:SetWidth(64)
    btn:SetHeight(64)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(100)
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -200)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Textura de fondo (icono de mascota)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexture("Interface\\Icons\\Spell_Shadow_SummonImp")
    btn.bg = bg
    
    -- Borde brillante con efecto de pulso
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetWidth(72)
    border:SetHeight(72)
    border:SetPoint("CENTER", btn, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(PET_COLOR_PURPLE.r, PET_COLOR_PURPLE.g, PET_COLOR_PURPLE.b, 0.8)
    btn.border = border
    
    -- Luz indicadora (esquina superior derecha) - Textura compatible con 1.12
    local light = btn:CreateTexture(nil, "OVERLAY")
    light:SetWidth(14)
    light:SetHeight(14)
    light:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 2, 2)
    light:SetTexture("Interface\\Buttons\\UI-RadioButton")
    light:SetTexCoord(0, 0.25, 0, 1)  -- Solo el circulo
    light:SetVertexColor(0.5, 0.5, 0.5, 1)  -- Gris por defecto
    btn.light = light
    
    -- Texto de estado debajo
    local statusText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    statusText:SetText("PET")
    statusText:SetTextColor(PET_COLOR_PURPLE.r, PET_COLOR_PURPLE.g, PET_COLOR_PURPLE.b)
    btn.statusText = statusText
    
    -- Texto de nombre de mascota
    local petNameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petNameText:SetPoint("TOP", statusText, "BOTTOM", 0, -1)
    petNameText:SetText("---")
    petNameText:SetTextColor(PET_COLOR_GOLD.r, PET_COLOR_GOLD.g, PET_COLOR_GOLD.b)
    btn.petNameText = petNameText
    
    -- Indicador visual de modo de IA
    local iaModeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iaModeText:SetPoint("BOTTOM", btn, "TOP", 0, 6)
    iaModeText:SetText("IA: " .. IA_MODES[WCS_BrainPetUI.IAMode])
    iaModeText:SetTextColor(1, 0.85, 0.2)
    btn.iaModeText = iaModeText
    
    -- =============================
    -- Barras de vida y manÃ¡ (debajo del botÃ³n)
    -- =============================
    local hpBar = CreateFrame("StatusBar", nil, btn)
    hpBar:SetWidth(64)
    hpBar:SetHeight(7)
    hpBar:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hpBar:SetStatusBarColor(PET_COLOR_GREEN.r, PET_COLOR_GREEN.g, PET_COLOR_GREEN.b, 0.8)
    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints(hpBar)
    hpBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hpBg:SetVertexColor(0.2, 0.2, 0.2, 0.6)
    hpBar:SetMinMaxValues(0, 100)
    hpBar:SetValue(0)
    btn.hpBar = hpBar

    local manaBar = CreateFrame("StatusBar", nil, btn)
    manaBar:SetWidth(64)
    manaBar:SetHeight(7)
    manaBar:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -2)
    manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    manaBar:SetStatusBarColor(PET_COLOR_CYAN.r, PET_COLOR_CYAN.g, PET_COLOR_CYAN.b, 0.8)
    local manaBg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints(manaBar)
    manaBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    manaBg:SetVertexColor(0.2, 0.2, 0.2, 0.6)
    manaBar:SetMinMaxValues(0, 100)
    manaBar:SetValue(0)
    btn.manaBar = manaBar

    -- Tooltip
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cFFCC66FFGestion de Mascota|r |cFF00FF80v" .. WCS_BrainPetUI.VERSION .. "|r")
        GameTooltip:AddLine(" ")
        
        if UnitExists("pet") then
            -- InformaciÃ³n de la mascota
            local petName = UnitName("pet") or "Mascota"
            local petLevel = UnitLevel("pet") or 1
            GameTooltip:AddLine("|cFFFFD700" .. petName .. "|r |cFFFFFFFF(Nivel " .. petLevel .. ")|r", 1, 1, 1)
            
            -- Salud
            local hp = UnitHealth("pet") or 0
            local maxHp = UnitHealthMax("pet") or 1
            local hpPercent = math.floor((hp / maxHp) * 100)
            local hpColor = "|cFF00FF00"
            if hpPercent < 30 then
                hpColor = "|cFFFF0000"
            elseif hpPercent < 70 then
                hpColor = "|cFFFFFF00"
            end
            GameTooltip:AddLine("Salud: " .. hpColor .. hp .. "/" .. maxHp .. " (" .. hpPercent .. "%)|r", 1, 1, 1)
            
            -- ManÃ¡/EnergÃ­a
            local mana = UnitMana("pet") or 0
            local maxMana = UnitManaMax("pet") or 1
            if maxMana > 0 then
                local manaPercent = math.floor((mana / maxMana) * 100)
                GameTooltip:AddLine("Mana: |cFF00CCFF" .. mana .. "/" .. maxMana .. " (" .. manaPercent .. "%)|r", 1, 1, 1)
            end
            
            -- Modo IA
            if WCS_BrainPetAI_IsEnabled then
                local aiActive = WCS_BrainPetAI_IsEnabled()
                local aiStatus = aiActive and "|cFF00FF00ACTIVA|r" or "|cFFFF0000INACTIVA|r"
                local modeName = IA_MODES[WCS_BrainPetUI.IAMode] or "Desconocido"
                GameTooltip:AddLine("IA: " .. aiStatus .. " |cFFFFFFFF(Modo: " .. modeName .. ")|r", 1, 1, 1)
            end
            
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF888888Click Izquierdo: Abrir panel|r", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("|cFF888888Click Derecho: Hacer hablar|r", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("|cFF888888Arrastrar: Mover boton|r", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("|cFFFF6666Sin mascota invocada|r")
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF888888Click Izquierdo: Abrir panel|r", 0.7, 0.7, 0.7)
        end
        
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    btn:SetScript("OnClick", function()
        -- Feedback visual de click
        btn:SetAlpha(0.7)
        btn.border:SetAlpha(1.0)
        
        -- Restaurar despuÃ©s de 0.1 segundos
        local restoreFrame = CreateFrame("Frame")
        local elapsed = 0
        restoreFrame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 0.1 then
                btn:SetAlpha(1.0)
                restoreFrame:SetScript("OnUpdate", nil)
            end
        end)
        
        if arg1 == "LeftButton" then
            -- Shift+Click: Alternar modo compacto/expandido
            if IsShiftKeyDown() then
                -- WCS_BrainPetUI:ToggleCompactMode() -- TODO: Implementar en futuro
            else
                -- Click normal: Abrir panel maestro en la pestaña de Mascota
                if WCS_BrainUI and WCS_BrainUI.SelectTabByName then
                    WCS_BrainUI:SelectTabByName("Mascota")
                else
                    WCS_BrainPetUI:Toggle()
                end
            end
        elseif arg1 == "RightButton" then
            -- Shift+Click Derecho: Abrir menÃº contextual
            if IsShiftKeyDown() then
                WCS_BrainPetUI:CreateContextMenu()
            else
                -- Click derecho normal: Cambiar modo IA
                WCS_BrainPetUI:CycleModeIA()
            end
        end
    end)
    
    btn:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    
    btn:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        WCS_BrainPetUI:SaveButtonPosition()
    end)
    
    -- OnUpdate optimizado para animacion de pulso
    if WCS_UpdateManager then
        -- Usar UpdateManager centralizado para animaciones
        WCS_UpdateManager:RegisterCallback("animation", "PetUI_Pulse", function()
            petPulseTimer = petPulseTimer + 0.05 -- Frecuencia fija para animaciones
            WCS_BrainPetUI:UpdateButtonVisuals()
        end)
    else
        -- Fallback: OnUpdate local con throttling
        local pulseElapsed = 0
        btn:SetScript("OnUpdate", function()
            pulseElapsed = pulseElapsed + arg1
            if pulseElapsed >= 0.05 then -- 20 FPS para animaciones suaves
                pulseElapsed = 0
                petPulseTimer = petPulseTimer + 0.05
                WCS_BrainPetUI:UpdateButtonVisuals()
            end
        end)
    end
    
    self.Button = btn
    
    -- NO cargar posicion guardada por ahora - usar posicion fija
    self:LoadButtonPosition()
    
    -- IMPORTANTE: Mostrar el boton explicitamente (requerido en Lua 5.0)
    btn:Show()
    
    -- Debug: confirmar que el boton fue creado y mostrado
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[WCS PetUI]|r Boton creado en TOPLEFT (10, -200)")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[WCS PetUI]|r Visible: " .. tostring(btn:IsVisible()))
    
    
    -- Inicializar funcionalidades Fase 4
    self:CreateBuffIcons()
    self:CreateHappinessBar()
    
    return btn
end

-- ============================================================================
-- ACTUALIZAR VISUALES DEL BOTON (pulso y colores)
-- ============================================================================
function WCS_BrainPetUI:UpdateButtonVisuals()
    if not self.Button then return end
    
    local btn = self.Button
    
    -- Usar cache en lugar de llamada directa
    UpdatePetDataCache()
    local hasPet = petDataCache.exists
    local petAIActive = WCS_BrainPetAI_IsEnabled and WCS_BrainPetAI_IsEnabled()
    
    -- Determinar color segun estado
    local color = PET_COLOR_PURPLE
    local petName = "---"
    
    if not hasPet then
        -- Sin mascota - gris/apagado
        color = {r=0.4, g=0.4, b=0.4}
        btn.light:SetVertexColor(0.5, 0.5, 0.5, 1)  -- Gris
        btn.bg:SetTexture("Interface\\Icons\\Spell_Shadow_SummonImp")
    else
        petName = petDataCache.name
        
        -- Cambiar icono segun tipo de mascota
        local petIcon = "Interface\\Icons\\Spell_Shadow_SummonImp"
        local petType = nil
        
        -- Usar WCS_BrainPetAI:GetPetType() si esta disponible
        if WCS_BrainPetAI and WCS_BrainPetAI.GetPetType then
            petType = WCS_BrainPetAI:GetPetType()
        end
        
        -- Mapear tipo a icono
        if petType then
            local petTypeIcons = {
                ["Imp"] = "Interface\\Icons\\Spell_Shadow_SummonImp",
                ["Voidwalker"] = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
                ["Succubus"] = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
                ["Felhunter"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
                ["Felguard"] = "Interface\\Icons\\Spell_Shadow_SummonFelGuard",
                ["Infernal"] = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
                ["Doomguard"] = "Interface\\Icons\\Spell_Shadow_AntiShadow"
            }
            petIcon = petTypeIcons[petType] or petIcon
        end
        btn.bg:SetTexture(petIcon)
        
        
        -- Color del indicador segun modo de IA seleccionado
        if WCS_BrainPetUI.IAMode == 1 then
            -- Modo Agresivo - Rojo
            color = PET_COLOR_RED
            btn.light:SetVertexColor(1, 0, 0, 1)
        elseif WCS_BrainPetUI.IAMode == 2 then
            -- Modo Defensivo - Verde
            color = PET_COLOR_GREEN
            btn.light:SetVertexColor(0, 1, 0, 1)
        elseif WCS_BrainPetUI.IAMode == 3 then
            -- Modo Soporte - Cyan
            color = PET_COLOR_CYAN
            btn.light:SetVertexColor(0, 0.8, 1, 1)
        else
            -- Por defecto - Purpura
            color = PET_COLOR_PURPLE
            btn.light:SetVertexColor(0.8, 0.4, 1, 1)
        end
    end
    
    -- Animacion de pulso mejorada
    if hasPet then
        -- Calcular porcentaje de salud para efectos especiales
        local healthPercent = (petDataCache.health / petDataCache.maxHealth) * 100
        
        -- Pulso base mÃ¡s suave
        local pulseAlpha = 0.6 + 0.4 * math.sin(petPulseTimer * PET_PULSE_SPEED)
        
        -- Efecto glow cuando salud baja (< 30%)
        if healthPercent < 30 then
            -- Pulso rÃ¡pido y mÃ¡s intenso en peligro
            pulseAlpha = 0.7 + 0.3 * math.sin(petPulseTimer * PET_PULSE_SPEED * 2)
            color = PET_COLOR_RED
            btn.light:SetVertexColor(1, 0, 0, 1)  -- Rojo intenso
        elseif healthPercent < 70 then
            -- Pulso normal, color amarillo
            color = {r=1, g=1, b=0}
            btn.light:SetVertexColor(1, 1, 0, 1)
        end
        
        btn.border:SetAlpha(pulseAlpha)
        btn.border:SetVertexColor(color.r, color.g, color.b, pulseAlpha)
        
        -- Luz indicadora con pulso suave
        local lightAlpha = 0.8 + 0.2 * math.sin(petPulseTimer * PET_PULSE_SPEED * 1.5)
        btn.light:SetAlpha(lightAlpha)
    else
        -- Sin mascota - apagado
        btn.border:SetAlpha(0.3)
        btn.border:SetVertexColor(color.r, color.g, color.b, 0.3)
        btn.light:SetAlpha(0.4)
    end
    -- Animacion de pulso cuando hay mascota
    if hasPet then
        local alpha = 0.5 + 0.5 * math.sin(petPulseTimer * PET_PULSE_SPEED)
        btn.border:SetAlpha(alpha)
        btn.border:SetVertexColor(color.r, color.g, color.b, alpha)
        btn.light:SetAlpha(0.7 + 0.3 * math.sin(petPulseTimer * PET_PULSE_SPEED * 2))
    else
        btn.border:SetAlpha(0.3)
        btn.border:SetVertexColor(color.r, color.g, color.b, 0.3)
        btn.light:SetAlpha(0.5)
    end
    
    -- Actualizar textos
    btn.statusText:SetTextColor(color.r, color.g, color.b)
    
    -- Actualizar funcionalidades Fase 4
    self:UpdateBuffIcons()
    self:UpdateHappinessBar()
    self:MonitorPetEvents()
    btn.petNameText:SetText(petName)
    if hasPet then
        btn.petNameText:SetTextColor(PET_COLOR_GOLD.r, PET_COLOR_GOLD.g, PET_COLOR_GOLD.b)
        -- Actualizar barras de vida y manÃ¡
        local hp = petDataCache.health
        local hpMax = petDataCache.maxHealth
        if hpMax == 0 then hpMax = 1 end
        local hpPct = (hp / hpMax) * 100
        btn.hpBar:SetMinMaxValues(0, 100)
        btn.hpBar:SetValue(hpPct)
        btn.hpBar:Show()

        local mana = petDataCache.mana
        local manaMax = petDataCache.maxMana
        if manaMax == 0 then manaMax = 1 end
        local manaPct = (mana / manaMax) * 100
        btn.manaBar:SetMinMaxValues(0, 100)
        btn.manaBar:SetValue(manaPct)
        btn.manaBar:Show()
    else
        btn.petNameText:SetTextColor(0.5, 0.5, 0.5)
        btn.hpBar:SetValue(0)
        btn.hpBar:Hide()
        btn.manaBar:SetValue(0)
        btn.manaBar:Hide()
    end
end

-- ============================================================================
-- VENTANA PRINCIPAL DE GESTION
-- ============================================================================
function WCS_BrainPetUI:CreateWindow()
    if self.Window then return self.Window end
    
    local win = CreateFrame("Frame", "WCSBrainPetWindow", UIParent)
    win:SetWidth(320)
    win:SetHeight(400)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetFrameStrata("DIALOG")
    win:Hide()
    
    win:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    win:SetBackdropColor(0.1, 0.0, 0.15, 0.95)
    win:SetBackdropBorderColor(0.6, 0.3, 0.8, 1)
    
    -- Titulo
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", win, "TOP", 0, -10)
    title:SetText("|cFF9966FFGestion de Mascota|r")
    win.title = title
    
    -- Boton cerrar
    local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        WCS_BrainPetUI:Hide()
    end)
    
    -- Drag
    win:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    win:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    
    -- ========== SECCION INFO MASCOTA ==========
    local infoFrame = CreateFrame("Frame", nil, win)
    infoFrame:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -35)
    infoFrame:SetWidth(300)
    infoFrame:SetHeight(60)
    infoFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    infoFrame:SetBackdropColor(0.05, 0.0, 0.1, 0.8)
    infoFrame:SetBackdropBorderColor(0.4, 0.2, 0.6, 0.8)
    
    -- Icono mascota
    local petIcon = infoFrame:CreateTexture(nil, "ARTWORK")
    petIcon:SetWidth(40)
    petIcon:SetHeight(40)
    petIcon:SetPoint("LEFT", infoFrame, "LEFT", 10, 0)
    petIcon:SetTexture("Interface\\Icons\\Spell_Shadow_SummonImp")
    win.petIcon = petIcon
    
    -- Nombre mascota
    local petName = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petName:SetPoint("TOPLEFT", petIcon, "TOPRIGHT", 10, -5)
    petName:SetText("Sin mascota")
    petName:SetTextColor(1, 0.8, 0.5, 1)
    win.petName = petName
    
    -- Personalidad
    local petPersonality = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petPersonality:SetPoint("TOPLEFT", petName, "BOTTOMLEFT", 0, -3)
    petPersonality:SetText("Personalidad: ---")
    petPersonality:SetTextColor(0.7, 0.7, 0.7, 1)
    win.petPersonality = petPersonality
    
    -- Estado
    local petStatus = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petStatus:SetPoint("TOPLEFT", petPersonality, "BOTTOMLEFT", 0, -3)
    petStatus:SetText("Estado: ---")
    petStatus:SetTextColor(0.7, 0.7, 0.7, 1)
    win.petStatus = petStatus
    
    -- ========== SECCION BURBUJA ==========
    local bubbleLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bubbleLabel:SetPoint("TOPLEFT", infoFrame, "BOTTOMLEFT", 0, -15)
    bubbleLabel:SetText("|cFFFFCC00Configuracion de Burbuja|r")
    
    -- Toggle Burbuja
    local bubbleToggle = self:CreateCheckbox(win, "Mostrar burbuja", 10, -125)
    bubbleToggle:SetScript("OnClick", function()
        if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social then
            local checked = this:GetChecked()
            WCS_Brain.Pet.Social.Config.showBubble = (checked == 1) or (checked == true)
            local status = WCS_Brain.Pet.Social.Config.showBubble and "ON" or "OFF"
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Burbuja: " .. status)
        end
    end)
    win.bubbleToggle = bubbleToggle
    
    -- Toggle Typewriter
    local typeToggle = self:CreateCheckbox(win, "Efecto typewriter", 160, -125)
    typeToggle:SetScript("OnClick", function()
        if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social then
            local checked = this:GetChecked()
            WCS_Brain.Pet.Social.Config.bubbleTypewriter = (checked == 1) or (checked == true)
        end
    end)
    win.typeToggle = typeToggle
    
    -- Toggle Animaciones
    local animToggle = self:CreateCheckbox(win, "Animaciones", 10, -150)
    animToggle:SetScript("OnClick", function()
        if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social then
            local checked = this:GetChecked()
            WCS_Brain.Pet.Social.Config.bubbleAnimations = (checked == 1) or (checked == true)
        end
    end)
    win.animToggle = animToggle
    
    -- Posicion label
    local posLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    posLabel:SetPoint("TOPLEFT", win, "TOPLEFT", 15, -180)
    posLabel:SetText("Posicion:")
    
    -- Botones de posicion
    local posPet = self:CreateSmallButton(win, "Pet", 70, -177)
    posPet:SetScript("OnClick", function()
        if WCS_Brain_Pet_ConfigureBubble then
            WCS_Brain_Pet_ConfigureBubble("position", "pet")
        end
    end)
    
    local posCenter = self:CreateSmallButton(win, "Centro", 120, -177)
    posCenter:SetScript("OnClick", function()
        if WCS_Brain_Pet_ConfigureBubble then
            WCS_Brain_Pet_ConfigureBubble("position", "center")
        end
    end)
    
    local posTop = self:CreateSmallButton(win, "Arriba", 180, -177)
    posTop:SetScript("OnClick", function()
        if WCS_Brain_Pet_ConfigureBubble then
            WCS_Brain_Pet_ConfigureBubble("position", "top")
        end
    end)
    
    -- ========== SECCION PET AI ==========
    local aiLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aiLabel:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -210)
    aiLabel:SetText("|cFFFFCC00IA de Mascota|r")
    
    -- Toggle PetAI
    local aiToggle = self:CreateCheckbox(win, "IA Autonoma activa", 10, -230)
    aiToggle:SetScript("OnClick", function()
        if WCS_BrainPetAI then
            local checked = this:GetChecked()
            WCS_BrainPetAI.ENABLED = (checked == 1) or (checked == true)
            local status = WCS_BrainPetAI.ENABLED and "ON" or "OFF"
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r PetAI: " .. status)
        end
    end)
    win.aiToggle = aiToggle
    
    -- Toggle Agresivo
    local aggroToggle = self:CreateCheckbox(win, "Modo agresivo", 160, -230)
    aggroToggle:SetScript("OnClick", function()
        if WCS_BrainPetAI and WCS_BrainPetAI.Config then
            local checked = this:GetChecked()
            WCS_BrainPetAI.Config.aggressiveMode = (checked == 1) or (checked == true)
            local status = WCS_BrainPetAI.Config.aggressiveMode and "ON" or "OFF"
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Modo agresivo: " .. status)
        end
    end)
    win.aggroToggle = aggroToggle
    
    -- ========== SECCION SOCIAL ==========
    local socialLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    socialLabel:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -265)
    socialLabel:SetText("|cFFFFCC00Sistema Social|r")
    
    -- Toggle Social
    local socialToggle = self:CreateCheckbox(win, "Chat social activo", 10, -285)
    socialToggle:SetScript("OnClick", function()
        if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social then
            local checked = this:GetChecked()
            WCS_Brain.Pet.Social.Config.enabled = (checked == 1) or (checked == true)
            local status = WCS_Brain.Pet.Social.Config.enabled and "ON" or "OFF"
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Social: " .. status)
        end
    end)
    win.socialToggle = socialToggle
    
    -- Toggle Verbose
    local verboseToggle = self:CreateCheckbox(win, "Modo verbose", 160, -285)
    verboseToggle:SetScript("OnClick", function()
        if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social then
            local checked = this:GetChecked()
            WCS_Brain.Pet.Social.Config.verboseMode = (checked == 1) or (checked == true)
            local status = WCS_Brain.Pet.Social.Config.verboseMode and "ON" or "OFF"
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Modo verbose: " .. status)
        end
    end)
    win.verboseToggle = verboseToggle
    
    -- Palabras aprendidas
    local wordsLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wordsLabel:SetPoint("TOPLEFT", win, "TOPLEFT", 15, -310)
    wordsLabel:SetText("Palabras aprendidas: 0")
    win.wordsLabel = wordsLabel
    
    -- ========== BOTONES DE ACCION ==========
    local testBtn = self:CreateButton(win, "Probar Burbuja", 10, -340, 95)
    testBtn:SetScript("OnClick", function()
        if WCS_Brain_Pet_Say then
            WCS_Brain_Pet_Say("Esta es una prueba del sistema de burbuja!")
        end
    end)
    
    local talkBtn = self:CreateButton(win, "Hacer Hablar", 112, -340, 95)
    talkBtn:SetScript("OnClick", function()
        if WCS_Brain_Pet_Say and WCS_Brain_Pet_GetResponse then
            local response = WCS_Brain_Pet_GetResponse("greetings")
            if response then WCS_Brain_Pet_Say(response) end
        end
    end)
    
    local resetBtn = self:CreateButton(win, "Reset Palabras", 214, -340, 95)
    resetBtn:SetScript("OnClick", function()
        if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social then
            WCS_Brain.Pet.Social.LearnedWords = {}
            if WCS_Brain_Pet_SaveLearnedWords then
                WCS_Brain_Pet_SaveLearnedWords()
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Palabras reseteadas!")
        end
    end)
    
    -- Stats button
    local statsBtn = self:CreateButton(win, "Ver Estadisticas", 10, -370, 145)
    statsBtn:SetScript("OnClick", function()
        SlashCmdList["WCSSOCIAL"]("stats")
    end)
    
    -- Help button
    local helpBtn = self:CreateButton(win, "Ayuda Comandos", 164, -370, 145)
    helpBtn:SetScript("OnClick", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Comandos de Mascota ===")
        DEFAULT_CHAT_FRAME:AddMessage("/wcssocial - Comandos sociales")
        DEFAULT_CHAT_FRAME:AddMessage("/wcssocial bubble help - Ayuda burbuja")
        DEFAULT_CHAT_FRAME:AddMessage("/brainpet - Comandos PetAI")
        DEFAULT_CHAT_FRAME:AddMessage("/pettalk - Hacer hablar mascota")
        DEFAULT_CHAT_FRAME:AddMessage("/petui - Abrir/cerrar este panel")
    end)
    
    self.Window = win
    return win
end

-- ============================================================================
-- HELPERS PARA CREAR CONTROLES
-- ============================================================================
function WCS_BrainPetUI:CreateCheckbox(parent, text, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetWidth(24)
    cb:SetHeight(24)
    
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(text)
    cb.label = label
    
    return cb
end

function WCS_BrainPetUI:CreateButton(parent, text, x, y, width)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetWidth(width or 100)
    btn:SetHeight(22)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    btn:SetBackdropColor(0.2, 0.1, 0.3, 0.9)
    btn:SetBackdropBorderColor(0.5, 0.3, 0.7, 1)
    
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    btn.label = label
    
    btn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.3, 0.2, 0.5, 1)
    end)
    btn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.2, 0.1, 0.3, 0.9)
    end)
    
    
    -- Inicializar funcionalidades Fase 4
    -- self:CreateBuffIcons() -- TODO: Implementar en futuro
    -- self:CreateHappinessBar() -- TODO: Implementar en futuro
    
    return btn
end

function WCS_BrainPetUI:CreateSmallButton(parent, text, x, y)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetWidth(45)
    btn:SetHeight(18)
    
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    btn:SetBackdropColor(0.15, 0.1, 0.25, 0.9)
    btn:SetBackdropBorderColor(0.4, 0.3, 0.6, 1)
    
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(0.9, 0.9, 0.9, 1)
    btn.label = label
    
    btn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.15, 0.4, 1)
    end)
    btn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.1, 0.25, 0.9)
    end)
    
    
    -- Inicializar funcionalidades Fase 4
    -- self:CreateBuffIcons() -- TODO: Implementar en futuro
    -- self:CreateHappinessBar() -- TODO: Implementar en futuro
    
    return btn
end

-- ============================================================================
-- ACTUALIZACION DE UI
-- ============================================================================
function WCS_BrainPetUI:UpdateWindow()
    if not self.Window or not self.Window:IsVisible() then return end
    
    local win = self.Window
    
    -- Actualizar info de mascota
    if UnitExists("pet") then
        local name = UnitName("pet") or "Mascota"
        win.petName:SetText(name)
        
        -- Icono segun tipo
        local petType = "imp"
        if WCS_BrainPetAI and WCS_BrainPetAI.GetPetType then
            petType = string.lower(WCS_BrainPetAI:GetPetType() or "imp")
        end
        
        local icons = {
            ["imp"] = "Interface\\Icons\\Spell_Shadow_SummonImp",
            ["voidwalker"] = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
            ["succubus"] = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
            ["felhunter"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter"
        }
        win.petIcon:SetTexture(icons[petType] or icons["imp"])
        
        -- Personalidad
        local personality = "Desconocida"
        if WCS_Brain_Pet_GetPersonality then
            personality = WCS_Brain_Pet_GetPersonality()
        end
        win.petPersonality:SetText("Personalidad: |cFFFFFF00" .. personality .. "|r")
        
        -- Estado
        local maxHp = UnitHealthMax("pet") or 1
        if maxHp == 0 then maxHp = 1 end
        local hp = math.floor((UnitHealth("pet") / maxHp) * 100)
        win.petStatus:SetText("Salud: |cFF00FF00" .. hp .. "%|r")
    else
        win.petName:SetText("|cFF888888Sin mascota|r")
        win.petPersonality:SetText("Personalidad: ---")
        win.petStatus:SetText("Estado: ---")
        win.petIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    -- Actualizar checkboxes
    if WCS_Brain and WCS_Brain.Pet and WCS_Brain.Pet.Social and WCS_Brain.Pet.Social.Config then
        local cfg = WCS_Brain.Pet.Social.Config
        win.bubbleToggle:SetChecked(cfg.showBubble)
        win.typeToggle:SetChecked(cfg.bubbleTypewriter)
        win.animToggle:SetChecked(cfg.bubbleAnimations)
        win.socialToggle:SetChecked(cfg.enabled)
        win.verboseToggle:SetChecked(cfg.verboseMode)
        
        -- Contar palabras
        local count = 0
        if WCS_Brain.Pet.Social.LearnedWords then
            for k, v in pairs(WCS_Brain.Pet.Social.LearnedWords) do
                count = count + 1
            end
        end
        win.wordsLabel:SetText("Palabras aprendidas: |cFFFFD700" .. count .. "|r")
    end
    
    if WCS_BrainPetAI then
        win.aiToggle:SetChecked(WCS_BrainPetAI.ENABLED)
        if WCS_BrainPetAI.Config then
            win.aggroToggle:SetChecked(WCS_BrainPetAI.Config.aggressiveMode)
        end
    end
end



-- ============================================================================
-- GUARDAR/CARGAR POSICION
-- ============================================================================
function WCS_BrainPetUI:SaveButtonPosition()
    if not self.Button then return end
    
    local point, _, relPoint, x, y = self.Button:GetPoint()
    
    if not WCS_BrainCharSaved then
        WCS_BrainCharSaved = {}
    end
    
    WCS_BrainCharSaved.petButtonPos = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y
    }
end

function WCS_BrainPetUI:LoadButtonPosition()
    if not self.Button then return end
    if not WCS_BrainCharSaved or not WCS_BrainCharSaved.petButtonPos then return end
    
    local pos = WCS_BrainCharSaved.petButtonPos
    self.Button:ClearAllPoints()
    self.Button:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
end

-- ============================================================================
-- TOGGLE/SHOW/HIDE
-- ============================================================================
function WCS_BrainPetUI:Toggle()
    if WCS_BrainUI and WCS_BrainUI.MainFrame and WCS_BrainUI.MainFrame:IsVisible() and WCS_BrainUI.tabDataList and WCS_BrainUI.MainFrame.currentTab then
        if WCS_BrainUI.tabDataList[WCS_BrainUI.MainFrame.currentTab].name == "Mascota" then
            WCS_BrainUI:Toggle()
            return
        end
    end
    
    if self.Window and self.Window:IsVisible() and (not WCS_BrainUI or not WCS_BrainUI.MainFrame or not WCS_BrainUI.MainFrame:IsVisible()) then
        self:Hide()
    else
        self:Show()
    end
end

function WCS_BrainPetUI:Show()
    if WCS_BrainUI and WCS_BrainUI.SelectTabByName then
        WCS_BrainUI:SelectTabByName("Mascota")
        if not self.Window then self:CreateWindow() end
        self:UpdateWindow()
    else
        if not self.Window then
            self:CreateWindow()
        end
        if self.Window then
            self.Window:Show()
            self:UpdateWindow()
        end
    end
end

function WCS_BrainPetUI:Hide()
    if self.Window then
        self.Window:Hide()
    end
end

function WCS_BrainPetUI:ToggleButton()
    if not self.Button then
        self:CreateButton()
    end
    
    if self.Button then
        if self.Button:IsVisible() then
            self.Button:Hide()
        else
            self.Button:Show()
        end
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_PETUI1 = "/petui"
SlashCmdList["PETUI"] = function(msg)
    WCS_BrainPetUI:Toggle()
end

SLASH_PETBTN1 = "/petbtn"
SlashCmdList["PETBTN"] = function(msg)
    WCS_BrainPetUI:ToggleButton()
end

-- ============================================================================
-- INICIALIZACION - Diferida para Lua 5.0 / WoW 1.12
-- ============================================================================
local initFrame = CreateFrame("Frame", "WCSBrainPetUIInit", UIParent)
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("UNIT_PET")
initFrame:RegisterEvent("UNIT_HEALTH")
initFrame:RegisterEvent("PLAYER_PET_CHANGED")
initFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not WCS_BrainPetUI.initialized then
            WCS_BrainPetUI.initialized = true
            WCS_BrainPetUI:CreatePetButton()
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r PetUI Button cargado")
        end
    elseif event == "UNIT_PET" or event == "UNIT_HEALTH" or event == "PLAYER_PET_CHANGED" then
        -- Forzar actualizacion del cache
        petDataCache.lastUpdate = 0
        if WCS_BrainPetUI.Button then
            WCS_BrainPetUI:UpdateButtonVisuals()
        end
    end
end)


-- ============================================================================
-- CREAR BOTON DE MASCOTA (Version mejorada)
-- ============================================================================



