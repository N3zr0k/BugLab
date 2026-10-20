# {BugLab}

BugLab ist ein modulares Debugging- und Analysewerkzeug für World-of-Warcraft-Addon-Entwickler (WoW Forever / Classic-Beta-Client).

## Module

| Modul | Aufgabe | Status |
|---|---|---|
| Console | Debug-Meldungen sammeln, filtern und darstellen | geplant |
| Inspector | UI-Frames, Eigenschaften, Hierarchien und Zustände untersuchen | geplant |
| Probe | Events, Funktionen und Variablen gezielt überwachen | geplant |

## Installation

Den Ordner `BugLab` in `Interface/AddOns` des Spielclients kopieren.

## Bedienung

- `/buglab` oder `/bl` öffnet bzw. schließt das BugLab-Fenster (Reiter Console, Inspector, Probe; Reiter deaktivierter Module sind ausgeblendet).
- Minimap-Button: Linksklick öffnet das Fenster, Rechtsklick die Einstellungen, Ziehen verschiebt ihn. Ein Eintrag im Addon-Menü an der Minimap öffnet das Fenster ebenfalls.
- Strg+Umschalt+Alt+R lädt die Oberfläche neu (wie `/reload`); unter Allgemein abschaltbar.
- `/buglab help` bzw. `/buglab hilfe` listet alle Befehle.
- Die Einstellungen (Übersicht, Allgemein, Profile) liegen unter Spiel-Menü > Optionen > AddOns > {BugLab}.

## Lizenz

MIT, siehe `LICENSE`. Enthaltene Libraries (Ace3) stehen unter ihren eigenen Lizenzen.
