-- 모바일에서 로블록스 기본 3D 캐릭터/TouchGui에 의존하지 않는 자체 방향 버튼 + 상호작용
-- 버튼. CrossPlatformService:Fire("InputBegin"/"InputEnd", {Action=...})는 공식 문서화된
-- 공개 API(Services/CrossPlatformService.luau 186~195줄)라 이 버튼에서 직접 호출하면
-- 키보드 WASD와 완전히 동일한 4방향 이동 판정을 그대로 재사용할 수 있다.
--
-- 상호작용(포탈 타기 등)은 원래 "위" 키(W/스페이스 둘 다 Action="Up")를 쓰려고 했는데,
-- Up이 이미 점프에 쓰이고 있어서 겹쳐 안 먹혔다 — 그래서 전용 액션 "Interact"를 새로
-- 만든다. 키보드는 스페이스바를 Up에서 떼어내 Interact로 재배정하고(W는 그대로 점프),
-- 모바일은 방향 패드와 별개로 전용 버튼을 하나 더 둔다.
--
-- (메이플식 방향키+Alt+Ctrl 배치를 시도했다가 이동 자체가 안 되는 문제가 있어서 이
-- 원래 배치로 롤백했다 — WASD/화살표 이동 + 스페이스바 상호작용 + 모바일 방향 패드
-- + 별도 상호작용 버튼.)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

-- 모듈이 require될 때 한 번만 실행되면 되고(플랫폼과 무관하게 항상 적용돼야 함), PC에서도
-- 필요하므로 TouchEnabled 가드가 있는 exports.load 밖(module 최상단)에 둔다.
CrossPlatformService:SetDeviceKey("Keyboard", "Space", "Interact")
-- 기본공격: F키. WASD에 왼손을 얹은 상태에서 손 이동 없이(검지가 D 바로 위) 누를 수
-- 있는 자리라 선택했다 — 처음엔 X를 검토했으나 WASD grip에서 손을 아예 옮겨야 해서
-- 기각. heroController.luau가 이 "Attack" 액션을 받아 공격 애니메이션을 재생한다.
CrossPlatformService:SetDeviceKey("Keyboard", "F", "Attack")

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

local function createButton(parent: Instance, action: string, position: UDim2, label: string, anchorPoint: Vector2?)
	local button = Instance.new("TextButton")
	button.Name = action
	button.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.Position = position
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.6
	button.BorderSizePixel = 0
	button.Text = label
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

	for action, position in LAYOUT do
		createButton(pad, action, position, LABEL[action])
	end

	-- (실측 버그 이력) 상호작용 버튼을 화면 하단 "중앙"에 뒀더니 시야 한복판이라 잘
	-- 안 보인다는 요청 — 기본공격 버튼과 같은 화면 오른쪽 하단으로 옮기고, 두 버튼이
	-- 겹치지 않게 위아래로 쌓는다(상호작용이 위, 공격이 아래).
	local INTERACT_GAP = 16

	-- 기본공격 버튼 — 화면 오른쪽 하단 모서리.
	createButton(
		screenGui,
		"Attack",
		UDim2.new(1, -24, 1, -24),
		"⚔",
		Vector2.new(1, 1)
	)

	-- 상호작용 버튼(포탈 타기 등) — 공격 버튼 바로 위.
	createButton(
		screenGui,
		"Interact",
		UDim2.new(1, -24, 1, -24 - BUTTON_SIZE - INTERACT_GAP),
		"✋",
		Vector2.new(1, 1)
	)

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
