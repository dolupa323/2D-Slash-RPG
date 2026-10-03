-- 탑다운 플레이어(닌자).
--
-- 그림: 「오문 닌자전」 — Ninja Adventure 팩 닌자(공방 tools/export_ninja.mjs). townAssets.PLAYER 시트 — 유파마다 4줄(아래·위·왼·오),
-- 칸 = 걷기 4장 + 기본 공격 4장, 칸 크기·발바닥 위치는 world.playerSheet(cellW · cellH · feetY).
-- 기본 공격: "Attack" 액션(PC F키 · HUD 공격 버튼 · 모바일도 같은 버튼) → 공격 애니메이션 → hitFrame번째 장에서
-- 서버에 바라보는 방향(TownAttack)을 보낸다 → 서버가 내 위치 앞 사각형(combat.luau의 ATTACK_REACH·ATTACK_WIDTH) 안의
-- 몬스터에게 데미지(같은 씬 모두에게 공유). 공격 중엔 멈춘다. 공격 동작 자체는 캐릭터 복제로 다른 사람에게도 보인다.
-- 이동: 엔진 물리(중력·충돌 클램프)는 쓰지 않는다(Anchored=true). 키 입력은 엔진
-- CrossPlatformService 이벤트(키보드 WASD/화살표, 모바일 방향 패드, 게임패드 전부 같은 액션)를
-- 받고, 위치는 여기서 직접 계산해서 town/map.luau의 충돌 격자에 걸리게 한다. 속도·발 상자는 공방 규칙 그대로.
-- 축별로 따로 움직여서 벽에 비스듬히 부딪혀도 미끄러지듯 따라간다.
-- 겹침: 발 높이가 클수록 앞(map.ZIndexFor) — 나무/집 뒤로 돌아가면 가려진다.
--
-- 씬 이동: 공방에서 놓은 포탈 칸에 발이 들어가면 서버에 이동을 요청하고(RequestTravel), 서버가 승인하면
-- (TravelApproved) 그 씬을 켠다. 도착 씬에서는 "출발 씬으로 돌아가는 포탈" 바로 아래에 나타나고,
-- 그런 포탈이 없으면 그 씬의 시작 위치(⭐)에 나타난다. 도착하자마자 다시 튕겨 가지 않게, 포탈 밖으로
-- 한 번 나갔다가 들어와야 다시 작동한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local SceneManager = UpsideEngine.GetService("SceneManager")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local Net = require(ReplicatedStorage.shared.net.net)
local map = require(script.Parent.town.map)
local travelState = require(script.Parent.travelState)
local loadingScreen = require(script.Parent.loadingScreen)
local combat = require(ReplicatedStorage.shared.config.combat)
local damageNumbers = require(script.Parent.damageNumbers)
local items = require(ReplicatedStorage.shared.data.items)
local weapons = require(ReplicatedStorage.shared.config.weapons)

local world = map.world
local S = map.S
local CS = townAssets.CHAR_SCALE -- 그림 크기 배율(위치는 바닥 배율 S)
local SHEET = world.playerSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local DIR_ROW = { down = 0, up = 1, left = 2, right = 3 }
local WALK_FRAMES = SHEET.walk -- 걷기 장수(칸 1..walk)
local ATTACK_FRAMES = SHEET.attack -- 공격 장수(칸 walk+1..)
local WALK_FRAME_TIME = 0.13
local SPEED = world.playerSpeed -- 도트/초
local FEET = world.playerFeet -- 발 상자(도트). 머리는 건물 앞 공간에 겹쳐도 되고 발만 막는다.
local TRAVEL_RETRY = 1.5 -- 승인이 안 오면 이 시간 뒤 다시 요청할 수 있다

local UserInputService = game:GetService("UserInputService")
local ninjutsuConfig = require(ReplicatedStorage.shared.config.ninjutsu)
local DASH_DIRS = { up = Vector2.new(0, -1), down = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }

local exports = {}

-- 유파(직업) 번호(0부터, world.schools 순서) — 시트에서 유파마다 4줄(아래·위·왼·오). globals/ninjutsu.luau가 내 유파에 맞춰 바꾼다
-- (그림 칸 위치가 캐릭터 복제로 그대로 가서 다른 사람에게도 내 유파 옷으로 보인다).
exports.school = 0

local function applyFrame(instance: ImageLabel, dir: string, col: number)
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.new((col - 1) * CELL.X, (exports.school * 4 + DIR_ROW[dir]) * CELL.Y)
end

local function blocked(x: number, y: number): boolean
	return map.BoxBlocked(x, y, FEET.halfW, FEET.h)
end

-- 원하는 자리가 막혀 있으면 가까운 빈 곳을 찾는다.
local function freeNear(p: Vector2): Vector2
	for r = 0, 60 do
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local q = p + Vector2.new(math.cos(a), math.sin(a)) * r * 2
			if not blocked(q.X, q.Y) then
				return q
			end
		end
	end
	return p
end

local function portalAt(d, pos: Vector2)
	for _, p in d.portals do
		if pos.X >= p.x0 and pos.X < p.x1 and pos.Y - 0.01 >= p.y0 and pos.Y - 0.01 < p.y1 then
			return p
		end
	end
	return nil
end

-- 도착 위치: 그 씬에 ⭐시작 위치가 있으면 포탈로 왔든 처음 들어왔든 항상 거기서 시작한다(사용자 결정 2026-09-29).
-- 시작 위치가 없는 씬만 "출발 씬으로 돌아가는 포탈" 바로 앞에 나타난다.
-- 예외: 건물 문·실내 출입구 포탈(arrive = "door")로 왔으면 ⭐와 상관없이 항상 돌아가는 포탈(문) 앞.
local function findSpawn(d): Vector2
	local fromKey = townWorld.KeyOf(travelState.fromScene)
	local arrive = travelState.arrive
	travelState.fromScene = nil -- 한 번 쓰면 바로 지운다
	travelState.arrive = nil
	if d.spawn and not (fromKey and arrive == "door") then
		return freeNear(Vector2.new(d.spawn.x, d.spawn.y))
	end
	if fromKey then
		for _, p in d.portals do
			if p.to == fromKey then
				-- 돌아가는 포탈 바로 아래 — 맵 밖이거나 막혀 있으면(실내 아랫벽 출입구) 바로 위, 그래도 안 되면 가까운 빈 곳
				-- (맵 가장자리의 포탈은 방향이 제각각이라 — 위·아래·왼·오른쪽 가장자리 — 포탈에서 맵 안쪽으로 한 걸음 들어온 자리를 찾는다)
				local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
				local mapW, mapH = d.w * world.tile, d.h * world.tile
				for _, q in { Vector2.new(cx, p.y1 + 6), Vector2.new(cx, p.y0 - 3), Vector2.new(p.x1 + 8, cy + 2), Vector2.new(p.x0 - 8, cy + 2) } do
					if q.X > 0 and q.Y > 0 and q.X < mapW and q.Y < mapH and not blocked(q.X, q.Y) then
						return q
					end
				end
				return freeNear(Vector2.new(cx, cy))
			end
		end
	end
	if d.spawn then
		return freeNear(Vector2.new(d.spawn.x, d.spawn.y))
	end
	return freeNear(Vector2.new(d.w * world.tile / 2, d.h * world.tile / 2))
end

function exports.load(scene: Scene)
	if exports.replicationConnection then
		exports.replicationConnection:Disconnect()
		exports.replicationConnection = nil
	end
	if exports.hero then
		exports.hero:Destroy()
		exports.hero = nil
	end

	local d = map.Use(scene)
	if not d then
		return
	end
	exports.pos = findSpawn(d)
	-- 포탈 위에서 태어났으면 한 번 밖으로 나가야 포탈이 작동한다.
	exports.portalArmed = portalAt(d, exports.pos) == nil

	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)
	hero.Anchored = true
	hero.GravityScale = 0
	hero.SkipCharacterCollisions = true
	hero.WalkSpeed = 0

	local instance = hero.Instance
	instance.AnchorPoint = Vector2.new(0.5, SHEET.feetY / SHEET.cellH) -- 발바닥이 위치점
	instance.ScaleType = Enum.ScaleType.Stretch
	instance.ResampleMode = Enum.ResamplerMode.Pixelated
	instance.Image = townAssets.PLAYER
	instance.Size = UDim2.fromOffset(CELL.X * CS, CELL.Y * CS)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.Position = UDim2.fromOffset(exports.pos.X * S, exports.pos.Y * S)
	instance.ZIndex = map.ZIndexFor(exports.pos.Y)
	applyFrame(instance, "down", 1)

	CrossPlatformService.SideView = false
	-- 엔진 기본 이동/애니메이션은 끄고 아래 Heartbeat에서 직접 처리한다.
	CrossPlatformService.DefaultControllersEnabled = false
	CrossPlatformService:SetPlayerCharacter(hero)

	-- 다른 플레이어에게 내 위치·프레임을 복제(서버 replication.luau가 승인해서 브로드캐스트).
	exports.replicationConnection = NetworkingService:ReplicateOnChange(hero)
	exports.hero = hero
end

function exports.start(scene: Scene)
	local hero = exports.hero
	local d = map.data
	if not hero or not d then
		return
	end

	local held = { up = false, down = false, left = false, right = false }
	local attack = { active = false, clock = 0, hitDone = false, readyAt = 0, speed = 1 }
	-- 대쉬(shared/config/ninjutsu.luau DASH): windup 동안 멈췄다가 time 동안 바라보는 쪽으로 dist만큼. 판정 · 연출은 서버(UseDash)
	local dash = { active = false, clock = 0, def = nil, dir = Vector2.zero, from = Vector2.zero, dist = 0 }
	exports.inputBeginConnection = CrossPlatformService:On("InputBegin", function(input)
		local action = input.Action and input.Action:lower()
		if action == "dash" then
			if exports.Dash then
				exports.Dash()
			end
			return
		end
		if action == "attack" then
			if not attack.active and not dash.active and os.clock() >= attack.readyAt then
				attack.active, attack.clock, attack.hitDone = true, 0, false
				-- 무기 종류마다 공격 빠르기가 다르다(shared/config/weapons.luau speed — 서버 공격 간격도 같은 배율)
				local equipment = require(script.Parent.globals.inventory).getEquipment()
				attack.speed = weapons.ClassOf(items[equipment.Weapon or ""]).speed * require(script.Parent.globals.ninjutsu).AttackSpeedMult() -- 전하가 쌓이면 빨라진다
			end
			return
		end
		if action and held[action] ~= nil then
			held[action] = true
		end
	end)
	exports.inputEndConnection = CrossPlatformService:On("InputEnd", function(input)
		local action = input.Action and input.Action:lower()
		if action and held[action] ~= nil then
			held[action] = false
		end
	end)

	-- 서버가 이동을 승인하면 도착 씬을 켠다(sceneLoader가 이 씬 모듈을 내리고 새 씬 모듈을 올린다).
	exports.travelConnection = Net.OnClient("TravelApproved", function(destination)
		local target = SceneManager:FindByName(destination)
		if not target or not townWorld.KeyOf(destination) then
			return
		end
		travelState.fromScene = scene.Name
		loadingScreen.Show()
		target:Enable()
	end)

	-- 몬스터에게 맞음: 머리 위 빨간 숫자. 쓰러짐(died): 서버가 시작 씬으로 옮겼으니 그 씬의 시작 위치(⭐)로 간다.
	exports.healthConnection = Net.OnClient("PlayerHealthChanged", function(health, maxHealth, damage, died)
		if damage and damage > 0 and hero.Instance then
			damageNumbers.Show(hero.Instance, damage, Color3.fromRGB(255, 90, 90))
			-- 피격 연출: 붉게 물들며 3번 깜빡(0.36초)
			local instance = hero.Instance
			exports.hitToken = (exports.hitToken or 0) + 1
			local token = exports.hitToken
			task.spawn(function()
				for i = 1, 6 do
					if not instance.Parent or exports.hitToken ~= token then
						return
					end
					local on = i % 2 == 1
					instance.ImageColor3 = if on then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
					instance.ImageTransparency = if on then 0.35 else 0
					task.wait(0.06)
				end
				instance.ImageColor3 = Color3.new(1, 1, 1)
				instance.ImageTransparency = 0
			end)
		end
		if not died then
			return
		end
		travelState.fromScene = nil -- 포탈 없이 도착 → 시작 위치
		local destination = townWorld.StartSceneName()
		local target = SceneManager:FindByName(destination)
		if target == scene then
			-- 이미 시작 씬이면 그 자리에서 시작 위치로 옮긴다
			exports.pos = findSpawn(map.data)
			exports.portalArmed = portalAt(map.data, exports.pos) == nil
			if hero.Instance then
				hero.Instance.Position = UDim2.fromOffset(exports.pos.X * S, exports.pos.Y * S)
			end
		elseif target then
			loadingScreen.Show()
			target:Enable()
		end
	end)

	task.spawn(function()
		ContentProvider:PreloadAsync({ townAssets.PLAYER })
		exports.animationReady = true
	end)

	local facing = "down"
	local walkClock = 0
	-- 대쉬 시작: 쿨타임 · 기력이 되면 서버에 알리고 바로 움직인다(벽까지의 거리는 서버와 같은 셈 — 2도트씩)
	function exports.Dash()
		if dash.active or attack.active or os.clock() < (exports.dashReadyAt or 0) then
			return
		end
		local nin = require(script.Parent.globals.ninjutsu)
		local _, def = ninjutsuConfig.DashFor(nin.school, nin.job)
		if nin.Energy() < def.cost then
			return
		end
		local dir = DASH_DIRS[facing]
		local dist = 0
		for step = 2, def.distance, 2 do
			local p = exports.pos + dir * step
			if blocked(p.X, p.Y) then
				break
			end
			dist = step
		end
		dash.active, dash.clock, dash.def, dash.dir, dash.from, dash.dist = true, 0, def, dir, exports.pos, dist
		exports.dashReadyAt, exports.dashCooldown = os.clock() + def.cooldown, def.cooldown
		Net.FireServer("UseDash", facing)
	end
	exports.dashKeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode[ninjutsuConfig.DASH_KEY] then
			exports.Dash()
		end
	end)
	local travelRequestedAt = -math.huge
	exports.connection = RunService.Heartbeat:Connect(function(dt)
		local instance = hero.Instance
		if not instance then
			return
		end

		local move = Vector2.new((held.right and 1 or 0) - (held.left and 1 or 0), (held.down and 1 or 0) - (held.up and 1 or 0))
		local moving = move.Magnitude > 0 and not attack.active and not dash.active -- 공격 · 대쉬 중엔 방향키가 듣지 않는다
		if dash.active then
			-- 준비 동작 동안은 제자리, 그 뒤 time초에 걸쳐 나아간다(걷는 그림을 빠르게 돌린다)
			dash.clock += dt
			local def = dash.def
			local p = math.clamp((dash.clock - def.windup) / def.time, 0, 1)
			exports.pos = dash.from + dash.dir * (dash.dist * p)
			applyFrame(instance, facing, if p > 0 then math.floor(dash.clock / 0.05) % WALK_FRAMES + 1 else 1)
			if dash.clock >= def.windup + def.time then
				dash.active = false
			end
		elseif attack.active then
			attack.clock += dt
			local f = math.floor(attack.clock / (combat.ATTACK_FRAME_TIME * attack.speed)) + 1
			if f >= SHEET.hitFrame and not attack.hitDone then
				attack.hitDone = true
				-- 판정은 서버(townMonsters)가 한다: 바라보는 방향만 보내면 서버가 아는 내 위치 앞 사각형으로 때린다(모두에게 공유)
				Net.FireServer("TownAttack", facing)
			end
			if f > ATTACK_FRAMES then
				attack.active = false
				attack.readyAt = os.clock() + combat.ATTACK_COOLDOWN * attack.speed
				applyFrame(instance, facing, 1)
			else
				applyFrame(instance, facing, WALK_FRAMES + f)
			end
		elseif moving then
			-- 방향: 가로가 있으면 가로 우선(대각선 이동 때 옆모습).
			if move.X ~= 0 then
				facing = if move.X < 0 then "left" else "right"
			else
				facing = if move.Y < 0 then "up" else "down"
			end
			if hero.Facing ~= facing then
				hero.Facing = facing -- 등 뒤 무기 자리(town/weapon.luau)용 — 캐릭터 복제로 다른 사람에게도 간다
			end

			local step = move.Unit * SPEED * math.min(dt, 0.1)
			local pos = exports.pos
			local nx = pos.X + step.X
			if not blocked(nx, pos.Y) then
				pos = Vector2.new(nx, pos.Y)
			end
			local ny = pos.Y + step.Y
			if not blocked(pos.X, ny) then
				pos = Vector2.new(pos.X, ny)
			end
			exports.pos = pos

			walkClock += dt
			applyFrame(instance, facing, math.floor(walkClock / WALK_FRAME_TIME) % WALK_FRAMES + 1)
		else
			walkClock = 0
			applyFrame(instance, facing, 1)
		end

		instance.Position = UDim2.fromOffset(math.round(exports.pos.X * S), math.round(exports.pos.Y * S))
		instance.ZIndex = map.ZIndexFor(exports.pos.Y)
		-- 엔진 자동 애니메이션이 IsPlaying을 켜면 프레임(ImageRectOffset)이 복제에서 빠진다(실측 이력) — 매 프레임 끈다.
		hero.IsPlaying = false

		-- 포탈: 밖에 있다가 들어오면 이동 요청
		local portal = portalAt(d, exports.pos)
		if not portal then
			exports.portalArmed = true
		elseif exports.portalArmed and portal.to and os.clock() - travelRequestedAt > TRAVEL_RETRY then
			travelRequestedAt = os.clock()
			travelState.arrive = portal.arrive -- 도착 씬에서 어디에 나타날지(findSpawn)
			Net.FireServer("RequestTravel", townWorld.SceneName(portal.to))
		end

		-- 다른 플레이어 사본도 도트가 번지지 않게, 발 높이로 겹침 순서를 맞춘다.
		local mine = hero.Id
		for _, objects in NetworkingService.PlayersData do
			for _, other in objects do
				local otherInstance = other.Instance
				if other.Id ~= mine and otherInstance and otherInstance.Parent then
					otherInstance.ResampleMode = Enum.ResamplerMode.Pixelated
					otherInstance.ZIndex = map.ZIndexFor(otherInstance.Position.Y.Offset / S)
				end
			end
		end
	end)
end

function exports.unload(scene: Scene)
	for _, key in { "connection", "inputBeginConnection", "inputEndConnection", "replicationConnection", "travelConnection", "healthConnection", "dashKeyConnection" } do
		if exports[key] then
			exports[key]:Disconnect()
			exports[key] = nil
		end
	end
	if exports.hero then
		exports.hero:Destroy()
		exports.hero = nil
	end
	exports.animationReady = false
end

return exports
