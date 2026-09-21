local addonName = ...
-- Always available in the main addon. The optional companion supplies a separate disk file.
local companion = ZoidsTools_FRecoveryService
local recovery = {}
ZoidsTools_FRecoveryService = recovery
local loaded, source, ticker, localPreset
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
local function Present(value) return type(value) == "table" and next(value) ~= nil end
function recovery:GetSnapshot()
    if not loaded then return end
    if Present(ZoidsTools_FBackupDB) then return ZoidsTools_FBackupDB end
    return companion and companion:GetSnapshot()
end
function recovery:Capture()
    if not loaded or not Present(source) then return false end
    ZoidsTools_FBackupDB = Copy(source)
    if companion then companion:Capture() end
    return true
end
function recovery:GetLocalPreset()
    return localPreset
end
function recovery:GetPresetSaveWarning()
    if companion and not companion.SavePreset then
        return "Your Recovery addon is outdated. Update ZoidsTools_F_Recovery alongside the main addon, then fully restart WoW before saving. Automatic reload was stopped."
    end
end
function recovery:GetPreset()
    if Present(localPreset) then return localPreset end
    if Present(ZoidsTools_FPresetDB) then return ZoidsTools_FPresetDB end
    if companion and companion.GetPreset then return companion:GetPreset() end
end
function recovery:SavePreset()
    if not loaded or not Present(source) then return false end
    ZoidsTools_FPresetDB = Copy(source)
    ZoidsTools_FRecovery = Copy(ZoidsTools_FPresetDB)
    if companion and companion.SavePreset then companion:SavePreset(ZoidsTools_FPresetDB) end
    self:Capture()
    return true
end
function recovery:Start(db)
    if not loaded or not Present(db) then return end
    source = db
    if companion then companion:Start(db) end
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
        if Present(ZoidsTools_FRecovery) then localPreset = Copy(ZoidsTools_FRecovery) end
        if not Present(ZoidsTools_FBackupDB) and companion then
            local snapshot = companion:GetSnapshot()
            if Present(snapshot) then ZoidsTools_FBackupDB = Copy(snapshot) end
        end
        -- Import personal data only on this installation; no player layout is shipped.
        if not Present(ZoidsTools_FPresetDB) and Present(ZoidsTools_FRecovery) then
            ZoidsTools_FPresetDB = Copy(ZoidsTools_FRecovery)
        end
        if not Present(ZoidsTools_FPresetDB) and companion and companion.GetPreset then
            local preset = companion:GetPreset()
            if Present(preset) then ZoidsTools_FPresetDB = Copy(preset) end
        end
        if Present(ZoidsTools_FPresetDB) then
            ZoidsTools_FRecovery = Copy(ZoidsTools_FPresetDB)
            -- Migrate old saved presets without replacing an independent restore point.
            if companion and companion.GetPreset and companion.SavePreset and not companion:GetPreset() then
                companion:SavePreset(ZoidsTools_FPresetDB)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        recovery:Capture()
    end
end)
