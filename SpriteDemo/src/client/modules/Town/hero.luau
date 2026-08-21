-- SpaceFighter 예제의 modules/game/spaceship.luau 패턴을 재활용:
-- 플레이어가 조작하는 "유일한" 오브젝트는 스크립트에서 새로 만들지 않고, Scene Manager
-- 플러그인으로 씬에 미리 배치해둔 뒤 scene.Objects:FindByName()으로 찾아서 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

-- Ninja Adventure Asset Pack(CC0, pixel-boy)의 NinjaGreen 캐릭터. 팩 README에는 그리드
-- 문서가 없어서, Preview/Push.gif(상자를 미는 4방향 애니메이션)로 방향을 실측 검증했다:
-- 상자가 캐릭터 기준 아래/위/왼쪽/오른쪽 중 어디에 있는지로 각 프레임의 실제 방향을 알아낸 뒤
-- (프레임0-3=아래, 4-7=위, 8-11=왼쪽, 12-15=오른쪽), 그 포즈들을 Separate/Walk.png,Idle.png의
-- 4x4 그리드와 대조했다. 결과: 방향은 "행"이 아니라 "열" 기준이다 — 열0=아래(정면), 열1=위
-- (뒤통수만 보임), 열2=왼쪽, 열3=오른쪽(얼굴 비대칭 위치로 왼쪽/오른쪽 구분 확인). 행은
-- 걷기/숨쉬기 애니메이션 프레임(0~3)이다. 이 사실을 바탕으로 각 열을 다시 잘라 방향별
-- 4프레임 가로 스트립(128x32)으로 새로 만들었다.
local IDLE_DOWN = "rbxassetid://121539012222072"
local IDLE_LEFT = "rbxassetid://74299535482049"
local IDLE_RIGHT = "rbxassetid://114783849777960"
local IDLE_UP = "rbxassetid://127592117956655"
local WALK_DOWN = "rbxassetid://102062913335734"
local WALK_LEFT = "rbxassetid://74190271824272"
local WALK_RIGHT = "rbxassetid://85077734646819"
local WALK_UP = "rbxassetid://120535248659777"
local FRAME_SIZE = Vector2.new(32, 32)

local exports = {}

function exports.load(scene: Scene)
	scene.Gravity = Vector2.zero -- 탑다운은 중력이 없다

	local hero = scene.Objects:FindByName("Hero")
	assert(hero, "Hero 오브젝트를 찾을 수 없습니다 — Scene Manager 플러그인에서 Character 타입으로 배치했는지 확인하세요")

	hero:Load(IDLE_DOWN)
	hero.SecondsPerFrame = 0.125
	hero.Mass = 50
	hero.WalkSpeed = 90
	-- 캐릭터 그림이 32x32 프레임을 거의 꽉 채우므로 여백이 크지 않다. 그래도 타일(96px)
	-- 대비 캐릭터가 과도하게 크면 충돌 판정이 타일 한 칸 앞에서 미리 멈추는 문제가
	-- 있었으므로(실측 확인됨), 약간의 여유를 두고 0.85로 설정한다.
	hero.HitboxScale = 0.85

	local instance = hero.Instance
	instance.Position = UDim2.fromOffset(0, 0)
	-- 원본 32x32를 2배로 표시(64x64) — 타일(96px)보다 작아서 충돌 오버슈트 문제를 피한다.
	instance.Size = UDim2.fromOffset(FRAME_SIZE.X * 2, FRAME_SIZE.Y * 2)
	instance.ImageRectSize = FRAME_SIZE
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	-- 엔진 기본 컨트롤러(CrossPlatformTracker.luau)가 요구하는 정확한 이름:
	--   이동 중: "up"/"down"/"left"/"right", 정지 시: "idle_up"/"idle_down"/"idle_left"/"idle_right"
	hero:SetSpriteSheet("idle_down", IDLE_DOWN, Vector2.new(4, 1))
	hero:SetSpriteSheet("idle_up", IDLE_UP, Vector2.new(4, 1))
	hero:SetSpriteSheet("idle_left", IDLE_LEFT, Vector2.new(4, 1))
	hero:SetSpriteSheet("idle_right", IDLE_RIGHT, Vector2.new(4, 1))
	hero:SetSpriteSheet("down", WALK_DOWN, Vector2.new(4, 1))
	hero:SetSpriteSheet("up", WALK_UP, Vector2.new(4, 1))
	hero:SetSpriteSheet("left", WALK_LEFT, Vector2.new(4, 1))
	hero:SetSpriteSheet("right", WALK_RIGHT, Vector2.new(4, 1))
	hero:Play("idle_down")

	CrossPlatformService.SideView = false
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	-- code to run once everything is ready
end

function exports.unload(scene: Scene)
	exports.hero = nil
end

return exports
