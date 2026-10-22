-- Log-API: Module und fremde Addons melden Zeilen, BugLab speichert sie als Historie und benachrichtigt die Ausgabe.
-- Aufruf aus anderen Addons: local BugLab = _G.BugLab; if BugLab then BugLab:Log("MeinAddon", "Text") end
local BugLab = _G.BugLab
local L = BugLab.L

local MAX_ENTRIES = 20000 -- Obergrenze zusätzlich zur Aufbewahrungsdauer
local DAY = 86400

-- Stufen wie in üblichen Logging-Systemen, aufsteigend nach Schwere. Textfarbe passend zur BugLab-Palette:
-- Debug hellgrau, Info unverändert, Warn Gelb (Blizzard-Warnton), Error Rot, Fatal kräftigeres Rot.
BugLab.LEVELS = { "DEBUG", "INFO", "WARN", "ERROR", "FATAL" }
BugLab.LEVEL_COLORS = { DEBUG = "999999", WARN = "ffd100", ERROR = "ff4040", FATAL = "ff1a1a" } -- INFO: keine Färbung
local LEVEL_INDEX = {}
for i, name in ipairs(BugLab.LEVELS) do LEVEL_INDEX[name] = i end
local INFO = LEVEL_INDEX.INFO

-- Stufe als Name (beliebige Schreibweise) oder Zahl; unbekannt = Info.
function BugLab:LevelIndex(level)
    if type(level) == "number" then return (level >= 1 and level <= #self.LEVELS) and level or INFO end
    return LEVEL_INDEX[tostring(level or "INFO"):upper()] or INFO
end

BugLab.LEVELS_ERROR_INDEX = LEVEL_INDEX.ERROR
local isModule = {}
for _, name in ipairs(BugLab.MODULES) do isModule[name] = true end

-- Zeilen vor dem Start der Datenbank werden zwischengespeichert.
local pending = {}
local probePending = {}

-- Zwei Historien mit gleichem Aufbau: "console" (Standard) und "probe" (Ausgaben der Probes).
local function History(self, kind)
    if not self.db then return nil end
    return kind == "probe" and self.db.global.probeHistory or self.db.global.history
end

-- Legt eine Zeile ab, ohne Drosselung (auch für zusammengehörige Blöcke wie einen Dump).
function BugLab:AddEntry(source, text, level, kind)
    local entry = {
        t = time(), s = tostring(source or "?"), m = tostring(text),
        i = isModule[source] and true or nil, l = self:LevelIndex(level),
    }
    local history = History(self, kind)
    if history then
        history[#history + 1] = entry
        if #history > MAX_ENTRIES then self:PruneHistory(nil, kind) end
    else
        local queue = kind == "probe" and probePending or pending
        queue[#queue + 1] = entry
    end
    self:SendMessage(kind == "probe" and "BUGLAB_PROBE_LOG" or "BUGLAB_LOG", entry)
    return entry
end

-- Drosselung je Quelle: höchstens logRateLimit Zeilen pro Sekunde (0 = aus). Überzählige Zeilen werden verworfen,
-- in der nächsten Sekunde meldet BugLab mit einer Warnung, wie viele es waren.
local buckets = {}

local function Throttled(self, source)
    local limit = self.db and self.db.profile.logRateLimit or 0
    if limit <= 0 then return false end
    local second = math.floor(GetTime())
    local bucket = buckets[source]
    if not bucket then
        bucket = { second = second, count = 0, dropped = 0 }
        buckets[source] = bucket
    end
    if bucket.second ~= second then
        local dropped = bucket.dropped
        bucket.second, bucket.count, bucket.dropped = second, 0, 0
        if dropped > 0 then self:AddEntry(source, L["LOG_THROTTLED"]:format(dropped), "WARN") end
    end
    if bucket.count >= limit then
        bucket.dropped = bucket.dropped + 1
        return true
    end
    bucket.count = bucket.count + 1
    return false
end

-- Meldet eine Zeile. source = Modulname oder Addonname, level = "DEBUG"|"INFO"|"WARN"|"ERROR"|"FATAL" (Standard INFO).
function BugLab:Log(source, text, level)
    if Throttled(self, tostring(source or "?")) then return nil end
    return self:AddEntry(source, text, level)
end

-- Logger je Addon: BugLab:GetLogger("MeinAddon"), danach log:Info("Zone %s", zone). Eingesetzte Werte erscheinen blau.
-- Jeder Logger hat eine eigene Mindeststufe und lässt sich abschalten.
local Logger = {}
Logger.__index = Logger
BugLab.loggers = {}

function BugLab:GetLogger(source, style)
    source = tostring(source)
    local logger = self.loggers[source]
    if not logger then
        logger = setmetatable({ source = source, minLevel = 1, enabled = true }, Logger)
        self.loggers[source] = logger
    end
    if style then logger:SetStyle(style) end
    return logger
end

-- Darstellung je Addon (gilt für alle Quellen "Addon" und "Addon:Teil", auch für Probes). Ohne Angabe gelten BugLabs
-- Namensfarbe, Abschnittspalette und Stufenfarben. style = {
--   name = "MeinAddon" (Schreibweise im Log), nameColor = "rrggbb",
--   colors = { "rrggbb", ... } (Palette für getrennte Werte), levelColors = { WARN = "rrggbb", ... } }
-- Farben als "rrggbb", "#rrggbb" oder "|cffrrggbb"; ungültige Angaben werden ignoriert.
BugLab.styles = {}

local function CleanHex(value)
    local hex = tostring(value or ""):match("(%x%x%x%x%x%x)$")
    return hex and hex:lower() or nil
end

function BugLab:SetAddonStyle(addon, style)
    addon = tostring(addon):match("^[^:]+")
    if not addon then return nil end
    local out = {}
    if type(style) == "table" then
        if type(style.name) == "string" and style.name ~= "" then out.name = style.name end
        out.nameColor = CleanHex(style.nameColor)
        if type(style.colors) == "table" then
            local palette = {}
            for _, color in ipairs(style.colors) do palette[#palette + 1] = CleanHex(color) end
            if #palette > 0 then out.colors = palette end
        end
        if type(style.levelColors) == "table" then
            out.levelColors = {}
            for level, color in pairs(style.levelColors) do out.levelColors[tostring(level):upper()] = CleanHex(color) end
        end
    end
    self.styles[addon] = (next(out) ~= nil) and out or nil
    return self.styles[addon]
end

function BugLab:GetAddonStyle(source)
    return self.styles[tostring(source):match("^[^:]+") or ""]
end

function Logger:SetStyle(style) return BugLab:SetAddonStyle(self.source, style) end

function Logger:Wants(level)
    return self.enabled and BugLab:LevelIndex(level) >= self.minLevel
end

function Logger:Log(level, fmt, ...)
    if not self:Wants(level) then return nil end
    return BugLab:Log(self.source, BugLab:FormatMessage(fmt, ...), level)
end

for _, name in ipairs(BugLab.LEVELS) do
    Logger[name:sub(1, 1) .. name:sub(2):lower()] = function(self, fmt, ...) return self:Log(name, fmt, ...) end
end

-- Gibt einen Wert (meist eine Tabelle) eingerückt aus; die Zeilen eines Dumps werden nicht gedrosselt.
function Logger:Dump(value, label, level, opts)
    level = level or "INFO"
    if not self:Wants(level) then return end
    if label then BugLab:AddEntry(self.source, tostring(label), level) end
    for _, line in ipairs(BugLab:DumpLines(value, opts)) do BugLab:AddEntry(self.source, line, level) end
end

-- Anmeldung eines Addons: einmal pro Sitzung eine Debug-Zeile mit Version und Debug-Zustand
-- (log:Announce({ version = "1.2.0", debug = true })). Ohne Version wird sie aus der TOC des Addons gelesen.
function Logger:Announce(opts)
    if self.announced then return nil end
    opts = opts or {}
    local version = opts.version
    if not version then
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local ok, value = pcall(getMeta, self.source:match("^[^:]+"), "Version")
        version = ok and value or nil
    end
    self.announced = true
    return BugLab:Log(self.source, BugLab:FormatMessage(BugLab.L["LOG_ANNOUNCE"], version or "?",
        BugLab.L[opts.debug and "LOG_DEBUG_ON" or "LOG_DEBUG_OFF"]), "DEBUG")
end

function Logger:SetLevel(level) self.minLevel = BugLab:LevelIndex(level) end
function Logger:SetEnabled(enabled) self.enabled = enabled and true or false end

-- Übernimmt Zeilen, die vor dem Start der Datenbank gemeldet wurden.
function BugLab:FlushPendingLog()
    local history = History(self)
    if not history then return end
    for _, entry in ipairs(pending) do history[#history + 1] = entry end
    wipe(pending)
    local probeHistory = History(self, "probe")
    for _, entry in ipairs(probePending) do probeHistory[#probeHistory + 1] = entry end
    wipe(probePending)
end

function BugLab:GetHistory(kind)
    return History(self, kind) or (kind == "probe" and probePending or pending)
end

-- Entfernt Zeilen, die älter als die eingestellte Dauer sind (Tage), und kappt auf MAX_ENTRIES.
function BugLab:PruneHistory(now, kind)
    local history = History(self, kind)
    if not history then return 0 end
    local cutoff = (now or time()) - self.db.profile.historyDays * DAY
    local first = 1
    while history[first] and history[first].t < cutoff do first = first + 1 end
    first = math.max(first, #history - MAX_ENTRIES + 1)
    if first <= 1 then return 0 end
    local kept = {}
    for i = first, #history do kept[#kept + 1] = history[i] end
    local removed = first - 1
    wipe(history)
    for i, entry in ipairs(kept) do history[i] = entry end
    return removed
end

-- Ohne Argument wird die ganze Historie gelöscht, mit Quelle nur deren Einträge (wie im Filter, "MeinAddon" umfasst
-- auch "MeinAddon:..."). Gibt die Zahl der gelöschten Einträge zurück.
function BugLab:ClearHistory(source, kind)
    local history = History(self, kind)
    if not history then return 0 end
    local before = #history
    if not source then
        wipe(history)
        return before
    end
    local kept = {}
    for _, entry in ipairs(history) do
        if not self:MatchesSource(entry, source) then kept[#kept + 1] = entry end
    end
    wipe(history)
    for i, entry in ipairs(kept) do history[i] = entry end
    return before - #kept
end

-- Quellenschlüssel eines Eintrags für den Filter: eigene Module als "BugLab:Console", externe Quellen wie gemeldet
-- ("MeinAddon" oder "MeinAddon:Modul" / "MeinAddon:Erweiterung").
function BugLab:SourceKey(entry)
    return entry.i and ("BugLab:" .. entry.s) or entry.s
end

-- Gehört der Eintrag zur gewählten Quelle? Der Addonname allein ("MeinAddon") umfasst auch alle "MeinAddon:..."-Quellen.
function BugLab:MatchesSource(entry, selected)
    local key = self:SourceKey(entry)
    return key == selected or key:sub(1, #selected + 1) == selected .. ":"
end

-- Auswahlliste der Quellen in der Historie, alphabetisch; ein Addon mit Unterquellen erscheint zusätzlich als Gruppe.
function BugLab:GetLogSources(kind)
    local seen, list = {}, {}
    local function add(key)
        if not seen[key] then seen[key] = true; list[#list + 1] = key end
    end
    for _, entry in ipairs(self:GetHistory(kind)) do
        local key = self:SourceKey(entry)
        add(key)
        local base = key:match("^([^:]+):")
        if base then add(base) end
    end
    table.sort(list)
    return list
end

-- {Käfer Addon:Modul}: Klammern grau, Käfer weiß, Addonname BugLab-Blau (BugLab selbst wie im Fenstertitel: "Bug" weiß, "Lab" blau), Modul oder Erweiterung (":Modul") grau.
function BugLab:FormatSource(name)
    local addon, module = name:match("^([^:]*)(:.*)$")
    local style = self:GetAddonStyle(name)
    local shown = (style and style.name or addon or name):gsub("|", "||")
    local label
    if style and (style.name or style.nameColor) then
        label = style.nameColor and ("|cff" .. style.nameColor .. shown .. "|r") or self:Paint("BRIGHTBLUE", shown)
    elseif (addon or name) == "BugLab" then
        label = self:Paint("WHITE", "Bug") .. self:Paint("BRIGHTBLUE", "Lab")
    else
        label = self:Paint("BRIGHTBLUE", shown)
    end
    return self:Paint("GRAY", "{") .. "|T" .. self.MEDIA_PATH .. "BugLab_Beetle_White_32:12:12|t"
        .. label .. (module and self:Paint("GRAY", module) or "") .. self:Paint("GRAY", "}")
end

-- Stufe eines gespeicherten Eintrags (ältere Einträge ohne Stufe zählen als Info).
function BugLab:EntryLevel(entry)
    return entry.l or INFO
end

-- Getrennte Werte ("a | b | c" oder "a; b; c") erscheinen reihum in unterschiedlichen Farben, damit man sie auseinanderhält.
-- Ein Trennzeichen "|" gilt nur, wenn es kein Escape des Spiels einleitet (|c, |r, |T, |H, ...); "||" ist ein echtes "|".
-- Eine Überschrift ("Name: Wert", der Teil vor dem ersten Doppelpunkt) steht in aufgehellter Farbe des Abschnitts.
-- Palette wie im Datenraster des Screenshots (Regenbogen von Rot bis Lila); Blau steht vorn, Rot zuletzt, damit
-- gewöhnliche Werte nicht wie Fehler wirken.
local SEGMENT_COLORS = { "61afef", "98c379", "e5c07b", "c678dd", "56b6c2", "d19a66", "e06c75" }
local ESCAPE_NEXT = "[cCrRtTaAhHnNkKqQ|]"

local function Lighten(hex)
    local out = {}
    for i = 1, 5, 2 do
        local value = tonumber(hex:sub(i, i + 1), 16)
        out[#out + 1] = string.format("%02x", math.floor(value + (255 - value) * 0.55))
    end
    return table.concat(out)
end

local function PaintSegment(text, color)
    local lead, body = text:match("^(%s*)(.-)$")
    if body == "" then return text end
    -- Überschrift: kurzer Text vor dem ersten Doppelpunkt, nur wenn kein Escape davor steht.
    local head, rest = body:match("^([^:|]-:)(.*)$")
    local inner = body
    if head and #head <= 28 then
        local bright = Lighten(color)
        inner = "|cff" .. bright .. head .. "|r|cff" .. color .. rest:gsub("|r", "|r|cff" .. color)
    else
        inner = body:gsub("|r", "|r|cff" .. color)
    end
    return lead .. "|cff" .. color .. inner .. "|r"
end

function BugLab:ColorizeSegments(text, palette)
    palette = palette or SEGMENT_COLORS
    -- Vorhandene Farben (z. B. blaue Werte aus FormatMessage) würden die Abschnittsfarbe überdecken: zuerst entfernen.
    local original = text
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local segments, separators, start, i = {}, {}, 1, 1
    while i <= #text do
        local char = text:sub(i, i)
        if char == ";" or (char == "|" and not text:sub(i + 1, i + 1):match(ESCAPE_NEXT)) then
            segments[#segments + 1] = text:sub(start, i - 1)
            separators[#separators + 1] = char
            start = i + 1
        elseif char == "|" then
            i = i + 1 -- zweites Zeichen des Escapes überspringen
        end
        i = i + 1
    end
    if #segments == 0 then return original end
    segments[#segments + 1] = text:sub(start)
    local out = {}
    for index, segment in ipairs(segments) do
        out[#out + 1] = PaintSegment(segment, palette[(index - 1) % #palette + 1])
        -- Ein "|" muss als "||" ausgegeben werden, sonst läse das Spiel das folgende "|r" als Text.
        if separators[index] then out[#out + 1] = "|cff808080" .. (separators[index] == "|" and "||" or separators[index]) .. "|r" end
    end
    return table.concat(out)
end

-- "[HH:MM:SS] {Käfer Name} " (ohne Uhrzeit, wenn hideTime gesetzt ist).
function BugLab:EntryPrefix(entry, hideTime)
    return (hideTime and "" or (self:Paint("GRAY", date("[%H:%M:%S]", entry.t)) .. " ")) .. self:FormatSource(self:SourceKey(entry)) .. " "
end

-- [HH:MM:SS] {Käfer Name} Text, der Text in der Farbe der Stufe.
function BugLab:FormatEntry(entry, hideTime)
    local style = self:GetAddonStyle(self:SourceKey(entry))
    local levelName = self.LEVELS[self:EntryLevel(entry)]
    local color = (style and style.levelColors and style.levelColors[levelName]) or self.LEVEL_COLORS[levelName]
    local text = entry.m
    -- Fehler und Fatal behalten ihre Stufenfarbe; sonst werden getrennte Werte reihum eingefärbt.
    local level = self:EntryLevel(entry)
    if level < self.LEVELS_ERROR_INDEX then
        local colored = self:ColorizeSegments(text, style and style.colors)
        if colored ~= text then return self:EntryPrefix(entry, hideTime) .. colored end
    end
    if color then
        -- Eingebettete Werte (blau) beenden ihre Farbe mit |r; danach geht die Stufenfarbe weiter.
        text = "|cff" .. color .. text:gsub("|r", "|r|cff" .. color) .. "|r"
    end
    return self:EntryPrefix(entry, hideTime) .. text
end

-- Datumszeile der Historie, hell und klar.
function BugLab:FormatDay(stamp)
    local pattern = (GetLocale() == "deDE") and "%d.%m.%Y" or "%Y-%m-%d"
    return "|cffffffff— " .. date(pattern, stamp) .. " —|r"
end

function BugLab:DayOf(stamp)
    return date("%Y%m%d", stamp)
end
