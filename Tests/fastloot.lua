local eventFrame
local timers, attempts = {}, {}
local count, auto, modifier, locked = 3, true, false, nil
local secret = {}
function issecretvalue(value) return value == secret end
function CreateFrame()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:SetScript(_, fn) self.handler = fn end
    return eventFrame
end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
function GetNumLootItems() return count end
function GetCVarBool() return auto end
function IsModifiedClick() return modifier end
function GetLootSlotInfo(slot) return nil, nil, nil, nil, nil, slot == locked end
function LootSlot(slot) attempts[#attempts + 1] = slot end
local function Event(event, value) eventFrame.handler(eventFrame, event, value) end
local function Flush()
    local batch = timers
    timers = {}
    for _, timer in ipairs(batch) do timer.fn() end
end
local function Reset()
    Event('LOOT_CLOSED')
    timers, attempts = {}, {}
    count, auto, modifier, locked = 3, true, false, nil
end

function RunFastLootTests(ns)
    ns:InitializeFastLoot()
    assert(not eventFrame.events.LOOT_SLOT_CLEARED)
    Event('LOOT_READY', true)
    Event('LOOT_OPENED', true)
    Flush()
    assert(#attempts == 3 and attempts[1] == 3 and attempts[3] == 1)
    Event('LOOT_OPENED', true); Flush()
    assert(#attempts == 3)
    Reset()
    ns:SetFastLootDelay(0.1)
    Event('LOOT_OPENED', true); Flush()
    assert(#timers == 3 and timers[1].delay == 0 and timers[3].delay == 0.2)
    timers[1].fn()
    Event('LOOT_CLOSED'); Flush()
    assert(#attempts == 1)
    Reset()
    ns:SetFastLootDelay(0)
    Event('LOOT_OPENED', true)
    ns:SetFastLootEnabled(false); Flush()
    assert(#attempts == 0)
    ns:SetFastLootEnabled(true)
    Reset()
    Event('LOOT_OPENED', false); Flush()
    assert(#attempts == 0)
    modifier = true
    Event('LOOT_READY'); Flush()
    assert(#attempts == 0)
    auto = false
    Event('LOOT_READY'); Flush()
    assert(#attempts == 3)
    Reset()
    locked = 2
    Event('LOOT_READY', true); Flush()
    assert(#attempts == 2 and attempts[1] == 3 and attempts[2] == 1)
    Reset()
    Event('LOOT_READY', true)
    Event('LOOT_CLOSED')
    Event('LOOT_OPENED', true); Flush()
    assert(#attempts == 3) -- Old session's callback must not loot the new corpse.
    Reset()
    count = 0
    Event('LOOT_READY', true)
    count = 3
    Event('LOOT_OPENED', true); Flush()
    assert(#attempts == 3)
    Reset()
    count = secret
    Event('LOOT_OPENED', true); Flush()
    assert(#attempts == 0)
    ns:SetFastLootDelay(9); assert(ns:GetFastLootDelay() == 0.2)
    ns:SetFastLootDelay(-1); assert(ns:GetFastLootDelay() == 0)
    Reset()
    C_Timer = nil
    Event('LOOT_OPENED', true)
    assert(#attempts == 3)
end
