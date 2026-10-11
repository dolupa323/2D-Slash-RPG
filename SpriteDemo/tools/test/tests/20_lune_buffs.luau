-- 「달의 계승자」 — 2~4차의 버프(shared/lune/sim/buffs.luau). 공방 js/lune/design/combat.js의 BUFFS.
--  사용자 2026-10-08: "2~4차 사출기, 설치기, 버프 다 옮겨야합니다."
--  걸기 · 다시 쓰기 · 시간이 다 되면 사라지는 것 · 세기(레벨의 배수) · 방에서의 주는 피해와 받는 피해. 서버를 거치는 것(패킷 · 파티원)은 13_lune_world.luau.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local FLOOR = CLASSES.skillRule.floor
local BUFF = COMBAT.buffs

local function near(a, b, tol, msg)
	expect(math.abs(a - b) <= tol * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

-- ---- 1) 자료: 설계의 버프 갈래 스킬마다 수치가 있다 ----
do
	local kinds = { buff = true, party = true, burst = true, guard = true }
	local seen = 0
	for class, c in CLASSES.classes do
		for _, t in c.tiers do
			for _, sk in t.skills do
				if kinds[sk.type] then
					seen += 1
					local def = BUFF[sk.id]
					expect(def ~= nil, "버프의 수치가 있다 " .. sk.id)
					if def then
						expect(def.who == class or def.who == "all", "그 직업의 버프(공용은 all) " .. sk.id)
						eq(def.job, t.job, "차수 " .. sk.id)
						eq(def.max, sk.max, "마스터 레벨 " .. sk.id)
						expect(def.dur > 0, "지속 시간 " .. sk.id)
						eq(def.dur, sk.dur, "지속 시간은 스킬 목록의 것과 같다 " .. sk.id)
						eq(def.cd, sk.cd or 0, "다시 쓰기는 스킬 목록의 것과 같다 " .. sk.id)
					end
				end
			end
		end
	end
	expect(seen >= 20, "버프가 스물이 넘는다 " .. seen)
	-- 극딜은 다시 쓰기 120초 · 갱신 버프는 60초에 다시 쓰기 없음(설계의 규칙)
	for id, def in BUFF do
		if def.type == "burst" then
			eq(def.cd, 120, "극딜 버프의 다시 쓰기 " .. id)
		elseif def.type == "buff" then
			eq(def.dur, 60, "갱신 버프의 지속 " .. id)
			eq(def.cd, 0, "갱신 버프는 다시 쓰기가 없다 " .. id)
		end
	end
end

-- 그 직업의 Lv.120 캐릭터(스킬은 직접 넣는다)
local function hero(class: string, skills)
	local h = Hero.new(1, class)
	h.level = 120
	Hero.grantJob(h)
	for id, lv in skills or {} do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y = 300, 176
	return h
end

-- ---- 2) 걸기 · 세기 · 다시 쓰기 · 사라지기 ----
do
	local h = hero("axion")
	eq(Buffs.cast(h, "ax_breath", 0), nil, "배우지 않은 버프는 걸리지 않는다")
	eq(Buffs.haste(h), 1, "버프가 없으면 공격 속도 그대로")
	h.skills.ax_breath = 1
	near(Buffs.cast(h, "ax_breath", 0) or 0, FLOOR, 1e-6, "레벨 1의 세기")
	expect(Buffs.has(h, "ax_breath"), "걸렸다")
	near(Buffs.haste(h), 1 + BUFF.ax_breath.fx.haste * FLOOR, 1e-6, "레벨 1: 공격 속도 +10%")
	h.skills.ax_breath = BUFF.ax_breath.max
	Buffs.cast(h, "ax_breath", 1)
	near(Buffs.haste(h), 1.25, 1e-6, "마스터: 공격 속도 +25%")
	-- 남의 직업의 버프 · 없는 것
	h.skills.rv_quick = 10
	eq(Buffs.cast(h, "rv_quick", 2), nil, "남의 직업의 버프")
	eq(Buffs.cast(h, "no_such", 2), nil, "없는 버프")
	eq(Buffs.is("ax_slam"), false, "기술은 버프가 아니다")
	-- 공용 버프는 누구나
	h.skills.c_hero = 10
	expect(Buffs.cast(h, "c_hero", 2) ~= nil, "공용 버프(달의 용사)는 누구나 건다")
	-- 시간이 다 되면 사라진다(갱신 버프 60초)
	local ended = {}
	for _ = 1, 59 * 20 do
		for _, id in Buffs.tick(h, 1 / 20) do
			table.insert(ended, id)
		end
	end
	eq(#ended, 0, "59초까지는 그대로")
	for _ = 1, 3 * 20 do
		for _, id in Buffs.tick(h, 1 / 20) do
			table.insert(ended, id)
		end
	end
	eq(#ended, 2, "60초가 지나면 둘 다 사라진다")
	eq(Buffs.haste(h), 1, "사라지면 공격 속도도 돌아온다")
	-- 다시 쓰기(극딜 120초)
	h.skills.ax_fullmoon = 20
	expect(Buffs.cast(h, "ax_fullmoon", 100) ~= nil, "만월을 건다")
	eq(Buffs.cast(h, "ax_fullmoon", 150), nil, "다시 쓰기 중에는 못 건다")
	near(Buffs.view(h, 150).cds.ax_fullmoon, 70, 1e-6, "다시 쓰기까지 남은 시간")
	expect(Buffs.cast(h, "ax_fullmoon", 221) ~= nil, "120초 뒤에 다시 건다")
	expect(Buffs.full(h), "만월: 강타를 끝까지 모은 것으로 친다")
	-- 주는 피해: 곱한다
	h.skills.ax_roar = 10
	Buffs.cast(h, "ax_roar", 221)
	near(Buffs.dmg(h), 1.3 * 1.1, 1e-6, "만월 x 달의 함성")
	-- 보내는 것: 건 차례로
	local view = Buffs.view(h, 221)
	eq(#view.list, 2, "걸린 버프 둘")
	eq(view.list[1].id, "ax_fullmoon", "먼저 건 것이 앞")
	eq(view.list[2].id, "ax_roar", "나중에 건 것이 뒤")
	-- 다시 걸면 맨 뒤로 간다(시간도 새로)
	Buffs.tick(h, 10)
	Buffs.cast(h, "ax_fullmoon", 400)
	view = Buffs.view(h, 400)
	eq(view.list[2].id, "ax_fullmoon", "다시 건 것은 맨 뒤로")
	near(view.list[2].t, BUFF.ax_fullmoon.dur, 1e-6, "시간도 새로")
	-- 퀵슬롯에 놓을 수 있다
	expect(Hero.canSlot(h, "ax_roar"), "배운 버프는 퀵슬롯에 놓는다")
	eq(Hero.canSlot(h, "ax_brace"), false, "배우지 않은 버프는 못 놓는다")
end

-- ---- 3) 받는 피해: 생존기 · 받는 피해 − · 걸어 둔 자리 곁에서만 · 쓰러질 피해를 버틴다 ----
do
	local m = hero("mooni", { mn_bless = 10, mn_sanct = 20 })
	Buffs.cast(m, "mn_bless", 0)
	near(Buffs.cut(m), 1 - BUFF.mn_bless.fx.cut, 1e-6, "달의 축복: 받는 피해 -15%")
	Buffs.cast(m, "mn_sanct", 0)
	near(Buffs.dmg(m), 1.3, 1e-6, "달의 성역 안: 주는 피해 +30%")
	near(Buffs.cut(m), (1 - 0.15) * (1 - 0.2), 1e-6, "달의 성역 안: 받는 피해가 더 준다")
	m.x += 200
	eq(Buffs.dmg(m), 1, "성역 밖으로 나가면 듣지 않는다")
	near(Buffs.cut(m), 1 - 0.15, 1e-6, "성역 밖: 달의 축복만")
	local a = hero("axion", { ax_brace = 5 })
	eq(Buffs.guard(a), false, "생존기를 쓰기 전")
	Buffs.cast(a, "ax_brace", 0)
	expect(Buffs.guard(a), "버티기: 피해를 받지 않는다")
	Buffs.tick(a, 3.1)
	eq(Buffs.guard(a), false, "3초 뒤에 풀린다")
	local r = hero("reaper", { rp_ward = 10 })
	eq(Buffs.ward(r), false, "가호가 없으면 못 버틴다")
	Buffs.cast(r, "rp_ward", 0)
	expect(Buffs.ward(r), "죽음의 가호: 한 번 버틴다")
	eq(Buffs.ward(r), false, "한 번뿐이다")
end

-- ---- 4) 방에서: 주는 피해가 그만큼 는다 · 생존기 동안 맞지 않는다 · 쓰러질 피해를 버틴다 ----
do
	local function total(buffed: boolean)
		local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(11))
		local h = hero("axion", { ax_fullmoon = 20 })
		for i, mob in room.mobs do
			mob.state, mob.t = "idle", 0
			mob.a, mob.b = 0, 4000
			mob.y = h.y
			mob.x = 2000 + i * 30
			mob.hp, mob.maxHp = 1e12, 1e12
		end
		local foe = room.mobs[1]
		if buffed then
			Buffs.cast(h, "ax_fullmoon", 0)
		end
		local hit = COMBAT.skills.ax_combo.hits[1]
		local sum = 0
		for _ = 1, 200 do
			foe.x, foe.state = h.x + 20, "idle"
			for _, e in room:skillHit(h, hit, h.x, h.y, 1, 1, nil, "boss", "ax_combo").hits do
				sum += e.dmg
			end
		end
		return sum
	end
	near(total(true) / total(false), 1.3, 0.02, "만월 동안 주는 피해 +30%")

	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(5))
	local mob = room.mobs[1]
	local h = hero("axion", { ax_brace = 5 })
	local events = {}
	Buffs.cast(h, "ax_brace", 0)
	h.invuln = 0
	room:hurtHero(events, h, mob, 1)
	eq(#events, 0, "버티기 동안에는 맞지 않는다")
	eq(h.hp, h.maxHp, "체력 그대로")
	local r = hero("reaper", { rp_ward = 10 })
	Buffs.cast(r, "rp_ward", 0)
	r.hp, r.invuln = 1, 0
	events = {}
	room:hurtHero(events, r, mob, 1000)
	expect(r.alive, "죽음의 가호: 쓰러질 피해를 버틴다")
	local ward = false
	for _, e in events do
		ward = ward or e.type == "ward"
	end
	expect(ward, "버텼다고 알린다")
	eq(Buffs.has(r, "rp_ward"), false, "가호는 사라진다")
	r.invuln = 0
	room:hurtHero({}, r, mob, 1000)
	eq(r.alive, false, "두 번째는 쓰러진다")
end

-- ---- 4-2) 거신: 도끼질이 더 멀리 닿는다 · 그림자 분신: 조금 뒤에 따라 벤다 ----
do
	local function arena(seed: number, h)
		local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(seed))
		for i, mob in room.mobs do
			mob.state, mob.t = "idle", 0
			mob.a, mob.b = 0, 4000
			mob.y = h.y
			mob.x = 2000 + i * 30
			mob.hp, mob.maxHp = 1e12, 1e12
		end
		return room, room.mobs[1]
	end
	-- 거신
	near(BUFF.ax_titan.fx.big, 0.5, 1e-6, "거신: 닿는 거리 +50%(마스터)")
	local a = hero("axion", { ax_titan = BUFF.ax_titan.max })
	local room, foe = arena(21, a)
	local hit = COMBAT.skills.ax_combo.hits[1]
	local far = hit.box[2] * 1.3 + 9 -- 보통 때는 닿지 않고(몸의 반 폭을 더해도), 거신이면 닿는 자리
	foe.x = a.x + far
	eq(#room:skillHit(a, hit, a.x, a.y, 1, 1, nil, "boss", "ax_combo").hits, 0, "보통 때는 닿지 않는 거리")
	eq(Buffs.big(a), 1, "거신을 쓰기 전")
	expect(Buffs.cast(a, "ax_titan", 0) ~= nil, "거신을 건다")
	near(Buffs.big(a), 1.5, 1e-6, "거신: 닿는 거리 x1.5")
	foe.state = "idle"
	eq(#room:skillHit(a, hit, a.x, a.y, 1, 1, nil, "boss", "ax_combo").hits, 1, "거신 동안에는 그 거리도 닿는다")
	a.skills.ax_titan = 1
	Buffs.cast(a, "ax_titan", 500)
	near(Buffs.big(a), 1 + 0.5 * FLOOR, 1e-6, "거신 레벨 1: 닿는 거리 +20%")
	Buffs.tick(a, BUFF.ax_titan.dur + 0.1)
	eq(Buffs.big(a), 1, "끝나면 그대로")

	-- 그림자 분신
	local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
	local fx = BUFF.rv_clone.fx
	near(fx.echo, 0.4, 1e-6, "그림자 분신: 그 타 피해의 40%(마스터)")
	local r = hero("riven", { rv_clone = BUFF.rv_clone.max, rv_mark = 10 })
	r.kit.on = false
	local room2, foe2 = arena(22, r)
	local cut = COMBAT.skills.rv_double.hits[1]
	local function slash()
		foe2.x, foe2.state = r.x + 14, "idle"
		local sum = 0
		for _, e in room2:skillHit(r, cut, r.x, r.y, 1, 1, nil, "boss", "rv_double").hits do
			if not e.proc then
				sum += e.dmg
			end
		end
		return sum
	end
	-- 분신의 타를 모은다: 방을 사람 없이 굴려(졸개가 움직이지 않게 멀리 둔 채) "kit" 일을 받는다
	local function echoes(time: number)
		local sum, n, marked = 0, 0, false
		for _ = 1, math.ceil(time / 0.05) do
			for _, e in room2:step({}, 0.05) do
				if e.type == "kit" then
					for _, x in e.result.hits do
						if x.proc == "clone" then
							sum += x.dmg
							n += 1
							marked = marked or x.mark ~= nil
						end
					end
				end
			end
			foe2.x, foe2.state = r.x + 14, "idle"
		end
		return sum, n, marked
	end
	local own = slash()
	expect(own > 0, "베기가 맞았다")
	local s0, n0 = echoes(1)
	eq(n0, 0, "분신이 없으면 따라 베지 않는다")
	eq(s0, 0, "피해도 없다")
	expect(Buffs.cast(r, "rv_clone", 0) ~= nil, "그림자 분신을 건다")
	own = slash()
	local s1, n1, marked = echoes(fx.after - 0.06)
	eq(n1, 0, "분신은 반 박자 늦게 벤다(아직 아니다)")
	s1, n1, marked = echoes(0.3)
	eq(n1, 1, "분신이 한 번 따라 벤다")
	near(s1, own * fx.echo, 0.01, "분신의 피해 = 그 타 피해의 40%")
	expect(marked, "분신의 베기도 표식을 남긴다")
	-- 레벨 1이면 그 40%
	r.skills.rv_clone = 1
	Buffs.cast(r, "rv_clone", 100)
	own = slash()
	s1, n1 = echoes(0.5)
	eq(n1, 1, "레벨 1에서도 따라 벤다")
	near(s1, own * fx.echo * FLOOR, 0.02, "레벨 1: 그 타 피해의 16%")
	-- 표식을 못 남기는 리븐(표식을 안 배웠다)은 분신도 못 남긴다
	r.skills.rv_mark = 0
	foe2.marks = nil
	own = slash()
	s1, n1, marked = echoes(0.5)
	eq(n1, 1, "따라 벤다")
	eq(marked, false, "표식을 배우지 않았으면 분신도 남기지 않는다")
	expect(Kit.level(r, "core") == 0, "표식 0")
end

-- ---- 5) 설치 · 소환(COMBAT.placed — sim/room.luau의 place · stepPlaced) ----
do
	local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
	local PLACED = COMBAT.placed
	-- 자료: 설계의 설치 · 소환 갈래 스킬마다 있다
	local n = 0
	for class, c in CLASSES.classes do
		for _, t in c.tiers do
			for _, sk in t.skills do
				if sk.type == "install" or sk.type == "summon" then
					n += 1
					local def = PLACED[sk.id]
					expect(def ~= nil and def.who == class and def.job == t.job and def.life == sk.dur, "설치 · 소환의 수치 " .. sk.id)
				end
			end
		end
	end
	expect(n >= 6, "설치 · 소환이 여섯이 넘는다 " .. n)

	-- 방 하나: 졸개를 멀리 치워 두고 하나만 곁에 세운다
	local function arena(class, skills)
		local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(3))
		local h = hero(class, skills)
		for i, mob in room.mobs do
			mob.state, mob.t = "idle", 0
			mob.a, mob.b = 0, 4000
			mob.y = h.y
			mob.x = 2000 + i * 30
			mob.hp, mob.maxHp = 1e12, 1e12
		end
		return room, h, room.mobs[1], room.mobs[2]
	end
	-- 한동안 돌리며 놓인 것이 준 타를 센다(졸개가 덤비지 않게 그 사람은 맞지 않게 해 둔다)
	local function run(room, h, seconds, each)
		local hits, sum = 0, 0
		for _ = 1, math.floor(seconds * 20 + 0.5) do
			h.invuln = 5
			for _, e in room:step({ h }, 1 / 20) do
				if e.type == "kit" then
					for _, hit in e.result.hits do
						hits += 1
						sum += hit.dmg
					end
				end
			end
			if each then
				each()
			end
		end
		return hits, sum
	end

	-- 화로(설치): 곁의 적을 0.5초마다 태우고, 곁에 있으면 열기가 오른다. 10초 뒤에 사라진다
	do
		local room, h, a = arena("salamander", { sl_furnace = 10, sl_heat = 10 })
		local out = { hits = {}, kills = {} }
		local p = room:place(h, "sl_furnace", 1, out)
		expect(p ~= nil and math.abs(p.x - (h.x + PLACED.sl_furnace.ahead)) < 1, "화로는 내 앞에 놓인다")
		a.x = p.x + 10
		local hits, sum = run(room, h, 2, function()
			a.x, a.state = p.x + 10, "idle"
		end)
		eq(hits, 4, "2초에 네 번 태운다(0.5초마다)")
		-- 초당 피해의 30%(마스터): 2초면 전투력 x 초당 피해 x 0.3 x 2(쓰임의 보정 · 숫자의 배율은 그대로 붙는다)
		local want = Hero.powerRaw(h) * N.data.POWER.dps * PLACED.sl_furnace.rate * 2 * COMBAT.rules.dmgScale * (1 + COMBAT.rules.targetBonus / 100)
		near(sum, want, 0.08, "화로의 피해: 초당 피해의 30%")
		expect(h.kit.heat > 5, "화로 곁에서는 열기가 오른다 " .. h.kit.heat)
		run(room, h, 8.2)
		eq(#room.placed, 0, "10초 뒤에 사라진다")
	end
	-- 저승문(설치): 끌어당기고 태우고, 곁에서 쓰러진 적은 영혼 2
	do
		local room, h, a, b = arena("reaper", { rp_gate = 15, rp_soul = 10 })
		local p = room:place(h, "rp_gate", 1, { hits = {}, kills = {} })
		a.x = p.x + 100
		local x0 = a.x
		run(room, h, 1)
		expect(a.x < x0 - 20, ("저승문이 끌어당긴다 %d → %d"):format(x0, a.x))
		-- 문 곁에서 쓰러뜨리면 영혼 2
		b.x, b.hp, b.maxHp = p.x + 5, 1, 1
		local souls = h.kit.souls
		local out = { hits = {}, kills = {} }
		room:strike(h, b, 10, h.x, nil, out)
		eq(h.kit.souls, souls + PLACED.rp_gate.souls, "문 곁에서 쓰러진 적은 영혼 2")
	end
	-- 망령(소환): 따라다니며 1.6초마다 가까운 적을 친다. 다시 부르면 하나만 남는다
	do
		local room, h, a = arena("reaper", { rp_ghost = 15, rp_soul = 10 })
		room:place(h, "rp_ghost", 1, { hits = {}, kills = {} })
		room:place(h, "rp_ghost", 1, { hits = {}, kills = {} })
		eq(#room.placed, 1, "같은 소환은 하나만 둔다")
		a.x = h.x + 30
		local hits = run(room, h, 3.4, function()
			a.x, a.state = h.x + 30, "idle"
		end)
		eq(hits, 2, "3.4초에 두 번 친다(1.6초마다)")
		h.x += 300
		run(room, h, 0.1)
		near(room.placed[1].x, h.x - h.dir * PLACED.rp_ghost.back, 0.01, "망령은 따라다닌다")
		-- 주인이 방에 없으면 사라진다
		room:step({}, 1 / 20)
		eq(#room.placed, 0, "주인이 방을 떠나면 사라진다")
	end
	-- 수정 심기(설치): 달 수정이 선다
	do
		local room, h = arena("mooni", { mn_plant = 10, mn_reson = 10 })
		local out = { hits = {}, kills = {} }
		eq(room:place(h, "mn_plant", 1, out), nil, "수정 심기는 놓인 것 대신 달 수정을 세운다")
		expect(out.crystals ~= nil and #out.crystals == 1 and #room.crystals == 1, "달 수정 하나")
		near(room.crystals[1].x, h.x + PLACED.mn_plant.ahead, 0.01, "발 앞에 선다")
	end
	-- 연막탄(설치 — 버프): 안에 있으면 졸개가 놓치고, 주는 피해가 는다
	do
		local room, h, a = arena("riven", { rv_smoke = 10 })
		expect(Buffs.is("rv_smoke") and not Buffs.instant("rv_smoke"), "연막탄은 쓰는 동작이 있는 버프다")
		Buffs.give(h, "rv_smoke", 1, h.x, h.y)
		expect(Buffs.stealth(h), "연막 안: 적이 나를 놓친다")
		near(Buffs.dmg(h), 1.2, 1e-6, "연막 안: 주는 피해 +20%")
		a.x = h.x + 20
		eq(room:findTarget(a, { [h.id] = h }), nil, "졸개가 연막 안의 사람을 못 찾는다")
		h.x += 100
		eq(Buffs.stealth(h), false, "연막 밖으로 나오면 보인다")
		expect(room:findTarget(a, { [h.id] = h }) ~= nil or math.abs(a.x - h.x) > a.def.see, "밖에서는 다시 찾는다")
	end
	-- 퀵슬롯에 놓을 수 있다
	expect(Hero.canSlot(hero("reaper", { rp_ghost = 1 }), "rp_ghost"), "배운 소환은 퀵슬롯에 놓는다")
	eq(Hero.canSlot(hero("reaper"), "rp_ghost"), false, "배우지 않은 소환은 못 놓는다")
end
