-- 「달의 계승자」 — 루나(2026-11-11 사용자: "이제 루나도 구현하고 , 지금 로벅스 물품들 모두 루나로 구매하는식으로 만들고 영국 미성년자의 경우만 뽑기제외하면 되는거잖아
--  기존 로벅스로 구매한 아이템들도 루나로 산것과같은 판정으로 바꿔야하고 구현들어가자").
--  sim/cash.luau(chargeLuna · buyLuna · payGift · giveProduct · 저장) · server/lune/modules/cash.luau(processReceipt의 충전 · buy · charge · owns).
--  보는 것: ① 설계(묶음 여섯 · 1 로벅스 = 1 루나 · 그림) ② 충전(같은 결제는 한 번 · 기록) ③ 루나로 사기(모자람 · 한도 · 영구 패스 · 뽑기 · 준비 중 · 기록)
--   ④ 서버의 충전 결제(저장 실패 = 되돌림 · 쓴 로벅스) ⑤ 서버의 사기(뽑기 정책 · 로블록스 패스 · 저장 실패 · 구매 창 없음) ⑥ 충전의 구매 창 ⑦ 예전 로벅스 결제 = 루나로 산 것과 같은 결과 ⑧ 상점 표
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
local prompts, passPrompts = {}, {}
SERVICE("MarketplaceService", {
	PromptProductPurchase = function(_, player, rid)
		table.insert(prompts, { player.UserId, rid })
	end,
	UserOwnsGamePassAsync = function()
		return false
	end,
	PromptGamePassPurchase = function(_, player, rid)
		table.insert(passPrompts, { player.UserId, rid })
	end,
})
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Gacha = req("ReplicatedStorage/shared/lune/sim/gacha")
local CashServer = req("ServerScriptService/server/lune/modules/cash")
local W = Cash.WORDS
local NOW = 2000000000
local GRANTED, LATER = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet

local function newAcct(uid: number)
	local acct = Account.new()
	Account.add(acct, "루나" .. uid, "axion", Hero.pack(Hero.new(uid, "axion")), NOW)
	return acct
end
local function boxN(acct, id)
	for _, e in acct.bm.box do
		if e.id == id then
			return e.n
		end
	end
	return 0
end
local function lastLog(acct)
	return acct.bm.log[#acct.bm.log]
end

-- ① 설계
eq(#Cash.LUNA.packs, 6, "루나 묶음 여섯")
for _, q in Cash.LUNA.packs do
	expect(q.id == "luna_" .. q.n and q.robux == q.n, "1 로벅스 = 1 루나: " .. q.id)
	expect(Cash.lunaPack(q.id) == q, "묶음을 찾는다 " .. q.id)
	expect(Cash.product(q.id) == nil, "루나 묶음은 상점의 상품이 아니다(루나로 루나를 사지 않는다) " .. q.id)
	expect(typeof(q.icon) == "string" and string.sub(q.icon, 1, 7) == "bm_luna", "그림 " .. q.id)
end
eq(Cash.LUNA.name, "루나", "이름")
for _, p in Cash.PRODUCTS do
	eq(Cash.lunaPrice(p.id), p.robux, "루나의 값 = 설계의 로벅스 값 " .. p.id)
end
expect(Cash.ready(Cash.product("exp")) and Cash.ready(Cash.product("exp_x10")), "상품은 로블록스 번호가 없어도 게임에 만들어 둔 것이면 판다(루나로)")
expect(not Cash.ready(Cash.product("tele")), "만들지 않은 것(순간이동의 돌)은 여전히 준비 중")

-- ② 충전
local a = newAcct(1)
eq(a.bm.luna, 0, "처음 루나 0")
local ok, n = Cash.chargeLuna(a, "luna_500", "R1", NOW)
expect(ok and n == 500 and a.bm.luna == 500, "충전 500")
local lg = lastLog(a)
expect(lg.r == "R1" and lg.k == "luna_500" and lg.d == 500 and lg.l == 500, "결제의 기록: +500 · 그 뒤 500")
local dupOk, dupWhy = Cash.chargeLuna(a, "luna_500", "R1", NOW)
expect(not dupOk and dupWhy == "dup" and a.bm.luna == 500, "같은 결제는 한 번만")
expect(not Cash.chargeLuna(a, "luna_7", "R2", NOW) and a.bm.luna == 500, "없는 묶음")
a.bm.luna = Cash.LUNA_MAX - 10
Cash.chargeLuna(a, "luna_100", "R3", NOW)
eq(a.bm.luna, Cash.LUNA_MAX, "가장 많은 루나에서 멈춘다")
a.bm.luna = 500
eq(Cash.addLuna(a, 100, "debug", NOW), 600, "결제가 아닌 길(Studio 확인 · 운영자): 루나를 넣는다")
expect(lastLog(a).k == "debug" and lastLog(a).d == 100 and lastLog(a).l == 600, "기록에 debug +100 · 그 뒤 600")
eq(Cash.addLuna(a, -1000, "debug", NOW), 0, "빼면 0 아래로는 가지 않는다")
expect(lastLog(a).d == -600, "실제로 뺀 수(-600)로 기록")
a.bm.luna = 500

-- ③ 루나로 사기
local rid = Cash.lunaRid(NOW, 1)
local okB, spent = Cash.buyLuna(a, "bagx", NOW, rid, Account.MAX)
expect(okB and spent == 49 and a.bm.luna == 451 and boxN(a, "bm_bagx") == 1, "가방 확장권 — 루나 49")
lg = lastLog(a)
expect(lg.r == rid and lg.k == "bagx" and lg.d == -49 and lg.l == 451, "결제의 기록: -49 · 남은 451")
expect(not Cash.granted(a.bm, rid), "루나로 산 것의 번호는 결제 번호 목록에 넣지 않는다(로블록스 결제 번호를 밀어내지 않게)")
local okShort, whyShort = Cash.buyLuna(a, "exp_x10", NOW, Cash.lunaRid(NOW, 1), Account.MAX)
expect(not okShort and whyShort == W.lunaShort and a.bm.luna == 451 and boxN(a, "bm_exp") == 0, "모자라면 사지 못한다(바꾼 것이 없다)")
local okSoon, whySoon = Cash.buyLuna(a, "dyepoint", NOW, Cash.lunaRid(NOW, 1), Account.MAX)
expect(not okSoon and whySoon == "판매 준비 중" and a.bm.luna == 451, "준비 중인 것(무기 염색약 — 꺼 둔 상품)은 사지 못한다 " .. tostring(whySoon))
local okTele, whyTele = Cash.buyLuna(a, "tele", NOW, Cash.lunaRid(NOW, 1), Account.MAX)
expect(not okTele and whyTele == W.passRobux, "순간이동의 돌(패스)은 루나로 사지 않는다")
-- 한도: 첫걸음 묶음 = 계정에 한 번
expect(Cash.buyLuna(a, "starter", NOW, Cash.lunaRid(NOW, 1), Account.MAX), "첫걸음 묶음")
local okOnce, whyOnce = Cash.buyLuna(a, "starter", NOW, Cash.lunaRid(NOW, 1), Account.MAX)
expect(not okOnce and typeof(whyOnce) == "string" and a.bm.luna == 451 - 99, "계정에 한 번 — 두 번째는 사지 못한다 " .. tostring(whyOnce))
-- 영구 게임 패스는 루나와 따로 — 로벅스로 산다(같은 날 사용자: "패스는 아예 별도입니다 패스는 로벅스로 구매하게하면됩니다")
a.bm.luna = 1000
local okP2, whyP2 = Cash.buyLuna(a, "xp125", NOW, Cash.lunaRid(NOW, 1), Account.MAX)
expect(not okP2 and whyP2 == W.passRobux and a.bm.luna == 1000, "영구 패스는 루나로 사지 않는다 — " .. tostring(whyP2))
expect(not Cash.giftable("xp125") and not Cash.giftable("drop125"), "영구 패스는 선물하지 않는다")
-- 뽑기 상자: 사는 순간 열린다 · 기록에 나온 것
a.bm.luna = 1000
expect(Cash.buyLuna(a, "petbox", NOW, Cash.lunaRid(NOW, 1), Account.MAX), "윤슬 펫 상자를 루나로")
lg = lastLog(a)
expect(lg.k == "petbox" and lg.d == -Cash.lunaPrice("petbox") and typeof(lg.g) == "string" and Gacha.box("petbox") ~= nil, "기록에 나온 것 " .. tostring(lg.g))
expect(Cash.count(a.bm, lg.g) >= 1, "나온 펫이 계정에")
-- 저장했다가 읽어도 루나 · 영구 패스 · 기록의 ± 그대로
local back = Cash.unpack(Cash.pack(a.bm))
expect(back.luna == a.bm.luna, "저장: 루나")
local bl = back.log[#back.log]
expect(bl.d == lg.d and bl.l == lg.l, "저장: 기록의 ± · 남은 루나")
expect(Cash.unpack({ luna = -5 }).luna == 0 and Cash.unpack({ luna = 1.5 }).luna == 0, "이상한 루나는 버린다")

-- ④ 서버: 충전의 결제
local sessions, saveOk, notified = {}, true, {}
CashServer.start({
	sessionOf = function(uid)
		return sessions[uid]
	end,
	saveNow = function()
		return saveOk
	end,
	afterSpent = function() end,
	notify = function(s, key)
		table.insert(notified, key)
	end,
	giftSent = function() end,
	giftGot = function() end,
	now = function()
		return NOW
	end,
})
local function session(uid: number)
	sessions[uid] = { player = { UserId = uid }, acct = newAcct(uid), loaded = true, name = "루나" .. uid, shop = 1 }
	return sessions[uid]
end
local s = session(301)
eq(CashServer.processReceipt({ PlayerId = 301, PurchaseId = "c1", CurrencySpent = 300 }, "luna_300"), GRANTED, "충전의 결제 → 준다")
expect(s.acct.bm.luna == 300 and s.acct.spent == 300 and notified[#notified] == "luna_300", "루나 300 · 쓴 로벅스 300 · 알림")
eq(CashServer.processReceipt({ PlayerId = 301, PurchaseId = "c1", CurrencySpent = 300 }, "luna_300"), GRANTED, "같은 결제가 다시 와도")
expect(s.acct.bm.luna == 300 and s.acct.spent == 300, "두 번 더하지 않는다")
saveOk = false
eq(CashServer.processReceipt({ PlayerId = 301, PurchaseId = "c2", CurrencySpent = 100 }, "luna_100"), LATER, "저장 실패 → 아직")
expect(s.acct.bm.luna == 300 and s.acct.spent == 300 and not Cash.granted(s.acct.bm, "c2"), "루나 · 쓴 로벅스 · 결제 번호 되돌림")
saveOk = true
eq(CashServer.processReceipt({ PlayerId = 301, PurchaseId = "c2", CurrencySpent = 100 }, "luna_100"), GRANTED, "다시 오면 준다")
eq(s.acct.bm.luna, 400, "루나 400")

-- ⑤ 서버: 루나로 사기
local okS, gotS = CashServer.buy(s, "exp")
expect(okS and gotS == 49 and s.acct.bm.luna == 351 and boxN(s.acct, "bm_exp") == 1, "경험치 쿠폰 — 루나 49")
eq(notified[#notified], "exp", "산 것을 알린다(보관함 · 상자 연출 — CashGot)")
eq(#prompts, 0, "로블록스의 구매 창은 뜨지 않는다")
s.policy = { ArePaidRandomItemsRestricted = true }
local okR, whyR = CashServer.buy(s, "petbox")
expect(not okR and whyR == W.randomBlocked and s.acct.bm.luna == 351, "뽑기 제한 계정은 루나로도 뽑기 상자를 사지 못한다 — " .. tostring(whyR))
okR, whyR = CashServer.buy(s, "yunseul")
expect(not okR and whyR == W.randomBlocked, "윤슬 조각도")
s.policy = { ArePaidRandomItemsRestricted = false }
s.passes = { drop125 = true } -- (로블록스에서 산 게임 패스)
local okPass, whyPass = CashServer.buy(s, "xp125")
expect(not okPass and whyPass == W.passRobux and s.acct.bm.luna == 351, "영구 패스는 루나로 사지 않는다(서버)")
-- 영구 패스 = 로블록스의 게임 패스 구매 창(로벅스)
local okPP, whyPP = CashServer.promptPass(s, "xp125")
if Cash.ready(Cash.product("xp125")) then
	expect(okPP and #passPrompts == 1 and passPrompts[1][2] == Cash.product("xp125").rid, "경험치 1.25배 패스의 구매 창 — " .. tostring(whyPP))
	local okOwn, whyOwn = CashServer.promptPass(s, "drop125")
	expect(not okOwn and whyOwn == "이미 가진 패스다" and #passPrompts == 1, "가진 패스는 창을 띄우지 않는다")
end
expect(not CashServer.promptPass(s, "tele"), "만들지 않은 패스(순간이동의 돌)는 띄우지 않는다")
expect(not CashServer.promptPass(s, "exp"), "개발자 상품은 패스의 창이 아니다")
eq(s.acct.bm.luna, 351, "패스의 창은 루나를 쓰지 않는다")
saveOk = false
local okF, whyF = CashServer.buy(s, "money")
expect(not okF and string.find(whyF or "", "저장하지 못했다", 1, true) ~= nil, "저장 실패 → 사지 못했다")
local moneyBox = 0
for _, e in s.acct.bm.box do
	if string.sub(e.id, 1, 9) == "bm_money_" then
		moneyBox += e.n
	end
end
expect(s.acct.bm.luna == 351 and moneyBox == 0, "루나 · 보관함 그대로")
saveOk = true
s.lunaBusy = true
local okBusy, whyBusy = CashServer.buy(s, "money")
expect(not okBusy and whyBusy ~= nil, "앞의 구매를 처리하는 동안에는 받지 않는다(두 번 누름)")
s.lunaBusy = nil

-- ⑥ 충전의 구매 창
local okC, whyC = CashServer.charge(s, "luna_500")
local pk = Cash.lunaPack("luna_500")
if Cash.packReady(pk) then
	expect(okC and #prompts == 1 and prompts[1][2] == pk.rid, "묶음의 구매 창")
else
	expect(not okC and whyC == "판매 준비 중" and #prompts == 0, "상품 번호가 없으면 「판매 준비 중」")
	pk.rid = 990500
	okC = CashServer.charge(s, "luna_500")
	expect(okC and #prompts == 1 and prompts[1][2] == 990500, "번호가 들어가면 구매 창")
end
expect(CashServer.pending(301, "luna_500") == 1, "띄운 창의 수")
expect(not CashServer.charge(s, "luna_7"), "없는 묶음")

-- ⑦ 예전 로벅스 결제 = 루나로 산 것과 같은 결과(사용자: "기존 로벅스로 구매한 아이템들도 루나로 산것과같은 판정")
local old = session(302)
local new = session(303)
new.acct.bm.luna = 5000
-- (영구 패스는 로블록스의 게임 패스라 결제가 오지 않는다 — 아래에서 따로)
for i, key in { "bagx", "storex", "money_x5", "dust", "starter", "mount_wolf" } do
	local p = Cash.product(key)
	if p and Cash.ready(p) then
		eq(CashServer.processReceipt({ PlayerId = 302, PurchaseId = "old" .. i, CurrencySpent = p.robux }, key), GRANTED, "예전 로벅스 결제 " .. key)
		expect(CashServer.buy(new, key), "루나로 " .. key)
	end
end
local function same(x, y)
	local sx, sy = {}, {}
	for _, e in x.acct.bm.box do
		sx[e.id] = e.n
	end
	for _, e in y.acct.bm.box do
		sy[e.id] = e.n
	end
	for k, v in sx do
		if sy[k] ~= v then
			return false, k
		end
	end
	for k, v in sy do
		if sx[k] ~= v then
			return false, k
		end
	end
	return true
end
local sameBox, diff = same(old, new)
expect(sameBox, "보관함의 아이템이 같다 " .. tostring(diff))
expect(old.acct.bm.mounts.mount_wolf == new.acct.bm.mounts.mount_wolf, "계정의 탈것이 같다")
eq(old.acct.bm.once.starter, new.acct.bm.once.starter, "산 수(한도)도 같이 센다")
old.passes = { xp125 = true } -- (로블록스에서 산 게임 패스 — 로벅스로 따로 산다)
expect(CashServer.owns(old, "xp125") and not CashServer.owns(new, "xp125"), "영구 패스는 로블록스에서 산 것만 가진 것")
-- 같은 아이템: 가방에 넣으면 같은 이름표 · 유료 표시 · 경매장 거래(가방 확장권)
local g = Items.goods("bm_bagx")
expect(g and g.paid == true and g.bound ~= true, "가방 확장권 = 유료 아이템 · 묶이지 않음(경매장 — 어떻게 샀든 같다)")

-- ⑧ 상점 표: 루나 · 묶음 · 값 · 루나로 산 패스는 「보유」
local v = Cash.view(new.acct, NOW, { xp125 = true }, 1, { luna_100 = 120, xp125 = 249 })
eq(v.luna, new.acct.bm.luna, "지금 루나")
eq(#v.packs, 6, "묶음 여섯")
local p100
for _, q in v.packs do
	if q.id == "luna_100" then
		p100 = q
	end
end
expect(p100 and p100.robux == 120, "묶음의 값 = 서버가 읽은 로블록스의 실제 값(대시보드)")
local row
for _, e in v.list do
	if e.id == "xp125" then
		row = e
	end
end
expect(row and row.own == true and row.robux == 249, "로블록스에서 산 패스는 「보유」 · 값은 로벅스(로블록스에서 읽은 값)")
