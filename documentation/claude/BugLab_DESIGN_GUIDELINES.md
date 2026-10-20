# BugLab – Farbschema & Namensdarstellung

> Verbindliche Designvorgaben für das World-of-Warcraft-Addon **BugLab**. Bei neuen UI-Elementen, Debug-Ausgaben, Tooltips und Einstellungen dieses Farbschema konsistent verwenden.

## 1. Farbpalette

| Konstante | Hex | RGB (0–1) | Verwendung |
|---|---|---|---|
| `BRIGHTBLUE_FONT_COLOR` | `#66BBFF` | `0.400, 0.733, 1.000` | Akzente, Hervorhebungen, `Lab` im Addon-Namen |
| `LIGHTGRAY_FONT_COLOR` | `#999999` | `0.600, 0.600, 0.600` | Hinweise und sekundäre Texte |
| `GRAY_FONT_COLOR` | `#808080` | `0.502, 0.502, 0.502` | Standard-Grau für zurückhaltende Texte, geschweifte Klammern im Addon-Namen |
| `DARKGRAY_COLOR` | `#404040` | `0.251, 0.251, 0.251` | Dunkle/deaktivierte UI-Elemente |
| `WHITE_FONT_COLOR` | `#FFFFFF` | `1.000, 1.000, 1.000` | Normale helle Schrift, `Bug` im Addon-Namen |

Die Werte sind als feste Hex-Farben zu behandeln; keine Farbverläufe für diese Textfarben verwenden.

## 2. Verbindliche Anzeige des Addon-Namens

**Exakte Schreibweise:** `BugLab` (großes B und L).

**Visuelle Darstellung:** `{BugLab}` – ohne zusätzliche Leerzeichen.

| Bestandteil | Farbe | Hex |
|---|---|---|
| `{` und `}` | Grau | `#808080` |
| `Bug` | Weiß | `#FFFFFF` |
| `Lab` | Hellblau | `#66BBFF` |

**WoW-Farbstring:**

```lua
local BUGLAB_NAME_COLORED = "|cff808080{|r|cffffffffBug|r|cff66bbffLab|r|cff808080}|r"
```

Beispiel für eine Chat-Ausgabe:

```lua
DEFAULT_CHAT_FRAME:AddMessage(BUGLAB_NAME_COLORED .. " |cff999999Debug aktiviert|r")
```

In WoW-Strings `|cffRRGGBB` zum Starten einer Farbe und `|r` zum Zurücksetzen verwenden. Die eingefärbte Namensform für Chat-Meldungen, Debug-Ausgaben und sonstige Stellen nutzen, an denen WoW-Farbcodes unterstützt werden. Für Dateinamen, Addon-IDs, Slash-Kommandos, Variablennamen oder unformatierte API-Felder weiterhin schlicht `BugLab` verwenden.

## 3. Einheitliche Lua-Farbdefinitionen

```lua
local COLORS = {
    BRIGHTBLUE_FONT_COLOR = { 0.400, 0.733, 1.000 }, -- #66BBFF
    LIGHTGRAY_FONT_COLOR = { 0.600, 0.600, 0.600 }, -- #999999
    GRAY_FONT_COLOR      = { 128/255, 128/255, 128/255 }, -- #808080
    DARKGRAY_COLOR       = { 64/255, 64/255, 64/255 }, -- #404040
    WHITE_FONT_COLOR     = { 1.000, 1.000, 1.000 }, -- #FFFFFF
}
```

Die Palette möglichst **zentral definieren**, statt Hex- oder RGB-Werte in einzelnen Modulen zu duplizieren. Bei WoW-UI-Objekten RGB-Werte verwenden (z. B. `fontString:SetTextColor(r, g, b)`), bei färbbaren Chat-Strings die WoW-Farbsequenzen.

## 4. Typografie, Logo und Stil

- **Logo-Schrift:** [Monoid](https://larsenwork.com/monoid/). Für das grafische Logo ist die festgelegte Vorlage maßgeblich.
- **Logo-Motiv:** schlichter, einfarbig hellblauer Käfer mit **sechs Beinen**, ohne Rahmen oder Farbverlauf; `{BugLab}` liegt mittig quer über dem Käfer. Weißes `Bug`, blaues `Lab`, graue Klammern; Schrift mit kräftiger schwarzer Kontur und **ohne durchgehenden schwarzen Textbalken**.
- **Ingame-Typografie:** WoW-Standardschrift verwenden, wo Monoid nicht ausdrücklich eingebunden bzw. bereitgestellt ist. Monoid ist keine automatisch verfügbare WoW-Schrift.
- **Stil:** reduziert, technisch, übersichtlich. Farben gezielt einsetzen; Hellblau für wichtige Akzente und nicht flächendeckend für alle Texte.
- **Bestehende Logodatei:** nicht ungefragt verändern, neu interpretieren oder umfärben.

## 5. Regeln für die Entwicklung mit Claude

1. Diese Palette für neue BugLab-Oberflächen und -Ausgaben verbindlich verwenden.
2. Den Addon-Namen bei farbformatierbaren UI-Texten konsequent als grau-weiß-blaues `{BugLab}` darstellen.
3. Nie `Buglab`, `BugLAB` oder Leerzeichen innerhalb von `{BugLab}` verwenden.
4. Bei textuellen Hinweisen `#999999`, bei neutralen grauen Texten `#808080`, für deaktivierte Elemente `#404040` verwenden; ausreichende Lesbarkeit sicherstellen.
5. Grafik/Logo nicht neu erzeugen oder verändern, sofern dies nicht ausdrücklich beauftragt wird.
