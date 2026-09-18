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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))

local sceneBootstrap = require(script.Parent.sceneBootstrap)
local heroTracking = require(script.Parent.heroTracking)

local SCENE_NAME = "Backfield"
local MARKER_PREFIX = "Monster_SproutGrub"

local CELL = Vector2.new(192, 108)
local DISPLAY_SCALE = 60 / CELL.Y -- 요청으로 축소(90 -> 60).

-- (실측 이력) 순찰 범위를 150px 고정값으로 뒀더니, 마커가 놓인 발판보다 넓게 왕복해서
-- 발판을 벗어나 허공을 걷는 것처럼 보이는 경우가 있었다. 고정값 대신 마커 자체의 가로
-- 폭을 순찰 범위로 쓴다 — 레벨 디자이너가 마커 박스를 발판 폭에 맞게 늘려두면 그 안에서만
-- 왕복하고, 마커가 기본 크기(폭이 아주 작음)면 사실상 거의 제자리에 가깝게 된다.
local PATROL_RANGE_FALLBACK = 80 -- 마커 폭이 0에 가까울 때(점 마커) 쓰는 최소 순찰 범위.
local PATROL_SPEED = 70 -- px/s(기존 150은 너무 빨랐다).
local AGGRO_RANGE = 220 -- 이 거리 안에 플레이어가 들어오면 공격 상태로 전환.
local MONSTER_ATTACK_RANGE = 130 -- 몬스터 자신의 공격이 실제로 닿는 거리(AGGRO_RANGE보다 좁음).

-- (요청 반영) 기본공격 판정을 "캐릭터 중심 기준 원형"이 아니라 "바라보는 방향 앞쪽"으로
-- 바꾼다 — 애니메이션에서 눈에 보이는 칼 길이보다 살짝 더 앞까지 닿게(ATTACK_RANGE_FRONT),
-- 뒤쪽은 거의 안 닿게(ATTACK_RANGE_BACK, 약간의 여유만 둠 — 몬스터가 발밑에 걸쳐 있는
-- 정도는 맞아야 하니까) 만든다.
local ATTACK_RANGE_FRONT = 170
local ATTACK_RANGE_BACK = 20
-- (실측 버그 이력) Y축 제한이 아예 없어서 1층에서 휘두른 공격이 2층 발판 몬스터까지
-- 맞아버렸다 — 좌우 판정과 별개로 수직으로도 캐릭터 키 정도의 좁은 범위만 닿게 한다.
local ATTACK_RANGE_VERTICAL = 70

local MONSTER_MAX_HEALTH = 30 -- 약한 잡몹이라 플레이어 기본공격 몇 대면 죽는다.
local PLAYER_ATTACK_DAMAGE = 10
local MONSTER_ATTACK_DAMAGE = 5
-- (Phase 1 전투 타격감, ROADMAP.md) 클라이언트가 임팩트 프레임 "구간" 동안 매 프레임
-- 공격을 신고하므로(heroController.luau의 ATTACK_IMPACT_WINDOW_FRAMES), 같은 스윙에서
-- 중복 신고가 들어와도 이 시간 안이면 데미지를 한 번만 적용한다. 다음 스윙 주기보다는
-- 훨씬 짧게 잡아야 진짜 다음 공격이 막히지 않는다.
local HIT_COOLDOWN = 0.2
local KNOCKBACK_DISTANCE = 18 -- px, 맞은 반대 방향으로 즉시 밀려나는 거리.

local DEATH_FADE_DURATION = 0.5 -- 죽을 때 점점 희미해지는 시간(초).
local RESPAWN_DELAY_MIN = 3
local RESPAWN_DELAY_MAX = 4

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
-- (실측 버그 이력, OpenMMO github.com/Julian-adv/OpenMMO의 COMBAT.md 참고) 판정을
-- 스윙 사이클이 "끝나는" 시점에 신고했더니, 실제로 몬스터가 팔을 휘두르는 것처럼 보이는
-- 시점(애니메이션 중간)과 플레이어가 맞았다는 신호/데미지 숫자가 뜨는 시점(애니메이션
-- 끝)이 완전히 어긋나 보였다. 전체 35프레임의 약 40% 지점("임팩트 프레임")으로 옮긴다.
local MONSTER_ATTACK_IMPACT_FRAME = 14

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
	-- Character.new() 기본값(100/100)은 플레이어 기준이라 잡몹치고 너무 튼튼하다.
	monster.MaxHealth = MONSTER_MAX_HEALTH
	monster.Health = MONSTER_MAX_HEALTH
	-- 이 값 자체는 게임 로직에 안 쓰인다 — 순전히 클라이언트가 리플리케이트된 오브젝트
	-- 중에 "이건 몬스터다"를 구분하기 위한 표식이다(globals/monsterHealthBar.luau가
	-- 체력바를 붙일 대상을 찾을 때 이 필드를 본다). 일반 필드라 다른 필드들과 동일하게
	-- 자동으로 복제된다.
	monster.MonsterKind = "SproutGrub"

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
		impactFired = false,
	}
end

local function updateMonster(state, delta: number)
	local instance = state.monster.Instance
	local monsterX = instance.Position.X.Offset

	-- 접속한 모든 플레이어 중 가장 가까운 사람 기준으로 어그로/방향/공격 대상을 정한다.
	local nearestDistance = nil
	local nearestX = nil
	local nearestUserId = nil
	for userId, position in heroTracking.GetPositions() do
		local distance = math.abs(monsterX - position.X)
		if not nearestDistance or distance < nearestDistance then
			nearestDistance = distance
			nearestX = position.X
			nearestUserId = userId
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
		if nextStateName == "attack" then
			state.impactFired = false
		end
	else
		state.frameClock += delta
		while state.frameClock >= SECONDS_PER_FRAME[state.currentState] do
			state.frameClock -= SECONDS_PER_FRAME[state.currentState]
			state.currentFrame += 1
		end
	end

	-- OpenMMO 방식(위 MONSTER_ATTACK_IMPACT_FRAME 주석 참고): 판정은 사이클이 끝날 때가
	-- 아니라 스윙 중간의 "임팩트 프레임"에서, 사이클당 딱 한 번만 신고한다.
	if
		state.currentState == "attack"
		and not state.impactFired
		and state.currentFrame >= MONSTER_ATTACK_IMPACT_FRAME
		and nearestUserId
		and nearestDistance
		and nearestDistance <= MONSTER_ATTACK_RANGE
	then
		state.impactFired = true
		local player = Players:GetPlayerByUserId(nearestUserId)
		if player then
			heroTracking.NotifyPlayerHit(player, MONSTER_ATTACK_DAMAGE, monsterX)
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
		elseif state.currentState == "attack" then
			-- 다음 사이클(계속 공격 중이면 바로 이어짐)의 임팩트 판정을 다시 받을 수
			-- 있게 리셋.
			state.impactFired = false
		end
	end

	local col = (state.currentFrame - 1) % grid.cols
	local row = (state.currentFrame - 1) // grid.cols

	instance.Image = SHEETS[state.currentState .. "_" .. state.facing]
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.new(col * CELL.X, row * CELL.Y)
end

-- 마커 하나 = "스포너" 하나. 스포너는 마커 자리에 고정된 채로 계속 남아있고, 그 안의
-- .state가 "지금 살아있는 몬스터"를 가리킨다 — 죽으면 .state가 nil이 되고
-- respawnTimer가 다 돌 때까지 기다렸다가 같은 자리에 새 몬스터를 다시 만든다.
local function spawnMonster(spawner)
	local monster = createMonster(spawner.scene, spawner.spawnPosition)
	local state = newMonsterState(monster, spawner.spawnPosition.X.Offset, spawner.patrolRange)

	-- Character.luau의 UpdateHealth()는 Health가 0 이하로 내려가는 순간 "Died"를 딱
	-- 한 번 쏴준다 — 그 즉시 지우는 대신 dying 플래그만 켜서, 아래 Heartbeat에서
	-- DEATH_FADE_DURATION에 걸쳐 서서히 투명해지게 한 뒤에 실제로 없앤다.
	monster:On("Died", function()
		state.dying = true
		state.deathClock = 0
	end)

	spawner.state = state
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

	exports.spawners = {}
	for _, marker in markers do
		local spawnPosition = marker.Instance.Position
		-- 마커 폭의 절반을 순찰 범위로 쓴다(스폰 지점 기준 좌우 대칭이라 절반). 마커
		-- 폭이 거의 0(점 마커)이면 최소값으로 대체한다.
		local markerWidth = marker.Instance.Size.X.Offset
		local patrolRange = math.max(markerWidth / 2, PATROL_RANGE_FALLBACK)

		local spawner = { scene = scene, spawnPosition = spawnPosition, patrolRange = patrolRange }
		spawnMonster(spawner)
		table.insert(exports.spawners, spawner)
	end
end

function exports.start()
	local spawners = exports.spawners
	if not spawners or #spawners == 0 then
		return
	end

	heroTracking.OnAttack(function(_player, attackX, attackY, facing)
		for _, spawner in spawners do
			local state = spawner.state
			if not state or state.dying then
				continue
			end

			local monsterInstance = state.monster.Instance

			-- 캐릭터 중심 기준 원형 판정이 아니라 "바라보는 방향 앞쪽" 판정 — 위
			-- ATTACK_RANGE_FRONT/BACK 주석 참고.
			local dx = monsterInstance.Position.X.Offset - attackX
			local inRangeX = if facing == "left"
				then dx <= ATTACK_RANGE_BACK and dx >= -ATTACK_RANGE_FRONT
				else dx >= -ATTACK_RANGE_BACK and dx <= ATTACK_RANGE_FRONT

			local dy = math.abs(monsterInstance.Position.Y.Offset - attackY)
			local inRange = inRangeX and dy <= ATTACK_RANGE_VERTICAL

			-- 클라이언트가 임팩트 프레임 "구간"(heroController.luau의
			-- ATTACK_IMPACT_WINDOW_FRAMES) 동안 매 프레임 신고하므로, 같은 스윙에서 여러
			-- 번 들어올 수 있다 — 짧은 쿨다운으로 한 스윙당 한 번만 데미지가 들어가게
			-- 걸러낸다(다음 스윙 주기(약 1초 이상)보다 훨씬 짧아서 진짜 다음 공격은
			-- 그대로 통과한다).
			local now = os.clock()
			if inRange and (not state.hitCooldownUntil or now >= state.hitCooldownUntil) then
				state.hitCooldownUntil = now + HIT_COOLDOWN
				state.hitActive = true
				local monster = state.monster
				monster:UpdateHealth(math.max(monster.Health - PLAYER_ATTACK_DAMAGE, 0))
				-- Phase 1 전투 타격감(ROADMAP.md) — 맞은 반대 방향으로 살짝 밀려나는 넉백.
				-- 물리를 안 쓰는 몬스터라(위 "엔진 제약" 참고) 속도가 아니라 좌표를
				-- 그냥 즉시 더한다.
				local knockDirection = if dx >= 0 then 1 else -1
				monsterInstance.Position += UDim2.fromOffset(knockDirection * KNOCKBACK_DISTANCE, 0)
			end
		end
	end)

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		for _, spawner in spawners do
			local state = spawner.state

			if not state then
				-- 죽어서 사라진 뒤 리스폰 대기 중.
				spawner.respawnTimer -= delta
				if spawner.respawnTimer <= 0 then
					spawnMonster(spawner)
				end
				continue
			end

			if state.dying then
				state.deathClock += delta
				local alpha = math.clamp(state.deathClock / DEATH_FADE_DURATION, 0, 1)
				state.monster.Instance.ImageTransparency = alpha
				if alpha >= 1 then
					-- (실측 버그 이력) Destroy()는 서버 쪽 Lua 오브젝트만 지운다 — 클라이언트가
					-- 리플리케이트해서 만들어둔 사본은 아무 신호도 못 받고 그대로(체력바
					-- 포함) 남는다. Destroy 전에 Id를 먼저 받아두고(Destroy가
					-- table.clear로 필드를 지워버리므로 순서 중요) 모든 클라이언트에
					-- "이 Id는 없앨 것"이라고 알린 뒤에 실제로 지운다.
					local monsterId = state.monster.Id
					heroTracking.NotifyMonsterDespawned(monsterId)
					state.monster:Destroy()
					spawner.state = nil
					spawner.respawnTimer = RESPAWN_DELAY_MIN + math.random() * (RESPAWN_DELAY_MAX - RESPAWN_DELAY_MIN)
				end
				continue
			end

			updateMonster(state, delta)
		end
	end)
end

function exports.unload()
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	if exports.spawners then
		for _, spawner in exports.spawners do
			if spawner.state then
				spawner.state.monster:Destroy()
			end
		end
		exports.spawners = nil
	end
end

return exports
