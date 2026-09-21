"""Fresh-VM recovery/import checks; never write game files or create archives."""
from pathlib import Path

def check_builtin_recovery(LuaRuntime):
    root = Path(__file__).resolve().parents[1]
    def start(saved='', legacy=''):
        lua=LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
            frames={}; timers={}; messages={}; SlashCmdList={}
            function CreateFrame()
                local f={}
                function f:RegisterEvent()end
                function f:SetScript(_,fn)self.handler=fn end
                frames[#frames+1]=f;return f
            end
            C_Timer={NewTicker=function(_,fn)timers[#timers+1]=fn;return {}end}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,s)messages[#messages+1]=s end}
            function fire(e,name)for _,f in ipairs(frames)do f.handler(f,e,name)end end
            function serialize(v)
                if type(v)=='table' then
                    local out={};for k,x in pairs(v)do out[#out+1]='['..serialize(k)..']='..serialize(x)end
                    return '{'..table.concat(out,',')..'}'
                elseif type(v)=='string' then return string.format('%q',v)
                else return tostring(v)end
            end
        """)
        if legacy:
            lua.execute((root/'Recovery/Recovery.lua').read_text(),'ZoidsTools_F_Recovery')
            lua.execute(legacy)
            lua.execute("fire('ADDON_LOADED','ZoidsTools_F_Recovery')")
        ns=lua.table();lua.globals().ns=ns
        for file in ['SettingsRecovery.lua','Core.lua']:
            lua.execute((root/file).read_text(encoding='utf-8'),'ZoidsTools_F',ns)
        lua.execute(saved)
        lua.execute("fire('ADDON_LOADED','ZoidsTools_F')")
        return lua
    def login(lua):
        lua.execute("""
            setmetatable(ns,{__index=function()return function()end end})
            fire('PLAYER_LOGIN')
            setmetatable(ns,nil)
        """)
    def save(lua):
        return lua.execute("""
            local lines={}
            for _,key in ipairs({'ZoidsTools_FDB','ZoidsTools_FBackupDB','ZoidsTools_FPresetDB'})do
                if _G[key] then lines[#lines+1]=key..'='..serialize(_G[key])end
            end
            return table.concat(lines,'\\n')
        """)
    fresh=start();login(fresh)
    fresh.execute("""
        assert(#timers==1 and ZoidsTools_FRecoveryDB==nil)
        ns.db.windows.points.CharacterFrame={x=77,y=-90,point='CENTER'}
        ns.db.stats.x=345;ns.db.macros.healthEnabled=true
        SlashCmdList.ZOIDSTOOLS_FOREVER('savepreset')
        assert(ZoidsTools_FPresetDB.stats.x==345 and ZoidsTools_FBackupDB.stats.x==345)
        ns.db.stats.x=678;timers[1]()
        assert(ZoidsTools_FBackupDB.stats.x==678 and ZoidsTools_FPresetDB.stats.x==345)
        ns.db.stats.x=900;fire('PLAYER_LOGOUT')
        assert(ZoidsTools_FBackupDB.stats.x==900)
    """)
    persisted=save(fresh)
    reloaded=start(persisted);login(reloaded)
    reloaded.execute("""
        assert(ns.db.stats.x==900 and ZoidsTools_FPresetDB.stats.x==345)
        reloads=0;function ReloadUI()reloads=reloads+1 end
        SlashCmdList.ZOIDSTOOLS_FOREVER('restorepreset')
        assert(reloads==1 and ns.db.stats.x==345)
        assert(ns.db.windows.points.CharacterFrame.x==77 and ns.db.macros.healthEnabled)
    """)
    recovered=start(persisted+'\nZoidsTools_FDB=nil')
    recovered.execute('assert(ns.settingsRecoveryUsed and ns.db.stats.x==900)')
    legacy="ZoidsTools_FRecoveryDB={stats={x=321}};ZoidsTools_FRecovery={stats={x=123},macros={healthEnabled=true,revision=1}}"
    imported=start(legacy=legacy);login(imported)
    imported.execute("""
        assert(ns.db.stats.x==321 and ns.db.macros.healthEnabled)
        assert(ZoidsTools_FPresetDB.stats.x==123)
        assert(ZoidsTools_FBackupDB~=ZoidsTools_FRecoveryDB)
        ns.db.stats.x=456;ZoidsTools_FRecoveryService:Capture()
        assert(ZoidsTools_FRecoveryDB.stats.x==456 and ZoidsTools_FBackupDB.stats.x==456)
    """)
    without_companions=start(save(imported));login(without_companions)
    without_companions.execute("""
        assert(ns.db.stats.x==456 and ZoidsTools_FRecovery.stats.x==123)
        assert(ZoidsTools_FRecoveryDB==nil and #timers==1)
    """)
    fixed=start('ZoidsTools_FPresetDB={stats={x=1}}', legacy)
    login(fixed)
    fixed.execute("""
        function ReloadUI()end
        SlashCmdList.ZOIDSTOOLS_FOREVER('restorepreset')
        assert(ns.db.stats.x==123, 'Explicit restore must use the fixed file when installed')
    """)
    reset_all=start()
    reset_all.execute('assert(ns.settingsStartup.source=="defaults")')

    # No private preset addon: save to both files, then simulate the beta losing
    # every main-addon table. Automatic snapshots must not overwrite the preset.
    separate=start(legacy='ZoidsTools_FRecoveryDB={stats={x=10}}')
    login(separate)
    separate.execute("""
        ns.db.stats.x=777
        SlashCmdList.ZOIDSTOOLS_FOREVER('savepreset')
        ns.db.stats.x=888;fire('PLAYER_LOGOUT')
        assert(ZoidsTools_FRecoveryPresetDB.stats.x==777)
        assert(ZoidsTools_FRecoveryDB.stats.x==888)
    """)
    companion_saved=separate.execute("""
        return 'ZoidsTools_FRecoveryDB='..serialize(ZoidsTools_FRecoveryDB)..
            '\\nZoidsTools_FRecoveryPresetDB='..serialize(ZoidsTools_FRecoveryPresetDB)
    """)
    separate_reload=start(legacy=companion_saved)
    login(separate_reload)
    separate_reload.execute("""
        assert(ZoidsTools_FRecoveryService:GetLocalPreset()==nil)
        assert(ZoidsTools_FRecoveryService:GetPreset().stats.x==777)
        assert(ns.db.stats.x==888)
        reloads=0;function ReloadUI()reloads=reloads+1 end
        SlashCmdList.ZOIDSTOOLS_FOREVER('restorepreset')
        assert(reloads==1 and ns.db.stats.x==777)
    """)
    reset_all.execute("""
        SlashCmdList.ZOIDSTOOLS_FOREVER('restorepreset')
        assert(messages[#messages]:find('No saved preset was loaded',1,true))
    """)
    print('PASS: separate preset survives loss of all main tables without private preset addon; snapshots preserve explicit preset')
    print('PASS: built-in backups without companions, personal restore point, positions across fresh reloads, missing-main restore, legacy import and companion removal, optional separate-file mirroring')

    ui=LuaRuntime(unpack_returned_tuples=True)
    ui.execute((root/'Tests/ui_localization.lua').read_text(encoding='utf-8'))
    host=ui.table();ui.globals().ns=host
    ui.execute("""
        ns.db={}; ns.Print=function()end
        saves=0;reloads=0;restores=0;combat=false;saveOK=true
        function InCombatLockdown()return combat end
        function ReloadUI()reloads=reloads+1 end
        ZoidsTools_FRecoveryService={SavePreset=function()saves=saves+1;return saveOK end}
        SlashCmdList.ZOIDSTOOLS_FOREVER=function(command)assert(command=='restorepreset');restores=restores+1 end
    """)
    for name in ['UI/Theme.lua','UI/Controls.lua','UI/RecoveryReminder.lua']:
        ui.execute((root/name).read_text(encoding='utf-8'),'ZoidsTools_F',host)
    ui.execute("""
        ns:ShowRecoveryReminder()
        local f=ZoidsTools_FRecoveryReminder
        assert(f:IsShown() and saves==0 and restores==0 and reloads==0)
        assert(not f.restoreButton.enabled)
        ZoidsTools_FRecovery={stats={x=10}}
        f.scripts.OnEvent(f,'PLAYER_REGEN_ENABLED')
        assert(f.restoreButton.enabled)
        f.laterButton.scripts.OnClick();assert(not f:IsShown())
        ns:ShowRecoveryReminder();assert(f:IsShown())
        combat=true;f.scripts.OnEvent(f,'PLAYER_REGEN_DISABLED')
        assert(not f.saveButton.enabled and not f.restoreButton.enabled)
        f.saveButton.scripts.OnClick();assert(saves==0)
        combat=false;f.scripts.OnEvent(f,'PLAYER_REGEN_ENABLED')
        saveOK=false;f.saveButton.scripts.OnClick();assert(reloads==0)
        saveOK=true;f.saveButton.scripts.OnClick();assert(reloads==1)
        ZoidsTools_FRecoveryService.GetPresetSaveWarning=function()return 'Outdated Recovery' end
        f.saveButton.scripts.OnClick();assert(reloads==1 and saves==2)
        f.restoreButton.scripts.OnClick();assert(restores==1)
    """)
    print('PASS: reminder does not auto-save/restore, Later dismisses, absent preset disables restore, combat guards and failed-save reload prevention')
