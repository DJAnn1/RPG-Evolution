-- UnifiedQuestRefresher.lua - Auto-refreshes quest GUIs based on config
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))
local player = game.Players.LocalPlayer
local questsFolder = player:WaitForChild("Quests")

-- Function to safely wait for the quests GUI to appear
local function getQuestsGUI()
	local playerGui = player:WaitForChild("PlayerGui")
	local maxWaitTime = 10
	local startTime = tick()

	while tick() - startTime < maxWaitTime do
		local gui = playerGui:FindFirstChild("questsGUI")
		if gui then return gui end
		task.wait(0.1)
	end

	warn("questsGUI did not load within time limit")
	return nil
end

-- Function to check if a quest is active and not completed
local function isQuestActive(questName)
	local started = questsFolder:FindFirstChild(questName .. "Started")
	local completed = questsFolder:FindFirstChild(questName .. "Complete")
	return started and started.Value and not completed
end

-- Main logic to refresh all active quest GUIs
local function refreshQuestGUI()
	local questsGUI = getQuestsGUI()
	if not questsGUI then return end

	-- Check each quest from config
	for questName, questConfig in pairs(QuestConfig.quests) do
		if isQuestActive(questName) then
			local arena = questsGUI:FindFirstChild(questConfig.guiLocation.arena)
			if arena then
				local questGUI = arena:FindFirstChild(questName)
				if questGUI then
					questGUI.Enabled = true
					--print("Enabled GUI for active quest: " .. questName)
				else
					warn(questName .. " GUI not found in " .. questConfig.guiLocation.arena)
				end
			else
				warn(questConfig.guiLocation.arena .. " not found in questsGUI")
			end
		end
	end
end

-- Run once on player load with a small delay
task.wait(1)
refreshQuestGUI()

-- Also rerun when the character respawns
player.CharacterAdded:Connect(function()
	task.wait(3) -- Give plenty of time for everything to load
	refreshQuestGUI()
end)