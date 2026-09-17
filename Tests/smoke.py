"""Run with Python + lupa (Lua 5.1); pass --runtime for a local lupa directory."""
from pathlib import Path
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--runtime')
args = parser.parse_args()
if args.runtime:
    sys.path.insert(0, args.runtime)
from lupa.lua51 import LuaRuntime

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
