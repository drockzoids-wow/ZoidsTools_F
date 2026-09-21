local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local UI = ns.UI

function UI.CreateCastbarsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local key = "player"
    local tabs = {}
    local labels = { player = L["Player"], target = L["Target"], focus = L["Focus"] }
    for index, frameKey in ipairs({ "player", "target", "focus" }) do
        local selectedKey = frameKey
        local button = UI.CreateButton(page, labels[frameKey], 150, 28)
        button:SetPoint("TOPLEFT", (index - 1) * 160, 0)
        button:SetScript("OnClick", function()
            ns:StopCastbarPreview()
            key = selectedKey
            page:Refresh()
        end)
        tabs[frameKey] = button
    end
    local enabled = UI.CreateCheckbox(page, L["Customize this castbar's size"], L["Use saved width and height. Turn off to restore the original dimensions."],
        function() return ns:GetCastbarSettings(key).enabled end,
        function(value) ns:SetCastbarSetting(key, "enabled", value) end)
    enabled:SetPoint("TOPLEFT", 0, -52)
    local width = UI.CreateSlider(page, L["Width"], nil, 120, 420, 1,
        function() return ns:GetCastbarSettings(key).width end,
        function(value) ns:SetCastbarSetting(key, "width", value) end, 220)
    width:SetPoint("TOPLEFT", 8, -117)
    local height = UI.CreateSlider(page, L["Height"], nil, 8, 40, 1,
        function() return ns:GetCastbarSettings(key).height end,
        function(value) ns:SetCastbarSetting(key, "height", value) end, 220)
    height:SetPoint("TOPLEFT", 278, -117)
    local preview = UI.CreateButton(page, L["Preview this castbar"], 210, 30)
    preview:SetPoint("TOPLEFT", 0, -170)
    local message = UI.CreateBodyText(page, "", 510)
    message:SetPoint("TOPLEFT", 0, -217)
    preview:SetScript("OnClick", function()
        if ns:IsCastbarPreviewActive(key) then
            ns:StopCastbarPreview()
            message:SetText("")
        else
            local ok, reason = ns:StartCastbarPreview(key)
            message:SetText(ok and L["Showing the actual Blizzard castbar at its current position."] or reason)
        end
        page:Refresh()
    end)
    local help = UI.CreateBodyText(page,
        L["Spell names are centered inside the bar, with text size adapting to its dimensions. Long names stay on one line within the bar.\n\nPreview shows the actual Blizzard bar. Target and focus frames must be visible. Preview stops when you leave this page, switch targets, start casting, or enter combat.\n\nPositions stay controlled by Blizzard. Close Blizzard's full Edit Mode before changing these settings."], 510)
    help:SetPoint("TOPLEFT", 0, -283)
    function page:Refresh()
        local available = ns:CanCustomizeCastbars()
        for tabKey, button in pairs(tabs) do button:SetStyledSelected(key == tabKey) end
        enabled:Refresh(); width:Refresh(); height:Refresh()
        UI.SetControlEnabled(enabled, available)
        UI.SetControlEnabled(width, available and ns:GetCastbarSettings(key).enabled)
        UI.SetControlEnabled(height, available and ns:GetCastbarSettings(key).enabled)
        UI.SetControlEnabled(preview, available)
        preview:SetText(ns:IsCastbarPreviewActive(key) and L["Stop preview"] or L["Preview this castbar"])
    end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:SetScript("OnHide", function() ns:StopCastbarPreview(); message:SetText("") end)
    page:Hide()
    return page
end
