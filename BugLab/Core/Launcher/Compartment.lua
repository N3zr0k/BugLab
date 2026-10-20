-- Eintrag im Addon-Menü (Kompartiment) oben rechts an der Minimap.
local BugLab = _G.BugLab

function BugLab:SetupCompartment()
    local compartment = _G.AddonCompartmentFrame
    -- Nicht jeder Client bringt das Menü mit; dann entfällt der Eintrag still.
    if not (compartment and compartment.RegisterAddon) then
        self:Debug("AddonCompartmentFrame not available")
        return
    end

    compartment:RegisterAddon({
        text = self.NAME_COLORED,
        icon = self.MEDIA_PATH .. "BugLab_Logo_Outlined_128",
        notCheckable = true,
        func = function() BugLab:ToggleWindow() end,
        funcOnEnter = function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            BugLab:FillLauncherTooltip(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function() GameTooltip:Hide() end,
    })
end
