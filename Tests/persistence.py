"""Exercise saved settings across fresh Lua runtimes, without touching game files."""
from pathlib import Path


def check_persistence(LuaRuntime, saved_file=None):
    root = Path(__file__).resolve().parents[1]

    def start(saved=''):
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
    stale = start(expected + '\nZoidsTools_FRecovery={stats={x=9999}};ZoidsTools_FBackupDB={stats={x=9999}};ZoidsTools_FPresetDB={stats={x=9999}};ZoidsTools_FRecoveryDB={stats={x=9999}}')
    assert snapshot(stale) == expected
    stale.execute("""
        assert(#tickers == 0)
        local finished = 0
        ns.FinishWindowDrags = function() finished = finished + 1 end
        frames[1].handler(nil, 'PLAYER_LOGOUT')
        assert(finished == 1, 'Reload/logout must finish window drags without a companion')
    """)
    print('PASS: obsolete beta backups are ignored; no backup timer is installed')
    if saved_file:
        contents = Path(saved_file).read_text(encoding='utf-8-sig')
        # Compare the client's actual saved table before and after applying defaults.
        lua = start(contents)
        expected = snapshot(lua)
        assert snapshot(start(expected)) == expected
    print('PASS: saved settings survive three fresh Lua reloads (including false, zero, nested layouts, and positions)')
