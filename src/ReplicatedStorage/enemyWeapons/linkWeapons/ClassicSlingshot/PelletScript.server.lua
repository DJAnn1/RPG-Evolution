local debris = game:service("Debris")
pellet = script.Parent
damage = 35

function onTouched(hit)
	if not hit or not hit.Parent then return end
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		tagHumanoid(humanoid)
		humanoid:TakeDamage(damage)
	else
		damage = damage / 2
		if damage < 1 then
			connection:Disconnect()
			pellet.Parent = nil
		end
	end
end

function tagHumanoid(humanoid)
	-- todo: make tag expire
	local tag = pellet:FindFirstChild("creator")
	if tag then
		-- kill all other tags
		while(humanoid:FindFirstChild("creator")) do
			humanoid:findFirstChild("creator").Parent = nil
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
