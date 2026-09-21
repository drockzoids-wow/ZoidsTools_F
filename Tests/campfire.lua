secret = {}
function issecretvalue(v) return v == secret end
local combat = true
function InCombatLockdown() return combat end
UIParent = {}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
local frames, drivers = {}, {}
local function Safe() assert(not combat, 'Protected mutation in combat') end
local function Region()
    local r = {}
    function r:SetAllPoints() end
    function r:SetPoint() end
    function r:SetText(v) self.text = v end
    function r:GetStringWidth() return #self.text * 8 end
    function r:SetTextColor() end
    function r:SetTexture(v) self.texture = v end
    function r:SetTexCoord() end
    return r
end
function CreateFrame(kind, name, parent, template)
    local secure = template and (template:find('Secure') or (parent and parent.protected))
    if secure then Safe() end
    local f = { scripts = {}, attributes = {}, children = {}, shown = true, parent = parent,
        protected = secure or (parent and parent.protected), template = template }
    if parent and parent.children then table.insert(parent.children, f) end
    if name then _G[name] = f end
    frames[#frames + 1] = f
    local function Check(self) if self.protected then Safe() end end
    function f:SetSize(w,h) Check(self); self.width,self.height = w,h end
    function f:SetPoint(...) Check(self); self.point = {...} end
    function f:GetPoint() return unpack(self.point) end
    function f:ClearAllPoints() Check(self) end
    function f:SetAllPoints() Check(self) end
    function f:SetFrameStrata() end
    function f:SetClampedToScreen() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:RegisterForClicks(...) self.clicks = {...} end
    function f:SetHighlightTexture() end
    function f:SetBackdrop(v) self.backdrop = v end
    function f:SetBackdropBorderColor(...) self.borderColor = {...} end
    function f:RegisterEvent() end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:SetAttribute(k,v) Check(self); self.attributes[k] = v end
    function f:CreateTexture() return Region() end
    function f:CreateFontString() return Region() end
    function f:SetCooldown(start,duration) self.cooldownValues = {start,duration} end
    function f:Clear() self.cooldownValues = nil end
    function f:SetShown(v)
        Check(self)
        local old = self.shown
        self.shown = v
        if old and not v and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:Show() self:SetShown(true) end
    function f:Hide() self:SetShown(false) end
    function f:IsShown() return self.shown and (not self.parent or not self.parent.IsShown or self.parent:IsShown()) end
    function f:StartMoving() Check(self); self.moving = true end
    function f:StopMovingOrSizing() Check(self); self.moving = false end
    return f
end
function RegisterStateDriver(frame,state,condition)
    Safe()
    assert(state == 'visibility' and condition == '[combat] hide; show')
    drivers[#drivers + 1] = frame
    frame.shown = not combat
end
local function SetCombat(value)
    combat = value
    for _, frame in ipairs(drivers) do frame.shown = not value end
end
local buffs = {}
C_UnitAuras = { GetAuraDataByIndex = function(_,i,filter) assert(filter == 'HELPFUL'); return buffs[i] end }
local bag = {
    {itemID=20, stackCount=2, iconFileID=200},
    {itemID=20, stackCount=3, iconFileID=200},
    {itemID=10, stackCount=1, iconFileID=100},
    {itemID=30, stackCount=1}, -- recipe
    {itemID=40, stackCount=1}, -- unrelated
    {itemID=50, stackCount=1}, -- delayed data
    {itemID=60, stackCount=1}, -- restricted tooltip
    {itemID=secret, stackCount=1},
}
local tooltipReady = false
local scanCalls = 0
C_Container = {
    GetContainerNumSlots = function(b) assert(b >= 0 and b <= 5); return b == 0 and #bag or 0 end,
    GetContainerItemInfo = function(_,slot) scanCalls = scanCalls + 1; return bag[slot] end,
}
C_TooltipInfo = { GetBagItem = function(_,slot)
    local id = bag[slot].itemID
    if id == 50 and not tooltipReady then return nil end
    if id == 60 then return {lines={{leftText=secret}}} end
    if id == 40 then return {lines={{leftText='Creates a campfire nearby.'}}} end
    return {lines={{leftText='Use: Builds an object. |cffff0000Requires a Campfire nearby.|r'}}}
end }
local cooldownSecret = false
C_Item = {
    GetItemSpell = function(id) return id ~= 10 and 'Use item' or nil end,
    GetItemInfoInstant = function(id) return id,nil,nil,nil,nil,id == 30 and 9 or 15 end,
    GetItemCooldown = function() if cooldownSecret then return secret,secret,secret end; return 10,3600,true end,
}
GameTooltip = {}
function GameTooltip:IsOwned(owner) return self.owner == owner end
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:SetHyperlink(link) self.link = link end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false; self.owner = nil end

function RunCampfireTests(ns)
    ns:InitializeCampfireBar()
    ns:InitializeCampfireBar()
    assert(#frames == 1 and not ZoidsTools_FCampfireBar, 'Combat login must defer construction')
    local watcher = frames[1]
    SetCombat(false)
    watcher.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED')
    local bar = ZoidsTools_FCampfireBar
    assert(bar and not bar:IsShown())
    local found = ns:FindCampfireItems()
    assert(#found == 1 and found[1].id == 20 and found[1].count == 5)
    buffs = {{name='Cozy Fire'}}
    watcher.scripts.OnEvent(nil,'UNIT_AURA','player')
    assert(not bar:IsShown(), 'Unrelated fire buffs must not show the bar')
    buffs = {{name='Campfire Nearby'}}
    watcher.scripts.OnEvent(nil,'UNIT_AURA','player')
    assert(bar:IsShown(), 'Campfire Nearby alone must show the bar with matching items')
    for _, spellID in ipairs({1229739, 1283391, 1289723}) do
        buffs = {{name='Localized campfire name', spellId=spellID}}
        assert(ns:HasCampfireBuff(), 'Known aura IDs must work in every locale')
    end
    buffs = {{name=secret, spellId=secret}}
    assert(not ns:HasCampfireBuff(), 'Restricted aura IDs must be skipped')
    buffs = {}
    watcher.scripts.OnEvent(nil,'UNIT_AURA','player')
    assert(not bar:IsShown(), 'Removing Campfire Nearby must hide the bar')
    buffs = {{name='Welcoming Campfire'}}
    watcher.scripts.OnEvent(nil,'UNIT_AURA','player')
    assert(bar:IsShown())
    local button = bar.children[1]
    assert(button.attributes.type1 == 'item' and button.attributes.item1 == 'item:20')
    assert(button.attributes.useOnKeyDown == false and #button.clicks == 1 and button.clicks[1] == 'LeftButtonUp')
    assert(button.count.text == '5' and button.cooldown.cooldownValues[2] == 3600)
    assert(button.scripts.OnClick == nil, 'Item use must remain in the secure template')
    button.scripts.OnEnter(button)
    assert(GameTooltip.link == 'item:20')
    watcher.scripts.OnUpdate(nil,2.1)
    assert(GameTooltip.owner == button and GameTooltip.shown, "Unchanged rescans must preserve hover tooltips")
    tooltipReady = true
    watcher.scripts.OnUpdate(nil,2.1)
    assert(#ns:FindCampfireItems() == 2 and bar.children[2].attributes.item1 == 'item:50')
    bar.scripts.OnDragStart()
    watcher.scripts.OnUpdate(nil,0.3)
    assert(bar.moving, 'Periodic updates must not interrupt dragging')
    bar:SetPoint('CENTER',UIParent,'CENTER',45,67)
    bar.scripts.OnDragStop()
    assert(ns.db.campfire.x == 45 and ns.db.campfire.y == 67)
    local scansBeforeCombat = scanCalls
    SetCombat(true)
    buffs = {}
    bag = {{itemID=50,stackCount=1,iconFileID=500}}
    watcher.scripts.OnEvent(nil,'BAG_UPDATE_DELAYED')
    watcher.scripts.OnUpdate(nil,2.1)
    assert(not bar:IsShown() and scanCalls == scansBeforeCombat)
    SetCombat(false)
    watcher.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED')
    assert(not bar:IsShown() and bar.children[1].attributes.item1 == 'item:50')
    assert(not bar.children[2].shown and bar.children[2].attributes.item1 == nil)
    buffs = {{name=secret},{name='Welcoming Campfire'}}
    watcher.scripts.OnEvent(nil,'UNIT_AURA','player')
    assert(bar:IsShown())
    cooldownSecret = true
    watcher.scripts.OnEvent(nil,'SPELL_UPDATE_COOLDOWN')
    assert(bar.children[1].cooldown.cooldownValues == nil)
    ns:SetCampfireBarEnabled(false)
    assert(not bar:IsShown())
    ns:SetCampfireBarEnabled(true)
    assert(bar:IsShown())
    bag = {}
    watcher.scripts.OnEvent(nil,'BAG_UPDATE_DELAYED')
    assert(not bar:IsShown())
    C_UnitAuras = nil
    function UnitBuff(_,index) return index == 1 and 'Welcoming Campfire' or nil end
    assert(ns:HasCampfireBuff())
    function UnitBuff(_,index) return index == 1 and 'Campfire Nearby' or nil end
    assert(ns:HasCampfireBuff(), 'Legacy aura lookup must also accept Campfire Nearby')
    C_TooltipInfo = nil
    assert(#ns:FindCampfireItems() == 0)
    bag = {{itemID=279978, stackCount=3, iconFileID=100}, {itemID=40, stackCount=1}}
    local localizedItems = ns:FindCampfireItems()
    assert(#localizedItems == 1 and localizedItems[1].id == 279978 and localizedItems[1].count == 3,
        'Known camping items must not depend on an English or available tooltip')
    function UnitBuff() return 'Localized buff', nil, nil, nil, nil, nil, nil, nil, nil, 1283391 end
    assert(ns:HasCampfireBuff(), 'Legacy aura spell IDs must work in every locale')
end
