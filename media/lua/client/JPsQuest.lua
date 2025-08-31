require("EquipmentUI/Settings")

local CITIES = {
    { NAME = 'Muldraugh',   MIN_X = 34, MAX_X = 37, MIN_Y = 29, MAX_Y = 36, },
    { NAME = 'Westpoint',   MIN_X = 35, MAX_X = 41, MIN_Y = 21, MAX_Y = 24, },
    { NAME = 'Riverside',   MIN_X = 19, MAX_X = 22, MIN_Y = 16, MAX_Y = 20, },
    { NAME = 'Rosewood',    MIN_X = 26, MAX_X = 28, MIN_Y = 37, MAX_Y = 40, },
    { NAME = 'March Ridge', MIN_X = 32, MAX_X = 35, MIN_Y = 42, MAX_Y = 44, },
}
local ZOMBIES_TO_KILL_BERSERK = 5 -- probably 100
local QUEST_TIMEOUT_MINUTES = 1 * 60 -- Probably 1 day (24 * 60)?
local XP_ON_QUEST_COMPLETE = 1000

local function isPlayerInCity(player, city)
    local cellX = player:getX() / 300;
    local cellY = player:getY() / 300;

    local inCity = cellX > city.MIN_X and cellX < city.MAX_X and cellY > city.MIN_Y and cellY < city.MAX_Y

    print("Player is in "..cellX..", "..cellY.." which is in "..city.NAME.."? "..tostring(inCity))
    return inCity
end

local function killPlayer(player)
    player:setHealth(0)
end

local function levelUpRandomPerk(player)
    local randomPerkIdx = ZombRand(Perks.getMaxIndex())
    local perk = PerkFactory.getPerk(Perks.fromIndex(randomPerkIdx))
    print("[JP's Quest] Adding XP to perk "..perk:getName())
    player:getXp():AddXP(perk, XP_ON_QUEST_COMPLETE);
end

local function questTrackerMsg(player, msg)
    player:setHaloNote(msg, 255, 0, 0, 200)
    local tracker = player:getInventory():FindAndReturn("JPsQuests.QuestTracker")
    if tracker == nil then
        print("[JP's Quest] Unable to update Quest Tracker")
        return
    end
    tracker:setTooltip(msg)
end

-- Expected to run once.
function JPsQuests:homesickQuest(player, args, successCB)
    local randomCity = CITIES[args.cityIdx]
    print("[JP's Quest] Chosen city: "..randomCity.NAME)
    questTrackerMsg(player, "JP's Quest: Get to "..randomCity.NAME..". You have ".. QUEST_TIMEOUT_MINUTES.." minutes.")
    local MINUTES_BEFORE_STARTING = 10

    JPsQuestsUtils:timer(MINUTES_BEFORE_STARTING, function()
        local minutesToDeadline = QUEST_TIMEOUT_MINUTES
        local function checkQuestCondition()
            minutesToDeadline = minutesToDeadline - MINUTES_BEFORE_STARTING
            print("[JP's Quest] Minutes left for quest deadline: "..minutesToDeadline)
            -- Success condition
            if (isPlayerInCity(player, randomCity)) then
                Events.EveryTenMinutes.Remove(checkQuestCondition)
                successCB(true)
                questTrackerMsg(player, "JP's Quest: You made it to "..randomCity.NAME..". You have completed the quest!")
                levelUpRandomPerk(player)
                return
            -- Failed condition
            elseif (minutesToDeadline <= 0) then
                Events.EveryTenMinutes.Remove(checkQuestCondition)
                successCB(false)
                questTrackerMsg(player, "JP's Quest: You have failed to reach "..randomCity.NAME.." in time.")
                JPsQuestsUtils:timer(3, function() player:setHaloNote("Now you must suffer the consequences.", 255, 0, 0, 200) end)
                JPsQuestsUtils:timer(5, function() killPlayer(player) end)
                return
            end

            questTrackerMsg(player, "JP's Quest: You have "..minutesToDeadline.." minutes to get to "..randomCity.NAME)
        end
        Events.EveryTenMinutes.Add(checkQuestCondition)
    end)
end

function JPsQuests:berserkQuest(player, args, successCB)
    local initialKills = player:getZombieKills()
    questTrackerMsg(player, "JP's Quest: Kill "..ZOMBIES_TO_KILL_BERSERK.." zombies. You have ".. QUEST_TIMEOUT_MINUTES.." minutes.")

    local MINUTES_BEFORE_STARTING = 10
    local minutesToDeadline = QUEST_TIMEOUT_MINUTES
    local function checkQuestCondition()
        minutesToDeadline = minutesToDeadline - MINUTES_BEFORE_STARTING
        local zombiesKilled = player:getZombieKills() - initialKills
        -- Success condition
        if (zombiesKilled >= ZOMBIES_TO_KILL_BERSERK) then
            Events.EveryTenMinutes.Remove(checkQuestCondition)
            successCB(true)
            questTrackerMsg(player, "JP's Quest: Your thirst for blood is saciated. You have completed the quest!")
            levelUpRandomPerk(player)
            return
        -- Failed condition
        elseif (minutesToDeadline <= 0) then
            JPsQuests.activeState = JPsQuests.STATES.DISABLED
            Events.EveryTenMinutes.Remove(checkQuestCondition)
            questTrackerMsg(player, "JP's Quest: You failed to kill enought zombies.")
            JPsQuestsUtils:timer(3, function() player:setHaloNote("Now you must suffer the consequences.", 255, 0, 0, 200) end)
            JPsQuestsUtils:timer(5, function() killPlayer(player) end)
            successCB(false)
            return
        end

        questTrackerMsg(player, "JP's Quest: Kill " ..ZOMBIES_TO_KILL_BERSERK.." zombies. "..(ZOMBIES_TO_KILL_BERSERK - zombiesKilled).." remaining. You have "..minutesToDeadline.." minutes left.")
    end
    Events.EveryTenMinutes.Add(checkQuestCondition)
end

function JPsQuests:pacifistQuest(player, args, successCB)
    local initialKills = player:getZombieKills()
    questTrackerMsg(player, "JP's Quest: Do not kill any zombies. You have ".. QUEST_TIMEOUT_MINUTES.." minutes.")

    local MINUTES_BEFORE_STARTING = 10
    local minutesToDeadline = QUEST_TIMEOUT_MINUTES
    local function checkQuestCondition()
        minutesToDeadline = minutesToDeadline - MINUTES_BEFORE_STARTING
        -- Failed condition
        if (player:getZombieKills() > initialKills) then
            JPsQuests.activeState = JPsQuests.STATES.DISABLED
            Events.EveryTenMinutes.Remove(checkQuestCondition)
            questTrackerMsg(player, "JP's Quest: You have killed a zombie and failed the quest.")
            JPsQuestsUtils:timer(3, function() player:setHaloNote("Now you must suffer the consequences.", 255, 0, 0, 200) end)
            JPsQuestsUtils:timer(5, function() killPlayer(player) end)
            successCB(false)
            return
        -- Success condition
        elseif (minutesToDeadline <= 0) then
            Events.EveryTenMinutes.Remove(checkQuestCondition)
            successCB(true)
            questTrackerMsg(player, "JP's Quest: You are a true pacifist. You have completed the quest!")
            levelUpRandomPerk(player)
            return
        end

        questTrackerMsg(player, "JP's Quest: Do not kill zombies. You have "..minutesToDeadline.." minutes left.")
    end
    Events.EveryTenMinutes.Add(checkQuestCondition)
end

-- Must match JPsQuests.ROLLABLE_QUESTS
JPsQuests.QUESTS = {
    { ID = "PACIFIST", FUNC = JPsQuests.pacifistQuest, },
    { ID = "BERSERK",  FUNC = JPsQuests.berserkQuest, },
    { ID = "HOMESICK", FUNC = JPsQuests.homesickQuest, },
}

function JPsQuests:getQuestByID(id)
    for i = 1, #JPsQuests.QUESTS do
        local candidateQuest = JPsQuests.QUESTS[i]
        if (id == tostring(candidateQuest.ID)) then
            return candidateQuest
        end
    end
    return nil
end

local function jpsQuestOnPlayerUpdate(player)
    -- Check if item is lost. If so, kill the player.
    local questTracker = player:getInventory():FindAndReturn("JPsQuests.QuestTracker")
    if questTracker == nil then
        print("Player lost Quest Tracker. Killing them.")
        killPlayer(player)
    end
end

-- Events.OnPlayerUpdate.Add(jpsQuestOnPlayerUpdate)
JPsQuests:init()