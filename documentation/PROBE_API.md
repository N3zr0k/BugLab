# BugLab – Probe-API

Eine **Probe** ist ein Test oder Diagnose-Werkzeug eines Addons (z. B. "Leuchten 10 Sekunden zeigen", "Kalender-Feste auslesen"). Die Logik bleibt im Addon. Das Addon meldet die Probe bei BugLab an; BugLab liefert dafür den Reiter **Probe** (Addon wählen, Werte einstellen, Starten/Beenden), den Befehl `/buglab probe`, das **Probe-Log** (Langzeit, durchsuchbar wie die Console) und den Chatreiter **BugLab:Probes**.

BugLab meldet selbst eine Probe an (`BugLab lua-error`, "Hallo Lua Fehler": erzeugt einen harmlosen Lua-Fehler zum Testen von BugSack), deshalb ist der Reiter Probe immer sichtbar. BugLab ist für das Addon optional: ohne BugLab passiert nichts.

## Anmelden
```lua
if BugLab and BugLab.RegisterProbe then
    BugLab:RegisterProbe("MeinAddon", "glow", {
        title = "Leuchten",                       -- Anzeigename
        desc  = "Zeigt das Leuchten am Ring.",    -- optional, eine Zeile
        mode  = "toggle",                         -- "toggle" (Standard): Starten und Beenden; "once": nur ein Knopf "Ausführen"
        params = {                                -- optional; BugLab baut daraus die Eingabefelder
            { key = "farbe",  type = "color",  label = "Farbe", default = "ff0000" },
            { key = "modus",  type = "choice", label = "Modus", values = { "static", "pulse", "blink" } },
            { key = "sek",    type = "number", label = "Sekunden", default = 10 },
            { key = "laut",   type = "bool",   label = "Mit Ton" },
        },
        run  = function(ctx, p)                   -- Start: p.farbe, p.modus, p.sek, p.laut
            ctx.log:Info("Leuchten %s, %s, %s s", p.farbe, p.modus, p.sek)
            MeinAddon:ShowGlow(p.farbe, p.modus, p.sek)
        end,
        stop = function(ctx)                      -- optional: alles wieder abbauen
            MeinAddon:HideGlow()
        end,
    })
end
```
`run` und `stop` sind normale Funktionen des Addons. Mehrstufiges (Fenster öffnen, Timer, Events) baut die Probe selbst; `stop` räumt es auf. Fehler in `run` oder `stop` fängt BugLab ab und schreibt sie als Error ins Probe-Log. Eine laufende Probe wird beim erneuten Start zuerst beendet. Wer dieselbe Addon- und Probe-Kennung erneut anmeldet, ersetzt die alte Anmeldung.

## Art der Probe
- `mode = "toggle"` (Standard): die Probe läuft, bis sie beendet wird. Der Reiter zeigt **Starten** und **Beenden**, `stop` baut alles wieder ab (Leuchten, Timer, Fenster).
- `mode = "once"`: die Probe führt nur etwas aus und ist danach fertig (z. B. Kalender auslesen, Fehler auslösen). Der Reiter zeigt nur **Ausführen**, `stop` ist nicht nötig, und im Log steht "Ausgeführt" statt "Gestartet". Läuft `run` ohne Fehler durch, zeigt der Reiter 10 Sekunden einen grünen Haken neben **Ausführen**.

## Parameter
| `type` | Eingabe | Wert in `p` | Hinweise |
|---|---|---|---|
| `number` | Zahlenfeld | Zahl | Komma oder Punkt |
| `text` | Textfeld | Text | |
| `color` | Farbwähler + Textfeld | Text `rrggbb` (z. B. `ff0000`) | Klick auf das Farbfeld öffnet den Farbwähler; die Probe wandelt den Text selbst um |
| `choice` | Auswahl | einer der `values` | Pflicht: `values = { ... }` |
| `bool` | Haken | `true`/`false` | im Befehl `ja`/`nein`, `an`/`aus`, `1`/`0` |

Optionale Felder: `label` (Beschriftung), `default` (Standardwert; macht den Parameter optional), `optional = true`. Parameter ohne Standardwert sind Pflicht. Ein `text`-Parameter an letzter Stelle nimmt im Befehl den Rest der Eingabe.

## `ctx` in `run` und `stop`
| Feld | Bedeutung |
|---|---|
| `ctx.addon`, `ctx.key` | Kennung der Probe |
| `ctx.params` | dieselben Werte wie `p` |
| `ctx.log:Debug/Info/Warn/Error/Fatal(fmt, ...)` | Ausgabe ins Probe-Log, wie `string.format`; Werte erscheinen blau |
| `ctx.log:Dump(wert, label, level, opts)` | Tabelle eingerückt (`opts.depth` 3, `opts.maxLines` 100) |

Die Quelle im Log ist `Addon:probe` (Probe grau), BugLab schreibt beim Start "Gestartet" und beim Ende "Beendet".

## Befehle
- `/buglab probe` listet alle angemeldeten Probes.
- `/buglab probe MeinAddon glow ff0000, pulse 5` startet sie; Werte stehen in der Reihenfolge der `params`, getrennt durch Komma oder Leerzeichen, fehlende optionale Werte nehmen den Standard.
- `/buglab probe stop MeinAddon glow` beendet sie.

Das Addon braucht keinen eigenen Slash-Befehl für Probes.

## Weitere Funktionen
| Aufruf | Wirkung |
|---|---|
| `BugLab:HasProbes()` | ist mindestens eine Probe angemeldet |
| `BugLab:GetProbeAddons()`, `GetProbes(addon)`, `GetProbe(addon, key)` | angemeldete Probes lesen |
| `BugLab:StartProbe(addon, key, values)` | Start aus Code, gibt `ok, fehler` zurück |
| `BugLab:StopProbe(addon, key)` | Ende aus Code |
| `BugLab:IsProbeRunning(addon, key)` | läuft sie gerade |
| `BugLab:ParseProbeArgs(def, text)` | Befehlstext in Werte umwandeln |
| `BugLab:GetHistory("probe")`, `ClearHistory(source, "probe")`, `GetLogSources("probe")` | Probe-Log lesen und pflegen |
| Nachrichten | `BUGLAB_PROBE_REGISTERED(addon, key)`, `BUGLAB_PROBE_STATE(addon, key)`, `BUGLAB_PROBE_LOG(eintrag)` (AceEvent) |

## Probe-Log und Chat
Das Probe-Log hat eine eigene Historie (Aufbewahrung wie die Console, Option `historyDays`). Im Reiter Console wählt das Auswahlfeld "Log" vor der Quelle zwischen **Debug-Log** und **Probe-Log**; Suche, Quelle, Stufe, Zeitraum und Löschen gelten jeweils für das gewählte Log. Im Chat gibt es die Reiter `BugLab:Debug` und `BugLab:Probes`.

## Prompt für andere Addons
Alles unter der Linie kann einer KI oder einem Entwickler mitgegeben werden.

---

Baue die vorhandenen Dev- und Test-Befehle dieses WoW-Addons (Lua 5.1, Forever/Classic) als **Probes** für das optionale Addon BugLab um. Die Logik bleibt im Addon; das Addon meldet jede Probe nur an. BugLab ist optional: immer `if BugLab and BugLab.RegisterProbe then ... end`.

Pro Probe:
```lua
BugLab:RegisterProbe("<Addonname>", "<kurzer-schlüssel>", {
    title = "<Anzeigename>", desc = "<eine Zeile>",
    mode = "toggle|once",              -- toggle: Starten/Beenden (läuft weiter); once: nur "Ausführen" (läuft einmal durch)
    params = { { key = "...", type = "number|text|color|choice|bool", label = "...", default = ..., values = { ... } } },
    run  = function(ctx, p) ... end,   -- bisherige Befehlslogik, Werte in p
    stop = function(ctx) ... end,      -- optional: Anzeige oder Timer wieder abbauen
})
```
Regeln:
1. Jeder bisherige `/addon probe ...`-Unterbefehl wird eine Probe; Argumente werden `params` (Pflicht = ohne `default`). Eigene Slash-Befehle und eigene Dev-Fenster für das Starten und Protokollieren entfallen.
2. Ausgaben der Probe laufen über `ctx.log:Info/Warn/Error(fmt, ...)` und `ctx.log:Dump(tabelle, "Titel")`, nicht über `print`. Format wie `string.format`.
3. Befehle, die nur etwas ausführen und fertig sind, werden `mode = "once"`; alles, was weiterläuft, `toggle`. Was `run` anzeigt oder startet (Fenster, Leuchten, Timer, Events), muss `stop` wieder beenden; `stop` darf mehrfach aufgerufen werden.
4. Die Anmeldungen stehen in einer Datei (z. B. `Dev/Probes.lua`), die beim Laden des Addons einmal ausgeführt wird; Tests, die nur im Repo gebraucht werden, bleiben aus dem Release-ZIP heraus.
5. Keine Abhängigkeit von BugLab im TOC erzwingen (`## OptionalDeps: BugLab`).

Vollständige Beschreibung: `documentation/PROBE_API.md` von BugLab.
