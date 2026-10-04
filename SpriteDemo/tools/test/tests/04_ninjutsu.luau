-- 유파와 인술(N2): 설정 정합성 · 유파 고르기/바꾸기 · 기력 · 쿨타임 · 인술 종류별 판정(투사체 · 직선 · 둘레 · 연쇄 · 회복 · 방어)
--  · 상태 이상(느려짐 · 멈춤 · 밀림 · 불붙음) · 두루마리(단계) · 두루마리 드롭률
local world = req("ReplicatedStorage/shared/data/townWorld").data
local townWorld = req("ReplicatedStorage/shared/data/townWorld")
local items = req("ReplicatedStorage/shared/data/items")
local itemIcons = req("ReplicatedStorage/shared/data/itemIcons.generated")
local balance = req("ReplicatedStorage/shared/config/balance")
local combat = req("ReplicatedStorage/shared/config/combat")
local drops = req("ReplicatedStorage/shared/config/drops")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local packets = req("ReplicatedStorage/shared/net/packets")
local schema = req("ServerScriptService/server/services/playerSchema")
local SK = ninjutsu.SKILLS

-- ---- 1) 설정 정합성 ----
eq(#ninjutsu.SCHOOLS, #world.schools, "유파 수 = 캐릭터 시트 유파 수")
for i, id in ninjutsu.SCHOOLS do
	eq(world.schools[i].id, id, "유파 순서 = 시트 줄 순서 " .. id)
	eq(ninjutsu.SchoolIndex(id), i - 1, "유파 번호 " .. id)
	local info = ninjutsu.SCHOOL_INFO[id]
	expect(info ~= nil and #info.skills == #ninjutsu.JOB_LEVELS, "유파 정보 · 전직마다 인술 하나 " .. id)
	for slot, sid in info.skills do
		local s = SK[sid]
		expect(s ~= nil and s.school == id, ("인술 %s 는 %s 유파"):format(sid, id))
		eq(ninjutsu.SkillFor(id, slot), sid, "칸 → 인술 " .. sid)
	end
end
eq(ninjutsu.SchoolIndex(""), 0, "유파 없음 → 0번 줄")
-- 전직 레벨 10 · 30 · 60 · 100(사용자 지시)
eq(table.concat(ninjutsu.JOB_LEVELS, ","), "10,30,60,100", "전직 레벨")
eq(ninjutsu.JobFor(1), 0, "Lv.1 = 견습"); eq(ninjutsu.JobFor(9), 0, "Lv.9 = 견습"); eq(ninjutsu.JobFor(10), 1, "Lv.10 = 1차")
eq(ninjutsu.JobFor(59), 2, "Lv.59 = 2차"); eq(ninjutsu.JobFor(60), 3, "Lv.60 = 3차"); eq(ninjutsu.JobFor(100), 4, "Lv.100 = 4차")
for job = 0, #ninjutsu.JOB_LEVELS do
	expect(typeof(ninjutsu.JOB_NAMES[job]) == "string", "계급 이름 " .. job)
end
expect(packets.JobAdvance ~= nil, "패킷 등록 JobAdvance")
expect(ninjutsu.SkillFor("", 1) == nil, "유파 없음 → 인술 없음")
local NEED = {
	projectile = { "range", "speed", "width", "radius", "power" },
	line = { "length", "width", "power" },
	circle = { "radius", "power" },
	chain = { "range", "jumps", "jumpRange", "power", "falloff" },
	heal = { "ratio" },
	guard = { "mult", "seconds" },
}
NEED.seed = { "range", "speed", "width", "radius", "power", "fuse", "burstPower" }
NEED.zone = { "radius", "seconds", "interval" }
NEED.buff = { "radius", "seconds" }
NEED.detonate = { "radius", "power", "spread" }
NEED.shatter = { "radius", "power" }
NEED.discharge = { "radius", "radiusPer", "power", "powerPer" }
NEED.decoy = { "radius", "seconds", "frost" }
NEED.counter = { "window", "radius", "power" }
for id, s in SK do
	expect(typeof(s.name) == "string" and typeof(s.desc) == "string", "이름 · 설명 " .. id)
	if s.kind == "passive" then
		continue -- 패시브 · 핵심 장치(쓰는 인술이 아님) — 09_skills.luau
	end
	expect(NEED[s.kind] ~= nil, "알려진 종류 " .. id)
	expect((s.cost > 0 or s.vigorCost ~= nil) and s.cost <= ninjutsu.ENERGY_MAX and s.cooldown > 0, "기력(또는 생기) · 쿨타임 " .. id)
	for _, f in NEED[s.kind] or {} do
		expect(typeof(s[f]) == "number", ("%s.%s"):format(id, f))
	end
end
eq(ninjutsu.LevelScale(1), 1, "1단계 보정")
eq(ninjutsu.LevelScale(99), 1 + (ninjutsu.MAX_LEVEL - 1) * ninjutsu.LEVEL_BONUS, "최고 단계 보정")
for _, name in { "ChooseSchool", "UseNinjutsu", "SchoolUpdated", "EnergyUpdated", "NinjutsuCast", "TownMonsterStatus" } do
	expect(packets[name] ~= nil, "패킷 등록 " .. name)
end
for _, id in ninjutsu.SCHOOLS do
	expect(packets.ChooseSchool.Args[1](id), "ChooseSchool 인자 " .. id)
end
expect(not packets.ChooseSchool.Args[1]("water"), "없는 유파는 거름")
for _, sid in drops.SCROLLS do
	local def = items[sid]
	expect(def ~= nil and def.Type == "Scroll" and ninjutsu.SCHOOL_INFO[def.School] ~= nil, "두루마리 아이템 " .. sid)
	expect(def ~= nil and itemIcons.rects["icon_" .. def.KitIcon] ~= nil, "두루마리 아이콘 " .. sid)
end

-- ---- 2) 저장 형태 ----
local fresh = schema.default()
eq(fresh.School, "", "새 플레이어: 유파 없음")
expect(typeof(fresh.Ninjutsu) == "table" and next(fresh.Ninjutsu) == nil, "새 플레이어: 인술 단계표 비어 있음")
local old = schema.default()
old.SchemaVersion, old.School, old.Ninjutsu = 7, nil, nil
schema.migrate(old)
expect(old.School == "" and typeof(old.Ninjutsu) == "table" and old.SchemaVersion == schema.CURRENT_VERSION, "v7 → v8 마이그레이션")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local p2 = { UserId = 2, Name = "닌자2", Parent = {} }
local byId = { [1] = p1, [2] = p2 }
local data = { [p1] = schema.default(), [p2] = schema.default() }
local where = { [1] = "town_field1", [2] = "town_field1" }
local pos = { [1] = V(0, 0), [2] = V(0, 0) }
local function standAt(player, x, y) pos[player.UserId] = V(x * world.scale, y * world.scale) end

local events, handlers = {}, {}
local function sent(name, player)
	local out = {}
	for _, e in events do
		if e.name == name and (player == nil or e.player == player) then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(player, word)
	for _, e in sent("Notify", player) do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end

MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName)
		local list = {}
		for id, s in where do
			if s == sceneName then table.insert(list, byId[id]) end
		end
		return list
	end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local hurts = {} -- 몬스터에게 맞은 피해 기록
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end,
	DamagePlayer = function(player, n) table.insert(hurts, { player = player, n = n }) end,
	Heal = function(player, n)
		local d = data[player]
		local before = d.Health
		d.Health = math.min(balance.maxHealthFor(d.Level), before + n)
		return d.Health - before
	end,
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
local heartbeat
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function(_, fn) heartbeat = fn; return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local ninjutsuService = req("ServerScriptService/server/modules/ninjutsuService")
local shops = req("ServerScriptService/server/modules/shops")
townMonsters.load()
ninjutsuService.load()
shops.load()

-- 스킬 나무(저장 v13) 호환: 아래 종류별 시험은 "칸 n = 그 유파의 옛 n차 인술(SCHOOL_INFO.skills)"로 쓴다 —
--  인술을 쓰기 직전에 그 네 인술을 1레벨로 배운 것으로 하고 단축칸을 그렇게 맞춘다(전직 단계도 4로 보고 쓴다 — 전직별 잠금은 09 · 10이 본다).
--  스킬 나무 · SP · 단축칸 · 핵심 장치 자체의 시험은 09_skills.luau.
do
	local use = handlers.UseNinjutsu
	handlers.UseNinjutsu = function(player, slot, facing)
		local d = data[player]
		local info = d and ninjutsu.SCHOOL_INFO[d.School or ""]
		if info then
			d.Ninjutsu = d.Ninjutsu or {}
			d.SkillSlots = table.clone(info.skills)
			for _, id in info.skills do
				if (d.Ninjutsu[id] or 0) < 1 then d.Ninjutsu[id] = 1 end
			end
		end
		local job = d and d.Job
		if d then d.Job = 4 end
		use(player, slot, facing)
		if d then d.Job = job end
	end
end

local ATTACK = balance.BASE_ATTACK
local field = world.scenes.field1
local FEET = world.monsterFeet
local function living() return townMonsters.Living("field1") end
-- 몬스터를 전부 구석으로 치우고(체력 넉넉히), 쓸 것만 자리에 놓는다. 집도 같이 옮긴다(멀어지면 쫓기를 포기하므로).
local function place(m, x, y)
	m.x, m.y, m.home = x, y, V(x, y)
	m.target, m.aggro, m.stunUntil, m.slowUntil = nil, nil, nil, nil
end
local function reset()
	advance(5) -- 앞 시험이 남긴 것(불붙음 등)을 먼저 흘려보낸다
	local list = living()
	for _, m in list do
		m.maxHp, m.hp = 100000, 100000
		m.damageBy = {}
		place(m, 8, 8)
	end
	return list
end
local function lost(m) return 100000 - m.hp end
local function refill() advance(30) end -- 기력 가득 + 쿨타임 끝
local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.01) end
-- 피해 기대값: 지금 p1의 공격력(레벨이 오르면 공격력도 오른다) × 배율
local function dmg(power, mult) return math.max(1, math.round(inventory.GetAttackDamage(p1) * power * (mult or 1))) end
-- 시험 자리(들판 한가운데)가 비어 있어야 밀림 · 쫓기 시험이 된다
for x = 240, 340, 4 do
	expect(not townWorld.BoxBlocked(field, x, 200, FEET.halfW, FEET.h), ("시험 자리 (%d, 200) 비어 있음"):format(x))
end

-- ---- 3) 1차 전직(유파 고르기) · 유파 바꾸기 · 2~4차 전직 ----
local elder
for _, n in world.scenes.village.npcs do
	if n.type == ninjutsu.CHANGE_NPC then elder = n end
end
expect(elder ~= nil, "마을에 스승 NPC가 있음")
local function atElder() where[1] = "town_village"; standAt(p1, elder.x, elder.y + 10) end
local function atField() where[1] = "town_field1"; standAt(p1, 250, 200) end
atField()
clear()
handlers.UseNinjutsu(p1, 1, "right")
eq(#sent("NinjutsuCast"), 0, "유파가 없으면(견습) 인술을 못 씀")
eq(data[p1].Job, 0, "새 플레이어 = 견습")
data[p1].Level = 10
handlers.ChooseSchool(p1, "fire")
expect(data[p1].School == "" and noticed(p1, "스승"), "스승 곁이 아니면 전직 못 함")
atElder()
data[p1].Level = 9
clear()
handlers.ChooseSchool(p1, "fire")
expect(data[p1].School == "" and data[p1].Job == 0 and noticed(p1, "Lv.10"), "Lv.10이 안 되면 1차 전직 못 함")
data[p1].Level = 10
clear()
handlers.ChooseSchool(p1, "fire")
expect(data[p1].School == "fire" and data[p1].Job == 1, "Lv.10 + 스승 곁 → 1차 전직(유파에 듦)")
eq(data[p1].Gold, schema.default().Gold, "1차 전직은 엽전을 안 씀")
local su = sent("SchoolUpdated", p1)
expect(#su == 1 and su[1].args[1] == "fire" and su[1].args[3] == 1, "SchoolUpdated(유파, 단계표, 전직 단계)")
clear()
handlers.ChooseSchool(p1, "fire")
eq(#sent("SchoolUpdated", p1), 0, "같은 유파는 무시")
data[p1].Gold = ninjutsu.CHANGE_COST - 1
clear()
handlers.ChooseSchool(p1, "ice")
expect(data[p1].School == "fire" and noticed(p1, "엽전"), "엽전이 모자라면 유파를 못 바꿈")
data[p1].Gold = ninjutsu.CHANGE_COST + 50
handlers.ChooseSchool(p1, "ice")
expect(data[p1].School == "ice" and data[p1].Gold == 50 and data[p1].Job == 1, "스승 곁 + 엽전 → 유파 바꿈(전직 단계는 그대로)")
data[p1].School = "fire"
-- 2차 전직
clear()
handlers.JobAdvance(p1)
expect(data[p1].Job == 1 and noticed(p1, "Lv.30"), "Lv.30이 안 되면 2차 전직 못 함")
data[p1].Level = 30
atField()
handlers.JobAdvance(p1)
eq(data[p1].Job, 1, "스승 곁이 아니면 전직 못 함")
atElder()
clear()
handlers.JobAdvance(p1)
eq(data[p1].Job, 2, "Lv.30 + 스승 곁 → 2차 전직")
su = sent("SchoolUpdated", p1)
expect(#su == 1 and su[1].args[3] == 2, "전직하면 SchoolUpdated")
handlers.JobAdvance(p1)
eq(data[p1].Job, 2, "레벨이 안 되면 3차 전직 못 함")
data[p1].Level = 100
handlers.JobAdvance(p1); handlers.JobAdvance(p1); handlers.JobAdvance(p1)
eq(data[p1].Job, 4, "4차까지만")
-- 아래 시험은 1차 전직 상태(Lv.1 공격력)에서 시작한다
data[p1].Level, data[p1].Job = 1, 1
data[p1].Health = balance.maxHealthFor(1)
atField()

-- ---- 4) 화염구(투사체 → 터짐 → 불붙음) · 기력 · 쿨타임 ----
local list = reset()
local a, b, far = list[1], list[2], list[3]
place(a, 300, 200)
place(b, 312, 206)
place(far, 350, 200)
standAt(p1, 250, 200)
refill()
eq(ninjutsuService.GetEnergy(p1), ninjutsu.ENERGY_MAX, "기력은 최대를 넘지 않음")
clear()
handlers.UseNinjutsu(p1, 1, "right")
local c = sent("NinjutsuCast", p1)
expect(#c == 1 and c[1].args[3] == "fire_ball" and c[1].args[2] == 1 and near(c[1].args[8], 50, 1), "NinjutsuCast(화염구, 날아간 거리 = 50)")
eq(#sent("NinjutsuCast", p2), 1, "같은 씬의 다른 사람도 연출을 받음")
expect(near(ninjutsuService.GetEnergy(p1), ninjutsu.ENERGY_MAX - SK.fire_ball.cost), "기력 소모")
local eu = sent("EnergyUpdated", p1)
expect(#eu == 1 and near(eu[1].args[1], ninjutsu.ENERGY_MAX - SK.fire_ball.cost) and eu[1].args[2] == ninjutsu.ENERGY_MAX and eu[1].args[3] == ninjutsu.ENERGY_REGEN, "EnergyUpdated")
eq(lost(a), 0, "아직 날아가는 중")
handlers.UseNinjutsu(p1, 1, "right")
eq(#sent("NinjutsuCast", p1), 1, "쿨타임 안에는 다시 못 씀")
advance(50 / SK.fire_ball.speed + 0.02)
eq(lost(a), dmg(SK.fire_ball.power), "화염구: 맞은 몬스터")
eq(lost(b), dmg(SK.fire_ball.power), "화염구: 터진 자리 옆 몬스터")
eq(lost(far), 0, "화염구: 범위 밖")
local hitEvent
for _, e in sent("TownMonsterHit", p1) do
	if e.args[2] == a.id then hitEvent = e end
end
expect(hitEvent ~= nil and hitEvent.args[6] == "nin:fire_ball", "피격 출처 = nin:fire_ball")
advance(4)
eq(lost(a), dmg(SK.fire_ball.power), "불씨(f_ember)를 안 배웠으면 더 타지 않음 — 불씨는 09_skills.luau")
-- 기력 회복(초당 REGEN)
local e0 = ninjutsuService.GetEnergy(p1)
advance(2)
expect(near(ninjutsuService.GetEnergy(p1), math.min(ninjutsu.ENERGY_MAX, e0 + 2 * ninjutsu.ENERGY_REGEN)), "기력 회복 속도")
-- 빗나감: 끝까지 날아가 터진다
refill()
clear()
handlers.UseNinjutsu(p1, 1, "left")
eq(sent("NinjutsuCast", p1)[1].args[8], SK.fire_ball.range, "빗나가면 끝까지 날아감")
local before = lost(a)
advance(2)
eq(lost(a), before, "빗나가면 피해 없음")
-- 기력이 모자라면 못 씀
refill()
ninjutsuService.AddEnergy(p1, -(ninjutsu.ENERGY_MAX - 5))
clear()
handlers.UseNinjutsu(p1, 1, "right")
expect(#sent("NinjutsuCast", p1) == 0 and noticed(p1, "기력"), "기력이 모자라면 못 씀")
-- 기본 공격이 맞으면 기력이 찬다
standAt(p1, 290, 200)
local e1 = ninjutsuService.GetEnergy(p1)
handlers.TownAttack(p1, "right")
expect(near(ninjutsuService.GetEnergy(p1), e1 + ninjutsu.ENERGY_PER_HIT, 0.05), "기본 공격 한 마리 맞힘 → 기력 +" .. ninjutsu.ENERGY_PER_HIT)
advance(1)
e1 = ninjutsuService.GetEnergy(p1)
handlers.TownAttack(p1, "left")
expect(near(ninjutsuService.GetEnergy(p1), e1, 0.05), "헛손질은 기력이 안 참")

-- ---- 5) 칸 번호 ----
data[p1].Job = 4 -- 아래 시험은 인술 칸이 모두 열린 상태로
clear()
handlers.UseNinjutsu(p1, 5, "down")
handlers.UseNinjutsu(p1, 1.5, "down")
eq(#sent("NinjutsuCast", p1), 0, "없는 칸 번호는 무시")

-- ---- 6) 얼음: 가시(직선 · 꿰뚫음 · 느려짐) / 빙결(멈춤) ----
data[p1].School = "ice"
list = reset()
local off, beyond
a, b, off, beyond = list[1], list[2], list[3], list[4]
place(a, 290, 200)
place(b, 330, 203)
place(off, 300, 230)
place(beyond, 250 + SK.ice_spike.length + 8, 200)
standAt(p1, 250, 200)
refill()
clear()
data[p1].Ninjutsu = data[p1].Ninjutsu or {}
data[p1].Ninjutsu.i_frost = 1 -- 서리를 배워야 느려진다
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.ice_spike.delay + 0.02)
data[p1].Ninjutsu.i_frost = nil
eq(lost(a), dmg(SK.ice_spike.power), "얼음 가시: 첫 몬스터")
eq(lost(b), dmg(SK.ice_spike.power), "얼음 가시: 꿰뚫고 뒤 몬스터도")
eq(lost(off), 0, "얼음 가시: 옆으로 벗어난 몬스터")
eq(lost(beyond), 0, "얼음 가시: 길이 밖")
local status = sent("TownMonsterStatus", p1)
expect(#status == 2 and status[1].args[3] == "slow" and status[1].args[4] == SK.i_frost.seconds, "TownMonsterStatus(slow) — 서리 1")
-- 느려진 몬스터는 쫓아오는 속도가 mult배(맞았으니 p1을 쫓는다)
local startX = b.x
for _ = 1, 10 do
	advance(0.1)
	heartbeat(0.1)
end
local moved = math.sqrt((b.x - startX) ^ 2 + (b.y - 203) ^ 2)
local expectMove = world.monsterSpeed * combat.MONSTER_CHASE_SPEED * (1 - SK.i_frost.slowPer) * 1
expect(near(moved, expectMove, 0.6), ("느려진 몬스터 1초 이동 %.2f(기대 %.2f)"):format(moved, expectMove))
b.slowUntil = 0 -- 느려짐 끝(서리는 8초라 기다리면 쫓기를 그만두므로 바로 끝낸다)
startX = b.x
local startY = b.y
for _ = 1, 10 do
	advance(0.1)
	heartbeat(0.1)
end
moved = math.sqrt((b.x - startX) ^ 2 + (b.y - startY) ^ 2)
expect(near(moved, world.monsterSpeed * combat.MONSTER_CHASE_SPEED, 0.8), ("느려짐이 풀리면 원래 속도(%.2f)"):format(moved))
-- 멈춤: 멈춘 몬스터는 움직이지도 때리지도 못한다
list = reset()
a = list[1]
place(a, 262, 200)
standAt(p1, 250, 200)
refill()
table.clear(hurts)
townMonsters.Damage("field1", a.id, p1, 1, "test") -- 맞았으니 쫓아와 때리려 한다
townMonsters.Stun("field1", a.id, 2.5)
for _ = 1, 20 do
	advance(0.1)
	heartbeat(0.1)
end
expect(a.x == 262 and a.y == 200 and #hurts == 0, "멈춘 동안(2초) 움직이지도 때리지도 못함")
for _ = 1, 30 do
	advance(0.1)
	heartbeat(0.1)
end
expect(#hurts > 0, "멈춤이 풀리면 다시 공격")

-- ---- 7) 풀: 덩굴 묶기(멈춤) / 치유의 잎 ----
data[p1].School = "plant"
list = reset()
a = list[1]
place(a, 270, 200)
refill()
clear()
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.plant_bind.delay + 0.02)
eq(lost(a), dmg(SK.plant_bind.power), "덩굴 묶기 피해")
local st = sent("TownMonsterStatus", p1)
expect(#st == 1 and st[1].args[3] == "stun" and st[1].args[4] == SK.plant_bind.stun, "TownMonsterStatus(stun)")
reset()
refill()
local maxHealth = balance.maxHealthFor(data[p1].Level)
data[p1].Health = maxHealth
data[p1].Ninjutsu.p_vigor = 1 -- 치유의 잎은 생기를 쓴다(생기 자체의 시험은 09_skills.luau)
ninjutsuService.AddCore(p1, 100)
clear()
local eFull = ninjutsuService.GetEnergy(p1)
handlers.UseNinjutsu(p1, 2, "down")
expect(#sent("NinjutsuCast", p1) == 0 and noticed(p1, "가득") and near(ninjutsuService.GetEnergy(p1), eFull), "체력이 가득하면 치유를 안 씀(기력 그대로)")
data[p1].Health = 10
handlers.UseNinjutsu(p1, 2, "down")
eq(data[p1].Health, 10 + math.round(maxHealth * SK.plant_heal.ratio), "치유의 잎: 최대 체력의 ratio만큼")
expect(near(ninjutsuService.GetEnergy(p1), eFull - SK.plant_heal.cost), "치유: 기력 소모")
data[p1].Health = maxHealth

-- ---- 8) 바위: 가시(밀쳐 내기) / 갑옷(받는 피해 절반) ----
data[p1].School = "rock"
list = reset()
a = list[1]
place(a, 280, 200)
standAt(p1, 250, 200)
refill()
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.rock_spike.delay + 0.02)
eq(lost(a), dmg(SK.rock_spike.power), "바위 가시 피해")
expect(near(a.x, 280 + SK.rock_spike.push, 0.01) and a.y == 200, ("밀려남(x = %.1f)"):format(a.x))
-- 벽 쪽으로는 막힌 곳 앞에서 멈춘다(맵 밖으로 안 나감)
place(a, 6, 200)
standAt(p1, 30, 200)
refill()
handlers.UseNinjutsu(p1, 1, "left")
advance(SK.rock_spike.delay + 0.02)
expect(a.x >= 0 and not townWorld.BoxBlocked(field, a.x, a.y, FEET.halfW, FEET.h) or a.x == 6, "밀려도 막힌 곳에는 안 들어감")
-- 갑옷
list = reset()
a = list[1]
place(a, 258, 200)
standAt(p1, 250, 200)
refill()
local base = math.max(monsterLevels.AttackDamage(a.level) - inventory.GetDefense(p1), 1)
townMonsters.Damage("field1", a.id, p1, 1, "test") -- 맞았으니 쫓아와 때린다
clear()
handlers.UseNinjutsu(p1, 2, "down")
local g = sent("NinjutsuCast", p1)
expect(#g == 1 and g[1].args[3] == "rock_guard" and g[1].args[8] == SK.rock_guard.seconds, "NinjutsuCast(바위 갑옷, 지속 시간)")
table.clear(hurts)
for _ = 1, 25 do
	advance(0.1)
	heartbeat(0.1)
end
expect(#hurts > 0 and hurts[1].n == math.max(1, math.round(base * SK.rock_guard.mult)), ("갑옷 중 받는 피해 절반(기본 %d)"):format(base))
townMonsters.Damage("field1", a.id, p1, 1, "test")
advance(SK.rock_guard.seconds)
table.clear(hurts)
townMonsters.Damage("field1", a.id, p1, 1, "test")
for _ = 1, 25 do
	advance(0.1)
	heartbeat(0.1)
end
expect(#hurts > 0 and hurts[1].n == base, "갑옷이 끝나면 원래 피해")

-- ---- 9) 번개: 연쇄(가까운 적 → 옆 적 둘) / 뇌우(세 번) ----
data[p1].School = "thunder"
list = reset()
local c3, d4
a, b, c3, d4 = list[1], list[2], list[3], list[4]
place(a, 290, 200)
place(b, 320, 210)
place(c3, 350, 200)
place(d4, 420, 200)
standAt(p1, 250, 200)
refill()
clear()
handlers.UseNinjutsu(p1, 1, "up") -- 방향과 상관없이 가까운 적
local bolt = sent("NinjutsuCast", p1)
local ids = bolt[1] and bolt[1].args[9]
expect(ids ~= nil and #ids == 3 and ids[1] == a.id and ids[2] == b.id and ids[3] == c3.id, "번개: 맞힌 순서(가까운 순으로 옮겨 감)")
local f = SK.thunder_bolt.falloff
eq(lost(a), dmg(SK.thunder_bolt.power), "번개: 첫 적")
eq(lost(b), dmg(SK.thunder_bolt.power, f), "번개: 둘째(× falloff)")
eq(lost(c3), dmg(SK.thunder_bolt.power, f * f), "번개: 셋째(× falloff²)")
eq(lost(d4), 0, "번개: 넷째로는 안 옮겨 감")
reset()
refill()
clear()
local eBefore = ninjutsuService.GetEnergy(p1)
handlers.UseNinjutsu(p1, 1, "right")
expect(#sent("NinjutsuCast", p1) == 0 and noticed(p1, "가까이") and near(ninjutsuService.GetEnergy(p1), eBefore), "번개: 적이 없으면 안 씀(기력 그대로)")
handlers.UseNinjutsu(p1, 1, "right")
list = reset()
a = list[1]
place(a, 270, 200)
refill()
handlers.UseNinjutsu(p1, 2, "right")
advance(SK.thunder_storm.delay + 0.02)
eq(lost(a), dmg(SK.thunder_storm.power), "뇌우: 첫 번째")
advance(SK.thunder_storm.interval * (SK.thunder_storm.hits - 1) + 0.02)
eq(lost(a), SK.thunder_storm.hits * dmg(SK.thunder_storm.power), "뇌우: 세 번 모두")

-- ---- 10) 두루마리: 자기 유파 것만 · 단계 +1 · 피해 +15% ----
data[p1].School = "fire"
data[p1].Level, data[p1].Job = 1, 1
data[p1].Ninjutsu, data[p1].SP = {}, { 0, 0, 0, 0 }
inventory.AddItem(p1, "ScrollIce", 1)
inventory.AddItem(p1, "ScrollFire", 2)
local function slotOf(id)
	for _, e in data[p1].Inventory do
		if e.ItemId == id then return e.Tab, e.Slot end
	end
end
clear()
local tab, slot = slotOf("ScrollIce")
handlers.UseItem(p1, tab, slot)
expect(inventory.CountItem(p1, "ScrollIce") == 1 and noticed(p1, "얼음"), "다른 유파 두루마리는 못 씀(안 줄어듦)")
tab, slot = slotOf("ScrollFire")
handlers.UseItem(p1, tab, slot)
eq(data[p1].SP[1], 1, "두루마리 → 지금 전직(1차)의 SP +1")
eq(inventory.CountItem(p1, "ScrollFire"), 1, "두루마리 1개 소모")
data[p1].Job = 2
tab, slot = slotOf("ScrollFire")
handlers.UseItem(p1, tab, slot)
expect(data[p1].SP[2] == 1 and data[p1].SP[1] == 1, "2차 닌자가 쓰면 2차 SP가 오름")
data[p2].School, data[p2].Job = "", 0
inventory.AddItem(p2, "ScrollFire", 1)
clear()
for _, e in data[p2].Inventory do
	if e.ItemId == "ScrollFire" then handlers.UseItem(p2, e.Tab, e.Slot) end
end
expect(inventory.CountItem(p2, "ScrollFire") == 1 and noticed(p2, "유파"), "유파가 없으면 두루마리를 못 씀")

-- ---- 10-1) 3 · 4차 전직 인술: 전직 단계에 따라 칸이 열리고, 유파마다 실제로 쓰인다 ----
data[p1].Level = 100
data[p1].Health = balance.maxHealthFor(100)
for _, school in ninjutsu.SCHOOLS do
	data[p1].School, data[p1].Job, data[p1].Ninjutsu = school, 2, {}
	list = reset()
	place(list[1], 280, 200)
	place(list[2], 300, 206)
	standAt(p1, 250, 200)
	refill()
	clear()
	data[p1].Job = 4
	for slot = 3, 4 do
		local id = ninjutsu.SkillFor(school, slot)
		refill()
		clear()
		local before = lost(list[1])
		handlers.UseNinjutsu(p1, slot, "right")
		local cast = sent("NinjutsuCast", p1)
		expect(#cast == 1 and cast[1].args[3] == id, ("%s: %d번 칸 = %s"):format(school, slot, id))
		advance(3)
		expect(lost(list[1]) > before, id .. ": 앞의 몬스터가 피해를 입음")
	end
end
-- 만개: 쓰면서 내 체력도 회복
data[p1].School, data[p1].Job = "plant", 4
reset()
refill()
data[p1].Health = 100
handlers.UseNinjutsu(p1, 4, "right")
eq(data[p1].Health, 100 + math.round(balance.maxHealthFor(100) * SK.plant_bloom.selfHeal), "만개: 최대 체력의 25% 회복")
data[p1].Level, data[p1].Job, data[p1].School = 1, 1, "fire"
data[p1].Health = balance.maxHealthFor(1)

-- ---- 11) 두루마리 드롭률 ----
local rng = RandomNew(777)
local N, scrolls, perSchool = 30000, 0, {}
for _ = 1, N do
	for _, d in drops.Roll("field", rng) do
		if items[d.item].Type == "Scroll" then
			scrolls += 1
			perSchool[d.item] = (perSchool[d.item] or 0) + 1
		end
	end
end
local want = N * drops.SCROLL_CHANCE
expect(scrolls > want * 0.8 and scrolls < want * 1.2, ("두루마리 %d개(기대 약 %d개)"):format(scrolls, want))
for _, sid in drops.SCROLLS do
	expect((perSchool[sid] or 0) > want / 5 * 0.6, "유파마다 고르게 " .. sid)
end
eq(#drops.Roll("없는지역", rng), 0, "없는 지역은 드롭 없음")

-- ---- 12) 화면에 나오는 글은 도트 글꼴에 있는 글자만(없는 글자는 "?"로 나온다) ----
local font = req("ReplicatedStorage/shared/data/pixelFont.generated").body
local npcTalk = req("ReplicatedStorage/shared/config/npcTalk")
local extra = {}
for _, ch in font.extra do extra[utf8.codepoint(ch)] = true end
local function badChar(text)
	for _, code in utf8.codes(text) do
		local ok = code == 10 or (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163) or extra[code]
		if not ok then return utf8.char(code) end
	end
	return nil
end
local function checkText(text, what)
	local bad = badChar(text)
	expect(bad == nil, ("%s: 글꼴에 없는 글자 [%s] — %s"):format(what, tostring(bad), text))
end
for id, s in SK do
	checkText(s.name, "인술 이름 " .. id)
	checkText(s.desc, "인술 설명 " .. id)
end
for id, info in ninjutsu.SCHOOL_INFO do
	checkText(info.name, "유파 이름 " .. id)
	checkText(info.title, "유파 호 " .. id)
	checkText(info.desc, "유파 설명 " .. id)
end
for id, def in items do
	if typeof(def) == "table" and def.Name then
		checkText(def.Name, "아이템 이름 " .. id)
		checkText(def.Description or "", "아이템 설명 " .. id)
	end
end
for _, group in { npcTalk.LINES or {}, npcTalk.lines or {} } do
	for role, v in group do
		for _, line in (if typeof(v) == "table" then v else { v }) do
			checkText(line, "NPC 대사 " .. role)
		end
	end
end
-- 알림(Notify)으로 보낸 글도 전부
for _, e in sent("Notify") do
	checkText(e.args[1], "알림")
end
