--[[
    WCS_BrainCleanup.lua - Sistema de Limpieza Automática de Cooldowns
    Parte del addon WCS_Brain v6.8.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    FASE 2 - OPTIMIZACIÓN DE MEMORIA
    Este módulo agrega limpieza automática de cooldowns expirados
    para prevenir crecimiento indefinido de la tabla WCS_Brain.Cooldowns
]]--

-- Verificar que WCS_Brain esté cargado
if not WCS_Brain then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS_BrainCleanup]|r Error: WCS_Brain no está cargado")
    return
end

-- ============================================================================
-- FRAME DE LIMPIEZA AUTOMÁTICA DE COOLDOWNS
-- ============================================================================
WCS_Brain.CleanupFrame = CreateFrame("Frame", "WCS_BrainCleanupFrame", UIParent)
WCS_Brain.CleanupFrame.timeSinceLastCleanup = 0
WCS_Brain.CleanupFrame.cleanupInterval = 60 -- Limpiar cada 60 segundos

WCS_Brain.CleanupFrame:SetScript("OnUpdate", function()
    this.timeSinceLastCleanup = this.timeSinceLastCleanup + arg1
    
    if this.timeSinceLastCleanup >= this.cleanupInterval then
        -- Llamar a la función de limpieza existente en WCS_Brain
        if WCS_Brain.CleanupCooldowns then
            WCS_Brain:CleanupCooldowns()
            this.timeSinceLastCleanup = 0
            
            -- Debug message (solo si DEBUG está activado)
            if WCS_Brain.DEBUG then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Brain]|r Cooldowns limpiados automáticamente")
            end
        end
    end
end)

-- Mensaje de confirmación de carga
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_BrainCleanup]|r Sistema de limpieza automática activado (cada 60s)")
