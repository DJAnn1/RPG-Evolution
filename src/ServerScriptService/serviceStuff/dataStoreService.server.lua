-- DataStoreService.lua script - Updated with proper base stat handling
local DataStoreService = game:GetService("DataStoreService")
local StatsManager = require(game.ServerScriptService:WaitForChild("StatsManager"))
local playerDataStore = DataStoreService:GetDataStore("PlayerLevelExpData")

-- Helper function to convert inventory folder to saveable data
local function getInventoryData(player)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return {} end

	local inventoryData = {}
	for _, item in pairs(inventory:GetChildren()) do
		if item:IsA("IntValue") then
			inventoryData[item.Name] = item.Value
		end
	end
	return inventoryData
end

-- Helper function to restore inventory from saved data
local function restoreInventory(player, inventoryData)
	if not inventoryData then return end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		inventory = Instance.new("Folder")
		inventory.Name = "Inventory"
		inventory.Parent = player
	end

	-- Clear existing inventory first
	for _, item in pairs(inventory:GetChildren()) do
		item:Destroy()
	end

	-- Restore saved items
	for itemName, quantity in pairs(inventoryData) do
		local item = Instance.new("IntValue")
		item.Name = itemName
		item.Value = quantity
		item.Parent = inventory
	end
end

game.Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats")
	local exp = leaderstats:WaitForChild("EXP")
	local level = leaderstats:WaitForChild("Level")
	local gold = leaderstats:WaitForChild("Gold")
	local healthStat = player:WaitForChild("maxHealthStat")
	local statsFolder = player:WaitForChild("statsFolder")
	local statPoints = statsFolder:WaitForChild("statPoints")
	local damageStat = statsFolder:WaitForChild("damageStat")
	local defenseStat = statsFolder:WaitForChild("defenseStat")
	local speedStat = statsFolder:WaitForChild("speedStat")

	local success, data = pcall(function()
		return playerDataStore:GetAsync(player.UserId)
	end)

	if success and data then
		exp.Value = data.EXP or 0
		level.Value = data.Level or 1
		gold.Value = data.Gold or 0
		healthStat.Value = data.Health or 100
		statPoints.Value = data.Statpoints or 0
		damageStat.Value = data.Damage or 1
		defenseStat.Value = data.Defense or 1
		speedStat.Value = data.Speed or 1

		-- NEW: Restore inventory data
		restoreInventory(player, data.Inventory)

		-- CRITICAL: Sync base stats with loaded data to prevent false buff detection
		-- Wait a moment for stats to be fully loaded
		task.wait(0.1)
		StatsManager:OnDataLoaded(player)

		--print("✅ Loaded data for " .. player.Name .. " - Stats: " .. damageStat.Value .. "/" .. defenseStat.Value .. "/" .. speedStat.Value)
	else
		warn("Failed to load player data for " .. player.Name)
		-- Still sync base stats even if data loading failed
		task.wait(0.1)
		StatsManager:OnDataLoaded(player)
	end
end)

game.Players.PlayerRemoving:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local exp = leaderstats:FindFirstChild("EXP")
		local level = leaderstats:FindFirstChild("Level")
		local gold = leaderstats:FindFirstChild("Gold")
		local healthStat = player:FindFirstChild("maxHealthStat")
		local statsFolder = player:FindFirstChild("statsFolder")

		if healthStat and statsFolder then
			local statPoints = statsFolder:FindFirstChild("statPoints")
			local damageStat = statsFolder:FindFirstChild("damageStat")
			local defenseStat = statsFolder:FindFirstChild("defenseStat")
			local speedStat = statsFolder:FindFirstChild("speedStat")

			if exp and level and gold and statPoints and damageStat and defenseStat and speedStat then
				-- Get base stats for saving (in case player had temporary buffs)
				local baseDamage, baseDefense, baseSpeed = StatsManager:GetBaseStats(player)

				local dataToSave = {
					EXP = exp.Value,
					Level = level.Value,
					Gold = gold.Value,
					Health = healthStat.Value,
					Statpoints = statPoints.Value,
					-- Save the BASE stats, not current stats (prevents saving temporary buffs)
					Damage = baseDamage,
					Defense = baseDefense,
					Speed = baseSpeed,
					Inventory = getInventoryData(player)
				}

				local success, err = pcall(function()
					playerDataStore:SetAsync(player.UserId, dataToSave)
				end)

				if not success then
					warn("Failed to save data for player "..player.Name..": "..err)
				else
					--print("✅ Saved data for " .. player.Name .. " - Base stats: " .. baseDamage .. "/" .. baseDefense .. "/" .. baseSpeed)
				end
			end
		end
	end
end)

-- Updated auto-save function
local function autoSavePlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local exp = leaderstats:FindFirstChild("EXP")
		local level = leaderstats:FindFirstChild("Level")
		local gold = leaderstats:FindFirstChild("Gold")
		local healthStat = player:FindFirstChild("maxHealthStat")
		local statsFolder = player:FindFirstChild("statsFolder")

		if healthStat and statsFolder then
			local statPoints = statsFolder:FindFirstChild("statPoints")
			local damageStat = statsFolder:FindFirstChild("damageStat")
			local defenseStat = statsFolder:FindFirstChild("defenseStat")
			local speedStat = statsFolder:FindFirstChild("speedStat")

			if exp and level and gold and statPoints and damageStat and defenseStat and speedStat then
				-- Get base stats for saving
				local baseDamage, baseDefense, baseSpeed = StatsManager:GetBaseStats(player)

				local dataToSave = {
					EXP = exp.Value,
					Level = level.Value,
					Gold = gold.Value,
					Health = healthStat.Value,
					Statpoints = statPoints.Value,
					-- Save the BASE stats, not current stats
					Damage = baseDamage,
					Defense = baseDefense,
					Speed = baseSpeed,
					Inventory = getInventoryData(player)
				}

				local success, err = pcall(function()
					playerDataStore:SetAsync(player.UserId, dataToSave)
				end)

				if not success then
					warn("Auto-save failed for player "..player.Name..": "..err)
				end
			end
		end
	end
end

-- Optional: Set up auto-save every 5 minutes for all players
--[[
spawn(function()
	while true do
		wait(300) -- 5 minutes
		for _, player in pairs(game.Players:GetPlayers()) do
			autoSavePlayer(player)
		end
	end
end)
--]]