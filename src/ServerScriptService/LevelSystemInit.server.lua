-- LevelSystemInit.lua - Initialize centralized reward system (Place in ServerScriptService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for LevelSystem to load
local LevelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))

-- Initialize the centralized reward system
LevelSystem.InitializeRewardSystem()

-- Set up health management for players
Players.PlayerAdded:Connect(function(player)
	LevelSystem.SetupPlayerHealth(player)
end)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	LevelSystem.SetupPlayerHealth(player)
end

--print("✅ LevelSystem: Centralized reward system active!")
--print("✅ All enemy kills and quest completions will award EXP + Gold through LevelSystem")
--print("✅ No duplicate reward systems running")