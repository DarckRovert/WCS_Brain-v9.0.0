--[[
    WCS_BrainPvP.lua - Modo PvP Inteligente v6.6.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Detección y adaptación automática a PvP
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainPvP = WCS_BrainPvP or {}
WCS_BrainPvP.VERSION = "6.6.0"
WCS_BrainPvP.enabled = false
WCS_BrainPvP.inPvP = false

-- ============================================================================
-- ESTRATEGIAS POR CLASE
-- ============================================================================
WCS_BrainPvP.Strategies = {
    ["Warrior"] = {
        priority = {"Fear", "Curse of Exhaustion", "Corruption", "Drain Life"},
        notes = "Kite, usa Fear cuando cargue",
        petRecommended = "Succubus"
    },
    ["Mage"] = {
        priority = {"Felhunter", "Spell Lock", "Curse of Tongues", "Shadow Bolt"},
        notes = "Interrumpe Polymorph, usa Felhunter",
        petRecommended = "Felhunter"
    },
    ["Rogue"] = {
        priority = {"Perception", "Voidwalker", "Corruption", "Curse of Agony"},
        notes = "Usa Voidwalker como tanque, DoTs",
        petRecommended = "Voidwalker"
    },
    ["Priest"] = {
        priority = {"Felhunter", "Devour Magic", "Curse of Tongues", "Shadow Bolt"},
        notes = "Devour Magic para shields, interrumpe heals",
        petRecommended = "Felhunter"
    },
    ["Paladin"] = {
        priority = {"Curse of Tongues", "Corruption", "Drain Life", "Fear"},
        notes = "Presión constante, interrumpe heals",
        petRecommended = "Succubus"
    },
    ["Hunter"] = {
        priority = {"Curse of Exhaustion", "Fear", "Corruption", "Drain Life"},
        notes = "Kite, controla la mascota",
        petRecommended = "Succubus"
    },
    ["Druid"] = {
        priority = {"Curse of Tongues", "Corruption", "Shadow Bolt", "Fear"},
        notes = "Presión en forma caster, kite en forma feral",
        petRecommended = "Felhunter"
    },
    ["Shaman"] = {
        priority = {"Felhunter", "Devour Magic", "Curse of Tongues", "Shadow Bolt"},
        notes = "Purga totems, interrumpe heals",
        petRecommended = "Felhunter"
    },
    ["Warlock"] = {
        priority = {"Felhunter", "Curse of Tongues", "Shadow Bolt", "Fear"},
        notes = "Mirror match, controla mascota enemiga",
        petRecommended = "Felhunter"
    }
}

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainPvP:Initialize()
    self:RegisterEvents()
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("PvP", "Modo PvP inicializado")
    end
end

-- ============================================================================
-- EVENTOS
-- ============================================================================
function WCS_BrainPvP:RegisterEvents()
    if not self.frame then
        self.frame = CreateFrame("Frame")
    end
    
    self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    
    local function OnEvent()
        if event == "PLAYER_TARGET_CHANGED" then
            WCS_BrainPvP:OnTargetChanged()
        elseif event == "PLAYER_REGEN_DISABLED" then
            WCS_BrainPvP:OnEnterCombat()
        end
    end
    
    self.frame:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- DETECCIÓN DE PVP
-- ============================================================================
function WCS_BrainPvP:OnTargetChanged()
    if not self.enabled then return end
    
    if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("player", "target") then
        self.inPvP = true
        self:OnPvPDetected()
    else
        self.inPvP = false
    end
end

function WCS_BrainPvP:OnEnterCombat()
    if not self.enabled then return end
    
    if UnitExists("target") and UnitIsPlayer("target") then
        self.inPvP = true
        self:OnPvPDetected()
    end
end

function WCS_BrainPvP:OnPvPDetected()
    local targetClass = UnitClass("target")
    
    if targetClass and self.Strategies[targetClass] then
        local strategy = self.Strategies[targetClass]
        
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("PvP", "Detectado: " .. targetClass .. " - " .. strategy.notes)
        end
        
        -- Notificar al usuario
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[PvP]|r " .. targetClass .. " detectado!")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Estrategia:|r " .. strategy.notes)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Mascota recomendada:|r " .. strategy.petRecommended)
    end
end

-- ============================================================================
-- OBTENER ESTRATEGIA
-- ============================================================================
function WCS_BrainPvP:GetStrategy(targetClass)
    if targetClass then
        return self.Strategies[targetClass]
    end
    
    if UnitExists("target") then
        local class = UnitClass("target")
        return self.Strategies[class]
    end
    
    return nil
end

function WCS_BrainPvP:GetPriority()
    local strategy = self:GetStrategy()
    if strategy then
        return strategy.priority
    end
    return nil
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSPVP1 = "/wcspvp"
SLASH_WCSPVP2 = "/brainpvp"

SlashCmdList["WCSPVP"] = function(msg)
    if msg == "on" then
        WCS_BrainPvP.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS PvP]|r Modo PvP activado")
        
    elseif msg == "off" then
        WCS_BrainPvP.enabled = false
        WCS_BrainPvP.inPvP = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS PvP]|r Modo PvP desactivado")
        
    elseif msg == "status" then
        local status = WCS_BrainPvP.enabled and "Activado" or "Desactivado"
        local inPvP = WCS_BrainPvP.inPvP and "Sí" or "No"
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS PvP]|r Estado: " .. status)
        DEFAULT_CHAT_FRAME:AddMessage("  En PvP: " .. inPvP)
        
        if WCS_BrainPvP.inPvP and UnitExists("target") then
            local class = UnitClass("target")
            local strategy = WCS_BrainPvP:GetStrategy(class)
            if strategy then
                DEFAULT_CHAT_FRAME:AddMessage("  Objetivo: " .. class)
                DEFAULT_CHAT_FRAME:AddMessage("  Estrategia: " .. strategy.notes)
            end
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS PvP]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainpvp on|r - Activar modo PvP")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainpvp off|r - Desactivar modo PvP")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainpvp status|r - Ver estado")
    end
end

-- Auto-inicialización
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainPvP:Initialize()
    end
end)
