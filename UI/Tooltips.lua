local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local UI = ns.UI

function UI.CreateTooltipsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local toggle = UI.CreateCheckbox(page, L["Class-colored player names"],
        L["Color player names in mouseover tooltips using their class color, just like retail ZoidsTools."],
        function() return ns:IsTooltipClassColoredNamesEnabled() end,
        function(value) ns:SetTooltipClassColoredNamesEnabled(value) end)
    toggle:SetPoint("TOPLEFT", 0, 0)
    local description = UI.CreateBodyText(page,
        L["Player names use their class colors when you hover over characters or their unit frames.\n\nEnabled by default, matching retail ZoidsTools. Changes apply the next time you hover over a player."], 500)
    description:SetPoint("TOPLEFT", 0, -54)
    local items = UI.CreateCheckbox(page, L["Item counts across characters"],
        L["Show saved item counts in bags, banks, and equipment for each character."],
        function() return ns:GetWarbandItemTooltipsEnabled() end,
        function(value) ns:SetWarbandItemTooltipsEnabled(value) end)
    items:SetPoint("TOPLEFT", 0, -165)
    local inventoryHelp = UI.CreateBodyText(page,
        L["Log into each character to record their bags and equipment. Visit their bank to record its contents. Offline characters and closed banks show their last recorded counts. Shared bank counts appear when supported by the client."], 500)
    inventoryHelp:SetPoint("TOPLEFT", 0, -215)
    function page:Refresh() toggle:Refresh(); items:Refresh() end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
