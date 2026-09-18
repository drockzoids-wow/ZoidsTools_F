local _, ns = ...
local frame, session

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not Secret(value) then return value end
end

local function Truth(value)
    return value == true or value == 1 or value == "1"
end

local function AutoLootIntent(value)
    if Secret(value) then return false end
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value == 1 end
    local default = Call(C_CVar and C_CVar.GetCVarBool or GetCVarBool, "autoLootDefault")
    if default == nil then default = Call(C_CVar and C_CVar.GetCVar or GetCVar, "autoLootDefault") end
    return Truth(default) ~= Truth(Call(IsModifiedClick, "AUTOLOOTTOGGLE"))
end

function ns:GetFastLootEnabled()
    return self.db and self.db.loot and self.db.loot.fastLoot == true
end

function ns:SetFastLootEnabled(value)
    self.db.loot.fastLoot = value == true
    if not value then session = nil end
end

function ns:GetFastLootDelay()
    local value = tonumber(self.db.loot.slotDelay) or 0
    if value ~= value then value = 0 end
    return math.max(0, math.min(0.2, value))
end

function ns:SetFastLootDelay(value)
    self.db.loot.slotDelay = tonumber(value) or 0
    self.db.loot.slotDelay = self:GetFastLootDelay()
end

local function TrySlot(slot)
    if type(GetLootSlotInfo) == "function" then
        local ok, _, _, _, _, _, locked = pcall(GetLootSlotInfo, slot)
        if not ok or Secret(locked) or locked then return end
    end
    if type(LootSlot) == "function" then pcall(LootSlot, slot) end
end

local function StartPass(current)
    if session ~= current or not ns:GetFastLootEnabled() then return end
    local count = Call(GetNumLootItems)
    if type(count) ~= "number" or count < 1 or count ~= math.floor(count) then return end
    local delay = ns:GetFastLootDelay()
    local function Visit(slot)
        if session ~= current or not ns:GetFastLootEnabled() then return end
        TrySlot(slot)
    end
    -- Snapshot once, descending: each slot is attempted at most once this visit.
    for slot = count, 1, -1 do
        if delay > 0 and C_Timer and C_Timer.After then
            local index = slot
            C_Timer.After((count - slot) * delay, function() Visit(index) end)
        else
            Visit(slot)
        end
    end
end

function ns:InitializeFastLoot()
    if frame then return end
    frame = CreateFrame("Frame")
    for _, event in ipairs({ "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED" }) do
        ns:RegisterCompatibleEvent(frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, autoLoot)
        if event == "LOOT_CLOSED" then session = nil; return end
        if not ns:GetFastLootEnabled() or not AutoLootIntent(autoLoot) then
            session = nil
            return
        end
        if session then return end -- READY + OPENED must not cause a second pass.
        local count = Call(GetNumLootItems)
        if type(count) ~= "number" or count < 1 then return end
        local current = {}
        session = current
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() StartPass(current) end)
        else
            StartPass(current)
        end
    end)
end
