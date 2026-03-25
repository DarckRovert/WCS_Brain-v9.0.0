--[[
    WCS_BrainTutorial.lua - Tutorial Interactivo v6.5.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Tutorial paso a paso para nuevos usuarios
    
    Autor: Elnazzareno (DarckRovert)
]]--

WCS_BrainTutorial = WCS_BrainTutorial or {}
WCS_BrainTutorial.VERSION = "6.5.0"
WCS_BrainTutorial.active = false
WCS_BrainTutorial.currentStep = 1

-- ============================================================================
-- PASOS DEL TUTORIAL
-- ============================================================================
WCS_BrainTutorial.Steps = {
    {
        title = "Bienvenido a WCS Brain!",
        text = "¡Bienvenido! Soy tu asistente de IA para Warlock. Voy a enseñarte cómo usarme.",
        action = "none"
    },
    {
        title = "Comandos Básicos",
        text = "Puedes usar /brain para ver todos mis comandos. Prueba escribir /brain help ahora.",
        action = "wait_command",
        command = "/brain"
    },
    {
        title = "Sistema de Sugerencias",
        text = "Cuando estés en combate, te sugeriré qué hechizos usar. Usa /brain suggest para ver una sugerencia.",
        action = "none"
    },
    {
        title = "Comando WCS Cast",
        text = "Usa /wcs cast para lanzar el mejor hechizo automáticamente. Puedes crear una macro con este comando para usarlo fácilmente.",
        action = "none"
    },
    {
        title = "Estadísticas",
        text = "Puedo trackear tus estadísticas. Usa /brainstats session para verlas.",
        action = "none"
    },
    {
        title = "Sistema de Memoria",
        text = "Recuerdo cada mob que matas. Usa /brainmemory list para ver mis recuerdos.",
        action = "none"
    },
    {
        title = "Perfiles",
        text = "Puedes crear perfiles diferentes para distintas situaciones. Usa /brainprofile list.",
        action = "none"
    },
    {
        title = "Modo PvP",
        text = "Tengo un modo especial para PvP. Usa /brainpvp on para activarlo.",
        action = "none"
    },
    {
        title = "Chat de Mascotas",
        text = "Tus mascotas pueden hablar! Usa /brainpetchat on para activarlo.",
        action = "none"
    },
    {
        title = "Logros",
        text = "Puedes desbloquear logros mientras juegas. Usa /brainachievements list para verlos.",
        action = "none"
    },
    {
        title = "Tutorial Completado!",
        text = "¡Felicidades! Ya sabes lo básico. Ahora sal y mata algunos mobs para que pueda aprender de ti.",
        action = "complete"
    }
}

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainTutorial:Initialize()
    -- Verificar si el tutorial ya se completó
    if WCS_BrainSaved and WCS_BrainSaved.tutorialCompleted then
        return
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Tutorial", "Tutorial disponible. Usa /braintutorial para empezar")
    end
end

-- ============================================================================
-- CONTROL DEL TUTORIAL
-- ============================================================================
function WCS_BrainTutorial:Start()
    if WCS_BrainSaved and WCS_BrainSaved.tutorialCompleted then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Tutorial]|r Ya completaste el tutorial")
        return
    end
    
    self.active = true
    self.currentStep = 1
    self:ShowStep()
end

function WCS_BrainTutorial:ShowStep()
    if not self.active then return end
    
    local step = self.Steps[self.currentStep]
    if not step then
        self:Complete()
        return
    end
    
    -- Mostrar paso
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700========================================|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[Tutorial]|r Paso " .. self.currentStep .. "/" .. table.getn(self.Steps))
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700" .. step.title .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFF" .. step.text .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Usa /braintutorial next para continuar|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700========================================|r")
end

function WCS_BrainTutorial:Next()
    if not self.active then return end
    
    self.currentStep = self.currentStep + 1
    
    if self.currentStep > table.getn(self.Steps) then
        self:Complete()
    else
        self:ShowStep()
    end
end

function WCS_BrainTutorial:Skip()
    self:Complete()
end

function WCS_BrainTutorial:Complete()
    self.active = false
    
    -- Marcar como completado
    if not WCS_BrainSaved then
        WCS_BrainSaved = {}
    end
    WCS_BrainSaved.tutorialCompleted = true
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700========================================|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00¡Tutorial Completado!|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFFFFAhora estoy listo para ayudarte.|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Usa /brain help para ver todos los comandos|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700========================================|r")
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Tutorial", "Tutorial completado")
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSTUTORIAL1 = "/wcstutorial"
SLASH_WCSTUTORIAL2 = "/braintutorial"

SlashCmdList["WCSTUTORIAL"] = function(msg)
    if msg == "" or msg == "start" then
        WCS_BrainTutorial:Start()
        
    elseif msg == "next" then
        WCS_BrainTutorial:Next()
        
    elseif msg == "skip" then
        WCS_BrainTutorial:Skip()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Tutorial]|r Tutorial omitido")
        
    elseif msg == "reset" then
        if WCS_BrainSaved then
            WCS_BrainSaved.tutorialCompleted = false
        end
        WCS_BrainTutorial.active = false
        WCS_BrainTutorial.currentStep = 1
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Tutorial]|r Tutorial reseteado")
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Tutorial]|r Comandos:")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braintutorial start|r - Iniciar tutorial")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braintutorial next|r - Siguiente paso")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braintutorial skip|r - Omitir tutorial")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00/braintutorial reset|r - Resetear tutorial")
    end
end

-- Auto-inicialización
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        WCS_BrainTutorial:Initialize()
    end
end)
