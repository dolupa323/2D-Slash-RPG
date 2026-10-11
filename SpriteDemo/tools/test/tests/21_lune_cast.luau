-- 「달의 계승자」 — 2~4차의 쓰는 스킬(shared/lune/sim/caster.luau). 공방 js/lune/design/combat.js의 CASTRULE · CAST.
--  사용자 2026-10-08: "작업 이어서 하세요"(2~4차의 남은 스킬). 직업 묶음(shared/lune/kits)의 그 스킬을 서버가 돌린다:
--  재 보기(쓰는 시간 · 몫의 합) · 피해의 크기(붙어 있는 적 한 마리가 다 맞으면 설계의 피해) · 구간의 차례 · 모은 단계 · 바인드 · 넘어뜨리기 · 갈라짐 · 순간이동 · 회복 · 영혼/열기/수정.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local CAST = COMBAT.cast
local RULES = COMBAT.rules
local SUB = 1 / 60
local X, Y = 2000, 176

local function near(a, b, tol, msg)
	expect(math.abs(a - b) <= tol * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

-- 그 직업의 Lv.120 캐릭터(스킬은 직접 넣는다 — 처음 받는 것 말고는 배우지 않았다)
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

-- 재 볼 때 쓰는 빈 방(졸개 하나)에서 그 스킬을 진짜 피해로 돌린다. 방 · 졸개 · 돌리는 것 · 한 걸음을 돌려준다
local function dry(h, at: number?)
	local room, foe = Caster.makeDry(X + (at or 14), Y)
	local c = Caster.new(room)
	c.dry = true
	local function tick()
		room.time += SUB
		foe.rend = 0 -- 갈라짐이 얹는 것은 따로 본다
		c:sub(SUB)
	end
	return room, foe, c, tick
end
local function drain(c, tick)
	local guard = 0
	while (#c.timers > 0 or #c.shots > 0) and guard < 20 do
		tick()
		guard += SUB
	end
end
local function total(a): number
	local sum = 0
	for _, e in a.out.hits do
		sum += e.dmg
	end
	return sum
end

-- ---- 1) 자료: 설계의 쓰는 스킬마다 있고(소생만 빼고), 묶음에 그 스킬이 있고, 게임에 들어와 있다 ----
do
	local kinds = { mob = true, boss = true, attack = true, nuke = true, bind = true, heal = true }
	local seen = 0
	for class, c in CLASSES.classes do
		for _, t in c.tiers do
			for _, sk in t.skills do
				if t.job >= 2 and kinds[sk.type] and not COMBAT.skills[sk.id] and not COMBAT.placed[sk.id] then
					seen += 1
					local def = CAST[sk.id]
					expect(def ~= nil, "쓰는 스킬의 자료가 있다 " .. sk.id)
					if def then
						eq(def.who, class, "직업 " .. sk.id)
						eq(def.job, t.job, "차수 " .. sk.id)
						eq(def.max, sk.max, "마스터 레벨 " .. sk.id)
						local skill, kit = Kitset.skill(sk.id)
						expect(skill ~= nil and kit.who == class, "직업 묶음에 그 스킬이 있다 " .. sk.id)
						expect(skill.instant or #skill.segs > 0, "동작이 있거나 바로 나간다 " .. sk.id)
						expect(Hero.ready(sk.id), "게임에 들어와 있다(포인트가 찍힌다) " .. sk.id)
						if sk.cd then
							eq(def.cd, sk.cd, "다시 쓰기는 스킬 목록의 것 " .. sk.id)
							near(def.cdTime, sk.cd * 0.2, 1e-6, "다시 쓰기의 20%를 쓰는 시간에 더한다 " .. sk.id)
						end
					end
				end
			end
		end
	end
	eq(seen, 45, "2~4차의 쓰는 스킬 45개(소생까지)")
	expect(Hero.ready("mn_revive") and CAST.mn_revive.heal.revive > 0, "소생이 게임에 들어와 있다")
	-- 차수의 배수: 앞 차수의 1.4배씩 — 2차 1.4 · 3차 1.96 · 4차 2.744(사냥기는 x0.7)
	near(CAST.ax_rend.rate, N.data.POWER.dps * 1.4, 1e-3, "2차 보스기의 초당 피해")
	near(CAST.ax_crescent.rate, N.data.POWER.dps * 0.7 * 1.4, 1e-3, "2차 사냥기의 초당 피해")
	near(CAST.ax_leap.rate, N.data.POWER.dps * 1.96, 1e-3, "3차 보스기")
	near(CAST.ax_execute.rate, N.data.POWER.dps * 2.744, 1e-3, "4차 보스기")
	-- 새 차수의 스킬은 레벨 1부터 앞 차수의 같은 갈래 스킬을 마스터한 것보다 세다(사용자 2026-10-08: "당연히 1차 마스터보다 2차 1레벨 스킬이 강해야합니다. 이건 기본이에요")
	--  같은 시간 동안 넣는 피해로 견준다: 레벨 1 = 앞 차수 마스터의 1.1배 · 마스터 = 1.4배
	local FLOORC = COMBAT.castRule.floor
	near(FLOORC, 1.1 / 1.4, 1e-3, "2~4차의 쓰는 스킬은 레벨 1에서 마스터의 78.6%")
	near(Caster.scale(1, 20), FLOORC, 1e-6, "레벨 1의 세기")
	near(Caster.scale(20, 20), 1, 1e-6, "마스터의 세기")
	eq(Caster.scale(0, 20), 0, "배우지 않았으면 0")
	for class, c in CLASSES.classes do
		for _, kind in { "mob", "boss" } do
			local prev = N.data.POWER.dps * (if kind == "mob" then RULES.mobShare else 1) -- 1차를 마스터했을 때 1초에 넣는 피해(전투력의 몇 배)
			for job = 2, 4 do
				local found = nil
				for _, sk in c.tiers[job].skills do
					if sk.type == kind then
						found = sk
					end
				end
				expect(found ~= nil and CAST[found.id] ~= nil, ("%s %d차의 %s가 있다"):format(class, job, kind))
				if found and CAST[found.id] then
					local master = CAST[found.id].rate
					local first = master * Caster.scale(1, found.max)
					expect(first > prev, ("%s %d차 %s 레벨 1(%.3f)이 앞 차수 마스터(%.3f)보다 세다"):format(class, job, found.id, first, prev))
					near(first / prev, 1.1, 0.002, ("레벨 1 = 앞 차수 마스터의 1.1배 %s"):format(found.id))
					near(master / prev, 1.4, 0.002, ("마스터 = 앞 차수 마스터의 1.4배 %s"):format(found.id))
					prev = master
				end
			end
		end
	end
	-- 도약 강타: 등 뒤까지 친다 — 붙어 있던 적(뛰어넘은 적)도 맞는다(따로 정한 재는 자리가 없다)
	eq(CAST.ax_leap.at, nil, "도약 강타는 붙어 있는 적으로 잰다")
	near(Caster.profile("ax_leap", 0).hits, 1, 1e-6, "붙어 있던 적이 내려찍기에 맞는다")
	-- 새 차수가 열리면 그 차수의 사냥기 · 보스기가 레벨 1로 생긴다 · 퀵슬롯에 놓을 수 있다
	local h = Hero.new(2, "axion")
	while h.level < 30 do
		Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
	end
	eq(h.skills.ax_crescent, nil, "Lv.30이 됐어도 전직하기 전에는 2차 사냥기가 없다")
	expect(Hero.advance(h, 2), "2차로 전직한다")
	eq(h.skills.ax_crescent, 1, "Lv.30: 2차 사냥기가 레벨 1로 생긴다")
	eq(h.skills.ax_rend, 1, "Lv.30: 2차 보스기가 레벨 1로 생긴다")
	expect(Hero.canSlot(h, "ax_crescent"), "배운 2차 스킬은 퀵슬롯에 놓는다")
	eq(Hero.canSlot(h, "ax_whirl"), false, "배우지 않은 것은 못 놓는다")
end

-- ---- 2) 재 보기: 스킬마다 쓰는 시간과 몫의 합이 나온다 · 묶음의 코드가 오류 없이 돈다 ----
do
	for id, def in CAST do
		local p = Caster.profile(id, 0)
		eq(#p.errors, 0, "묶음의 코드가 오류 없이 돈다 " .. id .. (if p.errors[1] then " — " .. p.errors[1] else ""))
		local skill = Kitset.skill(id)
		if skill.instant then
			eq(p.time, 0, "바로 나가는 스킬은 쓰는 시간이 0 " .. id)
		else
			expect(p.time > 0.2 and p.time < 3, ("쓰는 시간이 말이 된다 %s %.2f"):format(id, p.time))
		end
		if def.type == "bind" or def.type == "heal" then
			eq(p.measured, 0, "묶기 · 회복은 피해가 없다 " .. id)
		else
			expect(p.measured > 0, "붙어 있는 적이 맞는다 " .. id)
		end
	end
	-- 따로 정한 것
	eq(Caster.profile("mn_burst", 0).w, 20, "공명 폭발: 수정 둘이 터질 때가 기준")
	eq(Caster.profile("mn_burst", 0).measured, 5, "공명 폭발: 수정이 없으면 제 둘레만")
	eq(Caster.profile("sl_vent", 0).w, 23, "열 방출: 열기가 가득일 때가 기준")
	-- 몇 가지는 값을 못 박아 둔다(묶음의 값이 바뀌면 알게)
	near(Caster.profile("ax_rend", 0).w, 14, 1e-6, "쪼개기 6 + 8")
	near(Caster.profile("ax_execute", 0).w, 20, 1e-6, "처단: 12 + 다섯 번째마다 40")
	near(Caster.profile("rv_kill", 0).w, 36, 1e-6, "암살: 여섯 번 x 3 + 마무리 18")
	near(Caster.profile("rp_judge", 0).w, 27, 1e-6, "단죄: 9 x 3")
	near(Caster.profile("mn_divide", 0).w, 40, 1e-6, "월광 대참: 22 + 18")
	near(Caster.profile("ax_crescent", 0).time, 0.667, 0.03, "초승달 가르기의 쓰는 시간")
end

-- ---- 3) 피해: 붙어 있는 적 한 마리가 다 맞으면 설계의 피해 = 전투력 x rate x (쓰는 시간 + cdTime) x 스킬 레벨의 세기 ----
do
	for id, def in CAST do
		local p = Caster.profile(id, 0)
		if p.measured <= 0 then
			continue
		end
		local h = hero(def.who, { [id] = def.max })
		local room, foe, c, tick = dry(h, def.at)
		local a = c:actor(h)
		for _ = 1, 10 do
			h.x, h.y, h.dir = X, Y, 1
			foe.x, foe.stun, foe.bind, foe.bindImm = X + (def.at or 14), 0, 0, 0
			if id == "sl_vent" then
				h.kit.heat = 0 -- 열기가 없을 때(기준의 3 / 23)
			end
			c:dryCast(h, id, 0, tick)
		end
		drain(c, tick)
		eq(#c.errors, 0, "오류 없이 돈다 " .. id)
		-- 사냥기는 일반 몬스터에게 +50% · 보스기는 보스가 아니면 보정이 없다 · 그 밖은 누구에게나 +50%
		local fit = if def.type == "boss" then 1 else 1 + RULES.targetBonus / 100
		local want = Hero.powerRaw(h) * def.rate * (p.time + def.cdTime) * RULES.dmgScale * fit * 10 * (p.measured / p.w)
		near(total(a), want, 0.05, "열 번 쓴 피해의 합 = 설계의 피해 " .. id)
	end
	-- 스킬 레벨의 세기: 레벨 1은 마스터의 40%
	local function sum(lv: number): number
		local h = hero("reaper", { rp_judge = lv })
		local _, _, c, tick = dry(h)
		for _ = 1, 10 do
			c:dryCast(h, "rp_judge", 0, tick)
		end
		drain(c, tick)
		return total(c:actor(h))
	end
	near(sum(1) / sum(20), COMBAT.castRule.floor, 0.04, "레벨 1의 피해는 마스터의 78.6%")
	-- 진짜 피해로: 「초승달 가르기」 레벨 1이 마스터한 「대지 강타」보다 1초에 더 넣는다(110%)
	do
		local a = hero("axion", { ax_crescent = 1, ax_slam = 20 })
		local _, _, c, tick = dry(a)
		for _ = 1, 40 do
			a.x, a.dir = X, 1
			c:dryCast(a, "ax_crescent", 0, tick)
		end
		drain(c, tick)
		local perSecNew = total(c:actor(a)) / 40 / Caster.profile("ax_crescent", 0).time
		local slam = COMBAT.skills.ax_slam
		local room, foe = Caster.makeDry(X + 20, Y)
		local old = 0
		for _ = 1, 40 do
			for _, hit in slam.hits do
				if not hit.except then
					foe.x, foe.state = X + 20, "idle"
					for _, e in room:skillHit(a, hit, X, Y, 1, 1, nil, "mob", nil).hits do
						old += e.dmg
					end
				end
			end
		end
		local time = 0
		for _, sg in slam.segs do
			time += sg.time
		end
		local perSecOld = old / 40 / time
		expect(perSecNew > perSecOld, ("초승달 가르기 레벨 1(%.0f/초)이 마스터한 대지 강타(%.0f/초)보다 세다"):format(perSecNew, perSecOld))
		near(perSecNew / perSecOld, 1.1, 0.04, "앞 차수 마스터의 110%")
	end
end

-- ---- 4) 구간의 차례: 화면이 구간을 잇고, 서버는 너무 이르지 않은지만 본다 ----
do
	local h = hero("riven", { rv_kill = 30 })
	local room, _, c = dry(h)
	c.dry = false
	local function run(t: number)
		for _ = 1, math.floor(t / SUB + 0.5) do
			room.time += SUB
			c:sub(SUB)
		end
	end
	local segs = Kitset.skill("rv_kill").segs
	local T1 = Caster.segTime("riven", segs[1])
	eq(c:begin(h, "rv_kill", 2, nil), false, "둘째 구간부터 시작하지 못한다")
	eq(c:begin(h, "nope", 1, nil), false, "없는 스킬")
	eq(c:begin(h, "ax_rend", 1, nil), false, "남의 직업의 스킬")
	expect(c:begin(h, "rv_kill", 1, nil), "첫 구간")
	expect(c:busy(h), "쓰는 중")
	eq(c:begin(h, "rv_kill", 1, nil), false, "쓰는 중에는 다시 시작하지 못한다")
	eq(c:begin(h, "rv_kill", 2, nil), false, "앞 구간이 한창일 때는 잇지 못한다")
	run(T1 - 0.1)
	expect(c:begin(h, "rv_kill", 2, nil), "앞 구간이 끝날 즈음에는 이어진다")
	eq(c:actor(h).skill.i, 2, "둘째 구간")
	eq(c:begin(h, "rv_kill", 3, nil), false, "없는 구간")
	-- 알림이 오지 않으면: 구간이 끝나고 조금 기다렸다가 스킬이 끝난다
	run(Caster.segTime("riven", segs[2]) + 0.1)
	expect(c:actor(h).skill ~= nil and c:actor(h).skill.done, "구간은 끝났고 다음 알림을 기다린다")
	eq(c:busy(h), false, "다른 스킬을 시작할 수 있다")
	run(0.4)
	eq(c:actor(h).skill, nil, "기다리다 끝난다")
	-- 막 끝난 구간의 다음 구간이 조금 늦게 와도 받는다
	expect(c:begin(h, "rv_kill", 1, nil), "다시 첫 구간")
	run(T1 + 0.35)
	eq(c:actor(h).skill, nil, "첫 구간이 끝나고 기다리다 끝났다")
	expect(c:begin(h, "rv_kill", 2, nil), "막 끝난 구간의 다음은 조금 늦어도 받는다")
	run(1)
	eq(c:begin(h, "rv_kill", 2, nil), false, "한참 뒤에는 받지 않는다")
	-- 쓰러지면 끊긴다
	expect(c:begin(h, "rv_kill", 1, nil), "첫 구간")
	h.alive = false
	run(0.1)
	eq(c:actor(h).skill, nil, "쓰러지면 스킬이 끊긴다")
	eq(c:begin(h, "rv_kill", 1, nil), false, "쓰러져서는 못 쓴다")
	-- 방을 나가면 그 사람의 것이 걷힌다
	h.alive = true
	local other = hero("riven", { rv_kill = 30 })
	expect(c:begin(other, "rv_kill", 1, nil), "다른 사람")
	c:step({ h }, SUB, {})
	eq(c.actors[other], nil, "방에 없는 사람의 것은 걷힌다")
end

-- ---- 5) 힘 모으기: 모은 단계는 서버가 흐른 시간으로 센다 · 단계마다 피해 + ----
do
	local core = COMBAT.kit.axion.core
	local function charged(held: number, full: boolean): number
		local h = hero("axion", { ax_crescent = 20, ax_charge = 10, ax_fullmoon = 20 })
		local room, _, c = dry(h)
		c.dry = false
		if full then
			Buffs.cast(h, "ax_fullmoon", 0)
		end
		expect(c:begin(h, "ax_crescent", 1, nil), "모으는 구간")
		local base = Caster.segTime("axion", Kitset.skill("ax_crescent").segs[1])
		for _ = 1, math.floor((base + held) / SUB + 0.5) do
			room.time += SUB
			c:sub(SUB)
		end
		local ok, lv = c:begin(h, "ax_crescent", 2, nil)
		expect(ok, "모은 뒤의 구간")
		return lv
	end
	eq(charged(0, false), 0, "톡 누르면 모으지 않은 것")
	eq(charged(0.42, false), 1, "0.4초 = 한 단계")
	eq(charged(0.82, false), 2, "0.8초 = 두 단계")
	eq(charged(0.95, false), 2, "더 눌러도 두 단계까지")
	eq(charged(0, true), 2, "만월: 모으지 않아도 끝까지 모은 것으로")
	-- 힘 모으기를 배우지 않았으면 모이지 않는다
	local plain = hero("axion", { ax_crescent = 20 })
	local per, levels = Caster.chargeOf(plain, {})
	eq(levels, 0, "배우지 않으면 0단계")
	near(per, COMBAT.castRule.charge, 1e-6, "한 단계가 모이는 시간")
	-- 단계마다의 피해: 1 + 단계 x 그 레벨의 bonus(마스터 55%)
	local function sum(lv: number): number
		local h = hero("axion", { ax_crescent = 20, ax_charge = 10 })
		local _, _, c, tick = dry(h)
		for _ = 1, 10 do
			h.x, h.dir = X, 1
			c:dryCast(h, "ax_crescent", lv, tick)
		end
		drain(c, tick)
		return total(c:actor(h))
	end
	local zero = sum(0)
	near(sum(1) / zero, 1 + core.bonus[2], 0.06, "한 단계: 피해 +55%(마스터)")
	near(sum(2) / zero, 1 + 2 * core.bonus[2], 0.06, "두 단계: 피해 +110%")
end

-- ---- 6) 졸개에 걸리는 것: 갈라짐(받는 피해 +) · 넘어뜨리기 · 바인드 ----
do
	local function arena(seed: number)
		local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(seed))
		for i, mob in room.mobs do
			mob.state, mob.t = "idle", 0
			mob.a, mob.b = 0, 4000
			mob.y = 176
			mob.x = 2000 + i * 30
			mob.hp, mob.maxHp = 1e12, 1e12
		end
		return room, room.mobs[1], room.mobs[2]
	end
	-- 갈라짐: 쪼개기에 맞은 적은 5초 동안 누구에게 맞든 20% 더 아프다
	local a = hero("axion", { ax_rend = 20 })
	a.x, a.y = 300, 176
	local room, foe = arena(31)
	foe.x = 314
	room.caster.dry = true
	local function tick()
		room.time += SUB
		room.caster:sub(SUB)
	end
	room.caster:dryCast(a, "ax_rend", 0, tick)
	near(foe.rend, 5, 0.1, "쪼개기: 갈라짐 5초")
	local hit = COMBAT.skills.ax_combo.hits[1]
	a.skills.ax_combo = 20
	local function avg(): number
		local s = 0
		for _ = 1, 200 do
			foe.x, foe.state = 314, "idle"
			for _, e in room:skillHit(a, hit, a.x, a.y, 1, 1, nil, "boss", "ax_combo").hits do
				s += e.dmg
			end
		end
		return s
	end
	foe.rend = 5
	local torn = avg()
	foe.rend = 0
	near(torn / avg(), 1 + COMBAT.castRule.rend, 0.03, "갈라진 적은 20% 더 아프다(1차 기술에도)")
	foe.rend = 5
	room:step({}, 6)
	eq(foe.rend, 0, "5초 뒤에 풀린다")

	-- 지진: 앞의 보통 적을 1.5초 넘어뜨린다 — 그동안 움직이지도 치지도 못한다
	local q = hero("axion", { ax_quake = 15 })
	q.x, q.y = 300, 176
	local room2, foe2, far2 = arena(32)
	foe2.x = 340
	room2.caster.dry = true
	room2.caster:dryCast(q, "ax_quake", 0, function()
		room2.time += SUB
		room2.caster:sub(SUB)
	end)
	expect(foe2.stun > 1, "지진: 넘어졌다 " .. tostring(foe2.stun))
	eq(far2.stun or 0, 0, "멀리 있는 적은 넘어지지 않는다")
	local at = foe2.x
	foe2.state, foe2.target = "idle", 1
	local hurt = 0
	for _ = 1, 20 do
		for _, e in room2:step({ [1] = q }, 0.05) do
			if e.type == "hurt" then
				hurt += 1
			end
		end
	end
	eq(hurt, 0, "넘어진 동안에는 치지 못한다")
	near(foe2.x, at, 0.001, "움직이지도 못한다")
	room2:step({}, 1)
	eq(foe2.stun, 0, "1.5초 뒤에 일어난다")

	-- 저승 사슬: 둘레의 적을 10초 묶는다 · 풀린 뒤 90초 동안은 다시 묶이지 않는다 · 방의 요약(Snap)에 묶인 시간이 실린다
	local r = hero("reaper", { rp_chains = 15 })
	r.x, r.y = 300, 176
	local room3, foe3, far3 = arena(33)
	foe3.x = 380
	local function cast3()
		room3.caster.dry = true
		room3.caster:dryCast(r, "rp_chains", 0, function()
			room3.time += SUB
			room3.caster:sub(SUB)
		end)
		room3.caster.dry = false
	end
	cast3()
	near(foe3.bind, 10, 0.2, "저승 사슬: 10초 묶인다")
	eq(far3.bind or 0, 0, "멀리 있는 적은 묶이지 않는다")
	near(foe3.bindImm, 10 + COMBAT.castRule.bindImm, 0.2, "묶인 시간 + 90초 동안 다시 묶이지 않는다")
	local row = nil
	for _, s in room3:snapshot() do
		if s[1] == foe3.id then
			row = s
		end
	end
	expect(row ~= nil and row[7] > 9, "요약의 일곱째 = 묶인 시간")
	local at3 = foe3.x
	foe3.state, foe3.target = "idle", 1
	local hurt3 = 0
	for _ = 1, 100 do
		for _, e in room3:step({ [1] = r }, 0.05) do
			if e.type == "hurt" then
				hurt3 += 1
			end
		end
	end
	eq(hurt3, 0, "묶인 동안에는 치지 못한다")
	near(foe3.x, at3, 0.001, "움직이지도 못한다")
	room3:step({}, 5.2)
	eq(foe3.bind, 0, "10초 뒤에 풀린다")
	foe3.x = 380
	cast3()
	eq(foe3.bind, 0, "풀린 뒤 90초 동안은 다시 묶이지 않는다")
	room3:step({}, 91)
	foe3.x, foe3.state = 380, "idle"
	cast3()
	near(foe3.bind, 10, 0.2, "그 뒤에는 다시 묶인다")
	-- 수정 감옥(무니)도 같다
	local m = hero("mooni", { mn_prison = 15 })
	m.x, m.y = 300, 176
	local room4, foe4 = arena(34)
	foe4.x = 380
	room4.caster.dry = true
	room4.caster:dryCast(m, "mn_prison", 0, function()
		room4.time += SUB
		room4.caster:sub(SUB)
	end)
	near(foe4.bind, 10, 0.2, "수정 감옥: 10초 묶인다")
	eq(foe4.bindKind, "crystal", "수정에 가둔다")
end

-- ---- 7) 순간이동: 서버도 그 자리로 옮겨 적는다(연막 순보 — 가까운 적의 뒤) ----
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(41))
	local h = hero("riven", { rv_step = 10 })
	h.x, h.y = 60, 176 -- 시작 평지(0~14칸) 위: 2026-10-10에 사냥터를 줄이면서 옛 자리(300 · 390)는 다리와 턱이 됐다
	for i, mob in room.mobs do
		mob.state, mob.t = "idle", 0
		mob.a, mob.b, mob.y = 0, 4000, 176
		mob.x = 2000 + i * 30
		mob.hp, mob.maxHp = 1e12, 1e12
	end
	local foe = room.mobs[1]
	foe.x = 150
	room.caster.dry = true
	room.caster:dryCast(h, "rv_step", 0, function()
		room.time += SUB
		room.caster:sub(SUB)
	end)
	near(h.x, foe.x + 20, 6, "연막 순보: 적의 뒤로 옮겨졌다")
	eq(h.dir, -1, "적 쪽을 돌아본다")
	local hits = room.caster:actor(h).out.hits
	expect(#hits >= 1 and hits[1].mob == foe.id, "옮겨진 자리에서 벤다")
	-- 적이 없으면 앞으로 80
	local lone = hero("riven", { rv_step = 10 })
	lone.x, lone.y = 300, 176
	foe.x = 3000
	room.caster:dryCast(lone, "rv_step", 0, function()
		room.time += SUB
		room.caster:sub(SUB)
	end)
	near(lone.x, 380, 1, "적이 없으면 앞으로 80")
end

-- ---- 8) 회복(달빛 치유): 나와 가까운 파티원의 체력을 되돌린다 ----
do
	local def = CAST.mn_heal
	local function cast(lv: number)
		local h = hero("mooni", { mn_heal = lv })
		local near1, far1 = hero("axion"), hero("riven")
		near1.id, far1.id = 2, 3
		near1.x, far1.x = X + 100, X + 400
		h.hp, near1.hp, far1.hp = 1, 1, 1
		local room, _, c = dry(h)
		c.dry = false
		expect(c:begin(h, "mn_heal", 1, { h, near1, far1 }), "달빛 치유")
		local events = {}
		for _ = 1, 80 do
			room.time += SUB
			c:step({ h }, SUB, events)
		end
		return h, near1, far1, events
	end
	local h, near1, far1, events = cast(10)
	near(h.hp, 1 + math.floor(h.maxHp * def.heal.hp + 0.5), 1e-6, "나: 최대 체력의 30%(마스터)")
	near(near1.hp, 1 + math.floor(near1.maxHp * def.heal.hp + 0.5), 1e-6, "가까운 파티원도")
	eq(far1.hp, 1, "멀리 있는 파티원은 닿지 않는다")
	local n = 0
	for _, e in events do
		if e.type == "healed" then
			n += 1
			expect(e.amount > 0 and e.by == h.id, "누가 얼마나 채웠는지 알린다")
		end
	end
	eq(n, 2, "체력이 찬 사람마다 알린다")
	local low = cast(1)
	near(low.hp, 1 + math.floor(low.maxHp * def.heal.hp * CLASSES.skillRule.floor + 0.5), 1e-6, "레벨 1: 그 70%(1레벨의 세기 — skillRule.floor)")
	-- 가득 차 있으면 넘치지 않는다
	local full = hero("mooni", { mn_heal = 10 })
	local room, _, c, tick = dry(full)
	c:dryCast(full, "mn_heal", 0, tick)
	eq(full.hp, full.maxHp, "넘치지 않는다")
	eq(#c.events, 0, "채운 것이 없으면 알리지 않는다")
	expect(room ~= nil, "방")
end

-- ---- 9) 직업의 장치와 맞물린다: 영혼(리퍼) · 열기(살라맨더) · 수정(무니) · 표식(리븐) · 사출기 ----
do
	-- 영혼 수확: 맞힌 적이 있으면 영혼 1(캐릭터의 영혼이 오른다)
	local r = hero("reaper", { rp_reap = 10, rp_soul = 10 })
	local _, _, c, tick = dry(r)
	c:dryCast(r, "rp_reap", 0, tick)
	eq(r.kit.souls, 1, "영혼 수확: 영혼 1")
	expect(c:actor(r).out.kit, "장치의 모습이 바뀌었다고 알린다")
	-- 참수: 영혼이 있으면 타마다 하나씩 태워 그림자 낫이 한 번 더
	local b = hero("reaper", { rp_behead = 30, rp_soul = 10 })
	local _, _, cb, tickB = dry(b)
	cb:dryCast(b, "rp_behead", 0, tickB)
	drain(cb, tickB)
	local plain = #cb:actor(b).out.hits
	eq(plain, 3, "참수: 세 번")
	b.kit.souls = 3
	cb:dryCast(b, "rp_behead", 0, tickB)
	drain(cb, tickB)
	eq(#cb:actor(b).out.hits - plain, 6, "영혼이 있으면 타마다 그림자 낫이 한 번 더")
	eq(b.kit.souls, 0, "영혼 셋을 태웠다")

	-- 열 방출: 열기만큼 세고, 열기는 0이 된다
	local function vent(heat: number): number
		local s = hero("salamander", { sl_vent = 10, sl_heat = 10 })
		s.kit.heat = heat
		local _, foeS, cs, tickS = dry(s)
		local sum = 0
		for _ = 1, 40 do
			s.kit.heat = heat
			foeS.x = X + 14 -- 미는 타라 조금씩 밀린다(제자리에 다시 세운다)
			cs:dryCast(s, "sl_vent", 0, tickS)
			eq(s.kit.heat, 0, "열 방출: 열기가 0이 된다")
		end
		for _, e in cs:actor(s).out.hits do
			if not e.proc then
				sum += e.dmg
			end
		end
		return sum
	end
	local hot = vent(100)
	near(vent(50) / hot, 13 / 23, 0.05, "열기 50이면 가득일 때의 57%")
	near(vent(0) / hot, 3 / 23, 0.05, "열기 0이면 13%")

	-- 공명 폭발: 수정이 있으면 수정마다 터진다 — 금이 가고, 한 번 더 터지면 사라진다
	local m = hero("mooni", { mn_burst = 20, mn_reson = 10 })
	local room, foe, cm, tickM = dry(m)
	room:addCrystal(m, X + 10, Y, {})
	room:addCrystal(m, X + 40, Y, {})
	eq(#room.crystals, 2, "수정 둘")
	cm:dryCast(m, "mn_burst", 0, tickM)
	local first = 0
	for _, e in cm:actor(m).out.hits do
		if e.mob == foe.id then
			first += e.dmg
		end
	end
	expect(room.crystals[1].cracked and room.crystals[2].cracked, "터진 수정에 금이 간다")
	eq(#room.crystals, 2, "한 번 터져서는 사라지지 않는다")
	local p = Caster.profile("mn_burst", 0)
	near(first, Hero.powerRaw(m) * CAST.mn_burst.rate * p.time * RULES.dmgScale * 1.5, 0.12, "수정 둘이 터지면 설계의 피해(100%)")
	cm:dryCast(m, "mn_burst", 0, tickM)
	eq(#room.crystals, 0, "금 간 수정이 한 번 더 터지면 사라진다")
	local gone = 0
	for _, e in cm.events do
		if e.type == "crystalGone" then
			gone += 1
		end
	end
	eq(gone, 2, "사라진 수정을 알린다")

	-- 표식(리븐): 표식을 남기는 타만 남긴다 · 암살의 마무리는 표식을 태우고 그만큼 세다 · 연막 순보는 표식을 터뜨린다
	local v = hero("riven", { rv_kill = 30, rv_step = 10, rv_mark = 10 })
	local roomV, foeV, cv, tickV = dry(v)
	cv:dryCast(v, "rv_kill", 0, tickV)
	local hits = cv:actor(v).out.hits
	eq(#hits, 7, "암살: 여섯 번 + 마무리")
	expect(foeV.marks == nil or (foeV.marks[v.id] or 0) <= roomV.time, "마무리가 표식을 태웠다")
	local marked = 0
	for i = 1, 6 do
		if hits[i].mark then
			marked += 1
		end
	end
	eq(marked, 3, "여섯 번 가운데 세 번이 표식을 남긴다")
	-- 연막 순보: 표식이 있으면 터뜨린다(타가 하나 더)
	roomV:mark(v, foeV, { hits = { { mob = foeV.id } } })
	local before = #cv:actor(v).out.hits
	v.x, v.dir = X, 1
	cv:dryCast(v, "rv_step", 0, tickV)
	eq(#cv:actor(v).out.hits - before, 2, "베는 타 + 표식이 터지는 타")
	expect(foeV.marks[v.id] == nil, "표식이 사라졌다")
	roomV.time += 20
	before = #cv:actor(v).out.hits
	v.x, v.dir, foeV.x = X, 1, X + 14
	cv:dryCast(v, "rv_step", 0, tickV)
	eq(#cv:actor(v).out.hits - before, 1, "표식이 없으면 베는 타만")

	-- 사출기: 2~4차의 도끼질에도 메아리 도끼가 따라 나간다(1차와 같은 셈 — 세 번째 타마다)
	local e = hero("axion", { ax_rend = 20, ax_echo = 10 })
	e.kit.on = true
	local _, _, ce, tickE = dry(e)
	for _ = 1, 3 do
		ce:dryCast(e, "ax_rend", 0, tickE)
	end
	local echoes = 0
	for _, x in ce:actor(e).out.hits do
		if x.proc == "echo" then
			echoes += 1
		end
	end
	eq(echoes, 2, "여섯 타에 메아리 도끼 둘(세 번째 타마다)")
	-- 열기: 2~4차의 주먹에도 오른다
	local s = hero("salamander", { sl_rush = 20, sl_heat = 10 })
	local _, _, cs, tickS = dry(s)
	cs:dryCast(s, "sl_rush", 0, tickS)
	near(s.kit.heat, 30, 1e-6, "불꽃 돌진 세 타: 열기 +30")
	expect(Kit.level(s, "core") > 0, "열기를 배웠다")
end

-- ---- 10) 누르고 있는 스킬: 오래 누를수록 타가 는다 ----
do
	local function hits(hold: number): number
		local h = hero("riven", { rv_flurry = 20 })
		local _, _, c, tick = dry(h)
		c:dryCast(h, "rv_flurry", 0, tick, hold)
		return #c:actor(h).out.hits
	end
	local short, long = hits(0), hits(2)
	expect(short >= 2 and short <= 3, "난도질: 톡 누르면 두세 타 " .. short)
	expect(long >= 15 and long <= 17, "난도질: 2초 누르면 1초에 8타쯤 " .. long)
end
