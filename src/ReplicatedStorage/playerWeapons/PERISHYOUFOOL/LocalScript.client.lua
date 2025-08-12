local tool = script.Parent
local player = game.Players.LocalPlayer
local click = game:GetService("ReplicatedStorage"):WaitForChild("clickBoom")

local mouse = player:GetMouse()

tool.Activated:Connect(function()
	if mouse then
		click:FireServer(mouse.Hit.Position)
	end
end)
