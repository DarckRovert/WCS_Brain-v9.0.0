--[[
    WCS_ResourceManager.lua - Gestor de Recursos Centralizado (v7.0)
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Centraliza el rastreo de items importantes (Soul Shards, Healthstones, etc.)
    para evitar múltiples escaneos de bolsa por diferentes módulos.
]]--

WCS_ResourceManager = WCS_ResourceManager or {}
WCS_ResourceManager.VERSION = "1.0.0"

-- ============================================================================
-- CONFIGURACIÓN Y CACHÉ
-- ============================================================================

-- Cache de recursos
WCS_ResourceManager.Cache = {
    soulShards = 0,
    healthstones = {}, -- [rankID] = {bag, slot, count}
    soulstones = {},
    reagents = {},     -- [itemID] = count
    
    lastUpdate = 0
}

-- IDs de items importantes
WCS_ResourceManager.ItemIDs = {
    SoulShard = "6265",
    
    -- Healthstones (Mayor a Menor)
    Healthstones = {
        Major = "22103",   -- Master Healthstone (Talented)
        MajorBase = "9421", -- Major Healthstone
        Greater = "5511",
        Lesser = "5512",
        Minor = "19004"
    },
    
    -- Soulstones
    Soulstones = {
        Major = "16896",
        Greater = "16895",
        Normal = "16893",
        Lesser = "16892",
        Minor = "5232"
    }
}

-- ============================================================================
-- LÓGICA DE ESCANEO
-- ============================================================================

local function DebugPrint(msg)
    if WCS_Brain and WCS_Brain.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[ResourceManager]|r " .. tostring(msg))
    end
end

-- Escanear una bolsa específica (optimización)
-- Si bagID es nil, escanea todas
function WCS_ResourceManager:ScanBags(targetBagID)
    -- Si es escaneo completo, resetear cache
    if not targetBagID then
        self.Cache.soulShards = 0
        self.Cache.healthstones = {}
        self.Cache.soulstones = {}
        self.Cache.reagents = {}
    end
    
    local startBag = targetBagID or 0
    local endBag = targetBagID or 4
    
    local shardCount = 0
    
    for bag = startBag, endBag do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Parsear ItemID del link: |Hitem:1234:0:0...
                local _, _, itemID = string.find(link, "item:(%d+)")
                
                if itemID then
                    -- 1. Soul Shards
                    if itemID == self.ItemIDs.SoulShard then
                        local _, count = GetContainerItemInfo(bag, slot)
                        shardCount = shardCount + (count or 1)
                    end
                    
                    -- 2. Healthstones
                    for rank, id in pairs(self.ItemIDs.Healthstones) do
                        if itemID == id then
                            -- Guardar la mejor ubicación encontrada
                            self.Cache.healthstones[rank] = {bag = bag, slot = slot, id = id}
                        end
                    end
                    
                    -- 3. Soulstones
                    for rank, id in pairs(self.ItemIDs.Soulstones) do
                        if itemID == id then
                            self.Cache.soulstones[rank] = {bag = bag, slot = slot, id = id}
                        end
                    end
                end
            end
        end
    end
    
    if not targetBagID then
        self.Cache.soulShards = shardCount
    else
        -- Si fue parcial, necesitamos una forma de ajustar el total sin reescanear todo
        -- Por seguridad en Lua 5.0 y simplicidad, si cambia una bolsa, mejor escaneamos todo
        -- para garantizar precisión (el costo no es tan alto si no se hace en OnUpdate)
        -- NOTA: Como optimización real, llamaremos ScanBags(nil) en BAG_UPDATE
        -- ignorando el argumento parcial por ahora para asegurar consistencia.
    end
    
    self.Cache.lastUpdate = GetTime()
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================

function WCS_ResourceManager:GetShardCount()
    return self.Cache.soulShards or 0
end

-- Retorna bag, slot de la mejor Healthstone disponible
function WCS_ResourceManager:GetBestHealthstone()
    local ranks = {"Major", "MajorBase", "Greater", "Lesser", "Minor"}
    for i, rank in ipairs(ranks) do
        if self.Cache.healthstones[rank] then
            return self.Cache.healthstones[rank].bag, self.Cache.healthstones[rank].slot
        end
    end
    return nil, nil
end

function WCS_ResourceManager:HasHealthstone()
    local b, s = self:GetBestHealthstone()
    return b ~= nil
end

-- ============================================================================
-- INICIALIZACIÓN Y EVENTOS
-- ============================================================================

function WCS_ResourceManager:Initialize()
    -- Registrarse al bus de eventos
    if WCS_EventManager and WCS_EventManager.Register then
        WCS_EventManager:Register("BAG_UPDATE", function() 
            -- Forzar rescan completo para evitar desincronización
            -- En WoW 1.12 las bolsas son pequeñas, iterar 5 bolsas no es crítico si es por evento
            WCS_ResourceManager:ScanBags(nil) 
        end, "WCS_ResourceManager")
        
        WCS_EventManager:Register("PLAYER_ENTERING_WORLD", function() 
            WCS_ResourceManager:ScanBags(nil) 
        end, "WCS_ResourceManager")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[ResourceManager]|r Error: WCS_EventManager requerido.")
    end
    
    -- Escaneo inicial
    self:ScanBags(nil)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WCS_ResourceManager]|r v" .. self.VERSION .. " cargado")
end

-- Auto-inicializar (despues de cargar)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    WCS_ResourceManager:Initialize()
end)
