-- ZOMBIE BOSS SCRIPT - Giant Zombie with Enhanced Abilities
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local enemy = script.Parent
local humanoidRootPart = enemy.HumanoidRootPart
local levelSystem = require(ReplicatedStorage:WaitForChild("LevelSystem"))
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local humanoid = enemy.Humanoid

-- BOSS STATS
humanoid.MaxHealth = 3000
humanoid.Health = 3000

local Chat = game:GetService("Chat")
local PathfindingService = game:GetService("PathfindingService")

-- Create temporary transparent head if missing
local zombieHead = enemy:FindFirstChild("Head")
if not zombieHead then
	zombieHead = Instance.new("Part")
	zombieHead.Name = "Head"
	zombieHead.Size = Vector3.new(2, 1, 1) -- Normal head size
	zombieHead.Transparency = 1 -- Completely transparent
	zombieHead.CanCollide = false
	zombieHead.Material = Enum.Material.ForceField

	-- Position above torso
	local torso = enemy:FindFirstChild("Torso") or enemy:FindFirstChild("UpperTorso")
	if torso then
		zombieHead.Position = torso.Position + Vector3.new(0, torso.Size.Y/2 + zombieHead.Size.Y/2, 0)
	else
		zombieHead.Position = humanoidRootPart.Position + Vector3.new(0, 2, 0)
	end

	-- Weld to torso/humanoidrootpart
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = zombieHead
	weld.Part1 = torso or humanoidRootPart
	weld.Parent = zombieHead

	zombieHead.Parent = enemy

	-- Create a basic head configuration
	if humanoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = zombieHead
	end
end

-- Scale up the boss (not too big, but noticeably larger)
-- REMOVED: Manual scaling since boss is already manually sized

-- Boss damage resistances
local damageResistanceValue = Instance.new("NumberValue")
damageResistanceValue.Name = "DamageResistance" 
damageResistanceValue.Value = 0.45 -- 60% damage resistance
damageResistanceValue.Parent = enemy

local defenseResistanceValue = Instance.new("NumberValue")
defenseResistanceValue.Name = "DefenseResistance"
defenseResistanceValue.Value = 0.65-- 65% defense resistance
defenseResistanceValue.Parent = enemy

-- Boss behavior variables
local originPoint = humanoidRootPart.Position
local maxWanderDistance = 60
local wanderCooldown = 0
local lastChatTime = 0
local chatCooldown = 2
local currentState = "wandering"
local isWandering = false
local wanderPath = nil
local wanderWaypointIndex = 1
local wanderConnection = nil
local lastGroanTime = 0

-- Boss phase system
local currentPhase = 1
local maxPhase = 3
local phaseThresholds = {0.66, 0.33, 0} -- Health percentages for phase changes

-- Enhanced boss messages
local WANDER_MESSAGES = {
	"GRROOOAAARRRRR...",
	"WHERE... ARE... YOU...",
	"HUUUUUNGRYYYY...",
	"FEEEEEED... MEEEE...",
	"RAAAAWWWWWRRRRR..."
}

local CHASE_MESSAGES = {
	"I SMELL YOUR FEAR!!!",
	"YOU CANNOT HIDE!!!",
	"COME TO PAPA!!!",
	"FRESH MEAT!!!"
}

local PHASE_MESSAGES = {
	"PHASE 2: GETTING ANGRY!!!",
	"PHASE 3: MAXIMUM RAGE!!!",
	"FINAL FORM ACTIVATED!!!"
}

local RANGED_COUNTER_MESSAGES = {
	"COWARD! STOP HIDING!!!",
	"GRAHHH FACE ME!!!",
	"NO MORE GAMES!!!",
	"HAHAHA ROCK THROW!!!!!",
	"TIRED OF YOUR RUNNING!!!",
	"STAND AND FIGHT!!!"
}

local ACID_SPIT_MESSAGES = {
	"TASTE MY VENOM!!!",
	"ACID RAIN FOR COWARDS!!!",
	"DISSOLVE IN MY FURY!!!",
	"NO ESCAPE FROM MY BILE!!!"
}

local ATTACK_MESSAGE = "DIIIIEEE MORTAL!!!"
local LOST_TARGET_MESSAGE = "cowards... hiding..."

local maxDistance = 55
local deBounce = false
local lastSpecialTime = 0
local specialCooldown = 15
local isPerformingSpecialMove = false
local lastGroundSlamTime = 0
local groundSlamCooldown = 20
local lastSpawnMinionsTime = 0
local spawnMinionsCooldown = 30
local lastRockThrowTime = 0
local rockThrowCooldown = 8  -- REDUCED: More frequent (was 12)
local isPerformingRockThrow = false
local lastAcidSpitTime = 0
local acidSpitCooldown = 10
local isPerformingAcidSpit = false

-- Boss pathfinding (slower but more powerful)
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = maxDistance,
	combatMaxDistance = maxDistance * 2,
	walkSpeed = 10, -- Slower due to size
	combatWalkSpeed = 18,
	pathUpdateInterval = 2,
	combatPathUpdateInterval = 1,
	stuckThreshold = 4,
	waypointDistance = 8,
	combatDuration = 20,
	predictionTime = 1
})

-- Boss aura effect
local function createBossAura()
	local aura = Instance.new("SelectionBox")
	aura.Name = "BossAura"
	aura.Adornee = humanoidRootPart
	aura.Color3 = Color3.new(0.8, 0, 0)
	aura.LineThickness = 0.2
	aura.Transparency = 0.7
	aura.Parent = humanoidRootPart

	-- Pulsing effect
	local pulseInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulseTween = TweenService:Create(aura, pulseInfo, {Transparency = 0.3})
	pulseTween:Play()
end

local function sayBossMessage(messageTable, forceChat)
	if forceChat or tick() - lastChatTime >= chatCooldown then
		local message = messageTable
		if type(messageTable) == "table" then
			message = messageTable[math.random(1, #messageTable)]
		end

		-- Safety check for head
		if zombieHead and zombieHead.Parent then
			Chat:Chat(zombieHead, message, Enum.ChatColor.Red)
			lastChatTime = tick()

			-- Boss messages are louder and last longer
			task.spawn(function()
				task.wait(0.1) -- Small delay to ensure chat GUI exists
				if zombieHead:FindFirstChild("ChatGui") then
					local chatGui = zombieHead.ChatGui
					if chatGui:FindFirstChild("ChatFrame") then
						chatGui.ChatFrame.Size = UDim2.new(1.5, 0, 1.5, 0)
					end
				end
			end)
		end
	end
end

local function predictPlayerPosition(player, predictionTime)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local playerRoot = player.Character.HumanoidRootPart
	local currentPos = playerRoot.Position
	local currentVelocity = playerRoot.Velocity

	-- Simple linear prediction - just where they're moving
	local predictedPos = currentPos + (currentVelocity * predictionTime)

	-- Add small randomness to account for player dodging
	local spread = Vector3.new(
		math.random(-4, 4),
		0,
		math.random(-4, 4)
	)

	return predictedPos + spread
end


-- Enhanced touch damage for boss
local function setupBossTouchDamage()
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
						sayBossMessage(ATTACK_MESSAGE)
					end

					-- Boss damage scales with phase
					local baseDamage = 45 + (currentPhase * 15)
					local actualDamage = baseDamage + math.random(-8, 12)

					-- Higher crit chance for boss
					if math.random() > 0.75 then
						actualDamage = actualDamage * 1.8
						sayBossMessage("DEVASTATING BLOW!!!", true)
					end

					DamageService:ApplyDamage(player, actualDamage, enemy)

					-- Boss attacks cause knockback
					if character:FindFirstChild("HumanoidRootPart") then
						local knockDirection = (character.HumanoidRootPart.Position - humanoidRootPart.Position).Unit
						local bodyVelocity = Instance.new("BodyVelocity")
						bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
						bodyVelocity.Velocity = knockDirection * 50
						bodyVelocity.Parent = character.HumanoidRootPart

						Debris:AddItem(bodyVelocity, 0.5)
					end

					task.wait(1.5)
					deBounce = false
				end    
			end)
		end
	end
end

-- Rock Throw Attack - Counters ranged camping
-- SIMPLIFIED AND ACCURATE RANGED ATTACKS
-- Replace the predictPlayerPosition, performRockThrow, and performAcidSpit functions in your boss script


-- FIXED Rock Throw Attack - Prevents self-collision
local function performRockThrow()
	if isPerformingSpecialMove or isPerformingRockThrow then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance < 15 then return end

	isPerformingRockThrow = true
	pathfinding:pauseMovement()

	sayBossMessage(RANGED_COUNTER_MESSAGES, true)

	-- Quick wind-up
	humanoid.WalkSpeed = 0
	local originalCFrame = humanoidRootPart.CFrame

	task.wait(0.6)  -- Shorter wind-up

	-- Create rock
	local rock = Instance.new("Part")
	rock.Name = "BossRock"
	rock.Material = Enum.Material.Rock
	rock.Shape = Enum.PartType.Block
	rock.Size = Vector3.new(4, 4, 4)
	rock.Color = Color3.new(0.3, 0.2, 0.1)
	rock.TopSurface = Enum.SurfaceType.Smooth
	rock.BottomSurface = Enum.SurfaceType.Smooth

	-- Spawn rock at "hand" position
	local spawnOffset = humanoidRootPart.CFrame.LookVector * 6 + 
		humanoidRootPart.CFrame.RightVector * 3 +   
		Vector3.new(0, 2, 0)                       
	rock.Position = humanoidRootPart.Position + spawnOffset
	rock.Parent = workspace

	-- Visual effects
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Color = Color3.new(1, 0.3, 0)
	fire.Parent = rock

	-- Get target position with basic prediction
	local targetPos = player.Character.HumanoidRootPart.Position
	local playerVelocity = player.Character.HumanoidRootPart.Velocity

	-- Simple prediction: where will they be in 1 second?
	local simplePredict = targetPos + (playerVelocity * 0.8)

	-- Calculate direction from rock's actual position to player
	local startPos = rock.Position
	local direction = (simplePredict - startPos)
	local horizontalDist = Vector3.new(direction.X, 0, direction.Z).Magnitude
	local verticalDist = direction.Y  -- This will be NEGATIVE since player is below

	-- Aim downward at the smaller player
	local throwSpeed = math.max(60, horizontalDist * 0.8)

	-- Calculate the needed vertical component - aim slightly down if player is below
	local upwardSpeed = 0
	if verticalDist < 0 then
		-- Player is below us - aim down but add small arc for distance
		upwardSpeed = math.max(-10, verticalDist * 0.3) + math.min(15, horizontalDist * 0.1)
	else
		-- Player is somehow above us - normal arc
		upwardSpeed = math.max(10, horizontalDist * 0.2)
	end

	-- Apply physics with proper downward trajectory
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.Velocity = direction.Unit * throwSpeed + Vector3.new(0, upwardSpeed, 0)
	bodyVelocity.Parent = rock

	-- Spinning effect
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyAngularVelocity.AngularVelocity = Vector3.new(
		math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
	bodyAngularVelocity.Parent = rock

	-- FIXED: Only explode on players or baseplate
	local hasHitValidTarget = false
	local function onRockHit(hit)
		-- Ignore if hitting the boss himself
		if hit.Parent == enemy or hit == humanoidRootPart then
			return
		end

		-- Ignore if already hit something valid
		if hasHitValidTarget then
			return
		end

		local shouldExplode = false
		local hitPlayer = nil

		-- Check if hit a player
		local character = hit.Parent
		if character and character:FindFirstChild("Humanoid") then
			hitPlayer = Players:GetPlayerFromCharacter(character)
			if hitPlayer then
				shouldExplode = true
				hasHitValidTarget = true

				DamageService:ApplyDamage(hitPlayer, 120, enemy)
				sayBossMessage("CRUSHED!!!", true)

				-- Knockback
				if character:FindFirstChild("HumanoidRootPart") then
					local knockDirection = (character.HumanoidRootPart.Position - rock.Position).Unit
					local bodyVelocity = Instance.new("BodyVelocity")
					bodyVelocity.MaxForce = Vector3.new(1e5, 5e4, 1e5)
					bodyVelocity.Velocity = knockDirection * 80 + Vector3.new(0, 40, 0)
					bodyVelocity.Parent = character.HumanoidRootPart
					Debris:AddItem(bodyVelocity, 0.8)
				end
			end
		end

		-- Check if hit the baseplate (forestPart)
		if hit.Name == "forestPart" and hit.Parent and hit.Parent.Parent and 
			hit.Parent.Parent.Name == "areas" and hit.Parent.Name == "area2" then
			shouldExplode = true
			hasHitValidTarget = true
		end

		-- Only explode if we hit a player or the baseplate
		if shouldExplode then			
			-- Explosion effect
			local explosion = Instance.new("Explosion")
			explosion.Position = rock.Position
			explosion.BlastRadius = 20
			explosion.BlastPressure = 0
			explosion.Parent = workspace

			-- AOE damage to ONLY players
			for _, nearPlayer in pairs(Players:GetPlayers()) do
				if nearPlayer.Character and nearPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local dist = (nearPlayer.Character.HumanoidRootPart.Position - rock.Position).Magnitude
					if dist <= 20 then
						local damage = 120 - (dist * 2)
						if damage > 0 then
							DamageService:ApplyDamage(nearPlayer, damage, enemy)
						end
					end
				end
			end

			rock:Destroy()
		end
	end

	rock.Touched:Connect(onRockHit)
	Debris:AddItem(rock, 6)

	task.wait(0.5)
	isPerformingRockThrow = false
	pathfinding:resumeMovement()
	lastRockThrowTime = tick()
end


-- Ground Slam Attack - AOE damage
local function performGroundSlam()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 60 then return end -- Increased detection range

	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	sayBossMessage("MASSIVE GROUND SLAM INCOMING!!!", true)

	-- Store original position to prevent going through ground
	local originalPosition = humanoidRootPart.Position
	local originalCFrame = humanoidRootPart.CFrame

	-- Wind-up animation (lift up slightly)
	humanoid.WalkSpeed = 0
	local windUpTween = TweenService:Create(humanoidRootPart, TweenInfo.new(1.5), 
		{CFrame = originalCFrame * CFrame.new(0, 12, 0)}) -- Higher lift for bigger slam
	windUpTween:Play()
	task.wait(1.8)

	-- Slam down (but not below original position)
	local slamPosition = originalPosition -- Stay at ground level
	local slamTween = TweenService:Create(humanoidRootPart, TweenInfo.new(0.3), 
		{CFrame = CFrame.new(slamPosition) * (originalCFrame - originalCFrame.Position)})
	slamTween:Play()
	task.wait(0.3)

	-- Create MASSIVE shockwave effect
	local shockwave = Instance.new("Explosion")
	shockwave.Position = humanoidRootPart.Position
	shockwave.BlastRadius = 50 -- MUCH bigger blast radius (was 30)
	shockwave.BlastPressure = 0
	shockwave.Visible = false
	shockwave.Parent = workspace

	-- Create multiple expanding shockwave rings for visual effect
	for ring = 1, 3 do
		task.spawn(function()
			task.wait(ring * 0.2) -- Stagger the rings

			local shockwaveRing = Instance.new("Explosion")
			shockwaveRing.Position = humanoidRootPart.Position
			shockwaveRing.BlastRadius = 20 + (ring * 15) -- Expanding rings
			shockwaveRing.BlastPressure = 0
			shockwaveRing.Visible = true
			shockwaveRing.Parent = workspace
		end)
	end

	-- MASSIVE AOE damage to all nearby players
	for _, nearPlayer in pairs(Players:GetPlayers()) do
		if nearPlayer.Character and nearPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (nearPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
			if distance <= 50 then -- HUGE AOE range (was 30)
				-- Damage calculation with better falloff
				local damage = 250 - (distance * 2) -- Higher base damage, gradual falloff
				damage = math.max(damage, 50) -- Minimum 50 damage even at max range

				DamageService:ApplyDamage(nearPlayer, damage, enemy)

				-- STRONGER knockback effect
				local knockDirection = (nearPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Unit
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(2e5, 1e5, 2e5) -- Stronger force

				-- Scale knockback with distance (closer = stronger knockback)
				local knockbackStrength = math.max(40, 100 - (distance * 1.5))
				bodyVelocity.Velocity = knockDirection * knockbackStrength + Vector3.new(0, 50, 0)
				bodyVelocity.Parent = nearPlayer.Character.HumanoidRootPart

				Debris:AddItem(bodyVelocity, 1.2) -- Longer knockback duration
			end
		end
	end

	-- Enhanced visual effect - MUCH more debris
	for i = 1, 25 do -- More debris pieces (was 12)
		local debris = Instance.new("Part")
		debris.Name = "Debris"
		debris.Material = Enum.Material.Rock
		debris.Shape = Enum.PartType.Block
		debris.Size = Vector3.new(math.random(2, 8), math.random(2, 8), math.random(2, 8)) -- Varied sizes
		debris.Color = Color3.new(0.3 + math.random() * 0.3, 0.2 + math.random() * 0.2, 0.1 + math.random() * 0.1) -- Varied colors
		debris.Position = humanoidRootPart.Position + Vector3.new(
			math.random(-35, 35), 5, math.random(-35, 35)) -- MUCH wider spread (was -20 to 20)
		debris.Parent = workspace

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bodyVelocity.Velocity = Vector3.new(
			math.random(-60, 60), math.random(30, 70), math.random(-60, 60)) -- STRONGER launch
		bodyVelocity.Parent = debris

		-- Add spinning to debris
		local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
		bodyAngularVelocity.MaxTorque = Vector3.new(5e4, 5e4, 5e4)
		bodyAngularVelocity.AngularVelocity = Vector3.new(
			math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
		bodyAngularVelocity.Parent = debris

		Debris:AddItem(debris, 6)
		Debris:AddItem(bodyVelocity, 1.5)
		Debris:AddItem(bodyAngularVelocity, 1.5)
	end

	-- Create ground cracks effect
	for crack = 1, 8 do
		local crackPart = Instance.new("Part")
		crackPart.Name = "GroundCrack"
		crackPart.Material = Enum.Material.Concrete
		crackPart.Shape = Enum.PartType.Block
		crackPart.Size = Vector3.new(math.random(15, 25), 0.5, math.random(3, 6))
		crackPart.Color = Color3.new(0.1, 0.1, 0.1) -- Dark cracks
		crackPart.Anchored = true
		crackPart.CanCollide = false

		-- Position cracks radiating outward from boss
		local angle = (math.pi * 2 / 8) * crack
		local distance = math.random(20, 40)
		crackPart.Position = humanoidRootPart.Position + Vector3.new(
			math.cos(angle) * distance, -2, math.sin(angle) * distance)
		crackPart.Rotation = Vector3.new(0, math.deg(angle), 0)
		crackPart.Parent = workspace

		Debris:AddItem(crackPart, 10) -- Cracks last longer
	end

	-- Screen shake effect (if you have a screen shake system)
	sayBossMessage("THE EARTH TREMBLES!!!", true)

	task.wait(1.5)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
	lastGroundSlamTime = tick()
end

-- CLEAN Acid Spit Attack Function
-- ENHANCED Acid Spit Attack Function - Faster speed + path collision
local function performAcidSpit()
	if isPerformingSpecialMove or isPerformingAcidSpit then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance < 10 or distance > 70 then return end

	isPerformingAcidSpit = true
	pathfinding:pauseMovement()

	sayBossMessage(ACID_SPIT_MESSAGES, true)

	-- Quick wind-up
	humanoid.WalkSpeed = 0
	task.wait(0.3)  -- FASTER wind-up (was 0.5)

	-- Fire 3 acid balls in a spread pattern for better hit chance
	for i = 1, 3 do
		-- Get current player position each time
		local currentPlayer, currentDistance = pathfinding:getClosestPlayer()
		if not currentPlayer then break end

		local targetPos = currentPlayer.Character.HumanoidRootPart.Position
		local playerVel = currentPlayer.Character.HumanoidRootPart.Velocity

		-- Simple prediction for each shot
		local predictTime = 0.4  -- FASTER prediction time (was 0.6)
		local predictedPos = targetPos + (playerVel * predictTime)

		-- Add spread pattern
		local spreadPattern = {
			Vector3.new(0, 0, 0),      -- Center shot
			Vector3.new(-6, 0, -3),    -- Left shot
			Vector3.new(6, 0, 3)       -- Right shot
		}
		local finalTarget = predictedPos + spreadPattern[i]

		-- Create acid projectile
		local acidBall = Instance.new("Part")
		acidBall.Name = "AcidSpit"
		acidBall.Material = Enum.Material.Neon
		acidBall.Shape = Enum.PartType.Ball
		acidBall.Size = Vector3.new(2, 2, 2)
		acidBall.Color = Color3.new(0.2, 0.8, 0.1)
		acidBall.CanCollide = false

		-- Spawn from "mouth" position
		local spawnOffset = humanoidRootPart.CFrame.LookVector * 4 +  
			Vector3.new(0, 3.2, 0)                     
		acidBall.Position = humanoidRootPart.Position + spawnOffset
		acidBall.Parent = workspace

		-- Visual effects
		local acidFire = Instance.new("Fire")
		acidFire.Size = 3
		acidFire.Heat = 4
		acidFire.Color = Color3.new(0.2, 0.8, 0.1)
		acidFire.Parent = acidBall

		-- Calculate trajectory from the acid ball's actual position to player
		local direction = (finalTarget - acidBall.Position)
		local horizontalDist = Vector3.new(direction.X, 0, direction.Z).Magnitude
		local verticalDist = direction.Y  -- This will be NEGATIVE since player is below

		-- FASTER projectile speed
		local speed = math.max(65, horizontalDist * 1.0)  -- INCREASED speed (was 45 and 0.7)

		-- Calculate the needed vertical component - aim down at the player
		local upwardSpeed = 0
		if verticalDist < 0 then
			-- Player is below us - aim down but add tiny arc for distance
			upwardSpeed = math.max(-20, verticalDist * 0.5) + math.min(10, horizontalDist * 0.08)  -- FASTER arc
		else
			-- Player is somehow above us - normal small arc
			upwardSpeed = math.max(8, horizontalDist * 0.15)
		end

		-- Apply physics with proper downward trajectory
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bodyVelocity.Velocity = direction.Unit * speed + Vector3.new(0, upwardSpeed, 0)
		bodyVelocity.Parent = acidBall

		-- ENHANCED: Explode on players, baseplate, OR path parts
		local hasHitValidTarget = false
		local function onAcidHit(hit)
			-- Ignore ALL boss parts
			local hitParent = hit.Parent
			if hitParent == enemy then
				return
			end

			-- Also check if the hit part belongs to the boss by name
			local possibleBossParts = {"Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
			for _, partName in pairs(possibleBossParts) do
				if hit.Name == partName and hitParent == enemy then
					return
				end
			end

			-- Ignore if already hit something valid
			if hasHitValidTarget then
				return
			end

			local shouldExplode = false
			local hitPlayer = nil

			-- Check if hit a player
			local character = hit.Parent
			if character and character:FindFirstChild("Humanoid") then
				hitPlayer = Players:GetPlayerFromCharacter(character)
				if hitPlayer then
					shouldExplode = true
					hasHitValidTarget = true

					-- Initial damage to the hit player only
					DamageService:ApplyDamage(hitPlayer, 105, enemy)
					sayBossMessage("ACID BURNS!!!", true)

					-- Apply DOT effect to the hit player only
					task.spawn(function()
						for dotTick = 1, 3 do
							task.wait(1.5)
							if hitPlayer.Character and hitPlayer.Character:FindFirstChild("Humanoid") then
								DamageService:ApplyDamage(hitPlayer, 55, enemy)

								-- Visual effect
								if hitPlayer.Character:FindFirstChild("HumanoidRootPart") then
									local burnEffect = Instance.new("Fire")
									burnEffect.Size = 2
									burnEffect.Color = Color3.new(0.2, 0.8, 0.1)
									burnEffect.Parent = hitPlayer.Character.HumanoidRootPart
									Debris:AddItem(burnEffect, 1)
								end
							end
						end
					end)
				end
			end

			-- Check if hit the baseplate (forestPart)
			if hit.Name == "forestPart" and hit.Parent and hit.Parent.Parent and 
				hit.Parent.Parent.Name == "areas" and hit.Parent.Name == "area2" then
				shouldExplode = true
				hasHitValidTarget = true
			end

			-- NEW: Check if hit any part in the path model
			if hit.Parent and hit.Parent.Name == "path" and hit.Parent.Parent and 
				hit.Parent.Parent.Name == "area2" and hit.Parent.Parent.Parent and 
				hit.Parent.Parent.Parent.Name == "areas" then
				shouldExplode = true
				hasHitValidTarget = true
			end

			-- Only explode if we hit a player, baseplate, or path part
			if shouldExplode then
				-- Create acid pool
				local acidPool = Instance.new("Part")
				acidPool.Name = "AcidPool"
				acidPool.Material = Enum.Material.Neon
				acidPool.Shape = Enum.PartType.Cylinder
				acidPool.Size = Vector3.new(0.5, 10, 10)
				acidPool.Color = Color3.new(0.1, 0.6, 0.05)
				acidPool.Anchored = true
				acidPool.CanCollide = false
				acidPool.Transparency = 0.4
				acidPool.CFrame = CFrame.new(acidBall.Position.X, acidBall.Position.Y - 1, acidBall.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
				acidPool.Parent = workspace

				-- Pool damage that actually works
				local poolDamageCounter = 0
				local poolConnection
				poolConnection = RunService.Heartbeat:Connect(function()
					poolDamageCounter = poolDamageCounter + 1

					-- Check for damage every 30 frames (about 0.5 seconds at 60 FPS)
					if poolDamageCounter >= 30 then
						poolDamageCounter = 0

						-- Only damage players, not the boss
						for _, nearPlayer in pairs(Players:GetPlayers()) do
							if nearPlayer.Character and nearPlayer.Character:FindFirstChild("HumanoidRootPart") then
								local dist = (nearPlayer.Character.HumanoidRootPart.Position - acidPool.Position).Magnitude
								if dist <= 5 then -- Pool radius
									DamageService:ApplyDamage(nearPlayer, 35, enemy)

									-- Visual effect for puddle damage
									if nearPlayer.Character:FindFirstChild("HumanoidRootPart") then
										local puddleBurn = Instance.new("Fire")
										puddleBurn.Size = 1
										puddleBurn.Color = Color3.new(0.2, 0.8, 0.1)
										puddleBurn.Parent = nearPlayer.Character.HumanoidRootPart
										Debris:AddItem(puddleBurn, 0.5)
									end
								end
							end
						end
					end
				end)

				-- Cleanup acid pool
				Debris:AddItem(acidPool, 6)
				task.spawn(function()
					task.wait(6)
					if poolConnection then
						poolConnection:Disconnect()
					end
				end)

				-- Small explosion
				local acidExplosion = Instance.new("Explosion")
				acidExplosion.Position = acidBall.Position
				acidExplosion.BlastRadius = 8
				acidExplosion.BlastPressure = 0
				acidExplosion.Parent = workspace

				acidBall:Destroy()
			end
		end

		acidBall.Touched:Connect(onAcidHit)
		Debris:AddItem(acidBall, 4)

		task.wait(0.1)  -- FASTER succession (was 0.15)
	end

	task.wait(0.3)  -- FASTER recovery (was 0.4)
	isPerformingAcidSpit = false
	pathfinding:resumeMovement()
	lastAcidSpitTime = tick()
end
	
local function performBoulderBarrage()
	if currentPhase < 3 or isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance < 25 then return end

	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	sayBossMessage("ULTIMATE BOULDER STORM!!! DEATH FROM ABOVE!!!", true)

	humanoid.WalkSpeed = 0

	-- Throw 7 rocks in quick succession (increased from 5)
	for i = 1, 7 do
		local currentPlayer, currentDistance = pathfinding:getClosestPlayer()
		if not currentPlayer then break end

		-- Enhanced prediction for barrage
		local predictionTime = 0.6 + (i * 0.1)
		local predictedPos = predictPlayerPosition(currentPlayer, predictionTime)
		if not predictedPos then
			predictedPos = currentPlayer.Character.HumanoidRootPart.Position
		end

		-- Tighter spread pattern
		local spread = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		local targetPos = predictedPos + spread

		local rock = Instance.new("Part")
		rock.Name = "BarrageRock"
		rock.Material = Enum.Material.Rock
		rock.Shape = Enum.PartType.Block
		rock.Size = Vector3.new(3.5, 3.5, 3.5)  -- Slightly bigger
		rock.Color = Color3.new(0.3, 0.2, 0.1)
		rock.Position = humanoidRootPart.Position + Vector3.new(0, 12, 0)
		rock.Parent = workspace

		-- Enhanced visuals for barrage
		local barragefire = Instance.new("Fire")
		barragefire.Size = 5
		barragefire.Heat = 8
		barragefire.Color = Color3.new(1, 0.2, 0)
		barragefire.Parent = rock

		-- Faster, more accurate throws
		local direction = (targetPos - rock.Position).Unit
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bodyVelocity.Velocity = direction * 110 + Vector3.new(0, 30, 0)  -- FASTER
		bodyVelocity.Parent = rock

		-- Enhanced impact damage
		rock.Touched:Connect(function(hit)
			local character = hit.Parent
			if character and character:FindFirstChild("Humanoid") then
				local hitPlayer = Players:GetPlayerFromCharacter(character)
				if hitPlayer then
					DamageService:ApplyDamage(hitPlayer, 110, enemy)  -- INCREASED
				end
			end

			-- Bigger explosions
			local explosion = Instance.new("Explosion")
			explosion.Position = rock.Position
			explosion.BlastRadius = 15  -- BIGGER
			explosion.BlastPressure = 0
			explosion.Parent = workspace

			rock:Destroy()
		end)

		Debris:AddItem(rock, 5)
		task.wait(0.25)  -- Faster succession
	end

	task.wait(1.5)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
end

-- Spawn minion zombies (TARGETED FIX)
local function spawnMinions()
	if isPerformingSpecialMove then return end

	sayBossMessage("RISE MY MINIONS!!!", true)

	-- Get the zombie template (we know it exists)
	local serverStorage = game:GetService("ServerStorage")
	local zombieTemplate = serverStorage.enemies.area2.Zombie

	-- Verify template exists
	if not zombieTemplate then
		warn("Zombie template not found at ServerStorage.enemies.area2.Zombie!")
		return
	end

	--print("Spawning minions using template:", zombieTemplate.Name) -- Debug print

	-- Spawn 2-3 smaller zombies around the boss
	local minionsSpawned = 0
	for i = 1, math.random(2, 3) do
		local angle = (math.pi * 2 / 3) * i
		local spawnPos = humanoidRootPart.Position + Vector3.new(
			math.cos(angle) * 12, 2, math.sin(angle) * 12) -- Slightly further out and lower Y

		-- Create spawn effect first
		local spawnEffect = Instance.new("Explosion")
		spawnEffect.Position = spawnPos
		spawnEffect.BlastRadius = 8
		spawnEffect.BlastPressure = 0
		spawnEffect.Visible = true
		spawnEffect.Parent = workspace

		-- Wait a moment for effect
		task.wait(0.2)

		-- Clone the zombie
		local success, minionClone = pcall(function()
			return zombieTemplate:Clone()
		end)

		if success and minionClone then
			-- Set parent first
			minionClone.Parent = workspace

			-- Wait a frame for the clone to fully initialize
			task.wait()

			-- Check if it has the required parts
			local minionRoot = minionClone:FindFirstChild("HumanoidRootPart")
			local minionHumanoid = minionClone:FindFirstChild("Humanoid")

			if minionRoot then
				-- Set position safely
				minionRoot.CFrame = CFrame.new(spawnPos)
				--print("Minion spawned at:", spawnPos) -- Debug print

				-- Configure minion stats
				if minionHumanoid then
					minionHumanoid.MaxHealth = 250 -- Weaker than boss
					minionHumanoid.Health = 250
					minionHumanoid.WalkSpeed = 24 -- Faster than boss but weaker

					-- Give minion a distinctive name
					minionClone.Name = "Zombie Minion" .. i

					-- Add a visual effect to distinguish from regular zombies
					local minionEffect = Instance.new("PointLight")
					minionEffect.Name = "MinionGlow"
					minionEffect.Color = Color3.new(1, 0, 0) -- Red glow
					minionEffect.Brightness = 0.5
					minionEffect.Range = 10
					minionEffect.Parent = minionRoot

					minionsSpawned = minionsSpawned + 1
				else
					warn("Cloned zombie missing Humanoid!")
				end
			else
				warn("Cloned zombie missing HumanoidRootPart!")
			end

			-- Auto-cleanup after 45 seconds
			game:GetService("Debris"):AddItem(minionClone, 45)
		else
			warn("Failed to clone zombie template!")
		end
	end

	--print("Total minions spawned:", minionsSpawned) -- Debug print
	lastSpawnMinionsTime = tick()
end

-- Charge attack - devastating rush (FIXED VERSION)
local function performChargeAttack()
	if isPerformingSpecialMove then return end

	local player, distance = pathfinding:getClosestPlayer()
	if not player or distance > 60 or distance < 15 then return end

	isPerformingSpecialMove = true
	pathfinding:pauseMovement()

	sayBossMessage("UNSTOPPABLE CHARGE!!!", true)

	-- Wind up
	humanoid.WalkSpeed = 0
	humanoid.PlatformStand = true -- Prevent humanoid from interfering

	local chargePose = humanoidRootPart.CFrame * CFrame.Angles(math.rad(-20), 0, 0)
	local windUpTween = TweenService:Create(humanoidRootPart, TweenInfo.new(1), {CFrame = chargePose})
	windUpTween:Play()
	task.wait(1.2)

	-- Perform charge
	local targetPos = player.Character.HumanoidRootPart.Position
	local direction = (targetPos - humanoidRootPart.Position).Unit

	-- Create BodyVelocity properly
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 0, 4000) -- Reduced force for better control
	bodyVelocity.Velocity = direction * 80
	bodyVelocity.Parent = humanoidRootPart

	-- Alternative method - use BodyPosition for more reliable movement
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.MaxForce = Vector3.new(4000, 0, 4000)
	bodyPosition.Position = targetPos
	bodyPosition.P = 3000
	bodyPosition.D = 500
	bodyPosition.Parent = humanoidRootPart

	-- Charge damage trail
	local chargeDamageActive = true
	local chargeConnection
	chargeConnection = RunService.Heartbeat:Connect(function()
		if not chargeDamageActive then
			chargeConnection:Disconnect()
			return
		end

		-- Damage any player in path
		for _, nearPlayer in pairs(Players:GetPlayers()) do
			if nearPlayer.Character and nearPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local distance = (nearPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
				if distance < 18 then
					DamageService:ApplyDamage(nearPlayer, 85, enemy)
					sayBossMessage("TRAMPLED!!!")
					chargeDamageActive = false
				end
			end
		end
	end)

	-- Stop charge after time
	task.wait(1.5)
	if bodyVelocity then bodyVelocity:Destroy() end
	if bodyPosition then bodyPosition:Destroy() end
	chargeDamageActive = false

	-- Reset humanoid state
	humanoid.PlatformStand = false

	task.wait(0.8)
	isPerformingSpecialMove = false
	pathfinding:resumeMovement()
	lastSpecialTime = tick()
end

-- Phase system
local function checkPhaseChange()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	local newPhase = currentPhase

	for i, threshold in ipairs(phaseThresholds) do
		if healthPercent <= threshold and currentPhase < i + 1 then
			newPhase = i + 1
			break
		end
	end

	if newPhase > currentPhase then
		currentPhase = newPhase
		sayBossMessage(PHASE_MESSAGES[currentPhase - 1] or "EVOLUTION!!!", true)

		-- Phase bonuses
		if currentPhase == 2 then
			-- Phase 2: Faster and more aggressive
			pathfinding:updateConfig({
				combatWalkSpeed = 24,
				walkSpeed = 14
			})
			damageResistanceValue.Value = 0.55
			specialCooldown = 12
			groundSlamCooldown = 15

			-- Add phase 2 effect
			local phase2Effect = Instance.new("Fire")
			phase2Effect.Name = "Phase2Effect"
			phase2Effect.Size = 8
			phase2Effect.Heat = 10
			phase2Effect.Color = Color3.new(1, 0.5, 0)
			phase2Effect.Parent = humanoidRootPart

		elseif currentPhase == 3 then
			-- Phase 3: Maximum power
			pathfinding:updateConfig({
				combatWalkSpeed = 30,
				walkSpeed = 18
			})
			damageResistanceValue.Value = 0.65
			specialCooldown = 8
			groundSlamCooldown = 10
			spawnMinionsCooldown = 20

			-- Add phase 3 effect
			local phase3Effect = Instance.new("Fire")
			phase3Effect.Name = "Phase3Effect"
			phase3Effect.Size = 12
			phase3Effect.Heat = 15
			phase3Effect.Color = Color3.new(1, 0, 0)
			phase3Effect.Parent = humanoidRootPart

			local phase3Smoke = Instance.new("Smoke")
			phase3Smoke.Name = "Phase3Smoke"
			phase3Smoke.Size = 15
			phase3Smoke.Color = Color3.new(0.1, 0.1, 0.1)
			phase3Smoke.Parent = humanoidRootPart
		end
	end
end

-- Wandering system (similar to regular zombie but boss-specific)
local function getRandomWanderPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random(20, maxWanderDistance)
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
		AgentRadius = 4.5, -- Adjusted for boss size (roughly half of HumanoidRootPart width)
		AgentHeight = 8, -- Adjusted for boss height (roughly double normal)
		AgentCanJump = true,
		AgentJumpHeight = 20,
		AgentMaxSlope = 45,
		WaypointSpacing = 15 -- Bigger spacing for bigger boss
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
			if (waypoint.Position - humanoidRootPart.Position).Magnitude < 10 then
				wanderWaypointIndex += 1
			end
		else
			stopWandering()
		end
	end)

	-- Boss occasionally roars while wandering
	if math.random() > 0.5 then
		sayBossMessage(WANDER_MESSAGES)
	end
end

-- Boss AI state management
local function updateBossAI()
	local player, distance = pathfinding:getClosestPlayer()

	if player and distance <= maxDistance then
		if currentState == "wandering" or currentState == "lost" then
			currentState = "chasing"
			sayBossMessage(CHASE_MESSAGES, true)
			stopWandering()
			pathfinding:resumeMovement()
		end
	else
		if currentState == "chasing" or currentState == "attacking" then
			currentState = "lost"
			sayBossMessage(LOST_TARGET_MESSAGE)
			pathfinding:pauseMovement()
		elseif currentState == "lost" and tick() - lastChatTime > 8 then
			currentState = "wandering"
		end

		if (currentState == "wandering" or currentState == "lost") and not isWandering then
			if tick() - wanderCooldown > 12 then
				startWandering()
				wanderCooldown = tick()
			end
		end
	end

	-- Boss phase checking
	checkPhaseChange()
end

-- Setup all boss systems
setupBossTouchDamage()
createBossAura()
pathfinding:startMovement()

--ranged counter loop
task.spawn(function()
	while humanoid.Health > 0 do
		-- Check for ranged counter trigger MORE FREQUENTLY
		local counterTrigger = enemy:FindFirstChild("RangedCounterTrigger")
		if counterTrigger and counterTrigger.Value ~= "" then
			local targetPlayer = enemy:FindFirstChild("RangedCounterTarget")
			if targetPlayer and targetPlayer.Value then
				local counterType = counterTrigger.Value

				sayBossMessage("STOP RUNNING COWARD!!!", true)

				-- Execute counter based on type and cooldowns
				if counterType == "acid" and tick() - lastAcidSpitTime > acidSpitCooldown then
					task.spawn(performAcidSpit)
				elseif counterType == "rock" and tick() - lastRockThrowTime > rockThrowCooldown then
					task.spawn(performRockThrow)
				elseif counterType == "barrage" then
					task.spawn(performBoulderBarrage)
				end
			end
		end

		task.wait(0.2)  -- Check 5 times per second
	end
end)

--special attacks loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2.5)  -- Even faster loop

		if not isPerformingSpecialMove and not isPerformingRockThrow and not isPerformingAcidSpit then
			local player, distance = pathfinding:getClosestPlayer()
			if player then
				-- Ground slam (close range)
				if distance < 25 and tick() - lastGroundSlamTime > groundSlamCooldown then
					if math.random() > 0.6 then
						performGroundSlam()
					end
				end

				-- Charge attack (medium range)
				if distance > 25 and distance < 55 and tick() - lastSpecialTime > specialCooldown then
					if math.random() > 0.7 then
						performChargeAttack()
					end
				end

				-- Spawn minions (later phases)
				if currentPhase >= 2 and tick() - lastSpawnMinionsTime > spawnMinionsCooldown then
					if math.random() > 0.8 then
						spawnMinions()
					end
				end

				-- MUCH more frequent ranged counters
				if distance > 25 and tick() - lastRockThrowTime > rockThrowCooldown then
					if math.random() > 0.4 then  -- 60% chance (was 50%)
						performRockThrow()
					end
				end

				-- Acid spit for mobile players
				if distance > 20 and distance < 65 and tick() - lastAcidSpitTime > acidSpitCooldown then
					if math.random() > 0.5 then  -- 50% chance
						performAcidSpit()
					end
				end
			end
		end
	end
end)

-- Boss AI main loop
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(2)
		updateBossAI()
	end
end)

-- Boss death sequence
humanoid.Died:Connect(function()
	sayBossMessage("IMPOSSIBLE... I AM... ETERNAL...", true)

	-- Epic death effects
	for i = 1, 5 do
		local explosion = Instance.new("Explosion")
		explosion.Position = humanoidRootPart.Position + Vector3.new(
			math.random(-10, 10), math.random(-5, 15), math.random(-10, 10))
		explosion.BlastRadius = 15
		explosion.BlastPressure = 0
		explosion.Parent = workspace
		task.wait(0.3)
	end

	if pathfinding then
		pathfinding:destroy()
	end

	-- Clean up all effects
	for _, effect in pairs(humanoidRootPart:GetChildren()) do
		if effect.Name:find("Effect") or effect.Name:find("Aura") or effect.Name:find("Smoke") then
			effect:Destroy()
		end
	end

	-- Clean up temporary head
	if zombieHead and zombieHead.Parent then
		task.wait(3)
		zombieHead:Destroy()
	end
end)