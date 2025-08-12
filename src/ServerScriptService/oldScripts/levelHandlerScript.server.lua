-- LevelHandler.lua - Simplified level management (Place in ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local LevelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local ShopManager = require(ServerScriptService:WaitForChild("ShopManager"))

-- Wait for spawn events
local spawnEvents = ReplicatedStorage:WaitForChild("spawnEvents")

-- EXP and Gold rewards configuration
local REWARDS = {
	EnemyKilled = {exp = 15, gold = "EnemyKilled"},
	linkKilled = {exp = 70, gold = "linkKilled"},
	telamonKilled = {exp = 350, gold = "telamonKilled"},
	arab1Killed = {exp = 45, gold = "arab1Killed"},
	arab2Killed = {exp = 35, gold = "arab1Killed"},
	arab3Killed = {exp = 25, gold = "arab1Killed"},
	fishmanKilled = {exp = 25, gold = "fishmanKilled"},
	zombieKilled = {exp = 50, gold = "fishmanKilled"},
	arabKingKilled = {exp = 2000, gold = "arab1Killed"}
}

-- Helper function to award both EXP and Gold
local function awardExpAndGold(players, rewardKey)
	local reward = REWARDS[rewardKey]
	if not reward then return end

	for _, player in ipairs(players) do
		if player and player:IsA("Player") then
			-- Award EXP (handles level ups automatically)
			LevelSystem.AwardExp(player, reward.exp)

			-- Award Gold (using ShopManager's existing system)
			ShopManager:AwardKillGold({player}, reward.gold)
		end
	end
end

-- Set up health management for new players
Players.PlayerAdded:Connect(function(player)
	LevelSystem.SetupPlayerHealth(player)
end)

-- Connect all enemy kill events
spawnEvents.EnemyKilled.Event:Connect(function(players)
	awardExpAndGold(players, "EnemyKilled")
end)

spawnEvents.linkKilled.Event:Connect(function(players)
	awardExpAndGold(players, "linkKilled")
end)

spawnEvents.telamonKilled.Event:Connect(function(players)
	awardExpAndGold(players, "telamonKilled")
end)

spawnEvents.arab1Killed.Event:Connect(function(players)
	awardExpAndGold(players, "arab1Killed")
end)

spawnEvents.arab2Killed.Event:Connect(function(players)
	awardExpAndGold(players, "arab2Killed")
end)

spawnEvents.arab3Killed.Event:Connect(function(players)
	awardExpAndGold(players, "arab3Killed")
end)

spawnEvents.fishmanKilled.Event:Connect(function(players)
	awardExpAndGold(players, "fishmanKilled")
end)

spawnEvents.zombieKilled.Event:Connect(function(players)
	awardExpAndGold(players, "zombieKilled")
end)

spawnEvents.arabKingKilled.Event:Connect(function(players)
	awardExpAndGold(players, "arabKingKilled")
end)

--print("LevelHandler loaded successfully!")
--print("EXP, leveling, and health management are now handled automatically.")