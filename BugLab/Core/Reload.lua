-- Entwicklerkomfort: Strg+Umschalt+Alt+R lädt die Oberfläche neu (wie /reload), Strg+Umschalt+Alt+I startet die
-- Elementwahl des Inspectors.
local BugLab = _G.BugLab

-- Getrennt vom Frame, damit die Tastenlogik ohne Client testbar bleibt.
function BugLab:HandleReloadKey(key)
    if self.db.profile.reloadHotkey and key == "R" and IsControlKeyDown() and IsShiftKeyDown() and IsAltKeyDown() then
        ReloadUI()
        return true
    end
end

function BugLab:HandleInspectKey(key)
    if key == "I" and IsControlKeyDown() and IsShiftKeyDown() and IsAltKeyDown() then
        local inspector = self:GetModule("Inspector", true)
        if inspector and inspector:IsEnabled() then
            inspector:StartPick(true)
            return true
        end
    end
end

-- Alle Tastenkürzel an einer Stelle.
function BugLab:HandleHotkey(key)
    return self:HandleReloadKey(key) or self:HandleInspectKey(key)
end

function BugLab:SetupReloadHotkey()
    if self.hotkeyFrame then return end
    local frame = CreateFrame("Frame", "BugLabHotkeys", UIParent)
    frame:EnableKeyboard(true)
    -- Alle anderen Tastenbelegungen müssen weiter funktionieren.
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(_, key) BugLab:HandleHotkey(key) end)
    self.hotkeyFrame = frame
end

-- Ein fokussiertes Eingabefeld nimmt alle Tasten an, der Hotkey-Frame sieht sie dann nicht mehr.
-- Eingabefelder im BugLab-Fenster geben den Tastendruck deshalb zusätzlich selbst weiter.
function BugLab:HookReloadKey(editBox)
    editBox:HookScript("OnKeyDown", function(_, key) BugLab:HandleHotkey(key) end)
end
