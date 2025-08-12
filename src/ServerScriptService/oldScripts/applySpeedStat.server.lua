--applySpeedStat.lua script

game.Players.PlayerAdded:Connect(function(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		local statsFolder = player:WaitForChild("statsFolder")
		local speedStat = statsFolder:WaitForChild("speedStat")

		humanoid.WalkSpeed = 16 + (speedStat.Value * 1.5)

		speedStat.Changed:Connect(function()
			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = 16 + (speedStat.Value * 1.5)
				--print(player.Name .. "'s speed updated to " .. humanoid.WalkSpeed)
			end
		end)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end)
