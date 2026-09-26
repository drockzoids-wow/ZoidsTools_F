-- Extend the settings widget model with hierarchy, hooks and restoration state.
local m=getmetatable(UIParent).__index
local frames={}
local create=CreateFrame
function CreateFrame(kind,name,parent,template)
 local f=create(kind,name,parent,template);f.points={};f.alpha=1;f.level=1;f.strata='MEDIUM'
 frames[#frames+1]=f;return f
end
function m:SetParent(v)self.parent=v end
function m:SetPoint(...)self.points=self.points or {};self.points[#self.points+1]={...}end
function m:ClearAllPoints()self.points={}end
function m:GetNumPoints()return #(self.points or {})end
function m:GetPoint(i)return unpack(self.points[i or 1])end
function m:GetChildren()local list={};for _,f in ipairs(frames)do if f.parent==self then list[#list+1]=f end end;return unpack(list)end
function m:GetObjectType()return self.kind end
function m:GetFrameStrata()return self.strata or 'MEDIUM'end
function m:SetFrameStrata(v)self.strata=v end
function m:GetFrameLevel()return self.level or 1 end
function m:SetFrameLevel(v)self.level=v end
function m:GetAlpha()return self.alpha or 1 end
function m:SetAlpha(v)self.alpha=v end
function m:IsProtected()return self.protected end
function m:IsForbidden()return false end
function m:IsMouseOver()return self.mouse end
function m:GetCenter()return 100,100 end
function m:GetEffectiveScale()return 1 end
function m:SetMaskTexture(v)self.mask=v end
function m:SetClampedToScreen(v)self.clamped=v end
function m:IsClampedToScreen()return self.clamped==true end
function m:GetMaskTexture()return self.mask end
function m:GetFont()return 'font',12,''end
function m:SetFont(font,size,flags)self.fontSize=size end
function m:GetUnboundedStringWidth()return self:GetStringWidth()end
function m:GetScript(e)return self.scripts[e]end
function m:HookScript(e,fn)local old=self.scripts[e];self.scripts[e]=function(...)if old then old(...)end;fn(...)end end
function m:Show()local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self)end end
function m:Hide()local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self)end end
function m:LockHighlight()end
function m:UnlockHighlight()end
local combat=false
function InCombatLockdown()return combat end
function UnitClass()return 'Druid','DRUID'end
RAID_CLASS_COLORS={DRUID={r=1,g=.5,b=0}}
function GetRealZoneText()return 'Test zone'end
function GetSubZoneText()return 'Test subzone'end
local timers={}
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local function flush()
 for i=1,20 do
  if #timers==0 then return end
  local batch=timers;timers={};for _,fn in ipairs(batch)do fn()end
 end
 error('Timers failed to settle')
end
local function widget(kind,name,parent)
 local f=CreateFrame(kind,name,parent);f:SetSize(30,30);f:SetPoint('CENTER',parent,'CENTER',10,20);return f
end
Minimap=widget('Frame','Minimap',UIParent);Minimap:SetSize(180,180);Minimap.mask='original-mask'
MinimapCluster=widget('Frame','MinimapCluster',UIParent)
MinimapBorder=widget('Frame','MinimapBorder',Minimap)
MinimapBorderTop=widget('Frame','MinimapBorderTop',Minimap)
MinimapCompassTexture=widget('Frame','MinimapCompassTexture',Minimap)
MinimapZoneTextButton=widget('Button','MinimapZoneTextButton',MinimapCluster)
MinimapZoneTextButton.Text=MinimapZoneTextButton:CreateFontString();MinimapZoneTextButton.Text:SetText('Test zone')
TimeManagerClockButton=widget('Button','TimeManagerClockButton',MinimapCluster)
local originalClicks=0
TimeManagerClockButton:SetScript('OnClick',function()originalClicks=originalClicks+1 end)
TimeManagerClockButton:CreateFontString()
MiniMapTracking=widget('Button','MiniMapTracking',MinimapCluster)
GameTimeFrame=widget('Button','GameTimeFrame',MinimapCluster)
MinimapCluster.DielFrame=widget('Frame',nil,MinimapCluster)
local calendarClicks,stopwatchClicks=0,0
function Calendar_Toggle()calendarClicks=calendarClicks+1 end
function Stopwatch_Toggle()stopwatchClicks=stopwatchClicks+1 end
MiniMapMailFrame=widget('Frame','MiniMapMailFrame',MinimapCluster)
AddonCompartmentFrame=widget('Button','AddonCompartmentFrame',MinimapCluster)
local addon=widget('Button','LibDBIcon10_TestAddon',Minimap);addon:SetAlpha(.8)
local protected=widget('Button','ProtectedAddon',Minimap);protected.protected=true
local pin=widget('Button','GatherMatePin1',Minimap)
local originalShape=function()return 'ROUND'end
GetMinimapShape=originalShape
function RunMinimapTests(ns)
 ns:InitializeMinimapTools();flush()
 MinimapCluster:SetClampedToScreen(true);Minimap:SetClampedToScreen(false)
 ns:RefreshMinimapTools()
 assert(not MinimapCluster:IsClampedToScreen() and not Minimap:IsClampedToScreen())
 combat=true;MinimapCluster:SetClampedToScreen(true);ns:RefreshMinimapTools()
 assert(MinimapCluster:IsClampedToScreen())
 combat=false;ns:RefreshMinimapTools()
 assert(not MinimapCluster:IsClampedToScreen() and not Minimap:IsClampedToScreen())
 assert(Minimap.mask=='original-mask' and addon.parent==Minimap)
 assert(MiniMapMailFrame.parent==MinimapCluster and not ZoidsTools_FMinimapButtonCollector)
 ns:SetSquareMinimapEnabled(true);flush()
 assert(Minimap.mask=='Interface\\BUTTONS\\WHITE8X8' and GetMinimapShape()=='SQUARE')
 assert(not MinimapBorder.shown and ZoidsTools_FSquareMinimapBorder.shown)
 ns:SetSquareMinimapEnabled(false);flush()
 assert(Minimap.mask=='original-mask' and GetMinimapShape==originalShape and MinimapBorder.shown)
 assert(select(2,MiniMapMailFrame:GetPoint())==MinimapCluster)
 ns:SetMinimapHeaderBarEnabled(true);flush()
 local bar=ZoidsTools_FMinimapInfoBar
 assert(bar.shown and TimeManagerClockButton.parent==bar and not GameTimeFrame.shown)
 assert(MinimapCluster.DielFrame.parent==Minimap and select(1,MinimapCluster.DielFrame:GetPoint())=='TOPRIGHT')
 TimeManagerClockButton.scripts.OnClick(TimeManagerClockButton,'LeftButton')
 TimeManagerClockButton.scripts.OnClick(TimeManagerClockButton,'RightButton')
 assert(calendarClicks==1 and stopwatchClicks==1 and originalClicks==0)
 assert(TimeManagerClockButton.regions[1].fontSize==10 and TimeManagerClockButton.width==38)
 assert(bar.zoneText.fontSize==12 and bar.subZoneText.fontSize==10)
 assert(bar.zoneText.text=='Test zone' and bar.subZoneText.text=='Test subzone')
 ns:SetMinimapHeaderBarEnabled(false);flush()
 assert(not bar.shown and TimeManagerClockButton.parent==MinimapCluster and GameTimeFrame.shown and GameTimeFrame.parent==MinimapCluster)
 assert(MinimapCluster.DielFrame.parent==MinimapCluster)
 assert(MinimapZoneTextButton.Text.text=='Test zone')
 TimeManagerClockButton.scripts.OnClick(TimeManagerClockButton,'RightButton');assert(originalClicks==1)
 ns:SetAddonCompartmentHidden(true);assert(not AddonCompartmentFrame.shown)
 ns:SetAddonCompartmentHidden(false);assert(AddonCompartmentFrame.shown)
 ns:SetMinimapButtonsMouseoverEnabled(true);flush();assert(not addon.shown)
 Minimap.mouse=true;Minimap.scripts.OnEnter(Minimap);assert(addon.shown and addon.alpha==.8)
 Minimap.mouse=false;Minimap.scripts.OnLeave(Minimap);flush();assert(not addon.shown)
 ns:SetMinimapButtonCollectorEnabled(true);flush()
 local collector=ZoidsTools_FMinimapButtonCollector
 assert(collector.shown and addon.parent~=Minimap and protected.parent==Minimap and pin.parent==Minimap)
 collector.scripts.OnClick();assert(addon.shown and ZoidsTools_FMinimapButtonCollectorPanel.shown)
 combat=true
 ns:SetSquareMinimapEnabled(true);assert(GetMinimapShape()=='ROUND','Shape changes must defer in combat')
 collector.scripts.OnClick();assert(ZoidsTools_FMinimapButtonCollectorPanel.shown)
 combat=false
 for _,f in ipairs(frames)do if f.scripts.OnEvent then f.scripts.OnEvent(f,'PLAYER_REGEN_ENABLED')end end
 flush();assert(GetMinimapShape()=='SQUARE')
 ns:SetMinimapButtonsMouseoverEnabled(false);ns:SetMinimapButtonCollectorEnabled(false);flush()
 assert(addon.parent==Minimap and addon.shown and addon.alpha==.8 and not collector.shown)
 assert(select(4,addon:GetPoint())==10)
 -- Retail-only widgets can be absent on the Forever client.
 AddonCompartmentFrame=nil;TimeManagerClockButton=nil;GameTimeFrame=nil;MiniMapTracking=nil;MiniMapMailFrame=nil
 ns:SetMinimapHeaderBarEnabled(true);flush();ns:SetMinimapHeaderBarEnabled(false);flush()
 Minimap=nil;ns:RefreshMinimapTools()
end
