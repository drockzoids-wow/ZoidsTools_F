local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local UI, Theme = ns.UI, ns.UI.Theme
ns.UI2 = {}
local window

local function BuildWindow()
    if window then return window end
    local frame = CreateFrame("Frame", "ZoidsTools_FSettings", UIParent, "BackdropTemplate")
    window = frame
    frame:SetSize(740, 598)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.ui.window = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    local position = ns.db.ui.window
    if position then
        frame:ClearAllPoints()
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    end
    frame:SetFrameStrata("DIALOG")
    Theme.ApplyPanelBackdrop(frame)
    table.insert(UISpecialFrames, "ZoidsTools_FSettings")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -24)
    title:SetText(ns.title)
    title:SetTextColor(unpack(Theme.colors.gold))
    local subtitle = UI.CreateBodyText(frame, L["FOREVER BETA  /  DAMAGE METERS"], 650)
    subtitle:SetPoint("TOPLEFT", 24, -52)

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 16, -82)
    sidebar:SetPoint("BOTTOMLEFT", 16, 16)
    sidebar:SetWidth(142)
    Theme.ApplySoftBackdrop(sidebar)
    local selected = UI.CreateButton(sidebar, L["Damage Meters"], 126, 28)
    selected:SetPoint("TOPLEFT", 8, -12)
    selected:SetStyledSelected(true)
    local windowsButton = UI.CreateButton(sidebar, L["Windows & Bags"], 126, 28)
    windowsButton:SetPoint("TOPLEFT", 8, -48)
    local unitFramesButton = UI.CreateButton(sidebar, L["Unit Frames"], 126, 28)
    unitFramesButton:SetPoint("TOPLEFT", 8, -84)
    local castbarsButton = UI.CreateButton(sidebar, L["Castbars"], 126, 28)
    castbarsButton:SetPoint("TOPLEFT", 8, -120)
    local vendorButton = UI.CreateButton(sidebar, L["Vendor"], 126, 28)
    vendorButton:SetPoint("TOPLEFT", 8, -156)
    local tooltipsButton = UI.CreateButton(sidebar, L["Tooltips"], 126, 28)
    tooltipsButton:SetPoint("TOPLEFT", 8, -192)
    local lootButton = UI.CreateButton(sidebar, L["Loot"], 126, 28)
    lootButton:SetPoint("TOPLEFT", 8, -228)
    local questsButton = UI.CreateButton(sidebar, L["Quests"], 126, 28)
    questsButton:SetPoint("TOPLEFT", 8, -264)
    local actionBarsButton = UI.CreateButton(sidebar, L["Action Bars"], 126, 28)
    actionBarsButton:SetPoint("TOPLEFT", 8, -300)
    local statsButton = UI.CreateButton(sidebar, L["Stats"], 126, 28)
    statsButton:SetPoint("TOPLEFT", 8, -336)
    local macrosButton = UI.CreateButton(sidebar, L["Macros"], 126, 28)
    macrosButton:SetPoint("TOPLEFT", 8, -372)
    local completionistButton = UI.CreateButton(sidebar, "Completionist", 126, 28)
    completionistButton:SetPoint("TOPLEFT", 8, -408)
    local note = UI.CreateBodyText(sidebar, "v" .. ns.version, 116)
    note:SetPoint("TOPLEFT", 12, -464)

    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local controls = {}
    local function Check(label, tip, getter, setter, y)
        local c = UI.CreateCheckbox(page, label, tip, getter, setter)
        c:SetPoint("TOPLEFT", 0, y)
        controls[#controls + 1] = c
    end
    Check(L["Enable ZoidsTools meters"], L["Uses Blizzard's meter API. Enabling this hides Blizzard's meter windows."],
        function() return ns:GetCustomDamageMeterEnabled() end,
        function(v) ns:SetCustomDamageMeterEnabled(v) end, 0)
    Check(L["Show second meter"], L["Choose damage, healing, or another available type from each meter's title."],
        function() return ns:GetCustomDamageMeterSecondWindowEnabled() end,
        function(v) ns:SetCustomDamageMeterSecondWindowEnabled(v) end, -34)
    Check(L["Class-colored borders"], L["Use your class color for the meter borders."],
        function() return ns:GetCustomDamageMeterClassColoredBorder() end,
        function(v) ns:SetCustomDamageMeterClassColoredBorder(v) end, -68)
    Check(L["Show minimap button"], L["Open settings from the minimap."],
        function() return ns.db.ui.minimap.show end,
        function(v) ns:SetMinimapShown(v) end, -102)
    local minimapSettings = UI.CreateButton(page, L["Minimap options"], 180, 26)
    minimapSettings:SetPoint("TOPLEFT", 278, -102)
    minimapSettings:SetScript("OnClick", function() ns:ShowMinimapSettings() end)

    local function Slider(label, min, max, step, getter, setter, x, y, format)
        local c = UI.CreateSlider(page, label, nil, min, max, step, getter, setter, 220, format)
        c:SetPoint("TOPLEFT", x, y)
        controls[#controls + 1] = c
    end
    Slider(L["Text size"], 0.8, 1.5, 0.05,
        function() return ns:GetCustomDamageMeterTextScale() end,
        function(v) ns:SetCustomDamageMeterTextScale(v) end, 8, -164,
        function(v) return string.format("%d%%", v * 100 + 0.5) end)
    Slider(L["Background"], 0, 1, 0.05,
        function() return ns:GetCustomDamageMeterBackgroundOpacity() end,
        function(v) ns:SetCustomDamageMeterBackgroundOpacity(v) end, 278, -164,
        function(v) return string.format("%d%%", v * 100 + 0.5) end)
    Slider(L["Snap gap"], 0, 24, 1,
        function() return ns:GetCustomDamageMeterSnapGap() end,
        function(v) ns:SetCustomDamageMeterSnapGap(v) end, 8, -218)

    local preview = UI.CreateButton(page, L["Preview / Move"], 160, 30)
    preview:SetPoint("TOPLEFT", 0, -260)
    preview:SetScript("OnClick", function() ns:ToggleCustomDamageMeterMoveMode(); page:Refresh() end)
    local reset = UI.CreateButton(page, L["Reset position"], 160, 30)
    reset:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    reset:SetScript("OnClick", function() ns:ResetCustomDamageMeterPosition() end)
    local save = UI.CreateButton(page, L["Save layout"], 160, 30)
    save:SetPoint("TOPLEFT", 0, -300)
    save:SetScript("OnClick", function()
        ns.db.layouts.saved = ns:CaptureCustomDamageMeterLayout()
        ns:Print(L["Meter layout saved for all characters."])
        page:Refresh()
    end)
    local restore = UI.CreateButton(page, L["Restore layout"], 160, 30)
    restore:SetPoint("LEFT", save, "RIGHT", 10, 0)
    restore:SetScript("OnClick", function() ns:ApplyCustomDamageMeterLayout(ns.db.layouts.saved) end)
    local instructions = UI.CreateBodyText(page,
        L["Use each meter's title to select its type, and its segment menu for current, overall, or recent fights. Click a player for details. Preview / Move unlocks dragging and resizing and displays sample data."], 510)
    instructions:SetPoint("TOPLEFT", 0, -347)
    local status = UI.CreateBodyText(page, "", 510)
    status:SetPoint("TOPLEFT", 0, -416)
    function page:Refresh()
        for _, control in ipairs(controls) do control:Refresh() end
        preview:SetText(ns:IsCustomDamageMeterMoveMode() and L["Lock meters"] or L["Preview / Move"])
        UI.SetControlEnabled(restore, type(ns.db.layouts.saved) == "table")
        status:SetText(ns:GetCompatibilityStatus())
    end
    local windowsPage = UI.CreateWindowsPage(frame)
    local unitFramesPage = UI.CreateUnitFramesPage(frame)
    local castbarsPage = UI.CreateCastbarsPage(frame)
    local vendorPage = UI.CreateVendorPage(frame)
    local tooltipsPage = UI.CreateTooltipsPage(frame)
    local lootPage = UI.CreateLootPage(frame)
    local questsPage = UI.CreateQuestsPage(frame)
    local actionBarsPage = UI.CreateActionBarsPage(frame)
    local statsPage = UI.CreateStatsPage(frame)
    local macrosPage = UI.CreateMacrosPage(frame)
    local completionistPage = UI.CreateCompletionistPage(frame)
    -- Translated paragraphs and navigation labels need more room than English.
    if ns.locale and ns.locale ~= "enUS" then
        frame:SetWidth(900)
        sidebar:SetWidth(180)
        for _, button in ipairs({ selected, windowsButton, unitFramesButton, castbarsButton,
            vendorButton, tooltipsButton, lootButton, questsButton, actionBarsButton, statsButton, macrosButton, completionistButton }) do
            button:SetWidth(164)
            button.text:SetWidth(148)
        end
        for _, content in ipairs({ page, windowsPage, unitFramesPage, castbarsPage, vendorPage,
            tooltipsPage, lootPage, questsPage, actionBarsPage, statsPage, macrosPage, completionistPage }) do
            content:ClearAllPoints()
            content:SetPoint("TOPLEFT", 218, -90)
            content:SetWidth(650)
            for _, region in ipairs({ content:GetRegions() }) do
                if region:IsObjectType("FontString") and region:GetWidth() >= 500 then
                    region:SetWidth(630)
                end
            end
        end
    end
    local activePage = page
    function frame:SelectPage(key)
        local isWindows = key == "windows" or key == "bags"
        local isUnitFrames = key == "unitframes"
        local isCastbars = key == "castbars"
        local isVendor = key == "vendor"
        local isTooltips = key == "tooltips"
        local isLoot = key == "loot"
        local isQuests = key == "quests"
        local isActionBars = key == "actionbars"
        local isStats = key == "stats"
        local isMacros = key == "macros"
        local isCompletionist = key == "completionist"
        activePage = isVendor and vendorPage or (isCastbars and castbarsPage or (isUnitFrames and unitFramesPage or (isWindows and windowsPage or page)))
        if isTooltips then activePage = tooltipsPage end
        if isLoot then activePage = lootPage end
        if isQuests then activePage = questsPage end
        if isActionBars then activePage = actionBarsPage end
        if isStats then activePage = statsPage end
        if isMacros then activePage = macrosPage end
        if isCompletionist then activePage = completionistPage end
        page:SetShown(activePage == page)
        windowsPage:SetShown(isWindows)
        unitFramesPage:SetShown(isUnitFrames)
        castbarsPage:SetShown(isCastbars)
        vendorPage:SetShown(isVendor)
        tooltipsPage:SetShown(isTooltips)
        lootPage:SetShown(isLoot)
        questsPage:SetShown(isQuests)
        actionBarsPage:SetShown(isActionBars)
        statsPage:SetShown(isStats)
        macrosPage:SetShown(isMacros)
        completionistPage:SetShown(isCompletionist)
        selected:SetStyledSelected(activePage == page)
        windowsButton:SetStyledSelected(isWindows)
        unitFramesButton:SetStyledSelected(isUnitFrames)
        castbarsButton:SetStyledSelected(isCastbars)
        vendorButton:SetStyledSelected(isVendor)
        tooltipsButton:SetStyledSelected(isTooltips)
        lootButton:SetStyledSelected(isLoot)
        questsButton:SetStyledSelected(isQuests)
        actionBarsButton:SetStyledSelected(isActionBars)
        statsButton:SetStyledSelected(isStats)
        macrosButton:SetStyledSelected(isMacros)
        completionistButton:SetStyledSelected(isCompletionist)
        local section = isVendor and L["VENDOR"] or (isCastbars and L["CASTBARS"] or (isUnitFrames and L["UNIT FRAMES"] or (isWindows and L["WINDOWS & BAGS"] or L["DAMAGE METERS"])))
        subtitle:SetText(L["FOREVER BETA  /  "] .. (isQuests and L["QUESTS"] or (isLoot and L["LOOT"] or (isTooltips and L["TOOLTIPS"] or section))))
        if isActionBars then subtitle:SetText(L["FOREVER BETA  /  ACTION BARS"]) end
        if isStats then subtitle:SetText(L["FOREVER BETA  /  STATS"]) end
        if isMacros then subtitle:SetText(L["FOREVER BETA  /  "] .. L["Macros"]) end
        if isCompletionist then subtitle:SetText("FOREVER BETA  /  COMPLETIONIST") end
        activePage:Refresh()
    end
    selected:SetScript("OnClick", function() frame:SelectPage("meters") end)
    windowsButton:SetScript("OnClick", function() frame:SelectPage("windows") end)
    unitFramesButton:SetScript("OnClick", function() frame:SelectPage("unitframes") end)
    castbarsButton:SetScript("OnClick", function() frame:SelectPage("castbars") end)
    vendorButton:SetScript("OnClick", function() frame:SelectPage("vendor") end)
    tooltipsButton:SetScript("OnClick", function() frame:SelectPage("tooltips") end)
    lootButton:SetScript("OnClick", function() frame:SelectPage("loot") end)
    questsButton:SetScript("OnClick", function() frame:SelectPage("quests") end)
    actionBarsButton:SetScript("OnClick", function() frame:SelectPage("actionbars") end)
    statsButton:SetScript("OnClick", function() frame:SelectPage("stats") end)
    macrosButton:SetScript("OnClick", function() frame:SelectPage("macros") end)
    completionistButton:SetScript("OnClick", function() frame:SelectPage("completionist") end)
    UI.RefreshVisiblePage = function() if frame:IsShown() then activePage:Refresh() end end
    frame:SetScript("OnShow", function() activePage:Refresh() end)
    frame:Hide()
    return frame
end

function ns.UI2.Show(page)
    local frame = BuildWindow()
    if page then frame:SelectPage(page) end
    frame:Show()
end
function ns.UI2.Toggle()
    local frame = BuildWindow()
    frame:SetShown(not frame:IsShown())
end
