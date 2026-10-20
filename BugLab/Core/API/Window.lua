-- API rund um das Hauptfenster. Module nutzen GetPage(), um ihren Reiterinhalt aufzubauen.
local BugLab = _G.BugLab

-- Aktivierte Module in Anzeigereihenfolge (bestimmt die sichtbaren Reiter).
function BugLab:GetVisibleModules()
    local list = {}
    for _, name in ipairs(self.MODULES) do
        if self:IsModuleEnabled(name) then list[#list + 1] = name end
    end
    return list
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
