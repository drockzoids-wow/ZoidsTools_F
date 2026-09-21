local addonName = ...
local recovery = {}
ZoidsTools_FRecoveryService = recovery
local loaded, source, ticker

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

function recovery:GetSnapshot()
    if loaded and type(ZoidsTools_FRecoveryDB) == "table" and next(ZoidsTools_FRecoveryDB) then
        return ZoidsTools_FRecoveryDB
    end
end

function recovery:GetPreset()
    if loaded and type(ZoidsTools_FRecoveryPresetDB) == "table" and next(ZoidsTools_FRecoveryPresetDB) then
        return ZoidsTools_FRecoveryPresetDB
    end
end

function recovery:SavePreset(db)
    if not loaded or type(db) ~= "table" or not next(db) then return false end
    ZoidsTools_FRecoveryPresetDB = Copy(db)
    return true
end

function recovery:Capture()
    if not loaded or type(source) ~= "table" or not next(source) then return false end
    -- Replace only after copying, so later edits cannot mutate the snapshot.
    -- This updates memory; WoW writes SavedVariables on reload/logout.
    ZoidsTools_FRecoveryDB = Copy(source)
    return true
end

function recovery:Start(db)
    if not loaded or type(db) ~= "table" or not next(db) then return end
    source = db
    self:Capture()
    if not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(600, function() recovery:Capture() end)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        loaded = true
    elseif event == "PLAYER_LOGOUT" then
        recovery:Capture()
    end
end)
