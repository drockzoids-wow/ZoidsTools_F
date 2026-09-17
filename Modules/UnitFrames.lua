local _, ns = ...

local healthHooks = {}

local originalHealthColors = {}

local healthRefreshQueued = false

local function EnsureDB() return ns.db and ns.db.unitFrames end

local fallbackClassColors = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 },
    PRIEST = { r = 1, g = 1, b = 1 },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN = { r = 0, g = 0.44, b = 0.87 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    MONK = { r = 0, g = 1, b = 0.6 },
    DRUID = { r = 1, g = 0.49, b = 0.04 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER = { r = 0.2, g = 0.58, b = 0.5 },
}

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local healthBars = {
    player = {
        unit = "player",
        paths = {
            "PlayerFrameHealthBar",
            "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
            "PlayerFrame.healthbar",
            "PlayerFrame.HealthBar",
        },
    },
    target = {
        unit = "target",
        paths = {
            "TargetFrameHealthBar",
            "TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar",
            "TargetFrame.healthbar",
            "TargetFrame.HealthBar",
        },
    },
    targettarget = {
        unit = "targettarget",
        paths = {
            "TargetFrameToTHealthBar",
            "TargetFrameToT.HealthBar",
            "TargetFrameToT.healthbar",
        },
    },
    focus = {
        unit = "focus",
        paths = {
            "FocusFrameHealthBar",
            "FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar",
            "FocusFrame.healthbar",
            "FocusFrame.HealthBar",
        },
    },
}



local function ResolvePath(path)
    local current = _G

    for part in string.gmatch(path, "[^%.]+") do
        current = current and current[part]

        if not current then
            return nil
        end
    end

    return current
end



local function AddUniqueFrame(list, seen, frame)
    if not frame or seen[frame] then
        return
    end

    seen[frame] = true
    list[#list + 1] = frame
end



local function ReadColor(color)
    if not color then
        return nil
    end

    if type(color) == "table" then
        if color.GetRGB then
            local ok, r, g, b = pcall(color.GetRGB, color)

            if ok and r and g and b then
                return r, g, b
            end
        end

        return color.r or color[1], color.g or color[2], color.b or color[3]
    end

    return nil
end

local function GetClassColor(unit)
    local exists = UnitExists and UnitExists(unit)

    if IsSecretValue(exists) or not exists then
        return nil
    end

    if UnitIsPlayer then
        local isPlayer = UnitIsPlayer(unit)

        if IsSecretValue(isPlayer) or not isPlayer then
            return nil
        end
    end

    local ok, _, classFile = pcall(UnitClass, unit)

    if not ok or IsSecretValue(classFile) or type(classFile) ~= "string" then
        return nil
    end

    local color = fallbackClassColors[classFile]
    local r, g, b = ReadColor(color)

    if r and g and b then
        return r, g, b
    end

    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, apiColor = pcall(C_ClassColor.GetClassColor, classFile)

        if ok then
            r, g, b = ReadColor(apiColor)
        end

        if r and g and b then
            return r, g, b
        end
    end

    local customClassColors = rawget(_G, "CUSTOM_CLASS_COLORS")
    color = classFile
        and ((customClassColors and customClassColors[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    r, g, b = ReadColor(color)

    if r and g and b then
        return r, g, b
    end

    return nil
end

local function ReadHealthDesaturation(bar)
    if not bar then
        return nil
    end

    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()

    if texture and texture.IsDesaturated then
        return texture:IsDesaturated() == true
    elseif texture and texture.GetDesaturated then
        return texture:GetDesaturated() == true
    end

    return nil
end

local function ColorsMatch(aR, aG, aB, bR, bG, bB)
    if IsSecretValue(aR) or IsSecretValue(aG) or IsSecretValue(aB)
        or IsSecretValue(bR) or IsSecretValue(bG) or IsSecretValue(bB) then
        return false
    end
    if not aR or not aG or not aB or not bR or not bG or not bB then
        return false
    end

    return math.abs(aR - bR) < 0.01 and math.abs(aG - bG) < 0.01 and math.abs(aB - bB) < 0.01
end

local function SaveHealthColor(bar)
    if not bar then
        return
    end

    local r, g, b, a

    if bar.GetStatusBarColor then
        r, g, b, a = bar:GetStatusBarColor()
    end

    if IsSecretValue(r) or IsSecretValue(g) or IsSecretValue(b) or IsSecretValue(a) then return end

    if originalHealthColors[bar] and ColorsMatch(r, g, b, bar.ZTFClassColorR, bar.ZTFClassColorG, bar.ZTFClassColorB) then
        return true
    end

    originalHealthColors[bar] = {
        r = r,
        g = g,
        b = b,
        a = a,
        desaturated = ReadHealthDesaturation(bar),
    }
    return true
end

local function ClearHealthColorState(bar)
    if not bar then
        return
    end

    bar.ZTFClassColorHealth = nil
    bar.ZTFClassColorR = nil
    bar.ZTFClassColorG = nil
    bar.ZTFClassColorB = nil
    originalHealthColors[bar] = nil
end

local function SetHealthDesaturated(bar, value)
    if bar and bar.SetStatusBarDesaturated then
        bar:SetStatusBarDesaturated(value == true)
    end
end

local function RestoreHealthColor(bar)
    if not bar or not bar.SetStatusBarColor then
        return
    end

    local state = originalHealthColors[bar]

    if not state then
        return
    end

    if state.desaturated ~= nil then
        SetHealthDesaturated(bar, state.desaturated)
    else
        SetHealthDesaturated(bar, false)
    end

    if state.r and state.g and state.b then
        bar:SetStatusBarColor(state.r, state.g, state.b, state.a or 1)
    else
        bar:SetStatusBarColor(1, 1, 1, 1)
    end

    ClearHealthColorState(bar)
end

local function ReleaseHealthColor(bar)
    if not bar then
        return
    end

    local r, g, b

    if bar.GetStatusBarColor then
        r, g, b = bar:GetStatusBarColor()
    end

    if bar.ZTFClassColorHealth and ColorsMatch(r, g, b, bar.ZTFClassColorR, bar.ZTFClassColorG, bar.ZTFClassColorB) then
        RestoreHealthColor(bar)
    else
        ClearHealthColorState(bar)
    end
end

local function ApplyHealthColor(bar, r, g, b)
    if not bar then
        return
    end

    if bar.SetStatusBarColor then
        if not SaveHealthColor(bar) then return end
        SetHealthDesaturated(bar, true)
        bar:SetStatusBarColor(r, g, b, 1)
    end

    bar.ZTFClassColorHealth = true
    bar.ZTFClassColorR = r
    bar.ZTFClassColorG = g
    bar.ZTFClassColorB = b
end

local function GetHealthBarFrames(info)
    local frames = {}
    local seen = {}

    for _, path in ipairs(info and info.paths or {}) do
        local bar = ResolvePath(path)

        local accessible = true
        if bar and bar.CanBeAccessedInContext then
            local ok, value = pcall(bar.CanBeAccessedInContext, bar)
            accessible = ok and not IsSecretValue(value) and value == true
        end
        if bar and InCombatLockdown and InCombatLockdown() and bar.IsProtected then
            local ok, protected = pcall(bar.IsProtected, bar)
            if not ok or IsSecretValue(protected) or protected then accessible = false end
        end
        if bar and accessible and bar.SetStatusBarColor then
            AddUniqueFrame(frames, seen, bar)
        end
    end

    return frames
end

local function PlayerFrameIsShowingVehicle()
    for _, name in ipairs({ "UnitHasVehicleUI", "UnitInVehicle" }) do
        local api = _G[name]
        if api then
            local value = api("player")
            if IsSecretValue(value) or value then return true end
        end
    end

    return false
end

local function ApplyHealthBar(info)
    local db = EnsureDB()

    if not db or not info then
        return
    end

    local allowClassColor = db.classColorHealth
        and not (info.unit == "player" and PlayerFrameIsShowingVehicle())

    if allowClassColor then
        local r, g, b = GetClassColor(info.unit)

        for _, bar in ipairs(GetHealthBarFrames(info)) do
            if r and g and b then
                ApplyHealthColor(bar, r, g, b)
            elseif bar.ZTFClassColorHealth then
                ReleaseHealthColor(bar)
            end
        end
    else
        for _, bar in ipairs(GetHealthBarFrames(info)) do
            ReleaseHealthColor(bar)
        end
    end
end

local function ApplyHealthBars()
    for _, info in pairs(healthBars) do
        ApplyHealthBar(info)
    end
end



local function ScheduleHealthBars(delay)
    local db = EnsureDB()
    if not db or db.classColorHealth ~= true then
        return
    end

    if healthRefreshQueued then
        return
    end

    healthRefreshQueued = true
    delay = tonumber(delay) or 0.05

    if InCombatLockdown and InCombatLockdown() then
        delay = math.max(delay, 0.15)
    end

    local function Run()
        healthRefreshQueued = false
        ApplyHealthBars()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, Run)
    else
        Run()
    end
end

local function HookHealthBar(info)
    local db = EnsureDB()
    if not db or db.classColorHealth ~= true then
        return
    end

    for _, bar in ipairs(GetHealthBarFrames(info)) do
        if not healthHooks[bar] then
            healthHooks[bar] = true

            if bar.HookScript then
                bar:HookScript("OnShow", ScheduleHealthBars)
                bar:HookScript("OnValueChanged", ScheduleHealthBars)
            end
        end
    end
end

local function Refresh()
    for _, info in pairs(healthBars) do HookHealthBar(info) end
    ApplyHealthBars()
end

function ns:GetUnitFrameClassColorHealth()
    local db = EnsureDB()
    return db and db.classColorHealth == true
end

function ns:SetUnitFrameClassColorHealth(value)
    local db = EnsureDB()
    if not db then return end
    db.classColorHealth = value == true
    Refresh()
end

local eventFrame
function ns:InitializeUnitFrames()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_TARGET_CHANGED",
        "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "UNIT_NAME_UPDATE", "UNIT_FACTION",
        "UNIT_CONNECTION", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE", "VEHICLE_UPDATE", "PLAYER_CONTROL_GAINED",
        "PLAYER_CONTROL_LOST", "PLAYER_REGEN_ENABLED" }) do
        ns:RegisterCompatibleEvent(eventFrame, event)
    end
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" or event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
            Refresh()
            return
        end
        if IsSecretValue(unit) then return end
        if event:sub(1, 5) == "UNIT_" and unit and not healthBars[unit] then return end
        ScheduleHealthBars()
    end)
    if type(UnitFrameHealthBar_Update) == "function" then
        hooksecurefunc("UnitFrameHealthBar_Update", function() ScheduleHealthBars() end)
    end
    Refresh()
end

