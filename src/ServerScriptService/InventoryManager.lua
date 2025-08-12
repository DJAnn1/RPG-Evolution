-- InventoryManager.lua - Handles player inventory and item usage (Place in ServerScriptService)
local InventoryManager = {}

-- Helper function to notify client of inventory changes
local function notifyInventoryUpdate(player)
	local inventoryEvents = game.ReplicatedStorage:FindFirstChild("inventoryEvents")
	if inventoryEvents then
		local inventoryUpdate = inventoryEvents:FindFirstChild("inventoryUpdate")
		if inventoryUpdate then
			inventoryUpdate:FireClient(player)
		end
	end
end

-- Create inventory for player
function InventoryManager:CreatePlayerInventory(player)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		inventory = Instance.new("Folder")
		inventory.Name = "Inventory"
		inventory.Parent = player
	end

	-- Create cooldowns folder
	local cooldowns = player:FindFirstChild("ItemCooldowns")
	if not cooldowns then
		cooldowns = Instance.new("Folder")
		cooldowns.Name = "ItemCooldowns"
		cooldowns.Parent = player
	end

	return inventory
end

-- Add item to player's inventory
function InventoryManager:AddItem(player, itemName, quantity)
	quantity = quantity or 1
	local inventory = self:CreatePlayerInventory(player)

	local existingItem = inventory:FindFirstChild(itemName)
	if existingItem then
		existingItem.Value = existingItem.Value + quantity
	else
		local newItem = Instance.new("IntValue")
		newItem.Name = itemName
		newItem.Value = quantity
		newItem.Parent = inventory
	end

	notifyInventoryUpdate(player)
	return true
end

-- Remove item from player's inventory
function InventoryManager:RemoveItem(player, itemName, quantity)
	quantity = quantity or 1
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return false end

	local item = inventory:FindFirstChild(itemName)
	if not item or item.Value < quantity then
		return false
	end

	item.Value = item.Value - quantity
	if item.Value <= 0 then
		item:Destroy()
	end

	notifyInventoryUpdate(player)
	return true
end

-- Get item quantity in player's inventory
function InventoryManager:GetItemQuantity(player, itemName)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return 0 end

	local item = inventory:FindFirstChild(itemName)
	return item and item.Value or 0
end

-- Check if item is on cooldown
function InventoryManager:IsItemOnCooldown(player, itemName)
	local cooldowns = player:FindFirstChild("ItemCooldowns")
	if not cooldowns then return false end

	local cooldown = cooldowns:FindFirstChild(itemName)
	if cooldown then
		if tick() < cooldown.Value then
			return true, cooldown.Value - tick() -- Return remaining time
		else
			cooldown:Destroy()
			return false
		end
	end

	return false
end

-- Set item cooldown
function InventoryManager:SetItemCooldown(player, itemName, cooldownTime)
	local cooldowns = player:FindFirstChild("ItemCooldowns")
	if not cooldowns then
		cooldowns = Instance.new("Folder")
		cooldowns.Name = "ItemCooldowns"
		cooldowns.Parent = player
	end

	local existingCooldown = cooldowns:FindFirstChild(itemName)
	if existingCooldown then
		existingCooldown:Destroy()
	end

	local cooldown = Instance.new("NumberValue")
	cooldown.Name = itemName
	cooldown.Value = tick() + cooldownTime
	cooldown.Parent = cooldowns

	-- Auto-cleanup cooldown after it expires
	task.delay(cooldownTime, function()
		if cooldown and cooldown.Parent then
			cooldown:Destroy()
		end
	end)
end

-- OPTIMIZED: Handle buff items using centralized logic
function InventoryManager:HandleBuffItem(player, item)
	local StatsManager = require(game.ServerScriptService:WaitForChild("StatsManager"))

	-- Handle reset scroll
	if item.buffType == "reset" then
		self:CancelPlayerBuffTimers(player)
		return StatsManager:ResetTemporaryEffects(player)
	end

	-- Check if already buffed (prevent stacking)
	if StatsManager:HasActiveStatBuffs(player) then
		return false, "You already have active buffs! Use a Reset Scroll first."
	end

	-- Get player stats
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then
		return false, "Stats folder not found!"
	end

	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not damageStat or not defenseStat or not speedStat then
		return false, "Stats not found!"
	end

	-- Get base stats for proper buff calculation
	local baseDamage, baseDefense, baseSpeed = StatsManager:GetBaseStats(player)

	-- Initialize buff timers storage for this player
	if not self.activeBuffTimers then
		self.activeBuffTimers = {}
	end
	if not self.activeBuffTimers[player.UserId] then
		self.activeBuffTimers[player.UserId] = {}
	end

	-- CENTRALIZED BUFF LOGIC - No more duplicates!
	local success = self:ApplyBuffToPlayer(player, item, {
		baseDamage = baseDamage,
		baseDefense = baseDefense,
		baseSpeed = baseSpeed,
		damageStat = damageStat,
		defenseStat = defenseStat,
		speedStat = speedStat
	})

	if success then
		-- Return the message from the item config
		if item.useAction then
			local _, message = item.useAction(player)
			return true, message
		end
		return true, "Buff applied successfully!"
	else
		return false, "Failed to apply buff!"
	end
end

-- NEW: Centralized buff application logic (eliminates all duplicates)
function InventoryManager:ApplyBuffToPlayer(player, item, stats)
	local function applyStatBuff(stat, baseValue, multiplier)
		local buffAmount = math.floor(baseValue * multiplier)
		stat.Value = stat.Value + buffAmount
		return buffAmount
	end

	local function removeStatBuff(stat, buffAmount)
		if stat and stat.Parent then
			stat.Value = math.max(stat.Value - buffAmount, 1)
		end
	end

	local function createBuffTimer(duration, cleanupFunction)
		local thread
		thread = task.delay(duration, function()
			cleanupFunction()
			-- Clean up thread reference
			if self.activeBuffTimers and self.activeBuffTimers[player.UserId] then
				for i, t in pairs(self.activeBuffTimers[player.UserId]) do
					if t == thread then
						table.remove(self.activeBuffTimers[player.UserId], i)
						break
					end
				end
			end
		end)

		table.insert(self.activeBuffTimers[player.UserId], thread)
		return thread
	end

	-- Apply buffs based on type using centralized logic
	if item.buffType == "speed" then
		local buffAmount = applyStatBuff(stats.speedStat, stats.baseSpeed, item.buffAmount)
		createBuffTimer(item.duration, function()
			removeStatBuff(stats.speedStat, buffAmount)
		end)

	elseif item.buffType == "damage" then
		local buffAmount = applyStatBuff(stats.damageStat, stats.baseDamage, item.buffAmount)
		createBuffTimer(item.duration, function()
			removeStatBuff(stats.damageStat, buffAmount)
		end)

	elseif item.buffType == "defense" then
		local buffAmount = applyStatBuff(stats.defenseStat, stats.baseDefense, item.buffAmount)
		createBuffTimer(item.duration, function()
			removeStatBuff(stats.defenseStat, buffAmount)
		end)

	elseif item.buffType == "combo" then
		local damageBuffAmount = applyStatBuff(stats.damageStat, stats.baseDamage, item.damageBoost)
		local defenseBuffAmount = applyStatBuff(stats.defenseStat, stats.baseDefense, item.defenseBoost)

		createBuffTimer(item.duration, function()
			removeStatBuff(stats.damageStat, damageBuffAmount)
			removeStatBuff(stats.defenseStat, defenseBuffAmount)
		end)

	elseif item.buffType == "ultimate" then
		local damageBuffAmount = applyStatBuff(stats.damageStat, stats.baseDamage, item.damageBoost)
		local defenseBuffAmount = applyStatBuff(stats.defenseStat, stats.baseDefense, item.defenseBoost)
		local speedBuffAmount = applyStatBuff(stats.speedStat, stats.baseSpeed, item.speedBoost)

		createBuffTimer(item.duration, function()
			removeStatBuff(stats.damageStat, damageBuffAmount)
			removeStatBuff(stats.defenseStat, defenseBuffAmount)
			removeStatBuff(stats.speedStat, speedBuffAmount)
		end)
	else
		return false
	end

	return true
end

-- Cancel all active buff timers for a player
function InventoryManager:CancelPlayerBuffTimers(player)
	if not self.activeBuffTimers then
		self.activeBuffTimers = {}
		return
	end

	local playerTimers = self.activeBuffTimers[player.UserId]
	if playerTimers then
		for _, thread in pairs(playerTimers) do
			task.cancel(thread)
		end
		self.activeBuffTimers[player.UserId] = {}
	end
end

-- Clean up player buff timers when they leave
function InventoryManager:CleanupPlayerBuffs(player)
	self:CancelPlayerBuffTimers(player)
	if self.activeBuffTimers then
		self.activeBuffTimers[player.UserId] = nil
	end
end

-- Use an item from inventory
function InventoryManager:UseItem(player, itemName)
	-- Check if player has the item
	if self:GetItemQuantity(player, itemName) <= 0 then
		return false, "You don't have this item!"
	end

	-- Get item config
	local ShopConfig = require(game.ReplicatedStorage:WaitForChild("ShopConfig"))
	local item = ShopConfig:GetItem(itemName)
	if not item then
		return false, "Invalid item!"
	end

	-- Check for shared cooldowns (health potions share cooldown)
	local cooldownGroup = item.cooldownGroup or itemName
	local onCooldown, remainingTime = self:IsItemOnCooldown(player, cooldownGroup)
	if onCooldown then
		return false, string.format("Item is on cooldown! %.1f seconds remaining.", remainingTime)
	end

	-- Handle different item types
	local success, message

	if item.buffType then
		-- Handle buff items with centralized logic
		success, message = self:HandleBuffItem(player, item)
	elseif item.useAction then
		-- Handle regular items (like health potions)
		success, message = item.useAction(player)
	else
		return false, "This item cannot be used!"
	end

	if success then
		-- Remove item from inventory
		self:RemoveItem(player, itemName, 1)
		-- Set cooldown using the group name
		if item.cooldown then
			self:SetItemCooldown(player, cooldownGroup, item.cooldown)
		end
		return true, message
	else
		return false, message
	end
end

-- Check if any item in a cooldown group is on cooldown
function InventoryManager:IsGroupOnCooldown(player, cooldownGroup)
	return self:IsItemOnCooldown(player, cooldownGroup)
end

-- Get player's full inventory
function InventoryManager:GetPlayerInventory(player)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		return {} 
	end

	local items = {}
	for _, item in pairs(inventory:GetChildren()) do
		if item:IsA("IntValue") then
			items[item.Name] = item.Value
		end
	end

	return items
end

-- Initialize buff timer cleanup when players leave
game.Players.PlayerRemoving:Connect(function(player)
	local success, err = pcall(function()
		InventoryManager:CleanupPlayerBuffs(player)
	end)
	if not success then
		warn("Error cleaning up buff timers for " .. player.Name .. ": " .. err)
	end
end)

return InventoryManager