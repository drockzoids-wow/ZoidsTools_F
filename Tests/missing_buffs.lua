local methods={}
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:RegisterEvent(e)self.events[e]=true end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:SetPoint(...)self.point={...}end
function methods:GetPoint()return unpack(self.point)end
function methods:SetScale(value)self.scale=value end
function methods:CreateTexture()return CreateFrame()end
function methods:CreateFontString()return CreateFrame()end
for _,k in ipairs({'SetSize','SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','SetDontSavePosition','ClearAllPoints','SetText','SetTexture','StartMoving','StopMovingOrSizing'})do methods[k]=function()end end
function CreateFrame()return setmetatable({scripts={},events={}},{__index=methods})end
UIParent=CreateFrame()
local guid,class='druid-one','DRUID'
local known,auras={},{}
local combat,dead,mounted=false,false,false
local secret={}
function issecretvalue(v)return v==secret end
function UnitGUID()return guid end
function UnitClass()return class,class end
function InCombatLockdown()return combat end
function UnitIsDeadOrGhost()return dead end
function IsMounted()return mounted end
function IsPlayerSpell(id)return known[id]end
C_Spell={GetSpellInfo=function(id)return {name='Spell '..id,iconID=id}end}
C_UnitAuras={GetAuraDataByIndex=function(_,i)return auras[i]end}
function RunMissingBuffTests(ns)
 known[9885]=true;known[9910]=true
 assert(#ns:FindMissingBuffs()==1,'Only the default learned family should show')
 auras={{name='Gift',spellId=21850}}
 assert(#ns:FindMissingBuffs()==0,'Group equivalent must satisfy Mark')
 local thorns=ns:GetBuffReminderChoices()[2]
 ns:SetBuffReminderSelected(thorns,true)
 assert(#ns:FindMissingBuffs()==1,'Optional Thorns can be enabled')
 auras[2]={name='Spell 9910',spellId=999999}
 assert(#ns:FindMissingBuffs()==0,'Localized spell name matches ranks')
 auras={};known={}
 assert(#ns:FindMissingBuffs()==0,'Unlearned buffs must not warn')
 assert(ns:SetCustomBuffReminders('900,900 901'))
 assert(ns:GetBuffReminderSettings().custom=='900, 901')
 known[900]=true
 assert(#ns:FindMissingBuffs()==1)
 assert(not ns:SetCustomBuffReminders('1, bad'))
 assert(not ns:SetCustomBuffReminders('1,2,3,4,5,6,7,8,9'))
 assert(ns:GetBuffReminderSettings().custom=='900, 901','Invalid edits must preserve settings')
 local modern=C_UnitAuras.GetAuraDataByIndex
 C_UnitAuras.GetAuraDataByIndex=function()error('restricted')end
 assert(#ns:FindMissingBuffs()==0)
 C_UnitAuras.GetAuraDataByIndex=function()return {name=secret,spellId=900}end
 assert(#ns:FindMissingBuffs()==0)
 C_UnitAuras=nil
 assert(#ns:FindMissingBuffs()==0,'Unavailable aura API must suppress warnings')
 function UnitBuff(_,i)if i==1 then return 'Spell 900',nil,nil,nil,nil,nil,nil,nil,nil,900 end end
 assert(#ns:FindMissingBuffs()==0,'Legacy aura must satisfy reminder')
 UnitBuff=function()end
 assert(#ns:FindMissingBuffs()==1)
 C_UnitAuras={GetAuraDataByIndex=modern}
 ns:InitializeMissingBuffs()
 local f,w=ns.missingBuffFrame,ns.missingBuffWatcher
 assert(f.shown and not w.scripts.OnUpdate)
 local function event(e,u)w.scripts.OnEvent(w,e,u)end
 local function settle()if w.scripts.OnUpdate then w.scripts.OnUpdate(w,.3)end;assert(not w.scripts.OnUpdate)end
 event('UNIT_AURA','target');assert(not w.scripts.OnUpdate)
 combat=true;event('PLAYER_REGEN_DISABLED');assert(not f.shown);settle();assert(not f.shown)
 combat=false;event('PLAYER_REGEN_ENABLED');settle();assert(f.shown)
 dead=true;event('PLAYER_DEAD');assert(not f.shown);settle()
 dead=false;event('PLAYER_ALIVE');settle();assert(f.shown)
 mounted=true;event('PLAYER_MOUNT_DISPLAY_CHANGED');settle();assert(not f.shown)
 mounted=false;event('PLAYER_MOUNT_DISPLAY_CHANGED');settle();assert(f.shown)
 f.scripts.OnDragStart();f:SetPoint('TOP',UIParent,'TOP',44,-70);f.scripts.OnDragStop()
 assert(ns:GetBuffReminderSettings().x==44 and ns:GetBuffReminderSettings().y==-70)
 ns:SetMissingBuffsEnabled(false);assert(not f.shown)
 guid='druid-two'
 assert(ns:GetBuffReminderSettings().enabled and ns:GetBuffReminderSettings().custom=='')
 guid='druid-one';assert(not ns:GetBuffReminderSettings().enabled)
 known={};ns:SetMissingBuffsEnabled(true);assert(not f.shown)
 class='HUNTER';ns:SetCustomBuffReminders('');ns:ToggleMissingBuffPreview();assert(f.shown)
 ns:ToggleMissingBuffPreview();assert(not f.shown)
end
