-- 「달의 계승자」 — 구간 던전 「수정 거울숲」(dg1 · 2026-10-21 — 공방 design/dungeon.js · shared sim/rift.luau · room.luau · server world.luau).
--  사용자: "… 수정틈안에 들어가면 던전 입장 멋지게 있고, 파티로 들어갈수도있고 개인으로 들어갈수도있는 문이 하나 있고 … 퀘스트 알림이 일반 느낌표가 아니라 엄청 중요한것처럼 크고 색도다른 느낌표 …
--   메이플에 몬스터파크 처럼 몬스터가 엄청 많이 나오고 … 그 몬스터들은 아이템이나 경험치를 주는게 아니라 다잡고나서 던전 다깼다고 나오면서 일괄 경험치를 지급 … 하루에 한번 … 한국시간 자정에 초기화"
--  보는 것: ① 자료(던전 · 장면 · 물결 · 문 · 퀘스트 · 곰솔) ② 큰 「!」 ③ 방의 셈(무른 몬스터 · 정예 · 잡아도 경험치 · 물건 · 퀘스트의 숫자가 없다) ④ 하루 한 번(한국 시간 자정)
--   ⑤ 서버: 닫힌 문 · 곰솔에게 받기 · 문에 손 대기로 그 자리에서 끝남 · 문으로 맵을 옮기지 않음 · 혼자 입장 · 다 쓰러뜨리면 경험치를 한꺼번에 · 문 앞으로 · 오늘 다시는 안 됨 · 파티 입장
--  2026-10-22 몰려오기(사용자: "일자맵에다가 가운데로 계속 몬스터 몰려오는 형식으로 해줘 쾌감 느껴지게"): 일자 맵 · 나오는 차례(종류마다 per · 마지막 + 정예) · 양 끝에서 나옴 ·
--   한꺼번에 서 있는 수(cap)를 넘지 않음 · 잡을수록 더 많이 · 더 자주 · 가장 가까운 사람에게 곧장(느린 달팽이도) · 처치한 수를 화면에 보냄
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
eq(#DG.tiers, 2, "던전 둘(30~40 수정 거울숲 · 40~50 검은 거울숲 — 2026-10-24)")
-- 둘째 던전(2026-10-24): 금서고(r2bh)의 문 · 한결의 큰 「!!」 · 그 구간 사냥터 넷이 몰려온다 · 나가는 문은 금서고로
do
	local t2 = Rift.tier("dg2")
	expect(t2 ~= nil and Rift.isDungeon(t2), "dg2 = 던전")
	eq(t2.name, "검은 거울숲", "둘째 던전의 이름")
	eq(t2.lv, 40, "Lv.40부터")
	eq(t2.lvMax, 50, "Lv.50까지")
	eq(t2.door.scene, "r2bh", "문 = 금서고")
	eq(t2.quest, "dq02", "퀘스트 「금서고의 검은 문」")
	local q2 = Quests.def("dq02")
	expect(q2 and q2.big and q2.giver == "hangyeol" and q2.scene == "r2bh", "한결이 주는 큰 「!!」 · 금서고에서 끝난다")
	local s2 = SCENES.scenes.dg2
	expect(s2 and s2.dungeon == "dg2" and s2.swarm == true, "장면 dg2(던전 · 몰려오기)")
	eq(s2.portals[1].to, "r2bh", "나가는 문은 금서고로")
	local door2 = nil
	for _, p in SCENES.scenes.r2bh.portals do
		if p.dungeon == "dg2" then
			door2 = p
		end
	end
	expect(door2 ~= nil and door2.done == "dq02", "금서고의 문은 그 퀘스트를 끝내야 열린다")
	local kinds = {}
	for _, m in s2.mobs do
		kinds[m.kind] = true
		eq(m.lv, t2.mobLv, "둘째 던전의 몬스터 레벨 " .. m.kind)
	end
	expect(kinds.fox and kinds.bud and kinds.quill and kinds.dshard, "여우 · 수정 봉오리 · 수정 고슴도치 · 검은 결정")
	local r = Rift.new()
	local now = 1760000000
	expect(Rift.dungeonMark(r, "dg1", now) and not Rift.dungeonDone(r, "dg2", now), "던전마다 하루 한 번은 따로")
end
local t = Rift.tier("dg1")
expect(t ~= nil and Rift.isDungeon(t), "dg1 = 던전")
eq(t.name, "수정 거울숲", "이름")
eq(t.lv, 30, "Lv.30부터")
eq(t.lvMax, 40, "Lv.40까지")
eq(DG.perDay, 1, "하루 한 번")
eq(t.door.scene, "r2ah", "문 = 반달네 옛집(빛나는 연못의 수정 틈 안)")
expect(not Rift.isDungeon(Rift.tier("rf1")), "토벌은 던전이 아니다")
local sc = SCENES.scenes.dg1
expect(sc ~= nil and sc.dungeon == "dg1" and sc.rift == "dg1" and sc.swarm == true, "장면 dg1(던전 · 몰려오기)")
eq(#sc.portals, 1, "나가는 문은 하나")
eq(sc.portals[1].to, "r2ah", "그 문은 수정 틈(반달네 옛집)으로")
eq(#(sc.warps or {}), 0, "간이 포탈 없음")
expect(not sc.rest, "쉬는 곳이 아니다")
-- 일자 맵(2026-10-22): 땅 윗면이 한 줄(발판 · 턱 없음) · 가운데에 선다
do
	local surface = {}
	for x = 0, sc.w - 1 do
		for y = 0, sc.h - 1 do
			if string.sub(sc.rows[y + 1], x + 1, x + 1) ~= "." then
				surface[y] = (surface[y] or 0) + 1
				break
			end
		end
	end
	local rowsUsed = 0
	for _ in surface do
		rowsUsed += 1
	end
	eq(rowsUsed, 1, "일자 맵 — 땅의 윗면이 한 높이")
	expect(math.abs(sc.spawn.x - sc.w * 16 / 2) <= 16, "가운데에 선다")
	expect(sc.portals[1].x < sc.w * 16 / 4, "나가는 문은 왼쪽 끝")
end
local SW = DG.swarm
local elites, total, byGroup, lastGroup = 0, 0, {}, 0
for i, m in sc.mobs do
	total += 1
	byGroup[m.wave] = (byGroup[m.wave] or 0) + 1
	lastGroup = math.max(lastGroup, m.wave)
	eq(m.lv, t.mobLv, "몬스터의 레벨 " .. m.kind)
	expect(COMBAT.mobs[m.kind] ~= nil, "몬스터 " .. m.kind .. "의 수치")
	expect(m.x <= SW.edge * 16 + 1 or m.x >= (sc.w - SW.edge) * 16 - 1, ("양 끝의 수정 문에서 나온다 (%d번째 x %d)"):format(i, m.x))
	expect(m.range[1] <= 16 and m.range[2] >= (sc.w - 1) * 16, "맵 전체를 달린다")
	if m.elite then
		elites += 1
		expect(i > #sc.mobs - SW.elites, "정예는 맨 끝")
	end
	if i > 1 then
		expect((m.x < sc.w * 8) ~= (sc.mobs[i - 1].x < sc.w * 8), "나오는 쪽은 번갈아")
	end
end
eq(elites, SW.elites, "정예 " .. SW.elites)
eq(total, t.total, "모두 " .. t.total .. "마리")
expect(total >= 150, ("몬스터가 많다(몬스터파크처럼) — %d마리"):format(total))
for g = 1, #t.kinds - 1 do
	eq(byGroup[g], SW.per, ("%d째 종류 %s"):format(g, t.kinds[g]))
end
eq(byGroup[lastGroup], SW.last + SW.elites, "마지막 = 거미 " .. SW.last .. " + 정예 " .. SW.elites)
do
	local cap0, every0 = Rift.swarmPace(0, total)
	local cap1, every1 = Rift.swarmPace(total, total)
	eq(cap0, SW.cap[1], "처음에 한꺼번에 " .. SW.cap[1])
	eq(cap1, SW.cap[2], "끝에는 " .. SW.cap[2])
	expect(every1 < every0, "잡을수록 더 자주 나온다")
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

-- ③-2 몰려오기의 셈: 양 끝에서 나와 가운데의 사람에게 곧장 · 한꺼번에 cap을 넘지 않음 · 잡을수록 더 · 처치한 수
do
	local room = Room.new("dg1#2", SCENES.scenes["dg1#2"], Random.new(5))
	local R = room.rift
	expect(R.swarm == true and R.total == t.total, "몰려오기의 방")
	local h = Hero.new(7502, "riven")
	h.level, h.x, h.y = 34, sc.spawn.x, sc.spawn.y
	h.invuln = 1e9
	local heroes = { [h.id] = h }
	local function aliveNow()
		local n = 0
		for _, m in room.mobs do
			if m.wave and not m.away and m.state ~= "dead" then
				n += 1
			end
		end
		return n
	end
	local maxAlive = 0
	for _ = 1, math.floor((Rift.START + 6) / 0.05) do
		room:step(heroes, 0.05)
		maxAlive = math.max(maxAlive, aliveNow())
	end
	eq(R.state, "run", "싸우는 중")
	eq(maxAlive, SW.cap[1], "처음에는 한꺼번에 " .. SW.cap[1] .. "까지만 서 있다")
	-- 몰려온다: 처음 나온 것들은 가운데 쪽으로 왔다(느린 달팽이도 같은 빠르기 — 여기서는 그루터기)
	local near = 0
	for _, m in room.mobs do
		if m.wave and not m.away and m.state ~= "dead" and m.state ~= "gone" and math.abs(m.x - h.x) < sc.w * 16 / 2 - SW.edge * 16 - 40 then
			near += 1
		end
	end
	expect(near >= 4, ("양 끝에서 가운데로 몰려왔다(%d)"):format(near))
	eq(R.left, R.total, "아직 하나도 못 잡았다 — 남은 수 그대로")
	local view = Rift.view(room)
	expect(view.swarm == true and view.total == t.total and view.left == t.total, "화면에 처치한 수를 보낸다(total - left)")
	-- 달팽이(아주 느린 것)도 몰려오는 빠르기로 온다
	local snail = nil
	for _, m in room.mobs do
		if m.kind == "snail" then
			snail = m
			break
		end
	end
	if snail then
		snail.away, snail.state, snail.x, snail.pace, snail.cd, snail.t = false, "idle", snail.a + 20, 1, 0, 0
		local x0 = snail.x
		room:stepMob(snail, heroes, 1, {})
		expect(snail.x - x0 >= SW.speed * 0.99, ("달팽이도 1초에 %d점쯤 몰려온다 (%.1f)"):format(SW.speed, snail.x - x0))
		snail.away, snail.state, snail.x = true, "gone", snail.homeX
	end
	-- 다 잡는다: 나오는 대로 쓰러뜨린다 — 잡을수록 한꺼번에 더 많이 선다 · 끝나면 완료
	local peak, xp0 = 0, h.xp
	for _ = 1, 4000 do
		room:step(heroes, 0.05)
		local n = aliveNow()
		local killed = (R.next - 1) - n
		local cap = Rift.swarmPace(killed, R.total)
		expect(n <= cap, "한꺼번에 서 있는 수는 그때의 cap을 넘지 않는다")
		peak = math.max(peak, n)
		for _, m in room.mobs do
			if m.wave and not m.away and (m.state == "idle" or m.state == "run" or m.state == "atk") and math.random() < 0.012 then
				room:damageMob(m, m.hp + 1, m.x, h.id)
			end
		end
		if R.state ~= "run" then
			break
		end
	end
	eq(R.state, "clear", "모두 쓰러뜨리면 완료")
	eq(R.left, 0, "남은 몬스터 0")
	expect(peak > SW.cap[1], ("잡을수록 한꺼번에 더 많이 선다(가장 많을 때 %d)"):format(peak))
	eq(h.xp, xp0, "하나하나는 경험치를 주지 않는다")
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
for _ = 1, 600 do
	tickFor(0.5)
	local before = s.hero.xp
	for _, mob in room.mobs do
		if mob.wave and not mob.away and mob.state ~= "gone" and mob.state ~= "dead" and mob.state ~= "spawn" then
			room:damageMob(mob, mob.hp + 1, mob.x, s.hero.id)
		end
	end
	tickFor(0.1)
	if room.rift.state == "run" then
		eq(s.hero.xp, before, "몰려오는 것을 쓸어도 경험치가 오르지 않는다")
	else
		break
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
