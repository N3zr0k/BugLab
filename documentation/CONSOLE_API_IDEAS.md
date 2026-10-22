# Console-API: offene Ideen und Optionen zur Diskussion

Stand 0.1.47-alpha.1. Eingebaut sind: Logger pro Addon, Werte in Blau, Dump, Drosselung. Dieses Dokument erklärt die übrigen Ideen und die Optionstabelle `opts`, damit wir darüber entscheiden können.

## Offene Ideen

### Fehler einfangen (Idee 4)
**Was:** BugLab fängt Lua-Fehler und blockierte Aktionen (Taint) selbst ab und schreibt sie als Error oder Warn in die Historie, mit Stacktrace.
**Beispiel:** Ein Addon wirft `attempt to index nil value 'db'`. In der Historie steht `{Käfer MeinAddon} attempt to index nil value 'db'` in Rot, darunter die Aufrufkette. Tritt derselbe Fehler 12-mal auf, steht dort einmal „×12“.
**Haken:** Es gibt schon BugGrabber/BugSack. Zwei Fänger gleichzeitig können sich gegenseitig stören (beide setzen den Fehlerhandler). Deshalb wäre mein Vorschlag, bei vorhandenem BugGrabber dessen Callback `BugGrabber_BugGrabbed` zu nutzen und nur ohne BugGrabber selbst den Handler zu setzen.
**Aufwand:** mittel. **Risiko:** mittel (Fehlerhandler ist eine zentrale Stelle).

### Tags (Idee 5)
**Was:** Eine zweite Ebene unter der Quelle, zum Beispiel `Events`, `Netzwerk`, `UI`.
**Beispiel:** `log:Info("Events", "PLAYER_LOGIN")`. In der Historie gibt es einen weiteren Filter „Tag“, und ein Addon kann so seine Meldungen selbst gliedern.
**Haken:** Ein vierter Filter macht die Leiste voller. Alternative ohne neues Feld: der Tag steht im Text und wird mit dem Textfilter gefunden.
**Aufwand:** klein.

### Messen (Idee 6)
**Was:** Zeitmessung als Einzeiler.
**Beispiel:** `local stop = log:Timer("Zonenwechsel")` … später `stop()` schreibt `Zonenwechsel: 12.4 ms` (Dauer in Blau).
**Nutzen:** Brücke zum Probe-Modul, das später Messungen sammeln soll.
**Aufwand:** klein.

### Ohne harte Abhängigkeit (Idee 7)
**Was:** Heute muss ein fremdes Addon `_G.BugLab` prüfen. Mit einer winzigen Bibliothek `BugLabAPI-1.0` (über LibStub) kann ein Addon `LibStub("BugLabAPI-1.0", true)` fragen, ob es da ist, und bekommt immer ein gültiges Logger-Objekt zurück. Ist BugLab nicht installiert, tut der Logger nichts, und der Aufrufer braucht keine Prüfung.
**Nutzen:** sauberer Einstieg für andere Addons, kein Fehler ohne BugLab.
**Aufwand:** klein bis mittel.

### Abfragen und Export (Idee 9)
**Was:** `BugLab:Query(filterText, quelle, zeitraum, stufe)` liefert dieselben Zeilen wie das Fenster, damit andere Module sie lesen können. Dazu ein Export als Text, den man kopieren kann.
**Nutzen:** Der Inspector könnte die letzten Fehler einer Quelle zeigen. Für den Export gäbe es ein Fenster mit markierbarem Text.
**Aufwand:** klein für Query, mittel für Export.

### Testbefehl (Idee 10)
**Was:** `/buglab log warn MeinAddon Text` schreibt eine Zeile in die Historie, ohne Code zu schreiben.
**Nutzen:** Man sieht sofort, wie Farben und Filter wirken. Dein Wunsch, dass es nur wenige Befehle gibt, spricht aber dagegen.
**Aufwand:** klein.

## Optionen (`opts`) zum Diskutieren

Die Frage ist, wie ein Addon mehr als Quelle, Text und Stufe übergibt. Zwei Wege:
- **A:** vierter Parameter, eine Tabelle: `BugLab:Log(source, text, level, { tag = "Events", key = "login" })`.
- **B:** am Logger, ohne Tabelle: `log:With({ tag = "Events" }):Info("...")` oder eigene Methoden.
Ich bin für A bei `BugLab:Log` und für B-ähnliche Kürze bei Loggern. Das Feld bestimmt, ob es sich lohnt:

| Feld | Zweck | Beispiel | Meine Einschätzung |
|---|---|---|---|
| `tag` | Unterkategorie zum Filtern | `tag = "Events"` | sinnvoll, siehe Tags oben |
| `data` | angehängte Tabelle, in der Historie aufklappbar | `data = { id = 5 }` | nützlich, braucht aber Klick-Oberfläche in der Historie |
| `key` | Kennung, um gleiche Zeilen zu „×12“ zusammenzufassen | `key = "db-nil"` | sinnvoll zusammen mit Fehlerfang; ohne `key` könnte der Text selbst der Schlüssel sein |
| `target` | wohin die Zeile geht: beides, nur Historie, nur Chat | `target = "history"` | sinnvoll gegen Chat-Spam, kleiner Aufwand |
| `time` | eigener Zeitstempel | `time = ts` | selten nötig, nur für nachträgliche Meldungen |
| `link` | klickbarer Verweis in der Zeile (Frame im Inspector, Item, Spell) | `link = { frame = "PlayerFrame" }` | erst mit dem Inspector sinnvoll |
| `trace` | Stacktrace anhängen | `trace = true` | bei Error und Fatal automatisch, sonst selten |
| `color` | eigene Textfarbe statt Stufenfarbe | `color = "ff8800"` | würde ich weglassen, die Stufenfarben sollen einheitlich bleiben |

**Fragen an dich:**
1. Soll `opts` als vierter Parameter kommen (A), oder lieber nur über den Logger (B)?
2. Soll die Historie aufklappbare Zeilen können (für `data`), oder reicht Dump als mehrere Zeilen?
3. Soll ein Addon die Stufenfarbe überschreiben dürfen (`color`), oder bleiben Farben fest?
