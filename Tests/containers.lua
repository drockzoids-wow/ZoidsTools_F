local frame,timers,items,uses,tooltips={}, {}, {}, {}, {}
local combat,shift,space,cursor=false,false,true,nil
ITEM_OPENABLE="Right Click to Open";LOCKED="Locked";NUM_BAG_SLOTS=4
function CreateFrame()
 frame={events={}}
 function frame:RegisterEvent(e)self.events[e]=true end
 function frame:SetScript(_,fn)self.handler=fn end
 return frame
end
function InCombatLockdown()return combat end
function IsShiftKeyDown()return shift end
function GetCursorInfo()return cursor end
C_Timer={After=function(delay,fn)timers[#timers+1]=fn end}
C_Container={
 GetContainerNumSlots=function(bag)return bag==0 and 5 or 0 end,
 GetContainerNumFreeSlots=function()return space and 5 or 0,0 end,
 GetContainerItemInfo=function(bag,slot)return items[slot] end,
 GetContainerItemID=function(bag,slot)return items[slot] and items[slot].itemID end,
 UseContainerItem=function(bag,slot)uses[#uses+1]=slot end,
}
C_TooltipInfo={GetBagItem=function(bag,slot)return tooltips[slot] end}
local function Event(e)frame.handler(frame,e)end
local function Flush()
 local batch=timers;timers={};for _,fn in ipairs(batch)do fn()end
end
local function Add(slot,id,locked)
 items[slot]={itemID=id,stackCount=1,hasLoot=true,isLocked=false}
 tooltips[slot]={lines={{leftText="Container"},{leftText=ITEM_OPENABLE},{leftText=locked and LOCKED or ""}}}
end
function RunContainerTests(ns)
 ns:InitializeContainerOpener();Flush();assert(#uses==0)
 Add(1,100,true);Add(2,101);Add(3,102);items[3].hasLoot=false
 Add(4,103);items[4].isLocked=true;Add(5,104);tooltips[5]=nil
 ns:SetAutoOpenContainersEnabled(true);Flush()
 assert(#uses==1 and uses[1]==2,'Only confirmed unlocked containers are opened')
 Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==1,'No duplicate in-flight use')
 Flush();assert(#uses==1,'Unchanged failed items are not retried')
 items[2].stackCount=2;Event('LOOT_OPENED');Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==1)
 Event('LOOT_CLOSED');Flush();assert(#uses==2)
 Event('LOOT_CLOSED');Flush();Flush()
 items[2].stackCount=3
 for _,pair in ipairs({{'MERCHANT_SHOW','MERCHANT_CLOSED'},{'MAIL_SHOW','MAIL_CLOSED'},
  {'BANKFRAME_OPENED','BANKFRAME_CLOSED'},{'GUILDBANKFRAME_OPENED','GUILDBANKFRAME_CLOSED'},
  {'TRADE_SHOW','TRADE_CLOSED'},{'AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED'}}) do
  local before=#uses
  Event(pair[1]);Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before)
  Event(pair[2]);Flush();assert(#uses==before+1)
  Event('LOOT_CLOSED');Flush();Flush();items[2].stackCount=items[2].stackCount+1
 end
 local before=#uses
 combat=true;Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before)
 combat=false;shift=true;Event('PLAYER_REGEN_ENABLED');Flush();assert(#uses==before)
 shift=false;space=false;Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before)
 space=true;cursor='item';Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before)
 cursor=nil;Event('BAG_UPDATE_DELAYED');ns:SetAutoOpenContainersEnabled(false);Flush();assert(#uses==before)
 ns:SetAutoOpenContainersEnabled(true);Flush();assert(#uses==before+1)
 Event('LOOT_CLOSED');Flush();Flush()
 -- Missing tooltip support must fail closed, not guess from an item name.
 local tooltipAPI=C_TooltipInfo
 C_TooltipInfo=nil;items[2].stackCount=20;Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before+1)
 C_TooltipInfo=tooltipAPI
 -- Detection uses localized game text and handles color codes.
 ITEM_OPENABLE='Ouvrir';LOCKED='Verrouille'
 Add(2,101);tooltips[2].lines[2].leftText='|cffffffffOuvrir|r'
 Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before+2)
 Event('LOOT_CLOSED');Flush();Flush()
 items[2]=nil;Event('BAG_UPDATE_DELAYED');Flush()
 Add(2,101);Event('BAG_UPDATE_DELAYED');Flush();assert(#uses==before+3,'A later container in a previously empty slot must open')
 Event('LOOT_CLOSED');Flush();Flush()
 items[2].stackCount=30
 C_Container.UseContainerItem=function()error('restricted item use')end
 Event('BAG_UPDATE_DELAYED');Flush();Flush();Flush()
 assert(#uses==before+3,'API errors are contained without repeated use')
end
