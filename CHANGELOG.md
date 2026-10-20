# Changelog

## 0.1.23-alpha.1
- Chat: BugLab's own messages show the original addon name with its colors ("Bug" white, "Lab" blue) inside the braces.
- Chat: the module or extension part of the source (":Console") is gray, only the addon name stays blue.
- Repo: header images in `documentation/assets/`, header and badges (latest, last push, CI) at the top of the README, badge snippet for the CurseForge description in `documentation/curseforge/BADGES.md`.

## 0.1.22-alpha.1
- Inspector: "Changes" view (page button cycles details / Lua code / changes, popup has a toggle) shows all changes made so far as Lua code, also for several different elements; only what differs from the original.
- Inspector popup: "Pick element" button to choose a new element.
- Inspector: the popup is shown whenever the Inspector page is open and an element is selected (it closes with the page).
- Inspector popup: the Lua code of the element is shown directly (click selects all, Ctrl+C copies) and updates with every change.
- Console: filter dropdown text anchored at 8 / -7 (values taken over from the Inspector).
- Inspector: color field (hex and color picker) for textures and font strings, with reset.
- Inspector page: layer buttons (< 2/5 >) next to the pick button, like in the popup.
- Console: calendar popup "Apply" and "Cancel" buttons moved apart (-68 / +73) (value taken over from the Inspector).
- Console: calendar popup description sits 15 px below the title (value taken over from the Inspector).
- Window: minimum and default width is 850 px.
- Console: time range bar frame scaled to 1.1 (value taken over from the Inspector).

## 0.1.21-alpha.1
- Inspector popup: layer buttons (< 2/5 >, also mouse wheel) switch between the elements under the mouse of the last pick, plus a "Parent" button.
- Inspector: the blue selection frame hides while values are changed and returns 2 seconds after the last change.
- Window: header icons (gear, BugSack) are scaled to 1.25 (values taken over from the Inspector).

## 0.1.20-alpha.1
- Inspector: the hotkey and `/bl pick` now open a small popup with the edit fields (X, Y, size, alpha, scale, reset) instead of the main window, so the addon's own windows can be adjusted. "Show values" in the popup opens the Inspector page with the element.
- Console: calendar popup has a separate line for its description; time range bar uses the dropdown font.
- Console: time range bar uses exactly the font of the dropdowns (frame 30 px high).

## 0.1.19-alpha.1
- Inspector: font strings are listed before their frame when picking (no longer only reachable with the mouse wheel).
- Inspector: owner detection treats everything below a BugLab frame as BugLab (the history button showed another addon).
- Inspector: header row no longer overlaps at the minimum width ("Deselect" now follows "Parent"), "Reset" sits at the right edge, larger plus/minus buttons.
- Inspector: no selection frame for hidden objects (it was drawn at a stale position).
- Console: time range bar is taller (matches the dropdowns) and uses a larger font.

## 0.1.18-alpha.1
- Inspector: texture name (atlas or file path, resolved from the file ID when the client knows it) in the details and in the pick banner.
- Inspector: "Select nothing" button on the pick banner and a "Deselect" button on the page; the selection frame disappears as soon as the page is no longer visible (also when the window is closed).
- Inspector: Ctrl+Shift+Alt+I starts the element pick from anywhere (also while typing in BugLab input fields) and opens the Inspector with the chosen element; hint in the minimap tooltip.
- Fix: the blue selection frame stayed on screen after closing the window or leaving the Inspector tab.
- Fix: no frame was drawn around Blizzard elements such as action buttons (protected frames cannot be used as anchors). The frame is now placed from the element's screen rectangle; if that fails the status line shows why.
- Inspector: picking of Blizzard UI elements is faster and more robust (one protected call per frame, search only when the mouse moves, errors on locked frames no longer abort the search).
- Inspector: plus/minus buttons next to every value field (hold to repeat, Shift = large steps).
- Fix: Inspector showed the wrong owner (a later loaded addon) for frames created at runtime, e.g. the BugLab window. New frames are now marked as runtime frames, names starting with BugLab always belong to BugLab.

## 0.1.17-alpha.1
- Inspector module (first version): pick any element under the mouse (`/bl pick` or the button, click/Enter selects, arrow keys and mouse wheel change the layer, Esc cancels), shows size, position, anchors, strata, scripts, children, regions, textures (file/atlas, coordinates, color, blend mode) and font strings; own frames can be changed (x, y, width, height, alpha, scale, with reset), Blizzard frames are view only; "Lua code" button generates code to rebuild the frame.
- New files: `Core/Snapshot.lua` (frame owner tracking), `Core/API/Inspect.lua` (read, edit, export API), `Core/UI.lua` (shared buttons).
- Buttons use the standard texture, desaturated and tinted somewhat darker; the period bar is 2 px higher with a larger font.

## 0.1.16-alpha.1
- The beetle button of the chat window sits above the window at the top right (no longer over the text or near the copy icon).

## 0.1.15-alpha.1
- Fix: at small window widths the period bar overlapped the source dropdown. The bar and dropdowns now share the space (short values narrow first), the minimum window width is 700.
- Period bar and calendar popup use the dropdown font size (GameFontHighlightSmall).
- Calendar popup title bar matches the main window: large white title in the frame bar with a gray description below.
- Dropdowns, buttons, the filter text input and the period bar share one height (24).
- The "Clear" button keeps the standard red look and hover.
- Period bar uses the frame of the filter text input; buttons are darker gray and the standard hover texture is desaturated and tinted BugLab blue.

## 0.1.14-alpha.1
- Buttons use the standard game size (height 22, width fits the text); calendar input fields use the same height.
- Fix: calendar popup reset the first picked day when the date fields were filled by a click, so the end day could not be picked.
- Buttons use the standard game hover highlight (no full-face overlay). Calendar input fields have a button frame with a black interior.
- Calendar: today is marked with a blue frame and blue text.
- Calendar popup opens as its own window in the screen center, above everything (also chat windows), with an opaque background.
- Period quick-select bar has a black background like the dropdowns.

## 0.1.13-alpha.1
- Calendar popup: metal frame (Atlas), draggable, typed input with masks for start/end date and time (defaults 00:00 / 23:59), applied with Apply; every day selectable, mouse wheel changes month, today highlighted, range preview.

## 0.1.12-alpha.1
- Console period filter is now a quick-select bar (1h, 3h, 12h, 1d, 3d, 7d, All) plus Custom with a calendar popup for a date range; 24 hours replaced by 12 hours.
- Console source filter lists `BugLab:Console` etc. for own modules and `Addon:Module` for external sources; selecting the addon name includes all its sub-sources.
- Console filter ignores terms shorter than 3 characters.
- Log API: `BugLab:GetLogger(source)` with per-addon level and on/off, formatted values in blue (`FormatMessage`), `log:Dump()` for tables, per-source throttling (option "Throttle").
- Fix: the log shortcuts overwrote `BugLab:Debug`. See BUGFIX.md.

## 0.1.11-alpha.1
- Window: gear and BugSack buttons are flat gray icons in the title bar (blue on hover) instead of red boxes.
- BugSack integration: if BugSack is installed, an icon with the BugSack icon left of the gear opens it, the tooltip shows the saved Lua error count (`Core/Integrations/BugSack.lua`).
- Fix: error when opening the Console page (filter dropdowns). See BUGFIX.md.
- Reload hotkey (Ctrl+Shift+Alt+R) also works while an input field in the BugLab window has focus.

## 0.1.10-alpha.1
- Console buttons: lighter gray, white text, stronger blue hover glow; dropdown and input frames desaturated, blue dropdown arrow; "Copy" button removed (mark text with the mouse instead).

## 0.1.9-alpha.2
- Console history: filters as standard WoW dropdowns with tooltips, "Clear filters" button next to the text input, history text can be marked with the mouse and copied.
- GitHub Actions pipeline (`.github/workflows/ci.yml`): lint, tests, addon ZIP, GitHub release and CurseForge upload; `.luacheckrc` added.

## 0.1.9-alpha.1
- Window: gear button next to the close button (same button as background, gold gear) opens the settings.
- Log levels (Debug, Info, Warn, Error, Fatal) with colors, `BugLab:Warn()` etc. shortcuts and a level filter in the history.
- Console chat window: small blue beetle button opens the history.
- Console chat window: same line format as the history (time, source, level colors, date lines), today's lines replayed on first open, 2000 lines of scrollback.
- Console history: `BugLab:Log(source, text)` API, history kept for 30 days by default (option "History (days)"), formatting helpers.
- Console filter logic (source, text with -exclusion and "phrases", time range presets) in `Core/API/Filter.lua`.
- Window is resizable (grip bottom right), size is saved with the position.
- New white beetle icon `BugLab_Beetle_White_32` for the console source tag.

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
