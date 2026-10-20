-- API rund um das Hauptfenster. Module nutzen GetPage(), um ihren Reiterinhalt aufzubauen.
local BugLab = _G.BugLab

-- Aktivierte Module in Anzeigereihenfolge (bestimmt die sichtbaren Reiter).
function BugLab:GetVisibleModules()
    local list = {}
    for _, name in ipairs(self.MODULES) do
        -- Der Reiter Probe erscheint erst, wenn ein Addon eine Probe angemeldet hat.
        if self:IsModuleEnabled(name) and (name ~= "Probe" or self:HasProbes()) then list[#list + 1] = name end
    end
    return list
end

-- Schriftgröße des BugLab-Chatfensters für "console" oder "probe" setzen (Optionen).
function BugLab:SetChatFontSize(kind, size)
    self.db.profile.chatFontSize[kind] = size
    local console = self:GetModule("Console", true)
    if console and console.ApplyChatFontSize then console:ApplyChatFontSize() end
end

function BugLab:ShowWindow()
    local window = self.window or self:CreateWindow()
    self:RefreshWindow()
    window:Show()
end

function BugLab:HideWindow()
    if self.window then self.window:Hide() end
end

function BugLab:ToggleWindow()
    if self.window and self.window:IsShown() then
        self:HideWindow()
    else
        self:ShowWindow()
    end
end

-- Container (Frame) der Modulseite; legt das Fenster bei Bedarf an.
function BugLab:GetPage(name)
    local window = self.window or self:CreateWindow()
    return window.pages[name]
end
