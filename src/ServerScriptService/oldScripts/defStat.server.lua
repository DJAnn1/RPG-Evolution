--defStat.lua script

local replicatedStorage = game:GetService("ReplicatedStorage")
local statsEvents = replicatedStorage:WaitForChild("statsEvents")

local defenseUp = Instance.new("RemoteEvent")
defenseUp.Name = "defenseUp"
defenseUp.Parent = statsEvents

local function increaseDef(player)
	local statsFolder = player:FindFirstChild("statsFolder")

	if not statsFolder then 
		print("no stats folder found!")
		return 
	end

	local statPoints = statsFolder:FindFirstChild("statPoints")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")

	if not statPoints or not defenseStat then 
		print("no statpoints or defense stat found!")
		return 
	end

	if statPoints.Value >= 1 then
		statPoints.Value -= 1
		defenseStat.Value += 1
	end
end


defenseUp.OnServerEvent:Connect(increaseDef)

