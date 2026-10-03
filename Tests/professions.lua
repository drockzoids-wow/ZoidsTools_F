local m=getmetatable(UIParent).__index
local combat,alt,ctrl,shift,known,quality,class,locked=false,false,false,false,true,2,4,false
local bagID,slotID,id=0,1,100
local frames={}
local create=CreateFrame
function CreateFrame(...)
 local f=create(...);frames[#frames+1]=f;f.attrs={};return f
end
function m:SetAttribute(k,v)assert(not combat,'Protected write during combat');self.attrs[k]=v end
function m:GetAttribute(k)return self.attrs[k]end
function m:GetLeft()return 100 end
function m:GetBottom()return 50 end
function m:GetEffectiveScale()return 1 end
function m:GetParent()return self.parent end
function m:RegisterForClicks(v)self.clicks=v end
function m:SetBlendMode()end
function RegisterStateDriver(f,state,condition)f.driver=condition end
function InCombatLockdown()return combat end
function IsAltKeyDown()return alt end
function IsControlKeyDown()return ctrl end
function IsShiftKeyDown()return shift end
function IsPlayerSpell()return known end
local item=CreateFrame('Button','TestBagItem',UIParent);item:SetSize(32,32)
function item:GetSlotAndBagID()return slotID,bagID end
local focus=item
function GetMouseFoci()return {focus}end
C_Container={GetContainerItemInfo=function()return {itemID=id,isLocked=locked}end}
C_Item={GetItemInfo=function()return 'Item','link',quality,10,1,'Armor','Cloth',1,'INVTYPE_HEAD',1,1,class end}
local function Event(e)
 for _,f in ipairs(frames)do if f.scripts.OnEvent then f.scripts.OnEvent(f,e)end end
end
function RunProfessionTests(ns)
 ns:InitializeProfessionHelper()
 local b=ZoidsTools_FProfessionAction
 assert(not b.shown and not b.attrs.type1)
 alt=true;ns:SetProfessionHelperEnabled(true)
 assert(b.shown and b.attrs['alt-type1']=='spell' and b.attrs.spell==13262)
 assert(b.attrs['target-bag']==0 and b.attrs['target-slot']==1)
 assert(b.driver:find('[combat] blocked',1,true))
 focus=b;Event('BAG_UPDATE_DELAYED');assert(b.shown,'Overlay hover must retain the actual bag target')
 b.scripts.PreClick();assert(b.attrs['alt-type1']=='spell')
 id=101;b.scripts.PreClick();assert(not b.shown and not b.attrs.spell,'Changed item invalidates the pending click')
 focus=item;Event('BAG_UPDATE_DELAYED');assert(b.shown)
 slotID=2;b.scripts.PreClick();assert(not b.shown,'Recycled bag buttons cannot target the old slot')
 Event('BAG_UPDATE_DELAYED');assert(b.attrs['target-slot']==2)
 ctrl=true;Event('MODIFIER_STATE_CHANGED');assert(not b.shown,'Extra modifiers must not disenchant')
 alt=false;ns:SetProfessionHelperModifier('ctrl');assert(b.shown and b.attrs['ctrl-type1']=='spell' and not b.attrs['alt-type1'])
 known=false;Event('SPELLS_CHANGED');assert(not b.shown)
 known=true;quality=1;Event('BAG_UPDATE_DELAYED');assert(not b.shown)
 quality=5;Event('BAG_UPDATE_DELAYED');assert(not b.shown)
 quality=3;class=7;Event('BAG_UPDATE_DELAYED');assert(not b.shown)
 class=2;locked=true;Event('BAG_UPDATE_DELAYED');assert(not b.shown)
 locked=false;bagID=-1;Event('BAG_UPDATE_DELAYED');assert(not b.shown)
 bagID=5;Event('BAG_UPDATE_DELAYED');assert(not b.shown)
 bagID=0;Event('BAG_UPDATE_DELAYED');assert(b.shown)
 combat=true;b.shown=false -- The secure combat state hides it before insecure events run.
 Event('PLAYER_REGEN_DISABLED');ns:SetProfessionHelperEnabled(false)
 for _,f in ipairs(frames)do assert(not f.scripts.OnUpdate)end
 combat=false;Event('PLAYER_REGEN_ENABLED');assert(not b.shown and not b.attrs.spell)
 ns:SetProfessionHelperEnabled(true);assert(b.shown)
 ctrl=false;Event('MODIFIER_STATE_CHANGED');assert(not b.shown)
 for _,f in ipairs(frames)do assert(not f.scripts.OnUpdate)end
end
