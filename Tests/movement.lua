-- Behavioral smoke tests with named Blizzard frames and script hooks.
local combat = false
function InCombatLockdown() return combat end
function IsControlKeyDown() return true end
function wipe(t) for k in pairs(t) do t[k] = nil end end
C_Timer = nil
C_EventUtils = { IsEventValid = function(event) return event ~= 'BAG_OPEN' end }
local methods = {}
local function noop() end
for _, name in ipairs({ 'SetClampedToScreen', 'EnableMouse', 'RegisterForDrag',
    'SetDontSavePosition', 'EnableMouseWheel', 'SetBackdrop', 'SetBackdropColor',
    'SetBackdropBorderColor', 'SetHeight', 'SetWidth', 'SetSize', 'SetFrameStrata',
    'SetFrameLevel', 'SetText', 'SetAlpha' }) do methods[name] = noop end
function methods:GetName() return self.name end
function methods:GetID() return self.bagID end
function methods:IsProtected() return self.protected == true end
function methods:SetMovable(v) self.movable = v end
function methods:SetUserPlaced(v) self.userPlaced = v end
function methods:GetFrameStrata() return 'MEDIUM' end
function methods:GetFrameLevel() return 1 end
function methods:GetScale() return self.scale end
function methods:SetScale(v) self.scale = v end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(i) return unpack(self.points[i or 1]) end
function methods:SetPoint(...) self.points[1] = {...} end
function methods:ClearAllPoints() self.points = {} end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:IsShown() return self.shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(v) self.shown = v end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:CreateFontString() return CreateFrame('FontString') end
function CreateFrame(_, name)
    local frame = setmetatable({ name = name, scale = 1, points = {},
        shown = true, scripts = {}, events = {} }, { __index = methods })
    if name then _G[name] = frame end
    frames[#frames + 1] = frame
    return frame
end
function hooksecurefunc(target, key, hook)
    if type(target) ~= 'table' then return end
    local original = target[key]
    target[key] = function(...) local result = original(...); hook(...); return result end
end
UIParent = CreateFrame('Frame', 'UIParent')
for _, name in ipairs({ 'CharacterFrame', 'ContainerFrame1', 'ContainerFrameCombinedBags',
    'FlightMapFrame', 'GuildControlUI' }) do
    local f = CreateFrame('Frame', name)
    f:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
end
UIPanelWindows = { CharacterFrame = {}, FlightMapFrame = {}, GuildControlUI = {} }
ns.db.windows.points.FlightMapFrame = { x = 42 }
ns:InitializeMovableWindows()
local panel = CharacterFrameZoidsTools_FWindowDragHandle
local bag = ContainerFrame1ZoidsTools_FDragHandle
assert(panel and bag and ContainerFrameCombinedBagsZoidsTools_FDragHandle)
assert(not FlightMapFrame.movable and not GuildControlUI.movable)
assert(ns.db.windows.points.FlightMapFrame == nil)
local watcher = frames[#frames] -- Find watcher by its event registration, not allocation order.
for _, frame in ipairs(frames) do
    if frame.events and frame.events.PLAYER_REGEN_ENABLED then watcher = frame end
end
assert(not watcher.events.BAG_OPEN and watcher.events.BAG_CLOSED)
panel.scripts.OnDragStart(panel)
assert(CharacterFrame.moving)
CharacterFrame:SetPoint('CENTER', UIParent, 'CENTER', 120, 60)
panel.scripts.OnDragStop(panel)
assert(not CharacterFrame.moving and ns.db.windows.points.CharacterFrame.x == 120)
CharacterFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(select(4, CharacterFrame:GetPoint()) == 120)
bag.scripts.OnDragStart(bag)
ContainerFrame1:SetPoint('CENTER', UIParent, 'CENTER', 200, -50)
bag.scripts.OnDragStop(bag)
assert(ns.db.windows.points.ContainerFrame1.x == 200)
panel.scripts.OnMouseWheel(panel, 1)
assert(math.abs(CharacterFrame.scale - 1.05) < 0.001)
assert(ns.db.windows.scales.CharacterFrame == CharacterFrame.scale)
for i = 1, 40 do panel.scripts.OnMouseWheel(panel, 1) end
assert(CharacterFrame.scale == 1.8)
for i = 1, 40 do panel.scripts.OnMouseWheel(panel, -1) end
assert(CharacterFrame.scale == 0.6)
ns.db.windows.moveBags = false
ns:RefreshBagMovement()
assert(not bag.shown)
bag.scripts.OnMouseWheel(bag, 1)
assert(ContainerFrame1.scale == 1)
ns.db.windows.enabled = false
ns:RefreshMovableWindows()
assert(not panel.shown)
panel.scripts.OnDragStart(panel)
assert(not CharacterFrame.moving)
ns.db.windows.enabled = true
ns.db.windows.moveBags = true
ns:RefreshMovableWindows()
assert(panel.shown and bag.shown)
-- UIParent may report protected even though an unprotected bag can be
-- positioned relative to it. Check the bag being moved, not the screen root.
UIParent.protected = true
combat = true
watcher.scripts.OnEvent(watcher, 'PLAYER_REGEN_DISABLED')
assert(watcher.events.BAG_CLOSED)
-- Blizzard relayout on opening a bag must not win over its saved position.
ContainerFrame1:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
ContainerFrame1.scripts.OnShow(ContainerFrame1)
assert(select(4, ContainerFrame1:GetPoint()) == 200)
bag.scripts.OnDragStart(bag)
assert(ContainerFrame1.moving)
ContainerFrame1:SetPoint('CENTER', UIParent, 'CENTER', 350, -80)
watcher.scripts.OnEvent(watcher, 'BAG_UPDATE_DELAYED')
assert(select(4, ContainerFrame1:GetPoint()) == 350) -- Don't restore mid-drag.
bag.scripts.OnDragStop(bag)
assert(not ContainerFrame1.moving and ns.db.windows.points.ContainerFrame1.x == 350)
ContainerFrame1:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(select(4, ContainerFrame1:GetPoint()) == 350)
-- Combined bags and frames first created in combat use the same policy.
local combined = ContainerFrameCombinedBagsZoidsTools_FDragHandle
combined.scripts.OnDragStart(combined)
assert(ContainerFrameCombinedBags.moving)
ContainerFrameCombinedBags:SetPoint('CENTER', UIParent, 'CENTER', 450, -100)
combined.scripts.OnDragStop(combined)
assert(ns.db.windows.points.ContainerFrameCombinedBags.x == 450)
ContainerFrameCombinedBags:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
ContainerFrameCombinedBags.scripts.OnShow(ContainerFrameCombinedBags)
assert(select(4, ContainerFrameCombinedBags:GetPoint()) == 450)
local lateBag = CreateFrame('Frame', 'ContainerFrame2')
lateBag:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
watcher.scripts.OnEvent(watcher, 'BAG_UPDATE_DELAYED')
assert(ContainerFrame2ZoidsTools_FDragHandle)
-- Protected bags must never be moved, reanchored, or initialized in combat.
ContainerFrame1.protected = true
local originalStart = ContainerFrame1.StartMoving
local originalPoint = ContainerFrame1.SetPoint
ContainerFrame1.StartMoving = function() error('Protected drag attempted') end
ContainerFrame1.SetPoint = function() error('Protected restore attempted') end
bag.scripts.OnDragStart(bag)
bag.scripts.OnDragStop(bag)
ContainerFrame1.scripts.OnShow(ContainerFrame1)
assert(not ContainerFrame1.moving and ns.db.windows.points.ContainerFrame1.x == 350)
local protectedBag = CreateFrame('Frame', 'ContainerFrame3')
protectedBag.protected = true
protectedBag.SetMovable = function() error('Protected initialization attempted') end
watcher.scripts.OnEvent(watcher, 'BAG_UPDATE_DELAYED')
assert(not ContainerFrame3ZoidsTools_FDragHandle)
protectedBag.SetMovable = nil
ContainerFrame1.StartMoving = originalStart
ContainerFrame1.SetPoint = originalPoint
ContainerFrame1.protected = false
bag.scripts.OnMouseWheel(bag, 1)
assert(ContainerFrame1.scale == 1) -- Scaling still waits for combat to end.
panel.scripts.OnDragStart(panel)
assert(not CharacterFrame.moving)
assert(ns:ResetMovableWindowPositions() == false)
assert(ns:ResetMovableWindowScales() == false)
panel.scripts.OnMouseUp(panel, 'RightButton')
assert(ns.db.windows.points.CharacterFrame and ns.db.windows.scales.CharacterFrame)
combat = false
watcher.scripts.OnEvent(watcher, 'PLAYER_REGEN_ENABLED')
assert(watcher.events.BAG_CLOSED)
assert(ContainerFrame3ZoidsTools_FDragHandle)
assert(select(4, ContainerFrame1:GetPoint()) == 350)
assert(select(4, ContainerFrameCombinedBags:GetPoint()) == 450)
ns:ResetMovableWindowScales()
assert(CharacterFrame.scale == 1 and next(ns.db.windows.scales) == nil)
ns:ResetMovableWindowPositions()
assert(next(ns.db.windows.points) == nil)
-- Late-loaded windows receive handles without requiring a reload.
AuctionFrame = CreateFrame('Frame', 'AuctionFrame')
AuctionFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
watcher.scripts.OnEvent(watcher, 'ADDON_LOADED')
assert(AuctionFrameZoidsTools_FWindowDragHandle)

-- Profession bags borrow the combined bag anchor only while it is closed.
local profession = CreateFrame('Frame', 'ContainerFrame4')
profession.bagID = 1
local secondProfession = CreateFrame('Frame', 'ContainerFrame5')
secondProfession.bagID = 2
ContainerIDToInventoryID = function(id) return id + 20 end
IsInventoryItemProfessionBag = function(_, slot) return slot == 21 or slot == 22 end
local shared = {point='BOTTOMRIGHT',relativeTo='UIParent',relativePoint='BOTTOMRIGHT',x=-120,y=180}
ns.db.windows.points.ContainerFrameCombinedBags = shared
local oldProfession = {point='CENTER',relativeTo='UIParent',relativePoint='CENTER',x=99,y=88}
ns.db.windows.points.ContainerFrame4 = oldProfession
function UpdateContainerFrameAnchors()
    for _, frame in ipairs({profession, secondProfession}) do
        if ContainerFrameCombinedBags:IsShown() then
            assert(not frame.userPlaced, 'Solo placement must be released before native layout')
            frame:SetPoint('BOTTOMRIGHT', ContainerFrameCombinedBags, 'BOTTOMLEFT', -8, 0)
        else
            frame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -10, 20)
        end
    end
end
for _, inCombat in ipairs({false, true}) do
    combat = inCombat
    ContainerFrameCombinedBags:Hide()
    watcher.scripts.OnEvent(watcher, 'BAG_UPDATE_DELAYED')
    ContainerFrameCombinedBags.scripts.OnHide(ContainerFrameCombinedBags)
    for _, frame in ipairs({profession, secondProfession}) do
        frame.scripts.OnShow(frame)
        local point, relative, relativePoint, x, y = frame:GetPoint()
        assert(point=='BOTTOMRIGHT' and relative==UIParent and relativePoint=='BOTTOMRIGHT' and x==-120 and y==180)
    end
    UpdateContainerFrameAnchors() -- Later Blizzard layout must still use the solo anchor.
    assert(select(4, profession:GetPoint())==-120)
    ContainerFrameCombinedBags:Show()
    ContainerFrameCombinedBags.scripts.OnShow(ContainerFrameCombinedBags)
    assert(select(2, profession:GetPoint())==ContainerFrameCombinedBags)
    assert(select(4, profession:GetPoint())==-8)
    assert(select(2, secondProfession:GetPoint())==ContainerFrameCombinedBags)
    ContainerFrameCombinedBags:Hide()
    ContainerFrameCombinedBags.scripts.OnHide(ContainerFrameCombinedBags)
    assert(select(2, profession:GetPoint())==UIParent and select(4, profession:GetPoint())==-120)
    assert(ns.db.windows.points.ContainerFrameCombinedBags==shared)
    assert(ns.db.windows.points.ContainerFrame4==oldProfession)
end
-- Frame IDs are reused: a regular bag must not inherit the profession behavior.
profession.bagID=0
profession:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(select(4, profession:GetPoint())==99)
profession.bagID=1
ns.db.windows.moveBags=false
profession:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(select(4, profession:GetPoint())==0)
ns.db.windows.moveBags=true
-- Legacy family lookup and absent APIs fail safely.
IsInventoryItemProfessionBag=nil
GetContainerNumFreeSlots=function(id)return 0,id==1 and 32 or 0 end
profession:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(select(4, profession:GetPoint())==-120)
GetContainerNumFreeSlots=nil
profession:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
assert(select(4, profession:GetPoint())==99)
combat=false

-- Shared carried-bag corners: real open/close order and native stacking are retained.
for _,f in ipairs(frames) do if f.name and f.name:match('^ContainerFrame') then f.shown=false end end
local backpack=ContainerFrame1
local small=ContainerFrame4
backpack.bagID=0;small.bagID=1
backpack.shown=true;small.shown=false
for _,f in ipairs({backpack,small})do
 f.GetRight=function()return 700 end;f.GetLeft=function()return 500 end
 f.GetBottom=function()return 120 end;f.GetTop=function()return 420 end
 f.GetEffectiveScale=function(self)return self.scale end
end
UIParent.GetEffectiveScale=function()return 1 end
ns.db.windows.enabled=true;ns.db.windows.moveBags=true;ns.db.windows.savePositions=true
ns.db.windows.bagAnchor=nil
ns.db.windows.bagAnchorCorner=nil
ns.db.windows.points.ContainerFrame1={point='CENTER',relativeTo='UIParent',relativePoint='CENTER',x=0,y=0}
function UpdateContainerFrameAnchors()
 if backpack.shown then
  backpack:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-10,20)
  if small.shown then small:SetPoint('BOTTOMRIGHT',backpack,'TOPRIGHT',0,6)end
 elseif small.shown then small:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-10,20)end
end
ns:RefreshBagMovement() -- Existing backpack position becomes an absolute corner anchor.
assert(ns.db.windows.bagAnchor.point=='BOTTOMRIGHT' and ns.db.windows.bagAnchor.x==700)
ns:RefreshBagMovement()
assert(select(4,backpack:GetPoint())==700 and select(5,backpack:GetPoint())==120)
small:Show();small.scripts.OnShow(small)
assert(select(2,small:GetPoint())==backpack and select(3,small:GetPoint())=='TOPRIGHT')
backpack:Hide();backpack.scripts.OnHide(backpack)
assert(select(2,small:GetPoint())==UIParent and select(4,small:GetPoint())==700 and select(5,small:GetPoint())==120)
backpack:Show();backpack.scripts.OnShow(backpack)
assert(select(2,small:GetPoint())==backpack)
for _,corner in ipairs({'TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'})do
 ns:SetBagAnchorCorner(corner)
 assert(ns.db.windows.bagAnchor.point==corner and ns:GetBagAnchorCorner()==corner)
 assert(select(1,backpack:GetPoint())==corner)
 assert(ns.db.windows.bagAnchor.x==(corner:find('RIGHT') and 700 or 500))
end
backpack:Hide();backpack.scripts.OnHide(backpack)
small.scale=0.8;ns:RefreshBagMovement()
assert(select(4,small:GetPoint())==875 and select(5,small:GetPoint())==150)
-- A reused container frame with a bank ID never borrows the carried-bag anchor.
small.bagID=8
ns.db.windows.points.ContainerFrame4={point='CENTER',relativeTo='UIParent',relativePoint='CENTER',x=91,y=82}
small:SetPoint('CENTER',UIParent,'CENTER',0,0)
assert(select(4,small:GetPoint())==91)
small.bagID=1
combat=true;small.protected=true
local before=small:GetPoint()
ns:SetBagAnchorCorner('TOPLEFT')
assert(ns:GetBagAnchorCorner()=='BOTTOMRIGHT')
small.scripts.OnShow(small)
assert(small:GetPoint()==before)
combat=false;small.protected=false
small:Hide();small.scripts.OnHide(small)
ns:SetBagAnchorCorner('TOPLEFT') -- No visible bag: preserve the existing corner and position.
assert(ns:GetBagAnchorCorner()=='BOTTOMRIGHT')
ns:ResetMovableWindowPositions()
assert(ns.db.windows.bagAnchor==nil)
-- Explicit backups capture the base bag; reload/logout also finishes active drags.
backpack.shown=true;small.shown=false
backpack.GetRight=function()return 640 end
local captures=0
ZoidsTools_FRecoveryService={Capture=function()captures=captures+1 end}
local revision=ns.db.windows.layoutRevision
ns:CaptureCurrentWindowLayout()
assert(ns.db.windows.bagAnchor.x==640 and ns.db.windows.layoutRevision>revision and captures>0)
local savedX=ns.db.windows.bagAnchor.x
backpack.GetRight=function()return 720 end
ns:CaptureCurrentWindowLayout(true)
assert(ns.db.windows.bagAnchor.x==savedX, 'Ordinary logout must not save a transient layout')
backpack.ZTMoving=true;backpack:StartMoving()
ns:CaptureCurrentWindowLayout(true)
assert(not backpack.ZTMoving and not backpack.moving and ns.db.windows.bagAnchor.x==720)
backpack.shown=false
ns:CaptureCurrentWindowLayout()
assert(ns.db.windows.bagAnchor.x==720, 'Hidden bags keep their anchor')
revision=ns.db.windows.layoutRevision
ns:ResetMovableWindowPositions()
assert(ns.db.windows.bagAnchor==nil and ns.db.windows.layoutRevision>revision)
