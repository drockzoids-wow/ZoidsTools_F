local _, ns = ...
local paths = {
    player = { "PlayerCastingBarFrame", "CastingBarFrame" },
    target = { "TargetFrameSpellBar", "TargetFrame.spellbar", "TargetFrame.SpellBar" },
    focus = { "FocusFrameSpellBar", "FocusFrame.spellbar", "FocusFrame.SpellBar" },
}
local originals, hooks = {}, {}
local preview, events, applying = nil, nil, false
local pendingVisibility = {}

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function Resolve(key)
    for _, path in ipairs(paths[key] or {}) do
        local current = _G
        for name in path:gmatch("[^.]+") do current = current and current[name] end
        if current then return current end
    end
end

local function Accessible(bar)
    if not bar then return false end
    if bar.CanBeAccessedInContext then
        local ok, value = pcall(bar.CanBeAccessedInContext, bar)
        if not ok or Secret(value) or not value then return false end
    end
    return true
end

local function FullEditMode()
    local manager = EditModeManagerFrame
    return manager and manager.IsEditModeActive and manager:IsEditModeActive()
end

local function NotifyUI()
    if ns.UI and ns.UI.RefreshVisiblePage then ns.UI.RefreshVisiblePage() end
end

function ns:GetCastbarSettings(key)
    return self.db and self.db.castbars and self.db.castbars[key]
end

local function SpellText(bar)
    return bar.Text or bar.text or (bar.GetName and _G[(bar:GetName() or "") .. "Text"])
end

local function SaveSpellText(bar, state)
    local text = SpellText(bar)
    if state.text or not Accessible(text) or not text.GetFont then return end
    local font, size, flags = text:GetFont()
    local width, height = text:GetSize()
    if not font or Secret(size) or Secret(width) or Secret(height) then return end
    local saved = {
        frame = text, font = font, size = size, flags = flags,
        width = width, height = height, points = {},
        horizontal = text:GetJustifyH(), vertical = text:GetJustifyV(),
        wrap = text.CanWordWrap and text:CanWordWrap(),
    }
    for index = 1, text:GetNumPoints() do
        saved.points[index] = { text:GetPoint(index) }
    end
    state.text = saved
end

local function LayoutSpellText(bar, state, width, height)
    SaveSpellText(bar, state)
    local saved = state.text
    if not saved or not Accessible(saved.frame) then return end
    local text = saved.frame
    -- Keep the label centered on the bar even when a timer occupies one side.
    local inset = math.max(4, math.min(10, height * 0.3))
    local timer = bar.CastTimeText
    if Accessible(timer) and timer.IsShown and timer:IsShown() and timer.GetWidth then
        local timerWidth = timer:GetWidth()
        if not Secret(timerWidth) and type(timerWidth) == "number" then
            inset = math.max(inset, math.min(width * 0.3, timerWidth + 4))
        end
    end
    local textWidth = math.max(1, width - 2 * inset)
    local fontSize = math.max(6, math.min(20, math.floor(height * 0.72), math.floor(textWidth / 10)))
    text:ClearAllPoints()
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetSize(textWidth, height)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetFont(saved.font, fontSize, saved.flags)
    -- Do not read or measure spell names: they may be secret during combat.
    -- Blizzard's single-line FontString clips/truncates names within these bounds.
end

local function RestoreSpellText(state)
    local saved = state and state.text
    if not saved or not Accessible(saved.frame) then return end
    local text = saved.frame
    text:ClearAllPoints()
    text:SetSize(saved.width, saved.height)
    for _, point in ipairs(saved.points) do text:SetPoint(unpack(point)) end
    text:SetFont(saved.font, saved.size, saved.flags)
    text:SetJustifyH(saved.horizontal)
    text:SetJustifyV(saved.vertical)
    if saved.wrap ~= nil then text:SetWordWrap(saved.wrap) end
end

local function Apply(key)
    if applying or InCombat() or FullEditMode() then return end
    local bar, db = Resolve(key), ns:GetCastbarSettings(key)
    if not db or not Accessible(bar) or not bar.SetSize or not bar.GetSize then return end
    if not originals[bar] and db.enabled then
        local width, height = bar:GetSize()
        if Secret(width) or Secret(height) or not width or not height then return end
        originals[bar] = { width, height }
    end
    local width, height
    if db.enabled then
        width, height = db.width, db.height
    elseif originals[bar] then
        width, height = unpack(originals[bar])
    else
        return
    end
    applying = true
    local ok = pcall(bar.SetSize, bar, width, height)
    if ok then
        if db.enabled then
            ok = pcall(LayoutSpellText, bar, originals[bar], width, height)
        else
            ok = pcall(RestoreSpellText, originals[bar])
        end
    end
    applying = false
    if ok and not db.enabled then originals[bar] = nil end
end

function ns:RefreshCastbars()
    if InCombat() then return end
    for key in pairs(paths) do
        local bar = Resolve(key)
        if Accessible(bar) and not hooks[bar] and bar.HookScript then
            hooks[bar] = true
            local frameKey = key
            bar:HookScript("OnShow", function() Apply(frameKey) end)
            bar:HookScript("OnSizeChanged", function() Apply(frameKey) end)
        end
        Apply(key)
    end
end

function ns:SetCastbarSetting(key, setting, value)
    local db = self:GetCastbarSettings(key)
    if not db or InCombat() or FullEditMode() then return false end
    if setting == "enabled" then
        db.enabled = value == true
    elseif setting == "width" then
        db.width = math.max(120, math.min(420, tonumber(value) or 195))
    elseif setting == "height" then
        db.height = math.max(8, math.min(40, tonumber(value) or 16))
    else
        return false
    end
    self:RefreshCastbars()
    return true
end

function ns:IsCastbarPreviewActive(key)
    return preview ~= nil and (key == nil or preview.key == key)
end

function ns:StopCastbarPreview()
    if not preview then return true end
    local state = preview
    local bar = state.bar
    if state.key == "player" and FullEditMode() then
        preview = nil -- Blizzard now owns the flag and visibility.
        NotifyUI()
        return true
    end
    if not Accessible(bar) then
        state.stopPending = true
        return false
    end
    -- Only the local visibility flag is borrowed. Do not call the global
    -- manager, select a system, or change the user's Edit Mode layout.
    bar.isInEditMode = state.wasEditing
    preview = nil
    if not InCombat() then
        local refreshed = bar.OnEvent and pcall(bar.OnEvent, bar, "PLAYER_ENTERING_WORLD")
        if not refreshed then pcall(bar.UpdateShownState, bar) end
    else
        pendingVisibility[bar] = true
    end
    NotifyUI()
    return true
end

function ns:StartCastbarPreview(key)
    if not paths[key] then return false, "Unknown castbar." end
    if InCombat() then return false, "Preview is available outside combat." end
    if FullEditMode() then return false, "Close Blizzard Edit Mode first." end
    if not self:StopCastbarPreview() then return false, "The previous preview is waiting for access to its frame." end
    local bar = Resolve(key)
    if not Accessible(bar) or type(bar.UpdateShownState) ~= "function" then
        return false, "This castbar does not expose Blizzard's Edit Mode preview on this client."
    end
    if Secret(bar.isInEditMode) or bar.isInEditMode then return false, "This castbar is already being edited." end
    if (bar.GetParent and bar:GetParent() and not bar:GetParent():IsShown()) then
        return false, "Show the target or focus frame before previewing its castbar."
    end
    for _, api in ipairs({ "UnitCastingInfo", "UnitChannelInfo" }) do
        if type(_G[api]) == "function" then
            local name = _G[api](key)
            if Secret(name) or name then return false, "Wait for the current cast or channel to finish." end
        end
    end
    preview = { key = key, bar = bar, wasEditing = bar.isInEditMode }
    bar.isInEditMode = true
    local ok = pcall(bar.UpdateShownState, bar)
    if not ok then
        self:StopCastbarPreview()
        return false, "The beta client could not show its native castbar preview."
    end
    self:RefreshCastbars()
    NotifyUI()
    return true
end

function ns:CanCustomizeCastbars()
    return not InCombat() and not FullEditMode()
end

local editModeHooked
local function HookEditMode()
    if editModeHooked or not EditModeManagerFrame or not EditModeManagerFrame.HookScript then return end
    editModeHooked = true
    -- Once Blizzard owns Edit Mode, relinquish our preview without resetting
    -- its flag, selection, or account settings.
    EditModeManagerFrame:HookScript("OnShow", function() ns:StopCastbarPreview(); NotifyUI() end)
    EditModeManagerFrame:HookScript("OnHide", function()
        if C_Timer and C_Timer.After then C_Timer.After(0, function() ns:RefreshCastbars(); NotifyUI() end) end
    end)
end

function ns:InitializeCastbars()
    if events then return end
    events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_EMPOWER_START", "UNIT_ENTERED_VEHICLE" }) do
        ns:RegisterCompatibleEvent(events, event)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if preview then
            local shouldStop = event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_WORLD"
                or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
                or (not Secret(unit) and unit == preview.key)
                or preview.stopPending
            if shouldStop then ns:StopCastbarPreview() end
        end
        if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
            if not InCombat() and not FullEditMode() then
                for bar in pairs(pendingVisibility) do
                    if Accessible(bar) then
                        local refreshed = bar.OnEvent and pcall(bar.OnEvent, bar, "PLAYER_ENTERING_WORLD")
                        if not refreshed then pcall(bar.UpdateShownState, bar) end
                        pendingVisibility[bar] = nil
                    end
                end
            end
            HookEditMode()
            ns:RefreshCastbars()
        end
        NotifyUI()
    end)
    HookEditMode()
    self:RefreshCastbars()
end
