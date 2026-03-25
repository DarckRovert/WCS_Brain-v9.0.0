--[[
    WCS_PetManager.lua - Pet Intelligence Engine v8.0.0 (Multi-Class)
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
]]--

WCS = WCS or {}
WCS.PetManager = WCS.PetManager or {}
local PM = WCS.PetManager

function PM:OnUpdate()
    -- Solo para Brujos y Cazadores
    local cls = WCS.ClassEngine and WCS.ClassEngine.class
    if cls and cls ~= "WARLOCK" and cls ~= "HUNTER" then return end

    if not UnitExists("pet") then return end
    
    -- [1] DELEGACIÓN AL MOTOR AVANZADO (Si es Brujo)
    -- Esto garantiza que el PetAI tome el control total sin interferencias del manager básico
    if cls == "WARLOCK" and WCS_BrainPetAI and WCS_BrainPetAI.ENABLED then
        return -- Si PetAI está activo, él toma el control total
    end

    -- [2] Lógica básica para Cazadores o si PetAI está apagado
    if not WCS_BrainSaved or not WCS_BrainSaved.Config or not WCS_BrainSaved.Config.PetManager then return end
    
    local petMaxHP = UnitHealthMax("pet")
    if petMaxHP <= 0 then return end
    local hp = (UnitHealth("pet") / petMaxHP) * 100
    
    -- Curación básica
    if hp < 40 and not UnitAffectingCombat("player") then
        if WCS.SpellManager then WCS.SpellManager:Cast("Health Funnel") end
    end
    
    -- Ataque básico
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitAffectingCombat("pet") then
        PetAttack()
    end
end

WCS:Log("Pet Manager v8.0.0 (Multi-Class Guard) Ready.")
