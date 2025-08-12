-- LevelSystem.lua - Optimized level system with centralized rewards (Place in ReplicatedStorage)
local LevelSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local HEALTH_PER_LEVEL = 15
local STAT_POINTS_PER_LEVEL = 1

-- CENTRALIZED REWARD CONFIGURATION
local REWARDS = {
	-- Enemy kill rewards (EXP and Gold)
	enemyKills = {
		EnemyKilled = {exp = 15, gold = 2},      
		telamonKilled = {exp = 400, gold = 50},
		arab1Killed = {exp = 45, gold = 10},
		arab2Killed = {exp = 35, gold = 6},
		arab3Killed = {exp = 25, gold = 4},
		fishmanKilled = {exp = 20, gold = 4},  
		linkKilled = {exp = 550, gold = 12},     
		arabkingKilled = {exp = 1200, gold = 120},
		zombieKilled = {exp = 350, gold = 15},
		zombieBossKilled = {exp = 1800, gold = 180}, -- FIXED: Added exp = 
		ghostKilled = {exp = 500, gold = 25},
		ghostBossKilled = {exp = 2500, gold = 250}
	},
	-- Quest completion rewards
	questCompletions = {
		quest1 = {exp = 100, gold = 15},
		fishQuest1 = {exp = 400, gold = 25},
		bossQuest1 = {exp = 5000, gold = 200},    
		arabQuest1 = {exp = 2500, gold = 75},
		arabQuest2 = {exp = 2000, gold = 50},
		arabQuest3 = {exp = 1500, gold = 30},
		arabkingQuest1 = {exp = 8000, gold = 350},
		linkQuest1 = {exp = 7500, gold = 150},
		zombieQuest1 = {exp = 5500, gold = 200},
		zombieBossQuest1 = {exp = 10000, gold = 600},
		ghostQuest1 = {exp = 6000, gold = 300},
		ghostBossQuest1 = {exp = 15000, gold = 1000}
	}
}

-- Basic EXP curve: 100 + (Level - 1) * 50
function LevelSystem.GetExpToLevel(level)
	return 100 + (level - 1) * 50
end

-- Calculate max health based on level
function LevelSystem.GetMaxHealthForLevel(level)
	return 100 + ((level - 1) * HEALTH_PER_LEVEL)
end

-- Helper function to get player stats safely
local function getPlayerStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return nil end

	return {
		exp = leaderstats:FindFirstChild("EXP"),
		level = leaderstats:FindFirstChild("Level"),
		gold = leaderstats:FindFirstChild("Gold")
	}
end

-- Centralized reward awarding function
local function awardRewards(player, expAmount, goldAmount)
	local stats = getPlayerStats(player)
	if not stats or not stats.exp or not stats.level then return false end

	-- Ensure expAmount and goldAmount are valid numbers
	expAmount = expAmount or 0
	goldAmount = goldAmount or 0

	-- Award EXP and handle level ups
	local leveledUp = false
	stats.exp.Value = stats.exp.Value + expAmount

	-- Handle level ups
	local required = LevelSystem.GetExpToLevel(stats.level.Value)
	while stats.exp.Value >= required do
		stats.exp.Value = stats.exp.Value - required
		stats.level.Value = stats.level.Value + 1
		leveledUp = true

		-- Update max health
		local maxHealthStat = player:FindFirstChild("maxHealthStat")
		if maxHealthStat then
			maxHealthStat.Value = maxHealthStat.Value + HEALTH_PER_LEVEL
		end

		-- Give stat points
		local statsFolder = player:FindFirstChild("statsFolder")
		if statsFolder then
			local statPoints = statsFolder:FindFirstChild("statPoints")
			if statPoints then
				statPoints.Value = statPoints.Value + STAT_POINTS_PER_LEVEL
			end
		end

		-- Update character health immediately
		LevelSystem.UpdateCharacterHealth(player)

		-- Calculate next level requirement
		required = LevelSystem.GetExpToLevel(stats.level.Value)
	end

	-- Award Gold
	if stats.gold and goldAmount > 0 then
		stats.gold.Value = stats.gold.Value + goldAmount
	end

	return leveledUp
end

-- Award rewards for enemy kills
function LevelSystem.AwardEnemyKillRewards(players, killType)
	local rewardData = REWARDS.enemyKills[killType]
	if not rewardData then 
		warn("Unknown kill type: " .. tostring(killType))
		return
	end

	for _, player in ipairs(players) do
		if player and player:IsA("Player") then
			awardRewards(player, rewardData.exp, rewardData.gold)
		end
	end
end

-- Award rewards for quest completion
function LevelSystem.AwardQuestRewards(player, questName)
	local rewardData = REWARDS.questCompletions[questName]
	if not rewardData then 
		warn("Unknown quest: " .. tostring(questName))
		return false
	end

	return awardRewards(player, rewardData.exp, rewardData.gold)
end

-- Update character health based on maxHealthStat
function LevelSystem.UpdateCharacterHealth(player)
	local character = player.Character
	local maxHealthStat = player:FindFirstChild("maxHealthStat")

	if not character or not maxHealthStat then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.MaxHealth = maxHealthStat.Value
		humanoid.Health = maxHealthStat.Value -- Full heal on level up
	end
end

-- Set up health management for a player
function LevelSystem.SetupPlayerHealth(player)
	local previousLevel = 0

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		local maxHealthStat = player:WaitForChild("maxHealthStat")

		-- Set initial health based on stat
		humanoid.MaxHealth = maxHealthStat.Value
		humanoid.Health = maxHealthStat.Value

		-- Watch for changes to maxHealthStat
		local healthConnection = maxHealthStat:GetPropertyChangedSignal("Value"):Connect(function()
			if humanoid and humanoid.Parent then
				humanoid.MaxHealth = maxHealthStat.Value
			end
		end)

		-- Clean up connection when character is removed
		character.AncestryChanged:Connect(function()
			if not character.Parent then
				healthConnection:Disconnect()
			end
		end)
	end

	-- Handle existing character
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Handle future characters
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Store initial level for level-up detection
	local leaderstats = player:WaitForChild("leaderstats")
	local level = leaderstats:WaitForChild("Level")
	previousLevel = level.Value

	-- Monitor for level changes to trigger full heal
	level:GetPropertyChangedSignal("Value"):Connect(function()
		if level.Value > previousLevel then
			LevelSystem.UpdateCharacterHealth(player)
			previousLevel = level.Value
		end
	end)
end

-- Get player's level progress info
function LevelSystem.GetLevelProgress(player)
	local stats = getPlayerStats(player)
	if not stats or not stats.exp or not stats.level then return nil end

	local required = LevelSystem.GetExpToLevel(stats.level.Value)
	local progress = stats.exp.Value / required

	return {
		currentLevel = stats.level.Value,
		currentExp = stats.exp.Value,
		expToNext = required,
		expRemaining = required - stats.exp.Value,
		progressPercent = progress * 100
	}
end

-- Initialize centralized reward system
function LevelSystem.InitializeRewardSystem()
	local spawnEvents = ReplicatedStorage:WaitForChild("spawnEvents")

	-- Connect to enemy kill events
	for killType, _ in pairs(REWARDS.enemyKills) do
		local killEvent = spawnEvents:WaitForChild(killType)
		if killEvent then
			killEvent.Event:Connect(function(players)
				LevelSystem.AwardEnemyKillRewards(players, killType)
			end)
		end
	end
end

-- Get reward data (for other systems to check rewards)
function LevelSystem.GetEnemyKillReward(killType)
	return REWARDS.enemyKills[killType]
end

function LevelSystem.GetQuestReward(questName)
	return REWARDS.questCompletions[questName]
end

-- DEPRECATED FUNCTIONS (kept for backward compatibility)
function LevelSystem.AwardExp(player, expGain)
	warn("AwardExp is deprecated. Use reward functions instead.")
	return awardRewards(player, expGain, 0)
end

function LevelSystem.AwardExpToPlayers(players, expGain, killType)
	warn("AwardExpToPlayers is deprecated. Use AwardEnemyKillRewards instead.")
	for _, player in ipairs(players) do
		if player and player:IsA("Player") then
			awardRewards(player, expGain, 0)
		end
	end
end

return LevelSystem