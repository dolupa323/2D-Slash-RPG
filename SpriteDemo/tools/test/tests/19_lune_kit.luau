-- 「달의 계승자」 — 1차의 온오프 사출기 · 핵심 장치 · 패시브(shared/lune/sim/kit.luau · room.luau의 kitAfter). 공방 js/lune/design/combat.js의 KIT1.
--  사용자 2026-10-08: "스킬중에 지금 온오프, 차지 이런거 구현 안된건가요" · "지금 옮기던 작업을 하다가 만거죠?" — 사냥기 · 보스기 · 이동기만 옮기고 멈춰 있던 것을 마저 옮겼다.
--  방(Room)에 졸개 둘을 세워 놓고 기술의 한 타를 직접 넣어 본다(서버를 거치는 것 — 켜고 끄기 · 모은 시간 — 은 13_lune_world.luau).
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local RULES = COMBAT.rules
local KIT = COMBAT.kit
local FLOOR = CLASSES.skillRule.floor

local X, Y = 300, 176

local function near(a, b, tol, msg)
	expect(math.abs(a - b) <= tol * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

-- 방 하나와 그 직업의 캐릭터(Lv.20), 내 앞에 세운 졸개 둘(쓰러지지 않게 체력을 넉넉히). skills = 배운 스킬 { [이름표] = 레벨 }
local function arena(class: string, skills, seed: number?)
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(seed or 7))
	local h = Hero.new(1, class)
	h.level = 20
	for id, lv in skills or {} do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y = X, Y
	for i, mob in room.mobs do
		mob.state, mob.t = "idle", 0
		mob.a, mob.b = 0, 2000
		mob.y = Y
		mob.x = 1500 + i * 30 -- 멀리 치워 둔다
		mob.hp, mob.maxHp = 1e12, 1e12
	end
	local a, b = room.mobs[1], room.mobs[2]
	a.x, b.x = X + 20, X + 90
	return room, h, a, b
end

-- 그 기술의 n째 타를 넣는다. 맞은 졸개는 조금 밀리고 멈칫한다 — 같은 자리에서 거듭 쳐 보려고 넣은 뒤에 제자리로 돌려놓는다
local function strike(room, h, id: string, n: number, opts)
	local def = COMBAT.skills[id]
	local keep = {}
	for i, mob in room.mobs do
		keep[i] = mob.x
	end
	local out = room:skillHit(h, def.hits[n], h.x, h.y, 1, 1, nil, def.type, id, opts)
	for i, mob in room.mobs do
		mob.x = keep[i]
		if mob.state == "hit" then
			mob.state, mob.t = "idle", 0
		end
	end
	return out
end

local function procs(out, kind: string)
	local list = {}
	for _, e in out.hits do
		if e.proc == kind then
			table.insert(list, e)
		end
	end
	return list
end

local function mains(out)
	local list = {}
	for _, e in out.hits do
		if not e.proc then
			table.insert(list, e)
		end
	end
	return list
end

-- ---- 1) 자료 ----
for _, class in CLASSES.order do
	local k = KIT[class]
	expect(k ~= nil and #k.skills == 2, "직업마다 장치가 있다 " .. class)
	for _, id in k.skills do
		expect(COMBAT.skills[id] ~= nil and COMBAT.skills[id].who == class and Kit.follows(id), "따라붙는 기술 " .. id)
	end
	for _, role in { "toggle", "core", "passive" } do
		local id = k[role].id
		local info = Kit.skill(id)
		expect(info ~= nil and info.who == class and info.role == role, ("%s의 %s = %s"):format(class, role, id))
		local found = false
		for _, sk in CLASSES.classes[class].skills do
			if sk.id == id then
				found = sk.type == role and sk.max == info.max
			end
		end
		expect(found, "설계의 1차 스킬 목록에 같은 갈래 · 같은 마스터 레벨로 있다 " .. id)
		eq(#COMBAT.kitEffects[id], info.max, "레벨마다의 효과 글 " .. id)
		for lv, text in COMBAT.kitEffects[id] do
			expect(typeof(text) == "string" and #text > 0, ("효과 글 %s Lv.%d"):format(id, lv))
		end
		expect(COMBAT.kitEffects[id][1] ~= COMBAT.kitEffects[id][info.max], "레벨 1과 마스터의 효과가 다르다 " .. id)
	end
end
eq(Kit.skill("ax_slam"), nil, "주력기는 장치가 아니다")
eq(Kit.skill(7), nil, "이름표가 글이 아니면 없다")
expect(not Kit.follows("ax_dash") and not Kit.follows("no_such"), "이동기에는 따라붙지 않는다")
for _, c in COMBAT.kitCheck.charge do
	near(Kit.chargeBonus(c[1], c[2]), c[3], 1e-6, ("힘 모으기의 단계마다 피해 Lv.%d"):format(c[1]))
end

-- ---- 2) 배우지 않았으면 아무것도 따라 나가지 않는다 ----
for _, class in CLASSES.order do
	local room, h, a = arena(class, nil)
	local id = KIT[class].skills[2]
	for _ = 1, 30 do
		local out = strike(room, h, id, 1, nil)
		for _, e in out.hits do
			expect(e.proc == nil and e.crit == nil and e.mark == nil, "배우지 않은 장치는 없다 " .. class)
		end
		expect(out.kit == nil and out.heal == nil and out.crystals == nil, "장치의 일도 없다 " .. class)
	end
	eq(#room.crystals, 0, "수정도 없다 " .. class)
	eq(h.kit.heat, 0, "열기도 없다 " .. class)
	eq(Kit.toggle(h), nil, "배우지 않은 사출기는 켜지지 않는다 " .. class)
	expect(not h.kit.on and not Kit.firing(h), "꺼져 있다 " .. class)
	eq(Kit.attack(h), 1, "공격력 그대로 " .. class)
	eq(Kit.maxHp(h), 1, "체력 그대로 " .. class)
	eq(Kit.dodge(h), 0, "회피 없음 " .. class)
	eq(Kit.cut(h, true), 1, "받는 피해 그대로 " .. class)
	local run, jump = Kit.move(h)
	expect(run == 1 and jump == 1, "걸음 그대로 " .. class)
	expect(a.marks == nil, "표식 없음 " .. class)
end

-- ---- 3) 액시온: 메아리 도끼 · 힘 모으기 · 묵직한 몸 ----
do
	local tg = KIT.axion.toggle
	local room, h, a = arena("axion", { ax_echo = 10 })
	eq(Kit.toggle(h), true, "배운 사출기를 켠다")
	expect(Kit.firing(h) and Kit.isToggle(h, "ax_echo") and not Kit.isToggle(h, "rv_star"), "켜졌다")
	-- 메아리 도끼(2026-10-28 리마스터 — 고르심 「다 모은 한 방에만」): 끝까지 모아 친 한 방이 맞은 적마다 하나 · 그 타 피해의 share배(1). 모으지 않은 타 · 덜 모은 타에는 없다
	local levels = Kit.chargeLevels(h)
	local fullOpts = { mul = 1, reach = 0, level = levels }
	for _ = 1, 6 do
		eq(#procs(strike(room, h, "ax_combo", 1, nil), "echo"), 0, "모으지 않은 타에는 떨어지지 않는다")
	end
	eq(#procs(strike(room, h, "ax_combo", 1, { mul = 1, reach = 0, level = levels - 1 }), "echo"), 0, "덜 모은 타에도 떨어지지 않는다")
	for _ = 1, 5 do
		local out = strike(room, h, "ax_combo", 1, fullOpts)
		local main, list = mains(out), procs(out, "echo")
		eq(#main, 1, "모아 친 한 방은 한 숫자")
		eq(#list, 1, "끝까지 모아 친 한 방에 하나")
		if #list == 1 and #main == 1 then
			eq(list[1].mob, a.id, "그 적에게 떨어진다")
			eq(list[1].dmg, math.max(1, math.floor(main[1].dmg * tg.share + 0.5)), "그 타 피해만큼(share 1)")
			expect(list[1].sy < a.y - 30 and math.abs(list[1].sx - a.x) <= 4, "머리 위에서 떨어진다(맞고 조금 밀린 그 자리)")
		end
	end
	eq(Kit.toggle(h), false, "끈다")
	for _ = 1, 3 do
		eq(#procs(strike(room, h, "ax_combo", 1, fullOpts), "echo"), 0, "꺼 두면 나가지 않는다")
	end
	-- 레벨 1이면 그 타의 FLOOR배(스킬 레벨의 세기)
	local room1, h1 = arena("axion", { ax_echo = 1 })
	Kit.toggle(h1)
	local out1 = strike(room1, h1, "ax_combo", 1, fullOpts)
	local e1 = procs(out1, "echo")[1]
	expect(e1 ~= nil and e1.dmg == math.max(1, math.floor(mains(out1)[1].dmg * tg.share * FLOOR + 0.5)), "레벨 1의 메아리 도끼는 그 타의 FLOOR배")
	-- 메아리 도끼로 쓰러뜨려도 잡은 것이다(경험치 · 떨어지는 것) — 흩어짐 없이 재어 그 타 · 도끼의 피해를 정해 둔다(도끼가 그 타의 0.2배라 흩어짐 ±10%면 갈리지 않는다)
	local spread = COMBAT.rules.spread
	COMBAT.rules.spread = 0
	local roomK, hK, aK = arena("axion", { ax_echo = 10 })
	Kit.toggle(hK)
	local xp0 = hK.xp + hK.level * 1e9
	local probe = strike(roomK, hK, "ax_combo", 1, fullOpts)
	aK.hp = math.floor(mains(probe)[1].dmg * (1 + tg.share / 2)) -- 제 타로는 안 쓰러지고 메아리 도끼(그 타의 share배)로 쓰러지게
	local outK = strike(roomK, hK, "ax_combo", 1, fullOpts)
	COMBAT.rules.spread = spread
	expect(outK ~= nil and #outK.kills == 1 and outK.kills[1].mob == aK.id and #procs(outK, "echo") == 1, "메아리 도끼가 쓰러뜨린 것도 잡은 것으로 친다")
	expect(hK.xp + hK.level * 1e9 > xp0, "경험치를 받는다")

	-- 힘 모으기
	local core = KIT.axion.core
	local hc = Hero.new(2, "axion")
	local lv0, m0, r0 = Kit.charge(hc, "ax_slam", 5)
	expect(lv0 == 0 and m0 == 1 and r0 == 0 and Kit.chargeTime(hc, "ax_slam") == 0, "배우지 않았으면 모이지 않는다")
	hc.skills.ax_charge = 10
	eq(Kit.chargeTime(hc, "ax_slam"), core.per.ax_slam * core.levels, "대지 강타를 끝까지 모으는 시간")
	eq(Kit.chargeTime(hc, "ax_combo"), core.per.ax_combo * core.levels, "도끼 내려찍기를 끝까지 모으는 시간")
	eq(Kit.chargeTime(hc, "ax_dash"), 0, "돌진은 모을 수 없다")
	-- 모은 한 방 = 모으지 않은 한 방 x (쓰는 시간 + 단계 x per) ÷ 쓰는 시간 x (1 + 단계 x bonus) — 끝까지 모으면 초당 피해가 1 + 단계 x bonus배(2026-10-28 사용자 "시간을 생각해서 dps 계산을해서")
	local function timeOf(id)
		local t = 0
		for _, sg in COMBAT.skills[id].segs do
			t += sg.time
		end
		return t
	end
	local per, T = core.per.ax_slam, timeOf("ax_slam")
	for _, c in { { 0, 0 }, { per - 0.01, 0 }, { per, 1 }, { per * 2 - 0.01, 1 }, { per * 2, 2 }, { 9, 2 }, { -1, 0 } } do
		local lv, mul, reach = Kit.charge(hc, "ax_slam", c[1])
		eq(lv, c[2], ("대지 강타를 %.2f초 모으면 %d단계"):format(c[1], c[2]))
		near(mul, (1 + c[2] * core.bonus[2]) * (T + c[2] * per) / T, 1e-9, "모은 시간만큼 · 단계마다 초당 피해 +12%(마스터)")
		near(mul * T / (T + c[2] * per), 1 + c[2] * core.bonus[2], 1e-9, "그 단계로 치면 초당 피해가 1 + 단계 x bonus배")
		eq(reach, c[2] * core.reach, "단계마다 닿는 거리 +10")
	end
	eq((Kit.charge(hc, "ax_combo", core.per.ax_combo)), 1, "도끼 내려찍기는 per초에 한 단계")
	expect(core.per.ax_slam < core.per.ax_combo, "사냥기(대지 강타)가 보스기(도끼 내려찍기)보다 빨리 모인다")
	hc.skills.ax_charge = 1
	near(select(2, Kit.charge(hc, "ax_slam", per * 2)), (1 + 2 * core.bonus[1]) * (T + 2 * per) / T, 1e-9, "레벨 1이면 단계마다 초당 피해 +8%")
	-- 끝까지 모은 한 방이 그 시간 동안 톡톡 친 것보다 세다(어느 레벨이든)
	for _, lv in { 1, 5, 10 } do
		hc.skills.ax_charge = lv
		for _, id in { "ax_slam", "ax_combo" } do
			local n, mul = Kit.charge(hc, id, 9)
			local t = timeOf(id)
			expect(n == 2 and mul / (t + n * core.per[id]) > 1.1 / t, ("끝까지 모은 %s의 초당 피해가 톡톡 친 것의 1.1배를 넘는다 Lv.%d"):format(id, lv))
		end
	end
	hc.skills.ax_charge = 1
	-- 모아 친 타: 피해가 그 배수만큼, 닿는 거리가 그만큼 는다(같은 씨앗의 방 둘로 견준다 — 흩어짐이 같다)
	local roomA, hA, aA = arena("axion", { ax_charge = 10 }, 11)
	local roomB, hB, aB = arena("axion", { ax_charge = 10 }, 11)
	local _, mul2, reach2 = Kit.charge(hA, "ax_slam", 0.6)
	local plain = strike(roomA, hA, "ax_slam", 1, nil)
	local charged = strike(roomB, hB, "ax_slam", 1, { mul = mul2, reach = reach2 })
	-- 피해는 정수로 반올림된다: 비율의 허용 = 두 타의 반올림 몫(0.5씩)만큼(2026-10-28 — 방어구의 공격력이 붙어 보통 타가 57(실제 57.4) · 모아 친 타 121이 되어 0.01을 넘었다)
	near(charged.hits[1].dmg / plain.hits[1].dmg, mul2, math.max(0.01, (1 + mul2) * 0.5 / plain.hits[1].dmg), "끝까지 모아 치면 피해가 그 배수만큼")
	expect(charged.hits[1].big == true, "모아 친 타는 센 타로 뜬다")
	local slamBox = COMBAT.skills.ax_slam.hits[1].box
	aA.x, aB.x = X + slamBox[2] + 12, X + slamBox[2] + 12 -- 보통은 닿지 않는 자리(졸개의 몸 반폭 6을 넘어서)
	eq(#strike(roomA, hA, "ax_slam", 1, nil).hits, 0, "모으지 않으면 닿지 않는다")
	eq(#strike(roomB, hB, "ax_slam", 1, { mul = mul2, reach = reach2 }).hits, 1, "모으면 20도트 더 닿는다")

	-- 묵직한 몸: 최대 체력 +20%(마스터) — 올릴 때마다 는다
	local hg = Hero.new(3, "axion")
	hg.level, hg.sp = 20, 10
	Hero.recalc(hg)
	local base = N.hpOf("axion", 20, 0)
	eq(hg.maxHp, base, "배우기 전의 체력")
	expect(Hero.skillUp(hg, "ax_grit"), "묵직한 몸을 올린다")
	eq(hg.maxHp, math.floor(base * (1 + KIT.axion.passive.hp / 100 * FLOOR) + 0.5), "레벨 1에 +8%")
	for _ = 2, 10 do
		Hero.skillUp(hg, "ax_grit")
	end
	eq(hg.maxHp, math.floor(base * (1 + KIT.axion.passive.hp / 100) + 0.5), "마스터에 +20%")
	local backG = Hero.unpack(3, Hero.pack(hg))
	eq(backG.maxHp, hg.maxHp, "다시 들어와도 그 체력이다")
end

-- ---- 4) 리븐: 표식 · 그림자 표창 · 날랜 몸 ----
do
	local core, tg, pas = KIT.riven.core, KIT.riven.toggle, KIT.riven.passive
	local room, h, a, b = arena("riven", { rv_mark = 10 })
	b.x = 1400 -- 혼자 세운다
	local first = strike(room, h, "rv_double", 1, nil)
	expect(#first.hits == 1 and first.hits[1].mark == core.time and first.hits[1].crit == nil, "베기에 맞으면 표식 8초(처음 맞을 때는 표식이 없었다)")
	expect(a.marks ~= nil and a.marks[h.id] == room.time + core.time, "졸개에 표식이 남는다")
	-- 표식이 있는 적에게 치명타 30%: 피해 1.5배
	--  크리티컬은 줄(숫자 하나)마다 따로 굴린다(타수 나누기 — 2026-10-14) — 줄마다 센다
	local crits, n = 0, 0
	for _ = 1, 600 do
		local e = strike(room, h, "rv_double", 1, nil).hits[1]
		for i in e.lines or { e.dmg } do
			n += 1
			if (e.crits and e.crits[i]) or (not e.crits and e.crit) then
				crits += 1
			end
		end
		if e.crit then
			expect(e.big == true, "치명타는 센 타로 뜬다")
		end
	end
	expect(crits > n * 0.22 and crits < n * 0.38, ("표식이 있는 적에게 치명타 30%% — %d / %d"):format(crits, n))
	-- 치명타의 피해: 같은 씨앗으로 견준다(표식이 없는 방과)
	room.time += core.time + 1
	local e2 = strike(room, h, "rv_double", 1, nil).hits[1]
	expect(e2.crit == nil and e2.mark == core.time, "표식이 풀린 뒤에는 치명타가 없다(다시 남는다)")
	-- 표식은 쓰러지면 지워진다
	a.hp = 1
	local dead = strike(room, h, "rv_double", 1, nil)
	expect(#dead.kills == 1 and a.marks == nil, "쓰러진 졸개의 표식은 지워진다")

	-- 그림자 표창: 40% 확률로, 가까운 다른 적에게(없으면 그 적에게) — 그 타 피해의 45%, 표식을 남긴다
	local roomS, hS, aS, bS = arena("riven", { rv_star = 10, rv_mark = 10 })
	Kit.toggle(hS)
	bS.x = X + 120 -- 베기에는 안 맞고 표창은 닿는 자리
	local stars, toOther = 0, 0
	for _ = 1, n do
		aS.marks, bS.marks = nil, nil
		local out = strike(roomS, hS, "rv_double", 1, nil)
		local list = procs(out, "star")
		expect(#list <= 1, "한 타에 표창은 하나까지")
		if #list == 1 then
			stars += 1
			if list[1].mob == bS.id then
				toOther += 1
			end
			eq(list[1].dmg, math.max(1, math.floor(mains(out)[1].dmg * tg.share + 0.5)), "그 타 피해의 45%")
			expect(list[1].mark == core.time and bS.marks ~= nil, "표창이 표식을 남긴다")
		end
	end
	expect(stars > n * 0.32 and stars < n * 0.48, ("표창이 날아갈 확률 40%% — %d / %d"):format(stars, n))
	eq(toOther, stars, "가까운 다른 적에게 날아간다")
	bS.x = 1400
	local self1 = nil
	for _ = 1, 60 do
		local list = procs(strike(roomS, hS, "rv_double", 1, nil), "star")
		if #list == 1 then
			self1 = list[1]
			break
		end
	end
	expect(self1 ~= nil and self1.mob == aS.id, "다른 적이 없으면 그 적에게 날아간다")

	-- 날랜 몸: 걸음 +10% · 뛰는 힘 +5% · 회피 10%
	local hn = Hero.new(4, "riven")
	hn.skills.rv_nimble = 10
	local run, jump = Kit.move(hn)
	near(run, 1 + pas.run / 100, 1e-9, "걸음 +10%")
	near(jump, 1 + pas.jump / 100, 1e-9, "뛰는 힘 +5%")
	near(Kit.dodge(hn), pas.dodge / 100, 1e-9, "회피 10%")
	local view = Hero.view(hn)
	near(view.run, 1 + pas.run / 100, 1e-9, "화면에 걸음의 배수가 간다")
	near(view.jump, 1 + pas.jump / 100, 1e-9, "화면에 뛰는 힘의 배수가 간다")
	local roomN = Room.new("hunt", SCENES.scenes.hunt, Random.new(5))
	local dodged, hurt = 0, 0
	for _ = 1, 1000 do
		hn.invuln, hn.hp, hn.alive = 0, hn.maxHp, true
		local events = {}
		roomN:hurtHero(events, hn, roomN.mobs[1], 1)
		if events[1].type == "dodge" then
			dodged += 1
			expect(hn.hp == hn.maxHp and hn.invuln > 0, "피하면 체력이 그대로이고, 잠깐은 다시 맞지 않는다")
		else
			hurt += 1
		end
	end
	expect(dodged > 60 and dodged < 140 and dodged + hurt == 1000, ("열 번에 한 번 피한다 — %d / 1000"):format(dodged))
end

-- ---- 5) 리퍼: 사신 게이지 · 사신화 · 혼불 · 생기 흡수 ----
do
	local core, tg, pas = KIT.reaper.core, KIT.reaper.toggle, KIT.reaper.passive
	local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
	local G = core.gauge
	-- 사신 게이지(2026-10-31 사용자: "게이지 직업으로 설계하자 메이플 루미너스 처럼 사신화가 1차부터 있고 사신 게이지가 있어 …"):
	--  낫 기술이 맞으면 hit · 쓰러뜨리면 kill(차수의 배수 — 전직할수록 빨리) · 가득하면 멈춘다 · 공격력은 오르지 않는다 · 저절로 줄지 않는다
	local room, h, a, b0 = arena("reaper", { rp_soul = 10 })
	b0.x = 1430
	h.job = 1
	local out = strike(room, h, "rp_hook", 2, nil)
	near(h.kit.gauge, G.hit * G.job[1], 1e-6, "맞히면 +hit(1차)")
	expect(out.kit == true, "화면에 알린다")
	a.state, a.t, a.hp = "idle", 0, 1
	local g0 = h.kit.gauge
	strike(room, h, "rp_hook", 2, nil)
	near(h.kit.gauge, g0 + (G.hit + G.kill) * G.job[1], 1e-6, "쓰러뜨리면 +kill이 더")
	h.job = 4
	a.state, a.t, a.hp = "idle", 0, 1e12
	local g1 = h.kit.gauge
	strike(room, h, "rp_hook", 2, nil)
	near(h.kit.gauge - g1, G.hit * G.job[4], 1e-6, "4차는 그 배수만큼 빨리 찬다")
	expect(G.job[1] < G.job[2] and G.job[2] < G.job[3] and G.job[3] < G.job[4], "전직할수록 빨리")
	h.kit.gauge = G.max - 0.5
	strike(room, h, "rp_hook", 2, nil)
	eq(h.kit.gauge, G.max, "가득하면 멈춘다")
	eq(Kit.view(h).gauge, G.max, "화면에 게이지가 간다")
	near(Kit.attack(h), 1, 1e-9, "게이지는 공격력을 올리지 않는다(세지는 것은 사신화)")
	Kit.tick(h, 999)
	eq(h.kit.gauge, G.max, "저절로 줄지 않는다")
	-- 사신화: 1차부터 처음부터 준다 · 게이지가 가득할 때만 · 쓰면 게이지가 빈다 · 시간은 차수마다
	eq(Hero.skillLevel(Hero.new(9, "reaper"), "rp_form"), 1, "사신화는 1차부터(처음부터 준다)")
	expect(Kit.formReady(h), "가득하면 사신화를 쓸 수 있다")
	local pow = Buffs.cast(h, "rp_form", 0)
	expect(pow ~= nil and Kit.formed(h), "사신으로 변한다")
	eq(h.kit.gauge, 0, "게이지가 빈다")
	near(h.buffs.rp_form.t, core.form.dur[4], 1e-6, "4차 = " .. core.form.dur[4] .. "초")
	expect(not Kit.gainGauge(h, "hit"), "사신화 동안에는 차지 않는다")
	local outF = strike(room, h, "rp_hook", 2, nil)
	expect(#procs(outF, "shade") >= 1, "사신화: 맞을 때마다 그림자 낫")
	expect(math.abs(procs(outF, "shade")[1].dmg / mains(outF)[1].dmg - core.form.shade) < 0.05, "그림자 낫 = 그 타 피해의 절반")
	h.buffs.rp_form = nil
	h.kit.gauge = 50
	eq(Buffs.cast(h, "rp_form", 0), nil, "게이지가 덜 차면 사신화를 못 쓴다")
	local h1 = Hero.new(8, "reaper")
	h1.kit.gauge = G.max
	Buffs.cast(h1, "rp_form", 0)
	near(h1.buffs.rp_form.t, core.form.dur[1], 1e-6, "1차 = " .. core.form.dur[1] .. "초")
	-- 피해에 들어간다(같은 씨앗의 방 둘): 사신화 = 피해 +40%
	local roomA, hA = arena("reaper", { rp_soul = 10 }, 21)
	local roomB, hB = arena("reaper", { rp_soul = 10 }, 21)
	hB.kit.gauge = G.max
	Buffs.cast(hB, "rp_form", 0)
	near(mains(strike(roomB, hB, "rp_hook", 2, nil))[1].dmg / mains(strike(roomA, hA, "rp_hook", 2, nil))[1].dmg, 1.4, 0.02, "사신화: 피해 +40%")

	-- 도깨비불: 2초에 한 번, 맞은 적에게 — 초당 피해의 18%(한 번에 0.36초 치)
	local roomW, hW, aW = arena("reaper", { rp_wisp = 10 })
	Kit.toggle(hW)
	local w1 = procs(strike(roomW, hW, "rp_double", 1, nil), "wisp")
	eq(#w1, 1, "낫질이 맞으면 도깨비불이 난다")
	eq(w1[1].mob, aW.id, "맞은 적에게")
	local want = Hero.powerRaw(hW) * N.data.POWER.dps * tg.cd * tg.rate * RULES.dmgScale * (1 + RULES.targetBonus / 100)
	expect(w1[1].dmg >= want * 0.89 and w1[1].dmg <= want * 1.11, ("도깨비불의 피해 = 전투력 x 초당 피해 x 2초 x 18%% — %d(기대 %.1f)"):format(w1[1].dmg, want))
	near(tg.mul, N.data.POWER.dps * tg.cd * tg.rate, 1e-3, "내보낸 배수 = 초당 피해 x 2초 x 18%")
	eq(#procs(strike(roomW, hW, "rp_double", 2, nil), "wisp"), 0, "2초 안에는 다시 나지 않는다")
	roomW.time += tg.cd - 0.1
	eq(#procs(strike(roomW, hW, "rp_double", 1, nil), "wisp"), 0, "1.9초")
	roomW.time += 0.1
	eq(#procs(strike(roomW, hW, "rp_double", 1, nil), "wisp"), 1, "2초가 지나면 다시 난다")

	-- 생기 흡수(2026-10-31 사용자: "피흡도 처치시 흡혈로 해서 보스전에서는 흡혈효율이 좋지않은데 사냥에서는 흡혈 잘되게"): 맞히기만 해서는 되찾지 않는다 · 쓰러뜨릴 때마다 최대 체력의 kill%
	local roomD, hD, aD, bD = arena("reaper", { rp_drain = 10 })
	bD.x = X + 30 -- 둘이 같이 맞는다
	hD.hp = math.floor(hD.maxHp / 2)
	local hp0 = hD.hp
	local outD = strike(roomD, hD, "rp_double", 1, nil)
	eq(#mains(outD), 2, "둘이 맞는다")
	eq(outD.heal, nil, "맞히기만 해서는 되찾지 않는다(보스전에서는 흡혈이 거의 없다)")
	eq(hD.hp, hp0, "체력 그대로")
	aD.hp, bD.hp = 1, 1 -- 한 대에 쓰러진다
	local outK = strike(roomD, hD, "rp_double", 1, nil)
	local healWant = math.max(1, math.floor(hD.maxHp * pas.kill / 100 + 0.5))
	expect(#outK.kills == 2 and outK.heal == healWant * 2 and hD.hp == hp0 + healWant * 2, ("둘을 쓰러뜨리면 둘만큼 — 한 마리에 최대 체력의 %d%% (%s)"):format(pas.kill, tostring(outK.heal)))
end

-- ---- 6) 무니: 수정 공명 · 수정 조각 · 지키는 마음 ----
do
	local core, tg, pas = KIT.mooni.core, KIT.mooni.toggle, KIT.mooni.passive
	local room, h, a = arena("mooni", { mn_reson = 10 })
	-- 대검이 맞으면 30% 확률로 맞은 적의 발밑에 수정
	local grown, n = 0, 400
	for _ = 1, n do
		room.crystals = {}
		local out = strike(room, h, "mn_thrust", 1, nil)
		if out.crystals then
			grown += 1
			eq(#room.crystals, 1, "수정 하나")
			local c = out.crystals[1]
			expect(c.owner == h.id and math.abs(c.x - a.x) <= 4 and c.y == a.y and c.life == core.life, "맞은 적의 발밑에 20초")
		end
	end
	expect(grown > n * 0.22 and grown < n * 0.38, ("수정이 맺힐 확률 30%% — %d / %d"):format(grown, n))
	-- 둘까지: 셋째가 서면 가장 오래된 것이 사라진다 · 너무 가까우면 서지 않는다
	room.crystals = {}
	local out = { hits = {}, kills = {} }
	room:addCrystal(h, 100, Y, out)
	room:addCrystal(h, 105, Y, out)
	eq(#room.crystals, 1, "18도트 안에는 또 서지 않는다")
	room:addCrystal(h, 200, Y, out)
	local firstId = room.crystals[1].id
	room:addCrystal(h, 400, Y, out)
	expect(#room.crystals == core.max and out.crystalGone ~= nil and out.crystalGone[1] == firstId and room.crystals[1].x == 200, "셋째가 서면 가장 오래된 것이 사라진다")
	eq(#out.crystals, 3, "생긴 수정을 모두 알린다")
	-- 때가 되면 사라진다
	local gone = 0
	for _, e in room:step({}, core.life + 0.1) do
		if e.type == "crystalGone" then
			gone += 1
		end
	end
	expect(gone == 2 and #room.crystals == 0, "20초 뒤에 사라진다")
	-- 공명: 수정 곁(96도트 안)에서 쓴 대검은 수정에서도 같은 범위로 한 번 더 — 수정 하나가 그 타의 12%
	local roomR, hR, aR, bR = arena("mooni", { mn_reson = 10 }, 31)
	bR.x = X + 60 + 30 -- 수정의 앞: 수정에서 나간 찌르기에 맞는 자리
	local mine = { id = 901, owner = hR.id, x = X + 60, y = Y, till = roomR.time + 99 }
	local sum, sumMain, count = 0, 0, 0
	for _ = 1, 200 do
		roomR.crystals = { mine } -- 치다가 새로 맺힌 수정은 치운다(하나만 두고 잰다)
		local o = strike(roomR, hR, "mn_thrust", 1, nil)
		local res = procs(o, "reson")
		expect(#res >= 1, "수정에서도 나간다")
		for _, e in res do
			expect(e.sx == X + 60 and e.sy == Y and e.big == nil, "수정의 자리에서 나간다(센 타로 뜨지 않는다)")
			if e.mob == bR.id then
				sum += e.dmg
				count += 1
			end
		end
		for _, e in mains(o) do
			if e.mob == aR.id then
				sumMain += e.dmg
			end
		end
	end
	eq(count, 200, "수정 앞의 적이 매번 맞는다")
	near(sum / sumMain, core.share, 0.04, "수정 하나가 그 타 피해의 12%")
	roomR.crystals = { mine }
	mine.x = X + core.near + 5
	eq(#procs(strike(roomR, hR, "mn_thrust", 1, nil), "reson"), 0, "수정에서 96도트보다 멀면 공명하지 않는다")
	roomR.crystals = { mine }
	mine.x, mine.owner = X + 60, 999
	eq(#procs(strike(roomR, hR, "mn_thrust", 1, nil), "reson"), 0, "남의 수정은 공명하지 않는다")

	-- 수정 조각: 1.5초에 한 번, 내 수정마다 하나(없으면 대검에서 하나) — 조각 하나가 초당 피해의 10%
	local roomT, hT, aT = arena("mooni", { mn_shard = 10 })
	Kit.toggle(hT)
	local s1 = procs(strike(roomT, hT, "mn_thrust", 1, nil), "shard")
	eq(#s1, 1, "수정이 없으면 대검에서 하나")
	local wantS = Hero.powerRaw(hT) * N.data.POWER.dps * tg.cd * tg.rate * RULES.dmgScale * (1 + RULES.targetBonus / 100)
	expect(s1[1].dmg >= wantS * 0.89 and s1[1].dmg <= wantS * 1.11 and s1[1].mob == aT.id, ("조각의 피해 = 전투력 x 초당 피해 x 1.5초 x 10%% — %d(기대 %.1f)"):format(s1[1].dmg, wantS))
	eq(#procs(strike(roomT, hT, "mn_thrust", 1, nil), "shard"), 0, "1.5초 안에는 다시 나가지 않는다")
	roomT.time += tg.cd
	table.insert(roomT.crystals, { id = 902, owner = hT.id, x = X - 40, y = Y, till = roomT.time + 99 })
	table.insert(roomT.crystals, { id = 903, owner = hT.id, x = X + 50, y = Y, till = roomT.time + 99 })
	local s2 = procs(strike(roomT, hT, "mn_thrust", 1, nil), "shard")
	expect(#s2 == 2 and s2[1].sx == X - 40 and s2[2].sx == X + 50, "수정이 둘이면 조각도 둘(수정에서 날아간다)")

	-- 지키는 마음: 받는 피해 -10% · 내 수정 곁에서는 -20%
	local ho = Hero.new(6, "mooni")
	ho.skills.mn_oath = 10
	near(Kit.cut(ho, false), 1 - pas.cut / 100, 1e-9, "받는 피해 -10%")
	near(Kit.cut(ho, true), 1 - pas.cut / 100 * pas.nearMul, 1e-9, "수정 곁에서는 -20%")
	local roomO = Room.new("hunt", SCENES.scenes.hunt, Random.new(5))
	roomO.mobs[1].lv = 100 -- 한 방이 넉넉히 큰 졸개로 잰다(작은 수는 반올림에 묻힌다)
	local plainHero = Hero.new(7, "mooni")
	for _, x in { ho, plainHero } do
		x.level = 100
		Hero.recalc(x)
		x.hp, x.x, x.y = x.maxHp, X, Y
	end
	local function hitOnce(who)
		who.invuln, who.hp = 0, who.maxHp
		local events = {}
		roomO:hurtHero(events, who, roomO.mobs[1], 1)
		return events[1].dmg
	end
	local base = hitOnce(plainHero)
	near(hitOnce(ho) / base, 0.9, 0.03, "맞으면 10% 덜 아프다")
	expect(not roomO:nearCrystal(ho), "수정이 없다")
	table.insert(roomO.crystals, { id = 904, owner = ho.id, x = X + 30, y = Y, till = 99 })
	expect(roomO:nearCrystal(ho) and not roomO:nearCrystal(plainHero), "내 수정 곁이다")
	near(hitOnce(ho) / base, 0.8, 0.03, "수정 곁에서는 20% 덜 아프다")
end

-- ---- 7) 살라맨더: 열기 · 불티 · 뜨거운 피 ----
do
	local core, tg, pas = KIT.salamander.core, KIT.salamander.toggle, KIT.salamander.passive
	local room, h, a = arena("salamander", { sl_heat = 10 })
	-- 판을 나누지 않고 친 타(opts 없이)는 맞을 때마다 열기 + gain(2026-11-04 — 게임의 판은 한 번: 아래), 50부터 달아오름: 맞힐 때마다 불꽃이 한 번 더(그 타의 20%)
	local each = core.gain
	local hits = math.ceil(core.max / each) + 1
	for i = 1, hits do
		local out = strike(room, h, "sl_punch", 1, nil)
		near(h.kit.heat, math.min(core.max, i * each), 1e-6, ("열기 %d"):format(i))
		expect(out.kit == true, "열기가 올랐다고 알린다")
		local flames = procs(out, "flame")
		if i * each >= core.hot then
			expect(#flames == 1 and flames[1].mob == a.id and flames[1].dmg == math.max(1, math.floor(mains(out)[1].dmg * core.share + 0.5)), ("달아오르면 불꽃이 한 번 더 %d"):format(i))
		else
			eq(#flames, 0, ("아직 달아오르지 않았다 %d"):format(i))
		end
	end
	expect(Kit.hot(h) and Kit.view(h).hot == true and Kit.view(h).heat == core.max, "달아올랐다")
	-- cool초(6) 동안 못 맞히면 초마다 decay(15)씩 식는다(2026-11-03 — 그 전 3초 · 25)
	local changed = Kit.tick(h, core.cool - 0.5)
	expect(not changed and h.kit.heat == core.max, "식기 시작하는 때 전에는 식지 않는다")
	Kit.tick(h, 0.5)
	Kit.tick(h, 1)
	near(h.kit.heat, core.max - core.decay, 1e-6, "그 뒤로는 초마다 decay씩 식는다")
	local flipped = false
	for _ = 1, 100 do
		local c = Kit.tick(h, 0.1)
		flipped = flipped or (c and not Kit.hot(h))
	end
	expect(flipped and h.kit.heat == 0, "식으면 달아오름이 풀린다(풀릴 때 알린다)")
	strike(room, h, "sl_punch", 1, nil)
	eq(h.kit.heatT, 0, "맞히면 식는 시간을 다시 센다")
	a.x = 1400
	local heat0 = h.kit.heat
	strike(room, h, "sl_punch", 1, nil)
	eq(h.kit.heat, heat0, "못 맞히면 오르지 않는다")
	-- 한 판에 한 번(2026-11-04 사용자 "게이지도 3타정도 치면 4번째 공격이 강화공격으로"): 같은 판(opts)의 둘째 타는 열기를 채우지 않는다 · 세 판이면 가득 · 차수와 상관없다
	a.x = X + 14
	local job0 = h.job
	h.job, h.kit.heat = 4, 0
	for i = 1, 3 do
		local cast = { mul = 1, reach = 0, level = 0 }
		strike(room, h, "sl_punch", 1, cast)
		strike(room, h, "sl_punch", 2, cast)
		near(h.kit.heat, math.min(core.max, i * core.gain), 1e-6, ("한 판에 한 번 — %d판"):format(i))
	end
	eq(h.kit.heat, core.max, "세 판이면 가득(넷째가 강화판)")
	-- 폭주 동안은 서버의 열기도 가득한 채 고정(2026-11-03 — 열기 폭발이 서버의 열기를 쓴다)
	h.buffs.sl_overheat = { t = 20, dur = 20 }
	h.kit.heat = 10
	Kit.tick(h, 0.1)
	eq(h.kit.heat, core.max, "폭주 동안 열기 가득")
	h.buffs.sl_overheat = nil
	h.job, h.kit.heat = job0, 0

	-- 강화판(2026-11-04 사용자 "게이지를 가득채우면 불길에 휩싸이면서 사냥기, 보스기 가 강화되고 강화된 스킬들은 퀵슬롯에서 빛나는거야 그리고 그 스킬을 사용하면 열기가 모두 소모되면서
	--  원래스킬이아니라 더 강력한 스킬이 나가는거라고"): 열기가 가득(폭주면 늘) 찬 채 쓴 사냥기 · 보스기의 판 = Kit.empower — 열기를 모두 쓰고(용광로 심장이면 enhAfter에서) 그 판의 모든 타 x (1 + x[차수] x 열기의 세기 + 패시브의 enh).
	--  화면이 그리지 않은 판(want false) · 사냥기도 보스기도 아닌 것 · 덜 찬 열기는 강화하지 않는다(열기 그대로). 강화판의 타는 열기를 채우지 않는다(kitAfter의 opts.enh)
	do
		local enh = core.enh
		local roomB, hB, aB, bB = arena("salamander", { sl_heat = 10 })
		hB.kit.heat = core.max - 1
		eq(Kit.empower(hB, "boss", nil), nil, "덜 찼으면 강화판이 아니다")
		eq(hB.kit.heat, core.max - 1, "열기 그대로")
		hB.kit.heat = core.max
		eq(Kit.empower(hB, "boss", false), nil, "화면이 강화판으로 그리지 않은 판은 강화하지 않는다")
		eq(Kit.empower(hB, "attack", nil), nil, "공격기(화룡 승천)는 강화판이 없다")
		eq(Kit.empower(hB, "nuke", true), nil, "큰 기술(화산권)은 강화판이 없다")
		eq(hB.kit.heat, core.max, "그동안 열기는 가득한 채")
		local mul = Kit.empower(hB, "mob", true)
		near(mul or 0, 1 + enh.x[1] * Kit.scale(hB, "core"), 1e-9, "1차 사냥기의 강화판 = 1 + x[1] x 열기의 세기")
		eq(hB.kit.heat, 0, "열기를 모두 썼다")
		-- 1차의 판(skillHit의 opts): 같은 타가 그 배수만큼 세고, 열기를 채우지 않는다
		hB.kit.heat = 0
		local base = mains(strike(roomB, hB, "sl_punch", 1, nil))[1].dmg
		local heat1 = hB.kit.heat
		hB.kit.heat = 0
		local boosted = mains(strike(roomB, hB, "sl_punch", 1, { mul = mul, reach = 0, level = 0, enh = true }))[1].dmg
		near(boosted / base, mul, RULES.spread / 50 + 0.02, "강화판의 타 = 보통 타 x 배수")
		expect(heat1 > 0 and hB.kit.heat == 0, "보통 타는 열기를 채우고 강화판의 타는 채우지 않는다")
		-- 1차 강화판의 범위(core.enh.first): 불덩이 던지기(2026-11-04 1차 사냥기)는 앞으로 60 더 · 위로 3배 — 보통 판이 못 닿는 자리(앞 180 · 위 40)의 적이 맞는다
		local far = enh.first.sl_meteor
		local keepX, keepY, keepB = aB.x, aB.y, bB.x
		aB.x, aB.y, bB.x = hB.x + 180, hB.y - 40, hB.x + 1200
		eq(#mains(strike(roomB, hB, "sl_meteor", 1, nil)), 0, "보통 불덩이 던지기는 앞 180 · 위 40에 닿지 않는다")
		expect(#mains(strike(roomB, hB, "sl_meteor", 1, { mul = 1, reach = far.reach, tall = far.up, level = 0, enh = true })) == 1, "강화판 불덩이 던지기는 닿는다")
		aB.x, aB.y, bB.x = keepX, keepY, keepB
		-- 4차 · 패시브(폭열 · 용광로 심장 · 백열 — 다 마스터): 배수 + 셋의 enh · 쓴 뒤 열기 enhAfter
		local P = COMBAT.passive
		hB.skills.sl_vent, hB.skills.sl_furnace, hB.skills.sl_sun = 10, 10, 15
		hB.job = 4
		Hero.recalc(hB)
		hB.kit.heat = core.max
		mul = Kit.empower(hB, "boss", nil)
		near(mul or 0, 1 + enh.x[4] * Kit.scale(hB, "core") + P.sl_vent.fx.enh + P.sl_furnace.fx.enh + P.sl_sun.fx.enh, 1e-9, "4차의 강화판 = 1 + x[4] x 열기의 세기 + 폭열 + 용광로 심장 + 백열")
		eq(hB.kit.heat, P.sl_furnace.fx.enhAfter, "용광로 심장: 쓴 뒤 열기 " .. P.sl_furnace.fx.enhAfter .. "에서")
		-- 폭주: 열기가 가득한 채 — 쓸 때마다 강화판 · 열기는 그대로
		hB.buffs.sl_overheat = { t = 20, dur = 20, pow = 1 }
		hB.kit.heat = 10
		expect(Kit.empower(hB, "mob", nil) ~= nil and Kit.empower(hB, "boss", nil) ~= nil, "폭주 동안은 덜 찼어도 늘 강화판")
		eq(hB.kit.heat, 10, "폭주 동안은 열기를 쓰지 않는다(Kit.tick이 가득으로 고정한다)")
		hB.buffs.sl_overheat = nil
		-- 다른 직업은 강화판이 없다
		local _, hR = arena("reaper", {})
		eq(Kit.empower(hR, "boss", true), nil, "리퍼는 강화판이 없다")
		-- 2~4차의 판(Caster:begin): 가득 찬 채 시작하면 ctx.enh · g.s.enh · 열기를 쓴다 / 화면이 false면 그대로
		local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
		local roomC, hC = arena("salamander", { sl_heat = 10, sl_slam = 20 })
		hC.job = 2
		hC.kit.heat = core.max
		local cast = Caster.new(roomC)
		local ok, _, began = cast:begin(hC, "sl_slam", 1, nil, { hot = false })
		expect(ok and began == false and hC.kit.heat == core.max, "화면이 그리지 않은 판: 보통으로 · 열기 그대로")
		cast:drop(hC)
		ok, _, began = cast:begin(hC, "sl_slam", 1, nil, { hot = true })
		local act = cast.actors[hC]
		expect(ok and began == true and act.skill.ctx.enh ~= nil and rawget(act.g.s, "enh") == true and hC.kit.heat == 0, "가득 찬 채 시작한 화염 강타 = 강화판(ctx.enh · g.s.enh) · 열기를 썼다")
		near(act.skill.ctx.enh, 1 + enh.x[2] * Kit.scale(hC, "core"), 1e-9, "2차의 배수")
	end

	-- 불티: 주먹이 맞을 때마다 가까운 다른 적(없으면 그 적)에게 — 그 타 피해의 18%
	local roomE, hE, aE, bE = arena("salamander", { sl_ember = 10 })
	Kit.toggle(hE)
	bE.x = X + 120
	for _ = 1, 20 do
		local out = strike(roomE, hE, "sl_punch", 1, nil)
		local list = procs(out, "ember")
		expect(#list == 1 and list[1].mob == bE.id and list[1].dmg == math.max(1, math.floor(mains(out)[1].dmg * tg.share + 0.5)), "맞을 때마다 불티가 다른 적에게")
	end
	bE.x = 1400
	local alone = procs(strike(roomE, hE, "sl_punch", 1, nil), "ember")
	expect(#alone == 1 and alone[1].mob == aE.id, "다른 적이 없으면 그 적에게")
	-- 사출기의 타는 사출기를 다시 부르지 않는다
	eq(#strike(roomE, hE, "sl_punch", 1, nil).hits, 2, "제 타 하나 + 불티 하나뿐")

	-- 뜨거운 피: 초마다 최대 체력의 regen%(2026-10-23 0.5 → 0.3 — 피흡 너프) · 달아오름 동안 걸음 +10%
	local hb = Hero.new(8, "salamander")
	hb.level = 30
	hb.skills.sl_blood, hb.skills.sl_heat = 10, 10
	Hero.recalc(hb)
	hb.hp = math.floor(hb.maxHp / 2)
	local hp0, healedSum = hb.hp, 0
	for _ = 1, 100 do
		local _, healed = Kit.tick(hb, 0.1)
		healedSum += healed
	end
	near(healedSum + hb.kit.regen, hb.maxHp * pas.regen / 100 * 10, 0.05, ("10초에 최대 체력의 %s%%(찬 것 + 아직 1 못 채운 나머지)"):format(tostring(pas.regen * 10)))
	eq(hb.hp, hp0 + healedSum, "체력이 찬다")
	hb.hp = hb.maxHp
	eq(select(2, Kit.tick(hb, 5)), 0, "가득하면 차지 않는다")
	expect((Kit.move(hb)) == 1, "식어 있으면 걸음 그대로")
	hb.kit.heat = core.hot
	near((Kit.move(hb)), 1 + pas.run / 100, 1e-9, "달아오름 동안 걸음 +10%")
end

-- ---- 8) 켜 둔 것은 저장된다 · 퀵슬롯에 놓인다 ----
do
	local Quick = req("ReplicatedStorage/shared/lune/ui/quick")
	for _, class in CLASSES.order do
		local id = KIT[class].toggle.id
		local h = Hero.new(9, class)
		h.level = 10 -- 스킬 포인트를 받은 레벨(받은 것보다 많이 찍힌 저장은 스킬을 되돌린다)
		expect(not Hero.canSlot(h, id), "배우지 않은 사출기는 칸에 놓지 못한다 " .. class)
		h.skills[id] = 1
		expect(Hero.canSlot(h, id), "배운 사출기는 칸에 놓는다 " .. class)
		expect(not Hero.canSlot(h, KIT[class].core.id) and not Hero.canSlot(h, KIT[class].passive.id), "장치 · 패시브는 칸에 놓지 않는다 " .. class)
		local placed = Quick.place(h.slots, id, 6)
		expect(placed ~= nil and Hero.setSlots(h, placed) and h.slots[6] == id, "퀵슬롯에 놓인다 " .. class)
		eq(Kit.toggle(h), true, "켠다 " .. class)
		expect(Hero.view(h).kit.on == true and Hero.pack(h).kitOn == true, "켠 것이 화면과 저장에 실린다 " .. class)
		local back = Hero.unpack(9, Hero.pack(h))
		expect(back ~= nil and back.kit.on == true and back.slots[6] == id, "다시 들어와도 켜져 있고 칸에 그대로다 " .. class)
		local saved = Hero.pack(h)
		saved.skills[id] = nil
		expect(Hero.unpack(9, saved).kit.on == false, "배우지 않은 사출기는 켜진 채로 되살아나지 않는다 " .. class)
		for _, other in CLASSES.order do
			if other ~= class then
				expect(not Hero.canSlot(h, KIT[other].toggle.id), "다른 직업의 사출기는 놓지 못한다")
			end
		end
	end
end

-- ---- 사출기 강화(2~4차 패시브 — COMBAT.kitUp): 하나 더 · 번지고 튕기고 · 더 자주 더 세게 ----
do
	local UP = COMBAT.kitUp
	-- 그 타의 기록을 갈래로 센다
	local function count(out, kind)
		local n, sum, list = 0, 0, {}
		for _, e in out.hits do
			if e.proc == kind then
				n += 1
				sum += e.dmg
				table.insert(list, e)
			end
		end
		return n, sum, list
	end
	-- 액시온(2026-10-28 리마스터 — 모두 끝까지 모아 친 한 방에만): 무거운 메아리(도끼의 피해 +) · 울리는 메아리(둘레로 번진다) · 만근(한 단계 더 · 더 세게)
	do
		local room, h, a, b = arena("axion", { ax_echo = 10, ax_echo2 = 10, ax_echo3 = 10 })
		h.level = 120
		h.kit.on = true
		b.x = a.x + 10 -- 옆에 붙은 졸개(번지는 범위 안 · 내려찍기에도 맞는다)
		local out = strike(room, h, "ax_combo", 1, { mul = 1, reach = 0, level = Kit.chargeLevels(h) })
		local n, _, list = count(out, "echo")
		eq(n, #mains(out), "맞은 적마다 도끼 하나")
		local mainA, echoA = nil, nil
		for _, e in out.hits do
			if not e.proc and e.mob == a.id then
				mainA = e.dmg
			end
		end
		for _, e in list do
			if e.mob == a.id then
				echoA = e.dmg
			end
			eq(e.up, 3, "배운 강화를 같이 알린다(무거운 메아리 + 번짐)")
		end
		expect(mainA ~= nil and echoA ~= nil, "그 적에게 떨어진다")
		if mainA and echoA then
			near(echoA / mainA, KIT.axion.toggle.share * (1 + UP.axion.two.share), 0.02, "무거운 메아리: 도끼의 피해 +50%")
		end
		expect((count(out, "splash")) >= 1, "울리는 메아리: 옆의 졸개에게 번진다")
		-- 만근: 힘 모으기 한 단계 더 · 도끼 더 세게
		local room2, h2 = arena("axion", { ax_echo = 10, ax_echo4 = 10 })
		h2.level = 120
		h2.kit.on = true
		eq(Kit.chargeLevels(h2), KIT.axion.core.levels + UP.axion.fast.levels, "만근: 힘 모으기 한 단계 더")
		eq((count(strike(room2, h2, "ax_combo", 1, { mul = 1, reach = 0, level = KIT.axion.core.levels }), "echo")), 0, "만근이면 그 전의 끝 단계로는 모자란다")
		local out2 = strike(room2, h2, "ax_combo", 1, { mul = 1, reach = 0, level = Kit.chargeLevels(h2) })
		local m2, e2 = mains(out2)[1], select(3, count(out2, "echo"))[1]
		expect(m2 ~= nil and e2 ~= nil, "만근: 끝까지 모으면 떨어진다")
		if m2 and e2 then
			near(e2.dmg / m2.dmg, KIT.axion.toggle.share * (1 + UP.axion.fast.more), 0.02, "만근: 도끼의 데미지 +30%")
		end
	end
	-- 리븐: 쌍표창 · 되돌아오는 표창 · 피의 표창(확률이 70%까지)
	do
		local room, h, a, b = arena("riven", { rv_star = 10, rv_mark = 10, rv_star2 = 10, rv_star3 = 10, rv_star4 = 10 })
		h.level = 120
		h.kit.on = true
		local casts, stars, hops = 0, 0, 0
		for _ = 1, 300 do
			local out = strike(room, h, "rv_double", 1)
			local n, _, list = count(out, "star")
			if n > 0 then
				casts += 1
			end
			for _, e in list do
				if e.hop then
					hops += 1
				else
					stars += 1
				end
			end
		end
		near(casts / 300, UP.riven.fast.chance / 100, 0.12, "피의 표창: 마스터에 70%")
		near(stars / casts, 2, 0.05, "쌍표창: 나갈 때마다 둘")
		expect(hops >= casts, "되돌아오는 표창: 튕긴다 " .. hops)
	end
	-- 리퍼: 떼혼불(사신 게이지 34마다 하나 더 · 사신화 동안 넷 — 2026-10-31 게이지 직업 · 그 전: 영혼 둘마다) · 붙는 불(초마다 태운다) · 원혼(더 자주)
	do
		local room, h, a = arena("reaper", { rp_wisp = 10, rp_soul = 10, rp_wisp2 = 10, rp_wisp3 = 10 })
		h.level = 120
		h.kit.on = true
		h.kit.gauge = 70
		local out = strike(room, h, "rp_double", 1)
		local n = count(out, "wisp")
		eq(n, 3, "떼혼불: 게이지 70이면 세 발")
		-- 붙는 불: 1 · 2 · 3초 뒤에 한 번씩 더 탄다(방의 한 걸음이 알린다)
		local burns = 0
		for _ = 1, 3 * 20 + 4 do
			for _, e in room:step({}, 1 / 20) do -- 졸개가 덤비지 않게 사람 없이 돌린다(폭탄병은 다가와 터지면 사라진다)
				if e.type == "kit" then
					burns += (count(e.result, "burn"))
				end
			end
			a.state = "idle" -- 맞고 멈칫한 것을 풀어 둔다
		end
		eq(burns, 3 * UP.reaper.burn.ticks, "붙는 불: 세 발이 저마다 세 번 태운다")
		local room2, h2 = arena("reaper", { rp_wisp = 10, rp_wisp4 = 10 })
		h2.level = 120
		h2.kit.on = true
		strike(room2, h2, "rp_double", 1)
		room2.time += 1.05
		eq((count(strike(room2, h2, "rp_double", 1), "wisp")), 1, "원혼: 1초 뒤에 또 나간다")
	end
	-- 무니: 쌍조각 · 꿰뚫는 조각
	do
		local room, h, a, b = arena("mooni", { mn_shard = 10, mn_shard2 = 10, mn_shard3 = 10 })
		h.level = 120
		h.kit.on = true
		b.x = a.x + 40 -- 맞은 적 뒤에 선 졸개
		local out = strike(room, h, "mn_thrust", 1)
		eq((count(out, "shard")), 2, "쌍조각: 조각 둘")
		expect((count(out, "pierce")) >= 1, "꿰뚫는 조각: 뒤의 졸개도 맞는다")
	end
	-- 살라맨더: 겹불티(달아오름 동안 하나 더) · 옮겨붙는 불티 · 불새(더 세게)
	do
		local room, h, a, b = arena("salamander", { sl_ember = 10, sl_heat = 10, sl_ember2 = 10, sl_ember3 = 10 })
		h.level = 120
		h.kit.on = true
		b.x = a.x + 2000 -- 한 마리만 맞게
		local cold = strike(room, h, "sl_punch", 1)
		eq((count(cold, "ember")), 1, "식어 있을 때는 불티 하나")
		h.kit.heat = 100
		local hot = strike(room, h, "sl_punch", 1)
		local n, _, list = count(hot, "ember")
		eq(n, 2, "겹불티: 달아오름 동안 둘")
		b.x = a.x + 60 -- 옆의 졸개: 옮겨붙는다
		local hop = 0
		for _, e in strike(room, h, "sl_punch", 1).hits do
			if e.proc == "ember" and e.hop then
				hop += 1
			end
		end
		expect(hop >= 1, "옮겨붙는 불티 " .. hop)
	end
end
