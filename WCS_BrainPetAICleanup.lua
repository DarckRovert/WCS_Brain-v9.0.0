--[[
    WCS_BrainPetAICleanup.lua - Sistema de Limpieza de Cooldowns de Mascotas
    Parte del addon WCS_Brain v6.8.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    FASE 2 - OPTIMIZACIÓN DE MEMORIA
    Este módulo agrega limpieza automática de cooldowns de mascotas
    para prevenir crecimiento indefinido de la tabla PetAI.cooldowns
]]--

-- Verificar que PetAI esté cargado
if not PetAI then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WCS_PetAICleanup]|r Error: PetAI no está cargado")
    return
end

-- ============================================================================
-- FUNCIÓN DE LIMPIEZA DE COOLDOWNS DE MASCOTAS
-- ============================================================================
function PetAI:CleanupCooldowns()
    if not self.cooldowns then return end
    
    local now = GetTime()
    local cleaned = 0
    
    for spellName, cdData in pairs(self.cooldowns) do
        if cdData and cdData.start and cdData.duration then
            -- Si el cooldown ya expiró, eliminarlo
            if (now - cdData.start) >= cdData.duration then
                self.cooldowns[spellName] = nil
                cleaned = cleaned + 1
            end
        end
    end
    
    -- Debug message (solo si hay cooldowns limpiados y DEBUG activo)
    if cleaned > 0 and WCS_Brain and WCS_Brain.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[PetAI]|r " .. cleaned .. " cooldowns de mascota limpiados")
    end
end

-- ============================================================================
-- FRAME DE LIMPIEZA AUTOMÁTICA
-- ============================================================================
PetAI.CleanupFrame = CreateFrame("Frame", "WCS_PetAICleanupFrame", UIParent)
PetAI.CleanupFrame.timeSinceLastCleanup = 0
PetAI.CleanupFrame.cleanupInterval = 60 -- Limpiar cada 60 segundos

PetAI.CleanupFrame:SetScript("OnUpdate", function()
    this.timeSinceLastCleanup = this.timeSinceLastCleanup + arg1
    
    if this.timeSinceLastCleanup >= this.cleanupInterval then
        PetAI:CleanupCooldowns()
        this.timeSinceLastCleanup = 0
    end
end)

-- Mensaje de confirmación de carga
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_PetAICleanup]|r Sistema de limpieza de cooldowns de mascota activado (cada 60s)")
