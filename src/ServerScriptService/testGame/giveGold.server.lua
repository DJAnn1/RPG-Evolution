local re = game:GetService("ReplicatedStorage")
local giveGoldEvent = Instance.new("RemoteEvent")
giveGoldEvent.Parent = re.REtestStuff
giveGoldEvent.Name = "giveGoldEvent"

local function giveGold(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats:FindFirstChild("Gold")
	gold.Value += 100
end

giveGoldEvent.OnServerEvent:Connect(giveGold)