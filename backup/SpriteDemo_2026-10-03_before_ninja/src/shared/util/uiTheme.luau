-- Punch-RPG(사용자의 이전 프로젝트, https://github.com/dolupa323/Punch-RPG)의
-- UIUtils.lua/UITheme.lua 패턴을 참고한 이미지 없는(procedural) UI 빌더. 모든
-- "꾸며진" 요소는 그냥 색칠된 Frame + UICorner(+선택적 UIStroke/UIGradient)로 만든다.
--
-- 색상 팔레트는 동양풍(옻칠/자개/금박) 컨셉 — 어두운 적갈색 옻칠 배경 + 금동색
-- 테두리, 모서리는 둥글리지 않고 각지게(라운드 반경을 작게) 해서 한지/자개함 같은
-- 느낌을 낸다. 체력=주칠(붉은 옻칠), 마나=비취색, 경험치=금박색.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local uiTheme = {}

-- 반응형 기준: 세로 800px에서 1배. (예전엔 기준이 1080이라 일반 PC 창(세로 700~900)에서 UI가
-- 0.65~0.85배로 너무 작게 나왔다.) 큰 모니터에서 지나치게 커지지 않게 상한을 둔다.
local REFERENCE_HEIGHT = 800
local MIN_SCALE = 0.55
local MAX_SCALE = 1.6

-- 게임 UI 글씨체 — Caesar Dressing(숫자/영문용, 한글 미지원 확인됨). 지금 UI에 실제로
-- 표시되는 텍스트는 전부 숫자(HP/MP/EXP 수치, 레벨)라 한글이 필요 없어서, 한글은 그냥
-- 로블록스 기본 대체 폰트로 두고 이 폰트로 통일한다. 나중에 실제 한글 문구를 표시할
-- 일이 생기면 그 라벨만 따로 한글 지원 폰트(나눔고딕 등)를 써야 한다.
uiTheme.Font = Font.fromId(12187368843)

-- 모바일/PC 등 해상도가 달라져도 HUD 구성 비율이 동일하게 보이도록, 기준 해상도(세로
-- 1080px) 대비 현재 뷰포트 비율만큼 UIScale을 적용한다. root(GuiObject) 밑에 있는 모든
-- 자식이 이 비율로 같이 커지고 작아진다. 극단적인 화면(초소형/초대형)에서 너무 작아지거나
-- 커지지 않도록 0.6~1.4배로 clamp.
function uiTheme.applyResponsiveScale(root: Instance, designSize: Vector2?)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local function update()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, REFERENCE_HEIGHT)
		if viewport.Y <= 0 or viewport.X <= 0 then
			viewport = Vector2.new(1920, REFERENCE_HEIGHT)
		end

		local scale = math.clamp(viewport.Y / REFERENCE_HEIGHT, MIN_SCALE, MAX_SCALE)
		-- designSize(이 UI가 1배일 때 차지하는 픽셀 크기)를 주면, 어떤 화면 비율에서도 화면 밖으로
		-- 넘치지 않게 가로/세로 여유(각 96%/92%)에 맞춰 추가로 줄인다 — 최소 배율보다 더 작아지더라도
		-- "화면에 다 보이는 것"이 우선이다.
		if designSize then
			scale = math.min(scale, viewport.X * 0.96 / designSize.X, viewport.Y * 0.92 / designSize.Y)
		end
		uiScale.Scale = scale
	end

	update()

	local viewportConnection: RBXScriptConnection? = nil
	local function hookCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end

	hookCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

	return uiScale
end

-- 버튼 눌림/호버 피드백 — 누르는 동안 어두워졌다가 떼면 원래대로, 마우스를 올리면 살짝
-- 밝아진다(누르지 않는 상태와 눌린 상태가 한눈에 구분되도록). target이 이미지 계열
-- (ImageButton/ImageLabel)이면 ImageColor3를, 아니면 BackgroundColor3를 바꾼다. 원래 색은
-- 등록 시점 값을 기억해뒀다가 복원한다. 클릭 판정 자체는 건드리지 않는다.
local PRESS_DARKEN = 0.6
local HOVER_BRIGHTEN = 1.0 -- 1이면 원본 그대로(어두워진 상태와 비교해 눌림만 강조).
local FEEDBACK_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function isPointerInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function uiTheme.AddPressFeedback(button: GuiButton, target: GuiObject?)
	local object = target or button
	local property = if object:IsA("ImageButton") or object:IsA("ImageLabel") then "ImageColor3" else "BackgroundColor3"
	local baseColor: Color3 = object[property]
	local pressed = false
	local hovering = false

	local function apply()
		local color = baseColor
		if pressed then
			color = baseColor:Lerp(Color3.new(0, 0, 0), 1 - PRESS_DARKEN)
		elseif hovering then
			color = baseColor:Lerp(Color3.new(1, 1, 1), 0.18)
		end
		TweenService:Create(object, FEEDBACK_TWEEN, { [property] = color }):Play()
	end

	button.InputBegan:Connect(function(input)
		if isPointerInput(input) then
			pressed = true
			apply()
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering = true
			apply()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPointerInput(input) then
			pressed = false
			apply()
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering = false
			apply()
		end
	end)
end

uiTheme.Color = {
	PanelBg = Color3.fromRGB(26, 16, 14), -- 어두운 적갈색 옻칠
	PanelBorder = Color3.fromRGB(196, 155, 80), -- 금동색 테두리
	SlotBg = Color3.fromRGB(38, 24, 20),
	SlotBorder = Color3.fromRGB(140, 105, 55),
	SlotHoverBorder = Color3.fromRGB(230, 190, 100),

	HP = Color3.fromRGB(176, 34, 30), -- 주칠(붉은 옻칠)
	HPBg = Color3.fromRGB(42, 14, 12),
	MP = Color3.fromRGB(40, 110, 200), -- 파란색
	MPBg = Color3.fromRGB(12, 22, 42),
	XP = Color3.fromRGB(212, 175, 55), -- 금박색
	XPBg = Color3.fromRGB(32, 24, 10),

	ButtonBg = Color3.fromRGB(58, 30, 24),
	ButtonHoverBg = Color3.fromRGB(92, 48, 34),
	ButtonBorder = Color3.fromRGB(196, 155, 80),
	Text = Color3.fromRGB(240, 224, 196), -- 한지색 아이보리
}

uiTheme.Transp = {
	PANEL = 0.05,
	SLOT = 0.1,
	BAR_BG = 0.05,
}

function uiTheme.AddCorner(instance: Instance, radius: number | "full")
	local corner = Instance.new("UICorner")
	-- 동양풍은 서양식 둥근 버튼보다 각진 형태가 어울려서 기본 반경을 작게 잡는다
	-- (버튼/닫기 버튼처럼 명시적으로 "full"을 요청한 경우만 원형으로).
	corner.CornerRadius = if radius == "full" then UDim.new(1, 0) else UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

function uiTheme.AddStroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or uiTheme.Color.PanelBorder
	-- 금박 테두리가 잘 보이도록 기본 두께를 좀 더 두껍게(1.2 -> 1.6).
	stroke.Thickness = thickness or 1.6
	stroke.Transparency = transparency or 0.1
	stroke.Parent = instance
	return stroke
end

-- 배경 Frame + UICorner(+선택적 UIStroke)만 있는 기본 패널/프레임.
function uiTheme.mkFrame(props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Frame"
	frame.BackgroundColor3 = props.BackgroundColor3 or uiTheme.Color.PanelBg
	frame.BackgroundTransparency = props.BackgroundTransparency or 0
	frame.BorderSizePixel = 0
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.Position = props.Position or UDim2.fromOffset(0, 0)
	frame.Size = props.Size or UDim2.fromOffset(100, 100)
	frame.ZIndex = props.ZIndex or 1
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.Parent = props.Parent

	uiTheme.AddCorner(frame, props.Radius or 4)
	if props.Stroke ~= false then
		uiTheme.AddStroke(frame, props.StrokeColor, props.StrokeThickness, props.StrokeTransparency)
	end

	return frame
end

-- 배경 트랙 + 채움 Frame + 값 라벨로 이뤄진 스탯 바(체력/마나/경험치 공용).
function uiTheme.mkBar(props)
	local width = props.Width or 240
	local height = props.Height or 20

	local track = uiTheme.mkFrame({
		Name = (props.Name or "Bar") .. "Track",
		Parent = props.Parent,
		Size = UDim2.fromOffset(width, height),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = props.BgColor or uiTheme.Color.PanelBg,
		BackgroundTransparency = uiTheme.Transp.BAR_BG,
		Radius = props.Radius or 3,
		StrokeColor = props.StrokeColor or uiTheme.Color.PanelBorder,
	})
	track.LayoutOrder = props.LayoutOrder or 0

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = props.FillColor or uiTheme.Color.HP
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 2
	fill.Parent = track
	uiTheme.AddCorner(fill, props.Radius or 3)

	-- 은은한 금박 광택 느낌 — 위쪽은 살짝 밝게, 아래쪽은 원색 그대로.
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.4, Color3.new(0.92, 0.92, 0.92)),
		ColorSequenceKeypoint.new(1, Color3.new(0.72, 0.72, 0.72)),
	})
	gradient.Rotation = 90
	gradient.Parent = fill

	-- 금동색 안쪽 테두리선(트랙 자체 테두리와 별개로 채움 위에 한 겹 더) — 자개함 느낌.
	uiTheme.AddStroke(fill, uiTheme.Color.PanelBorder, 1, 0.6)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = uiTheme.Font
	label.TextScaled = true
	label.TextColor3 = uiTheme.Color.Text
	label.TextStrokeTransparency = 0.3
	label.Text = props.LabelText or ""
	label.ZIndex = 3
	label.Parent = track

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = label

	return { track = track, fill = fill, label = label }
end

-- 호버/눌림 트윈이 붙은 버튼(TextButton). 이미지 대신 색+테두리로만 표현.
function uiTheme.mkBtn(props)
	local btn = Instance.new("TextButton")
	btn.Name = props.Name or "Button"
	btn.BackgroundColor3 = props.BackgroundColor3 or uiTheme.Color.ButtonBg
	btn.BorderSizePixel = 0
	btn.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	btn.Position = props.Position or UDim2.fromOffset(0, 0)
	btn.Size = props.Size or UDim2.fromOffset(32, 32)
	btn.FontFace = uiTheme.Font
	btn.TextScaled = true
	btn.TextColor3 = uiTheme.Color.Text
	btn.Text = props.Text or ""
	btn.AutoButtonColor = false
	btn.ZIndex = props.ZIndex or 1
	btn.Parent = props.Parent

	uiTheme.AddCorner(btn, props.Radius or (props.Round and "full") or 4)
	uiTheme.AddStroke(btn, props.StrokeColor or uiTheme.Color.ButtonBorder, 1.2, 0.2)

	local scale = Instance.new("UIScale")
	scale.Parent = btn

	local baseColor = btn.BackgroundColor3
	local hoverColor = props.HoverColor or uiTheme.Color.ButtonHoverBg

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Back), { Scale = 0.85 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)

	return btn
end

-- 인벤토리 등에 쓰는 정사각형 슬롯(아이콘 + 개수 라벨 + 클릭용 투명 버튼).
function uiTheme.mkSlot(props)
	local slot = uiTheme.mkFrame({
		Name = props.Name or "Slot",
		Parent = props.Parent,
		Size = props.Size or UDim2.fromOffset(56, 56),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = props.BackgroundColor3 or uiTheme.Color.SlotBg,
		BackgroundTransparency = props.BackgroundTransparency or uiTheme.Transp.SLOT,
		Radius = props.Radius or 3,
		StrokeColor = props.StrokeColor or uiTheme.Color.SlotBorder,
	})

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.78, 0.78)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Image = ""
	icon.ZIndex = 2
	icon.Parent = slot

	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.fromScale(1, 1)
	count.Size = UDim2.fromOffset(20, 14)
	count.FontFace = uiTheme.Font
	count.TextScaled = true
	count.TextColor3 = uiTheme.Color.Text
	count.TextStrokeTransparency = 0.3
	count.Text = ""
	count.ZIndex = 3
	count.Parent = slot

	local button = Instance.new("TextButton")
	button.Name = "Click"
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 4
	button.Parent = slot

	local stroke = slot:FindFirstChildOfClass("UIStroke")
	local hoverColor = props.HoverStrokeColor or uiTheme.Color.SlotHoverBorder
	local normalColor = props.StrokeColor or uiTheme.Color.SlotBorder
	button.MouseEnter:Connect(function()
		if stroke then
			stroke.Color = hoverColor
		end
	end)
	button.MouseLeave:Connect(function()
		if stroke then
			stroke.Color = normalColor
		end
	end)

	uiTheme.AddPressFeedback(button, slot)

	return { frame = slot, icon = icon, count = count, button = button }
end

-- 아이콘 이미지가 없는 아이템/장비를 칸에 표시할 때 쓰는 이름 앞 두 글자(한글 UTF-8 안전).
function uiTheme.ShortName(name: string): string
	return name:sub(1, (utf8.offset(name, 3) or #name + 1) - 1)
end

return uiTheme
