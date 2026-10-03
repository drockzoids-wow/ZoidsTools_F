"""Independent binary fixtures and checked-in evidence integrity checks."""
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Tools'))
from read_client_quests import read_db2, read_cache, audit_hotfix, project_point, write_lua


class ClientDataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def file(self, name, data):
        p = self.root / name
        p.write_bytes(data)
        return p

    def test_cache_boundaries(self):
        head = struct.pack('<4s5I', b'TSQW', 70009, 0, 0, 0, 0)
        record = struct.pack('<III', 92742, 4, 92742)
        valid = head + record + bytes(8)
        self.assertEqual(read_cache(self.file('cache', valid))['records'][0]['id'], 92742)
        for bad in (valid[:-1], head + record, valid + b'x', head + record*2 + bytes(8), head + struct.pack('<III', 1, 4, 2) + bytes(8)):
            with self.assertRaises(ValueError):
                read_cache(self.file('cache', bad))

    def test_hotfix_identification(self):
        head = struct.pack('<4sII', b'XFTH', 9, 70009) + bytes(32)
        row = struct.pack('<4siiiIiiB3x', b'XFTH', 1, 2, 3, 0x1234, 55, 3, 1) + b'abc'
        result = audit_hotfix(self.file('hotfix', head + row), {0x1234:'QuestV2'})
        self.assertEqual(result['records'], 1)
        self.assertEqual(result['relevantRecords'][0]['id'], 55)
        for bad in (head[:12], head + row[:-1], head + row[:12]):
            with self.assertRaises(ValueError):
                audit_hotfix(self.file('hotfix', bad), {})

    def test_db2_packed_signed_common_and_truncation(self):
        # One packed ID, a signed field, and a common field with an ID override.
        data = bytearray(204)
        data[:4] = b'WDC5'
        struct.pack_into('<9I2H7I', data, 136,
                         1, 3, 8, 0, 0, 0x1854BDB9, 7, 7, 0, 0, 0,
                         3, 0, 0, 72, 8, 0, 1)
        offset = 204 + 40 + 12 + 72 + 8
        data += struct.pack('<Q8I', 0, offset, 1, 0, offset+8, 0, 0, 0, 0)
        data += struct.pack('<hH', 0, 0)*3
        data += struct.pack('<HH5I', 0, 8, 0, 1, 0, 0, 0)
        data += struct.pack('<HH5I', 8, 8, 0, 5, 0, 0, 0)
        data += struct.pack('<HH5I', 0, 0, 8, 2, 9, 0, 0)
        data += struct.pack('<II', 7, 42)
        data += struct.pack('<Q', 7 | (255 << 8))
        path = self.file('QuestV2.db2', data)
        row = read_db2(path)['rows'][0]
        self.assertEqual(row, dict(ID=7, UniqueBitFlag=-1, UiQuestDetailsThemeID=42))
        with self.assertRaises(ValueError):
            read_db2(self.file('QuestV2.db2', data[:-1]))
        data[156:160] = bytes(4)  # Unknown layout hash.
        with self.assertRaises(ValueError):
            read_db2(self.file('QuestV2.db2', data))

    def test_coordinate_axes_and_ambiguity(self):
        a = dict(ID=1, UiMapID=2, MapID=0, WMODoodadPlacementID=0, WMOGroupID=0,
                 Region=[0, 0, -10, 100, 200, 10], UiMin=[0, 0], UiMax=[1, 1])
        blob = dict(UiMapID=2, MapID=0)
        point = dict(ID=1, X=25, Y=150, Z=0)
        self.assertEqual(project_point(point, blob, [a]), dict(mapID=2, x=.25, y=.75, assignmentID=1))
        for assignments in ([], [a, a]):
            with self.assertRaises(ValueError):
                project_point(point, blob, assignments)

    def test_report_and_generated_evidence(self):
        r = json.loads((ROOT/'Tools/reports/client-quests-70009.json').read_text(encoding='utf8'))
        self.assertEqual(r['bundledCount'], 6090)
        self.assertEqual(len(r['clientIdsAbsentFromAddon']), 1423)
        self.assertEqual(len(r['cache']['records']), 195)
        self.assertEqual(r['cachedIdsAbsentFromAddon'], [])
        self.assertEqual(r['hotfix']['relevantRecords'], [])
        self.assertEqual(sum(len(s['ids']) for s in r['tables']['QuestV2']['encryptedSections']), 89)
        self.assertEqual(len(r['evidence']), 22)
        self.assertEqual(sum(len(q['completionMarkers']) for q in r['evidence'].values()), 23)
        self.assertEqual(sum(len(m['points']) for m in r['markers']), 99)
        self.assertTrue(all(0 <= p['x'] <= 1 and 0 <= p['y'] <= 1 for m in r['markers'] for p in m['points']))
        output = self.root/'generated.lua'
        write_lua(output, {int(k):v for k,v in r['evidence'].items()})
        self.assertEqual(output.read_bytes(), (ROOT/'Completionist/ClientData.lua').read_bytes())


if __name__ == '__main__':
    unittest.main()
