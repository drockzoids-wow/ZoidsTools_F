local addonName, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
ns.addonName = addonName
ns.title = "ZoidsTools Forever"
ns.version = "0.2.9-beta"

local defaults = {
    buffs = { characters = {} },
    reputation = { autoZone = true },
    campfire = { enabled = true, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 260 },
    stats = { enabled = true, locked = false, point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 },
    actionBars = { rangeTint = true },
    macros = { healthEnabled = false, healthCombatItems = true, manaEnabled = false, manaCombatPotion = true },
    quests = { autoAccept = false, autoTurnIn = false, pauseModifier = "shift", minimizeTracker = true,
        questItemButtonEnabled = true, questItemButton = { point = "CENTER", relativePoint = "CENTER", x = 280, y = -80 } },
    loot = { fastLoot = true, slotDelay = 0 },
    tooltips = { classColoredNames = true, itemCounts = true },
    vendor = { autoSellJunk = false, autoRepairMode = "disabled" },
    unitFrames = { classColorHealth = false },
    castbars = {
        player = { enabled = false, width = 195, height = 16 },
        target = { enabled = false, width = 195, height = 16 },
        focus = { enabled = false, width = 195, height = 16 },
    },
    windows = {
        enabled = true, moveBags = true, savePositions = true, bagAnchorCorner = "BOTTOMRIGHT",
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

local function ReadMemory()
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
        return
    end
    local updated = pcall(UpdateAddOnMemoryUsage)
    local ok, usage = pcall(GetAddOnMemoryUsage, addonName)
    if not updated or not ok or (issecretvalue and issecretvalue(usage))
        or type(usage) ~= "number" or usage ~= usage or usage < 0 or usage == math.huge then
        return
    end
    return usage
end

function ns:ReportMemory(collect)
    -- Normal readings never force collection. The explicit diagnostic compares
    -- before/after once, outside combat; it is not an automatic optimization.
    if collect and InCombatLockdown and InCombatLockdown() then
        self:Print("Run the memory cleanup diagnostic after leaving combat.")
        return
    end
    local usage = ReadMemory()
    if not usage then
        self:Print("Memory reporting is unavailable on this client.")
        return
    end
    if collect then
        if type(collectgarbage) ~= "function" then
            self:Print("Memory cleanup diagnostic is unavailable on this client.")
            return
        end
        local ok, result = pcall(collectgarbage, "collect")
        if not ok or result == false then
            self:Print("Memory cleanup diagnostic is unavailable on this client.")
            return
        end
        local after = ReadMemory()
        if not after then
            self:Print("Cleanup requested, but the updated memory reading is unavailable.")
            return
        end
        self:Print(string.format("v%s memory diagnostic: before %.2f MiB; after cleanup request %.2f MiB; change %+.2f MiB.",
            self.version, usage / 1024, after / 1024, (after - usage) / 1024))
        self:Print("Cleanup affects the whole UI; these readings are for the main addon only. This is a diagnostic, not a performance fix.")
        return
    end
    self:Print(string.format("v%s main addon memory: %.2f MiB (%.0f KiB). Includes temporary Lua allocations; companions are reported separately by the game.",
        self.version, usage / 1024, usage))
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
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(ZoidsTools_FDB) ~= "table" then ZoidsTools_FDB = {} end
        ApplyDefaults(ZoidsTools_FDB, defaults)
        ns.db = ZoidsTools_FDB
    elseif event == "PLAYER_LOGOUT" then
        if ns.FinishWindowDrags then ns:FinishWindowDrags() end
    elseif event == "PLAYER_LOGIN" then
        ns:InitializeMovableWindows()
        ns:InitializeUnitFrames()
        ns:InitializeMissingBuffs()
        ns:InitializePlayerTooltip()
        ns:InitializeWarbandItems()
        ns:InitializeActionButtonRange()
        ns:InitializeCampfireBar()
        ns:InitializeConsumableMacros()
        ns:InitializeZoneReputation()
        ns:InitializeStatsWindow()
        ns:InitializeCastbars()
        ns:InitializeVendorAutomation()
        ns:InitializeFastLoot()
        ns:InitializeQuestAutomation()
        ns:InitializeQuestItemButton()
        ns:InitializeTrackerMinimize()
        ns:InitializeCustomDamageMeter()
        ns:InitializeMinimapButton()
        ns:InitializeMinimapTools()
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
        ns:Print(string.format(feature == "windows" and L["Window movement: %s."] or L["Bag movement: %s."], state == "on" and L["Enabled"] or L["Disabled"]))
    elseif (feature == "rep" or feature == "reputation") and (state == "on" or state == "off") then
        ns:SetZoneReputationEnabled(state == "on")
        ns:Print(string.format(L["Automatic zone reputation: %s."], state == "on" and L["Enabled"] or L["Disabled"]))
    elseif command == "rep" or command == "reputation" then
        ns:OpenConfig("quests")
    elseif command == "minimap" then
        ns:ShowMinimapSettings()
    elseif command == "buffs" or command == "buff" then
        ns:ShowMissingBuffSettings()
    elseif command == "stats" then
        ns:OpenConfig("stats")
    elseif command == "macros" or command == "macro" or command == "food" or command == "water" or command == "drink" then
        ns:OpenConfig("macros")
    elseif command == "campfire" then
        ns:OpenConfig("actionbars")
    elseif command == "actionbars" or command == "range" then
        ns:OpenConfig("actionbars")
    elseif command == "completionist" or command == "guide" then
        ns:OpenConfig("completionist")
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
    elseif command == "memory" then
        ns:ReportMemory()
    elseif command == "memory collect" then
        ns:ReportMemory(true)
    elseif command == "preview" then
        ns:ToggleCustomDamageMeterMoveMode()
    elseif command == "on" or command == "off" then
        ns:SetCustomDamageMeterEnabled(command == "on")
    else
        ns:OpenConfig()
    end
end
