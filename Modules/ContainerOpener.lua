local _, ns = ...
local frame, scheduled, pending, lootOpen
local attempted, interactions = {}, {}
local RequestScan

local function Secret(v)
    return type(issecretvalue)=="function" and issecretvalue(v)
end
local function Call(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and not Secret(v) then return v end
end
local function Number(v)
    if not Secret(v) and type(v)=="number" and v==v then return v end
end
local function Info(bag,slot)
    if not C_Container or type(C_Container.GetContainerItemInfo)~="function" then return end
    local v=Call(C_Container and C_Container.GetContainerItemInfo,bag,slot)
    if type(v)~="table" then return end
    if not Number(v.itemID) or not Number(v.stackCount) then return end
    if Secret(v.isLocked) or Secret(v.hasLoot) or v.isLocked or v.hasLoot~=true then return end
    return v
end
local function Signature(info)
    return info.itemID..":"..info.stackCount
end
local function Clean(text)
    if Secret(text) or type(text)~="string" then return end
    return text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
end
local function Openable(bag,slot)
    local data=Call(C_TooltipInfo and C_TooltipInfo.GetBagItem,bag,slot)
    local openText,lockedText=Clean(ITEM_OPENABLE),Clean(LOCKED)
    if not openText or not lockedText or type(data)~="table" or Secret(data.lines) or type(data.lines)~="table" then return false end
    local open=false
    for _,line in ipairs(data.lines) do
        if Secret(line) or type(line)~="table" then return false end
        for _,key in ipairs({"leftText","rightText"}) do
            if Secret(line[key]) then return false end
            local text=Clean(line[key])
            if text==lockedText then return false end
            if text==openText then open=true end
        end
    end
    return open
end
local function Safe()
    if not ns:GetAutoOpenContainersEnabled() or lootOpen or next(interactions) then return false end
    if Call(InCombatLockdown) or Call(UnitIsDeadOrGhost,"player") or Call(UnitCastingInfo,"player")
        or Call(UnitChannelInfo,"player") or Call(GetCursorInfo) or Call(IsShiftKeyDown) then return false end
    for _,name in ipairs({"MerchantFrame","MailFrame","BankFrame","GuildBankFrame","TradeFrame","AuctionFrame","AuctionHouseFrame"}) do
        local f=_G[name]
        if f and Call(f.IsShown,f) then return false end
    end
    return true
end
local function HasSpace()
    if not C_Container or not C_Container.GetContainerNumFreeSlots then return false end
    for bag=0,math.min(Number(NUM_BAG_SLOTS) or 4,5) do
        local ok,free,family=pcall(C_Container.GetContainerNumFreeSlots,bag)
        if ok and Number(free) and free>0 and Number(family)==0 then return true end
    end
    return false
end
local function Scan()
    if pending or not Safe() or not HasSpace() or not C_Container or not C_Container.UseContainerItem then return end
    for bag=0,math.min(Number(NUM_BAG_SLOTS) or 4,5) do
        local slots=Number(Call(C_Container.GetContainerNumSlots,bag)) or 0
        for slot=1,slots do
            local info=Info(bag,slot)
            local key=bag..":"..slot
            if attempted[key] and C_Container.GetContainerItemID then
                local ok,id=pcall(C_Container.GetContainerItemID,bag,slot)
                if ok and id==nil then attempted[key]=nil end
            end
            if info and attempted[key]~=Signature(info) and Openable(bag,slot) then
                if not Safe() then return end
                attempted[key]=Signature(info)
                local current={}
                pending=current
                -- Never retry an unchanged item: this also handles full bags,
                -- server refusals and clients that require a hardware click.
                pcall(C_Container.UseContainerItem,bag,slot)
                C_Timer.After(2,function()
                    if pending~=current or lootOpen then return end
                    pending=nil
                    RequestScan()
                end)
                return
            end
        end
    end
end
RequestScan=function()
    if scheduled or not ns:GetAutoOpenContainersEnabled() or not C_Timer or not C_Timer.After then return end
    scheduled=true
    C_Timer.After(.3,function() scheduled=nil;Scan() end)
end
function ns:GetAutoOpenContainersEnabled()
    return self.db and self.db.loot and self.db.loot.autoOpenContainers==true
end
function ns:SetAutoOpenContainersEnabled(value)
    self.db.loot.autoOpenContainers=value==true
    if value then attempted={};RequestScan() end
end
function ns:InitializeContainerOpener()
    if frame then return end
    frame=CreateFrame("Frame")
    local opens={MERCHANT_SHOW="merchant",MAIL_SHOW="mail",BANKFRAME_OPENED="bank",GUILDBANKFRAME_OPENED="guildbank",TRADE_SHOW="trade",AUCTION_HOUSE_SHOW="auction"}
    local closes={MERCHANT_CLOSED="merchant",MAIL_CLOSED="mail",BANKFRAME_CLOSED="bank",GUILDBANKFRAME_CLOSED="guildbank",TRADE_CLOSED="trade",AUCTION_HOUSE_CLOSED="auction"}
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","ITEM_LOCK_CHANGED","GET_ITEM_INFO_RECEIVED",
        "PLAYER_REGEN_ENABLED","PLAYER_ALIVE","PLAYER_UNGHOST","MODIFIER_STATE_CHANGED","UNIT_SPELLCAST_STOP","LOOT_OPENED","LOOT_CLOSED"}) do ns:RegisterCompatibleEvent(frame,event) end
    for event in pairs(opens) do ns:RegisterCompatibleEvent(frame,event) end
    for event in pairs(closes) do ns:RegisterCompatibleEvent(frame,event) end
    frame:SetScript("OnEvent",function(_,event)
        if opens[event] then interactions[opens[event]]=true;return end
        if closes[event] then interactions[closes[event]]=nil end
        if event=="LOOT_OPENED" then lootOpen=true;return end
        if event=="LOOT_CLOSED" then lootOpen=false;pending=nil end
        RequestScan()
    end)
    RequestScan()
end
