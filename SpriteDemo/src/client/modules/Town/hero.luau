-- 탑다운 전환: Ninja Adventure Asset Pack(NinjaGreen)의 4방향 Idle/Walk 스프라이트를 쓴다.
-- 원본 시트(Idle.png/Walk.png)는 4x4 그리드인데, 방향이 "행"이 아니라 "열" 기준이다 —
-- 왼쪽부터 열1=아래, 열2=위, 열3=왼쪽, 열4=오른쪽이고 각 열 안에서 위→아래로 그 방향의
-- 애니메이션 프레임이 재생된다(레퍼런스 GIF로 확인). 그래서 방향별로 열 단위(32x128, 세로
-- 4프레임)로 잘라 올렸고, FRAME_GRID를 (1,4)로 둬서 Y축으로 프레임을 재생한다 — 이전에 행
-- 단위(4x1)로 잘랐을 때는 한 이미지 안에 서로 다른 4방향이 섞여 있어서 가만히 있어도 방향이
-- 계속 바뀌어 보이는(빙글빙글 도는) 문제가 있었다.
-- CrossPlatformService.SideView = false로 두면 엔진이 자동으로 4방향 입력/애니메이션을 처리한다
-- (up/down/left/right 걷기, idle_up/idle_down/idle_left/idle_right 정지) — 점프는 side view 전용이라
-- 여기선 동작하지 않는다.
-- hero:Load()는 쓰지 않는다 — 내부적으로 ContentProvider:PreloadAsync()를 동기 호출하는데,
-- 방금 업로드한 에셋에서 이게 끝없이 블로킹돼서 이 exports.load() 전체가 멈추는 걸 실측 확인
-- (StaticObject:Load 참고). Play()가 시작되면 SpritePlayer.luau가 매 프레임 Instance.Image를
-- 알아서 갱신하므로 최초 이미지는 직접 지정한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local IDLE_DOWN = "rbxassetid://96675597256879"
local IDLE_LEFT = "rbxassetid://107894135932128"
local IDLE_RIGHT = "rbxassetid://130412459189584"
local IDLE_UP = "rbxassetid://77995554853337"
local WALK_DOWN = "rbxassetid://98442771882460"
local WALK_LEFT = "rbxassetid://127242018909263"
local WALK_RIGHT = "rbxassetid://96147776484017"
local WALK_UP = "rbxassetid://128781622632777"
local FRAME_SIZE = Vector2.new(32, 32)
local FRAME_GRID = Vector2.new(1, 4)
local DISPLAY_SCALE = 2 -- 화면에 보이는 크기 배율(원본 프레임은 32x32라 작게 보여서 키운다)

local SPAWN_POSITION = UDim2.fromOffset(0, 0)

local exports = {}

function exports.load(scene: Scene)
	-- Scene Manager 플러그인 데이터(UpsideEngineDB)에 의존하지 않고 코드로 Character를 직접
	-- 생성한다 — 플러그인으로 배치한 오브젝트와 이름이 겹치거나 낡은 저장 데이터가 남는 문제를
	-- 원천적으로 피한다.
	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero.SecondsPerFrame = 0.12
	hero.Anchored = false
	-- Physics.luau는 SideView 값과 무관하게 중력을 항상 적용한다(GravityScale만 참고).
	-- 탑다운은 중력이 없어야 하므로 이 오브젝트만 중력을 끈다.
	hero.GravityScale = 0

	local instance = hero.Instance
	instance.Image = IDLE_DOWN
	instance.Position = SPAWN_POSITION
	instance.Size = UDim2.fromOffset(FRAME_SIZE.X * DISPLAY_SCALE, FRAME_SIZE.Y * DISPLAY_SCALE)
	instance.ImageRectSize = FRAME_SIZE
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	hero:SetSpriteSheet("idle_down", IDLE_DOWN, FRAME_GRID)
	hero:SetSpriteSheet("idle_left", IDLE_LEFT, FRAME_GRID)
	hero:SetSpriteSheet("idle_right", IDLE_RIGHT, FRAME_GRID)
	hero:SetSpriteSheet("idle_up", IDLE_UP, FRAME_GRID)
	hero:SetSpriteSheet("down", WALK_DOWN, FRAME_GRID)
	hero:SetSpriteSheet("left", WALK_LEFT, FRAME_GRID)
	hero:SetSpriteSheet("right", WALK_RIGHT, FRAME_GRID)
	hero:SetSpriteSheet("up", WALK_UP, FRAME_GRID)
	hero:Play("idle_down")

	CrossPlatformService.SideView = false
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	-- 카메라 추종은 camera.luau의 start()가 CrossPlatformService.Character를 보고 처리한다.
end

function exports.unload(scene: Scene)
	exports.hero = nil
end

return exports
