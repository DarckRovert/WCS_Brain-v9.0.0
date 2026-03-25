--[[
    WCS_BrainAchievements.lua - Sistema de Logros v6.5.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Gamificación del aprendizaje del Brain
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainAchievements = WCS_BrainAchievements or {}
WCS_BrainAchievements.VERSION = "6.5.0"

-- ============================================================================
-- DEFINICIÓN DE LOGROS
-- ============================================================================
WCS_BrainAchievements.Achievements = {
    ["first_blood"] = {
        name = "First Blood",
        desc = "Primera kill con el Brain",
        icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
        unlocked = false,
        progress = 0,
        required = 1
    },
    ["efficient_killer"] = {
        name = "Efficient Killer",
        desc = "100 kills con >80% eficiencia",
        icon = "Interface\\Icons\\Spell_Shadow_Corruption",
        unlocked = false,
        progress = 0,
        required = 100
    },
    ["pet_master"] = {
        name = "Pet Master",
        desc = "Usa las 4 mascotas en combate",
        icon = "Interface\\Icons\\Spell_Shadow_SummonImp",
        unlocked = false,
        progress = 0,
        required = 4,
        petsUsed = {}
    },
    ["speed_demon"] = {
        name = "Speed Demon",
        desc = "Kill en <10s",
        icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
        unlocked = false,
        progress = 0,
        required = 1
    },
    ["survivor"] = {
        name = "Survivor",
        desc = "Sobrevive con <5% HP",
        icon = "Interface\\Icons\\Spell_Shadow_LifeDrain",
        unlocked = false,
        progress = 0,
        required = 1
    },
    ["mana_master"] = {
        name = "Mana Master",
        desc = "Completa combate sin quedarte sin mana",
        icon = "Interface\\Icons\\Spell_Shadow_DarkRitual",
        unlocked = false,
        progress = 0,
        required = 50
    },
    ["brain_trust"] = {
        name = "Brain Trust",
        desc = "Sigue 100 sugerencias del Brain",
        icon = "Interface\\Icons\\Spell_Shadow_Charm",
        unlocked = false,
        progress = 0,
        required = 100
    },
    ["learning_machine"] = {
        name = "Learning Machine",
        desc = "1000 combates registrados",
        icon = "Interface\\Icons\\Spell_Shadow_Possession",
        unlocked = false,
        progress = 0,
        required = 1000
    },
    ["warlock_master"] = {
        name = "Warlock Master",
        desc = "Desbloquea todos los logros",
        icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
        unlocked = false,
        progress = 0,
        required = 10
    },
    ["top_dps"] = {
        name = "Top DPS",
        desc = "Estar #1 en TerrorMeter (grupo 5+)",
        icon = "Interface\\Icons\\Spell_Fire_Fireball",
        unlocked = false,
        progress = 0,
        required = 1
    },
    ["dps_master"] = {
        name = "DPS Master",
        desc = "Superar 500 DPS",
        icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
        unlocked = false,
        progress = 0,
        required = 1
    },
    ["consistent_dps"] = {
        name = "Consistent DPS",
        desc = "Mantener top 3 por 10 combates",
        icon = "Interface\\Icons\\Spell_Shadow_Shadowform",
        unlocked = false,
        progress = 0,
        required = 10
    }
}

-- ============================================================================
-- INTEGRACIÓN CON WCS_BrainMetrics
-- ============================================================================

-- Sincronizar progreso con WCS_BrainMetrics (sistema existente)
function WCS_BrainAchievements:SyncWithMetrics()
    if not WCS_BrainMetrics or not WCS_BrainMetrics.Data then
        return
    end
    
    local data = WCS_BrainMetrics.Data
    
    -- Learning Machine - Total de combates
    local totalCombats = (data.combatsWon or 0) + (data.combatsLost or 0)
    if totalCombats > 0 then
        self:SetProgress("learning_machine", totalCombats)
    end
    
    -- Efficient Killer - Basado en win rate
    if data.combatsWon and data.combatsWon > 0 then
        local winRate = data.combatsWon / totalCombats
        if winRate > 0.8 then
            self:SetProgress("efficient_killer", data.combatsWon)
        end
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Debug("Achievements", "Sincronizado con WCS_BrainMetrics")
    end
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainAchievements:Initialize()
    -- Cargar desde SavedVariables
    if WCS_BrainSaved and WCS_BrainSaved.achievements then
        for id, data in pairs(WCS_BrainSaved.achievements) do
            if self.Achievements[id] then
                self.Achievements[id].unlocked = data.unlocked
                self.Achievements[id].progress = data.progress
                if data.petsUsed then
                    self.Achievements[id].petsUsed = data.petsUsed
                end
            end
        end
    end
    
    -- Registrar eventos
    self:RegisterEvents()
    
    -- Sincronizar con WCS_BrainMetrics al iniciar
    self:SyncWithMetrics()
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Achievements", "Sistema de logros inicializado")
    end
end

-- ============================================================================
-- EVENTOS
-- ============================================================================
function WCS_BrainAchievements:RegisterEvents()
    if not self.frame then
        self.frame = CreateFrame("Frame")
    end
    
    self.frame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Inicio de combate
    
    local function OnEvent()
        if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
            WCS_BrainAchievements:OnMobDeath()
        elseif event == "PLAYER_REGEN_ENABLED" then
            WCS_BrainAchievements:OnCombatEnd()
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Guardar tiempo de inicio de combate para Speed Demon
            WCS_BrainAchievements.combatStartTime = GetTime()
        end
    end
    
    self.frame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- TRACKING DE PROGRESO
-- ============================================================================
function WCS_BrainAchievements:OnMobDeath()
    -- First Blood
    self:UpdateProgress("first_blood", 1)
    
    -- Learning Machine (usar WCS_BrainMetrics - sistema existente)
    if WCS_BrainMetrics and WCS_BrainMetrics.Data then
        local combatsWon = WCS_BrainMetrics.Data.combatsWon or 0
        local combatsLost = WCS_BrainMetrics.Data.combatsLost or 0
        local totalCombats = combatsWon + combatsLost
        self:SetProgress("learning_machine", totalCombats)
        
        -- CORRECCION 1: Efficient Killer - Verificar en tiempo real
        if combatsWon > 0 and totalCombats > 0 then
            local winRate = combatsWon / totalCombats
            if winRate > 0.8 then
                self:SetProgress("efficient_killer", combatsWon)
            end
        end
    end
    
    -- CORRECCION 3: Pet Master - Verificar mascota activa
    if UnitExists("pet") then
        local petName = UnitCreatureFamily("pet") or UnitName("pet")
        if petName then
            self:CheckPetMaster(petName)
        end
    end
end

function WCS_BrainAchievements:OnCombatEnd()
    -- Verificar Survivor
    local healthPct = (UnitHealth("player") / UnitHealthMax("player")) * 100
    if healthPct < 5 and healthPct > 0 then
        self:UpdateProgress("survivor", 1)
    end
    
    -- Verificar Mana Master
    local manaPct = (UnitMana("player") / UnitManaMax("player")) * 100
    if manaPct > 10 then
        self:UpdateProgress("mana_master", 1)
    end
    
    -- CORRECCION 2: Speed Demon - Verificar duracion del combate
    if self.combatStartTime then
        local duration = GetTime() - self.combatStartTime
        self:CheckSpeedDemon(duration)
        self.combatStartTime = nil
    end
end

function WCS_BrainAchievements:CheckSpeedDemon(duration)
    if duration < 10 then
        self:UpdateProgress("speed_demon", 1)
    end
end

function WCS_BrainAchievements:CheckPetMaster(petType)
    local achievement = self.Achievements["pet_master"]
    if not achievement.petsUsed then
        achievement.petsUsed = {}
    end
    
    if not achievement.petsUsed[petType] then
        achievement.petsUsed[petType] = true
        local count = 0
        for _ in pairs(achievement.petsUsed) do
            count = count + 1
        end
        self:SetProgress("pet_master", count)
    end
end

-- ============================================================================
-- GESTIÓN DE PROGRESO
-- ============================================================================
function WCS_BrainAchievements:UpdateProgress(id, amount)
    local achievement = self.Achievements[id]
    if not achievement or achievement.unlocked then return end
    
    achievement.progress = achievement.progress + amount
    
    if achievement.progress >= achievement.required then
        self:Unlock(id)
    end
end

function WCS_BrainAchievements:SetProgress(id, value)
    local achievement = self.Achievements[id]
    if not achievement or achievement.unlocked then return end
    
    achievement.progress = value
    
    if achievement.progress >= achievement.required then
        self:Unlock(id)
    end
end

function WCS_BrainAchievements:Unlock(id)
    local achievement = self.Achievements[id]
    if not achievement or achievement.unlocked then return end
    
    achievement.unlocked = true
    
    -- Notificar al jugador
    self:ShowUnlockNotification(achievement)
    
    -- Guardar
    self:Save()
    
    -- Verificar Warlock Master
    self:CheckWarlockMaster()
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Achievements", "Logro desbloqueado: " .. achievement.name)
    end
end

function WCS_BrainAchievements:CheckWarlockMaster()
    local unlockedCount = 0
    for id, achievement in pairs(self.Achievements) do
        if id ~= "warlock_master" and achievement.unlocked then
            unlockedCount = unlockedCount + 1
        end
    end
    
    self:SetProgress("warlock_master", unlockedCount)
end

-- ============================================================================
-- NOTIFICACIONES
-- ============================================================================
function WCS_BrainAchievements:ShowUnlockNotification(achievement)
    -- Mensaje en chat
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700========================================|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700¡LOGRO DESBLOQUEADO!|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00" .. achievement.name .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFF" .. achievement.desc .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700========================================|r")
    
    -- Sonido (si está disponible)
    PlaySound("LevelUp")
end

-- ============================================================================
-- CONSULTAS
-- ============================================================================
function WCS_BrainAchievements:GetAchievement(id)
    return self.Achievements[id]
end

function WCS_BrainAchievements:GetAllAchievements()
    local achievements = {}
    for id, achievement in pairs(self.Achievements) do
        table.insert(achievements, {
            id = id,
            data = achievement
        })
    end
    return achievements
end

function WCS_BrainAchievements:GetUnlockedCount()
    local count = 0
    for _, achievement in pairs(self.Achievements) do
        if achievement.unlocked then
            count = count + 1
        end
    end
    return count
end

function WCS_BrainAchievements:GetTotalCount()
    local count = 0
    for _ in pairs(self.Achievements) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- GUARDADO
-- ============================================================================
function WCS_BrainAchievements:Save()
    if not WCS_BrainSaved then
        WCS_BrainSaved = {}
    end
    
    WCS_BrainSaved.achievements = {}
    for id, achievement in pairs(self.Achievements) do
        WCS_BrainSaved.achievements[id] = {
            unlocked = achievement.unlocked,
            progress = achievement.progress,
            petsUsed = achievement.petsUsed
        }
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSACHIEVEMENTS1 = "/wcsachievements"
SLASH_WCSACHIEVEMENTS2 = "/brainachievements"

SlashCmdList["WCSACHIEVEMENTS"] = function(msg)
    if msg == "" or msg == "list" then
        local unlocked = WCS_BrainAchievements:GetUnlockedCount()
        local total = WCS_BrainAchievements:GetTotalCount()
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Achievements]|r Logros (" .. unlocked .. "/" .. total .. "):")
        
        for id, achievement in pairs(WCS_BrainAchievements.Achievements) do
            local status = achievement.unlocked and "|cFF00FF00✓|r" or "|cFFFF0000✗|r"
            local progress = ""
            if not achievement.unlocked and achievement.required > 1 then
                progress = " (" .. achievement.progress .. "/" .. achievement.required .. ")"
            end
            DEFAULT_CHAT_FRAME:AddMessage("  " .. status .. " " .. achievement.name .. progress)
            DEFAULT_CHAT_FRAME:AddMessage("     " .. achievement.desc)
        end
        
    elseif msg == "reset" then
        for _, achievement in pairs(WCS_BrainAchievements.Achievements) do
            achievement.unlocked = false
            achievement.progress = 0
            if achievement.petsUsed then
                achievement.petsUsed = {}
            end
        end
        WCS_BrainAchievements:Save()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Achievements]|r Logros reseteados")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Achievements]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainachievements list|r - Listar logros")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainachievements reset|r - Resetear logros")
    end
end

-- Auto-inicialización
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainAchievements:Initialize()
    elseif event == "PLAYER_LOGOUT" then
        WCS_BrainAchievements:Save()
    end
end)

