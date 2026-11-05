-- 「달의 계승자」 — 달빛 상점: 여러 개를 한 번에 · 나눠 받기(2026-11-06 사용자: "로벅스 경험치 쿠폰이나, 드롭률 쿠폰같은거 살때 여러수량을 한번에 구매요청하고
--   로벅스도 그 개수에맞춰 구매할수있게 결제처리 연결되고 쉽게 살수있어야해" · "달빛상점 에서 물건 구매하고나서 수령을 나눠서 할수있어야해 지금 수령하면 그냥 다 수령되어버린다")
--  ① 묶음 상품(5개 · 10개): 담긴 상품 · 수 · 값 = 한 개 값 x 수 ② 결제 하나 → 그 수만큼 보관함에(같은 결제 번호는 두 번 주지 않는다) · 주머니 · 상자는 레벨대 그대로
--  ③ 나눠 받기: 줄에서 n개만 가방으로 · 나머지는 보관함에(상점 창의 수 고르기 — 시험 62)
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local NOW = 1_790_000_000

-- ① 묶음의 표
for _, base in { "bagx", "exp", "drop", "money", "dust" } do
	local one = Cash.product(base)
	for _, n in { 5, 10 } do
		local p = Cash.product(base .. "_x" .. n)
		expect(p ~= nil, ("묶음 %s_x%d가 있다"):format(base, n))
		if p then
			eq(p.of, base, p.id .. "에 담긴 상품")
			eq(p.n, n, p.id .. "의 수")
			eq(p.robux, one.robux * n, p.id .. "의 값 = 한 개 값 x 수")
			eq(p.kind, "product", p.id .. "는 개발자 상품")
			expect(p.built == true, p.id .. "는 게임에 만들어 두었다(번호가 오면 바로 판다)")
			eq(p.trade, one.trade, p.id .. "의 거래는 한 개와 같다")
		end
	end
end

-- ② 결제 하나 → n개
local acct = Account.new()
acct.chars[1] = { hero = { level = 47 } } -- (레벨대 Lv.40)
expect(Cash.grant(acct, "exp_x10", "p1", NOW, Account.MAX), "경험치 쿠폰 10개를 산다")
local again = Cash.grant(acct, "exp_x10", "p1", NOW, Account.MAX)
expect(not again, "같은 결제 번호는 두 번 주지 않는다")
expect(Cash.grant(acct, "exp_x5", "p2", NOW, Account.MAX), "경험치 쿠폰 5개를 산다")
expect(Cash.grant(acct, "money_x5", "p3", NOW, Account.MAX), "달돈 주머니 5개를 산다")
local function boxOf(id)
	for i, e in acct.bm.box do
		if e.id == id then
			return e.n, i
		end
	end
	return 0, nil
end
eq(boxOf("bm_exp"), 15, "보관함에 경험치 쿠폰 15개(10 + 5)")
eq(boxOf("bm_money_40"), 5, "보관함에 달돈 주머니(Lv.40) 5개")
expect(Cash.grant(acct, "dust_x10", "p4", NOW, Account.MAX), "달가루 상자 10개")
eq(boxOf("bm_dust_40"), 10, "달가루 상자(Lv.40) 10개")
expect(Cash.grant(acct, "bagx_x5", "p5", NOW, Account.MAX), "가방 확장권 5장")
eq(boxOf("bm_bagx"), 5, "가방 확장권 5장")
expect(Cash.grant(acct, "drop_x5", "p6", NOW, Account.MAX), "드롭률 쿠폰 5개")
eq(boxOf("bm_drop"), 5, "드롭률 쿠폰 5개")

-- ③ 나눠 받기
local h = Hero.new(1, "axion")
local _, row = boxOf("bm_exp")
local moved = Cash.take(h, acct.bm, row, 4)
eq(moved, 4, "경험치 쿠폰 4개만 받는다")
eq(Bag.countIn(Bag.view(h), "bm_exp"), 4, "가방에 4개")
eq(boxOf("bm_exp"), 11, "보관함에 11개가 남는다")
_, row = boxOf("bm_exp")
moved = Cash.take(h, acct.bm, row, 99)
eq(moved, 11, "남은 것보다 많이 적으면 남은 만큼(11)")
eq(boxOf("bm_exp"), 0, "그 줄이 비면 보관함에서 빠진다")
local _, mrow = boxOf("bm_money_40")
moved = Cash.take(h, acct.bm, mrow)
eq(moved, 5, "수를 적지 않으면 그 줄을 모두(그 전과 같다)")
local before = #acct.bm.box
moved = Cash.take(h, acct.bm, 1, 0)
expect(moved > 0, "0 같은 틀린 수는 그 줄을 모두로 본다(받을 수는 1부터)")
expect(#acct.bm.box < before or moved > 0, "받았다")

-- (④ 상점 창의 수 고르기는 시험 62)
