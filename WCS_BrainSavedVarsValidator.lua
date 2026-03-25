--[[
    WCS_BrainSavedVarsValidator.lua - Validación de SavedVariables
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    Version: 1.0.0
    
    Valida y repara SavedVariables corruptas, migra entre versiones,
    y asegura la integridad de los datos guardados.
]]--

WCS_BrainSavedVarsValidator = WCS_BrainSavedVarsValidator or {}
local Validator = WCS_BrainSavedVarsValidator

Validator.VERSION = "1.0.0"
Validator.CURRENT_DATA_VERSION = "6.8.0"

-- ============================================================================
-- ESTRUCTURA DE DATOS POR DEFECTO
-- ============================================================================
Validator.DefaultStructure = {
    version = "6.8.0",
    
    settings = {
        enabled = true,
        debug = false,
        aiMode = "hybrid",
        petAIEnabled = true,
        autoProfile = true
    },
    
    profiles = {
        current = "default",
        list = {
            default = {
                name = "Default",
                settings = {}
            }
        }
    },
    
    state = {
        firstRun = true,
        lastLogin = 0,
        totalSessions = 0
    }
}

-- ============================================================================
-- VALIDACIÓN PRINCIPAL
-- ============================================================================

function Validator:ValidateAll()
    local results = {
        success = true,
        errors = {},
        warnings = {},
        repairs = {}
    }
    
    -- Validar WCS_BrainSaved
    local mainResult = self:ValidateMainSaved()
    if not mainResult.success then
        results.success = false
    end
    
    -- Copiar resultados
    for i = 1, table.getn(mainResult.errors) do
        table.insert(results.errors, mainResult.errors[i])
    end
    for i = 1, table.getn(mainResult.warnings) do
        table.insert(results.warnings, mainResult.warnings[i])
    end
    for i = 1, table.getn(mainResult.repairs) do
        table.insert(results.repairs, mainResult.repairs[i])
    end
    
    return results
end

function Validator:ValidateMainSaved()
    local result = {
        success = true,
        errors = {},
        warnings = {},
        repairs = {}
    }
    
    -- Verificar existencia
    if not WCS_BrainSaved then
        WCS_BrainSaved = self:CreateDefaultStructure()
        table.insert(result.repairs, "WCS_BrainSaved creado desde cero")
        return result
    end
    
    -- Verificar tipo
    if type(WCS_BrainSaved) ~= "table" then
        WCS_BrainSaved = self:CreateDefaultStructure()
        table.insert(result.errors, "WCS_BrainSaved corrupto - recreado")
        result.success = false
        return result
    end
    
    -- Verificar versión
    if not WCS_BrainSaved.version then
        WCS_BrainSaved.version = "6.0.0"
        table.insert(result.warnings, "Versión no encontrada - asumiendo 6.0.0")
    end
    
    -- Migrar si es necesario
    if WCS_BrainSaved.version ~= self.CURRENT_DATA_VERSION then
        self:MigrateData(WCS_BrainSaved.version, self.CURRENT_DATA_VERSION)
        table.insert(result.repairs, "Migrado de v" .. WCS_BrainSaved.version .. " a v" .. self.CURRENT_DATA_VERSION)
        WCS_BrainSaved.version = self.CURRENT_DATA_VERSION
    end
    
    -- Verificar campos críticos
    local requiredFields = {"settings", "profiles", "state"}
    for i = 1, table.getn(requiredFields) do
        local field = requiredFields[i]
        if not WCS_BrainSaved[field] or type(WCS_BrainSaved[field]) ~= "table" then
            WCS_BrainSaved[field] = self:DeepCopy(self.DefaultStructure[field])
            table.insert(result.repairs, "Campo '" .. field .. "' restaurado")
        end
    end
    
    return result
end

function Validator:MigrateData(fromVersion, toVersion)
    if not WCS_BrainSaved then return false end
    
    -- Migraciones específicas
    if WCS_BrainSaved.settings and not WCS_BrainSaved.settings.aiMode then
        WCS_BrainSaved.settings.aiMode = "hybrid"
    end
    
    return true
end

-- ============================================================================
-- UTILIDADES
-- ============================================================================

function Validator:CreateDefaultStructure()
    return self:DeepCopy(self.DefaultStructure)
end

function Validator:DeepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = self:DeepCopy(value)
        else
            copy[key] = value
        end
    end
    
    return copy
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSVALIDATE1 = "/wcsvalidate"
SlashCmdList["WCSVALIDATE"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "check" or msg == "" then
        local results = Validator:ValidateAll()
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS Validator]|r Resultados:")
        DEFAULT_CHAT_FRAME:AddMessage("  Estado: " .. (results.success and "|cFF00FF00OK|r" or "|cFFFF0000ERROR|r"))
        
        if table.getn(results.errors) > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  |cFFFF0000Errores:|r")
            for i = 1, table.getn(results.errors) do
                DEFAULT_CHAT_FRAME:AddMessage("    - " .. results.errors[i])
            end
        end
        
        if table.getn(results.repairs) > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FF00Reparaciones:|r")
            for i = 1, table.getn(results.repairs) do
                DEFAULT_CHAT_FRAME:AddMessage("    - " .. results.repairs[i])
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS Validator]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("  /wcsvalidate check - Validar SavedVariables")
    end
end

-- ============================================================================
-- INICIALIZACIÓN AUTOMÁTICA
-- ============================================================================
local InitFrame = CreateFrame("Frame")
InitFrame:RegisterEvent("ADDON_LOADED")
InitFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        local results = Validator:ValidateAll()
        
        if table.getn(results.repairs) > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS Brain]|r " .. table.getn(results.repairs) .. " reparaciones aplicadas")
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS Brain]|r SavedVarsValidator v" .. Validator.VERSION .. " cargado")
    end
end)
