-- WCS_BrainDQNButton.lua
-- Boton flotante para el sistema DQN
-- Compatible con Lua 5.0 (WoW 1.12) - SOLO ASCII

WCS_BrainDQNButton = {}

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
    xOffset = 0,
    yOffset = -200,
    visible = true
}

-- Funcion para obtener configuracion
local function GetConfig()
    if not WCS_BrainDQNButtonConfig then
        WCS_BrainDQNButtonConfig = {}
        for k, v in pairs(defaultConfig) do
            WCS_BrainDQNButtonConfig[k] = v
        end
    end
    return WCS_BrainDQNButtonConfig
end

-- Funcion para crear el boton
function WCS_BrainDQNButton:CreateButton()
    if button then
        return button
    end
    
    -- Crear el boton
    button = CreateFrame("Button", "WCS_BrainDQNFloatingButton", UIParent)
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
    bg:SetTexture("Interface\\AddOns\\WCS_Brain\\Textures\\DQNButton")
    if not bg:GetTexture() then
        -- Si no existe la textura personalizada, usar una por defecto
        bg:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
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
    statusText:SetText("CONEXION")
    statusText:SetTextColor(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
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
        WCS_BrainDQNButton:SavePosition()
    end)
    
    -- Script de click
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            -- Click izquierdo: Abrir pestaña técnica en WCS_BrainUI
            if WCS_BrainUI and WCS_BrainUI.SelectTabByName then
                WCS_BrainUI:SelectTabByName("DQN")
            end
        elseif arg1 == "RightButton" then
            -- Click derecho: Menu de opciones
            WCS_BrainDQNButton:ShowMenu()
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        WCS_BrainDQNButton:ShowTooltip()
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
        
        -- Animacion de pulso cuando esta activo
        if WCS_BrainDQN and WCS_BrainDQN.enabled then
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
            WCS_BrainDQNButton:SavePosition()
        end
    end)
    
    return button
end

-- Funcion para guardar la posicion
function WCS_BrainDQNButton:SavePosition()
    if not button then
        return
    end
    
    local config = GetConfig()
    local point, relativeTo, relativePoint, xOffset, yOffset = button:GetPoint()
    
    config.point = point or "CENTER"
    config.relativeTo = "UIParent"
    config.relativePoint = relativePoint or "CENTER"
    config.xOffset = xOffset or 0
    config.yOffset = yOffset or -200
end

-- Funcion para mostrar el tooltip
function WCS_BrainDQNButton:ShowTooltip()
    if not button then
        return
    end
    
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("WCS Brain - DQN Node", COLOR_FEL.r, COLOR_FEL.g, COLOR_FEL.b)
    GameTooltip:AddLine("|cFFAAAAAASistema Deep Q-Learning v9.0|r", 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    if WCS_BrainDQN then
        if WCS_BrainDQN.enabled then
            GameTooltip:AddLine("RED NEURONAL: |cFF00FF00ACTIVA|r", 1, 1, 1)
        else
            GameTooltip:AddLine("RED NEURONAL: |cFFFF4444INACTIVA|r", 1, 1, 1)
        end
        
        if WCS_BrainDQN.Stats then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("Episodios: |cFFFFCC00%d|r", WCS_BrainDQN.Stats.episodes or 0), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(string.format("Recompensa: |cFF00FF80%.2f|r", WCS_BrainDQN.Stats.totalReward or 0), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(string.format("Epsilon: |cFF9482C9%.4f|r", WCS_BrainDQN.Config.epsilon or 1), 0.8, 0.8, 0.8)
        end
    else
        GameTooltip:AddLine("Sistema no disponible", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFD700Click Izquierdo:|r Abrir Matriz DQN", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700Click Derecho:|r Menu de Red", 1, 1, 1)
    GameTooltip:AddLine("|cFF888888Arrastrar para mover|r", 1, 1, 1)
    
    GameTooltip:Show()
end

-- Funcion para mostrar el menu de opciones
function WCS_BrainDQNButton:ShowMenu()
    if not button then
        return
    end
    
    -- Crear menu contextual simple
    local menu = {}
    
    if WCS_BrainDQN then
        if WCS_BrainDQN.enabled then
            table.insert(menu, {
                text = "Desactivar DQN",
                func = function()
                    if WCS_BrainDQN.ToggleDQN then
                        WCS_BrainDQN:ToggleDQN()
                    end
                end
            })
        else
            table.insert(menu, {
                text = "Activar DQN",
                func = function()
                    if WCS_BrainDQN.ToggleDQN then
                        WCS_BrainDQN:ToggleDQN()
                    end
                end
            })
        end
        
        table.insert(menu, {
            text = "Abrir Interfaz",
            func = function()
                if WCS_BrainUI and WCS_BrainUI.SelectTabByName then
                    WCS_BrainUI:SelectTabByName("DQN")
                end
            end
        })
        
        table.insert(menu, {
            text = "Ver Estadisticas",
            func = function()
                if WCS_BrainDQN.PrintStats then
                    WCS_BrainDQN:PrintStats()
                end
            end
        })
        
        table.insert(menu, {
            text = "Guardar Red",
            func = function()
                if WCS_BrainDQN.SaveNetwork then
                    WCS_BrainDQN:SaveNetwork()
                    DEFAULT_CHAT_FRAME:AddMessage("DQN: Red neuronal guardada", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                end
            end
        })
        
        table.insert(menu, {
            text = "Resetear Red",
            func = function()
                if WCS_BrainDQN.ResetNetwork then
                    WCS_BrainDQN:ResetNetwork()
                    DEFAULT_CHAT_FRAME:AddMessage("DQN: Red neuronal reseteada", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
                end
            end
        })
    end
    
    table.insert(menu, {
        text = "Ocultar Boton",
        func = function()
            WCS_BrainDQNButton:Hide()
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
    
    DEFAULT_CHAT_FRAME:AddMessage("Usa /dqnmenu <numero> para seleccionar", 0.7, 0.7, 0.7)
    
    -- Guardar menu para comando
    WCS_BrainDQNButton.currentMenu = menu
end

-- Funcion para mostrar el boton
function WCS_BrainDQNButton:Show()
    if not button then
        self:CreateButton()
    end
    button:Show()
    local config = GetConfig()
    config.visible = true
end

-- Funcion para ocultar el boton
function WCS_BrainDQNButton:Hide()
    if button then
        button:Hide()
    end
    local config = GetConfig()
    config.visible = false
end

-- Funcion para alternar visibilidad
function WCS_BrainDQNButton:Toggle()
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
SLASH_DQNBUTTON1 = "/dqnbutton"
SlashCmdList["DQNBUTTON"] = function(msg)
    if msg == "show" then
        WCS_BrainDQNButton:Show()
        DEFAULT_CHAT_FRAME:AddMessage("DQN: Boton mostrado", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    elseif msg == "hide" then
        WCS_BrainDQNButton:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("DQN: Boton ocultado", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    elseif msg == "toggle" then
        WCS_BrainDQNButton:Toggle()
    elseif msg == "reset" then
        local config = GetConfig()
        config.point = "CENTER"
        config.relativeTo = "UIParent"
        config.relativePoint = "CENTER"
        config.xOffset = 0
        config.yOffset = -200
        if button then
            button:ClearAllPoints()
            button:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        end
        DEFAULT_CHAT_FRAME:AddMessage("DQN: Posicion del boton reseteada", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Comandos del boton DQN:", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
        DEFAULT_CHAT_FRAME:AddMessage("  /dqnbutton show - Mostrar boton", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /dqnbutton hide - Ocultar boton", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /dqnbutton toggle - Alternar visibilidad", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("  /dqnbutton reset - Resetear posicion", 1, 1, 1)
    end
end

-- Comando para seleccionar opcion del menu
SLASH_DQNMENU1 = "/dqnmenu"
SlashCmdList["DQNMENU"] = function(msg)
    local num = tonumber(msg)
    if num and WCS_BrainDQNButton.currentMenu and WCS_BrainDQNButton.currentMenu[num] then
        WCS_BrainDQNButton.currentMenu[num].func()
        WCS_BrainDQNButton.currentMenu = nil
    else
        DEFAULT_CHAT_FRAME:AddMessage("Uso: /dqnmenu <numero>", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    end
end

-- Inicializacion automatica
local function Initialize()
    WCS_BrainDQNButton:CreateButton()
    DEFAULT_CHAT_FRAME:AddMessage("WCS_BrainDQNButton cargado. Usa /dqnbutton para opciones.", COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b)
end

-- Registrar evento de carga
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    Initialize()
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

