local speedNum = script.Parent

while true do
	speedNum.Text = game.Players.LocalPlayer.statsFolder.speedStat.Value
	wait(0.1)
end