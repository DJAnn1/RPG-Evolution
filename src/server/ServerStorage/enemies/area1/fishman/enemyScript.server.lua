-------------------------------------------
-- FISHMAN ENEMY SCRIPT - UPDATED for Simple Pathfinding
-------------------------------------------

local EnemyPathfinding2 = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players2 = game:GetService("Players")
local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
local RunService2 = game:GetService("RunService")
local Chat2 = game:GetService("Chat")
local PathfindingService2 = game:GetService("PathfindingService")

local enemy2 = script.Parent
local humanoidRootPart2 = enemy2.HumanoidRootPart
local levelSystem2 = require(ReplicatedStorage2:WaitForChild("LevelSystem"))
local DamageService2 = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid2 = enemy2.Humanoid

-- CUSTOMIZABLE FISHMAN CONFIGURATION (aquatic enemy)
local CONFIG2 = {
	-- Basic Stats
	maxHealth = 150,
	walkSpeed = 16,

	-- Combat Settings
	maxDistance = 35,
	touchDamage = 40,
	touchDamageCooldown = 1,
	dashDamage = 25,
	dashCooldown = 8,
	dashRange = {min = 8, max = 30},
	dashSpeed = 50,
	dashDuration = 0.4,

	-- Berserker Mode (aquatic rage)
	berserkerHealthThreshold = 0.25,
	berserkerSpeedMultiplier = 2,
	berserkerDashCooldown = 4,

	-- Wandering Settings
	wanderDistance = 50,
	wanderInterval = 8,
	chatCooldown = 5,

	-- Pathfinding Settings (more aquatic-like movement)
	combatSpeedMultiplier = 1.56, -- 25/16 - fast in combat
	combatRangeMultiplier = 3.5,
	pathUpdateInterval = 2,
	combatPathUpdateInterval = 0.8,
	combatDuration = 8 -- Shorter combat duration, more hit-and-run
}

-- Initialize health
humanoid2.MaxHealth = CONFIG2.maxHealth
humanoid2.Health = CONFIG2.maxHealth

-- Add fishman damage resistance (8% base, increases with aquatic abilities)
local damageResistanceValue2 = Instance.new("NumberValue")
damageResistanceValue2.Name = "DamageResistance"
damageResistanceValue2.Value = 0.08 -- 8% base damage resistance
damageResistanceValue2.Parent = enemy2

local defenseResistanceValue2 = Instance.new("NumberValue")
defenseResistanceValue2.Name = "DefenseResistance"
defenseResistanceValue2.Value = 0.15 -- 15% defense resistance (slippery)
defenseResistanceValue2.Parent = enemy2

-- Message constants (aquatic personality)
local WANDER_MESSAGES2 = {
	"glug glug",
	"blug blug gloob",
	"gubby blubyers",
	"I am hungry for humans."
}
local CHASE_MESSAGE2 = "GLUB BLUUUUBB"
local ATTACK_MESSAGE2 = "glubab geh geh heh"
local LOST_TARGET_MESSAGE2 = "blub glub :("

-- Enemy behavior variables
local deBounce2 = false
local lastDashTime2 = 0
local isPerformingSpecialMove2 = false

-- Wandering variables
local originPoint2 = humanoidRootPart2.Position
local wanderCooldown2 = 0
local lastChatTime2 = 0
local currentState2 = "wandering"
local isWandering2 = false
local wanderPath2 = nil
local wanderWaypointIndex2 = 1
local wanderConnection2 = nil

-- Initialize the simplified pathfinding system
local pathfinding2 = EnemyPathfinding2.new(enemy2, {
	maxDistance = CONFIG2.maxDistance,
	combatMaxDistance = CONFIG2.maxDistance * CONFIG2.combatRangeMultiplier,
	walkSpeed = CONFIG2.walkSpeed,
	combatWalkSpeed = CONFIG2.walkSpeed * CONFIG2.combatSpeedMultiplier,
	pathUpdateInterval = CONFIG2.pathUpdateInterval,
	combatPathUpdateInterval = CONFIG2.combatPathUpdateInterval,
	stuckThreshold = 2.5,
	waypointDistance = 4,
	combatDuration = CONFIG2.combatDuration,
	predictionTime = 0.6
})

-- Enhanced chat system
local function sayMessage2(message)
	if tick() - lastChatTime2 >= CONFIG2.chatCooldown then
		Chat2:Chat(enemy2.Head, message, Enum.ChatColor.Red)
		lastChatTime2 = tick()
	end
end

-- Wandering system functions
local function getRandomWanderPosition2()
	local angle = math.random() * math.pi * 2
	local distance = math.random(10, CONFIG2.wanderDistance)
	return originPoint2 + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
end

local function isWithinWanderBounds2(position)
	return (position - originPoint2).Magnitude <= CONFIG2.wanderDistance
end

local function createWanderPath2(targetPosition)
	local path = PathfindingService2:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 16,
		AgentMaxSlope = 45,
		WaypointSpacing = 8
	})

	local success = pcall(function()
		path:ComputeAsync(humanoidRootPart2.Position, targetPosition)
	end)

	return success and path.Status == Enum.PathStatus.Success and path or nil
end

local function stopWandering2()
	isWandering2 = false
	if wanderConnection2 then
		wanderConnection2:Disconnect()
		wanderConnection2 = nil
	end
	wanderPath2 = nil
	wanderWaypointIndex2 = 1
end

local function startWandering2()
	if isWandering2 or isPerformingSpecialMove2 then return end

	pathfinding2:pauseMovement()
	isWandering2 = true

	local wanderTarget = isWithinWanderBounds2(humanoidRootPart2.Position) 
		and getRandomWanderPosition2() or originPoint2

	wanderPath2 = createWanderPath2(wanderTarget)
	wanderWaypointIndex2 = 1

	if not wanderPath2 then
		humanoid2:MoveTo(wanderTarget)
		task.wait(0.1)
		stopWandering2()
		return
	end

	wanderConnection2 = RunService2.Heartbeat:Connect(function()
		if not isWandering2 or not wanderPath2 then return end

		local waypoints = wanderPath2:GetWaypoints()
		if wanderWaypointIndex2 <= #waypoints then
			local waypoint = waypoints[wanderWaypointIndex2]
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid2.Jump = true
			end
			humanoid2:MoveTo(waypoint.Position)
			if (waypoint.Position - humanoidRootPart2.Position).Magnitude < 6 then
				wanderWaypointIndex2 += 1
			end
		else
			stopWandering2()
		end
	end)

	-- Occasional wander message
	if math.random() > 0.7 then
		sayMessage2(WANDER_MESSAGES2[math.random(1, #WANDER_MESSAGES2)])
	end
end

-- Enhanced touch damage system (higher damage for fishman)
local function setupTouchDamage2()
	local function createTouchHandler2(part)
		return function(hit)
			if deBounce2 or isPerformingSpecialMove2 then return end

			local character = hit.Parent
			if not character or not character:IsA("Model") then return end

			local playerHumanoid = character:FindFirstChild("Humanoid")
			if not playerHumanoid then return end

			local player = Players2:GetPlayerFromCharacter(character)
			if not player then return end

			if playerHumanoid and player and humanoid2.Health > 0 and character ~= enemy2 then
				deBounce2 = true

				if currentState2 ~= "attacking" then
					currentState2 = "attacking"
					sayMessage2(ATTACK_MESSAGE2)
				end

				local actualDamage = CONFIG2.touchDamage + math.random(-3, 5)
				DamageService2:ApplyDamage(player, actualDamage, enemy2)

				-- Force combat mode on touch
				pathfinding2:forceCombatMode()

				task.wait(CONFIG2.touchDamageCooldown)
				deBounce2 = false
			end
		end
	end

	for _, part in pairs(enemy2:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(createTouchHandler2(part))
		end
	end

	enemy2.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			child.Touched:Connect(createTouchHandler2(child))
		end
	end)
end

-- Enhanced dash attack (aquatic lunge)
local function performDash2()
	if isPerformingSpecialMove2 then return end

	local player, distance = pathfinding2:getClosestPlayer()
	if not player or distance > CONFIG2.dashRange.max or distance < CONFIG2.dashRange.min then return end

	isPerformingSpecialMove2 = true
	pathfinding2:pauseMovement()

	humanoid2.WalkSpeed = 0
	task.wait(0.5) -- Brief pause before dash

	local targetPos = player.Character.HumanoidRootPart.Position
	local direction = (targetPos - humanoidRootPart2.Position).Unit

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
	bodyVelocity.Velocity = direction * CONFIG2.dashSpeed
	bodyVelocity.Parent = humanoidRootPart2

	local dashDamageActive = true
	local dashConnection = RunService2.Heartbeat:Connect(function()
		if not dashDamageActive then return end

		local player, distance = pathfinding2:getClosestPlayer()
		if player and distance < 8 then
			DamageService2:ApplyDamage(player, CONFIG2.dashDamage, enemy2)
			dashDamageActive = false
		end
	end)

	task.wait(CONFIG2.dashDuration)
	bodyVelocity:Destroy()
	dashDamageActive = false
	dashConnection:Disconnect()

	task.wait(0.3) -- Recovery time
	isPerformingSpecialMove2 = false
	pathfinding2:resumeMovement()
	lastDashTime2 = tick()
end

-- Enhanced berserker mode (aquatic frenzy)
local function checkBerserkerMode2()
	local healthPercent = humanoid2.Health / humanoid2.MaxHealth
	if healthPercent < CONFIG2.berserkerHealthThreshold then
		-- Increase damage resistance during aquatic frenzy
		damageResistanceValue2.Value = 0.18 -- 18% damage resistance when frenzied

		if not humanoidRootPart2:FindFirstChild("BerserkerEffect") then
			local effect = Instance.new("Fire")
			effect.Name = "BerserkerEffect"
			effect.Size = 3
			effect.Heat = 5
			effect.Color = Color3.new(0, 0.5, 1) -- Blue fire for aquatic theme
			effect.SecondaryColor = Color3.new(0, 0.8, 1)
			effect.Parent = humanoidRootPart2
		end
	else
		-- Reset damage resistance to normal
		damageResistanceValue2.Value = 0.08 -- Back to 8% normal resistance

		local effect = humanoidRootPart2:FindFirstChild("BerserkerEffect")
		if effect then effect:Destroy() end
	end
end

-- Enhanced AI state management
local function updateAIState2()
	local player, distance = pathfinding2:getClosestPlayer()

	if player and distance <= CONFIG2.maxDistance then
		if currentState2 == "wandering" or currentState2 == "lost" then
			currentState2 = "chasing"
			sayMessage2(CHASE_MESSAGE2)
			stopWandering2()
			pathfinding2:resumeMovement()
		end
	else
		if currentState2 == "chasing" or currentState2 == "attacking" then
			currentState2 = "lost"
			sayMessage2(LOST_TARGET_MESSAGE2)
			pathfinding2:pauseMovement()
		elseif currentState2 == "lost" and tick() - lastChatTime2 > 5 then
			currentState2 = "wandering"
		end

		if (currentState2 == "wandering" or currentState2 == "lost") and not isWandering2 then
			if tick() - wanderCooldown2 > CONFIG2.wanderInterval then
				startWandering2()
				wanderCooldown2 = tick()
			end
		end
	end
end

-- Setup systems
setupTouchDamage2()
pathfinding2:startMovement()

-- Main AI loop
task.spawn(function()
	while humanoid2.Health > 0 do
		task.wait(1)
		updateAIState2()
	end
end)

-- Dash attack loop (more frequent for aggressive fishman)
task.spawn(function()
	while humanoid2.Health > 0 do
		task.wait(2)

		if not isPerformingSpecialMove2 and tick() - lastDashTime2 > CONFIG2.dashCooldown then
			local player, distance = pathfinding2:getClosestPlayer()
			if player and distance > 12 and distance < 25 then
				if math.random() > 0.6 then -- 40% chance when in range (more aggressive)
					performDash2()
				end
			end
		end
	end
end)

-- Berserker mode checker
task.spawn(function()
	while humanoid2.Health > 0 do
		task.wait(3)
		checkBerserkerMode2()
	end
end)

-- Special aquatic behavior - occasional burst of speed
task.spawn(function()
	while humanoid2.Health > 0 do
		task.wait(math.random(15, 25)) -- Every 15-25 seconds

		if pathfinding2:isInCombatMode() and not isPerformingSpecialMove2 then
			-- Temporary damage resistance boost during water burst
			local originalResistance = damageResistanceValue2.Value
			damageResistanceValue2.Value = math.min(0.3, originalResistance + 0.1) -- +10% resistance

			-- Visual effect for water burst
			local speedEffect = Instance.new("Sparkles")
			speedEffect.SparkleColor = Color3.new(0, 0.5, 1)
			speedEffect.Parent = humanoidRootPart2

			task.wait(3) -- Water burst lasts 3 seconds

			-- Restore original resistance
			damageResistanceValue2.Value = originalResistance
			speedEffect:Destroy()
		end
	end
end)

-- Cleanup when enemy dies
humanoid2.Died:Connect(function()
	stopWandering2()
	if pathfinding2 then
		pathfinding2:destroy()
	end

	local effect = humanoidRootPart2:FindFirstChild("BerserkerEffect")
	if effect then effect:Destroy() end
end)

-- Make CONFIG globally accessible
_G.FishmanEnemyConfig = CONFIG2