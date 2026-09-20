local addonName, ns = ...
ns.addonName = addonName
ns.title = "ZoidsTools Forever"
ns.version = "0.2.3-beta"

local defaults = {
    reputation = { autoZone = true },
    campfire = { enabled = true, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 260 },
    stats = { enabled = true, locked = false, point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 },
    actionBars = { rangeTint = true },
    quests = { autoAccept = false, autoTurnIn = false, pauseModifier = "shift", minimizeTracker = true },
    loot = { fastLoot = true, slotDelay = 0 },
    tooltips = { classColoredNames = true },
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
        local missingSettings = type(ZoidsTools_FDB) ~= "table" or next(ZoidsTools_FDB) == nil
        if type(ZoidsTools_FDB) ~= "table" then ZoidsTools_FDB = {} end
        local recovery = ZoidsTools_FRecoveryService and ZoidsTools_FRecoveryService:GetSnapshot()
        ns.settingsStartup = {
            main = not missingSettings,
            backup = type(recovery) == "table" and next(recovery) ~= nil,
            preset = type(ZoidsTools_FRecovery) == "table" and next(ZoidsTools_FRecovery) ~= nil,
            source = missingSettings and "defaults" or "main save",
        }
        -- Retain compatibility with the original local fixed-preset companion.
        if not recovery then recovery = ZoidsTools_FRecovery end
        -- Never replace settings the client successfully loaded.
        if missingSettings and type(recovery) == "table" and next(recovery) then
            ApplyDefaults(ZoidsTools_FDB, recovery)
            ns.settingsRecoveryUsed = true
            ns.settingsStartup.source = ns.settingsStartup.backup and "recovery save" or "local preset"
            ns:Print("Saved settings were missing; restored your recovery snapshot.")
        end
        ApplyDefaults(ZoidsTools_FDB, defaults)
        ns.db = ZoidsTools_FDB
    elseif event == "PLAYER_LOGIN" then
        if ZoidsTools_FRecoveryService then ZoidsTools_FRecoveryService:Start(ns.db) end
        ns:InitializeMovableWindows()
        ns:InitializeUnitFrames()
        ns:InitializePlayerTooltip()
        ns:InitializeActionButtonRange()
        ns:InitializeCampfireBar()
        ns:InitializeZoneReputation()
        ns:InitializeStatsWindow()
        ns:InitializeCastbars()
        ns:InitializeVendorAutomation()
        ns:InitializeFastLoot()
        ns:InitializeQuestAutomation()
        ns:InitializeTrackerMinimize()
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
    elseif (feature == "rep" or feature == "reputation") and (state == "on" or state == "off") then
        ns:SetZoneReputationEnabled(state == "on")
        ns:Print("Automatic zone reputation " .. state .. ".")
    elseif command == "rep" or command == "reputation" then
        ns:OpenConfig("quests")
    elseif command == "stats" then
        ns:OpenConfig("stats")
    elseif command == "campfire" then
        ns:OpenConfig("actionbars")
    elseif command == "actionbars" or command == "range" then
        ns:OpenConfig("actionbars")
    elseif command == "quests" or command == "quest" then
        ns:OpenConfig("quests")
    elseif command == "loot" or command == "fastloot" then
        ns:OpenConfig("loot")
    elseif command == "tooltips" or command == "tooltip" then
        ns:OpenConfig("tooltips")
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
    elseif command == "restorepreset" then
        if type(ZoidsTools_FRecovery) ~= "table" or not next(ZoidsTools_FRecovery) then
            ns:Print("No local recovery preset is installed.")
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            ns:Print("Restore your preset after leaving combat.")
            return
        end
        if not ReloadUI then return end
        -- Explicit user command: replace settings, including a nonempty reset save.
        local restored = {}
        ApplyDefaults(restored, ZoidsTools_FRecovery)
        ApplyDefaults(restored, defaults)
        ZoidsTools_FDB = restored
        ns.db = restored
        if ZoidsTools_FRecoveryService then ZoidsTools_FRecoveryService:Start(restored) end
        ReloadUI()
    elseif command == "recovery" then
        local startup = ns.settingsStartup
        if startup then
            ns:Print("Settings at startup: main=" .. (startup.main and "present" or "missing")
                .. ", backup=" .. (startup.backup and "present" or "missing")
                .. ", local preset=" .. (startup.preset and "present" or "missing")
                .. "; using " .. startup.source .. ".")
            ns:Print("Snapshots update in memory; disk saves happen on reload/logout. A local preset is a fixed copy.")
        end
    elseif command == "preview" then
        ns:ToggleCustomDamageMeterMoveMode()
    elseif command == "on" or command == "off" then
        ns:SetCustomDamageMeterEnabled(command == "on")
    else
        ns:OpenConfig()
    end
end
