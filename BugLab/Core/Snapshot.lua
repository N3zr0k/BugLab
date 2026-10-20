-- Merkt sich, welches Addon welchen Frame erzeugt hat, damit der Inspector Blizzard-Frames (nur Anzeige) von eigenen
-- Frames (änderbar) unterscheiden kann. Wird als Allererstes geladen: alles, was jetzt schon existiert, gehört dem Spiel
-- (FrameXML und früher geladene Addons). Bei jedem ADDON_LOADED wird der Zuwachs dem geladenen Addon zugeordnet. Damit
-- zur Laufzeit erzeugte Frames (z. B. Fenster, die erst beim Öffnen entstehen) nicht dem nächsten geladenen Addon zufallen,
-- werden neue Frames außerdem alle 0,25 Sekunden als "?" (Laufzeit, Herkunft unbekannt) markiert.
local owners = setmetatable({}, { __mode = "k" })
_G.BugLabFrameOwners = owners

local function Snapshot(label)
    if not EnumerateFrames then return end
    local frame = EnumerateFrames()
    while frame do
        if owners[frame] == nil then owners[frame] = label end
        frame = EnumerateFrames(frame)
    end
end

Snapshot("Blizzard")

local watcher = CreateFrame("Frame")
owners[watcher] = "BugLab"
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name) Snapshot(name) end)

local elapsed = 0
watcher:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    Snapshot("?")
end)
