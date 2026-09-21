-- Lightweight widget model: verify every translated settings page builds and refreshes.
local methods = {}
local objects = {}
local function New(kind, name, parent)
    local object = setmetatable({kind=kind, name=name, parent=parent, scripts={}, regions={},
        width=0, height=0, shown=true, enabled=true}, {__index=methods})
    objects[#objects+1] = object
    if name then _G[name] = object end
    return object
end
for _, method in ipairs({"SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "RegisterForClicks", "RegisterEvent", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetTextColor", "SetJustifyH", "SetJustifyV", "SetHitRectInsets", "SetColorTexture", "SetAlpha",
    "SetTexCoord", "SetTexture", "SetVertexColor", "SetBlendMode", "SetFrameLevel", "SetAllPoints",
    "SetAutoFocus", "EnableMouseWheel", "SetValueStep", "SetObeyStepOnDrag", "SetMinMaxValues",
    "SetOrientation", "SetThumbTexture", "SetHighlightTexture", "SetNormalTexture", "SetPushedTexture",
    "StartMoving", "StopMovingOrSizing", "SetClipsChildren", "SetToplevel"}) do methods[method]=function() end end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return 1 end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:IsEnabled() return self.enabled end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetText(v) assert(type(v)=='string' or type(v)=='number'); self.text=tostring(v) end
function methods:GetText() return self.text or '' end
function methods:GetStringWidth() return #(self.text or '')*6 end
function methods:SetWordWrap(v) self.wrap=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetValue(v) self.value=v end
function methods:SetScript(e,fn) self.scripts[e]=fn end
function methods:HookScript() end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:IsObjectType(kind) return self.kind==kind end
function methods:GetRegions() return unpack(self.regions) end
function methods:CreateTexture() local r=New('Texture',nil,self); self.regions[#self.regions+1]=r; return r end
function methods:CreateFontString() local r=New('FontString',nil,self); self.regions[#self.regions+1]=r; return r end
function CreateFrame(kind,name,parent,template)
    local frame=New(kind,name,parent)
    if template=='OptionsSliderTemplate' then
        for _,suffix in ipairs({'Text','Low','High'}) do _G[name..suffix]=New('FontString',nil,frame) end
    end
    return frame
end
UIParent=CreateFrame('Frame')
UISpecialFrames={}; SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function InCombatLockdown() return false end
function GetBuildInfo() return '1.60.1','69893','',160001 end
function InitializeTestSettings()
    for _, object in ipairs(objects) do
        if object.scripts.OnEvent then
            object.scripts.OnEvent(object,'ADDON_LOADED','ZoidsTools_F')
        end
    end
end
function VerifySettings(ns)
    for _,page in ipairs({'meters','windows','unitframes','castbars','vendor','tooltips','loot','quests','actionbars','stats','macros','completionist'}) do
        ns.UI2.Show(page)
    end
    assert(ZoidsTools_FSettings.width == ((ns.locale and ns.locale~='enUS') and 900 or 740))
    for _,object in ipairs(objects) do
        if object.kind=='FontString' and object.text then
            assert(not object.text:find('ZXQ',1,true))
        end
    end
end
