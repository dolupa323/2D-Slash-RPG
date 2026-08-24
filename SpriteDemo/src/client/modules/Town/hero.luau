-- 메이플스토리 스타일 횡스크롤. GandalfHardcore Character Asset Pack의 Male Skin1.png를
-- 옷/헤어 없는 기본 스킨으로 사용한다(사용자 선택: 고정 스킨으로 빨리 게임 돌아가게).
-- 원본 시트는 80x64 격자, 행마다 다른 애니메이션. 행별 픽셀 좌표를 실측해서(연속 알파
-- 영역 스캔) idle(0행,5프레임)/walk(1행,8프레임)을 잘라냈다. 왼쪽 방향은 원본에 없어서
-- (오른쪽만 그려져 있음) PIL로 좌우 반전해서 별도 업로드했다 — 실측(코 방향 확대 확인)으로
-- 원본이 왼쪽을 보고 있다는 걸 재확인해서 IDLE/WALK LEFT·RIGHT 배정을 맞췄다.
--
-- 이동이 전혀 안 되던 문제의 근본 원인(엔진 소스에 직접 진단 코드를 심어서 실측 확인, 여러
-- 차례 재검증): CrossPlatformTracker(메인 스레드)가 매 프레임 character.Velocity를 세팅해도,
-- 실제 위치를 옮기는 Physics.luau는 RunService.Heartbeat:ConnectParallel(병렬 액터)에서
-- 따로 돌아서 그 값을 온전히 못 읽는다 — 직접 값을 찍어보니 Physics가 실제로 쓰는 velocity는
-- 매 프레임 1픽셀도 안 됐다. UDim2 Offset은 정수 단위라 이런 1px 미만 이동은 매번 반올림으로
-- 사라져서 영원히 안 움직였다.
-- 처음엔 "점프만 큰 속도라 이 문턱을 넘는다"고 생각해서 좌우만 직접 구현하고 점프는 여전히
-- hero.Velocity(엔진 물리)에 맡겼는데, 그러니 이번엔 점프 자체가 죽었다 — 바닥 고정 로직
-- (여기 있는 Heartbeat)이 "접촉 유지" 판정 때문에 매 프레임 Velocity.Y를 0으로 되돌리는데,
-- 그게 병렬 액터가 점프 속도를 미처 적용하기도 전에 같은 프레임(또는 바로 다음 프레임)에
-- 취소해버린 것. 결국 세로 방향도 엔진 Velocity/Physics를 아예 안 거치고 직접 구현해야
-- 안전하다 — 그래서 중력·점프·바닥 고정을 전부 이 스크립트 안의 순수 계산으로 옮겼다.
-- hero.Velocity는 이제 이동에 전혀 안 쓴다(애니메이션 상태 전환용 DefaultControllersEnabled만
-- 계속 켜둔다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local IDLE_RIGHT = "rbxassetid://92541671973889"
local IDLE_LEFT = "rbxassetid://99438009204418"
local WALK_RIGHT = "rbxassetid://95695385364364"
local WALK_LEFT = "rbxassetid://108987429791684"
local FRAME_SIZE = Vector2.new(80, 64)

-- 전부 직접 계산이라 여기 숫자만 바꾸면 튜닝됨.
local WALK_SPEED_PX = 220 -- 초당 픽셀
local GRAVITY_PX = 3000 -- 초당 픽셀/초 (가속도)
local JUMP_SPEED_PX = 900 -- 점프 상승 초기 속도(초당 픽셀) — 정점 약 0.3초, 높이 약 1.4칸

-- mapData.luau의 바닥 정의(y=240, 98px 타일)와 맞춘 상수. 바닥이 바뀌면 같이 바꿔야 한다.
local GROUND_TOP_Y = 240 - 98 / 2
local GROUND_LEFT_X = -576 - 98 / 2
local GROUND_RIGHT_X = 576 + 98 / 2

local exports = {}

function exports.load(scene: Scene)
	local hero = scene.Objects:FindByName("Hero")
	assert(hero, "Hero 오브젝트를 찾을 수 없습니다 — Scene Manager 플러그인에서 Character 타입으로 배치했는지 확인하세요")

	hero:Load(IDLE_RIGHT)
	hero.SecondsPerFrame = 0.1

	local instance = hero.Instance
	instance.Position = UDim2.fromOffset(0, 0)
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

	-- DefaultControllersEnabled는 켜둔다 — 애니메이션 상태 전환(idle/walk 전환)이 여기 달려
	-- 있다. 실제 이동(Position 변경)은 전부 아래에서 직접 처리하고, character.Velocity는
	-- 더 이상 이동 목적으로 안 쓴다.
	CrossPlatformService.SideView = true
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	-- DefaultControllersEnabled를 켜두면 CrossPlatformTracker.luau의 characterController가
	-- 매 프레임 여전히 character:Jump()/character.Velocity를 건드린다(애니메이션용 actions
	-- 테이블은 같은 컨트롤러에 묶여있어서 끌 수 없다). 이 Velocity를 Physics.luau(병렬 액터)가
	-- 계속 중력 누적 + Instance.Position 갱신에 반영해서, 우리가 같은 프레임에 쓰는 커스텀
	-- Position과 경쟁해 순간이동하는 버그가 있었다(MCP로 [DIAGY] 로그 찍어서 y가
	-- 159→493→1037→159로 튀는 걸 실측 확인). Anchored=true로 막는다 — Physics.luau는
	-- Anchored 오브젝트를 freefall(위치 갱신) 목록에서 아예 빼고 update() 함수 자체도
	-- Anchored면 즉시 리턴하도록 이중삼중으로 막아놔서, 엔진이 Position에 손대는 경로 자체가
	-- 원천 차단된다. character.Velocity/Jump 호출은 여전히 일어나지만 이제 아무 코드도 그
	-- 값으로 Position을 옮기지 않는다.
	hero.Anchored = true

	exports.hero = hero
	exports.isGrounded = true
	exports.moveDir = 0 -- -1=왼쪽, 0=정지, 1=오른쪽
	exports.velocityY = 0
end

function exports.start(scene: Scene)
	-- 카메라 추종은 camera.luau의 start()가 CrossPlatformService.Character를 보고 처리한다.

	local RunService = game:GetService("RunService")
	local hero = exports.hero
	if not hero then
		return
	end

	local halfHeight = FRAME_SIZE.Y / 2
	local halfWidth = FRAME_SIZE.X / 2
	local restY = GROUND_TOP_Y - halfHeight

	-- InputBegin은 물리 키 누름당 한 번만 온다(꾹 눌러도 재발화 안 됨) — 그래서 "연타하면 착지
	-- 즉시 재점프, 꾹 누르면 다음 점프까지 텀이 생김" 불일치가 있었다. upHeld로 눌림 상태
	-- 자체를 들고 있다가, 아래 Heartbeat에서 "눌려 있고 + 막 착지함" 조건으로 매번 재점프시켜서
	-- 연타와 꾹 누르기가 동일하게 동작하게 만든다.
	local upHeld = false

	CrossPlatformService:On("InputBegin", function(inputObject)
		if inputObject.Action == "Left" then
			exports.moveDir = -1
		elseif inputObject.Action == "Right" then
			exports.moveDir = 1
		elseif inputObject.Action == "Up" then
			upHeld = true
			if exports.isGrounded then
				exports.velocityY = -JUMP_SPEED_PX
				exports.isGrounded = false
			end
		end
	end)

	CrossPlatformService:On("InputEnd", function(inputObject)
		if inputObject.Action == "Left" and exports.moveDir == -1 then
			exports.moveDir = 0
		elseif inputObject.Action == "Right" and exports.moveDir == 1 then
			exports.moveDir = 0
		elseif inputObject.Action == "Up" then
			upHeld = false
		end
	end)

	local lastClock = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = math.min(now - lastClock, 1 / 20) -- 프레임 드랍 시 한 번에 너무 크게 점프하지 않도록 캡
		lastClock = now

		local instance = hero.Instance
		local pos = instance.Position

		local x = pos.X.Offset + exports.moveDir * WALK_SPEED_PX * dt
		x = math.clamp(x, GROUND_LEFT_X + halfWidth, GROUND_RIGHT_X - halfWidth)

		exports.velocityY += GRAVITY_PX * dt
		local y = pos.Y.Offset + exports.velocityY * dt
		local feetY = y + halfHeight

		if feetY >= GROUND_TOP_Y and exports.velocityY >= 0 then
			y = restY
			exports.velocityY = 0
			if upHeld then
				exports.velocityY = -JUMP_SPEED_PX
				exports.isGrounded = false
			else
				exports.isGrounded = true
			end
		else
			exports.isGrounded = false
		end

		instance.Position = UDim2.fromOffset(x, y)
	end)
end

function exports.unload(scene: Scene)
	exports.hero = nil
end

return exports
