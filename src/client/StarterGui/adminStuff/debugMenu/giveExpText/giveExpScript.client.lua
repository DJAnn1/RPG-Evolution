local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = replicatedStorage.REtestStuff:WaitForChild("giveExpEvent")
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui

local function requestExp()
	remoteEvent:FireServer()
	--print("exp button clicked")
end


button.MouseButton1Click:Connect(requestExp)