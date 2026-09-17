local _, ns = ...
local UI = ns.UI

function UI.CreateWindowsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local controls = {}
    local function Check(key, label, tooltip, y)
        local control = UI.CreateCheckbox(page, label, tooltip,
            function() return ns.db.windows[key] end,
            function(value)
                ns.db.windows[key] = value
                ns:RefreshMovableWindows()
            end)
        control:SetPoint("TOPLEFT", 0, y)
        controls[#controls + 1] = control
    end
    Check("enabled", "Enable window movement", "Drag the Move handle on supported Blizzard windows. Changes made in combat apply when combat ends.", 0)
    Check("moveBags", "Move bags", "Move individual bags and the combined backpack using their title handles.", -38)
    Check("showBagHandles", "Show bag move handles", "Hide handles to keep bags in place without an extra drag area.", -76)
    Check("savePositions", "Remember window positions", "Restore moved windows and bags when reopened and after reloading. Turning this off keeps saved positions for later.", -114)
    Check("scaleEnabled", "Ctrl + mouse wheel to scale", "Hold Ctrl and scroll over a window or its Move handle. Scales are saved independently of positions.", -152)

    local resetPositions = UI.CreateButton(page, "Reset all positions", 190, 30)
    resetPositions:SetPoint("TOPLEFT", 0, -210)
    resetPositions:SetScript("OnClick", function() ns:ResetMovableWindowPositions(); page:Refresh() end)
    local resetScales = UI.CreateButton(page, "Reset all scales", 190, 30)
    resetScales:SetPoint("LEFT", resetPositions, "RIGHT", 12, 0)
    resetScales:SetScript("OnClick", function() ns:ResetMovableWindowScales(); page:Refresh() end)

    local instructions = UI.CreateBodyText(page,
        "Drag the Move handle at the top of a window or bag.\n\nCtrl + mouse wheel: adjust size (60% to 180%).\nCtrl + right-click a Move handle: reset its position.\n\nMove the windowed world map by its title bar; it uses WoW's own position saving and does not support scaling.\n\nAs in retail, protected frames such as the flight map and guild controls stay under Blizzard's control. Action bars, unit frames, and third-party bag replacements are outside this mover's scope.", 510)
    instructions:SetPoint("TOPLEFT", 0, -264)
    local status = UI.CreateBodyText(page, "", 510)
    status:SetPoint("TOPLEFT", 0, -440)

    function page:Refresh()
        for index, control in ipairs(controls) do
            control:Refresh()
            UI.SetControlEnabled(control, index == 1 or ns.db.windows.enabled)
        end
        UI.SetControlEnabled(controls[3], ns.db.windows.enabled and ns.db.windows.moveBags)
        local combat = InCombatLockdown()
        UI.SetControlEnabled(resetPositions, not combat)
        UI.SetControlEnabled(resetScales, not combat)
        local windows, bags, scales = ns:GetMovableWindowStats()
        status:SetText(combat and "Movement is paused during combat. Changes apply after combat."
            or string.format("Detected: %d windows, %d bags. Saved scales: %d.\nMore windows are detected as you open them.", windows, bags, scales))
    end
    page:RegisterEvent("PLAYER_REGEN_DISABLED")
    page:RegisterEvent("PLAYER_REGEN_ENABLED")
    page:SetScript("OnEvent", function(self) if self:IsShown() then self:Refresh() end end)
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
