--[[
    WCS_SpellLocalization.lua - Sistema de Localización de Hechizos
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
    
    Mapea nombres de hechizos en diferentes idiomas al inglés (usado internamente)
    
    Autor: Elnazzareno (DarckRovert)
    Twitch: twitch.tv/darckrovert
    Kick: kick.com/darckrovert
]]--

WCS_SpellLocalization = WCS_SpellLocalization or {}
WCS_SpellLocalization.VERSION = "1.0.0"

-- ============================================================================
-- MAPEO ESPAÑOL -> INGLÉS
-- ============================================================================
WCS_SpellLocalization.esES = {
    -- Hechizos de Daño
    ["Descarga de las Sombras"] = "Shadow Bolt",
    ["Inmolar"] = "Immolate",
    ["Incinerar"] = "Immolate", -- variante
    ["Corrupción"] = "Corruption",
    ["Maldición de agonía"] = "Curse of Agony",
    ["Maldición de muerte"] = "Curse of Doom",
    ["Succionar vida"] = "Siphon Life",
    ["Drenar vida"] = "Drain Life",
    ["Drenar alma"] = "Drain Soul",
    ["Fuego de alma"] = "Soul Fire",
    ["Dolor abrasador"] = "Searing Pain",
    ["Conflagrar"] = "Conflagrate",
    ["Quemadura de las Sombras"] = "Shadowburn",
    ["Lluvia de Fuego"] = "Rain of Fire",
    ["Fuego Infernal"] = "Hellfire",
    
    -- Hechizos de Control
    ["Miedo"] = "Fear",
    ["Aullido de terror"] = "Howl of Terror",
    ["Espiral de la muerte"] = "Death Coil",
    ["Destierro"] = "Banish",
    ["Maldición de lenguas"] = "Curse of Tongues",
    ["Maldición de agotamiento"] = "Curse of Exhaustion",
    ["Maldición de debilidad"] = "Curse of Weakness",
    ["Maldición de imprudencia"] = "Curse of Recklessness",
    ["Maldición de los elementos"] = "Curse of the Elements",
    ["Maldición de las Sombras"] = "Curse of Shadow",
    
    -- Hechizos Defensivos/Utilidad
    ["Transfusión de vida"] = "Life Tap",
    ["Pacto Oscuro"] = "Dark Pact",
    ["Drenar maná"] = "Drain Mana",
    ["Canalizar salud"] = "Health Funnel",
    ["Respiración interminable"] = "Unending Breath",
    ["Detectar invisibilidad"] = "Detect Invisibility",
    ["Protección de las Sombras"] = "Shadow Ward",
    ["Armadura de demonio"] = "Demon Armor",
    ["Piel de demonio"] = "Demon Skin",
    ["Vínculo de alma"] = "Soul Link",
    ["Dominación vil"] = "Fel Domination",
    
    -- Invocaciones
    ["Invocar diablillo"] = "Summon Imp",
    ["Invocar Abisario"] = "Summon Voidwalker",
    ["Invocar súcubo"] = "Summon Succubus",
    ["Invocar manáfago"] = "Summon Felhunter",
    ["Invocar guardia vil"] = "Summon Felguard",
    ["Infernal"] = "Inferno",
    ["Ritual de Perdición"] = "Ritual of Doom",
    
    -- Habilidades del Diablillo (Imp)
    ["Bola de Fuego"] = "Firebolt",
    ["Escudo de fuego"] = "Fire Shield",
    ["Pacto de sangre"] = "Blood Pact",
    ["Cambio de fase"] = "Phase Shift",
    
    -- Habilidades del Abisario (Voidwalker)
    ["Tormento"] = "Torment",
    ["Consumir Sombras"] = "Consume Shadows",
    ["Consumir las Sombras"] = "Consume Shadows",
    ["Sacrificio"] = "Sacrifice",
    ["Sufrimiento"] = "Suffering",
    
    -- Habilidades del Súcubo (Succubus)
    ["Latigazo de dolor"] = "Lash of Pain",
    ["Seducción"] = "Seduction",
    ["Beso tranquilizador"] = "Soothing Kiss",
    ["Invisibilidad menor"] = "Lesser Invisibility",
    
    -- Habilidades del Manáfago (Felhunter)
    ["Mordedura de las Sombras"] = "Shadow Bite",
    ["Bloqueo de hechizo"] = "Spell Lock",
    ["Devorar magia"] = "Devour Magic",
    ["Paranoia"] = "Paranoia",
    
    -- Habilidades del Guardia Vil (Felguard)
    ["Hender"] = "Cleave",
    ["Interceptar"] = "Intercept",
    ["Angustia"] = "Anguish",
    ["Frenesí demoníaco"] = "Demonic Frenzy",
    
    -- Creación de Piedras
    ["Crear Piedra de Alma"] = "Create Soulstone",
    ["Crear Piedra de Alma Inferior"] = "Create Soulstone (Lesser)",
    ["Crear Piedra de Alma Menor"] = "Create Soulstone (Minor)",
    ["Crear Piedra de Alma Superior"] = "Create Soulstone (Greater)",
    ["Crear Piedra de Fuego"] = "Create Firestone",
    ["Crear Piedra de Hechizo"] = "Create Spellstone",
    ["Crear Piedra de Salud"] = "Create Healthstone",
    ["Crear Piedra de Salud Inferior"] = "Create Healthstone (Lesser)",
    ["Crear Piedra de Salud Menor"] = "Create Healthstone (Minor)",
    ["Crear Piedra de Salud Superior"] = "Create Healthstone (Greater)",
    ["Crear Piedra del Vacío"] = "Create Voidstone",
    ["Crear Piedra Demoníaca"] = "Create Demonstone",
    ["Invocar Diablillo"] = "Summon Imp",
    ["Invocar Súcubo"] = "Summon Succubus",
    ["Invocar Corcelón"] = "Summon Felsteed",
    ["Invocar Manáfago"] = "Summon Felhunter",
    ["Detectar Invisibilidad Inferior"] = "Detect Lesser Invisibility",
    ["Detectar Invisibilidad Superior"] = "Detect Greater Invisibility",
    ["Ojo de Kilrogg"] = "Eye of Kilrogg",
    ["Esclavizar Demonio"] = "Enslave Demon",
    ["Dominar Voluntad"] = "Dominate Mind",
    ["Desterrar"] = "Banish",
    ["Desafiar"] = "Challenge",
    ["Capas de Magia"] = "Magic Layers",
    ["Capas de Salud"] = "Health Layers",
    ["Orden de mascotas: Agresivo"] = "Pet Aggressive",
    ["Forma Obnubilada"] = "Shadowform",
    ["Resguardo Contra las Sombras"] = "Shadow Ward",
    ["Baile de Invocador"] = "Summoner's Dance",
    ["Montar"] = "Mount",
    ["Cancelar Aura: Montura"] = "Cancel Aura: Mount",
    ["Llamas infernales"] = "Hellfire",
    ["Mecanizado"] = "Engineering",
    ["Mecanizado rápido"] = "Fast Engineering",
    
    -- Hechizos adicionales identificados
    ["Dolor Abrasador"] = "Searing Pain",
    ["Fuego de Alma"] = "Soul Fire",
    ["Incinerar"] = "Incinerate",
    ["Llamas Infernales"] = "Hellfire",
    ["Invocar Corcel"] = "Summon Felsteed",
    ["Invocar Corcel del Abismo"] = "Summon Felsteed",
    ["Ritual de Perdición"] = "Ritual of Doom",
    ["Ritual demoniaco"] = "Ritual of Summoning",
    ["Ritual de Invocación"] = "Ritual of Summoning",
    ["Captar Esencia"] = "Drain Soul",
    ["Captar Alma"] = "Drain Soul",
    ["Captar Demonio"] = "Banish",
    ["Captar Invisibilidad"] = "Detect Invisibility",
    ["Lengua de Muerte"] = "Death Coil",
    ["Embrujo de Alma"] = "Soul Link",
    ["Inferno"] = "Inferno",
    
    -- Mascotas/Invocaciones adicionales
    ["Alevín"] = "Minnow",
    ["Carámbano"] = "Icicle",
    ["Culebra Escarlata"] = "Scarlet Snake",
    ["Gato Blanco"] = "White Cat",
    ["Desvanecido Azul"] = "Blue Flicker",
    ["Desvanecido Rojo"] = "Red Flicker",
    ["Desvanecido Verde"] = "Green Flicker",
    
    -- Cóleras elementales
    ["Cólera Arcana"] = "Arcane Wrath",
    ["Cólera de Fuego"] = "Fire Wrath",
    ["Cólera Helada"] = "Frost Wrath",
    ["Cólera Terrenal"] = "Earth Wrath",
    
    -- Capas
    ["Capa de Magia"] = "Magic Layer",
    ["Capas de Maná"] = "Mana Layers",
    
    -- Piedras con rangos específicos
    ["Crear Piedra de Alma (Inferior)"] = "Create Soulstone (Lesser)",
    ["Crear Piedra de Alma (Menor)"] = "Create Soulstone (Minor)",
    ["Crear Piedra de Alma (Sublime)"] = "Create Soulstone (Major)",
    ["Crear Piedra de Alma (Superior)"] = "Create Soulstone (Greater)",
    ["Crear Piedra de Salud (Inferior)"] = "Create Healthstone (Lesser)",
    ["Crear Piedra de Salud (Menor)"] = "Create Healthstone (Minor)",
    ["Crear Piedra de Salud (Superior)"] = "Create Healthstone (Greater)",
    ["Crear Piedra de Salud (Sublime)"] = "Create Healthstone (Major)",
    ["Crear Piedra de Ira"] = "Create Firestone",
    
    -- Armaduras Demoníacas (todos los rangos)
    ["Armadura Demoníaca"] = "Demon Armor",
    ["Piel de Demonio"] = "Demon Skin",
    
    -- Capas de Maná y Salud (todos los rangos)
    ["Capas de Maná"] = "Mana Layers",
    ["Capas de Salud"] = "Health Layers",
    
    -- Hechizos adicionales que faltaban
    ["Puerta Demoníaca"] = "Demonic Gateway",
    ["Orden de mascotas"] = "Pet Order",
    ["Pulso Demoníaco"] = "Demonic Pulse",
    ["Captar Demonio"] = "Drain Demon",
    
    -- Hechizos de mascotas y otros
    ["Gusano Blanco"] = "White Worm",
    ["Lino"] = "Linen",
    ["Quimera"] = "Chimera",
    ["Rana Toro"] = "Bull Frog",
    ["Rana de Árbol"] = "Tree Frog",
    ["Sapo"] = "Toad",
    ["Sapo Mecánico Casi Vivo"] = "Lifelike Mechanical Toad",
    ["Tank de Vapor Púrpura"] = "Purple Vapor Tank",
    ["Tank de Vapor Verde"] = "Green Vapor Tank",
    ["Veneno Blanco"] = "White Venom",
    ["Vitalidad"] = "Vitality",
    ["Huellas de Maná"] = "Mana Footprints",
    ["Rocío: Cima del Jardín"] = "Dew: Garden Top",
    ["Rocío: Rayo de Arena de Esmeralda"] = "Dew: Emerald Sand Ray",
    ["Rocío: Sueño Esmeralda"] = "Dew: Emerald Dream",
    
    -- Habilidades de mascotas del Brujo
    ["Machetazo"] = "Firebolt",
    ["Mordedura"] = "Bite",
    ["Tormento"] = "Torment",
    ["Consumir Sombras"] = "Consume Shadows",
    ["Sacrificio"] = "Sacrifice",
    ["Sufrir"] = "Suffering",
    ["Latigazo"] = "Lash of Pain",
    ["Seducir"] = "Seduction",
    ["Caricia de Sombras"] = "Shadow Bite",
    ["Hechizo de Paranoia"] = "Paranoia",
    ["Devorar Magia"] = "Devour Magic",
    ["Embestida de Hechizos"] = "Spell Lock",
    ["Golpe de Hacha"] = "Cleave",
    ["Intercepción"] = "Intercept",
    ["Aturdir"] = "Anguish",
    
    -- Sapos y ranas adicionales
    ["Sapo Mecánico Gris"] = "Lifelike Mechanical Toad",
    
    -- Tótems (pueden ser de chamán pero aparecen en la lista)
    ["Tótem de Fuego"] = "Fire Totem",
    ["Tótem de Tierra"] = "Earth Totem",
    ["Tótem de Agua"] = "Water Totem",
    ["Tótem de Aire"] = "Air Totem",
    
    -- Mascotas/Compañeros adicionales (Turtle WoW)
    ["Caprina"] = "Goat",
    ["Cría Rezzashi"] = "Razzashi Hatchling",
    ["Cría Razzashi"] = "Razzashi Hatchling",
    ["Cría Hakkari"] = "Hakkari Hatchling",
    ["Cría de Hakkari"] = "Hakkari Hatchling",
    ["Gato Naranja"] = "Orange Cat",
    ["Gato"] = "Cat",
    ["Gato Blanco"] = "White Cat",
    ["Víbora Escarlata"] = "Scarlet Viper",
    ["Vial"] = "Vial",
    ["Murloco de Nieve"] = "Snow Murloc",
    ["Cría de Hakkari"] = "Hakkari Hatchling",
    ["Cría de Tigre"] = "Tiger Cub",
    ["Gato Naranja"] = "Orange Tabby Cat",
    ["Gato Blanco"] = "White Kitten",
    ["Rana Naranja"] = "Orange Frog",
    
    -- Rocío (Dew) - Hechizos custom de Turtle WoW
    ["Rocío: Cima del Agua"] = "Dew: Water Peak",
    ["Rocío: Reloj de Arena de Jade Oscuro"] = "Dew: Dark Jade Hourglass",
    ["Rocío: Sueño Esmeralda"] = "Dew: Emerald Dream",
    
    -- Tótems de Vapor
    ["Tótem de Vapor Púrpura"] = "Purple Vapor Totem",
    ["Tótem de Vapor Verde"] = "Green Vapor Totem",
    
    -- Hechizos adicionales del Brujo
    ["Buf tras Agotarse"] = "Buff on Drain",
    ["Captar Demonio"] = "Drain Demon",
    ["Capas de Maná"] = "Mana Layers",
    ["Capas de Salud"] = "Health Layers",
    ["Dominación VI"] = "Domination VI",
    ["Flagelo de Alma"] = "Soul Scourge",
    ["Inferno"] = "Inferno",
    ["Invocar Corcel"] = "Summon Felsteed",
    ["Ojo de Kilrogg"] = "Eye of Kilrogg",
    
    -- Hechizos de mascotas (Turtle WoW custom)
    ["Mazazo Azul"] = "Blue Smash",
    ["Mazazo Rojo"] = "Red Smash",
    ["Mazazo Sólido"] = "Solid Smash",
    ["Mazazo Verde"] = "Green Smash",
    ["Tortura de Muñón"] = "Stump Torture",
    ["Ancoraje"] = "Anchoring",
    ["Caja de Herramientas"] = "Toolbox",
    ["Cardina"] = "Cardinal",
    ["Cría de Hakkari"] = "Hakkari Hatchling"
}

-- ============================================================================
-- MAPEO PORTUGUÉS -> INGLÉS
-- ============================================================================
WCS_SpellLocalization.ptBR = {
    -- Hechizos de Daño
    ["Seta das Sombras"] = "Shadow Bolt",
    ["Imolar"] = "Immolate",
    ["Corrupção"] = "Corruption",
    ["Maldição da Agonia"] = "Curse of Agony",
    ["Maldição da Perdição"] = "Curse of Doom",
    ["Drenar Vida"] = "Siphon Life",
    ["Drenar Vida"] = "Drain Life",
    ["Drenar Alma"] = "Drain Soul",
    ["Fogo da Alma"] = "Soul Fire",
    ["Dor Ardente"] = "Searing Pain",
    ["Conflagrar"] = "Conflagrate",
    ["Queimadura Sombria"] = "Shadowburn",
    ["Chuva de Fogo"] = "Rain of Fire",
    ["Fogo do Inferno"] = "Hellfire",
    
    -- Control
    ["Medo"] = "Fear",
    ["Uivo do Terror"] = "Howl of Terror",
    ["Espiral da Morte"] = "Death Coil",
    ["Banir"] = "Banish",
    
    -- Invocaciones
    ["Convocar Diabrete"] = "Summon Imp",
    ["Convocar Caçador Vil"] = "Summon Felhunter"
}

-- ============================================================================
-- MAPEO FRANCÉS -> INGLÉS
-- ============================================================================
WCS_SpellLocalization.frFR = {
    ["Trait de l'ombre"] = "Shadow Bolt",
    ["Immolation"] = "Immolate",
    ["Corruption"] = "Corruption",
    ["Malédiction d'agonie"] = "Curse of Agony",
    ["Peur"] = "Fear",
    ["Invocation d'un diablotin"] = "Summon Imp"
}

-- ============================================================================
-- MAPEO ALEMÁN -> INGLÉS
-- ============================================================================
WCS_SpellLocalization.deDE = {
    ["Schattenblitz"] = "Shadow Bolt",
    ["Feuerbrand"] = "Immolate",
    ["Verderbnis"] = "Corruption",
    ["Fluch der Pein"] = "Curse of Agony",
    ["Furcht"] = "Fear",
    ["Wichtel beschwören"] = "Summon Imp"
}

-- ============================================================================
-- FUNCIÓN DE NORMALIZACIÓN
-- ============================================================================
function WCS_SpellLocalization:NormalizeSpellName(spellName)
    if not spellName then return nil end
    
    -- Si ya está en inglés, devolver tal cual
    if WCS_SpellDB and WCS_SpellDB:GetSpell(spellName) then
        return spellName
    end
    
    -- Obtener idioma del cliente
    local locale = GetLocale() or "enUS"
    
    -- Si es inglés, no hay nada que traducir
    if locale == "enUS" then
        return spellName
    end
    
    -- Buscar en el mapeo del idioma actual
    local localeMap = self[locale]
    if localeMap and localeMap[spellName] then
        return localeMap[spellName]
    end
    
    -- Si no se encuentra, devolver el nombre original
    return spellName
end

-- ============================================================================
-- FUNCIÓN INVERSA: INGLÉS -> IDIOMA LOCAL
-- ============================================================================
function WCS_SpellLocalization:LocalizeSpellName(englishName)
    if not englishName then return nil end
    
    local locale = GetLocale() or "enUS"
    
    -- Si es inglés, devolver tal cual
    if locale == "enUS" then
        return englishName
    end
    
    -- Buscar en el mapeo inverso
    local localeMap = self[locale]
    if localeMap then
        for localName, engName in pairs(localeMap) do
            if engName == englishName then
                return localName
            end
        end
    end
    
    -- Si no se encuentra, devolver el nombre en inglés
    return englishName
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
local function OnLoad()
    local locale = GetLocale() or "enUS"
    DEFAULT_CHAT_FRAME:AddMessage("[WCS_SpellLocalization] Sistema de localización de hechizos cargado (" .. locale .. ")")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WCS_Brain" then
        OnLoad()
    end
end)
