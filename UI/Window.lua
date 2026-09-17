local _, ns = ...
local UI, Theme = ns.UI, ns.UI.Theme
ns.UI2 = {}
local window

local function BuildWindow()
    if window then return window end
    local frame = CreateFrame("Frame", "ZoidsTools_FSettings", UIParent, "BackdropTemplate")
    window = frame
    frame:SetSize(740, 600)
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
    local subtitle = UI.CreateBodyText(frame, "FOREVER BETA  /  DAMAGE METERS", 650)
    subtitle:SetPoint("TOPLEFT", 24, -52)

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 16, -82)
    sidebar:SetPoint("BOTTOMLEFT", 16, 18)
    sidebar:SetWidth(142)
    Theme.ApplySoftBackdrop(sidebar)
    local selected = UI.CreateButton(sidebar, "Damage Meters", 126, 32)
    selected:SetPoint("TOPLEFT", 8, -12)
    selected:SetStyledSelected(true)
    local windowsButton = UI.CreateButton(sidebar, "Windows & Bags", 126, 32)
    windowsButton:SetPoint("TOPLEFT", 8, -52)
    local unitFramesButton = UI.CreateButton(sidebar, "Unit Frames", 126, 32)
    unitFramesButton:SetPoint("TOPLEFT", 8, -92)
    local castbarsButton = UI.CreateButton(sidebar, "Castbars", 126, 32)
    castbarsButton:SetPoint("TOPLEFT", 8, -132)
    local vendorButton = UI.CreateButton(sidebar, "Vendor", 126, 32)
    vendorButton:SetPoint("TOPLEFT", 8, -172)
    local note = UI.CreateBodyText(sidebar, "ZoidsTools style\nForever foundation\n\nv" .. ns.version, 116)
    note:SetPoint("TOPLEFT", 12, -222)

    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local controls = {}
    local function Check(label, tip, getter, setter, y)
        local c = UI.CreateCheckbox(page, label, tip, getter, setter)
        c:SetPoint("TOPLEFT", 0, y)
        controls[#controls + 1] = c
    end
    Check("Enable ZoidsTools meters", "Uses Blizzard's meter API. Enabling this hides Blizzard's meter windows.",
        function() return ns:GetCustomDamageMeterEnabled() end,
        function(v) ns:SetCustomDamageMeterEnabled(v) end, 0)
    Check("Show second meter", "Choose damage, healing, or another available type from each meter's title.",
        function() return ns:GetCustomDamageMeterSecondWindowEnabled() end,
        function(v) ns:SetCustomDamageMeterSecondWindowEnabled(v) end, -34)
    Check("Class-colored borders", "Use your class color for the meter borders.",
        function() return ns:GetCustomDamageMeterClassColoredBorder() end,
        function(v) ns:SetCustomDamageMeterClassColoredBorder(v) end, -68)
    Check("Show minimap button", "Open settings from the minimap.",
        function() return ns.db.ui.minimap.show end,
        function(v) ns:SetMinimapShown(v) end, -102)

    local function Slider(label, min, max, step, getter, setter, x, y, format)
        local c = UI.CreateSlider(page, label, nil, min, max, step, getter, setter, 220, format)
        c:SetPoint("TOPLEFT", x, y)
        controls[#controls + 1] = c
    end
    Slider("Text size", 0.8, 1.5, 0.05,
        function() return ns:GetCustomDamageMeterTextScale() end,
        function(v) ns:SetCustomDamageMeterTextScale(v) end, 8, -164,
        function(v) return string.format("%d%%", v * 100 + 0.5) end)
    Slider("Background", 0, 1, 0.05,
        function() return ns:GetCustomDamageMeterBackgroundOpacity() end,
        function(v) ns:SetCustomDamageMeterBackgroundOpacity(v) end, 278, -164,
        function(v) return string.format("%d%%", v * 100 + 0.5) end)
    Slider("Snap gap", 0, 24, 1,
        function() return ns:GetCustomDamageMeterSnapGap() end,
        function(v) ns:SetCustomDamageMeterSnapGap(v) end, 8, -218)

    local preview = UI.CreateButton(page, "Preview / Move", 160, 30)
    preview:SetPoint("TOPLEFT", 0, -260)
    preview:SetScript("OnClick", function() ns:ToggleCustomDamageMeterMoveMode(); page:Refresh() end)
    local reset = UI.CreateButton(page, "Reset position", 160, 30)
    reset:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    reset:SetScript("OnClick", function() ns:ResetCustomDamageMeterPosition() end)
    local save = UI.CreateButton(page, "Save layout", 160, 30)
    save:SetPoint("TOPLEFT", 0, -300)
    save:SetScript("OnClick", function()
        ns.db.layouts.saved = ns:CaptureCustomDamageMeterLayout()
        ns:Print("Meter layout saved for all characters.")
        page:Refresh()
    end)
    local restore = UI.CreateButton(page, "Restore layout", 160, 30)
    restore:SetPoint("LEFT", save, "RIGHT", 10, 0)
    restore:SetScript("OnClick", function() ns:ApplyCustomDamageMeterLayout(ns.db.layouts.saved) end)
    local instructions = UI.CreateBodyText(page,
        "Use each meter's title to select its type, and its segment menu for current, overall, or recent fights. Click a player for details. Preview / Move unlocks dragging and resizing and displays sample data.", 510)
    instructions:SetPoint("TOPLEFT", 0, -347)
    local status = UI.CreateBodyText(page, "", 510)
    status:SetPoint("TOPLEFT", 0, -416)
    function page:Refresh()
        for _, control in ipairs(controls) do control:Refresh() end
        preview:SetText(ns:IsCustomDamageMeterMoveMode() and "Lock meters" or "Preview / Move")
        UI.SetControlEnabled(restore, type(ns.db.layouts.saved) == "table")
        status:SetText(ns:GetCompatibilityStatus())
    end
    local windowsPage = UI.CreateWindowsPage(frame)
    local unitFramesPage = UI.CreateUnitFramesPage(frame)
    local castbarsPage = UI.CreateCastbarsPage(frame)
    local vendorPage = UI.CreateVendorPage(frame)
    local activePage = page
    function frame:SelectPage(key)
        local isWindows = key == "windows" or key == "bags"
        local isUnitFrames = key == "unitframes"
        local isCastbars = key == "castbars"
        local isVendor = key == "vendor"
        activePage = isVendor and vendorPage or (isCastbars and castbarsPage or (isUnitFrames and unitFramesPage or (isWindows and windowsPage or page)))
        page:SetShown(not isWindows and not isUnitFrames and not isCastbars and not isVendor)
        windowsPage:SetShown(isWindows)
        unitFramesPage:SetShown(isUnitFrames)
        castbarsPage:SetShown(isCastbars)
        vendorPage:SetShown(isVendor)
        selected:SetStyledSelected(not isWindows and not isUnitFrames and not isCastbars and not isVendor)
        windowsButton:SetStyledSelected(isWindows)
        unitFramesButton:SetStyledSelected(isUnitFrames)
        castbarsButton:SetStyledSelected(isCastbars)
        vendorButton:SetStyledSelected(isVendor)
        local section = isVendor and "VENDOR" or (isCastbars and "CASTBARS" or (isUnitFrames and "UNIT FRAMES" or (isWindows and "WINDOWS & BAGS" or "DAMAGE METERS")))
        subtitle:SetText("FOREVER BETA  /  " .. section)
        activePage:Refresh()
    end
    selected:SetScript("OnClick", function() frame:SelectPage("meters") end)
    windowsButton:SetScript("OnClick", function() frame:SelectPage("windows") end)
    unitFramesButton:SetScript("OnClick", function() frame:SelectPage("unitframes") end)
    castbarsButton:SetScript("OnClick", function() frame:SelectPage("castbars") end)
    vendorButton:SetScript("OnClick", function() frame:SelectPage("vendor") end)
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
