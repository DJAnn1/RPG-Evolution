local players = game:GetService("Players")

players.PlayerAdded:Connect(function(player)
	local gui = player.PlayerGui
	local guideMessage = gui:WaitForChild("guideMessage")
	guideMessage.Enabled = false
	task.wait(3)
	guideMessage.Enabled = true
end)