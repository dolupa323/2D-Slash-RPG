-- 「달의 계승자」 — 용암 거인: 넷째 보스전 · Lv.150 · 세 페이즈(왼팔 → 오른팔 → 몸통) · 걷지 않는다(2026-11-04).
--  사용자(11-03): "1,2,3 페로 나눠서 왼팔 깨고 … 오른팔 깨고 … 최종 몸통형태고 이 보스는 움직이지 않는 허수아비에 피가 많은 피돼지인 형태 … 반드시 파훼해야하는 공통 기믹 … 실패하면 전멸기"
--   → (11-04) "이제 용암거인 마저 만들면된다". 셈 = sim/lavagim.luau(방 sim/room.luau가 gimmick.mod로 고른다)
--  2026-11-04 다시(혼테일처럼 방 셋 — 사용자 "첫번째 거인의 손은 맵의 좌측, 혹은 우측 끝에서나오는거야 … 마지막 방은 거대한 얼굴 몸통이 나오는거야 손까지 제한시간이랑 데스카운트는 세방이 합쳐서 하나야"):
--   첫 굴 r3d5(손이 오른쪽 끝에서 — 보스 자리 = 오른쪽 벽 512) → 둘째 굴 r3d6(왼쪽 끝에서 — 0) → 분화구 r3d7(얼굴 · 몸통 — 256). 방마다 그 부위부터 선다.
--  보는 것: ① 자료(문 = 분화구 오른쪽 단의 분기공 · 방 셋 · 보스 퀘스트 · 동작 · 패턴 · 졸개 둘) ② 들어가기(난이도 하나 · 20분)
--   ③ 부위 · 방: 지금 부위만 맞는다 · 한 번에 다음 부위까지 깎이지 않는다 · 들어서는 동안 · 손이 빠져나가는 동안 맞지 않는다 · 다 빠져나가면 다음 방(room.lavaNext) ·
--     다음 방의 거인은 그 부위부터(넘어온 체력 startHp) ④ 대분화: 다 깨면 휘청 · 받는 피해 1.5배 / 남으면 모두 쓰러지고 체력을 되찾는다
--   ⑤ 끓어오르는 분화구(바닥만) ⑥ 움켜쥐기(놓치게 하기 · 내던지기) ⑦ 끓는 숨(낮은 발판 높이만) ⑧ 사람마다의 자리 ⑨ 심장 드러남 ⑩ 걷지 않는다 ⑪ 세기(입장 레벨 리븐의 %) ⑫ 예고 모양
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local LavaGim = req("ReplicatedStorage/shared/lune/sim/lavagim")
local BossFx = req("ReplicatedStorage/shared/lune/bossfx")
local DT = 1 / 20

-- ---- ① 자료 ----
local b = Weekly.boss("lavagiant")
expect(b ~= nil and b.room == "r3d5" and b.quest == "wq07" and b.door.scene == "r3d4", "용암 거인: 첫 방 갈라진 틈 속 · 보스 퀘스트 · 문은 분화구")
expect(b.rooms ~= nil and b.rooms[1] == "r3d5" and b.rooms[2] == "r3d6" and b.rooms[3] == "r3d7", "방 셋: 갈라진 틈 속 → 무너진 굴 → 끓는 분화구 속")
local m6, b6 = Weekly.ofKey("r3d6#wn3")
expect(m6 == "normal" and b6 == b and Weekly.isRoomOf(b, "r3d7") and not Weekly.isRoomOf(b, "r3d4"), "둘째 · 마지막 방도 그 보스의 방이다")
eq(Weekly.stageKey("r3d5#wn12", "r3d6"), "r3d6#wn12", "다음 방 = 같은 번호")
eq(b.time, 1200, "제한 시간 20분(그 보스만)")
expect(b.normal ~= nil and b.hard == nil, "난이도 하나(노말만)")
local door
for _, p in SCENES.scenes.r3d4.portals do
	if p.weekly == "lavagiant" then
		door = p
	end
end
expect(door ~= nil and door.done == "wq07" and math.abs(door.x - 662) <= 2, "문 = 분화구 오른쪽 단(41.4칸)의 분기공 · 보스 퀘스트를 끝내야 열린다")
local room0 = SCENES.scenes.r3d5
expect(room0 ~= nil and room0.bosses ~= nil and room0.bosses[1].kind == "lavagiant" and #room0.mobs == 0, "보스 방에는 거인만")
for i, id in { "r3d5", "r3d6", "r3d7" } do
	local sc = SCENES.scenes[id]
	local bb = sc and sc.bosses and sc.bosses[1]
	expect(bb ~= nil and bb.kind == "lavagiant" and bb.stage == i and #sc.mobs == 0, ("%s: %d째 방의 거인만"):format(id, i))
end
eq(SCENES.scenes.r3d5.bosses[1].x, 512, "첫 방: 손이 오른쪽 끝(벽 512)에서")
eq(SCENES.scenes.r3d6.bosses[1].x, 0, "둘째 방: 왼쪽 끝(0)에서")
eq(SCENES.scenes.r3d7.bosses[1].x, 256, "마지막 방: 몸통이 가운데에")
local def = COMBAT.mobs.lavagiant
expect(def and def.boss and def.story and def.story.fixed and def.story.week.normal.lv == 150 and def.story.week.normal.need == 120, "싸움 자료: 걷지 않는다 · Lv.150 · 입장 Lv.120")
local G = def.story.gimmick
expect(G and G.mod == "lava" and #G.parts == 3 and G.parts[1].share == 0.25 and G.parts[3].share == 0.5, "기믹 lava · 부위 셋(왼팔 25% · 오른팔 25% · 몸통 50%)")
eq(def.story.mark, "lava", "그 보스만의 예고 모양")
local char = CHARS.chars[def.sprite]
for _, clip in { "spawn", "spawn2", "spawn3", "idle", "idle2", "idle3", "slamL", "palmL", "flickL", "throwR", "boil", "stagger", "shift2", "slamR", "grabR", "grab", "throwR2", "fount", "boil2", "stagger2", "shift3", "flinch", "flinchL", "flinchR", "pulse", "boil3", "stagger3", "sink", "under", "rise", "death" } do
	expect(char and char.clips[clip] ~= nil, "동작 그림 " .. clip)
end
local P = {}
for _, p in def.story.patterns do
	P[p.id] = p
	if p.clip then
		expect(char.clips[p.clip] ~= nil and def.story.anim[p.clip] ~= nil and def.story.anim[p.clip].hit ~= nil, ("%s: 동작 %s과 그 치는 장"):format(p.id, p.clip))
	end
end
for _, id in { "slamL", "palmL", "flickL", "magma", "scrape", "slamR", "slamR2", "grab", "rock", "fount", "double", "sky", "pillar", "rain", "pulse", "halfR", "halfL", "floor", "lines", "sides", "updown" } do
	expect(P[id] ~= nil, "패턴 " .. id)
end
-- 2026-11-06 사용자 "고개돌리는거 스프라이트 쓰지마 · 팔 들고 포효하는 모션도 쓰지마 팔드는 모션도 쓰지마 그냥 원래형태에서 움찔거리기만": 끓는 숨 · 손 내려찍기가 없다 · 마지막 방의 동작은 움찔(flinch)과 맥동뿐
for _, id in { "breathL", "breathR", "breaths", "handL", "handR", "hands" } do
	expect(P[id] == nil, "뺀 패턴 " .. id)
end
for _, clip in { "breathL", "breathR", "pillar", "handL", "handR" } do
	expect(char.clips[clip] == nil, "뺀 동작 그림 " .. clip)
end
for _, p in def.story.patterns do
	if p.ph == 3 and p.clip then
		expect(p.clip == "flinch" or p.clip == "flinchL" or p.clip == "flinchR" or p.clip == "pulse", ("마지막 방 %s의 동작 = 움찔 · 맥동(%s)"):format(p.id, p.clip))
	end
end
expect(COMBAT.mobs.lavablister and COMBAT.mobs.lavablister.gim == "blister" and CHARS.chars.lavablister ~= nil, "마그마 혹(졸개)과 그 그림")
expect(COMBAT.mobs.lavaheart and COMBAT.mobs.lavaheart.gim == "heart" and CHARS.chars.lavaheart ~= nil, "용암 심장(졸개)과 그 그림")
local q = Quests.def("wq07")
expect(q ~= nil and q.big and q.after == "r3m9" and q.steps[1].type == "use", "보스 퀘스트: 「분화구의 깃발」(메인) 뒤 · 틈으로 내려가기")
expect(Items.unique("lava_ring") ~= nil and Items.unique("lava_ring").slot == "ring", "드문 보상 「식은 심장의 반지」(반지)")

-- ---- 공개(2026-11-05 사용자 "퍼블리시 할거고 … 보스는 바로 열리는게아니고" — release를 지우고 reveal: 출현 시각 전에는 닫혀 있다 · 시험 125가 서버의 흐름을 본다) ----
do
	local Reveal = req("ReplicatedStorage/shared/lune/sim/reveal")
	Reveal.at = {}
	expect(not b.dev and b.reveal ~= nil, "공개한 보스 · 출현을 기다린다")
	eq(Quests.state({ r3m9 = { done = true, c = {} } }, 150, "wq07"), "locked", "출현 전: 보스 퀘스트 「다시 깨어난 분화구」를 받지 못한다(문이 닫힌 채)")
	local Schedule = req("ReplicatedStorage/shared/lune/sim/schedule")
	local hs = Hero.new(5, "riven")
	Hero.setLevel(hs, 150)
	local seen = false
	for _, row in Schedule.view(hs, nil, 1_800_000_000).weekly do
		if row.id == "boss:lavagiant" then
			seen = true
		end
	end
	expect(not seen, "출현 전: 스케줄러의 주간 목록에 없다")
	Reveal.at.lavagiant = Reveal.clock() - 1 -- (모듈의 시계 · 아래 들어가기는 출현한 뒤로 본다)
	eq(Quests.state({ r3m9 = { done = true, c = {} } }, 150, "wq07"), "open", "출현 뒤: 받는다")
end

-- ---- ② 들어가기 ----
do
	local now = 1_800_000_000
	local h = Hero.new(1, "riven")
	Hero.setLevel(h, 120)
	h.rift = h.rift or {}
	eq(Weekly.canEnter(h, b, "normal", now), Weekly.DATA.words.closed, "보스 퀘스트를 끝내기 전에는 문이 닫혀 있다")
	h.quests.wq07 = { done = true, c = {} }
	eq(Weekly.canEnter(h, b, "normal", now), nil, "끝냈으면 들어간다(혼자도)")
	expect(Weekly.canEnter(h, b, "hard", now) ~= nil, "하드는 없다")
	Hero.setLevel(h, 119)
	expect(Weekly.canEnter(h, b, "normal", now) ~= nil, "Lv.119는 못 들어간다")
end

-- ---- 방 ----
local FLOOR = 176
local function idx(id: string): number
	for i, p in def.story.patterns do
		if p.id == id then
			return i
		end
	end
	error(id)
end
-- 그 방(r3d5 · r3d6 · r3d7)을 연다: 사람들(xs = 가로 자리) · 거인이 들어선 뒤까지(spawn초 + 0.4) 돌린다. startHp = 앞 방에서 넘어온 체력(서버 toStage가 적는 것)
local function open(id: string, seed: number, xs, startHp: number?)
	local room = Room.new(id .. "#wn" .. seed, SCENES.scenes[id], Random.new(seed))
	local heroes = {}
	for i, x in xs do
		local p = Hero.new(seed * 10 + i, if i % 2 == 1 then "riven" else "axion")
		Hero.setLevel(p, 120)
		p.x, p.y, p.invuln = x, FLOOR, 0
		heroes[p.id] = p
	end
	if startHp then
		room.bosses[1].startHp = startHp
	end
	local m = room.bosses[1]
	for _ = 1, math.floor((LavaGim.spawnTime(m) + 0.4) / DT) do
		room:step(heroes, DT)
	end
	return room, heroes, m
end
-- seconds 동안 방을 돌린다: 사람의 자리를 붙잡아 두고(pin = { [번호] = { x, y } }) · 체력을 채운다(quiet = 보스가 새 패턴을 고르지 않게)
local function run(room, heroes, m, seconds: number, events, pin, quiet: boolean?)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		for id, h in heroes do
			local at = pin and pin[id]
			if at then
				h.x, h.y = at[1], at[2]
			end
			if h.alive then
				h.invuln = 0
				h.hp = h.maxHp
			end
		end
		for _, e in room:step(heroes, DT) do
			table.insert(events, e)
		end
		if quiet and m.state == "idle" then
			m.rest = math.max(m.rest, 5)
		end
	end
	return events
end
local function count(events, f): number
	local n = 0
	for _, e in events do
		if f(e) then
			n += 1
		end
	end
	return n
end
local function gimN(events, k: string): number
	return count(events, function(e)
		return e.type == "gim" and e.k == k
	end)
end
local function first(heroes)
	for _, h in heroes do
		return h
	end
	return nil
end

-- ---- ③ 부위 · 방 ----
do
	-- 첫 방: 들어서는 동안(손이 밀고 들어온다) 맞지 않는다
	local roomS = Room.new("r3d5#wn30", SCENES.scenes.r3d5, Random.new(30))
	local hs = Hero.new(300, "riven")
	Hero.setLevel(hs, 120)
	hs.x, hs.y = 200, FLOOR
	roomS:step({ [hs.id] = hs }, DT)
	local ms = roomS.bosses[1]
	eq(ms.state, "spawn", "들어서면 손이 굴 끝에서 밀고 들어온다(spawn)")
	eq(LavaGim.spawnTime(ms), 2, "첫 방의 들어오는 시간 2초")
	local hp0 = ms.hp
	roomS:strike(hs, ms, 1000, 330, {}, { hits = {}, kills = {} })
	eq(ms.hp, hp0, "들어오는 동안은 맞지 않는다")

	local room, heroes, m = open("r3d5", 31, { 200 })
	local h = first(heroes)
	expect(m ~= nil and m.lava ~= nil and m.ph == 1 and m.maxHp > 1.2e9 and m.maxHp < 1.3e9 and m.state ~= "spawn", "거인이 섰다 · 첫 방(왼팔) · 체력 약 12.6억(2026-11-05 — 10,000배)")
	eq(m.x, 512, "보스의 자리 = 오른쪽 벽")
	m.lava.ventT, m.lava.floodT = 999, 999 -- (이 묶음에서는 대분화 · 분화구를 미룬다)
	local inArm = room:mobsInBox(300, 320, FLOOR - 40, FLOOR, 310)
	local inFree = room:mobsInBox(150, 250, FLOOR - 40, FLOOR, 200)
	expect(table.find(inArm, m) ~= nil, "첫 방: 손끝(발톱 — 벽에서 200점)은 맞는다")
	expect(table.find(inFree, m) == nil, "손 앞의 빈 바닥(왼쪽)에는 거인이 없다")
	local lo = LavaGim.partOf(m)
	room:strike(h, m, m.hp, h.x, {}, { hits = {}, kills = {} })
	expect(math.abs(m.hp - lo) < 2, "한 번에 다음 부위까지 깎이지 않는다(왼팔의 끝 = 전체의 75%에서 멈춘다)")
	local ev = run(room, heroes, m, 0.2, {}, nil, true)
	eq(m.state, "shift", "왼팔이 다 닳으면 손이 굴 밖으로 빠져나간다")
	eq(gimN(ev, "armL"), 1, "「왼팔이 굴 밖으로 물러났다!」")
	local before = m.hp
	room:strike(h, m, 1000, 330, {}, { hits = {}, kills = {} })
	eq(m.hp, before, "빠져나가는 동안은 맞지 않는다(직접 맞히는 것도)")
	expect(room.lavaNext == nil, "다 빠져나가기 전에는 아직 이 방")
	ev = run(room, heroes, m, G.shift[1] + 0.2, {}, nil, true)
	expect(room.lavaNext ~= nil and room.lavaNext.ph == 2 and math.abs(room.lavaNext.hp - lo) < 2, "2초 뒤 다음 방으로(둘째 · 체력 그대로 — 서버가 옮긴다)")
	eq(gimN(ev, "next"), 1, "화면에 「다음 방」")
	eq(m.ph, 1, "이 방의 거인은 그대로(다음 부위로 바뀌지 않는다)")

	-- 둘째 방: 넘어온 체력 그대로 · 오른팔만
	local room2, heroes2, m2 = open("r3d6", 32, { 300 }, lo - 7)
	local h2 = first(heroes2)
	m2.lava.ventT, m2.lava.floodT = 999, 999
	eq(m2.ph, 2, "둘째 방의 거인은 오른팔부터")
	eq(m2.hp, lo - 7, "넘어온 체력 그대로")
	eq(m2.x, 0, "보스의 자리 = 왼쪽 벽")
	local inR = room2:mobsInBox(180, 200, FLOOR - 40, FLOOR, 190)
	local inOut = room2:mobsInBox(300, 340, FLOOR - 40, FLOOR, 320)
	expect(table.find(inR, m2) ~= nil and table.find(inOut, m2) == nil, "둘째 방: 왼쪽 끝에서 들어온 오른팔만 맞는다")
	local lo2 = LavaGim.partOf(m2)
	room2:strike(h2, m2, m2.hp, h2.x, {}, { hits = {}, kills = {} })
	run(room2, heroes2, m2, G.shift[2] + 0.4, {}, nil, true)
	expect(room2.lavaNext ~= nil and room2.lavaNext.ph == 3 and math.abs(room2.lavaNext.hp - lo2) < 2, "오른팔이 다 빠져나가면 마지막 방으로")
	-- 둘째 방은 넘어온 것이 없으면 그 부위의 위 끝(75%)
	local _, _, m2b = open("r3d6", 33, { 300 })
	expect(math.abs(m2b.hp - m2b.maxHp * 0.75) < 2, "넘어온 것이 없으면 그 부위의 위 끝(전체의 75%)")

	-- 마지막 방: 몸통 · 두 손
	local room3, _, m3 = open("r3d7", 34, { 200 })
	eq(m3.ph, 3, "마지막 방의 거인은 몸통")
	expect(math.abs(m3.hp - m3.maxHp * 0.5) < 2, "몸통 = 전체의 50%")
	eq(m3.x, 256, "보스의 자리 = 방의 가운데")
	local inB = room3:mobsInBox(250, 262, FLOOR - 120, FLOOR - 60, 256)
	expect(table.find(inB, m3) ~= nil, "마지막 방: 몸통이 맞는다")
	eq(m3.x, 256, "걷지 않는다(자리 그대로)")
	eq(BossFx.phaseName(char.clips, "spawn", 2), "spawn2", "화면: 둘째 방의 들어오는 동작 = spawn2")
	eq(BossFx.phaseName(char.clips, "shift", 2), "shift2", "화면: 첫 방의 손이 빠져나가는 동작 = shift2(그때 체력이 첫 부위의 끝)")
end

-- ---- ④ 대분화 ----
do
	-- 다 깬다 → 휘청 · 받는 피해 1.5배
	local room, heroes, m = open("r3d5", 41, { 100, 220 })
	local h = first(heroes)
	m.lava.floodT = 999
	m.lava.ventT = 0.05
	local ev = run(room, heroes, m, 0.3, {}, nil, true)
	eq(gimN(ev, "vents"), 1, "숨구멍에 혹이 솟는다(첫 방 40초 — 여기서는 앞당겼다)")
	expect(m.lava.vents ~= nil and #m.lava.vents.adds == 2, "첫 방의 혹은 둘(바닥 5.5 · 14칸)")
	expect(math.abs(m.lava.vents.adds[1].x - 5.5 * 16) < 1 and math.abs(m.lava.vents.adds[2].x - 14 * 16) < 1, "혹은 그 방의 숨구멍 자리에")
	local blister = m.lava.vents.adds[1]
	eq(blister.maxHp, math.floor(m.maxHp * G.vents.hp + 0.5), "혹 하나 = 거인 전체 체력의 0.25%")
	run(room, heroes, m, 0.7, {}, nil, true) -- (나타나는 동안)
	for _, a in m.lava.vents.adds do
		local got = room:mobsInBox(a.x - 4, a.x + 4, a.y - 10, a.y, a.x)
		expect(table.find(got, a) ~= nil, "혹은 맞는다")
		room:strike(h, a, a.hp + 1, a.x, {}, { hits = {}, kills = {} })
	end
	ev = run(room, heroes, m, 0.2, {}, nil, true)
	eq(gimN(ev, "ventsOk"), 1, "다 깨면 「숨이 막혔다! 휘청!」")
	eq(m.state, "stagger", "휘청")
	local hp0 = m.hp
	room:strike(h, m, 1000, h.x, {}, { hits = {}, kills = {} })
	eq(hp0 - m.hp, 1500, "휘청 동안 받는 피해 1.5배")
	-- 남는다 → 모두 쓰러진다(무적이어도) · 부위 체력 3% 되찾음
	local room2, heroes2, m2 = open("r3d5", 42, { 100, 220 })
	m2.lava.floodT = 999
	local lo, hi = LavaGim.partOf(m2)
	m2.hp = lo + (hi - lo) * 0.5
	m2.lava.ventT = 0.05
	run(room2, heroes2, m2, 0.3, {}, nil, true)
	for _, hh in heroes2 do
		hh.invuln = 99 -- (맞은 뒤의 무적 — 대분화는 무시한다)
	end
	local ev2 = {}
	for _ = 1, math.floor((G.vents.count[1] + 0.5) / DT) do
		for _, e in room2:step(heroes2, DT) do
			table.insert(ev2, e)
		end
		if m2.state == "idle" then
			m2.rest = 5
		end
	end
	eq(gimN(ev2, "wipe"), 1, "시간 안에 다 깨지 못하면 「대분화!」")
	local dead = 0
	for _, hh in heroes2 do
		if not hh.alive then
			dead += 1
		end
	end
	eq(dead, 2, "방의 모두가 쓰러진다(무적이어도)")
	expect(math.abs(m2.hp - (lo + (hi - lo) * 0.53)) < 2, "거인은 지금 부위 체력의 3%를 되찾는다")
end

-- ---- ⑤ 끓어오르는 분화구 ----
do
	local room, heroes, m = open("r3d5", 51, { 200, 136 })
	local floorH, padH
	for _, h in heroes do
		if h.x == 200 then
			floorH = h
		else
			padH = h
		end
	end
	m.lava.ventT = 999
	m.lava.floodT = 0.05
	local pin = { [floorH.id] = { 200, FLOOR }, [padH.id] = { 136, FLOOR - 48 } } -- (낮은 바위 위)
	local ev = run(room, heroes, m, 0.3, {}, pin, true)
	eq(gimN(ev, "boil"), 1, "두 주먹을 쳐들고 울부짖는다(예고)")
	ev = run(room, heroes, m, G.flood.tell + G.flood.time + 0.3, {}, pin, true)
	eq(gimN(ev, "flood"), 1, "바닥이 끓는다")
	local hitF = count(ev, function(e) return e.type == "hurt" and e.hero == floorH.id end)
	local hitP = count(ev, function(e) return e.type == "hurt" and e.hero == padH.id end)
	expect(hitF >= 8, "바닥의 사람은 0.65초마다 맞는다(" .. hitF .. "번)")
	eq(hitP, 0, "발판 위는 괜찮다")
end

-- ---- ⑥ 움켜쥐기 ----
do
	local room, heroes, m = open("r3d6", 61, { 300 })
	local h = first(heroes)
	m.lava.ventT, m.lava.floodT = 999, 999
	local lo = LavaGim.partOf(m, 2)
	m.hp = lo + (m.maxHp * 0.25) * 0.9
	-- 놓치게 한다: 쥔 동안 파티가 오른팔 체력의 1%를 깎는다
	local p = room:bossStart(m, idx("grab"), h)
	m.lava.grabAim, m.lava.grabAt = h.id, { h.x, h.y }
	local ev = run(room, heroes, m, p.tell + 0.1, {}, { [h.id] = { 300, FLOOR } }, true)
	expect(m.lava.grab ~= nil and m.lava.grab.h == h, "표시된 자리에 서 있으면 잡힌다")
	eq(gimN(ev, "grab"), 1, "「움켜쥐었다!」")
	ev = run(room, heroes, m, 1.0, {}, nil, true)
	expect(h.y < FLOOR - 60, "쥔 주먹의 자리(높이)로 들려 있다")
	expect(math.abs(h.x - (m.x + P.grab.grab.at[1])) < 1, "쥔 주먹의 자리 = 쳐든 주먹(벽에서 185점)")
	room:strike(h, m, math.ceil(m.maxHp * 0.25 * G.parts[2].share / 0.25 * 0.0101), m.x + 90, {}, { hits = {}, kills = {} })
	ev = run(room, heroes, m, 0.2, {}, nil, true)
	eq(gimN(ev, "free"), 1, "오른팔 체력의 1%를 깎으면 놓친다")
	-- 못 깎으면 내던진다
	local room2, heroes2, m2 = open("r3d6", 62, { 300 })
	local h2 = first(heroes2)
	m2.lava.ventT, m2.lava.floodT = 999, 999
	m2.hp = LavaGim.partOf(m2, 2) + m2.maxHp * 0.2
	local p2 = room2:bossStart(m2, idx("grab"), h2)
	m2.lava.grabAim, m2.lava.grabAt = h2.id, { h2.x, h2.y }
	run(room2, heroes2, m2, p2.tell + 0.1, {}, { [h2.id] = { 300, FLOOR } }, true)
	local ev2 = {}
	for _ = 1, math.floor((p2.grab.hold + 0.3) / DT) do
		if h2.alive then
			h2.hp = h2.maxHp
		end
		for _, e in room2:step(heroes2, DT) do
			table.insert(ev2, e)
		end
	end
	eq(gimN(ev2, "crush"), 1, "못 풀면 「짓눌렸다!」(2026-11-05 사용자 「못 풀면 즉사」 — 전에는 내던져 체력 50%)")
	expect(not h2.alive, "즉사(무적 · 막기와 상관없이)")
end

-- ---- ⑦ 마지막 방의 짤 패턴(2026-11-06 사용자: "오른쪽 전역 뜨면 다 왼쪽으로 도망가고 왼쪽 전역 뜨면 다 오른쪽으로 도망가고 바닥위험이면 다 발판위로 도망가고 발판도 견제하는 가로 레이저선 패턴도") ----
local function hurtOf(ev, h)
	return count(ev, function(e) return e.type == "hurt" and e.hero == h.id end)
end
local function twoAt(seed, xa, xb)
	local room, heroes, m = open("r3d7", seed, { xa, xb })
	local A, B
	for _, h in heroes do
		if h.x == xa then
			A = h
		else
			B = h
		end
	end
	m.lava.ventT, m.lava.floodT = 999, 999
	m.hp = m.maxHp * 0.45
	m.lava.heartDone = true
	return room, heroes, m, A, B
end
-- 가로 열선: 발판 위(낮은 껍질 — 바닥에서 48점)는 맞고 · 바닥은 괜찮다
do
	local room, heroes, m, lowH, floorH = twoAt(71, 40, 100)
	local p = room:bossStart(m, idx("lines"), lowH)
	local ev = run(room, heroes, m, p.tell + 0.2, {}, { [lowH.id] = { 40, FLOOR - 48 }, [floorH.id] = { 100, FLOOR } }, true)
	expect(hurtOf(ev, lowH) >= 1, "가로 열선: 낮은 껍질 위의 사람이 맞는다")
	eq(hurtOf(ev, floorH), 0, "가로 열선: 바닥의 사람은 맞지 않는다")
end
-- 끓는 바닥: 바닥은 맞고 · 발판 위는 괜찮다
do
	local room, heroes, m, lowH, floorH = twoAt(72, 40, 300)
	local p = room:bossStart(m, idx("floor"), lowH)
	local ev = run(room, heroes, m, p.tell + 0.2, {}, { [lowH.id] = { 40, FLOOR - 48 }, [floorH.id] = { 300, FLOOR } }, true)
	expect(hurtOf(ev, floorH) >= 1, "끓는 바닥: 바닥의 사람이 맞는다(방 어디서나)")
	eq(hurtOf(ev, lowH), 0, "끓는 바닥: 발판 위의 사람은 맞지 않는다")
end
-- 오른쪽 · 왼쪽 불바다: 그쪽 절반(발판 위도)은 맞고 · 반대쪽은 괜찮다
for _, case in { { "halfR", 420, 90 }, { "halfL", 90, 420 } } do
	local id, hitX, safeX = case[1], case[2], case[3]
	local room, heroes, m, hitH, safeH = twoAt(73, hitX, safeX)
	local p = room:bossStart(m, idx(id), hitH)
	local ev = run(room, heroes, m, p.tell + 0.2, {}, { [hitH.id] = { hitX, FLOOR - 96 }, [safeH.id] = { safeX, FLOOR } }, true)
	expect(hurtOf(ev, hitH) >= 1, ("%s: 그쪽 절반의 높은 껍질 위(%d)도 맞는다"):format(id, hitX))
	eq(hurtOf(ev, safeH), 0, ("%s: 반대쪽(%d)은 맞지 않는다"):format(id, safeX))
end
-- 하늘의 용암 줄기: 하늘에서 바닥까지(발판 위도) — 자리 여덟을 고른다
do
	local room, heroes, m = twoAt(74, 150, 400)
	room.gimQ = {}
	local p = room:bossStart(m, idx("sky"), first(heroes))
	eq(p.spots and p.spots.up, 999, "하늘의 용암 줄기는 하늘까지 닿는다(up 999 — 화면은 하늘의 빛줄)")
	local n = 0
	for _, bl in room.blasts or {} do
		if bl.mob == m then
			n += 1
		end
	end
	expect(n >= 8, ("자리 여덟(두 번에 나눠) — %d"):format(n))
end

-- ---- ⑧ 사람마다의 자리 ----
do
	local room, heroes, m = open("r3d7", 81, { 150, 400 })
	m.lava.ventT, m.lava.floodT = 999, 999
	m.hp = m.maxHp * 0.45
	m.lava.heartDone = true
	local ev = {}
	room.gimQ = {}
	room:bossStart(m, idx("pillar"), first(heroes))
	local n = 0
	for _, bl in room.blasts or {} do
		if bl.mob == m then
			n += 1
		end
	end
	eq(n, 2, "솟는 용암 기둥 = 사람마다 하나")
	for _, e in room.gimQ do
		table.insert(ev, e)
	end
	eq(gimN(ev, "spots"), 1, "그 자리를 화면에 보낸다")
end

-- ---- ⑨ 심장 드러남 ----
do
	local room, heroes, m = open("r3d7", 91, { 300 })
	local h = first(heroes)
	m.lava.ventT, m.lava.floodT = 999, 999
	m.hp = m.maxHp * 0.24 -- (몸통의 48%)
	local ev = run(room, heroes, m, 0.2, {}, nil, true)
	eq(gimN(ev, "heart"), 1, "몸통 절반 아래에서 심장이 튀어나온다")
	expect(m.hitBox == false, "거인은 바닥 아래(맞지 않는다)")
	local hop1 = m.lava.heartAdd
	run(room, heroes, m, G.heart.sink + 0.8, {}, nil, true)
	local heart = m.lava.heartAdd
	expect(not heart.away and heart.maxHp == math.floor(m.maxHp * 0.5 * G.heart.hp + 0.5), "심장의 체력 = 몸통 체력의 2%")
	local onHop = false
	for _, at in G.heart.hops do
		if math.abs(heart.x - at[1] * 16) < 1 and math.abs(heart.y - at[2] * 16) < 1 then
			onHop = true
		end
	end
	expect(onHop and hop1 == heart, "심장은 분화구의 자리(설계 hops) 가운데 하나에")
	room:strike(h, heart, heart.hp + 1, heart.x, {}, { hits = {}, kills = {} })
	ev = run(room, heroes, m, 0.3, {}, nil, true)
	eq(gimN(ev, "heartOk"), 1, "깨면 「심장을 깼다!」")
	run(room, heroes, m, G.heart.rise + 0.2, {}, nil, true)
	expect(m.hitBox ~= false, "다시 솟아 맞는다")
	local hp0 = m.hp
	room:strike(h, m, 1000, h.x, {}, { hits = {}, kills = {} })
	eq(hp0 - m.hp, 1300, "깬 뒤 받는 피해 1.3배")
	-- 못 깨면 몸통 체력 5%를 되찾는다(전멸은 아니다)
	local room2, heroes2, m2 = open("r3d7", 92, { 300 })
	m2.lava.ventT, m2.lava.floodT = 999, 999
	m2.hp = m2.maxHp * 0.24
	local ev2 = run(room2, heroes2, m2, G.heart.sink + G.heart.time + 0.6, {}, nil, true)
	eq(gimN(ev2, "heartMiss"), 1, "시간이 다 되면 「심장이 돌아갔다…」")
	expect(math.abs(m2.hp - m2.maxHp * (0.24 + 0.5 * G.heart.regain)) < 2, "몸통 체력 5%를 되찾는다")
	eq(count(ev2, function(e) return e.type == "hurt" and e.dead end), 0, "아무도 쓰러지지 않는다")
end

-- ---- ⑩ 마지막까지: 몸통이 다 닳으면 쓰러지고 격파 ----
do
	local room, heroes, m = open("r3d7", 101, { 300 })
	local h = first(heroes)
	m.lava.ventT, m.lava.floodT = 999, 999
	m.hp = m.maxHp * 0.1
	m.lava.heartDone = true
	room:strike(h, m, m.hp + 10, h.x, {}, { hits = {}, kills = {} })
	eq(m.state, "dead", "몸통이 다 닳으면 쓰러진다")
	eq(room.weekly.state, "clear", "격파")
end

-- ---- ⑪ 세기: 입장 레벨(Lv.120 · 무기 17강 · 방어구 5강) 리븐의 % ----
do
	local room, _, m = open("r3d5", 111, { 200 })
	local h = Hero.new(9, "riven")
	Hero.setLevel(h, 120, Hero.jobAt(120))
	Hero.autoStat(h)
	local stage = Items.stageOf(120)
	for _, slot in Items.data.GEAR do
		local it = Items.make(slot, stage, Items.data.NORMAL, "riven")
		it.star = if slot == "weapon" then 17 else 5
		h.equip[slot] = it
	end
	Hero.recalc(h)
	local function pct(mul: number): number
		h.hp, h.invuln, h.alive = h.maxHp, 0, true
		local ev = {}
		room:hurtHero(ev, h, m, mul)
		return (ev[1] and ev[1].dmg or 0) / h.maxHp * 100
	end
	-- (설계의 %(S326) x 세기 1.3 — 2026-11-05 사용자 "맞는패턴은 더 아프게")
	-- 마지막 방(2026-11-06 사용자 "마지막 페이즈에서 짤패턴들이 하나도 안아파 … 거의 죽을정도의 데미지가 들어와야지 뎀감은 적용되는걸로"): 세기 2.6 = 67.3% x 1.3 = 리븐 체력의 약 88% · 맥동 1.6(세 번)
	local want = { slamL = 45, palmL = 35, flickL = 30, magma = 30, scrape = 40, slamR = 45, rock = 35, fount = 35, sky = 67.3, pillar = 67.3, rain = 67.3, pulse = 41.4, halfR = 67.3, halfL = 67.3, floor = 67.3, lines = 67.3 }
	for id, w0 in want do
		local w = w0 * 1.3
		local got = pct(P[id].mul)
		expect(math.abs(got - w) <= 3.5, ("%s: 리븐 체력의 %.1f%% (설계 %.1f%% x 1.3 = %.1f%%)"):format(id, got, w0, w))
	end
end

-- ---- ⑫ 예고 모양 ----
expect(BossFx.lavaCrack and BossFx.lavaSmear and BossFx.lavaBand and BossFx.bubbleMark and BossFx.heatColumn and BossFx.magmaSigil and BossFx.lavaLines and BossFx.skyMark, "용암 거인만의 예고 모양(금 · 물결 · 아지랑이 띠 · 거품 원 · 아지랑이 기둥 · 용암 방울 · 가로 열선 · 하늘의 빛줄)")
eq(BossFx.phaseOf(def.story.week.normal.hp, 1, G.parts), 1, "화면의 페이즈: 가득 = 첫째")
eq(BossFx.phaseOf(0.75, 1, G.parts), 2, "화면의 페이즈: 왼팔의 끝(75%) = 둘째")
eq(BossFx.phaseOf(0.3, 1, G.parts), 3, "화면의 페이즈: 절반 아래 = 셋째")
