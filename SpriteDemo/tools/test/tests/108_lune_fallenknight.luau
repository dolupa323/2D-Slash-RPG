-- 「달의 계승자」 — 타락한 부단장(망령 기사): 문으로 들어가는 둘째 보스전(2026-10-28).
--  사용자: "다음보스 작업 들어가자" → 고른 것 「① 타락한 부단장 (추천)」(민트 눈 · 곧은 대검 · 뿔피리 · 찢긴 망토)
--  보는 것: ① 자료(문 = 성당 제단 앞의 타는 제단 · 보스 방 기사단 납골당 · 보스 퀘스트 · 동작 열 · 이펙트 · 메인 「타락한 부단장」은 그대로 할 수 있다)
--   ② 들어가기(퀘스트 · 레벨 · 한 주에 노말이나 하드 하나) ③ 패턴마다 피하는 법(물러선다 · 뛴다 · 그대로 선다 · 표시 밖으로) ④ 그 보스만의 예고(mark "knight")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local ITEMS = req("ReplicatedStorage/shared/lune/data/items.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local BossPat = req("ReplicatedStorage/shared/lune/sim/bosspat")
local DT = 1 / 20

-- ---- ① 자료 ----
local b = Weekly.boss("fallenknight")
expect(b ~= nil and b.room == "r2c5" and b.quest == "wq01" and b.door.scene == "r2c4", "타락한 부단장: 방 기사단 납골당 · 보스 퀘스트 · 문은 성당 제단 앞")
local altar = SCENES.scenes.r2c4
local door
for _, p in altar.portals do
	if p.weekly == "fallenknight" then
		door = p
	end
end
expect(door ~= nil and math.abs(door.x - 582) <= 2 and door.y == 10 * 16, "문 = 두 단 위의 타는 제단 자리(36.4칸 · 10줄)")
expect(door ~= nil and door.done == "wq01", "그 문은 보스 퀘스트를 끝내야 열린다")
local room0 = SCENES.scenes.r2c5
expect(room0 ~= nil and room0.bosses ~= nil and room0.bosses[1].kind == "fallenknight" and #room0.mobs == 0, "보스 방에는 그 보스만")
local back
for _, p in room0.portals do
	if p.to == "r2c4" then
		back = p
	end
end
expect(back ~= nil, "보스 방의 왼쪽 문 = 성당 제단 앞으로")
local def = COMBAT.mobs.fallenknight
expect(def ~= nil and def.boss and def.story and def.story.week and def.story.week.normal and def.story.week.hard, "싸움 자료와 노말 · 하드")
eq(def.story.week.normal.lv, 60, "노말 보스 Lv.60")
eq(def.story.week.hard.lv, 80, "하드 보스 Lv.80")
local char = CHARS.chars[def.sprite]
for _, clip in { "idle", "run", "thrust", "cleave", "sweep", "horn", "pages", "leap", "roar", "death" } do
	expect(char and char.clips[clip] ~= nil, "동작 그림 " .. clip)
end
for _, clip in { "fx_thrust", "fx_cleave", "fx_sweep", "fx_horn", "fx_shock", "fx_blade", "fx_bladeHigh", "fx_launch", "fx_page", "fx_pyre", "fx_plunge", "fx_roar", "fx_jump", "fx_land" } do
	expect(char and char.clips[clip] ~= nil, "이펙트 그림 " .. clip)
end
local P = {}
for _, p in def.story.patterns do
	P[p.id] = p
	if p.clip then
		expect(char.clips[p.clip] ~= nil and def.story.anim[p.clip] ~= nil and def.story.anim[p.clip].hit ~= nil, ("%s: 동작 %s과 그 치는 장"):format(p.id, p.clip))
	end
end
for _, id in { "thrust", "cleave", "sweep", "horn", "pages", "leap", "waveLow", "waveHigh", "waves", "judgement", "pyre" } do
	expect(P[id] ~= nil, "패턴 " .. id)
end
expect(P.waveLow.only and P.waveHigh.only, "낮은 · 높은 검기는 연속기 안에서만")
expect(P.waves.chain[1] == "waveLow" and P.waves.chain[2] == "waveHigh" and P.waves.chain[3] == "waveLow" and P.waves.from == 0.5, "검기 세 줄 = 낮게 · 높게 · 낮게(체력 절반 아래)")
expect(P.judgement.chain[1] == "thrust" and P.judgement.chain[2] == "cleave" and P.judgement.chain[3] == "leap", "심판 = 찌르기 → 내려베기 → 도약")
expect(P.waveHigh.wave.lift > 0 and not P.waveLow.wave.lift, "높은 검기는 뜬 발만 맞는다")
expect(P.sweep.zone.from < 0 and P.sweep.zone.up < 57, "땅 가르기: 등 뒤도 치고 · 뛰는 높이(57점)보다 낮다")
expect(P.thrust.zone.up > 57, "찌르기는 뛰어서 넘지 못한다(물러선다)")
expect(P.leap.act >= P.leap.leap.time, "도약: 굳는 시간이 공중에 있는 시간보다 길다(공중에서 끝나지 않는다)")
eq(def.story.mark, "knight", "그 보스만의 예고 모양")
expect((def.story.fall or 0) > 0, "쓰러지는 동작이 다 보일 때까지 치우지 않는다")
local q = Quests.def("wq01")
expect(q ~= nil and q.big and q.after == "r2m9" and q.steps[1].type == "use", "보스 퀘스트: 「타락한 부단장」(메인) 뒤 · 타는 제단에 손 대기")
local main = Quests.def("r2m9")
expect(main ~= nil and main.steps[1].type ~= "boss", "메인 「타락한 부단장」은 보스와 싸우지 않는다(이야기만 — 2026-10-24 규칙)")
local pv
for _, u in ITEMS.UNIQUES or {} do
	if u.id == "vice_pauldron" then
		pv = u
	end
end
expect(pv ~= nil and pv.slot == "shoulder" and pv.stage == 80, "하드의 귀한 장신구 = 검은 맹세 견장(견장 · Lv.80)")

-- ---- ② 들어가기 ----
local now = 1_800_000_000
local h = Hero.new(1, "riven")
Hero.setLevel(h, 58)
h.rift = h.rift or {}
eq(Weekly.canEnter(h, b, "normal", now), Weekly.DATA.words.closed, "보스 퀘스트를 끝내기 전에는 문이 닫혀 있다")
h.quests.wq01 = { done = true, c = {} }
eq(Weekly.canEnter(h, b, "normal", now), nil, "끝냈으면 노말에 들어간다(혼자도)")
expect(Weekly.canEnter(h, b, "hard", now) ~= nil, "하드는 레벨이 모자라다(Lv." .. b.hard.need .. ")")
Hero.setLevel(h, b.hard.need)
eq(Weekly.canEnter(h, b, "hard", now), nil, "레벨이 되면 하드도")
expect(Weekly.mark(h.rift, b.id, "hard", now), "하드 격파를 적는다")
eq(Weekly.canEnter(h, b, "normal", now), Weekly.DATA.words.done, "하드를 격파한 주에는 노말도 끝")
local ws = Weekly.boss("shadowarcher")
h.quests.wq05 = { done = true, c = {} }
eq(Weekly.canEnter(h, ws, "normal", now), nil, "다른 보스(그림자 사수)의 한 주와는 따로")
eq(Weekly.canEnter(h, b, "normal", now + 7 * 86400), nil, "다음 주(목요일 0시 뒤)에는 다시")

-- ---- ③ 패턴마다 피하는 법 ----
local scene = SCENES.scenes.r2c5
local FLOOR = scene.spawn.y
local function bossOf(room)
	for _, m in room.bosses do
		if m.kind == "fallenknight" then
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
local function open(seed: number, hx: number)
	local room = Room.new("r2c5#wn" .. seed, scene, Random.new(seed))
	local p = Hero.new(seed, "riven")
	Hero.setLevel(p, 60)
	p.x, p.y = hx, FLOOR
	p.invuln = 0
	local heroes = { [seed] = p }
	for _ = 1, 30 do
		room:step(heroes, DT)
	end
	return room, p, heroes, bossOf(room)
end
-- 그 패턴을 지금 시작해 seconds 동안(사람은 그 자리 · 그 높이에 붙잡아 둔다 — 뛰는 중 · 서 있음)
local function play(room, p, heroes, m, id: string, x: number, y: number, seconds: number)
	p.x = x
	room:bossBegin(m, idx(id), nil, p)
	local events = {}
	for _ = 1, math.floor(seconds / DT) do
		p.x, p.y = x, y
		p.invuln = 0
		p.hp = p.maxHp or p.hp
		for _, e in room:step(heroes, DT) do
			table.insert(events, e)
		end
		if m.state == "idle" then
			m.rest = math.max(m.rest, 5) -- 그 패턴 하나만 본다
		end
	end
	return events
end
-- (보스는 오른쪽 560점에서 왼쪽을 본다 — 「앞」 = 보스의 왼쪽)
do
	local room, p, heroes, m = open(21, 260)
	expect(m ~= nil and not m.away, "주간의 방에 들어서면 보스가 선다")
	eq(room.weekly and room.weekly.mode, "normal", "#wn = 노말")
end
local function front(m, d: number): number
	return m.x + (if m.dir > 0 then d else -d)
end
do -- 대검 찌르기: 앞의 긴 띠(가슴 높이) — 띠 안이면 맞고 · 뛰어도 맞고 · 띠 끝 밖이면 안 맞는다
	local room, p, heroes, m = open(22, 260)
	eq(hurts(play(room, p, heroes, m, "thrust", front(m, 100), FLOOR, 2.5), 22), 1, "찌르기: 앞 100점에서 맞는다")
	room, p, heroes, m = open(23, 260)
	eq(hurts(play(room, p, heroes, m, "thrust", front(m, 100), FLOOR - 30, 2.5), 23), 1, "찌르기: 뛰어 30점 떠 있어도 맞는다")
	room, p, heroes, m = open(24, 260)
	eq(hurts(play(room, p, heroes, m, "thrust", front(m, 215), FLOOR, 2.5), 24), 0, "찌르기: 띠 끝 밖(앞 215점)이면 안 맞는다")
end
do -- 땅 가르기: 낮게 · 등 뒤도 — 서 있으면 맞고 뛰면 넘는다
	local room, p, heroes, m = open(25, 260)
	eq(hurts(play(room, p, heroes, m, "sweep", front(m, 60), FLOOR, 2.5), 25), 1, "땅 가르기: 서 있으면 맞는다")
	room, p, heroes, m = open(26, 260)
	eq(hurts(play(room, p, heroes, m, "sweep", front(m, -30), FLOOR, 2.5), 26), 1, "땅 가르기: 등 뒤 30점에서도 맞는다")
	room, p, heroes, m = open(27, 260)
	eq(hurts(play(room, p, heroes, m, "sweep", front(m, 60), FLOOR - 30, 2.5), 27), 0, "땅 가르기: 뛰어 떠 있으면 넘는다")
end
do -- 뿔피리: 몸 둘레(양쪽 50점) + 바닥을 따라 양쪽으로 퍼지는 충격파(낮다 — 뛰어넘는다)
	local room, p, heroes, m = open(28, 260)
	eq(hurts(play(room, p, heroes, m, "horn", front(m, 200), FLOOR, 4), 28), 1, "뿔피리: 멀리 서 있어도 충격파에 한 번 맞는다")
	room, p, heroes, m = open(29, 260)
	eq(hurts(play(room, p, heroes, m, "horn", front(m, 200), FLOOR - 30, 4), 29), 0, "뿔피리: 충격파는 뛰어 넘는다")
	room, p, heroes, m = open(30, 260)
	eq(hurts(play(room, p, heroes, m, "horn", front(m, -150), FLOOR, 4), 30), 1, "뿔피리: 등 뒤로도 퍼진다")
end
do -- 검기(체력 절반 아래의 「검기 세 줄」의 조각): 낮은 것은 뛰어넘고 · 높은 것은 그대로 서서 보낸다
	local room, p, heroes, m = open(31, 260)
	eq(hurts(play(room, p, heroes, m, "waveLow", front(m, 220), FLOOR, 3), 31), 1, "낮은 검기: 서 있으면 맞는다")
	room, p, heroes, m = open(32, 260)
	eq(hurts(play(room, p, heroes, m, "waveLow", front(m, 220), FLOOR - 30, 3), 32), 0, "낮은 검기: 뛰면 넘는다")
	room, p, heroes, m = open(33, 260)
	eq(hurts(play(room, p, heroes, m, "waveHigh", front(m, 220), FLOOR, 3), 33), 0, "높은 검기: 그대로 서 있으면 머리 위로 지나간다")
	room, p, heroes, m = open(34, 260)
	eq(hurts(play(room, p, heroes, m, "waveHigh", front(m, 220), FLOOR - 30, 3), 34), 1, "높은 검기: 뛰면 맞는다")
end
do -- 불타는 장부: 내 발밑에 떨어지는 종이 — 그 자리에 서 있으면 맞는다
	local room, p, heroes, m = open(35, 260)
	eq(hurts(play(room, p, heroes, m, "pages", 260, FLOOR, 3), 35), 1, "불타는 장부: 발밑의 종이에 맞는다")
end
do -- 망령 도약: 멀리 있어도 내가 선 자리에 내리꽂는다
	local room, p, heroes, m = open(36, 260)
	local x0 = m.x
	eq(hurts(play(room, p, heroes, m, "leap", 260, FLOOR, 3.5), 36), 1, "망령 도약: 내가 선 자리에 꽂힌다")
	expect(math.abs(m.x - x0) > 100, ("도약해서 다가왔다(%.0f → %.0f)"):format(x0, m.x))
end
do -- 금서의 불(방 전체 · 두 번): 불씨의 자리에 서 있으면 맞고, 불씨 사이(32점)에 서면 안 맞는다
	local lo = BossPat.bounds(scene)
	local sp = P.pyre.spots
	local room, p, heroes, m = open(37, 260)
	m.hp, m.raged = m.maxHp * 0.4, true
	eq(hurts(play(room, p, heroes, m, "pyre", lo + sp.gap / 2 + sp.gap * 3, FLOOR, 4), 37), 1, "금서의 불: 불씨 자리에서 맞는다")
	room, p, heroes, m = open(38, 260)
	m.hp, m.raged = m.maxHp * 0.4, true
	eq(hurts(play(room, p, heroes, m, "pyre", lo + sp.gap * 3 + sp.gap, FLOOR, 4), 38), 0, "금서의 불: 불씨 사이에 서면 안 맞는다")
end

-- ---- ④ 타락한 부단장만의 예고(mark "knight") — 판정의 칠 = 맞는 자리 그대로 · 다른 보스의 그림과 다르다 ----
do
	local BossFx = req("ReplicatedStorage/shared/lune/bossfx")
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
	local floorY, X = 176, 400
	local function fill(c, lo: number, hi: number, top: number, bottom: number)
		for _, r in c.rects do
			if r.a > 0.15 and r.a < 0.3 and r.x == lo and r.w == hi - lo and r.y == top and r.y + r.h == bottom then
				return true
			end
		end
		return false
	end
	for _, id in { "thrust", "cleave", "sweep", "horn" } do
		local p = P[id]
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "knight")
		local lo, hi = X - p.zone.to, X - p.zone.from
		expect(fill(c, lo, hi, floorY - p.zone.up, floorY), ("%s: 판정의 칠 = 맞는 자리(%d ~ %d · 높이 %d)"):format(id, lo, hi, p.zone.up))
		local cOld = canvas()
		BossFx.tell(cOld, X, floorY, -1, p, 0.5, 112, 704, 100, nil, nil)
		expect(#c.rects ~= #cOld.rects, id .. ": 다른 보스의 붉은 자리와 다른 그림")
	end
	for _, id in { "waveLow", "waveHigh" } do
		local p = P[id]
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "knight")
		local x0 = X - p.wave.at
		local x1 = math.clamp(x0 - p.wave.range, 112 - 20, 704 + 20)
		expect(fill(c, math.floor(math.min(x0, x1) + 0.5), math.floor(math.max(x0, x1) + 0.5), floorY - p.wave.up, floorY - (p.wave.lift or 0)), ("%s: 검기의 칠 = 맞는 높이(바닥에서 %d ~ %d)"):format(id, p.wave.lift or 0, p.wave.up))
	end
	do -- 도약: 꽂힐 자리(겨눈 사람에게서 aim만큼 못 미친 몸의 앞)
		local p = P.leap
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, 200, "knight")
		local land = math.clamp(200 + p.leap.aim, 112, 704)
		expect(fill(c, land - p.zone.to, land - p.zone.from, floorY - p.zone.up, floorY), "도약: 꽂힐 자리의 칠")
	end
	for _, grid in { false, true } do
		local c = canvas()
		BossFx.spot(c, 300, floorY, 14, 56, 0.6, nil, nil, "knight", grid)
		local hasEdge = false
		for _, r in c.rects do
			if r.x == 300 - 14 or r.x == 300 + 14 - 1 then
				hasEdge = true
			end
		end
		local cOld = canvas()
		BossFx.spot(cOld, 300, floorY, 14, 56, 0.6, nil, nil, "archer", grid)
		expect(#c.rects > 20 and hasEdge and #c.rects ~= #cOld.rects, (if grid then "민트 불씨" else "떨어지는 종이") .. ": 판정의 양옆(x ± r)을 보이고 그림자 사수의 것과 다르다")
	end
	do -- 머리 위: 칼 표시(다른 보스의 「!」 · 그림자 사수의 조준 십자선과 다르다)
		local c, cA, cX = canvas(), canvas(), canvas()
		local p = P.cleave
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "knight")
		BossFx.tell(cA, X, floorY, -1, p, 0.5, 112, 704, 100, nil, nil)
		BossFx.tell(cX, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "archer")
		local above = function(cc)
			local n = 0
			for _, r in cc.rects do
				if r.y < floorY - 100 - 6 then
					n += 1
				end
			end
			return n
		end
		expect(above(c) > 0 and above(c) ~= above(cA) and above(c) ~= above(cX), "머리 위의 표시가 다른 보스들과 다르다")
	end
end
