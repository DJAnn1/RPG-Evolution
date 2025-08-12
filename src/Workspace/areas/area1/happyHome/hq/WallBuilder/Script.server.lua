wallWidth = 12
wallHeight = 4
wallLifetime = 15
brickSpeed = 0.04

-- places a brick at pos and returns the position of the brick's opposite corner
function placeBrick(cf, pos, color)
	local brick = Instance.new("Part")
	brick.BrickColor = color
	brick.CFrame = cf * CFrame.new(pos + brick.size / 2)
	brick.Parent = script.Parent.Bricks
	brick:makeJoints()
	return  brick, pos +  brick.size
end

function buildWall(cf)

	local color = BrickColor.random()
	local bricks = {}

	assert(wallWidth>0)
	local y = 0
	while y < wallHeight do
		local p
		local x = -wallWidth/2
		while x < wallWidth/2 do
			local brick
			brick, p = placeBrick(cf, Vector3.new(x, y, 0), color)
			x = p.x
			table.insert(bricks, brick)
			wait(brickSpeed)
		end
		y = p.y
	end

	wait(wallLifetime)

	-- now delete them!
	while #bricks>0 do
		table.remove(bricks):remove()
		wait(brickSpeed/2)
	end

end

script.Parent.ChildAdded:connect(function(item)
	if item.Name=="NewWall" then
		item:remove()
		buildWall(item.Value)
	end
end)
