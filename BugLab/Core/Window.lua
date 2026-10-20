-- Losgelöstes Hauptfenster im Rahmen des Blizzard-Uhrenfensters: Metallrahmen mit Portraitecke, Kopfleiste,
-- rotes X, Logo links oben, Name und Beschreibung daneben, Karteireiter rechts, Fußzeile mittig.
-- Alle Rahmengrafiken sind Spiel-Atlanten; fehlt einer, fällt das Fenster auf einfarbige Flächen zurück.
local BugLab = _G.BugLab
local L = BugLab.L
local C = BugLab.COLORS

local WIDTH, HEIGHT = 850, 500
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 850, 360, 1500, 950
local GRIP_X, GRIP_Y = -2, -4
local TAB_SIZE, TAB_GAP = 52, 10 -- Fallback-Reiter ohne Atlanten
local ICON_INSET = 6

-- Reiter wie im Charakterfenster (LargeSideTabButton): Atlanten für Hintergrund, Maske, Auswahl und Hover.
local SIDETAB = {
    background = "common-sidetab", mask = "common-sidetab-mask",
    selected = "common-sidetab-selected", hover = "common-sidetab-hover",
    iconExtent = 50, iconOffsetX = -4, -- Symbol sitzt wegen der leeren rechten Fläche etwas links
    gap = -2, top = 30,
}

-- Rahmenfarbe entfernen (neutral statt Bronze), passend zur grau-weiß-blauen Palette.
local DESATURATE = true

local FRAME = {
    corners = { -- Atlas, Anker, Versatz
        tl = { "UI-Frame-PortraitMetal-CornerTopLeft", "TOPLEFT", -12, 16 },
        tr = { "UI-Frame-Metal-CornerTopRight", "TOPRIGHT", 4, 16 },
        bl = { "UI-Frame-Metal-CornerBottomLeft", "BOTTOMLEFT", -12, -16 },
        br = { "UI-Frame-Metal-CornerBottomRight", "BOTTOMRIGHT", 4, -16 },
    },
    top = "_UI-Frame-Metal-EdgeTop", bottom = "_UI-Frame-Metal-EdgeBottom",
    left = "!UI-Frame-Metal-EdgeLeft", right = "!UI-Frame-Metal-EdgeRight",
    streaks = "_UI-Frame-TopTileStreaks",
    background = 374155, -- Hintergrund des Uhrenfensters
    headerHeight = 37,
    close = { normal = "RedButton-Exit", pushed = "RedButton-exit-pressed",
              disabled = "RedButton-Exit-Disabled", highlight = "RedButton-Highlight" },
    closeSize = 28.5, closeX = 1.5, closeY = 3.5,
}
local PLAIN_TOPLEFT = "UI-Frame-Metal-CornerTopLeft" -- ohne Portrait, für Popups
local LOGO_SIZE, LOGO_DX, LOGO_DY = 52.5, -9.5, 11 -- relativ zur Mitte der Portraitecke
local TITLE_Y, TAGLINE_DY = -3, -18 -- Name mittig in der Titelzeile, Beschreibung darunter
local CONTENT_TOP, CONTENT_SIDE, CONTENT_BOTTOM = 74, 17, 40 -- eine Zeile Abstand unter der Beschreibung
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local MODULE_ICONS = {
    Console = "BugLab_Console_128",
    Inspector = "BugLab_Inspector_128",
    Gallery = "BugLab_Gallery_128",
    Probe = "BugLab_Probe_128",
}

local function Fill(frame, layer, r, g, b, a)
    local tex = frame:CreateTexture(nil, layer)
    tex:SetColorTexture(r, g, b, a)
    return tex
end

-- Ein-Pixel-Rahmen aus vier Kanten (für Reiter, Inhaltsfläche und den Fallback).
local function AddBorder(frame)
    local edges = {}
    local anchors = {
        { "TOPLEFT", "TOPRIGHT", false },
        { "BOTTOMLEFT", "BOTTOMRIGHT", false },
        { "TOPLEFT", "BOTTOMLEFT", true },
        { "TOPRIGHT", "BOTTOMRIGHT", true },
    }
    for i, a in ipairs(anchors) do
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetPoint(a[1])
        edge:SetPoint(a[2])
        if a[3] then edge:SetWidth(1) else edge:SetHeight(1) end
        edges[i] = edge
    end
    frame.edges = edges
end

local function SetBorderColor(frame, color)
    for _, edge in ipairs(frame.edges) do
        edge:SetColorTexture(color[1], color[2], color[3], 1)
    end
end

local function SideTabInfo()
    if not (C_Texture and C_Texture.GetAtlasInfo) then return end
    for _, key in ipairs({ "background", "mask", "selected", "hover" }) do
        if not C_Texture.GetAtlasInfo(SIDETAB[key]) then return end
    end
    return C_Texture.GetAtlasInfo(SIDETAB.background)
end

local function UpdateTab(tab, selected)
    if tab.skinned == true then
        tab.selectedTex:SetShown(selected)
        tab.hoverTex:SetShown(tab.hovered and not selected)
        return
    end
    SetBorderColor(tab, (selected or tab.hovered) and C.BRIGHTBLUE_FONT_COLOR or C.DARKGRAY_COLOR)
    tab.icon:SetAlpha(selected and 1 or 0.7)
end

local function Atlas(tab, layer, name)
    local tex = tab:CreateTexture(nil, layer)
    tex:SetAtlas(name, true)
    tex:SetDesaturated(DESATURATE) -- Rahmen und Leuchten ohne Gold, wie der Fensterrahmen
    tex:SetPoint("CENTER")
    return tex
end

-- Reiter im Stil des Charakterfensters: Rahmenform aus Spielatlanten, Symbol per Formmaske zugeschnitten.
local function BuildSideTab(tab, info, name)
    tab.skinned = true
    tab:SetSize(info.width, info.height - 5) -- Höhe ohne den leeren Rand, damit die Reiter bündig stapeln
    Atlas(tab, "BACKGROUND", SIDETAB.background)

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(BugLab.MEDIA_PATH .. MODULE_ICONS[name])
    icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    icon:SetSize(SIDETAB.iconExtent, SIDETAB.iconExtent)
    icon:SetPoint("CENTER", SIDETAB.iconOffsetX, 0)
    tab.icon = icon

    -- Maske aus dem Atlas-Ausschnitt; die Umbruchmodi lassen sich bei SetAtlas nicht setzen.
    local maskInfo = C_Texture.GetAtlasInfo(SIDETAB.mask)
    local mask = tab:CreateMaskTexture()
    mask:SetTexture(maskInfo.file or maskInfo.filename, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetTexCoord(maskInfo.leftTexCoord, maskInfo.rightTexCoord, maskInfo.topTexCoord, maskInfo.bottomTexCoord)
    mask:SetSize(maskInfo.width, maskInfo.height)
    mask:SetPoint("CENTER")
    icon:AddMaskTexture(mask)

    tab.selectedTex = Atlas(tab, "OVERLAY", SIDETAB.selected)
    tab.hoverTex = Atlas(tab, "OVERLAY", SIDETAB.hover)
    tab.selectedTex:Hide()
    tab.hoverTex:Hide()

    tab:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", SIDETAB.iconOffsetX + 1, -1) end)
    tab:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", SIDETAB.iconOffsetX, 0) end)
end

-- Fallback ohne Atlanten: schwarzes Feld mit dünnem Rahmen.
local function BuildFlatTab(tab, name)
    tab:SetSize(TAB_SIZE, TAB_SIZE)
    Fill(tab, "BACKGROUND", 0, 0, 0, 0.9):SetAllPoints()
    AddBorder(tab)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
    tab.icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    tab.icon:SetTexture(BugLab.MEDIA_PATH .. MODULE_ICONS[name])
end

local function CreateTab(window, name)
    local tab = CreateFrame("Button", nil, window)
    tab.module = name
    local info = SideTabInfo()
    if info then BuildSideTab(tab, info, name) else BuildFlatTab(tab, name) end

    tab:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateTab(self, window.selected == name)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
        GameTooltip:SetText(BugLab:ModuleName(name))
        GameTooltip:AddLine(L["MODULE_" .. name:upper() .. "_DESC"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function(self)
        self.hovered = false
        UpdateTab(self, window.selected == name)
        GameTooltip:Hide()
    end)
    tab:SetScript("OnClick", function() BugLab:SelectTab(name) end)
    return tab
end

-- Senkrechter Versatz des i-ten Reiters ab Oberkante des Fensters.
local function tabOffset(tab, index)
    if tab.skinned == true then
        return SIDETAB.top + (index - 1) * (tab:GetHeight() - SIDETAB.gap)
    end
    return 60 + (index - 1) * (TAB_SIZE + TAB_GAP)
end

local function SavePosition(window)
    local point, _, relPoint, x, y = window:GetPoint()
    BugLab.db.profile.window = {
        point = point, relPoint = relPoint, x = x, y = y,
        width = window:GetWidth(), height = window:GetHeight(),
    }
end

local function RestorePosition(window)
    local pos = BugLab.db.profile.window
    window:ClearAllPoints()
    if pos then
        if pos.width and pos.height then window:SetSize(math.max(pos.width, MIN_WIDTH), math.max(pos.height, MIN_HEIGHT)) end
        window:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        window:SetPoint("CENTER")
    end
end

local function AtlasesAvailable()
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local names = { FRAME.top, FRAME.bottom, FRAME.left, FRAME.right }
    for _, corner in pairs(FRAME.corners) do names[#names + 1] = corner[1] end
    for _, atlas in ipairs(names) do
        if not C_Texture.GetAtlasInfo(atlas) then return false end
    end
    return true
end

-- Metallrahmen aus Spielgrafiken. Gibt die Portraitecke zurück (Bezug für das Logo).
local function BuildMetalFrame(window, plain)
    local function Tex(layer, sublevel)
        local tex = window:CreateTexture(nil, layer, nil, sublevel)
        if DESATURATE then tex:SetDesaturated(true) end
        return tex
    end

    local bg = Tex("BACKGROUND", -7)
    bg:SetTexture(FRAME.background, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, -2) -- 4 px tiefer, bis unter den Rahmen

    if C_Texture.GetAtlasInfo(FRAME.streaks) then
        local streaks = Tex("BACKGROUND", -6)
        streaks:SetAtlas(FRAME.streaks)
        streaks:SetHorizTile(true)
        streaks:SetPoint("TOPLEFT", 6, -3)
        streaks:SetPoint("TOPRIGHT", -2, -3)
        streaks:SetHeight(FRAME.headerHeight)
    end

    local corners = {}
    for key, c in pairs(FRAME.corners) do
        local tex = Tex("OVERLAY", 2)
        tex:SetAtlas(plain and key == "tl" and PLAIN_TOPLEFT or c[1], true)
        tex:SetPoint(c[2], window, c[2], c[3], c[4])
        corners[key] = tex
    end

    -- Kanten füllen den Raum zwischen den Ecken, gekachelt in ihrer Laufrichtung.
    local function Edge(atlas, horizontal, a, aPoint, b, bPoint)
        local tex = Tex("OVERLAY", 1)
        tex:SetAtlas(atlas, true)
        if horizontal then tex:SetHorizTile(true) else tex:SetVertTile(true) end
        tex:SetPoint(aPoint[1], a, aPoint[2], 0, 0)
        tex:SetPoint(bPoint[1], b, bPoint[2], 0, 0)
    end
    Edge(FRAME.top, true, corners.tl, { "TOPLEFT", "TOPRIGHT" }, corners.tr, { "BOTTOMRIGHT", "BOTTOMLEFT" })
    Edge(FRAME.bottom, true, corners.bl, { "TOPLEFT", "TOPRIGHT" }, corners.br, { "BOTTOMRIGHT", "BOTTOMLEFT" })
    Edge(FRAME.left, false, corners.tl, { "TOPLEFT", "BOTTOMLEFT" }, corners.bl, { "BOTTOMRIGHT", "TOPRIGHT" })
    Edge(FRAME.right, false, corners.tr, { "TOPLEFT", "BOTTOMLEFT" }, corners.br, { "BOTTOMRIGHT", "TOPRIGHT" })
    return corners.tl
end

-- Fallback ohne Atlanten: einfarbige Fläche mit dünnem Rahmen.
local function BuildFlatFrame(window)
    Fill(window, "BACKGROUND", 0.02, 0.02, 0.02, 0.96):SetAllPoints()
    AddBorder(window)
    SetBorderColor(window, C.DARKGRAY_COLOR)
end

-- Rahmen im Stil des Hauptfensters für Popups (ohne Portrait); fehlen die Atlanten, bleibt eine flache Fläche.
function BugLab:SkinFrame(frame)
    if AtlasesAvailable() and C_Texture.GetAtlasInfo(PLAIN_TOPLEFT) then
        BuildMetalFrame(frame, true)
    else
        BuildFlatFrame(frame)
    end
end

-- Logo in der Portraitecke, hinter dem Ring der Ecke, auf einer dunklen Kreisfläche.
local function BuildLogo(window, anchor)
    local disc = window:CreateTexture(nil, "BACKGROUND", nil, -4)
    disc:SetColorTexture(0, 0, 0, 0.7)
    disc:SetSize(LOGO_SIZE, LOGO_SIZE)
    disc:SetPoint("CENTER", anchor, "CENTER", LOGO_DX, LOGO_DY)
    local mask = window:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(LOGO_SIZE, LOGO_SIZE)
    mask:SetPoint("CENTER", disc, "CENTER", 0, 0)
    disc:AddMaskTexture(mask)

    local logo = window:CreateTexture(nil, "BACKGROUND", nil, -3)
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("CENTER", disc, "CENTER", 0, 0)
    logo:SetTexture(BugLab.MEDIA_PATH .. "BugLab_Logo_Outlined_128")
end

local function BuildCloseButton(window, skinned)
    local close = CreateFrame("Button", nil, window)
    close:SetFrameLevel(window:GetFrameLevel() + 30)
    close:SetScript("OnClick", function() window:Hide() end)
    if skinned and C_Texture and C_Texture.GetAtlasInfo(FRAME.close.normal) then
        close:SetSize(FRAME.closeSize, FRAME.closeSize)
        close:SetPoint("TOPRIGHT", FRAME.closeX, FRAME.closeY)
        close:SetNormalAtlas(FRAME.close.normal)
        close:SetPushedAtlas(FRAME.close.pushed)
        close:SetDisabledAtlas(FRAME.close.disabled)
        close:SetHighlightAtlas(FRAME.close.highlight)
    else
        close:SetSize(22, 22)
        close:SetPoint("TOPRIGHT", -6, -5)
        local label = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER")
        label:SetText("X")
    end
    return close
end

-- Auch für andere Fenster (z. B. das Inspector-Popup): X-Knopf oben rechts, schließt das Fenster.
BugLab.CreateCloseButton = BuildCloseButton

-- Symbole links neben dem Schließen-Knopf (Zahnrad, BugSack): flach in der Titelzeile wie die Leiste eines
-- macOS-Fensters, ohne Kasten. Grau, beim Überfahren in BugLab-Blau.
local HEADER = { size = 16, gap = 8, scale = 1.25, gear = "Interface\\WorldMap\\GEAR_64GREY" }

local function BuildHeaderIcon(window, anchor, gap, texture, tooltip, onClick, originalOnHover)
    local button = CreateFrame("Button", nil, window)
    button:SetSize(HEADER.size, HEADER.size)
    button:SetScale(HEADER.scale)
    button:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    button:SetFrameLevel(window:GetFrameLevel() + 30)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetDesaturated(true)
    button.icon = icon

    -- originalOnHover: beim Überfahren erscheint das Symbol in seinen Originalfarben (z. B. das BugSack-Icon).
    -- button.alert (BugSack hat Fehler): das Symbol ist rot statt grau, beim Überfahren in Originalfarben.
    local function Paint(hover)
        button.hover = hover
        if originalOnHover then icon:SetDesaturated(button.alert or not hover) end
        if button.alert then
            -- Dauerhaft rot, solange Fehler vorliegen; beim Überfahren etwas heller.
            if hover then icon:SetVertexColor(1, 0.45, 0.4) else icon:SetVertexColor(1, 0.15, 0.15) end
        elseif originalOnHover and hover then
            icon:SetVertexColor(1, 1, 1)
        elseif hover then
            -- Das graue Symbol getönt bliebe matt; additiv gemischt leuchtet es kräftig in BugLab-Blau.
            icon:SetVertexColor(0.3, 0.75, 1)
        else
            icon:SetVertexColor(unpack(C.LIGHTGRAY_FONT_COLOR))
        end
        if not originalOnHover then icon:SetBlendMode(hover and "ADD" or "BLEND") end
    end
    Paint(false)
    button.Repaint = function() Paint(button.hover and true or false) end
    if texture then icon:SetTexture(texture) end
    button:SetScript("OnEnter", function(self)
        Paint(true)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        tooltip(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() Paint(false); GameTooltip:Hide() end)
    button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", 1, -1) end)
    button:SetScript("OnMouseUp", function() icon:ClearAllPoints(); icon:SetAllPoints() end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton) onClick(mouseButton) end)
    return button
end

-- Das Zahnrad öffnet die Einstellungen; der BugSack-Absprung (Icon von BugSack, Fehleranzahl im Tooltip) ist nur
-- sichtbar, wenn BugSack installiert ist.
local function BuildHeaderIcons(window, close)
    local gear = BuildHeaderIcon(window, close, HEADER.gap, HEADER.gear,
        function(tip) tip:SetText(L["OPEN_OPTIONS"]) end,
        function(mouseButton) if mouseButton ~= "RightButton" then BugLab:OpenOptions() end end)
    window.settingsButton = gear

    local sack = BuildHeaderIcon(window, gear, HEADER.gap, nil,
        function(tip)
            tip:SetText(L["OPEN_BUGSACK"])
            local count = BugLab:GetBugSackCount()
            if count and count > 0 then
                tip:AddLine(L["BUGSACK_COUNT"]:format(count), 1, 0.35, 0.3)
            elseif count then
                tip:AddLine(L["BUGSACK_NONE"], 0.6, 0.6, 0.6)
            end
            tip:AddLine(L["BUGSACK_CLEAR_HINT"], 0.6, 0.6, 0.6)
        end,
        function(mouseButton)
            if mouseButton == "RightButton" then BugLab:ClearBugSack() else BugLab:OpenBugSack() end
        end, true)
    sack:Hide()
    window.bugSackButton = sack
end

-- Größenänderung: Griff unten rechts wie bei den Chatfenstern, Größe wird mit der Position gespeichert.
local function BuildResizeGrip(window)
    window:SetResizable(true)
    if window.SetResizeBounds then
        window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    else
        window:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
        window:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
    end
    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", GRIP_X, GRIP_Y)
    grip:SetFrameLevel(window:GetFrameLevel() + 30)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        SavePosition(window)
    end)
    window.grip = grip
end

function BugLab:CreateWindow()
    local window = CreateFrame("Frame", "BugLabWindow", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    window:Hide()
    RestorePosition(window)
    -- ESC schließt das Fenster wie die Standardfenster.
    tinsert(UISpecialFrames, "BugLabWindow")

    local skinned = AtlasesAvailable()
    if skinned then
        BuildLogo(window, BuildMetalFrame(window))
    else
        BuildFlatFrame(window)
    end
    BuildHeaderIcons(window, BuildCloseButton(window, skinned))
    BuildResizeGrip(window)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, TITLE_Y)
    title:SetText(self.NAME_COLORED)
    local tagline = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagline:SetPoint("TOP", title, "BOTTOM", 0, TAGLINE_DY)
    tagline:SetTextColor(unpack(C.LIGHTGRAY_FONT_COLOR))
    tagline:SetText(L["SLOGAN"])

    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", CONTENT_SIDE, -CONTENT_TOP)
    content:SetPoint("BOTTOMRIGHT", -CONTENT_SIDE, CONTENT_BOTTOM)
    Fill(content, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
    AddBorder(content)
    SetBorderColor(content, C.DARKGRAY_COLOR)
    window.content = content

    local footer = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer:SetPoint("BOTTOM", 0, 14)
    footer:SetText(self.NAME_COLORED .. " " .. self:FormatVersion("999999")
        .. " |cff999999· " .. L["FOOTER_CMD"] .. "|r")

    window.tabs, window.pages = {}, {}
    for _, name in ipairs(self.MODULES) do
        window.tabs[name] = CreateTab(window, name)
        -- Leere Seite je Modul; das Modul füllt sie später über BugLab:GetPage().
        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints()
        page:Hide()
        window.pages[name] = page
    end

    self.window = window
    return window
end

-- Zeigt nur Reiter aktivierter Module und hält die Auswahl gültig.
function BugLab:RefreshWindow()
    local window = self.window
    if not window then return end
    self:UpdateBugSackButton()

    local visible = self:GetVisibleModules()
    for _, tab in pairs(window.tabs) do tab:Hide() end
    for i, name in ipairs(visible) do
        local tab = window.tabs[name]
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", window, "TOPRIGHT", tab.skinned == true and 0 or 10, -tabOffset(tab, i))
        tab:Show()
    end

    local selected = window.selected
    if not (selected and self:IsModuleEnabled(selected)) then selected = visible[1] end
    self:SelectTab(selected)
end

function BugLab:SelectTab(name)
    local window = self.window
    if not window then return end
    window.selected = name
    for module, page in pairs(window.pages) do
        if module == name then page:Show() else page:Hide() end
    end
    for module, tab in pairs(window.tabs) do UpdateTab(tab, module == name) end
end
