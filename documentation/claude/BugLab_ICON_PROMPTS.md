# BugLab Icon Prompts

Diese Datei enthält wiederverwendbare Prompt-Vorlagen für die Erstellung von Icons im Stil von **BugLab**.

Die Prompts orientieren sich an den festgelegten Designrichtlinien:

- reduzierter, technischer Stil
- klare, flache Formen
- kein Rahmen
- kein realistischer Look
- keine Verläufe
- keine 3D-Effekte
- transparente Hintergründe
- geeignet für kleine Größen in der WoW-UI
- konsistente Formensprache passend zum BugLab-Logo

---

## 1. Ziel des Icon-Systems

Die Icons sollen wie Teil derselben **BugLab-Produktfamilie** wirken.

Sie müssen:

- sich visuell am BugLab-Logo orientieren
- für World of Warcraft Addons geeignet sein
- in kleinen Größen wie **32x32 px** und **64x64 px** gut lesbar bleiben
- dieselbe technische, ruhige und professionelle Designsprache teilen

---

## 2. Verbindliche BugLab-Farbpalette

### Primärfarbe
- **BRIGHTBLUE_FONT_COLOR**
- Hex: `#66BBFF`
- RGB: `0.400, 0.733, 1.000`
- Verwendung: Hauptsymbol, Fokusbereiche, primäre Akzente

### Sekundäre helle Farbe
- **LIGHTGRAY_FONT_COLOR**
- Hex: `#999999`
- Verwendung: Hinweise, sekundäre Formen, unterstützende Details

### Standard-Grau
- **GRAY_FONT_COLOR**
- Hex: `#808080`
- Verwendung: neutrale technische Elemente, Standarddetails

### Dunkelgrau
- **DARKGRAY_COLOR**
- Hex: `#404040`
- Verwendung: dunkle Linien, deaktivierte Elemente, technische Tiefe

### Weiß
- Hex: `#FFFFFF`
- Verwendung: sparsame Hervorhebungen, Kontrastpunkte

### Farbnutzungsregeln
- Verwende **#66BBFF** als primäre visuelle Leitfarbe.
- Verwende **#999999** und **#808080** für sekundäre Elemente.
- Verwende **#404040** für dunkle Kontraste und strukturierende Details.
- Verwende **#FFFFFF** nur sparsam.
- Nutze **kein buntes Farbschema**.
- Nutze **keine Verläufe**.

---

## 3. Master-Prompt

```text
Erstelle ein einzelnes Icon für das World-of-Warcraft-Addon „BugLab“.

Das Icon muss sich klar am bestehenden BugLab-Logo orientieren und dieselbe visuelle Designsprache verwenden.

## Stilvorgaben
- minimalistischer, klarer, technischer Stil
- flache, saubere Formen
- kein realistischer Look
- keine Verläufe, keine 3D-Effekte, keine Glanzeffekte
- keine überflüssigen Verzierungen
- klare, gut lesbare Silhouette
- geeignet für kleine Größen in der WoW-UI
- modernes Addon-/Debug-Tool-Design
- sauberer, ruhiger, professioneller Gesamteindruck

## Bezug zum BugLab-Logo
- Das Icon muss sich visuell am BugLab-Logo orientieren.
- Die Formensprache soll zum BugLab-Käferlogo passen.
- Der Look soll wie Teil derselben Produktfamilie wirken.
- Wenn ein Käfer-Element verwendet wird, dann in derselben reduzierten, einfachen Formensprache.
- Kein Rahmen.
- Transparenter Hintergrund.

## Farbpalette
Verwende nur diese Farben oder sehr nahe Nuancen davon:
- BRIGHTBLUE_FONT_COLOR: #66BBFF
- LIGHTGRAY_FONT_COLOR: #999999
- GRAY_FONT_COLOR: #808080
- DARKGRAY_COLOR: #404040
- WHITE: #FFFFFF

## Farbverwendung
- Hauptakzent und wichtigste Form: #66BBFF
- Sekundäre Formen und Hinweise: #999999 oder #808080
- dunkle Linien oder zurückhaltende Elemente: #404040
- Weiß nur sparsam zur Hervorhebung
- insgesamt reduzierte, kontrollierte Farbverteilung
- kein buntes Farbschema

## Komposition
- zentrierte Komposition
- klares Hauptsymbol
- gut erkennbar auch bei 32x32 oder 64x64 Pixel
- keine feinen, unnötig kleinen Details
- starke Lesbarkeit in kleiner Darstellung
- transparent freigestellt

## Inhalt
Gestalte ein Icon für folgendes Modul / Thema:
[HIER MODUL ODER SYMBOL EINSETZEN]

## Zusätzliche inhaltliche Vorgaben
Das Symbol soll folgende Bedeutung transportieren:
[HIER KURZE BESCHREIBUNG EINSETZEN]

## Ausgabe
- 1 einzelnes Icon
- quadratisches Format
- 512x512 px
- transparenter Hintergrund
- PNG
- keine Schrift im Icon, außer wenn ausdrücklich gefordert
```

---

## 4. Kurzversion

```text
Erstelle ein 512x512 px PNG-Icon mit transparentem Hintergrund für das WoW-Addon BugLab. Das Icon soll sich klar am bestehenden BugLab-Logo orientieren: minimalistischer, technischer, reduzierter Stil, flache Formen, keine Verläufe, keine 3D-Effekte, keine Verzierungen, kein Rahmen. Verwende nur die BugLab-Farbpalette: #66BBFF als Hauptfarbe, #999999 und #808080 für sekundäre Elemente, #404040 für dunkle Details, #FFFFFF nur sparsam. Das Icon muss auch in kleiner Größe gut lesbar sein und wie Teil derselben BugLab-Produktfamilie wirken. Thema des Icons: [THEMA]. Inhaltlich soll es [BESCHREIBUNG] darstellen.
```

---

## 5. Set-Regeln für mehrere Icons

Diesen Zusatztext an einen Prompt anhängen, wenn mehrere Icons im selben Stil erzeugt werden sollen:

```text
Alle Icons müssen wie ein zusammengehöriges Set wirken. Behalte über alle Icons hinweg dieselbe Strichstärke, dieselbe Formensprache, dieselbe Farbverteilung, dieselbe Detailtiefe und dieselbe visuelle Gewichtung bei. Jedes Icon soll ein anderes Thema darstellen, aber erkennbar zur gleichen BugLab-Familie gehören.
```

Zusätzliche Empfehlung:

```text
Wichtig: Das Icon muss in 32x32 px und 64x64 px klar lesbar bleiben.
```

---

## 6. Modul-Prompt: Console

```text
Erstelle ein 512x512 px PNG-Icon mit transparentem Hintergrund für das WoW-Addon BugLab. Das Icon soll sich klar am bestehenden BugLab-Logo orientieren: minimalistischer, technischer, reduzierter Stil, flache Formen, keine Verläufe, keine 3D-Effekte, keine Verzierungen, kein Rahmen. Verwende nur die BugLab-Farbpalette: #66BBFF als Hauptfarbe, #999999 und #808080 für sekundäre Elemente, #404040 für dunkle Details, #FFFFFF nur sparsam. Das Icon muss auch in kleiner Größe gut lesbar sein und wie Teil derselben BugLab-Produktfamilie wirken. Thema des Icons: Console. Das Icon soll Debug-Meldungen, Logging und Ausgaben symbolisieren. Verwende ein klares Symbol wie ein Terminalfenster, Sprech-/Ausgabeblöcke oder stilisierte Log-Zeilen in technischer Formensprache.
```

---

## 7. Modul-Prompt: Inspector

```text
Erstelle ein 512x512 px PNG-Icon mit transparentem Hintergrund für das WoW-Addon BugLab. Das Icon soll sich klar am bestehenden BugLab-Logo orientieren: minimalistischer, technischer, reduzierter Stil, flache Formen, keine Verläufe, keine 3D-Effekte, keine Verzierungen, kein Rahmen. Verwende nur die BugLab-Farbpalette: #66BBFF als Hauptfarbe, #999999 und #808080 für sekundäre Elemente, #404040 für dunkle Details, #FFFFFF nur sparsam. Das Icon muss auch in kleiner Größe gut lesbar sein und wie Teil derselben BugLab-Produktfamilie wirken. Thema des Icons: Inspector. Das Icon soll Frame-Analyse, UI-Untersuchung und Eigenschaftenprüfung symbolisieren. Verwende ein klares Symbol wie einen Frame, ein UI-Fenster, ein Fadenkreuz oder eine Lupe in schlichter technischer Form.
```

---

## 8. Modul-Prompt: Probe

```text
Erstelle ein 512x512 px PNG-Icon mit transparentem Hintergrund für das WoW-Addon BugLab. Das Icon soll sich klar am bestehenden BugLab-Logo orientieren: minimalistischer, technischer, reduzierter Stil, flache Formen, keine Verläufe, keine 3D-Effekte, keine Verzierungen, kein Rahmen. Verwende nur die BugLab-Farbpalette: #66BBFF als Hauptfarbe, #999999 und #808080 für sekundäre Elemente, #404040 für dunkle Details, #FFFFFF nur sparsam. Das Icon muss auch in kleiner Größe gut lesbar sein und wie Teil derselben BugLab-Produktfamilie wirken. Thema des Icons: Probe. Das Icon soll gezielte Überwachung, Analyse und Beobachtung von Daten oder Funktionen symbolisieren. Verwende ein klares Symbol wie eine Sonde, einen Marker, einen Zielpunkt oder ein technisches Scan-Element.
```

---

## 9. Empfohlene Einsatzweise

### Für ein einzelnes neues Icon
- Verwende den **Master-Prompt**
- ersetze `[HIER MODUL ODER SYMBOL EINSETZEN]`
- ersetze `[HIER KURZE BESCHREIBUNG EINSETZEN]`

### Für schnelle Tests
- verwende die **Kurzversion**

### Für ein vollständiges Icon-Set
- verwende den **Master-Prompt** oder Modul-Prompts
- ergänze die **Set-Regeln für mehrere Icons**

---

## 10. Beispiel für neue Module

### EventMonitor

```text
Erstelle ein 512x512 px PNG-Icon mit transparentem Hintergrund für das WoW-Addon BugLab. Das Icon soll sich klar am bestehenden BugLab-Logo orientieren: minimalistischer, technischer, reduzierter Stil, flache Formen, keine Verläufe, keine 3D-Effekte, keine Verzierungen, kein Rahmen. Verwende nur die BugLab-Farbpalette: #66BBFF als Hauptfarbe, #999999 und #808080 für sekundäre Elemente, #404040 für dunkle Details, #FFFFFF nur sparsam. Das Icon muss auch in kleiner Größe gut lesbar sein und wie Teil derselben BugLab-Produktfamilie wirken. Thema des Icons: EventMonitor. Das Icon soll die Überwachung von Spielereignissen symbolisieren. Verwende ein klares Symbol wie ein Signal, Wellen, einen Auslöser oder ein technisches Monitoring-Element.
```

### Performance

```text
Erstelle ein 512x512 px PNG-Icon mit transparentem Hintergrund für das WoW-Addon BugLab. Das Icon soll sich klar am bestehenden BugLab-Logo orientieren: minimalistischer, technischer, reduzierter Stil, flache Formen, keine Verläufe, keine 3D-Effekte, keine Verzierungen, kein Rahmen. Verwende nur die BugLab-Farbpalette: #66BBFF als Hauptfarbe, #999999 und #808080 für sekundäre Elemente, #404040 für dunkle Details, #FFFFFF nur sparsam. Das Icon muss auch in kleiner Größe gut lesbar sein und wie Teil derselben BugLab-Produktfamilie wirken. Thema des Icons: Performance. Das Icon soll Leistung, Messung und Analyse symbolisieren. Verwende ein klares Symbol wie ein Messinstrument, Balken, Aktivitätslinien oder ein technisches Performance-Symbol.
```

---

## 11. Wichtigste Kurzregeln auf einen Blick

- BugLab-Stil: **minimalistisch, technisch, reduziert**
- **kein Rahmen**
- **kein Verlauf**
- **kein 3D-Look**
- **transparenter Hintergrund**
- **gut lesbar bei 32x32 und 64x64**
- **#66BBFF ist die Leitfarbe**
- Icons müssen **wie ein konsistentes Set** wirken

