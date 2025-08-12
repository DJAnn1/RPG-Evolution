local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local healthLabel = script.Parent.healthFrame.healthText
local healthbarBg = script.Parent.healthFrame
local healthbarFill = script.Parent.healthFrame.healthBar
local gui = script.Parent

gui.Enabled = true

local function updateHealth()
	local currentHealth = humanoid.Health
	local maxHealth = humanoid.MaxHealth
	
	local ratio = math.clamp(currentHealth / maxHealth, 0, 1)
	healthbarFill.Size = UDim2.new(ratio, 0, 1, 0)
	healthLabel.Text = "Health: " .. math.floor(humanoid.Health) .. " / " .. humanoid.MaxHealth
end

humanoid:GetPropertyChangedSignal("Health"):Connect(updateHealth)
humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	humanoid:GetPropertyChangedSignal("Health"):Connect(updateHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	updateHealth()
end)

updateHealth()
