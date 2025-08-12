local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Region Configuration
local REGIONS = {
	temple = {
		part = workspace.areas.area1.desert.templeRegion,
		lighting = {
			ClockTime = 14,
			Brightness = 2,
			FogEnd = 100000
		},
		sounds = {
			--desertMusic = "rbxassetid://9040296745"
		},
		barrier = workspace.areas.area1.desert.templeBarrier
	}
}

local DEFAULT_LIGHTING = {
	ClockTime = 14,
	Brightness = 2,
	FogEnd = 100000
}

local TRANSITION_TIME = 2
local CHECK_INTERVAL = 0.1 -- Check position every 0.1 seconds instead of every frame

-- Region Management Class
local RegionManager = {}
RegionManager.__index = RegionManager

function RegionManager.new()
	local self = setmetatable({}, RegionManager)
	self.regions = {}
	self.currentRegion = nil
	self.lastCheckTime = 0
	self.activeTweens = {}
	self.soundObjects = {}

	-- Initialize regions
	for regionName, config in pairs(REGIONS) do
		self:addRegion(regionName, config)
	end

	return self
end

function RegionManager:addRegion(name, config)
	local part = config.part
	local position = part.Position
	local size = part.Size

	self.regions[name] = {
		min = position - (size / 2),
		max = position + (size / 2),
		lighting = config.lighting,
		sounds = config.sounds or {},
		barriers = config.barrier and { config.barrier } or {}
	}

	return true -- Optional
end -- ✅ <--- Add this!


function RegionManager:isInRegion(regionName, position)
	local region = self.regions[regionName]
	if not region then return false end

	return (position.X >= region.min.X and position.X <= region.max.X) and
		(position.Y >= region.min.Y and position.Y <= region.max.Y) and
		(position.Z >= region.min.Z and position.Z <= region.max.Z)
end

function RegionManager:getCurrentRegion(position)
	for regionName, _ in pairs(self.regions) do
		if self:isInRegion(regionName, position) then
			return regionName
		end
	end
	return nil
end

function RegionManager:tweenLighting(targetProps)
	-- Stop any active lighting tweens
	for _, tween in pairs(self.activeTweens) do
		tween:Cancel()
	end
	self.activeTweens = {}

	local tweenInfo = TweenInfo.new(
		TRANSITION_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	for property, targetValue in pairs(targetProps) do
		local tween = TweenService:Create(Lighting, tweenInfo, {[property] = targetValue})
		table.insert(self.activeTweens, tween)
		tween:Play()
	end
end

function RegionManager:playRegionSounds(regionName)
	local sounds = self.soundObjects[regionName]
	if not sounds then return end

	-- Create a shared flag to track if any music is currently playing
	local musicPlaying = false

	-- Function to play music sounds with mutual exclusion
	local function playMusicSound(sound, playbackSpeed)
		spawn(function()
			while self.currentRegion == regionName do
				-- Wait until no music is playing
				while musicPlaying and self.currentRegion == regionName do
					wait(0.1) -- Check every 0.1 seconds
				end

				if self.currentRegion == regionName then
					musicPlaying = true -- Mark that music is now playing

					sound.PlaybackSpeed = playbackSpeed
					sound:Play()

					-- Wait for the sound to finish playing
					local soundLength = sound.TimeLength / sound.PlaybackSpeed
					wait(soundLength)

					musicPlaying = false -- Mark that music is no longer playing

					-- Wait additional random time before this sound can play again
					wait(math.random(10, 25))
				end
			end
		end)
	end

	for soundName, sound in pairs(sounds) do
		-- Music sounds
	end
end

function RegionManager:stopRegionSounds(regionName)
	local sounds = self.soundObjects[regionName]
	if not sounds then return end

	for _, sound in pairs(sounds) do
		sound:Stop()
		sound.PlaybackSpeed = 1
	end
end

function RegionManager:enableBarriers(regionName)
	local region = self.regions[regionName]
	if not region then return end
	for _, part in pairs(region.barriers) do
		part.CanCollide = true
	end
end

function RegionManager:disableBarriers(regionName)
	local region = self.regions[regionName]
	if not region then return end
	for _, part in pairs(region.barriers) do
		part.CanCollide = false
	end
end

function RegionManager:enterRegion(regionName)
	if self.currentRegion == regionName then return end

	-- Exit previous region
	if self.currentRegion then
		self:stopRegionSounds(self.currentRegion)
	end

	self.currentRegion = regionName
	local region = self.regions[regionName]

	-- Stop default background music when entering any region
	local waltzingFlutes = SoundService:FindFirstChild("Waltzing Flutes")
	if waltzingFlutes then
		waltzingFlutes:Stop()
	end

	-- Apply lighting changes
	self:tweenLighting(region.lighting)

	-- Start region sounds
	self:playRegionSounds(regionName)
	
	self:enableBarriers(regionName)

	--print("Entered region:", regionName)
end

function RegionManager:exitAllRegions(regionName)
	if not self.currentRegion then return end

	-- Stop current region sounds
	self:stopRegionSounds(self.currentRegion)

	self.currentRegion = nil

	-- Resume default background music when leaving all regions
	local waltzingFlutes = SoundService:FindFirstChild("Waltzing Flutes")
	if waltzingFlutes then
		waltzingFlutes:Play()
	end

	-- Return to default lighting
	self:tweenLighting(DEFAULT_LIGHTING)
	
	self:disableBarriers(regionName)

	--print("Exited all regions")
end

function RegionManager:update()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local currentTime = tick()

	-- Throttle position checks for better performance
	if currentTime - self.lastCheckTime < CHECK_INTERVAL then
		return
	end
	self.lastCheckTime = currentTime

	local newRegion = self:getCurrentRegion(rootPart.Position)

	if newRegion and newRegion ~= self.currentRegion then
		self:enterRegion(newRegion)
	elseif not newRegion and self.currentRegion then
		self:exitAllRegions()
	end
end

function RegionManager:destroy()
	-- Clean up
	for _, tween in pairs(self.activeTweens) do
		tween:Cancel()
	end

	for _, regionSounds in pairs(self.soundObjects) do
		for _, sound in pairs(regionSounds) do
			sound:Destroy()
		end
	end
end

-- Initialize and start the region manager
local regionManager = RegionManager.new()

-- Main update loop
local connection = RunService.Heartbeat:Connect(function()
	regionManager:update()
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		connection:Disconnect()
		regionManager:destroy()
	end
end)
