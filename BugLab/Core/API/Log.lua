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

local isModule = {}
for _, name in ipairs(BugLab.MODULES) do isModule[name] = true end

-- Zeilen vor dem Start der Datenbank werden zwischengespeichert.
local pending = {}

local function History(self)
    return self.db and self.db.global.history
end

-- Legt eine Zeile ab, ohne Drosselung (auch für zusammengehörige Blöcke wie einen Dump).
function BugLab:AddEntry(source, text, level)
    local entry = {
        t = time(), s = tostring(source or "?"), m = tostring(text),
        i = isModule[source] and true or nil, l = self:LevelIndex(level),
    }
    local history = History(self)
    if history then
        history[#history + 1] = entry
        if #history > MAX_ENTRIES then self:PruneHistory() end
    else
        pending[#pending + 1] = entry
    end
    self:SendMessage("BUGLAB_LOG", entry)
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

function BugLab:GetLogger(source)
    source = tostring(source)
    local logger = self.loggers[source]
    if not logger then
        logger = setmetatable({ source = source, minLevel = 1, enabled = true }, Logger)
        self.loggers[source] = logger
    end
    return logger
end

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

function Logger:SetLevel(level) self.minLevel = BugLab:LevelIndex(level) end
function Logger:SetEnabled(enabled) self.enabled = enabled and true or false end

-- Übernimmt Zeilen, die vor dem Start der Datenbank gemeldet wurden.
function BugLab:FlushPendingLog()
    local history = History(self)
    if not history then return end
    for _, entry in ipairs(pending) do history[#history + 1] = entry end
    wipe(pending)
end

function BugLab:GetHistory()
    return History(self) or pending
end

-- Entfernt Zeilen, die älter als die eingestellte Dauer sind (Tage), und kappt auf MAX_ENTRIES.
function BugLab:PruneHistory(now)
    local history = History(self)
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

function BugLab:ClearHistory()
    local history = History(self)
    if history then wipe(history) end
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
function BugLab:GetLogSources()
    local seen, list = {}, {}
    local function add(key)
        if not seen[key] then seen[key] = true; list[#list + 1] = key end
    end
    for _, entry in ipairs(self:GetHistory()) do
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
    return self:Paint("GRAY", "{") .. "|T" .. self.MEDIA_PATH .. "BugLab_Beetle_White_32:12:12|t"
        .. ((addon or name) == "BugLab" and self:Paint("WHITE", "Bug") .. self:Paint("BRIGHTBLUE", "Lab")
            or self:Paint("BRIGHTBLUE", addon or name)) .. (module and self:Paint("GRAY", module) or "") .. self:Paint("GRAY", "}")
end

-- Stufe eines gespeicherten Eintrags (ältere Einträge ohne Stufe zählen als Info).
function BugLab:EntryLevel(entry)
    return entry.l or INFO
end

-- [HH:MM:SS] {Käfer Name} Text, der Text in der Farbe der Stufe.
function BugLab:FormatEntry(entry)
    local color = self.LEVEL_COLORS[self.LEVELS[self:EntryLevel(entry)]]
    local text = entry.m
    if color then
        -- Eingebettete Werte (blau) beenden ihre Farbe mit |r; danach geht die Stufenfarbe weiter.
        text = "|cff" .. color .. text:gsub("|r", "|r|cff" .. color) .. "|r"
    end
    return self:Paint("GRAY", date("[%H:%M:%S]", entry.t)) .. " " .. self:FormatSource(self:SourceKey(entry)) .. " " .. text
end

-- Datumszeile der Historie, hell und klar.
function BugLab:FormatDay(stamp)
    local pattern = (GetLocale() == "deDE") and "%d.%m.%Y" or "%Y-%m-%d"
    return "|cffffffff— " .. date(pattern, stamp) .. " —|r"
end

function BugLab:DayOf(stamp)
    return date("%Y%m%d", stamp)
end
