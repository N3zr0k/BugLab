-- Syntaxfärbung für Lua-Text (Farbcodes des Spiels). Die Färbung dient nur der Anzeige: Textfelder zeigen beim Anklicken
-- (zum Markieren und Kopieren) wieder den reinen Text ohne Farbcodes.
local BugLab = _G.BugLab

-- Farben aus dem Editor-Theme, das Sven als Vorlage gegeben hat (Screenshot): "local" korallenrot, andere Schlüsselwörter
-- lila, Strings hellblau, Zahlen blassgrün, Kommentare grau, Aufrufe und Globals orange, Felder nach Punkt türkis.
local COLORS = {
    ["local"] = "ff7b72", keyword = "c586c0", constant = "569cd6", string = "a5d6ff", number = "b5cea8",
    comment = "8b949e", call = "ffa657", builtin = "dcdcaa", field = "4ec9b0", definition = "d2a8ff", brace = "ffd700",
}
local KEYWORDS = {}
for word in ("break do else elseif end for function goto if in repeat return then until while"):gmatch("%a+") do
    KEYWORDS[word] = true
end
local OPERATORS = { ["and"] = true, ["or"] = true, ["not"] = true } -- bleiben wie normaler Text
local BUILTINS = {}
for word in ("assert collectgarbage error getmetatable ipairs next pairs pcall print rawequal rawget rawset select setmetatable tonumber tostring type unpack xpcall string table math"):gmatch("%a+") do
    BUILTINS[word] = true
end
local CONSTANTS = { ["true"] = true, ["false"] = true, ["nil"] = true }

local function Plain(text) return (text:gsub("|", "||")) end

local function Paint(color, text) return "|cff" .. color .. Plain(text) .. "|r" end

-- Ende eines Langtexts [[ ... ]] / [=[ ... ]=] ab Position `start` (Index des ersten "["), sonst nil.
local function LongBracketEnd(code, start)
    local level = code:match("^%[(=*)%[", start)
    if not level then return nil end
    local _, close = code:find("]" .. level .. "]", start + #level + 2, true)
    return close or #code
end

-- Gibt den Lua-Text mit Farbcodes zurück. Unbekanntes und Operatoren bleiben ungefärbt; "|" wird zu "||".
function BugLab:HighlightLua(code)
    code = tostring(code or "")
    local out, pos, length = {}, 1, #code
    while pos <= length do
        local char = code:sub(pos, pos)
        local stop
        if code:sub(pos, pos + 1) == "--" then
            local long = LongBracketEnd(code, pos + 2)
            stop = long or ((code:find("\n", pos, true) or (length + 1)) - 1)
            out[#out + 1] = Paint(COLORS.comment, code:sub(pos, stop))
        elseif char == '"' or char == "'" then
            stop = pos
            while stop < length do
                stop = stop + 1
                local c = code:sub(stop, stop)
                if c == "\\" then stop = stop + 1
                elseif c == char or c == "\n" then break end
            end
            stop = math.min(stop, length)
            out[#out + 1] = Paint(COLORS.string, code:sub(pos, stop))
        elseif char == "[" and LongBracketEnd(code, pos) then
            stop = LongBracketEnd(code, pos)
            out[#out + 1] = Paint(COLORS.string, code:sub(pos, stop))
        elseif char:match("%d") or (char == "." and code:sub(pos + 1, pos + 1):match("%d")) then
            local number = code:match("^0[xX]%x+", pos) or code:match("^%d*%.?%d+[eE][+-]?%d+", pos) or code:match("^%d*%.?%d*", pos)
            stop = pos + #number - 1
            out[#out + 1] = Paint(COLORS.number, number)
        elseif char:match("[%a_]") then
            local word = code:match("^[%w_]+", pos)
            stop = pos + #word - 1
            local before = code:sub(1, pos - 1):match("([%.:]?)%s*$")
            local previous = code:sub(1, pos - 1):match("([%a_]+)%s*$")
            if before == "." or before == ":" then
                out[#out + 1] = Paint(COLORS.field, word)
            elseif word == "local" then
                out[#out + 1] = Paint(COLORS["local"], word)
            elseif KEYWORDS[word] then
                out[#out + 1] = Paint(COLORS.keyword, word)
            elseif CONSTANTS[word] then
                out[#out + 1] = Paint(COLORS.constant, word)
            elseif OPERATORS[word] then
                out[#out + 1] = Plain(word)
            elseif previous == "function" then
                out[#out + 1] = Paint(COLORS.definition, word)
            elseif BUILTINS[word] and code:match("^%s*[%(%.]", stop + 1) then
                out[#out + 1] = Paint(COLORS.builtin, word)
            elseif code:match("^%s*%(", stop + 1) or word:match("^[A-Z][A-Z0-9_]+$") or word:match("^C_%w+") then
                out[#out + 1] = Paint(COLORS.call, word)
            else
                out[#out + 1] = Plain(word)
            end
        else
            stop = pos
            if char == "{" or char == "}" then
                out[#out + 1] = Paint(COLORS.brace, char)
            else
                local run = code:match("^[^%a_%d\"'%-%[{}]+", pos) -- Satzzeichen und Leerraum am Stück
                if run then stop = pos + #run - 1 end
                out[#out + 1] = Plain(code:sub(pos, stop))
            end
        end
        pos = stop + 1
    end
    return table.concat(out)
end
