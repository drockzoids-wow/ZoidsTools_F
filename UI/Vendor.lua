local _, ns = ...
local UI = ns.UI
function UI.CreateVendorPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local sell = UI.CreateCheckbox(page, "Automatically sell all junk", "Uses the vendor's native bulk-sale action without showing its confirmation popup.",
        function() return ns.db.vendor.autoSellJunk end,
        function(value) ns.db.vendor.autoSellJunk = value end)
    sell:SetPoint("TOPLEFT", 0, 0)
    local repair = UI.CreateDropdown(page, "Auto repair", "Choose where repair payments come from.", {
        { value = "disabled", text = "Disabled" },
        { value = "personal", text = "Personal gold" },
        { value = "guild", text = "Guild bank only" },
    }, function() return ns.db.vendor.autoRepairMode end,
    function(value) ns.db.vendor.autoRepairMode = value end, 260)
    repair:SetPoint("TOPLEFT", 0, -74)
    local help = UI.CreateBodyText(page,
        "When you open a vendor, auto sell uses Blizzard's Sell All Junk action once. The confirmation popup is never opened. Items sold this way cannot be bought back, as the native confirmation explains.\n\nOnly items included by Blizzard's junk-sale rules are sold. If the bulk button or API is unavailable, auto sell skips that visit.\n\nRepairs run after the sale request, with a short wait for sale proceeds if needed. Guild bank mode requires permission, sufficient guild funds, and repair allowance; it never spends personal gold.\n\nHold Shift while opening a vendor to skip both actions for that visit. Both options start disabled.", 510)
    help:SetPoint("TOPLEFT", 0, -155)
    function page:Refresh() sell:Refresh(); repair:Refresh() end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
