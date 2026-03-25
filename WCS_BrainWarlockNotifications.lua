--[[
    WCS_BrainWarlockNotifications.lua - Sistema de Notificaciones para Warlock
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 1.0.0
    
    Notificaciones inteligentes para eventos importantes del Warlock:
    - Demon Armor por expirar
    - Demonios mayores por rebelarse
    - Soul Shards bajos
    - Healthstones disponibles
    - Buffs importantes
]]--

WCS_BrainWarlockNotif = WCS_BrainWarlockNotif or {}
local WarlockNotif = WCS_BrainWarlockNotif

WarlockNotif.VERSION = "1.0.0"
WarlockNotif.enabled = true
WarlockNotif.initialized = false

-- ============================================================================
-- CONFIGURACIÓN
-- ============================================================================
WarlockNotif.Config = {
    -- Tiempos de advertencia (segundos antes de expirar)
    demonArmorWarning = 60,      -- Avisar 60s antes
    soulLinkWarning = 30,        -- Avisar 30s antes
    felDominationWarning = 10,   -- Avisar 10s antes
    
    -- Umbrales
    soulShardLowThreshold = 3,   -- Avisar si < 3 soul shards
    soulShardCriticalThreshold = 1, -- Crítico si < 1
    
    -- Rebelión de demonios
    checkEnslavedInterval = 5,   -- Verificar cada 5s
    enslavedWarningTime = 10,    -- Avisar 10s antes de rebelión
    
    -- Healthstones
    notifyHealthstoneReady = true,
    healthstoneCheckInterval = 30, -- Verificar cada 30s
    
    -- Otros buffs
    checkBuffsInterval = 10      -- Verificar buffs cada 10s
}

-- ============================================================================
-- ESTADO
-- ============================================================================
WarlockNotif.State = {
    lastBuffCheck = 0,
    lastEnslavedCheck = 0,
    lastHealthstoneCheck = 0,
    lastSoulShardCheck = 0,
    
    -- Tracking de notificaciones para evitar spam
    lastNotifications = {
        demonArmor = 0,
        soulLink = 0,
        soulShards = 0,
        enslaved = 0,
        healthstone = 0
    }
}

-- ============================================================================
-- NOMBRES DE SPELLS/BUFFS (WoW 1.12)
-- ============================================================================
WarlockNotif.Spells = {
    -- Armors
    DemonSkin = "Demon Skin",
    DemonArmor = "Demon Armor",
    
    -- Buffs importantes
    SoulLink = "Soul Link",
    FelDomination = "Fel Domination",
    
    -- Control
    EnslaveDemon = "Enslave Demon",
    
    -- Items
    Healthstone = "Healthstone",
    Soulstone = "Soulstone"
}

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WarlockNotif:Initialize()
    -- Intento de usar WCS_EventManager si está disponible
    if WCS_EventManager and WCS_EventManager.Register then
        WCS_EventManager:Register("PLAYER_ENTERING_WORLD", function() WarlockNotif:DelayedInitialize() end, "WCS_WarlockNotif_Init")
        WCS_EventManager:Register("PLAYER_LOGIN", function() WarlockNotif:DelayedInitialize() end, "WCS_WarlockNotif_Init")
    else
        -- Fallback Legacy
        self.initFrame = CreateFrame("Frame")
        self.initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.initFrame:RegisterEvent("PLAYER_LOGIN")
        self.initFrame:SetScript("OnEvent", function()
            WarlockNotif:DelayedInitialize()
        end)
    end
end

function WarlockNotif:DelayedInitialize()
    -- Solo inicializar una vez
    if self.initialized then return end
    
    -- Verificar dependencias... (código omitido igual al original)
    if not WCS_Brain then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS Warlock]|r WCS_Brain no encontrado")
        self.enabled = false
        return
    end
    
    -- ... (verificaciones de clase) ...
    local _, class = UnitClass("player")
    if not class then return end
    if class ~= "WARLOCK" then self.enabled = false return end
    
    self.initialized = true
    
    -- Limpiar inicializador
    if WCS_EventManager and WCS_EventManager.Unregister then
        WCS_EventManager:Unregister("PLAYER_ENTERING_WORLD", "WCS_WarlockNotif_Init")
        WCS_EventManager:Unregister("PLAYER_LOGIN", "WCS_WarlockNotif_Init")
    elseif self.initFrame then
        self.initFrame:UnregisterAllEvents()
        self.initFrame = nil
    end
    
    -- Registrar eventos principales
    local function EventHandler(event, arg1)
        WarlockNotif:OnEvent(event, arg1)
    end
    
    if WCS_EventManager and WCS_EventManager.Register then
        WCS_EventManager:Register("PLAYER_ENTERING_WORLD", EventHandler, "WCS_WarlockNotif")
        WCS_EventManager:Register("UNIT_AURA", EventHandler, "WCS_WarlockNotif")
        WCS_EventManager:Register("BAG_UPDATE", EventHandler, "WCS_WarlockNotif")
        WCS_EventManager:Register("PLAYER_REGEN_DISABLED", EventHandler, "WCS_WarlockNotif")
        WCS_EventManager:Register("PLAYER_REGEN_ENABLED", EventHandler, "WCS_WarlockNotif")
    else
        -- Fallback Legacy Frame
        self.frame = CreateFrame("Frame")
        self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.frame:RegisterEvent("UNIT_AURA")
        self.frame:RegisterEvent("BAG_UPDATE")
        self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.frame:SetScript("OnEvent", function()
            WarlockNotif:OnEvent(event, arg1)
        end)
    end
    
    -- Frame para actualizaciones periódicas (OnUpdate sigue necesitando frame propio por ahora)
    self.updateFrame = CreateFrame("Frame")
    self.updateFrame:SetScript("OnUpdate", function()
        WarlockNotif:OnUpdate(arg1)
    end)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9WCS Warlock Notifications|r v" .. self.VERSION .. " cargado (Core: " .. (WCS_EventManager and "EventBus" or "Legacy") .. ")")
end

-- ============================================================================
-- EVENTOS
-- ============================================================================
function WarlockNotif:OnEvent(event, arg1)
    if not self.enabled or not self.initialized then return end
    
    if event == "PLAYER_ENTERING_WORLD" then
        self:CheckAllBuffs()
        self:CheckSoulShards()
        
    elseif event == "UNIT_AURA" and arg1 == "player" then
        self:CheckAllBuffs()
        
    elseif event == "BAG_UPDATE" then
        self:CheckSoulShards()
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entrar en combate: verificar preparación
        self:CheckCombatReadiness()
    end
end

-- ============================================================================
-- ACTUALIZACIÓN PERIÓDICA
-- ============================================================================
function WarlockNotif:OnUpdate(elapsed)
    if not self.enabled or not self.initialized then return end
    
    local now = GetTime()
    
    -- Verificar buffs
    if now - self.State.lastBuffCheck >= self.Config.checkBuffsInterval then
        self.State.lastBuffCheck = now
        self:CheckAllBuffs()
    end
    
    -- Verificar demonios esclavizados
    if now - self.State.lastEnslavedCheck >= self.Config.checkEnslavedInterval then
        self.State.lastEnslavedCheck = now
        self:CheckEnslavedDemon()
    end
    
    -- Verificar healthstones
    if now - self.State.lastHealthstoneCheck >= self.Config.healthstoneCheckInterval then
        self.State.lastHealthstoneCheck = now
        self:CheckHealthstone()
    end
    
    -- Verificar soul shards
    if now - self.State.lastSoulShardCheck >= 15 then -- Cada 15s
        self.State.lastSoulShardCheck = now
        self:CheckSoulShards()
    end
end

-- ============================================================================
-- VERIFICACIONES
-- ============================================================================

-- Verificar todos los buffs importantes
function WarlockNotif:CheckAllBuffs()
    self:CheckDemonArmor()
    self:CheckSoulLink()
    self:CheckFelDomination()
end

-- Verificar Demon Armor
function WarlockNotif:CheckDemonArmor()
    local hasDemonArmor = self:HasBuff(self.Spells.DemonArmor)
    local hasDemonSkin = self:HasBuff(self.Spells.DemonSkin)
    
    local now = GetTime()
    
    if not hasDemonArmor and not hasDemonSkin then
        -- No tiene ningún armor
        if now - self.State.lastNotifications.demonArmor >= 60 then
            self.State.lastNotifications.demonArmor = now
            WCS_BrainNotifications:Warning("No tienes Demon Armor activo!")
        end
    end
    -- Nota: No podemos detectar tiempo de expiración en WoW 1.12 sin addons adicionales
end

-- Verificar Soul Link
function WarlockNotif:CheckSoulLink()
    if not UnitExists("pet") then return end
    
    local hasSoulLink = self:HasBuff(self.Spells.SoulLink)
    local now = GetTime()
    
    -- Solo avisar si NO tiene Soul Link (no podemos detectar tiempo en WoW 1.12)
    if not hasSoulLink then
        if now - self.State.lastNotifications.soulLink >= 120 then
            self.State.lastNotifications.soulLink = now
            WCS_BrainNotifications:Info("Soul Link no activo")
        end
    end
end

-- Verificar Fel Domination
function WarlockNotif:CheckFelDomination()
    -- Fel Domination es un buff instantáneo, no necesita verificación periódica
    -- Se puede agregar lógica específica si es necesario
end

-- Verificar demonio esclavizado
function WarlockNotif:CheckEnslavedDemon()
    if not UnitExists("pet") then return end
    
    -- Verificar si el pet es un demonio esclavizado
    local creatureFamily = UnitCreatureFamily("pet")
    if not creatureFamily then return end
    
    -- Buscar el buff de Enslave Demon en el pet
    local hasEnslave = self:HasBuff(self.Spells.EnslaveDemon, "pet")
    
    -- Nota: En WoW 1.12 no podemos obtener el tiempo restante de buffs
    -- Esta funcionalidad requiere addons como ClassicAuraDurations
    -- Por ahora, solo verificamos si existe el buff
    if hasEnslave then
        -- El demonio está esclavizado, pero no podemos saber cuánto tiempo queda
        -- Se podría agregar integración con ClassicAuraDurations en el futuro
    end
end

-- Verificar Soul Shards
function WarlockNotif:CheckSoulShards()
    local count = self:CountSoulShards()
    local now = GetTime()
    
    if count <= self.Config.soulShardCriticalThreshold then
        if now - self.State.lastNotifications.soulShards >= 30 then
            self.State.lastNotifications.soulShards = now
            WCS_BrainNotifications:Critical(
                string.format("SOUL SHARDS CRITICO! (%d)", count)
            )
        end
    elseif count <= self.Config.soulShardLowThreshold then
        if now - self.State.lastNotifications.soulShards >= 60 then
            self.State.lastNotifications.soulShards = now
            WCS_BrainNotifications:Warning(
                string.format("Soul Shards bajos: %d", count)
            )
        end
    end
end

-- Verificar Healthstone
function WarlockNotif:CheckHealthstone()
    if not self.Config.notifyHealthstoneReady then return end
    
    local hasHealthstone = self:HasHealthstone()
    local healthstoneCooldown = self:GetHealthstoneCooldown()
    
    if not hasHealthstone and healthstoneCooldown == 0 then
        local now = GetTime()
        if now - self.State.lastNotifications.healthstone >= 120 then
            self.State.lastNotifications.healthstone = now
            WCS_BrainNotifications:Info("Puedes crear Healthstone")
        end
    end
end

-- Verificar preparación para combate
function WarlockNotif:CheckCombatReadiness()
    local warnings = {}
    
    -- Verificar armor
    if not self:HasBuff(self.Spells.DemonArmor) and not self:HasBuff(self.Spells.DemonSkin) then
        table.insert(warnings, "Sin Demon Armor")
    end
    
    -- Verificar soul shards
    local shards = self:CountSoulShards()
    if shards < 2 then
        table.insert(warnings, "Soul Shards bajos")
    end
    
    -- Verificar healthstone
    if not self:HasHealthstone() then
        table.insert(warnings, "Sin Healthstone")
    end
    
    if table.getn(warnings) > 0 then
        WCS_BrainNotifications:Warning(
            "Combate: " .. table.concat(warnings, ", ")
        )
    end
end

-- ============================================================================
-- FUNCIONES HELPER
-- ============================================================================

-- Función helper para normalizar nombres de hechizos (español -> inglés)
local function NormalizeSpellName(spellName)
    if not spellName then return spellName end
    
    -- Si WCS_SpellLocalization existe y tiene la tabla esES, usarla
    if WCS_SpellLocalization and WCS_SpellLocalization.esES then
        local englishName = WCS_SpellLocalization.esES[spellName]
        if englishName then
            return englishName
        end
    end
    
    -- Si no se encontró traducción, retornar el nombre original
    return spellName
end

-- Verificar si tiene un buff
function WarlockNotif:HasBuff(buffName, unit)
    unit = unit or "player"
    local i = 1
    
    -- Normalizar el nombre del buff que buscamos (convertir a inglés si está en español)
    local normalizedSearchName = NormalizeSpellName(buffName)
    
    while true do
        local buffTexture = UnitBuff(unit, i)
        if not buffTexture then break end
        
        -- Obtener el tooltip del buff para comparar el nombre
        WCS_TooltipScanner = WCS_TooltipScanner or CreateFrame("GameTooltip", "WCS_TooltipScanner", nil, "GameTooltipTemplate")
        WCS_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
        WCS_TooltipScanner:SetUnitBuff(unit, i)
        
        local tooltipText = WCS_TooltipScannerTextLeft1:GetText()
        if tooltipText then
            -- Normalizar el nombre del buff encontrado (español -> inglés)
            local normalizedBuffName = NormalizeSpellName(tooltipText)
            
            -- Comparar nombres normalizados (ambos en inglés)
            if normalizedBuffName == normalizedSearchName or string.find(normalizedBuffName, normalizedSearchName) then
                return true
            end
        end
        
        i = i + 1
    end
    return false
end

-- Obtener tiempo restante de un buff
function WarlockNotif:GetBuffTimeLeft(buffName, unit)
    unit = unit or "player"
    local i = 1
    
    -- Normalizar el nombre del buff que buscamos
    local normalizedSearchName = NormalizeSpellName(buffName)
    
    -- Crear tooltip scanner si no existe
    WCS_TooltipScanner = WCS_TooltipScanner or CreateFrame("GameTooltip", "WCS_TooltipScanner", nil, "GameTooltipTemplate")
    
    while true do
        local buffTexture = UnitBuff(unit, i)
        if not buffTexture then break end
        
        -- Obtener el tooltip del buff
        WCS_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
        WCS_TooltipScanner:SetUnitBuff(unit, i)
        
        local tooltipText = WCS_TooltipScannerTextLeft1:GetText()
        if tooltipText then
            -- Normalizar el nombre del buff encontrado
            local normalizedBuffName = NormalizeSpellName(tooltipText)
            
            -- Comparar nombres normalizados
            if normalizedBuffName == normalizedSearchName or string.find(normalizedBuffName, normalizedSearchName) then
                -- En WoW 1.12, no hay forma nativa de obtener el tiempo restante de buffs
                -- Necesitamos usar un addon como ClassicAuraDurations o estimarlo
                -- Por ahora, retornamos que existe pero sin tiempo
                return true, nil
            end
        end
        
        i = i + 1
    end
    return false, nil
end

-- Contar Soul Shards
function WarlockNotif:CountSoulShards()
    local count = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                -- Buscar por Item ID 6265 (mas confiable que nombre)
                -- El itemLink tiene formato |Hitem:6265:0:0:0|h[Soul Shard]|h
                if string.find(itemLink, "6265") then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    count = count + (itemCount or 1)
                else
                    -- Fallback: buscar por nombre (solo si GetItemInfo funciona)
                    local itemName = GetItemInfo(itemLink)
                    if itemName and (string.find(itemName, "Soul Shard") or string.find(itemName, "Fragmento de alma")) then
                        local _, itemCount = GetContainerItemInfo(bag, slot)
                        count = count + (itemCount or 1)
                    end
                end            end
        end
    end
    return count
end

-- Verificar si tiene Healthstone
function WarlockNotif:HasHealthstone()
    -- Item IDs de todas las Healthstones en WoW 1.12
    local healthstoneIDs = {"5512", "19004", "19005", "5511", "9421", "22103"}
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                -- Buscar por Item ID (mas confiable)
                for _, itemID in ipairs(healthstoneIDs) do
                    if string.find(itemLink, itemID) then
                        return true
                    end
                end
                -- Fallback: buscar por nombre
                local itemName = GetItemInfo(itemLink)
                if itemName and (string.find(itemName, "Healthstone") or string.find(itemName, "Piedra de salud")) then
                    return true
                end
            end
        end
    end
    return false
end

-- Obtener cooldown de Healthstone
function WarlockNotif:GetHealthstoneCooldown()
    -- Buscar el spell Create Healthstone en el spellbook
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end
        
        if string.find(spellName, "Create Healthstone") then
            local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
            if start and duration then
                local remaining = (start + duration) - GetTime()
                return math.max(0, remaining)
            end
            return 0
        end
        i = i + 1
    end
    return 0
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SlashCmdList["WCSWARLOCKNOTIF"] = function(msg)
    local cmd = string.lower(msg or "")
    
    -- Verificar si está inicializado
    if not WarlockNotif.initialized then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS Warlock]|r Sistema no inicializado.")
        DEFAULT_CHAT_FRAME:AddMessage("Debug:")
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_Brain: " .. (WCS_Brain and "OK" or "NO ENCONTRADO"))
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_BrainNotifications: " .. (WCS_BrainNotifications and "OK" or "NO ENCONTRADO"))
        
        local _, class = UnitClass("player")
        DEFAULT_CHAT_FRAME:AddMessage("  Clase: " .. (class or "NO DISPONIBLE"))
        DEFAULT_CHAT_FRAME:AddMessage("  Inicializado: No")
        DEFAULT_CHAT_FRAME:AddMessage("")
        DEFAULT_CHAT_FRAME:AddMessage("Intenta: /reload")
        return
    end
    
    if cmd == "toggle" then
        WarlockNotif.enabled = not WarlockNotif.enabled
        local status = WarlockNotif.enabled and "activadas" or "desactivadas"
        if WCS_BrainNotifications then
            WCS_BrainNotifications:Info("Notificaciones Warlock " .. status)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Warlock]|r Notificaciones " .. status)
        end
        
    elseif cmd == "test" then
        if WCS_BrainNotifications then
            WCS_BrainNotifications:Info("Test: Info")
            WCS_BrainNotifications:Warning("Test: Warning")
            WCS_BrainNotifications:Critical("Test: Critical")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFF[Test]|r Info")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[Test]|r Warning")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FF[Test]|r Critical")
        end
        
    elseif cmd == "status" or cmd == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9WCS Warlock Status|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Version: " .. WarlockNotif.VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("  Inicializado: " .. (WarlockNotif.initialized and "|cFF00FF00Si|r" or "|cFFFF0000No|r"))
        DEFAULT_CHAT_FRAME:AddMessage("  Habilitado: " .. (WarlockNotif.enabled and "|cFF00FF00Si|r" or "|cFFFF0000No|r"))
        DEFAULT_CHAT_FRAME:AddMessage("")
        DEFAULT_CHAT_FRAME:AddMessage("Dependencias:")
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_Brain: " .. (WCS_Brain and "|cFF00FF00OK|r" or "|cFFFF0000NO ENCONTRADO|r"))
        DEFAULT_CHAT_FRAME:AddMessage("  WCS_BrainNotifications: " .. (WCS_BrainNotifications and "|cFF00FF00OK|r" or "|cFFFF0000NO ENCONTRADO|r"))
        
        local _, class = UnitClass("player")
        DEFAULT_CHAT_FRAME:AddMessage("  Clase: " .. (class or "NO DISPONIBLE"))
        
        if WarlockNotif.initialized then
            DEFAULT_CHAT_FRAME:AddMessage("")
            DEFAULT_CHAT_FRAME:AddMessage("Estado del Warlock:")
            local shards = WarlockNotif:CountSoulShards()
            local hasHealthstone = WarlockNotif:HasHealthstone()
            local hasDemonArmor = WarlockNotif:HasBuff(WarlockNotif.Spells.DemonArmor)
            DEFAULT_CHAT_FRAME:AddMessage("  Soul Shards: " .. shards)
            DEFAULT_CHAT_FRAME:AddMessage("  Healthstone: " .. (hasHealthstone and "Si" or "No"))
            DEFAULT_CHAT_FRAME:AddMessage("  Demon Armor: " .. (hasDemonArmor and "Si" or "No"))
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9WCS Warlock Notifications|r v" .. WarlockNotif.VERSION)
        DEFAULT_CHAT_FRAME:AddMessage("Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/wcswarlock status|r - Ver estado y debug")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/wcswarlock test|r - Probar notificaciones")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/wcswarlock toggle|r - Activar/desactivar")
        DEFAULT_CHAT_FRAME:AddMessage("")
        DEFAULT_CHAT_FRAME:AddMessage("Alias: |cFFFFCC00/wcslock|r")
    end
end
SLASH_WCSWARLOCKNOTIF1 = "/wcswarlock"
SLASH_WCSWARLOCKNOTIF2 = "/wcslock"

-- ============================================================================
-- INICIALIZAR AL CARGAR
-- ============================================================================
WarlockNotif:Initialize()
