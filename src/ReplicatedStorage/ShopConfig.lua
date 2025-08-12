-- ShopConfig.lua - Centralized shop configuration (Place in ReplicatedStorage)
local ShopConfig = {
	-- Shop items definitions
	items = {
		healthPotion = {
			displayName = "Health Potion",
			description = "Restores 50 HP instantly",
			price = 40,
			icon = "rbxassetid://164758928", -- Replace with actual icon ID
			category = "consumables",
			cooldown = 60,
			cooldownGroup = "healthPotions", -- Shared cooldown group
			-- Purchase action (adds to inventory)
			action = function(player)
				-- This will be handled by InventoryManager
				return true, "Health Potion added to inventory!"
			end,
			-- Use action (when used from inventory)
			useAction = function(player)
				local character = player.Character
				if character then
					local humanoid = character:FindFirstChild("Humanoid")
					local maxHealthStat = player:FindFirstChild("maxHealthStat")
					if humanoid and maxHealthStat then
						local newHealth = math.min(humanoid.Health + 50, maxHealthStat.Value)
						humanoid.Health = newHealth
						return true, "Used Health Potion! Restored 50 HP."
					end
				end
				return false, "Failed to use Health Potion."
			end
		},
		bigHealthPotion = {
			displayName = "Big Health Potion",
			description = "Restores 100 HP instantly",
			price = 80,
			icon = "rbxassetid://16306040837", -- Replace with actual icon ID
			category = "consumables",
			cooldown = 60,
			cooldownGroup = "healthPotions", -- Shared cooldown group
			-- Purchase action (adds to inventory)
			action = function(player)
				return true, "Big Health Potion added to inventory!"
			end,
			-- Use action (when used from inventory)
			useAction = function(player)
				local character = player.Character
				if character then
					local humanoid = character:FindFirstChild("Humanoid")
					local maxHealthStat = player:FindFirstChild("maxHealthStat")
					if humanoid and maxHealthStat then
						local newHealth = math.min(humanoid.Health + 100, maxHealthStat.Value)
						humanoid.Health = newHealth
						return true, "Used Big Health Potion! Restored 100 HP."
					end
				end
				return false, "Failed to use Big Health Potion."
			end
		},
		-- Speed boost item (buff logic handled in server)
		speedBoost = {
			displayName = "Speed Boost",
			description = "Increases speed for 30 seconds",
			price = 50,
			icon = "rbxassetid://0",
			category = "buffs",
			cooldown = 45,
			buffType = "speed",
			buffAmount = 0.5, -- 50% boost
			duration = 30,
			action = function(player)
				return true, "Speed Boost added to inventory!"
			end,
			useAction = function(player)
				-- This will be handled by the server-side buff system
				return true, "Speed boost activated for 30 seconds!"
			end
		},
		-- Damage boost item
		strengthBoost = {
			displayName = "Strength Boost",
			description = "Doubles damage for 1 minute",
			price = 100,
			icon = "rbxassetid://0",
			category = "buffs",
			cooldown = 120,
			buffType = "damage",
			buffAmount = 1.0, -- 100% boost (double)
			duration = 60,
			action = function(player)
				return true, "Strength Boost added to inventory!"
			end,
			useAction = function(player)
				return true, "Strength doubled for 1 minute!"
			end
		},
		-- Defense boost item
		defenseBoost = {
			displayName = "Defense Boost",
			description = "Doubles defense for 1 minute",
			price = 100,
			icon = "rbxassetid://0",
			category = "buffs",
			cooldown = 120,
			buffType = "defense", 
			buffAmount = 1.0, -- 100% boost (double)
			duration = 60,
			action = function(player)
				return true, "Defense Boost added to inventory!"
			end,
			useAction = function(player)
				return true, "Defense doubled for 1 minute!"
			end
		},
		-- Combined buff item
		battleTonic = {
			displayName = "Battle Tonic",
			description = "Triples damage and doubles defense for 30 seconds",
			price = 200,
			icon = "rbxassetid://0",
			category = "buffs",
			cooldown = 120,
			cooldownGroup = "battleBuffs",
			buffType = "combo",
			damageBoost = 2.0, -- 3x total (2x boost)
			defenseBoost = 1.0, -- 2x total (1x boost) 
			duration = 30,
			action = function(player)
				return true, "Battle Tonic added to inventory!"
			end,
			useAction = function(player)
				return true, "Battle ready! Damage x3, Defense x2 for 30 seconds!"
			end
		},
		-- Ultimate buff item
		warriorElixir = {
			displayName = "Warrior's Elixir",
			description = "Quadruples damage, triples defense, and boosts speed for 15 seconds",
			price = 500,
			icon = "rbxassetid://0",
			category = "buffs",
			cooldown = 300,
			cooldownGroup = "ultimateBuffs",
			buffType = "ultimate",
			damageBoost = 3.0, -- 4x total (3x boost)
			defenseBoost = 2.0, -- 3x total (2x boost)
			speedBoost = 0.5, -- 50% boost
			duration = 15,
			action = function(player)
				return true, "Warrior's Elixir added to inventory!"
			end,
			useAction = function(player)
				return true, "GODMODE! Damage x4, Defense x3, Speed boost for 15 seconds!"
			end
		},
		-- Stat reset item
		resetScroll = {
			displayName = "Buff Reset Scroll",
			description = "Resets all temporary stat effects immediately",
			price = 25,
			icon = "rbxassetid://0",
			category = "utility",
			cooldown = 10,
			buffType = "reset",
			action = function(player)
				return true, "Buff Reset Scroll added to inventory!"
			end,
			useAction = function(player)
				return true, "All temporary effects removed!"
			end
		}
	},

	-- Shopkeeper definitions
	shopkeepers = {
		potionMerchant = {
			displayName = "Potion Merchant",
			dialogue = {
				greeting = {"Welcome to my potion shop!", "What can I brew for you today?"},
				farewell = {"Come back anytime!"},
				noMoney = {"You don't have enough gold for that!", "Come back when you're richer!"},
				purchaseSuccess = {"Thank you for your purchase!", "Use it wisely!"}
			},
			items = {"healthPotion", "bigHealthPotion", "battleTonic", "warriorElixir"}, -- Items this shopkeeper sells
			npcName = "potionMerchantDialogue" -- Must match NPC name in dialogueFolder
		},
		-- Updated general merchant with more items
		generalMerchant = {
			displayName = "General Merchant",
			dialogue = {
				greeting = {"Welcome traveler!", "Browse my wares!"},
				farewell = {"May fortune favor you!"},
				noMoney = {"Your pockets seem light!", "Gold first, goods second!", "Come back when you can afford my goods!"},
				purchaseSuccess = {"Excellent choice!", "Pleasure doing business!", "Use it well, warrior!"}
			},
			items = {"speedBoost", "strengthBoost", "defenseBoost", "resetScroll"}, -- More items
			npcName = "generalMerchantDialogue"
		}
	},

	-- Gold rewards for different activities
	goldRewards = {
		-- Enemy kill rewards (based on kill events from your quest system)
		enemyKills = {
			EnemyKilled = 5, -- Basic enemies give 5 gold
			telamonKilled = 20, -- Boss gives more gold
			arab1Killed = 8,
			fishmanKilled = 10,
			linkKilled = 12
		},
		-- Quest completion rewards (UPDATED to match QuestConfig quest names)
		questCompletions = {
			quest1 = 50,        -- Basic Quest completion
			bossQuest1 = 200,   -- Boss Quest completion  
			arabQuest1 = 75,    -- Arab Quest completion (increased from 50)
			linkQuest1 = 150    -- Link Quest completion
		}
	}
}

-- Helper function to get item config by name
function ShopConfig:GetItem(itemName)
	return self.items[itemName]
end

-- Helper function to get shopkeeper config by name
function ShopConfig:GetShopkeeper(shopkeeperName)
	return self.shopkeepers[shopkeeperName]
end

-- Helper function to get all items for a specific shopkeeper
function ShopConfig:GetShopkeeperItems(shopkeeperName)
	local shopkeeper = self.shopkeepers[shopkeeperName]
	if not shopkeeper then return {} end

	local items = {}
	for _, itemName in pairs(shopkeeper.items) do
		local item = self.items[itemName]
		if item then
			items[itemName] = item
		end
	end
	return items
end

-- Helper function to get gold reward for enemy kill
function ShopConfig:GetEnemyGoldReward(killEvent)
	return self.goldRewards.enemyKills[killEvent] or 0
end

-- Helper function to get gold reward for quest completion
function ShopConfig:GetQuestGoldReward(questName)
	return self.goldRewards.questCompletions[questName] or 0
end

return ShopConfig