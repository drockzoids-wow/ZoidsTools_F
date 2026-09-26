local combat=false
local methods={}
local function protected(self) assert(not combat or not self.secure,"Protected mutation during combat") end
function methods:SetAttribute(k,v) protected(self);self.attributes[k]=v end
function methods:SetShown(v) protected(self);self.shown=v end
function methods:Show()self:SetShown(true)end
function methods:Hide()self:SetShown(false)end
function methods:SetPoint(...)
    protected(self);self.point={...};self.points=self.points or {};self.points[self.point[1]]=self.point
end
function methods:GetPoint()return unpack(self.point)end
function methods:ClearAllPoints()protected(self);self.point=nil end
function methods:StartMoving()protected(self);self.moving=true end
function methods:StopMovingOrSizing()protected(self);self.moving=false end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:RegisterEvent(e)self.events[e]=true end
function methods:SetTexture(v)self.texture=v end
function methods:SetText(v)self.text=v end
function methods:SetVertexColor(...)self.color={...}end
function methods:SetCooldown(s,d)self.start=s;self.duration=d end
function methods:Clear()self.start=nil;self.duration=nil end
function methods:CreateTexture()return CreateFrame()end
function methods:CreateFontString()return CreateFrame()end
function methods:EnableMouse(value)self.mouseEnabled=value end
function methods:RegisterForDrag(...)self.dragButtons={...}end
function methods:RegisterForClicks(...)self.clicks={...}end
function methods:SetAllPoints(region)self.allPoints=region end
function methods:SetBackdrop(value)self.backdrop=value end
function methods:SetBackdropColor()end
function methods:SetBackdropBorderColor()end
for _,name in ipairs({"SetSize","SetClampedToScreen","SetMovable","SetDontSavePosition",
    "SetNormalTexture","SetHighlightTexture"}) do
    methods[name]=function()end
end
function CreateFrame(_,name,_,template)
    local f=setmetatable({scripts={},attributes={},events={},secure=template and template:find("SecureActionButtonTemplate",1,true)~=nil},{__index=methods})
    if name then _G[name]=f end
    return f
end
UIParent=CreateFrame()
function InCombatLockdown()return combat end
local secret={}
function issecretvalue(v)return v==secret end
local log={}
local tracked
C_SuperTrack={GetSuperTrackedQuestID=function()return tracked end}
C_QuestLog={
    GetNumQuestLogEntries=function()return #log end,
    GetInfo=function(i)return {questID=log[i].id,title="Test",isHeader=log[i].header}end,
    IsComplete=function(id)for _,q in ipairs(log)do if q.id==id then return q.complete end end end,
    GetDistanceSqToQuest=function(id)for _,q in ipairs(log)do if q.id==id then return q.distance,q.continent end end end,
}
C_Minimap={IsInsideQuestBlob=function(id)for _,q in ipairs(log)do if q.id==id then return q.inside end end end}
function GetQuestLogSpecialItemInfo(i)
    local q=log[i];if not q then return end
    return q.link,q.icon or 134400,q.charges or 1,q.showComplete
end
function IsQuestLogSpecialItemInRange(i)return log[i] and log[i].range end
function GetQuestLogSpecialItemCooldown()return 10,30,1 end

function RunQuestItemTests(ns)
    ns.Print=function()end
    ns:InitializeQuestItemButton()
    local b=ns.questItemButton
    assert(not b.shown)
    assert(b.mouseEnabled and b.cooldown.mouseEnabled==false)
    assert(b.cooldown.allPoints==b.icon and b.backdrop.edgeSize==9)
    assert(b.icon.points.TOPLEFT[4]==4 and b.icon.points.BOTTOMRIGHT[4]==-4)
    assert(b.dragButtons[1]=="LeftButton" and b.dragButtons[2]=="RightButton")
    assert(b.clicks[1]=="AnyDown" and b.clicks[2]=="AnyUp")
    log={{id=1,link="item:100",distance=62500,continent=true,charges=3}}
    ns:RefreshQuestItemButton()
    assert(b.shown and b.attributes.item1=="item:100" and b.count.text=="3" and b.cooldown.duration==30)
    assert(b.attributes.type1=="item" and not b.moveLabel.shown)
    b.scripts.OnDragStart(b,"LeftButton");assert(not b.moving) -- Normal left-click remains an item action.
    b.scripts.OnDragStart(b,"RightButton");assert(b.moving)
    local originalLog=log;log={}
    ns:RefreshQuestItemButton();assert(b.shown and b.moving and b.attributes.item1=="item:100")
    log=originalLog;b.scripts.OnDragStop()
    log[1].distance=62501;ns:RefreshQuestItemButton();assert(not b.shown)
    log[1].distance=nil;ns:RefreshQuestItemButton();assert(not b.shown)
    log[1].range=1;ns:RefreshQuestItemButton();assert(b.shown)
    log[1].continent=false;ns:RefreshQuestItemButton();assert(not b.shown)
    log[1].inside=true;ns:RefreshQuestItemButton();assert(b.shown)
    log[1].complete=true;ns:RefreshQuestItemButton();assert(not b.shown)
    log[1].showComplete=true;ns:RefreshQuestItemButton();assert(b.shown)
    log[1].showComplete=false;log[1].complete=false
    log[2]={id=2,link="item:200",distance=4,continent=true}
    tracked=2;ns:RefreshQuestItemButton();assert(b.candidate.id==1) -- In area takes priority.
    log[1].inside=false;log[1].range=nil;log[1].continent=true;log[1].distance=1
    ns:RefreshQuestItemButton();assert(b.candidate.id==2) -- Selected quest before nearest.
    tracked=nil;ns:RefreshQuestItemButton();assert(b.candidate.id==1)
    combat=true
    log[1],log[2]=log[2],log[1] -- Log indexes can change, secure item ID must not.
    ns:RefreshQuestItemButton();assert(b.attributes.item1=="item:100" and b.cooldown.duration==nil)
    ns:SetQuestItemButtonEnabled(false);assert(b.shown)
    combat=false;ns.questItemWatcher.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
    ns.questItemWatcher.scripts.OnUpdate(nil,.01);assert(not b.shown and b.attributes.item1==nil)
    ns:SetQuestItemButtonEnabled(true)
    ns:ToggleQuestItemButtonMoveMode();assert(b.shown and not b.attributes.type1 and b.moveLabel.shown)
    b.scripts.OnDragStart(b,"LeftButton");assert(b.moving)
    b:SetPoint("CENTER",UIParent,"CENTER",42,73);b.scripts.OnDragStop()
    assert(ns.db.quests.questItemButton.x==42 and ns.db.quests.questItemButton.y==73)
    ns:ToggleQuestItemButtonMoveMode();assert(b.attributes.type1=="item" and b.attributes.item1=="item:100" and not b.moveLabel.shown)
    combat=true;b.scripts.OnDragStart(b,"RightButton");assert(not b.moving);combat=false
    log={{id=secret,link="item:100",inside=true}};ns:RefreshQuestItemButton();assert(not b.shown)
    log={{id=1,link=secret,inside=true}};ns:RefreshQuestItemButton();assert(not b.shown)
    log={{id=1,link="item:100",distance=secret,continent=true,range=secret,inside=secret}}
    ns:RefreshQuestItemButton();assert(not b.shown)
    C_QuestLog.GetDistanceSqToQuest=function()error("unavailable")end
    ns:RefreshQuestItemButton();assert(not b.shown)
    -- Legacy client path uses log indexes for distance, IDs for completion.
    C_QuestLog=nil;C_Minimap=nil
    function GetNumQuestLogEntries()return 1 end
    function GetQuestLogTitle()return "Legacy",1,nil,false,nil,nil,nil,1 end
    function GetDistanceSqToQuest(i)assert(i==1);return 100,true end
    log={{id=1,link="item:100"}};ns:RefreshQuestItemButton();assert(b.shown)
    GetQuestLogSpecialItemInfo=nil;ns:RefreshQuestItemButton();assert(not b.shown)
end
