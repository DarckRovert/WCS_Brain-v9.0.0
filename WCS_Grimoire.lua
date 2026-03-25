--[[
    WCS_Grimoire.lua
    Grimorio de Brujo - Base de datos de hechizos y rotaciones
]]--

WCS_Grimoire = WCS_Grimoire or {}

local panel = nil
local selectedSpell = nil
local selectedSpec = "Affliction"

-- Clasificación de hechizos por escuela (para filtrado)
local SPELL_SCHOOLS = {
    -- Affliction
    ["Corruption"] = "Affliction",
    ["Curse of Agony"] = "Affliction",
    ["Curse of Doom"] = "Affliction",
    ["Curse of Weakness"] = "Affliction",
    ["Curse of Recklessness"] = "Affliction",
    ["Curse of the Elements"] = "Affliction",
    ["Curse of Shadow"] = "Affliction",
    ["Curse of Tongues"] = "Affliction",
    ["Curse of Exhaustion"] = "Affliction",
    ["Siphon Life"] = "Affliction",
    ["Drain Life"] = "Affliction",
    ["Drain Soul"] = "Affliction",
    ["Drain Mana"] = "Affliction",
    ["Life Tap"] = "Affliction",
    ["Dark Pact"] = "Affliction",
    
    -- Destruction
    ["Shadow Bolt"] = "Destruction",
    ["Immolate"] = "Destruction",
    ["Incinerate"] = "Destruction",
    ["Searing Pain"] = "Destruction",
    ["Soul Fire"] = "Destruction",
    ["Conflagrate"] = "Destruction",
    ["Shadowburn"] = "Destruction",
    ["Hellfire"] = "Destruction",
    ["Rain of Fire"] = "Destruction",
    ["Death Coil"] = "Destruction",
    
    -- Demonology
    ["Summon Imp"] = "Demonology",
    ["Summon Voidwalker"] = "Demonology",
    ["Summon Succubus"] = "Demonology",
    ["Summon Felhunter"] = "Demonology",
    ["Demon Skin"] = "Demonology",
    ["Demon Armor"] = "Demonology",
    ["Fel Armor"] = "Demonology",
    ["Demonic Sacrifice"] = "Demonology",
    ["Soul Link"] = "Demonology",
    ["Fel Domination"] = "Demonology",
    ["Health Funnel"] = "Demonology",
    ["Enslave Demon"] = "Demonology",
    
    -- Utility
    ["Fear"] = "Utility",
    ["Howl of Terror"] = "Utility",
    ["Banish"] = "Utility",
    ["Detect Invisibility"] = "Utility",
    ["Unending Breath"] = "Utility",
    ["Amplify Curse"] = "Utility",
    ["Shadowfury"] = "Utility",
    ["Create Healthstone"] = "Utility",
    ["Create Soulstone"] = "Utility",
    ["Create Firestone"] = "Utility",
    ["Create Spellstone"] = "Utility",
    ["Ritual of Summoning"] = "Utility",
    ["Eye of Kilrogg"] = "Utility",
    ["Sense Demons"] = "Utility",
}

-- Función para escanear el spellbook del jugador
function WCS_Grimoire:ScanPlayerSpells()
    local spells = {}
    local i = 1
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        
        -- Extraer el nombre base del hechizo (sin "Rank X")
        local baseName = spellName
        local rank = 0
        
        if spellRank then
            local _, _, rankNum = string.find(spellRank, "Rank (%d+)")
            if rankNum then
                rank = tonumber(rankNum)
            end
        end
        
        -- Obtener información del hechizo
        local spellTexture = GetSpellTexture(i, BOOKTYPE_SPELL)
        
        -- Clasificar por escuela
        local school = SPELL_SCHOOLS[baseName] or "Other"
        
        -- Verificar si ya tenemos este hechizo
        local existing = spells[baseName]
        if not existing or rank > existing.rank then
            -- Este es el rango más alto que hemos visto
            spells[baseName] = {
                name = baseName,
                rank = rank,
                school = school,
                texture = spellTexture,
                spellId = i
            }
        end
        
        i = i + 1
    end
    
    -- Convertir tabla a array
    local spellArray = {}
    for name, spell in spells do
        table.insert(spellArray, spell)
    end
    
    return spellArray
end

-- Rotaciones recomendadas
local ROTATIONS = {
    Affliction = {
        "1. Curse of Agony/Doom",
        "2. Corruption",
        "3. Siphon Life (if talented)",
        "4. Shadow Bolt spam",
        "5. Drain Soul at <25% HP"
    },
    Destruction = {
        "1. Immolate",
        "2. Curse of Doom/Elements",
        "3. Conflagrate (if talented)",
        "4. Shadow Bolt spam",
        "5. Soul Fire with Soul Shard"
    },
    Demonology = {
        "1. Curse of Agony",
        "2. Corruption",
        "3. Shadow Bolt spam",
        "4. Pet management",
        "5. Soul Link uptime"
    }
}

function WCS_Grimoire:Initialize()
    if panel then return end
    
    panel = CreateFrame("Frame", "WCS_GrimoireFrame", WCS_ClanUI.MainFrame.content)
    panel:SetAllPoints(WCS_ClanUI.MainFrame.content)
    panel:Hide()
    
    -- Título
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff9370DBGrimorio Oscuro|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    
    -- Botones de especialización
    local specButtons = {}
    local specs = {"Affliction", "Destruction", "Demonology"}
    for i = 1, table.getn(specs) do
        local spec = specs[i]
        local btn = CreateFrame("Button", nil, panel)
        btn:SetPoint("TOPLEFT", 10 + (i-1)*120, -40)
        btn:SetWidth(110)
        btn:SetHeight(25)
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture(0, 0, 0, 0.7)
        btn.bg = btnBg
        
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btnText:SetText(spec)
        
        btn:SetScript("OnClick", function()
            selectedSpec = spec
            WCS_Grimoire:UpdateSpecButtons()
            WCS_Grimoire:UpdateSpellList()
            WCS_Grimoire:UpdateRotation()
        end)
        
        specButtons[spec] = btn
    end
    
    self.specButtons = specButtons
    
    -- Lista de hechizos (izquierda)
    local spellListBg = CreateFrame("Frame", nil, panel)
    spellListBg:SetPoint("TOPLEFT", 10, -75)
    spellListBg:SetWidth(360)
    spellListBg:SetHeight(450)
    local spellListBgTex = spellListBg:CreateTexture(nil, "BACKGROUND")
    spellListBgTex:SetAllPoints()
    spellListBgTex:SetTexture(0, 0, 0, 0.5)
    
    local spellListTitle = spellListBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellListTitle:SetPoint("TOP", 0, -5)
    spellListTitle:SetText("|cffFFD700Lista de Hechizos|r")
    
    -- Scroll frame para hechizos
    local scrollFrame = CreateFrame("ScrollFrame", "WCS_GrimoireScrollFrame", spellListBg)
    scrollFrame:SetPoint("TOPLEFT", 5, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(340)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    
    self.spellScrollChild = scrollChild
    self.spellButtons = {}
    
    -- Panel de detalles (derecha)
    local detailsBg = CreateFrame("Frame", nil, panel)
    detailsBg:SetPoint("TOPRIGHT", -10, -75)
    detailsBg:SetWidth(400)
    detailsBg:SetHeight(250)
    local detailsBgTex = detailsBg:CreateTexture(nil, "BACKGROUND")
    detailsBgTex:SetAllPoints()
    detailsBgTex:SetTexture(0, 0, 0, 0.5)
    
    local detailsTitle = detailsBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailsTitle:SetPoint("TOP", 0, -5)
    detailsTitle:SetText("|cffFFD700Detalles del Hechizo|r")
    
    self.detailsText = detailsBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.detailsText:SetPoint("TOPLEFT", 10, -30)
    self.detailsText:SetWidth(380)
    self.detailsText:SetJustifyH("LEFT")
    self.detailsText:SetText("Selecciona un hechizo para ver detalles")
    
    -- Panel de rotación (derecha abajo)
    local rotationBg = CreateFrame("Frame", nil, panel)
    rotationBg:SetPoint("TOPRIGHT", -10, -335)
    rotationBg:SetWidth(400)
    rotationBg:SetHeight(190)
    local rotationBgTex = rotationBg:CreateTexture(nil, "BACKGROUND")
    rotationBgTex:SetAllPoints()
    rotationBgTex:SetTexture(0, 0, 0, 0.5)
    
    local rotationTitle = rotationBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rotationTitle:SetPoint("TOP", 0, -5)
    rotationTitle:SetText("|cffFFD700Rotación Recomendada|r")
    
    self.rotationText = rotationBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.rotationText:SetPoint("TOPLEFT", 10, -30)
    self.rotationText:SetWidth(380)
    self.rotationText:SetJustifyH("LEFT")
    
    self.panel = panel
    
    -- Inicializar
    self:UpdateSpecButtons()
    self:UpdateSpellList()
    self:UpdateRotation()
end

function WCS_Grimoire:UpdateSpecButtons()
    for spec, btn in pairs(self.specButtons) do
        if spec == selectedSpec then
            btn.bg:SetTexture(0.4, 0.2, 0.6, 0.8)
        else
            btn.bg:SetTexture(0, 0, 0, 0.7)
        end
    end
end

function WCS_Grimoire:UpdateSpellList()
    -- Limpiar botones anteriores
    for i = 1, table.getn(self.spellButtons) do
        self.spellButtons[i]:Hide()
    end
    
    -- Escanear hechizos del jugador
    local playerSpells = self:ScanPlayerSpells()
    
    -- Filtrar hechizos por especialización
    local filteredSpells = {}
    for i = 1, table.getn(playerSpells) do
        local spell = playerSpells[i]
        if spell.school == selectedSpec then
            table.insert(filteredSpells, spell)
        end
    end
    
    -- Crear/actualizar botones
    for i = 1, table.getn(filteredSpells) do
        local spell = filteredSpells[i]
        local btn = self.spellButtons[i]
        
        if not btn then
            btn = CreateFrame("Button", nil, self.spellScrollChild)
            btn:SetWidth(330)
            btn:SetHeight(30)
            btn:SetPoint("TOPLEFT", 5, -(i-1)*32)
            
            local btnBg = btn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            btnBg:SetTexture(0.1, 0.1, 0.1, 0.8)
            btn.bg = btnBg
            
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btnText:SetPoint("LEFT", 5, 0)
            btnText:SetJustifyH("LEFT")
            btn.text = btnText
            
            self.spellButtons[i] = btn
        end
        
        btn.spell = spell
        btn.text:SetText(string.format("|cff9370DB%s|r (Rank %d)", spell.name, spell.rank))
        
        btn:SetScript("OnClick", function()
            selectedSpell = this.spell
            WCS_Grimoire:UpdateSpellDetails()
        end)
        
        btn:SetScript("OnEnter", function()
            this.bg:SetTexture(0.3, 0.2, 0.4, 0.9)
        end)
        
        btn:SetScript("OnLeave", function()
            this.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
        end)
        
        btn:Show()
    end
    
    self.spellScrollChild:SetHeight(math.max(1, table.getn(filteredSpells) * 32))
end

function WCS_Grimoire:UpdateSpellDetails()
    if not selectedSpell then
        self.detailsText:SetText("Selecciona un hechizo para ver detalles")
        return
    end
    
    local details = string.format(
        "|cffFFD700Nombre:|r %s\n" ..
        "|cffFFD700Rango:|r %d\n" ..
        "|cffFFD700Escuela:|r %s\n" ..
        "|cffFFD700Daño:|r %s\n" ..
        "|cffFFD700Maná:|r %s\n" ..
        "|cffFFD700Rango:|r %s\n" ..
        "|cffFFD700Tiempo de Lanzamiento:|r %s\n" ..
        "|cffFFD700Cooldown:|r %s",
        selectedSpell.name or "Desconocido",
        selectedSpell.rank or 0,
        selectedSpell.school or "Desconocido",
        selectedSpell.damage or "N/A",
        tostring(selectedSpell.mana or "N/A"),
        tostring(selectedSpell.range or "N/A") .. " yardas",
        selectedSpell.cast or "N/A",
        tostring(selectedSpell.cooldown or "N/A") .. "s"
    )
    
    self.detailsText:SetText(details)
end

function WCS_Grimoire:UpdateRotation()
    local rotation = ROTATIONS[selectedSpec]
    if not rotation then return end
    
    local text = ""
    for i = 1, table.getn(rotation) do
        text = text .. rotation[i] .. "\n"
    end
    
    self.rotationText:SetText(text)
end

function WCS_Grimoire:Show()
    if self.panel then self.panel:Show() end
end

function WCS_Grimoire:Hide()
    if self.panel then self.panel:Hide() end
end

_G["WCS_Grimoire"] = WCS_Grimoire

