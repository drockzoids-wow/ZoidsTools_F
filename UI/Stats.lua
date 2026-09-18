local _, ns = ...
local UI = ns.UI

function UI.CreateStatsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local enabled = UI.CreateCheckbox(page, "Show stats window",
        "Show a compact box with FPS, world latency, and current movement speed.",
        function() return ns.db.stats.enabled end,
        function(value) ns:SetStatsWindowOption("enabled", value) end)
    enabled:SetPoint("TOPLEFT", 0, 0)
    local locked = UI.CreateCheckbox(page, "Lock position",
        "Prevent dragging while keeping hover tooltips. On supported clients, clicks pass through the locked box.",
        function() return ns.db.stats.locked end,
        function(value) ns:SetStatsWindowOption("locked", value) end)
    locked:SetPoint("TOPLEFT", 0, -38)
    local reset = UI.CreateButton(page, "Reset position", 160, 30)
    reset:SetPoint("TOPLEFT", 0, -88)
    reset:SetScript("OnClick", function() ns:ResetStatsWindowPosition() end)
    local text = UI.CreateBodyText(page,
        "Drag anywhere on the unlocked box to move it. Lock position keeps it visible and still allows each stat's tooltip. Position and settings are saved across reloads.\n\nLatency shows world latency; hover to see both home and world. Speed is your current movement as a percentage of normal running speed (100%). Standing still shows 0%.\n\nMovement is paused during combat. Unavailable or restricted values display --.", 500)
    text:SetPoint("TOPLEFT", 0, -142)
    function page:Refresh() enabled:Refresh(); locked:Refresh() end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
