-- Darstellung von Werten für die Console: Bezeichnungen grau, Werte in BugLab-Blau.
local BugLab = _G.BugLab

function BugLab:FormatValue(value)
    if type(value) == "string" then return self:Paint("BRIGHTBLUE", '"' .. value .. '"') end
    return self:Paint("BRIGHTBLUE", tostring(value))
end

-- Wie string.format, aber jeder eingesetzte Wert steht in BugLab-Blau: FormatMessage("Zone %s, Ebene %d", zone, 4).
-- Ohne Werte bleibt der Text unverändert (dort darf ein Prozentzeichen vorkommen). Passt ein Wert nicht zum
-- Platzhalter, werden die Werte hinten angehängt, statt einen Fehler zu werfen.
function BugLab:FormatMessage(fmt, ...)
    fmt = tostring(fmt)
    local count = select("#", ...)
    if count == 0 then return fmt end
    local args, used = { ... }, 0
    local ok, text = pcall(string.gsub, fmt, "%%([%-%+ #0]*%d*%.?%d*)([%a%%])", function(flags, conversion)
        if conversion == "%" then return "%" end
        used = used + 1
        local value = args[used]
        if conversion == "s" then value = tostring(value) end
        return self:Paint("BRIGHTBLUE", string.format("%" .. flags .. conversion, value))
    end)
    if ok then return text end
    local parts = {}
    for i = 1, count do parts[i] = self:FormatValue(args[i]) end
    return fmt .. " " .. table.concat(parts, " ")
end

-- Tabelle als Zeilen: "Schlüssel:" grau, Werte blau, Unterebenen eingerückt. Tiefenlimit, Schutz vor Zyklen und
-- Zeilenlimit (weitere Zeilen werden mit einer Auslassung abgeschlossen).
function BugLab:DumpLines(value, opts)
    opts = opts or {}
    local maxDepth, maxLines = opts.depth or 3, opts.maxLines or 100
    local lines, seen, truncated = {}, {}, false

    local function add(text)
        if #lines < maxLines then lines[#lines + 1] = text else truncated = true end
    end

    local function walk(tbl, indent, depth)
        if seen[tbl] then add(indent .. self:Paint("GRAY", "<...>")); return end
        seen[tbl] = true
        local keys = {}
        for key in pairs(tbl) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            local item = tbl[key]
            local label = indent .. self:Paint("GRAY", tostring(key) .. ":")
            if type(item) ~= "table" then
                add(label .. " " .. self:FormatValue(item))
            elseif depth >= maxDepth then
                add(label .. " " .. self:Paint("GRAY", "{...}"))
            else
                add(label)
                walk(item, indent .. "  ", depth + 1)
            end
        end
        seen[tbl] = nil
    end

    if type(value) == "table" then walk(value, "", 1) else add(self:FormatValue(value)) end
    if truncated then lines[#lines + 1] = self:Paint("GRAY", "...") end
    return lines
end
