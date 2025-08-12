--Rescripted by Luckymaxer
--EUROCOW WAS HERE BECAUSE I MADE THE PARTICLES AND THEREFORE THIS ENTIRE SWORD PRETTY AND LOOK PRETTY WORDS AND I'D LIKE TO DEDICATE THIS TO MY FRIENDS AND HI LUCKYMAXER PLS FIX SFOTH SWORDS TY LOVE Y'ALl
--Updated for R15 avatars by StarWars
--Re-updated by TakeoHonorable
--Modified for multi-player kill credit system

Tool = script.Parent
Handle = Tool:WaitForChild("Handle")
local hitCooldowns = {} -- Tracks cooldowns per humanoid


local function checkInventorySpace(player)
	if not player then return false end

	-- Check Backpack and Character for ClassicSword
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if (backpack and backpack:FindFirstChild("ClassicSword")) or 
		(character and character:FindFirstChild("ClassicSword")) then
		return false -- Already has the sword
	end

	return true -- No sword found, it's okay to give
end

function Create(ty)
	return function(data)
		local obj = Instance.new(ty)
		for k, v in pairs(data) do
			if type(k) == 'number' then
				v.Parent = obj
			else
				obj[k] = v
			end
		end
		return obj
	end
end

local BaseUrl = "rbxassetid://"

Players = game:GetService("Players")
Debris = game:GetService("Debris")
RunService = game:GetService("RunService")

DamageValues = {
	BaseDamage = 5,
	SlashDamage = 15,
	LungeDamage = 30
}

--For R15 avatars
Animations = {
	R15Slash = 522635514,
	R15Lunge = 522638767
}

Damage = DamageValues.BaseDamage

Grips = {
	Up = CFrame.new(0, 0, -1.70000005, 0, 0, 1, 1, 0, 0, 0, 1, 0),
	Out = CFrame.new(0, 0, -1.70000005, 0, 1, 0, 1, -0, 0, 0, 0, -1)
}

Sounds = {
	Slash = Handle:WaitForChild("SwordSlash"),
	Lunge = Handle:WaitForChild("SwordLunge"),
	Unsheath = Handle:WaitForChild("Unsheath")
}

ToolEquipped = false

for i, v in pairs(Handle:GetChildren()) do
	if v:IsA("ParticleEmitter") then
		v.Rate = 20
	end
end

Tool.Grip = Grips.Up
Tool.Enabled = true

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

-- Modified tagging system to support multiple players
function TagHumanoid(humanoid, player)
	-- Get or create the DamagersTable
	local damagersTable = humanoid:FindFirstChild("DamagersTable")
	if not damagersTable then
		damagersTable = Instance.new("Folder")
		damagersTable.Name = "DamagersTable"
		damagersTable.Parent = humanoid
	end

	-- Add this player to the damagers list if not already there
	local playerTag = damagersTable:FindFirstChild(player.Name)
	if not playerTag then
		playerTag = Instance.new("ObjectValue")
		playerTag.Name = player.Name
		playerTag.Value = player
		playerTag.Parent = damagersTable
		--Debris:AddItem(playerTag, 500) -- Remove after 30 seconds of no damage
	end

	-- Also keep the original creator tag for compatibility
	local Creator_Tag = humanoid:FindFirstChild("creator")
	if not Creator_Tag then
		Creator_Tag = Instance.new("ObjectValue")
		Creator_Tag.Name = "creator"
		Creator_Tag.Parent = humanoid
	end
	Creator_Tag.Value = player
	Debris:AddItem(Creator_Tag, 2)
end

function UntagHumanoid(humanoid)
	for i, v in pairs(humanoid:GetChildren()) do
		if v:IsA("ObjectValue") and v.Name == "creator" then
			v:Destroy()
		end
	end
end

-- New function to get all players who damaged this humanoid
function GetAllDamagers(humanoid)
	local damagers = {}
	local damagersTable = humanoid:FindFirstChild("DamagersTable")
	if damagersTable then
		for _, playerTag in pairs(damagersTable:GetChildren()) do
			if playerTag:IsA("ObjectValue") and playerTag.Value and playerTag.Value:IsA("Player") then
				table.insert(damagers, playerTag.Value)
			end
		end
	end

	-- Fallback to creator tag if no damagers table
	if #damagers == 0 then
		local creatorTag = humanoid:FindFirstChild("creator")
		if creatorTag and creatorTag.Value and creatorTag.Value:IsA("Player") then
			table.insert(damagers, creatorTag.Value)
		end
	end

	return damagers
end

local function GetDamageMultiplier(player)
	if not player then return 1 end
	local statsFolder = player:FindFirstChild("statsFolder")
	if not statsFolder then return 1 end
	local damageStat = statsFolder:FindFirstChild("damageStat")
	if not damageStat then return 1 end
	return 1 + 0.05 * damageStat.Value
end

function Blow(Hit)
	if not Hit or not Hit.Parent or not CheckIfAlive() or not ToolEquipped then
		return
	end
	local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if not RightArm then return end
	local RightGrip = RightArm:FindFirstChild("RightGrip")
	if not RightGrip or (RightGrip.Part0 ~= Handle and RightGrip.Part1 ~= Handle) then
		return
	end

	local character = Hit.Parent
	if character == Character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health == 0 then return end

	local player = Players:GetPlayerFromCharacter(character)
	if player and (player == Player or IsTeamMate(Player, player) or (_G.PartySystem and _G.PartySystem:AreInSameParty(Player, player))) then
		return
	end

	-- Cooldown check
	local currentTime = tick()
	local lastHit = hitCooldowns[humanoid]
	if lastHit and (currentTime - lastHit) < 0.5 then
		return -- Too soon, exit
	end
	hitCooldowns[humanoid] = currentTime

	TagHumanoid(humanoid, Player)
	humanoid:TakeDamage(Damage)
end


function Attack()
	local multiplier = GetDamageMultiplier(Player)
	Damage = DamageValues.SlashDamage * multiplier
	--print("[ATTACK] DamageStat Multiplier:", multiplier, "| Final Damage:", Damage)
	Sounds.Slash:Play()

	if Humanoid then
		if Humanoid.RigType == Enum.HumanoidRigType.R6 then
			local Anim = Instance.new("StringValue")
			Anim.Name = "toolanim"
			Anim.Value = "Slash"
			Anim.Parent = Tool
		elseif Humanoid.RigType == Enum.HumanoidRigType.R15 then
			local Anim = Tool:FindFirstChild("R15Slash")
			if Anim then
				local Track = Humanoid:LoadAnimation(Anim)
				Track:Play(0)
			end
		end
	end
end

function Lunge()
	local multiplier = GetDamageMultiplier(Player)
	Damage = DamageValues.LungeDamage * multiplier
	--print("[LUNGE] DamageStat Multiplier:", multiplier, "| Final Damage:", Damage)
	Sounds.Lunge:Play()

	if Humanoid then
		if Humanoid.RigType == Enum.HumanoidRigType.R6 then
			local Anim = Instance.new("StringValue")
			Anim.Name = "toolanim"
			Anim.Value = "Lunge"
			Anim.Parent = Tool
		elseif Humanoid.RigType == Enum.HumanoidRigType.R15 then
			local Anim = Tool:FindFirstChild("R15Lunge")
			if Anim then
				local Track = Humanoid:LoadAnimation(Anim)
				Track:Play(0)
			end
		end
	end	

	wait(0.2)
	Tool.Grip = Grips.Out
	wait(0.6)
	Tool.Grip = Grips.Up

	Damage = DamageValues.SlashDamage * multiplier
end

Tool.Enabled = true
LastAttack = 0

function Activated()
	if not Tool.Enabled or not ToolEquipped or not CheckIfAlive() then
		return
	end
	Tool.Enabled = false
	local Tick = RunService.Stepped:wait()
	if (Tick - LastAttack < 0.2) then
		Lunge()
	else
		Attack()
	end
	LastAttack = Tick
	--wait(0.5)
	Damage = DamageValues.BaseDamage
	local SlashAnim = (Tool:FindFirstChild("R15Slash") or Create("Animation"){
		Name = "R15Slash",
		AnimationId = BaseUrl .. Animations.R15Slash,
		Parent = Tool
	})

	local LungeAnim = (Tool:FindFirstChild("R15Lunge") or Create("Animation"){
		Name = "R15Lunge",
		AnimationId = BaseUrl .. Animations.R15Lunge,
		Parent = Tool
	})
	Tool.Enabled = true
end

function CheckIfAlive()
	return (((Player and Player.Parent and Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0 and Torso and Torso.Parent) and true) or false)
end

function Equipped()
	Character = Tool.Parent
	Player = Players:GetPlayerFromCharacter(Character)
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("HumanoidRootPart")
	if not CheckIfAlive() then
		return
	end
	ToolEquipped = true
	Sounds.Unsheath:Play()
end

function Unequipped()
	Tool.Grip = Grips.Up
	ToolEquipped = false
end

Tool.Activated:Connect(Activated)
Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)

Connection = Handle.Touched:Connect(Blow)