local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerWeapons = ReplicatedStorage.playerWeapons

local toolsToGive = {
	{ Tool = playerWeapons:WaitForChild("Sword"), RequiredLevel = 0 },
	{ Tool = playerWeapons:WaitForChild("slingshot"), RequiredLevel = 5},
	{ Tool = playerWeapons:WaitForChild("PERISHYOUFOOL"), RequiredLevel = 50 }
}

local givenTools = {}

local function giveTools(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	if not level then return end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	for _, entry in ipairs(toolsToGive) do
		local toolName = entry.Tool.Name
		local requiredLevel = entry.RequiredLevel

		local toolExistsInBackpack = backpack:FindFirstChild(toolName)
		local toolExistsInCharacter = player.Character and player.Character:FindFirstChild(toolName)

		if level.Value >= requiredLevel and not (toolExistsInBackpack or toolExistsInCharacter) then
			local clone = entry.Tool:Clone()
			clone.Parent = backpack
			--print("Gave", toolName, "to", player.Name)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	givenTools[player] = {}

	player.CharacterAdded:Connect(function()
		repeat task.wait() until player:FindFirstChild("Backpack")
		task.wait(0.25) 
		giveTools(player)
	end)

	player:WaitForChild("leaderstats"):WaitForChild("Level")

	player.leaderstats.Level.Changed:Connect(function()
		giveTools(player)
	end)

	task.spawn(function()
		repeat task.wait() until player:FindFirstChild("Backpack")
		task.wait(0.25)
		giveTools(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	givenTools[player] = nil
end)
