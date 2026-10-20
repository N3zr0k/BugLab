-- Gemeinsame Bedienelemente der BugLab-Oberfläche: Standardhöhe, Entfärben und Knöpfe im BugLab-Stil.
local BugLab = _G.BugLab

-- Einheitliche Höhe für Auswahllisten, Knöpfe und Eingabefelder (Höhe der Vorlage WowStyle1DropdownTemplate).
BugLab.ROW_HEIGHT = 24

-- Entfärbt alle Grafiken eines Elements (Rahmen, Hintergrund), damit kein Bronze/Gold bleibt.
function BugLab.Desaturate(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.SetDesaturated then region:SetDesaturated(true) end
    end
end

-- Standardknopf des Spiels, aber dunkelgrau statt rot: Flächen entsättigt und abgedunkelt, damit er als Knopf erkennbar
-- bleibt, Schrift weiß. Das Standard-Hover wird entfärbt und BugLab-Blau getönt. Die Vorlage nutzt je nach Client
-- Normal-/Pushed-Texturen oder drei Teile.
BugLab.FACE_TINT = { 0.55, 0.55, 0.55 } -- Standardtextur entfärbt und neutral abgedunkelt
local HOVER_TINT = { 0.4, 0.73, 1 } -- BugLab-Blau

local function StyleButton(button)
    local tint = BugLab.FACE_TINT
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local tex = button[getter](button)
        if tex then tex:SetDesaturated(true); tex:SetVertexColor(unpack(tint)) end
    end
    for _, key in ipairs({ "Left", "Middle", "Center", "Right" }) do
        local tex = button[key]
        if tex and tex.SetDesaturated then tex:SetDesaturated(true); tex:SetVertexColor(unpack(tint)) end
    end
    local glow = button:GetHighlightTexture()
    if glow then glow:SetDesaturated(true); glow:SetVertexColor(unpack(HOVER_TINT)) end

    button:SetNormalFontObject("GameFontHighlight")
    button:SetHighlightFontObject("GameFontHighlight")
    button:SetDisabledFontObject("GameFontDisable")
end
BugLab.StyleButton = StyleButton

-- "red" = Standardfarbe des Spiels behalten (für zerstörerische Aktionen wie "Leeren").
function BugLab.CreateButton(parent, text, width, onClick, red)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, BugLab.ROW_HEIGHT)
    button:SetText(text)
    -- Standardbreite des Spiels: Textbreite plus Rand (UIButtonFitToTextBehaviorMixin); "width" gilt nur ohne diese Vorlage.
    if button.FitToText and text ~= "" then button:FitToText() end
    button:SetScript("OnClick", onClick)
    if not red then StyleButton(button) end
    return button
end
