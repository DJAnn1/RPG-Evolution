local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local statsEvents = replicatedStorage.statsEvents
local damageUp = statsEvents:WaitForChild("damageUp")

button.MouseButton1Click:Connect(function()
	damageUp:FireServer()
end)