--dmgStat.lua script


local replicatedStorage = game:GetService("ReplicatedStorage")
local statsEvents = replicatedStorage:WaitForChild("statsEvents")

local damageUp = Instance.new("RemoteEvent")
damageUp.Name = "damageUp"
damageUp.Parent = statsEvents

local function increaseDmg(player)
	local statsFolder = player:FindFirstChild("statsFolder")

	if not statsFolder then 
		print("no stats folder found!")
		return 
	end

	local statPoints = statsFolder:FindFirstChild("statPoints")
	local damageStat = statsFolder:FindFirstChild("damageStat")

	if not statPoints or not damageStat then 
		print("no statpoints or damage stat found!")
		return 
	end
	
	if statPoints.Value >= 1 then
		statPoints.Value -= 1
		damageStat.Value += 1
	end
end


damageUp.OnServerEvent:Connect(increaseDmg)

