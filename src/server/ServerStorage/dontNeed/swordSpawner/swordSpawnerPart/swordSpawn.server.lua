local Players = game:GetService("Players")
local swordModel = game.ReplicatedStorage:FindFirstChild("Sword")

local function spawnSword(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	-- Check if the player already has a Sword (by name)
	if backpack:FindFirstChild("Sword") then
		return
	end
	local sword = swordModel:Clone()
	sword.Parent = backpack
	print("Sword has been cloned for", player.Name)
end

local function checkInventorySpace(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return false end
	-- Only allow one Sword in the backpack
	if backpack:FindFirstChild("Sword") then
		return false
	else
		return true
	end
end

script.Parent.Touched:Connect(function(hit)
	local character = hit.Parent
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	if checkInventorySpace(player) then
		spawnSword(player)
	end
end)

