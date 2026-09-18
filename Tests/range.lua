secret = {}
function issecretvalue(value) return value == secret end
local combat = false
function InCombatLockdown() return combat end
local frames = {}
function CreateFrame()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    frames[#frames + 1] = frame
    return frame
end
local function Button(action)
    local button = { action = action, icon = {}, shown = true }
    function button:IsShown() return self.shown end
    function button:CreateTexture()
        assert(not combat, "Region created during combat")
        assert(not self.overlay, "Duplicate overlay")
        local overlay = {}
        function overlay:SetAllPoints(icon) self.anchor = icon end
        function overlay:SetColorTexture(...) self.color = { ... } end
        function overlay:SetBlendMode() end
        function overlay:Hide() self.shown = false end
        function overlay:SetShown(value) self.shown = value end
        self.overlay = overlay
        return overlay
    end
    return button
end
ActionButton1 = Button(1)
MultiBar7Button12 = Button(2)
OverrideActionBarButton1 = Button(3)
local ranges = { false, true, 0 }
local present, required = true, true
C_ActionBar = {
    HasAction = function() return present end,
    HasRangeRequirements = function() return required end,
    IsActionInRange = function(action) return ranges[action] end,
}
function RunRangeTests(ns)
    ns:InitializeActionButtonRange()
    ns:InitializeActionButtonRange()
    assert(#frames == 1)
    local b = ActionButton1
    assert(b.overlay.shown and b.overlay.anchor == b.icon)
    assert(b.overlay.color[1] == 1 and b.overlay.color[4] == 0.42)
    assert(not MultiBar7Button12.overlay.shown and OverrideActionBarButton1.overlay.shown)
    ranges[1] = true
    frames[1].scripts.OnUpdate(nil, 0.1)
    assert(b.overlay.shown)
    frames[1].scripts.OnUpdate(nil, 0.06)
    assert(not b.overlay.shown)
    for _, value in ipairs({ false, 0, true, 1, secret }) do
        ranges[1] = value
        ns:RefreshActionButtonRangeTint()
        assert(b.overlay.shown == (value == false or value == 0))
    end
    ranges[1] = nil
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)
    ranges[1] = false
    for _, value in ipairs({ false, secret }) do
        present = value
        ns:RefreshActionButtonRangeTint()
        assert(not b.overlay.shown)
    end
    present = true
    required = false
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)
    required = true
    b.action = secret
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)
    b.action = 2
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)
    b.action = 1
    combat = true
    ActionButton2 = Button(1)
    ns:RefreshActionButtonRangeTint()
    assert(b.overlay.shown and ActionButton2.overlay == nil)
    ns:SetActionButtonRangeTintEnabled(false)
    assert(not b.overlay.shown)
    ns:SetActionButtonRangeTintEnabled(true)
    assert(b.overlay.shown)
    combat = false
    frames[1].scripts.OnEvent(nil, 'PLAYER_REGEN_ENABLED')
    assert(ActionButton2.overlay.shown)
    b.shown = false
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)
    b.shown = true
    HasAction = C_ActionBar.HasAction
    ActionHasRange = C_ActionBar.HasRangeRequirements
    IsActionInRange = C_ActionBar.IsActionInRange
    C_ActionBar = nil
    ns:RefreshActionButtonRangeTint()
    assert(b.overlay.shown)
    IsActionInRange = function() error('unavailable') end
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)
    IsActionInRange = nil
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown)

    -- Late-loaded native updater: hook once and react without advancing any timer.
    local hookCount = 0
    function ActionButton_UpdateRangeIndicator(button, checksRange, inRange)
        button.keybindRed = checksRange == true and inRange == false
    end
    function hooksecurefunc(name, callback)
        hookCount = hookCount + 1
        local original = _G[name]
        _G[name] = function(...)
            original(...)
            callback(...)
        end
    end
    IsActionInRange = function() return true end -- Deliberately stale polling result.
    ns:RefreshActionButtonRangeTint()
    ns:RefreshActionButtonRangeTint()
    assert(hookCount == 1)
    combat = true
    ActionButton_UpdateRangeIndicator(b, true, false)
    assert(b.keybindRed and b.overlay.shown)
    frames[1].scripts.OnUpdate(nil, 0.16)
    assert(b.overlay.shown, "Polling must not overwrite the native range result")
    ActionButton_UpdateRangeIndicator(b, true, true)
    assert(not b.keybindRed and not b.overlay.shown)
    ActionButton_UpdateRangeIndicator(b, true, false)
    ns:SetActionButtonRangeTintEnabled(false)
    ActionButton_UpdateRangeIndicator(b, true, false)
    assert(not b.overlay.shown)
    ns:SetActionButtonRangeTintEnabled(true)
    assert(b.overlay.shown)
    ActionButton_UpdateRangeIndicator(b, false, false)
    assert(not b.overlay.shown)
    ActionButton_UpdateRangeIndicator(b, secret, false)
    assert(not b.overlay.shown)
    ActionButton_UpdateRangeIndicator(b, true, secret)
    assert(not b.overlay.shown)
    ActionButton_UpdateRangeIndicator(b, true, false)
    b.action = 2
    ns:RefreshActionButtonRangeTint()
    assert(not b.overlay.shown, "Paged buttons must not reuse an old action's result")
    b.action = 1
    ActionButton_UpdateRangeIndicator(b, true, false)
    frames[1].scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
    assert(not b.overlay.shown, "Target changes must discard cached range")
    ActionButton_UpdateRangeIndicator(b, true, false)
    b.action = secret
    ActionButton_UpdateRangeIndicator(b, true, false)
    assert(not b.overlay.shown)
    ActionButton_UpdateRangeIndicator(Button(1), true, false) -- Untracked buttons ignored.
    combat = false
end
