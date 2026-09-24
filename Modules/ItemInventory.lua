local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
-- Inventory snapshots are stored separately from addon settings.

local initialized, bankOpen, queued, currentKey
local dirtyBags, dirtyBank = true, false
local cachedID, cachedEntry
local worldActive, loggingOut = true, false

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function Safe(value, kind)
    return not IsSecret(value) and type(value) == kind
end

local function DB()
    if type(ZoidsTools_FInventoryDB) ~= "table" then ZoidsTools_FInventoryDB = {} end
    local db = ZoidsTools_FInventoryDB
    if type(db.characters) ~= "table" then db.characters = {} end
    if type(db.account) ~= "table" then db.account = {} end
    return db
end

local function Character()
    if not UnitGUID then return end
    local key = UnitGUID("player")
    if not Safe(key, "string") then return end
    currentKey = key
    local db = DB()
    local name, realm = (UnitFullName or UnitName)("player")
    local _, class = UnitClass("player")
    if not Safe(name, "string") or IsSecret(realm) or IsSecret(class) then return end
    db.characters[key] = db.characters[key] or { containers = {} }
    local character = db.characters[key]
    character.name = name or "Unknown"
    character.realm = realm and realm ~= "" and realm or GetRealmName()
    character.class = class
    return character
end

-- Build a complete replacement first. Unavailable/restricted data must never
-- erase a previously readable bank snapshot.
local function ScanContainer(bag, label, requireSlots)
    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    if type(getSlots) ~= "function" then return end
    local ok, slots = pcall(getSlots, bag)
    if not ok then return end
    if not Safe(slots, "number") or slots < 0 or (requireSlots and slots == 0) then return end
    local snapshot = { label = label, items = {} }
    for slot = 1, slots do
        local ok, info
        if C_Container and C_Container.GetContainerItemInfo then
            ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        elseif GetContainerItemInfo then
            local texture, count, locked, quality, readable, lootable, link, filtered, id
            ok, texture, count, locked, quality, readable, lootable, link, filtered, id = pcall(GetContainerItemInfo, bag, slot)
            if IsSecret(count) or IsSecret(id) then return end
            if id then info = { itemID = id, stackCount = count, hyperlink = link } end
        end
        if not ok then return end
        if IsSecret(info) then return end
        if info then
            if not Safe(info.itemID, "number") or not Safe(info.stackCount, "number") then return end
            local id = info.itemID
            local item = snapshot.items[id] or { count = 0 }
            item.count = item.count + info.stackCount
            if Safe(info.hyperlink, "string") then
                item.name = info.hyperlink:match("%[(.-)%]") or item.name
            end
            snapshot.items[id] = item
        end
    end
    return snapshot
end

local function ScanBags(character)
    local bags = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do bags[bag] = true end
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then bags[Enum.BagIndex.ReagentBag] = true end
    for bag in pairs(bags) do
        local snapshot = ScanContainer(bag, "Bags")
        if snapshot then character.containers["bag" .. bag] = snapshot end
    end
    if not GetInventoryItemID then return end
    local equipped = { label = "Equipped", items = {} }
    for slot = 1, 19 do
        local ok, id = pcall(GetInventoryItemID, "player", slot)
        if not ok or IsSecret(id) then return end
        if Safe(id, "number") then
            local item = equipped.items[id] or { count = 0 }
            item.count = item.count + 1
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
            if Safe(link, "string") then item.name = link:match("%[(.-)%]") end
            equipped.items[id] = item
        end
    end
    character.containers.equipped = equipped
end

local function ScanBank(target, bankType, account)
    if not bankOpen then return end
    if bankType and C_Bank and C_Bank.FetchPurchasedBankTabData then
        if C_Bank.CanViewBank then
            local ok, visible = pcall(C_Bank.CanViewBank, bankType)
            if not ok or not Safe(visible, "boolean") or not visible then return end
        end
        if C_Bank.FetchBankLockedReason then
            local ok, reason = pcall(C_Bank.FetchBankLockedReason, bankType)
            if not ok or IsSecret(reason) or (reason ~= nil and
                reason ~= (Enum.BankLockedReason and Enum.BankLockedReason.None)) then return end
        end
        local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
        if not ok or not Safe(tabs, "table") then return end
        for index, tab in ipairs(tabs) do
            if Safe(tab, "table") and Safe(tab.ID, "number") then
                local label = (account and "Warband bank " or "Bank ") .. index
                local snapshot = ScanContainer(tab.ID, label, true)
                if snapshot then target["bank" .. tab.ID] = snapshot end
            end
        end
        return
    end
    if account then return end
    -- Older clients without tab APIs use a main bank container and bank bags.
    local snapshot = ScanContainer(BANK_CONTAINER or -1, "Bank", true)
    if snapshot then target.mainBank = snapshot end
    local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do
        snapshot = ScanContainer(bag, "Bank")
        if snapshot then target["bank" .. bag] = snapshot end
    end
    if REAGENTBANK_CONTAINER then
        snapshot = ScanContainer(REAGENTBANK_CONTAINER, "Reagent bank", true)
        if snapshot then target.reagentBank = snapshot end
    end
end

local function Notify()
    cachedID, cachedEntry = nil, nil
end

local function Capture()
    if loggingOut or not worldActive or (InCombatLockdown and InCombatLockdown())
        or (not dirtyBags and not dirtyBank) then return end
    local character = Character()
    if not character then return end
    if dirtyBags then
        dirtyBags = false
        ScanBags(character)
    end
    if dirtyBank then
        dirtyBank = false
        ScanBank(character.containers, Enum and Enum.BankType and Enum.BankType.Character)
        ScanBank(DB().account, Enum and Enum.BankType and Enum.BankType.Account, true)
    end
    Notify()
end

local function Queue()
    if queued or loggingOut or not worldActive then return end
    queued = true
    local function Run()
        queued = false
        Capture()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, Run) else Run() end
end

local function GetEntry(id)
    if cachedID == id then return cachedEntry end
    -- Look up only the requested item in each container. Retain one result,
    -- rather than duplicating every character's entire inventory in an index.
    local entry
    local function Add(containers, key, owner, class)
        for containerKey, snapshot in pairs(containers) do
            local item = snapshot.items[id]
            if item and item.count > 0 then
                entry = entry or { id = id, count = 0, locations = {} }
                entry.name = entry.name or item.name
                entry.count = entry.count + item.count
                -- Merge bag counts for each character, retain distinct bank tabs.
                local locationKey = key .. ":" .. snapshot.label
                local location = entry.locations[locationKey] or {
                    key = key, owner = owner, class = class, label = snapshot.label,
                    count = 0, kind = containerKey == "equipped" and "Equipped"
                        or containerKey:match("^bag") and "Bags" or "Bank",
                }
                location.count = location.count + item.count
                entry.locations[locationKey] = location
            end
        end
    end
    for key, character in pairs(DB().characters) do
        Add(character.containers, key, character.name .. "-" .. character.realm, character.class)
    end
    Add(DB().account, "account", "Warband", nil)
    cachedID, cachedEntry = id, entry
    return entry
end

function ns:GetWarbandItemLocations(id)
    local entry = GetEntry(id)
    local locations = {}
    for _, location in pairs(entry and entry.locations or {}) do locations[#locations + 1] = location end
    table.sort(locations, function(a, b)
        if a.key ~= b.key then
            if a.key == currentKey then return true end
            if b.key == currentKey then return false end
            if a.owner ~= b.owner then return a.owner < b.owner end
            return a.key < b.key
        end
        return a.label < b.label
    end)
    return locations, entry and entry.count or 0
end

function ns:GetWarbandItemTooltipsEnabled() return ns.db and ns.db.tooltips and ns.db.tooltips.itemCounts ~= false end
function ns:SetWarbandItemTooltipsEnabled(value) ns.db.tooltips.itemCounts = value == true end

function ns:AddWarbandItemTooltip(tooltip, id)
    if not Safe(id, "number") then return end
    local locations, total = self:GetWarbandItemLocations(id)
    if total == 0 then return end
    tooltip:AddLine(" ")
    local function Count(label, count)
        return "|cff80bfff" .. L[label] .. ":|r " .. count
    end
    tooltip:AddDoubleLine(L["Inventory"], Count("Total", total), 1, 0.82, 0, 1, 1, 1)
    local owners, ordered, names = {}, {}, {}
    for _, location in ipairs(locations) do
        local owner = owners[location.key]
        if not owner then
            local character = DB().characters[location.key]
            owner = { key = location.key, name = character and character.name or "Warband",
                realm = character and character.realm, class = location.class, counts = {} }
            owners[location.key] = owner
            ordered[#ordered + 1] = owner
            names[owner.name] = (names[owner.name] or 0) + 1
        end
        owner.counts[location.kind] = (owner.counts[location.kind] or 0) + location.count
    end
    -- Keep the shared bank after the character rows.
    table.sort(ordered, function(a, b)
        if a.key == b.key then return false end
        if a.key == "account" then return false end
        if b.key == "account" then return true end
        if a.key == currentKey then return true end
        if b.key == currentKey then return false end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    for _, owner in ipairs(ordered) do
        local counts = {}
        for _, kind in ipairs({ "Bags", "Bank", "Equipped" }) do
            if owner.counts[kind] then counts[#counts + 1] = Count(kind, owner.counts[kind]) end
        end
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[owner.class]
        local label = owner.name
        if names[label] > 1 and owner.realm then label = label .. "-" .. owner.realm end
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[owner.class]
        if coords then
            label = string.format("|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:16:16:0:0:256:256:%d:%d:%d:%d|t ",
                coords[1] * 256, coords[2] * 256, coords[3] * 256, coords[4] * 256) .. label
        elseif owner.key == "account" then
            label = "|TInterface\\Icons\\Spell_Fire_Fire:16:16|t " .. label
        end
        tooltip:AddDoubleLine(label, table.concat(counts, ", "), color and color.r or 1,
            color and color.g or 0.82, color and color.b or 0, 1, 1, 1)
    end
end

function ns:InitializeWarbandItems()
    if initialized then return end
    initialized = true
    local db = DB()
    -- Drop obsolete timestamps from previously recorded characters and banks.
    for _, character in pairs(db.characters) do
        for _, snapshot in pairs(character.containers) do snapshot.updated = nil end
    end
    for _, snapshot in pairs(db.account) do snapshot.updated = nil end
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
        "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED",
        "BAG_CONTAINER_UPDATE", "PLAYERREAGENTBANKSLOTS_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do pcall(frame.RegisterEvent, frame, event) end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGOUT" then
            -- Inventory APIs can already be empty during logout. SavedVariables
            -- retain the last event-driven scan without a final rescan.
            loggingOut = true
            return
        elseif loggingOut then
            return
        elseif event == "PLAYER_LEAVING_WORLD" then
            worldActive, bankOpen = false, false
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            worldActive, dirtyBags = true, true
            dirtyBank = bankOpen == true
        elseif event == "BANKFRAME_CLOSED" then
            -- Flush pending changes while bank data is still readable, if the
            -- client retains access during the close notification.
            if dirtyBank then Capture() end
            bankOpen = false
        elseif event == "BANKFRAME_OPENED" then
            bankOpen, dirtyBank = true, true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if not dirtyBags and not dirtyBank then return end
        else
            dirtyBags = true
            dirtyBank = bankOpen == true
        end
        Queue()
    end)
    local function Reset(tooltip) tooltip.ZTFInventoryApplied = nil end
    local function Apply(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        if tooltip.ZTFInventoryApplied or not ns:GetWarbandItemTooltipsEnabled() then return end
        local id = Safe(data, "table") and data.id
        if not Safe(id, "number") then return end
        tooltip.ZTFInventoryApplied = true
        ns:AddWarbandItemTooltip(tooltip, id)
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and TooltipDataProcessor.AddTooltipPreCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes, Reset)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Apply)
    else
        for _, tooltip in pairs({ GameTooltip, ItemRefTooltip }) do
            if tooltip.HookScript and tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
                tooltip:HookScript("OnTooltipCleared", Reset)
                tooltip:HookScript("OnTooltipSetItem", function(self)
                    local ok, _, link = pcall(self.GetItem, self)
                    if ok and Safe(link, "string") then
                        Apply(self, { id = tonumber(link:match("item:(%d+)")) })
                    end
                end)
            end
        end
    end
    Queue()
end
