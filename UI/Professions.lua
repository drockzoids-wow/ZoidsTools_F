local _,ns=...
local L=ns.L or setmetatable({},{__index=function(_,k)return k end})
local UI=ns.UI
function UI.CreateProfessionsPage(parent)
    local page=CreateFrame("Frame",nil,parent)
    page:SetPoint("TOPLEFT",180,-90);page:SetSize(530,485)
    local enabled=UI.CreateCheckbox(page,L["Modifier-click disenchant"],L["Highlight bag equipment for disenchanting while holding your chosen modifier."],
        function()return ns:GetProfessionHelperEnabled()end,function(v)ns:SetProfessionHelperEnabled(v)end)
    enabled:SetPoint("TOPLEFT",0,0)
    local modifier=UI.CreateDropdown(page,L["Disenchant modifier"],L["Hold this key and left-click a highlighted bag item."],{
        {value="alt",text=L["Alt"]},{value="ctrl",text=L["Ctrl"]},{value="shift",text=L["Shift"]},
    },function()return ns:GetProfessionHelperModifier()end,function(v)ns:SetProfessionHelperModifier(v)end,260)
    modifier:SetPoint("TOPLEFT",0,-85)
    local help=UI.CreateBodyText(page,L["Off by default. Requires Disenchant. Hold only the selected modifier and left-click uncommon, rare or epic bag equipment to disenchant it. Disenchanting destroys the item. Equipped items and bank items are excluded. Unavailable during combat. The game checks skill requirements and whether an item can be disenchanted."],510)
    help:SetPoint("TOPLEFT",0,-165)
    function page:Refresh()enabled:Refresh();modifier:Refresh()end
    page:SetScript("OnShow",function(self)self:Refresh()end);page:Hide();return page
end
