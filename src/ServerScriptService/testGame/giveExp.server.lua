local re = game:GetService("ReplicatedStorage")
local giveExpEvent = Instance.new("RemoteEvent")
giveExpEvent.Parent = re.REtestStuff
giveExpEvent.Name = "giveExpEvent"

local function giveExp(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local exp = leaderstats:FindFirstChild("EXP")
	exp.Value += 10000
end

giveExpEvent.OnServerEvent:Connect(giveExp)