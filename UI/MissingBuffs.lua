local _,ns=...
local L=ns.L or setmetatable({}, {__index=function(_,k)return k end})
local window
function ns:ShowMissingBuffSettings()
 if window then window:Show();window:Refresh();return end
 local UI=self.UI
 window=CreateFrame("Frame","ZoidsTools_FBuffSettings",UIParent,"BackdropTemplate")
 window:SetSize(540,550);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetClampedToScreen(true)
 window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton")
 window:SetScript("OnDragStart",window.StartMoving);window:SetScript("OnDragStop",window.StopMovingOrSizing)
 UI.Theme.ApplyPanelBackdrop(window)
 table.insert(UISpecialFrames,"ZoidsTools_FBuffSettings")
 local close=CreateFrame("Button",nil,window,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-3,-3)
 local title=UI.CreateBodyText(window,L["Missing buffs"],470);title:SetPoint("TOPLEFT",20,-20)
 local enabled=UI.CreateCheckbox(window,L["Enable missing-buff reminders"],L["Quiet reminders for learned buffs. Settings are saved for this character."],
  function()return ns:GetBuffReminderSettings().enabled end,function(v)ns:SetMissingBuffsEnabled(v);window:Refresh()end)
 enabled:SetPoint("TOPLEFT",20,-55)
 local help=UI.CreateBodyText(window,L["Shown outside combat while alive and unmounted. Hover for buff names; drag the reminder to move it. Icons are reminders, not cast buttons."],490)
 help:SetPoint("TOPLEFT",20,-90)
 local controls={enabled}
 for i,choice in ipairs(ns:GetBuffReminderChoices()) do
  local c=choice
  local control=UI.CreateCheckbox(window,ns:GetBuffReminderName(c),L["Accepts any listed rank or group equivalent. Only reminds you when you know this buff."],
   function()return ns:IsBuffReminderSelected(c)end,function(v)ns:SetBuffReminderSelected(c,v)end)
  control:SetPoint("TOPLEFT",20,-150-(i-1)*32);controls[#controls+1]=control
 end
 local customLabel=UI.CreateBodyText(window,L["Additional buffs: up to eight spell IDs, separated by commas"],490)
 customLabel:SetPoint("TOPLEFT",20,-265)
 local input=CreateFrame("EditBox",nil,window,"InputBoxTemplate")
 input:SetSize(480,26);input:SetPoint("TOPLEFT",25,-292);input:SetAutoFocus(false);input:SetMaxLetters(120)
 input:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
 local status=UI.CreateBodyText(window,"",490);status:SetPoint("TOPLEFT",20,-380)
 local save=UI.CreateButton(window,L["Save custom buffs"],160,28);save:SetPoint("TOPLEFT",20,-335)
 save:SetScript("OnClick",function()
  local ok,message=ns:SetCustomBuffReminders(input:GetText());status:SetText(message)
  if ok then input:ClearFocus();input:SetText(ns:GetBuffReminderSettings().custom)end
 end)
 local preview=UI.CreateButton(window,L["Toggle preview"],210,28);preview:SetPoint("LEFT",save,"RIGHT",12,0)
 preview:SetScript("OnClick",function()ns:ToggleMissingBuffPreview()end)
 local size=UI.CreateSlider(window,L["Buff bar size"],L["Resize the icons and heading together. Use the preview to see the size even when no buffs are missing."],50,200,5,
  function()return ns:GetBuffReminderSettings().scale*100 end,function(value)ns:SetMissingBuffScale(value)end,460,
  function(value)return string.format("%d%%",value)end)
 size:SetPoint("TOPLEFT",30,-440);controls[#controls+1]=size
 local locked=UI.CreateCheckbox(window,L["Lock buff bar"],L["Prevent dragging and hide the movement hint. Unlock to move the bar, including in preview."],
  function()return ns:GetBuffReminderSettings().locked end,function(value)ns:SetMissingBuffsLocked(value)end)
 locked:SetPoint("TOPLEFT",20,-480);controls[#controls+1]=locked
 function window:Refresh()
  for _,c in ipairs(controls)do c:Refresh()end
  input:SetText(ns:GetBuffReminderSettings().custom)
  UI.SetControlEnabled(preview,ns:GetBuffReminderSettings().enabled)
 end
 window:SetScript("OnShow",function(self)self:Refresh()end)
 window:Refresh();window:Show()
end
