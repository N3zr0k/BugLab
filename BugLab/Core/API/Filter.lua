-- Textfilter für die Console: "wort" muss vorkommen, "-wort" schließt aus, Phrasen in Anführungszeichen.
-- Groß-/Kleinschreibung egal, Suche als einfacher Text (keine Lua-Muster). Weitere Platzhalter hier ergänzen.
local BugLab = _G.BugLab

-- Begriffe unter dieser Länge (in Zeichen) filtern nicht: einzelne Buchstaben würden die Anzeige beim Tippen zerreißen.
BugLab.FILTER_MIN_LENGTH = 3

-- Zeichenzahl eines UTF-8-Texts (Folgebytes zählen nicht mit).
local function Length(text)
    return #text:gsub("[\128-\191]", "")
end

-- Zerlegt die Eingabe in Begriffe: { text = "...", exclude = bool }.
function BugLab:ParseFilter(input)
    local terms = {}
    local pos = 1
    input = input or ""
    while pos <= #input do
        local _, nextPos = input:find("^%s+", pos)
        if nextPos then
            pos = nextPos + 1
        else
            local exclude = input:sub(pos, pos) == "-"
            if exclude then pos = pos + 1 end
            local text
            if input:sub(pos, pos) == '"' then
                local close = input:find('"', pos + 1, true)
                text = input:sub(pos + 1, (close or #input + 1) - 1)
                pos = (close or #input) + 1
            else
                local _, stop = input:find("^%S+", pos)
                text = input:sub(pos, stop or pos - 1)
                pos = (stop or #input) + 1
            end
            if Length(text) >= BugLab.FILTER_MIN_LENGTH then terms[#terms + 1] = { text = text:lower(), exclude = exclude } end
        end
    end
    return terms
end

-- Wahr, wenn die Zeile alle Pflichtbegriffe enthält und keinen ausgeschlossenen.
function BugLab:MatchesFilter(terms, line)
    line = line:lower()
    for _, term in ipairs(terms) do
        local found = line:find(term.text, 1, true) ~= nil
        if found == term.exclude then return false end
    end
    return true
end

-- Zeitraum-Voreinstellungen der Console: Schlüssel -> Untergrenze (Unixzeit) relativ zu "now"; nil = unbegrenzt.
-- "custom" ist ein frei gewählter Zeitraum (Kalender) und wird über von/bis (Tagesbeginn, Unixzeit) angegeben.
BugLab.TIME_RANGES = { "hour", "h3", "h12", "today", "d3", "week", "all" }
local RANGE_SECONDS = { hour = 3600, h3 = 3 * 3600, h12 = 12 * 3600, d3 = 3 * 86400, week = 7 * 86400 }

-- Unixzeit des Tagesbeginns (0:00 Uhr) für die Zeit "stamp".
function BugLab:DayStart(stamp)
    local t = date("*t", stamp)
    return time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 })
end

function BugLab:GetTimeRangeStart(key, now, from)
    if RANGE_SECONDS[key] then return now - RANGE_SECONDS[key] end
    if key == "today" then return self:DayStart(now) end
    if key == "custom" then return from end
    return nil
end

-- "from"/"to" gelten nur bei "custom": exakter Beginn und exaktes Ende (Unixzeit, beide inklusive).
function BugLab:InTimeRange(key, stamp, now, from, to)
    local start = self:GetTimeRangeStart(key, now, from)
    if start and stamp < start then return false end
    if key == "custom" and to and stamp > to then return false end
    return true
end
