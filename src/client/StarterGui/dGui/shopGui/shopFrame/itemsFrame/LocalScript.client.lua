local itemList = script.Parent
--itemList.Size = UDim2.new(1, -40, 1, -160)
--itemList.Position = UDim2.new(0, 20, 0, 80)
itemList.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
itemList.BorderSizePixel = 1
itemList.ScrollBarThickness = 8
itemList.CanvasSize = UDim2.new(0, 0, 0, 0)

-- Add padding and vertical spacing
local layout = Instance.new("UIListLayout", itemList)
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

local padding = Instance.new("UIPadding", itemList)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
