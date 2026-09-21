local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local UI = ns.UI

function UI.CreateActionBarsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local toggle = UI.CreateCheckbox(page, L["Full-button range indicator"],
        L["Cover the entire action icon with a red tint when its action is out of range."],
        function() return ns:GetActionButtonRangeTintEnabled() end,
        function(value) ns:SetActionButtonRangeTintEnabled(value) end)
    toggle:SetPoint("TOPLEFT", 0, 0)
    local description = UI.CreateBodyText(page,
        L["Out-of-range actions receive a full-icon red overlay, matching retail ZoidsTools. Enabled by default.\n\nSupports Blizzard's main and additional action bars, plus action-slot buttons on vehicle, override, and extra-action bars.\n\nThe overlay clears when you move into range or the action has no known range result. Blizzard's normal icon colors and cooldowns remain underneath."], 500)
    description:SetPoint("TOPLEFT", 0, -54)
    local campfire = UI.CreateCheckbox(page, L["Show campfire item bar"],
        L["Show carried camp items while you have the Welcoming Campfire or Campfire Nearby buff. Hidden during combat."],
        function() return ns:GetCampfireBarEnabled() end,
        function(value) ns:SetCampfireBarEnabled(value) end)
    campfire:SetPoint("TOPLEFT", 0, -240)
    local campHelp = UI.CreateBodyText(page,
        L["Finds supported camping items in your bags. Duplicate stacks share one button. Click to use an item; hover for its tooltip. Drag the title to move the bar.\n\nShows near a campfire when matching items are carried. Cooldowns and other requirements still apply. New beta items may need a detection update."], 500)
    campHelp:SetPoint("TOPLEFT", 0, -282)
    local status = UI.CreateBodyText(page, "", 500)
    status:SetPoint("TOPLEFT", 0, -390)
    local rescan = UI.CreateButton(page, L["Rescan camp items"], 180, 30)
    rescan:SetPoint("TOPLEFT", 0, -428)
    if ns.locale and ns.locale ~= "enUS" then
        status:ClearAllPoints(); status:SetPoint("TOPLEFT", 0, -410)
        rescan:ClearAllPoints(); rescan:SetPoint("TOPLEFT", 0, -453)
    end
    rescan:SetScript("OnClick", function() ns:RefreshCampfireBar(true); page:Refresh() end)
    function page:Refresh()
        toggle:Refresh()
        campfire:Refresh()
        status:SetText(ns:GetCampfireBarStatus())
    end
    local elapsedTime = 0
    page:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime >= 1 then elapsedTime = 0; status:SetText(ns:GetCampfireBarStatus()) end
    end)
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
