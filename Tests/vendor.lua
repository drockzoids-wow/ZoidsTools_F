local handler, timers = nil, {}
local shown, buttonShown, buttonEnabled, bulkEnabled, shift, combat = true, true, true, true, false, false
local sales, repairs, junk, money, cost, allowance, guildFunds = 0, {}, 3, 20, 100, 200, 1000
local guildAllowed = true
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end }
end
MerchantFrame = { IsShown = function() return shown end }
MerchantSellAllJunkButton = { IsShown = function() return buttonShown end, IsEnabled = function() return buttonEnabled end }
C_MerchantFrame = {
    IsSellAllJunkEnabled = function() return bulkEnabled end,
    GetNumJunkItems = function() return junk end,
    SellAllJunkItems = function() sales = sales + 1; junk = 0 end,
}
function StaticPopup_Show() error('Must not open popups') end
function StaticPopup_ShowCustomGenericConfirmation() error('Must not open popups') end
function IsShiftKeyDown() return shift end
function InCombatLockdown() return combat end
function CanMerchantRepair() return true end
function GetRepairAllCost() return cost, cost > 0 end
function GetMoney() return money end
function CanGuildBankRepair() return guildAllowed end
function GetGuildBankWithdrawMoney() return allowance end
function GetGuildBankMoney() return guildFunds end
function RepairAllItems(guild) repairs[#repairs + 1] = guild and 'guild' or 'personal' end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush()
    local queued = timers; timers = {}
    for _, callback in ipairs(queued) do callback() end
end
local function Open() handler(nil, 'MERCHANT_CLOSED'); handler(nil, 'MERCHANT_SHOW') end
function RunVendorTests(ns)
    ns:InitializeVendorAutomation()
    Open(); Flush()
    assert(sales == 0 and #repairs == 0)
    ns.db.vendor.autoSellJunk = true
    ns.db.vendor.autoRepairMode = 'personal'
    Open()
    table.remove(timers, 1)()
    assert(sales == 1 and #repairs == 0)
    money = 150 -- Sale proceeds arrive after the first callback.
    Flush()
    assert(sales == 1 and #repairs == 1 and repairs[1] == 'personal')
    junk = 3
    Open(); handler(nil, 'MERCHANT_CLOSED'); Flush()
    assert(sales == 1 and #repairs == 1)
    Open(); Open(); Flush() -- Callbacks from the old visit must be ignored.
    assert(sales == 2 and #repairs == 2)
    shift = true; Open(); Flush(); shift = false
    assert(sales == 2 and #repairs == 2)
    junk = 3; buttonShown = false
    ns.db.vendor.autoRepairMode = 'disabled'
    Open(); Flush(); assert(sales == 2)
    buttonShown = true; buttonEnabled = false
    Open(); Flush(); assert(sales == 2)
    buttonEnabled = true; bulkEnabled = false
    Open(); Flush(); assert(sales == 2)
    bulkEnabled = true
    local sell = C_MerchantFrame.SellAllJunkItems
    C_MerchantFrame.SellAllJunkItems = nil
    Open(); Flush(); assert(sales == 2)
    C_MerchantFrame.SellAllJunkItems = sell
    ns.db.vendor.autoSellJunk = false
    ns.db.vendor.autoRepairMode = 'guild'
    allowance = 50
    Open(); Flush(); assert(#repairs == 2) -- No personal fallback.
    allowance = -1
    Open(); Flush(); assert(#repairs == 3 and repairs[3] == 'guild')
    guildAllowed = false
    Open(); Flush(); assert(#repairs == 3)
    ns.db.vendor.autoSellJunk = true
    combat = true
    Open(); Flush(); assert(sales == 2 and #repairs == 3)
    combat = false; shown = false
    Open(); Flush(); assert(sales == 2 and #repairs == 3)
    shown = true; ns.db.vendor.autoRepairMode = 'personal'; money = 0
    ns.db.vendor.autoSellJunk = false
    Open(); Flush(); assert(#repairs == 3)
end
