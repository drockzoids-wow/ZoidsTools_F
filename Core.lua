local addonName, ns = ...
ns.addonName = addonName
ns.title = "ZoidsTools Forever"
ns.version = "0.2.0-beta"

local defaults = {
    vendor = { autoSellJunk = false, autoRepairMode = "disabled" },
    unitFrames = { classColorHealth = false },
    castbars = {
        player = { enabled = false, width = 195, height = 16 },
        target = { enabled = false, width = 195, height = 16 },
        focus = { enabled = false, width = 195, height = 16 },
    },
    windows = {
        enabled = true, moveBags = true, savePositions = true,
        scaleEnabled = true, scaleStep = 0.05, minScale = 0.6, maxScale = 1.8,
        showBagHandles = true, points = {}, scales = {},
    },
    customDamageMeter = {
        enabled = false, sessionType = "current", damageMeterType = "DamageDone",
        textScale = 1, snapGap = 0, backgroundOpacity = 0.94, classColoredBorder = true,
        point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -18, y = 210,
        width = 300, height = 143,
        secondWindow = { enabled = false, sessionType = "current", damageMeterType = "HealingDone" },
    },
    ui = { minimap = { show = true, minimapPos = 225 } },
    layouts = {},
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ApplyDefaults(target[key], value)
        elseif type(target[key]) ~= type(value) then
            target[key] = value
        end
    end
end

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cfff5b833ZoidsTools Forever:|r " .. tostring(message))
end

function ns:OpenConfig(page)
    if self.UI2 then self.UI2.Show(page) end
end

function ns:SetMinimapShown(value)
    self.db.ui.minimap.show = value == true
    self:UpdateMinimapButton()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(ZoidsTools_FDB) ~= "table" then ZoidsTools_FDB = {} end
        ApplyDefaults(ZoidsTools_FDB, defaults)
        ns.db = ZoidsTools_FDB
    elseif event == "PLAYER_LOGIN" then
        ns:InitializeMovableWindows()
        ns:InitializeUnitFrames()
        ns:InitializeCastbars()
        ns:InitializeVendorAutomation()
        ns:InitializeCustomDamageMeter()
        ns:InitializeMinimapButton()
    end
end)

SLASH_ZOIDSTOOLS_FOREVER1 = "/ztf"
SLASH_ZOIDSTOOLS_FOREVER2 = "/zoidsforever"
-- Preserve the familiar shortcut when the retail addon is not loaded.
if not SlashCmdList.ZOIDSTOOLS then SLASH_ZOIDSTOOLS_FOREVER3 = "/zt" end
SlashCmdList.ZOIDSTOOLS_FOREVER = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    local feature, state = command:match("^(%a+)%s+(%a+)$")
    if (feature == "windows" or feature == "bags") and (state == "on" or state == "off") then
        ns.db.windows[feature == "windows" and "enabled" or "moveBags"] = state == "on"
        ns:RefreshMovableWindows()
        if ns.UI.RefreshVisiblePage then ns.UI.RefreshVisiblePage() end
        ns:Print((feature == "windows" and "Window movement " or "Bag movement ") .. state .. ".")
    elseif command == "vendor" then
        ns:OpenConfig("vendor")
    elseif command == "castbars" then
        ns:OpenConfig("castbars")
    elseif command == "unitframes" or command == "frames" then
        ns:OpenConfig("unitframes")
    elseif command == "windows" or command == "bags" then
        ns:OpenConfig("windows")
    elseif command == "status" then
        ns:Print(ns:GetCompatibilityStatus())
    elseif command == "preview" then
        ns:ToggleCustomDamageMeterMoveMode()
    elseif command == "on" or command == "off" then
        ns:SetCustomDamageMeterEnabled(command == "on")
    else
        ns:OpenConfig()
    end
end
