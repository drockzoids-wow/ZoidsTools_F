local _, ns = ...
local events, visit
local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok and not Secret(a) and not Secret(b) then return a, b end
end
local function IsOpen(session)
    return visit == session and MerchantFrame and MerchantFrame:IsShown()
end

local function SellJunk(session, final)
    if session.sold or not ns.db.vendor.autoSellJunk then return end
    local api = C_MerchantFrame
    local button = MerchantSellAllJunkButton
    if not api or type(api.SellAllJunkItems) ~= "function" then
        if final then ns:Print("Auto sell unavailable: this client has no bulk junk-sale API.") end
        return
    end
    if not button or not button:IsShown() then return end
    if api.IsSellAllJunkEnabled and Call(api.IsSellAllJunkEnabled) ~= true then return end
    local count = Call(api.GetNumJunkItems)
    if count == 0 then session.sold = true; return end
    if not button:IsEnabled() then return end
    session.sold = true -- Set before calling: money/bag events can fire synchronously.
    -- This is the exact bulk action used by the vendor confirmation's Yes
    -- callback. No popup is created and no global popup handler is replaced.
    local ok, result = pcall(api.SellAllJunkItems)
    if not ok or result == false then ns:Print("Auto sell could not complete the bulk junk sale.") end
end

local function Repair(session, final)
    local mode = ns.db.vendor.autoRepairMode
    if session.repaired or mode == "disabled" then return end
    if Call(CanMerchantRepair) ~= true then return end
    local cost, needed = Call(GetRepairAllCost)
    if not needed or type(cost) ~= "number" or cost <= 0 then return end
    local guild = mode == "guild"
    local funds, available
    if guild then
        funds = Call(GetGuildBankMoney)
        local allowance = Call(GetGuildBankWithdrawMoney)
        available = Call(CanGuildBankRepair) == true and type(funds) == "number" and funds >= cost
            and type(allowance) == "number" and (allowance == -1 or allowance >= cost)
    elseif mode == "personal" then
        funds = Call(GetMoney)
        available = type(funds) == "number" and funds >= cost
    else
        return
    end
    if not available then
        if final then
            ns:Print(guild and "Auto repair skipped: guild funds, allowance, or permission unavailable."
                or "Auto repair skipped: not enough gold.")
        end
        return
    end
    if type(RepairAllItems) ~= "function" then return end
    session.repaired = true
    local ok, result = pcall(RepairAllItems, guild)
    if not ok or result == false then ns:Print("Auto repair could not complete.") end
end

local function Run(session, final)
    if not IsOpen(session) or (InCombatLockdown and InCombatLockdown()) then return end
    SellJunk(session, final)
    if IsOpen(session) then Repair(session, final) end
end

function ns:InitializeVendorAutomation()
    if events then return end
    events = CreateFrame("Frame")
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then visit = nil; return end
        -- Holding Shift when opening a vendor skips this entire visit.
        local session = {}
        visit = session
        if IsShiftKeyDown and IsShiftKeyDown() then return end
        if C_Timer and C_Timer.After then
            -- Allow native controls to initialize and proceeds to arrive before
            -- deciding that a player cannot afford repairs. At most one sale
            -- and one repair request per visit, including duplicate callbacks.
            for index, delay in ipairs({ 0.1, 0.4, 1.0 }) do
                local final = index == 3
                C_Timer.After(delay, function() Run(session, final) end)
            end
        else
            Run(session, true)
        end
    end)
end
