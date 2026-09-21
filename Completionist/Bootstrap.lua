local _, root = ...
local ns = {}
root.Completionist = ns
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
function ns.PrepareCharacter()
    if type(ZoidsTools_FCompletionistDB) ~= "table" then ZoidsTools_FCompletionistDB = {} end
    local db = ZoidsTools_FCompletionistDB
    -- Optional dependency loads the old character save before our ADDON_LOADED.
    if not db.legacyImported and type(ZoidsForeverGuideCharDB) == "table" then
        local old = Copy(ZoidsForeverGuideCharDB)
        for key, value in pairs(old) do if db[key] == nil then db[key] = value end end
        db.discovered = type(db.discovered) == "table" and db.discovered or {}
        for id, value in pairs(type(old.discovered) == "table" and old.discovered or {}) do
            if db.discovered[id] == nil then db.discovered[id] = value end
        end
        db.legacyImported = true
    end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    ns.migrationPending = type(loaded) == "function" and loaded("ZoidsForeverGuide") == true
end
local function Revision(db)
    local value = type(db) == "table" and db.revision
    return type(value) == "number" and value >= 0 and value < math.huge and value or 0
end
function ns.LoadTrackerSettings()
    if type(root.db) ~= "table" then return end
    local settings = root.db.completionistTracker
    if type(settings) == "table" then
        ns.char.windowPoint = Copy(settings.windowPoint)
        ns.char.locked = settings.locked == true
        ns.char.minimized = settings.minimized == true
    else
        -- Import the first character's existing layout once, then use the shared save.
        ns.SaveTrackerSettings()
    end
end
function ns.SaveTrackerSettings()
    if not ns.char or type(root.db) ~= "table" then return end
    root.db.completionistTracker = {
        windowPoint = Copy(ns.char.windowPoint),
        locked = ns.char.locked == true,
        minimized = ns.char.minimized == true,
        revision = Revision(root.db.completionistTracker) + 1,
    }
    if ZoidsTools_FRecoveryService then ZoidsTools_FRecoveryService:Capture() end
end
local migration = CreateFrame("Frame")
ns.migrationEvents = migration
migration:RegisterEvent("PLAYER_LOGIN")
migration:RegisterEvent("PLAYER_LOGOUT")
migration:SetScript("OnEvent", function(_, event)
    if not ns.migrationPending then return end
    if event == "PLAYER_LOGOUT" then
        -- Capture any quests discovered by the legacy tracker after login and before reload.
        local old = ZoidsForeverGuideCharDB
        if type(old) == "table" and type(old.discovered) == "table" then
            local db = ZoidsTools_FCompletionistDB
            db.discovered = type(db.discovered) == "table" and db.discovered or {}
            for id, value in pairs(old.discovered) do
                if db.discovered[id] == nil then db.discovered[id] = Copy(value) end
            end
        end
        return
    end
    -- Leave the old tracker in charge until reload; never run both event systems.
    local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
    if type(disable) == "function" then
        -- Character-scoped disable allows each alt to import its own discoveries first.
        local character = UnitName and UnitName("player")
        local ok, result = pcall(disable, "ZoidsForeverGuide", character)
        ns.legacyDisabled = ok and result ~= false
    end
    root:Print("Completionist imported your Guide settings. Reload to finish; disable ZoidsForeverGuide in AddOns if it remains enabled.")
end)
function ns.ShowTracker()
    if ns.window then ns.char.show = true; ns.char.minimized = false; ns.window:Show(); ns.ApplyTrackerState() end
end
