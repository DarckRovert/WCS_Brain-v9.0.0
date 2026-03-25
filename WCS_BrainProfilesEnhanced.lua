-- WCS_BrainProfilesEnhanced.lua
-- Sistema mejorado de perfiles con auto-switch y presets
-- Version: 6.5.0
-- Author: Elnazzareno (DarckRovert)

WCS_BrainProfilesEnhanced = {
    VERSION = "6.5.0",
    
    -- Configuracion
    Config = {
        autoSwitch = true,
        autoSwitchDelay = 2, -- segundos
        maxProfiles = 20,
    },
    
    -- Perfiles predefinidos
    Presets = {
        ["Solo Leveling"] = {
            description = "Optimizado para leveling solo",
            settings = {
                dqnEnabled = true,
                smartAIEnabled = true,
                petAIEnabled = true,
                aggressiveness = 0.7,
                manaConservation = 0.6,
                dotUsage = 0.8,
                aoeThreshold = 3,
            },
        },
        ["Dungeon DPS"] = {
            description = "Maximo DPS para dungeons",
            settings = {
                dqnEnabled = true,
                smartAIEnabled = true,
                petAIEnabled = true,
                aggressiveness = 1.0,
                manaConservation = 0.3,
                dotUsage = 0.5,
                aoeThreshold = 2,
            },
        },
        ["Raid Support"] = {
            description = "Soporte y utilidad para raids",
            settings = {
                dqnEnabled = false,
                smartAIEnabled = true,
                petAIEnabled = true,
                aggressiveness = 0.5,
                manaConservation = 0.8,
                dotUsage = 0.9,
                aoeThreshold = 5,
            },
        },
        ["PvP Aggressive"] = {
            description = "PvP agresivo con burst",
            settings = {
                dqnEnabled = false,
                smartAIEnabled = true,
                petAIEnabled = true,
                aggressiveness = 1.0,
                manaConservation = 0.4,
                dotUsage = 0.6,
                aoeThreshold = 2,
                pvpMode = true,
            },
        },
        ["Farming"] = {
            description = "Farming eficiente de mobs",
            settings = {
                dqnEnabled = true,
                smartAIEnabled = true,
                petAIEnabled = true,
                aggressiveness = 0.8,
                manaConservation = 0.7,
                dotUsage = 0.9,
                aoeThreshold = 2,
            },
        },
    },
    
    -- Auto-switch rules
    AutoSwitchRules = {
        {
            name = "Dungeon",
            profile = "Dungeon DPS",
            condition = function()
                return GetNumPartyMembers() > 0 and IsInInstance()
            end,
        },
        {
            name = "Raid",
            profile = "Raid Support",
            condition = function()
                return GetNumRaidMembers() > 0
            end,
        },
        {
            name = "PvP",
            profile = "PvP Aggressive",
            condition = function()
                -- Detectar si hay jugadores enemigos cerca
                if UnitExists("target") and UnitIsPlayer("target") and UnitIsEnemy("player", "target") then
                    return true
                end
                return false
            end,
        },
        {
            name = "Solo",
            profile = "Solo Leveling",
            condition = function()
                return GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0
            end,
        },
    },
}

local PE = WCS_BrainProfilesEnhanced

-- Inicializar
function PE:Initialize()
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Inicializando sistema de perfiles mejorado v" .. self.VERSION)
    end
    
    -- Cargar saved variables
    if not WCS_BrainProfilesEnhancedSaved then
        WCS_BrainProfilesEnhancedSaved = {
            profiles = {},
            currentProfile = nil,
            autoSwitch = true,
            lastAutoSwitch = 0,
        }
    end
    
    self.Data = WCS_BrainProfilesEnhancedSaved
    
    -- Crear perfiles predefinidos si no existen
    for name, preset in pairs(self.Presets) do
        if not self.Data.profiles[name] then
            self:CreateProfile(name, preset.settings, preset.description)
        end
    end
    
    -- Iniciar auto-switch si esta habilitado
    if self.Data.autoSwitch then
        self:StartAutoSwitch()
    end
    
    -- Registrar comandos
    self:RegisterCommands()
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Sistema de perfiles inicializado con " .. self:GetProfileCount() .. " perfiles")
    end
end

-- Crear perfil
function PE:CreateProfile(name, settings, description)
    if not name or name == "" then
        return false, "Nombre invalido"
    end
    
    if self.Data.profiles[name] then
        return false, "El perfil ya existe"
    end
    
    if self:GetProfileCount() >= self.Config.maxProfiles then
        return false, "Maximo de perfiles alcanzado (" .. self.Config.maxProfiles .. ")"
    end
    
    self.Data.profiles[name] = {
        name = name,
        description = description or "",
        settings = settings or {},
        created = time(),
        lastUsed = 0,
        useCount = 0,
    }
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Perfil creado: " .. name)
    end
    
    return true
end

-- Cambiar perfil
function PE:SwitchProfile(name)
    if not self.Data.profiles[name] then
        return false, "Perfil no encontrado: " .. name
    end
    
    local profile = self.Data.profiles[name]
    
    -- Aplicar configuracion
    if profile.settings then
        self:ApplySettings(profile.settings)
    end
    
    -- Actualizar datos
    self.Data.currentProfile = name
    profile.lastUsed = time()
    profile.useCount = profile.useCount + 1
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Perfil cambiado a: " .. name)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Perfil cambiado a: |cFFFFFF00" .. name .. "|r")
    
    return true
end

-- Aplicar configuracion
function PE:ApplySettings(settings)
    if not settings then return end
    
    -- Aplicar a WCS_Brain
    if WCS_Brain then
        if settings.dqnEnabled ~= nil then
            WCS_Brain.Config.useDQN = settings.dqnEnabled
        end
        if settings.aggressiveness then
            WCS_Brain.Config.aggressiveness = settings.aggressiveness
        end
        if settings.manaConservation then
            WCS_Brain.Config.manaConservation = settings.manaConservation
        end
        if settings.dotUsage then
            WCS_Brain.Config.dotUsage = settings.dotUsage
        end
        if settings.aoeThreshold then
            WCS_Brain.Config.aoeThreshold = settings.aoeThreshold
        end
    end
    
    -- Aplicar a SmartAI
    if WCS_BrainSmartAI and WCS_BrainSmartAI.Config and settings.smartAIEnabled ~= nil then
        WCS_BrainSmartAI.Config.enabled = settings.smartAIEnabled
    end
    
    -- Aplicar a PetAI
    if WCS_BrainPetAI and WCS_BrainPetAI.Config and settings.petAIEnabled ~= nil then
        WCS_BrainPetAI.Config.enabled = settings.petAIEnabled
    end
    
    -- Aplicar a PvP
    if WCS_BrainPvP and WCS_BrainPvP.Config and settings.pvpMode ~= nil then
        WCS_BrainPvP.Config.enabled = settings.pvpMode
    end
end

-- Auto-switch
function PE:StartAutoSwitch()
    if self.autoSwitchFrame then return end
    
    self.autoSwitchFrame = CreateFrame("Frame")
    self.autoSwitchFrame:SetScript("OnUpdate", function()
        PE:OnAutoSwitchUpdate()
    end)
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Auto-switch activado")
    end
end

function PE:StopAutoSwitch()
    if self.autoSwitchFrame then
        self.autoSwitchFrame:SetScript("OnUpdate", nil)
        self.autoSwitchFrame = nil
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Auto-switch desactivado")
    end
end

function PE:OnAutoSwitchUpdate()
    -- Throttle: solo verificar cada X segundos
    local now = time()
    if now - self.Data.lastAutoSwitch < self.Config.autoSwitchDelay then
        return
    end
    
    self.Data.lastAutoSwitch = now
    
    -- Verificar reglas
    for _, rule in ipairs(self.AutoSwitchRules) do
        if rule.condition() then
            -- Solo cambiar si es diferente al actual
            if self.Data.currentProfile ~= rule.profile then
                self:SwitchProfile(rule.profile)
            end
            return
        end
    end
end

-- Listar perfiles
function PE:ListProfiles()
    local profiles = {}
    for name, profile in pairs(self.Data.profiles) do
        table.insert(profiles, {
            name = name,
            description = profile.description,
            useCount = profile.useCount,
            isCurrent = (name == self.Data.currentProfile),
        })
    end
    
    -- Ordenar por uso
    table.sort(profiles, function(a, b)
        return a.useCount > b.useCount
    end)
    
    return profiles
end

-- Eliminar perfil
function PE:DeleteProfile(name)
    if not self.Data.profiles[name] then
        return false, "Perfil no encontrado"
    end
    
    -- No permitir eliminar presets
    if self.Presets[name] then
        return false, "No se pueden eliminar perfiles predefinidos"
    end
    
    self.Data.profiles[name] = nil
    
    if self.Data.currentProfile == name then
        self.Data.currentProfile = nil
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Log("INFO", "ProfilesEnhanced", "Perfil eliminado: " .. name)
    end
    
    return true
end

-- Obtener perfil actual
function PE:GetCurrentProfile()
    if not self.Data.currentProfile then
        return nil
    end
    return self.Data.profiles[self.Data.currentProfile]
end

-- Contar perfiles
function PE:GetProfileCount()
    local count = 0
    for _ in pairs(self.Data.profiles) do
        count = count + 1
    end
    return count
end

-- Registrar comandos
function PE:RegisterCommands()
    SLASH_BRAINPROFILEENHANCED1 = "/brainprofile"
    SLASH_BRAINPROFILEENHANCED2 = "/bprofile"
    SlashCmdList["BRAINPROFILEENHANCED"] = function(msg)
        PE:HandleCommand(msg)
    end
end

function PE:HandleCommand(msg)
    local args = {}
    for word in string.gfind(msg, "%S+") do
        table.insert(args, word)
    end
    
    local cmd = args[1] or "list"
    
    if cmd == "list" then
        self:ShowProfileList()
    elseif cmd == "switch" or cmd == "use" then
        local name = args[2]
        if not name then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r Uso: /brainprofile switch <nombre>")
            return
        end
        self:SwitchProfile(name)
    elseif cmd == "create" then
        local name = args[2]
        if not name then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r Uso: /brainprofile create <nombre>")
            return
        end
        local success, err = self:CreateProfile(name)
        if success then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Perfil creado: " .. name)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r Error: " .. err)
        end
    elseif cmd == "delete" then
        local name = args[2]
        if not name then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r Uso: /brainprofile delete <nombre>")
            return
        end
        local success, err = self:DeleteProfile(name)
        if success then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Perfil eliminado: " .. name)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Brain]|r Error: " .. err)
        end
    elseif cmd == "auto" then
        self.Data.autoSwitch = not self.Data.autoSwitch
        if self.Data.autoSwitch then
            self:StartAutoSwitch()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Auto-switch activado")
        else
            self:StopAutoSwitch()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Brain]|r Auto-switch desactivado")
        end
    elseif cmd == "current" then
        local current = self:GetCurrentProfile()
        if current then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Perfil actual: |cFFFFFF00" .. current.name .. "|r")
            if current.description and current.description ~= "" then
                DEFAULT_CHAT_FRAME:AddMessage("  " .. current.description)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Brain]|r No hay perfil activo")
        end
    else
        self:ShowHelp()
    end
end

function PE:ShowProfileList()
    local profiles = self:ListProfiles()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== Brain Profiles ===")
    DEFAULT_CHAT_FRAME:AddMessage("Total: " .. table.getn(profiles) .. " perfiles")
    DEFAULT_CHAT_FRAME:AddMessage("")
    
    for i = 1, table.getn(profiles) do
        local p = profiles[i]
        local marker = p.isCurrent and "|cFF00FF00[ACTIVO]|r " or ""
        local preset = self.Presets[p.name] and "|cFF9482C9[PRESET]|r " or ""
        DEFAULT_CHAT_FRAME:AddMessage(marker .. preset .. "|cFFFFFF00" .. p.name .. "|r (usado " .. p.useCount .. " veces)")
        if p.description and p.description ~= "" then
            DEFAULT_CHAT_FRAME:AddMessage("  " .. p.description)
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("")
    DEFAULT_CHAT_FRAME:AddMessage("Auto-switch: " .. (self.Data.autoSwitch and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
end

function PE:ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00=== Brain Profiles - Comandos ===")
    DEFAULT_CHAT_FRAME:AddMessage("/brainprofile list - Listar perfiles")
    DEFAULT_CHAT_FRAME:AddMessage("/brainprofile switch <nombre> - Cambiar perfil")
    DEFAULT_CHAT_FRAME:AddMessage("/brainprofile create <nombre> - Crear perfil")
    DEFAULT_CHAT_FRAME:AddMessage("/brainprofile delete <nombre> - Eliminar perfil")
    DEFAULT_CHAT_FRAME:AddMessage("/brainprofile current - Ver perfil actual")
    DEFAULT_CHAT_FRAME:AddMessage("/brainprofile auto - Toggle auto-switch")
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        PE:Initialize()
    end
end)

