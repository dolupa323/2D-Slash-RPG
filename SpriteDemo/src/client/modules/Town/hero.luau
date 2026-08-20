-- SpaceFighter 예제의 modules/game/spaceship.luau 패턴을 재활용:
-- 플레이어가 조작하는 "유일한" 오브젝트는 스크립트에서 새로 만들지 않고, Scene Manager
-- 플러그인으로 씬에 미리 배치해둔 뒤 scene.Objects:FindByName()으로 찾아서 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

-- hero2_topdown (sprite-gen) 4방향 idle + walk. 원본 256x256 칸에서 캐릭터가 실제로 그려진
-- 영역(94,151,163,240 + 여유 8px)만 남기고 다시 크롭한 69x89 프레임 사용 — Instance.Size나
-- HitboxScale로 우회하지 않고 이미지 자체의 투명 여백을 제거한 것이 근본 해결책이었다.
local IDLE_DOWN = "rbxassetid://94223352968956"
local IDLE_UP = "rbxassetid://85612115830214"
local IDLE_LEFT = "rbxassetid://134458246440596"
local IDLE_RIGHT = "rbxassetid://87042318259786"
local WALK_DOWN = "rbxassetid://84053810163197"
local WALK_UP = "rbxassetid://91088062123550"
local WALK_LEFT = "rbxassetid://98827223717513"
local WALK_RIGHT = "rbxassetid://122458851573145"
local FRAME_SIZE = Vector2.new(69, 89)

local exports = {}

function exports.load(scene: Scene)
	scene.Gravity = Vector2.zero -- 탑다운은 중력이 없다

	local hero = scene.Objects:FindByName("Hero")
	assert(hero, "Hero 오브젝트를 찾을 수 없습니다 — Scene Manager 플러그인에서 Character 타입으로 배치했는지 확인하세요")

	hero:Load(IDLE_DOWN)
	hero.SecondsPerFrame = 0.125
	hero.Mass = 50
	hero.WalkSpeed = 90
	-- 69x89 프레임 안에서 캐릭터 그림 자체는 53x73만 차지한다(걷기 애니메이션 팔다리가
	-- 안 잘리게 상하좌우 8px씩 여백을 일부러 남겨서 크롭했기 때문 — 실측 확인, 추측 아님).
	-- 화면 크기는 그대로 두고 충돌 판정만 실제 그림 크기 비율(~0.8)로 줄인다.
	hero.HitboxScale = 0.8

	local instance = hero.Instance
	instance.Position = UDim2.fromOffset(0, 0)
	-- 2배 확대(138x178)였을 때 타일(96px)보다 훨씬 커서 충돌 판정이 타일 한 칸만큼 미리
	-- 멈추는 문제가 있었다(실측: 캐릭터 절반 높이 89px만큼 여유 공간 발생, 위/아래 대칭 확인).
	-- 원본 픽셀 크기(69x89) 그대로 써서 타일 크기(96)에 맞춘다.
	instance.Size = UDim2.fromOffset(FRAME_SIZE.X, FRAME_SIZE.Y)
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
