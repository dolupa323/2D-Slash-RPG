-- 체력/마나/경험치/레벨 HUD. mobileControls.luau와 동일하게 Scene/GameFrame 밖의 자체
-- ScreenGui(화면 고정, 카메라 패닝에 안 움직임)로 만든다.
--
-- char ui.png/exp.png는 초상화(또는 레벨 원)와 막대 틀이 하나로 그려진 이미지다 —
-- 이미지를 자르거나 일부만 쓰지 않고 원본 그대로 통째로 표시한다.
--
-- 채움(Fill)은 색칠된 도형을 새로 그려서 겹치는 대신, 같은 이미지의 트랙 부분을
-- ImageRectOffset/ImageRectSize로 그대로 한 번 더 잘라와서 색만 입힌(ImageColor3) 뒤,
-- 그 위에 겹쳐서 값만큼만 보이게 클리핑하는 방식을 쓴다 — 이렇게 하면 채워지는 부분이
-- 트랙 원본과 완전히 같은 픽셀(둥근 테두리, 하이라이트/음영까지)이라 이질감 없이
-- 자연스럽게 안착한다. 트랙의 실제 픽셀 좌표는 PIL로 실측(밝기 경계 스캔) 후 가장자리
-- 안티에일리어싱을 감안해 각 방향 +2px 여백을 더했다 — 실측치 그대로 쓰면 배경이
-- 테두리처럼 살짝 비치는 문제가 있었다. 레벨 숫자 원은 x:[5,61] y:[3,55].
--
-- 반응형: 화면 해상도(모바일/PC)가 달라져도 같은 비율로 보이도록 uiTheme.
-- applyResponsiveScale로 루트에 UIScale을 걸어둔다.
--
-- HP/MP/EXP 숫자 표기는 막대 높이와 무관하게 항상 같은 글씨 크기(TextSize 고정)로
-- 통일하고, 색은 검은색으로 표기한다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)

local DISPLAY_WIDTH = 320

-- 2026-09-16: char ui.png가 다시 새 이미지로 교체됨(339x106, 더 단순한 평면 디자인 —
-- 원형 초상 + 위/아래 둥근 막대 두 개, 트랙 안쪽은 밋밋한 크림색 사각형이라 이전
-- 이미지보다 측정이 훨씬 쉬웠음). PIL로 재실측 + 안전 여백(각 방향 +2px, 이유는 위
-- createFillOverlay 설명 참고).
local CHAR_UI_ASSET = "rbxassetid://131285376650204"
local CHAR_UI_NATIVE = Vector2.new(339, 106)
local HP_TRACK = { x = 94, y = 29, w = 233, h = 26 }
local MP_TRACK = { x = 91, y = 71, w = 220, h = 18 }

-- char ui.png 안의 초상화 원 위치 — 원래 직업 가면 사진을 넣으려던 자리인데, 그 대신
-- 여기에 레벨 숫자를 큼직하게 표시한다. PIL로 실측: 원은 중심 (52, 57), 지름 약 72px.
local PORTRAIT_RECT = { x = 16, y = 21, w = 72, h = 72 }

local EXP_ASSET = "rbxassetid://76982575040834"
local EXP_NATIVE = Vector2.new(399, 57)
local EXP_TRACK = { x = 56, y = 21, w = 331, h = 16 }

local TEXT_SIZE = 16
local TEXT_COLOR = Color3.new(0, 0, 0)

local function createOverlayFrame(parent: Instance, layoutOrder: number, image: string, native: Vector2)
	local scale = DISPLAY_WIDTH / native.X
	local displayHeight = native.Y * scale

	local frame = Instance.new("ImageLabel")
	frame.Name = "Frame"
	frame.BackgroundTransparency = 1
	frame.Image = image
	frame.Size = UDim2.fromOffset(DISPLAY_WIDTH, displayHeight)
	frame.LayoutOrder = layoutOrder
	frame.Parent = parent

	return frame, scale
end

-- 값에 따라 채워지는 막대. Fill은 새로 그린 도형이 아니라 "같은 이미지의 트랙 부분을
-- 한 번 더 잘라와 색을 입힌 것"이라 트랙 원본과 픽셀 단위로 동일하다 — mask(클리핑용
-- 컨테이너) 안에 트랙 전체 너비로 깔아두고, mask의 너비만 값에 따라 줄여서 오른쪽이
-- 잘려 보이게 하는 방식으로 "채워지는" 효과를 낸다. 외곽선/별도 도형 없음.
local function createFillOverlay(image: string, parent: Instance, scale: number, track, tintColor: Color3)
	local trackWidth = track.w * scale
	local trackHeight = track.h * scale

	-- 이 프로젝트 ScreenGui는 ZIndexBehavior가 Global이라 부모 ImageLabel(기본 ZIndex 1)
	-- 보다 낮으면 이미지 뒤로 숨는다 — 반드시 부모보다 높은 값을 줘야 한다.
	local mask = Instance.new("Frame")
	mask.Name = "FillMask"
	mask.Position = UDim2.fromOffset(track.x * scale, track.y * scale)
	mask.Size = UDim2.fromOffset(trackWidth, trackHeight)
	mask.BackgroundTransparency = 1
	mask.ClipsDescendants = true
	mask.ZIndex = 2
	mask.Parent = parent
	-- 실측해보니 이미지 안쪽 트랙 자체가 거의 각진 사각형이다(둥근 정도가 2px 수준).
	-- 트랙 높이의 절반(알약) 반경으로 둥글렸더니 네 모서리에서 실제 트랙 영역을 너무
	-- 많이 깎아내서 배경이 초승달 모양으로 드러났다 — 원본 트랙의 미세한 라운드에
	-- 맞춰 아주 작은 반경만 준다.
	uiTheme.AddCorner(mask, 2)

	local fill = Instance.new("ImageLabel")
	fill.Name = "Fill"
	fill.BackgroundTransparency = 1
	fill.Image = image
	fill.ImageRectOffset = Vector2.new(track.x, track.y)
	fill.ImageRectSize = Vector2.new(track.w, track.h)
	fill.ImageColor3 = tintColor
	fill.Size = UDim2.fromOffset(trackWidth, trackHeight)
	fill.ZIndex = 2
	fill.Parent = mask

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(track.x * scale, track.y * scale)
	label.Size = UDim2.fromOffset(trackWidth, trackHeight)
	label.FontFace = uiTheme.Font
	label.TextSize = TEXT_SIZE
	label.TextColor3 = TEXT_COLOR
	label.Text = ""
	label.ZIndex = 3
	label.Parent = parent

	return mask, label, trackWidth
end

-- (Phase 1 전투 타격감, ROADMAP.md — Cheruton HealthBarMob.gd 이중 바 패턴을 플레이어
-- HUD에도 동일 적용) monsterHealthBar.luau와 같은 개념: 뒤쪽(slow)은 맞은 직후에도 잠깐
-- 그대로 있다가 천천히 줄어들고, 앞쪽(fast)은 즉시 반영된다. 여기서는 이미지 트랙을
-- 재활용하는 createFillOverlay를 두 번 겹쳐 부른다 — 먼저 부른 게 아래(slow), 나중에
-- 부른 게 위(fast)에 오도록 ZIndex를 붙인다.
local function createDualFillOverlay(image: string, parent: Instance, scale: number, track, fastColor: Color3, slowColor: Color3)
	local slowMask, slowLabel = createFillOverlay(image, parent, scale, track, slowColor)
	slowLabel:Destroy() -- 라벨은 fast 쪽 것 하나만 있으면 된다(둘 다 있으면 텍스트가 겹쳐 두꺼워 보임).
	slowMask.ZIndex = 1 -- fast(기본 ZIndex 2)보다 확실히 뒤로.

	local fastMask, label, trackWidth = createFillOverlay(image, parent, scale, track, fastColor)
	return fastMask, slowMask, label, trackWidth
end

local exports = {}

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	screenGui.ResetOnSpawn = false
	-- IgnoreGuiInset을 안 켠다(기본값 false) — 로블록스 기본 상단 메뉴바 영역과 안 겹치게.

	local root = Instance.new("Frame")
	root.Name = "HUDRoot"
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.fromOffset(24, 24)
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Size = UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	uiTheme.applyResponsiveScale(root)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = root

	local charFrame, charScale = createOverlayFrame(root, 1, CHAR_UI_ASSET, CHAR_UI_NATIVE)

	-- 원래 직업 가면 사진을 넣으려던 초상화 원 자리에 레벨 숫자를 큼직하게 표시.
	local portraitLevelLabel = Instance.new("TextLabel")
	portraitLevelLabel.Name = "PortraitLevelLabel"
	portraitLevelLabel.BackgroundTransparency = 1
	portraitLevelLabel.Position = UDim2.fromOffset(PORTRAIT_RECT.x * charScale, PORTRAIT_RECT.y * charScale)
	portraitLevelLabel.Size = UDim2.fromOffset(PORTRAIT_RECT.w * charScale, PORTRAIT_RECT.h * charScale)
	portraitLevelLabel.FontFace = uiTheme.Font
	portraitLevelLabel.TextScaled = true
	portraitLevelLabel.TextColor3 = TEXT_COLOR
	portraitLevelLabel.Text = "1"
	portraitLevelLabel.ZIndex = 2
	portraitLevelLabel.Parent = charFrame

	local hpMask, hpSlowMask, hpLabel, hpMaxWidth = createDualFillOverlay(
		CHAR_UI_ASSET, charFrame, charScale, HP_TRACK,
		Color3.fromRGB(255, 70, 60), Color3.fromRGB(255, 210, 120)
	)
	-- 마나는 하얀색에 가까운 옅은 노란색으로.
	local mpMask, mpLabel, mpMaxWidth = createFillOverlay(CHAR_UI_ASSET, charFrame, charScale, MP_TRACK, Color3.fromRGB(255, 250, 205))

	local expFrame, expScale = createOverlayFrame(root, 2, EXP_ASSET, EXP_NATIVE)
	-- 경험치는 연두색(yellow-green)으로.
	local expMask, expLabel, expMaxWidth = createFillOverlay(EXP_ASSET, expFrame, expScale, EXP_TRACK, Color3.fromRGB(170, 220, 60))
	-- 레벨 숫자는 이제 초상화 원 쪽(portraitLevelLabel)에서만 표시한다.

	screenGui.Parent = playerGui
	exports.screenGui = screenGui

	-- (Phase 1 전투 타격감) 뒤쪽(주황) 바가 목표치까지 내려가는 데 걸리는 시간 —
	-- monsterHealthBar.luau와 동일하게 1.5초.
	local SLOW_FILL_DURATION = 1.5
	local slowFillScale = 1
	local lastHealth = nil

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		local character = CrossPlatformService.Character
		if not character then
			return
		end

		local health = character.Health or 0
		local maxHealth = character.MaxHealth or 1
		local targetScale = math.clamp(health / maxHealth, 0, 1)

		-- 앞쪽(빨강)은 새 값으로 즉시 스냅.
		hpMask.Size = UDim2.fromOffset(hpMaxWidth * targetScale, hpMask.Size.Y.Offset)
		hpLabel.Text = ("%d / %d"):format(math.floor(health + 0.5), maxHealth)

		if lastHealth == nil then
			slowFillScale = targetScale
		elseif health > lastHealth then
			-- 회복은 뒤쪽 바도 즉시 따라 올려서 어색한 역방향 애니메이션을 피한다.
			slowFillScale = targetScale
		end
		lastHealth = health

		-- 뒤쪽(주황, "방금 깎여나간 만큼"을 보여주는 잔상)은 목표치를 향해 천천히
		-- 줄어든다 — 절대 목표치보다 먼저 내려가지 않게 아래로만 보정.
		if slowFillScale > targetScale then
			local step = delta / SLOW_FILL_DURATION
			slowFillScale = math.max(slowFillScale - step, targetScale)
		else
			slowFillScale = targetScale
		end
		hpSlowMask.Size = UDim2.fromOffset(hpMaxWidth * slowFillScale, hpSlowMask.Size.Y.Offset)

		-- 마나 소비/회복 콘텐츠가 아직 없어서 필드가 없으면 항상 가득 찬 것으로 표시.
		local mana = character.Mana or character.MaxMana or 100
		local maxMana = character.MaxMana or 100
		mpMask.Size = UDim2.fromOffset(mpMaxWidth * math.clamp(mana / maxMana, 0, 1), mpMask.Size.Y.Offset)
		mpLabel.Text = ("%d / %d"):format(mana, maxMana)

		local experience = character.Experience or 0
		local maxExperience = character.MaxExperience or 100
		expMask.Size = UDim2.fromOffset(expMaxWidth * math.clamp(experience / maxExperience, 0, 1), expMask.Size.Y.Offset)
		expLabel.Text = ("%d / %d"):format(experience, maxExperience)

		portraitLevelLabel.Text = tostring(character.Level or 1)
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end

	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
end

return exports
