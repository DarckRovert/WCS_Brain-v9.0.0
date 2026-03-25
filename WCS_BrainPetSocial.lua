-- Global alias for compatibility (single definition)
function WCS_Brain_Pet_GetResponse(situation)
    return WCS_Brain.Pet.Social:GetResponse(situation)
end
-- ============================================================================
-- WCS_BrainPetSocial.lua v6.4.2
-- Sistema de Chat Social para Mascota - WCS_Brain
-- Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
-- ============================================================================

if not WCS_Brain then WCS_Brain = {} end
if not WCS_Brain.Pet then WCS_Brain.Pet = {} end
WCS_Brain.Pet.Social = {}

-- ============================================================================
-- CONFIGURACION DEL SISTEMA SOCIAL
-- ============================================================================
WCS_Brain.Pet.Social.Config = {
    enabled = true,
    learnFromChat = true,
    autoEmotes = true,
    showResponseButton = true,
    responseCooldown = 30,
    verboseMode = false,
    lastResponse = 0,
    lastSentMessage = nil
}

-- ============================================================================
-- MEMORIA DE PALABRAS APRENDIDAS
-- ============================================================================
WCS_Brain.Pet.Social.LearnedWords = {}
WCS_Brain.Pet.Social.MemoryConfig = {
    maxWords = 200,
    forgetThreshold = 3,
    forgetDays = 7,
    reinforceBonus = 2,
    lastCleanup = 0,
    cleanupInterval = 300,
    learnedThisSession = 0,
    maxLearnedPerSession = 150
}

-- ============================================================================
-- SISTEMA DE APRENDIZAJE AVANZADO v2.0
-- ============================================================================
WCS_Brain.Pet.Social.AdvancedMemory = {
    -- Frases completas aprendidas
    phrases = {},
    maxPhrases = 50,
    
    -- Asociaciones situacion-respuesta
    situationResponses = {},
    
    -- Feedback del jugador
    playerFeedback = {
        positive = {},  -- respuestas que gustaron
        negative = {}   -- respuestas ignoradas
    },
    
    -- Contexto de combate
    combatContext = {
        inCombat = false,
        lastCombatTime = 0,
        combatPhrases = {},
        idlePhrases = {}
    },
    
    -- Estadisticas de aprendizaje
    stats = {
        totalLearned = 0,
        phrasesUsed = 0,
        positiveReactions = 0,
        negativeReactions = 0
    }
}

-- ============================================================================
-- PATRONES A IGNORAR (spam, ventas, LFG)
-- ============================================================================
WCS_Brain.Pet.Social.IgnorePatterns = {
    "wtb", "wts", "selling", "buying", "compro", "vendo",
    "lfg", "lfm", "lf tank", "lf healer", "lf dps",
    "need", "looking for", "buscando",
    "gold", "oro", "price", "precio",
    "boost", "run", "carry"
}

-- ============================================================================
-- CATEGORIAS DE DETECCION
-- ============================================================================
WCS_Brain.Pet.Social.Categories = {
    greetings = {"hola", "hey", "hi", "saludos", "hello", "buenas", "ey"},
    praise = {"buen", "genial", "excelente", "bien hecho", "good", "nice", "gj", "wp", "gg", "crack", "pro"},
    victory = {"ganamos", "win", "victoria", "loot", "drop", "down", "muerto", "killed"},
    danger = {"cuidado", "watch", "careful", "boss", "add", "adds", "inc", "incoming", "run", "corre"},
    affection = {"te quiero", "love", "amor", "gracias", "thanks", "thx", "ty", "grax"},
    funny = {"jaja", "lol", "xd", "haha", "jeje", "rofl", "lmao", "xdd"}
}

-- ============================================================================
-- RESPUESTAS POR PERSONALIDAD Y SITUACION
-- ============================================================================
WCS_Brain.Pet.Social.Responses = {
    ["Timido"] = {
        greetings = {"H-hola...", "Um... hola", "Saludos..."},
        praise = {"G-gracias...", "No fue nada...", "Me sonrojo..."},
        victory = {"S-sobrevivimos!", "Que alivio...", "Menos mal..."},
        danger = {"T-tengo miedo!", "Cuidado!", "Ayuda!"},
        affection = {"Eres muy amable...", "Gracias...", "..."},
        funny = {"Jejeje...", "Que gracioso...", "..."},
        combat_start = {"T-ten cuidado...", "E-estare detras de ti...", "*tiembla*"},
        low_health = {"M-me duele...", "*llora*", "A-ayudame..."}
    },
    ["Agresivo"] = {
        greetings = {"QUE MIRAS?!", "Hmph!", "HABLA!"},
        praise = {"LO SE!", "SOY EL MEJOR!", "OBVIAMENTE!"},
        victory = {"DESTRUIDOS!", "JAJAJA!", "QUIEN SIGUE?!"},
        danger = {"VENGAN!", "LOS DESTROZARE!", "NO TENGO MIEDO!"},
        affection = {"Hmph... gracias", "No te acostumbres", "...bien"},
        funny = {"JAJAJA PATETICO!", "Buena esa!", "JAJA!"},
        combat_start = {"A DESTRUIRLOS!", "MUERAN!", "JAJAJA PELEA!"},
        low_health = {"ESTO NO ES NADA!", "*escupe sangre* MAS!", "NO ME RENDIRE!"}
    },
    ["Protector"] = {
        greetings = {"Saludos, aliado", "Bienvenido", "A tu servicio"},
        praise = {"Solo cumplo mi deber", "Gracias", "Por el equipo"},
        victory = {"Todos a salvo", "Mision cumplida", "Bien hecho equipo"},
        danger = {"CUIDADO!", "PROTEGETE!", "PELIGRO!"},
        affection = {"Siempre estare aqui", "Gracias companero", "Juntos somos fuertes"},
        funny = {"Jaja, buena", "Me alegra verte feliz", "Eso estuvo bien"},
        combat_start = {"Yo te protegere", "Quedate detras de mi", "Juntos somos fuertes"},
        low_health = {"Aun puedo pelear...", "No te preocupes por mi", "Sigo en pie"}
    },
    ["Sabio"] = {
        greetings = {"Saludos", "La paz sea contigo", "Bienvenido, amigo"},
        praise = {"La virtud es su recompensa", "Gracias", "Interesante"},
        victory = {"Como estaba previsto", "La estrategia funciono", "Excelente"},
        danger = {"Cautela", "Analicemos la situacion", "Paciencia"},
        affection = {"El vinculo nos fortalece", "Gracias", "Sabias palabras"},
        funny = {"Hmm, ingenioso", "Interesante humor", "Jaja, cierto"},
        combat_start = {"Analicemos la situacion", "Estrategia ante todo", "Interesante desafio"},
        low_health = {"Debo ser mas cuidadoso", "Una leccion aprendida", "El dolor es maestro"}
    },
    ["Rebelde"] = {
        greetings = {"Meh", "Si, hola", "Que quieres?"},
        praise = {"Como sea", "Ya lo sabia", "Obvio"},
        victory = {"Facil", "Aburrido", "Siguiente?"},
        danger = {"Pfff no es nada", "Relajate", "Ya veras"},
        affection = {"...supongo que gracias", "No te emociones", "Meh"},
        funny = {"Jaja ok esa estuvo buena", "Nada mal", "Pfff jaja"},
        combat_start = {"Ugh, otra pelea...", "Que fastidio", "*suspira* alla vamos"},
        low_health = {"Auch... eso dolio", "Maldicion", "*grune*"}
    }
}

-- ============================================================================
-- FUNCIONES DE PERSONALIDAD
-- ============================================================================
function WCS_Brain.Pet.Social:GetPersonality()
    if WCS_Brain.Pet.personality then
        return WCS_Brain.Pet.personality
    end
    return "Protector"
end
function WCS_Brain_Pet_GetPersonality()
    return WCS_Brain.Pet.Social:GetPersonality()
end

-- ============================================================================
-- SISTEMA DE BURBUJA DE CHAT MEJORADO v2.0
-- Simula las burbujas de chat de NPCs sobre la mascota
-- ============================================================================

-- Configuracion de burbuja
WCS_Brain.Pet.Social.Config.showBubble = true
WCS_Brain.Pet.Social.Config.bubbleDuration = 5
WCS_Brain.Pet.Social.Config.bubbleStyle = "warlock" -- "warlock", "classic", "minimal"
WCS_Brain.Pet.Social.Config.bubblePosition = "pet" -- "pet", "center", "top"
WCS_Brain.Pet.Social.Config.bubbleScale = 1.0
WCS_Brain.Pet.Social.Config.bubbleAnimations = true
WCS_Brain.Pet.Social.Config.bubbleTypewriter = true

-- Frame principal de la burbuja
local WCS_PetBubbleFrame = CreateFrame("Frame", "WCSBrainPetBubble", UIParent)
WCS_PetBubbleFrame:SetWidth(220)
WCS_PetBubbleFrame:SetHeight(80)
WCS_PetBubbleFrame:SetFrameStrata("DIALOG")
WCS_PetBubbleFrame:SetFrameLevel(100)
WCS_PetBubbleFrame:Hide()

-- Fondo con estilo de burbuja de chat (como los NPCs)
WCS_PetBubbleFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\ChatBubble-Background",
    edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 16, right = 16, top = 16, bottom = 16 }
})
WCS_PetBubbleFrame:SetBackdropColor(0.1, 0.0, 0.15, 0.95)
WCS_PetBubbleFrame:SetBackdropBorderColor(0.6, 0.3, 0.8, 1)

-- Icono de la mascota (esquina superior izquierda)
local petIcon = WCS_PetBubbleFrame:CreateTexture(nil, "ARTWORK")
petIcon:SetWidth(24)
petIcon:SetHeight(24)
petIcon:SetPoint("TOPLEFT", WCS_PetBubbleFrame, "TOPLEFT", 8, -8)
petIcon:SetTexture("Interface\\Icons\\Spell_Shadow_SummonVoidWalker")
WCS_PetBubbleFrame.petIcon = petIcon

-- Nombre de la mascota con color Warlock
local bubbleName = WCS_PetBubbleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bubbleName:SetPoint("TOPLEFT", petIcon, "TOPRIGHT", 5, -2)
bubbleName:SetTextColor(0.58, 0.51, 0.79, 1) -- Color Warlock
WCS_PetBubbleFrame.nameText = bubbleName

-- Indicador de personalidad
local personalityText = WCS_PetBubbleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
personalityText:SetPoint("LEFT", bubbleName, "RIGHT", 5, 0)
personalityText:SetTextColor(0.5, 0.5, 0.5, 1)
WCS_PetBubbleFrame.personalityText = personalityText

-- Texto del mensaje (mas grande y centrado)
local bubbleText = WCS_PetBubbleFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
bubbleText:SetPoint("TOP", WCS_PetBubbleFrame, "TOP", 0, -35)
bubbleText:SetPoint("LEFT", WCS_PetBubbleFrame, "LEFT", 12, 0)
bubbleText:SetPoint("RIGHT", WCS_PetBubbleFrame, "RIGHT", -12, 0)
bubbleText:SetJustifyH("CENTER")
bubbleText:SetJustifyV("TOP")
WCS_PetBubbleFrame.messageText = bubbleText

-- Triangulo/flecha apuntando hacia abajo (simula la cola de la burbuja)
local bubbleTail = WCS_PetBubbleFrame:CreateTexture(nil, "ARTWORK")
bubbleTail:SetWidth(16)
bubbleTail:SetHeight(16)
bubbleTail:SetPoint("TOP", WCS_PetBubbleFrame, "BOTTOM", 0, 8)
bubbleTail:SetTexture("Interface\\Tooltips\\ChatBubble-Tail")
WCS_PetBubbleFrame.tail = bubbleTail

-- Variables de animacion
WCS_PetBubbleFrame.hideTimer = 0
WCS_PetBubbleFrame.fadeAlpha = 1
WCS_PetBubbleFrame.animPhase = 0
WCS_PetBubbleFrame.typewriterIndex = 0
WCS_PetBubbleFrame.fullMessage = ""
WCS_PetBubbleFrame.typewriterSpeed = 0.03
WCS_PetBubbleFrame.typewriterTimer = 0

-- Iconos por tipo de mascota
local PET_ICONS = {
    ["imp"] = "Interface\\Icons\\Spell_Shadow_SummonImp",
    ["voidwalker"] = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
    ["succubus"] = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
    ["felhunter"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    ["felguard"] = "Interface\\Icons\\Spell_Shadow_SummonFelGuard",
    ["infernal"] = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
    ["doomguard"] = "Interface\\Icons\\Spell_Shadow_SummonDoomGuard",
    ["unknown"] = "Interface\\Icons\\INV_Misc_QuestionMark"
}

-- Colores por personalidad
local PERSONALITY_COLORS = {
    ["Timido"] = {0.6, 0.8, 1.0},
    ["Agresivo"] = {1.0, 0.3, 0.2},
    ["Protector"] = {0.3, 1.0, 0.5},
    ["Sabio"] = {1.0, 0.9, 0.5},
    ["Rebelde"] = {0.8, 0.5, 1.0}
}

-- Funcion para obtener el tipo de mascota
local function GetPetTypeForBubble()
    if not UnitExists("pet") then return "unknown" end
    if WCS_BrainPetAI and WCS_BrainPetAI.GetPetType then
        local ptype = WCS_BrainPetAI:GetPetType()
        if ptype then return string.lower(ptype) end
    end
    local petName = string.lower(UnitName("pet") or "")
    if string.find(petName, "imp") then return "imp" end
    if string.find(petName, "void") or string.find(petName, "abis") then return "voidwalker" end
    if string.find(petName, "succub") then return "succubus" end
    if string.find(petName, "felhunter") then return "felhunter" end
    return "unknown"
end

-- OnUpdate para animaciones y timer con throttling
WCS_PetBubbleFrame.elapsed = 0
WCS_PetBubbleFrame:SetScript("OnUpdate", function()
    local dt = arg1
    this.elapsed = this.elapsed + dt
    
    -- Throttling: actualizar solo cada 0.05s (20 FPS)
    if this.elapsed < 0.05 then return end
    this.elapsed = 0
    
    if not UnitExists("pet") then
        this:Hide()
        return
    end
    
    -- Efecto typewriter
    if WCS_Brain.Pet.Social.Config.bubbleTypewriter then
        if this.typewriterIndex < string.len(this.fullMessage) then
            this.typewriterTimer = (this.typewriterTimer or 0) + dt
            if this.typewriterTimer >= this.typewriterSpeed then
                this.typewriterTimer = 0
                this.typewriterIndex = this.typewriterIndex + 1
                local partialText = string.sub(this.fullMessage, 1, this.typewriterIndex)
                this.messageText:SetText(partialText)
            end
        end
    end
    
    -- Timer para ocultar con fade out
    if this.hideTimer > 0 then
        this.hideTimer = this.hideTimer - dt
        if this.hideTimer < 1 then
            this.fadeAlpha = this.hideTimer
            this:SetAlpha(this.fadeAlpha)
        end
        if this.hideTimer <= 0 then
            this:Hide()
            this:SetAlpha(1)
            return
        end
    end
    
    -- Animacion de brillo sutil (pulso)
    if WCS_Brain.Pet.Social.Config.bubbleAnimations then
        this.animPhase = (this.animPhase or 0) + dt * 2
        local pulse = 0.8 + 0.2 * math.sin(this.animPhase)
        this:SetBackdropBorderColor(0.6 * pulse, 0.3 * pulse, 0.8 * pulse, 1)
    end
end)

-- Funcion principal para mostrar la burbuja
function WCS_Brain.Pet.Social:ShowBubble(message)
    if not self.Config.showBubble then return end
    if not message then return end
    if not UnitExists("pet") then return end
    local petName = UnitName("pet") or "Mascota"
    local petType = GetPetTypeForBubble()
    local personality = self:GetPersonality()
    -- Configurar icono de mascota
    local iconPath = PET_ICONS[petType] or PET_ICONS["unknown"]
    WCS_PetBubbleFrame.petIcon:SetTexture(iconPath)
    -- Configurar nombre
    WCS_PetBubbleFrame.nameText:SetText(petName)
    -- Configurar indicador de personalidad
    local persColor = PERSONALITY_COLORS[personality] or {0.7, 0.7, 0.7}
    WCS_PetBubbleFrame.personalityText:SetText("[" .. personality .. "]")
    WCS_PetBubbleFrame.personalityText:SetTextColor(persColor[1], persColor[2], persColor[3], 0.8)
    -- Configurar mensaje
    WCS_PetBubbleFrame.fullMessage = message
    if self.Config.bubbleTypewriter then
        WCS_PetBubbleFrame.typewriterIndex = 0
        WCS_PetBubbleFrame.typewriterTimer = 0
        WCS_PetBubbleFrame.messageText:SetText("")
    else
        WCS_PetBubbleFrame.typewriterIndex = string.len(message)
        WCS_PetBubbleFrame.messageText:SetText(message)
    end
    -- Calcular altura necesaria (compatible con Lua 5.0)
    local msgLen = string.len(message)
    local linesEstimate = math.ceil(msgLen / 30)
    local textHeight = linesEstimate * 14
    local totalHeight = math.max(70, textHeight + 50)
    WCS_PetBubbleFrame:SetHeight(totalHeight)
    -- Posicionar la burbuja
    WCS_PetBubbleFrame:ClearAllPoints()
    local position = self.Config.bubblePosition
    if position == "pet" then
        if PetFrame and PetFrame:IsVisible() then
            WCS_PetBubbleFrame:SetPoint("BOTTOM", PetFrame, "TOP", 0, 15)
        else
            WCS_PetBubbleFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 80, 250)
        end
    elseif position == "center" then
        WCS_PetBubbleFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    elseif position == "top" then
        WCS_PetBubbleFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end
    -- Aplicar escala
    local scale = self.Config.bubbleScale or 1.0
    WCS_PetBubbleFrame:SetScale(scale)
    -- Resetear animaciones
    WCS_PetBubbleFrame.hideTimer = self.Config.bubbleDuration
    WCS_PetBubbleFrame.fadeAlpha = 1
    WCS_PetBubbleFrame.animPhase = 0
    WCS_PetBubbleFrame:SetAlpha(1)
    -- Mostrar
    WCS_PetBubbleFrame:Show()
end
function WCS_Brain_Pet_ShowBubble(message)
    return WCS_Brain.Pet.Social:ShowBubble(message)
end

function WCS_Brain.Pet.Social:HideBubble()
    WCS_PetBubbleFrame:Hide()
end
function WCS_Brain_Pet_HideBubble()
    return WCS_Brain.Pet.Social:HideBubble()
end

function WCS_Brain.Pet.Social:ConfigureBubble(option, value)
    if option == "position" then
        if value == "pet" or value == "center" or value == "top" then
            self.Config.bubblePosition = value
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Posicion de burbuja: " .. value)
        end
    elseif option == "scale" then
        local scale = tonumber(value)
        if scale and scale >= 0.5 and scale <= 2.0 then
            self.Config.bubbleScale = scale
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Escala de burbuja: " .. scale)
        end
    elseif option == "duration" then
        local dur = tonumber(value)
        if dur and dur >= 1 and dur <= 30 then
            self.Config.bubbleDuration = dur
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Duracion de burbuja: " .. dur .. "s")
        end
    elseif option == "animations" then
        self.Config.bubbleAnimations = not self.Config.bubbleAnimations
        local status = self.Config.bubbleAnimations and "ON" or "OFF"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Animaciones: " .. status)
    elseif option == "typewriter" then
        self.Config.bubbleTypewriter = not self.Config.bubbleTypewriter
        local status = self.Config.bubbleTypewriter and "ON" or "OFF"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Efecto typewriter: " .. status)
    end
end
function WCS_Brain_Pet_ConfigureBubble(option, value)
    return WCS_Brain.Pet.Social:ConfigureBubble(option, value)
end

function WCS_Brain.Pet.Social:Say(message)
    if not message then return end
    local petName = UnitName("pet") or "Mascota"
    -- Mostrar en chat
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF8800[" .. petName .. "]|r " .. message)
    -- Mostrar burbuja sobre la mascota
    self:ShowBubble(message)
end
function WCS_Brain_Pet_Say(message)
    return WCS_Brain.Pet.Social:Say(message)
end

function WCS_Brain.Pet.Social:GetResponse(situation)
    local personality = self:GetPersonality()
    local responses = self.Responses[personality]
    if not responses then
        responses = self.Responses["Protector"]
    end
    local situationResponses = responses[situation]
    if not situationResponses or WCS_TableCount(situationResponses) == 0 then
        return nil
    end
    -- 30% de probabilidad de usar palabra aprendida
    if math.random(100) <= 30 then
        local learnedResponse = self:GenerateLearnedResponse(situation)
        if learnedResponse then
            if self.Config.verboseMode then
                DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00ff00[USANDO PALABRA APRENDIDA]|r")
            end
            return learnedResponse
        end
    end
    return situationResponses[math.random(WCS_TableCount(situationResponses))]
end


-- ============================================================================
-- DETECCION DE CATEGORIA DE MENSAJE
-- ============================================================================
function WCS_Brain.Pet.Social:DetectCategory(message)
    local lowerMsg = string.lower(message)
    -- Verificar si es spam/ignorar
    for i = 1, WCS_TableCount(self.IgnorePatterns) do
        if string.find(lowerMsg, self.IgnorePatterns[i]) then
            return nil
        end
    end
    -- Detectar categoria
    for category, keywords in pairs(self.Categories) do
        for i = 1, WCS_TableCount(keywords) do
            if string.find(lowerMsg, keywords[i]) then
                return category
            end
        end
    end
    -- Verificar palabras aprendidas
    if self.LearnedWords then
        for word, data in pairs(self.LearnedWords) do
            if string.find(lowerMsg, word) then
                self:ReinforceWord(word)
                return data.category
            end
        end
    end
    return nil
end
function WCS_Brain_Pet_DetectCategory(message)
    return WCS_Brain.Pet.Social:DetectCategory(message)
end

-- ============================================================================
-- SISTEMA DE APRENDIZAJE
-- ============================================================================
function WCS_Brain.Pet.Social:LearnWord(word, category, context)
    if not self.Config.learnFromChat then return end
    if not word or word == "" then return end
    if string.len(word) < 3 then return end
    
    -- FILTRO: Ignorar si es solo numeros o tiene muchos numeros
    local numCount = 0
    local len = string.len(word)
    for i = 1, len do
        local c = string.sub(word, i, i)
        if c >= "0" and c <= "9" then numCount = numCount + 1 end
    end
    -- Si mas del 30% son numeros, ignorar
    if numCount > (len * 0.3) then return end
    -- Si es solo numeros, ignorar
    if numCount == len then return end
    
    local config = WCS_Brain.Pet.Social.MemoryConfig
    if config.learnedThisSession >= config.maxLearnedPerSession then
        return
    end
    
    -- Verificar si ya existe
    if WCS_Brain.Pet.Social.LearnedWords[word] then
        local wordData = WCS_Brain.Pet.Social.LearnedWords[word]
        wordData.count = (wordData.count or 0) + 1
        wordData.lastUsed = GetTime()
        return
    end
    
    -- Verificar espacio
    local wordCount = 0
    for k, v in pairs(WCS_Brain.Pet.Social.LearnedWords) do
        wordCount = wordCount + 1
    end
    
    if wordCount >= config.maxWords then
        WCS_Brain_Pet_CleanupMemory(true)
    end
    
    -- Aprender nueva palabra
    WCS_Brain.Pet.Social.LearnedWords[word] = {
        category = category,
        context = context,
        count = 1,
        learned = GetTime(),
        lastUsed = GetTime()
    }
    
    config.learnedThisSession = config.learnedThisSession + 1
    
    if WCS_Brain.Pet.Social.Config.verboseMode then
        local petName = UnitName("pet") or "Mascota"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00ffff[APRENDIDO]|r " .. petName .. " ahora conoce: '|cffFFD700" .. word .. "|r' = " .. category)
    end
end

function WCS_Brain.Pet.Social:ReinforceWord(word)
    if not self.LearnedWords[word] then return end
    local wordData = self.LearnedWords[word]
    wordData.count = (wordData.count or 0) + self.MemoryConfig.reinforceBonus
    wordData.lastUsed = GetTime()
end
function WCS_Brain_Pet_ReinforceWord(word)
    return WCS_Brain.Pet.Social:ReinforceWord(word)
end

-- Obtener una palabra aprendida aleatoria de una categoria
function WCS_Brain.Pet.Social:GetLearnedWord(category)
    local words = {}
    for word, data in pairs(self.LearnedWords) do
        if data.category == category and data.count >= 2 then
            table.insert(words, word)
        end
    end
    if WCS_TableCount(words) > 0 then
        return words[math.random(WCS_TableCount(words))]
    end
    return nil
end
function WCS_Brain_Pet_GetLearnedWord(category)
    return WCS_Brain.Pet.Social:GetLearnedWord(category)
end

-- Generar respuesta usando palabras aprendidas
function WCS_Brain.Pet.Social:GenerateLearnedResponse(category)
    local learnedWord = self:GetLearnedWord(category)
    if not learnedWord then return nil end
    local personality = self:GetPersonality()
    local templates = {
        ["Timido"] = {
            "Um... " .. learnedWord .. "...",
            "C-creo que " .. learnedWord .. "...",
            learnedWord .. "... si...",
        },
        ["Agresivo"] = {
            learnedWord .. "!!! JAJA!",
            "SI! " .. learnedWord .. "!",
            learnedWord .. " OBVIAMENTE!",
        },
        ["Protector"] = {
            "Entiendo, " .. learnedWord,
            learnedWord .. ", companero",
            "Bien dicho, " .. learnedWord,
        },
        ["Sabio"] = {
            "Interesante... " .. learnedWord,
            learnedWord .. ", como dice el proverbio",
            "Hmm, " .. learnedWord .. "...",
        },
        ["Jugueton"] = {
            learnedWord .. "! Jijiji!",
            "Ooooh " .. learnedWord .. "!",
            learnedWord .. " uwu",
        },
    }
    local t = templates[personality] or templates["Protector"]
    return t[math.random(WCS_TableCount(t))]
end
function WCS_Brain_Pet_GenerateLearnedResponse(category)
    return WCS_Brain.Pet.Social:GenerateLearnedResponse(category)
end

function WCS_Brain.Pet.Social:CleanupMemory(force)
    local config = self.MemoryConfig
    local currentTime = GetTime()
    if not force and (currentTime - config.lastCleanup) < config.cleanupInterval then
        return
    end
    config.lastCleanup = currentTime
    local forgottenWords = {}
    local secondsPerDay = 86400
    local forgetAfter = config.forgetDays * secondsPerDay
    for word, data in pairs(self.LearnedWords) do
        local lastUsed = data.lastUsed or data.learned or 0
        local timeSinceUse = currentTime - lastUsed
        local count = data.count or 1
        if count < config.forgetThreshold and timeSinceUse > forgetAfter then
            table.insert(forgottenWords, word)
        end
    end
    for i = 1, WCS_TableCount(forgottenWords) do
        self.LearnedWords[forgottenWords[i]] = nil
    end
end
function WCS_Brain_Pet_CleanupMemory(force)
    return WCS_Brain.Pet.Social:CleanupMemory(force)
end

-- ============================================================================
-- FRAME DE RESPUESTA (Boton para responder)
-- ============================================================================
local WCS_ResponseFrame = CreateFrame("Frame", "WCSBrainResponseFrame", UIParent)
WCS_ResponseFrame:SetWidth(280)
WCS_ResponseFrame:SetHeight(80)
WCS_ResponseFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
WCS_ResponseFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
WCS_ResponseFrame:SetMovable(true)
WCS_ResponseFrame:EnableMouse(true)
WCS_ResponseFrame:RegisterForDrag("LeftButton")
WCS_ResponseFrame:SetScript("OnDragStart", function() this:StartMoving() end)
WCS_ResponseFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
WCS_ResponseFrame:Hide()

-- Titulo
local titleText = WCS_ResponseFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleText:SetPoint("TOP", WCS_ResponseFrame, "TOP", 0, -8)
titleText:SetText("|cff9370DB[WCS] Tu mascota quiere decir:|r")

-- Texto de respuesta
local responseText = WCS_ResponseFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
responseText:SetPoint("TOP", titleText, "BOTTOM", 0, -4)
responseText:SetWidth(260)
responseText:SetJustifyH("CENTER")
WCS_ResponseFrame.responseText = responseText
WCS_ResponseFrame.pendingResponse = nil

-- Boton Say
local sendSayBtn = CreateFrame("Button", "WCSBrainSendSayBtn", WCS_ResponseFrame, "UIPanelButtonTemplate")
sendSayBtn:SetWidth(60)
sendSayBtn:SetHeight(22)
sendSayBtn:SetPoint("BOTTOMLEFT", WCS_ResponseFrame, "BOTTOMLEFT", 5, 8)
sendSayBtn:SetText("/say")
sendSayBtn:SetScript("OnClick", function()
    if WCS_ResponseFrame.pendingResponse then
        SendChatMessage(WCS_ResponseFrame.pendingResponse, "SAY")
        WCS_ResponseFrame:Hide()
        WCS_ResponseFrame.pendingResponse = nil
    end
end)

-- Boton Party
local sendPartyBtn = CreateFrame("Button", "WCSBrainSendPartyBtn", WCS_ResponseFrame, "UIPanelButtonTemplate")
sendPartyBtn:SetWidth(60)
sendPartyBtn:SetHeight(22)
sendPartyBtn:SetPoint("LEFT", sendSayBtn, "RIGHT", 3, 0)
sendPartyBtn:SetText("/party")
sendPartyBtn:SetScript("OnClick", function()
    if WCS_ResponseFrame.pendingResponse then
        SendChatMessage(WCS_ResponseFrame.pendingResponse, "PARTY")
        WCS_ResponseFrame:Hide()
        WCS_ResponseFrame.pendingResponse = nil
    end
end)

-- Boton Guild
local sendGuildBtn = CreateFrame("Button", "WCSBrainSendGuildBtn", WCS_ResponseFrame, "UIPanelButtonTemplate")
sendGuildBtn:SetWidth(60)
sendGuildBtn:SetHeight(22)
sendGuildBtn:SetPoint("LEFT", sendPartyBtn, "RIGHT", 3, 0)
sendGuildBtn:SetText("/guild")
sendGuildBtn:SetScript("OnClick", function()
    if WCS_ResponseFrame.pendingResponse then
        SendChatMessage(WCS_ResponseFrame.pendingResponse, "GUILD")
        WCS_ResponseFrame:Hide()
        WCS_ResponseFrame.pendingResponse = nil
    end
end)

-- Boton Ignorar
local ignoreBtn = CreateFrame("Button", "WCSBrainIgnoreBtn", WCS_ResponseFrame, "UIPanelButtonTemplate")
ignoreBtn:SetWidth(60)
ignoreBtn:SetHeight(22)
ignoreBtn:SetPoint("LEFT", sendGuildBtn, "RIGHT", 3, 0)
ignoreBtn:SetText("X")
ignoreBtn:SetScript("OnClick", function()
    WCS_ResponseFrame:Hide()
    WCS_ResponseFrame.pendingResponse = nil
end)

function WCS_Brain.Pet.Social:ShowResponseFrame(response)
    if not self.Config.showResponseButton then return end
    if not response then return end
    local petName = UnitName("pet") or "Mascota"
    WCS_ResponseFrame.responseText:SetText('"' .. response .. '"')
    WCS_ResponseFrame.pendingResponse = petName .. ": " .. response
    self.Config.lastSentMessage = response
    WCS_ResponseFrame:Show()
    -- Auto-ocultar despues de 10 segundos
    WCS_ResponseFrame.hideTimer = 10
    WCS_ResponseFrame:SetScript("OnUpdate", function()
        this.hideTimer = this.hideTimer - arg1
        if this.hideTimer <= 0 then
            this:Hide()
            this:SetScript("OnUpdate", nil)
            WCS_ResponseFrame.pendingResponse = nil
        end
    end)
end
function WCS_Brain_Pet_ShowResponseFrame()
    return WCS_Brain.Pet.Social:ShowResponseFrame()
end

-- ============================================================================
-- PROCESAMIENTO DE MENSAJES DE CHAT
-- ============================================================================
function WCS_Brain.Pet.Social:ProcessMessage(message, sender, channel)
    if not self.Config.enabled then return end
    if not UnitExists("pet") then return end
    local petName = UnitName("pet") or "Mascota"
    local playerName = UnitName("player") or ""
    local isFromPlayer = (sender == playerName)
    -- Anti-bucle: Ignorar mensajes que contienen nombre de mascota
    if string.find(message, petName) then return end
    -- Ignorar si es mensaje reciente nuestro
    if self.Config.lastSentMessage then
        if string.find(message, self.Config.lastSentMessage) then
            return
        end
    end
    -- Cooldown de respuesta
    local currentTime = GetTime()
    if not isFromPlayer then
        if currentTime - self.Config.lastResponse < self.Config.responseCooldown then
            return
        end
    end
    -- Detectar categoria
    local category = self:DetectCategory(message)
    if not category then
        if isFromPlayer and self.Config.verboseMode then
            local reactions = {
                petName .. " te mira con curiosidad",
                petName .. " ladea la cabeza sin entender",
                petName .. " escucha atentamente"
            }
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff888888[?]|r " .. reactions[math.random(WCS_TableCount(reactions))])
        end
        return
    end
    -- Actualizar tiempo de respuesta
    self.Config.lastResponse = currentTime
    -- Mostrar que entendio (si verbose)
    if self.Config.verboseMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00ff00[ENTENDIDO]|r " .. petName .. " detecto: |cffFFD700" .. category .. "|r")
    end
    -- Obtener y mostrar respuesta
    local suggestedResponse = self:GetResponse(category)
    self:ShowResponseFrame(suggestedResponse)
    -- Aprender palabras del mensaje (SIEMPRE aprende de cualquier categoria)
    for word in string.gfind(string.lower(message), "(%w+)") do
        if string.len(word) >= 3 then
            -- 70% probabilidad de aprender
            if math.random(100) <= 70 then
                self:LearnWord(word, category, channel)
            end
        end
    end
    -- Mensaje de aprendizaje visible
    if self.Config.verboseMode then
        local petName = UnitName("pet") or "Mascota"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r |cff00ffff[APRENDIENDO]|r " .. petName .. " escucha y aprende del chat...")
    end
end
function WCS_Brain_Pet_ProcessMessage(message, sender, channel)
    return WCS_Brain.Pet.Social:ProcessMessage(message, sender, channel)
end

-- ============================================================================
-- FRAME PARA ESCUCHAR CHAT
-- ============================================================================
local WCS_SocialChatFrame = CreateFrame("Frame", "WCSBrainSocialChatFrame")
WCS_SocialChatFrame:RegisterEvent("CHAT_MSG_PARTY")
WCS_SocialChatFrame:RegisterEvent("CHAT_MSG_RAID")
WCS_SocialChatFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
WCS_SocialChatFrame:RegisterEvent("CHAT_MSG_GUILD")
WCS_SocialChatFrame:RegisterEvent("CHAT_MSG_SAY")
WCS_SocialChatFrame:RegisterEvent("CHAT_MSG_YELL")
WCS_SocialChatFrame:SetScript("OnEvent", function()
    local message = arg1 or ""
    local sender = arg2 or ""
    local channel = event or ""
    
    local chatChannel = "PARTY"
    if string.find(channel, "GUILD") then
        chatChannel = "GUILD"
    elseif string.find(channel, "RAID") then
        chatChannel = "RAID"
    elseif string.find(channel, "SAY") then
        chatChannel = "SAY"
    elseif string.find(channel, "YELL") then
        chatChannel = "YELL"
    end
    
    WCS_Brain_Pet_ProcessMessage(message, sender, chatChannel)
end)

-- ============================================================================
-- EVENTOS DE COMBATE
-- ============================================================================
local petCombatFrame = CreateFrame("Frame", "WCSBrainPetCombatFrame")
petCombatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
petCombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
petCombatFrame:RegisterEvent("UNIT_HEALTH")

petCombatFrame:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
        if math.random(100) <= 40 then
            local response = WCS_Brain_Pet_GetResponse("combat_start")
            if response then WCS_Brain_Pet_Say(response) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if math.random(100) <= 50 then
            local response = WCS_Brain_Pet_GetResponse("victory")
            if response then WCS_Brain_Pet_Say(response) end
        end
    elseif event == "UNIT_HEALTH" then
        if arg1 == "pet" then
            local health = UnitHealth("pet") / UnitHealthMax("pet") * 100
            if health < 20 and math.random(100) <= 30 then
                local response = WCS_Brain_Pet_GetResponse("low_health")
                if response then WCS_Brain_Pet_Say(response) end
            end
        end
    end
end)

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSPET1 = "/wcspet"
SlashCmdList["WCSPET"] = function(msg)
    local petName = UnitName("pet") or "Sin mascota"
    local personality = WCS_Brain_Pet_GetPersonality()
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS Brain]|r Mascota: " .. petName)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS Brain]|r Personalidad: " .. personality)
end

SLASH_WCSSOCIAL1 = "/wcssocial"
SlashCmdList["WCSSOCIAL"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "on" then
        WCS_Brain.Pet.Social.Config.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Chat social ACTIVADO")
    elseif cmd == "off" then
        WCS_Brain.Pet.Social.Config.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Chat social DESACTIVADO")
    elseif cmd == "button" then
        WCS_Brain.Pet.Social.Config.showResponseButton = not WCS_Brain.Pet.Social.Config.showResponseButton
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Boton toggled")
    elseif cmd == "verbose" then
        WCS_Brain.Pet.Social.Config.verboseMode = not WCS_Brain.Pet.Social.Config.verboseMode
        if WCS_Brain.Pet.Social.Config.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Modo Verbose |cff00ff00ACTIVADO|r - Veras cuando la mascota aprende palabras")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Modo Verbose |cffff0000DESACTIVADO|r")
        end
    elseif cmd == "bubble" then
        WCS_Brain.Pet.Social.Config.showBubble = not WCS_Brain.Pet.Social.Config.showBubble
        if WCS_Brain.Pet.Social.Config.showBubble then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Burbuja de chat |cff00ff00ACTIVADA|r - La mascota mostrara burbujas al hablar")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Burbuja de chat |cffff0000DESACTIVADA|r")
        end
    elseif cmd == "test" then
        WCS_Brain_Pet_ProcessMessage("Buen trabajo equipo gg", "Test", "PARTY")
    elseif cmd == "words" then
        local count = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Palabras aprendidas:")
        for word, data in pairs(WCS_Brain.Pet.Social.LearnedWords) do
            count = count + 1
            if count <= 20 then
                DEFAULT_CHAT_FRAME:AddMessage("  |cffFFD700" .. word .. "|r = " .. (data.category or "?") .. " (x" .. (data.count or 1) .. ")")
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Total: " .. count .. " palabras")
    elseif cmd == "save" then
        WCS_Brain_Pet_SaveLearnedWords()
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Palabras guardadas!")
    elseif cmd == "reset" then
        WCS_Brain.Pet.Social.LearnedWords = {}
        WCS_Brain_Pet_SaveLearnedWords()
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Palabras reseteadas!")
    elseif cmd == "stats" then
        local count = 0
        local categories = {}
        for word, data in pairs(WCS_Brain.Pet.Social.LearnedWords) do
            count = count + 1
            local cat = data.category or "unknown"
            categories[cat] = (categories[cat] or 0) + 1
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Estadisticas de Aprendizaje ===")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Total palabras: |cffFFD700" .. count .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Por categoria:")
        for cat, num in pairs(categories) do
            DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00" .. cat .. "|r: " .. num)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Aprendidas esta sesion: " .. WCS_Brain.Pet.Social.MemoryConfig.learnedThisSession)
    elseif cmd == "learn" then
        WCS_Brain_Pet_LearnWord("prueba", "praise", "TEST")
        WCS_Brain_Pet_LearnWord("genial", "praise", "TEST")
        WCS_Brain_Pet_LearnWord("victoria", "victory", "TEST")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Palabras de prueba aprendidas!")
    -- Comandos de configuracion de burbuja
    elseif string.find(cmd, "^bubble pos") then
        local pos = string.gsub(cmd, "bubble pos%s*", "")
        WCS_Brain_Pet_ConfigureBubble("position", pos)
    elseif string.find(cmd, "^bubble scale") then
        local scale = string.gsub(cmd, "bubble scale%s*", "")
        WCS_Brain_Pet_ConfigureBubble("scale", scale)
    elseif string.find(cmd, "^bubble dur") then
        local dur = string.gsub(cmd, "bubble dur%s*", "")
        WCS_Brain_Pet_ConfigureBubble("duration", dur)
    elseif cmd == "bubble anim" then
        WCS_Brain_Pet_ConfigureBubble("animations")
    elseif cmd == "bubble type" then
        WCS_Brain_Pet_ConfigureBubble("typewriter")
    elseif cmd == "bubble test" then
        WCS_Brain_Pet_Say("Esta es una prueba del sistema de burbuja mejorado!")
    elseif cmd == "bubble help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Comandos de Burbuja ===")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble - Toggle on/off")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble pos [pet/center/top]")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble scale [0.5-2.0]")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble dur [1-30]")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble anim - Toggle animaciones")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble type - Toggle typewriter")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble test - Probar burbuja")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r === Comandos Disponibles ===")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial on/off - Activar/desactivar")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble - Toggle burbuja")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial bubble help - Opciones de burbuja")
        DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r /wcssocial verbose/button/test/words/save/reset/stats/learn")
    end
end

SLASH_PETTALK1 = "/pettalk"
SlashCmdList["PETTALK"] = function(msg)
    local response = WCS_Brain_Pet_GetResponse("greetings")
    if response then WCS_Brain_Pet_Say(response) end
end

-- ============================================================================
-- PERSISTENCIA DE PALABRAS APRENDIDAS
-- ============================================================================
function WCS_Brain_Pet_LoadLearnedWords()
    if not WCS_BrainSaved then WCS_BrainSaved = {} end
    if not WCS_BrainSaved.PetSocial then WCS_BrainSaved.PetSocial = {} end
    if WCS_BrainSaved.PetSocial.LearnedWords then
        WCS_Brain.Pet.Social.LearnedWords = WCS_BrainSaved.PetSocial.LearnedWords
        local count = 0
        for k, v in pairs(WCS_Brain.Pet.Social.LearnedWords) do count = count + 1 end
        if count > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS]|r Cargadas " .. count .. " palabras aprendidas")
        end
    end
    if WCS_BrainSaved.PetSocial.Personality then
        WCS_Brain.Pet.personality = WCS_BrainSaved.PetSocial.Personality
    end
end

function WCS_Brain_Pet_SaveLearnedWords()
    if not WCS_BrainSaved then WCS_BrainSaved = {} end
    if not WCS_BrainSaved.PetSocial then WCS_BrainSaved.PetSocial = {} end
    WCS_BrainSaved.PetSocial.LearnedWords = WCS_Brain.Pet.Social.LearnedWords
    WCS_BrainSaved.PetSocial.Personality = WCS_Brain.Pet.personality
end

-- Frame para cargar/guardar
local WCS_PetSocialSaveFrame = CreateFrame("Frame", "WCSBrainPetSocialSaveFrame")
WCS_PetSocialSaveFrame:RegisterEvent("ADDON_LOADED")
WCS_PetSocialSaveFrame:RegisterEvent("PLAYER_LOGOUT")
WCS_PetSocialSaveFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
WCS_PetSocialSaveFrame.saveTimer = 0
WCS_PetSocialSaveFrame.saveInterval = 60

WCS_PetSocialSaveFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == "WCS_Brain" then
            WCS_Brain_Pet_LoadLearnedWords()
        end
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        WCS_Brain_Pet_SaveLearnedWords()
    end
end)

WCS_PetSocialSaveFrame:SetScript("OnUpdate", function()
    this.saveTimer = this.saveTimer + arg1
    if this.saveTimer >= this.saveInterval then
        this.saveTimer = 0
        WCS_Brain_Pet_SaveLearnedWords()
    end
end)

DEFAULT_CHAT_FRAME:AddMessage("|cff9370DB[WCS Brain]|r PetSocial v6.3.4 cargado - Burbuja mejorada! /wcssocial bubble help")

