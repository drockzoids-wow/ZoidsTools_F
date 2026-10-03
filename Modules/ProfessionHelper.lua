local _,ns=...
local frame,button,owner,bag,slot,itemID,elapsed
local modifiers={alt=true,ctrl=true,shift=true}
local function Secret(v)return issecretvalue and issecretvalue(v)end
local function Call(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and not Secret(v) then return v end
end
local function Number(v)return not Secret(v) and type(v)=="number" and v==v end
local function Combat()return InCombatLockdown and InCombatLockdown()end
function ns:GetProfessionHelperEnabled()return self.db and self.db.professions and self.db.professions.enabled==true end
function ns:GetProfessionHelperModifier()
    local v=self.db and self.db.professions and self.db.professions.modifier
    return modifiers[v] and v or "alt"
end
local function Held()
    local chosen=ns:GetProfessionHelperModifier()
    for key,fn in pairs({alt=IsAltKeyDown,ctrl=IsControlKeyDown,shift=IsShiftKeyDown}) do
        if (Call(fn)==true)~=(key==chosen) then return false end
    end
    return true
end
local function Eligible(b,s)
    if not Number(b) or not Number(s) or b<0 or b>(NUM_BAG_SLOTS or 4) or s<1 then return end
    if not (Call(IsPlayerSpell,13262) or Call(IsSpellKnown,13262)) then return end
    local info=Call(C_Container and C_Container.GetContainerItemInfo,b,s)
    if type(info)~="table" or Secret(info.isLocked) or info.isLocked or not Number(info.itemID) then return end
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(fn)~="function" then return end
    local ok,_,_,quality,_,_,_,_,_,equip,_,_,class=pcall(fn,info.itemID)
    if not ok or not Number(quality) or not Number(class) or Secret(equip) then return end
    if quality<2 or quality>4 or (class~=2 and class~=4) or equip=="INVTYPE_BODY" or equip=="INVTYPE_TABARD" then return end
    return info.itemID
end
local function Hide()
    if Combat() then return end
    if button then
        button:Hide()
        for key in pairs(modifiers)do button:SetAttribute(key.."-type1",nil)end
        button:SetAttribute("spell",nil);button:SetAttribute("target-bag",nil);button:SetAttribute("target-slot",nil)
    end
    owner,bag,slot,itemID=nil,nil,nil,nil
end
local function BagSlot(f)
    for _=1,5 do
        if not f or Call(f.IsForbidden,f) then return end
        if f==button then return owner,bag,slot end
        if type(f.GetSlotAndBagID)=="function" then
            local ok,s,b=pcall(f.GetSlotAndBagID,f)
            if ok and Number(b) and Number(s) then return f,b,s end
        elseif type(f.GetBagID)=="function" then
            local b,s=Call(f.GetBagID,f),Call(f.GetID,f)
            if Number(b) and Number(s) then return f,b,s end
        else
            local name=Call(f.GetName,f)
            if type(name)=="string" and name:match("^ContainerFrame%d+Item%d+$") then
                local parent=Call(f.GetParent,f)
                return f,parent and Call(parent.GetID,parent),Call(f.GetID,f)
            end
        end
        f=Call(f.GetParent,f)
    end
end
local function Refresh()
    if Combat() then return end
    if not ns:GetProfessionHelperEnabled() or not Held() or Call(GetCursorInfo)
        or Call(UnitIsDeadOrGhost,"player") or Call(UnitCastingInfo,"player") or Call(UnitChannelInfo,"player") then Hide();return end
    local foci=Call(GetMouseFoci)
    if type(foci)~="table" then foci={Call(GetMouseFocus)} end
    local target,b,s
    for _,f in ipairs(foci)do target,b,s=BagSlot(f);if target then break end end
    if not target or not Call(target.IsShown,target) then Hide();return end
    local id=Eligible(b,s)
    if not id then Hide();return end
    local left,bottom=Call(target.GetLeft,target),Call(target.GetBottom,target)
    local width,height=Call(target.GetWidth,target),Call(target.GetHeight,target)
    local scale=Call(target.GetEffectiveScale,target)
    local uiScale=Call(UIParent.GetEffectiveScale,UIParent)
    if not Number(left) or not Number(bottom) or not Number(width) or not Number(height)
        or not Number(scale) or not Number(uiScale) or uiScale<=0 then Hide();return end
    for key in pairs(modifiers)do button:SetAttribute(key.."-type1",nil)end
    owner,bag,slot,itemID=target,b,s,id
    button:SetAttribute(ns:GetProfessionHelperModifier().."-type1","spell")
    button:SetAttribute("spell",13262)
    button:SetAttribute("target-bag",b);button:SetAttribute("target-slot",s)
    local ratio=scale/uiScale
    button:ClearAllPoints();button:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left*ratio,bottom*ratio)
    button:SetSize(width*ratio,height*ratio)
    button:Show()
end
local function Update()
    if not frame then return end
    if not Combat() and button then
        local mod=ns:GetProfessionHelperModifier()
        local condition="[combat] blocked; [mod:"..mod
        for key in pairs(modifiers)do if key~=mod then condition=condition..",nomod:"..key end end
        -- A secure driver can hide the overlay immediately during combat or
        -- modifier release; it never shows a stale target by itself.
        RegisterStateDriver(button,"activation",condition.."] ready; blocked")
        local down=Call(C_CVar and C_CVar.GetCVarBool or GetCVarBool,"ActionButtonUseKeyDown")
        button:RegisterForClicks(down and "LeftButtonDown" or "LeftButtonUp")
    end
    local active=ns:GetProfessionHelperEnabled() and Held() and not Combat()
    elapsed=0
    frame:SetScript("OnUpdate",active and function(_,dt)
        elapsed=elapsed+dt;if elapsed>=.05 then elapsed=0;Refresh()end
    end or nil)
    if not Combat() then Refresh() end
end
function ns:SetProfessionHelperEnabled(value)
    self.db.professions.enabled=value==true;Update()
end
function ns:SetProfessionHelperModifier(value)
    self.db.professions.modifier=modifiers[value] and value or "alt";Update()
end
function ns:InitializeProfessionHelper()
    if frame or Combat() or not RegisterStateDriver then return end
    button=CreateFrame("Button","ZoidsTools_FProfessionAction",UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate,SecureHandlerEnterLeaveTemplate")
    button:SetFrameStrata("TOOLTIP");button:EnableMouse(true);button:Hide()
    button:SetAttribute("_onstate-activation",[[if newstate ~= "ready" then self:Hide() end]])
    button:SetAttribute("_onleave",[[self:Hide()]])
    local glow=button:CreateTexture(nil,"OVERLAY")
    glow:SetAllPoints();glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD");glow:SetVertexColor(.6,.4,1,.9)
    button:SetScript("PreClick",function()
        if Combat() then return end
        local _,currentBag,currentSlot=BagSlot(owner)
        if not ns:GetProfessionHelperEnabled() or not Held() or not owner or not Call(owner.IsShown,owner)
            or currentBag~=bag or currentSlot~=slot or Eligible(bag,slot)~=itemID or Call(GetCursorInfo)
            or Call(UnitIsDeadOrGhost,"player") or Call(UnitCastingInfo,"player") or Call(UnitChannelInfo,"player") then Hide() end
    end)
    button:SetScript("PostClick",function()Hide()end)
    frame=CreateFrame("Frame")
    for _,event in ipairs({"MODIFIER_STATE_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","BAG_UPDATE_DELAYED",
        "SPELLS_CHANGED","GET_ITEM_INFO_RECEIVED","CVAR_UPDATE","PLAYER_ENTERING_WORLD"}) do ns:RegisterCompatibleEvent(frame,event)end
    frame:SetScript("OnEvent",Update)
    Update()
end
