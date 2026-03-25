--[[
    WCS_BrainActions.lua - Definicion de Acciones del DQN
    Compatible con Lua 5.0 (Turtle WoW)
    Version: 6.4.2
    
    Total: 30 acciones (29 hechizos + WAIT)
    NO incluye acciones de mascota (manejadas por WCS_BrainPetAI)
]]--

WCS_BrainActions = WCS_BrainActions or {}
WCS_BrainActions.VERSION = "6.4.2"
WCS_BrainActions.ACTION_SIZE = 30

-- Mapeo de acciones (indice -> nombre)
WCS_BrainActions.ActionMap = {
    [1] = "Shadow Bolt",
    [2] = "Corruption",
    [3] = "Curse of Agony",
    [4] = "Immolate",
    [5] = "Siphon Life",
    [6] = "Drain Life",
    [7] = "Drain Soul",
    [8] = "Searing Pain",
    [9] = "Soul Fire",
    [10] = "Shadowburn",
    [11] = "Conflagrate",
    [12] = "Rain of Fire",
    [13] = "Hellfire",
    [14] = "Fear",
    [15] = "Howl of Terror",
    [16] = "Death Coil",
    [17] = "Banish",
    [18] = "Curse of Tongues",
    [19] = "Curse of Weakness",
    [20] = "Curse of the Elements",
    [21] = "Curse of Shadow",
    [22] = "Curse of Doom",
    [23] = "Curse of Exhaustion",
    [24] = "Curse of Recklessness",
    [25] = "Life Tap",
    [26] = "Dark Pact",
    [27] = "Drain Mana",
    [28] = "Health Funnel",
    [29] = "Healthstone",
    [30] = nil
}

-- Mapeo inverso (nombre -> indice)
WCS_BrainActions.SpellToAction = {
    ["Shadow Bolt"] = 1,
    ["Corruption"] = 2,
    ["Curse of Agony"] = 3,
    ["Immolate"] = 4,
    ["Siphon Life"] = 5,
    ["Drain Life"] = 6,
    ["Drain Soul"] = 7,
    ["Searing Pain"] = 8,
    ["Soul Fire"] = 9,
    ["Shadowburn"] = 10,
    ["Conflagrate"] = 11,
    ["Rain of Fire"] = 12,
    ["Hellfire"] = 13,
    ["Fear"] = 14,
    ["Howl of Terror"] = 15,
    ["Death Coil"] = 16,
    ["Banish"] = 17,
    ["Curse of Tongues"] = 18,
    ["Curse of Weakness"] = 19,
    ["Curse of the Elements"] = 20,
    ["Curse of Shadow"] = 21,
    ["Curse of Doom"] = 22,
    ["Curse of Exhaustion"] = 23,
    ["Curse of Recklessness"] = 24,
    ["Life Tap"] = 25,
    ["Dark Pact"] = 26,
    ["Drain Mana"] = 27,
    ["Health Funnel"] = 28,
    ["Healthstone"] = 29,
    ["Minor Healthstone"] = 29,
    ["Lesser Healthstone"] = 29,
    ["Greater Healthstone"] = 29,
    ["Major Healthstone"] = 29
}

-- Nombres cortos para UI
WCS_BrainActions.ShortNames = {
    [1] = "SBolt", [2] = "Corr", [3] = "CoA", [4] = "Immo", [5] = "Siph",
    [6] = "DLife", [7] = "DSoul", [8] = "SPain", [9] = "SFire", [10] = "SBurn",
    [11] = "Confl", [12] = "RoF", [13] = "Hell", [14] = "Fear", [15] = "Howl",
    [16] = "DCoil", [17] = "Ban", [18] = "CoT", [19] = "CoW", [20] = "CoE",
    [21] = "CoS", [22] = "CoDm", [23] = "CoEx", [24] = "CoR", [25] = "LTap",
    [26] = "DPact", [27] = "DMana", [28] = "HFun", [29] = "Stone", [30] = "WAIT"
}

function WCS_BrainActions:GetSpellName(idx)
    return self.ActionMap[idx]
end

function WCS_BrainActions:GetActionIndex(spell)
    return self.SpellToAction[spell]
end

function WCS_BrainActions:GetShortName(idx)
    return self.ShortNames[idx] or "?"
end

function WCS_BrainActions:Initialize()
    if WCS_BrainDQN and WCS_BrainDQN.Config then
        WCS_BrainDQN.Config.actionSize = self.ACTION_SIZE
    end
    if WCS_BrainIntegration then
        WCS_BrainIntegration.ActionMap = self.ActionMap
        WCS_BrainIntegration.ActionNameToIndex = self.SpellToAction
    end
    if WCS_BrainAutoCapture then
        WCS_BrainAutoCapture.SpellToAction = self.SpellToAction
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        delayFrame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed > 1.5 then
                WCS_BrainActions:Initialize()
                delayFrame:SetScript("OnUpdate", nil)
            end
        end)
    end
end)
