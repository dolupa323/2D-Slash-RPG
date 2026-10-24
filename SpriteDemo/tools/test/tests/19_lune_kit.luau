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
	-- 바로 앞의 적 하나를 서른 번 치면 메아리 도끼가 꼭 열 번(세 번째 타마다) — 그 타 피해의 60%
	local echoes = 0
	for i = 1, 30 do
		local out = strike(room, h, "ax_combo", 1, nil)
		local main, list = mains(out), procs(out, "echo")
		eq(#main, 1, "한 마리가 맞는다")
		eq(#list, if i % tg.every == 0 then 1 else 0, ("도끼질 %d번째"):format(i))
		if #list == 1 then
			echoes += 1
			eq(list[1].mob, a.id, "그 적에게 떨어진다")
			eq(list[1].dmg, math.max(1, math.floor(main[1].dmg * tg.share + 0.5)), "그 타 피해의 60%")
			expect(list[1].sy < a.y - 30 and math.abs(list[1].sx - a.x) <= 4, "머리 위에서 떨어진다(맞고 조금 밀린 그 자리)")
		end
	end
	eq(echoes, 10, "서른 타에 열 번")
	eq(Kit.toggle(h), false, "끈다")
	for _ = 1, 9 do
		eq(#procs(strike(room, h, "ax_combo", 1, nil), "echo"), 0, "꺼 두면 나가지 않는다")
	end
	-- 레벨 1이면 40%의 세기(60% x 0.4 = 24%)
	local room1, h1 = arena("axion", { ax_echo = 1 })
	Kit.toggle(h1)
	local got = nil
	for _ = 1, 3 do
		local out = strike(room1, h1, "ax_combo", 1, nil)
		if #procs(out, "echo") == 1 then
			got = { mains(out)[1].dmg, procs(out, "echo")[1].dmg }
		end
	end
	expect(got ~= nil and got[2] == math.max(1, math.floor(got[1] * tg.share * FLOOR + 0.5)), "레벨 1의 메아리 도끼는 그 타의 24%")
	-- 메아리 도끼로 쓰러뜨려도 잡은 것이다(경험치 · 떨어지는 것)
	local roomK, hK, aK = arena("axion", { ax_echo = 10 })
	Kit.toggle(hK)
	hK.kit.n = 2 -- 다음 타가 세 번째
	local xp0 = hK.xp + hK.level * 1e9
	local trial = strike(roomK, hK, "ax_combo", 1, nil)
	expect(#procs(trial, "echo") == 1, "세 번째 타에 떨어진다")
	hK.kit.n = 2
	aK.hp = mains(trial)[1].dmg * 3 -- 제 타로는 안 쓰러지고 메아리 도끼로 쓰러지게
	local outK = nil
	for _ = 1, 20 do
		hK.kit.n = 2
		aK.hp = 1e12
		local probe = strike(roomK, hK, "ax_combo", 1, nil)
		aK.hp = procs(probe, "echo")[1].dmg -- 메아리 도끼 한 방이면 쓰러진다
		hK.kit.n = 2
		outK = strike(roomK, hK, "ax_combo", 1, nil)
		if #outK.kills == 1 then
			break
		end
		aK.state, aK.t = "idle", 0
	end
	expect(outK ~= nil and #outK.kills == 1 and outK.kills[1].mob == aK.id, "메아리 도끼가 쓰러뜨린 것도 잡은 것으로 친다")
	expect(hK.xp + hK.level * 1e9 > xp0, "경험치를 받는다")

	-- 힘 모으기
	local core = KIT.axion.core
	local hc = Hero.new(2, "axion")
	local lv0, m0, r0 = Kit.charge(hc, "ax_slam", 5)
	expect(lv0 == 0 and m0 == 1 and r0 == 0 and Kit.chargeTime(hc, "ax_slam") == 0, "배우지 않았으면 모이지 않는다")
	hc.skills.ax_charge = 10
	eq(Kit.chargeTime(hc, "ax_slam"), core.per.ax_slam * core.levels, "대지 강타를 끝까지 모으는 시간")
	eq(Kit.chargeTime(hc, "ax_combo"), core.per.ax_combo * core.levels, "삼단 베기 셋째 타를 끝까지 모으는 시간")
	eq(Kit.chargeTime(hc, "ax_dash"), 0, "돌진은 모을 수 없다")
	for _, c in { { 0, 0 }, { 0.29, 0 }, { 0.3, 1 }, { 0.59, 1 }, { 0.6, 2 }, { 9, 2 }, { -1, 0 } } do
		local lv, mul, reach = Kit.charge(hc, "ax_slam", c[1])
		eq(lv, c[2], ("대지 강타를 %.2f초 모으면 %d단계"):format(c[1], c[2]))
		near(mul, 1 + c[2] * core.bonus[2], 1e-9, "단계마다 피해 +55%(마스터)")
		eq(reach, c[2] * core.reach, "단계마다 닿는 거리 +10")
	end
	eq((Kit.charge(hc, "ax_combo", 0.2)), 1, "삼단 베기 셋째 타는 0.2초에 한 단계")
	hc.skills.ax_charge = 1
	near(select(2, Kit.charge(hc, "ax_slam", 0.6)), 1 + 2 * core.bonus[1], 1e-9, "레벨 1이면 단계마다 +36%")
	-- 모아 친 타: 피해가 그 배수만큼, 닿는 거리가 그만큼 는다(같은 씨앗의 방 둘로 견준다 — 흩어짐이 같다)
	local roomA, hA, aA = arena("axion", { ax_charge = 10 }, 11)
	local roomB, hB, aB = arena("axion", { ax_charge = 10 }, 11)
	local _, mul2, reach2 = Kit.charge(hA, "ax_slam", 0.6)
	local plain = strike(roomA, hA, "ax_slam", 1, nil)
	local charged = strike(roomB, hB, "ax_slam", 1, { mul = mul2, reach = reach2 })
	near(charged.hits[1].dmg / plain.hits[1].dmg, mul2, 0.01, "끝까지 모아 치면 피해가 2.1배")
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

-- ---- 5) 리퍼: 영혼 · 도깨비불 · 생기 흡수 ----
do
	local core, tg, pas = KIT.reaper.core, KIT.reaper.toggle, KIT.reaper.passive
	local room, h, a = arena("reaper", { rp_soul = 10 })
	-- 쓰러뜨리면 영혼 하나(다섯까지). 영혼 하나마다 공격력 +3%
	for i = 1, core.max + 2 do
		a.state, a.t, a.hp = "idle", 0, 1
		local out = strike(room, h, "rp_hook", 2, nil)
		eq(#out.kills, 1, "쓰러뜨린다")
		eq(h.kit.souls, math.min(core.max, i), ("영혼 %d"):format(i))
		expect((out.kit == true) == (i <= core.max), "늘었을 때만 화면에 알린다")
	end
	near(Kit.attack(h), 1 + core.max * core.each / 100, 1e-9, "영혼 다섯이면 공격력 +15%")
	eq(Kit.view(h).souls, core.max, "화면에 영혼의 수가 간다")
	-- 피해에 들어간다(같은 씨앗의 방 둘)
	local roomA, hA = arena("reaper", { rp_soul = 10 }, 21)
	local roomB, hB = arena("reaper", { rp_soul = 10 }, 21)
	hB.kit.souls = core.max
	near(strike(roomB, hB, "rp_hook", 2, nil).hits[1].dmg / strike(roomA, hA, "rp_hook", 2, nil).hits[1].dmg, 1.15, 0.01, "영혼 다섯이면 피해 +15%")
	-- 30초마다 하나씩 흩어진다(얻으면 다시 센다)
	local changed = Kit.tick(h, core.decay - 1)
	expect(not changed and h.kit.souls == core.max, "아직 흩어지지 않는다")
	changed = Kit.tick(h, 1)
	expect(changed and h.kit.souls == core.max - 1, "30초가 지나면 하나가 흩어진다")
	Kit.tick(h, core.decay - 1)
	expect(Kit.gainSoul(h) and h.kit.souls == core.max and h.kit.soulT == 0, "얻으면 시간을 다시 센다")
	hA.skills.rp_soul = 1
	hA.kit.souls = 2
	near(Kit.attack(hA), 1 + 2 * core.each / 100 * FLOOR, 1e-9, "레벨 1이면 하나마다 +1.2%")

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

	-- 생기 흡수: 낫 기술의 한 타가 맞을 때마다 최대 체력의 1.5%(몇 마리가 맞든 한 번 · 가득하면 없다)
	local roomD, hD, aD, bD = arena("reaper", { rp_drain = 10 })
	bD.x = X + 30 -- 둘이 같이 맞는다
	eq(strike(roomD, hD, "rp_double", 1, nil).heal, nil, "체력이 가득하면 되찾을 것이 없다")
	hD.hp = math.floor(hD.maxHp / 2)
	local hp0 = hD.hp
	local outD = strike(roomD, hD, "rp_double", 1, nil)
	eq(#mains(outD), 2, "둘이 맞는다")
	local healWant = math.max(1, math.floor(hD.maxHp * pas.heal / 100 + 0.5))
	expect(outD.heal == healWant and hD.hp == hp0 + healWant, ("한 타에 한 번, 최대 체력의 1.5%% — %s"):format(tostring(outD.heal)))
	aD.x, bD.x = 1400, 1430
	eq(strike(roomD, hD, "rp_double", 1, nil).heal, nil, "못 맞히면 되찾지 못한다")
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
	-- 주먹의 한 타가 맞을 때마다 열기 +10, 50부터 달아오름: 맞힐 때마다 불꽃이 한 번 더(그 타의 20%)
	for i = 1, 12 do
		local out = strike(room, h, "sl_punch", 1, nil)
		eq(h.kit.heat, math.min(core.max, i * core.gain), ("열기 %d"):format(i))
		expect(out.kit == true, "열기가 올랐다고 알린다")
		local flames = procs(out, "flame")
		if i * core.gain >= core.hot then
			expect(#flames == 1 and flames[1].mob == a.id and flames[1].dmg == math.max(1, math.floor(mains(out)[1].dmg * core.share + 0.5)), ("달아오르면 불꽃이 한 번 더 %d"):format(i))
		else
			eq(#flames, 0, ("아직 달아오르지 않았다 %d"):format(i))
		end
	end
	expect(Kit.hot(h) and Kit.view(h).hot == true and Kit.view(h).heat == core.max, "달아올랐다")
	-- 3초 동안 못 맞히면 초마다 25씩 식는다
	local changed = Kit.tick(h, core.cool - 0.5)
	expect(not changed and h.kit.heat == core.max, "3초 전에는 식지 않는다")
	Kit.tick(h, 0.5)
	Kit.tick(h, 1)
	near(h.kit.heat, core.max - core.decay, 1e-6, "3초가 지나면 초마다 25씩 식는다")
	local flipped = false
	for _ = 1, 40 do
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
	-- 액시온: 겹 메아리(둘째 도끼) · 울리는 메아리(둘레로 번진다) · 달 그림자 도끼(두 번째 타마다 · 더 세게)
	do
		local room, h, a, b = arena("axion", { ax_echo = 10, ax_echo2 = 10, ax_echo3 = 10 })
		h.level = 120
		h.kit.on = true
		b.x = a.x + 10 -- 옆에 붙은 졸개(번지는 범위 안)
		local echo, splash, main = 0, 0, 0
		local first, second = 0, 0
		for i = 1, 3 do
			local out = strike(room, h, "ax_combo", 1)
			local n, _, list = count(out, "echo")
			echo += n
			splash += (count(out, "splash"))
			for _, e in out.hits do
				if not e.proc and e.mob == a.id then
					main = e.dmg
				end
			end
			for _, e in list do
				if e.i == 0 then
					first = e.dmg
				else
					second = e.dmg
				end
				eq(e.up, 3, "배운 강화를 같이 알린다(하나 더 + 번짐)")
			end
		end
		expect(echo >= 2 and first > 0 and second > 0, "겹 메아리: 도끼가 둘 떨어진다 " .. echo)
		near(second / first, UP.axion.two.share, 0.05, "둘째 도끼는 첫 도끼의 절반")
		expect(splash >= 1, "울리는 메아리: 옆의 졸개에게 번진다 " .. splash)
		-- 달 그림자 도끼: 두 번째 타마다
		local room2, h2 = arena("axion", { ax_echo = 10, ax_echo4 = 10 })
		h2.level = 120
		h2.kit.on = true
		local n2 = 0
		for _ = 1, 6 do
			n2 += (count(strike(room2, h2, "ax_combo", 1), "echo"))
		end
		expect(n2 >= 3, "달 그림자 도끼: 여섯 타에 세 번(두 번째 타마다) " .. n2)
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
	-- 리퍼: 떼도깨비불(영혼 둘마다 하나 더) · 붙는 불(초마다 태운다) · 원혼(더 자주)
	do
		local room, h, a = arena("reaper", { rp_wisp = 10, rp_soul = 10, rp_wisp2 = 10, rp_wisp3 = 10 })
		h.level = 120
		h.kit.on = true
		h.kit.souls = 4
		local out = strike(room, h, "rp_double", 1)
		local n = count(out, "wisp")
		eq(n, 3, "떼도깨비불: 영혼 넷이면 세 발")
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
