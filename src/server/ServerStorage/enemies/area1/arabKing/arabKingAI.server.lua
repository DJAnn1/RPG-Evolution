-- Enhanced Arab King script with improved accuracy, smoother movement, and cooler features
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local enemy = script.Parent
local humanoidRootPart = enemy:WaitForChild("HumanoidRootPart")
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy:WaitForChild("Humanoid")
humanoid.MaxHealth = 2500
humanoid.Health = 2500

-- Enhanced visual effects
local function createAura()
	local aura = Instance.new("SelectionBox")
	aura.Name = "KingAura"
	aura.Adornee = humanoidRootPart
	aura.Color3 = Color3.new(1, 0.8, 0)
	aura.LineThickness = 0.2
	aura.Transparency = 0.7
	aura.Parent = humanoidRootPart

	-- Pulsing aura effect
	local pulseTween = TweenService:Create(aura, 
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Transparency = 0.3, LineThickness = 0.4}
	)
	pulseTween:Play()
end

createAura()

local damageResistanceValue = Instance.new("NumberValue")
damageResistanceValue.Name = "DamageResistance"
damageResistanceValue.Value = 0.4 -- 40% base damage resistance (boss-level)
damageResistanceValue.Parent = enemy

local defenseResistanceValue = Instance.new("NumberValue")
defenseResistanceValue.Name = "DefenseResistance"
defenseResistanceValue.Value = 0.4 -- 40% defense resistance
defenseResistanceValue.Parent = enemy

-- Enhanced message constants with more personality
local WANDER_MESSAGES = {
	"Salam Alaykum, my subjects...",
	"Where is the finest chai in the land?",
	"My kingdom thirsts for excellence...",
	"Brother, where is my golden chariot?",
	"The desert whispers of great treasures..."
}
local CHASE_MESSAGE = "YOU CANNOT ESCAPE THE WRATH OF THE KING!"
local ATTACK_MESSAGE = "KNEEL BEFORE YOUR SOVEREIGN!"
local LOST_TARGET_MESSAGE = "Wise choice... flee while you still can."
local BOMB_MESSAGES = {
	"BEHOLD THE KING'S EXPLOSIVE DECREE!",
	"TASTE THE FIRE OF A THOUSAND SUNS!",
	"THE DESERT'S FURY INCARNATE!"
}
local GUN_MESSAGES = {
	"THE ROYAL ARSENAL NEVER MISSES!",
	"BULLETS OF PURE GOLD AND FURY!",
	"WITNESS THE KING'S MARKSMANSHIP!"
}

-- Enemy behavior variables
local maxDistance = 45
local baseMaxDistance = 45
local maxPossibleDistance = 120
local deBounce = false
local lastDashTime = 0
local dashCooldown = 6
local isPerformingSpecialMove = false
local lastBombTime = 0
local bombCooldown = 5 -- Reduced for more aggressive gameplay
local lastGunTime = 0
local gunCooldown = 6 -- Reduced for more aggressive gameplay
local lastDodgeTime = 0
local dodgeCooldown = 4
local isAttacking = false
local hasSpawnedMinions = false
local lastDamageTime = 0
local rangeBoostDuration = 15

-- Enhanced movement smoothing variables
local movementSmoothing = true
local lastTargetPosition = Vector3.new(0, 0, 0)
local movementLerpAlpha = 0.15

-- Wandering variables
local originPoint = humanoidRootPart.Position
local maxWanderDistance = 15
local wanderCooldown = 5
local lastWanderMessage = 0
local lastChatTime = 0
local chatCooldown = 4
local currentState = "wandering"
local isWandering = false
local wanderPath = nil
local wanderWaypointIndex = 1
local wanderConnection = nil

-- Enhanced prediction system
local playerMovementHistory = {}
local MAX_HISTORY_SIZE = 20 -- Increased for better prediction
local PREDICTION_SAMPLES = 8

-- Initialize the enhanced pathfinding system
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = maxDistance,
	combatMaxDistance = maxDistance * 10,
	walkSpeed = 16, -- Slightly reduced for smoother movement
	combatWalkSpeed = 24, -- Slightly reduced for smoother movement
	pathUpdateInterval = 1.2, -- Slightly increased for less jitter
	combatPathUpdateInterval = 0.8, -- Slightly increased for less jitter
	stuckThreshold = 2.0,
	waypointDistance = 4, -- Increased for smoother pathfinding
	combatDuration = 60,
	predictionTime = 0.8 -- Increased for better prediction
})

-- Enhanced message system with cooldowns
local function sayMessage(message, priority)
	priority = priority or 1
	local cooldownTime = priority == 1 and chatCooldown or (chatCooldown * 0.5)

	if tick() - lastChatTime >= cooldownTime then
		local head = enemy:FindFirstChild("Head")
		if head then
			Chat:Chat(head, message, Enum.ChatColor.Red)

			-- Add dramatic pause effect
			if priority == 1 then
				local originalSpeed = humanoid.WalkSpeed
				humanoid.WalkSpeed = originalSpeed * 0.3
				task.wait(0.6)
				humanoid.WalkSpeed = originalSpeed
			end
		end
		lastChatTime = tick()
	end
end

-- Enhanced movement prediction system
local function updatePlayerMovementTracking()
	local player, distance = pathfinding:getClosestPlayer()
	if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local currentPos = player.Character.HumanoidRootPart.Position
		local currentTime = tick()

		-- Add to history with timestamp
		table.insert(playerMovementHistory, {
			position = currentPos,
			time = currentTime,
			velocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
		})

		-- Keep only recent history
		while #playerMovementHistory > MAX_HISTORY_SIZE do
			table.remove(playerMovementHistory, 1)
		end

		local lastPlayerPosition = currentPos
	end
end

-- Advanced prediction using velocity and acceleration analysis with anti-zigzag detection
local function predictPlayerPositionAdvanced(player, timeAhead)
	if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local hrp = player.Character.HumanoidRootPart
	local currentPos = hrp.Position
	local currentVel = hrp.AssemblyLinearVelocity

	if #playerMovementHistory < 3 then
		-- Basic prediction with current velocity
		return currentPos + (currentVel * timeAhead)
	end

	-- Advanced prediction using movement patterns with zigzag detection
	local recentHistory = {}
	local currentTime = tick()

	-- Get recent samples for pattern analysis
	for i = math.max(1, #playerMovementHistory - PREDICTION_SAMPLES), #playerMovementHistory do
		if currentTime - playerMovementHistory[i].time < 2 then -- Only use data from last 2 seconds
			table.insert(recentHistory, playerMovementHistory[i])
		end
	end

	if #recentHistory < 2 then
		return currentPos + (currentVel * timeAhead)
	end

	-- ZIGZAG DETECTION: Check if player is rapidly changing direction
	local isZigzagging = false
	local directionChanges = 0

	if #recentHistory >= 4 then
		for i = 3, #recentHistory do
			local dir1 = (recentHistory[i-1].position - recentHistory[i-2].position).Unit
			local dir2 = (recentHistory[i].position - recentHistory[i-1].position).Unit

			-- Check if direction changed significantly (dot product < 0 means opposite directions)
			local dotProduct = dir1:Dot(dir2)
			if dotProduct < 0.3 then -- Significant direction change
				directionChanges = directionChanges + 1
			end
		end

		-- If multiple direction changes in short time, player is zigzagging
		isZigzagging = directionChanges >= 2
	end

	if isZigzagging then
		-- ANTI-ZIGZAG STRATEGY: Predict center point instead of extrapolating movement
		local avgPosition = Vector3.new(0, 0, 0)
		local positionWeight = 0

		-- Weight recent positions more heavily
		for i = 1, #recentHistory do
			local weight = i / #recentHistory -- More recent = higher weight
			avgPosition = avgPosition + (recentHistory[i].position * weight)
			positionWeight = positionWeight + weight
		end

		local centerPosition = avgPosition / positionWeight

		-- Add slight bias toward player's CURRENT position (not velocity direction)
		local biasTowardCurrent = (currentPos - centerPosition) * 0.3
		local predictedPos = centerPosition + biasTowardCurrent

		-- Add minimal randomness to avoid being too predictable
		local smallRandomOffset = Vector3.new(
			math.random(-1, 1),
			0,
			math.random(-1, 1)
		)

		return predictedPos + smallRandomOffset
	end

	-- NORMAL PREDICTION: For non-zigzagging players
	-- Calculate average acceleration
	local totalAcceleration = Vector3.new(0, 0, 0)
	local validSamples = 0

	for i = 2, #recentHistory do
		local dt = recentHistory[i].time - recentHistory[i-1].time
		if dt > 0 then
			local acceleration = (recentHistory[i].velocity - recentHistory[i-1].velocity) / dt
			totalAcceleration = totalAcceleration + acceleration
			validSamples = validSamples + 1
		end
	end

	local avgAcceleration = validSamples > 0 and (totalAcceleration / validSamples) or Vector3.new(0, 0, 0)

	-- Predict using physics: pos = current + vel*t + 0.5*acc*t^2
	local predictedPos = currentPos + (currentVel * timeAhead) + (0.5 * avgAcceleration * timeAhead * timeAhead)

	-- Add some randomness based on player's movement style (reduced for moving players)
	local movementVariability = currentVel.Magnitude > 16 and 1 or 0.5
	local randomOffset = Vector3.new(
		math.random(-movementVariability, movementVariability),
		0,
		math.random(-movementVariability, movementVariability)
	)

	return predictedPos + randomOffset
end

-- Function to spawn minions at 35% health with resistance boost
local function spawnMinions()
	if hasSpawnedMinions then return end
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent > 0.35 then return end

	hasSpawnedMinions = true
	sayMessage("ARISE, MY LOYAL GUARDIANS! DEFEND YOUR KING!", 1)

	-- Dramatically increase damage resistance when minions spawn
	damageResistanceValue.Value = 0.6 -- 60% damage resistance with minion support

	-- Epic visual effect for minion summoning
	local summonEffect = Instance.new("Explosion")
	summonEffect.Position = humanoidRootPart.Position
	summonEffect.BlastRadius = 30
	summonEffect.BlastPressure = 0
	summonEffect.Visible = true
	summonEffect.Parent = workspace

	local serverStorage = game:GetService("ServerStorage")
	local enemiesFolder = serverStorage:FindFirstChild("enemies")
	if enemiesFolder then
		local area1Folder = enemiesFolder:FindFirstChild("area1")
		if area1Folder then
			local minionNames = {"arab1", "arab2", "arab3"}
			local spawnPositions = {
				humanoidRootPart.Position + Vector3.new(10, 0, 10),
				humanoidRootPart.Position + Vector3.new(-10, 0, 10),
				humanoidRootPart.Position + Vector3.new(0, 0, -12)
			}

			for i, minionName in ipairs(minionNames) do
				local minionTemplate = area1Folder:FindFirstChild(minionName)
				if minionTemplate then
					local minion = minionTemplate:Clone()
					local minionHRP = minion:FindFirstChild("HumanoidRootPart")
					if minionHRP then
						minion:SetPrimaryPartCFrame(CFrame.new(spawnPositions[i]))

						-- Add spawn effect for each minion
						local minionSpawnEffect = Instance.new("Explosion")
						minionSpawnEffect.Position = spawnPositions[i]
						minionSpawnEffect.BlastRadius = 10
						minionSpawnEffect.BlastPressure = 0
						minionSpawnEffect.Visible = true
						minionSpawnEffect.Parent = workspace
					end
					minion.Parent = workspace
					local minionHumanoid = minion:FindFirstChildOfClass("Humanoid")
					if minionHumanoid then
						minionHumanoid.Died:Connect(function()
							task.wait(5)
							minion:Destroy()
						end)
					end
				end
			end
		end
	end
end

-- Enhanced damage handling with rage buildup
local function onDamaged()
	lastDamageTime = tick()

	-- Progressive damage resistance increase
	local currentResistance = damageResistanceValue.Value
	damageResistanceValue.Value = math.min(0.75, currentResistance + 0.03) -- Cap at 75%

	-- Enhanced pursuit behavior with smoother speed increases
	local timeSinceSpawn = tick() - (lastDamageTime - rangeBoostDuration)
	local rangeMultiplier = math.min(2.5, 1 + (timeSinceSpawn * 0.08))

	-- Smoother speed increases
	pathfinding.combatWalkSpeed = math.min(28, pathfinding.combatWalkSpeed + 0.5)

	-- Enhanced visual feedback
	local rageEffect = Instance.new("Fire")
	rageEffect.Size = 6
	rageEffect.Heat = 8
	rageEffect.Color = Color3.new(1, 0.2, 0)
	rageEffect.SecondaryColor = Color3.new(1, 0.8, 0)
	rageEffect.Parent = humanoidRootPart

	Debris:AddItem(rageEffect, 3)

	-- Enraged messages with more variety
	if math.random() > 0.6 then
		local rageMessages = {
			"THE KING'S WRATH KNOWS NO BOUNDS!",
			"YOU HAVE AWAKENED THE DESERT STORM!",
			"FOOL! YOU ONLY MAKE ME STRONGER!",
			"THE ROYAL BLOOD BOILS WITH FURY!"
		}
		sayMessage(rageMessages[math.random(1, #rageMessages)], 2)
	end
end

-- Connect damage detection
humanoid.HealthChanged:Connect(function(health)
	if health < humanoid.MaxHealth then
		onDamaged()
		spawnMinions()
	end
end)

-- Enhanced dodging system with smoother movement
local function performSmartDodge()
	if isDodging or isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 25 then return end

	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	isDodging = true
	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	-- Enhanced dodge direction calculation
	local playerPos = player.Character.HumanoidRootPart.Position
	local myPos = humanoidRootPart.Position
	local toPlayer = (playerPos - myPos).Unit

	-- Analyze player velocity for predictive dodging
	local playerVel = player.Character.HumanoidRootPart.AssemblyLinearVelocity
	local playerSpeed = playerVel.Magnitude

	-- Choose dodge direction based on player movement
	local dodgeDirection
	if playerSpeed > 10 then
		-- Player is moving fast, dodge perpendicular to their movement
		local playerMovementDir = playerVel.Unit
		dodgeDirection = Vector3.new(-playerMovementDir.Z, 0, playerMovementDir.X)
	else
		-- Player is slow/stationary, use standard perpendicular dodge
		local leftDir = Vector3.new(-toPlayer.Z, 0, toPlayer.X)
		local rightDir = Vector3.new(toPlayer.Z, 0, -toPlayer.X)

		-- Smart obstacle checking
		local leftRay = workspace:Raycast(myPos, leftDir * 12)
		local rightRay = workspace:Raycast(myPos, rightDir * 12)

		if leftRay and not rightRay then
			dodgeDirection = rightDir
		elseif rightRay and not leftRay then
			dodgeDirection = leftDir
		else
			dodgeDirection = math.random() > 0.5 and leftDir or rightDir
		end
	end

	-- Smooth dodge execution using TweenService
	local dodgeDistance = 15
	local dodgeTarget = myPos + (dodgeDirection * dodgeDistance)

	-- Create smooth dodge tween
	local dodgeTween = TweenService:Create(humanoidRootPart,
		TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{CFrame = CFrame.new(dodgeTarget, dodgeTarget + humanoidRootPart.CFrame.LookVector)}
	)

	-- Visual dodge effect
	local dodgeEffect = Instance.new("Explosion")
	dodgeEffect.Position = myPos
	dodgeEffect.BlastRadius = 8
	dodgeEffect.BlastPressure = 0
	dodgeEffect.Visible = false
	dodgeEffect.Parent = workspace

	-- Dodge message with style
	local dodgeMessages = {
		"TOO SLOW FOR THE KING!",
		"THE DESERT WIND GUIDES ME!",
		"PREDICTABLE MOVEMENTS!"
	}
	sayMessage(dodgeMessages[math.random(1, #dodgeMessages)], 2)

	dodgeTween:Play()

	dodgeTween.Completed:Connect(function()
		isDodging = false
		isPerformingSpecialMove = false
		pathfinding:resumeMovement()
		lastDodgeTime = tick()
	end)
end

-- Massively enhanced gun attack with superior accuracy
local function fireGunAttack()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 55 or distance < 6 then return end

	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	isPerformingSpecialMove = true
	isAttacking = true
	pathfinding:pauseMovement()

	-- Epic gun message with dramatic pause
	local gunMessage = GUN_MESSAGES[math.random(1, #GUN_MESSAGES)]
	sayMessage(gunMessage, 1)

	-- Enhanced aiming with smooth rotation
	local playerPos = player.Character.HumanoidRootPart.Position
	local aimDirection = (playerPos - humanoidRootPart.Position).Unit

	-- Smooth aim rotation using TweenService
	local targetCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + aimDirection)
	local aimTween = TweenService:Create(humanoidRootPart,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{CFrame = targetCFrame}
	)
	aimTween:Play()

	task.wait(0.5)

	-- Get enhanced bullet template
	local bulletTemplate = nil
	local enemyWeapons = ReplicatedStorage:FindFirstChild("enemyWeapons")
	if enemyWeapons then
		local desertWeapons = enemyWeapons:FindFirstChild("desertWeapons")
		if desertWeapons then
			bulletTemplate = desertWeapons:FindFirstChild("arabBullet")
		end
	end

	if not bulletTemplate then
		-- Enhanced default bullet (smaller size)
		bulletTemplate = Instance.new("Part")
		bulletTemplate.Name = "arabBullet"
		bulletTemplate.Size = Vector3.new(0.4, 0.4, 1.8)
		bulletTemplate.Shape = Enum.PartType.Cylinder
		bulletTemplate.Color = Color3.new(1, 0.8, 0)
		bulletTemplate.Material = Enum.Material.ForceField
		bulletTemplate.CanCollide = false
		bulletTemplate.Anchored = false
	end

	-- Enhanced bullet volley with superior prediction
	local bulletsToFire = math.random(6, 9)
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < 0.4 then
		bulletsToFire = bulletsToFire + 3 -- More bullets when enraged
	end

	for i = 1, bulletsToFire do
		local bullet = bulletTemplate:Clone()
		bullet.Name = "ArabBullet"

		-- Enhanced bullet starting position
		local muzzleOffset = humanoidRootPart.CFrame.LookVector * 4 + humanoidRootPart.CFrame.UpVector * 1.5
		local startPos = humanoidRootPart.Position + muzzleOffset

		-- SUPERIOR prediction system
		local predictionTime = 0.4 + (distance * 0.008) -- Dynamic prediction based on distance
		local predictedPos = predictPlayerPositionAdvanced(player, predictionTime)

		if not predictedPos then
			predictedPos = player.Character.HumanoidRootPart.Position
		end

		-- Intelligent spread pattern - tighter at range, wider up close
		local spreadFactor = math.max(0.3, math.min(2, distance * 0.04))
		local spread = Vector3.new(
			math.random(-spreadFactor, spreadFactor),
			math.random(-spreadFactor * 0.5, spreadFactor * 0.5),
			math.random(-spreadFactor, spreadFactor)
		)

		-- Lead target slightly more for moving players
		local playerVelocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
		if playerVelocity.Magnitude > 10 then
			predictedPos = predictedPos + (playerVelocity * 0.15)
		end

		predictedPos = predictedPos + spread

		local direction = (predictedPos - startPos).Unit

		bullet.CFrame = CFrame.new(startPos, startPos + direction) * CFrame.Angles(0, math.rad(90), 0)
		bullet.Parent = workspace

		-- Enhanced bullet physics
		local bulletSpeed = 110 + math.random(-10, 15) -- Variable speed for unpredictability
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bodyVelocity.Velocity = direction * bulletSpeed
		bodyVelocity.Parent = bullet

		-- Epic bullet trail effect
		local trail = Instance.new("Trail")
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.6, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0))
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1)
		})
		trail.Lifetime = 0.8
		trail.MinLength = 0
		trail.FaceCamera = true

		local attachment1 = Instance.new("Attachment")
		local attachment2 = Instance.new("Attachment")
		attachment1.Position = Vector3.new(0, 0, -1.5)
		attachment2.Position = Vector3.new(0, 0, 1.5)
		attachment1.Parent = bullet
		attachment2.Parent = bullet
		trail.Attachment0 = attachment1
		trail.Attachment1 = attachment2
		trail.Parent = bullet

		-- Enhanced hit detection
		local hasHit = false
		bullet.Touched:Connect(function(hit)
			if hasHit then return end

			local character = hit.Parent
			local targetPlayer = Players:GetPlayerFromCharacter(character)
			local targetHumanoid = character:FindFirstChild("Humanoid")

			if targetPlayer and targetHumanoid and targetHumanoid.Health > 0 and character ~= enemy then
				hasHit = true

				-- Enhanced damage based on distance (reduced damage)
				local hitDistance = (bullet.Position - humanoidRootPart.Position).Magnitude
				local baseDamage = 45 -- Reduced from 70
				local distanceMultiplier = hitDistance < 30 and 1.2 or (hitDistance > 45 and 0.8 or 1.0)
				local finalDamage = baseDamage * distanceMultiplier + math.random(-6, 8)

				DamageService:ApplyDamage(targetPlayer, finalDamage, enemy)

				-- Enhanced hit effect
				local hitEffect = Instance.new("Explosion")
				hitEffect.Position = bullet.Position
				hitEffect.BlastRadius = 4
				hitEffect.BlastPressure = 0
				hitEffect.Visible = true
				hitEffect.Parent = workspace

				bullet:Destroy()
			elseif hit.Parent ~= enemy and hit.Name ~= "arabBullet" and hit.Name ~= "ArabBomb" and hit.CanCollide then
				hasHit = true
				-- Wall impact effect
				local impactEffect = Instance.new("Explosion")
				impactEffect.Position = bullet.Position
				impactEffect.BlastRadius = 2
				impactEffect.BlastPressure = 0
				impactEffect.Visible = false
				impactEffect.Parent = workspace
				bullet:Destroy()
			end
		end)

		Debris:AddItem(bullet, 4)
		task.wait(0.08) -- Faster firing rate
	end

	task.wait(0.4)
	isPerformingSpecialMove = false
	isAttacking = false
	pathfinding:resumeMovement()
	lastGunTime = tick()
end

-- Massively enhanced bomb throwing with physics-accurate trajectory
local function throwBomb()
	if isPerformingSpecialMove then return end
	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 50 or distance < 5 then return end

	local char = player.Character
	if not char then return end
	local targetHRP = char:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end

	isPerformingSpecialMove = true
	isAttacking = true
	pathfinding:pauseMovement()

	-- Epic bomb message
	local bombMessage = BOMB_MESSAGES[math.random(1, #BOMB_MESSAGES)]
	sayMessage(bombMessage, 1)

	-- Dramatic windup with smooth rotation
	local targetDirection = (targetHRP.Position - humanoidRootPart.Position).Unit
	local windupCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + targetDirection)

	local windupTween = TweenService:Create(humanoidRootPart,
		TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{CFrame = windupCFrame}
	)
	windupTween:Play()

	task.wait(0.8)

	-- Get enhanced bomb template
	local bombTemplate = nil
	local enemyWeapons = ReplicatedStorage:FindFirstChild("enemyWeapons")
	if enemyWeapons then
		local desertWeapons = enemyWeapons:FindFirstChild("desertWeapons")
		if desertWeapons then
			bombTemplate = desertWeapons:FindFirstChild("arabBoom")
		end
	end

	if not bombTemplate then
		-- Enhanced default bomb
		bombTemplate = Instance.new("Part")
		bombTemplate.Name = "arabBoom"
		bombTemplate.Size = Vector3.new(2.5, 2.5, 2.5)
		bombTemplate.Shape = Enum.PartType.Ball
		bombTemplate.Color = Color3.new(0.1, 0.1, 0.1)
		bombTemplate.Material = Enum.Material.Metal
	end

	local bomb = bombTemplate:Clone()
	bomb.Name = "ArabBomb"
	bomb.Anchored = false
	bomb.CanCollide = true

	-- Epic bomb effects
	local fuse = Instance.new("Fire")
	fuse.Size = 6
	fuse.Heat = 8
	fuse.Color = Color3.new(1, 0.3, 0)
	fuse.SecondaryColor = Color3.new(1, 0.8, 0)
	fuse.Parent = bomb

	local spark = Instance.new("Sparkles")
	spark.SparkleColor = Color3.new(1, 1, 0)
	spark.Parent = bomb

	-- Ominous ticking sound effect
	local tickSound = Instance.new("Sound")
	tickSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	tickSound.Volume = 0.5
	tickSound.Pitch = 1.5
	tickSound.Looped = true
	tickSound.Parent = bomb
	tickSound:Play()

	-- DIRECT targeting - straight at the player
	local startPos = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)

	-- Simple prediction with minimal leading
	local predictedPos = predictPlayerPositionAdvanced(player, 0.3) -- Very short prediction

	if not predictedPos then
		predictedPos = targetHRP.Position
	end

	bomb.CFrame = CFrame.new(startPos)
	bomb.Parent = workspace

	-- STRAIGHT LINE throw - no arc calculation, just direct velocity
	local direction = (predictedPos - startPos).Unit
	local throwSpeed = 40 -- Fast, direct throw speed
	local throwVelocity = direction * throwSpeed

	bomb.AssemblyLinearVelocity = throwVelocity

	-- Enhanced spinning effect
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bodyAngularVelocity.AngularVelocity = Vector3.new(
		math.random(-15, 15), 
		math.random(-15, 15), 
		math.random(-15, 15)
	)
	bodyAngularVelocity.Parent = bomb

	-- Smart proximity detection with prediction (NO REAL EXPLOSION)
	local hasExploded = false
	local explosionRadius = 22

	task.spawn(function()
		while bomb and bomb.Parent and not hasExploded do
			for _, p in pairs(Players:GetPlayers()) do
				local char = p.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					local currentDist = (char.HumanoidRootPart.Position - bomb.Position).Magnitude

					-- Predict where player will be in 0.2 seconds for more reliable detonation
					local playerVel = char.HumanoidRootPart.AssemblyLinearVelocity
					local predictedPlayerPos = char.HumanoidRootPart.Position + (playerVel * 0.2)
					local predictedDist = (predictedPlayerPos - bomb.Position).Magnitude

					if currentDist <= 10 or predictedDist <= 8 then
						hasExploded = true
						tickSound:Stop()

						-- FAKE visual explosion (no real blast damage/knockback)
						local explosion = Instance.new("Explosion")
						explosion.Position = bomb.Position
						explosion.BlastRadius = explosionRadius
						explosion.BlastPressure = 0 -- No knockback
						explosion.Visible = true
						explosion.Parent = workspace

						-- REAL DAMAGE calculation with falloff (not from explosion)
						for _, nearbyPlayer in pairs(Players:GetPlayers()) do
							local nearbyChar = nearbyPlayer.Character
							if nearbyChar and nearbyChar:FindFirstChild("HumanoidRootPart") then
								local d = (nearbyChar.HumanoidRootPart.Position - bomb.Position).Magnitude
								if d <= explosionRadius then
									-- Enhanced damage formula with better scaling
									local baseDamage = 180
									local falloffFactor = 1 - (d / explosionRadius)
									local finalDamage = baseDamage * falloffFactor + math.random(-15, 25)
									finalDamage = math.max(60, finalDamage) -- Minimum damage

									-- Apply REAL damage through DamageService (not explosion damage)
									DamageService:ApplyDamage(nearbyPlayer, finalDamage, enemy)
								end
							end
						end
						bomb:Destroy()
						break
					end
				end
			end
			task.wait(0.03) -- Higher frequency checking for better accuracy
		end
	end)

	-- Enhanced failsafe explosion with warning (NO REAL EXPLOSION)
	task.delay(4, function()
		if not hasExploded and bomb and bomb.Parent then
			hasExploded = true
			tickSound:Stop()

			-- Warning effect before explosion
			local warningEffect = Instance.new("Explosion")
			warningEffect.Position = bomb.Position
			warningEffect.BlastRadius = 5
			warningEffect.BlastPressure = 0
			warningEffect.Visible = false
			warningEffect.Parent = workspace

			task.wait(0.3)

			-- FAKE visual explosion (no real blast damage/knockback)
			local explosion = Instance.new("Explosion")
			explosion.Position = bomb.Position
			explosion.BlastRadius = explosionRadius
			explosion.BlastPressure = 0 -- No knockback
			explosion.Visible = true
			explosion.Parent = workspace

			-- REAL DAMAGE calculation (not from explosion)
			for _, nearbyPlayer in pairs(Players:GetPlayers()) do
				local nearbyChar = nearbyPlayer.Character
				if nearbyChar and nearbyChar:FindFirstChild("HumanoidRootPart") then
					local d = (nearbyChar.HumanoidRootPart.Position - bomb.Position).Magnitude
					if d <= explosionRadius then
						local baseDamage = 180
						local falloffFactor = 1 - (d / explosionRadius)
						local finalDamage = baseDamage * falloffFactor + math.random(-15, 25)
						finalDamage = math.max(60, finalDamage)
						-- Apply REAL damage through DamageService (not explosion damage)
						DamageService:ApplyDamage(nearbyPlayer, finalDamage, enemy)
					end
				end
			end
			bomb:Destroy()
		end
	end)

	task.wait(1.2)
	isPerformingSpecialMove = false
	isAttacking = false
	pathfinding:resumeMovement()
	lastBombTime = tick()
end

-- Enhanced wandering functions (keeping original logic but with smoother movement)
local function getRandomWanderPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random(8, maxWanderDistance)
	local newPos = originPoint + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
	return newPos
end

local function isWithinWanderBounds(position)
	local distanceFromOrigin = (position - originPoint).Magnitude
	return distanceFromOrigin <= maxWanderDistance
end

local function createWanderPath(targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 16,
		AgentMaxSlope = 45,
		WaypointSpacing = 8 -- Increased for smoother movement
	})

	local success, errorMessage = pcall(function()
		path:ComputeAsync(humanoidRootPart.Position, targetPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		return path
	else
		return nil
	end
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

-- Enhanced wandering with smoother movement
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
		-- Smoother direct movement for wandering
		local moveTween = TweenService:Create(humanoidRootPart,
			TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{CFrame = CFrame.new(wanderTarget, wanderTarget + humanoidRootPart.CFrame.LookVector)}
		)
		moveTween:Play()

		moveTween.Completed:Connect(function()
			stopWandering()
		end)
		return
	end

	-- Smoother wander movement loop
	wanderConnection = RunService.Heartbeat:Connect(function()
		if not isWandering or not wanderPath then return end

		local waypoints = wanderPath:GetWaypoints()
		if wanderWaypointIndex <= #waypoints then
			local waypoint = waypoints[wanderWaypointIndex]
			local distanceToWaypoint = (waypoint.Position - humanoidRootPart.Position).Magnitude

			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end

			-- Smoother movement to waypoint
			if movementSmoothing then
				local targetPos = waypoint.Position
				local currentPos = humanoidRootPart.Position
				local smoothedPos = currentPos:Lerp(targetPos, movementLerpAlpha)
				humanoid:MoveTo(smoothedPos)
			else
				humanoid:MoveTo(waypoint.Position)
			end

			if distanceToWaypoint < 6 then -- Increased threshold for smoother movement
				wanderWaypointIndex = wanderWaypointIndex + 1
			end
		else
			stopWandering()
		end
	end)

	-- Enhanced wander messages
	if tick() - lastWanderMessage > 20 and math.random() > 0.8 then
		local randomMessage = WANDER_MESSAGES[math.random(1, #WANDER_MESSAGES)]
		sayMessage(randomMessage)
		lastWanderMessage = tick()
	end
end

-- Enhanced touch damage with better collision detection
local function setupTouchDamage()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if deBounce or isPerformingSpecialMove then return end
				local character = hit.Parent
				if character == nil then return end
				local playerHumanoid = character:FindFirstChild("Humanoid")
				local player = Players:GetPlayerFromCharacter(character)

				if playerHumanoid and player and humanoid.Health > 0 and character ~= enemy then
					deBounce = true

					if currentState ~= "attacking" then
						currentState = "attacking"
						sayMessage(ATTACK_MESSAGE)
					end

					-- Enhanced damage with health-based scaling
					local healthPercent = humanoid.Health / humanoid.MaxHealth
					local baseDamage = healthPercent < 0.4 and 55 or 45 -- More damage when low health
					local actualDamage = baseDamage + math.random(-8, 12)

					DamageService:ApplyDamage(player, actualDamage, enemy)

					-- Enhanced hit effect
					local hitEffect = Instance.new("Explosion")
					hitEffect.Position = hit.Position
					hitEffect.BlastRadius = 6
					hitEffect.BlastPressure = 0
					hitEffect.Visible = false
					hitEffect.Parent = workspace

					task.wait(0.6) -- Slightly faster attack rate
					deBounce = false
				end    
			end)
		end
	end

	enemy.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			child.Touched:Connect(function(hit)
				if deBounce or isPerformingSpecialMove then return end
				local character = hit.Parent
				local playerHumanoid = character:FindFirstChild("Humanoid")
				local player = Players:GetPlayerFromCharacter(character)

				if playerHumanoid and player and humanoid.Health > 0 and character ~= enemy then
					deBounce = true

					if currentState ~= "attacking" then
						currentState = "attacking"
						sayMessage(ATTACK_MESSAGE)
					end

					local healthPercent = humanoid.Health / humanoid.MaxHealth
					local baseDamage = healthPercent < 0.4 and 55 or 45
					local actualDamage = baseDamage + math.random(-8, 12)
					DamageService:ApplyDamage(player, actualDamage, enemy)

					local hitEffect = Instance.new("Explosion")
					hitEffect.Position = hit.Position
					hitEffect.BlastRadius = 6
					hitEffect.BlastPressure = 0
					hitEffect.Visible = false
					hitEffect.Parent = workspace

					task.wait(0.6)
					deBounce = false
				end    
			end)
		end
	end)
end

-- Enhanced dash attack with smoother movement and better targeting
local function performDash()
	if isPerformingSpecialMove then return end
	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 40 or distance < 6 then return end

	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	isPerformingSpecialMove = true
	stopWandering()

	-- Epic warning with visual effect
	sayMessage("THE KING CHARGES!", 1)

	-- Warning effect at target location
	local warningPos = player.Character.HumanoidRootPart.Position
	local warningEffect = Instance.new("Explosion")
	warningEffect.Position = warningPos
	warningEffect.BlastRadius = 8
	warningEffect.BlastPressure = 0
	warningEffect.Visible = false
	warningEffect.Parent = workspace

	task.wait(0.4)

	-- Enhanced prediction for dash target
	local predictedPos = predictPlayerPositionAdvanced(player, 0.8)
	if not predictedPos then
		predictedPos = player.Character.HumanoidRootPart.Position
	end

	-- Smooth dash using TweenService for better visual effect
	local dashTween = TweenService:Create(humanoidRootPart,
		TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{CFrame = CFrame.new(predictedPos, predictedPos + humanoidRootPart.CFrame.LookVector)}
	)

	-- Enhanced dash trail effect
	local dashTrail = Instance.new("Trail")
	dashTrail.Color = ColorSequence.new(Color3.new(1, 0.8, 0), Color3.new(1, 0, 0))
	dashTrail.Transparency = NumberSequence.new(0, 1)
	dashTrail.Lifetime = 1
	dashTrail.MinLength = 0
	dashTrail.FaceCamera = true

	local attachment1 = Instance.new("Attachment")
	local attachment2 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, -2, 0)
	attachment2.Position = Vector3.new(0, 2, 0)
	attachment1.Parent = humanoidRootPart
	attachment2.Parent = humanoidRootPart
	dashTrail.Attachment0 = attachment1
	dashTrail.Attachment1 = attachment2
	dashTrail.Parent = humanoidRootPart

	dashTween:Play()

	-- Enhanced damage during dash
	local dashDamageActive = true
	local dashConnection
	dashConnection = RunService.Heartbeat:Connect(function()
		if not dashDamageActive then
			dashConnection:Disconnect()
			return
		end

		local currentPlayer, currentDistance = pathfinding:getClosestPlayer()
		if currentPlayer and currentDistance < 15 then
			local healthPercent = humanoid.Health / humanoid.MaxHealth
			local dashDamage = healthPercent < 0.4 and 80 or 65 -- More damage when enraged
			DamageService:ApplyDamage(currentPlayer, dashDamage, enemy)
			dashDamageActive = false
		end
	end)

	dashTween.Completed:Connect(function()
		dashDamageActive = false

		-- Clean up trail effect
		Debris:AddItem(dashTrail, 1)
		Debris:AddItem(attachment1, 1)
		Debris:AddItem(attachment2, 1)

		task.wait(0.5)
		isPerformingSpecialMove = false
		lastDashTime = tick()
	end)
end

-- Enhanced berserker mode with maximum resistance and cooler effects
local function checkBerserkerMode()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < 0.35 then
		-- Maximum damage resistance when berserking
		damageResistanceValue.Value = math.max(damageResistanceValue.Value, 0.55)

		-- Enhanced capabilities with smoother increases
		pathfinding:updateConfig({
			combatWalkSpeed = math.min(30, pathfinding.walkSpeed * 1.6),
			walkSpeed = math.min(22, pathfinding.walkSpeed * 1.3)
		})

		-- Epic berserker visual effects
		if not humanoidRootPart:FindFirstChild("BerserkerEffect") then
			-- Main berserker fire
			local effect = Instance.new("Fire")
			effect.Name = "BerserkerEffect"
			effect.Size = 12
			effect.Heat = 15
			effect.Color = Color3.new(1, 0, 0)
			effect.SecondaryColor = Color3.new(1, 0.3, 0)
			effect.Parent = humanoidRootPart

			-- Berserker sparks
			local sparks = Instance.new("Sparkles")
			sparks.Name = "BerserkerSparks"
			sparks.SparkleColor = Color3.new(1, 0.8, 0)
			sparks.Parent = humanoidRootPart

			-- Pulsing berserker aura
			local berserkerAura = Instance.new("SelectionBox")
			berserkerAura.Name = "BerserkerAura"
			berserkerAura.Adornee = humanoidRootPart
			berserkerAura.Color3 = Color3.new(1, 0, 0)
			berserkerAura.LineThickness = 0.4
			berserkerAura.Transparency = 0.3
			berserkerAura.Parent = humanoidRootPart

			local berserkerPulse = TweenService:Create(berserkerAura,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Transparency = 0.1, LineThickness = 0.8}
			)
			berserkerPulse:Play()
		end
	end
end

-- Enhanced smart attack decision system with better logic
local function chooseSmartAttack()
	local player, distance = pathfinding:getClosestPlayer()
	if not player then return end

	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local healthPercent = humanoid.Health / humanoid.MaxHealth
	local inBerserker = healthPercent < 0.35
	local playerVelocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
	local playerSpeed = playerVelocity.Magnitude

	-- Prioritize attacks based on situation and distance
	local attackPriorities = {}

	-- Gun attack priority
	if distance > 18 and distance < 55 and tick() - lastGunTime > (inBerserker and gunCooldown * 0.7 or gunCooldown) then
		local gunPriority = 0.6
		if playerSpeed > 14 then gunPriority = gunPriority + 0.3 end -- Higher priority for moving targets
		if distance > 35 then gunPriority = gunPriority + 0.2 end -- Prefer guns at long range
		if inBerserker then gunPriority = gunPriority + 0.2 end
		table.insert(attackPriorities, {type = "gun", priority = gunPriority})
	end

	-- Bomb attack priority  
	if distance > 8 and distance < 50 and tick() - lastBombTime > (inBerserker and bombCooldown * 0.6 or bombCooldown) then
		local bombPriority = 0.5
		if playerSpeed < 10 then bombPriority = bombPriority + 0.4 end -- Higher priority for slow targets
		if distance > 15 and distance < 35 then bombPriority = bombPriority + 0.3 end -- Optimal bomb range
		if inBerserker then bombPriority = bombPriority + 0.25 end
		table.insert(attackPriorities, {type = "bomb", priority = bombPriority})
	end

	-- Dash attack priority
	if distance > 10 and distance < 35 and tick() - lastDashTime > dashCooldown then
		local dashPriority = 0.4
		if distance > 20 and distance < 30 then dashPriority = dashPriority + 0.3 end -- Optimal dash range
		if playerSpeed < 8 then dashPriority = dashPriority + 0.2 end -- Easier to hit slow targets
		if inBerserker then dashPriority = dashPriority + 0.3 end
		table.insert(attackPriorities, {type = "dash", priority = dashPriority})
	end

	-- Dodge priority
	if distance < 25 and tick() - lastDodgeTime > dodgeCooldown then
		local dodgePriority = 0.3
		if playerSpeed > 12 then dodgePriority = dodgePriority + 0.2 end
		if distance < 15 then dodgePriority = dodgePriority + 0.3 end -- More likely to dodge when close
		table.insert(attackPriorities, {type = "dodge", priority = dodgePriority})
	end

	-- Sort by priority and execute the best attack
	table.sort(attackPriorities, function(a, b) return a.priority > b.priority end)

	if #attackPriorities > 0 and math.random() < attackPriorities[1].priority then
		local chosenAttack = attackPriorities[1].type

		if chosenAttack == "gun" then
			fireGunAttack()
		elseif chosenAttack == "bomb" then
			throwBomb()
		elseif chosenAttack == "dash" then
			performDash()
		elseif chosenAttack == "dodge" then
			performSmartDodge()
		end
	end
end

-- Enhanced AI state management with smoother transitions
local function updateAIState()
	local player, distance = pathfinding:getClosestPlayer()

	-- Update player tracking for better prediction
	updatePlayerMovementTracking()

	-- Handle range decay over time (smoother)
	if tick() - lastDamageTime > rangeBoostDuration then
		local decayRate = 0.995 -- Slower decay for smoother transitions
		maxDistance = math.max(baseMaxDistance, maxDistance * decayRate)
		pathfinding.maxDistance = maxDistance
		pathfinding.combatMaxDistance = maxDistance * 1.5
	end

	if player and distance <= maxDistance then
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
		elseif currentState == "lost" and tick() - lastChatTime > 8 then
			currentState = "wandering"
		end

		-- Enhanced wandering behavior with longer intervals
		if (currentState == "wandering" or currentState == "lost") and not isWandering then
			if tick() - wanderCooldown > 8 then -- Longer wandering intervals for less jitter
				startWandering()
				wanderCooldown = tick()
			end
		end
	end
end

-- Setup systems
setupTouchDamage()

-- Start the pathfinding system
pathfinding:startMovement()

-- Main AI loop with reduced frequency for smoother performance
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(0.4) -- Reduced frequency for smoother performance
		updateAIState()
	end
end)

-- Enhanced smart attack system with better timing
task.spawn(function()
	while humanoid.Health > 0 do
		local healthPercent = humanoid.Health / humanoid.MaxHealth
		local attackInterval = healthPercent < 0.35 and math.random(1.8, 2.8) or math.random(2.5, 4.0)
		task.wait(attackInterval)

		if not isPerformingSpecialMove then
			chooseSmartAttack()
		end
	end
end)

-- Enhanced anti-range camping system
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2.0) -- Reduced frequency for smoother performance

		if not isPerformingSpecialMove then
			local player, distance = pathfinding:getClosestPlayer()
			if player and distance > maxDistance * 0.75 then
				if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
					continue
				end

				local timeSinceDamage = tick() - lastDamageTime

				if timeSinceDamage < rangeBoostDuration then
					local pursuitMessages = {
						"NO ESCAPE FROM THE KING'S WRATH!",
						"COWARD! FACE ME IN COMBAT!",
						"THE DESERT HAS NO HIDING PLACES!"
					}
					sayMessage(pursuitMessages[math.random(1, #pursuitMessages)])

					-- Enhanced pursuit with smoother speed increases
					pathfinding:updateConfig({
						combatWalkSpeed = math.min(32, pathfinding.combatWalkSpeed + 1)
					})

					if distance < maxPossibleDistance then
						currentState = "chasing"
						pathfinding:resumeMovement()

						-- Prefer long-range attacks while pursuing
						if distance > 25 and tick() - lastGunTime > gunCooldown * 0.6 then
							fireGunAttack()
						elseif distance > 15 and distance < 45 and tick() - lastBombTime > bombCooldown * 0.7 then
							throwBomb()
						end
					end
				end
			end
		end
	end
end)

-- Enhanced berserker mode checker
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2.0)
		checkBerserkerMode()
	end
end)

-- Enhanced rage mode with rapid attacks
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1.2)

		local healthPercent = humanoid.Health / humanoid.MaxHealth
		if healthPercent < 0.25 and not isPerformingSpecialMove then
			if math.random() > 0.4 then -- More frequent attacks when enraged
				local player, distance = pathfinding:getClosestPlayer()
				if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					if distance > 20 and distance < 50 and tick() - lastGunTime > 2.5 then
						fireGunAttack()
					elseif distance > 10 and distance < 40 and tick() - lastBombTime > 2 then
						throwBomb()
					end
				end
			end
		end
	end
end)

-- Enhanced adaptive behavior system
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(6) -- Longer intervals for better performance

		local player, distance = pathfinding:getClosestPlayer()
		if player and #playerMovementHistory > 8 then
			if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
				continue
			end

			-- Enhanced movement analysis
			local totalMovement = 0
			local recentHistory = {}

			-- Get more samples for better analysis
			for i = math.max(1, #playerMovementHistory - 10), #playerMovementHistory do
				table.insert(recentHistory, playerMovementHistory[i])
			end

			-- Calculate average movement speed and patterns
			for i = 2, #recentHistory do
				local dist = (recentHistory[i].position - recentHistory[i-1].position).Magnitude
				local time = recentHistory[i].time - recentHistory[i-1].time
				if time > 0 then
					totalMovement = totalMovement + (dist / time)
				end
			end

			local avgSpeed = totalMovement / math.max(1, (#recentHistory - 1))

			-- Smarter strategy adaptation
			if avgSpeed > 18 then
				-- Very mobile player - optimize for prediction and guns
				gunCooldown = math.max(2.5, gunCooldown - 0.3)
				bombCooldown = math.min(8, bombCooldown + 0.3)
			elseif avgSpeed < 6 then
				-- Stationary player - prefer bombs and close combat
				bombCooldown = math.max(2, bombCooldown - 0.3)
				gunCooldown = math.min(12, gunCooldown + 0.3)
			else
				-- Balanced approach for moderate movement
				gunCooldown = math.max(4, math.min(8, gunCooldown))
				bombCooldown = math.max(3, math.min(7, bombCooldown))
			end
		end
	end
end)

-- Enhanced smart positioning system
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(3) -- Longer intervals for smoother movement

		if not isPerformingSpecialMove and not isWandering then
			local player, distance = pathfinding:getClosestPlayer()
			if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				-- Enhanced optimal distance maintenance (15-28 studs)
				if distance < 12 and not isDodging then
					-- Too close - strategic retreat with attack
					local backAwayDirection = (humanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Unit
					local backAwayPos = humanoidRootPart.Position + (backAwayDirection * 10)

					-- Enhanced obstacle checking
					local ray = workspace:Raycast(humanoidRootPart.Position, backAwayDirection * 12)
					if not ray then
						-- Smooth retreat using TweenService
						local retreatTween = TweenService:Create(humanoidRootPart,
							TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{CFrame = CFrame.new(backAwayPos, player.Character.HumanoidRootPart.Position)}
						)
						retreatTween:Play()

						-- Fire while retreating for tactical advantage
						if math.random() > 0.5 and tick() - lastGunTime > gunCooldown * 0.7 then
							task.wait(0.6)
							fireGunAttack()
						end
					end
				elseif distance > 45 then
					-- Too far - advance for better attack opportunities
					pathfinding:resumeMovement()
				end
			end
		end
	end
end)

-- Cleanup when enemy dies
humanoid.Died:Connect(function()
	stopWandering()
	if pathfinding then
		pathfinding:destroy()
	end

	-- Clean up all effects
	local effect = humanoidRootPart:FindFirstChild("BerserkerEffect")
	local sparks = humanoidRootPart:FindFirstChild("BerserkerSparks")
	local aura = humanoidRootPart:FindFirstChild("KingAura")
	local berserkerAura = humanoidRootPart:FindFirstChild("BerserkerAura")

	if effect then effect:Destroy() end
	if sparks then sparks:Destroy() end
	if aura then aura:Destroy() end
	if berserkerAura then berserkerAura:Destroy() end

	-- Epic death message
	sayMessage("The King... falls... but the legend... lives on...", 1)
end)