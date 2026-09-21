local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

local movableFrames = {}
local windowHandles = {}
local bagFrames = {}
local bagHandles = {}
local windowsRegistered = false
local bagWatcher
local panelRefreshQueued = false
local bagRefreshQueued = false
local worldMapMoverInstalled = false
local worldMapMoving = false
local RestoreOriginalPoint
local RefreshBagsSoon

local blockedFrames = {
    AlertFrame = true,
    BuffFrame = true,
    ChatFrame1 = true,
    CompactRaidFrameManager = true,
    ContainerFrameCombinedBags = true,
    -- Blizzard's flight map is a MapCanvas. Modifying its parent frame taints
    -- protected quest-pin mouse setup (SetPassThroughButtons), so it must stay
    -- entirely under Blizzard's control.
    FlightMapFrame = true,
    -- Guild Control performs protected account-authorization checks from its
    -- Blizzard OnShow path. Adding movement, scale, anchor, or script hooks to
    -- either the control panel or its legacy host taints IsUserOAuthed().
    GuildControlUI = true,
    GuildFrame = true,
    -- The generic mover changes scale, anchors, placement state, and frame
    -- scripts. Keep those operations away from MapCanvas; WorldMapFrame gets
    -- a dedicated position-only title-bar mover below.
    WorldMapFrame = true,
    HouseEditorFrame = true,
    LossOfControlFrame = true,
    MainMenuBar = true,
    MinimapCluster = true,
    ObjectiveTrackerFrame = true,
    PlayerFrame = true,
    TargetFrame = true,
    UIParent = true,
}

local bagHandleAllowedFrames = {
    ContainerFrameCombinedBags = true,
}

local commonFrames = {
    "AuctionFrame",
    "QuestLogFrame",
    "CraftFrame",
    "GuildBankFrame",
    "AchievementFrame",
    "ArchaeologyFrame",
    "AuctionHouseFrame",
    "BankFrame",
    "CalendarFrame",
    "CharacterFrame",
    "CollectionsJournal",
    "CommunitiesFrame",
    "EncounterJournal",
    "FriendsFrame",
    "GameMenuFrame",
    "GossipFrame",
    "InspectFrame",
    "ItemTextFrame",
    "ItemUpgradeFrame",
    "LFGDungeonReadyPopup",
    "LootFrame",
    "MailFrame",
    "MerchantFrame",
    "OpenMailFrame",
    "PlayerSpellsFrame",
    "PlayerTalentFrame",
    "ProfessionsFrame",
    "ProfessionsBookFrame",
    "PVEFrame",
    "PVPQueueFrame",
    "QuestFrame",
    "QuestLogPopupDetailFrame",
    "ReforgingFrame",
    "ScrappingMachineFrame",
    "SpellBookFrame",
    "SubscriptionInterstitialFrame",
    "TimeManagerFrame",
    "TradeFrame",
    "TradeSkillFrame",
    "TransmogrifyFrame",
    "WardrobeFrame",
    "WeeklyRewardsFrame",
    "ClassTalentFrame",
    "MajorFactionRenownFrame",
    "GenericTraitFrame",
}

local knownBagFrames = {
    "ContainerFrameCombinedBags",
    "ContainerFrame1",
    "ContainerFrame2",
    "ContainerFrame3",
    "ContainerFrame4",
    "ContainerFrame5",
    "ContainerFrame6",
    "ContainerFrame7",
    "ContainerFrame8",
    "ContainerFrame9",
    "ContainerFrame10",
    "ContainerFrame11",
    "ContainerFrame12",
    "ContainerFrame13",
    "ContainerFrame14",
    "ContainerFrame15",
    "ContainerFrame16",
    "ContainerFrame17",
    "ContainerFrame18",
    "ContainerFrame19",
    "ContainerFrame20",
    "ReagentBankFrame",
    "AccountBankPanel",
    "WarbandBankFrame",
}

local function SafeCall(method, frame, ...)
    if type(method) ~= "function" then
        return false
    end

    return pcall(method, frame, ...)
end

local function CombatBlocksMovement(frame, isBagWindow)
    if not InCombatLockdown() then return false end
    if not isBagWindow or not frame or type(frame.IsProtected) ~= "function" then return true end
    local ok, protected = pcall(frame.IsProtected, frame)
    return not ok or protected ~= false
end

local function SetManagedPlacement(frame, value)
    if frame.SetUserPlaced then
        SafeCall(frame.SetUserPlaced, frame, value == true)
    end

    if frame.SetDontSavePosition then
        SafeCall(frame.SetDontSavePosition, frame, value == true)
    end
end

local function GetFrameName(frame)
    return frame and frame.GetName and frame:GetName()
end

local function IsBlockedFrameName(name, isBagWindow)
    return name and blockedFrames[name] == true and not (isBagWindow and bagHandleAllowedFrames[name])
end

local function IsBlockedFrame(frame, isBagWindow)
    return IsBlockedFrameName(GetFrameName(frame), isBagWindow)
end

local function CanMoveWorldMap(frame)
    if not frame
        or not ns.db
        or not ns.db.windows
        or not ns.db.windows.enabled
        or InCombatLockdown()
    then
        return false
    end

    return not frame.IsMaximized or not frame:IsMaximized()
end

local function FinishWorldMapMove(frame)
    if not frame or not worldMapMoving then
        return
    end

    SafeCall(frame.StopMovingOrSizing, frame)
    worldMapMoving = false

    -- StartMoving marks the frame as user placed. Leave persistence to WoW's
    -- native layout cache instead of restoring anchors from addon code.
    if frame.SetUserPlaced then
        local remember = ns.db
            and ns.db.windows
            and ns.db.windows.savePositions == true
        SafeCall(frame.SetUserPlaced, frame, remember)
    end

    if frame.SetDontSavePosition then
        SafeCall(frame.SetDontSavePosition, frame, false)
    end
end

local function RefreshWorldMapMovement()
    local frame = _G.WorldMapFrame
    local titleContainer = frame and frame.BorderFrame and frame.BorderFrame.TitleContainer

    if not frame or not titleContainer then
        return
    end

    if not worldMapMoverInstalled then
        if not SafeCall(frame.SetMovable, frame, true) then
            return
        end

        SafeCall(frame.SetClampedToScreen, frame, true)

        if frame.SetDontSavePosition then
            SafeCall(frame.SetDontSavePosition, frame, false)
        end

        if titleContainer.SetMouseClickEnabled then
            SafeCall(titleContainer.SetMouseClickEnabled, titleContainer, true)
        elseif titleContainer.EnableMouse then
            SafeCall(titleContainer.EnableMouse, titleContainer, true)
        end

        titleContainer:HookScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" or not CanMoveWorldMap(frame) then
                return
            end

            if SafeCall(frame.StartMoving, frame) then
                worldMapMoving = true
            end
        end)

        titleContainer:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                FinishWorldMapMove(frame)
            end
        end)

        titleContainer:HookScript("OnHide", function()
            FinishWorldMapMove(frame)
        end)

        worldMapMoverInstalled = true
    end

    local enabled = ns.db and ns.db.windows and ns.db.windows.enabled == true
    if not enabled then
        FinishWorldMapMove(frame)
    end

    SafeCall(frame.SetMovable, frame, enabled)

    if enabled and ns.db.windows.savePositions ~= true and frame.SetUserPlaced then
        SafeCall(frame.SetUserPlaced, frame, false)
    end
end

local function ResetWorldMapPosition()
    local frame = _G.WorldMapFrame

    if not frame or InCombatLockdown() then
        return
    end

    FinishWorldMapMove(frame)

    if frame.SetUserPlaced then
        SafeCall(frame.SetUserPlaced, frame, false)
    end

    if frame.SetDontSavePosition then
        SafeCall(frame.SetDontSavePosition, frame, false)
    end
end

local function ClearSavedWindowState(name)
    if not name or not ns.db or not ns.db.windows then
        return
    end

    if ns.db.windows.points then
        ns.db.windows.points[name] = nil
    end

    if ns.db.windows.scales then
        ns.db.windows.scales[name] = nil
    end
end

local function ClearBlockedWindowState()
    for name in pairs(blockedFrames) do
        if not bagHandleAllowedFrames[name] then
            ClearSavedWindowState(name)
        end
    end
end

local function IsUsableFrame(frame)
    local name = GetFrameName(frame)

    return frame
        and name
        and not IsBlockedFrameName(name)
        and frame.SetMovable
        and frame.SetClampedToScreen
        and frame.EnableMouse
        and frame.RegisterForDrag
        and frame.HookScript
        and frame.GetNumPoints
        and frame.GetPoint
end

local function CaptureOriginalPoints(frame, isBagWindow)
    if IsBlockedFrame(frame, isBagWindow) then
        return
    end

    if not frame.ZTOriginalScale and frame.GetScale then
        frame.ZTOriginalScale = frame:GetScale() or 1
    end

    if frame.ZTOriginalPoints and #frame.ZTOriginalPoints > 0 then
        return
    end

    local pointCount = frame:GetNumPoints()

    if pointCount == 0 then
        return
    end

    frame.ZTOriginalPoints = {}

    for index = 1, pointCount do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        frame.ZTOriginalPoints[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local function UsesProfessionBagAnchor(frame)
    local name = GetFrameName(frame)
    if not name or not name:match("^ContainerFrame%d+$") or not frame.GetID then return false end
    local ok, bagID = pcall(frame.GetID, frame)
    if not ok or type(bagID) ~= "number" or bagID <= 0 then return false end
    local api = C_Container or {}
    local inventoryID = api.ContainerIDToInventoryID or ContainerIDToInventoryID
    if type(inventoryID) == "function" and type(IsInventoryItemProfessionBag) == "function" then
        local mapped, slot = pcall(inventoryID, bagID)
        if mapped and slot then
            local checked, profession = pcall(IsInventoryItemProfessionBag, "player", slot)
            if checked then return profession == true or profession == 1 end
        end
    end
    -- Older clients expose specialty bag families instead of the inventory query.
    local freeSlots = api.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    if bagID <= (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) and type(freeSlots) == "function" then
        local read, _, family = pcall(freeSlots, bagID)
        return read and type(family) == "number" and family > 0
    end
    return false
end

local bagCorners = { BOTTOMRIGHT=true, BOTTOMLEFT=true, TOPRIGHT=true, TOPLEFT=true }
local bagLayoutInProgress = false
local function CarriedBag(frame)
    local name = GetFrameName(frame)
    if name == "ContainerFrameCombinedBags" then return true end
    if not name or not name:match("^ContainerFrame%d+$") or not frame.GetID then return false end
    local ok, id = pcall(frame.GetID, frame)
    return ok and type(id)=="number" and id>=0 and id<=(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
end
local function BagBase()
    local fallback
    for _,name in ipairs(knownBagFrames) do
        local bag = _G[name]
        if bag and CarriedBag(bag) and bag:IsShown() then
            fallback = fallback or bag
            local _,relative = bag:GetPoint(1)
            if not (relative and relative ~= bag and CarriedBag(relative) and relative:IsShown()) then return bag end
        end
    end
    return fallback
end
local function BagScale(frame)
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or (frame.GetScale and frame:GetScale()) or 1
    return scale / parentScale
end
local function CaptureBagAnchor(frame, corner)
    if not frame or CombatBlocksMovement(frame,true) then return false end
    local xMethod = corner:find("RIGHT",1,true) and frame.GetRight or frame.GetLeft
    local yMethod = corner:find("TOP",1,true) and frame.GetTop or frame.GetBottom
    if not xMethod or not yMethod then return false end
    local okX,x = pcall(xMethod,frame)
    local okY,y = pcall(yMethod,frame)
    if not okX or not okY or type(x)~="number" or type(y)~="number" then return false end
    local scale = BagScale(frame)
    ns.db.windows.bagAnchor = {point=corner,x=x*scale,y=y*scale}
    if ZoidsTools_FRecoveryService then ZoidsTools_FRecoveryService:Capture() end
    return true
end
function ns:GetBagAnchorCorner()
    local corner = self.db and self.db.windows.bagAnchorCorner
    return bagCorners[corner] and corner or "BOTTOMRIGHT"
end
function ns:SetBagAnchorCorner(corner)
    if not bagCorners[corner] or InCombatLockdown() then return end
    local base = BagBase()
    -- Require a visible bag when changing an existing anchor so it does not jump.
    if self.db.windows.bagAnchor and not CaptureBagAnchor(base,corner) then
        self:Print("Open a bag before changing its anchor corner.")
        return
    end
    self.db.windows.bagAnchorCorner = corner
    if base and self.db.windows.savePositions then CaptureBagAnchor(base,corner) end
    if ZoidsTools_FRecoveryService then ZoidsTools_FRecoveryService:Capture() end
    if RefreshBagsSoon then RefreshBagsSoon() end
end

local function GetSavedPoint(frame, isBagWindow)
    local points = ns.db and ns.db.windows and ns.db.windows.points
    if not points then return end
    local anchor = ns.db.windows.bagAnchor
    if isBagWindow and CarriedBag(frame) and anchor then
        if bagLayoutInProgress or not frame:IsShown() or BagBase() ~= frame then return end
        local scale = BagScale(frame)
        return {point=anchor.point,relativeTo="UIParent",relativePoint="BOTTOMLEFT",x=anchor.x/scale,y=anchor.y/scale}
    end
    local combined = _G.ContainerFrameCombinedBags
    if isBagWindow and combined and points.ContainerFrameCombinedBags and UsesProfessionBagAnchor(frame) then
        -- When both are open, leave the side-by-side arrangement to Blizzard.
        if combined:IsShown() then return end
        return points.ContainerFrameCombinedBags
    end
    return points[GetFrameName(frame)]
end

local function SavePoint(frame, isBagWindow)
    if not ns.db or not ns.db.windows.savePositions or CombatBlocksMovement(frame, isBagWindow) then
        return
    end

    local name = GetFrameName(frame)
    if not name then
        return
    end

    if isBagWindow and CarriedBag(frame) and CaptureBagAnchor(frame,ns:GetBagAnchorCorner()) then
        if RefreshBagsSoon then RefreshBagsSoon() end
        return
    end

    if isBagWindow and UsesProfessionBagAnchor(frame) and _G.ContainerFrameCombinedBags
        and ns.db.windows.points.ContainerFrameCombinedBags then
        return -- Never persist the temporary shared anchor as a profession bag position.
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    ns.db.windows.points[name] = {
        point = point,
        relativeTo = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function HasSavedPoint(frame, isBagWindow)
    local name = GetFrameName(frame)

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return false
    end

    return ns.db
        and ns.db.windows.savePositions
        and ns.db.windows.points
        and name
        and GetSavedPoint(frame, isBagWindow) ~= nil
end

local function ClampScale(value)
    local minScale = ns.db and ns.db.windows.minScale or 0.6
    local maxScale = ns.db and ns.db.windows.maxScale or 1.8

    value = tonumber(value) or 1

    if value < minScale then
        return minScale
    elseif value > maxScale then
        return maxScale
    end

    return value
end

local function GetFrameScale(frame)
    if not frame or not frame.GetScale then
        return 1
    end

    return frame:GetScale() or 1
end

local function GetOriginalScale(frame)
    return frame and frame.ZTOriginalScale or 1
end

local function ApplyScale(frame, scale, save, isBagWindow)
    if not frame or not frame.SetScale or InCombatLockdown() then
        return false
    end

    local name = GetFrameName(frame)

    if not name then
        return false
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return false
    end

    scale = ClampScale(scale)

    if save then
        ns.db.windows.scales = ns.db.windows.scales or {}
        ns.db.windows.scales[name] = scale
    end

    frame.ZTApplyingScale = true
    local ok = SafeCall(frame.SetScale, frame, scale)
    frame.ZTApplyingScale = nil

    if not ok then
        return false
    end

    return true
end

local function ApplySavedScale(frame, isBagWindow)
    if not ns.db or not frame or IsBlockedFrame(frame, isBagWindow) then
        return
    end

    local name = GetFrameName(frame)
    local saved = name and ns.db.windows.scales and ns.db.windows.scales[name]

    if saved then
        ApplyScale(frame, saved, false, isBagWindow)
    end
end

local function HasSavedScale(frame, isBagWindow)
    local name = GetFrameName(frame)

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return false
    end

    return ns.db
        and ns.db.windows.scales
        and name
        and ns.db.windows.scales[name] ~= nil
end

local function ApplySavedScaleSoon(frame, isBagWindow)
    if not frame or IsBlockedFrame(frame, isBagWindow) then
        return
    end

    if not HasSavedScale(frame, isBagWindow) then
        return
    end

    ApplySavedScale(frame, isBagWindow)

    if not C_Timer or not C_Timer.After or frame.ZTScaleRestoreQueued then
        return
    end

    frame.ZTScaleRestoreQueued = true

    C_Timer.After(0, function()
        frame.ZTScaleRestoreQueued = nil
        ApplySavedScale(frame, isBagWindow)
    end)

    C_Timer.After(0.05, function()
        ApplySavedScale(frame, isBagWindow)
    end)

    C_Timer.After(0.2, function()
        ApplySavedScale(frame, isBagWindow)
    end)
end

local function HookFrameSetScale(frame, isBagWindow)
    if IsBlockedFrame(frame, isBagWindow) or frame.ZTSetScaleHooked or not frame.SetScale then
        return
    end

    local ok = pcall(hooksecurefunc, frame, "SetScale", function(self)
        if self.ZTApplyingScale then
            return
        end

        if IsBlockedFrame(self, isBagWindow) then
            return
        end

        local name = GetFrameName(self)
        local saved = name and ns.db and ns.db.windows.scales and ns.db.windows.scales[name]

        if saved then
            ApplySavedScaleSoon(self, isBagWindow)
        end
    end)

    if ok then
        frame.ZTSetScaleHooked = true
    end
end

local function ResetFrameScale(frame, notify, isBagWindow)
    if not ns.db or not frame then
        return
    end

    local name = GetFrameName(frame)

    if not name then
        return
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return
    end

    if ns.db.windows.scales then
        ns.db.windows.scales[name] = nil
    end

    frame.ZTApplyingScale = true
    local didReset = ApplyScale(frame, GetOriginalScale(frame), false, isBagWindow)
    frame.ZTApplyingScale = nil

    if didReset and notify then
        ns:Print(string.format(L["%s scale reset."], name))
    end
end

local function AdjustFrameScale(frame, delta, isBagWindow)
    if not ns.db
        or not ns.db.windows.enabled
        or not ns.db.windows.scaleEnabled
        or (isBagWindow and not ns.db.windows.moveBags)
        or not frame
        or IsBlockedFrame(frame, isBagWindow)
        or InCombatLockdown()
    then
        return
    end

    local step = ns.db.windows.scaleStep or 0.05
    local scale = GetFrameScale(frame) + ((delta or 0) > 0 and step or -step)

    if ApplyScale(frame, scale, true, isBagWindow) then
        SavePoint(frame, isBagWindow)
    end
end

local function RelayoutContainerFrames()
    local layoutFunctions = {
        "UpdateContainerFrameAnchors",
        "ContainerFrame_UpdateContainerFrameAnchors",
        "ContainerFrame_UpdateAll",
    }

    for _, functionName in ipairs(layoutFunctions) do
        if type(_G[functionName]) == "function" then
            pcall(_G[functionName])
        end
    end
end

local function RefreshProfessionBagLayout(frame)
    if ns.db and ns.db.windows.bagAnchor and CarriedBag(frame) then
        RefreshBagsSoon()
        return
    end
    if GetFrameName(frame) ~= "ContainerFrameCombinedBags" or not ns.db
        or not ns.db.windows.enabled or not ns.db.windows.moveBags
        or not ns.db.windows.savePositions or not ns.db.windows.points.ContainerFrameCombinedBags then return end
    if frame:IsShown() then
        for bag in pairs(bagFrames) do
            if UsesProfessionBagAnchor(bag) and not CombatBlocksMovement(bag, true) and not bag.ZTMoving then
                -- Release the solo override before Blizzard lays out adjacent bags.
                SetManagedPlacement(bag, false)
            end
        end
    end
    RelayoutContainerFrames()
    RefreshBagsSoon()
end

local function RelayoutUIPanelFrames(frame)
    if frame then
        frame.ZTRestoringPoint = true
    end

    if type(_G.UpdateUIPanelPositions) == "function" then
        pcall(_G.UpdateUIPanelPositions, frame)
    end

    if type(_G.ManageFramePositions) == "function" then
        pcall(_G.ManageFramePositions)
    end

    if frame then
        frame.ZTRestoringPoint = nil
    end
end

local function ShowPanelFrame(frame)
    if not frame or frame:IsShown() then
        return
    end

    if type(ShowUIPanel) == "function" then
        local ok = pcall(ShowUIPanel, frame)

        if ok and frame:IsShown() then
            return
        end
    end

    SafeCall(frame.Show, frame)
end

local function ResetPanelFramePosition(frame)
    if not frame or InCombatLockdown() then
        return false
    end

    local wasShown = frame:IsShown()
    local restored = false

    SetManagedPlacement(frame, false)

    if wasShown and RestoreOriginalPoint then
        restored = RestoreOriginalPoint(frame, false)
    end

    RelayoutUIPanelFrames(frame)

    if wasShown then
        ShowPanelFrame(frame)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            SetManagedPlacement(frame, false)
            RelayoutUIPanelFrames(frame)

            if wasShown then
                ShowPanelFrame(frame)
            end
        end)

        C_Timer.After(0.05, function()
            SetManagedPlacement(frame, false)
            RelayoutUIPanelFrames(frame)

            if wasShown then
                ShowPanelFrame(frame)
            end
        end)
    end

    return restored or true
end

local function ResetFramePosition(frame, notify, useOriginalPoint)
    if not ns.db or not frame or InCombatLockdown() then
        return
    end

    local name = GetFrameName(frame)
    local isBagWindow = useOriginalPoint == "bag"

    if not name then
        return
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return
    end

    local now = GetTime and GetTime() or 0

    if frame.ZTLastPositionReset and now > 0 and now - frame.ZTLastPositionReset < 0.25 then
        return
    end

    frame.ZTLastPositionReset = now

    if ns.db.windows.points then
        ns.db.windows.points[name] = nil
    end

    if isBagWindow and CarriedBag(frame) then ns.db.windows.bagAnchor = nil end
    if useOriginalPoint == "bag" and not InCombatLockdown() then
        SetManagedPlacement(frame, false)
        RelayoutContainerFrames()

        if C_Timer and C_Timer.After then
            C_Timer.After(0, RelayoutContainerFrames)
            C_Timer.After(0.05, RelayoutContainerFrames)
        end
    elseif useOriginalPoint == "panel" then
        ResetPanelFramePosition(frame)
    elseif useOriginalPoint and RestoreOriginalPoint then
        RestoreOriginalPoint(frame, true)
    elseif frame:IsShown() and not InCombatLockdown() then
        frame.ZTRestoringPoint = true
        SafeCall(frame.ClearAllPoints, frame)
        SafeCall(frame.SetPoint, frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame.ZTRestoringPoint = nil
        SetManagedPlacement(frame, true)
    end

    if notify then
        ns:Print(string.format(L["%s position reset."], name))
    end
end

local function EnableMouseWheel(frame)
    if not frame then
        return
    end

    if frame.SetMouseWheelEnabled then
        SafeCall(frame.SetMouseWheelEnabled, frame, true)
    elseif frame.EnableMouseWheel then
        SafeCall(frame.EnableMouseWheel, frame, true)
    end
end

local function AddScaleScripts(inputFrame, targetFrame, allowPositionReset, resetToOriginalPoint, isBagWindow)
    if not inputFrame or inputFrame.ZTScaleScriptsHooked or IsBlockedFrame(targetFrame, isBagWindow) then
        return
    end

    inputFrame.ZTScaleScriptsHooked = true
    EnableMouseWheel(inputFrame)

    inputFrame:HookScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown and IsControlKeyDown() then
            AdjustFrameScale(targetFrame, delta, isBagWindow)
        end
    end)

    inputFrame:HookScript("OnMouseUp", function(_, button)
        if allowPositionReset and button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
            ResetFramePosition(targetFrame, true, resetToOriginalPoint)
        end
    end)
end

local function RestoreSavedPoint(frame, isBagWindow)
    if not ns.db
        or not ns.db.windows.enabled
        or not ns.db.windows.savePositions
        or (isBagWindow and not ns.db.windows.moveBags)
        or IsBlockedFrame(frame, isBagWindow)
        or CombatBlocksMovement(frame, isBagWindow)
        or frame.ZTMoving
    then
        return
    end

    local name = GetFrameName(frame)
    local saved = name and GetSavedPoint(frame, isBagWindow)

    if not saved then
        return
    end

    local relativeTo = _G[saved.relativeTo] or UIParent
    -- UIParent is the normal screen anchor, not the frame we are moving.
    -- Its protection state must not block an otherwise movable bag's restore.
    if relativeTo ~= UIParent and InCombatLockdown() and CombatBlocksMovement(relativeTo, true) then return end

    if frame.GetNumPoints and frame.GetPoint and frame:GetNumPoints() == 1 then
        local point, currentRelativeTo, relativePoint, x, y = frame:GetPoint(1)
        if point == saved.point
            and currentRelativeTo == relativeTo
            and relativePoint == saved.relativePoint
            and math.abs((x or 0) - (saved.x or 0)) < 0.5
            and math.abs((y or 0) - (saved.y or 0)) < 0.5
        then
            SetManagedPlacement(frame, true)
            return true
        end
    end

    frame.ZTRestoringPoint = true
    SafeCall(frame.ClearAllPoints, frame)
    SafeCall(frame.SetPoint, frame, saved.point, relativeTo, saved.relativePoint, saved.x, saved.y)
    frame.ZTRestoringPoint = nil

    SetManagedPlacement(frame, true)

    return true
end

local function RestoreSavedPointSoon(frame, isBagWindow)
    if not frame or IsBlockedFrame(frame, isBagWindow) then
        return
    end

    if not HasSavedPoint(frame, isBagWindow) then
        return
    end

    RestoreSavedPoint(frame, isBagWindow)

    if not C_Timer or not C_Timer.After or frame.ZTRestoreQueued then
        return
    end

    frame.ZTRestoreQueued = true

    C_Timer.After(0, function()
        frame.ZTRestoreQueued = nil
        RestoreSavedPoint(frame, isBagWindow)
    end)

end

function RestoreOriginalPoint(frame, keepManaged)
    if not frame or IsBlockedFrame(frame) or not frame.ZTOriginalPoints or #frame.ZTOriginalPoints == 0 or InCombatLockdown() then
        return false
    end

    frame.ZTRestoringPoint = true
    SafeCall(frame.ClearAllPoints, frame)

    for _, point in ipairs(frame.ZTOriginalPoints) do
        SafeCall(frame.SetPoint, frame, point.point, point.relativeTo or UIParent, point.relativePoint, point.x, point.y)
    end

    frame.ZTRestoringPoint = nil
    SetManagedPlacement(frame, keepManaged == true)

    return true
end

local function HookFrameSetPoint(frame, isBagWindow)
    if IsBlockedFrame(frame, isBagWindow) or frame.ZTSetPointHooked or not frame.SetPoint then
        return
    end

    local ok = pcall(hooksecurefunc, frame, "SetPoint", function(self)
        if IsBlockedFrame(self, isBagWindow) or self.ZTRestoringPoint or self.ZTMoving then
            return
        end

        RestoreSavedPointSoon(self, isBagWindow)
    end)

    if ok then
        frame.ZTSetPointHooked = true
    end
end

local function PositionWindowHandle(frame)
    local handle = windowHandles[frame]

    if not handle then
        return
    end

    local rightOffset = frame.CloseButton and -38 or -12

    handle:ClearAllPoints()
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -4)
    handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightOffset, -4)
    handle:SetHeight(28)
    handle:SetFrameStrata(frame:GetFrameStrata())
    handle:SetFrameLevel(math.min((frame:GetFrameLevel() or 1) + 100, 10000))
end

local function UpdateWindowHandle(frame)
    local handle = windowHandles[frame]

    if not handle then
        return
    end

    if ns.db and ns.db.windows.enabled and frame:IsShown() then
        PositionWindowHandle(frame)
        handle:Show()
    else
        handle:Hide()
    end
end

local function CreateWindowHandle(frame)
    if windowHandles[frame] then
        return
    end

    local name = frame:GetName()
    local handle = CreateFrame("Frame", name .. "ZoidsTools_FWindowDragHandle", frame, "BackdropTemplate")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    handle:SetBackdropColor(0.12, 0.16, 0.22, 0.08)
    handle:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.12)

    handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    handle.label:SetPoint("CENTER")
    handle.label:SetText(L["Move"])
    handle.label:SetAlpha(0.45)

    handle:SetScript("OnDragStart", function()
        if ns.db and ns.db.windows.enabled and not InCombatLockdown() then
            frame.ZTMoving = true
            if not SafeCall(frame.StartMoving, frame) then
                frame.ZTMoving = nil
            end
        end
    end)

    handle:SetScript("OnDragStop", function()
        SafeCall(frame.StopMovingOrSizing, frame)
        frame.ZTMoving = nil
        SetManagedPlacement(frame, true)
        SavePoint(frame)
        UpdateWindowHandle(frame)
    end)

    handle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.12, 0.16, 0.22, 0.18)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.35)
        self.label:SetAlpha(0.7)

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Move Window"])
        GameTooltip:AddLine(L["Drag this handle to reposition the window."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Ctrl + Mouse Wheel: Scale this window"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["Ctrl + Right-click: Reset this position"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    handle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.16, 0.22, 0.08)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.12)
        self.label:SetAlpha(0.45)
        GameTooltip:Hide()
    end)

    AddScaleScripts(handle, frame, true, "panel")

    handle:Hide()
    windowHandles[frame] = handle
    PositionWindowHandle(frame)
end

local function UpdateBagHandle(frame)
    local handle = bagHandles[frame]

    if not handle or CombatBlocksMovement(frame, true) then
        return
    end

    local shouldShow = ns.db
        and ns.db.windows.enabled
        and ns.db.windows.moveBags
        and ns.db.windows.showBagHandles
        and frame:IsShown()

    handle:SetShown(shouldShow == true)
end

local function MakeMovable(frame)
    if not IsUsableFrame(frame) or movableFrames[frame] then
        return
    end

    if not SafeCall(frame.SetMovable, frame, true) then
        return
    end

    movableFrames[frame] = true
    CaptureOriginalPoints(frame)

    SafeCall(frame.SetClampedToScreen, frame, true)
    SafeCall(frame.EnableMouse, frame, true)
    SafeCall(frame.RegisterForDrag, frame, "LeftButton")
    SetManagedPlacement(frame, HasSavedPoint(frame))
    HookFrameSetScale(frame, false)
    ApplySavedScaleSoon(frame)
    AddScaleScripts(frame, frame, false)
    CreateWindowHandle(frame)
    HookFrameSetPoint(frame, false)

    frame:HookScript("OnDragStart", function(self)
        if ns.db and ns.db.windows.enabled and not InCombatLockdown() then
            self.ZTMoving = true
            if not SafeCall(self.StartMoving, self) then
                self.ZTMoving = nil
            end
        end
    end)

    frame:HookScript("OnDragStop", function(self)
        SafeCall(self.StopMovingOrSizing, self)
        self.ZTMoving = nil
        SetManagedPlacement(self, true)
        SavePoint(self, false)
        UpdateWindowHandle(self)
    end)

    frame:HookScript("OnShow", function(self)
        CaptureOriginalPoints(self)
        ApplySavedScaleSoon(self)
        RestoreSavedPointSoon(self, false)
        UpdateWindowHandle(self)
    end)

    frame:HookScript("OnHide", function(self)
        ApplySavedScaleSoon(self)

        if ns.db and not ns.db.windows.savePositions then
            SetManagedPlacement(self, false)
        elseif ns.db and ns.db.windows.savePositions then
            RestoreSavedPointSoon(self, false)
        end

        UpdateWindowHandle(self)
    end)

    frame:HookScript("OnSizeChanged", UpdateWindowHandle)

    RestoreSavedPointSoon(frame, false)
    UpdateWindowHandle(frame)
end

local function PositionBagHandle(frame, handle)
    if CombatBlocksMovement(frame, true) then return end
    local name = frame:GetName()
    local leftOffset = name == "ContainerFrameCombinedBags" and 22 or 8
    local rightOffset = name == "ContainerFrameCombinedBags" and -92 or -34
    local height = name == "ContainerFrameCombinedBags" and 32 or 24

    handle:ClearAllPoints()
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", leftOffset, -4)
    handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightOffset, -4)
    handle:SetHeight(height)
end

local function CreateBagHandle(frame)
    local name = frame:GetName()
    local handle = CreateFrame("Frame", name .. "ZoidsTools_FDragHandle", frame, "BackdropTemplate")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetFrameStrata(frame:GetFrameStrata())
    handle:SetFrameLevel(math.min((frame:GetFrameLevel() or 1) + 100, 10000))
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    handle:SetBackdropColor(0.12, 0.16, 0.22, 0.16)
    handle:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.18)

    handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    handle.label:SetPoint("CENTER")
    handle.label:SetText(L["Move"])
    handle.label:SetAlpha(0.65)

    handle:SetScript("OnDragStart", function()
        if ns.db and ns.db.windows.enabled and ns.db.windows.moveBags and not CombatBlocksMovement(frame, true) then
            frame.ZTMoving = true
            if not SafeCall(frame.StartMoving, frame) then
                frame.ZTMoving = nil
            end
        end
    end)

    handle:SetScript("OnDragStop", function()
        if not frame.ZTMoving or CombatBlocksMovement(frame, true) then return end
        SafeCall(frame.StopMovingOrSizing, frame)
        frame.ZTMoving = nil
        SetManagedPlacement(frame, true)
        SavePoint(frame, true)
        UpdateBagHandle(frame)
    end)

    handle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.34, 0.46, 0.35)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.55)

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Move Bag Window"])
        GameTooltip:AddLine(L["Drag this handle to reposition the bag."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Ctrl + Mouse Wheel: Scale this bag"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["Ctrl + Right-click: Reset this position"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    handle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.16, 0.22, 0.16)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.18)
        GameTooltip:Hide()
    end)

    PositionBagHandle(frame, handle)
    AddScaleScripts(handle, frame, true, "bag", true)
    handle:Hide()

    return handle
end

local function MakeBagMovable(frame)
    if not frame or not ns.db or CombatBlocksMovement(frame, true) then
        return
    end

    local name = frame.GetName and frame:GetName()

    if not name
        or IsBlockedFrameName(name, true)
        or not frame.SetMovable
        or not frame.SetClampedToScreen
        or not frame.HookScript
    then
        return
    end

    if not bagFrames[frame] then
        if not SafeCall(frame.SetMovable, frame, true) then
            return
        end

        bagFrames[frame] = true
        CaptureOriginalPoints(frame, true)

        SafeCall(frame.SetClampedToScreen, frame, true)
        SetManagedPlacement(frame, HasSavedPoint(frame, true))
        HookFrameSetScale(frame, true)
        ApplySavedScaleSoon(frame, true)
        AddScaleScripts(frame, frame, false, nil, true)
        HookFrameSetPoint(frame, true)

        local handle = CreateBagHandle(frame)
        frame.ZoidsTools_FBagDragHandle = handle
        bagHandles[frame] = handle

        frame:HookScript("OnShow", function(self)
            if CombatBlocksMovement(self, true) then return end
            RefreshProfessionBagLayout(self)
            CaptureOriginalPoints(self, true)
            ApplySavedScaleSoon(self, true)
            RestoreSavedPointSoon(self, true)
            PositionBagHandle(self, bagHandles[self])
            UpdateBagHandle(self)
        end)

        frame:HookScript("OnHide", function(self)
            if CombatBlocksMovement(self, true) then return end
            RefreshProfessionBagLayout(self)
            if self.ZTMoving then
                SafeCall(self.StopMovingOrSizing, self)
                self.ZTMoving = nil
                SavePoint(self, true)
            end
            ApplySavedScaleSoon(self, true)

            if ns.db and not ns.db.windows.savePositions then
                SetManagedPlacement(self, false)
            elseif ns.db and ns.db.windows.savePositions then
                RestoreSavedPointSoon(self, true)
            end

            UpdateBagHandle(self)
        end)

        frame:HookScript("OnSizeChanged", function(self)
            if ns.db.windows.bagAnchor then RefreshBagsSoon() end
            PositionBagHandle(self, bagHandles[self])
            UpdateBagHandle(self)
        end)
    end

    RestoreSavedPointSoon(frame, true)
    if not ns.db.windows.bagAnchor and ns.db.windows.enabled and ns.db.windows.savePositions
        and CarriedBag(frame) and frame:IsShown() and ns.db.windows.points[name]
        and (name=="ContainerFrameCombinedBags" or frame:GetID()==0) then
        CaptureBagAnchor(frame,ns:GetBagAnchorCorner())
    end
    PositionBagHandle(frame, bagHandles[frame])
    UpdateBagHandle(frame)
end

local function RegisterUIPanelWindows()
    if InCombatLockdown() then
        return
    end

    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            MakeMovable(_G[name])
        end
    end

    for _, name in ipairs(commonFrames) do
        MakeMovable(_G[name])
    end

    for _, name in ipairs({ "PlayerSpellsFrame", "ClassTalentFrame", "PlayerTalentFrame", "SpellBookFrame" }) do
        MakeMovable(rawget(_G, name))
    end

    RefreshWorldMapMovement()
end

local function RefreshPanelWindowsSoon()
    if panelRefreshQueued or InCombatLockdown() then
        return
    end

    panelRefreshQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            panelRefreshQueued = false
            RegisterUIPanelWindows()
        end)
    else
        panelRefreshQueued = false
        RegisterUIPanelWindows()
    end
end

local function RegisterBagWindows()
    if not ns.db or not ns.db.windows.moveBags then
        return
    end

    for bag in pairs(bagFrames) do if bag.ZTMoving then return end end
    if ns.db.windows.enabled and ns.db.windows.savePositions and ns.db.windows.bagAnchor and not InCombatLockdown() then
        bagLayoutInProgress = true
        for _, name in ipairs(knownBagFrames) do
            local bag = _G[name]
            if bag and CarriedBag(bag) and not bag.ZTMoving then SetManagedPlacement(bag,false) end
        end
        RelayoutContainerFrames()
        bagLayoutInProgress = false
    end
    for _, name in ipairs(knownBagFrames) do
        if _G[name] then
            MakeBagMovable(_G[name])
        end
    end
end

RefreshBagsSoon = function()
    if bagRefreshQueued or bagLayoutInProgress then
        return
    end

    bagRefreshQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            bagRefreshQueued = false
            RegisterBagWindows()
        end)
    else
        bagRefreshQueued = false
        RegisterBagWindows()
    end
end

local function RegisterBagWatcherWorkEvents()
    if not bagWatcher then
        return
    end

    ns:RegisterCompatibleEvent(bagWatcher, "BAG_OPEN")
    ns:RegisterCompatibleEvent(bagWatcher, "BAG_CLOSED")
    ns:RegisterCompatibleEvent(bagWatcher, "BAG_UPDATE_DELAYED")
    ns:RegisterCompatibleEvent(bagWatcher, "PLAYERBANKSLOTS_CHANGED")
end

local function RefreshFrameSoon(frame, isBagWindow)
    if not frame or InCombatLockdown() then
        return
    end

    MakeMovable(frame)
    RestoreSavedPointSoon(frame, isBagWindow)
    UpdateWindowHandle(frame)
end

local function InstallHooks()
    if windowsRegistered then
        return
    end

    windowsRegistered = true

    if type(ShowUIPanel) == "function" then
        hooksecurefunc("ShowUIPanel", function(frame)
            if not InCombatLockdown() then
                RefreshFrameSoon(frame, false)
            end
        end)
    end

    if type(HideUIPanel) == "function" then
        hooksecurefunc("HideUIPanel", function(frame)
            if frame and not InCombatLockdown() then
                RestoreSavedPointSoon(frame, false)
            end
        end)
    end

    local windowFunctions = {
        "ToggleSpellBook",
        "ToggleTalentFrame",
        "TogglePlayerSpellsFrame",
        "ToggleProfessionsBook",
    }

    for _, functionName in ipairs(windowFunctions) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, function()
                if not InCombatLockdown() then
                    RefreshPanelWindowsSoon()
                end
            end)
        end
    end

    if type(_G.ToggleGameMenu) == "function" then
        hooksecurefunc("ToggleGameMenu", function()
            RefreshFrameSoon(_G.GameMenuFrame, false)
        end)
    end

    local bagFunctions = {
        "OpenAllBags",
        "CloseAllBags",
        "ToggleAllBags",
        "OpenBag",
        "CloseBag",
        "ToggleBag",
        "ToggleBackpack",
        "ContainerFrame_GenerateFrame",
    }

    for _, functionName in ipairs(bagFunctions) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, RefreshBagsSoon)
        end
    end

    bagWatcher = CreateFrame("Frame")
    bagWatcher:RegisterEvent("ADDON_LOADED")
    RegisterBagWatcherWorkEvents()
    bagWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    bagWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    bagWatcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            return
        end

        if event == "ADDON_LOADED" or event == "PLAYER_REGEN_ENABLED" then
            if event == "PLAYER_REGEN_ENABLED" then
                RegisterBagWatcherWorkEvents()
                ns:RefreshMovableWindows()
            end

            RefreshPanelWindowsSoon()
        end

        RefreshBagsSoon()
    end)
end

function ns:InitializeMovableWindows()
    if not self.db then
        return
    end

    ClearBlockedWindowState()
    InstallHooks()

    if self.db.windows.enabled then
        RegisterUIPanelWindows()
    end

    if self.db.windows.moveBags then
        RegisterBagWindows()
    end
end

function ns:RefreshMovableWindows()
    if InCombatLockdown() then return end
    ClearBlockedWindowState()
    RegisterUIPanelWindows()
    RegisterBagWindows()

    for frame in pairs(movableFrames) do
        UpdateWindowHandle(frame)
    end

    for frame in pairs(bagFrames) do
        UpdateBagHandle(frame)
    end
end

function ns:RefreshBagMovement()
    RegisterBagWindows()

    for frame in pairs(bagFrames) do
        UpdateBagHandle(frame)
    end
end

function ns:ResetMovableWindowPositions()
    if InCombatLockdown() then
        self:Print(L["Window positions can be reset after combat."])
        return false
    end
    if not self.db then
        return
    end

    self.db.windows.bagAnchor = nil
    wipe(self.db.windows.points)

    for frame in pairs(movableFrames) do
        ResetFramePosition(frame, false, "panel")
        UpdateWindowHandle(frame)
    end

    for frame in pairs(bagFrames) do
        ResetFramePosition(frame, false, "bag")
        UpdateBagHandle(frame)
    end

    ResetWorldMapPosition()

    self:Print(L["Saved window positions reset."])
end

function ns:ResetMovableWindowScales()
    if InCombatLockdown() then
        self:Print(L["Window scales can be reset after combat."])
        return false
    end
    if not self.db then
        return
    end

    self.db.windows.scales = self.db.windows.scales or {}
    wipe(self.db.windows.scales)

    for frame in pairs(movableFrames) do
        ResetFrameScale(frame, false)
        UpdateWindowHandle(frame)
    end

    for frame in pairs(bagFrames) do
        ResetFrameScale(frame, false, true)
        UpdateBagHandle(frame)
    end

    self:Print(L["Saved window scales reset."])
end

function ns:GetSavedWindowScaleCount()
    local count = 0

    if not self.db or not self.db.windows.scales then
        return count
    end

    for _ in pairs(self.db.windows.scales) do
        count = count + 1
    end

    return count
end

function ns:GetMovableWindowStats()
    local windowCount = 0
    local bagCount = 0
    local scaleCount = self.GetSavedWindowScaleCount and self:GetSavedWindowScaleCount() or 0

    for _ in pairs(movableFrames) do
        windowCount = windowCount + 1
    end

    if worldMapMoverInstalled and _G.WorldMapFrame then
        windowCount = windowCount + 1
    end

    for _ in pairs(bagFrames) do
        bagCount = bagCount + 1
    end

    return windowCount, bagCount, scaleCount
end
