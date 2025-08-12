--boss telamon script - UPDATED for Simple Pathfinding and New Damage System

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- Require the pathfinding module
local EnemyPathfinding = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))

local enemy = script.Parent
local humanoid = enemy:WaitForChild("Humanoid")
local humanoidRootPart = enemy:WaitForChild("HumanoidRootPart")

-- CUSTOMIZABLE BOSS CONFIGURATION
local CONFIG = {
	-- Basic Stats
	maxHealth = 1000,
	walkSpeed = 20,

	-- Combat Settings
	maxDistance = 35,
	touchDamage = 30,
	touchDamageCooldown = 1,

	-- Attack Settings
	laserDamage = 80,
	laserCooldown = 8,
	laserRange = 35,
	laserSpeed = 40,
	laserPredictionTime = 0.3,

	largeBlastDamage = 120,
	largeBlastCooldown = 12,
	largeBlastRange = 35,
	largeBlastSpeed = 35,
	largeBlastSize = Vector3.new(6, 6, 8),

	-- Rage Mode (when health is low)
	rageHealthThreshold = 0.3, -- Below 30% health
	rageLaserCooldown = 3, -- Reduced cooldown in rage
	rageChance = 0.3, -- 30% chance per second in rage

	-- Pathfinding Settings
	combatSpeedMultiplier = 1.3,
	combatRangeMultiplier = 3,
	pathUpdateInterval = 2,
	combatPathUpdateInterval = 0.8,
	combatDuration = 15
}

-- Initialize health
humanoid.MaxHealth = CONFIG.maxHealth
humanoid.Health = CONFIG.maxHealth

-- Add boss-level damage resistance (50% damage resistance, 35% defense resistance)
local damageResistanceValue = Instance.new("NumberValue")
damageResistanceValue.Name = "DamageResistance"
damageResistanceValue.Value = 0.5 -- 50% damage resistance (boss-level)
damageResistanceValue.Parent = enemy

local defenseResistanceValue = Instance.new("NumberValue")
defenseResistanceValue.Name = "DefenseResistance"
defenseResistanceValue.Value = 0.35 -- 35% defense resistance
defenseResistanceValue.Parent = enemy

local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local blastAnimation = script:WaitForChild("attackBlast")

local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local loadedBlastAnimation = animator:LoadAnimation(blastAnimation)

local deBounce = false
local isAttacking = false
local lastLaserTime = 0
local lastLargeBlastTime = 0

-- Initialize the simplified pathfinding system
local pathfinding = EnemyPathfinding.new(enemy, {
	maxDistance = CONFIG.maxDistance,
	combatMaxDistance = CONFIG.maxDistance * CONFIG.combatRangeMultiplier,
	walkSpeed = CONFIG.walkSpeed,
	combatWalkSpeed = CONFIG.walkSpeed * CONFIG.combatSpeedMultiplier,
	pathUpdateInterval = CONFIG.pathUpdateInterval,
	combatPathUpdateInterval = CONFIG.combatPathUpdateInterval,
	stuckThreshold = 3,
	waypointDistance = 5,
	combatDuration = CONFIG.combatDuration,
	predictionTime = 0.6
})

-- Ensure boss doesn't sit
task.delay(1, function()
	if humanoid.Sit then
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)

-- Enhanced touch damage system
local function setupTouchDamage()
	for _, part in pairs(enemy:GetChildren()) do
		if part:IsA("BasePart") and part ~= humanoidRootPart then
			part.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and humanoid.Health > 0 and not deBounce then
					deBounce = true
					-- Use original ApplyDamage for enemy-to-player damage
					DamageService:ApplyDamage(player, CONFIG.touchDamage, enemy)
					-- Force combat mode when touching player
					pathfinding:forceCombatMode()
					task.wait(CONFIG.touchDamageCooldown)
					deBounce = false
				end
			end)
		end
	end

	-- Handle new parts
	enemy.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") and child ~= humanoidRootPart then
			child.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and humanoid.Health > 0 and not deBounce then
					deBounce = true
					-- Use original ApplyDamage for enemy-to-player damage
					DamageService:ApplyDamage(player, CONFIG.touchDamage, enemy)
					pathfinding:forceCombatMode()
					task.wait(CONFIG.touchDamageCooldown)
					deBounce = false
				end
			end)
		end
	end)
end

-- Enhanced laser blast attack
local function fireLaserBlast()
	if isAttacking then return end

	local closestPlayer, closestDist = pathfinding:getClosestPlayer()
	if not closestPlayer or closestDist > CONFIG.laserRange then
		return
	end

	isAttacking = true
	pathfinding:pauseMovement()

	loadedBlastAnimation:Play()
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0

	-- Animation windup
	task.wait(0.5)

	local origin = humanoidRootPart.Position + Vector3.new(0, 2, 0)
	local targetPos = closestPlayer.Character.HumanoidRootPart.Position
	local targetVelocity = closestPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity
	local predictedPos = targetPos + (targetVelocity * CONFIG.laserPredictionTime)
	local direction = (predictedPos - origin).Unit

	local laser = ReplicatedStorage.enemyWeapons.happyHome.telemonPowers:FindFirstChild("LaserBeam")
	if not laser then
		warn("LaserBeam missing from ReplicatedStorage")
		humanoid.WalkSpeed = originalWalkSpeed
		isAttacking = false
		pathfinding:resumeMovement()
		return
	end

	laser = laser:Clone()
	laser.Size = Vector3.new(1, 1, 10)
	laser.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -5)
	laser.Anchored = false
	laser.CanCollide = false
	laser.Parent = workspace

	local velocity = Instance.new("BodyVelocity")
	velocity.Velocity = direction * CONFIG.laserSpeed
	velocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	velocity.Parent = laser

	local sound = Instance.new("Sound", laser)
	sound.SoundId = "rbxassetid://72254333785487"
	sound:Play()

	local hasHit = false
	laser.Touched:Connect(function(hit)
		if hasHit then return end
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		local targetHumanoid = character:FindFirstChild("Humanoid")

		if player and targetHumanoid and targetHumanoid.Health > 0 and character ~= enemy then
			hasHit = true
			-- Use original ApplyDamage for enemy-to-player damage
			DamageService:ApplyDamage(player, CONFIG.laserDamage, enemy)
			laser:Destroy()
		end
	end)

	Debris:AddItem(laser, 4)

	task.wait(1)
	humanoid.WalkSpeed = originalWalkSpeed
	isAttacking = false
	pathfinding:resumeMovement()
end

-- Enhanced large blast attack
local function fireLargeBlast()
	if isAttacking then return end

	local closestPlayer, closestDist = pathfinding:getClosestPlayer()
	if not closestPlayer or closestDist > CONFIG.largeBlastRange then
		return
	end

	isAttacking = true
	pathfinding:pauseMovement()

	loadedBlastAnimation:Play()
	task.wait(0.8)

	local template = ReplicatedStorage.enemyWeapons.happyHome.telemonPowers:FindFirstChild("LargeBlast")
	if not template then
		warn("LargeBlast missing from ReplicatedStorage")
		isAttacking = false
		pathfinding:resumeMovement()
		return
	end

	local blast = template:Clone()
	blast.Name = "TelamonLargeBlast"
	blast.Size = CONFIG.largeBlastSize

	local startPos = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 8 + Vector3.new(0, 2, 0)
	local targetPos = closestPlayer.Character.HumanoidRootPart.Position
	local direction = (targetPos - startPos).Unit

	blast.CFrame = CFrame.lookAt(startPos, targetPos)
	blast.Anchored = false
	blast.CanCollide = false
	blast.Parent = workspace

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.Velocity = direction * CONFIG.largeBlastSpeed
	bodyVelocity.Parent = blast

	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(0, 1e5, 0)
	bodyAngularVelocity.AngularVelocity = Vector3.new(0, 5, 0)
	bodyAngularVelocity.Parent = blast

	local hasHit = false
	local connection
	connection = blast.Touched:Connect(function(hit)
		if hasHit or hit.Parent == enemy or hit.Parent.Parent == enemy then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		local targetHumanoid = character:FindFirstChild("Humanoid")

		if player and targetHumanoid and targetHumanoid.Health > 0 and character ~= enemy then
			hasHit = true
			-- Use original ApplyDamage for enemy-to-player damage
			DamageService:ApplyDamage(player, CONFIG.largeBlastDamage, enemy)
			connection:Disconnect()
			blast:Destroy()
		end
	end)

	task.delay(6, function()
		if blast and blast.Parent then
			blast:Destroy()
		end
	end)

	task.wait(1.5)
	isAttacking = false
	pathfinding:resumeMovement()
end

-- Enhanced rage mode with increased damage resistance
local function checkRageMode()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if healthPercent < CONFIG.rageHealthThreshold then
		-- Increase damage resistance when in rage mode
		damageResistanceValue.Value = 0.7 -- 70% damage resistance when enraged

		-- Visual effect for rage mode
		if not humanoidRootPart:FindFirstChild("RageEffect") then
			local effect = Instance.new("Fire")
			effect.Name = "RageEffect"
			effect.Size = 8
			effect.Heat = 10
			effect.Color = Color3.new(1, 0, 0)
			effect.SecondaryColor = Color3.new(1, 0.5, 0)
			effect.Parent = humanoidRootPart
		end
	else
		-- Reset damage resistance to normal
		damageResistanceValue.Value = 0.5 -- Back to 50% normal boss resistance

		-- Remove rage effects
		local effect = humanoidRootPart:FindFirstChild("RageEffect")
		if effect then effect:Destroy() end
	end
end

-- Intelligent attack selection
local function shouldUseLaser()
	local player, distance = pathfinding:getClosestPlayer()
	if not player then return false end

	local velocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
	local isMovingFast = velocity.Magnitude > 10

	return distance > 15 and distance <= CONFIG.laserRange and (isMovingFast or math.random() > 0.3)
end

local function shouldUseLargeBlast()
	local player, distance = pathfinding:getClosestPlayer()
	if not player then return false end

	local velocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity
	local isStationary = velocity.Magnitude < 5

	return distance <= 25 and (isStationary or math.random() > 0.4)
end

-- Check if boss is in rage mode
local function isInRageMode()
	local healthPercent = humanoid.Health / humanoid.MaxHealth
	return healthPercent < CONFIG.rageHealthThreshold
end

-- Setup systems
setupTouchDamage()
pathfinding:startMovement()

-- Smart attack system
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(math.random(3, 6))

		if not isAttacking then
			if shouldUseLaser() and tick() - lastLaserTime > CONFIG.laserCooldown then
				lastLaserTime = tick()
				fireLaserBlast()
			elseif shouldUseLargeBlast() and tick() - lastLargeBlastTime > CONFIG.largeBlastCooldown then
				lastLargeBlastTime = tick()
				fireLargeBlast()
			end
		end
	end
end)

-- Rage mode system
task.spawn(function()
	while humanoid.Health > 0 do
		task.wait(1)

		checkRageMode() -- Check rage mode status

		if isInRageMode() and not isAttacking then
			if math.random() > (1 - CONFIG.rageChance) then
				if tick() - lastLaserTime > CONFIG.rageLaserCooldown then
					lastLaserTime = tick()
					fireLaserBlast()
				end
			end
		end
	end
end)

-- Cleanup when enemy dies
humanoid.Died:Connect(function()
	if pathfinding then
		pathfinding:destroy()
	end
end)

-- CUSTOMIZATION FUNCTIONS (call these to modify behavior at runtime)
function CONFIG.updateLaserSettings(damage, cooldown, range, speed)
	CONFIG.laserDamage = damage or CONFIG.laserDamage
	CONFIG.laserCooldown = cooldown or CONFIG.laserCooldown
	CONFIG.laserRange = range or CONFIG.laserRange
	CONFIG.laserSpeed = speed or CONFIG.laserSpeed
end

function CONFIG.updateBlastSettings(damage, cooldown, range, speed, size)
	CONFIG.largeBlastDamage = damage or CONFIG.largeBlastDamage
	CONFIG.largeBlastCooldown = cooldown or CONFIG.largeBlastCooldown
	CONFIG.largeBlastRange = range or CONFIG.largeBlastRange
	CONFIG.largeBlastSpeed = speed or CONFIG.largeBlastSpeed
	CONFIG.largeBlastSize = size or CONFIG.largeBlastSize
end

function CONFIG.updatePathfindingSettings(settings)
	pathfinding:updateConfig(settings)
end

-- Make CONFIG globally accessible for easy customization
_G.TelamonBossConfig = CONFIG