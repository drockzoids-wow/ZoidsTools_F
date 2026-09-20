local frame
function CreateFrame()
    frame = { events = {} }
    function frame:RegisterEvent(e) self.events[e] = true end
    function frame:SetScript(e, fn) self[e] = fn end
    return frame
end
local zone, subzone, side, combat, instance = "Dun Morogh", "Kharanos", "Alliance", false, false
function GetRealZoneText() return zone end
function GetSubZoneText() return subzone end
function UnitFactionGroup() return side end
function InCombatLockdown() return combat end
function IsInInstance() return instance end
local secret = {}
function issecretvalue(v) return v == secret end
local watched, calls, unavailable, fail = nil, 0, false, false
C_Reputation = {
    GetFactionDataByID = function(id)
        if unavailable then return nil end
        return { name = "Faction", factionID = id, isHeader = false }
    end,
    GetWatchedFactionData = function() return { factionID = watched } end,
    SetWatchedFactionByID = function(id)
        assert(not combat, "Reputation changes must wait until combat ends")
        if fail then error("unavailable") end
        watched = id; calls = calls + 1
        frame.OnEvent(frame, "UPDATE_FACTION")
    end,
}
function RunReputationTests(ns)
    ns:InitializeZoneReputation()
    assert(watched == 47 and calls == 1 and not frame.OnUpdate)
    ns:InitializeZoneReputation(); assert(calls == 1)
    local function event(e) frame.OnEvent(frame, e or "ZONE_CHANGED") end
    event(); event("UPDATE_FACTION"); assert(calls == 1)
    watched = 72; event("UPDATE_FACTION"); event(); assert(watched == 72)
    zone = "Unknown"; subzone = ""; event(); assert(watched == 72)
    zone = "Loch Modan"; event(); assert(watched == 47)
    zone = "Wetlands"; event(); assert(watched == 47)
    zone = "Elwynn Forest"; combat = true; event(); assert(watched == 47)
    zone = "Darkshore"; event()
    combat = false; event("PLAYER_REGEN_ENABLED"); assert(watched == 69)
    zone = "Dun Morogh"; combat = true; event()
    zone = "Unknown"; event()
    combat = false; event("PLAYER_REGEN_ENABLED"); assert(watched == 69)
    zone = "Dun Morogh"; unavailable = true; event(); assert(watched == 69)
    unavailable = false; event("UPDATE_FACTION"); assert(watched == 47)
    zone = "Elwynn Forest"; fail = true; event(); assert(watched == 47)
    fail = false; event("UPDATE_FACTION"); assert(watched == 72)
    zone = "Dun Morogh"; instance = true; event(); assert(watched == 72)
    instance = false; event(); assert(watched == 47)
    ns:SetZoneReputationEnabled(false)
    zone = "Elwynn Forest"; event(); assert(watched == 47)
    ns:SetZoneReputationEnabled(true); assert(watched == 72)
    side = "Horde"; zone = "Dun Morogh"; event(); assert(watched == 72)
    zone = "Durotar"; event(); assert(watched == 76)
    subzone = "Ratchet"; event(); assert(watched == 470)
    subzone = ""; zone = "Mulgore"; event(); assert(watched == 81)
    zone = "Silverpine Forest"; event(); assert(watched == 68)
    zone = secret; subzone = secret; event(); assert(watched == 68)
    -- Hidden legacy entries remain untouched; a later list update can retry.
    C_Reputation = nil
    side = "Alliance"; zone = "Dun Morogh"; subzone = ""
    local visible = false
    function GetNumFactions() return visible and 2 or 1 end
    function GetFactionInfo(index)
        if index == 1 then return "Alliance", nil, nil, nil, nil, nil, nil, nil, true end
        return "Ironforge", nil, nil, nil, nil, nil, nil, nil, false, false, true, false, 47
    end
    function SetWatchedFactionIndex(index) assert(index == 2); watched = 47 end
    event(); assert(watched == 68)
    visible = true; event("UPDATE_FACTION"); assert(watched == 47)
    GetNumFactions = nil; zone = "Elwynn Forest"; event(); assert(watched == 47)
end
