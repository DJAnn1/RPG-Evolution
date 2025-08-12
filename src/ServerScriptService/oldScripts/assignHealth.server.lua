-- assignHealth.lua

local Players = game:GetService("Players")
local previousLevels = {}

local function updateHealth(player)
	local character = player.Character
	local maxHealthStat = player:FindFirstChild("maxHealthStat")
	local leaderstats = player:FindFirstChild("leaderstats")

	if not (character and maxHealthStat and leaderstats) then return end

	local level = leaderstats:FindFirstChild("Level")
	local humanoid = character:FindFirstChild("Humanoid")

	if not (humanoid and level) then return end

	-- Always make sure MaxHealth matches the stat
	if humanoid.MaxHealth ~= maxHealthStat.Value then
		humanoid.MaxHealth = maxHealthStat.Value
	end

	-- If level increased, reset health
	local previousLevel = previousLevels[player] or 0
	if level.Value > previousLevel then
		humanoid.MaxHealth = maxHealthStat.Value
		humanoid.Health = maxHealthStat.Value
	end

	-- Store the latest level
	previousLevels[player] = level.Value
end

Players.PlayerAdded:Connect(function(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		local maxHealthStat = player:WaitForChild("maxHealthStat")

		-- Set initial health based on stat
		humanoid.MaxHealth = maxHealthStat.Value
		humanoid.Health = maxHealthStat.Value

		-- Optional: watch for direct changes to maxHealthStat
		maxHealthStat:GetPropertyChangedSignal("Value"):Connect(function()
			humanoid.MaxHealth = maxHealthStat.Value
		end)
	end

	-- Handle existing character
	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	local leaderstats = player:WaitForChild("leaderstats")
	local level = leaderstats:WaitForChild("Level")
	previousLevels[player] = level.Value
end)

Players.PlayerRemoving:Connect(function(player)
	previousLevels[player] = nil
end)

-- Background loop to monitor players
while true do
	task.wait(0.2)
	for _, player in pairs(Players:GetPlayers()) do
		pcall(function()
			updateHealth(player)
		end)
	end
end
