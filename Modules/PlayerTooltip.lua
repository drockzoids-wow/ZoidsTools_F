local _, ns = ...
local initialized = false

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function GetClassRGB(unit)
    if IsSecret(unit) or type(unit) ~= "string" or not UnitIsPlayer or not UnitClass then return end
    local ok, player = pcall(UnitIsPlayer, unit)
    if not ok or IsSecret(player) or player ~= true then return end
    local classOK, _, class = pcall(UnitClass, unit)
    if not classOK or IsSecret(class) or type(class) ~= "string" then return end
    local custom = rawget(_G, "CUSTOM_CLASS_COLORS")
    local color = (custom and custom[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if not color and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local colorOK, value = pcall(C_ClassColor.GetClassColor, class)
        if colorOK then color = value end
    end
    if IsSecret(color) or type(color) ~= "table" then return end
    local r, g, b
    if type(color.GetRGB) == "function" then
        local colorOK
        colorOK, r, g, b = pcall(color.GetRGB, color)
        if not colorOK then return end
    else
        r, g, b = color.r, color.g, color.b
    end
    if IsSecret(r) or IsSecret(g) or IsSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
    return r, g, b
end

function ns:IsTooltipClassColoredNamesEnabled()
    return self.db and self.db.tooltips and self.db.tooltips.classColoredNames == true
end

function ns:SetTooltipClassColoredNamesEnabled(value)
    if self.db and self.db.tooltips then self.db.tooltips.classColoredNames = value == true end
end

local function ApplyNameColor(tooltip, line)
    if tooltip ~= GameTooltip or not ns:IsTooltipClassColoredNamesEnabled()
        or IsSecret(line) or type(line) ~= "table" then return end
    local r, g, b = GetClassRGB(line.unitToken)
    if r then line.leftColor = CreateColor(r, g, b) end
end

function ns:InitializePlayerTooltip()
    if initialized then return end
    if TooltipDataProcessor and type(TooltipDataProcessor.AddLinePreCall) == "function"
        and Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitName
        and type(CreateColor) == "function" then
        -- Match retail: change only the player-name color before Blizzard draws it.
        initialized = pcall(TooltipDataProcessor.AddLinePreCall,
            Enum.TooltipDataLineType.UnitName, ApplyNameColor)
        if initialized then return end
    end

    -- Older clients expose OnTooltipSetUnit instead of the line-data processor.
    local tooltip = GameTooltip
    if not tooltip or not tooltip.HookScript or not tooltip.GetUnit or not tooltip.HasScript then return end
    for _, script in ipairs({ "OnTooltipSetUnit", "OnTooltipCleared", "OnHide" }) do
        local ok, supported = pcall(tooltip.HasScript, tooltip, script)
        if not ok or IsSecret(supported) or not supported then return end
    end
    local saved
    local function Restore()
        if saved then
            pcall(saved.line.SetTextColor, saved.line, saved.r, saved.g, saved.b, saved.a)
            saved = nil
        end
    end
    tooltip:HookScript("OnTooltipCleared", Restore)
    tooltip:HookScript("OnHide", Restore)
    tooltip:HookScript("OnTooltipSetUnit", function(self)
        Restore()
        if not ns:IsTooltipClassColoredNamesEnabled() then return end
        local ok, _, unit = pcall(self.GetUnit, self)
        if not ok then return end
        local r, g, b = GetClassRGB(unit)
        local line = GameTooltipTextLeft1
        if not r or not line or not line.GetTextColor or not line.SetTextColor then return end
        local colorOK, oldR, oldG, oldB, oldA = pcall(line.GetTextColor, line)
        if not colorOK or IsSecret(oldR) or IsSecret(oldG) or IsSecret(oldB) or IsSecret(oldA)
            or type(oldR) ~= "number" or type(oldG) ~= "number" or type(oldB) ~= "number" then return end
        saved = { line = line, r = oldR, g = oldG, b = oldB, a = oldA or 1 }
        pcall(line.SetTextColor, line, r, g, b)
    end)
    initialized = true
end
