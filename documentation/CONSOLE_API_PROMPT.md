# Prompt: BugLab-Console-API in ein anderes Addon einbauen

Diesen Text einer KI oder einem Entwickler geben, damit ein Addon BugLab als Debug-Ausgabe nutzt.

---

Binde in dieses WoW-Addon (Lua 5.1, Forever/Classic) die Console-API des Addons BugLab ein. BugLab ist optional: das Addon muss auch ohne BugLab fehlerfrei laufen, also nie hart davon abhängen und immer prüfen, ob das globale Objekt `BugLab` existiert.

Regeln:
1. Lege am Anfang der Hauptdatei einen Logger an, der ohne BugLab zu einer leeren Attrappe wird:
```lua
local log = BugLab and BugLab:GetLogger("MeinAddon") -- Quellenname = Addonname, Untermodule als "MeinAddon:Modul"
local function Log(level, fmt, ...)
    if log then log[level](log, fmt, ...) end
end
```
2. Beim Anmelden (Event `PLAYER_LOGIN`) einmal melden: `if log then log:Announce({ version = "<Addon-Version>", debug = <true/false, ob der Debug-Modus des Addons aktiv ist> }) end`. Das erzeugt eine Debug-Zeile "Angemeldet, Version X, Debug aktiviert/deaktiviert". Ohne `version` liest BugLab sie aus der TOC.
3. Ersetze vorhandene `print`-Debugausgaben durch `Log("Debug", ...)`. Stufen: `Debug`, `Info`, `Warn`, `Error`, `Fatal`. Das Format ist `string.format`; eingesetzte Werte erscheint in BugLab automatisch blau, Werte also immer über `%s`/`%d` einsetzen, nicht per `..` verketten.
4. Tabellen ausgeben mit `log:Dump(tabelle, "Beschriftung")` (optional `level`, `{ depth = 3, maxLines = 100 }`).
5. Zähle keine Zeilen selbst: BugLab drosselt automatisch (Standard 30 Zeilen pro Sekunde und Quelle). Logge trotzdem nicht in jedem Frame (`OnUpdate`).
6. Die Mindeststufe lässt sich mit `log:SetLevel("WARN")` anheben und der Logger mit `log:SetEnabled(false)` abschalten, z. B. passend zur Debug-Option des Addons.
7. Eigene Chat-Ausgaben des Addons nicht ändern, nur Debug- und Fehlermeldungen umleiten.

Schreibe kein eigenes Logging-System, sondern nur diese API: `BugLab:GetLogger(name)`, `log:Announce`, `log:Debug/Info/Warn/Error/Fatal`, `log:Dump`, `log:SetLevel`, `log:SetEnabled`. Die vollständige Beschreibung steht in `documentation/CONSOLE_API.md` von BugLab.
