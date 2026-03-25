-- ============================================================================
-- WCS_BrainPetEmotions.lua v6.4.2
-- Sistema de Emociones y Canales de Chat Extendidos
-- Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
-- ============================================================================

-- Este archivo extiende el sistema social de la mascota para:
-- 1. Escuchar canales adicionales (World, Whisper, General, Trade, etc.)
-- 2. Expresar emociones a traves del personaje del jugador
-- 3. Reaccionar con emotes segun el contexto

if not WCS_Brain then WCS_Brain = {} end
if not WCS_Brain.Pet then WCS_Brain.Pet = {} end
if not WCS_Brain.Pet.Social then WCS_Brain.Pet.Social = {} end

WCS_Brain.Pet.Emotions = WCS_Brain.Pet.Emotions or {}

-- ============================================================================
-- CONFIGURACION DE EMOCIONES
-- ============================================================================
WCS_Brain.Pet.Emotions.Config = {
    enabled = true,
    emoteChance = 40,           -- % de probabilidad de hacer emote
    emoteCooldown = 30,         -- Segundos entre emotes
    lastEmoteTime = 0,
    listenWorld = true,         -- Escuchar canal de mundo
    listenWhisper = true,       -- Escuchar susurros
    listenGeneral = true,       -- Escuchar canal general
    listenTrade = true,         -- Escuchar canal de comercio
    listenLFG = true            -- Escuchar canal LFG
}

-- ============================================================================
-- MAPEO DE EMOCIONES A EMOTES
-- Cada categoria de mensaje puede triggear diferentes emotes
-- ============================================================================
WCS_Brain.Pet.Emotions.EmoteMap = {
    -- Categoria -> Lista de emotes posibles
    ["greetings"] = {"wave", "hello", "bow"},
    ["praise"] = {"cheer", "clap", "thank", "bow"},
    ["victory"] = {"cheer", "victory", "dance", "flex"},
    ["danger"] = {"cower", "gasp", "point"},
    ["affection"] = {"love", "hug", "kiss", "blush"},
    ["funny"] = {"laugh", "lol", "giggle", "rofl"},
    ["combat_start"] = {"charge", "roar", "flex"},
    ["low_health"] = {"cry", "plead", "beg"},
    ["sad"] = {"cry", "sigh", "mourn"},
    ["angry"] = {"angry", "threaten", "glare"},
    ["confused"] = {"shrug", "confused", "scratch"},
    ["excited"] = {"bounce", "cheer", "dance"}
}

-- ============================================================================
-- EMOTES POR PERSONALIDAD
-- Cada personalidad tiene preferencias de emotes
-- ============================================================================
WCS_Brain.Pet.Emotions.PersonalityEmotes = {
    ["Timido"] = {
        preferred = {"blush", "cower", "shy", "fidget"},
        avoided = {"roar", "flex", "charge", "threaten"}
    },
    ["Agresivo"] = {
        preferred = {"roar", "threaten", "flex", "charge", "angry"},
        avoided = {"cower", "cry", "blush", "shy"}
    },
    ["Protector"] = {
        preferred = {"salute", "bow", "nod", "point"},
        avoided = {"cower", "cry", "flee"}
    },
    ["Sabio"] = {
        preferred = {"bow", "nod", "think", "ponder"},
        avoided = {"rofl", "silly", "chicken"}
    },
    ["Rebelde"] = {
        preferred = {"shrug", "yawn", "bored", "sigh"},
        avoided = {"bow", "salute", "kneel"}
    }
}

-- ============================================================================
-- DETECCION DE EMOCIONES EN MENSAJES
-- ============================================================================
WCS_Brain.Pet.Emotions.EmotionPatterns = {
    -- Patrones para detectar emociones adicionales
    sad = {"triste", "sad", ":(", "llorar", "cry", "malo", "bad", "murio", "died", "rip"},
    angry = {"rabia", "angry", "odio", "hate", "maldito", "damn", "wtf", "idiota"},
    confused = {"que?", "what?", "como?", "how?", "???", "no entiendo", "confused"},
    excited = {"omg", "wow", "increible", "amazing", "epic", "legendary", "!!!"}
}

-- ============================================================================
-- FUNCION PARA DETECTAR EMOCION ADICIONAL
-- ============================================================================
function WCS_Brain.Pet.Emotions:DetectEmotion(message)
    local lowerMsg = string.lower(message)
    for emotion, patterns in pairs(self.EmotionPatterns) do
        for i = 1, WCS_TableCount(patterns) do
            if string.find(lowerMsg, patterns[i], 1, true) then
                return emotion
            end
        end
    end
    return nil
end
function WCS_Brain_Pet_DetectEmotion(message)
    return WCS_Brain.Pet.Emotions:DetectEmotion(message)
end

-- ============================================================================
-- FUNCION PARA EJECUTAR EMOTE
-- ============================================================================
function WCS_Brain.Pet.Emotions:DoEmote(category)
    if not self.Config.enabled then return end
    if not UnitExists("pet") then return end
    local now = GetTime()
    local lastEmote = self.Config.lastEmoteTime or 0
    local cooldown = self.Config.emoteCooldown or 30
    if (now - lastEmote) < cooldown then
        return
    end
    local chance = self.Config.emoteChance or 40
    if math.random(100) > chance then
        return
    end
    local emotes = self.EmoteMap[category]
    if not emotes or WCS_TableCount(emotes) == 0 then
        return
    end
    local personality = "Protector"
    if WCS_Brain_Pet_GetPersonality then
        personality = WCS_Brain_Pet_GetPersonality()
    end
    local persEmotes = self.PersonalityEmotes[personality]
    local filteredEmotes = {}
    for i = 1, WCS_TableCount(emotes) do
        local emote = emotes[i]
        local avoided = false
        if persEmotes and persEmotes.avoided then
            for j = 1, WCS_TableCount(persEmotes.avoided) do
                if emote == persEmotes.avoided[j] then
                    avoided = true
                    break
                end
            end
        end
        if not avoided then
            table.insert(filteredEmotes, emote)
        end
    end
    if WCS_TableCount(filteredEmotes) == 0 then
        filteredEmotes = emotes
    end
    local selectedEmote = filteredEmotes[math.random(WCS_TableCount(filteredEmotes))]
    DoEmote(string.upper(selectedEmote))
    self.Config.lastEmoteTime = now
    if WCS_Brain.Pet.Social.Config.verboseMode then
        local petName = UnitName("pet") or "Mascota"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cffFF69B4[EMOTE]|r " .. petName .. " hace que hagas: /" .. selectedEmote)
    end
end
function WCS_Brain_Pet_DoEmote(category)
    return WCS_Brain.Pet.Emotions:DoEmote(category)
end

-- ============================================================================
-- FUNCION MEJORADA DE SAY QUE INCLUYE EMOTES
-- ============================================================================
local originalPetSay = WCS_Brain_Pet_Say
    function WCS_Brain.Pet.Emotions:ProcessExtendedMessage(message, sender, channel)
        if not WCS_Brain.Pet.Social.Config.enabled then return end
        if not UnitExists("pet") then return end
        local petName = UnitName("pet") or "Mascota"
        local playerName = UnitName("player") or ""
        if sender == playerName then return end
        if string.find(message, petName) then return end
        local currentTime = GetTime()
        local cooldown = WCS_Brain.Pet.Social.Config.responseCooldown or 30
        if channel == "WORLD" or channel == "GENERAL" or channel == "TRADE" then
            cooldown = cooldown * 2
        end
        if currentTime - (WCS_Brain.Pet.Social.Config.lastResponse or 0) < cooldown then
            return
        end
        local category = nil
        if WCS_Brain_Pet_DetectCategory then
            category = WCS_Brain_Pet_DetectCategory(message)
        end
        local emotion = self:DetectEmotion(message)
        if emotion and not category then
            category = emotion
        end
        if not category then
            return
        end
        if WCS_Brain.Pet.Social.Config.verboseMode then
            local petName = UnitName("pet") or "Mascota"
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00ff00[ENTENDIDO]|r " .. petName .. " detecto: |cffFFD700" .. category .. "|r (canal: " .. channel .. ")")
        end
        local suggestedResponse = nil
        if WCS_Brain_Pet_GetResponse then
            suggestedResponse = WCS_Brain_Pet_GetResponse(category)
        end
        if suggestedResponse then
            WCS_Brain_Pet_Say_WithEmote(suggestedResponse, category)
        end
    end
    function WCS_Brain_Pet_ProcessExtendedMessage(message, sender, channel)
        return WCS_Brain.Pet.Emotions:ProcessExtendedMessage(message, sender, channel)
    end

WCS_Brain_Pet_Say_WithEmote = function(message, category)
    if not message then return end
    
    -- Llamar a la funcion original de Say
    if originalPetSay then
        originalPetSay(message)
    else
        local petName = UnitName("pet") or "Mascota"
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF8800[" .. petName .. "]|r " .. message)
        if WCS_Brain_Pet_ShowBubble then
            WCS_Brain_Pet_ShowBubble(message)
        end
    end
    
    -- Hacer emote si hay categoria
    if category then
        WCS_Brain_Pet_DoEmote(category)
    end
end

-- ============================================================================
-- FRAME EXTENDIDO PARA ESCUCHAR MAS CANALES DE CHAT
-- ============================================================================
local WCS_ExtendedChatFrame = CreateFrame("Frame", "WCSBrainExtendedChatFrame")

-- Registrar canales adicionales
WCS_ExtendedChatFrame:RegisterEvent("CHAT_MSG_WHISPER")           -- Susurros recibidos
WCS_ExtendedChatFrame:RegisterEvent("CHAT_MSG_CHANNEL")           -- Canales personalizados (World, General, Trade, LFG)
WCS_ExtendedChatFrame:RegisterEvent("CHAT_MSG_EMOTE")             -- Emotes de otros jugadores
WCS_ExtendedChatFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")        -- Emotes de texto

WCS_ExtendedChatFrame:SetScript("OnEvent", function()
    local message = arg1 or ""
    local sender = arg2 or ""
    local channelName = arg9 or ""  -- Nombre del canal para CHAT_MSG_CHANNEL
    
    -- Verificar configuracion
    local cfg = WCS_Brain.Pet.Emotions.Config
    
    if event == "CHAT_MSG_WHISPER" then
        if cfg.listenWhisper then
            WCS_Brain_Pet_ProcessExtendedMessage(message, sender, "WHISPER")
        end
        
    elseif event == "CHAT_MSG_CHANNEL" then
        -- Detectar tipo de canal
        local lowerChannel = string.lower(channelName or "")
        
        if string.find(lowerChannel, "world") or string.find(lowerChannel, "mundo") then
            if cfg.listenWorld then
                WCS_Brain_Pet_ProcessExtendedMessage(message, sender, "WORLD")
            end
        elseif string.find(lowerChannel, "general") then
            if cfg.listenGeneral then
                WCS_Brain_Pet_ProcessExtendedMessage(message, sender, "GENERAL")
            end
        elseif string.find(lowerChannel, "trade") or string.find(lowerChannel, "comercio") then
            if cfg.listenTrade then
                WCS_Brain_Pet_ProcessExtendedMessage(message, sender, "TRADE")
            end
        elseif string.find(lowerChannel, "lfg") or string.find(lowerChannel, "buscar") then
            if cfg.listenLFG then
                WCS_Brain_Pet_ProcessExtendedMessage(message, sender, "LFG")
            end
        else
            -- Otros canales
            if cfg.listenWorld then
                WCS_Brain_Pet_ProcessExtendedMessage(message, sender, "CHANNEL")
            end
        end
        
    elseif event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE" then
        -- Reaccionar a emotes de otros jugadores
        WCS_Brain_Pet_ReactToEmote(message, sender)
    end
end)

-- ============================================================================
-- PROCESAR MENSAJES DE CANALES EXTENDIDOS
-- ============================================================================
function WCS_Brain_Pet_ProcessExtendedMessage(message, sender, channel)
    if not WCS_Brain.Pet.Social.Config.enabled then return end
    if not UnitExists("pet") then return end
    
    local petName = UnitName("pet") or "Mascota"
    local playerName = UnitName("player") or ""
    
    -- Ignorar mensajes propios
    if sender == playerName then return end
    
    -- Ignorar mensajes que contienen nombre de mascota (anti-loop)
    if string.find(message, petName) then return end
    
    -- Cooldown de respuesta (mas largo para canales de mundo)
    local currentTime = GetTime()
    local cooldown = WCS_Brain.Pet.Social.Config.responseCooldown or 30
    
    -- Canales de mundo tienen cooldown mas largo
    if channel == "WORLD" or channel == "GENERAL" or channel == "TRADE" then
        cooldown = cooldown * 2  -- Doble cooldown para canales publicos
    end
    
    if currentTime - (WCS_Brain.Pet.Social.Config.lastResponse or 0) < cooldown then
        return
    end
    
    -- Detectar categoria del mensaje
    local category = nil
    if WCS_Brain_Pet_DetectCategory then
        category = WCS_Brain_Pet_DetectCategory(message)
    end
    
    -- Detectar emocion adicional
    local emotion = WCS_Brain_Pet_DetectEmotion(message)
    if emotion and not category then
        category = emotion
    end
    
    if not category then
        -- Para susurros, siempre reaccionar aunque no detecte categoria
        if channel == "WHISPER" then
            category = "greetings"
        else
            return
        end
    end
    
    -- Actualizar tiempo de respuesta
    WCS_Brain.Pet.Social.Config.lastResponse = currentTime
    
    -- Obtener respuesta
    local response = nil
    if WCS_Brain_Pet_GetResponse then
        response = WCS_Brain_Pet_GetResponse(category)
    end
    
    -- Para susurros, mostrar respuesta especial
    if channel == "WHISPER" and response then
        -- Mostrar que la mascota "escucho" el susurro
        if WCS_Brain.Pet.Social.Config.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cffFF69B4[WHISPER]|r " .. petName .. " escucho a " .. sender)
        end
        
        -- Decir respuesta y hacer emote
        WCS_Brain_Pet_Say_WithEmote(response, category)
    elseif response then
        -- Para otros canales, menor probabilidad de responder
        if math.random(100) <= 30 then  -- 30% de probabilidad
            WCS_Brain_Pet_Say_WithEmote(response, category)
        else
            -- Solo hacer emote sin hablar
            WCS_Brain_Pet_DoEmote(category)
        end
    end
    
    -- Aprender palabras del mensaje
    if WCS_Brain_Pet_LearnWord then
        for word in string.gfind(string.lower(message), "(%w+)") do
            if string.len(word) >= 3 then
                if math.random(100) <= 50 then  -- 50% probabilidad
                    WCS_Brain_Pet_LearnWord(word, category, channel)
                end
            end
        end
    end
end

-- ============================================================================
-- REACCIONAR A EMOTES DE OTROS JUGADORES
-- ============================================================================
function WCS_Brain_Pet_ReactToEmote(message, sender)
    if not WCS_Brain.Pet.Emotions.Config.enabled then return end
    if not UnitExists("pet") then return end
    
    local playerName = UnitName("player") or ""
    local petName = UnitName("pet") or "Mascota"
    
    -- Solo reaccionar si el emote es hacia nosotros
    if not string.find(message, playerName) and not string.find(message, petName) then
        return
    end
    
    -- Detectar tipo de emote recibido
    local lowerMsg = string.lower(message)
    local reactionCategory = nil
    
    if string.find(lowerMsg, "wave") or string.find(lowerMsg, "saluda") or string.find(lowerMsg, "hello") then
        reactionCategory = "greetings"
    elseif string.find(lowerMsg, "hug") or string.find(lowerMsg, "abraza") or string.find(lowerMsg, "love") then
        reactionCategory = "affection"
    elseif string.find(lowerMsg, "laugh") or string.find(lowerMsg, "rie") or string.find(lowerMsg, "lol") then
        reactionCategory = "funny"
    end
    -- Aquí puedes agregar más categorías y reacciones según sea necesario
    if reactionCategory then
        WCS_Brain_Pet_DoEmote(reactionCategory)
    end
end

-- ============================================================================
-- COMANDOS SLASH PARA EMOCIONES
-- ============================================================================
SLASH_PETEMOTE1 = "/petemote"
SlashCmdList["PETEMOTE"] = function(msg)
    local cmd = string.lower(msg or "")
    local cfg = WCS_Brain.Pet.Emotions.Config
    
    if cmd == "on" then
        cfg.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Emociones de mascota |cff00ff00ACTIVADAS|r")
        
    elseif cmd == "off" then
        cfg.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Emociones de mascota |cffff0000DESACTIVADAS|r")
        
    elseif cmd == "world" then
        cfg.listenWorld = not cfg.listenWorld
        local status = cfg.listenWorld and "ON" or "OFF"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Escuchar World: " .. status)
        
    elseif cmd == "whisper" then
        cfg.listenWhisper = not cfg.listenWhisper
        local status = cfg.listenWhisper and "ON" or "OFF"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Escuchar Whispers: " .. status)
        
    elseif cmd == "general" then
        cfg.listenGeneral = not cfg.listenGeneral
        local status = cfg.listenGeneral and "ON" or "OFF"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Escuchar General: " .. status)
        
    elseif cmd == "trade" then
        cfg.listenTrade = not cfg.listenTrade
        local status = cfg.listenTrade and "ON" or "OFF"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Escuchar Trade: " .. status)
        
    elseif cmd == "test" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Probando emociones...")
        WCS_Brain_Pet_DoEmote("victory")
        
    elseif cmd == "chance" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Probabilidad de emote: " .. cfg.emoteChance .. "%")
        
    elseif string.find(cmd, "chance ") then
        local value = tonumber(string.gsub(cmd, "chance ", ""))
        if value and value >= 0 and value <= 100 then
            cfg.emoteChance = value
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Probabilidad de emote: " .. value .. "%")
        end
        
    elseif cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Estado de Emociones ===")
        DEFAULT_CHAT_FRAME:AddMessage("Emociones: " .. (cfg.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage("Escuchar World: " .. (cfg.listenWorld and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage("Escuchar Whisper: " .. (cfg.listenWhisper and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage("Escuchar General: " .. (cfg.listenGeneral and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage("Escuchar Trade: " .. (cfg.listenTrade and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage("Probabilidad: " .. cfg.emoteChance .. "%")
        DEFAULT_CHAT_FRAME:AddMessage("Cooldown: " .. cfg.emoteCooldown .. "s")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Comandos de Emociones ===")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote on/off - Activar/desactivar")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote world - Toggle canal World")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote whisper - Toggle susurros")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote general - Toggle canal General")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote trade - Toggle canal Trade")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote chance [0-100] - Probabilidad de emote")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote test - Probar emote")
        DEFAULT_CHAT_FRAME:AddMessage("/petemote status - Ver estado")
    end
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r PetEmotions v6.3.4 cargado - /petemote para comandos")

