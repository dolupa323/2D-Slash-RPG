-- 2D 횡스크롤 캐릭터: talchar 캐릭터를 방향별 스프라이트시트 6장으로 재작업한 버전.
-- Source: Assets/character/talchar/full-splite/{idle,jump,run}_{left,right}.png
-- 프레임마다 개별 이미지를 올리던 이전 방식(idle/jump/run 합쳐 약 230장)은, Roblox
-- 클라이언트가 이미지를 "화면에 실제로 표시되는 순간" 처음 다운로드하기 때문에 —
-- 애니메이션 전환마다 그 상태의 프레임을 처음 만날 때 다운로드가 끝날 때까지 빈
-- 화면으로 보이는 문제가 있었다(PreloadAsync를 걸어도 재생 속도가 다운로드를
-- 앞질러서 근본적으로 해결이 안 됨). 그래서 상태당 프레임 전체를 한 장의 시트로
-- 합쳐 올려 총 6개 에셋(idle/jump/run × left/right)만 다운로드하면 되게 했다 —
-- 애니메이션 재생 중에는 ImageRectOffset만 바뀌므로 추가 다운로드가 전혀 없다.
--
-- (실측 이력) 예전에 공유 아틀라스를 ImageRectOffset/ImageRectSize로 잘라 쓰는
-- 방식을 시도했다가 화면에 캐릭터가 2개로 겹쳐 보이는 렌더링 버그가 있었다(git
-- fb0095a 대비 diff로 확인) — 원인은 좌우반전에 쓴 "음수 ImageRectSize"였다. 이번엔
-- 애초에 좌우 방향별로 시트가 따로 있어서 좌우반전을 위한 음수 ImageRectSize가
-- 전혀 필요 없다(모든 ImageRectOffset/ImageRectSize가 항상 양수) — 그 버그의
-- 트리거 조건 자체가 없다.
--
-- (실측 이력 2) 원본 시트(idle 3840x2160, jump/run 4480x1800)를 그대로 업로드했더니
-- 캐릭터가 여러 개로 쪼개져 보였다 — 로블록스 이미지 업로드는 1024x1024가 사실상
-- 상한이라 그보다 큰 이미지는 업로드 시 자동으로 축소되는데, 우리가 계산한 크롭
-- 좌표(px)는 원본 해상도 기준이라 축소된 실제 서빙 이미지와 어긋나 있었다. 그래서
-- 6장 전부 1024 이하로(896x360, 1/5 배율) 리사이즈해서 다시 올렸다 — 셀 크기도
-- 128x72로 같이 줄었다.
--
-- 그리드는 셀 128x72(6장 모두 동일), 읽는 순서는 왼쪽→오른쪽, 그 줄 다 읽으면
-- 다음 줄(행 우선) — GIF 원본과 셀별로 대조해서 확인했다. idle/jump/run 전부
-- 7x5=35칸으로 통일되어 있다. 원본 애니메이션은 36프레임인데 첫 프레임(정지
-- 포즈로 추정)이 시트에서 빠져 있다 — 셀 1번이 원본 2번째 프레임부터 시작한다.
-- 이 프로젝트가 우리 자체 프레임 번호만 쓰므로(원본 번호를 참조할 일이 없음) 그냥
-- 35칸을 순서대로 재생하면 된다.
--
-- jump는 이 팩에 상승/하강이 분리된 별도 아트가 없어서(fall 시트 없음), 상승부터
-- 하강까지 35프레임 전체를 한 번에 잇는 애니메이션으로 재생한다 — LOOPING.jump=false
-- 라 재생이 끝나면 마지막(착지 직전 포즈) 프레임에서 멈춰 실제로 착지할 때까지
-- 유지된다.
--
-- 애니메이션은 엔진 기본 SetSpriteSheet/Play() 자동 시스템(idle_left/right, left/right
-- 4개 이름만 지원) 대신 직접 Heartbeat에서 Position 변화를 보고 idle/run/jump를
-- 고른다. 이동/점프/중력 물리 판정은 CrossPlatformService(SetPlayerCharacter)에
-- 그대로 맡긴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local CELL = Vector2.new(128, 72)
local DISPLAY_SCALE = 90 / CELL.Y -- 캐릭터 크기 축소 요청: 실측 높이 117.6px -> 90px
local RUN_SPEED_THRESHOLD = 20
local AIR_SPEED_THRESHOLD = 90
local SPAWN_POSITION = UDim2.fromOffset(0, 0)

-- 상태+방향당 시트 이미지 하나. 프레임 전환은 ImageRectOffset만 바꾼다(재다운로드 없음).
local SHEETS = {
	idle_left = "rbxassetid://95889205116414",
	idle_right = "rbxassetid://128191018293807",
	jump_left = "rbxassetid://128031828795179",
	jump_right = "rbxassetid://89346281016673",
	run_left = "rbxassetid://138593483530939",
	run_right = "rbxassetid://140173495359769",
}

-- 상태+방향별 그리드: cols(한 줄에 몇 칸), frames(총 프레임 수). 셀 크기는 6장 전부
-- CELL(128x72)로 통일. run만 loopStart/loopEnd가 따로 있다 — 도입부(가속)를 한 번
-- 재생한 뒤 실제 반복 구간만 계속 도는데, 이 반복 구간을 "몇 번째 줄"처럼 눈대중으로
-- 추측하지 않고 원본 GIF 36프레임 전체를 프레임간 픽셀 차이로 분석해서 실제로 자세가
-- 10프레임 주기로 되풀이되는 구간을 직접 찾았다(예: right는 15번째~24번째 GIF
-- 프레임이 25번째~34번째와 거의 동일 — 10프레임 주기). 우리 셀 번호는 GIF 프레임
-- 번호보다 1 작으므로(셀1=GIF프레임2) 그만큼 보정해서 넣었다. left/right가 완전히
-- 대칭으로 그려진 게 아니라 주기 구간이 서로 다르다 — left는 12~22번째 GIF 프레임,
-- right는 15~24번째 GIF 프레임에서 반복된다.
local GRID = {
	idle_left = { cols = 7, frames = 35 },
	idle_right = { cols = 7, frames = 35 },
	jump_left = { cols = 7, frames = 35 },
	jump_right = { cols = 7, frames = 35 },
	run_left = { cols = 7, frames = 35, loopStart = 11, loopEnd = 21 }, -- GIF 프레임 12~22
	run_right = { cols = 7, frames = 35, loopStart = 14, loopEnd = 23 }, -- GIF 프레임 15~24
}

-- idle: 35장 * 1/12s ≈ 2.9s/루프.
-- run: 도입부 재생 후 실측으로 찾은 반복 구간(약 10~11장)을 계속 반복 — 10장 * 1/35s
--      ≈ 0.29s/사이클.
-- jump: 상승+하강 35장을 한 번에 잇는 시퀀스라 전체 공중 체공을 커버해야 함 —
--       35장 * 1/30s ≈ 1.17s. LOOPING=false라 재생이 끝나면 마지막 프레임에서
--       멈춰 착지까지 유지된다.
local SECONDS_PER_FRAME = {
	idle = 1 / 12,
	jump = 1 / 30,
	run = 1 / 35,
}
local LOOPING = { idle = true, jump = false, run = true }

local exports = {}

-- hero.IsGrounded와 hero.Velocity.Y 둘 다 신뢰할 수 없다(실측 확인: Position.Y가
-- 소수점까지 완전히 고정된 채 가만히 서 있는 동안에도 IsGrounded가 수백 ms 단위로
-- true/false를 오가고, 그때 Velocity.Y도 AIR_SPEED_THRESHOLD를 넘나든다). 그래서
-- 실제로 화면에 보이는 유일한 진실인 Position.Y 자체가 최근 POSITION_WINDOW 동안
-- 얼마나 움직였는지로 "진짜 속도"를 직접 계산해서 쓴다.
local POSITION_WINDOW = 0.12

local ContentProvider = game:GetService("ContentProvider")

local function preloadAllFrames()
	local ids = {}
	for _, id in SHEETS do
		table.insert(ids, id)
	end
	ContentProvider:PreloadAsync(ids)
end

function exports.load(scene: Scene)
	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero.Anchored = false
	-- 캔버스(300x420)에 세이프 마진(28/39px)이 커서 실제 그림은 그보다 작다 — 실측 후 조정 예정.
	hero.HitboxScale = 0.28
	hero.WalkSpeed = 80
	hero.JumpPower = 150 -- 기본값

	local instance = hero.Instance
	instance.AnchorPoint = Vector2.new(0.5, 1) -- 발밑 중앙 기준(바닥에 닿는 지점 고정)
	-- ScaleType 기본값은 Tile이다 — 이전엔 ImageRectSize가 항상 Vector2.zero(크롭 없음)라
	-- 안 드러났지만, 지금처럼 실제로 640x360 하위 영역을 크롭해서 쓰면 그 조각을 작은
	-- Size 박스 안에 원본 픽셀 크기 그대로 반복 타일링해버린다(캐릭터가 여러 개로
	-- 겹쳐 보이는 원인). Stretch로 명시해서 크롭된 한 프레임을 Size 박스에 맞게 늘린다.
	instance.ScaleType = Enum.ScaleType.Stretch
	instance.Image = SHEETS.idle_right
	instance.Position = SPAWN_POSITION
	instance.Size = UDim2.fromOffset(CELL.X * DISPLAY_SCALE, CELL.Y * DISPLAY_SCALE)
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.zero
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	CrossPlatformService.SideView = true
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local hero = exports.hero
	if not hero then
		return
	end

	-- setup.run()은 모든 모듈의 load/start를 한 스레드에서 순차 호출한다(setup.luau
	-- 참고). preloadAllFrames()를 여기서 그냥 부르면 다 받을 때까지 exports.start()
	-- 자체가 안 끝나서, 뒤이어 호출될 다른 모듈(camera 등)의 start()까지 전부 밀린다.
	-- task.spawn으로 감싸서 exports.start()는 즉시 리턴하게 하고, 프리로드와
	-- Heartbeat 연결은 백그라운드에서 이어서 진행한다(이제 에셋이 6개뿐이라 거의
	-- 즉시 끝난다).
	task.spawn(function()
		preloadAllFrames()

		local facing = "right"
		local currentState = "idle"
		local currentFrame = 1
		local frameClock = 0
		local elapsed = 0
		local yHistory = {} -- {t, y} 샘플들, 최근 POSITION_WINDOW초 분량만 유지

		-- 포물선 정점에서는 estimatedVelocityY가 순간적으로 0 근처를 지나간다. 매 프레임
		-- 속도만으로 상태를 다시 판단하면 정점에서 "착지했다"고 착각해 idle/run으로
		-- 빠졌다가 다시 jump로 튕겨 들어오면서 currentFrame이 1로 리셋되기를 반복한다.
		-- 그래서 "떴다/착지했다"는 순간 속도가 아니라 grounded라는 상태를 따로 든다.
		--
		-- (실측 버그 이력) 착지 판정을 "이륙 직전 높이로 정확히 돌아왔는지"로 했더니,
		-- 실제 물리 정착 위치가 그 높이와 몇 px만 달라도(반복 점프 중 흔함) grounded가
		-- 영원히 false로 남아 마지막 프레임에 고정되는 버그가 있었다. 착지는 절대
		-- 높이가 아니라 "수직으로 실제로 멈췄는지"로 판정한다 — 이미 신뢰성이 검증된
		-- Position 기반 estimatedVelocityY를 재사용: 하강 중(phaseFall) 속도가
		-- SETTLE_THRESHOLD 밑으로 떨어지면 착지. 정점을 막 지난 시점도 속도가 잠깐 0
		-- 근처를 지나가므로, 하강 시작 후 최소 MIN_FALL_DURATION이 지나기 전에는
		-- 착지 판정을 하지 않아 정점과 착지를 구분한다.
		--
		-- phaseFall 자체는 이제 화면에 보이는 프레임에는 영향을 주지 않는다(jump
		-- 시트 하나가 상승+하강을 전부 담당) — 착지 오판을 막는 내부 게이팅 용도로만
		-- 쓴다.
		local SETTLE_THRESHOLD = 10
		local MIN_FALL_DURATION = 0.15
		local grounded = true
		local phaseFall = false
		local fallStartTime = 0

		local function stateFor(moving: boolean, estimatedVelocityY: number, currentTime: number): string
			if grounded then
				if estimatedVelocityY < -AIR_SPEED_THRESHOLD then
					grounded = false
					phaseFall = false
				end
			else
				if not phaseFall and estimatedVelocityY > 0 then
					phaseFall = true
					fallStartTime = currentTime
				end
				if
					phaseFall
					and currentTime - fallStartTime > MIN_FALL_DURATION
					and math.abs(estimatedVelocityY) < SETTLE_THRESHOLD
				then
					grounded = true
				end
			end

			if not grounded then
				return "jump"
			end

			if moving then
				return "run"
			end

			return "idle"
		end

		exports.connection = RunService.Heartbeat:Connect(function(delta)
			local instance = hero.Instance
			elapsed += delta
			if instance.Position.Y.Offset >= 1000 then
				hero.Velocity = Vector2.zero
				instance.Position = SPAWN_POSITION
				yHistory = {}
				grounded = true
				phaseFall = false
			end

			local currentY = instance.Position.Y.Offset
			table.insert(yHistory, { t = elapsed, y = currentY })
			while #yHistory > 1 and elapsed - yHistory[1].t > POSITION_WINDOW do
				table.remove(yHistory, 1)
			end

			local estimatedVelocityY = 0
			local oldest = yHistory[1]
			local span = elapsed - oldest.t
			if span > 0 then
				estimatedVelocityY = (currentY - oldest.y) / span
			end

			local velocity = hero.Velocity or Vector2.zero
			local leftHeld = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
			local rightHeld = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)
			-- moving은 오직 "지금 이동 키가 눌려있는가"로만 정해야 한다. 예전엔 키를 뗀
			-- 뒤에도 관성으로 velocity.X가 잠깐 안 죽으면 이 값이 moving=true로 되살아나서
			-- (아래 facing 분기에서), 키를 놓아도 run 애니메이션이 감속이 끝날 때까지
			-- 계속 재생되는 버그가 있었다(run이 "끝까지 재생되고 나서야" idle로 바뀌는
			-- 것처럼 보임). facing만 속도로 보정하고 moving 자체는 건드리지 않는다.
			local moving = leftHeld ~= rightHeld

			if leftHeld and not rightHeld then
				facing = "left"
			elseif rightHeld and not leftHeld then
				facing = "right"
			elseif velocity.X < -RUN_SPEED_THRESHOLD then
				facing = "left"
			elseif velocity.X > RUN_SPEED_THRESHOLD then
				facing = "right"
			end

			local nextStateName = stateFor(moving, estimatedVelocityY, elapsed)
			if nextStateName ~= currentState then
				currentState = nextStateName
				currentFrame = 1
				frameClock = 0
			else
				frameClock += delta
				while frameClock >= SECONDS_PER_FRAME[currentState] do
					frameClock -= SECONDS_PER_FRAME[currentState]
					currentFrame += 1
				end
			end

			local grid = GRID[currentState .. "_" .. facing]
			local loopEnd = grid.loopEnd or grid.frames
			local loopStart = grid.loopStart or 1
			if currentFrame > loopEnd then
				currentFrame = if LOOPING[currentState] then loopStart else loopEnd
			end

			local col = (currentFrame - 1) % grid.cols
			local row = (currentFrame - 1) // grid.cols

			instance.Image = SHEETS[currentState .. "_" .. facing]
			instance.ImageRectSize = CELL
			instance.ImageRectOffset = Vector2.new(col * CELL.X, row * CELL.Y)
		end)
	end)
end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	exports.hero = nil
end

return exports
