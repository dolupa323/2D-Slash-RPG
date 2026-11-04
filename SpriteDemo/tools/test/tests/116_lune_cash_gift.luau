-- 「달의 계승자」 — 달빛 상점의 선물하기(2026-10-31 사용자: "달빛상점에 모든 품목을 아이템 선물을 할수있게 해줘 다른사람에게 선물을 보낼수있게").
--  server/lune/modules/cash.luau의 CashServer.gift · processReceipt · giftTick · store.luau의 bmgift_<계정>.
--  보는 것: 선물할 수 있는 상품(개발자 상품만 — 영구 패스는 아니다) · 나에게는 못 · 없는 닉네임 · 로블록스 정책(보내는 쪽 · 받는 쪽) · 받는 사람의 한도(아직 받지 않은 선물까지 센다) ·
--   결제가 오면 받는 계정의 상자에 · 산 사람에게는 주지 않고 결제 번호만 · 같은 결제가 다시 와도 한 번 · 저장에 실패하면 되돌린다 ·
--   받는 사람이 이 서버에 있으면 바로 · 접속하지 않았으면 들어올 때 · 받는 쪽 저장에 실패하면 상자에 남는다 · 선물 상자가 가득 차면 더 보내지 못한다
local data = {}
local fake = {
	GetAsync = function(_, key)
		return data[key]
	end,
	SetAsync = function(_, key, value)
		data[key] = value
	end,
	UpdateAsync = function(_, key, fn)
		local value = fn(data[key])
		if value ~= nil then
			data[key] = value
		end
	end,
}
SERVICE("DataStoreService", {
	GetDataStore = function()
		return fake
	end,
	GetOrderedDataStore = function()
		return fake
	end,
})
local prompts = {}
SERVICE("MarketplaceService", {
	PromptProductPurchase = function(_, player, rid)
		table.insert(prompts, { player.UserId, rid })
	end,
})
local Store = req("ServerScriptService/server/lune/modules/store")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local CashServer = req("ServerScriptService/server/lune/modules/cash")
local W = Cash.WORDS
local GRANTED, LATER = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
local NOW = 2000000000

-- ① 선물할 수 있는 상품
expect(Cash.giftable("bagx"), "가방 확장권은 선물할 수 있다(개발자 상품)")
expect(not Cash.giftable("xp125"), "경험치 1.25배 패스는 못 한다(게임 패스 — 로블록스가 남에게 사 주지 못하게 한다)")
expect(not Cash.giftable("nope"), "없는 상품은 못 한다")
local PET = nil
for _, p in Cash.PRODUCTS do
	if string.sub(p.id, 1, 4) == "pet_" and p.kind == "product" then
		PET = p.id
		p.rid = if typeof(p.rid) == "number" and p.rid > 0 then p.rid else 990100
		p.built = true
		break
	end
end
expect(PET ~= nil, "상점의 펫이 있다")

-- 가짜 세계: 보내는 사람(201) · 이 서버에 있는 받는 사람(202) · 접속하지 않은 받는 사람(203 — 저장된 계정만)
local function account(uid: number, name: string)
	local acct = Account.new()
	Account.add(acct, name, "axion", Hero.pack(Hero.new(uid, "axion")), NOW)
	data[Account.nameKey(name)] = { u = uid }
	return acct
end
local sessions, saveOk, events = {}, true, {}
sessions[201] = { player = { UserId = 201 }, acct = account(201, "보내는이"), loaded = true, name = "보내는이" }
sessions[202] = { player = { UserId = 202 }, acct = account(202, "받는이"), loaded = true, name = "받는이" }
data["acct_203"] = Account.pack(account(203, "멀리있는이"))
CashServer.start({
	sessionOf = function(uid)
		return sessions[uid]
	end,
	saveNow = function()
		return saveOk
	end,
	afterSpent = function() end,
	notify = function() end,
	giftSent = function(s, key, to)
		table.insert(events, { "sent", s.player.UserId, key, to })
	end,
	giftGot = function(s, key, from)
		table.insert(events, { "got", s.player.UserId, key, from })
	end,
	now = function()
		return NOW
	end,
})
local me, you = sessions[201], sessions[202]
local function count(acct, id)
	for _, e in acct.bm.box do
		if e.id == id then
			return e.n
		end
	end
	return 0
end
local function boxOf(uid)
	local _, list = Store.bmGiftList(uid)
	return list
end

-- ② 보내지 못하는 것
local ok, why = CashServer.gift(me, "bagx", "보내는이")
expect(not ok and why == W.giftSelf, "나에게는 못 보낸다 — " .. tostring(why))
ok, why = CashServer.gift(me, "bagx", "아무도아닌이")
expect(not ok and why == "「아무도아닌이」 닉네임은 없다", "없는 닉네임 — " .. tostring(why))
ok, why = CashServer.gift(me, "bagx", "  ")
expect(not ok and why == W.giftNeedName, "닉네임을 적지 않았다 — " .. tostring(why))
ok, why = CashServer.gift(me, "xp125", "받는이")
expect(not ok and why == W.giftCant, "영구 패스는 선물하지 못한다 — " .. tostring(why))
me.policy = { IsPaidItemTradingAllowed = false }
ok, why = CashServer.gift(me, "bagx", "받는이")
expect(not ok and why == W.giftPolicy, "로블록스 정책으로 유료 아이템을 거래할 수 없는 계정은 보내지 못한다 — " .. tostring(why))
expect(CashServer.giftLocked(me), "상점 창에 미리 알린다(giftLock)")
me.policy = { IsPaidItemTradingAllowed = true }
you.policy = { IsPaidItemTradingAllowed = false }
CashServer.giftTick(you) -- (들어와 있는 동안 1초마다 — 정책을 계정에 적는다)
expect(you.acct.bm.lock == true, "받는 사람의 정책을 계정에 적었다")
ok, why = CashServer.gift(me, "bagx", "받는이")
expect(not ok and why == W.giftPolicyTo, "받는 사람이 막힌 계정이면 보내지 못한다 — " .. tostring(why))
you.policy = { IsPaidItemTradingAllowed = true }
CashServer.giftTick(you)
expect(you.acct.bm.lock == false, "정책이 바뀌면 다시 적는다")
eq(#prompts, 0, "구매 창은 아직 하나도 띄우지 않았다")

-- ③ 이 서버에 있는 사람에게 가방 확장권
ok, why = CashServer.gift(me, "bagx", " 받는이 ")
expect(ok, "선물의 구매 창을 띄운다 — " .. tostring(why))
eq(#prompts, 1, "구매 창 하나")
expect(me.acct.bm.gift and me.acct.bm.gift.uid == 202 and me.acct.bm.gift.to == "받는이", "띄운 선물을 계정에 적었다(앞뒤 빈칸은 뺀다)")
local okBuy, whyBuy = CashServer.prompt(me, "bagx")
expect(not okBuy and whyBuy == W.giftBusy, "선물의 구매 창이 떠 있으면 같은 상품을 나에게 사는 창은 띄우지 않는다 — " .. tostring(whyBuy))
local okOther, whyOther = CashServer.gift(me, "money", "받는이")
expect(not okOther and whyOther == W.giftBusy, "선물의 구매 창이 떠 있으면 다른 선물도 기다린다 — " .. tostring(whyOther))
eq(CashServer.processReceipt({ PlayerId = 201, PurchaseId = "p1", CurrencySpent = 49 }, "bagx"), GRANTED, "결제가 왔다")
eq(count(me.acct, "bm_bagx"), 0, "산 사람의 보관함에는 넣지 않는다")
expect(Cash.granted(me.acct.bm, "p1"), "산 사람의 계정에는 결제 번호만")
eq(me.acct.spent, 49, "쓴 로벅스는 산 사람의 것")
expect(me.acct.bm.gift == false, "띄운 선물을 지웠다")
eq(#boxOf(202), 1, "받는 계정의 선물 상자에 하나")
expect(events[1] and events[1][1] == "sent" and events[1][4] == "받는이", "보낸 사람에게 「보냈다」")
eq(CashServer.processReceipt({ PlayerId = 201, PurchaseId = "p1", CurrencySpent = 49 }, "bagx"), GRANTED, "같은 결제가 다시 와도")
eq(#boxOf(202), 1, "상자에는 한 번만")
CashServer.giftTick(you)
eq(count(you.acct, "bm_bagx"), 1, "받는 사람의 보관함에 가방 확장권")
eq(#boxOf(202), 0, "선물 상자를 비웠다")
local got = events[#events]
expect(got and got[1] == "got" and got[2] == 202 and got[4] == "보내는이", "받는 사람에게 「보내는이님이 보낸 선물」")
CashServer.giftTick(you)
eq(count(you.acct, "bm_bagx"), 1, "두 번 넣지 않는다")

-- ④ 받는 사람의 한도: 계정에 하나인 펫 — 아직 받지 않은 선물도 센다
ok, why = CashServer.gift(me, PET, "받는이")
expect(ok, "펫을 선물한다 — " .. tostring(why))
eq(CashServer.processReceipt({ PlayerId = 201, PurchaseId = "p2", CurrencySpent = 399 }, PET), GRANTED, "펫의 결제")
expect(not me.acct.bm.pets[PET], "산 사람은 펫을 받지 않는다")
ok, why = CashServer.gift(me, PET, "받는이")
expect(not ok and string.find(why or "", "받는 사람이 받을 수 없다", 1, true) ~= nil, "아직 받지 않은 같은 펫이 상자에 있으면 또 보내지 못한다 — " .. tostring(why))
you.bmGiftDone = nil
CashServer.giftTick(you)
expect(you.acct.bm.pets[PET] == true, "받는 사람의 계정에 펫")
ok, why = CashServer.gift(me, PET, "받는이")
expect(not ok and why ~= nil, "이미 가진 펫은 보내지 못한다 — " .. tostring(why))

-- ⑤ 결제를 저장하지 못했다 → 되돌린다 · 다시 오면 보낸다(상자에는 한 번)
ok = CashServer.gift(me, "dust", "받는이")
expect(ok, "달가루 상자를 선물한다")
saveOk = false
eq(CashServer.processReceipt({ PlayerId = 201, PurchaseId = "p3", CurrencySpent = 49 }, "dust"), LATER, "저장 실패 → 아직")
expect(not Cash.granted(me.acct.bm, "p3"), "결제 번호를 되돌렸다")
expect(me.acct.bm.gift and me.acct.bm.gift.k == "dust", "띄운 선물도 되돌렸다(다시 오면 그 사람에게)")
eq(me.acct.spent, 49 + 399, "쓴 로벅스도 되돌렸다")
saveOk = true
eq(CashServer.processReceipt({ PlayerId = 201, PurchaseId = "p3", CurrencySpent = 49 }, "dust"), GRANTED, "다시 오면 보낸다")
eq(#boxOf(202), 1, "상자에는 한 번만")

-- ⑥ 받는 쪽이 저장하지 못했다 → 상자에 남는다 · 다음에 받는다
saveOk = false
you.bmGiftDone = nil
CashServer.giftTick(you)
local dustBand = 0
for _, e in you.acct.bm.box do
	if string.sub(e.id, 1, 8) == "bm_dust_" then
		dustBand += e.n
	end
end
eq(dustBand, 0, "저장하지 못하면 계정의 것을 되돌린다")
eq(#boxOf(202), 1, "선물은 상자에 남는다")
saveOk = true
you.bmGiftNext = 0 -- (30초 뒤 — 여기서는 바로)
CashServer.giftTick(you)
for _, e in you.acct.bm.box do
	if string.sub(e.id, 1, 8) == "bm_dust_" then
		dustBand += e.n
	end
end
eq(dustBand, 1, "다음에 받는다")
eq(#boxOf(202), 0, "상자를 비웠다")

-- ⑦ 접속하지 않은 사람(저장된 계정을 읽어 한도를 본다) → 들어오면 받는다
ok, why = CashServer.gift(me, "money", "멀리있는이")
expect(ok, "접속하지 않은 사람에게도 보낸다 — " .. tostring(why))
eq(CashServer.processReceipt({ PlayerId = 201, PurchaseId = "p4", CurrencySpent = 99 }, "money"), GRANTED, "결제")
eq(#boxOf(203), 1, "그 계정의 상자에")
sessions[203] = { player = { UserId = 203 }, acct = Account.unpack(data["acct_203"]), loaded = true, name = "멀리있는이" }
CashServer.giftTick(sessions[203])
local money = 0
for _, e in sessions[203].acct.bm.box do
	if string.sub(e.id, 1, 9) == "bm_money_" then
		money += e.n
	end
end
eq(money, 1, "들어오면 달돈 주머니가 보관함에")

-- ⑧ 선물 상자가 가득 찼다
for i = 1, Cash.RULES.gift.max do
	Store.bmGiftAdd(202, { k = "bagx", rid = "fill" .. i, from = "x", to = "받는이", at = NOW })
end
ok, why = CashServer.gift(me, "bagx", "받는이")
expect(not ok and why == W.giftBox, "아직 받지 않은 선물이 가득하면 더 보내지 못한다 — " .. tostring(why))
eq(#boxOf(202), Cash.RULES.gift.max, "돈을 낸 것은 버리지 않는다")

-- ⑨ 저장 꼴: 띄운 선물 · 정책
local c = Cash.new()
c.gift, c.lock = { k = "bagx", uid = 7, to = "가", at = NOW }, true
local back = Cash.unpack(Cash.pack(c))
expect(back.gift and back.gift.k == "bagx" and back.gift.uid == 7 and back.gift.to == "가" and back.lock == true, "저장했다가 읽어도 그대로")
expect(Cash.unpack(Cash.pack(Cash.new())).gift == false, "없으면 false")
