--[[
    WCS_BrainAutoCapture.lua - Captura Automatica de Transiciones
    Compatible con Lua 5.0 (Turtle WoW)
    Version: 6.4.2 - Sin spam de mensajes
]]--

WCS_BrainAutoCapture = WCS_BrainAutoCapture or {}
WCS_BrainAutoCapture.VERSION = "6.4.2"

WCS_BrainAutoCapture.Enabled = false
WCS_BrainAutoCapture.CaptureFrame = nil
WCS_BrainAutoCapture.LastCaptureTime = 0
WCS_BrainAutoCapture.CaptureInterval = 0.5
WCS_BrainAutoCapture.PreviousState = nil
WCS_BrainAutoCapture.CurrentAction = nil
WCS_BrainAutoCapture.LastDetectedAction = 30
WCS_BrainAutoCapture.TransitionsThisCombat = 0

-- Mapeo por defecto (sera actualizado por WCS_BrainActions)
WCS_BrainAutoCapture.SpellToAction = {
    ["Shadow Bolt"] = 1, ["Corruption"] = 2, ["Curse of Agony"] = 3,
    ["Immolate"] = 4, ["Siphon Life"] = 5, ["Drain Life"] = 6,
    ["Drain Soul"] = 7, ["Searing Pain"] = 8, ["Soul Fire"] = 9,
    ["Shadowburn"] = 10, ["Conflagrate"] = 11, ["Rain of Fire"] = 12,
    ["Hellfire"] = 13, ["Fear"] = 14, ["Howl of Terror"] = 15,
    ["Death Coil"] = 16, ["Banish"] = 17, ["Curse of Tongues"] = 18,
    ["Curse of Weakness"] = 19, ["Curse of the Elements"] = 20,
    ["Curse of Shadow"] = 21, ["Curse of Doom"] = 22,
    ["Curse of Exhaustion"] = 23, ["Curse of Recklessness"] = 24,
    ["Life Tap"] = 25, ["Dark Pact"] = 26, ["Drain Mana"] = 27,
    ["Health Funnel"] = 28, ["Healthstone"] = 29
}

function WCS_BrainAutoCapture:DetectAction()
    if CastingBarFrame and CastingBarFrame:IsVisible() then
        local spellName = CastingBarFrame.spellName
        if spellName and self.SpellToAction[spellName] then
            self.LastDetectedAction = self.SpellToAction[spellName]
            return self.LastDetectedAction
        end
    end
    if ChannelBarFrame and ChannelBarFrame:IsVisible() then
        local spellName = ChannelBarFrame.spellName
        if spellName and self.SpellToAction[spellName] then
            self.LastDetectedAction = self.SpellToAction[spellName]
            return self.LastDetectedAction
        end
    end
    return self.LastDetectedAction or 30
end

function WCS_BrainAutoCapture:CaptureTransition()
    if not WCS_BrainDQN or not WCS_BrainDQN.enabled then return end
    if not UnitAffectingCombat("player") then return end
    if not WCS_BrainState then return end
    
    local currentState = WCS_BrainState:CaptureState()
    if not currentState then return end
    
    local detectedAction = self:DetectAction()
    
    if self.PreviousState and self.CurrentAction then
        local reward = 0
        if WCS_BrainReward and WCS_BrainReward.CalculateImmediateReward then
            reward = WCS_BrainReward:CalculateImmediateReward(self.CurrentAction, self.PreviousState, currentState)
        end
        
        if WCS_BrainDQN.ReplayBuffer and WCS_BrainDQN.ReplayBuffer.Add then
            WCS_BrainDQN.ReplayBuffer:Add(self.PreviousState, self.CurrentAction, reward, currentState, false)
            self.TransitionsThisCombat = self.TransitionsThisCombat + 1
        end
    end
    
    self.PreviousState = currentState
    self.CurrentAction = detectedAction
end

function WCS_BrainAutoCapture:Start()
    if not WCS_BrainDQN or not WCS_BrainDQN.enabled then return end
    
    self.Enabled = true
    self.TransitionsThisCombat = 0
    self.LastCaptureTime = GetTime()
    self.PreviousState = nil
    self.CurrentAction = nil
    self.LastDetectedAction = 30
    
    if WCS_BrainState then
        self.PreviousState = WCS_BrainState:CaptureState()
    end
    self.CurrentAction = self:DetectAction()
    
    if not self.CaptureFrame then
        self.CaptureFrame = CreateFrame("Frame", "WCS_AutoCaptureFrame")
    end
    
    self.CaptureFrame:SetScript("OnUpdate", function()
        if not WCS_BrainAutoCapture.Enabled then return end
        local now = GetTime()
        if now - WCS_BrainAutoCapture.LastCaptureTime >= WCS_BrainAutoCapture.CaptureInterval then
            WCS_BrainAutoCapture:CaptureTransition()
            WCS_BrainAutoCapture.LastCaptureTime = now
        end
    end)
end

function WCS_BrainAutoCapture:Stop()
    self.Enabled = false
    if self.CaptureFrame then
        self.CaptureFrame:SetScript("OnUpdate", nil)
    end
end

function WCS_BrainAutoCapture:OnCombatEnd(won)
    self:Stop()
    
    if not WCS_BrainDQN or not WCS_BrainDQN.enabled then return end
    
    local finalState = WCS_BrainState and WCS_BrainState:CaptureState()
    if not finalState then return end
    
    local finalReward = 0
    if WCS_BrainReward and WCS_BrainReward.CalculateFinalReward then
        finalReward = WCS_BrainReward:CalculateFinalReward(won, finalState)
    else
        finalReward = won and 10 or -10
    end
    
    if self.PreviousState and self.CurrentAction then
        if WCS_BrainDQN.ReplayBuffer and WCS_BrainDQN.ReplayBuffer.Add then
            WCS_BrainDQN.ReplayBuffer:Add(self.PreviousState, self.CurrentAction, finalReward, finalState, true)
            self.TransitionsThisCombat = self.TransitionsThisCombat + 1
        end
    end
    
    self.PreviousState = nil
    self.CurrentAction = nil
    self.TransitionsThisCombat = 0
end

function WCS_BrainAutoCapture:SetupCombatHooks()
    if self.CombatFrame then return end
    
    self.CombatFrame = CreateFrame("Frame")
    self.CombatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.CombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.CombatFrame:RegisterEvent("PLAYER_DEAD")
    self.CombatFrame:RegisterEvent("SPELLCAST_START")
    self.CombatFrame:RegisterEvent("SPELLCAST_CHANNEL_START")
    
    self.CombatFrame:SetScript("OnEvent", function()
        if event == "PLAYER_REGEN_DISABLED" then
            WCS_BrainAutoCapture:Start()
        elseif event == "PLAYER_REGEN_ENABLED" then
            WCS_BrainAutoCapture:OnCombatEnd(true)
        elseif event == "PLAYER_DEAD" then
            WCS_BrainAutoCapture:OnCombatEnd(false)
        elseif event == "SPELLCAST_START" or event == "SPELLCAST_CHANNEL_START" then
            if arg1 and WCS_BrainAutoCapture.SpellToAction[arg1] then
                WCS_BrainAutoCapture.LastDetectedAction = WCS_BrainAutoCapture.SpellToAction[arg1]
                WCS_BrainAutoCapture.CurrentAction = WCS_BrainAutoCapture.LastDetectedAction
            end
        end
    end)
end

function WCS_BrainAutoCapture:Initialize()
    self:SetupCombatHooks()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        delayFrame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed > 2 then
                WCS_BrainAutoCapture:Initialize()
                delayFrame:SetScript("OnUpdate", nil)
            end
        end)
    end
end)
