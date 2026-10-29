-- 「달의 계승자」 — 유료 상품(로벅스 — 2026-10-20). 사용자: "1. 스타포스 관련은 판매하지않는다 2. 달가루, 달돈 계정당 수량 제한해서 판다 3. … 경매장에서 거래가능 …"
--  · "경험치 쿠폰 판매해도 됩니다. 꾸밈탈것 만들어도 됩니다. 만들어 봅시다"
--  ① 상품 표 ↔ 아이템 표 ② 결제 하나 = 한 번(같은 결제 번호는 두 번 주지 않는다) ③ 주간 수 · 계정에 한 번 ④ 보관함 → 가방 ⑤ 쓰기(주머니 · 상자 · 확장권 · 쿠폰)
--  ⑥ 저장(DataStore처럼 JSON을 한 번 거쳐) ⑦ 사서 늘린 캐릭터 칸 ⑧ 서버의 결제 처리(저장 실패 → 되돌리고 「아직」 · 이미 준 결제 → 「줬다」)
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")

local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local n = 0
	for _ in v do
		n += 1
	end
	local array = n > 0 and #v == n
	local out = {}
	for k, x in v do
		out[if array then k else tostring(k)] = json(x)
	end
	return out
end

-- ① 표가 맞는가
eq(#Cash.check(), 0, "유료 아이템이 아이템 표에 다 있다(주머니 · 상자 16레벨대 · 확장권 · 이름 · 쿠폰)")
for _, p in BM.products do
	expect(not string.find(p.name, "스타포스") and not string.find(p.name, "강화"), "스타포스 · 강화 상품이 없다(결정 1): " .. p.name)
	-- (재화 상품의 수량 제한 — 결정 2 — 은 2026-10-22 사용자 "달빛상점에서 달가루 상자, 달돈주머니 구매 제한 푼다"로 뺐다: 아래 ③)
	if p.trade then
		eq(p.kind, "product", "거래되는 것은 아이템으로 받는 상품뿐(결정 3): " .. p.id)
	end
end
for _, b in BM.bands do
	expect(Items.goods("bm_money_" .. b).sell >= 1, "상인에게 팔 때 1달돈 이상(못 파는 것은 퀘스트 물건뿐)")
end

-- 계정 하나 · 캐릭터 하나(Lv.37)
local NOW = 1792800000 -- 어느 날
local acct = Account.new()
local h = Hero.new(1, "axion")
h.level = 37
Account.add(acct, "달빛", "axion", Hero.pack(h), NOW)
eq(Cash.topLevel(acct), 37, "계정의 가장 높은 레벨")
eq(Cash.bandOf(37), 30, "레벨대 = 10 단위로 내림")
eq(Cash.bandOf(5), 1, "1~9 = Lv.1")
eq(Cash.bandOf(150), 150, "끝 레벨")

-- ② 결제 하나 = 한 번
local ok = Cash.grant(acct, "money", "r1", NOW, Account.MAX)
expect(ok, "달돈 주머니를 준다")
eq(acct.bm.box[1].id, "bm_money_30", "레벨대의 주머니가 보관함에")
local again, why = Cash.grant(acct, "money", "r1", NOW, Account.MAX)
expect(not again and why == "dup", "같은 결제 번호는 두 번 주지 않는다")
eq(acct.bm.box[1].n, 1, "보관함의 수는 그대로")

-- ③ 주머니 · 상자는 한 주 제한 없이 산다(2026-10-22 사용자 "달빛상점에서 달가루 상자, 달돈주머니 구매 제한 푼다" — 전에는 한 주에 3번)
Cash.grant(acct, "money", "r2", NOW, Account.MAX)
Cash.grant(acct, "money", "r3", NOW, Account.MAX)
local can = Cash.canBuy(acct, "money", NOW, 0, Account.MAX)
expect(can, "세 번 산 주에도 또 산다")
can = Cash.canBuy(acct, "money", NOW, 5, Account.MAX)
expect(can, "구매 창이 여럿 떠 있어도 막지 않는다")
expect(Cash.canBuy(acct, "dust", NOW, 9, Account.MAX), "달가루 상자도 제한 없이")
expect(Cash.product("money").limit == false and Cash.product("dust").limit == false, "주머니 · 상자에는 횟수 제한이 없다")
-- (주 번호의 셈은 남아 있다 — 다시 제한을 두는 상품을 위해)
eq(Cash.weekOf(NOW + 7 * 86400) - Cash.weekOf(NOW), 1, "주 번호가 하나 오른다")
-- 한국 시각 월요일 0시에 바뀐다: 일요일 23:59(한국) → 월요일 0:00(한국)
local mon = 4 * 86400 - 9 * 3600 + 52 * 7 * 86400 -- 어느 월요일 0시(한국)
eq(Cash.weekOf(mon) - Cash.weekOf(mon - 60), 1, "한국 시각 월요일 0시에 새 주")
eq(Cash.weekOf(mon + 6 * 86400) - Cash.weekOf(mon), 0, "그 주의 일요일까지 같은 주")
-- 계정에 한 번(첫걸음 묶음)
expect(Cash.grant(acct, "starter", "s1", NOW, Account.MAX), "첫걸음 묶음")
expect(not Cash.canBuy(acct, "starter", NOW, 0, Account.MAX), "첫걸음 묶음은 계정에 한 번")
-- 준비 중(번호 · 그림이 없는 것)은 주지 않는다
expect(not Cash.grant(acct, "mount", "m1", NOW, Account.MAX), "탈것은 아직 준비 중(그림)")

-- ④ 보관함 → 가방
local h2 = Hero.unpack(1, acct.chars[1].hero)
local before = Bag.count(h2, "bm_money_30")
local moved, left = Cash.take(h2, acct.bm)
expect(moved >= 4, "보관함을 모두 받는다(주머니 3 + 묶음)")
eq(left, 0, "보관함이 비었다")
eq(Bag.count(h2, "bm_money_30") - before, 4, "주머니 넷(산 셋 + 묶음 하나)")
eq(Bag.count(h2, "bm_bagx"), 1, "묶음의 가방 확장권")
-- 가방이 가득 차면 남는다
Cash.grant(acct, "exp", "e1", NOW, Account.MAX)
local full = Hero.unpack(1, acct.chars[1].hero)
for i = 1, Bag.size(full) do
	full.use[i] = { item = "potion1", n = 200 }
end
moved, left = Cash.take(full, acct.bm)
eq(moved, 0, "가방에 자리가 없으면 옮기지 않는다")
eq(left, 1, "보관함에 그대로 남는다")

-- ⑤ 쓰기
local money0 = h2.money
local def = Items.goods("bm_money_30")
expect(Cash.use(h2, acct, def), "달돈 주머니를 쓴다")
eq(h2.money - money0, def.amount, "든 만큼 달돈이 는다")
local dust0 = h2.dust
expect(Cash.use(h2, acct, Items.goods("bm_dust_60")), "달가루 상자")
eq(h2.dust - dust0, Items.goods("bm_dust_60").amount, "든 만큼 달가루가 는다")
local size0 = Bag.size(h2)
expect(Cash.use(h2, acct, Items.goods("bm_bagx")), "가방 확장권")
eq(Bag.size(h2) - size0, 4, "세 탭이 함께 4칸")
eq(#h2.gear, Bag.size(h2), "장비 탭도 칸이 늘었다")
for _ = 2, Cash.RULES.bagSteps do
	Cash.use(h2, acct, Items.goods("bm_bagx"))
end
local more, whyBag = Cash.use(h2, acct, Items.goods("bm_bagx"))
expect(not more and string.find(whyBag, "더 늘릴 수 없다"), "가방 확장권은 넷까지")
local store0 = Account.storeExtra(acct)
expect(Cash.use(h2, acct, Items.goods("bm_storex")), "창고 확장권")
eq(Account.storeExtra(acct) - store0, Cash.RULES.storeStep, "창고가 한 장의 칸만큼")
-- 경험치 쿠폰
eq(Cash.expMul(h2), 1, "쿠폰 없이는 1배")
local xp0 = Hero.killXp(h2, 37, 1)
expect(Cash.use(h2, acct, Items.goods("bm_exp")), "경험치 쿠폰")
eq(h2.expLeft, Cash.RULES.exp.add, "30분")
local xp1 = Hero.killXp(h2, 37, 1)
expect(math.abs(xp1 - xp0 * Cash.RULES.exp.mul) <= 1, ("사냥 경험치 1.5배(%d → %d)"):format(xp0, xp1))
Hero.tick(h2, 60)
eq(h2.expLeft, Cash.RULES.exp.add - 60, "게임 안에 있는 동안 줄어든다")
for _ = 1, 5 do
	Cash.use(h2, acct, Items.goods("bm_exp"))
end
local over = Cash.use(h2, acct, Items.goods("bm_exp"))
expect(not over, "3시간을 넘게 쌓지 않는다")
expect(h2.expLeft <= Cash.RULES.exp.cap, "3시간 안")
-- 드롭률 쿠폰(2026-10-27 사용자: "달빛상점에 경험치 쿠폰같이 드롭률 쿠폰도똑같이 살수있게 만들자") — 경험치 쿠폰과 같은 꼴 · 드롭률 패스와 더한다
eq(Cash.dropMul(h2), 1, "드롭률 쿠폰 없이는 1배")
expect(Cash.use(h2, acct, Items.goods("bm_drop")), "드롭률 쿠폰")
eq(h2.dropLeft, Cash.RULES.drop.add, "드롭률 쿠폰 30분")
eq(Cash.dropMul(h2), Cash.RULES.drop.mul, "드롭률 1.5배")
h2.passDrop = 0.25
eq(Cash.dropMul(h2), Cash.RULES.drop.mul + 0.25, "드롭률 패스와 함께면 더해서 1.75배")
h2.passDrop = nil
Hero.tick(h2, 60)
eq(h2.dropLeft, Cash.RULES.drop.add - 60, "드롭률 쿠폰도 게임 안에 있는 동안 줄어든다")
for _ = 1, 5 do
	Cash.use(h2, acct, Items.goods("bm_drop"))
end
expect(not Cash.use(h2, acct, Items.goods("bm_drop")), "드롭률 쿠폰도 3시간을 넘게 쌓지 않는다")
local dropProduct = nil
for _, pr in req("ReplicatedStorage/shared/lune/data/bm.generated").products do
	if pr.id == "drop" then
		dropProduct = pr
	end
end
expect(dropProduct ~= nil and dropProduct.robux == 49 and dropProduct.trade == true and dropProduct.built == true, "달빛 상점에 드롭률 쿠폰(49 로벅스 · 거래됨)")
expect(dropProduct ~= nil and dropProduct.rid == 3722962958 and Cash.byRid(3722962958) == "drop", "대시보드의 상품 번호(3722962958 — 사용자 10-27) → 드롭률 쿠폰")
do -- 사면(결제 처리) 보관함에 드롭률 쿠폰 한 장
	local a2 = Account.new()
	expect(Cash.grant(a2, "drop", "rDrop1", NOW, Account.MAX), "드롭률 쿠폰을 산다")
	local n = 0
	for _, e in a2.bm.box do
		if e.id == "bm_drop" then
			n += e.n
		end
	end
	eq(n, 1, "보관함에 드롭률 쿠폰 한 장(받기 → 가방 → 쓰기는 경험치 쿠폰과 같다)")
end
do -- 경매장에 올릴 수 있다(2026-10-30 사용자: "드롭률 쿠폰이랑 경험치쿠폰 로벅스로 사는거 경매장에 올릴수 있게해줘"): 사면 보관함 → 받기로 가방 → 경매장의 「판매」 목록
	local Market = req("ReplicatedStorage/shared/lune/sim/market")
	local View = req("ReplicatedStorage/shared/lune/ui/auctionView")
	local a3 = Account.new()
	local h3 = Hero.new(3, "riven")
	expect(Cash.grant(a3, "exp", "rExp9", NOW, Account.MAX) and Cash.grant(a3, "drop", "rDrop9", NOW, Account.MAX), "경험치 · 드롭률 쿠폰을 산다")
	local moved = Cash.take(h3, a3.bm)
	eq(moved, 2, "보관함 → 가방(둘)")
	local bagView = Bag.view(h3)
	for _, id in { "bm_exp", "bm_drop" } do
		local listed = false
		for _, e in View.sellables(bagView) do
			if e.it.item == id then
				listed = Market.sellable(e.it) == true
			end
		end
		expect(listed, Items.goods(id).name .. ": 경매장 「판매」 목록에 든다(올릴 수 있다)")
	end
end
-- 달가루 상자 = 한 시간 반치(2026-10-27 사용자 "로벅스로 구매하는 달가루의 효율이 조금더 좋게")
eq(req("ReplicatedStorage/shared/lune/data/bm.generated").rules.dustHours, 1.5, "달가루 상자 = 가장 높은 캐릭터의 한 시간 반 사냥치")
local box50 = Items.goods("bm_dust_50")
eq(box50 and box50.amount, 2970, "Lv.50 달가루 상자 2,970(한 시간치 1,980의 1.5배)")

-- ⑥ 저장(JSON을 거쳐)
acct.chars[1].hero = Hero.pack(h2)
local back = Account.unpack(json(Account.pack(acct)))
expect(back, "계정을 다시 읽는다")
eq(back.bm.store, acct.bm.store, "창고 확장")
eq(#back.bm.rec, #acct.bm.rec, "처리한 결제 번호")
eq(back.bm.wc.money, nil, "제한 없는 상품은 주간 수를 세지 않는다")
eq(back.bm.once.starter, 1, "계정에 한 번")
eq(#back.bm.box, 1, "보관함(쿠폰 하나)")
local hb = Hero.unpack(1, back.chars[1].hero)
eq(hb.bagPaid, h2.bagPaid, "가방 확장")
eq(Bag.size(hb), Bag.size(h2), "가방 칸 수")
eq(hb.expLeft, h2.expLeft, "쿠폰 남은 시간")
eq(hb.dropLeft, h2.dropLeft, "드롭률 쿠폰 남은 시간도 저장된다")
-- 이상한 저장은 버린다
local bad = Cash.unpack({ box = { { id = "없는것", n = 1 }, { id = "bm_exp", n = -3 } }, slots = 99, store = 99, wc = { money = "x" } }, Account.MAX)
eq(#bad.box, 0, "없는 아이템 · 이상한 수는 버린다")
eq(bad.slots, 0, "캐릭터 칸이 너무 크면 0")
eq(bad.store, 0, "창고 확장이 너무 크면 0")

-- ⑦ 사서 늘린 캐릭터 칸: 일곱 번째 캐릭터가 「읽지 못한 것」으로 빠지지 않는다
local big = Account.new()
for i = 1, Account.MAX do
	Account.add(big, "c" .. i, "riven", Hero.pack(Hero.new(i, "riven")), NOW)
end
expect(Account.full(big), "처음 칸이 다 찼다")
expect(Cash.grant(big, "charx", "c1", NOW, Account.MAX), "캐릭터 칸 +1")
expect(not Account.full(big), "한 칸 더")
Account.add(big, "c7", "mooni", Hero.pack(Hero.new(7, "mooni")), NOW)
local big2 = Account.unpack(json(Account.pack(big)))
eq(#big2.chars, Account.MAX + 1, "다시 읽어도 일곱 캐릭터")
eq(#big2.broken, 0, "빠진 캐릭터가 없다")
eq(Account.view(big2).max, Account.MAX + 1, "고르기 화면의 칸 수")
local capped = Account.new()
for i = 1, Cash.RULES.charCap - Account.MAX do
	Cash.grant(capped, "charx", "k" .. i, NOW, Account.MAX)
end
local cc, whyChar = Cash.canBuy(capped, "charx", NOW, 0, Account.MAX)
expect(not cc and string.find(whyChar, "캐릭터 칸"), "캐릭터 칸은 12까지")

-- ⑧ 서버의 결제 처리(가짜 세계)
local CashServer = req("ServerScriptService/server/lune/modules/cash")
local saveOk, saves, told = true, 0, {}
local sess = { player = { UserId = 77 }, acct = Account.new(), loaded = true }
Account.add(sess.acct, "결제", "salamander", Hero.pack(Hero.new(1, "salamander")), NOW)
CashServer.start({
	sessionOf = function(uid)
		return if uid == 77 then sess else nil
	end,
	saveNow = function()
		saves += 1
		return saveOk
	end,
	afterSpent = function() end,
	notify = function(_, key)
		table.insert(told, key)
	end,
	now = function()
		return NOW
	end,
})
local GRANTED, LATER = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
eq(CashServer.processReceipt({ PlayerId = 77, PurchaseId = "p1", CurrencySpent = 49 }, "dust"), GRANTED, "산 것을 주고 저장 → 줬다")
eq(sess.acct.bm.box[1].id, "bm_dust_1", "보관함에 달가루 상자")
eq(sess.acct.spent, 49, "쓴 로벅스(후원 판)")
eq(told[1], "dust", "화면에 알린다")
eq(CashServer.processReceipt({ PlayerId = 77, PurchaseId = "p1", CurrencySpent = 49 }, "dust"), GRANTED, "같은 결제가 다시 오면 → 줬다(두 번 주지 않음)")
eq(sess.acct.bm.box[1].n, 1, "상자는 하나 그대로")
eq(sess.acct.spent, 49, "쓴 로벅스도 그대로")
saveOk = false
eq(CashServer.processReceipt({ PlayerId = 77, PurchaseId = "p2", CurrencySpent = 49 }, "dust"), LATER, "저장에 실패하면 → 아직(로블록스가 다시 보낸다)")
eq(sess.acct.bm.box[1].n, 1, "준 것을 되돌렸다")
eq(sess.acct.spent, 49, "쓴 로벅스도 되돌렸다")
eq(Cash.bought(sess.acct.bm, "dust", NOW), 0, "제한 없는 상품은 주간 수를 세지 않는다")
saveOk = true
eq(CashServer.processReceipt({ PlayerId = 77, PurchaseId = "p2", CurrencySpent = 49 }, "dust"), GRANTED, "다시 오면 이번에는 준다")
eq(sess.acct.bm.box[1].n, 2, "상자 둘")
eq(CashServer.processReceipt({ PlayerId = 99, PurchaseId = "p3", CurrencySpent = 49 }, "dust"), LATER, "이 서버에 없는 사람 → 아직")
sess.loaded = false
eq(CashServer.processReceipt({ PlayerId = 77, PurchaseId = "p4", CurrencySpent = 49 }, "dust"), LATER, "계정을 다 읽기 전 → 아직")
sess.loaded = true
eq(CashServer.processReceipt({ PlayerId = 77, ProductId = 123456789, PurchaseId = "p5" }), LATER, "모르는 상품 번호 → 아직(주지 않는다)")
local okP, whyP = CashServer.prompt(sess, "tele")
expect(not okP and whyP == "판매 준비 중", "번호가 없거나 게임에 아직 없는 상품(순간이동의 돌)은 구매 창을 띄우지 않는다")
local _, whyM = CashServer.prompt(sess, "money")
expect(whyM ~= "판매 준비 중", "대시보드 번호가 있고 만들어 둔 상품(달돈 주머니)은 한도를 보는 데까지 간다 — " .. tostring(whyM))
local priced = Cash.view(sess.acct, NOW, nil, nil, { money = 77 })
local moneyRow
for _, v in priced.list do
	if v.id == "money" then
		moneyRow = v
	end
end
eq(moneyRow.robux, 77, "화면의 값 = 로블록스에서 읽은 실제 값")
eq(Cash.view(sess.acct, NOW).list[1].robux, BM.products[1].robux, "못 읽었으면 설계의 값")

-- ⑨ 달빛 패스(2026-10-20 — 사용자: "달빛패스에 자동줍기는 아니에요" · "달빛 패스도 개발자 상품에 등록해야해요" · "달빛패스에 시즌이라는 개념이 필요가 없잖아")
--  산 때부터 30일 · 그동안만 달빛이 쌓인다 · 하루 상한 · 칸마다 보상 · 경매장 칸 · 끝난 뒤에 다시 산다(받지 않은 칸은 먼저 보관함) · 저장
local Pass = req("ReplicatedStorage/shared/lune/sim/pass")
local PD = Pass.DATA
local T0 = 1792411200 -- 2026-10-19 03:00 (세계 표준시) = 한국 12:00
local pacct = Account.new()
Account.add(pacct, "패스", "riven", Hero.pack(Hero.new(1, "riven")), T0)
local ps = pacct.bm.pass
eq(Cash.passAdd(pacct, "daily", T0), 0, "패스가 없으면 달빛이 쌓이지 않는다")
expect(not Pass.active(ps, T0) and Cash.marketPlus(pacct, T0) == 0, "패스가 없으면 경매장 칸 그대로")
expect(Cash.canBuy(pacct, "pass", T0, 0, Account.MAX), "처음에는 살 수 있다")
expect(Cash.grant(pacct, "pass", "pass-1", T0, Account.MAX), "패스를 샀다(개발자 상품 — 결제 하나)")
expect(Pass.active(ps, T0), "산 때부터")
eq(Pass.left(ps, T0), PD.days, "30일 남음")
eq(Pass.left(ps, T0 + 29 * 86400 + 1), 1, "마지막 날 = 1일")
expect(not Pass.active(ps, T0 + PD.days * 86400), "30일 뒤에 끝난다")
eq(Cash.marketPlus(pacct, T0), PD.auctionPlus, "경매장 칸 +5")
local can, whyPass = Cash.canBuy(pacct, "pass", T0, 0, Account.MAX)
expect(not can and string.find(whyPass, "30일 남았다", 1, true) ~= nil, "패스가 있는 동안은 다시 못 산다 — " .. tostring(whyPass))
eq(Cash.passAdd(pacct, "daily", T0), PD.gain.daily, "일일 의뢰 하나 = 달빛 3")
eq(Cash.passAdd(pacct, "attend", T0), PD.gain.attend, "출석 = 2")
eq(Cash.passAdd(pacct, "rift", T0), PD.gain.rift, "토벌 = 3")
eq(Cash.passAdd(pacct, "kill", T0, PD.killEach - 1), 0, "99마리는 아직")
eq(Cash.passAdd(pacct, "kill", T0, 1), PD.gain.kill, "100마리째 = 2")
eq(Cash.passAdd(pacct, "daily", T0), PD.dayCap - 10, "하루 상한 12까지만")
eq(Cash.passAdd(pacct, "daily", T0), 0, "오늘은 더 없다")
eq(Cash.passAdd(pacct, "daily", T0 + 86400), PD.gain.daily, "다음 날(한국 0시가 지나) 다시")
for d = 2, 9 do
	Cash.passAdd(pacct, "daily", T0 + d * 86400)
	Cash.passAdd(pacct, "daily", T0 + d * 86400)
	Cash.passAdd(pacct, "rift", T0 + d * 86400)
	Cash.passAdd(pacct, "attend", T0 + d * 86400)
end
local T9 = T0 + 9 * 86400
eq(ps.pts, 15 + 8 * 11, "여드레 더 = 하루 11")
eq(Pass.reached(ps), 10, "10칸")
eq(#Pass.ready(ps), 10, "연 10칸을 받을 수 있다")
eq(Cash.passClaim(pacct, T9, 1, 1), 10, "10칸의 보상을 보관함에")
eq(#Pass.ready(ps), 0, "다시 받을 것은 없다")
local hasPotion, hasMoney = false, false
for _, e in pacct.bm.box do
	if e.id == "potion1" then
		hasPotion = true
	elseif e.id == "bm_money_1" then
		hasMoney = true
	end
end
expect(hasPotion, "물약 = 받는 캐릭터의 레벨(1)의 물약")
expect(hasMoney, "10칸의 달돈 주머니 = 레벨대 1")
for d = 10, 12 do
	Cash.passAdd(pacct, "daily", T0 + d * 86400)
	Cash.passAdd(pacct, "daily", T0 + d * 86400)
	Cash.passAdd(pacct, "rift", T0 + d * 86400)
	Cash.passAdd(pacct, "attend", T0 + d * 86400)
end
eq(Pass.reached(ps), 13, "13칸(11 · 12 · 13은 아직 안 받음)")
-- 저장(JSON을 거쳐)
local savedPass = Cash.unpack(json(Cash.pack(pacct.bm)), Account.MAX)
eq(savedPass.pass.pts, ps.pts, "달빛을 저장")
eq(savedPass.pass.ends, ps.ends, "끝나는 때를 저장")
expect(savedPass.pass.p[10] and not savedPass.pass.p[11], "받은 칸을 저장")
-- 30일이 지난 뒤
local TEND = T0 + PD.days * 86400 + 60
eq(Cash.passAdd(pacct, "daily", TEND), 0, "끝난 뒤에는 달빛이 쌓이지 않는다")
eq(Cash.marketPlus(pacct, TEND), 0, "끝난 뒤에는 경매장 칸 그대로")
eq(Pass.view(ps, TEND).ended, true, "화면: 끝났다")
eq(#Pass.ready(ps), 3, "끝난 뒤에도 연 칸(11~13)은 받을 수 있다")
local function boxItems()
	local n = 0
	for _, e in pacct.bm.box do
		n += e.n
	end
	return n
end
local boxN = boxItems()
expect(Cash.canBuy(pacct, "pass", TEND, 0, Account.MAX), "끝난 뒤에는 다시 살 수 있다")
expect(Cash.grant(pacct, "pass", "pass-2", TEND, Account.MAX), "다시 샀다")
eq(boxItems() - boxN, PD.paid[11][2] + PD.paid[12][2] + PD.paid[13][2], "받지 않은 11~13칸은 먼저 보관함에(물약 10 · 경험치 쿠폰 1 · 귀환 주문서 2)")
eq(ps.pts, 0, "새 30일 = 달빛 0")
eq(#Pass.ready(ps), 0, "새 패스의 칸은 아직 닫혀 있다")
eq(Pass.left(ps, TEND), PD.days, "새 30일")
-- 패스가 있는데 결제가 또 왔다(구매 창을 띄운 뒤 다른 곳에서 산 경우) — 받은 돈은 반드시: 끝나는 때만 30일 늘린다
local ends = ps.ends
expect(Cash.grant(pacct, "pass", "pass-3", TEND + 10, Account.MAX), "겹친 결제도 준다")
eq(ps.ends, ends + PD.days * 86400, "끝나는 때 +30일")
eq(Pass.unpack({ pts = -5, p = { 99, "x", 3 }, ends = "a" }).pts, 0, "이상한 값은 버린다")

-- ⑩ 펫 · 탈것(2026-10-20 — 사용자: "펫은 종류 다르게 별도상품으로 … 같은기능을가진 별도의 펫으로 판매" · "탈것은 사다리에서 감추기 좋습니다")
local racct = Account.new()
Account.add(racct, "펫주인", "mooni", Hero.pack(Hero.new(1, "mooni")), T0)
expect(Cash.grant(racct, "pet_lantern", "pet-1", T0, Account.MAX), "펫을 샀다")
expect(racct.bm.pets.pet_lantern, "계정에 들어왔다")
eq(racct.bm.petOut, "pet_lantern", "꺼내 둔 것이 없었으면 바로 꺼낸다")
expect(Cash.grant(racct, "pet_silver", "pet-2", T0, Account.MAX), "다른 펫도 따로 산다")
eq(racct.bm.petOut, "pet_lantern", "둘째는 꺼내 둔 것을 바꾸지 않는다")
local cp, whyPet = Cash.canBuy(racct, "pet_silver", T0, 0, Account.MAX)
expect(not cp, "같은 펫은 한 번 — " .. tostring(whyPet))
expect(Cash.setPet(racct, "pet_silver"), "꺼낼 펫을 바꾼다")
eq(racct.bm.petOut, "pet_silver", "은빛 달토끼")
expect(not Cash.setPet(racct, "pet_scarf"), "가지지 않은 펫은 꺼낼 수 없다")
expect(Cash.setPet(racct, false) and racct.bm.petOut == false, "넣는다")
expect(Cash.grant(racct, "mount_deer", "mount-1", T0, Account.MAX), "탈것을 샀다")
eq(racct.bm.mount, "mount_deer", "고른 탈것")
expect(not Cash.setMount(racct, "mount_wolf"), "가지지 않은 탈것은 고를 수 없다")
local rv = Cash.view(racct, T0)
local ownCount = 0
for _, v in rv.list do
	if v.own then
		ownCount += 1
	end
end
eq(ownCount, 3, "화면: 가진 것 셋(펫 둘 · 탈것 하나)")
eq(#rv.pets, 2, "화면: 가진 펫")
local rsaved = Cash.unpack(json(Cash.pack(racct.bm)), Account.MAX)
expect(rsaved.pets.pet_lantern and rsaved.pets.pet_silver and rsaved.mounts.mount_deer, "가진 펫 · 탈것을 저장")
eq(rsaved.mount, "mount_deer", "고른 탈것을 저장")
eq(Cash.unpack({ pets = { "pet_x", 3 }, petOut = "pet_silver" }, Account.MAX).petOut, false, "없는 펫 · 가지지 않은 펫은 버린다")
