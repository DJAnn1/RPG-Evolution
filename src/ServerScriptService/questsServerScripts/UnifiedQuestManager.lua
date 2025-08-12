-- UnifiedQuestManager.lua - Handles all quest logic (OPTIMIZED - REMOVED DUPLICATES)
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local QuestManager = {}

-- Helper function to get quest folder with validation
local function getQuestFolder(player)
	local quests = player:FindFirstChild("Quests")
	if not quests then
		warn("No quests folder found for player: " .. player.Name)
	end
	return quests
end

-- Helper function to get quest values
local function getQuestValues(player, questName)
	local quests = getQuestFolder(player)
	if not quests then return nil end

	local started = quests:FindFirstChild(questName .. "Started")
	local completed = quests:FindFirstChild(questName .. "Complete")
	local kills = quests:FindFirstChild(questName .. "Kills")

	return {
		started = started,
		completed = completed,
		kills = kills,
		isActive = started and started.Value and not completed,
		isCompleted = completed ~= nil
	}
end

-- Helper function to fire GUI events
local function fireGUIEvent(player, eventName, ...)
	local questEvents = ReplicatedStorage:FindFirstChild("questEvents")
	if questEvents then
		local event = questEvents:FindFirstChild(eventName)
		if event then
			event:FireClient(player, ...)
		end
	end
end

-- Function to check if player has any active quest
function QuestManager:HasActiveQuest(player)
	local quests = getQuestFolder(player)
	if not quests then return false end

	for _, questName in pairs(QuestConfig:GetAllQuestNames()) do
		local questValues = getQuestValues(player, questName)
		if questValues and questValues.isActive then
			return true, questName
		end
	end
	return false
end

-- Generic function to start any quest
function QuestManager:StartQuest(player, questName)
	local questConfig = QuestConfig:GetQuest(questName)
	if not questConfig then 
		return false, "Invalid quest name" 
	end

	local questValues = getQuestValues(player, questName)
	if not questValues then 
		return false, "No quests folder found" 
	end

	-- Check if quest is already completed
	if questValues.isCompleted then
		return false, "Quest already completed"
	end

	-- Check if player already has an active quest
	local hasActive, activeQuestName = self:HasActiveQuest(player)
	if hasActive then
		return false, "You already have an active quest: " .. activeQuestName
	end

	-- Start the quest
	if questValues.started and not questValues.started.Value then
		questValues.started.Value = true
		return true, "Quest started successfully"
	end

	return false, "Quest could not be started"
end

-- Function to cancel a quest
function QuestManager:CancelQuest(player, questName)
	local questConfig = QuestConfig:GetQuest(questName)
	if not questConfig then 
		return false, "Invalid quest name" 
	end

	local questValues = getQuestValues(player, questName)
	if not questValues then 
		return false, "No quests folder found" 
	end

	-- Check if quest is actually active
	if not questValues.isActive then
		return false, "Quest is not active"
	end

	if questValues.isCompleted then
		return false, "Cannot cancel completed quest"
	end

	-- Reset quest values
	questValues.started.Value = false
	if questValues.kills then
		questValues.kills.Value = 0
	end

	-- Fire GUI events
	local updateEventName = "Update" .. questName:gsub("^%l", string.upper) .. "GUI"
	local cancelEventName = "Cancel" .. questName:gsub("^%l", string.upper) .. "GUI"

	fireGUIEvent(player, updateEventName, 0) -- Reset to 0 kills
	fireGUIEvent(player, cancelEventName)

	return true, "Quest cancelled successfully"
end

-- Function to cancel any active quest (for GUI button)
function QuestManager:CancelActiveQuest(player)
	local hasActive, activeQuestName = self:HasActiveQuest(player)
	if not hasActive then
		return false, "No active quest to cancel"
	end

	return self:CancelQuest(player, activeQuestName)
end

-- Generic function to update kills for any quest
function QuestManager:UpdateKills(player, questName, requiredKills)
	local questValues = getQuestValues(player, questName)
	if not questValues or not questValues.isActive or not questValues.kills then 
		return 
	end

	questValues.kills.Value = questValues.kills.Value + 1

	-- Fire the appropriate GUI update event
	local updateEventName = "Update" .. questName:gsub("^%l", string.upper) .. "GUI"
	fireGUIEvent(player, updateEventName, questValues.kills.Value)

	-- Check if quest is complete
	if questValues.kills.Value >= requiredKills and not questValues.isCompleted then
		local complete = Instance.new("BoolValue")
		complete.Name = questName .. "Complete"
		complete.Value = true
		complete.Parent = getQuestFolder(player)

		-- Award quest rewards through centralized system
		LevelSystem.AwardQuestRewards(player, questName)
	end
end

-- Function to create all quest values for a player
function QuestManager:CreatePlayerQuestValues(player)
	local quests = Instance.new("Folder")
	quests.Name = "Quests"
	quests.Parent = player

	-- Create quest values for all configured quests
	for questName in pairs(QuestConfig.quests) do
		local questStarted = Instance.new("BoolValue")
		questStarted.Name = questName .. "Started"
		questStarted.Value = false
		questStarted.Parent = quests

		local questKills = Instance.new("IntValue")
		questKills.Name = questName .. "Kills"
		questKills.Value = 0
		questKills.Parent = quests
	end
end

-- Function to get quest status for dialogue
function QuestManager:GetQuestStatus(player, questName)
	local questValues = getQuestValues(player, questName)
	if not questValues then return "no_folder" end

	if questValues.isCompleted then return "completed" end

	local hasActive, activeQuestName = self:HasActiveQuest(player)
	if hasActive then return "has_active", activeQuestName end

	return "available"
end

return QuestManager