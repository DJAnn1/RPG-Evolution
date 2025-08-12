-- ShopDialogueClient.lua - Client-side shop dialogue handler (LocalScript in StarterPlayerScripts)
local ShopConfig = require(game.ReplicatedStorage:WaitForChild("ShopConfig"))

local plr = game.Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local shopEvents = replicatedStorage:WaitForChild("shopEvents")
local inventoryEvents = replicatedStorage:WaitForChild("inventoryEvents")

-- Variables that need to be updated on character spawn
local character
local humanoid
local gui
local textBox
local textLabel
local sound
local shopGui
local shopFrame
local shopTitle
local itemsFrame
local closeButton
local goldLabel
local inventoryGui
local inventoryFrame
local inventoryTitle
local inventoryItemsFrame
local inventoryCloseButton
local inventoryToggleButton

local currentShopkeeper = nil
local isShopOpen = false
local isInventoryOpen = false
local playerInventory = {}
local itemCooldowns = {} -- Track cooldowns for UI updates

-- Function to setup GUI references
local function setupGUIReferences()
	-- Wait for PlayerGui to be ready
	local playerGui = plr:WaitForChild("PlayerGui")
	gui = playerGui:WaitForChild("dGui")
	textBox = gui:WaitForChild("textBox")
	textLabel = textBox:WaitForChild("textLabel")
	sound = gui:WaitForChild("talkSound")

	-- Shop GUI elements
	shopGui = gui:WaitForChild("shopGui")
	shopFrame = shopGui:WaitForChild("shopFrame")
	shopTitle = shopFrame:WaitForChild("shopTitle")
	itemsFrame = shopFrame:WaitForChild("itemsFrame")
	closeButton = shopFrame:WaitForChild("closeButton")
	goldLabel = shopFrame:WaitForChild("goldLabel")

	-- Inventory GUI elements
	inventoryGui = gui:WaitForChild("inventoryGui")
	inventoryFrame = inventoryGui:WaitForChild("inventoryFrame")
	inventoryTitle = inventoryFrame:WaitForChild("inventoryTitle")
	inventoryItemsFrame = inventoryFrame:WaitForChild("inventoryItemsFrame")
	inventoryCloseButton = inventoryFrame:WaitForChild("inventoryCloseButton")
	inventoryToggleButton = gui:WaitForChild("inventoryToggleButton")

	-- Initialize GUI state
	shopGui.Enabled = false
	inventoryGui.Enabled = false
	gui.Enabled = false
	textBox.Visible = false
end

-- Function to setup character references
local function setupCharacterReferences(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
end

-- Function to connect GUI events (call this after GUI setup)
local function connectGUIEvents()
	-- Close button functionality
	closeButton.MouseButton1Click:Connect(closeShop)
	inventoryCloseButton.MouseButton1Click:Connect(closeInventory)
	inventoryToggleButton.MouseButton1Click:Connect(toggleInventory)
end

-- Utility functions
local function getCurrentWalkSpeed()
	local statsFolder = plr:FindFirstChild("statsFolder")
	if statsFolder then
		local speedStat = statsFolder:FindFirstChild("speedStat")
		if speedStat then
			return 16 + (speedStat.Value * 1.5) 
		end
	end
	return 16 
end

local function writeText(text, waitTime)
	if not gui or not textBox or not textLabel or not sound or not humanoid then
		warn("GUI or character references not ready")
		return
	end

	-- Don't interfere with cursor if inventory or shop is open
	if not isInventoryOpen and not isShopOpen then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	gui.Enabled = true
	textBox.Visible = true
	textLabel.Text = text
	sound:Play()
	task.wait(waitTime)
end

local function endDialogue()
	if not gui or not textBox or not textLabel or not humanoid then
		return
	end

	gui.Enabled = false
	textBox.Visible = false
	textLabel.Text = ""
	-- Only restore movement if no GUIs are open, but NEVER disable cursor
	if not isInventoryOpen and not isShopOpen then
		humanoid.WalkSpeed = getCurrentWalkSpeed() 
		humanoid.JumpPower = 50
	end
	-- Keep cursor always enabled
	userInputService.MouseIconEnabled = true
end

-- NEW: Function to show temporary notification without blocking
local function showTemporaryNotification(message, duration)
	duration = duration or 2

	if not gui or not textBox or not textLabel or not sound then
		warn("GUI references not ready for notification")
		return
	end

	-- Store current dialogue state
	local wasGuiEnabled = gui.Enabled
	local wasTextBoxVisible = textBox.Visible
	local currentText = textLabel.Text

	-- Show notification
	gui.Enabled = true
	textBox.Visible = true
	textLabel.Text = message
	sound:Play()

	-- Auto-hide after duration
	task.spawn(function()
		task.wait(duration)

		-- Only hide if our message is still showing (prevents conflicts)
		if gui.Enabled and textBox.Visible and textLabel.Text == message then
			gui.Enabled = wasGuiEnabled
			textBox.Visible = wasTextBoxVisible
			textLabel.Text = currentText
		end
	end)
end

-- Function to update gold display
local function updateGoldDisplay()
	if not goldLabel then return end

	local leaderstats = plr:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		if gold then
			goldLabel.Text = "Gold: " .. gold.Value
		end
	end
end

-- Function to create item buttons in shop
local function createItemButtons(shopkeeperName)
	if not itemsFrame then return end

	-- Clear existing buttons
	for _, child in pairs(itemsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local shopkeeper = ShopConfig:GetShopkeeper(shopkeeperName)
	if not shopkeeper then return end

	local yPosition = 0
	for _, itemName in pairs(shopkeeper.items) do
		local item = ShopConfig:GetItem(itemName)
		if item then
			local itemButton = Instance.new("TextButton")
			itemButton.Size = UDim2.new(1, -20, 0, 60)
			itemButton.Position = UDim2.new(0, 10, 0, yPosition)
			itemButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			itemButton.BorderSizePixel = 2
			itemButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
			itemButton.Text = item.displayName .. " - " .. item.price .. " Gold\n" .. item.description
			itemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			itemButton.TextScaled = true
			itemButton.Font = Enum.Font.SourceSans
			itemButton.Name = itemName
			itemButton.Parent = itemsFrame

			-- Handle purchase
			itemButton.MouseButton1Click:Connect(function()
				shopEvents.purchaseItem:FireServer(itemName)
			end)

			-- Hover effects
			itemButton.MouseEnter:Connect(function()
				itemButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			end)

			itemButton.MouseLeave:Connect(function()
				itemButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			end)

			yPosition = yPosition + 70
		end
	end

	-- Resize the items frame based on content
	itemsFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition)
end

-- Function to create inventory item buttons
local function createInventoryButtons()
	if not inventoryItemsFrame then return end

	-- Clear existing buttons
	for _, child in pairs(inventoryItemsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local yPosition = 0
	for itemName, quantity in pairs(playerInventory) do
		if quantity > 0 then
			local item = ShopConfig:GetItem(itemName)
			if item then
				local itemButton = Instance.new("TextButton")
				itemButton.Size = UDim2.new(1, -20, 0, 60)
				itemButton.Position = UDim2.new(0, 10, 0, yPosition)
				itemButton.BorderSizePixel = 2
				itemButton.BorderColor3 = Color3.fromRGB(80, 80, 80)
				itemButton.TextScaled = true
				itemButton.Font = Enum.Font.SourceSans
				itemButton.Name = itemName
				itemButton.Parent = inventoryItemsFrame

				-- Check cooldown status
				local cooldownGroup = item.cooldownGroup or itemName
				local cooldownInfo = itemCooldowns[cooldownGroup]
				local isOnCooldown = cooldownInfo and cooldownInfo.active

				-- Set button appearance based on cooldown
				if isOnCooldown then
					itemButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Darker when on cooldown
					itemButton.TextColor3 = Color3.fromRGB(150, 150, 150) -- Grayed out text
					local remainingTime = math.ceil(cooldownInfo.remaining)
					itemButton.Text = item.displayName .. " x" .. quantity .. " (CD: " .. remainingTime .. "s)\n" .. item.description
					itemButton.Active = false -- Disable clicking
				else
					itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
					itemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
					local cooldownText = ""
					if item.cooldown then
						cooldownText = " (CD: " .. item.cooldown .. "s)"
					end
					itemButton.Text = item.displayName .. " x" .. quantity .. cooldownText .. "\n" .. item.description
					itemButton.Active = true -- Enable clicking
				end

				-- Handle item usage (only if not on cooldown)
				itemButton.MouseButton1Click:Connect(function()
					if itemButton.Active then
						inventoryEvents.useItem:FireServer(itemName)
					end
				end)

				-- Hover effects (only if not on cooldown)
				itemButton.MouseEnter:Connect(function()
					if itemButton.Active then
						itemButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
					end
				end)

				itemButton.MouseLeave:Connect(function()
					if itemButton.Active then
						itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
					end
				end)

				yPosition = yPosition + 70
			end
		end
	end

	-- Resize the inventory items frame based on content
	inventoryItemsFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition)
end

-- Function to open shop
local function openShop(shopkeeperName)
	if isShopOpen or not shopGui or not shopTitle then return end

	local shopkeeper = ShopConfig:GetShopkeeper(shopkeeperName)
	if not shopkeeper then return end

	currentShopkeeper = shopkeeperName
	isShopOpen = true

	-- Set shop title
	shopTitle.Text = shopkeeper.displayName

	-- Create item buttons
	createItemButtons(shopkeeperName)

	-- Update gold display
	updateGoldDisplay()

	-- Show shop GUI
	shopGui.Enabled = true

	humanoid.WalkSpeed = 0

	-- Enable mouse cursor
	userInputService.MouseIconEnabled = true
end

-- Function to close shop
function closeShop() -- Made global so it can be accessed by connection
	if not isShopOpen then return end

	local shopkeeperName = currentShopkeeper
	isShopOpen = false
	currentShopkeeper = nil
	if shopGui then
		shopGui.Enabled = false
		humanoid.WalkSpeed = getCurrentWalkSpeed()
		humanoid.JumpPower = 50
	end

	-- Keep cursor always enabled
	userInputService.MouseIconEnabled = true

	-- Show farewell message
	if shopkeeperName then
		local shopkeeper = ShopConfig:GetShopkeeper(shopkeeperName)
		if shopkeeper and shopkeeper.dialogue.farewell then
			for _, line in ipairs(shopkeeper.dialogue.farewell) do
				writeText(line, 1.5)
			end
			endDialogue()
		end
	end
end

local function requestCooldownInfo()
	for itemName, _ in pairs(playerInventory) do
		local item = ShopConfig:GetItem(itemName)
		if item and item.cooldownGroup then
			inventoryEvents.getCooldown:FireServer(item.cooldownGroup)
		end
	end
end

-- Function to open inventory
function openInventory() -- Made global so it can be accessed by connection
	if isInventoryOpen or not inventoryGui then return end

	isInventoryOpen = true
	inventoryGui.Enabled = true
	userInputService.MouseIconEnabled = true

	-- Request inventory data from server
	inventoryEvents.getInventory:FireServer()
	-- Request cooldown info
	requestCooldownInfo()
end

-- Function to close inventory
function closeInventory() -- Made global so it can be accessed by connection
	if not isInventoryOpen then return end

	isInventoryOpen = false
	if inventoryGui then
		inventoryGui.Enabled = false
	end

	-- Keep cursor always enabled
	userInputService.MouseIconEnabled = true
end

-- Function to toggle inventory
function toggleInventory() -- Made global so it can be accessed by connection
	if isInventoryOpen then
		closeInventory()
	else
		openInventory()
	end
end

-- Shop dialogue handler
local function handleShopDialogue(shopkeeperName, proximityPrompt)
	proximityPrompt.Enabled = false

	local shopkeeper = ShopConfig:GetShopkeeper(shopkeeperName)
	if not shopkeeper then 
		proximityPrompt.Enabled = true
		return 
	end

	-- Show greeting dialogue
	for _, line in ipairs(shopkeeper.dialogue.greeting) do
		writeText(line, 2)
	end

	endDialogue()

	-- Open shop after dialogue
	task.wait(0.5)
	openShop(shopkeeperName)

	proximityPrompt.Enabled = true
end

-- Keyboard shortcuts
local inputConnection
local function setupInputConnection()
	if inputConnection then
		inputConnection:Disconnect()
	end

	inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Z then
			toggleInventory()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if isShopOpen then
				closeShop()
			elseif isInventoryOpen then
				closeInventory()
			end
		end
	end)
end

-- Wait for dialogue folder and setup shop NPCs
local function waitForDialogueFolder()
	local maxAttempts = 10
	local attempt = 0

	while attempt < maxAttempts do
		local dialogueFolder = game.Workspace:FindFirstChild("dialogueFolder")
		if dialogueFolder then
			task.wait(0.5)
			return dialogueFolder
		end
		attempt = attempt + 1
		task.wait(1)
	end

	warn("dialogueFolder not found after " .. maxAttempts .. " attempts")
	return nil
end

-- Setup shop dialogues
local function setupShopDialogues()
	local dialogueFolder = waitForDialogueFolder()
	if not dialogueFolder then
		warn("No dialogue folder found - shop dialogue system disabled")
		return
	end

	-- Connect shop NPCs
	for shopkeeperName, shopkeeper in pairs(ShopConfig.shopkeepers) do
		local npcDialogue = dialogueFolder:FindFirstChild(shopkeeper.npcName)
		if npcDialogue then
			local proximityPrompt = npcDialogue:FindFirstChild("ProximityPrompt")
			if proximityPrompt then
				proximityPrompt.Triggered:Connect(function(player)
					handleShopDialogue(shopkeeperName, proximityPrompt)
				end)
				--print("✅ Connected shop dialogue for " .. shopkeeper.npcName .. " → " .. shopkeeperName)
			else
				warn("❌ ProximityPrompt not found for shop NPC: " .. shopkeeper.npcName)
			end
		else
			warn("❌ Shop NPC dialogue not found: " .. shopkeeper.npcName)
		end
	end

	--print("🛍️ Shop dialogue system initialized!")
end

-- Function to initialize everything
local function initializeSystem()
	-- Setup GUI references
	setupGUIReferences()

	-- Setup character references
	if plr.Character then
		setupCharacterReferences(plr.Character)
	end

	-- Connect GUI events
	connectGUIEvents()

	-- Setup input connection
	setupInputConnection()

	-- Setup shop dialogues
	setupShopDialogues()
end

-- Handle character spawning/respawning
local function onCharacterAdded(newCharacter)
	setupCharacterReferences(newCharacter)

	-- Reset GUI states
	isShopOpen = false
	isInventoryOpen = false
	currentShopkeeper = nil

	-- Make sure GUIs are closed
	if shopGui then shopGui.Enabled = false end
	if inventoryGui then inventoryGui.Enabled = false end
	if gui then gui.Enabled = false end
	if textBox then textBox.Visible = false end
end

-- Connect character spawning
plr.CharacterAdded:Connect(onCharacterAdded)

-- FIXED: Handle purchase responses from server
shopEvents.purchaseResponse.OnClientEvent:Connect(function(success, message, newGoldAmount)
	-- Use the new temporary notification function
	showTemporaryNotification(message, 2)

	if success then
		-- Update gold display
		updateGoldDisplay()
		-- Update inventory if it's open
		if isInventoryOpen then
			inventoryEvents.getInventory:FireServer()
		end
	end
end)

-- FIXED: Handle item use responses from server
inventoryEvents.useItemResponse.OnClientEvent:Connect(function(success, message)
	-- Use the new temporary notification function
	showTemporaryNotification(message, 2)

	if success then
		-- Refresh inventory display and cooldown info
		inventoryEvents.getInventory:FireServer()
		requestCooldownInfo()
	end
end)

-- Handle inventory data from server
inventoryEvents.inventoryData.OnClientEvent:Connect(function(inventory)
	playerInventory = inventory
	if isInventoryOpen then
		requestCooldownInfo()
		createInventoryButtons()
	end
end)

-- Handle cooldown data from server
inventoryEvents.cooldownData.OnClientEvent:Connect(function(cooldownGroup, isOnCooldown, remainingTime)
	if isOnCooldown then
		itemCooldowns[cooldownGroup] = {
			active = true,
			remaining = remainingTime
		}
	else
		itemCooldowns[cooldownGroup] = nil
	end

	if isInventoryOpen then
		createInventoryButtons()
	end
end)

-- Handle inventory updates from server
inventoryEvents.inventoryUpdate.OnClientEvent:Connect(function()
	-- Request updated inventory data
	inventoryEvents.getInventory:FireServer()
end)

-- Handle gold notifications
shopEvents.goldNotification.OnClientEvent:Connect(function(amount, reason)
	-- Show gold notification using the temporary notification system
	showTemporaryNotification("+" .. amount .. " Gold (" .. reason .. ")", 1.5)
end)

-- Initialize the system
initializeSystem()