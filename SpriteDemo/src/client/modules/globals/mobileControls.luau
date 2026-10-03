-- 모바일에서 로블록스 기본 3D 캐릭터/TouchGui에 의존하지 않는 자체 방향 패드.
-- CrossPlatformService:Fire("InputBegin"/"InputEnd", {Action=...})는 공식 문서화된
-- 공개 API(Services/CrossPlatformService.luau 186~195줄)라 이 버튼에서 직접 호출하면
-- 키보드 WASD와 완전히 동일한 4방향 이동 판정을 그대로 재사용할 수 있다.
--
-- (2026-09-29) 도트 UI로 교체: 에셋 공방 UI 부품의 흰 입체 버튼(30x30) 4개를 십자로 놓고, 안에 진보라 도트 화살표를 그린다.
-- 화면 배율은 다른 도트 UI와 같은 정수배(pixelUI.Scale). 누르는 동안 눌린 그림.
-- 손가락이 버튼 밖으로 미끄러져 나가도 손을 뗄 때 확실히 멈추도록, 누른 입력을 기억해 두었다가 전역 InputEnded로 뗀다.
-- 공격·대화 버튼은 HUD(hud.luau)에 있다(PC·모바일 공용).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local UI = require(script.Parent.Parent.ui.pixelUI)

-- 모듈이 require될 때 한 번만 실행되면 되고(플랫폼과 무관하게 항상 적용돼야 함), PC에서도
-- 필요하므로 TouchEnabled 가드가 있는 exports.load 밖(module 최상단)에 둔다.
CrossPlatformService:SetDeviceKey("Keyboard", "Space", "Interact")
-- (2026-09-29) NPC 대화용으로 E키도 상호작용. 모바일은 HUD의 "대화" 버튼(hud.luau).
CrossPlatformService:SetDeviceKey("Keyboard", "E", "Interact")
-- 기본공격: F키. WASD에 왼손을 얹은 상태에서 손 이동 없이(검지가 D 바로 위) 누를 수
-- 있는 자리라 선택했다 — 처음엔 X를 검토했으나 WASD grip에서 손을 아예 옮겨야 해서 기각.
CrossPlatformService:SetDeviceKey("Keyboard", "F", "Attack")

local BTN = 30 -- 버튼 크기(도트)
local STEP = 31
local MARGIN = 6
local PAD = STEP * 2 + BTN -- 십자 전체 크기
local LAYOUT = {
	Up = Vector2.new(STEP, 0),
	Left = Vector2.new(0, STEP),
	Right = Vector2.new(STEP * 2, STEP),
	Down = Vector2.new(STEP, STEP * 2),
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function fire(kind: string, action: string)
	CrossPlatformService:Fire(kind, { Action = action, Position = Vector2.zero, KeyCode = { Name = action } })
end

-- 버튼 가운데 도트 화살표(진보라, 가로 9 x 세로 5 삼각형 — 방향에 맞게 돌림)
local function arrow(parent: Instance, dir: string)
	local ink = UI.colors.ink
	for i = 0, 4 do
		local len = 9 - i * 2
		local px = Instance.new("Frame")
		px.BackgroundColor3 = ink
		px.BorderSizePixel = 0
		px.ZIndex = 6
		if dir == "Up" or dir == "Down" then
			-- 넓은 줄(i=0)이 꼬리, 좁은 줄이 뾰족한 끝
			local y = if dir == "Up" then 15 - i else 11 + i
			px.Position = UDim2.fromOffset(10 + i, y)
			px.Size = UDim2.fromOffset(len, 1)
		else
			local x = if dir == "Left" then 16 - i else 12 + i
			px.Position = UDim2.fromOffset(x, 9 + i)
			px.Size = UDim2.fromOffset(1, len)
		end
		px.Parent = parent
	end
end

local exports = {}

function exports.load(scene: Scene)
	if not UserInputService.TouchEnabled or exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileControls"
	screenGui.ResetOnSpawn = false

	-- 왼쪽 아래 모서리 고정 + 정수 배율
	local pad = Instance.new("Frame")
	pad.Name = "DPad"
	pad.BackgroundTransparency = 1
	pad.AnchorPoint = Vector2.new(0, 1)
	pad.Position = UDim2.new(0, 0, 1, 0)
	pad.Size = UDim2.fromOffset(PAD + MARGIN * 2, PAD + MARGIN * 2)
	pad.Parent = screenGui
	UI.Scale(pad)

	local held = {} -- InputObject -> action
	for action, pos in LAYOUT do
		local button = UI.Button(pad, MARGIN + pos.X, MARGIN + pos.Y, BTN, BTN, { Color = "plain" })
		arrow(button.Instance, action)
		button.Instance.InputBegan:Connect(function(input)
			if isPointer(input) and not held[input] then
				held[input] = action
				fire("InputBegin", action)
			end
		end)
	end
	exports.endConnection = UserInputService.InputEnded:Connect(function(input)
		local action = held[input]
		if action then
			held[input] = nil
			fire("InputEnd", action)
		end
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.endConnection then
		exports.endConnection:Disconnect()
		exports.endConnection = nil
	end
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
end

return exports
