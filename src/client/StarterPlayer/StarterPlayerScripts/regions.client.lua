--regions local script

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Wait for player to spawn and world to load
local character = player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
wait(3) -- Give extra time for world streaming

-- Region Configuration with lazy loading paths
local REGION_CONFIGS = {
	forest1 = {
		path = {"areas", "area2", "forestRegion"},
		lighting = {
			ClockTime = 0,
			Brightness = 1,
			FogEnd = 300
		},
		sounds = {
			forestMusic = "rbxassetid://1842724613"
		}
	},
	forest2 = {
		path = {"areas", "area2", "forestRegion2"},
		lighting = {
			ClockTime = 3,
			Brightness = 1.2,
			FogEnd = 1000
		},
		sounds = {
			scaryMusic = "rbxassetid://13061809",
			lightning = "rbxassetid://6767192500",
			scaryMusic2 = "rbxassetid://13061809",
		}
	},
	forest3 = {
		path = {"areas", "area2", "forestRegion3"},
		lighting = {
			ClockTime = 6,
			Brightness = 1.5,
			FogEnd = 10000
		},
		sounds = {}
	},
	desertMusic = {
		path = {"areas", "area1", "desert", "desertRegion"},
		lighting = {
			ClockTime = 14,
			Brightness = 2,
			FogEnd = 100000,
			skybox = game.Lighting.desert.Sky
		},
		sounds = {
			desertMusic = "rbxassetid://9040296745"
		}
	},
	desertBoss = {
		path = {"areas", "area1", "desert", "arabKingRegion"},
		lighting = {
			ClockTime = 14,
			Brightness = 2,
			FogEnd = 100000
		},
		sounds = {
			desertMusic = "rbxassetid://1847070557"
		}
	},
	winter = {
		path = {"areas", "area1", "snow", "snowRegion"},
		lighting = {
			ClockTime = 7,
			Brightness = 1.3,
			FogEnd = 50000
		},
		sounds = {
			winterMusic = "rbxassetid://1837101327"
		}
	},
}

local DEFAULT_LIGHTING = {
	ClockTime = 14,
	Brightness = 2,
	FogEnd = 100000,
	skybox = Lighting.happyhome.Sky
}

local function clearSkybox()
	-- Remove any existing Sky object from Lighting
	local existingSky = Lighting:FindFirstChild("Sky")
	if existingSky then
		existingSky:Destroy()
	end
end

local TRANSITION_TIME = 2
local CHECK_INTERVAL = 0.1

-- Enhanced Region Manager with lazy loading
local RegionManager = {}
RegionManager.__index = RegionManager

function RegionManager.new()
	local self = setmetatable({}, RegionManager)
	self.regions = {}
	self.loadedRegions = {}
	self.currentRegion = nil
	self.lastCheckTime = 0
	self.activeTweens = {}
	self.soundObjects = {}
	self.loadingAttempts = {}

	-- Store region configs without loading parts immediately
	for regionName, config in pairs(REGION_CONFIGS) do
		self.regions[regionName] = {
			config = config,
			loaded = false
		}
		self.loadingAttempts[regionName] = 0
	end

	-- Count regions properly (pairs doesn't work with #)
	local regionCount = 0
	for _ in pairs(self.regions) do
		regionCount = regionCount + 1
	end

	--print("RegionManager initialized with", regionCount, "regions")
	return self
end

function RegionManager:loadRegionPart(regionName)
	local region = self.regions[regionName]
	if not region or region.loaded then 
		return region and region.loaded 
	end

	-- Prevent infinite loading attempts
	self.loadingAttempts[regionName] = self.loadingAttempts[regionName] + 1
	if self.loadingAttempts[regionName] > 3 then
		-- Only warn once, not every time
		if self.loadingAttempts[regionName] == 4 then
			warn("⚠️ Max loading attempts reached for region:", regionName, "- skipping")
		end
		return false
	end

	local config = region.config
	local success, part = pcall(function()
		local current = workspace
		for i, pathPart in ipairs(config.path) do
			local timeout = (i == #config.path) and 10 or 15 -- Shorter timeout for final part
			current = current:WaitForChild(pathPart, timeout)
		end
		return current
	end)

	if success and part then
		-- Successfully loaded the part
		local position = part.Position
		local size = part.Size

		self.loadedRegions[regionName] = {
			min = position - (size / 2),
			max = position + (size / 2),
			lighting = config.lighting,
			sounds = config.sounds or {},
			part = part
		}

		region.loaded = true

		-- Create sound objects
		if config.sounds and next(config.sounds) then
			self.soundObjects[regionName] = {}
			for soundName, soundId in pairs(config.sounds) do
				local sound = Instance.new("Sound")
				sound.SoundId = soundId
				sound.Volume = 0.5
				sound.Parent = SoundService
				self.soundObjects[regionName][soundName] = sound
			end
		end

		--print("✅ Successfully loaded region:", regionName)
		return true
	else
		if self.loadingAttempts[regionName] <= 2 then
			--print("🔄 Retrying load for region:", regionName, "(attempt", self.loadingAttempts[regionName] .. ")")
		end
		return false
	end
end

function RegionManager:isInRegion(regionName, position)
	-- Try to load region if not loaded
	if not self.regions[regionName].loaded then
		if not self:loadRegionPart(regionName) then
			return false
		end
	end

	local region = self.loadedRegions[regionName]
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
		if tween then
			tween:Cancel()
		end
	end
	self.activeTweens = {}

	local tweenInfo = TweenInfo.new(
		TRANSITION_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	-- Handle skybox separately (can't be tweened)
	-- Use pairs to check if skybox key exists in the table
	local hasSkybox = false
	for key, _ in pairs(targetProps) do
		if key == "skybox" then
			hasSkybox = true
			break
		end
	end

	if hasSkybox then
		if targetProps.skybox ~= nil then
			-- Apply new skybox
			clearSkybox()
			local newSky = targetProps.skybox:Clone()
			newSky.Parent = Lighting
		else
			-- skybox is explicitly set to nil - clear it
			clearSkybox()
		end
	end

	-- Tween other properties (excluding skybox)
	local tweenableProps = {}
	for property, targetValue in pairs(targetProps) do
		if property ~= "skybox" then
			tweenableProps[property] = targetValue
		end
	end

	if next(tweenableProps) then
		local tween = TweenService:Create(Lighting, tweenInfo, tweenableProps)
		table.insert(self.activeTweens, tween)
		tween:Play()
	end
end

function RegionManager:playRegionSounds(regionName)
	local sounds = self.soundObjects[regionName]
	if not sounds then return end

	local musicPlaying = false

	local function playMusicSound(sound, playbackSpeed, volume)
		spawn(function()
			while self.currentRegion == regionName do
				-- Wait until no music is playing
				while musicPlaying and self.currentRegion == regionName do
					wait(0.1)
				end

				if self.currentRegion == regionName then
					musicPlaying = true
					sound.PlaybackSpeed = playbackSpeed
					sound.Volume = volume

					-- Safely play the sound
					local success = pcall(function()
						sound:Play()
					end)

					if success then
						local soundLength = sound.TimeLength / sound.PlaybackSpeed
						wait(soundLength)
					else
						wait(1) -- Short wait if sound failed to play
					end

					musicPlaying = false
					wait(math.random(10, 25))
				end
			end
		end)
	end

	for soundName, sound in pairs(sounds) do
		if soundName == "scaryMusic" then
			playMusicSound(sound, 0.2, 1)
		elseif soundName == "scaryMusic2" then
			playMusicSound(sound, 0.1, 1)
		elseif soundName == "forestMusic" then
			playMusicSound(sound, 1, 1)
		elseif soundName == "desertMusic" then
			playMusicSound(sound, 1, 1)
		elseif soundName == "winterMusic" then
			playMusicSound(sound, 1, 1)
		elseif soundName == "lightning" then
			spawn(function()
				while self.currentRegion == regionName do
					wait(math.random(10, 30))
					if self.currentRegion == regionName then
						pcall(function()
							sound:Play()
						end)
					end
				end
			end)
		end
	end
end

function RegionManager:stopRegionSounds(regionName)
	local sounds = self.soundObjects[regionName]
	if not sounds then return end

	for _, sound in pairs(sounds) do
		pcall(function()
			sound:Stop()
			sound.PlaybackSpeed = 1
		end)
	end
end

function RegionManager:enterRegion(regionName)
	if self.currentRegion == regionName then return end

	-- Exit previous region
	if self.currentRegion then
		self:stopRegionSounds(self.currentRegion)
	end

	self.currentRegion = regionName
	local region = self.loadedRegions[regionName]
	if not region then return end

	-- Stop default background music
	local waltzingFlutes = SoundService:FindFirstChild("Waltzing Flutes")
	if waltzingFlutes then
		waltzingFlutes:Stop()
	end

	-- Apply lighting changes
	self:tweenLighting(region.lighting)

	-- Start region sounds
	self:playRegionSounds(regionName)

	--print("🌍 Entered region:", regionName)
end

function RegionManager:exitAllRegions()
	if not self.currentRegion then return end

	-- Stop current region sounds
	self:stopRegionSounds(self.currentRegion)
	self.currentRegion = nil

	-- Resume default background music
	local waltzingFlutes = SoundService:FindFirstChild("Waltzing Flutes")
	if waltzingFlutes then
		waltzingFlutes:Play()
	end

	-- Return to default lighting
	self:tweenLighting(DEFAULT_LIGHTING)

	--print("🚪 Exited all regions")
end

function RegionManager:update()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local currentTime = tick()

	-- Throttle position checks
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
	-- Clean up tweens
	for _, tween in pairs(self.activeTweens) do
		if tween then
			tween:Cancel()
		end
	end

	-- Clean up sounds
	for _, regionSounds in pairs(self.soundObjects) do
		for _, sound in pairs(regionSounds) do
			if sound then
				sound:Destroy()
			end
		end
	end

	--print("🧹 RegionManager cleaned up")
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

-- Handle character respawning
player.CharacterAdded:Connect(function(newCharacter)
	-- Reset current region when respawning
	if regionManager.currentRegion then
		regionManager:exitAllRegions()
	end
end)

--print("🚀 Regions script loaded successfully!")