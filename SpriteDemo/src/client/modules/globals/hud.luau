-- 플레이어 상태 HUD. 두 부분:
--  1) 화면 왼쪽 위의 장식 틀(Assets/.../ui/gui.png — 동그란 초상 칸 + 체력/도력 막대 창 두 개, 막대 창은
--     투명하게 뚫려 있다). 뚫린 창 "뒤"에서 막대를 채워 넣고 그 위를 틀 이미지가 덮는 방식이라, 막대가
--     창 밖으로 넘쳐도 틀에 가려 깔끔하다. 동그란 칸에는 경지(레벨) 숫자를 쓴다.
--  2) 화면 맨 아래를 가로로 꽉 채우는 아주 얇은 경험치 막대.
-- 모든 막대는 값이 바뀔 때 즉시 점프하지 않고 부드럽게 차오르거나 줄어든다. 체력은 몬스터 체력바처럼
-- 이중 바(앞쪽은 빠르게, 뒤쪽 주황 잔상은 1.5초에 걸쳐 천천히 따라 내려옴)로 그린다.
--
-- 이미지 준비: 원본(1672x941)의 투명 여백을 잘라내고 가로 1024로 줄여 올렸다(로블록스 업로드 1024 상한).
-- 아래 좌표는 전부 그 1024x453 이미지 기준 픽셀이고(PIL로 뚫린 창/동그란 칸을 실측), DISPLAY_SCALE로
-- 화면 크기에 맞춰 환산한다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)

-- (실측 버그 이력) 폰트 경로 문자열("rbxasset://fonts/families/GothicA1.json")은 Studio에서 로드 실패("Temp read failed")했고,
-- Enum.Font.GothicA1은 존재하지 않는 열거형이라 클라이언트 전체가 로드 에러로 멈췄다. 확실히 존재하는 기본 열거형 폰트로 둔다
-- (한글은 로블록스가 자동으로 대체 글꼴로 그린다).
local HUD_FONT = Font.fromEnum(Enum.Font.SourceSansBold)

local FRAME_ASSET = "rbxassetid://92620503060435"
local FRAME_NATIVE = Vector2.new(1024, 453)
local DISPLAY_WIDTH = 320 -- 처음 420은 너무 커서 줄였다(화면 배율은 uiTheme.applyResponsiveScale이 따로 맞춘다).
local DISPLAY_SCALE = DISPLAY_WIDTH / FRAME_NATIVE.X
local DISPLAY_HEIGHT = math.floor(FRAME_NATIVE.Y * DISPLAY_SCALE)

-- 뚫린 막대 창(x, y, w, h)과 동그란 초상 칸(중심, 지름) — 1024x453 이미지 기준.
local HP_WINDOW = { x = 447, y = 136, w = 466, h = 27 }
local MP_WINDOW = { x = 446, y = 194, w = 467, h = 27 }
local CIRCLE = { cx = 187, cy = 148, d = 156 }
-- 막대를 창보다 이만큼(이미지 픽셀) 넉넉하게 깔아, 창 가장자리(둥근 끝)에 빈틈이 안 생기게 한다.
local BLEED = 8

local EXP_BAR_HEIGHT = 5

local TRACK_BACK = Color3.fromRGB(28, 18, 14) -- 창 안쪽 빈 부분 바탕(틀 색과 어울리는 어두운 갈색)
local TEXT_LIGHT = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(150, 95, 10)

local HP_COLOR = Color3.fromRGB(226, 60, 50)
local HP_TRAIL_COLOR = Color3.fromRGB(255, 200, 110)
local MP_COLOR = Color3.fromRGB(255, 250, 205)
local EXP_COLOR = Color3.fromRGB(170, 220, 60)

local SLOW_FILL_DURATION = 1.5
-- 값이 바뀔 때 막대가 목표를 따라가는 속도(클수록 빠름) — 지수 보간.
local FILL_SPEED = 9

local function d(v: number): number
	return v * DISPLAY_SCALE
end

local function makeLabel(parent: Instance, text: string, size: number, position: UDim2, boxSize: UDim2, color: Color3, align: Enum.TextXAlignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = boxSize
	label.FontFace = HUD_FONT
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = if color.R + color.G + color.B < 1.2 then 1 else 0.4
	label.TextXAlignment = align
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text
	label.Parent = parent
	return label
end

local function makeFill(track: Frame, color: Color3, zIndex: number)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = zIndex
	fill.Parent = track
	uiTheme.AddCorner(fill, "full")

	-- 위는 밝고 아래는 살짝 어둡게 — 납작한 색면이 아니라 막대다운 입체감.
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 175, 175)),
	})
	gradient.Parent = fill
	return fill
end

-- 막대(어두운 바탕 + 뒤쪽 잔상(선택) + 앞쪽 채움 + 수치 글자). rect는 트랙이 차지할 위치/크기.
local function makeBar(parent: Instance, position: UDim2, size: UDim2, color: Color3, trailColor: Color3?, zIndex: number)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = TRACK_BACK
	track.BorderSizePixel = 0
	track.Position = position
	track.Size = size
	track.ClipsDescendants = true
	track.ZIndex = zIndex
	track.Parent = parent
	uiTheme.AddCorner(track, "full")

	local trail = if trailColor then makeFill(track, trailColor, zIndex + 1) else nil
	local fill = makeFill(track, color, zIndex + 2)
	return { track = track, fill = fill, trail = trail }
end

-- 창 위치(1024x453 기준) → 넉넉하게 넘치는 트랙 위치/크기(화면 픽셀).
local function bleedRect(window)
	return UDim2.fromOffset(d(window.x - BLEED), d(window.y - BLEED / 2)),
		UDim2.fromOffset(d(window.w + BLEED * 2), d(window.h + BLEED))
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
	-- IgnoreGuiInset을 안 켠다(기본값 false) — 왼쪽 위의 로블록스 기본 메뉴 버튼 영역과 안 겹치게.

	local root = Instance.new("Frame")
	root.Name = "HUDRoot"
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.fromOffset(12, 8)
	root.Size = UDim2.fromOffset(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	uiTheme.applyResponsiveScale(root, Vector2.new(DISPLAY_WIDTH + 24, DISPLAY_HEIGHT + 16))

	-- 막대는 틀 이미지(ZIndex 10) "뒤"(낮은 ZIndex)에 깔고, 수치/레벨 글자는 틀 위(ZIndex 20)에 얹는다.
	local hpPos, hpSize = bleedRect(HP_WINDOW)
	local mpPos, mpSize = bleedRect(MP_WINDOW)
	local hpBar = makeBar(root, hpPos, hpSize, HP_COLOR, HP_TRAIL_COLOR, 1)
	local mpBar = makeBar(root, mpPos, mpSize, MP_COLOR, nil, 1)

	local frame = Instance.new("ImageLabel")
	frame.Name = "Frame"
	frame.Image = FRAME_ASSET
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 10
	frame.Parent = root

	-- 수치는 막대 창 정중앙에(창 안의 실제 보이는 영역 기준). 어두운 바탕 위라 흰 글씨 + 외곽선.
	local function windowLabel(window)
		local label = makeLabel(
			root, "", 10,
			UDim2.fromOffset(d(window.x), d(window.y)), UDim2.fromOffset(d(window.w), d(window.h)),
			TEXT_LIGHT, Enum.TextXAlignment.Center
		)
		label.ZIndex = 20
		return label
	end
	local hpLabel = windowLabel(HP_WINDOW)
	local mpLabel = windowLabel(MP_WINDOW)

	-- 동그란 초상 칸에 "Lv." + 경지(레벨) 숫자.
	local circleLeft = d(CIRCLE.cx - CIRCLE.d / 2)
	local circleTop = d(CIRCLE.cy - CIRCLE.d / 2)
	local circleSize = d(CIRCLE.d)
	local lvLabel = makeLabel(
		root, "Lv.", 9, UDim2.fromOffset(circleLeft, circleTop + circleSize * 0.2), UDim2.fromOffset(circleSize, circleSize * 0.2),
		Color3.fromRGB(70, 45, 20), Enum.TextXAlignment.Center
	)
	lvLabel.ZIndex = 20
	local levelLabel = makeLabel(
		root, "1", 22, UDim2.fromOffset(circleLeft, circleTop + circleSize * 0.38), UDim2.fromOffset(circleSize, circleSize * 0.4),
		GOLD, Enum.TextXAlignment.Center
	)
	levelLabel.ZIndex = 20

	-- 경험치: 화면 맨 아래를 가로로 꽉 채우는 아주 얇은 막대. 안에 글씨 대신, 수치는 막대 바로 위 오른쪽 끝에 작게.
	local expTrack = makeBar(screenGui, UDim2.new(0, 0, 1, -EXP_BAR_HEIGHT), UDim2.new(1, 0, 0, EXP_BAR_HEIGHT), EXP_COLOR, nil, 1)
	expTrack.track.BackgroundTransparency = 0.8
	local expLabel = makeLabel(
		screenGui, "", 11, UDim2.new(1, -168, 1, -EXP_BAR_HEIGHT - 16), UDim2.fromOffset(160, 14), TEXT_LIGHT, Enum.TextXAlignment.Right
	)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui

	-- 화면에 보이는 값(부드럽게 움직이는 쪽). 목표값 쪽으로 매 프레임 조금씩 다가간다.
	local shown = { hp = nil, hpTrail = nil, mp = nil, exp = nil }
	local lastHealth = nil

	local function approach(current: number?, target: number, delta: number): number
		if current == nil then
			return target -- 처음에는 애니메이션 없이 바로(로딩 직후 0에서 차오르는 어색함 방지).
		end
		local alpha = 1 - math.exp(-FILL_SPEED * delta)
		local nextValue = current + (target - current) * alpha
		if math.abs(target - nextValue) < 0.002 then
			return target
		end
		return nextValue
	end

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		local character = CrossPlatformService.Character
		if not character then
			return
		end

		levelLabel.Text = tostring(character.Level or 1)

		-- 체력: 앞쪽은 빠르게 목표로, 뒤쪽 잔상은 맞았을 때만 1.5초에 걸쳐 따라 내려온다(회복은 같이 올라감).
		local health = character.Health or 0
		local maxHealth = math.max(character.MaxHealth or 1, 1)
		local hpTarget = math.clamp(health / maxHealth, 0, 1)
		shown.hp = approach(shown.hp, hpTarget, delta)
		if shown.hpTrail == nil or (lastHealth ~= nil and health > lastHealth) then
			shown.hpTrail = shown.hp
		end
		lastHealth = health
		if shown.hpTrail > shown.hp then
			shown.hpTrail = math.max(shown.hpTrail - delta / SLOW_FILL_DURATION, shown.hp)
		else
			shown.hpTrail = shown.hp
		end
		hpBar.fill.Size = UDim2.fromScale(shown.hp, 1)
		hpBar.trail.Size = UDim2.fromScale(shown.hpTrail, 1)
		hpLabel.Text = ("%d / %d"):format(math.floor(health + 0.5), maxHealth)

		-- 도력: 소비/회복 콘텐츠가 아직 없어서 필드가 없으면 항상 가득 찬 것으로 표시.
		local maxMana = character.MaxMana or 100
		local mana = character.Mana or maxMana
		shown.mp = approach(shown.mp, math.clamp(mana / maxMana, 0, 1), delta)
		mpBar.fill.Size = UDim2.fromScale(shown.mp, 1)
		mpLabel.Text = ("%d / %d"):format(mana, maxMana)

		-- 경험치: 얻을 때마다 부드럽게 차오른다(레벨업으로 값이 크게 줄면 그냥 바로 따라 내려감).
		local experience = character.Experience or 0
		local maxExperience = math.max(character.MaxExperience or 100, 1)
		local expTarget = math.clamp(experience / maxExperience, 0, 1)
		shown.exp = approach(shown.exp, expTarget, delta)
		expTrack.fill.Size = UDim2.fromScale(shown.exp, 1)
		expLabel.Text = ("경험치 %d / %d (%.1f%%)"):format(experience, maxExperience, expTarget * 100)
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
