--[[
    WCS_BrainMacros.lua - Sistema de Macros Automáticas v6.6.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Genera macros optimizadas basadas en el aprendizaje del Brain
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainMacros = WCS_BrainMacros or {}
WCS_BrainMacros.VERSION = "6.6.0"

-- ============================================================================
-- CONFIGURACIÓN
-- ============================================================================
WCS_BrainMacros.Config = {
    enabled = true,
    autoUpdate = true,
    updateInterval = 60,  -- Actualizar cada 60 segundos
    macroName = "WCS_Optimal",
    maxSpells = 5  -- Máximo de hechizos en la macro
}

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainMacros:Initialize()
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Macros", "Sistema de macros inicializado")
    end
end

-- ============================================================================
-- FUNCIONES DE COMPATIBILIDAD CON WCS_BrainMetrics
-- ============================================================================

-- Obtener top hechizos desde WCS_BrainMetrics (sistema existente)
function WCS_BrainMacros:GetTopSpellsFromMetrics(maxSpells)
    if not WCS_BrainMetrics or not WCS_BrainMetrics.Data then
        return {}
    end
    
    local spells = {}
    
    -- Obtener datos de WCS_BrainMetrics
    for spellName, dps in WCS_BrainMetrics.Data.spellDPS do
        local damage = WCS_BrainMetrics.Data.spellDamageTotal[spellName] or 0
        local usage = WCS_BrainMetrics.Data.spellUsage[spellName] or 0
        
        if usage > 0 and damage > 0 then
            table.insert(spells, {
                name = spellName,
                dps = dps,
                damage = damage,
                casts = usage
            })
        end
    end
    
    -- Ordenar por DPS
    table.sort(spells, function(a, b) return a.dps > b.dps end)
    
    -- Limitar a maxSpells
    local result = {}
    for i = 1, math.min(maxSpells, table.getn(spells)) do
        table.insert(result, spells[i])
    end
    
    return result
end

-- ============================================================================
-- GENERACIÓN DE MACROS
-- ============================================================================
function WCS_BrainMacros:GenerateOptimalMacro()
    -- Usar WCS_BrainMetrics (sistema existente que YA funciona)
    if WCS_BrainMetrics and WCS_BrainMetrics.Data then
        local topSpells = self:GetTopSpellsFromMetrics(self.Config.maxSpells)
        
        if topSpells and table.getn(topSpells) > 0 then
            -- Construir macro con datos reales
            local macro = "#showtooltip\n"
            for i = 1, table.getn(topSpells) do
                local spell = topSpells[i]
                macro = macro .. "/cast [target=enemy] " .. spell.name .. "\n"
            end
            return macro
        end
    end
    
    -- Si no hay datos, generar macro por defecto
    local macro = "#showtooltip\n"
    macro = macro .. "/cast Shadow Bolt\n"
    macro = macro .. "/cast Corruption\n"
    macro = macro .. "/cast Curse of Agony\n"
    macro = macro .. "/cast Immolate\n"
    macro = macro .. "/cast Drain Life\n"
    return macro
end

function WCS_BrainMacros:CreateMacro()
    local macroText = self:GenerateOptimalMacro()
    
    if not macroText then
        if WCS_BrainLogger then
            WCS_BrainLogger:Warn("Macros", "No hay suficientes datos para crear macro")
        end
        return false
    end
    
    -- Buscar si la macro ya existe
    local macroIndex = GetMacroIndexByName(self.Config.macroName)
    
    if macroIndex == 0 then
        -- Crear nueva macro
        CreateMacro(self.Config.macroName, 1, macroText, 1)
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("Macros", "Macro creada: " .. self.Config.macroName)
        end
    else
        -- Actualizar macro existente
        EditMacro(macroIndex, self.Config.macroName, 1, macroText)
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("Macros", "Macro actualizada: " .. self.Config.macroName)
        end
    end
    
    return true
end

function WCS_BrainMacros:DeleteMacro()
    local macroIndex = GetMacroIndexByName(self.Config.macroName)
    
    if macroIndex > 0 then
        DeleteMacro(self.Config.macroName)
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("Macros", "Macro eliminada: " .. self.Config.macroName)
        end
        return true
    end
    
    return false
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSMACROS1 = "/wcsmacro"
SLASH_WCSMACROS2 = "/brainmacro"

SlashCmdList["WCSMACROS"] = function(msg)
    if msg == "create" then
        WCS_BrainMacros:CreateMacro()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Macros]|r Macro creada/actualizada")
        
    elseif msg == "delete" then
        if WCS_BrainMacros:DeleteMacro() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Macros]|r Macro eliminada")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Macros]|r Macro no encontrada")
        end
        
    elseif msg == "show" then
        local macroText = WCS_BrainMacros:GenerateOptimalMacro()
        if macroText then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Macros]|r Contenido de la macro:")
            DEFAULT_CHAT_FRAME:AddMessage(macroText)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Macros]|r No hay suficientes datos")
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Macros]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmacro create|r - Crear/actualizar macro")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmacro delete|r - Eliminar macro")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmacro show|r - Mostrar contenido")
    end
end

-- Auto-inicialización
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainMacros:Initialize()
    end
end)


-- Macros del Guardian
WCS_BrainMacros.Guardian = {}
function WCS_BrainMacros.Guardian:CreateGuardMacro()
    local macroName = "WCS_Guard"
    local macroText = "/petguard target"
    local macroIcon = 1  -- Índice numérico del icono
    local macroIndex = GetMacroIndexByName(macroName)
    if macroIndex == 0 then
        CreateMacro(macroName, macroIcon, macroText, 1)  -- 1 = per-character macro
        return true, "creada"
    else
        EditMacro(macroIndex, macroName, macroIcon, macroText)
        return true, "actualizada"
    end
end

function WCS_BrainMacros.Guardian:CreatePositionMacro()
    local macroName = "WCS_PetPos"
    local macroText = "/cast Pet Command: Take Position"
    local macroIcon = 1  -- Índice numérico del icono
    local macroIndex = GetMacroIndexByName(macroName)
    if macroIndex == 0 then
        CreateMacro(macroName, macroIcon, macroText, 1)  -- 1 = per-character macro
        return true, "creada"
    else
        EditMacro(macroIndex, macroName, macroIcon, macroText)
        return true, "actualizada"
    end
end
function WCS_BrainMacros.Guardian:CreateAll()
    local results = {}
    local ok1, msg1 = self:CreateGuardMacro()
    table.insert(results, { name = "WCS_Guard", success = ok1, message = msg1 })
    local ok2, msg2 = self:CreatePositionMacro()
    table.insert(results, { name = "WCS_PetPos", success = ok2, message = msg2 })
    return results
end
SLASH_GUARDMACROS1 = "/guardmacros"
SlashCmdList["GUARDMACROS"] = function(msg)
    if msg == "create" or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFAA[Guardian Macros]|r Creando macros...")
        local results = WCS_BrainMacros.Guardian:CreateAll()
        for i = 1, table.getn(results) do
            local r = results[i]
            if r.success then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FF00OK|r %s - %s", r.name, r.message))
            end
        end
    end
end

