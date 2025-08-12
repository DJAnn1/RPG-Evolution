local dmgNum = script.Parent

while true do
	dmgNum.Text = game.Players.LocalPlayer.statsFolder.damageStat.Value
	wait(0.1)
end