-- 「달의 계승자」 — 그림자 사수(그림자 허수아비): 문으로 들어가는 보스전(2026-10-27).
--  사용자: "필드보스라는건 없어요 다 보스전입니다. 파티로 들어가서 하는 레이드에요 / 무너진아치를 문으로 씁시다 빠른이동 포탈을 옮기고"
--   · "혼자도 가능합니다. 못깨면 재도전은 가능하지만 노말,하드 둘중에 하나만 한주에 한번입니다." · "그림자사수는 이 그림자 허수아비로 만들어주세요"
--  보는 것: ① 자료(문 = 그림자 능선 꼭대기의 아치 · 빠른이동 포탈은 그 곁을 비킨다 · 보스 방 · 보스 퀘스트 · 동작 그림 아홉) ② 들어가기(퀘스트 · 레벨 · 한 주에 노말이나 하드 하나)
--   ③ 새 셈 둘: 물러서기(leap.back — 겨눈 사람에게서 멀어지는 쪽으로 뛴다) · 높은 화살(wave.lift — 서 있으면 지나가고 뛰면 맞는다) ④ 낮은 화살은 뛰어서 넘는다
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local BossPat = req("ReplicatedStorage/shared/lune/sim/bosspat")
local DT = 1 / 20

-- ---- ① 자료 ----
local b = Weekly.boss("shadowarcher")
expect(b ~= nil and b.room == "r2b5" and b.quest == "wq05" and b.door.scene == "r2b4", "그림자 사수: 방 능선 너머 · 보스 퀘스트 · 문은 그림자 능선")
local ridge = SCENES.scenes.r2b4
local door
for _, p in ridge.portals do
	if p.weekly == "shadowarcher" then
		door = p
	end
end
expect(door ~= nil and math.abs(door.x - 554) <= 2 and door.y == 7 * 16, "문 = 꼭대기 단(7줄)의 무너진 아치 자리(34.6칸)")
expect(door ~= nil and door.done == "wq05", "그 문은 보스 퀘스트를 끝내야 열린다")
for _, w in ridge.warps do
	if w.y == door.y then
		expect(math.abs(w.x - door.x) >= 60, ("꼭대기의 빠른이동 포탈은 아치에서 비켜 있다(%d점)"):format(math.abs(w.x - door.x)))
	end
end
for _, m in ridge.mobs do
	expect(not (m.y == door.y and math.abs(m.x - door.x) < 48), "아치 곁에 몬스터가 없다")
end
local room0 = SCENES.scenes.r2b5
expect(room0 ~= nil and room0.bosses ~= nil and room0.bosses[1].kind == "shadowarcher" and #room0.mobs == 0, "보스 방에는 그 보스만")
local def = COMBAT.mobs.shadowarcher
expect(def ~= nil and def.boss and def.story and def.story.week and def.story.week.normal and def.story.week.hard, "싸움 자료와 노말 · 하드")
local char = CHARS.chars[def.sprite]
for _, clip in { "idle", "run", "shot", "sky", "trap", "leap", "pierce", "roar", "death" } do
	expect(char and char.clips[clip] ~= nil, "동작 그림 " .. clip)
end
local P = {}
for _, p in def.story.patterns do
	P[p.id] = p
	if p.clip then
		expect(char.clips[p.clip] ~= nil and def.story.anim[p.clip] ~= nil and def.story.anim[p.clip].hit ~= nil, ("%s: 동작 %s과 그 치는 장"):format(p.id, p.clip))
	end
end
for _, id in { "shot", "volley", "rain", "trap", "thorns", "hop", "retreat", "pierce", "pierceHigh", "hunt" } do
	expect(P[id] ~= nil, "패턴 " .. id)
end
expect(P.hop.only and P.hop.leap.back > 0 and not P.hop.zone, "물러서기는 연속기 안에서만 · 뒤로 뛴다 · 치지 않는다")
expect(P.retreat.chain[1] == "hop" and P.retreat.chain[2] == "volley" and P.retreat.reach ~= nil, "가까이 붙으면: 물러서기 → 네 발 연사(2026-10-27)")
expect(P.pierceHigh.wave.lift > 0 and P.pierceHigh.wave.fly > P.pierceHigh.wave.lift, "높은 관통 화살: 뜬 발만 맞는다 · 머리 높이로 그린다")
expect((def.story.fall or 0) > 0, "쓰러지는 동작이 다 보일 때까지 치우지 않는다")
local q = Quests.def("wq05")
expect(q ~= nil and q.big and q.after == "r2m7" and q.steps[1].type == "use", "보스 퀘스트: 「그림자 능선」 뒤 · 아치에 손 대기")

-- ---- ② 들어가기 ----
local now = 1_800_000_000
local h = Hero.new(1, "riven")
Hero.setLevel(h, 52)
h.rift = h.rift or {}
eq(Weekly.canEnter(h, b, "normal", now), Weekly.DATA.words.closed, "보스 퀘스트를 끝내기 전에는 문이 닫혀 있다")
h.quests.wq05 = { done = true, c = {} }
eq(Weekly.canEnter(h, b, "normal", now), nil, "끝냈으면 노말에 들어간다(혼자도)")
expect(Weekly.canEnter(h, b, "hard", now) ~= nil, "하드는 레벨이 모자라다(Lv." .. b.hard.need .. ")")
Hero.setLevel(h, b.hard.need)
eq(Weekly.canEnter(h, b, "hard", now), nil, "레벨이 되면 하드도")
-- 실패하면 다시 들어간다(격파를 적지 않는다) · 격파는 노말이나 하드 하나로 그 주에 끝
eq(Weekly.canEnter(h, b, "normal", now), nil, "실패한 뒤에도 다시 들어간다")
expect(Weekly.mark(h.rift, b.id, "normal", now), "노말 격파를 적는다")
eq(Weekly.canEnter(h, b, "hard", now), Weekly.DATA.words.done, "노말을 격파한 주에는 하드도 끝")
eq(Weekly.canEnter(h, b, "normal", now + 7 * 86400), nil, "다음 주(목요일 0시 뒤)에는 다시")

-- ---- ③ 새 셈 ----
do -- 물러서기: 겨눈 사람의 반대쪽으로 back점(방 안으로 당긴다) · 보는 쪽은 겨눈 쪽 그대로
	local land, d = BossPat.leapTo(P.hop, 400, -1, 460, 96, 704)
	eq(land, 400 - P.hop.leap.back, "오른쪽의 사람에게서 왼쪽으로 뛴다")
	eq(d, 1, "내려앉아서도 사람을 본다")
	land = BossPat.leapTo(P.hop, 150, 1, 90, 96, 704)
	eq(land, math.min(704, 150 + P.hop.leap.back), "왼쪽의 사람에게서 오른쪽으로")
	land = BossPat.leapTo(P.hop, 120, 1, 200, 96, 704)
	eq(land, 96, "벽 밖으로는 뛰지 않는다")
end

local scene = SCENES.scenes.r2b5
local FLOOR = scene.spawn.y
local function bossOf(room)
	for _, m in room.bosses do
		if m.kind == "shadowarcher" then
			return m
		end
	end
	return nil
end
local function hurts(events, id): number
	local n = 0
	for _, e in events do
		if e.type == "hurt" and e.hero == id then
			n += 1
		end
	end
	return n
end
local function idx(id: string): number
	for i, p in def.story.patterns do
		if p.id == id then
			return i
		end
	end
	error(id)
end
-- 방을 열고 보스가 서서 쉬는 때까지(사람은 멀리 — 다가오지 않게 keep 밖)
local function open(seed: number, hx: number)
	local room = Room.new("r2b5#wn" .. seed, scene, Random.new(seed))
	local p = Hero.new(seed, "riven")
	Hero.setLevel(p, 52)
	p.x, p.y = hx, FLOOR
	p.invuln = 0
	local heroes = { [seed] = p }
	for _ = 1, 30 do
		room:step(heroes, DT)
	end
	local m = bossOf(room)
	return room, p, heroes, m
end
-- 그 패턴을 지금 시작해 seconds 동안(사람의 높이는 y로 붙잡아 둔다 — 뛰는 중 · 서 있음)
local function play(room, p, heroes, m, id: string, y: number, seconds: number)
	room:bossBegin(m, idx(id), nil, p)
	local events = {}
	for _ = 1, math.floor(seconds / DT) do
		p.y = y
		p.invuln = 0
		p.hp = p.maxHp or p.hp
		for _, e in room:step(heroes, DT) do
			table.insert(events, e)
		end
		if m.state == "idle" and m.rest > 0 and #(room.waves or {}) == 0 then
			break
		end
		if m.state == "idle" then
			m.rest = math.max(m.rest, 5) -- 그 패턴 하나만 본다(쉬는 틈이 화살이 날아가는 시간보다 짧다 — 2026-10-27)
		end
	end
	return events
end
do
	local room, p, heroes, m = open(11, 260)
	expect(m ~= nil and not m.away, "주간의 방에 들어서면 보스가 선다")
	eq(room.weekly and room.weekly.mode, "normal", "#wn = 노말")
	-- 물러서기: 가까이 붙은 사람에게서 뒤로
	p.x = m.x - 60
	local x0 = m.x
	play(room, p, heroes, m, "hop", FLOOR, 1.6)
	expect(m.x >= x0 + P.hop.leap.back - 2 or m.x >= m.b - 1, ("뒤로 크게 뛰었다(%.0f → %.0f)"):format(x0, m.x))
end
do -- 낮은 화살(조준 사격): 서 있으면 맞고, 떠 있으면 넘는다
	local room, p, heroes, m = open(12, 260)
	local ev = play(room, p, heroes, m, "shot", FLOOR, 4)
	eq(hurts(ev, 12), 1, "서 있으면 낮은 화살에 한 번 맞는다")
	room, p, heroes, m = open(13, 260)
	ev = play(room, p, heroes, m, "shot", FLOOR - 30, 4)
	eq(hurts(ev, 13), 0, "뛰어 떠 있으면 넘는다")
end
do -- 높은 화살(높은 관통 화살 — 새 셈): 서 있으면 머리 위로 지나가고, 뛰면 맞는다
	local room, p, heroes, m = open(14, 260)
	m.hp = m.maxHp * 0.4 -- 체력 절반 아래의 패턴
	m.raged = true
	local ev = play(room, p, heroes, m, "pierceHigh", FLOOR, 4)
	eq(hurts(ev, 14), 0, "서 있으면 머리 위로 지나간다")
	room, p, heroes, m = open(15, 260)
	m.hp, m.raged = m.maxHp * 0.4, true
	ev = play(room, p, heroes, m, "pierceHigh", FLOOR - 30, 4)
	eq(hurts(ev, 15), 1, "뛰어 떠 있으면 맞는다")
end
do -- 네 발 연사(2026-10-27): 화살 넷(서 있으면 넷 다 맞는다 — 간격이 맞은 뒤 다시 맞지 않는 시간보다 길다)
	local room, p, heroes, m = open(16, 260)
	local ev = play(room, p, heroes, m, "volley", FLOOR, 5)
	eq(hurts(ev, 16), 4, "화살 넷")
	expect(P.volley.wave.gap > COMBAT.rules.invuln, ("연사의 간격 %.2f초 > 맞은 뒤 무적 %.2f초(넷이 다 들어간다)"):format(P.volley.wave.gap, COMBAT.rules.invuln))
end

-- ---- 검은 가시밭(즉사 — 2026-10-27 사용자: "보스가 화살이 안맞는 안쪽라인이있잖아 그 안쪽라인을 때리는 즉사패턴도 있어야해") ----
--  안쪽 줄 = 화살이 떠나는 자리(앞 80점)보다 안 · 몸의 뒤. 거기 있으면 체력과 상관없이 쓰러진다 · 뛰어도 못 넘는다 · 밖이면 맞지 않는다 · 생존기(무적)는 막는다
do
	local T = P.thorns
	expect(T.kill == true and T.zone.from <= -P.shot.wave.at and T.zone.to >= P.shot.wave.at, "가시밭은 즉사 · 화살이 떠나는 자리(앞 80점)와 몸의 뒤를 다 덮는다")
	expect(T.reach ~= nil and T.reach >= P.shot.wave.at and T.reach <= T.zone.to, "안쪽 줄에 붙은 사람이 있을 때 쓴다")
	expect(T.zone.up > 57, "가시가 뛰는 높이(57점)보다 높다 — 뛰어서는 못 넘는다")
	expect(T.tell * 92 >= T.zone.to + 5, ("예고 %.1f초 동안 달리면(초당 92점) 가운데에서도 밖으로 나간다"):format(T.tell))
	local function dead(ev, id)
		for _, e in ev do
			if e.type == "hurt" and e.hero == id and e.dead then
				return true
			end
		end
		return false
	end
	local function try(seed: number, dx: number, y: number, guard: boolean?)
		local room, p, heroes, m = open(seed, 260)
		p.maxHp, p.hp = 1000000, 1000000 -- 체력이 아무리 많아도
		p.x = m.x + dx
		if guard then
			Buffs.give(p, "rv_slip", 1, p.x, p.y) -- 리븐의 그림자 숨기(3초 무적)
		end
		local ev = play(room, p, heroes, m, "thorns", y, 3)
		return dead(ev, seed), hurts(ev, seed)
	end
	local d, n = try(31, -60, FLOOR)
	expect(d, "앞의 안쪽 줄(60점)에서는 체력이 백만이어도 쓰러진다")
	d = try(32, 90, FLOOR)
	expect(d, "몸의 뒤(90점)에서도 쓰러진다")
	d = try(33, -40, FLOOR - 50)
	expect(d, "뛰어 50점 떠 있어도 쓰러진다")
	d, n = try(34, -130, FLOOR)
	expect(not d and n == 0, "안쪽 줄 밖(130점)이면 맞지 않는다")
	d, n = try(35, -40, FLOOR, true)
	expect(not d and n == 0, "생존기(무적)가 걸려 있으면 막는다")
end

-- ---- ⑤ 그림자 사수만의 예고(2026-10-27 — 사용자: "지금 패턴표시랑 이펙트랑 너무 똑같잖아 달라야지 다른보슨데") ----
--  표시 모양 = story.mark "archer": 조준선(물결) · 조준경(화살비) · 수정 씨앗(수정 덫) · 조준 십자선(머리 위). 판정의 칠은 맞는 높이(lift ~ up) 그대로
do
	local BossFx = req("ReplicatedStorage/shared/lune/bossfx")
	eq(def.story.mark, "archer", "그림자 사수의 표시 모양")
	local function canvas()
		local c = { rects = {}, color = 0, a = 1 }
		function c:style(v)
			self.color = v
		end
		function c:alpha(v)
			self.a = v
		end
		function c:rect(x, y, w, hh)
			table.insert(self.rects, { x = x, y = y, w = w, h = hh, c = self.color, a = self.a })
		end
		return c
	end
	local floorY = 176
	for _, id in { "shot", "pierceHigh" } do
		local p = P[id]
		local c = canvas()
		BossFx.tell(c, 400, floorY, -1, p, 0.5, 96, 704, 100, nil, "archer")
		local band
		for _, r in c.rects do
			if r.a > 0.1 and r.a < 0.2 and r.w > 100 then
				band = r
			end
		end
		expect(band ~= nil and band.y == floorY - p.wave.up and band.y + band.h == floorY - (p.wave.lift or 0), ("%s: 조준선의 옅은 칠 = 맞는 높이(바닥에서 %d ~ %d)"):format(id, p.wave.lift or 0, p.wave.up))
		local cOld = canvas()
		BossFx.tell(cOld, 400, floorY, -1, p, 0.5, 96, 704, 100, nil, nil)
		expect(#c.rects ~= #cOld.rects, id .. ": 다른 보스의 띠(꺾쇠)와 다른 그림")
	end
	for _, grid in { false, true } do
		local c = canvas()
		BossFx.spot(c, 300, floorY, 14, 50, 0.6, nil, nil, "archer", grid)
		local hasEdge = false
		for _, r in c.rects do
			if r.x == 300 - 14 or r.x == 300 + 14 - 1 then
				hasEdge = true
			end
		end
		expect(#c.rects > 20 and hasEdge, (if grid then "수정 씨앗" else "조준경") .. ": 그리고 판정의 양옆(x ± r)을 보인다")
	end
	-- 검은 가시밭(즉사 — 2026-10-27): 판정의 넓이(몸의 양쪽 104점 · 높이 90) 전체를 짙게 칠하고 양 끝에 굵은 경계를 세운다
	do
		local T = P.thorns
		local c = canvas()
		BossFx.tell(c, 400, floorY, -1, T, 0.5, 96, 704, 100, nil, "archer")
		local lo, hi = 400 - T.zone.to, 400 - T.zone.from
		local fill, edgeL, edgeR = nil, false, false
		for _, r in c.rects do
			if r.a >= 0.2 and r.x == lo and r.w == hi - lo and r.h == T.zone.up then
				fill = r
			end
			if r.x == lo and r.w == 2 and r.h == T.zone.up then
				edgeL = true
			end
			if r.x == hi - 2 and r.w == 2 and r.h == T.zone.up then
				edgeR = true
			end
		end
		expect(fill ~= nil and fill.y == floorY - T.zone.up, ("가시밭: 판정의 넓이(%d ~ %d · 높이 %d)를 짙게 칠한다"):format(lo, hi, T.zone.up))
		expect(edgeL and edgeR, "가시밭: 양 끝에 나가야 할 경계(굵은 세로 줄)")
	end
end
