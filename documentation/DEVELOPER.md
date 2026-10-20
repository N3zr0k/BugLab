# BugLab – Developer

## Aufbau
- `BugLab/BugLab.toc` lädt nur `BugLab.xml`; dort stehen Libs, Locales, Core, Options, Commands und Module in dieser Reihenfolge. Die Lua-Dateien Core, Options und Commands liegen in `BugLab/Core/`, alle APIs in `BugLab/Core/API/`.
- Version und Infos werden aus der TOC gelesen (`BugLab:GetMeta(field)`).
- Globales Addon-Objekt: `BugLab` (AceAddon, AceEvent, AceConsole). Datenbank: `BugLab.db` (AceDB, SavedVariable `BugLabSettings`).

## API (Stand 0.1.8-alpha.1)
| Funktion | Beschreibung |
|---|---|
| `BugLab:Print(msg)` | Chat-Ausgabe mit farbigem `{BugLab}`-Präfix |
| `BugLab:Debug(...)` | Ausgabe nur bei aktivierter Debug-Option |
| `BugLab:GetMeta(field)` | TOC-Feld lesen |
| `BugLab:OpenOptions()` | Einstellungen öffnen |
| `BugLab:ShowWindow()`, `HideWindow()`, `ToggleWindow()` | Hauptfenster steuern (`Core/API/Window.lua`) |
| `BugLab:SetMinimapButtonShown(bool)` | Minimap-Button (LibDBIcon, Name `BugLab`, Standardrahmen entsättigt) ein- oder ausblenden (`Core/Launcher/Minimap.lua`) |
| `BugLab:GetPage(name)` | leerer Container (Frame) des Modulreiters `Console`, `Inspector` oder `Probe`, hier baut das Modul seine Oberfläche |
| `BugLab:GetVisibleModules()` | aktivierte Module in Reihenfolge der Reiter |
| `BugLab:HandleReloadKey(key)` | Tastenlogik für Strg+Umschalt+Alt+R = `ReloadUI()` (`Core/Reload.lua`) |
| `BugLab:ModuleName(name)` | farbiger Modulname (`Bug` weiß, Rest BugLab-Blau) |
| `BugLab:IsModuleEnabled(name)`, `SetModuleEnabled(name, bool)` | Modul-Schalter pro Profil |
| `BugLab.COLORS`, `BugLab.NAME_COLORED`, `BugLab.MEDIA_PATH` | zentrale Palette, Namens-String, Medienpfad |

## Module
Interne Module liegen je in einem eigenen Ordner unter `BugLab/Modules/` (Console, Inspector, Probe) und werden in `Modules/Modules.xml` eingetragen. Externe Module als eigenes Addon folgen mit der Modul-Schnittstelle.

## Tests ohne Spielclient
`pip install lupa && python3 -I tests/run_addon.py` lädt das Addon in einer simulierten WoW-Umgebung (Lua 5.1), prüft Ladereihenfolge, Lifecycle, Optionstabelle, Slash-Befehl und beide Locales. Die WoW-API ist nur gestubbt, das Rendering wird nicht geprüft.
