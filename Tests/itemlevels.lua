local m=getmetatable(UIParent).__index
function m:SetTextColor(r,g,b)self.color={r,g,b}end
function m:GetName()return self.name end
function m:HookScript(e,fn)local old=self.scripts[e];self.scripts[e]=function(...)if old then old(...)end;fn(...)end end
local timers,now={},10
C_Timer={After=function(delay,fn)timers[#timers+1]={at=now+delay,fn=fn}end}
local function Advance(dt)
 now=now+dt
 for _=1,20 do
  local ready={};local later={}
  for _,v in ipairs(timers)do if v.at<=now then ready[#ready+1]=v else later[#later+1]=v end end
  timers=later;if #ready==0 then return end
  for _,v in ipairs(ready)do v.fn()end
 end
 error('Timer loop')
end
function GetTime()return now end
local combat=false
function InCombatLockdown()return combat end
local events={}
local create=CreateFrame
function CreateFrame(...)
 local f=create(...);events[#events+1]=f;return f
end
local function Event(name,arg)for _,f in ipairs(events)do if f.scripts.OnEvent then f.scripts.OnEvent(f,name,arg)end end end
local secret={}
function issecretvalue(v)return v==secret end
local link='item:100'
CharacterFrame=CreateFrame('Frame');CharacterHeadSlot=CreateFrame('Button')
BankFrame=CreateFrame('Frame');BankFrameItem1=CreateFrame('Button')
ContainerFrame1=CreateFrame('Frame');ContainerFrame1.Items={CreateFrame('Button')}
local bagButton=ContainerFrame1.Items[1]
function bagButton:GetSlotAndBagID()return 1,0 end
C_Container={GetContainerItemLink=function()return link end}
function GetInventoryItemLink(_,slot)if slot==1 then return link end end
local quality,base,equip,detailed=3,40,'INVTYPE_HEAD',45
C_Item={GetItemInfo=function()return 'Hat',link,quality,base,nil,nil,nil,nil,equip end,
 GetDetailedItemLevelInfo=function()return detailed end}
GameTooltip=CreateFrame('GameTooltip','GameTooltip')
GameTooltip.unit='player';GameTooltip.lines={}
function GameTooltip:GetUnit()return 'Name',self.unit end
function GameTooltip:NumLines()return #self.lines end
function GameTooltip:AddDoubleLine(left,right)
 self.lines[#self.lines+1]={left,right}
 local index=#self.lines
 _G['GameTooltipTextRight'..index]={SetText=function(_,text)self.lines[index][2]=text end}
end
local pre,post
TooltipDataProcessor={AllTypes=0,AddTooltipPreCall=function(_,fn)pre=fn end,AddTooltipPostCall=function(_,fn)post=fn end}
Enum={TooltipDataType={Unit=1}}
local guid='A';local requests=0;local canInspect=true;local inspectValue=51.5;local equipped=40.3
function UnitIsPlayer(unit)return unit~='npc'end
function UnitGUID(unit)return unit=='player' and 'SELF' or guid end
function UnitIsUnit(a,b)return a==b end
function GetAverageItemLevel()return 80,equipped end
function CanInspect()return canInspect end
function NotifyInspect()requests=requests+1 end
function ClearInspectPlayer()end
function hooksecurefunc(a,b,c)
 if type(a)=='string'then local old=_G[a];_G[a]=function(...)local result=old(...);b(...);return result end
 else local old=a[b];a[b]=function(...)local result=old(...);c(...);return result end end
end
C_PaperDollInfo={GetInspectItemLevel=function()return inspectValue end}
local function Hover(unit)
 GameTooltip.lines={};pre(GameTooltip);GameTooltip.unit=unit;GameTooltip:Show();post(GameTooltip)
end
function RunItemLevelTests(ns)
 ns:InitializeItemLevels();Advance(.2)
 assert(CharacterHeadSlot.regions[1].text=='45' and bagButton.regions[1].text=='45' and BankFrameItem1.regions[1].text=='45')
 detailed=nil;assert(ns:ReadItemLevel(link)==40)
 quality=secret;assert(ns:ReadItemLevel(link)==nil);quality=3
 equip='';ns:RefreshItemLevels();assert(not bagButton.regions[1].shown)
 equip='INVTYPE_HEAD';link=nil;ns:RefreshItemLevels();assert(not CharacterHeadSlot.regions[1].shown)
 link='item:100';ns:SetItemLevelOverlaysEnabled(false);Advance(.2);assert(not bagButton.regions[1].shown)
 ns:SetItemLevelOverlaysEnabled(true);Advance(.2);assert(bagButton.regions[1].shown)
 ns:InitializePlayerItemLevel()
 Hover('player');assert(GameTooltip.lines[1][2]=='40.3' and requests==0,'Self uses equipped, not maximum owned ilvl')
 equipped=nil;Hover('player');assert(#GameTooltip.lines==0 and requests==0)
 Hover('mouseover');assert(requests==1 and GameTooltip.lines[1][2]=='...')
 Event('INSPECT_READY','wrong');assert(GameTooltip.lines[1][2]=='...')
 Event('INSPECT_READY','A');assert(GameTooltip.lines[1][2]=='51.5' and #GameTooltip.lines==1)
 Hover('mouseover');assert(requests==1 and GameTooltip.lines[1][2]=='51.5','Fresh cache must avoid a new inspect')
 Advance(4);guid='B';Hover('mouseover');assert(requests==2)
 guid='C';Hover('mouseover');Event('INSPECT_READY','B');assert(GameTooltip.lines[1][2]=='...','Late response cannot populate a different player')
 combat=true;Advance(9);Hover('mouseover');assert(requests==2 and #GameTooltip.lines==0)
 combat=false;canInspect=false;Hover('mouseover');assert(requests==2)
 canInspect=true;InspectFrame=CreateFrame('Frame');Hover('mouseover');assert(requests==2,'Manual Inspect UI owns inspections')
 InspectFrame:Hide();Hover('mouseover');assert(requests==3)
 inspectValue=secret;Event('INSPECT_READY','C');assert(GameTooltip.lines[1][2]=='...')
 inspectValue=60;Event('GET_ITEM_INFO_RECEIVED',100);assert(GameTooltip.lines[1][2]=='60.0')
 Advance(4);guid='D';Hover('mouseover');assert(requests==4)
 guid='OTHER';NotifyInspect('target');guid='D';Event('INSPECT_READY','D');assert(GameTooltip.lines[1][2]=='...','Another addon owns the replacement inspect')
 ns:SetTooltipItemLevelEnabled(false);Hover('mouseover');assert(#GameTooltip.lines==0)
 Hover('npc');assert(#GameTooltip.lines==0)
end
