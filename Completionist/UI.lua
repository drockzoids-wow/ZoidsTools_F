local _,root=...
local ns=root.Completionist
ns.listOffset=0
ns.expanded={}
ns.searchCollapsed={}
local ROWS=14
local function Label(parent,text,x,y,width,template)
    local f=parent:CreateFontString(nil,"OVERLAY",template or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,y);f:SetWidth(width);f:SetHeight(16);f:SetWordWrap(false);f:SetJustifyH("LEFT");f:SetText(text);return f
end
local function Button(parent,text,x,y,width,action)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",action);return b
end
local function Input(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetSize(width,24);e:SetPoint("TOPLEFT",x,y);e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    e:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    return e
end
local function Scrollbar(parent,x,y,height,offsetKey)
    -- The Blizzard scrollbar template calls ScrollFrame methods on its parent.
    -- Our lists use row offsets, so keep the slider and its textures independent.
    local s=CreateFrame("Slider",nil,parent)
    s:SetOrientation("VERTICAL");s:EnableMouse(true)
    local track=s:CreateTexture(nil,"BACKGROUND")
    track:SetAllPoints(s);track:SetColorTexture(.12,.15,.19,1)
    local thumb=s:CreateTexture(nil,"OVERLAY")
    thumb:SetSize(12,24);thumb:SetColorTexture(.65,.53,.32,1)
    s:SetThumbTexture(thumb)
    s:SetPoint("TOPLEFT",x,y);s:SetSize(16,height);s:SetMinMaxValues(0,0);s:SetValueStep(1);s:SetValue(0)
    s:SetScript("OnValueChanged",function(_,v)
        if not ns.rendering then ns[offsetKey]=math.floor(v+.5);ns.RenderRows() end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel",function(_,delta)
        ns[offsetKey]=ns[offsetKey]-delta*3;ns.RenderRows()
    end)
    return s
end
local function Cycle(value,options)
    for i,v in ipairs(options)do if v==value then return options[i%#options+1] end end
    return options[1]
end
function ns.QuestTooltip(row)
    local q=row.quest;if not q or not GameTooltip then return end
    local state=ns.statusInfo[ns.Status(q.id)]
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    GameTooltip:SetText(q.name,1,.82,.4)
    GameTooltip:AddLine(state.label,1,1,1)
    GameTooltip:AddLine(q.area.." - "..q.side, .7,.7,.7)
    GameTooltip:AddLine(string.format("Level %d - Requires %d - ID %d",q.level,q.min,q.id),.7,.7,.7)
    GameTooltip:AddLine(q.type..(q.classMask>0 and " - Class restricted" or ""),.7,.7,.7)
    if q.sourceStatus=="retained" then
        GameTooltip:AddLine("Earlier Forever database entry; absent from the latest index. Availability unverified.",.85,.85,.65,true)
    elseif q.sourceStatus=="secondary" then
        GameTooltip:AddLine("Source: 60.tools. Listed in the Forever client; details inherited from Classic. Availability unverified.",.85,.85,.65,true)
    elseif not q.discovered and not q.observed then
        GameTooltip:AddLine("Source: Wowhead Forever. Datamined availability and requirements remain provisional.",.7,.7,.7,true)
    end
    local saved=ns.char.discovered and ns.char.discovered[q.id]
    if q.discovered or q.observed or saved then
        GameTooltip:AddLine(q.observed and "Added to the guide from verified beta encounters." or "Discovered in game on this character.",.5,1,.7,true)
        GameTooltip:AddLine("Level requirements and faction/class restrictions are not verified.",.7,.7,.7,true)
        local r=saved
        if not (r and r.pickup) and q.observation then r=q.observation end
        local p=r and r.pickup
        if p then
            GameTooltip:AddLine("Observed quest giver: "..p.name.." - "..p.zone,1,.85,.4,true)
            if p.x then
                GameTooltip:AddLine(string.format("Nearby player position: %.1f, %.1f (map %d). Approximate, not an exact NPC location.",p.x*100,p.y*100,p.mapID),.7,.7,.7,true)
            end
        else GameTooltip:AddLine("Pickup location unknown; found in quest dialogue/log.",.7,.7,.7,true) end
        if r and r.category then GameTooltip:AddLine("Quest-log category: "..r.category,.7,.7,.7,true) end
    end
    local locations=ns.pickups and ns.pickups[q.id]
    if locations and #locations>0 then
        for i=1,math.min(4,#locations) do
            local p=locations[i]
            GameTooltip:AddLine(string.format("Pickup: %s - %s (%.1f, %.1f)",p.name,p.zone,p.x*100,p.y*100),1,.85,.4,true)
        end
        if #locations>4 then GameTooltip:AddLine("Additional pickup locations are recorded in the source data.") end
        GameTooltip:AddLine("Source: Wowhead Forever; coordinates not verified in game.",.7,.7,.7,true)
    elseif not q.discovered and not q.observed then
        local starter=ns.starters and ns.starters[q.id]
        GameTooltip:AddLine(starter and ("Starts with: "..starter.." (coordinates unavailable)") or "Pickup location not yet documented.",.7,.7,.7,true)
    end
    GameTooltip:AddLine("Not completed does not confirm that you can accept this quest.",.85,.85,.85,true)
    if ns.Status(q.id)=="unknown" then GameTooltip:AddLine("The game has not supplied a usable completion result.",.85,.85,.85,true) end
    GameTooltip:Show()
end

function ns.ToggleArea(area)
    local open=ns.openAreas[area]
    ns.expanded[area]=not open
    ns.searchCollapsed[area]=open or nil
    ns.char.followZone=false
    ns.Refresh()
end
function ns.RenderRows()
    local f=ns.window;if not f or not ns.listEntries then return end
    if GameTooltip then GameTooltip:Hide() end
    ns.rendering=true
    ns.listOffset=math.max(0,math.min(ns.listOffset,math.max(0,#ns.listEntries-ROWS)))
    f.scroll:SetMinMaxValues(0,math.max(0,#ns.listEntries-ROWS));f.scroll:SetValue(ns.listOffset)
    for i,row in ipairs(f.rows)do
        local entry=ns.listEntries[ns.listOffset+i]
        row.quest=entry and entry.quest;row.area=entry and entry.area
        row:SetShown(entry~=nil)
        if row.quest then
            local q=row.quest;local status=ns.statusInfo[ns.Status(q.id)]
            row.name:SetText("    ["..q.level.."] "..q.name)
            row.status:SetText("|cff"..status.color..(({completed="Done",incomplete="Not done",progress="Active",ready="Ready",unknown="Unknown"})[ns.Status(q.id)]).."|r")
        elseif entry then
            local count=ns.areaCounts[entry.area]
            row.name:SetText("|cffefc77d"..(ns.openAreas[entry.area] and "[-] " or "[+] ")..entry.area.."|r")
            row.status:SetText(count.done.." / "..count.total)
        end
    end
    f.range:SetText(string.format("%d matching / %d total quests",#ns.visibleQuests,#ns.quests))
    ns.rendering=false
end
function ns.Refresh()
    local f=ns.window;if not f then return end
    ns.RefreshCharacter()
    local query=(f.search:GetText() or ""):lower()
    local searching=query~=""
    local byArea={}
    ns.visibleQuests={};ns.areaCounts={};ns.listEntries={};ns.openAreas={}
    for _,q in ipairs(ns.quests)do
        if ns.Eligible(q) then
            local count=ns.areaCounts[q.area] or {done=0,total=0}
            ns.areaCounts[q.area]=count;count.total=count.total+1
            if ns.Status(q.id)=="completed" then count.done=count.done+1 end
            if ns.MatchesStatus(ns.Status(q.id)) and (not searching or q.area:lower():find(query,1,true)
                or q.name:lower():find(query,1,true) or tostring(q.id)==query) then
                byArea[q.area]=byArea[q.area] or {}
                table.insert(byArea[q.area],q);table.insert(ns.visibleQuests,q)
            end
        end
    end
    local jump
    for _,area in ipairs(ns.areas)do
        if byArea[area] then
            table.sort(byArea[area],function(a,b)if a.level==b.level then return a.name<b.name end;return a.level<b.level end)
            if ns.jumpToArea==area then jump=#ns.listEntries end
            table.insert(ns.listEntries,{area=area})
            local open=ns.expanded[area] or (searching and not ns.searchCollapsed[area])
            ns.openAreas[area]=open
            if open then
                for _,q in ipairs(byArea[area])do table.insert(ns.listEntries,{quest=q}) end
            end
        end
    end
    if ns.jumpToArea then ns.listOffset=jump or 0;ns.jumpToArea=nil end
    f.statusButton:SetText(({All="All quests",Unfinished="Unfinished",Completed="Done",["In log"]="In log",Unknown="Unknown"})[ns.char.statusFilter])
    f.factionButton:SetText(ns.char.factionFilter=="Mine" and "Mine" or ns.char.factionFilter)
    f.follow:SetChecked(ns.char.followZone)
    f.sync:SetText(ns.syncMessage or "Completion not checked yet.")
    f.refreshButton:SetEnabled(not ns.scan and not ns.waiting)
    ns.RenderRows()
end

function ns.SaveTrackerPosition()
    local f=ns.window
    -- Store the top-left corner so changing height never moves the header.
    local x,y=f:GetLeft(),f:GetTop()
    if ns.Number(x) and ns.Number(y) then
        f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
        ns.char.windowPoint={point="TOPLEFT",relative="BOTTOMLEFT",x=x,y=y}
    end
    ns.SaveTrackerSettings()
end
function ns.StopTrackerMoving()
    local f=ns.window
    if f.moving then f:StopMovingOrSizing();f.moving=nil;ns.SaveTrackerPosition() end
end
function ns.ApplyTrackerState(initializing)
    local f=ns.window;if not f then return end
    ns.StopTrackerMoving()
    -- Login must not replace the saved anchor with unfinished frame geometry.
    if not initializing then ns.SaveTrackerPosition() end
    local minimized=ns.char.minimized==true
    f:SetSize(minimized and 250 or 360,minimized and 34 or 520)
    f.body:SetShown(not minimized)
    f:SetMovable(not ns.char.locked)
    f.lockButton:SetText(ns.char.locked and "Unlock" or "Lock")
    f.minimizeButton:SetText(minimized and "+" or "-")
    f.lockButton:ClearAllPoints();f.lockButton:SetPoint("TOPRIGHT",-42,-5)
    f.minimizeButton:ClearAllPoints();f.minimizeButton:SetPoint("TOPRIGHT",-8,-5)
    f:SetBackdropColor(.055,.075,.10,ns.char.locked and .55 or .85)
    f:SetBackdropBorderColor(.45,.38,.25,ns.char.locked and .25 or .75)
    if minimized then f.search:ClearFocus();if GameTooltip then GameTooltip:Hide() end end
end
function ns.ToggleMinimized()
    ns.char.minimized=not ns.char.minimized;ns.ApplyTrackerState()
end
function ns.ToggleLocked()
    ns.char.locked=not ns.char.locked;ns.ApplyTrackerState()
end
function ns.CreateUI()
    local f=CreateFrame("Frame","ZoidsTools_FCompletionistWindow",UIParent,"BackdropTemplate")
    ns.window=f
    -- Use the saved size before restoring/clamping a minimized window near an edge.
    f:SetSize(ns.char.minimized and 250 or 360,ns.char.minimized and 34 or 520)
    f:SetPoint("CENTER");f:SetClampedToScreen(true)
    -- SavedVariables own this anchor; do not let the client's frame cache override it.
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(.055,.075,.10,.98);f:SetBackdropBorderColor(.45,.38,.25,1)

    f:EnableMouse(true)
    f.body=CreateFrame("Frame",nil,f)
    f.body:SetSize(360,486);f.body:SetPoint("TOPLEFT",0,-34)
    f.header=CreateFrame("Frame",nil,f)
    f.header:SetPoint("TOPLEFT");f.header:SetPoint("TOPRIGHT");f.header:SetHeight(34)
    f.header:EnableMouse(true);f.header:RegisterForDrag("LeftButton")
    -- Child buttons sit above the drag surface and receive their own clicks.
    f.header:SetScript("OnDragStart",function()
        if not ns.char.locked then f:StartMoving();f.moving=true end
    end)
    f.header:SetScript("OnDragStop",ns.StopTrackerMoving)
    local p=ns.char.windowPoint
    if type(p)=="table" and ns.Number(p.x) and ns.Number(p.y) then
        local ok=pcall(function()f:ClearAllPoints();f:SetPoint(p.point,UIParent,p.relative,p.x,p.y)end)
        if not ok then f:ClearAllPoints();f:SetPoint("CENTER") end
    end

    Label(f.header,"Completionist",12,-11,140,"GameFontNormal")
    f.lockButton=Button(f.header,"Lock",0,0,54,ns.ToggleLocked)
    f.minimizeButton=Button(f.header,"-",0,0,26,ns.ToggleMinimized)
    Label(f.body,"Search quests / areas",14,-4,330)
    f.search=Input(f.body,18,-20,324)
    f.statusButton=Button(f.body,"All quests",12,-50,120,function()
        ns.char.statusFilter=Cycle(ns.char.statusFilter,{"All","Unfinished","Completed","In log","Unknown"});ns.listOffset=0;ns.Refresh()
    end)
    f.factionButton=Button(f.body,"Mine",138,-50,106,function()
        ns.char.factionFilter=Cycle(ns.char.factionFilter,{"Mine","Alliance","Horde","All"});ns.listOffset=0;ns.Refresh()
    end)
    f.refreshButton=Button(f.body,"Refresh",250,-50,96,function()ns.Sync(true)end)
    f.follow=CreateFrame("CheckButton",nil,f.body,"UICheckButtonTemplate")
    f.follow:SetSize(24,24);f.follow:SetPoint("TOPLEFT",11,-79)
    Label(f.body,"Follow area",36,-84,122)
    f.follow:SetScript("OnClick",function(self)
        ns.char.followZone=self:GetChecked()==true
        if ns.char.followZone then ns.UseCurrentArea() else ns.Refresh() end
    end)
    f.rows={}
    local function Scroll(_,delta)ns.listOffset=ns.listOffset-delta*3;ns.RenderRows()end
    for i=1,ROWS do
        local row=CreateFrame("Button",nil,f.body);row:SetSize(314,21);row:SetPoint("TOPLEFT",14,-114-(i-1)*21)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.name=Label(row,"",2,-3,228);row.status=Label(row,"",236,-3,78)
        row.name:SetWordWrap(false);row.status:SetWordWrap(false)
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",Scroll)
        row:SetScript("OnClick",function(self)if self.area then ns.ToggleArea(self.area)end end)
        row:SetScript("OnEnter",function(self)
            if self.quest then ns.QuestTooltip(self)
            elseif self.area and GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.area)
                GameTooltip:AddLine("Click to expand/collapse. Counts: completed / total.",1,1,1,true);GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
        f.rows[i]=row
    end
    f.scroll=Scrollbar(f.body,334,-114,294,"listOffset")
    f.range=Label(f.body,"",14,-416,332)
    f.sync=Label(f.body,"",14,-440,332)
    f.sync:SetHeight(36);f.sync:SetWordWrap(true);f.sync:SetJustifyV("TOP")
    f.search:SetScript("OnTextChanged",function()ns.listOffset=0;ns.searchCollapsed={};ns.Refresh()end)
    f:SetScript("OnShow",function()ns.char.show=true;ns.Refresh()end)
    f:SetScript("OnHide",function()ns.StopTrackerMoving();ns.char.show=false;f.search:ClearFocus();if GameTooltip then GameTooltip:Hide()end end)
    ns.ApplyTrackerState(true)
    f:SetShown(ns.char.show~=false)
    ns.Refresh()
end
