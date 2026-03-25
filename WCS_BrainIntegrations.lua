--[[
    WCS_BrainIntegrations.lua - Sistema de Integración con Addons v6.4.2
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Integración con addons populares:
    - Damage Meters (Recount, DamageMeters, etc.)
    - Threat Meters (KTM, Omen, etc.)
    - Boss Mods (BigWigs, CTRaidAssist, etc.)
    - Unit Frames (Discord Unit Frames, etc.)
    - Casting Bars (Quartz, etc.)
]]--

WCS_BrainIntegrations = WCS_BrainIntegrations or {}
WCS_BrainIntegrations.VERSION = "6.4.2"
WCS_BrainIntegrations.enabled = true

-- ============================================================================
-- CONFIGURACIÓN DE INTEGRACIONES
-- ============================================================================
WCS_BrainIntegrations.Config = {
    enableDamageMeters = true,
    enableThreatMeters = true,
    enableBossMods = true,
    enableUnitFrames = true,
    enableCastingBars = true,
    autoDetect = true,
    updateInterval = 1.0,
    debugMode = false
}

-- ============================================================================
-- DETECCIÓN DE ADDONS
-- ============================================================================
WCS_BrainIntegrations.DetectedAddons = {
    damageMeters = {},
    threatMeters = {},
    bossMods = {},
    unitFrames = {},
    castingBars = {},
    bagAddons = {},
    auctionHouse = {},
    questHelpers = {},
    actionBars = {},
    buffDebuff = {},
    combatText = {},
    cooldownTrackers = {},
    other = {}
}

-- Lista de addons conocidos
WCS_BrainIntegrations.KnownAddons = {
    -- Damage Meters
    damageMeters = {
        "Recount", "DamageMeters", "SW_Stats", "Recap", "TinyDPS", "TerrorMeter"
    },
    
    -- Threat Meters
    threatMeters = {
        "KTM", "KLHThreatMeter", "Omen", "ThreatMeter", "ClassicThreatMeter"
    },
    
    -- Boss Mods
    bossMods = {
        "BigWigs", "CTRaidAssist", "CTRA", "BossWarnings", "RaidAlert"
    },
    
    -- Unit Frames
    unitFrames = {
        "DiscordUnitFrames", "ag_UnitFrames", "Perl", "XPerl", "PitBull"
    },
    
    -- Casting Bars
    castingBars = {
        "Quartz", "eCastingBar", "CastingBarMod", "ImprovedCastBar"
    },

    -- Bag Addons
    bagAddons = {
        "Bagnon", "OneBag", "ArkInventory", "Enginventory", "BagBrother"
    },

    -- Auction House
    auctionHouse = {
        "Auctioneer", "aux-addon", "BeanCounter", "AuctionMaster"
    },

    -- Quest Helpers
    questHelpers = {
        "Questie", "ShaguQuest", "QuestHelper", "MonkeyQuest", "QuestLog"
    },

    -- Action Bars
    actionBars = {
        "Bartender", "Bongos", "CT_BarMod", "Discord_ActionBars", "FlexBar"
    },

    -- Buff/Debuff
    buffDebuff = {
        "Buffalo", "Buffwatch", "ClassicAuraDurations", "DebuffTimers"
    },

    -- Combat Text
    combatText = {
        "SCT", "MSBT", "Parrot", "CombatText", "xCT"
    },

    -- Cooldown Trackers
    cooldownTrackers = {
        "OmniCC", "CooldownCount", "ClassicCastbars", "CooldownTimers"
    }
}

-- Detectar addons instalados
function WCS_BrainIntegrations:DetectAddons()
    self:Log("Detectando addons instalados...")
    
    -- Limpiar detecciones previas
    for category, _ in self.DetectedAddons do
        self.DetectedAddons[category] = {}
    end
    
    -- Detectar por categoría
    for category, addonList in self.KnownAddons do
        for _, addonName in addonList do
            if self:IsAddonLoaded(addonName) then
                table.insert(self.DetectedAddons[category], addonName)
                self:Log("Detectado " .. category .. ": " .. addonName)
            end
        end
    end
    
    -- Mostrar resumen
    self:ShowDetectionSummary()
end

-- Verificar si un addon está cargado
function WCS_BrainIntegrations:IsAddonLoaded(addonName)
    -- Método 1: Verificar variables globales conocidas
    local globalVars = {
        ["Recount"] = "Recount",
        ["DamageMeters"] = "DM",
        -- Damage Meters adicionales
        ["SW_Stats"] = "SW_Stats",
        ["Recap"] = "Recap",
        ["TinyDPS"] = "TinyDPS",
        ["TerrorMeter"] = "TerrorMeter",
        -- Threat Meters adicionales
        ["KLHThreatMeter"] = "KLHThreatMeter",
        ["Omen"] = "Omen",
        ["ThreatMeter"] = "ThreatMeter",
        ["ClassicThreatMeter"] = "ClassicThreatMeter",
        -- Boss Mods adicionales
        ["CTRaidAssist"] = "CT_RaidAssist",
        ["CTRA"] = "CT_RaidAssist",
        ["BossWarnings"] = "BossWarnings",
        ["RaidAlert"] = "RaidAlert",
        -- Unit Frames adicionales
        ["ag_UnitFrames"] = "ag_UnitFrames",
        ["Perl"] = "Perl_Config",
        ["XPerl"] = "XPerl",
        ["PitBull"] = "PitBull",
        -- Casting Bars adicionales
        ["eCastingBar"] = "eCastingBar",
        ["CastingBarMod"] = "CastingBarMod",
        ["ImprovedCastBar"] = "ImprovedCastBar",
        -- Bag Addons
        ["Bagnon"] = "Bagnon",
        ["OneBag"] = "OneBag",
        ["ArkInventory"] = "ArkInventory",
        ["Enginventory"] = "Enginventory",
        ["BagBrother"] = "BagBrother",
        -- Auction House
        ["Auctioneer"] = "Auctioneer",
        ["aux-addon"] = "aux",
        ["BeanCounter"] = "BeanCounter",
        ["AuctionMaster"] = "AuctionMaster",
        -- Quest Helpers
        ["Questie"] = "QuestieLoader",
        ["ShaguQuest"] = "ShaguQuest",
        ["QuestHelper"] = "QuestHelper",
        ["MonkeyQuest"] = "MonkeyQuest",
        ["QuestLog"] = "QuestLog",
        -- Action Bars
        ["Bartender"] = "Bartender",
        ["Bongos"] = "Bongos",
        ["CT_BarMod"] = "CT_BarMod",
        ["Discord_ActionBars"] = "DiscordActionBars",
        ["FlexBar"] = "FlexBar",
        -- Buff/Debuff
        ["Buffalo"] = "Buffalo",
        ["Buffwatch"] = "Buffwatch",
        ["ClassicAuraDurations"] = "ClassicAuraDurations",
        ["DebuffTimers"] = "DebuffTimers",
        -- Combat Text
        ["SCT"] = "SCT",
        ["MSBT"] = "MSBTMain",
        ["Parrot"] = "Parrot",
        ["CombatText"] = "CombatText",
        ["xCT"] = "xCT",
        -- Cooldown Trackers
        ["OmniCC"] = "OmniCC",
        ["CooldownCount"] = "CooldownCount",
        ["ClassicCastbars"] = "ClassicCastbars",
        ["CooldownTimers"] = "CooldownTimers"
    }

    
    if globalVars[addonName] and _G[globalVars[addonName]] then
        return true
    end
    
    -- Método 2: Verificar por nombre directo
    if _G[addonName] then
        return true
    end
    
    -- Método 3: Verificar funciones específicas
    local specificChecks = {
        ["Recount"] = function() return Recount and Recount.db end,
        ["KTM"] = function() return KTM and KTM.GetThreat end,
        ["BigWigs"] = function() return BigWigs and BigWigs.RegisterModule end,
        ["Questie"] = function() return QuestieLoader or Questie end,
        ["aux-addon"] = function() return aux and aux.scan end,
        ["Bagnon"] = function() return Bagnon and Bagnon.GetVersion end
    }
    
    if specificChecks[addonName] and specificChecks[addonName]() then
        return true
    end
    
    return false
end

-- Mostrar resumen de detección
function WCS_BrainIntegrations:ShowDetectionSummary()
    local totalDetected = 0
    
    for category, addons in self.DetectedAddons do
        totalDetected = totalDetected + WCS_TableCount(addons)
    end
    
    self:Log("=== RESUMEN DE DETECCIÓN ===")
    self:Log("Total de addons detectados: " .. totalDetected)
    
    for category, addons in self.DetectedAddons do
        if WCS_TableCount(addons) > 0 then
            self:Log(string.upper(category) .. ": " .. table.concat(addons, ", "))
        end
    end
end

-- ============================================================================
-- INTEGRACIÓN CON DAMAGE METERS
-- ============================================================================
WCS_BrainIntegrations.DamageMeters = {}

-- Obtener DPS actual de Recount
function WCS_BrainIntegrations.DamageMeters:GetRecountDPS()
    if not Recount or not Recount.db then return 0 end
    
    local playerName = UnitName("player")
    local combatData = Recount.db.profile.CombatTimes
    
    if not combatData or not combatData[playerName] then return 0 end
    
    local damage = combatData[playerName].Damage or 0
    local time = combatData[playerName].ActiveTime or 1
    
    return time > 0 and (damage / time) or 0
end

-- Obtener datos de DamageMeters
function WCS_BrainIntegrations.DamageMeters:GetDamageMetersData()
    if not DM or not DM.GetDamage then return {} end
    
    local playerName = UnitName("player")
    return DM.GetDamage(playerName) or {}
end

-- Obtener DPS promedio de cualquier damage meter
function WCS_BrainIntegrations.DamageMeters:GetCurrentDPS()
    -- Intentar Recount primero
    if WCS_TableCount(WCS_BrainIntegrations.DetectedAddons.damageMeters) > 0 then
        for _, addon in WCS_BrainIntegrations.DetectedAddons.damageMeters do
            if addon == "Recount" then
                return self:GetRecountDPS()
            elseif addon == "DamageMeters" then
                local data = self:GetDamageMetersData()
                return data.dps or 0
            end
        end
    end
    
    return 0
end

-- ============================================================================
-- INTEGRACIÓN CON THREAT METERS
-- ============================================================================
WCS_BrainIntegrations.ThreatMeters = {}

-- Obtener threat de KTM
function WCS_BrainIntegrations.ThreatMeters:GetKTMThreat()
    if not KTM or not KTM.GetThreat then return 0, 0 end
    
    local playerThreat = KTM.GetThreat("player", "target") or 0
    local maxThreat = 0
    
    -- Obtener threat máximo del grupo/raid
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local unit = "raid" .. i
            local threat = KTM.GetThreat(unit, "target") or 0
            if threat > maxThreat then
                maxThreat = threat
            end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local threat = KTM.GetThreat(unit, "target") or 0
            if threat > maxThreat then
                maxThreat = threat
            end
        end
    end
    
    return playerThreat, maxThreat
end

-- Obtener porcentaje de threat actual
function WCS_BrainIntegrations.ThreatMeters:GetThreatPercentage()
    if WCS_TableCount(WCS_BrainIntegrations.DetectedAddons.threatMeters) > 0 then
        for _, addon in WCS_BrainIntegrations.DetectedAddons.threatMeters do
            if addon == "KTM" then
                local playerThreat, maxThreat = self:GetKTMThreat()
                if maxThreat > 0 then
                    return (playerThreat / maxThreat) * 100
                end
            end
        end
    end
    
    return 0
end

-- Verificar si el threat está alto
function WCS_BrainIntegrations.ThreatMeters:IsThreatHigh(threshold)
    threshold = threshold or 80 -- 80% por defecto
    return self:GetThreatPercentage() > threshold
end

-- ============================================================================
-- INTEGRACIÓN CON BOSS MODS
-- ============================================================================
WCS_BrainIntegrations.BossMods = {}

-- Verificar si hay alerta de boss activa
function WCS_BrainIntegrations.BossMods:HasActiveBossAlert()
    -- BigWigs
    if BigWigs and BigWigs.inCombat then
        return BigWigs.inCombat
    end
    
    -- CTRaidAssist
    if CTRA_BossWarnings and CTRA_BossWarnings.active then
        return CTRA_BossWarnings.active
    end
    
    return false
end

-- Obtener información del boss actual
function WCS_BrainIntegrations.BossMods:GetCurrentBossInfo()
    local info = {
        name = "",
        phase = 0,
        abilities = {},
        warnings = {}
    }
    
    -- Intentar obtener de BigWigs
    if BigWigs and BigWigs.currentBoss then
        info.name = BigWigs.currentBoss.name or ""
        info.phase = BigWigs.currentBoss.phase or 0
    end
    
    return info
end

-- ============================================================================
-- INTEGRACIÓN CON UNIT FRAMES
-- ============================================================================
WCS_BrainIntegrations.UnitFrames = {}

-- Obtener información extendida del target
function WCS_BrainIntegrations.UnitFrames:GetExtendedTargetInfo()
    local info = {
        name = UnitName("target") or "",
        level = UnitLevel("target") or 0,
        classification = UnitClassification("target") or "",
        creatureType = UnitCreatureType("target") or "",
        health = UnitHealth("target") or 0,
        maxHealth = UnitHealthMax("target") or 1,
        mana = UnitMana("target") or 0,
        maxMana = UnitManaMax("target") or 0,
        buffs = {},
        debuffs = {}
    }
    
    -- Obtener buffs y debuffs si hay unit frames avanzados
    if DiscordUnitFrames then
        -- Discord Unit Frames tiene funciones extendidas
        info.buffs = self:GetTargetBuffs()
        info.debuffs = self:GetTargetDebuffs()
    end
    
    return info
end

-- Obtener buffs del target
function WCS_BrainIntegrations.UnitFrames:GetTargetBuffs()
    local buffs = {}
    
    for i = 1, 16 do
        local texture = UnitBuff("target", i)
        if texture then
            table.insert(buffs, {
                index = i,
                texture = texture,
                name = "Unknown" -- WoW 1.12 no tiene UnitBuff con nombre
            })
        end
    end
    
    return buffs
end

-- Obtener debuffs del target
function WCS_BrainIntegrations.UnitFrames:GetTargetDebuffs()
    local debuffs = {}
    
    for i = 1, 16 do
        local texture, stacks = UnitDebuff("target", i)
        if texture then
            table.insert(debuffs, {
                index = i,
                texture = texture,
                stacks = stacks or 1,
                name = "Unknown"
            })
        end
    end
    
    return debuffs
end

-- ============================================================================
-- SISTEMA DE HOOKS Y CALLBACKS
-- ============================================================================
WCS_BrainIntegrations.Hooks = {
    damageCallbacks = {},
    threatCallbacks = {},
    bossCallbacks = {}
}

-- Registrar callback para eventos de damage
function WCS_BrainIntegrations:RegisterDamageCallback(callback)
    table.insert(self.Hooks.damageCallbacks, callback)
end

-- Registrar callback para eventos de threat
function WCS_BrainIntegrations:RegisterThreatCallback(callback)
    table.insert(self.Hooks.threatCallbacks, callback)
end

-- Registrar callback para eventos de boss
function WCS_BrainIntegrations:RegisterBossCallback(callback)
    table.insert(self.Hooks.bossCallbacks, callback)
end

-- Ejecutar callbacks de damage
function WCS_BrainIntegrations:FireDamageCallbacks(data)
    for _, callback in self.Hooks.damageCallbacks do
        if type(callback) == "function" then
            callback(data)
        end
    end
end

-- ============================================================================
-- INTEGRACIÓN CON WCS_BRAIN
-- ============================================================================

-- Modificar decisiones basado en datos de addons
function WCS_BrainIntegrations:ModifyBrainDecision(spell, score, category)
    local modifiedScore = score
    
    -- Modificar basado en threat
    if self.Config.enableThreatMeters and self.ThreatMeters:IsThreatHigh(75) then
        -- Reducir agresividad si threat está alto
        if category == "damage" then
            modifiedScore = modifiedScore * 0.7
            self:DebugLog("Reduciendo agresividad por threat alto: " .. spell)
        elseif category == "utility" and spell == "Soulshatter" then
            modifiedScore = modifiedScore * 1.5 -- Priorizar Soulshatter
        end
    end
    
    -- Modificar basado en boss mods
    if self.Config.enableBossMods and self.BossMods:HasActiveBossAlert() then
        -- En combate de boss, priorizar supervivencia
        if category == "survival" then
            modifiedScore = modifiedScore * 1.2
        end
    end
    
    -- Modificar basado en DPS actual
    if self.Config.enableDamageMeters then
        local currentDPS = self.DamageMeters:GetCurrentDPS()
        if currentDPS > 0 then
            -- Si el DPS está bajo, priorizar hechizos de daño
            local expectedDPS = UnitLevel("player") * 10 -- DPS esperado básico
            if currentDPS < expectedDPS * 0.8 then
                if category == "damage" then
                    modifiedScore = modifiedScore * 1.1
                end
            end
        end
    end
    
    return modifiedScore
end

-- Hook WCS_BrainAI para integrar modificaciones
function WCS_BrainIntegrations:HookBrainAI()
    if not WCS_BrainAI then return end
    
    -- Guardar función original si no existe
    if not self.originalCalculateSpellScore then
        self.originalCalculateSpellScore = WCS_BrainAI.CalculateSpellScore
    end
    
    -- Override con integración de addons
    WCS_BrainAI.CalculateSpellScore = function(self, spell, category)
        local baseScore = WCS_BrainIntegrations.originalCalculateSpellScore(self, spell, category)
        return WCS_BrainIntegrations:ModifyBrainDecision(spell, baseScore, category)
    end
end

-- ============================================================================
-- COMANDOS
-- ============================================================================
function WCS_BrainIntegrations:RegisterCommands()
    SLASH_WCSINTEGRATION1 = "/wcsint"
    SlashCmdList["WCSINTEGRATION"] = function(msg)
        local args = {}
        for word in string.gfind(msg, "%S+") do
            table.insert(args, string.lower(word))
        end
        
        if not args[1] or args[1] == "help" then
            self:ShowHelp()
        elseif args[1] == "detect" then
            self:DetectAddons()
        elseif args[1] == "status" then
            self:ShowStatus()
        elseif args[1] == "dps" then
            self:ShowDPSInfo()
        elseif args[1] == "threat" then
            self:ShowThreatInfo()
        elseif args[1] == "boss" then
            self:ShowBossInfo()
        elseif args[1] == "toggle" and args[2] then
            self:ToggleIntegration(args[2])
        elseif args[1] == "debug" then
            self:ToggleDebug()
        else
            self:Log("Comando desconocido. Usa /wcsint help")
        end
    end
end

function WCS_BrainIntegrations:ShowHelp()
    self:Log("=== COMANDOS DE INTEGRACIÓN ===")
    self:Log("/wcsint detect - Detectar addons instalados")
    self:Log("/wcsint status - Ver estado de integraciones")
    self:Log("/wcsint dps - Mostrar información de DPS")
    self:Log("/wcsint threat - Mostrar información de threat")
    self:Log("/wcsint boss - Mostrar información de boss")
    self:Log("/wcsint toggle <tipo> - Activar/desactivar integración")
    self:Log("/wcsint debug - Toggle modo debug")
    self:Log("Tipos: damage, threat, boss, unitframes, casting")
end

function WCS_BrainIntegrations:ShowStatus()
    self:Log("=== ESTADO DE INTEGRACIONES ===")
    self:Log("Damage Meters: " .. (self.Config.enableDamageMeters and "ON" or "OFF"))
    self:Log("Threat Meters: " .. (self.Config.enableThreatMeters and "ON" or "OFF"))
    self:Log("Boss Mods: " .. (self.Config.enableBossMods and "ON" or "OFF"))
    self:Log("Unit Frames: " .. (self.Config.enableUnitFrames and "ON" or "OFF"))
    self:Log("Casting Bars: " .. (self.Config.enableCastingBars and "ON" or "OFF"))
    
    self:ShowDetectionSummary()
end

function WCS_BrainIntegrations:ShowDPSInfo()
    if not self.Config.enableDamageMeters then
        self:Log("Integración con Damage Meters desactivada")
        return
    end
    
    local dps = self.DamageMeters:GetCurrentDPS()
    self:Log("=== INFORMACIÓN DE DPS ===")
    self:Log("DPS Actual: " .. string.format("%.1f", dps))
    
    if WCS_TableCount(self.DetectedAddons.damageMeters) > 0 then
        self:Log("Addons detectados: " .. table.concat(self.DetectedAddons.damageMeters, ", "))
    else
        self:Log("No se detectaron damage meters")
    end
end

function WCS_BrainIntegrations:ShowThreatInfo()
    if not self.Config.enableThreatMeters then
        self:Log("Integración con Threat Meters desactivada")
        return
    end
    
    local threatPct = self.ThreatMeters:GetThreatPercentage()
    self:Log("=== INFORMACIÓN DE THREAT ===")
    self:Log("Threat Actual: " .. string.format("%.1f%%", threatPct))
    self:Log("Threat Alto: " .. (self.ThreatMeters:IsThreatHigh() and "SÍ" or "NO"))
    
    if WCS_TableCount(self.DetectedAddons.threatMeters) > 0 then
        self:Log("Addons detectados: " .. table.concat(self.DetectedAddons.threatMeters, ", "))
    else
        self:Log("No se detectaron threat meters")
    end
end

function WCS_BrainIntegrations:ToggleIntegration(type)
    local configMap = {
        damage = "enableDamageMeters",
        threat = "enableThreatMeters",
        boss = "enableBossMods",
        unitframes = "enableUnitFrames",
        casting = "enableCastingBars"
    }
    
    local configKey = configMap[type]
    if not configKey then
        self:Log("Tipo de integración inválido: " .. type)
        return
    end
    
    self.Config[configKey] = not self.Config[configKey]
    self:Log("Integración " .. type .. ": " .. (self.Config[configKey] and "ON" or "OFF"))
end

function WCS_BrainIntegrations:ToggleDebug()
    self.Config.debugMode = not self.Config.debugMode
    self:Log("Modo debug: " .. (self.Config.debugMode and "ON" or "OFF"))
end

-- ============================================================================
-- UTILIDADES
-- ============================================================================
function WCS_BrainIntegrations:Log(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Integration]|r " .. message)
end

function WCS_BrainIntegrations:DebugLog(message)
    if self.Config.debugMode then
        self:Log("[DEBUG] " .. message)
    end
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainIntegrations:Initialize()
    self:RegisterCommands()
    
    -- Detectar addons automáticamente
    if self.Config.autoDetect then
        self:DetectAddons()
    end
    
    -- Hook WCS_BrainAI si está disponible
    self:HookBrainAI()
    
    self:Log("Sistema de Integraciones v" .. self.VERSION .. " inicializado")
end

-- Auto-inicialización
if WCS_BrainCore and WCS_BrainCore.RegisterModule then
    WCS_BrainCore:RegisterModule("Integrations", WCS_BrainIntegrations)
end

-- Inicialización manual
local function InitializeIntegrations()
    if WCS_BrainIntegrations then
        WCS_BrainIntegrations:Initialize()
    end
end

-- Registrar eventos
if not WCS_BrainIntegrations.initialized then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("VARIABLES_LOADED")
    
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
            InitializeIntegrations()
            WCS_BrainIntegrations.initialized = true
        elseif event == "VARIABLES_LOADED" then
            -- Re-detectar addons después de que todos estén cargados
            if WCS_BrainIntegrations.initialized then
                WCS_BrainIntegrations:DetectAddons()
            end
        end
    end)
end
