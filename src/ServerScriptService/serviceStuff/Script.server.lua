-- Server Script to create the missing arabKingRegion part
-- Place this in ServerScriptService and run once

local function createArabKingRegion()
	-- Navigate to the target location
	local areas = workspace:WaitForChild("areas")
	local area1 = areas:WaitForChild("area1")
	local desert = area1:WaitForChild("desert")

	-- Check if arabKingRegion already exists
	local existingRegion = desert:FindFirstChild("arabKingRegion")
	if existingRegion then
		print("✅ arabKingRegion already exists!")
		return
	end

	-- Create the region part
	local arabKingRegion = Instance.new("Part")
	arabKingRegion.Name = "arabKingRegion"
	arabKingRegion.Size = Vector3.new(270, 59, 158.239)
	arabKingRegion.Position = Vector3.new(4265.707, -48.325, 760.619)
	arabKingRegion.CanCollide = false
	arabKingRegion.Transparency = 1 -- Make it invisible
	arabKingRegion.Material = Enum.Material.ForceField -- Optional: makes it easier to see in Studio if needed
	arabKingRegion.Anchored = true
	arabKingRegion.Parent = desert

	--print("🏜️ Created arabKingRegion part successfully!")
	--print("   Size:", arabKingRegion.Size)
	--print("   Position:", arabKingRegion.Position)
	--print("   Parent:", arabKingRegion.Parent:GetFullName())
end

-- Run the function
local success, error = pcall(createArabKingRegion)

if not success then
	warn("❌ Failed to create arabKingRegion:", error)
else
	--print("✨ arabKingRegion creation script completed!")
end