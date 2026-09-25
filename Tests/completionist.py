from pathlib import Path
import sys
base=Path(__file__).resolve().parents[1]
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--runtime')
args=parser.parse_args()
if args.runtime: sys.path.insert(0,args.runtime)
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
frame_stubs='''
local methods={}
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:RegisterEvent(e)self.events[e]=true end
function methods:SetShown(v)
 local changed=self.shown~=v;self.shown=v
 if changed then local fn=self.scripts[v and "OnShow" or "OnHide"];if fn then fn(self)end end
end
function methods:Show()self:SetShown(true)end
function methods:Hide()self:SetShown(false)end
function methods:IsShown()return self.shown end
function methods:SetText(t)self.text=t;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self)end end
function methods:GetText()return self.text or "" end
function methods:GetPoint()return "CENTER",UIParent,"CENTER",0,0 end
function methods:CreateFontString()return CreateFrame(nil,nil,self)end
function methods:CreateTexture()return CreateFrame()end
function methods:SetOrientation(v)self.orientation=v end
function methods:SetThumbTexture(v)self.thumb=v end
function methods:SetAllPoints()end
function methods:SetColorTexture()end
function methods:SetValue(v)self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v)end end
function methods:SetMinMaxValues(lo,hi)assert(lo<=hi);self.lo=lo;self.hi=hi end
function methods:SetChecked(v)self.checked=v end
function methods:GetChecked()return self.checked end
function methods:SetEnabled(v)self.enabled=v end
function methods:SetDontSavePosition(v)self.dontSavePosition=v end
for _,n in ipairs({"SetSize","SetPoint","SetClampedToScreen","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetMovable","EnableMouse","RegisterForDrag","StartMoving","StopMovingOrSizing","ClearAllPoints","SetWidth","SetJustifyH","SetAutoFocus","ClearFocus","SetHighlightTexture","EnableMouseWheel","SetValueStep","SetWordWrap"})do methods[n]=function()end end
function methods:SetHeight(h)self.height=h end
function methods:GetLeft()return 120 end
function methods:GetTop()return 700 end
function methods:SetSize(w,h)self.width=w;self.height=h end
function methods:StartMoving()self.starts=(self.starts or 0)+1 end
function methods:StopMovingOrSizing()self.stops=(self.stops or 0)+1 end
function methods:SetPoint(...)self.point={...}end
function methods:SetWidth(w)self.width=w end
function methods:SetWordWrap(v)self.wrap=v end
function methods:SetJustifyV()end
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({shown=true,scripts={},events={},template=template,parent=parent},{__index=methods})
 if kind=="Slider" and template=="UIPanelScrollBarTemplate" then
  f.scripts.OnValueChanged=function(_,value)parent:SetVerticalScroll(value)end
 end
 return f
end
UIParent=CreateFrame();SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function()end}
-- Reproduce the user's failure: the real template expects a ScrollFrame parent.
local broken=CreateFrame("Slider",nil,UIParent,"UIPanelScrollBarTemplate")
local ok,err=pcall(broken.SetValue,broken,0);assert(not ok and err:find("SetVerticalScroll"))
function UnitFactionGroup()return "Alliance" end
function UnitClass()return "Warrior","WARRIOR" end
zone="Elwynn Forest";function GetZoneText()return zone end
complete={};active={};ready={};reads=0
C_QuestLog={
 GetAllCompletedQuestIDs=function()local t={};for id,v in pairs(complete)do if v then t[#t+1]=id end end;return t end,
 IsQuestFlaggedCompleted=function(id)reads=reads+1;return complete[id] or false end,
 IsOnQuest=function(id)return active[id] or false end,
 IsComplete=function(id)return ready[id] or false end
}
ZoidsTools_FDB={sentinel=true,pins={sentinel=true}}

ZoidsTools_FCompletionistDB={done={[783]=true},skipped={[7]=true},active=783,phase="objective",arrow=true}
'''
lua.execute(frame_stubs)
root=lua.table();root.version='0.2.4-beta'
lua.execute((base/'Completionist/Bootstrap.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', root)
ns=root.Completionist;lua.globals().ns=ns
compile_lua=lua.eval('function(s,n)local f,e=loadstring(s,n);assert(f,e);return f end')
addon=base/'Completionist'
files=[line.split('\\')[-1] for line in (base/'ZoidsTools_F.toc').read_text().splitlines() if line.startswith('Completionist\\') and not line.endswith('Bootstrap.lua')]
assert 'Arrow.lua' not in files
for filename in (f for f in files if f.endswith(".lua")):compile_lua((addon/filename).read_text(encoding='utf-8'),filename)('ZoidsTools_F',root)
lua.execute('''
function event(e,a)ns.events.scripts.OnEvent(ns.events,e,a)end
function finish()for i=1,100 do ns.Tick(.1)end;assert(not ns.scan and not ns.waiting)end
event("ADDON_LOADED","ZoidsTools_F");event("PLAYER_LOGIN")
assert(#ns.quests==6090 and ns.scan and reads==0)
ns.Tick(.01);assert(reads<=150 and ns.scan)
finish();assert(ZoidsTools_FDB.sentinel and ZoidsTools_FDB.pins.sentinel)
assert(ns.Status(783)=="incomplete" and ns.char.done[783])
assert(ns.char.factionFilter=="Mine" and ns.char.area=="Elwynn Forest")
assert(ns.Eligible({side="Alliance",classMask=1}))
assert(not ns.Eligible({side="Horde",classMask=0}))
assert(not ns.Eligible({side="Alliance",classMask=128}))
assert(ns.window and not ns.arrow and not ns.Select and not ns.SavePin)
complete[783]=true;active[7]=true;ready[7]=true;active[15]=true
ns.Sync(false);finish()
assert(ns.Status(783)=="completed" and ns.Status(7)=="ready" and ns.Status(15)=="progress")
complete[7]=true;ns.Sync(false);finish();assert(ns.Status(7)=="ready")
active[7]=nil;ready[7]=nil;event("QUEST_TURNED_IN",7);finish();assert(ns.Status(7)=="completed")
complete[7]=false;ns.Sync(false);finish();assert(ns.Status(7)=="incomplete")
local modern=C_QuestLog;C_QuestLog={};ns.Sync(false);finish();assert(ns.Status(783)=="unknown")
ns.char.statusFilter="Unfinished";assert(not ns.MatchesStatus("unknown"));assert(ns.MatchesStatus("progress"))
ns.char.statusFilter="Unknown";assert(ns.MatchesStatus("unknown"));ns.char.statusFilter="All"
C_QuestLog={GetAllCompletedQuestIDs=function()return {783,7}end};ns.Sync(false);finish()
assert(ns.Status(783)=="completed" and ns.Status(15)=="incomplete")
C_QuestLog.IsQuestFlaggedCompleted=function()return false end;ns.Sync(false);finish();assert(ns.Status(783)=="incomplete")
local secret={};function issecretvalue(v)return v==secret end
C_QuestLog={GetAllCompletedQuestIDs=function()return {secret}end,IsQuestFlaggedCompleted=function()return secret end}
ns.Sync(false);finish();assert(ns.Status(783)=="unknown")
C_QuestLog.GetAllCompletedQuestIDs=function()error("unavailable")end;ns.Sync(false);finish();assert(ns.Status(783)=="unknown")
C_QuestLog=nil;queries=0
function QueryQuestsCompleted()queries=queries+1 end
function GetQuestsCompleted(out)out[783]=true end
ns.Sync(true);assert(ns.waiting and queries==1);ns.Sync(true);assert(queries==1)
event("QUEST_QUERY_COMPLETE");finish();assert(ns.Status(783)=="completed" and ns.Status(15)=="incomplete")
event("QUEST_LOG_UPDATE");finish();assert(ns.Status(783)=="completed")
ns.Sync(true);ns.Tick(11);finish();assert(ns.Status(783)=="unknown" and ns.syncMessage:find("timed out"))
function QueryQuestsCompleted()error("not supported")end
ns.Sync(true);finish();assert(ns.Status(783)=="unknown" and ns.syncMessage:find("unavailable"))
function GetQuestsCompleted()return false end
event("QUEST_QUERY_COMPLETE");finish();assert(ns.Status(783)=="unknown")
QueryQuestsCompleted=nil;GetQuestsCompleted=nil;C_QuestLog=modern;ns.legacyReady=nil
ns.Sync(false);finish()
ns.char.factionFilter="All";ns.char.area="All areas";ns.Refresh();assert(#ns.visibleQuests==6090)
assert(ns.window.range.text=="6090 matching / 6090 total quests")

assert(not ns.window.scroll.template and ns.window.scroll.orientation=="VERTICAL")
ns.char.followZone=false;ns.expanded={};ns.listOffset=0;ns.Refresh()
local headers=#ns.listEntries
assert(headers>14 and not ns.window.areaRows and not ns.window.questRows)
for _,entry in ipairs(ns.listEntries)do assert(entry.area and not entry.quest)end
local area=ns.listEntries[1].area
ns.window.rows[1].scripts.OnClick(ns.window.rows[1])
assert(ns.openAreas[area] and #ns.listEntries>headers and ns.listEntries[2].quest.area==area)
ns.ToggleArea(area);assert(not ns.openAreas[area] and #ns.listEntries==headers)
ns.window.scroll:SetValue(99999);assert(ns.listOffset==headers-14)
ns.window.scroll.scripts.OnMouseWheel(ns.window.scroll,10000);assert(ns.listOffset==0)
ns.window.search:SetText("783");assert(#ns.visibleQuests==1 and ns.visibleQuests[1].id==783)
assert(#ns.listEntries==2 and ns.listEntries[2].quest.id==783)
local matchArea=ns.listEntries[1].area
ns.ToggleArea(matchArea);assert(#ns.listEntries==1)
ns.ToggleArea(matchArea);assert(#ns.listEntries==2)
ns.window.search:SetText("NO_MATCH_abcdef");assert(#ns.visibleQuests==0 and ns.window.range:GetText()=="0 matching / 6090 total quests")
assert(ns.listOffset==0)
ns.window.search:SetText("Elwynn Forest")
assert(#ns.visibleQuests>0)
for _,q in ipairs(ns.visibleQuests)do assert(q.area=="Elwynn Forest")end
ns.window.search:SetText("");ns.expanded={};ns.Refresh()
assert(#ns.listEntries==headers)

assert(ns.window:IsShown() and ns.window.body:IsShown())
assert(ns.window.width==360 and ns.window.height==520)
for _,name in ipairs(UISpecialFrames or {})do assert(name~="ZoidsTools_FWindow")end
ns.window.search.scripts.OnEscapePressed(ns.window.search)
assert(ns.window:IsShown())
ns.window.header.scripts.OnDragStart()
assert(ns.window.moving and ns.window.starts==1)
ns.window.header.scripts.OnDragStop()
assert(not ns.window.moving and ns.char.windowPoint.point=="TOPLEFT")
ns.window.lockButton.scripts.OnClick()
assert(ns.char.locked and ns.window.lockButton:GetText()=="Unlock")
ns.window.header.scripts.OnDragStart();assert(not ns.window.moving and ns.window.starts==1)
ns.window.minimizeButton.scripts.OnClick()
assert(ns.char.minimized and ns.window:IsShown() and not ns.window.body:IsShown())
assert(ns.window.width==250 and ns.window.height==34)
local offset=ns.listOffset
ns.Refresh();assert(not ns.window.body:IsShown() and ns.listOffset==offset)
ns.Command("expand");assert(not ns.char.minimized and ns.window.body:IsShown())
ns.Command("lock");assert(not ns.char.locked)
ns.window.header.scripts.OnDragStart();assert(ns.window.moving)
ns.Command("");assert(ns.char.minimized and not ns.window.moving)
ns.Command("");assert(not ns.char.minimized and ns.window:IsShown())
-- Reapply persisted settings, as on login: no reset of saved lock/minimize/anchor.
ns.char.locked=true;ns.char.minimized=true;ns.ApplyTrackerState()
assert(ns.char.locked and not ns.window.body:IsShown())
assert(ns.char.windowPoint.x==120 and ns.char.windowPoint.y==700)
ns.Command("expand");ns.Command("lock")
ns.ToggleArea(ns.listEntries[1].area);assert(not ns.char.followZone)
local selected=ns.char.area;zone="Durotar";event("ZONE_CHANGED_NEW_AREA");assert(ns.char.area==selected)
ns.Command("zone");assert(ns.char.area=="Durotar" and ns.char.followZone and ns.openAreas["Durotar"])
assert(ns.listEntries[ns.listOffset+1].area=="Durotar")
ns.char.statusFilter="Completed";ns.Refresh();for _,q in ipairs(ns.visibleQuests)do assert(ns.Status(q.id)=="completed")end
assert(ZoidsTools_FDB.sentinel and ns.char.skipped[7] and ns.char.done[783] and ZoidsTools_FDB.pins.sentinel)
''')

lua.execute("""
finish()
local scans=0
local original=ns.BeginScan
ns.BeginScan=function(...)scans=scans+1;return original(...)end
for _,e in ipairs({"QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","PLAYER_ENTERING_WORLD"})do
 assert(not ns.events.events[e])
 event(e,783)
end
event("ADDON_LOADED","UnrelatedAddon");event("QUEST_QUERY_COMPLETE")
ns.window:Hide();ns.window:Show()
ns.Command("minimize");ns.Command("expand");ns.Command("lock");ns.Command("lock")
finish();assert(scans==0 and not ns.events.scripts.OnUpdate)
-- Same-zone/subzone notifications do not reread quests.
event("ZONE_CHANGED");event("ZONE_CHANGED_NEW_AREA");finish();assert(scans==0)
-- Refresh even when follow-current-area is disabled; coalesce zone event burst.
ns.char.followZone=false;zone="Westfall"
event("ZONE_CHANGED");event("ZONE_CHANGED_NEW_AREA");finish()
assert(scans==1 and not ns.events.scripts.OnUpdate)
event("QUEST_TURNED_IN",783);event("QUEST_TURNED_IN",7);finish()
assert(scans==2)
-- A completion during a scan must produce one follow-up, not be lost.
ns.Sync(false);ns.Tick(.01);assert(ns.scan)
event("QUEST_TURNED_IN",7);event("QUEST_TURNED_IN",783);finish()
assert(scans==4 and not ns.events.scripts.OnUpdate)
ns.Command("refresh");finish();assert(scans==5)
ns.BeginScan=original
""")
print('PASS: refreshes only on turn-in/changed zone after startup; duplicate events coalesced; no refresh on show or quest-log noise; pending completion preserved; idle update handler removed.')
print('PASS: Lua 5.1 syntax; 6,090 quests; UI startup; batched modern/legacy completion sync; historical completion; turn-in/reset updates; active/repeatable status; unknown/error/secret handling; query timeout; faction/class/status/search/area/scroll filters; old-save migration; no arrow/manual progression.')

lua.execute("""
-- Verify relative layout, not just direct invocation of button callbacks.
local f=ns.window
assert(f.lockButton.parent==f.header and f.minimizeButton.parent==f.header,
       "Controls must be children above the mouse-enabled drag surface")
for _,row in ipairs(f.rows) do
    assert(row.name.parent==row and row.status.parent==row)
    assert(row.name.point[3]==-3 and row.status.point[3]==-3,
           "Labels must be inside their row rather than offset into the controls")
    assert(row.name.height<=row.height-3 and row.status.height<=row.height-3)
    assert(row.name.point[2]+row.name.width<row.status.point[2])
    assert(row.status.point[2]+row.status.width<=row.width)
    assert(row.name.wrap==false and row.status.wrap==false)
end
assert(f.sync.height==36 and f.sync.wrap==true)
local locked=ns.char.locked
f.lockButton.scripts.OnClick(f.lockButton)
assert(ns.char.locked~=locked)
local minimized=ns.char.minimized
f.minimizeButton.scripts.OnClick(f.minimizeButton)
assert(ns.char.minimized~=minimized and f.body:IsShown()==minimized)
""")
print('PASS: header controls above drag surface; row text bounds and spacing; wrapping limits; lock/minimize callbacks.')

lua.execute("""
-- Discovery reads only encountered IDs and never queues a completion scan.
ns.mapProvider=nil;WorldMapFrame=nil
local baseCount=#ns.quests
local scans=0;local oldSync=ns.Sync
ns.Sync=function()scans=scans+1 end
C_QuestLog={
 IsQuestFlaggedCompleted=function()return false end,
 GetNumQuestLogEntries=function()return 2 end,
 GetInfo=function(i)
  if i==1 then return {isHeader=true,title="Discovery Test Zone"} end
  return {questID=990001,title="Unlisted Log Quest",level=12}
 end
}
assert(ns.DiscoverLog())
assert(#ns.quests==baseCount+1 and ns.index[990001].area=="Discovery Test Zone")
assert(ns.char.discovered[990001] and not ns.char.discovered[990001].pickup)
assert(not ns.DiscoverLog() and #ns.quests==baseCount+1)
function UnitName(unit)assert(unit=="npc");return "New Quest Giver" end
function UnitGUID(unit)assert(unit=="npc");return "Creature-0-1-2-3-12345-000000" end
C_Map={
 GetBestMapForUnit=function()return 111 end,
 GetPlayerMapPosition=function()return {GetXY=function()return .4,.6 end}end
}
C_GossipInfo={GetAvailableQuests=function()return {
 {questID=990001,title="Unlisted Log Quest",questLevel=12},
 {questID=990002,title="Unlisted Offer",questLevel=15},
 {questID=783,title="Do not replace bundled title",questLevel=999},
 {questID=0,title="Invalid"}
}end}
local function discover(e)ns.discoveryEvents.scripts.OnEvent(ns.discoveryEvents,e)end
zone="Discovery Test Zone";discover("GOSSIP_SHOW")
assert(#ns.quests==baseCount+2 and ns.index[990001].area==zone)
local pickup=ns.char.discovered[990002].pickup
assert(pickup.name=="New Quest Giver" and pickup.mapID==111 and pickup.x==.4)
assert(ns.index[783].name~="Do not replace bundled title")
discover("GOSSIP_SHOW");assert(#ns.quests==baseCount+2)
assert(not ns.pickups[990002]) -- Approximate player positions are not exact NPC map pins.
function GetQuestID()return 990003 end
function GetTitleText()return "Remote Offer" end
discover("QUEST_DETAIL")
assert(ns.index[990003] and not ns.char.discovered[990003].pickup)
function UnitGUID()return "Player-1-123" end
C_GossipInfo.GetAvailableQuests=function()return {{questID=990004,title="Offer Without NPC"}}end
discover("GOSSIP_SHOW");assert(not ns.char.discovered[990004].pickup)
assert(scans==0 and not ns.discoveryEvents.scripts.OnUpdate)
-- Saved observations survive reload; saved metadata never supplies completion.
ns.char.discovered[990005]={name="Restored Quest",level=9,done=true}
ns.char.discovered.bad={name="Invalid"}
ns.LoadDiscoveries()
assert(ns.index[990005] and ns.Status(990005)=="unknown")
assert(not ns.char.discovered.bad and not ns.char.discovered[990005].done)
local n=#ns.quests;ns.LoadDiscoveries();assert(#ns.quests==n)
C_GossipInfo.GetAvailableQuests=function()error("unsupported")end
discover("GOSSIP_SHOW")
C_QuestLog={};GetNumQuestLogEntries=function()return 1 end
GetQuestLogTitle=function()return "Legacy Encounter",7,nil,false,nil,nil,nil,990006 end
assert(ns.DiscoverLog() and ns.index[990006])
local secret={};issecretvalue=function(v)return v==secret end
assert(not ns.ObserveQuest(secret,"Secret ID",1))
assert(not ns.ObserveQuest(990007,secret,1))
ns.Sync=oldSync
""")
print('PASS: discovery deduplication, log/offer capture, NPC-only approximate positions, unknown remote/log pickups, bundled data preservation, saved-record validation, legacy fallback, no full refresh or idle polling.')


lua.execute("""
-- Synthetic IDs reproduce delayed availability, not actual beta quest IDs.
local oldSync=ns.Sync
local scans=0
ns.Sync=function()scans=scans+1 end
local entries={}
C_QuestLog={GetNumQuestLogEntries=function()return #entries end,
 GetInfo=function(i)return entries[i]end,
 IsQuestFlaggedCompleted=function()return false end}
local function event(e)ns.discoveryEvents.scripts.OnEvent(ns.discoveryEvents,e)end
assert(ns.discoveryEvents.events.QUEST_LOG_UPDATE)
event("QUEST_ACCEPTED")
assert(not ns.index[991001])
entries={{questID=991001,title="Infestation Investigation"},
 {questID=991002,title="Harmony in Balance"}}
event("QUEST_LOG_UPDATE")
assert(ns.char.discovered[991001].name=="Infestation Investigation")
assert(ns.char.discovered[991002].name=="Harmony in Balance")
local n=#ns.quests
event("QUEST_LOG_UPDATE");assert(#ns.quests==n)
assert(scans==0 and not ns.discoveryEvents.scripts.OnUpdate)
C_QuestLog.GetNumQuestLogEntries=function()error("unavailable")end
C_QuestLog.GetInfo=function()return {questID=0,title=""}end
GetNumQuestLogEntries=function()return 1 end
GetQuestLogTitle=function()return "Legacy Fallback",7,nil,false,nil,nil,nil,991003 end
event("QUEST_LOG_UPDATE");assert(ns.char.discovered[991003])
ns.Sync=oldSync
entries={{questID=991004,title="Manual Recovery"}}
C_QuestLog.GetNumQuestLogEntries=function()return #entries end
C_QuestLog.GetInfo=function(i)return entries[i]end
ns.Sync(true)
assert(ns.char.discovered[991004])
""")
print('PASS: delayed acceptance capture, duplicate log updates, unavailable modern API fallback, manual discovery recovery; no full scans from log events.')


lua.execute("""
-- Previously saved discoveries without NPC metadata must group correctly.
ns.char.discovered[92460]={name="Coming of Age",level=1,pickup={name="Ailee Farheart",zone="Zephras Isle"}}
ns.char.discovered[92461]={name="Harmony in Balance",level=1}
ns.char.discovered[92462]={name="Infestation Investigation",level=2}
ns.LoadDiscoveries()
ns.char.statusFilter="All";ns.char.factionFilter="Mine"
ns.window.search:SetText("Zephras Isle")
ns.Refresh()
local found={}
for _,q in ipairs(ns.visibleQuests)do found[q.id]=true end
for _,id in ipairs({92460,92461,92462})do
 assert(found[id] and ns.index[id].area=="Zephras Isle")
end
assert(not ns.char.discovered[92461].pickup)
-- Header category persists and follows the newly discovered current area.
zone="New Beta Area";ns.char.followZone=true
C_QuestLog.GetNumQuestLogEntries=function()return 2 end
C_QuestLog.GetInfo=function(i)
 if i==1 then return {isHeader=true,title=zone} end
 return {questID=992010,title="New Beta Quest"}
end
ns.DiscoverLog()
assert(ns.index[992010].area==zone and ns.expanded[zone])
ns.LoadDiscoveries()
assert(ns.char.discovered[992010].category==zone and not ns.char.discovered[992010].pickup)
""")
print('PASS: saved Zephras Isle discoveries visible together, log category persistence, new current-area expansion, no invented pickup metadata.')


lua.execute("""
-- Permanent beta inventory survives an absent per-character discovery record.
ns.char.discovered[92460]=nil
ns.char.discovered[92461]=nil
ns.char.discovered[92462]=nil
ns.LoadDiscoveries()
ns.char.statusFilter="All";ns.char.factionFilter="Mine"
ns.window.search:SetText("Zephras Isle")
ns.Refresh()
local found={}
for _,q in ipairs(ns.visibleQuests)do found[q.id]=true end
for _,id in ipairs({92460,92461,92462})do
 assert(found[id] and ns.index[id].observed and not ns.index[id].discovered)
end
assert(ns.index[92460].observation.pickup.name=="Ailee Farheart")
assert(not ns.pickups[92460])
C_QuestLog={};IsQuestFlaggedCompleted=nil;ns.bulk=nil
assert(ns.ReadStatus(92460)=="unknown")
C_QuestLog.IsQuestFlaggedCompleted=function(id)return id==92460 end
assert(ns.ReadStatus(92460)=="completed" and ns.ReadStatus(92461)=="incomplete")
""")
print('PASS: permanent beta quests survive missing discovery history; NPC observation preserved; completion comes only from current character game data.')



# Exercise migration in independent Lua environments, including the reload boundary.
def migration_runtime(saved="", legacy="", loaded=False):
    runtime=LuaRuntime(unpack_returned_tuples=True)
    runtime.execute("""
        SlashCmdList={}; frames={}; UIParent={}
        function CreateFrame()
            local f={scripts={}}
            function f:RegisterEvent()end
            function f:SetScript(e,fn)self.scripts[e]=fn end
            frames[#frames+1]=f; return f
        end
        function UnitName()return "TestCharacter" end
        messages={}; root={version="0.2.4-beta", Print=function(_,s)messages[#messages+1]=s end}
    """)
    runtime.globals().legacyLoaded=loaded
    runtime.execute("""
        C_AddOns={IsAddOnLoaded=function(name)return legacyLoaded end,
          DisableAddOn=function(name,character)disabled={name,character}end}
    """)
    if saved: runtime.execute(saved)
    if legacy: runtime.execute(legacy)
    host=runtime.globals().root
    for name in ['Bootstrap.lua','Data.lua','PickupData.lua','Core.lua','Discovery.lua','UI.lua']:
        runtime.execute((addon/name).read_text(encoding='utf-8'),'ZoidsTools_F',host)
    runtime.execute("""
        ns=root.Completionist
        ns.events.scripts.OnEvent(ns.events,"ADDON_LOADED","ZoidsTools_F")
    """)
    return runtime

legacy="""ZoidsForeverGuideCharDB={locked=true,show=false,discovered={
 [990010]={name="Imported Quest",level=3,pickup={name="NPC",zone="Test Zone"}}}}"""
first=migration_runtime(legacy=legacy,loaded=True)
first.execute("""
assert(ns.migrationPending and not ns.char and not ns.window)
assert(ZoidsTools_FCompletionistDB.discovered[990010].name=="Imported Quest")
assert(ZoidsTools_FCompletionistDB.discovered~=ZoidsForeverGuideCharDB.discovered)
ns.migrationEvents.scripts.OnEvent(ns.migrationEvents,"PLAYER_LOGIN")
assert(disabled[1]=="ZoidsForeverGuide" and disabled[2]=="TestCharacter")
ns.events.scripts.OnEvent(ns.events,"PLAYER_LOGIN")
assert(not ns.window) -- Only the old tracker runs before the required reload.
ZoidsForeverGuideCharDB.discovered[990011]={name="Before Reload",level=4}
ns.migrationEvents.scripts.OnEvent(ns.migrationEvents,"PLAYER_LOGOUT")
assert(ZoidsTools_FCompletionistDB.discovered[990011])
function serialize(v)
 if type(v)=="table" then
  local entries={};for k,item in pairs(v)do entries[#entries+1]="["..serialize(k).."]="..serialize(item)end
  return "{"..table.concat(entries,",").."}"
 elseif type(v)=="string" then return string.format("%q",v)
 else return tostring(v)end
end
""")
snapshot='ZoidsTools_FCompletionistDB='+first.globals().serialize(first.globals().ZoidsTools_FCompletionistDB)
second=migration_runtime(saved=snapshot)
second.execute("""
assert(not ns.migrationPending and ns.char.locked and ns.char.show==false)
assert(ns.index[990010] and ns.index[990011])
assert(ns.char.discovered[990010].pickup.zone=="Test Zone")
assert(not ns.SetupMapPins and not ns.mapEvents)
assert(root.version=="0.2.4-beta" and root.quests==nil)
assert(SlashCmdList.ZOIDSTOOLS_COMPLETIONIST and not SlashCmdList.ZOIDSFOREVERGUIDE)
""")
other=migration_runtime()
other.execute('assert(not ns.index[990010] and ns.index[92460])')
existing=migration_runtime(saved='ZoidsTools_FCompletionistDB={locked=false,discovered={[990010]={name="Newer"}}}',legacy=legacy,loaded=True)
existing.execute('assert(ZoidsTools_FCompletionistDB.locked==false and ZoidsTools_FCompletionistDB.discovered[990010].name=="Newer")')
print('PASS: isolated namespace, deep-copy legacy import, existing data priority, late discoveries at logout, per-character disable, no duplicate tracker, fresh reload persistence, alt isolation, no map provider.')

# Fresh login geometry deliberately differs from the saved corner. Startup must
# restore the anchor without reading that geometry back into SavedVariables.
for minimized in (False, True):
    saved='ZoidsTools_FCompletionistDB={minimized='+str(minimized).lower()+'}'
    for reload_index in range(4):
        session=LuaRuntime(unpack_returned_tuples=True)
        session.execute(frame_stubs)
        session.execute(saved)
        host=session.table()
        host.version='0.2.4-beta'
        for filename in ['Bootstrap.lua']+files:
            session.execute((addon/filename).read_text(encoding='utf-8'),'ZoidsTools_F',host)
        session.globals().ns=host.Completionist
        session.execute('''
            ns.events.scripts.OnEvent(ns.events,"ADDON_LOADED","ZoidsTools_F")
            ns.events.scripts.OnEvent(ns.events,"PLAYER_LOGIN")
            assert(ns.window.dontSavePosition)
            assert(ns.window.height==(ns.char.minimized and 34 or 520))
        ''')
        if reload_index:
            session.execute('''
                assert(ns.char.windowPoint.x==920 and ns.char.windowPoint.y==80,
                    "Login overwrote the saved corner with startup geometry")
                local p=ns.window.point
                assert(p[1]=="TOPLEFT" and p[3]=="BOTTOMLEFT" and p[4]==920 and p[5]==80)
            ''')
        session.execute('''
            ns.window.GetLeft=function()return 920 end
            ns.window.GetTop=function()return 80 end
            ns.window.header.scripts.OnDragStart()
        ''')
        # Cover ordinary release and reload/logout while the mouse is still held.
        if reload_index % 2 == 0:
            session.execute('ns.window.header.scripts.OnDragStop()')
        session.execute('''
            assert(ns.events.events.PLAYER_LOGOUT)
            ns.events.scripts.OnEvent(ns.events,"PLAYER_LOGOUT")
            assert(not ns.window.moving and ns.window.stops==1)
            function serialize(v)
                if type(v)=="table" then
                    local fields={}
                    for k,item in pairs(v)do fields[#fields+1]="["..serialize(k).."]="..serialize(item)end
                    return "{"..table.concat(fields,",").."}"
                elseif type(v)=="string" then return string.format("%q",v)
                else return tostring(v) end
            end
        ''')
        saved='ZoidsTools_FCompletionistDB='+session.globals().serialize(host.Completionist.char)
print('PASS: expanded/minimized tracker positions survive three fresh reloads, including logout during drag.')

def tracker_session(account='', character='', guid='Player-Test-1'):
    session=LuaRuntime(unpack_returned_tuples=True)
    session.execute(frame_stubs)
    session.execute('ZoidsTools_FCompletionistDB=nil')
    session.execute(account)
    session.execute(character)
    session.globals().playerGUID=guid
    session.execute('function UnitGUID(unit)if unit=="player" then return playerGUID end end')
    host=session.table()
    host.version='0.2.4-beta'
    host.db=session.globals().ZoidsTools_FDB
    for filename in ['Bootstrap.lua']+files:
        session.execute((addon/filename).read_text(encoding='utf-8'),'ZoidsTools_F',host)
    session.globals().ns=host.Completionist
    session.execute('''
        ns.events.scripts.OnEvent(ns.events,"ADDON_LOADED","ZoidsTools_F")
        ns.events.scripts.OnEvent(ns.events,"PLAYER_LOGIN")
    ''')
    return session

session=tracker_session()
session.execute('''
    ns.window.GetLeft=function()return 0 end
    ns.window.GetTop=function()return 1200 end
    ns.window.header.scripts.OnDragStart()
    ns.window.header.scripts.OnDragStop()
    ns.window.lockButton.scripts.OnClick()
    assert(ns.char.locked and ns.char.windowPoint.x==0 and ns.char.windowPoint.y==1200)
    assert(ZoidsTools_FDB.completionistTracker.locked)
    assert(ZoidsTools_FDB.completionistTracker.windowPoint.y==1200)
''')
def account_snapshot(session):
    return session.execute('''
        local function serialize(v)
            if type(v)=="string" then return string.format("%q",v) end
            if type(v)~="table" then return tostring(v) end
            local fields={}
            for k,item in pairs(v)do fields[#fields+1]="["..serialize(k).."]="..serialize(item)end
            return "{"..table.concat(fields,",").."}"
        end
        return "ZoidsTools_FDB="..serialize(ZoidsTools_FDB)
    ''')
for stale_character in ['', 'ZoidsTools_FCompletionistDB={locked=false,settingsRevision=0}']*3:
    account=account_snapshot(session)
    session=tracker_session(account,stale_character)
    session.execute('''
        assert(ns.char.locked and ns.window.lockButton:GetText()=="Unlock")
        assert(ns.char.windowPoint.x==0 and ns.char.windowPoint.y==1200)
        assert(ns.window.point[4]==0 and ns.window.point[5]==1200)
        ns.window.header.scripts.OnDragStart();assert(not ns.window.moving)
    ''')
alt=tracker_session(account,guid='Player-Test-2')
alt.execute('''
    assert(ns.char.locked and ns.char.windowPoint.y==1200)
    assert(next(ns.char.discovered)==nil)
    ns.window.lockButton.scripts.OnClick()
    ns.window.minimizeButton.scripts.OnClick()
''')
unlocked=tracker_session(account_snapshot(alt))
unlocked.execute('assert(not ns.char.locked and ns.char.minimized and ns.window.height==34)')
imported=tracker_session(character='ZoidsTools_FCompletionistDB={locked=true,windowPoint={point="TOPLEFT",relative="BOTTOMLEFT",x=0,y=1200}}')
imported.execute('assert(ZoidsTools_FDB.completionistTracker.locked and ns.window.point[5]==1200)')
print('PASS: shared locked corner survives six logins with missing/stale character saves; alt layout sharing, unlock/minimize persistence, and existing layout import.')

promoted=tracker_session(character='''ZoidsTools_FCompletionistDB={discovered={
 [86758]={name="Twisting the Knife",level=16,category="Loch Modan",
 pickup={name="Marek Ironheart",zone="Farstrider Lodge",mapID=1432,x=.818,y=.616}}
}}''')
promoted.execute('''
    assert(#ns.quests==6090 and not ns.index[86758].discovered)
    assert(ns.char.discovered[86758].pickup.name=="Marek Ironheart")
    local lines={}
    GameTooltip={SetOwner=function()end,SetText=function()end,Show=function()end,
        AddLine=function(_,s)lines[#lines+1]=s end}
    local row=ns.window.rows[1];row.quest=ns.index[86758]
    row.scripts.OnEnter(row)
    local tooltip=table.concat(lines,"\\n")
    assert(tooltip:find("Marek Ironheart",1,true) and tooltip:find("Approximate",1,true))
    assert(tooltip:find("Wowhead Forever",1,true))
''')
print('PASS: newly bundled discovery preserves saved NPC evidence, appears once, and shows both source and observation in its tooltip.')
