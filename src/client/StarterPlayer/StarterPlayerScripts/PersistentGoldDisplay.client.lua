-- PersistentGoldDisplay.lua - Always visible gold counter (LocalScript in StarterPlayerScripts)
local plr = game.Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local tweenService = game:GetService("TweenService")

local goldDisplay = nil
local goldLabel = nil
local currentGold = 0

-- Create the persistent gold display
local function createGoldDisplay()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PersistentGoldGUI"
	screenGui.Parent = playerGui
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10 -- Make sure it's on top

	-- Main container frame
	local container = Instance.new("Frame")
	container.Name = "GoldContainer"
	container.Size = UDim2.new(0, 200, 0, 60)
	container.Position = UDim2.new(0, 20, 0, 20) -- Top left corner
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0.3
	container.BorderSizePixel = 2
	container.BorderColor3 = Color3.fromRGB(255, 215, 0)
	container.Parent = screenGui

	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = container

	-- Gold icon
	local goldIcon = Instance.new("ImageLabel")
	goldIcon.Size = UDim2.new(0, 40, 0, 40)
	goldIcon.Position = UDim2.new(0, 10, 0.5, -20)
	goldIcon.BackgroundTransparency = 1
	goldIcon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png" -- Replace with gold coin image
	goldIcon.ScaleType = Enum.ScaleType.Fit
	goldIcon.Parent = container

	-- If you don't have a gold icon, use text instead
	local goldIconText = Instance.new("TextLabel")
	goldIconText.Size = UDim2.new(0, 40, 0, 40)
	goldIconText.Position = UDim2.new(0, 10, 0.5, -20)
	goldIconText.BackgroundTransparency = 1
	goldIconText.Text = "💰"
	goldIconText.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldIconText.TextScaled = true
	goldIconText.Font = Enum.Font.SourceSansBold
	goldIconText.Parent = container

	-- Gold amount label
	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "GoldLabel"
	amountLabel.Size = UDim2.new(1, -60, 1, 0)
	amountLabel.Position = UDim2.new(0, 55, 0, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = "0"
	amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	amountLabel.TextScaled = true
	amountLabel.Font = Enum.Font.SourceSansBold
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel.Parent = container

	-- Add a subtle glow effect
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(255, 215, 0)
	glow.Thickness = 1
	glow.Transparency = 0.5
	glow.Parent = container

	goldDisplay = container
	goldLabel = amountLabel

	return container
end

-- Update gold display with animation
local function updateGoldDisplay(newAmount)
	if not goldLabel then return end

	local oldAmount = currentGold
	currentGold = newAmount

	-- Create a counting animation
	local startTime = tick()
	local duration = 0.5 -- Half second animation
	local difference = newAmount - oldAmount

	-- Color flash for positive/negative changes
	if difference > 0 then
		-- Flash green for gains
		local flashTween = tweenService:Create(goldLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			TextColor3 = Color3.fromRGB(0, 255, 0)
		})
		flashTween:Play()
		flashTween.Completed:Connect(function()
			local returnTween = tweenService:Create(goldLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				TextColor3 = Color3.fromRGB(255, 255, 255)
			})
			returnTween:Play()
		end)
	elseif difference < 0 then
		-- Flash red for losses
		local flashTween = tweenService:Create(goldLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			TextColor3 = Color3.fromRGB(255, 0, 0)
		})
		flashTween:Play()
		flashTween.Completed:Connect(function()
			local returnTween = tweenService:Create(goldLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				TextColor3 = Color3.fromRGB(255, 255, 255)
			})
			returnTween:Play()
		end)
	end

	-- Animate the counting
	task.spawn(function()
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			local currentDisplayAmount = math.floor(oldAmount + (difference * progress))
			goldLabel.Text = tostring(currentDisplayAmount)
			task.wait()
		end
		goldLabel.Text = tostring(newAmount)
	end)

	-- Scale animation for emphasis
	local scaleUp = tweenService:Create(goldDisplay, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
		Size = UDim2.new(0, 210, 0, 65)
	})
	scaleUp:Play()
	scaleUp.Completed:Connect(function()
		local scaleDown = tweenService:Create(goldDisplay, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, 200, 0, 60)
		})
		scaleDown:Play()
	end)
end

-- Monitor player's gold value
local function monitorGold()
	local function checkGold()
		local leaderstats = plr:FindFirstChild("leaderstats")
		if leaderstats then
			local gold = leaderstats:FindFirstChild("Gold")
			if gold and gold.Value ~= currentGold then
				updateGoldDisplay(gold.Value)
			end
		end
	end

	-- Check initially
	checkGold()

	-- Set up monitoring
	if plr:FindFirstChild("leaderstats") then
		local leaderstats = plr.leaderstats
		if leaderstats:FindFirstChild("Gold") then
			leaderstats.Gold.Changed:Connect(function(newValue)
				updateGoldDisplay(newValue)
			end)
		end
	end

	-- Backup polling in case leaderstats isn't ready yet
	task.spawn(function()
		while true do
			task.wait(1)
			checkGold()
		end
	end)
end

-- Handle player respawning
local function onCharacterAdded(character)
	-- Wait a moment for stats to load
	task.wait(2)
	monitorGold()
end

-- Initialize
local function initialize()
	createGoldDisplay()

	if plr.Character then
		onCharacterAdded(plr.Character)
	end

	plr.CharacterAdded:Connect(onCharacterAdded)

	-- Start monitoring immediately
	monitorGold()
end

-- Start the system
initialize()