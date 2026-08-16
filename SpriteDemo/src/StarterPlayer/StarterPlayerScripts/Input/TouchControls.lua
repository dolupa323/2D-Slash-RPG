-- On-screen virtual buttons for touch devices — only instantiated when
-- UserInputService.TouchEnabled. Feeds InputController through the exact
-- same entry points keyboard/gamepad use (SetTouchMoveAxis/Trigger*), so
-- gameplay code never knows or cares which input source is active.
--
-- MouseButton1Down/Up fire for touch taps too (Roblox synthesizes them), so
-- one set of button connections covers touch and a mouse-based emulator
-- test alike — no separate Touch* event wiring needed.

local UserInputService = game:GetService("UserInputService")

local TouchControls = {}

local function makeButton(parent, size, position, anchor, text)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.AnchorPoint = anchor
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundTransparency = 0.55
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.ZIndex = 50
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	return button
end

function TouchControls.setup(screenGui, inputController)
	if not UserInputService.TouchEnabled then
		return nil
	end

	local container = Instance.new("Frame")
	container.Name = "TouchControls"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 50
	container.Parent = screenGui

	-- movement: left/right, bottom-left
	local leftButton = makeButton(container, UDim2.new(0, 70, 0, 70), UDim2.new(0, 20, 1, -20), Vector2.new(0, 1), "<")
	local rightButton = makeButton(container, UDim2.new(0, 70, 0, 70), UDim2.new(0, 100, 1, -20), Vector2.new(0, 1), ">")

	local leftDown, rightDown = false, false
	local function refreshAxis()
		local axis = 0
		if leftDown then axis -= 1 end
		if rightDown then axis += 1 end
		inputController:SetTouchMoveAxis(axis)
	end

	leftButton.MouseButton1Down:Connect(function() leftDown = true; refreshAxis() end)
	leftButton.MouseButton1Up:Connect(function() leftDown = false; refreshAxis() end)
	leftButton.MouseLeave:Connect(function() leftDown = false; refreshAxis() end)
	rightButton.MouseButton1Down:Connect(function() rightDown = true; refreshAxis() end)
	rightButton.MouseButton1Up:Connect(function() rightDown = false; refreshAxis() end)
	rightButton.MouseLeave:Connect(function() rightDown = false; refreshAxis() end)

	-- actions: jump/attack/wave, bottom-right
	local jumpButton = makeButton(container, UDim2.new(0, 70, 0, 70), UDim2.new(1, -20, 1, -20), Vector2.new(1, 1), "JUMP")
	local attackButton = makeButton(container, UDim2.new(0, 70, 0, 70), UDim2.new(1, -100, 1, -20), Vector2.new(1, 1), "ATK")
	local waveButton = makeButton(container, UDim2.new(0, 56, 0, 56), UDim2.new(1, -100, 1, -110), Vector2.new(1, 1), "WAVE")

	jumpButton.MouseButton1Down:Connect(function() inputController:TriggerJump() end)
	attackButton.MouseButton1Down:Connect(function() inputController:TriggerAttack() end)
	waveButton.MouseButton1Down:Connect(function() inputController:TriggerWave() end)

	return container
end

return TouchControls
