--removeLevel.lua

local re = game:GetService("ReplicatedStorage")
local resetLvl = re.REtestStuff.resetLvl

local function resetLevel(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats:FindFirstChild("Level")
	local exp = leaderstats:FindFirstChild("EXP")
	local healthMax = player:FindFirstChild("maxHealthStat")
	local gold = leaderstats:FindFirstChild("Gold")
	
	local statsFolder = player:WaitForChild("statsFolder")
	local statPoints = statsFolder:WaitForChild("statPoints")
	local damageStat = statsFolder:WaitForChild("damageStat")
	local defenseStat = statsFolder:WaitForChild("defenseStat")
	local speedStat = statsFolder:WaitForChild("speedStat")
	
	healthMax.Value = 100
	level.Value = 0
	exp.Value = 0
	statPoints.Value = 0
	damageStat.Value = 0
	defenseStat.Value = 0
	speedStat.Value = 0
	gold.Value = 0
end

resetLvl.OnServerEvent:Connect(resetLevel)