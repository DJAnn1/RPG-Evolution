local statPointsLabel = script.Parent
local player = game.Players.LocalPlayer
local statpoints = player:WaitForChild("statsFolder"):WaitForChild("statPoints")

while true do
	statPointsLabel.Text = "Statpoints left: " .. statpoints.Value
	task.wait()
end