"""Extract selected installed Forever tables with a supplied official TACTTool.

The game installation is read-only. Close WoW/Battle.net first. Downloads are
not requested: numeric file IDs avoid TACTTool's external filename-list lookup.
Output and tool working files stay in the selected research directory.
"""
import argparse
import ctypes
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

TABLES = ['QuestV2','QuestPOIPoint','QuestPOIBlob','QuestLine','QuestLineXQuest',
          'QuestV2CliTask','QuestObjective','QuestHub','QuestInfo','QuestSort',
          'CollectableSourceQuest','CollectableSourceQuestSparse','UiMap','UiMapAssignment']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--tool', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('build/client-data'))
    args = parser.parse_args()
    game, tool, output = args.game.resolve(), args.tool.resolve(), args.output.resolve()
    if output == game or game in output.parents:
        raise ValueError('Research output must be outside the game installation')
    if not tool.is_file():
        raise ValueError('Archive reader executable does not exist')
    if output.exists() and any(output.iterdir()):
        raise ValueError('Choose a fresh, empty output directory to preserve previous snapshots')
    lines = (game / '.build.info').read_text().splitlines()
    columns = [s.split('!')[0] for s in lines[0].split('|')]
    builds = [dict(zip(columns, row.split('|'))) for row in lines[1:]]
    selected = [b for b in builds if b.get('Product') == 'wow_classic_beta' and b.get('Active') == '1']
    if len(selected) != 1 or selected[0]['Version'] != '1.60.1.70009':
        raise ValueError('Expected one active Forever build 1.60.1.70009; audit new layouts before proceeding')
    build = selected[0]
    output.mkdir(parents=True, exist_ok=True)
    snapshot = output / 'cache-snapshot'; snapshot.mkdir(exist_ok=True)
    for src, dest in [('WDB/enUS/questcache.wdb','questcache.wdb'),('ADB/enUS/DBCache.bin','DBCache.bin')]:
        shutil.copyfile(game / '_classic_beta_/Cache' / src, snapshot / dest)
    manifest = json.loads(Path(__file__).with_name('client_tables.json').read_text())
    table_ids = {r['tableName']: r['db2FileDataID'] for r in manifest}
    # Suppress Windows crash-dialog boxes in child readers. Failures remain in logs.
    if hasattr(ctypes, 'windll'):
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    ledger = dict(build=build['Version'], buildKey=build['Build Key'], cdnKey=build['CDN Key'],
                  extractorSHA256=hashlib.sha256(tool.read_bytes()).hexdigest(), files=[])
    for name in TABLES:
        destination = output / (name + '.db2')
        if destination.exists():
            raise ValueError(f'Choose a fresh output directory: {destination} already exists')
        cmd = [str(tool), '-d', str(game), '-p', 'wow_classic_beta', '-b', build['Build Key'],
               '-c', build['CDN Key'], '-m', 'id', '-i', str(table_ids[name]), '-o', str(destination)]
        result = subprocess.run(cmd, cwd=output, capture_output=True, text=True, timeout=45)
        (output / (name + '.log')).write_text(result.stdout + result.stderr, encoding='utf8')
        if result.returncode or not destination.exists() or 'Downloading' in result.stdout:
            raise RuntimeError(f'{name}: local extraction failed or attempted fallback; inspect its log')
        ledger['files'].append(dict(table=name, fileDataID=table_ids[name],
                                   sha256=hashlib.sha256(destination.read_bytes()).hexdigest()))
        print(f'Extracted {name}')
    (output / 'extraction.json').write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf8')


if __name__ == '__main__':
    main()
