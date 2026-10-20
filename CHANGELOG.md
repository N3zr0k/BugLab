# Changelog

## 0.1.8-alpha.1
- Window close button back to the standard look (custom tint and cross removed).

## 0.1.7-alpha.1
- Window close button: pure white cross, light blue hover glow.

## 0.1.6-alpha.1
- Ctrl+Shift debug block: gray labels, blue values; new `BugLab:Paint(color, text)` palette helper.
- Window: title moved up; side tab frame and selection glow desaturated (white instead of gold).

## 0.1.5-alpha.1
- Minimap button default position is now 180 (bottom) and snaps at 55, 90 and 180 degrees while dragging.
- Ctrl+Shift over a minimap button adds a {BugLab} debug block (position, button name) to its tooltip.
- Window side tabs now use the Character window look (game atlases), one per module.
- Window: addon name centered in the title bar, description below.
- Renamed `AddonMenu.lua` to `Compartment.lua`.
- Main window: logo 1.5 px further right, one line more space below the description.
- Tooltip info icon is desaturated and tinted in the BugLab blue, like the text.

## 0.1.4-alpha.1
- Minimap button back to the standard LibDBIcon size and border (desaturated), as in 0.1.2.
- Tooltip logo is fully opaque.
- Version display: stage (alpha/beta/latest) in blue, repo counter in gray.
- Options header: own header with logo, name in title size and description; the standard panel title is removed.
- Add Ctrl+Shift+Alt+R hotkey to reload the UI (can be disabled in the options), described in the launcher tooltips with a blue info icon and blue text.

## 0.1.3-alpha.1
- Main window now uses the game's metal frame atlases (clock window style, desaturated) with logo, name and description in the header.
- Minimap button uses LibDBIcon with the clock ring atlas, desaturated; the old own button is gone.
- Show the beetle icon in the settings category list.
- Add a transparent logo next to the launcher tooltips; use the logo in the addon menu entry.

## 0.1.2-alpha.1
- Add detached main window with logo, side tabs (Console, Inspector, Probe) and footer; `/buglab` and `/bl` toggle it, `/buglab help` lists commands.
- Use BugLab_Logo_Outlined_128 as logo in the options header; header with name and description next to the logo; module descriptions inline after the module name.
- Window API in Core/API/Window.lua.
- Add minimap button (desaturated clock border atlas, draggable) with LibDataBroker object, option to hide it, and an entry in the minimap addon menu (Core/Launcher/).

## 0.1.1-alpha.1
- Add logo as addon list icon and in the overview, colored name in the options list.
- Add per-module enable checkboxes with colored module names.
- Restructure addon folder: Lua files in Core/, module folders, Core/API/.

## 0.1.0-alpha.1
- Add addon skeleton: TOC, Libs.xml, Core, Options (Overview, General, Profiles), Commands, deDE/enUS locales.
