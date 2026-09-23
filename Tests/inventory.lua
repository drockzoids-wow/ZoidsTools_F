local frame, pre, post
local timers, containers = {}, {}
local player, combat, accessible, locked = "one", false, true, false
local secret = {}
function issecretvalue(value) return value == secret end
function UnitGUID() return player end
function UnitFullName() return "Zoid", player == "one" and "RealmOne" or "RealmTwo" end
function UnitClass() return "Mage", "MAGE" end
function InCombatLockdown() return combat end
function GetInventoryItemID(_, slot) if slot == 1 then return 100 end end
function GetInventoryItemLink() return "item:100 [Test]" end
NUM_BAG_SLOTS = 4
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
NUM_BANKBAGSLOTS = 7
Enum = { BagIndex = { ReagentBag = 5 }, BankType = { Character = 0, Account = 2 },
    BankLockedReason = { None = 0 }, TooltipDataType = { Item = 0 } }
C_Container = {
    GetContainerNumSlots = function(bag)
        if containers[bag] == secret then return secret end
        return containers[bag] and #containers[bag] or 0
    end,
    GetContainerItemInfo = function(bag, slot) return containers[bag][slot] end,
}
C_Bank = {
    CanViewBank = function() return accessible end,
    FetchBankLockedReason = function() return locked and 1 or 0 end,
    FetchPurchasedBankTabData = function(kind) return { { ID = kind == 0 and 6 or 15 } } end,
}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function CreateFrame()
    frame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
    return frame
end
local function Tooltip()
    local tooltip = { lines = {}, scripts = {} }
    function tooltip:AddLine(text) self.lines[#self.lines + 1] = {text} end
    function tooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = {left, right} end
    function tooltip:HasScript() return true end
    function tooltip:HookScript(name, fn) self.scripts[name] = fn end
    function tooltip:GetItem() return "Test", "item:100:0" end
    return tooltip
end
GameTooltip, ItemRefTooltip = Tooltip(), Tooltip()
TooltipDataProcessor = {
    AllTypes = 999,
    AddTooltipPreCall = function(_, fn) pre = fn end,
    AddTooltipPostCall = function(_, fn) post = fn end,
}
local function Item(count) return { itemID = 100, stackCount = count } end
local function Flush()
    local pending = timers; timers = {}
    for _, fn in ipairs(pending) do fn() end
end
local function Event(event) frame.event(frame, event); Flush() end
local function Count(ns) local _, count = ns:GetWarbandItemLocations(100); return count end

function RunInventoryTests(ns, legacy, reloadModule)
    if legacy then C_Bank = nil; TooltipDataProcessor = nil end
    containers[0], containers[5], containers[6], containers[15] = { Item(3), Item(4) }, { Item(2) }, { Item(10) }, { Item(20) }
    if legacy then containers[-1] = { Item(20) } end
    ns:InitializeWarbandItems(); ns:InitializeWarbandItems(); Flush()
    assert(Count(ns) == 10, "Bags, reagent bag, and equipment; no unseen bank")
    Event("BANKFRAME_OPENED")
    assert(Count(ns) == 40, "All storage counted once")
    Event("BANKFRAME_CLOSED")
    containers[6] = {}
    containers[0] = { Item(1) }
    Event("BAG_UPDATE_DELAYED")
    assert(Count(ns) == 34, "Closed bank preserved, bags refreshed")
    combat = true; containers[0] = { Item(8) }; Event("BAG_UPDATE_DELAYED")
    assert(Count(ns) == 34, "Combat defers capture")
    combat = false; Event("PLAYER_REGEN_ENABLED")
    assert(Count(ns) == 41)
    containers[6] = secret; Event("BANKFRAME_OPENED")
    assert(Count(ns) == 41, "Restricted bank retains snapshot")
    containers[6] = { Item(5) }; Event("BAG_CONTAINER_UPDATE")
    assert(Count(ns) == 36, "Late bank contents load")
    containers[6] = { Item(1) }
    if not legacy then
        locked = true; Event("PLAYERBANKSLOTS_CHANGED"); assert(Count(ns) == 36)
        locked = false; accessible = false; Event("PLAYERBANKSLOTS_CHANGED"); assert(Count(ns) == 36)
        accessible = true
    end
    Event("PLAYERBANKSLOTS_CHANGED"); assert(Count(ns) == 32)
    containers[6] = { false }; Event("PLAYERBANKSLOTS_CHANGED")
    assert(Count(ns) == 31, "Readable empty slots clear old items")
    Event("BANKFRAME_CLOSED")
    local old = ZoidsTools_FInventoryDB
    player = "two"; containers[0], containers[5] = { Item(4) }, {}
    ns = reloadModule(); ns:InitializeWarbandItems(); Flush()
    assert(ZoidsTools_FInventoryDB == old, "Reload keeps independent account-wide storage")
    assert(Count(ns) == 36, "Offline character plus new character")
    Event("BANKFRAME_OPENED")
    assert(Count(ns) == (legacy and 56 or 36), "Shared bank counted once across characters")
    if legacy then
        GameTooltip.scripts.OnTooltipCleared(GameTooltip)
        GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
    else
        pre(GameTooltip); post(GameTooltip, {id=100})
    end
    assert(#GameTooltip.lines >= 4)
    assert(GameTooltip.lines[3][1]:find("RealmTwo"), "Current character first, duplicate names disambiguated")
    local count = #GameTooltip.lines
    if legacy then GameTooltip.scripts.OnTooltipSetItem(GameTooltip) else post(GameTooltip, {id=100}) end
    assert(#GameTooltip.lines == count, "No duplicate tooltip rows")
    ns:SetWarbandItemTooltipsEnabled(false)
    if legacy then
        GameTooltip.scripts.OnTooltipCleared(GameTooltip); GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
    else
        pre(GameTooltip); post(GameTooltip, {id=100}); post(GameTooltip, secret)
        local scanner = Tooltip(); post(scanner, {id=100}); assert(#scanner.lines == 0)
    end
    assert(#GameTooltip.lines == count, "Disabled tooltip adds nothing")
    local total = Count(ns)
    Event("PLAYER_LEAVING_WORLD"); containers[0] = {}; Event("BAG_UPDATE_DELAYED")
    assert(Count(ns) == total, "Loading screens preserve snapshots")
    Event("PLAYER_LOGOUT"); Event("PLAYER_ENTERING_WORLD")
    assert(Count(ns) == total, "Logout cannot erase snapshots")
end
