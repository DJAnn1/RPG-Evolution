-- StarterGui/ZonesClient.lua (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for events
local zoneEvents = ReplicatedStorage:WaitForChild("zoneEvents")
local teleportEvent = zoneEvents:WaitForChild("teleportEvent")
local combatStatusEvent = zoneEvents:WaitForChild("combatStatusEvent")

-- GUI References (adjust paths as needed)
local zonesGui = playerGui:WaitForChild("zones")
local zoneFrame = zonesGui:WaitForChild("zoneFrame")
local openZonesButton = zonesGui:WaitForChild("openZones")
local levelLowGui = zonesGui:WaitForChild("levelLow")

-- Zone buttons configuration
local ZONE_BUTTONS = {
	["zone1"] = "happyHome",
	["zone2"] = "desert", 
	["zone3"] = "forest"
	-- Add more zone mappings here as you add zones
}

-- Combat status
local inCombat = false
local combatCooldownActive = false

-- Create combat notification GUI
local function createCombatNotification()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatNotification"
	screenGui.Parent = playerGui
	screenGui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "NotificationFrame"
	frame.Size = UDim2.new(0, 300, 0, 80)
	frame.Position = UDim2.new(0.5, -150, 0, -100)
	frame.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "NotificationText"
	textLabel.Size = UDim2.new(1, -20, 1, -20)
	textLabel.Position = UDim2.new(0, 10, 0, 10)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "⚔️ You are in combat! Cannot teleport."
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame

	return screenGui
end

-- Show combat notification
local function showCombatNotification()
	local notification = createCombatNotification()
	local frame = notification.NotificationFrame

	-- Animate in
	local tweenIn = TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -150, 0, 20)}
	)

	tweenIn:Play()

	-- Wait and animate out
	task.wait(2)

	local tweenOut = TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, -150, 0, -100)}
	)

	tweenOut:Play()
	tweenOut.Completed:Wait()
	notification:Destroy()
end

-- Show level requirement notification
local function showLevelNotification(requiredLevel, currentLevel, zoneName)
	-- Update the existing levelLow GUI with dynamic content
	local textLabel = levelLowGui:FindFirstChild("TextLabel")
	if textLabel then
		textLabel.Text = string.format(
			"Level %d required for %s!\nYour level: %d", 
			requiredLevel, zoneName, currentLevel
		)
	end

	levelLowGui.Visible = true
	task.wait(3)
	levelLowGui.Visible = false
end

-- Handle zone button clicks
local function onZoneButtonClick(zoneId)
	if combatCooldownActive then
		task.spawn(showCombatNotification)
		return
	end

	-- Close zones GUI
	zoneFrame.Visible = false

	-- Fire teleport request
	teleportEvent:FireServer(zoneId)
end

-- Setup zone buttons
local function setupZoneButtons()
	for buttonName, zoneId in pairs(ZONE_BUTTONS) do
		local button = zoneFrame:FindFirstChild(buttonName)
		if button then
			button.MouseButton1Click:Connect(function()
				onZoneButtonClick(zoneId)
			end)
		else
			warn("Zone button not found: " .. buttonName)
		end
	end
end

-- Setup open zones button
local function setupOpenZonesButton()
	if openZonesButton then
		openZonesButton.MouseButton1Click:Connect(function()
			zoneFrame.Visible = not zoneFrame.Visible
		end)
	end
end

-- Handle combat status updates
combatStatusEvent.OnClientEvent:Connect(function(combatStatus)
	inCombat = combatStatus
	combatCooldownActive = combatStatus

	if combatStatus then
		-- Player entered combat
		--print("Entered combat - teleportation disabled")
	else
		-- Player left combat
		--print("Left combat - teleportation enabled")
	end
end)

-- Handle server responses
teleportEvent.OnClientEvent:Connect(function(responseType, data)
	if responseType == "levelTooLow" then
		showLevelNotification(data.required, data.current, data.zoneName)
	end
end)

-- Initialize
setupZoneButtons()
setupOpenZonesButton()

-- Optional: Add visual feedback for combat status
local function updateButtonStates()
	for buttonName, _ in pairs(ZONE_BUTTONS) do
		local button = zoneFrame:FindFirstChild(buttonName)
		if button then
			if combatCooldownActive then
				button.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5) -- Gray out
				button.Text = button.Text:gsub("🔴 ", ""):gsub("⚔️ ", "") .. " ⚔️"
			else
				button.BackgroundColor3 = Color3.new(0.2, 0.6, 1) -- Normal color
				button.Text = button.Text:gsub("🔴 ", ""):gsub("⚔️ ", "")
			end
		end
	end
end

-- Update button states when combat status changes
combatStatusEvent.OnClientEvent:Connect(function(combatStatus)
	inCombat = combatStatus
	combatCooldownActive = combatStatus
	updateButtonStates()
end)