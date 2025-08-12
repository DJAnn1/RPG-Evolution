local kingTP = game.Workspace.areas.area1.desert.arabKingTP
local templeEntrance = script.Parent

local pos1 = templeEntrance.Position
local pos2 = kingTP.Position

local debounce = {}

templeEntrance.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = game.Players:GetPlayerFromCharacter(character)
	if player and not debounce[player] then
		debounce[player] = true
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(pos2)
		end
		wait(1)
		debounce[player] = false
	end
end)
