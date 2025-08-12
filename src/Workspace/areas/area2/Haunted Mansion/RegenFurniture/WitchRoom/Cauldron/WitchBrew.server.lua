r = game:service("RunService")

--print("Witch's Brew loaded")

brew = script.Parent.Brew

function doTheBrew(humanoid, player)
	player.Head.Size = Vector3.new(2,2,2)
	player.Head.BrickColor = BrickColor.random()
end


function onTouch(touchedPart)
	print("touched")
	-- see if a character touched it
	local parent = touchedPart.Parent
		if parent~=nil then
		local humanoid = parent:findFirstChild("Humanoid", false);
		if humanoid ~= nil then
			doTheBrew(humanoid, parent)
			return
		end
	end
end

print(brew)

--brew.Touched:connect(onTouch)

