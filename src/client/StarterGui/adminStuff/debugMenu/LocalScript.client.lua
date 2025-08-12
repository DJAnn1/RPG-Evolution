local Players = game:GetService("Players")
local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local gui = script.Parent
gui.Enabled = false

local allowedUserIds = {
	17476255,       -- great
	1103430971,     -- cae
	489106246,       -- spider
	5454365			--calvin
}

-- Wait for the GUI to be fully parented to PlayerGui
repeat wait() until gui:IsDescendantOf(Players.LocalPlayer:WaitForChild("PlayerGui"))

if table.find(allowedUserIds, player.UserId) then
	gui.Enabled = true
end
