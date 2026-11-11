-- 「달의 계승자」 — 한정 판매(2026-10-29 사용자: "거인 라이딩 황금으로 해서 한정 20개 판매로 해서 판매하고 다팔리면 안파는식으로").
--  server/lune/modules/store.luau의 stock_<상품>(세계 기록 — 모든 서버가 같이 본다) · server/lune/modules/cash.luau의 buy(2026-11-11 루나부터 — 전에는 prompt · processReceipt).
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

-- ② 루나로 산다(2026-11-11 루나부터 — 가짜 세계 21명 · server/lune/modules/cash.luau CashServer.buy · 로블록스의 구매 창은 뜨지 않는다)
--  하나를 잡고 → 주고 → 판 것으로 적고 → 저장. 저장에 실패하면 판 수 · 루나 · 계정을 모두 되돌린다 · 20개를 다 팔면 「품절」 · 루나가 모자라면 잡지도 않는다
local CashServer = req("ServerScriptService/server/lune/modules/cash")
local NOW = T0
CashServer.clock = function()
	return NOW
end
local PRICE = Cash.lunaPrice(KEY)
eq(PRICE, P.robux, "루나의 값 = 설계의 로벅스 값(1 로벅스 = 1 루나)")
local sessions, saveOk = {}, true
for uid = 101, 122 do
	local acct = Account.new()
	Account.add(acct, "골렘" .. uid, "axion", Hero.pack(Hero.new(uid, "axion")), NOW)
	acct.bm.luna = if uid == 122 then 10 else 2000
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
for uid = 101, 119 do
	local ok, got = CashServer.buy(sessions[uid], KEY)
	expect(ok == true and got == PRICE, ("%d번째 사람은 루나로 산다 %s"):format(uid - 100, tostring(got)))
	expect(sessions[uid].acct.bm.mounts[KEY] == true and sessions[uid].acct.bm.luna == 2000 - PRICE, "계정에 황금 골렘 · 루나가 값만큼 줄었다 " .. uid)
end
eq(CashServer.stocks()[KEY], 1, "남은 수 1")
local _, r1 = Store.stockGet(KEY, NOW)
eq(r1.sold, 19, "판 수 19")
expect(next(r1.holds) == nil, "잡아 둔 것이 남지 않는다(산 순간 판 것으로)")
-- 루나가 모자라면 잡지도 않는다
local okPoor, whyPoor = CashServer.buy(sessions[122], KEY)
expect(not okPoor and whyPoor == Cash.WORDS.lunaShort, "루나가 모자라다 — " .. tostring(whyPoor))
local _, rPoor = Store.stockGet(KEY, NOW)
expect(next(rPoor.holds) == nil and sessions[122].acct.bm.luna == 10, "잡지 않았다 · 루나 그대로")
-- 마지막 하나: 저장에 실패하면 모두 되돌린다 → 다시 사면 판다
saveOk = false
local okFail, whyFail = CashServer.buy(sessions[120], KEY)
expect(not okFail and typeof(whyFail) == "string", "저장 실패 → 사지 못했다 " .. tostring(whyFail))
expect(sessions[120].acct.bm.luna == 2000 and not sessions[120].acct.bm.mounts[KEY], "루나 · 계정 그대로")
local _, r2 = Store.stockGet(KEY, NOW)
expect(r2.sold == 19 and next(r2.holds) == nil, "판 수를 되돌렸고 잡은 것도 놓았다")
saveOk = true
expect(CashServer.buy(sessions[120], KEY) == true, "다시 사면 판다")
local _, r3 = Store.stockGet(KEY, NOW)
eq(r3.sold, 20, "스물 다 팔렸다")
eq(CashServer.stocks()[KEY], 0, "남은 수 0")
-- 다 팔렸다: 품절(루나 그대로)
NOW += 3600
local okSold, whySold = CashServer.buy(sessions[121], KEY)
expect(not okSold and whySold == Cash.WORDS.soldOut and sessions[121].acct.bm.luna == 2000, "다 팔리면 「품절」 · 루나 그대로 — " .. tostring(whySold))
-- 이미 산 사람은 계정에 하나
local okAgain = CashServer.buy(sessions[101], KEY)
expect(not okAgain and sessions[101].acct.bm.luna == 2000 - PRICE, "이미 산 계정은 다시 사지 못한다")
eq(#prompts, 0, "로블록스의 구매 창은 한 번도 뜨지 않았다(상품은 루나로)")
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
