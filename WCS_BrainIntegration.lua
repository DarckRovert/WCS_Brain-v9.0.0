--[[
    WCS_BrainIntegration.lua - Integración del DQN con el sistema existente
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Conecta el DQN con WCS_Brain, WCS_BrainAI y WCS_BrainML
]]--

WCS_BrainIntegration = WCS_BrainIntegration or {}
WCS_BrainIntegration.VERSION = "6.4.2"

-- ============================================================================
-- TRACKING DE ACCIONES
-- ============================================================================
WCS_BrainIntegration.CurrentAction = nil
WCS_BrainIntegration.PreviousState = nil
WCS_BrainIntegration.ActionCounter = 0
WCS_BrainIntegration.LastActionTime = 0
WCS_BrainIntegration.ActionSequence = {}

-- ============================================================================
-- MAPEO DE ACCIONES (DQN -> WCS_Brain)
-- ============================================================================
WCS_BrainIntegration.ActionMap = {
    [1] = "Shadow Bolt",
    [2] = "Corruption",
    [3] = "Curse of Agony",
    [4] = "Immolate",
    [5] = "Siphon Life",
    [6] = "Life Tap",
    [7] = "Dark Pact",
    [8] = "Death Coil",
    [9] = "Shadowburn",
    [10] = "Fear",
    [11] = "Drain Life",
    [12] = "Healthstone",
    [13] = nil  -- WAIT = no hacer nada
}

-- ============================================================================
-- FUNCIÓN DE DECISIÓN DQN (llamada por BrainAI)
-- ============================================================================
-- Esta función NO sobrescribe GetNextAction()
-- En su lugar, BrainAI la llamará cuando necesite una decisión
-- Retorna nil si DQN está desactivado, permitiendo que BrainAI use su sistema
function WCS_BrainIntegration:GetDQNAction()
    -- Si DQN está desactivado, retornar nil para que BrainAI use su sistema
    if not WCS_BrainDQN or not WCS_BrainDQN.enabled then
        return nil
    end
        
        -- Capturar estado actual
        local currentState = WCS_BrainState:CaptureState()
        
        -- Si tenemos estado previo, calcular recompensa y almacenar transición
        if WCS_BrainIntegration.PreviousState and WCS_BrainIntegration.CurrentAction then
            local reward = WCS_BrainReward:CalculateImmediateReward(
                WCS_BrainIntegration.CurrentAction,
                WCS_BrainIntegration.PreviousState,
                currentState
            )
            
            -- Detectar combos
            local comboReward = WCS_BrainReward:DetectCombo(WCS_BrainIntegration.ActionSequence)
            reward = reward + comboReward
            
            -- Almacenar transición
            local done = not UnitAffectingCombat("player")
            WCS_BrainDQN:StoreTransition(
                WCS_BrainIntegration.PreviousState,
                WCS_BrainIntegration.CurrentAction,
                reward,
                currentState,
                done
            )
        end
        
        -- Seleccionar nueva acción con DQN
        local action = WCS_BrainDQN:SelectAction(currentState)
        
        -- Guardar para próxima iteración
        WCS_BrainIntegration.PreviousState = currentState
        WCS_BrainIntegration.CurrentAction = action
        WCS_BrainIntegration.LastActionTime = GetTime()
        
        -- Agregar a secuencia
        table.insert(WCS_BrainIntegration.ActionSequence, action)
        if WCS_TableCount(WCS_BrainIntegration.ActionSequence) > 10 then
            table.remove(WCS_BrainIntegration.ActionSequence, 1)
        end
        
        -- Convertir acción a nombre usando el mapa central de acciones si existe
        local actionName = nil
        if WCS_BrainActions and WCS_BrainActions.ActionMap then
            actionName = WCS_BrainActions.ActionMap[action]
        else
            actionName = WCS_BrainIntegration.ActionMap[action]
        end

        -- Validar índice de acción y existencia del nombre (acción WAIT u otras = nil)
        local maxActions = (WCS_BrainDQN and WCS_BrainDQN.Config and WCS_BrainDQN.Config.actionSize) or 30
        if type(action) ~= "number" or action < 1 or action > maxActions then
            return nil
        end
        if not actionName then
            return nil
        end
        
        -- Devolver en formato tabla compatible con WCS_Brain
        return {
            action = "CAST",
            spell = actionName,
            priority = 1,
            reason = "DQN Action"
        }
end

-- ============================================================================
-- HOOK EN EVENTOS DE COMBATE
-- ============================================================================
function WCS_BrainIntegration:HookCombatEvents()
    -- Frame para eventos
    if not WCS_BrainIntegration.EventFrame then
        WCS_BrainIntegration.EventFrame = CreateFrame("Frame")
    end
    
    local frame = WCS_BrainIntegration.EventFrame
    
    -- Registrar eventos
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_DEAD")
    frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
    frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
    
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_REGEN_DISABLED" then
            -- Inicio de combate
            WCS_BrainIntegration:OnCombatStart()
            
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Fin de combate (victoria)
            WCS_BrainIntegration:OnCombatEnd(true)
            
        elseif event == "PLAYER_DEAD" then
            -- Fin de combate (derrota)
            WCS_BrainIntegration:OnCombatEnd(false)
            
        elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
            -- Tracking de daño
            WCS_BrainIntegration:OnDamageEvent(arg1)
        end
    end)
    
    -- Combat events registrados
end

-- ============================================================================
-- EVENTOS DE COMBATE
-- ============================================================================
function WCS_BrainIntegration:OnCombatStart()
    WCS_BrainReward:ResetCombatStats()
    self.ActionSequence = {}
    self.PreviousState = nil
    self.CurrentAction = nil
end

function WCS_BrainIntegration:OnCombatEnd(won)
    if not WCS_BrainDQN or not WCS_BrainDQN.enabled then
        return
    end
    
    -- Capturar estado final
    local finalState = WCS_BrainState:CaptureState()
    
    -- Calcular recompensa final
    local finalReward = WCS_BrainReward:CalculateFinalReward(won, finalState)
    
    -- Si hay una transición pendiente, agregarle la recompensa final
    if self.PreviousState and self.CurrentAction then
        WCS_BrainDQN:StoreTransition(
            self.PreviousState,
            self.CurrentAction,
            finalReward,
            finalState,
            true
        )
    end
    
    -- Actualizar estadísticas de recompensa
    WCS_BrainDQN.Stats.totalReward = WCS_BrainDQN.Stats.totalReward + finalReward
    WCS_BrainDQN.Stats.lastEpisodeReward = finalReward
    
    -- Actualizar victorias/derrotas
    if won then
        WCS_BrainDQN.Stats.wins = WCS_BrainDQN.Stats.wins + 1
    else
        WCS_BrainDQN.Stats.losses = WCS_BrainDQN.Stats.losses + 1
    end
    
    -- Notificar fin de episodio
    WCS_BrainDQN:EndEpisode()
    
    -- Resetear
    self.PreviousState = nil
    self.CurrentAction = nil
    self.ActionSequence = {}
end

function WCS_BrainIntegration:OnDamageEvent(msg)
    if not msg then return end
    
    -- Parsear daño del mensaje (sin usar string.match)
    local damage = nil
    local i = 1
    while i <= string.len(msg) do
        local char = string.sub(msg, i, i)
        if char >= "0" and char <= "9" then
            local j = i
            while j <= string.len(msg) do
                local c = string.sub(msg, j, j)
                if c < "0" or c > "9" then
                    break
                end
                j = j + 1
            end
            damage = tonumber(string.sub(msg, i, j - 1))
            break
        end
        i = i + 1
    end
    
    if damage then
        -- Determinar si es daño hecho o recibido
        if string.find(msg, "hit") or string.find(msg, "crit") then
            WCS_BrainReward:OnDamageDealt(damage)
        elseif string.find(msg, "hits you") or string.find(msg, "crits you") then
            WCS_BrainReward:OnDamageTaken(damage)
        end
    end
end

-- ============================================================================
-- HOOK EN WCS_BrainML (si existe)
-- ============================================================================
function WCS_BrainIntegration:HookML()
    if not WCS_BrainML then
        return
    end
    
    -- Guardar función original
    if not WCS_BrainML.OriginalLearn_DQN then
        WCS_BrainML.OriginalLearn_DQN = WCS_BrainML.Learn
    end
    
    -- Nueva función que también usa DQN
    WCS_BrainML.Learn = function(self, action, success)
        -- Llamar al sistema original
        if WCS_BrainML.OriginalLearn_DQN then
            WCS_BrainML.OriginalLearn_DQN(self, action, success)
        end
        
        -- Si DQN está activo, también aprender ahí
        if WCS_BrainDQN and WCS_BrainDQN.enabled then
            -- El DQN ya está aprendiendo automáticamente
            -- Este hook es solo para compatibilidad
        end
    end
    
    -- ML system hooked silenciosamente
end

-- ============================================================================
-- DESACTIVAR HOOKS
-- ============================================================================
function WCS_BrainIntegration:UnhookAll()
    -- NOTA: Ya no hay hook en GetNextAction() que restaurar
    -- BrainAI simplemente dejará de llamar a GetDQNAction() si DQN está desactivado
    
    -- Restaurar ML
    if WCS_BrainML and WCS_BrainML.OriginalLearn_DQN then
        WCS_BrainML.Learn = WCS_BrainML.OriginalLearn_DQN
        WCS_BrainML.OriginalLearn_DQN = nil
    end
    
    -- Desregistrar eventos
    if self.EventFrame then
        self.EventFrame:UnregisterAllEvents()
    end
    
    -- Hooks removidos
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
function WCS_BrainIntegration:Initialize()
    -- Esperar a que WCS_Brain esté cargado
    if not WCS_Brain then
        -- Esperando WCS_Brain...
        return false
    end
    
    -- Instalar hooks de eventos y ML
    -- NOTA: Ya NO instalamos hook en GetNextAction()
    -- BrainAI llamará directamente a GetDQNAction() cuando necesite
    self:HookCombatEvents()
    self:HookML()
    
    -- Integración cargada silenciosamente
    return true
end

-- ============================================================================
-- AUTO-INICIALIZACION
-- ============================================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        -- Esperar un poco para que todo se cargue
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        delayFrame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed > 1 then
                WCS_BrainIntegration:Initialize()
                delayFrame:SetScript("OnUpdate", nil)
            end
        end)
    end
end)

-- ============================================================================
-- COMANDO /WCS - Unificado para ambas IAs
-- ============================================================================
SLASH_WCS1 = "/wcs"
SlashCmdList["WCS"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "cast" or cmd == "brain" then
        if WCS_Brain and WCS_Brain.Execute then
            WCS_Brain:Execute()
        end
    elseif cmd == "dqn" or cmd == "ai" then
        if not WCS_BrainDQN or not WCS_BrainDQN.enabled then return end
        local currentState = WCS_BrainState and WCS_BrainState:CaptureState()
        if not currentState then return end
        local action = WCS_BrainDQN:SelectAction(currentState)
        if not action or action == 13 then return end
        local spellName = WCS_BrainIntegration.ActionMap[action]
        if not spellName then return end
        if WCS_BrainCore then
            WCS_BrainCore:ExecuteAction({action="CAST",spell=spellName,priority=1,reason="DQN"})
        end
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[WCS]|r Brain:" .. (WCS_Brain.ENABLED and "ON" or "OFF") .. " DQN:" .. (WCS_BrainDQN.enabled and "ON" or "OFF"))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[WCS]|r /wcs cast | /wcs dqn | /wcs status")
    end
end

