local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })
-- Detection is adapted from retail ZoidsTools; macro ownership is separate.
local HEALTH_MACRO_NAME, MANA_MACRO_NAME = "ZTF Health", "ZTF Mana"
local MACRO_ICON = "INV_Misc_QuestionMark"
local CONSUMABLE_CLASS_ID, POTION_SUBCLASS_ID, FOOD_DRINK_SUBCLASS_ID = 0, 1, 5
local pendingItemInfo, pendingCombatUpdate, updateScheduled = false, false, false
local frame
local lastStatus = { health = L["Health macro disabled."], mana = L["Mana macro disabled."] }
local healthstones = { [5512]=true, [5511]=true, [5509]=true, [5510]=true, [9421]=true,
    [19004]=true, [19005]=true, [19006]=true, [19007]=true, [19008]=true, [19009]=true,
    [19010]=true, [19011]=true, [19012]=true, [19013]=true, [22103]=true,
    [22104]=true, [22105]=true, [224464]=true }
local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end
local function GetBagIds()
    local bags = {}
    local maxBag = NUM_BAG_SLOTS or 4

    for bag = 0, maxBag do
        bags[#bags + 1] = bag
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        bags[#bags + 1] = Enum.BagIndex.ReagentBag
    end

    return bags
end

local function GetContainerNumSlotsSafe(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end

    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function GetContainerItemIDSafe(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

---@type GameTooltip?
local tooltipScanner

local function ReadTooltipViaScanner(bag, slot)
    if not CreateFrame or not UIParent then
        return ""
    end

    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "ZoidsTools_FConsumableScannerTooltip", UIParent, "GameTooltipTemplate")
        ---@cast tooltipScanner GameTooltip
        tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end

    tooltipScanner:ClearLines()

    if tooltipScanner.SetBagItem then
        local ok = pcall(tooltipScanner.SetBagItem, tooltipScanner, bag, slot)

        if not ok then
            return ""
        end
    end

    local lines = {}
    local count = tooltipScanner:NumLines() or 0

    for index = 1, count do
        local left = _G["ZoidsTools_FConsumableScannerTooltipTextLeft" .. index]
        local right = _G["ZoidsTools_FConsumableScannerTooltipTextRight" .. index]

        if left and left.GetText then
            local text = left:GetText()

            if not IsSecretValue(text) and type(text) == "string" and text ~= "" then
                lines[#lines + 1] = text
            end
        end

        if right and right.GetText then
            local text = right:GetText()

            if not IsSecretValue(text) and type(text) == "string" and text ~= "" then
                lines[#lines + 1] = text
            end
        end
    end

    return table.concat(lines, "\n")
end

local function ReadTooltipText(bag, slot)
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)

        if ok and type(data) == "table" and type(data.lines) == "table" then
            local lines = {}

            for _, line in ipairs(data.lines) do
                if not IsSecretValue(line.leftText)
                    and type(line.leftText) == "string"
                    and line.leftText ~= "" then
                    lines[#lines + 1] = line.leftText
                end

                if not IsSecretValue(line.rightText)
                    and type(line.rightText) == "string"
                    and line.rightText ~= "" then
                    lines[#lines + 1] = line.rightText
                end
            end

            if #lines > 0 then
                return table.concat(lines, "\n")
            end
        end
    end

    return ReadTooltipViaScanner(bag, slot)
end

local function ParseNumber(value)
    value = tostring(value or ""):gsub(",", "")
    return tonumber(value) or 0
end

local function GetPercentBase(kind)
    local ok, value

    if kind == "mana" and UnitPowerMax and Enum and Enum.PowerType then
        ok, value = pcall(UnitPowerMax, "player", Enum.PowerType.Mana)
    elseif kind == "mana" and UnitPowerMax then
        ok, value = pcall(UnitPowerMax, "player", 0)
    elseif UnitHealthMax then
        ok, value = pcall(UnitHealthMax, "player")
    end

    if not ok or IsSecretValue(value) or type(value) ~= "number" then
        return 0
    end

    return value
end

local function FindRestoreAmount(text, kind)
    local best = 0

    local function AddAmount(amount, percent)
        local value = ParseNumber(amount)

        if percent == "%" then
            local base = GetPercentBase(kind)

            if base <= 0 then
                return
            end

            value = base * (value / 100)
        end

        if value > best then
            best = value
        end
    end

    for amount, percent in text:gmatch("restores?%s+([%d,%.]+)(%%?)%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("restores?%s+([%d,%.]+)(%%?)%s+of%s+your%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("restoring%s+([%d,%.]+)(%%?)%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("restoring%s+([%d,%.]+)(%%?)%s+of%s+your%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("and%s+([%d,%.]+)(%%?)%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("and%s+([%d,%.]+)(%%?)%s+of%s+your%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for low, high in text:gmatch("restores?%s+([%d,%.]+)%s+to%s+([%d,%.]+)%s+" .. kind) do
        AddAmount((ParseNumber(low) + ParseNumber(high)) / 2, "")
    end

    return best
end

local function LooksLikeBuffFood(text)
    return text:find("well fed", 1, true)
        or text:find("increase your", 1, true)
        or text:find("increases your", 1, true)
        or text:find("gain ", 1, true) and text:find(" for ", 1, true)
end

local function ContainsAny(text, values)
    for _, value in ipairs(values) do
        if text:find(value, 1, true) then
            return true
        end
    end

    return false
end

local function LooksLikePotion(name, text, itemSubType, classID, subclassID)
    return name:find("potion", 1, true)
        or text:find("potion", 1, true)
        or name:find("serum", 1, true)
        or text:find("serum", 1, true)
        or (classID == CONSUMABLE_CLASS_ID and subclassID == POTION_SUBCLASS_ID)
        or string.lower(itemSubType or ""):find("potion", 1, true)
end

local function LooksLikeNonFoodConsumable(name, text)
    return LooksLikePotion(name, text)
        or name:find("flask", 1, true)
        or text:find("flask", 1, true)
        or name:find("phial", 1, true)
        or text:find("phial", 1, true)
        or name:find("elixir", 1, true)
        or text:find("elixir", 1, true)
        or name:find("healthstone", 1, true)
        or text:find("healthstone", 1, true)
end

local function LooksLikeFoodDrinkSubtype(itemSubType, classID, subclassID)
    local subtype = string.lower(itemSubType or "")

    return subtype:find("food", 1, true)
        or subtype:find("drink", 1, true)
        or (classID == CONSUMABLE_CLASS_ID and subclassID == FOOD_DRINK_SUBCLASS_ID)
end

local function LooksLikeMageFood(name, text)
    return name:find("conjured", 1, true)
        or text:find("conjured", 1, true)
        or name:find("mana bun", 1, true)
        or name:find("mana biscuit", 1, true)
        or name:find("mana strudel", 1, true)
        or name:find("mana pudding", 1, true)
        or name:find("conjured tea", 1, true)
end

local drinkNameHints = {
    "water",
    "drink",
    "tea",
    "juice",
    "milk",
    "wine",
    "mead",
    "brew",
    "coffee",
    "nectar",
    "cola",
    "cider",
    "punch",
    "draft",
    "draught",
    "latte",
    "mosa",
    "refreshment",
}

local foodNameHints = {
    "food",
    "bread",
    "bun",
    "biscuit",
    "strudel",
    "cake",
    "pie",
    "cookie",
    "rations",
    "meal",
    "stew",
    "soup",
    "jerky",
    "cheese",
    "fruit",
    "apple",
    "fish",
    "meat",
    "sandwich",
    "snack",
    "pudding",
}

local function ScoreCandidate(candidate)
    return (candidate.isMageFood and 1000000000000 or 0)
        + ((candidate.restore or 0) * 10000)
        + ((candidate.itemLevel or 0) * 100)
        + ((candidate.quality or 0) * 10)
        + (candidate.itemID or 0) / 1000000
end

local function BetterCandidate(current, candidate)
    if not candidate then
        return current
    end

    if not current or ScoreCandidate(candidate) > ScoreCandidate(current) then
        return candidate
    end

    return current
end

local function GetItemInfoSafe(itemID)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemID)
    end
    if GetItemInfo then return GetItemInfo(itemID) end
end

local function GetItemInfoInstantSafe(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(itemID)
    end
    if GetItemInfoInstant then return GetItemInfoInstant(itemID) end
end

local function GetFallbackRestore(candidate)
    local level = tonumber(candidate.itemLevel) or 0

    if level <= 0 then
        level = tonumber(candidate.requiredLevel) or 0
    end

    if level <= 0 then
        level = tonumber(candidate.itemID) or 0
    end

    return level
end

local function RequestItemInfo(itemID)
    pendingItemInfo = true

    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

local function BuildCandidate(itemID, bag, slot)
    local name, _, quality, itemLevel, requiredLevel, itemType, itemSubType, _, _, _, _, classID, subclassID = GetItemInfoSafe(itemID)
    local _, instantItemType, instantItemSubType, _, _, instantClassID, instantSubclassID = GetItemInfoInstantSafe(itemID)

    if not name then
        RequestItemInfo(itemID)
        return nil
    end
    if requiredLevel and UnitLevel and requiredLevel > UnitLevel("player") then return nil end

    itemType = itemType or instantItemType
    itemSubType = itemSubType or instantItemSubType
    classID = classID or instantClassID
    subclassID = subclassID or instantSubclassID

    local tooltip = ReadTooltipText(bag, slot)
    if tooltip == "" then pendingItemInfo = true; return nil end
    local lowerName = string.lower(name or "")
    local lowerTooltip = string.lower(tooltip or "")
    local healthRestore = FindRestoreAmount(lowerTooltip, "health")
    local manaRestore = FindRestoreAmount(lowerTooltip, "mana")
    local foodDrinkSubtype = LooksLikeFoodDrinkSubtype(itemSubType, classID, subclassID)
    local likelyDrinkName = ContainsAny(lowerName, drinkNameHints) or ContainsAny(lowerTooltip, drinkNameHints)
    local likelyFoodName = ContainsAny(lowerName, foodNameHints) or ContainsAny(lowerTooltip, foodNameHints)
    local candidate = {
        itemID = itemID,
        name = name,
        quality = quality or 0,
        itemLevel = itemLevel or 0,
        requiredLevel = requiredLevel or 0,
        itemType = itemType,
        itemSubType = itemSubType,
        classID = classID,
        subclassID = subclassID,
        tooltip = lowerTooltip,
        lowerName = lowerName,
        healthRestore = healthRestore,
        manaRestore = manaRestore,
    }

    if LooksLikeBuffFood(lowerTooltip) then
        candidate.isBuffFood = true
    end

    if LooksLikeMageFood(lowerName, lowerTooltip) then
        candidate.isMageFood = true
    end

    if LooksLikePotion(lowerName, lowerTooltip, itemSubType, classID, subclassID) then
        candidate.isPotion = true
    end

    local fallbackRestore = GetFallbackRestore(candidate)
    local validFoodDrink = foodDrinkSubtype and not candidate.isBuffFood and not LooksLikeNonFoodConsumable(lowerName, lowerTooltip)

    candidate.isHealthstone = healthstones[itemID] or lowerName:find("healthstone", 1, true)
    if candidate.isHealthstone then
        candidate.restore = healthRestore
        return candidate
    end

    if validFoodDrink and healthRestore > 0 then
        candidate.isFood = true
        candidate.restore = math.max(candidate.restore or 0, healthRestore)
    elseif validFoodDrink and healthRestore == 0 and manaRestore == 0 and (likelyFoodName or candidate.isMageFood or not likelyDrinkName) then
        candidate.isFood = true
        candidate.restore = math.max(candidate.restore or 0, fallbackRestore)
    end

    if validFoodDrink and manaRestore > 0 then
        candidate.isDrink = true
        candidate.restore = math.max(candidate.restore or 0, manaRestore)
    elseif validFoodDrink and healthRestore == 0 and manaRestore == 0 and (likelyDrinkName or candidate.isMageFood) then
        candidate.isDrink = true
        candidate.restore = math.max(candidate.restore or 0, fallbackRestore)
    end

    if candidate.isPotion and (healthRestore > 0 or lowerName:find("healing", 1, true) or lowerName:find("health", 1, true)) and not lowerName:find("mana", 1, true) then
        candidate.isHealthPotion = true
        candidate.restore = math.max(candidate.restore or 0, healthRestore, fallbackRestore)
    end

    if candidate.isPotion and (manaRestore > 0 or lowerName:find("mana", 1, true)) then
        candidate.isManaPotion = true
        candidate.restore = math.max(candidate.restore or 0, manaRestore, fallbackRestore)
    end

    return candidate
end

local function ScanConsumables()
    local best, seen = {}, {}
    pendingItemInfo = false
    for _, bag in ipairs(GetBagIds()) do
        for slot = 1, GetContainerNumSlotsSafe(bag) do
            local id = GetContainerItemIDSafe(bag, slot)
            if id and not seen[id] then
                seen[id] = true
                local candidate = BuildCandidate(id, bag, slot)
                if candidate then
                    for key, flag in pairs({ food="isFood", drink="isDrink", healthPotion="isHealthPotion",
                        manaPotion="isManaPotion", healthstone="isHealthstone" }) do
                        if candidate[flag] then
                            local ranked = {}
                            for k, v in pairs(candidate) do ranked[k] = v end
                            local amount = (key == "drink" or key == "manaPotion") and candidate.manaRestore or candidate.healthRestore
                            ranked.restore = amount > 0 and amount or GetFallbackRestore(candidate)
                            best[key] = BetterCandidate(best[key], ranked)
                        end
                    end
                end
            end
        end
    end
    return best
end

local function WriteMacro(name, body)
    if InCombatLockdown and InCombatLockdown() then
        pendingCombatUpdate = true
        return false
    end
    if not GetMacroInfo or not CreateMacro or not EditMacro then return false end
    -- Keep an existing character macro in place; never delete it to migrate scopes.
    local index
    for i = 1, (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18) do
        if GetMacroInfo(i) == name then index = i; break end
    end
    if index then
        local _, _, oldBody = GetMacroInfo(index)
        if oldBody == body then return true end
        local ok, result = pcall(EditMacro, index, name, MACRO_ICON, body)
        return ok and result ~= nil
    end
    local ok, result = pcall(CreateMacro, name, MACRO_ICON, body, false)
    return ok and result ~= nil
end

local function BuildMacro(kind, db, items)
    local health = kind == "health"
    local rest = health and items.food or (not health and items.drink)
    local combat = health and db.healthCombatItems or (not health and db.manaCombatPotion)
    local potion = health and items.healthPotion or (not health and items.manaPotion)
    local stone = health and items.healthstone
    local tooltip, lines = {}, {}
    if combat then
        local combatItem = stone or potion
        if combatItem then tooltip[#tooltip + 1] = "[combat] item:" .. combatItem.itemID end
        if stone then lines[#lines + 1] = "/use [combat] item:" .. stone.itemID end
        if potion then lines[#lines + 1] = "/use [combat] item:" .. potion.itemID end
    end
    if rest then
        tooltip[#tooltip + 1] = "[nocombat] item:" .. rest.itemID
        lines[#lines + 1] = "/use [nocombat] item:" .. rest.itemID
    end
    table.insert(lines, 1, #tooltip > 0 and "#showtooltip " .. table.concat(tooltip, "; ") or "#showtooltip")
    lastStatus[kind] = rest and string.format(L["Out of combat: %s."], rest.name) or L["No suitable food or water found."]
    if combat then
        local names = {}
        if stone then names[#names + 1] = stone.name end
        if potion then names[#names + 1] = potion.name end
        lastStatus[kind] = lastStatus[kind] .. " " .. (#names > 0 and string.format(L["Combat: %s."], table.concat(names, ", ")) or L["No combat consumables found."])
    end
    return table.concat(lines, "\n")
end

local function UpdateMacros()
    updateScheduled = false
    if InCombatLockdown and InCombatLockdown() then pendingCombatUpdate = true; return end
    local db = ns.db and ns.db.macros
    if not db then return end
    local items = (db.healthEnabled or db.manaEnabled) and ScanConsumables() or {}
    for _, kind in ipairs({ "health", "mana" }) do
        if db[kind .. "Enabled"] then
            local body = BuildMacro(kind, db, items)
            if #body > 255 or not WriteMacro(kind == "health" and HEALTH_MACRO_NAME or MANA_MACRO_NAME, body) then
                lastStatus[kind] = L["Could not save macro. Check free macro slots and try again."]
            end
        else
            lastStatus[kind] = kind == "health" and L["Health macro disabled."] or L["Mana macro disabled."]
        end
    end
    if ns.UI and ns.UI.RefreshVisiblePage then ns.UI.RefreshVisiblePage() end
end

function ns:RefreshConsumableMacros()
    if InCombatLockdown and InCombatLockdown() then pendingCombatUpdate = true; return end
    if updateScheduled then return end
    updateScheduled = true
    if C_Timer and C_Timer.After then C_Timer.After(0.15, UpdateMacros) else UpdateMacros() end
end

function ns:GetConsumableMacroOption(key)
    return self.db and self.db.macros and self.db.macros[key] == true
end

function ns:SetConsumableMacroOption(key, value)
    local db = self.db and self.db.macros
    if not db or db[key] == nil then return end
    local enabled = value == true
    if db[key] ~= enabled then
        db[key] = enabled
    end
    self:RefreshConsumableMacros()
end

function ns:GetConsumableMacroStatus()
    if pendingCombatUpdate then return L["Macro updates queued until combat ends."], L["Macro updates queued until combat ends."] end
    return lastStatus.health, lastStatus.mana
end

function ns:InitializeConsumableMacros()
    if frame then return end
    frame = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED" }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" and not pendingItemInfo then return end
        if event == "PLAYER_REGEN_ENABLED" then
            if not pendingCombatUpdate then return end
            pendingCombatUpdate = false
            ns:RefreshConsumableMacros()
            return
        end
        local db = ns.db and ns.db.macros
        if pendingCombatUpdate or (db and (db.healthEnabled or db.manaEnabled)) then ns:RefreshConsumableMacros() end
    end)
    self:RefreshConsumableMacros()
end

