	local PartySystem = require(game.ReplicatedStorage:WaitForChild("PartySystem"))
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local remotes = PartySystem:GetRemoteEvents()

	local partyGui = playerGui:WaitForChild("PartyGui", 10)
	if not partyGui then
		warn("PartyGui not found! Please create the GUI first.")
		return
	end

	local mainFrame = partyGui:WaitForChild("MainFrame")
	local partyFrame = mainFrame:WaitForChild("PartyFrame")
	local inviteFrame = mainFrame:WaitForChild("InviteFrame")
	local notificationFrame = mainFrame:WaitForChild("NotificationFrame")

	local partyMembersList = partyFrame:WaitForChild("MembersList")
	local createPartyButton = partyFrame:WaitForChild("CreatePartyButton")
	local leavePartyButton = partyFrame:WaitForChild("LeavePartyButton")
	local invitePlayerButton = partyFrame:WaitForChild("InvitePlayerButton")

	local invitePlayerTextBox = inviteFrame:WaitForChild("PlayerNameTextBox")
	local sendInviteButton = inviteFrame:WaitForChild("SendInviteButton")
	local cancelInviteButton = inviteFrame:WaitForChild("CancelButton")

	local notificationLabel = notificationFrame:WaitForChild("NotificationLabel")
	local acceptButton = notificationFrame:WaitForChild("AcceptButton")
	local declineButton = notificationFrame:WaitForChild("DeclineButton")
	local closeNotificationButton = notificationFrame:WaitForChild("CloseButton")

	-- State
	local currentParty = nil
	local pendingInvite = nil

	-- UI Animation functions
	local function showFrame(frame)
		frame.Visible = true
		frame.Size = UDim2.new(0, 0, 0, 0)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, 0, 0.5, 0)

		local targetSize = UDim2.new(0, 240, 0, 300)

		if frame == notificationFrame then
			targetSize = UDim2.new(0, 200, 0, 120)
		elseif frame == inviteFrame then
			targetSize = UDim2.new(0, 220, 0, 150)
		end

		local tween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Size = targetSize
		})
		tween:Play()
	end

	local function hideFrame(frame)
		local tween = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, 0, 0, 0)
		})
		tween:Play()

		tween.Completed:Connect(function()
			frame.Visible = false
		end)
	end

	-- Update party member display
-- Update party member display (FOR FRAME, NOT SCROLLINGFRAME)
local function updatePartyDisplay()
	-- Clear existing members
	for _, child in ipairs(partyMembersList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if not currentParty then
		leavePartyButton.Visible = false
		invitePlayerButton.Visible = false
		createPartyButton.Visible = true
		return -- Remove CanvasSize line since it's a Frame
	end

	createPartyButton.Visible = false
	leavePartyButton.Visible = true
	invitePlayerButton.Visible = (currentParty.leader == player)

	-- Create member display 
	for i, member in ipairs(currentParty.members) do
		local memberFrame = Instance.new("Frame")
		memberFrame.Size = UDim2.new(1, -10, 0, 30)
		memberFrame.Position = UDim2.new(0, 5, 0, (i - 1) * 32) -- 30 height + 2 spacing
		memberFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		memberFrame.BorderSizePixel = 0
		memberFrame.Parent = partyMembersList

		local memberLabel = Instance.new("TextLabel")
		memberLabel.Size = UDim2.new(0.65, 0, 1, 0)
		memberLabel.Position = UDim2.new(0, 5, 0, 0)
		memberLabel.BackgroundTransparency = 1
		memberLabel.Text = member.Name .. (member == currentParty.leader and " (Leader)" or "")
		memberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		memberLabel.TextScaled = true
		memberLabel.Font = Enum.Font.Gotham
		memberLabel.TextXAlignment = Enum.TextXAlignment.Left
		memberLabel.Parent = memberFrame

		-- Kick button for leader
		if currentParty.leader == player and member ~= player then
			local kickButton = Instance.new("TextButton")
			kickButton.Size = UDim2.new(0.3, -5, 0.8, 0)
			kickButton.Position = UDim2.new(0.7, 0, 0.1, 0)
			kickButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			kickButton.BorderSizePixel = 0
			kickButton.Text = "Kick"
			kickButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			kickButton.TextScaled = true
			kickButton.Font = Enum.Font.Gotham
			kickButton.ZIndex = 5
			kickButton.Active = true
			kickButton.Parent = memberFrame

			-- Visual feedback
			kickButton.MouseEnter:Connect(function()
				kickButton.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
			end)

			kickButton.MouseLeave:Connect(function()
				kickButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			end)

			kickButton.MouseButton1Click:Connect(function()
				print("Kick button clicked for:", member.Name)
				remotes.KickFromParty:FireServer(member.Name)
			end)
		end
	end
	-- No CanvasSize needed for Frame!
end

	-- Show notification
	local function showNotification(message, hasButtons)
		notificationLabel.Text = message
		acceptButton.Visible = hasButtons or false
		declineButton.Visible = hasButtons or false
		closeNotificationButton.Visible = not hasButtons

		showFrame(notificationFrame)

		if not hasButtons then
			wait(3)
			hideFrame(notificationFrame)
		end
	end

	-- Button connections
	createPartyButton.MouseButton1Click:Connect(function()
		remotes.CreateParty:FireServer()
	end)

	leavePartyButton.MouseButton1Click:Connect(function()
		remotes.LeaveParty:FireServer()
	end)

	invitePlayerButton.MouseButton1Click:Connect(function()
		showFrame(inviteFrame)
	end)

	sendInviteButton.MouseButton1Click:Connect(function()
		local playerName = invitePlayerTextBox.Text
		if playerName and playerName ~= "" then
			remotes.InviteToParty:FireServer(playerName)
			hideFrame(inviteFrame)
			invitePlayerTextBox.Text = ""
		end
	end)

	cancelInviteButton.MouseButton1Click:Connect(function()
		hideFrame(inviteFrame)
		invitePlayerTextBox.Text = ""
	end)

	acceptButton.MouseButton1Click:Connect(function()
		remotes.AcceptInvite:FireServer()
		hideFrame(notificationFrame)
	end)

	declineButton.MouseButton1Click:Connect(function()
		remotes.DeclineInvite:FireServer()
		hideFrame(notificationFrame)
	end)

	closeNotificationButton.MouseButton1Click:Connect(function()
		hideFrame(notificationFrame)
	end)

	-- Toggle party GUI with hotkey (P key)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.P then
			if partyFrame.Visible then
				hideFrame(partyFrame)
			else
				showFrame(partyFrame)
				updatePartyDisplay()
			end
		end
	end)

	-- Handle server responses
	remotes.UpdatePartyUI.OnClientEvent:Connect(function(data, extra)
		if type(data) == "table" and data.members then
			-- Party data update
			currentParty = data
			updatePartyDisplay()
		elseif data == "invite" then
			-- Incoming invite
			pendingInvite = extra
			showNotification(extra.inviterName .. " invited you to their party!", true)
		elseif data == "created" then
			showNotification("Party created!", false)
		elseif data == "joined" then
			showNotification("Joined party!", false)
		elseif data == "left" then
			currentParty = nil
			updatePartyDisplay()
			showNotification("Left party", false)
		elseif data == "kicked" then
			currentParty = nil
			updatePartyDisplay()
			showNotification("You were kicked from the party", false)
		elseif data == "declined" then
			showNotification("Invite declined", false)
		elseif data == "error" then
			showNotification("Error: " .. tostring(extra), false)
		elseif data == "success" then
			showNotification(tostring(extra), false)
		end
	end)

	-- Initialize
	partyFrame.Visible = false
	inviteFrame.Visible = false
	notificationFrame.Visible = false