local BugLab = _G.BugLab
local L = BugLab.L

-- Pro Modul ein Haken; die Beschreibung folgt hinter einem weißen Mittelpunkt in derselben Zeile.
local function AddModuleOptions(args)
    for i, name in ipairs(BugLab.MODULES) do
        args["module" .. name] = {
            type = "toggle", order = 10 + i, width = "full",
            name = BugLab:ModuleName(name) .. " |cffffffff·|r |cff999999" .. L["MODULE_" .. name:upper() .. "_DESC"] .. "|r",
            desc = L["MODULE_ENABLE_DESC"],
            get = function() return BugLab:IsModuleEnabled(name) end,
            set = function(_, v) BugLab:SetModuleEnabled(name, v) end,
        }
    end
end

local function GetOptions()
    local options = {
        type = "group",
        name = BugLab.NAME_COLORED,
        childGroups = "tab",
        args = {
            overview = {
                type = "group",
                name = L["TAB_OVERVIEW"],
                order = 1,
                args = {
                    version = {
                        type = "description", order = 2,
                        name = function() return "|cff999999" .. L["VERSION"] .. ":|r " .. BugLab:FormatVersion() end,
                    },
                    author = {
                        type = "description", order = 3,
                        name = function() return "|cff999999" .. L["AUTHOR"] .. ":|r " .. (BugLab:GetMeta("Author") or "?") .. "\n" end,
                    },
                    modulesHeader = { type = "header", order = 4, name = L["MODULES"] },
                },
            },
            general = {
                type = "group",
                name = L["TAB_GENERAL"],
                order = 2,
                args = {
                    debug = {
                        type = "toggle", order = 1, width = "full",
                        name = L["OPT_DEBUG"], desc = L["OPT_DEBUG_DESC"],
                        get = function() return BugLab.db.profile.debug end,
                        set = function(_, v) BugLab.db.profile.debug = v end,
                    },
                    reloadHotkey = {
                        type = "toggle", order = 3, width = "full",
                        name = L["OPT_RELOAD"], desc = L["OPT_RELOAD_DESC"],
                        get = function() return BugLab.db.profile.reloadHotkey end,
                        set = function(_, v) BugLab.db.profile.reloadHotkey = v end,
                    },
                    minimap = {
                        type = "toggle", order = 2, width = "full",
                        name = L["OPT_MINIMAP"], desc = L["OPT_MINIMAP_DESC"],
                        get = function() return not BugLab.db.profile.minimap.hide end,
                        set = function(_, v) BugLab:SetMinimapButtonShown(v) end,
                    },
                },
            },
        },
    }
    AddModuleOptions(options.args.overview.args)
    return options
end

function BugLab:SetupOptions()
    local opts = GetOptions()
    opts.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    opts.args.profiles.name = L["TAB_PROFILES"]
    opts.args.profiles.order = 3

    LibStub("AceConfig-3.0"):RegisterOptionsTable("BugLab", opts)
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:AddToBlizOptions("BugLab", self.OPTIONS_NAME)
    local group = dialog.BlizOptions.BugLab and dialog.BlizOptions.BugLab.BugLab
    if group then self:BuildPanelHeader(group) end
end

local HEADER_LOGO_SIZE, HEADER_HEIGHT = 64, 84

-- Kopfbereich des Panels: Logo links, Name (Titelgröße) und graue Beschreibung rechts daneben.
-- AceConfigDialog setzt den Panel-Titel bei jedem Öffnen neu, daher wird SetTitle der Gruppe ersetzt:
-- kein Standardtitel, der Inhalt beginnt unter dem eigenen Kopf.
function BugLab:BuildPanelHeader(group)
    local frame = group.frame
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(HEADER_LOGO_SIZE, HEADER_LOGO_SIZE)
    logo:SetPoint("TOPLEFT", 10, -10)
    logo:SetTexture(self.MEDIA_PATH .. "BugLab_Logo_Outlined_128")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -8)
    title:SetText(self.NAME_COLORED)

    local tagline = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    tagline:SetTextColor(unpack(self.COLORS.LIGHTGRAY_FONT_COLOR))
    tagline:SetText(L["SLOGAN"])

    group.SetTitle = function(widget)
        widget.label:SetText("")
        widget.content:ClearAllPoints()
        widget.content:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT)
        widget.content:SetPoint("BOTTOMRIGHT", -10, 10)
    end
    group:SetTitle()
end

function BugLab:OpenOptions()
    if Settings and Settings.OpenToCategory then
        -- Ace merkt sich die Kategorie-ID je nach Client unter dem Namen oder einer Nummer.
        local dialog = LibStub("AceConfigDialog-3.0")
        Settings.OpenToCategory(dialog.BlizOptionsIDMap[self.OPTIONS_NAME] or self.OPTIONS_NAME)
    else
        LibStub("AceConfigDialog-3.0"):Open("BugLab")
    end
end
