"""Validate shipped localization, format safety, fallback and localized game detection."""
from pathlib import Path
import re


def check_localization(LuaRuntime):
    root = Path(__file__).resolve().parents[1]
    languages = ['enUS', 'enGB', 'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW', 'unknown']
    fmt = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs%]')
    commands = re.compile(r'/ztf(?: [a-z]+)?')
    for language in languages:
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().language = language
        lua.execute('function GetLocale() return language end')
        ns = lua.table()
        lua.execute((root / 'Localization.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', ns)
        for path in sorted((root / 'Locales').glob('*.lua')):
            lua.execute(path.read_text(encoding='utf-8'), 'ZoidsTools_F', ns)
        keys = list(ns.localeKeys.keys())
        assert len(keys) >= 230
        for key in keys:
            value = ns.L[key]
            assert isinstance(value, str) and value, (language, key)
            if language not in ['enUS', 'enGB', 'unknown']:
                assert lua.eval('rawget')(ns.L, key), (language, 'missing key', key)
            else:
                assert value == key, (language, 'fallback changed', key)
            assert fmt.findall(key) == fmt.findall(value), (language, 'format changed', key)
            assert commands.findall(key) == commands.findall(value), (language, 'command changed', key)
            assert not re.search(r'ZXQ|QXZ|\[\[\[', value), (language, 'translation marker', key)
            if fmt.search(key):
                arguments = [7 if token[-1] in 'diouxXeEfgGc' else 'sample'
                             for token in fmt.findall(key) if token != '%%']
                lua.eval('string.format')(value, *arguments)
        assert ns.L['untranslated future label'] == 'untranslated future label'
        # Exercise detection using localized names supplied by the game, not our translation table.
        lua.globals().ns = ns
        lua.execute('''
            local localized = { [1] = "Zone-" .. language, [392] = "Town-" .. language }
            zone, subzone, watched = localized[1], "", nil
            function GetRealZoneText() return zone end
            function GetSubZoneText() return subzone end
            function UnitFactionGroup() return "Alliance" end
            function IsInInstance() return false end
            C_Map = { GetAreaInfo = function(id) return localized[id] end }
            C_Reputation = {
                GetFactionDataByID = function(id) return {name="Localized faction", factionID=id} end,
                SetWatchedFactionByID = function(id) watched=id end,
            }
            ns.db = { reputation = { autoZone = true } }
        ''')
        lua.execute((root / 'Modules/ZoneReputation.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', ns)
        lua.execute('''
            ns:RefreshZoneReputation(true); assert(watched==47)
            subzone="Town-" .. language
            ns:RefreshZoneReputation(); assert(watched==470)
        ''')
        lua.execute((root / 'Tests/ui_localization.lua').read_text(encoding='utf-8'))
        files = ['Core.lua', 'Compatibility.lua']
        files += [str(p.relative_to(root)) for p in (root / 'Modules').glob('*.lua')]
        files += ['UI/Theme.lua', 'UI/Controls.lua']
        files += [str(p.relative_to(root)) for p in (root / 'UI').glob('*.lua')
                  if p.name not in ['Theme.lua', 'Controls.lua', 'Window.lua', 'Minimap.lua']]
        files += ['UI/Window.lua']
        for file in files:
            lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', ns)
        lua.globals().InitializeTestSettings()
        lua.globals().VerifySettings(ns)
    # Catch translated keys accidentally substituted into APIs or saved enum comparisons.
    sources = [root / 'Core.lua', *root.glob('UI/*.lua'), *root.glob('Modules/*.lua')]
    for path in sources:
        source = path.read_text(encoding='utf-8')
        assert not re.search(r'(?:==|~=)\s*L\[', source), path
        assert not re.search(r'_G\[[^\n]*L\[', source), path
        assert not re.search(r'CreateFrame\([^\n]*L\[', source), path
    print(f'PASS: all {len(keys)} strings across 10 translated locales, English/unknown fallback, format arguments, slash commands, localized area detection, stable API identifiers')
    print('PASS: every settings page builds and refreshes with every client locale')
