-- Ghost ENEMY SCRIPT - Updated for New Resistance System
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local enemy = script.Parent
local humanoidRootPart = enemy.HumanoidRootPart
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy.Humanoid

-- Ghost Stats
humanoid.MaxHealth = 750 
humanoid.Health = 750

local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")

-- Ghost properties with NEW resistance system
local ghostTransparency = 0.7
local phaseTransparency = 0.95
local isPhasing = false
local isInvisible = false
local lastPhaseTime = 0
local phaseCooldown = 15
local baseDamageResistance = 0.40 -- 40% base damage resistance
local phaseDamageResistance = 0.6 -- 60% damage resistance when phasing
local baseDefenseResistance = 0.45 -- 45% base defense resistance (reduces player defense effectiveness)
local phaseDefenseResistance = 0.95 -- 95% defense resistance when phasing

-- Wandering variables
local originPoint = humanoidRootPart.Position
local maxWanderDistance = 80 -- Larger range for boss
local wanderCooldown = 0
local lastChatTime = 0
local chatCooldown = 3
local currentState = "wandering"
local isWandering = false
local wanderPath = nil
local wanderWaypointIndex = 1
local wanderConnection = nil

-- Ghost-themed messages
local WANDER_MESSAGES = {
	"oooooooooh...",
	"I sense... living souls...",
	"The spirits call to me...",
	"Death awaits all...",
	"*ethereal whispers*"
}

local CHASE_MESSAGE = "YOUR SOUL IS MINE!"
local ATTACK_MESSAGE = "FEEL THE COLD OF DEATH!"
local LOST_TARGET_MESSAGE = "You cannot hide from death..."
local PHASE_MESSAGE = "You cannot touch what is not there!"
local ENRAGE_MESSAGE = "THE VEIL BETWEEN WORLDS TEARS!"

local maxDistance = 50 -- Larger detection range
local deBounce = false
local lastSpecialAttackTime = 0
local specialAttackCooldown = 12
local isPerformingSpecialMove = false
local lastSoulDrainTime = 0
local soulDrainCooldown = 20

-- Setup NEW resistance system (replaces old defenseEffectiveness)
local function setupResistanceSystem()
	-- Remove old defenseEffectiveness if it exists (deprecated)
	local oldDefenseEffectiveness = enemy:FindFirstChild("defenseEffectiveness")
	if oldDefenseEffectiveness then
		oldDefenseEffectiveness:Destroy()
		--print("🗑️ Removed deprecated defenseEffectiveness from " .. enemy.Name)
	end

	-- Set up NEW damage resistance
	local damageResistanceValue = Instance.new("NumberValue")
	damageResistanceValue.Name = "DamageResistance"
	damageResistanceValue.Value = baseDamageResistance
	damageResistanceValue.Parent = enemy

	-- Set up NEW defense resistance (reduces player defense effectiveness)
	local defenseResistanceValue = Instance.new("NumberValue")
	defenseResistanceValue.Name = "DefenseResistance"
	defenseResistanceValue.Value = baseDefenseResistance
	defenseResistanceValue.Parent = enemy

	--print("✅ Ghost Boss resistance system initialized:")
	--print("   📊 Damage Resistance: " .. (baseDamageResistance * 100) .. "%")
	--print("   🛡️ Defense Resistance: " .. (baseDefenseResistance * 100) .. "%")
end

-- Make ghost semi-transparent initially
local function setGhostAppearance()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = ghostTransparency
			part.CanCollide = false -- Ghosts don't collide normally

			-- Add ghostly glow effect
			local pointLight = Instance.new("PointLight")
			pointLight.Brightness = 1
			pointLight.Color = Color3.fromRGB(100, 255, 255) -- Cyan ghost light
			pointLight.Range = 15
			pointLight.Parent = part
		end
	end
end

-- Initialize the pathfinding system with ghost abilities
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = maxDistance,
	combatMaxDistance = maxDistance * 2,
	walkSpeed = 25, -- Faster than normal enemies
	combatWalkSpeed = 35,
	pathUpdateInterval = 1.5,
	combatPathUpdateInterval = 0.5,
	stuckThreshold = 3,
	waypointDistance = 6,
	combatDuration = 20,
	predictionTime = 0.7
})

local function sayMessage(message)
	if tick() - lastChatTime >= chatCooldown then
		Chat:Chat(enemy.Head, message, Enum.ChatColor.White)
		lastChatTime = tick()
	end
end

-- Phase Walk ability - ghost becomes nearly invisible and increases both resistances
local function performPhaseWalk()
	if isPhasing or tick() - lastPhaseTime < phaseCooldown then return end

	isPhasing = true
	lastPhaseTime = tick()
	sayMessage(PHASE_MESSAGE)

	-- Increase BOTH resistances during phase using NEW system
	local damageResistanceValue = enemy:FindFirstChild("DamageResistance")
	local defenseResistanceValue = enemy:FindFirstChild("DefenseResistance")

	if damageResistanceValue then
		damageResistanceValue.Value = phaseDamageResistance
		--print("⚡ Ghost phase: Damage resistance increased to " .. (phaseDamageResistance * 100) .. "%")
	end

	if defenseResistanceValue then
		defenseResistanceValue.Value = phaseDefenseResistance
		--print("⚡ Ghost phase: Defense resistance increased to " .. (phaseDefenseResistance * 100) .. "%")
	end

	-- Make ghost nearly invisible and intangible
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(0.5, Enum.EasingStyle.Sine), 
				{Transparency = phaseTransparency}
			)
			tween:Play()
			part.CanCollide = false
		end
	end

	-- Phase walk lasts 4 seconds
	task.wait(4)

	-- Return to normal resistance values
	if damageResistanceValue then
		damageResistanceValue.Value = baseDamageResistance
		--print("🔄 Ghost phase ended: Damage resistance returned to " .. (baseDamageResistance * 100) .. "%")
	end

	if defenseResistanceValue then
		defenseResistanceValue.Value = baseDefenseResistance
		--print("🔄 Ghost phase ended: Defense resistance returned to " .. (baseDefenseResistance * 100) .. "%")
	end

	-- Return to normal ghost appearance
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(0.5, Enum.EasingStyle.Sine), 
				{Transparency = ghostTransparency}
			)
			tween:Play()
		end
	end

	isPhasing = false
end

-- Soul Drain attack - damages all nearby players and heals ghost
local function performSoulDrain()
	if isPerformingSpecialMove or tick() - lastSoulDrainTime < soulDrainCooldown then return end

	isPerformingSpecialMove = true
	lastSoulDrainTime = tick()

	sayMessage("YOUR LIFE FORCE FEEDS ME!")

	-- Create soul drain effect
	local soulDrainEffect = Instance.new("Explosion")
	soulDrainEffect.Position = humanoidRootPart.Position
	soulDrainEffect.BlastRadius = 25
	soulDrainEffect.BlastPressure = 0
	soulDrainEffect.Visible = false
	soulDrainEffect.Parent = workspace

	-- Visual effect
	local drainOrb = Instance.new("Part")
	drainOrb.Name = "SoulDrainOrb"
	drainOrb.Anchored = true
	drainOrb.CanCollide = false
	drainOrb.Transparency = 0.3
	drainOrb.Material = Enum.Material.Neon
	drainOrb.BrickColor = BrickColor.new("Really red")
	drainOrb.Shape = Enum.PartType.Ball
	drainOrb.Size = Vector3.new(1, 1, 1)
	drainOrb.CFrame = humanoidRootPart.CFrame
	drainOrb.Parent = workspace

	-- Expand the orb
	local expandTween = TweenService:Create(drainOrb,
		TweenInfo.new(2, Enum.EasingStyle.Sine),
		{Size = Vector3.new(50, 50, 50), Transparency = 0.8}
	)
	expandTween:Play()

	-- Damage players in range and heal ghost using NEW system
	local totalHealing = 0
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
			if distance <= 25 then
				-- Use SmartApplyDamage to automatically route to correct damage system
				local success, result = DamageService:SmartApplyDamage(enemy, player, 65)
				if success then
					totalHealing = totalHealing + 115
					--print("👻 Soul Drain hit " .. player.Name .. " for magic damage (bypasses resistance)")
				end
			end
		end
	end

	-- Heal the ghost
	humanoid.Health = math.min(humanoid.Health + totalHealing, humanoid.MaxHealth)
	if totalHealing > 0 then
		--print("💚 Ghost healed for " .. totalHealing .. " HP from soul drain")
	end

	-- Clean up effect
	task.wait(2)
	drainOrb:Destroy()
	isPerformingSpecialMove = false
end

-- Spectral Charge - ghost teleports behind closest player
local function performSpectralCharge()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 40 or distance < 10 then return end

	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	sayMessage("NOWHERE TO RUN!")

	-- Disappear effect
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(0.3, Enum.EasingStyle.Quad), 
				{Transparency = 1}
			)
			tween:Play()
		end
	end

	task.wait(0.5)

	-- Teleport behind player
	local playerChar = player.Character
	local playerPos = playerChar.HumanoidRootPart.Position
	local playerDirection = playerChar.HumanoidRootPart.CFrame.LookVector
	local teleportPos = playerPos - (playerDirection * 8) -- Behind player

	humanoidRootPart.CFrame = CFrame.new(teleportPos, playerPos)

	-- Reappear with dramatic effect
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(0.3, Enum.EasingStyle.Quad), 
				{Transparency = ghostTransparency}
			)
			tween:Play()
		end
	end

	-- Immediate attack after teleport using NEW system
	task.wait(0.3)
	if (playerChar.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude < 12 then
		local success, result = DamageService:SmartApplyDamage(enemy, player, 60)
		if success then
			--print("⚡ Spectral Charge successfully hit " .. player.Name .. " for enhanced damage!")
		end
	end

	task.wait(0.5)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
end

-- Enhanced touch damage using NEW damage system
local function setupTouchDamage()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if deBounce or isPerformingSpecialMove or isPhasing then return end

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

					-- Boss-level damage using NEW damage system
					local baseDamage = 50
					local actualDamage = baseDamage + math.random(-5, 10)

					-- Use SmartApplyDamage for automatic routing to correct damage function
					local success, result = DamageService:SmartApplyDamage(enemy, player, actualDamage)

					if success then
						--print("👻 Ghost touch attack hit " .. player.Name .. " - damage properly reduced by player defense!")
					end

					-- Chance to trigger phase walk after attacking
					if math.random() > 0.7 then
						task.spawn(performPhaseWalk)
					end

					task.wait(1) -- Slightly longer cooldown for boss
					deBounce = false
				end    
			end)
		end
	end
end

-- Poltergeist Rage when health is low - increases resistances further
local function checkPoltergeistRage()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < 0.35 then -- Below 35% health
		if not humanoidRootPart:FindFirstChild("RageAura") then
			sayMessage(ENRAGE_MESSAGE)

			-- Increase speed and reduce cooldowns
			pathfinding:updateConfig({
				combatWalkSpeed = pathfinding.walkSpeed * 1.8
			})
			specialAttackCooldown = 6
			soulDrainCooldown = 8
			phaseCooldown = 8

			-- BOOST RESISTANCES during rage using NEW system
			local damageResistanceValue = enemy:FindFirstChild("DamageResistance")
			local defenseResistanceValue = enemy:FindFirstChild("DefenseResistance")

			if damageResistanceValue and not isPhasing then
				-- Don't override phase resistance if currently phasing
				damageResistanceValue.Value = math.min(baseDamageResistance + 0.2, 0.8) -- +20% damage resistance, max 80%
				--print("🔥 RAGE: Damage resistance increased to " .. (damageResistanceValue.Value * 100) .. "%")
			end

			if defenseResistanceValue and not isPhasing then
				defenseResistanceValue.Value = math.min(baseDefenseResistance + 0.25, 0.7) -- +25% defense resistance, max 70%
				--print("🔥 RAGE: Defense resistance increased to " .. (defenseResistanceValue.Value * 100) .. "%")
			end

			-- Rage aura effect
			local rageAura = Instance.new("Fire")
			rageAura.Name = "RageAura"
			rageAura.Size = 8
			rageAura.Heat = 10
			rageAura.Color = Color3.fromRGB(100, 0, 255) -- Purple flames
			rageAura.SecondaryColor = Color3.fromRGB(255, 0, 100)
			rageAura.Parent = humanoidRootPart

			-- Environmental effect - flicker lights
			if Lighting:FindFirstChild("PointLight") then
				local lightFlicker = TweenService:Create(Lighting.PointLight,
					TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
					{Brightness = 0.2}
				)
				lightFlicker:Play()
			end
		end
	else
		-- Remove rage effects if health is restored
		local rageAura = humanoidRootPart:FindFirstChild("RageAura")
		if rageAura then 
			rageAura:Destroy()

			-- Reset resistances to base values when rage ends
			local damageResistanceValue = enemy:FindFirstChild("DamageResistance")
			local defenseResistanceValue = enemy:FindFirstChild("DefenseResistance")

			if damageResistanceValue and not isPhasing then
				damageResistanceValue.Value = baseDamageResistance
			end

			if defenseResistanceValue and not isPhasing then
				defenseResistanceValue.Value = baseDefenseResistance
			end

			--print("😌 Rage ended: Resistances returned to base values")
		end
	end
end

-- Wandering functions (simplified for boss)
local function getRandomWanderPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random(20, maxWanderDistance)
	return originPoint + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
end

local function updateAIState()
	local player, distance = pathfinding:getClosestPlayer()

	if player and distance <= maxDistance then
		if currentState == "wandering" or currentState == "lost" then
			currentState = "chasing"
			sayMessage(CHASE_MESSAGE)
			pathfinding:resumeMovement()
		end
	else
		if currentState == "chasing" or currentState == "attacking" then
			currentState = "lost"
			sayMessage(LOST_TARGET_MESSAGE)
		elseif currentState == "lost" and tick() - lastChatTime > 8 then
			currentState = "wandering"
		end
	end
end

-- Initialize systems in correct order
setupResistanceSystem() -- Set up NEW resistance system FIRST
setGhostAppearance()
setupTouchDamage()
pathfinding:startMovement()

-- Special attacks loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(3)

		if not isPerformingSpecialMove then
			local player, distance = pathfinding:getClosestPlayer()
			if player then
				local attackChance = math.random()

				-- Soul Drain (close range, high damage + heal)
				if distance < 30 and attackChance > 0.85 and tick() - lastSoulDrainTime > soulDrainCooldown then
					performSoulDrain()
					-- Spectral Charge (medium range, teleport attack)
				elseif distance > 15 and distance < 35 and attackChance > 0.75 then
					performSpectralCharge()
					-- Phase Walk (any range, defensive)
				elseif attackChance > 0.8 then
					performPhaseWalk()
				end
			end
		end
	end
end)

-- Poltergeist rage checker
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2)
		checkPoltergeistRage()
	end
end)

-- Main AI loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1)
		updateAIState()
	end
end)

-- Cleanup when enemy dies
humanoid.Died:Connect(function()
	sayMessage("The veil... closes... but I shall return...")

	if pathfinding then
		pathfinding:destroy()
	end

	-- Clean up any remaining effects
	for _, effect in pairs({"RageAura", "BerserkerEffect"}) do
		local foundEffect = humanoidRootPart:FindFirstChild(effect)
		if foundEffect then foundEffect:Destroy() end
	end

	-- Death effect
	local deathOrb = Instance.new("Part")
	deathOrb.Anchored = true
	deathOrb.CanCollide = false
	deathOrb.Transparency = 0.5
	deathOrb.Material = Enum.Material.Neon
	deathOrb.BrickColor = BrickColor.new("White")
	deathOrb.Shape = Enum.PartType.Ball
	deathOrb.Size = Vector3.new(1, 1, 1)
	deathOrb.CFrame = humanoidRootPart.CFrame
	deathOrb.Parent = workspace

	local deathTween = TweenService:Create(deathOrb,
		TweenInfo.new(3, Enum.EasingStyle.Sine),
		{Size = Vector3.new(30, 30, 30), Transparency = 1}
	)
	deathTween:Play()

	task.wait(3)
	deathOrb:Destroy()
end)