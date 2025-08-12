local Players = game:GetService("Players")

-- Whitelist: Add allowed usernames or UserIds here
local WHITELIST = {
    -- Example: ["PlayerName"] = true,
    -- Example: [12345678] = true,
    -- Replace/add your allowed users below:
    ["YourUsernameHere"] = true,
    -- [UserIdHere] = true,
}

local function isWhitelisted(player)
    -- Check by Username or UserId
    if WHITELIST[player.Name] or WHITELIST[player.UserId] then
        return true
    end
    return false
end

local function onPlayerAdded(player)
    if not isWhitelisted(player) then
        player:Kick("You are not whitelisted to join this game.")
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Also check existing players in case script is added during runtime
for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end

