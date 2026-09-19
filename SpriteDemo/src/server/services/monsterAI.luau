-- 몬스터 AI 서비스(공용). shared/data/monsters.luau의 몬스터 정의 하나를 받아 그 종류의 서버 권위(server-authoritative)
-- 몬스터를 돌린다 — 스폰/순찰/어그로/공격/피격/사망/리스폰/드롭이 전부 이 코드 하나로 동작하고, 종류마다 다른 건 정의 데이터
-- (스탯, 스프라이트 시트, 판정 범위, 드롭 표 키)뿐이다. 새 몬스터는 정의를 추가하면 monsterSpawner가 자동으로 돌린다.
-- Ryzom의 AI 서비스 + creature sheet 구조에 해당한다.
--
-- 공식 문서(Replication Guide - Authority System / How It Works)의 NPC 패턴을 그대로 따른다: "Server objects replicate to
-- clients automatically by default - no ReplicateOnChange() needed! Server can move NPC, clients just see updates." 서버가
-- 만들고 움직이면 별도 복제 호출 없이 모든 클라이언트에 복제된다. (예전에 클라이언트마다 각자 몬스터를 만드는 구조를 시도했다가
-- "모두가 똑같은 하나를 봐야 하는" 몬스터에는 잘못된 패턴이라 서버 권위로 다시 만들었다.)
--
-- (엔진 제약) 이 엔진의 Position 기반 2D 물리(Runtime/EveryStep/Physics.luau)는 Roblox의 AbsolutePosition/AbsoluteSize(실제
-- 화면 렌더링 결과)에 의존하는데, 서버는 렌더링 파이프라인이 없어서 이 값들이 항상 (0,0)이다 — 서버에서는 중력/충돌 판정 자체가
-- 의미가 없다. 그래서 몬스터는 Anchored=true로 엔진 물리를 아예 끄고 좌우 이동을 매 프레임 Position에 직접 더한다. 수직 이동이
-- 없는 몬스터라 Y는 마커 좌표를 그대로 고정한다 — 마커는 반드시 발밑 위치(캐릭터가 서 있을 지면 높이)에 놓여 있어야 한다.
--
-- (메이플스토리식 사냥터 구조) 사냥터 하나에 스폰 지점이 여러 개 있고, 각 지점이 몬스터 한 마리씩 담당해서 그 주변만 순찰한다.
-- 마커는 정의의 MarkerPrefix(예: "Monster_SproutGrub")로 시작하는 이름이면 전부 인식한다(뒤의 번호/구분자는 자유).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))

local sceneBootstrap = require(script.Parent.Parent.modules.sceneBootstrap)
local heroTracking = require(script.Parent.Parent.modules.heroTracking)
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local progressionService = require(script.Parent.progressionService)
local inventoryService = require(script.Parent.inventoryService)
local lootService = require(script.Parent.lootService)
local lootTables = require(ReplicatedStorage.shared.data.lootTables)

local monsterAI = {}

-- typeName: shared/data/monsters.luau의 키(= lootTables의 키), DEF: 그 몬스터 정의. load/start/unload를 가진 인스턴스를 돌려준다.
function monsterAI.new(typeName: string, DEF)
	-- 이 몬스터 종류의 모든 수치/스프라이트/판정 범위는 shared/data/monsters.luau의 정의(DEF)에서 읽는다(코드에 하드코딩 X).
	local SCENE_NAME = DEF.Scene
	local MARKER_PREFIX = DEF.MarkerPrefix

	local CELL = DEF.Cell
	local DISPLAY_SCALE = DEF.DisplayHeight / CELL.Y

	local PATROL_RANGE_FALLBACK = DEF.PatrolRangeFallback
	local PATROL_SPEED = DEF.PatrolSpeed
	local AGGRO_RANGE = DEF.AggroRange
	local MONSTER_VERTICAL_RANGE = DEF.VerticalRange
	local MONSTER_ATTACK_RANGE = DEF.AttackRange

	local ATTACK_RANGE_FRONT = DEF.HitRangeFront
	local ATTACK_RANGE_BACK = DEF.HitRangeBack
	local ATTACK_RANGE_VERTICAL = DEF.HitRangeVertical

	local MONSTER_MAX_HEALTH = DEF.MaxHealth
	local MONSTER_ATTACK_DAMAGE = DEF.AttackDamage
	-- (Phase 1 전투 타격감) 클라이언트가 임팩트 프레임 "구간" 동안 매 프레임 공격을 신고하므로 같은 스윙의
	-- 중복 신고를 걸러내는 짧은 쿨다운. 다음 스윙 주기보다 훨씬 짧아야 진짜 다음 공격이 막히지 않는다.
	local HIT_COOLDOWN = 0.2
	local EXPERIENCE_REWARD = DEF.ExperienceReward
	local KNOCKBACK_DISTANCE = DEF.KnockbackDistance

	local DEATH_FADE_DURATION = DEF.DeathFadeDuration
	local RESPAWN_DELAY_MIN = DEF.RespawnDelayMin
	local RESPAWN_DELAY_MAX = DEF.RespawnDelayMax

	local SHEETS = DEF.Sheets
	local GRID = DEF.Grid
	local SECONDS_PER_FRAME = DEF.SecondsPerFrame
	local LOOPING = DEF.Looping
	local MONSTER_ATTACK_IMPACT_FRAME = DEF.AttackImpactFrame

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
		local monsterY = instance.Position.Y.Offset

		-- 접속한 모든 플레이어 중 가장 가까운 사람 기준으로 어그로/방향/공격 대상을 정한다.
		local nearestDistance = nil
		local nearestX = nil
		local nearestUserId = nil
		for userId, position in heroTracking.GetPositions() do
			if heroTracking.GetPlayerScene(userId) ~= SCENE_NAME then
				continue
			end
			-- (실측 버그 이력) 어그로/공격 대상을 X 거리만으로 골라서, 다른 층(발판)에 있는 플레이어도
			-- 바로 위/아래라는 이유로 몬스터에게 맞았다 — 세로로도 같은 층일 때만 대상으로 친다.
			if math.abs(monsterY - position.Y) > MONSTER_VERTICAL_RANGE then
				continue
			end
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
				progressionService.DamagePlayer(player, math.max(MONSTER_ATTACK_DAMAGE - inventoryService.GetDefense(player), 1))
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
			if state.lastAttacker and state.lastAttacker.Parent then
				progressionService.AddExperience(state.lastAttacker, EXPERIENCE_REWARD)
				lootService.RollLoot(state.lastAttacker, lootTables[typeName])
			end
			state.dying = true
			state.deathClock = 0
		end)

		spawner.state = state
	end

	function exports.load()
		local scene = sceneBootstrap.GetScene(SCENE_NAME)
		if not scene then
			warn(('monsterAI(%s): "%s" 씬을 찾을 수 없습니다.'):format(typeName, SCENE_NAME))
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

		heroTracking.OnAttack(function(player, attackX, attackY, facing)
			if heroTracking.GetPlayerScene(player.UserId) ~= SCENE_NAME then
				return
			end
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
					state.lastAttacker = player
					state.hitActive = true
					local monster = state.monster
					monster:UpdateHealth(math.max(monster.Health - inventoryService.GetAttackDamage(player), 0))
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
						-- (실측 버그 이력) 엔진은 서버 오브젝트의 복제 내용을 RequestsCache/Cache/PlayersData에 계속 남겨두고 Destroy()해도 지우지
						-- 않는다. 그래서 씬 이동 후 재동기화(ResyncClient) 때 이미 죽은 몬스터의 옛 내용이 다시 전송돼, 클라이언트에서 이미 Destroy된
						-- 사본에 Accept가 걸려 "attempt to index nil with 'match'"가 나거나 죽은 몬스터가 유령으로 되살아났다. 캐시에서 확실히 지운다.
						NetworkingService.RequestsCache[0][monsterId] = nil
						NetworkingService.Cache[monsterId] = nil
						NetworkingService.PlayersData[0][monsterId] = nil
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
end

return monsterAI
