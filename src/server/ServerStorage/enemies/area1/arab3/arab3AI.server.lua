-- desert peasant 2 script - UPDATED for Simple Pathfinding
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")

local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local enemy = script.Parent
local humanoidRootPart = enemy.HumanoidRootPart
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy.Humanoid

-- CUSTOMIZABLE BANDIT 3 CONFIGURATION (weakest of the 3 bandits)
local CONFIG = {
	-- Basic Stats
	maxHealth = 200,
	walkSpeed = 16,

	-- Combat Settings
	maxDistance = 35,
	touchDamage = 15,
	touchDamageCooldown = 1,
	dashDamage = 25,
	dashCooldown = 8,
	dashRange = {min = 8, max = 30},
	dashSpeed = 50,
	dashDuration = 0.4,

	-- Bomb Settings (weakest bombs)
	bombDamage = {min = 50, max = 100},
	bombCooldown = 8,
	bombRange = {min = 5, max = 40},
	bombBlastRadius = 15,
	bombFuseTime = 4,
	bombProximityTrigger = 6,

	-- Berserker Mode (most desperate)
	berserkerHealthThreshold = 0.25,
	berserkerSpeedMultiplier = 2,
	berserkerDashCooldown = 4,
	berserkerBombCooldown = 2,

	-- Wandering Settings
	wanderDistance = 50,
	wanderInterval = 8,
	chatCooldown = 5,

	-- Pathfinding Settings
	combatSpeedMultiplier = 1.25, -- 20/16
	combatRangeMultiplier = 3.5,
	pathUpdateInterval = 2,
	combatPathUpdateInterval = 0.8,
	combatDuration = 12
}

-- Initialize health
humanoid.MaxHealth = CONFIG.maxHealth
humanoid.Health = CONFIG.maxHealth

-- Add damage resistance for desert bandit 2 (12% damage resistance, 8% defense resistance)
local damageResistanceValue = Instance.new("NumberValue")
damageResistanceValue.Name = "DamageResistance"
damageResistanceValue.Value = 0.12 -- 12% damage resistance
damageResistanceValue.Parent = enemy

local defenseResistanceValue = Instance.new("NumberValue")
defenseResistanceValue.Name = "DefenseResistance"
defenseResistanceValue.Value = 0.08 -- 8% defense resistance
defenseResistanceValue.Parent = enemy

-- Message constants (more peaceful personality)
local WANDER_MESSAGES = {
	"Salam Alaykum",
	"where is the chai?",
	"i'm late for work",
	"brother where is my toyota camry?"
}
local CHASE_MESSAGE = "please come back.."
local ATTACK_MESSAGE = "forgive me for this."
local LOST_TARGET_MESSAGE = "please never come back"
local BOMB_MESSAGES = {
	"my king forced me to use this..",
}

-- Enemy behavior variables
local deBounce = false
local lastDashTime = 0
local isPerformingSpecialMove = false
local lastBombTime = 0

-- Wandering variables
local originPoint = humanoidRootPart.Position
local wanderCooldown = 0
local lastWanderMessage = 0
local lastChatTime = 0
local currentState = "wandering"
local isWandering = false
local wanderPath = nil
local wanderWaypointIndex = 1
local wanderConnection = nil

-- Initialize the simplified pathfinding system
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = CONFIG.maxDistance,
	combatMaxDistance = CONFIG.maxDistance * CONFIG.combatRangeMultiplier,
	walkSpeed = CONFIG.walkSpeed,
	combatWalkSpeed = CONFIG.walkSpeed * CONFIG.combatSpeedMultiplier,
	pathUpdateInterval = CONFIG.pathUpdateInterval,
	combatPathUpdateInterval = CONFIG.combatPathUpdateInterval,
	stuckThreshold = 2.5,
	waypointDistance = 4,
	combatDuration = CONFIG.combatDuration,
	predictionTime = 0.5
})

-- Enhanced chat system
local function sayMessage(message)
	if tick() - lastChatTime >= CONFIG.chatCooldown then
		Chat:Chat(enemy.Head, message, Enum.ChatColor.Red)
		lastChatTime = tick()
	end
end

-- Wandering system functions (same as Bandit 1 but configurable)
local function getRandomWanderPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random(10, CONFIG.wanderDistance)
	return originPoint + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
end

local function isWithinWanderBounds(position)
	return (position - originPoint).Magnitude <= CONFIG.wanderDistance
end

local function createWanderPath(targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 16,
		AgentMaxSlope = 45,
		WaypointSpacing = 8
	})

	local success = pcall(function()
		path:ComputeAsync(humanoidRootPart.Position, targetPosition)
	end)

	return success and path.Status == Enum.PathStatus.Success and path or nil
end

local function stopWandering()
	isWandering = false
	if wanderConnection then
		wanderConnection:Disconnect()
		wanderConnection = nil
	end
	wanderPath = nil
	wanderWaypointIndex = 1
end

local function startWandering()
	if isWandering or isPerformingSpecialMove then return end

	pathfinding:pauseMovement()
	isWandering = true

	local wanderTarget = isWithinWanderBounds(humanoidRootPart.Position) 
		and getRandomWanderPosition() or originPoint

	wanderPath = createWanderPath(wanderTarget)
	wanderWaypointIndex = 1

	if not wanderPath then
		humanoid:MoveTo(wanderTarget)
		task.wait(0.1)
		stopWandering()
		return
	end

	wanderConnection = RunService.Heartbeat:Connect(function()
		if not isWandering or not wanderPath then return end

		local waypoints = wanderPath:GetWaypoints()
		if wanderWaypointIndex <= #waypoints then
			local waypoint = waypoints[wanderWaypointIndex]
			local distanceToWaypoint = (waypoint.Position - humanoidRootPart.Position).Magnitude

			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)

			if distanceToWaypoint < 6 then
				wanderWaypointIndex = wanderWaypointIndex + 1
			end
		else
			stopWandering()
		end
	end)

	-- Occasional wander message
	if tick() - lastWanderMessage > 15 and math.random() > 0.7 then
		local randomMessage = WANDER_MESSAGES[math.random(1, #WANDER_MESSAGES)]
		sayMessage(randomMessage)
		lastWanderMessage = tick()
	end
end

-- Enhanced bomb throwing (same logic but configurable damage)
local function throwBomb()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > CONFIG.bombRange.max or distance < CONFIG.bombRange.min then return end

	local char = player.Character
	if not char then return end
	local targetHRP = char:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end

	isPerformingSpecialMove = true
	stopWandering()
	pathfinding:pauseMovement()

	sayMessage(BOMB_MESSAGES[math.random(1, #BOMB_MESSAGES)])

	humanoid.WalkSpeed = 0
	humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, targetHRP.Position)
	task.wait(0.8)

	local bombTemplate = ReplicatedStorage.enemyWeapons.desertWeapons:FindFirstChild("arabBoom")
	if not bombTemplate then
		warn("arabBoom not found!")
		isPerformingSpecialMove = false
		pathfinding:resumeMovement()
		return
	end

	local bomb = bombTemplate:Clone()
	bomb.Name = "ArabBomb"
	bomb.Shape = Enum.PartType.Ball
	bomb.Size = Vector3.new(2, 2, 2)
	bomb.Color = Color3.new(0.1, 0.1, 0.1)
	bomb.Material = Enum.Material.Metal
	bomb.Anchored = false
	bomb.CanCollide = true
	bomb.Massless = false

	local fuse = Instance.new("Fire")
	fuse.Size = 2
	fuse.Heat = 3
	fuse.Color = Color3.new(1, 0.5, 0)
	fuse.SecondaryColor = Color3.new(1, 0, 0)
	fuse.Parent = bomb

	local startPos = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 3 + Vector3.new(0, 5, 0)
	local targetPos = targetHRP.Position
	local targetVelocity = targetHRP.AssemblyLinearVelocity
	local predictedPos = targetPos + (targetVelocity * 0.5)

	bomb.CFrame = CFrame.new(startPos)
	bomb.Parent = workspace

	-- Projectile calculation
	local function calculateProjectileVelocity(startPos, endPos, gravity, desiredTime)
		local displacement = endPos - startPos
		local horizontalDisplacement = Vector3.new(displacement.X, 0, displacement.Z)
		local verticalDisplacement = displacement.Y

		local horizontalVelocity = horizontalDisplacement / desiredTime
		local verticalVelocity = Vector3.new(0, verticalDisplacement / desiredTime + 0.5 * gravity * desiredTime, 0)

		return horizontalVelocity + verticalVelocity
	end

	local gravity = workspace.Gravity
	local desiredTime = 1.1
	local throwVelocity = calculateProjectileVelocity(startPos, predictedPos, gravity, desiredTime)
	bomb.AssemblyLinearVelocity = throwVelocity

	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyAngularVelocity.AngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
	bodyAngularVelocity.Parent = bomb

	-- Explosion logic
	local hasExploded = false
	local function explodeBomb()
		if hasExploded then return end
		hasExploded = true

		local explosion = Instance.new("Explosion")
		explosion.Position = bomb.Position
		explosion.BlastRadius = CONFIG.bombBlastRadius
		explosion.BlastPressure = 0
		explosion.Parent = workspace

		for _, nearbyPlayer in pairs(Players:GetPlayers()) do
			local nearbyChar = nearbyPlayer.Character
			if nearbyChar and nearbyChar:FindFirstChild("HumanoidRootPart") then
				local d = (nearbyChar.HumanoidRootPart.Position - bomb.Position).Magnitude
				if d <= CONFIG.bombBlastRadius then
					local damage = math.max(CONFIG.bombDamage.min, CONFIG.bombDamage.max - (d * 3))
					DamageService:ApplyDamage(nearbyPlayer, damage, enemy)
				end
			end
		end

		bomb:Destroy()
	end

	-- Proximity detection
	task.spawn(function()
		while bomb and bomb.Parent and not hasExploded do
			for _, p in pairs(Players:GetPlayers()) do
				local char = p.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					local dist = (char.HumanoidRootPart.Position - bomb.Position).Magnitude
					if dist <= CONFIG.bombProximityTrigger then
						explodeBomb()
						return
					end
				end
			end
			task.wait(0.1)
		end
	end)

	-- Failsafe timer
	task.delay(CONFIG.bombFuseTime, explodeBomb)

	task.wait(1)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
	lastBombTime = tick()
end

-- Enhanced touch damage system
local function setupTouchDamage()
	local function createTouchHandler(part)
		return function(hit)
			if deBounce or isPerformingSpecialMove then return end

			local character = hit.Parent
			if not character then return end
			local playerHumanoid = character:FindFirstChild("Humanoid")
			local player = Players:GetPlayerFromCharacter(character)

			if playerHumanoid and player and humanoid.Health > 0 and character ~= enemy then
				deBounce = true

				if currentState ~= "attacking" then
					currentState = "attacking"
					sayMessage(ATTACK_MESSAGE)
				end

				local actualDamage = CONFIG.touchDamage + math.random(-3, 5)
				DamageService:ApplyDamage(player, actualDamage, enemy)
				pathfinding:forceCombatMode()

				task.wait(CONFIG.touchDamageCooldown)
				deBounce = false
			end
		end
	end

	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(createTouchHandler(part))
		end
	end

	enemy.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			child.Touched:Connect(createTouchHandler(child))
		end
	end)
end

-- Enhanced dash attack
local function performDash()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > CONFIG.dashRange.max or distance < CONFIG.dashRange.min then return end

	isPerformingSpecialMove = true
	stopWandering()
	pathfinding:pauseMovement()

	humanoid.WalkSpeed = 0
	task.wait(0.5)

	local targetPos = player.Character.HumanoidRootPart.Position
	local direction = (targetPos - humanoidRootPart.Position).Unit

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
	bodyVelocity.Velocity = direction * CONFIG.dashSpeed
	bodyVelocity.Parent = humanoidRootPart

	local dashDamageActive = true
	local dashConnection = RunService.Heartbeat:Connect(function()
		if not dashDamageActive then return end

		local player, distance = pathfinding:getClosestPlayer()
		if player and distance < 8 then
			DamageService:ApplyDamage(player, CONFIG.dashDamage, enemy)
			dashDamageActive = false
		end
	end)

	task.wait(CONFIG.dashDuration)
	bodyVelocity:Destroy()
	dashDamageActive = false
	dashConnection:Disconnect()

	task.wait(0.3)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
	lastDashTime = tick()
end

-- Enhanced berserker mode for Bandit 2
local function checkBerserkerMode()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < CONFIG.berserkerHealthThreshold then
		pathfinding:updateConfig({
			combatWalkSpeed = pathfinding.walkSpeed * CONFIG.berserkerSpeedMultiplier
		})
		CONFIG.dashCooldown = CONFIG.berserkerDashCooldown
		CONFIG.bombCooldown = CONFIG.berserkerBombCooldown

		-- Increase damage resistance when berserking
		damageResistanceValue.Value = 0.22 -- 22% damage resistance when berserking

		if not humanoidRootPart:FindFirstChild("BerserkerEffect") then
			local effect = Instance.new("Fire")
			effect.Name = "BerserkerEffect"
			effect.Size = 5
			effect.Heat = 5
			effect.Parent = humanoidRootPart
		end
	else
		-- Reset damage resistance to normal
		damageResistanceValue.Value = 0.12 -- Back to 12% normal resistance

		local effect = humanoidRootPart:FindFirstChild("BerserkerEffect")
		if effect then effect:Destroy() end
	end
end

-- Enhanced AI state management
local function updateAIState()
	local player, distance = pathfinding:getClosestPlayer()

	if player and distance <= CONFIG.maxDistance then
		if currentState == "wandering" or currentState == "lost" then
			currentState = "chasing"
			sayMessage(CHASE_MESSAGE)
			stopWandering()
			pathfinding:resumeMovement()
		end
	else
		if currentState == "chasing" or currentState == "attacking" then
			currentState = "lost"
			sayMessage(LOST_TARGET_MESSAGE)
			pathfinding:pauseMovement()
		elseif currentState == "lost" and tick() - lastChatTime > 5 then
			currentState = "wandering"
		end

		if (currentState == "wandering" or currentState == "lost") and not isWandering then
			if tick() - wanderCooldown > CONFIG.wanderInterval then
				startWandering()
				wanderCooldown = tick()
			end
		end
	end
end

-- Setup systems
setupTouchDamage()
pathfinding:startMovement()

-- Main AI loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1)
		updateAIState()
	end
end)

-- Dash attack loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2)

		if not isPerformingSpecialMove and tick() - lastDashTime > CONFIG.dashCooldown then
			local player, distance = pathfinding:getClosestPlayer()
			if player and distance > 12 and distance < 25 then
				if math.random() > 0.7 then
					performDash()
				end
			end
		end
	end
end)

-- Bomb throwing loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(3)

		if not isPerformingSpecialMove and tick() - lastBombTime > CONFIG.bombCooldown then
			local player, distance = pathfinding:getClosestPlayer()
			if player and distance > CONFIG.bombRange.min and distance < CONFIG.bombRange.max then
				local inCombat = pathfinding:isInCombatMode()
				local healthPercent = humanoid.Health / humanoid.MaxHealth
				local inBerserker = healthPercent < CONFIG.berserkerHealthThreshold

				if inCombat or inBerserker then
					throwBomb()
				end
			end
		end
	end
end)

-- Berserker mode checker
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(3)
		checkBerserkerMode()
	end
end)

-- Cleanup when enemy dies
humanoid.Died:Connect(function()
	stopWandering()
	if pathfinding then
		pathfinding:destroy()
	end

	local effect = humanoidRootPart:FindFirstChild("BerserkerEffect")
	if effect then effect:Destroy() end
end)

-- CUSTOMIZATION FUNCTIONS
function CONFIG.updateCombatSettings(touchDamage, dashDamage, bombDamage)
	CONFIG.touchDamage = touchDamage or CONFIG.touchDamage
	CONFIG.dashDamage = dashDamage or CONFIG.dashDamage
	if bombDamage then
		CONFIG.bombDamage = bombDamage
	end
end

function CONFIG.updateBombSettings(settings)
	for key, value in pairs(settings) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function CONFIG.updatePathfindingSettings(settings)
	pathfinding:updateConfig(settings)
end

function CONFIG.setBerserkerThreshold(threshold)
	CONFIG.berserkerHealthThreshold = threshold
end

-- Make CONFIG globally accessible
_G.DesertBandit2Config = CONFIG