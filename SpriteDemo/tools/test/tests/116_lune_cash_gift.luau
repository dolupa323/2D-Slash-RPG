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

-- ⑩ 겹침 보상(2026-11-10 사용자: "이미 샀는데 증발된사람들한테 소급적용 해줘야해 … 돈관련된건 철저하게해야해"):
--  운영자가 보낸 "dupfix:<상자>:<횟수>"가 선물 상자 → 접속하지 않은 사람도 들어오면 계정에(남은 횟수) · 같은 것은 한 번 · 그 상자에서 나오는 가진 것에만 쓴다 · 결제의 기록에 남는다
local fx = { player = { UserId = 204 }, acct = account(204, "겹친이"), loaded = true, name = "겹친이" }
data["acct_204"] = Account.pack(fx.acct)
eq(Cash.dupfixKey("petbox", 2), "dupfix:petbox:2", "보내는 이름표")
expect(Cash.dupfixOf("dupfix:nobox:1") == nil and Cash.dupfixOf("dupfix:petbox:0") == nil and Cash.dupfixOf("dupfix:petbox:100") == nil, "없는 상자 · 이상한 횟수는 받지 않는다")
Store.bmGiftAdd(204, { k = Cash.dupfixKey("petbox", 2), rid = "fixA", from = "운영자", to = "겹친이", at = NOW })
sessions[204] = fx
table.clear(events)
CashServer.giftTick(fx)
local function boxN(c, id)
	for _, e in c.box do
		if e.id == id then
			return e.n
		end
	end
	return 0
end
eq(boxN(fx.acct.bm, "bm_pick_petbox"), 2, "들어오면 보관함에 펫 선택 상자 2개(2026-11-10 상자 판매 바로잡기부터 — 그 전에는 고르는 표)")
eq(#boxOf(204), 0, "선물 상자에서는 지웠다")
expect(events[1] and events[1][1] == "got" and events[1][3] == "dupfix:petbox:2", "받은 사람에게 알림(그 이름표)")
local logged = fx.acct.bm.log[#fx.acct.bm.log]
expect(logged and logged.k == "dupfix:petbox:2" and logged.r == "gfixA", "결제의 기록에 남는다")
expect(not Cash.grant(fx.acct, "dupfix:petbox:2", "gfixA", NOW, Account.MAX), "같은 것은 두 번 받지 않는다")
eq(boxN(fx.acct.bm, "bm_pick_petbox"), 2, "그대로 2개")
fx.acct.bm.dupfix.petbox = 2 -- (그 전에 받아 둔 고르는 표 — 쓰는 길은 남아 있다)
-- 쓰기: 그 상자에서 나오는 가진 것만
local r0, w0 = Cash.dupfixUse(fx.acct, "pet_silver")
expect(r0 == nil and w0 == Cash.DUPFIX_NONE, "가지지 않은 것에는 못 쓴다")
fx.acct.bm.pets.pet_silver = true
fx.acct.bm.mounts.mount_wolf = true
local r1 = Cash.dupfixUse(fx.acct, "mount_wolf")
expect(r1 == nil, "그 상자에서 나오지 않는 것(지금의 탈것 — 탈것 상자에 없다)에는 못 쓴다")
local r2, n2 = Cash.dupfixUse(fx.acct, "pet_silver")
expect(r2 == true and n2 == 2, "은빛 달토끼 하나 더 — 이제 2")
eq(fx.acct.bm.dupfix.petbox, 1, "남은 1번")
expect(Cash.dupfixUse(fx.acct, "pet_silver"), "한 번 더")
eq(fx.acct.bm.dupfix.petbox, nil, "다 쓰면 지운다")
eq(Cash.count(fx.acct.bm, "pet_silver"), 3, "은빛 달토끼 3")
expect(Cash.dupfixUse(fx.acct, "pet_silver") == nil, "남은 것이 없으면 못 쓴다")
-- 저장 꼴: 남은 횟수 · 기록
fx.acct.bm.dupfix.mountbox = 3
local backFix = Cash.unpack(Cash.pack(fx.acct.bm), Account.MAX)
eq(backFix.dupfix.mountbox, 3, "저장 → 읽기: 남은 횟수")
eq(#backFix.log, #fx.acct.bm.log, "저장 → 읽기: 기록")
local view = Cash.view(fx.acct, NOW)
eq(view.dupfix and view.dupfix.mountbox, 3, "상점 상태에 남은 횟수(가방 캐시 탭의 단추)")
local bad = Cash.pack(fx.acct.bm)
bad.dupfix = { nobox = 2, petbox = -1, mountbox = 1.5 }
local backBad = Cash.unpack(bad, Account.MAX)
expect(next(backBad.dupfix) == nil, "없는 상자 · 이상한 수는 버린다")
-- 산 것도 기록에: 상자를 사면 나온 것까지
local buyer = account(205, "산이")
expect(Cash.grant(buyer, "petbox", "buy1", NOW, Account.MAX), "펫 상자를 샀다")
local lb = buyer.bm.log[#buyer.bm.log]
expect(lb and lb.r == "buy1" and lb.k == "petbox" and typeof(lb.g) == "string" and lb.t == NOW, "기록 = 결제 번호 · 상품 · 때 · 나온 것 " .. tostring(lb and lb.g))
expect(Cash.grant(buyer, "bagx", "buy2", NOW, Account.MAX) and buyer.bm.log[#buyer.bm.log].g == nil, "뽑기가 아닌 것은 나온 것 없이")

-- ⑪ 겹침의 자동 보상(2026-11-10 사용자: "그사람이 가지고있는 캐시템이랑 산 상자를 비교하면 얼마나 사라졌는지 알수있는거아니야? 정확히 파악해야"):
--  사라진 수 = 산 수(로블록스 판매 기록) − 그 상자의 것을 가진 수(따로 산 달토끼 뺌) · 이미 준 수는 빼고 · 새 서버의 결제(기록)는 따로
local UPTO = 1794322062
local a1 = Account.new()
for _, id in { "dsk_mint", "dsk_blossom", "dsk_frost", "dsk_ember", "dsk_moon", "dsk_starry", "dsk_royal", "dsk_aurora" } do
	a1.bm.dskins[id] = true -- 데미지 스킨 상자의 여덟을 모두 가졌다
end
a1.bm.ntags.ntag_wave = true
a1.bm.ntags.ntag_sprout = true -- (두 종류 — 어느 것이 겹쳤는지 모른다 → 선택상자)
local dry = Cash.dupfixAuto(a1.bm, { dmgskin = 18, tagskin = 4 }, UPTO, NOW, true)
eq(#dry, 2, "산 상자 둘의 줄")
local byBox = {}
for _, r in dry do
	byBox[r.box] = r
end
expect(byBox.dmgskin.bought == 18 and byBox.dmgskin.owned == 8 and byBox.dmgskin.lost == 10 and byBox.dmgskin.add == 10, "데미지 스킨 상자 18개 · 여덟 가짐 → 10개 사라짐")
expect(byBox.tagskin.lost == 2 and byBox.tagskin.add == 2, "이름표 테두리 상자 4개 · 둘 가짐 → 2개")
expect(next(a1.bm.dupfix) == nil, "셈만(조회)은 계정을 바꾸지 않는다")
Cash.dupfixAuto(a1.bm, { dmgskin = 18, tagskin = 4 }, UPTO, NOW)
expect(a1.bm.dupfix.dmgskin == 10 and a1.bm.dupfix.tagskin == 2, "겹침 보상(선택상자) 10 · 2번")
expect(a1.bm.fixGiven.dmgskin == 10 and a1.bm.fixGiven.tagskin == 2, "준 수를 적는다")
local again = Cash.dupfixAuto(a1.bm, { dmgskin = 18, tagskin = 4 }, UPTO, NOW)
expect(again[1].add == 0 and again[2].add == 0 and a1.bm.dupfix.dmgskin == 10, "다시 셈해도 두 번 주지 않는다")
Cash.dupfixAuto(a1.bm, { dmgskin = 20, tagskin = 4 }, UPTO, NOW)
eq(a1.bm.dupfix.dmgskin, 12, "판매 기록을 다시 받아 2개 늘면 모자란 2번만 더")
local autoLog = 0
for _, e in a1.bm.log do
	if string.sub(e.r, 1, 4) == "auto" then
		autoLog += 1
	end
end
eq(autoLog, 3, "자동 보상도 결제의 기록에(10 · 2 · 2)")
-- 펫 상자: 따로 산 달토끼는 상자에서 나온 것으로 세지 않는다
local a2 = Account.new()
a2.bm.pets.pet_lantern = true -- 옛 상점에서 산 것
a2.bm.pets.pet_bud = true -- 상자에서 나온 것
local pr = Cash.dupfixAuto(a2.bm, { petbox = 3, direct = { "pet_lantern" } }, UPTO, NOW)[1]
expect(pr.owned == 1 and pr.lost == 2, "펫 상자 3개 · 상자에서 나온 것 하나 → 2개 사라짐(초롱 달토끼는 따로 산 것)")
-- 새 서버의 결제: 기록 받은 뒤(upTo 뒤) 새것이 나온 것은 가진 수에서 뺀다 · upTo까지 새 서버에서 산 것은 산 수에서 뺀다(그때는 겹쳐도 하나 더)
local a3 = Account.new()
a3.bm.mounts.mount_jelly = true
a3.bm.mounts.mount_whale = true -- 기록 받은 뒤 새 서버에서 산 상자에서 나왔다
a3.bm.log = { { r = "n1", k = "mountbox", t = UPTO + 60, g = "mount_whale" } }
local mr = Cash.dupfixAuto(a3.bm, { mountbox = 2 }, UPTO, NOW, true)[1]
expect(mr.owned == 1 and mr.lost == 1, "기록 뒤에 새로 얻은 것은 빼고 센다(2개 · 하나 가짐 → 1개)")
a3.bm.log = { { r = "n0", k = "mountbox", t = UPTO - 60, g = "mount_jelly", n = 2 } }
local mr2 = Cash.dupfixAuto(a3.bm, { mountbox = 2 }, UPTO, NOW, true)[1]
expect(mr2.bought == 1 and mr2.lost == 0, "기록 전에 새 서버에서 산 것(겹쳐도 하나 더 받음)은 산 수에서 뺀다")
expect(#Cash.dupfixAuto(a3.bm, nil, UPTO, NOW, true) == 0, "판매 기록이 없는 사람 = 없음")
-- 저장 꼴: 준 수
local backGiven = Cash.unpack(Cash.pack(a1.bm), Account.MAX)
eq(backGiven.fixGiven.dmgskin, 12, "저장 → 읽기: 준 수")
-- 서버: 들어온 사람마다 한 번 — 판매 기록에 있는 사람(Tuesday — modules/dupfixBuys.luau)이면 넣고 바로 저장 · 알림 / 저장에 실패하면 되돌리고 나중에
local tu = { player = { UserId = 1275060964 }, acct = account(1275060964, "화요일"), loaded = true, name = "화요일" }
tu.acct.bm.pets.pet_lantern = true
tu.acct.bm.pets.pet_bud = true
tu.acct.bm.mounts.mount_jelly = true
tu.acct.bm.ntags.ntag_wave = true
tu.acct.bm.ntags.ntag_lotus = true
tu.acct.bm.bubbles.bub_wave = true
tu.acct.bm.dskins.dsk_mint = true
sessions[1275060964] = tu
table.clear(events)
saveOk = false
CashServer.dupfixAuto(tu)
expect(next(tu.acct.bm.dupfix) == nil and not tu.fixDone and #events == 0, "저장에 실패하면 넣지 않고 알리지 않는다")
saveOk = true
tu.fixNext = 0
CashServer.dupfixAuto(tu)
expect(tu.fixDone == true, "한 번 했다")
eq(tu.acct.bm.dupfix.petbox, 2, "펫 상자 3 − 1(초롱 달토끼는 따로 산 것) = 2번(두 종류 → 선택상자)")
eq(tu.acct.bm.dupfix.tagskin, 1, "이름표 테두리 상자 3 − 2 = 1번(두 종류 → 선택상자)")
expect(tu.acct.bm.dupfix.bubblebox == nil and Cash.count(tu.acct.bm, "bub_wave") == 2, "말풍선 상자 2 − 1 = 1 · 한 종류(물결)만 → 물결 말풍선을 바로 하나 더")
eq(tu.acct.bm.dupfix.dmgskin, nil, "데미지 스킨 상자 1개 · 하나 가짐 → 없음")
eq(tu.acct.bm.dupfix.mountbox, nil, "탈것 상자 1개 · 하나 가짐 → 없음")
local fixEvents = 0
for _, e in events do
	if e[1] == "got" and string.match(e[3], "^dupfix:") then
		fixEvents += 1
	end
end
eq(fixEvents, 2, "선택상자마다 알림(펫 · 이름표 테두리)")
local itemEvents = 0
for _, e in events do
	if e[1] == "got" and e[3] == "fixitem:bub_wave:1" then
		itemEvents += 1
	end
end
eq(itemEvents, 1, "원래 상품으로 준 것도 알림(물결 말풍선)")
-- 그 상자의 것을 하나도 안 가졌으면 겹침일 수 없다 → 아직 들어오지 않은 결제(로블록스가 다시 보낸다) — 주지 않는다
local r0 = Cash.dupfixAuto(Account.new().bm, { tagskin = 2 }, UPTO, NOW, true)[1]
expect(r0.lost == 0 and r0.add == 0, "상자의 것이 하나도 없으면 사라진 수 0(두 번 받지 않게)")
table.clear(events)
CashServer.dupfixAuto(tu)
eq(#events, 0, "다시 부르지 않는다(들어온 뒤 한 번)")
local none = { player = { UserId = 999 }, acct = account(999, "안산이"), loaded = true, name = "안산이" }
CashServer.dupfixAuto(none)
expect(none.fixDone == true and next(none.acct.bm.dupfix) == nil, "판매 기록에 없는 사람은 아무것도 없다")

-- ⑫ 최대한 원래 상품으로(2026-11-10 사용자: "최대한 원래 상품으로 지급하고 그게 추론되지 않는경우는 선택상자로 지급하자"):
--  겹침은 그때 이미 가진 것만 나온다 → 그 상자의 것을 한 종류만 가졌으면 사라진 것은 모두 그것 = 그 아이템을 바로 · 두 종류 이상이면 선택상자
local a5 = Account.new()
a5.bm.mounts.mount_whale = true
local r5 = Cash.dupfixAuto(a5.bm, { mountbox = 3 }, UPTO, NOW)[1]
expect(r5.sure == "mount_whale" and r5.lost == 2, "탈것 상자 3개 · 별고래 하나만 → 사라진 2개는 모두 별고래")
expect(Cash.count(a5.bm, "mount_whale") == 3 and a5.bm.dupfix.mountbox == nil, "별고래를 바로 2개 더(가진 수 3) · 선택상자는 없음")
local l5 = a5.bm.log[#a5.bm.log]
expect(l5 and l5.k == "fixitem:mount_whale:2" and l5.g == "mount_whale" and l5.n == 3, "기록 = 원래 상품 · 수 · 그 뒤의 가진 수")
expect(Cash.dupfixAuto(a5.bm, { mountbox = 3 }, UPTO, NOW)[1].add == 0 and Cash.count(a5.bm, "mount_whale") == 3, "다시 셈해도 두 번 주지 않는다")
local a6 = Account.new()
a6.bm.pets.pet_lantern = true -- 옛 상점에서 따로 산 것 하나뿐
local r6 = Cash.dupfixAuto(a6.bm, { petbox = 2, direct = { "pet_lantern" } }, UPTO, NOW)[1]
expect(r6.owned == 0 and r6.lost == 2 and r6.sure == "pet_lantern" and Cash.count(a6.bm, "pet_lantern") == 3, "펫 상자 2개 · 따로 산 초롱 달토끼뿐 → 겹친 2개는 초롱 달토끼 → 2마리 더")
local a7 = Account.new()
a7.bm.mounts.mount_jelly = true
a7.bm.mounts.mount_whale = true
local r7 = Cash.dupfixAuto(a7.bm, { mountbox = 4 }, UPTO, NOW)[1]
expect(r7.sure == nil and a7.bm.dupfix.mountbox == 2 and Cash.count(a7.bm, "mount_jelly") == 1, "두 종류를 가졌으면 어느 것인지 모른다 → 선택상자 2번")
eq(Cash.fixItemOf("fixitem:mount_whale:2"), "mount_whale", "알림의 이름표를 읽는다")
eq(Cash.itemName("mount_whale"), Cash.MOUNT.mount_whale.name, "아이템 이름")
-- 서버: 원래 상품으로 준 것은 그 이름표로 알린다(1ca_dy1 — 탈것 상자 2개 · 달빛 해파리 하나만)
local ca = { player = { UserId = 11858280522 }, acct = account(11858280522, "씨에이"), loaded = true, name = "씨에이" }
ca.acct.bm.mounts.mount_jelly = true
sessions[11858280522] = ca
table.clear(events)
CashServer.dupfixAuto(ca)
expect(Cash.count(ca.acct.bm, "mount_jelly") == 2 and next(ca.acct.bm.dupfix) == nil, "달빛 해파리 하나 더(가진 수 2) · 선택상자 없음")
expect(events[1] and events[1][3] == "fixitem:mount_jelly:1", "알림 = 원래 상품 " .. tostring(events[1] and events[1][3]))

-- ⑬ 상자 판매 바로잡기(2026-11-10 사용자: "다시 다뺏고 안연상자를 산것보다 카테고리별로 +3인거야 그리고 상자별로 선택상자를 주는걸로"):
--  상자에서 받은 것을 모두 거둔다(가진 것 · 하나 더 · 남은 겹침 보상 · 보관함의 윤슬 조각 — 따로 산 달토끼는 하나 남긴다) → 상자마다 안 연 상자(산 수 + 3) · 선택 상자 하나 · 계정에 한 번
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local hz = Account.new()
local hb = hz.bm
for _, id in { "dsk_mint", "dsk_blossom", "dsk_frost", "dsk_ember", "dsk_moon", "dsk_aurora" } do
	hb.dskins[id] = true
end
hb.extra.dsk_aurora = 12 -- (선택상자를 오로라에 몰아 써 13개)
hb.dskin = "dsk_aurora"
hb.mounts.mount_whale, hb.mounts.mount_jelly = true, true
hb.mounts.mount_wolf = true -- (상자 밖의 탈것 — 그대로)
hb.mount = "mount_whale"
hb.ntags.ntag_wave = true
hb.ntag = "ntag_wave"
hb.bubbles.bub_lotus = true
hb.bubble = "bub_lotus"
hb.pets.pet_silver, hb.pets.pet_lantern = true, true -- 옛 상점에서 따로 산 것
hb.extra.pet_lantern = 1
hb.petsOut = { "pet_lantern", "pet_lantern", "pet_silver" }
hb.dupfix.tagskin = 2
hb.fixGiven.dmgskin = 10
table.insert(hb.box, { id = "yunseul", n = 24 })
table.insert(hb.box, { id = "bm_exp", n = 2 })
local HBUY = { dmgskin = 18, mountbox = 7, tagskin = 4, bubblebox = 2, direct = { "pet_silver", "pet_lantern", "pet_scarf" } }
local rz = Cash.boxReset(hb, HBUY, NOW, 1)
expect(rz ~= nil, "바로잡았다")
for _, id in { "dsk_mint", "dsk_blossom", "dsk_frost", "dsk_ember", "dsk_moon", "dsk_aurora" } do
	expect(not hb.dskins[id], "데미지 스킨을 거뒀다 " .. id)
end
eq(rz.taken.dsk_aurora, 13, "오로라 13개를 거뒀다")
expect(not hb.mounts.mount_whale and not hb.mounts.mount_jelly and hb.mounts.mount_wolf, "상자의 탈것만 거둔다(달빛 늑대는 그대로)")
expect(not hb.ntags.ntag_wave and not hb.bubbles.bub_lotus, "이름표 테두리 · 말풍선을 거뒀다")
expect(hb.dskin == false and hb.mount == false and hb.ntag == false and hb.bubble == false, "낀 것 · 고른 탈것을 푼다")
expect(hb.pets.pet_silver and hb.pets.pet_lantern and Cash.count(hb, "pet_lantern") == 2, "펫 상자를 사지 않은 사람의 펫은 그대로")
eq(table.concat(hb.petsOut, ","), "pet_lantern,pet_lantern,pet_silver", "꺼낸 펫도 그대로")
-- 펫 상자를 산 사람(Tuesday처럼): 상자의 펫은 거두고 · 따로 산 초롱 달토끼는 하나 남기고 하나 더는 거둔다 · 꺼낸 펫은 가진 수까지
local tz = Account.new()
local tb = tz.bm
tb.pets.pet_lantern, tb.pets.pet_bud, tb.pets.pet_fox = true, true, true
tb.extra.pet_lantern, tb.extra.pet_fox = 2, 1
tb.petsOut = { "pet_lantern", "pet_lantern", "pet_fox" }
local tr = Cash.boxReset(tb, { petbox = 3, direct = { "pet_lantern" } }, NOW, 1)
expect(tb.pets.pet_lantern and not tb.pets.pet_bud and not tb.pets.pet_fox, "상자의 펫은 거두고 따로 산 초롱 달토끼는 남는다")
expect(Cash.count(tb, "pet_lantern") == 1 and tr.taken.pet_lantern == 2 and tr.taken.pet_fox == 2, "초롱 달토끼의 하나 더(2)와 여우 둘을 거뒀다")
eq(table.concat(tb.petsOut, ","), "pet_lantern", "꺼낸 펫은 가진 것 · 가진 수까지")
eq(tb.petOut, "pet_lantern", "첫째 펫")
expect(next(hb.dupfix) == nil and hb.fixGiven.dmgskin == nil, "남은 겹침 보상 · 준 수를 지운다")
local inBox = {}
for _, e in hb.box do
	inBox[e.id] = e.n
end
expect(inBox.bm_box_dmgskin == 21 and inBox.bm_box_mountbox == 10 and inBox.bm_box_tagskin == 7 and inBox.bm_box_bubblebox == 5, "안 연 상자 = 산 수 + 3(상자마다)")
expect(inBox.bm_pick_dmgskin == 1 and inBox.bm_pick_mountbox == 1 and inBox.bm_pick_tagskin == 1 and inBox.bm_pick_bubblebox == 1, "선택 상자 하나씩(상자마다)")
expect(inBox.bm_box_petbox == nil and inBox.bm_pick_petbox == nil, "사지 않은 상자는 없다")
expect(inBox.yunseul == nil and rz.shards == 24, "보관함의 윤슬 조각을 거뒀다(24)")
eq(inBox.bm_exp, 2, "다른 보관함 물건은 그대로")
eq(Cash.boxReset(hb, HBUY, NOW, 1), nil, "계정에 한 번")
local back = Cash.unpack(Cash.pack(hb), Account.MAX)
eq(back.boxReset, 1, "저장 → 읽기: 바로잡은 차례")
for _, e in back.box do
	if e.id == "bm_box_dmgskin" then
		eq(e.n, 21, "저장 → 읽기: 안 연 상자")
	end
end
-- 안 연 상자를 쓴다(가방 「사용」 — Cash.use): 그 자리에서 열린다(산 것과 같은 셈 · 뽑기 연출의 lastBox · 기록)
local uh = Hero.new(1, "axion")
local boxDef = Items.goods("bm_box_dmgskin")
expect(boxDef and boxDef.kind == "bmBox" and boxDef.box == "dmgskin" and boxDef.bound == true and boxDef.paid == true, "안 연 상자의 아이템(경매장 불가)")
local okUse = Cash.use(uh, hz, boxDef)
expect(okUse == true and hb.lastBox and hb.lastBox.k == "dmgskin" and typeof(hb.lastBox.got) == "string", "열었다 — " .. tostring(hb.lastBox and hb.lastBox.got))
expect(hb.dskins[hb.lastBox.got] == true, "나온 것이 계정에")
expect(hb.log[#hb.log].k == "open:dmgskin" and hb.log[#hb.log].g == hb.lastBox.got, "열기도 결제의 기록에")
local firstGot = hb.lastBox.got
hb.lastBox = nil
-- 같은 것이 또 나오면 하나 더
Cash.use(uh, hz, boxDef)
local sameOrNew = hb.lastBox.got
expect(Cash.count(hb, sameOrNew) >= 1, "두 번째도 계정에")
local _ = firstGot
-- 선택 상자: 그 상자의 것 하나를 고른다(가방의 선택 상자를 쓴다 · 가진 것이면 하나 더)
local pickDef = Items.goods("bm_pick_tagskin")
expect(pickDef and pickDef.kind == "bmPick" and pickDef.box == "tagskin" and pickDef.bound == true, "선택 상자의 아이템")
expect(Bag.give(uh, "bm_pick_tagskin", 1), "가방에 선택 상자")
local nP, wP = Cash.pickBox(uh, hz, "dsk_aurora")
expect(nP == nil and wP ~= nil, "다른 상자의 것은 못 고른다(이름표 테두리 선택 상자로 데미지 스킨)")
local okP, cntP = Cash.pickBox(uh, hz, "ntag_royal")
expect(okP == true and cntP == 1 and hb.ntags.ntag_royal == true, "황금 왕관 이름표를 골라 받았다")
eq(hb.ntag, "ntag_royal", "낀 것이 없으면 바로 낀다")
eq(Bag.count(uh, "bm_pick_tagskin"), 0, "선택 상자를 썼다")
expect(Cash.pickBox(uh, hz, "ntag_royal") == nil, "선택 상자가 없으면 못 고른다")
-- 서버: 계정을 읽을 때 한 번(판매 기록에 있는 사람 — hinoo) · 저장에 실패하면 되돌린다
local hs = { player = { UserId = 1372895479 }, acct = account(1372895479, "히누"), loaded = true, name = "히누" }
hs.acct.bm.dskins.dsk_aurora = true
hs.acct.bm.extra.dsk_aurora = 12
saveOk = false
expect(CashServer.boxReset(hs) == false and hs.acct.bm.dskins.dsk_aurora == true and (hs.acct.bm.boxReset or 0) == 0, "저장에 실패하면 되돌린다")
saveOk = true
expect(CashServer.boxReset(hs) == true and hs.resetNote == true, "바로잡았다(들어오면 알림)")
expect(not hs.acct.bm.dskins.dsk_aurora and Cash.count(hs.acct.bm, "dsk_aurora") == 0, "오로라를 거뒀다")
local hsBox = {}
for _, e in hs.acct.bm.box do
	hsBox[e.id] = e.n
end
expect(hsBox.bm_box_dmgskin == 21 and hsBox.bm_box_mountbox == 10 and hsBox.bm_box_tagskin == 7 and hsBox.bm_box_bubblebox == 5, "hinoo: 안 연 상자 21 · 10 · 7 · 5")
expect(CashServer.boxReset(hs) == false, "다시 하지 않는다")
local nobody = { player = { UserId = 999 }, acct = account(999, "아무개"), loaded = true, name = "아무개" }
expect(CashServer.boxReset(nobody) == false and (nobody.acct.bm.boxReset or 0) == 0, "판매 기록에 없는 사람은 그대로")
-- 운영자가 보내는 것(관리 창 「뽑기 보상」): 이제 선택 상자
local gz = Account.new()
expect(Cash.grant(gz, "dupfix:mountbox:2", "gpick1", NOW, Account.MAX), "보낸 것을 받는다")
local gzBox = {}
for _, e in gz.bm.box do
	gzBox[e.id] = e.n
end
expect(gzBox.bm_pick_mountbox == 2 and next(gz.bm.dupfix) == nil, "탈것 선택 상자 2개(고르는 표가 아니다)")
