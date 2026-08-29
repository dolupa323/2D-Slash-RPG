-- 탑다운 복귀: FREE_Adventurer 2D Pixel Art 에셋의 idle/run 4방향을 쓴다.
-- 각 시트는 96x80 칸의 8프레임 가로 스트립이고, idle/run 각각 상하좌우 4장씩 별도 파일이다.
-- CrossPlatformService.SideView = false면 4방향 이동(WASD/방향키)이 활성화되고, 엔진 트래커가
-- "up"/"down"/"left"/"right"/"idle_up"/"idle_down"/"idle_left"/"idle_right" 이름으로 알아서
-- 방향 전환과 정지 시 idle 복귀를 처리한다(사이드뷰 점프 때와 달리 커스텀 오버라이드 불필요).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local IDLE_DOWN = "rbxassetid://128779615003808"
local IDLE_UP = "rbxassetid://76762008503019"
local IDLE_LEFT = "rbxassetid://100318210699473"
local IDLE_RIGHT = "rbxassetid://105958644544046"
local RUN_DOWN = "rbxassetid://106571078711111"
local RUN_UP = "rbxassetid://106523947292961"
local RUN_LEFT = "rbxassetid://109700906749064"
local RUN_RIGHT = "rbxassetid://91366119878042"
local FRAME_SIZE = Vector2.new(96, 80)
local DISPLAY_SCALE = 1.5

local SPAWN_POSITION = UDim2.fromOffset(0, 0)

local exports = {}

function exports.load(scene: Scene)
	-- 엔진 기본값(Vector2.new(0, 9.81*4))은 사이드뷰용 낙하 중력이라, SideView 여부와
	-- 무관하게 Physics.luau가 항상 적용한다(사이드뷰 아닐 때는 감쇠만 안 걸릴 뿐). 탑다운은
	-- Y축이 "아래"가 아니라 "남쪽"이라 중력 자체가 없어야 하므로 0으로 꺼둔다.
	scene.Gravity = Vector2.zero

	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero.SecondsPerFrame = 0.1
	hero.Anchored = false
	hero.HitboxScale = 0.5

	local instance = hero.Instance
	instance.Image = IDLE_DOWN
	instance.Position = SPAWN_POSITION
	instance.Size = UDim2.fromOffset(FRAME_SIZE.X * DISPLAY_SCALE, FRAME_SIZE.Y * DISPLAY_SCALE)
	instance.ImageRectSize = FRAME_SIZE
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	hero:SetSpriteSheet("idle_down", IDLE_DOWN, Vector2.new(8, 1))
	hero:SetSpriteSheet("idle_up", IDLE_UP, Vector2.new(8, 1))
	hero:SetSpriteSheet("idle_left", IDLE_LEFT, Vector2.new(8, 1))
	hero:SetSpriteSheet("idle_right", IDLE_RIGHT, Vector2.new(8, 1))
	hero:SetSpriteSheet("down", RUN_DOWN, Vector2.new(8, 1))
	hero:SetSpriteSheet("up", RUN_UP, Vector2.new(8, 1))
	hero:SetSpriteSheet("left", RUN_LEFT, Vector2.new(8, 1))
	hero:SetSpriteSheet("right", RUN_RIGHT, Vector2.new(8, 1))
	hero:Play("idle_down")

	CrossPlatformService.SideView = false
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	local RunService = game:GetService("RunService")
	local hero = exports.hero
	if not hero then
		return
	end

	RunService.Heartbeat:Connect(function()
		local instance = hero.Instance
		if instance.Position.Y.Offset >= 1000 then
			instance.Position = SPAWN_POSITION
		end
	end)
end

function exports.unload(scene: Scene)
	exports.hero = nil
end

return exports
