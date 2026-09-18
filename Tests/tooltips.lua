secret = {}
function issecretvalue(value) return value == secret end
function UnitIsPlayer(unit) return unit == "player" end
function UnitClass() return "Mage", "MAGE" end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
function CreateColor(r, g, b) return { r = r, g = g, b = b } end
Enum = { TooltipDataLineType = { UnitName = 1 } }
GameTooltip = { scripts = {} }
function GameTooltip:HasScript() return true end
function GameTooltip:HookScript(script, fn) self.scripts[script] = fn end
function GameTooltip:GetUnit() return "Name", self.unit end
GameTooltipTextLeft1 = { color = { 1, 0.8, 0, 1 } }
function GameTooltipTextLeft1:GetTextColor() return unpack(self.color) end
function GameTooltipTextLeft1:SetTextColor(...) self.color = { ... } end
local callback
local calls = 0
TooltipDataProcessor = { AddLinePreCall = function(_, fn) callback = fn; calls = calls + 1 end }

function RunTooltipTests(ns, legacy)
    ns:InitializePlayerTooltip()
    ns:InitializePlayerTooltip()
    if legacy then
        local scripts = GameTooltip.scripts
        GameTooltip.unit = "player"
        scripts.OnTooltipSetUnit(GameTooltip)
        assert(GameTooltipTextLeft1.color[1] == 0.25)
        scripts.OnTooltipCleared()
        assert(GameTooltipTextLeft1.color[1] == 1)
        GameTooltip.unit = "npc"
        scripts.OnTooltipSetUnit(GameTooltip)
        assert(GameTooltipTextLeft1.color[1] == 1)
        GameTooltip.unit = secret
        scripts.OnTooltipSetUnit(GameTooltip)
        ns:SetTooltipClassColoredNamesEnabled(false)
        GameTooltip.unit = "player"
        scripts.OnTooltipSetUnit(GameTooltip)
        assert(GameTooltipTextLeft1.color[1] == 1)
        ns:SetTooltipClassColoredNamesEnabled(true)
        scripts.OnTooltipSetUnit(GameTooltip)
        scripts.OnHide()
        assert(GameTooltipTextLeft1.color[1] == 1)
        return
    end
    assert(calls == 1 and next(GameTooltip.scripts) == nil)
    local line = { unitToken = "player", leftText = secret }
    callback(GameTooltip, line)
    assert(line.leftColor.r == 0.25 and line.leftText == secret)
    CUSTOM_CLASS_COLORS = { MAGE = { r = 0.1, g = 0.2, b = 0.3 } }
    callback(GameTooltip, line)
    assert(line.leftColor.r == 0.1)
    for _, unit in ipairs({ "npc", secret }) do
        local untouched = { unitToken = unit }
        callback(GameTooltip, untouched)
        assert(untouched.leftColor == nil)
    end
    callback(GameTooltip, secret)
    local other = { unitToken = "player" }
    callback({}, other)
    assert(other.leftColor == nil)
    ns:SetTooltipClassColoredNamesEnabled(false)
    callback(GameTooltip, other)
    assert(other.leftColor == nil)
    ns:SetTooltipClassColoredNamesEnabled(true)
    UnitClass = function() return "Mage", secret end
    callback(GameTooltip, other)
    assert(other.leftColor == nil)
    UnitClass = function() error("unavailable") end
    callback(GameTooltip, other)
    assert(other.leftColor == nil)
end
