local frame
local held, choice, complete = {}, 0, true
local accepted, progressed, rewarded = 0, 0, 0
local selected, rewardChoice
local secret = {}
function issecretvalue(value) return value == secret end
function CreateFrame()
    frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(_, fn) self.handler = fn end
    return frame
end
function IsShiftKeyDown() return held.shift or false end
function IsControlKeyDown() return held.ctrl or false end
function IsAltKeyDown() return held.alt or false end
function AcceptQuest() accepted = accepted + 1 end
function CompleteQuest() progressed = progressed + 1 end
function IsQuestCompletable() return complete end
function GetQuestID() return 123 end
function GetNumQuestChoices() return choice end
function GetQuestReward(index) rewarded = rewarded + 1; rewardChoice = index end
C_GossipInfo = {
    GetActiveQuests = function() return { { questID = 11, isComplete = false }, { questID = 12, isComplete = true } } end,
    SelectActiveQuest = function(id) selected = id end,
    GetAvailableQuests = function() return { { questID = 13 } } end,
    SelectAvailableQuest = function(id) selected = id end,
}
function GetNumActiveQuests() return 2 end
function GetActiveTitle(index) return 'Quest', index == 2 end
function SelectActiveQuest(index) selected = index end
function GetNumAvailableQuests() return 1 end
function SelectAvailableQuest(index) selected = index end
local function Event(event) frame.handler(frame, event) end

function RunQuestTests(ns)
    ns:InitializeQuestAutomation()
    Event('QUEST_DETAIL'); Event('QUEST_PROGRESS'); Event('QUEST_COMPLETE')
    assert(accepted == 0 and progressed == 0 and rewarded == 0)
    ns:SetQuestAutomationOption('autoAccept', true)
    ns:SetQuestAutomationOption('autoTurnIn', true)
    Event('GOSSIP_SHOW'); assert(selected == 12)
    Event('QUEST_GREETING'); assert(selected == 2)
    Event('QUEST_DETAIL'); assert(accepted == 1)
    Event('QUEST_PROGRESS'); assert(progressed == 1)
    Event('QUEST_COMPLETE'); Event('QUEST_COMPLETE')
    assert(rewarded == 1 and rewardChoice == nil)
    Event('QUEST_FINISHED'); choice = 1
    Event('QUEST_COMPLETE'); assert(rewarded == 2 and rewardChoice == 1)
    Event('QUEST_FINISHED'); choice = 2
    Event('QUEST_COMPLETE'); assert(rewarded == 2)
    choice = nil; Event('QUEST_COMPLETE'); assert(rewarded == 2)
    choice = secret; Event('QUEST_COMPLETE'); assert(rewarded == 2)
    choice = 0
    for _, key in ipairs({ 'shift', 'ctrl', 'alt' }) do
        ns:SetQuestAutomationPauseModifier(key)
        held[key] = true
        selected = nil
        Event('GOSSIP_SHOW'); Event('QUEST_GREETING'); Event('QUEST_DETAIL')
        Event('QUEST_PROGRESS'); Event('QUEST_COMPLETE')
        assert(selected == nil and accepted == 1 and progressed == 1 and rewarded == 2)
        held[key] = false
    end
    ns:SetQuestAutomationPauseModifier('none')
    held.shift, held.ctrl, held.alt = true, true, true
    Event('QUEST_DETAIL'); assert(accepted == 2)
    ns:SetQuestAutomationOption('autoTurnIn', false)
    Event('GOSSIP_SHOW'); assert(selected == 13)
    ns:SetQuestAutomationOption('autoTurnIn', true)
    complete = false
    Event('QUEST_PROGRESS'); assert(progressed == 1)
    complete = secret
    Event('QUEST_PROGRESS'); assert(progressed == 1)
    C_GossipInfo.GetActiveQuests = function() return secret end
    C_GossipInfo.GetAvailableQuests = nil
    selected = nil; Event('GOSSIP_SHOW'); assert(selected == nil)
    GetNumQuestChoices = nil; Event('QUEST_COMPLETE'); assert(rewarded == 2)
    ns:SetQuestAutomationPauseModifier('invalid')
    assert(ns:GetQuestAutomationPauseModifier() == 'shift')
end
