-- 「달의 계승자」 — 스토리 보스 둘(망루의 부관 · 정찰대장): 등장 · 패턴 · 물결 · 호령 · 내달리기 · 보상 없음 · 퀘스트.
--  사용자 2026-10-11: "리워드 없는 스토리보스로넘기고 스토리가 끝나면 재도전 하거나 재격파없이 그냥 이야기에서 지나치는 스토리보스로".
--  설계: 공방 js/lune/design/bosses.js의 STORYBOSS → COMBAT.mobs[보스].story · 장면의 bosses. 셈: sim/room.luau의 stepBoss.
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local DT = 1 / 20
local KEY = "r1c4"
local scene = SCENES.scenes[KEY]
local FLOOR = scene.spawn.y

-- ---- 1) 자료 ----
expect(scene.bosses ~= nil and #scene.bosses == 2, "망루 꼭대기에 스토리 보스 둘의 자리가 있다")
eq(scene.bosses[1].kind, "towerlieutenant", "첫째 = 망루의 부관")
eq(scene.bosses[2].kind, "scoutcaptain", "둘째 = 정찰대장")
eq(#scene.mobs, 0, "졸개의 목록에는 넣지 않는다(월드맵 · 사냥터의 셈이 보스를 졸개로 세지 않는다)")
for _, b in scene.bosses do
	local def = COMBAT.mobs[b.kind]
	expect(def ~= nil and def.boss == true and def.story ~= nil and def.bare == true, "보스의 싸움 자료 " .. b.kind)
	expect(CHARS.chars[def.sprite] ~= nil and CHARS.chars[def.sprite].clips.idle ~= nil, "보스의 그림(대기) " .. b.kind)
	local q = Quests.def(def.story.quest)
	expect(q ~= nil and q.kind == "main" and q.scene == KEY and #q.steps == 1 and q.steps[1].type == "kill" and q.steps[1].mob == b.kind and q.steps[1].n == 1, "그 보스를 한 번 잡는 메인 퀘스트 " .. b.kind)
	expect(b.range[1] >= 32 + def.body[1] / 2 and b.range[2] <= scene.w * 16 - 32 - def.body[1] / 2 and b.x >= b.range[1] and b.x <= b.range[2], "움직이는 범위가 방 안(양 끝의 벽 안쪽)")
	eq(b.y, FLOOR, "바닥에 선다")
	local ids = {}
	for _, p in def.story.patterns do
		ids[p.id] = p
	end
	for _, p in def.story.patterns do
		expect(typeof(p.name) == "string" and #p.name > 0, ("%s %s: 화면에 띄울 패턴의 이름"):format(b.kind, p.id))
		if p.chain then
			-- 연속기: 적힌 패턴들을 쉬지 않고 잇는다 — 그 자체는 예고도 판정도 없다
			expect(#p.chain >= 2 and p.quick >= 0.6 and p.quick <= 1, ("%s %s: 연속기는 둘 넘게 잇고, 둘째부터의 예고는 0.6배보다 짧아지지 않는다"):format(b.kind, p.id))
			for _, id in p.chain do
				expect(ids[id] ~= nil and ids[id].chain == nil, ("%s %s: 잇는 패턴 %s가 있다"):format(b.kind, p.id, id))
				expect(ids[id].tell * p.quick >= 0.8, ("%s %s: 이어지는 %s의 예고도 0.8초는 된다"):format(b.kind, p.id, id))
			end
			continue
		end
		-- 예고: 맞기까지 1.2초는 된다(도약은 뛰어올라 내려앉는 시간까지) — 기술을 쓰던 중에도 보고 피할 만큼
		local warn = p.tell + (if p.leap then p.leap.time else 0)
		expect(warn >= 1.2 and p.tell <= 1.8, ("%s %s: 예고가 기술을 쓰던 중에도 보고 피할 만큼 길다(%.1f초)"):format(b.kind, p.id, warn))
		expect(p.act + p.rest >= 1.4, ("%s %s: 친 뒤 다음 패턴까지 한두 번 칠 틈이 있다(굳어 있는 %.2f + %.2f초)"):format(b.kind, p.id, p.act, p.rest))
		expect((p.zone ~= nil or p.wave ~= nil or p.summon ~= nil or p.dash ~= nil or p.spots ~= nil) and p.mul >= 0, ("%s %s: 하는 일이 있다"):format(b.kind, p.id))
		if p.zone then
			expect(p.zone.to > p.zone.from and p.zone.up > 0, ("%s %s: 맞는 자리"):format(b.kind, p.id))
		end
		if p.summon then
			expect(COMBAT.mobs[p.summon.kind] ~= nil and p.summon.n <= p.summon.max, "부르는 졸개")
		end
		if p.leap then
			expect(p.zone ~= nil and p.far ~= nil and p.leap.time >= 0.4, ("%s %s: 도약은 멀리 있을 때 쓰고, 내려앉아 찍는 자리가 있다"):format(b.kind, p.id))
		end
		if p.spots then
			expect(p.spots.r >= 8 and p.spots.up > 12, ("%s %s: 표시된 자리의 크기"):format(b.kind, p.id))
		end
	end
	-- 패턴의 수 · 체력 구간: 처음부터 서넛, 체력 구간(포효) 뒤에 둘 넘게 더 열린다 · 멀리 있을 때 쓰는 것이 처음부터 있다(멀리 도망가도 쉴 수 없다)
	local early, late, far = 0, 0, 0
	for _, p in def.story.patterns do
		if p.from then
			late += 1
		else
			early += 1
			far += if p.far then 1 else 0
		end
	end
	expect(early >= 3 and late >= 2 and far >= 1, ("%s: 패턴 처음 %d개 + 체력 구간 뒤 %d개 · 멀리 있을 때 쓰는 것 %d개"):format(b.kind, early, late, far))
	local ph = def.story.phase
	expect(ph ~= nil and ph.at > 0.3 and ph.at < 0.8 and ph.time >= 0.8 and ph.rage <= 1 and #ph.name > 0, b.kind .. ": 체력 구간의 포효")
end
-- 세기(사용자 2026-10-11: 처음 값은 "깰수가 없는 수준"): 한 방이 맨몸 체력의 3~10% — 열 번을 맞아도 선다 · 그래도 일반 몬스터보다는 아프다
for _, b in scene.bosses do
	for _, p in COMBAT.mobs[b.kind].story.patterns do
		if p.mul and p.mul > 0 then
			local share = N.rawHit("mob", b.lv) * p.mul / N.baseHp(b.lv)
			expect(share >= 0.03 and share <= 0.1 and p.mul > 1, ("%s %s: 한 방 = 맨몸 체력의 %.0f%%"):format(b.kind, p.id, share * 100))
		end
	end
end

-- ---- 2) 방 ----
local function hero(id: number, level: number, quest: string?)
	local h = Hero.new(id, "riven")
	Hero.setLevel(h, level)
	h.x, h.y = scene.spawn.x, FLOOR
	if quest then
		h.quests[quest] = { done = false, c = {} }
	end
	return h
end
local function run(room, heroes, seconds: number, each)
	local events = {}
	for _ = 1, math.floor(seconds / DT + 0.5) do
		for _, e in room:step(heroes, DT) do
			table.insert(events, e)
		end
		if each and each() then
			break
		end
	end
	return events
end
local function bossOf(room, kind: string)
	for _, m in room.bosses do
		if m.kind == kind then
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

-- 퀘스트가 없는 사람만 있으면 보스가 없다
do
	local room = Room.new(KEY, scene, Random.new(1))
	local h = hero(1, 30)
	run(room, { [1] = h }, 2)
	for _, m in room.mobs do
		expect(m.state == "gone", "퀘스트를 하지 않는 사람에게는 보스도 졸개도 없다 " .. m.kind)
	end
	eq(#room:describe(1).mobs, 2 + 4, "자리는 여섯(보스 둘 + 대장이 부르는 검병 넷)")
	expect(room:describe(1).mobs[1].boss == true and room:describe(1).mobs[3].boss == nil, "화면에 보스인지 알린다")
end

-- 「망루의 부관」을 하는 중이면 부관이 선다 — 대장은 없다
local room = Room.new(KEY, scene, Random.new(2))
local h = hero(1, 25, "r1m7")
local heroes = { [1] = h }
h.x = 140
run(room, heroes, 0.1)
local lt, cap = bossOf(room, "towerlieutenant"), bossOf(room, "scoutcaptain")
expect(lt.state == "spawn" and not lt.away and lt.hp == lt.maxHp, "부관이 나타난다(체력 가득)")
expect(cap.state == "gone" and cap.away, "대장은 아직 없다")
expect(lt.maxHp >= 8 * N.mobHp(25) * COMBAT.rules.dmgScale * 1.5 and lt.maxHp <= 20 * N.mobHp(25) * COMBAT.rules.dmgScale * 1.5, "체력은 일반 몬스터의 8~20배(쉬지 않고 쳐서 20~50초)")
run(room, heroes, 1)
expect(lt.state == "run" or lt.state == "idle", "나타난 뒤 다가온다 — " .. lt.state)
-- 멀리 있으면 걸어온다
local x0 = lt.x
run(room, heroes, 2)
-- 2초 동안 걷는 빠르기의 절반 넘게 다가온다(쉬는 틈이 있다) — 2026-10-15 두 보스를 느리게(사용자: 「더 느릿느릿」 — 성벽 거인 20점/초)
expect(lt.x < x0 - COMBAT.mobs.towerlieutenant.speed * 0.5, ("사람 쪽으로 걸어온다 %.0f → %.0f"):format(x0, lt.x))
eq(lt.dir, -1, "사람을 본다")
-- 닿을 거리가 되면 예고한다
local saw = {}
run(room, heroes, 30, function()
	saw[lt.state] = true
	return lt.state == "tell"
end)
eq(lt.state, "tell", "쉬는 틈이 지나면 패턴을 예고한다")
local P = lt.def.story.patterns
local p = P[lt.pat]
expect(p ~= nil and p.from == nil and p.chain == nil, "체력이 많을 때는 처음부터 쓰는 패턴 — " .. tostring(p and p.id))
eq(room:snapshot()[lt.id][9], lt.pat, "화면에 패턴의 차례를 보낸다")
eq(room:snapshot()[lt.id][4], "tell", "화면에 예고를 보낸다")
eq(#room:snapshot()[lt.id], 12, "화면에 겨눈 자리 · 연속기 · 빠른 패턴인지도 보낸다")

-- 패턴을 시킨다: id의 패턴을 예고부터(보는 쪽 dir · target = 겨눈 사람 — 없으면 보는 쪽 앞을 겨눈다). 연속기는 그 첫 패턴부터 시작한다
local function force(mob, id: string, dir: number, target)
	for i, q in mob.def.story.patterns do
		if q.id == id then
			mob.dir, mob.rest = dir, 0
			mob.target = if target then target.id else mob.target
			room:bossSpotsOff(mob)
			room.blasts = nil
			local first = room:bossStart(mob, i, target)
			if not target then
				mob.dir = dir
			end
			return q, first
		end
	end
	error("없는 패턴 " .. id)
end
-- 예고 동안에는 맞지 않는다 · 그 자리에 서 있으면 예고가 끝날 때 맞는다
lt.x = 400
p = force(lt, "smash", -1)
h.x = lt.x + lt.dir * (p.zone.from + p.zone.to) / 2
h.invuln = 0
local hp0 = h.hp
local ev = run(room, heroes, p.tell - lt.t - DT)
eq(hurts(ev, 1), 0, "예고 동안에는 맞지 않는다")
eq(h.hp, hp0, "체력 그대로")
ev = run(room, heroes, DT * 3)
eq(hurts(ev, 1), 1, "예고가 끝나면 그 자리의 사람이 맞는다")
expect(h.hp < hp0 and h.hp > hp0 * 0.85, ("한 방에 체력의 15%% 넘게 깎이지 않는다 %d → %d"):format(hp0, h.hp))
expect(lt.state == "act" or lt.state == "idle", "친다")
run(room, heroes, p.act + 0.1)
-- 굳어 있는 시간(act)이 끝나면 다음 패턴까지 쉰다(rest) — 그동안은 돌아서거나 다가올 뿐 치지 않는다(맞는 자리의 가운데가 서는 거리 keep보다 멀면 그새 다가온다)
expect((lt.state == "idle" or lt.state == "run") and lt.pat == 0 and lt.rest > 0.3, "친 뒤에는 다음 패턴까지 틈이 있다(때릴 틈) — " .. lt.state)

-- 패턴마다: 피하는 법대로 하면 맞지 않는다
do
	-- 내려찍기: 뒤로 물러나면 · 등 뒤로 돌아가면 안 맞는다 / 발판 위(48점)에 서 있어도 맞는다(안전한 자리가 없게)
	lt.x = 400
	local q = force(lt, "smash", 1)
	h.x, h.y, h.invuln = lt.x + q.zone.to + 12, FLOOR, 0
	eq(hurts(run(room, heroes, q.tell + 0.1), 1), 0, "내려찍기: 뒤로 물러나면 안 맞는다")
	q = force(lt, "smash", 1)
	h.x, h.invuln = lt.x - 20, 0
	eq(hurts(run(room, heroes, q.tell + 0.1), 1), 0, "내려찍기: 등 뒤에서는 안 맞는다")
	q = force(lt, "smash", 1)
	h.x, h.y, h.invuln = lt.x + 30, FLOOR - 48, 0
	eq(hurts(run(room, heroes, q.tell + 0.1), 1), 1, "내려찍기: 발판 높이(48점)에서도 맞는다")
	-- 휩쓸기: 낮다 — 뛰어 있으면 넘는다 · 서 있으면 맞는다
	q = force(lt, "sweep", 1)
	h.x, h.y, h.invuln = lt.x + 50, FLOOR - 20, 0
	eq(hurts(run(room, heroes, q.tell + 0.1), 1), 0, "휩쓸기: 뛰어 있으면 넘는다")
	q = force(lt, "sweep", 1)
	h.x, h.y, h.invuln = lt.x + 50, FLOOR, 0
	eq(hurts(run(room, heroes, q.tell + 0.1), 1), 1, "휩쓸기: 서 있으면 맞는다")
	-- 고르기: 가까이 있으면 내려찍기와 휩쓸기를 번갈아(방금 쓴 것은 다시 뽑지 않는다) · 체력 구간 뒤의 것(땅 울림 · 연속 찍기 · 봉화 불기둥)은 아직 쓰지 않는다
	lt.state, lt.pat, lt.rest, lt.used, lt.lastPat, lt.raged = "idle", 0, 0, {}, 0, false
	h.x, h.y = lt.x + 30, FLOOR
	lt.hp = lt.maxHp
	local function picks(n: number, far: boolean?)
		local seen, order = {}, {}
		for _ = 1, n do
			if far then
				h.x = if lt.x > 384 then lt.x - 200 else lt.x + 200 -- 멀리 선다(보스가 다가오면 다시 물러난다)
			end
			run(room, heroes, 20, function()
				if far and math.abs(h.x - lt.x) < 130 and lt.state ~= "tell" and lt.state ~= "act" then
					h.x = if lt.x > 384 then lt.x - 200 else lt.x + 200
				end
				return lt.state == "tell"
			end)
			local id = if (lt.chainPat or 0) > 0 then lt.def.story.patterns[lt.chainPat].id else lt.def.story.patterns[lt.pat].id
			seen[id] = true
			table.insert(order, id)
			h.invuln = 99
			run(room, heroes, 12, function()
				return lt.state == "idle" and lt.rest <= 0.05
			end)
		end
		return seen, order
	end
	local seen, order = picks(6)
	expect(seen.smash and seen.sweep and not (seen.quake or seen.combo or seen.beacon or seen.embers or seen.leap), "체력이 많고 가까이: 내려찍기와 휩쓸기만")
	for k = 2, #order do
		expect(order[k] ~= order[k - 1], "같은 것을 연달아 쓰지 않는다 — " .. table.concat(order, " "))
	end
	expect(not lt.raged, "체력이 많을 때는 포효하지 않는다")
	-- 멀리 있으면: 불씨 뿌리기 · 도약 찍기(멀리 도망가도 쉴 수 없다)
	lt.state, lt.pat, lt.rest, lt.used, lt.lastPat = "idle", 0, 0, {}, 0
	seen = picks(4, true)
	expect(seen.embers and seen.leap and not (seen.smash or seen.sweep), "멀리 있으면 불씨 뿌리기와 도약 찍기를 쓴다")
	-- 체력 구간: 체력이 60% 아래로 내려가면 한 번 포효한다(그동안은 치지 않는다) → 그 뒤로 땅 울림 · 연속 찍기 · 봉화 불기둥이 열린다
	lt.state, lt.pat, lt.rest, lt.used, lt.lastPat = "idle", 0, 0, {}, 0
	lt.hp = math.floor(lt.maxHp * 0.4)
	h.x, h.y, h.invuln = lt.x + 30, FLOOR, 0
	ev = run(room, heroes, 0.2)
	local ph = lt.def.story.phase
	expect(lt.state == "roar" and lt.raged == true, "체력 구간: 포효한다 — " .. lt.state)
	eq(room:snapshot()[lt.id][4], "roar", "화면에 포효를 보낸다")
	ev = run(room, heroes, ph.time - 0.3)
	expect(lt.state == "roar" and hurts(ev, 1) == 0, "포효하는 동안은 치지 않는다(때릴 틈)")
	run(room, heroes, 0.4)
	expect(lt.state ~= "roar", "포효가 끝난다")
	seen = picks(14)
	expect(seen.quake and seen.combo and seen.beacon, "체력 구간 뒤: 땅 울림 · 연속 찍기 · 봉화 불기둥을 쓴다")
	expect(lt.raged and lt.state ~= "roar", "포효는 한 번뿐이다")
	lt.state, lt.pat, lt.rest, lt.chain, lt.chainPat, lt.quick = "idle", 0, 0, nil, 0, 1
	lt.bind = 0.3
	run(room, heroes, 0.4)
	-- 불씨 뿌리기: 겨눈 사람의 발밑과 그 좌우에 자리 넷 — 예고가 끝나면 솟는다. 발밑에 그대로 서 있으면 맞고, 자리 사이로 옮기면 안 맞는다
	lt.x, h.x, h.y, h.invuln = 600, 300, FLOOR, 0
	local q = force(lt, "embers", -1, h)
	eq(#room.blasts, q.spots.n, "불씨가 떨어질 자리 넷")
	eq(room.blasts[1].x, 300, "첫 자리는 겨눈 사람의 발밑")
	eq(room:snapshot()[lt.id][10], 300, "화면에 겨눈 자리를 보낸다")
	ev = run(room, heroes, q.tell - DT)
	eq(hurts(ev, 1), 0, "불씨: 예고 동안에는 안 맞는다")
	ev = run(room, heroes, 0.5)
	eq(hurts(ev, 1), 1, "불씨: 발밑에 그대로 서 있으면 맞는다")
	eq(#room.blasts, 0, "솟고 나면 자리가 사라진다")
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	lt.x, h.x, h.invuln = 600, 300, 0
	q = force(lt, "embers", -1, h)
	h.x = 300 + q.spots.spread / 2 -- 두 자리의 한가운데
	expect(q.spots.spread / 2 > q.spots.r + 5, "자리 사이에 설 틈이 있다")
	ev = run(room, heroes, q.tell + 0.6)
	eq(hurts(ev, 1), 0, "불씨: 자리 사이로 옮기면 안 맞는다")
	-- 예고하던 중에 묶이면 표시된 자리도 사라진다
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	lt.x, h.x, h.invuln = 600, 300, 0
	q = force(lt, "embers", -1, h)
	lt.bind = 2
	ev = run(room, heroes, q.tell + 0.6)
	expect(hurts(ev, 1) == 0 and (room.blasts == nil or #room.blasts == 0), "묶이면 불씨의 자리도 사라진다")
	lt.bind = 0
	-- 도약 찍기: 뛰어올라 겨눈 자리에 내려앉으며 찍는다. 붉은 자리는 뛰기 0.25초 전까지 따라온다 → 그 뒤에 밖으로 나가면 안 맞는다
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	lt.x, h.x, h.y, h.invuln = 600, 300, FLOOR, 0
	q = force(lt, "leap", -1, h)
	run(room, heroes, 0.4)
	h.x = 260 -- 예고하는 동안 움직이면 겨눈 자리가 따라온다
	run(room, heroes, 0.2)
	eq(lt.aim, 260, "도약: 겨눈 자리가 사람을 따라온다")
	ev = run(room, heroes, 2, function()
		return lt.state == "act"
	end)
	expect(lt.state == "act" and lt.x == 600 and hurts(ev, 1) == 0, "도약: 예고가 끝나면 뛰어오른다(아직 안 맞는다)")
	run(room, heroes, q.leap.time / 2)
	expect(lt.alt > q.leap.peak * 0.8 and lt.x < 600 and lt.x > 260, ("도약: 공중을 날아간다(높이 %.0f · x %.0f)"):format(lt.alt, lt.x))
	ev = run(room, heroes, q.leap.time / 2 + DT * 2)
	eq(hurts(ev, 1), 1, "도약: 그 자리에 그대로 서 있으면 내려앉을 때 맞는다")
	expect(lt.alt == 0 and math.abs(lt.x - (260 + q.leap.aim)) < 1, ("도약: 겨눈 자리 앞에 내려앉는다(x %.0f)"):format(lt.x))
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	lt.x, h.x, h.invuln = 600, 300, 0
	q = force(lt, "leap", -1, h)
	run(room, heroes, q.tell - 0.2) -- 겨눈 자리가 멈춘 뒤(뛰기 0.25초 전)
	h.x = 300 + q.zone.to + 80 -- 붉은 자리 밖으로(보스 쪽으로 지나쳐 나간다)
	ev = run(room, heroes, 0.2 + q.leap.time + 0.2)
	eq(hurts(ev, 1), 0, "도약: 붉은 자리 밖으로 나가면 안 맞는다")
	-- 봉화 불기둥: 방 전체에 한 칸 걸러 한 칸 — 먼저 터지는 칸에 서 있으면 맞고, 나중 칸에 서 있다가 첫 불기둥이 꺼진 뒤 옮기면 안 맞는다
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	lt.x, h.invuln = 400, 0
	q = force(lt, "beacon", -1, h)
	local first, second = nil, nil
	for _, bl in room.blasts do
		if math.abs(bl.t - q.tell) < 0.01 then
			first = first or bl.x
		else
			second = second or bl.x
		end
	end
	expect(first ~= nil and second ~= nil and math.abs(second - first) == q.spots.gap, "불기둥의 자리: 먼저 터지는 칸과 나중 칸이 번갈아 있다")
	expect(#room.blasts >= 8, ("방 전체에 깔린다(%d곳)"):format(#room.blasts))
	h.x = first
	ev = run(room, heroes, q.tell + 0.1)
	eq(hurts(ev, 1), 1, "불기둥: 먼저 터지는 칸에 서 있으면 맞는다")
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	h.invuln = 0
	q = force(lt, "beacon", -1, h)
	h.x = second
	ev = run(room, heroes, q.tell + 0.2)
	eq(hurts(ev, 1), 0, "불기둥: 나중 칸에 서 있으면 첫 번에는 안 맞는다")
	h.x = first -- 방금 터진 칸으로 옮긴다
	ev = run(room, heroes, q.spots.lag + 0.2)
	eq(hurts(ev, 1), 0, "불기둥: 첫 불기둥이 꺼진 칸으로 옮기면 둘째 번도 안 맞는다")
	eq(#room.blasts, 0, "다 터지면 자리가 사라진다")
	-- 연속 찍기: 내려찍기 → 내려찍기 → 땅 울림을 쉬지 않고 잇는다. 첫 번째는 제 예고대로, 둘째부터 quick배. 다 끝나면 길게 쉰다
	lt.state, lt.pat, lt.rest = "idle", 0, 9
	lt.x, h.x, h.y, h.invuln = 400, 300, FLOOR, 99
	local combo, sub = force(lt, "combo", -1, h)
	local smash = sub
	expect(smash.id == "smash" and lt.chainPat > 0 and lt.quick == 1, "연속기: 첫 패턴(내려찍기)부터 — 제 예고대로")
	eq(room:snapshot()[lt.id][11], lt.chainPat, "화면에 연속기의 차례를 보낸다")
	eq(room:snapshot()[lt.id][12], 0, "첫 번째는 빠르지 않다")
	run(room, heroes, smash.tell + smash.act + DT * 2)
	expect(lt.state == "tell" and lt.def.story.patterns[lt.pat].id == "smash" and lt.quick == combo.quick, "연속기: 쉬지 않고 둘째(내려찍기 — 빠르게)를 예고한다")
	eq(room:snapshot()[lt.id][12], 1, "화면에 빠른 패턴임을 보낸다")
	run(room, heroes, smash.tell * combo.quick - lt.t - DT)
	expect(lt.state == "tell" and math.abs(lt.x - (400 - combo.chainStep)) < 0.5, ("연속기: 예고하면서 한 걸음(%d점) 다가선다(400 → %.0f)"):format(combo.chainStep, lt.x))
	run(room, heroes, DT * 2 + math.max(0.25, smash.act * combo.quick))
	expect(lt.state == "tell" and lt.def.story.patterns[lt.pat].id == "quake", "연속기: 셋째(땅 울림)")
	run(room, heroes, 3, function()
		return lt.state == "idle"
	end)
	expect(lt.state == "idle" and lt.chainPat == 0 and lt.rest > 1.2, ("연속기가 끝나면 길게 쉰다(%.2f초)"):format(lt.rest))
	room.waves = nil
	lt.raged = false
	-- 물결: 내려찍은 자리에서 양쪽으로 — 멀리 서 있으면 물결이 와서 맞고, 뛰어 있으면 넘는다
	room.waves = nil
	lt.x = 400
	q = force(lt, "quake", 1)
	h.x, h.y, h.invuln = lt.x - 120, FLOOR, 0 -- 등 뒤 멀리
	ev = run(room, heroes, q.tell + 0.05)
	eq(hurts(ev, 1), 0, "땅 울림: 내려찍는 자리 밖은 그 순간에는 안 맞는다")
	expect(room.waves ~= nil and #room.waves == 2, "물결 둘이 생긴다")
	local travel = (q.wave.at + 120) / q.wave.speed -- 물결이 생기는 자리(보는 쪽으로 wave.at)에서 등 뒤 120점의 사람까지
	ev = run(room, heroes, travel + 0.3)
	eq(hurts(ev, 1), 1, "물결이 와서 맞는다(한 번)")
	q = force(lt, "quake", 1)
	room.waves = nil
	h.x, h.y, h.invuln = lt.x - 120, FLOOR - 30, 0
	ev = run(room, heroes, q.tell + travel + 0.4)
	eq(hurts(ev, 1), 0, "물결: 뛰어 있으면 넘는다")
	lt.bind = 9 -- 기다리는 동안 새 패턴을 고르지 않게 묶어 둔다
	run(room, heroes, 3)
	lt.bind = 0
	eq(#room.waves, 0, "물결은 끝까지 가면 사라진다")
end

-- 맞아도 멈칫하지 않고 밀리지 않는다 · 쓰러뜨리면 경험치도 물건도 없다 · 방에 있는 모두의 퀘스트가 찬다
do
	h.y, h.invuln = FLOOR, 99
	lt.hp = lt.maxHp
	local q = force(lt, "smash", 1)
	local x = lt.x
	local out = { hits = {}, kills = {} }
	room:strike(h, lt, 50, h.x, nil, out)
	expect(lt.state == "tell" and lt.x == x and lt.hp == lt.maxHp - 50, "맞아도 예고를 멈추지 않고 밀리지 않는다")
	eq(#out.kills, 0, "아직 살아 있다")
	-- 함께 온 사람(퀘스트를 하는 중) 하나 더
	local mate = hero(2, 26, "r1m7")
	heroes[2] = mate
	mate.invuln = 99
	run(room, heroes, DT)
	local xp0, lv0 = h.xp, h.level
	out = { hits = {}, kills = {} }
	local dead = room:strike(h, lt, lt.hp, h.x, nil, out)
	expect(dead and lt.state == "dead", "쓰러진다")
	eq(#out.kills, 1, "잡은 것 하나")
	local kill = out.kills[1]
	expect(kill.xp == 0 and kill.drop == nil and #kill.loot == 0, "경험치도 떨어지는 것도 없다")
	expect(h.xp == xp0 and h.level == lv0, "경험치가 오르지 않는다")
	eq(#kill.gains, 2, "방에 있는 둘 모두에게 잡은 것으로 친다")
	for _, g in kill.gains do
		eq(g.xp, 0, "몫도 0")
	end
	eq(next(room.drops), nil, "바닥에 떨어진 것이 없다")
	-- 서버가 하는 대로 퀘스트를 센다
	for _, g in kill.gains do
		local who = heroes[g.hero]
		expect(#Quests.onKill(who.quests, kill.kind, KEY) > 0, "퀘스트의 숫자가 오른다")
		expect(Quests.isReady(who.quests, "r1m7"), "「망루의 부관」의 할 일이 끝났다")
		expect(not Quests.wantsKill(who.quests, "towerlieutenant", KEY), "더 잡을 것이 없다")
	end
	-- 쓰러지는 동작 그림이 있는 보스는 그 그림이 다 보일 때까지(story.fall초 — 동작 + 누워 있는 시간 + 사라지는 시간) 쓰러진 채 남는다. 없는 보스는 0.9초
	local fall = lt.def.story.fall
	if fall then
		expect(fall > 1 and fall < 4, ("쓰러져 사라지기까지 %.2f초 — 1~4초"):format(fall))
		run(room, heroes, fall - 0.2)
		eq(lt.state, "dead", "쓰러지는 동작이 다 보일 때까지는 쓰러진 채 있다")
		run(room, heroes, 0.4)
	else
		run(room, heroes, 1.5)
	end
	expect(lt.state == "gone" and lt.away, "쓰러진 뒤 사라진다")
	run(room, heroes, 30)
	expect(lt.state == "gone" and lt.away, "다시 나오지 않는다(다시 싸울 수 없다)")
	expect(cap.state == "gone", "「정찰대장」을 받기 전에는 대장도 없다")
	heroes[2] = nil
end

-- 「정찰대장」: 호령 · 내달리기
do
	h.quests.r1m7.done = true
	h.quests.r1m8 = { done = false, c = {} }
	Hero.setLevel(h, 28)
	h.x, h.y, h.invuln = 140, FLOOR, 0
	run(room, heroes, 1.2)
	expect(not cap.away and cap.state ~= "gone" and cap.hp == cap.maxHp, "「정찰대장」을 하는 중이면 대장이 선다")
	expect(lt.away, "부관은 없다")
	local adds = cap.adds
	eq(#adds, 4, "부르는 검병의 자리 넷")
	for _, a in adds do
		expect(a.away and a.state == "gone" and a.kind == "warrior", "아직 아무도 없다")
	end
	-- 호령: 둘이 방의 양 끝에서 나온다 · 한 번 더 부르면 넷 · 넷이 서 있으면 더 부르지 않는다
	cap.x = 400
	h.invuln = 99
	local q = force(cap, "call", -1)
	run(room, heroes, q.tell + 0.1)
	local outN, xs = 0, {}
	for _, a in adds do
		if not a.away then
			outN += 1
			table.insert(xs, a.x)
		end
	end
	eq(outN, 2, "검병 둘이 나온다")
	table.sort(xs)
	expect(xs[1] < 100 and xs[2] > 660, ("방의 양 끝에서 %.0f · %.0f"):format(xs[1], xs[2]))
	q = force(cap, "call", -1)
	run(room, heroes, q.tell + 0.1)
	outN = 0
	for _, a in adds do
		outN += if a.away then 0 else 1
	end
	eq(outN, 4, "두 번 부르면 넷")
	cap.state, cap.pat, cap.rest, cap.used = "idle", 0, 0, {}
	local best = room:bossPick(cap, 30)
	expect(best ~= nil and best.id ~= "call", "넷이 서 있으면 호령은 고르지 않는다 — " .. tostring(best and best.id))
	-- 불려 나온 검병: 잡아도 경험치도 물건도 없다 · 저절로 다시 나오지 않는다
	run(room, heroes, 1.5)
	local a1 = adds[1]
	expect(a1.state ~= "gone" and a1.state ~= "spawn", "나와서 움직인다 — " .. a1.state)
	local xp0 = h.xp
	local out = { hits = {}, kills = {} }
	expect(room:strike(h, a1, a1.hp, h.x, nil, out), "검병을 잡는다")
	expect(#out.kills == 1 and out.kills[1].xp == 0 and #out.kills[1].gains == 0 and out.kills[1].drop == nil and #out.kills[1].loot == 0, "아무것도 주지 않는다")
	eq(h.xp, xp0, "경험치 그대로")
	cap.bind = 30 -- 기다리는 동안 다시 호령하지 않게 묶어 둔다
	run(room, heroes, 12)
	cap.bind = 0
	expect(a1.away and a1.state == "gone", "저절로 다시 나오지 않는다")
	-- 내달리기: 보는 쪽의 벽까지 달린다 — 길 위에 서 있으면 한 번 맞고, 뛰어 있으면 넘는다
	for _, a in adds do
		a.state, a.away = "gone", true
	end
	cap.x = 600
	q = force(cap, "charge", -1)
	h.x, h.y, h.invuln = 300, FLOOR, 0
	local ev = run(room, heroes, q.tell - DT)
	expect(cap.x == 600 and hurts(ev, 1) == 0, "예고 동안에는 서 있다")
	ev = run(room, heroes, 3, function()
		return cap.state == "idle"
	end)
	eq(hurts(ev, 1), 1, "내달리는 길 위에 서 있으면 맞는다(한 번)")
	eq(cap.x, cap.a, "보는 쪽의 벽까지 달린다")
	expect(cap.rest > 0.5, "달린 뒤에는 굳어 있다")
	cap.x = 600
	q = force(cap, "charge", -1)
	h.x, h.y, h.invuln = 300, FLOOR - 48, 0
	ev = run(room, heroes, 4, function()
		return cap.state == "idle"
	end)
	eq(hurts(ev, 1), 0, "발판 위(48점)에 있으면 달려오는 것을 넘긴다")
	-- 검기: 보는 쪽으로만 초승달이 날아간다 — 서 있으면 맞고, 뛰어 있으면 넘고, 등 뒤는 안 맞는다
	room.waves = nil
	cap.x = 600
	q = force(cap, "bladewave", -1)
	h.x, h.y, h.invuln = 300, FLOOR, 0
	ev = run(room, heroes, q.tell + DT)
	expect(room.waves ~= nil and #room.waves == 1 and room.waves[1].dir == -1, "검기 하나가 보는 쪽으로 떠난다")
	eq(hurts(ev, 1), 0, "검기: 떠나는 순간에는 멀리 있는 사람이 안 맞는다")
	ev = run(room, heroes, (600 - q.wave.at - 300) / q.wave.speed + 0.3)
	eq(hurts(ev, 1), 1, "검기가 와서 맞는다(한 번)")
	cap.state, cap.pat, cap.rest = "idle", 0, 9
	room.waves = nil
	q = force(cap, "bladewave", -1)
	h.x, h.y, h.invuln = 300, FLOOR - 30, 0
	ev = run(room, heroes, q.tell + (600 - q.wave.at - 300) / q.wave.speed + 0.4)
	eq(hurts(ev, 1), 0, "검기: 뛰어 있으면 넘는다")
	cap.state, cap.pat, cap.rest = "idle", 0, 9
	room.waves = nil
	q = force(cap, "bladewave", -1)
	h.x, h.y, h.invuln = 700, FLOOR, 0
	ev = run(room, heroes, q.tell + 2)
	eq(hurts(ev, 1), 0, "검기: 등 뒤에서는 안 맞는다")
	-- 연속 검기: 셋이 gap초 간격으로 — 서 있으면 맞는다(맞은 뒤의 짧은 무적 때문에 셋을 다 맞지는 않는다)
	cap.state, cap.pat, cap.rest = "idle", 0, 9
	room.waves = nil
	q = force(cap, "storm", -1)
	run(room, heroes, q.tell + DT)
	eq(#room.waves, q.wave.n, "연속 검기: 물결 셋")
	local waits = {}
	for _, w in room.waves do
		table.insert(waits, w.wait or 0)
	end
	table.sort(waits)
	expect(waits[1] <= 0 and math.abs(waits[2] - q.wave.gap) < DT * 3 and math.abs(waits[3] - q.wave.gap * 2) < DT * 3, "하나씩 gap초 간격으로 떠난다")
	cap.bind = 9
	run(room, heroes, 6)
	cap.bind = 0
	eq(#room.waves, 0, "검기는 끝까지 가면 사라진다")
	-- 몰아치기: 내리베기 → 내리베기 → 내달리기를 쉬지 않고 잇는다(벽까지 달린 뒤 길게 쉰다)
	cap.state, cap.pat, cap.rest = "idle", 0, 9
	cap.x, h.x, h.y, h.invuln = 500, 400, FLOOR, 99
	local triple, sub = force(cap, "triple", -1, h)
	expect(sub.id == "slash" and cap.chainPat > 0, "몰아치기: 내리베기부터")
	local chainIds = { sub.id }
	local lastPat = cap.pat
	run(room, heroes, 12, function()
		if cap.pat ~= 0 and (cap.pat ~= lastPat or (cap.state == "tell" and cap.t <= DT * 1.5 and #chainIds < 2)) then
			if cap.state == "tell" and cap.t <= DT * 1.5 then
				table.insert(chainIds, cap.def.story.patterns[cap.pat].id)
			end
			lastPat = cap.pat
		end
		return cap.state == "idle"
	end)
	expect(cap.state == "idle" and cap.chainPat == 0 and cap.rest > 1.2, "몰아치기가 끝나면 길게 쉰다")
	expect(chainIds[#chainIds] == "charge" and (cap.x == cap.a or cap.x == cap.b), ("몰아치기의 끝은 내달리기 — 벽까지(%s)"):format(table.concat(chainIds, " ")))
	-- 체력이 많고 가까이 있으면: 내리베기와 호령
	cap.hp, cap.used, cap.rest, cap.lastPat, cap.raged, cap.chain, cap.chainPat, cap.quick = cap.maxHp, {}, 0, 0, false, nil, 0, 1
	for _, a in cap.adds do
		a.state, a.away = "gone", true
	end
	local saw = {}
	h.x, h.y, h.invuln = cap.x + 40, FLOOR, 99
	for _ = 1, 5 do
		run(room, heroes, 20, function()
			return cap.state == "tell"
		end)
		saw[cap.def.story.patterns[cap.pat].id] = true
		run(room, heroes, 5, function()
			return cap.state == "idle" and cap.rest <= 0.05
		end)
	end
	expect(saw.slash and saw.call and not (saw.charge or saw.bladewave or saw.storm or saw.triple), "체력이 많고 가까이: 내리베기와 호령(멀리 있을 때 쓰는 검기 · 내달리기는 쓰지 않는다)")
end

-- 방을 비우면(쓰러져 마을로 돌아갔다) 보스가 사라지고, 다시 들어오면 체력이 가득한 채 새로 선다
do
	cap.hp = math.floor(cap.maxHp * 0.3)
	expect(not cap.away, "싸우는 중")
	room:idle() -- 서버: 아무도 없는 방
	expect(cap.away and cap.state == "gone", "아무도 없으면 사라진다")
	for _, a in cap.adds do
		expect(a.away and a.state == "gone", "부른 검병도 같이 사라진다")
	end
	h.x, h.invuln = 140, 0
	run(room, heroes, 0.2)
	expect(not cap.away and cap.state == "spawn" and cap.hp == cap.maxHp and cap.x == cap.homeX, "다시 들어오면 체력이 가득한 채 제자리에 선다")
	-- 묶이면(바인드) 하던 것을 그만둔다
	run(room, heroes, 1)
	local q = force(cap, "slash", -1)
	cap.bind = 2
	h.x, h.invuln = cap.x - 30, 0
	local ev = run(room, heroes, q.tell + 0.3)
	expect(cap.state == "idle" and cap.pat == 0 and hurts(ev, 1) == 0, "묶이면 예고하던 것을 그만둔다(맞지 않는다)")
	-- 퀘스트를 끝낸 사람만 남으면 사라진다
	h.quests.r1m8.done = true
	run(room, heroes, 0.2)
	expect(cap.away, "퀘스트를 끝내면 다시 나오지 않는다")
end

-- 부관과 대장을 따로 하는 두 사람이 같이 있으면: 이야기의 차례로 부관이 먼저, 한 번에 하나만 선다
do
	local r2 = Room.new(KEY, scene, Random.new(5))
	local a, b = hero(11, 28, "r1m8"), hero(12, 25, "r1m7")
	a.invuln, b.invuln = 99, 99
	local both = { [11] = a, [12] = b }
	run(r2, both, 0.2)
	local l2, c2 = bossOf(r2, "towerlieutenant"), bossOf(r2, "scoutcaptain")
	expect(not l2.away and c2.away, "부관이 먼저 선다(대장은 아직)")
	local out = { hits = {}, kills = {} }
	r2:strike(a, l2, l2.hp, a.x, nil, out)
	eq(#out.kills[1].gains, 2, "둘 다 잡은 것으로 친다")
	Quests.onKill(b.quests, "towerlieutenant", KEY)
	eq(#Quests.onKill(a.quests, "towerlieutenant", KEY), 0, "그 퀘스트가 없는 사람은 오르는 것이 없다")
	run(r2, both, 0.2)
	expect(c2.away, "쓰러지는 부관 위에 대장이 서지 않는다(쓰러지는 동작이 끝날 때까지 — 2026-10-18 검토)")
	run(r2, both, (l2.def.story.fall or 0.9) + 0.6) -- 쓰러지는 동작이 다 보인 뒤에 사라진다(story.fall초 — 없으면 0.9초)
	expect(l2.away and not c2.away, "부관이 사라진 뒤에 대장이 선다")
end

-- 싸우는 중인 보스는 앞 퀘스트의 사람이 들어와도 그대로 선다(2026-10-18 검토: 이야기의 차례로 늘 다시 골라, 대장을 20%까지 깎았는데 부관 퀘스트의 사람이 들어오면 대장이 사라지고 부관이 섰다)
do
	local r3 = Room.new(KEY, scene, Random.new(6))
	local a = hero(21, 28, "r1m8")
	a.invuln = 99
	run(r3, { [21] = a }, 0.5)
	local l3, c3 = bossOf(r3, "towerlieutenant"), bossOf(r3, "scoutcaptain")
	expect(not c3.away and l3.away, "대장 퀘스트의 사람만 있으면 대장이 선다")
	c3.hp = math.floor(c3.maxHp * 0.2)
	local hpWas = c3.hp
	local b = hero(22, 25, "r1m7")
	b.invuln = 99
	run(r3, { [21] = a, [22] = b }, 0.5)
	expect(not c3.away and c3.hp <= hpWas and l3.away, "부관 퀘스트의 사람이 들어와도 싸우던 대장이 그대로 선다")
	-- 대장을 쓰러뜨리면(대장 퀘스트의 사람만 있는 것이 아니다) 그 뒤에 부관이 선다
	local out = { hits = {}, kills = {} }
	r3:strike(a, c3, c3.hp, a.x, nil, out)
	run(r3, { [21] = a, [22] = b }, (c3.def.story.fall or 0.9) + 0.6)
	expect(c3.away and not l3.away, "대장이 쓰러진 뒤에 부관 퀘스트의 사람을 위해 부관이 선다")
end

-- ---- 3) 서버: 퀘스트를 하는 사람이 방에 들어오면 보스가 서고, 쓰러뜨리면 퀘스트만 찬다(경험치 알림 없음) · 방을 비우면 새로 선다 ----
do
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
		rankSet = function() end,
		rankRemove = function() end,
		rankTop = function() return {} end,
		rankInfoSet = function() end,
		rankInfoGet = function() return nil end,
		rankInfoRemove = function() end,
		isOffline = function() return false end,
	})
	local World = req("ServerScriptService/server/lune/modules/world")
	World.start()
	local p = { UserId = 4301, Name = "보스4301", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", "망루4301", "riven")
	handlers.Chars(p, "enter", made.id)
	local s = World.session(p)
	local wh = s.hero
	Hero.setLevel(wh, 25)
	Quests.finishBefore(wh.quests, "r1m7") -- 줄에서 「망루의 부관」 앞의 것을 모두 끝냈다
	local function tick(seconds: number)
		for _ = 1, math.floor(seconds / DT + 0.5) do
			World.tick(DT)
		end
	end
	local function count(name: string): number
		local n = 0
		for _, e in sent do
			n += if e.name == name then 1 else 0
		end
		return n
	end
	-- 퀘스트 없이 올라가면 빈 방이다
	expect(World.jump(p, KEY), "망루 꼭대기로")
	handlers.Move(p, wh.x, wh.y, 1)
	tick(1)
	local wroom = World.room(KEY)
	local wlt, wcap = wroom.bosses[1], wroom.bosses[2]
	expect(wlt.away and wcap.away, "퀘스트가 없으면 보스가 없다")
	-- 「망루의 부관」을 받고 올라오면 선다
	World.jump(p, "r1cc")
	handlers.Move(p, wh.x, wh.y, 1)
	tick(0.2)
	expect(Quests.accept(wh.quests, wh.level, "r1m7"), "차돌에게 「망루의 부관」을 받는다(Lv.25 · 앞의 메인 여섯을 끝냈다)")
	World.jump(p, KEY)
	handlers.Move(p, wh.x, wh.y, 1)
	tick(1.2)
	expect(not wlt.away and wlt.state ~= "gone" and wlt.hp == wlt.maxHp, "퀘스트를 하는 중이면 부관이 서 있다")
	local desc = wroom:describe(wh.id)
	expect(desc.mobs[wlt.id].boss == true and desc.snap[wlt.id][4] ~= "gone", "방의 모습에 보스가 실린다")
	-- 싸우다 나가면(쓰러져 마을로 · 문으로) 방이 비어 보스가 사라지고, 다시 오면 체력이 가득하다
	wlt.hp = math.floor(wlt.maxHp / 2)
	World.jump(p, "r1c3")
	handlers.Move(p, wh.x, wh.y, 1)
	tick(0.3)
	expect(wlt.away and wlt.state == "gone", "방을 비우면 보스가 사라진다")
	World.jump(p, KEY)
	handlers.Move(p, wh.x, wh.y, 1)
	tick(1.2)
	expect(not wlt.away and wlt.hp == wlt.maxHp, "다시 올라오면 체력이 가득한 채 서 있다")
	-- 기술로 쓰러뜨린다(서버의 길 그대로): 퀘스트의 숫자가 오르고, 경험치 알림(Gain)은 없고, 바닥에 떨어지는 것도 없다
	wh.invuln = 9999
	wlt.hp = 1
	wh.x, wh.dir = wlt.x - 20, 1
	handlers.Move(p, wh.x, wh.y, 1)
	table.clear(sent)
	local xp0, money0 = wh.xp, wh.money
	local skill
	for id, sk in COMBAT.skills do
		if sk.who == "riven" and sk.type == "boss" and (sk.job or 1) == 1 then
			skill = id
		end
	end
	expect(skill ~= nil, "리븐의 1차 보스기")
	handlers.Skill(p, skill, 1, wh.x, wh.y, 1)
	tick(1.5)
	expect(wlt.state == "dead" or wlt.state == "gone", "부관이 쓰러졌다 — " .. wlt.state)
	expect(Quests.isReady(wh.quests, "r1m7"), "「망루의 부관」의 할 일이 끝났다")
	eq(count("Gain"), 0, "경험치 알림이 없다")
	expect(count("Quests") >= 1, "퀘스트의 숫자를 알린다")
	eq(count("DropAdd"), 0, "떨어지는 것이 없다")
	expect(wh.xp == xp0 and wh.money == money0, "경험치도 달돈도 그대로다")
	tick(2)
	expect(wlt.away, "사라졌다")
	tick(20)
	expect(wlt.away and wcap.away, "다시 나오지 않는다 · 대장은 「정찰대장」을 받아야 선다")
	-- 차돌에게 돌려주고 「정찰대장」을 받으면 대장이 선다
	Quests.complete(wh.quests, "r1m7")
	expect(Quests.accept(wh.quests, wh.level, "r1m8") == nil, "「정찰대장」은 Lv.28부터")
	Hero.setLevel(wh, 28)
	Quests.finishBefore(wh.quests, "r1m8") -- (줄에서 그 사이의 「마을 문 고치기」도 끝냈다)
	expect(Quests.accept(wh.quests, wh.level, "r1m8"), "「정찰대장」을 받는다")
	tick(1.2)
	expect(not wcap.away and wlt.away, "대장이 선다(부관은 없다)")
end

-- ---- 4) 난이도(사용자 2026-10-11: "난이도는 2차수준이 깰수가 없는 수준인데요?") ----
--  피하지 않는 사람(보스 앞에 붙어 서서 1차 보스기만 되풀이한다 · 예고를 봐도 비키지 않는다)도 깰 수 있어야 한다:
--  그 레벨의 캐릭터(본보기 장비)가 1분 안에 쓰러뜨리고, 그동안 받는 피해가 제 체력의 두 배를 넘지 않는다(물약 몇 병).
do
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	for _, b in scene.bosses do
		local def = COMBAT.mobs[b.kind]
		local q = Quests.def(def.story.quest)
		local r3 = Room.new(KEY, scene, Random.new(9))
		local hh = Hero.new(21, "riven")
		Hero.setLevel(hh, b.lv)
		for _, slot in Items.data.SLOTS do
			hh.equip[slot.id] = Items.make(slot.id, hh.level, nil, hh.class)
		end
		Hero.setLevel(hh, b.lv) -- 장비를 낀 체력으로
		hh.quests[q.id] = { done = false, c = {} }
		hh.x, hh.y = b.x - 60, FLOOR
		local all = { [21] = hh }
		local boss = bossOf(r3, b.kind)
		local sk = COMBAT.skills.rv_double
		local t, lost, casts, nextCast, dead = 0, 0, 0, 1.2, false
		while t < 120 and not dead do
			-- 보스 앞 30점에 붙어 선다(보스가 움직이면 따라간다) — 피하지 않는다
			if boss.state ~= "gone" and boss.state ~= "spawn" then
				hh.x = boss.x + boss.dir * 30 -- 보스가 보는 쪽 앞(맞는 자리 안)
			end
			if hh.hp < hh.maxHp * 0.5 then -- 물약: 절반 아래면 다 채운 것으로 치고 받은 피해만 센다
				hh.hp = hh.maxHp
			end
			local before = hh.hp
			Hero.tick(hh, DT) -- 맞은 뒤의 짧은 무적 시간이 흐른다(서버가 하는 일)
			r3:step(all, DT)
			lost += math.max(0, before - hh.hp)
			t += DT
			if t >= nextCast and boss.state ~= "gone" and boss.state ~= "spawn" and boss.state ~= "dead" then
				nextCast = t + sk.time
				casts += 1
				for _, hit in sk.hits do
					local res = r3:skillHit(hh, hit, hh.x, hh.y, if boss.x >= hh.x then 1 else -1, nil, nil, "boss", "rv_double")
					for _, e in res.hits do
						dead = dead or (e.mob == boss.id and e.dead == true)
					end
				end
			end
		end
		print(("[BOSS] %s: 피하지 않고 서서 쳐서 %.0f초(이중 베기 %d번) · 받은 피해 = 내 체력의 %.0f%%(체력 %d)"):format(def.name, t, casts, lost / hh.maxHp * 100, hh.maxHp))
		expect(dead, def.name .. ": 피하지 않아도 2분 안에 쓰러뜨린다")
		expect(t <= 60, ("%s: 쓰러뜨리는 데 %.0f초 — 1분을 넘지 않는다"):format(def.name, t))
		expect(lost <= hh.maxHp * 2, ("%s: 피하지 않고 받는 피해가 내 체력의 두 배를 넘지 않는다(%.0f%%)"):format(def.name, lost / hh.maxHp * 100))
	end
end
