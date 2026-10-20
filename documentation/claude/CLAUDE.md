# CLAUDE.md

Diese Datei gibt Claude Code Orientierung für die Arbeit in diesem Repository.

## Sprache
- Kommunikation auf Deutsch.



## Git
- Kein `Co-Authored-By: Claude` in Commit-Nachrichten.
- Commits laufen unter meiner eigenen Git-Identität – keine Identität setzen oder ändern.
- README.md auf Deutsch, dürfen ausführlich und gut strukturiert sein.
- CHANGELOG.md auf Englisch, kurz nur wichtige Änderungen (Bugfixes werden extra dokumentiert in BUGFIX.md), eine Zeile pro Änderung.
- DEVELOPER.md Es gibt eine Developer-README (Funktionen, API Beschreibung, Erweitern als Modul oder als eigenes Addon) – bei API-Änderungen mitpflegen.


## Code
- Keinen Code 1:1 aus fremden Projekten/Addons übernehmen. Ansatz und Idee dürfen übernommen werden, die Umsetzung ist eigener Code.
- Bevor ein neuer Baustein gebaut wird: prüfen, ob es eine etablierte Library gibt, die das kann oder dabei hilft. Ergebnis kurz nennen, bevor selbst implementiert wird.
- Kommentare im Entwickler-Stil: knapp, sachlich, erklären das *Warum*. Keine Füllkommentare, die nur wiederholen, was der Code tut.

## Umgebung
- Entwicklung unter Windows.
- Repos: `C:\Users\N3zr0k\Documents\Development\WoW\Addons`
- Spielclient-AddOns: `D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns` (Repo-Ordner per Junction verlinkt)
- Getestet wird in der WoW-Forever-Beta (nur bis Level 30 spielbar – Inhalte darüber sind nicht testbar).
- Der Spielclient ist deutschsprachig.

# Verzeichnisstruktur
- `<AddOn_Name>/` – Addon alle benötigen InGame Addon Dateien (Das eigentliche Addon, welches ins Interface/AddOn Verzeichnis kopiert wird.)
    - `<AddOn_Name>.toc` – Addon-Metadaten; Quelle für Version und Infos (nicht im Code duplizieren)
    - `Libs.xml` – lädt alle Libraries; neue Libs nur hier eintragen
    - `Libs/` – eingebundene Libraries (Ace3 unter `Libs/Ace3`, weitere wie HereBeDragons, LibQTip …); nicht bearbeiten
    - `Locales/` – eine Datei pro Sprache (`deDE`, `enUS`); neue Texte immer in beiden Dateien
    - `Core/` – alle Lua-Dateien des Addons außer Locales und Modulen (`Core.lua`, `Options.lua`, `Commands.lua`); Unterordner `Core/API/` enthält alle APIs; `Core/Launcher/` enthält die Einstiegspunkte (Minimap-Button, Addon-Menü)
    - `<Core.lua>` – Initialisierung, Addon-Objekt, gemeinsame Helfer (Debug, ID-/Methodenprüfung)
    - `<Options.lua>` – Einstellungen mit den Tabs Übersicht, Allgemein, Profile
    - `<Commands.lua>` – Slash-Befehle; neue Befehle hier ergänzen
    - `<Modules/>` – interne Module, jedes Modul in einem eigenen Ordner (`Modules/Console/`, `Modules/Inspector/`, `Modules/Probe/`)
    - `Media/` – selbst gezeichnete Icons (TGA); Blizzard-Artwork wird nicht hineinkopiert
- `.github/workflows/` – CI: Lint, ZIP-Build, Release und CurseForge-Upload
- `README.md` – Nutzer-Doku (ausführlich)
- `CHANGELOG.md` – eine Zeile pro Änderung
- `documentation/` – Ordner Dokumentationen. Badges, CurseForge Text Vorlagen für alle benötigten Bereiche in de und en
    - `<DEVELOPER.md>` – Entwickler-Doku im Ordner Docs/
    - `<API.md>` – API-Doku im Ordner Docs/
- `documentation/assets/` – Ordner für Artwork, welches auf CurseForge, als Vorlage für TGAs oder in der ReadMe verwendet wird.
- `LICENSE` – MIT Lizenz
- `.pkgmeta` 

## Versionierung & Dateien
- ZIP-Namen immer mit Version: `<AddOn_Name>_<AddOn_Erweiterung>_Repo_<version>.zip` (z. B. `BugLab_Helper_Repo_0.1.14-alpha.1.zip`).
- `x.y.z-alpha.N`
- `x` → Major (wird nur von mir freigegeben und angesagt)
- `y` → Minor (wird nur von mir freigegeben und angesagt)
- `z` → Fix (zählt mit jedem neuen Repo Zip hoch, wenn sich am Addon Game Ordner etwas ändert)
- `alpha` → alpha, beta (wird nur von mir freigegeben und angesagt)
- `N` → Repo (zählt mit jedem neuen Repo Zip hoch, wenn sich am Repo Ordner etwas ändert, GameOrdner ist ausgenommen)
- Aufbau des Repo-ZIPs: ein Wurzelordner `BugLab/` mit dem gesamten Repo (README, CHANGELOG, `documentation/`, `tests/`, LICENSE, `.pkgmeta`) und darin der Addon-Ordner `BugLab/BugLab/`. Nichts liegt lose im Archiv-Root.
- TOC-Vorgaben: `## SavedVariables: BugLabSettings`, `## Category: Development Tools` (nur deDE als Übersetzung), `## X-Curse-Project-ID: 1755124`, `## X-Website: https://github.com/N3zr0k/BugLab`, `## X-License: MIT`.

## Befehle / Release
- Lint: `<Lint-Befehl eintragen>`
- Release läuft über GitHub Actions: Ist die TOC-Version neu und die Pipeline grün, erstellt CI Tag + Release und lädt nach CurseForge hoch.
- Release-Stufe ergibt sich aus der TOC-Version:
  - `x.y.z-alpha.N` → Prerelease (kein CurseForge)
  - `x.y.z-beta.N` → normales Release, im Titel als Beta markiert (kein Prerelease)
  - `x.y.z` → normales Release

## Lokalisierung
- Getrennte Dateien pro Sprache, mindestens `deDE` und `enUS`; Spracherkennung über den Client.
- Jeder neue Text bekommt in **beiden** Sprachen einen Eintrag.

## Architektur
- Ace3 liegt lokal unter `Libs/Ace3`; geladen über `Libs.xml`. 
- Zusätzlich getestete Libraries (laufen im Forever-Client): HereBeDragons-2.0, LibSerialize, LibDeflate, CallbackHandler-1.0, LibQTip-1.0, LibDataBroker-1.1, LibDBIcon-1.0.
- Erweiterungsmodell: intern als Modul oder extern als eigenes Addon (Prinzip wie bei Scrap/DBM).
- Addon-Infos (Version etc.) werden aus der TOC gelesen, nicht im Code dupliziert.
- Slash-Befehle in eigener Lua-Datei, einfach erweiterbar. Es sollen aber bewusst nur sehr wenige Befehle existieren.
- Konfiguration im XML-Format. die TOC lädt nur ein XML.

## Design Guidelines
@documentation/BugLab_DESIGN_GUIDELINES.md

## Wichtig / Nicht tun
- Keinen Code 1:1 aus anderen Addons (z. B. Fishing Buddy, GatherMate2) übernehmen – nur Ansatz/Idee.
- Vor jedem neuen Baustein prüfen, ob es eine Library dafür gibt.
- Ingame-Oberflächen nutzen soweit möglich Spielgrafiken (Atlanten, Standardrahmen, Standardtexturen), nicht selbst gezeichnete. Eigene TGA-Icons nur für Logo und Modul-Icons. Blizzard-Artwork wird nie in eigene Icons oder Grafiken kopiert.
- `.git` – Verzeichnis wir nicht mit in das REPO ZIP gepackt
- Nicht selbstständig einen Build erstellen. Immer Fragen! Auswahl zum anklicken.
