-- WCS_BrainThinkingButton.lua
-- Boton flotante para el sistema Thinking UI
-- Compatible con Lua 5.0 (WoW 1.12) - SOLO ASCII

WCS_BrainThinkingButton = {}

-- Variables locales
local button = nil
local pulseTimer = 0
local PULSE_SPEED = 2
local saveTimer = 0
local updateTimer = 0
local UPDATE_INTERVAL = 0.05  -- Throttling: 20 FPS en lugar de 60 FPS

local SAVE_INTERVAL = 5

-- Colores
local COLOR_PURPLE = {r=0.58, g=0.51, b=0.79}
local COLOR_FEL = {r=0.0, g=1.0, b=0.5}
local COLOR_GOLD = {r=1.0, g=0.82, b=0.0}
local COLOR_RED = {r=1, g=0.2, b=0.2}

-- Configuracion por defecto
local defaultConfig = {
    point = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    xOffset = 100,
    yOffset = -200,
    visible = true
}

-- Funcion para obtener configuracion
local function GetConfig()
    if not WCS_BrainThinkingButtonConfig then
        WCS_BrainThinkingButtonConfig = {}
        for k, v in pairs(defaultConfig) do
            WCS_BrainThinkingButtonConfig[k] = v
        end
    end
    return WCS_BrainThinkingButtonConfig
end

-- Funcion para crear el boton
function WCS_BrainThinkingButton:CreateButton()
    if button then
        return button
    end
    
    -- Crear el boton
    button = CreateFrame("Button", "WCS_BrainThinkingFloatingButton", UIParent)
    button:SetWidth(64)
    button:SetHeight(64)
    button:SetFrameStrata("HIGH")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Textura de fondo
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetTexture("Interface\\AddOns\\WCS_Brain\\Textures\\ThinkingButton")
    if not bg:GetTexture() then
        -- Si no existe la textura personalizada, usar una por defecto
        bg:SetTexture("Interface\\Icons\\Spell_Shadow_Charm")
    end
    button.bg = bg
    
    -- Borde brillante
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(72)
    border:SetHeight(72)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.8)
    button.border = border
    
    -- Texto de estado
    local statusText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOM", button, "BOTTOM", 0, -15)
    statusText:SetText("THINKING")
    statusText:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    button.statusText = statusText
    
    -- Restaurar posicion guardada
    local config = GetConfig()
    button:ClearAllPoints()
    button:SetPoint(
        config.point,
        config.relativeTo,
        config.relativePoint,
        config.xOffset,
        config.yOffset
    )
    
    -- Mostrar/ocultar segun configuracion
    if config.visible then
        button:Show()
    else
        button:Hide()
    end
    
    -- Script de arrastre
    button:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        WCS_BrainThinkingButton:SavePosition()
    end)
    
    -- Script de click
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            -- Click izquierdo: Abrir interfaz
            if WCS_BrainThinkingUI then
                WCS_BrainThinkingUI:Toggle()
            end
        elseif arg1 == "RightButton" then
            -- Click derecho: Menu de opciones
            WCS_BrainThinkingButton:ShowMenu()
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        WCS_BrainThinkingButton:ShowTooltip()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Script de actualizacion (animacion de pulso)
    button:SetScript("OnUpdate", function()
        updateTimer = updateTimer + arg1
        
        -- Throttling: Solo actualizar cada 0.05s (20 FPS)
        if updateTimer < UPDATE_INTERVAL then
            return
        end
        
        pulseTimer = pulseTimer + updateTimer
        saveTimer = saveTimer + updateTimer
        updateTimer = 0
        
        -- Animacion de pulso cuando esta visible
        if WCS_BrainThinkingUI and WCS_BrainThinkingUI.isShowing then
            local alpha = 0.5 + 0.5 * math.sin(pulseTimer * PULSE_SPEED)
            button.border:SetAlpha(alpha)
            button.border:SetVertexColor(COLOR_FEL.r, COLOR_FEL.g, COLOR_FEL.b, alpha)
            button.statusText:SetTextColor(COLOR_FEL.r, COLOR_FEL.g, COLOR_FEL.b)
        else
            button.border:SetAlpha(0.3)
            button.border:SetVertexColor(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.3)
            button.statusText:SetTextColor(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
        end
        
        -- Auto-guardar posicion cada 5 segundos
        if saveTimer >= SAVE_INTERVAL then
            saveTimer = 0
            WCS_BrainThinkingButton:SavePosition()
        end
    end)
    
    return button
end

-- Funcion para guardar la posicion
function WCS_BrainThinkingButton:SavePosition()
    if not button then
        return
    end
    
    local config = GetConfig()
    local point, relativeTo, relativePoint, xOffset, yOffset = button:GetPoint()
    
    config.point = point or "CENTER"
    config.relativeTo = "UIParent"
    config.relativePoint = relativePoint or "CENTER"
    config.xOffset = xOffset or 100
    config.yOffset = yOffset or -200
end

-- Funcion para mostrar el tooltip
function WCS_BrainThinkingButton:ShowTooltip()
    if not button then
        return
    end
    
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("WCS Brain - Thinking UI", COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
    GameTooltip:AddLine("|cFFAAAAAAConsola de Razonamiento v9.0|r", 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    if WCS_BrainThinkingUI then
        GameTooltip:AddLine("ESTADO: |cFF00FF00CONECTADO|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Visualiza en tiempo real los", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("procesos cognitivos de la IA.", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Sistema no disponible", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFD700Click Izquierdo:|r Abrir Consola", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700Click Derecho:|r Menu de Sistema", 1, 1, 1)
    GameTooltip:AddLine("|cFF888888Arrastrar para mover|r", 1, 1, 1)
    
    GameTooltip:Show()
end

-- Funcion para mostrar el menu de opciones
function WCS_BrainThinkingButton:ShowMenu()
    if not button then
        return
    end
    
    -- Crear menu contextual simple
    local menu = {}
    
    if WCS_BrainThinkingUI then
        if WCS_BrainThinkingUI.isShowing then
            table.insert(menu, {
                text = "Cerrar Thinking UI",
                func = function()
                    if WCS_BrainThinkingUI.Hide then
                        WCS_BrainThinkingUI:Hide()
                    end
                end
            })
        else
            table.insert(menu, {
                text = "Abrir Thinking UI",
                func = function()
                    if WCS_BrainThinkingUI.Show then
                        WCS_BrainThinkingUI:Show()
                    end
                end
            })
        end
        
        table.insert(menu, {
            text = "Limpiar Pensamientos",
            func = function()
                if WCS_BrainThinkingUI.ClearThoughts then
                    WCS_BrainThinkingUI:ClearThoughts()
                    DEFAULT_CHAT_FRAME:AddMessage("Thinking: Pensamientos limpiados", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                end
            end
        })
        
        -- Opciones de configuracion
        if WCS_BrainThinkingUI.Config then
            if WCS_BrainThinkingUI.Config.showDPS then
                table.insert(menu, {
                    text = "Ocultar DPS",
                    func = function()
                        WCS_BrainThinkingUI.Config.showDPS = false
                        DEFAULT_CHAT_FRAME:AddMessage("Thinking: DPS ocultado", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                    end
                })
            else
                table.insert(menu, {
                    text = "Mostrar DPS",
                    func = function()
                        WCS_BrainThinkingUI.Config.showDPS = true
                        DEFAULT_CHAT_FRAME:AddMessage("Thinking: DPS visible", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                    end
                })
            end
            
            if WCS_BrainThinkingUI.Config.showTTK then
                table.insert(menu, {
                    text = "Ocultar TTK",
                    func = function()
                        WCS_BrainThinkingUI.Config.showTTK = false
                        DEFAULT_CHAT_FRAME:AddMessage("Thinking: TTK ocultado", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                    end
                })
            else
                table.insert(menu, {
                    text = "Mostrar TTK",
                    func = function()
                        WCS_BrainThinkingUI.Config.showTTK = true
                        DEFAULT_CHAT_FRAME:AddMessage("Thinking: TTK visible", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                    end
                })
            end
        end
    end
    
    table.insert(menu, {
        text = "Ocultar Boton",
        func = function()
            WCS_BrainThinkingButton:Hide()
        end
    })
    
    table.insert(menu, {
        text = "Cancelar",
        func = function() end
    })
    
    -- Mostrar menu usando el sistema de WoW
    for i, item in ipairs(menu) do
        DEFAULT_CHAT_FRAME:AddMessage(i .. ". " .. item.text, 1, 1, 0)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("Usa /thinkingmenu <numero> para seleccionar", 0.7, 0.7, 0.7)
    
    -- Guardar menu para comando
    WCS_BrainThinkingButton.currentMenu = menu
end

-- Funcion para mostrar el boton
function WCS_BrainThinkingButton:Show()
    if not button then
        self:CreateButton()
    end
    button:Show()
    local config = GetConfig()
    config.visible = true
end

-- Funcion para ocultar el boton
function WCS_BrainThinkingButton:Hide()
    if button then
        button:Hide()
    end
    local config = GetConfig()
    config.visible = false
end

-- Funcion para alternar visibilidad
function WCS_BrainThinkingButton:Toggle()
    if not button then
        self:CreateButton()
    end
    
    if button:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

-- Comando slash para el boton
SLASH_THINKINGBUTTON1 = "/thinkingbutton"
SlashCmdList["THINKINGBUTTON"] = function(msg)
    if msg == "show" then
        WCS_BrainThinkingButton:Show()
        DEFAULT_CHAT_FRAME:AddMessage("Thinking: Boton mostrado", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    elseif msg == "hide" then
        WCS_BrainThinkingButton:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("Thinking: Boton ocultado", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    elseif msg == "toggle" then
        WCS_BrainThinkingButton:Toggle()
    elseif msg == "reset" then
        local config = GetConfig()
        config.point = "CENTER"
        config.relativeTo = "UIParent"
        config.relativePoint = "CENTER"
        config.xOffset = 100
        config.yOffset = -200
        if button then
            button:ClearAllPoints()
            button:SetPoint("CENTER", UIParent, "CENTER", 100, -200)
        end
        DEFAULT_CHAT_FRAME:AddMessage("Thinking: Posicion del boton reseteada", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Comandos del boton Thinking:", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
        DEFAULT_CHAT_FRAME:AddMessage("  /thinkingbutton show - Mostrar boton", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /thinkingbutton hide - Ocultar boton", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /thinkingbutton toggle - Alternar visibilidad", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /thinkingbutton reset - Resetear posicion", 1, 1, 1)
    end
end

-- Comando para seleccionar opcion del menu
SLASH_THINKINGMENU1 = "/thinkingmenu"
SlashCmdList["THINKINGMENU"] = function(msg)
    local num = tonumber(msg)
    if num and WCS_BrainThinkingButton.currentMenu and WCS_BrainThinkingButton.currentMenu[num] then
        WCS_BrainThinkingButton.currentMenu[num].func()
        WCS_BrainThinkingButton.currentMenu = nil
    else
        DEFAULT_CHAT_FRAME:AddMessage("Uso: /thinkingmenu <numero>", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    end
end

-- Inicializacion automatica
local function Initialize()
    WCS_BrainThinkingButton:CreateButton()
    DEFAULT_CHAT_FRAME:AddMessage("WCS_BrainThinkingButton cargado. Usa /thinkingbutton para opciones.", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
end

-- Registrar evento de carga
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" or event == "VARIABLES_LOADED" then
        Initialize()
        this:UnregisterAllEvents()
    end
end)

