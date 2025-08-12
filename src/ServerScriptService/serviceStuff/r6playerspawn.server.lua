players = game:GetService("Players")
players.PlayerAdded:connect(function(player)
	player.CharacterAdded:connect(function(character)
		character.Humanoid.RigType = Enum.HumanoidRigType.R6
	end)
end)