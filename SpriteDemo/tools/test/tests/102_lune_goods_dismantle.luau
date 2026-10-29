-- 「달의 계승자」 — 물약 · 귀환 주문서 분해 · 귀환 주문서 드롭(2026-10-27 사용자: "마을귀환주문서 드롭확률 줄이고, 포션이랑 마을귀환주문서 분해할수있게하고 분해하면 소량의 달가루 주는형식으로").
--  보는 것: ① 하나의 몫(상점 값의 4분의 1어치 — 소수)에 수를 곱해 내린다 · 작은 물약은 14개부터 1 ② 사서 분해해도 달가루를 사는 것보다 비싸다(달가루를 만들어 내는 길이 없다)
--   ③ 가방에서 분해: 그 칸에서 그 수만큼 빠지고 달가루가 는다 · 0이 되는 수 · 모자란 수 · 분해할 수 없는 것은 그대로 ④ 귀환 주문서 드롭 5%
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local D = Items.data

-- ① 몫
eq(Items.goodsDust("potion1", 13), 0, "작은 물약 13개 = 달가루 0")
eq(Items.goodsDust("potion1", 14), 1, "작은 물약 14개 = 달가루 1")
eq(Items.goodsDust("potion4", 1), 6, "맑은 물약 하나 = 달가루 6")
eq(Items.goodsDust("scroll_return", 1), 1, "귀환 주문서 하나 = 달가루 1")
eq(Items.goodsDust("scroll_return", 4), 5, "귀환 주문서 넷 = 달가루 5(1.25 x 4)")
eq(Items.goodsDust("charm", 1), nil, "달빛 부적은 분해하지 않는다")
eq(Items.goodsDust("mat_ore1", 1), nil, "재료는 분해하지 않는다")

-- ② 사서 분해해 달가루를 버는 길이 없다: 상점 값 ≥ 받는 달가루 x 달가루 값(어느 수든)
local dustPrice
for _, s in D.STOCK do
	if s.id == "dust" then
		dustPrice = s.price
	end
end
expect(dustPrice ~= nil and dustPrice > 0, "상인이 파는 달가루의 값")
local priced = 0
for _, s in D.STOCK do
	if s.goods and s.price and Items.goodsDust(s.goods, 1) ~= nil then
		priced += 1
		for _, n in { 1, 7, 14, 99, 200 } do
			expect(s.price * n >= Items.goodsDust(s.goods, n) * dustPrice, ("사서 분해해도 손해다 — %s x%d"):format(s.goods, n))
		end
	end
end
eq(priced, 5, "상점에서 파는 분해할 수 있는 것 다섯(물약 넷 · 귀환 주문서)")

-- ③ 가방에서 분해
local h = Hero.new(1, "axion")
for i = 1, Bag.size(h) do
	h.gear[i], h.use[i], h.etc[i] = false, false, false
end
h.dust = 0
Bag.give(h, "potion1", 20)
Bag.give(h, "scroll_return", 3)
Bag.give(h, "charm", 1)
local function slotOf(id: string): number?
	for i = 1, Bag.size(h) do
		if h.use[i] and h.use[i].item == id then
			return i
		end
	end
	return nil
end
local p1, sc, ch = slotOf("potion1"), slotOf("scroll_return"), slotOf("charm")
local got, why = Bag.dismantleGoods(h, "use", p1, 13)
expect(got == nil and why ~= nil and h.use[p1].n == 20 and h.dust == 0, "달가루가 0이 되는 수는 분해하지 않는다 — " .. tostring(why))
got = Bag.dismantleGoods(h, "use", p1, 14)
expect(got == 1 and h.use[p1].n == 6 and h.dust == 1, "작은 물약 14개 → 달가루 1 · 6개가 남는다")
got = Bag.dismantleGoods(h, "use", sc, 3)
expect(got == 3 and h.use[sc] == false and h.dust == 4, "귀환 주문서 셋 → 달가루 3 · 칸이 빈다")
got, why = Bag.dismantleGoods(h, "use", p1, 7)
expect(got == nil and h.use[p1].n == 6, "가진 것보다 많이는 못 한다 — " .. tostring(why))
got, why = Bag.dismantleGoods(h, "use", ch, 1)
expect(got == nil and h.use[ch].n == 1, "분해할 수 없는 것은 그대로 — " .. tostring(why))
got = Bag.dismantleGoods(h, "gear", 1, 1)
expect(got == nil, "장비 탭은 이 길이 아니다(장비 분해는 따로)")
got = Bag.dismantleGoods(h, "use", 0, 1)
expect(got == nil, "없는 칸")
got = Bag.dismantleGoods(h, "use", p1, 1.5)
expect(got == nil, "수는 정수만")

-- ④ 귀환 주문서 드롭
local rare
for _, r in D.RARE or {} do
	if r.goods == "scroll_return" then
		rare = r
	end
end
expect(rare ~= nil and rare.pct == 5, "귀환 주문서는 한 마리에 5%(전에는 20%) — " .. tostring(rare and rare.pct))

-- 수량 창의 글
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
expect(UI.words.ask.dismantleGoods ~= nil and UI.layout.count.words.gainDust ~= nil, "수량 창의 글(몇 개를 분해할까요? · 받을 달가루)")
