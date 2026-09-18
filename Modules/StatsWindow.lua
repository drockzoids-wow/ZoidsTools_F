local _, ns = ...
local window
local rows = {}
local values = {}
local dragging = false

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if type(value) == "number" and value == value and value >= 0 and value < math.huge then return value end
end

local function ReadNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Number(value) end
end

local function Format(value, suffix)
    return value and string.format("%.0f%s", value, suffix or "") or "--"
end

local function HideTooltip(owner)
    if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function ShowTooltip(row)
    if not GameTooltip or dragging then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if row.key == "fps" then
        GameTooltip:SetText("Frames per second")
        GameTooltip:AddLine("Current: " .. Format(values.fps, " FPS"), 1, 1, 1)
        GameTooltip:AddLine("Higher values generally mean smoother motion.", 0.8, 0.8, 0.8, true)
    elseif row.key == "latency" then
        GameTooltip:SetText("Latency")
        GameTooltip:AddDoubleLine("Home", Format(values.home, " ms"), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("World", Format(values.world, " ms"), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine("The box shows world latency. Lower latency means a faster server response.", 0.8, 0.8, 0.8, true)
    else
        GameTooltip:SetText("Movement speed")
        GameTooltip:AddLine("Current: " .. Format(values.speed, "%"), 1, 1, 1)
        GameTooltip:AddLine("100% = normal running speed (7 yards/second). Standing still shows 0%. Includes movement while mounted, swimming, or flying when reported by the client.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine("Unavailable or restricted values display --.", 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(ns.db.stats.locked and "Position locked. Unlock in /ztf stats." or "Drag to move. Lock in /ztf stats.", 0.96, 0.72, 0.20, true)
    GameTooltip:Show()
end

local function UpdateValues()
    values.fps = ReadNumber(GetFramerate)
    values.home, values.world = nil, nil
    if type(GetNetStats) == "function" then
        local ok, _, _, home, world = pcall(GetNetStats)
        if ok then values.home, values.world = Number(home), Number(world) end
    end
    local speed = ReadNumber(GetUnitSpeed, "player")
    values.speed = speed and speed / 7 * 100 or nil
    rows[1].value:SetText(Format(values.fps))
    rows[2].value:SetText(Format(values.world))
    rows[3].value:SetText(Format(values.speed))
    for _, row in ipairs(rows) do
        if GameTooltip and GameTooltip:IsOwned(row) then ShowTooltip(row) end
    end
end

local function StopMoving()
    if not dragging then return end
    window:StopMovingOrSizing()
    dragging = false
    local point, _, relativePoint, x, y = window:GetPoint()
    local db = ns.db.stats
    db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
end

local function StartMoving()
    if ns.db.stats.locked or not ns.db.stats.enabled then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for _, row in ipairs(rows) do HideTooltip(row) end
    window:StartMoving()
    dragging = true
end

local function MouseBehavior(frame, locked)
    -- Lock clicks/dragging, not hover motion: stat tooltips must remain usable.
    frame:EnableMouse(true)
    if frame.SetMouseMotionEnabled and frame.SetMouseClickEnabled then
        frame:SetMouseMotionEnabled(true)
        frame:SetMouseClickEnabled(not locked)
    end
end

function ns:RefreshStatsWindow()
    if not window then return end
    StopMoving()
    local db = self.db.stats
    window:ClearAllPoints()
    window:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    window:SetMovable(not db.locked)
    MouseBehavior(window, db.locked)
    for _, row in ipairs(rows) do MouseBehavior(row, db.locked) end
    window:SetShown(db.enabled)
    if db.enabled then UpdateValues() end
end

function ns:SetStatsWindowOption(key, value)
    if key ~= "enabled" and key ~= "locked" then return end
    StopMoving()
    self.db.stats[key] = value == true
    self:RefreshStatsWindow()
end

function ns:ResetStatsWindowPosition()
    StopMoving()
    local db = self.db.stats
    db.point, db.relativePoint, db.x, db.y = "CENTER", "CENTER", 0, -180
    self:RefreshStatsWindow()
end

function ns:InitializeStatsWindow()
    if window then return end
    window = CreateFrame("Frame", "ZoidsTools_FStats", UIParent, "BackdropTemplate")
    window:SetSize(120, 90)
    window:SetFrameStrata("MEDIUM")
    window:SetClampedToScreen(true)
    ns.UI.Theme.ApplyPanelBackdrop(window)
    local title = window:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -8)
    title:SetText("STATS")
    title:SetTextColor(unpack(ns.UI.Theme.colors.gold))
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", StartMoving)
    window:SetScript("OnDragStop", StopMoving)
    window:SetScript("OnHide", function()
        StopMoving()
        for _, row in ipairs(rows) do HideTooltip(row) end
    end)
    for i, entry in ipairs({ { "fps", "FPS" }, { "latency", "Latency (ms)" }, { "speed", "Speed (%)" } }) do
        local row = CreateFrame("Frame", nil, window)
        row.key = entry[1]
        row:SetPoint("TOPLEFT", 8, -22 - (i - 1) * 20)
        row:SetSize(104, 20)
        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 2, 0)
        label:SetText(entry[2])
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.value:SetPoint("RIGHT", -2, 0)
        row.value:SetTextColor(unpack(ns.UI.Theme.colors.gold))
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart", StartMoving)
        row:SetScript("OnDragStop", StopMoving)
        row:SetScript("OnEnter", ShowTooltip)
        row:SetScript("OnLeave", HideTooltip)
        rows[i] = row
    end
    local elapsedTime = 0
    window:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime < 0.2 then return end
        elapsedTime = 0
        UpdateValues()
    end)
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:SetScript("OnEvent", StopMoving)
    self:RefreshStatsWindow()
end
