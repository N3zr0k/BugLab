# BugLab – Developer

## Aufbau
- `BugLab/BugLab.toc` lädt nur `BugLab.xml`; dort stehen Libs, Locales, Core, Options, Commands und Module in dieser Reihenfolge. Die Lua-Dateien Core, Options und Commands liegen in `BugLab/Core/`, alle APIs in `BugLab/Core/API/`.
- Version und Infos werden aus der TOC gelesen (`BugLab:GetMeta(field)`).
- Globales Addon-Objekt: `BugLab` (AceAddon, AceEvent, AceConsole). Datenbank: `BugLab.db` (AceDB, SavedVariable `BugLabSettings`).

## API (Stand 0.1.47-alpha.1)
Console-API ausführlich: `CONSOLE_API.md`, Probe-API: `PROBE_API.md`.

| Funktion | Beschreibung |
|---|---|
| `BugLab:Print(msg)` | Chat-Ausgabe mit farbigem `{BugLab}`-Präfix |
| `BugLab:Debug(...)` | Ausgabe nur bei aktivierter Debug-Option |
| `BugLab:GetMeta(field)` | TOC-Feld lesen |
| `BugLab:OpenOptions()` | Einstellungen öffnen |
| `BugLab:ShowWindow()`, `HideWindow()`, `ToggleWindow()` | Hauptfenster steuern (`Core/API/Window.lua`) |
| `BugLab:SetMinimapButtonShown(bool)` | Minimap-Button (LibDBIcon, Name `BugLab`, Standardrahmen entsättigt) ein- oder ausblenden (`Core/Launcher/Minimap.lua`) |
| `BugLab:GetPage(name)` | leerer Container (Frame) des Modulreiters (`Console`, `Inspector`, `Gallery`, `Probe`, `Database`), hier baut das Modul seine Oberfläche |
| `BugLab:IsBugSackAvailable()`, `OpenBugSack()`, `GetBugSackCount()` | optionale Anbindung an BugSack/BugGrabber (`Core/Integrations/BugSack.lua`) |
| `BugLab:Log(source, text, level)` | meldet eine Zeile an die Console (Historie plus Chatfenster); `source` = Modul- oder Addonname, auch aus fremden Addons nutzbar; `level` = `"DEBUG"`, `"INFO"` (Standard), `"WARN"`, `"ERROR"` oder `"FATAL"` (`Core/API/Log.lua`) |
| `BugLab:GetLogger(source)` | Logger je Addon (gleicher Name = gleiches Objekt): `log:Debug/Info/Warn/Error/Fatal(fmt, ...)`, `log:Dump(wert, label, level, opts)`, `log:SetLevel(level)`, `log:SetEnabled(bool)` (`Core/API/Log.lua`) |
| `BugLab:FormatMessage(fmt, ...)` | wie `string.format`, eingesetzte Werte erscheinen in BugLab-Blau (`Core/API/Dump.lua`) |
| `BugLab:DumpLines(value, opts)` | Tabelle als eingerückte Zeilen, `opts.depth` (3) und `opts.maxLines` (100), Zyklenschutz |
| Drosselung | höchstens `logRateLimit` Zeilen pro Sekunde und Quelle (Standard 30, 0 = aus); überzählige Zeilen werden verworfen, danach folgt eine Warnung mit der Anzahl |
| Textfarben der Stufen | Debug `#999999`, Info ungefärbt, Warn `#FFD100`, Error `#FF4040`, Fatal `#FF1A1A` |
| `BugLab:GetHistory()`, `PruneHistory()`, `ClearHistory()`, `GetLogSources()` | Historie lesen und pflegen; Aufbewahrung in Tagen über die Option `historyDays` (Standard 30) |
| `BugLab:FormatEntry(entry)`, `FormatSource(name)`, `FormatDay(stamp)` | Darstellung `[HH:MM:SS] {Käfer Name} Text` und Datumszeile |
| `BugLab:ParseFilter(text)`, `MatchesFilter(terms, line)` | Textfilter: Wort muss vorkommen, `-Wort` und `-"Phrase"` schließen aus (`Core/API/Filter.lua`) |
| `BugLab:InTimeRange(key, stamp, now)` | Zeitraum-Voreinstellungen `hour`, `today`, `day`, `week`, `all` |
| Nachricht `BUGLAB_LOG` | AceEvent-Nachricht bei jeder neuen Zeile, Argument: der Eintrag `{t, s, m, i, l}` (`l` = Stufe 1–5) |
| `BugLab:DescribeObject(obj)`, `FormatObjectInfo(info)`, `ExportLua(obj)` | Inspector: Frame, Textur oder Schrift auslesen (Größe, Anker, Texturdaten, Skripte, Kinder), als farbige Zeilen darstellen oder als Lua-Nachbau ausgeben (`Core/API/Inspect.lua`) |
| `BugLab:ObjectName(obj)`, `ObjectOwner(obj)`, `IsBlizzardObject(obj)` | Anzeigename (`Elternname.Schlüssel`) und Herkunft: `Blizzard`, Addonname, `BugLab` oder `?`; `Core/Snapshot.lua` ordnet Frames beim Laden dem Addon zu |
| `BugLab:CanEditObject(obj)`, `ApplyEdit(obj, field, value)`, `ResetEdit(obj)` | eigene Frames ändern (`x`, `y`, `width`, `height`, `alpha`, `scale`); Blizzard-Frames und geschützte Frames im Kampf werden abgelehnt |
| `BugLab:GetObjectsUnderMouse(ignore)` | alle sichtbaren Frames und Bereiche unter der Maus, oberster zuerst |
| `BugLab:RegisterProbe(addon, key, def)`, `StartProbe`, `StopProbe`, `GetProbes` | Probes anmelden und steuern, Details in `PROBE_API.md` (`Core/API/Probe.lua`); `GetHistory("probe")` liest das Probe-Log |
| `BugLab:GetVisibleModules()` | aktivierte Module in Reihenfolge der Reiter |
| `BugLab:HandleReloadKey(key)` | Tastenlogik für Strg+Umschalt+Alt+R = `ReloadUI()` (`Core/Reload.lua`) |
| `BugLab:ModuleName(name)` | farbiger Modulname (`Bug` weiß, Rest BugLab-Blau) |
| `BugLab:IsModuleEnabled(name)`, `SetModuleEnabled(name, bool)` | Modul-Schalter pro Profil |
| `BugLab.COLORS`, `BugLab.NAME_COLORED`, `BugLab.MEDIA_PATH` | zentrale Palette, Namens-String, Medienpfad |

## Module
Interne Module liegen je in einem eigenen Ordner unter `BugLab/Modules/` (Console, Inspector, Gallery, Probe, Database) und werden in `Modules/Modules.xml` eingetragen. Externe Module als eigenes Addon folgen mit der Modul-Schnittstelle.

## Tests ohne Spielclient
`pip install lupa && python3 -I tests/run_addon.py` lädt das Addon in einer simulierten WoW-Umgebung (Lua 5.1), prüft Ladereihenfolge, Lifecycle, Optionstabelle, Slash-Befehl und beide Locales. Die WoW-API ist nur gestubbt, das Rendering wird nicht geprüft.

## CI/CD (GitHub Actions)

Datei: `.github/workflows/ci.yml`. Jeder Push und Pull Request durchläuft Lint (luacheck, Konfiguration `.luacheckrc`), die Logiktests (`tests/run_addon.py`) und den ZIP-Bau.

Auf dem Standardbranch erstellt die Pipeline zusätzlich ein Release, wenn die TOC-Version noch keinen Tag `v<version>` hat. Die Stufe stammt aus der TOC-Version:

| Version | GitHub | CurseForge |
|---|---|---|
| `x.y.z-alpha.N` | Prerelease | nein |
| `x.y.z-beta.N` | Release (Beta) | Beta |
| `x.y.z` | Release | Release |

Die Release-Beschreibung ist der Abschnitt der Version aus `CHANGELOG.md`. Für den CurseForge-Upload braucht das Repository das Secret `CURSEFORGE_API_TOKEN` und die Variable `CURSEFORGE_GAME_VERSION_ID` (ID der Forever-Beta-Spielversion).

