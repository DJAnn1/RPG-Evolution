-- UnifiedGUIUpdater.lua - Single script to handle all quest GUI updates (WITH CANCEL SUPPORT)
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Enhanced QuestGUIUpdater module that works with the config system
local QuestGUIUpdater = {}

function QuestGUIUpdater.SetupAllQuests()
	task.wait(0.5) -- Wait for GUI to load

	for questName, questConfig in pairs(QuestConfig.quests) do
		QuestGUIUpdater.SetupSingleQuest(questName, questConfig)
	end
end

function QuestGUIUpdater.SetupSingleQuest(questName, questConfig)
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local questEvents = replicatedStorage:WaitForChild("questEvents")
	local updateEventName = "Update" .. questName:gsub("^%l", string.upper) .. "GUI"
	local updateEvent = questEvents:WaitForChild(updateEventName)

	-- NEW: Get cancel event
	local cancelEventName = "Cancel" .. questName:gsub("^%l", string.upper) .. "GUI"
	local cancelEvent = questEvents:WaitForChild(cancelEventName)

	local kills = 0
	local lastKnownKills = -1

	-- Wait for GUI frame with timeout
	local function waitForQuestFrame()
		local maxAttempts = 10
		local attempt = 0

		while attempt < maxAttempts do
			local questsGUI = playerGui:FindFirstChild("questsGUI")
			if not questsGUI then
				attempt = attempt + 1
				--print("Waiting for questsGUI... Attempt " .. attempt)
				task.wait(1)
				continue
			end

			local arena = questsGUI:FindFirstChild(questConfig.guiLocation.arena)
			if not arena then
				attempt = attempt + 1
				--print("Waiting for " .. questConfig.guiLocation.arena .. "... Attempt " .. attempt)
				task.wait(1)
				continue
			end

			local questElement = arena:FindFirstChild(questName)
			if questElement then
				local questFrame = questElement:FindFirstChild(questConfig.guiLocation.frame)
				if questFrame then
					--print("Found quest frame for " .. questName .. " after " .. attempt .. " attempts")
					return questFrame
				end
			end

			attempt = attempt + 1
			--print("Waiting for " .. questName .. "... Attempt " .. attempt)
			task.wait(1)
		end

		warn("Quest GUI frame not found for: " .. questName .. " after " .. maxAttempts .. " attempts")
		return nil
	end

	local questFrame = waitForQuestFrame()
	if not questFrame then
		return
	end

	local label = questFrame:FindFirstChild(questConfig.guiLocation.label)
	if not label then
		warn("Label '" .. questConfig.guiLocation.label .. "' not found in quest frame for: " .. questName)
		return
	end

	local questGUI = questFrame.Parent

	-- Get current kill count from player's quest data
	local function getCurrentKills()
		local questsFolder = player:FindFirstChild("Quests")
		if not questsFolder then return 0 end

		local killCounter = questsFolder:FindFirstChild(questName .. "Kills")
		return killCounter and killCounter.Value or 0
	end

	local function updateText()
		local remaining = math.max(questConfig.enemiesRequired - kills, 0)
		if remaining <= 0 then
			label.Text = "Quest Complete!"
			task.delay(3, function()
				questFrame.Visible = false
			end)
		else
			label.Text = "Enemies Remaining: " .. remaining
		end
	end

	-- NEW: Function to hide quest GUI when cancelled
	local function hideQuestGUI()
		questFrame.Visible = false
		questGUI.Enabled = false
		kills = 0
		lastKnownKills = 0
		--print("Hidden GUI for cancelled quest: " .. questName)
	end

	-- Initialize the GUI with current kill count
	local function initializeGUI()
		local currentKills = getCurrentKills()
		if currentKills ~= lastKnownKills then
			kills = currentKills
			lastKnownKills = currentKills
			updateText()
		end

		-- Make sure the frame is visible when quest is active
		local questsFolder = player:FindFirstChild("Quests")
		if questsFolder then
			local started = questsFolder:FindFirstChild(questName .. "Started")
			local completed = questsFolder:FindFirstChild(questName .. "Complete")

			if started and started.Value and not completed then
				questFrame.Visible = true
				questGUI.Enabled = true
				--print("✅ Initialized visible GUI for active quest:", questName)
			end
		end
	end

	-- Periodic check for kill count changes
	local function startPeriodicCheck()
		local heartbeat = game:GetService("RunService").Heartbeat
		heartbeat:Connect(function()
			if questGUI.Enabled and questFrame.Visible then
				local currentKills = getCurrentKills()
				if currentKills ~= lastKnownKills then
					kills = currentKills
					lastKnownKills = currentKills
					updateText()
				end
			end
		end)
	end

	-- Start systems
	startPeriodicCheck()
	initializeGUI()

	-- Listen for kill updates from server
	updateEvent.OnClientEvent:Connect(function(currentKills)
		kills = currentKills
		lastKnownKills = currentKills
		updateText()
	end)

	-- NEW: Listen for quest cancel events
	cancelEvent.OnClientEvent:Connect(function()
		hideQuestGUI()
	end)

	--print("Successfully set up GUI for quest: " .. questName)
end

-- Auto-setup all quests
QuestGUIUpdater.SetupAllQuests()

return QuestGUIUpdater