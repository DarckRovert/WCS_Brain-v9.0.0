--[[
    WCS_BrainCore.lua - Núcleo de Ejecución del Cerebro Central
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema independiente - no requiere otros módulos WCS
]]--

WCS_BrainCore = WCS_BrainCore or {}
WCS_BrainCore.VERSION = "6.6.0"

-- ============================================================================
-- ESTADO INTERNO
-- ============================================================================
WCS_BrainCore.State = {
    lastCast = 0,
    lastSpell = nil,
    gcdEnd = 0,
    castEnd = 0,
    isCasting = false,
    
    -- Tracking de DoTs aplicados (por GUID/nombre de target)
    activeDoTs = {},
    
    -- Cooldowns internos
    cooldowns = {},
    
    -- Soul Shards
    soulShards = 0
}

-- ============================================================================
-- CONSTANTES
-- ============================================================================
local GCD = 1.5 -- Global Cooldown base

-- ============================================================================
-- FUNCIONES DE UTILIDAD (Lua 5.0)
-- ============================================================================

local function getTime()
    return GetTime and GetTime() or 0
end

local function debugPrint(msg)
    if WCS_Brain and WCS_Brain.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[BrainCore]|r " .. tostring(msg))
    end
end

-- ============================================================================
-- DETECCIÓN DE ESTADO
-- ============================================================================

-- Verificar si estamos en GCD
function WCS_BrainCore:IsOnGCD()
    -- Metodo 1: Usar nuestro tracking interno
    local now = getTime()
    if now < self.State.gcdEnd then
        return true
    end
    
    -- Metodo 2: Verificar GCD real usando GetSpellCooldown (mas confiable)
    -- Usamos un hechizo comun para verificar el GCD global
    if GetSpellCooldown then
        -- Buscar cualquier hechizo instant para verificar GCD
        local testSpells = {"Corruption", "Curse of Agony", "Life Tap", "Shadow Bolt"}
        for i = 1, 4 do
            local spellName = testSpells[i]
            local slot = self:FindSpellSlot(spellName)
            if slot then
                local start, duration = GetSpellCooldown(slot, BOOKTYPE_SPELL)
                if start and duration and start > 0 and duration > 0 and duration <= 1.5 then
                    -- Esta en GCD (duracion <= 1.5s indica GCD, no cooldown real)
                    return true
                end
                break -- Solo necesitamos verificar uno
            end
        end
    end
    
    return false
end

-- Verificar si estamos casteando
function WCS_BrainCore:IsCasting()
    if CastingBarFrame and CastingBarFrame:IsVisible() then
        return true
    end
    if ChannelBarFrame and ChannelBarFrame:IsVisible() then
        return true
    end
    return false
end

-- Verificar si podemos castear
-- canSuggest: si es true, solo verifica si podemos SUGERIR (no bloquea por GCD)
function WCS_BrainCore:CanCast(canSuggest)
    if UnitIsDeadOrGhost("player") then return false end
    if self:IsCasting() then return false end
    
    -- Si solo queremos saber si podemos sugerir, no verificar GCD
    -- Esto permite que el Brain siga sugiriendo hechizos mientras el GCD esta activo
    if canSuggest then return true end
    
    -- Para ejecucion real, verificar GCD
    if self:IsOnGCD() then return false end
    return true
end

-- Verificar si podemos sugerir un hechizo (no bloquea por GCD)
function WCS_BrainCore:CanSuggest()
    return self:CanCast(true)
end

-- Detectar si el jugador se está moviendo
-- Compatible con Turtle WoW / WoW 1.12 (Lua 5.0)
function WCS_BrainCore:IsMoving()
    local now = getTime()
    local isMoving = false
    
    -- Metodo Principal: Comparar posicion del JUGADOR en el mapa
    -- GetPlayerMapPosition devuelve coordenadas del jugador (0-1)
    local x, y = GetPlayerMapPosition("player")
    
    -- Debug: mostrar coordenadas
    if WCS_Brain and WCS_Brain.DEBUG then
        debugPrint("Pos: x=" .. tostring(x) .. ", y=" .. tostring(y))
    end
    
    -- Solo procesar si tenemos coordenadas validas (no 0,0)
    if x and y and (x ~= 0 or y ~= 0) then
        if self.lastPlayerX and self.lastPlayerY and self.lastPlayerTime then
            local dx = math.abs(x - self.lastPlayerX)
            local dy = math.abs(y - self.lastPlayerY)
            local dt = now - self.lastPlayerTime
            
            -- Si paso suficiente tiempo (0.1s) y la posicion cambio
            if dt >= 0.1 then
                -- Umbral pequeno para detectar movimiento
                if dx > 0.0001 or dy > 0.0001 then
                    isMoving = true
                end
                -- Actualizar posicion guardada
                self.lastPlayerX = x
                self.lastPlayerY = y
                self.lastPlayerTime = now
            end
        else
            -- Primera vez, guardar posicion inicial
            self.lastPlayerX = x
            self.lastPlayerY = y
            self.lastPlayerTime = now
        end
    end
    
    -- Cache del resultado para evitar fluctuaciones
    if isMoving then
        self.lastMovingTime = now
        self.isMovingCached = true
    else
        -- Mantener estado "moviendo" por 0.3s despues de parar
        -- para evitar sugerir cast spells justo al detenerse
        if self.lastMovingTime and (now - self.lastMovingTime) < 0.3 then
            isMoving = true
        else
            self.isMovingCached = false
        end
    end
    
    return isMoving
end

-- Contar Soul Shards en bolsas
function WCS_BrainCore:CountSoulShards()
    local count = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "Soul Shard") then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                count = count + (itemCount or 1)
            end
        end
    end
    self.State.soulShards = count
    return count
end

-- Buscar Healthstone en bolsas
function WCS_BrainCore:FindHealthstone()
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "Healthstone") then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- ============================================================================
-- DETECCIÓN DE DEBUFFS EN TARGET
-- ============================================================================

function WCS_BrainCore:GetTargetDebuffs()
    local debuffs = {}
    local i = 1
    
    while true do
        local texture = UnitDebuff("target", i)
        if not texture then break end
        
        -- Intentar identificar por textura
        local name = nil
        if WCS_SpellDB and WCS_SpellDB.DebuffTextures then
            name = WCS_SpellDB.DebuffTextures[texture]
        end
        
        debuffs[i] = {
            texture = texture,
            name = name or "Unknown",
            index = i
        }
        i = i + 1
    end
    
    return debuffs
end

-- Verificar si target tiene un debuff específico
function WCS_BrainCore:TargetHasDebuff(debuffName)
    local debuffs = self:GetTargetDebuffs()
    
    for i, debuff in pairs(debuffs) do
        if debuff.name == debuffName then
            return true
        end
        -- También buscar por substring en textura
        if string.find(debuff.texture or "", debuffName) then
            return true
        end
    end
    
    return false
end

-- Verificar DoTs activos
function WCS_BrainCore:HasCorruption()
    return self:TargetHasDebuff("Corruption") or 
           self:TargetHasDebuff("AbominationExplosion")
end

function WCS_BrainCore:HasImmolate()
    return self:TargetHasDebuff("Immolate") or 
           self:TargetHasDebuff("Immolation")
end

function WCS_BrainCore:HasCurseOfAgony()
    return self:TargetHasDebuff("Curse of Agony") or 
           self:TargetHasDebuff("CurseOfSargeras")
end

function WCS_BrainCore:HasSiphonLife()
    return self:TargetHasDebuff("Siphon Life") or 
           self:TargetHasDebuff("Requiem")
end

function WCS_BrainCore:HasAnyCurse()
    local debuffs = self:GetTargetDebuffs()
    for i, debuff in pairs(debuffs) do
        if string.find(debuff.name or "", "Curse") then
            return true
        end
        if string.find(debuff.texture or "", "Curse") then
            return true
        end
    end
    return false
end

-- ============================================================================
-- DETECCIÓN DE BUFFS EN PLAYER
-- ============================================================================

function WCS_BrainCore:GetPlayerBuffs()
    local buffs = {}
    local i = 1
    
    while true do
        local texture = GetPlayerBuffTexture(i)
        if not texture then break end
        
        buffs[i] = {
            texture = texture,
            index = i
        }
        i = i + 1
    end
    
    return buffs
end

function WCS_BrainCore:HasBuff(buffName)
    local buffs = self:GetPlayerBuffs()
    
    for i, buff in pairs(buffs) do
        if string.find(buff.texture or "", buffName) then
            return true
        end
    end
    
    return false
end

function WCS_BrainCore:HasDemonArmor()
    return self:HasBuff("DemonArmor") or self:HasBuff("Demon_Armor")
end

function WCS_BrainCore:HasSoulLink()
    return self:HasBuff("SoulLink") or self:HasBuff("Soul_Link")
end

-- ============================================================================
-- SISTEMA DE COOLDOWNS
-- ============================================================================

function WCS_BrainCore:StartCooldown(spellName, duration)
    self.State.cooldowns[spellName] = getTime() + duration
    debugPrint("Cooldown iniciado: " .. spellName .. " (" .. duration .. "s)")
end

function WCS_BrainCore:IsOnCooldown(spellName)
    local cdEnd = self.State.cooldowns[spellName]
    if cdEnd and getTime() < cdEnd then
        return true
    end
    return false
end

function WCS_BrainCore:GetCooldownRemaining(spellName)
    local cdEnd = self.State.cooldowns[spellName]
    if cdEnd then
        local remaining = cdEnd - getTime()
        if remaining > 0 then
            return remaining
        end
    end
    return 0
end

-- ============================================================================
-- EJECUCIÓN DE HECHIZOS
-- ============================================================================

-- Encontrar hechizo en spellbook y obtener su slot
function WCS_BrainCore:FindSpellSlot(spellName)
    local i = 1
    local bestSlot = nil
    local bestRank = 0
    
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        
        if name == spellName then
            local rankNum = 1
            if rank then
                local _, _, num = string.find(rank, "(%d+)")
                if num then rankNum = tonumber(num) or 1 end
            end
            if rankNum > bestRank then
                bestRank = rankNum
                bestSlot = i
            end
        end
        i = i + 1
    end
    
    return bestSlot, bestRank
end

-- Castear hechizo por nombre
function WCS_BrainCore:CastSpell(spellName, target)
    if not self:CanCast() then
        debugPrint("No se puede castear: " .. spellName)
        return false
    end
    
    local slot, rank = self:FindSpellSlot(spellName)
    if not slot then
        debugPrint("Hechizo no encontrado: " .. spellName)
        return false
    end
    
    -- Verificar cooldown
    if self:IsOnCooldown(spellName) then
        debugPrint("En cooldown: " .. spellName)
        return false
    end
    
    -- Target si es necesario
    if target and target ~= "target" then
        TargetUnit(target)
    end
    
    -- Castear
    CastSpell(slot, BOOKTYPE_SPELL)
    
    -- Registrar
    self.State.lastCast = getTime()
    self.State.lastSpell = spellName
    self.State.gcdEnd = getTime() + GCD
    
    -- Iniciar cooldown si aplica
    if WCS_SpellDB then
        local spellInfo = WCS_SpellDB:GetSpell(spellName)
        if spellInfo and spellInfo.cooldown then
            self:StartCooldown(spellName, spellInfo.cooldown)
        end
    end
    
    debugPrint("Casteando: " .. spellName .. " (Rank " .. rank .. ")")
    return true
end

-- Usar item de bolsa
function WCS_BrainCore:UseItem(bag, slot)
    if not self:CanCast() then return false end
    UseContainerItem(bag, slot)
    self.State.gcdEnd = getTime() + GCD
    return true
end

-- Usar Healthstone
function WCS_BrainCore:UseHealthstone()
    local bag, slot = self:FindHealthstone()
    if bag and slot then
        return self:UseItem(bag, slot)
    end
    return false
end

-- ============================================================================
-- COMANDOS DE MASCOTA
-- ============================================================================

function WCS_BrainCore:PetAttack()
    if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
        PetAttack()
        return true
    end
    return false
end

function WCS_BrainCore:PetFollow()
    if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
        PetFollow()
        return true
    end
    return false
end

function WCS_BrainCore:PetStay()
    if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
        PetWait()
        return true
    end
    return false
end

-- Usar habilidad de mascota por índice (1-4)
function WCS_BrainCore:UsePetAbility(index)
    if not UnitExists("pet") or UnitIsDeadOrGhost("pet") then
        return false
    end
    
    CastPetAction(index)
    return true
end

-- Spell Lock del Felhunter (generalmente slot 4)
function WCS_BrainCore:PetSpellLock()
    return self:UsePetAbility(4)
end

-- Seduction de Succubus (generalmente slot 4)
function WCS_BrainCore:PetSeduction()
    return self:UsePetAbility(4)
end

-- Sacrifice del Voidwalker
function WCS_BrainCore:PetSacrifice()
    return self:UsePetAbility(4)
end

-- ============================================================================
-- INTEGRACIÓN CON WCS_BRAIN
-- ============================================================================

function WCS_BrainCore:ExecuteAction(action)
    if not action then return false end
    
    local actionType = action.action
    local spell = action.spell
    
    if actionType == "CAST" then
        return self:CastSpell(spell)
        
    elseif actionType == "USE_ITEM" then
        if spell == "Healthstone" then
            return self:UseHealthstone()
        end
        
    elseif actionType == "PET_ABILITY" then
        if spell == "Spell Lock" then
            return self:PetSpellLock()
        elseif spell == "Seduction" then
            return self:PetSeduction()
        elseif spell == "Sacrifice" then
            return self:PetSacrifice()
        end
        
    elseif actionType == "PET_ATTACK" then
        return self:PetAttack()
        
    elseif actionType == "PET_FOLLOW" then
        return self:PetFollow()
    end
    
    return false
end

-- ============================================================================
-- FRAME DE ACTUALIZACIÓN
-- ============================================================================

function WCS_BrainCore:CreateUpdateFrame()
    if self.updateFrame then return end
    
    self.updateFrame = CreateFrame("Frame", "WCSBrainCoreFrame")
    self.updateFrame.elapsed = 0
    
    self.updateFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.1 then
            this.elapsed = 0
            WCS_BrainCore:OnUpdate()
        end
    end)
end

function WCS_BrainCore:OnUpdate()
    -- Actualizar estado de casting
    self.State.isCasting = self:IsCasting()
    
    -- Contar shards periódicamente
    self:CountSoulShards()
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================

function WCS_BrainCore:Initialize()
    self:CreateUpdateFrame()
    self:CountSoulShards()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_BrainCore]|r Nucleo de ejecucion cargado v" .. self.VERSION)
end

-- Auto-inicializar
WCS_BrainCore:Initialize()

