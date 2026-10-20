-- Entwicklerkomfort: Strg+Umschalt+Alt+R lädt die Oberfläche neu (wie /reload).
local BugLab = _G.BugLab

-- Getrennt vom Frame, damit die Tastenlogik ohne Client testbar bleibt.
function BugLab:HandleReloadKey(key)
    if self.db.profile.reloadHotkey and key == "R" and IsControlKeyDown() and IsShiftKeyDown() and IsAltKeyDown() then
        ReloadUI()
        return true
    end
end

function BugLab:SetupReloadHotkey()
    if self.hotkeyFrame then return end
    local frame = CreateFrame("Frame", "BugLabHotkeys", UIParent)
    frame:EnableKeyboard(true)
    -- Alle anderen Tastenbelegungen müssen weiter funktionieren.
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(_, key) BugLab:HandleReloadKey(key) end)
    self.hotkeyFrame = frame
end
