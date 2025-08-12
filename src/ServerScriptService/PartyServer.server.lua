-- Party Server Script
-- Place this in ServerScriptService
local PartySystem = require(game.ReplicatedStorage:WaitForChild("PartySystem"))
local Players = game:GetService("Players")

-- Initialize remote events
local remotes = PartySystem:InitializeRemoteEvents()

-- Debug print to verify remotes are created
--print("Party remotes initialized:")
for name, remote in pairs(remotes) do
	--print(" - " .. name .. ": " .. tostring(remote))
end

-- Function to update all party members' UI
local function updatePartyUI(partyId)
	-- If partyId is a string, we need to get the party data differently
	local party = nil

	if typeof(partyId) == "string" then
		-- partyId is actually a party ID string
		-- We need to find any member of this party to get the party data
		local allParties = PartySystem:GetAllParties()
		party = allParties[partyId]
	else
		-- partyId might actually be a player object, get their party
		party = PartySystem:GetPlayerParty(partyId)
	end

	if not party then return end

	for _, member in ipairs(party.members) do
		if member and member.Parent then
			remotes.UpdatePartyUI:FireClient(member, party)
		end
	end
end

-- Function to notify player about invite
local function notifyInvite(player, inviter)
	remotes.UpdatePartyUI:FireClient(player, "invite", {
		inviter = inviter,
		inviterName = inviter.Name
	})
end

-- Create Party
remotes.CreateParty.OnServerEvent:Connect(function(player)
	local success, result = PartySystem:CreateParty(player)
	if success then
		updatePartyUI(result)
		remotes.UpdatePartyUI:FireClient(player, "created", result)
	else
		remotes.UpdatePartyUI:FireClient(player, "error", result)
	end
end)

-- Invite to Party
remotes.InviteToParty.OnServerEvent:Connect(function(player, targetPlayerName)
	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then
		remotes.UpdatePartyUI:FireClient(player, "error", "Player not found")
		return
	end

	local success, result = PartySystem:InviteToParty(player, targetPlayer)
	if success then
		notifyInvite(targetPlayer, player)
		remotes.UpdatePartyUI:FireClient(player, "success", "Invite sent to " .. targetPlayerName)
	else
		remotes.UpdatePartyUI:FireClient(player, "error", result)
	end
end)

-- Accept Invite
remotes.AcceptInvite.OnServerEvent:Connect(function(player)
	local success, result = PartySystem:AcceptInvite(player)
	if success then
		updatePartyUI(result)
		remotes.UpdatePartyUI:FireClient(player, "joined")
	else
		remotes.UpdatePartyUI:FireClient(player, "error", result)
	end
end)

-- Decline Invite
remotes.DeclineInvite.OnServerEvent:Connect(function(player)
	PartySystem:DeclineInvite(player)
	remotes.UpdatePartyUI:FireClient(player, "declined")
end)

-- Leave Party
remotes.LeaveParty.OnServerEvent:Connect(function(player)
	local party = PartySystem:GetPlayerParty(player)
	local partyMembers = party and party.members or {}
	local success, result = PartySystem:LeaveParty(player)

	if success then
		-- Update UI for remaining members
		for _, member in ipairs(partyMembers) do
			if member ~= player and member.Parent then
				local updatedParty = PartySystem:GetPlayerParty(member)
				remotes.UpdatePartyUI:FireClient(member, updatedParty)
			end
		end
		remotes.UpdatePartyUI:FireClient(player, "left")
	end
end)

-- Kick from Party
remotes.KickFromParty.OnServerEvent:Connect(function(player, targetPlayerName)
	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then
		remotes.UpdatePartyUI:FireClient(player, "error", "Player not found")
		return
	end

	local party = PartySystem:GetPlayerParty(player)
	local success, result = PartySystem:KickFromParty(player, targetPlayer)

	if success then
		-- Get updated party info for remaining members
		local updatedParty = PartySystem:GetPlayerParty(player)
		if updatedParty then
			for _, member in ipairs(updatedParty.members) do
				if member.Parent then
					remotes.UpdatePartyUI:FireClient(member, updatedParty)
				end
			end
		end
		remotes.UpdatePartyUI:FireClient(targetPlayer, "kicked")
		remotes.UpdatePartyUI:FireClient(player, "success", targetPlayerName .. " has been kicked")
	else
		remotes.UpdatePartyUI:FireClient(player, "error", result)
	end
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	PartySystem:PlayerLeft(player)
end)

-- Export function to check if players are in same party (for damage system)
_G.PartySystem = PartySystem