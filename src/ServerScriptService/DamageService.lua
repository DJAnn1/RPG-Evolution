-- Enhanced DamageService.lua with AGGRESSIVE Ranged Counter System - CORRECTED with proper stat resistance system (Place in ServerScriptService)
local DamageService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local damageDealtEvent = ReplicatedStorage:FindFirstChild("damageDealtEvent")
if not damageDealtEvent then
	damageDealtEvent = Instance.new("BindableEvent")
	damageDealtEvent.Name = "damageDealtEvent"
	damageDealtEvent.Parent = ReplicatedStorage
end

-- ENHANCED: More aggressive ranged counter system
local rangedDamageTracking = {}

-- ENHANCED: More sensitive ranged weapon detection
local function isRangedWeaponDamage(player, enemy)
	if not player or not player.Character then return false end

	-- Check player's equipped tool
	local tool = player.Character:FindFirstChildOfClass("Tool")
	if tool then
		local toolName = tool.Name:lower()
		-- Add your ranged weapon names here
		if toolName:find("slingshot") or toolName:find("pellet") or toolName:find("bow") or 
			toolName:find("gun") or toolName:find("crossbow") or toolName:find("launcher") then
			return true, tool
		end
	end

	-- MORE AGGRESSIVE: Lower distance threshold and check player velocity
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 
		enemy and enemy:FindFirstChild("HumanoidRootPart") then
		local distance = (player.Character.HumanoidRootPart.Position - enemy.HumanoidRootPart.Position).Magnitude

		-- If player is more than 15 studs away (reduced from 20), likely ranged
		if distance > 15 then
			-- Also check if player is moving away (kiting behavior)
			local playerVelocity = player.Character.HumanoidRootPart.Velocity
			local directionToPlayer = (player.Character.HumanoidRootPart.Position - enemy.HumanoidRootPart.Position).Unit
			local velocityDotProduct = playerVelocity:Dot(directionToPlayer)

			-- If moving away while attacking, definitely ranged kiting
			if velocityDotProduct > 5 then -- Moving away at decent speed
				return true, "kiting_behavior"
			end

			return true, "distant_attack"
		end
	end

	return false, nil
end

-- ENHANCED: Much more aggressive boss ranged damage tracking
local function handleBossRangedDamage(player, enemy, weaponInfo)
	if not enemy or not enemy:FindFirstChild("HumanoidRootPart") then return end

	-- Only track for bosses
	local isBoss = enemy.Name:lower():find("boss") or 
		enemy:FindFirstChild("DamageResistance") or 
		enemy:FindFirstChild("DefenseResistance")

	if not isBoss then return end

	local enemyId = tostring(enemy)
	local currentTime = tick()

	-- Initialize tracking for this enemy if needed
	if not rangedDamageTracking[enemyId] then
		rangedDamageTracking[enemyId] = {
			hitCount = 0,
			lastHitTime = 0,
			hitWindow = 12, -- INCREASED: Longer memory window
			counterThreshold = 2, -- REDUCED: Trigger much faster (was 4)
			lastCounterTime = 0,
			counterCooldown = 6, -- REDUCED: More frequent counters (was 12)
			totalRangedDamage = 0,
			kiteCount = 0, -- Track kiting behavior
			lastPlayerPosition = nil
		}
	end

	local tracking = rangedDamageTracking[enemyId]

	-- LESS FORGIVING: Only reset if MUCH more time has passed
	if currentTime - tracking.lastHitTime > tracking.hitWindow then
		tracking.hitCount = math.max(0, tracking.hitCount - 1) -- Decay slower
		tracking.kiteCount = math.max(0, tracking.kiteCount - 1)
	end

	-- Track player position for kiting detection
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local currentPos = player.Character.HumanoidRootPart.Position
		if tracking.lastPlayerPosition then
			local movement = (currentPos - tracking.lastPlayerPosition).Magnitude
			if movement > 10 then -- Player moved significantly while attacking
				tracking.kiteCount = tracking.kiteCount + 1
			end
		end
		tracking.lastPlayerPosition = currentPos
	end

	-- Increment hit count MORE AGGRESSIVELY
	tracking.hitCount = tracking.hitCount + 1
	tracking.lastHitTime = currentTime
	tracking.totalRangedDamage = tracking.totalRangedDamage + 1

	-- MUCH MORE AGGRESSIVE: Multiple trigger conditions
	local shouldTriggerCounter = false
	local counterType = "rock"

	if tracking.hitCount >= tracking.counterThreshold and 
		currentTime - tracking.lastCounterTime > tracking.counterCooldown then
		shouldTriggerCounter = true
		counterType = "rock"
	end

	-- SPECIAL: Kiting behavior triggers acid spit
	if tracking.kiteCount >= 2 or weaponInfo == "kiting_behavior" then
		shouldTriggerCounter = true
		counterType = "acid"
		tracking.kiteCount = 0 -- Reset kite counter
	end

	-- ESCALATION: More hits = more aggressive responses
	if tracking.hitCount >= 5 then
		shouldTriggerCounter = true
		counterType = "barrage"
	end

	if shouldTriggerCounter then
		tracking.hitCount = 0 -- Reset counter
		tracking.lastCounterTime = currentTime

		-- Send ranged counter signal to boss
		local bossScript = enemy:FindFirstChild("BossScript") or enemy:FindFirstChild("ZombieBoss") or script.Parent
		if bossScript then
			local counterEvent = bossScript:FindFirstChild("RangedCounterEvent")
			if not counterEvent then
				counterEvent = Instance.new("BindableEvent")
				counterEvent.Name = "RangedCounterEvent"
				counterEvent.Parent = bossScript
			end
			counterEvent:Fire(player, weaponInfo, counterType)
		end

		-- Set trigger values with counter type
		local counterTrigger = enemy:FindFirstChild("RangedCounterTrigger")
		if not counterTrigger then
			counterTrigger = Instance.new("StringValue") -- Changed to StringValue for counter type
			counterTrigger.Name = "RangedCounterTrigger"
			counterTrigger.Value = ""
			counterTrigger.Parent = enemy
		end
		counterTrigger.Value = counterType

		-- Store player reference
		local targetPlayer = enemy:FindFirstChild("RangedCounterTarget")
		if not targetPlayer then
			targetPlayer = Instance.new("ObjectValue")
			targetPlayer.Name = "RangedCounterTarget"
			targetPlayer.Parent = enemy
		end
		targetPlayer.Value = player

		-- Reset trigger after short delay
		task.spawn(function()
			task.wait(0.1)
			counterTrigger.Value = ""
		end)

		print("🎯 AGGRESSIVE Boss ranged counter triggered: " .. counterType .. " for " .. enemy.Name .. " against " .. player.Name)
		print("   Hit count: " .. (tracking.hitCount + 1) .. ", Kite count: " .. tracking.kiteCount)
	else
		-- Warning messages for building anger
		if tracking.hitCount >= 1 then
			print("⚠️ Boss anger building: " .. tracking.hitCount .. "/" .. tracking.counterThreshold .. " (Kites: " .. tracking.kiteCount .. ")")
		end
	end
end

-- Function to get enemy's damage resistance (ignores % of player's damage stat)
local function getEnemyDamageResistance(enemy)
	if not enemy then return 0 end

	-- Check for new DamageResistance NumberValue
	local damageResistance = enemy:FindFirstChild("DamageResistance")
	if damageResistance and damageResistance:IsA("NumberValue") then
		-- Clamp between 0 and 1 (0% to 100% resistance)
		return math.clamp(damageResistance.Value, 0, 1)
	end

	return 0 -- Default: no damage resistance
end

-- Function to get enemy's defense resistance (ignores % of player's defense stat)
local function getEnemyDefenseResistance(enemy)
	if not enemy then return 0 end

	-- Check for new DefenseResistance NumberValue
	local defenseResistance = enemy:FindFirstChild("DefenseResistance")
	if defenseResistance and defenseResistance:IsA("NumberValue") then
		-- Clamp between 0 and 1 (0% to 100% resistance)
		return math.clamp(defenseResistance.Value, 0, 1)
	end

	return 0 -- Default: no defense resistance
end

-- FIXED: Apply damage to player (with enemy defense resistance)
function DamageService:ApplyDamage(player, baseDamage, enemy)
	if not player or not player:IsA("Player") then
		return false, "Invalid player"
	end

	local statsFolder = player:FindFirstChild("statsFolder")
	local defenseStat = statsFolder and statsFolder:FindFirstChild("defenseStat")
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")

	if not humanoid then
		return false, "No humanoid found"
	end

	if humanoid and defenseStat then
		-- Get player's actual defense stat
		local playerDefenseStat = defenseStat.Value

		-- Apply enemy's defense resistance (enemy ignores % of player's defense)
		local enemyDefenseResistance = getEnemyDefenseResistance(enemy)
		local effectiveDefenseStat = playerDefenseStat * (1 - enemyDefenseResistance)

		-- Use effective defense stat in damage reduction calculation
		local scale = 0.07
		local baseReduction = 1 - 1 / (1 + effectiveDefenseStat * scale)
		local effectiveness = 1

		-- Handle old defenseEffectiveness system (deprecated)
		if enemy and enemy:FindFirstChild("defenseEffectiveness") then
			enemy.defenseEffectiveness:Destroy()
		end

		local adjustedReduction = baseReduction * effectiveness
		adjustedReduction = math.clamp(adjustedReduction, 0, 0.9)
		local finalDamage = baseDamage * (1 - adjustedReduction)

		humanoid:TakeDamage(finalDamage)

		return true, {
			finalDamage = finalDamage,
			damageReduction = adjustedReduction,
			effectiveDefenseStat = effectiveDefenseStat,
			defenseResistance = enemyDefenseResistance
		}
	elseif humanoid then
		-- No defense stat, apply raw damage
		humanoid:TakeDamage(baseDamage)
		return true, {finalDamage = baseDamage, damageReduction = 0}
	end

	return false, "Unknown error"
end

-- ENHANCED: Apply damage from player to enemy (with enemy damage resistance + AGGRESSIVE ranged tracking)
function DamageService:ApplyPlayerDamageToEnemy(player, baseDamage, enemy)
	if not player or not player:IsA("Player") then
		return false, "Invalid player"
	end

	if not enemy or not enemy:IsA("Model") then
		return false, "Invalid enemy"
	end

	-- ENHANCED: Check for ranged weapon damage and track it AGGRESSIVELY
	local isRanged, weaponInfo = isRangedWeaponDamage(player, enemy)
	if isRanged then
		handleBossRangedDamage(player, enemy, weaponInfo)
	end

	-- Get player's damage stat
	local playerDamageStat = 1
	local statsFolder = player:FindFirstChild("statsFolder")
	if statsFolder then
		local damageStat = statsFolder:FindFirstChild("damageStat")
		if damageStat then
			playerDamageStat = damageStat.Value
		end
	end

	-- Get enemy's humanoid
	local enemyHumanoid = enemy and enemy:FindFirstChild("Humanoid")
	if not enemyHumanoid then
		return false, "Enemy has no humanoid"
	end

	if enemyHumanoid.Health <= 0 then
		return false, "Enemy is dead"
	end

	-- Apply enemy's damage resistance (enemy ignores % of player's damage stat)
	local enemyDamageResistance = getEnemyDamageResistance(enemy)
	local effectiveDamageStat = playerDamageStat * (1 - enemyDamageResistance)

	-- Calculate damage boost from EFFECTIVE damage stat
	-- Each damage point increases damage by 15%
	local damageMultiplier = 1 + ((effectiveDamageStat - 1) * 0.15)
	local finalDamage = baseDamage * damageMultiplier

	-- Ensure minimum damage
	finalDamage = math.max(finalDamage, 1)

	-- Apply the damage
	enemyHumanoid:TakeDamage(finalDamage)

	if player and player.Parent then
		damageDealtEvent:Fire(player)
	end

	-- Fire damage event for UI/effects if it exists
	local damageEvent = ReplicatedStorage:FindFirstChild("DamageEvent")
	if damageEvent then
		local damageInfo = {
			baseDamage = baseDamage,
			finalDamage = finalDamage,
			effectiveDamageStat = effectiveDamageStat,
			damageResistance = enemyDamageResistance,
			attackerDamage = playerDamageStat,
			isRangedAttack = isRanged,
			weaponInfo = weaponInfo
		}
		damageEvent:FireAllClients(enemy, finalDamage, damageInfo)
	end

	return true, {
		finalDamage = finalDamage,
		effectiveDamageStat = effectiveDamageStat,
		damageResistance = enemyDamageResistance,
		damageBoost = finalDamage - baseDamage,
		isRangedAttack = isRanged
	}
end

-- NEW FUNCTION: Get damage preview for UI
function DamageService:PreviewPlayerDamageToEnemy(player, baseDamage, enemy)
	if not player or not enemy then
		return baseDamage
	end

	-- Get player's damage stat
	local playerDamageStat = 1
	local statsFolder = player:FindFirstChild("statsFolder")
	if statsFolder then
		local damageStat = statsFolder:FindFirstChild("damageStat")
		if damageStat then
			playerDamageStat = damageStat.Value
		end
	end

	-- Apply enemy's damage resistance
	local enemyDamageResistance = getEnemyDamageResistance(enemy)
	local effectiveDamageStat = playerDamageStat * (1 - enemyDamageResistance)

	-- Calculate boosted damage
	local damageMultiplier = 1 + ((effectiveDamageStat - 1) * 0.15)
	local finalDamage = baseDamage * damageMultiplier

	return math.max(finalDamage, 1)
end

-- UTILITY FUNCTION: Apply damage with custom resistance (for special abilities)
function DamageService:ApplyDamageWithCustomResistance(target, baseDamage, attacker, customDamageResistance, customDefenseResistance)
	-- Temporarily set custom resistances if provided
	local originalDamageResistance = nil
	local originalDefenseResistance = nil
	local damageResistanceValue = nil
	local defenseResistanceValue = nil

	if target:IsA("Model") then
		-- Handle damage resistance
		if customDamageResistance then
			damageResistanceValue = target:FindFirstChild("DamageResistance")
			if damageResistanceValue then
				originalDamageResistance = damageResistanceValue.Value
				damageResistanceValue.Value = customDamageResistance
			else
				damageResistanceValue = Instance.new("NumberValue")
				damageResistanceValue.Name = "DamageResistance"
				damageResistanceValue.Value = customDamageResistance
				damageResistanceValue.Parent = target
			end
		end

		-- Handle defense resistance
		if customDefenseResistance then
			defenseResistanceValue = target:FindFirstChild("DefenseResistance")
			if defenseResistanceValue then
				originalDefenseResistance = defenseResistanceValue.Value
				defenseResistanceValue.Value = customDefenseResistance
			else
				defenseResistanceValue = Instance.new("NumberValue")
				defenseResistanceValue.Name = "DefenseResistance"
				defenseResistanceValue.Value = customDefenseResistance
				defenseResistanceValue.Parent = target
			end
		end
	end

	-- Apply damage using appropriate function
	local success, result
	if attacker:IsA("Player") and target:IsA("Model") then
		success, result = self:ApplyPlayerDamageToEnemy(attacker, baseDamage, target)
	else
		-- Use original function for enemy-to-player damage
		success, result = self:ApplyDamage(target, baseDamage, attacker)
	end

	-- Restore original resistances
	if originalDamageResistance and damageResistanceValue then
		damageResistanceValue.Value = originalDamageResistance
	elseif customDamageResistance and damageResistanceValue and not originalDamageResistance then
		damageResistanceValue:Destroy()
	end

	if originalDefenseResistance and defenseResistanceValue then
		defenseResistanceValue.Value = originalDefenseResistance
	elseif customDefenseResistance and defenseResistanceValue and not originalDefenseResistance then
		defenseResistanceValue:Destroy()
	end

	return success, result
end

-- ENHANCED: Auto-detect damage direction and use appropriate function
function DamageService:SmartApplyDamage(source, target, baseDamage)
	local sourcePlayer = nil
	local targetPlayer = nil
	local targetEnemy = nil
	local sourceEnemy = nil

	-- Determine source type
	if source:IsA("Player") then
		sourcePlayer = source
	elseif source:IsA("Model") and source:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(source) then
		sourceEnemy = source
	end

	-- Determine target type
	if target:IsA("Player") then
		targetPlayer = target
	elseif target:IsA("Model") and target:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(target) then
		targetEnemy = target
	end

	-- Route to appropriate function
	if sourcePlayer and targetEnemy then
		-- Player attacking enemy - use damage resistance system
		return self:ApplyPlayerDamageToEnemy(sourcePlayer, baseDamage, targetEnemy)
	elseif (sourceEnemy or source) and targetPlayer then
		-- Enemy attacking player - use defense resistance system
		return self:ApplyDamage(targetPlayer, baseDamage, sourceEnemy or source)
	else
		-- Fallback - try to determine from the target
		if target:IsA("Player") then
			return self:ApplyDamage(target, baseDamage, source)
		else
			return false, "Unable to determine damage routing"
		end
	end
end

-- NEW: Cleanup function for when enemies are destroyed
function DamageService:CleanupRangedTracking(enemy)
	if enemy then
		local enemyId = tostring(enemy)
		rangedDamageTracking[enemyId] = nil
	end
end

return DamageService