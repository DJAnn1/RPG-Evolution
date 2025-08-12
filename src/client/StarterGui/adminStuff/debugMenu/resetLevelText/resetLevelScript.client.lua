local button = script.Parent
local replicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = replicatedStorage.REtestStuff.resetLvl
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui

local function requestLevelRemoval()
	remoteEvent:FireServer()
	--print("reset lvl button clicked")
end


button.MouseButton1Click:Connect(requestLevelRemoval)