local combat = false
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
function InCombatLockdown() return combat end
local classes = { player = 'MAGE', target = 'WARRIOR', targettarget = 'PRIEST', focus = 'ROGUE' }
function UnitExists(unit) return classes[unit] ~= nil end
function UnitIsPlayer(unit) return classes[unit] ~= 'NPC' end
function UnitClass(unit) return 'Class', classes[unit] end
local vehicle = false
function UnitHasVehicleUI() return vehicle end
local eventFrame
function CreateFrame()
    local f = {}
    function f:RegisterEvent() end
    function f:SetScript(_, fn) self.handler = fn end
    eventFrame = f
    return f
end
local function Bar()
    local bar = { color = { 0, 1, 0, 1 }, desaturated = false }
    function bar:GetStatusBarColor() return unpack(self.color) end
    function bar:SetStatusBarColor(...) self.color = {...} end
    function bar:SetStatusBarDesaturated(value) self.desaturated = value end
    function bar:GetStatusBarTexture()
        return { IsDesaturated = function() return self.desaturated end }
    end
    function bar:HookScript() end
    function bar:IsProtected() return self.protected end
    return bar
end
PlayerFrameHealthBar = Bar()
TargetFrameHealthBar = Bar()
TargetFrameToTHealthBar = Bar()
FocusFrame = { HealthBar = Bar() }
function RunUnitFrameTests(ns)
    local function IsColor(bar, r, g, b)
        assert(bar.color[1] == r and bar.color[2] == g and bar.color[3] == b)
    end
    ns:InitializeUnitFrames()
    IsColor(PlayerFrameHealthBar, 0, 1, 0)
    ns:SetUnitFrameClassColorHealth(true)
    IsColor(PlayerFrameHealthBar, 0.25, 0.78, 0.92)
    IsColor(TargetFrameHealthBar, 0.78, 0.61, 0.43)
    IsColor(TargetFrameToTHealthBar, 1, 1, 1)
    IsColor(FocusFrame.HealthBar, 1, 0.96, 0.41)
    assert(PlayerFrameHealthBar.desaturated)
    -- Preserve a newly applied Blizzard NPC color after switching targets.
    classes.target = 'NPC'
    TargetFrameHealthBar:SetStatusBarColor(1, 0, 0, 1)
    eventFrame.handler(eventFrame, 'PLAYER_TARGET_CHANGED')
    IsColor(TargetFrameHealthBar, 1, 0, 0)
    vehicle = true
    eventFrame.handler(eventFrame, 'VEHICLE_UPDATE')
    IsColor(PlayerFrameHealthBar, 0, 1, 0)
    vehicle = false
    eventFrame.handler(eventFrame, 'VEHICLE_UPDATE')
    IsColor(PlayerFrameHealthBar, 0.25, 0.78, 0.92)
    ns:SetUnitFrameClassColorHealth(false)
    IsColor(PlayerFrameHealthBar, 0, 1, 0)
    assert(not PlayerFrameHealthBar.desaturated)
    classes.focus = secret
    ns:SetUnitFrameClassColorHealth(true)
    IsColor(FocusFrame.HealthBar, 0, 1, 0)
    eventFrame.handler(eventFrame, 'UNIT_HEALTH', secret)
    -- Do not overwrite inaccessible health color information.
    ns:SetUnitFrameClassColorHealth(false)
    PlayerFrameHealthBar.color = { secret, secret, secret, 1 }
    ns:SetUnitFrameClassColorHealth(true)
    assert(rawequal(PlayerFrameHealthBar.color[1], secret))
    PlayerFrameHealthBar.color = { 0, 1, 0, 1 }
    PlayerFrameHealthBar.protected = true
    combat = true
    ns:SetUnitFrameClassColorHealth(true)
    IsColor(PlayerFrameHealthBar, 0, 1, 0)
    combat = false
    eventFrame.handler(eventFrame, 'PLAYER_REGEN_ENABLED')
    IsColor(PlayerFrameHealthBar, 0.25, 0.78, 0.92)
    combat = true
    ns:SetUnitFrameClassColorHealth(false)
    IsColor(PlayerFrameHealthBar, 0.25, 0.78, 0.92)
    combat = false
    eventFrame.handler(eventFrame, 'PLAYER_REGEN_ENABLED')
    IsColor(PlayerFrameHealthBar, 0, 1, 0)
end
