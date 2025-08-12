-- QuestCancelGUI.lua - Client script to handle quest cancellation button
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local replicatedStorage = game:GetService("ReplicatedStorage")
local questEvents = replicatedStorage:WaitForChild("questEvents")

-- Create the cancel quest GUI
local function createCancelQuestGUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestCancelGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	screenGui.ResetOnSpawn = true

	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 200, 0, 100)
	mainFrame.Position = UDim2.new(0, 10, 0, 200) -- Position it below other GUI elements
	mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	mainFrame.Visible = false -- Start hidden
	mainFrame.Parent = screenGui

	-- Create title label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	titleLabel.BorderSizePixel = 0
	titleLabel.Text = "Active Quest"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = mainFrame

	-- Create quest name label
	local questNameLabel = Instance.new("TextLabel")
	questNameLabel.Name = "QuestNameLabel"
	questNameLabel.Size = UDim2.new(1, -10, 0, 25)
	questNameLabel.Position = UDim2.new(0, 5, 0, 35)
	questNameLabel.BackgroundTransparency = 1
	questNameLabel.Text = "No Active Quest"
	questNameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	questNameLabel.TextScaled = true
	questNameLabel.Font = Enum.Font.SourceSans
	questNameLabel.Parent = mainFrame

	-- Create cancel button
	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "CancelButton"
	cancelButton.Size = UDim2.new(0, 80, 0, 25)
	cancelButton.Position = UDim2.new(0.5, -40, 0, 65)
	cancelButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	cancelButton.BorderSizePixel = 1
	cancelButton.BorderColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.Text = "Cancel"
	cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelButton.TextScaled = true
	cancelButton.Font = Enum.Font.SourceSansBold
	cancelButton.Parent = mainFrame

	-- Add hover effect to cancel button
	cancelButton.MouseEnter:Connect(function()
		cancelButton.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	end)

	cancelButton.MouseLeave:Connect(function()
		cancelButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end)

	return screenGui, mainFrame, questNameLabel, cancelButton
end

-- Function to check if player has any active quest
local function getActiveQuest()
	local questsFolder = player:FindFirstChild("Quests")
	if not questsFolder then return nil end

	for questName, questConfig in pairs(QuestConfig.quests) do
		local started = questsFolder:FindFirstChild(questName .. "Started")
		local completed = questsFolder:FindFirstChild(questName .. "Complete")

		if started and started.Value and not completed then
			return questName, questConfig.displayName
		end
	end
	return nil
end

-- Function to update the GUI visibility and content
local function updateCancelGUI(mainFrame, questNameLabel)
	local activeQuestName, displayName = getActiveQuest()

	if activeQuestName then
		mainFrame.Visible = true
		questNameLabel.Text = displayName or activeQuestName
	else
		mainFrame.Visible = false
		questNameLabel.Text = "No Active Quest"
	end
end

-- Main setup function
local function setupCancelGUI()
	-- Wait for quests folder to be created
	local questsFolder = player:WaitForChild("Quests")

	-- Create the GUI
	local screenGui, mainFrame, questNameLabel, cancelButton = createCancelQuestGUI()

	-- Connect cancel button
	cancelButton.Activated:Connect(function()
		local activeQuest = getActiveQuest()
		if activeQuest then
			-- Fire the cancel quest event to the server
			questEvents.cancelQuest:FireServer()
		end
	end)

	-- Update GUI when quest status changes
	local function onQuestChange()
		updateCancelGUI(mainFrame, questNameLabel)
	end

	-- Listen for changes in the quests folder
	questsFolder.ChildAdded:Connect(onQuestChange)
	questsFolder.ChildRemoved:Connect(onQuestChange)

	-- Listen for value changes in quest values
	for _, child in pairs(questsFolder:GetChildren()) do
		if child:IsA("BoolValue") then
			child.Changed:Connect(onQuestChange)
		end
	end

	-- Handle new quest values being added
	questsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BoolValue") then
			child.Changed:Connect(onQuestChange)
		end
	end)

	-- Initial update
	updateCancelGUI(mainFrame, questNameLabel)

	-- Update periodically as a backup
	task.spawn(function()
		while true do
			task.wait(1)
			updateCancelGUI(mainFrame, questNameLabel)
		end
	end)

	--print("Quest Cancel GUI initialized")
end

-- Initialize the cancel GUI
setupCancelGUI()