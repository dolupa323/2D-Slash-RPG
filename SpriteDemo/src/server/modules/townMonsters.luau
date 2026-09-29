-- 탑다운 씬 몬스터(서버 권위, 온라인 공유). 공방 맵의 스폰 구역·직접 놓은 몬스터 그대로 씬마다 서버가 만들고 움직인다.
--  배회: 나타난 자리에서 반경 world.monsterRoam 안을 자유롭게(공방 js/world.js와 같은 규칙), 충돌은 씬 충돌 격자.
--  레벨·체력·경험치: shared/config/monsterLevels.luau(도감 순번 = 강함 단계).
--  공격(TownAttack): 클라이언트는 바라보는 방향만 보낸다 — 서버가 아는 발 위치 앞 사각형(combat.ATTACK_REACH/WIDTH)
--  안의 몬스터에게 장비 공격력(inventoryService.GetAttackDamage)만큼 피해. 간격은 balance.TOWN_ATTACK_COOLDOWN으로 검증.
--  처치: 때린 사람에게 경험치 + 도감 등록(처음이면 DexDiscovered), combat.MONSTER_RESPAWN초 뒤 같은 구역에 새 레벨로 다시 나타남.
-- 같은 씬 플레이어에게만 보낸다(첫 인자 = 씬 키): 위치 10Hz(TownMonsterMoves), 피격/죽음/등장은 즉시.
-- 플레이어가 없는 씬은 움직이지 않는다(서버 부담).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local combat = require(ReplicatedStorage.shared.config.combat)
local monsterLevels = require(ReplicatedStorage.shared.config.monsterLevels)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local worldDrops = require(script.Parent.worldDrops)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local world = townWorld.data
local FEET = world.monsterFeet
local SPEED = world.monsterSpeed
local ROAM = world.monsterRoam or 96
local WAIT = world.monsterWait or { 0.6, 2.2 }
local SEND_INTERVAL = 0.1

local exports = {}

local scenes = {} -- 씬 키 -> { d, monsters = { [id] = m } }
local nextId = 0
local rng = Random.new()
local lastAttackAt = {}

local function toScene(key: string, name: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient(name, player, key, ...)
	end
end

local function blocked(d, x: number, y: number): boolean
	return townWorld.BoxBlocked(d, x, y, FEET.halfW, FEET.h)
end

local function randomIn(d, z): Vector2?
	for _ = 1, 40 do
		local x, y = rng:NextNumber(z.x0, z.x1), rng:NextNumber(z.y0, z.y1)
		if not blocked(d, x, y) then
			return Vector2.new(x, y)
		end
	end
	return nil
end

local function rollLevel(m)
	local lo, hi = monsterLevels.LevelRange(m.row)
	m.level = rng:NextInteger(lo, hi)
	m.maxHp = monsterLevels.MaxHealth(m.level)
	m.hp = m.maxHp
end

local function wire(m)
	return { id = m.id, row = m.row, level = m.level, hp = m.hp, maxHp = m.maxHp, x = m.x, y = m.y }
end

local function add(st, row: number, pos: Vector2, zone)
	nextId += 1
	local m = {
		id = nextId, row = row, zone = zone, home = pos, x = pos.X, y = pos.Y,
		target = nil, wait = rng:NextNumber(0, WAIT[2]), facingLeft = rng:NextNumber() < 0.5, moving = false, dirty = true, dead = false,
	}
	rollLevel(m)
	st.monsters[m.id] = m
end

local function buildScene(key: string, d)
	local st = { d = d, monsters = {}, sendClock = 0 }
	for _, m in d.mons do
		add(st, m.species, Vector2.new(m.x, m.y), nil)
	end
	for _, z in d.zones do
		local pool = z.species
		if #pool == 0 then
			pool = {}
			for i = 1, #world.species do
				table.insert(pool, i)
			end
		end
		for _ = 1, z.count do
			local pos = randomIn(d, z)
			if pos then
				add(st, pool[rng:NextInteger(1, #pool)], pos, z)
			end
		end
	end
	scenes[key] = st
end

local function pickTarget(d, m): Vector2?
	for _ = 1, 8 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = ROAM * math.sqrt(rng:NextNumber())
		local tx, ty = m.home.X + math.cos(ang) * r, m.home.Y + math.sin(ang) * r
		if not blocked(d, tx, ty) then
			return Vector2.new(tx, ty)
		end
	end
	return nil
end

local function step(st, dt: number)
	local d = st.d
	for _, m in st.monsters do
		if m.dead then
			continue
		end
		local wasMoving = m.moving
		m.moving = false
		if m.target then
			local dx, dy = m.target.X - m.x, m.target.Y - m.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < 1 then
				m.target = nil
				m.wait = rng:NextNumber(WAIT[1], WAIT[2])
			else
				local s = math.min(dist, SPEED * dt)
				local nx, ny = m.x + dx / dist * s, m.y + dy / dist * s
				if blocked(d, nx, ny) then
					m.target = nil
					m.wait = rng:NextNumber(0.3, 1)
				else
					m.x, m.y = nx, ny
					m.facingLeft = dx < 0
					m.moving = true
				end
			end
		else
			m.wait -= dt
			if m.wait <= 0 then
				m.target = pickTarget(d, m)
				if not m.target then
					m.wait = rng:NextNumber(0.5, 1.5)
				end
			end
		end
		if m.moving or wasMoving then
			m.dirty = true
		end
	end
end

local function broadcastMoves(key: string, st)
	local list = {}
	for _, m in st.monsters do
		if m.dirty and not m.dead then
			m.dirty = false
			table.insert(list, { m.id, math.round(m.x * 10) / 10, math.round(m.y * 10) / 10, m.facingLeft, m.moving })
		end
	end
	if #list > 0 then
		toScene(key, "TownMonsterMoves", list)
	end
end

-- 처치 보상: 경험치 + 도감(처음이면 알림)
local function reward(player: Player, m)
	progressionService.AddExperience(player, monsterLevels.Experience(m.level))
	local data = persistence.Get(player)
	local species = world.species[m.row]
	if data and species then
		data.Dex = data.Dex or {}
		if not data.Dex[species.id] then
			data.Dex[species.id] = true
			persistence.MarkDirty(player)
			Net.FireClient("DexDiscovered", player, m.row)
		end
	end
end

local function kill(key: string, st, m, killer: Player)
	m.dead = true
	m.target = nil
	toScene(key, "TownMonsterDied", m.id)
	reward(killer, m)
	task.delay(combat.MONSTER_RESPAWN, function()
		if scenes[key] ~= st then
			return
		end
		local pos = if m.zone then randomIn(st.d, m.zone) else m.home
		pos = pos or m.home
		m.x, m.y, m.home = pos.X, pos.Y, pos
		rollLevel(m)
		m.dead = false
		m.dirty = true
		m.wait = rng:NextNumber(0.5, WAIT[2])
		toScene(key, "TownMonsterSpawned", wire(m))
	end)
end

-- 바라보는 방향 앞 사각형(발 기준) — 클라이언트 topDownHero의 공격 범위와 같은 수치
local function attackBox(x: number, y: number, facing: string)
	local reach, half = combat.ATTACK_REACH, combat.ATTACK_WIDTH / 2
	if facing == "left" then
		return x - reach, y - half, x, y + half
	elseif facing == "right" then
		return x, y - half, x + reach, y + half
	elseif facing == "up" then
		return x - half, y - reach, x + half, y
	end
	return x - half, y, x + half, y + reach
end

function exports.load()
	for key, d in world.scenes do
		buildScene(key, d)
	end

	Net.OnServer("GetTownState", function(player: Player)
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local st = key and scenes[key]
		if not st then
			return nil
		end
		local list = {}
		for _, m in st.monsters do
			if not m.dead then
				table.insert(list, wire(m))
			end
		end
		return { scene = key, monsters = list, drops = worldDrops.List(key) }
	end)

	Net.OnServer("TownAttack", function(player: Player, facing: string)
		local now = os.clock()
		local last = lastAttackAt[player.UserId]
		if last and now - last < balance.TOWN_ATTACK_COOLDOWN then
			return
		end
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local st = key and scenes[key]
		local position = heroTracking.GetPosition(player.UserId)
		if not st or not position then
			return
		end
		lastAttackAt[player.UserId] = now
		local feet = position / world.scale
		local x0, y0, x1, y1 = attackBox(feet.X, feet.Y, facing)
		local damage = inventoryService.GetAttackDamage(player)
		local data = persistence.Get(player)
		local weaponId = data and data.Equipment and data.Equipment.Weapon or "" -- 맞은 몬스터 위 베기 VFX를 무기에 맞게
		for _, m in st.monsters do
			if not m.dead and m.x >= x0 and m.x <= x1 and m.y >= y0 and m.y <= y1 then
				m.hp = math.max(0, m.hp - damage)
				m.target = nil
				m.wait = 0.6
				toScene(key, "TownMonsterHit", m.id, m.hp, damage, player.UserId, weaponId)
				if m.hp <= 0 then
					kill(key, st, m, player)
				end
			end
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAttackAt[player.UserId] = nil
	end)

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for key, st in scenes do
			if #heroTracking.PlayersInScene(townWorld.SceneName(key)) == 0 then
				continue
			end
			step(st, dt)
			st.sendClock += dt
			if st.sendClock >= SEND_INTERVAL then
				st.sendClock = 0
				broadcastMoves(key, st)
			end
		end
	end)
end

function exports.start() end

function exports.unload()
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
end

return exports
