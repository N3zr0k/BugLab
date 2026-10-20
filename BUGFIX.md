# Bugfixes

## 0.1.12-alpha.1
- **`BugLab:Debug` überschrieben:** Die Kurzformen der Log-API (`BugLab:Debug/Info/Warn/Error/Fatal`) ersetzten die interne
  Diagnose-Funktion `BugLab:Debug` aus `Core.lua`. Der Aufruf in `Compartment.lua` hätte dadurch eine falsche Zeile
  geloggt statt eine Debugmeldung zu drucken. Die Kurzformen gibt es jetzt nur noch am Logger (`log:Warn(...)`).

## 0.1.11-alpha.1
- **Console.lua:187 "attempt to call a nil value"** beim Öffnen der Console-Seite.
  Ursache: `Desaturate` und `Button` waren als lokale Funktionen weiter unten definiert als ihre erste Verwendung,
  Lua las deshalb eine nicht vorhandene globale Variable.
  Behebung: Definitionen nach oben verschoben. `tests/run_addon.py` prüft jetzt in allen Addon-Dateien, dass lokale
  Funktionen und Variablen nicht vor ihrer Definition benutzt werden (der Teststub hatte den Fehler zuvor verdeckt).
