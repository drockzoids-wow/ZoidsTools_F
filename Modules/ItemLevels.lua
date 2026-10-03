local _,ns=...
local labels,hooks={},{}
local frame,queued
local function Secret(v)return issecretvalue and issecretvalue(v)end
local function Call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok and not Secret(a) and not Secret(b) then return a,b end
end
local function Number(v)return not Secret(v) and type(v)=="number" and v==v and v>0 and v<math.huge end
function ns:GetItemLevelOverlaysEnabled()return self.db and self.db.tooltips and self.db.tooltips.itemLevelOverlays==true end
function ns:ReadItemLevel(link)
    if Secret(link) or type(link)~="string" then return end
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(fn)~="function" then return end
    local ok,_,_,quality,base,_,_,_,_,equip=pcall(fn,link)
    if not ok or Secret(equip) or type(equip)~="string" or equip=="" or equip=="INVTYPE_BAG"
        or equip=="INVTYPE_BODY" or equip=="INVTYPE_TABARD" or Secret(quality) or type(quality)~="number" then return end
    local level=Call(C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo,link)
    if not Number(level) then level=base end
    if Number(level) then return level,quality end
end
local slots={Head=1,Neck=2,Shoulder=3,Chest=5,Waist=6,Legs=7,Feet=8,Wrist=9,Hands=10,
    Finger0=11,Finger1=12,Trinket0=13,Trinket1=14,Back=15,MainHand=16,SecondaryHand=17,Ranged=18}
local function Label(b,link)
    if not b or Call(b.IsForbidden,b) then return end
    local level,quality
    if ns:GetItemLevelOverlaysEnabled() then level,quality=ns:ReadItemLevel(link) end
    local text=labels[b]
    if not level then if text then text:Hide()end;return end
    if not text then
        if Call(InCombatLockdown) then return end
        text=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall")
        text:SetPoint("TOPRIGHT",b,"TOPRIGHT",-2,-2);labels[b]=text
    end
    text:SetText(tostring(math.floor(level+.5)))
    local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    text:SetTextColor(color and color.r or 1,color and color.g or .82,color and color.b or 0)
    text:Show()
end
local Queue
local function Hook(f)
    if not f or hooks[f] then return end
    hooks[f]=true
    if f.HookScript then f:HookScript("OnShow",function()Queue()end)end
    if hooksecurefunc and type(f.UpdateItems)=="function" then hooksecurefunc(f,"UpdateItems",function()Queue()end)end
end
local function BagButton(b,defaultBag,defaultSlot)
    if not b or Call(b.IsForbidden,b) then return end
    local bag,slot=defaultBag,defaultSlot
    if b.GetSlotAndBagID then slot,bag=Call(b.GetSlotAndBagID,b)
    elseif b.GetBagID then bag=Call(b.GetBagID,b);slot=Call(b.GetID,b) end
    local link
    if not Secret(bag) and not Secret(slot) and type(bag)=="number" and type(slot)=="number" then
        link=Call(C_Container and C_Container.GetContainerItemLink or GetContainerItemLink,bag,slot)
    end
    Label(b,link)
end
local function Container(f)
    if not f then return end
    Hook(f)
    if not Call(f.IsShown,f) then return end
    if type(f.EnumerateValidItems)=="function" then
        pcall(function()for a,b in f:EnumerateValidItems()do BagButton(b or a)end end)
    elseif type(f.Items)=="table" then
        for _,b in pairs(f.Items)do BagButton(b)end
    end
end
function ns:RefreshItemLevels()
    -- Clear every prior label first, including recycled or empty bank slots.
    for _,text in pairs(labels)do text:Hide()end
    if not self:GetItemLevelOverlaysEnabled() then return end
    for _,prefix in ipairs({"Character","Inspect"})do
        local panel=_G[prefix.."Frame"];Hook(panel)
        if panel and Call(panel.IsShown,panel) then
            local unit=prefix=="Character" and "player" or panel.unit
            if not Secret(unit) and type(unit)=="string" then
                for name,slot in pairs(slots)do Label(_G[prefix..name.."Slot"],Call(GetInventoryItemLink,unit,slot))end
            end
        end
    end
    Container(ContainerFrameCombinedBags)
    if ContainerFrameContainer and type(ContainerFrameContainer.ContainerFrames)=="table" then
        for _,f in pairs(ContainerFrameContainer.ContainerFrames)do Container(f)end
    end
    for i=1,13 do
        local f=_G["ContainerFrame"..i];Container(f)
        if f and Call(f.IsShown,f) then
            local bag=Call(f.GetID,f)
            for j=1,100 do
                local b=_G["ContainerFrame"..i.."Item"..j]
                if b then BagButton(b,bag,Call(b.GetID,b))end
            end
        end
    end
    Hook(BankFrame);Container(BankPanel)
    if BankFrame and Call(BankFrame.IsShown,BankFrame) then
        for i=1,28 do BagButton(_G["BankFrameItem"..i],-1,i)end
    end
end
Queue=function()
    if queued then return end
    queued=true
    local function run()queued=nil;ns:RefreshItemLevels()end
    if C_Timer and C_Timer.After then C_Timer.After(.1,run)else run()end
end
function ns:SetItemLevelOverlaysEnabled(value)self.db.tooltips.itemLevelOverlays=value==true;Queue()end
function ns:InitializeItemLevels()
    if frame then return end
    frame=CreateFrame("Frame")
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","ADDON_LOADED","PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE_DELAYED",
        "BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT",
        "PLAYER_REGEN_ENABLED","INSPECT_READY","BANK_TABS_CHANGED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED"})do ns:RegisterCompatibleEvent(frame,event)end
    frame:SetScript("OnEvent",Queue)
    if hooksecurefunc and type(ContainerFrame_UpdateAll)=="function" then hooksecurefunc("ContainerFrame_UpdateAll",Queue)end
    Queue()
end
