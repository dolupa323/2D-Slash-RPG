-- 「달의 계승자」 — 장비 · 가방 · 강화 · 상점의 셈(shared/lune/sim/items.luau · bag.luau). 공방의 식과 같은 값인지(checks) · 규칙이 지켜지는지
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local D = req("ReplicatedStorage/shared/lune/data/items.generated")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local pixelText = req("Client/ui/pixelText")
local C = D.checks
local E = D.ENHANCE

local function near(a, b, msg)
	expect(math.abs(a - b) < 1e-4 * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

-- ---- 1) 공방과 같은 값 ----
for _, c in C.names do
	eq(Items.name(c[1]), c[2], "이름 " .. c[2])
end
for _, c in C.score do
	near(Items.score(c[1]), c[2], "점수 " .. Items.name(c[1]))
end
for _, c in C.power do
	eq(Items.power(c[1], c[2], c[3]), c[4], ("전투력 Lv.%d 효율 %s 장비 %d"):format(c[1], tostring(c[2]), #c[3]))
end
for _, c in C.cut do
	near(Items.cut(c[1], c[2]), c[3], ("방어 장비 %d · 몬스터 Lv.%d"):format(#c[1], c[2]))
end
for _, c in C.stageOf do
	eq(Items.stageOf(c[1]), c[2], "떨어지는 단계 Lv." .. c[1])
end
for _, c in C.dustDrop do
	local chance, amount = Items.dustDrop(c[1])
	near(chance, c[2], "달가루 확률 Lv." .. c[1])
	near(amount, c[3], "달가루 양 Lv." .. c[1])
	expect(amount >= 1, "떨어지면 하나 이상 Lv." .. c[1])
end
for _, c in C.enhanceDust do
	eq(Items.enhanceDust(c[1], c[2]), c[3], ("강화 달가루 단계 %d · %d성"):format(c[1], c[2]))
end
for _, c in C.starCap do
	eq(Items.starCap(c[1]), c[2], "별 상한 단계 " .. c[1])
end
for _, c in C.dismantle do
	eq(Items.dismantle(c[1]), c[2], "분해 " .. Items.name(c[1]))
end
for _, c in C.transfer do
	eq(Items.transfer({ star = c[1], stage = c[2] }, { star = c[3], stage = c[4] }), c[5], ("별 옮기기 %d성(단계 %d) → %d성(단계 %d)"):format(c[1], c[2], c[3], c[4]))
end
for _, c in C.stockPrice do
	for i, L in { 1, 29, 30, 60, 100 } do
		eq(Items.stockPrice(Items.stock(c[1]), L), c[2][i], ("상점 값 %s Lv.%d"):format(c[1], L))
	end
end
for _, c in C.startPower do
	eq(Hero.power(Hero.new(1, c[1])), c[2], "새 캐릭터의 전투력 " .. c[1])
end

-- ---- 2) 자료의 짜임 ----
local pct = 0
for _, q in D.QUALITY do
	pct += q.pct
end
eq(pct, 100, "성능 단의 확률 합")
eq(D.QUALITY[D.NORMAL].bonus, 0, "보통은 0%")
eq(#E.table, E.max, "강화 표는 22줄")
eq(#E.essence, E.max, "정수 표는 22줄")
for i, row in E.table do
	near(row[1] + row[2] + row[3], 100, "강화 확률의 합 " .. i)
end
for _, s in D.STOCK do
	expect(D.NPCDO[s.npc] ~= nil, "상점 물건을 파는 주민 " .. s.id)
	expect(s.id == "potion" or (typeof(s.price) == "number" and s.price > 0), "값이 있다 " .. s.id)
end
-- 이름이 가방 창의 이름 줄(한 줄 · 폭 166 — 작은 글씨)에 별까지 붙여 들어간다 — 가장 긴 이름까지
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
local longest = 0
for _, stage in D.STAGES do
	for qi in D.QUALITY do
		for who in D.KINDS do
			longest = math.max(longest, (pixelText.Measure(Items.name(Items.make("weapon", stage, qi, who)), "small")))
		end
		for _, slot in D.ARMOR do
			longest = math.max(longest, (pixelText.Measure(Items.name(Items.make(slot, stage, qi)), "small")))
		end
	end
end
expect(longest + (pixelText.Measure(" +22", "small")) <= 166, ("가장 긴 장비 이름이 별까지 한 줄(166)에 들어감 — 폭 %d"):format(longest))
expect(longest <= 84 * 3, "장비 창의 이름 칸(84 x 세 줄)에도 들어간다")

-- ---- 3) 새 캐릭터의 차림 ----
local h = Hero.new(1, "reaper")
eq(#Bag.worn(h), 5, "무기와 방어구 네 부위를 입고 있다")
eq(h.equip.weapon.who, "reaper", "내 직업의 무기")
eq(#h.gear, 0, "가방은 비어 있다")
eq(Bag.size(h), D.BAG.base, "가방 24칸")
near(Hero.cut(h, 1), N.armorCut(1, 1), "Lv.1 방어구 네 부위 = 같은 레벨의 방어")
expect(Hero.cut(h, 20) < Hero.cut(h, 1), "레벨이 높은 몬스터에게는 덜 막는다")

-- ---- 4) 끼기 · 벗기 ----
local better = Items.make("weapon", 1, 5, "reaper")
expect(Bag.add(h, better), "가방에 넣는다")
local before = Hero.power(h)
local oldId = h.equip.weapon.id
expect(Bag.equip(h, better.id), "낀다")
eq(h.equip.weapon, better, "무기가 바뀌었다")
eq(h.gear[1].id, oldId, "끼고 있던 것은 그 칸으로 들어간다")
expect(Hero.power(h) >= before, "빼어난 무기는 전투력이 같거나 높다")
local other = Items.make("weapon", 1, 3, "axion")
Bag.add(h, other)
local ok, why = Bag.equip(h, other.id)
expect(not ok and why == "다른 직업의 무기다", "남의 무기는 못 낀다")
local high = Items.make("hat", 10, 3)
Bag.add(h, high)
ok, why = Bag.equip(h, high.id)
expect(not ok and string.find(why, "Lv.10") ~= nil, "레벨이 모자라면 못 낀다")
h.level = 10
expect(Bag.equip(h, high.id), "레벨이 되면 낀다")
expect(Hero.cut(h, 10) > 0, "방어구가 피해를 줄인다")
eq(Bag.equip(h, 9999), nil, "없는 번호")
eq(Bag.equip(h, "x"), nil, "번호가 아닌 것")
expect(Bag.unequip(h, "hat"), "벗는다")
eq(h.equip.hat, nil, "모자 자리가 비었다")
eq(Bag.unequip(h, "hat"), nil, "안 낀 것은 못 벗는다")
local naked = Hero.new(2, "axion")
for _, slot in D.GEAR do
	Bag.unequip(naked, slot)
end
eq(Hero.cut(naked, 1), 0, "다 벗으면 방어가 0")
expect(Hero.power(naked) < Hero.power(Hero.new(3, "axion")), "다 벗으면 전투력이 낮다")
-- 가방이 가득 차면
local full = Hero.new(4, "mooni")
for i = 1, Bag.size(full) do
	expect(Bag.add(full, Items.make("glove", 1, 3)), "가방에 넣는다 " .. i)
end
ok, why = Bag.add(full, Items.make("glove", 1, 3))
expect(not ok and why == "가방이 가득 찼다", "가득 차면 못 넣는다")
ok, why = Bag.unequip(full, "weapon")
expect(not ok, "가득 차면 못 벗는다")
-- 가방 늘리기
eq(Bag.growCost(full), D.BAG.costs[1], "처음 늘리는 값")
ok, why = Bag.grow(full)
expect(not ok and why == "달돈이 모자란다", "돈이 없으면 못 늘린다")
full.money = 1e9
for i = 1, D.BAG.times do
	expect(Bag.grow(full), "늘린다 " .. i)
end
eq(Bag.size(full), D.BAG.base + D.BAG.step * D.BAG.times, "48칸까지")
eq(Bag.grow(full), nil, "더는 못 늘린다")

-- ---- 5) 분해 ----
local d = Hero.new(5, "axion")
local junk = Items.make("shoes", 20, 1)
junk.star = 3
Bag.add(d, junk)
local dust = Bag.dismantle(d, junk.id)
eq(dust, Items.dismantle(junk), "분해한 달가루")
eq(d.dust, dust, "달가루가 는다")
eq(#d.gear, 0, "분해한 것은 사라진다")
eq(Bag.dismantle(d, d.equip.weapon.id), nil, "끼고 있는 것은 분해하지 못한다")

-- ---- 6) 상점 ----
local b = Hero.new(6, "salamander")
ok, why = Bag.buy(b, "potion", 5)
expect(not ok and why == "달돈이 모자란다", "돈이 없으면 못 산다")
b.money = 100000
local p0, m0 = b.potions, b.money
expect(Bag.buy(b, "potion", 5), "물약 다섯 병")
eq(b.potions, p0 + 5, "물약이 는다")
eq(b.money, m0 - 5 * N.potionAt(1).price, "값을 치른다")
eq(Bag.buy(b, "potion", 0), nil, "0개는 못 산다")
eq(Bag.buy(b, "potion", 1.5), nil, "소수는 못 산다")
eq(Bag.buy(b, "potion", 100000), nil, "한 번에 너무 많이는 못 산다")
eq(Bag.buy(b, "nothing", 1), nil, "없는 물건")
expect(Bag.buy(b, "a1_hat", 1), "Lv.1 모자")
eq(b.gear[1].q, D.NORMAL, "상점의 것은 늘 보통")
ok, why = Bag.buy(b, "w10", 1)
expect(not ok and string.find(why, "Lv.10") ~= nil, "Lv.10 무기는 Lv.10부터")
b.level = 10
expect(Bag.buy(b, "w10", 1), "Lv.10 무기")
eq(b.gear[2].who, "salamander", "내 직업의 무기를 판다")
eq(b.gear[2].stage, 10, "Lv.10")
expect(Bag.buy(b, "dust", 50), "달가루 쉰 개")
eq(b.dust, 50, "달가루가 는다")

-- ---- 7) 강화 ----
local rng = Random.new(7)
local f = Hero.new(7, "axion")
f.level = 20
local w = Items.make("weapon", 20, 3, "axion")
Bag.add(f, w)
ok, why = Bag.enhance(f, w.id, rng)
expect(not ok and why == "달가루가 모자란다", "달가루가 없으면 못 한다")
f.dust = 1e9
local tries, oks = 0, 0
while w.star < Items.starCap(20) and tries < 500 do
	local star0, dust0 = w.star, f.dust
	local info = Items.enhanceInfo(w)
	local result = Bag.enhance(f, w.id, rng)
	tries += 1
	eq(f.dust, dust0 - info.dust, "달가루를 치른다")
	if result == "ok" then
		oks += 1
		eq(w.star, star0 + 1, "붙으면 별 하나")
	else
		eq(result, "fail", "10성까지는 실패해도 그대로다")
		eq(w.star, star0, "별이 그대로")
	end
end
eq(w.star, 5, "Lv.20 장비는 5성까지")
ok, why = Bag.enhance(f, w.id, rng)
expect(not ok and why == "더 붙일 수 없다", "상한을 넘지 못한다")
near(Items.score(w), 4 * 1.07 ^ 20 * 1.04 ^ 5, "별 하나에 4%씩")
-- 확률: 첫 별 95% · 열한째 별 50%
local function rate(star, n)
	local hit = 0
	for _ = 1, n do
		local it = Items.make("weapon", 160, 3, "axion")
		it.star = star
		if Items.enhance(it, rng) == "ok" then
			hit += 1
		end
	end
	return hit / n * 100
end
local r0, r10 = rate(0, 4000), rate(10, 4000)
expect(math.abs(r0 - 95) < 2, ("첫 별은 95%% — %.1f"):format(r0))
expect(math.abs(r10 - 50) < 3, ("열한째 별은 50%% — %.1f"):format(r10))
-- 정수: 11~15성에만 든다
for star = 0, E.max - 1 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = star
	local info = Items.enhanceInfo(it)
	eq(info.essence > 0, star >= 10 and star <= 14, "정수가 드는 별 " .. (star + 1))
	eq(info.drops, star + 1 >= 16 and star ~= 15 and star ~= 20, "실패하면 떨어지는 별 " .. (star + 1))
	eq(info.boom > 0, star + 1 >= 16, "부서질 수 있는 별 " .. (star + 1))
	eq(info.guard, star + 1 == 16 or star + 1 == 17, "파괴 막기를 쓸 수 있는 별 " .. (star + 1))
end
-- 16성부터: 떨어짐 · 부서짐 · 버팀 단계 · 두 번 떨어지면 반드시 성공 · 파괴 막기
local seen = { ok = 0, fail = 0, drop = 0, boom = 0 }
local sureOk, lowest = true, 99
for _ = 1, 3000 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 17
	for _ = 1, 40 do
		if it.broken then
			break
		end
		if it.star >= E.max then
			break
		end
		local star0, sure = it.star, (it.fails or 0) >= E.chance
		local result = Items.enhance(it, rng)
		seen[result] += 1
		if sure and result ~= "ok" then
			sureOk = false
		end
		if result == "drop" then
			eq(it.star, star0 - 1, "한 단계 떨어진다")
		elseif result == "boom" then
			eq(it.star, math.min(E.boomTo, star0), "부서지면 12성 흔적")
			eq(Items.score(it), 0, "부서진 것은 힘이 없다")
		end
		lowest = math.min(lowest, it.star)
	end
end
expect(seen.drop > 0 and seen.boom > 0 and seen.ok > 0, ("떨어지고 부서지고 붙는다(%d · %d · %d)"):format(seen.drop, seen.boom, seen.ok))
expect(sureOk, "두 번 잇달아 떨어지면 다음은 반드시 붙는다")
expect(lowest >= 12, "15성 아래로는 부서질 때만 내려간다(가장 낮은 별 " .. lowest .. ")")
local floorHeld = true
for _ = 1, 2000 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 15
	local result = Items.enhance(it, rng)
	if result == "drop" then
		floorHeld = false
	end
end
expect(floorHeld, "15성은 버팀 단계 — 16성 시도에 실패해도 떨어지지 않는다")
local guarded = 0
for _ = 1, 3000 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 16
	if Items.enhance(it, rng, true) == "boom" then
		guarded += 1
	end
end
eq(guarded, 0, "파괴 막기를 켜면 17성 시도에서 부서지지 않는다")
do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 16
	eq(Items.enhanceInfo(it, true).dust, Items.enhanceInfo(it).dust * E.guard.cost, "파괴 막기는 달가루 세 배")
	it.star = 18
	eq(Items.enhanceInfo(it, true).boom > 0, true, "19성 시도는 막을 수 없다")
end
-- 끼고 있다가 부서지면 가방으로 간다 · 같은 장비로 되살린다
local g = Hero.new(8, "axion")
g.level = 150
g.dust, g.essence = 1e12, 1e6
local sword = Items.make("weapon", 180, 3, "axion")
sword.star = 18
sword.need = 150 -- 보스의 장비는 단계가 레벨보다 높다(낄 수 있는 레벨을 따로 가진다 — 보스 장비가 생기는 단계에서 저장에도 넣는다)
Bag.add(g, sword)
expect(Bag.equip(g, sword.id), "18성 무기를 낀다")
local broke = false
for _ = 1, 4000 do
	local result = Bag.enhance(g, sword.id, rng)
	if result == "boom" then
		broke = true
		break
	elseif result == nil then
		sword.star = 18
	end
end
expect(broke, "언젠가 부서진다")
eq(g.equip.weapon, nil, "부서진 것은 끼고 있을 수 없다")
eq(Bag.find(g, sword.id) ~= nil, true, "흔적이 가방에 남는다")
eq(sword.star, 12, "12성 흔적")
eq(Bag.equip(g, sword.id), nil, "부서진 것은 못 낀다")
eq(Bag.enhance(g, sword.id, rng), nil, "부서진 것은 강화하지 못한다")
local wrong = Items.make("weapon", 170, 3, "axion")
Bag.add(g, wrong)
ok, why = Bag.restore(g, sword.id, wrong.id)
expect(not ok and why == "같은 장비가 아니다", "다른 장비로는 못 되살린다")
local spare = Items.make("weapon", 180, 1, "axion")
Bag.add(g, spare)
expect(Bag.restore(g, sword.id, spare.id), "같은 장비로 되살린다")
eq(sword.broken, false, "되살아났다")
eq(sword.star, 12, "12성으로")
eq(Bag.find(g, spare.id), nil, "쓴 장비는 사라진다")

-- ---- 8) 별 옮기기 ----
local t = Hero.new(9, "riven")
t.level = 30
t.equip.weapon.star = 5
local old = t.equip.weapon
local new = Items.make("weapon", 20, 4, "riven")
Bag.add(t, new)
expect(Bag.transfer(t, old.id, new.id), "별을 옮긴다")
eq(new.star, 4, "하나 낮아져 4성")
eq(Bag.find(t, old.id), nil, "옛 장비는 사라진다")
eq(t.equip.weapon, new, "끼고 있던 것을 옮겼으면 새것을 낀다")
local hat = Items.make("hat", 20, 3)
Bag.add(t, hat)
ok, why = Bag.transfer(t, new.id, hat.id)
expect(not ok and why == "같은 부위끼리만 옮긴다", "다른 부위로는 못 옮긴다")
local plain = Items.make("weapon", 30, 3, "riven")
Bag.add(t, plain)
local zero = Items.make("weapon", 30, 3, "riven")
Bag.add(t, zero)
ok, why = Bag.transfer(t, zero.id, plain.id)
expect(not ok and why == "옮길 별이 없다", "별이 없는 것은 옮길 것이 없다")

-- ---- 9) 창고 ----
local k = Hero.new(10, "axion")
local thing = Items.make("suit", 1, 2)
Bag.add(k, thing)
expect(Bag.storeIn(k, thing.id), "창고에 넣는다")
eq(#k.gear, 0, "가방에서 빠진다")
eq(#k.store, 1, "창고에 들어간다")
eq(Bag.equip(k, thing.id), nil, "창고의 것은 바로 못 낀다")
eq(Bag.dismantle(k, thing.id), nil, "창고의 것은 분해하지 못한다")
expect(Bag.storeOut(k, thing.id), "창고에서 뺀다")
eq(#k.gear, 1, "가방으로 돌아온다")
eq(Bag.storeIn(k, k.equip.weapon.id), nil, "끼고 있는 것은 못 넣는다")
for i = 1, Bag.storeSize(k) do
	local it = Items.make("hat", 1, 3)
	Bag.add(k, it)
	expect(Bag.storeIn(k, it.id), "창고에 넣는다 " .. i)
end
ok, why = Bag.storeIn(k, thing.id)
expect(not ok and why == "창고가 가득 찼다", "창고가 가득 차면 못 넣는다")

-- ---- 10) 떨어지는 것 ----
local roll = Random.new(11)
local n, mine, others, armor = 200000, 0, 0, 0
local byQ = table.create(#D.QUALITY, 0)
for _ = 1, n do
	local it = Items.rollDrop(roll, 25, "mooni")
	if it then
		eq(it.stage, 20, "Lv.25 몬스터는 Lv.20 장비")
		byQ[it.q] += 1
		if it.slot ~= "weapon" then
			armor += 1
		elseif it.who == "mooni" then
			mine += 1
		else
			others += 1
		end
	end
end
local function pctOf(x)
	return x / n * 100
end
expect(math.abs(pctOf(mine) - D.DROP.weapon) < 0.06, ("내 무기 0.2%% — %.3f"):format(pctOf(mine)))
expect(math.abs(pctOf(others) - D.DROP.other) < 0.06, ("남의 무기 0.2%% — %.3f"):format(pctOf(others)))
expect(math.abs(pctOf(armor) - D.DROP.armor) < 0.08, ("방어구 0.4%% — %.3f"):format(pctOf(armor)))
local total = mine + others + armor
for i, q in D.QUALITY do
	expect(math.abs(byQ[i] / total * 100 - q.pct) < 5, ("성능 %s %d%% — %.1f"):format(q.name, q.pct, byQ[i] / total * 100))
end
expect(byQ[1] > 0 and byQ[5] > 0, "보통 아래도, 위도 나온다")
-- 벌칙 동안에는 덜 나온다
local weakN = 0
for _ = 1, n do
	if Items.rollDrop(roll, 25, "mooni", 0.2) then
		weakN += 1
	end
end
expect(weakN < total * 0.35, ("벌칙 동안 장비가 덜 나온다(%d → %d)"):format(total, weakN))

-- ---- 11) 저장 ----
local s = Hero.new(12, "mooni")
s.level = 20
local keep = Items.make("glove", 20, 5)
keep.star = 4
Bag.add(s, keep)
Bag.add(s, Items.make("weapon", 20, 1, "axion"))
local stored = Items.make("hat", 10, 2)
Bag.add(s, stored)
Bag.storeIn(s, stored.id)
s.dust, s.essence = 321, 7
s.money = 1e7
Bag.grow(s)
Bag.equip(s, keep.id)
local back = Hero.unpack(12, Hero.pack(s))
expect(back ~= nil, "저장한 것을 되살린다")
eq(Hero.power(back), Hero.power(s), "전투력이 같다")
eq(back.equip.glove.star, 4, "낀 장비의 별")
eq(back.equip.glove.q, 5, "낀 장비의 성능")
eq(#back.gear, #s.gear, "가방의 장비 수")
eq(#back.store, 1, "창고")
eq(back.dust, 321, "달가루")
eq(back.essence, 7, "정수")
eq(Bag.size(back), Bag.size(s), "늘린 가방")
-- 장비가 생기기 전에 저장된 캐릭터는 처음 차림을 받는다
local oldSave = Hero.pack(Hero.new(13, "riven"))
oldSave.bag = nil
local revived = Hero.unpack(13, oldSave)
eq(#Bag.worn(revived), 5, "옛 저장에는 처음 차림을 준다")
-- 깨진 자료: 이상한 장비는 버린다
local bad = Hero.pack(s)
bad.bag.gear[1] = { "weapon", 20, 9, 0, "axion", 0, 0 } -- 없는 성능 단
table.insert(bad.bag.gear, { "wing", 20, 3, 0, "", 0, 0 }) -- 없는 부위
table.insert(bad.bag.gear, { "hat", 20, 3, 22, "", 0, 0 }) -- 상한을 넘는 별
table.insert(bad.bag.equip, { "weapon", 20, 3, 0, "axion", 0, 0 }) -- 남의 무기를 끼고 있다
bad.bag.dust = -5
local fixed = Hero.unpack(12, bad)
expect(fixed ~= nil, "깨진 자료도 캐릭터는 살린다")
eq(fixed.dust, 0, "이상한 달가루는 0으로")
for _, it in fixed.gear do
	expect(Items.valid(it), "남은 장비는 꼴이 맞다")
end
expect(fixed.equip.weapon == nil or fixed.equip.weapon.who == "mooni", "남의 무기는 끼고 있지 않다")

-- ---- 12) 화면에 보내는 것 ----
local v = Bag.view(s)
eq(v.size, Bag.size(s), "가방 칸 수")
eq(v.dust, 321, "달가루")
expect(v.equip.glove ~= nil and v.equip.glove.id == keep.id, "낀 장비")
eq(#v.gear, #s.gear, "가방의 장비")

-- ---- 13) 떨어진 장비와 달가루를 줍는다 ----
do
	local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(3))
	local me = Hero.new(21, "axion")
	me.x, me.y = 200, 176
	local gear = room:addDrop({ kind = "gear", item = Items.make("hat", 1, 4), amount = 1 }, 205, 176, me.id)
	local dustDrop = room:addDrop({ kind = "dust", amount = 7 }, 210, 176, me.id)
	local shown = Room.dropView(gear)
	expect(shown.item ~= nil and shown.item.slot == "hat" and shown.item.q == 4, "떨어진 장비가 무엇인지 알린다")
	eq(#room:describe().drops, 2, "방에 들어온 사람도 떨어진 것을 본다")
	expect(room:pickup(me, gear.id) ~= nil, "장비를 줍는다")
	eq(#me.gear, 1, "가방에 들어온다")
	eq(me.gear[1].q, 4, "성능이 그대로")
	expect(room:pickup(me, dustDrop.id) ~= nil, "달가루를 줍는다")
	eq(me.dust, 7, "달가루가 는다")
	-- 가방이 가득 차면 줍지 못하고, 물건은 그대로 남는다
	for _ = 1, Bag.free(me) do
		Bag.add(me, Items.make("glove", 1, 3))
	end
	local more = room:addDrop({ kind = "gear", item = Items.make("suit", 1, 3), amount = 1 }, 205, 176, me.id)
	local got, why = room:pickup(me, more.id)
	expect(got == nil and why == "가방이 가득 찼다", "가방이 가득 차면 못 줍는다")
	expect(room.drops[more.id] ~= nil, "못 주운 것은 그대로 남는다")
	-- 졸개를 잡으면 장비와 달가루가 정한 확률로 나온다(Lv.25 졸개 십만 마리)
	local hunter = Hero.new(22, "reaper")
	local gearN, dustN, dustSum, kills = 0, 0, 0, 100000
	local mob = { lv = 25, x = 100, y = 176, def = { hp = 1 } }
	for _ = 1, kills do
		for _, d in room:lootFor(hunter, mob) do
			if d.kind == "gear" then
				gearN += 1
			else
				dustN += 1
				dustSum += d.amount
			end
			room.drops[d.id] = nil
		end
	end
	local want = D.DROP.weapon + D.DROP.other + D.DROP.armor
	expect(math.abs(gearN / kills * 100 - want) < 0.15, ("졸개 백 마리에 장비 %.1f개 — %.2f"):format(want, gearN / kills * 100))
	local avg = D.DUST.kill * (25 / 10) ^ 3
	expect(math.abs(dustSum / kills - avg) < avg * 0.06, ("달가루 한 마리 평균 %.3f — %.3f"):format(avg, dustSum / kills))
	expect(dustN > 0, "달가루가 떨어진다")
end

-- ---- 14) 창에 적는 글이 칸에 들어간다 ----
do
	local function width(text)
		return (pixelText.Measure(text, "small"))
	end
	-- 상점: 물건 이름 100 · 값 30 · "Lv.10부터" 64(client/lune/ui/shopWindow.luau의 NAME_W · PRICE_W · LOCK_W) — 셋과 단추가 창 안(174)에 들어간다
	local NAME_W, PRICE_W, LOCK_W = 100, 30, 64
	expect(4 + NAME_W + PRICE_W + 3 + 15 + 1 + 17 <= 174, "상점 한 줄이 창 안")
	expect(4 + NAME_W + LOCK_W <= 174, "잠긴 줄이 창 안")
	for _, st in D.STOCK do
		local label = st.name
		if st.id == "w10" then
			for who in D.KINDS do
				expect(width(Items.name(Items.make("weapon", st.item.stage, D.NORMAL, who))) <= NAME_W, "상점의 무기 이름 " .. who)
			end
		elseif st.id == "potion" then
			for _, pt in N.data.BODY.potion do
				expect(width(pt.name) <= NAME_W, "물약 이름 " .. pt.name)
				expect(width(tostring(pt.price)) <= PRICE_W, "물약 값 " .. pt.name)
			end
		else
			expect(width(label) <= NAME_W, ("상점의 물건 이름 %s — 폭 %d"):format(label, width(label)))
			expect(width(tostring(st.price)) <= PRICE_W, "상점의 값 " .. label)
		end
		expect(width(("Lv.%d부터"):format(st.from)) <= LOCK_W, "열리는 레벨 글 " .. st.id)
	end
	-- 장비 창: 부위 이름과 「Lv.140 +17」이 58에 들어간다(client/lune/ui/equipWindow.luau의 TEXT_W) — 왼쪽 단(칸 20 + 글)이 오른쪽 덩이(88부터, 네 칸) 앞에서 끝나고, 오른쪽 덩이가 창 안(174)
	local TEXT_W, CELL = 58, KIT.cell
	expect(2 + CELL + 4 + TEXT_W <= 88 and 88 + 4 * (CELL + 1) - 1 <= 174, "장비 창의 두 덩이가 겹치지 않고 창 안")
	expect(2 + 5 * (CELL + 1) <= 152 - 18, "장비 창의 왼쪽 다섯 칸이 창의 높이 안")
	for _, slot in D.SLOTS do
		expect(width(slot.name) <= TEXT_W, "장비 창의 부위 이름 " .. slot.name)
		expect(width(slot.name .. " — 비었다") <= 84 * 3, "빈 부위를 골랐을 때의 글 " .. slot.name)
	end
	expect(width("Lv.140 +17") <= TEXT_W, "장비 창의 단계와 별(사냥 장비)")
	-- 가방 창: 탭 셋이 나란히(이름 + 10씩, 사이 1) 가방 수 글(174 - 64부터) 왼쪽에 들어간다 · 칸 여덟이 창 안
	local tabs = 2
	for _, name in D.BAG.tabs do
		tabs += width(name) + 10 + 1
	end
	expect(tabs <= 174 - 64, ("가방 탭 셋의 폭 %d"):format(tabs))
	expect(2 + 8 * CELL + 6 <= 174, "가방의 여덟 칸이 창 안")
	expect(width("48/48") <= 30, "가방 수 글")
	-- 가방을 늘리는 단추(폭 58)의 글: 「+4칸 16만」
	local F = req("ReplicatedStorage/shared/lune/ui/format")
	for n = 0, D.BAG.times - 1 do
		local text = ("+4칸 %s"):format(F.short(D.BAG.costs[n + 1]))
		expect(width(text) <= 58 - 4, ("가방 늘리기 단추의 글 %s — 폭 %d"):format(text, width(text)))
	end
end
for _, s in D.STOCK do
	expect(D.NPCDO[s.npc] ~= nil, "상점 물건을 파는 주민 " .. s.id)
	expect(s.id == "potion" or (typeof(s.price) == "number" and s.price > 0), "값이 있다 " .. s.id)
end
-- 이름이 가방 창의 이름 줄(한 줄 · 폭 166 — 작은 글씨)에 별까지 붙여 들어간다 — 가장 긴 이름까지
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
local longest = 0
for _, stage in D.STAGES do
	for qi in D.QUALITY do
		for who in D.KINDS do
			longest = math.max(longest, (pixelText.Measure(Items.name(Items.make("weapon", stage, qi, who)), "small")))
		end
		for _, slot in D.ARMOR do
			longest = math.max(longest, (pixelText.Measure(Items.name(Items.make(slot, stage, qi)), "small")))
		end
	end
end
expect(longest + (pixelText.Measure(" +22", "small")) <= 166, ("가장 긴 장비 이름이 별까지 한 줄(166)에 들어감 — 폭 %d"):format(longest))
expect(longest <= 84 * 3, "장비 창의 이름 칸(84 x 세 줄)에도 들어간다")

-- ---- 3) 새 캐릭터의 차림 ----
local h = Hero.new(1, "reaper")
eq(#Bag.worn(h), 5, "무기와 방어구 네 부위를 입고 있다")
eq(h.equip.weapon.who, "reaper", "내 직업의 무기")
eq(#h.gear, 0, "가방은 비어 있다")
eq(Bag.size(h), D.BAG.base, "가방 24칸")
near(Hero.cut(h, 1), N.armorCut(1, 1), "Lv.1 방어구 네 부위 = 같은 레벨의 방어")
expect(Hero.cut(h, 20) < Hero.cut(h, 1), "레벨이 높은 몬스터에게는 덜 막는다")

-- ---- 4) 끼기 · 벗기 ----
local better = Items.make("weapon", 1, 5, "reaper")
expect(Bag.add(h, better), "가방에 넣는다")
local before = Hero.power(h)
local oldId = h.equip.weapon.id
expect(Bag.equip(h, better.id), "낀다")
eq(h.equip.weapon, better, "무기가 바뀌었다")
eq(h.gear[1].id, oldId, "끼고 있던 것은 그 칸으로 들어간다")
expect(Hero.power(h) >= before, "빼어난 무기는 전투력이 같거나 높다")
local other = Items.make("weapon", 1, 3, "axion")
Bag.add(h, other)
local ok, why = Bag.equip(h, other.id)
expect(not ok and why == "다른 직업의 무기다", "남의 무기는 못 낀다")
local high = Items.make("hat", 10, 3)
Bag.add(h, high)
ok, why = Bag.equip(h, high.id)
expect(not ok and string.find(why, "Lv.10") ~= nil, "레벨이 모자라면 못 낀다")
h.level = 10
expect(Bag.equip(h, high.id), "레벨이 되면 낀다")
expect(Hero.cut(h, 10) > 0, "방어구가 피해를 줄인다")
eq(Bag.equip(h, 9999), nil, "없는 번호")
eq(Bag.equip(h, "x"), nil, "번호가 아닌 것")
expect(Bag.unequip(h, "hat"), "벗는다")
eq(h.equip.hat, nil, "모자 자리가 비었다")
eq(Bag.unequip(h, "hat"), nil, "안 낀 것은 못 벗는다")
local naked = Hero.new(2, "axion")
for _, slot in D.GEAR do
	Bag.unequip(naked, slot)
end
eq(Hero.cut(naked, 1), 0, "다 벗으면 방어가 0")
expect(Hero.power(naked) < Hero.power(Hero.new(3, "axion")), "다 벗으면 전투력이 낮다")
-- 가방이 가득 차면
local full = Hero.new(4, "mooni")
for i = 1, Bag.size(full) do
	expect(Bag.add(full, Items.make("glove", 1, 3)), "가방에 넣는다 " .. i)
end
ok, why = Bag.add(full, Items.make("glove", 1, 3))
expect(not ok and why == "가방이 가득 찼다", "가득 차면 못 넣는다")
ok, why = Bag.unequip(full, "weapon")
expect(not ok, "가득 차면 못 벗는다")
-- 가방 늘리기
eq(Bag.growCost(full), D.BAG.costs[1], "처음 늘리는 값")
ok, why = Bag.grow(full)
expect(not ok and why == "달돈이 모자란다", "돈이 없으면 못 늘린다")
full.money = 1e9
for i = 1, D.BAG.times do
	expect(Bag.grow(full), "늘린다 " .. i)
end
eq(Bag.size(full), D.BAG.base + D.BAG.step * D.BAG.times, "48칸까지")
eq(Bag.grow(full), nil, "더는 못 늘린다")

-- ---- 5) 분해 ----
local d = Hero.new(5, "axion")
local junk = Items.make("shoes", 20, 1)
junk.star = 3
Bag.add(d, junk)
local dust = Bag.dismantle(d, junk.id)
eq(dust, Items.dismantle(junk), "분해한 달가루")
eq(d.dust, dust, "달가루가 는다")
eq(#d.gear, 0, "분해한 것은 사라진다")
eq(Bag.dismantle(d, d.equip.weapon.id), nil, "끼고 있는 것은 분해하지 못한다")

-- ---- 6) 상점 ----
local b = Hero.new(6, "salamander")
ok, why = Bag.buy(b, "potion", 5)
expect(not ok and why == "달돈이 모자란다", "돈이 없으면 못 산다")
b.money = 100000
local p0, m0 = b.potions, b.money
expect(Bag.buy(b, "potion", 5), "물약 다섯 병")
eq(b.potions, p0 + 5, "물약이 는다")
eq(b.money, m0 - 5 * N.potionAt(1).price, "값을 치른다")
eq(Bag.buy(b, "potion", 0), nil, "0개는 못 산다")
eq(Bag.buy(b, "potion", 1.5), nil, "소수는 못 산다")
eq(Bag.buy(b, "potion", 100000), nil, "한 번에 너무 많이는 못 산다")
eq(Bag.buy(b, "nothing", 1), nil, "없는 물건")
expect(Bag.buy(b, "a1_hat", 1), "Lv.1 모자")
eq(b.gear[1].q, D.NORMAL, "상점의 것은 늘 보통")
ok, why = Bag.buy(b, "w10", 1)
expect(not ok and string.find(why, "Lv.10") ~= nil, "Lv.10 무기는 Lv.10부터")
b.level = 10
expect(Bag.buy(b, "w10", 1), "Lv.10 무기")
eq(b.gear[2].who, "salamander", "내 직업의 무기를 판다")
eq(b.gear[2].stage, 10, "Lv.10")
expect(Bag.buy(b, "dust", 50), "달가루 쉰 개")
eq(b.dust, 50, "달가루가 는다")

-- ---- 7) 강화 ----
local rng = Random.new(7)
local f = Hero.new(7, "axion")
f.level = 20
local w = Items.make("weapon", 20, 3, "axion")
Bag.add(f, w)
ok, why = Bag.enhance(f, w.id, rng)
expect(not ok and why == "달가루가 모자란다", "달가루가 없으면 못 한다")
f.dust = 1e9
local tries, oks = 0, 0
while w.star < Items.starCap(20) and tries < 500 do
	local star0, dust0 = w.star, f.dust
	local info = Items.enhanceInfo(w)
	local result = Bag.enhance(f, w.id, rng)
	tries += 1
	eq(f.dust, dust0 - info.dust, "달가루를 치른다")
	if result == "ok" then
		oks += 1
		eq(w.star, star0 + 1, "붙으면 별 하나")
	else
		eq(result, "fail", "10성까지는 실패해도 그대로다")
		eq(w.star, star0, "별이 그대로")
	end
end
eq(w.star, 5, "Lv.20 장비는 5성까지")
ok, why = Bag.enhance(f, w.id, rng)
expect(not ok and why == "더 붙일 수 없다", "상한을 넘지 못한다")
near(Items.score(w), 4 * 1.07 ^ 20 * 1.04 ^ 5, "별 하나에 4%씩")
-- 확률: 첫 별 95% · 열한째 별 50%
local function rate(star, n)
	local hit = 0
	for _ = 1, n do
		local it = Items.make("weapon", 160, 3, "axion")
		it.star = star
		if Items.enhance(it, rng) == "ok" then
			hit += 1
		end
	end
	return hit / n * 100
end
local r0, r10 = rate(0, 4000), rate(10, 4000)
expect(math.abs(r0 - 95) < 2, ("첫 별은 95%% — %.1f"):format(r0))
expect(math.abs(r10 - 50) < 3, ("열한째 별은 50%% — %.1f"):format(r10))
-- 정수: 11~15성에만 든다
for star = 0, E.max - 1 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = star
	local info = Items.enhanceInfo(it)
	eq(info.essence > 0, star >= 10 and star <= 14, "정수가 드는 별 " .. (star + 1))
	eq(info.drops, star + 1 >= 16 and star ~= 15 and star ~= 20, "실패하면 떨어지는 별 " .. (star + 1))
	eq(info.boom > 0, star + 1 >= 16, "부서질 수 있는 별 " .. (star + 1))
	eq(info.guard, star + 1 == 16 or star + 1 == 17, "파괴 막기를 쓸 수 있는 별 " .. (star + 1))
end
-- 16성부터: 떨어짐 · 부서짐 · 버팀 단계 · 두 번 떨어지면 반드시 성공 · 파괴 막기
local seen = { ok = 0, fail = 0, drop = 0, boom = 0 }
local sureOk, lowest = true, 99
for _ = 1, 3000 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 17
	for _ = 1, 40 do
		if it.broken then
			break
		end
		if it.star >= E.max then
			break
		end
		local star0, sure = it.star, (it.fails or 0) >= E.chance
		local result = Items.enhance(it, rng)
		seen[result] += 1
		if sure and result ~= "ok" then
			sureOk = false
		end
		if result == "drop" then
			eq(it.star, star0 - 1, "한 단계 떨어진다")
		elseif result == "boom" then
			eq(it.star, math.min(E.boomTo, star0), "부서지면 12성 흔적")
			eq(Items.score(it), 0, "부서진 것은 힘이 없다")
		end
		lowest = math.min(lowest, it.star)
	end
end
expect(seen.drop > 0 and seen.boom > 0 and seen.ok > 0, ("떨어지고 부서지고 붙는다(%d · %d · %d)"):format(seen.drop, seen.boom, seen.ok))
expect(sureOk, "두 번 잇달아 떨어지면 다음은 반드시 붙는다")
expect(lowest >= 12, "15성 아래로는 부서질 때만 내려간다(가장 낮은 별 " .. lowest .. ")")
local floorHeld = true
for _ = 1, 2000 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 15
	local result = Items.enhance(it, rng)
	if result == "drop" then
		floorHeld = false
	end
end
expect(floorHeld, "15성은 버팀 단계 — 16성 시도에 실패해도 떨어지지 않는다")
local guarded = 0
for _ = 1, 3000 do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 16
	if Items.enhance(it, rng, true) == "boom" then
		guarded += 1
	end
end
eq(guarded, 0, "파괴 막기를 켜면 17성 시도에서 부서지지 않는다")
do
	local it = Items.make("weapon", 180, 3, "axion")
	it.star = 16
	eq(Items.enhanceInfo(it, true).dust, Items.enhanceInfo(it).dust * E.guard.cost, "파괴 막기는 달가루 세 배")
	it.star = 18
	eq(Items.enhanceInfo(it, true).boom > 0, true, "19성 시도는 막을 수 없다")
end
-- 끼고 있다가 부서지면 가방으로 간다 · 같은 장비로 되살린다
local g = Hero.new(8, "axion")
g.level = 150
g.dust, g.essence = 1e12, 1e6
local sword = Items.make("weapon", 180, 3, "axion")
sword.star = 18
sword.need = 150 -- 보스의 장비는 단계가 레벨보다 높다(낄 수 있는 레벨을 따로 가진다 — 보스 장비가 생기는 단계에서 저장에도 넣는다)
Bag.add(g, sword)
expect(Bag.equip(g, sword.id), "18성 무기를 낀다")
local broke = false
for _ = 1, 4000 do
	local result = Bag.enhance(g, sword.id, rng)
	if result == "boom" then
		broke = true
		break
	elseif result == nil then
		sword.star = 18
	end
end
expect(broke, "언젠가 부서진다")
eq(g.equip.weapon, nil, "부서진 것은 끼고 있을 수 없다")
eq(Bag.find(g, sword.id) ~= nil, true, "흔적이 가방에 남는다")
eq(sword.star, 12, "12성 흔적")
eq(Bag.equip(g, sword.id), nil, "부서진 것은 못 낀다")
eq(Bag.enhance(g, sword.id, rng), nil, "부서진 것은 강화하지 못한다")
local wrong = Items.make("weapon", 170, 3, "axion")
Bag.add(g, wrong)
ok, why = Bag.restore(g, sword.id, wrong.id)
expect(not ok and why == "같은 장비가 아니다", "다른 장비로는 못 되살린다")
local spare = Items.make("weapon", 180, 1, "axion")
Bag.add(g, spare)
expect(Bag.restore(g, sword.id, spare.id), "같은 장비로 되살린다")
eq(sword.broken, false, "되살아났다")
eq(sword.star, 12, "12성으로")
eq(Bag.find(g, spare.id), nil, "쓴 장비는 사라진다")

-- ---- 8) 별 옮기기 ----
local t = Hero.new(9, "riven")
t.level = 30
t.equip.weapon.star = 5
local old = t.equip.weapon
local new = Items.make("weapon", 20, 4, "riven")
Bag.add(t, new)
expect(Bag.transfer(t, old.id, new.id), "별을 옮긴다")
eq(new.star, 4, "하나 낮아져 4성")
eq(Bag.find(t, old.id), nil, "옛 장비는 사라진다")
eq(t.equip.weapon, new, "끼고 있던 것을 옮겼으면 새것을 낀다")
local hat = Items.make("hat", 20, 3)
Bag.add(t, hat)
ok, why = Bag.transfer(t, new.id, hat.id)
expect(not ok and why == "같은 부위끼리만 옮긴다", "다른 부위로는 못 옮긴다")
local plain = Items.make("weapon", 30, 3, "riven")
Bag.add(t, plain)
local zero = Items.make("weapon", 30, 3, "riven")
Bag.add(t, zero)
ok, why = Bag.transfer(t, zero.id, plain.id)
expect(not ok and why == "옮길 별이 없다", "별이 없는 것은 옮길 것이 없다")

-- ---- 9) 창고 ----
local k = Hero.new(10, "axion")
local thing = Items.make("suit", 1, 2)
Bag.add(k, thing)
expect(Bag.storeIn(k, thing.id), "창고에 넣는다")
eq(#k.gear, 0, "가방에서 빠진다")
eq(#k.store, 1, "창고에 들어간다")
eq(Bag.equip(k, thing.id), nil, "창고의 것은 바로 못 낀다")
eq(Bag.dismantle(k, thing.id), nil, "창고의 것은 분해하지 못한다")
expect(Bag.storeOut(k, thing.id), "창고에서 뺀다")
eq(#k.gear, 1, "가방으로 돌아온다")
eq(Bag.storeIn(k, k.equip.weapon.id), nil, "끼고 있는 것은 못 넣는다")
for i = 1, Bag.storeSize(k) do
	local it = Items.make("hat", 1, 3)
	Bag.add(k, it)
	expect(Bag.storeIn(k, it.id), "창고에 넣는다 " .. i)
end
ok, why = Bag.storeIn(k, thing.id)
expect(not ok and why == "창고가 가득 찼다", "창고가 가득 차면 못 넣는다")

-- ---- 10) 떨어지는 것 ----
local roll = Random.new(11)
local n, mine, others, armor = 200000, 0, 0, 0
local byQ = table.create(#D.QUALITY, 0)
for _ = 1, n do
	local it = Items.rollDrop(roll, 25, "mooni")
	if it then
		eq(it.stage, 20, "Lv.25 몬스터는 Lv.20 장비")
		byQ[it.q] += 1
		if it.slot ~= "weapon" then
			armor += 1
		elseif it.who == "mooni" then
			mine += 1
		else
			others += 1
		end
	end
end
local function pctOf(x)
	return x / n * 100
end
expect(math.abs(pctOf(mine) - D.DROP.weapon) < 0.06, ("내 무기 0.2%% — %.3f"):format(pctOf(mine)))
expect(math.abs(pctOf(others) - D.DROP.other) < 0.06, ("남의 무기 0.2%% — %.3f"):format(pctOf(others)))
expect(math.abs(pctOf(armor) - D.DROP.armor) < 0.08, ("방어구 0.4%% — %.3f"):format(pctOf(armor)))
local total = mine + others + armor
for i, q in D.QUALITY do
	expect(math.abs(byQ[i] / total * 100 - q.pct) < 5, ("성능 %s %d%% — %.1f"):format(q.name, q.pct, byQ[i] / total * 100))
end
expect(byQ[1] > 0 and byQ[5] > 0, "보통 아래도, 위도 나온다")
-- 벌칙 동안에는 덜 나온다
local weakN = 0
for _ = 1, n do
	if Items.rollDrop(roll, 25, "mooni", 0.2) then
		weakN += 1
	end
end
expect(weakN < total * 0.35, ("벌칙 동안 장비가 덜 나온다(%d → %d)"):format(total, weakN))

-- ---- 11) 저장 ----
local s = Hero.new(12, "mooni")
s.level = 20
local keep = Items.make("glove", 20, 5)
keep.star = 4
Bag.add(s, keep)
Bag.add(s, Items.make("weapon", 20, 1, "axion"))
local stored = Items.make("hat", 10, 2)
Bag.add(s, stored)
Bag.storeIn(s, stored.id)
s.dust, s.essence = 321, 7
s.money = 1e7
Bag.grow(s)
Bag.equip(s, keep.id)
local back = Hero.unpack(12, Hero.pack(s))
expect(back ~= nil, "저장한 것을 되살린다")
eq(Hero.power(back), Hero.power(s), "전투력이 같다")
eq(back.equip.glove.star, 4, "낀 장비의 별")
eq(back.equip.glove.q, 5, "낀 장비의 성능")
eq(#back.gear, #s.gear, "가방의 장비 수")
eq(#back.store, 1, "창고")
eq(back.dust, 321, "달가루")
eq(back.essence, 7, "정수")
eq(Bag.size(back), Bag.size(s), "늘린 가방")
-- 장비가 생기기 전에 저장된 캐릭터는 처음 차림을 받는다
local oldSave = Hero.pack(Hero.new(13, "riven"))
oldSave.bag = nil
local revived = Hero.unpack(13, oldSave)
eq(#Bag.worn(revived), 5, "옛 저장에는 처음 차림을 준다")
-- 깨진 자료: 이상한 장비는 버린다
local bad = Hero.pack(s)
bad.bag.gear[1] = { "weapon", 20, 9, 0, "axion", 0, 0 } -- 없는 성능 단
table.insert(bad.bag.gear, { "wing", 20, 3, 0, "", 0, 0 }) -- 없는 부위
table.insert(bad.bag.gear, { "hat", 20, 3, 22, "", 0, 0 }) -- 상한을 넘는 별
table.insert(bad.bag.equip, { "weapon", 20, 3, 0, "axion", 0, 0 }) -- 남의 무기를 끼고 있다
bad.bag.dust = -5
local fixed = Hero.unpack(12, bad)
expect(fixed ~= nil, "깨진 자료도 캐릭터는 살린다")
eq(fixed.dust, 0, "이상한 달가루는 0으로")
for _, it in fixed.gear do
	expect(Items.valid(it), "남은 장비는 꼴이 맞다")
end
expect(fixed.equip.weapon == nil or fixed.equip.weapon.who == "mooni", "남의 무기는 끼고 있지 않다")

-- ---- 12) 화면에 보내는 것 ----
local v = Bag.view(s)
eq(v.size, Bag.size(s), "가방 칸 수")
eq(v.dust, 321, "달가루")
expect(v.equip.glove ~= nil and v.equip.glove.id == keep.id, "낀 장비")
eq(#v.gear, #s.gear, "가방의 장비")

-- ---- 13) 떨어진 장비와 달가루를 줍는다 ----
do
	local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(3))
	local me = Hero.new(21, "axion")
	me.x, me.y = 200, 176
	local gear = room:addDrop({ kind = "gear", item = Items.make("hat", 1, 4), amount = 1 }, 205, 176, me.id)
	local dustDrop = room:addDrop({ kind = "dust", amount = 7 }, 210, 176, me.id)
	local shown = Room.dropView(gear)
	expect(shown.item ~= nil and shown.item.slot == "hat" and shown.item.q == 4, "떨어진 장비가 무엇인지 알린다")
	eq(#room:describe().drops, 2, "방에 들어온 사람도 떨어진 것을 본다")
	expect(room:pickup(me, gear.id) ~= nil, "장비를 줍는다")
	eq(#me.gear, 1, "가방에 들어온다")
	eq(me.gear[1].q, 4, "성능이 그대로")
	expect(room:pickup(me, dustDrop.id) ~= nil, "달가루를 줍는다")
	eq(me.dust, 7, "달가루가 는다")
	-- 가방이 가득 차면 줍지 못하고, 물건은 그대로 남는다
	for _ = 1, Bag.free(me) do
		Bag.add(me, Items.make("glove", 1, 3))
	end
	local more = room:addDrop({ kind = "gear", item = Items.make("suit", 1, 3), amount = 1 }, 205, 176, me.id)
	local got, why = room:pickup(me, more.id)
	expect(got == nil and why == "가방이 가득 찼다", "가방이 가득 차면 못 줍는다")
	expect(room.drops[more.id] ~= nil, "못 주운 것은 그대로 남는다")
	-- 졸개를 잡으면 장비와 달가루가 정한 확률로 나온다(Lv.25 졸개 십만 마리)
	local hunter = Hero.new(22, "reaper")
	local gearN, dustN, dustSum, kills = 0, 0, 0, 100000
	local mob = { lv = 25, x = 100, y = 176, def = { hp = 1 } }
	for _ = 1, kills do
		for _, d in room:lootFor(hunter, mob) do
			if d.kind == "gear" then
				gearN += 1
			else
				dustN += 1
				dustSum += d.amount
			end
			room.drops[d.id] = nil
		end
	end
	local want = D.DROP.weapon + D.DROP.other + D.DROP.armor
	expect(math.abs(gearN / kills * 100 - want) < 0.15, ("졸개 백 마리에 장비 %.1f개 — %.2f"):format(want, gearN / kills * 100))
	local avg = D.DUST.kill * (25 / 10) ^ 3
	expect(math.abs(dustSum / kills - avg) < avg * 0.06, ("달가루 한 마리 평균 %.3f — %.3f"):format(avg, dustSum / kills))
	expect(dustN > 0, "달가루가 떨어진다")
end

-- ---- 14) 창에 적는 글이 칸에 들어간다 ----
do
	local function width(text)
		return (pixelText.Measure(text, "small"))
	end
	-- 상점: 물건 이름 100 · 값 30 · "Lv.10부터" 64(client/lune/ui/shopWindow.luau의 NAME_W · PRICE_W · LOCK_W) — 셋과 단추가 창 안(174)에 들어간다
	local NAME_W, PRICE_W, LOCK_W = 100, 30, 64
	expect(4 + NAME_W + PRICE_W + 3 + 15 + 1 + 17 <= 174, "상점 한 줄이 창 안")
	expect(4 + NAME_W + LOCK_W <= 174, "잠긴 줄이 창 안")
	for _, st in D.STOCK do
		local label = st.name
		if st.id == "w10" then
			for who in D.KINDS do
				expect(width(Items.name(Items.make("weapon", st.item.stage, D.NORMAL, who))) <= NAME_W, "상점의 무기 이름 " .. who)
			end
		elseif st.id == "potion" then
			for _, pt in N.data.BODY.potion do
				expect(width(pt.name) <= NAME_W, "물약 이름 " .. pt.name)
				expect(width(tostring(pt.price)) <= PRICE_W, "물약 값 " .. pt.name)
			end
		else
			expect(width(label) <= NAME_W, ("상점의 물건 이름 %s — 폭 %d"):format(label, width(label)))
			expect(width(tostring(st.price)) <= PRICE_W, "상점의 값 " .. label)
		end
		expect(width(("Lv.%d부터"):format(st.from)) <= LOCK_W, "열리는 레벨 글 " .. st.id)
	end
	-- 장비 창: 부위 이름과 「Lv.140 +17」이 68에 들어간다(client/lune/ui/equipWindow.luau의 TEXT_W) — 두 단이 창 안(174)
	local TEXT_W = 68
	expect(89 + 17 + TEXT_W <= 174 and 2 + 17 + TEXT_W <= 89, "장비 창의 두 단이 겹치지 않고 창 안")
	for _, slot in D.SLOTS do
		expect(width(slot.name) <= TEXT_W, "장비 창의 부위 이름 " .. slot.name)
	end
	expect(width("Lv.140 +17") <= TEXT_W, "장비 창의 단계와 별(사냥 장비)")
	-- 가방 탭 이름: 셋이 나란히(이름 + 10씩, 사이 2) 가방 수 글(40) 왼쪽에 들어간다
	local tabs = 4
	for _, name in D.BAG.tabs do
		tabs += width(name) + 10 + 2
	end
	expect(tabs <= 174 - 44, ("가방 탭 셋의 폭 %d"):format(tabs))
end
