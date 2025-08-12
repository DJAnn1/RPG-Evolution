-- NOOB ENEMY SCRIPT
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")

local enemy = script.Parent
local humanoidRootPart = enemy.HumanoidRootPart
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy.Humanoid

-- CUSTOMIZABLE NOOB CONFIGURATION (basic enemy)
local CONFIG = {
	-- Basic Stats
	maxHealth = 100,
	walkSpeed = 18,

	-- Combat Settings
	maxDistance = 35,
	touchDamage = 15,
	touchDamageCooldown = 1,
	dashDamage = 25,
	dashCooldown = 8,
	dashRange = {min = 8, max = 30},
	dashSpeed = 50,
	dashDuration = 0.4,

	-- Berserker Mode (simple version)
	berserkerHealthThreshold = 0.25,
	berserkerSpeedMultiplier = 2,
	berserkerDashCooldown = 4,

	-- Wandering Settings
	wanderDistance = 50,
	wanderInterval = 8,
	chatCooldown = 5,

	-- Pathfinding Settings
	combatSpeedMultiplier = 1.22, -- 22/18
	combatRangeMultiplier = 3.5,
	pathUpdateInterval = 2,
	combatPathUpdateInterval = 0.8,
	combatDuration = 12
}

-- Initialize health
humanoid.MaxHealth = CONFIG.maxHealth
humanoid.Health = CONFIG.maxHealth

-- Add minimal damage resistance for noob enemy (5% base damage resistance)
local damageResistanceValue = Instance.new("NumberValue")
damageResistanceValue.Name = "DamageResistance"
damageResistanceValue.Value = 0.05 -- 5% damage resistance (minimal)
damageResistanceValue.Parent = enemy

local defenseResistanceValue = Instance.new("NumberValue")
defenseResistanceValue.Name = "DefenseResistance"
defenseResistanceValue.Value = 0.05 -- 5% defense resistance
defenseResistanceValue.Parent = enemy

-- Message constants (guard personality)
local WANDER_MESSAGES = {
	"i hate guarding for telamon",
	"i wish i could fight someone",
	"i gotta report to the boss in an hour",
	"i am the strongest npc"
}
local CHASE_MESSAGE = "GET EM BOYS!!"
local ATTACK_MESSAGE = "i will solo you"
local LOST_TARGET_MESSAGE = "they always get away..."

-- Enemy behavior variables
local deBounce = false
local lastDashTime = 0
local isPerformingSpecialMove = false

-- Wandering variables
local originPoint = humanoidRootPart.Position
local wanderCooldown = 0
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
		-- Try to find Head first, then HumanoidRootPart, then any BasePart
		local chatPart = enemy:FindFirstChild("Head") 

		if not chatPart then
			chatPart = enemy:FindFirstChild("HumanoidRootPart")
		end

		if not chatPart then
			chatPart = enemy:FindFirstChildOfClass("BasePart")
		end

		if chatPart then
			Chat:Chat(chatPart, message, Enum.ChatColor.Red)
			lastChatTime = tick()
		else
			-- If no suitable part exists, create a temporary invisible head for chat
			local tempHead = Instance.new("Part")
			tempHead.Name = "TempChatHead"
			tempHead.Size = Vector3.new(1, 1, 1)
			tempHead.Transparency = 1
			tempHead.CanCollide = false
			tempHead.Anchored = true
			tempHead.Position = humanoidRootPart.Position + Vector3.new(0, 2, 0)
			tempHead.Parent = enemy

			Chat:Chat(tempHead, message, Enum.ChatColor.Red)

			-- Clean up temp head after a short delay
			game:GetService("Debris"):AddItem(tempHead, 5)
			lastChatTime = tick()
		end
	end
end

-- Wandering system functions
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
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)
			if (waypoint.Position - humanoidRootPart.Position).Magnitude < 6 then
				wanderWaypointIndex += 1
			end
		else
			stopWandering()
		end
	end)

	-- Occasional wander message
	if math.random() > 0.7 then
		sayMessage(WANDER_MESSAGES[math.random(1, #WANDER_MESSAGES)])
	end
end

-- Enhanced touch damage system
local function setupTouchDamage()
	local function createTouchHandler(part)
		return function(hit)
			if deBounce or isPerformingSpecialMove then return end

			local character = hit.Parent
			if not character or not character:IsA("Model") then return end

			local playerHumanoid = character:FindFirstChild("Humanoid")
			if not playerHumanoid then return end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end

			if playerHumanoid and player and humanoid.Health > 0 and character ~= enemy then
				deBounce = true

				if currentState ~= "attacking" then
					currentState = "attacking"
					sayMessage(ATTACK_MESSAGE)
				end

				local actualDamage = CONFIG.touchDamage + math.random(-3, 5)
				DamageService:ApplyDamage(player, actualDamage, enemy)

				-- Force combat mode on touch
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
	pathfinding:pauseMovement()

	humanoid.WalkSpeed = 0
	task.wait(0.5) -- Brief pause before dash

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

	task.wait(0.3) -- Recovery time
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
	lastDashTime = tick()
end

-- Simple berserker mode
local function checkBerserkerMode()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < CONFIG.berserkerHealthThreshold then
		-- Slightly increase damage resistance when berserking
		damageResistanceValue.Value = 0.1 -- 10% damage resistance when berserking

		if not humanoidRootPart:FindFirstChild("BerserkerEffect") then
			local effect = Instance.new("Fire")
			effect.Name = "BerserkerEffect"
			effect.Size = 3
			effect.Heat = 5
			effect.Parent = humanoidRootPart
		end
	else
		-- Reset damage resistance to normal
		damageResistanceValue.Value = 0.05 -- Back to 5% normal resistance

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
				if math.random() > 0.7 then -- 30% chance when in range
					performDash()
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

-- Make CONFIG globally accessible
_G.NoobEnemyConfig = CONFIG