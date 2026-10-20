-- Inspector-API: liest Frames, Texturen und Schriften aus (Größe, Anker, Texturen, Skripte ...), erkennt die Herkunft
-- (Blizzard = nur Anzeige), ändert eigene Frames und erzeugt Lua-Code zum Nachbauen. Arbeitet auf beliebigen Objekten mit
-- der üblichen Frame-API und ist deshalb ohne Spiel testbar.
local BugLab = _G.BugLab
local L = BugLab.L

-- Ruft eine Methode geschützt auf; gibt eine Tabelle mit allen Rückgabewerten zurück (nil bei Fehler oder fehlender Methode).
local function TryAll(obj, method, ...)
    local fn = obj[method]
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, obj, ...) }
    if not table.remove(result, 1) then return nil end
    return result
end

-- Erster Rückgabewert einer geschützten Methode.
local function Try(obj, method, ...)
    local result = TryAll(obj, method, ...)
    return result and result[1]
end

BugLab.INSPECT_SCRIPTS = { "OnClick", "OnEnter", "OnLeave", "OnShow", "OnHide", "OnUpdate", "OnEvent", "OnMouseDown",
    "OnMouseUp", "OnMouseWheel", "OnDragStart", "OnDragStop", "OnKeyDown", "OnTextChanged", "OnValueChanged", "OnSizeChanged" }

-- Ist das Objekt ein Frame (hat Kinder) und kein Bereich (Textur, Schrift ...)?
function BugLab:IsFrameObject(obj)
    return type(obj.GetChildren) == "function"
end

-- Name für die Anzeige: globaler Name, sonst "Elternname.Schlüssel" (parentKey), sonst "<Typ>".
function BugLab:ObjectName(obj)
    local name = Try(obj, "GetName")
    if name then return name end
    local parent = Try(obj, "GetParent")
    if parent then
        local ok, key = pcall(function()
            for k, v in pairs(parent) do
                if v == obj and type(k) == "string" then return k end
            end
        end)
        if ok and key then return (Try(parent, "GetName") or "<" .. (Try(parent, "GetObjectType") or "?") .. ">") .. "." .. key end
    end
    return "<" .. (Try(obj, "GetObjectType") or "?") .. ">"
end

-- Herkunft: "Blizzard", Addonname, "BugLab" oder "?" (unbekannt, zur Laufzeit erzeugt). Namen, die mit "BugLab" beginnen,
-- gehören immer BugLab, ebenso ihre Kinder. "?" erbt vom Elternframe (außer UIParent und WorldFrame).
function BugLab:ObjectOwner(obj)
    local owners = _G.BugLabFrameOwners or {}
    local frame = obj
    if not self:IsFrameObject(obj) then frame = Try(obj, "GetParent") or obj end
    local name = Try(frame, "GetName")
    if name and name:find("^BugLab") then return "BugLab" end
    -- Alles unterhalb eines BugLab-Frames gehört BugLab, auch wenn es während eines fremden ADDON_LOADED entstand.
    local up = Try(frame, "GetParent")
    for _ = 1, 20 do
        if not up then break end
        local upName = Try(up, "GetName")
        if upName and upName:find("^BugLab") then return "BugLab" end
        up = Try(up, "GetParent")
    end
    local label = owners[frame]
    if label and label ~= "?" then return label end
    local parent = Try(frame, "GetParent")
    if parent and parent ~= _G.UIParent and parent ~= _G.WorldFrame then return self:ObjectOwner(parent) end
    return "?"
end

-- Gehört das Objekt dem Spiel? Dann nur Anzeige.
function BugLab:IsBlizzardObject(obj)
    local owner = self:ObjectOwner(obj)
    return owner == "Blizzard" or owner:find("^Blizzard_") ~= nil
end

local function Points(obj)
    local points = {}
    local count = Try(obj, "GetNumPoints") or 0
    for i = 1, count do
        local p = TryAll(obj, "GetPoint", i)
        if p then
            local relTo = p[2]
            points[#points + 1] = { point = p[1], relTo = relTo, relName = relTo and BugLab:ObjectName(relTo) or nil,
                relPoint = p[3], x = p[4] or 0, y = p[5] or 0 }
        end
    end
    return points
end

local function Names(list)
    local out = {}
    for _, obj in ipairs(list or {}) do
        out[#out + 1] = { object = obj, name = BugLab:ObjectName(obj), type = Try(obj, "GetObjectType") or "?" }
    end
    return out
end

-- Name der Textur: Atlasname, sonst Dateipfad; bei einer Datei-ID der aufgelöste Pfad (sofern der Client ihn kennt),
-- sonst die ID. Gibt zusätzlich die rohe Datei-ID oder den Pfad zurück.
function BugLab:TextureName(obj)
    local atlas = Try(obj, "GetAtlas")
    local file = Try(obj, "GetTexture")
    if atlas and atlas ~= "" then return atlas, file end
    if type(file) == "number" then
        local ctex = _G.C_Texture
        if ctex and ctex.GetFilenameFromFileDataID then
            local ok, path = pcall(ctex.GetFilenameFromFileDataID, file)
            if ok and type(path) == "string" and path ~= "" then return path, file end
        end
        return tostring(file), file
    end
    if type(file) == "string" and file ~= "" then return file, file end
    return nil, file
end

-- Alle auslesbaren Angaben zu einem Frame oder Bereich als Tabelle.
-- Wie man ein unbenanntes Objekt im Code erreicht (z. B. "MeinButton:GetHighlightTexture()").
BugLab.inspectRefs = setmetatable({}, { __mode = "k" })

function BugLab:DescribeObject(obj)
    local info = { object = obj }
    info.type = Try(obj, "GetObjectType") or "?"
    info.name = self:ObjectName(obj)
    info.isFrame = self:IsFrameObject(obj)
    info.owner = self:ObjectOwner(obj)
    info.parent = Try(obj, "GetParent")
    info.parentName = info.parent and self:ObjectName(info.parent) or nil
    info.shown, info.visible = Try(obj, "IsShown"), Try(obj, "IsVisible")
    info.alpha, info.effectiveAlpha = Try(obj, "GetAlpha"), Try(obj, "GetEffectiveAlpha")
    local size = TryAll(obj, "GetSize")
    info.width, info.height = size and size[1], size and size[2]
    local rect = TryAll(obj, "GetRect")
    if rect and rect[1] then info.rect = { left = rect[1], bottom = rect[2], width = rect[3], height = rect[4] } end
    info.points = Points(obj)
    info.layer = TryAll(obj, "GetDrawLayer")

    if info.isFrame then
        info.strata, info.level = Try(obj, "GetFrameStrata"), Try(obj, "GetFrameLevel")
        info.scale, info.effectiveScale = Try(obj, "GetScale"), Try(obj, "GetEffectiveScale")
        info.mouse, info.movable = Try(obj, "IsMouseEnabled"), Try(obj, "IsMovable")
        info.protected = Try(obj, "IsProtected")
        info.children = Names(TryAll(obj, "GetChildren"))
        info.regions = Names(TryAll(obj, "GetRegions"))
        info.scripts = {}
        for _, script in ipairs(self.INSPECT_SCRIPTS) do
            if Try(obj, "HasScript", script) and Try(obj, "GetScript", script) then info.scripts[#info.scripts + 1] = script end
        end
    end

    -- Mouseover-Effekt (Hervorhebungs-Textur von Buttons): eigenes Objekt, das sich ebenfalls verstellen lässt.
    if info.isFrame then
        local highlight = Try(obj, "GetHighlightTexture")
        if type(highlight) == "table" and highlight.GetObjectType then
            info.highlight = highlight
            info.highlightInfo = self:DescribeObject(highlight)
            if not info.name:find("^<") then self.inspectRefs[highlight] = info.name .. ":GetHighlightTexture()" end
        end
    end

    if info.type == "Texture" then
        info.texture, info.atlas = Try(obj, "GetTexture"), Try(obj, "GetAtlas")
        info.textureName = self:TextureName(obj)
        info.texCoord = TryAll(obj, "GetTexCoord")
        info.vertexColor = TryAll(obj, "GetVertexColor")
        info.blend, info.desaturated = Try(obj, "GetBlendMode"), Try(obj, "IsDesaturated")
        info.horizTile, info.vertTile = Try(obj, "GetHorizTile"), Try(obj, "GetVertTile")
    elseif info.type == "FontString" then
        info.text = Try(obj, "GetText")
        info.font = TryAll(obj, "GetFont")
        info.textColor = TryAll(obj, "GetTextColor")
        info.justifyH, info.justifyV = Try(obj, "GetJustifyH"), Try(obj, "GetJustifyV")
    end
    return info
end

-- Änderbar? Gibt true oder false plus Locale-Schlüssel des Grundes zurück.
function BugLab:CanEditObject(obj)
    if self:IsBlizzardObject(obj) then return false, "INS_LOCKED_BLIZZARD" end
    if Try(obj, "IsProtected") and InCombatLockdown and InCombatLockdown() then return false, "INS_LOCKED_COMBAT" end
    return true
end

-- Eigenschaften ------------------------------------------------------------------------------------------------------
-- Alles, was sich außer Position, Größe, Alpha, Skalierung und Farbe verstellen lässt: Sichtbarkeit, Maus, Strata, Level,
-- Zeichenebene, Textur (Datei/ID, Atlas, Ausschnitt, Mischmodus, Entsättigung, Kacheln) und Schrift (Text, Schrift,
-- Ausrichtung). Jede Eigenschaft hat Lesen (ReadProps), Setzen (SETTERS) und Code (PROP_CODE) an einer Stelle.

BugLab.INSPECT_ENUMS = {
    strata = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" },
    layer = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" },
    blend = { "DISABLE", "BLEND", "ALPHAKEY", "ADD", "MOD" },
    justifyH = { "LEFT", "CENTER", "RIGHT" },
    justifyV = { "TOP", "MIDDLE", "BOTTOM" },
}

-- Reihenfolge, in der Eigenschaften gesetzt und im Code ausgegeben werden (Atlas/Datei vor dem Ausschnitt).
local PROP_ORDER = { "file", "atlas", "texcoord", "blend", "desaturated", "horizTile", "vertTile", "text", "font",
    "justifyH", "justifyV", "layer", "strata", "level", "mouse", "shown" }

local function ReadProps(obj)
    local props = {}
    props.shown = Try(obj, "IsShown")
    if BugLab:IsFrameObject(obj) then
        props.mouse, props.strata, props.level = Try(obj, "IsMouseEnabled"), Try(obj, "GetFrameStrata"), Try(obj, "GetFrameLevel")
    end
    local layer = TryAll(obj, "GetDrawLayer")
    if layer and layer[1] then props.layer = layer[1] end
    local kind = Try(obj, "GetObjectType")
    if kind == "Texture" then
        props.file, props.atlas, props.texcoord = Try(obj, "GetTexture"), Try(obj, "GetAtlas"), TryAll(obj, "GetTexCoord")
        props.blend, props.desaturated = Try(obj, "GetBlendMode"), Try(obj, "IsDesaturated")
        props.horizTile, props.vertTile = Try(obj, "GetHorizTile"), Try(obj, "GetVertTile")
    elseif kind == "FontString" then
        props.text, props.font = Try(obj, "GetText"), TryAll(obj, "GetFont")
        props.justifyH, props.justifyV = Try(obj, "GetJustifyH"), Try(obj, "GetJustifyV")
    end
    return props
end

local function ToBool(value)
    if type(value) == "string" then
        value = value:lower()
        return value == "true" or value == "1" or value == "ja" or value == "yes"
    end
    return value and true or false
end

local function Numbers(text)
    local list = {}
    for number in tostring(text):gmatch("[%-%d%.]+") do list[#list + 1] = tonumber(number) end
    return list
end

-- "Pfad, Größe, Stil" oder {Pfad, Größe, Stil} -> Pfad, Größe, Stil
local function ParseFont(value)
    if type(value) == "table" then return value[1], tonumber(value[2]), value[3] or "" end
    local path, size, flags = tostring(value):match("^%s*([^,]-)%s*,%s*([%d%.]+)%s*,?%s*(.-)%s*$")
    return path, tonumber(size), flags or ""
end

local SETTERS = {
    shown = function(o, v) o:SetShown(ToBool(v)) end,
    mouse = function(o, v) o:EnableMouse(ToBool(v)) end,
    strata = function(o, v) o:SetFrameStrata(v) end,
    level = function(o, v) o:SetFrameLevel(assert(tonumber(v))) end,
    layer = function(o, v) local _, sub = o:GetDrawLayer(); o:SetDrawLayer(v, sub or 0) end,
    file = function(o, v) o:SetTexture(tonumber(v) or (v ~= "" and v or nil)) end,
    atlas = function(o, v) assert(v ~= ""); o:SetAtlas(v) end,
    texcoord = function(o, v)
        local list = type(v) == "table" and v or Numbers(v)
        assert(#list == 4 or #list == 8)
        o:SetTexCoord(unpack(list))
    end,
    blend = function(o, v) o:SetBlendMode(v) end,
    desaturated = function(o, v) o:SetDesaturated(ToBool(v)) end,
    horizTile = function(o, v) o:SetHorizTile(ToBool(v)) end,
    vertTile = function(o, v) o:SetVertTile(ToBool(v)) end,
    text = function(o, v) o:SetText(tostring(v)) end,
    font = function(o, v)
        local path, size, flags = ParseFont(v)
        assert(path and path ~= "" and size)
        o:SetFont(path, size, flags)
    end,
    justifyH = function(o, v) o:SetJustifyH(v) end,
    justifyV = function(o, v) o:SetJustifyV(v) end,
}

local function SameValue(a, b)
    if type(a) == "table" or type(b) == "table" then
        if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
        for i = 1, #a do if tostring(a[i]) ~= tostring(b[i]) then return false end end
        return true
    end
    return a == b
end

-- Ursprungswerte vor der ersten Änderung, damit "Zurücksetzen" möglich ist.
BugLab.inspectOriginals = setmetatable({}, { __mode = "k" })

-- Reihenfolge der ersten Änderung je Objekt, für den Änderungs-Code.
BugLab.inspectOrder = {}

local function SaveOriginal(obj)
    if BugLab.inspectOriginals[obj] then return end
    BugLab.inspectOrder[#BugLab.inspectOrder + 1] = obj
    local size = TryAll(obj, "GetSize")
    BugLab.inspectOriginals[obj] = {
        points = Points(obj), width = size and size[1], height = size and size[2],
        alpha = Try(obj, "GetAlpha"), scale = Try(obj, "GetScale"),
        color = TryAll(obj, "GetVertexColor") or TryAll(obj, "GetTextColor"),
        props = ReadProps(obj),
    }
end

local function ApplyPoints(obj, points)
    obj:ClearAllPoints()
    for _, p in ipairs(points) do obj:SetPoint(p.point, p.relTo, p.relPoint, p.x, p.y) end
end

-- Setzt eine Eigenschaft (Schlüssel siehe PROP_ORDER). Gibt true oder false plus Locale-Schlüssel des Grundes zurück.
function BugLab:SetProperty(obj, key, value)
    local ok, reason = self:CanEditObject(obj)
    if not ok then return false, reason end
    local setter = SETTERS[key]
    if not setter then return false, "INS_BAD_VALUE" end
    SaveOriginal(obj)
    if not pcall(setter, obj, value) then return false, "INS_BAD_VALUE" end
    return true
end

-- "RRGGBB" (auch mit #) oder {r, g, b} mit Werten von 0 bis 1 -> r, g, b.
local function ParseColor(value)
    if type(value) == "table" then
        local r, g, b = tonumber(value[1]), tonumber(value[2]), tonumber(value[3])
        if r and g and b then return r, g, b end
        return nil
    end
    local hex = type(value) == "string" and value:match("^#?(%x%x%x%x%x%x)$")
    if not hex then return nil end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- Ändert ein Feld: x, y (Abstand des ersten Ankers), width, height, alpha, scale. Gibt true oder false plus Grund zurück.
function BugLab:ApplyEdit(obj, field, value)
    local ok, reason = self:CanEditObject(obj)
    if not ok then return false, reason end
    if field == "color" then
        local r, g, b = ParseColor(value)
        local kind = Try(obj, "GetObjectType")
        if not r or (kind ~= "Texture" and kind ~= "FontString") then return false, "INS_BAD_VALUE" end
        SaveOriginal(obj)
        if kind == "Texture" then
            local old = TryAll(obj, "GetVertexColor") or {}
            obj:SetVertexColor(r, g, b, old[4] or 1)
        else
            local old = TryAll(obj, "GetTextColor") or {}
            obj:SetTextColor(r, g, b, old[4] or 1)
        end
        return true
    end
    value = tonumber(value)
    if not value then return false, "INS_BAD_VALUE" end
    SaveOriginal(obj)
    if field == "x" or field == "y" then
        local points = Points(obj)
        if #points == 0 then points[1] = { point = "BOTTOMLEFT", relTo = _G.UIParent, relPoint = "BOTTOMLEFT", x = 0, y = 0 } end
        points[1][field] = value
        ApplyPoints(obj, points)
    elseif field == "width" then obj:SetWidth(value)
    elseif field == "height" then obj:SetHeight(value)
    elseif field == "alpha" then obj:SetAlpha(math.max(0, math.min(1, value)))
    elseif field == "scale" and obj.SetScale then obj:SetScale(math.max(0.1, value))
    else return false, "INS_BAD_VALUE" end
    return true
end

function BugLab:ResetEdit(obj)
    local original = self.inspectOriginals[obj]
    if not original then return false end
    ApplyPoints(obj, original.points)
    if original.width then obj:SetWidth(original.width) end
    if original.height then obj:SetHeight(original.height) end
    if original.alpha then obj:SetAlpha(original.alpha) end
    if original.scale and obj.SetScale then obj:SetScale(original.scale) end
    -- Nur Eigenschaften zurücksetzen, die sich geändert haben (sonst würde z. B. ein Atlas durch seine Datei ersetzt).
    local current = ReadProps(obj)
    for _, key in ipairs(PROP_ORDER) do
        local value = original.props and original.props[key]
        if value ~= nil and not SameValue(value, current[key]) then pcall(SETTERS[key], obj, value) end
    end
    if original.color then
        local kind = Try(obj, "GetObjectType")
        if kind == "Texture" then obj:SetVertexColor(unpack(original.color))
        elseif kind == "FontString" then obj:SetTextColor(unpack(original.color)) end
    end
    return true
end

-- Darstellung ------------------------------------------------------------------------------------------------------

local function Num(value)
    if type(value) ~= "number" then return tostring(value) end
    if value == math.floor(value) then return tostring(value) end
    return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function ListText(list)
    local parts = {}
    for i, v in ipairs(list) do parts[i] = Num(v) end
    return table.concat(parts, ", ")
end

local function Blue(value) return BugLab:Paint("BRIGHTBLUE", value) end
local function Row(label, value) return BugLab:Paint("GRAY", label .. ":") .. " " .. Blue(value) end

local function ColorText(color)
    if not color then return "-" end
    return string.format("%s, %s, %s", Num(color[1] or 0), Num(color[2] or 0), Num(color[3] or 0))
        .. (color[4] and (", " .. Num(color[4])) or "")
end

local function PointText(p)
    local rel = p.relName and (" -> " .. p.relName .. " " .. tostring(p.relPoint)) or ""
    return string.format("%s%s (%s, %s)", p.point, rel, Num(p.x), Num(p.y))
end

-- Anzeigezeilen zu einer DescribeObject-Tabelle. Bezeichnungen grau, Werte blau, Abschnitte weiß.
-- Hex-Wert "RRGGBB" einer Farbe {r, g, b}.
local function HexColor(color)
    if not color then return "" end
    local function byte(v) return math.floor(math.max(0, math.min(1, v or 0)) * 255 + 0.5) end
    return string.format("%02X%02X%02X", byte(color[1]), byte(color[2]), byte(color[3]))
end

-- Gibt die Anzeigezeilen und, je Zeilennummer, die dort verstellbare Eigenschaft zurück ({ key, kind, value, options }):
-- kind "bool" (Umschalter), "enum" (Auswahl aus options) oder "text" (Eingabefeld).
function BugLab:FormatObjectInfo(info)
    local lines, props = {}, {}
    local function add(text) lines[#lines + 1] = text end
    -- "target": Objekt, auf das sich die Eigenschaft bezieht (Standard das gewählte Objekt; beim Mouseover-Effekt die Textur).
    local function prop(key, kind, value, options, target)
        props[#lines] = { key = key, kind = kind, value = value, options = options, target = target }
    end
    local function heading(key) add(""); add(self:Paint("WHITE", L[key])) end
    local enums = self.INSPECT_ENUMS

    add(self:Paint("WHITE", info.name) .. " " .. self:Paint("GRAY", "(" .. info.type .. ")"))
    add(Row(L["INS_OWNER"], info.owner))
    if info.parentName then add(Row(L["INS_PARENT"], info.parentName)) end
    if info.strata then
        add(Row(L["INS_STRATA"], info.strata)); prop("strata", "enum", info.strata, enums.strata)
        add(Row(L["INS_LEVEL"], tostring(info.level))); prop("level", "text", tostring(info.level))
    end
    add(Row(L["INS_SIZE"], Num(info.width) .. " x " .. Num(info.height)))
    if info.rect then
        add(Row(L["INS_RECT"], string.format("%s, %s, %s x %s", Num(info.rect.left), Num(info.rect.bottom),
            Num(info.rect.width), Num(info.rect.height))))
    end
    add(Row(L["INS_VISIBLE"], tostring(info.shown) .. " / " .. tostring(info.visible))); prop("shown", "bool", info.shown and true or false)
    add(Row(L["INS_ALPHA"], Num(info.alpha) .. " (" .. Num(info.effectiveAlpha) .. ")"))
    if info.scale then add(Row(L["INS_SCALE"], Num(info.scale) .. " (" .. Num(info.effectiveScale) .. ")")) end
    if info.isFrame then
        add(Row(L["INS_MOUSE"], tostring(info.mouse) .. (info.movable and " / " .. L["INS_MOVABLE"] or ""))); prop("mouse", "bool", info.mouse and true or false)
        if info.protected then add(Row(L["INS_PROTECTED"], "true")) end
    end
    if info.layer and info.layer[1] then
        add(Row(L["INS_LAYER"], tostring(info.layer[1]) .. " " .. tostring(info.layer[2] or 0))); prop("layer", "enum", info.layer[1], enums.layer)
    end

    heading("INS_ANCHORS")
    if #info.points == 0 then add(self:Paint("GRAY", "-")) end
    for i, p in ipairs(info.points) do add(self:Paint("GRAY", i .. ":") .. " " .. Blue(PointText(p))) end

    local function textureRows(tex, target, withName)
        if withName then add(Row(L["INS_TEXNAME"], tostring(tex.textureName))) end
        add(Row(L["INS_ATLAS"], tex.atlas or "-")); prop("atlas", "text", tex.atlas or "", nil, target)
        add(Row(L["INS_FILE"], tostring(tex.texture))); prop("file", "text", tostring(tex.texture or ""), nil, target)
        local coords = tex.texCoord and ListText(tex.texCoord) or "-"
        add(Row(L["INS_TEXCOORD"], coords)); prop("texcoord", "text", tex.texCoord and coords or "", nil, target)
        add(Row(L["INS_COLOR"], ColorText(tex.vertexColor))); prop("color", "text", HexColor(tex.vertexColor), nil, target)
        add(Row(L["INS_BLEND"], tostring(tex.blend))); prop("blend", "enum", tex.blend, enums.blend, target)
        add(Row(L["INS_DESATURATED"], tostring(tex.desaturated))); prop("desaturated", "bool", tex.desaturated and true or false, nil, target)
        add(Row(L["INS_HTILE"], tostring(tex.horizTile))); prop("horizTile", "bool", tex.horizTile and true or false, nil, target)
        add(Row(L["INS_VTILE"], tostring(tex.vertTile))); prop("vertTile", "bool", tex.vertTile and true or false, nil, target)
    end

    if info.type == "Texture" then
        heading("INS_TEXTURE")
        textureRows(info, nil, true)
    elseif info.type == "FontString" then
        heading("INS_TEXT")
        add(Row(L["INS_CONTENT"], tostring(info.text))); prop("text", "text", info.text or "")
        if info.font then
            local font = tostring(info.font[1]) .. ", " .. Num(info.font[2]) .. ", " .. tostring(info.font[3] or "")
            add(Row(L["INS_FONT"], font)); prop("font", "text", font)
        end
        add(Row(L["INS_COLOR"], ColorText(info.textColor))); prop("color", "text", HexColor(info.textColor))
        add(Row(L["INS_JUSTIFY_H"], tostring(info.justifyH))); prop("justifyH", "enum", info.justifyH, enums.justifyH)
        add(Row(L["INS_JUSTIFY_V"], tostring(info.justifyV))); prop("justifyV", "enum", info.justifyV, enums.justifyV)
    end

    if info.highlightInfo then
        heading("INS_HOVER")
        textureRows(info.highlightInfo, info.highlight, false)
    end

    if info.isFrame then
        if #info.scripts > 0 then heading("INS_SCRIPTS"); add(Blue(table.concat(info.scripts, ", "))) end
        heading("INS_CHILDREN")
        if #info.children == 0 then add(self:Paint("GRAY", "-")) end
        for i, child in ipairs(info.children) do add(self:Paint("GRAY", i .. ":") .. " " .. Blue(child.name) .. " " .. self:Paint("GRAY", "(" .. child.type .. ")")) end
        heading("INS_REGIONS")
        if #info.regions == 0 then add(self:Paint("GRAY", "-")) end
        for i, region in ipairs(info.regions) do add(self:Paint("GRAY", i .. ":") .. " " .. Blue(region.name) .. " " .. self:Paint("GRAY", "(" .. region.type .. ")")) end
    end
    return lines, props
end

-- Lua-Code zum Nachbauen ---------------------------------------------------------------------------------------------

local function Quote(value) return string.format("%q", tostring(value)) end

local function PointCode(var, p, parentVar, parentObj)
    local rel = "nil"
    if p.relTo then
        if p.relTo == parentObj then rel = parentVar
        elseif Try(p.relTo, "GetName") then rel = Try(p.relTo, "GetName") end
    end
    return string.format("%s:SetPoint(%s, %s, %s, %s, %s)", var, Quote(p.point), rel, Quote(p.relPoint or p.point),
        Num(p.x), Num(p.y))
end

local function RegionCode(out, region, parentVar, index)
    local kind = Try(region, "GetObjectType")
    local var = (kind == "Texture" and "tex" or "text") .. index
    local layer = TryAll(region, "GetDrawLayer") or {}
    if kind == "Texture" then
        out[#out + 1] = string.format("local %s = %s:CreateTexture(nil, %s, nil, %s)", var, parentVar, Quote(layer[1] or "ARTWORK"), tostring(layer[2] or 0))
        local atlas, file = Try(region, "GetAtlas"), Try(region, "GetTexture")
        if atlas then out[#out + 1] = string.format("%s:SetAtlas(%s)", var, Quote(atlas))
        elseif type(file) == "string" or type(file) == "number" then out[#out + 1] = string.format("%s:SetTexture(%s)", var, type(file) == "number" and tostring(file) or Quote(file)) end
        local coord = TryAll(region, "GetTexCoord")
        if coord and #coord == 8 then
            out[#out + 1] = string.format("%s:SetTexCoord(%s)", var, (function() local t = {} for i, v in ipairs(coord) do t[i] = Num(v) end return table.concat(t, ", ") end)())
        end
        local color = TryAll(region, "GetVertexColor")
        if color and not (color[1] == 1 and color[2] == 1 and color[3] == 1 and (color[4] or 1) == 1) then
            out[#out + 1] = string.format("%s:SetVertexColor(%s)", var, ColorText(color))
        end
        local blend = Try(region, "GetBlendMode")
        if blend and blend ~= "BLEND" then out[#out + 1] = string.format("%s:SetBlendMode(%s)", var, Quote(blend)) end
        if Try(region, "IsDesaturated") then out[#out + 1] = var .. ":SetDesaturated(true)" end
    else
        out[#out + 1] = string.format("local %s = %s:CreateFontString(nil, %s)", var, parentVar, Quote(layer[1] or "OVERLAY"))
        local font = TryAll(region, "GetFont")
        if font and font[1] then out[#out + 1] = string.format("%s:SetFont(%s, %s, %s)", var, Quote(font[1]), Num(font[2]), Quote(font[3] or "")) end
        local text = Try(region, "GetText")
        if text then out[#out + 1] = string.format("%s:SetText(%s)", var, Quote(text)) end
        local color = TryAll(region, "GetTextColor")
        if color then out[#out + 1] = string.format("%s:SetTextColor(%s)", var, ColorText(color)) end
        local justify = Try(region, "GetJustifyH")
        if justify then out[#out + 1] = string.format("%s:SetJustifyH(%s)", var, Quote(justify)) end
    end
    local size = TryAll(region, "GetSize")
    if size and size[1] then out[#out + 1] = string.format("%s:SetSize(%s, %s)", var, Num(size[1]), Num(size[2])) end
    for _, p in ipairs(Points(region)) do out[#out + 1] = PointCode(var, p, parentVar, Try(region, "GetParent")) end
end

-- Code, der einen Frame samt seinen Texturen und Schriften nachbaut (Kinderframes werden nur als Kommentar genannt).
function BugLab:ExportLua(obj)
    local out = { "-- " .. L["INS_EXPORT_HEADER"]:format(self:ObjectName(obj)) }
    local kind = Try(obj, "GetObjectType") or "Frame"
    if not self:IsFrameObject(obj) then
        RegionCode(out, obj, "parent", 1)
        return table.concat(out, "\n")
    end
    local name = Try(obj, "GetName")
    local parent = Try(obj, "GetParent")
    local parentName = parent and Try(parent, "GetName")
    out[#out + 1] = string.format("local f = CreateFrame(%s, %s, %s)", Quote(kind), name and Quote(name) or "nil",
        parentName or "UIParent")
    local size = TryAll(obj, "GetSize")
    if size and size[1] then out[#out + 1] = string.format("f:SetSize(%s, %s)", Num(size[1]), Num(size[2])) end
    for _, p in ipairs(Points(obj)) do out[#out + 1] = PointCode("f", p, parentName or "UIParent", parent) end
    local strata, level = Try(obj, "GetFrameStrata"), Try(obj, "GetFrameLevel")
    if strata then out[#out + 1] = string.format("f:SetFrameStrata(%s)", Quote(strata)) end
    if level then out[#out + 1] = string.format("f:SetFrameLevel(%s)", Num(level)) end
    local alpha, scale = Try(obj, "GetAlpha"), Try(obj, "GetScale")
    if alpha and alpha ~= 1 then out[#out + 1] = string.format("f:SetAlpha(%s)", Num(alpha)) end
    if scale and scale ~= 1 then out[#out + 1] = string.format("f:SetScale(%s)", Num(scale)) end
    for i, region in ipairs(TryAll(obj, "GetRegions") or {}) do
        out[#out + 1] = ""
        RegionCode(out, region, "f", i)
    end
    for _, child in ipairs(TryAll(obj, "GetChildren") or {}) do
        out[#out + 1] = "-- " .. L["INS_EXPORT_CHILD"]:format(self:ObjectName(child), Try(child, "GetObjectType") or "?")
    end
    return table.concat(out, "\n")
end

-- Pick: Objekte unter der Maus -----------------------------------------------------------------------------------------

local STRATA_ORDER = { WORLD = 1, BACKGROUND = 2, LOW = 3, MEDIUM = 4, HIGH = 5, DIALOG = 6, FULLSCREEN = 7,
    FULLSCREEN_DIALOG = 8, TOOLTIP = 9 }
local LAYER_ORDER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

-- Liegt der Mauszeiger über dem Objekt (rein geometrisch, auch bei deaktivierter Maus)? Ohne IsMouseOver wird das
-- Rechteck gegen die Mausposition geprüft.
local function MouseOver(obj)
    if type(obj.IsMouseOver) == "function" then
        local ok, over = pcall(obj.IsMouseOver, obj)
        if ok then return over end
    end
    local rect = TryAll(obj, "GetRect")
    if not (rect and rect[1] and GetCursorPosition) then return false end
    local scale = Try(obj, "GetEffectiveScale") or 1
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    return x >= rect[1] and x <= rect[1] + rect[3] and y >= rect[2] and y <= rect[2] + rect[4]
end

-- Prüft einen Frame samt Bereichen und trägt Treffer in "found" ein. Läuft je Frame in einem eigenen pcall: gesperrte oder
-- geschützte Spiel-Frames dürfen die Suche nicht abbrechen. Das Teure (Bereiche, Ebene) passiert nur bei Treffern.
local function Probe(frame, ignore, found)
    if ignore and ignore[frame] then return end
    if not MouseOver(frame) or not frame:IsVisible() then return end
    local base = (STRATA_ORDER[frame:GetFrameStrata() or "MEDIUM"] or 4) * 1e6 + (frame:GetFrameLevel() or 0) * 10
    found[#found + 1] = { object = frame, score = base + 5 }
    for _, region in ipairs({ frame:GetRegions() }) do
        if not (ignore and ignore[region]) and region:IsVisible() and MouseOver(region) then
            local layer, sub = region:GetDrawLayer()
            local score = base + (LAYER_ORDER[layer or "ARTWORK"] or 3) / 10 + (sub or 0) / 100
            -- Schrift liegt in der Auswahl vor ihrem Frame, sonst wäre sie nur mit dem Mausrad erreichbar.
            if region:GetObjectType() == "FontString" then score = base + 6 + (LAYER_ORDER[layer or "ARTWORK"] or 3) / 10 end
            found[#found + 1] = { object = region, score = score }
        end
    end
end

-- Alle sichtbaren Frames und Bereiche unter dem Mauszeiger, oberster zuerst, auch die des Spiels. "ignore" ist eine Menge
-- auszublendender Objekte (z. B. die eigenen Markierungen). UIParent und WorldFrame zählen nur, wenn nichts anderes darunter
-- liegt.
function BugLab:GetObjectsUnderMouse(ignore)
    local found = {}
    local frame = EnumerateFrames()
    while frame do
        pcall(Probe, frame, ignore, found)
        frame = EnumerateFrames(frame)
    end
    table.sort(found, function(a, b) return a.score > b.score end)
    local list = {}
    for _, entry in ipairs(found) do
        if entry.object ~= _G.UIParent and entry.object ~= _G.WorldFrame then list[#list + 1] = entry.object end
    end
    if #list == 0 then
        for _, entry in ipairs(found) do list[#list + 1] = entry.object end
    end
    return list
end

-- Änderungen ---------------------------------------------------------------------------------------------------------

local function PointSignature(points)
    local parts = {}
    for _, p in ipairs(points) do
        parts[#parts + 1] = table.concat({ p.point, tostring(p.relTo), tostring(p.relPoint), Num(p.x), Num(p.y) }, "|")
    end
    return table.concat(parts, ";")
end

local function ColorChanged(a, b)
    if not (a and b) then return false end
    for i = 1, 4 do
        if math.abs((a[i] or 1) - (b[i] or 1)) > 0.001 then return true end
    end
    return false
end

local function PropCode(key, value, props)
    if key == "shown" then return value and "f:Show()" or "f:Hide()"
    elseif key == "mouse" then return string.format("f:EnableMouse(%s)", tostring(value))
    elseif key == "strata" then return string.format("f:SetFrameStrata(%s)", Quote(value))
    elseif key == "level" then return string.format("f:SetFrameLevel(%s)", Num(value))
    elseif key == "layer" then return string.format("f:SetDrawLayer(%s)", Quote(value))
    elseif key == "file" then return string.format("f:SetTexture(%s)", type(value) == "number" and Num(value) or Quote(value))
    elseif key == "atlas" then return string.format("f:SetAtlas(%s)", Quote(value))
    elseif key == "texcoord" then return string.format("f:SetTexCoord(%s)", ListText(value))
    elseif key == "blend" then return string.format("f:SetBlendMode(%s)", Quote(value))
    elseif key == "desaturated" then return string.format("f:SetDesaturated(%s)", tostring(value))
    elseif key == "horizTile" then return string.format("f:SetHorizTile(%s)", tostring(value))
    elseif key == "vertTile" then return string.format("f:SetVertTile(%s)", tostring(value))
    elseif key == "text" then return string.format("f:SetText(%s)", Quote(value))
    elseif key == "font" then return string.format("f:SetFont(%s, %s, %s)", Quote(value[1]), Num(value[2]), Quote(value[3] or ""))
    elseif key == "justifyH" then return string.format("f:SetJustifyH(%s)", Quote(value))
    elseif key == "justifyV" then return string.format("f:SetJustifyV(%s)", Quote(value)) end
    return "-- " .. key .. " " .. tostring(props[key])
end

-- Code für alle bisher geänderten Elemente (auch mehrere verschiedene), nur mit dem, was sich gegenüber dem Ursprung
-- geändert hat. Elemente ohne Namen brauchen eine Referenz, die man selbst einträgt.
function BugLab:ChangesLua()
    local blocks = {}
    for _, obj in ipairs(self.inspectOrder) do
        local original = self.inspectOriginals[obj]
        if original then
            local body = {}
            local points = Points(obj)
            if PointSignature(points) ~= PointSignature(original.points) then
                body[#body + 1] = "f:ClearAllPoints()"
                for _, p in ipairs(points) do body[#body + 1] = PointCode("f", p, "f", Try(obj, "GetParent")) end
            end
            local size = TryAll(obj, "GetSize")
            if size and size[1] then
                local wChanged = original.width and math.abs(size[1] - original.width) > 0.001
                local hChanged = original.height and math.abs(size[2] - original.height) > 0.001
                if wChanged and hChanged then body[#body + 1] = string.format("f:SetSize(%s, %s)", Num(size[1]), Num(size[2]))
                elseif wChanged then body[#body + 1] = string.format("f:SetWidth(%s)", Num(size[1]))
                elseif hChanged then body[#body + 1] = string.format("f:SetHeight(%s)", Num(size[2])) end
            end
            local alpha = Try(obj, "GetAlpha")
            if alpha and original.alpha and math.abs(alpha - original.alpha) > 0.001 then
                body[#body + 1] = string.format("f:SetAlpha(%s)", Num(alpha))
            end
            local scale = Try(obj, "GetScale")
            if scale and original.scale and math.abs(scale - original.scale) > 0.001 then
                body[#body + 1] = string.format("f:SetScale(%s)", Num(scale))
            end
            local kind = Try(obj, "GetObjectType")
            local color = kind == "Texture" and TryAll(obj, "GetVertexColor") or kind == "FontString" and TryAll(obj, "GetTextColor")
            if color and ColorChanged(color, original.color) then
                body[#body + 1] = string.format("f:%s(%s)", kind == "Texture" and "SetVertexColor" or "SetTextColor", ColorText(color))
            end
            local current = ReadProps(obj)
            for _, key in ipairs(PROP_ORDER) do
                local old, now = original.props and original.props[key], current[key]
                if now ~= nil and not SameValue(old, now) then body[#body + 1] = PropCode(key, now, current) end
            end
            if #body > 0 then
                local name = self:ObjectName(obj)
                local ref = self.inspectRefs[obj] or (name:find("^<") and "nil -- Referenz ergänzen (Element hat keinen Namen)" or name)
                blocks[#blocks + 1] = table.concat({ "-- " .. name .. " (" .. tostring(kind) .. ")", "do", "    local f = " .. ref,
                    "    " .. table.concat(body, "\n    "), "end" }, "\n")
            end
        end
    end
    if #blocks == 0 then return "-- keine Änderungen" end
    return table.concat(blocks, "\n\n")
end
