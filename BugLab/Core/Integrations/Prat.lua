-- Prat-Anbindung: Prat setzt vor jede Chatzeile eine eigene Uhrzeit. BugLab lässt seine dann im Chatfenster weg
-- (die Historie im BugLab-Fenster zeigt sie weiter).
local BugLab = _G.BugLab

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

function BugLab:IsPratLoaded()
    return (IsLoaded("Prat-3.0") or IsLoaded("Prat")) and true or false
end
