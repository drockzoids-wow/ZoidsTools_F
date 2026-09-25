"""Merge cached public Forever indexes into the compact addon inventory.

Run collect_forever_quests.ps1 first. Sources are parsed as data, never executed.
Existing IDs absent from the current source are retained, not silently deleted.
"""
import argparse
from collections import Counter, defaultdict
import html
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def text(markup):
    return html.unescape(re.sub(r'<[^>]+>', '', markup)).strip()


def read_secondary(folder):
    records = {}
    pages = [p for p in folder.glob('60tools*.html') if '-detail-' not in p.name]
    if not pages:
        return records
    root = (folder / '60tools.html').read_text(encoding='utf-8')
    total = int(re.search(r'([\d,]+)<!-- --> records', root)[1].replace(',', ''))
    # The accessible full index supplies every ID/name even when table pagination
    # has unstable boundaries between identical titles. Detail fields stay unknown.
    for link, id, title in re.findall(r'href="(/quests/(\d+)[^"]*)"[^>]*>(.*?)</a>', root):
        records[int(id)] = dict(id=int(id), name=text(title), level=0, area='',
                                url='https://www.60.tools' + link)
    for page in pages:
        for row in re.findall(r'<tr>.*?</tr>', page.read_text(encoding='utf-8')):
            match = re.search(r'href="(/quests/(\d+)[^"]*)"[^>]*>(.*?)</a>', row)
            if not match:
                continue
            cells = re.findall(r'<td>(.*?)</td>', row)
            level = text(cells[1])
            record = dict(id=int(match[2]), name=text(match[3]),
                          level=int(level) if level else 0, area=text(cells[2]),
                          url='https://www.60.tools' + match[1])
            if record['id'] in records and records[record['id']]['area'] and record != records[record['id']]:
                raise ValueError('Inconsistent secondary-source duplicate')
            records[record['id']] = record
    if len(records) != total:
        raise ValueError(f'Secondary index coverage: {len(records)} of {total}')
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'build/quest-refresh')
    parser.add_argument('--allow-count-mismatch', action='store_true',
                        help='Record a reviewed source count discrepancy in the manifest')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    folder = args.cache
    log = read_json(folder / 'collection-log.json')
    raw = read_json(folder / 'quests-raw.json')
    assert len(raw) == len({q['id'] for q in raw}) == log['uniqueCount']
    if log['uniqueCount'] != log['reportedTotal'] and not args.allow_count_mismatch:
        raise ValueError('Source count discrepancy requires explicit review')
    page = (folder / 'quests.html').read_text(encoding='utf-8-sig')
    filters = json.JSONDecoder().raw_decode(page[page.index('Filter.init(') + 12:])[0]
    categories = {(int(g['id']), int(c['id'])): c['url'].replace('-', ' ').title()
                  for g in filters['categories'] for c in g['categories']}
    # Confirmed by the player's quest-log categories and Forever quest pages.
    categories[(-2, 16593)] = 'Zephras Isle'
    categories[(-2, -666)] = 'Camping'
    secondary = read_secondary(folder)
    target = ROOT / 'Completionist/Data.lua'
    original = target.read_text(encoding='utf-8')
    start = original.index('ns.quests = {') + len('ns.quests = {')
    end = original.index('\n}\n', start)
    old = {row[0]: row for line in original[start:end].splitlines() if line.strip()
           for row in [json.loads('[' + line.strip().removesuffix(',')[1:-1] + ']')]}
    # Keep previously observed records in the existing suffix, with their evidence.
    observed = set(map(int, re.findall(r'\{id=(\d+),', original[end:])))
    old_ids = set(old) | observed
    old_categories = defaultdict(Counter)
    for q in raw:
        if q['id'] in old:
            old_categories[(q['category2'], q['category'])][old[q['id']][5]] += 1
    rows = dict(old)
    source_ids = {q['id'] for q in raw}
    root_match = re.search(r"new Listview\(\{template: 'quest'.*?data:\s*(\[)", page, re.S)
    root_rows = json.JSONDecoder().raw_decode(page[root_match.start(1):])[0]
    if not {q['id'] for q in root_rows} <= source_ids:
        raise ValueError('Partitioned collection missed IDs shown on the unfiltered page')
    types = {0: 'Quest', 1: 'Elite', 21: 'Life', 41: 'PvP', 62: 'Raid',
             81: 'Dungeon', 82: 'World Event', 83: 'Legendary'}
    sides = {0: 'Unassigned', 1: 'Alliance', 2: 'Horde', 3: 'Both'}
    unmapped = Counter()
    changed = []
    for q in raw:
        if q['id'] in observed:
            continue
        key = (q['category2'], q['category'])
        area = categories.get(key)
        if not area and old_categories[key]:
            area = old_categories[key].most_common(1)[0][0]
        if not area:
            area = f'Uncatalogued {q["category"]}'
            unmapped[area] += 1
        row = [q['id'], q['name'], q['level'], q['reqlevel'],
               sides.get(q['side'], 'Unknown'), area,
               types.get(q['type'], f'Type {q["type"]}'), q.get('reqclass', 0)]
        if q['id'] in old and old[q['id']][:8] != row:
            changed.append(q['id'])
        rows[q['id']] = row
    # This source includes Classic-only records. Require explicit Forever client
    # membership on each extra quest, and label its inherited Classic details.
    secondary_only = []
    secondary_excluded = []
    secondary_evidence = {}
    for id, q in secondary.items():
        if id not in rows and id not in observed:
            detail = (folder / f'60tools-detail-{id}.html').read_text(encoding='utf-8')
            facts = {text(k): text(v) for k, v in re.findall(r'<dt>(.*?)</dt><dd>(.*?)</dd>', detail)}
            assert int(facts['Quest ID']) == id
            if not facts.get('Forever client', '').startswith('Lists this quest'):
                secondary_excluded.append(id)
                continue
            class_bits = {'Warrior': 1, 'Paladin': 2, 'Hunter': 4, 'Rogue': 8,
                          'Priest': 16, 'Shaman': 64, 'Mage': 128, 'Warlock': 256, 'Druid': 1024}
            classes = facts.get('Classes', '')
            mask = sum(class_bits[name.strip()] for name in classes.split(',') if name.strip())
            rows[id] = [id, q['name'], int(facts['Level']), int(facts['Minimum level']),
                        facts['Faction'], facts['Zone'], facts.get('Type', 'Quest'), mask, 'secondary']
            secondary_only.append(id)
            secondary_evidence[id] = dict(url=q['url'], client=facts['Forever client'], details=facts['Source'])
    retained = sorted(set(old) - source_ids)
    for id in retained:
        # Source absence is not evidence of removal from the game.
        if len(rows[id]) == 8:
            rows[id] = rows[id] + ['retained']
    rows = sorted(rows.values(), key=lambda r: (r[5], r[2], r[3], r[1], r[0]))
    # JSON strings are Lua-compatible for these fields; forbid JSON-only escapes.
    rendered = []
    for row in rows:
        encoded = json.dumps(row, ensure_ascii=False, separators=(',', ':'))
        if re.search(r'\\(?:u[0-9a-fA-F]{4}|[bf])', encoded):
            raise ValueError('Unsupported control character in source text')
        rendered.append('{' + encoded[1:-1] + '},')
    header = original[:start]
    header = re.sub(r'^-- Private snapshot.*\n',
                    f'-- Wowhead Forever snapshot {log["checked"]}; older absent IDs retained. See Sources.json.\n', header)
    header = header.replace('classMask=8 }', 'classMask=8, sourceStatus=9 }')
    output = header + '\n' + '\n'.join(rendered) + original[end:]
    manifest = dict(checked=log['checked'], source='https://www.wowhead.com/forever/quests',
                    reportedTotal=log['reportedTotal'], collectedUnique=log['uniqueCount'],
                    countDiscrepancy=log['uniqueCount'] - log['reportedTotal'],
                    coverage='All level partitions resolved without truncation; source totals differ. No claim of all playable quests.',
                    totalBundled=len(rows) + len(observed),
                    wowheadAddedIds=sorted(source_ids - old_ids),
                    updatedIds=sorted(changed), retainedIds=retained,
                    secondarySource='https://www.60.tools/quests', secondaryCount=len(secondary),
                    secondaryAddedIds=sorted(secondary_only),
                    secondaryExcludedIds=sorted(secondary_excluded), secondaryEvidence=secondary_evidence,
                    unmappedCategories=dict(unmapped), requests=log['requests'])
    (folder / 'import-report.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in manifest.items() if not isinstance(v, (list, dict))}, indent=2))
    print(f'Added from Wowhead: {len(manifest["wowheadAddedIds"])}; secondary: {len(secondary_only)}; updated: {len(changed)}; retained: {len(retained)}')
    if args.write:
        target.write_text(output, encoding='utf-8', newline='\n')
        (ROOT / 'Completionist/Sources.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
