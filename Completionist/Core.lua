local addon, root = ...
local ns = root.Completionist
ns.version = root.version
ns.index, ns.areas, ns.states = {}, {}, {}
local seen = {}
for _, q in ipairs(ns.quests) do
    ns.index[q.id] = q
    if not seen[q.area] then seen[q.area] = true; ns.areas[#ns.areas+1] = q.area end
end
table.sort(ns.areas)
function ns.AddArea(area)
    if not seen[area] then seen[area]=true;ns.areas[#ns.areas+1]=area;table.sort(ns.areas) end
end
ns.statusInfo = {
    completed = {label="Completed", color="66dd88"},
    incomplete = {label="Not completed", color="cccccc"},
    progress = {label="In progress", color="77bbee"},
    ready = {label="Ready to turn in", color="ffdd77"},
    unknown = {label="Unknown", color="999999"},
}
function ns.Secret(v) return type(issecretvalue)=="function" and issecretvalue(v) end
function ns.Number(v) return not ns.Secret(v) and type(v)=="number" and v==v and math.abs(v)<math.huge end
function ns.Call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok and not ns.Secret(a) and not ns.Secret(b) then return a,b end
end
local function Boolean(v)
    if v==true or v==1 then return true end
    if v==false or v==0 then return false end
end
function ns.Print(s) DEFAULT_CHAT_FRAME:AddMessage("|cffefc77dCompletionist:|r "..s) end
function ns.RefreshCharacter()
    ns.playerFaction=ns.Call(UnitFactionGroup,"player")
    local _,class=ns.Call(UnitClass,"player");ns.playerClass=class
end
function ns.Eligible(q)
    local filter=ns.char.factionFilter
    if filter=="All" then return true end
    local faction=filter=="Mine" and ns.playerFaction or filter
    if q.side~=faction and q.side~="Both" then return false end
    if filter=="Mine" then
        local class=ns.playerClass
        local bits={WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024}
        if q.classMask>0 and bits[class] and math.floor(q.classMask/bits[class])%2~=1 then return false end
    end
    return true
end
function ns.Status(id) return ns.states[id] or "unknown" end
function ns.MatchesStatus(state)
    local f=ns.char.statusFilter
    return f=="All" or (f=="Unfinished" and (state=="incomplete" or state=="progress" or state=="ready"))
        or (f=="Completed" and state=="completed") or (f=="In log" and (state=="progress" or state=="ready"))
        or (f=="Unknown" and state=="unknown")
end
function ns.ReadStatus(id)
    local api=C_QuestLog or {}
    local on=Boolean(ns.Call(api.IsOnQuest,id))
    if on then return Boolean(ns.Call(api.IsComplete or IsQuestComplete,id)) and "ready" or "progress" end
    local done=Boolean(ns.Call(api.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted,id))
    -- A current false must not be overridden by old local history or a previous bulk snapshot.
    if done~=nil then return done and "completed" or "incomplete" end
    if ns.bulk then return ns.bulk[id] and "completed" or "incomplete" end
    return "unknown"
end
local function ReadBulk(legacyReady)
    local list=ns.Call(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    if type(list)=="table" then
        local set={}
        for _,id in pairs(list) do
            if not ns.Number(id) or id<=0 or id%1~=0 then return end
            set[id]=true
        end
        return set
    end
    -- Older clients populate a set only after QUEST_QUERY_COMPLETE.
    if legacyReady and type(GetQuestsCompleted)=="function" then
        local result={}
        local ok,returned=pcall(GetQuestsCompleted,result)
        if not ok or ns.Secret(returned) or returned==false then return end
        if type(returned)=="table" then result=returned end
        local set={}
        for id,value in pairs(result) do
            if not ns.Number(id) or id<=0 or id%1~=0 or ns.Secret(value) then return end
            if value~=true and value~=false and value~=1 and value~=0 then return end
            if value==true or value==1 then set[id]=true end
        end
        return set
    end
end
function ns.WakeUpdates()
    ns.events:SetScript("OnUpdate",function(_,dt)ns.Tick(dt)end)
end
function ns.QueueRefresh()
    ns.dirty=.5
    ns.WakeUpdates()
end
function ns.BeginScan(legacyReady)
    ns.WakeUpdates()
    ns.bulk=ReadBulk(legacyReady or ns.legacyReady)
    ns.scan={cursor=1,states={}}
    ns.syncMessage="Reading your character's quest records..."
    if ns.Refresh then ns.Refresh() end
end
function ns.Sync(requestServer)
    if ns.char and ns.DiscoverLog then ns.DiscoverLog() end
    if ns.waiting or ns.scan then return end
    ns.dirty=nil
    ns.WakeUpdates()
    ns.syncWarning=nil
    if requestServer and not (C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs)=="function")
        and type(QueryQuestsCompleted)=="function" and type(GetQuestsCompleted)=="function" then
        ns.legacyReady=nil;ns.waiting=0; ns.syncMessage="Waiting for quest completion records..."
        local ok,result=pcall(QueryQuestsCompleted)
        if ok and not ns.Secret(result) and result~=false then
            if ns.Refresh then ns.Refresh() end
            return
        end
        ns.waiting=nil; ns.syncWarning="Server query unavailable."
    end
    ns.BeginScan(false)
end
function ns.UseCurrentArea()
    local zone=ns.Call(GetRealZoneText) or ns.Call(GetZoneText)
    if type(zone)=="string" and not seen[zone] then
        local clean=zone:lower():gsub("[^%w]","")
        for _,area in ipairs(ns.areas)do
            if area:lower():gsub("[^%w]","")==clean then zone=area;break end
        end
    end
    if zone and seen[zone] then ns.char.area=zone else ns.char.area="All areas" end
    ns.expanded=ns.expanded or {}
    if ns.char.area~="All areas" then ns.expanded[ns.char.area]=true end
    ns.jumpToArea=ns.char.area
    ns.listOffset=0
    if ns.Refresh then ns.Refresh() end
end
function ns.Tick(dt)
    if ns.waiting then
        ns.waiting=ns.waiting+dt
        if ns.waiting>=10 then ns.waiting=nil;ns.syncWarning="Server query timed out.";ns.BeginScan(false) end
    end
    if ns.scan then
        local scan=ns.scan
        -- Spread the cached game reads over frames; no per-quest network requests.
        for i=scan.cursor,math.min(scan.cursor+149,#ns.quests) do
            local q=ns.quests[i];scan.states[q.id]=ns.ReadStatus(q.id)
        end
        scan.cursor=scan.cursor+150
        if scan.cursor>#ns.quests then
            ns.states=scan.states;ns.scan=nil
            local unknown=0
            for _,state in pairs(ns.states) do if state=="unknown" then unknown=unknown+1 end end
            ns.syncMessage=unknown>0 and string.format("Game records read; %d quests have unknown status.",unknown)
                or "Completion checked against this character's game records."
            if ns.syncWarning then ns.syncMessage=ns.syncWarning.." "..ns.syncMessage end
            if ns.Refresh then ns.Refresh() end
        end
    elseif ns.dirty then
        ns.dirty=ns.dirty-dt
        if ns.dirty<=0 and not ns.waiting then ns.dirty=nil;ns.Sync(true) end
    end
    if not ns.scan and not ns.waiting and not ns.dirty then ns.events:SetScript("OnUpdate",nil) end
end
function ns.Command(msg)
    if not ns.window then return end
    local command=(msg:match("^%s*(%S*)") or ""):lower()
    if command=="" then ns.window:Show();ns.ToggleMinimized()
    elseif command=="lock" then ns.ToggleLocked()
    elseif command=="minimize" then ns.char.minimized=true;ns.ApplyTrackerState()
    elseif command=="expand" then ns.window:Show();ns.char.minimized=false;ns.ApplyTrackerState()
    elseif command=="refresh" then ns.Sync(true)
    elseif command=="zone" then ns.char.followZone=true;ns.UseCurrentArea()
    elseif command=="resetpos" then ns.window:ClearAllPoints();ns.window:SetPoint("CENTER");ns.char.windowPoint=nil;ns.SaveTrackerPosition()
    else ns.Print("/ztfc minimizes/expands the tracker. /ztfc lock toggles movement lock; /ztfc expand restores it. /ztfc refresh checks game completion; /ztfc zone follows your current area; /ztfc resetpos resets the window.") end
end
local events=CreateFrame("Frame")
ns.events=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_LOGOUT","QUEST_TURNED_IN","QUEST_QUERY_COMPLETE","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,a)
    if event=="ADDON_LOADED" and a==addon then
        ns.PrepareCharacter()
        if ns.migrationPending then return end
        ns.char=ZoidsTools_FCompletionistDB
        -- Preserve original settings, but never treat manual progress or pins as completion evidence.
        if not ({Mine=true,Alliance=true,Horde=true,All=true})[ns.char.factionFilter or ""] then ns.char.factionFilter="Mine" end
        if not ({All=true,Unfinished=true,Completed=true,["In log"]=true,Unknown=true})[ns.char.statusFilter or ""] then ns.char.statusFilter="All" end
        if ns.char.locked==nil then ns.char.locked=false end
        if ns.char.minimized==nil then ns.char.minimized=false end
        if ns.char.followZone==nil then ns.char.followZone=true end
        if ns.LoadDiscoveries then ns.LoadDiscoveries() end
        if not seen[ns.char.area] then ns.char.area="All areas" end
    elseif event=="PLAYER_LOGIN" and ns.char then
        ns.LoadTrackerSettings()
        ns.lastZone=ns.Call(GetRealZoneText) or ns.Call(GetZoneText)
        if ns.char.followZone then ns.UseCurrentArea() end
        if ns.DiscoverLog then ns.DiscoverLog() end
        ns.CreateUI();ns.Sync(true)
        ns.Print("Completionist loaded. /ztfc to minimize or expand.")
    elseif ns.window then
        if event=="PLAYER_LOGOUT" then
            ns.StopTrackerMoving()
        elseif event=="QUEST_QUERY_COMPLETE" and ns.waiting then
            ns.waiting=nil;ns.legacyReady=true;ns.BeginScan(true)
        elseif event=="QUEST_TURNED_IN" then
            ns.QueueRefresh()
        elseif event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED" then
            local zone=ns.Call(GetRealZoneText) or ns.Call(GetZoneText)
            if type(zone)=="string" and zone~=ns.lastZone then
                ns.lastZone=zone
                if ns.char.followZone then ns.UseCurrentArea() end
                ns.QueueRefresh()
            end
        end
    end
end)
SlashCmdList.ZOIDSTOOLS_COMPLETIONIST=ns.Command
SLASH_ZOIDSTOOLS_COMPLETIONIST1="/ztfc"
