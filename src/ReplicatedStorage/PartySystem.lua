local PartySystem = {}
PartySystem.__index = PartySystem

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Initialize remote events (call this from server ONLY)
function PartySystem:InitializeRemoteEvents()
	-- Clean up existing folder if it exists
	local existingFolder = ReplicatedStorage:FindFirstChild("PartyRemotes")
	if existingFolder then
		existingFolder:Destroy()
	end

	local remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "PartyRemotes"
	remoteFolder.Parent = ReplicatedStorage

	-- List of remote event names
	local eventNames = {
		"CreateParty",
		"JoinParty", 
		"LeaveParty",
		"KickFromParty",
		"InviteToParty",
		"AcceptInvite",
		"DeclineInvite",
		"UpdatePartyUI"
	}

	-- Create and return the remote events
	local remotes = {}
	for _, eventName in ipairs(eventNames) do
		local remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = eventName
		remoteEvent.Parent = remoteFolder
		remotes[eventName] = remoteEvent
	end

	return remotes
end

-- Get remote events (call this from client)
function PartySystem:GetRemoteEvents()
	local remoteFolder = ReplicatedStorage:WaitForChild("PartyRemotes")

	local remotes = {}
	local eventNames = {
		"CreateParty",
		"JoinParty",
		"LeaveParty", 
		"KickFromParty",
		"InviteToParty",
		"AcceptInvite",
		"DeclineInvite",
		"UpdatePartyUI"
	}

	for _, eventName in ipairs(eventNames) do
		remotes[eventName] = remoteFolder:WaitForChild(eventName)
	end

	return remotes
end

-- Party data structure
local parties = {} -- [partyId] = {leader = Player, members = {Player1, Player2, ...}, invites = {Player1, Player2, ...}}
local playerParties = {} -- [Player] = partyId
local pendingInvites = {} -- [Player] = {partyId = partyId, inviter = Player}

-- Generate unique party ID
local function generatePartyId()
	return "party_" .. tick() .. "_" .. math.random(1000, 9999)
end

-- Create a new party
function PartySystem:CreateParty(leader)
	if playerParties[leader] then
		return false, "You are already in a party"
	end

	local partyId = generatePartyId()
	parties[partyId] = {
		leader = leader,
		members = {leader},
		invites = {}
	}
	playerParties[leader] = partyId

	return true, partyId
end

-- Invite player to party
function PartySystem:InviteToParty(inviter, targetPlayer)
	local partyId = playerParties[inviter]
	if not partyId then
		return false, "You are not in a party"
	end

	local party = parties[partyId]
	if party.leader ~= inviter then
		return false, "Only the party leader can invite players"
	end

	if playerParties[targetPlayer] then
		return false, "Player is already in a party"
	end

	if pendingInvites[targetPlayer] then
		return false, "Player already has a pending invite"
	end

	if #party.members >= 8 then -- Max party size of 8
		return false, "Party is full"
	end

	pendingInvites[targetPlayer] = {
		partyId = partyId,
		inviter = inviter
	}

	return true, "Invite sent"
end

-- Accept party invite
function PartySystem:AcceptInvite(player)
	local invite = pendingInvites[player]
	if not invite then
		return false, "No pending invite"
	end

	local party = parties[invite.partyId]
	if not party then
		pendingInvites[player] = nil
		return false, "Party no longer exists"
	end

	if #party.members >= 4 then
		pendingInvites[player] = nil
		return false, "Party is full"
	end

	table.insert(party.members, player)
	playerParties[player] = invite.partyId
	pendingInvites[player] = nil

	return true, invite.partyId
end

-- Decline party invite
function PartySystem:DeclineInvite(player)
	if pendingInvites[player] then
		pendingInvites[player] = nil
		return true
	end
	return false
end

-- Leave party
function PartySystem:LeaveParty(player)
	local partyId = playerParties[player]
	if not partyId then
		return false, "You are not in a party"
	end

	local party = parties[partyId]
	playerParties[player] = nil

	-- Remove from members list
	for i, member in ipairs(party.members) do
		if member == player then
			table.remove(party.members, i)
			break
		end
	end

	-- If leader leaves, transfer leadership or disband
	if party.leader == player then
		if #party.members > 0 then
			party.leader = party.members[1]
		else
			-- Disband party
			parties[partyId] = nil
			return true, "Party disbanded"
		end
	end

	-- If party becomes empty, remove it
	if #party.members == 0 then
		parties[partyId] = nil
	end

	return true, "Left party"
end

-- Kick player from party
function PartySystem:KickFromParty(kicker, targetPlayer)
	local partyId = playerParties[kicker]
	if not partyId then
		return false, "You are not in a party"
	end

	local party = parties[partyId]
	if party.leader ~= kicker then
		return false, "Only the party leader can kick players"
	end

	if targetPlayer == kicker then
		return false, "You cannot kick yourself"
	end

	if playerParties[targetPlayer] ~= partyId then
		return false, "Player is not in your party"
	end

	-- Remove player
	playerParties[targetPlayer] = nil
	for i, member in ipairs(party.members) do
		if member == targetPlayer then
			table.remove(party.members, i)
			break
		end
	end

	return true, "Player kicked"
end

-- Check if two players are in the same party
function PartySystem:AreInSameParty(player1, player2)
	local party1 = playerParties[player1]
	local party2 = playerParties[player2]

	return party1 and party2 and party1 == party2
end

-- Get player's party info
function PartySystem:GetPlayerParty(player)
	local partyId = playerParties[player]
	if not partyId then
		return nil
	end

	return parties[partyId]
end

-- Get all parties (for admin/debugging)
function PartySystem:GetAllParties()
	return parties
end

-- Get pending invite for player
function PartySystem:GetPendingInvite(player)
	return pendingInvites[player]
end

-- Cleanup when player leaves
function PartySystem:PlayerLeft(player)
	-- Clean up any pending invites
	pendingInvites[player] = nil

	-- Remove from party if in one
	local partyId = playerParties[player]
	if partyId then
		self:LeaveParty(player)
	end

	-- Remove any invites this player sent
	for invitedPlayer, invite in pairs(pendingInvites) do
		if invite.inviter == player then
			pendingInvites[invitedPlayer] = nil
		end
	end
end

return PartySystem