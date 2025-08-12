local debris = game:service("Debris")
local Players = game:GetService("Players")
pellet = script.Parent
damage = 8

local function GetDamageMultiplier(player)
	if not player then return 1 end
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then return 1 end
	local damageStat = statsFolder:FindFirstChild("damageStat")
	if not damageStat then return 1 end
	return 1 + 0.05 * damageStat.Value
end

function onTouched(hit)
	if not hit or not hit.Parent then return end
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Get the creator (shooter) from the pellet itself
	local creatorTag = pellet:FindFirstChild("creator")
	if not creatorTag or not creatorTag.Value then return end
	local shooter = creatorTag.Value

	-- Prevent damaging self
	local targetPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
	if shooter == targetPlayer or (_G.PartySystem and _G.PartySystem:AreInSameParty(shooter, targetPlayer)) then
		return
	end


	local multiplier = GetDamageMultiplier(shooter)
	local finalDamage = damage * multiplier
	tagHumanoid(humanoid)
	humanoid:TakeDamage(finalDamage)
	--print("Final Damage:", finalDamage)

	-- Destroy pellet after hitting someone
	pellet:Destroy()
end

function tagHumanoid(humanoid)
	-- todo: make tag expire
	local tag = pellet:FindFirstChild("creator")
	if tag then
		-- kill all other tags
		while(humanoid:FindFirstChild("creator")) do
			humanoid:FindFirstChild("creator").Parent = nil
		end
		local new_tag = tag:Clone()
		new_tag.Parent = humanoid
		debris:AddItem(new_tag, 1)
	end
end

connection = pellet.Touched:Connect(onTouched)
r = game:service("RunService")
t, s = r.Stepped:Wait()
d = t + 2.0 - s
while t < d do
	t = r.Stepped:Wait()
end
pellet:Destroy()