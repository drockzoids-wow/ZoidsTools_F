local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local UI = ns.UI

function UI.CreateUnitFramesPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local toggle = UI.CreateCheckbox(page, L["Class-colored health bars"],
        L["Use class colors on Blizzard's player, target, target-of-target, and focus health bars."],
        function() return ns:GetUnitFrameClassColorHealth() end,
        function(value) ns:SetUnitFrameClassColorHealth(value) end)
    toggle:SetPoint("TOPLEFT", 0, 0)
    local description = UI.CreateBodyText(page,
        L["Colors the health fill for player characters on the default player, target, target-of-target, and focus frames.\n\nNPCs and vehicle bars retain Blizzard's colors. Frame borders, portraits, party frames, and raid frames are unchanged.\n\nTurn this option off to restore the normal health colors. Changes to protected frames wait until combat ends. If the beta restricts class information, the addon leaves that information alone."], 500)
    description:SetPoint("TOPLEFT", 0, -54)
    local buffs=UI.CreateButton(page,L["Missing-buff reminders"],230,30)
    buffs:SetPoint("TOPLEFT",0,-290)
    buffs:SetScript("OnClick",function()ns:ShowMissingBuffSettings()end)
    function page:Refresh() toggle:Refresh() end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
