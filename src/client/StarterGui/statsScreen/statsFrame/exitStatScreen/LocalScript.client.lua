local statsScreen = script.Parent.Parent
local button = script.Parent

button.MouseButton1Click:Connect(function()
	if statsScreen.Visible then
		statsScreen.Visible = false
	end
end)