local _, ns = ...
local L = ns.L or setmetatable({}, {__index=function(_,key)return key end})
local reminder
function ns:ShowRecoveryReminder()
    if not self.db then return end
    if not reminder then
        local frame = CreateFrame("Frame", "ZoidsTools_FRecoveryReminder", UIParent, "BackdropTemplate")
        reminder = frame
        frame:SetSize(620, 170)
        frame:SetPoint("TOP", UIParent, "TOP", 0, -90)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("DIALOG")
        ns.UI.Theme.ApplyPanelBackdrop(frame)
        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText(L["BETA SETTINGS REMINDER"])
        title:SetTextColor(unpack(ns.UI.Theme.colors.gold))
        local text = ns.UI.CreateBodyText(frame,
            L["Save & reload writes a preset, but the beta may fail to load it.\nIf Restore stays disabled, run Save-BetaPreset.ps1 in the addon folder.\nRestore replaces newer changes. Re-run the helper to update its fixed preset."], 588)
        text:SetPoint("TOPLEFT", 16, -42)
        text:SetHeight(64)
        text:SetWordWrap(true)
        text:SetJustifyV("TOP")
        local save = ns.UI.CreateButton(frame, L["Save & reload"], 180, 30)
        save:SetPoint("BOTTOMLEFT", 16, 16)
        save:SetScript("OnClick", function()
            if InCombatLockdown and InCombatLockdown() then
                ns:Print("Save and reload after leaving combat.")
                return
            end
            local service = ZoidsTools_FRecoveryService
            local warning = service and service.GetPresetSaveWarning and service:GetPresetSaveWarning()
            if warning then ns:Print(warning); return end
            if service and service.SavePreset and service:SavePreset() then
                if ReloadUI then ReloadUI() end
            else ns:Print("Settings are not ready to save yet.") end
        end)
        local restore = ns.UI.CreateButton(frame, L["Restore preset"], 180, 30)
        restore:SetPoint("LEFT", save, "RIGHT", 12, 0)
        restore:SetScript("OnClick", function() SlashCmdList.ZOIDSTOOLS_FOREVER("restorepreset") end)
        local later = ns.UI.CreateButton(frame, L["Later"], 180, 30)
        later:SetPoint("LEFT", restore, "RIGHT", 12, 0)
        later:SetScript("OnClick", function() frame:Hide() end)
        frame.saveButton, frame.restoreButton, frame.laterButton = save, restore, later
        local function RefreshActions()
            local combat = InCombatLockdown and InCombatLockdown()
            local service = ZoidsTools_FRecoveryService
            local preset = service and service.GetPreset and service:GetPreset() or ZoidsTools_FRecovery
            ns.UI.SetControlEnabled(save, not combat and service ~= nil)
            ns.UI.SetControlEnabled(restore, not combat and type(preset)=="table" and next(preset)~=nil)
        end
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function() if frame:IsShown() then RefreshActions() end end)
        frame:SetScript("OnShow", RefreshActions)
        RefreshActions()
    end
    reminder:Show()
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() ns:ShowRecoveryReminder() end)
