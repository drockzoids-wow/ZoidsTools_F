local _, ns = ...
local watcher, target, pending

-- English zone names are intentional: Forever's new maps need not share retail map IDs.
local alliance = {
    ["Ironforge"] = 47, ["Dun Morogh"] = 47, ["Loch Modan"] = 47, ["Wetlands"] = 47,
    ["Stormwind City"] = 72, ["Stormwind"] = 72, ["Elwynn Forest"] = 72,
    ["Westfall"] = 72, ["Redridge Mountains"] = 72, ["Duskwood"] = 72,
    ["Darnassus"] = 69, ["Teldrassil"] = 69, ["Darkshore"] = 69,
}
local horde = {
    ["Orgrimmar"] = 76, ["Durotar"] = 76,
    ["Thunder Bluff"] = 81, ["Mulgore"] = 81,
    ["Undercity"] = 68, ["Tirisfal Glades"] = 68, ["Silverpine Forest"] = 68,
}
local towns = {
    ["Booty Bay"] = 21, ["Ratchet"] = 470, ["Gadgetzan"] = 369, ["Everlook"] = 577,
}
local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not Secret(value) then return value end
end
local function Name(fn)
    local value = Call(fn)
    return type(value) == "string" and value or ""
end

function ns:GetZoneReputationEnabled()
    return self.db and self.db.reputation and self.db.reputation.autoZone == true
end

local function DesiredFaction()
    -- Avoid assigning outdoor city reputations to dungeons and battlegrounds.
    if Call(IsInInstance) then return nil end
    local zone, subzone = Name(GetRealZoneText), Name(GetSubZoneText)
    local side = Call(UnitFactionGroup, "player")
    local zones = side == "Alliance" and alliance or side == "Horde" and horde or {}
    return towns[subzone] or towns[zone] or zones[subzone] or zones[zone]
end

local function WatchFaction(id)
    local api = C_Reputation
    if api and type(api.SetWatchedFactionByID) == "function" then
        local data = Call(api.GetFactionDataByID, id)
        if type(data) ~= "table" or Secret(data.name) or type(data.name) ~= "string"
            or Secret(data.isHeader) or Secret(data.isHeaderWithRep)
            or (data.isHeader and not data.isHeaderWithRep) then return false end
        local watched = Call(api.GetWatchedFactionData)
        if type(watched) == "table" and not Secret(watched.factionID) and watched.factionID == id then return true end
        local ok, result = pcall(api.SetWatchedFactionByID, id)
        return ok and not Secret(result) and result ~= false
    end
    -- Legacy fallback only visits visible entries; never expand/collapse the user's reputation list.
    local count = Call(GetNumFactions)
    if type(count) ~= "number" or count < 0 or count > 1000
        or type(GetFactionInfo) ~= "function" or type(SetWatchedFactionIndex) ~= "function" then return false end
    for index = 1, count do
        local ok, name, _, _, _, _, _, _, _, header, _, hasRep, watched, factionID = pcall(GetFactionInfo, index)
        if ok and not Secret(factionID) and factionID == id and not Secret(name) and type(name) == "string"
            and not Secret(header) and not Secret(hasRep) and (not header or hasRep) then
            if not Secret(watched) and watched then return true end
            local success, result = pcall(SetWatchedFactionIndex, index)
            return success and not Secret(result) and result ~= false
        end
    end
    return false
end

function ns:RefreshZoneReputation(force)
    if not self:GetZoneReputationEnabled() then target, pending = nil, false; return end
    local desired = DesiredFaction()
    if force or desired ~= target then target, pending = desired, desired ~= nil end
    if not pending or not target or (InCombatLockdown and InCombatLockdown()) then return end
    -- Clear before calling the setter: it can itself trigger UPDATE_FACTION.
    pending = false
    if not WatchFaction(target) then pending = true end
end

function ns:SetZoneReputationEnabled(value)
    if not self.db or not self.db.reputation then return end
    self.db.reputation.autoZone = value == true
    self:RefreshZoneReputation(true)
end

function ns:InitializeZoneReputation()
    if watcher then return end
    watcher = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "UPDATE_FACTION" }) do
        self:RegisterCompatibleEvent(watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_FACTION" or event == "PLAYER_REGEN_ENABLED" then
            if pending then self:RefreshZoneReputation() end
        else
            self:RefreshZoneReputation()
        end
    end)
    self:RefreshZoneReputation(true)
end
