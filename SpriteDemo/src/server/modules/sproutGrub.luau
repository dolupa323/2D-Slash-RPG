-- 첫 몬스터 "Sprout Grub"의 서버 권위(server-authoritative) 구현. 공식 문서
-- (Replication Guide - Authority System / How It Works)의 NPC 패턴을 그대로 따른다:
-- "Server objects replicate to clients automatically by default - no ReplicateOnChange()
-- needed! Server can move NPC, clients just see updates." 서버가 여기서 만들고 움직이면,
-- 별도 복제 호출 없이 자동으로 모든 클라이언트에 복제된다.
--
-- (이전 시도 이력) 원래는 클라이언트마다 각자 자기 몬스터를 만드는 구조
-- (heroController.luau와 같은 client-authoritative 패턴)로 만들었었다 — 이건 "각자 자기
-- 캐릭터를 조작하는" 플레이어 캐릭터에는 맞는 패턴이지만, "모두가 똑같은 하나를 봐야
-- 하는" 몬스터에는 처음부터 잘못된 패턴이었다. 그 구조에서 Velocity로 이동이 안 되는
-- 문제를 오래 팠었는데, 그것도 결국 이 구조적 문제 위에서 헤맨 것이었다.
--
-- (엔진 제약) 이 엔진의 Position 기반 2D 물리(Runtime/EveryStep/Physics.luau)는
-- Roblox의 AbsolutePosition/AbsoluteSize(실제 화면 렌더링 결과)에 의존하는데, 서버는
-- 렌더링 파이프라인이 없어서 이 값들이 항상 (0,0)이다 — 서버에서는 중력/충돌 판정
-- 자체가 의미가 없다. 그래서 이 몬스터는 Anchored=true로 엔진 물리를 아예 끄고,
-- 좌우 이동을 매 프레임 Position에 직접 더하는 방식으로만 구현한다. 수직 이동(점프/
-- 낙하)이 없는 몬스터라 Y는 마커 좌표를 그대로 고정해서 쓴다 — 마커는 반드시 발밑
-- 위치(캐릭터가 서 있을 지면 높이)에 정확히 놓여 있어야 한다.
--
-- (메이플스토리식 사냥터 구조) 사냥터 하나에 스폰 지점이 여러 개 있고, 각 지점이 각자
-- 몬스터 한 마리씩을 담당해서 그 주변만 순찰한다 — 맵 전체를 몬스터 한 마리가 돌아다니는
-- 게 아니다. 그래서 마커는 "Monster_SproutGrub"로 시작하는 이름이면 전부 인식한다
-- (예: "Monster_SproutGrub1", "Monster_SproutGrub2", ... 뒤에 번호/구분자는 자유 —
-- 접두사만 같으면 됨). 마커 개수만큼 몬스터가 각각 독립적으로 스폰되고, 서로 다른
-- 순찰 범위/어그로/피격 상태를 갖는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))

local sceneBootstrap = require(script.Parent.sceneBootstrap)
local heroTracking = require(script.Parent.heroTracking)

local SCENE_NAME = "Backfield"
local MARKER_PREFIX = "Monster_SproutGrub"

local CELL = Vector2.new(192, 108)
local DISPLAY_SCALE = 46 / CELL.Y -- 플레이어(105px)보다 작은 잔몹 크기(70 -> 46으로 축소).

-- (실측 이력) 순찰 범위를 150px 고정값으로 뒀더니, 마커가 놓인 발판보다 넓게 왕복해서
-- 발판을 벗어나 허공을 걷는 것처럼 보이는 경우가 있었다. 고정값 대신 마커 자체의 가로
-- 폭을 순찰 범위로 쓴다 — 레벨 디자이너가 마커 박스를 발판 폭에 맞게 늘려두면 그 안에서만
-- 왕복하고, 마커가 기본 크기(폭이 아주 작음)면 사실상 거의 제자리에 가깝게 된다.
local PATROL_RANGE_FALLBACK = 80 -- 마커 폭이 0에 가까울 때(점 마커) 쓰는 최소 순찰 범위.
local PATROL_SPEED = 70 -- px/s(기존 150은 너무 빨랐다).
local AGGRO_RANGE = 220 -- 이 거리 안에 플레이어가 들어오면 공격 상태로 전환.
local HIT_RANGE = 140 -- 플레이어 기본공격이 이 거리 안에서 신고돼야 맞는 걸로 친다.

-- 상태+방향당 시트 이미지. client/modules/heroController.luau가 이미 검증한 것과 동일한
-- 방식(리사이즈/그리드)으로 만들어 올렸다 — Source:
-- Assets/character/talchar/three/monster/Sprout Grub/{walk,attack,hit}_{left,right}.png
local SHEETS = {
	walk_left = "rbxassetid://92264999271413",
	walk_right = "rbxassetid://100223635620373",
	attack_left = "rbxassetid://98419651702250",
	attack_right = "rbxassetid://93586067969223",
	hit_left = "rbxassetid://107018587663153",
	hit_right = "rbxassetid://121503629119574",
}

local GRID = {
	walk_left = { cols = 5, frames = 35 },
	walk_right = { cols = 5, frames = 35 },
	attack_left = { cols = 5, frames = 35 },
	attack_right = { cols = 5, frames = 35 },
	-- hit는 충격 이펙트+표정 변화가 대략 12프레임 안에 다 끝나고 나머지는 원본
	-- 시트에서 같은 포즈가 반복되는 padding이라 12에서 끊는다.
	hit_left = { cols = 5, frames = 35, loopEnd = 12 },
	hit_right = { cols = 5, frames = 35, loopEnd = 12 },
}

local SECONDS_PER_FRAME = {
	walk = 1 / 12,
	attack = 1 / 24,
	hit = 1 / 20,
}
local LOOPING = { walk = true, attack = true, hit = false }

local exports = {}

-- 이 씬의 마커란 마커는 전부 찾는다(이름이 MARKER_PREFIX로 "시작"하기만 하면 됨).
local function findMarkers(scene: Scene)
	local markers = {}
	for _, object in scene.Objects do
		if object.Instance and object.Name:sub(1, #MARKER_PREFIX) == MARKER_PREFIX then
			table.insert(markers, object)
		end
	end
	return markers
end

local function createMonster(scene: Scene, spawnPosition: UDim2)
	local monster = UpsideEngine.new("Character")
	monster:SetScene(scene)
	-- 위 "엔진 제약" 설명 참고 — 서버 물리는 의미가 없으므로 아예 꺼서, 우리가 매 프레임
	-- 계산하는 Position을 엔진이 건드리지 못하게 한다.
	monster.Anchored = true
	monster.HitboxScale = 0.28
	-- 플레이어가 이 몬스터에 물리적으로 부딪혀서 밀리거나 막히면 안 된다 — 어그로/
	-- 히트 판정은 전부 순수 좌표 거리 계산(heroTracking 위치 신고 기반)이라 CanCollide랑
	-- 무관하게 그대로 작동한다. CanCollide는 Instance 속성이 아니라 오브젝트 필드라
	-- ObjectProperties로 그대로 복제되므로, 클라이언트에서도 동일하게 충돌이 꺼진다.
	monster.CanCollide = false

	local instance = monster.Instance
	instance.AnchorPoint = Vector2.new(0.5, 1)
	instance.ScaleType = Enum.ScaleType.Stretch
	instance.Image = SHEETS.walk_right
	instance.Position = spawnPosition
	instance.Size = UDim2.fromOffset(CELL.X * DISPLAY_SCALE, CELL.Y * DISPLAY_SCALE)
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.zero
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 9 -- 히어로(10)보다 한 칸 아래 — 겹칠 때 플레이어가 위로 보이게.

	return monster
end

-- 몬스터 한 마리치 상태(순찰 방향/애니메이션 프레임 등)를 한데 묶는다 — 마커가 여러
-- 개면 이 테이블도 여러 개 생겨서 서로 완전히 독립적으로 움직인다.
local function newMonsterState(monster, spawnX: number, patrolRange: number)
	return {
		monster = monster,
		spawnX = spawnX,
		patrolRange = patrolRange,
		patrolDirection = 1,
		facing = "right",
		currentState = "walk",
		currentFrame = 1,
		frameClock = 0,
		hitActive = false,
	}
end

local function updateMonster(state, delta: number)
	local instance = state.monster.Instance
	local monsterX = instance.Position.X.Offset

	-- 접속한 모든 플레이어 중 가장 가까운 사람 기준으로 어그로/방향을 정한다.
	local nearestDistance = nil
	local nearestX = nil
	for _, position in heroTracking.GetPositions() do
		local distance = math.abs(monsterX - position.X)
		if not nearestDistance or distance < nearestDistance then
			nearestDistance = distance
			nearestX = position.X
		end
	end

	local aggro = nearestDistance ~= nil and nearestDistance <= AGGRO_RANGE

	if state.hitActive or aggro then
		-- 공격/피격 중에는 제자리.
		if nearestX then
			state.facing = if nearestX > monsterX then "right" else "left"
		end
	else
		if monsterX - state.spawnX >= state.patrolRange then
			state.patrolDirection = -1
		elseif monsterX - state.spawnX <= -state.patrolRange then
			state.patrolDirection = 1
		end
		instance.Position += UDim2.fromOffset(state.patrolDirection * PATROL_SPEED * delta, 0)
		state.facing = if state.patrolDirection > 0 then "right" else "left"
	end

	local nextStateName = if aggro then "attack" else "walk"
	if state.hitActive then
		nextStateName = "hit"
	end

	if nextStateName ~= state.currentState then
		state.currentState = nextStateName
		state.currentFrame = 1
		state.frameClock = 0
	else
		state.frameClock += delta
		while state.frameClock >= SECONDS_PER_FRAME[state.currentState] do
			state.frameClock -= SECONDS_PER_FRAME[state.currentState]
			state.currentFrame += 1
		end
	end

	local grid = GRID[state.currentState .. "_" .. state.facing]
	local loopEnd = grid.loopEnd or grid.frames
	local loopStart = grid.loopStart or 1
	if state.currentFrame > loopEnd then
		state.currentFrame = if LOOPING[state.currentState] then loopStart else loopEnd
		if state.currentState == "hit" then
			-- 한 번 다 재생됐으니 오버레이 해제 — 다음 프레임에 순찰/공격 중 실제
			-- 상황에 맞는 상태로 복귀한다.
			state.hitActive = false
		end
	end

	local col = (state.currentFrame - 1) % grid.cols
	local row = (state.currentFrame - 1) // grid.cols

	instance.Image = SHEETS[state.currentState .. "_" .. state.facing]
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.new(col * CELL.X, row * CELL.Y)
end

function exports.load()
	local scene = sceneBootstrap.GetScene(SCENE_NAME)
	if not scene then
		warn(('sproutGrub(server): "%s" 씬을 찾을 수 없습니다.'):format(SCENE_NAME))
		return
	end

	local markers = findMarkers(scene)
	if #markers == 0 then
		-- 이 씬에는 이 몬스터가 없다(예: village) — 조용히 넘어간다.
		return
	end

	exports.monsterStates = {}
	for _, marker in markers do
		local spawnPosition = marker.Instance.Position
		local monster = createMonster(scene, spawnPosition)
		-- 마커 폭의 절반을 순찰 범위로 쓴다(스폰 지점 기준 좌우 대칭이라 절반). 마커
		-- 폭이 거의 0(점 마커)이면 최소값으로 대체한다.
		local markerWidth = marker.Instance.Size.X.Offset
		local patrolRange = math.max(markerWidth / 2, PATROL_RANGE_FALLBACK)
		table.insert(exports.monsterStates, newMonsterState(monster, spawnPosition.X.Offset, patrolRange))
	end
end

function exports.start()
	local monsterStates = exports.monsterStates
	if not monsterStates or #monsterStates == 0 then
		return
	end

	heroTracking.OnAttack(function(_player, attackX, _attackY)
		for _, state in monsterStates do
			local distance = math.abs(state.monster.Instance.Position.X.Offset - attackX)
			if distance <= HIT_RANGE then
				state.hitActive = true
			end
		end
	end)

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		for _, state in monsterStates do
			updateMonster(state, delta)
		end
	end)
end

function exports.unload()
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	if exports.monsterStates then
		for _, state in exports.monsterStates do
			state.monster:Destroy()
		end
		exports.monsterStates = nil
	end
end

return exports
