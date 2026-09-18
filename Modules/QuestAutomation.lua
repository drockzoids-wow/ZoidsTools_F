local _, ns = ...
local frame
local rewardsClaimed = {}
local modifiers = { shift = true, ctrl = true, alt = true, none = true }

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if ok and not Secret(a) and not Secret(b) then return a, b end
end

local function True(value) return value == true or value == 1 end

function ns:GetQuestAutomationOption(key)
    return self.db and self.db.quests and self.db.quests[key] == true
end

function ns:SetQuestAutomationOption(key, value)
    if key == "autoAccept" or key == "autoTurnIn" then self.db.quests[key] = value == true end
end

function ns:GetQuestAutomationPauseModifier()
    local value = self.db.quests.pauseModifier
    return modifiers[value] and value or "shift"
end

function ns:SetQuestAutomationPauseModifier(value)
    self.db.quests.pauseModifier = modifiers[value] and value or "shift"
end

local function Allowed(key)
    if not ns:GetQuestAutomationOption(key) then return false end
    local modifier = ns:GetQuestAutomationPauseModifier()
    if modifier == "none" then return true end
    local api = ({ shift = IsShiftKeyDown, ctrl = IsControlKeyDown, alt = IsAltKeyDown })[modifier]
    local held = Call(api)
    -- If the key state is unavailable, leave the interaction to the player.
    return held == false or held == 0
end

local function Gossip()
    local api = C_GossipInfo
    if not api then return end
    for _, info in ipairs({
        { key = "autoTurnIn", get = api.GetActiveQuests, select = api.SelectActiveQuest, complete = true },
        { key = "autoAccept", get = api.GetAvailableQuests, select = api.SelectAvailableQuest },
    }) do
        if Allowed(info.key) and type(info.select) == "function" then
            local quests = Call(info.get)
            if type(quests) == "table" then
                for _, quest in ipairs(quests) do
                    if not Secret(quest) and type(quest) == "table" then
                        local id, complete = quest.questID, quest.isComplete
                        if not Secret(id) and type(id) == "number" and id > 0
                            and (not info.complete or (not Secret(complete) and True(complete))) then
                            Call(info.select, id)
                            return
                        end
                    end
                end
            end
        end
    end
end

local function Greeting()
    if Allowed("autoTurnIn") then
        local count = Call(GetNumActiveQuests)
        if type(count) == "number" then
            for index = 1, count do
                local _, complete = Call(GetActiveTitle, index)
                if True(complete) then Call(SelectActiveQuest, index); return end
            end
        end
    end
    if Allowed("autoAccept") then
        local count = Call(GetNumAvailableQuests)
        if type(count) == "number" and count > 0 then Call(SelectAvailableQuest, 1) end
    end
end

local function Reward()
    if not Allowed("autoTurnIn") then return end
    local count = Call(GetNumQuestChoices)
    if count ~= 0 and count ~= 1 then return end
    local id = Call(GetQuestID)
    if type(id) ~= "number" or id <= 0 or rewardsClaimed[id] then return end
    if type(GetQuestReward) ~= "function" then return end
    rewardsClaimed[id] = true
    if count == 1 then Call(GetQuestReward, 1) else Call(GetQuestReward) end
end

function ns:InitializeQuestAutomation()
    if frame then return end
    frame = CreateFrame("Frame")
    for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL",
        "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED" }) do
        ns:RegisterCompatibleEvent(frame, event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
            rewardsClaimed = {}
        elseif event == "GOSSIP_SHOW" then
            Gossip()
        elseif event == "QUEST_GREETING" then
            Greeting()
        elseif event == "QUEST_DETAIL" then
            if Allowed("autoAccept") then Call(AcceptQuest) end
        elseif event == "QUEST_PROGRESS" then
            if Allowed("autoTurnIn") and True(Call(IsQuestCompletable)) then Call(CompleteQuest) end
        elseif event == "QUEST_COMPLETE" then
            Reward()
        end
    end)
end
