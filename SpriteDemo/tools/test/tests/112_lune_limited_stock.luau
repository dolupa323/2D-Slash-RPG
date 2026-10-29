-- 「달의 계승자」 — 한정 판매(2026-10-29 사용자: "거인 라이딩 황금으로 해서 한정 20개 판매로 해서 판매하고 다팔리면 안파는식으로").
--  server/lune/modules/store.luau의 stock_<상품>(세계 기록 — 모든 서버가 같이 본다) · server/lune/modules/cash.luau의 prompt · processReceipt.
--  보는 것: 구매 창을 띄우기 전에 한 개를 잡는다 · 잡은 것까지 20이면 다음 사람은 창을 띄우지 않는다 · 결제가 오면 판 수가 오른다 · 같은 결제가 다시 와도 두 번 세지 않는다 ·
--   저장에 실패하면 판 수를 되돌린다 · 20개를 다 팔면 「품절」 · 사지 않고 닫으면 놓는다 · 잡아 둔 시간이 지나면 풀린다
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
local KEY = "mount_golem_gold"
local P = Cash.product(KEY)
expect(P ~= nil and P.stock == 20, "황금 골렘은 20개 한정")
eq(P.kind, "product", "개발자 상품")
expect(P.limit and P.limit.n == 1, "계정에 하나")

-- ① 저장소의 셈
local T0 = 1000000
expect(Store.stockHold(KEY, 1, 2, T0, 600) == true, "잡는다(1)")
expect(Store.stockHold(KEY, 2, 2, T0, 600) == true, "잡는다(2)")
expect(Store.stockHold(KEY, 3, 2, T0, 600) == false, "판 수 + 잡은 수가 다 찼으면 잡지 못한다")
expect(Store.stockHold(KEY, 1, 2, T0 + 10, 600) == true, "이미 잡은 사람은 다시 잡는다(시간만 늘린다)")
Store.stockRelease(KEY, 2, T0)
expect(Store.stockHold(KEY, 3, 2, T0, 600) == true, "놓으면 다른 사람이 잡는다")
local okT, rec = Store.stockTake(KEY, 1, 2, T0 + 20)
expect(okT and rec.sold == 1 and rec.holds["1"] == nil, "결제 → 판 수 1 · 잡은 것은 풀린다")
local _, later = Store.stockGet(KEY, T0 + 2000)
expect(later and next(later.holds) == nil, "잡아 둔 시간이 지나면 저절로 풀린다")
eq(later and later.sold, 1, "판 수는 그대로")
Store.stockUntake(KEY, 1, T0 + 30, 600)
local _, back = Store.stockGet(KEY, T0 + 30)
expect(back.sold == 0 and back.holds["1"] ~= nil, "되돌리면 판 수가 줄고 그 사람이 다시 잡은 것으로")
data["stock_" .. KEY] = nil

-- ② 결제의 흐름(가짜 세계 — 21명)
local CashServer = req("ServerScriptService/server/lune/modules/cash")
P.rid = 990001 -- (대시보드 번호가 들어간 뒤의 모습)
local NOW = T0
CashServer.clock = function()
	return NOW
end
local sessions, saveOk = {}, true
for uid = 101, 121 do
	local acct = Account.new()
	Account.add(acct, "골렘" .. uid, "axion", Hero.pack(Hero.new(uid, "axion")), NOW)
	sessions[uid] = { player = { UserId = uid }, acct = acct, loaded = true }
end
CashServer.start({
	sessionOf = function(uid)
		return sessions[uid]
	end,
	saveNow = function()
		return saveOk
	end,
	afterSpent = function() end,
	notify = function() end,
	now = function()
		return NOW
	end,
})
local GRANTED, LATER = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
for uid = 101, 120 do
	local ok, why = CashServer.prompt(sessions[uid], KEY)
	expect(ok, ("%d번째 사람은 구매 창을 띄운다 %s"):format(uid - 100, tostring(why)))
end
eq(#prompts, 20, "구매 창 스물")
local ok21, why21 = CashServer.prompt(sessions[121], KEY)
expect(not ok21 and why21 ~= Cash.WORDS.soldOut and why21 ~= nil, "스물이 결제하는 중이면 스물한 번째는 창을 띄우지 않는다(아직 품절은 아니다) — " .. tostring(why21))
eq(#prompts, 20, "창은 그대로 스물")
-- 결제가 온다
for uid = 101, 119 do
	eq(CashServer.processReceipt({ PlayerId = uid, PurchaseId = "r" .. uid, CurrencySpent = 999 }, KEY), GRANTED, "결제 → 준다 " .. uid)
	expect(sessions[uid].acct.bm.mounts[KEY] == true, "계정에 황금 골렘 " .. uid)
end
eq(CashServer.stocks()[KEY], 1, "남은 수 1(판 것만 뺀다)")
eq(CashServer.processReceipt({ PlayerId = 101, PurchaseId = "r101", CurrencySpent = 999 }, KEY), GRANTED, "같은 결제가 다시 오면 줬다고만 한다")
local _, r1 = Store.stockGet(KEY, NOW)
eq(r1.sold, 19, "같은 결제를 두 번 세지 않는다")
-- 마지막 하나: 저장에 실패하면 판 수를 되돌린다 → 다시 오면 판다
saveOk = false
eq(CashServer.processReceipt({ PlayerId = 120, PurchaseId = "r120", CurrencySpent = 999 }, KEY), LATER, "저장 실패 → 아직")
local _, r2 = Store.stockGet(KEY, NOW)
eq(r2.sold, 19, "판 수를 되돌렸다")
expect(r2.holds["120"] ~= nil, "그 사람이 잡은 것으로 남는다(다른 사람이 가져가지 못한다)")
saveOk = true
eq(CashServer.processReceipt({ PlayerId = 120, PurchaseId = "r120", CurrencySpent = 999 }, KEY), GRANTED, "다시 오면 준다")
local _, r3 = Store.stockGet(KEY, NOW)
eq(r3.sold, 20, "스물 다 팔렸다")
eq(CashServer.stocks()[KEY], 0, "남은 수 0")
-- 다 팔렸다: 품절 · 창을 띄우지 않는다
NOW += 3600
local okSold, whySold = CashServer.prompt(sessions[121], KEY)
expect(not okSold and whySold == Cash.WORDS.soldOut, "다 팔리면 「품절」 — " .. tostring(whySold))
eq(#prompts, 20, "창을 더 띄우지 않는다")
-- 이미 산 사람은 계정에 하나(창을 띄우지 않는다)
local okAgain = CashServer.prompt(sessions[101], KEY)
expect(not okAgain, "이미 산 계정은 다시 사지 못한다")
-- 상점 화면에 보내는 남은 수
local v = Cash.view(sessions[121].acct, NOW, nil, nil, nil, CashServer.stocks())
local row
for _, e in v.list do
	if e.id == KEY then
		row = e
	end
end
eq(row and row.left, 0, "상점 줄의 남은 수 0")
-- 서버가 새로 켜져도(다른 서버) 같은 기록을 읽는다
CashServer.readStocks()
eq(CashServer.stocks()[KEY], 0, "다시 읽어도 0")
CashServer.clock = os.time
