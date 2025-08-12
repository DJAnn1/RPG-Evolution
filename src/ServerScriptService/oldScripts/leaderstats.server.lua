-- leaderstatsScript.lua
game.Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = stats

	local exp = Instance.new("IntValue")
	exp.Name = "EXP"
	exp.Value = 0
	exp.Parent = stats

	-- NEW: Add Gold to leaderstats
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = 0 -- Starting gold
	gold.Parent = stats

	local maxHealthStat = Instance.new("IntValue")
	maxHealthStat.Name = "maxHealthStat"
	maxHealthStat.Value = 100
	maxHealthStat.Parent = player

	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "statsFolder"
	statsFolder.Parent = player

	local statPoints = Instance.new("IntValue")
	statPoints.Name = "statPoints"
	statPoints.Value = 0
	statPoints.Parent = statsFolder

	local damageStat = Instance.new("IntValue")
	damageStat.Name = "damageStat"
	damageStat.Value = 1
	damageStat.Parent = statsFolder

	local defenseStat = Instance.new("IntValue")
	defenseStat.Name = "defenseStat"
	defenseStat.Value = 1
	defenseStat.Parent = statsFolder

	local speedStat = Instance.new("IntValue")
	speedStat.Name = "speedStat"
	speedStat.Value = 1
	speedStat.Parent = statsFolder
end)