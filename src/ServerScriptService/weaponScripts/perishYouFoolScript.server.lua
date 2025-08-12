--Perish you fool
--Updated with Party Protection - FIXED
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DamageService = require(game.ServerScriptService:WaitForChild("DamageService"))
local click = Instance.new("RemoteEvent")
click.Name = "clickBoom"
click.Parent = ReplicatedStorage
local Debris = game:GetService("Debris")

local function createExplosion(position, player)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 10
	explosion.BlastPressure = 0
	explosion.Parent = workspace

	explosion.Hit:Connect(function(part, distance)
		local character = part:FindFirstAncestorOfClass("Model")
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				-- Check if it's the player's own character
				if character == player.Character then
					return -- Don't damage yourself
				end

				-- Determine target type
				local targetPlayer = Players:GetPlayerFromCharacter(character)

				local success, result
				if targetPlayer then
					-- Target is another player - use ApplyDamage (enemy attacking player format)
					success, result = DamageService:ApplyDamage(targetPlayer, 50, player.Character or player)
				else
					-- Target is an NPC/Enemy - use ApplyPlayerDamageToEnemy
					success, result = DamageService:ApplyPlayerDamageToEnemy(player, 50, character)
				end

				-- Alternative: Use SmartApplyDamage (automatically detects direction)
				-- success, result = DamageService:SmartApplyDamage(player, targetPlayer or character, 50)

				if success then
					-- Only tag if damage was successful
					if not humanoid:FindFirstChild("creator") then
						local tag = Instance.new("ObjectValue")
						tag.Name = "creator"
						tag.Value = player
						tag.Parent = humanoid
						Debris:AddItem(tag, 2)
					end

					-- Debug output
					if type(result) == "table" then
						print("[EXPLOSION HIT] Dealt " .. math.floor(result.finalDamage or 50) .. " damage to " .. character.Name)
					end
				else
					-- Damage was blocked (party protection or other reason)
					print("[EXPLOSION BLOCKED] " .. (result or "Unknown reason") .. " on " .. character.Name)
				end

				-- Play sound effect regardless of damage success
				local fartSound = script:FindFirstChild("reverbFart")
				if fartSound then
					local soundClone = fartSound:Clone()
					local soundPart = Instance.new("Part")
					soundPart.Position = explosion.Position
					soundPart.Anchored = true
					soundPart.CanCollide = false
					soundPart.Transparency = 1
					soundPart.Size = Vector3.new(1, 1, 1)
					soundPart.Name = "ExplosionSoundPart"
					soundPart.Parent = workspace
					soundClone.Parent = soundPart
					soundClone:Play()
					Debris:AddItem(soundClone, soundClone.TimeLength + 1)
					Debris:AddItem(soundPart, soundClone.TimeLength + 1)
				else
					warn("Missing sound: reverbFart")
				end
			end
		end
	end)

	Debris:AddItem(explosion, 2)
end

click.OnServerEvent:Connect(function(player, pos)
	createExplosion(pos, player)
end)