-- Probe-API: Addons melden Tests ("Probes") an, BugLab liefert Oberfläche, Befehle und Langzeitlog dazu.
-- Aufruf aus anderen Addons:
--   BugLab:RegisterProbe("MeinAddon", "glow", {
--       title = "Leuchten", desc = "Zeigt das Leuchten",
--       params = { { key = "farbe", type = "color", default = "ff0000" }, { key = "modus", type = "choice", values = { "static", "pulse" } } },
--       mode = "toggle" (Standard: Starten und Beenden) oder "once" (nur "Ausführen"),
--       run = function(ctx, p) ctx.log:Info("Farbe %s", p.farbe) end,
--       stop = function(ctx) end,
--   })
local BugLab = _G.BugLab
local L = BugLab.L

BugLab.probes = {}   -- [addon] = { [key] = definition }
local order = {}     -- Anmeldereihenfolge je Addon
local running = {}   -- ["addon\0key"] = ctx

local PARAM_TYPES = { number = true, text = true, choice = true, color = true, bool = true }

local function RunKey(addon, key) return addon .. "\0" .. key end

-- Meldet eine Probe an. Gleicher Addon- und Probename ersetzt die frühere Anmeldung.
function BugLab:RegisterProbe(addon, key, def)
    assert(type(addon) == "string" and type(key) == "string", "RegisterProbe(addon, key, def)")
    assert(type(def) == "table" and type(def.run) == "function", "RegisterProbe: def.run fehlt")
    local params = {}
    for _, param in ipairs(def.params or {}) do
        assert(type(param.key) == "string", "RegisterProbe: param.key fehlt")
        params[#params + 1] = {
            key = param.key, type = PARAM_TYPES[param.type] and param.type or "text", label = param.label or param.key,
            values = param.values, default = param.default, optional = param.optional or param.default ~= nil,
        }
    end
    local list = self.probes[addon]
    if not list then
        list = {}
        self.probes[addon] = list
        order[addon] = {}
    end
    if not list[key] then table.insert(order[addon], key) end
    list[key] = { addon = addon, key = key, once = def.mode == "once", title = def.title or key, desc = def.desc, params = params, run = def.run, stop = def.stop }
    self:SendMessage("BUGLAB_PROBE_REGISTERED", addon, key)
    return true
end

function BugLab:HasProbes()
    return next(self.probes) ~= nil
end

-- Addons mit Probes, alphabetisch.
function BugLab:GetProbeAddons()
    local list = {}
    for addon in pairs(self.probes) do list[#list + 1] = addon end
    table.sort(list)
    return list
end

-- Probes eines Addons in Anmeldereihenfolge.
function BugLab:GetProbes(addon)
    local list = {}
    for _, key in ipairs(order[addon] or {}) do list[#list + 1] = self.probes[addon][key] end
    return list
end

function BugLab:GetProbe(addon, key)
    return self.probes[addon] and self.probes[addon][key]
end

function BugLab:IsProbeRunning(addon, key)
    return running[RunKey(addon, key)] ~= nil
end

-- Logger einer Probe: schreibt ins Probe-Log, Quelle "Addon:probe".
local function ProbeLogger(addon, key)
    local source, log = addon .. ":" .. key, {}
    for _, name in ipairs(BugLab.LEVELS) do
        log[name:sub(1, 1) .. name:sub(2):lower()] = function(_, fmt, ...)
            return BugLab:AddEntry(source, BugLab:FormatMessage(fmt, ...), name, "probe")
        end
    end
    function log:Dump(value, label, level, opts)
        level = level or "INFO"
        if label then BugLab:AddEntry(source, tostring(label), level, "probe") end
        for _, line in ipairs(BugLab:DumpLines(value, opts)) do BugLab:AddEntry(source, line, level, "probe") end
    end
    return log
end

-- Wandelt den Text eines Parameters um; gibt Wert oder nil und eine Fehlermeldung zurück.
local function Convert(param, text)
    if param.type == "number" then
        local value = tonumber((text:gsub(",", ".")))
        if not value then return nil, L["PROBE_ERR_NUMBER"]:format(param.key) end
        return value
    elseif param.type == "bool" then
        text = text:lower()
        if text == "1" or text == "true" or text == "an" or text == "ja" or text == "on" then return true end
        if text == "0" or text == "false" or text == "aus" or text == "nein" or text == "off" then return false end
        return nil, L["PROBE_ERR_BOOL"]:format(param.key)
    elseif param.type == "choice" then
        for _, value in ipairs(param.values or {}) do
            if tostring(value):lower() == text:lower() then return value end
        end
        return nil, L["PROBE_ERR_CHOICE"]:format(param.key, table.concat(param.values or {}, ", "))
    end
    return text
end

-- Parameter aus einem Befehlstext ("ff0000, pulse 5"): getrennt durch Komma oder Leerzeichen, in der Reihenfolge der
-- Parameter; fehlende optionale Parameter nehmen ihren Standardwert.
function BugLab:ParseProbeArgs(def, text)
    local tokens = {}
    for token in (text or ""):gmatch("[^,%s]+") do tokens[#tokens + 1] = token end
    local values = {}
    for i, param in ipairs(def.params) do
        local token = tokens[i]
        -- Ein Textparameter am Ende nimmt den Rest der Eingabe (mit Leerzeichen).
        if token and param.type == "text" and i == #def.params then token = table.concat(tokens, " ", i) end
        if token then
            local value, err = Convert(param, token)
            if value == nil then return nil, err end
            values[param.key] = value
        elseif param.default ~= nil then
            values[param.key] = param.default
        elseif not param.optional then
            return nil, L["PROBE_ERR_MISSING"]:format(param.key)
        end
    end
    return values
end

-- Startet eine Probe (Werte als Tabelle {key = wert}); eine laufende wird vorher beendet.
function BugLab:StartProbe(addon, key, values)
    local def = self:GetProbe(addon, key)
    if not def then return false, L["PROBE_ERR_UNKNOWN"]:format(addon, key) end
    if self:IsProbeRunning(addon, key) then self:StopProbe(addon, key) end
    local ctx = { addon = addon, key = key, params = values or {}, log = ProbeLogger(addon, key) }
    -- Einmal-Probes laufen nur durch und gelten nie als "läuft"; die übrigen bleiben bis zum Beenden aktiv.
    if not def.once then running[RunKey(addon, key)] = ctx end
    ctx.log:Info(L[def.once and "PROBE_EXECUTED" or "PROBE_STARTED"])
    local ok, err = pcall(def.run, ctx, ctx.params)
    if not ok then
        ctx.log:Error(L["PROBE_FAILED"], tostring(err))
        running[RunKey(addon, key)] = nil
    end
    self:SendMessage("BUGLAB_PROBE_STATE", addon, key)
    if ok and def.once then self:SendMessage("BUGLAB_PROBE_DONE", addon, key) end
    return ok, ok and nil or tostring(err)
end

function BugLab:StopProbe(addon, key)
    local ctx = running[RunKey(addon, key)]
    if not ctx then return false end
    running[RunKey(addon, key)] = nil
    local def = self:GetProbe(addon, key)
    if def and def.stop then
        local ok, err = pcall(def.stop, ctx)
        if not ok then ctx.log:Error(L["PROBE_FAILED"], tostring(err)) end
    end
    ctx.log:Info(L["PROBE_STOPPED"])
    self:SendMessage("BUGLAB_PROBE_STATE", addon, key)
    return true
end

-- /buglab probe: ohne Argument die Liste, sonst "<Addon> <Probe> [Werte]" oder "stop <Addon> <Probe>".
function BugLab:HandleProbeCommand(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    local stopArgs = text:match("^[Ss][Tt][Oo][Pp]%s+(.+)$")
    local addon, key, rest
    if stopArgs then addon, key = stopArgs:match("^(%S+)%s+(%S+)") else addon, key, rest = text:match("^(%S+)%s+(%S+)%s*(.*)$") end
    if not addon then
        self:Print(L["PROBE_LIST_HEADER"])
        for _, name in ipairs(self:GetProbeAddons()) do
            for _, def in ipairs(self:GetProbes(name)) do
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cff66bbff%s %s|r |cff999999- %s|r", name, def.key, def.title))
            end
        end
        return
    end
    if stopArgs then
        if not self:StopProbe(addon, key) then self:Print(L["PROBE_ERR_UNKNOWN"]:format(addon, key)) end
        return
    end
    local def = self:GetProbe(addon, key)
    if not def then self:Print(L["PROBE_ERR_UNKNOWN"]:format(addon, key)); return end
    local values, err = self:ParseProbeArgs(def, rest)
    if not values then self:Print(BugLab:Paint("ERROR", err)); return end
    local ok, runErr = self:StartProbe(addon, key, values)
    if not ok then self:Print(BugLab:Paint("ERROR", runErr)) end
end
