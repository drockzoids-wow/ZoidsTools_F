local _, ns = ...
local watcher, bar, controller, title
local buttons, entries = {}, {}
local dirty = true
local nearby = false
local scanElapsed, tickElapsed = 0, 0
local moving = false

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not Secret(value) then return value end
end

local function Number(value)
    if not Secret(value) and type(value) == "number" and value >= 0 and value < math.huge then return value end
end

local function Text(value)
    if Secret(value) or type(value) ~= "string" then return nil end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

function ns:HasCampfireBuff()
    if InCombat() then return false end
    for index = 1, 255 do
        local aura = Call(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        local name
        if type(aura) == "table" then
            name = aura.name
        elseif not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
            name = Call(UnitBuff, "player", index)
            if name == nil then break end
        elseif aura == nil then
            break
        end
        local normalizedName = Text(name)
        if normalizedName == "welcoming campfire" or normalizedName == "campfire nearby" then return true end
    end
    return false
end

local function RequiresCampfire(bag, slot)
    local data = Call(C_TooltipInfo and C_TooltipInfo.GetBagItem, bag, slot)
    if type(data) ~= "table" or Secret(data.lines) or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        if not Secret(line) and type(line) == "table" then
            for _, key in ipairs({ "leftText", "rightText" }) do
                local text = Text(line[key])
                if text and text:find("requires%s+a%s+campfire%s+nearby") then return true end
            end
        end
    end
    return false
end

local function IsRecipe(itemID)
    local fn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(fn) ~= "function" then return false end
    local ok, _, _, _, _, _, classID = pcall(fn, itemID)
    return ok and not Secret(classID) and classID == 9
end

function ns:FindCampfireItems()
    local found, byID, counts = {}, {}, {}
    if not C_Container then return found end
    local lastBag = Number(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or Number(NUM_BAG_SLOTS) or 4
    for bag = 0, math.min(lastBag, 5) do
        local slots = Number(Call(C_Container.GetContainerNumSlots, bag)) or 0
        for slot = 1, slots do
            local info = Call(C_Container.GetContainerItemInfo, bag, slot)
            if type(info) == "table" then
                local id = Number(info.itemID)
                if id and id > 0 then
                    counts[id] = (counts[id] or 0) + (Number(info.stackCount) or 1)
                    local entry = byID[id]
                    if not entry and RequiresCampfire(bag, slot) and not IsRecipe(id)
                        and Call(C_Item and C_Item.GetItemSpell or GetItemSpell, id) then
                        entry = { id = id, count = 0, bag = bag, slot = slot,
                            icon = not Secret(info.iconFileID) and info.iconFileID or 134400 }
                        byID[id] = entry
                        found[#found + 1] = entry
                    end
                end
            end
        end
    end
    for _, entry in ipairs(found) do entry.count = counts[entry.id] end
    table.sort(found, function(a, b) return a.id < b.id end)
    return found
end

local function HideTooltip(button)
    if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function StopMoving()
    if not moving or not bar then return end
    if InCombat() then return end
    bar:StopMovingOrSizing()
    moving = false
    local point, _, relativePoint, x, y = bar:GetPoint()
    local db = ns.db.campfire
    db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
end

local function CreateBar()
    if bar then return true end
    if InCombat() or type(RegisterStateDriver) ~= "function" then return false end
    controller = CreateFrame("Frame", "ZoidsTools_FCampfireCombat", UIParent, "SecureHandlerStateTemplate")
    controller:SetAllPoints(UIParent)
    RegisterStateDriver(controller, "visibility", "[combat] hide; show")
    bar = CreateFrame("Frame", "ZoidsTools_FCampfireBar", controller, "BackdropTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function()
        if InCombat() then return end
        bar:StartMoving()
        moving = true
    end)
    bar:SetScript("OnDragStop", StopMoving)
    bar:SetScript("OnHide", function()
        StopMoving()
        for _, button in ipairs(buttons) do HideTooltip(button) end
    end)
    ns.UI.Theme.ApplyPanelBackdrop(bar)
    title = bar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -6)
    title:SetText("CAMPFIRE NEARBY")
    title:SetTextColor(unpack(ns.UI.Theme.colors.gold))
    local db = ns.db.campfire
    bar:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    bar:Hide()
    return true
end

local function CreateButton(index)
    local button = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetSize(32, 32)
    button:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropBorderColor(0.82, 0.62, 0.28, 1)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", "item")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", -1, 1)
    button:SetScript("OnEnter", function(self)
        if self.entry and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.entry.id)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", HideTooltip)
    buttons[index] = button
    return button
end

local function UpdateCooldowns()
    local fn = C_Item and C_Item.GetItemCooldown or GetItemCooldown
    for i, entry in ipairs(entries) do
        local button = buttons[i]
        if button then
            local start, duration, enabled
            if type(fn) == "function" then
                local ok, a, b, c = pcall(fn, entry.id)
                if ok then start, duration, enabled = Number(a), Number(b), not Secret(c) and c end
            end
            if start and duration and (enabled == true or enabled == 1) then
                button.cooldown:SetCooldown(start, duration)
            else
                button.cooldown:Clear()
            end
        end
    end
end

local function Layout()
    local columns = math.min(10, #entries)
    local itemWidth = columns * 36 - 4
    local width = math.max(math.ceil(title:GetStringWidth()) + 16, itemWidth + 12)
    bar:SetSize(width, math.ceil(#entries / 10) * 36 + 28)
    for i, entry in ipairs(entries) do
        local button = buttons[i] or CreateButton(i)
        if not button.entry or button.entry.id ~= entry.id then HideTooltip(button) end
        button.entry = entry
        -- Item-ID binding stays correct if the player sorts bags or uses up a stack.
        button:SetAttribute("item1", "item:" .. entry.id)
        button:ClearAllPoints()
        local row = math.floor((i - 1) / 10)
        local rowWidth = math.min(10, #entries - row * 10) * 36 - 4
        button:SetPoint("TOPLEFT", (width - rowWidth) / 2 + ((i - 1) % 10) * 36, -24 - row * 36)
        button.icon:SetTexture(entry.icon or 134400)
        button.count:SetText(entry.count > 1 and tostring(entry.count) or "")
        button:Show()
    end
    for i = #entries + 1, #buttons do
        HideTooltip(buttons[i])
        buttons[i]:Hide()
        buttons[i]:SetAttribute("item1", nil)
        buttons[i].entry = nil
    end
end

function ns:GetCampfireBarEnabled()
    return self.db and self.db.campfire and self.db.campfire.enabled == true
end

function ns:GetCampfireBarStatus()
    if not self:GetCampfireBarEnabled() then return "Campfire bar is disabled." end
    if type(RegisterStateDriver) ~= "function" then return "Campfire bar is unavailable on this client." end
    if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then return "Item tooltip scanning is unavailable on this client." end
    if InCombat() then return "Campfire bar is hidden during combat." end
    if not nearby then return "Waiting for Welcoming Campfire or Campfire Nearby. Found " .. #entries .. " matching item types in your bags." end
    return #entries == 0 and "Campfire nearby, but no matching usable items found in your bags."
        or ("Campfire nearby: " .. #entries .. " item types available.")
end

function ns:RefreshCampfireBar(rescan)
    if rescan then dirty = true end
    if InCombat() then return end -- Secure driver handles combat visibility; defer all mutations.
    if not self:GetCampfireBarEnabled() then
        if bar then StopMoving(); bar:Hide() end
        return
    end
    if not CreateBar() then return end
    local wasNearby = nearby
    nearby = self:HasCampfireBuff()
    if nearby and not wasNearby then dirty = true end
    if dirty then
        entries = self:FindCampfireItems()
        dirty = false
        Layout()
    end
    bar:SetShown(nearby and #entries > 0)
    if nearby then UpdateCooldowns() end
end

function ns:SetCampfireBarEnabled(value)
    if self.db and self.db.campfire then self.db.campfire.enabled = value == true end
    self:RefreshCampfireBar(true)
end

function ns:InitializeCampfireBar()
    if watcher then return end
    watcher = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_AURA", "BAG_UPDATE_DELAYED",
        "GET_ITEM_INFO_RECEIVED", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED" }) do
        ns:RegisterCompatibleEvent(watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then StopMoving() end
        if event == "UNIT_AURA" and (Secret(unit) or unit ~= "player") then return end
        if event ~= "UNIT_AURA" and event ~= "SPELL_UPDATE_COOLDOWN" and event ~= "BAG_UPDATE_COOLDOWN" then dirty = true end
        self:RefreshCampfireBar()
    end)
    watcher:SetScript("OnUpdate", function(_, elapsed)
        tickElapsed, scanElapsed = tickElapsed + elapsed, scanElapsed + elapsed
        if tickElapsed < 0.25 then return end
        tickElapsed = 0
        if scanElapsed >= 2 then
            scanElapsed = 0
            if nearby then dirty = true end -- Retry delayed tooltip/item data while at camp.
        end
        self:RefreshCampfireBar()
    end)
    self:RefreshCampfireBar(true)
end
