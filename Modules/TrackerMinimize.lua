local _, ns = ...
local watcher
local suppressed = {}

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Read(fn, object)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object)
    if ok and not IsSecret(value) then return value end
end

local function Restore(region)
    local alpha = suppressed[region]
    if alpha == nil then return end
    -- Preserve an appearance update Blizzard made after our last observation.
    if Read(region.GetAlpha, region) == 0 then region:SetAlpha(alpha) end
    suppressed[region] = nil
end

local function Suppress(region)
    if not region or not region.GetAlpha or not region.SetAlpha then return end
    local alpha = Read(region.GetAlpha, region)
    if type(alpha) ~= "number" then return end
    if suppressed[region] == nil or alpha ~= 0 then suppressed[region] = alpha end
    if alpha ~= 0 then region:SetAlpha(0) end
end

function ns:GetTrackerMinimizeToButton()
    return self.db and self.db.quests and self.db.quests.minimizeTracker == true
end

function ns:RefreshTrackerMinimize()
    local tracker = ObjectiveTrackerFrame
    local header = tracker and tracker.Header
    local editMode = EditModeManagerFrame
    local minimized = self:GetTrackerMinimizeToButton() and header and header.MinimizeButton
        and Read(tracker.IsCollapsed, tracker) == true
        and not (editMode and Read(editMode.IsEditModeActive, editMode) == true)
    if minimized then
        -- Cosmetic only: keep the header parent and native +/- button intact.
        -- Resizing or calling tracker layout from addon code can taint its updates.
        Suppress(header.Text)
        Suppress(header.Background)
        Suppress(tracker.NineSlice)
    end
    for region in pairs(suppressed) do
        if not minimized or (region ~= header.Text and region ~= header.Background
            and region ~= tracker.NineSlice) then Restore(region) end
    end
end

function ns:SetTrackerMinimizeToButton(value)
    if self.db and self.db.quests then self.db.quests.minimizeTracker = value == true end
    self:RefreshTrackerMinimize()
end

function ns:InitializeTrackerMinimize()
    if watcher then return end
    watcher = CreateFrame("Frame")
    -- Observe native state each frame for immediate visuals without hooking protected layout.
    -- This also handles late-loaded trackers and automatic expansion by Blizzard.
    watcher:SetScript("OnUpdate", function() self:RefreshTrackerMinimize() end)
    self:RefreshTrackerMinimize()
end
