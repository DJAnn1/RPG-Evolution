-- GHOST OVERLORD BOSS SCRIPT - Enhanced Version (FIXED)
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local enemy = script.Parent
local humanoidRootPart = enemy.HumanoidRootPart
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy.Humanoid

-- GHOST OVERLORD BOSS STATS - Balanced
humanoid.MaxHealth = 3000 -- Balanced boss health
humanoid.Health = 3000
humanoid.WalkSpeed = 25 -- Balanced base speed

local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")

-- Enhanced Ghost Overlord properties with SUPREME resistance system
local ghostTransparency = 0.6
local phaseTransparency = 0.98
local voidFormTransparency = 0.99
local isPhasing = false
local isInVoidForm = false
local isInvisible = false
local lastPhaseTime = 0
local phaseCooldown = 8 -- Reduced cooldown for boss
local baseDamageResistance = 0.65 -- 65% base damage resistance (massive)
local phaseDamageResistance = 0.85 -- 85% damage resistance when phasing
local voidFormDamageResistance = 0.95 -- 95% damage resistance in void form
local baseDefenseResistance = 0.70 -- 70% base defense resistance
local phaseDefenseResistance = 0.90 -- 90% defense resistance when phasing
local voidFormDefenseResistance = 0.98 -- 98% defense resistance in void form

-- Boss-level wandering variables
local originPoint = humanoidRootPart.Position
local maxWanderDistance = 120 -- Massive range for overlord
local wanderCooldown = 0
local lastChatTime = 0
local chatCooldown = 2
local currentState = "wandering"
local isWandering = false
local wanderPath = nil
local wanderWaypointIndex = 1
local wanderConnection = nil

-- Enhanced boss phases
local currentPhase = 1
local maxPhase = 3
local phaseTransitionHealth = {0.67, 0.33} -- Phase transitions at 67% and 33% health

-- Ghost Overlord themed messages
local WANDER_MESSAGES = {
	"I am the shadow between worlds...",
	"Reality bends to my will...",
	"The boundary between life and death... dissolves...",
	"I have consumed a thousand souls...",
	"*reality distorts around the presence*"
}

local CHASE_MESSAGE = "YOUR EXISTENCE ENDS NOW!"
local ATTACK_MESSAGE = "WITNESS TRUE DESPAIR!"
local LOST_TARGET_MESSAGE = "You only delay the inevitable..."
local PHASE_MESSAGE = "I TRANSCEND YOUR MORTAL REALM!"
local VOID_FORM_MESSAGE = "BEHOLD THE VOID INCARNATE!"
local ENRAGE_MESSAGE = "THE FABRIC OF REALITY TEARS ASUNDER!"

-- Boss detection and combat ranges
local maxDistance = 80 -- Massive detection range
local combatRange = 100
local disengageDistance = 120 -- Distance at which boss gives up chase
local deBounce = false
local lastSpecialAttackTime = 0
local specialAttackCooldown = 6 -- Faster special attacks
local isPerformingSpecialMove = false
local lastSoulDrainTime = 0
local soulDrainCooldown = 12
local lastVoidRiftTime = 0
local voidRiftCooldown = 18
local lastShadowArmyTime = 0
local shadowArmyCooldown = 25
local lastRealityStormTime = 0
local realityStormCooldown = 35

-- NEW boss-specific variables
local shadowMinions = {}
local isChanneling = false
local overlordAura = nil
local lastDamageTime = 0 -- Track when boss last took damage
local combatTimeout = 15 -- Seconds before boss disengages if no damage taken
local lastPlayerSeenTime = 0 -- Track when boss last saw a player

-- Setup SUPREME resistance system for Ghost Overlord
local function setupSupremeResistanceSystem()
	-- Remove any old resistance systems
	local oldDefenseEffectiveness = enemy:FindFirstChild("defenseEffectiveness")
	if oldDefenseEffectiveness then
		oldDefenseEffectiveness:Destroy()
	end

	-- Set up SUPREME damage resistance
	local damageResistanceValue = Instance.new("NumberValue")
	damageResistanceValue.Name = "DamageResistance"
	damageResistanceValue.Value = baseDamageResistance
	damageResistanceValue.Parent = enemy

	-- Set up SUPREME defense resistance
	local defenseResistanceValue = Instance.new("NumberValue")
	defenseResistanceValue.Name = "DefenseResistance"
	defenseResistanceValue.Value = baseDefenseResistance
	defenseResistanceValue.Parent = enemy

	-- Boss immunity tags
	local magicResistance = Instance.new("NumberValue")
	magicResistance.Name = "MagicResistance"
	magicResistance.Value = 0.45 -- 45% magic resistance
	magicResistance.Parent = enemy

	local statusImmunity = Instance.new("BoolValue")
	statusImmunity.Name = "StatusImmune"
	statusImmunity.Value = true -- Immune to stuns, slows, etc.
	statusImmunity.Parent = enemy
end

-- Enhanced ghost overlord appearance with subtle boss effects
local function setOverlordAppearance()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = ghostTransparency
			part.CanCollide = false
			part.Material = Enum.Material.ForceField

			-- Subtle overlord ghostly glow
			local pointLight = Instance.new("PointLight")
			pointLight.Brightness = 1.2
			pointLight.Color = Color3.fromRGB(75, 0, 130) -- Dark purple
			pointLight.Range = 15
			pointLight.Parent = part

			-- Subtle dark energy particles
			local attachment = Instance.new("Attachment")
			attachment.Parent = part

			local particles = Instance.new("ParticleEmitter")
			particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
			particles.Color = ColorSequence.new(Color3.fromRGB(138, 43, 226))
			particles.Size = NumberSequence.new(0.8)
			particles.Lifetime = NumberRange.new(1, 2)
			particles.Rate = 15
			particles.VelocityInheritance = 0.3
			particles.Parent = attachment
		end
	end

	-- Create subtle overlord aura (much less obtrusive)
	overlordAura = Instance.new("SelectionBox")
	overlordAura.Adornee = humanoidRootPart
	overlordAura.Color3 = Color3.fromRGB(75, 0, 130)
	overlordAura.LineThickness = 0.1
	overlordAura.Transparency = 0.8
	overlordAura.Parent = humanoidRootPart
end

-- Initialize enhanced pathfinding with boss parameters
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = maxDistance,
	combatMaxDistance = combatRange,
	walkSpeed = 25, -- Balanced speed
	combatWalkSpeed = 40, -- Fast in combat but not excessive
	pathUpdateInterval = 0.8,
	combatPathUpdateInterval = 0.3,
	stuckThreshold = 2,
	waypointDistance = 8,
	combatDuration = 30,
	predictionTime = 1.2
})

local function sayMessage(message)
	if tick() - lastChatTime >= chatCooldown then
		-- Removed Chat:Chat to disable chat bubbles
		lastChatTime = tick()

		-- Check if any players are close enough to see the message
		local nearbyPlayer = false
		local messageRange = 40 -- Distance at which players can see floating messages

		for _, player in pairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local distance = (player.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
				if distance <= messageRange then
					nearbyPlayer = true
					break
				end
			end
		end

		-- Only show floating text if players are nearby
		if nearbyPlayer then
			-- Stylish purple floating messages only
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(0, 200, 0, 50)
			gui.StudsOffset = Vector3.new(0, 6, 0)
			gui.Parent = enemy.Head

			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = message
			textLabel.TextColor3 = Color3.fromRGB(138, 43, 226)
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.Antique
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			textLabel.Parent = gui

			-- Animate text
			textLabel.TextTransparency = 1
			local textTween = TweenService:Create(textLabel,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine),
				{TextTransparency = 0}
			)
			textTween:Play()

			Debris:AddItem(gui, 3)
		end
	end
end

-- VOID FORM - Ultimate defensive ability
local function performVoidForm()
	if isInVoidForm or isPhasing or tick() - lastPhaseTime < phaseCooldown then return end

	isInVoidForm = true
	isPhasing = true -- Prevent other abilities
	lastPhaseTime = tick()
	sayMessage(VOID_FORM_MESSAGE)

	-- Maximum resistance during void form
	local damageResistanceValue = enemy:FindFirstChild("DamageResistance")
	local defenseResistanceValue = enemy:FindFirstChild("DefenseResistance")

	if damageResistanceValue then
		damageResistanceValue.Value = voidFormDamageResistance
	end

	if defenseResistanceValue then
		defenseResistanceValue.Value = voidFormDefenseResistance
	end

	-- Become nearly invisible and create void distortion
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(1, Enum.EasingStyle.Sine), 
				{Transparency = voidFormTransparency}
			)
			tween:Play()
			part.CanCollide = false
		end
	end

	-- Void distortion effect
	local voidSphere = Instance.new("Part")
	voidSphere.Name = "VoidDistortion"
	voidSphere.Anchored = true
	voidSphere.CanCollide = false
	voidSphere.Transparency = 0.8
	voidSphere.Material = Enum.Material.Neon
	voidSphere.BrickColor = BrickColor.new("Really black")
	voidSphere.Shape = Enum.PartType.Ball
	voidSphere.Size = Vector3.new(20, 20, 20)
	voidSphere.CFrame = humanoidRootPart.CFrame
	voidSphere.Parent = workspace

	-- Void sphere pulsing
	local voidTween = TweenService:Create(voidSphere,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Size = Vector3.new(25, 25, 25), Transparency = 0.9}
	)
	voidTween:Play()

	-- Void form lasts 6 seconds
	task.wait(6)

	-- Return to base resistance values
	if damageResistanceValue then
		damageResistanceValue.Value = baseDamageResistance
	end

	if defenseResistanceValue then
		defenseResistanceValue.Value = baseDefenseResistance
	end

	-- Return to normal appearance
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(1, Enum.EasingStyle.Sine), 
				{Transparency = ghostTransparency}
			)
			tween:Play()
		end
	end

	voidSphere:Destroy()
	isInVoidForm = false
	isPhasing = false
end

-- VOID RIFT - Creates damaging portals that chase players
local function performVoidRift()
	if isPerformingSpecialMove or tick() - lastVoidRiftTime < voidRiftCooldown then return end

	isPerformingSpecialMove = true
	lastVoidRiftTime = tick()
	sayMessage("REALITY TEARS OPEN!")

	-- Create multiple void rifts
	for i = 1, 3 do
		local player = pathfinding:getClosestPlayer()
		if not player then break end

		local rift = Instance.new("Part")
		rift.Name = "VoidRift"
		rift.Anchored = true
		rift.CanCollide = false
		rift.Transparency = 0.3
		rift.Material = Enum.Material.Neon
		rift.BrickColor = BrickColor.new("Dark indigo")
		rift.Shape = Enum.PartType.Cylinder
		rift.Size = Vector3.new(2, 15, 15)

		-- Position near player
		local playerPos = player.Character.HumanoidRootPart.Position
		rift.CFrame = CFrame.new(playerPos + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)))
		rift.Parent = workspace

		-- Rift visual effects
		local light = Instance.new("PointLight")
		light.Brightness = 3
		light.Color = Color3.fromRGB(75, 0, 130)
		light.Range = 20
		light.Parent = rift

		-- Rift damage zone (slower damage + player validation)
		local lastDamageTime = 0
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if tick() - lastDamageTime >= 1.5 then -- Damage every 1.5 seconds instead of 0.5
				for _, p in pairs(Players:GetPlayers()) do
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") then
						-- Check if player is alive and properly spawned
						if p.Character.Humanoid.Health > 0 then
							local distance = (p.Character.HumanoidRootPart.Position - rift.Position).Magnitude
							if distance < 12 then
								-- Reduced void damage
								local success, result = DamageService:SmartApplyDamage(enemy, p, 20)
								lastDamageTime = tick()
							end
						end
					end
				end
			end
		end)

		-- Move rift toward players (with better cleanup)
		task.spawn(function()
			for j = 1, 40 do -- Lasts 20 seconds
				-- Check if boss is still alive, if not, destroy rift
				if not enemy or not enemy.Parent or humanoid.Health <= 0 then
					connection:Disconnect()
					if rift and rift.Parent then
						rift:Destroy()
					end
					return
				end

				local closestPlayer = pathfinding:getClosestPlayer()
				if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart") then
					-- Only chase living players
					if closestPlayer.Character:FindFirstChild("Humanoid") and closestPlayer.Character.Humanoid.Health > 0 then
						local targetPos = closestPlayer.Character.HumanoidRootPart.Position
						local direction = (targetPos - rift.Position).Unit
						rift.CFrame = rift.CFrame + direction * 2
					end
				end
				task.wait(0.5)
			end

			connection:Disconnect()
			if rift and rift.Parent then
				rift:Destroy()
			end
		end)

		task.wait(0.5) -- Stagger rift creation
	end

	task.wait(2)
	isPerformingSpecialMove = false
end

-- SHADOW ARMY - Summons shadow minions
local function performShadowArmy()
	if isPerformingSpecialMove or tick() - lastShadowArmyTime < shadowArmyCooldown then return end

	isPerformingSpecialMove = true
	lastShadowArmyTime = tick()
	sayMessage("ARISE, MY SHADOW LEGION!")

	-- Clear existing minions
	for _, minion in pairs(shadowMinions) do
		if minion and minion.Parent then
			minion:Destroy()
		end
	end
	shadowMinions = {}

	-- Get the ghost minion template
	local ghostMinionTemplate = game.ServerStorage.enemies.area2.ghostMinion
	if not ghostMinionTemplate then
		warn("Ghost minion template not found in ServerStorage.Enemies.Area2.GhostMinion")
		isPerformingSpecialMove = false
		return
	end

	-- Summon shadow minions using the proper model
	for i = 1, 4 do
		local minion = ghostMinionTemplate:Clone()
		minion.Name = "ShadowMinion"

		-- Make it darker/more shadowy
		for _, part in pairs(minion:GetDescendants()) do
			if part:IsA("BasePart") then
				part.BrickColor = BrickColor.new("Really black")
				part.Material = Enum.Material.Neon
				-- Make it slightly transparent for shadow effect
				part.Transparency = math.min(part.Transparency + 0.3, 0.9)
			end
		end

		-- Position around boss at ground level
		local angle = (i - 1) * (math.pi * 2 / 4)
		local spawnPos = humanoidRootPart.Position + Vector3.new(
			math.cos(angle) * 15,
			0,
			math.sin(angle) * 15
		)

		-- Raycast to find ground
		local raycast = workspace:Raycast(spawnPos + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
		if raycast then
			spawnPos = raycast.Position + Vector3.new(0, 3, 0) -- Adjust height for minion size
		end

		minion:SetPrimaryPartCFrame(CFrame.new(spawnPos))
		minion.Parent = workspace

		-- Get minion's humanoid and humanoidRootPart
		local minionHumanoid = minion:FindFirstChild("Humanoid")
		local minionHRP = minion:FindFirstChild("HumanoidRootPart")

		if not minionHumanoid or not minionHRP then
			warn("Minion missing Humanoid or HumanoidRootPart")
			minion:Destroy()
			continue
		end

		-- Set minion stats
		minionHumanoid.MaxHealth = 50
		minionHumanoid.Health = 50
		minionHumanoid.WalkSpeed = 20

		-- Add shadow minion glow effect
		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(138, 43, 226)
		light.Range = 8
		light.Parent = minionHRP

		-- Shadow particles
		local attachment = Instance.new("Attachment")
		attachment.Parent = minionHRP

		local particles = Instance.new("ParticleEmitter")
		particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
		particles.Color = ColorSequence.new(Color3.fromRGB(75, 0, 130))
		particles.Size = NumberSequence.new(0.5)
		particles.Lifetime = NumberRange.new(0.5, 1)
		particles.Rate = 10
		particles.Parent = attachment

		-- Improved minion AI using Humanoid movement
		task.spawn(function()
			local lifetime = 0
			local maxLifetime = 30 -- 30 second lifetime

			while lifetime < maxLifetime and minion.Parent and minionHumanoid.Health > 0 do
				local closestPlayer = pathfinding:getClosestPlayer()
				if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local targetPos = closestPlayer.Character.HumanoidRootPart.Position

					-- Use Humanoid:MoveTo for proper pathfinding
					minionHumanoid:MoveTo(targetPos)

					-- Damage on contact
					local distance = (targetPos - minionHRP.Position).Magnitude
					if distance < 8 then
						local success = DamageService:SmartApplyDamage(enemy, closestPlayer, 30)
						-- Minion sacrifices itself after attack with death effect
						local deathEffect = Instance.new("Explosion")
						deathEffect.Position = minionHRP.Position
						deathEffect.BlastRadius = 8
						deathEffect.BlastPressure = 0
						deathEffect.Parent = workspace
						break
					end
				end

				task.wait(0.2)
				lifetime = lifetime + 0.2
			end

			-- Remove minion from tracking
			for j, m in pairs(shadowMinions) do
				if m == minion then
					table.remove(shadowMinions, j)
					break
				end
			end

			-- Clean destruction
			if minion and minion.Parent then
				minion:Destroy()
			end
		end)

		table.insert(shadowMinions, minion)
		task.wait(0.3) -- Stagger summons
	end

	task.wait(1)
	isPerformingSpecialMove = false
end

-- REALITY STORM - Ultimate area attack
local function performRealityStorm()
	if isPerformingSpecialMove or tick() - lastRealityStormTime < realityStormCooldown then return end

	isPerformingSpecialMove = true
	lastRealityStormTime = tick()
	isChanneling = true
	pathfinding:pauseMovement()

	sayMessage("THE STORM OF OBLIVION APPROACHES!")

	-- Channeling effect
	local channelingOrb = Instance.new("Part")
	channelingOrb.Name = "RealityOrb"
	channelingOrb.Anchored = true
	channelingOrb.CanCollide = false
	channelingOrb.Transparency = 0.2
	channelingOrb.Material = Enum.Material.Neon
	channelingOrb.BrickColor = BrickColor.new("Royal purple")
	channelingOrb.Shape = Enum.PartType.Ball
	channelingOrb.Size = Vector3.new(3, 3, 3)
	channelingOrb.CFrame = humanoidRootPart.CFrame + Vector3.new(0, 8, 0)
	channelingOrb.Parent = workspace

	-- Grow channeling orb
	local channelTween = TweenService:Create(channelingOrb,
		TweenInfo.new(4, Enum.EasingStyle.Sine),
		{Size = Vector3.new(15, 15, 15)}
	)
	channelTween:Play()

	-- Environmental effects during channeling (NO LIGHTING CHANGES)
	-- Removed lighting modifications to prevent interference

	task.wait(4) -- Channel time

	sayMessage("REALITY COLLAPSES!")

	-- Massive explosion effect
	local storm = Instance.new("Explosion")
	storm.Position = humanoidRootPart.Position
	storm.BlastRadius = 60
	storm.BlastPressure = 0
	storm.Visible = false
	storm.Parent = workspace

	-- Visual storm effect
	local stormSphere = Instance.new("Part")
	stormSphere.Name = "RealityStorm"
	stormSphere.Anchored = true
	stormSphere.CanCollide = false
	stormSphere.Transparency = 0.4
	stormSphere.Material = Enum.Material.Neon
	stormSphere.BrickColor = BrickColor.new("Dark indigo")
	stormSphere.Shape = Enum.PartType.Ball
	stormSphere.Size = Vector3.new(5, 5, 5)
	stormSphere.CFrame = humanoidRootPart.CFrame
	stormSphere.Parent = workspace

	-- Expand storm
	local stormTween = TweenService:Create(stormSphere,
		TweenInfo.new(2, Enum.EasingStyle.Sine),
		{Size = Vector3.new(120, 120, 120), Transparency = 0.8}
	)
	stormTween:Play()

	-- Devastating damage to all players in massive range
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
			if distance <= 60 then
				-- Multiple damage waves
				for wave = 1, 3 do
					local damage = 120 - (wave * 20) -- 120, 100, 80 damage per wave
					local success = DamageService:SmartApplyDamage(enemy, player, damage)
					task.wait(0.7)
				end
			end
		end
	end

	-- Clean up effects (NO LIGHTING RESTORATION)
	channelingOrb:Destroy()
	task.wait(2)
	stormSphere:Destroy()

	isChanneling = false
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
end

-- Enhanced Soul Drain with much larger range and effect
local function performEnhancedSoulDrain()
	if isPerformingSpecialMove or tick() - lastSoulDrainTime < soulDrainCooldown then return end

	isPerformingSpecialMove = true
	lastSoulDrainTime = tick()

	sayMessage("YOUR ESSENCE SUSTAINS MY ETERNAL HUNGER!")

	-- Much larger soul drain effect
	local soulDrainEffect = Instance.new("Explosion")
	soulDrainEffect.Position = humanoidRootPart.Position
	soulDrainEffect.BlastRadius = 45 -- Much larger
	soulDrainEffect.BlastPressure = 0
	soulDrainEffect.Visible = false
	soulDrainEffect.Parent = workspace

	-- Enhanced visual effect
	local drainOrb = Instance.new("Part")
	drainOrb.Name = "SoulDrainOrb"
	drainOrb.Anchored = true
	drainOrb.CanCollide = false
	drainOrb.Transparency = 0.2
	drainOrb.Material = Enum.Material.Neon
	drainOrb.BrickColor = BrickColor.new("Bright red")
	drainOrb.Shape = Enum.PartType.Ball
	drainOrb.Size = Vector3.new(2, 2, 2)
	drainOrb.CFrame = humanoidRootPart.CFrame
	drainOrb.Parent = workspace

	-- Expand the orb massively
	local expandTween = TweenService:Create(drainOrb,
		TweenInfo.new(3, Enum.EasingStyle.Sine),
		{Size = Vector3.new(90, 90, 90), Transparency = 0.9}
	)
	expandTween:Play()

	-- Enhanced damage and healing
	local totalHealing = 0
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
			if distance <= 45 then
				local success = DamageService:SmartApplyDamage(enemy, player, 90)
				if success then
					totalHealing = totalHealing + 200 -- Much more healing
				end
			end
		end
	end

	-- Heal the overlord
	humanoid.Health = math.min(humanoid.Health + totalHealing, humanoid.MaxHealth)

	-- Clean up effect
	task.wait(3)
	drainOrb:Destroy()
	isPerformingSpecialMove = false
end

-- Enhanced spectral charge with area damage
local function performEnhancedSpectralCharge()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 60 or distance < 8 then return end

	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	sayMessage("DEATH COMES FROM ALL DIRECTIONS!")

	-- Disappear with enhanced effect
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(0.2, Enum.EasingStyle.Quad), 
				{Transparency = 1}
			)
			tween:Play()
		end
	end

	task.wait(0.8)

	-- Teleport to random position around player
	local playerChar = player.Character
	local playerPos = playerChar.HumanoidRootPart.Position
	local angle = math.random() * math.pi * 2
	local teleportPos = playerPos + Vector3.new(
		math.cos(angle) * 12,
		0,
		math.sin(angle) * 12
	)

	humanoidRootPart.CFrame = CFrame.new(teleportPos, playerPos)

	-- Reappear with shockwave
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, 
				TweenInfo.new(0.2, Enum.EasingStyle.Quad), 
				{Transparency = ghostTransparency}
			)
			tween:Play()
		end
	end

	-- Shockwave damage to all nearby players
	task.wait(0.2)
	for _, p in pairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local dist = (p.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
			if dist < 20 then
				local success = DamageService:SmartApplyDamage(enemy, p, 85)
			end
		end
	end

	task.wait(1)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
end

-- Enhanced touch damage with boss-level power
local function setupEnhancedTouchDamage()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if deBounce or isPerformingSpecialMove or isChanneling then return end

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

					-- Boss-level damage
					local baseDamage = 85 + (currentPhase * 15) -- Increases with phase
					local actualDamage = baseDamage + math.random(-10, 15)

					local success = DamageService:SmartApplyDamage(enemy, player, actualDamage)

					-- Higher chance for special abilities after attacking
					if math.random() > 0.5 then
						if math.random() > 0.7 then
							task.spawn(performVoidForm)
						else
							task.spawn(performEnhancedSpectralCharge)
						end
					end

					task.wait(0.8) -- Faster attack rate
					deBounce = false
				end    
			end)
		end
	end
end

-- Phase transition system (FIXED)
local function checkPhaseTransition()
	local healthPercent = humanoid.Health / humanoid.MaxHealth

	if currentPhase == 1 and healthPercent <= phaseTransitionHealth[1] then
		currentPhase = 2
		sayMessage("PHASE TWO: THE VEIL GROWS THIN!")

		-- Phase 2 enhancements
		specialAttackCooldown = 4
		soulDrainCooldown = 8
		voidRiftCooldown = 12

		-- Increased resistances
		local damageRes = enemy:FindFirstChild("DamageResistance")
		local defenseRes = enemy:FindFirstChild("DefenseResistance")
		if damageRes then damageRes.Value = math.min(baseDamageResistance + 0.1, 0.75) end
		if defenseRes then defenseRes.Value = math.min(baseDefenseResistance + 0.1, 0.8) end

		-- Enhanced speed (balanced)
		pathfinding:updateConfig({
			combatWalkSpeed = 45
		})

	elseif currentPhase == 2 and healthPercent <= phaseTransitionHealth[2] then
		currentPhase = 3
		sayMessage("FINAL PHASE: REALITY ITSELF BOWS TO ME!")

		-- Phase 3 ultimate enhancements
		specialAttackCooldown = 2
		soulDrainCooldown = 5
		voidRiftCooldown = 8
		shadowArmyCooldown = 15
		realityStormCooldown = 20

		-- Maximum resistances
		local damageRes = enemy:FindFirstChild("DamageResistance")
		local defenseRes = enemy:FindFirstChild("DefenseResistance")
		if damageRes then damageRes.Value = 0.8 end -- 80% damage resistance
		if defenseRes then defenseRes.Value = 0.85 end -- 85% defense resistance

		-- Ultimate speed (balanced)
		pathfinding:updateConfig({
			combatWalkSpeed = 55
		})

		-- Phase 3 environmental effects
		local phase3Aura = Instance.new("Fire")
		phase3Aura.Name = "Phase3Aura"
		phase3Aura.Size = 15
		phase3Aura.Heat = 15
		phase3Aura.Color = Color3.fromRGB(75, 0, 130)
		phase3Aura.SecondaryColor = Color3.fromRGB(138, 43, 226)
		phase3Aura.Parent = humanoidRootPart

		-- Reality distortion effect (NO LIGHTING CHANGES)
		-- Removed TimeOfDay modification to prevent interference

		-- Continuous void rifts in phase 3
		task.spawn(function()
			while currentPhase == 3 and humanoid.Health > 0 do
				task.wait(6)
				if not isPerformingSpecialMove then
					task.spawn(performVoidRift)
				end
			end
		end)
	end
end

-- Ultimate Overlord Rage when health is very low
local function checkOverlordRage()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < 0.15 then -- Below 15% health - FINAL STAND
		if not humanoidRootPart:FindFirstChild("OverlordRage") then
			sayMessage(ENRAGE_MESSAGE)

			-- MAXIMUM EVERYTHING (balanced)
			pathfinding:updateConfig({
				combatWalkSpeed = 70 -- Fast but not insane
			})
			specialAttackCooldown = 1
			soulDrainCooldown = 3
			voidRiftCooldown = 4
			shadowArmyCooldown = 8
			realityStormCooldown = 12
			phaseCooldown = 3

			-- ULTIMATE resistances
			local damageResistanceValue = enemy:FindFirstChild("DamageResistance")
			local defenseResistanceValue = enemy:FindFirstChild("DefenseResistance")

			if damageResistanceValue and not isInVoidForm then
				damageResistanceValue.Value = 0.9 -- 90% damage resistance
			end

			if defenseResistanceValue and not isInVoidForm then
				defenseResistanceValue.Value = 0.95 -- 95% defense resistance
			end

			-- Ultimate rage aura
			local rageAura = Instance.new("Fire")
			rageAura.Name = "OverlordRage"
			rageAura.Size = 25
			rageAura.Heat = 25
			rageAura.Color = Color3.fromRGB(138, 43, 226)
			rageAura.SecondaryColor = Color3.fromRGB(255, 0, 100)
			rageAura.Parent = humanoidRootPart

			-- Screen shake effect for all players
			for _, player in pairs(Players:GetPlayers()) do
				if player.Character then
					local shake = Instance.new("Explosion")
					shake.Position = player.Character.HumanoidRootPart.Position
					shake.BlastRadius = 0
					shake.BlastPressure = 500000
					shake.Parent = workspace
				end
			end

			-- Environmental chaos (NO LIGHTING CHANGES)
			-- Removed lighting modifications to prevent interference

			-- Continuous special attacks during rage
			task.spawn(function()
				while humanoid.Health > 0 and humanoid.Health / humanoid.MaxHealth < 0.15 do
					task.wait(2)
					if not isPerformingSpecialMove then
						local attackRoll = math.random()
						if attackRoll > 0.8 then
							task.spawn(performRealityStorm)
						elseif attackRoll > 0.6 then
							task.spawn(performShadowArmy)
						elseif attackRoll > 0.4 then
							task.spawn(performVoidRift)
						else
							task.spawn(performEnhancedSoulDrain)
						end
					end
				end
			end)
		end
	end
end

-- Enhanced wandering for boss
local function getRandomWanderPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random(30, maxWanderDistance)
	return originPoint + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
end

-- Enhanced AI state management with disengagement
local function updateAIState()
	local player, distance = pathfinding:getClosestPlayer()

	if player and distance <= maxDistance then
		lastPlayerSeenTime = tick()

		if currentState == "wandering" or currentState == "lost" then
			currentState = "chasing"
			sayMessage(CHASE_MESSAGE)
			pathfinding:resumeMovement()
		end
	else
		-- Player is far away or no player found
		if currentState == "chasing" or currentState == "attacking" then
			-- Check if we should disengage
			local timeSinceLastDamage = tick() - lastDamageTime
			local timeSinceLastPlayer = tick() - lastPlayerSeenTime

			-- Disengage if no damage taken for a while AND no players seen recently
			if timeSinceLastDamage > combatTimeout and timeSinceLastPlayer > 8 then
				currentState = "disengaging"
				sayMessage("You flee like cowards... I return to the shadows...")

				-- Cancel any ongoing special moves
				isPerformingSpecialMove = false
				isChanneling = false

				-- Destroy any active minions
				for _, minion in pairs(shadowMinions) do
					if minion and minion.Parent then
						minion:Destroy()
					end
				end
				shadowMinions = {}

				pathfinding:pauseMovement()

				-- After a short delay, return to wandering
				task.spawn(function()
					task.wait(3)
					if currentState == "disengaging" then
						currentState = "wandering"
						pathfinding:resumeMovement()
					end
				end)
			else
				currentState = "lost"
				sayMessage(LOST_TARGET_MESSAGE)
			end
		elseif currentState == "lost" and tick() - lastChatTime > 6 then
			currentState = "wandering"
		end
	end
end

-- Initialize all systems in correct order
setupSupremeResistanceSystem() -- Set up SUPREME resistance system FIRST
setOverlordAppearance()
setupEnhancedTouchDamage()
pathfinding:startMovement()

-- Enhanced special attacks main loop with disengagement check
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2)

		-- Don't perform special attacks if disengaging or wandering
		if not isPerformingSpecialMove and not isChanneling and 
			currentState ~= "disengaging" and currentState ~= "wandering" then

			local player, distance = pathfinding:getClosestPlayer()
			if player then
				local attackChance = math.random()
				local phaseMultiplier = currentPhase * 0.1 -- Higher chance in later phases

				-- Reality Storm (ultimate attack, longer range)
				if distance < 50 and attackChance > (0.92 - phaseMultiplier) and tick() - lastRealityStormTime > realityStormCooldown then
					task.spawn(performRealityStorm)

					-- Shadow Army (medium range, overwhelming force)
				elseif distance < 40 and attackChance > (0.85 - phaseMultiplier) and tick() - lastShadowArmyTime > shadowArmyCooldown then
					task.spawn(performShadowArmy)

					-- Void Rift (medium range, portal attacks)
				elseif distance > 20 and distance < 45 and attackChance > (0.8 - phaseMultiplier) and tick() - lastVoidRiftTime > voidRiftCooldown then
					task.spawn(performVoidRift)

					-- Enhanced Soul Drain (close-medium range, healing + damage)
				elseif distance < 35 and attackChance > (0.75 - phaseMultiplier) and tick() - lastSoulDrainTime > soulDrainCooldown then
					task.spawn(performEnhancedSoulDrain)

					-- Enhanced Spectral Charge (medium range, teleport attack)
				elseif distance > 15 and distance < 40 and attackChance > (0.7 - phaseMultiplier) then
					task.spawn(performEnhancedSpectralCharge)

					-- Void Form (any range, ultimate defense)
				elseif attackChance > (0.85 - phaseMultiplier) then
					task.spawn(performVoidForm)
				end
			end
		end
	end
end)

-- Phase transition checker
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1)
		checkPhaseTransition()
	end
end)

-- Overlord rage checker
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1.5)
		checkOverlordRage()
	end
end)

-- Main AI loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(0.8) -- Faster AI updates for boss
		updateAIState()
	end
end)

-- Continuous wandering messages (only when actually wandering)
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(8)
		if currentState == "wandering" and not isPerformingSpecialMove then
			sayMessage(WANDER_MESSAGES[math.random(1, #WANDER_MESSAGES)])
		end
	end
end)

-- Track damage taken to maintain combat state
humanoid.HealthChanged:Connect(function(newHealth)
	if newHealth < humanoid.Health then
		lastDamageTime = tick() -- Update last damage time
		-- If boss was disengaging or wandering, re-enter combat
		if currentState == "disengaging" or currentState == "wandering" then
			local player, distance = pathfinding:getClosestPlayer()
			if player and distance <= combatRange then
				currentState = "chasing"
				sayMessage("You dare attack me while I retreat?! FACE MY WRATH!")
				pathfinding:resumeMovement()
			end
		end
	end
end)

-- Enhanced cleanup when overlord dies
humanoid.Died:Connect(function()
	sayMessage("This... is not... the end... I shall return from the void eternal...")

	if pathfinding then
		pathfinding:destroy()
	end

	-- Clean up all minions
	for _, minion in pairs(shadowMinions) do
		if minion and minion.Parent then
			minion:Destroy()
		end
	end

	-- Clean up all effects
	for _, effect in pairs({"OverlordRage", "Phase3Aura", "VoidDistortion", "RageAura"}) do
		local foundEffect = humanoidRootPart:FindFirstChild(effect)
		if foundEffect then foundEffect:Destroy() end
	end

	-- Epic death sequence
	local deathSequence = {
		{size = Vector3.new(1, 1, 1), color = BrickColor.new("Royal purple"), time = 1},
		{size = Vector3.new(20, 20, 20), color = BrickColor.new("Dark indigo"), time = 2},
		{size = Vector3.new(50, 50, 50), color = BrickColor.new("Really black"), time = 3},
		{size = Vector3.new(100, 100, 100), color = BrickColor.new("White"), time = 2}
	}

	for i, phase in ipairs(deathSequence) do
		local deathOrb = Instance.new("Part")
		deathOrb.Anchored = true
		deathOrb.CanCollide = false
		deathOrb.Transparency = 0.3
		deathOrb.Material = Enum.Material.Neon
		deathOrb.BrickColor = phase.color
		deathOrb.Shape = Enum.PartType.Ball
		deathOrb.Size = Vector3.new(1, 1, 1)
		deathOrb.CFrame = humanoidRootPart.CFrame
		deathOrb.Parent = workspace

		local deathTween = TweenService:Create(deathOrb,
			TweenInfo.new(phase.time, Enum.EasingStyle.Sine),
			{Size = phase.size, Transparency = 1}
		)
		deathTween:Play()

		task.wait(phase.time)
		deathOrb:Destroy()
	end

	-- Final screen shake for all players
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character then
			local finalShake = Instance.new("Explosion")
			finalShake.Position = player.Character.HumanoidRootPart.Position
			finalShake.BlastRadius = 0
			finalShake.BlastPressure = 1000000
			finalShake.Parent = workspace
		end
	end

	-- Restore lighting (REMOVED - no lighting changes made)
	-- No lighting restoration needed since we don't modify lighting
end)