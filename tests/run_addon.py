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
G.time, G.date = os.time, os.date
G.NOW = 1000
G.GetTime = function() return NOW end
G.NUM_CHAT_WINDOWS = 10
G.GetChatWindowInfo = function() return nil end
G.EnumerateFrames = function() return nil end
G.InCombatLockdown = function() return false end
G.securecallfunction = function(f, ...) return f(...) end
G.strsplit = function(sep, s)
    local out, pos = {}, 1
    while true do
        local a, b = string.find(s, sep, pos, true)
        if not a then out[#out + 1] = string.sub(s, pos); break end
        out[#out + 1] = string.sub(s, pos, a - 1); pos = b + 1
    end
    return unpack(out)
end
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


def check_local_order():
    """Fängt "lokal definiert, aber vorher benutzt": Lua liest dann eine (nicht vorhandene) globale Variable.
    Der Stub liefert für Namen mit Großbuchstaben Proxys und würde den Fehler sonst verdecken."""
    import re, pathlib
    problems = []
    for path in sorted(pathlib.Path("BugLab").rglob("*.lua")):
        if "Libs" in path.parts:
            continue
        lines = path.read_text(encoding="utf-8").split("\n")

        def code(line):
            line = re.sub(r'"(\\.|[^"\\])*"', '""', line)
            return line.split("--")[0]

        defs = {}
        for i, line in enumerate(lines):
            m = re.match(r"local function ([A-Za-z_]\w*)", line) or re.match(r"local ([A-Za-z_]\w*)\s*=", line)
            if m and m.group(1) not in defs:
                defs[m.group(1)] = i
        for name, at in defs.items():
            for i in range(at):
                if re.search(r"(?<![\w.:])" + re.escape(name) + r"\b", code(lines[i])):
                    problems.append(f"{path}:{i + 1} nutzt '{name}' vor der Definition (Zeile {at + 1})")
    assert not problems, "\n".join(problems)


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
    assert re.search(r"-\|r\|cff66bbffalpha\|r\|cff808080\.\d+\|r$", fv), fv
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
    # Inspector-Hotkey: Strg+Umschalt+Alt+I startet die Elementwahl, andere Tasten nicht.
    assert lua.eval('BugLab:HandleHotkey("I") == true')
    assert lua.eval('BugLab:HandleHotkey("T") == nil')
    lua.execute('BugLab:GetModule("Inspector"):StopPick()')
    assert g.RELOADS == 1, "Hotkey lässt sich nicht abschalten"
    # Eingabefelder reichen den Reload-Hotkey weiter.
    assert lua.eval('type(BugLab.HookReloadKey)') == "function"
    # BugSack-Anbindung: ohne BugSack nicht verfügbar, keine Fehler beim Aktualisieren.
    assert lua.eval('BugLab:IsBugSackAvailable()') is False
    assert lua.eval('BugLab:GetBugSackCount()') is None
    lua.execute('BugLab:UpdateBugSackButton()')
    # Einrasten der Minimap-Position bei 55, 90 und 180 Grad.
    assert lua.eval('BugLab:SnapMinimapPosition(177)') == 180
    assert lua.eval('BugLab:SnapMinimapPosition(92.5)') == 90
    assert lua.eval('BugLab:SnapMinimapPosition(52)') == 55
    assert lua.eval('BugLab:SnapMinimapPosition(120)') == 120
    # Debug-Zeilen (Strg+Umschalt): weißer Mittelpunkt, Position in Grad.
    dbg = lua.eval('(function() local b = {minimapPos = 180, registeredName = "X"}; return table.concat(BugLab:GetDebugLines(b), "\\n") end)()')
    assert dbg.startswith("|cffffffff\u00b7|r ") and "180.0" in dbg and "X" in dbg, dbg
    # Console-Filter: Pflichtwörter, -Ausschluss, Phrasen in Anführungszeichen.
    def match(f, line):
        return lua.eval('(function(f, l) return BugLab:MatchesFilter(BugLab:ParseFilter(f), l) end)')(f, line)
    assert match('-Messung', 'Messung beendet') is False
    assert match('-Messung', 'Zone gewechselt') is True
    assert match('-"Ebene 4"', 'Frame X gewählt (Ebene 4)') is False
    assert match('-"Ebene 4"', 'Ebene 5 und 4') is True
    assert match('zone -cache', 'Zone gewechselt') is True
    assert match('zone -cache', 'Zone Cache') is False
    assert match('ZONE', 'zone x') is True
    assert match('', 'egal') is True
    # Begriffe unter 3 Zeichen filtern nicht (Plus und Minus, auch in Anführungszeichen); Umlaute zählen als ein Zeichen.
    assert match('ab', 'xyz') is True and match('-ab', 'ab') is True and match('-"ab"', 'ab') is True
    assert match('abc', 'xyz') is False and match('-äöü', 'äöü') is False
    assert match('a.b', 'axb') is False, "Eingabe darf kein Lua-Muster sein"
    # Zeitraum: Stunde/Tag/Woche relativ zu "jetzt", "alles" unbegrenzt.
    inr = lua.eval('function(k, s, n) return BugLab:InTimeRange(k, s, n) end')
    assert inr("hour", 10000 - 1800, 10000) and not inr("hour", 10000 - 4000, 10000)
    assert inr("week", 1, 6 * 86400) and not inr("week", 1, 9 * 86400)
    assert inr("all", 0, 10**9)
    assert inr("h3", 10000 - 9000, 10000) and not inr("h3", 10000 - 11000, 10000)
    assert inr("d3", 1, 2 * 86400) and not inr("d3", 1, 4 * 86400)
    cr = lua.eval('function(s, n, f, t) return BugLab:InTimeRange("custom", s, n, f, t) end')
    f0, t0 = 1700000000, 1700000000 + 2 * 86400
    assert cr(f0 + 100, 2 * 10**9, f0, t0) and not cr(f0 - 1, 2 * 10**9, f0, t0) and not cr(t0 + 1, 2 * 10**9, f0, t0) and cr(t0, 2 * 10**9, f0, t0)
    # Log-API und Historie: Quelle, Format, Aufräumen nach Tagen.
    lua.execute('BugLab:ClearHistory(); BugLab.db.profile.historyDays = 30')
    lua.execute('BugLab:Log("Console", "hallo"); BugLab:Log("FremdAddon", "x")')
    assert lua.eval('#BugLab:GetHistory()') == 2
    assert lua.eval('BugLab:GetHistory()[1].i') is True and lua.eval('BugLab:GetHistory()[2].i') is None
    line = lua.eval('BugLab:FormatEntry(BugLab:GetHistory()[1])')
    assert "BugLab_Beetle_White_32" in line and "|cffffffffBug|r|cff66bbffLab|r|cff808080:Console|r" in line and line.endswith("hallo"), line
    lua.execute('local h = BugLab:GetHistory(); h[1].t = time() - 40 * 86400')
    assert lua.eval('BugLab:PruneHistory()') == 1 and lua.eval('#BugLab:GetHistory()') == 1
    assert lua.eval('BugLab:GetLogSources()[1]') == "FremdAddon"
    lua.execute('BugLab:ClearHistory(); BugLab.db.profile.logRateLimit = 0')
    lua.execute('local log = BugLab:GetLogger("A"); log:Warn("w"); log:Error("e"); log:Info("i"); BugLab:Log("A", "d", "debug")')
    assert lua.eval('(function() local h = BugLab:GetHistory(); return h[1].l .. h[2].l .. h[3].l .. h[4].l end)()') == "3421"
    assert "|cffffd100w|r" in lua.eval('BugLab:FormatEntry(BugLab:GetHistory()[1])')
    assert lua.eval('BugLab:FormatEntry(BugLab:GetHistory()[3])').endswith(" i")
    assert lua.eval('BugLab:LevelIndex("nonsense")') == 2
    assert lua.eval('BugLab:GetLogger("A") == BugLab:GetLogger("A")') is True
    # Logger: eigene Mindeststufe, Abschalten, Werte blau (Warnfarbe läuft nach dem Wert weiter).
    lua.execute('BugLab:ClearHistory(); local log = BugLab:GetLogger("B"); log:SetLevel("WARN"); log:Info("zu leise"); log:Warn("Zone %s, Ebene %d", "Elwynn", 4); log:SetEnabled(false); log:Error("aus")')
    assert lua.eval('#BugLab:GetHistory()') == 1
    line = lua.eval('BugLab:FormatEntry(BugLab:GetHistory()[1])')
    assert '|cff66bbffElwynn|r|cffffd100' in line and "|cff66bbff4|r" in line, line
    assert lua.eval('BugLab:FormatMessage("100% sicher")') == "100% sicher"  # ohne Werte unverändert
    assert lua.eval('BugLab:FormatMessage("%d%%", 5)').endswith("5|r%")
    assert lua.eval('BugLab:FormatMessage("%d", "kein Zahl")').startswith("%d")
    # Dump: eingerückt, Tiefenlimit, Zyklenschutz.
    lua.execute('BugLab:ClearHistory(); BugLab:GetLogger("C"):SetEnabled(true); local c = {a = 1, b = {x = "y"}}; c.self = c; BugLab:GetLogger("C"):Dump(c, "Test")')
    dump = lua.eval('(function() local t = {} for _, e in ipairs(BugLab:GetHistory()) do t[#t + 1] = e.m end return table.concat(t, "|") end)()')
    assert dump.startswith("Test|") and "<...>" in dump and "  " in dump and "a:" in dump, dump
    # Drosselung: 3 Zeilen pro Sekunde, danach verworfen, in der nächsten Sekunde eine Warnung.
    lua.execute('BugLab:ClearHistory(); BugLab.db.profile.logRateLimit = 3; NOW = 2000; for i = 1, 10 do BugLab:Log("D", "x" .. i) end')
    assert lua.eval('#BugLab:GetHistory()') == 3
    lua.execute('NOW = 2001; BugLab:Log("D", "wieder")')
    assert lua.eval('#BugLab:GetHistory()') == 5 and "7" in lua.eval('BugLab:GetHistory()[4].m')
    lua.execute('BugLab.db.profile.logRateLimit = 0')
    # Quellen im Filter: "BugLab:Console", "Addon:Modul", Gruppe "Addon".
    lua.execute('BugLab:ClearHistory(); BugLab:Log("Console", "a"); BugLab:Log("MeinAddon:Netz", "b"); BugLab:Log("MeinAddon:Erw", "c"); BugLab:Log("Solo", "d")')
    srcs = lua.eval('table.concat(BugLab:GetLogSources(), ",")')
    assert srcs == "BugLab,BugLab:Console,MeinAddon,MeinAddon:Erw,MeinAddon:Netz,Solo", srcs
    ms = lua.eval('function(i, s) return BugLab:MatchesSource(BugLab:GetHistory()[i], s) end')
    assert ms(2, "MeinAddon") and ms(3, "MeinAddon") and not ms(4, "MeinAddon") and ms(1, "BugLab") and ms(2, "MeinAddon:Netz") and not ms(3, "MeinAddon:Netz")
    lua.execute('BugLab:ClearHistory()')
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

    # Inspector-API mit einfachen Ersatzobjekten (nur die Frame-Methoden, die gelesen werden).
    insp = lua.eval('''function()
        local function Obj(kind, name, parent)
            local o = { kind = kind, name = name, parent = parent, points = {}, w = 100, h = 50, alpha = 1, scale = 1, children = {}, regions = {} }
            function o:GetObjectType() return self.kind end
            function o:GetName() return self.name end
            function o:GetParent() return self.parent end
            function o:GetNumPoints() return #self.points end
            function o:GetPoint(i) local p = self.points[i]; return p[1], p[2], p[3], p[4], p[5] end
            function o:SetPoint(pt, rel, rp, x, y) table.insert(self.points, { pt, rel, rp or pt, x or 0, y or 0 }) end
            function o:ClearAllPoints() self.points = {} end
            function o:GetSize() return self.w, self.h end
            function o:SetWidth(v) self.w = v end
            function o:SetHeight(v) self.h = v end
            function o:GetAlpha() return self.alpha end
            function o:SetAlpha(v) self.alpha = v end
            function o:GetEffectiveAlpha() return self.alpha end
            function o:IsShown() return true end
            function o:IsVisible() return true end
            function o:IsMouseOver() return self.over end
            function o:GetRect() return 10, 20, self.w, self.h end
            function o:GetDrawLayer() return "ARTWORK", 2 end
            if kind == "Frame" then
                function o:GetChildren() return unpack(self.children) end
                function o:GetRegions() return unpack(self.regions) end
                function o:GetFrameStrata() return "MEDIUM" end
                function o:GetFrameLevel() return 3 end
                function o:GetScale() return self.scale end
                function o:SetScale(v) self.scale = v end
                function o:GetEffectiveScale() return self.scale end
                function o:IsMouseEnabled() return true end
                function o:IsMovable() return false end
                function o:IsProtected() return false end
                function o:HasScript(name) return name == "OnClick" end
                function o:GetScript(name) return name == "OnClick" and function() end or nil end
            elseif kind == "Texture" then
                function o:GetTexture() return "Interface\\\\Foo\\\\Bar" end
                function o:GetAtlas() return nil end
                function o:GetTexCoord() return 0, 1, 0, 1, 0, 1, 0, 1 end
                function o:GetVertexColor() return 0.5, 0.5, 0.5, 1 end
                function o:GetBlendMode() return "ADD" end
                function o:IsDesaturated() return true end
                function o:GetHorizTile() return false end
                function o:GetVertTile() return false end
            end
            return o
        end
        local parent = Obj("Frame", "UIParentFake")
        local mine = Obj("Frame", "MeinFrame", parent)
        mine:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -6)
        local tex = Obj("Texture", nil, mine)
        mine.regions[1] = tex
        local blizz = Obj("Frame", "BlizzFrame", parent)
        _G.BugLabFrameOwners[mine] = "MeinAddon"
        _G.BugLabFrameOwners[blizz] = "Blizzard"
        local runtime = Obj("Frame", nil, mine)
        _G.BugLabFrameOwners[runtime] = "?"
        local lone = Obj("Frame", "LoneFrame", parent)
        _G.BugLabFrameOwners[lone] = "?"
        local ownNamed = Obj("Frame", "BugLabWindowFake", parent)
        _G.BugLabFrameOwners[ownNamed] = "Glimpse_Database_Professions"
        local ownersText = BugLab:ObjectOwner(runtime) .. "," .. BugLab:ObjectOwner(lone) .. "," .. BugLab:ObjectOwner(ownNamed) .. ";" .. BugLab:TextureName(tex)
        local info = BugLab:DescribeObject(mine)
        local out = {}
        out.owners = ownersText
        out.name, out.type, out.w, out.pts, out.owner = info.name, info.type, info.w or info.width, #info.points, info.owner
        out.texinfo = BugLab:DescribeObject(tex)
        out.tex, out.blend, out.coords = out.texinfo.texture, out.texinfo.blend, #out.texinfo.texCoord
        out.lines = table.concat(BugLab:FormatObjectInfo(info), " ") .. table.concat(BugLab:FormatObjectInfo(out.texinfo), " ")
        out.editMine = BugLab:CanEditObject(mine)
        out.editBlizz = BugLab:CanEditObject(blizz)
        out.setX = BugLab:ApplyEdit(mine, "x", 40)
        out.x = mine.points[1][4]
        out.setW = BugLab:ApplyEdit(mine, "width", 222)
        out.refused = BugLab:ApplyEdit(blizz, "x", 1) == false
        out.bad = BugLab:ApplyEdit(mine, "x", "abc") == false
        out.w2 = mine.w
        BugLab:ResetEdit(mine)
        out.xBack, out.wBack = mine.points[1][4], mine.w
        local frameB = Obj("Frame", "FrameB", parent); frameB.over = true
        function frameB:GetFrameStrata() return "DIALOG" end
        local frameC = Obj("Frame", "FrameC", parent)
        mine.over, tex.over = true, true
        local list = { mine, frameB, frameC }
        local oldEnum = _G.EnumerateFrames
        _G.EnumerateFrames = function(prev)
            if prev == nil then return list[1] end
            for i, f in ipairs(list) do if f == prev then return list[i + 1] end end
        end
        local under = BugLab:GetObjectsUnderMouse({})
        _G.EnumerateFrames = oldEnum
        local names = {}
        for _, o in ipairs(under) do names[#names + 1] = BugLab:ObjectName(o) end
        out.under = table.concat(names, ",")
        local I = BugLab:GetModule("Inspector")
        I:Select(mine)
        I:ApplyField("x", 12)
        I:StartPick(); I:UpdatePick(); I:MovePick(1); I:ChoosePick()
        I:Select(blizz)
        I:StartPick(true); I:UpdatePick(); I:ChoosePick(); I:MoveLayer(1); I:MoveLayer(-1, true); I:Select(mine); I:ApplyField("color", "FF8000")
        out.changes = BugLab:ChangesLua()
        assert(out.changes:find("SetPoint", 1, true) and out.changes:find("MeinFrame", 1, true), out.changes)
        I:Select(mine, true); I:ApplyField("y", 3); I:ApplyField("y", -6); I:Select(blizz, true); I:Select(mine); I:ClearSelection()
        BugLab:OnSlashCommand("pick"); I:StopPick()
        I:Select(mine); I:ClearSelection()
        BugLab:SelectTab("Console")
        out.code = BugLab:ExportLua(mine)
        return out.name .. "|" .. out.type .. "|" .. out.owner .. "|" .. out.pts .. "|" .. tostring(out.editMine) .. "|"
            .. tostring(out.editBlizz) .. "|" .. out.x .. "|" .. out.w2 .. "|" .. out.xBack .. "|" .. out.wBack .. "|"
            .. tostring(out.refused) .. "|" .. tostring(out.bad) .. "|" .. out.tex .. "|" .. out.blend .. "|" .. out.coords
            .. "|" .. out.under .. "|" .. out.owners .. "|" .. out.lines .. "|" .. out.code
    end''')
    r = insp().split("|")
    assert r[:15] == ["MeinFrame", "Frame", "MeinAddon", "1", "true", "false", "40", "222", "5", "100", "true", "true",
                      "Interface\\Foo\\Bar", "ADD", "8"], r[:15]
    assert r[15] == "FrameB,MeinFrame,MeinFrame.<Texture>" or r[15].startswith("FrameB,MeinFrame,"), r[15]
    assert r[16] == "MeinAddon,?,BugLab;Interface\\Foo\\Bar", r[16]
    detail = "|".join(r[17:])
    assert "Interface\\Foo\\Bar" in detail and "TOPLEFT" in detail and "OnClick" in detail, detail
    assert 'CreateFrame("Frame", "MeinFrame", UIParentFake)' in detail and ':SetPoint("TOPLEFT", UIParentFake, "TOPLEFT", 12, -6)' in detail
    assert 'CreateTexture(nil, "ARTWORK", nil, 2)' in detail and 'SetTexture("Interface\\\\Foo\\\\Bar")' in detail, detail
    # Kalender-Popup: Eingabemaske füllt von links, gültige Eingabe wird übernommen, Ungültiges nicht.
    cal = lua.eval('''function(sd, st, ed, et)
        local C = BugLab:GetModule("Console")
        C:OpenCalendar(UIParent)
        local c = C.calendar
        c.sd.SetDigits(sd); c.st.SetDigits(st); c.ed.SetDigits(ed); c.et.SetDigits(et)
        C:OnCalendarInput(c.sd)
        C:ApplyCalendarInput()
        return c.sd.digits .. "|" .. tostring(C.state.range) .. "|" .. tostring(C.state.from and true or false)
            .. "|" .. (C.state.to and C.state.from and (C.state.to - C.state.from) or 0)
    end''')
    r = cal("1003", "0000", "", "1200")
    assert r.startswith("1003|all|false"), r  # unvollständiges Datum wird nicht übernommen
    r = cal("01032026", "0000", "03032026", "1200")
    assert r.startswith("01032026|custom|true|") and r.endswith(str(2 * 86400 + 12 * 3600 + 59)), r
    r = cal("01032026", "0800", "", "0900")
    assert r.startswith("01032026|custom|true|") and r.endswith(str(3600 + 59)), r  # ein Datum = ein Tag
    # Zwei Klicks im Kalender: Start, dann Ende (auch rückwärts); die Felder zeigen beide Tage.
    r = lua.eval('''function()
        local C = BugLab:GetModule("Console")
        C:OpenCalendar(UIParent)
        C:PickDay(time({ year = 2026, month = 3, day = 5, hour = 0 }))
        C:PickDay(time({ year = 2026, month = 3, day = 2, hour = 0 }))
        return C.calendar.sd.digits .. "|" .. C.calendar.ed.digits .. "|" .. tostring(C.calendar.pending)
    end''')()
    assert r == "02032026|05032026|false", r
    lua.execute('BugLab:GetModule("Console"):ClearFilters()')
    r = cal("30022026", "0000", "", "1200")
    assert "|all|false" in r, r  # ungültiges Datum
    r = cal("01032026", "2500", "", "1200")
    assert "|all|false" in r, r  # ungültige Uhrzeit
    r = cal("02032026", "0000", "01032026", "1200")
    assert "|all|false" in r, r  # Ende vor Start
    lua.execute('BugLab:GetModule("Console"):ClearFilters()')
    lua.execute('BugLab:OnSlashCommand("hilfe")')
    n = len(g.CHAT)
    assert n >= 3 and any("/bl|r" in v for v in g.CHAT.values()) and any("/buglab pick" in v for v in g.CHAT.values()), list(g.CHAT.values())
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
    check_local_order()
    for loc in ("enUS", "deDE"):
        run(loc)
    sys.exit(0)
