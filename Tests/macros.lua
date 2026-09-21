local frames, timers, macros, bags, items = {}, {}, {}, {}, {}
local combat, writes, creates, full = false, 0, 0, false
local missing = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end
function InCombatLockdown() return combat end
function UnitLevel() return 30 end
function UnitHealthMax() return 1000 end
function UnitPowerMax() return 2000 end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush()
    local pending = timers; timers = {}
    for _, fn in ipairs(pending) do fn() end
end
local function Fire(e)
    for _, f in ipairs(frames) do if f.events[e] then f.handler(f, e) end end
end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemID = function(_, slot) return bags[slot] end,
}
C_Item = {
    GetItemInfo = function(id)
        if missing[id] then return end
        local i = items[id]
        return i.name, nil, 1, i.level or 10, i.required or 1, "Consumable", "", nil, nil, nil, nil, 0, i.subclass
    end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetBagItem = function(_, slot) return { lines = {{leftText = items[bags[slot]].text}} } end }
function GetMacroInfo(index)
    local m = macros[index]
    if m then return m.name, "?", m.body end
end
function CreateMacro(name, _, body)
    assert(not combat, "macro created in combat")
    if full then error("full") end
    creates = creates + 1
    local index = #macros + 1
    macros[index] = { name = name, body = body }
    return index
end
function EditMacro(index, name, _, body)
    assert(not combat, "macro edited in combat")
    writes = writes + 1
    macros[index] = { name=name, body=body }
    return index
end
local function Add(id, name, text, subclass, required)
    items[id] = {name=name, text=text, subclass=subclass, required=required}
    bags[#bags + 1] = id
end
local function Body(name)
    for _, m in pairs(macros) do if m.name == name then return m.body end end
end
local function Has(body, text) return body:find(text, 1, true) ~= nil end

function RunMacroTests(ns)
    ns:InitializeConsumableMacros(); Flush()
    assert(creates == 0, "disabled macros must not be created")
    Add(101, "Bread", "Restores 500 health over 20 sec.", 5)
    Add(102, "Water", "Restores 800 mana over 20 sec.", 5)
    Add(103, "Buff food", "Restores 9000 health. Well Fed", 5)
    Add(104, "Healing Potion", "Restores 100 to 200 health.", 1)
    Add(105, "Mana Potion", "Restores 400 mana.", 1)
    Add(5511, "Lesser Healthstone", "Restores 250 health.", 0)
    Add(106, "Future Bread", "Restores 50000 health.", 5, 60)
    Add(107, "Bandage", "Restores 99999 health.", 7)
    ns:SetConsumableMacroOption("healthEnabled", true)
    ns:SetConsumableMacroOption("manaEnabled", true); Flush()
    local h, m = Body("ZTF Health"), Body("ZTF Mana")
    assert(Has(h, "/use [nocombat] item:101") and not Has(h, "item:103") and not Has(h, "item:106") and not Has(h, "item:107"))
    assert(Has(m, "/use [nocombat] item:102") and Has(m, "/use [combat] item:105"))
    assert(Has(h, "/use [combat] item:5511\n/use [combat] item:104"))
    assert(#h <= 255 and #m <= 255)
    local before = writes; ns:RefreshConsumableMacros(); Flush(); assert(writes == before)
    Add(108, "Conjured Bread", "Restores 200 health.", 5)
    Fire("BAG_UPDATE_DELAYED"); combat = true; Flush()
    assert(Body("ZTF Health") == h)
    assert(ns:GetConsumableMacroStatus():find("queued"))
    combat = false; Fire("PLAYER_REGEN_ENABLED"); Flush()
    assert(Has(Body("ZTF Health"), "[nocombat] item:108"))
    combat = true
    ns:SetConsumableMacroOption("healthCombatItems", false)
    ns:SetConsumableMacroOption("manaCombatPotion", false)
    combat = false; Fire("PLAYER_REGEN_ENABLED"); Flush()
    assert(not Has(Body("ZTF Health"), "/use [combat]"))
    assert(not Has(Body("ZTF Mana"), "/use [combat]"))
    Add(109, "Conjured Water", "Restores 900 mana.", 5); missing[109] = true
    Fire("BAG_UPDATE_DELAYED"); Flush()
    assert(not Has(Body("ZTF Mana"), "item:109"))
    missing[109] = nil; Fire("GET_ITEM_INFO_RECEIVED"); Flush()
    assert(Has(Body("ZTF Mana"), "item:109"))
    -- General-slot failures surface without touching unrelated or character macros.
    macros = { [1] = {name="ZT Health", body="retail"} }; full = true
    ns:RefreshConsumableMacros(); Flush()
    assert(ns:GetConsumableMacroStatus():find("Could not save"))
    assert(macros[1].body == "retail")
    macros[121] = {name="ZTF Health", body="old"}
    ns:RefreshConsumableMacros(); Flush()
    assert(Has(macros[121].body, "item:108"))
    full = false; ns:RefreshConsumableMacros(); Flush()
    -- Disabling during combat must settle status without deleting frozen macros.
    combat = true; ns:SetConsumableMacroOption("healthEnabled", false); ns:SetConsumableMacroOption("manaEnabled", false)
    local frozen = macros[121].body
    combat = false; Fire("PLAYER_REGEN_ENABLED"); Flush()
    assert(ns:GetConsumableMacroStatus() == "Health macro disabled.")
    assert(macros[121].body == frozen)
    bags = {}; ns:SetConsumableMacroOption("healthEnabled", true); Flush()
    assert(macros[121].body == "#showtooltip", "empty bags must remove stale uses")
    -- Legacy bag/item-info adapters select the same consumable.
    GetContainerNumSlots = C_Container.GetContainerNumSlots
    GetContainerItemID = C_Container.GetContainerItemID
    GetItemInfo = C_Item.GetItemInfo
    C_Container, C_Item = nil, nil
    Add(110, "Bread", "Restores 100 health.", 5)
    Fire("BAG_UPDATE_DELAYED"); Flush()
    assert(Has(macros[121].body, "item:110"))
end
