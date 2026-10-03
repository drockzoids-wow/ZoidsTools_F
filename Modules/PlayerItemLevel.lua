local _,ns=...
local cache,pending={},nil
local frame,lastRequest,retry= nil,-math.huge,nil
local function Secret(v)return issecretvalue and issecretvalue(v)end
local function Call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok and not Secret(a) and not Secret(b) then return a,b end
end
local function Number(v)return not Secret(v) and type(v)=="number" and v>0 and v<math.huge end
local function Now()return Call(GetTime) or 0 end
local function Unit(tooltip)
    local _,unit=Call(tooltip.GetUnit,tooltip)
    if type(unit)~="string" or Call(UnitIsPlayer,unit)~=true then return end
    local guid=Call(UnitGUID,unit)
    if type(guid)=="string" then return unit,guid end
end
local function Busy()return InspectFrame and Call(InspectFrame.IsShown,InspectFrame)end
function ns:IsTooltipItemLevelEnabled()return self.db and self.db.tooltips and self.db.tooltips.showItemLevel==true end
local function Reset(t)t.ZTFLevelRow=nil;t.ZTFLevelGUID=nil end
local Apply
local function SetLine(t,guid,value)
    if t.ZTFLevelGUID==guid and t.ZTFLevelRow then
        local right=_G[(Call(t.GetName,t) or "GameTooltip").."TextRight"..t.ZTFLevelRow]
        if right and right.SetText then right:SetText(value);t:Show()end
        return
    end
    t:AddDoubleLine("Item Level",value,1,.82,0,1,1,1)
    t.ZTFLevelRow=Call(t.NumLines,t);t.ZTFLevelGUID=guid
end
local function Retry(guid,delay)
    if retry or not C_Timer or not C_Timer.After then return end
    local token={};retry=token
    C_Timer.After(delay,function()
        if retry~=token then return end
        retry=nil
        if GameTooltip and Call(GameTooltip.IsShown,GameTooltip) then
            local _,current=Unit(GameTooltip)
            if current==guid then Apply(GameTooltip)end
        end
    end)
end
local function Request(unit,guid)
    if Call(UnitIsUnit,unit,"player") or Call(InCombatLockdown) or Busy() or Call(CanInspect,unit)~=true
        or type(NotifyInspect)~="function" or not C_PaperDollInfo or type(C_PaperDollInfo.GetInspectItemLevel)~="function" then return end
    local now=Now()
    if pending and now-pending.time>=8 then pending=nil end
    if pending then
        if pending.guid~=guid then Retry(guid,1) end
        return true
    end
    if now-lastRequest<3 then Retry(guid,3-(now-lastRequest));return true end
    pending={unit=unit,guid=guid,time=now}
    lastRequest=now
    local request=pending
    local ok=pcall(NotifyInspect,unit)
    if not ok then pending=nil;return end
    if C_Timer and C_Timer.After then C_Timer.After(8,function()
        if pending~=request then return end
        pending=nil
        if GameTooltip and Call(GameTooltip.IsShown,GameTooltip) then
            local _,current=Unit(GameTooltip)
            if current==guid and GameTooltip.ZTFLevelGUID==guid then SetLine(GameTooltip,guid,"Unavailable")end
        end
    end)end
    return true
end
Apply=function(t)
    if t~=GameTooltip or not ns:IsTooltipItemLevelEnabled() then return end
    local unit,guid=Unit(t);if not guid then return end
    local value
    if Call(UnitIsUnit,unit,"player") then
        local _,equipped=Call(GetAverageItemLevel)
        if Number(equipped)then value=equipped end
    else
        local saved=cache[guid]
        if saved and Now()-saved.time<=120 then value=saved.value end
    end
    if value then SetLine(t,guid,string.format("%.1f",value))
    elseif Request(unit,guid)then SetLine(t,guid,"...")end
end
local function InspectReady(guid)
    if Secret(guid) or type(guid)~="string" then return end
    local request=pending
    if not request or request.guid~=guid or Call(UnitGUID,request.unit)~=guid then return end
    local value=Call(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel,request.unit)
    if not Number(value)then return end
    pending=nil
    local count=0
    for key,entry in pairs(cache)do
        if Now()-entry.time>120 then cache[key]=nil else count=count+1 end
    end
    if count>=100 then cache={}end
    cache[guid]={value=value,time=Now()}
    if GameTooltip and Call(GameTooltip.IsShown,GameTooltip)then
        local _,current=Unit(GameTooltip)
        if current==guid then Apply(GameTooltip)end
    end
end
function ns:SetTooltipItemLevelEnabled(value)
    self.db.tooltips.showItemLevel=value==true
    if not value then pending=nil;retry=nil end
end
function ns:InitializePlayerItemLevel()
    if frame or not GameTooltip then return end
    frame=CreateFrame("Frame")
    ns:RegisterCompatibleEvent(frame,"INSPECT_READY")
    ns:RegisterCompatibleEvent(frame,"GET_ITEM_INFO_RECEIVED")
    ns:RegisterCompatibleEvent(frame,"PLAYER_EQUIPMENT_CHANGED")
    frame:SetScript("OnEvent",function(_,event,guid)
        if event=="INSPECT_READY"then InspectReady(guid)
        elseif event=="GET_ITEM_INFO_RECEIVED" and pending and pending.ready then InspectReady(pending.guid)
        elseif event=="PLAYER_EQUIPMENT_CHANGED" and Call(GameTooltip.IsShown,GameTooltip)then Apply(GameTooltip)end
        if event=="INSPECT_READY" and not Secret(guid) and pending and pending.guid==guid then pending.ready=true end
    end)
    -- Observe competing requests without clearing another addon's inspection.
    if hooksecurefunc and type(NotifyInspect)=="function"then hooksecurefunc("NotifyInspect",function(unit)
        lastRequest=Now()
        if pending and Call(UnitGUID,unit)~=pending.guid then pending=nil end
    end)end
    if hooksecurefunc and type(ClearInspectPlayer)=="function"then hooksecurefunc("ClearInspectPlayer",function()pending=nil end)end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AddTooltipPreCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes,Reset)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,Apply)
    elseif GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetUnit")then
        GameTooltip:HookScript("OnTooltipCleared",Reset)
        GameTooltip:HookScript("OnTooltipSetUnit",Apply)
    end
    if GameTooltip.HookScript then GameTooltip:HookScript("OnHide",function(t)Reset(t);retry=nil end)end
end
