-- 「달의 계승자」 — 구간 던전 「수정 거울숲」(dg1 · 2026-10-21 — 공방 design/dungeon.js · shared sim/rift.luau · room.luau · server world.luau).
--  사용자: "… 수정틈안에 들어가면 던전 입장 멋지게 있고, 파티로 들어갈수도있고 개인으로 들어갈수도있는 문이 하나 있고 … 퀘스트 알림이 일반 느낌표가 아니라 엄청 중요한것처럼 크고 색도다른 느낌표 …
--   메이플에 몬스터파크 처럼 몬스터가 엄청 많이 나오고 … 그 몬스터들은 아이템이나 경험치를 주는게 아니라 다잡고나서 던전 다깼다고 나오면서 일괄 경험치를 지급 … 하루에 한번 … 한국시간 자정에 초기화"
--  보는 것: ① 자료(던전 · 장면 · 물결 · 문 · 퀘스트 · 곰솔) ② 큰 「!」 ③ 방의 셈(무른 몬스터 · 정예 · 잡아도 경험치 · 물건 · 퀘스트의 숫자가 없다) ④ 하루 한 번(한국 시간 자정)
--   ⑤ 서버: 닫힌 문 · 곰솔에게 받기 · 문에 손 대기로 그 자리에서 끝남 · 문으로 맵을 옮기지 않음 · 혼자 입장 · 다 쓰러뜨리면 경험치를 한꺼번에 · 문 앞으로 · 오늘 다시는 안 됨 · 파티 입장
local Rift = req("ReplicatedStorage/shared/lune/sim/rift")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local DG = Rift.DUNGEON

-- ① 자료
eq(#DG.tiers, 1, "던전 하나(30~40 — 수정 거울숲)")
local t = Rift.tier("dg1")
expect(t ~= nil and Rift.isDungeon(t), "dg1 = 던전")
eq(t.name, "수정 거울숲", "이름")
eq(t.lv, 30, "Lv.30부터")
eq(t.lvMax, 40, "Lv.40까지")
eq(DG.perDay, 1, "하루 한 번")
eq(t.door.scene, "r2ah", "문 = 반달네 옛집(빛나는 연못의 수정 틈 안)")
expect(not Rift.isDungeon(Rift.tier("rf1")), "토벌은 던전이 아니다")
local sc = SCENES.scenes.dg1
expect(sc ~= nil and sc.dungeon == "dg1" and sc.rift == "dg1", "장면 dg1(던전)")
eq(#sc.portals, 1, "나가는 문은 하나")
eq(sc.portals[1].to, "r2ah", "그 문은 수정 틈(반달네 옛집)으로")
eq(#(sc.warps or {}), 0, "간이 포탈 없음")
expect(not sc.rest, "쉬는 곳이 아니다")
local waves, elites, total, byWave = 0, 0, 0, {}
for _, m in sc.mobs do
	waves = math.max(waves, m.wave or 0)
	byWave[m.wave] = (byWave[m.wave] or 0) + 1
	total += 1
	eq(m.lv, t.mobLv, "몬스터의 레벨 " .. m.kind)
	expect(COMBAT.mobs[m.kind] ~= nil, "몬스터 " .. m.kind .. "의 수치")
	if m.elite then
		elites += 1
		eq(m.wave, t.waves, "정예는 마지막 물결")
	end
end
eq(waves, t.waves, "물결 수")
eq(elites, 2, "정예 둘")
expect(total >= 60, ("몬스터가 많다(몬스터파크처럼) — %d마리"):format(total))
for w = 1, waves - 1 do
	expect((byWave[w] or 0) >= 12, ("물결 %d에 %d마리"):format(w, byWave[w] or 0))
end
local door = nil
for _, p in SCENES.scenes.r2ah.portals do
	if p.dungeon == "dg1" then
		door = p
	end
end
expect(door ~= nil and door.to == "dg1" and door.done == "dq01", "반달네 옛집에 던전의 문(퀘스트를 끝내야 열린다)")
eq(door.x, t.door.x, "문의 자리")
local q = Quests.def("dq01")
expect(q ~= nil and q.big == true, "퀘스트 「수정 틈의 문」 = 큰 「!」")
eq(q.giver, "woodcutter", "주는 사람 = 곰솔")
eq(q.endNpc, false, "돌려주러 가지 않는다(그 자리에서 끝난다)")
eq(q.lv, 30, "Lv.30에 열린다")
eq(q.steps[1].type, "use", "문에 손 대기")
expect(math.abs(q.steps[1].x - door.x) <= 30, "손 대는 자리 = 그 문 앞")
local cutter = nil
for _, n in SCENES.scenes.ct.npcs do
	if n.id == "woodcutter" then
		cutter = n
	end
end
expect(cutter ~= nil, "곰솔은 은달 항구(건물 밖)에 서 있다")
expect(UI.questMark.big ~= nil and UI.questMark.big ~= UI.questMark.new, "큰 「!」의 그림이 따로 있다")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local bigPart, newPart = KIT.parts[UI.questMark.big], KIT.parts[UI.questMark.new]
expect(bigPart and newPart and bigPart.h > newPart.h and bigPart.w > newPart.w, "큰 「!」가 보통 「!」보다 크다")

-- ② 큰 「!」
do
	local book = {}
	eq(Quests.mark(book, 30, "woodcutter", SCENES.scenes.ct.region, SCENES.scenes.ct.also), "!!", "Lv.30 — 곰솔 머리 위에 큰 「!」")
	expect(Quests.mark(book, 29, "woodcutter", SCENES.scenes.ct.region, SCENES.scenes.ct.also) ~= "!!", "Lv.29에는 아직 없다")
	book.dq01 = { done = true, c = {} }
	expect(Quests.mark(book, 30, "woodcutter", SCENES.scenes.ct.region, SCENES.scenes.ct.also) ~= "!!", "끝낸 뒤에는 없다")
end

-- ③ 방의 셈
do
	local room = Room.new("dg1#1", SCENES.scenes["dg1#1"], Random.new(3))
	expect(room.rift ~= nil and room.rift.dungeon and room.rift.time == DG.time, "던전의 방(제한 시간 = 던전의 것)")
	local rf = Room.new("rf1#90", SCENES.scenes["rf1#90"], Random.new(3))
	local function hpOf(r, kind, elite)
		for _, m in r.mobs do
			if m.kind == kind and (m.elite == true) == elite then
				return m.maxHp, m.lv
			end
		end
		return nil, nil
	end
	local a, al = hpOf(room, "stump", false)
	local b, bl = hpOf(rf, "stump", false)
	if a and b and al == bl then
		eq(a, math.floor(b * DG.mob.hp + 0.5), "던전의 몬스터는 무르다(체력 x " .. DG.mob.hp .. ")")
	end
	local e = hpOf(room, t.elite, true)
	local plain = hpOf(room, t.elite, false)
	if e and plain then
		eq(e, plain * DG.elite.hp, "정예의 체력")
	end
	-- 잡아도 경험치 · 물건 · 퀘스트의 숫자가 없다
	local h = Hero.new(7501, "riven")
	h.level = 34
	local heroes = { [h.id] = h }
	for _ = 1, math.floor((Rift.START + 0.2) / 0.05) do
		room:step(heroes, 0.05)
	end
	for _ = 1, 80 do
		room:step(heroes, 0.05)
	end
	local mob = nil
	for _, m in room.mobs do
		if m.wave == 1 and not m.away and m.state ~= "gone" then
			mob = m
		end
	end
	expect(mob ~= nil, "첫 물결이 나왔다")
	if mob then
		local xp0 = h.xp
		local out = room:damageMob(mob, mob.hp + 1, mob.x, h.id)
		local kills = (typeof(out) == "table" and out.kills) or {}
		local k = kills[1]
		if k then
			eq(k.xp, 0, "잡아도 경험치 없음")
			eq(#k.credit, 0, "퀘스트 · 일일 의뢰의 숫자 없음")
			eq(#k.loot, 0, "물건 없음")
			expect(k.drop == nil, "떨어지는 것 없음")
		end
		eq(h.xp, xp0, "영웅의 경험치 그대로")
	end
end

-- ④ 하루 한 번(한국 시간 자정)
do
	local r = Rift.new()
	local now = 1760000000
	expect(not Rift.dungeonDone(r, "dg1", now), "처음 = 오늘 아직 안 함")
	expect(Rift.dungeonMark(r, "dg1", now), "끝냈다고 적는다")
	expect(Rift.dungeonDone(r, "dg1", now), "오늘 끝냈다")
	expect(not Rift.dungeonMark(r, "dg1", now + 60), "같은 날 두 번은 안 된다")
	local nextDay = now + Daily.left(now) + 1
	expect(not Rift.dungeonDone(r, "dg1", nextDay), "한국 시간 자정이 지나면 다시")
	eq(Daily.dayOf(nextDay), Daily.dayOf(now) + 1, "(자정 = 일일 의뢰와 같은 날의 경계)")
	local back = Rift.unpack(Rift.pack(r))
	expect(Rift.dungeonDone(back, "dg1", now), "저장되고 읽힌다")
	expect(not Rift.dungeonDone(Rift.unpack({ day = 0, used = 0, clears = 0 }), "dg1", now), "예전 저장(던전이 없던 때)도 읽힌다")
	eq(Rift.dungeonXp(35), math.floor(N.xpNeed(35) * DG.pay.need + 0.5), "완료 경험치 = 한 레벨의 절반(Lv.35)")
	expect(Rift.dungeonXp(40) > Rift.dungeonXp(30), "레벨이 높으면 더")
end

-- ⑤ 서버
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
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function newPlayer(id: number, name: string, class: string)
	local p = { UserId = id, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	handlers.Chars(p, "enter", made.id)
	return p, World.session(p)
end
local p, s = newPlayer(7505, "거울숲시험", "riven")
local p2, s2 = newPlayer(7506, "거울숲동료", "axion")
s.hero.level, s2.hero.level = 34, 34
-- 문이 닫혀 있다(퀘스트 전)
World.jump(p, "r2ah")
s.hero.x, s.hero.y = door.x - 10, door.y
local res = handlers.Rift(p, "enter", "dg1", false)
expect(res and not res.ok and res.why == DG.words.closed, "퀘스트를 끝내기 전에는 문이 닫혀 있다 — " .. tostring(res and res.why))
expect(not Quests.portalOpen(s.hero.quests, door), "포탈의 빛도 꺼져 있다")
-- 곰솔에게 받는다(은달 항구 · 건물 밖)
World.jump(p, "ct")
s.hero.x, s.hero.y = cutter.x + 8, cutter.y
handlers.Quest(p, "accept", "dq01")
expect(s.hero.quests.dq01 ~= nil and not s.hero.quests.dq01.done, "곰솔에게서 받았다")
-- 문에 손을 댄다 → 그 자리에서 끝난다 · 문이 열린다
World.jump(p, "r2ah")
s.hero.x, s.hero.y = q.steps[1].x, q.steps[1].y or door.y
table.clear(sent)
handlers.Quest(p, "use", "dq01")
expect(s.hero.quests.dq01 and s.hero.quests.dq01.done, "문에 손을 대자 그 자리에서 끝났다")
local gain = false
for _, f in sent do
	gain = gain or (f.name == "Gain" and f.player == p and f.args[1].quest == q.name)
end
expect(gain, "퀘스트의 보상(경험치)을 알린다")
expect(Quests.portalOpen(s.hero.quests, door), "문이 열렸다(포탈의 빛)")
-- 문으로는 맵을 옮기지 않는다
s.hero.x, s.hero.y = door.x, door.y
eq(handlers.Travel(p, "dg1"), nil, "던전의 문으로 걸어 들어가지 못한다(던전 창으로만)")
eq(s.scene, "r2ah", "그대로 반달네 옛집")
-- 파티로 — 같은 맵에 파티원이 없으면
res = handlers.Rift(p, "enter", "dg1", true)
expect(res and not res.ok and res.why == DG.words.partyNone, "파티 입장 — 함께 들어갈 파티원이 없다")
-- 멀면
s.hero.x = door.x - 200
res = handlers.Rift(p, "enter", "dg1", false)
expect(res and not res.ok, "문에서 멀면 들어가지 못한다")
-- 혼자 입장
s.hero.x = door.x - 10
res = handlers.Rift(p, "view")
expect(res and res.dungeonDone and res.dungeonDone.dg1 == false, "오늘 아직 안 했다")
res = handlers.Rift(p, "enter", "dg1", false)
expect(res and res.ok, "혼자 입장 — " .. tostring(res and res.why))
expect(string.match(s.scene, "^dg1#%d+$") ~= nil, "따로 된 방: " .. tostring(s.scene))
local key = s.scene
local room = World.room(key)
local TICK = 1 / 20
local function tickFor(sec: number)
	for _ = 1, math.floor(sec / TICK + 0.5) do
		World.tick(TICK)
	end
end
s.hero.invuln = 1e9
local level0, xp0 = s.hero.level, s.hero.xp
local want = Rift.dungeonXp(level0)
table.clear(sent)
tickFor(Rift.START + 0.2)
for _ = 1, room.rift.waves do
	tickFor(Rift.STAGGER * 30 + 1)
	local before = s.hero.xp
	for _, mob in room.mobs do
		if mob.wave == room.rift.wave and not mob.away and mob.state ~= "gone" and mob.state ~= "dead" then
			room:damageMob(mob, mob.hp + 1, mob.x, s.hero.id)
		end
	end
	tickFor(3)
	if room.rift.state == "run" then
		eq(s.hero.xp, before, "물결을 쓸어도 경험치가 오르지 않는다(물결 " .. room.rift.wave .. ")")
	end
end
eq(room.rift.state, "clear", "다 쓰러뜨리면 완료")
local paid = nil
for _, f in sent do
	if f.name == "RiftPay" and f.player == p then
		paid = f.args[1]
	end
end
expect(paid ~= nil and paid.dungeon and paid.xp == want, ("「던전 완료!」와 경험치를 한꺼번에 — %s / %d"):format(tostring(paid and paid.xp), want))
local got = 0
do
	local L, x = level0, xp0
	got = -x
	while L < s.hero.level do
		got += N.xpNeed(L)
		L += 1
	end
	got += s.hero.xp
end
eq(got, want, "영웅이 받은 경험치 = 완료 보상")
local viewNow = handlers.Rift(p, "view")
expect(viewNow and viewNow.dungeonDone and viewNow.dungeonDone.dg1 == true, "오늘 끝냈다고 적혔다(서버의 시계로)")
-- back초 뒤 문 앞으로
tickFor(DG.back + 0.5)
eq(s.scene, "r2ah", "끝나면 수정 틈(반달네 옛집)으로")
expect(math.abs(s.hero.x - door.x) <= 60, "그 문 앞에")
expect(not req("ReplicatedStorage/shared/lune/sim/physics").solidBox(SCENES.scenes.r2ah, s.hero.x, s.hero.y), ("나와 선 자리는 땅 속이 아니다 (%s, %s) — 2026-10-21 고침"):format(tostring(s.hero.x), tostring(s.hero.y)))
eq(s.hero.y, door.y, "문이 선 높은 땅의 높이")
-- 오늘 다시는 안 된다
res = handlers.Rift(p, "enter", "dg1", false)
expect(res and not res.ok and res.why == DG.words.done, "오늘은 이미 끝냈다")
-- 파티 입장: 같은 맵 · 문이 열린 파티원과 함께(오늘 안 한 사람만 — 여기서는 동료가 이끈다)
handlers.Party(p2, "invite", p.UserId)
handlers.Party(p, "accept", p2.UserId)
if World.sameParty(p.UserId, p2.UserId) then
	s2.hero.quests.dq01 = { done = true, c = {} }
	World.jump(p2, "r2ah")
	s2.hero.x, s2.hero.y = door.x - 12, door.y
	local partner = newPlayer
	local _ = partner
	local p3, s3 = newPlayer(7507, "거울숲셋째", "reaper")
	s3.hero.level = 35
	s3.hero.quests.dq01 = { done = true, c = {} }
	handlers.Party(p2, "invite", p3.UserId)
	handlers.Party(p3, "accept", p2.UserId)
	World.jump(p3, "r2ah")
	s3.hero.x, s3.hero.y = door.x - 20, door.y
	res = handlers.Rift(p2, "enter", "dg1", true)
	expect(res and res.ok, "파티 입장 — " .. tostring(res and res.why))
	expect(string.match(s2.scene, "^dg1#%d+$") ~= nil, "이끈 사람이 들어갔다")
	if World.sameParty(p2.UserId, p3.UserId) then
		eq(s3.scene, s2.scene, "같은 맵의 파티원이 함께")
	end
	eq(s.scene, "r2ah", "오늘 이미 끝낸 파티원은 따라가지 않는다")
end
