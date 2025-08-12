local player = game.Players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local levelSystem = require(rs:WaitForChild("LevelSystem"))

local expBarBg = script.Parent:WaitForChild("expBar")
local expBarFill = expBarBg:WaitForChild("expBarFill")
local levelText = expBarBg:WaitForChild("levelText")

local expGUI = script.Parent
expGUI.Enabled = true

local function updateExpBar()
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local exp = stats:FindFirstChild("EXP")
	local level = stats:FindFirstChild("Level")
	if not exp or not level then return end

	local currentExp = exp.Value
	local currentLevel = level.Value
	local requiredExp = levelSystem.GetExpToLevel(currentLevel)

	local ratio = math.clamp(currentExp / requiredExp, 0, 1)
	expBarFill.Size = UDim2.new(ratio, 0, 1, 0)

	levelText.Text = "Level: " .. tostring(currentLevel) .. " | EXP: " .. currentExp .. " / " .. requiredExp
end

player:WaitForChild("leaderstats"):WaitForChild("EXP").Changed:Connect(updateExpBar)
player:WaitForChild("leaderstats"):WaitForChild("Level").Changed:Connect(updateExpBar)

updateExpBar()
