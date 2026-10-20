-- Inspector: beliebige Frames, Texturen und Schriften per Pick wählen, alle Angaben lesen (Größe, Anker, Texturen, Schriften,
-- Skripte) und eigene Frames verändern. Blizzard-Frames sind nur zur Ansicht. Die Datenlogik liegt in Core/API/Inspect.lua.
local BugLab = _G.BugLab
local L = BugLab.L
local Inspector = BugLab:NewModule("Inspector", "AceEvent-3.0")

local ROW_HEIGHT, Desaturate, Button = BugLab.ROW_HEIGHT, BugLab.Desaturate, BugLab.CreateButton
local PICK_INTERVAL = 0.1
local MAX_MENU_ENTRIES = 60
local OUTLINE_PAUSE = 2
local CONTROL_WIDTH = 170 -- Breite der Bedienelemente rechts neben den Werten
local EDIT_FIELDS = { x = true, y = true, width = true, height = true, alpha = true, scale = true, color = true }
local MODE_NEXT = { info = "code", code = "changes", changes = "info" }
local MODE_BUTTON = { info = "INS_CODE", code = "INS_CHANGES", changes = "INS_INFO" }
local BLUE = { 0.4, 0.73, 1, 1 }
local HOVER = { 1, 1, 1, 0.9 }

-- Eingabefelder der Änderungszeile: Schlüssel für ApplyEdit und Locale-Schlüssel der Bezeichnung.
local FIELDS = {
    { "x", "INS_FIELD_X" }, { "y", "INS_FIELD_Y" }, { "width", "INS_FIELD_W" }, { "height", "INS_FIELD_H" },
    { "alpha", "INS_FIELD_ALPHA" }, { "scale", "INS_FIELD_SCALE" },
}

-- Markierung ---------------------------------------------------------------------------------------------------------

-- Rahmen aus vier Kanten um ein Objekt (Frame oder Bereich); wird mit Show/Hide und Mark() bewegt.
local function CreateOutline(thickness, color)
    local outline = CreateFrame("Frame", nil, UIParent)
    outline:SetFrameStrata("TOOLTIP")
    outline:EnableMouse(false)
    for _, def in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                           { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local edge = outline:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(unpack(color))
        edge:SetPoint(def[1]); edge:SetPoint(def[2])
        if def[3] then edge:SetHeight(thickness) else edge:SetWidth(thickness) end
    end
    outline:Hide()
    return outline
end

-- Markierung um ein Objekt. Eigene Objekte werden am Objekt verankert (folgt ihm). Bei Spiel-Frames (oft geschützt oder
-- gesperrt, Verankern kann fehlschlagen oder nichts zeichnen) wird das Rechteck aus GetRect berechnet und fest gesetzt.
-- Gibt true zurück, wenn eine Markierung steht, sonst false und den Fehlertext.
local function MarkByRect(outline, obj)
    local left, bottom, width, height = obj:GetRect()
    if not left then error("no rect") end
    local scale = (obj.GetEffectiveScale and obj:GetEffectiveScale())
        or (obj.GetParent and obj:GetParent() and obj:GetParent():GetEffectiveScale()) or 1
    local ui = UIParent:GetEffectiveScale()
    local factor = scale / ui
    outline:ClearAllPoints()
    outline:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * factor - 1, bottom * factor - 1)
    outline:SetSize(width * factor + 2, height * factor + 2)
end

local function MarkByAnchor(outline, obj)
    outline:ClearAllPoints()
    outline:SetPoint("TOPLEFT", obj, "TOPLEFT", -1, 1)
    outline:SetPoint("BOTTOMRIGHT", obj, "BOTTOMRIGHT", 1, -1)
end

local function Mark(outline, obj)
    if not obj then outline:Hide(); return true end
    -- Ein verborgenes Objekt hat keine verlässliche Bildschirmposition: keine (irreführende) Markierung.
    if obj.IsVisible and obj:IsVisible() == false then outline:Hide(); return true end
    local ok, err
    if BugLab:ObjectOwner(obj) == "BugLab" then
        ok, err = pcall(MarkByAnchor, outline, obj)
    end
    if not ok then ok, err = pcall(MarkByRect, outline, obj) end
    outline:SetShown(ok)
    return ok, err
end

-- Pick ---------------------------------------------------------------------------------------------------------------

function Inspector:BuildPicker()
    local picker = CreateFrame("Frame", nil, UIParent)
    picker:SetAllPoints(UIParent)
    picker:SetFrameStrata("TOOLTIP")
    picker:EnableMouse(true) -- fängt Klicks ab, damit beim Wählen nichts im Spiel ausgelöst wird
    picker:EnableMouseWheel(true)
    picker:EnableKeyboard(true)
    picker:SetPropagateKeyboardInput(false)
    picker:Hide()

    local banner = CreateFrame("Frame", nil, picker)
    banner:SetFrameStrata("TOOLTIP")
    banner:SetFrameLevel(picker:GetFrameLevel() + 5)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -40)
    banner:SetSize(560, 60)
    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.85)
    banner.name = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    banner.name:SetPoint("TOP", 0, -7)
    banner.hint = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    banner.hint:SetPoint("BOTTOM", 0, 7)
    banner.hint:SetText(BugLab:Paint("LIGHTGRAY", L["INS_PICK_HINT"]))
    -- Sichtbarer Ausweg: bricht die Wahl ab, ohne etwas auszuwählen.
    local none = Button(banner, L["INS_PICK_NONE"], 140, function() self:StopPick() end)
    none:SetPoint("TOP", banner, "BOTTOM", 0, -6)

    self.hoverOutline = CreateOutline(1, HOVER)
    self.picker, self.banner = picker, banner
    self.ignore = self.ignore or {}
    self.ignore[picker], self.ignore[banner], self.ignore[self.hoverOutline], self.ignore[none] = true, true, true, true

    local elapsed = 0
    picker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < PICK_INTERVAL then return end
        elapsed = 0
        self:UpdatePick()
    end)
    picker:SetScript("OnKeyDown", function(_, key)
        if key == "ENTER" or key == "SPACE" then self:ChoosePick()
        elseif key == "ESCAPE" then self:StopPick()
        elseif key == "UP" then self:MovePick(-1)
        elseif key == "DOWN" then self:MovePick(1) end
    end)
    picker:SetScript("OnMouseWheel", function(_, delta) self:MovePick(-delta) end)
    picker:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then self:ChoosePick() else self:StopPick() end
    end)
    return picker
end

-- "popup": Das Ergebnis erscheint im kleinen Popup (Tastenkürzel, /bl pick); sonst direkt auf der Inspector-Seite.
function Inspector:StartPick(popup)
    local picker = self.picker or self:BuildPicker()
    self.pickPopup = popup and true or false
    self.stack, self.pickIndex = {}, 1
    self.lastX, self.lastY = nil, nil
    picker:Show()
end

function Inspector:StopPick()
    if not self.picker then return end
    self.picker:Hide()
    Mark(self.hoverOutline, nil)
end

function Inspector:UpdatePick()
    -- Nur neu suchen, wenn sich die Maus bewegt hat (die Suche läuft über alle Frames des Spiels).
    local x, y = GetCursorPosition()
    if self.lastX == x and self.lastY == y and self.stack and #self.stack > 0 then return end
    self.lastX, self.lastY = x, y
    local previous = self.stack and self.stack[self.pickIndex]
    self.stack = BugLab:GetObjectsUnderMouse(self.ignore)
    -- Auswahl innerhalb des Stapels beibehalten, solange das Objekt noch unter der Maus liegt.
    local index = 1
    if previous and self.keepIndex then
        for i, obj in ipairs(self.stack) do if obj == previous then index = i; break end end
    end
    self.pickIndex = math.min(index, math.max(#self.stack, 1))
    self:ShowHover()
end

function Inspector:ShowHover()
    local obj = self.stack[self.pickIndex]
    Mark(self.hoverOutline, obj)
    if obj then
        local kind = obj.GetObjectType and obj:GetObjectType() or "?"
        self.banner.name:SetText(BugLab:Paint("WHITE", BugLab:ObjectName(obj)) .. " " .. BugLab:Paint("GRAY", "(" .. kind .. ")")
            .. "  " .. BugLab:Paint("BRIGHTBLUE", self.pickIndex .. "/" .. #self.stack))
        -- Bei Texturen zusätzlich deren Name (Atlas oder Datei), damit man beim Picken gleich sieht, welche es ist.
        if kind == "Texture" then
            local name = BugLab:TextureName(obj)
            if name then
                if #name > 70 then name = "..." .. name:sub(-67) end
                self.banner.name:SetText(self.banner.name:GetText() .. "\n" .. BugLab:Paint("BRIGHTBLUE", name))
            end
        end
    else
        self.banner.name:SetText(BugLab:Paint("GRAY", "-"))
    end
end

-- Pfeiltasten und Mausrad wechseln innerhalb des Stapels unter der Maus (Vordergrund bis Hintergrund).
function Inspector:MovePick(delta)
    if #self.stack == 0 then return end
    self.pickIndex = math.max(1, math.min(#self.stack, self.pickIndex + delta))
    self.keepIndex = true
    self:ShowHover()
end

function Inspector:ChoosePick()
    local obj = self.stack and self.stack[self.pickIndex]
    self:StopPick()
    self.keepIndex = false
    if obj then
        -- Der Stapel bleibt für das Popup erhalten, damit man dort die Ebene wechseln kann.
        self.layers, self.layerIndex = self.stack, self.pickIndex
        self:Select(obj, self.pickPopup)
    end
end

-- Wechselt im Popup die Ebene (Vordergrund bis Hintergrund) der letzten Wahl.
function Inspector:MoveLayer(delta, popup)
    if not (self.layers and #self.layers > 0) then return end
    local index = math.max(1, math.min(#self.layers, (self.layerIndex or 1) + delta))
    if index == self.layerIndex then return end
    self.layerIndex = index
    self:Select(self.layers[index], popup)
end

-- Anzeige -------------------------------------------------------------------------------------------------------------

-- Wählt ein Objekt aus und zeigt es im Inspector.
function Inspector:Select(obj, popup)
    self.target = obj
    if self.layers then
        local found
        for i, o in ipairs(self.layers) do if o == obj then found = i; break end end
        if found then self.layerIndex = found else self.layers = nil end
    end
    self.mode = "info"
    if not self.selectOutline then
        self.selectOutline = CreateOutline(2, BLUE)
        -- Verschwindet sofort, sobald die Inspector-Seite nicht mehr sichtbar ist (Fenster geschlossen, anderer Reiter).
        self.selectOutline:SetScript("OnUpdate", function(outline)
            if not self:IsShowingTarget() then outline:Hide() end
        end)
    end
    self.ignore = self.ignore or {}
    self.ignore[self.selectOutline] = true
    -- Das Popup ist immer dabei, sobald ein Element gewählt ist. Bei der Wahl per Tastenkürzel steht es allein (ohne
    -- Hauptfenster); sonst gehört es zur Inspector-Seite und verschwindet mit ihr.
    self.popupStandalone = popup and true or false
    local frame = self.popup or self:BuildPopup()
    frame:Show()
    if not popup then
        BugLab:ShowWindow()
        BugLab:SelectTab("Inspector")
    end
    self.outlineHidden = false
    self:Refresh()
    Mark(self.selectOutline, obj)
end

-- Wird das gewählte Element gerade angezeigt (Inspector-Seite oder Popup sichtbar)? Nur dann gilt die Markierung.
function Inspector:IsShowingTarget()
    return (self.page and self.page:IsVisible()) or (self.popup and self.popup:IsVisible()) or false
end

-- Hebt die Auswahl auf: Markierung und Anzeige verschwinden.
function Inspector:ClearSelection()
    self.target = nil
    if self.popup then self.popup:Hide() end
    self.mode = "info"
    if self.selectOutline then self.selectOutline:Hide() end
    self:SetStatus(nil)
    self:Refresh()
end

function Inspector:SetStatus(text)
    self.view.status:SetText(text or "")
    if self.popup then self.popup.edit.status:SetText(text or "") end
end

-- Liest das gewählte Objekt neu aus und füllt Text, Änderungsfelder und Knöpfe.
function Inspector:Refresh()
    local view = self.view
    if not view then return end
    local obj = self.target
    if not obj then
        view.panel:Hide()
        view.textScroll:Show()
        view.SetText(BugLab:Paint("GRAY", L["INS_NONE"]))
        view.editRow:Hide()
        view.parent:Disable(); view.layerPrev:Disable(); view.layerNext:Disable(); view.layer:SetText(""); view.children:Hide(); view.code:Disable(); view.refresh:Disable(); view.clear:Disable(); view.toEditor:Disable()
        return
    end
    view.parent:SetEnabled(obj.GetParent and obj:GetParent() ~= nil)
    local count = self.layers and #self.layers or 0
    view.layer:SetText(count > 0 and BugLab:Paint("BRIGHTBLUE", self.layerIndex .. "/" .. count) or "")
    view.layerPrev:SetEnabled(count > 1)
    view.layerNext:SetEnabled(count > 1)
    view.code:Enable(); view.refresh:Enable(); view.clear:Enable()
    view.toEditor:SetEnabled(self:TextureSource(obj) ~= nil)
    view.code:SetText(L[MODE_BUTTON[self.mode or "info"]])

    local info = BugLab:DescribeObject(obj)
    local showPanel = self.mode ~= "changes" and self.mode ~= "code"
    view.panel:SetShown(showPanel)
    view.textScroll:SetShown(not showPanel)
    if self.mode == "changes" then
        view.SetText(BugLab:ChangesLua())
    elseif self.mode == "code" then
        view.SetText(BugLab:ExportLua(obj))
    else
        local lines, props = BugLab:FormatObjectInfo(info)
        self:FillPanel(lines, props, (BugLab:CanEditObject(obj)))
    end
    self:RefreshChildren(info)
    self:RefreshEditRow(info)
    if self.popup and self.popup:IsVisible() then self:RefreshPopup(info) end
    -- Auch die Markierung folgt Änderungen (bei Spiel-Frames ist sie ein festes Rechteck).
    if self.selectOutline and self:IsShowingTarget() and not self.outlineHidden then
        local marked, err = Mark(self.selectOutline, obj)
        if not marked then self:SetStatus(BugLab:Paint("ERROR", L["INS_NO_OUTLINE"]:format(tostring(err)))) end
    end
end

function Inspector:RefreshChildren(info)
    local view = self.view
    local items = {}
    for _, child in ipairs(info.children or {}) do items[#items + 1] = child end
    for _, region in ipairs(info.regions or {}) do items[#items + 1] = region end
    view.children:SetShown(#items > 0)
    if #items == 0 then return end
    local text = BugLab:Paint("WHITE", L["INS_CHILDREN_BTN"]:format(#items))
    if view.children.SetDefaultText then
        view.children:SetupMenu(function(_, root)
            for i, item in ipairs(items) do
                if i > MAX_MENU_ENTRIES then root:CreateTitle(L["INS_MORE"]:format(#items - MAX_MENU_ENTRIES)); break end
                root:CreateButton(item.name .. " (" .. item.type .. ")", function() self:Select(item.object) end)
            end
        end)
        view.children:SetDefaultText(text)
    else
        view.children:SetText(text)
    end
end

local function FieldValue(info, key)
    if key == "x" or key == "y" then
        local p = info.points[1]
        return p and p[key] or 0
    elseif key == "width" then return info.width
    elseif key == "height" then return info.height
    elseif key == "alpha" then return info.alpha
    elseif key == "scale" then return info.scale
    elseif key == "color" then
        local c = info.vertexColor or info.textColor
        if not c then return nil end
        local function byte(v) return math.floor(math.max(0, math.min(1, v or 0)) * 255 + 0.5) end
        return string.format("%02X%02X%02X", byte(c[1]), byte(c[2]), byte(c[3]))
    end
end

local function FormatField(value)
    if type(value) == "string" then return value end
    if type(value) ~= "number" then return "" end
    if value == math.floor(value) then return tostring(value) end
    return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

function Inspector:FillEditRow(edit, info)
    local editable, reason = BugLab:CanEditObject(info.object)
    edit.row:Show()
    edit.locked:SetShown(not editable)
    edit.locked:SetText(not editable and BugLab:Paint("LIGHTGRAY", L[reason]) or "")
    for _, field in ipairs(edit.fields) do
        local key = field.key
        -- Skalierung gibt es nur bei Frames; Bereiche haben keine eigene.
        local applicable = editable and (key ~= "scale" or info.scale ~= nil)
        field.box:SetShown(applicable)
        field.label:SetShown(applicable)
        field.plus:SetShown(applicable)
        field.minus:SetShown(applicable)
        if applicable and not field.box:HasFocus() then field.box:SetText(FormatField(FieldValue(info, key))) end
    end
    local color = edit.color
    local hex = editable and FieldValue(info, "color")
    color.box:SetShown(hex ~= nil and hex ~= false)
    color.label:SetShown(hex ~= nil and hex ~= false)
    color.swatch:SetShown(hex ~= nil and hex ~= false)
    if hex then
        local c = info.vertexColor or info.textColor
        color.swatch.color:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
        if not color.box:HasFocus() then color.box:SetText(hex) end
    end
    edit.reset:SetShown(editable)
end

function Inspector:RefreshEditRow(info)
    self:FillEditRow(self.view.edit, info)
end

-- Wert aus einem Eingabefeld anwenden, danach neu auslesen.
function Inspector:ApplyField(key, text, target)
    target = target or self.target
    if not target then return end
    local apply = EDIT_FIELDS[key] and BugLab.ApplyEdit or BugLab.SetProperty
    local ok, reason = apply(BugLab, target, key, text)
    self:SetStatus(not ok and BugLab:Paint("ERROR", L[reason]) or nil)
    -- Die Markierung verschwindet beim Verstellen, damit man die neue Position sieht; 2 Sekunden nach der letzten
    -- Änderung kommt sie wieder.
    self.outlineHidden = true
    if self.selectOutline then self.selectOutline:Hide() end
    self.hideToken = (self.hideToken or 0) + 1
    local token = self.hideToken
    C_Timer.After(OUTLINE_PAUSE, function()
        if token ~= self.hideToken then return end
        self.outlineHidden = false
        if self.target then self:Refresh() end
    end)
    self:Refresh()
end

-- Schreibgeschütztes, scrollbares Textfeld (mit der Maus markierbar, Strg+C kopiert; beim Anklicken wird alles markiert).
-- Gibt den ScrollFrame (vom Aufrufer zu verankern) und die Funktion zum Setzen des Inhalts zurück.
local function CreateTextArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local text = CreateFrame("EditBox", nil, scroll)
    text:SetMultiLine(true)
    text:SetFontObject(ChatFontNormal)
    text:SetAutoFocus(false)
    BugLab:HookReloadKey(text)
    text:SetWidth(scroll:GetWidth() or 400)
    text.content = ""
    text:SetScript("OnTextChanged", function(edit, byUser)
        if byUser then edit:SetText(edit.content) end
    end)
    text:SetScript("OnEditFocusGained", function(edit) edit:HighlightText() end)
    text:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    scroll:SetScript("OnSizeChanged", function(_, width) text:SetWidth(width) end)
    scroll:SetScrollChild(text)
    return scroll, function(content)
        text.content = content
        text:SetText(content)
        scroll:SetVerticalScroll(0)
    end
end

BugLab.CreateTextArea = CreateTextArea

-- Popup ---------------------------------------------------------------------------------------------------------------

-- Kleines eigenes Fenster mit den Änderungsfeldern des gewählten Elements. Es ist unabhängig vom Hauptfenster, damit man
-- auch BugLabs eigene Fenster verstellen kann; "Werte anzeigen" öffnet die Inspector-Seite mit dem Element.
function Inspector:BuildPopup()
    local frame = CreateFrame("Frame", "BugLabInspectorPopup", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetSize(660, 340)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    local solid = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    solid:SetColorTexture(0.05, 0.05, 0.06, 1)
    solid:SetPoint("TOPLEFT", 2, -2)
    solid:SetPoint("BOTTOMRIGHT", -2, 2)
    BugLab:SkinFrame(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -3)
    frame.title:SetText(BugLab:Paint("WHITE", L["INS_POPUP_TITLE"]))
    BugLab.CreateCloseButton(frame, true)
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.name:SetPoint("TOP", frame.title, "BOTTOM", 0, -6)
    frame.name:SetWidth(620)

    local edit = self:CreateEditRow(frame)
    edit.row:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -54)
    edit.row:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    edit.reset:SetPoint("TOPLEFT", edit.row, "BOTTOMLEFT", 6, -4)
    edit.status:SetPoint("LEFT", edit.reset, "RIGHT", 10, 0)
    edit.status:SetJustifyH("LEFT")
    frame.edit = edit

    -- Ebenen: der Stapel unter der Maus bei der Wahl (1 = vorne); Eltern springt zum übergeordneten Element.
    local up = Button(frame, "<", 28, function() self:MoveLayer(-1, true) end)
    up:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
    frame.layer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.layer:SetWidth(96)
    frame.layer:SetPoint("LEFT", up, "RIGHT", 4, 0)
    local down = Button(frame, ">", 28, function() self:MoveLayer(1, true) end)
    down:SetPoint("LEFT", frame.layer, "RIGHT", 4, 0)
    local parent = Button(frame, L["INS_PARENT_BTN"], 80, function()
        local target = self.target and self.target:GetParent()
        if target then self:Select(target, true) end
    end)
    parent:SetPoint("LEFT", down, "RIGHT", 6, 0)
    local pick = Button(frame, L["INS_PICK"], 100, function() self:StartPick(true) end)
    pick:SetPoint("LEFT", parent, "RIGHT", 6, 0)
    frame.layerButtons, frame.parentButton = { up, down }, parent
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) self:MoveLayer(-delta, true) end)

    -- Lua-Code des Elements zum Kopieren (anklicken markiert alles, dann Strg+C).
    local code, SetCode = CreateTextArea(frame)
    code:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -128)
    code:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 48)
    frame.SetCode = SetCode
    -- Umschalter: Code des Elements oder aller bisherigen Änderungen (auch an anderen Elementen).
    frame.toggle = Button(frame, L["INS_CHANGES"], 130, function()
        self.popupChanges = not self.popupChanges
        self:Refresh()
    end)
    frame.toggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -98)

    local show = Button(frame, L["INS_SHOW_VALUES"], 130, function()
        local target = self.target
        if target then self:Select(target) end
    end)
    show:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    local close = Button(frame, L["CLOSE"], 100, function() frame:Hide() end)
    close:SetPoint("RIGHT", show, "LEFT", -6, 0)
    -- Reset und Status wandern in die Zeile über den Knöpfen.
    frame:SetScript("OnHide", function()
        if self.selectOutline and not self:IsShowingTarget() then self.selectOutline:Hide() end
    end)
    tinsert(UISpecialFrames, "BugLabInspectorPopup")
    self.popup = frame
    self.ignore = self.ignore or {}
    self.ignore[frame] = true
    frame:Hide()
    return frame
end

function Inspector:RefreshPopup(info)
    local frame = self.popup
    frame.name:SetText(BugLab:Paint("BRIGHTBLUE", info.name) .. " " .. BugLab:Paint("GRAY", "(" .. info.type .. ")"))
    self:FillEditRow(frame.edit, info)
    frame.SetCode(self.popupChanges and BugLab:ChangesLua() or BugLab:ExportLua(info.object))
    frame.toggle:SetText(self.popupChanges and L["INS_ELEMENT_CODE"] or L["INS_CHANGES"])
    local count = self.layers and #self.layers or 0
    frame.layer:SetText(count > 0 and BugLab:Paint("LIGHTGRAY", L["INS_LAYER_NAV"] .. " ") .. BugLab:Paint("BRIGHTBLUE", self.layerIndex .. "/" .. count) or "")
    for _, button in ipairs(frame.layerButtons) do button:SetEnabled(count > 1) end
    local parent = self.target and self.target.GetParent and self.target:GetParent()
    frame.parentButton:SetEnabled(parent ~= nil)
end

-- Eigenschaftenliste ---------------------------------------------------------------------------------------------------

-- Eine Zeile der Liste: Text links, bei verstellbaren Werten rechts (rechtsbündig) das passende Bedienelement.
function Inspector:CreateRow()
    local row = CreateFrame("Frame", nil, self.view.content)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", 0, -2)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    return row
end

local function ApplyRowValue(inspector, row, value)
    local prop = row.prop
    inspector:ApplyField(prop.key, value, prop.target)
end

-- Zeigt für eine Zeile das Bedienelement ihrer Eigenschaft (oder keins).
function Inspector:SetupRowControl(row, prop)
    row.prop = prop
    for _, name in ipairs({ "toggle", "edit", "menu" }) do
        if row[name] then row[name]:Hide() end
    end
    if not prop then return end
    if prop.kind == "bool" then
        if not row.toggle then
            row.toggle = Button(row, "", CONTROL_WIDTH, function() ApplyRowValue(self, row, not row.prop.value) end)
            row.toggle:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
        end
        row.toggle:SetText(BugLab:Paint(prop.value and "BRIGHTBLUE" or "LIGHTGRAY", tostring(prop.value)))
        row.toggle:Show()
    elseif prop.kind == "enum" then
        if not row.menu then
            local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, row, "WowStyle1DropdownTemplate")
            if ok and dropdown and dropdown.SetupMenu then
                dropdown:SetSize(CONTROL_WIDTH, ROW_HEIGHT)
                Desaturate(dropdown)
                if dropdown.Arrow then dropdown.Arrow:SetDesaturated(true); dropdown.Arrow:SetVertexColor(0.6, 0.82, 1) end
                dropdown:SetupMenu(function(_, root)
                    local current = row.prop
                    for _, option in ipairs(current.options or {}) do
                        root:CreateRadio(option, function() return row.prop.value == option end,
                            function() ApplyRowValue(self, row, option) end)
                    end
                end)
            else
                -- Ohne Auswahlvorlage schaltet der Knopf reihum zum nächsten Wert.
                dropdown = Button(row, "", CONTROL_WIDTH, function()
                    local options, index = row.prop.options or {}, 0
                    for i, option in ipairs(options) do if option == row.prop.value then index = i end end
                    if #options > 0 then ApplyRowValue(self, row, options[index % #options + 1]) end
                end)
            end
            dropdown:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
            row.menu = dropdown
        end
        if row.menu.SetDefaultText then
            row.menu:SetDefaultText(BugLab:Paint("WHITE", tostring(prop.value)))
            if row.menu.GenerateMenu then row.menu:GenerateMenu() end
        else
            row.menu:SetText(BugLab:Paint("WHITE", tostring(prop.value)))
        end
        row.menu:Show()
    else
        if not row.edit then
            local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            box:SetSize(CONTROL_WIDTH - 8, ROW_HEIGHT)
            box:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, 0)
            box:SetAutoFocus(false)
            Desaturate(box)
            BugLab:HookReloadKey(box)
            box:SetScript("OnEnterPressed", function(input) input:ClearFocus(); ApplyRowValue(self, row, input:GetText()) end)
            box:SetScript("OnEscapePressed", function(input) input:ClearFocus(); self:Refresh() end)
            row.edit = box
        end
        if not row.edit:HasFocus() then
            row.edit:SetText(tostring(prop.value or ""))
            row.edit:SetCursorPosition(0)
        end
        row.edit:Show()
    end
end

-- Merkt sich Zeilen und verstellbare Eigenschaften und legt die Liste neu aus.
function Inspector:FillPanel(lines, props, editable)
    self.panelData = { lines = lines, props = props, editable = editable }
    self:LayoutPanel()
end

function Inspector:LayoutPanel()
    local data, view = self.panelData, self.view
    if not (data and view) then return end
    local width = tonumber(view.content:GetWidth()) or 0
    if width < 100 then width = 600 end
    local y = 0
    for i, line in ipairs(data.lines) do
        local row = view.rows[i]
        if not row then row = self:CreateRow(); view.rows[i] = row end
        local prop = data.editable and data.props[i] or nil
        row.text:SetWidth(width - (prop and CONTROL_WIDTH + 8 or 0))
        row.text:SetText(line)
        local height = math.max(tonumber(row.text:GetStringHeight()) or 14, 14) + 4
        if prop then height = math.max(height, ROW_HEIGHT + 2) end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view.content, "TOPLEFT", 0, -y)
        row:SetSize(width, height)
        self:SetupRowControl(row, prop)
        row:Show()
        y = y + height
    end
    for i = #data.lines + 1, #view.rows do
        view.rows[i]:Hide()
        self:SetupRowControl(view.rows[i], nil)
    end
    view.content:SetHeight(math.max(y, 1))
end

-- Aufbau der Seite ------------------------------------------------------------------------------------------------------

-- Änderungszeile (X, Y, Breite, Höhe, Alpha, Skalierung mit +/-, Zurücksetzen, Status); sie gibt es auf der Seite und im Popup.
-- Der Aufrufer setzt Position und Größe von edit.row und die Anker von edit.reset und edit.status.
function Inspector:CreateEditRow(parent)
    local edit = { fields = {} }
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(40)
    edit.row = row
    edit.locked = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    edit.locked:SetPoint("LEFT", 2, 0)
    local x = 0
    for _, def in ipairs(FIELDS) do
        local key = def[1]
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", x + 6, 0)
        label:SetText(BugLab:Paint("LIGHTGRAY", L[def[2]]))
        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(56, ROW_HEIGHT)
        box:SetPoint("TOPLEFT", x + 6, -14)
        box:SetAutoFocus(false)
        Desaturate(box)
        BugLab:HookReloadKey(box)
        box:SetScript("OnEnterPressed", function(input) input:ClearFocus(); self:ApplyField(key, input:GetText()) end)
        box:SetScript("OnEscapePressed", function(input) input:ClearFocus(); self:Refresh() end)
        -- Schrittweite: 1 (Umschalt: 10); bei Alpha und Skalierung 0,05 (Umschalt: 0,25).
        local function Step(direction)
            local fine = key == "alpha" or key == "scale"
            local step = fine and (IsShiftKeyDown() and 0.25 or 0.05) or (IsShiftKeyDown() and 10 or 1)
            local value = (tonumber(box:GetText()) or 0) + direction * step
            self:ApplyField(key, tonumber(string.format("%.2f", value)))
        end
        box:SetScript("OnKeyDown", function(_, k)
            if k == "UP" then Step(1) elseif k == "DOWN" then Step(-1) end
        end)
        -- Plus/Minus rechts neben dem Feld; gedrückt halten wiederholt nach kurzer Pause.
        local function Spinner(text, direction, anchor, relPoint)
            local spin = Button(row, text, 26, nil)
            spin:SetSize(26, ROW_HEIGHT / 2 + 1)
            spin:SetPoint("TOPLEFT", anchor, relPoint, anchor == box and 2 or 0, anchor == box and 0 or 0)
            spin:SetScript("OnClick", function() Step(direction) end)
            spin:SetScript("OnMouseDown", function(btn) btn.hold = -0.4 end)
            spin:SetScript("OnMouseUp", function(btn) btn.hold = nil end)
            spin:SetScript("OnHide", function(btn) btn.hold = nil end)
            spin:SetScript("OnUpdate", function(btn, dt)
                if not btn.hold then return end
                btn.hold = btn.hold + dt
                if btn.hold > 0.06 then btn.hold = 0; Step(direction) end
            end)
            return spin
        end
        local plus = Spinner("+", 1, box, "TOPRIGHT")
        local minus = Spinner("-", -1, plus, "BOTTOMLEFT")
        box:EnableMouseWheel(true)
        box:SetScript("OnMouseWheel", function(_, delta) Step(delta) end)
        edit.fields[#edit.fields + 1] = { key = key, box = box, label = label, plus = plus, minus = minus }
        x = x + 90
    end
    -- Farbe (Texturen und Schriften) anstelle der Skalierung, die es bei Bereichen nicht gibt: Hex-Feld und Farbfeld.
    do
        local cx = (#FIELDS - 1) * 90
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", cx + 6, 0)
        label:SetText(BugLab:Paint("LIGHTGRAY", L["INS_FIELD_COLOR"]))
        local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(56, ROW_HEIGHT)
        box:SetPoint("TOPLEFT", cx + 6, -14)
        box:SetAutoFocus(false)
        box:SetMaxLetters(7)
        Desaturate(box)
        BugLab:HookReloadKey(box)
        box:SetScript("OnEnterPressed", function(input) input:ClearFocus(); self:ApplyField("color", input:GetText()) end)
        box:SetScript("OnEscapePressed", function(input) input:ClearFocus(); self:Refresh() end)
        local swatch = Button(row, "", 26, function()
            local target = self.target
            if not target then return end
            local info = BugLab:DescribeObject(target)
            local old = info.vertexColor or info.textColor
            if not (old and ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
            -- Der Farbwähler liegt sonst hinter dem Popup (FULLSCREEN_DIALOG).
            pcall(function() ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG"); ColorPickerFrame:SetFrameLevel(100) end)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = old[1] or 1, g = old[2] or 1, b = old[3] or 1, hasOpacity = false,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    self:ApplyField("color", { r, g, b })
                end,
                cancelFunc = function() self:ApplyField("color", { old[1], old[2], old[3] }) end,
            })
        end)
        swatch:SetSize(26, ROW_HEIGHT)
        swatch:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, 0)
        swatch.color = swatch:CreateTexture(nil, "OVERLAY")
        swatch.color:SetPoint("TOPLEFT", 5, -5)
        swatch.color:SetPoint("BOTTOMRIGHT", -5, 5)
        edit.color = { key = "color", box = box, label = label, swatch = swatch }
    end
    edit.reset = Button(row, L["INS_RESET"], 100, function()
        if self.target then BugLab:ResetEdit(self.target); self:Refresh() end
    end)
    edit.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    edit.status:SetJustifyH("RIGHT")
    return edit
end

local TAB_HEIGHT = 34
local SUBTABS = { "details", "editor" }
local SUBTAB_LABEL = { details = "INS_TAB_DETAILS", editor = "INS_TAB_EDITOR" }

function Inspector:BuildPage()
    local pageFrame = BugLab:GetPage("Inspector")
    -- Unterpunkte als Reiter: Details (die bisherige Seite) und Textur-Editor.
    local page = CreateFrame("Frame", nil, pageFrame)
    page:SetPoint("TOPLEFT", 0, -TAB_HEIGHT)
    page:SetPoint("BOTTOMRIGHT")
    local view = { page = page, pageFrame = pageFrame, fields = {}, subtabs = {} }
    self.view = view
    self.page = page
    for i, key in ipairs(SUBTABS) do
        local button = Button(pageFrame, L[SUBTAB_LABEL[key]], 130, function() self:SelectSubTab(key) end)
        button:SetPoint("TOPLEFT", 6 + (i - 1) * 136, -4)
        view.subtabs[key] = button
    end
    local editorFrame = self:BuildTextureEditor(pageFrame)
    editorFrame:SetPoint("TOPLEFT", 0, -TAB_HEIGHT)
    editorFrame:SetPoint("BOTTOMRIGHT")

    -- Zeile 1: Pick, Abwählen, Aktualisieren, Lua-Code.
    view.pick = Button(page, L["INS_PICK"], 100, function() self:StartPick() end)
    view.pick:SetPoint("TOPLEFT", 6, -6)
    view.parent = Button(page, L["INS_PARENT_BTN"], 80, function()
        local parent = self.target and self.target:GetParent()
        if parent then self:Select(parent) end
    end)
    -- Zeile 2 (Navigation): Eltern, Ebenen, Kinder.
    view.parent:SetPoint("TOPLEFT", view.pick, "BOTTOMLEFT", 0, -6)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(130, ROW_HEIGHT)
        Desaturate(dropdown)
        if dropdown.Arrow then dropdown.Arrow:SetDesaturated(true); dropdown.Arrow:SetVertexColor(0.6, 0.82, 1) end
        view.children = dropdown
    else
        view.children = Button(page, L["INS_CHILDREN_BTN"]:format(0), 130, function() end)
    end
    view.clear = Button(page, L["INS_CLEAR"], 90, function() self:ClearSelection() end)
    view.clear:SetPoint("LEFT", view.pick, "RIGHT", 6, 0)
    -- Ebenen der letzten Wahl (1 = vorne), wie im Popup.
    view.layerPrev = Button(page, "<", 28, function() self:MoveLayer(-1) end)
    view.layerPrev:SetPoint("LEFT", view.parent, "RIGHT", 6, 0)
    view.layer = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.layer:SetWidth(56)
    view.layer:SetPoint("LEFT", view.layerPrev, "RIGHT", 2, 0)
    view.layerNext = Button(page, ">", 28, function() self:MoveLayer(1) end)
    view.layerNext:SetPoint("LEFT", view.layer, "RIGHT", 2, 0)
    view.children:SetPoint("LEFT", view.layerNext, "RIGHT", 6, 0)
    -- Der Knopf zeigt die nächste Ansicht: Details -> Lua-Code -> Änderungen -> Details.
    view.code = Button(page, L["INS_CODE"], 90, function()
        self.mode = MODE_NEXT[self.mode or "info"]
        self:Refresh()
    end)
    view.code:SetPoint("TOPRIGHT", -6, -6)
    view.refresh = Button(page, L["INS_REFRESH"], 110, function() self:Refresh() end)
    view.refresh:SetPoint("RIGHT", view.code, "LEFT", -6, 0)
    view.toEditor = Button(page, L["INS_TO_EDITOR"], 140, function()
        local source, crop = self:TextureSource(self.target)
        if source then self:OpenTextureEditor(source, crop) end
    end)
    view.toEditor:SetPoint("RIGHT", view.refresh, "LEFT", -6, 0)

    -- Zeile 3: Änderungsfelder (nur bei eigenen Frames) oder der Hinweis "nur Anzeige".
    local edit = self:CreateEditRow(page)
    view.edit = edit
    view.editRow, view.fields, view.locked, view.reset, view.status = edit.row, edit.fields, edit.locked, edit.reset, edit.status
    local row = edit.row
    row:SetPoint("TOPLEFT", view.parent, "BOTTOMLEFT", 0, -6)
    row:SetPoint("RIGHT", page, "RIGHT", -6, 0)
    view.reset:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -14)
    view.status:SetPoint("RIGHT", view.reset, "LEFT", -10, 0)

    -- Ausgabe: schreibgeschütztes Textfeld, mit der Maus markierbar und mit Strg+C kopierbar.
    local scroll
    scroll, view.SetText = CreateTextArea(page)
    scroll:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    view.textScroll = scroll

    -- Details als Liste: verstellbare Werte tragen rechts ihr Bedienelement.
    local panel = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    panel:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -4)
    panel:SetPoint("BOTTOMRIGHT", -26, 8)
    local content = CreateFrame("Frame", nil, panel)
    content:SetSize(10, 10)
    panel:SetScrollChild(content)
    view.panel, view.content, view.rows = panel, content, {}
    panel:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
        self:LayoutPanel()
    end)

    -- Die Markierung des gewählten Elements gilt nur, solange die Seite sichtbar ist (Fenster zu oder anderer Reiter = weg).
    pageFrame:SetScript("OnShow", function()
        self.popupStandalone = false
        if self.target then (self.popup or self:BuildPopup()):Show() end
        self:Refresh()
    end)
    pageFrame:SetScript("OnHide", function()
        if self.popup and not self.popupStandalone then self.popup:Hide() end
        if self.selectOutline and not self:IsShowingTarget() then self.selectOutline:Hide() end
    end)
    self:SelectSubTab("details")
    self:Refresh()
end

-- Wechselt zwischen "details" und "editor".
function Inspector:SelectSubTab(key)
    local view = self.view
    if not view then return end
    self.subtab = key
    view.page:SetShown(key == "details")
    self.editorView.frame:SetShown(key == "editor")
    for name, button in pairs(view.subtabs) do
        button:SetText(name == key and BugLab:Paint("BRIGHTBLUE", L[SUBTAB_LABEL[name]]) or L[SUBTAB_LABEL[name]])
    end
end

function Inspector:OnEnable()
    if not self.view then self:BuildPage() end
end
