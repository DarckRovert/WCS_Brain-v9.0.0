--[[
    WCS_BrainLocale.lua - Sistema de Localización v6.6.0
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Sistema de traducción para múltiples idiomas
    
    Autor: Elnazzareno (DarckRovert)
    Twitch: twitch.tv/darckrovert
    Kick: kick.com/darckrovert
]]--

WCS_BrainLocale = WCS_BrainLocale or {}
WCS_BrainLocale.VERSION = "6.6.0"

-- ============================================================================
-- CONFIGURACIÓN
-- ============================================================================
WCS_BrainLocale.currentLocale = GetLocale() or "enUS"

-- ============================================================================
-- TRADUCCIONES
-- ============================================================================
WCS_BrainLocale.Translations = {}

-- ============================================================================
-- INGLÉS (enUS)
-- ============================================================================
WCS_BrainLocale.Translations["enUS"] = {
    -- General
    ["BRAIN_LOADED"] = "Brain loaded successfully!",
    ["BRAIN_VERSION"] = "Version",
    ["BRAIN_ENABLED"] = "Brain enabled",
    ["BRAIN_DISABLED"] = "Brain disabled",
    
    -- Combat
    ["ENTERING_COMBAT"] = "Entering combat...",
    ["LEAVING_COMBAT"] = "Leaving combat",
    ["TARGET_CHANGED"] = "Target changed",
    ["NO_TARGET"] = "No target",
    
    -- Suggestions
    ["SUGGESTION"] = "Suggestion",
    ["CASTING"] = "Casting",
    ["CONFIDENCE"] = "Confidence",
    ["REASON"] = "Reason",
    
    -- Stats
    ["STATS_SESSION"] = "Session Statistics",
    ["STATS_COMBATS"] = "Combats",
    ["STATS_KILLS"] = "Kills",
    ["STATS_DEATHS"] = "Deaths",
    ["STATS_DPS"] = "DPS",
    ["STATS_TTK"] = "Avg TTK",
    
    -- Pet
    ["PET_SUMMONED"] = "Pet summoned",
    ["PET_DISMISSED"] = "Pet dismissed",
    ["PET_DIED"] = "Pet died",
    ["PET_HEALTH_LOW"] = "Pet health low!",
    
    -- Profiles
    ["PROFILE_LOADED"] = "Profile loaded",
    ["PROFILE_SAVED"] = "Profile saved",
    ["PROFILE_CREATED"] = "Profile created",
    ["PROFILE_DELETED"] = "Profile deleted",
    
    -- Errors
    ["ERROR_NO_TARGET"] = "Error: No target",
    ["ERROR_NOT_ENOUGH_MANA"] = "Error: Not enough mana",
    ["ERROR_OUT_OF_RANGE"] = "Error: Out of range",
    ["ERROR_SPELL_NOT_READY"] = "Error: Spell not ready",
    
    -- Achievements
    ["ACHIEVEMENT_UNLOCKED"] = "Achievement Unlocked!",
    ["ACHIEVEMENT_FIRST_BLOOD"] = "First Blood",
    ["ACHIEVEMENT_EFFICIENT_KILLER"] = "Efficient Killer",
    ["ACHIEVEMENT_PET_MASTER"] = "Pet Master",
    ["ACHIEVEMENT_SPEED_DEMON"] = "Speed Demon",
    ["ACHIEVEMENT_SURVIVOR"] = "Survivor",
    ["ACHIEVEMENT_MANA_MASTER"] = "Mana Master",
    ["ACHIEVEMENT_BRAIN_TRUST"] = "Brain Trust",
    ["ACHIEVEMENT_LEARNING_MACHINE"] = "Learning Machine"
}

-- ============================================================================
-- ESPAÑOL (esES)
-- ============================================================================
WCS_BrainLocale.Translations["esES"] = {
    -- General
    ["BRAIN_LOADED"] = "¡Brain cargado exitosamente!",
    ["BRAIN_VERSION"] = "Versión",
    ["BRAIN_ENABLED"] = "Brain activado",
    ["BRAIN_DISABLED"] = "Brain desactivado",
    
    -- Combat
    ["ENTERING_COMBAT"] = "Entrando en combate...",
    ["LEAVING_COMBAT"] = "Saliendo de combate",
    ["TARGET_CHANGED"] = "Objetivo cambiado",
    ["NO_TARGET"] = "Sin objetivo",
    
    -- Suggestions
    ["SUGGESTION"] = "Sugerencia",
    ["CASTING"] = "Lanzando",
    ["CONFIDENCE"] = "Confianza",
    ["REASON"] = "Razón",
    
    -- Stats
    ["STATS_SESSION"] = "Estadísticas de Sesión",
    ["STATS_COMBATS"] = "Combates",
    ["STATS_KILLS"] = "Asesinatos",
    ["STATS_DEATHS"] = "Muertes",
    ["STATS_DPS"] = "DPS",
    ["STATS_TTK"] = "TTK Promedio",
    
    -- Pet
    ["PET_SUMMONED"] = "Mascota invocada",
    ["PET_DISMISSED"] = "Mascota despedida",
    ["PET_DIED"] = "Mascota murió",
    ["PET_HEALTH_LOW"] = "¡Salud de mascota baja!",
    
    -- Profiles
    ["PROFILE_LOADED"] = "Perfil cargado",
    ["PROFILE_SAVED"] = "Perfil guardado",
    ["PROFILE_CREATED"] = "Perfil creado",
    ["PROFILE_DELETED"] = "Perfil eliminado",
    
    -- Errors
    ["ERROR_NO_TARGET"] = "Error: Sin objetivo",
    ["ERROR_NOT_ENOUGH_MANA"] = "Error: No hay suficiente mana",
    ["ERROR_OUT_OF_RANGE"] = "Error: Fuera de rango",
    ["ERROR_SPELL_NOT_READY"] = "Error: Hechizo no está listo",
    
    -- Achievements
    ["ACHIEVEMENT_UNLOCKED"] = "¡Logro Desbloqueado!",
    ["ACHIEVEMENT_FIRST_BLOOD"] = "Primera Sangre",
    ["ACHIEVEMENT_EFFICIENT_KILLER"] = "Asesino Eficiente",
    ["ACHIEVEMENT_PET_MASTER"] = "Maestro de Mascotas",
    ["ACHIEVEMENT_SPEED_DEMON"] = "Demonio Veloz",
    ["ACHIEVEMENT_SURVIVOR"] = "Superviviente",
    ["ACHIEVEMENT_MANA_MASTER"] = "Maestro del Mana",
    ["ACHIEVEMENT_BRAIN_TRUST"] = "Confianza en el Brain",
    ["ACHIEVEMENT_LEARNING_MACHINE"] = "Máquina de Aprendizaje"
}

-- ============================================================================
-- PORTUGUÉS (ptBR)
-- ============================================================================
WCS_BrainLocale.Translations["ptBR"] = {
    -- General
    ["BRAIN_LOADED"] = "Brain carregado com sucesso!",
    ["BRAIN_VERSION"] = "Versão",
    ["BRAIN_ENABLED"] = "Brain ativado",
    ["BRAIN_DISABLED"] = "Brain desativado",
    
    -- Combat
    ["ENTERING_COMBAT"] = "Entrando em combate...",
    ["LEAVING_COMBAT"] = "Saindo de combate",
    ["TARGET_CHANGED"] = "Alvo mudado",
    ["NO_TARGET"] = "Sem alvo",
    
    -- Suggestions
    ["SUGGESTION"] = "Sugestão",
    ["CASTING"] = "Lançando",
    ["CONFIDENCE"] = "Confiança",
    ["REASON"] = "Razão",
    
    -- Stats
    ["STATS_SESSION"] = "Estatísticas da Sessão",
    ["STATS_COMBATS"] = "Combates",
    ["STATS_KILLS"] = "Mortes",
    ["STATS_DEATHS"] = "Mortes",
    ["STATS_DPS"] = "DPS",
    ["STATS_TTK"] = "TTK Médio",
    
    -- Pet
    ["PET_SUMMONED"] = "Pet invocado",
    ["PET_DISMISSED"] = "Pet dispensado",
    ["PET_DIED"] = "Pet morreu",
    ["PET_HEALTH_LOW"] = "Saúde do pet baixa!",
    
    -- Profiles
    ["PROFILE_LOADED"] = "Perfil carregado",
    ["PROFILE_SAVED"] = "Perfil salvo",
    ["PROFILE_CREATED"] = "Perfil criado",
    ["PROFILE_DELETED"] = "Perfil deletado",
    
    -- Errors
    ["ERROR_NO_TARGET"] = "Erro: Sem alvo",
    ["ERROR_NOT_ENOUGH_MANA"] = "Erro: Mana insuficiente",
    ["ERROR_OUT_OF_RANGE"] = "Erro: Fora de alcance",
    ["ERROR_SPELL_NOT_READY"] = "Erro: Feitiço não está pronto",
    
    -- Achievements
    ["ACHIEVEMENT_UNLOCKED"] = "Conquista Desbloqueada!",
    ["ACHIEVEMENT_FIRST_BLOOD"] = "Primeiro Sangue",
    ["ACHIEVEMENT_EFFICIENT_KILLER"] = "Assassino Eficiente",
    ["ACHIEVEMENT_PET_MASTER"] = "Mestre dos Pets",
    ["ACHIEVEMENT_SPEED_DEMON"] = "Demônio Veloz",
    ["ACHIEVEMENT_SURVIVOR"] = "Sobrevivente",
    ["ACHIEVEMENT_MANA_MASTER"] = "Mestre do Mana",
    ["ACHIEVEMENT_BRAIN_TRUST"] = "Confiança no Brain",
    ["ACHIEVEMENT_LEARNING_MACHINE"] = "Máquina de Aprendizado"
}

-- ============================================================================
-- FRANCÉS (frFR)
-- ============================================================================
WCS_BrainLocale.Translations["frFR"] = {
    -- General
    ["BRAIN_LOADED"] = "Brain chargé avec succès!",
    ["BRAIN_VERSION"] = "Version",
    ["BRAIN_ENABLED"] = "Brain activé",
    ["BRAIN_DISABLED"] = "Brain désactivé",
    
    -- Combat
    ["ENTERING_COMBAT"] = "Entrée en combat...",
    ["LEAVING_COMBAT"] = "Sortie de combat",
    ["TARGET_CHANGED"] = "Cible changée",
    ["NO_TARGET"] = "Pas de cible",
    
    -- Suggestions
    ["SUGGESTION"] = "Suggestion",
    ["CASTING"] = "Lancement",
    ["CONFIDENCE"] = "Confiance",
    ["REASON"] = "Raison",
    
    -- Stats
    ["STATS_SESSION"] = "Statistiques de Session",
    ["STATS_COMBATS"] = "Combats",
    ["STATS_KILLS"] = "Tués",
    ["STATS_DEATHS"] = "Morts",
    ["STATS_DPS"] = "DPS",
    ["STATS_TTK"] = "TTK Moyen",
    
    -- Pet
    ["PET_SUMMONED"] = "Familier invoqué",
    ["PET_DISMISSED"] = "Familier renvoyé",
    ["PET_DIED"] = "Familier mort",
    ["PET_HEALTH_LOW"] = "Santé du familier faible!",
    
    -- Profiles
    ["PROFILE_LOADED"] = "Profil chargé",
    ["PROFILE_SAVED"] = "Profil sauvegardé",
    ["PROFILE_CREATED"] = "Profil créé",
    ["PROFILE_DELETED"] = "Profil supprimé",
    
    -- Errors
    ["ERROR_NO_TARGET"] = "Erreur: Pas de cible",
    ["ERROR_NOT_ENOUGH_MANA"] = "Erreur: Pas assez de mana",
    ["ERROR_OUT_OF_RANGE"] = "Erreur: Hors de portée",
    ["ERROR_SPELL_NOT_READY"] = "Erreur: Sort pas prêt",
    
    -- Achievements
    ["ACHIEVEMENT_UNLOCKED"] = "Succès Débloqué!",
    ["ACHIEVEMENT_FIRST_BLOOD"] = "Premier Sang",
    ["ACHIEVEMENT_EFFICIENT_KILLER"] = "Tueur Efficace",
    ["ACHIEVEMENT_PET_MASTER"] = "Maître des Familiers",
    ["ACHIEVEMENT_SPEED_DEMON"] = "Démon de Vitesse",
    ["ACHIEVEMENT_SURVIVOR"] = "Survivant",
    ["ACHIEVEMENT_MANA_MASTER"] = "Maître du Mana",
    ["ACHIEVEMENT_BRAIN_TRUST"] = "Confiance dans le Brain",
    ["ACHIEVEMENT_LEARNING_MACHINE"] = "Machine Apprenante"
}

-- ============================================================================
-- ALEMÁN (deDE)
-- ============================================================================
WCS_BrainLocale.Translations["deDE"] = {
    -- General
    ["BRAIN_LOADED"] = "Brain erfolgreich geladen!",
    ["BRAIN_VERSION"] = "Version",
    ["BRAIN_ENABLED"] = "Brain aktiviert",
    ["BRAIN_DISABLED"] = "Brain deaktiviert",
    
    -- Combat
    ["ENTERING_COMBAT"] = "Kampf beginnt...",
    ["LEAVING_COMBAT"] = "Kampf beendet",
    ["TARGET_CHANGED"] = "Ziel geändert",
    ["NO_TARGET"] = "Kein Ziel",
    
    -- Suggestions
    ["SUGGESTION"] = "Vorschlag",
    ["CASTING"] = "Zaubern",
    ["CONFIDENCE"] = "Vertrauen",
    ["REASON"] = "Grund",
    
    -- Stats
    ["STATS_SESSION"] = "Sitzungsstatistiken",
    ["STATS_COMBATS"] = "Kämpfe",
    ["STATS_KILLS"] = "Tötungen",
    ["STATS_DEATHS"] = "Tode",
    ["STATS_DPS"] = "DPS",
    ["STATS_TTK"] = "Durchschn. TTK",
    
    -- Pet
    ["PET_SUMMONED"] = "Begleiter beschwört",
    ["PET_DISMISSED"] = "Begleiter entlassen",
    ["PET_DIED"] = "Begleiter gestorben",
    ["PET_HEALTH_LOW"] = "Begleiter Gesundheit niedrig!",
    
    -- Profiles
    ["PROFILE_LOADED"] = "Profil geladen",
    ["PROFILE_SAVED"] = "Profil gespeichert",
    ["PROFILE_CREATED"] = "Profil erstellt",
    ["PROFILE_DELETED"] = "Profil gelöscht",
    
    -- Errors
    ["ERROR_NO_TARGET"] = "Fehler: Kein Ziel",
    ["ERROR_NOT_ENOUGH_MANA"] = "Fehler: Nicht genug Mana",
    ["ERROR_OUT_OF_RANGE"] = "Fehler: Außerhalb der Reichweite",
    ["ERROR_SPELL_NOT_READY"] = "Fehler: Zauber nicht bereit",
    
    -- Achievements
    ["ACHIEVEMENT_UNLOCKED"] = "Erfolg Freigeschaltet!",
    ["ACHIEVEMENT_FIRST_BLOOD"] = "Erstes Blut",
    ["ACHIEVEMENT_EFFICIENT_KILLER"] = "Effizienter Mörder",
    ["ACHIEVEMENT_PET_MASTER"] = "Begleitermeister",
    ["ACHIEVEMENT_SPEED_DEMON"] = "Geschwindigkeitsdämon",
    ["ACHIEVEMENT_SURVIVOR"] = "Überlebender",
    ["ACHIEVEMENT_MANA_MASTER"] = "Manameister",
    ["ACHIEVEMENT_BRAIN_TRUST"] = "Brain Vertrauen",
    ["ACHIEVEMENT_LEARNING_MACHINE"] = "Lernmaschine"
}

-- ============================================================================
-- FUNCIONES DE TRADUCCIÓN
-- ============================================================================
function WCS_BrainLocale:Get(key, ...)
    local locale = self.currentLocale
    local translations = self.Translations[locale]
    
    -- Si no existe el idioma, usar inglés
    if not translations then
        translations = self.Translations["enUS"]
    end
    
    -- Obtener traducción
    local text = translations[key]
    
    -- Si no existe la clave, devolver la clave misma
    if not text then
        return key
    end
    
    -- Reemplazar parámetros si existen
    if arg and table.getn(arg) > 0 then
        for i = 1, table.getn(arg) do
            text = string.gsub(text, "{" .. i .. "}", tostring(arg[i]))
        end
    end
    
    return text
end

-- Alias corto
function WCS_BrainLocale:L(key, ...)
    return self:Get(key, unpack(arg))
end

function WCS_BrainLocale:SetLocale(locale)
    if self.Translations[locale] then
        self.currentLocale = locale
        if WCS_BrainLogger then
            WCS_BrainLogger:Info("Locale", "Idioma cambiado a: " .. locale)
        end
        return true
    end
    return false
end

function WCS_BrainLocale:GetAvailableLocales()
    local locales = {}
    for locale, _ in pairs(self.Translations) do
        table.insert(locales, locale)
    end
    return locales
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
function WCS_BrainLocale:Initialize()
    -- Detectar idioma del cliente
    local clientLocale = GetLocale()
    if self.Translations[clientLocale] then
        self.currentLocale = clientLocale
    else
        self.currentLocale = "enUS"
    end
    
    if WCS_BrainLogger then
        WCS_BrainLogger:Info("Locale", "Sistema de localización inicializado (" .. self.currentLocale .. ")")
    end
end

-- ============================================================================
-- COMANDOS SLASH
-- ============================================================================
SLASH_WCSLOCALE1 = "/wcslocale"
SLASH_WCSLOCALE2 = "/brainlang"

SlashCmdList["WCSLOCALE"] = function(msg)
    if msg == "" or msg == "list" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Locale]|r Idiomas disponibles:")
        local locales = WCS_BrainLocale:GetAvailableLocales()
        for i = 1, table.getn(locales) do
            local marker = locales[i] == WCS_BrainLocale.currentLocale and " (actual)" or ""
            DEFAULT_CHAT_FRAME:AddMessage("  " .. locales[i] .. marker)
        end
    else
        if WCS_BrainLocale:SetLocale(msg) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Locale]|r Idioma cambiado a: " .. msg)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF9482C9[WCS Locale]|r Error: Idioma no disponible")
        end
    end
end

-- ============================================================================
-- AUTO-INICIALIZACIÓN
-- ============================================================================
local function OnLoad()
    WCS_BrainLocale:Initialize()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        OnLoad()
    end
end)

