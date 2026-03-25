-- ============================================================================
-- WCS_BrainPetLearning.lua v6.4.2
-- Sistema de Aprendizaje Mejorado para Mascota
-- Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
-- ============================================================================

-- Este archivo mejora el sistema de aprendizaje de la mascota para:
-- 1. Aprender frases completas, no solo palabras
-- 2. Generar respuestas mas naturales combinando palabras aprendidas
-- 3. Recordar quien dijo que (contexto social)
-- 4. Aprender de TODOS los canales de chat

if not WCS_Brain then WCS_Brain = {} end
if not WCS_Brain.Pet then WCS_Brain.Pet = {} end
if not WCS_Brain.Pet.Social then WCS_Brain.Pet.Social = {} end

WCS_Brain.Pet.Learning = WCS_Brain.Pet.Learning or {}

-- ============================================================================
-- CONFIGURACION DE APRENDIZAJE
-- ============================================================================
WCS_Brain.Pet.Learning.Config = {
    enabled = true,
    learnPhrases = true,        -- Aprender frases completas
    learnFromAll = true,        -- Aprender de todos los canales
    maxPhrases = 100,           -- Maximo de frases guardadas
    minPhraseLength = 5,        -- Minimo de caracteres para guardar frase
    maxPhraseLength = 100,      -- Maximo de caracteres para guardar frase
    useLearnedInResponses = true, -- Usar frases aprendidas en respuestas
    learnedResponseChance = 40  -- % de usar respuesta aprendida
}

-- ============================================================================
-- ALMACENAMIENTO DE FRASES APRENDIDAS
-- ============================================================================
WCS_Brain.Pet.Learning.Phrases = WCS_Brain.Pet.Learning.Phrases or {}
WCS_Brain.Pet.Learning.SocialMemory = WCS_Brain.Pet.Learning.SocialMemory or {}

-- ============================================================================
-- PATRONES DE FRASES INTERESANTES
-- Frases que vale la pena aprender
-- ============================================================================
WCS_Brain.Pet.Learning.InterestingPatterns = {
    -- Expresiones comunes
    "jaja", "lol", "xd", "gg", "wp", "nice", "cool", "genial",
    -- Saludos
    "hola", "hey", "buenas", "saludos", "hi", "hello",
    -- Despedidas
    "adios", "bye", "chao", "nos vemos", "hasta luego",
    -- Emociones
    "me encanta", "odio", "amo", "quiero", "necesito",
    -- Exclamaciones
    "wow", "omg", "increible", "epico", "brutal"
}

-- ============================================================================
-- METODOS ENCAPSULADOS EN WCS_Brain.Pet.Learning
-- ============================================================================

function WCS_Brain.Pet.Learning:LearnPhrase(phrase, category, sender, channel)
    if not self.Config.enabled then return end
    if not self.Config.learnPhrases then return end
    if not phrase or phrase == "" then return end
    
    local cfg = self.Config
    
    -- Verificar longitud
    local len = string.len(phrase)
    if len < cfg.minPhraseLength or len > cfg.maxPhraseLength then
        return
    end
    
    -- FILTRO: Ignorar datos tecnicos (coordenadas, IDs de addons, etc)
    -- Prefijos de addons conocidos
    if string.find(phrase, "PWB_", 1, true) then return end
    if string.find(phrase, "DMF-", 1, true) then return end
    if string.find(phrase, "WCS_", 1, true) then return end
    if string.find(phrase, "pfQuest", 1, true) then return end
    if string.find(phrase, "ATW:", 1, true) then return end
    if string.find(phrase, "ATW", 1, true) then return end
    if string.find(phrase, "AtlasLoot", 1, true) then return end
    if string.find(phrase, "VERSION:", 1, true) then return end
    if string.find(phrase, "PizzaSlices", 1, true) then return end
    if string.find(phrase, "Slices:", 1, true) then return end
    if string.find(phrase, "ADDON", 1, true) then return end
    if string.find(phrase, "DBM", 1, true) then return end
    if string.find(phrase, "BigWigs", 1, true) then return end
    if string.find(phrase, "WeakAura", 1, true) then return end
    if string.find(phrase, "Questie", 1, true) then return end
    if string.find(phrase, "Recount", 1, true) then return end
    if string.find(phrase, "Details", 1, true) then return end
    if string.find(phrase, "ElvUI", 1, true) then return end
    if string.find(phrase, "TukUI", 1, true) then return end
    if string.find(phrase, "Omen", 1, true) then return end
    if string.find(phrase, "KTM", 1, true) then return end
    if string.find(phrase, "CT_", 1, true) then return end
    if string.find(phrase, "Auctioneer", 1, true) then return end
    
    -- FILTRO: Ignorar mensajes con corchetes (suelen ser addons)
    if string.find(phrase, "%[") and string.find(phrase, "%]") then return end
    
    -- FILTRO: Ignorar mensajes que empiezan con simbolos tecnicos
    local firstChar = string.sub(phrase, 1, 1)
    if firstChar == "|" or firstChar == "<" or firstChar == "{" or firstChar == ">" then return end
    
    -- FILTRO: Ignorar URLs
    if string.find(phrase, "http", 1, true) then return end
    if string.find(phrase, "www%.") then return end
    if string.find(phrase, "%.com", 1, true) then return end
    if string.find(phrase, "%.net", 1, true) then return end
    -- FILTRO: Ignorar spam de comercio
    local lowerPhrase = string.lower(phrase)
    if string.find(lowerPhrase, "compro", 1, true) then return end
    if string.find(lowerPhrase, "vendo", 1, true) then return end
    if string.find(lowerPhrase, "wtb", 1, true) then return end
    if string.find(lowerPhrase, "wts", 1, true) then return end
    if string.find(lowerPhrase, "selling", 1, true) then return end
    if string.find(lowerPhrase, "buying", 1, true) then return end
    if string.find(lowerPhrase, "lfg", 1, true) then return end
    if string.find(lowerPhrase, "lfm", 1, true) then return end
    if string.find(lowerPhrase, "%d+g") then return end  -- Precios como 10g, 100g
    if string.find(lowerPhrase, "%d+k") then return end  -- Precios como 1k, 10k
    if string.find(lowerPhrase, "gold", 1, true) then return end
    if string.find(lowerPhrase, "oro", 1, true) then return end
    -- Patrones de datos
    if string.find(phrase, "%d+:%d+:%d+") then return end
    if string.find(phrase, "%d+:%d+:v") then return end
    if string.find(phrase, "%d+%.%d+%.%d+") then return end
    if string.find(phrase, "%d+-%d+-%d+-%d+") then return end
    -- Ignorar si empieza con numero seguido de dos puntos (ID:algo)
    if string.find(phrase, "^%d+:") then return end
    -- Ignorar si mas del 40% son numeros
    local numCount = 0
    for i = 1, len do
        local c = string.sub(phrase, i, i)
        if c >= "0" and c <= "9" then numCount = numCount + 1 end
    end
    if numCount > (len * 0.3) then return end  -- Reducido de 40% a 30%
    
    -- Limpiar la frase (quitar espacios extra)
    phrase = string.gsub(phrase, "^%s+", "")
    phrase = string.gsub(phrase, "%s+$", "")
    phrase = string.gsub(phrase, "%s+", " ")
    
    -- Verificar si es interesante
    local isInteresting = false
    lowerPhrase = string.lower(phrase)
    
    for i = 1, WCS_TableCount(self.InterestingPatterns) do
        -- Usar plain=true (4to param) para busqueda literal sin patrones Lua
        if string.find(lowerPhrase, self.InterestingPatterns[i], 1, true) then
            isInteresting = true
            break
        end
    end
    
    -- Si no es interesante, solo 20% de probabilidad de aprender
    if not isInteresting and math.random(100) > 20 then
        return
    end
    
    -- Verificar si ya existe una frase similar
    for existingPhrase, data in pairs(self.Phrases) do
        if string.lower(existingPhrase) == lowerPhrase then
            -- Reforzar frase existente
            data.count = (data.count or 1) + 1
            data.lastUsed = GetTime()
            return
        end
    end
    
    -- Verificar espacio
    local phraseCount = 0
    for k, v in pairs(self.Phrases) do
        phraseCount = phraseCount + 1
    end
    
    if phraseCount >= cfg.maxPhrases then
        -- Eliminar frase menos usada
        self:CleanupPhrases()
    end
    
    -- Guardar nueva frase
    self.Phrases[phrase] = {
        category = category,
        sender = sender,
        channel = channel,
        count = 1,
        learned = GetTime(),
        lastUsed = GetTime()
    }
    
    -- Mostrar en modo verbose
    if WCS_Brain.Pet.Social.Config.verboseMode then
        local petName = UnitName("pet") or "Mascota"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00FF00[FRASE]|r " .. petName .. " aprendio: \"|cffFFD700" .. phrase .. "|r\"")
    end
end

function WCS_Brain.Pet.Learning:CleanupPhrases()
    local minCount = 999999
    local minPhrase = nil
    
    for phrase, data in pairs(self.Phrases) do
        local count = data.count or 1
        if count < minCount then
            minCount = count
            minPhrase = phrase
        end
    end
    
    if minPhrase then
        self.Phrases[minPhrase] = nil
    end
end

function WCS_Brain.Pet.Learning:GetLearnedPhrase(category)
    if not self.Config.useLearnedInResponses then
        return nil
    end
    
    -- Verificar probabilidad
    local chance = self.Config.learnedResponseChance or 40
    if math.random(100) > chance then
        return nil
    end
    
    -- Buscar frases de esta categoria
    local matchingPhrases = {}
    
    for phrase, data in pairs(self.Phrases) do
        if data.category == category then
            table.insert(matchingPhrases, phrase)
        end
    end
    
    -- Si no hay de esta categoria, buscar cualquiera
    if WCS_TableCount(matchingPhrases) == 0 then
        for phrase, data in pairs(self.Phrases) do
            -- Solo frases con mas de 1 uso
            if (data.count or 1) > 1 then
                table.insert(matchingPhrases, phrase)
            end
        end
    end
    
    if WCS_TableCount(matchingPhrases) == 0 then
        return nil
    end
    
    -- Seleccionar aleatoria
    local selected = matchingPhrases[math.random(WCS_TableCount(matchingPhrases))]
    
    -- Marcar como usada
    if self.Phrases[selected] then
        self.Phrases[selected].lastUsed = GetTime()
    end
    
    return selected
end

function WCS_Brain.Pet.Learning:GenerateCreativeResponse(category)
    local personality = "Protector"
    if WCS_Brain_Pet_GetPersonality then
        personality = WCS_Brain_Pet_GetPersonality()
    end
    
    -- Intentar obtener frase aprendida primero
    local learnedPhrase = self:GetLearnedPhrase(category)
    if learnedPhrase then
        -- Modificar segun personalidad
        local modifiedPhrase = self:ModifyByPersonality(learnedPhrase, personality)
        return modifiedPhrase
    end
    
    -- Si no hay frase aprendida, intentar combinar palabras
    local words = {}
    if WCS_Brain.Pet.Social.LearnedWords then
        for word, data in pairs(WCS_Brain.Pet.Social.LearnedWords) do
            if data.category == category and (data.count or 1) >= 2 then
                table.insert(words, word)
            end
        end
    end
    
    if WCS_TableCount(words) < 2 then
        return nil
    end
    
    -- Combinar 2-3 palabras
    local numWords = math.random(2, math.min(3, WCS_TableCount(words)))
    local selectedWords = {}
    
    for i = 1, numWords do
        local idx = math.random(WCS_TableCount(words))
        table.insert(selectedWords, words[idx])
        table.remove(words, idx)
        if WCS_TableCount(words) == 0 then break end
    end
    
    -- Crear frase segun personalidad
    local phrase = table.concat(selectedWords, " ")
    return self:ModifyByPersonality(phrase, personality)
end

function WCS_Brain.Pet.Learning:ModifyByPersonality(phrase, personality)
    if not phrase then return nil end
    
    local prefixes = {
        ["Timido"] = {"Um... ", "E-eh... ", "C-creo que... ", ""},
        ["Agresivo"] = {"JA! ", "OBVIAMENTE ", "", "SI! "},
        ["Protector"] = {"Entiendo, ", "Bien, ", "", "Companero, "},
        ["Sabio"] = {"Interesante... ", "Hmm, ", "Como dice el dicho: ", ""},
        ["Rebelde"] = {"Meh, ", "Como sea, ", "Pfff ", ""}
    }
    
    local suffixes = {
        ["Timido"] = {"...", " *tiembla*", "", " supongo..."},
        ["Agresivo"] = {"!!", " JAJA!", "!", " OBVIAMENTE!"},
        ["Protector"] = {".", ", companero.", "", "."},
        ["Sabio"] = {"...", ".", " ciertamente.", ""},
        ["Rebelde"] = {"...", " o lo que sea.", "", " *suspira*"}
    }
    
    local pref = prefixes[personality] or prefixes["Protector"]
    local suff = suffixes[personality] or suffixes["Protector"]
    
    local prefix = pref[math.random(WCS_TableCount(pref))]
    local suffix = suff[math.random(WCS_TableCount(suff))]
    
    return prefix .. phrase .. suffix
end

function WCS_Brain.Pet.Learning:RememberSender(sender, message, category)
    if not sender or sender == "" then return end
    
    local memory = self.SocialMemory
    
    if not memory[sender] then
        memory[sender] = {
            messages = 0,
            lastSeen = GetTime(),
            favoriteCategory = nil,
            categories = {}
        }
    end
    
    local senderData = memory[sender]
    senderData.messages = (senderData.messages or 0) + 1
    senderData.lastSeen = GetTime()
    
    if category then
        senderData.categories[category] = (senderData.categories[category] or 0) + 1
        
        -- Actualizar categoria favorita
        local maxCount = 0
        for cat, count in pairs(senderData.categories) do
            if count > maxCount then
                maxCount = count
                senderData.favoriteCategory = cat
            end
        end
    end
end

function WCS_Brain.Pet.Learning:GetPersonalizedResponse(sender, category)
    local memory = self.SocialMemory
    
    if not memory[sender] then
        return nil
    end
    
    local senderData = memory[sender]
    
    -- Si hemos visto a este jugador muchas veces, respuesta especial
    if senderData.messages >= 10 then
        local responses = {
            "Oh, " .. sender .. " otra vez!",
            "Hola " .. sender .. ", te recuerdo!",
            sender .. "! Mi amigo!",
            "Ah, " .. sender .. "..."
        }
        
            if math.random(100) <= 30 then
            return responses[math.random(WCS_TableCount(responses))]
        end
    end
    
    return nil
end

function WCS_Brain.Pet.Learning:SaveLearning()
    if not WCS_BrainSaved then WCS_BrainSaved = {} end
    if not WCS_BrainSaved.PetLearning then WCS_BrainSaved.PetLearning = {} end
    
    WCS_BrainSaved.PetLearning.Phrases = self.Phrases
    WCS_BrainSaved.PetLearning.SocialMemory = self.SocialMemory
end

function WCS_Brain.Pet.Learning:LoadLearning()
    if not WCS_BrainSaved then return end
    if not WCS_BrainSaved.PetLearning then return end
    
    if WCS_BrainSaved.PetLearning.Phrases then
        self.Phrases = WCS_BrainSaved.PetLearning.Phrases
        local count = 0
        for k, v in pairs(self.Phrases) do count = count + 1 end
        if count > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Cargadas " .. count .. " frases aprendidas")
        end
    end
    
    if WCS_BrainSaved.PetLearning.SocialMemory then
        self.SocialMemory = WCS_BrainSaved.PetLearning.SocialMemory
    end
end

-- ============================================================================
-- ALIASES GLOBALES PARA COMPATIBILIDAD (usan metodos del modulo)
-- ============================================================================
function WCS_Brain_Pet_LearnPhrase(phrase, category, sender, channel)
    return WCS_Brain.Pet.Learning:LearnPhrase(phrase, category, sender, channel)
end

function WCS_Brain_Pet_CleanupPhrases()
    return WCS_Brain.Pet.Learning:CleanupPhrases()
end

function WCS_Brain_Pet_GetLearnedPhrase(category)
    return WCS_Brain.Pet.Learning:GetLearnedPhrase(category)
end

function WCS_Brain_Pet_GenerateCreativeResponse(category)
    return WCS_Brain.Pet.Learning:GenerateCreativeResponse(category)
end

function WCS_Brain_Pet_ModifyByPersonality(phrase, personality)
    return WCS_Brain.Pet.Learning:ModifyByPersonality(phrase, personality)
end

function WCS_Brain_Pet_RememberSender(sender, message, category)
    return WCS_Brain.Pet.Learning:RememberSender(sender, message, category)
end

function WCS_Brain_Pet_GetPersonalizedResponse(sender, category)
    return WCS_Brain.Pet.Learning:GetPersonalizedResponse(sender, category)
end

function WCS_Brain_Pet_SaveLearning()
    return WCS_Brain.Pet.Learning:SaveLearning()
end

function WCS_Brain_Pet_LoadLearning()
    return WCS_Brain.Pet.Learning:LoadLearning()
end

-- ============================================================================
-- HOOK A LA FUNCION ORIGINAL DE PROCESAR MENSAJE
-- ============================================================================
local originalProcessMessage = WCS_Brain_Pet_ProcessMessage

WCS_Brain_Pet_ProcessMessage_Enhanced = function(message, sender, channel)
    -- Llamar funcion original si existe
    if originalProcessMessage then
        originalProcessMessage(message, sender, channel)
    end
    
    -- Aprendizaje mejorado
    if not WCS_Brain.Pet.Learning.Config.enabled then return end
    if not message or message == "" then return end
    
    -- Detectar categoria
    local category = nil
    if WCS_Brain_Pet_DetectCategory then
        category = WCS_Brain_Pet_DetectCategory(message)
    end
    
    -- Aprender frase completa
    WCS_Brain.Pet.Learning:LearnPhrase(message, category, sender, channel)
    
    -- Recordar al sender
    WCS_Brain.Pet.Learning:RememberSender(sender, message, category)
end

-- ============================================================================
-- SOBRESCRIBIR GetResponse PARA USAR APRENDIZAJE
-- ============================================================================
local originalGetResponse = WCS_Brain_Pet_GetResponse

WCS_Brain_Pet_GetResponse_Enhanced = function(situation)
    -- Primero intentar respuesta personalizada
    -- (esto requiere que tengamos el sender, que no siempre tenemos)
    
    -- Intentar generar respuesta creativa con palabras/frases aprendidas
    local creativeResponse = WCS_Brain.Pet.Learning:GenerateCreativeResponse(situation)
    if creativeResponse and math.random(100) <= 50 then
        if WCS_Brain.Pet.Social.Config.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00FF00[CREATIVO]|r Usando respuesta aprendida")
        end
        return creativeResponse
    end
    
    -- Si no, usar respuesta original
    if originalGetResponse then
        return originalGetResponse(situation)
    end
    
    return nil
end

-- Aplicar hooks
WCS_Brain_Pet_GetResponse = WCS_Brain_Pet_GetResponse_Enhanced

-- ============================================================================
-- FRAME PARA ESCUCHAR TODOS LOS CANALES Y APRENDER
-- ============================================================================
local WCS_LearningFrame = CreateFrame("Frame", "WCSBrainLearningFrame")

-- Registrar TODOS los eventos de chat
WCS_LearningFrame:RegisterEvent("CHAT_MSG_SAY")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_YELL")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_PARTY")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_RAID")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_GUILD")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_WHISPER")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_CHANNEL")
WCS_LearningFrame:RegisterEvent("CHAT_MSG_EMOTE")

WCS_LearningFrame:SetScript("OnEvent", function()
    if not WCS_Brain.Pet.Learning.Config.enabled then return end
    if not WCS_Brain.Pet.Learning.Config.learnFromAll then return end
    if not UnitExists("pet") then return end
    
    local message = arg1 or ""
    local sender = arg2 or ""
    local channel = event or ""
    
    -- Ignorar mensajes propios
    local playerName = UnitName("player") or ""
    if sender == playerName then return end
    
    -- Detectar categoria
    local category = nil
    if WCS_Brain_Pet_DetectCategory then
        category = WCS_Brain_Pet_DetectCategory(message)
    end
    
    -- Detectar emocion si no hay categoria
    if not category and WCS_Brain_Pet_DetectEmotion then
        category = WCS_Brain_Pet_DetectEmotion(message)
    end
    
    -- Aprender frase
    WCS_Brain.Pet.Learning:LearnPhrase(message, category, sender, channel)
    
    -- Recordar sender
    WCS_Brain.Pet.Learning:RememberSender(sender, message, category)
    
    -- Aprender palabras individuales tambien
    if WCS_Brain_Pet_LearnWord and category then
        for word in string.gfind(string.lower(message), "(%w+)") do
            if string.len(word) >= 3 then
                if math.random(100) <= 30 then
                    WCS_Brain_Pet_LearnWord(word, category, channel)
                end
            end
        end
    end
end)

-- ============================================================================
-- PERSISTENCIA DE FRASES APRENDIDAS
-- ============================================================================

-- Frame para guardar/cargar
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("ADDON_LOADED")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:RegisterEvent("PLAYER_LEAVING_WORLD")

saveFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_Brain.Pet.Learning:LoadLearning()
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        WCS_Brain.Pet.Learning:SaveLearning()
    end
end)

-- Auto-guardar cada 2 minutos
local autoSaveFrame = CreateFrame("Frame")
autoSaveFrame.elapsed = 0
autoSaveFrame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 120 then
        this.elapsed = 0
        WCS_Brain.Pet.Learning:SaveLearning()
    end
end)

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_PETLEARN1 = "/petlearn"
SlashCmdList["PETLEARN"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "on" then
        WCS_Brain.Pet.Learning.Config.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Aprendizaje |cff00ff00ACTIVADO|r")
        
    elseif cmd == "off" then
        WCS_Brain.Pet.Learning.Config.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Aprendizaje |cffff0000DESACTIVADO|r")
        
    elseif cmd == "phrases" then
        local count = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Frases Aprendidas ===")
        for phrase, data in pairs(WCS_Brain.Pet.Learning.Phrases) do
            count = count + 1
            if count <= 15 then
                local cat = data.category or "?"
                local uses = data.count or 1
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700\"" .. phrase .. "\"|r [" .. cat .. "] x" .. uses)
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Total: " .. count .. " frases")
        
    elseif cmd == "memory" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Memoria Social ===")
        local count = 0
        for sender, data in pairs(WCS_Brain.Pet.Learning.SocialMemory) do
            count = count + 1
            if count <= 10 then
                local msgs = data.messages or 0
                local fav = data.favoriteCategory or "?"
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00" .. sender .. "|r: " .. msgs .. " msgs, favorito: " .. fav)
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Total: " .. count .. " jugadores recordados")
        
    elseif cmd == "test" then
        local response = WCS_Brain.Pet.Learning:GenerateCreativeResponse("greetings")
        if response then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Respuesta generada: |cffFFD700" .. response .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r No hay suficientes datos para generar respuesta")
        end
        
    elseif cmd == "clear" then
        WCS_Brain.Pet.Learning.Phrases = {}
        WCS_Brain.Pet.Learning.SocialMemory = {}
        -- Limpiar tambien las palabras aprendidas del sistema social
        if WCS_Brain.Pet.Social and WCS_Brain.Pet.Social.LearnedWords then
            WCS_Brain.Pet.Social.LearnedWords = {}
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Memoria de aprendizaje borrada (frases, palabras y jugadores)")
        
    elseif cmd == "save" then
        WCS_Brain.Pet.Learning:SaveLearning()
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Aprendizaje guardado!")
        
    elseif cmd == "stats" then
        local phraseCount = 0
        local wordCount = 0
        local playerCount = 0
        
        for k, v in pairs(WCS_Brain.Pet.Learning.Phrases) do phraseCount = phraseCount + 1 end
        if WCS_Brain.Pet.Social.LearnedWords then
            for k, v in pairs(WCS_Brain.Pet.Social.LearnedWords) do wordCount = wordCount + 1 end
        end
        for k, v in pairs(WCS_Brain.Pet.Learning.SocialMemory) do playerCount = playerCount + 1 end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Estadisticas de Aprendizaje ===")
        DEFAULT_CHAT_FRAME:AddMessage("Frases aprendidas: |cffFFD700" .. phraseCount .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("Palabras aprendidas: |cffFFD700" .. wordCount .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("Jugadores recordados: |cffFFD700" .. playerCount .. "|r")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Comandos de Aprendizaje ===")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn on/off - Activar/desactivar")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn phrases - Ver frases aprendidas")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn memory - Ver memoria social")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn stats - Ver estadisticas")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn test - Probar respuesta generada")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn clear - Borrar memoria")
        DEFAULT_CHAT_FRAME:AddMessage("/petlearn save - Guardar manualmente")
    end
end

-- ============================================================================
-- INICIALIZACION
-- ============================================================================
DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r PetLearning v6.3.4 cargado - /petlearn para comandos")

