"""Read-only audit of locally extracted Forever DB2s and a quest-cache snapshot.

Supports the specific WDC5 layouts recorded below; rejects unknown layouts,
sparse records; lists encrypted IDs without decoding their content.
Outputs JSON for inspection, not automatic quest-availability claims.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

LAYOUTS = {
    'QuestV2': ('1854BDB9', ['ID', 'UniqueBitFlag', 'UiQuestDetailsThemeID']),
    'QuestPOIPoint': ('5CBBEFE7', ['ID', 'X', 'Y', 'Z']),
    'QuestPOIBlob': ('FDC814CF', ['ID', 'MapID', 'UiMapID', 'Flags', 'NumPoints', 'QuestID', 'ObjectiveIndex', 'ObjectiveID', 'PlayerConditionID', 'NavigationPlayerConditionID']),
    'QuestLine': ('27C5AD69', ['Name', 'Description', 'CompletionPlayerConditionID', 'Flags', 'QuestID', 'PlayerConditionID', 'Unknown']),
    'QuestLineXQuest': ('8552F722', ['QuestLineID', 'QuestID', 'OrderIndex', 'Flags', 'Unknown']),
    'UiMapAssignment': ('C9CC8DFB', ['UiMin', 'UiMax', 'Region', 'ID', 'UiMapID', 'OrderIndex', 'MapID', 'AreaID', 'WMODoodadPlacementID', 'WMOGroupID', 'Unknown']),
    'UiMap': ('DB51D55F', ['Name', 'ID', 'ParentUiMapID', 'Flags', 'System', 'Type', 'BountySetID', 'BountyDisplayLocation', 'VisibilityPlayerConditionID', 'HelpTextPosition', 'BkgAtlasID', 'AlternateUiMapGroup', 'ContentTuningID', 'AdventureMapTextureKitID', 'MapArtZoneTextPosition']),
}


def read_db2(path):
    data = path.read_bytes()
    if data[:4] != b'WDC5' or len(data) < 204:
        raise ValueError(f'{path}: expected WDC5')
    h = struct.unpack_from('<9I2H7I', data, 136)
    count, fields, size, strings, table, layout, low, high, locale, flags, id_col, total, packed, lookup, meta_size, common_size, pallet_size, sections = h
    result = dict(file=path.name, sha256=hashlib.sha256(data).hexdigest(), recordCount=count,
                  layout=f'{layout:08X}', rows=[], encryptedSections=[])
    if not count:
        return result
    expected, names = LAYOUTS[path.stem]
    if expected != result['layout'] or flags & 1 or len(names) != fields:
        raise ValueError(f'{path}: unsupported layout/flags')
    headers = [struct.unpack_from('<Q8I', data, 204 + i * 40) for i in range(sections)]
    pos = 204 + sections * 40
    field_meta = [struct.unpack_from('<hH', data, pos + i * 4) for i in range(fields)]
    pos += fields * 4
    columns = [struct.unpack_from('<HH5I', data, pos + i * 24) for i in range(fields)]
    pos += fields * 24
    pallets, commons = {}, {}
    for compression in (3, 4):
        for i, col in enumerate(columns):
            if col[3] == compression:
                pallets[i] = struct.unpack_from('<' + 'I' * (col[2] // 4), data, pos)
                pos += col[2]
    for i, col in enumerate(columns):
        if col[3] == 2:
            commons[i] = dict(struct.unpack_from('<II', data, pos + k) for k in range(0, col[2], 8))
            pos += col[2]
    for key, *_ in headers:
        if key:
            n = struct.unpack_from('<I', data, pos)[0]; pos += 4
            ids = list(struct.unpack_from('<' + 'I' * n, data, pos)); pos += n * 4
            result['encryptedSections'].append(dict(key=f'{key:016X}', ids=ids))
    for key, offset, n, strsize, end, idxsize, relsize, sparse_count, copies in headers:
        if key:
            continue  # Do not decode locked/zero-filled content as real records.
        if sparse_count or copies:
            raise ValueError('Unsupported sparse/copy section')
        if offset < pos or offset + n * size + strsize + idxsize + relsize > len(data):
            raise ValueError('Invalid section bounds')
        if idxsize not in (0, n * 4):
            raise ValueError('Invalid section ID count')
        after = offset + n * size + strsize
        ids = struct.unpack_from('<' + 'I' * (idxsize // 4), data, after)
        after += idxsize
        relations = {}
        if relsize:
            nr, _, _ = struct.unpack_from('<III', data, after)
            relations = {index: value for value, index in
                         (struct.unpack_from('<II', data, after + 12 + i * 8) for i in range(nr))}
        for r in range(n):
            start = offset + r * size
            raw = int.from_bytes(data[start:start + size], 'little')
            row = {'ID': ids[r]} if ids else {}
            for i, (name, col) in enumerate(zip(names, columns)):
                bit, width, additional, kind, arg1, arg2, arg3 = col
                if name in ('UiMin', 'UiMax', 'Region'):
                    if kind != 0 or bit % 8 or width % 32:
                        raise ValueError('Unsupported float array storage')
                    row[name] = list(struct.unpack_from('<' + 'f' * (width // 32), data, start + bit // 8))
                    continue
                if kind == 2:
                    value = commons[i].get(row.get('ID'), arg1)
                else:
                    if kind == 0:
                        width = 32 - field_meta[i][0]
                    value = (raw >> bit) & ((1 << width) - 1)
                    if kind == 5 and value & (1 << (width - 1)):
                        value -= 1 << width
                    elif kind in (3, 4):
                        if kind == 4 and arg3 != 1:
                            raise ValueError('Unsupported array cardinality')
                        value = pallets[i][value]
                    elif kind not in (0, 1, 5):
                        raise ValueError(f'Unsupported compression {kind}')
                if name in ('Name', 'Description'):
                    string_pos = start + bit // 8 + value
                    value = data[string_pos:data.index(b'\0', string_pos)].decode('utf-8') if value else ''
                row[name] = value
            if path.stem == 'QuestPOIPoint':
                row['QuestPOIBlobID'] = relations.get(r, 0)
            result['rows'].append(row)
    if len(result['rows']) + sum(len(s['ids']) for s in result['encryptedSections']) != count:
        raise ValueError('Section accounting mismatch')
    all_ids = [r['ID'] for r in result['rows']] + [qid for s in result['encryptedSections'] for qid in s['ids']]
    if len(set(all_ids)) != count:
        raise ValueError('Duplicate table IDs')
    return result


def read_cache(path):
    data = path.read_bytes()
    if len(data) < 32:
        raise ValueError('Truncated quest cache')
    magic, build, locale, _, _, _ = struct.unpack_from('<4s5I', data)
    if magic != b'TSQW' or build != 70009:
        raise ValueError('Cache layout is only audited for build 70009')
    records, pos, terminated = [], 24, False
    while pos + 8 <= len(data):
        qid, size = struct.unpack_from('<II', data, pos); pos += 8
        if not qid and not size:
            terminated = True
            if pos != len(data):
                raise ValueError('Trailing cache bytes')
            break
        payload = data[pos:pos + size]
        if len(payload) != size or size < 4 or struct.unpack_from('<I', payload)[0] != qid:
            raise ValueError('Invalid cache record boundary or duplicated quest ID')
        records.append(dict(id=qid, offset=pos, size=size))
        pos += size
    if not terminated or pos != len(data) or len({q['id'] for q in records}) != len(records):
        raise ValueError('Incomplete or duplicate cache records')
    return dict(build=build, locale=locale, sha256=hashlib.sha256(data).hexdigest(), records=records)


def audit_hotfix(path, table_hashes):
    data = path.read_bytes()
    if len(data) < 44:
        raise ValueError('Truncated hotfix header')
    if struct.unpack_from('<4sII', data) != (b'XFTH', 9, 70009):
        raise ValueError('Unsupported hotfix-cache version/build')
    pos, count, relevant = 44, 0, []
    while pos < len(data):
        if len(data) - pos < 32:
            raise ValueError('Truncated hotfix record')
        magic, region, push, unique, table, rid, size, op = struct.unpack_from('<4siiiIiiB3x', data, pos)
        pos += 32
        if magic != b'XFTH' or size < 0 or pos + size > len(data):
            raise ValueError('Invalid hotfix record')
        if table in table_hashes:
            relevant.append(dict(table=table_hashes[table], id=rid, operation=op, size=size))
        pos += size; count += 1
    return dict(sha256=hashlib.sha256(data).hexdigest(), records=count, relevantRecords=relevant)


def project_point(point, blob, assignments):
    matches = []
    for a in assignments:
        if a['UiMapID'] != blob['UiMapID'] or a['MapID'] != blob['MapID']:
            continue
        if a['WMODoodadPlacementID'] or a['WMOGroupID']:
            continue
        x0, y0, z0, x1, y1, z1 = a['Region']
        if not (x0 <= point['X'] <= x1 and y0 <= point['Y'] <= y1 and z0 <= point['Z'] <= z1):
            continue
        if x0 == x1 or y0 == y1:
            continue
        u0,v0 = a['UiMin']; u1,v1 = a['UiMax']
        x = u0 + (y1-point['Y'])/(y1-y0)*(u1-u0)
        y = v0 + (x1-point['X'])/(x1-x0)*(v1-v0)
        matches.append(dict(mapID=blob['UiMapID'], x=round(x,7), y=round(y,7), assignmentID=a['ID']))
    if len(matches) != 1:
        raise ValueError(f'Ambiguous/unmapped client point {point["ID"]}: {len(matches)} assignments')
    return matches[0]


def make_evidence(tables):
    evidence = {}
    lines = {r['ID']: r for r in tables['QuestLine']['rows']}
    maps = {r['ID']: r['Name'] for r in tables['UiMap']['rows']}
    for row in tables['QuestLineXQuest']['rows']:
        q = evidence.setdefault(row['QuestID'], dict(storylines=[], completionMarkers=[]))
        q['storylines'].append(dict(id=row['QuestLineID'], name=lines[row['QuestLineID']]['Name'], order=row['OrderIndex']))
    points = {}
    for p in tables['QuestPOIPoint']['rows']:
        points.setdefault(p['QuestPOIBlobID'], []).append(p)
    markers = []
    for blob in tables['QuestPOIBlob']['rows']:
        group = points.get(blob['ID'], [])
        if len(group) != blob['NumPoints']:
            raise ValueError('POI point count mismatch')
        converted = [dict(world=[p['X'],p['Y'],p['Z']], pointID=p['ID'],
                          **project_point(p, blob, tables['UiMapAssignment']['rows'])) for p in group]
        markers.append(dict(**blob, points=converted))
        # -1 is the documented completion POI. Index 32 remains unclassified;
        # it is deliberately not promoted to a pickup/NPC record.
        if blob['ObjectiveIndex'] == -1 and len(group) == 1 and not blob['PlayerConditionID'] and not blob['NavigationPlayerConditionID']:
            q = evidence.setdefault(blob['QuestID'], dict(storylines=[], completionMarkers=[]))
            q['completionMarkers'].append(dict(**converted[0], blobID=blob['ID'], zone=maps[blob['UiMapID']]))
    return evidence, markers


def write_lua(path, evidence):
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    lines = ['-- Generated from local Forever build 1.60.1.70009; see Tools/reports/client-quests-70009.md.',
             '-- Completion markers are client POIs, not verified NPC spawn/pickup locations.',
             'local _,root=...', 'local ns=root.Completionist', 'ns.clientQuestEvidence = {']
    for qid, data in sorted(evidence.items()):
        stories = ','.join('{name=%s,order=%d}' % (quote(s['name']),s['order']) for s in data['storylines'])
        markers = ','.join('{mapID=%d,x=%.7f,y=%.7f,zone=%s}' % (m['mapID'],m['x'],m['y'],quote(m['zone'])) for m in data['completionMarkers'])
        lines.append('[%d]={storylines={%s},completionMarkers={%s}},' % (qid,stories,markers))
    lines.append('}')
    path.write_text('\n'.join(lines)+'\n', encoding='utf8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=Path('build/client-data'))
    parser.add_argument('--write-addon', action='store_true')
    parser.add_argument('--report', type=Path, help='Save a compact audit, including candidate IDs and raw POIs')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source = (root / 'Completionist/Data.lua').read_text(encoding='utf8')
    known = set(map(int, re.findall(r'\{(?:id=)?(\d+),', source)))
    tables = {name: read_db2(args.input / (name + '.db2')) for name in LAYOUTS}
    manifest = json.loads(Path(__file__).with_name('client_tables.json').read_text())
    hashes = {int(r['tableHash'],16): r['tableName'] for r in manifest
              if 'Quest' in r['tableName'] or r['tableName'] in ('UiMap','UiMapAssignment')}
    hotfix = audit_hotfix(args.input / 'cache-snapshot/DBCache.bin', hashes)
    if hotfix['relevantRecords']:
        raise ValueError('Relevant hotfix records require decoding before export')
    cache = read_cache(args.input / 'cache-snapshot/questcache.wdb')
    evidence, markers = make_evidence(tables)
    ids = {row['ID'] for row in tables['QuestV2']['rows']}
    report = dict(build='1.60.1.70009', bundledCount=len(known), tables=tables, cache=cache, hotfix=hotfix,
                  evidence=evidence, markers=markers,
                  clientIdsAbsentFromAddon=sorted(ids-known), addonIdsAbsentFromReadableClientTable=sorted(known-ids),
                  cachedIdsAbsentFromAddon=sorted({q['id'] for q in cache['records']}-known))
    (args.input / 'client-quest-audit.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf8')
    if args.report:
        compact = {k: v for k, v in report.items() if k != 'tables'}
        compact['tables'] = {name: {k: v for k, v in table.items() if k != 'rows'} for name, table in tables.items()}
        compact['limitations'] = [
            'QuestV2 provides IDs and flags, not titles or proof of availability.',
            'Completion markers are client POIs, not verified NPC spawn locations.',
            'ObjectiveIndex 32 is unclassified; it is not imported as a pickup marker.',
            'Encrypted sections are not decoded. Missing table IDs do not justify removing addon quests.',
            'Quest cache records are indexed structurally; payload text is not imported.',
        ]
        ledger = args.input / 'extraction.json'
        if ledger.exists():
            compact['extraction'] = json.loads(ledger.read_text(encoding='utf8'))
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(compact, indent=2, ensure_ascii=False)+'\n', encoding='utf8')
    if args.write_addon:
        write_lua(root / 'Completionist/ClientData.lua', evidence)
    print(json.dumps({k: len(v) if isinstance(v,(list,dict)) else v for k, v in report.items()}, indent=2))


if __name__ == '__main__':
    main()
