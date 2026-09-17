local combat, editMode, casting, channeling = false, false, false, false
local eventFrame
function InCombatLockdown() return combat end
function UnitCastingInfo() if casting then return 'Spell' end end
function UnitChannelInfo() if channeling then return 'Channel' end end
EditModeManagerFrame = { scripts = {} }
function EditModeManagerFrame:IsEditModeActive() return editMode end
function EditModeManagerFrame:HookScript(event, fn) self.scripts[event] = fn end
function CreateFrame()
    eventFrame = {}
    function eventFrame:RegisterEvent() end
    function eventFrame:SetScript(_, fn) self.handler = fn end
    return eventFrame
end
local function Bar()
    local bar = { width = 195, height = 16, scripts = {}, shown = false, parentShown = true }
    local text = { font = 'font.ttf', size = 12, flags = 'OUTLINE', width = 180, height = 12,
        horizontal = 'LEFT', vertical = 'TOP', wrap = true,
        points = { { 'TOP', bar, 'BOTTOM', 0, -2 } } }
    function text:GetFont() return self.font, self.size, self.flags end
    function text:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function text:GetSize() return self.width, self.height end
    function text:SetSize(w, h) self.width, self.height = w, h end
    function text:GetNumPoints() return #self.points end
    function text:GetPoint(i) return unpack(self.points[i]) end
    function text:ClearAllPoints() self.points = {} end
    function text:SetPoint(...) self.points[#self.points + 1] = {...} end
    function text:GetJustifyH() return self.horizontal end
    function text:GetJustifyV() return self.vertical end
    function text:SetJustifyH(v) self.horizontal = v end
    function text:SetJustifyV(v) self.vertical = v end
    function text:CanWordWrap() return self.wrap end
    function text:SetWordWrap(v) self.wrap = v end
    function text:GetText() error('Must not inspect restricted spell names') end
    function text:GetStringWidth() error('Must not measure restricted spell names') end
    bar.Text = text
    function bar:GetSize() return self.width, self.height end
    function bar:SetSize(w, h)
        assert(not combat, 'Changed geometry during combat')
        self.width, self.height = w, h
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged() end
    end
    function bar:HookScript(event, fn) self.scripts[event] = fn end
    function bar:GetParent() return { IsShown = function() return self.parentShown end } end
    function bar:UpdateShownState() self.shown = self.isInEditMode or casting or channeling or false end
    function bar:OnEvent() self:UpdateShownState() end
    return bar
end
PlayerCastingBarFrame = Bar()
TargetFrameSpellBar = Bar()
FocusFrameSpellBar = Bar()
function RunCastbarTests(ns)
    ns:InitializeCastbars()
    local bar = PlayerCastingBarFrame
    assert(ns:SetCastbarSetting('player', 'enabled', true))
    ns:SetCastbarSetting('player', 'width', 300)
    ns:SetCastbarSetting('player', 'height', 25)
    assert(bar.width == 300 and bar.height == 25)
    assert(bar.Text.horizontal == 'CENTER' and bar.Text.vertical == 'MIDDLE')
    assert(bar.Text.points[1][1] == 'CENTER' and bar.Text.points[1][2] == bar)
    assert(bar.Text.points[1][4] == 0 and bar.Text.points[1][5] == 0)
    assert(bar.Text.size == 18 and bar.Text.width < bar.width and not bar.Text.wrap)
    ns:SetCastbarSetting('player', 'width', 120)
    ns:SetCastbarSetting('player', 'height', 8)
    assert(bar.Text.size == 6 and bar.Text.width == 112 and bar.Text.height == 8)
    ns:SetCastbarSetting('player', 'width', 300)
    ns:SetCastbarSetting('player', 'height', 25)
    bar.CastTimeText = { IsShown = function() return true end, GetWidth = function() return 30 end }
    ns:RefreshCastbars()
    assert(bar.Text.width == 232 and bar.Text.points[1][4] == 0)
    assert(ns:StartCastbarPreview('player'))
    assert(bar.isInEditMode and bar.shown and not editMode)
    assert(not TargetFrameSpellBar.shown and not FocusFrameSpellBar.shown)
    ns:SetCastbarSetting('player', 'width', 350)
    assert(bar.width == 350)
    ns:StopCastbarPreview()
    assert(bar.isInEditMode == nil and not bar.shown)
    ns:StartCastbarPreview('player')
    casting = true
    eventFrame.handler(eventFrame, 'UNIT_SPELLCAST_START', 'player')
    assert(not ns:IsCastbarPreviewActive() and bar.shown)
    assert(not ns:StartCastbarPreview('player'))
    casting = false
    ns:StartCastbarPreview('player')
    channeling = true
    eventFrame.handler(eventFrame, 'UNIT_SPELLCAST_CHANNEL_START', 'player')
    assert(not ns:IsCastbarPreviewActive() and bar.shown)
    channeling = false
    TargetFrameSpellBar.parentShown = false
    assert(not ns:StartCastbarPreview('target'))
    TargetFrameSpellBar.parentShown = true
    assert(ns:StartCastbarPreview('target'))
    assert(ns:StartCastbarPreview('focus'))
    assert(not TargetFrameSpellBar.isInEditMode and FocusFrameSpellBar.isInEditMode)
    eventFrame.handler(eventFrame, 'PLAYER_FOCUS_CHANGED')
    assert(not ns:IsCastbarPreviewActive())
    local method = FocusFrameSpellBar.UpdateShownState
    FocusFrameSpellBar.UpdateShownState = nil
    assert(not ns:StartCastbarPreview('focus'))
    FocusFrameSpellBar.UpdateShownState = function() error('beta API failure') end
    assert(not ns:StartCastbarPreview('focus'))
    assert(not FocusFrameSpellBar.isInEditMode and not ns:IsCastbarPreviewActive())
    FocusFrameSpellBar.UpdateShownState = method
    ns:StartCastbarPreview('player')
    combat = true
    eventFrame.handler(eventFrame, 'PLAYER_REGEN_DISABLED')
    assert(not ns:IsCastbarPreviewActive() and not bar.isInEditMode)
    assert(not ns:SetCastbarSetting('player', 'width', 200))
    assert(not ns:StartCastbarPreview('player'))
    combat = false
    eventFrame.handler(eventFrame, 'PLAYER_REGEN_ENABLED')
    assert(not bar.shown)
    ns:StartCastbarPreview('player')
    editMode = true
    EditModeManagerFrame.scripts.OnShow()
    assert(not ns:IsCastbarPreviewActive() and bar.isInEditMode)
    assert(not ns:StartCastbarPreview('player'))
    assert(not ns:SetCastbarSetting('player', 'height', 20))
    editMode = false
    bar.isInEditMode = nil
    ns:StartCastbarPreview('target')
    editMode = true
    EditModeManagerFrame.scripts.OnShow()
    assert(not TargetFrameSpellBar.isInEditMode and not ns:IsCastbarPreviewActive())
    editMode = false
    ns:SetCastbarSetting('player', 'enabled', false)
    assert(bar.width == 195 and bar.height == 16)
    assert(bar.Text.size == 12 and bar.Text.font == 'font.ttf' and bar.Text.flags == 'OUTLINE')
    assert(bar.Text.width == 180 and bar.Text.height == 12 and bar.Text.wrap)
    assert(bar.Text.horizontal == 'LEFT' and bar.Text.vertical == 'TOP')
    assert(bar.Text.points[1][1] == 'TOP' and bar.Text.points[1][3] == 'BOTTOM' and bar.Text.points[1][5] == -2)
    ns:SetCastbarSetting('target', 'width', 999)
    assert(ns:GetCastbarSettings('target').width == 420)
end
