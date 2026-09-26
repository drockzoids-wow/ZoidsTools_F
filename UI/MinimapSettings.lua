local _,ns=...
local L=ns.L or setmetatable({}, {__index=function(_,key)return key end})
local window
function ns:ShowMinimapSettings()
    if window then window:Show();window:Refresh();return end
    local UI=self.UI
    window=CreateFrame("Frame","ZoidsTools_FMinimapSettings",UIParent,"BackdropTemplate")
    window:SetSize(540,390);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true);window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart",window.StartMoving);window:SetScript("OnDragStop",window.StopMovingOrSizing)
    UI.Theme.ApplyPanelBackdrop(window)
    table.insert(UISpecialFrames,"ZoidsTools_FMinimapSettings")
    local close=CreateFrame("Button",nil,window,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3)
    local title=UI.CreateBodyText(window,L["Minimap"],470);title:SetPoint("TOPLEFT",20,-20)
    local controls={}
    local function Check(label,tip,getter,setter)
        local c=UI.CreateCheckbox(window,L[label],L[tip],getter,setter)
        c:SetPoint("TOPLEFT",20,-60-#controls*38);controls[#controls+1]=c
    end
    Check("Show minimap button","Show the ZoidsTools Forever settings button.",
        function()return ns.db.ui.minimap.show end,function(v)ns:SetMinimapShown(v)end)
    Check("Square minimap","Use a square map with a class-colored border.",
        function()return ns:IsSquareMinimapEnabled()end,function(v)ns:SetSquareMinimapEnabled(v)end)
    Check("Compact minimap header","Move zone text, tracking and the clock into a compact header. Left-click the clock for the calendar; right-click for the stopwatch.",
        function()return ns:IsMinimapHeaderBarEnabled()end,function(v)ns:SetMinimapHeaderBarEnabled(v)end)
    Check("Hide addon compartment","Hide Blizzard's addon-compartment button when available.",
        function()return ns:IsAddonCompartmentHidden()end,function(v)ns:SetAddonCompartmentHidden(v)end)
    Check("Show addon buttons on mouseover","Reveal addon buttons when hovering over the map; hide them four seconds after leaving.",
        function()return ns:IsMinimapButtonsMouseoverEnabled()end,function(v)ns:SetMinimapButtonsMouseoverEnabled(v)end)
    Check("Collect addon buttons","Group addon buttons in one expandable button. Takes precedence over mouseover hiding. Drag the collector to reposition it.",
        function()return ns:IsMinimapButtonCollectorEnabled()end,function(v)ns:SetMinimapButtonCollectorEnabled(v)end)
    local help=UI.CreateBodyText(window,L["Settings apply to all characters. Changes made in combat wait until combat ends. Disable an option to restore the original layout."],490)
    help:SetPoint("TOPLEFT",20,-310)
    function window:Refresh()for _,c in ipairs(controls)do c:Refresh()end end
    window:SetScript("OnShow",function(self)self:Refresh()end)
    window:Refresh();window:Show()
end
