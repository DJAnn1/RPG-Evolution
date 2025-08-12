-- UnifiedDialogueSystem.lua - Client-side dialogue handler (ENHANCED DEBUG VERSION)
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))

local gui = script.Parent
local textBox = gui:WaitForChild("textBox")
local textLabel = textBox:WaitForChild("textLabel")
local sound = gui:WaitForChild("talkSound")
local plr = game.Players.LocalPlayer
local character = plr.Character or plr.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local replicatedStorage = game:GetService("ReplicatedStorage")
local questEvents = replicatedStorage:WaitForChild("questEvents")
local questsFolder = plr:WaitForChild("Quests")
local playerGui = plr:WaitForChild("PlayerGui")

gui.Enabled = false
textBox.Visible = false

local waitingForQuestResponse = false

-- DEBUG: --print all quest config info
--print("🔍 DEBUG: Quest Config Analysis")
for questName, questData in pairs(QuestConfig.quests) do
	--print("  Quest:", questName, "→ NPC:", questData.npcName)
end

-- Utility functions
local function getCurrentWalkSpeed()
	local statsFolder = plr:FindFirstChild("statsFolder")
	if statsFolder then
		local speedStat = statsFolder:FindFirstChild("speedStat")
		if speedStat then
			return 16 + (speedStat.Value * 1.5) 
		end
	end
	return 16 
end

local function writeText(text, waitTime)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	gui.Enabled = true
	textBox.Visible = true
	textLabel.Text = text
	sound:Play()
	task.wait(waitTime)
end

local function endDialogue()
	gui.Enabled = false
	textBox.Visible = false
	textLabel.Text = ""
	humanoid.WalkSpeed = getCurrentWalkSpeed() 
	humanoid.JumpPower = 50
end

-- Check if player has any active quest (client-side)
local function hasActiveQuest()
	if not questsFolder then return false end

	for questName in pairs(QuestConfig.quests) do
		local started = questsFolder:FindFirstChild(questName .. "Started")
		local completed = questsFolder:FindFirstChild(questName .. "Complete")

		if started and started.Value and not completed then
			return true, questName
		end
	end
	return false
end

-- Generic function to enable quest GUI
local function enableQuestGUI(questName)
	--print("🔍 DEBUG: Attempting to enable GUI for quest:", questName)

	local questConfig = QuestConfig:GetQuest(questName)
	if not questConfig then 
		warn("Quest config not found for:", questName)
		return 
	end

	local questsGUI = playerGui:FindFirstChild("questsGUI")
	if not questsGUI then 
		warn("questsGUI not found in PlayerGui")
		return 
	end

	local arena = questsGUI:FindFirstChild(questConfig.guiLocation.arena)
	if not arena then 
		warn("Arena not found:", questConfig.guiLocation.arena)
		return 
	end

	local questGUI = arena:FindFirstChild(questName)
	if questGUI then
		questGUI.Enabled = true

		-- Also make sure the frame itself is visible
		local questFrame = questGUI:FindFirstChild(questConfig.guiLocation.frame)
		if questFrame then
			questFrame.Visible = true
			--print("✅ Enabled and made visible:", questName, "GUI")
		else
			warn("Quest frame not found:", questConfig.guiLocation.frame)
		end
	else
		warn("Quest GUI not found in arena:", questName)
	end
end

-- Generic quest dialogue handler
local function handleQuestDialogue(questName, proximityPrompt)
	--print("🔍 DEBUG: handleQuestDialogue called for:", questName)

	if waitingForQuestResponse then 
		--print("🔍 DEBUG: Already waiting for quest response, ignoring")
		return 
	end

	proximityPrompt.Enabled = false
	--print("🔍 DEBUG: Disabled proximity prompt")

	local questConfig = QuestConfig:GetQuest(questName)
	--print("🔍 DEBUG: Got quest config:", questConfig and "✅" or "❌")

	-- Check quest status
	local completed = questsFolder:FindFirstChild(questName .. "Complete")
	local hasActive, activeQuestName = hasActiveQuest()

	--print("🔍 DEBUG: Quest status - Completed:", completed and "✅" or "❌", "HasActive:", hasActive, "ActiveQuest:", activeQuestName)

	if completed then
		-- Quest already completed
		--print("🔍 DEBUG: Showing completed dialogue")
		for _, line in ipairs(questConfig.completedDialogue) do
			writeText(line, 2)
		end

	elseif hasActive and activeQuestName ~= questName then
		-- Player has another active quest
		--print("🔍 DEBUG: Showing active quest dialogue")
		for _, line in ipairs(questConfig.activeQuestDialogue) do
			local formattedLine = string.format(line, activeQuestName)
			writeText(formattedLine, 2)
		end

	else
		-- Quest is available
		--print("🔍 DEBUG: Quest is available, showing NPC dialogue")
		for _, line in ipairs(questConfig.npcDialogue) do
			writeText(line, 2)
		end

		-- Start the quest
		--print("🔍 DEBUG: Starting quest...")
		waitingForQuestResponse = true
		local questEvent = questEvents:FindFirstChild(questName)
		if questEvent then
			--print("🔍 DEBUG: Found quest event, firing server")
			questEvent:FireServer()
		else
			--print("❌ DEBUG: Quest event not found:", questName)
		end

		task.wait(0.5)

		if waitingForQuestResponse then
			--print("🔍 DEBUG: Enabling quest GUI")
			enableQuestGUI(questName)
			endDialogue()
			waitingForQuestResponse = false
		end
	end

	if not (hasActive and activeQuestName == questName and not completed) then
		endDialogue()
	end

	task.wait(1)
	proximityPrompt.Enabled = true
	--print("🔍 DEBUG: Re-enabled proximity prompt")
end

-- Special NPC handler
local function handleSpecialNPC(npcName, config, proximityPrompt)
	--print("🔍 DEBUG: handleSpecialNPC called for:", npcName)
	proximityPrompt.Enabled = false

	for _, line in ipairs(config.dialogue) do
		writeText(line, 2)
	end

	if config.action then
		config.action(plr)
	end

	endDialogue()
	task.wait(1)
	proximityPrompt.Enabled = true
end

-- Wait for dialogue folder with timeout and enhanced checking
local function waitForDialogueFolder()
	local maxAttempts = 10
	local attempt = 0

	while attempt < maxAttempts do
		local dialogueFolder = game.Workspace:FindFirstChild("dialogueFolder")
		if dialogueFolder then
			-- ENHANCED: Wait a bit more to ensure all children are loaded
			task.wait(0.5)
			return dialogueFolder
		end
		attempt = attempt + 1
		task.wait(1)
		--print("Waiting for dialogueFolder... Attempt " .. attempt)
	end

	warn("dialogueFolder not found after " .. maxAttempts .. " attempts")
	return nil
end

-- Setup dialogue connections
local function setupDialogues()
	local dialogueFolder = waitForDialogueFolder()
	if not dialogueFolder then
		warn("No dialogue folder found - dialogue system disabled")
		return
	end

	-- ENHANCED DEBUG: More detailed folder inspection
	--print("🔍 DEBUG: Enhanced Contents of dialogueFolder:")
	for _, child in pairs(dialogueFolder:GetChildren()) do
		--print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
		local proximityPrompt = child:FindFirstChild("ProximityPrompt")
		--print("    ProximityPrompt:", proximityPrompt and "✅" or "❌")

		-- --print all children of each NPC
		--print("    Children:")
		for _, grandchild in pairs(child:GetChildren()) do
			--print("      - " .. grandchild.Name .. " (" .. grandchild.ClassName .. ")")
		end
	end

	-- ENHANCED: Try to wait for missing NPCs
	local missingNPCs = {}
	for questName, questConfig in pairs(QuestConfig.quests) do
		if not dialogueFolder:FindFirstChild(questConfig.npcName) then
			table.insert(missingNPCs, questConfig.npcName)
		end
	end

	if #missingNPCs > 0 then
		--print("🔍 DEBUG: Missing NPCs detected:", table.concat(missingNPCs, ", "))
		--print("🔍 DEBUG: Waiting 3 seconds for them to load...")
		task.wait(3)

		-- Check again
		--print("🔍 DEBUG: Rechecking missing NPCs...")
		for i, npcName in ipairs(missingNPCs) do
			local npc = dialogueFolder:FindFirstChild(npcName)
			if npc then
				--print("✅ DEBUG: Found " .. npcName .. " after waiting!")
			else
				--print("❌ DEBUG: " .. npcName .. " still missing")
			end
		end
	end

	-- Connect quest NPCs
	--print("🔍 DEBUG: Connecting quest NPCs...")
	for questName, questConfig in pairs(QuestConfig.quests) do
		--print("🔍 DEBUG: Looking for NPC:", questConfig.npcName, "for quest:", questName)

		local npcDialogue = dialogueFolder:FindFirstChild(questConfig.npcName)
		if npcDialogue then
			--print("🔍 DEBUG: Found NPC dialogue:", questConfig.npcName)

			local proximityPrompt = npcDialogue:FindFirstChild("ProximityPrompt")
			if proximityPrompt then
				--print("🔍 DEBUG: Found ProximityPrompt for:", questConfig.npcName)

				proximityPrompt.Triggered:Connect(function(player)
					--print("🔍 DEBUG: ProximityPrompt triggered for:", questConfig.npcName, "by player:", player.Name)
					handleQuestDialogue(questName, proximityPrompt)
				end)
				--print("✅ Connected dialogue for " .. questConfig.npcName .. " → " .. questName)
			else
				warn("❌ ProximityPrompt not found for " .. questConfig.npcName)
			end
		else
			warn("❌ NPC dialogue not found:", questConfig.npcName)
			-- ENHANCED: Show what IS available
			--print("Available NPCs in dialogueFolder:")
			for _, child in pairs(dialogueFolder:GetChildren()) do
				--print("  - " .. child.Name)
			end
		end
	end

	-- Connect special NPCs
	--print("🔍 DEBUG: Connecting special NPCs...")
	for npcName, config in pairs(QuestConfig.specialNPCs) do
		--print("🔍 DEBUG: Looking for special NPC:", npcName)

		local npcDialogue = dialogueFolder:FindFirstChild(npcName)
		if npcDialogue then
			--print("🔍 DEBUG: Found special NPC dialogue:", npcName)

			local proximityPrompt = npcDialogue:FindFirstChild("ProximityPrompt")
			if proximityPrompt then
				--print("🔍 DEBUG: Found ProximityPrompt for special NPC:", npcName)

				proximityPrompt.Triggered:Connect(function(player)
					--print("🔍 DEBUG: Special NPC ProximityPrompt triggered for:", npcName, "by player:", player.Name)
					handleSpecialNPC(npcName, config, proximityPrompt)
				end)
				--print("✅ Connected special dialogue for " .. npcName)
			else
				warn("❌ ProximityPrompt not found for special NPC:" .. npcName)
			end
		else
			warn("❌ Special NPC dialogue not found:", npcName)
		end
	end

	--print("🔍 DEBUG: Dialogue setup complete!")
end

-- Handle quest error responses
questEvents.questError.OnClientEvent:Connect(function(errorMessage)
	----print("🔍 DEBUG: Received quest error:", errorMessage)
	writeText(errorMessage, 2)
	endDialogue()
	waitingForQuestResponse = false
end)

-- Initialize the dialogue system
--print("🔍 DEBUG: Initializing dialogue system...")
setupDialogues()