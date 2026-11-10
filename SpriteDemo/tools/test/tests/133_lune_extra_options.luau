-- 「달의 계승자」 — 장비 추가 옵션 · 윤슬 조각(2026-11-07 — 공방 js/lune/design/items.js 4-1b EXTRA · 게임 shared/lune/sim/items.luau).
--  사용자: "모든 장비에 메이플스토리 추가옵션 같은 개념을 부여할거야 … 150제 장비는 3가지의 추가 옵션이 부여된다 장비 능력치 옆에 연두색으로 + 몇 이라고 뜨고 …
--   현재 우리 게임에 존재하는 모든 능력치들이 동등환 확률로 부여될수 있고 장비가 태어날때 완전한 랜덤으로 부여되는 능력치야 그리고 이 능력치를 재설정 할수있는 도구가 있는데"
--  가짜 환경은 추가 옵션을 끈다(mock.luau의 shared.LUNE_NOEXTRA) — 이 파일만 켠다.
shared.LUNE_NOEXTRA = false
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Market = req("ReplicatedStorage/shared/lune/sim/market")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Passives = req("ReplicatedStorage/shared/lune/sim/passives")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local ItemInfo = req("ReplicatedStorage/shared/lune/ui/itemInfo")
local Odds = req("ReplicatedStorage/shared/lune/ui/odds")
local EX = Items.EXTRA
local K = #EX.pool

-- ① 줄 수: Lv.150 이상 3 · 70 이상 2 · 그 아래 1
eq(K, 14, "종류는 열네 가지(힘 · 민첩 · 지능 · 운 · 올스탯 · 공격력 · 방어력 · 최대 체력 · 크리티컬 확률 · 크리티컬 데미지 · 데미지 · 최종 데미지 · 받는 피해 감소 · 이동 속도)")
eq(Items.exCount(150), 3, "Lv.150 장비 = 3줄")
eq(Items.exCount(200), 3, "Lv.200 = 3줄")
eq(Items.exCount(149), 2, "Lv.149 = 2줄")
eq(Items.exCount(70), 2, "Lv.70 = 2줄")
eq(Items.exCount(69), 1, "Lv.69 = 1줄")
eq(Items.exCount(1), 1, "Lv.1 = 1줄")

-- ② 굴리기: 종류는 겹치지 않고 · 값은 그 범위 안 · 종류마다 같은 확률(n/k)
do
	local rng = Random.new(7)
	local seen, bad, n = {}, 0, 7000
	for _ = 1, n do
		local ex = Items.rollExtra(150, rng)
		local here = {}
		if #ex ~= 3 then
			bad += 1
		end
		for _, e in ex do
			local lo, hi = Items.exRange(e.k, 150)
			if here[e.k] or e.v < lo or e.v > hi or e.v ~= math.floor(e.v) then
				bad += 1
			end
			here[e.k] = true
			seen[e.k] = (seen[e.k] or 0) + 1
		end
	end
	eq(bad, 0, "7000번 굴려 줄 수 · 겹침 · 범위가 틀린 것")
	local want = n * 3 / K
	local worst = 0
	for _, p in EX.pool do
		worst = math.max(worst, math.abs((seen[p.id] or 0) - want) / want)
	end
	expect(worst < 0.08, ("종류마다 같은 확률(가장 먼 것이 기대의 %.1f%% 차이 — 8%% 안)"):format(worst * 100))
	for _, p in EX.pool do
		local lo, hi = Items.exRange(p.id, 150)
		expect(lo >= 1 and hi >= lo, "범위 " .. p.id .. (" %d~%d"):format(lo, hi))
		local lo1 = Items.exRange(p.id, 1)
		expect(lo1 >= 1, "Lv.1에서도 적어도 1 " .. p.id)
	end
	local alo, ahi = Items.exRange("str", 150)
	eq(alo, math.floor(0.4 * N.armorStat(150) + 0.5), "힘 = 0.4 x 그 레벨 방어구 올스탯부터")
	eq(ahi, math.floor(N.armorStat(150) + 0.5), "힘 = 1.0 x 그 레벨 방어구 올스탯까지")
	local clo, chi = Items.exRange("crit", 150)
	eq(clo .. "~" .. chi, "1~3", "Lv.150 크리티컬 확률 1~3%")
end

-- ③ 태어날 때: 가방에 들어오면 붙는다 · 저장 → 불러오기에 그대로 · 옛 저장(9째가 없는 것)은 불러올 때 굴린다
local h = Hero.new(1, "axion")
h.level = 150
Hero.recalc(h)
for _, it in h.equip do
	eq(#(it.ex or {}), 1, "처음 받는 차림(Lv.1)에도 1줄 " .. it.slot)
end
local it = Items.make("weapon", 140, Items.NORMAL, "axion")
eq(it.ex, nil, "만들기만 하면 아직 없다(가방 · 장비 칸에 들어올 때 태어난다)")
Bag.add(h, it)
eq(#it.ex, 2, "Lv.140 무기 = 2줄")
do
	local saved = Bag.pack(h)
	local h2 = Hero.new(2, "axion")
	Bag.unpack(h2, saved)
	local same = true
	for i = 1, Bag.size(h2) do
		local a, b = h.gear[i], h2.gear[i]
		if (a == nil) ~= (b == nil) or (a and (#a.ex ~= #b.ex or a.ex[1].k ~= b.ex[1].k or a.ex[1].v ~= b.ex[1].v or a.ex[2].v ~= b.ex[2].v)) then
			same = false
		end
	end
	expect(same, "저장 → 불러오기: 추가 옵션이 그대로")
	-- 옛 저장(2026-11-07 전 — 9째가 없다)
	local old = { "weapon", 150, Items.NORMAL, 3, "axion", 0, 0 }
	saved.gear[1] = old
	local h3 = Hero.new(3, "axion")
	Bag.unpack(h3, saved)
	eq(#(h3.gear[1].ex or {}), 3, "옛 장비(9째 없음)는 불러올 때 3줄이 붙는다(Lv.150)")
	-- 망가진 9째(모르는 종류 · 겹침)도 다시 굴린다
	saved.gear[1] = { "weapon", 150, Items.NORMAL, 3, "axion", 0, 0, false, { "str", 5, "str", 7, "xx", 1 } }
	local h4 = Hero.new(4, "axion")
	Bag.unpack(h4, saved)
	expect(Items.exValid(h4.gear[1]), "꼴이 틀린 추가 옵션은 새로 굴린다")
end
do
	local row = Market.pack(it)
	eq(#row, 9, "경매장 장부: 9째 = 추가 옵션")
	local back = Market.unpack(row)
	eq(back.ex[1].k .. back.ex[1].v .. back.ex[2].k .. back.ex[2].v, it.ex[1].k .. it.ex[1].v .. it.ex[2].k .. it.ex[2].v, "경매장 장부 → 물건: 추가 옵션이 그대로(산 사람에게 같은 옵션)")
	local bare = Market.pack(Items.make("hat", 10, Items.NORMAL))
	eq(#bare, 7, "추가 옵션 · 이름표가 없는 장비의 줄은 7칸(빈 데가 없다)")
end

-- ④ 셈에 든다: 공격력 · 올스탯 · 방어력 = Items.sum · 힘(주스탯) = Hero.spec · 크리티컬 · 최종 데미지 = 패시브의 합 · 최대 체력 · 이동 속도 = 키트 · 데미지 = 버프의 배수
do
	local w = h.equip.weapon
	local function set(list)
		w.ex = list
	end
	set({})
	local base = Items.sum(Bag.worn(h))
	local sp0 = Hero.spec(h)
	local crit0, mul0 = Passives.crit(h, false)
	local run0 = Kit.move(h)
	local hp0 = Hero.maxHpOf(h)
	local dmg0 = Buffs.dmg(h)
	local fin0 = Passives.finalMul(h)
	local cut0 = Passives.cut(h, false)
	local pow0 = Hero.power(h)
	set({ { k = "atk", v = 10 }, { k = "all", v = 20 }, { k = "def", v = 30 } })
	local s1 = Items.sum(Bag.worn(h))
	eq(s1.atk - base.atk, 10, "추가 옵션 공격력 +10 → 공격력 합 +10")
	eq(s1.stat - base.stat, 20, "추가 옵션 올스탯 +20 → 올스탯 합 +20")
	eq(s1.def - base.def, 30, "추가 옵션 방어력 +30 → 방어력 합 +30")
	expect(Hero.power(h) > pow0, "공격력 · 올스탯이 붙으면 전투력이 오른다")
	set({ { k = "str", v = 50 }, { k = "dex", v = 7 } })
	local sp1 = Hero.spec(h)
	eq(sp1.stats.str - sp0.stats.str, 50, "추가 옵션 힘 +50 → 힘 +50")
	eq(sp1.stats.dex - sp0.stats.dex, 7, "추가 옵션 민첩 +7 → 민첩 +7")
	eq(sp1.main - sp0.main, 50, "액시온의 주스탯(힘)에 든다")
	eq(sp1.stats.int - sp0.stats.int, 0, "지능은 그대로")
	set({ { k = "crit", v = 3 }, { k = "critDmg", v = 5 }, { k = "final", v = 2 } })
	local crit1, mul1 = Passives.crit(h, false)
	eq(crit1 - crit0, 3, "크리티컬 확률 +3%")
	expect(math.abs((mul1 - mul0) - 0.05) < 1e-9, "크리티컬 데미지 +5%(배수 +0.05)")
	expect(math.abs(Passives.finalMul(h) - fin0 - 0.02) < 1e-9, "최종 데미지 +2%")
	set({ { k = "hp", v = 4 }, { k = "run", v = 3 }, { k = "dmg", v = 4 } })
	expect(math.abs(Kit.move(h) - run0 - 0.03) < 1e-9, "이동 속도 +3%")
	eq(Hero.maxHpOf(h), math.floor(hp0 * 1.04 + 0.5), "최대 체력 +4%")
	expect(math.abs(Buffs.dmg(h) / dmg0 - 1.04) < 1e-9, "데미지 +4%(피해의 버프 배수에)")
	expect(Hero.power(h) > pow0, "데미지 %도 전투력에 든다")
	set({ { k = "cut", v = 3 } })
	expect(math.abs(Passives.cut(h, false) / cut0 - 0.97) < 1e-9, "받는 피해 감소 3% → 받는 피해 x 0.97")
	w.broken = true
	expect(Kit.move(h) == run0 and Passives.cut(h, false) == cut0, "부서진 장비(흔적)의 추가 옵션은 쳐 주지 않는다")
	w.broken = false
	set({ { k = "str", v = 5 } })
end

-- ⑤ 윤슬 조각: 없으면 안 된다 · 있으면 하나를 쓰고 줄 수 그대로 새로 굴린다 · 낀 장비도
do
	local tool = EX.reroll.id
	local g = Items.goods(tool)
	expect(g ~= nil and g.tab == "etc" and g.bound == true, "윤슬 조각 = 기타 탭 · 경매장에 올리지 못한다")
	local res, why = Bag.reroll(h, it.id)
	eq(res, nil, "조각이 없으면 재설정하지 못한다")
	eq(why, EX.words.noTool, "까닭 = 「윤슬 조각이 없다」")
	Bag.give(h, tool, 3)
	local before = Items.packEx(it)
	local rng = Random.new(99)
	local changed = false
	for _ = 1, 3 do
		local ex = Bag.reroll(h, it.id, rng)
		expect(ex ~= nil and #ex == 2, "재설정: Lv.140 = 2줄 그대로")
		if table.concat(Items.packEx(it), ",") ~= table.concat(before, ",") then
			changed = true
		end
	end
	expect(changed, "세 번 굴리면 옵션이 바뀐다")
	eq(Bag.count(h, tool), 0, "한 번에 하나씩 쓴다(3개 → 0개)")
	Bag.give(h, tool, 1)
	local wid = h.equip.weapon.id
	expect(Bag.reroll(h, wid, rng) ~= nil, "낀 장비도 재설정된다")
	h.equip.weapon.broken = true
	Bag.give(h, tool, 1)
	local r2, why2 = Bag.reroll(h, wid, rng)
	expect(r2 == nil and why2 ~= nil, "부서진 흔적은 재설정하지 못한다")
	h.equip.weapon.broken = false
	eq(Bag.count(h, tool), 1, "못 했으면 조각이 줄지 않는다")
end

-- ⑥ 상세 판: 같은 종류 줄 끝의 연두 「+n」(4째 칸) · 그 밖은 아래에 연두 줄 · 확률 창의 글(줄마다 합 100%)
do
	local arm = Items.make("hat", 150, Items.NORMAL)
	arm.ex = { { k = "all", v = 21 }, { k = "crit", v = 2 }, { k = "dex", v = 40 } }
	local info = ItemInfo.gear(arm, { level = 150, class = "axion" }, nil, false)
	local statRow, critRow, dexRow
	for _, r in info.rows do
		if r[1] == Items.data.WORDS.stat then
			statRow = r
		elseif r[1] == "크리티컬 확률" then
			critRow = r
		elseif r[1] == "민첩" then
			dexRow = r
		end
	end
	expect(statRow and statRow[4] == "+21", "올스탯 줄 끝에 「+21」(연두 — 4째 칸)")
	expect(critRow and critRow[2] == "+2%" and critRow[3] == "extra", "크리티컬 확률은 아래 줄 「+2%」 연두")
	expect(dexRow and dexRow[2] == "+40" and dexRow[3] == "extra", "민첩은 아래 줄 「+40」 연두")
	local o = Odds.reroll(150)
	eq(#o.head, 5, "확률 창 머리 글: 줄 수 · 1~3째 줄 · 값")
	eq(#o.rows, K, "확률 창: 종류 열넷과 범위")
	local sum = 0
	for i = 1, 3 do
		local left = K - i + 1
		sum = left * tonumber(("%.4f"):format(100 / left))
		expect(math.abs(sum - 100) < 0.01, ("%d째 줄: %d가지 x %.4f%% = 100%%"):format(i, left, 100 / left))
	end
	expect(string.find(o.head[2], "7.1429", 1, true) ~= nil, "첫 줄 = 14가지 가운데 하나 — 각 7.1429%")
end
shared.LUNE_NOEXTRA = true
