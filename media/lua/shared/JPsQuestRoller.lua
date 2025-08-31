JPsQuests = JPsQuests or {}

JPsQuests.QUEST_CHECK_PERIOD = Events.EveryTenMinutes -- Probably every Day in a real game?
JPsQuests.PERCENT_FOR_QUEST = 100
JPsQuests.QUEST_TIMEOUT_MINUTES = 1 * 60 -- Probably 1 day (24 * 60)?
JPsQuests.COOLDOWN_MINUTES = 60 -- Probably 60?
JPsQuests.WAIT_BEFORE_FIRST_ROLL_MINUTES = 1 -- Probably 60?
JPsQuests.SERVER_QUEST_TIMEOUT_MINUTES = JPsQuests.QUEST_TIMEOUT_MINUTES + 10 -- Probably 60?

-- Quest rolling states
JPsQuests.STATES = {
    ROLLING  = {},
    ACTIVE   = {},
    COOLDOWN = {},
    DISABLED = {},
}
JPsQuests.activeState = JPsQuests.STATES.ROLLING
JPsQuests.latestPlayersSeen = {}

-- Running environment mode
JPsQuests.MODES = {
    SP  = {},
    MP_SERVER   = {},
    MP_CLIENT = {},
}
JPsQuests.mode = JPsQuests.MODES.SP

-- Must match JPsQuests.QUESTS (that one is not available on servers)
JPsQuests.ROLLABLE_QUESTS = {
    { ID = "PACIFIST", ARGS_FUNC = function() return {} end },
    { ID = "HOMESICK", ARGS_FUNC = function() return { cityIdx = (ZombRand(5) + 1) } end },
    { ID = "BERSERK",  ARGS_FUNC = function() return {} end },
}

local function sendServerCommandEligiblePlayers(cmd, args)
	local players = getOnlinePlayers();
    -- TODO: Filter out new ones.
    for i = 0, players:size() - 1 do
        print("[JP's Quest] Sending command to player: "..i)
        sendServerCommand(players:get(i), "jpsquest", cmd, args)
    end
end

local function halonote(msg)
    if JPsQuests.mode == JPsQuests.MODES.SP or JPsQuests.mode == JPsQuests.MODES.MP_CLIENT then
        getPlayer():setHaloNote(msg, 255, 0, 0, 200)
    elseif JPsQuests.mode == JPsQuests.MODES.MP_SERVER then
        sendServerCommandEligiblePlayers("halonote", { text = msg })
    end
end

local function additem(item)
    if JPsQuests.mode == JPsQuests.MODES.SP or JPsQuests.mode == JPsQuests.MODES.MP_CLIENT then
        if (getPlayer():getInventory():FindAndReturn(item) == nil) then
            --print("[JP's Quest] Giving player item "..item)
            getPlayer():getInventory():AddItem(item)
        else
            --print("[JP's Quest] Player already has item "..item)
        end
    elseif JPsQuests.mode == JPsQuests.MODES.MP_SERVER then
        sendServerCommandEligiblePlayers("additem", { item = item })
    end
end

local function startquest(questID, args)
    print("[JP's Quest] Request to start quest "..questID)
    if JPsQuests.mode == JPsQuests.MODES.SP or JPsQuests.mode == JPsQuests.MODES.MP_CLIENT then
        local fetchedQuest = JPsQuests:getQuestByID(questID)
        if (fetchedQuest == nil) then
            print("[JP's Quest] Unknown quest: "..questID)
            return
        end
        print("[JP's Quest] Starting quest: "..fetchedQuest.ID)
        fetchedQuest:FUNC(getPlayer(), args, function(success)
            print("[JP's Quest] Player has finished quest. Success? "..tostring(success))
            if (success) then
                JPsQuests.activeState = JPsQuests.STATES.COOLDOWN
                JPsQuestsUtils:timer(JPsQuests.COOLDOWN_MINUTES, function() JPsQuests.activeState = JPsQuests.STATES.ROLLING end)
            else
                JPsQuests.activeState = JPsQuests.STATES.DISABLED
            end
        end)
    elseif JPsQuests.mode == JPsQuests.MODES.MP_SERVER then
        print("[JP's Quest] Rolled quest "..questID..". Notifying clients.")
        sendServerCommandEligiblePlayers("startquest", { quest = questID, questargs = args })

        -- Server doesn't know if players finished the quest. Wait for the quest to expire and roll a new one.
        JPsQuestsUtils:timer(JPsQuests.SERVER_QUEST_TIMEOUT_MINUTES, function()
            print("[JP's Quest] Server-triggered quest expired. Getting ready to roll a new one.")
            JPsQuests.activeState = JPsQuests.STATES.ROLLING
        end)
    end
end

-- Expected to run in a loop.
local function rollForQuest()
    -- Add item to inventory. TODO: Move to a "new player" checker, rather than re-adding it in a loop.
    --print("[JP's Quest] Adding Quest Tracker.")
    additem("JPsQuests.QuestTracker")

    if JPsQuests.activeState == JPsQuests.STATES.DISABLED then
        print("[JP's Quest] Quests are disabled.")
        return
    elseif JPsQuests.activeState == JPsQuests.STATES.ACTIVE then
        print("[JP's Quest] A quest is active. Don't roll.")
        return
    elseif JPsQuests.activeState == JPsQuests.STATES.COOLDOWN then
        print("[JP's Quest] In cooldown. Waiting.")
        return
    elseif (ZombRand(100) <= JPsQuests.PERCENT_FOR_QUEST) then
        JPsQuests.activeState = JPsQuests.STATES.ACTIVE

        JPsQuestsUtils:timer(5, function()
            halonote("JP's Quest: Rolling for a new quest...")
            local questRoll = ZombRand(#JPsQuests.ROLLABLE_QUESTS) + 1
            local questWithArgs = JPsQuests.ROLLABLE_QUESTS[questRoll]
            startquest(questWithArgs.ID, questWithArgs:ARGS_FUNC())
        end)
    end
end

-- Expected to be called once.
local function jpsQuestOnStart()
    -- Wait a bit. Then initialize a timer to roll for quests.
    JPsQuestsUtils:timer(JPsQuests.WAIT_BEFORE_FIRST_ROLL_MINUTES, function()
        -- Roll quests.
        JPsQuests.QUEST_CHECK_PERIOD.Add(rollForQuest)
    end)
end

local function jpsQuestOnServerCommand(module, command, args)
    print("[JP's Quest] Received command "..module.."::"..command)
    if (module ~= "jpsquest") then return end
    if (command == "additem") then additem(args["item"]) end
    if (command == "halonote") then halonote(args["text"]) end
    if (command == "startquest") then startquest(args["quest"], args["questargs"]) end
end

print("[JP's Quest] Checking running environment.")

function JPsQuests:init()
    -- Singleplayer
    if (getWorld():getGameMode() ~= "Multiplayer") then
        print("[JP's Quest] Running as Singleplayer.")
        JPsQuests.mode = JPsQuests.MODES.SP
        Events.OnNewGame.Remove(jpsQuestOnStart)
        Events.OnNewGame.Add(jpsQuestOnStart)
    -- Multiplayer: Server
    elseif (isServer()) then
        print("[JP's Quest] Running as Multiplayer Server.")
        JPsQuests.mode = JPsQuests.MODES.MP_SERVER
        Events.OnServerStarted.Remove(jpsQuestOnStart)
        Events.OnServerStarted.Add(jpsQuestOnStart)
    -- Multiplayer: Client
    else
        print("[JP's Quest] Running as Multiplayer Client.")
        JPsQuests.mode = JPsQuests.MODES.MP_CLIENT
        Events.OnServerCommand.Remove(jpsQuestOnServerCommand)
        Events.OnServerCommand.Add(jpsQuestOnServerCommand)
    end
end