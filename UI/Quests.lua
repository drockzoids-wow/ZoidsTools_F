local _, ns = ...
local UI = ns.UI

function UI.CreateQuestsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local accept = UI.CreateCheckbox(page, "Automatically accept quests", "Accept quests offered by the NPC you interact with.",
        function() return ns:GetQuestAutomationOption("autoAccept") end,
        function(value) ns:SetQuestAutomationOption("autoAccept", value) end)
    accept:SetPoint("TOPLEFT", 0, 0)
    local turnIn = UI.CreateCheckbox(page, "Automatically turn in quests", "Complete ready quests when there is no reward choice to make.",
        function() return ns:GetQuestAutomationOption("autoTurnIn") end,
        function(value) ns:SetQuestAutomationOption("autoTurnIn", value) end)
    turnIn:SetPoint("TOPLEFT", 0, -38)
    local modifier = UI.CreateDropdown(page, "Hold to pause", "Hold this key before interacting to handle quests manually.", {
        { value = "shift", text = "Shift" }, { value = "ctrl", text = "Ctrl" },
        { value = "alt", text = "Alt" }, { value = "none", text = "None" },
    }, function() return ns:GetQuestAutomationPauseModifier() end,
    function(value) ns:SetQuestAutomationPauseModifier(value) end, 260)
    modifier:SetPoint("TOPLEFT", 0, -110)
    local help = UI.CreateBodyText(page,
        "Hold your pause key before talking to a quest giver to read or finish quests manually. The key is checked at each stage. Shift is the default.\n\nAuto turn-in selects completed quests and claims rewards when there are zero or one choices. Multiple reward choices wait for your selection.\n\nBoth automation options start disabled. Enable either option independently.", 510)
    help:SetPoint("TOPLEFT", 0, -190)
    local minimize = UI.CreateCheckbox(page, "Minimize tracker to its button",
        "When collapsed, hide All Objectives and the tracker background, leaving the native + button. Expand to restore the normal tracker.",
        function() return ns:GetTrackerMinimizeToButton() end,
        function(value) ns:SetTrackerMinimizeToButton(value) end)
    minimize:SetPoint("TOPLEFT", 0, -350)
    local reputation = UI.CreateCheckbox(page, "Track reputation for the current area",
        "Automatically watch the faction for recognized home zones and neutral towns. Unmapped areas keep your selection. Changes wait until combat ends.",
        function() return ns:GetZoneReputationEnabled() end,
        function(value) ns:SetZoneReputationEnabled(value) end)
    reputation:SetPoint("TOPLEFT", 0, -400)
    local repHelp = UI.CreateBodyText(page,
        "For example: Dun Morogh, Loch Modan and Wetlands track Ironforge. Uses English area names; enabled by default.", 510)
    repHelp:SetPoint("TOPLEFT", 0, -440)
    function page:Refresh() accept:Refresh(); turnIn:Refresh(); modifier:Refresh(); minimize:Refresh(); reputation:Refresh() end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
