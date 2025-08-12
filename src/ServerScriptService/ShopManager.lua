-- ShopManager.lua - Handles shop transactions and gold system (Place in ServerScriptService)
local ShopConfig = require(game.ReplicatedStorage:WaitForChild("ShopConfig"))
local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))
local ShopManager = {}

-- Function to create player gold value
function ShopManager:CreatePlayerGold(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		-- Check if gold already exists
		if not leaderstats:FindFirstChild("Gold") then
			local gold = Instance.new("IntValue")
			gold.Name = "Gold"
			gold.Value = 5 -- Starting gold 
			gold.Parent = leaderstats
		end
	end

	-- Also create inventory for the player
	InventoryManager:CreatePlayerInventory(player)
end

-- Function to get player's gold
function ShopManager:GetPlayerGold(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		if gold then
			return gold.Value
		end
	end
	return 0
end

-- Function to add gold to player
function ShopManager:AddGold(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		if gold then
			gold.Value = gold.Value + amount
			return true
		end
	end
	return false
end

-- Function to remove gold from player
function ShopManager:RemoveGold(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		if gold and gold.Value >= amount then
			gold.Value = gold.Value - amount
			return true
		end
	end
	return false
end

-- Function to handle item purchase (now adds to inventory instead of using immediately)
function ShopManager:PurchaseItem(player, itemName)
	local item = ShopConfig:GetItem(itemName)
	if not item then
		return false, "Item not found"
	end

	local playerGold = self:GetPlayerGold(player)
	if playerGold < item.price then
		return false, "Not enough gold"
	end

	-- Remove gold
	if not self:RemoveGold(player, item.price) then
		return false, "Failed to process payment"
	end

	-- Add item to inventory instead of using it immediately
	local success = InventoryManager:AddItem(player, itemName, 1)
	if success then
		-- Execute purchase action for any special effects or messages
		if item.action then
			local actionSuccess, message = item.action(player)
			return true, message or "Item purchased successfully!"
		end
		return true, "Item purchased and added to inventory!"
	else
		-- Refund gold if adding to inventory failed
		self:AddGold(player, item.price)
		return false, "Failed to add item to inventory"
	end
end

-- Function to use item from inventory
function ShopManager:UseInventoryItem(player, itemName)
	return InventoryManager:UseItem(player, itemName)
end

-- Function to get player's inventory
function ShopManager:GetPlayerInventory(player)
	return InventoryManager:GetPlayerInventory(player)
end

-- Function to award gold for enemy kills
function ShopManager:AwardKillGold(playersWhoHit, killEvent)
	local goldReward = ShopConfig:GetEnemyGoldReward(killEvent)
	if goldReward > 0 then
		for _, player in pairs(playersWhoHit) do
			if player and player:IsA("Player") then
				self:AddGold(player, goldReward)
				-- Optional: Send notification to player
				local shopEvents = game.ReplicatedStorage:FindFirstChild("shopEvents")
				if shopEvents then
					local goldNotification = shopEvents:FindFirstChild("goldNotification")
					if goldNotification then
						goldNotification:FireClient(player, goldReward, "Enemy Kill")
					end
				end
			end
		end
	end
end

-- Function to award gold for quest completion
function ShopManager:AwardQuestGold(player, questName)
	local goldReward = ShopConfig:GetQuestGoldReward(questName)
	if goldReward > 0 then
		self:AddGold(player, goldReward)
		-- Optional: Send notification to player
		local shopEvents = game.ReplicatedStorage:FindFirstChild("shopEvents")
		if shopEvents then
			local goldNotification = shopEvents:FindFirstChild("goldNotification")
			if goldNotification then
				goldNotification:FireClient(player, goldReward, "Quest Complete")
			end
		end
	end
end

-- Function to get shop items for a specific shopkeeper
function ShopManager:GetShopItems(shopkeeperName)
	return ShopConfig:GetShopkeeperItems(shopkeeperName)
end

-- Function to validate if a shopkeeper exists
function ShopManager:ValidateShopkeeper(shopkeeperName)
	return ShopConfig:GetShopkeeper(shopkeeperName) ~= nil
end

return ShopManager