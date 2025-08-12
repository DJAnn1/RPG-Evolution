

local statsScreen = script.Parent.Parent.statsFrame
local button = script.Parent
button.Visible = true

button.MouseButton1Click:Connect(function()
	if not statsScreen.Visible then
		statsScreen.Visible = true
	elseif statsScreen.Visible then
		statsScreen.Visible = false
	end
end)