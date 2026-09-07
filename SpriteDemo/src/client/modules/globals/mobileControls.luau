-- 모바일에서 로블록스 기본 3D 캐릭터/TouchGui에 의존하지 않는 자체 방향 버튼.
-- CrossPlatformService:Fire("InputBegin"/"InputEnd", {Action=...})는 공식 문서화된
-- 공개 API(Services/CrossPlatformService.luau 186~195줄)라 이 버튼에서 직접 호출하면
-- 키보드 WASD와 완전히 동일한 4방향 이동 판정을 그대로 재사용할 수 있다.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local BUTTON_SIZE = 64
local LAYOUT = {
	Up = UDim2.fromOffset(BUTTON_SIZE, 0),
	Left = UDim2.fromOffset(0, BUTTON_SIZE),
	Right = UDim2.fromOffset(BUTTON_SIZE * 2, BUTTON_SIZE),
	Down = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE * 2),
}
local LABEL = {
	Up = "▲",
	Left = "◀",
	Right = "▶",
	Down = "▼",
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function createButton(parent: Instance, action: string)
	local button = Instance.new("TextButton")
	button.Name = action
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.Position = LAYOUT[action]
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.6
	button.BorderSizePixel = 0
	button.Text = LABEL[action]
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = false
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	button.InputBegan:Connect(function(input)
		if not isPointer(input) then
			return
		end
		button.BackgroundTransparency = 0.2
		CrossPlatformService:Fire("InputBegin", { Action = action, Position = Vector2.zero, KeyCode = { Name = action } })
	end)

	button.InputEnded:Connect(function(input)
		if not isPointer(input) then
			return
		end
		button.BackgroundTransparency = 0.6
		CrossPlatformService:Fire("InputEnd", { Action = action, Position = Vector2.zero, KeyCode = { Name = action } })
	end)

	return button
end

local exports = {}

function exports.load(scene: Scene)
	if not UserInputService.TouchEnabled then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileControls"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	local pad = Instance.new("Frame")
	pad.Name = "DPad"
	pad.AnchorPoint = Vector2.new(0, 1)
	pad.Position = UDim2.new(0, 24, 1, -24)
	pad.Size = UDim2.fromOffset(BUTTON_SIZE * 3, BUTTON_SIZE * 3)
	pad.BackgroundTransparency = 1
	pad.Parent = screenGui

	for action in LAYOUT do
		createButton(pad, action)
	end

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
end

return exports
