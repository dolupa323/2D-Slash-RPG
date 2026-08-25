-- 공식 UpsideEngine "Player Character" 튜토리얼 패턴 그대로 따른다
-- (https://notreux.github.io/UpsideEngine/tutorials/get-started/PlayerCharacter.html).
-- 커스텀 이동/중력/점프 코드를 전부 없애고 Anchored=false로 엔진 물리·충돌·컨트롤러에
-- 그대로 맡긴다. Heartbeat는 튜토리얼과 동일하게 "너무 멀리 떨어지면 리스폰"용 안전장치
-- 하나만 둔다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local IDLE_RIGHT = "rbxassetid://92541671973889"
local IDLE_LEFT = "rbxassetid://99438009204418"
local WALK_RIGHT = "rbxassetid://95695385364364"
local WALK_LEFT = "rbxassetid://108987429791684"
local FRAME_SIZE = Vector2.new(80, 64)

local SPAWN_POSITION = UDim2.fromOffset(0, 0)

local exports = {}

function exports.load(scene: Scene)
	-- Scene Manager 플러그인 데이터(UpsideEngineDB)에 의존하지 않고 튜토리얼 그대로 코드로
	-- Character를 직접 생성한다 — 플러그인으로 배치한 오브젝트와 이름이 겹치거나 낡은 저장
	-- 데이터가 남는 문제를 원천적으로 피한다.
	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero:Load(IDLE_RIGHT)
	hero.SecondsPerFrame = 0.1
	hero.Anchored = false -- 엔진 물리/충돌 사용(튜토리얼 기본값)

	local instance = hero.Instance
	instance.Position = SPAWN_POSITION
	instance.Size = UDim2.fromOffset(FRAME_SIZE.X, FRAME_SIZE.Y)
	instance.ImageRectSize = FRAME_SIZE
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	hero:SetSpriteSheet("idle_right", IDLE_RIGHT, Vector2.new(5, 1))
	hero:SetSpriteSheet("idle_left", IDLE_LEFT, Vector2.new(5, 1))
	hero:SetSpriteSheet("right", WALK_RIGHT, Vector2.new(8, 1))
	hero:SetSpriteSheet("left", WALK_LEFT, Vector2.new(8, 1))
	hero:Play("idle_right")

	CrossPlatformService.SideView = true
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	-- 카메라 추종은 camera.luau의 start()가 CrossPlatformService.Character를 보고 처리한다.
	local RunService = game:GetService("RunService")
	local hero = exports.hero
	if not hero then
		return
	end

	RunService.Heartbeat:Connect(function()
		local instance = hero.Instance
		if instance.Position.Y.Offset < 1000 then
			return
		end
		instance.Position = SPAWN_POSITION
	end)
end

function exports.unload(scene: Scene)
	exports.hero = nil
end

return exports
