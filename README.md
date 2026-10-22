<p align="center">
  <img src="documentation/assets/BugLab_Header_hell.png" alt="BugLab: Debugging Toolkit for WoW Forever">
</p>

# README.md

[![latest](https://img.shields.io/github/v/release/N3zr0k/BugLab?include_prereleases&sort=date&label=latest)](https://github.com/N3zr0k/BugLab/releases) [![last push](https://img.shields.io/github/last-commit/N3zr0k/BugLab/main?label=last%20push)](https://github.com/N3zr0k/BugLab/commits/main) [![CI](https://img.shields.io/github/actions/workflow/status/N3zr0k/BugLab/ci.yml?branch=main&label=CI)](https://github.com/N3zr0k/BugLab/actions/workflows/ci.yml)

BugLab ist ein modulares Debugging- und Analysewerkzeug für World-of-Warcraft-Addon-Entwickler (WoW Forever / Classic-Beta-Client).

## Module

| Modul | Aufgabe | Status |
|---|---|---|
| Console | Debug-Meldungen sammeln, filtern und darstellen | geplant |
| Inspector | UI-Frames, Eigenschaften, Hierarchien und Zustände untersuchen | geplant |
| Gallery | Texturen und Atlanten als Vorschau durchsuchen, Ausschnitt im Textur-Editor des Inspectors | in Arbeit |
| Probe | Von Addons angemeldete Tests (Probes) starten, Probe-Log | in Arbeit |
| Database | SavedVariables geladener Addons als Baum ansehen (nur lesend), suchen, als Lua-Text kopieren | in Arbeit |

## Installation

Den Ordner `BugLab` in `Interface/AddOns` des Spielclients kopieren.

## Bedienung

- `/buglab` oder `/bl` öffnet bzw. schließt das BugLab-Fenster (Reiter Console, Inspector, Gallery, Probe, Database; Reiter deaktivierter Module sind ausgeblendet).
- Minimap-Button: Linksklick öffnet das Fenster, Rechtsklick die Einstellungen, Ziehen verschiebt ihn. Ein Eintrag im Addon-Menü an der Minimap öffnet das Fenster ebenfalls.
- Strg+Umschalt+Alt+R lädt die Oberfläche neu (wie `/reload`); unter Allgemein abschaltbar.
- `/buglab help` bzw. `/buglab hilfe` listet alle Befehle.
- Die Einstellungen (Übersicht, Allgemein, Profile) liegen unter Spiel-Menü > Optionen > AddOns > {BugLab}.

## Lizenz

Alle Rechte vorbehalten, siehe `LICENSE`. Enthaltene Libraries (Ace3) stehen unter ihren eigenen Lizenzen.
