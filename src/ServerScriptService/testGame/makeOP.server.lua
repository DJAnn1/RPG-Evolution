local re = game:GetService("ReplicatedStorage")
local makeOPEvent = Instance.new("RemoteEvent")
makeOPEvent.Parent = re.REtestStuff
makeOPEvent.Name = "makeOPEvent"

local function makeOP(player)
	local statsFolder = player:FindFirstChild("statsFolder")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local damageStat = statsFolder:FindFirstChild("damageStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")
	
	defenseStat.Value += 100
	damageStat.Value += 100
	speedStat.Value += 10
end

makeOPEvent.OnServerEvent:Connect(makeOP)