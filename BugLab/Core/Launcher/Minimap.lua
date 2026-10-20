-- Minimap-Button über LibDBIcon plus LibDataBroker-Objekt (für Broker-Leisten wie Titan oder ChocolateBar).
-- Standardgröße und -rahmen von LibDBIcon, der Rahmen ist entsättigt (neutral statt Gold).
local BugLab = _G.BugLab
local L = BugLab.L

local NAME = "BugLab"
local ICON = BugLab.MEDIA_PATH .. "BugLab_Beetle_Outlined_32"

local INFO_ICON = "Interface\\FriendsFrame\\InformationIcon"
local INFO_SIZE = 14
local TOOLTIP_LOGO_SIZE, TOOLTIP_LOGO_ALPHA = 64, 1

-- Gemeinsame Handler für Minimap-Button, Broker-Objekt und Addon-Menü.
function BugLab:OnLauncherClick(mouseButton)
    if mouseButton == "RightButton" then
        self:OpenOptions()
    else
        self:ToggleWindow()
    end
end

-- Transparentes Logo neben dem Tooltip (wie bei AllTheThings), links, weil der Tooltip meist links vom Button hängt.
function BugLab:AttachTooltipLogo(tooltip)
    local logo = tooltip.bugLabLogo
    if not logo then
        logo = tooltip:CreateTexture(nil, "ARTWORK")
        logo:SetTexture(self.MEDIA_PATH .. "BugLab_Logo_Outlined_128")
        logo:SetSize(TOOLTIP_LOGO_SIZE, TOOLTIP_LOGO_SIZE)
        logo:SetAlpha(TOOLTIP_LOGO_ALPHA)
        tooltip.bugLabLogo = logo
        -- Der Tooltip gehört mehreren Addons: das Logo darf nur zu unserem Inhalt erscheinen.
        tooltip:HookScript("OnHide", function() logo:Hide() end)
    end
    logo:ClearAllPoints()
    logo:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -2, 0)
    logo:Show()
end

-- Hinweiszeile: i-Symbol entsättigt und in BugLab-Blau, passend zur Schrift. Ein Texturcode im Text kennt
-- keine Entsättigung; deshalb bleibt dort Platz frei und eine eigene Textur liegt darüber.
local INFO_SPACER = "|TInterface\\Common\\spacer:" .. INFO_SIZE .. ":" .. INFO_SIZE .. "|t"
function BugLab:AddInfoLine(tooltip, text)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then
        -- Tooltip ohne Namen: Symbol per Texturcode, nur eingefärbt (Vertexfarbe 102/187/255).
        tooltip:AddLine("|T" .. INFO_ICON .. ":" .. INFO_SIZE .. ":" .. INFO_SIZE .. ":0:0:64:64:0:64:0:64:102:187:255|t |cff66bbff" .. text .. "|r")
        return
    end
    tooltip:AddLine(INFO_SPACER .. " |cff66bbff" .. text .. "|r")
    local line = _G[name .. "TextLeft" .. tooltip:NumLines()]

    local icon = tooltip.bugLabInfoIcon
    if not icon then
        icon = tooltip:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(INFO_ICON)
        icon:SetSize(INFO_SIZE, INFO_SIZE)
        icon:SetDesaturated(true)
        icon:SetVertexColor(unpack(self.COLORS.BRIGHTBLUE_FONT_COLOR))
        tooltip.bugLabInfoIcon = icon
        tooltip:HookScript("OnHide", function() icon:Hide() end)
    end
    if line then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", line, "LEFT", 0, 0)
        icon:Show()
    else
        icon:Hide()
    end
end

function BugLab:FillLauncherTooltip(tooltip, withDragHint)
    self:AttachTooltipLogo(tooltip)
    tooltip:AddLine(self.NAME_COLORED)
    tooltip:AddLine(self:FormatVersion("999999"))
    tooltip:AddLine(L["LAUNCHER_LEFT"], 1, 1, 1)
    tooltip:AddLine(L["LAUNCHER_RIGHT"], 1, 1, 1)
    if withDragHint then tooltip:AddLine(L["LAUNCHER_DRAG"], 0.6, 0.6, 0.6) end
    -- Hinweis zum Reload-Hotkey: blaues i-Symbol (Spielgrafik) und blaue Schrift.
    if self.db.profile.reloadHotkey then
        tooltip:AddLine(" ")
        self:AddInfoLine(tooltip, L["LAUNCHER_RELOAD"])
    end
end

-- Der Rahmen von LibDBIcon ist eine Spielgrafik (MiniMap-TrackingBorder); nur die Farbe wird entfernt.
local function StyleButton(button)
    if button.border then button.border:SetDesaturated(true) end
end

-- Einrastpunkte beim Ziehen (Grad auf der Minimap) und Fangbereich; LibDBIcon kennt kein Einrasten.
local SNAP_POINTS = { 55, 90, 180 }
local SNAP_RANGE = 4

function BugLab:SnapMinimapPosition(pos)
    for _, point in ipairs(SNAP_POINTS) do
        if math.abs(pos - point) <= SNAP_RANGE then return point end
    end
    return pos
end

-- Läuft als Hook nach dem OnUpdate von LibDBIcon und korrigiert die Position, solange gezogen wird.
local function SnapWhileDragging(button)
    if button.isMouseDown ~= true then return end
    local db = BugLab.db.profile.minimap
    local snapped = BugLab:SnapMinimapPosition(db.minimapPos)
    if snapped ~= db.minimapPos then
        db.minimapPos = snapped
        LibStub("LibDBIcon-1.0"):SetButtonToPosition(button, snapped)
    end
end

-- Debug-Infos an Minimap-Buttons bei gedrückter Strg+Umschalt-Taste. Jede Info beginnt mit einem weißen Mittelpunkt.
local DOT = "|cffffffff\194\183|r "

-- Bezeichnung grau, Wert blau.
local function DebugLine(label, value)
    return DOT .. BugLab:Paint("GRAY", label .. ":") .. " " .. BugLab:Paint("BRIGHTBLUE", value)
end

function BugLab:GetButtonPosition(button)
    local db = button.db
    return (db and db.minimapPos) or button.minimapPos
end

function BugLab:GetDebugLines(button)
    local lines = {}
    local pos = self:GetButtonPosition(button)
    if pos then
        lines[#lines + 1] = DebugLine(L["DEBUG_MINIMAP_POS"], ("%.1f°"):format(pos))
        for _, point in ipairs(SNAP_POINTS) do
            if math.abs(pos - point) < 0.05 then lines[#lines + 1] = DebugLine(L["DEBUG_SNAP"], point .. "°") end
        end
    end
    lines[#lines + 1] = DebugLine(L["DEBUG_BUTTON"], tostring(button.registeredName or button:GetName() or "?"))
    return lines
end

-- Der Tooltip gehört je nach Addon GameTooltip oder dem eigenen Tooltip von LibDBIcon.
local function OwnedTooltip(button)
    local lib = LibStub("LibDBIcon-1.0")
    for _, tooltip in ipairs({ lib.tooltip, GameTooltip }) do
        if tooltip and tooltip:IsShown() and tooltip:IsOwned(button) then return tooltip end
    end
end

local function AppendDebugInfo(button)
    if not (IsControlKeyDown() and IsShiftKeyDown()) then return end
    local tooltip = OwnedTooltip(button)
    if not tooltip then return end
    local own = button == BugLab.minimapButton
    tooltip:AddLine(" ")
    if not own then tooltip:AddLine(BugLab.NAME_COLORED) end
    for _, line in ipairs(BugLab:GetDebugLines(button)) do tooltip:AddLine(line) end
    tooltip:Show() -- berechnet die Größe neu
end

function BugLab:HookDebugButton(button)
    if button.bugLabDebug == true then return end
    button.bugLabDebug = true
    button:HookScript("OnEnter", AppendDebugInfo)
end

-- Beim Drücken oder Loslassen der Tasten über einem Button den Tooltip neu aufbauen.
function BugLab:SetupDebugInfo()
    local dbicon = LibStub("LibDBIcon-1.0")
    for _, name in ipairs(dbicon:GetButtonList()) do self:HookDebugButton(dbicon:GetMinimapButton(name)) end
    dbicon.RegisterCallback(self, "LibDBIcon_IconCreated", function(_, button) self:HookDebugButton(button) end)

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    watcher:SetScript("OnEvent", function()
        for _, name in ipairs(dbicon:GetButtonList()) do
            local button = dbicon:GetMinimapButton(name)
            if button:IsMouseOver() and button:GetScript("OnEnter") then button:GetScript("OnEnter")(button) end
        end
    end)
    self.debugWatcher = watcher
end

function BugLab:SetupMinimapButton()
    if self.minimapButton then return end

    local ldb = LibStub("LibDataBroker-1.1")
    local object = ldb:NewDataObject(NAME, {
        type = "launcher",
        icon = ICON,
        label = NAME,
        OnClick = function(_, mouseButton) BugLab:OnLauncherClick(mouseButton) end,
        OnTooltipShow = function(tooltip) BugLab:FillLauncherTooltip(tooltip, true) end,
    })

    local dbicon = LibStub("LibDBIcon-1.0")
    dbicon:Register(NAME, object, self.db.profile.minimap)
    self.minimapButton = dbicon:GetMinimapButton(NAME)
    StyleButton(self.minimapButton)
    self.minimapButton:HookScript("OnUpdate", SnapWhileDragging)
    self:SetupDebugInfo()
end

function BugLab:SetMinimapButtonShown(shown)
    self.db.profile.minimap.hide = not shown
    local dbicon = LibStub("LibDBIcon-1.0")
    if shown then dbicon:Show(NAME) else dbicon:Hide(NAME) end
end
