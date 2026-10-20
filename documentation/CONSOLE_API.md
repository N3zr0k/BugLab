# BugLab – Console-API

Mit der Console-API melden eigene und fremde Addons Zeilen an BugLab. Jede Zeile landet in der Historie (Reiter Console) und im Chatfenster, mit `{Käfer Addonname}` davor. Alles steht in `BugLab/Core/API/Log.lua` und `Dump.lua`; ein Addon braucht nur das globale Objekt `BugLab` (optional als Abhängigkeit prüfen: `if BugLab then ... end`).

## Schnellstart
```lua
local log = BugLab and BugLab:GetLogger("MeinAddon")
if log then
    log:Announce({ version = "1.0.0", debug = MeinAddonDB.debug }) -- einmal beim Start melden
    log:Info("Zone %s betreten", GetZoneText()) -- eingesetzte Werte erscheinen blau
    log:Warn("Wenig Platz: %d Slots", 3)
    log:Dump(MeineTabelle, "Einstellungen")      -- eingerückte Zeilen
end
```
Untermodule: Quelle `"MeinAddon:Kampf"` zeigt `{Käfer MeinAddon:Kampf}` (Modulteil grau).

## Funktionen
| Aufruf | Wirkung |
|---|---|
| `BugLab:Log(source, text, level)` | einzelne Zeile; `level` = `"DEBUG"`, `"INFO"` (Standard), `"WARN"`, `"ERROR"`, `"FATAL"` |
| `BugLab:GetLogger(source)` | Logger je Quelle (gleicher Name = gleiches Objekt) |
| `log:Debug/Info/Warn/Error/Fatal(fmt, ...)` | wie `string.format`; Werte in Blau |
| `log:Dump(wert, label, level, opts)` | Tabelle eingerückt; `opts.depth` (3), `opts.maxLines` (100), Zyklenschutz |
| `log:Announce({ version, debug })` | Anmeldung: einmal pro Sitzung eine Debug-Zeile „Angemeldet, Version X, Debug aktiviert/deaktiviert“; ohne `version` wird sie aus der TOC (`## Version`) gelesen. Empfohlen beim Start jedes Addons (z. B. in `PLAYER_LOGIN`) |
| `log:SetLevel(level)` | Mindeststufe dieses Loggers |
| `log:SetEnabled(bool)` | Logger ein- oder ausschalten |
| `BugLab:FormatMessage(fmt, ...)` | formatierter Text mit blauen Werten, ohne zu loggen |
| `BugLab:DumpLines(value, opts)` | die Dump-Zeilen als Liste |
| `BugLab:GetHistory()`, `PruneHistory()`, `ClearHistory()`, `GetLogSources()` | Historie lesen und pflegen |

## Stufen und Farben
Debug `#999999`, Info ungefärbt, Warn `#FFD100`, Error `#FF4040`, Fatal `#FF1A1A`.

## Getrennte Werte
Texte mit `|` oder `;` als Trenner (`"Version: 1.2 | Debug: an; Zone: Elwynn"`) werden abschnittsweise reihum eingefärbt (Blau, Grün, Gelb, Lila, Türkis, Orange, Rot), die Überschrift vor dem ersten Doppelpunkt etwas heller. Ein `|` zählt nur als Trenner, wenn es kein Escape des Spiels einleitet (`|c`, `|r`, `|T`, `|H`); `||` ist ein echtes `|`. Error und Fatal behalten ihre rote Farbe.

## Drosselung
Höchstens `logRateLimit` Zeilen pro Sekunde und Quelle (Standard 30, 0 = aus). Überzählige Zeilen werden verworfen, danach folgt eine Warnung mit der Anzahl. Dump-Zeilen werden nicht gedrosselt.

## Mitlesen
AceEvent-Nachricht `BUGLAB_LOG` bei jeder neuen Zeile, Argument: der Eintrag `{t, s, m, i, l}` (Zeit, Quelle, Text, Id, Stufe 1–5).

Historie: `historyDays` (Standard 30 Tage).
