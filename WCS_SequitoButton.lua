--[[
    WCS_SequitoButton.lua - Botón Épico para El Séquito del Terror
    El botón más hermoso jamás creado
    Compatible con Lua 5.0 (WoW 1.12 / Turtle WoW)
]]--

function WCS_BrainUI:CreateSequitoButton(section)
    -- ========================================================================
    -- BOTÓN SÉQUITO - EL BOTÓN MÁS HERMOSO JAMAS CREADO
    -- ========================================================================
    local sequitoBtn = CreateFrame("Button", "WCS_SequitoButton", section)
    sequitoBtn:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -105)
    sequitoBtn:SetWidth(200)
    sequitoBtn:SetHeight(35)
    
    -- Fondo con gradiente oscuro
    local bgTexture = sequitoBtn:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints(sequitoBtn)
    bgTexture:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bgTexture:SetVertexColor(0.1, 0.05, 0.15, 1)
    sequitoBtn.bgTexture = bgTexture
    
    -- Borde brillante con efecto fel
    local borderTexture = sequitoBtn:CreateTexture(nil, "BORDER")
    borderTexture:SetPoint("TOPLEFT", sequitoBtn, "TOPLEFT", -2, 2)
    borderTexture:SetPoint("BOTTOMRIGHT", sequitoBtn, "BOTTOMRIGHT", 2, -2)
    borderTexture:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    borderTexture:SetVertexColor(0.0, 1.0, 0.5, 0.8)
    sequitoBtn.borderTexture = borderTexture
    
    -- Efecto de brillo superior
    local glowTop = sequitoBtn:CreateTexture(nil, "OVERLAY")
    glowTop:SetPoint("TOP", sequitoBtn, "TOP", 0, 0)
    glowTop:SetWidth(200)
    glowTop:SetHeight(8)
    glowTop:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    glowTop:SetVertexColor(0.0, 1.0, 0.5, 0.6)
    glowTop:SetBlendMode("ADD")
    sequitoBtn.glowTop = glowTop
    
    -- Efecto de brillo inferior
    local glowBottom = sequitoBtn:CreateTexture(nil, "OVERLAY")
    glowBottom:SetPoint("BOTTOM", sequitoBtn, "BOTTOM", 0, 0)
    glowBottom:SetWidth(200)
    glowBottom:SetHeight(8)
    glowBottom:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    glowBottom:SetVertexColor(0.58, 0.51, 0.79, 0.6)
    glowBottom:SetBlendMode("ADD")
    sequitoBtn.glowBottom = glowBottom
    
    -- Icono del séquito (calavera warlock)
    local icon = sequitoBtn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", sequitoBtn, "LEFT", 8, 0)
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_Skull")
    sequitoBtn.icon = icon
    
    -- Texto principal con efecto de sombra
    local shadowText = sequitoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    shadowText:SetPoint("CENTER", sequitoBtn, "CENTER", 11, -1)
    shadowText:SetText("EL SÉQUITO")
    shadowText:SetTextColor(0, 0, 0, 0.8)
    
    local mainText = sequitoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainText:SetPoint("CENTER", sequitoBtn, "CENTER", 10, 0)
    mainText:SetText("EL SÉQUITO")
    mainText:SetTextColor(0.0, 1.0, 0.5, 1)
    sequitoBtn.mainText = mainText
    
    -- Subtexto
    local subText = sequitoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subText:SetPoint("BOTTOM", sequitoBtn, "BOTTOM", 10, 3)
    subText:SetText("del Terror")
    subText:SetTextColor(0.58, 0.51, 0.79, 1)
    sequitoBtn.subText = subText
    
    -- Variables de animación
    sequitoBtn.pulseTime = 0
    sequitoBtn.glowAlpha = 0.6
    sequitoBtn.glowDirection = 1
    
    -- Script de animación (efecto de pulso)
    sequitoBtn:SetScript("OnUpdate", function()
        this.pulseTime = this.pulseTime + arg1
        
        -- Efecto de pulso en el brillo
        this.glowAlpha = this.glowAlpha + (this.glowDirection * arg1 * 0.8)
        if this.glowAlpha >= 1.0 then
            this.glowAlpha = 1.0
            this.glowDirection = -1
        elseif this.glowAlpha <= 0.3 then
            this.glowAlpha = 0.3
            this.glowDirection = 1
        end
        
        this.glowTop:SetAlpha(this.glowAlpha)
        this.glowBottom:SetAlpha(this.glowAlpha)
        
        -- Efecto de zoom del icono (muy sutil)
        local scale = 1.0 + math.sin(this.pulseTime * 2) * 0.05
        this.icon:SetWidth(28 * scale)
        this.icon:SetHeight(28 * scale)
    end)
    
    -- Efecto hover (mouse encima)
    sequitoBtn:SetScript("OnEnter", function()
        this.bgTexture:SetVertexColor(0.15, 0.08, 0.2, 1)
        this.borderTexture:SetVertexColor(0.0, 1.0, 0.5, 1.0)
        this.mainText:SetTextColor(1.0, 1.0, 1.0, 1)
        
        -- Tooltip premium v9.0
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("El Sequito del Terror", 1.0, 0.82, 0.0)
        GameTooltip:AddLine("|cFFAAAAAAClan UI v9.0 - Grimorio del Sequito|r", 1, 1, 1)
        GameTooltip:AddLine(" ", 0, 0, 0)
        GameTooltip:AddLine("|cFFFFD700=== Modulos Disponibles ===|r", 1, 1, 1)
        GameTooltip:AddLine("|cFF00FF80•|r Clan Panel - Miembros Online", 0.9, 0.9, 1)
        GameTooltip:AddLine("|cFF00FF80•|r Estadisticas de Combate", 0.9, 0.9, 1)
        GameTooltip:AddLine("|cFF00FF80•|r Banco del Sequito", 0.9, 0.9, 1)
        GameTooltip:AddLine("|cFF00FF80•|r Gestion de Raid", 0.9, 0.9, 1)
        GameTooltip:AddLine("|cFF9482C9•|r Grimorio Warlock", 0.9, 0.7, 1)
        GameTooltip:AddLine("|cFF9482C9•|r Invocaciones y Recursos", 0.9, 0.7, 1)
        GameTooltip:AddLine(" ", 0, 0, 0)
        GameTooltip:AddLine("|cFFFFD700Click|r para abrir el Grimorio", 1, 0.9, 0.3)
        GameTooltip:Show()
    end)
    
    sequitoBtn:SetScript("OnLeave", function()
        this.bgTexture:SetVertexColor(0.1, 0.05, 0.15, 1)
        this.borderTexture:SetVertexColor(0.0, 1.0, 0.5, 0.8)
        this.mainText:SetTextColor(0.0, 1.0, 0.5, 1)
        GameTooltip:Hide()
    end)
    
    -- Click para abrir /sequito
    sequitoBtn:SetScript("OnClick", function()
        -- Efecto visual de click
        this.bgTexture:SetVertexColor(0.0, 0.5, 0.25, 1)
        this.mainText:SetTextColor(1.0, 1.0, 1.0, 1)
        
        -- Ejecutar comando
        if WCS_ClanUI and WCS_ClanUI.ToggleMainFrame then
            WCS_ClanUI:ToggleMainFrame()
        end
        
        -- Restaurar colores después de 0.1 segundos
        this:SetScript("OnUpdate", function()
            if not this.clickTime then
                this.clickTime = 0
            end
            this.clickTime = this.clickTime + arg1
            if this.clickTime >= 0.1 then
                this.bgTexture:SetVertexColor(0.1, 0.05, 0.15, 1)
                this.mainText:SetTextColor(0.0, 1.0, 0.5, 1)
                this.clickTime = nil
                -- Restaurar el script OnUpdate original
                this:SetScript("OnUpdate", function()
                    this.pulseTime = this.pulseTime + arg1
                    this.glowAlpha = this.glowAlpha + (this.glowDirection * arg1 * 0.8)
                    if this.glowAlpha >= 1.0 then
                        this.glowAlpha = 1.0
                        this.glowDirection = -1
                    elseif this.glowAlpha <= 0.3 then
                        this.glowAlpha = 0.3
                        this.glowDirection = 1
                    end
                    this.glowTop:SetAlpha(this.glowAlpha)
                    this.glowBottom:SetAlpha(this.glowAlpha)
                    local scale = 1.0 + math.sin(this.pulseTime * 2) * 0.05
                    this.icon:SetWidth(28 * scale)
                    this.icon:SetHeight(28 * scale)
                end)
            end
        end)
    end)
    
    -- Hacer el botón clickeable
    sequitoBtn:EnableMouse(true)
    sequitoBtn:RegisterForClicks("LeftButtonUp")
    
    self.sequitoBtn = sequitoBtn
    return sequitoBtn
end
