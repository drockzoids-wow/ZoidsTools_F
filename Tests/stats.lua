secret = {}
function issecretvalue(v) return v == secret end
local combat = false
function InCombatLockdown() return combat end
local fps, home, world, speed = 59.6, 25, 43, 7
function GetFramerate() return fps end
function GetNetStats() return 0, 0, home, world end
function GetUnitSpeed(unit) assert(unit == 'player'); return speed end
UIParent = {}
local function Region()
    local r = {}
    function r:SetPoint() end
    function r:SetText(v) self.text = v end
    function r:SetTextColor() end
    return r
end
function CreateFrame(_, name, parent)
    local f = { scripts = {}, children = {}, shown = true }
    if parent and parent.children then table.insert(parent.children, f) end
    if name then _G[name] = f end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetFrameStrata() end
    function f:SetClampedToScreen(v) self.clamped = v end
    function f:SetMovable(v) self.movable = v end
    function f:EnableMouse(v) self.mouse = v end
    function f:SetMouseMotionEnabled(v) self.motion = v end
    function f:SetMouseClickEnabled(v) self.click = v end
    function f:RegisterForDrag() end
    function f:RegisterEvent() end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:CreateFontString() return Region() end
    function f:ClearAllPoints() end
    function f:SetPoint(...) self.point = { ... } end
    function f:GetPoint() return unpack(self.point) end
    function f:SetShown(v)
        local wasShown = self.shown
        self.shown = v
        if wasShown and not v and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:StartMoving() assert(self.movable); self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
    return f
end
GameTooltip = { lines = {} }
function GameTooltip:IsOwned(owner) return self.owner == owner end
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:SetText(text) self.title = text; self.lines = {} end
function GameTooltip:AddLine(text) table.insert(self.lines, text) end
function GameTooltip:AddDoubleLine(a, b) table.insert(self.lines, a .. ': ' .. b) end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false; self.owner = nil end

function RunStatsTests(ns)
    ns:InitializeStatsWindow()
    local f = ZoidsTools_FStats
    ns:InitializeStatsWindow()
    assert(f == ZoidsTools_FStats and #f.children == 3)
    assert(f.clamped and f.shown)
    local a, b, c = unpack(f.children)
    assert(a.value.text == '60' and b.value.text == '43' and c.value.text == '100')
    speed = 0
    f.scripts.OnUpdate(f, 0.2)
    assert(c.value.text == '0')
    speed = 14
    f.scripts.OnUpdate(f, 0.2)
    assert(c.value.text == '200')
    a.scripts.OnDragStart(a)
    assert(f.moving)
    f:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 123, -456)
    a.scripts.OnDragStop(a)
    assert(not f.moving and ns.db.stats.x == 123 and ns.db.stats.y == -456)
    ns:SetStatsWindowOption('locked', true)
    assert(not f.movable and not f.click and f.motion)
    for _, row in ipairs(f.children) do
        assert(row.motion and not row.click)
        row.scripts.OnEnter(row)
        assert(GameTooltip.shown and GameTooltip.owner == row)
        row.scripts.OnDragStart(row)
        assert(not f.moving)
        row.scripts.OnLeave(row)
        assert(not GameTooltip.shown)
    end
    b.scripts.OnEnter(b)
    assert(GameTooltip.lines[1] == 'Home: 25 ms' and GameTooltip.lines[2] == 'World: 43 ms')
    world = 88
    f.scripts.OnUpdate(f, 0.2)
    assert(GameTooltip.lines[2] == 'World: 88 ms')
    GameTooltip:SetOwner({})
    b.scripts.OnLeave(b)
    assert(GameTooltip.shown, 'Must not hide another frame tooltip')
    ns:SetStatsWindowOption('locked', false)
    combat = true
    f.scripts.OnDragStart(f)
    assert(not f.moving)
    combat = false
    f.scripts.OnDragStart(f)
    assert(f.moving)
    f.scripts.OnEvent(f, 'PLAYER_REGEN_DISABLED')
    assert(not f.moving)
    b.scripts.OnEnter(b)
    ns:SetStatsWindowOption('enabled', false)
    assert(not f.shown and not GameTooltip.shown)
    ns:SetStatsWindowOption('enabled', true)
    ns:ResetStatsWindowPosition()
    assert(ns.db.stats.x == 0 and ns.db.stats.y == -180 and f.point[1] == 'CENTER')
    -- Older clients still retain hover tooltips, even without click-through support.
    f.SetMouseMotionEnabled, f.SetMouseClickEnabled = nil, nil
    a.SetMouseMotionEnabled, a.SetMouseClickEnabled = nil, nil
    ns:SetStatsWindowOption('locked', true)
    assert(f.mouse and a.mouse and not f.movable)
    a.scripts.OnEnter(a)
    assert(GameTooltip.shown)
    fps, home, world, speed = secret, secret, secret, secret
    f.scripts.OnUpdate(f, 0.2)
    assert(a.value.text == '--' and b.value.text == '--' and c.value.text == '--')
    GetFramerate = function() error('unavailable') end
    GetNetStats, GetUnitSpeed = nil, nil
    f.scripts.OnUpdate(f, 0.2)
    assert(a.value.text == '--' and b.value.text == '--' and c.value.text == '--')
end
