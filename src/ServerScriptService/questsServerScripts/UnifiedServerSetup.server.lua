-- UnifiedServerSetup.lua - FIXED to handle BindableEvents properly
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))
local QuestManager = require(script.Parent:WaitForChild("UnifiedQuestManager"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create quest events folder structure
local function createQuestEvents()
	local questEvents = ReplicatedStorage:FindFirstChild("questEvents")
	if not questEvents then
		questEvents = Instance.new("Folder")
		questEvents.Name = "questEvents"
		questEvents.Parent = ReplicatedStorage
	end

	-- Create questError RemoteEvent
	if not questEvents:FindFirstChild("questError") then
		local questError = Instance.new("RemoteEvent")
		questError.Name = "questError"
		questError.Parent = questEvents
	end

	-- Create quest cancel event
	if not questEvents:FindFirstChild("cancelQuest") then
		local cancelQuest = Instance.new("RemoteEvent")
		cancelQuest.Name = "cancelQuest"
		cancelQuest.Parent = questEvents
	end

	-- Create quest start events, GUI update events, and cancel GUI events for all quests
	for questName in pairs(QuestConfig.quests) do
		-- Quest start event
		if not questEvents:FindFirstChild(questName) then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = questName
			remoteEvent.Parent = questEvents
		end

		-- GUI update event
		local guiUpdateName = "Update" .. questName:gsub("^%l", string.upper) .. "GUI"
		if not questEvents:FindFirstChild(guiUpdateName) then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = guiUpdateName
			remoteEvent.Parent = questEvents
		end

		-- GUI cancel event
		local guiCancelName = "Cancel" .. questName:gsub("^%l", string.upper) .. "GUI"
		if not questEvents:FindFirstChild(guiCancelName) then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = guiCancelName
			remoteEvent.Parent = questEvents
		end
	end

	return questEvents
end

-- Connect all quest start events dynamically
local function connectQuestEvents(questEvents)
	for questName in pairs(QuestConfig.quests) do
		local questEvent = questEvents:FindFirstChild(questName)
		if questEvent then
			questEvent.OnServerEvent:Connect(function(player)
				local success, message = QuestManager:StartQuest(player, questName)
				if not success then
					questEvents.questError:FireClient(player, message)
				end
			end)
		end
	end

	-- Connect quest cancel event
	local cancelQuestEvent = questEvents:FindFirstChild("cancelQuest")
	if cancelQuestEvent then
		cancelQuestEvent.OnServerEvent:Connect(function(player)
			local success, message = QuestManager:CancelActiveQuest(player)
			if not success then
				questEvents.questError:FireClient(player, message)
			else
				questEvents.questError:FireClient(player, message)
			end
		end)
	end
end

-- FIXED: Connect kill events with proper BindableEvent handling
local function connectKillEvents()
	local killEventMapping = QuestConfig:GetKillEventMapping()
	for killEventName, questData in pairs(killEventMapping) do
		local killEvent = ReplicatedStorage.spawnEvents:FindFirstChild(killEventName)
		if killEvent then
			-- FIXED: Handle BindableEvent properly
			if killEvent:IsA("BindableEvent") then
				killEvent.Event:Connect(function(playersWhoHit)
					-- Ensure playersWhoHit is a table
					if type(playersWhoHit) == "table" then
						for _, player in pairs(playersWhoHit) do
							if player and player:IsA("Player") then
								QuestManager:UpdateKills(
									player, 
									questData.questName, 
									questData.enemiesRequired
								)
							end
						end
					elseif playersWhoHit and playersWhoHit:IsA("Player") then
						-- Handle single player case
						QuestManager:UpdateKills(
							playersWhoHit, 
							questData.questName, 
							questData.enemiesRequired
						)
					end
				end)
			elseif killEvent:IsA("RemoteEvent") then
				-- Handle RemoteEvent case
				killEvent.OnServerEvent:Connect(function(player, ...)
					QuestManager:UpdateKills(
						player, 
						questData.questName, 
						questData.enemiesRequired
					)
				end)
			end
			--print("Connected kill event: " .. killEventName .. " for quest: " .. questData.questName)
		else
			warn("Kill event not found: " .. killEventName)
		end
	end
end

-- Handle player joining
local function onPlayerAdded(player)
	QuestManager:CreatePlayerQuestValues(player)
end

-- Initialize the system
local function initialize()
	local questEvents = createQuestEvents()
	connectQuestEvents(questEvents)
	connectKillEvents()

	-- Connect player events
	game.Players.PlayerAdded:Connect(onPlayerAdded)

	-- Handle players already in game
	for _, player in pairs(game.Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	--print("Unified Quest System initialized - Using centralized LevelSystem for rewards with Cancel functionality")
end

-- Start the system
initialize()