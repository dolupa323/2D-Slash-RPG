-- 스킬 나무(메이플식 1~4차): 설정 정합성 · 저장 올리기(v13) · 전직할 때 받는 것 · SP로 배우기 · 단축칸 · 레벨업 SP
--  · 핵심 장치(불씨 · 서리 · 생기 · 견고 · 전하) · 1차 새 스킬(가시 씨앗 · 달궈진 칼날 · 얼음 갑옷 · 정전기) · 유파 바꾸기 · 공용 패시브
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local balance = req("ReplicatedStorage/shared/config/balance")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local weapons = req("ReplicatedStorage/shared/config/weapons")
local packets = req("ReplicatedStorage/shared/net/packets")
local fxSheet = req("ReplicatedStorage/shared/data/ninjaFx.generated")
local schema = req("ServerScriptService/server/services/playerSchema")
local SK = ninjutsu.SKILLS

-- ---- 1) 설정 ----
local seenIds = {}
for _, school in ninjutsu.SCHOOLS do
	local tree = ninjutsu.TREE[school]
	expect(tree ~= nil and #tree == #ninjutsu.JOB_LEVELS, "유파마다 전직 4개 " .. school)
	local cores = 0
	for job, list in tree do
		for i, id in list do
			local s = SK[id]
			expect(s ~= nil and s.school == school, ("%s %d차 %s"):format(school, job, id))
			expect(not seenIds[id], "한 스킬은 한 곳에만 " .. id)
			seenIds[id] = true
			eq(ninjutsu.JobOf(id), job, "JobOf " .. id)
			expect(ninjutsu.MaxOf(id) >= 5 and ninjutsu.MaxOf(id) <= 30, "마스터 레벨 " .. id)
			expect(ninjutsu.Belongs(id, school) and not ninjutsu.Belongs(id, if school == "fire" then "ice" else "fire"), "Belongs " .. id)
			if i == 1 then
				expect(ninjutsu.IsActive(id), ("%s %d차 첫 스킬 = 주력기(쓰는 인술)"):format(school, job))
			end
			if s.core then
				cores += 1
				expect(job == 1 and s.kind == "passive", "핵심 장치는 1차 패시브 " .. id)
			end
			if s.fx then
				for _, k in { "shot", "burst", "hit", "burstHit", "self", "ring", "row" } do
					expect(s.fx[k] == nil or fxSheet.rects[s.fx[k]] ~= nil, ("%s 이펙트 %s"):format(id, tostring(s.fx[k])))
				end
			end
		end
	end
	eq(cores, 1, "유파마다 핵심 장치 하나 " .. school)
	expect(#tree[1] >= 3, "1차 고유 스킬 3개 넘게 " .. school)
	local auto = ninjutsu.AutoFor(school, 1)
	expect(#auto == 2 and auto[1] == tree[1][1] and SK[auto[2]].core == true, "1차 전직 때 주력기 + 핵심 장치 " .. school)
	eq(#ninjutsu.TreeFor(school, 1), #tree[1] + #ninjutsu.COMMON[1], "TreeFor = 고유 + 공용 " .. school)
end
for job, list in ninjutsu.COMMON do
	for _, id in list do
		expect(SK[id] ~= nil and SK[id].school == "" and SK[id].kind == "passive", "공용 스킬 " .. id)
		eq(ninjutsu.JobOf(id), job, "공용 JobOf " .. id)
		expect(ninjutsu.Belongs(id, "fire") and ninjutsu.Belongs(id, "rock"), "공용은 모든 유파 " .. id)
	end
end
expect(not ninjutsu.IsActive("f_ember") and ninjutsu.IsActive("fire_ball") and not ninjutsu.IsActive("nothing"), "IsActive")
eq(ninjutsu.Scale("fire_ball", 1), 1, "1레벨 보정")
expect(math.abs(ninjutsu.Scale("fire_ball", ninjutsu.MaxOf("fire_ball")) - (1 + ninjutsu.GROW)) < 1e-9, "마스터 보정 = 1 + GROW")
expect(ninjutsu.Scale("fire_ball", 99) == ninjutsu.Scale("fire_ball", ninjutsu.MaxOf("fire_ball")), "마스터를 넘지 않음")
eq(ninjutsu.LevelOf({ fire_ball = 3 }, "fire_ball"), 3, "LevelOf")
eq(ninjutsu.LevelOf({}, "fire_ball"), 0, "안 배움 = 0")
eq(ninjutsu.LevelOf(nil, "fire_ball"), 0, "표가 없어도 0")
eq(ninjutsu.SpEarned(1, 9), 0, "전직 레벨 전 = 0")
eq(ninjutsu.SpEarned(1, 10), ninjutsu.SP_ON_JOB, "전직한 레벨 = 전직 SP")
eq(ninjutsu.SpEarned(1, 12), ninjutsu.SP_ON_JOB + 2 * ninjutsu.SP_PER_LEVEL, "구간 안에서 오른 레벨마다")
eq(ninjutsu.SpEarned(1, 80), ninjutsu.SP_ON_JOB + 19 * ninjutsu.SP_PER_LEVEL, "다음 전직 레벨 앞까지만")
eq(ninjutsu.SpEarned(2, 35), ninjutsu.SP_ON_JOB + 5 * ninjutsu.SP_PER_LEVEL, "2차 구간")
do
	local d = { Job = 0 }
	expect(not ninjutsu.GrantLevelSp(d, 2) and d.SP == nil, "견습은 레벨업 SP 없음")
	d = { Job = 2, SP = { 1, 0, 0, 0 } }
	expect(ninjutsu.GrantLevelSp(d, 2) and d.SP[2] == 2 * ninjutsu.SP_PER_LEVEL and d.SP[1] == 1, "레벨업 SP는 지금 전직에")
end
for _, name in { "LearnSkill", "SetSkillSlot", "CoreUpdated", "SchoolUpdated" } do
	expect(packets[name] ~= nil, "패킷 등록 " .. name)
end

-- ---- 2) 저장 ----
local fresh = schema.default()
expect(#fresh.SP == 4 and fresh.SP[1] == 0 and #fresh.SkillSlots == ninjutsu.SLOTS and fresh.SkillSlots[1] == "", "새 플레이어: SP 0 · 빈 단축칸")
do
	local old = schema.default()
	old.SchemaVersion, old.SP, old.SkillSlots = 12, nil, nil
	old.School, old.Job, old.Level, old.Ninjutsu = "fire", 1, 12, { fire_ball = 3 }
	schema.migrate(old)
	eq(old.SP[1], ninjutsu.SP_ON_JOB + 2 * ninjutsu.SP_PER_LEVEL, "v13: 1차 구간에서 얻은 SP")
	expect(old.Ninjutsu.fire_ball == 3 and old.Ninjutsu.f_ember == 1, "v13: 옛 두루마리 단계는 레벨로 · 핵심 장치는 배운 것으로")
	expect(old.SkillSlots[1] == "fire_ball" and old.SkillSlots[2] == "", "v13: 단축칸")
	local two = schema.default()
	two.SchemaVersion, two.SP, two.SkillSlots = 12, nil, nil
	two.School, two.Job, two.Level, two.Ninjutsu = "ice", 2, 35, {}
	schema.migrate(two)
	expect(two.SP[1] == ninjutsu.SpEarned(1, 35) and two.SP[2] == ninjutsu.SpEarned(2, 35) and two.SP[3] == 0, "v13: 전직한 구간마다 SP")
	expect(two.SkillSlots[1] == "ice_spike" and two.SkillSlots[2] == "ice_freeze", "v13: 전직마다 주력기가 단축칸에")
	local none = schema.default()
	none.SchemaVersion, none.SP, none.SkillSlots = 12, nil, nil
	schema.migrate(none)
	expect(none.SP[1] == 0 and next(none.Ninjutsu) == nil and none.SkillSlots[1] == "", "v13: 견습은 그대로")
end

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_field1" }
local pos = { [1] = V(0, 0) }
local function standAt(x, y) pos[1] = V(x * world.scale, y * world.scale) end
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
local function hitsFrom(source)
	local n = 0
	for _, e in sent("TownMonsterHit") do
		if e.args[6] == source then n += 1 end
	end
	return n
end
local function status(kind)
	local n = 0
	for _, e in sent("TownMonsterStatus") do
		if e.args[3] == kind then n += 1 end
	end
	return n
end
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
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
local hurts = {}
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end,
	DamagePlayer = function(_, n) table.insert(hurts, n) end,
	Heal = function(player, n)
		local d = data[player]
		local before = d.Health
		d.Health = math.min(balance.maxHealthFor(d.Level), before + n)
		return d.Health - before
	end,
})
MOCK("ServerScriptService/server/services/currencyService", { AddGold = function(player, n) data[player].Gold += n end })
local heartbeat
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function(_, fn) heartbeat = fn; return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local ninjutsuService = req("ServerScriptService/server/modules/ninjutsuService")
townMonsters.load()
ninjutsuService.load()

local elder
for _, n in world.scenes.village.npcs do
	if n.type == ninjutsu.CHANGE_NPC then elder = n end
end
local X0, Y0 = 250, 200
local function atElder() where[1] = "town_village"; standAt(elder.x, elder.y + 10) end
local function atField() where[1] = "town_field1"; standAt(X0, Y0) end
-- 새 캐릭터로 1차 전직(Lv.10)
local function newNinja(school)
	advance(120) -- 앞 시험의 쿨타임 · 자리 효과 · 핵심 장치를 흘려보낸다
	data[p1] = schema.default()
	data[p1].Level = 10
	data[p1].Health = balance.maxHealthFor(10)
	atElder()
	handlers.ChooseSchool(p1, school)
	atField()
	clear()
	table.clear(hurts)
	return data[p1]
end
-- 몬스터를 모두 구석으로 치우고 체력을 넉넉히. 앞에서부터 n마리를 돌려준다.
local function monsters()
	local list = townMonsters.Living("field1")
	for _, m in list do
		m.maxHp, m.hp, m.damageBy = 1000000, 1000000, {}
		m.x, m.y, m.home = 8, 8, V(8, 8)
		m.target, m.aggro, m.stunUntil, m.slowUntil, m.ember, m.frost = nil, nil, nil, nil, nil, nil
	end
	return list
end
local function put(m, x, y) m.x, m.y, m.home = x, y, V(x, y) end
local function lost(m) return 1000000 - m.hp end
local function atk() return inventory.GetAttackDamage(p1) end
local function dmg(power) return math.max(1, math.round(atk() * power)) end
local function slots() return table.concat(data[p1].SkillSlots, ",") end
-- 몬스터 m이 p1을 n번 때릴 때까지 시간을 보낸다
local function getHit(m, n)
	townMonsters.Damage("field1", m.id, p1, 1, "test")
	for _ = 1, 300 do
		if #hurts >= n then break end
		advance(0.1)
		heartbeat(0.1)
	end
end
local SWORD_GAP = balance.TOWN_ATTACK_COOLDOWN * weapons.ClassOf(items.Ninjato).speed

-- ---- 3) 1차 전직: SP · 주력기 · 핵심 장치 · 단축칸 ----
local d = newNinja("fire")
expect(d.Job == 1 and d.School == "fire", "1차 전직")
eq(d.SP[1], ninjutsu.SP_ON_JOB, "전직 SP")
expect(d.Ninjutsu.fire_ball == 1 and d.Ninjutsu.f_ember == 1 and d.Ninjutsu.f_blade == nil, "주력기 · 핵심 장치만 1레벨")
eq(slots(), "fire_ball,,,", "주력기가 1번 칸에")

-- ---- 4) 배우기 · 단축칸 ----
clear()
handlers.LearnSkill(p1, "f_blade")
expect(d.Ninjutsu.f_blade == 1 and d.SP[1] == ninjutsu.SP_ON_JOB - 1, "SP 1로 배움")
eq(slots(), "fire_ball,,,", "패시브는 단축칸에 안 들어감")
local su = sent("SchoolUpdated")
expect(#su == 1 and su[1].args[4][1] == d.SP[1] and su[1].args[5][1] == "fire_ball", "SchoolUpdated(유파, 레벨표, 전직, SP, 단축칸)")
handlers.LearnSkill(p1, "ice_spike")
expect(d.Ninjutsu.ice_spike == nil, "다른 유파 스킬은 못 배움")
handlers.LearnSkill(p1, "fire_burst")
expect(d.Ninjutsu.fire_burst == nil, "아직 안 한 전직의 스킬은 못 배움")
handlers.LearnSkill(p1, "nothing")
handlers.LearnSkill(p1, "fire_ball")
handlers.LearnSkill(p1, "fire_ball")
expect(d.Ninjutsu.fire_ball == 3 and d.SP[1] == 0, "주력기 +2")
clear()
handlers.LearnSkill(p1, "fire_ball")
expect(d.Ninjutsu.fire_ball == 3 and noticed("스킬 포인트"), "SP가 없으면 못 올림")
d.SP[1] = 50
for _ = 1, 30 do handlers.LearnSkill(p1, "f_ember") end
eq(d.Ninjutsu.f_ember, ninjutsu.MaxOf("f_ember"), "마스터 레벨까지만")
eq(d.SP[1], 50 - (ninjutsu.MaxOf("f_ember") - 1), "마스터 뒤에는 SP가 안 줄어듦")
-- 단축칸
handlers.SetSkillSlot(p1, 3, "fire_ball")
eq(slots(), ",,fire_ball,", "칸 옮기기(같은 인술은 한 칸에만)")
handlers.SetSkillSlot(p1, 2, "f_ember")
handlers.SetSkillSlot(p1, 2, "fire_burst")
handlers.SetSkillSlot(p1, 9, "fire_ball")
eq(slots(), ",,fire_ball,", "패시브 · 안 배운 인술 · 없는 칸은 무시")
handlers.SetSkillSlot(p1, 3, "")
eq(slots(), ",,,", "칸 비우기")
clear()
handlers.UseNinjutsu(p1, 1, "right")
eq(#sent("NinjutsuCast"), 0, "빈 칸은 아무 일도 없음")
handlers.SetSkillSlot(p1, 1, "fire_ball")
-- 2차 전직: SP · 2차 주력기
d.Level = 30
atElder()
handlers.JobAdvance(p1)
expect(d.Job == 2 and d.SP[2] == ninjutsu.SP_ON_JOB and d.Ninjutsu.fire_burst == 1, "2차 전직: SP + 2차 주력기")
eq(slots(), "fire_ball,fire_burst,,", "2차 주력기가 빈 칸에")

-- ---- 5) 불: 불씨(쌓임 · 주기 피해 · 최대) + 스킬 레벨 보정 + 달궈진 칼날 ----
d = newNinja("fire")
local list = monsters()
local a, far = list[1], list[2]
put(a, X0 + 50, Y0)
put(far, X0 + 50, Y0 + 60)
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
eq(lost(a), dmg(SK.fire_ball.power), "화염구 1레벨")
eq(a.ember[1].stacks, 1, "불씨 1")
local E = SK.f_ember
local tick1 = math.max(1, math.round(atk() * (E.power + E.perLevel * 1) * 1))
advance(E.seconds + 1)
eq(lost(a), dmg(SK.fire_ball.power) + (E.seconds - 1) * tick1, "불씨: 붙어 있는 동안 1초마다 피해")
expect(hitsFrom("nin:burn") == E.seconds - 1, "불씨 피해 출처 = nin:burn")
eq(lost(far), 0, "안 맞은 적은 불씨 없음")
local settled = lost(a)
advance(5)
eq(lost(a), settled, "불씨가 꺼지면 피해 없음")
-- 쌓임: 꺼지기 전에 다시 맞히면 +1(최대 stacks)
for i = 1, E.stacks + 1 do
	handlers.UseNinjutsu(p1, 1, "right")
	advance(SK.fire_ball.cooldown + 0.1)
	if i <= E.stacks then eq(a.ember[1].stacks, i, ("불씨 %d"):format(i)) end
end
eq(a.ember[1].stacks, E.stacks, "불씨는 최대를 넘지 않음")
-- 스킬 레벨: 화염구 5레벨
list = monsters()
a = list[1]
put(a, X0 + 50, Y0)
d.Ninjutsu.fire_ball, d.Ninjutsu.f_ember = 5, nil
advance(20)
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
eq(lost(a), math.max(1, math.round(atk() * SK.fire_ball.power * ninjutsu.Scale("fire_ball", 5))), "화염구 5레벨 피해 보정")
advance(3)
expect(a.ember == nil or a.ember[1] == nil, "불씨를 안 배웠으면 안 붙음")
-- 달궈진 칼날: 기본 공격이 3번째로 맞을 때
d.Ninjutsu.f_ember, d.Ninjutsu.f_blade = 1, 2
list = monsters()
a = list[1]
put(a, X0 + 10, Y0)
clear()
for i = 1, SK.f_blade.every do
	advance(1)
	handlers.TownAttack(p1, "right")
	eq(hitsFrom("nin:f_blade"), if i == SK.f_blade.every then 1 else 0, ("달궈진 칼날: %d번째 공격"):format(i))
end
expect(a.ember ~= nil and a.ember[1].stacks == 1, "달궈진 칼날: 불씨 1")

-- ---- 6) 얼음: 서리(느려짐 → 5에서 얼어붙음) + 얼음 갑옷 ----
d = newNinja("ice")
expect(d.Ninjutsu.ice_spike == 1 and d.Ninjutsu.i_frost == 1, "빙문 1차: 얼음 가시 + 서리")
list = monsters()
a = list[1]
put(a, X0 + 30, Y0)
local F = SK.i_frost
for i = 1, F.stacks do
	clear()
	handlers.UseNinjutsu(p1, 1, "right")
	advance(SK.ice_spike.delay + 0.05)
	if i < F.stacks then
		expect(a.frost.stacks == i and status("slow") == 1 and status("stun") == 0, ("서리 %d: 느려짐"):format(i))
	else
		expect(a.frost.stacks == 0 and status("stun") == 1, "서리 5: 얼어붙고 다시 0부터")
	end
	put(a, X0 + 30, Y0)
	a.aggro, a.target = nil, nil
	advance(SK.ice_spike.cooldown)
end
advance(F.seconds + 1)
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.ice_spike.delay + 0.05)
eq(a.frost.stacks, 1, "서리는 시간이 지나면 사라지고 다시 1부터")
-- 얼음 갑옷
handlers.LearnSkill(p1, "i_armor")
list = monsters()
a = list[1]
a.level = 50
put(a, X0 + 8, Y0)
local base = math.max(monsterLevels.AttackDamage(50) - inventory.GetDefense(p1), 1)
table.clear(hurts)
getHit(a, 1)
expect(#hurts >= 1 and hurts[1] == math.max(1, math.round(base * (1 - SK.i_armor.perLevel * 1))), ("얼음 갑옷: 받는 피해 감소(기본 %d → %s)"):format(base, tostring(hurts[1])))
expect(a.frost ~= nil and a.frost.stacks >= 1, "얼음 갑옷: 나를 때린 적에게 서리")

-- ---- 7) 풀: 가시 씨앗(박힘 → 터짐) + 생기 + 치유의 잎 ----
d = newNinja("plant")
expect(d.Ninjutsu.p_seed == 1 and d.Ninjutsu.p_vigor == 1 and d.Ninjutsu.plant_heal == nil, "초문 1차: 가시 씨앗 + 생기")
handlers.LearnSkill(p1, "plant_heal")
eq(slots(), "p_seed,plant_heal,,", "치유의 잎을 배우면 빈 칸에")
list = monsters()
local b
a, b, far = list[1], list[2], list[3]
put(a, X0 + 50, Y0)
put(b, X0 + 50, Y0 + 12)
put(far, X0 + 50, Y0 + 70)
clear()
local S = SK.p_seed
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
expect(lost(a) == dmg(S.power) and lost(b) == 0, "씨앗: 처음 닿은 적에게만 박힘")
local V1 = SK.p_vigor.perHit + SK.p_vigor.perLevel * 1
expect(math.abs(ninjutsuService.GetCore(p1) - V1) < 1e-6, "생기: 풀 인술이 맞으면 쌓임")
local cu = sent("CoreUpdated")
expect(#cu == 1 and cu[1].args[1] == "p_vigor" and cu[1].args[3] == SK.p_vigor.stacks, "CoreUpdated(생기, 값, 최대)")
advance(S.fuse)
expect(lost(a) == dmg(S.power) + dmg(S.burstPower) and lost(b) == dmg(S.burstPower), "씨앗: 2초 뒤 둘레에 터짐")
eq(lost(far), 0, "씨앗: 범위 밖")
expect(hitsFrom("nin:p_seed:burst") == 2, "터짐 출처 = nin:p_seed:burst")
expect(math.abs(ninjutsuService.GetCore(p1) - V1 * 3) < 1e-6, "생기: 맞은 횟수만큼")
advance(30)
expect(math.abs(ninjutsuService.GetCore(p1) - V1 * 3) < 1e-6, "생기는 시간이 지나도 남음")
-- 치유의 잎: 생기 30
d.Health = 10
clear()
handlers.UseNinjutsu(p1, 2, "down")
expect(d.Health == 10 and noticed("생기"), "생기가 모자라면 치유를 못 씀")
ninjutsuService.AddCore(p1, 100)
eq(ninjutsuService.GetCore(p1), SK.p_vigor.stacks, "생기 최대")
handlers.UseNinjutsu(p1, 2, "down")
eq(d.Health, 10 + math.round(balance.maxHealthFor(10) * SK.plant_heal.ratio), "치유의 잎: 회복")
eq(ninjutsuService.GetCore(p1), SK.p_vigor.stacks - SK.plant_heal.vigorCost, "치유의 잎: 생기 30 소모")

-- ---- 8) 바위: 견고(맞을 때마다 쌓임 → 받는 피해 감소, 방어 중에는 더 쌓임, 시간이 지나면 사라짐) ----
d = newNinja("rock")
expect(d.Ninjutsu.rock_spike == 1 and d.Ninjutsu.r_firm == 1, "암문 1차: 바위 주먹 + 견고")
handlers.LearnSkill(p1, "rock_guard")
eq(slots(), "rock_spike,rock_guard,,", "바위 갑옷은 1차 스킬")
list = monsters()
a = list[1]
a.level = 50
put(a, X0 + 8, Y0)
base = math.max(monsterLevels.AttackDamage(50) - inventory.GetDefense(p1), 1)
local R = SK.r_firm
table.clear(hurts)
getHit(a, 2)
eq(hurts[1], base, "견고 0: 원래 피해")
eq(hurts[2], math.max(1, math.round(base * (1 - (R.reduce + R.perLevel * 1) * 1))), "견고 1: 피해 감소")
eq(ninjutsuService.GetCore(p1), 2, "두 번 맞음 → 견고 2")
handlers.UseNinjutsu(p1, 2, "down")
table.clear(hurts)
getHit(a, 1)
eq(ninjutsuService.GetCore(p1), 2 + R.guardGain, "바위 갑옷 중에 맞으면 견고가 더 쌓임")
put(a, 8, 8)
a.aggro, a.target = nil, nil
advance(R.seconds + 0.5)
eq(ninjutsuService.GetCore(p1), 0, "견고는 시간이 지나면 사라짐")

-- ---- 9) 번개: 전하(맞을 때마다 쌓임 → 공격이 빨라짐, 3초 안 맞히면 사라짐) + 정전기 ----
d = newNinja("thunder")
expect(d.Ninjutsu.thunder_bolt == 1 and d.Ninjutsu.t_charge == 1, "뇌문 1차: 번개 + 전하")
list = monsters()
a = list[1]
put(a, X0 + 10, Y0)
local T = SK.t_charge
-- 전하가 없을 때: 공격 간격보다 빨리는 못 친다
clear()
handlers.TownAttack(p1, "right")
eq(ninjutsuService.GetCore(p1), 1, "기본 공격이 맞으면 전하 1")
advance(SWORD_GAP * 0.9)
handlers.TownAttack(p1, "right")
eq(ninjutsuService.GetCore(p1), 1, "전하 1로는 아직 간격이 모자람")
ninjutsuService.AddCore(p1, 100)
eq(ninjutsuService.GetCore(p1), T.stacks, "전하 최대")
advance(SWORD_GAP * 0.9)
local before = lost(a)
handlers.TownAttack(p1, "right")
expect(lost(a) > before, "전하가 가득하면 같은 간격으로도 공격이 나감(공격이 빨라짐)")
advance(T.seconds + 0.2)
eq(ninjutsuService.GetCore(p1), 0, "3초 동안 못 맞히면 전하가 사라짐")
-- 인술이 맞아도 전하
handlers.UseNinjutsu(p1, 1, "right")
eq(ninjutsuService.GetCore(p1), 1, "번개가 맞으면 전하")
-- 정전기: 4번째로 맞을 때 한 번 더
handlers.LearnSkill(p1, "t_static")
advance(10)
clear()
local got = 0
for _ = 1, SK.t_static.every * 2 do
	advance(1)
	handlers.TownAttack(p1, "right")
end
expect(hitsFrom("nin:t_static") == 2 or hitsFrom("nin:t_static") == 1, ("정전기: %d번 공격에 추가타 %d번"):format(SK.t_static.every * 2, hitsFrom("nin:t_static")))
got = hitsFrom("nin:t_static")
expect(got >= 1, "정전기 추가타")

-- ---- 10) 유파 바꾸기: 옛 유파에 쓴 SP는 돌려받고, 공용은 그대로 ----
d = newNinja("fire")
handlers.LearnSkill(p1, "f_blade")
handlers.LearnSkill(p1, "f_blade")
handlers.LearnSkill(p1, "c_mastery")
eq(d.SP[1], 0, "SP를 다 씀")
d.Gold = ninjutsu.CHANGE_COST
atElder()
handlers.ChooseSchool(p1, "ice")
expect(d.School == "ice" and d.Gold == 0, "유파 바꿈(엽전)")
eq(d.SP[1], 2, "달궈진 칼날에 쓴 SP 2를 돌려받음(그냥 받은 1레벨은 빼고)")
expect(d.Ninjutsu.c_mastery == 1 and d.Ninjutsu.f_blade == nil and d.Ninjutsu.fire_ball == nil, "공용은 남고 옛 유파 스킬은 없어짐")
expect(d.Ninjutsu.ice_spike == 1 and d.Ninjutsu.i_frost == 1, "새 유파의 주력기 · 핵심 장치")
eq(slots(), "ice_spike,,,", "단축칸은 새 유파로")

-- ---- 11) 공용 패시브: 기력 단련 · 무기 단련 ----
d = newNinja("fire")
clear()
local attack0 = atk()
handlers.LearnSkill(p1, "c_energy")
local eu = sent("EnergyUpdated")
expect(#eu == 1 and eu[1].args[2] == ninjutsu.ENERGY_MAX + SK.c_energy.maxPerLevel, "기력 단련: 최대 기력")
expect(math.abs(eu[1].args[3] - (ninjutsu.ENERGY_REGEN + SK.c_energy.regenPerLevel)) < 1e-9, "기력 단련: 회복")
handlers.LearnSkill(p1, "c_mastery")
eq(atk(), math.round(attack0 * (1 + SK.c_mastery.perLevel)), "무기 단련: 공격력")

-- ---- 12) 스킬 창(globals/ninjutsu.luau buildSkillWindow)의 글 자리: 잘리지 않고 들어가는가 ----
local text = req("Client/ui/pixelText")
local SW = 372
local LIST_W, INFO_W = 168, SW - 190 - 14
local function fits(str, width, lines)
	return text.Fit(str, width, lines) == (if lines == 1 then str else text.Wrap(str, width))
end
for id, sk in SK do
	if ninjutsu.JobOf(id) then
		expect(fits(sk.name, LIST_W - 30, 1), "스킬 창 목록 이름 " .. sk.name)
		expect(fits(("Lv %d/%d"):format(ninjutsu.MaxOf(id), ninjutsu.MaxOf(id)), LIST_W - 30, 1), "스킬 창 레벨 " .. id)
		local kind = if sk.core then "핵심 장치" elseif sk.kind == "passive" then "패시브" else "쓰는 인술"
		expect(fits(("%s · Lv %d/%d"):format(kind, ninjutsu.MaxOf(id), ninjutsu.MaxOf(id)), INFO_W, 1), "스킬 창 종류 줄 " .. id)
		expect(fits(sk.desc, INFO_W, 4), ("스킬 창 설명(4줄) %s: %s"):format(id, sk.desc))
		if ninjutsu.IsActive(id) then
			local cost = if sk.vigorCost then ("생기 %d"):format(sk.vigorCost) else ("기력 %d"):format(sk.cost)
			expect(fits(("%s · 쿨타임 %s초"):format(cost, tostring(sk.cooldown)), INFO_W, 1), "스킬 창 기력 줄 " .. id)
		end
	end
end
for _, sk in { SK.p_vigor, SK.r_firm, SK.t_charge } do
	expect(fits(("%s %d/%d"):format(sk.name, sk.stacks, sk.stacks), 26 * 4 + 4 * 3, 1), "핵심 장치 표시 " .. sk.name)
end
