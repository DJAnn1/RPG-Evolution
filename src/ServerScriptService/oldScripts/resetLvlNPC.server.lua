replicatedStorage = game:GetService("ReplicatedStorage")
local resetLvlNPCEvent = replicatedStorage.resetLevelNPC

local function resetLevel(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats:FindFirstChild("Level")
	local exp = leaderstats:FindFirstChild("EXP")
	local statsFolder = player:FindFirstChild("statsFolder")
	local statPoints = statsFolder:FindFirstChild("statPoints")
	local maxHealthStat = player:FindFirstChild("maxHealthStat")
	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")
	if level then
		level.Value = 0
		exp.Value = 0
		statPoints.Value = 0
		maxHealthStat.Value = 100
		damageStat.Value = 0
		defenseStat.Value = 0
		speedStat.Value = 0
	end
end

resetLvlNPCEvent.OnServerEvent:Connect(resetLevel)