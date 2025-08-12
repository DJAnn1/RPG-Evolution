local replicatedStorage = game:GetService("ReplicatedStorage")
local statsEvents = replicatedStorage:WaitForChild("statsEvents")

local speedUp = Instance.new("RemoteEvent")
speedUp.Name = "speedUp"
speedUp.Parent = statsEvents

local function increaseSpeed(player)
	local statsFolder = player:FindFirstChild("statsFolder")

	if not statsFolder then 
		print("no stats folder found!")
		return 
	end

	local statPoints = statsFolder:FindFirstChild("statPoints")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not statPoints or not speedStat then 
		print("no statpoints or speed stat found!")
		return 
	end

	if statPoints.Value >= 1 then
		statPoints.Value -= 1
		speedStat.Value += 1
	end
end


speedUp.OnServerEvent:Connect(increaseSpeed)

