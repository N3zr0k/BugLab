-- Datenbank: zeigt die SavedVariables geladener Addons als aufklappbaren Baum (nur lesend). Gezeigt wird der Stand im
-- Arbeitsspeicher; die Datei auf der Platte wird erst bei /reload oder Abmelden geschrieben. Rechts (senkrecht getrennt) steht der gewählte
-- Eintrag samt Unterzweigen als Lua-Text zum Kopieren.
local BugLab = _G.BugLab
local L = BugLab.L
local Database = BugLab:NewModule("Database", "AceEvent-3.0")

local ROW_HEIGHT, Desaturate, Button = BugLab.ROW_HEIGHT, BugLab.Desaturate, BugLab.CreateButton
local INDENT, DETAIL_WIDTH, DETAIL_SHARE, DETAIL_TOP = 14, 260, 0.42, 58
local MAX_CHILDREN, MAX_VISITED, MAX_MATCHES, MAX_DEPTH, MAX_TEXT = 500, 20000, 400, 12, 60000
local TYPE_COLOR = { string = "98c379", number = "d19a66", boolean = "c678dd", table = "61afef", ["function"] = "e5c07b" }

Database.varCache = {}
Database.state = { addon = nil, search = "", expanded = {}, selected = nil }

-- Daten ----------------------------------------------------------------------------------------------------------------

-- Beim Aufruf nachschlagen (nicht beim Laden), damit Tests und spätere API-Änderungen greifen.
local function Api(name)
    return (C_AddOns and C_AddOns[name]) or _G[name]
end

-- Namen der SavedVariables-Tabellen eines Addons. Zuerst aus der TOC ("## SavedVariables", "## SavedVariablesPerCharacter");
-- liefert der Client dort nichts (er gibt diese Felder nicht überall heraus), werden globale Tabellen gesucht, deren Name
-- mit dem Addonnamen beginnt (GlimpseDB, GlimpseCharDB, Glimpse_Areas ...). Das Addon-Objekt selbst (Name = Addonname),
-- Frames, Mixins, Vorlagen, Lokalisierungen und leere Tabellen werden übersprungen.
local SKIP_SUFFIXES = { "frame", "button", "template", "mixin", "locale", "locales", "namespace", "window", "tooltip" }

local function IsDataTable(value)
    return type(value) == "table" and rawget(value, 0) == nil -- Frames haben [0]
end

function Database:GuessVariables(addon)
    local names = {}
    local prefix = addon:gsub("[^%w]", ""):lower()
    if prefix == "" then return names end
    for key, value in pairs(_G) do
        if type(key) == "string" and IsDataTable(value) and key ~= "BugLab" then
            local lower = key:lower():gsub("[^%w]", "")
            local rest = lower:sub(#prefix + 1)
            local skip = rest == ""
            for _, suffix in ipairs(SKIP_SUFFIXES) do
                if rest:sub(-#suffix) == suffix then skip = true end
            end
            if lower:sub(1, #prefix) == prefix and not skip and next(value) ~= nil then names[#names + 1] = key end
        end
    end
    table.sort(names)
    return names
end

-- Beim Laden mitschneiden: Der Client legt die SavedVariables eines Addons kurz vor ADDON_LOADED an. Neue globale Tabellen
-- zwischen zwei ADDON_LOADED-Ereignissen sind daher die Kandidaten für das gerade geladene Addon. Das klappt nur für Addons,
-- die nach BugLab laden; für frühere greift die Namenssuche.
Database.captured = {} -- [Addon] = { Variablennamen }
local seenGlobals = {}

local function SnapshotGlobals()
    for key in pairs(_G) do seenGlobals[key] = true end
end
SnapshotGlobals()

function Database:OnAddonLoaded(addon)
    local found = {}
    for key, value in pairs(_G) do
        if not seenGlobals[key] then
            seenGlobals[key] = true
            if type(key) == "string" and IsDataTable(value) and next(value) ~= nil then found[#found + 1] = key end
        end
    end
    local prefix = tostring(addon):gsub("[^%w]", ""):lower()
    local names = {}
    for _, key in ipairs(found) do
        local rest = key:lower():gsub("[^%w]", "")
        local skip = rest == prefix
        rest = rest:sub(1, #prefix) == prefix and rest:sub(#prefix + 1) or rest
        for _, suffix in ipairs(SKIP_SUFFIXES) do
            if rest:sub(-#suffix) == suffix then skip = true end
        end
        if not skip then names[#names + 1] = key end
    end
    table.sort(names)
    if #names > 0 then self.captured[addon] = names end
    if self.varCache then self.varCache = {} end
end

local captureFrame = CreateFrame("Frame")
captureFrame:RegisterEvent("ADDON_LOADED")
captureFrame:SetScript("OnEvent", function(_, _, addon) Database:OnAddonLoaded(addon) end)

-- Von Hand eingetragene Variablen je Addon (bleiben gespeichert).
function Database:ManualVariables(addon)
    local store = BugLab.db and BugLab.db.global.dbVars
    return store and store[addon] or {}
end

function Database:AddManualVariable(addon, name)
    if not (addon and BugLab.db) then return false end
    local store = BugLab.db.global.dbVars
    if not store then
        store = {}
        BugLab.db.global.dbVars = store
    end
    store[addon] = store[addon] or {}
    for _, existing in ipairs(store[addon]) do if existing == name then return true end end
    store[addon][#store[addon] + 1] = name
    self.varCache = {}
    return true
end

function Database:RemoveManualVariable(addon, name)
    local list = self:ManualVariables(addon)
    for i, existing in ipairs(list) do
        if existing == name then
            table.remove(list, i)
            self.varCache = {}
            return true
        end
    end
    return false
end

function Database:GetVariables(addon)
    local cache = self.varCache
    if cache and cache[addon] then return cache[addon] end
    local names, seen = {}, {}
    local function add(name)
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    local getMeta = Api("GetAddOnMetadata")
    for _, field in ipairs({ "SavedVariables", "SavedVariablesPerCharacter" }) do
        local ok, list = false, nil
        if getMeta then ok, list = pcall(getMeta, addon, field) end
        if ok and type(list) == "string" then
            for name in list:gmatch("[^,%s]+") do add(name) end
        end
    end
    if #names == 0 then
        for _, name in ipairs(self.captured[addon] or {}) do add(name) end
    end
    if #names == 0 then
        for _, name in ipairs(self:GuessVariables(addon)) do add(name) end
    end
    for _, name in ipairs(self:ManualVariables(addon)) do add(name) end
    if cache then cache[addon] = names end
    return names
end

-- Alle geladenen Addons (alphabetisch), optional nur die mit gefundenen SavedVariables.
function Database:GetLoadedAddons(onlyWithVariables)
    local list = {}
    local getNum, getInfo, isLoaded = Api("GetNumAddOns"), Api("GetAddOnInfo"), Api("IsAddOnLoaded")
    if not (getNum and getInfo) then return list end
    for i = 1, getNum() do
        local name = getInfo(i)
        if type(name) == "table" then name = name.name end
        if name and (not isLoaded or isLoaded(name)) and (not onlyWithVariables or #self:GetVariables(name) > 0) then
            list[#list + 1] = name
        end
    end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

function Database:GetAddons() return self:GetLoadedAddons(true) end

-- Nur reine Daten: Zahlen, Texte, Wahrheitswerte und Tabellen ohne [0] (Frames). Funktionen, Userdata und Threads gehören
-- nicht in die SavedVariables und bleiben ausgeblendet (auch in Zählern, Suche und Lua-Text).
local DATA_KEY = { string = true, number = true, boolean = true }
local DATA_VALUE = { string = true, number = true, boolean = true }

local function IsData(key, value)
    if not DATA_KEY[type(key)] then return false end
    local kind = type(value)
    if kind == "table" then return rawget(value, 0) == nil end
    return DATA_VALUE[kind] == true
end

local function SortedKeys(tbl)
    local keys = {}
    for key, value in pairs(tbl) do
        if IsData(key, value) then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta == "number" end
        if ta == "number" then return a < b end
        return tostring(a):lower() < tostring(b):lower()
    end)
    return keys
end

local function IsIdentifier(key) return type(key) == "string" and key:match("^[%a_][%w_]*$") ~= nil end

local function KeyText(key)
    if type(key) == "string" then return key end
    return "[" .. tostring(key) .. "]"
end

-- Pfadausdruck wie im Lua-Code: Name.key["anderer key"][3]
local function ChildPath(path, key)
    if IsIdentifier(key) then return path .. "." .. key end
    if type(key) == "string" then return path .. "[" .. string.format("%q", key) .. "]" end
    return path .. "[" .. tostring(key) .. "]"
end

-- Kurzanzeige eines Wertes (Pipes werden verdoppelt, damit das Spiel sie nicht als Formatcode liest).
local function ValueText(value)
    local kind = type(value)
    local text
    if kind == "string" then
        text = value:gsub("\n", "\\n")
        if #text > 80 then text = text:sub(1, 80) .. "…" end
        text = '"' .. text .. '"'
    elseif kind == "table" then
        local n = 0
        for key, entry in pairs(value) do
            if IsData(key, entry) then n = n + 1 end
        end
        text = "{" .. n .. "}"
    else
        text = tostring(value)
    end
    return (text:gsub("|", "||"))
end
Database.ValueText = ValueText

-- Lua-Text eines Wertes mit Unterzweigen (Tiefe und Länge begrenzt, Zyklen markiert).
local function Serialize(value, indent, visited, state)
    local kind = type(value)
    if kind == "string" then return (string.format("%q", value):gsub("\\\n", "\\n")) end
    if kind ~= "table" then return tostring(value) end
    if visited[value] then return "nil --[[ Zyklus ]]" end
    if indent > MAX_DEPTH or state.length > MAX_TEXT then return "{ --[[ … ]] }" end
    visited[value] = true
    local pad, parts = string.rep("  ", indent + 1), {}
    for i, key in ipairs(SortedKeys(value)) do
        if i > MAX_CHILDREN then
            parts[#parts + 1] = pad .. "--[[ … weitere Einträge ]]"
            break
        end
        local keyText = IsIdentifier(key) and key or ("[" .. (type(key) == "string" and string.format("%q", key) or tostring(key)) .. "]")
        local line = pad .. keyText .. " = " .. Serialize(value[key], indent + 1, visited, state) .. ","
        state.length = state.length + #line
        parts[#parts + 1] = line
    end
    visited[value] = nil
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, "\n") .. "\n" .. string.rep("  ", indent) .. "}"
end

function Database:SerializeEntry(path, value)
    return path .. " = " .. Serialize(value, 0, {}, { length = 0 })
end

-- Sichtbare Zeilen: je Variable der Baum, aufgeklappte Tabellen mit ihren Kindern. Bei einer Suche nur Zweige, in denen
-- ein Schlüssel oder Wert den Suchtext enthält (diese sind dann automatisch aufgeklappt).
function Database:BuildRows()
    local rows, state = {}, self.state
    local needle = (state.search or ""):lower()
    local visited, matches = 0, 0
    local function hit(key, value)
        if tostring(key):lower():find(needle, 1, true) then return true end
        return type(value) ~= "table" and tostring(value):lower():find(needle, 1, true) ~= nil
    end
    -- Gibt zurück, ob im Zweig etwas passt; hängt die Zeilen des Zweigs an `out` an.
    local function walk(key, value, path, depth, out, ancestors)
        visited = visited + 1
        local row = { key = key, value = value, path = path, depth = depth }
        if needle == "" then
            out[#out + 1] = row
            if type(value) == "table" and state.expanded[path] and not ancestors[value] then
                ancestors[value] = true
                for i, childKey in ipairs(SortedKeys(value)) do
                    if i > MAX_CHILDREN then
                        out[#out + 1] = { more = true, depth = depth + 1, count = #SortedKeys(value) - MAX_CHILDREN }
                        break
                    end
                    walk(childKey, value[childKey], ChildPath(path, childKey), depth + 1, out, ancestors)
                end
                ancestors[value] = nil
            end
            return true
        end
        local mine = hit(key, value)
        local childRows, found = {}, false
        if type(value) == "table" and depth < MAX_DEPTH and not ancestors[value] and visited < MAX_VISITED then
            ancestors[value] = true
            for _, childKey in ipairs(SortedKeys(value)) do
                if matches >= MAX_MATCHES or visited >= MAX_VISITED then break end
                if walk(childKey, value[childKey], ChildPath(path, childKey), depth + 1, childRows, ancestors) then found = true end
            end
            ancestors[value] = nil
        end
        if mine or found then
            if mine then matches = matches + 1 end
            row.open = found
            out[#out + 1] = row
            for _, child in ipairs(childRows) do out[#out + 1] = child end
            return true
        end
        return false
    end
    for _, name in ipairs(state.addon and self:GetVariables(state.addon) or {}) do
        local value = rawget(_G, name)
        if value ~= nil then walk(name, value, name, 0, rows, {}) end
    end
    return rows
end

-- Oberfläche -------------------------------------------------------------------------------------------------------------

function Database:RowText(row)
    local state = self.state
    if row.more then return BugLab:Paint("GRAY", L["DB_MORE"]:format(row.count)) end
    local isTable = type(row.value) == "table"
    local open = isTable and (state.expanded[row.path] or row.open)
    local arrow = isTable and BugLab:Paint("LIGHTGRAY", open and "- " or "+ ") or "  "
    local color = TYPE_COLOR[type(row.value)] or "999999"
    local key = BugLab:Paint("BRIGHTBLUE", (KeyText(row.key):gsub("|", "||")))
    return arrow .. key .. BugLab:Paint("GRAY", "  =  ") .. "|cff" .. color .. ValueText(row.value) .. "|r"
end

function Database:GetRow(index)
    local view = self.view
    local row = view.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, view.content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("RIGHT", view.content, "RIGHT")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.2, 0.45, 0.65, 0.35)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.08)
    row:SetScript("OnClick", function(button) self:OnRowClick(button.data) end)
    view.rows[index] = row
    return row
end

function Database:OnRowClick(data)
    if not data or data.more then return end
    local state = self.state
    state.selected = data.path
    if type(data.value) == "table" and (state.search or "") == "" then
        state.expanded[data.path] = not state.expanded[data.path] or nil
    end
    self:Refresh()
end

-- Zeichnet nur die sichtbaren Zeilen (der ScrollFrame hat die Gesamthöhe, die Zeilen werden wiederverwendet).
function Database:Paint()
    local view, state = self.view, self.state
    local shown = view.list or {}
    local height = tonumber(view.scroll:GetHeight()) or 300
    local offset = math.floor((tonumber(view.scroll:GetVerticalScroll()) or 0) / ROW_HEIGHT)
    local capacity = math.ceil(height / ROW_HEIGHT) + 1
    for i = 1, capacity do
        local data = shown[offset + i]
        local row = self:GetRow(i)
        if data then
            row.data = data
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", view.content, "TOPLEFT", 0, -(offset + i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", view.content, "RIGHT")
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", 4 + data.depth * INDENT, 0)
            row.text:SetPoint("RIGHT", -4, 0)
            row.text:SetText(self:RowText(data))
            row.bg:SetShown(data.path ~= nil and data.path == state.selected)
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end
    for i = capacity + 1, #view.rows do view.rows[i]:Hide() end
end

function Database:Refresh()
    local view, state = self.view, self.state
    if not view then return end
    view.list = self:BuildRows()
    view.content:SetHeight(math.max(#view.list * ROW_HEIGHT, 10))
    view.empty:SetShown(#view.list == 0)
    view.empty:SetText(BugLab:Paint("GRAY", state.addon and L["DB_EMPTY"] or L["DB_NONE"]))
    self:Paint()
    -- Auswahl als Lua-Text zeigen
    local text = ""
    if state.selected then
        for _, data in ipairs(view.list) do
            if data.path == state.selected then
                text = self:SerializeEntry(data.path, data.value)
                break
            end
        end
    end
    view.SetDetail(text)
end

function Database:SelectAddon(addon)
    local state = self.state
    if state.addon ~= addon then
        state.addon, state.selected, state.expanded = addon, nil, {}
        -- Variablen mit nur einem Eintrag direkt aufklappen: der AceDB-Baum ist sofort zu sehen.
        for _, name in ipairs(addon and self:GetVariables(addon) or {}) do
            if type(rawget(_G, name)) == "table" then state.expanded[name] = true end
        end
    end
    if self.view and self.view.menu and self.view.menu.GenerateMenu then self.view.menu:GenerateMenu() end
    if self.view then self.view.addonText:SetText(addon and BugLab:Paint("BRIGHTBLUE", addon) or BugLab:Paint("GRAY", L["DB_NONE"])) end
    self:Refresh()
end

function Database:OnAddClicked()
    local view, addon = self.view, self.state.addon
    if not addon then BugLab:Print(L["DB_ADD_NO_ADDON"]) return end
    local added = false
    for name in view.addBox:GetText():gmatch("[^,%s]+") do
        if type(rawget(_G, name)) == "table" then
            self:AddManualVariable(addon, name)
            added = true
        else
            BugLab:Print(L["DB_ADD_MISSING"]:format(name))
        end
    end
    if added then
        view.addBox:SetText("")
        self.state.expanded = self.state.expanded or {}
        self:Refresh()
    end
end

-- Entfernt die von Hand eingetragene Variable, zu der die gewählte Zeile gehört.
function Database:OnRemoveClicked()
    local state = self.state
    local root = state.selected and state.selected:match("^[^%.%[]+")
    if root and self:RemoveManualVariable(state.addon, root) then
        state.selected = nil
        self:Refresh()
    else
        BugLab:Print(L["DB_REMOVE_NONE"])
    end
end

function Database:BuildPage()
    local page = BugLab:GetPage("Database")
    local view = { page = page, rows = {} }
    self.view = view

    view.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.label:SetPoint("TOPLEFT", 12, -8)
    view.label:SetText(BugLab:Paint("LIGHTGRAY", L["DB_ADDON"]))
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(220, ROW_HEIGHT)
        Desaturate(dropdown)
        if dropdown.Arrow then dropdown.Arrow:SetDesaturated(true); dropdown.Arrow:SetVertexColor(0.6, 0.82, 1) end
        dropdown:SetupMenu(function(_, root)
            for _, name in ipairs(self:GetAddons()) do
                root:CreateRadio(name, function() return self.state.addon == name end, function() self:SelectAddon(name) end)
            end
            -- Alle geladenen Addons, damit sich dort eine Variable von Hand eintragen lässt.
            if root.CreateButton then
                local all = root:CreateButton(L["DB_ALL_ADDONS"])
                for _, name in ipairs(self:GetLoadedAddons(false)) do
                    all:CreateRadio(name, function() return self.state.addon == name end, function() self:SelectAddon(name) end)
                end
            end
        end)
        view.menu = dropdown
        view.addonText = dropdown.Text or page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    else
        dropdown = Button(page, "", 220, function()
            local list = self:GetAddons()
            local index = 0
            for i, name in ipairs(list) do if name == self.state.addon then index = i end end
            self:SelectAddon(list[index % math.max(#list, 1) + 1])
        end)
        view.addonText = dropdown
    end
    dropdown:SetPoint("TOPLEFT", 6, -22)
    view.dropdown = dropdown

    view.search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    view.search:SetSize(200, ROW_HEIGHT)
    view.search:SetPoint("LEFT", dropdown, "RIGHT", 18, 0)
    view.search:SetAutoFocus(false)
    Desaturate(view.search)
    BugLab:HookReloadKey(view.search)
    view.searchHint = view.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.searchHint:SetPoint("LEFT", 6, 0)
    view.searchHint:SetText(L["DB_SEARCH"])
    view.search:SetScript("OnTextChanged", function(edit)
        view.searchHint:SetShown(edit:GetText() == "")
        self.state.search = edit:GetText()
        self:Refresh()
    end)
    view.search:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)

    view.refresh = Button(page, L["DB_REFRESH"], 120, function() self:Refresh() end)
    view.refresh:SetPoint("LEFT", view.search, "RIGHT", 10, 0)

    view.note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.note:SetPoint("TOPRIGHT", -8, -10)
    view.note:SetText(L["DB_NOTE"])

    local detail, SetDetail = BugLab.CreateTextArea(page, true)
    -- Senkrechte Trennung: links der Baum, rechts der gewählte Eintrag als Lua-Text.
    detail:SetPoint("TOPRIGHT", page, "TOPRIGHT", -26, -DETAIL_TOP)
    detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -26, 8)
    detail:SetWidth(DETAIL_WIDTH)
    view.SetDetail = SetDetail
    view.detail = detail
    page:SetScript("OnSizeChanged", function(_, width)
        detail:SetWidth(math.max(DETAIL_WIDTH, math.floor((tonumber(width) or 0) * DETAIL_SHARE)))
    end)
    view.divider = page:CreateTexture(nil, "ARTWORK")
    view.divider:SetColorTexture(0.35, 0.35, 0.35, 0.8)
    view.divider:SetWidth(1)
    view.divider:SetPoint("TOP", detail, "TOPLEFT", -8, 0)
    view.divider:SetPoint("BOTTOM", detail, "BOTTOMLEFT", -8, 0)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 6, 8 + ROW_HEIGHT + 6)
    scroll:SetPoint("RIGHT", detail, "LEFT", -26, 0)
    view.scroll = scroll
    view.content = CreateFrame("Frame", nil, scroll)
    view.content:SetSize(400, 10)
    scroll:SetScrollChild(view.content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        view.content:SetWidth(math.max(tonumber(width) or 0, 200))
        self:Paint()
    end)
    scroll:SetScript("OnVerticalScroll", function(frame, offset)
        frame:SetVerticalScroll(offset)
        self:Paint()
    end)

    -- Untere Zeile: Variable eines Addons von Hand eintragen (der Client verrät die SavedVariables-Namen nicht).
    view.addBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    view.addBox:SetSize(180, ROW_HEIGHT)
    view.addBox:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 8)
    view.addBox:SetAutoFocus(false)
    Desaturate(view.addBox)
    BugLab:HookReloadKey(view.addBox)
    view.addHint = view.addBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.addHint:SetPoint("LEFT", 6, 0)
    view.addHint:SetText(L["DB_ADD_HINT"])
    view.addBox:SetScript("OnTextChanged", function(edit) view.addHint:SetShown(edit:GetText() == "") end)
    view.addBox:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    view.addBox:SetScript("OnEnterPressed", function() self:OnAddClicked() end)
    view.add = Button(page, L["DB_ADD"], 110, function() self:OnAddClicked() end)
    view.add:SetPoint("LEFT", view.addBox, "RIGHT", 8, 0)
    view.remove = Button(page, L["DB_REMOVE"], 110, function() self:OnRemoveClicked() end)
    view.remove:SetPoint("LEFT", view.add, "RIGHT", 6, 0)

    view.empty = scroll:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.empty:SetPoint("TOPLEFT", 8, -8)

    page:SetScript("OnShow", function() self:OnShow() end)
end

-- Wählt ein vorhandenes Addon (das gewählte bleibt, sonst das erste).
function Database:OnShow()
    self.varCache = {}
    local list = self:GetAddons()
    local current = self.state.addon
    local found = false
    for _, name in ipairs(self:GetLoadedAddons(false)) do if name == current then found = true end end
    if not found then current = list[1] end
    self.state.addon = found and current or nil
    self:SelectAddon(current)
end

function Database:OnEnable()
    if not self.view then self:BuildPage() end
end
