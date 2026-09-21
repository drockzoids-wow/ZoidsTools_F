local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
local UI = ns.UI

function UI.CreateMacrosPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 180, -90)
    page:SetSize(530, 485)
    local controls = {}
    local function Check(key, label, tip, y)
        local control = UI.CreateCheckbox(page, label, tip,
            function() return ns:GetConsumableMacroOption(key) end,
            function(value) ns:SetConsumableMacroOption(key, value) end)
        control:SetPoint("TOPLEFT", 0, y)
        controls[#controls + 1] = control
    end
    Check("healthEnabled", L["Build ZTF Health macro"], L["Automatically select carried non-buff food. Creates a general macro."], 0)
    Check("healthCombatItems", L["Use Healthstone and healing potion in combat"],
        L["Adds Healthstone first, then a healing potion. Both may be used on the same press if the game permits."], -40)
    Check("manaEnabled", L["Build ZTF Mana macro"], L["Automatically select carried water or other non-buff drinks. Creates a general macro."], -96)
    Check("manaCombatPotion", L["Use mana potion in combat"], L["Adds your best carried mana potion to the mana macro."], -136)
    local help = UI.CreateBodyText(page,
        L["Enable either macro, then drag ZTF Health or ZTF Mana from the game's Macros window onto your action bar. Food and water are used out of combat; combat items require a button press.\n\nPrefers conjured food and drinks, then restoration amount. Updates as bags change, after combat ends. Disabling stops updates and leaves existing macros in place. Detection currently uses English item text."], 500)
    help:SetPoint("TOPLEFT", 0, -192)
    local health = UI.CreateBodyText(page, "", 500)
    health:SetPoint("TOPLEFT", 0, -340)
    local mana = UI.CreateBodyText(page, "", 500)
    mana:SetPoint("TOPLEFT", 0, -386)
    local refresh = UI.CreateButton(page, L["Build / refresh macros"], 210, 30)
    refresh:SetPoint("TOPLEFT", 0, -440)
    refresh:SetScript("OnClick", function() ns:RefreshConsumableMacros(); page:Refresh() end)
    function page:Refresh()
        for _, control in ipairs(controls) do control:Refresh() end
        local healthStatus, manaStatus = ns:GetConsumableMacroStatus()
        health:SetText("ZTF Health: " .. healthStatus)
        mana:SetText("ZTF Mana: " .. manaStatus)
    end
    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:Hide()
    return page
end
