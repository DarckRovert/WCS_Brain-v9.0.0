--[[
    WCS_BrainDiagnostics.lua - Ventana de Diagnostico y Estado del Sistema
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Muestra:
    - Sistemas cargados/faltantes
    - Errores detectados
    - Funcionalidades pendientes
    - Warnings y problemas
    - Checklist de configuracion
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainDiagnostics = WCS_BrainDiagnostics or {}

-- ============================================================================
-- SISTEMA DE DEBUG LOG Y ESTADISTICAS EN VIVO
-- ============================================================================
WCS_BrainDiagnostics.debugLog = {}
WCS_BrainDiagnostics.maxLogEntries = 20
WCS_BrainDiagnostics.showDebugInChat = false

-- Estadisticas en vivo
WCS_BrainDiagnostics.liveStats = {
    combatCount = 0,
    spellsCast = 0,
    damageDealt = 0,
    healingDone = 0,
    petSummons = 0,
    profileChanges = 0,
    errorsDetected = 0,
    uptime = 0,
    startTime = time()
}

-- Funcion para agregar entrada al debug log
function WCS_BrainDiagnostics:AddDebugLog(category, message, level)
    level = level or "INFO"
    
    local entry = {
        time = date("%H:%M:%S"),
        category = category,
        message = message,
        level = level
    }
    
    table.insert(self.debugLog, 1, entry)
    
    while table.getn(self.debugLog) > self.maxLogEntries do
        table.remove(self.debugLog)
    end
    
    if self.showDebugInChat then
        local colorCode = "00FF00"
        if level == "ERROR" then colorCode = "FF0000"
        elseif level == "WARNING" then colorCode = "FFFF00"
        end
        
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff%s[%s] %s:|r %s", colorCode, entry.time, category, message)
        )
    end
end

WCS_BrainDiagnostics.VERSION = "6.4.2"

-- ============================================================================
-- COLORES
-- ============================================================================
local COLORS = {
    BG_DARK = {0.05, 0.05, 0.08},
    BG_SECTION = {0.1, 0.08, 0.12},
    BORDER = {0.5, 0.4, 0.7},
    WARLOCK_PURPLE = {0.58, 0.51, 0.79},
    FEL_GREEN = {0.0, 1.0, 0.5},
    
    OK = {0.0, 1.0, 0.3},
    WARNING = {1.0, 0.7, 0.0},
    ERROR = {1.0, 0.2, 0.2},
    INFO = {0.4, 0.7, 1.0},
    DISABLED = {0.5, 0.5, 0.5},
    
    GOLD = {1.0, 0.82, 0.0},
    WHITE = {1.0, 1.0, 1.0},
    GRAY = {0.6, 0.6, 0.6}
}

-- ============================================================================
-- DEFINICION DE TODOS LOS SISTEMAS
-- ============================================================================
local SYSTEMS = {
    -- NUCLEO
    {name = "WCS_SpellDB", category = "Nucleo", description = "Base de datos de hechizos", critical = true},
    {name = "WCS_BrainCore", category = "Nucleo", description = "Nucleo del sistema", critical = true},
    {name = "WCS_Brain", category = "Nucleo", description = "Cerebro principal", critical = true},
    
    -- IA
    {name = "WCS_BrainAI", category = "IA", description = "Sistema de IA principal", critical = true},
    {name = "WCS_BrainML", category = "IA", description = "Machine Learning", critical = false},
    {name = "WCS_BrainDQN", category = "IA", description = "Deep Q-Network", critical = false},
    {name = "WCS_BrainState", category = "IA", description = "Gestion de estados", critical = true},
    {name = "WCS_BrainReward", category = "IA", description = "Sistema de recompensas", critical = false},
    {name = "WCS_BrainActions", category = "IA", description = "Acciones disponibles", critical = true},
    
    -- MODULOS v6.4.1
    {name = "WCS_BrainTesting", category = "Modulos v6.3", description = "Testing automatizado", critical = false},
    {name = "WCS_BrainMetrics", category = "Modulos v6.3", description = "Metricas de rendimiento", critical = false},
    {name = "WCS_BrainContextual", category = "Modulos v6.3", description = "Configuracion contextual", critical = false},
    {name = "WCS_BrainIntegrations", category = "Modulos v6.3", description = "Integracion con addons", critical = false},
    
    -- INTEGRACION
    {name = "WCS_BrainIntegration", category = "Integracion", description = "Integracion general", critical = false},
    {name = "WCS_BrainAutoCapture", category = "Integracion", description = "Captura automatica", critical = false},
    
    -- MASCOTAS
    {name = "WCS_BrainPetAI", category = "Mascotas", description = "IA de mascotas", critical = false},
    {name = "WCS_BrainMajorDemons", category = "Mascotas", description = "Demonios mayores", critical = false},
    {name = "WCS_Brain.Pet.Social", category = "Mascotas", description = "Sistema social de pets", critical = false, checkPath = true},
    {name = "WCS_Brain.Pet.Emotions", category = "Mascotas", description = "Emociones de pets", critical = false, checkPath = true},
    {name = "WCS_Brain.Pet.Learning", category = "Mascotas", description = "Aprendizaje de pets", critical = false, checkPath = true},
    
    -- UI
    {name = "WCS_BrainUI", category = "UI", description = "Interfaz principal", critical = false},
    {name = "WCS_BrainButton", category = "UI", description = "Boton principal", critical = false},
    {name = "WCS_BrainDQNUI", category = "UI", description = "Interfaz DQN", critical = false},
    {name = "WCS_BrainDQNButton", category = "UI", description = "Boton DQN", critical = false},
    {name = "WCS_BrainThoughts", category = "UI", description = "Panel de pensamientos", critical = false},
    {name = "WCS_BrainPetUI", category = "UI", description = "Interfaz de mascotas", critical = false},
    
    -- OPTIMIZACION
    {name = "WCS_UpdateManager", category = "Optimizacion", description = "Gestor de updates", critical = false},
    {name = "WCS_Profiler", category = "Optimizacion", description = "Profiler de rendimiento", critical = false},
    {name = "WCS_StringOptimizer", category = "Optimizacion", description = "Optimizador de strings", critical = false},
    {name = "WCS_UIOptimizer", category = "Optimizacion", description = "Optimizador de UI", critical = false},
    {name = "WCS_LazyLoader", category = "Optimizacion", description = "Carga diferida", critical = false}
}

-- ============================================================================
-- FUNCIONALIDADES PENDIENTES / TODO
-- ============================================================================
local TODO_LIST = {
    -- SISTEMAS COMPLETADOS
    {task = "Deep Q-Network (DQN) con replay buffer", priority = "Alta", status = "completado"},
    {task = "Backup automatico de datos ML", priority = "Alta", status = "completado"},
    {task = "Sistema de metricas de rendimiento", priority = "Alta", status = "completado"},
    {task = "Configuracion contextual (solo/group/raid/pvp)", priority = "Media", status = "completado"},
    {task = "Integracion con addons (DBM/KTM/etc)", priority = "Media", status = "completado"},
    {task = "Soporte Infernal/Doomguard", priority = "Media", status = "completado"},
    -- MEJORAS FUTURAS
    {task = "Agregar soporte para Felguard", priority = "Media", status = "pendiente"},
    {task = "Modo PvP especializado", priority = "Alta", status = "en_progreso"},
    {task = "Exportar/Importar configuracion", priority = "Baja", status = "pendiente"}
}

-- ============================================================================
-- CHECKLIST DE CONFIGURACION
-- ============================================================================
local function GetConfigChecklist()
    local checklist = {}
    
    -- Brain habilitado
    table.insert(checklist, {
        name = "Brain habilitado",
        check = function() return WCS_Brain and WCS_Brain.ENABLED end,
        fix = "/brain on"
    })
    
    -- DQN habilitado
    table.insert(checklist, {
        name = "DQN habilitado",
        check = function() return WCS_BrainDQN and WCS_BrainDQN.enabled end,
        fix = "/dqn on"
    })
    
    -- Pet AI habilitado
    table.insert(checklist, {
        name = "Pet AI habilitado",
        check = function() return WCS_BrainPetAI_IsEnabled and WCS_BrainPetAI_IsEnabled() end,
        fix = "Checkbox en UI"
    })
    
    -- Mascota invocada
    table.insert(checklist, {
        name = "Mascota invocada",
        check = function() return UnitExists("pet") end,
        fix = "Invocar demonio"
    })
    
    -- En combate (info)
    table.insert(checklist, {
        name = "Estado de combate",
        check = function() return UnitAffectingCombat("player") end,
        fix = nil,
        isInfo = true
    })
    
    -- Target hostil
    table.insert(checklist, {
        name = "Target hostil seleccionado",
        check = function() return UnitExists("target") and UnitCanAttack("player", "target") end,
        fix = "Seleccionar enemigo"
    })
    
    -- ML tiene datos
    table.insert(checklist, {
        name = "ML tiene datos de combate",
        check = function() 
            return WCS_BrainML and WCS_BrainML.Data and WCS_BrainML.Data.globalStats 
                   and WCS_BrainML.Data.globalStats.totalCombats 
                   and WCS_BrainML.Data.globalStats.totalCombats > 0 
        end,
        fix = "Combatir para recopilar datos"
    })
    
    -- DQN tiene experiencias
    table.insert(checklist, {
        name = "DQN tiene experiencias en buffer",
        check = function()
            return WCS_BrainDQN and WCS_BrainDQN.replayBuffer and WCS_TableCount(WCS_BrainDQN.replayBuffer) > 0
        end,
        fix = "Combatir para llenar buffer"
    })
    
    return checklist
end

-- ============================================================================
-- UTILIDADES UI
-- ============================================================================
local function CreateSection(parent, x, y, width, height, title)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    frame:SetBackdropColor(COLORS.BG_SECTION[1], COLORS.BG_SECTION[2], COLORS.BG_SECTION[3], 0.95)
    frame:SetBackdropBorderColor(COLORS.BORDER[1], COLORS.BORDER[2], COLORS.BORDER[3], 0.8)
    
    if title then
        local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
        titleText:SetText("|cFF9482C9" .. title .. "|r")
    end
    
    return frame
end

local function ColorToHex(color)
    local r = math.floor(color[1] * 255)
    local g = math.floor(color[2] * 255)
    local b = math.floor(color[3] * 255)
    return string.format("%02X%02X%02X", r, g, b)
end

-- ============================================================================
-- CREAR FRAME PRINCIPAL
-- ============================================================================
function WCS_BrainDiagnostics:CreateMainFrame()
    if self.MainFrame then return self.MainFrame end
    
    local f = CreateFrame("Frame", "WCSBrainDiagnosticsFrame", UIParent)
    f:SetWidth(420)
    f:SetHeight(580)
    f:SetPoint("CENTER", UIParent, "CENTER", -400, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetFrameStrata("HIGH")
    
    -- Fondo
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    f:SetBackdropColor(COLORS.BG_DARK[1], COLORS.BG_DARK[2], COLORS.BG_DARK[3], 0.97)
    f:SetBackdropBorderColor(COLORS.WARLOCK_PURPLE[1], COLORS.WARLOCK_PURPLE[2], COLORS.WARLOCK_PURPLE[3], 1)
    
    -- Header
    self:CreateHeader(f)
    
    -- Secciones
    self:CreateSystemsSection(f)
    self:CreateErrorsSection(f)
    self:CreateChecklistSection(f)
    self:CreateTodoSection(f)
    
    self.MainFrame = f
    self:StartUpdate()
    
    return f
end

-- ============================================================================
-- HEADER
-- ============================================================================
function WCS_BrainDiagnostics:CreateHeader(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", parent, "TOP", 0, -12)
    title:SetText("|cFF9482C9WCS|r |cFFFF6600DIAGNOSTICO|r")
    
    local subtitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("|cFF666666Estado del Sistema v" .. self.VERSION .. "|r")
    
    -- Boton cerrar
    local closeBtn = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() WCS_BrainDiagnostics:Toggle() end)
    
    -- Boton refrescar
    local refreshBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshBtn:SetWidth(70)
    refreshBtn:SetHeight(20)
    refreshBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -8)
    refreshBtn:SetText("Refrescar")
    refreshBtn:SetScript("OnClick", function() WCS_BrainDiagnostics:Update() end)
    
    -- Linea separadora
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -45)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -45)
    line:SetHeight(1)
    line:SetTexture(1, 1, 1, 0.2)
    
    -- Resumen rapido
    local summaryText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -52)
    summaryText:SetText("|cFF888888Cargando...|r")
    self.summaryText = summaryText
end

-- ============================================================================
-- SECCION: SISTEMAS
-- ============================================================================
function WCS_BrainDiagnostics:CreateSystemsSection(parent)
    local section = CreateSection(parent, 10, -70, 400, 150, "Sistemas Cargados")
    
    -- Crear contenedor simple para los sistemas (sin scroll por compatibilidad Lua 5.0)
    local content = CreateFrame("Frame", nil, section)
    content:SetPoint("TOPLEFT", section, "TOPLEFT", 5, -20)
    content:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -5, 5)
    
    -- Crear textos para mostrar resumen de sistemas
    self.systemsContent = {}
    for i = 1, 8 do
        local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -((i-1) * 14))
        text:SetWidth(380)
        text:SetJustifyH("LEFT")
        text:SetText("")
        self.systemsContent[i] = text
    end
    
    self.systemsSection = section
end

-- ============================================================================
-- SECCION: ERRORES Y WARNINGS
-- ============================================================================
function WCS_BrainDiagnostics:CreateErrorsSection(parent)
    local section = CreateSection(parent, 10, -230, 400, 100, "Errores y Warnings")
    
    self.errorsContent = {}
    for i = 1, 5 do
        local text = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -20 - (i-1) * 14)
        text:SetWidth(380)
        text:SetJustifyH("LEFT")
        text:SetText("")
        self.errorsContent[i] = text
    end
    
    self.errorsSection = section
end

-- ============================================================================
-- SECCION: CHECKLIST
-- ============================================================================
function WCS_BrainDiagnostics:CreateChecklistSection(parent)
    local section = CreateSection(parent, 10, -340, 400, 110, "Checklist de Configuracion")
    
    self.checklistContent = {}
    for i = 1, 6 do
        local text = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -20 - (i-1) * 14)
        text:SetWidth(380)
        text:SetJustifyH("LEFT")
        text:SetText("")
        self.checklistContent[i] = text
    end
    
    self.checklistSection = section
end

-- ============================================================================
-- SECCION: TODO / PENDIENTES
-- ============================================================================
function WCS_BrainDiagnostics:CreateTodoSection(parent)
    local section = CreateSection(parent, 10, -460, 400, 110, "Funcionalidades Pendientes")
    
    self.todoContent = {}
    for i = 1, 6 do
        local text = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -20 - (i-1) * 14)
        text:SetWidth(380)
        text:SetJustifyH("LEFT")
        text:SetText("")
        self.todoContent[i] = text
    end
    
    self.todoSection = section
end

-- ============================================================================
-- ACTUALIZACION
-- ============================================================================
function WCS_BrainDiagnostics:Update()
    if not self.MainFrame or not self.MainFrame:IsVisible() then return end
    
    local totalSystems = 0
    local loadedSystems = 0
    local criticalMissing = 0
    local warnings = {}
    local errors = {}
    
    -- === ACTUALIZAR SISTEMAS ===
    local categories = {}
    
    for i, sys in ipairs(SYSTEMS) do
        totalSystems = totalSystems + 1
        local isLoaded = false
        
        -- Verificar si es una ruta con puntos (ej: WCS_Brain.Pet.Social)
        if sys.checkPath then
            -- Parsear la ruta usando string.gfind (compatible Lua 5.0)
            local obj = nil
            local isFirst = true
            for part in string.gfind(sys.name, "([^.]+)") do
                if isFirst then
                    obj = getglobal(part)
                    isFirst = false
                else
                    if obj and type(obj) == "table" and obj[part] then
                        obj = obj[part]
                    else
                        obj = nil
                        break
                    end
                end
            end
            isLoaded = (obj ~= nil)
        else
            isLoaded = getglobal(sys.name) ~= nil
        end
        
        if isLoaded then
            loadedSystems = loadedSystems + 1
        elseif sys.critical then
            criticalMissing = criticalMissing + 1
            table.insert(errors, "|cFFFF0000[CRITICO]|r " .. sys.name .. " no cargado!")
        else
            table.insert(warnings, "|cFFFFAA00[WARN]|r " .. sys.name .. " no disponible")
        end
        
        -- Contar por categoria
        if not categories[sys.category] then
            categories[sys.category] = {total = 0, loaded = 0}
        end
        categories[sys.category].total = categories[sys.category].total + 1
        if isLoaded then
            categories[sys.category].loaded = categories[sys.category].loaded + 1
        end
    end
    
    -- Mostrar resumen por categoria
    if self.systemsContent then
        local idx = 1
        local catOrder = {"Nucleo", "IA", "Modulos v6.3", "Integracion", "Mascotas", "UI", "Optimizacion"}
        for _, catName in ipairs(catOrder) do
            local cat = categories[catName]
            if cat and self.systemsContent[idx] then
                local color = cat.loaded == cat.total and "00FF00" or (cat.loaded > 0 and "FFAA00" or "FF0000")
                self.systemsContent[idx]:SetText("|cFFFFCC00" .. catName .. ":|r |cFF" .. color .. cat.loaded .. "/" .. cat.total .. "|r")
                idx = idx + 1
            end
        end
        -- Limpiar resto
        while idx <= 8 do
            if self.systemsContent[idx] then
                self.systemsContent[idx]:SetText("")
            end
            idx = idx + 1
        end
    end
    
    -- === RESUMEN ===
    local summaryColor = criticalMissing > 0 and "FF0000" or (WCS_TableCount(warnings) > 0 and "FFAA00" or "00FF00")
    local summaryIcon = criticalMissing > 0 and "X" or (WCS_TableCount(warnings) > 0 and "!" or "OK")
    self.summaryText:SetText("|cFF" .. summaryColor .. "[" .. summaryIcon .. "]|r Sistemas: " .. loadedSystems .. "/" .. totalSystems .. " | Criticos faltantes: " .. criticalMissing .. " | Warnings: " .. WCS_TableCount(warnings))
    
    -- === ERRORES Y WARNINGS ===
    local allMessages = {}
    for _, e in ipairs(errors) do table.insert(allMessages, e) end
    for _, w in ipairs(warnings) do table.insert(allMessages, w) end
    
    if WCS_TableCount(allMessages) == 0 then
        table.insert(allMessages, "|cFF00FF00Todo OK - Sin errores ni warnings|r")
    end
    
    for i = 1, 5 do
        if self.errorsContent[i] then
            self.errorsContent[i]:SetText(allMessages[i] or "")
        end
    end
    
    -- === CHECKLIST ===
    local checklist = GetConfigChecklist()
    for i, item in ipairs(checklist) do
        if self.checklistContent[i] then
            local ok, result = pcall(item.check)
            local isOk = ok and result
            
            local icon = isOk and "|cFF00FF00[*]|r" or "|cFFFF6666[ ]|r"
            local nameColor = isOk and "AAAAAA" or "FFFFFF"
            local fixText = ""
            if not isOk and item.fix then
                fixText = " |cFF888888(" .. item.fix .. ")|r"
            end
            
            self.checklistContent[i]:SetText(icon .. " |cFF" .. nameColor .. item.name .. "|r" .. fixText)
        end
    end
    
    -- === TODO LIST ===
    for i, todo in ipairs(TODO_LIST) do
        if self.todoContent[i] then
            local prioColor = todo.priority == "Alta" and "FF6666" or (todo.priority == "Media" and "FFAA00" or "88FF88")
            local statusIcon = todo.status == "completado" and "|cFF00FF00[OK]|r" or (todo.status == "en_progreso" and "|cFFFFFF00[>>]|r" or "|cFF666666[ ]|r")
            
            self.todoContent[i]:SetText(statusIcon .. " |cFF" .. prioColor .. "[" .. todo.priority .. "]|r " .. todo.task)
        end
    end
end

function WCS_BrainDiagnostics:StartUpdate()
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame.elapsed = 0
        self.updateFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= 2 then
                this.elapsed = 0
                WCS_BrainDiagnostics:Update()
            end
        end)
    end
end

-- ============================================================================
-- TOGGLE
-- ============================================================================
function WCS_BrainDiagnostics:Toggle()
    if not self.MainFrame then
        self:CreateMainFrame()
    end
    
    if self.MainFrame:IsVisible() then
        self.MainFrame:Hide()
    else
        self.MainFrame:Show()
        self:Update()
    end
end

function WCS_BrainDiagnostics:Show()
    if not self.MainFrame then
        self:CreateMainFrame()
    end
    self.MainFrame:Show()
    self:Update()
end

function WCS_BrainDiagnostics:Hide()
    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSDIAG1 = "/wcsdiag"
SLASH_WCSDIAG2 = "/braindiag"
SLASH_WCSDIAG3 = "/diagnostico"
SlashCmdList["WCSDIAG"] = function(msg)
    WCS_BrainDiagnostics:Toggle()
end

-- Mensaje de carga
DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS_Diagnostics]|r v" .. WCS_BrainDiagnostics.VERSION .. " cargado. Usa |cFFFFCC00/wcsdiag|r para abrir.")

-- ============================================================================
-- COMANDO DE PRUEBA DE BOTONES (Integrado)
-- ============================================================================

SLASH_WCSTEST1 = "/wcstest"
SlashCmdList["WCSTEST"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "toggle" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando botón ON/OFF...")
        if WCS_Brain then
            WCS_Brain.ENABLED = not WCS_Brain.ENABLED
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r ENABLED = " .. tostring(WCS_Brain.ENABLED))
        end
        
    elseif cmd == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando botón Debug...")
        if WCS_Brain then
            WCS_Brain.DEBUG = not WCS_Brain.DEBUG
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r DEBUG = " .. tostring(WCS_Brain.DEBUG))
        end
        
    elseif cmd == "cast" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando botón Cast...")
        if WCS_Brain and WCS_Brain.Execute then
            local result = WCS_Brain:Execute()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r Execute() = " .. tostring(result))
        end
        
    elseif cmd == "reset" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando botón Reset Memory...")
        if WCS_Brain and WCS_Brain.ResetMemory then
            WCS_Brain:ResetMemory()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r ResetMemory() ejecutado")
        end
        
    elseif cmd == "ml" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando botón ML...")
        if WCS_BrainML and WCS_BrainML.ToggleUI then
            WCS_BrainML:ToggleUI()
        end
        
    elseif cmd == "petai" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando checkbox Pet AI...")
        if WCS_BrainPetAI_SetEnabled and WCS_BrainPetAI_IsEnabled then
            local current = WCS_BrainPetAI_IsEnabled()
            WCS_BrainPetAI_SetEnabled(not current)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r Pet AI = " .. tostring(WCS_BrainPetAI_IsEnabled()))
        end
        
    elseif cmd == "action" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Probando GetNextAction()...")
        if WCS_Brain and WCS_Brain.GetNextAction then
            local action = WCS_Brain:GetNextAction()
            if action then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r Acción sugerida: " .. (action.spell or "?"))
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Test]|r Razón: " .. (action.reason or "?"))
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[Test]|r No hay acción disponible")
            end
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[WCS Test]|r Comandos disponibles:")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest toggle - Probar botón ON/OFF")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest debug - Probar botón Debug")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest cast - Probar botón Cast")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest reset - Probar botón Reset Memory")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest ml - Probar botón ML")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest petai - Probar checkbox Pet AI")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcstest action - Probar GetNextAction()")
    end
end

-- ============================================================================
-- BOTON FLOTANTE DE DIAGNOSTICO
-- ============================================================================
function WCS_BrainDiagnostics:CreateButton()
    if self.Button then return self.Button end
    
    local btn = CreateFrame("Button", "WCSBrainDiagButton", UIParent)
    btn:SetWidth(32)
    btn:SetHeight(32)
    btn:SetPoint("TOP", UIParent, "TOP", 0, -100)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(50)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Fondo con icono
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    btn.bg = bg
    
    -- Borde estilo Warlock
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetWidth(38)
    border:SetHeight(38)
    border:SetPoint("CENTER", btn, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetVertexColor(1, 0.5, 0, 1)
    btn.border = border
    
    -- Texto debajo
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    text:SetText("Diag")
    text:SetTextColor(1, 0.5, 0, 1)
    btn.text = text
    
    -- Tooltip
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cFFFF6600WCS Diagnostico|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFFFFFClick Izq:|r Abrir panel", 1, 1, 1)
        GameTooltip:AddLine("|cFFFFFFFFClick Der:|r Refrescar", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Arrastrar para mover|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click
    btn:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            WCS_BrainDiagnostics:Toggle()
        elseif arg1 == "RightButton" then
            if WCS_BrainDiagnostics.MainFrame and WCS_BrainDiagnostics.MainFrame:IsVisible() then
                WCS_BrainDiagnostics:Update()
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600[Diag]|r Actualizado")
            end
        end
    end)
    
    -- Drag
    btn:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    
    btn:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        WCS_BrainDiagnostics:SaveButtonPosition()
    end)
    
    btn:Show()
    self.Button = btn
    
    -- Cargar posicion guardada
    self:LoadButtonPosition()
    
    return btn
end

-- Guardar posicion del boton
function WCS_BrainDiagnostics:SaveButtonPosition()
    if not self.Button then return end
    local point, _, relPoint, x, y = self.Button:GetPoint()
    if not WCS_BrainCharSaved then WCS_BrainCharSaved = {} end
    WCS_BrainCharSaved.diagButtonPos = {point = point, relPoint = relPoint, x = x, y = y}
end

-- Cargar posicion del boton
function WCS_BrainDiagnostics:LoadButtonPosition()
    if not self.Button then return end
    if not WCS_BrainCharSaved or not WCS_BrainCharSaved.diagButtonPos then return end
    local pos = WCS_BrainCharSaved.diagButtonPos
    self.Button:ClearAllPoints()
    self.Button:SetPoint(pos.point or "TOP", UIParent, pos.relPoint or "TOP", pos.x or 0, pos.y or -100)
end

-- Toggle del boton
function WCS_BrainDiagnostics:ToggleButton()
    if not self.Button then
        self:CreateButton()
    else
        if self.Button:IsVisible() then
            self.Button:Hide()
        else
            self.Button:Show()
        end
    end
end

-- Comando para mostrar/ocultar boton
SLASH_WCSDIAGBTN1 = "/diagbtn"
SlashCmdList["WCSDIAGBTN"] = function()
    WCS_BrainDiagnostics:ToggleButton()
end

-- Crear boton automaticamente al cargar
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    WCS_BrainDiagnostics:CreateButton()
end)

