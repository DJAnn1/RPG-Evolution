local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local statsEvents = replicatedStorage.statsEvents
local speedUp = statsEvents:WaitForChild("speedUp")

button.MouseButton1Click:Connect(function()
	speedUp:FireServer()
end)