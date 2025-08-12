local serverStorage = game:GetService("ServerStorage")
local enemyFolder = serverStorage.enemies.area1
local enemyTemplate = enemyFolder:WaitForChild("arab3")
local spawnsFolder = workspace.enemySpawners.arabSpawns.arab3
local replicatedStorage = game:GetService("ReplicatedStorage")
local spawnEvents = replicatedStorage.spawnEvents

local yOffset = 3

local function spawnEnemyAt(spawnPart)
	local enemy = enemyTemplate:Clone()
	enemy.Parent = workspace
	enemy:SetPrimaryPartCFrame(spawnPart.CFrame + Vector3.new(0, yOffset, 0))

	local humanoid = enemy:WaitForChild("Humanoid")

	local function getAllDamagers(humanoid)
		local damagers = {}
		local damagersTable = humanoid:FindFirstChild("DamagersTable")
		if damagersTable then
			for _, playerTag in pairs(damagersTable:GetChildren()) do
				if playerTag:IsA("ObjectValue") and playerTag.Value and playerTag.Value:IsA("Player") then
					table.insert(damagers, playerTag.Value)
				end
			end
		end

		if #damagers == 0 then
			local creatorTag = humanoid:FindFirstChild("creator")
			if creatorTag and creatorTag.Value and creatorTag.Value:IsA("Player") then
				table.insert(damagers, creatorTag.Value)
			end
		end

		return damagers
	end

	humanoid.Died:Connect(function()

		local playersWhoDamaged = getAllDamagers(humanoid)

		if #playersWhoDamaged > 0 then
			spawnEvents.arab3Killed:Fire(playersWhoDamaged)
		else
			print("No players damaged this enemy")
		end

		task.wait(3)
		enemy:Destroy()
		task.wait(8)
		spawnEnemyAt(spawnPart)
	end)
end

local function startEnemySpawns()
	for _, spawnpart in pairs(spawnsFolder:GetChildren()) do
		if spawnpart:IsA("BasePart") then
			spawnEnemyAt(spawnpart)
		end
	end
end

startEnemySpawns()