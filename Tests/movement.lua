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
combat = true
watcher.scripts.OnEvent(watcher, 'PLAYER_REGEN_DISABLED')
assert(not watcher.events.BAG_CLOSED)
panel.scripts.OnDragStart(panel)
assert(not CharacterFrame.moving)
assert(ns:ResetMovableWindowPositions() == false)
assert(ns:ResetMovableWindowScales() == false)
panel.scripts.OnMouseUp(panel, 'RightButton')
assert(ns.db.windows.points.CharacterFrame and ns.db.windows.scales.CharacterFrame)
combat = false
watcher.scripts.OnEvent(watcher, 'PLAYER_REGEN_ENABLED')
assert(watcher.events.BAG_CLOSED)
ns:ResetMovableWindowScales()
assert(CharacterFrame.scale == 1 and next(ns.db.windows.scales) == nil)
ns:ResetMovableWindowPositions()
assert(next(ns.db.windows.points) == nil)
-- Late-loaded windows receive handles without requiring a reload.
AuctionFrame = CreateFrame('Frame', 'AuctionFrame')
AuctionFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
watcher.scripts.OnEvent(watcher, 'ADDON_LOADED')
assert(AuctionFrameZoidsTools_FWindowDragHandle)
