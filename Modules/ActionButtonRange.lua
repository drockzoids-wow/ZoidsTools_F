local _, ns = ...
local eventFrame
local overlays = {}
local nativeRange = {}
local rangeHookInstalled = false
local groups = {
    { "ActionButton", 12 }, { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 }, { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 }, { "MultiBar5Button", 12 },
    { "MultiBar6Button", 12 }, { "MultiBar7Button", 12 },
    { "OverrideActionBarButton", 6 }, { "VehicleMenuBarActionButton", 6 },
    { "ExtraActionButton", 1 },
}

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not IsSecret(value) then return value end
end

local function API(name)
    return (C_ActionBar and C_ActionBar[name]) or _G[name]
end

local function IsOutOfRange(button)
    local action = button.action
    if IsSecret(action) then return false end
    if action == nil then action = Read(button.GetAttribute, button, "action") end
    if type(action) ~= "number" or action <= 0 then return false end
    local native = nativeRange[button]
    if native and native.action == action then return native.outOfRange end
    local hasAction = Read(API("HasAction"), action)
    if hasAction ~= true and hasAction ~= 1 then return false end
    local hasRange = API("HasRangeRequirements") or _G.ActionHasRange
    if hasRange then
        local checksRange = Read(hasRange, action)
        if checksRange ~= true and checksRange ~= 1 then return false end
    end
    local inRange = Read(API("IsActionInRange"), action)
    return inRange == false or inRange == 0
end

function ns:GetActionButtonRangeTintEnabled()
    return self.db and self.db.actionBars and self.db.actionBars.rangeTint == true
end

local function InstallRangeHook()
    if rangeHookInstalled or type(hooksecurefunc) ~= "function"
        or type(ActionButton_UpdateRangeIndicator) ~= "function" then return end
    -- Run in the same update as Blizzard's keybind color, using its exact range result.
    hooksecurefunc("ActionButton_UpdateRangeIndicator", function(button, checksRange, inRange)
        if IsSecret(button) or not button then return end
        local overlay = overlays[button]
        if not overlay then return end
        local action = button.action
        if IsSecret(action) then
            nativeRange[button] = nil
            overlay:Hide()
            return
        end
        if action == nil then action = Read(button.GetAttribute, button, "action") end
        local outOfRange = not IsSecret(checksRange) and not IsSecret(inRange)
            and (checksRange == true or checksRange == 1) and (inRange == false or inRange == 0)
        if type(action) == "number" and action > 0 then
            nativeRange[button] = { action = action, outOfRange = outOfRange }
        else
            nativeRange[button] = nil
            outOfRange = false
        end
        overlay:SetShown(ns:GetActionButtonRangeTintEnabled() == true
            and Read(button.IsShown, button) == true and outOfRange)
    end)
    rangeHookInstalled = true
end

function ns:RefreshActionButtonRangeTint()
    InstallRangeHook()
    local enabled = self:GetActionButtonRangeTintEnabled()
    local inCombat = InCombatLockdown and InCombatLockdown()
    for _, group in ipairs(groups) do
        for index = 1, group[2] do
            local button = _G[group[1] .. index]
            if button then
                local overlay = overlays[button]
                -- Create regions before combat; existing regions can change visibility in combat.
                if enabled and not overlay and not inCombat and button.CreateTexture then
                    local icon = button.icon or button.Icon or _G[group[1] .. index .. "Icon"]
                    if icon then
                        overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
                        overlay:SetAllPoints(icon)
                        overlay:SetColorTexture(1, 0.05, 0.05, 0.42)
                        overlay:SetBlendMode("BLEND")
                        overlay:Hide()
                        overlays[button] = overlay
                    end
                end
                if overlay then
                    local shown = enabled and Read(button.IsShown, button) == true and IsOutOfRange(button)
                    overlay:SetShown(shown == true)
                end
            end
        end
    end
end

function ns:SetActionButtonRangeTintEnabled(value)
    if self.db and self.db.actionBars then self.db.actionBars.rangeTint = value == true end
    self:RefreshActionButtonRangeTint()
end

function ns:InitializeActionButtonRange()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_PAGE_CHANGED", "UPDATE_SHAPESHIFT_FORM", "UPDATE_VEHICLE_ACTIONBAR",
        "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    eventFrame:SetScript("OnEvent", function(_, event)
        if event ~= "ADDON_LOADED" and event ~= "PLAYER_REGEN_ENABLED" then
            nativeRange = {}
        end
        self:RefreshActionButtonRangeTint()
    end)
    local elapsedTime = 0
    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        if not self:GetActionButtonRangeTintEnabled() then return end
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.15 then return end
        elapsedTime = 0
        self:RefreshActionButtonRangeTint()
    end)
    self:RefreshActionButtonRangeTint()
end
