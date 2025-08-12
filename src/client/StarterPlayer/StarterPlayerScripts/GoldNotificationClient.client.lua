-- GoldNotificationClient.lua - Enhanced gold notification system (LocalScript in StarterPlayerScripts)
local plr = game.Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

-- Wait for shop events
local shopEvents = replicatedStorage:WaitForChild("shopEvents")
local goldNotification = shopEvents:WaitForChild("goldNotification")

-- Create the notification GUI
local function createNotificationGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GoldNotificationGUI"
	screenGui.Parent = playerGui
	screenGui.ResetOnSpawn = false

	-- Container for notifications
	local notificationContainer = Instance.new("Frame")
	notificationContainer.Name = "NotificationContainer"
	notificationContainer.Size = UDim2.new(0, 300, 1, 0)
	notificationContainer.Position = UDim2.new(1, -320, 0, 20) -- Top right corner
	notificationContainer.BackgroundTransparency = 1
	notificationContainer.Parent = screenGui

	return notificationContainer
end

-- Create individual notification frame
local function createNotificationFrame(amount, reason)
	local notificationContainer = playerGui:FindFirstChild("GoldNotificationGUI")
	if not notificationContainer then
		notificationContainer = createNotificationGUI()
	else
		notificationContainer = notificationContainer:FindFirstChild("NotificationContainer")
	end

	-- Create notification frame
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(1, 0, 0, 60)
	notification.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
	notification.BorderSizePixel = 2
	notification.BorderColor3 = Color3.fromRGB(218, 165, 32) -- Darker gold
	notification.Parent = notificationContainer

	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	-- Gold icon (you can replace with actual image)
	local goldIcon = Instance.new("TextLabel")
	goldIcon.Size = UDim2.new(0, 40, 1, 0)
	goldIcon.Position = UDim2.new(0, 5, 0, 0)
	goldIcon.BackgroundTransparency = 1
	goldIcon.Text = "💰" -- Gold emoji, replace with image if preferred
	goldIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	goldIcon.TextScaled = true
	goldIcon.Font = Enum.Font.SourceSansBold
	goldIcon.Parent = notification

	-- Amount text
	local amountLabel = Instance.new("TextLabel")
	amountLabel.Size = UDim2.new(0, 80, 0.6, 0)
	amountLabel.Position = UDim2.new(0, 50, 0, 5)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = "+" .. amount
	amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	amountLabel.TextScaled = true
	amountLabel.Font = Enum.Font.SourceSansBold
	amountLabel.Parent = notification

	-- Reason text
	local reasonLabel = Instance.new("TextLabel")
	reasonLabel.Size = UDim2.new(0, 150, 0.4, 0)
	reasonLabel.Position = UDim2.new(0, 50, 0.6, -5)
	reasonLabel.BackgroundTransparency = 1
	reasonLabel.Text = reason
	reasonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	reasonLabel.TextScaled = true
	reasonLabel.Font = Enum.Font.SourceSans
	reasonLabel.Parent = notification

	-- Position notification based on existing ones
	local existingNotifications = 0
	for _, child in pairs(notificationContainer:GetChildren()) do
		if child:IsA("Frame") and child ~= notification then
			existingNotifications = existingNotifications + 1
		end
	end

	notification.Position = UDim2.new(0, 0, 0, existingNotifications * 70)

	-- Animate in
	notification.Size = UDim2.new(0, 0, 0, 60)
	local tweenIn = tweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Size = UDim2.new(1, 0, 0, 60)
	})
	tweenIn:Play()

	-- Auto-remove after 3 seconds
	task.spawn(function()
		task.wait(3)

		-- Animate out
		local tweenOut = tweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, 0, 0, 60),
			Position = UDim2.new(1, 0, notification.Position.Y.Scale, notification.Position.Y.Offset)
		})

		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			notification:Destroy()

			-- Reposition remaining notifications
			local yOffset = 0
			for _, child in pairs(notificationContainer:GetChildren()) do
				if child:IsA("Frame") then
					local repositionTween = tweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
						Position = UDim2.new(0, 0, 0, yOffset)
					})
					repositionTween:Play()
					yOffset = yOffset + 70
				end
			end
		end)
	end)
end

-- Handle gold notifications
goldNotification.OnClientEvent:Connect(function(amount, reason)
	createNotificationFrame(amount, reason)
end)