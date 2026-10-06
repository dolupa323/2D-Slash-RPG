-- 「달의 계승자」 — 싸움의 셈: 캐릭터(체력 · 경험치 · 레벨업 · 물약 · 쓰러짐)와 방(졸개의 움직임 · 공격 · 기술 판정 · 보상 · 줍기)
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
-- 본보기 차림: 열세 부위를 모두 내 레벨의 장비로 — 능력치를 다 주 능력치에 찍으면 전투력이 "본보기 전투력"(10 × 1.07^레벨)이 된다
local function dressRef(h)
	for _, slot in Items.data.SLOTS do
		h.equip[slot.id] = Items.make(slot.id, h.level, nil, h.class)
	end
end
local startPower = {}
for _, c in Items.data.checks.startPower do
	startPower[c[1]] = c[2]
end
local RULES = COMBAT.rules
local DT = 1 / 20

-- ---- 1) 자료의 짜임 ----
for id, sk in COMBAT.skills do
	local char = CHARS.chars[sk.who]
	expect(char ~= nil, "기술의 캐릭터 " .. id)
	local total = 0
	for i, seg in sk.segs do
		local clip = char.clips[seg.clip]
		expect(clip ~= nil and seg.to < #clip.frames and seg.from <= seg.to, ("%s 구간 %d의 동작"):format(id, i))
		expect(math.abs(seg.time - (seg.to - seg.from + 1) / seg.fps) < 0.001, id .. " 구간 시간")
		total += seg.time
	end
	expect(math.abs(total - sk.time) < 0.001, id .. " 전체 시간")
	for _, h in sk.hits do
		local seg = sk.segs[h.seg]
		expect(seg ~= nil and h.at >= 0 and h.at <= seg.time + 0.2, id .. " 맞는 때가 구간 안")
		expect(#h.box == 4 and h.box[1] < h.box[2] and h.mul > 0, id .. " 판정 상자와 배수")
	end
	if sk.type == "move" then
		expect(#sk.hits == 0 and sk.speed > 0 and sk.dist > 0, id .. " 이동기는 피해가 없다")
	else
		expect(#sk.hits >= 1, id .. " 공격기는 판정이 있다")
	end
end
-- 보스기 삼단 베기를 다 맞히면 "전투력 × 초당 피해 × 걸린 시간"
local combo = COMBAT.skills.ax_combo
local sum = 0
for _, h in combo.hits do
	sum += h.mul
end
expect(math.abs(sum - N.data.POWER.dps * combo.time) < 0.01, ("삼단 베기의 배수 합 %.3f = 초당 피해 × 시간 %.3f"):format(sum, N.data.POWER.dps * combo.time))
for kind, m in COMBAT.mobs do
	local clip = CHARS.chars[COMBAT.mobs[kind].sprite].clips.atk
	expect(clip ~= nil, "졸개 공격 동작 " .. kind)
	expect(m.atk.windup < m.atk.time and m.atk.time > 0, "졸개가 치는 때 " .. kind)
	for _, c in { "idle", "run", "hit", "spawn", "death" } do
		expect(CHARS.chars[COMBAT.mobs[kind].sprite].clips[c] ~= nil, ("졸개 동작 %s.%s"):format(kind, c))
	end
end

-- ---- 2) 캐릭터 ----
local h = Hero.new(1, "axion")
h.auto = false -- 저절로 찍기를 끄고 점수가 쌓이는 것을 본다
eq(h.level, 1, "새 캐릭터는 Lv.1")
eq(h.hp, N.hpOf("axion", 1), "체력이 다 차 있다")
eq(Hero.power(h), startPower.axion, "처음 차림의 전투력(공방과 같다)")
dressRef(h)
eq(Hero.power(h), N.refPower(1), "본보기 차림이면 본보기 전투력")
-- 경험치: 딱 필요한 만큼이면 한 레벨
local need = N.xpNeed(1)
eq(Hero.gainXp(h, need - 1), 0, "모자라면 그대로")
eq(Hero.gainXp(h, 1), 1, "채우면 레벨업")
eq(h.level, 2, "Lv.2")
eq(h.xp, 0, "남는 경험치 없음")
eq(h.ap, 5, "능력치 5점")
eq(h.sp, 3, "스킬 포인트 3점")
eq(h.hp, N.hpOf("axion", 2), "레벨업하면 체력이 다 찬다")
-- 한꺼번에 많이: 여러 레벨이 오른다
local big = N.xpNeed(2) + N.xpNeed(3) + 5
eq(Hero.gainXp(h, big), 2, "두 레벨이 한 번에")
eq(h.level, 4, "Lv.4")
eq(h.xp, 5, "남은 경험치가 넘어간다")
-- 맞기와 무적
local before = h.hp
eq(Hero.hurt(h, 10), 10, "10 맞는다")
eq(h.hp, before - 10, "체력이 준다")
eq(Hero.hurt(h, 10), 0, "무적 중에는 안 맞는다")
Hero.tick(h, RULES.invuln + 0.01)
eq(Hero.hurt(h, 10), 10, "무적이 끝나면 다시 맞는다")
-- 물약
local pots = h.potions
local healed = Hero.drink(h)
expect(healed ~= nil and healed > 0, "물약으로 회복")
eq(h.potions, pots - 1, "물약이 하나 준다")
eq(Hero.drink(h), nil, "바로 또 마시지는 못한다")
Hero.tick(h, 2)
h.hp = h.maxHp
eq(Hero.drink(h), nil, "체력이 다 차 있으면 마시지 않는다")
-- 쓰러짐: Lv.10 전에는 벌칙이 없다
Hero.hurt(h, 999999)
expect(not h.alive and h.hp == 0, "쓰러진다")
eq(h.weak, 0, "Lv.10 전에는 벌칙 없음")
eq(Hero.hurt(h, 10), 0, "쓰러져 있으면 더 맞지 않는다")
expect(not Hero.tick(h, RULES.reviveWait - 0.1), "아직 일어날 때가 아니다")
expect(Hero.tick(h, 0.2), "일어날 때가 됐다")
Hero.revive(h)
expect(h.alive and h.hp == h.maxHp, "일어나면 체력이 다 찬다")
-- Lv.10부터는 벌칙: 경험치가 20%만
local vet = Hero.new(2, "riven")
Hero.gainXp(vet, 1e7)
expect(vet.level >= 10, "레벨을 올려 둠 " .. vet.level)
local full = Hero.killXp(vet, vet.level, 1)
Hero.hurt(vet, 1e9)
expect(vet.weak > 0, "Lv.10부터는 쓰러지면 벌칙이 있다")
eq(Hero.killXp(vet, vet.level, 1), math.max(1, math.floor(full * 0.2 + 0.5)), "벌칙 중 경험치 20%")
-- 최고 레벨
local top = Hero.new(3, "mooni")
top.auto = true
Hero.gainXp(top, 1e15)
eq(top.level, N.MAX_LEVEL, "최고 레벨에서 멈춘다")
eq(Hero.gainXp(top, 1000), 0, "더 오르지 않는다")
eq(top.xp, 0, "최고 레벨에서는 경험치가 쌓이지 않는다")
eq(top.ap + top.stats.str + top.stats.int, N.apAt(N.MAX_LEVEL), "받은 능력치 점수 합(저절로 주 능력치에 찍힌다)")
eq(top.stats.str, N.apAt(N.MAX_LEVEL), "무니의 주 능력치는 힘")

-- ---- 2-1) 직업 · 능력치 · 스킬 ----
eq(#CLASSES.order, 5, "직업 다섯")
for _, class in CLASSES.order do
	local c = CLASSES.classes[class]
	expect(c ~= nil and c.name ~= "" and c.weapon ~= "" and c.face ~= "", "직업의 이름 · 무기 · 달의 얼굴 " .. class)
	local fresh = Hero.new(1, class)
	local started = 0
	for _, sk in c.skills do
		if table.find(CLASSES.skillRule.start, sk.type) then
			started += 1
			eq(Hero.skillLevel(fresh, sk.id), 1, ("처음부터 주는 기술 %s"):format(sk.id))
			expect(COMBAT.skills[sk.id] ~= nil and COMBAT.skills[sk.id].who == class, "그 기술의 싸움 수치 " .. sk.id)
			eq(COMBAT.skills[sk.id].max, sk.max, "마스터 레벨이 설계와 같다 " .. sk.id)
		else
			eq(Hero.skillLevel(fresh, sk.id), 0, "나머지는 배우지 않은 채로 " .. sk.id)
		end
	end
	eq(started, 3, "사냥기 · 보스기 · 이동기 " .. class)
	eq(Hero.power(fresh), startPower[class], "Lv.1의 전투력(처음 차림) " .. class)
end
-- 스킬 레벨의 세기: 공방의 식과 같다
for _, c in CLASSES.scaleCheck do
	expect(math.abs(Hero.skillScale(c[1], c[2]) - c[3]) < 1e-6, ("스킬 세기(%d/%d)"):format(c[1], c[2]))
end
-- 전투력: 공방의 식과 같다(능력치 효율을 넣어서)
for _, c in N.data.checks.power do
	local P = N.data.POWER
	local mine = math.floor(P.base * (P.levelShare * c[2] * P.grow ^ c[1] + P.itemShare * P.grow ^ c[1]) + 0.5)
	eq(mine, c[3], ("전투력 Lv.%d 효율 %s"):format(c[1], tostring(c[2])))
end
-- 능력치 찍기
local st = Hero.new(5, "riven")
st.auto = false
Hero.gainXp(st, N.xpNeed(1) + N.xpNeed(2))
eq(st.level, 3, "Lv.3")
eq(st.ap, 10, "찍지 않은 점수 10")
dressRef(st)
local weak = Hero.power(st)
expect(weak < N.refPower(3), "점수를 안 찍으면 전투력이 모자라다")
eq(Hero.addStat(st, "luk", 11), false, "가진 것보다 많이는 못 찍는다")
eq(Hero.addStat(st, "luk", 0), false, "0점은 못 찍는다")
eq(Hero.addStat(st, "luk", 1.5), false, "소수는 못 찍는다")
eq(Hero.addStat(st, "wis", 1), false, "없는 능력치")
eq(Hero.addStat(st, "luk", 6), true, "주 능력치(운)에 6점")
eq(st.ap, 4, "남은 점수")
local hp0 = st.maxHp
eq(Hero.addStat(st, "hp", 4), true, "체력에 4점")
expect(st.maxHp >= hp0, "체력에 찍으면 체력 상한이 는다")
eq(st.maxHp, N.hpOf("riven", 3, 4), "체력 상한의 식")
expect(Hero.power(st) > weak and Hero.power(st) < N.refPower(3), "주 능력치에 찍은 만큼 전투력이 오른다(체력에 찍은 만큼은 모자라다)")
local all = Hero.new(6, "riven")
all.auto = false
Hero.gainXp(all, N.xpNeed(1) + N.xpNeed(2))
eq(Hero.autoStat(all), 10, "자동으로 찍기: 남은 것을 모두 주 능력치에")
dressRef(all)
eq(Hero.power(all), N.refPower(3), "다 주 능력치에 찍으면 본보기 전투력")
-- 스킬 올리기
eq(Hero.skillUp(all, "rv_fan"), true, "스킬 포인트로 한 레벨")
eq(Hero.skillLevel(all, "rv_fan"), 2, "칼날 부채 Lv.2")
eq(all.sp, N.spAt(2) + N.spAt(3) - 1, "포인트가 준다")
eq(Hero.skillUp(all, "ax_slam"), false, "남의 직업 스킬은 못 올린다")
eq(Hero.skillUp(all, "no_such"), false, "없는 스킬")
expect(Hero.scale(all, "rv_fan") > Hero.scale(all, "rv_double"), "레벨이 높은 스킬이 더 세다")
eq(Hero.scale(all, "rv_mark"), 0, "배우지 않은 스킬은 세기가 0")
local spent = Hero.autoSkill(all)
eq(spent, N.spAt(2) + N.spAt(3) - 1, "추천대로 찍기: 남은 것을 모두")
eq(all.sp, 0, "포인트를 다 썼다")
expect(Hero.skillLevel(all, "rv_fan") >= Hero.skillLevel(all, "rv_double"), "사냥기부터 찍는다")
-- 마스터를 넘지 않는다
local rich = Hero.new(7, "axion")
rich.auto = false
rich.sp = 500
Hero.autoSkill(rich)
for _, sk in CLASSES.classes.axion.skills do
	eq(Hero.skillLevel(rich, sk.id), sk.max, "마스터까지만 " .. sk.id)
end
expect(rich.sp > 0, "남는 포인트는 그대로")
-- 저절로 찍기를 켜 두면: 레벨업하면 주 능력치와 추천 스킬에 들어간다(기본은 꺼져 있다 — 직접 찍는다)
eq(Hero.new(8, "salamander").auto, false, "기본은 직접 찍기")
local auto = Hero.new(8, "salamander")
auto.auto = true
Hero.gainXp(auto, N.xpNeed(1) + N.xpNeed(2) + N.xpNeed(3))
eq(auto.ap, 0, "저절로: 능력치 점수가 남지 않는다")
eq(auto.sp, 0, "저절로: 스킬 포인트가 남지 않는다")
eq(auto.stats.dex, 15, "살라맨더의 주 능력치는 민첩")
dressRef(auto)
eq(Hero.power(auto), N.refPower(4), "본보기 전투력")

-- ---- 2-2) 저장 꼴 ----
local saved = Hero.pack(all)
eq(saved.v, 1, "저장 꼴 번호")
local back = Hero.unpack(6, saved)
expect(back ~= nil, "되살린다")
eq(back.class, "riven", "직업")
eq(back.level, all.level, "레벨")
eq(back.xp, all.xp, "경험치")
eq(back.stats.luk, all.stats.luk, "능력치")
eq(back.ap, all.ap, "남은 능력치 점수")
eq(Hero.skillLevel(back, "rv_fan"), Hero.skillLevel(all, "rv_fan"), "스킬 레벨")
eq(back.sp, all.sp, "남은 스킬 포인트")
eq(back.hp, back.maxHp, "들어오면 체력이 다 차 있다")
eq(Hero.power(back), Hero.power(all), "전투력이 같다")
-- 이상한 자료
eq(Hero.unpack(1, nil), nil, "없으면 nil")
eq(Hero.unpack(1, { class = "wizard", level = 3 }), nil, "없는 직업")
eq(Hero.unpack(1, { class = "axion", level = 999 }), nil, "레벨이 말이 안 됨")
eq(Hero.unpack(1, { class = "axion", level = 2.5 }), nil, "레벨이 소수")
-- 점수가 받은 것보다 많이 찍혀 있으면 되돌려 준다(레벨과 돈은 지킨다)
local cheat = Hero.unpack(1, { class = "axion", level = 5, xp = 3, money = 77, potions = 4, stats = { str = 999, dex = 0, int = 0, luk = 0, hp = 0 }, skills = { ax_slam = 20, ax_combo = 20, ax_charge = 10 } })
expect(cheat ~= nil, "되살리기는 한다")
eq(cheat.level, 5, "레벨은 지킨다")
eq(cheat.money, 77, "돈은 지킨다")
eq(cheat.stats.str, 0, "넘치게 찍힌 능력치는 되돌린다")
eq(cheat.ap, N.apAt(5), "받은 점수를 다 돌려준다")
eq(Hero.skillLevel(cheat, "ax_slam"), 1, "넘치게 찍힌 스킬은 처음으로")
eq(cheat.sp, Hero.spEarned(5), "받은 스킬 포인트를 다 돌려준다")
-- 빠진 칸이 있어도 기본값으로 채운다
local thin = Hero.unpack(1, { class = "mooni", level = 2 })
expect(thin ~= nil and thin.money == 0 and thin.potions == RULES.startPotions and thin.ap == N.apAt(2), "빠진 칸은 기본값")
eq(Hero.skillLevel(thin, "mn_spin"), 1, "처음부터 주는 기술은 늘 있다")

-- ---- 3) 방: 졸개의 움직임 ----
local scene = SCENES.scenes.hunt
-- 졸개 한 마리만 있는 방(다른 졸개가 끼어들지 않게) — 사냥터에서 그 종류의 넓은 자리 하나를 골라 온다
local function soloRoom(kind, seed)
	local def = nil
	for _, m in scene.mobs do
		if m.kind == kind and m.range[2] - m.range[1] >= 40 and not def then
			def = m
		end
	end
	assert(def, "사냥터에 " .. kind .. "가 없다")
	local one = { w = scene.w, h = scene.h, rows = scene.rows, spawn = scene.spawn, mobs = { def } }
	local r = Room.new("solo", one, Random.new(seed))
	for _ = 1, 30 do
		r:step({}, DT) -- 나타나는 동작이 끝날 때까지
	end
	return r, r.mobs[1]
end
local room = Room.new("hunt", scene, Random.new(7))
eq(#room.mobs, #scene.mobs, "졸개 수")
local function run(heroes, seconds)
	local all = {}
	for _ = 1, math.floor(seconds / DT + 0.5) do
		for _, hero in heroes do
			Hero.tick(hero, DT)
		end
		for _, e in room:step(heroes, DT) do
			table.insert(all, e)
		end
	end
	return all
end
-- 아무도 없으면: 나타나서 제 범위 안을 어슬렁거린다
run({}, 12)
local moved = 0
for _, mob in room.mobs do
	expect(mob.x >= mob.a - 0.01 and mob.x <= mob.b + 0.01, "범위를 벗어나지 않는다 " .. mob.kind)
	expect(mob.state == "idle" or mob.state == "run", "어슬렁 상태 " .. mob.state)
	if math.abs(mob.x - mob.homeX) > 0.5 then
		moved += 1
	end
end
expect(moved >= #room.mobs / 3, "어슬렁거리며 자리를 옮긴다 " .. moved)

-- 검병 하나를 골라 그 옆에 선다 → 알아채고 다가와서 친다
local function pick(kind)
	for _, mob in room.mobs do
		if mob.kind == kind and mob.b - mob.a >= 40 then
			return mob
		end
	end
end
local function fresh(class, lv)
	local hero = Hero.new(9, class)
	if lv > 1 then
		local xp = 0
		for L = 1, lv - 1 do
			xp += N.xpNeed(L)
		end
		Hero.gainXp(hero, xp)
	end
	return hero
end
local warrior = pick("warrior")
expect(warrior ~= nil, "검병이 있다")
local me = fresh("axion", 3)
me.x, me.y = math.clamp(warrior.x + 30, warrior.a, warrior.b), warrior.y
local hp0 = me.hp
local ev = run({ [me.id] = me }, 4)
local hurt = 0
for _, e in ev do
	if e.type == "hurt" and e.hero == me.id then
		hurt += 1
		-- 한 방 = 그 레벨 기본 체력의 6% × (1 - 끼고 있는 방어구가 줄여 주는 몫)
		eq(e.dmg, math.max(1, math.floor(N.rawHit("mob", warrior.lv) * (1 - Hero.cut(me, warrior.lv) / 100) * warrior.def.atk.mul + 0.5)), "검병의 한 방")
	end
end
expect(hurt >= 1, "검병이 다가와 친다 " .. hurt)
expect(me.hp < hp0, "체력이 줄었다")
expect(hurt <= 4, "무적과 다시 치기 시간 때문에 4초에 몇 번뿐 " .. hurt)
-- 다른 층(높이가 다름)에 있으면 알아채지 못한다
local room2, w2 = soloRoom("warrior", 7)
local far = fresh("axion", 3)
far.x, far.y = w2.x, w2.y - 80
for _ = 1, 100 do
	room2:step({ [far.id] = far }, DT)
	expect(w2.target == nil and w2.state ~= "atk", "다른 층의 사람은 알아채지 못한다")
end
eq(far.hp, far.maxHp, "다른 층의 사람은 치지 않는다")

-- 궁병: 다가오지 않고 쏜다 — 화살이 날아와 맞는다
local room3, archer = soloRoom("archer", 11)
expect(archer ~= nil, "궁병이 있다")
if archer then
	local ax = archer.x
	local target = fresh("riven", 4)
	target.x, target.y = archer.x + 60, archer.y
	local shots, hits = 0, 0
	for _ = 1, 120 do
		Hero.tick(target, DT)
		for _, e in room3:step({ [target.id] = target }, DT) do
			if e.type == "shot" then
				shots += 1
				eq(e.dir, 1, "화살은 사람 쪽으로")
			elseif e.type == "hurt" then
				hits += 1
			end
		end
	end
	expect(shots >= 1 and hits >= 1, ("궁병이 쏘고 맞힌다(쏜 것 %d · 맞은 것 %d)"):format(shots, hits))
	eq(archer.x, ax, "궁병은 다가오지 않는다")
end

-- 폭탄병: 달려와 터지고 사라진다(경험치를 주지 않는다)
local room4, bomber = soloRoom("bomber", 13)
expect(bomber ~= nil, "폭탄병이 있다")
if bomber then
	local victim = fresh("mooni", 4)
	victim.x, victim.y = math.clamp(bomber.x + 24, bomber.a, bomber.b), bomber.y
	local burst, hurtN = false, 0
	for _ = 1, 100 do
		Hero.tick(victim, DT)
		for _, e in room4:step({ [victim.id] = victim }, DT) do
			if e.type == "burst" then
				burst = true
			elseif e.type == "hurt" then
				hurtN += 1
			end
		end
	end
	expect(burst and hurtN == 1, "폭탄병이 터져 한 번 맞는다")
	expect(bomber.state == "gone" or bomber.state == "dead" or bomber.state == "spawn", "터진 폭탄병은 사라진다 " .. bomber.state)
	eq(victim.xp, 0, "터진 폭탄병은 경험치를 주지 않는다")
end

-- ---- 4) 기술 판정과 보상 ----
local roomS, foe = soloRoom("warrior", 21)
local hero = fresh("axion", 3)
hero.x, hero.y = foe.x - 20, foe.y
local slam = COMBAT.skills.ax_slam
-- 등 뒤로 쓰면 맞지 않는다
local miss = roomS:skillHit(hero, combo.hits[1], hero.x, hero.y, -1)
eq(#miss.hits, 0, "등 뒤의 졸개는 삼단 베기에 맞지 않는다")
-- 앞으로 쓰면 맞는다. 피해 = 전투력 × 배수 ± 흩어짐
local res = roomS:skillHit(hero, combo.hits[1], hero.x, hero.y, 1)
expect(#res.hits >= 1, "앞의 졸개가 맞는다")
local want = Hero.power(hero) * combo.hits[1].mul
for _, hit in res.hits do
	expect(hit.dmg >= math.floor(want * 0.9) and hit.dmg <= math.ceil(want * 1.1), ("피해 %d(기대 %.1f ±10%%)"):format(hit.dmg, want))
end
eq(foe.state, "hit", "맞으면 멈칫한다")
-- 스킬 레벨의 세기가 곱해진다
local roomK, foeK = soloRoom("warrior", 21)
local half = roomK:skillHit(hero, combo.hits[1], foeK.x - 20, foeK.y, 1, 0.4)
expect(#half.hits == 1 and half.hits[1].dmg <= math.ceil(want * 0.4 * 1.1) and half.hits[1].dmg >= math.floor(want * 0.4 * 0.9), "세기 0.4면 피해도 0.4배")
-- 리퍼의 낫 걸기: 맞은 적을 끌어온다(제 범위 안에서)
local roomP, foeP = soloRoom("warrior", 22)
local hook = COMBAT.skills.rp_hook
local reaper = fresh("reaper", 3)
foeP.x = math.min(foeP.b, foeP.a + 50)
reaper.x, reaper.y = foeP.x - 50, foeP.y
local farX = foeP.x
local pulled = roomP:skillHit(reaper, hook.hits[1], reaper.x, reaper.y, 1, 1)
expect(#pulled.hits == 1, "낫 걸기가 닿는다")
expect(foeP.x < farX and foeP.x >= foeP.a, ("끌려온다 %.1f → %.1f"):format(farX, foeP.x))
expect(foe.target == hero.id and foe.aggro > 0, "때린 사람을 쫓는다")
-- 죽을 때까지 친다 → 경험치 · 달돈(열에 여섯쯤)
local room5 = Room.new("hunt", scene, Random.new(21))
for _ = 1, 30 do
	room5:step({}, DT)
end
local kills, xpSum, money = 0, 0, 0
local drops = {}
for _ = 1, 1200 do
	for _, mob in room5.mobs do
		if mob.state ~= "dead" and mob.state ~= "gone" and mob.state ~= "spawn" then
			local r = room5:skillHit(hero, slam.hits[1], mob.x - 10, mob.y, 1)
			for _, k in r.kills do
				kills += 1
				xpSum += k.xp
				if k.drop then
					table.insert(drops, k.drop)
				end
			end
		end
	end
	room5:step({}, DT)
	if kills >= 40 then
		break
	end
end
expect(kills >= 40, "졸개를 마흔 마리 잡는다(다시 나온다) " .. kills)
expect(hero.level > 3, "경험치를 얻어 레벨이 오른다 → Lv." .. hero.level)
expect(#drops >= 12 and #drops <= 36, ("달돈이 열에 여섯쯤 떨어진다(마흔 마리에 %d번)"):format(#drops))
for _, d in drops do
	expect(d.kind == "money" and d.amount >= 1 and d.owner == hero.id, "떨어진 달돈")
end
-- 한 타에 맞는 수는 정해져 있다
local crowd = Room.new("hunt", scene, Random.new(5))
for _ = 1, 30 do
	crowd:step({}, DT)
end
for _, mob in crowd.mobs do
	mob.x, mob.y, mob.a, mob.b = 300, 160, 0, 9999
end
local wide = crowd:skillHit(fresh("axion", 50), { box = { -100, 100, 60, 10 }, mul = 0.01 }, 300, 160, 1)
eq(#wide.hits, RULES.maxTargets, "한 타에 맞는 수")

-- ---- 5) 줍기 ----
local d = drops[#drops]
local live = nil
for _, x in room5.drops do
	live = x
end
expect(live ~= nil, "방에 떨어진 것이 남아 있다")
if live then
	local other = fresh("riven", 3)
	other.id = 77
	other.x, other.y = live.x, live.y
	local got, why = room5:pickup(other, live.id)
	expect(got == nil and why == "남의 것", "잡은 사람이 아니면 한동안 못 줍는다")
	hero.x, hero.y = live.x + RULES.pickup + 30, live.y
	got, why = room5:pickup(hero, live.id)
	expect(got == nil and why == "멀다", "멀면 못 줍는다")
	hero.x = live.x + 4
	local m0 = hero.money
	got = room5:pickup(hero, live.id)
	expect(got ~= nil and hero.money == m0 + live.amount, "가까이에서 줍는다 — 달돈이 는다")
	expect(room5:pickup(hero, live.id) == nil, "한 번 주운 것은 없다")
end
-- 주인만 줍는 시간이 지나면 남도 줍는다 · 오래되면 사라진다
local keep = nil
for _, x in room5.drops do
	keep = x
	break
end
if keep then
	local other = fresh("riven", 3)
	other.id = 78
	other.x, other.y = keep.x, keep.y
	for _ = 1, math.floor(RULES.dropOwn / DT) + 2 do
		room5:step({}, DT)
	end
	expect(room5:pickup(other, keep.id) ~= nil, "시간이 지나면 남도 줍는다")
	local gone = 0
	for _ = 1, math.floor(RULES.dropLife / DT) + 2 do
		for _, e in room5:step({}, DT) do
			if e.type == "dropGone" then
				gone += 1
			end
		end
	end
	local left = 0
	for _ in room5.drops do
		left += 1
	end
	eq(left, 0, "오래된 것은 사라진다")
end
local _ = d

-- 방의 모습: 들어온 사람에게 주는 것과 화면용 요약
local desc = room:describe()
eq(#desc.mobs, #room.mobs, "졸개 목록")
eq(#desc.snap, #room.mobs, "요약 목록")
expect(desc.mobs[1].maxHp > 0 and desc.mobs[1].name ~= nil and #desc.snap[1] == 6, "졸개 한 줄의 짜임")
