local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
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
    Check("enabled", L["Enable window movement"], L["Drag the Move handle on supported Blizzard windows. Changes made in combat apply when combat ends."], 0)
    Check("moveBags", L["Move bags"], L["Move individual bags and the combined backpack using their title handles."], -38)
    Check("showBagHandles", L["Show bag move handles"], L["Hide handles to keep bags in place without an extra drag area."], -76)
    Check("savePositions", L["Remember window positions"], L["Restore moved windows and bags when reopened and after reloading. Turning this off keeps saved positions for later."], -114)
    Check("scaleEnabled", L["Ctrl + mouse wheel to scale"], L["Hold Ctrl and scroll over a window or its Move handle. Scales are saved independently of positions."], -152)

    local corner = UI.CreateDropdown(page, "Bag anchor corner", "Open a bag to change its corner without moving it. Solo bags share this position; multiple bags keep Blizzard's stacking.", {
        {value="BOTTOMRIGHT",text="Bottom right"}, {value="BOTTOMLEFT",text="Bottom left"},
        {value="TOPRIGHT",text="Top right"}, {value="TOPLEFT",text="Top left"},
    }, function() return ns:GetBagAnchorCorner() end,
    function(value) ns:SetBagAnchorCorner(value) end, 210)
    corner:SetPoint("TOPLEFT", 0, -196)
    local resetPositions = UI.CreateButton(page, L["Reset all positions"], 190, 30)
    resetPositions:SetPoint("TOPLEFT", 0, -272)
    resetPositions:SetScript("OnClick", function() ns:ResetMovableWindowPositions(); page:Refresh() end)
    local resetScales = UI.CreateButton(page, L["Reset all scales"], 190, 30)
    resetScales:SetPoint("LEFT", resetPositions, "RIGHT", 12, 0)
    resetScales:SetScript("OnClick", function() ns:ResetMovableWindowScales(); page:Refresh() end)

    local instructions = UI.CreateBodyText(page,
        L["Drag a bag's Move handle to set its position. Ctrl + wheel scales; Ctrl + right-click resets."], 510)
    instructions:SetPoint("TOPLEFT", 0, -318)
    local status = UI.CreateBodyText(page, "", 510)
    status:SetPoint("TOPLEFT", 0, -376)

    function page:Refresh()
        for index, control in ipairs(controls) do
            control:Refresh()
            UI.SetControlEnabled(control, index == 1 or ns.db.windows.enabled)
        end
        UI.SetControlEnabled(controls[3], ns.db.windows.enabled and ns.db.windows.moveBags)
        corner:Refresh()
        local combat = InCombatLockdown()
        UI.SetControlEnabled(corner, not combat and ns.db.windows.enabled and ns.db.windows.moveBags)
        UI.SetControlEnabled(resetPositions, not combat)
        UI.SetControlEnabled(resetScales, not combat)
        local windows, bags, scales = ns:GetMovableWindowStats()
        local anchor = ns.db.windows.bagAnchor
        status:SetText(combat and L["Movement is paused during combat. Changes apply after combat."]
            or (anchor and string.format(L["Bag position saved: %s (%.0f, %.0f)."], anchor.point, anchor.x, anchor.y))
            or string.format(L["Detected: %d windows, %d bags. Saved scales: %d.\nMore windows are detected as you open them."], windows, bags, scales))
    end
    page:RegisterEvent("PLAYER_REGEN_DISABLED")
    page:RegisterEvent("PLAYER_REGEN_ENABLED")
    page:SetScript("OnEvent", function(self) if self:IsShown() then self:Refresh() end end)
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
