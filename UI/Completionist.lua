local _, ns = ...
local UI = ns.UI
function UI.CreateCompletionistPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local title = UI.CreateBodyText(page, "Completionist", 510)
    title:SetPoint("TOPLEFT", 0, 0)
    local help = UI.CreateBodyText(page,
        "Browse quests by area, check this character's completion, and collect missing beta quests as you play. The compact tracker can stay open while you quest.\n\nQuest availability remains provisional. Unknown game results stay unknown.", 510)
    help:SetPoint("TOPLEFT", 0, -36)
    local show = UI.CreateButton(page, "Open tracker", 140, 30)
    show:SetPoint("TOPLEFT", 0, -160)
    show:SetScript("OnClick", function() if ns.Completionist then ns.Completionist.ShowTracker() end end)
    local hide = UI.CreateButton(page, "Hide tracker", 140, 30)
    hide:SetPoint("LEFT", show, "RIGHT", 10, 0)
    hide:SetScript("OnClick", function()
        local guide = ns.Completionist
        if guide and guide.window then guide.window:Hide() end
    end)
    local reload = UI.CreateButton(page, "Finish import", 140, 30)
    reload:SetPoint("TOPLEFT", 0, -206)
    reload:SetScript("OnClick", function() if ReloadUI then ReloadUI() end end)
    local status = UI.CreateBodyText(page, "", 510)
    status:SetPoint("TOPLEFT", 0, -254)
    function page:Refresh()
        local guide = ns.Completionist
        local pending = guide and guide.migrationPending
        UI.SetControlEnabled(show, guide and guide.window ~= nil and not pending)
        UI.SetControlEnabled(hide, guide and guide.window ~= nil and not pending)
        reload:SetShown(pending == true)
        status:SetText(pending and "Guide data imported. Finish import reloads the UI. If the old Guide remains enabled, disable ZoidsForeverGuide in the AddOns list first."
            or "Use /ztfc to minimize or expand. Filters, discoveries and tracker position are saved separately for each character. Hover a quest for its full title and details.")
    end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
