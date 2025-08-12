-- ENHANCED ZOMBIE ENEMY SCRIPT - More zombie-like behavior
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local enemy = script.Parent
local humanoidRootPart = enemy.HumanoidRootPart
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy.Humanoid
humanoid.MaxHealth = 850
humanoid.Health = 850

local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")

-- Create temporary transparent head if missing
local zombieHead = enemy:FindFirstChild("Head")
if not zombieHead then
	zombieHead = Instance.new("Part")
	zombieHead.Name = "Head"
	zombieHead.Size = Vector3.new(2, 1, 1)
	zombieHead.Transparency = 1 -- Completely transparent
	zombieHead.CanCollide = false
	zombieHead.Material = Enum.Material.ForceField

	-- Position above torso
	local torso = enemy:FindFirstChild("Torso") or enemy:FindFirstChild("UpperTorso")
	if torso then
		zombieHead.Position = torso.Position + Vector3.new(0, 2, 0)
	else
		zombieHead.Position = humanoidRootPart.Position + Vector3.new(0, 2, 0)
	end

	-- Weld to torso/humanoidrootpart
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = zombieHead
	weld.Part1 = torso or humanoidRootPart
	weld.Parent = zombieHead

	zombieHead.Parent = enemy

	-- Set humanoid head reference
	if humanoid then
		-- Create a basic head configuration
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = zombieHead
	end
end

-- Enhanced damage resistance for zombies
local damageResistanceValue = Instance.new("NumberValue")
damageResistanceValue.Name = "DamageResistance"
damageResistanceValue.Value = 0.15 -- 15% damage resistance
damageResistanceValue.Parent = enemy

local defenseResistanceValue = Instance.new("NumberValue")
defenseResistanceValue.Name = "DefenseResistance"
defenseResistanceValue.Value = 0.25 -- 25% defense resistance
defenseResistanceValue.Parent = enemy

-- Zombie behavior variables
local originPoint = humanoidRootPart.Position
local maxWanderDistance = 40
local wanderCooldown = 0
local lastChatTime = 0
local chatCooldown = 3
local currentState = "wandering"
local isWandering = false
local wanderPath = nil
local wanderWaypointIndex = 1
local wanderConnection = nil
local lastGroanTime = 0

-- Enhanced zombie messages
local WANDER_MESSAGES = {
	"grrraaahhhhh...",
	"braaaaainsss...",
	"huuuungryyyy...",
	"raaawwwrrr...",
	"grrrrr...",
	"hhhhunnngggg..."
}

local CHASE_MESSAGES = {
	"BRAAAIIINNNSSS!!!",
	"HUUUMANNNN!!!",
	"FEEEEEDDD!!!",
	"RAAAAWWWRRR!!!"
}

local ATTACK_MESSAGE = "DIIIIEEEE!!!"
local LOST_TARGET_MESSAGE = "wheeerrreee..."

local maxDistance = 40
local deBounce = false
local lastLungeTime = 0
local lungeCooldown = 12
local isPerformingSpecialMove = false
local lastStumbleTime = 0

-- More zombie-like pathfinding settings
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = maxDistance,
	combatMaxDistance = maxDistance * 2.5,
	walkSpeed = 12, -- Slower, more zombie-like
	combatWalkSpeed = 20, -- Faster when chasing
	pathUpdateInterval = 3, -- Less frequent updates for smoother movement
	combatPathUpdateInterval = 1.2,
	stuckThreshold = 3,
	waypointDistance = 6,
	combatDuration = 15,
	predictionTime = 0.8
})

-- Add zombie-like stumbling animation
local function addZombieWalk()
	local stumbleInfo = TweenInfo.new(
		0.8,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)

	local leftShoulder = enemy:FindFirstChild("Left Shoulder")
	local rightShoulder = enemy:FindFirstChild("Right Shoulder")

	if leftShoulder and rightShoulder then
		local leftTween = TweenService:Create(leftShoulder, stumbleInfo, {C0 = leftShoulder.C0 * CFrame.Angles(0, 0, math.rad(15))})
		local rightTween = TweenService:Create(rightShoulder, stumbleInfo, {C0 = rightShoulder.C0 * CFrame.Angles(0, 0, math.rad(-15))})
		leftTween:Play()
		rightTween:Play()
	end
end

local function sayMessage(messageTable)
	if tick() - lastChatTime >= chatCooldown then
		local message = messageTable
		if type(messageTable) == "table" then
			message = messageTable[math.random(1, #messageTable)]
		end

		-- Safety check for head
		if zombieHead and zombieHead.Parent then
			Chat:Chat(zombieHead, message, Enum.ChatColor.Red)
			lastChatTime = tick()
		end
	end
end

-- Random groaning while idle
local function randomGroan()
	if tick() - lastGroanTime >= 8 and currentState == "wandering" then
		if math.random() > 0.6 then
			sayMessage(WANDER_MESSAGES)
			lastGroanTime = tick()
		end
	end
end

-- Enhanced touch damage with zombie bite effect
local function setupTouchDamage()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
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

					-- Stronger zombie damage
					local baseDamage = 80
					local actualDamage = baseDamage + math.random(-5, 8)

					-- Chance for critical bite
					if math.random() > 0.8 then
						actualDamage = actualDamage * 1.5
						sayMessage("CRIIITICAL BITE!!!")
					end

					DamageService:ApplyDamage(player, actualDamage, enemy)

					-- Zombie bite effect - brief stun
					if playerHumanoid then
						local originalWalkSpeed = playerHumanoid.WalkSpeed
						playerHumanoid.WalkSpeed = originalWalkSpeed * 0.3
						task.wait(0.8)
						playerHumanoid.WalkSpeed = originalWalkSpeed
					end

					task.wait(1.2)
					deBounce = false
				end    
			end)
		end
	end

	-- Handle new parts
	enemy.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			child.Touched:Connect(function(hit)
				if deBounce or isPerformingSpecialMove then return end

				local character = hit.Parent
				local playerHumanoid = character:FindFirstChild("Humanoid")
				local player = Players:GetPlayerFromCharacter(character)

				if playerHumanoid and player and humanoid.Health > 0 and character ~= enemy then
					deBounce = true
					local baseDamage = 28
					local actualDamage = baseDamage + math.random(-5, 8)

					if math.random() > 0.8 then
						actualDamage = actualDamage * 1.5
					end

					DamageService:ApplyDamage(player, actualDamage, enemy)

					task.wait(1.2)
					deBounce = false
				end    
			end)
		end
	end)
end

-- Zombie lunge attack (improved dash)
local function performLunge()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 35 or distance < 6 then return end

	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	sayMessage("LUUUUUNGE!!!")

	-- Crouch before lunge
	humanoid.WalkSpeed = 0
	local crouchTween = TweenService:Create(humanoidRootPart, TweenInfo.new(0.6), {CFrame = humanoidRootPart.CFrame * CFrame.new(0, -1, 0)})
	crouchTween:Play()
	task.wait(0.8)

	-- Perform the lunge
	local targetPos = player.Character.HumanoidRootPart.Position
	local direction = (targetPos - humanoidRootPart.Position).Unit

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e4, 1e5)
	bodyVelocity.Velocity = direction * 65 + Vector3.new(0, 15, 0) -- Add upward force
	bodyVelocity.Parent = humanoidRootPart

	-- Enhanced lunge damage
	local lungeDamageActive = true
	local lungeConnection
	lungeConnection = RunService.Heartbeat:Connect(function()
		if not lungeDamageActive then
			lungeConnection:Disconnect()
			return
		end

		local player, distance = pathfinding:getClosestPlayer()
		if player and distance < 10 then
			DamageService:ApplyDamage(player, 45, enemy)
			sayMessage("GOTCHA!!!")
			lungeDamageActive = false
		end
	end)

	-- Stop lunge
	task.wait(0.6)
	bodyVelocity:Destroy()
	lungeDamageActive = false

	-- Recover from lunge
	local recoverTween = TweenService:Create(humanoidRootPart, TweenInfo.new(0.4), {CFrame = humanoidRootPart.CFrame * CFrame.new(0, 1, 0)})
	recoverTween:Play()
	task.wait(0.5)

	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
	lastLungeTime = tick()
end

-- Enhanced berserker mode
local function checkBerserkerMode()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < 0.3 then
		-- Berserker zombie is faster and more aggressive
		pathfinding:updateConfig({
			combatWalkSpeed = 28,
			walkSpeed = 16
		})
		lungeCooldown = 6
		chatCooldown = 1.5

		-- Higher damage resistance when berserking
		damageResistanceValue.Value = 0.25

		-- Enhanced berserker effects
		if not humanoidRootPart:FindFirstChild("BerserkerEffect") then
			local effect = Instance.new("Fire")
			effect.Name = "BerserkerEffect"
			effect.Size = 4
			effect.Heat = 8
			effect.Color = Color3.new(0.8, 0, 0)
			effect.Parent = humanoidRootPart

			-- Add smoke effect
			local smoke = Instance.new("Smoke")
			smoke.Name = "BerserkerSmoke"
			smoke.Size = 6
			smoke.Color = Color3.new(0.3, 0.3, 0.3)
			smoke.Parent = humanoidRootPart
		end

		-- Berserker sounds
		if math.random() > 0.7 then
			sayMessage("RAAAAGGGGEEE!!!")
		end
	else
		damageResistanceValue.Value = 0.15
		lungeCooldown = 12
		chatCooldown = 3

		-- Remove berserker effects
		local effect = humanoidRootPart:FindFirstChild("BerserkerEffect")
		if effect then effect:Destroy() end
		local smoke = humanoidRootPart:FindFirstChild("BerserkerSmoke")
		if smoke then smoke:Destroy() end
	end
end

-- Rest of the wandering and AI logic (similar to original but with tweaks)
local function getRandomWanderPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random(15, maxWanderDistance)
	return originPoint + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
end

local function isWithinWanderBounds(position)
	return (position - originPoint).Magnitude <= maxWanderDistance
end

local function createWanderPath(targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 16,
		AgentMaxSlope = 45,
		WaypointSpacing = 10
	})

	local success = pcall(function()
		path:ComputeAsync(humanoidRootPart.Position, targetPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		return path
	end
	return nil
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

	local wanderTarget
	if not isWithinWanderBounds(humanoidRootPart.Position) then
		wanderTarget = originPoint
	else
		wanderTarget = getRandomWanderPosition()
	end

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
			if (waypoint.Position - humanoidRootPart.Position).Magnitude < 8 then
				wanderWaypointIndex += 1
			end
		else
			stopWandering()
		end
	end)
end

local function updateAIState()
	local player, distance = pathfinding:getClosestPlayer()

	if player and distance <= maxDistance then
		if currentState == "wandering" or currentState == "lost" then
			currentState = "chasing"
			sayMessage(CHASE_MESSAGES)
			stopWandering()
			pathfinding:resumeMovement()
		end
	else
		if currentState == "chasing" or currentState == "attacking" then
			currentState = "lost"
			sayMessage(LOST_TARGET_MESSAGE)
			pathfinding:pauseMovement()
		elseif currentState == "lost" and tick() - lastChatTime > 6 then
			currentState = "wandering"
		end

		if (currentState == "wandering" or currentState == "lost") and not isWandering then
			if tick() - wanderCooldown > 10 then
				startWandering()
				wanderCooldown = tick()
			end
		end
	end

	-- Random groaning
	randomGroan()
end

-- Setup systems
setupTouchDamage()
pathfinding:startMovement()
addZombieWalk() -- Add zombie-like movement

-- Lunge attack loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(3)

		if not isPerformingSpecialMove and tick() - lastLungeTime > lungeCooldown then
			local player, distance = pathfinding:getClosestPlayer()
			if player and distance > 15 and distance < 30 then
				if math.random() > 0.6 then
					performLunge()
				end
			end
		end
	end
end)

-- Berserker mode checker
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(4)
		checkBerserkerMode()
	end
end)

-- Main AI loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1.5)
		updateAIState()
	end
end)

-- Cleanup when enemy dies
humanoid.Died:Connect(function()
	sayMessage("NOOOOOO!!!")

	if pathfinding then
		pathfinding:destroy()
	end

	-- Clean up effects
	local effect = humanoidRootPart:FindFirstChild("BerserkerEffect")
	if effect then effect:Destroy() end
	local smoke = humanoidRootPart:FindFirstChild("BerserkerSmoke")
	if smoke then smoke:Destroy() end

	-- Clean up temporary head
	if zombieHead and zombieHead.Parent then
		zombieHead:Destroy()
	end
end)