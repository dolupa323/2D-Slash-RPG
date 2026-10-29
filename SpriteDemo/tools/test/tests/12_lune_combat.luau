-- 「달의 계승자」 — 싸움의 셈: 캐릭터(체력 · 경험치 · 레벨업 · 물약 · 쓰러짐)와 방(졸개의 움직임 · 공격 · 기술 판정 · 보상 · 줍기)
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
-- 본보기 차림: 무기와 방어구 넷을 내 레벨의 보통 장비로(장신구는 벗는다) — 능력치를 다 주스탯에 찍으면 스탯 공격력이 "그 레벨의 기준 스탯 공격력"(N.refAttack)에 가깝다
--  (2026-10-15 스펙 — 예전에는 열세 부위 · 전투력 10 x 1.07^레벨. 장비의 옵션은 부위마다 반올림해서 기준과 몇 % 다를 수 있다)
local function dressRef(h)
	for _, slot in Items.data.SLOTS do
		h.equip[slot.id] = if table.find(Items.data.GEAR, slot.id) then Items.make(slot.id, h.level, nil, h.class) else nil
	end
end
-- 그 레벨의 본보기 차림(보통 · 별 없음)의 스탯 공격력 — 장비의 옵션을 부위마다 반올림한 그대로
--  (2026-10-28부터 방어구 넷의 공격력도 — 적어도 1씩. 몬스터 체력의 기준 N.refAttack에는 넣지 않으므로, 반올림이 그 기준과 가까운지는 방어구의 공격력 없이 본다)
local function refRounded(L: number, noArmorAtk: boolean?): number
	local a = math.floor(N.armorStat(L) + 0.5)
	local armorAtk = if noArmorAtk then 0 else 4 * math.max(1, math.floor(N.armorAtk(L) + 0.5))
	return N.statAtk(4 + 5 * (L - 1) + 4 * a, 4 + 4 * a, math.floor(N.weaponAtk(L) + 0.5) + armorAtk)
end
local function nearRef(power: number, L: number): boolean
	return power == math.floor(refRounded(L) + 0.5) and math.abs(refRounded(L, true) - N.refAttack(L)) / N.refAttack(L) < 0.15
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
	elseif sk.type == "install" then
		-- 쓰는 동작이 있는 설치(연막탄 · 수정 심기 · 저승문): 동작만 있고 판정은 없다 — 그 장에서 놓이고, 놓인 것이 친다(COMBAT.placed)
		local placed = COMBAT.placed[id]
		expect(#sk.hits == 0 and placed ~= nil and placed.cast == "seg", id .. " 설치는 판정이 없고 놓이는 것의 수치가 있다")
		expect(placed ~= nil and placed.at >= 0 and placed.at <= sk.segs[1].time, id .. " 놓이는 때가 동작 안이다")
		eq(sk.cd, placed and placed.cd, id .. " 다시 쓰기")
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
	if m.story then
		-- 스토리 보스(33_lune_boss.luau): 지금은 대기 그림뿐이다(동작 그림은 사용자가 만든다) — 졸개의 공격(atk)은 쓰지 않는다
		expect(CHARS.chars[m.sprite].clips.idle ~= nil, "보스의 대기 그림 " .. kind)
		continue
	end
	if m.gim then
		-- 보스의 기믹 물건(불씨 도둑 두목의 불씨 폭탄 · 가짜 두목 — 치지 않는다): 110_lune_thiefboss.luau가 본다
		expect(CHARS.chars[m.sprite] ~= nil, "기믹 물건의 그림 " .. kind)
		continue
	end
	local clip = CHARS.chars[COMBAT.mobs[kind].sprite].clips.atk
	expect(clip ~= nil, "졸개 공격 동작 " .. kind)
	expect(m.atk.windup < m.atk.time and m.atk.time > 0, "졸개가 치는 때 " .. kind)
	-- 새 몬스터(bare)는 맞음 · 나타남 · 쓰러짐 그림이 없다 — 화면이 번쩍 · 서서히 보임 · 서서히 사라짐으로 그린다(23_lune_monsters.luau)
	for _, c in if m.bare then { "idle", "run" } else { "idle", "run", "hit", "spawn", "death" } do
		expect(CHARS.chars[COMBAT.mobs[kind].sprite].clips[c] ~= nil, ("졸개 동작 %s.%s"):format(kind, c))
	end
end

-- ---- 2) 캐릭터 ----
local h = Hero.new(1, "axion")
h.auto = false -- 저절로 찍기를 끄고 점수가 쌓이는 것을 본다
eq(h.level, 1, "새 캐릭터는 Lv.1")
eq(h.hp, N.hpOf("axion", 1), "체력이 다 차 있다")
-- 이 파일은 크리티컬을 0으로 둔다 — 전투력 = 스탯 공격력(공방의 처음 전투력은 크리티컬 5% · 1.5배의 기댓값까지 넣은 것)
eq(Hero.power(h), math.floor(Hero.attackBase(h) + 0.5), "크리티컬이 없으면 전투력 = 스탯 공격력")
eq(math.floor(Hero.attackBase(h) * 1.025 + 0.5), startPower.axion, "처음 차림의 전투력(공방과 같다 — 크리티컬 5% · 1.5배)")
dressRef(h)
expect(nearRef(Hero.power(h), 1), "본보기 차림이면 기준 스탯 공격력")
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
local pots = Hero.potions(h)
local healed = Hero.drink(h)
expect(healed ~= nil and healed > 0, "물약으로 회복")
eq(Hero.potions(h), pots - 1, "물약이 하나 준다(가방의 소비 탭에서 빠진다)")
eq(Hero.drink(h), nil, "바로 또 마시지는 못한다")
Hero.tick(h, 2)
h.hp = h.maxHp
eq(Hero.drink(h), nil, "체력이 다 차 있으면 마시지 않는다")
-- 쓰러짐: Lv.10 전에는 벌칙이 없다
Hero.hurt(h, 999999)
expect(not h.alive and h.hp == 0, "쓰러진다")
eq(h.weak, 0, "Lv.10 전에는 벌칙 없음")
eq(Hero.hurt(h, 10), 0, "쓰러져 있으면 더 맞지 않는다")
-- 저절로 일어나지 않는다: 조금 지나면 마을로 돌아갈 수 있게 될 뿐이다(돌아갈지는 그 사람이 정한다 — 사용자 2026-10-08)
eq(Hero.tick(h, RULES.reviveWait - 0.1), false, "쓰러져 있다")
eq(Hero.canReturn(h), false, "쓰러진 직후에는 아직 마을로 돌아가지 못한다")
eq(Hero.tick(h, 0.2), false, "저절로 일어나지 않는다")
expect(Hero.canReturn(h), "조금 지나면 마을로 돌아갈 수 있다")
Hero.tick(h, 60)
expect(not h.alive, "오래 지나도 쓰러져 있다")
Hero.revive(h)
eq(Hero.canReturn(h), false, "일어난 사람은 돌아갈 것이 없다")
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
	expect(c ~= nil and c.name ~= "" and c.weapon ~= "" and c.old ~= "", "직업의 이름 · 무기 · 닮은 옛 용사 " .. class)
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
	eq(math.floor(Hero.attackBase(fresh) * 1.025 + 0.5), startPower[class], "Lv.1의 전투력(처음 차림) " .. class)
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
expect(weak < refRounded(3) * 0.8, "점수를 안 찍으면 전투력이 한참 모자라다")
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
expect(Hero.power(st) > weak and Hero.power(st) < Hero.power(st) + 1 and Hero.attackBase(st) < refRounded(3), "주스탯에 찍은 만큼 전투력이 오른다(체력에 찍은 만큼은 모자라다)")
local all = Hero.new(6, "riven")
all.auto = false
Hero.gainXp(all, N.xpNeed(1) + N.xpNeed(2))
eq(Hero.autoStat(all), 10, "자동으로 찍기: 남은 것을 모두 주 능력치에")
dressRef(all)
expect(nearRef(Hero.power(all), 3), "다 주스탯에 찍으면 기준 스탯 공격력")
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
rich.level = 29 -- 1차의 끝: 그 차수 동안 받는 포인트는 1차 스킬을 다 찍는 데 드는 만큼이다(72 — 마스터의 합 75에서 처음부터 주는 셋의 1레벨을 뺀 것). 레벨업마다 3점씩이면 84지만 72에서 멈춘다
rich.sp = Hero.spEarned(29, "axion")
eq(rich.sp, 72, "1차 동안 받는 포인트 = 1차 스킬을 다 찍는 데 드는 만큼")
Hero.autoSkill(rich)
eq(Hero.spLeft(rich, 1), 0, "1차 스킬을 다 찍으면 남는 포인트가 없다(사용자 2026-10-11: 12점이 남았다)")
for _, sk in CLASSES.classes.axion.skills do
	eq(Hero.skillLevel(rich, sk.id), sk.max, "마스터까지만 " .. sk.id)
end
eq(rich.sp, 0, "all tier-1 skills mastered: no skill points left over")
-- 저절로 찍기를 켜 두면: 레벨업하면 주 능력치와 추천 스킬에 들어간다(기본은 꺼져 있다 — 직접 찍는다)
eq(Hero.new(8, "salamander").auto, false, "기본은 직접 찍기")
local auto = Hero.new(8, "salamander")
auto.auto = true
Hero.gainXp(auto, N.xpNeed(1) + N.xpNeed(2) + N.xpNeed(3))
eq(auto.ap, 0, "저절로: 능력치 점수가 남지 않는다")
eq(auto.sp, 0, "저절로: 스킬 포인트가 남지 않는다")
eq(auto.stats.dex, 15, "살라맨더의 주 능력치는 민첩")
dressRef(auto)
expect(nearRef(Hero.power(auto), 4), "기준 스탯 공격력")

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
-- 최고 레벨을 넘는 레벨(설계의 최고 레벨이 줄었다)은 최고 레벨로 맞춘다(2026-10-18 검토 — 전에는 캐릭터에 들어갈 수 없게 됐다) · 0 이하 · 소수는 여전히 말이 안 된다
local over = Hero.unpack(1, { class = "axion", level = 999 })
expect(over ~= nil and over.level == N.MAX_LEVEL, "최고 레벨을 넘는 레벨은 최고 레벨로")
eq(Hero.unpack(1, { class = "axion", level = 0 }), nil, "레벨이 말이 안 됨(0)")
eq(Hero.unpack(1, { class = "axion", level = 2.5 }), nil, "레벨이 말이 안 됨(소수)")
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
expect(thin ~= nil and thin.money == 0 and Hero.potions(thin) == RULES.startPotions and thin.ap == N.apAt(2), "빠진 칸은 기본값")
eq(Hero.potions(cheat), 4, "예전 저장의 물약 수는 가방의 물약이 된다")
eq(Hero.skillLevel(thin, "mn_spin"), 1, "처음부터 주는 기술은 늘 있다")

-- ---- 3) 방: 졸개의 움직임 ----
local scene = SCENES.scenes.hunt
-- 졸개 한 마리만 있는 방(다른 졸개가 끼어들지 않게) — 사냥터의 넓은 자리 하나에 그 종류를 세운다.
--   2026-10-14부터 한 맵에 한 종류다(사냥터 = 검병만) — 레벨은 그 종류가 사는 맵의 것을 쓴다
local function soloRoom(kind, seed)
	local spot, lv = nil, nil
	for _, m in scene.mobs do
		if m.range[2] - m.range[1] >= 40 and not spot then
			spot = m
		end
	end
	for _, sc in SCENES.scenes do
		for _, m in sc.mobs do
			if m.kind == kind and not lv then
				lv = m.lv
			end
		end
	end
	assert(spot and lv, "어느 맵에도 " .. kind .. "가 없다")
	local def = table.clone(spot)
	def.kind, def.lv = kind, lv
	local one = { w = scene.w, h = scene.h, rows = scene.rows, spawn = scene.spawn, mobs = { def } }
	local r = Room.new("solo", one, Random.new(seed))
	for _ = 1, 30 do
		r:step({}, DT) -- 나타나는 동작이 끝날 때까지
	end
	return r, r.mobs[1]
end
local room = Room.new("hunt", scene, Random.new(7))
local FLIES = if Room.huntRoom(scene) then COMBAT.afk.slots else 0 -- 잠수 방지 날파리의 자리(2026-10-28 — 목록 끝 · 처음에는 없다)
eq(#room.mobs, #scene.mobs + FLIES, "졸개 수(+ 날파리의 자리)")
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
	if mob.afk then
		expect(mob.state == "gone" and mob.away, "날파리는 보내기 전까지 없다")
		continue
	end
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
expect(pick("warrior") ~= nil, "검병이 있다")
-- 검병 한 마리만 있는 방에서 잰다 — 사냥터에는 한 자리에 네 종류가 몰려 있어, 옆의 창병 · 폭탄병이 먼저 치면 "검병의 한 방"이 아닌 피해가 섞인다
--  (2026-10-09: 문 곁의 창병 하나를 빼자 졸개들의 어슬렁거리는 차례가 바뀌어 이 검사가 창병의 피해를 쟀다)
local roomW, warrior = soloRoom("warrior", 7)
local me = fresh("axion", 3)
me.x, me.y = math.clamp(warrior.x + 30, warrior.a, warrior.b), warrior.y
local hp0 = me.hp
local ev = {}
for _ = 1, math.floor(4 / DT + 0.5) do
	Hero.tick(me, DT)
	for _, e in roomW:step({ [me.id] = me }, DT) do
		table.insert(ev, e)
	end
end
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

-- 폭탄병: 달려와 터뜨린다 — 터뜨려도 사라지지 않고, 기다렸다가 또 터뜨린다(사용자 2026-10-11: "폭탄병 지혼자 터져서 없어지는거 없어야합니다. 공격하고 사냥당하는 일반 몬스터여야하는거에요")
local room4, bomber = soloRoom("bomber", 13)
expect(bomber ~= nil, "폭탄병이 있다")
if bomber then
	local victim = fresh("mooni", bomber.lv) -- 맞는 쪽도 폭탄병의 레벨(2026-10-14부터 폭탄병은 굽잇길 Lv.14에만 산다 — 전에는 사냥터의 Lv.5를 Lv.4가 맞았다)
	victim.x, victim.y = math.clamp(bomber.x + 24, bomber.a, bomber.b), bomber.y
	local burst, hurtN = false, 0
	local hp0 = bomber.hp
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
	expect(not burst and hurtN >= 1, ("폭탄병이 터뜨려 맞는다(%d번) — 「사라졌다」는 일은 없다"):format(hurtN))
	expect(bomber.hp == hp0 and bomber.state ~= "gone" and bomber.state ~= "dead" and bomber.state ~= "spawn", "터뜨린 폭탄병은 사라지지 않는다 " .. bomber.state)
	expect(bomber.def.atk.cd >= 1, "다시 터뜨리기까지 기다린다")
	-- 오래 두면 되풀이해 터뜨린다(한 번 치고 끝나지 않는다)
	for _ = 1, 300 do
		Hero.tick(victim, DT)
		victim.hp = victim.maxHp
		for _, e in room4:step({ [victim.id] = victim }, DT) do
			if e.type == "hurt" then
				hurtN += 1
			end
		end
	end
	expect(hurtN >= 3, ("되풀이해 터뜨린다(%d번)"):format(hurtN))
	-- 맞으면 다른 몬스터처럼 멈칫하고, 잡히면 경험치를 준다
	-- (경험치는 잡은 기술의 길로 준다 — 4)의 검사가 본다)
	room4:damageMob(bomber, bomber.hp + 1, victim.x, victim.id) -- (남은 체력보다 큰 한 방 — Lv.14의 체력은 99999를 넘는다)
	expect(bomber.state == "dead", "폭탄병도 잡힌다")
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
local want = Hero.powerRaw(hero) * combo.hits[1].mul * RULES.dmgScale * (1 + RULES.targetBonus / 100) -- 피해 = 전투력(반올림 전) x 그 타의 배수 x 피해 숫자의 배율 x 쓰임의 보정(갈래를 주지 않으면 누구에게나)
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
	if x.kind == "money" then -- 달돈 말고 재료 · 물약도 떨어진다(2026-10-11) — 달돈을 골라 줍는 것을 본다
		live = x
	end
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
expect(desc.mobs[1].maxHp > 0 and desc.mobs[1].name ~= nil and #desc.snap[1] == 12 and desc.snap[1][9] == 0 and desc.snap[1][10] == 0 and desc.snap[1][11] == 0 and desc.snap[1][12] == 0, "졸개 한 줄의 짜임(일곱째 · 여덟째 = 묶인 · 넘어진 시간 · 아홉째 = 스토리 보스의 패턴 차례 · 열째 ~ 열두째 = 겨눈 자리 · 연속기 · 빠른 패턴)")

-- ---- 가시: 닿으면 약한 피해(최대 체력의 5%) — 사용자 2026-10-08: "맵에 가시 있잖아요 그거 닿으면 데미지 입게 약한데미지 입게하세요" ----
do
	local Physics = req("ReplicatedStorage/shared/lune/sim/physics")
	local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
	local SC = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local scene = SC.scenes.hunt
	-- 사냥터의 가시 구덩이: 가시 칸을 찾는다
	local tx, ty = nil, nil
	for y, row in scene.rows do
		local x = string.find(row, "^", 1, true)
		if x then
			tx, ty = x - 1, y - 1
			break
		end
	end
	expect(tx ~= nil, "사냥터에 가시 칸이 있다")
	local sx, sy = tx * 16 + 8, (ty + 1) * 16 -- 그 칸에 서 있는 자리(발밑)
	expect(Physics.onSpike(scene, sx, sy), "가시 칸에 서 있으면 닿는다")
	eq(Physics.onSpike(scene, sx, sy - 16), false, "가시 위로 뛰어 있는 동안에는 닿지 않는다")
	eq(Physics.onSpike(scene, scene.spawn.x, scene.spawn.y), false, "가시가 없는 자리")
	eq(Physics.onSpike(scene, tx * 16 - 7, sy), false, "가시 칸의 옆 칸")
	eq(RULES.spike, 5, "가시의 피해 = 최대 체력의 5%")
	local room = Room.new("hunt", scene, Random.new(71))
	for i, mob in room.mobs do
		mob.state, mob.t, mob.x = "idle", 0, 5000 + i * 30 -- 졸개는 멀리 치워 둔다
		mob.a, mob.b = 5000, 6000
	end
	local h = Hero.new(1, "axion")
	h.x, h.y, h.invuln = sx, sy, 0
	local function hurts(events)
		local n, dmg = 0, 0
		for _, e in events do
			if e.type == "hurt" and e.hero == h.id then
				n += 1
				dmg += e.dmg
			end
		end
		return n, dmg
	end
	local want = math.max(1, math.floor(h.maxHp * RULES.spike / 100 + 0.5))
	local n, dmg = hurts(room:step({ [h.id] = h }, 0.05))
	eq(n, 1, "가시에 닿으면 맞는다")
	eq(dmg, want, "최대 체력의 5%")
	eq(h.hp, h.maxHp - want, "체력이 그만큼 준다")
	expect(h.invuln > 0, "맞은 뒤 잠깐은 다시 맞지 않는다")
	n = hurts(room:step({ [h.id] = h }, 0.05))
	eq(n, 0, "바로 또 맞지는 않는다")
	-- 닿아 있는 동안: 그 간격(invuln)으로 한 번씩
	local count = 0
	for _ = 1, 60 do
		Hero.tick(h, 0.05)
		count += hurts(room:step({ [h.id] = h }, 0.05))
	end
	expect(count >= 4 and count <= 5, "3초 동안 0.6초마다 한 번씩 " .. count)
	-- 가시에서 나오면 맞지 않는다 · 시작 자리로 돌려보내지지 않는다
	h.x, h.y, h.invuln = scene.spawn.x, scene.spawn.y, 0
	n = hurts(room:step({ [h.id] = h }, 0.05))
	eq(n, 0, "가시 밖에서는 맞지 않는다")
	-- 피해를 받지 않는 버프(버티기) 동안에는 들지 않는다
	local g = Hero.new(2, "axion")
	g.level = 120
	g.skills.ax_brace = 5
	Hero.recalc(g)
	g.hp = g.maxHp
	g.x, g.y, g.invuln = sx, sy, 0
	Buffs.cast(g, "ax_brace", 0)
	local gn = 0
	for _, e in room:step({ [g.id] = g }, 0.05) do
		if e.type == "hurt" then
			gn += 1
		end
	end
	eq(gn, 0, "버티기 동안에는 가시도 아프지 않다")
	-- 체력이 바닥이면 가시에도 쓰러진다
	h.x, h.y, h.invuln, h.hp = sx, sy, 0, 1
	local events = room:step({ [h.id] = h }, 0.05)
	expect(not h.alive, "체력이 바닥이면 가시에 쓰러진다")
	local dead = false
	for _, e in events do
		dead = dead or (e.type == "hurt" and e.dead == true)
	end
	expect(dead, "쓰러졌다고 알린다")
end

-- ---- 문 곁의 빈 터: 어느 맵이든 문 위에 몬스터가 겹쳐 서지 않는다 ----
--  2026-10-10에 규칙이 바뀌었다(맵을 화면 두 장으로 줄이면서): 보는 거리를 다 비우지 않고 40점까지만 친다(어느 몬스터든 문에서 56점 = 3.5칸). 들어서자마자 맞지 않게 하는 일은 Hero.arrive가 맡는다(아래).
--  몬스터가 돌아다니는 구간의 가까운 끝은 모든 문에서 (그 몬스터가 보는 거리 + 한 칸)보다 멀다(공방의 maps.js gateNeed — 2026-10-09 고갯길 초입에서 들어서자마자 화살을 맞아 넣은 규칙)
do
	local n = 0
	for key, sc in SCENES.scenes do
		if sc.swarm then
			continue -- 던전의 몰려오기(2026-10-22): 몬스터는 양 끝의 수정 문(왼쪽 = 나가는 문)에서 나와 맵 전체를 달린다 — 사람은 가운데에서 들어선다(Hero.arrive)
		end
		for _, m in sc.mobs do
			local see = COMBAT.mobs[m.kind].see
			for _, p in sc.portals do
				if math.abs(p.y - m.y) > 32 then
					continue -- 층이 다르면 서로 알아채지 못한다(망루의 안)
				end
				local gap = if p.x < m.range[1] then m.range[1] - p.x elseif p.x > m.range[2] then p.x - m.range[2] else 0
				n += 1
				expect(gap >= math.min(see, 40) + 16 - 0.01, ("%s: %s(%.0f~%.0f)이 문(%s · %d)에서 %.0f점 — 56점(보는 거리 %d)보다 가깝다"):format(key, m.kind, m.range[1], m.range[2], p.to, p.x, gap, see))
			end
		end
	end
	expect(n > 100, "문과 몬스터의 사이를 잰 것이 있다")
end

-- ---- 쉬는 곳(쉼터 · 작은 마을 · 마을): 가만히 서 있으면 체력이 찬다 ----
do
	local R = RULES.rest
	local sc = SCENES.scenes.r1af
	expect(sc.rest == true and #sc.mobs == 0, "세 갈래 길은 쉬는 곳이고 몬스터가 없다")
	expect(SCENES.scenes.r1bv.rest == true and #SCENES.scenes.r1bv.mobs == 0, "고갯마루 주막도 쉬는 곳이다")
	expect(SCENES.scenes.town.rest == true and SCENES.scenes.in_store.rest == true, "마을과 건물의 실내도 쉬는 곳이다")
	expect(SCENES.scenes.hunt.rest == false and SCENES.scenes.r1b1.rest == false and SCENES.scenes.r1b3.rest == false, "사냥터와 길 맵은 쉬는 곳이 아니다")
	local room = Room.new("r1af", sc, Random.new(3))
	local h = Hero.new(1, "axion")
	h.x, h.y = sc.spawn.x, sc.spawn.y
	h.hp = 1
	local heroes = { [h.id] = h }
	local function rest(r, sec)
		local healed, times = 0, 0
		for _ = 1, math.floor(sec / DT + 0.5) do
			for _, e in r:step(heroes, DT) do
				if e.type == "healed" then
					healed += e.amount
					times += 1
				end
			end
		end
		return healed, times
	end
	local one = math.floor(h.maxHp * R.heal / 100 + 0.5)
	eq(rest(room, R.wait + R.every - 0.3), 0, "가만히 선 지 얼마 안 됐으면 차지 않는다")
	local got, times = rest(room, 0.6)
	eq(times, 1, "기다린 뒤에 한 번 찬다")
	eq(got, one, "한 번에 최대 체력의 10%")
	eq(h.hp, 1 + one, "체력이 그만큼 올랐다")
	got, times = rest(room, R.every * 3)
	eq(times, 3, "그 뒤로 1초에 한 번씩")
	eq(h.hp, 1 + one * 4, "네 번 찼다")
	-- 움직이면 처음부터 다시 센다
	h.x += 12
	eq(rest(room, R.wait + R.every - 0.3), 0, "움직이면 처음부터 다시 센다")
	-- 맞으면(체력이 줄면) 처음부터 다시 센다
	rest(room, 0.6)
	h.hp -= 1
	eq(rest(room, R.wait + R.every - 0.3), 0, "체력이 줄면 처음부터 다시 센다")
	-- 가득 차면 멈춘다
	rest(room, 30)
	eq(h.hp, h.maxHp, "가득 찬다")
	eq(rest(room, 5), 0, "가득 차면 더 차지 않는다")
	-- 쓰러진 사람은 차지 않는다
	h.hp, h.alive = 0, false
	eq(rest(room, 6), 0, "쓰러진 사람은 차지 않는다")
	h.alive = true
	-- 사냥터에서는 차지 않는다
	local field = Room.new("r1b1", SCENES.scenes.r1b1, Random.new(4))
	h.x, h.y, h.hp, h.rest = SCENES.scenes.r1b1.portals[1].x, SCENES.scenes.r1b1.portals[1].y, 1, nil
	-- 들어선 뒤 RULES.arrive초는 피해를 받지 않는다(문 곁에도 몬스터가 있다)
	h.invuln = 0
	Hero.arrive(h)
	eq(h.invuln, COMBAT.rules.arrive, "들어서면 잠깐 피해를 받지 않는다")
	rest(field, COMBAT.rules.arrive - 0.2)
	eq(h.hp, 1, "들어선 직후에는 문 앞에 서 있어도 맞지 않는다")
	h.invuln = 99 -- 아래는 쉬는 곳의 규칙만 본다(맞아서 체력이 바뀌지 않게)
	eq(rest(field, 8), 0, "사냥터에서는 가만히 있어도 차지 않는다")
	h.invuln = 0
end
