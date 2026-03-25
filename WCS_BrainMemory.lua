--[[
    WCS_BrainMemory.lua - Sistema de Recuerdos v6.6.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    El Brain recuerda encuentros anteriores y aprende de ellos
    
    Autor: Elnazzareno (DarckRovert)
    Twitch: twitch.tv/darckrovert
    Kick: kick.com/darckrovert
]]--

WCS_BrainMemory = WCS_BrainMemory or {}
WCS_BrainMemory.VERSION = "6.6.0"

-- ============================================================================
-- ESTRUCTURA DE MEMORIA
-- ============================================================================
WCS_BrainMemory.Encounters = {}
WCS_BrainMemory.Config = {
    maxEncounters = 500,
    autoSave = true,
    saveInterval = 300,  -- 5 minutos
    trackRotations = true,
    trackDifficulty = true
}

-- ============================================================================
-- INTEGRACIÓN CON WCS_BrainMetrics
-- ============================================================================

-- Sincronizar con WCS_BrainMetrics (sistema existente)
function WCS_BrainMemory:SyncWithMetrics()
    if not WCS_BrainMetrics or not WCS_BrainMetrics.Data then
        return
    end
    
    -- Obtener datos de enemigos desde WCS_BrainMetrics
    if WCS_BrainMetrics.Data.enemyTypes then
        for enemyName, enemyData in pairs(WCS_BrainMetrics.Data.enemyTypes) do
            if enemyData.encounters and enemyData.encounters > 0 then
                -- Crear o actualizar memoria
                if not self.Encounters[enemyName] then
                    self.Encounters[enemyName] = {
                        name = enemyName,
                        firstSeen = time(),
                        lastSeen = time(),
                        encounters = 0,
                        kills = 0,
                        deaths = 0,
                        totalDamage = 0,
                        totalTime = 0,
                        avgTTK = 0,
                        avgDPS = 0,
                        bestRotation = {},
                        worstRotation = {},
                        notes = "",
                        difficulty = "Unknown",
                        level = 0,
                        type = "Unknown",
                        classification = "normal",
                        abilities = {},
                        weaknesses = {},
                        resistances = {}
                    }
                end
                
                local memory = self.Encounters[enemyName]
                memory.encounters = enemyData.encounters or memory.encounters
                memory.kills = enemyData.kills or memory.kills
                memory.deaths = enemyData.deaths or memory.deaths
                memory.lastSeen = time()
                
                -- Calcular dificultad
                if self.Config.trackDifficulty then
                    memory.difficulty = self:CalculateDifficulty(memory)
                end
            end
        end
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Debug("Memory", "Sincronizado con WCS_BrainMetrics")
    end
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainMemory:Initialize()
    -- Cargar desde SavedVariables
    if WCS_BrainSaved and WCS_BrainSaved.memory then
        self.Encounters = WCS_BrainSaved.memory
    else
        self.Encounters = {}
    end
    
    -- Iniciar auto-save
    if self.Config.autoSave then
        self:StartAutoSave()
    end
    
    -- Sincronizar con WCS_BrainMetrics al iniciar
    self:SyncWithMetrics()
    
    if WCS_BrainLogger then
        local count = 0
        for _ in pairs(self.Encounters) do count = count + 1 end
        WCS_BrainLogger:Info("Memory", "Sistema de recuerdos inicializado (" .. count .. " encuentros)")
    end
end

-- ============================================================================
-- RECORDAR ENCUENTRO
-- ============================================================================
function WCS_BrainMemory:Remember(mobName, outcome, data)
    if not mobName then return end
    
    -- Crear entrada si no existe
    if not self.Encounters[mobName] then
        self.Encounters[mobName] = {
            name = mobName,
            firstSeen = time(),
            lastSeen = time(),
            encounters = 0,
            kills = 0,
            deaths = 0,
            totalDamage = 0,
            totalTime = 0,
            avgTTK = 0,
            avgDPS = 0,
            bestRotation = {},
            worstRotation = {},
            notes = "",
            difficulty = "Unknown",
            level = 0,
            type = "Unknown",
            classification = "normal",
            abilities = {},
            weaknesses = {},
            resistances = {}
        }
    end
    
    local memory = self.Encounters[mobName]
    memory.encounters = memory.encounters + 1
    memory.lastSeen = time()
    
    -- Actualizar datos básicos
    if data then
        if data.level then memory.level = data.level end
        if data.type then memory.type = data.type end
        if data.classification then memory.classification = data.classification end
    end
    
    -- Actualizar resultado
    if outcome == "kill" then
        memory.kills = memory.kills + 1
        
        if data and data.duration then
            memory.totalTime = memory.totalTime + data.duration
            memory.avgTTK = memory.totalTime / memory.kills
        end
        
        if data and data.damage then
            memory.totalDamage = memory.totalDamage + data.damage
            memory.avgDPS = memory.totalDamage / memory.totalTime
        end
        
        -- Actualizar mejor rotación
        if data and data.rotation and self.Config.trackRotations then
            self:UpdateBestRotation(memory, data.rotation, data.duration)
        end
        
    elseif outcome == "death" then
        memory.deaths = memory.deaths + 1
        
        -- Actualizar peor rotación
        if data and data.rotation and self.Config.trackRotations then
            memory.worstRotation = data.rotation
        end
    end
    
    -- Calcular dificultad
    if self.Config.trackDifficulty then
        memory.difficulty = self:CalculateDifficulty(memory)
    end
    
    -- Verificar límite de memoria
    self:CheckMemoryLimit()
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Debug("Memory", "Encuentro recordado: " .. mobName .. " (" .. outcome .. ")")
    end
end

-- ============================================================================
-- RECUPERAR MEMORIA
-- ============================================================================
function WCS_BrainMemory:Recall(mobName)
    return self.Encounters[mobName]
end

function WCS_BrainMemory:HasMemory(mobName)
    return self.Encounters[mobName] ~= nil
end

function WCS_BrainMemory:GetAllMemories()
    local memories = {}
    for name, data in pairs(self.Encounters) do
        table.insert(memories, data)
    end
    return memories
end

function WCS_BrainMemory:GetRecentMemories(count)
    count = count or 10
    local memories = self:GetAllMemories()
    
    -- Ordenar por última vez visto
    table.sort(memories, function(a, b)
        return a.lastSeen > b.lastSeen
    end)
    
    -- Retornar top N
    local result = {}
    for i = 1, count do
        if memories[i] then
            table.insert(result, memories[i])
        end
    end
    
    return result
end

function WCS_BrainMemory:GetDangerousMobs(count)
    count = count or 10
    local memories = self:GetAllMemories()
    
    -- Filtrar solo mobs con muertes
    local dangerous = {}
    for i = 1, table.getn(memories) do
        if memories[i].deaths > 0 then
            table.insert(dangerous, memories[i])
        end
    end
    
    -- Ordenar por ratio de muertes
    table.sort(dangerous, function(a, b)
        local ratioA = a.deaths / a.encounters
        local ratioB = b.deaths / b.encounters
        return ratioA > ratioB
    end)
    
    -- Retornar top N
    local result = {}
    for i = 1, count do
        if dangerous[i] then
            table.insert(result, dangerous[i])
        end
    end
    
    return result
end

-- ============================================================================
-- ANÁLISIS DE ROTACIONES
-- ============================================================================
function WCS_BrainMemory:UpdateBestRotation(memory, rotation, duration)
    if not rotation or table.getn(rotation) == 0 then return end
    
    -- Si no hay mejor rotación, usar esta
    if not memory.bestRotation or table.getn(memory.bestRotation) == 0 then
        memory.bestRotation = rotation
        memory.bestRotationTTK = duration
        return
    end
    
    -- Si esta rotación es más rápida, reemplazar
    if duration < memory.bestRotationTTK then
        memory.bestRotation = rotation
        memory.bestRotationTTK = duration
    end
end

function WCS_BrainMemory:GetBestRotation(mobName)
    local memory = self:Recall(mobName)
    if memory and memory.bestRotation then
        return memory.bestRotation
    end
    return nil
end

-- ============================================================================
-- CÁLCULO DE DIFICULTAD
-- ============================================================================
function WCS_BrainMemory:CalculateDifficulty(memory)
    if memory.encounters == 0 then return "Unknown" end
    
    local deathRate = memory.deaths / memory.encounters
    local avgTTK = memory.avgTTK
    
    -- Clasificación basada en muerte rate y TTK
    if deathRate >= 0.5 then
        return "Very Hard"
    elseif deathRate >= 0.25 then
        return "Hard"
    elseif avgTTK > 30 then
        return "Medium"
    elseif avgTTK > 15 then
        return "Easy"
    else
        return "Very Easy"
    end
end

function WCS_BrainMemory:GetDifficultyColor(difficulty)
    if difficulty == "Very Hard" then
        return "|cFFFF0000"  -- Rojo
    elseif difficulty == "Hard" then
        return "|cFFFF8800"  -- Naranja
    elseif difficulty == "Medium" then
        return "|cFFFFFF00"  -- Amarillo
    elseif difficulty == "Easy" then
        return "|cFF00FF00"  -- Verde
    elseif difficulty == "Very Easy" then
        return "|cFF00FFFF"  -- Cyan
    else
        return "|cFFFFFFFF"  -- Blanco
    end
end

-- ============================================================================
-- NOTAS Y ANOTACIONES
-- ============================================================================
function WCS_BrainMemory:AddNote(mobName, note)
    local memory = self:Recall(mobName)
    if memory then
        if memory.notes == "" then
            memory.notes = note
        else
            memory.notes = memory.notes .. "; " .. note
        end
        
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("Memory", "Nota agregada a " .. mobName)
        end
    end
end

function WCS_BrainMemory:ClearNotes(mobName)
    local memory = self:Recall(mobName)
    if memory then
        memory.notes = ""
    end
end

-- ============================================================================
-- GESTIÓN DE MEMORIA
-- ============================================================================
function WCS_BrainMemory:CheckMemoryLimit()
    local count = 0
    for _ in pairs(self.Encounters) do
        count = count + 1
    end
    
    if count > self.Config.maxEncounters then
        self:EvictOldest()
    end
end

function WCS_BrainMemory:EvictOldest()
    local oldest = nil
    local oldestTime = nil
    
    for name, memory in pairs(self.Encounters) do
        if not oldestTime or memory.lastSeen < oldestTime then
            oldest = name
            oldestTime = memory.lastSeen
        end
    end
    
    if oldest then
        self.Encounters[oldest] = nil
        if WCS_BrainLogger then
            WCS_BrainLogger:Debug("Memory", "Memoria más antigua eliminada: " .. oldest)
        end
    end
end

function WCS_BrainMemory:Clear()
    self.Encounters = {}
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Memory", "Todas las memorias borradas")
    end
end

function WCS_BrainMemory:Forget(mobName)
    if self.Encounters[mobName] then
        self.Encounters[mobName] = nil
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("Memory", "Memoria olvidada: " .. mobName)
        end
        return true
    end
    return false
end

-- ============================================================================
-- GUARDADO AUTOMÁTICO
-- ============================================================================
function WCS_BrainMemory:StartAutoSave()
    if not self.saveFrame then
        self.saveFrame = CreateFrame("Frame")
        self.saveFrame.elapsed = 0
        
        self.saveFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed >= WCS_BrainMemory.Config.saveInterval then
                this.elapsed = 0
                WCS_BrainMemory:Save()
            end
        end)
    end
end

function WCS_BrainMemory:Save()
    if not WCS_BrainSaved then
        WCS_BrainSaved = {}
    end
    
    WCS_BrainSaved.memory = self.Encounters
    
    if WCS_BrainLogger then
        local count = 0
        for _ in pairs(self.Encounters) do count = count + 1 end
        WCS_BrainLogger:Debug("Memory", "Memorias guardadas (" .. count .. " encuentros)")
    end
end

-- ============================================================================
-- EXPORTACIÓN
-- ============================================================================
function WCS_BrainMemory:ExportMemory(mobName)
    local memory = self:Recall(mobName)
    if not memory then return nil end
    
    local output = "Memory: " .. mobName .. "\n"
    output = output .. "Encounters: " .. memory.encounters .. "\n"
    output = output .. "Kills: " .. memory.kills .. " | Deaths: " .. memory.deaths .. "\n"
    output = output .. "Avg TTK: " .. string.format("%.1f", memory.avgTTK) .. "s\n"
    output = output .. "Avg DPS: " .. string.format("%.1f", memory.avgDPS) .. "\n"
    output = output .. "Difficulty: " .. memory.difficulty .. "\n"
    
    if memory.notes ~= "" then
        output = output .. "Notes: " .. memory.notes .. "\n"
    end
    
    return output
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSMEMORY1 = "/wcsmemory"
SLASH_WCSMEMORY2 = "/brainmemory"

SlashCmdList["WCSMEMORY"] = function(msg)
    local args = {}
    for word in string.gfind(msg, "%S+") do
        table.insert(args, word)
    end
    
    local cmd = args[1]
    
    if not cmd or cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmemory [mobname]|r - Ver memoria de un mob")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmemory list [count]|r - Listar memorias recientes")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmemory dangerous [count]|r - Mobs más peligrosos")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmemory forget [mobname]|r - Olvidar un mob")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmemory clear|r - Borrar todas las memorias")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/brainmemory save|r - Guardar memorias")
        return
    end
    
    if cmd == "list" then
        local count = tonumber(args[2]) or 10
        local memories = WCS_BrainMemory:GetRecentMemories(count)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Memorias recientes:")
        for i = 1, table.getn(memories) do
            local m = memories[i]
            local color = WCS_BrainMemory:GetDifficultyColor(m.difficulty)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s%s|r: %d/%d K/D, %.1fs TTK, %s",
                color, m.name, m.kills, m.deaths, m.avgTTK, m.difficulty))
        end
        
    elseif cmd == "dangerous" then
        local count = tonumber(args[2]) or 10
        local dangerous = WCS_BrainMemory:GetDangerousMobs(count)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Mobs más peligrosos:")
        for i = 1, table.getn(dangerous) do
            local m = dangerous[i]
            local deathRate = m.deaths / m.encounters * 100
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cFFFF0000%s|r: %.0f%% muerte rate (%d/%d)",
                m.name, deathRate, m.deaths, m.encounters))
        end
        
    elseif cmd == "forget" then
        local mobName = table.concat(args, " ", 2)
        if mobName and mobName ~= "" then
            if WCS_BrainMemory:Forget(mobName) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Memoria olvidada: " .. mobName)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r No hay memoria de: " .. mobName)
            end
        end
        
    elseif cmd == "clear" then
        WCS_BrainMemory:Clear()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Todas las memorias borradas")
        
    elseif cmd == "save" then
        WCS_BrainMemory:Save()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Memorias guardadas")
        
    else
        -- Buscar memoria por nombre
        local mobName = msg
        local memory = WCS_BrainMemory:Recall(mobName)
        
        if memory then
            local color = WCS_BrainMemory:GetDifficultyColor(memory.difficulty)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r Memoria: " .. color .. mobName .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("  Encuentros: " .. memory.encounters)
            DEFAULT_CHAT_FRAME:AddMessage("  Kills: " .. memory.kills .. " | Deaths: " .. memory.deaths)
            DEFAULT_CHAT_FRAME:AddMessage("  Avg TTK: " .. string.format("%.1f", memory.avgTTK) .. "s")
            DEFAULT_CHAT_FRAME:AddMessage("  Avg DPS: " .. string.format("%.1f", memory.avgDPS))
            DEFAULT_CHAT_FRAME:AddMessage("  Dificultad: " .. color .. memory.difficulty .. "|r")
            
            if memory.notes ~= "" then
                DEFAULT_CHAT_FRAME:AddMessage("  Notas: " .. memory.notes)
            end
            
            if memory.bestRotation and table.getn(memory.bestRotation) > 0 then
                local rotation = table.concat(memory.bestRotation, " -> ")
                DEFAULT_CHAT_FRAME:AddMessage("  Mejor rotación: " .. rotation)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r No hay memoria de: " .. mobName)
        end
    end
end

-- ============================================================================
-- TRACKING AUTOMÁTICO DE COMBATE
-- ============================================================================
WCS_BrainMemory.CurrentCombat = {
    active = false,
    targetName = nil,
    targetLevel = nil,
    targetType = nil,
    targetClassification = nil,
    startTime = 0,
    rotation = {}
}

function WCS_BrainMemory:StartCombatTracking()
    if self.CurrentCombat.active then return end
    
    local targetName = UnitName("target")
    if not targetName then return end
    
    self.CurrentCombat.active = true
    self.CurrentCombat.targetName = targetName
    self.CurrentCombat.targetLevel = UnitLevel("target") or 0
    self.CurrentCombat.targetType = UnitCreatureType("target") or "Unknown"
    self.CurrentCombat.targetClassification = UnitClassification("target") or "normal"
    self.CurrentCombat.startTime = GetTime()
    self.CurrentCombat.rotation = {}
end

function WCS_BrainMemory:EndCombatTracking(outcome)
    if not self.CurrentCombat.active then return end
    
    local duration = GetTime() - self.CurrentCombat.startTime
    local targetName = self.CurrentCombat.targetName
    
    local combatData = {
        duration = duration,
        damage = 0,
        rotation = self.CurrentCombat.rotation,
        level = self.CurrentCombat.targetLevel,
        type = self.CurrentCombat.targetType,
        classification = self.CurrentCombat.targetClassification
    }
    
    self:Remember(targetName, outcome, combatData)
    
    self.CurrentCombat.active = false
    self.CurrentCombat.targetName = nil
    self.CurrentCombat.rotation = {}
end

function WCS_BrainMemory:RecordSpellCast(spellName)
    if not self.CurrentCombat.active then return end
    if not spellName then return end
    
    table.insert(self.CurrentCombat.rotation, spellName)
    
    if table.getn(self.CurrentCombat.rotation) > 20 then
        table.remove(self.CurrentCombat.rotation, 1)
    end
end


-- ============================================================================
-- AUTO-INICIALIZACIÓN
-- ============================================================================
local function OnLoad()
    WCS_BrainMemory:Initialize()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Memory]|r v" .. WCS_BrainMemory.VERSION .. " - Sistema de recuerdos activo")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        OnLoad()
    elseif event == "PLAYER_LOGOUT" then
        WCS_BrainMemory:Save()
    elseif event == "PLAYER_REGEN_DISABLED" then
        WCS_BrainMemory:StartCombatTracking()
    elseif event == "PLAYER_REGEN_ENABLED" then
        WCS_BrainMemory:EndCombatTracking("kill")
    elseif event == "PLAYER_DEAD" then
        WCS_BrainMemory:EndCombatTracking("death")
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        local targetName = WCS_BrainMemory.CurrentCombat.targetName
        if targetName and arg1 and string.find(arg1, targetName) then
            WCS_BrainMemory:EndCombatTracking("kill")
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        if arg2 then
            WCS_BrainMemory:RecordSpellCast(arg2)
        end
    end
end)

