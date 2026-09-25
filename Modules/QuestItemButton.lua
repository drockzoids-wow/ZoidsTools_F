local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local button, watcher
local moveMode, moving = false, false
local elapsed = 0
local function Secret(v) return type(issecretvalue)=="function" and issecretvalue(v) end
local function Call(fn, ...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d=pcall(fn,...)
    if ok and not Secret(a) and not Secret(b) and not Secret(c) and not Secret(d) then return a,b,c,d end
end
local function Number(v) return not Secret(v) and type(v)=="number" and v==v and math.abs(v)<math.huge end
local function True(v) return not Secret(v) and (v==true or v==1) end
local function Combat() return True(Call(InCombatLockdown)) end
local function Settings() return ns.db and ns.db.quests end

function ns:GetQuestItemButtonEnabled()
    local db=Settings();return db and db.questItemButtonEnabled==true
end
function ns:IsQuestItemButtonMoveMode() return moveMode end

local function Info(index)
    local info=Call(C_QuestLog and C_QuestLog.GetInfo,index)
    if type(info)=="table" and not Secret(info.questID) and Number(info.questID) and info.questID>0
        and not Secret(info.isHeader) and not True(info.isHeader) and not Secret(info.isHidden) and not True(info.isHidden) then
        return info.questID, not Secret(info.title) and info.title
    end
    if type(GetQuestLogTitle)=="function" then
        local ok,title,_,_,header,_,_,_,id=pcall(GetQuestLogTitle,index)
        if ok and not Secret(header) and not True(header) and Number(id) and id>0 then
            return id,not Secret(title) and title
        end
    end
end

function ns:FindNearbyQuestItem()
    local api=C_QuestLog or {}
    local count=Call(api.GetNumQuestLogEntries) or Call(GetNumQuestLogEntries)
    if not Number(count) then return end
    local tracked=Call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
    local best
    for index=1,math.min(math.floor(count),200) do
        local id,title=Info(index)
        if id then
            local link,icon,charges,showComplete=Call(GetQuestLogSpecialItemInfo,index)
            local itemID=type(link)=="string" and tonumber(link:match("item:(%d+)"))
            local complete=Call(api.IsComplete or IsQuestComplete,id)
            if itemID and itemID>0 and (not True(complete) or True(showComplete)) then
                local inside=True(Call(C_Minimap and C_Minimap.IsInsideQuestBlob,id))
                local distance,onContinent=Call(api.GetDistanceSqToQuest,id)
                if not api.GetDistanceSqToQuest then distance,onContinent=Call(GetDistanceSqToQuest,index) end
                local validDistance=Number(distance) and distance>=0 and True(onContinent)
                local inRange=True(Call(IsQuestLogSpecialItemInRange,index))
                if inside or (validDistance and distance<=250*250) or (inRange and onContinent~=false) then
                    local rank=inside and 2 or (inRange and 1 or 0)
                    local isTracked=id==tracked
                    local d=validDistance and distance or math.huge
                    if not best or rank>best.rank or (rank==best.rank and
                        ((isTracked and not best.tracked) or (isTracked==best.tracked and d<best.distance))) then
                        best={id=id,index=index,title=type(title)=="string" and title or "",itemID=itemID,
                            link=link,icon=icon,charges=Number(charges) and charges or 0,
                            rank=rank,tracked=isTracked,distance=d}
                    end
                end
            end
        end
    end
    return best
end

local function StopMoving()
    if not moving or not button or Combat() then return end
    button:StopMovingOrSizing();moving=false
    local point,_,relative,x,y=button:GetPoint()
    if point and Number(x) and Number(y) then
        Settings().questItemButton={point=point,relativePoint=relative,x=x,y=y}
    end
end
local function Cooldown()
    if not button or not button.candidate then return end
    local c=button.candidate
    -- Bind by item ID, and recheck log identity before reading index-based data.
    local id=Info(c.index)
    local link=Call(GetQuestLogSpecialItemInfo,c.index)
    local start,duration,enabled
    if id==c.id and link==c.link then
        start,duration,enabled=Call(GetQuestLogSpecialItemCooldown,c.index)
    end
    if Number(start) and Number(duration) and True(enabled) then
        button.cooldown:SetCooldown(start,duration)
    else button.cooldown:Clear() end
    local range=id==c.id and Call(IsQuestLogSpecialItemInRange,c.index)
    if range==false or range==0 then button.icon:SetVertexColor(1,.25,.25)
    else button.icon:SetVertexColor(1,1,1) end
end
local function CreateButton()
    if button or Combat() then return end
    button=CreateFrame("Button","ZoidsTools_FQuestItemButton",UIParent,"SecureActionButtonTemplate")
    ns.questItemButton=button
    button:SetSize(46,46);button:SetClampedToScreen(true);button:SetMovable(true)
    if button.SetDontSavePosition then button:SetDontSavePosition(true) end
    button:RegisterForClicks("AnyDown","AnyUp");button:RegisterForDrag("RightButton")
    button:SetAttribute("pressAndHoldAction",true)
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetAllPoints(button)
    button.cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button.count=button:CreateFontString(nil,"OVERLAY","NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT",-2,2)
    local p=Settings().questItemButton
    local ok=pcall(button.SetPoint,button,p.point,UIParent,p.relativePoint,p.x,p.y)
    if not ok then button:ClearAllPoints();button:SetPoint("CENTER",UIParent,"CENTER",280,-80) end
    button:SetScript("OnDragStart",function()
        if not Combat() then button:StartMoving();moving=true end
    end)
    button:SetScript("OnDragStop",StopMoving)
    button:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        if self.candidate then
            GameTooltip:SetHyperlink(self.candidate.link)
            GameTooltip:AddLine(self.candidate.title,1,.82,.4,true)
        else GameTooltip:SetText(L["Quest item button"]) end
        GameTooltip:AddLine(L["Right-drag to move. Item selection updates after combat."],.7,.7,.7,true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    button:Hide()
end

function ns:RefreshQuestItemButton()
    if Combat() then Cooldown();return end
    if not self:GetQuestItemButtonEnabled() then
        if button then
            StopMoving();button:Hide();button:SetAttribute("type1",nil);button:SetAttribute("item1",nil)
            button.candidate=nil
        end
        return
    end
    CreateButton()
    local candidate=self:FindNearbyQuestItem()
    if button.candidate and (not candidate or candidate.itemID~=button.candidate.itemID) and GameTooltip
        and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    button.candidate=candidate
    button:SetAttribute("type1",candidate and not moveMode and "item" or nil)
    button:SetAttribute("item1",candidate and not moveMode and ("item:"..candidate.itemID) or nil)
    button.icon:SetTexture(candidate and candidate.icon or 134400)
    button.icon:SetVertexColor(1,1,1)
    button.count:SetText(candidate and candidate.charges>1 and tostring(candidate.charges) or "")
    if not candidate then button.cooldown:Clear() end
    if not candidate and not moveMode then StopMoving() end
    button:SetShown(candidate~=nil or moveMode)
    Cooldown()
end
function ns:SetQuestItemButtonEnabled(value)
    Settings().questItemButtonEnabled=value==true
    if not value then moveMode=false end
    self:RefreshQuestItemButton()
end
function ns:ToggleQuestItemButtonMoveMode()
    if Combat() then self:Print(L["Move the quest item button after combat ends."]);return end
    StopMoving();moveMode=not moveMode;self:RefreshQuestItemButton()
end
function ns:InitializeQuestItemButton()
    if watcher then return end
    watcher=CreateFrame("Frame");ns.questItemWatcher=watcher
    for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN",
        "BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","PLAYER_TARGET_CHANGED","ZONE_CHANGED_NEW_AREA",
        "PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_LOGOUT",
        "SUPER_TRACKING_CHANGED","BAG_UPDATE_COOLDOWN"}) do ns:RegisterCompatibleEvent(watcher,event) end
    watcher:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_LOGOUT" or event=="PLAYER_REGEN_DISABLED" then StopMoving();return end
        if event=="PLAYER_REGEN_ENABLED" then StopMoving() end
        -- Coalesce bursts of log/item events into the next proximity update.
        elapsed=.5
    end)
    watcher:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed<.5 then return end
        elapsed=0;self:RefreshQuestItemButton()
    end)
    self:RefreshQuestItemButton()
end
