local re = game:GetService("ReplicatedStorage")
local giveStatsEvent = Instance.new("RemoteEvent")
giveStatsEvent.Parent = re.REtestStuff
giveStatsEvent.Name = "giveStatsEvent"

local function giveStats(player)
	local statsFolder = player:FindFirstChild("statsFolder")
	local statPoints = statsFolder:FindFirstChild("statPoints")
	statPoints.Value += 10
end

giveStatsEvent.OnServerEvent:Connect(giveStats)