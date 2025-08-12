local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = replicatedStorage.REtestStuff:WaitForChild("makeOPEvent")
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui

local function makeOP()
	remoteEvent:FireServer()
end


button.MouseButton1Click:Connect(makeOP)