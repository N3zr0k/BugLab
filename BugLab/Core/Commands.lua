local BugLab = _G.BugLab
local L = BugLab.L

-- Bewusst nur wenige Befehle; weitere Funktionen hängen am Fenster.
function BugLab:SetupCommands()
    self:RegisterChatCommand("buglab", "OnSlashCommand")
    self:RegisterChatCommand("bl", "OnSlashCommand")
end

function BugLab:OnSlashCommand(input)
    local cmd = (input or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "help" or cmd == "hilfe" then
        self:PrintHelp()
    else
        self:ToggleWindow()
    end
end

function BugLab:PrintHelp()
    self:Print(L["HELP_HEADER"])
    DEFAULT_CHAT_FRAME:AddMessage("  |cff66bbff/buglab|r, |cff66bbff/bl|r |cff999999- " .. L["HELP_WINDOW"] .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("  |cff66bbff/buglab help|r, |cff66bbff/buglab hilfe|r |cff999999- " .. L["HELP_HELP"] .. "|r")
end
