-- Textur-Editor (Unterpunkt des Inspectors): zeigt eine Textur oder einen Atlas groß, lässt per Maus oder Eingabe einen
-- Ausschnitt wählen und eine Maske, Zoom und Versatz einstellen, und gibt am Ende den Lua-Code für genau diesen Ausschnitt aus.
local BugLab = _G.BugLab
local L = BugLab.L
local Inspector = BugLab:GetModule("Inspector")

local ROW_HEIGHT, Desaturate, Button = BugLab.ROW_HEIGHT, BugLab.Desaturate, BugLab.CreateButton
local BLUE = { 0.4, 0.73, 1, 1 }
local PREVIEW_W, PREVIEW_H = 380, 210 -- Fläche der Quellansicht
local RESULT_BOX = 150 -- Kantenlänge der Fläche der Ergebnisansicht
local CORNER = 9 -- Greifbereich der Ecken in Pixeln
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DEFAULT_SIZE = 256
local CONTENT_H = 540

local MASKS = { "none", "circle", "custom" }
local MASK_LABEL = { none = "TEX_MASK_NONE", circle = "TEX_MASK_CIRCLE", custom = "TEX_MASK_CUSTOM" }

-- Zustand -------------------------------------------------------------------------------------------------------------

local function NewState()
    return {
        file = nil, atlas = nil,                   -- Quelle
        bl = 0, br = 1, bt = 0, bb = 1,            -- Bereich der Quelle in der Datei (bei Atlanten der Atlas, sonst alles)
        srcW = DEFAULT_SIZE, srcH = DEFAULT_SIZE,  -- Größe dieses Bereichs in Pixeln
        cl = 0, cr = 1, ct = 0, cb = 1,            -- gewählter Ausschnitt, 0 bis 1 im Quellbereich
        outW = DEFAULT_SIZE, outH = DEFAULT_SIZE, autoSize = true,
        zoom = 100, offX = 0, offY = 0,
        mask = "none", maskPath = "", maskW = DEFAULT_SIZE, maskH = DEFAULT_SIZE, maskX = 0, maskY = 0,
    }
end

local function Round(value, digits)
    local factor = 10 ^ (digits or 0)
    return math.floor(value * factor + 0.5) / factor
end

local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end

local function Fmt(value)
    if type(value) ~= "number" then return "" end
    local text = string.format("%.4f", value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

-- Löst Datei und Bereich einer Quelle auf: Atlanten über ihre Daten, Dateien als Ganzes.
local function Resolve(ed, source)
    ed.atlas, ed.file = source.atlas, source.file
    ed.bl, ed.br, ed.bt, ed.bb = 0, 1, 0, 1
    ed.srcW, ed.srcH = DEFAULT_SIZE, DEFAULT_SIZE
    ed.sizeKnown = false
    if source.atlas and C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, source.atlas)
        if ok and type(info) == "table" and info.file then
            ed.file = info.file
            ed.bl, ed.br = info.leftTexCoord or 0, info.rightTexCoord or 1
            ed.bt, ed.bb = info.topTexCoord or 0, info.bottomTexCoord or 1
            ed.srcW, ed.srcH = info.width or DEFAULT_SIZE, info.height or DEFAULT_SIZE
            ed.sizeKnown = true
        end
    end
end

-- Texturkoordinaten des Ausschnitts in der Datei.
local function FinalCoords(ed)
    local width, height = ed.br - ed.bl, ed.bb - ed.bt
    return ed.bl + ed.cl * width, ed.bl + ed.cr * width, ed.bt + ed.ct * height, ed.bt + ed.cb * height
end

local function CropPixels(ed)
    return (ed.cr - ed.cl) * ed.srcW, (ed.cb - ed.ct) * ed.srcH
end

local function SourceLabel(ed)
    if ed.atlas then return ed.atlas end
    return ed.file and tostring(ed.file) or "-"
end

local function Quote(value) return string.format("%q", tostring(value)) end

-- Lua-Code für den gewählten Ausschnitt samt Maske, Zoom und Versatz.
local function BuildCode(ed)
    if not ed.file then return "-- " .. L["TEX_NO_SOURCE"] end
    local out = {}
    local function add(text) out[#out + 1] = text end
    local fl, fr, ft, fb = FinalCoords(ed)
    local framed = ed.zoom ~= 100 or ed.offX ~= 0 or ed.offY ~= 0
    add("-- " .. L["TEX_CODE_HEADER"]:format(SourceLabel(ed)))
    add('local frame = CreateFrame("Frame", nil, UIParent)')
    add(string.format("frame:SetSize(%s, %s)", Fmt(ed.outW), Fmt(ed.outH)))
    if framed or ed.mask ~= "none" then add("frame:SetClipsChildren(true)") end
    add('local tex = frame:CreateTexture(nil, "ARTWORK")')
    add(string.format("tex:SetTexture(%s)", type(ed.file) == "number" and Fmt(ed.file) or Quote(ed.file)))
    add(string.format("tex:SetTexCoord(%s, %s, %s, %s)", Fmt(fl), Fmt(fr), Fmt(ft), Fmt(fb)))
    if framed then
        add(string.format("tex:SetSize(%s, %s)", Fmt(ed.outW * ed.zoom / 100), Fmt(ed.outH * ed.zoom / 100)))
        add(string.format('tex:SetPoint("CENTER", frame, "CENTER", %s, %s)', Fmt(ed.offX), Fmt(ed.offY)))
    else
        add("tex:SetAllPoints()")
    end
    if ed.mask ~= "none" then
        local path = ed.mask == "circle" and CIRCLE_MASK or ed.maskPath
        add("local mask = frame:CreateMaskTexture()")
        add(string.format('mask:SetTexture(%s, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")', Quote(path)))
        add(string.format("mask:SetSize(%s, %s)", Fmt(ed.maskW), Fmt(ed.maskH)))
        add(string.format('mask:SetPoint("CENTER", frame, "CENTER", %s, %s)', Fmt(ed.maskX), Fmt(ed.maskY)))
        add("tex:AddMaskTexture(mask)")
    end
    return table.concat(out, "\n")
end

-- Bausteine ------------------------------------------------------------------------------------------------------------

-- Beschriftetes Zahlen- oder Textfeld: Enter übernimmt, Mausrad und Pfeiltasten ändern in Schritten (Umschalt = zehnfach).
local function CreateField(parent, labelText, x, y, width, step, get, set)
    local field = {}
    field.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    field.label:SetPoint("TOPLEFT", x + 6, y)
    field.label:SetText(BugLab:Paint("LIGHTGRAY", labelText))
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, ROW_HEIGHT)
    box:SetPoint("TOPLEFT", x + 6, y - 13)
    box:SetAutoFocus(false)
    Desaturate(box)
    BugLab:HookReloadKey(box)
    field.box = box
    local function Commit(text) set(step and tonumber(text) or text) end
    local function Step(direction)
        if not step then return end
        local amount = step * (IsShiftKeyDown() and 10 or 1)
        set(Round((tonumber(box:GetText()) or 0) + direction * amount, 4))
    end
    box:SetScript("OnEnterPressed", function(input) input:ClearFocus(); Commit(input:GetText()) end)
    box:SetScript("OnEscapePressed", function(input) input:ClearFocus(); field.Refresh() end)
    box:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then Step(1) elseif key == "DOWN" then Step(-1) end
    end)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta) Step(delta) end)
    function field.Refresh()
        if not box:HasFocus() then
            local value = get()
            box:SetText(type(value) == "number" and Fmt(value) or tostring(value or ""))
            box:SetCursorPosition(0)
        end
    end
    -- Tooltip über Feld und Beschriftung.
    function field.SetTooltip(title, text)
        local function show(anchor)
            GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
        box:HookScript("OnEnter", function() show(box) end)
        box:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    function field.SetShown(shown)
        field.label:SetShown(shown)
        box:SetShown(shown)
    end
    return field
end

-- Auswahl aus einer festen Liste (Auswahlfeld des Spiels, sonst ein Knopf, der reihum weiterschaltet).
local function CreateChoice(parent, options, labels, width, get, set)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(width, ROW_HEIGHT)
        Desaturate(dropdown)
        if dropdown.Arrow then dropdown.Arrow:SetDesaturated(true); dropdown.Arrow:SetVertexColor(0.6, 0.82, 1) end
        dropdown:SetupMenu(function(_, root)
            for _, option in ipairs(options) do
                root:CreateRadio(L[labels[option]], function() return get() == option end, function() set(option) end)
            end
        end)
        dropdown.Refresh = function() if dropdown.GenerateMenu then dropdown:GenerateMenu() end end
        return dropdown
    end
    local button
    button = Button(parent, "", width, function()
        local index = 0
        for i, option in ipairs(options) do if option == get() then index = i end end
        set(options[index % #options + 1])
    end)
    button.Refresh = function() button:SetText(L[labels[get()]]) end
    return button
end

-- Aufbau -----------------------------------------------------------------------------------------------------------------

local function Plain(parent, layer, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetColorTexture(r, g, b, a)
    return tex
end

function Inspector:BuildTextureEditor(root)
    local ed = NewState()
    -- Der Editor ist höher als die Seite, deshalb liegt er in einem Rollbereich.
    local outer = CreateFrame("Frame", nil, root)
    local area = CreateFrame("ScrollFrame", nil, outer, "UIPanelScrollFrameTemplate")
    area:SetPoint("TOPLEFT", 0, 0)
    area:SetPoint("BOTTOMRIGHT", -26, 4)
    local editor = CreateFrame("Frame", nil, area)
    editor:SetSize(800, CONTENT_H)
    area:SetScrollChild(editor)
    area:SetScript("OnSizeChanged", function(_, width) editor:SetWidth(math.max(width, 800)) end)
    local view = { frame = outer, fields = {} }
    self.editorView, self.ed = view, ed

    -- Quellansicht links: Textur eingepasst, außerhalb des Ausschnitts abgedunkelt, Ecken zum Ziehen.
    local srcFrame = CreateFrame("Frame", nil, editor)
    srcFrame:SetSize(PREVIEW_W, PREVIEW_H)
    srcFrame:SetPoint("TOPLEFT", 8, -8)
    Plain(srcFrame, "BACKGROUND", 0.07, 0.07, 0.07, 1):SetAllPoints()
    local tex = srcFrame:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")
    view.srcFrame, view.srcTex = srcFrame, tex
    view.dim = {}
    for i = 1, 4 do view.dim[i] = Plain(srcFrame, "OVERLAY", 0, 0, 0, 0.6) end
    view.edges = {}
    for i = 1, 4 do view.edges[i] = Plain(srcFrame, "OVERLAY", BLUE[1], BLUE[2], BLUE[3], 1) end
    view.handles = {}
    for i = 1, 4 do
        view.handles[i] = Plain(srcFrame, "OVERLAY", 1, 1, 1, 1)
        view.handles[i]:SetSize(7, 7)
    end
    view.srcInfo = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.srcInfo:SetPoint("TOPLEFT", srcFrame, "BOTTOMLEFT", 0, -4)
    view.srcInfo:SetWidth(PREVIEW_W)
    view.srcInfo:SetJustifyH("LEFT")

    -- Felder des Ausschnitts (0 bis 1) und Größe des Quellbilds.
    local function Add(field) view.fields[#view.fields + 1] = field; return field end
    local function Crop(key, other, isLow)
        return function(value)
            if not value then return end
            value = Clamp(value, 0, 1)
            if isLow then value = math.min(value, ed[other]) else value = math.max(value, ed[other]) end
            ed[key] = value
            self:EditorChanged()
        end
    end
    local fy = -PREVIEW_H - 52
    Add(CreateField(editor, L["TEX_LEFT"], 2, fy, 78, 0.01, function() return ed.cl end, Crop("cl", "cr", true)))
    Add(CreateField(editor, L["TEX_RIGHT"], 96, fy, 78, 0.01, function() return ed.cr end, Crop("cr", "cl", false)))
    Add(CreateField(editor, L["TEX_TOP"], 190, fy, 78, 0.01, function() return ed.ct end, Crop("ct", "cb", true)))
    Add(CreateField(editor, L["TEX_BOTTOM"], 284, fy, 78, 0.01, function() return ed.cb end, Crop("cb", "ct", false)))
    local function Size(key)
        return function(value)
            if value and value >= 1 and not ed.sizeKnown then ed[key] = value; self:EditorChanged() end
        end
    end
    view.srcW = Add(CreateField(editor, L["TEX_SRC_W"], 2, fy - 42, 78, 1, function() return ed.srcW end, Size("srcW")))
    view.srcH = Add(CreateField(editor, L["TEX_SRC_H"], 96, fy - 42, 78, 1, function() return ed.srcH end, Size("srcH")))
    view.reset = Button(editor, L["INS_RESET"], 110, function() self:EditorReset() end)
    view.reset:SetPoint("TOPLEFT", 284 + 6, fy - 42 - 13)

    -- Ergebnis rechts: Vorschau mit Maske, darunter Größe, Versatz, Zoom und Maske.
    local rx = PREVIEW_W + 40
    local resFrame = CreateFrame("Frame", nil, editor)
    resFrame:SetSize(RESULT_BOX, RESULT_BOX)
    resFrame:SetPoint("TOPLEFT", rx, -8)
    Plain(resFrame, "BACKGROUND", 0.07, 0.07, 0.07, 1):SetAllPoints()
    local box = CreateFrame("Frame", nil, resFrame)
    box:SetPoint("CENTER")
    if box.SetClipsChildren then box:SetClipsChildren(true) end
    local rtex = box:CreateTexture(nil, "ARTWORK")
    rtex:SetPoint("CENTER")
    local mask = box:CreateMaskTexture()
    view.resFrame, view.resBox, view.resTex, view.mask = resFrame, box, rtex, mask
    view.resInfo = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.resInfo:SetPoint("TOPLEFT", resFrame, "BOTTOMLEFT", 0, -4)
    view.resInfo:SetWidth(RESULT_BOX + 40)
    view.resInfo:SetJustifyH("LEFT")

    local gx = rx + RESULT_BOX + 14
    local function Out(key) return function(value) if value and value >= 1 then ed[key] = value; ed.autoSize = false; self:EditorChanged() end end end
    local function Num(key) return function(value) if value then ed[key] = value; self:EditorChanged() end end end
    view.outW = Add(CreateField(editor, L["TEX_OUT_W"], gx, -8, 78, 1, function() return ed.outW end, Out("outW")))
    view.outH = Add(CreateField(editor, L["TEX_OUT_H"], gx + 92, -8, 78, 1, function() return ed.outH end, Out("outH")))
    Add(CreateField(editor, L["TEX_OFF_X"], gx, -50, 78, 1, function() return ed.offX end, Num("offX")))
    Add(CreateField(editor, L["TEX_OFF_Y"], gx + 92, -50, 78, 1, function() return ed.offY end, Num("offY")))
    Add(CreateField(editor, L["TEX_ZOOM"], gx, -92, 78, 5, function() return ed.zoom end,
        function(value) if value and value > 0 then ed.zoom = value; self:EditorChanged() end end))

    local my = -RESULT_BOX - 36
    view.maskLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.maskLabel:SetPoint("TOPLEFT", rx + 6, my)
    view.maskLabel:SetText(BugLab:Paint("LIGHTGRAY", L["TEX_MASK"]))
    view.maskChoice = CreateChoice(editor, MASKS, MASK_LABEL, 150, function() return ed.mask end,
        function(option) ed.mask = option; self:EditorChanged() end)
    view.maskChoice:SetPoint("TOPLEFT", rx + 2, my - 13)
    view.maskPath = Add(CreateField(editor, L["TEX_MASK_PATH"], rx + 160, my, 190, nil, function() return ed.maskPath end,
        function(value) ed.maskPath = tostring(value or ""); self:EditorChanged() end))
    view.maskPath.SetTooltip(L["TEX_MASK_PATH"], L["TEX_MASK_PATH_TIP"])
    view.maskW = Add(CreateField(editor, L["TEX_MASK_W"], rx, my - 42, 66, 1, function() return ed.maskW end, Num("maskW")))
    view.maskH = Add(CreateField(editor, L["TEX_MASK_H"], rx + 78, my - 42, 66, 1, function() return ed.maskH end, Num("maskH")))
    view.maskX = Add(CreateField(editor, L["TEX_MASK_X"], rx + 156, my - 42, 66, 1, function() return ed.maskX end, Num("maskX")))
    view.maskY = Add(CreateField(editor, L["TEX_MASK_Y"], rx + 234, my - 42, 66, 1, function() return ed.maskY end, Num("maskY")))

    -- Lua-Code unten, zum Markieren und Kopieren.
    local scroll, SetCode = BugLab.CreateTextArea(editor)
    scroll:SetPoint("TOPLEFT", 8, -(PREVIEW_H + 52 + 84 + 36))
    scroll:SetPoint("TOPRIGHT", -28, -(PREVIEW_H + 52 + 84 + 36))
    scroll:SetHeight(120)
    view.SetCode = SetCode
    view.codeLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.codeLabel:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", 2, 3)
    view.codeLabel:SetText(BugLab:Paint("LIGHTGRAY", L["TEX_CODE"]))

    self:EnableCropDragging()
    outer:Hide()
    self:EditorChanged()
    return outer
end

-- Ziehen in der Quellansicht: Ecke greifen = Größe ändern, im Rechteck = verschieben, sonst neuen Ausschnitt aufziehen.
function Inspector:EnableCropDragging()
    local view, ed = self.editorView, self.ed
    local frame = view.srcFrame
    frame:EnableMouse(true)

    local function Normalized()
        local scale = frame:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local tex = view.srcTex
        local width, height = tex:GetWidth(), tex:GetHeight()
        if not (width and height and width > 0 and height > 0) then return nil end
        local left, top = tex:GetLeft(), tex:GetTop()
        if not (left and top) then return nil end
        return Clamp((cx / scale - left) / width, 0, 1), Clamp((top - cy / scale) / height, 0, 1), width, height
    end

    frame:SetScript("OnMouseDown", function()
        local nx, ny, width, height = Normalized()
        if not nx then return end
        local tx, ty = CORNER / width, CORNER / height
        local drag = {}
        local function near(x, y) return math.abs(nx - x) <= tx and math.abs(ny - y) <= ty end
        if near(ed.cl, ed.ct) then drag.ax, drag.ay = ed.cr, ed.cb
        elseif near(ed.cr, ed.ct) then drag.ax, drag.ay = ed.cl, ed.cb
        elseif near(ed.cl, ed.cb) then drag.ax, drag.ay = ed.cr, ed.ct
        elseif near(ed.cr, ed.cb) then drag.ax, drag.ay = ed.cl, ed.ct
        elseif nx > ed.cl and nx < ed.cr and ny > ed.ct and ny < ed.cb then
            drag.move, drag.dx, drag.dy, drag.w, drag.h = true, nx - ed.cl, ny - ed.ct, ed.cr - ed.cl, ed.cb - ed.ct
        else
            drag.ax, drag.ay = nx, ny
        end
        view.drag = drag
    end)
    frame:SetScript("OnMouseUp", function() view.drag = nil end)
    frame:SetScript("OnHide", function() view.drag = nil end)
    frame:SetScript("OnUpdate", function()
        local drag = view.drag
        if not drag then return end
        local nx, ny = Normalized()
        if not nx then return end
        if drag.move then
            ed.cl = Clamp(nx - drag.dx, 0, 1 - drag.w)
            ed.ct = Clamp(ny - drag.dy, 0, 1 - drag.h)
            ed.cr, ed.cb = ed.cl + drag.w, ed.ct + drag.h
        else
            ed.cl, ed.cr = math.min(drag.ax, nx), math.max(drag.ax, nx)
            ed.ct, ed.cb = math.min(drag.ay, ny), math.max(drag.ay, ny)
        end
        self:EditorChanged()
    end)
end

-- Anzeige ------------------------------------------------------------------------------------------------------------

-- Zeichnet Quellansicht, Ausschnitt, Ergebnis und Code neu.
function Inspector:EditorChanged()
    local view, ed = self.editorView, self.ed
    if not view then return end
    local cropW, cropH = CropPixels(ed)
    if ed.autoSize then ed.outW, ed.outH = math.max(1, Round(cropW)), math.max(1, Round(cropH)) end

    -- Quellansicht: Textur im Seitenverhältnis des Quellbereichs einpassen.
    local tex = view.srcTex
    if ed.file then
        tex:SetTexture(ed.file)
        tex:SetTexCoord(ed.bl, ed.br, ed.bt, ed.bb)
    else
        tex:SetColorTexture(0.12, 0.12, 0.12, 1)
    end
    local fit = math.min(PREVIEW_W / math.max(ed.srcW, 1), PREVIEW_H / math.max(ed.srcH, 1))
    local pw, ph = math.max(ed.srcW * fit, 1), math.max(ed.srcH * fit, 1)
    tex:SetSize(pw, ph)
    local x1, x2, y1, y2 = ed.cl * pw, ed.cr * pw, ed.ct * ph, ed.cb * ph
    local dim = view.dim
    dim[1]:ClearAllPoints(); dim[1]:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, 0); dim[1]:SetPoint("BOTTOMRIGHT", tex, "TOPRIGHT", 0, -y1)
    dim[2]:ClearAllPoints(); dim[2]:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, -y2); dim[2]:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, 0)
    dim[3]:ClearAllPoints(); dim[3]:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, -y1); dim[3]:SetPoint("BOTTOMRIGHT", tex, "TOPLEFT", x1, -y2)
    dim[4]:ClearAllPoints(); dim[4]:SetPoint("TOPLEFT", tex, "TOPLEFT", x2, -y1); dim[4]:SetPoint("BOTTOMRIGHT", tex, "TOPRIGHT", 0, -y2)
    local e = view.edges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", tex, "TOPLEFT", x1, -y1); e[1]:SetSize(math.max(x2 - x1, 1), 1)
    e[2]:ClearAllPoints(); e[2]:SetPoint("TOPLEFT", tex, "TOPLEFT", x1, -y2); e[2]:SetSize(math.max(x2 - x1, 1), 1)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", tex, "TOPLEFT", x1, -y1); e[3]:SetSize(1, math.max(y2 - y1, 1))
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPLEFT", tex, "TOPLEFT", x2, -y1); e[4]:SetSize(1, math.max(y2 - y1, 1))
    local corners = { { x1, y1 }, { x2, y1 }, { x1, y2 }, { x2, y2 } }
    for i, corner in ipairs(corners) do
        view.handles[i]:ClearAllPoints()
        view.handles[i]:SetPoint("CENTER", tex, "TOPLEFT", corner[1], -corner[2])
    end
    view.srcInfo:SetText(BugLab:Paint("GRAY", L["TEX_SOURCE"] .. ": ") .. BugLab:Paint("BRIGHTBLUE", SourceLabel(ed))
        .. BugLab:Paint("GRAY", string.format("   %s %d x %d px   %s %d, %d, %d x %d px", L["TEX_SIZE"], Round(ed.srcW), Round(ed.srcH),
            L["TEX_CROP"], Round(ed.cl * ed.srcW), Round(ed.ct * ed.srcH), Round(cropW), Round(cropH))))

    -- Ergebnis: Ausschnitt in Ausgabegröße, mit Zoom, Versatz und Maske, auf die Vorschaufläche verkleinert.
    local scale = math.min(RESULT_BOX / math.max(ed.outW, 1), RESULT_BOX / math.max(ed.outH, 1), 4)
    view.resBox:SetSize(math.max(ed.outW * scale, 1), math.max(ed.outH * scale, 1))
    local rtex = view.resTex
    if ed.file then
        local fl, fr, ft, fb = FinalCoords(ed)
        rtex:SetTexture(ed.file)
        rtex:SetTexCoord(fl, fr, ft, fb)
    else
        rtex:SetColorTexture(0.12, 0.12, 0.12, 1)
    end
    rtex:SetSize(math.max(ed.outW * ed.zoom / 100 * scale, 1), math.max(ed.outH * ed.zoom / 100 * scale, 1))
    rtex:ClearAllPoints()
    rtex:SetPoint("CENTER", view.resBox, "CENTER", ed.offX * scale, ed.offY * scale)
    local mask = view.mask
    if rtex.RemoveMaskTexture then pcall(rtex.RemoveMaskTexture, rtex, mask) end
    mask:Hide()
    if ed.mask ~= "none" then
        local path = ed.mask == "circle" and CIRCLE_MASK or ed.maskPath
        if path and path ~= "" then
            mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:ClearAllPoints()
            mask:SetSize(math.max(ed.maskW * scale, 1), math.max(ed.maskH * scale, 1))
            mask:SetPoint("CENTER", view.resBox, "CENTER", ed.maskX * scale, ed.maskY * scale)
            mask:Show()
            rtex:AddMaskTexture(mask)
        end
    end
    view.resInfo:SetText(BugLab:Paint("GRAY", L["TEX_RESULT"] .. ": ") .. BugLab:Paint("BRIGHTBLUE", string.format("%d x %d px", Round(ed.outW), Round(ed.outH))))

    local custom = ed.mask == "custom"
    view.maskPath.SetShown(custom)
    for _, key in ipairs({ "maskW", "maskH", "maskX", "maskY" }) do view[key].SetShown(ed.mask ~= "none") end
    if view.maskChoice.Refresh then view.maskChoice.Refresh() end
    for _, field in ipairs(view.fields) do field.Refresh() end
    view.srcW.box:SetEnabled(not ed.sizeKnown)
    view.srcH.box:SetEnabled(not ed.sizeKnown)
    view.codeText = BuildCode(ed)
    view.SetCode(view.codeText)
end

function Inspector:EditorReset()
    local ed = self.ed
    local source = { atlas = ed.atlas, file = ed.atlas and nil or ed.file }
    local fresh = NewState()
    for key, value in pairs(fresh) do ed[key] = value end
    Resolve(ed, source)
    self:EditorChanged()
end

-- Öffnet den Editor mit einer Quelle {atlas = "Name"} oder {file = ID oder Pfad}; "crop" ({l, r, t, b}, 0 bis 1) setzt
-- den Ausschnitt (z. B. aus den Texturkoordinaten einer untersuchten Textur).
function Inspector:LoadTexture(source, crop)
    if not self.editorView then return end
    local ed = self.ed
    local fresh = NewState()
    for key, value in pairs(fresh) do ed[key] = value end
    Resolve(ed, source)
    if crop then
        ed.cl, ed.cr = Clamp(crop[1], 0, 1), Clamp(crop[2], 0, 1)
        ed.ct, ed.cb = Clamp(crop[3], 0, 1), Clamp(crop[4], 0, 1)
    end
    self:EditorChanged()
end

function Inspector:OpenTextureEditor(source, crop)
    BugLab:ShowWindow()
    BugLab:SelectTab("Inspector")
    self:SelectSubTab("editor")
    self:LoadTexture(source, crop)
end

-- Quelle und Ausschnitt einer untersuchten Textur (Atlas oder Datei) für den Editor.
function Inspector:TextureSource(obj)
    if not (obj and obj.GetObjectType and obj:GetObjectType() == "Texture") then return nil end
    local atlas, file = obj:GetAtlas(), obj:GetTexture()
    if atlas then return { atlas = atlas } end
    if type(file) ~= "number" and type(file) ~= "string" then return nil end
    local coords = { obj:GetTexCoord() }
    local crop
    if #coords == 8 then crop = { coords[1], coords[5], coords[2], coords[4] }
    elseif #coords == 4 then crop = { coords[1], coords[2], coords[3], coords[4] } end
    return { file = file }, crop
end
