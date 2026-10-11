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
	expect(typeof(s.price) == "number" and s.price > 0, "값이 있다 " .. s.id)
	expect(s.goods == false or (Items.goods(s.goods) ~= nil and Items.goods(s.goods).tab == "use"), "상점의 소비 아이템은 아이템 목록에 있다 " .. s.id)
end
-- 가장 긴 장비 이름: 아이템 상세 판의 이름 칸(본문 글씨 두 줄 — 그림 칸의 오른쪽)에 별까지 붙여 들어간다
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
do
	local LAY = req("ReplicatedStorage/shared/lune/ui/layout")
	local longest, longName = 0, ""
	local function see(it)
		local name = Items.name(it)
		local w = (pixelText.Measure(name, "body"))
		if w > longest then
			longest, longName = w, name
		end
	end
	for _, stage in D.STAGES do
		for qi in D.QUALITY do
			for who in D.KINDS do
				see(Items.make("weapon", stage, qi, who))
			end
			for _, slot in D.ARMOR do
				see(Items.make(slot, stage, qi))
			end
		end
	end
	for s = 2, 10 do
		local _, _, us = LAY.gridFor(s)
		local ratio = s / us
		local nameW = LAY.detailNameW(ratio)
		for _, tail in { " +22", " " .. D.WORDS.broken } do
			local wrapped = pixelText.Wrap(longName .. tail, nameW, "body")
			local lines = string.split(wrapped, "\n")
			expect(#lines <= LAY.DETAIL.nameLines, ("게임 %d배: 가장 긴 장비 이름 「%s%s」이 상세 판의 이름 칸(폭 %d · %d줄)에 들어감"):format(s, longName, tail, nameW, LAY.DETAIL.nameLines))
			for _, line in lines do
				expect((pixelText.Measure(line, "body")) <= nameW, ("게임 %d배: 이름의 한 줄 「%s」이 칸(%d)을 넘지 않는다"):format(s, line, nameW))
			end
		end
	end
end

-- ---- 3) 새 캐릭터의 차림 ----
local h = Hero.new(1, "reaper")
eq(#Bag.worn(h), 5, "무기와 방어구 네 부위를 입고 있다")
eq(h.equip.weapon.who, "reaper", "내 직업의 무기")
eq(Bag.used(h), 0, "가방의 장비 탭은 비어 있다")
eq(#h.gear, D.BAG.base, "장비 탭의 칸(빈 칸은 false)")
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
eq(Bag.used(d), 0, "분해한 것은 사라진다")
eq(Bag.dismantle(d, d.equip.weapon.id), nil, "끼고 있는 것은 분해하지 못한다")

-- ---- 6) 상점 ----
local b = Hero.new(6, "salamander")
ok, why = Bag.buy(b, "potion1", 5)
expect(not ok and why == "달돈이 모자란다", "돈이 없으면 못 산다")
b.money = 100000
local p0, m0 = Bag.count(b, "potion1"), b.money
expect(Bag.buy(b, "potion1", 5), "물약 다섯 병")
eq(Bag.count(b, "potion1"), p0 + 5, "물약이 는다(가방의 소비 탭)")
eq(b.money, m0 - 5 * N.potionAt(1).price, "값을 치른다")
eq(Bag.buy(b, "potion1", 0), nil, "0개는 못 산다")
eq(Bag.buy(b, "potion1", 1.5), nil, "소수는 못 산다")
eq(Bag.buy(b, "potion1", 100000), nil, "한 번에 너무 많이는 못 산다")
ok, why = Bag.buy(b, "potion2", 1)
expect(not ok and string.find(why, "Lv.30") ~= nil, "윗단의 물약은 그 레벨부터 산다")
do
	-- 소비 탭이 가득 차면 못 산다(돈은 그대로)
	local keep, m1 = table.clone(b.use), b.money
	for i = 1, Bag.size(b) do
		b.use[i] = { item = "potion4", n = 200 }
	end
	ok, why = Bag.buy(b, "potion1", 1)
	expect(not ok and why == Bag.FULL and b.money == m1, "소비 탭이 가득 차면 못 산다")
	b.use = keep
end
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
-- 첫 강화: 달가루가 하나도 없어도 된다 · 반드시 붙는다 · 한 번뿐이다(공방 basics.js의 FORGE.first — "이 한 번은 반드시 성공")
do
	local first = Hero.new(70, "riven")
	first.level = 20
	local it = Items.make("weapon", 20, 3, "riven")
	Bag.add(first, it)
	eq(first.forged, false, "새 캐릭터는 강화를 해 본 적이 없다")
	local info = Items.enhanceInfo(it, false, true)
	expect(info.first == true and info.sure == true and info.ok == 100 and info.dust == 0 and info.essence == 0, "첫 강화의 내용: 공짜 · 반드시 성공")
	for _ = 1, 50 do
		local hero = Hero.new(71, "riven")
		local one = Items.make("hat", 10, 3)
		Bag.add(hero, one)
		eq(Bag.enhance(hero, one.id, rng), "ok", "첫 강화는 반드시 붙는다")
		eq(hero.dust, 0, "달가루가 들지 않는다")
	end
	eq(Bag.enhance(first, it.id, rng), "ok", "달가루 없이 첫 별이 붙는다")
	eq(it.star, 1, "별 하나")
	eq(first.forged, true, "강화를 해 봤다")
	expect(select(2, Bag.enhance(first, it.id, rng)) == "달가루가 모자란다", "두 번째부터는 달가루가 든다")
	eq(Hero.unpack(70, Hero.pack(first)).forged, true, "저장해도 그대로다(첫 강화를 다시 받지 않는다)")
	-- 별이 이미 붙은 장비에는 첫 강화가 듣지 않는다(예전 캐릭터가 높은 별에서 공짜로 넘어가지 못한다) — 시도하면 그것으로 첫 강화는 끝난다
	do
		local old = Hero.new(72, "riven")
		local it2 = Items.make("weapon", 20, 3, "riven")
		it2.star = 3
		Bag.add(old, it2)
		expect(select(2, Bag.enhance(old, it2.id, rng)) == "달가루가 모자란다", "별이 붙은 장비의 강화는 공짜가 아니다")
		eq(old.forged, false, "치르지 못한 시도는 첫 강화를 쓰지 않는다")
	end
	eq(Hero.view(first).forged, true, "화면에 알린다")
end
f.forged = true -- 아래는 보통의 강화를 본다
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
g.forged = true -- 첫 강화(공짜 · 반드시 성공)는 위에서 봤다 — 여기는 보통의 강화
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
local thingAt = Bag.add(k, thing)
expect(Bag.storeIn(k, "gear", thingAt), "창고에 넣는다(가방의 그 칸의 것을)")
eq(Bag.used(k), 0, "가방에서 빠진다")
eq(Bag.stored(k), 1, "창고에 들어간다")
eq(k.store.gear[1], thing, "창고의 첫 빈 칸에 놓인다")
eq(Bag.equip(k, thing.id), nil, "창고의 것은 바로 못 낀다")
eq(Bag.dismantle(k, thing.id), nil, "창고의 것은 분해하지 못한다")
expect(Bag.storeOut(k, "gear", 1), "창고에서 뺀다")
eq(Bag.used(k), 1, "가방으로 돌아온다")
eq(Bag.storeIn(k, "gear", 9), nil, "빈 칸은 맡길 것이 없다(끼고 있는 것은 가방의 칸에 없다)")
for i = 1, Bag.storeSize(k) do
	local it = Items.make("hat", 1, 3)
	local at = Bag.add(k, it)
	expect(Bag.storeIn(k, "gear", at), "창고에 넣는다 " .. i)
end
ok, why = Bag.storeIn(k, "gear", select(3, Bag.find(k, thing.id)))
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
Bag.storeIn(s, "gear", Bag.add(s, stored))
s.dust, s.essence = 321, 7
s.money = 1e7
Bag.grow(s)
Bag.equip(s, keep.id)
local back = Hero.unpack(12, Hero.pack(s))
expect(back ~= nil, "저장한 것을 되살린다")
eq(Hero.power(back), Hero.power(s), "전투력이 같다")
eq(back.equip.glove.star, 4, "낀 장비의 별")
eq(back.equip.glove.q, 5, "낀 장비의 성능")
eq(Bag.used(back), Bag.used(s), "가방의 장비 수")
for i = 1, Bag.size(s) do
	expect((back.gear[i] == false) == (s.gear[i] == false), "장비가 놓인 칸이 그대로다 " .. i)
end
eq(Bag.stored(back), 1, "창고")
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
	expect(it == false or Items.valid(it), "남은 장비는 꼴이 맞다")
end
eq(#fixed.gear, Bag.size(fixed), "칸의 수는 그대로다")
expect(fixed.equip.weapon == nil or fixed.equip.weapon.who == "mooni", "남의 무기는 끼고 있지 않다")

-- ---- 12) 화면에 보내는 것 ----
local v = Bag.view(s)
eq(v.size, Bag.size(s), "가방 칸 수")
eq(v.dust, 321, "달가루")
expect(v.equip.glove ~= nil and v.equip.glove.id == keep.id, "낀 장비")
eq(#v.gear, Bag.size(s), "가방의 장비 탭(칸의 수만큼 — 빈 칸은 false)")
expect(#v.use == Bag.size(s) and #v.etc == Bag.size(s), "소비 · 기타 탭도 칸의 수만큼")

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
	eq(Bag.used(me), 1, "가방에 들어온다")
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
	local goodsN = {} -- 재료 · 귀한 드롭: [아이템의 이름표] = 떨어진 수
	local mob = { lv = 25, x = 100, y = 176, def = { hp = 1 } }
	for _ = 1, kills do
		for _, d in room:lootFor(hunter, mob) do
			if d.kind == "gear" then
				gearN += 1
			elseif d.kind == "dust" then
				dustN += 1
				dustSum += d.amount
			else
				goodsN[d.goods] = (goodsN[d.goods] or 0) + 1 -- 재료 · 귀한 드롭(가방의 아이템)
				expect(d.kind == "goods" and d.amount == 1 and Items.goods(d.goods) ~= nil and d.name == Items.goods(d.goods).name and d.icon == Items.goods(d.goods).icon, "재료 · 귀한 드롭의 꼴")
			end
			room.drops[d.id] = nil
		end
	end
	local want = D.DROP.weapon + D.DROP.other + D.DROP.armor
	expect(math.abs(gearN / kills * 100 - want) < 0.3, ("졸개 백 마리에 장비 %.1f개 — %.2f"):format(want, gearN / kills * 100))
	expect(want >= 3, "장비를 얻는 것은 쉽다 — 한 마리에 3% 넘게 떨어진다(사용자 2026-10-11: 벽은 강화다)")
	local avg = D.DUST.kill * (25 / 10) ^ 3
	expect(math.abs(dustSum / kills - avg) < avg * 0.06, ("달가루 한 마리 평균 %.3f — %.3f"):format(avg, dustSum / kills))
	expect(dustN > 0, "달가루가 떨어진다")
	-- 재료: Lv.25 몬스터는 Lv.20~29의 광석과 가죽을 저마다 MATDROP.pct%로 · 낮은 확률의 귀한 것: 그 레벨의 물약 · 귀환 주문서
	for _, id in Items.matsAt(25) do
		local pct = (goodsN[id] or 0) / kills * 100
		expect(math.abs(pct - D.MATDROP.pct) < 1, ("재료 %s: 한 마리에 %d%% — %.2f"):format(id, D.MATDROP.pct, pct))
	end
	for _, r in D.RARE do
		local id = if r.id == "potion" then Items.potionFor(25).id else r.goods
		local pct = (goodsN[id] or 0) / kills * 100
		expect(math.abs(pct - r.pct) < math.max(0.12, r.pct * 0.25), ("귀한 드롭 %s: 한 마리에 %s%% — %.2f"):format(id, tostring(r.pct), pct))
	end
end

-- ---- 재료와 제작(사용자 2026-10-11: 몬스터가 재료를 떨어뜨리고, 안 뜨면 대장장이가 그 재료로 만든다) ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	-- 재료는 레벨대마다 광석 하나 · 가죽 하나. 1지역(Lv.1~29)의 세 단계
	for _, lv in { 1, 9, 10, 19, 20, 29 } do
		local list = Items.matsAt(lv)
		eq(#list, 2, "그 레벨의 몬스터는 재료 둘(광석 · 가죽)을 떨어뜨린다 Lv." .. lv)
		for _, id in list do
			local g = Items.goods(id)
			expect(g ~= nil and g.tab == "etc" and g.kind == "mat" and g.sell > 0, "재료는 가방의 기타 탭에 놓이고 상점에 팔 수 있다 " .. id)
		end
	end
	eq(#Items.matsAt(30), 0, "Lv.30부터의 재료는 아직 없다(그 지역을 다듬을 때 붙인다)")
	expect(Items.matsAt(9)[1] ~= Items.matsAt(10)[1], "레벨대가 바뀌면 재료도 바뀐다")
	-- 제작법: 단계 셋 x (무기 + 방어구 네 부위). 재료는 그 단계의 것 · 무기에는 광석이, 방어구에는 가죽이 더 든다
	eq(#D.RECIPES, 15, "제작법 열다섯")
	for _, r in D.RECIPES do
		expect(Items.recipe(r.id) == r and r.money > 0 and r.from == r.stage, "제작법의 꼴 " .. r.id)
		local ore, hide = 0, 0
		for _, need in r.needs do
			local m
			for _, x in D.MATS do
				if x.id == need.item then
					m = x
				end
			end
			expect(m ~= nil and m.stage == r.stage and need.n > 0, "그 단계의 재료가 든다 " .. r.id)
			if m and m.kind == "ore" then
				ore = need.n
			else
				hide = need.n
			end
		end
		expect(if r.slot == "weapon" then ore > hide else hide > ore, "무기에는 광석이, 방어구에는 가죽이 더 든다 " .. r.id)
	end
	-- 만든다: 재료 · 달돈 · 레벨 · 가방의 빈 칸
	local h = Hero.new(900, "axion")
	local rng = Random.new(5)
	local r = Items.recipe("c10_weapon")
	eq(select(2, Bag.craft(h, "c10_weapon", rng)), "Lv.10부터 만든다", "레벨이 안 되면 못 만든다")
	while h.level < 10 do
		Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
	end
	eq(select(2, Bag.craft(h, "c10_weapon", rng)), "재료가 모자란다", "재료가 없으면 못 만든다")
	for _, need in r.needs do
		Bag.give(h, need.item, need.n)
	end
	h.money = r.money - 1
	eq(select(2, Bag.craft(h, "c10_weapon", rng)), "달돈이 모자란다", "삯이 모자라면 못 만든다")
	eq(select(2, Bag.craft(h, "nope", rng)), "없는 제작법이다", "없는 제작법")
	h.money = r.money + 7
	local gearWas = Bag.used(h, "gear")
	local made = Bag.craft(h, "c10_weapon", rng)
	expect(made ~= nil and made.slot == "weapon" and made.stage == 10 and made.who == "axion" and made.star == 0, "Lv.10 내 직업의 무기가 나온다")
	expect(made.q >= D.NORMAL, "만든 것의 성능은 보통 이상")
	eq(h.money, 7, "삯이 빠진다")
	for _, need in r.needs do
		eq(Bag.count(h, need.item), 0, "재료가 빠진다 " .. need.item)
	end
	eq(Bag.used(h, "gear"), gearWas + 1, "가방의 장비 탭에 들어온다")
	-- 성능의 비율: 보통 40 · 좋은 22 · 빼어난 8(떨어질 때의 비율에서 보통 아래를 뺀 것)
	local seen, n = {}, 20000
	for _ = 1, n do
		local q = Items.rollCraftQuality(rng)
		seen[q] = (seen[q] or 0) + 1
	end
	local total = 0
	for _, x in D.CRAFTQ do
		total += x.pct
	end
	for q = 1, D.NORMAL - 1 do
		eq(seen[q], nil, "보통 아래는 나오지 않는다 " .. q)
	end
	for _, x in D.CRAFTQ do
		expect(math.abs((seen[x.q] or 0) / n - x.pct / total) < 0.02, ("만든 것의 성능 %d단 — %.3f"):format(x.q, (seen[x.q] or 0) / n))
	end
	-- 귀환 주문서: 소비 탭의 아이템 · 잡화 상인이 판다
	local scroll = Items.goods("scroll_return")
	expect(scroll ~= nil and scroll.tab == "use" and scroll.kind == "scroll" and scroll.sell > 0, "귀환 주문서는 소비 아이템이다")
	expect(Items.stock("scroll_return") ~= nil and Items.stock("scroll_return").npc == "merchant" and Items.stock("scroll_return").price > scroll.sell, "잡화 상인이 판다(되팔면 손해)")
	expect(Hero.canSlot(h, "scroll_return"), "퀵슬롯에 놓을 수 있다")
end

-- ---- 14) 창에 적는 글이 칸에 들어간다 · 창이 화면에 들어간다 ----
--  창은 화면 틀의 고운 격자에 뜨는 옆 판이다(client/lune/ui/windows.luau). 치수는 shared/lune/ui/layout.luau — 화면과 같은 값을 쓴다.
--  장비 칸의 크기는 화면 틀의 배율을 따르므로(게임 2배 ~ 10배) 배율마다 본다.
do
	local L = req("ReplicatedStorage/shared/lune/ui/layout")
	local UIGEN = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local F = req("ReplicatedStorage/shared/lune/ui/format")
	local function width(text)
		return (pixelText.Measure(text, "small"))
	end
	local function widthBody(text)
		return (pixelText.Measure(text, "body"))
	end
	local WIN, BAG, EQ, SHOP = L.WIN, L.BAG, L.EQUIP, L.SHOP
	local function outer(bw, bh)
		return bw + WIN.pad * 2, bh + WIN.head + WIN.foot
	end
	for s = 2, 10 do
		local gw, gh, us = L.gridFor(s)
		local ratio = s / us
		local cell = L.cellFor(ratio)
		expect(cell >= KIT.icon * ratio + 4, ("게임 %d배: 칸(%d)이 장비 그림(%s)보다 사방으로 두 점은 크다"):format(s, cell, tostring(KIT.icon * ratio)))
		-- 가방 · 장비 창이 화면의 높이 안에 들어가고, 둘이 양쪽 끝에 같이 떠도 가운데가 남는다
		local bw, bh = L.bagBody(ratio)
		local ow, oh = outer(bw, bh)
		expect(WIN.top + oh <= gh, ("게임 %d배: 가방 창(%dx%d)이 화면(%dx%d) 안"):format(s, ow, oh, gw, gh))
		local ew, eh, rx = L.equipBody(ratio)
		local eow, eoh = outer(ew, eh)
		expect(WIN.top + eoh + 46 <= gh, ("게임 %d배: 장비 창(%dx%d)이 화면 안(왼쪽 위의 기본 단추 아래로 내려도)"):format(s, eow, eoh))
		expect(ow + eow + WIN.edge * 2 <= gw - 40, ("게임 %d배: 가방과 장비 창이 양쪽에 떠도 가운데가 남는다(%d + %d / %d)"):format(s, ow, eow, gw))
		expect(rx >= cell + EQ.gap + EQ.textW and ew - rx == EQ.accCols * cell, "장비 창의 두 덩이가 겹치지 않는다")
		expect(ew - rx >= 150, ("게임 %d배: 장비 창의 이름 · 단추 칸의 폭 %d"):format(s, ew - rx))
		-- 가방: 탭 셋과 가방 수 글(과 줄 넘기는 단추)이 한 줄에 · 단추 셋의 글이 단추 안에
		local tabs = 0
		for _, name in D.BAG.tabs do
			tabs += width(name) + 16
		end
		expect(tabs <= bw - BAG.countW - BAG.scrollW - 4, ("게임 %d배: 가방 탭 셋(%d)이 가방 수 글의 왼쪽에 들어간다(속 %d)"):format(s, tabs, bw))
		-- 가방의 아래: 「정렬」과 「+4칸 값」이 한 줄에, 지갑 셋(달돈 · 달가루 · 정수)의 숫자가 제 칸에
		expect(BAG.sortW + BAG.gap + BAG.growW <= bw, ("게임 %d배: 정렬 · 늘리기 단추가 한 줄에(속 %d)"):format(s, bw))
		local purse = L.purseW(bw)
		for _, big in { 9999, 99999999, 9.9e15 } do
			expect(width(F.short(big)) <= purse - 21 - 2, ("게임 %d배: 지갑의 숫자 %s가 제 칸(%d)에"):format(s, F.short(big), purse))
		end
		-- 아이템 상세 판: 가방 옆에 놓여도 화면 안이고, 가장 긴 판(줄 여섯 · 알림 글 여섯 줄 · 버릴 수를 고르는 줄)도 화면의 높이 안이다
		local K = L.DETAIL
		expect(WIN.edge + ow + K.gap + K.w <= gw, ("게임 %d배: 상세 판(%d)이 가방 옆에 놓여도 화면 안"):format(s, K.w))
		expect(WIN.edge + eow + K.gap + K.w <= gw, ("게임 %d배: 상세 판이 장비 창 옆에 놓여도 화면 안"):format(s))
		local tall = L.detailHeight(ratio, K.nameLines, 6, 6, 2) + L.M.smallLine + 4
		expect(WIN.top + tall <= gh, ("게임 %d배: 가장 긴 상세 판(%d)이 화면(%d) 안"):format(s, tall, gh))
		expect(L.detailNameW(ratio) >= 110, ("게임 %d배: 상세 판의 이름 칸 %d"):format(s, L.detailNameW(ratio)))
		-- 창고: 가방과 같은 짜임(탭 · 여섯 칸 x 네 줄 · 정렬과 안내 글) — 가방과 나란히 떠도 상세 판이 낄 자리는 겹쳐 쓴다(판이 위에 뜬다)
		local sbw, sbh = L.storeBody(ratio, D.BAG.storeBase)
		local sow, soh = outer(sbw, sbh)
		expect(WIN.top + soh + 46 <= gh, ("게임 %d배: 창고 창이 화면 안"):format(s))
		expect(ow + sow + WIN.edge * 2 <= gw, ("게임 %d배: 가방과 창고가 양쪽에 같이 뜬다(%d + %d / %d)"):format(s, ow, sow, gw))
		expect(tabs <= sbw - BAG.countW, ("게임 %d배: 창고의 탭 셋이 찬 칸 글의 왼쪽에 들어간다"):format(s))
		expect(width(UIGEN.words.storeHint) <= sbw - L.STORE.sortW - 10, ("게임 %d배: 창고의 안내 글이 정렬 단추 옆에 들어간다"):format(s))
	end
	expect(width("48 / 48") <= BAG.countW, "가방 수 글")
	expect(BAG.footH >= BAG.footY + BAG.purseY + 18 and BAG.purseY >= L.M.button + 10, "가방의 칸 아래에 단추 줄 · 가르는 줄 · 지갑이 들어간다")
	expect(widthBody(UIGEN.words.sort) <= BAG.sortW - 6, "정렬 단추의 글")
	for n = 0, D.BAG.times - 1 do
		local text = ("+%d칸 %s"):format(D.BAG.step, F.short(D.BAG.costs[n + 1]))
		expect(width(text) <= BAG.growW - 6, ("가방 늘리기 단추(%d)의 글 %s — 폭 %d"):format(BAG.growW, text, width(text)))
	end
	-- 아이템 상세 판의 글: 단추 · 줄의 이름과 값 · 알림 글이 제 칸에 들어간다(공방의 본보기와 아이템 모두)
	do
		local K = L.DETAIL
		local Info = req("ReplicatedStorage/shared/lune/ui/itemInfo")
		local WD = UIGEN.words
		local three, two = L.detailButtonW(K.btnCols), L.detailButtonW(2)
		for _, word in { WD.equip, WD.unequip, WD.use, WD.dismantle, WD.discard, WD.toStore, WD.toForge, WD.quick, WD.sell, WD.split, WD.take } do
			expect(widthBody(word) <= three - 6, ("상세 판의 단추(%d) 글 %s"):format(three, word))
		end
		-- 수를 고르는 줄: 묻는 글(팔 때는 받을 값이 뒤에 붙는다)과 하는 단추 · 그만두는 단추
		local kinds = 0
		for kind, pair in WD.ask do
			kinds += 1
			local ask = if kind == "sell" or kind == "sellGear" then pair[1] .. "  " .. F.fill(WD.gain, { n = "9999.9만" }) else pair[1]
			expect(width(ask) <= L.detailInner(), ("묻는 글 %s(폭 %d)이 판의 속(%d)에 들어간다"):format(ask, width(ask), L.detailInner()))
			expect(widthBody(pair[2]) <= two - 6, "하는 단추의 글 " .. pair[2])
		end
		eq(kinds, 6, "수를 고르는 일: 버리기 · 맡기기 · 찾기 · 팔기 · 나누기 · 장비 팔기")
		expect(widthBody(WD.askNo) <= two - 6, "그만두는 단추의 글")
		expect(widthBody(WD.sort) <= L.STORE.sortW - 6, "창고의 정렬 단추의 글")
		expect(width(WD.shopHint) <= SHOP.w - SHOP.hintX, "상점의 안내 글(끌어다 놓으면 판다)이 달돈 · 달가루의 오른쪽에 들어간다")
		expect(SHOP.hintX >= 96 + 90, "상점의 안내 글이 달가루의 숫자와 겹치지 않는다")
		expect(width("-10") <= K.stepW - 6 and width("+10") <= K.stepW - 6, "수를 고르는 단추의 글")
		expect(widthBody("9999") <= L.detailInner() - K.stepW * 4 - K.btnGap * 2 - 4, "버릴 수가 단추 사이에 들어간다")
		local function fits(info, label)
			for _, row in info.rows do
				expect(width(row[1]) <= K.labelW - 4, ("%s: 줄의 이름 %s(폭 %d)이 칸(%d)에"):format(label, row[1], width(row[1]), K.labelW))
				expect(width(row[2]) <= L.detailValueW(), ("%s: 줄의 값 %s(폭 %d)이 칸(%d)에"):format(label, row[2], width(row[2]), L.detailValueW()))
			end
			expect(#info.rows <= 6, label .. ": 줄은 여섯까지")
			local noteLines = 0
			for _, note in info.notes do
				local lines = string.split(pixelText.Wrap(note[1], L.detailInner(), "small"), "\n")
				expect(#lines <= K.noteLines, ("%s: 알림 글 「%s」이 %d줄 안에"):format(label, note[1], K.noteLines))
				noteLines += #lines
			end
			expect(noteLines <= 6, label .. ": 알림 글은 모두 여섯 줄까지")
			expect(width(info.sub) <= L.detailInner() - L.cellFor(2) - 8, label .. ": 갈래 글 " .. info.sub)
		end
		for i, c in C.info.gear do
			fits(Info.gear(c[1], { level = c[2], class = c[3] }, c[4] or nil, c[5]), "본보기 장비 " .. i)
		end
		-- 모든 부위 · 단계 · 성능에서(가장 높은 별 · 부서진 것까지): 가장 넓은 값들
		for _, slot in D.SLOTS do
			for _, stage in { 1, 140 } do
				for _, q in { 1, 5 } do
					local it = Items.make(slot.id, stage, q, "salamander")
					it.star = Items.starCap(stage)
					fits(Info.gear(it, { level = 150, class = "salamander" }, nil, false), Items.name(it))
					fits(Info.gear(it, { level = 1, class = "riven" }, nil, true), Items.name(it) .. " 장착 중")
					it.broken = true
					fits(Info.gear(it, { level = 150, class = "salamander" }, nil, false), Items.name(it) .. " 부서짐")
				end
			end
		end
		for _, g in D.GOODS do
			fits(Info.goods(g.id, { level = 1, class = "axion" }, g.stack * 48), g.name)
			expect(widthBody(g.name) <= L.detailNameW(2) * K.nameLines, "아이템 이름 " .. g.name)
			if g.tab == "use" then
				expect(width(g.short) <= 50, "좁은 데에 적는 이름(스마트폰의 놓을 것 목록 — 폭 50) " .. g.short)
			end
		end
	end
	-- 상점: 물건 이름(본문 글씨) · 값 · 사는 단추가 한 줄에 들어간다
	expect(SHOP.nameW + 4 <= SHOP.w - SHOP.buyW - 8 - SHOP.priceW, "상점의 이름과 값이 겹치지 않는다")
	for _, st in D.STOCK do
		local label = st.name
		if st.id == "w10" then
			for who in D.KINDS do
				local name = Items.name(Items.make("weapon", st.item.stage, D.NORMAL, who))
				expect(widthBody(name) <= SHOP.nameW, ("상점의 무기 이름 %s — 폭 %d"):format(name, widthBody(name)))
			end
		else
			expect(widthBody(label) <= SHOP.nameW, ("상점의 물건 이름 %s — 폭 %d"):format(label, widthBody(label)))
			expect(width(tostring(st.price)) <= SHOP.priceW, "상점의 값 " .. label)
		end
		expect(width(("Lv.%d부터"):format(st.from)) <= SHOP.w - SHOP.nameW, "열리는 레벨 글 " .. st.id)
	end
	do
		local count = {}
		for _, st in D.STOCK do
			count[st.npc] = (count[st.npc] or 0) + 1
		end
		for npc, n in count do
			expect(n <= SHOP.rows, ("상점 %s의 물건 %d가지가 창의 줄 수(%d) 안"):format(npc, n, SHOP.rows))
		end
	end
	expect(widthBody("사기") <= SHOP.buyW - 6 and widthBody("10") <= (SHOP.buyW - 6) / 2 - 6, "사는 단추의 글")
	-- 장비 창: 부위 이름과 「Lv.140 +17」이 글 칸에 들어간다
	for _, slot in D.SLOTS do
		expect(width(slot.name) <= EQ.textW, "장비 창의 부위 이름 " .. slot.name)
		expect(widthBody(slot.name .. " — 비었다") <= 150 * 2, "빈 부위를 골랐을 때의 글(두 줄까지) " .. slot.name)
	end
	expect(width("Lv.140 +17") <= EQ.textW, "장비 창의 단계와 별(사냥 장비)")
	-- 장비의 이름(본문 글씨)이 가방의 속(가장 좁을 때)에 한 줄로 들어간다 — 넘으면 …로 줄지만, 흔한 이름은 다 보여야 한다
	do
		local narrow = select(1, L.bagBody(2))
		local sample = Items.make("weapon", 20, 5, "axion")
		sample.star = 17
		local name = ("%s +%d"):format(Items.name(sample), sample.star)
		expect(widthBody(name) <= narrow, ("가방에서 고른 장비의 이름 「%s」(폭 %d)이 가장 좁은 가방(%d)에 들어간다"):format(name, widthBody(name), narrow))
	end
end

-- ---- 15) 가방의 칸: 소비 · 기타 아이템의 묶음 · 옮기기 · 정렬 · 버리기 ----
--  사용자 2026-10-08: "품목이 고정되어있고 거기서 수량 1/8 이런식으로 표기하는게 인벤토리가 아닙니다" — 세 탭 모두 진짜 칸이다(공방 js/lune/design/items.js의 BAGPLAY)
do
	local RULES = req("ReplicatedStorage/shared/lune/data/combat.generated").rules
	local g = Hero.new(31, "axion")
	local P1, P2 = "potion1", "potion2"
	local stack = Items.goods(P1).stack
	local n0 = RULES.startPotions
	eq(D.BAG.keys[1], "gear", "탭의 이름표 1")
	eq(D.BAG.keys[2], "use", "탭의 이름표 2")
	eq(D.BAG.keys[3], "etc", "탭의 이름표 3")
	eq(#D.BAG.keys, #D.BAG.tabs, "탭의 이름표와 이름의 수")
	for _, tab in Bag.TABS do
		eq(#g[tab], Bag.size(g), "칸의 수 " .. tab)
	end
	-- 새 캐릭터의 물약은 소비 탭 첫 칸의 한 묶음이다
	expect(g.use[1] ~= false and g.use[1].item == P1 and g.use[1].n == n0, "처음 물약은 소비 탭 첫 칸의 한 묶음")
	eq(Bag.used(g, "use"), 1, "소비 탭 한 칸")
	eq(Bag.used(g, "etc"), 0, "기타 탭은 비어 있다")
	eq(Bag.count(g, P1), n0, "가진 수")
	eq(Bag.room(g, P1), (Bag.size(g) - 1) * stack + stack - n0, "더 들어갈 수 = 덜 찬 묶음의 자리 + 빈 칸마다 한 묶음")
	-- 넣기: 같은 것이 든 칸부터 채우고, 넘치면 첫 빈 칸에 새 묶음
	expect(Bag.give(g, P1, stack), "한 묶음만큼 더 넣는다")
	eq(g.use[1].n, stack, "첫 칸이 가득 찬다")
	eq(g.use[2].n, n0, "넘친 것은 다음 칸에")
	eq(Bag.count(g, P1), n0 + stack, "수가 는다")
	expect(Bag.give(g, P2, 3) and g.use[3].item == P2 and g.use[3].n == 3, "다른 아이템은 다른 칸에")
	eq(Bag.give(g, "no_such", 1), nil, "없는 아이템")
	eq(Bag.give(g, P1, 0), nil, "0개")
	eq(Bag.give(g, P1, 1.5), nil, "소수")
	eq(Bag.give(g, P1, -3), nil, "음수")
	eq(Bag.count(g, "no_such"), 0, "없는 아이템의 수는 0")
	-- 덜어 내기: 앞 칸의 묶음부터. 다 덜린 칸은 빈다
	expect(Bag.take(g, P1, stack), "한 묶음을 덜어 낸다")
	expect(g.use[1] == false and g.use[2].n == n0, "앞 칸부터 준다 — 빈 칸은 비워진다(뒤의 것이 당겨 오지 않는다)")
	local ok15, why15 = Bag.take(g, P1, 9999)
	expect(ok15 == nil and why15 == "가진 것이 모자란다" and Bag.count(g, P1) == n0, "가진 것보다 많이는 덜지 못한다(하나도 줄지 않는다)")
	-- 새로 넣는 다른 아이템은 첫 빈 칸에
	expect(Bag.give(g, "etc_plate", 5) and g.etc[1].item == "etc_plate" and g.etc[1].n == 5, "기타 아이템은 기타 탭에")
	eq(Bag.used(g, "use"), 2, "소비 탭은 그대로")
	-- 옮기기: 빈 칸으로 · 자리 바꾸기 · 합치기
	local a = g.use[2]
	expect(Bag.move(g, "use", 2, 10) and g.use[2] == false and g.use[10] == a, "빈 칸으로 옮긴다")
	expect(Bag.move(g, "use", 10, 3) and g.use[3] == a and g.use[10].item == P2, "다른 것이 있는 칸: 자리를 바꾼다")
	g.use[5] = { item = P1, n = stack - 2 }
	local all = Bag.count(g, P1)
	expect(Bag.move(g, "use", 3, 5), "같은 것이 든 칸에 놓는다")
	eq(g.use[5].n, stack, "합쳐져 한 묶음이 찬다")
	expect((n0 > 2 and g.use[3] ~= false and g.use[3].n == n0 - 2) or (n0 <= 2 and g.use[3] == false), "넘치는 만큼은 남는다")
	eq(Bag.count(g, P1), all, "합쳐도 수는 그대로다")
	expect(Bag.move(g, "use", 5, 5), "제자리에 놓으면 아무 일도 없다")
	for _, bad in { { "use", 4, 6 }, { "use", 5, 999 }, { "use", 0, 1 }, { "use", 1.5, 2 }, { "bad", 1, 2 }, { "equip", 1, 2 }, { "use", "a", 2 }, { "use", 5, nil } } do
		eq(Bag.move(g, bad[1], bad[2], bad[3]), nil, ("옮길 수 없다(%s %s → %s)"):format(tostring(bad[1]), tostring(bad[2]), tostring(bad[3])))
	end
	eq(Bag.count(g, P1), all, "안 되는 옮기기는 아무것도 바꾸지 않는다")
	-- 장비도 칸을 옮긴다 — 놓인 자리는 그대로이고, 새로 얻은 것은 첫 빈 칸에
	local e1, e2, e3 = Items.make("hat", 1, 3), Items.make("suit", 1, 3), Items.make("glove", 1, 3)
	eq(Bag.add(g, e1), 1, "첫 칸")
	eq(Bag.add(g, e2), 2, "둘째 칸")
	expect(Bag.move(g, "gear", 1, 6) and g.gear[1] == false and g.gear[6] == e1, "장비를 빈 칸으로")
	eq(Bag.add(g, e3), 1, "새로 얻은 것은 첫 빈 칸에")
	expect(Bag.move(g, "gear", 6, 2) and g.gear[2] == e1 and g.gear[6] == e2, "장비끼리 자리를 바꾼다")
	-- 장착: 끼고 있던 것이 그 칸으로 · 해제: 첫 빈 칸(고른 칸이 비어 있으면 그 칸)
	local wornHat = g.equip.hat
	expect(Bag.equip(g, e1.id) and g.equip.hat == e1 and g.gear[2] == wornHat, "장착하면 끼고 있던 것이 그 칸으로 온다")
	expect(Bag.unequip(g, "hat", 9) and g.gear[9] == e1 and g.equip.hat == nil, "고른 빈 칸으로 해제한다")
	expect(Bag.equip(g, e1.id) and g.gear[9] == false, "끼고 있던 것이 없으면 그 칸은 빈다")
	expect(Bag.unequip(g, "hat", 2) and g.gear[3] == e1, "고른 칸이 차 있으면 첫 빈 칸으로")
	-- 정렬(소비): 같은 것끼리 합친 뒤 목록의 차례로 앞에서부터
	g.use[20] = { item = P2, n = 5 }
	g.use[24] = { item = P1, n = 7 }
	local c1, c2 = Bag.count(g, P1), Bag.count(g, P2)
	expect(Bag.sort(g, "use"), "소비 탭을 정렬한다")
	eq(Bag.count(g, P1), c1, "정렬해도 수는 그대로 1")
	eq(Bag.count(g, P2), c2, "정렬해도 수는 그대로 2")
	local stacks1 = math.ceil(c1 / stack)
	for i = 1, stacks1 do
		expect(g.use[i] ~= false and g.use[i].item == P1 and g.use[i].n == (if i < stacks1 then stack else c1 - stack * (stacks1 - 1)), "앞에서부터 가득 찬 묶음 " .. i)
	end
	expect(g.use[stacks1 + 1].item == P2 and g.use[stacks1 + 1].n == c2, "그 뒤에 다음 아이템(한 묶음으로 합쳐졌다)")
	eq(Bag.used(g, "use"), stacks1 + 1, "빈 데 없이 앞에서부터")
	eq(#g.use, Bag.size(g), "정렬해도 칸의 수는 그대로")
	-- 정렬(장비): 부위 → 내 직업의 무기 먼저 → 레벨이 높은 것 → 성능 → 강화. 부서진 것은 맨 뒤
	local sg = Hero.new(32, "axion")
	local list = {
		Items.make("hat", 10, 3), Items.make("weapon", 30, 3, "riven"), Items.make("hat", 20, 1), Items.make("weapon", 1, 5, "axion"),
		Items.make("hat", 20, 4), Items.make("ring", 10, 3), Items.make("weapon", 10, 3, "axion"), Items.make("glove", 60, 5),
	}
	list[8].broken = true
	for i, it in list do
		Bag.add(sg, it)
		Bag.move(sg, "gear", i, 25 - i * 2) -- 흩어 놓는다
	end
	expect(Bag.sort(sg, "gear"), "장비 탭을 정렬한다")
	local want = { list[7], list[4], list[2], list[5], list[3], list[1], list[6], list[8] }
	for i, it in want do
		eq(sg.gear[i], it, ("정렬한 차례 %d: %s"):format(i, Items.name(it)))
	end
	eq(Bag.used(sg), #list, "정렬해도 수는 그대로")
	eq(Bag.sort(sg, "bad"), nil, "없는 탭")
	-- 버리기: 소비 · 기타만(장비는 분해한다)
	local d0 = g.use[1].n
	expect(Bag.discard(g, "use", 1, 3) and g.use[1].n == d0 - 3, "셋을 버린다")
	eq(Bag.discard(g, "use", 1, d0), nil, "그 칸에 든 것보다 많이는 못 버린다")
	eq(Bag.discard(g, "use", 1, 0), nil, "0개")
	eq(Bag.discard(g, "use", 23, 1), nil, "빈 칸")
	local okD, whyD = Bag.discard(g, "gear", 1, 1)
	expect(okD == nil and whyD == "장비는 분해한다", "장비는 버리지 않는다")
	expect(Bag.discard(g, "use", 1, d0 - 3) and g.use[1] == false, "다 버리면 칸이 빈다")
	-- 가득 찬 탭: 더 넣지 못한다(하나도 들어가지 않는다) · 덜 찬 묶음에는 그만큼만
	for i = 1, Bag.size(g) do
		g.use[i] = { item = P2, n = stack }
	end
	eq(Bag.room(g, P1), 0, "빈 칸이 없으면 다른 아이템은 못 넣는다")
	local okF, whyF = Bag.give(g, P1, 1)
	expect(okF == nil and whyF == Bag.FULL, "가방이 가득 찼다")
	g.use[7].n = stack - 2
	eq(Bag.room(g, P2), 2, "덜 찬 묶음의 자리만큼")
	eq(Bag.give(g, P2, 3), nil, "다 들어가지 않으면 하나도 넣지 않는다")
	eq(g.use[7].n, stack - 2, "그대로다")
	expect(Bag.give(g, P2, 2) and g.use[7].n == stack, "딱 맞게는 들어간다")
	-- 늘리기: 세 탭이 함께 늘어난다
	g.money = 1e9
	local size0 = Bag.size(g)
	expect(Bag.grow(g), "가방을 늘린다")
	for _, tab in Bag.TABS do
		eq(#g[tab], size0 + D.BAG.step, "늘어난 칸 " .. tab)
		eq(g[tab][size0 + 1], false, "새 칸은 비어 있다 " .. tab)
	end
	expect(Bag.give(g, P1, 1) and g.use[size0 + 1].item == P1, "새 칸에 들어간다")
	-- 장착한 장비를 강화하다 부서지면 흔적이 가방에 들어간다 — 들어갈 칸이 없으면 시도하지 않는다(달가루도 그대로)
	local fg = Hero.new(33, "axion")
	fg.level = 150
	local big = Items.make("weapon", 140, 3, "axion")
	big.star = 15
	Bag.add(fg, big)
	Bag.equip(fg, big.id)
	for i = 1, Bag.size(fg) do
		if not fg.gear[i] then
			fg.gear[i] = Items.make("hat", 1, 3)
			fg.gear[i].id = 9000 + i
		end
	end
	fg.dust, fg.essence = 1e12, 1e6
	local okE, whyE = Bag.enhance(fg, big.id, Random.new(1))
	expect(okE == nil and whyE == "가방에 빈 칸이 하나 있어야 한다" and fg.dust == 1e12, "가방이 가득 차면 부서질 수 있는 강화는 시도하지 않는다")
	-- 저장: 놓인 칸까지 그대로 되살아난다
	local sv = Hero.new(34, "mooni")
	Bag.add(sv, Items.make("hat", 1, 4))
	Bag.move(sv, "gear", 1, 17)
	Bag.give(sv, P2, 250)
	Bag.move(sv, "use", 1, 11)
	Bag.give(sv, "etc_cloth", 12)
	Bag.move(sv, "etc", 1, 24)
	local packed = Hero.pack(sv)
	eq(#packed.bag.gear, 17, "맨 뒤의 빈 칸들은 저장하지 않는다")
	eq(packed.bag.gear[1], false, "빈 칸은 false로 저장한다")
	local back = Hero.unpack(34, packed)
	expect(back ~= nil and back.gear[17] ~= false and back.gear[17].q == 4 and back.gear[1] == false, "장비가 놓인 칸")
	for i = 1, Bag.size(sv) do
		for _, tab in { "use", "etc" } do
			local x, y = sv[tab][i], back[tab][i]
			expect((x == false and y == false) or (x ~= false and y ~= false and x.item == y.item and x.n == y.n), ("저장한 묶음이 그 칸에 그대로 %s %d"):format(tab, i))
		end
	end
	-- 깨진 묶음은 버린다(없는 아이템 · 다른 탭의 것 · 겹치는 수를 넘는 것 · 이상한 수)
	local broken = Hero.pack(sv)
	broken.bag.use = { { "no_such", 3 }, { "etc_cloth", 3 }, { P1, 201 }, { P1, 0 }, { P1, 2.5 }, "x", { P1, 9 } }
	broken.bag.etc = { { P1, 1 } }
	local fixed = Hero.unpack(34, broken)
	expect(fixed ~= nil and Bag.used(fixed, "use") == 1 and fixed.use[7].item == P1 and fixed.use[7].n == 9, "꼴이 맞는 묶음만 남는다(그 칸에)")
	eq(Bag.used(fixed, "etc"), 0, "다른 탭의 아이템은 버린다")
	-- 예전 저장(소비 · 기타 칸이 생기기 전): 숫자로만 갖고 있던 물약과 퀘스트의 물건이 가방의 아이템이 된다 — 잃는 것이 없다
	local Q15 = req("ReplicatedStorage/shared/lune/sim/quests")
	local old = Hero.new(35, "axion")
	old.level = 4
	old.quests.r1m3 = { done = false, c = { 3 } }
	local oldSave = Hero.pack(old)
	oldSave.bag.use, oldSave.bag.etc = nil, nil
	oldSave.potions = 17
	oldSave.bag.gear = { { "hat", 1, 4, 0, "", 0, 0 }, { "weapon", 1, 5, "axion", 0, 0 } }
	oldSave.bag.gear[2] = { "weapon", 1, 5, 0, "axion", 0, 0 }
	local moved = Hero.unpack(35, oldSave)
	expect(moved ~= nil, "예전 저장을 되살린다")
	eq(Bag.count(moved, P1), 17, "예전의 물약 수만큼 작은 달빛 물약이 가방에 든다")
	eq(Hero.potions(moved), 17, "처음 받는 물약이 더해지지 않는다")
	local item3 = Q15.def("r1m3").steps[1].item
	eq(Bag.count(moved, item3), 3, "퀘스트가 세어 둔 수만큼 물건이 가방에 든다")
	eq(moved.quests.r1m3.c[1], 3, "퀘스트의 숫자는 그대로다")
	expect(moved.gear[1] ~= false and moved.gear[2] ~= false and moved.gear[3] == false, "예전의 장비는 앞 칸부터 그대로")
	oldSave.level = 61
	eq(Bag.count(Hero.unpack(35, oldSave), "potion3"), 17, "Lv.61이었다면 그때 마시던 큰 달빛 물약으로")
	local again = Hero.unpack(35, Hero.pack(moved))
	expect(Bag.count(again, P1) == 17 and Bag.count(again, item3) == 3, "한 번 옮긴 뒤에는 다시 옮기지 않는다(두 배가 되지 않는다)")
	-- 물약: 고른 것을 마신다 · 내 레벨에 못 쓰는 것 · 없는 것
	local dr = Hero.new(36, "axion")
	Bag.give(dr, P2, 2)
	dr.hp = 1
	local healed, whyH = Hero.drink(dr, P2)
	expect(healed == nil and whyH == "Lv.30부터 쓸 수 있다" and Bag.count(dr, P2) == 2, "아직 못 쓰는 물약은 줄지 않는다")
	eq(Hero.bestPotion(dr).id, P1, "지금 마실 수 있는 가장 좋은 물약")
	healed = Hero.drink(dr, P1)
	expect(healed ~= nil and healed > 0 and Bag.count(dr, P1) == n0 - 1, "고른 물약을 마신다")
	dr.level = 30
	dr.potionWait, dr.hp = 0, 1
	eq(Hero.bestPotion(dr).id, P2, "레벨이 되면 윗단의 물약이 가장 좋은 물약")
	healed = Hero.drink(dr)
	expect(healed ~= nil and Bag.count(dr, P2) == 1, "이름표를 안 주면 가장 좋은 물약을 마신다")
	dr.potionWait, dr.hp = 0, 1
	local none, whyN = Hero.drink(dr, "potion4")
	expect(none == nil and whyN == "가진 물약이 없다", "없는 물약")
	eq(Hero.drink(dr, "etc_plate"), nil, "물약이 아닌 것은 마시지 못한다")
	-- 보내는 것에서 수를 센다(퀵슬롯의 숫자)
	local view = Bag.view(dr)
	eq(Bag.countIn(view, P2), 1, "보낸 가방에서 센 수")
	eq(Bag.countIn(view, "potion4"), 0, "없는 것은 0")
	eq(Bag.countIn(nil, P1), 0, "가방이 아직 없으면 0")
end

-- ---- 16) 아이템의 상세(창 옆의 작은 판에 적는 글) — 공방의 본보기와 같다 ----
do
	local Info = req("ReplicatedStorage/shared/lune/ui/itemInfo")
	local F = req("ReplicatedStorage/shared/lune/ui/format")
	local function same(got, want, label)
		eq(got.name, want.name, label .. ": 이름")
		eq(got.tone, want.tone, label .. ": 이름의 색")
		eq(got.sub, want.sub, label .. ": 갈래")
		eq(#got.rows, #want.rows, label .. ": 줄의 수")
		for i, row in want.rows do
			for k = 1, 3 do
				eq(got.rows[i] and got.rows[i][k], row[k], ("%s: 줄 %d의 %d"):format(label, i, k))
			end
		end
		eq(#got.notes, #want.notes, label .. ": 알림 글의 수")
		for i, note in want.notes do
			eq(got.notes[i] and got.notes[i][1], note[1], ("%s: 알림 글 %d"):format(label, i))
			eq(got.notes[i] and got.notes[i][2], note[2], ("%s: 알림 글 %d의 색"):format(label, i))
		end
	end
	expect(#C.info.gear >= 8 and #C.info.goods >= 8, "본보기가 넉넉하다")
	for i, c in C.info.gear do
		same(Info.gear(c[1], { level = c[2], class = c[3] }, c[4] or nil, c[5]), c[6], "장비 " .. i)
	end
	for _, c in C.info.goods do
		same(Info.goods(c[1], { level = c[2], class = "axion" }, c[3]), c[4], ("%s Lv.%d %d개"):format(c[1], c[2], c[3]))
	end
	for _, c in C.info.short do
		eq(F.short(c[1]), c[2], "짧게 적은 수 " .. tostring(c[1]))
	end
	-- 아이템마다: 이름 · 그림 · 겹치는 수 · 설명이 있다. 소비 아이템의 그림은 퀵슬롯용(24도트)도 있다
	local seenId = {}
	for _, g in D.GOODS do
		expect(not seenId[g.id], "이름표가 겹치지 않는다 " .. g.id)
		seenId[g.id] = true
		expect(g.tab == "use" or g.tab == "etc", "탭 " .. g.id)
		expect(#g.name > 0 and #g.text > 0 and g.stack >= 1, "이름 · 설명 · 겹치는 수 " .. g.id)
		expect(KIT.parts.icons.icons[g.icon] ~= nil, "그림(게임 세계의 18도트) " .. g.id)
		if g.tab == "use" then
			expect(KIT.parts.pics.icons[g.icon] ~= nil, "퀵슬롯의 그림(24도트) " .. g.id)
		end
	end
	eq(Items.potionFor(1).id, "potion1", "Lv.1의 물약")
	eq(Items.potionFor(29).id, "potion1", "Lv.29의 물약")
	eq(Items.potionFor(30).id, "potion2", "Lv.30의 물약")
	eq(Items.potionFor(150).id, "potion4", "Lv.150의 물약")
	eq(Items.goods(7), nil, "이름표가 글이 아니면 없다")
end

-- ---- 17) 창고(세 탭) · 묶음 나누기 · 상점에 팔기 ----
--  사용자 2026-10-08: "소비, 기타아이템도 창고에 맡길수있어야하고, 상점에 팔기 가능해야하고 묶음나누기 가능해야하고 창고에 드래그앤 드랍으로 맡기기가능해야합니다."
do
	local P1, P2 = "potion1", "potion2"
	local stack = Items.goods(P1).stack
	local w = Hero.new(41, "axion")
	local n0 = Bag.count(w, P1)
	-- 창고는 가방과 같은 짜임: 탭 셋 · 탭마다 칸(빈 칸은 false)
	for _, tab in Bag.TABS do
		eq(#w.store[tab], Bag.storeSize(w), "창고의 칸 수 " .. tab)
		eq(Bag.stored(w, tab), 0, "새 캐릭터의 창고는 비어 있다 " .. tab)
	end
	-- 묶음 맡기기: 몇 개만 · 고른 칸에(끌어다 놓은 칸) · 같은 묶음에 겹치기 · 전부
	Bag.give(w, P1, 50)
	expect(Bag.storeIn(w, "use", 1, 20), "스무 개만 맡긴다")
	expect(w.use[1].n == n0 + 30 and w.store.use[1].item == P1 and w.store.use[1].n == 20, "가방에서 줄고 창고의 첫 칸에 놓인다")
	expect(Bag.storeIn(w, "use", 1, 5, 7) and w.store.use[7].n == 5 and w.store.use[1].n == 20, "빈 칸을 고르면 그 칸에 새 묶음")
	expect(Bag.storeIn(w, "use", 1, 3, 7) and w.store.use[7].n == 8, "같은 묶음이 든 칸에 놓으면 겹친다")
	Bag.give(w, P2, 4)
	expect(Bag.storeIn(w, "use", 2, nil, 7), "다른 것이 든 칸을 고르면 알아서 놓인다")
	expect(w.use[2] == false and w.store.use[2].item == P2 and w.store.use[2].n == 4 and w.store.use[7].n == 8, "수를 안 주면 전부 · 첫 빈 칸에")
	expect(Bag.storeIn(w, "use", 1) and w.use[1] == false and w.store.use[1].n == n0 + 42, "남은 것을 전부 맡긴다: 같은 묶음에 겹친다")
	eq(Bag.count(w, P1), 0, "가방에는 남지 않는다")
	eq(Bag.storeIn(w, "use", 1), nil, "빈 칸은 맡길 것이 없다")
	eq(Bag.storeIn(w, "bad", 1), nil, "없는 탭")
	eq(Bag.storeOut(w, "use", 1, 9999), nil, "맡긴 것보다 많이는 못 찾는다")
	eq(Bag.storeOut(w, "use", 1, 0), nil, "0개")
	eq(Bag.storeOut(w, "use", 1, 1.5), nil, "소수")
	eq(Bag.storeOut(w, "use", 20), nil, "창고의 빈 칸")
	-- 찾기: 몇 개만 · 가방의 고른 칸에 · 전부(가방의 같은 묶음에 겹친다)
	expect(Bag.storeOut(w, "use", 1, 10, 5) and w.use[5].item == P1 and w.use[5].n == 10 and w.store.use[1].n == n0 + 32, "열 개를 가방의 고른 칸(5)에")
	expect(Bag.storeOut(w, "use", 7) and w.store.use[7] == false and w.use[5].n == 18, "한 묶음 전부를 찾는다 — 가방의 같은 묶음에 겹친다")
	-- 기타 아이템도 맡긴다 · 탭끼리는 섞이지 않는다
	Bag.give(w, "etc_plate", 6)
	expect(Bag.storeIn(w, "etc", 1, 4) and w.store.etc[1].item == "etc_plate" and w.store.etc[1].n == 4 and w.etc[1].n == 2, "기타 아이템도 맡긴다")
	expect(Bag.stored(w, "gear") == 0 and Bag.stored(w, "use") == 2 and Bag.stored(w, "etc") == 1, "탭마다 칸이 따로다")
	-- 창고 안에서 옮기기 · 정렬
	expect(Bag.move(w, "use", 1, 10, true) and w.store.use[1] == false and w.store.use[10].item == P1, "창고 안에서 빈 칸으로 옮긴다")
	expect(Bag.move(w, "use", 2, 10, true) and w.store.use[2].item == P1 and w.store.use[10].item == P2, "창고 안에서 자리를 바꾼다")
	eq(Bag.move(w, "use", 1, Bag.storeSize(w) + 1, true), nil, "창고의 칸 밖으로는 못 옮긴다")
	expect(Bag.sort(w, "use", true) and w.store.use[1].item == P1 and w.store.use[2].item == P2 and Bag.stored(w, "use") == 2, "창고의 탭을 정렬한다(앞에서부터 목록의 차례)")
	expect(Bag.used(w, "use") == 1 and w.use[5].n == 18, "창고를 정렬해도 가방은 그대로다")
	-- 창고가 가득 차면: 다 들어가지 않으면 하나도 맡기지 않는다 · 덜 찬 묶음의 자리만큼은 된다
	local keepStore = w.store.use
	w.store.use = table.create(Bag.storeSize(w), false)
	for i = 1, Bag.storeSize(w) do
		w.store.use[i] = { item = P2, n = stack }
	end
	local okS, whyS = Bag.storeIn(w, "use", 5)
	expect(okS == nil and whyS == "창고가 가득 찼다" and w.use[5].n == 18, "창고가 가득 차면 맡기지 못한다")
	w.store.use[3].n = stack - 2
	Bag.give(w, P2, 5)
	eq(Bag.storeIn(w, "use", 1), nil, "다섯 개가 다 들어가지 않으면 하나도 맡기지 않는다")
	expect(Bag.storeIn(w, "use", 1, 2) and w.use[1].n == 3 and w.store.use[3].n == stack, "자리가 있는 만큼(둘)은 맡긴다")
	w.store.use = keepStore
	-- 가방이 가득 차면 찾지 못한다
	local keepBag = w.use
	w.use = table.create(Bag.size(w), false)
	for i = 1, Bag.size(w) do
		w.use[i] = { item = P2, n = stack }
	end
	local okO, whyO = Bag.storeOut(w, "use", 1)
	expect(okO == nil and whyO == Bag.FULL and w.store.use[1].item == P1, "가방이 가득 차면 찾지 못한다")
	w.use = keepBag
	-- 장비: 창고의 고른 칸에 · 차 있으면 첫 빈 칸 · 가방의 고른 칸으로 찾기
	local g1, g2 = Items.make("hat", 1, 3), Items.make("suit", 1, 3)
	local a1, a2 = Bag.add(w, g1), Bag.add(w, g2)
	expect(Bag.storeIn(w, "gear", a1, nil, 9) and w.store.gear[9] == g1 and w.gear[a1] == false, "장비를 창고의 고른 칸에")
	expect(Bag.storeIn(w, "gear", a2, nil, 9) and w.store.gear[1] == g2, "고른 칸이 차 있으면 첫 빈 칸에")
	expect(Bag.storeOut(w, "gear", 9, nil, 20) and w.gear[20] == g1 and w.store.gear[9] == false, "창고의 장비를 가방의 고른 칸으로")
	expect(select(2, Bag.find(w, g2.id)) == "store", "창고의 장비도 번호로 찾는다")
	w.dust = 1e9
	eq(Bag.enhance(w, g2.id, Random.new(1)), nil, "창고의 것은 강화하지 못한다")
	-- 저장: 창고도 놓인 칸까지 그대로 되살아난다
	local back = Hero.unpack(41, Hero.pack(w))
	expect(back ~= nil, "창고가 있는 캐릭터를 되살린다")
	for i = 1, Bag.storeSize(w) do
		local x, y = w.store.gear[i], back.store.gear[i]
		expect((x == false and y == false) or (x ~= false and y ~= false and x.slot == y.slot and x.stage == y.stage and x.q == y.q), "창고의 장비가 그 칸에 그대로 " .. i)
		for _, tab in { "use", "etc" } do
			local p, q = w.store[tab][i], back.store[tab][i]
			expect((p == false and q == false) or (p ~= false and q ~= false and p.item == q.item and p.n == q.n), ("창고의 묶음이 그 칸에 그대로 %s %d"):format(tab, i))
		end
	end
	-- 화면에 보내는 것: 창고도 탭마다 칸들
	local v = Bag.view(w)
	expect(#v.store.gear == Bag.storeSize(w) and #v.store.use == Bag.storeSize(w) and #v.store.etc == Bag.storeSize(w), "보내는 창고의 칸 수")
	expect(v.store.gear[1].id == g2.id and v.store.use[1].item == P1 and v.store.etc[1].n == 4 and v.store.use[5] == false, "보내는 창고의 칸들")
	-- 예전 저장(창고가 장비만 차례로 늘어놓던 때): 장비 탭의 앞 칸부터 그대로
	local oldS = Hero.pack(Hero.new(44, "mooni"))
	oldS.bag.store = { { "hat", 10, 2, 0, "", 0, 0 }, { "suit", 1, 3, 2, "", 0, 0 } }
	local mv = Hero.unpack(44, oldS)
	expect(mv ~= nil and mv.store.gear[1].slot == "hat" and mv.store.gear[2].star == 2 and Bag.stored(mv) == 2 and Bag.stored(mv, "use") == 0, "예전 창고의 장비는 잃지 않는다")
	expect(Bag.stored(Hero.unpack(44, Hero.pack(mv))) == 2, "새 꼴로 저장한 뒤에도 그대로다")
	-- 깨진 창고: 이상한 것은 버린다
	local badS = Hero.pack(mv)
	badS.bag.store = { gear = { { "wing", 1, 3, 0, "", 0, 0 }, { "hat", 1, 3, 0, "", 0, 0 } }, use = { { "etc_plate", 3 }, { P1, 5 }, { P1, 999 } }, etc = "x" }
	local fixedS = Hero.unpack(44, badS)
	expect(fixedS ~= nil and fixedS.store.gear[1] == false and fixedS.store.gear[2].slot == "hat" and Bag.stored(fixedS, "use") == 1 and fixedS.store.use[2].n == 5 and Bag.stored(fixedS, "etc") == 0, "꼴이 맞는 것만 남는다")

	-- 묶음 나누기
	local sp = Hero.new(42, "axion")
	sp.use[1] = { item = P1, n = 40 }
	expect(Bag.split(sp, "use", 1, 15) and sp.use[1].n == 25 and sp.use[2].item == P1 and sp.use[2].n == 15, "묶음에서 열다섯을 덜어 첫 빈 칸에 새 묶음으로")
	expect(Bag.split(sp, "use", 1, 5, 9) and sp.use[9].n == 5 and sp.use[1].n == 20, "고른 빈 칸에 나눈다")
	expect(Bag.split(sp, "use", 1, 1, 2) and sp.use[3].n == 1 and sp.use[2].n == 15, "고른 칸이 차 있으면 첫 빈 칸에")
	eq(Bag.count(sp, P1), 40, "나눠도 가진 수는 그대로다")
	eq(Bag.split(sp, "use", 3, 1), nil, "하나짜리 묶음은 나눌 수 없다")
	eq(Bag.split(sp, "use", 1, 19), nil, "전부를 덜어 낼 수는 없다(옮기기다)")
	eq(Bag.split(sp, "use", 1, 0), nil, "0개")
	eq(Bag.split(sp, "use", 1, 2.5), nil, "소수")
	eq(Bag.split(sp, "use", 20, 1), nil, "빈 칸")
	local okG, whyG = Bag.split(sp, "gear", 1, 1)
	expect(okG == nil and whyG == "묶음이 아니다", "장비는 나누지 못한다")
	local keepSp = table.clone(sp.use)
	for i = 1, Bag.size(sp) do
		sp.use[i] = sp.use[i] or { item = P2, n = 1 }
	end
	local okF, whyF = Bag.split(sp, "use", 1, 3)
	expect(okF == nil and whyF == Bag.FULL and sp.use[1].n == 19, "빈 칸이 없으면 나누지 못한다")
	sp.use = keepSp
	expect(Bag.sort(sp, "use") and sp.use[1].n == 40 and Bag.used(sp, "use") == 1, "정렬하면 다시 한 묶음으로 합쳐진다")

	-- 상점에 팔기
	local sl = Hero.new(43, "axion")
	sl.use[1] = { item = P2, n = 10 }
	local m0 = sl.money
	local one = Items.goodsSell(P2)
	expect(one >= 1, "물약은 팔 수 있다")
	eq(Bag.sell(sl, "use", 1, 3), 3 * one, "세 개를 판 값")
	expect(sl.money == m0 + 3 * one and sl.use[1].n == 7, "달돈이 늘고 묶음이 준다")
	eq(Bag.sell(sl, "use", 1), 7 * one, "수를 안 주면 전부 판다")
	expect(sl.use[1] == false and sl.money == m0 + 10 * one, "다 팔면 칸이 빈다")
	Bag.give(sl, "etc_plate", 2)
	local no, whyNo = Bag.sell(sl, "etc", 1, 1)
	expect(no == nil and whyNo == "팔 수 없는 물건이다" and sl.etc[1].n == 2, "퀘스트의 물건은 팔 수 없다")
	local gear = Items.make("weapon", 20, 5, "riven")
	gear.star = 3
	local ga = Bag.add(sl, gear)
	local m1 = sl.money
	eq(Bag.sell(sl, "gear", ga), Items.sellPrice(gear), "장비를 판 값")
	expect(sl.gear[ga] == false and sl.money == m1 + Items.sellPrice(gear), "장비가 가방에서 빠지고 달돈이 는다")
	eq(Items.sellPrice(gear), Items.sellPrice(Items.make("weapon", 20, 1, "axion")), "성능과 별은 값에 들어가지 않는다")
	eq(Bag.sell(sl, "gear", ga), nil, "빈 칸은 팔 것이 없다")
	sl.use[1] = { item = P1, n = 5 }
	eq(Bag.sell(sl, "use", 1, 0), nil, "0개")
	eq(Bag.sell(sl, "use", 1, 6), nil, "가진 것보다 많이")
	eq(Bag.sell(sl, "use", 1, 1.5), nil, "소수")
	eq(Bag.sell(sl, "bad", 1, 1), nil, "없는 탭")
	eq(Bag.sell(sl, "gear", 999), nil, "없는 칸")
	eq(Bag.sell(sl, "equip", "weapon"), nil, "끼고 있는 것은 팔지 못한다")
	-- 값: 공방의 셈과 같다(모든 단계) · 사서 되팔면 늘 손해다 · 퀘스트의 물건은 0
	for _, c in C.info.sell do
		eq(Items.sellPrice({ slot = c[1], stage = c[2] }), c[3], ("파는 값 %s Lv.%d"):format(c[1], c[2]))
	end
	for _, st in D.STOCK do
		if st.goods then
			expect(Items.goodsSell(st.goods) < st.price, "사서 되팔면 손해다 " .. st.id)
		elseif st.item then
			expect(Items.sellPrice({ slot = st.item.slot, stage = st.item.stage }) < st.price, "사서 되팔면 손해다 " .. st.id)
		end
	end
	for _, g in D.GOODS do
		expect((g.kind == "quest") == (g.sell == 0), "퀘스트의 물건만 팔 수 없다 " .. g.id)
	end
	eq(Items.goodsSell("no_such"), 0, "없는 아이템의 값은 0")
end
