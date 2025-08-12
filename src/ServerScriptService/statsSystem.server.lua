-- statsSystem.lua - Consolidated stats management (Place in ServerScriptService)
local StatsManager = require(script.Parent:WaitForChild("StatsManager"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for or create the statsEvents folder
local statsEvents = ReplicatedStorage:FindFirstChild("statsEvents")
if not statsEvents then
	statsEvents = Instance.new("Folder")
	statsEvents.Name = "statsEvents"
	statsEvents.Parent = ReplicatedStorage
end

-- Create Remote Events for stat upgrades
local damageUp = statsEvents:FindFirstChild("damageUp")
if not damageUp then
	damageUp = Instance.new("RemoteEvent")
	damageUp.Name = "damageUp"
	damageUp.Parent = statsEvents
end

local defenseUp = statsEvents:FindFirstChild("defenseUp")
if not defenseUp then
	defenseUp = Instance.new("RemoteEvent")
	defenseUp.Name = "defenseUp"
	defenseUp.Parent = statsEvents
end

local speedUp = statsEvents:FindFirstChild("speedUp")
if not speedUp then
	speedUp = Instance.new("RemoteEvent")
	speedUp.Name = "speedUp"
	speedUp.Parent = statsEvents
end

-- Create Remote Event for stat upgrade notifications
local statUpgradeResponse = statsEvents:FindFirstChild("statUpgradeResponse")
if not statUpgradeResponse then
	statUpgradeResponse = Instance.new("RemoteEvent")
	statUpgradeResponse.Name = "statUpgradeResponse"
	statUpgradeResponse.Parent = statsEvents
end

-- Create Remote Event for reset level NPC
local resetLevelNPC = ReplicatedStorage:FindFirstChild("resetLevelNPC")
if not resetLevelNPC then
	resetLevelNPC = Instance.new("RemoteEvent")
	resetLevelNPC.Name = "resetLevelNPC"
	resetLevelNPC.Parent = ReplicatedStorage
end

-- === PLAYER SETUP ===
game.Players.PlayerAdded:Connect(function(player)
	-- Create all player stats when they join
	StatsManager:CreatePlayerStats(player)

	-- FIXED: Add a small delay to ensure all stats are created before fixing base stats
	task.wait(0.1)

	-- AUTO-FIX: Automatically repair any corrupted base stats on join
	local statsFolder = player:FindFirstChild("statsFolder")
	if statsFolder then
		local damageStat = statsFolder:FindFirstChild("damageStat")
		local defenseStat = statsFolder:FindFirstChild("defenseStat")
		local speedStat = statsFolder:FindFirstChild("speedStat")

		if damageStat and defenseStat and speedStat then
			-- Get current base stats
			local baseDamage = player:GetAttribute("baseDamage")
			local baseDefense = player:GetAttribute("baseDefense")
			local baseSpeed = player:GetAttribute("baseSpeed")

			-- Check if base stats are missing or corrupted (lower than current stats)
			local needsRepair = false
			if not baseDamage or baseDamage < damageStat.Value then
				needsRepair = true
			end
			if not baseDefense or baseDefense < defenseStat.Value then
				needsRepair = true
			end
			if not baseSpeed or baseSpeed < speedStat.Value then
				needsRepair = true
			end

			-- Auto-repair if needed
			if needsRepair then
				player:SetAttribute("baseDamage", damageStat.Value)
				player:SetAttribute("baseDefense", defenseStat.Value)
				player:SetAttribute("baseSpeed", speedStat.Value)
				print("🔧 AUTO-REPAIRED base stats for " .. player.Name .. " on join: " .. damageStat.Value .. "/" .. defenseStat.Value .. "/" .. speedStat.Value)
			else
				--print("✅ " .. player.Name .. " joined with valid base stats: " .. (baseDamage or "?") .. "/" .. (baseDefense or "?") .. "/" .. (baseSpeed or "?"))
			end
		end
	end

	-- Ensure base stats are properly set (fallback)
	StatsManager:EnsureBaseStatsAreSet(player)

	-- Handle character spawning and speed application
	local function onCharacterAdded(character)
		StatsManager:ApplySpeedToCharacter(player, character)
	end

	-- Apply to current character if it exists
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Apply to future characters
	player.CharacterAdded:Connect(onCharacterAdded)
end)

-- === STAT UPGRADE HANDLERS ===
damageUp.OnServerEvent:Connect(function(player)
	local success, message = StatsManager:IncreaseDamage(player)
	if not success then
		warn("Failed to increase damage for " .. player.Name .. ": " .. (message or "Unknown error"))
		-- Send error message to client
		statUpgradeResponse:FireClient(player, false, message or "Failed to upgrade damage")
	else
		-- Send success message to client
		statUpgradeResponse:FireClient(player, true, message or "Damage increased!")
	end
end)

defenseUp.OnServerEvent:Connect(function(player)
	local success, message = StatsManager:IncreaseDefense(player)
	if not success then
		warn("Failed to increase defense for " .. player.Name .. ": " .. (message or "Unknown error"))
		-- Send error message to client
		statUpgradeResponse:FireClient(player, false, message or "Failed to upgrade defense")
	else
		-- Send success message to client
		statUpgradeResponse:FireClient(player, true, message or "Defense increased!")
	end
end)

speedUp.OnServerEvent:Connect(function(player)
	local success, message = StatsManager:IncreaseSpeed(player)
	if not success then
		warn("Failed to increase speed for " .. player.Name .. ": " .. (message or "Unknown error"))
		-- Send error message to client
		statUpgradeResponse:FireClient(player, false, message or "Failed to upgrade speed")
	else
		-- Send success message to client
		statUpgradeResponse:FireClient(player, true, message or "Speed increased!")
	end
end)

-- === RESET LEVEL NPC HANDLER ===
resetLevelNPC.OnServerEvent:Connect(function(player)
	local success = StatsManager:ResetPlayerLevel(player)
	if not success then
		warn("Failed to reset level for " .. player.Name)
	else
		print("🔄 " .. player.Name .. " reset their level and stats!")
	end
end)

-- === ADMIN COMMANDS ===
-- Function to give stat points to a player (useful for testing)
local function giveStatPoints(player, amount)
	local statsFolder = player:FindFirstChild("statsFolder")
	if statsFolder then
		local statPoints = statsFolder:FindFirstChild("statPoints")
		if statPoints then
			statPoints.Value = statPoints.Value + amount
			print("Gave " .. amount .. " stat points to " .. player.Name)
		end
	end
end

-- Function to display player's current stats (useful for debugging)
local function displayPlayerStats(player)
	local stats = StatsManager:GetPlayerStats(player)
	if stats then
		print("=== " .. player.Name .. "'s Stats ===")
		print("Level: " .. stats.level)
		print("EXP: " .. stats.exp)
		print("Gold: " .. stats.gold)
		print("Max Health: " .. stats.maxHealth)
		print("Stat Points: " .. stats.statPoints)
		print("Damage: " .. stats.damage)
		print("Defense: " .. stats.defense)
		print("Speed: " .. stats.speed)
		print("Has Active Buffs: " .. tostring(StatsManager:HasActiveStatBuffs(player)))
		print("Has Upgraded Stats: " .. tostring(StatsManager:HasUpgradedStats(player)))

		-- Debug base stats
		local baseDamage, baseDefense, baseSpeed = StatsManager:GetBaseStats(player)
		print("Base Stats: " .. baseDamage .. "/" .. baseDefense .. "/" .. baseSpeed)

		-- Show upgrade counts
		local upgrades = StatsManager:GetStatUpgrades(player)
		print("Upgrades: " .. upgrades.damageUpgrades .. "/" .. upgrades.defenseUpgrades .. "/" .. upgrades.speedUpgrades)
		print("=======================")
	else
		print("Could not retrieve stats for " .. player.Name)
	end
end

-- Example admin commands
game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		-- Only allow certain players to use admin commands
		if player.Name == "greatcoolroblox22" then -- Replace with your username
			local args = string.split(message, " ")

			if args[1]:lower() == "/givesp" and args[2] then
				local amount = tonumber(args[2])
				if amount then
					giveStatPoints(player, amount)
				end
			elseif args[1]:lower() == "/stats" then
				displayPlayerStats(player)
			elseif args[1]:lower() == "/resetstats" then
				StatsManager:ResetPlayerLevel(player)
			elseif args[1]:lower() == "/fixbase" then
				-- FIXED: Command to properly initialize base stats to current values
				local statsFolder = player:FindFirstChild("statsFolder")
				if statsFolder then
					local damageStat = statsFolder:FindFirstChild("damageStat")
					local defenseStat = statsFolder:FindFirstChild("defenseStat")
					local speedStat = statsFolder:FindFirstChild("speedStat")
					if damageStat and defenseStat and speedStat then
						-- Set base stats to current stat values (this saves your upgrades)
						player:SetAttribute("baseDamage", damageStat.Value)
						player:SetAttribute("baseDefense", defenseStat.Value)
						player:SetAttribute("baseSpeed", speedStat.Value)
						print("✅ Fixed base stats for " .. player.Name .. " to current values: " .. damageStat.Value .. "/" .. defenseStat.Value .. "/" .. speedStat.Value)
					end
				end
			elseif args[1]:lower() == "/forcerepair" then
				-- NEW: Force repair all players' base stats
				for _, otherPlayer in pairs(game.Players:GetPlayers()) do
					local statsFolder = otherPlayer:FindFirstChild("statsFolder")
					if statsFolder then
						local damageStat = statsFolder:FindFirstChild("damageStat")
						local defenseStat = statsFolder:FindFirstChild("defenseStat")
						local speedStat = statsFolder:FindFirstChild("speedStat")
						if damageStat and defenseStat and speedStat then
							otherPlayer:SetAttribute("baseDamage", damageStat.Value)
							otherPlayer:SetAttribute("baseDefense", defenseStat.Value)
							otherPlayer:SetAttribute("baseSpeed", speedStat.Value)
							print("🔧 Force repaired " .. otherPlayer.Name .. ": " .. damageStat.Value .. "/" .. defenseStat.Value .. "/" .. speedStat.Value)
						end
					end
				end
			elseif args[1]:lower() == "/checkbuffs" then
				-- Command to check buff status
				local hasBuffs = StatsManager:HasActiveStatBuffs(player)
				local hasUpgrades = StatsManager:HasUpgradedStats(player)
				print(player.Name .. " has active buffs: " .. tostring(hasBuffs))
				print(player.Name .. " has upgraded stats: " .. tostring(hasUpgrades))
			elseif args[1]:lower() == "/clearbuffs" then
				-- NEW: Command to clear temporary buffs only
				local success, message = StatsManager:ResetTemporaryEffects(player)
				print("Clear buffs result: " .. tostring(success) .. " - " .. (message or ""))
			end
		end
	end)
end)

--print("✅ StatsSystem loaded successfully!")
--print("🎮 All stat management is now handled by this single script.")
--print("🔧 Fixed buff detection system - no more false positives!")