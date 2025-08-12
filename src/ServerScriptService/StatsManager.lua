-- StatsManager.lua - Centralized stats management (Place in ServerScriptService)
local StatsManager = {}

-- Default stat values
local DEFAULT_STATS = {
	level = 1,
	exp = 0,
	gold = 0,
	maxHealth = 100,
	statPoints = 0,
	damage = 1,
	defense = 1,
	speed = 1
}

-- Speed calculation formula
local function calculateWalkSpeed(speedStat)
	return 16 + (speedStat * 1.5)
end

-- NEW: Function to properly sync base stats with current stats
function StatsManager:SyncBaseStatsWithCurrent(player)
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then return end

	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not damageStat or not defenseStat or not speedStat then return end

	-- Always sync base stats to match current stats (this handles data loading)
	player:SetAttribute("baseDamage", damageStat.Value)
	player:SetAttribute("baseDefense", defenseStat.Value)
	player:SetAttribute("baseSpeed", speedStat.Value)

	--print("🔄 Synced base stats for " .. player.Name .. " to current values: " .. damageStat.Value .. "/" .. defenseStat.Value .. "/" .. speedStat.Value)
end

-- IMPROVED: Much more robust buff detection
function StatsManager:HasActiveStatBuffs(player)
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then return false end

	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not damageStat or not defenseStat or not speedStat then return false end

	-- Get base stats
	local baseDamage = player:GetAttribute("baseDamage")
	local baseDefense = player:GetAttribute("baseDefense")
	local baseSpeed = player:GetAttribute("baseSpeed")

	-- If ANY base stat is missing, sync them and return false (no buffs)
	if not baseDamage or not baseDefense or not baseSpeed then
		self:SyncBaseStatsWithCurrent(player)
		return false
	end

	-- Use a reasonable tolerance for floating point comparisons
	local TOLERANCE = 0.1

	-- Check if current stats are significantly higher than base stats
	local damageBuffed = damageStat.Value > (baseDamage + TOLERANCE)
	local defenseBuffed = defenseStat.Value > (baseDefense + TOLERANCE)
	local speedBuffed = speedStat.Value > (baseSpeed + TOLERANCE)

	local hasBuffs = damageBuffed or defenseBuffed or speedBuffed

	if hasBuffs then
		--print("🔍 " .. player.Name .. " has active buffs - Current: " .. damageStat.Value .. "/" .. defenseStat.Value .. "/" .. speedStat.Value .. " Base: " .. baseDamage .. "/" .. baseDefense .. "/" .. baseSpeed)
	end

	return hasBuffs
end

-- ADDED: Missing EnsureBaseStatsAreSet method for compatibility
function StatsManager:EnsureBaseStatsAreSet(player)
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then return end

	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not damageStat or not defenseStat or not speedStat then return end

	-- Only set base stats if they don't exist
	if not player:GetAttribute("baseDamage") then
		player:SetAttribute("baseDamage", damageStat.Value)
	end
	if not player:GetAttribute("baseDefense") then
		player:SetAttribute("baseDefense", defenseStat.Value)
	end
	if not player:GetAttribute("baseSpeed") then
		player:SetAttribute("baseSpeed", speedStat.Value)
	end

	--print("✅ " .. player.Name .. " joined with valid base stats: " .. player:GetAttribute("baseDamage") .. "/" .. player:GetAttribute("baseDefense") .. "/" .. player:GetAttribute("baseSpeed"))
end

-- Create all player stats and folders
function StatsManager:CreatePlayerStats(player)
	-- Create leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = DEFAULT_STATS.level
	level.Parent = leaderstats

	local exp = Instance.new("IntValue")
	exp.Name = "EXP"
	exp.Value = DEFAULT_STATS.exp
	exp.Parent = leaderstats

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = DEFAULT_STATS.gold
	gold.Parent = leaderstats

	-- Create maxHealthStat
	local maxHealthStat = Instance.new("IntValue")
	maxHealthStat.Name = "maxHealthStat"
	maxHealthStat.Value = DEFAULT_STATS.maxHealth
	maxHealthStat.Parent = player

	-- Create statsFolder
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "statsFolder"
	statsFolder.Parent = player

	local statPoints = Instance.new("IntValue")
	statPoints.Name = "statPoints"
	statPoints.Value = DEFAULT_STATS.statPoints
	statPoints.Parent = statsFolder

	local damageStat = Instance.new("IntValue")
	damageStat.Name = "damageStat"
	damageStat.Value = DEFAULT_STATS.damage
	damageStat.Parent = statsFolder

	local defenseStat = Instance.new("IntValue")
	defenseStat.Name = "defenseStat"
	defenseStat.Value = DEFAULT_STATS.defense
	defenseStat.Parent = statsFolder

	local speedStat = Instance.new("IntValue")
	speedStat.Name = "speedStat"
	speedStat.Value = DEFAULT_STATS.speed
	speedStat.Parent = statsFolder

	-- Set initial base stats to default values
	self:SetBaseStats(player, DEFAULT_STATS.damage, DEFAULT_STATS.defense, DEFAULT_STATS.speed)

	--print("📊 Created stats for " .. player.Name .. " with initial base stats: " .. DEFAULT_STATS.damage .. "/" .. DEFAULT_STATS.defense .. "/" .. DEFAULT_STATS.speed)

	return leaderstats, maxHealthStat, statsFolder
end

-- NEW: Function to call after data loading is complete
function StatsManager:OnDataLoaded(player)
	-- This should be called after the DataStore has loaded the player's data
	-- It ensures base stats match the loaded stats
	self:SyncBaseStatsWithCurrent(player)
end

-- Set base stats as attributes (for reset scroll functionality)
function StatsManager:SetBaseStats(player, baseDamage, baseDefense, baseSpeed)
	player:SetAttribute("baseDamage", baseDamage)
	player:SetAttribute("baseDefense", baseDefense)
	player:SetAttribute("baseSpeed", baseSpeed)
end

-- Get base stats from attributes with better fallback logic
function StatsManager:GetBaseStats(player)
	local baseDamage = player:GetAttribute("baseDamage")
	local baseDefense = player:GetAttribute("baseDefense") 
	local baseSpeed = player:GetAttribute("baseSpeed")

	-- If any attribute is missing, fall back to current stat values and set the attributes
	if not baseDamage or not baseDefense or not baseSpeed then
		local statsFolder = player:FindFirstChild("statsFolder")
		if statsFolder then
			local damageStat = statsFolder:FindFirstChild("damageStat")
			local defenseStat = statsFolder:FindFirstChild("defenseStat")
			local speedStat = statsFolder:FindFirstChild("speedStat")

			baseDamage = baseDamage or (damageStat and damageStat.Value) or DEFAULT_STATS.damage
			baseDefense = baseDefense or (defenseStat and defenseStat.Value) or DEFAULT_STATS.defense
			baseSpeed = baseSpeed or (speedStat and speedStat.Value) or DEFAULT_STATS.speed

			-- Set the missing attributes
			if not player:GetAttribute("baseDamage") then player:SetAttribute("baseDamage", baseDamage) end
			if not player:GetAttribute("baseDefense") then player:SetAttribute("baseDefense", baseDefense) end
			if not player:GetAttribute("baseSpeed") then player:SetAttribute("baseSpeed", baseSpeed) end
		else
			baseDamage = baseDamage or DEFAULT_STATS.damage
			baseDefense = baseDefense or DEFAULT_STATS.defense
			baseSpeed = baseSpeed or DEFAULT_STATS.speed
		end
	end

	return baseDamage, baseDefense, baseSpeed
end

-- Apply speed stat to character
function StatsManager:ApplySpeedToCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	local statsFolder = player:WaitForChild("statsFolder")
	local speedStat = statsFolder:WaitForChild("speedStat")

	-- Set initial speed
	humanoid.WalkSpeed = calculateWalkSpeed(speedStat.Value)

	-- Connect to speed changes
	local speedConnection = speedStat.Changed:Connect(function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = calculateWalkSpeed(speedStat.Value)
		end
	end)

	-- Clean up connection when character is removed
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			speedConnection:Disconnect()
		end
	end)
end

-- Increase damage stat
function StatsManager:IncreaseDamage(player)
	-- Check for active stat buffs
	if self:HasActiveStatBuffs(player) then
		return false, "Cannot upgrade stats while using stat boosters!"
	end

	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then 
		print("No stats folder found for " .. player.Name)
		return false, "Stats folder not found"
	end

	local statPoints = statsFolder:FindFirstChild("statPoints")
	local damageStat = statsFolder:FindFirstChild("damageStat")

	if not statPoints or not damageStat then 
		print("No statpoints or damage stat found for " .. player.Name)
		return false, "Required stats not found"
	end

	if statPoints.Value >= 1 then
		statPoints.Value = statPoints.Value - 1
		damageStat.Value = damageStat.Value + 1
		-- Update base stat for reset functionality
		player:SetAttribute("baseDamage", damageStat.Value)
		--print("💪 " .. player.Name .. " increased damage to " .. damageStat.Value)
		return true, "Damage increased!"
	end

	return false, "Not enough stat points"
end

-- Increase defense stat
function StatsManager:IncreaseDefense(player)
	-- Check for active stat buffs
	if self:HasActiveStatBuffs(player) then
		return false, "Cannot upgrade stats while using stat boosters!"
	end

	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then 
		print("No stats folder found for " .. player.Name)
		return false, "Stats folder not found"
	end

	local statPoints = statsFolder:FindFirstChild("statPoints")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")

	if not statPoints or not defenseStat then 
		print("No statpoints or defense stat found for " .. player.Name)
		return false, "Required stats not found"
	end

	if statPoints.Value >= 1 then
		statPoints.Value = statPoints.Value - 1
		defenseStat.Value = defenseStat.Value + 1
		-- Update base stat for reset functionality
		player:SetAttribute("baseDefense", defenseStat.Value)
		--print("🛡️ " .. player.Name .. " increased defense to " .. defenseStat.Value)
		return true, "Defense increased!"
	end

	return false, "Not enough stat points"
end

-- Increase speed stat
function StatsManager:IncreaseSpeed(player)
	-- Check for active stat buffs
	if self:HasActiveStatBuffs(player) then
		return false, "Cannot upgrade stats while using stat boosters!"
	end

	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then 
		print("No stats folder found for " .. player.Name)
		return false, "Stats folder not found"
	end

	local statPoints = statsFolder:FindFirstChild("statPoints")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not statPoints or not speedStat then 
		print("No statpoints or speed stat found for " .. player.Name)
		return false, "Required stats not found"
	end

	if statPoints.Value >= 1 then
		statPoints.Value = statPoints.Value - 1
		speedStat.Value = speedStat.Value + 1
		-- Update base stat for reset functionality
		player:SetAttribute("baseSpeed", speedStat.Value)
		--print("⚡ " .. player.Name .. " increased speed to " .. speedStat.Value)
		return true, "Speed increased!"
	end

	return false, "Not enough stat points"
end

-- Reset player level and stats (for reset Level NPC)
function StatsManager:ResetPlayerLevel(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local statsFolder = player:FindFirstChild("statsFolder")
	local maxHealthStat = player:FindFirstChild("maxHealthStat")

	if not leaderstats or not statsFolder or not maxHealthStat then
		print("Missing stats components for " .. player.Name)
		return false
	end

	local level = leaderstats:FindFirstChild("Level")
	local exp = leaderstats:FindFirstChild("EXP")
	local gold = leaderstats:FindFirstChild("Gold")
	local statPoints = statsFolder:FindFirstChild("statPoints")
	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if level and exp and statPoints and damageStat and defenseStat and speedStat then
		-- Reset to default values
		level.Value = DEFAULT_STATS.level
		exp.Value = DEFAULT_STATS.exp
		statPoints.Value = DEFAULT_STATS.statPoints
		maxHealthStat.Value = DEFAULT_STATS.maxHealth
		damageStat.Value = DEFAULT_STATS.damage
		defenseStat.Value = DEFAULT_STATS.defense
		speedStat.Value = DEFAULT_STATS.speed
		gold.Value = DEFAULT_STATS.gold

		-- Reset base stats attributes
		self:SetBaseStats(player, DEFAULT_STATS.damage, DEFAULT_STATS.defense, DEFAULT_STATS.speed)

		print(player.Name .. "'s level and stats have been reset!")
		return true
	end

	return false
end

-- Get player's current stats (useful for other systems)
function StatsManager:GetPlayerStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local statsFolder = player:FindFirstChild("statsFolder")
	local maxHealthStat = player:FindFirstChild("maxHealthStat")

	if not leaderstats or not statsFolder or not maxHealthStat then
		return nil
	end

	return {
		level = leaderstats.Level.Value,
		exp = leaderstats.EXP.Value,
		gold = leaderstats.Gold.Value,
		maxHealth = maxHealthStat.Value,
		statPoints = statsFolder.statPoints.Value,
		damage = statsFolder.damageStat.Value,
		defense = statsFolder.defenseStat.Value,
		speed = statsFolder.speedStat.Value
	}
end

-- IMPROVED: Reset temporary stat effects (for reset scroll)
function StatsManager:ResetTemporaryEffects(player)
	local statsFolder = player:FindFirstChild("statsFolder")
	local character = player.Character

	if not statsFolder or not character then
		return false, "Player components not found"
	end

	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")
	local humanoid = character:FindFirstChild("Humanoid")

	if not damageStat or not defenseStat or not speedStat or not humanoid then
		return false, "Stats or humanoid not found"
	end

	-- Check if there are actually active buffs
	if not self:HasActiveStatBuffs(player) then
		return false, "No active stat effects to remove!"
	end

	-- Get base stats (permanent upgraded values)
	local baseDamage, baseDefense, baseSpeed = self:GetBaseStats(player)

	-- Reset all stats to base values (this preserves permanent upgrades)
	damageStat.Value = baseDamage
	defenseStat.Value = baseDefense
	speedStat.Value = baseSpeed
	humanoid.WalkSpeed = calculateWalkSpeed(baseSpeed)

	--print("🔄 Reset temporary effects for " .. player.Name .. " to base: " .. baseDamage .. "/" .. baseDefense .. "/" .. baseSpeed)

	return true, "All temporary effects removed!"
end

-- NEW: Apply temporary stat buff (for potions/items)
function StatsManager:ApplyStatBuff(player, damageBoost, defenseBoost, speedBoost, duration)
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then
		return false, "Stats folder not found"
	end

	local damageStat = statsFolder:FindFirstChild("damageStat")
	local defenseStat = statsFolder:FindFirstChild("defenseStat")
	local speedStat = statsFolder:FindFirstChild("speedStat")

	if not damageStat or not defenseStat or not speedStat then
		return false, "Stats not found"
	end

	-- Apply the buffs
	damageStat.Value = damageStat.Value + damageBoost
	defenseStat.Value = defenseStat.Value + defenseBoost
	speedStat.Value = speedStat.Value + speedBoost

	print("✨ Applied stat buff to " .. player.Name .. ": +" .. damageBoost .. "/" .. defenseBoost .. "/" .. speedBoost)

	-- If duration is specified, remove the buff after that time
	if duration and duration > 0 then
		task.wait(duration)
		-- Remove the buff
		damageStat.Value = math.max(damageStat.Value - damageBoost, 1)
		defenseStat.Value = math.max(defenseStat.Value - defenseBoost, 1)
		speedStat.Value = math.max(speedStat.Value - speedBoost, 1)
		print("⏰ Stat buff expired for " .. player.Name)
	end

	return true, "Stat buff applied!"
end

-- NEW: Function to check if stats have been modified from default (for admin purposes)
function StatsManager:HasUpgradedStats(player)
	local baseDamage, baseDefense, baseSpeed = self:GetBaseStats(player)
	return baseDamage > DEFAULT_STATS.damage or baseDefense > DEFAULT_STATS.defense or baseSpeed > DEFAULT_STATS.speed
end

-- NEW: Function to get upgrade count for each stat
function StatsManager:GetStatUpgrades(player)
	local baseDamage, baseDefense, baseSpeed = self:GetBaseStats(player)
	return {
		damageUpgrades = baseDamage - DEFAULT_STATS.damage,
		defenseUpgrades = baseDefense - DEFAULT_STATS.defense,
		speedUpgrades = baseSpeed - DEFAULT_STATS.speed
	}
end

return StatsManager