local ADDON_NAME = ...

local BugLab = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

_G.BugLab = BugLab
BugLab.L = L

-- Palette zentral (siehe Design Guidelines); Module lesen sie von hier.
BugLab.COLORS = {
    BRIGHTBLUE_FONT_COLOR = { 0.400, 0.733, 1.000 }, -- #66BBFF
    LIGHTGRAY_FONT_COLOR  = { 0.600, 0.600, 0.600 }, -- #999999
    GRAY_FONT_COLOR       = { 128 / 255, 128 / 255, 128 / 255 }, -- #808080
    DARKGRAY_COLOR        = { 64 / 255, 64 / 255, 64 / 255 }, -- #404040
    WHITE_FONT_COLOR      = { 1.000, 1.000, 1.000 }, -- #FFFFFF
}

-- Dieselbe Palette als Hex für Farbcodes in Texten: BugLab:Paint("BRIGHTBLUE", "Text").
local HEX = { BRIGHTBLUE = "66bbff", LIGHTGRAY = "999999", GRAY = "808080", DARKGRAY = "404040", WHITE = "ffffff", ERROR = "ff4040" }
function BugLab:Paint(color, text)
    return "|cff" .. HEX[color] .. text .. "|r"
end

BugLab.NAME_COLORED = "|cff808080{|r|cffffffffBug|r|cff66bbffLab|r|cff808080}|r"
BugLab.MEDIA_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

-- Kategoriename in den Einstellungen: Symbol als Texturcode vor dem farbigen Namen (die Liste kennt kein eigenes Icon-Feld).
BugLab.OPTIONS_NAME = "|T" .. BugLab.MEDIA_PATH .. "BugLab_Beetle_Outlined_32:16:16|t " .. BugLab.NAME_COLORED

-- Reihenfolge = Anzeige in der Übersicht. Tabelle wird von den Modulen nicht verändert.
BugLab.MODULES = { "Console", "Inspector", "Gallery", "Probe", "Database" }

local DB_DEFAULTS = {
    profile = {
        debug = false,
        reloadHotkey = true,
        inspectBlizzard = true, -- Inspector darf auch Blizzard-Elemente verändern (Taint-Risiko, nur bis /reload)
        historyDays = 30, -- Aufbewahrung der Console-Historie
        logRateLimit = 30, -- Zeilen pro Sekunde und Quelle, 0 = keine Drosselung
        chatFontSize = { console = 12, probe = 12 }, -- Schriftgröße des BugLab-Chatfensters je Log
        modules = { Console = true, Inspector = true, Gallery = true, Probe = true, Database = true },
        minimap = { hide = false, minimapPos = 180 }, -- Format von LibDBIcon
    },
    global = { history = {}, probeHistory = {}, dbVars = {} }, -- Console- und Probe-Historie, profilübergreifend
}

-- Version und Infos kommen aus der TOC, nicht aus dem Code.
local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

function BugLab:GetMeta(field)
    return GetMetadata(ADDON_NAME, field)
end

-- Modulnamen: "Bug" weiß, Rest BugLab-Blau (Design Guidelines).
function BugLab:ModuleName(name)
    return "|cffffffffBug|r|cff66bbff" .. name .. "|r"
end

function BugLab:IsModuleEnabled(name)
    return self.db.profile.modules[name] and true or false
end

-- Schaltet ein Modul um; existiert das Modul-Objekt noch nicht, gilt nur die Einstellung.
function BugLab:SetModuleEnabled(name, enabled)
    self.db.profile.modules[name] = enabled and true or false
    self:RefreshWindow()
    local module = self:GetModule(name, true)
    if not module then return end
    if enabled then self:EnableModule(name) else self:DisableModule(name) end
end

-- Version x.y.z-stufe.N: Stufe (alpha, beta, latest) in BugLab-Blau, der Repo-Zähler N grau, der Rest in baseHex.
function BugLab:FormatVersion(baseHex)
    baseHex = baseHex or "ffffff"
    local version = self:GetMeta("Version") or "?"
    local core, stage, build = version:match("^([%d%.]+)%-(%a+)%.(%d+)$")
    if not core then return "|cff" .. baseHex .. version .. "|r" end
    return "|cff" .. baseHex .. core .. "-|r|cff66bbff" .. stage .. "|r|cff808080." .. build .. "|r"
end

function BugLab:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(self.NAME_COLORED .. " |cff999999" .. tostring(msg) .. "|r")
end

-- Nur interne Diagnose; die Console (später) hängt sich hier ein.
function BugLab:Debug(...)
    if not self.db.profile.debug then return end
    self:Print(strjoin(" ", tostringall(...)))
end

function BugLab:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BugLabSettings", DB_DEFAULTS, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    self:FlushPendingLog()
    self:PruneHistory()
    self:PruneHistory(nil, "probe")
    self:SetupOptions()
    self:SetupCommands()
end

function BugLab:OnEnable()
    self:SetupReloadHotkey()
    self:SetupReloadLog()
    self:WatchBugSack()
    self:RegisterMessage("BUGLAB_PROBE_REGISTERED", function() if self.window then self:RefreshWindow() end end)
    self:SetupMinimapButton()
    self:SetupCompartment()
    for _, name in ipairs(self.MODULES) do
        if self:GetModule(name, true) and not self:IsModuleEnabled(name) then
            self:DisableModule(name)
        end
    end
    -- BugLab meldet sich wie jedes andere Addon einmal pro Sitzung mit Version und Debug-Zustand.
    self:GetLogger("BugLab:Core"):Announce({ version = self:GetMeta("Version"), debug = self.db.profile.debug })
end

function BugLab:OnProfileChanged()
    for _, name in ipairs(self.MODULES) do
        if self:GetModule(name, true) then self:SetModuleEnabled(name, self:IsModuleEnabled(name)) end
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end
