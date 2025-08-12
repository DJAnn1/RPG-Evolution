-- Resistance Utility Script
-- Place this in ServerScriptService
-- Provides easy functions to add resistance to any enemy

local ResistanceUtility = {}

-- Function to add damage resistance NumberValue to an enemy
function ResistanceUtility:AddDamageResistance(enemy, resistancePercent)
	if not enemy or not enemy:IsA("Model") then
		warn("Invalid enemy model provided")
		return false
	end

	-- Clamp resistance between 0 and 100
	resistancePercent = math.clamp(resistancePercent or 0, 0, 100)
	local resistanceValue = resistancePercent / 100 -- Convert to decimal

	-- Create or update DamageResistance NumberValue
	local damageResistance = enemy:FindFirstChild("DamageResistance")
	if not damageResistance then
		damageResistance = Instance.new("NumberValue")
		damageResistance.Name = "DamageResistance"
		damageResistance.Parent = enemy
	end

	damageResistance.Value = resistanceValue
	print("✅ Added " .. resistancePercent .. "% damage resistance to " .. enemy.Name)
	return true
end

-- Function to add defense resistance NumberValue to an enemy
function ResistanceUtility:AddDefenseResistance(enemy, resistancePercent)
	if not enemy or not enemy:IsA("Model") then
		warn("Invalid enemy model provided")
		return false
	end

	-- Clamp resistance between 0 and 100
	resistancePercent = math.clamp(resistancePercent or 0, 0, 100)
	local resistanceValue = resistancePercent / 100 -- Convert to decimal

	-- Create or update DefenseResistance NumberValue
	local defenseResistance = enemy:FindFirstChild("DefenseResistance")
	if not defenseResistance then
		defenseResistance = Instance.new("NumberValue")
		defenseResistance.Name = "DefenseResistance"
		defenseResistance.Parent = enemy
	end

	defenseResistance.Value = resistanceValue
	print("✅ Added " .. resistancePercent .. "% defense resistance to " .. enemy.Name)
	return true
end

-- Function to add both resistances at once
function ResistanceUtility:AddBothResistances(enemy, damageResistancePercent, defenseResistancePercent)
	if not enemy or not enemy:IsA("Model") then
		warn("Invalid enemy model provided")
		return false
	end

	local success1 = self:AddDamageResistance(enemy, damageResistancePercent)
	local success2 = self:AddDefenseResistance(enemy, defenseResistancePercent)

	return success1 and success2
end

-- Function to remove all resistances from an enemy
function ResistanceUtility:RemoveResistances(enemy)
	if not enemy or not enemy:IsA("Model") then
		warn("Invalid enemy model provided")
		return false
	end

	local damageResistance = enemy:FindFirstChild("DamageResistance")
	local defenseResistance = enemy:FindFirstChild("DefenseResistance")

	if damageResistance then
		damageResistance:Destroy()
	end

	if defenseResistance then
		defenseResistance:Destroy()
	end

	print("🗑️ Removed all resistances from " .. enemy.Name)
	return true
end

-- Function to get current resistance values
function ResistanceUtility:GetResistances(enemy)
	if not enemy or not enemy:IsA("Model") then
		return nil
	end

	local damageResistance = enemy:FindFirstChild("DamageResistance")
	local defenseResistance = enemy:FindFirstChild("DefenseResistance")

	return {
		damageResistance = damageResistance and (damageResistance.Value * 100) or 0,
		defenseResistance = defenseResistance and (defenseResistance.Value * 100) or 0
	}
end

-- Function to apply resistances to all enemies of a specific name
function ResistanceUtility:ApplyToAllEnemiesNamed(enemyName, damageResistancePercent, defenseResistancePercent)
	local count = 0

	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name == enemyName then
			-- Check if it's actually an enemy (has Humanoid but no Player)
			local humanoid = obj:FindFirstChild("Humanoid")
			if humanoid and not game.Players:GetPlayerFromCharacter(obj) then
				if self:AddBothResistances(obj, damageResistancePercent, defenseResistancePercent) then
					count = count + 1
				end
			end
		end
	end

	print("📊 Applied resistances to " .. count .. " enemies named '" .. enemyName .. "'")
	return count
end

-- ADMIN COMMANDS for easy testing
game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		-- Only allow certain players to use admin commands
		if player.Name == "greatcoolroblox22" then -- Replace with your username
			local args = string.split(message, " ")

			-- Command: /resist [enemyName] [damageResist] [defenseResist]
			-- Example: /resist Zombie 25 15
			if args[1]:lower() == "/resist" and args[2] and args[3] then
				local enemyName = args[2]
				local damageResist = tonumber(args[3]) or 0
				local defenseResist = tonumber(args[4]) or 0

				local count = ResistanceUtility:ApplyToAllEnemiesNamed(enemyName, damageResist, defenseResist)
				game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
					"Applied " .. damageResist .. "% damage resistance and " .. 
						defenseResist .. "% defense resistance to " .. count .. " " .. enemyName .. " enemies",
					"All"
				)

				-- Command: /checkresist [enemyName]
				-- Example: /checkresist Zombie
			elseif args[1]:lower() == "/checkresist" and args[2] then
				local enemyName = args[2]

				for _, obj in pairs(workspace:GetChildren()) do
					if obj:IsA("Model") and obj.Name == enemyName then
						local humanoid = obj:FindFirstChild("Humanoid")
						if humanoid and not game.Players:GetPlayerFromCharacter(obj) then
							local resistances = ResistanceUtility:GetResistances(obj)
							if resistances then
								print(enemyName .. " resistances: " .. resistances.damageResistance .. 
									"% damage, " .. resistances.defenseResistance .. "% defense")
							end
							break -- Only check first one found
						end
					end
				end

				-- Command: /clearresist [enemyName]
				-- Example: /clearresist Zombie
			elseif args[1]:lower() == "/clearresist" and args[2] then
				local enemyName = args[2]
				local count = 0

				for _, obj in pairs(workspace:GetChildren()) do
					if obj:IsA("Model") and obj.Name == enemyName then
						local humanoid = obj:FindFirstChild("Humanoid")
						if humanoid and not game.Players:GetPlayerFromCharacter(obj) then
							if ResistanceUtility:RemoveResistances(obj) then
								count = count + 1
							end
						end
					end
				end

				game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
					"Removed resistances from " .. count .. " " .. enemyName .. " enemies",
					"All"
				)
			end
		end
	end)
end)

--print("🛡️ Resistance Utility loaded!")
print("💬 Admin commands available:")
print("   /resist [enemyName] [damageResist%] [defenseResist%]")
print("   /checkresist [enemyName]")
print("   /clearresist [enemyName]")

return ResistanceUtility