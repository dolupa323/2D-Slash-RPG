-- 「달의 계승자」 — 2~4차의 패시브 37개(shared/lune/sim/passives.luau). 공방 js/lune/design/combat.js의 PASSIVE.
--  사용자 2026-10-08: "작업 이어서 하세요"(남은 2~4차). 패시브마다 그 효과가 실제로 듣는지 본다 — 찍히는데 효과가 없는 것이 없게.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local Passives = req("ReplicatedStorage/shared/lune/sim/passives")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local PASS = COMBAT.passive
local RULES = COMBAT.rules
local FLOOR = CLASSES.skillRule.floor
local SUB = 1 / 60
local X, Y = 2000, 176

local function near(a, b, tol, msg)
	expect(math.abs(a - b) <= tol * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

local function hero(class: string, skills)
	local h = Hero.new(1, class)
	h.level = 120
	h.skills = {}
	for id, lv in skills or {} do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y, h.dir = X, Y, 1
	return h
end
local function arena(seed: number, h)
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(seed))
	for i, mob in room.mobs do
		mob.state, mob.t = "idle", 0
		mob.a, mob.b = 0, 9000
		mob.y = h.y
		mob.x = 6000 + i * 30
		mob.hp, mob.maxHp = 1e12, 1e12
	end
	return room, room.mobs[1], room.mobs[2]
end
-- 1차 기술의 한 타를 여러 번 쳐서 그 적이 받은 피해의 합(제 타만 — 따라붙는 것은 뺀다)
local function swing(room, h, foe, id: string, n: number?, opts): number
	local hit = COMBAT.skills[id].hits[1]
	local sum = 0
	for _ = 1, n or 200 do
		foe.x, foe.state = h.x + 20, "idle"
		for _, e in room:skillHit(h, hit, h.x, h.y, 1, 1, nil, COMBAT.skills[id].type, id, opts).hits do
			if e.mob == foe.id and not e.proc then
				sum += e.dmg
			end
		end
	end
	return sum
end

-- ---- 1) 자료: 2~4차의 패시브마다 수치가 있고(사출기 강화는 KITUP), 게임에 들어와 있다 ----
do
	local up = {}
	for _, k in COMBAT.kitUp do
		for _, def in k do
			up[def.id] = true
		end
	end
	local seen = 0
	for class, c in CLASSES.classes do
		for _, t in c.tiers do
			for _, sk in t.skills do
				if t.job >= 2 and sk.type == "passive" and not up[sk.id] then
					seen += 1
					local def = PASS[sk.id]
					expect(def ~= nil, "패시브의 수치가 있다 " .. sk.id)
					if def then
						eq(def.who, class, "직업 " .. sk.id)
						eq(def.job, t.job, "차수 " .. sk.id)
						eq(def.max, sk.max, "마스터 레벨 " .. sk.id)
						expect(next(def.fx) ~= nil, "효과가 있다 " .. sk.id)
						expect(Hero.ready(sk.id), "게임에 들어와 있다(포인트가 찍힌다) " .. sk.id)
						local texts = COMBAT.kitEffects[sk.id]
						expect(texts ~= nil and #texts == sk.max and #texts[1] > 0, "레벨마다의 효과 글이 있다 " .. sk.id)
					end
				end
			end
		end
	end
	eq(seen, 37, "2~4차의 패시브 37개")
	-- 남은 것은 둘뿐이다
	local left = {}
	for class, c in CLASSES.classes do
		for _, t in c.tiers do
			for _, sk in t.skills do
				if not Hero.ready(sk.id) then
					left[sk.id] = true
				end
			end
		end
	end
	local n = 0
	for _ in left do
		n += 1
	end
	eq(n, 1, "아직 준비 중인 스킬은 용사의 의지 하나(상태 이상이 생길 때를 위해 미리 넣어 둔 것)")
	expect(left.c_will, "용사의 의지")
	-- 세기: 레벨 1에서 40% → 마스터 100% · 배우지 않았으면 0 · 남의 직업의 것은 0
	local h = hero("axion", { ax_mastery = 1 })
	near(Passives.scale(h, "ax_mastery"), FLOOR, 1e-6, "레벨 1의 세기")
	h.skills.ax_mastery = 10
	near(Passives.scale(h, "ax_mastery"), 1, 1e-6, "마스터의 세기")
	eq(Passives.scale(h, "ax_expert"), 0, "배우지 않았으면 0")
	h.skills.rv_mastery = 10
	eq(Passives.scale(h, "rv_mastery"), 0, "남의 직업의 패시브는 듣지 않는다")
	eq(Passives.atk(hero("axion")), 1, "패시브가 없으면 그대로")
end

-- ---- 2) 공격력 · 최종 피해 · 옛 사냥기: 주는 피해가 그만큼 는다 ----
do
	for class, ids in { axion = { "ax_mastery", "ax_expert", "ax_crush" }, riven = { "rv_mastery", "rv_expert", "rv_intent" }, reaper = { "rp_mastery", "rp_expert", "rp_touch" }, mooni = { "mn_mastery", "mn_expert", "mn_astral" }, salamander = { "sl_mastery", "sl_expert", "sl_reign" } } do
		local mastery, expert, final = PASS[ids[1]].fx, PASS[ids[2]].fx, PASS[ids[3]].fx
		-- 숙련 · 달인 = 최종 피해 +(예전의 숙련도 — 사용자 2026-10-08) · 공격력 +
		near(Passives.atk(hero(class, { [ids[1]] = 10 })), (1 + mastery.atk) * (1 + mastery.final), 1e-6, "숙련: 최종 피해 + · 공격력 + " .. class)
		near(Passives.atk(hero(class, { [ids[1]] = 1 })), (1 + mastery.atk * FLOOR) * (1 + mastery.final * FLOOR), 1e-6, "숙련 레벨 1: 그 40% " .. class)
		near(Passives.atk(hero(class, { [ids[1]] = 10, [ids[2]] = 10, [ids[3]] = 10 })), (1 + mastery.atk + expert.atk) * (1 + mastery.final + expert.final + final.final), 1e-6, "숙련 + 달인 + 4차의 최종 피해 " .. class)
		expect(expert.critMul > 0, "달인: 치명타 피해 + " .. class)
		-- 옛 사냥기의 피해 +
		local h = hero(class, { [ids[3]] = 10 })
		local foe = { x = h.x + 10, hp = 50, maxHp = 100 }
		for _, sid in final.skills do
			expect(COMBAT.cast[sid] ~= nil, "피해를 올려 주는 스킬이 게임에 있다 " .. sid)
			near(Passives.vs(h, foe, { skill = sid, now = 0 }), 1 + final.boost, 1e-6, "옛 사냥기의 피해 + " .. sid)
		end
		eq(Passives.vs(h, foe, { skill = "nope", now = 0 }), 1, "다른 스킬에는 붙지 않는다 " .. class)
	end
	-- 방에서: 숙련을 마스터하면 1차 기술의 피해가 그만큼 는다
	local plain = hero("mooni")
	local skilled = hero("mooni", { mn_expert = 10 })
	local room, foe = arena(51, plain)
	near(swing(room, skilled, foe, "mn_thrust") / swing(room, plain, foe, "mn_thrust"), (1 + PASS.mn_expert.fx.atk) * (1 + PASS.mn_expert.fx.final), 0.02, "대검 달인: 달빛 찌르기의 피해 x1.04 x1.04")
	-- 2~4차의 스킬에도 듣는다(옛 사냥기 +30% x 최종 피해 +10%)
	local function cast(skills): number
		local h = hero("axion", skills)
		local dry, _ = Caster.makeDry(X + 14, Y)
		local c = Caster.new(dry)
		c.dry = true
		for _ = 1, 10 do
			h.x, h.dir = X, 1
			c:dryCast(h, "ax_crescent", 0, function()
				dry.time += SUB
				c:sub(SUB)
			end)
		end
		for _ = 1, 120 do
			dry.time += SUB
			c:sub(SUB)
		end
		local sum = 0
		for _, e in c:actor(h).out.hits do
			sum += e.dmg
		end
		return sum
	end
	local crush = PASS.ax_crush.fx
	near(cast({ ax_crescent = 20, ax_crush = 10 }) / cast({ ax_crescent = 20 }), (1 + crush.final) * (1 + crush.boost), 0.04, "분쇄: 초승달 가르기의 피해 x1.1 x1.3")
end

-- ---- 3) 그 적에게만 붙는 것: 넘어진 적 · 체력이 많은/적은 적 · 먼 거리 · 모은 단계 · 이어 맞히기 ----
do
	-- 도끼 숙련: 넘어졌거나 묶인 적에게 +20%
	local a = hero("axion", { ax_mastery = 10 })
	local m = { x = a.x + 10, hp = 50, maxHp = 100, stun = 0, bind = 0 }
	eq(Passives.vs(a, m, { now = 0 }), 1, "멀쩡한 적에게는 붙지 않는다")
	m.stun = 1
	near(Passives.vs(a, m, { now = 0 }), 1 + PASS.ax_mastery.fx.stunned, 1e-6, "넘어진 적에게 +20%")
	m.stun, m.bind = 0, 5
	near(Passives.vs(a, m, { now = 0 }), 1 + PASS.ax_mastery.fx.stunned, 1e-6, "묶인 적에게도")
	-- 무게 싣기: 체력이 70% 넘게 남은 적에게 +15% · 모은 단계마다 +5%
	local w = hero("axion", { ax_weight = 10 })
	local fx = PASS.ax_weight.fx
	local full = { x = w.x + 10, hp = 100, maxHp = 100 }
	near(Passives.vs(w, full, { now = 0 }), 1 + fx.healthy, 1e-6, "체력이 많이 남은 적에게 +15%")
	full.hp = 60
	eq(Passives.vs(w, full, { now = 0 }), 1, "70% 아래면 붙지 않는다")
	near(Passives.vs(w, full, { now = 0, charge = 2 }), 1 + fx.perCharge * 2, 1e-6, "모은 단계마다 +5%")
	-- 죽음의 손길: 체력이 30% 아래인 적에게 +20%
	local r = hero("reaper", { rp_touch = 10 })
	local low = { x = r.x + 10, hp = 20, maxHp = 100 }
	near(Passives.vs(r, low, { now = 0 }), 1 + PASS.rp_touch.fx.low, 1e-6, "체력이 30% 아래인 적에게 +20%")
	low.hp = 40
	eq(Passives.vs(r, low, { now = 0 }), 1, "30% 넘으면 붙지 않는다")
	-- 대검 숙련: 40도트보다 멀리서 맞히면 +15%
	local mo = hero("mooni", { mn_mastery = 10 })
	local farM = { x = mo.x + 60, hp = 50, maxHp = 100 }
	near(Passives.vs(mo, farM, { now = 0 }), 1 + PASS.mn_mastery.fx.far, 1e-6, "대검 끝에 맞으면 +15%")
	farM.x = mo.x + 20
	eq(Passives.vs(mo, farM, { now = 0 }), 1, "가까이에서는 붙지 않는다")
	-- 피의 계약: 잃은 체력만큼 공격력 +(가장 많이 20%)
	local p = hero("reaper", { rp_pact = 10 })
	eq(Passives.atk(p), 1, "체력이 가득이면 그대로")
	p.hp = p.maxHp / 2
	near(Passives.atk(p), 1 + PASS.rp_pact.fx.pact * 0.5, 1e-6, "체력이 반이면 +10%")
	p.hp = 1
	near(Passives.atk(p), 1 + PASS.rp_pact.fx.pact, 0.001, "거의 없으면 +20%")
	-- 주먹 숙련: 2초 안에 이어 맞힐 때마다 +4%(세 번까지) · 몰아붙이기: 같은 적을 이어 때릴 때마다 +3%(다섯 번까지)
	local s = hero("salamander", { sl_mastery = 10, sl_press = 10 })
	local sf, pf = PASS.sl_mastery.fx, PASS.sl_press.fx
	local one, two = { x = s.x + 10, hp = 50, maxHp = 100 }, { x = s.x + 12, hp = 50, maxHp = 100 }
	eq(Passives.vs(s, one, { now = 0 }), 1, "처음에는 겹친 것이 없다")
	Passives.onHit(s, one, 0)
	near(Passives.vs(s, one, { now = 0.1 }), (1 + sf.streak) * (1 + pf.press), 1e-6, "한 번 맞힌 뒤")
	for i = 1, 6 do
		Passives.onHit(s, one, i * 0.2)
	end
	near(Passives.vs(s, one, { now = 1.3 }), (1 + sf.streak * sf.streakMax) * (1 + pf.press * pf.pressMax), 1e-6, "끝까지 겹쳤다(세 번 · 다섯 번)")
	near(Passives.vs(s, two, { now = 1.3 }), 1 + sf.streak * sf.streakMax, 1e-6, "다른 적에게는 이어 맞힌 것만")
	Passives.onHit(s, two, 1.4)
	near(Passives.vs(s, one, { now = 1.5 }), 1 + sf.streak * sf.streakMax, 1e-6, "다른 적을 때리면 그 적의 것은 풀린다")
	eq(Passives.vs(s, one, { now = 9 }), 1, "쉬면 모두 풀린다")
	-- 방에서: 주먹을 이어 맞히면 피해가 오른다
	local fresh = hero("salamander", { sl_mastery = 10 })
	local room, foe = arena(52, fresh)
	local hit = COMBAT.skills.sl_punch.hits[1]
	local first, later = 0, 0
	for round = 1, 60 do
		fresh.pass.streak, fresh.pass.streakAt = 0, -1e9
		for i = 1, 5 do
			foe.x, foe.state = fresh.x + 20, "idle"
			room.time += 0.3
			local d = room:skillHit(fresh, hit, fresh.x, fresh.y, 1, 1, nil, "boss", "sl_punch").hits[1].dmg
			if i == 1 then
				first += d
			elseif i == 5 then
				later += d
			end
		end
	end
	near(later / first, (1 + sf.atk + 0) / (1 + sf.atk) * (1 + sf.streak * 3), 0.03, "다섯 번째 주먹은 첫 주먹보다 12% 세다")
end

-- ---- 4) 받는 피해: 굳센 자세 · 달궈진 몸 · 흘리기 · 재점화 ----
do
	local a = hero("axion", { ax_stance = 10 })
	local fx = PASS.ax_stance.fx
	near(Passives.cut(a, false), 1 - fx.cut, 1e-6, "굳센 자세: 받는 피해 -8%")
	near(Passives.cut(a, true), 1 - fx.cutCast, 1e-6, "기술을 쓰는 동안에는 -20%")
	local s = hero("salamander", { sl_tough = 10, sl_heat = 10 })
	eq(Passives.cut(s, false), 1, "달아오르지 않았으면 그대로")
	s.kit.heat = 80
	near(Passives.cut(s, false), 1 - PASS.sl_tough.fx.cutHot, 1e-6, "달궈진 몸: 달아오름 동안 -20%")
	-- 방에서: 기술을 쓰는 동안 덜 아프다
	local room, mob = arena(53, a)
	mob.lv = 130 -- 센 졸개로 잰다(약한 졸개의 한 방은 숫자가 작아 반올림에 묻힌다)
	local function taken(acting: boolean): number
		local sum = 0
		for _ = 1, 50 do
			a.hp, a.invuln = a.maxHp, 0
			a.actUntil = if acting then room.time + 5 else nil
			local events = {}
			room:hurtHero(events, a, mob, 1)
			sum += events[1].dmg
		end
		return sum
	end
	local base = taken(false)
	near(taken(true) / base, (1 - fx.cutCast) / (1 - fx.cut), 0.02, "기술을 쓰는 동안에는 더 줄어든다")
	near(base / (function()
		local plain = hero("axion")
		local sum = 0
		for _ = 1, 50 do
			plain.hp, plain.invuln = plain.maxHp, 0
			local events = {}
			room:hurtHero(events, plain, mob, 1)
			sum += events[1].dmg
		end
		return sum
	end)(), 1 - fx.cut, 0.02, "굳센 자세가 없을 때보다 8% 덜 아프다")
	-- 흘리기: 회피 +10%p · 피하면 다음 베기가 반드시 치명타
	local r = hero("riven", { rv_feint = 10, rv_mark = 10 })
	near(Passives.dodge(r), PASS.rv_feint.fx.dodge / 100, 1e-6, "흘리기: 회피 +10%p")
	local _, _, sure = Passives.crit(r)
	eq(sure, false, "피하기 전")
	Passives.dodged(r)
	_, _, sure = Passives.crit(r)
	expect(sure, "피하면 다음 베기가 반드시 치명타")
	local room2, foe2 = arena(54, r)
	foe2.x = r.x + 14
	local out = room2:skillHit(r, COMBAT.skills.rv_double.hits[1], r.x, r.y, 1, 1, nil, "boss", "rv_double")
	expect(out.hits[1].crit, "표식이 없어도 치명타가 난다")
	_, _, sure = Passives.crit(r)
	eq(sure, false, "한 번 쓰면 사라진다")
	local dodges = 0
	for _ = 1, 4000 do
		r.hp, r.invuln = r.maxHp, 0
		local events = {}
		room2:hurtHero(events, r, foe2, 1)
		if events[1] and events[1].type == "dodge" then
			dodges += 1
		end
	end
	near(dodges / 4000, 0.1, 0.2, "열 번에 한 번쯤 피한다")
	-- 재점화: 쓰러질 피해를 받으면 열기를 모두 태워 최대 체력의 30%로 버틴다(300초에 한 번)
	local k = hero("salamander", { sl_rekindle = 10, sl_heat = 10 })
	local room3, mob3 = arena(55, k)
	k.kit.heat, k.hp, k.invuln = 70, 1, 0
	local events = {}
	room3:hurtHero(events, k, mob3, 1000)
	expect(k.alive, "재점화: 쓰러질 피해를 버틴다")
	near(k.hp, math.floor(k.maxHp * PASS.sl_rekindle.fx.rekindle + 0.5), 1e-6, "최대 체력의 30%로")
	eq(k.kit.heat, 0, "열기를 모두 태웠다")
	k.hp, k.invuln = 1, 0
	room3:hurtHero({}, k, mob3, 1000)
	eq(k.alive, false, "300초 안에는 다시 버티지 못한다")
	local again = hero("salamander", { sl_rekindle = 10 })
	again.hp, again.invuln = 1, 0
	room3.time += 400
	room3:hurtHero({}, again, mob3, 1000)
	expect(again.alive, "다른 사람은 제 것으로 버틴다")
end

-- ---- 5) 리븐: 표식 치명타(확률 · 피해) · 깊은 표식(셋까지) · 스미는 독 · 쌍영 ----
do
	-- 치명타(사용자 2026-10-08: "치명타 확률과 치명타 터지는건 만들겁니다"): 모든 직업의 기술 타가 기본 5%로, 1.5배
	local core = COMBAT.kit.riven.core
	local BASE, MUL = 5, 1.5
	eq(COMBAT.rules.critChance, 0, "이 파일은 치명타를 꺼 두고 잰다(여기서만 켠다)")
	COMBAT.rules.critChance = BASE
	eq(COMBAT.rules.critMul, MUL, "치명타의 피해 = 1.5배")
	local chance, mul, sure = Passives.crit(hero("axion"), false)
	eq(chance, BASE, "기본 치명타 확률 5%")
	eq(mul, MUL, "기본 치명타 피해 1.5배")
	eq(sure, false, "반드시 치명타는 흘리기뿐")
	chance, mul = Passives.crit(hero("axion", { ax_expert = 10 }), false)
	near(mul, MUL + PASS.ax_expert.fx.critMul, 1e-6, "도끼 달인: 치명타 피해 +20%p")
	chance = Passives.crit(hero("riven", { rv_mastery = 10 }), false)
	near(chance, BASE + PASS.rv_mastery.fx.crit, 1e-6, "창 숙련: 치명타 확률 +10%p(표식이 없어도)")
	chance, mul = Passives.crit(hero("riven", { rv_mark = 10, rv_back = 10 }), true)
	near(chance, BASE + core.crit, 1e-6, "표식이 있는 적에게 치명타 확률 +30%p")
	near(mul, MUL + PASS.rv_back.fx.markCritMul, 1e-6, "급소: 표식이 있는 적에게 치명타 피해 +30%p")
	chance, mul = Passives.crit(hero("riven", { rv_mark = 10, rv_back = 10 }), false)
	eq(chance, BASE, "표식이 없으면 기본 확률")
	eq(mul, MUL, "급소는 표식이 있는 적에게만")
	chance = Passives.crit(hero("axion", { rv_mastery = 10 }), false)
	eq(chance, BASE, "남의 직업의 패시브는 듣지 않는다")
	-- 방에서: 치명타가 그 확률로 터지고 그 배수로 들어간다(marked = 표식을 달아 두고 친다)
	--  타수 나누기(2026-10-14)부터 크리티컬은 줄마다 따로 굴린다 — 줄(숫자 하나)마다 센다(사용자: "모든타수가 별개로 크리티컬 확률이 적용되는겁니다")
	local function crits(class: string, id: string, skills, marked: boolean): (number, number)
		local h = hero(class, skills)
		local room, foe = arena(56, h)
		local hit = COMBAT.skills[id].hits[1]
		local n, sumCrit, sumPlain, plain, all = 0, 0, 0, 0, 0
		for _ = 1, 2000 do
			foe.x, foe.state = h.x + 20, "idle"
			foe.marks = if marked then { [h.id] = room.time + 5 } else nil
			local e = room:skillHit(h, hit, h.x, h.y, 1, 1, nil, COMBAT.skills[id].type, id).hits[1]
			local lines = e.lines or { e.dmg }
			for i, d in lines do
				all += 1
				local crit = if e.crits then e.crits[i] == true else e.crit == true
				if crit then
					n += 1
					sumCrit += d
					expect(e.big and e.crit, "크리티컬이 든 타는 센 타 · crit으로 온다(화면은 크리티컬인 줄만 밝은 색)")
				else
					plain += 1
					sumPlain += d
				end
			end
		end
		return n / all, (sumCrit / math.max(1, n)) / (sumPlain / math.max(1, plain))
	end
	local rateA, mulA = crits("axion", "ax_combo", { ax_combo = 20 }, false)
	near(rateA, BASE / 100, 0.25, "액시온: 치명타 5%쯤")
	near(mulA, MUL, 0.03, "치명타 = 1.5배")
	local rateE, mulE = crits("mooni", "mn_thrust", { mn_thrust = 20, mn_expert = 10 }, false)
	near(rateE, BASE / 100, 0.25, "무니: 치명타 5%쯤")
	near(mulE, MUL + PASS.mn_expert.fx.critMul, 0.03, "대검 달인: 치명타 = 1.7배")
	local rate0, mul0 = crits("riven", "rv_double", { rv_mark = 10, rv_double = 20 }, true)
	local rate1, mul1 = crits("riven", "rv_double", { rv_mark = 10, rv_double = 20, rv_mastery = 10, rv_back = 10 }, true)
	near(rate0, (BASE + core.crit) / 100, 0.08, "표식이 있는 적에게 35%")
	near(rate1, (BASE + core.crit + PASS.rv_mastery.fx.crit) / 100, 0.08, "창 숙련까지 45%")
	near(mul0, MUL, 0.03, "치명타 = 1.5배")
	near(mul1, MUL + PASS.rv_back.fx.markCritMul, 0.03, "급소: 1.8배")
	-- 2~4차의 스킬도 같은 확률로 터진다
	do
		local h = hero("reaper", { rp_judge = 20 })
		local dry = Caster.makeDry(X + 14, Y)
		local c = Caster.new(dry)
		c.dry = true
		for _ = 1, 400 do
			c:dryCast(h, "rp_judge", 0, function()
				dry.time += SUB
				c:sub(SUB)
			end)
		end
		for _ = 1, 60 do
			dry.time += SUB
			c:sub(SUB)
		end
		local n, total = 0, 0
		for _, e in c:actor(h).out.hits do
			total += 1
			if e.crit then
				n += 1
			end
		end
		eq(total, 1200, "단죄 400번 = 1200타")
		near(n / total, BASE / 100, 0.35, "2~4차의 스킬도 치명타 5%쯤")
	end
	COMBAT.rules.critChance = 0
	-- 깊은 표식: 셋까지 겹친다
	local h = hero("riven", { rv_mark = 10, rv_double = 20 })
	local room, foe = arena(57, h)
	local function mark(): number
		local out = { hits = { { mob = foe.id } } }
		room:mark(h, foe, out)
		return out.hits[1].markN
	end
	eq(mark(), 1, "표식 하나")
	eq(mark(), 1, "깊은 표식을 배우지 않으면 겹치지 않는다")
	h.skills.rv_mark2 = 10
	eq(mark(), 2, "깊은 표식: 둘")
	eq(mark(), 3, "셋")
	eq(mark(), 3, "셋까지")
	eq(room:marksOf(h, foe), 3, "그 졸개의 표식 셋")
	room.time += 20
	eq(room:marksOf(h, foe), 0, "시간이 지나면 사라진다")
	eq(mark(), 1, "다시 하나부터")
	-- 2~4차의 스킬이 표식의 수를 읽는다: 암살의 마무리는 표식 수만큼 세다
	local function finisher(n: number): number
		local v = hero("riven", { rv_kill = 30, rv_mark = 10, rv_mark2 = 10 })
		local dry, dummy = Caster.makeDry(X + 14, Y)
		local c = Caster.new(dry)
		c.dry = true
		local a = c:actor(v)
		local sum = 0
		for _ = 1, 30 do
			v.x, v.dir = X, 1
			dummy.marks, dummy.markN = nil, nil
			a.out.hits = {}
			-- 마무리 직전에 표식을 n개로 맞춰 둔다
			c:begin(v, "rv_kill", 1, nil)
			for _ = 1, 40 do
				dry.time += SUB
				c:sub(SUB)
			end
			dummy.marks = if n > 0 then { [v.id] = dry.time + 5 } else nil
			dummy.markN = if n > 0 then { [v.id] = n } else nil
			a.out.hits = {}
			expect(c:begin(v, "rv_kill", 2, nil), "마무리")
			for _ = 1, 60 do
				dry.time += SUB
				c:sub(SUB)
			end
			for _, e in a.out.hits do
				if not e.crit then
					sum += e.dmg
				else
					sum += e.dmg / COMBAT.rules.critMul
				end
			end
			eq(room ~= nil and (dummy.marks == nil or dummy.marks[v.id] == nil), true, "마무리가 표식을 태웠다")
		end
		return sum
	end
	near(finisher(3) / finisher(0), (18 + 3 * 8) / 18, 0.06, "암살의 마무리: 표식 셋이면 18 → 42")
	-- 스미는 독: 표식이 있는 적은 초마다 독 — 표식 하나마다 초당 피해의 10%
	local v = hero("riven", { rv_mark = 10, rv_venom = 10, rv_mark2 = 10 })
	v.dmgBoost = 50 -- (2026-10-15: 새 스펙에서 피해 숫자가 작아 반올림이 커서 키워 잰다)
	local room2, foe2 = arena(58, v)
	local function poison(n: number): number
		foe2.marks, foe2.markN = { [v.id] = room2.time + 99 }, { [v.id] = n }
		local sum, ticks = 0, 0
		for _ = 1, 100 do
			for _, e in room2:step({ [v.id] = v }, 0.05) do
				if e.type == "kit" then
					for _, x in e.result.hits do
						if x.proc == "venom" then
							sum += x.dmg
							ticks += 1
						end
					end
				end
			end
			foe2.state = "idle"
		end
		near(ticks, 5, 0.21, "5초에 다섯 번쯤")
		return sum / ticks
	end
	v.x = 100
	foe2.x = 6000
	local one = poison(1)
	near(one, Hero.powerRaw(v) * N.data.POWER.dps * PASS.rv_venom.fx.venom * RULES.dmgScale * 1.5, 0.02, "표식 하나: 초당 피해의 10%")
	near(poison(3) / one, 3, 0.02, "표식 셋이면 세 배")
	foe2.marks = nil
	local quiet = 0
	for _ = 1, 60 do
		for _, e in room2:step({ [v.id] = v }, 0.05) do
			if e.type == "kit" then
				quiet += 1
			end
		end
	end
	eq(quiet, 0, "표식이 없으면 독도 없다")
	-- 쌍영: 둘째 분신 — 분신의 몫이 1.5배
	local c1 = hero("riven", { rv_clone = 15 })
	local c2 = hero("riven", { rv_clone = 15, rv_clone2 = 10 })
	Buffs.cast(c1, "rv_clone", 0)
	Buffs.cast(c2, "rv_clone", 0)
	local s1, s2 = Buffs.echo(c1), Buffs.echo(c2)
	near(s2 / s1, 1 + PASS.rv_clone2.fx.clones, 1e-6, "쌍영: 따라 베는 몫이 1.5배")
end

-- ---- 6) 액시온: 깊은 호흡(3단계) · 충격파 · 넘치는 힘 ----
do
	local a = hero("axion", { ax_charge = 10 })
	eq(Kit.chargeLevels(a), 2, "힘 모으기 2단계")
	local lv = Kit.charge(a, "ax_slam", 5)
	eq(lv, 2, "오래 눌러도 2단계")
	a.skills.ax_charge2 = 10
	eq(Kit.chargeLevels(a), 3, "깊은 호흡: 3단계")
	lv = Kit.charge(a, "ax_slam", 5)
	eq(lv, 3, "3단계까지 모인다")
	near(Kit.chargeTime(a, "ax_slam"), COMBAT.kit.axion.core.per.ax_slam * 3, 1e-6, "끝까지 모으는 시간도 는다")
	local _, levels = Caster.chargeOf(a, {})
	eq(levels, 3, "2~4차의 모으는 스킬도 3단계")
	-- 넘치는 힘: 끝까지 모은 강타를 맞히면 3초 동안 다음 강타가 2단계에서 시작
	local s = hero("axion", { ax_charge = 10, ax_charge3 = 10, ax_slam = 20 })
	local room, foe = arena(59, s)
	foe.x = s.x + 20
	local level, mul, reach = Kit.charge(s, "ax_slam", 5)
	eq(level, 2, "끝까지 모았다")
	room:skillHit(s, COMBAT.skills.ax_slam.hits[1], s.x, s.y, 1, 1, nil, "mob", "ax_slam", { mul = mul, reach = reach, level = level })
	near(s.pass.surge, room.time + PASS.ax_charge3.fx.surge, 1e-6, "넘치는 힘이 켜졌다(3초)")
	local half = hero("axion", { ax_charge = 10, ax_charge3 = 10, ax_slam = 20 })
	room:skillHit(half, COMBAT.skills.ax_slam.hits[1], half.x, half.y, 1, 1, nil, "mob", "ax_slam", { mul = 1.5, reach = 10, level = 1 })
	expect(half.pass.surge < room.time, "끝까지 모으지 않은 강타로는 켜지지 않는다")
	local m2, r2 = Kit.chargeAt(s, 2)
	near(m2, mul, 1e-6, "그 단계의 피해 배수")
	near(r2, reach, 1e-6, "그 단계의 더 닿는 거리")
end

-- ---- 7) 리퍼: 낫 숙련 · 영혼 주머니(닿는 거리 · 영혼 8) · 깊은 흡수 · 망령 군단 ----
do
	local r = hero("reaper", { rp_mastery = 10, rp_soul = 10 })
	near(Passives.reach(r), 1 + PASS.rp_mastery.fx.reach, 1e-6, "낫 숙련: 닿는 거리 +10%")
	eq(Kit.soulMax(r), COMBAT.kit.reaper.core.max, "영혼 다섯까지")
	r.skills.rp_soul2 = 10
	eq(Kit.soulMax(r), 8, "영혼 주머니: 여덟까지")
	r.kit.souls = 4
	near(Passives.reach(r), 1 + PASS.rp_mastery.fx.reach, 1e-6, "영혼이 넷이면 그대로")
	r.kit.souls = 5
	near(Passives.reach(r), 1 + PASS.rp_mastery.fx.reach + PASS.rp_soul2.fx.reach, 1e-6, "영혼 다섯부터 닿는 거리 +15%")
	for _ = 1, 10 do
		Kit.gainSoul(r)
	end
	eq(r.kit.souls, 8, "영혼이 여덟까지 모인다")
	-- 닿는 거리: 보통은 닿지 않는 자리의 적이 맞는다
	local plain = hero("reaper", { rp_double = 20 })
	local long = hero("reaper", { rp_double = 20, rp_mastery = 10 })
	local room, foe = arena(60, plain)
	local hit = COMBAT.skills.rp_double.hits[1]
	foe.x = plain.x + hit.box[2] + 9
	eq(#room:skillHit(plain, hit, plain.x, plain.y, 1, 1, nil, "mob", "rp_double").hits, 0, "보통 때는 닿지 않는 거리")
	foe.state = "idle"
	eq(#room:skillHit(long, hit, long.x, long.y, 1, 1, nil, "mob", "rp_double").hits, 1, "낫 숙련을 배우면 닿는다")
	-- 깊은 흡수: 되찾는 체력 +50% · 영혼이 가득하면 두 배
	local function drained(skills, souls: number): number
		local h = hero("reaper", skills)
		h.kit.souls = souls
		h.hp = 1
		local rm, f = arena(61, h)
		f.x = h.x + 20
		local out = rm:skillHit(h, hit, h.x, h.y, 1, 1, nil, "mob", "rp_double")
		return out.heal or 0
	end
	local base = drained({ rp_double = 20, rp_drain = 10 }, 0)
	expect(base > 0, "생기 흡수")
	near(drained({ rp_double = 20, rp_drain = 10, rp_drain2 = 10 }, 0) / base, 1 + PASS.rp_drain2.fx.drain, 0.01, "깊은 흡수: +50%")
	near(drained({ rp_double = 20, rp_drain = 10, rp_drain2 = 10, rp_soul = 10 }, 5) / base, (1 + PASS.rp_drain2.fx.drain) * PASS.rp_drain2.fx.fullMul, 0.01, "영혼이 가득하면 두 배")
	-- 망령 군단: 망령을 셋까지 부린다
	local g = hero("reaper", { rp_ghost = 15, rp_soul = 10 })
	local room2 = arena(62, g)
	local function ghosts(): number
		local n = 0
		for _, p in room2.placed or {} do
			if p.owner == g and p.skill == "rp_ghost" then
				n += 1
			end
		end
		return n
	end
	for _ = 1, 3 do
		room2:place(g, "rp_ghost", 1, { hits = {}, kills = {} })
	end
	eq(ghosts(), 1, "망령은 하나만 둔다")
	g.skills.rp_ghost2 = 10
	for _ = 1, 4 do
		room2:place(g, "rp_ghost", 1, { hits = {}, kills = {} })
	end
	eq(ghosts(), 3, "망령 군단: 셋까지")
end

-- ---- 8) 무니: 수정 군락(넷 · 지속 +) · 달빛 칼날 · 수호령 각성 ----
do
	local m = hero("mooni", { mn_reson = 10 })
	local room, foe = arena(63, m)
	local function crystals(): number
		local n = 0
		for _, c in room.crystals do
			if c.owner == m.id then
				n += 1
			end
		end
		return n
	end
	for i = 1, 6 do
		room:addCrystal(m, 300 + i * 40, m.y, {})
	end
	eq(crystals(), COMBAT.kit.mooni.core.max, "수정 둘까지")
	near(room.crystals[#room.crystals].till - room.time, COMBAT.kit.mooni.core.life, 1e-6, "수정의 지속")
	m.skills.mn_grove = 10
	for i = 1, 6 do
		room:addCrystal(m, 700 + i * 40, m.y, {})
	end
	eq(crystals(), 4, "수정 군락: 넷까지")
	near(room.crystals[#room.crystals].till - room.time, COMBAT.kit.mooni.core.life * (1 + PASS.mn_grove.fx.life), 1e-6, "지속 +50%")
	-- 달빛 칼날: 대검이 맞은 횟수가 다섯 번째일 때마다 둘레로 번진다 — 그 타 피해의 50%
	local e = hero("mooni", { mn_thrust = 20, mn_edge = 10 })
	local room2, foe2, side = arena(64, e)
	local hit = COMBAT.skills.mn_thrust.hits[1]
	local edges, sumEdge, sumHit = 0, 0, 0
	for i = 1, 50 do
		foe2.x, foe2.state = e.x + 30, "idle"
		side.x, side.state = e.x + 30 + 20, "idle"
		for _, x in room2:skillHit(e, hit, e.x, e.y, 1, 1, nil, "boss", "mn_thrust").hits do
			if x.proc == "edge" then
				edges += 1
				sumEdge += x.dmg
			elseif x.mob == foe2.id then
				sumHit += x.dmg
			end
		end
	end
	expect(edges >= 30 and edges <= 44, "번지는 타가 다섯 번째마다(둘이 맞으면 두 번에 한 번 꼴) " .. edges)
	expect(sumEdge > 0 and sumHit > 0, "피해가 있다")
	expect(foe ~= nil, "방")
	-- 수호령 각성: 수호령 둘
	local gm = hero("mooni", { mn_guard = 15, mn_reson = 10 })
	local room3 = arena(65, gm)
	local function guards(): number
		local n = 0
		for _, p in room3.placed or {} do
			if p.owner == gm and p.skill == "mn_guard" then
				n += 1
			end
		end
		return n
	end
	room3:place(gm, "mn_guard", 1, { hits = {}, kills = {} })
	room3:place(gm, "mn_guard", 1, { hits = {}, kills = {} })
	eq(guards(), 1, "수호령은 하나만 둔다")
	gm.skills.mn_guard2 = 10
	room3:place(gm, "mn_guard", 1, { hits = {}, kills = {} })
	room3:place(gm, "mn_guard", 1, { hits = {}, kills = {} })
	eq(guards(), 2, "수호령 각성: 둘까지")
end

-- ---- 9) 살라맨더: 끓는 피(열기) · 꺼지지 않는 불 ----
do
	local core = COMBAT.kit.salamander.core
	local s = hero("salamander", { sl_heat = 10 })
	Kit.gainHeat(s)
	near(s.kit.heat, core.gain, 1e-6, "맞히면 열기 +10")
	eq(Kit.hotAt(s), core.hot, "달아오름 기준 50")
	local b = hero("salamander", { sl_heat = 10, sl_heat2 = 10 })
	local fx = PASS.sl_heat2.fx
	Kit.gainHeat(b)
	near(b.kit.heat, core.gain * (1 + fx.gain), 1e-6, "끓는 피: 열기가 30% 빨리 오른다")
	eq(Kit.hotAt(b), 40, "달아오름 기준이 40으로 낮아진다")
	b.kit.heat = 45
	expect(Kit.hot(b), "45면 달아올랐다")
	s.kit.heat = 45
	eq(Kit.hot(s), false, "끓는 피가 없으면 아직이다")
	-- 천천히 식는다
	local function cooled(h): number
		h.kit.heat, h.kit.heatT = 80, 0
		for _ = 1, 100 do
			Kit.tick(h, 0.05)
		end
		return 80 - h.kit.heat
	end
	near(cooled(b) / cooled(s), 1 - fx.slow, 0.02, "40% 천천히 식는다")
	-- 꺼지지 않는 불: 폭주 중에 쓰러뜨리면 폭주가 늘어난다(1초씩 · 10초까지)
	local o = hero("salamander", { sl_overheat = 20, sl_embers = 10, sl_punch = 20 })
	local room, foe = arena(66, o)
	Buffs.cast(o, "sl_overheat", 0)
	local before = o.buffs.sl_overheat.t
	local hit = COMBAT.skills.sl_punch.hits[1]
	local function kill()
		foe.x, foe.state, foe.hp = o.x + 20, "idle", 1
		return room:skillHit(o, hit, o.x, o.y, 1, 1, nil, "boss", "sl_punch")
	end
	local out = kill()
	near(o.buffs.sl_overheat.t - before, PASS.sl_embers.fx.extend, 1e-6, "쓰러뜨리면 폭주 +1초")
	expect(out.buffs, "걸린 버프가 바뀌었다고 알린다")
	for _ = 1, 20 do
		kill()
	end
	near(o.buffs.sl_overheat.t - before, PASS.sl_embers.fx.extendMax, 1e-6, "10초까지 늘어난다")
	local keep = Passives.get(o, "keep")
	eq(keep.keep, 50, "폭주가 끝나면 열기 50에서 시작한다(server world.luau의 tick이 넣는다)")
end
