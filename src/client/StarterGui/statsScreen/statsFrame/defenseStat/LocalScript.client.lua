local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local statsEvents = replicatedStorage.statsEvents
local defenseUp = statsEvents:WaitForChild("defenseUp")

button.MouseButton1Click:Connect(function()
	defenseUp:FireServer()
end)