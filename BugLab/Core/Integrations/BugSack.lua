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
end
