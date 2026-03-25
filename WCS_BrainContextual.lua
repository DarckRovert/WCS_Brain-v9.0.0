--[[
    WCS_BrainContextual.lua - Sistema de Configuración Contextual v6.4.2
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema de pesos dinámicos según contexto:
    - Configuración por situación (solo/group/raid/pvp)
    - Pesos adaptativos según enemigos
    - Perfiles de juego personalizables
    - Detección automática de contexto
]]--

WCS_BrainContextual = WCS_BrainContextual or {}
WCS_BrainContextual.VERSION = "6.4.2"
WCS_BrainContextual.enabled = true

-- ============================================================================
-- CONFIGURACIÓN CONTEXTUAL
-- ============================================================================
WCS_BrainContextual.Contexts = {
    -- Contexto Solo
    solo = {
        name = "Solo",
        description = "Jugando solo, prioriza supervivencia",
        weights = {
            damage = 0.6,      -- 60% peso en daño
            survival = 0.3,    -- 30% peso en supervivencia
            mana = 0.1,        -- 10% peso en eficiencia de mana
            pet = 0.2,         -- 20% peso en uso de mascota
            cc = 0.1,          -- 10% peso en control de multitudes
            utility = 0.1      -- 10% peso en utilidades
        },
        spellPriorities = {
            ["Shadow Bolt"] = 1.0,
            ["Corruption"] = 0.9,
            ["Curse of Agony"] = 0.8,
            ["Life Tap"] = 0.7,
            ["Fear"] = 0.6,
            ["Healthstone"] = 1.2  -- Mayor prioridad en solo
        },
        thresholds = {
            healthCritical = 25,   -- Más conservador
            manaCritical = 20,
            petHealthCritical = 30,
            useLifeTapAt = 50      -- Usar Life Tap antes
        }
    },
    
    -- Contexto Grupo (5 jugadores)
    group = {
        name = "Grupo",
        description = "En grupo de 5, balance entre daño y utilidad",
        weights = {
            damage = 0.7,      -- 70% peso en daño
            survival = 0.2,    -- 20% peso en supervivencia
            mana = 0.15,       -- 15% peso en eficiencia de mana
            pet = 0.15,        -- 15% peso en uso de mascota
            cc = 0.2,          -- 20% peso en control de multitudes
            utility = 0.15     -- 15% peso en utilidades
        },
        spellPriorities = {
            ["Shadow Bolt"] = 1.1,
            ["Corruption"] = 1.0,
            ["Curse of Elements"] = 0.9,  -- Útil para el grupo
            ["Banish"] = 0.8,             -- CC importante
            ["Fear"] = 0.7,
            ["Healthstone"] = 0.8
        },
        thresholds = {
            healthCritical = 20,
            manaCritical = 15,
            petHealthCritical = 25,
            useLifeTapAt = 40
        }
    },
    
    -- Contexto Raid (40 jugadores)
    raid = {
        name = "Raid",
        description = "En raid, maximiza DPS y utilidad de grupo",
        weights = {
            damage = 0.8,      -- 80% peso en daño
            survival = 0.1,    -- 10% peso en supervivencia
            mana = 0.2,        -- 20% peso en eficiencia de mana
            pet = 0.1,         -- 10% peso en uso de mascota
            cc = 0.15,         -- 15% peso en control de multitudes
            utility = 0.2      -- 20% peso en utilidades
        },
        spellPriorities = {
            ["Shadow Bolt"] = 1.2,        -- Máximo DPS
            ["Curse of Elements"] = 1.1,  -- Crítico en raids
            ["Curse of Shadow"] = 1.0,
            ["Corruption"] = 0.9,
            ["Life Tap"] = 0.6,           -- Menos conservador
            ["Healthstone"] = 0.5         -- Healers se encargan
        },
        thresholds = {
            healthCritical = 15,   -- Más agresivo
            manaCritical = 10,
            petHealthCritical = 20,
            useLifeTapAt = 30
        }
    },
    
    -- Contexto PvP
    pvp = {
        name = "PvP",
        description = "Contra jugadores, prioriza burst y control",
        weights = {
            damage = 0.5,      -- 50% peso en daño
            survival = 0.4,    -- 40% peso en supervivencia
            mana = 0.1,        -- 10% peso en eficiencia de mana
            pet = 0.3,         -- 30% peso en uso de mascota
            cc = 0.4,          -- 40% peso en control de multitudes
            utility = 0.2      -- 20% peso en utilidades
        },
        spellPriorities = {
            ["Fear"] = 1.3,              -- Crítico en PvP
            ["Death Coil"] = 1.2,
            ["Curse of Tongues"] = 1.1,  -- Anti-caster
            ["Howl of Terror"] = 1.0,
            ["Shadowburn"] = 0.9,
            ["Corruption"] = 0.8,
            ["Healthstone"] = 1.1
        },
        thresholds = {
            healthCritical = 30,   -- Muy conservador
            manaCritical = 25,
            petHealthCritical = 35,
            useLifeTapAt = 60
        }
    },
    
    -- Contexto Elite/Boss
    elite = {
        name = "Elite/Boss",
        description = "Contra enemigos elite, maximiza DPS sostenido",
        weights = {
            damage = 0.75,     -- 75% peso en daño
            survival = 0.15,   -- 15% peso en supervivencia
            mana = 0.25,       -- 25% peso en eficiencia de mana
            pet = 0.2,         -- 20% peso en uso de mascota
            cc = 0.05,         -- 5% peso en control (inmunes)
            utility = 0.15     -- 15% peso en utilidades
        },
        spellPriorities = {
            ["Curse of Elements"] = 1.2,
            ["Corruption"] = 1.1,
            ["Curse of Agony"] = 1.0,
            ["Shadow Bolt"] = 0.9,
            ["Life Tap"] = 0.8,
            ["Dark Pact"] = 0.7
        },
        thresholds = {
            healthCritical = 20,
            manaCritical = 15,
            petHealthCritical = 25,
            useLifeTapAt = 45
        }
    }
}

-- ============================================================================
-- DETECCIÓN DE CONTEXTO
-- ============================================================================
WCS_BrainContextual.Detection = {
    currentContext = "solo",
    lastUpdate = 0,
    updateInterval = 2.0,  -- Verificar contexto cada 2 segundos
    forceContext = nil     -- Contexto forzado por usuario
}

-- Detectar contexto automáticamente
function WCS_BrainContextual:DetectContext()
    -- Si hay contexto forzado, usarlo
    if self.Detection.forceContext then
        return self.Detection.forceContext
    end
    
    local now = GetTime()
    if now - self.Detection.lastUpdate < self.Detection.updateInterval then
        return self.Detection.currentContext
    end
    
    self.Detection.lastUpdate = now
    
    -- Detectar PvP
    if self:IsPvPContext() then
        self.Detection.currentContext = "pvp"
        return "pvp"
    end
    
    -- Detectar Elite/Boss
    if self:IsEliteContext() then
        self.Detection.currentContext = "elite"
        return "elite"
    end
    
    -- Detectar Raid
    if GetNumRaidMembers() > 0 then
        self.Detection.currentContext = "raid"
        return "raid"
    end
    
    -- Detectar Grupo
    if GetNumPartyMembers() > 0 then
        self.Detection.currentContext = "group"
        return "group"
    end
    
    -- Por defecto: Solo
    self.Detection.currentContext = "solo"
    return "solo"
end

-- Verificar si estamos en contexto PvP
function WCS_BrainContextual:IsPvPContext()
    -- Verificar si el target es un jugador
    if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("player", "target") then
        return true
    end
    
    -- Verificar si estamos en zona PvP
    local pvpType = GetZonePVPInfo()
    if pvpType == "combat" or pvpType == "arena" or pvpType == "contested" then
        return true
    end
    
    -- Verificar si hay jugadores enemigos cerca
    if self:HasEnemyPlayersNearby() then
        return true
    end
    
    return false
end

-- Verificar si estamos contra elite/boss
function WCS_BrainContextual:IsEliteContext()
    if not UnitExists("target") then return false end
    
    -- Verificar si es elite
    local classification = UnitClassification("target")
    if classification == "elite" or classification == "worldboss" or classification == "rareelite" then
        return true
    end
    
    -- Verificar si es un boss conocido (nivel muy alto)
    local targetLevel = UnitLevel("target")
    local playerLevel = UnitLevel("player")
    if targetLevel == -1 or (targetLevel > playerLevel + 5) then
        return true
    end
    
    return false
end

-- Verificar si hay jugadores enemigos cerca
function WCS_BrainContextual:HasEnemyPlayersNearby()
    -- Esta función requeriría scanning de unidades cercanas
    -- Por simplicidad, retornamos false por ahora
    return false
end

-- ============================================================================
-- APLICACIÓN DE CONTEXTO
-- ============================================================================

-- Obtener configuración actual
function WCS_BrainContextual:GetCurrentConfig()
    local context = self:DetectContext()
    return self.Contexts[context] or self.Contexts.solo
end

-- Obtener pesos actuales
function WCS_BrainContextual:GetCurrentWeights()
    local config = self:GetCurrentConfig()
    return config.weights
end

-- Obtener prioridades de hechizos actuales
function WCS_BrainContextual:GetCurrentSpellPriorities()
    local config = self:GetCurrentConfig()
    return config.spellPriorities
end

-- Obtener umbrales actuales
function WCS_BrainContextual:GetCurrentThresholds()
    local config = self:GetCurrentConfig()
    return config.thresholds
end

-- Aplicar modificador contextual a score de hechizo
function WCS_BrainContextual:ApplyContextualModifier(spell, baseScore, category)
    local weights = self:GetCurrentWeights()
    local priorities = self:GetCurrentSpellPriorities()
    
    -- Aplicar peso por categoría
    local categoryWeight = weights[category] or 1.0
    
    -- Aplicar prioridad específica del hechizo
    local spellPriority = priorities[spell] or 1.0
    
    -- Calcular score final
    local finalScore = baseScore * categoryWeight * spellPriority
    
    return finalScore
end

-- ============================================================================
-- PERFILES PERSONALIZADOS
-- ============================================================================
WCS_BrainContextual.CustomProfiles = {}

-- Crear perfil personalizado
function WCS_BrainContextual:CreateCustomProfile(name, baseContext, modifications)
    if not name or not baseContext or not self.Contexts[baseContext] then
        self:Log("Error: Parámetros inválidos para crear perfil")
        return false
    end
    
    -- Copiar configuración base
    local profile = self:DeepCopy(self.Contexts[baseContext])
    profile.name = name
    profile.description = "Perfil personalizado basado en " .. baseContext
    profile.isCustom = true
    
    -- Aplicar modificaciones
    if modifications.weights then
        for key, value in modifications.weights do
            profile.weights[key] = value
        end
    end
    
    if modifications.spellPriorities then
        for spell, priority in modifications.spellPriorities do
            profile.spellPriorities[spell] = priority
        end
    end
    
    if modifications.thresholds then
        for key, value in modifications.thresholds do
            profile.thresholds[key] = value
        end
    end
    
    -- Guardar perfil
    self.CustomProfiles[name] = profile
    self:Log("Perfil personalizado '" .. name .. "' creado exitosamente")
    
    return true
end

-- Cargar perfil personalizado
function WCS_BrainContextual:LoadCustomProfile(name)
    if not self.CustomProfiles[name] then
        self:Log("Error: Perfil '" .. name .. "' no encontrado")
        return false
    end
    
    self.Detection.forceContext = name
    self:Log("Perfil '" .. name .. "' cargado")
    return true
end

-- ============================================================================
-- COMANDOS
-- ============================================================================
function WCS_BrainContextual:RegisterCommands()
    SLASH_WCSCONTEXT1 = "/wcscontext"
    SlashCmdList["WCSCONTEXT"] = function(msg)
        local args = {}
        for word in string.gfind(msg, "%S+") do
            table.insert(args, string.lower(word))
        end
        
        if not args[1] or args[1] == "help" then
            self:ShowHelp()
        elseif args[1] == "status" then
            self:ShowStatus()
        elseif args[1] == "set" and args[2] then
            self:SetContext(args[2])
        elseif args[1] == "auto" then
            self:SetAutoContext()
        elseif args[1] == "weights" then
            self:ShowWeights()
        elseif args[1] == "priorities" then
            self:ShowPriorities()
        elseif args[1] == "thresholds" then
            self:ShowThresholds()
        elseif args[1] == "profiles" then
            self:ShowProfiles()
        elseif args[1] == "create" and args[2] and args[3] then
            self:CreateProfileCommand(args[2], args[3])
        elseif args[1] == "load" and args[2] then
            self:LoadCustomProfile(args[2])
        else
            self:Log("Comando desconocido. Usa /wcscontext help")
        end
    end
end

function WCS_BrainContextual:ShowHelp()
    self:Log("=== COMANDOS DE CONTEXTO ===")
    self:Log("/wcscontext status - Ver contexto actual")
    self:Log("/wcscontext set <contexto> - Forzar contexto")
    self:Log("/wcscontext auto - Detección automática")
    self:Log("/wcscontext weights - Ver pesos actuales")
    self:Log("/wcscontext priorities - Ver prioridades de hechizos")
    self:Log("/wcscontext thresholds - Ver umbrales actuales")
    self:Log("/wcscontext profiles - Ver perfiles disponibles")
    self:Log("/wcscontext create <nombre> <base> - Crear perfil personalizado")
    self:Log("/wcscontext load <nombre> - Cargar perfil personalizado")
    self:Log("Contextos: solo, group, raid, pvp, elite")
end

function WCS_BrainContextual:ShowStatus()
    local currentContext = self:DetectContext()
    local config = self:GetCurrentConfig()
    
    self:Log("=== ESTADO DEL CONTEXTO ===")
    self:Log("Contexto Actual: " .. config.name)
    self:Log("Descripción: " .. config.description)
    self:Log("Detección: " .. (self.Detection.forceContext and "Manual" or "Automática"))
    
    if GetNumRaidMembers() > 0 then
        self:Log("En Raid: " .. GetNumRaidMembers() .. " miembros")
    elseif GetNumPartyMembers() > 0 then
        self:Log("En Grupo: " .. (GetNumPartyMembers() + 1) .. " miembros")
    else
        self:Log("Jugando Solo")
    end
end

function WCS_BrainContextual:ShowWeights()
    local weights = self:GetCurrentWeights()
    local context = self:DetectContext()
    
    self:Log("=== PESOS ACTUALES (" .. string.upper(context) .. ") ===")
    for category, weight in weights do
        self:Log(category .. ": " .. string.format("%.1f%%", weight * 100))
    end
end

function WCS_BrainContextual:ShowPriorities()
    local priorities = self:GetCurrentSpellPriorities()
    local context = self:DetectContext()
    
    self:Log("=== PRIORIDADES DE HECHIZOS (" .. string.upper(context) .. ") ===")
    
    -- Ordenar por prioridad
    local sortedSpells = {}
    for spell, priority in priorities do
        table.insert(sortedSpells, {spell = spell, priority = priority})
    end
    
    table.sort(sortedSpells, function(a, b) return a.priority > b.priority end)
    
    for _, data in sortedSpells do
        self:Log(data.spell .. ": " .. string.format("%.1f", data.priority))
    end
end

function WCS_BrainContextual:SetContext(context)
    if not self.Contexts[context] and not self.CustomProfiles[context] then
        self:Log("Error: Contexto '" .. context .. "' no válido")
        return
    end
    
    self.Detection.forceContext = context
    self:Log("Contexto forzado a: " .. context)
end

function WCS_BrainContextual:SetAutoContext()
    self.Detection.forceContext = nil
    self:Log("Detección automática de contexto activada")
end

-- ============================================================================
-- UTILIDADES
-- ============================================================================
function WCS_BrainContextual:DeepCopy(original)
    local copy = {}
    for key, value in original do
        if type(value) == "table" then
            copy[key] = self:DeepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function WCS_BrainContextual:Log(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Context]|r " .. message)
end

-- ============================================================================
-- INTEGRACIÓN CON WCS_BRAIN
-- ============================================================================

-- Hook para modificar scores de WCS_BrainAI
function WCS_BrainContextual:HookBrainAI()
    if not WCS_BrainAI then return end
    
    -- Guardar función original
    if not self.originalCalculateSpellScore then
        self.originalCalculateSpellScore = WCS_BrainAI.CalculateSpellScore
    end
    
    -- Override con modificador contextual
    WCS_BrainAI.CalculateSpellScore = function(self, spell, category)
        local baseScore = WCS_BrainContextual.originalCalculateSpellScore(self, spell, category)
        return WCS_BrainContextual:ApplyContextualModifier(spell, baseScore, category)
    end
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainContextual:Initialize()
    self:RegisterCommands()
    
    -- Cargar perfiles personalizados guardados
    if WCS_BrainSaved and WCS_BrainSaved.CustomProfiles then
        self.CustomProfiles = WCS_BrainSaved.CustomProfiles
    end
    
    -- Hook WCS_BrainAI si está disponible
    self:HookBrainAI()
    
    self:Log("Sistema Contextual v" .. self.VERSION .. " inicializado")
    self:Log("Contexto inicial: " .. self:DetectContext())
end

-- Auto-inicialización
if WCS_BrainCore and WCS_BrainCore.RegisterModule then
    WCS_BrainCore:RegisterModule("Contextual", WCS_BrainContextual)
end

-- Inicialización manual
local function InitializeContextual()
    if WCS_BrainContextual then
        WCS_BrainContextual:Initialize()
    end
end

-- Registrar eventos
if not WCS_BrainContextual.initialized then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    frame:SetScript("OnEvent", function()
        if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
            InitializeContextual()
            WCS_BrainContextual.initialized = true
        elseif WCS_BrainContextual.initialized then
            -- Forzar actualización de contexto en cambios relevantes
            WCS_BrainContextual.Detection.lastUpdate = 0
        end
    end)
end
