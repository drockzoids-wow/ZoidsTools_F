"""Run with Python + lupa (Lua 5.1); pass --runtime for a local lupa directory."""
from pathlib import Path
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--runtime')
parser.add_argument('--saved-variables', help='Optional read-only check of an existing SavedVariables file')
args = parser.parse_args()
if args.runtime:
    sys.path.insert(0, args.runtime)
from lupa.lua51 import LuaRuntime
from persistence import check_persistence
from builtin_recovery import check_builtin_recovery
from localization import check_localization

check_persistence(LuaRuntime, args.saved_variables)
check_builtin_recovery(LuaRuntime)
check_localization(LuaRuntime)

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(source, name) local f, e = loadstring(source, name); assert(f, e); return f end')
files = [line.strip() for line in (root / 'ZoidsTools_F.toc').read_text().splitlines()
         if line.strip() and not line.startswith('#')]
for file in files:
    path = root / file.replace('\\', '/')
    assert path.is_file(), file
    compile_lua(path.read_text(encoding='utf-8-sig'), file)
print(f'PASS: manifest and Lua 5.1 syntax ({len(files)} files)')

macro_lua = LuaRuntime(unpack_returned_tuples=True)
macro_lua.execute((root / 'Tests/macros.lua').read_text(encoding='utf-8'))
macro_ns = macro_lua.eval('{ db = { macros = { healthEnabled=false, manaEnabled=false, healthCombatItems=true, manaCombatPotion=true } } }')
macro_lua.execute((root / 'Modules/ConsumableMacros.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', macro_ns)
macro_lua.globals().RunMacroTests(macro_ns)
print('PASS: consumable selection, classic Healthstones, combat deferral, item loading, macro ownership/capacity, empty bags and legacy APIs')

lua.execute('''
frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
function GetBuildInfo() return '1.60.1', '69893', '', 160001 end
ZoidsToolsDB = { retailSentinel = true }
ZoidsTools_FDB = { customDamageMeter = { textScale = 1.35 }, ui = { minimap = { show = false } } }
''')
ns = lua.table()
for file in ['Core.lua', 'Compatibility.lua', 'Modules/CustomDamageMeter.lua']:
    compile_lua((root / file).read_text(encoding='utf-8-sig'), file)('ZoidsTools_F', ns)
lua.globals().ns = ns
lua.execute('''
frames[1].handler(frames[1], 'ADDON_LOADED', 'ZoidsTools_F')
assert(ns.db.customDamageMeter.textScale == 1.35)
assert(ns.db.customDamageMeter.secondWindow.damageMeterType == 'HealingDone')
assert(ns.db.ui.minimap.show == false)
assert(ZoidsToolsDB.retailSentinel and ZoidsToolsDB.customDamageMeter == nil)
assert(not ns:HasDamageMeterAPI())
assert(not ns:IsMeterDataAvailable())
assert(ns:SetCustomDamageMeterEnabled(true) == false)
assert(ns.db.customDamageMeter.enabled == false)
assert(ns:GetCompatibilityStatus():find('160001'))
C_DamageMeter = { GetCombatSessionFromType = function() end }
assert(not ns:HasDamageMeterAPI())
Enum = { DamageMeterSessionType = { Current = 0, Overall = 1 }, DamageMeterType = { DamageDone = 0 } }
assert(ns:HasDamageMeterAPI() and ns:IsMeterDataAvailable())
C_DamageMeter.IsDamageMeterAvailable = function() return false end
assert(not ns:IsMeterDataAvailable())
C_DamageMeter.IsDamageMeterAvailable = function() error('not available') end
assert(not ns:IsMeterDataAvailable())
C_DamageMeter.IsDamageMeterAvailable = function() return true end
assert(ns:IsMeterDataAvailable())
local frame = CreateFrame()
C_EventUtils = { IsEventValid = function() return false end }
assert(ns:RegisterMeterEvent(frame, 'UNKNOWN') == false)
assert(next(frame.events) == nil)
C_EventUtils = nil
frame.RegisterEvent = function() error('unknown event') end
assert(ns:RegisterMeterEvent(frame, 'UNKNOWN') == false)
local enabled = '1'
C_CVar = { GetCVar = function() return enabled end, SetCVar = function(_, v) enabled = v end }
assert(ns:GetBlizzardDamageMeterEnabled())
assert(ns:SetBlizzardDamageMeterEnabled(false))
assert(not ns:GetBlizzardDamageMeterEnabled())
C_CVar.SetCVar = function() error('blocked') end
assert(ns:SetBlizzardDamageMeterEnabled(true) == false)
''')
print('PASS: saved settings isolation, defaults, missing/partial APIs, availability, unknown events, CVar failures')
compile_lua((root / 'Modules/MovableWindows.lua').read_text(encoding='utf-8-sig'), 'MovableWindows.lua')('ZoidsTools_F', ns)
lua.execute((root / 'Tests/movement.lua').read_text(encoding='utf-8'))
print('PASS: window/bag drag, persistence, scale limits, toggles, protected exclusions, combat guards, late-loaded windows')
health_lua = LuaRuntime(unpack_returned_tuples=True)
health_lua.execute((root / 'Tests/unitframes.lua').read_text(encoding='utf-8'))
health_ns = health_lua.eval('{ db = { unitFrames = { classColorHealth = false } } }')
for file in ['Compatibility.lua', 'Modules/UnitFrames.lua']:
    health_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', health_ns)
health_lua.globals().RunUnitFrameTests(health_ns)
print('PASS: class health colors, NPC/vehicle transitions, restoration, secret-value guards, and combat deferral')
cast_lua = LuaRuntime(unpack_returned_tuples=True)
cast_lua.execute((root / 'Tests/castbars.lua').read_text(encoding='utf-8'))
cast_ns = cast_lua.eval('''{ db = { castbars = {
    player = { enabled = false, width = 195, height = 16 },
    target = { enabled = false, width = 195, height = 16 },
    focus = { enabled = false, width = 195, height = 16 }
} } }''')
for file in ['Compatibility.lua', 'Modules/Castbars.lua']:
    cast_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', cast_ns)
cast_lua.globals().RunCastbarTests(cast_ns)
print('PASS: castbar sizing, native preview lifecycle, cast/channel handoff, combat, API failures, and Edit Mode ownership')
vendor_lua = LuaRuntime(unpack_returned_tuples=True)
vendor_lua.execute((root / 'Tests/vendor.lua').read_text(encoding='utf-8'))
vendor_ns = vendor_lua.eval('{ db = { vendor = { autoSellJunk = false, autoRepairMode = "disabled" } }, Print = function() end }')
vendor_lua.execute((root / 'Modules/VendorAutomation.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', vendor_ns)
vendor_lua.globals().RunVendorTests(vendor_ns)
print('PASS: popup-free bulk junk sale, repair funding, delayed proceeds, Shift skip, missing API/button, and stale visit cancellation')
for legacy in [False, True]:
    tooltip_lua = LuaRuntime(unpack_returned_tuples=True)
    tooltip_lua.execute((root / 'Tests/tooltips.lua').read_text(encoding='utf-8'))
    if legacy:
        tooltip_lua.execute('TooltipDataProcessor = nil; CreateColor = nil')
    tooltip_ns = tooltip_lua.eval('{ db = { tooltips = { classColoredNames = true } } }')
    tooltip_lua.execute((root / 'Modules/PlayerTooltip.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', tooltip_ns)
    tooltip_lua.globals().RunTooltipTests(tooltip_ns, legacy)
print('PASS: retail/legacy tooltip colors, custom class colors, NPC exclusion, settings, restoration, and restricted data')
for legacy in [False, True]:
    inventory_lua = LuaRuntime(unpack_returned_tuples=True)
    inventory_lua.execute((root / 'Tests/inventory.lua').read_text(encoding='utf-8'))

    def load_inventory():
        ns = inventory_lua.eval('{ db = { tooltips = { itemCounts = true } } }')
        inventory_lua.execute((root / 'Modules/ItemInventory.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', ns)
        return ns

    inventory_lua.globals().RunInventoryTests(load_inventory(), legacy, load_inventory)
print('PASS: cross-character item tooltips, shared and legacy banks, reload persistence, empty/restricted storage, combat, loading screens, logout, and tooltip toggle/deduplication')
loot_lua = LuaRuntime(unpack_returned_tuples=True)
loot_lua.execute((root / 'Tests/fastloot.lua').read_text(encoding='utf-8'))
loot_ns = loot_lua.eval('{ db = { loot = { fastLoot = true, slotDelay = 0 } } }')
for file in ['Compatibility.lua', 'Modules/FastLoot.lua']:
    loot_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', loot_ns)
loot_lua.globals().RunFastLootTests(loot_ns)
print('PASS: single-pass loot, pacing, duplicate events, cancellation, modifiers, locked slots, and restricted data')
quest_lua = LuaRuntime(unpack_returned_tuples=True)
quest_lua.execute((root / 'Tests/quests.lua').read_text(encoding='utf-8'))
quest_ns = quest_lua.eval('{ db = { quests = { autoAccept = false, autoTurnIn = false, pauseModifier = "shift" } } }')
for file in ['Compatibility.lua', 'Modules/QuestAutomation.lua']:
    quest_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', quest_ns)
quest_lua.globals().RunQuestTests(quest_ns)
print('PASS: quest acceptance, completed-quest selection, pause modifiers, reward choices, duplicate claims, and missing APIs')

range_lua = LuaRuntime(unpack_returned_tuples=True)
range_lua.execute((root / 'Tests/range.lua').read_text(encoding='utf-8'))
range_ns = range_lua.eval('{ db = { actionBars = { rangeTint = true } } }')
range_lua.execute((root / 'Modules/ActionButtonRange.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', range_ns)
range_lua.globals().RunRangeTests(range_ns)
print('PASS: action range overlay, polling, paging, toggle, combat setup, legacy APIs, and restricted/missing data')

stats_lua = LuaRuntime(unpack_returned_tuples=True)
stats_lua.execute((root / 'Tests/stats.lua').read_text(encoding='utf-8'))
stats_ns = stats_lua.eval('''{ db = { stats = { enabled = true, locked = false,
    point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 } },
    UI = { Theme = { ApplyPanelBackdrop = function() end, colors = { gold = { 1, 0.8, 0.2 } } } }
}''')
stats_lua.execute((root / 'Modules/StatsWindow.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', stats_ns)
stats_lua.globals().RunStatsTests(stats_ns)
print('PASS: stats display, speed conversion, saved dragging, lock/click-through, hover tooltips, combat, reset, and restricted APIs')

tracker_lua = LuaRuntime(unpack_returned_tuples=True)
tracker_lua.execute((root / 'Tests/tracker.lua').read_text(encoding='utf-8'))
tracker_ns = tracker_lua.eval('{ db = { quests = { minimizeTracker = true } } }')
tracker_lua.execute((root / 'Modules/TrackerMinimize.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', tracker_ns)
tracker_lua.globals().RunTrackerMinimizeTests(tracker_ns)
print('PASS: tracker collapse/expand, native alpha restoration, button preservation, toggle, Edit Mode, and missing/restricted state')

camp_lua = LuaRuntime(unpack_returned_tuples=True)
camp_lua.execute((root / 'Tests/campfire.lua').read_text(encoding='utf-8'))
camp_ns = camp_lua.eval('''{ db = { campfire = { enabled = true, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 260 } },
    UI = { Theme = { ApplyPanelBackdrop = function() end, colors = { gold = { 1, 0.8, 0.2 } } } }
}''')
for file in ['Compatibility.lua', 'Modules/CampfireBar.lua']:
    camp_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', camp_ns)
camp_lua.globals().RunCampfireTests(camp_ns)
print('PASS: campfire aura gating, item discovery, duplicate stacks, secure item bindings, delayed data, cooldowns, dragging, and combat deferral')

rep_lua = LuaRuntime(unpack_returned_tuples=True)
rep_lua.execute((root / 'Tests/reputation.lua').read_text(encoding='utf-8'))
rep_ns = rep_lua.eval('{ db = { reputation = { autoZone = true } } }')
for file in ['Compatibility.lua', 'Modules/ZoneReputation.lua']:
    rep_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', rep_ns)
rep_lua.globals().RunReputationTests(rep_ns)
print('PASS: zone reputation, faction/town selection, duplicate and recursive events, manual overrides, combat deferral, delayed data, disabled mode, instances, restricted names, and legacy fallback')
