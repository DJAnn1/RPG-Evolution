local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = replicatedStorage.REtestStuff:WaitForChild("giveStatsEvent")
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui

local function requestStats()
	remoteEvent:FireServer()
	--print("stat button clicked")
end

button.MouseButton1Click:Connect(requestStats)