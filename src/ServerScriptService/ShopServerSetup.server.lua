-- ShopServerSetup.lua - Server script to handle shop events and integrate with existing systems
-- Place this in ServerScriptService alongside your other scripts
local ShopManager = require(script.Parent:WaitForChild("ShopManager"))
local ShopConfig = require(game.ReplicatedStorage:WaitForChild("ShopConfig"))
local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create shop events folder
local function createShopEvents()
	local shopEvents = ReplicatedStorage:FindFirstChild("shopEvents")
	if not shopEvents then
		shopEvents = Instance.new("Folder")
		shopEvents.Name = "shopEvents"
		shopEvents.Parent = ReplicatedStorage
	end

	-- Create purchase item event
	if not shopEvents:FindFirstChild("purchaseItem") then
		local purchaseItem = Instance.new("RemoteEvent")
		purchaseItem.Name = "purchaseItem"
		purchaseItem.Parent = shopEvents
	end

	-- Create purchase response event
	if not shopEvents:FindFirstChild("purchaseResponse") then
		local purchaseResponse = Instance.new("RemoteEvent")
		purchaseResponse.Name = "purchaseResponse"
		purchaseResponse.Parent = shopEvents
	end

	-- Create gold notification event
	if not shopEvents:FindFirstChild("goldNotification") then
		local goldNotification = Instance.new("RemoteEvent")
		goldNotification.Name = "goldNotification"
		goldNotification.Parent = shopEvents
	end

	return shopEvents
end

-- Create inventory events folder
local function createInventoryEvents()
	local inventoryEvents = ReplicatedStorage:FindFirstChild("inventoryEvents")
	if not inventoryEvents then
		inventoryEvents = Instance.new("Folder")
		inventoryEvents.Name = "inventoryEvents"
		inventoryEvents.Parent = ReplicatedStorage
	end

	-- Create use item event
	if not inventoryEvents:FindFirstChild("useItem") then
		local useItem = Instance.new("RemoteEvent")
		useItem.Name = "useItem"
		useItem.Parent = inventoryEvents
	end

	-- Create use item response event
	if not inventoryEvents:FindFirstChild("useItemResponse") then
		local useItemResponse = Instance.new("RemoteEvent")
		useItemResponse.Name = "useItemResponse"
		useItemResponse.Parent = inventoryEvents
	end

	-- Create inventory update event
	if not inventoryEvents:FindFirstChild("inventoryUpdate") then
		local inventoryUpdate = Instance.new("RemoteEvent")
		inventoryUpdate.Name = "inventoryUpdate"
		inventoryUpdate.Parent = inventoryEvents
	end

	-- Create get inventory event
	if not inventoryEvents:FindFirstChild("getInventory") then
		local getInventory = Instance.new("RemoteEvent")
		getInventory.Name = "getInventory"
		getInventory.Parent = inventoryEvents
	end

	-- Create inventory data event
	if not inventoryEvents:FindFirstChild("inventoryData") then
		local inventoryData = Instance.new("RemoteEvent")
		inventoryData.Name = "inventoryData"
		inventoryData.Parent = inventoryEvents
	end

	-- Create get cooldown event
	if not inventoryEvents:FindFirstChild("getCooldown") then
		local getCooldown = Instance.new("RemoteEvent")
		getCooldown.Name = "getCooldown"
		getCooldown.Parent = inventoryEvents
	end

	-- Create cooldown data event
	if not inventoryEvents:FindFirstChild("cooldownData") then
		local cooldownData = Instance.new("RemoteEvent")
		cooldownData.Name = "cooldownData"
		cooldownData.Parent = inventoryEvents
	end

	return inventoryEvents
end

-- Connect shop events
local function connectShopEvents(shopEvents)
	-- Handle item purchases
	shopEvents.purchaseItem.OnServerEvent:Connect(function(player, itemName)
		local success, message = ShopManager:PurchaseItem(player, itemName)
		shopEvents.purchaseResponse:FireClient(player, success, message)
	end)
end

-- Connect inventory events
local function connectInventoryEvents(inventoryEvents)
	-- Handle item usage
	inventoryEvents.useItem.OnServerEvent:Connect(function(player, itemName)
		local success, message = ShopManager:UseInventoryItem(player, itemName)
		inventoryEvents.useItemResponse:FireClient(player, success, message)
	end)

	-- Handle inventory requests
	inventoryEvents.getInventory.OnServerEvent:Connect(function(player)
		local inventory = ShopManager:GetPlayerInventory(player)
		inventoryEvents.inventoryData:FireClient(player, inventory)
	end)

	-- Handle cooldown requests
	inventoryEvents.getCooldown.OnServerEvent:Connect(function(player, cooldownGroup)
		local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))
		local onCooldown, remainingTime = InventoryManager:IsGroupOnCooldown(player, cooldownGroup)
		inventoryEvents.cooldownData:FireClient(player, cooldownGroup, onCooldown, remainingTime or 0)
	end)
end

-- DISABLED: Kill event integration (now handled by LevelSystem)
--[[
local function integrateWithKillEvents()
	-- COMMENTED OUT: This was causing duplicate gold rewards
	-- LevelSystem now handles all kill rewards centrally
	print("⚠️ Kill event integration disabled - handled by LevelSystem")
end
--]]

-- DISABLED: Quest event integration (now handled by UnifiedQuestManager)
--[[
local function integrateWithQuestEvents()
	-- COMMENTED OUT: This was causing duplicate gold rewards
	-- UnifiedQuestManager now uses LevelSystem for quest rewards
	print("⚠️ Quest event integration disabled - handled by LevelSystem")
end
--]]

-- Handle player joining
local function onPlayerAdded(player)
	ShopManager:CreatePlayerGold(player)
end

-- Initialize the shop system
local function initialize()
	local shopEvents = createShopEvents()
	local inventoryEvents = createInventoryEvents()
	connectShopEvents(shopEvents)
	connectInventoryEvents(inventoryEvents)
	-- DISABLED: Duplicate reward systems
	-- integrateWithKillEvents()
	-- integrateWithQuestEvents()

	-- Connect player events
	game.Players.PlayerAdded:Connect(onPlayerAdded)

	-- Handle players already in game
	for _, player in pairs(game.Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	--print("🛍️ Shop System initialized! (Kill/Quest rewards handled by LevelSystem)")
end

-- Start the system
initialize()