local serverStorage = game:GetService("ServerStorage")
local enemyTemplate = serverStorage.enemies.area1.Telamon
local spawnpoint = workspace.enemySpawners.telamonThrone.telemonSpawner
local replicatedStorage = game:GetService("ReplicatedStorage")
local spawnEvents = replicatedStorage:WaitForChild("spawnEvents")

local yOffset = 3

local function spawnEnemyAt(spawnpoint)
	local enemy = enemyTemplate:Clone()
	enemy.Parent = workspace
	enemy:SetPrimaryPartCFrame(spawnpoint.CFrame + Vector3.new(0, yOffset, 0))

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
			spawnEvents.telamonKilled:Fire(playersWhoDamaged) 
		else
			print("No players damaged this enemy")
		end

		task.wait(3)
		enemy:Destroy()
		task.wait(10)
		spawnEnemyAt(spawnpoint)
	end)
end

spawnEnemyAt(spawnpoint)