"""Lua 5.1 retained-memory checks; optional comparison with a local Git ref.

These isolate Lua data and caches, not WoW's UI objects or live SavedVariables.
"""
import argparse
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runtime')
parser.add_argument('--compare-ref')
args = parser.parse_args()
if args.runtime:
    sys.path.insert(0, args.runtime)
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]


def source(path, ref=None):
    if ref:
        return subprocess.check_output(['git', 'show', f'{ref}:{path}'], cwd=root).decode('utf-8-sig')
    return (root / path).read_text(encoding='utf-8-sig')


def memory(lua):
    lua.gccollect()
    return lua.eval('collectgarbage("count")')


def quests(ref=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{Completionist={}}')
    before = memory(lua)
    lua.execute(source('Completionist/Data.lua', ref), 'ZoidsTools_F', ns)
    used = memory(lua) - before
    rows = ns.Completionist.quests
    fields = ('id', 'name', 'level', 'min', 'side', 'area', 'type', 'classMask', 'observed', 'observation')
    def plain(value):
        return {k: plain(v) for k, v in value.items()} if hasattr(value, 'items') else value
    values = [tuple(plain(rows[i][key]) for key in fields) for i in range(1, len(rows) + 1)]
    assert len(values) > 5300
    assert len({row[0] for row in values}) == len(values)
    assert all(isinstance(row[0], (int, float)) and isinstance(row[1], str) for row in values)
    return used, values


def filtering(ref=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval('{Completionist={char={factionFilter="Mine"},playerFaction="Alliance",playerClass="WARRIOR"}}')
    lua.execute('''
        function CreateFrame() return {RegisterEvent=function()end,SetScript=function()end} end
        SlashCmdList={}
    ''')
    for path in ('Completionist/Data.lua', 'Completionist/Core.lua'):
        lua.execute(source(path, ref), 'ZoidsTools_F', ns)
    lua.globals().ns = ns.Completionist
    run = lua.eval('''function()
        local count=0
        for _,q in ipairs(ns.quests) do if ns.Eligible(q) then count=count+1 end end
        return count
    end''')
    memory(lua)
    lua.execute('collectgarbage("stop")')
    before = lua.eval('collectgarbage("count")')
    count = run()
    allocated = lua.eval('collectgarbage("count")') - before
    lua.execute('collectgarbage("restart")')
    return allocated, count


def inventory(ref=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.table()
    lua.globals().ns = ns
    lua.execute(source('Modules/ItemInventory.lua', ref), 'ZoidsTools_F', ns)
    lua.execute('''
        ZoidsTools_FInventoryDB = {characters={}, account={}}
        for c=1,12 do
            local items={}
            for i=1,200 do items[c*1000+i]={count=i, name="Item "..i} end
            ZoidsTools_FInventoryDB.characters[tostring(c)]={
                name="Character"..c, realm="Realm", class="MAGE",
                containers={bag0={label="Bags",items=items}},
            }
        end
    ''')
    before = memory(lua)
    lua.execute('''
        local locations,total=ns:GetWarbandItemLocations(1001)
        assert(total==1 and #locations==1)
    ''')
    first = memory(lua) - before
    lua.execute('''
        for c=1,12 do
            for i=1,200 do
                local locations,total=ns:GetWarbandItemLocations(c*1000+i)
                assert(total==i and #locations==1)
            end
        end
        local locations,total=ns:GetWarbandItemLocations(999999)
        assert(total==0 and #locations==0)
        locations,total=ns:GetWarbandItemLocations(1001)
        assert(total==1 and #locations==1)
    ''')
    return first, memory(lua) - before


def diagnostic():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        function CreateFrame() return {RegisterEvent=function()end,SetScript=function()end} end
        SlashCmdList={}; messages={}
        DEFAULT_CHAT_FRAME={AddMessage=function(_,message) messages[#messages+1]=message end}
    ''')
    lua.execute(source('Core.lua'), 'ZoidsTools_F', lua.table())
    lua.execute('''
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory")
        assert(messages[#messages]:find("unavailable"))
        local calls=0
        local collections=0
        collectgarbage=function(mode) assert(mode=="collect");collections=collections+1;return 0 end
        function UpdateAddOnMemoryUsage() calls=calls+1 end
        function GetAddOnMemoryUsage(name) assert(name=="ZoidsTools_F");return 2048 end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory")
        assert(calls==1 and messages[#messages]:find("2.00 MiB",1,true))
        assert(collections==0, "Ordinary memory readings must not collect")
        GetAddOnMemoryUsage=function() return collections==0 and 4096 or 2048 end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory collect")
        assert(collections==1)
        assert(messages[#messages-1]:find("before 4.00 MiB; after cleanup request 2.00 MiB; change -2.00 MiB",1,true))
        InCombatLockdown=function()return true end
        local oldCalls=calls
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory collect")
        assert(collections==1 and calls==oldCalls and messages[#messages]:find("after leaving combat"))
        InCombatLockdown=nil
        collectgarbage=function()error("blocked")end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory collect")
        assert(messages[#messages]:find("unavailable"))
        collectgarbage=nil
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory collect")
        assert(messages[#messages]:find("unavailable"))
        collectgarbage=function()return false end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory collect")
        assert(messages[#messages]:find("unavailable"))
        GetAddOnMemoryUsage=function() error("not available") end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory")
        assert(messages[#messages]:find("unavailable"))
        GetAddOnMemoryUsage=function() return 0/0 end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory")
        assert(messages[#messages]:find("unavailable"))
        local secret={};function issecretvalue(v) return v==secret end
        GetAddOnMemoryUsage=function() return secret end
        SlashCmdList.ZOIDSTOOLS_FOREVER("memory")
        assert(messages[#messages]:find("unavailable"))
    ''')


diagnostic()
current, values = quests()
first, browsed = inventory()
allocated, eligible = filtering()
print(f'Quest data: {current:.1f} KiB retained ({len(values)} records)')
print(f'Inventory lookup cache: {first:.1f} KiB first hover; {browsed:.1f} KiB after 2,400 distinct items')
print(f'Quest filter temporary allocations: {allocated:.1f} KiB per pass ({eligible} eligible quests)')
assert current < len(values) * .4, 'Quest records no longer use compact storage'
assert max(first, browsed) < 32, 'Inventory lookups retain an unbounded item index'
assert allocated < 16, 'Quest filter allocates tables per quest'
if args.compare_ref:
    old, old_values = quests(args.compare_ref)
    old_first, old_browsed = inventory(args.compare_ref)
    old_allocated, old_eligible = filtering(args.compare_ref)
    assert values == old_values, 'Bundled quest fields changed'
    assert eligible == old_eligible, 'Quest eligibility changed'
    print(f'{args.compare_ref}: quest data {old:.1f} KiB; inventory cache {old_first:.1f}/{old_browsed:.1f} KiB')
    print(f'Quest saving: {old-current:.1f} KiB ({(old-current)/old:.1%}); all quest fields match')
    print(f'Previous quest filter temporary allocations: {old_allocated:.1f} KiB per pass')
print('PASS: retained-memory limits, item totals, cache replacement, and quest records')
