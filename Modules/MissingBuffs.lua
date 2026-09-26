local _, ns = ...
local L = ns.L or setmetatable({}, {__index=function(_,k)return k end})
local frame, watcher, preview, moving
local icons={}
-- Rank families use client-resolved names, including equivalent group buffs.
local families={
 DRUID={{key="mark",ids={1126,5232,6756,5234,8907,9884,9885,21849,21850}},
        {key="thorns",optional=true,ids={467,782,1075,8914,9756,9910}}},
 PRIEST={{key="fortitude",ids={1243,1244,1245,2791,10937,10938,21562,21564}},
         {key="innerfire",ids={588,7128,602,1006,10951,10952}},
         {key="spirit",ids={14752,14818,14819,27841,27681}}},
 MAGE={{key="intellect",ids={1459,1460,1461,10156,10157,23028}},
       {key="armor",ids={168,7300,7301,7302,7320,10219,10220,6117,22782,22783}}},
 WARLOCK={{key="armor",ids={687,696,706,1086,11733,11734,11735}}},
 WARRIOR={{key="shout",ids={6673,5242,6192,11549,11550,11551,25289}}},
 SHAMAN={{key="shield",optional=true,ids={324,325,905,945,8134,8135,8136}}},
 PALADIN={{key="fury",optional=true,ids={25780}}},
}
local function Secret(v)return type(issecretvalue)=="function" and issecretvalue(v)end
local function Call(fn,...)
 if type(fn)~="function" then return end
 local ok,a,b,c=pcall(fn,...)
 if ok and not Secret(a) and not Secret(b) and not Secret(c) then return a,b,c end
end
local function Yes(v)return v==true or v==1 end
local fallback={enabled=true,disabled={},custom="",scale=1,point="CENTER",relativePoint="CENTER",x=0,y=160}
function ns:GetBuffReminderSettings()
 local guid=Call(UnitGUID,"player")
 if type(guid)~="string" or not self.db then return fallback end
 self.db.buffs=self.db.buffs or {characters={}}
 local characters=self.db.buffs.characters
 if type(characters)~="table" then characters={};self.db.buffs.characters=characters end
 local db=characters[guid]
 if type(db)~="table" then db={};characters[guid]=db end
 if type(db.disabled)~="table" then db.disabled={} end
 if type(db.custom)~="string" then db.custom="" end
 if type(db.enabled)~="boolean" then db.enabled=true end
 if type(db.locked)~="boolean" then db.locked=false end
 if type(db.scale)~="number" or db.scale~=db.scale then db.scale=1 end
 db.scale=math.max(.5,math.min(2,db.scale))
 return db
end
local function Spell(id)
 local info=Call(C_Spell and C_Spell.GetSpellInfo,id)
 if type(info)=="table" and not Secret(info.name) and type(info.name)=="string" then
  return info.name,not Secret(info.iconID) and info.iconID
 end
 local name,_,icon=Call(GetSpellInfo,id)
 if type(name)=="string" then return name,icon end
end
local function Known(id)
 return Yes(Call(C_SpellBook and C_SpellBook.IsSpellKnown,id)) or Yes(Call(IsPlayerSpell,id)) or Yes(Call(IsSpellKnown,id))
end
function ns:GetBuffReminderChoices()
 local _,class=Call(UnitClass,"player")
 return families[class] or {}
end
function ns:GetBuffReminderName(choice)
 return Spell(choice.ids[1]) or (L["Spell"].." "..choice.ids[1])
end
function ns:IsBuffReminderSelected(choice)
 local v=self:GetBuffReminderSettings().disabled[choice.key]
 if v==nil then return not choice.optional end
 return v~=true
end
function ns:SetBuffReminderSelected(choice,value)
 self:GetBuffReminderSettings().disabled[choice.key]=not value;self:RefreshMissingBuffs()
end
function ns:SetCustomBuffReminders(value)
 local ids,seen={},{}
 for token in (value or ""):gmatch("[^,%s]+") do
  local id=tonumber(token)
  if not id or id<=0 or id%1~=0 or id>2147483647 then return false,L["Enter spell IDs separated by commas."] end
  if not seen[id] then ids[#ids+1]=tostring(id);seen[id]=true end
 end
 if #ids>8 then return false,L["Choose up to eight custom spell IDs."] end
 self:GetBuffReminderSettings().custom=table.concat(ids,", ")
 self:RefreshMissingBuffs();return true,L["Custom reminders saved."]
end
local function Auras()
 local names,ids={},{}
 local modern=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if type(modern)~="function" and type(UnitBuff)~="function" then return end
 for i=1,255 do
  local name,id
  if type(modern)=="function" then
   local ok,a=pcall(modern,"player",i,"HELPFUL")
   if not ok or Secret(a) then return end
   if a==nil then return names,ids end
   if type(a)~="table" or Secret(a.name) or Secret(a.spellId) then return end
   name,id=a.name,a.spellId
  else
   local ok,n,_,_,_,_,_,_,_,_,spellID=pcall(UnitBuff,"player",i)
   if not ok or Secret(n) or Secret(spellID) then return end
   if n==nil then return names,ids end
   name,id=n,spellID
  end
  if type(name)~="string" then return end
  names[name]=true
  if type(id)=="number" then ids[id]=true end
 end
 -- No terminator means the snapshot may be incomplete; never assert absence.
end
function ns:FindMissingBuffs(isPreview)
 local names,ids=Auras()
 if not names and not isPreview then return {} end
 names,ids=names or {},ids or {}
 local choices={}
 for _,c in ipairs(self:GetBuffReminderChoices()) do if self:IsBuffReminderSelected(c) then choices[#choices+1]=c end end
 local count=0
 for id in self:GetBuffReminderSettings().custom:gmatch("%d+") do
  count=count+1;if count>8 then break end
  choices[#choices+1]={ids={tonumber(id)}}
 end
 local result,seen={},{}
 for _,c in ipairs(choices) do
  local present,known=false,false
  local name,icon=Spell(c.ids[1])
  for _,id in ipairs(c.ids) do
   local n=Spell(id)
   if ids[id] or (n and names[n]) then present=true end
   if Known(id) then known=true end
  end
  if name and not seen[name] and (isPreview or (known and not present)) then
   result[#result+1]={name=name,icon=icon or 134400};seen[name]=true
  end
 end
 return result
end
local function StopMoving()
 if not moving then return end
 frame:StopMovingOrSizing();moving=false
 local p,_,r,x,y=frame:GetPoint()
 local db=ns:GetBuffReminderSettings();db.point,db.relativePoint,db.x,db.y=p,r,x,y
end
local function CreateReminder()
 if frame then return end
 frame=CreateFrame("Frame","ZoidsTools_FMissingBuffs",UIParent)
 ns.missingBuffFrame=frame
 frame:SetClampedToScreen(true);frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag("LeftButton")
 if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
 frame.title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 frame.title:SetPoint("TOP",0,-2)
 frame:SetScript("OnDragStart",function()if not ns:GetBuffReminderSettings().locked and not Yes(Call(InCombatLockdown)) then moving=true;frame:StartMoving() end end)
 frame:SetScript("OnDragStop",StopMoving)
 frame:SetScript("OnHide",function()StopMoving();if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end end)
 local db=ns:GetBuffReminderSettings()
 local ok=pcall(frame.SetPoint,frame,db.point or "CENTER",UIParent,db.relativePoint or "CENTER",db.x or 0,db.y or 160)
 if not ok then frame:ClearAllPoints();frame:SetPoint("CENTER",0,160) end
end
function ns:RefreshMissingBuffs()
 local db=self:GetBuffReminderSettings()
 if not db.enabled or Yes(Call(InCombatLockdown)) or Yes(Call(UnitIsDeadOrGhost,"player")) or Yes(Call(IsMounted)) then
  if frame then frame:Hide() end;return
 end
 local missing=self:FindMissingBuffs(preview)
 if preview and #missing==0 then missing={{name=L["Missing buff preview"],icon=134400}} end
 if #missing==0 then if frame then frame:Hide() end;return end
 CreateReminder()
 frame:SetScale(db.scale)
 frame:SetMovable(not db.locked)
 if db.locked then
  frame.title:SetText(preview and L["Missing buff preview"] or L["Missing buffs"])
 else
  frame.title:SetText(preview and L["PREVIEW - drag to move"] or L["Missing buffs - drag to move"])
 end
 frame:SetSize(math.max(190,math.min(6,#missing)*38),20+math.ceil(#missing/6)*38)
 for i,entry in ipairs(missing) do
  local icon=icons[i]
  if not icon then icon=frame:CreateTexture(nil,"ARTWORK");icon:SetSize(32,32);icons[i]=icon end
  local row=math.floor((i-1)/6)
  local rowCount=math.min(6,#missing-row*6)
  local rowWidth=rowCount*38-6
  icon:ClearAllPoints();icon:SetPoint("TOPLEFT",frame,"TOP",-rowWidth/2+(i-1)%6*38,-20-row*38)
  icon:SetTexture(entry.icon);icon:Show()
 end
 for i=#missing+1,#icons do icons[i]:Hide() end
 frame:SetScript("OnEnter",function()
  if not GameTooltip then return end
  GameTooltip:SetOwner(frame,"ANCHOR_RIGHT");GameTooltip:SetText(L["Missing buffs"])
  for _,entry in ipairs(missing) do GameTooltip:AddLine(entry.name,1,1,1) end
  GameTooltip:AddLine(L["Reminder only. Cast buffs from your spellbook or action bars."],.7,.7,.7,true);GameTooltip:Show()
 end)
 frame:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
 frame:Show()
end
function ns:SetMissingBuffsEnabled(v)
 self:GetBuffReminderSettings().enabled=v==true;if not v then preview=false end;self:RefreshMissingBuffs()
end
function ns:SetMissingBuffScale(percent)
 if type(percent)~="number" or percent~=percent then return end
 StopMoving()
 self:GetBuffReminderSettings().scale=math.max(.5,math.min(2,percent/100))
 self:RefreshMissingBuffs()
end
function ns:SetMissingBuffsLocked(value)
 StopMoving()
 self:GetBuffReminderSettings().locked=value==true
 self:RefreshMissingBuffs()
end
function ns:ToggleMissingBuffPreview()preview=not preview;self:RefreshMissingBuffs()end
function ns:InitializeMissingBuffs()
 if watcher then return end
 watcher=CreateFrame("Frame");ns.missingBuffWatcher=watcher
 for _,event in ipairs({"UNIT_AURA","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED",
  "PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_MOUNT_DISPLAY_CHANGED","SPELLS_CHANGED","PLAYER_LOGOUT"}) do
  self:RegisterCompatibleEvent(watcher,event)
 end
 watcher:SetScript("OnEvent",function(_,event,unit)
  if event=="UNIT_AURA" and (Secret(unit) or unit~="player") then return end
  if event=="PLAYER_LOGOUT" then StopMoving();return end
  if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_DEAD" then if frame then frame:Hide() end end
  local delay=0
  watcher:SetScript("OnUpdate",function(_,dt)
   delay=delay+dt;if delay<.2 then return end
   watcher:SetScript("OnUpdate",nil);self:RefreshMissingBuffs()
  end)
 end)
 self:RefreshMissingBuffs()
end
