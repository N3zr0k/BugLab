-- Console: Live-Ausgabe in einem eigenen Ingame-Chatfenster, Historie mit Filtern im BugLab-Fenster.
local BugLab = _G.BugLab
local L = BugLab.L
local Console = BugLab:NewModule("Console", "AceEvent-3.0")

-- Ein eigenes, abgedocktes Chatfenster "BugLab" mit zwei Reitern: BugLab:Debug (Console) und BugLab:Probes. Die Reiter
-- schaltet BugLab selbst um (Blizzard kennt kein Andocken mehrerer Reiter per Code): gezeigt wird immer ein Log, das
-- andere steht weiter in der Historie und erscheint beim Umschalten (Zeilen von heute).
local CHAT_NAME = "BugLab"
local OLD_CHAT_NAMES = { ["BugLab:Debug"] = true } -- Namen früherer Versionen (werden umbenannt)
local CHAT_KINDS = { "console", "probe" }
local CHAT_TAB_LABEL = { console = "BugLab:Debug", probe = "BugLab:Probes" }
local CHAT_REPLAY_MAX = 500
local MAX_LINES = 3000
local CHAT_MAX_LINES = 2000
-- Gemeinsame Bedienelemente (Core/UI.lua): Standardhöhe, Entfärben, Knöpfe im BugLab-Stil.
local ROW_HEIGHT, FACE_TINT = BugLab.ROW_HEIGHT, BugLab.FACE_TINT
local Desaturate, Button = BugLab.Desaturate, BugLab.CreateButton
local TIME_RANGE_KEYS = { hour = "RANGE_HOUR", h3 = "RANGE_H3", h12 = "RANGE_H12", today = "RANGE_TODAY", d3 = "RANGE_D3", week = "RANGE_WEEK", all = "RANGE_ALL" }

-- Chatfenster ---------------------------------------------------------------------------------------------------

-- Löst das Fenster aus dem allgemeinen Chat (wie Reiter wegziehen) und setzt es an eine feste Stelle. Meldet im
-- Debug-Log, wenn es danach noch angedockt ist, mit den Fehlern der Aufrufe.
function Console:DetachChat(frame)
    local errors = {}
    local function try(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then errors[#errors + 1] = tostring(err) end
    end
    if FCF_UnDockFrame then try(FCF_UnDockFrame, frame) else errors[#errors + 1] = "FCF_UnDockFrame fehlt" end
    try(function()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 60, 220)
        frame:SetSize(430, 200)
    end)
    if FCF_SavePositionAndDimensions then try(FCF_SavePositionAndDimensions, frame) end
    if FCF_DockUpdate then try(FCF_DockUpdate) end
    if frame.isDocked then
        BugLab:AddEntry("BugLab:Console", L["CHAT_DETACH_FAILED"]:format(tostring(frame.isDocked), table.concat(errors, "; ")), "WARN")
    end
end

-- Benennt ein Fenster um und aktualisiert den Text seines Reiters (je nach Version reicht FCF_SetWindowName nicht).
function Console:RenameChat(frame, id)
    if FCF_SetWindowName then pcall(FCF_SetWindowName, frame, CHAT_NAME) end
    if SetChatWindowName then pcall(SetChatWindowName, id, CHAT_NAME) end
    local tab = _G["ChatFrame" .. id .. "Tab"]
    if tab and tab.SetText then tab:SetText(CHAT_NAME) end
end

-- Schließt ein Chatfenster; hilft FCF_Close nicht, wird es ausgeblendet und als "nicht angezeigt" gespeichert.
function Console:CloseChat(frame, id)
    if not frame then return end
    if FCF_Close then pcall(FCF_Close, frame) end
    if frame.IsShown and frame:IsShown() then
        if SetChatWindowShown then pcall(SetChatWindowShown, id, false) end
        frame:Hide()
        local tab = _G["ChatFrame" .. id .. "Tab"]
        if tab and tab.Hide then tab:Hide() end
    end
end

-- Sucht das Chatfenster "BugLab" oder legt es an (abgedockt, einmalig); es erhält keine normalen Chatnachrichten.
function Console:GetChatFrame()
    if self.chatFrame then return self.chatFrame end
    -- Warnungen beim Anlegen lösen selbst eine Chatausgabe aus: nicht erneut anlegen.
    if self.chatBuilding then return nil end
    self.chatBuilding = true
    self.chatKind = self.chatKind or "console"
    local frame
    for i = 1, NUM_CHAT_WINDOWS or 0 do
        local existing = GetChatWindowInfo(i)
        if existing == CHAT_NAME or OLD_CHAT_NAMES[existing] then
            frame = _G["ChatFrame" .. i]
            if existing ~= CHAT_NAME then self:RenameChat(frame, i) end
        elseif existing == "BugLab:Probes" then
            self:CloseChat(_G["ChatFrame" .. i], i) -- zweites Fenster früherer Versionen: nicht mehr nötig
        end
    end
    if not frame then
        local ok, created = pcall(FCF_OpenNewWindow, CHAT_NAME)
        if not ok or not created then
            -- Nicht still scheitern: einmal im Debug-Log melden.
            if not self.chatFailed then
                self.chatFailed = true
                BugLab:AddEntry("BugLab:Console", L["CHAT_TAB_FAILED"]:format(CHAT_NAME, tostring(created)), "WARN")
            end
            self.chatBuilding = nil
            return nil
        end
        frame = created
    end
    if frame and not self.chatClean then
        if ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(frame) end
        if ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
        self.chatClean = true
    end
    if frame and frame.SetMaxLines then frame:SetMaxLines(CHAT_MAX_LINES) end -- genug Platz zum Zurückscrollen
    -- Vom Standardfenster lösen: ein docked Fenster hängt als Reiter im allgemeinen Chat; BugLab will ein eigenes.
    if frame and frame.isDocked then self:DetachChat(frame) end
    -- Das Chatfenster gehört dem Spiel: ein Fehler beim Anbringen der Bedienelemente darf die Ausgabe nicht stoppen.
    if frame and not self.historyButton then
        local ok, button = pcall(self.AddHistoryButton, self, frame)
        self.historyButton = ok and button or false
        pcall(self.AddChatTabs, self, frame)
    end
    self.chatFrame = frame
    self.chatBuilding = nil
    self:ApplyChatFontSize()
    self:ReplayChat()
    return frame
end

-- Kleiner blauer Käfer in der Ecke des Chatfensters: öffnet die Historie im BugLab-Fenster.
local HISTORY_BUTTON_SIZE = 18

-- Prat legt eigene Knöpfe an den rechten Rand: Käfer und Reiter rücken dann 30 Pixel nach links.
local function PRAT_SHIFT() return BugLab:IsPratLoaded() and 30 or 0 end

function Console:AddHistoryButton(frame)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(HISTORY_BUTTON_SIZE, HISTORY_BUTTON_SIZE)
    -- Über dem Chatfenster am rechten Rand (Höhe der Reiterleiste): verdeckt keinen Text und kollidiert nicht mit dem
    -- Kopier-Symbol unten rechts.
    button:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -2 - PRAT_SHIFT(), 4)
    button:SetFrameLevel(frame:GetFrameLevel() + 10)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(BugLab.MEDIA_PATH .. "BugLab_Beetle_Outlined_32")
    icon:SetAlpha(1)
    button:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        GameTooltip:SetText(BugLab.NAME_COLORED)
        GameTooltip:AddLine(L["CHAT_OPEN_HISTORY"], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function()
        BugLab:ShowWindow()
        BugLab:SelectTab("Console")
    end)
    return button
end

-- Reiter im Chatfenster (links neben dem Käfer): Debug und Probes.
function Console:AddChatTabs(frame)
    self.chatTabs = {}
    local previous
    -- Von rechts nach links anlegen: Probes ganz rechts, Debug links davon.
    for i = #CHAT_KINDS, 1, -1 do
        local kind = CHAT_KINDS[i]
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(92, 18)
        tab:SetFrameLevel(frame:GetFrameLevel() + 10)
        -- Rechts über dem Fenster, links vom Käfer: der Reiter des Spiels bleibt links frei.
        if previous then tab:SetPoint("RIGHT", previous, "LEFT", -2, 0) else tab:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -24 - PRAT_SHIFT(), 4) end
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0, 0, 0, 0.55)
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tab.text:SetAllPoints()
        tab.kind = kind
        tab:SetScript("OnClick", function() self:SetChatKind(kind) end)
        self.chatTabs[kind] = tab
        previous = tab
    end
    self:UpdateChatTabs()
end

function Console:UpdateChatTabs()
    for kind, tab in pairs(self.chatTabs or {}) do
        local active = kind == self.chatKind
        tab.text:SetText(BugLab:Paint(active and "BRIGHTBLUE" or "GRAY", CHAT_TAB_LABEL[kind]))
        tab.bg:SetColorTexture(active and 0.1 or 0, active and 0.2 or 0, active and 0.3 or 0, 0.7)
    end
end

-- Zeigt das gewählte Log neu: Fenster leeren, Zeilen von heute (zuletzt höchstens CHAT_REPLAY_MAX) nachtragen.
function Console:ReplayChat()
    local frame = self.chatFrame
    if not (frame and frame.AddMessage) then return end
    if frame.Clear then frame:Clear() end
    self.chatDay = nil
    local today, lines = BugLab:DayOf(time()), {}
    for _, entry in ipairs(BugLab:GetHistory(self.chatKind)) do
        if BugLab:DayOf(entry.t) == today then lines[#lines + 1] = entry end
    end
    for i = math.max(1, #lines - CHAT_REPLAY_MAX + 1), #lines do self:AddToChat(frame, lines[i]) end
end

-- Schriftgröße des BugLab-Fensters (nur dieses Fenster; die übrigen Chatfenster bleiben unberührt). Jedes Log hat
-- seine eigene Größe, sie gilt, solange es im Fenster gezeigt wird.
function Console:ApplyChatFontSize()
    local frame = self.chatFrame
    local sizes = BugLab.db and BugLab.db.profile.chatFontSize
    local size = sizes and sizes[self.chatKind]
    if not (frame and size) then return end
    if FCF_SetChatWindowFontSize then
        pcall(FCF_SetChatWindowFontSize, nil, frame, size)
    elseif frame.GetFont and frame.SetFont then
        local face, _, flags = frame:GetFont()
        if face then pcall(frame.SetFont, frame, face, size, flags) end
    end
end

function Console:SetChatKind(kind)
    self.chatKind = kind
    self:UpdateChatTabs()
    self:ApplyChatFontSize()
    self:ReplayChat()
end

-- Schreibt einen Eintrag in das Chatfenster, bei Tageswechsel mit Datumszeile davor (wie in der Historie).
function Console:AddToChat(frame, entry)
    local day = BugLab:DayOf(entry.t)
    if day ~= self.chatDay then
        frame:AddMessage(BugLab:FormatDay(entry.t))
        self.chatDay = day
    end
    -- Prat zeigt schon eine Uhrzeit: die eigene entfällt dann im Chat (nicht in der Historie).
    frame:AddMessage(BugLab:FormatEntry(entry, BugLab:IsPratLoaded()))
end

-- Neue Zeile: erscheint nur, wenn ihr Log gerade im Chatfenster gezeigt wird. Legt der Eintrag das Fenster erst an, steht
-- er schon in dem, was beim Anlegen nachgetragen wird.
function Console:OnChatEntry(entry, kind)
    local fresh = not self.chatFrame
    local frame = self:GetChatFrame()
    if not (frame and frame.AddMessage) or fresh then return end
    if kind == self.chatKind then self:AddToChat(frame, entry) end
end

function Console:OnLogEntry(_, entry) self:OnChatEntry(entry, "console") end
function Console:OnProbeEntry(_, entry) self:OnChatEntry(entry, "probe") end

-- Historie im BugLab-Fenster -----------------------------------------------------------------------------------------

-- Eintrag durchläuft Quelle, Zeitraum und Texteingabe.
function Console:Passes(entry, terms, now)
    local state = self.state
    if state.source and not BugLab:MatchesSource(entry, state.source) then return false end
    if BugLab:EntryLevel(entry) < state.level then return false end
    if not BugLab:InTimeRange(state.range, entry.t, now, state.from, state.to) then return false end
    return BugLab:MatchesFilter(terms, entry.s .. " " .. entry.m)
end

function Console:RefreshHistory()
    local view = self.view
    if not view then return end
    local now, terms = time(), BugLab:ParseFilter(self.state.text)
    local lines, shown, total, lastDay = {}, 0, 0, nil
    for _, entry in ipairs(BugLab:GetHistory(self.state.kind)) do
        total = total + 1
        if self:Passes(entry, terms, now) then
            shown = shown + 1
            local day = BugLab:DayOf(entry.t)
            if day ~= lastDay then
                lines[#lines + 1] = BugLab:FormatDay(entry.t)
                lastDay = day
            end
            lines[#lines + 1] = BugLab:FormatEntry(entry)
        end
    end
    local first = math.max(1, #lines - MAX_LINES + 1)
    local visible = {}
    for i = first, #lines do visible[#visible + 1] = lines[i] end
    view.lines = visible
    view.text.content = table.concat(visible, "\n")
    view.text:SetText(view.text.content)
    -- erst nach dem Layout ans Ende, damit die neuesten Zeilen sichtbar sind
    C_Timer.After(0, function() view.log:SetVerticalScroll(view.log:GetVerticalScrollRange()) end)
    view.count:SetText(BugLab:Paint("BRIGHTBLUE", L[self.state.kind == "probe" and "KIND_PROBE" or "KIND_CONSOLE"]) .. BugLab:Paint("GRAY", "  " .. L["HISTORY_COUNT"]:format(
        BugLab:Paint("BRIGHTBLUE", shown), BugLab:Paint("BRIGHTBLUE", total))))
end

-- Filter: Auswahlwerte je Feld. Jeder Wert ist { value, text }; value = nil bedeutet "alle".
local DEFAULT_STATE = { range = "all", text = "", level = 1 }

function Console:GetOptions(field)
    local list = {}
    if field == "kind" then
        list[1] = { "console", L["KIND_CONSOLE"] }
        list[2] = { "probe", L["KIND_PROBE"] }
    elseif field == "source" then
        list[1] = { nil, L["FILTER_ALL"] }
        for _, name in ipairs(BugLab:GetLogSources(self.state.kind)) do list[#list + 1] = { name, name } end
    elseif field == "range" then
        -- Dritter Eintrag: Kurztext für den Button (Auswahlliste zeigt den Langtext).
        for _, key in ipairs(BugLab.TIME_RANGES) do list[#list + 1] = { key, L[TIME_RANGE_KEYS[key]], L[TIME_RANGE_KEYS[key] .. "_SHORT"] } end
        list[#list + 1] = { "custom", L["RANGE_CUSTOM"], self:CustomRangeText() }
    else
        for i, level in ipairs(BugLab.LEVELS) do
            local color = BugLab.LEVEL_COLORS[level] or "ffffff"
            list[#list + 1] = { i, "|cff" .. color .. L["LEVEL_" .. level] .. "|r" }
        end
    end
    return list
end

local FIELD_LABEL = { kind = "FILTER_KIND", source = "FILTER_SOURCE", range = "FILTER_RANGE", level = "FILTER_LEVEL" }
local FIELD_TIP = { kind = "TIP_KIND", source = "TIP_SOURCE", range = "TIP_RANGE", level = "TIP_LEVEL" }

-- Kurztext des frei gewählten Zeitraums, z. B. "01.10.-05.10."; ohne Auswahl "Custom".
function Console:CustomRangeText()
    local from, to = self.state.from, self.state.to
    if not (from and to) then return L["RANGE_CUSTOM"] end
    if BugLab:DayStart(from) == BugLab:DayStart(to) then return date("%d.%m.", from) end
    return date("%d.%m.", from) .. "-" .. date("%d.%m.", to)
end

-- Kalender-Popup zur Wahl eines Zeitraums: erster Klick = Starttag, zweiter Klick = Endtag (Reihenfolge egal).
-- Rahmen wie das Hauptfenster, per Ziehen verschiebbar; der heutige Tag trägt einen blauen Rahmen.
local CAL_W, CAL_H, CAL_GAP = 34, 26, 2
local TODAY_FRAME = { 0.4, 0.73, 1 } -- BugLab-Blau

-- Eingabemasken: getippte Ziffern füllen z. B. "dd.mm.yyyy" von links nach rechts, der Rest bleibt grau, die nächste
-- Stelle ist blau. Intern zählt nur die Ziffernfolge. Buchstaben der Maske sind Platzhalter, alles andere Trennzeichen.
local DATE_MASK, TIME_MASK = "dd.mm.yyyy", "hh:mm"
local DEFAULT_START_TIME, DEFAULT_END_TIME = "0000", "1200"

local function MaskText(mask, digits, invalid)
    local out, used = {}, 0
    for i = 1, #mask do
        local c = mask:sub(i, i)
        if c:match("%a") then
            used = used + 1
            if used <= #digits then
                out[#out + 1] = BugLab:Paint(invalid and "ERROR" or "WHITE", digits:sub(used, used))
            else
                out[#out + 1] = BugLab:Paint(used == #digits + 1 and "BRIGHTBLUE" or "GRAY", c)
            end
        else
            out[#out + 1] = BugLab:Paint("GRAY", c)
        end
    end
    return table.concat(out)
end

-- Ziffern "ddmmyyyy" -> Tagesbeginn (Unixzeit), nil bei ungültigem Datum.
local function ParseDate(d)
    if #d ~= 8 then return nil end
    local day, month, year = tonumber(d:sub(1, 2)), tonumber(d:sub(3, 4)), tonumber(d:sub(5, 8))
    if month < 1 or month > 12 or day < 1 or year < 2000 then return nil end
    local stamp = time({ year = year, month = month, day = day, hour = 0 })
    local t = stamp and date("*t", stamp)
    if not t or t.day ~= day or t.month ~= month then return nil end
    return stamp
end

-- Ziffern "hhmm" -> Sekunden seit 0:00 Uhr, nil bei ungültiger Uhrzeit.
local function ParseTime(d)
    if #d ~= 4 then return nil end
    local hour, minute = tonumber(d:sub(1, 2)), tonumber(d:sub(3, 4))
    if hour > 23 or minute > 59 then return nil end
    return hour * 3600 + minute * 60
end

-- Gültiger Zeitraum aus den vier Feldern (Ziffernfolgen); ohne Enddatum gilt der Starttag. Das Ende zählt bis zum
-- Ende der Minute; von <= bis.
local function ParseRange(sd, st, ed, et)
    local day1 = ParseDate(sd)
    local day2 = ed == "" and day1 or ParseDate(ed)
    local t1, t2 = ParseTime(st), ParseTime(et)
    if not (day1 and day2 and t1 and t2) then return nil end
    local from, to = day1 + t1, day2 + t2 + 59
    if from > to then return nil end
    return from, to
end

local function DayCell(parent, onClick)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(CAL_W, CAL_H)
    cell.fill = cell:CreateTexture(nil, "BACKGROUND")
    cell.fill:SetAllPoints()
    cell.hover = cell:CreateTexture(nil, "HIGHLIGHT")
    cell.hover:SetAllPoints()
    cell.hover:SetColorTexture(1, 1, 1, 0.18)
    cell.edges = {}
    for i, def in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                           { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local edge = cell:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(unpack(TODAY_FRAME))
        edge:SetPoint(def[1]); edge:SetPoint(def[2])
        if def[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        edge:Hide()
        cell.edges[i] = edge
    end
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.text:SetPoint("CENTER")
    cell:SetScript("OnClick", onClick)
    return cell
end

-- Eingabefeld mit Maske: der EditBox-Text bleibt unsichtbar (nur Ziffern), die Maske zeichnet ein FontString darüber.
-- Über dem Feld steht die Bezeichnung. Gibt die Feldtabelle { digits, SetDigits, input } zurück.
local function MaskField(parent, label, mask, maxDigits, onChange)
    local field = { mask = mask, max = maxDigits, digits = "" }
    -- Rahmen wie ein Knopf, innen schwarz wie die Auswahllisten; der blaue Innenrand zeigt den Fokus.
    local box = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    box:SetHeight(ROW_HEIGHT)
    box:EnableMouse(false)
    box:SetText("")
    Desaturate(box)
    for _, key in ipairs({ "Left", "Middle", "Center", "Right" }) do
        local tex = box[key]
        if tex and tex.SetDesaturated then tex:SetDesaturated(true); tex:SetVertexColor(unpack(FACE_TINT)) end
    end
    field.box = box
    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 2)
    caption:SetText(BugLab:Paint("LIGHTGRAY", label))
    local inner = box:CreateTexture(nil, "ARTWORK", nil, 6)
    inner:SetPoint("TOPLEFT", 3, -3)
    inner:SetPoint("BOTTOMRIGHT", -3, 3)
    inner:SetColorTexture(0, 0, 0, 1)
    local edges = {}
    for i, def in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                           { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local edge = box:CreateTexture(nil, "ARTWORK", nil, 7)
        edge:SetColorTexture(0.4, 0.73, 1, 1)
        edge:SetPoint(def[1], inner, def[1]); edge:SetPoint(def[2], inner, def[2])
        if def[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        edge:Hide()
        edges[i] = edge
    end
    field.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    field.text:SetPoint("CENTER")
    local input = CreateFrame("EditBox", nil, box)
    input:SetAllPoints()
    input:SetAutoFocus(false)
    input:SetFontObject("GameFontHighlightSmall")
    input:SetTextColor(0, 0, 0, 0)
    input:SetMaxLetters(40)
    BugLab:HookReloadKey(input)
    field.input = input

    local function Show(invalid) field.text:SetText(MaskText(mask, field.digits, invalid)) end
    field.Show = Show
    -- Programmatisch setzen, ohne die Änderungsmeldung auszulösen.
    function field.SetDigits(digits)
        field.syncing = true
        input:SetText(digits)
        field.syncing = false
        field.digits = digits
        Show(false)
    end
    input:SetScript("OnTextChanged", function(edit, userInput)
        -- Nur echte Eingaben auswerten; programmatisches SetText (Kalenderklicks) meldet userInput = false.
        if field.syncing or not userInput then return end
        local text = edit:GetText()
        local digits = text:gsub("%D", ""):sub(1, maxDigits)
        if digits ~= text then
            field.syncing = true
            edit:SetText(digits)
            field.syncing = false
        end
        field.digits = digits
        Show(false)
        onChange(field)
    end)
    input:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    input:SetScript("OnEditFocusGained", function() for _, e in ipairs(edges) do e:Show() end end)
    input:SetScript("OnEditFocusLost", function() for _, e in ipairs(edges) do e:Hide() end end)
    Show(false)
    return field
end

function Console:BuildCalendar()
    local cal = CreateFrame("Frame", "BugLabConsoleCalendar", UIParent)
    cal:SetFrameStrata("FULLSCREEN_DIALOG") -- eigenes Fenster über allen anderen, auch über Chatfenstern
    cal:SetToplevel(true)
    cal:SetClampedToScreen(true)
    cal:SetMovable(true)
    cal:EnableMouse(true)
    cal:RegisterForDrag("LeftButton")
    cal:SetScript("OnDragStart", cal.StartMoving)
    cal:SetScript("OnDragStop", cal.StopMovingOrSizing)
    local gridW = 7 * (CAL_W + CAL_GAP) - CAL_GAP
    cal:SetSize(gridW + 44, 424)
    local solid = cal:CreateTexture(nil, "BACKGROUND", nil, -8) -- deckend, damit nichts durchscheint
    solid:SetColorTexture(0.05, 0.05, 0.06, 1)
    solid:SetPoint("TOPLEFT", 2, -2)
    solid:SetPoint("BOTTOMRIGHT", -2, 2)
    BugLab:SkinFrame(cal)

    -- Titelzeile wie im Hauptfenster: Name groß in der Rahmenleiste, darunter die Beschreibung in Hellgrau.
    cal.title = cal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cal.title:SetPoint("TOP", 0, -3)
    cal.title:SetText(BugLab:Paint("WHITE", L["CAL_TITLE"]))
    cal.subtitle = cal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cal.subtitle:SetPoint("TOP", cal.title, "BOTTOM", 0, -15)
    cal.subtitle:SetText(BugLab:Paint("LIGHTGRAY", L["CAL_SUBTITLE"]))

    -- Vier Felder: Startdatum, Startzeit / Enddatum, Endzeit.
    local function Changed(field) self:OnCalendarInput(field) end
    local dateW = 150
    local function Place(field, row, column)
        field.box:SetPoint("TOPLEFT", cal, "TOPLEFT", 22 + (column == 1 and 0 or dateW + 12), -64 - (row - 1) * 40)
        field.box:SetWidth(column == 1 and dateW or gridW - dateW - 12)
    end
    cal.sd = MaskField(cal, L["CAL_START_DATE"], DATE_MASK, 8, Changed)
    cal.st = MaskField(cal, L["CAL_START_TIME"], TIME_MASK, 4, Changed)
    cal.ed = MaskField(cal, L["CAL_END_DATE"], DATE_MASK, 8, Changed)
    cal.et = MaskField(cal, L["CAL_END_TIME"], TIME_MASK, 4, Changed)
    Place(cal.sd, 1, 1); Place(cal.st, 1, 2); Place(cal.ed, 2, 1); Place(cal.et, 2, 2)
    -- Tab springt zum nächsten Feld.
    local order = { cal.sd, cal.st, cal.ed, cal.et }
    for i, field in ipairs(order) do
        field.input:SetScript("OnTabPressed", function() order[i % 4 + 1].input:SetFocus() end)
        field.input:SetScript("OnEnterPressed", function() self:ApplyCalendarInput() end)
    end

    cal.step = cal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cal.step:SetPoint("TOP", 0, -148)

    local function Step(delta) cal.month = cal.month + delta; self:LayoutCalendar() end
    cal:EnableMouseWheel(true)
    cal:SetScript("OnMouseWheel", function(_, delta) Step(-delta) end)
    local prev = Button(cal, "<", 28, function() Step(-1) end)
    prev:SetPoint("TOPLEFT", 22, -166)
    local nxt = Button(cal, ">", 28, function() Step(1) end)
    nxt:SetPoint("TOPRIGHT", -22, -166)
    cal.month_text = cal:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cal.month_text:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    cal.month_text:SetPoint("RIGHT", nxt, "LEFT", -4, 0)

    local x0, y0 = 22, -198
    local weekdays = { strsplit(",", L["CAL_WEEKDAYS"]) }
    for i = 1, 7 do
        local label = cal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOP", cal, "TOPLEFT", x0 + (i - 1) * (CAL_W + CAL_GAP) + CAL_W / 2, y0)
        label:SetText(BugLab:Paint("LIGHTGRAY", weekdays[i] or ""))
    end
    cal.days = {}
    for i = 1, 42 do
        local cell = DayCell(cal, function(c) self:PickDay(c.stamp) end)
        cell:SetPoint("TOPLEFT", x0 + ((i - 1) % 7) * (CAL_W + CAL_GAP), y0 - 16 - math.floor((i - 1) / 7) * (CAL_H + CAL_GAP))
        cell:SetScript("OnEnter", function(c) cal.hoverStamp = c.stamp; if cal.pending then self:LayoutCalendar() end end)
        cell:SetScript("OnLeave", function() cal.hoverStamp = false; if cal.pending then self:LayoutCalendar() end end)
        cal.days[i] = cell
    end

    local apply = Button(cal, L["APPLY"], 100, function() self:ApplyCalendarInput() end)
    apply:SetPoint("BOTTOM", -68, 16)
    local cancel = Button(cal, L["CANCEL"], 100, function() cal:Hide() end)
    cancel:SetPoint("BOTTOM", 73, 16)
    tinsert(UISpecialFrames, "BugLabConsoleCalendar")
    cal:Hide()
    return cal
end

-- Felder mit einem Zeitraum (oder den Vorgaben) füllen.
function Console:FillCalendarFields(from, to)
    local cal = self.calendar
    cal.sd.SetDigits(from and date("%d%m%Y", from) or "")
    cal.st.SetDigits(from and date("%H%M", from) or DEFAULT_START_TIME)
    cal.ed.SetDigits(to and date("%d%m%Y", to) or "")
    cal.et.SetDigits(to and date("%H%M", to) or DEFAULT_END_TIME)
end

function Console:OpenCalendar(anchor)
    local cal = self.calendar or self:BuildCalendar()
    self.calendar = cal
    if not cal.placed then -- beim ersten Öffnen mittig, danach bleibt die vom Nutzer gewählte Position
        cal:ClearAllPoints()
        cal:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        cal.placed = true
    end
    cal.pending, cal.hoverStamp, cal.typed = false, false, false
    self:FillCalendarFields(self.state.from, self.state.to)
    local t = date("*t", self.state.to or time())
    cal.month = t.year * 12 + t.month - 1
    self:LayoutCalendar()
    cal:Show()
end

-- Füllt die Tageszellen des angezeigten Monats (Woche beginnt am Montag).
function Console:LayoutCalendar()
    local cal = self.calendar
    local year, month = math.floor(cal.month / 12), cal.month % 12 + 1
    local names = { strsplit(",", L["CAL_MONTHS"]) }
    cal.month_text:SetText(BugLab:Paint("WHITE", (names[month] or string.format("%02d", month)) .. " " .. year))
    cal.step:SetText(BugLab:Paint("BRIGHTBLUE", cal.pending and L["CAL_STEP2"] or L["CAL_STEP1"]))

    local first = time({ year = year, month = month, day = 1, hour = 12 })
    local offset = (tonumber(date("%w", first)) + 6) % 7
    local today = BugLab:DayStart(time())
    -- Markierter Bereich: während der Wahl Starttag bis Mausposition, sonst die Eingabe oder der gespeicherte Zeitraum.
    local lo, hi
    if cal.pending then
        lo, hi = cal.pending, cal.hoverStamp or cal.pending
    elseif cal.typed then
        lo, hi = cal.typed[1], cal.typed[2]
    elseif self.state.from and self.state.to then
        lo, hi = BugLab:DayStart(self.state.from), BugLab:DayStart(self.state.to)
    end
    if lo and hi and lo > hi then lo, hi = hi, lo end

    for i = 1, 42 do
        local cell = cal.days[i]
        local stamp = time({ year = year, month = month, day = i - offset, hour = 0 })
        local d = date("*t", stamp)
        cell.stamp = stamp
        local ends = lo and (stamp == lo or stamp == hi)
        local inside = lo and stamp >= lo and stamp <= hi
        if ends then cell.fill:SetColorTexture(0.25, 0.55, 0.85, 0.85)
        elseif inside then cell.fill:SetColorTexture(0.25, 0.55, 0.85, 0.35)
        else cell.fill:SetColorTexture(1, 1, 1, d.month == month and 0.07 or 0.03) end
        local color = ends and "WHITE" or (d.month == month and "WHITE" or "GRAY")
        local label = tostring(d.day)
        if stamp == today and not ends then color = "BRIGHTBLUE" end
        label = BugLab:Paint(color, label)
        cell.text:SetText(label)
        for _, edge in ipairs(cell.edges) do edge:SetShown(stamp == today) end
    end
end

-- Eingabe in einem der Felder: gültige Daten erscheinen sofort markiert im Kalender, Fehler färben die Ziffern rot.
function Console:OnCalendarInput(field)
    local cal = self.calendar
    cal.pending = false
    local day1 = ParseDate(cal.sd.digits)
    local day2 = cal.ed.digits == "" and day1 or ParseDate(cal.ed.digits)
    cal.typed = (day1 and day2) and { math.min(day1, day2), math.max(day1, day2) } or false
    for _, f in ipairs({ cal.sd, cal.ed }) do
        local invalid = #f.digits == f.max and not ParseDate(f.digits)
        f.Show(invalid)
    end
    for _, f in ipairs({ cal.st, cal.et }) do
        f.Show(#f.digits == f.max and not ParseTime(f.digits))
    end
    if (field == cal.sd or field == cal.ed) and cal.typed then
        local t = date("*t", field == cal.ed and day2 or day1)
        cal.month = t.year * 12 + t.month - 1
    end
    self:LayoutCalendar()
end

function Console:ApplyCalendarInput()
    local cal = self.calendar
    local from, to = ParseRange(cal.sd.digits, cal.st.digits, cal.ed.digits, cal.et.digits)
    if not from then
        cal.step:SetText(BugLab:Paint("ERROR", L["CAL_INVALID"]))
        return
    end
    self.state.from, self.state.to = from, to
    cal:Hide()
    self:SetFilter("range", "custom")
end

-- Klick im Kalender: erster Klick = Startdatum, zweiter = Enddatum (Reihenfolge egal); die Zeiten bleiben bei den
-- Vorgaben bzw. den eingetragenen Werten. Übernommen wird erst mit "Übernehmen".
function Console:PickDay(stamp)
    local cal = self.calendar
    if not cal.pending then
        cal.pending, cal.typed = stamp, false
        cal.sd.SetDigits(date("%d%m%Y", stamp))
        cal.ed.SetDigits("")
        self:LayoutCalendar()
        return
    end
    local a, b = cal.pending, stamp
    if a > b then a, b = b, a end
    cal.pending = false
    cal.sd.SetDigits(date("%d%m%Y", a))
    cal.ed.SetDigits(date("%d%m%Y", b))
    cal.typed = { a, b }
    self:LayoutCalendar()
end

function Console:SetFilter(field, value)
    if field == "kind" then return self:SetKind(value) end
    self.state[field] = value
    self:UpdateFilterControls()
    self:RefreshHistory()
end

-- Text der Auswahl, z. B. "Quelle: Alle": Bezeichnung weiß, Wert BugLab-Blau (Stufen in ihrer Stufenfarbe).
function Console:FilterLabel(field)
    local current = self.state[field]
    for _, option in ipairs(self:GetOptions(field)) do
        if option[1] == current then
            local value = field == "level" and option[2] or BugLab:Paint("BRIGHTBLUE", option[3] or option[2])
            return BugLab:Paint("WHITE", L[FIELD_LABEL[field]] .. ":") .. " " .. value
        end
    end
    return L[FIELD_LABEL[field]]
end

-- Auswahl im Standarddesign des Spiels (DropdownButton mit Menü). Fehlt die Vorlage, bleibt ein Knopf, der
-- reihum den nächsten Wert wählt.
local function ShowTooltip(frame, field)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetText(L[FIELD_LABEL[field]])
    GameTooltip:AddLine(L[FIELD_TIP[field]], 1, 1, 1, true)
    GameTooltip:Show()
end

function Console:CreateFilterControl(parent, field, width)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(width, ROW_HEIGHT)
        -- Rahmen entfärbt (Grautöne), der Pfeil in BugLab-Blau.
        local arrowTint = { 0.6, 0.82, 1 }
        Desaturate(dropdown)
        if dropdown.Arrow then
            dropdown.Arrow:SetDesaturated(true)
            dropdown.Arrow:SetVertexColor(unpack(arrowTint))
        end
        -- Textposition aus dem Inspector übernommen: links 8, oben 7, rechts bis zum Pfeil.
        if dropdown.Text and dropdown.Arrow then
            dropdown.Text:ClearAllPoints()
            dropdown.Text:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 8, -7)
            dropdown.Text:SetPoint("TOPRIGHT", dropdown.Arrow, "LEFT", 0, 0)
        end
        dropdown:SetupMenu(function(_, root)
            for _, option in ipairs(self:GetOptions(field)) do
                local value = option[1]
                root:CreateRadio(option[2], function() return self.state[field] == value end,
                    function() self:SetFilter(field, value) end)
            end
        end)
        dropdown:SetDefaultText(self:FilterLabel(field))
        if dropdown.SetSelectionTranslator then
            dropdown:SetSelectionTranslator(function() return self:FilterLabel(field) end)
        end
        dropdown:HookScript("OnEnter", function(frame) ShowTooltip(frame, field) end)
        dropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)
        return dropdown
    end
    local button = Button(parent, "", width, function()
        local options = self:GetOptions(field)
        for i, option in ipairs(options) do
            if option[1] == self.state[field] then
                self:SetFilter(field, options[i % #options + 1][1])
                return
            end
        end
        self:SetFilter(field, options[1][1])
    end)
    button:SetScript("OnEnter", function(frame) ShowTooltip(frame, field) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- Schnellauswahl für den Zeitraum in einem Button-Rahmen: "1h 3h 12h 1d 3d 7d Alles Custom [Kalender]"; aktiv = blau,
-- sonst grau, Hover weiß. Custom öffnet den Kalender und zeigt danach den gewählten Zeitraum.
local KIND_WIDTH = 140 -- Auswahl des Logs (Debug/Probe) vor der Quelle
local RANGE_PAD = 8
local RANGE_CUSTOM_WIDTH, RANGE_SHORT_MAX, RANGE_SHORT_MIN = 112, 34, 24
local RANGE_HEIGHT = ROW_HEIGHT + 6 -- Der sichtbare Rahmen der Eingabevorlage ist kleiner als sein Frame: so wirkt er so hoch wie die Auswahllisten

-- Kleines Kalendersymbol aus Flächen (Rahmen, Kopfleiste, Tage); die Farbe setzt SetCalendarIconColor.
local function CalendarIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(12, 12)
    icon.parts = {}
    local function Part(x, y, w, h)
        local tex = icon:CreateTexture(nil, "OVERLAY")
        tex:SetPoint("TOPLEFT", x, -y)
        tex:SetSize(w, h)
        icon.parts[#icon.parts + 1] = tex
    end
    Part(0, 1, 12, 3)                   -- Kopfleiste
    Part(0, 4, 1, 8); Part(11, 4, 1, 8) -- Seiten
    Part(0, 11, 12, 1)                  -- Boden
    for row = 0, 1 do for col = 0, 2 do Part(2 + col * 3, 6 + row * 3, 2, 2) end end
    Part(2, 0, 1, 2); Part(9, 0, 1, 2)  -- Ringe
    return icon
end

local function SetCalendarIconColor(icon, r, g, b)
    for _, tex in ipairs(icon.parts) do tex:SetColorTexture(r, g, b, 1) end
end

function Console:CreateRangeBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(RANGE_HEIGHT)
    -- Rahmen wie die Texteingabe des Filters (leeres, entfärbtes Eingabefeld ohne Funktion).
    local frame = CreateFrame("EditBox", nil, bar, "InputBoxTemplate")
    frame:SetHeight(RANGE_HEIGHT)
    frame:SetScale(1.1) -- Wert aus dem Inspector
    frame:SetPoint("LEFT", bar, "LEFT", 5, 0)
    frame:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    frame:SetAutoFocus(false)
    frame:EnableMouse(false)
    Desaturate(frame)
    bar.items = {}
    local function add(key)
        local item = CreateFrame("Button", nil, bar)
        item:SetHeight(RANGE_HEIGHT - 4)
        item.key = key
        item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        -- Schrift exakt wie im Dropdown daneben.
        local dropdownText = self.view and self.view.source and self.view.source.Text
        if dropdownText and dropdownText.GetFont then
            local path, size, flags = dropdownText:GetFont()
            if path and size then item.text:SetFont(path, size, flags) end
        end
        if key == "custom" then
            item.icon = CalendarIcon(item)
            item.icon:SetPoint("RIGHT", 0, 0)
            item.text:SetPoint("RIGHT", item.icon, "LEFT", -4, 0)
        else
            item.text:SetPoint("CENTER")
        end
        item:SetScript("OnClick", function(f)
            if key == "custom" then self:OpenCalendar(bar) else self:SetFilter("range", key) end
        end)
        item:SetScript("OnEnter", function(f) item.hover = true; self:UpdateRangeBar(); ShowTooltip(f, "range") end)
        item:SetScript("OnLeave", function() item.hover = false; self:UpdateRangeBar(); GameTooltip:Hide() end)
        bar.items[#bar.items + 1] = item
    end
    for _, key in ipairs(BugLab.TIME_RANGES) do add(key) end
    add("custom")
    -- Die Kurzwerte werden bei Platzmangel schmaler (RANGE_SHORT_MAX bis RANGE_SHORT_MIN), Custom behält seine Breite.
    function bar.Layout(shortWidth)
        local x = RANGE_PAD
        for _, item in ipairs(bar.items) do
            local width = item.key == "custom" and RANGE_CUSTOM_WIDTH or shortWidth
            item:SetWidth(width)
            item:ClearAllPoints()
            item:SetPoint("LEFT", x, 0)
            x = x + width + 2
        end
        bar:SetWidth(x + RANGE_PAD - 2)
    end
    -- Breite der Leiste für die Kurzwert-Breite "shortWidth".
    function bar.WidthFor(shortWidth)
        return 2 * RANGE_PAD - 2 + (#bar.items - 1) * (shortWidth + 2) + RANGE_CUSTOM_WIDTH + 2
    end
    bar.Layout(RANGE_SHORT_MAX)
    return bar
end

function Console:UpdateRangeBar()
    local bar = self.view.range
    for _, item in ipairs(bar.items) do
        local key = item.key
        local label = key == "custom" and self:CustomRangeText() or L[TIME_RANGE_KEYS[key] .. "_SHORT"]
        local color = item.hover and "WHITE" or (self.state.range == key and "BRIGHTBLUE" or "LIGHTGRAY")
        item.text:SetText(BugLab:Paint(color, label))
        if item.icon then SetCalendarIconColor(item.icon, item.hover and 1 or 0.6, item.hover and 1 or 0.6, item.hover and 1 or 0.6) end
    end
end

function Console:UpdateFilterControls()
    local view = self.view
    self:UpdateRangeBar()
    for _, field in ipairs({ "kind", "source", "level" }) do
        local control = view[field]
        local label = self:FilterLabel(field)
        if control.SetDefaultText then
            control:SetDefaultText(label)
            if control.GenerateMenu then control:GenerateMenu() end
        else
            control:SetText(label)
        end
    end
    view.filter:SetText(self.state.text)
end

-- Alle Filter zurücksetzen (Quelle, Zeitraum, Stufe, Text).
-- Rückfrage vor dem Löschen: entweder nur die gewählte Quelle oder alle, danach "Jetzt löschen".
function Console:ShowClearDialog()
    local dialog = self.clearDialog
    if not dialog then
        dialog = CreateFrame("Frame", "BugLabClearDialog", UIParent)
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetToplevel(true)
        dialog:SetClampedToScreen(true)
        dialog:EnableMouse(true)
        dialog:SetSize(380, 190)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        local solid = dialog:CreateTexture(nil, "BACKGROUND", nil, -8)
        solid:SetColorTexture(0.05, 0.05, 0.06, 1)
        solid:SetPoint("TOPLEFT", 2, -2)
        solid:SetPoint("BOTTOMRIGHT", -2, 2)
        BugLab:SkinFrame(dialog)
        dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        dialog.title:SetPoint("TOP", 0, -3)
        dialog.title:SetText(BugLab:Paint("WHITE", L["CLEAR_TITLE"]))
        BugLab.CreateCloseButton(dialog, true)
        -- Warnung rot und hervorgehoben (WoW kennt keine kursive Schrift, "fett" kommt über den dicken Rand).
        dialog.warn = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        local face, size = GameFontHighlight:GetFont()
        if face then dialog.warn:SetFont(face, size, "THICKOUTLINE") end
        dialog.warn:SetPoint("TOPLEFT", 20, -40)
        dialog.warn:SetWidth(340)
        dialog.warn:SetJustifyH("LEFT")
        dialog.warn:SetText("|A:Ping_Wheel_Icon_Warning_Small:18:18|a " .. BugLab:Paint("ERROR", L["CLEAR_WARN"]))
        dialog.options = {}
        local function Choose(key)
            dialog.choice = key
            for name, check in pairs(dialog.options) do check:SetChecked(name == key) end
        end
        local function Option(key, y)
            local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 14, y)
            check.label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
            check:SetScript("OnClick", function() Choose(key) end)
            dialog.options[key] = check
            return check
        end
        Option("source", -68)
        Option("all", -98).label:SetText(L["CLEAR_ALL"])
        dialog.Choose = Choose
        dialog.confirm = Button(dialog, L["CLEAR_NOW"], 140, function()
            local source = dialog.choice == "source" and self.state.source or nil
            local removed = BugLab:ClearHistory(source, self.state.kind)
            dialog:Hide()
            self:RefreshHistory()
            BugLab:Log("BugLab:Console", L["CLEAR_DONE"]:format(removed), "INFO")
        end, true)
        dialog.confirm:SetPoint("BOTTOM", 0, 18)
        self.clearDialog = dialog
    end
    local source = self.state.source
    local sourceOption = dialog.options.source
    sourceOption.label:SetText(source and (L["CLEAR_SELECTED"] .. " " .. BugLab:Paint("BRIGHTBLUE", source)) or BugLab:Paint("GRAY", L["CLEAR_SELECTED_NONE"]))
    sourceOption:SetEnabled(source ~= nil)
    dialog.Choose(source and "source" or "all")
    dialog:Show()
end

function Console:SetKind(kind)
    self.state.kind = kind
    self:ClearFilters()
end

function Console:ClearFilters()
    for key, value in pairs(DEFAULT_STATE) do self.state[key] = value end
    self.state.source, self.state.from, self.state.to = nil, nil, nil
    self:UpdateFilterControls()
    self:RefreshHistory()
end


function Console:BuildHistory()
    local page = BugLab:GetPage("Console")
    local view = { page = page }
    self.view = view
    self.state = { kind = "console" }
    for key, value in pairs(DEFAULT_STATE) do self.state[key] = value end

    -- Symbolknopf; die Rückfrage (Quelle oder alles) steht im Dialog.
    view.clear = CreateFrame("Button", nil, page)
    view.clear:SetSize(ROW_HEIGHT, ROW_HEIGHT)
    view.clear:SetPoint("TOPRIGHT", -6, -6)
    view.clear.icon = view.clear:CreateTexture(nil, "ARTWORK")
    view.clear.icon:SetAllPoints()
    view.clear.icon:SetAtlas("128-RedButton-Delete")
    view.clear.glow = view.clear:CreateTexture(nil, "HIGHLIGHT")
    view.clear.glow:SetAllPoints()
    view.clear.glow:SetAtlas("128-RedButton-Delete")
    view.clear.glow:SetBlendMode("ADD")
    view.clear:SetScript("OnClick", function() self:ShowClearDialog() end)
    view.clear:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText(L["CLEAR_TITLE"], 1, 1, 1)
        GameTooltip:Show()
    end)
    view.clear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    view.kind = self:CreateFilterControl(page, "kind", KIND_WIDTH)
    view.source = self:CreateFilterControl(page, "source", 150)
    view.range = self:CreateRangeBar(page)
    view.level = self:CreateFilterControl(page, "level", 130)

    -- Zeile mit Texteingabe; die Erklärung erscheint per Mouseover, rechts löscht ein Knopf alle Filter.
    view.clearFilters = Button(page, L["CLEAR_FILTERS"], 110, function() self:ClearFilters() end)
    view.clearFilters:SetPoint("TOPRIGHT", page, "TOPRIGHT", -6, -34)
    view.filter = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    view.filter:SetHeight(ROW_HEIGHT)
    Desaturate(view.filter)
    view.filter:SetPoint("LEFT", page, "LEFT", 14, 0)
    view.filter:SetPoint("TOP", view.clearFilters, "TOP", 0, -1)
    view.filter:SetPoint("RIGHT", view.clearFilters, "LEFT", -8, 0)

    -- Obere Zeile endet bündig mit der Eingabe: Stufe rechts, Zeitraum daneben, die Quelle nimmt den Rest.
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(26)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -6)
    row:SetPoint("RIGHT", view.filter, "RIGHT", 0, 0)
    view.level:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    view.range:SetPoint("RIGHT", view.level, "LEFT", -10, 0)
    view.kind:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    view.source:SetPoint("LEFT", view.kind, "RIGHT", 10, 0)
    -- Platz verteilen: erst die Kurzwerte der Leiste verengen, dann die Stufe schmaler, zuletzt die Quelle (min. 90).
    row:SetScript("OnSizeChanged", function(_, width)
        local level = 130
        local function fit(levelWidth)
            local avail = width - 30 - KIND_WIDTH - 90 - levelWidth -- Platz für die Leiste bei kleinster Quelle
            for short = RANGE_SHORT_MAX, RANGE_SHORT_MIN, -1 do
                if view.range.WidthFor(short) <= avail then return short end
            end
        end
        local short = fit(level)
        if not short then level = 110; short = fit(level) or RANGE_SHORT_MIN end
        view.level:SetWidth(level)
        view.range.Layout(short)
        view.source:SetWidth(math.max(90, math.min(150, width - view.range:GetWidth() - level - KIND_WIDTH - 30)))
    end)
    view.filter:SetAutoFocus(false)
    BugLab:HookReloadKey(view.filter)
    view.filter:SetScript("OnTextChanged", function(edit)
        self.state.text = edit:GetText()
        self:RefreshHistory()
    end)
    view.filter:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    view.filter:SetScript("OnEnter", function(edit)
        GameTooltip:SetOwner(edit, "ANCHOR_TOP")
        GameTooltip:SetText(L["TIP_FILTER_TITLE"])
        GameTooltip:AddLine(L["TIP_FILTER"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    view.filter:SetScript("OnLeave", function() GameTooltip:Hide() end)

    view.count = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.count:SetPoint("BOTTOMLEFT", 8, 6)

    -- Anzeige als schreibgeschütztes Textfeld: mit der Maus markieren, Strg+C kopiert (mit Farbcodes).
    local log = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    log:SetPoint("TOPLEFT", view.filter, "BOTTOMLEFT", -8, -8)
    log:SetPoint("BOTTOMRIGHT", -26, 24)
    local text = CreateFrame("EditBox", nil, log)
    text:SetMultiLine(true)
    text:SetFontObject(ChatFontNormal)
    text:SetAutoFocus(false)
    BugLab:HookReloadKey(text)
    text:SetWidth(log:GetWidth() or 400)
    text.content = ""
    text:SetScript("OnTextChanged", function(edit, byUser)
        if byUser then edit:SetText(edit.content) end -- Eingaben verwerfen, die Anzeige bleibt unverändert
    end)
    text:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    log:SetScript("OnSizeChanged", function(_, width) text:SetWidth(width) end)
    log:SetScrollChild(text)
    view.log, view.text = log, text

    page:SetScript("OnShow", function() self:UpdateFilterControls(); self:RefreshHistory() end)
end

function Console:OnEnable()
    if not self.view then self:BuildHistory() end
    self:RegisterMessage("BUGLAB_LOG", "OnLogEntry")
    self:RegisterMessage("BUGLAB_PROBE_LOG", "OnProbeEntry")
    BugLab:Log("Console", L["CONSOLE_READY"]:format(#BugLab:GetHistory()))
    -- Das Chatfenster mit beiden Reitern gleich nach dem Login anlegen, nicht erst bei der ersten Zeile.
    C_Timer.After(1, function()
        self:GetChatFrame()
    end)
end
