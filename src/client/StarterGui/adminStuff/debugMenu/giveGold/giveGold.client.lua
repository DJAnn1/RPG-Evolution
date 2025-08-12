local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = replicatedStorage.REtestStuff:WaitForChild("giveGoldEvent")
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui

local function requestGold()
	remoteEvent:FireServer()
	--print("gold button clicked")
end


button.MouseButton1Click:Connect(requestGold)