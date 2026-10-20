-- Probe: Oberfläche für Tests, die Addons über BugLab:RegisterProbe angemeldet haben. Pro Addon wählt man eine Probe,
-- stellt ihre Parameter ein und startet oder beendet sie. Ausgaben stehen im Probe-Log (Reiter Console, Umschalter unten).
local BugLab = _G.BugLab
local L = BugLab.L
local Probe = BugLab:NewModule("Probe", "AceEvent-3.0")

local ROW_HEIGHT, Desaturate, Button = BugLab.ROW_HEIGHT, BugLab.Desaturate, BugLab.CreateButton
local COLUMNS, COLUMN_WIDTH, PARAM_HEIGHT = 4, 190, 46

Probe.values = {} -- zuletzt eingestellte Werte je Probe ["Addon\0probe"][Parameter]

local function ValueKey(def) return def.addon .. "\0" .. def.key end

-- Wert eines Parameters: zuletzt eingestellt, sonst Standard, sonst bei Auswahl der erste Eintrag.
local function CurrentValue(def, param)
    local stored = Probe.values[ValueKey(def)]
    if stored and stored[param.key] ~= nil then return stored[param.key] end
    if param.default ~= nil then return param.default end
    if param.type == "choice" then return param.values and param.values[1] end
    if param.type == "bool" then return false end
    return nil
end

local function Store(def, param, value)
    local key = ValueKey(def)
    Probe.values[key] = Probe.values[key] or {}
    Probe.values[key][param.key] = value
end

-- Hexwert "rrggbb" (auch mit "#" oder "|cff" davor) in r, g, b (0 bis 1); ungültig = weiß.
local function HexToRGB(text)
    local hex = tostring(text or ""):match("(%x%x%x%x%x%x)%s*$")
    if not hex then return 1, 1, 1 end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function RGBToHex(r, g, b)
    return string.format("%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

-- Parameterfeld: Eingabe, Auswahl oder Haken, je nach Typ.
function Probe:CreateParam(parent, def, param, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x + 6, y)
    label:SetText(BugLab:Paint("LIGHTGRAY", param.label))
    if param.type == "bool" then
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x, y - 12)
        check:SetChecked(CurrentValue(def, param) and true or false)
        check:SetScript("OnClick", function(button) Store(def, param, button:GetChecked() and true or false) end)
        return
    end
    if param.type == "choice" then
        local button
        button = Button(parent, "", COLUMN_WIDTH - 20, function()
            local index = 0
            for i, value in ipairs(param.values or {}) do if value == CurrentValue(def, param) then index = i end end
            local nextValue = (param.values or {})[index % math.max(#(param.values or {}), 1) + 1]
            Store(def, param, nextValue)
            button:SetText(tostring(nextValue))
        end)
        button:SetText(tostring(CurrentValue(def, param) or ""))
        button:SetPoint("TOPLEFT", x + 4, y - 14)
        return
    end
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    local swatch
    if param.type == "color" then
        -- Farbwähler vor dem Feld: Klick öffnet den Farbwähler des Spiels, das Feld enthält den Hexwert (rrggbb).
        swatch = CreateFrame("Button", nil, parent)
        swatch:SetSize(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
        swatch:SetPoint("TOPLEFT", x + 6, y - 17)
        swatch.border = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.border:SetPoint("TOPLEFT", -1, 1)
        swatch.border:SetPoint("BOTTOMRIGHT", 1, -1)
        swatch.border:SetColorTexture(0.7, 0.7, 0.7, 1)
        swatch.color = swatch:CreateTexture(nil, "ARTWORK")
        swatch.color:SetAllPoints()
        swatch:SetScript("OnClick", function()
            local r, g, b = HexToRGB(box:GetText())
            local function Apply()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                box:SetText(RGBToHex(nr, ng, nb))
            end
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b, hasOpacity = false,
                swatchFunc = Apply,
                cancelFunc = function() box:SetText(RGBToHex(r, g, b)) end,
            })
        end)
    end
    box:SetSize(COLUMN_WIDTH - (swatch and 56 or 30), ROW_HEIGHT)
    box:SetPoint("TOPLEFT", x + (swatch and 34 or 10), y - 14)
    box:SetAutoFocus(false)
    Desaturate(box)
    BugLab:HookReloadKey(box)
    local value = CurrentValue(def, param)
    box:SetText(value ~= nil and tostring(value) or "")
    box:SetCursorPosition(0)
    if swatch then swatch.color:SetColorTexture(HexToRGB(box:GetText())) end
    box:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    box:SetScript("OnTextChanged", function(edit)
        local text = edit:GetText()
        if param.type == "number" then Store(def, param, tonumber((text:gsub(",", ".")))) else Store(def, param, text) end
        if swatch then swatch.color:SetColorTexture(HexToRGB(text)) end
    end)
end

-- Werte für den Start: Eingaben prüfen wie bei der Befehlszeile (fehlende Pflichtwerte, Zahlen).
local function CollectValues(def)
    local values = {}
    for _, param in ipairs(def.params) do
        local value = CurrentValue(def, param)
        if value == nil or value == "" then
            if not param.optional then return nil, L["PROBE_ERR_MISSING"]:format(param.key) end
        else
            values[param.key] = value
        end
    end
    return values
end

-- Ein Block je Probe: Titel, Beschreibung, Parameter, Start/Stop.
function Probe:BuildBlock(parent, def, top)
    local block = CreateFrame("Frame", nil, parent)
    block:SetPoint("TOPLEFT", 0, top)
    block:SetPoint("TOPRIGHT", 0, top)
    local bg = block:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.04)
    local title = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(BugLab:Paint("WHITE", def.title) .. BugLab:Paint("GRAY", "  " .. def.key))
    local height = 30
    if def.desc and def.desc ~= "" then
        local desc = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", 10, -26)
        desc:SetPoint("RIGHT", block, "RIGHT", -10, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(BugLab:Paint("LIGHTGRAY", def.desc))
        height = 46
    end
    for i, param in ipairs(def.params) do
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        self:CreateParam(block, def, param, 4 + column * COLUMN_WIDTH, -(height + row * PARAM_HEIGHT))
    end
    height = height + math.ceil(#def.params / COLUMNS) * PARAM_HEIGHT + 4
    local start = Button(block, L[def.once and "PROBE_BTN_RUN" or "PROBE_BTN_START"], 100, function()
        local values, err = CollectValues(def)
        if not values then BugLab:Print(BugLab:Paint("ERROR", err)); return end
        local ok, runErr = BugLab:StartProbe(def.addon, def.key, values)
        if not ok then BugLab:Print(BugLab:Paint("ERROR", tostring(runErr))) end
    end)
    start:SetPoint("TOPLEFT", 10, -height)
    local stop = Button(block, L["PROBE_BTN_STOP"], 100, function() BugLab:StopProbe(def.addon, def.key) end)
    stop:SetPoint("LEFT", start, "RIGHT", 6, 0)
    stop:SetShown(not def.once) -- Einmal-Probes haben nur "Ausführen"
    block.status = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.status:SetPoint("LEFT", def.once and start or stop, "RIGHT", 12, 0)
    block.start, block.stop, block.def = start, stop, def
    height = height + ROW_HEIGHT + 10
    block:SetHeight(height)
    return block, height
end

-- Grüner Haken neben "Ausführen", wenn eine Einmal-Probe fertig durchgelaufen ist; nach 10 Sekunden verschwindet er.
local DONE_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:18|t"
local DONE_SECONDS = 10
Probe.doneAt = {}

function Probe:IsRecentlyDone(def)
    local at = self.doneAt[ValueKey(def)]
    return at ~= nil and GetTime() - at < DONE_SECONDS
end

function Probe:OnProbeDone(_, addon, key)
    self.doneAt[addon .. "\0" .. key] = GetTime()
    self:UpdateRunning()
    C_Timer.After(DONE_SECONDS + 0.1, function() self:UpdateRunning() end)
end

function Probe:UpdateRunning()
    for _, block in ipairs(self.blocks or {}) do
        local running = BugLab:IsProbeRunning(block.def.addon, block.def.key)
        block.stop:SetEnabled(running)
        local done = block.def.once and self:IsRecentlyDone(block.def)
        block.status:SetText(done and DONE_ICON or (running and BugLab:Paint("BRIGHTBLUE", L["PROBE_RUNNING"]) or ""))
    end
end

function Probe:SelectAddon(addon)
    local view = self.view
    self.addon = addon
    if view.content then view.content:Hide(); view.content:SetParent(nil) end
    local content = CreateFrame("Frame", nil, view.scroll)
    content:SetSize(math.max(tonumber(view.scroll:GetWidth()) or 600, 600), 10)
    view.scroll:SetScrollChild(content)
    view.content = content
    self.blocks = {}
    local top = 0
    for _, def in ipairs(addon and BugLab:GetProbes(addon) or {}) do
        local block, height = self:BuildBlock(content, def, -top)
        self.blocks[#self.blocks + 1] = block
        top = top + height + 8
    end
    content:SetHeight(math.max(top, 10))
    view.addonText:SetText(addon and BugLab:Paint("BRIGHTBLUE", addon) or BugLab:Paint("GRAY", L["PROBE_NONE"]))
    if view.menu and view.menu.GenerateMenu then view.menu:GenerateMenu() end
    self:UpdateRunning()
end

function Probe:BuildPage()
    local page = BugLab:GetPage("Probe")
    local view = { page = page }
    self.view = view

    view.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.label:SetPoint("TOPLEFT", 12, -8)
    view.label:SetText(BugLab:Paint("LIGHTGRAY", L["PROBE_ADDON"]))
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(220, ROW_HEIGHT)
        Desaturate(dropdown)
        if dropdown.Arrow then dropdown.Arrow:SetDesaturated(true); dropdown.Arrow:SetVertexColor(0.6, 0.82, 1) end
        dropdown:SetupMenu(function(_, root)
            for _, name in ipairs(BugLab:GetProbeAddons()) do
                root:CreateRadio(name, function() return self.addon == name end, function() self:SelectAddon(name) end)
            end
        end)
        view.menu = dropdown
        view.addonText = dropdown.Text or page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    else
        dropdown = Button(page, "", 220, function()
            local list = BugLab:GetProbeAddons()
            local index = 0
            for i, name in ipairs(list) do if name == self.addon then index = i end end
            self:SelectAddon(list[index % math.max(#list, 1) + 1])
        end)
        view.addonText = dropdown
    end
    dropdown:SetPoint("TOPLEFT", 6, -22)
    view.dropdown = dropdown
    -- Im Spiel hat das Auswahlfeld einen eigenen Text; hier nur den Namen setzen.
    local setText = view.addonText.SetText
    view.addonText.SetText = function(frame, text) setText(frame, text) end

    view.log = Button(page, L["PROBE_OPEN_LOG"], 160, function()
        local console = BugLab:GetModule("Console", true)
        if console and console.view then console:SetKind("probe") end
        BugLab:SelectTab("Console")
    end)
    view.log:SetPoint("TOPRIGHT", -6, -22)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)
    scroll:SetScript("OnSizeChanged", function(_, width)
        if view.content then view.content:SetWidth(math.max(width, 600)) end
    end)
    view.scroll = scroll

    page:SetScript("OnShow", function() self:Refresh() end)
end

-- Wählt ein vorhandenes Addon (das gewählte bleibt, sonst das erste).
function Probe:Refresh()
    local list = BugLab:GetProbeAddons()
    local current = self.addon
    local found = false
    for _, name in ipairs(list) do if name == current then found = true end end
    if not found then current = list[1] end
    self:SelectAddon(current)
end

-- BugLabs eigene Probe: "Hallo Lua Fehler" erzeugt einen harmlosen Lua-Fehler, der wie jeder andere bei BugGrabber/BugSack
-- ankommt. Der Fehler entsteht in einem eigenen Timer-Aufruf, weil BugLab Fehler aus Probes sonst selbst abfängt und
-- ins Probe-Log schreibt.
function Probe:RegisterOwnProbes()
    BugLab:RegisterProbe("BugLab", "lua-error", {
        mode = "once", title = L["PROBE_LUAERR_TITLE"], desc = L["PROBE_LUAERR_DESC"],
        params = { { key = "text", type = "text", label = L["PROBE_LUAERR_TEXT"], default = "Hallo Lua Fehler" } },
        run = function(ctx, p)
            ctx.log:Info(L["PROBE_LUAERR_LOG"], p.text)
            C_Timer.After(0, function() error(p.text, 0) end)
        end,
    })
end

function Probe:OnEnable()
    self:RegisterOwnProbes()
    if not self.view then self:BuildPage() end
    self:RegisterMessage("BUGLAB_PROBE_REGISTERED", function()
        if self.view.page:IsShown() then self:Refresh() end
    end)
    self:RegisterMessage("BUGLAB_PROBE_STATE", "UpdateRunning")
    self:RegisterMessage("BUGLAB_PROBE_DONE", "OnProbeDone")
end
