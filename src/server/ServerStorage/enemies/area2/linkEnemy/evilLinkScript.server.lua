-------------------------------------------
-- LINK ENEMY SCRIPT - FIXED and ENHANCED with Better AI
-------------------------------------------

local EnemyPathfinding3 = require(game.ServerScriptService:WaitForChild("EnemyPathfinding"))

local enemy3 = script.Parent
local humanoid3 = enemy3:WaitForChild("Humanoid")
local humanoidRootPart3 = enemy3:WaitForChild("HumanoidRootPart")
local players3 = game:GetService("Players")
local replicatedStorage3 = game:GetService("ReplicatedStorage")
local slingshotTemplate3 = replicatedStorage3.enemyWeapons.linkWeapons:WaitForChild("ClassicSlingshot")
local DamageService3 = require(game.ServerScriptService:WaitForChild("DamageService"))
local RunService = game:GetService("RunService")
local Chat = game:GetService("Chat")

humanoid3.MaxHealth = 250
humanoid3.Health = 250

-- Add Link enemy damage resistance (20% base, changes with combat mode)
local damageResistanceValue3 = Instance.new("NumberValue")
damageResistanceValue3.Name = "DamageResistance"
damageResistanceValue3.Value = 0.2 -- 20% base damage resistance
damageResistanceValue3.Parent = enemy3

local defenseResistanceValue3 = Instance.new("NumberValue")
defenseResistanceValue3.Name = "DefenseResistance"
defenseResistanceValue3.Value = 0.1 -- 10% defense resistance
defenseResistanceValue3.Parent = enemy3

-- Enhanced Configuration
local CONFIG = {
	meleeDistance = 10,
	rangedDistance = 40,
	maxDistance = 50,
	attackCooldown = 2,
	slingshotDamage = 30,
	meleeDamage = 25,
	slingshotDuration = 8, -- How long to shoot before switching modes
	repositionDistance = 25, -- Preferred combat distance
	repositionCooldown = 3,
	dodgeChance = 0.3, -- 30% chance to dodge when player gets close
	chatCooldown = 4
}

local canAttack = true
local currentMode = "none"
local currentTool = nil
local touchCooldown = {}  -- Track cooldown per player (now with timestamps)
local slingshotStartTime = nil  -- Track when slingshot mode started
local lastRepositionTime = 0
local isRepositioning = false
local lastChatTime = 0
local TOUCH_COOLDOWN_TIME = 1.5 -- 1.5 second cooldown for touch damage

-- Link's personality messages
local LINK_MESSAGES = {
	ranged = {
		"Take this!",
		"You can't escape my aim!",
		"Hyah! Direct hit!",
		"The power of the slingshot!"
	},
	melee = {
		"Hiyah!",
		"Come and fight me!",
		"I'll defend Hyrule!",
		"You won't defeat the hero!"
	},
	reposition = {
		"I need some distance!",
		"Tactical retreat!",
		"Getting into position!"
	},
	taunt = {
		"Is that all you've got?",
		"I've faced tougher enemies!",
		"You're no match for me!"
	}
}

-- Initialize the simplified pathfinding system
local pathfinding3 = EnemyPathfinding3.new(enemy3, {
	maxDistance = CONFIG.maxDistance,
	combatMaxDistance = CONFIG.maxDistance * 1.5,
	walkSpeed = 16,
	combatWalkSpeed = 22, -- Faster when in combat
	pathUpdateInterval = 1.5,
	combatPathUpdateInterval = 0.8,
	stuckThreshold = 2.5,
	waypointDistance = 4,
	combatDuration = 12,
	predictionTime = 0.6 -- Better prediction for slingshot
})

-- Enhanced chat system
local function sayMessage(messageType)
	if tick() - lastChatTime >= CONFIG.chatCooldown then
		local messages = LINK_MESSAGES[messageType]
		if messages and #messages > 0 then
			local message = messages[math.random(1, #messages)]
			Chat:Chat(enemy3.Head, message, Enum.ChatColor.Green)
			lastChatTime = tick()
		end
	end
end

-- Adaptive resistance based on combat mode
local function updateCombatResistance(mode)
	if mode == "range" then
		-- Higher resistance when at range (harder to hit)
		damageResistanceValue3.Value = 0.25 -- 25% resistance when ranged
	elseif mode == "melee" then
		-- Lower resistance when in melee (easier to hit)
		damageResistanceValue3.Value = 0.15 -- 15% resistance when melee
	else
		-- Normal resistance when not in combat
		damageResistanceValue3.Value = 0.2 -- 20% normal resistance
	end
end

-- Store touch connections for proper cleanup
local touchConnections = {}

-- Function to damage player on touch (using original DamageService)
local function onTouch(hit)
	-- Check if enemy is still alive first
	if humanoid3.Health <= 0 then return end

	if not hit or not hit.Parent then return end

	local character = hit.Parent
	if not character:IsA("Model") then return end

	local targetHumanoid = character:FindFirstChild("Humanoid")
	if targetHumanoid and character ~= enemy3 and targetHumanoid.Health > 0 then
		local player = players3:GetPlayerFromCharacter(character)
		if player then
			local currentTime = tick()
			local lastTouchTime = touchCooldown[player.UserId]

			-- Check if enough time has passed since last damage
			if not lastTouchTime or (currentTime - lastTouchTime) >= TOUCH_COOLDOWN_TIME then
				-- Record the time of this damage
				touchCooldown[player.UserId] = currentTime

				-- Apply damage
				DamageService3:ApplyDamage(player, CONFIG.meleeDamage, enemy3)
				sayMessage("melee")

				--print("Link damaged " .. player.Name .. " for " .. CONFIG.meleeDamage .. " damage")
			else
				-- Still on cooldown, calculate remaining time
				local remainingTime = TOUCH_COOLDOWN_TIME - (currentTime - lastTouchTime)
				--print("Touch damage on cooldown for " .. player.Name .. " - " .. math.ceil(remainingTime * 10) / 10 .. "s remaining")
			end
		end
	end
end

-- Connect touch event to all parts of the enemy and store connections
for _, part in pairs(enemy3:GetChildren()) do
	if part:IsA("BasePart") then
		local connection = part.Touched:Connect(onTouch)
		table.insert(touchConnections, connection)
	end
end

-- Connect to new parts that might be added and store connections
local childAddedConnection = enemy3.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		local connection = child.Touched:Connect(onTouch)
		table.insert(touchConnections, connection)
	end
end)

local function equipSlingshot()
	-- Remove old tools
	for _, tool in ipairs(enemy3:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end

	-- Clone and parent new tool
	local tool = slingshotTemplate3:Clone()
	tool.Parent = enemy3

	-- Wait for tool to load properly
	local handle = tool:WaitForChild("Handle", 2)
	if not handle then
		warn("Slingshot handle not found!")
		return nil
	end

	-- Equip tool on humanoid
	humanoid3:EquipTool(tool)

	-- Wait a bit for tool to be fully equipped
	task.wait(0.5)

	return tool
end

local function unequipTools()
	humanoid3:UnequipTools()
	for _, tool in ipairs(enemy3:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
	currentTool = nil
end


-- Fallback manual pellet creation (uses DamageService properly)
local function createManualPellet(targetPos, targetPlayer)
	-- Create pellet similar to the tool's system
	local pellet = Instance.new("Part")
	pellet.Name = "LinkPellet"
	pellet.Size = Vector3.new(1, 1, 1)
	pellet.Shape = Enum.PartType.Ball
	pellet.Material = Enum.Material.Neon
	pellet.BrickColor = BrickColor.new("Bright red")
	pellet.CanCollide = false
	pellet.Anchored = false
	pellet.Locked = true

	-- Set all surfaces to smooth (like original tool)
	pellet.BackSurface = Enum.SurfaceType.Smooth
	pellet.BottomSurface = Enum.SurfaceType.Smooth
	pellet.FrontSurface = Enum.SurfaceType.Smooth
	pellet.LeftSurface = Enum.SurfaceType.Smooth
	pellet.RightSurface = Enum.SurfaceType.Smooth
	pellet.TopSurface = Enum.SurfaceType.Smooth

	-- Position and launch calculation
	local head = enemy3:FindFirstChild("Head") or humanoidRootPart3
	local startPos = head.Position
	local direction = targetPos - startPos

	-- Use similar trajectory calculation as the tool
	local dir = direction.Unit
	local launch = startPos + 5 * dir
	local delta = targetPos - launch

	pellet.Position = launch
	pellet.Parent = workspace

	-- Apply velocity (simplified version of tool's physics)
	pellet.Velocity = direction.Unit * 85

	-- Add creator tag for consistency
	local creator_tag = Instance.new("ObjectValue")
	creator_tag.Value = enemy3
	creator_tag.Name = "creator"
	creator_tag.Parent = pellet

	-- Add touch damage using DamageService
	local connection
	connection = pellet.Touched:Connect(function(hit)
		if not hit or not hit.Parent then return end

		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if humanoid and character ~= enemy3 then
			local player = players3:GetPlayerFromCharacter(character)
			if player then
				-- Use DamageService for proper damage calculation
				DamageService3:ApplyDamage(player, CONFIG.slingshotDamage, enemy3)
				connection:Disconnect()
				pellet:Destroy()
			end
		else
			-- Hit something else, reduce damage like original pellet script
			local currentDamage = pellet:GetAttribute("CurrentDamage") or CONFIG.slingshotDamage
			currentDamage = currentDamage / 2
			pellet:SetAttribute("CurrentDamage", currentDamage)

			if currentDamage < 1 then
				connection:Disconnect()
				pellet:Destroy()
			end
		end
	end)

	-- Clean up pellet after 2 seconds (like original script)
	task.spawn(function()
		task.wait(2)
		if pellet and pellet.Parent then
			connection:Disconnect()
			pellet:Destroy()
		end
	end)

	sayMessage("ranged")
end

-- Enhanced slingshot firing with direct tool integration
local function fireSlingshot(tool, targetPlayer)
	if not canAttack or not tool or not targetPlayer then return end
	if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

	canAttack = false

	-- Get predicted target position
	local targetHRP = targetPlayer.Character.HumanoidRootPart
	local targetVelocity = targetHRP.AssemblyLinearVelocity
	local distance = (targetHRP.Position - humanoidRootPart3.Position).Magnitude
	local travelTime = distance / 85 -- Use actual pellet velocity from tool
	local predictedPos = targetHRP.Position + (targetVelocity * travelTime)

	-- Aim at target
	local aimDirection = (predictedPos - humanoidRootPart3.Position).Unit
	humanoidRootPart3.CFrame = CFrame.new(humanoidRootPart3.Position, humanoidRootPart3.Position + aimDirection)

	-- Use the tool's built-in firing system
	local fireBindable = tool:FindFirstChild("linkSlingBind")
	if fireBindable then
		local success, result = pcall(function()
			return fireBindable:Invoke(predictedPos)
		end)

		if success then
			sayMessage("ranged")

			-- The tool creates the pellet with PelletScript
			-- We need to modify the pellet to use DamageService instead of direct TakeDamage
			task.wait(0.15) -- Wait a bit longer for pellet to spawn

			-- Find the newly created pellet
			for _, obj in pairs(workspace:GetChildren()) do
				if obj.Name == "Part" and obj:FindFirstChild("PelletScript") and obj:FindFirstChild("creator") then
					-- Check if this pellet doesn't have our custom tag yet
					if not obj:GetAttribute("LinkEnemyPellet") then
						-- Tag it as our pellet
						obj:SetAttribute("LinkEnemyPellet", true)

						-- Ensure the creator tag points to the enemy (tool should have set this)
						local creator = obj:FindFirstChild("creator")
						if creator and creator.Value ~= enemy3 then
							creator.Value = enemy3
						end

						-- Replace the pellet's touch handling with our enhanced version
						local pelletScript = obj:FindFirstChild("PelletScript")
						if pelletScript then
							-- Disable the original script
							pelletScript.Disabled = true

							-- Create our custom pellet behavior
							local customConnection
							customConnection = obj.Touched:Connect(function(hit)
								if not hit or not hit.Parent then return end

								local character = hit.Parent
								local humanoid = character:FindFirstChildOfClass("Humanoid")

								if humanoid and character ~= enemy3 then
									local player = players3:GetPlayerFromCharacter(character)
									if player then
										-- Use DamageService instead of direct TakeDamage
										DamageService3:ApplyDamage(player, CONFIG.slingshotDamage, enemy3)

										-- Clean up
										customConnection:Disconnect()
										obj:Destroy()
									end
								else
									-- Hit something else, reduce damage like original script
									local currentDamage = obj:GetAttribute("CurrentDamage") or CONFIG.slingshotDamage
									currentDamage = currentDamage / 2
									obj:SetAttribute("CurrentDamage", currentDamage)

									if currentDamage < 1 then
										customConnection:Disconnect()
										obj:Destroy()
									end
								end
							end)

							-- Set up cleanup timer (like original script)
							task.spawn(function()
								task.wait(2)
								if obj and obj.Parent then
									if customConnection then
										customConnection:Disconnect()
									end
									obj:Destroy()
								end
							end)
						end

						break
					end
				end
			end
		else
			warn("Failed to fire slingshot via BindableFunction: " .. tostring(result))
			-- Use fallback manual pellet creation
			createManualPellet(predictedPos, targetPlayer)
		end
	else
		warn("Slingshot tool missing linkSlingBind BindableFunction")
		-- Use fallback manual pellet creation
		createManualPellet(predictedPos, targetPlayer)
	end

	task.delay(CONFIG.attackCooldown, function()
		canAttack = true
	end)
end


-- Smart repositioning system
local function shouldReposition(player, distance)
	if not player or isRepositioning then return false end
	if tick() - lastRepositionTime < CONFIG.repositionCooldown then return false end

	-- Reposition if too close or too far from preferred distance
	local preferredDist = CONFIG.repositionDistance
	return distance < 8 or (distance > preferredDist + 10 and distance < CONFIG.rangedDistance)
end

local function performRepositioning(player, distance)
	if isRepositioning then return end

	isRepositioning = true
	lastRepositionTime = tick()

	sayMessage("reposition")

	-- Calculate reposition target
	local playerPos = player.Character.HumanoidRootPart.Position
	local myPos = humanoidRootPart3.Position
	local direction

	if distance < CONFIG.repositionDistance then
		-- Move away from player
		direction = (myPos - playerPos).Unit
	else
		-- Move closer to preferred distance
		direction = (playerPos - myPos).Unit
	end

	-- Add some randomness to avoid predictable movement
	local randomOffset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
	local repositionTarget = myPos + (direction * CONFIG.repositionDistance) + randomOffset

	-- Temporarily pause pathfinding and move manually
	pathfinding3:pauseMovement()
	humanoid3:MoveTo(repositionTarget)

	-- Wait for repositioning to complete
	task.spawn(function()
		local startTime = tick()
		while (humanoidRootPart3.Position - repositionTarget).Magnitude > 6 and tick() - startTime < 3 do
			task.wait(0.1)
		end

		isRepositioning = false
		pathfinding3:resumeMovement()
	end)
end

-- Enhanced dodge system
local function performDodge(player)
	if isRepositioning then return end

	local playerPos = player.Character.HumanoidRootPart.Position
	local myPos = humanoidRootPart3.Position
	local dodgeDirection = Vector3.new(-1 + math.random() * 2, 0, -1 + math.random() * 2).Unit
	local dodgeTarget = myPos + (dodgeDirection * 8)

	-- Quick dodge movement
	pathfinding3:pauseMovement()
	humanoid3.WalkSpeed = humanoid3.WalkSpeed * 1.5
	humanoid3:MoveTo(dodgeTarget)

	task.wait(0.5)
	humanoid3.WalkSpeed = 16 -- Reset speed
	pathfinding3:resumeMovement()
end

-- Start the pathfinding system
pathfinding3:startMovement()

-- Enhanced AI loop with improved decision making
task.spawn(function()
	while humanoid3.Health > 0 do
		local player, distance = pathfinding3:getClosestPlayer()

		-- Check if we should engage
		if not player or not pathfinding3:shouldPursueTarget(player, distance) then
			if currentMode ~= "none" then
				currentMode = "none"
				updateCombatResistance(currentMode)
				unequipTools()
			end
			task.wait(0.5)
			continue
		end

		-- Smart repositioning
		if shouldReposition(player, distance) then
			performRepositioning(player, distance)
			task.wait(1)
			continue
		end

		-- Dodge chance when player gets very close
		if distance < 6 and math.random() < CONFIG.dodgeChance then
			performDodge(player)
			task.wait(0.5)
			continue
		end

		-- Combat mode decision making
		if distance <= CONFIG.meleeDistance then
			-- Melee mode - get close and personal
			if currentMode ~= "melee" then
				currentMode = "melee"
				updateCombatResistance(currentMode)
				unequipTools()
				sayMessage("melee")
			end
			-- Let pathfinding handle movement

		elseif distance <= CONFIG.rangedDistance then
			-- Ranged mode - equip slingshot and shoot
			if currentMode ~= "range" then
				currentTool = equipSlingshot()
				if currentTool then
					currentMode = "range"
					updateCombatResistance(currentMode)
					slingshotStartTime = tick()
					sayMessage("ranged")
				else
					-- Fallback to melee if slingshot fails
					currentMode = "melee"
					updateCombatResistance(currentMode)
				end
			end

			-- Check if we should stop shooting (after duration or if slingshot fails)
			if slingshotStartTime and (tick() - slingshotStartTime) >= CONFIG.slingshotDuration then
				-- Switch to melee pursuit
				unequipTools()
				currentMode = "melee"
				updateCombatResistance(currentMode)
				slingshotStartTime = nil
				sayMessage("melee")
			else
				-- Continue ranged combat
				if currentTool and canAttack then
					-- Pause movement while aiming and firing
					pathfinding3:pauseMovement()
					fireSlingshot(currentTool, player)
					task.wait(0.3) -- Brief pause after firing
					pathfinding3:resumeMovement()
				end
			end

		else
			-- Approach mode - get into combat range
			if currentMode ~= "approach" then
				currentMode = "approach"
				updateCombatResistance("none")
				unequipTools()
			end
			-- Let pathfinding handle approach
		end

		-- Occasional taunt
		if math.random() < 0.05 then -- 5% chance per loop
			sayMessage("taunt")
		end

		task.wait(0.3) -- Faster AI updates for more responsive behavior
	end
end)

-- Health monitoring for dynamic behavior
task.spawn(function()
	while humanoid3.Health > 0 do
		task.wait(2)

		local healthPercent = humanoid3.Health / humanoid3.MaxHealth

		-- Become more aggressive when health is low
		if healthPercent < 0.3 then
			CONFIG.attackCooldown = 1.5 -- Faster attacks
			CONFIG.dodgeChance = 0.5 -- More dodging
			CONFIG.slingshotDuration = 12 -- Longer ranged phases

			-- Increase damage resistance when desperate
			damageResistanceValue3.Value = math.max(damageResistanceValue3.Value, 0.3)
		end
	end
end)

-- Cleanup when enemy dies
humanoid3.Died:Connect(function()
	-- Clean up pathfinding
	if pathfinding3 then
		pathfinding3:destroy()
	end

	-- Clean up all touch damage connections
	for _, connection in pairs(touchConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	touchConnections = {}

	-- Clean up child added connection
	if childAddedConnection then
		childAddedConnection:Disconnect()
	end

	-- Clean up any remaining effects and tools
	unequipTools()

	-- Clear touch cooldown table
	touchCooldown = {}

	-- Death message
	Chat:Chat(enemy3.Head, "I... failed to protect Hyrule...", Enum.ChatColor.Green)
end)