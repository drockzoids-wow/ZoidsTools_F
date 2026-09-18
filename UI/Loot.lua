local _, ns = ...
local UI = ns.UI

function UI.CreateLootPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local enabled = UI.CreateCheckbox(page, "Fast loot", "Speed up looting when Auto Loot is active.",
        function() return ns:GetFastLootEnabled() end,
        function(value) ns:SetFastLootEnabled(value) end)
    enabled:SetPoint("TOPLEFT", 0, 0)
    local delay = UI.CreateSlider(page, "Delay between items", "Drag or use the mouse wheel to adjust by 1 millisecond.", 0, 200, 1,
        function() return ns:GetFastLootDelay() * 1000 end,
        function(value) ns:SetFastLootDelay(value / 1000) end, 300,
        function(value) return string.format("%.3f s (%d ms)", value / 1000, math.floor(value + 0.5)) end)
    delay:SetPoint("TOPLEFT", 8, -80)
    delay:EnableMouseWheel(true)
    delay:SetScript("OnMouseWheel", function(_, direction)
        if not ns:GetFastLootEnabled() or direction == 0 then return end
        local milliseconds = math.floor(ns:GetFastLootDelay() * 1000 + 0.5)
        ns:SetFastLootDelay((milliseconds + (direction > 0 and 1 or -1)) / 1000)
        delay:Refresh()
    end)
    local help = UI.CreateBodyText(page,
        "Adjust in 1 ms steps by dragging or using the mouse wheel over the slider. 0 ms requests all available loot immediately; the maximum is 0.200 seconds between items. Server response time can still affect pickup speed.\n\nUses your Auto Loot setting and its modifier key. Enable Auto Loot in Blizzard's settings, or hold your Auto Loot modifier to loot automatically.\n\nEach slot gets one attempt per loot opening. Locked items and any normal loot confirmations remain under Blizzard's control.", 510)
    help:SetPoint("TOPLEFT", 0, -155)
    function page:Refresh()
        enabled:Refresh(); delay:Refresh()
        UI.SetControlEnabled(delay, ns:GetFastLootEnabled())
    end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
