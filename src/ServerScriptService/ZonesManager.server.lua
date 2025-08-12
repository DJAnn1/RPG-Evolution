-- ServerScriptService/ZonesManager.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Create RemoteEvents folder if it doesn't exist
local zoneEvents = ReplicatedStorage:FindFirstChild("zoneEvents")
if not zoneEvents then
	zoneEvents = Instance.new("Folder")
	zoneEvents.Name = "zoneEvents"
	zoneEvents.Parent = ReplicatedStorage
end

-- Create main teleport event
local teleportEvent = Instance.new("RemoteEvent")
teleportEvent.Name = "teleportEvent"
teleportEvent.Parent = zoneEvents

-- Create combat status event
local combatStatusEvent = Instance.new("RemoteEvent")
combatStatusEvent.Name = "combatStatusEvent"
combatStatusEvent.Parent = zoneEvents

-- Zone Configuration
local ZONES_CONFIG = {
	["happyHome"] = {
		name = "Happy Home",
		teleportLocation = game.Workspace.areas.area1.happyHome.happyHomeTP,
		levelRequired = 1,
		yOffset = 3
	},
	["desert"] = {
		name = "Desert",
		teleportLocation = game.Workspace.areas.area1.desert.desertTP,
		levelRequired = 1,
		yOffset = 3
	},
	["forest"] = {
		name = "Forest Cross",
		teleportLocation = game.Workspace.areas.area2.forestTP,
		levelRequired = 10,
		yOffset = 3
	}
	-- Add more zones here easily:
	-- ["newZone"] = {
	--     name = "New Zone Name",
	--     teleportLocation = workspace.path.to.teleport,
	--     levelRequired = 20,
	--     yOffset = 3
	-- }
}

-- Combat tracking
local playerCombatStatus = {}
local COMBAT_COOLDOWN = 10 -- seconds

-- Initialize player combat status
local function initializePlayer(player)
	playerCombatStatus[player] = {
		inCombat = false,
		lastDamageTime = 0
	}
end

-- Clean up player data when they leave
local function cleanupPlayer(player)
	playerCombatStatus[player] = nil
end

-- Handle player damage (put in combat)
local function onPlayerDamaged(player)
	if not playerCombatStatus[player] then
		initializePlayer(player)
	end

	playerCombatStatus[player].inCombat = true
	playerCombatStatus[player].lastDamageTime = tick()

	-- Notify client about combat status
	combatStatusEvent:FireClient(player, true)

	-- Start combat cooldown
	task.spawn(function()
		task.wait(COMBAT_COOLDOWN)
		if playerCombatStatus[player] and 
			tick() - playerCombatStatus[player].lastDamageTime >= COMBAT_COOLDOWN then
			playerCombatStatus[player].inCombat = false
			combatStatusEvent:FireClient(player, false)
		end
	end)
end

-- Check if player is in combat
local function isPlayerInCombat(player)
	if not playerCombatStatus[player] then
		return false
	end
	return playerCombatStatus[player].inCombat
end

-- Teleport function
local function teleportPlayer(player, zoneId)
	-- Check if zone exists
	local zoneConfig = ZONES_CONFIG[zoneId]
	if not zoneConfig then
		warn("Zone not found: " .. tostring(zoneId))
		return false
	end

	-- Check combat status
	if isPlayerInCombat(player) then
		-- Notify client they're in combat (client will show notification)
		return false
	end

	-- Check level requirement
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local level = stats:FindFirstChild("Level")
		if level and level.Value < zoneConfig.levelRequired then
			-- Send level requirement info to client
			teleportEvent:FireClient(player, "levelTooLow", {
				required = zoneConfig.levelRequired,
				current = level.Value,
				zoneName = zoneConfig.name
			})
			return false
		end
	end

	-- Perform teleport
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local teleportPos = zoneConfig.teleportLocation.Position
		character.HumanoidRootPart.CFrame = CFrame.new(
			teleportPos.X, 
			teleportPos.Y + zoneConfig.yOffset, 
			teleportPos.Z
		)
		return true
	end

	return false
end

-- Event connections
teleportEvent.OnServerEvent:Connect(function(player, zoneId)
	teleportPlayer(player, zoneId)
end)

-- Monitor player health for combat detection
local function monitorPlayerHealth(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	local lastHealth = humanoid.Health

	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			-- Player took damage
			onPlayerDamaged(player)
		end
		lastHealth = health
	end)
end

-- Player connections
Players.PlayerAdded:Connect(function(player)
	initializePlayer(player)

	player.CharacterAdded:Connect(function()
		monitorPlayerHealth(player)
	end)

	if player.Character then
		monitorPlayerHealth(player)
	end
end)

Players.PlayerRemoving:Connect(cleanupPlayer)

-- Initialize existing players
for _, player in pairs(Players:GetPlayers()) do
	initializePlayer(player)
	if player.Character then
		monitorPlayerHealth(player)
	end
end