-- 「달의 계승자」 — 불씨 도둑 두목: 문으로 들어가는 셋째 보스전 · 처음으로 기믹이 있는 보스(2026-10-28).
--  사용자: "오케이 불씨 도둑 두목으로 하고 여기서부터는 재밌는 기믹같은것도 넣어보자" → "다넣어보자" → "아니 바인드 잘거는것도 실력이야 그렇게 하고 기믹은 맘에든다 이대로 작업해보자"
--  보는 것: ① 자료(문 = 불씨 도둑의 소굴의 두목의 천막 · 보스 방 두목의 불씨 창고 · 보스 퀘스트 · 동작 열넷 · 기믹 · 폭탄 · 가짜 · 버프)
--   ② 들어가기 ③ 기믹 — 되받아치기(폭탄을 쳐서 되돌리면 휘청 · 단지가 깨진다) · 단지 털기(단지마다 덜 받는다 · 되찾은 불씨 = 모두에게 데미지 + · 다시 채우기) ·
--   연막 분신(진짜를 다섯 번 · 가짜를 치면 그을음 · 못 찾으면 불단지) · 낚아채기(끌어오고 버프를 턴다) · 큰 불단지(되돌린 폭탄으로 끊긴다)
--   ④ 바인드는 기믹 동작 중에도 걸린다 ⑤ 그 보스만의 예고(mark "thief")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local Gim = req("ReplicatedStorage/shared/lune/sim/thiefgim")
local DT = 1 / 20
local PK = req("ReplicatedStorage/shared/lune/net/packets")
expect(PK.Gim ~= nil and PK.Gim.Direction == "ServerToClient" and PK.Pull ~= nil and PK.Pull.Direction == "ServerToClient", "기믹의 신호 Gim · Pull이 신호 목록에 있다(없으면 화면이 「정의되지 않은 패킷」으로 멈춘다 — 2026-10-28 Play에서 났다)")

-- ---- ① 자료 ----
local b = Weekly.boss("thiefboss")
expect(b ~= nil and b.room == "r3b5" and b.quest == "wq06" and b.door.scene == "r3b3", "불씨 도둑 두목: 방 두목의 불씨 창고 · 보스 퀘스트 · 문은 불씨 도둑의 소굴")
local den = SCENES.scenes.r3b3
local door
local thieves = 0
for _, p in den.portals do
	if p.weekly == "thiefboss" then
		door = p
	end
end
for _, m in den.mobs do
	if m.kind == "thief" then
		thieves += 1
	end
end
expect(door ~= nil and math.abs(door.x - 437) <= 2 and door.y == 10 * 16, "문 = 오른쪽 낮은 단의 두목의 천막(27.3칸 · 10줄)")
expect(door ~= nil and door.done == "wq06", "그 문은 보스 퀘스트를 끝내야 열린다")
eq(thieves, 10, "소굴의 불씨 도둑은 문을 세운 뒤에도 열")
local room0 = SCENES.scenes.r3b5
expect(room0 ~= nil and room0.bosses ~= nil and room0.bosses[1].kind == "thiefboss" and #room0.mobs == 0, "보스 방에는 그 보스만")
local back
for _, p in room0.portals do
	if p.to == "r3b3" then
		back = p
	end
end
expect(back ~= nil, "보스 방의 왼쪽 문 = 불씨 도둑의 소굴로")
local def = COMBAT.mobs.thiefboss
expect(def ~= nil and def.boss and def.story and def.story.week and def.story.week.normal and def.story.week.hard, "싸움 자료와 노말 · 하드")
eq(def.story.week.normal.lv, 78, "노말 보스 Lv.78")
eq(def.story.week.hard.lv, 98, "하드 보스 Lv.98")
local char = CHARS.chars[def.sprite]
for _, clip in { "idle", "run", "slash", "spin", "throw", "hook", "roll", "lift", "stagger", "roar", "refill", "smoke", "upcut", "death" } do
	expect(char and char.clips[clip] ~= nil, "동작 그림 " .. clip)
end
local P = {}
for _, p in def.story.patterns do
	P[p.id] = p
	if p.clip then
		expect(char.clips[p.clip] ~= nil and def.story.anim[p.clip] ~= nil and def.story.anim[p.clip].hit ~= nil, ("%s: 동작 %s과 그 치는 장"):format(p.id, p.clip))
	end
end
for _, id in { "slash", "spin", "bombs", "hook", "carpet", "roll", "rain", "bigjar", "smoke", "combo" } do
	expect(P[id] ~= nil, "패턴 " .. id)
end
expect(P.combo.chain[1] == "slash" and P.combo.chain[2] == "spin" and P.combo.chain[3] == "bombs" and P.combo.from == 0.5, "도둑의 연속기 = 갈고리 베기 → 자루 돌리기 → 폭탄(체력 절반 아래)")
expect(P.bigjar.from == 0.5 and P.smoke.from == 0.5 and P.rain.from == 0.5, "큰 불단지 · 연막 분신 · 화약 비는 체력 절반 아래")
local loops = def.story.anim.loops
expect(loops and loops.stagger and loops.refill, "휘청 · 다시 채우기는 그 동작의 장을 되풀이한다(loops)")
eq(def.story.mark, "thief", "그 보스만의 예고 모양")
local G = def.story.gimmick
expect(G ~= nil and G.jars.n == 3 and G.bomb.kind == "thiefbomb" and G.decoy.kind == "thiefdecoy", "기믹: 단지 셋 · 불씨 폭탄 · 가짜 두목")
expect(COMBAT.mobs.thiefbomb and COMBAT.mobs.thiefbomb.gim == "bomb" and CHARS.chars.thiefbomb ~= nil, "불씨 폭탄(졸개)과 그 그림")
expect(COMBAT.mobs.thiefdecoy and COMBAT.mobs.thiefdecoy.gim == "decoy" and COMBAT.mobs.thiefdecoy.sprite == def.sprite, "가짜 두목 = 두목의 그림 그대로")
local EB = Buffs.data[G.ember.buff]
expect(EB ~= nil and EB.gim and EB.who == "none" and EB.fx.dmg > 0, "「화롯골의 불씨」 = 기믹만 거는 버프(배울 수 없다)")
local q = Quests.def("wq06")
expect(q ~= nil and q.big and q.after == "r3m5" and q.steps[1].type == "use", "보스 퀘스트: 「불씨 도둑의 소굴」(메인) 뒤 · 천막 걷기")
local main = Quests.def("r3m5")
expect(main ~= nil and main.steps[1].type ~= "boss", "메인 「불씨 도둑의 소굴」은 보스와 싸우지 않는다(이야기만 — 2026-10-24 규칙)")

-- ---- ② 들어가기 ----
do
	local now = 1_800_000_000
	local h = Hero.new(1, "riven")
	Hero.setLevel(h, 76)
	h.rift = h.rift or {}
	eq(Weekly.canEnter(h, b, "normal", now), Weekly.DATA.words.closed, "보스 퀘스트를 끝내기 전에는 문이 닫혀 있다")
	h.quests.wq06 = { done = true, c = {} }
	eq(Weekly.canEnter(h, b, "normal", now), nil, "끝냈으면 노말에 들어간다(혼자도)")
	expect(Weekly.canEnter(h, b, "hard", now) ~= nil, "하드는 레벨이 모자라다(Lv." .. b.hard.need .. ")")
	Hero.setLevel(h, b.hard.need)
	eq(Weekly.canEnter(h, b, "hard", now), nil, "레벨이 되면 하드도")
end

-- ---- ③ 기믹 ----
local scene = SCENES.scenes.r3b5
local FLOOR = scene.spawn.y
local function bossOf(room)
	for _, m in room.bosses do
		if m.kind == "thiefboss" then
			return m
		end
	end
	return nil
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
	local room = Room.new("r3b5#wn" .. seed, scene, Random.new(seed))
	local p = Hero.new(seed, "riven")
	Hero.setLevel(p, 78)
	p.x, p.y = hx, FLOOR
	p.invuln = 0
	local heroes = { [seed] = p }
	for _ = 1, 30 do
		room:step(heroes, DT)
	end
	return room, p, heroes, bossOf(room)
end
-- seconds 동안 방을 돌린다(사람은 x · y에 붙잡아 둔다 — x가 nil이면 가로는 그대로) · 보스는 그 패턴 하나만(쉬는 동안 다른 것을 고르지 않게)
local function run(room, p, heroes, m, x: number?, y: number, seconds: number, events)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		if x then
			p.x = x
		end
		p.y = y
		p.invuln = 0
		p.hp = p.maxHp or p.hp
		for _, e in room:step(heroes, DT) do
			table.insert(events, e)
		end
		if m.state == "idle" then
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
local function gimOf(events, k: string): number
	return count(events, function(e)
		return e.type == "gim" and e.k == k
	end)
end
local function hurtsOf(events, id): number
	return count(events, function(e)
		return e.type == "hurt" and e.hero == id
	end)
end
local function liveBombs(m)
	local list = {}
	for _, a in m.gim.bombs do
		if not a.away then
			table.insert(list, a)
		end
	end
	return list
end
local function front(m, d: number): number
	return m.x + (if m.dir > 0 then d else -d)
end

do -- 들어서면: 단지 셋 · 폭탄 · 가짜는 아직 없다 · 단지 셋이면 받는 피해 x0.7
	local room, _, _, m = open(40, 300)
	expect(m ~= nil and m.gim ~= nil and m.gim.jars == 3, "들어서면 두목 등에 단지 셋")
	eq(#liveBombs(m), 0, "처음에는 바닥에 폭탄이 없다")
	eq(Gim.dmgIn(room, m, 1000, {}), 700, "단지 셋: 받는 피해 x0.7(단지 하나마다 −10%)")
end
do -- 불씨 폭탄: 던진 폭탄은 발밑에 떨어져 3초 뒤 터진다 — 그 자리에 서 있으면 맞는다
	local room, p, heroes, m = open(41, 300)
	room:bossBegin(m, idx("bombs"), nil, p)
	local ev = run(room, p, heroes, m, 300, FLOOR, P.bombs.tell + G.bomb.fly + 0.2, {})
	eq(gimOf(ev, "throw"), P.bombs.bombs.n, "폭탄 셋을 던진다")
	eq(#liveBombs(m), P.bombs.bombs.n, "떨어진 폭탄 셋이 바닥에서 도화선이 탄다")
	ev = run(room, p, heroes, m, 300, FLOOR, G.bomb.fuse + 0.3, {})
	expect(gimOf(ev, "boom") == P.bombs.bombs.n and hurtsOf(ev, 41) >= 1, "치지 않으면 터진다 — 발밑의 폭탄에 맞는다")
	eq(#liveBombs(m), 0, "터진 폭탄은 사라진다")
end
local emberRoom
do -- 되받아치기: 폭탄을 치면 두목에게 되날아가 터진다 → 휘청(받는 피해 x1.3) · 단지 하나가 깨져 되찾은 불씨가 바닥에 · 두목 체력의 1%
	local room, p, heroes, m = open(42, 300)
	local mate = Hero.new(4200, "axion")
	Hero.setLevel(mate, 78)
	mate.x, mate.y = 150, FLOOR
	heroes[4200] = mate
	room:bossBegin(m, idx("bombs"), nil, p)
	run(room, p, heroes, m, 300, FLOOR, P.bombs.tell + G.bomb.fly + 0.2, {})
	local bomb = liveBombs(m)[1]
	local hp0 = m.hp
	local ok = room:strike(p, bomb, 10, p.x, {}, { hits = {} })
	expect(ok and bomb.away, "폭탄을 치면 한 대에 쳐 낸다(체력 1)")
	local ev = run(room, p, heroes, m, 300, FLOOR, G.bomb.back + 0.15, {})
	expect(gimOf(ev, "bat") == 1 and gimOf(ev, "backhit") == 1, "쳐 낸 폭탄이 두목에게 되날아가 터진다")
	eq(m.state, "stagger", "두목이 휘청한다")
	eq(m.gim.jars, 2, "등의 단지 하나가 깨진다")
	eq(hp0 - m.hp, math.floor(m.maxHp * G.bomb.self + 0.5), "두목 체력의 1%")
	eq(#room.embers, 1, "깨진 단지에서 되찾은 불씨가 바닥에 떨어진다")
	eq(Gim.dmgIn(room, m, 1000, {}), math.floor(1000 * (1 - G.jars.cut * 2) * G.stagger.mul + 0.5), "휘청 동안 x1.3 · 단지 둘 x0.8")
	ev = run(room, p, heroes, m, 300, FLOOR, G.stagger.time + 0.2, {})
	expect(gimOf(ev, "recover") == 1 and m.state ~= "stagger", "2.5초 뒤 일어선다")
	-- 되찾은 불씨: 밟으면 방의 모두에게 「화롯골의 불씨」(데미지 +10% — 셋까지 겹친다)
	local e = room.embers[1]
	ev = run(room, p, heroes, m, e.x, FLOOR, 0.2, {})
	expect(gimOf(ev, "ember") == 1 and #room.embers == 0, "되찾은 불씨를 밟으면 줍는다")
	expect(p.buffs[G.ember.buff] ~= nil and p.buffs[G.ember.buff].pow == 1, "밟은 사람에게 「화롯골의 불씨」")
	expect(mate.buffs[G.ember.buff] ~= nil and mate.buffs[G.ember.buff].pow == 1, "멀리 있는 파티원에게도(방의 모두)")
	expect(math.abs(Buffs.dmg(mate) - 1.1) < 1e-6, "데미지 x1.1")
	for _ = 1, 3 do
		table.insert(room.embers, { id = 900 + #room.embers, x = e.x, y = FLOOR, t = 10 })
		run(room, p, heroes, m, e.x, FLOOR, 0.1, {})
	end
	eq(p.buffs[G.ember.buff].pow, G.ember.max, "셋까지만 겹친다")
	emberRoom = room
end
expect(emberRoom ~= nil, "되받아치기를 끝까지 봤다")
do -- 다시 채우기: 체력 60% 아래로 쉬고 있으면 뒤쪽 불씨 더미로 달려가 3초 동안 단지를 다시 채운다(포효 없이)
	local room, p, heroes, m = open(44, 300)
	m.gim.jars = 1
	m.hp = math.floor(m.maxHp * 0.55)
	m.raged = true
	m.state, m.rest = "idle", 5
	local ev = run(room, p, heroes, m, 300, FLOOR, 0.1, {})
	eq(gimOf(ev, "refill"), 1, "체력 60% 아래 — 다시 채우러 간다")
	local fillX
	for _ = 1, math.floor(((G.jars.stash - 560) / G.jars.run + G.jars.time + 0.5) / DT) do
		run(room, p, heroes, m, 300, FLOOR, DT, ev)
		if m.state == "refill" then
			fillX = m.x
		end
	end
	expect(fillX ~= nil and math.abs(fillX - G.jars.stash) <= 4, ("불씨 더미(%d점)에서 채웠다 — %s"):format(G.jars.stash, tostring(fillX)))
	eq(m.gim.jars, G.jars.n, "단지가 다시 셋")
	eq(gimOf(ev, "filled"), 1, "다 채웠다")
	eq(count(ev, function(x) return x.type == "roar" end), 0, "포효 없이")
end
do -- 다시 채우는 중 바인드: 끊긴다(채운 만큼 그대로 — 여기서는 하나도 못 채웠다)
	local room, p, heroes, m = open(45, 300)
	m.gim.jars = 1
	m.hp = math.floor(m.maxHp * 0.55)
	m.raged = true
	m.state, m.rest = "idle", 5
	run(room, p, heroes, m, 300, FLOOR, (G.jars.stash - 560) / G.jars.run + 1.0, {})
	expect(m.gim.refill ~= nil and m.state == "refill", "채우는 중")
	m.bind = 1.5
	local ev = run(room, p, heroes, m, 300, FLOOR, 0.1, {})
	expect(m.gim.refill == nil and m.gim.jars == 1 and m.state == "idle", "바인드에 묶이면 채우기가 끊긴다(단지 하나 그대로)")
	expect(gimOf(ev, "filled") == 1, "끊긴 것을 화면에 알린다")
end
do -- 연막 분신: 진짜에게 다섯 번 맞히면 연기가 걷히고 휘청 · 가짜를 치면 그을음(친 사람의 화면이 2초 어둡다)
	local room, p, heroes, m = open(46, 300)
	room:bossBegin(m, idx("smoke"), nil, p)
	local ev = run(room, p, heroes, m, 300, FLOOR, P.smoke.tell + 0.2, {})
	expect(gimOf(ev, "smoke") == 1 and m.gim.smoke ~= nil and m.state == "sneak", "연막탄을 내리치면 연기 속에 셋 — 진짜도 걷는다")
	local decoys = {}
	for _, d in m.gim.decoys do
		if not d.away then
			table.insert(decoys, d)
		end
	end
	eq(#decoys, G.decoy.n, "가짜 둘")
	local x0 = m.x
	run(room, p, heroes, m, 300, FLOOR, 1.5, {})
	expect(m.x ~= x0 and decoys[1].state == "run", "진짜와 가짜가 똑같이 걷는다(서 있는 것이 진짜가 아니다)")
	local xs = { m.x, decoys[1].x, decoys[2].x }
	table.sort(xs)
	expect(xs[2] - xs[1] > 100 and xs[3] - xs[2] > 100, "셋이 방에 흩어진다")
	room:strike(p, decoys[1], 10, p.x, {}, { hits = {} })
	ev = run(room, p, heroes, m, 300, FLOOR, 0.1, {})
	local pop
	for _, e in ev do
		if e.type == "gim" and e.k == "pop" then
			pop = e
		end
	end
	expect(pop ~= nil and pop.hero == 46 and pop.blind == G.decoy.blind and decoys[1].away, "가짜를 치면 그을음이 터진다 — 친 사람의 화면이 2초 어둡다")
	for i = 1, G.decoy.need do
		room:damageMob(m, 100, p.x, p.id)
		if i < G.decoy.need then
			expect(m.gim.smoke ~= nil, ("진짜를 %d번 — 아직 연기 속"):format(i))
		end
	end
	expect(m.gim.smoke == nil and m.state == "stagger" and m.gim.stagger >= G.decoy.stagger - 0.01, "진짜를 다섯 번 맞히면 연기가 걷히고 3초 휘청")
	eq(#(function()
		local l = {}
		for _, d in m.gim.decoys do
			if not d.away then
				table.insert(l, d)
			end
		end
		return l
	end)(), 0, "남은 가짜도 사라진다")
end
do -- 연막 분신: 8초 안에 못 찾으면 진짜가 겨눈 사람 둘레에 불단지를 떨어뜨린다
	local room, p, heroes, m = open(47, 300)
	room:bossBegin(m, idx("smoke"), nil, p)
	local ev = run(room, p, heroes, m, 300, FLOOR, P.smoke.tell + G.decoy.time + G.decoy.drop.tell + 0.4, {})
	expect(gimOf(ev, "clear") == 1 and gimOf(ev, "drop") == 1, "못 찾았다 — 불단지가 떨어진다")
	expect(hurtsOf(ev, 47) >= 1, "그 자리에 서 있으면 맞는다")
end
do -- 연막 속 바인드: 진짜가 드러난다(찾은 것과 같다 — 휘청)
	local room, p, heroes, m = open(48, 300)
	room:bossBegin(m, idx("smoke"), nil, p)
	run(room, p, heroes, m, 300, FLOOR, P.smoke.tell + 0.5, {})
	expect(m.gim.smoke ~= nil, "연기 속")
	m.bind = 1
	local ev = run(room, p, heroes, m, 300, FLOOR, 0.1, {})
	local clear
	for _, e in ev do
		if e.type == "gim" and e.k == "clear" then
			clear = e
		end
	end
	expect(m.gim.smoke == nil and clear ~= nil and clear.found, "바인드에 묶이면 연기가 걷히고 진짜가 드러난다")
end
do -- 낚아채기: 갈고리가 처음 닿은 사람을 두목 앞으로 끌어오고 버프 하나를 턴다 → 두목이 10초 동안 세진다
	local room, p, heroes, m = open(49, 300)
	local bid
	for id, d in Buffs.data do
		if not d.gim and (d.dur or 0) > 0 and d.fx and d.fx.dmg and not d.fx.guard then -- (생존기면 맞지 않는다 — 데미지 버프로)
			bid = id
			break
		end
	end
	Buffs.give(p, bid, 1, p.x, p.y)
	local x = front(m, 200)
	room:bossBegin(m, idx("hook"), nil, p)
	local ev = run(room, p, heroes, m, nil, FLOOR, 0.0, {})
	p.x = x
	ev = run(room, p, heroes, m, nil, FLOOR, P.hook.tell + 1.2, ev)
	local pull
	for _, e in ev do
		if e.type == "pull" and e.hero == 49 then
			pull = e
		end
	end
	expect(pull ~= nil and math.abs(p.x - (m.x + m.dir * P.hook.hook.pull)) <= 1, ("끌려왔다(두목 앞 %d점) — 지금 %.0f · 두목 %.0f"):format(P.hook.hook.pull, p.x, m.x))
	expect(hurtsOf(ev, 49) + count(ev, function(e) return e.type == "dodge" and e.hero == 49 end) == 1, "갈고리에 한 번 맞는다(리븐은 피하기도 한다)")
	expect(p.buffs[bid] == nil and gimOf(ev, "steal") == 1, "걸린 버프 하나를 털렸다")
	expect(math.abs(Gim.hitMul(room, m) - (1 + P.hook.hook.boost.dmg)) < 1e-6, "두목이 10% 세진다")
	run(room, p, heroes, m, nil, FLOOR, P.hook.hook.boost.time + 0.2, {})
	eq(Gim.hitMul(room, m), 1, "10초 뒤 원래대로")
end
do -- 낚아채기: 뛰어 떠 있으면 갈고리를 넘는다
	local room, p, heroes, m = open(50, 300)
	local x = front(m, 200)
	room:bossBegin(m, idx("hook"), nil, p)
	local ev = run(room, p, heroes, m, x, FLOOR - 40, P.hook.tell + 1.2, {})
	expect(count(ev, function(e) return e.type == "pull" end) == 0 and hurtsOf(ev, 50) == 0, "뛰면 넘는다")
end
do -- 큰 불단지: 모으는 동안 던진 폭탄을 되돌리면 단지가 두목 위에서 깨져 끊긴다(4초 휘청 · 두목 체력의 1% + 3%)
	local room, p, heroes, m = open(51, 300)
	room:bossBegin(m, idx("bigjar"), nil, p)
	run(room, p, heroes, m, 300, FLOOR, P.bigjar.bigjar.throwAt + G.bomb.fly + 0.2, {})
	local list = liveBombs(m)
	eq(#list, P.bigjar.bigjar.bombs, "모으는 동안 작은 폭탄 둘을 던진다")
	local hp0 = m.hp
	room:strike(p, list[1], 10, p.x, {}, { hits = {} })
	local ev = run(room, p, heroes, m, 300, FLOOR, G.bomb.back + 0.15, {})
	local bh
	for _, e in ev do
		if e.type == "gim" and e.k == "backhit" then
			bh = e
		end
	end
	expect(bh ~= nil and bh.jar, "되돌린 폭탄이 큰 불단지를 깼다")
	eq(m.state, "stagger", "큰 불단지가 끊기고 휘청")
	eq(hp0 - m.hp, math.floor(m.maxHp * G.bomb.self + 0.5) + math.floor(m.maxHp * P.bigjar.bigjar.self + 0.5), "두목 체력의 1% + 3%")
	expect(m.gim.stagger >= G.stagger.jar - 0.2, "큰 불단지를 끊으면 4초 휘청")
	ev = run(room, p, heroes, m, 300, FLOOR, P.bigjar.tell, ev)
	eq(gimOf(ev, "bigjar"), 0, "방 전체가 터지지 않는다")
end
do -- 큰 불단지: 바인드로도 끊긴다
	local room, p, heroes, m = open(52, 300)
	room:bossBegin(m, idx("bigjar"), nil, p)
	run(room, p, heroes, m, 300, FLOOR, 2.0, {})
	m.bind = 1
	local ev = run(room, p, heroes, m, 300, FLOOR, P.bigjar.tell, {})
	eq(gimOf(ev, "bigjar"), 0, "바인드에 묶이면 큰 불단지가 끊긴다")
end
do -- 큰 불단지: 끊지 못하면 방 전체가 터진다(어디 서 있어도 맞는다)
	local room, p, heroes, m = open(53, 140)
	room:bossBegin(m, idx("bigjar"), nil, p)
	local ev = run(room, p, heroes, m, 140, FLOOR, P.bigjar.tell + 0.5, {})
	expect(gimOf(ev, "bigjar") == 1 and hurtsOf(ev, 53) >= 1, "5초를 다 모으면 방 전체가 터진다")
end

-- ---- ⑤ 불씨 도둑 두목만의 예고(mark "thief") — 판정의 칠 = 맞는 자리 그대로 · 다른 보스의 그림과 다르다 ----
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
	for _, id in { "slash", "spin" } do
		local p = P[id]
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "thief")
		local lo, hi = X - p.zone.to, X - p.zone.from
		expect(fill(c, lo, hi, floorY - p.zone.up, floorY), ("%s: 판정의 칠 = 맞는 자리(%d ~ %d · 높이 %d)"):format(id, lo, hi, p.zone.up))
		local cOld, cK = canvas(), canvas()
		BossFx.tell(cOld, X, floorY, -1, p, 0.5, 112, 704, 100, nil, nil)
		BossFx.tell(cK, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "knight")
		expect(#c.rects ~= #cOld.rects and #c.rects ~= #cK.rects, id .. ": 다른 보스의 그림과 다르다")
	end
	do -- 낚아채기: 갈고리가 날아갈 길(높이 0 ~ up)
		local p = P.hook
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "thief")
		local x0 = X - p.hook.at
		local x1 = math.clamp(x0 - p.hook.range, 112 - 20, 704 + 20)
		expect(fill(c, math.floor(math.min(x0, x1) + 0.5), math.floor(math.max(x0, x1) + 0.5), floorY - p.hook.up, floorY), "낚아채기: 갈고리 길의 칠 = 맞는 높이")
	end
	do -- 굴러 박치기: 방 끝까지의 낮은 띠
		local p = P.roll
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "thief")
		expect(fill(c, 112, X, floorY - p.dash.up, floorY), "굴러 박치기: 방 끝까지 · 높이 " .. p.dash.up)
	end
	do -- 큰 불단지: 방 전체 + 도화선(다른 그림)
		local p = P.bigjar
		local c, cOld = canvas(), canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "thief")
		BossFx.tell(cOld, X, floorY, -1, p, 0.5, 112, 704, 100, nil, nil)
		expect(#c.rects > 0 and #c.rects ~= #cOld.rects, "큰 불단지: 타 들어가는 도화선")
	end
	for _, grid in { false, true } do
		local c = canvas()
		BossFx.spot(c, 300, floorY, 14, 56, 0.6, nil, nil, "thief", grid)
		local hasEdge = false
		for _, r in c.rects do
			if r.x == 300 - 14 or r.x == 300 + 14 - 1 then
				hasEdge = true
			end
		end
		local cK = canvas()
		BossFx.spot(cK, 300, floorY, 14, 56, 0.6, nil, nil, "knight", grid)
		expect(#c.rects > 15 and hasEdge and #c.rects ~= #cK.rects, (if grid then "화약 자루" else "굴려 놓은 폭탄") .. ": 판정의 양옆(x ± r)을 보이고 부단장의 것과 다르다")
	end
	do -- 머리 위: 불붙은 폭탄(다른 보스의 「!」 · 조준 십자선 · 칼과 다르다)
		local c, cA, cK = canvas(), canvas(), canvas()
		local p = P.slash
		BossFx.tell(c, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "thief")
		BossFx.tell(cA, X, floorY, -1, p, 0.5, 112, 704, 100, nil, nil)
		BossFx.tell(cK, X, floorY, -1, p, 0.5, 112, 704, 100, nil, "knight")
		local above = function(cc)
			local n = 0
			for _, r in cc.rects do
				if r.y < floorY - 100 - 6 then
					n += 1
				end
			end
			return n
		end
		expect(above(c) > 0 and above(c) ~= above(cA) and above(c) ~= above(cK), "머리 위의 표시가 다른 보스들과 다르다")
	end
end

-- ---- ⑥ 화면(client/lune/thiefView.luau): 서버의 Gim 신호마다 그림을 건다 — 신호 종류를 모두 넣어 오류 없이 돌고, 이 보스의 이펙트 그림을 트는가 ----
--  (2026-10-28: 신호 목록에 Gim이 없어 Play에서 화면이 멈췄다 — 그 뒤로 화면 쪽도 여기서 돌려 본다)
do
	-- 화면 틀 · 글씨 층 · UI 부품은 가짜(24_lune_mobsview와 같다) — 그리는 mobsView · bossView · thiefView는 진짜
	local function label(name)
		local l = { Name = name, Visible = false, ZIndex = 1, ImageTransparency = 0, Image = "" }
		function l:Destroy() end
		return l
	end
	local any = setmetatable({}, { __index = function() return "c" end })
	MOCK("Client/lune/stage", { image = function(_, name) return label(name) end })
	MOCK("Client/lune/overlay", { x = function(v) return v end, y = function(v) return v end, len = function(v) return v end })
	MOCK("Client/lune/ui/ui", {
		COLOR = any,
		bar = function()
			local b = { frame = label("bar"), fill = label("fill"), ratio = nil }
			function b.set(_, r) b.ratio = r end
			return b
		end,
		box = function() return label("box") end,
		tag = function() local t = { Frame = label("tag"), Width = 40 } function t:Destroy() end return t end,
	})
	MOCK("Client/lune/ui/kit", { COLOR = any, box = function() return label("box") end })
	MOCK("Client/lune/ui/itemCell", {})
	MOCK("Client/modules/ui/pixelText", {})
	local MobsView = req("Client/lune/mobsView")
	local BossView = req("Client/lune/bossView")
	local TV = req("Client/lune/thiefView")
	local room3 = { mobs = {}, snap = {} }
	for i, bb in room0.bosses do
		room3.mobs[i] = { id = i, kind = bb.kind, lv = bb.lv, y = bb.y, maxHp = 1000, name = def.name, boss = true }
		room3.snap[i] = { i, bb.x, -1, "idle", 0, 1000, 0, 0, 0 }
	end
	local v3 = MobsView.new({}, room3, {})
	local adds3, sprites3 = {}, {}
	local fx = setmetatable({
		add = function(life, fn, opts)
			table.insert(adds3, { life = life, fn = fn })
		end,
	}, {
		__index = function()
			return function() end
		end,
	})
	local effectsFake = {
		ghost = function() end,
		play = function(_, who, clip, x, y, dir, opts)
			local rec = { who = who, clip = clip, t = 0, life = 1 }
			table.insert(sprites3, rec)
			return rec
		end,
	}
	local sounds = {} -- 보스의 소리(2026-10-28 — hooks.sfx로 부른 이름)
	local bv = BossView.new(v3, { fx = fx, shakeA = 0, shakeT = 0 }, effectsFake, room0, { sfx = function(k) table.insert(sounds, k) end })
	v3:apply({ { 1, 560, -1, "idle", 0, 1000, 0, 0, 0 } }, 10)
	v3:update(10)
	bv:update(0.016)
	local floats, dims = 0, 0
	local tv = TV.new(bv, {
		me = 7,
		words = G.words,
		float = function() floats += 1 end,
		dim = function() dims += 1 end,
		body = function() return { x = 300, y = FLOOR } end,
	})
	local canvas = { style = function() end, alpha = function() end, rect = function() end }
	local ok, err = pcall(function()
		for _, e in {
			{ k = "jars", jars = 3, smoke = false }, { k = "throw", x0 = 550, x = 320, y = FLOOR, t = 0.6 }, { k = "boom", x = 320, y = FLOOR },
			{ k = "bat", x = 320, y = FLOOR, to = 560, toY = FLOOR, t = 0.4, hero = 7 }, { k = "backhit", x = 560, jar = false },
			{ k = "stagger", t = 2.5 }, { k = "jar", jars = 2, ember = 1, x = 520, y = FLOOR }, { k = "ember", id = 1, hero = 7 },
			{ k = "jar", jars = 1, ember = 2, x = 500, y = FLOOR }, { k = "emberGone", id = 2 }, { k = "recover" },
			{ k = "refill", x = 680 }, { k = "filled", jars = 3 }, { k = "smoke", t = 8, x = 400, y = FLOOR }, { k = "jars", jars = 3, smoke = true },
			{ k = "pop", x = 200, y = FLOOR, hero = 7, blind = 2 }, { k = "clear", found = true }, { k = "drop", x = 300, y = FLOOR, spread = 40, t = 1.2 },
			{ k = "hook", id = 5, x = 544, y = FLOOR - 30, dir = -1, speed = 320, range = 360 }, { k = "hookEnd", id = 5, hero = 7 },
			{ k = "steal", hero = 7, buff = "x" }, { k = "bigjar", x = 560 },
		} do
			TV.event(tv, e)
		end
		for _, a in adds3 do -- 건 그림들을 한 장씩 그려 본다(가운데쯤 · 끝 무렵)
			a.fn(canvas, 0.5)
			a.fn(canvas, 0.95)
		end
	end)
	expect(ok, "신호를 모두 받아 그림을 그려도 오류가 없다 — " .. tostring(err))
	local played = {}
	for _, r in sprites3 do
		played[r.clip] = (played[r.clip] or 0) + 1
	end
	for _, clip in { "fx_boom", "fx_jar", "fx_ember", "fx_smoke", "fx_soot" } do
		expect((played[clip] or 0) > 0 and char.clips[clip] ~= nil, "기믹이 이 보스의 이펙트 그림을 튼다 — " .. clip)
	end
	expect(floats >= 4 and dims >= 2, ("말이 뜨고(%d) · 화면이 어두워진다(%d — 연막 · 그을음)"):format(floats, dims))
	eq(tv.jars, 3, "머리 위의 남은 단지 = 서버가 알린 수")
	expect(tv.hide == false, "연막이 걷히면 단지 칸이 다시 보인다")
	local emberRec
	for _, r in sprites3 do
		if r.clip == "fx_ember" then
			emberRec = r
		end
	end
	expect(emberRec ~= nil and emberRec.t >= emberRec.life, "주운(또는 사라진) 바닥 불씨의 그림은 끝낸다")
	local heard = {}
	for _, k in sounds do
		heard[k] = true
	end
	for _, k in { "boss_boom", "boss_glass", "boss_smoke", "boss_shot" } do
		expect(heard[k], "기믹의 소리 " .. k)
	end
	-- 치는 순간의 소리: 갈고리 베기(예고 → 침) = 휘두르기 · 큰 불단지 = 터짐 · 쓰러짐
	table.clear(sounds)
	local t9 = 20
	for _, st in { { "tell", "slash" }, { "act", "slash" }, { "idle", nil }, { "tell", "bigjar" }, { "act", "bigjar" }, { "dead", nil } } do
		t9 += 0.5
		v3:apply({ { 1, 560, -1, st[1], 0, if st[1] == "dead" then 0 else 1000, 0, 0, if st[2] then idx(st[2]) else 0 } }, t9)
		v3:update(t9)
		bv:update(0.016)
	end
	eq(table.concat(sounds, " "), "boss_swing boss_boom boss_down", "보스의 소리: 갈고리 베기 = 휘두르기 · 큰 불단지 = 터짐 · 쓰러짐")
	eq(P.slash.sfx, "boss_swing", "패턴에 소리가 적혀 온다(공방 bosses.js BOSS_SFX)")
	eq(P.carpet.spots.sfx, "boss_boom", "표시된 자리가 터질 때의 소리")
end
