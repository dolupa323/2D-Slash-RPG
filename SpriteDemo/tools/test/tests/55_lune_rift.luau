-- 「달의 계승자」 — 수정 틈 토벌(shared/lune/sim/rift.luau — 2026-10-16): 은달 항구의 반복 던전(로스트아크 카오스 던전 · 메이플 몬스터파크를 참고).
--  사용자 2026-10-15: 반복 컨텐츠는 배를 타고 대도시(은달 항구)에 간 뒤의 구간에 둔다.
--  보는 것: 자료(단계 셋 · 장면 · 물결 · 정예 · 나가는 문) · 따로 된 방의 이름(rf1#번호 → rf1의 자료) · 하루 보상 횟수(날이 바뀌면 다시) · 저장 ·
--   방의 셈(기다림 → 물결마다 → 정예 → 완료 · 쓰러진 몬스터는 다시 나오지 않는다 · 제한 시간을 넘기면 실패) · 정예의 체력과 힘 ·
--   서버의 흐름(토벌대장 앞에서만 · 레벨 · 들어가면 rf1#번호 · 같은 맵의 파티원이 함께 · 완료의 보상과 횟수 · 때가 되면 광장으로 · 빈 방은 닫는다)
local Rift = req("ReplicatedStorage/shared/lune/sim/rift")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
local Party = req("ReplicatedStorage/shared/lune/sim/party")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local D = Rift.DATA

-- ---- 1) 자료 ----
eq(#D.tiers, 3, "단계 셋")
eq(D.perDay, 2, "하루 보상 두 번")
expect(D.scene == "ct_office", "토벌대장은 은달 항구의 항구 의뢰소(문 안의 방 — 2026-10-16)")
local wardenHere = false
for _, n in SCENES.scenes.ct_office.npcs or {} do
	wardenHere = wardenHere or n.id == D.npc
end
expect(wardenHere, "의뢰소에 토벌대장이 서 있다")
for i, t in D.tiers do
	local sc = SCENES.scenes[t.id]
	expect(sc ~= nil, t.id .. ": 장면이 있다")
	if sc then
		eq(sc.rift, t.id, t.id .. ": 장면이 제 단계를 안다")
		eq(#sc.portals, 1, t.id .. ": 문은 하나")
		eq(sc.portals[1].to, D.scene, t.id .. ": 그 문은 의뢰소로")
		eq(#(sc.warps or {}), 0, t.id .. ": 간이 포탈 없음")
		expect(not sc.rest, t.id .. ": 쉬는 곳이 아니다")
		local waves, elites, byWave = 0, 0, {}
		for _, m in sc.mobs do
			expect(m.wave ~= nil, t.id .. ": 몬스터마다 물결")
			waves = math.max(waves, m.wave or 0)
			byWave[m.wave] = (byWave[m.wave] or 0) + 1
			if m.elite then
				elites += 1
				eq(m.wave, t.waves, t.id .. ": 정예는 마지막 물결")
				eq(m.kind, t.elite, t.id .. ": 정예의 종류")
			end
			eq(m.lv, t.mobLv, t.id .. ": 몬스터의 레벨")
			expect(COMBAT.mobs[m.kind] ~= nil, t.id .. ": 몬스터 " .. m.kind .. "의 수치가 있다")
		end
		eq(waves, t.waves, t.id .. ": 물결 수")
		eq(elites, D.elite.n, t.id .. ": 정예 수")
		for w = 1, waves do
			expect((byWave[w] or 0) >= 4, t.id .. ": 물결 " .. w .. "에 몬스터가 넉넉하다")
		end
		expect(t.pay.xp > 0 and t.pay.money > 0 and t.pay.dust > 0, t.id .. ": 완료 보상")
		if i > 1 then
			expect(t.lv > D.tiers[i - 1].lv and t.pay.xp > D.tiers[i - 1].pay.xp, t.id .. ": 뒤 단계가 높고 더 준다")
		end
	end
end
-- 따로 된 방의 이름
expect(SCENES.scenes["rf1#7"] == SCENES.scenes.rf1, "rf1#7 = rf1의 자료")
expect(SCENES.scenes["ct#1"] == SCENES.scenes.ct, "#번호는 어느 장면에나 붙는다(방을 나눌 때)")
expect(SCENES.scenes["nothing#1"] == nil, "없는 장면은 없다")
eq(Rift.tierOfKey("rf2#13"), Rift.tier("rf2"), "방의 이름 → 단계")
eq(Rift.tierOfKey("rf2"), nil, "번호가 없으면 토벌의 방이 아니다")
eq(Rift.tierOfKey("ct_office"), nil, "의뢰소는 토벌의 방이 아니다")

-- ---- 2) 하루 보상 횟수 ----
local NOW = 1_800_000_000
local r = Rift.new()
eq(Rift.left(r, NOW), 2, "처음 = 두 번")
expect(Rift.use(r, NOW), "한 번 쓴다")
eq(Rift.left(r, NOW), 1, "남은 것 하나")
expect(Rift.use(r, NOW), "두 번째")
expect(not Rift.use(r, NOW), "세 번째는 없다")
eq(Rift.left(r, NOW), 0, "남은 것 없음")
eq(Rift.left(r, NOW + 86400), 2, "다음 날 = 다시 두 번")
r.clears = 5
local back = Rift.unpack(Rift.pack(r))
eq(back.used, 2, "저장: 쓴 수")
eq(back.day, Daily.dayOf(NOW), "저장: 날")
eq(back.clears, 5, "저장: 끝낸 수")
eq(Rift.unpack(nil).used, 0, "예전 저장 = 오늘 아직 안 함")
eq(Rift.unpack({ used = 99 }).used, D.perDay, "이상한 저장은 줄인다")
local hh0 = Hero.new(5501, "riven")
expect(hh0.rift ~= nil, "새 캐릭터에 토벌의 기록")
eq(Hero.unpack(5501, Hero.pack(hh0)).rift.used, 0, "캐릭터 저장에 실린다")

-- ---- 3) 방의 셈 ----
local t1 = Rift.tier("rf1")
local room = Room.new("rf1#1", SCENES.scenes["rf1#1"], Random.new(5))
expect(room.rift ~= nil and room.rift.state == "wait", "처음 = 기다림")
for _, mob in room.mobs do
	expect(mob.away, "물결이 오기 전에는 몬스터가 없다")
end
local h = Hero.new(5502, "riven")
h.level = 35
h.x, h.y = SCENES.scenes.rf1.spawn.x, SCENES.scenes.rf1.spawn.y
h.invuln = 1e9 -- (맞지 않게 — 셈만 본다)
local heroes = { [h.id] = h }
local function run(sec: number)
	for _ = 1, math.floor(sec / 0.05 + 0.5) do
		room:step(heroes, 0.05)
	end
end
-- 사람이 없으면 흐르지 않는다
for _ = 1, 100 do
	room:step({}, 0.05)
end
eq(room.rift.state, "wait", "아무도 없으면 기다린 채")
run(Rift.START + 0.1)
eq(room.rift.state, "run", "곧 첫 물결")
eq(room.rift.wave, 1, "물결 1")
local n1 = 0
for _, mob in room.mobs do
	if mob.wave == 1 then
		n1 += 1
	end
end
eq(room.rift.left, n1, "남은 몬스터 = 첫 물결의 수")
run(Rift.STAGGER * n1 + 1)
local shown = 0
for _, mob in room.mobs do
	if mob.wave == 1 and mob.state ~= "gone" then
		shown += 1
	end
	if mob.wave ~= 1 then
		expect(mob.away, "다음 물결은 아직 없다")
	end
end
eq(shown, n1, "첫 물결이 다 나타났다")
-- 정예의 체력
for _, mob in room.mobs do
	if mob.elite then
		local plain = nil
		for _, o in room.mobs do
			if not o.elite and o.kind == mob.kind and o.lv == mob.lv then
				plain = o
			end
		end
		if plain then
			eq(mob.maxHp, plain.maxHp * D.elite.hp, "정예의 체력 = 몇 배")
		end
	end
end
-- 물결을 하나씩 쓸어 낸다(쓰러진 몬스터는 다시 나오지 않는다)
local function sweep()
	for _, mob in room.mobs do
		if mob.wave == room.rift.wave and not mob.away and mob.state ~= "gone" and mob.state ~= "dead" then
			room:damageMob(mob, mob.hp + 1, mob.x, h.id)
		end
	end
end
for w = 1, room.rift.waves do
	eq(room.rift.wave, w, "물결 " .. w)
	run(Rift.STAGGER * 12 + 1) -- 다 나타나기를 기다린다
	sweep()
	run(3) -- 쓰러지는 동작 → 사라짐 → 다음 물결
	if w < room.rift.waves then
		expect(room.rift.state == "run", "아직 싸우는 중")
	end
end
eq(room.rift.state, "clear", "마지막 물결 뒤 = 완료")
for _, mob in room.mobs do
	expect(mob.away, "완료 뒤 몬스터가 다시 나오지 않는다")
end
expect(not Rift.due(room), "곧바로 나가지는 않는다")
run(D.back + 0.2)
expect(Rift.due(room), "back초 뒤 의뢰소로")
-- 실패
local room2 = Room.new("rf1#2", SCENES.scenes["rf1#2"], Random.new(6))
local function run2(sec: number)
	for _ = 1, math.floor(sec / 0.25 + 0.5) do
		room2:step(heroes, 0.25)
	end
end
run2(Rift.START + D.time + 1)
eq(room2.rift.state, "fail", "제한 시간을 넘기면 실패")
for _, mob in room2.mobs do
	expect(mob.away, "실패하면 몬스터가 사라진다")
end
run2(Rift.FAIL_BACK + 0.5)
expect(Rift.due(room2), "실패 뒤 조금 있다 의뢰소로")
-- 정예는 더 세게 친다
do
	local room3 = Room.new("rf1#3", SCENES.scenes["rf1#3"], Random.new(7))
	local elite, plain = nil, nil
	for _, mob in room3.mobs do
		if mob.elite then
			elite = mob
		elseif mob.wave == 1 then
			plain = mob
		end
	end
	local a = Hero.new(5503, "axion")
	a.level, a.invuln = 35, 0
	local b = Hero.new(5504, "axion")
	b.level, b.invuln = 35, 0
	plain.lv = elite.lv
	local ev = {}
	room3:hurtHero(ev, a, plain, 1)
	room3:hurtHero(ev, b, elite, 1)
	local da, db = a.maxHp - a.hp, b.maxHp - b.hp
	expect(da > 0 and db > da, ("정예의 한 방이 더 아프다(%d > %d)"):format(db, da))
end
-- 완료의 장비(확률)
do
	local got, rng = 0, Random.new(9)
	for _ = 1, 400 do
		local it = Rift.rollGear(t1, rng, "riven")
		if it then
			got += 1
			expect(it.stage == 30, "장비는 그 단계 몬스터의 레벨대")
		end
	end
	expect(got > 60 and got < 140, ("장비 25%%쯤(%d/400)"):format(got))
end

-- ---- 4) 서버의 흐름 ----
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
expect(handlers.Rift ~= nil, "서버가 토벌을 듣는다")
local function newPlayer(id: number, name: string, class: string)
	local p = { UserId = id, Name = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	handlers.Chars(p, "enter", made.id)
	return p, World.session(p)
end
local p, s = newPlayer(5505, "토벌시험", "riven")
local p2, s2 = newPlayer(5506, "토벌동료", "axion")
s.hero.level, s2.hero.level = 35, 35
local warden = nil
for _, n in SCENES.scenes.ct_office.npcs do
	if n.id == D.npc then
		warden = n
	end
end
World.jump(p, "ct_office")
World.jump(p2, "ct_office")
s.hero.bond.met[D.npc] = true -- 토벌대장과 인사를 나눴다(만나면 열림 — 인사 전의 것은 54가 본다)
s.hero.x, s.hero.y = warden.x + 200, warden.y
local res = handlers.Rift(p, "enter", "rf1")
expect(res and res.ok == false, "멀면 들어가지 못한다")
eq(s.scene, "ct_office", "그대로 의뢰소")
s.hero.x, s.hero.y = warden.x + 10, warden.y
res = handlers.Rift(p, "enter", "rf3")
expect(res and res.ok == false and res.why ~= nil, "레벨이 모자라면 들어가지 못한다(Lv.50)")
res = handlers.Rift(p, "view")
eq(res.left, 2, "오늘 두 번")
-- 파티(같은 맵) → 함께 들어간다
handlers.Party(p, "invite", p2.UserId)
handlers.Party(p2, "accept", p.UserId)
local together = World.sameParty(p.UserId, p2.UserId)
-- 인사를 나누지 않은 파티원은 끌려가지 않는다(2026-10-18 검토) — 먼저 그것을 보고, 인사를 나눈 뒤에 함께 들어간다
s2.hero.bond.met[D.npc] = nil
res = handlers.Rift(p, "enter", "rf1")
if together then
	eq(s2.scene, "ct_office", "토벌대장과 인사를 나누지 않은 파티원은 따라 들어가지 않는다")
end
World.jump(p, "ct_office")
s.hero.x, s.hero.y = warden.x + 10, warden.y
s.stale, s.trust = nil, true
s2.hero.bond.met[D.npc] = true
res = handlers.Rift(p, "enter", "rf1")
expect(res and res.ok, "토벌대장 앞에서 들어간다")
expect(string.match(s.scene, "^rf1#%d+$") ~= nil, "따로 된 방: " .. tostring(s.scene))
if together then
	eq(s2.scene, s.scene, "같은 맵의 파티원이 함께")
end
local key = s.scene
local room4 = World.room(key)
expect(room4 and room4.rift and room4.rift.state == "wait", "방이 열렸다(기다림)")
-- 물결을 서버의 걸음으로 쓸어 낸다
local TICK = 1 / 20
local function tickFor(sec: number)
	for _ = 1, math.floor(sec / TICK + 0.5) do
		World.tick(TICK)
	end
end
s.hero.invuln, s2.hero.invuln = 1e9, 1e9
local xp0, money0, dust0 = s.hero.xp, s.hero.money, s.hero.dust
local level0 = s.hero.level
table.clear(sent)
tickFor(Rift.START + 0.2)
for _ = 1, room4.rift.waves do
	tickFor(Rift.STAGGER * 12 + 1)
	for _, mob in room4.mobs do
		if mob.wave == room4.rift.wave and not mob.away and mob.state ~= "gone" and mob.state ~= "dead" then
			room4:damageMob(mob, mob.hp + 1, mob.x, s.hero.id)
		end
	end
	tickFor(3)
end
eq(room4.rift.state, "clear", "서버의 방도 완료")
local paid, view = nil, false
for _, m in sent do
	if m.name == "RiftPay" and m.player == p then
		paid = m.args[1]
	end
	view = view or m.name == "RiftView"
end
expect(view, "방의 상태를 알렸다")
expect(paid ~= nil and not paid.none, "보상을 알렸다")
if paid then
	eq(paid.xp, Rift.tier("rf1").pay.xp, "경험치 = 그 단계의 것")
	eq(paid.left, 1, "남은 보상 하나")
end
expect(s.hero.level > level0 or s.hero.xp > xp0, "경험치가 들었다")
expect(s.hero.money >= money0 + Rift.tier("rf1").pay.money, "달돈이 들었다")
expect(s.hero.dust >= dust0 + Rift.tier("rf1").pay.dust, "달가루가 들었다")
eq(s.hero.rift.clears, 1, "끝낸 수")
eq(s.acct.ach.c.rift, 1, "업적: 토벌 한 번")
tickFor(D.back + 0.5)
eq(s.scene, "ct_office", "때가 되어 의뢰소로")
expect(math.abs(s.hero.x - warden.x) < 40, "토벌대장 앞에 선다")
tickFor(0.2)
expect(not World.hasRoom(key), "모두 나온 토벌의 방은 닫혔다")
-- 두 번 더: 셋째는 보상 없이
for round = 2, 3 do
	s.hero.x, s.hero.y = warden.x + 10, warden.y
	if s2.scene ~= "ct_office" then
		World.jump(p2, "ct_office")
	end
	res = handlers.Rift(p, "enter", "rf1")
	expect(res and res.ok, "다시 들어간다 " .. round)
	local rr = World.room(s.scene)
	table.clear(sent)
	tickFor(Rift.START + 0.2)
	for _ = 1, rr.rift.waves do
		tickFor(Rift.STAGGER * 12 + 1)
		for _, mob in rr.mobs do
			if mob.wave == rr.rift.wave and not mob.away and mob.state ~= "gone" and mob.state ~= "dead" then
				rr:damageMob(mob, mob.hp + 1, mob.x, s.hero.id)
			end
		end
		tickFor(3)
	end
	local pp = nil
	for _, m in sent do
		if m.name == "RiftPay" and m.player == p then
			pp = m.args[1]
		end
	end
	if round == 3 then
		expect(pp and pp.none, "오늘 보상을 다 받았으면 보상 없이 끝난다")
	else
		expect(pp and not pp.none, "둘째도 보상")
	end
	tickFor(D.back + 0.5)
end
eq(s.hero.rift.clears, 3, "끝낸 수 셋")
-- 나가는 문 → 토벌대장 앞
s.hero.x, s.hero.y = warden.x + 10, warden.y
handlers.Rift(p, "enter", "rf1")
local inKey = s.scene
local door = SCENES.scenes[inKey].portals[1]
s.hero.x, s.hero.y = door.x, door.y
local moved = handlers.Travel(p, D.scene)
expect(moved and moved.scene == "ct_office", "문으로 의뢰소에 나온다")
expect(moved and math.abs(moved.x - warden.x) < 40, "토벌대장 앞으로")
if s2.scene == inKey then
	World.jump(p2, "ct_office")
end
tickFor(0.2)
expect(not World.hasRoom(inKey), "빈 토벌의 방은 닫는다")
-- 장터 거리의 대장장이 · 창고지기(2026-10-16 — 도시에도 제작 · 강화 · 창고): 그 앞에서 제작이 된다
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local ITEMS = req("ReplicatedStorage/shared/lune/data/items.generated")
	local smith, keeper = nil, nil
	for _, n in SCENES.scenes.ct_smith.npcs do
		if ITEMS.NPCDO[n.id] == "smith" then
			smith = n
		end
	end
	for _, n in SCENES.scenes.ct_storage.npcs do
		if ITEMS.NPCDO[n.id] == "store" then
			keeper = n
		end
	end
	expect(smith ~= nil and smith.id ~= "smith", "도시의 대장간에 마을과 다른 대장장이")
	expect(keeper ~= nil and keeper.id ~= "keeper", "도시의 창고에 마을과 다른 창고지기")
	World.jump(p, "ct_smith")
	s.hero.level = 35
	local r = nil
	for _, x in ITEMS.RECIPES do
		if x.id == "c30_weapon" then
			r = x
		end
	end
	expect(r ~= nil, "Lv.30 무기의 제작법")
	if smith and r then
		for _, need in r.needs do
			Bag.give(s.hero, need.item, need.n)
		end
		s.hero.money += r.money
		local before = 0
		for _, it in s.hero.gear do
			if it then
				before += 1
			end
		end
		s.hero.x, s.hero.y = smith.x + 10, smith.y
		handlers.Item(p, "craft", r.id)
		local unmet = 0
		for _, it in s.hero.gear do
			if it then
				unmet += 1
			end
		end
		eq(unmet, before, "인사 전에는 도시의 대장장이가 만들어 주지 않는다(만나면 열림)")
		s.hero.bond.met[smith.id] = true
		handlers.Item(p, "craft", r.id)
		local after = 0
		for _, it in s.hero.gear do
			if it then
				after += 1
			end
		end
		eq(after, before + 1, "도시의 대장장이 앞에서 Lv.30 무기를 만든다")
	end
end
World.removePlayer(p)
World.removePlayer(p2)

-- ---- 5) 화면(그리지 않고): 토벌 창 · 위의 판 · 끝의 판 — 한 번도 돌지 않은 화면 코드를 실제로 돌려 본다 ----
local texts, buttons = {}, {}
local function frame(name)
	local f = { Name = name, Visible = true, BackgroundTransparency = 0, ImageTransparency = 0, Position = nil }
	function f:Destroy() end
	return f
end
local COLOR = setmetatable({}, { __index = function(_, k) return k end })
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	M = { small = 10, smallLine = 14, body = 12, button = 26 },
	measure = function(t) return #t * 3 end,
	text = function(_, value, x, y, width, opts)
		local t = { value = value, x = x, y = y, width = width, shown = true }
		function t.set(_, val) t.value = val end
		function t.color(_, c) t.tint = c end
		function t.move(_, nx, ny) t.x, t.y = nx, ny end
		table.insert(texts, t)
		return t
	end,
	panel = function() return frame("Panel") end,
	line = function() return frame("Line") end,
	smallIcon = function(_, name) local f = frame("Icon"); f.icon = name; return f end,
	setWorldIcon = function(label, name) label.icon = name end,
	button = function(_, label, x, y, w, fn, opts)
		local b = { frame = frame("Button"), label = label, click = fn, enabled = true }
		function b.setEnabled(_, on) b.enabled = on end
		function b.setText(_, val) b.label = val end
		table.insert(buttons, b)
		return b
	end,
})
MOCK("Client/lune/stage", { REF_W = 960, REF_H = 540, place = function(_, name) return frame(name) end })
local RiftWindow = req("Client/lune/ui/riftWindow")
local ww, wh = RiftWindow.size()
expect(wh + 44 + 14 + 16 <= 432, ("토벌 창이 스마트폰의 화면 틀(432)에 들어간다 — %d"):format(wh + 74))
local entered = {}
local riftState = { left = 2, clears = 0 }
local ctx2 = {
	me = function() return { level = 45 } end,
	rift = function() return riftState end,
	riftDo = function(action, id) table.insert(entered, { action, id }) end,
}
local wv = RiftWindow.build(frame("Body"), ctx2, ww, wh)
wv.refresh()
eq(#buttons, #D.tiers, "단계마다 「입장」")
expect(buttons[1].enabled and buttons[2].enabled and not buttons[3].enabled, "Lv.45 = 둘째 단계까지 열림")
buttons[2].click()
expect(entered[1] and entered[1][1] == "enter" and entered[1][2] == "rf2", "「입장」 → 서버에 그 단계")
local mobLine = false
for _, t in texts do
	mobLine = mobLine or (typeof(t.value) == "string" and string.find(t.value, D.elite.name .. " ", 1, true) ~= nil)
end
expect(mobLine, "몬스터 줄에 「정예 ○○」")
riftState = { left = 0, clears = 2 }
wv.refresh()
local noPay = false
for _, t in texts do
	noPay = noPay or t.value == D.words.noPay
end
expect(noPay, "오늘 보상을 다 받으면 그 말")
-- 위의 판 · 끝의 판
local RiftView = req("Client/lune/riftView")
RiftView.init(frame("Hud"))
RiftView.enter(nil)
expect(RiftView.box.Visible == false, "토벌의 방이 아니면 숨긴다")
RiftView.enter({ tier = "rf1", state = "wait", wave = 0, waves = 4, left = 0, t = 0, time = D.time, after = 0 })
expect(RiftView.box.Visible == true, "토벌의 방이면 보인다")
eq(RiftView.what.value, D.words.ready, "기다림 = 「곧 몰려온다」")
RiftView.set({ tier = "rf1", state = "run", wave = 2, waves = 4, left = 6, t = 70, time = D.time, after = 0 })
expect(string.find(RiftView.what.value, "2/4", 1, true) ~= nil and string.find(RiftView.what.value, "6", 1, true) ~= nil, "물결 2/4 · 남은 6: " .. RiftView.what.value)
eq(RiftView.clock.value, "3:50", "남은 시간 = 5:00 - 1:10")
RiftView.update(1.2)
eq(RiftView.clock.value, "3:48", "받은 뒤로 시계가 흐른다(초가 바뀌면 다시 그린다)")
RiftView.set({ tier = "rf1", state = "run", wave = 4, waves = 4, left = 3, t = 250, time = D.time, after = 0 })
expect(string.find(RiftView.what.value, D.words.eliteWave, 1, true) == 1, "마지막 물결 = 「정예」")
eq(RiftView.clock.tint, "red", "1분이 안 남으면 빨강")
RiftView.set({ tier = "rf1", state = "clear", wave = 4, waves = 4, left = 0, t = 260, time = D.time, after = 0 })
expect(RiftView.endBox.Visible, "완료 = 가운데의 판")
RiftView.pay({ xp = 1960, money = 1835, dust = 162, gear = { slot = "weapon" }, gearName = "Lv.30 큰 도끼", left = 1 })
eq(RiftView.rows[4].text.value, "Lv.30 큰 도끼", "받은 장비의 이름")
expect(RiftView.rows[2].icon.Visible and RiftView.rows[2].icon.icon == "coin", "달돈 줄의 그림")
expect(string.find(RiftView.back.value, tostring(D.back), 1, true) ~= nil, "「30초 뒤 의뢰소로」: " .. RiftView.back.value)
RiftView.pay({ none = true, left = 0 })
eq(RiftView.rows[1].text.value, D.words.noPay, "보상이 없으면 그 말")
RiftView.set({ tier = "rf1", state = "fail", wave = 2, waves = 4, left = 5, t = 300, time = D.time, after = 0 })
eq(RiftView.title.value, D.words.fail, "실패의 판")
