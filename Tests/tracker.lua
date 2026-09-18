secret = {}
function issecretvalue(v) return v == secret end
local frames = {}
function CreateFrame()
    local f = { scripts = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    frames[#frames + 1] = f
    return f
end
local function Region(alpha)
    return { alpha = alpha, writes = 0,
        GetAlpha = function(self) return self.alpha end,
        SetAlpha = function(self, value) self.alpha = value; self.writes = self.writes + 1 end }
end
function RunTrackerMinimizeTests(ns)
    ns:InitializeTrackerMinimize()
    ns:InitializeTrackerMinimize()
    assert(#frames == 1)
    local tick = frames[1].scripts.OnUpdate
    tick() -- Tracker not yet loaded.
    local text, background, backdrop = Region(0.9), Region(0.8), Region(0.65)
    local button = Region(1)
    local tracker = { Header = { Text = text, Background = background, MinimizeButton = button }, NineSlice = backdrop }
    function tracker:IsCollapsed() return self.collapsed end
    function tracker:SetSize() error('Must not change tracker layout') end
    function tracker:SetPoint() error('Must not move tracker') end
    function tracker:Update() error('Must not invoke protected layout') end
    ObjectiveTrackerFrame = tracker
    tracker.collapsed = false
    tick()
    assert(text.writes == 0 and backdrop.writes == 0)
    tracker.collapsed = true
    tick()
    assert(text.alpha == 0 and background.alpha == 0 and backdrop.alpha == 0)
    assert(button.alpha == 1 and button.writes == 0)
    tick()
    assert(text.writes == 1 and backdrop.writes == 1)
    tracker.collapsed = false
    tick()
    assert(text.alpha == 0.9 and background.alpha == 0.8 and backdrop.alpha == 0.65)
    tracker.collapsed = true
    tick()
    backdrop.alpha = 0.35 -- A native background-opacity update while collapsed.
    tick()
    assert(backdrop.alpha == 0)
    ns:SetTrackerMinimizeToButton(false)
    assert(text.alpha == 0.9 and backdrop.alpha == 0.35)
    ns:SetTrackerMinimizeToButton(true)
    assert(text.alpha == 0)
    EditModeManagerFrame = { IsEditModeActive = function() return true end }
    tick()
    assert(text.alpha == 0.9 and backdrop.alpha == 0.35)
    EditModeManagerFrame = nil
    tick()
    assert(text.alpha == 0)
    tracker.collapsed = secret
    tick()
    assert(text.alpha == 0.9)
    tracker.IsCollapsed = function() error('unavailable') end
    tick()
    assert(text.alpha == 0.9)
    tracker.IsCollapsed = function() return true end
    background.alpha = 0 -- Preserve a naturally transparent region on expansion.
    tick()
    ns:SetTrackerMinimizeToButton(false)
    assert(background.alpha == 0)
    ns:SetTrackerMinimizeToButton(true)
    ObjectiveTrackerFrame = nil
    tick()
    assert(text.alpha == 0.9 and backdrop.alpha == 0.35)
end
