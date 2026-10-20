"""Lädt das Addon mit einer simulierten WoW-Umgebung (lupa, Lua 5.1) und prüft den Start.

Aufruf: python3 tests/run_addon.py
Die WoW-API ist nur grob gestubbt: unbekannte Globals werden zu tolerierenden Proxys,
damit die Libs laden. Geprüft werden Ladereihenfolge, Events und Slash-Befehl, nicht das Rendering.
"""
import re
import sys
from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent / "BugLab"

STUB = r"""
local function proxy(name)
    local p = {}
    return setmetatable(p, {
        __index = function(t, k)
            if k == "__name" then return name end
            local v = proxy(name .. "." .. tostring(k)); rawset(t, k, v); return v
        end,
        __call = function(self, ...) return proxy(name .. "()") end,
    })
end

local G = _G
local real = {}
setmetatable(G, { __index = function(t, k)
    if real[k] ~= nil then return real[k] end
    -- Eigene Namen und Lib-Registries müssen nil bleiben, sonst laden sich Libs nicht.
    if type(k) ~= "string" or not k:find("^[A-Z]") or k:find("^Lib") or k:find("^Ace")
        or k:find("^Callback") or k:find("^BugLab") or k == "GAME_LOCALE" or k == "C_AddOns" or k == "C_Texture" or k == "TimeManagerClockButton" then return nil end
    return proxy(k)
end })

-- Echte Semantik nur dort, wo Libs/Addon Werte auswerten.
G.strjoin = function(sep, ...) local t = {...}; for i = 1, select("#", ...) do t[i] = tostring(t[i]) end return table.concat(t, sep) end
G.tostringall = function(...) local t = {...}; for i = 1, select("#", ...) do t[i] = tostring(t[i]) end return unpack(t, 1, select("#", ...)) end
G.strmatch, G.strfind, G.gsub_ = string.match, string.find, string.gsub
G.tinsert, G.tremove, G.wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end return t end
G.format = string.format
G.GetLocale = function() return LOCALE end
G.GetAddOnMetadata = function(_, f) return META[f] end
G.IsLoggedIn = function() return false end
G.UnitName = function() return "Tester" end
G.GetRealmName = function() return "Realm" end
G.UnitFactionGroup = function() return "Alliance", "Alliance" end
G.UnitRace = function() return "Human", "Human" end
G.GetNormalizedRealmName = function() return "Realm" end
G.GetCurrentRegion = function() return 3 end
G.GetCurrentRegionName = function() return "EU" end
G.UnitClass = function() return "Warrior", "WARRIOR" end
G.UnitFullName = function() return "Tester", "Realm" end
G.ERRORS = {}
G.geterrorhandler = function() return function(e) ERRORS[#ERRORS + 1] = tostring(e) .. "\n" .. debug.traceback() end end
G.seterrorhandler = function() end
G.InCombatLockdown = function() return false end
G.GetBuildInfo = function() return "1.16.1", "1", "Jan 1 2026", 16001 end
-- WoW-xpcall reicht Argumente durch, Lua 5.1 nicht.
local lua_xpcall = xpcall
G.xpcall = function(f, h, ...) local a = {...}; local n = select("#", ...); return lua_xpcall(function() return f(unpack(a, 1, n)) end, h) end
G.CHAT = {}
G.UISpecialFrames = {}
G.RELOADS, G.MODS = 0, { ctrl = true, shift = true, alt = true }
G.ReloadUI = function() RELOADS = RELOADS + 1 end
G.IsControlKeyDown = function() return MODS.ctrl end
G.IsShiftKeyDown = function() return MODS.shift end
G.IsAltKeyDown = function() return MODS.alt end
G.AddonCompartmentFrame = { RegisterAddon = function(_, info) COMPARTMENT = info end }
G.GetMinimapShape = function() return "ROUND" end
G.Minimap = setmetatable({ GetWidth = function() return 140 end, GetHeight = function() return 140 end, GetCenter = function() return 500, 500 end,
                           GetEffectiveScale = function() return 1 end }, { __index = function() return function() end end })
-- Zweiter Lauf (deDE) simuliert einen Clock-Button mit Rahmen-Atlas, erster nutzt den Fallback-Rahmen.
if CLOCK_ATLAS then
    G.TimeManagerClockButton = { GetNumRegions = function() return 1 end, GetNumChildren = function() return 0 end,
        GetRegions = function() return { GetAtlas = function() return CLOCK_ATLAS end } end }
end
G.GetCursorPosition = function() return 600, 500 end
G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHAT[#CHAT + 1] = m end }
G.Settings = { OpenToCategory = function(n) OPENED = n end,
               RegisterCanvasLayoutCategory = function() return { ID = "x" } end,
               RegisterAddOnCategory = function() end }
-- Frames und Texturen kennen ihren Parent, weil Libs (LibDBIcon) darüber navigieren.
local function child(kind, parent)
    local f = proxy(kind)
    rawset(f, "GetParent", function() return parent end)
    rawset(f, "GetFrameLevel", function() return 1 end)
    rawset(f, "CreateTexture", function(self) return child("Texture", self) end)
    rawset(f, "CreateFontString", function(self) return child("FontString", self) end)
    rawset(f, "CreateMaskTexture", function(self) return child("Mask", self) end)
    return f
end
G.CreateFrame = function(_, _, parent) return child("Frame", parent) end
G.hooksecurefunc = function() end
G.C_AddOns = nil
G.C_Texture = nil
"""


def parse_toc(path):
    meta, files = {}, []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"##\s*([^:]+):\s*(.*)", line)
        if m:
            meta[m.group(1).strip()] = m.group(2).strip()
        elif line.strip() and not line.startswith("#"):
            files.append(line.strip())
    return meta, files


def expand(path, out):
    """Löst XML-Include/Script rekursiv in eine Lua-Dateiliste auf."""
    if path.suffix.lower() == ".lua":
        out.append(path)
        return
    text = re.sub(r"<!--.*?-->", "", path.read_text(encoding="utf-8"), flags=re.S)
    for tag, f in re.findall(r"<(Include|Script)\s+file=\"([^\"]+)\"", text):
        expand(path.parent / f.replace("\\", "/"), out)


def run(locale):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    meta, toc_files = parse_toc(ROOT / "BugLab.toc")
    g = lua.globals()
    g.LOCALE = locale
    g.CLOCK_ATLAS = "ClockBorder-Test" if locale == "deDE" else None
    g.META = lua.table_from(meta)
    lua.execute(STUB)

    files = []
    for f in toc_files:
        expand(ROOT / f, files)
    for f in files:
        # Wie WoW: jede Datei bekommt (addonName, addonTable) als Varargs.
        chunk = lua.eval("function(src, name) local f, e = loadstring(src, name); if not f then error(e) end; return f end")
        fn = chunk(f.read_text(encoding="utf-8"), "@" + str(f.relative_to(ROOT)))
        fn("BugLab", lua.table())

    # Addon-Lebenszyklus: ADDON_LOADED -> PLAYER_LOGIN triggert OnInitialize/OnEnable.
    lua.execute("""
        local AceAddon = LibStub("AceAddon-3.0")
        local ev = LibStub("AceEvent-3.0")
        -- AceAddon hängt sich an einen echten Frame; hier manuell auslösen.
        local addon = AceAddon:GetAddon("BugLab")
        AceAddon:InitializeAddon(addon)
        AceAddon:EnableAddon(addon)
    """)
    errs = list(g.ERRORS.values())
    assert not errs, "Lua-Fehler im Lifecycle:\n" + "\n".join(errs)
    # Versionsdarstellung: Stufe blau, Repo-Zähler grau.
    fv = lua.eval('function() return BugLab:FormatVersion() end')()
    assert fv.endswith("-|r|cff66bbffalpha|r|cff808080.1|r"), fv
    # Tooltip: Hinweiszeile mit entsättigtem, blau eingefärbtem i-Symbol (Mock-Tooltip mit Namen).
    lua.execute("""
        MOCK_LINES = {}
        TT = { GetName = function() return "MockTT" end, NumLines = function() return #MOCK_LINES end,
               AddLine = function(_, t) MOCK_LINES[#MOCK_LINES + 1] = t end,
               HookScript = function() end,
               CreateTexture = function() local t = { calls = {} }
                   for _, m in ipairs({ "SetTexture", "SetSize", "SetDesaturated", "SetVertexColor", "ClearAllPoints", "SetPoint", "Show", "Hide", "SetAlpha" }) do
                       t[m] = function(_, ...) t.calls[m] = { ... } end
                   end
                   return t end }
        MockTTTextLeft3 = {}
        BugLab:FillLauncherTooltip(TT)
    """)
    icon = g.TT.bugLabInfoIcon
    assert icon.calls.SetDesaturated[1] is True, "i-Symbol nicht entsättigt"
    assert abs(icon.calls.SetVertexColor[1] - 0.4) < 1e-6
    assert "66bbff" in g.MOCK_LINES[len(g.MOCK_LINES)], g.MOCK_LINES[len(g.MOCK_LINES)]
    # Reload-Hotkey: nur mit allen drei Modifikatoren und R.
    assert g.BugLab.hotkeyFrame is not None
    lua.execute('BugLab:HandleReloadKey("R")')
    assert g.RELOADS == 1, g.RELOADS
    lua.execute('BugLab:HandleReloadKey("T"); MODS.alt = false; BugLab:HandleReloadKey("R"); MODS.alt = true')
    assert g.RELOADS == 1, g.RELOADS
    lua.execute('BugLab.db.profile.reloadHotkey = false; BugLab:HandleReloadKey("R"); BugLab.db.profile.reloadHotkey = true')
    assert g.RELOADS == 1, "Hotkey lässt sich nicht abschalten"
    # Einrasten der Minimap-Position bei 55, 90 und 180 Grad.
    assert lua.eval('BugLab:SnapMinimapPosition(177)') == 180
    assert lua.eval('BugLab:SnapMinimapPosition(92.5)') == 90
    assert lua.eval('BugLab:SnapMinimapPosition(52)') == 55
    assert lua.eval('BugLab:SnapMinimapPosition(120)') == 120
    # Debug-Zeilen (Strg+Umschalt): weißer Mittelpunkt, Position in Grad.
    dbg = lua.eval('(function() local b = {minimapPos = 180, registeredName = "X"}; return table.concat(BugLab:GetDebugLines(b), "\\n") end)()')
    assert dbg.startswith("|cffffffff\u00b7|r ") and "180.0" in dbg and "X" in dbg, dbg
    # Launcher: Addon-Menü-Eintrag, Broker-Objekt und Minimap-Button (Handler, nicht Rendering).
    assert g.COMPARTMENT is not None and "Bug" in g.COMPARTMENT.text, "Addon-Menü-Eintrag fehlt"
    assert lua.eval('LibStub("LibDataBroker-1.1"):GetDataObjectByName("BugLab").type') == "launcher"
    assert g.BugLab.minimapButton is not None
    lua.execute('BugLab:SetMinimapButtonShown(false)')
    assert g.BugLab.db.profile.minimap.hide is True
    lua.execute('BugLab:SetMinimapButtonShown(true)')
    lua.execute('BugLab:OnSlashCommand("")')  # öffnet das Fenster
    # Fenster: /buglab und /bl schalten es um (gestubbte Frames, geprüft wird die Logik, nicht das Rendering).
    assert g.BugLab.window is not None, "Fenster wurde nicht erzeugt"
    lua.execute('BugLab:OnSlashCommand("hilfe")')
    n = len(g.CHAT)
    assert n >= 3 and "/bl" in g.CHAT[n - 1], list(g.CHAT.values())
    assert g.SlashCmdList["ACECONSOLE_BL"] is not None and g.SlashCmdList["ACECONSOLE_BUGLAB"] is not None
    vis = lua.eval('function() BugLab:SetModuleEnabled("Probe", false); return table.concat(BugLab:GetVisibleModules(), ",") end')()
    assert vis == "Console,Inspector", vis
    assert g.BugLab.window.selected == "Console", g.BugLab.window.selected
    lua.execute('BugLab:SetModuleEnabled("Probe", true)'), "Slash-Befehl öffnet die Einstellungen nicht"
    assert g.BugLab.db.profile.debug is False
    # Optionstabelle muss die AceConfigRegistry-Validierung bestehen und die drei Tabs liefern.
    names = lua.eval('''function()
        local t = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("BugLab", "dialog", "test-1.0")
        local keys = {}
        for k in pairs(t.args) do keys[#keys + 1] = k end
        table.sort(keys)
        return table.concat(keys, ",")
    end''')()
    assert names == "general,overview,profiles", names
    mods = lua.eval('''function()
        local t = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("BugLab", "dialog", "test-1.0")
        local a = t.args.overview.args
        BugLab:SetModuleEnabled("Probe", false)
        return a.moduleConsole.name .. "|" .. tostring(a.moduleProbe.get()) .. "|" .. a.moduleInspector.name
    end''')()
    assert mods.startswith("|cffffffffBug|r|cff66bbffConsole|r |cffffffff\u00b7|r |cff999999"), mods
    assert "|false|" in mods, mods
    lua.execute('BugLab:Print("hi")')
    last = g.CHAT[len(g.CHAT)]
    assert "{|r" in last and "hi" in last, last
    L = g.BugLab.L
    tab = L["TAB_OVERVIEW"]
    expected = {"enUS": "Overview", "deDE": "Übersicht"}[locale]
    assert tab == expected, (locale, tab)
    print(f"OK {locale}: {len(files)} Dateien geladen, Tab '{tab}'")


if __name__ == "__main__":
    for loc in ("enUS", "deDE"):
        run(loc)
    sys.exit(0)
