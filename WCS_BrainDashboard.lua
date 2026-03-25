-- WCS_BrainDashboard.lua
-- Dashboard de Rendimiento en Tiempo Real para WCS_Brain v6.9.0
-- Muestra métricas de CPU, memoria, eventos, y estado del addon

if not WCS_Brain then return end

WCS_Brain.Dashboard = {
    -- Estado del dashboard
    isVisible = false,
    frame = nil,
    updateInterval = 1.0, -- Actualizar cada 1 segundo
    lastUpdate = 0,
    
    -- Métricas
    metrics = {
        fps = 0,
        latency = 0,
        memoryUsage = 0,
        cpuUsage = 0,
        eventsProcessed = 0,
        eventsThrottled = 0,
        cooldownsActive = 0,
        petCooldownsActive = 0,
        cacheSize = 0,
        aiDecisions = 0,
        petAIDecisions = 0,
    },
    
    -- Historial para gráficos (últimos 60 segundos)
    history = {
        fps = {},
        memory = {},
        cpu = {},
        events = {},
    },
    maxHistory = 60,
}

local Dashboard = WCS_Brain.Dashboard

-- Función para inicializar el dashboard
function Dashboard:Initialize()
    if self.frame then return end
    
    -- Crear frame principal
    local frame = CreateFrame("Frame", "WCS_BrainDashboardFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    
    self.frame = frame
    
    -- Título
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetText("WCS Brain Dashboard")
    frame.title = title
    
    -- Botón de cerrar
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() Dashboard:Hide() end)
    frame.closeBtn = closeBtn
    
    -- Crear secciones de métricas
    self:CreateMetricsSection(frame)
    
    -- Frame de actualización
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        Dashboard:OnUpdate(arg1)
    end)
    self.updateFrame = updateFrame
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Info("Dashboard inicializado. Usa /wcsdash para abrir.")
    end
end

-- Crear sección de métricas
function Dashboard:CreateMetricsSection(parent)
    local yOffset = -60
    local lineHeight = 20
    
    -- Sección: Rendimiento del Sistema
    local sysHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sysHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    sysHeader:SetText("Sistema")
    sysHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - lineHeight - 5
    
    -- FPS
    local fpsLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fpsLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    fpsLabel:SetText("FPS:")
    local fpsValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fpsValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    fpsValue:SetText("0")
    parent.fpsValue = fpsValue
    yOffset = yOffset - lineHeight
    
    -- Latencia
    local latLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    latLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    latLabel:SetText("Latencia:")
    local latValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    latValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    latValue:SetText("0 ms")
    parent.latValue = latValue
    yOffset = yOffset - lineHeight
    
    -- Memoria
    local memLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    memLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    memLabel:SetText("Memoria WCS:")
    local memValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    memValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    memValue:SetText("0 KB")
    parent.memValue = memValue
    yOffset = yOffset - lineHeight
    
    -- CPU (estimado)
    local cpuLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cpuLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    cpuLabel:SetText("CPU Estimado:")
    local cpuValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cpuValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    cpuValue:SetText("0%")
    parent.cpuValue = cpuValue
    yOffset = yOffset - lineHeight - 10
    
    -- Sección: Eventos
    local evtHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    evtHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    evtHeader:SetText("Eventos")
    evtHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - lineHeight - 5
    
    -- Eventos procesados
    local evtProcLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    evtProcLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    evtProcLabel:SetText("Procesados:")
    local evtProcValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    evtProcValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    evtProcValue:SetText("0")
    parent.evtProcValue = evtProcValue
    yOffset = yOffset - lineHeight
    
    -- Eventos throttled
    local evtThrotLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    evtThrotLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    evtThrotLabel:SetText("Throttled:")
    local evtThrotValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    evtThrotValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    evtThrotValue:SetText("0")
    parent.evtThrotValue = evtThrotValue
    yOffset = yOffset - lineHeight - 10
    
    -- Sección: Cooldowns y Caché
    local cdHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cdHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    cdHeader:SetText("Cooldowns y Caché")
    cdHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - lineHeight - 5
    
    -- Cooldowns activos
    local cdLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    cdLabel:SetText("Cooldowns:")
    local cdValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    cdValue:SetText("0")
    parent.cdValue = cdValue
    yOffset = yOffset - lineHeight
    
    -- Pet Cooldowns
    local petCdLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petCdLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    petCdLabel:SetText("Pet Cooldowns:")
    local petCdValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petCdValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    petCdValue:SetText("0")
    parent.petCdValue = petCdValue
    yOffset = yOffset - lineHeight
    
    -- Tamaño de caché
    local cacheLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cacheLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    cacheLabel:SetText("Caché:")
    local cacheValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cacheValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    cacheValue:SetText("0")
    parent.cacheValue = cacheValue
    yOffset = yOffset - lineHeight - 10
    
    -- Sección: IA
    local aiHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    aiHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    aiHeader:SetText("Inteligencia Artificial")
    aiHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - lineHeight - 5
    
    -- Decisiones de IA
    local aiDecLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aiDecLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    aiDecLabel:SetText("Decisiones IA:")
    local aiDecValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aiDecValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    aiDecValue:SetText("0")
    parent.aiDecValue = aiDecValue
    yOffset = yOffset - lineHeight
    
    -- Decisiones Pet IA
    local petAiLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petAiLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    petAiLabel:SetText("Pet IA:")
    local petAiValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petAiValue:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, yOffset)
    petAiValue:SetText("0")
    parent.petAiValue = petAiValue
    yOffset = yOffset - lineHeight - 10
    
    -- Botón de reset
    local resetBtn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    resetBtn:SetWidth(150)
    resetBtn:SetHeight(25)
    resetBtn:SetPoint("BOTTOM", parent, "BOTTOM", 0, 20)
    resetBtn:SetText("Reset Estadísticas")
    resetBtn:SetScript("OnClick", function() Dashboard:ResetStats() end)
    parent.resetBtn = resetBtn
end

-- Actualizar métricas
function Dashboard:OnUpdate(elapsed)
    if not self.isVisible then return end
    
    self.lastUpdate = self.lastUpdate + elapsed
    if self.lastUpdate < self.updateInterval then return end
    self.lastUpdate = 0
    
    -- Recopilar métricas
    self:CollectMetrics()
    
    -- Actualizar UI
    self:UpdateUI()
end

-- Recopilar métricas del sistema
function Dashboard:CollectMetrics()
    -- FPS
    self.metrics.fps = GetFramerate()
    
    -- Latencia
    local _, _, latency = GetNetStats()
    self.metrics.latency = latency or 0
    
    -- Memoria del addon
    -- En WoW 1.12 no existe UpdateAddOnMemoryUsage, así que estimamos basado en otros factores
    local memEstimate = 0
    
    -- Estimar memoria basada en estructuras de datos
    if WCS_Brain.Cooldowns then
        for _ in pairs(WCS_Brain.Cooldowns) do
            memEstimate = memEstimate + 0.5 -- ~0.5 KB por cooldown
        end
    end
    
    if WCS_BrainCache and WCS_BrainCache.Storage then
        for _ in pairs(WCS_BrainCache.Storage) do
            memEstimate = memEstimate + 1 -- ~1 KB por item en caché
        end
    end
    
    if WCS_BrainPetAI and WCS_BrainPetAI.cooldowns then
        for _ in pairs(WCS_BrainPetAI.cooldowns) do
            memEstimate = memEstimate + 0.3 -- ~0.3 KB por pet cooldown
        end
    end
    
    -- Agregar memoria base del addon (estimado)
    memEstimate = memEstimate + 50 -- Base de ~50 KB
    
    self.metrics.memoryUsage = memEstimate
    
    -- CPU estimado (basado en combate activo)
    local cpuEstimate = 0
    if WCS_BrainMetrics and WCS_BrainMetrics.Combat and WCS_BrainMetrics.Combat.active then
        cpuEstimate = 15.0 -- CPU moderado durante combate
    else
        cpuEstimate = 0.5 -- CPU mínimo fuera de combate
    end
    self.metrics.cpuUsage = cpuEstimate
    
    -- Eventos - Usar combates ganados/perdidos de WCS_BrainMetrics
    if WCS_BrainMetrics and WCS_BrainMetrics.Data then
        local totalCombats = (WCS_BrainMetrics.Data.combatsWon or 0) + (WCS_BrainMetrics.Data.combatsLost or 0)
        self.metrics.eventsProcessed = totalCombats
        self.metrics.eventsThrottled = 0 -- No usado
    else
        self.metrics.eventsProcessed = 0
        self.metrics.eventsThrottled = 0
    end
    
    -- Cooldowns
    local cdCount = 0
    if WCS_Brain.Cooldowns then
        for _ in pairs(WCS_Brain.Cooldowns) do
            cdCount = cdCount + 1
        end
    end
    self.metrics.cooldownsActive = cdCount
    
    -- Pet Cooldowns
    local petCdCount = 0
    if WCS_BrainPetAI and WCS_BrainPetAI.cooldowns then
        for _ in pairs(WCS_BrainPetAI.cooldowns) do
            petCdCount = petCdCount + 1
        end
    end
    self.metrics.petCooldownsActive = petCdCount
    
    -- Caché
    local cacheCount = 0
    if WCS_BrainCache and WCS_BrainCache.Storage then
        for _ in pairs(WCS_BrainCache.Storage) do
            cacheCount = cacheCount + 1
        end
    end
    self.metrics.cacheSize = cacheCount
    
    -- Decisiones de IA - Usar WCS_BrainMetrics (sistema original del addon)
    local aiDecisions = 0
    local petAIDecisions = 0
    
    -- Contar hechizos casteados desde WCS_BrainMetrics
    if WCS_BrainMetrics and WCS_BrainMetrics.Data and WCS_BrainMetrics.Data.spellUsage then
        for spell, count in pairs(WCS_BrainMetrics.Data.spellUsage) do
            aiDecisions = aiDecisions + count
        end
    end
    
    -- Contar acciones de mascota desde WCS_BrainPetAI
    if WCS_BrainPetAI and WCS_BrainPetAI.Stats and WCS_BrainPetAI.Stats.totalActions then
        petAIDecisions = WCS_BrainPetAI.Stats.totalActions
    elseif WCS_BrainPetAI and WCS_BrainPetAI.actionCount then
        petAIDecisions = WCS_BrainPetAI.actionCount
    end
    
    self.metrics.aiDecisions = aiDecisions
    self.metrics.petAIDecisions = petAIDecisions
    
    -- Agregar al historial
    self:AddToHistory("fps", self.metrics.fps)
    self:AddToHistory("memory", self.metrics.memoryUsage)
    self:AddToHistory("cpu", self.metrics.cpuUsage)
    self:AddToHistory("events", self.metrics.eventsProcessed)
end

-- Agregar dato al historial
function Dashboard:AddToHistory(metric, value)
    if not self.history[metric] then return end
    
    table.insert(self.history[metric], value)
    
    -- Mantener solo los últimos N valores
    while table.getn(self.history[metric]) > self.maxHistory do
        table.remove(self.history[metric], 1)
    end
end

-- Actualizar UI con las métricas
function Dashboard:UpdateUI()
    if not self.frame then return end
    
    local frame = self.frame
    
    -- FPS (color según rendimiento)
    local fpsColor = "|cff00ff00" -- Verde
    if self.metrics.fps < 30 then
        fpsColor = "|cffff0000" -- Rojo
    elseif self.metrics.fps < 60 then
        fpsColor = "|cffffff00" -- Amarillo
    end
    frame.fpsValue:SetText(fpsColor .. string.format("%.1f", self.metrics.fps))
    
    -- Latencia
    local latColor = "|cff00ff00"
    if self.metrics.latency > 200 then
        latColor = "|cffff0000"
    elseif self.metrics.latency > 100 then
        latColor = "|cffffff00"
    end
    frame.latValue:SetText(latColor .. self.metrics.latency .. " ms")
    
    -- Memoria
    local memKB = self.metrics.memoryUsage
    local memText = string.format("%.2f KB", memKB)
    if memKB > 1024 then
        memText = string.format("%.2f MB", memKB / 1024)
    end
    frame.memValue:SetText(memText)
    
    -- CPU
    frame.cpuValue:SetText(string.format("%.2f%%", self.metrics.cpuUsage))
    
    -- Eventos
    frame.evtProcValue:SetText(tostring(self.metrics.eventsProcessed))
    frame.evtThrotValue:SetText(tostring(self.metrics.eventsThrottled))
    
    -- Cooldowns
    local cdColor = "|cffffffff"
    if self.metrics.cooldownsActive > 80 then
        cdColor = "|cffffff00"
    end
    if self.metrics.cooldownsActive > 100 then
        cdColor = "|cffff0000"
    end
    frame.cdValue:SetText(cdColor .. self.metrics.cooldownsActive)
    
    frame.petCdValue:SetText(tostring(self.metrics.petCooldownsActive))
    frame.cacheValue:SetText(tostring(self.metrics.cacheSize))
    
    -- IA
    frame.aiDecValue:SetText(tostring(self.metrics.aiDecisions))
    frame.petAiValue:SetText(tostring(self.metrics.petAIDecisions))
end

-- Mostrar dashboard
function Dashboard:Show()
    if not self.frame then
        self:Initialize()
    end
    
    self.frame:Show()
    self.isVisible = true
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Info("Dashboard abierto")
    end
end

-- Ocultar dashboard
function Dashboard:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.isVisible = false
end

-- Toggle dashboard
function Dashboard:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

-- Reset estadísticas
function Dashboard:ResetStats()
    -- Reset métricas
    self.metrics.eventsProcessed = 0
    self.metrics.eventsThrottled = 0
    self.metrics.aiDecisions = 0
    self.metrics.petAIDecisions = 0
    
    -- Reset historial
    self.history.fps = {}
    self.history.memory = {}
    self.history.cpu = {}
    self.history.events = {}
    
    -- Reset stats en EventThrottle
    if WCS_Brain.EventThrottle then
        WCS_Brain.EventThrottle.stats.totalProcessed = 0
        WCS_Brain.EventThrottle.stats.totalThrottled = 0
    end
    
    if WCS_Brain.Notifications then
        WCS_Brain.Notifications:Success("Estadísticas reseteadas")
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS Dashboard: Estadísticas reseteadas", 0, 1, 0)
    end
end

-- Comando slash
SlashCmdList["WCSDASHBOARD"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "show" or msg == "" then
        Dashboard:Show()
    elseif msg == "hide" then
        Dashboard:Hide()
    elseif msg == "toggle" then
        Dashboard:Toggle()
    elseif msg == "reset" then
        Dashboard:ResetStats()
    else
        DEFAULT_CHAT_FRAME:AddMessage("WCS Dashboard - Comandos:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsdash show - Mostrar dashboard", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsdash hide - Ocultar dashboard", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsdash toggle - Toggle dashboard", 1, 1, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/wcsdash reset - Reset estadísticas", 1, 1, 1)
    end
end
SLASH_WCSDASHBOARD1 = "/wcsdash"
SLASH_WCSDASHBOARD2 = "/wcsdashboard"

-- Inicializar al cargar
if WCS_Brain.Notifications then
    WCS_Brain.Notifications:Info("Dashboard de rendimiento cargado. Usa /wcsdash")
end
