local tool = script.Parent
local player = nil

-- When the tool is equipped, find the player
tool.Equipped:Connect(function()
	local character = tool.Parent
	player = game.Players:GetPlayerFromCharacter(character)
end)

-- Damage logic when the handle touches something
tool.Handle.Touched:Connect(function(hit)
	if not player then return end

	local character = tool.Parent
	local humanoid = hit.Parent and hit.Parent:FindFirstChild("Humanoid")

	-- Prevent damaging yourself or non-humanoids
	if humanoid and hit.Parent ~= character then
		-- Basic cooldown so we don't spam hit
		if not humanoid:FindFirstChild("AlreadyHit") then
			-- Tag the humanoid with the attacker
			local tag = Instance.new("ObjectValue")
			tag.Name = "creator"
			tag.Value = player
			tag.Parent = humanoid

			-- Clean up tag after 2 seconds
			game.Debris:AddItem(tag, 2)

			-- Simple hit cooldown tag
			local marker = Instance.new("BoolValue")
			marker.Name = "AlreadyHit"
			marker.Parent = humanoid
			game.Debris:AddItem(marker, 1)

			-- Damage
			humanoid:TakeDamage(20)
		end
	end
end)
