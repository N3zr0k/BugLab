-- BugSack-Anbindung: BugLab erkennt BugSack (mit BugGrabber) und bietet im Fenster einen Absprung dorthin.
-- BugSack bleibt optional; ohne das Addon passiert nichts.
local BugLab = _G.BugLab

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

function BugLab:IsBugSackAvailable()
    local sack = _G.BugSack
    return IsLoaded("BugSack") and type(sack) == "table" and type(sack.OpenSack) == "function"
end

function BugLab:OpenBugSack()
    if self:IsBugSackAvailable() then _G.BugSack:OpenSack() end
end

-- Anzahl gespeicherter Fehler laut BugGrabber, nil wenn nicht ermittelbar.
function BugLab:GetBugSackCount()
    local grabber = _G.BugGrabber
    if type(grabber) ~= "table" or type(grabber.GetDB) ~= "function" then return nil end
    local ok, db = pcall(grabber.GetDB, grabber)
    return ok and type(db) == "table" and #db or nil
end

-- Löscht alle gespeicherten Fehler. Bevorzugt die eigene Routine von BugSack (setzt dessen Anzeige und Symbol zurück),
-- sonst BugGrabber:Reset. Gibt die Zahl der gelöschten Einträge zurück, nil wenn nichts zum Löschen da ist.
function BugLab:ClearBugSack()
    local grabber, sack = _G.BugGrabber, _G.BugSack
    local count = self:GetBugSackCount() or 0
    local ok
    if type(sack) == "table" and type(sack.Reset) == "function" then
        ok = pcall(sack.Reset, sack)
    elseif type(grabber) == "table" and type(grabber.Reset) == "function" then
        ok = pcall(grabber.Reset, grabber)
    end
    if not ok then return nil end
    -- Symbol und Anzeige von BugSack nachziehen (je nach Version unterschiedlich benannt).
    if type(sack) == "table" and type(sack.UpdateDisplay) == "function" then pcall(sack.UpdateDisplay, sack, true) end
    self:Log("BugLab:Core", self.L["BUGSACK_CLEARED"]:format(count))
    self:UpdateBugSackButton()
    -- BugSack aktualisiert sein Symbol teils verzögert: danach noch zweimal nachlesen.
    C_Timer.After(0.2, function() BugLab:UpdateBugSackButton() end)
    C_Timer.After(1, function() BugLab:UpdateBugSackButton() end)
    return count
end

-- Icon von BugSack aus seinem Broker-Objekt, nicht aus einem festen Pfad.
function BugLab:GetBugSackIcon()
    local ldb = LibStub("LibDataBroker-1.1", true)
    local object = ldb and ldb:GetDataObjectByName("BugSack")
    return object and object.icon
end

function BugLab:UpdateBugSackButton()
    local button = self.window and self.window.bugSackButton
    if not button then return end
    local available = self:IsBugSackAvailable()
    button:SetShown(available)
    if available then button.icon:SetTexture(self:GetBugSackIcon()) end
    -- Rot, sobald BugSack Fehler gespeichert hat.
    button.alert = available and (self:GetBugSackCount() or 0) > 0
    if button.Repaint then button:Repaint() end
end

-- Aktualisiert das Symbol, wenn BugGrabber einen Fehler fängt oder die Liste leert.
function BugLab:WatchBugSack()
    if self.bugSackWatched then return end
    self.bugSackWatched = true
    -- Zusätzlich zu den Rückrufen (die je nach BugGrabber-Version fehlen oder später kommen): bei sichtbarem Fenster
    -- alle 0,25 Sekunden die Fehlerzahl prüfen, damit das Symbol sofort rot wird.
    local frame, elapsed, lastCount = CreateFrame("Frame"), 0, nil
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.25 then return end
        elapsed = 0
        if not (BugLab.window and BugLab.window:IsShown()) then return end
        local count = BugLab:GetBugSackCount()
        if count ~= lastCount then
            lastCount = count
            BugLab:UpdateBugSackButton()
        end
    end)
    local grabber = _G.BugGrabber
    if type(grabber) ~= "table" or type(grabber.RegisterCallback) ~= "function" then return end
    local owner = {}
    local function update() BugLab:UpdateBugSackButton() end
    for _, event in ipairs({ "BugGrabber_BugGrabbed", "BugGrabber_DatabaseCleared" }) do
        pcall(grabber.RegisterCallback, owner, event, update)
    end
end
