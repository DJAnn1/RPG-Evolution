-- GoldDebugger.lua - Place in ServerScriptService to track all gold changes
local Players = game:GetService("Players")

-- Function to track gold changes for a player
local function trackPlayerGold(player)
	local leaderstats = player:WaitForChild("leaderstats")
	local gold = leaderstats:WaitForChild("Gold")

	print("=== GOLD TRACKER STARTED FOR " .. player.Name .. " ===")
	print("Initial Gold: " .. gold.Value)

	gold.Changed:Connect(function()
		print("🟡 GOLD CHANGED for " .. player.Name .. ": " .. gold.Value)
		print("📍 Source trace:")
		print(debug.traceback())
		print("=====================================")
	end)
end

-- Track all players
Players.PlayerAdded:Connect(trackPlayerGold)

-- Track existing players
for _, player in pairs(Players:GetPlayers()) do
	if player:FindFirstChild("leaderstats") then
		trackPlayerGold(player)
	else
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				trackPlayerGold(player)
			end
		end)
	end
end

--print("Gold Debugger: Tracking all gold changes with stack traces")