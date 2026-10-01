-- 탑다운 씬 몬스터(서버 권위, 온라인 공유). 공방 맵의 스폰 구역·직접 놓은 몬스터 그대로 씬마다 서버가 만들고 움직인다.
--  배회: 나타난 자리에서 반경 world.monsterRoam 안을 자유롭게(공방 js/world.js와 같은 규칙), 충돌은 씬 충돌 격자.
--  레벨·체력·경험치·공격력: shared/config/monsterLevels.luau(종마다 레벨 범위, 높을수록 드묾).
--  공격(TownAttack): 클라이언트는 바라보는 방향만 보낸다 — 서버가 아는 발 위치 앞 사각형(combat.ATTACK_REACH/WIDTH)
--  안의 몬스터에게 장비 공격력(inventoryService.GetAttackDamage)만큼 피해. 간격은 balance.TOWN_ATTACK_COOLDOWN으로 검증.
--  기여도(GAME_DESIGN §3): 몬스터마다 플레이어별 넣은 피해(damageBy)를 모은다. 개인 기준, 그 플레이어가 씬을 옮기면 지운다.
--  처치: 기여도 rewards.CONTRIB_MIN(10%) 이상인 사람 모두 경험치 + 도감(봤음) + 전리품(골드·그 몬스터 재료). 미만이면 "기여도 부족" 알림만.
--  포획(M2): 전투 중 단축칸 방울 → ThrowBell — 바라보는 방향 직선으로 날아가 처음 맞은 몬스터에게 시도(BellThrown 연출).
--   자격 = 아무도 안 때렸거나 던진 사람이 딜 1등. 확률 = 레벨·방울 × 체력 비율(capture.Chance). 결과 연출(TownCapture) 뒤
--   성공 = 펫 상자 + 도감 잡았음, 실패 = 도망. 어느 쪽이든 쓰러뜨린 게 아니라 전리품은 없다.
--  반격: 맞은 몬스터는 때린 사람을 쫓아가 공격한다(combat.MONSTER_*). 집에서 너무 멀어지거나, 한동안 안 맞거나,
--   그 사람이 씬을 떠나면 포기하고 돌아간다. 피해는 progressionService.DamagePlayer(사망 페널티·리스폰 포함).
--  combat.MONSTER_RESPAWN초 뒤 같은 구역에 새 레벨로 다시 나타남.
-- 같은 씬 플레이어에게만 보낸다(첫 인자 = 씬 키): 위치 10Hz(TownMonsterMoves), 피격/죽음/등장은 즉시.
-- 플레이어가 없는 씬은 움직이지 않는다(서버 부담).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local combat = require(ReplicatedStorage.shared.config.combat)
local monsterLevels = require(ReplicatedStorage.shared.config.monsterLevels)
local pets = require(ReplicatedStorage.shared.config.pets)
local rewards = require(ReplicatedStorage.shared.config.rewards)
local capture = require(ReplicatedStorage.shared.config.capture)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local worldDrops = require(script.Parent.worldDrops)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local currencyService = require(script.Parent.Parent.services.currencyService)
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
	m.level = monsterLevels.RollLevel(m.row, rng) -- 종의 레벨 범위 안에서, 높은 레벨일수록 드물게
	m.maxHp = monsterLevels.MaxHealth(m.level)
	m.hp = m.maxHp
	m.damageBy = {} -- [userId] = { dmg = 넣은 피해, first = 처음 때린 시각 }
	m.aggro = nil -- 쫓는 플레이어 userId
	m.shiny = rng:NextNumber() < pets.SHINY_CHANCE -- 이로치(색만 다름) — 잡으면 펫에 저장
end

local function wire(m)
	return { id = m.id, row = m.row, level = m.level, hp = m.hp, maxHp = m.maxHp, x = m.x, y = m.y, shiny = m.shiny }
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

-- 쫓기·공격(맞은 몬스터). 계속 쫓으면 true, 포기했으면 false(평소 배회로 돌아감).
local function chase(key: string, st, m, dt: number): boolean
	local player = Players:GetPlayerByUserId(m.aggro)
	local position = player and heroTracking.GetPosition(m.aggro)
	local here = player and townWorld.KeyOf(heroTracking.GetPlayerScene(m.aggro)) == key
	local now = os.clock()
	local homeDist = (Vector2.new(m.x, m.y) - m.home).Magnitude
	if not here or not position or now > m.aggroUntil or homeDist > combat.MONSTER_LEASH then
		m.aggro = nil
		m.target = m.home -- 집으로 돌아간다
		return false
	end
	local feet = position / world.scale
	local dx, dy = feet.X - m.x, feet.Y - m.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist > combat.MONSTER_ATTACK_RANGE * 0.7 then
		local s = math.min(dist - combat.MONSTER_ATTACK_RANGE * 0.6, SPEED * combat.MONSTER_CHASE_SPEED * dt)
		local nx, ny = m.x + dx / dist * s, m.y + dy / dist * s
		if not blocked(st.d, nx, ny) then
			m.x, m.y = nx, ny
			m.moving = true
		end
	end
	m.facingLeft = dx < 0
	if dist <= combat.MONSTER_ATTACK_RANGE and now >= (m.nextAttack or 0) then
		m.nextAttack = now + combat.MONSTER_ATTACK_COOLDOWN
		toScene(key, "TownMonsterAttack", m.id)
		local damage = math.max(monsterLevels.AttackDamage(m.level) - inventoryService.GetDefense(player), 1)
		progressionService.DamagePlayer(player, damage)
	end
	return true
end

local function step(key: string, st, dt: number)
	local d = st.d
	for _, m in st.monsters do
		if m.dead or m.capturing then
			continue
		end
		local wasMoving = m.moving
		m.moving = false
		if m.aggro and chase(key, st, m, dt) then
			if m.moving or wasMoving then
				m.dirty = true
			end
			continue
		end
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

-- 처치 보상(기여도 10% 이상인 사람 모두, GAME_DESIGN §3): 기본(경험치 + 도감 봤음) + 전리품(골드 + 그 몬스터 재료).
-- 그냥 사냥해서 쓰러뜨리는 것이 곧 "재료 받기"다. 포획은 전투 중 방울 던지기(아래 ThrowBell)로 따로 한다.
local function rewardBase(player: Player, m)
	progressionService.AddExperience(player, monsterLevels.Experience(m.level))
	local species = world.species[m.row]
	local data = persistence.Get(player)
	if data and species then
		data.Dex = data.Dex or {}
		if not data.Dex[species.id] then
			data.Dex[species.id] = pets.DEX_SEEN -- 봤음
			persistence.MarkDirty(player)
			Net.FireClient("DexDiscovered", player, m.row)
		end
	end
end

local function rewardLoot(player: Player, m)
	currencyService.AddGold(player, rewards.Gold(m.level, rng))
	local species = world.species[m.row]
	local material = species and species.material -- 그 몬스터 전용 재료(Mat_<종 id>)
	if material then
		inventoryService.AddItem(player, material, rewards.MaterialCount(m.level))
	end
end

-- 지금 딜 1등(넣은 피해가 가장 많은 사람, 동점이면 먼저 때린 사람)의 userId — 아무도 안 때렸으면 nil
local function topDealer(m): number?
	local best, bestDmg, bestFirst = nil, -1, math.huge
	for userId, e in m.damageBy do
		if e.dmg > bestDmg or (e.dmg == bestDmg and e.first < bestFirst) then
			best, bestDmg, bestFirst = userId, e.dmg, e.first
		end
	end
	return best
end

-- 기여도 정산: 10% 이상은 보상, 미만은 알림만(개인 기준).
local function settle(m)
	for userId, e in m.damageBy do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			continue
		end
		local share = e.dmg / m.maxHp
		if share >= rewards.CONTRIB_MIN then
			rewardBase(player, m)
			rewardLoot(player, m)
		else
			Net.FireClient("Notify", player, ("기여도 %d%% — 10%% 이상 때려야 보상을 받아요"):format(math.floor(share * 100)))
		end
	end
end

local function respawnLater(key: string, st, m)
	task.delay(combat.MONSTER_RESPAWN, function()
		if scenes[key] ~= st then
			return
		end
		local pos = if m.zone then randomIn(st.d, m.zone) else m.home
		pos = pos or m.home
		m.x, m.y, m.home = pos.X, pos.Y, pos
		rollLevel(m)
		m.dead = false
		m.capturing = false
		m.dirty = true
		m.wait = rng:NextNumber(0.5, WAIT[2])
		toScene(key, "TownMonsterSpawned", wire(m))
	end)
end

-- ---- 포획(M2, shared/config/capture.luau) — 전투 중 방울 던지기 ----
local lastThrowAt = {}
local DIRS = { up = Vector2.new(0, -1), down = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }

local function boxFull(player: Player): boolean
	local data = persistence.Get(player)
	local p = data and data.Pets
	return not p or #p.Box >= pets.Capacity(p.Boxes)
end

local function kill(key: string, st, m)
	m.dead = true
	m.target = nil
	m.aggro = nil
	toScene(key, "TownMonsterDied", m.id)
	settle(m)
	respawnLater(key, st, m)
end

-- 맞은 몬스터에게 포획 시도. 결과는 바로 굴리고, 연출(룬 문양 원 + 딸랑 3번) 시간 뒤에 적용한다.
local function tryCapture(key: string, st, m, player: Player, tier: number)
	local top = topDealer(m)
	if (top and top ~= player.UserId) or boxFull(player) then
		-- 다른 사람이 더 많이 싸우던 몬스터(또는 상자가 가득) — 방울이 튕겨 나간다
		toScene(key, "TownCapture", m.id, tier, "blocked")
		Net.FireClient("Notify", player, if top and top ~= player.UserId then "다른 사람이 먼저 싸우던 몬스터예요" else "몬스터 상자가 가득 찼어요")
		return
	end
	local species = world.species[m.row]
	local dings, success = capture.RollShakes(capture.Chance(m.level, tier, m.hp / m.maxHp, false, false), rng)
	m.capturing = true -- 연출 동안 멈추고, 맞지도 않는다
	m.target = nil
	m.aggro = nil
	toScene(key, "TownCapture", m.id, tier, if success then "success" else "fail", dings)
	task.delay(capture.RevealTime(dings), function()
		m.capturing = false
		m.dead = true -- 잡혔거나 도망감(쓰러뜨린 게 아니라 전리품은 없다)
		if success and player.Parent then
			local data = persistence.Get(player)
			if data and species then
				table.insert(data.Pets.Box, { S = species.id, L = m.level, C = if m.shiny then 1 else 0, B = tier, T = os.time() })
				-- 함께 다니는 칸이 비어 있으면 바로 넣는다
				if #data.Pets.Party < pets.SlotCount(data.Level, data.Pets.Paid) then
					table.insert(data.Pets.Party, #data.Pets.Box)
				end
				Net.FireClient("PetsUpdated", player, data.Pets)
				local first = data.Dex[species.id] ~= pets.DEX_CAUGHT
				data.Dex[species.id] = pets.DEX_CAUGHT
				persistence.MarkDirty(player)
				task.spawn(persistence.Save, player, false) -- 잡은 몬스터는 잃으면 가장 아프다 — 바로 저장
				Net.FireClient("Notify", player, ("%s%s(Lv.%d)와(과) 맺어졌어요!"):format(if m.shiny then "★이로치★ " else "", species.name, m.level))
				if first then
					Net.FireClient("DexDiscovered", player, m.row)
				end
			end
		elseif player.Parent then
			Net.FireClient("Notify", player, ("맺기 실패… %s이(가) 도망갔어요"):format(species and species.name or "몬스터"))
		end
		respawnLater(key, st, m)
	end)
end

-- 방울 던지기(단축칸 사용 — server/modules/quickSlots.luau가 부른다). 방울 1개를 먼저 쓰고, 바라보는 방향으로 직선
-- THROW_RANGE까지 날아가 처음 맞은 몬스터에게 포획 시도. 같은 씬 모두에게 날아가는 연출(BellThrown).
function exports.ThrowBell(player: Player, itemId: string, facing: string): boolean
	local def = items[itemId]
	if not def or def.Type ~= "Bell" then
		return false
	end
	local now = os.clock()
	if lastThrowAt[player.UserId] and now - lastThrowAt[player.UserId] < capture.THROW_COOLDOWN then
		return false
	end
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local st = key and scenes[key]
	local position = heroTracking.GetPosition(player.UserId)
	local dir = DIRS[facing]
	if not st or not position or not dir then
		return false
	end
	if not inventoryService.TakeItem(player, itemId, 1) then
		return false
	end
	lastThrowAt[player.UserId] = now
	-- 손 높이(발보다 조금 위)에서 출발
	local origin = position / world.scale - Vector2.new(0, 8)
	local hit, hitT = nil, capture.THROW_RANGE
	for _, m in st.monsters do
		if m.dead or m.capturing then
			continue
		end
		local rel = Vector2.new(m.x, m.y - 6) - origin -- 몬스터 몸 가운데쯤
		local t = rel:Dot(dir)
		local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
		if t >= 0 and t <= hitT and side <= capture.THROW_WIDTH then
			hit, hitT = m, t
		end
	end
	toScene(key, "BellThrown", player.UserId, origin.X, origin.Y, dir.X, dir.Y, hitT, def.Tier, if hit then hit.id else 0)
	if hit then
		task.delay(hitT / capture.THROW_SPEED, function()
			if scenes[key] == st and not hit.dead and not hit.capturing and player.Parent then
				tryCapture(key, st, hit, player, def.Tier)
			end
		end)
	end
	return true
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
			if not m.dead and not m.capturing and m.x >= x0 and m.x <= x1 and m.y >= y0 and m.y <= y1 then
				local dealt = math.min(m.hp, damage) -- 기여도는 실제로 깎은 체력만(마지막 한 방이 넘쳐도 최대 체력까지)
				m.hp -= dealt
				local e = m.damageBy[player.UserId]
				if not e then
					e = { dmg = 0, first = now }
					m.damageBy[player.UserId] = e
				end
				e.dmg += dealt
				m.target = nil
				m.wait = 0.6
				-- 반격: 쫓는 사람이 없으면 이 사람을 쫓고, 맞을 때마다 포기 시간을 늘린다
				if not m.aggro then
					m.aggro = player.UserId
					m.nextAttack = now + 0.5
				end
				m.aggroUntil = now + combat.MONSTER_AGGRO_TIME
				toScene(key, "TownMonsterHit", m.id, m.hp, damage, player.UserId, weaponId)
				if m.hp <= 0 then
					kill(key, st, m)
				end
			end
		end
	end)

	-- 씬을 옮기거나 나가면 그 씬 몬스터에 쌓인 그 사람의 기여도를 지우고, 쫓던 몬스터는 포기한다
	local function forget(userId: number, sceneName: string?)
		local key = townWorld.KeyOf(sceneName)
		local st = key and scenes[key]
		if not st then
			return
		end
		for _, m in st.monsters do
			m.damageBy[userId] = nil
			if m.aggro == userId then
				m.aggro = nil
				m.target = m.home
			end
		end
	end
	heroTracking.OnSceneChanged(function(userId, previous)
		forget(userId, previous)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player.UserId] = nil
		lastThrowAt[player.UserId] = nil
		forget(player.UserId, heroTracking.GetPlayerScene(player.UserId))
	end)

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for key, st in scenes do
			if #heroTracking.PlayersInScene(townWorld.SceneName(key)) == 0 then
				continue
			end
			step(key, st, dt)
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
