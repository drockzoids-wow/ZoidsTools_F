"""Exercise saved settings across fresh Lua runtimes, without touching game files."""
from pathlib import Path


def check_persistence(LuaRuntime, saved_file=None):
    root = Path(__file__).resolve().parents[1]

    def start(saved='', recovery='', bundled=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            frames = {}
            function CreateFrame()
                local frame = {}
                function frame:RegisterEvent() end
                function frame:SetScript(_, fn) self.handler = fn end
                frames[#frames + 1] = frame
                return frame
            end
            SlashCmdList = {}
            messages = {}
            DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) messages[#messages + 1] = text end }
            tickers = {}
            C_Timer = { NewTicker = function(interval, callback)
                local ticker = { interval = interval, callback = callback }
                tickers[#tickers + 1] = ticker
                return ticker
            end }
        ''')
        if bundled:
            lua.execute((root / 'Recovery/Recovery.lua').read_text(), 'ZoidsTools_F_Recovery')
        lua.execute(recovery)
        if bundled:
            lua.execute("frames[1].handler(nil, 'ADDON_LOADED', 'ZoidsTools_F_Recovery')")
        ns = lua.table()
        lua.execute((root / 'Core.lua').read_text(encoding='utf-8-sig'), 'ZoidsTools_F', ns)
        lua.execute(saved)  # WoW loads saved variables after addon files, before ADDON_LOADED.
        lua.globals().ns = ns
        lua.execute("frames[#frames].handler(nil, 'ADDON_LOADED', 'ZoidsTools_F'); assert(ns.db == ZoidsTools_FDB)")
        return lua

    def snapshot(lua, variable='ZoidsTools_FDB'):
        return lua.execute('''
            local variable = ...
            local function serialize(value)
                if type(value) == 'string' then return string.format('%q', value) end
                if type(value) ~= 'table' then return tostring(value) end
                local fields = {}
                for key, child in pairs(value) do
                    fields[#fields + 1] = '[' .. serialize(key) .. ']=' .. serialize(child)
                end
                table.sort(fields)
                return '{' .. table.concat(fields, ',') .. '}'
            end
            return variable .. '=' .. serialize(_G[variable])
        ''', variable)

    lua = start()
    lua.execute('''
        local db = ns.db
        db.vendor.autoSellJunk = true
        db.quests.minimizeTracker = false
        db.quests.autoAccept = true
        db.quests.autoTurnIn = true
        db.quests.pauseModifier = 'alt'
        db.loot.fastLoot = false
        db.loot.slotDelay = 0.08
        db.vendor.autoRepairMode = 'guild'
        db.unitFrames.classColorHealth = true
        db.tooltips.classColoredNames = false
        db.actionBars.rangeTint = false
        db.campfire.enabled = false
        db.campfire.x, db.campfire.y = 88, 99
        db.stats.enabled = false
        db.stats.locked = true
        db.stats.x, db.stats.y = 123, -456
        db.castbars.player = { enabled = true, width = 310, height = 25 }
        db.windows.bagAnchorCorner = "BOTTOMRIGHT"
        db.windows.bagAnchor = {point="BOTTOMRIGHT",x=700,y=120}
        db.windows.enabled = false
        db.windows.moveBags = false
        db.windows.points.CharacterFrame = { point = 'CENTER', x = 77, y = -90 }
        db.windows.scales.CharacterFrame = 1.2
        db.customDamageMeter.enabled = true
        db.customDamageMeter.backgroundOpacity = 0
        db.customDamageMeter.x = 0
        db.customDamageMeter.y = -99
        db.customDamageMeter.secondWindow.enabled = true
        db.ui.minimap.show = false
        db.ui.minimap.minimapPos = 35
        db.ui.window = { point = 'CENTER', relativePoint = 'CENTER', x = 80, y = 90 }
        db.layouts.saved = { snapGap = 7, windows = { { x = 1, y = 2 } } }
    ''')
    # Click real macro page controls, then reload their serialized settings in fresh VMs.
    controls_lua = LuaRuntime(unpack_returned_tuples=True)
    controls_lua.execute((root / 'Tests/ui_localization.lua').read_text(encoding='utf-8'))
    controls_ns = controls_lua.table()
    for file in ['Core.lua', 'Modules/ConsumableMacros.lua', 'UI/Theme.lua', 'UI/Controls.lua', 'UI/Macros.lua']:
        controls_lua.execute((root / file).read_text(encoding='utf-8'), 'ZoidsTools_F', controls_ns)
    controls_lua.globals().ns = controls_ns
    controls_lua.execute("""
        InitializeTestSettings()
        local create = CreateFrame
        macroChecks = {}
        function CreateFrame(kind, ...)
            local widget = create(kind, ...)
            if kind == 'CheckButton' then macroChecks[#macroChecks+1] = widget end
            return widget
        end
        local page = ns.UI.CreateMacrosPage(UIParent)
        -- The native check state may be numeric on older clients.
        for _,index in ipairs({1,3}) do
            local check = macroChecks[index]
            check.GetChecked = function() return 1 end
            check.scripts.OnClick(check)
        end
        assert(ns.db.macros.healthEnabled and ns.db.macros.manaEnabled,
            'Checked macro controls must save true, including numeric native checked states')
        assert(ns.db == ZoidsTools_FDB)
    """)
    macro_saved = snapshot(controls_lua)
    for _ in range(3):
        reloaded = start(macro_saved)
        reloaded.execute('assert(ns.db.macros.healthEnabled and ns.db.macros.manaEnabled)')
        assert snapshot(reloaded) == macro_saved
    controls_lua.execute("""
        for _,value in ipairs({0,false}) do
            macroChecks[1].GetChecked = function() return value end
            macroChecks[1].scripts.OnClick(macroChecks[1])
            assert(ns.db.macros.healthEnabled == false)
        end
        macroChecks[3].GetChecked = function() return nil end
        macroChecks[3].scripts.OnClick(macroChecks[3])
        assert(ns.db.macros.manaEnabled == false)
        macroChecks[1].GetChecked = function() return true end
        macroChecks[1].scripts.OnClick(macroChecks[1])
        assert(ns.db.macros.healthEnabled == true)
    """)
    disabled_reload = start(snapshot(controls_lua))
    disabled_reload.execute('assert(ns.db.macros.healthEnabled and ns.db.macros.manaEnabled == false)')
    print('PASS: real macro checkboxes persist numeric/boolean checked states across three fresh reloads; intentional disable persists')
    expected = snapshot(lua)
    for _ in range(3):
        lua = start(expected)
        assert snapshot(lua) == expected, 'Saved settings changed during addon loading'
    recovery = "ZoidsTools_FRecovery={stats={enabled=true,locked=true,x=321,y=-87},vendor={autoSellJunk=true}}"
    recovered = start(recovery=recovery)
    recovered.execute("assert(ns.settingsRecoveryUsed and ns.db.stats.x == 321 and ns.db.vendor.autoSellJunk)")
    baseline = snapshot(recovered)
    for _ in range(3):
        assert snapshot(start(recovery=recovery)) == baseline
    recovered.execute("ns.db.stats.x=999; assert(ZoidsTools_FRecovery.stats.x == 321)")
    existing = start("ZoidsTools_FDB={stats={x=42,locked=false},vendor={autoSellJunk=false}}", recovery)
    existing.execute("assert(not ns.settingsRecoveryUsed and ns.db.stats.x == 42 and not ns.db.stats.locked and not ns.db.vendor.autoSellJunk)")
    empty = start("ZoidsTools_FDB={}", recovery)
    empty.execute("assert(ns.settingsRecoveryUsed and ns.db.stats.x == 321)")
    blank = start(recovery='ZoidsTools_FRecovery={}')
    blank.execute('assert(not ns.settingsRecoveryUsed)')
    bundled = start("ZoidsTools_FDB={stats={x=42,locked=false}}", bundled=True)
    bundled.execute('''
        -- Stub unrelated feature initializers while exercising the real login hook.
        setmetatable(ns, { __index = function() return function() end end })
        frames[#frames].handler(nil, 'PLAYER_LOGIN')
        setmetatable(ns, nil)
        assert(#tickers == 1 and tickers[1].interval == 600)
        assert(ZoidsTools_FRecoveryDB.stats.x == 42)
        ns.db.stats.x = 500
        ns.db.layouts.example = { nested = { enabled = false, offset = 0 } }
        assert(ZoidsTools_FRecoveryDB.stats.x == 42)
        tickers[1].callback()
        assert(ZoidsTools_FRecoveryDB.stats.x == 500)
        ns.db.layouts.example.nested.offset = 10
        assert(ZoidsTools_FRecoveryDB.layouts.example.nested.offset == 0)
        ns.db.stats.x = 600
        frames[1].handler(nil, 'PLAYER_LOGOUT')
        assert(ZoidsTools_FRecoveryDB.stats.x == 600)
        ZoidsTools_FRecoveryService:Start(ns.db)
        assert(#tickers == 1)
    ''')
    backup = snapshot(bundled, 'ZoidsTools_FRecoveryDB')
    for missing in ['', 'ZoidsTools_FDB={}', 'ZoidsTools_FDB=false']:
        restored = start(missing, backup, bundled=True)
        restored.execute('''
            assert(ns.settingsRecoveryUsed and ns.db.stats.x == 600)
            assert(ns.db.layouts.example.nested.enabled == false)
            ns.db.stats.x = 700
            assert(ZoidsTools_FRecoveryDB.stats.x == 600)
        ''')
    priority = start('ZoidsTools_FDB={stats={x=88}}', backup, bundled=True)
    priority.execute('assert(not ns.settingsRecoveryUsed and ns.db.stats.x == 88)')
    priority.execute("assert(ns.settingsStartup.main and ns.settingsStartup.backup and ns.settingsStartup.source == 'main save')")
    lost = start(bundled=True)
    lost.execute('''
        assert(not ns.settingsStartup.main and not ns.settingsStartup.backup)
        assert(ns.settingsStartup.source == 'defaults')
        ZoidsTools_FRecoveryService:Start(ns.db)
        assert(ZoidsTools_FRecoveryDB.stats.locked == false)
        -- A freshly generated backup must not mask what failed to load.
        SlashCmdList.ZOIDSTOOLS_FOREVER('recovery')
        assert(messages[#messages - 1]:find('main=missing, backup=missing', 1, true))
    ''')
    preset = start(recovery=recovery, bundled=True)
    preset.execute('''
        assert(ns.settingsStartup.source == 'local preset')
        assert(ns.settingsStartup.preset and not ns.settingsStartup.backup)
        assert(ns.db.stats.locked and ns.db.stats.x == 321)
        ZoidsTools_FRecoveryService:Start(ns.db)
        ns.db.stats.x = 100
        tickers[1].callback()
        assert(ZoidsTools_FRecoveryDB.stats.x == 100 and ZoidsTools_FRecovery.stats.x == 321)
        assert(ns.settingsStartup.source == 'local preset')
    ''')
    preferred_backup = start(recovery=backup + '\n' + recovery, bundled=True)
    preferred_backup.execute("assert(ns.db.stats.x == 600 and ns.settingsStartup.source == 'recovery save')")
    manual = start('ZoidsTools_FDB={stats={locked=false,x=0}}', recovery, bundled=True)
    manual.execute('''
        reloads = 0
        function ReloadUI() reloads = reloads + 1 end
        function InCombatLockdown() return true end
        SlashCmdList.ZOIDSTOOLS_FOREVER('restorepreset')
        assert(reloads == 0 and ns.db.stats.x == 0)
        function InCombatLockdown() return false end
        SlashCmdList.ZOIDSTOOLS_FOREVER('restorepreset')
        assert(reloads == 1 and ns.db == ZoidsTools_FDB and ns.db.stats.x == 321)
        assert(ZoidsTools_FRecoveryDB.stats.locked)
        ns.db.stats.x = 200
        assert(ZoidsTools_FRecovery.stats.x == 321)
        tickers[1].callback()
        assert(ZoidsTools_FRecoveryDB.stats.x == 200)
    ''')
    # A companion with the main addon disabled must preserve its existing backup.
    idle = start(recovery=backup, bundled=True)
    idle.execute("frames[1].handler(nil, 'PLAYER_LOGOUT'); assert(ZoidsTools_FRecoveryDB.stats.x == 600 and #tickers == 0)")
    no_timer = start(bundled=True)
    no_timer.execute('''
        C_Timer = nil
        ZoidsTools_FRecoveryService:Start(ns.db)
        ns.db.stats.x = 123
        frames[1].handler(nil, 'PLAYER_LOGOUT')
        assert(ZoidsTools_FRecoveryDB.stats.x == 123)
    ''')
    # A nonempty stale main save must not replace a newer explicit macro choice.
    macro_recovery = start('ZoidsTools_FDB={stats={x=42}}', bundled=True)
    macro_recovery.execute('ZoidsTools_FRecoveryService:Start(ns.db)')
    macro_ns = macro_recovery.globals().ns
    macro_recovery.execute((root / 'Modules/ConsumableMacros.lua').read_text(encoding='utf-8'), 'ZoidsTools_F', macro_ns)
    macro_recovery.execute("""
        -- No bag/macro APIs needed to exercise persistence of explicit choices.
        C_Timer.After = function() end
        ns:SetConsumableMacroOption('healthEnabled', true)
        ns:SetConsumableMacroOption('manaEnabled', true)
        assert(ZoidsTools_FRecoveryDB.macros.healthEnabled and ZoidsTools_FRecoveryDB.macros.manaEnabled)
        assert(ZoidsTools_FRecoveryDB.macros.revision == 2)
    """)
    macro_backup = snapshot(macro_recovery, 'ZoidsTools_FRecoveryDB')
    stale = start('ZoidsTools_FDB={macros={healthEnabled=false,manaEnabled=false},stats={x=123}}', macro_backup, bundled=True)
    stale.execute("""
        assert(ns.macroSettingsRecoveryUsed and ns.db.macros.healthEnabled and ns.db.macros.manaEnabled)
        assert(ns.db.stats.x == 123) -- Recover only macros, not unrelated valid settings.
        ZoidsTools_FRecoveryService:Start(ns.db)
        assert(ZoidsTools_FRecoveryDB.macros.healthEnabled)
    """)
    macro_recovery.execute("""
        ns:SetConsumableMacroOption('healthEnabled', false)
        ns:SetConsumableMacroOption('manaEnabled', false)
        assert(ZoidsTools_FRecoveryDB.macros.revision == 4)
    """)
    disabled_backup = snapshot(macro_recovery, 'ZoidsTools_FRecoveryDB')
    off = start('ZoidsTools_FDB={macros={healthEnabled=true,manaEnabled=true,revision=2}}', disabled_backup, bundled=True)
    off.execute('assert(ns.db.macros.healthEnabled == false and ns.db.macros.manaEnabled == false)')
    newer_main = start('ZoidsTools_FDB={macros={healthEnabled=false,manaEnabled=false,revision=5}}', macro_backup, bundled=True)
    newer_main.execute('assert(not ns.macroSettingsRecoveryUsed and ns.db.macros.revision==5 and ns.db.macros.healthEnabled==false)')
    pinned = 'ZoidsTools_FRecovery={macros={healthEnabled=true,manaEnabled=true,healthCombatItems=true,manaCombatPotion=true,revision=1}}'
    reset = start('ZoidsTools_FDB={macros={healthEnabled=false,manaEnabled=false},stats={x=77}}',
                  'ZoidsTools_FRecoveryDB={macros={healthEnabled=false,manaEnabled=false}}\n'+pinned, bundled=True)
    reset.execute('assert(ns.db.macros.healthEnabled and ns.db.macros.manaEnabled and ns.db.stats.x==77)')
    intentional_off = start('ZoidsTools_FDB={macros={healthEnabled=false,manaEnabled=false,revision=2}}', pinned, bundled=True)
    intentional_off.execute('assert(not ns.db.macros.healthEnabled and not ns.db.macros.manaEnabled)')
    tracker = start(bundled=True)
    tracker.execute('ZoidsTools_FRecoveryService:Start(ns.db)')
    tracker.execute((root / 'Completionist/Bootstrap.lua').read_text(), 'ZoidsTools_F', tracker.globals().ns)
    tracker.execute('''
        ns.Completionist.char={locked=true,minimized=true,windowPoint={point="TOPLEFT",relative="BOTTOMLEFT",x=0,y=1200}}
        ns.Completionist.SaveTrackerSettings()
        assert(ZoidsTools_FRecoveryDB.completionistTracker.locked)
        assert(ZoidsTools_FRecoveryDB.completionistTracker.windowPoint.y==1200)
        ns.Completionist.char.windowPoint.y=999
        assert(ZoidsTools_FRecoveryDB.completionistTracker.windowPoint.y==1200)
    ''')
    tracker_backup = snapshot(tracker, 'ZoidsTools_FRecoveryDB')
    for main in ['', 'ZoidsTools_FDB={stats={x=42}}', 'ZoidsTools_FDB={completionistTracker={locked=false,revision=0}}']:
        recovered_tracker = start(main, tracker_backup, bundled=True)
        recovered_tracker.execute('assert(ns.db.completionistTracker.locked and ns.db.completionistTracker.windowPoint.y==1200)')
    newer_tracker = start('ZoidsTools_FDB={completionistTracker={locked=false,revision=10}}', tracker_backup, bundled=True)
    newer_tracker.execute('assert(not ns.db.completionistTracker.locked and ns.db.completionistTracker.revision==10)')
    print('PASS: shared tracker immediate recovery snapshot; missing/stale main recovery; newer unlock preserved')
    print('PASS: immediate macro recovery snapshot, newer backup overrides stale nonempty main settings, explicit disable and newer main win')
    print('PASS: bundled recovery, 600-second snapshots, deep copies, logout, reload restoration, and disabled companion fallback')
    print('PASS: missing-save recovery, repeated reloads, independent snapshot, and normal saved-settings priority')
    if saved_file:
        contents = Path(saved_file).read_text(encoding='utf-8-sig')
        # Compare the client's actual saved table before and after applying defaults.
        lua = start(contents)
        expected = snapshot(lua)
        assert snapshot(start(expected)) == expected
    print('PASS: saved settings survive three fresh Lua reloads (including false, zero, nested layouts, and positions)')
