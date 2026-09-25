"""Check the merged inventory and source accounting in Lua 5.1."""
import argparse
import json
from pathlib import Path
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--runtime')
args = parser.parse_args()
if args.runtime:
    sys.path.insert(0, args.runtime)
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'Completionist/Sources.json').read_text())
lua = LuaRuntime(unpack_returned_tuples=True)
ns = lua.table()
addon = lua.table(Completionist=ns)
lua.execute((root / 'Completionist/Data.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', addon)
records = {}
for _, quest in ns.quests.items():
    assert quest.id not in records, f'Duplicate quest {quest.id}'
    assert quest.id > 0 and quest.name and quest.area and quest.type
    assert quest.side in {'Alliance', 'Horde', 'Both', 'Unassigned', 'Unknown'}
    assert isinstance(quest.level, (int, float)) and quest.min >= 0 and quest.classMask >= 0
    records[quest.id] = quest
assert len(records) == manifest['totalBundled'] == 6090
for key in ('wowheadAddedIds', 'updatedIds', 'retainedIds', 'secondaryAddedIds'):
    assert set(manifest[key]) <= records.keys(), key
assert not set(manifest['secondaryExcludedIds']) & records.keys()
assert all(records[id].sourceStatus == 'retained' for id in manifest['retainedIds'])
assert all(records[id].sourceStatus == 'secondary' for id in manifest['secondaryAddedIds'])
assert records[2358].classMask == 8 and records[2358].min == 16
assert records[93836].area == 'Zephras Isle' and records[93836].side == 'Horde'
assert records[92460].observed and records[92460].observation.pickup.name == 'Ailee Farheart'
captured = {94472, 94375, 97277, 94373, 94374, 97894, 86758,
            92682, 92683, 94484, 94006, 93317, 92840, 94896, 94897, 92741, 92684}
assert captured <= records.keys()
assert records[94006].area == 'Druid'
assert len(manifest['wowheadAddedIds']) == 748 and len(manifest['secondaryAddedIds']) == 10
assert manifest['collectedUnique'] - manifest['reportedTotal'] == manifest['countDiscrepancy'] == 3
print('PASS: 6,090 unique quests, source accounting, all 17 discoveries, exclusions, restrictions and observation preservation')
