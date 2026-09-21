local _,root=...
local ns=root.Completionist
local UNKNOWN="Discovered (area unknown)"
-- IDs from saved encounters; area confirmed by the player. No pickup coordinates inferred.
local confirmedAreas={[92460]="Zephras Isle",[92461]="Zephras Isle",[92462]="Zephras Isle"}
local function Area(id,r)
    return confirmedAreas[id] or r.category or (r.pickup and r.pickup.zone) or UNKNOWN
end
local function Text(v)
    if not ns.Secret(v) and type(v)=="string" and #v>0 and #v<=300 then return v end
end
local function ID(v) return ns.Number(v) and v>0 and v%1==0 end
local function Level(v) return ns.Number(v) and v>=0 and v<=1000 and math.floor(v) or 0 end
local function Pickup()
    -- Never use the selected target: it may not be the NPC being spoken to.
    local name=Text(ns.Call(UnitName,"npc"))
    local guid=Text(ns.Call(UnitGUID,"npc"))
    if not name or not guid or not guid:match("^Creature%-") then return end
    local zone=Text(ns.Call(GetRealZoneText) or ns.Call(GetZoneText))
    if not zone then return end
    local p={name=name,zone=zone}
    local map=ns.Call(C_Map and C_Map.GetBestMapForUnit,"player")
    if ID(map) then
        local position=ns.Call(C_Map and C_Map.GetPlayerMapPosition,map,"player")
        local x,y
        if position then x,y=ns.Call(position.GetXY,position) end
        if ns.Number(x) and ns.Number(y) and x>=0 and x<=1 and y>=0 and y<=1 and (x>0 or y>0) then
            p.mapID=map;p.x=x;p.y=y
        end
    end
    return p
end
local function ValidPickup(p)
    if type(p)~="table" or not Text(p.name) or not Text(p.zone) then return end
    local copy={name=p.name,zone=p.zone}
    if ID(p.mapID) and ns.Number(p.x) and ns.Number(p.y) and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 then
        copy.mapID=p.mapID;copy.x=p.x;copy.y=p.y
    end
    return copy
end
local function Install(id,r)
    if ns.index[id] then return false end
    local q={id=id,name=r.name,area=Area(id,r),
        level=Level(r.level),min=0,side="Both",classMask=0,type="Discovered",discovered=true}
    ns.index[id]=q;ns.quests[#ns.quests+1]=q;ns.AddArea(q.area)
    return true
end
function ns.LoadDiscoveries()
    local saved=ns.char.discovered
    ns.char.discovered={}
    if type(saved)~="table" then return end
    for id,r in pairs(saved) do
        if ID(id) and type(r)=="table" and Text(r.name) then
            local copy={name=r.name,level=Level(r.level),pickup=ValidPickup(r.pickup),category=Text(r.category)}
            ns.char.discovered[id]=copy;Install(id,copy)
        end
    end
end
function ns.ObserveQuest(id,title,level,pickup,category)
    if not ns.char or not ID(id) or not Text(title) then return false end
    local existing=ns.index[id]
    -- Keep the bundled inventory authoritative; collect only missing quests.
    if existing and not existing.discovered then return false end
    ns.char.discovered=ns.char.discovered or {}
    local r=ns.char.discovered[id]
    local changed=false
    if not r then
        r={name=title,level=Level(level)};ns.char.discovered[id]=r;changed=true
    end
    if r.name~=title then r.name=title;changed=true end
    local lv=Level(level)
    if lv>0 and r.level~=lv then r.level=lv;changed=true end
    if Text(category) and r.category~=category then r.category=category;changed=true end
    local p=ValidPickup(pickup)
    if p and not r.pickup then r.pickup=p;changed=true end
    if Install(id,r) then
        -- Read only this newly discovered ID, never start a full scan.
        ns.states[id]=ns.ReadStatus(id)
    end
    local q=ns.index[id];q.name=r.name;q.level=r.level
    local area=Area(id,r)
    if q.area~=area then q.area=area;ns.AddArea(q.area);changed=true end
    if changed and ns.char.followZone and area==Text(ns.Call(GetRealZoneText) or ns.Call(GetZoneText)) then
        ns.expanded=ns.expanded or {};ns.expanded[area]=true
        ns.char.area=area
    end
    return changed
end
function ns.DiscoverLog()
    local api=C_QuestLog or {}
    local count=ns.Call(api.GetNumQuestLogEntries)
    if not ns.Number(count) then count=ns.Call(GetNumQuestLogEntries) end
    if not ns.Number(count) then return false end
    local changed=false
    local category
    for i=1,math.min(math.floor(count),200) do
        local info=ns.Call(api.GetInfo,i)
        if (type(info)~="table" or (not ns.Secret(info.isHeader) and not info.isHeader and (not ID(info.questID) or not Text(info.title))))
            and type(GetQuestLogTitle)=="function" then
            local ok,title,level,_,header,_,_,_,id=pcall(GetQuestLogTitle,i)
            if ok and not ns.Secret(header) then info={title=title,level=level,questID=id,isHeader=header} end
        end
        if type(info)=="table" and not ns.Secret(info.isHeader) then
            if info.isHeader then category=Text(info.title)
            elseif ns.ObserveQuest(info.questID,info.title,info.level,nil,category) then changed=true end
        end
    end
    return changed
end
local events=CreateFrame("Frame")
ns.discoveryEvents=events
for _,e in ipairs({"GOSSIP_SHOW","QUEST_DETAIL","QUEST_ACCEPTED","QUEST_LOG_UPDATE"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event)
    if not ns.char then return end
    local changed=false
    if event=="GOSSIP_SHOW" then
        local list=ns.Call(C_GossipInfo and C_GossipInfo.GetAvailableQuests)
        local pickup=Pickup()
        if type(list)=="table" then
            for _,q in ipairs(list) do
                if type(q)=="table" and ns.ObserveQuest(q.questID,q.title,q.questLevel,pickup) then changed=true end
            end
        end
    elseif event=="QUEST_DETAIL" then
        changed=ns.ObserveQuest(ns.Call(GetQuestID),ns.Call(GetTitleText),nil)
        -- Detail panes may be remotely offered; only gossip offers supply pickup evidence.
    -- Acceptance can fire before the new entry is readable. The subsequent log
    -- update retries discovery without requesting a full completion scan.
    elseif event=="QUEST_ACCEPTED" or event=="QUEST_LOG_UPDATE" then
        changed=ns.DiscoverLog()
    end
    if changed and ns.Refresh then ns.Refresh() end
end)
