-- Gallery: Texturen und Atlanten als Vorschaubilder durchblättern. Quellen sind die Atlasliste des Clients (falls vorhanden)
-- und die Texturen, die geladene Frames gerade verwenden. Eine Auswahl zeigt Name, Größe und einen Code-Schnipsel zum
-- Kopieren und lässt sich im Textur-Editor des Inspectors öffnen.
local BugLab = _G.BugLab
local L = BugLab.L
local Gallery = BugLab:NewModule("Gallery", "AceEvent-3.0")

local ROW_HEIGHT, Desaturate, Button = BugLab.ROW_HEIGHT, BugLab.Desaturate, BugLab.CreateButton
local GAP, LABEL_HEIGHT = 8, 14
local SIZE_MIN, SIZE_MAX, SIZE_STEP = 24, 128, 8
local DETAIL_HEIGHT = 62
local CELL_COLOR, CELL_SELECTED = { 0.1, 0.1, 0.1, 0.95 }, { 0.2, 0.45, 0.65, 0.95 }

local SOURCES = { "atlas", "ui" }
local SOURCE_LABEL = { atlas = "GAL_SOURCE_ATLAS", ui = "GAL_SOURCE_UI" }

Gallery.state = { source = "atlas", search = "", size = 56 }

-- Daten ----------------------------------------------------------------------------------------------------------------

local function SortItems(items)
    for _, item in ipairs(items) do item.lower = tostring(item.label):lower() end
    table.sort(items, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.lower < b.lower
    end)
    return items
end

-- Atlasliste des Clients (nil, wenn er keine liefert).
local function ClientAtlases()
    if not (C_Texture and C_Texture.GetAtlasElements) then return nil end
    local ok, names = pcall(C_Texture.GetAtlasElements)
    if not (ok and type(names) == "table") then return nil end
    local items = {}
    for i = 1, #names do items[i] = { kind = "atlas", id = names[i], label = names[i] } end
    return SortItems(items)
end

-- Alle Atlanten und Dateien, die Texturen geladener Frames gerade verwenden.
local function ScanUI()
    local seen, items = {}, {}
    local function add(kind, id)
        local key = kind .. ":" .. tostring(id)
        if not seen[key] then
            seen[key] = true
            items[#items + 1] = { kind = kind, id = id, label = tostring(id) }
        end
    end
    local frame = EnumerateFrames and EnumerateFrames()
    while frame do
        pcall(function()
            for _, region in ipairs({ frame:GetRegions() }) do
                if region:GetObjectType() == "Texture" then
                    local atlas = region:GetAtlas()
                    if atlas then
                        add("atlas", atlas)
                    else
                        local file = region:GetTexture()
                        if type(file) == "number" or type(file) == "string" then add("file", file) end
                    end
                end
            end
        end)
        frame = EnumerateFrames(frame)
    end
    return SortItems(items)
end

-- Lädt die Einträge der gewählten Quelle (Atlanten werden nur einmal gelesen) und wendet die Suche an.
function Gallery:LoadSource(force)
    local state = self.state
    self.note = nil
    if state.source == "atlas" then
        if force or not self.atlasItems then self.atlasItems = ClientAtlases() or false end
        if self.atlasItems then
            self.items = self.atlasItems
        else
            self.note = L["GAL_NO_ATLAS_API"]
            self.items = ScanUI()
        end
    else
        self.items = ScanUI()
    end
    self:ApplyFilter()
end

function Gallery:ApplyFilter()
    local needle = (self.state.search or ""):lower()
    local filtered = {}
    for _, item in ipairs(self.items or {}) do
        if needle == "" or item.lower:find(needle, 1, true) then filtered[#filtered + 1] = item end
    end
    self.filtered = filtered
    if self.view then
        self.view.grid:SetVerticalScroll(0)
        self:UpdateGrid()
    end
end

-- Größe und Quelle eines Eintrags für die Anzeige: Breite, Höhe, Datei (nur bei Atlanten bekannt).
function Gallery:ItemInfo(item)
    if item.kind == "atlas" and C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, item.id)
        if ok and type(info) == "table" then return info end
    end
end

local function Snippet(item)
    if item.kind == "atlas" then return string.format("tex:SetAtlas(%q)", tostring(item.id)) end
    return type(item.id) == "number" and string.format("tex:SetTexture(%d)", item.id) or string.format("tex:SetTexture(%q)", tostring(item.id))
end

-- Raster ---------------------------------------------------------------------------------------------------------------

local function SameItem(a, b)
    return a and b and a.kind == b.kind and a.id == b.id
end

-- Zeichnet das Vorschaubild eines Eintrags eingepasst in ein Quadrat der Kantenlänge size.
function Gallery:ShowThumb(texture, item, size)
    texture:SetTexCoord(0, 1, 0, 1)
    local width, height = size, size
    if item.kind == "atlas" then
        texture:SetAtlas(item.id)
        local info = self:ItemInfo(item)
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            local scale = math.min(size / info.width, size / info.height)
            width, height = info.width * scale, info.height * scale
        end
    else
        texture:SetTexture(item.id)
    end
    texture:SetSize(width, height)
end

function Gallery:CreateCell()
    local view = self.view
    local cell = CreateFrame("Button", nil, view.content)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetPoint("TOPLEFT")
    cell.thumb = cell:CreateTexture(nil, "ARTWORK")
    cell.thumb:SetPoint("CENTER", cell.bg, "CENTER")
    cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.label:SetJustifyH("CENTER")
    cell.label:SetWordWrap(false)
    cell:SetScript("OnClick", function(button) Gallery:Select(button.item) end)
    cell:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(button.item.label), 1, 1, 1, 1, true)
        GameTooltip:AddLine(button.item.kind == "atlas" and L["GAL_KIND_ATLAS"] or L["GAL_KIND_FILE"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return cell
end

function Gallery:SetupCell(cell, item, x, y)
    local size = self.state.size
    cell.item = item
    cell:SetSize(size, size + LABEL_HEIGHT)
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", self.view.content, "TOPLEFT", x + GAP / 2, -y - GAP / 2)
    cell.bg:SetSize(size, size)
    local color = SameItem(item, self.selected) and CELL_SELECTED or CELL_COLOR
    cell.bg:SetColorTexture(color[1], color[2], color[3], color[4])
    self:ShowThumb(cell.thumb, item, size)
    cell.label:ClearAllPoints()
    cell.label:SetPoint("TOP", cell.bg, "BOTTOM", 0, -1)
    cell.label:SetWidth(size + GAP - 2)
    cell.label:SetText(BugLab:Paint("LIGHTGRAY", tostring(item.label)))
    cell:Show()
end

-- Nur die sichtbaren Zeilen werden gezeichnet; die Zellen werden wiederverwendet.
function Gallery:UpdateGrid()
    local view = self.view
    if not view then return end
    local items = self.filtered or {}
    local size = self.state.size
    local cellW, cellH = size + GAP, size + GAP + LABEL_HEIGHT
    local width = math.max(tonumber(view.content:GetWidth()) or 0, cellW)
    local cols = math.max(1, math.floor(width / cellW))
    local rows = math.ceil(#items / cols)
    view.content:SetHeight(math.max(rows * cellH, 1))
    local viewHeight = tonumber(view.grid:GetHeight()) or 300
    local offset = tonumber(view.grid:GetVerticalScroll()) or 0
    local firstRow = math.max(0, math.floor(offset / cellH))
    local lastRow = math.min(rows - 1, firstRow + math.ceil(viewHeight / cellH))
    local used = 0
    for row = firstRow, lastRow do
        for col = 0, cols - 1 do
            local index = row * cols + col + 1
            if index > #items then break end
            used = used + 1
            local cell = view.cells[used]
            if not cell then cell = self:CreateCell(); view.cells[used] = cell end
            self:SetupCell(cell, items[index], col * cellW, row * cellH)
        end
    end
    for i = used + 1, #view.cells do view.cells[i]:Hide() end
    view.count:SetText(BugLab:Paint("LIGHTGRAY", L["GAL_COUNT"]:format(#items)) .. (self.note and ("  " .. BugLab:Paint("ERROR", self.note)) or ""))
end

-- Auswahl ----------------------------------------------------------------------------------------------------------------

function Gallery:Select(item)
    self.selected = item
    local view = self.view
    if item then
        local info = self:ItemInfo(item)
        local parts = { BugLab:Paint("WHITE", tostring(item.label)) }
        if info and info.width then
            parts[#parts + 1] = BugLab:Paint("GRAY", info.width .. " x " .. info.height)
            if info.file then parts[#parts + 1] = BugLab:Paint("GRAY", L["GAL_FILE"] .. ": ") .. BugLab:Paint("BRIGHTBLUE", tostring(info.file)) end
        end
        view.selected:SetText(table.concat(parts, "  "))
        view.snippet.content = Snippet(item)
        view.snippet:SetText(view.snippet.content)
        view.snippet:SetCursorPosition(0)
        view.open:Enable()
    else
        view.selected:SetText(BugLab:Paint("GRAY", L["GAL_NONE_SELECTED"]))
        view.snippet.content = ""
        view.snippet:SetText("")
        view.open:Disable()
    end
    self:UpdateGrid()
end

function Gallery:OpenInEditor()
    local item = self.selected
    local inspector = BugLab:GetModule("Inspector", true)
    if item and inspector and inspector:IsEnabled() then
        inspector:OpenTextureEditor({ atlas = item.kind == "atlas" and item.id or nil, file = item.kind == "file" and item.id or nil })
    end
end

-- Seite --------------------------------------------------------------------------------------------------------------------

function Gallery:SetSize(size)
    self.state.size = math.max(SIZE_MIN, math.min(SIZE_MAX, size))
    self.view.sizeLabel:SetText(BugLab:Paint("LIGHTGRAY", L["GAL_SIZE"] .. ": ") .. BugLab:Paint("BRIGHTBLUE", self.state.size))
    self:UpdateGrid()
end

function Gallery:BuildSourceControl(page)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(190, ROW_HEIGHT)
        Desaturate(dropdown)
        if dropdown.Arrow then dropdown.Arrow:SetDesaturated(true); dropdown.Arrow:SetVertexColor(0.6, 0.82, 1) end
        dropdown:SetupMenu(function(_, root)
            for _, source in ipairs(SOURCES) do
                root:CreateRadio(L[SOURCE_LABEL[source]], function() return self.state.source == source end, function()
                    self.state.source = source
                    self:LoadSource(true)
                end)
            end
        end)
        return dropdown
    end
    -- Ohne Auswahlvorlage schaltet der Knopf reihum zur nächsten Quelle.
    local button
    button = Button(page, L[SOURCE_LABEL[self.state.source]], 190, function()
        self.state.source = self.state.source == "atlas" and "ui" or "atlas"
        button:SetText(L[SOURCE_LABEL[self.state.source]])
        self:LoadSource(true)
    end)
    return button
end

function Gallery:BuildPage()
    local page = BugLab:GetPage("Gallery")
    local view = { page = page, cells = {} }
    self.view, self.page = view, page

    -- Obere Leiste: Quelle, Suche, Aktualisieren, Größe.
    view.source = self:BuildSourceControl(page)
    view.source:SetPoint("TOPLEFT", 6, -6)
    view.search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    view.search:SetSize(200, ROW_HEIGHT)
    view.search:SetPoint("LEFT", view.source, "RIGHT", 14, 0)
    view.search:SetAutoFocus(false)
    Desaturate(view.search)
    BugLab:HookReloadKey(view.search)
    -- Das Wort "Suche" steht als Platzhalter im Feld, solange es leer ist.
    view.searchHint = view.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.searchHint:SetPoint("LEFT", 6, 0)
    view.searchHint:SetText(L["GAL_SEARCH"])
    local function UpdateHint(edit) view.searchHint:SetShown(edit:GetText() == "") end
    view.search:SetScript("OnTextChanged", function(edit, byUser)
        UpdateHint(edit)
        if not byUser then return end
        self.state.search = edit:GetText()
        self:ApplyFilter()
    end)
    view.search:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    view.refresh = Button(page, L["INS_REFRESH"], 110, function() self:LoadSource(true) end)
    view.refresh:SetPoint("LEFT", view.search, "RIGHT", 10, 0)
    view.bigger = Button(page, "+", 28, function() self:SetSize(self.state.size + SIZE_STEP) end)
    view.bigger:SetPoint("TOPRIGHT", -6, -6)
    view.sizeLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.sizeLabel:SetWidth(90)
    view.sizeLabel:SetPoint("RIGHT", view.bigger, "LEFT", -4, 0)
    view.smaller = Button(page, "-", 28, function() self:SetSize(self.state.size - SIZE_STEP) end)
    view.smaller:SetPoint("RIGHT", view.sizeLabel, "LEFT", -4, 0)

    -- Auswahl unten: Name und Größe, Code-Schnipsel zum Kopieren, Knopf zum Textur-Editor.
    local detail = CreateFrame("Frame", nil, page)
    detail:SetPoint("BOTTOMLEFT", 6, 6)
    detail:SetPoint("BOTTOMRIGHT", -6, 6)
    detail:SetHeight(DETAIL_HEIGHT)
    view.selected = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.selected:SetPoint("TOPLEFT", 2, -2)
    view.selected:SetPoint("RIGHT", detail, "RIGHT", -2, 0)
    view.selected:SetJustifyH("LEFT")
    view.selected:SetWordWrap(false)
    view.open = Button(detail, L["GAL_OPEN_EDITOR"], 190, function() self:OpenInEditor() end)
    view.open:SetPoint("BOTTOMRIGHT", 0, 0)
    view.snippet = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
    view.snippet:SetHeight(ROW_HEIGHT)
    view.snippet:SetPoint("BOTTOMLEFT", 6, 0)
    view.snippet:SetPoint("RIGHT", view.open, "LEFT", -10, 0)
    view.snippet:SetAutoFocus(false)
    Desaturate(view.snippet)
    BugLab:HookReloadKey(view.snippet)
    view.snippet.content = ""
    view.snippet:SetScript("OnTextChanged", function(edit, byUser)
        if byUser then edit:SetText(edit.content) end
    end)
    view.snippet:SetScript("OnEditFocusGained", function(edit) edit:HighlightText() end)
    view.snippet:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)

    view.count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.count:SetPoint("BOTTOMLEFT", detail, "TOPLEFT", 2, 2)

    -- Raster in der Mitte.
    local grid = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    grid:SetPoint("TOPLEFT", view.source, "BOTTOMLEFT", 0, -22)
    grid:SetPoint("BOTTOMRIGHT", detail, "TOPRIGHT", -20, 20)
    local content = CreateFrame("Frame", nil, grid)
    content:SetSize(10, 10)
    grid:SetScrollChild(content)
    grid:HookScript("OnVerticalScroll", function() self:UpdateGrid() end)
    grid:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
        self:UpdateGrid()
    end)
    view.grid, view.content = grid, content

    page:SetScript("OnShow", function()
        if not self.items then self:LoadSource() end
    end)
    self:SetSize(self.state.size)
    self:Select(nil)
end

function Gallery:OnEnable()
    if not self.view then self:BuildPage() end
end
