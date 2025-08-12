-- Simplified EnemyPathfinding ModuleScript

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EnemyPathfinding = {}
EnemyPathfinding.__index = EnemyPathfinding

function EnemyPathfinding.new(enemy, config)
	local self = setmetatable({}, EnemyPathfinding)

	-- Core references
	self.enemy = enemy
	self.humanoid = enemy:WaitForChild("Humanoid")
	self.humanoidRootPart = enemy:WaitForChild("HumanoidRootPart")

	-- Configuration with defaults
	config = config or {}
	self.maxDistance = config.maxDistance or 35
	self.combatMaxDistance = config.combatMaxDistance or (self.maxDistance * 2)
	self.walkSpeed = config.walkSpeed or 16
	self.combatWalkSpeed = config.combatWalkSpeed or (self.walkSpeed * 1.5)
	self.pathUpdateInterval = config.pathUpdateInterval or 1.5
	self.combatPathUpdateInterval = config.combatPathUpdateInterval or 0.8
	self.stuckThreshold = config.stuckThreshold or 2.5
	self.waypointDistance = config.waypointDistance or 3.5
	self.combatDuration = config.combatDuration or 12
	self.predictionTime = config.predictionTime or 0.5

	-- Pathfinding variables
	self.currentPath = nil
	self.currentWaypointIndex = 1
	self.targetPlayer = nil
	self.lastPathTime = 0
	self.stuckCheckTime = 0
	self.lastPosition = self.humanoidRootPart.Position
	self.moveConnection = nil

	-- Prediction variables
	self.playerPositionHistory = {}
	self.maxHistorySize = 8

	-- Combat state tracking
	self.isInCombat = false
	self.lastDamageTime = 0

	-- Set initial humanoid properties
	self.humanoid.WalkSpeed = self.walkSpeed
	self.humanoid.PlatformStand = false

	-- Connect damage detection
	self:setupDamageDetection()

	return self
end

function EnemyPathfinding:setupDamageDetection()
	local lastHealth = self.humanoid.Health

	self.healthConnection = self.humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth and health > 0 then
			self.isInCombat = true
			self.lastDamageTime = tick()
			self.humanoid.WalkSpeed = self.combatWalkSpeed
		end
		lastHealth = health
	end)
end

function EnemyPathfinding:isInCombatMode()
	if self.isInCombat then
		local timeSinceDamage = tick() - self.lastDamageTime
		if timeSinceDamage > self.combatDuration then
			self.isInCombat = false
			self.humanoid.WalkSpeed = self.walkSpeed
		end
	end
	return self.isInCombat
end

function EnemyPathfinding:getClosestPlayer()
	local closestPlayer = nil
	local closestDist = math.huge

	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
			local dist = (char.HumanoidRootPart.Position - self.humanoidRootPart.Position).Magnitude
			if dist < closestDist then
				closestPlayer = plr
				closestDist = dist
			end
		end
	end

	return closestPlayer, closestDist
end

function EnemyPathfinding:updatePlayerHistory(player)
	if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local position = player.Character.HumanoidRootPart.Position
	local currentTime = tick()

	table.insert(self.playerPositionHistory, {
		position = position,
		time = currentTime
	})

	while #self.playerPositionHistory > self.maxHistorySize do
		table.remove(self.playerPositionHistory, 1)
	end

	-- Clean old entries
	for i = #self.playerPositionHistory, 1, -1 do
		if currentTime - self.playerPositionHistory[i].time > 3 then
			table.remove(self.playerPositionHistory, i)
		else
			break
		end
	end
end

function EnemyPathfinding:predictPlayerPosition(player, timeAhead)
	if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local hrp = player.Character.HumanoidRootPart
	local currentPos = hrp.Position

	if #self.playerPositionHistory >= 3 then
		local recent = self.playerPositionHistory[#self.playerPositionHistory]
		local older = self.playerPositionHistory[math.max(1, #self.playerPositionHistory - 2)]

		local timeDiff = recent.time - older.time
		if timeDiff > 0 then
			local avgVelocity = (recent.position - older.position) / timeDiff

			local randomOffset = Vector3.new(
				math.random(-2, 2),
				0,
				math.random(-2, 2)
			)

			return currentPos + (avgVelocity * timeAhead) + randomOffset
		end
	end

	local velocity = hrp.AssemblyLinearVelocity
	return currentPos + (velocity * timeAhead)
end

function EnemyPathfinding:createPath(targetPosition)
	local finalTarget = targetPosition
	if self.targetPlayer then
		local predictedPos = self:predictPlayerPosition(self.targetPlayer, self.predictionTime)
		if predictedPos then
			finalTarget = predictedPos
		end
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 1.8,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 16,
		AgentMaxSlope = 45,
		AgentCanClimb = true,
		WaypointSpacing = 4,
		Costs = {
			Water = 20,
			DangerZone = math.huge
		}
	})

	local success, errorMessage = pcall(function()
		path:ComputeAsync(self.humanoidRootPart.Position, finalTarget)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		return path
	else
		-- Fallback path
		local fallbackPath = PathfindingService:CreatePath({
			AgentRadius = 1.8,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentJumpHeight = 16,
			AgentMaxSlope = 45,
			WaypointSpacing = 6,
		})

		local fallbackSuccess = pcall(function()
			fallbackPath:ComputeAsync(self.humanoidRootPart.Position, targetPosition)
		end)

		if fallbackSuccess and fallbackPath.Status == Enum.PathStatus.Success then
			return fallbackPath
		end
	end

	return nil
end

function EnemyPathfinding:moveToNextWaypoint()
	if not self.currentPath or not self.currentPath:GetWaypoints()[self.currentWaypointIndex] then
		return false
	end

	local waypoints = self.currentPath:GetWaypoints()
	local waypoint = waypoints[self.currentWaypointIndex]

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		self.humanoid.Jump = true
	end

	self.humanoid:MoveTo(waypoint.Position)
	return true
end

-- Simple direct movement function
function EnemyPathfinding:moveToPosition(targetPosition)
	self.humanoid:MoveTo(targetPosition)
end

function EnemyPathfinding:isStuck()
	local currentTime = tick()
	local currentPos = self.humanoidRootPart.Position
	local distanceMoved = (currentPos - self.lastPosition).Magnitude

	if distanceMoved < 1 then
		if self.stuckCheckTime == 0 then
			self.stuckCheckTime = currentTime
		elseif currentTime - self.stuckCheckTime > self.stuckThreshold then
			return true
		end
	else
		self.stuckCheckTime = 0
		self.lastPosition = currentPos
	end

	return false
end

function EnemyPathfinding:shouldUpdatePath()
	local currentTime = tick()
	local updateInterval = self:isInCombatMode() and self.combatPathUpdateInterval or self.pathUpdateInterval

	return (currentTime - self.lastPathTime) > updateInterval or 
		not self.currentPath or 
		not self.targetPlayer or 
		not self.targetPlayer.Character or
		self:isStuck()
end

function EnemyPathfinding:shouldPursueTarget(player, distance)
	local maxRange = self:isInCombatMode() and self.combatMaxDistance or self.maxDistance
	return distance <= maxRange
end

function EnemyPathfinding:startMovement()
	if self.moveConnection then
		self.moveConnection:Disconnect()
	end

	self.moveConnection = RunService.Heartbeat:Connect(function()
		if self.humanoid.Health <= 0 then
			self:stopMovement()
			return
		end

		local player, distance = self:getClosestPlayer()

		if player then
			self:updatePlayerHistory(player)
		end

		if not player or not self:shouldPursueTarget(player, distance) then
			self.targetPlayer = nil
			self.currentPath = nil
			return
		end

		local needsNewPath = self:shouldUpdatePath() or 
			(self.targetPlayer and player ~= self.targetPlayer) or
			(self.targetPlayer and self.targetPlayer.Character and 
				(self.targetPlayer.Character.HumanoidRootPart.Position - self.humanoidRootPart.Position).Magnitude < 6)

		if needsNewPath then
			self.targetPlayer = player
			self.currentPath = self:createPath(player.Character.HumanoidRootPart.Position)
			self.currentWaypointIndex = 1
			self.lastPathTime = tick()

			if not self.currentPath then
				self.humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
				return
			end
		end

		if self.currentPath then
			local waypoints = self.currentPath:GetWaypoints()
			if self.currentWaypointIndex <= #waypoints then
				local waypoint = waypoints[self.currentWaypointIndex]
				local distanceToWaypoint = (waypoint.Position - self.humanoidRootPart.Position).Magnitude

				if distanceToWaypoint < self.waypointDistance then
					self.currentWaypointIndex = self.currentWaypointIndex + 1
				end

				if self.currentWaypointIndex <= #waypoints then
					self:moveToNextWaypoint()
				else
					if self.targetPlayer and self.targetPlayer.Character then
						local targetPos = self.targetPlayer.Character.HumanoidRootPart.Position
						self.humanoid:MoveTo(targetPos)
					end
				end
			end
		end
	end)
end

function EnemyPathfinding:stopMovement()
	if self.moveConnection then
		self.moveConnection:Disconnect()
		self.moveConnection = nil
	end

	if self.healthConnection then
		self.healthConnection:Disconnect()
		self.healthConnection = nil
	end
end

function EnemyPathfinding:destroy()
	self:stopMovement()
end

function EnemyPathfinding:pauseMovement()
	if self.moveConnection then
		self.moveConnection:Disconnect()
		self.moveConnection = nil
	end
end

function EnemyPathfinding:resumeMovement()
	if not self.moveConnection then
		self:startMovement()
	end
end

function EnemyPathfinding:forceCombatMode(duration)
	self.isInCombat = true
	self.lastDamageTime = tick()
	if duration then
		self.combatDuration = duration
	end
end

-- Simple config update (removed smooth movement options)
function EnemyPathfinding:updateConfig(config)
	if config.predictionTime then self.predictionTime = config.predictionTime end
	if config.walkSpeed then 
		self.walkSpeed = config.walkSpeed
		if not self:isInCombatMode() then
			self.humanoid.WalkSpeed = config.walkSpeed
		end
	end
	if config.combatWalkSpeed then 
		self.combatWalkSpeed = config.combatWalkSpeed
		if self:isInCombatMode() then
			self.humanoid.WalkSpeed = config.combatWalkSpeed
		end
	end
end

return EnemyPathfinding