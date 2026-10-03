-- 대쉬(이동기): 설정 정합성(유파마다 무게가 다름 — 불 · 번개 빠름, 얼음 중간, 풀 · 바위 무거움) · 견습 구르기 / 유파 대쉬 고르기
--  · 쿨타임 · 기력 · 벽까지의 거리 · 순수 이동기(피해 · 상태 이상 없음) · 연출 알림 · 이펙트 이름
local world = req("ReplicatedStorage/shared/data/townWorld").data
local townWorld = req("ReplicatedStorage/shared/data/townWorld")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local packets = req("ReplicatedStorage/shared/net/packets")
local fxSheet = req("ReplicatedStorage/shared/data/ninjaFx.generated")
local schema = req("ServerScriptService/server/services/playerSchema")
local D = ninjutsu.DASH

-- ---- 1) 설정 ----
for _, id in { "novice", "fire", "ice", "plant", "rock", "thunder" } do
	local d = D[id]
	expect(d ~= nil, "대쉬 정의 " .. id)
	for _, f in { "windup", "distance", "time", "cooldown", "cost" } do
		expect(typeof(d[f]) == "number", ("%s.%s"):format(id, f))
	end
	expect(typeof(d.name) == "string" and typeof(d.desc) == "string" and typeof(d.feel) == "string", "이름 · 설명 " .. id)
	expect(d.distance > 0 and d.time > 0 and d.cooldown > 0 and d.cost >= 0 and d.cost <= ninjutsu.ENERGY_MAX, "수치 범위 " .. id)
	for _, k in { "start", "path", "finish" } do
		if d.fx[k] then
			expect(fxSheet.rects[d.fx[k]] ~= nil, ("%s 이펙트 %s가 시트에 있음"):format(id, d.fx[k]))
		end
	end
	if d.fx.path then
		expect(typeof(d.fx.pathStep) == "number" and d.fx.pathStep > 0, "길 이펙트 간격 " .. id)
	end
	if d.fx.pathHold then
		expect(fxSheet.rects[d.fx.path].hold ~= nil, "머무는 이펙트에는 머무는 장이 있음 " .. id)
	end
	expect(d.hit == nil and d.trail == nil and d.guard == nil, "대쉬는 순수 이동기 — 피해 · 상태 이상 · 방어 효과 없음 " .. id)
end
-- 무게: 처음부터 끝까지 걸리는 시간(준비 + 이동)으로 한 칸을 가는 빠르기
local function pace(id) return D[id].distance / (D[id].windup + D[id].time) end
expect(pace("thunder") > pace("fire") and pace("fire") > pace("ice"), "번개 > 불 > 얼음(빠른 순)")
expect(pace("ice") > pace("plant") and pace("plant") > pace("rock"), "얼음 > 풀 > 바위")
expect(D.fire.windup == 0 and D.thunder.windup == 0, "불 · 번개는 준비 동작이 없음")
expect(D.plant.windup >= 0.15 and D.rock.windup >= 0.15, "풀 · 바위는 준비 동작이 있음(무거움)")
expect(D.ice.windup < D.plant.windup, "얼음은 중간")
expect(D.rock.cooldown > D.plant.cooldown and D.plant.cooldown > D.ice.cooldown and D.ice.cooldown > D.fire.cooldown, "무거울수록 쿨타임이 김")
do
	local id, def = ninjutsu.DashFor("", 0)
	expect(id == "novice" and def == D.novice, "견습 = 구르기")
	eq((ninjutsu.DashFor("fire", 0)), "novice", "전직 전에는 유파가 있어도 구르기")
	eq((ninjutsu.DashFor("fire", 1)), "fire", "1차 전직부터 유파의 대쉬")
	eq((ninjutsu.DashFor("rock", 4)), "rock", "4차도 그대로")
	eq((ninjutsu.DashFor("water", 2)), "novice", "모르는 유파 → 구르기")
end
expect(packets.UseDash ~= nil and packets.UseDash.Args[1]("left") and not packets.UseDash.Args[1]("north"), "패킷 UseDash")
expect(Enum.KeyCode[ninjutsu.DASH_KEY] ~= nil, "대쉬 키")

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
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end,
	DamagePlayer = function() end,
	Heal = function() return 0 end,
})
MOCK("ServerScriptService/server/services/currencyService", { AddGold = function() end })
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local ninjutsuService = req("ServerScriptService/server/modules/ninjutsuService")
townMonsters.load()
ninjutsuService.load()
expect(handlers.UseDash ~= nil, "UseDash 핸들러 등록")

local field = world.scenes.field1
local X0, Y0 = 250, 200 -- 들판 한가운데(테스트 04와 같은 빈 자리)
for x = X0, X0 + 90, 4 do
	expect(not townWorld.BoxBlocked(field, x, Y0, world.playerFeet.halfW, world.playerFeet.h), ("시험 자리 (%d, %d) 비어 있음"):format(x, Y0))
end
-- 몬스터를 모두 구석으로 치우고 체력을 넉넉히, 둘만 골라 길 위(on) · 길 밖(off)에 놓는다
local function arrange(onX)
	advance(8) -- 앞 시험이 남긴 자리 효과를 흘려보낸다
	local list = townMonsters.Living("field1")
	for _, m in list do
		m.maxHp, m.hp, m.damageBy = 100000, 100000, {}
		m.x, m.y, m.home = 8, 8, V(8, 8)
		m.target, m.aggro, m.stunUntil, m.slowUntil = nil, nil, nil, nil
	end
	local on, off = list[1], list[2]
	on.x, on.y, on.home = onX, Y0, V(onX, Y0)
	off.x, off.y, off.home = onX, Y0 + 40, V(onX, Y0 + 40)
	return on, off
end
local function lost(m) return 100000 - m.hp end
local function become(school, job)
	data[p1].School, data[p1].Job = school, job
	advance(60) -- 쿨타임 끝 · 기력 가득
	clear()
end
local function attackOf() return inventory.GetAttackDamage(p1) end
local function casts() return sent("NinjutsuCast") end
local function status(kind)
	local n = 0
	for _, e in sent("TownMonsterStatus") do
		if e.args[3] == kind then n += 1 end
	end
	return n
end

-- ---- 2) 견습 구르기: 기력 없이, 쿨타임, 효과 없음 ----
standAt(X0, Y0)
become("", 0)
local on, off = arrange(X0 + 20)
local before = ninjutsuService.GetEnergy(p1)
handlers.UseDash(p1, "right")
local c = casts()
expect(#c == 1 and c[1].args[3] == "dash_novice", "구르기 → NinjutsuCast(dash_novice)")
eq(c[1].args[8], D.novice.distance, "막힌 곳이 없으면 끝까지")
expect(c[1].args[6] == 1 and c[1].args[7] == 0, "방향(오른쪽)")
advance(1)
eq(lost(on), 0, "구르기는 피해가 없음")
eq(ninjutsuService.GetEnergy(p1), before, "구르기는 기력을 쓰지 않음")
clear()
handlers.UseDash(p1, "right")
eq(#casts(), 0, "쿨타임 중에는 못 씀")
advance(D.novice.cooldown)
handlers.UseDash(p1, "right")
eq(#casts(), 1, "쿨타임이 지나면 다시")
handlers.UseDash(p1, "north")
eq(#casts(), 1, "모르는 방향은 무시")

-- ---- 3) 벽까지의 거리 ----
eq(ninjutsuService.DashDistance("field1", V(X0, Y0), V(1, 0), 64), 64, "빈 길: 끝까지")
do
	-- 왼쪽으로 계속 가면 가장자리 나무에 막힌다: 막히기 직전 자리에서 대쉬하면 거리가 줄어든다
	local x = X0
	while x > 8 and not townWorld.BoxBlocked(field, x - 2, Y0, world.playerFeet.halfW, world.playerFeet.h) do x -= 2 end
	expect(x > 8, "왼쪽 어딘가에 막힌 곳이 있음")
	eq(ninjutsuService.DashDistance("field1", V(x, Y0), V(-1, 0), 64), 0, "벽 바로 앞: 0")
	eq(ninjutsuService.DashDistance("field1", V(x + 10, Y0), V(-1, 0), 64), 10, "벽 10도트 앞: 10")
end

-- ---- 4) 유파 대쉬: 순수 이동기 — 길 위에 적이 있어도 피해 · 멈춤 · 느려짐 · 밀림이 없다 ----
for _, school in { "fire", "thunder", "ice", "plant", "rock" } do
	become(school, 1)
	on, off = arrange(X0 + 30)
	local x0, y0 = on.x, on.y
	before = ninjutsuService.GetEnergy(p1)
	handlers.UseDash(p1, "right")
	eq(casts()[1].args[3], "dash_" .. school, "유파 대쉬 " .. school)
	eq(casts()[1].args[8], D[school].distance, "거리 " .. school)
	eq(math.round(before - ninjutsuService.GetEnergy(p1)), D[school].cost, "기력 소모 " .. school)
	advance(6)
	eq(lost(on), 0, "길 위의 적도 피해 없음 " .. school)
	eq(#sent("TownMonsterStatus"), 0, "상태 이상 없음 " .. school)
	eq(#sent("TownMonsterHit"), 0, "맞음 알림 없음 " .. school)
	expect(on.x == x0 and on.y == y0, "밀려나지 않음 " .. school)
end

-- ---- 9) 기력이 모자라면 못 씀 ----
become("fire", 1)
ninjutsuService.AddEnergy(p1, -ninjutsu.ENERGY_MAX)
clear()
handlers.UseDash(p1, "right")
expect(#casts() == 0 and noticed("기력"), "기력이 모자라면 대쉬를 못 씀")
