-- 「달의 계승자」 — 경매장(메이플 옥션 방식).
--  사용자 2026-10-06: "경매장으로 전부 거래가능하게 할겁니다" · 2026-10-13: "경매장 부터 진행합시다.  알아서 조사하고 판단하고 해서  경매장 구현 해보세요"
--  **사용자 2026-10-13(처음 만든 것을 보고): "메이플 식 경매장을 말하는거긴합니다."** — 메뉴에서 어디서나 연다 · 구매 / 판매 / 완료 / 시세 · 개당 가격과 낱개 구매 · 보증금 · 완료에서 수령 / 대금 수령 / 반환 / 재등록 / 모두 받기.
--  셈(shared/lune/sim/market.luau) · 저장소의 장부(server/lune/modules/store.luau) · 서버의 흐름(world.luau의 onMarket) · 창의 글과 폭(shared/lune/ui/auctionView.luau) · 창(client/lune/ui/auctionWindow.luau)을 화면 없이 돌려 본다.
--  가장 무겁게 보는 것: 물건과 달돈이 복사되지도 사라지지도 않는가 — 여럿이 같이 살 때 · 저장소가 답하지 않을 때 · 저장하지 못했을 때 · 처리하는 도중에 나갈 때 · 서버가 바뀔 때.

-- DataStore가 하는 일의 흉내(차례로 놓인 표는 배열로, 그 밖의 표는 이름표가 글자인 표로 — 읽을 때마다 새 표가 온다)
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
local function same(a, b): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- ================= 1) 셈: 물건의 꼴 · 장부를 바꾸는 법 · 맡긴 것과 견주기 =================
do
	local Market = req("ReplicatedStorage/shared/lune/sim/market")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local Account = req("ReplicatedStorage/shared/lune/sim/account")
	local Format = req("ReplicatedStorage/shared/lune/ui/format")
	local M, WHY = Market.DATA, Market.WHY
	local NOW = 1700000000
	local H = 3600
	-- 메이플 옥션의 숫자
	eq(M.fee, 5, "수수료 5%")
	eq(M.slots, 10, "한 계정이 열 건까지")
	expect(#M.hours == 2 and M.hours[1] == 24 and M.hours[2] == 48, "기간은 24 · 48시간")
	expect(M.keepDays == 365 and Market.KEEP == 365 * 86400, "끝난 거래는 1년 보관")
	expect(M.deposit >= 1 and M.holdMax >= M.slots and M.cap >= 50 and M.show >= 20 and M.show <= M.cap and M.priceMax >= 1e8 and M.logMax >= 20 and M.lastBuys >= 2, "보증금 · 받지 않은 구매품 · 분류의 크기 · 보여 주는 수 · 값의 위 · 시세")
	eq(table.concat(Market.WORDS.tabs, "/"), "구매/판매/완료/시세", "탭 넷(메이플 옥션)")

	-- 물건의 꼴
	local hat = Items.make("hat", 10, 4)
	hat.star, hat.id = 3, 77
	local axe = Items.make("weapon", 10, 3, "axion")
	local potion = Items.potionFor(1)
	local quest, mat
	for _, g in Items.data.GOODS do
		if g.quest and not quest then
			quest = g
		elseif g.tab == "etc" and not g.quest and g.kind ~= "event" and not mat then -- (기간 이벤트의 물건 — 호박 사탕 — 은 올릴 수 없다: 113_lune_halloween)
			mat = g
		end
	end
	expect(potion ~= nil and quest ~= nil and mat ~= nil, "물약 · 퀘스트의 물건 · 재료가 있다")
	local rowHat = Market.pack(hat)
	local back = Market.unpack(rowHat)
	expect(back.slot == "hat" and back.stage == 10 and back.q == 4 and back.star == 3 and back.broken == false and back.id == nil, "장비는 성능 · 별까지 그대로 오간다(가방의 번호는 떼고)")
	local rowPot = Market.pack({ item = potion.id, n = 10 })
	expect(same(Market.unpack(rowPot), { item = potion.id, n = 10 }), "묶음은 이름표와 수")
	expect(Market.unpack({ g = "없는것", n = 1 }) == nil and Market.unpack({ g = potion.id, n = 0 }) == nil and Market.unpack({ g = potion.id, n = potion.stack + 1 }) == nil and Market.unpack({ g = potion.id, n = 1.5 }) == nil, "없는 물건 · 0개 · 한 묶음을 넘는 수 · 소수는 받지 않는다")
	expect(Market.unpack({ "hat", 10, 99, 0, "", 0, 0 }) == nil and Market.unpack({ "weapon", 10, 3, 0, "nobody", 0, 0 }) == nil and Market.unpack("x") == nil and Market.unpack(nil) == nil, "꼴이 틀린 장비는 받지 않는다")
	expect(Market.units(rowHat) == 1 and Market.units(rowPot) == 10, "수: 장비는 하나 · 묶음은 그 수")
	local three = Market.withUnits(rowPot, 3)
	expect(three.g == potion.id and three.n == 3 and rowPot.n == 10 and Market.withUnits(rowHat, 5) ~= rowHat and same(Market.withUnits(rowHat, 5), rowHat), "같은 물건을 n개로(받은 것은 고치지 않는다 · 장비는 그대로)")
	expect(Market.sellable(hat) == true and Market.sellable({ item = potion.id, n = 3 }) == true and Market.sellable({ item = mat.id, n = 1 }) == true, "장비 · 소비 · 기타 아이템을 올린다")
	local ok1, why1 = Market.sellable({ item = quest.id, n = 1 })
	expect(ok1 == nil and why1 == WHY.quest, "퀘스트의 물건은 못 올린다")
	local brokenHat = Items.make("hat", 10, 3)
	brokenHat.broken = true
	local ok2, why2 = Market.sellable(brokenHat)
	expect(ok2 == nil and why2 == WHY.item, "부서진 장비는 못 올린다")
	-- 장부의 이름
	eq(Market.boardOf(rowHat), "a_hat", "방어구는 부위마다")
	eq(Market.boardOf(Market.pack(axe)), "w_axion", "무기는 직업마다")
	eq(Market.boardOf(rowPot), "u", "소비")
	eq(Market.boardOf({ g = mat.id, n = 1 }), "e", "기타")
	eq(#Market.boards(), 11, "장부는 열하나(무기 다섯 · 방어구 넷 · 소비 · 기타)")
	for _, key in Market.boards() do
		expect(Market.isBoard(key), "있는 장부 " .. key)
	end
	for _, key in { "w_nobody", "a_weapon", "a_", "x", "b_u", "w_axion/../u", "", 3, false } do
		expect(not Market.isBoard(key), "없는 장부 " .. tostring(key))
	end
	local cats = Market.cats()
	eq(#cats, 7, "분류 일곱(무기 · 모자 · 옷 · 장갑 · 신발 · 소비 · 기타)")
	for _, c in cats do
		expect(Market.isBoard(Market.catBoard(c.id, "riven")), "분류의 장부 " .. c.id)
	end
	-- 값
	eq(Market.fee(100), 5, "100의 수수료 5")
	eq(Market.payout(100), 95, "100에 팔면 95를 받는다")
	eq(Market.fee(19), 0, "수수료는 내림(19 → 0)")
	expect(Market.priceOk(1) and Market.priceOk(M.priceMax) and not Market.priceOk(0) and not Market.priceOk(-5) and not Market.priceOk(M.priceMax + 1) and not Market.priceOk(1.5) and not Market.priceOk("100") and not Market.priceOk(0 / 0), "값은 1부터 위까지의 정수")
	expect(Market.hoursOk(24) and Market.hoursOk(48) and not Market.hoursOk(12) and not Market.hoursOk("24"), "기간은 정해진 것만")
	eq(Format.comma(0), "0", "쉼표: 0")
	eq(Format.comma(1000), "1,000", "쉼표: 1,000")
	eq(Format.comma(999999999), "999,999,999", "쉼표: 가장 큰 값")

	-- 올리기
	local e1 = Market.entry("5_1_1", 5, "판매자", rowPot, 50, 24, NOW)
	expect(e1.e == NOW + 24 * H and e1.u == 5 and e1.p == 50 and e1.l == 10 and e1.c == nil, "새 줄: 값은 개당 · 남은 수 = 올린 수 · 끝나는 때 = 올린 때 + 기간")
	eq(Market.entry("5_1_9", 5, "판매자", rowHat, 1000, 48, NOW).l, 1, "장비의 남은 수는 하나")
	local d1, w1 = Market.txList(nil, e1, NOW)
	expect(w1 == nil and #d1.list == 1 and d1.v == Market.VERSION and #d1.log == 0, "빈 장부에 올린다")
	eq(#Market.txList(json(d1), e1, NOW).list, 1, "같은 줄을 다시 올려도 하나다(저장소가 다시 불렀을 때)")
	local full = { v = 2, list = {} }
	for i = 1, M.cap do
		table.insert(full.list, Market.entry("9_1_" .. i, 9, "많이", rowPot, 10, 24, NOW))
	end
	local dFull, wFull = Market.txList(full, e1, NOW)
	expect(dFull == nil and wFull == WHY.full, "판매 중인 줄이 가득 찬 분류에는 못 올린다")
	local dOld = Market.txList(full, Market.entry("5_1_2", 5, "판매자", rowHat, 1, 24, NOW + 25 * H), NOW + 25 * H)
	expect(dOld ~= nil and #dOld.list == M.cap + 1, "기간이 끝난 줄은 자리를 차지하지 않는다")

	-- 사기: 낱개로 · 남은 수만큼만 · 받은 장부는 고치지 않는다
	local doc = json(d1)
	local before = json(doc)
	local d2, w2, got2 = Market.txBuy(doc, "5_1_1", 6, 3, 50, NOW + 60, "k1")
	expect(same(doc, before), "받은 장부를 고치지 않는다(저장소가 다시 불러도 같은 답)")
	expect(w2 == nil and got2 ~= nil and d2.list[1].l == 7 and d2.list[1].it.n == 10 and #d2.list[1].b == 1 and d2.list[1].b[1].u == 6 and d2.list[1].b[1].q == 3, "셋을 샀다: 남은 수 7(올린 수는 그대로)")
	expect(#d2.log == 1 and d2.log[1].it.n == 3 and d2.log[1].p == 50 and d2.log[1].t == NOW + 60, "거래가 시세에 남는다(팔린 수 · 개당 값 · 때)")
	local d2b, w2b, got2b = Market.txBuy(json(d2), "5_1_1", 6, 3, 50, NOW + 60, "k1")
	expect(d2b == nil and w2b == nil and got2b ~= nil and got2b.l == 7, "같은 구매가 다시 불리면 한 번만 친다(답이 늦어 다시 불렸을 때 — 두 번 팔리지 않는다)")
	local d3 = Market.txBuy(json(d2), "5_1_1", 6, 3, 50, NOW + 61, "k2")
	eq(d3.list[1].l, 4, "새 구매(다른 표)는 또 팔린다")
	expect(select(2, Market.txBuy(json(d2), "5_1_1", 7, 8, 50, NOW + 61, "k3")) == WHY.count, "남은 수보다 많이는 못 산다")
	expect(select(2, Market.txBuy(json(d2), "5_1_1", 7, 0, 50, NOW + 61, "k3")) == WHY.count and select(2, Market.txBuy(json(d2), "5_1_1", 7, 1.5, 50, NOW + 61, "k3")) == WHY.count, "0개 · 소수는 못 산다")
	local d4 = Market.txBuy(json(d2), "5_1_1", 7, 7, 50, NOW + 62, "k4")
	expect(d4.list[1].l == 0 and Market.stateOf(d4.list[1], NOW + 62) == "soldout" and #d4.log == 2, "남은 것을 다 사면 다 팔린 줄이 된다")
	expect(select(2, Market.txBuy(json(d4), "5_1_1", 8, 1, 50, NOW + 63, "k5")) == WHY.gone, "다 팔린 줄은 못 산다")
	expect(select(2, Market.txBuy(json(d1), "5_1_1", 5, 1, 50, NOW, "k6")) == WHY.mine, "내가 올린 것은 못 산다")
	expect(select(2, Market.txBuy(json(d1), "5_1_1", 6, 1, 49, NOW, "k6")) == WHY.changed, "본 값과 다르면 사지 않는다")
	expect(select(2, Market.txBuy(json(d1), "5_1_1", 6, 1, 50, NOW + 24 * H, "k6")) == WHY.expired, "기간이 끝난 줄은 못 산다")
	expect(select(2, Market.txBuy(json(d1), "없는줄", 6, 1, 50, NOW, "k6")) == WHY.gone and select(2, Market.txBuy(nil, "5_1_1", 6, 1, 50, NOW, "k6")) == WHY.gone, "없는 줄")
	local gearDoc = Market.txList(nil, Market.entry("5_1_9", 5, "판매자", rowHat, 1000, 24, NOW), NOW)
	expect(select(2, Market.txBuy(json(gearDoc), "5_1_9", 6, 2, 1000, NOW, "g1")) == WHY.count, "장비는 하나뿐이다")
	local gearSold = Market.txBuy(json(gearDoc), "5_1_9", 6, 1, 1000, NOW, "g1")
	expect(gearSold.list[1].l == 0 and gearSold.log[1].it[1] == "hat" and gearSold.log[1].it[3] == 4, "장비를 샀다(시세에 성능까지 남는다)")
	-- 줄마다 기억하는 최근 구매는 몇 건뿐이다(오래된 표는 잊는다 — 다시 부르는 것은 몇 초 안의 일이다)
	local many = Market.txList(nil, Market.entry("5_1_3", 5, "판매자", { g = potion.id, n = 20 }, 5, 24, NOW), NOW)
	for i = 1, M.lastBuys + 3 do
		many = Market.txBuy(json(many), "5_1_3", 6, 1, 5, NOW + i, "m" .. i)
	end
	expect(#many.list[1].b == M.lastBuys and many.list[1].l == 20 - (M.lastBuys + 3), "최근 구매는 정해진 수만 남긴다")
	expect(Market.boughtBy(many, "5_1_3", 6, "m" .. (M.lastBuys + 3)) ~= nil and Market.boughtBy(many, "5_1_3", 6, "m1") == nil and Market.boughtBy(many, "5_1_3", 7, "m" .. (M.lastBuys + 3)) == nil, "그 사람의 그 구매가 적혔는가")
	-- 시세의 기록: 정해진 수 · 날 수까지만
	local busyDoc = Market.txList(nil, Market.entry("5_1_4", 5, "판매자", { g = potion.id, n = potion.stack }, 5, 48, NOW), NOW)
	busyDoc.log = {}
	for i = 1, M.logMax + 5 do
		table.insert(busyDoc.log, { it = { g = potion.id, n = 1 }, p = i, t = NOW })
	end
	local trimmed = Market.txBuy(busyDoc, "5_1_4", 6, 1, 5, NOW + 1, "z1")
	expect(#trimmed.log == M.logMax and trimmed.log[#trimmed.log].p == 5 and trimmed.log[1].p == 7, "시세는 최근 것만 남긴다(오래된 것부터 버린다)")
	eq(#Market.fresh(trimmed, NOW + Market.LOG_KEEP + 5).log, 0, "오래된 거래는 시세에서 빠진다")
	local trades = Market.trades(d4, NOW + 100)
	expect(#trades == 2 and trades[1].it.n == 7 and trades[2].it.n == 3 and trades[1].p == 50, "시세: 새것부터")
	expect(#Market.trades(trimmed, NOW + 2) == M.show, "시세도 보여 주는 수까지만")
	eq(#Market.trades(nil, NOW), 0, "빈 장부의 시세")

	-- 닫기(취소 · 반환 · 재등록의 첫걸음) · 지우기
	local c1, r1, l1 = Market.txClose(json(d2), "5_1_1", 5, NOW + 70)
	expect(r1 == "closed" and l1 == 7 and c1.list[1].c == 1 and c1.list[1].l == 7 and Market.stateOf(c1.list[1], NOW + 70) == "ended", "닫는다: 남은 수가 굳는다")
	local c1b, r1b, l1b = Market.txClose(json(c1), "5_1_1", 5, NOW + 71)
	expect(c1b == nil and r1b == "closed" and l1b == 7, "다시 닫아도 같은 답(고치지 않는다)")
	expect(select(2, Market.txBuy(json(c1), "5_1_1", 6, 1, 50, NOW + 72, "k9")) == WHY.gone, "닫힌 줄은 팔리지 않는다")
	expect(select(2, Market.txClose(json(d2), "5_1_1", 8, NOW)) == "none" and select(2, Market.txClose(nil, "5_1_1", 5, NOW)) == "none", "남의 줄 · 없는 줄은 닫지 못한다")
	local s1, sr1 = Market.txSettle(json(c1), "5_1_1", 5, NOW)
	expect(sr1 == "ok" and #s1.list == 0 and #s1.log == 1, "줄을 지운다(시세의 기록은 남는다)")
	expect(select(2, Market.txSettle(json(c1), "5_1_1", 8, NOW)) == "none" and select(2, Market.txSettle(json(s1), "5_1_1", 5, NOW)) == "none", "남의 줄 · 없는 줄은 지우지 않는다")
	local p1, pn = Market.txPurge({ v = 2, list = { Market.entry("0_1_1", 0, "시험", rowHat, 5, 24, NOW), Market.entry("3_1_1", 3, "남", rowHat, 5, 24, NOW) } }, 0, NOW)
	expect(pn == 1 and #p1.list == 1 and p1.list[1].u == 3 and Market.txPurge(p1, 0, NOW) == nil, "그 사람의 줄만 치운다")

	-- 목록: 판매 중인 것만, 싼 것부터 — 남은 수로 보인다
	local list = { v = 2, list = {
		Market.entry("1_1_1", 1, "가", rowHat, 500, 24, NOW),
		Market.entry("2_1_1", 2, "나", rowPot, 100, 24, NOW + 5),
		Market.entry("3_1_1", 3, "다", rowPot, 100, 24, NOW),
		Market.entry("4_1_1", 4, "라", rowHat, 50, 24, NOW - 30 * H), -- 기간이 끝났다
		Market.entry("6_1_1", 6, "마", rowHat, 60, 24, NOW), -- 닫혔다
	} }
	list.list[1].l = 0 -- 다 팔렸다
	list.list[2].l = 4 -- 여섯이 팔렸다
	list.list[5].c = 1
	local rows = Market.rows(list, NOW + 10, 3)
	expect(#rows == 2 and rows[1].id == "3_1_1" and rows[2].id == "2_1_1" and rows[1].mine == true and rows[2].mine == false and rows[1].sn == "다", "판매 중인 것만 · 값이 같으면 먼저 올린 것부터 · 내 것 표시")
	expect(rows[2].l == 4 and rows[2].it.n == 4 and rows[1].it.n == 10 and list.list[2].it.n == 10, "남은 수로 보인다(장부의 줄은 그대로)")
	local big = { v = 2, list = {} }
	for i = 1, M.show + 15 do
		table.insert(big.list, Market.entry("7_1_" .. i, 7, "큰손", rowPot, 1000 - i, 24, NOW))
	end
	local shown = Market.rows(big, NOW, nil)
	expect(#shown == M.show and shown[1].p == 1000 - (M.show + 15), "보여 주는 수까지만(싼 것부터)")
	eq(#Market.rows(nil, NOW, 1), 0, "빈 장부")
	eq(#Market.rows({ v = 2, list = { "깨진 줄", { id = 3 }, { id = "x", e = NOW + 9, u = 1, p = 1, t = NOW }, Market.entry("8_1_1", 8, "x", { g = "없는것", n = 1 }, 5, 24, NOW) } }, NOW, 1), 0, "꼴이 깨진 줄은 보이지 않는다")
	local olds = { v = 2, list = { Market.entry("1_1_1", 1, "가", rowHat, 500, 24, NOW), Market.entry("1_1_2", 1, "가", rowHat, 500, 24, NOW - Market.KEEP - 25 * H) } }
	eq(#Market.fresh(olds, NOW).list, 1, "기간이 끝나고 보관 기간도 지난 줄은 장부에서 빠진다")

	-- 맡긴 것과 견주기: 팔린 수 = 올린 수 − 남은 수 · 받을 대금 = 아직 받지 않은 수의 값
	local handle = { b = "u", it = rowPot, p = 50, t = NOW, e = NOW + 24 * H, got = 0, d = M.deposit }
	local function look(entry, at)
		local r = Market.resolve(handle, entry, at)
		return r, Market.amount(handle, r)
	end
	local r, am = look(d1.list[1], NOW + 10)
	expect(r.state == "selling" and r.n == 10 and r.left == 10 and r.sold == 0 and r.due == 0 and am.pay == 0 and am.deposit == 0, "아직 안 팔렸다")
	r, am = look(d2.list[1], NOW + 70)
	expect(r.state == "selling" and r.left == 7 and r.sold == 3 and r.due == 3 and am.gross == 150 and am.fee == 7 and am.pay == 143 and am.deposit == 0, "셋이 팔렸다: 150에서 수수료 7을 떼고 143(보증금은 아직)")
	handle.got = 3
	r, am = look(d2.list[1], NOW + 70)
	expect(r.due == 0 and am.pay == 0, "받은 것은 다시 받지 않는다")
	r, am = look(d4.list[1], NOW + 70)
	expect(r.state == "soldout" and r.left == 0 and r.due == 7 and am.gross == 350 and am.pay == 350 - 17 and am.deposit == M.deposit, "다 팔렸다: 남은 일곱의 대금과 보증금")
	r, am = look(d2.list[1], NOW + 25 * H)
	expect(r.state == "ended" and r.left == 7 and r.due == 0 and am.deposit == 0, "기간이 끝났다: 남은 일곱을 돌려받는다 — 보증금은 돌려받지 못한다")
	r, am = look(c1.list[1], NOW + 80)
	expect(r.state == "ended" and r.left == 7, "닫힌 줄도 끝난 것이다")
	handle.got = 0
	r, am = look(nil, NOW + 10)
	expect(r.state == "back" and r.left == 10 and r.due == 0 and am.deposit == M.deposit, "줄이 없다 = 장부에 오르지 못했다: 물건과 보증금이 돌아온다")
	eq(look(nil, NOW + 24 * H + Market.KEEP).state, "void", "보관 기간이 지났다")
	eq(Market.resolve({ hold = true, it = rowHat, p = 0, t = NOW, e = NOW }, nil, NOW + 999 * 86400).state, "hold", "산 것(낙찰)은 사라지지 않는다")
	expect(Market.entryIn(d1, "5_1_1", 5, NOW) ~= nil and Market.entryIn(d1, "5_1_1", 6, NOW) == nil and Market.entryIn(nil, "5_1_1", 5, NOW) == nil, "내 줄만 찾는다")
	expect(Market.entryIn(d4, "5_1_1", 5, NOW + 24 * H + Market.KEEP - 1) ~= nil and Market.entryIn(d4, "5_1_1", 5, NOW + 24 * H + Market.KEEP) == nil, "보관 기간이 지난 줄은 없는 것으로 본다(팔린 것의 대금도 그때까지)")

	-- 계정의 「맡긴 것」: 저장하고 읽기
	local book = Market.newBook()
	local id1 = Market.nextId(book, 5, NOW)
	local t1, t2 = Market.nextToken(book, NOW), Market.nextToken(book, NOW)
	expect(string.find(id1, "^5_") ~= nil and t1 ~= t2 and Market.nextToken(Market.newBook(), NOW + 1) ~= Market.nextToken(Market.newBook(), NOW + 2), "번호는 겹치지 않는다(차례가 되돌아가도 때가 다르다)")
	book.list[id1] = { b = "u", it = rowPot, p = 50, t = NOW, e = NOW + 24 * H, got = 3, d = M.deposit }
	book.list["h_" .. t1] = { hold = true, it = rowHat, p = 1000, t = NOW, e = NOW }
	expect(Market.count(book) == 1 and Market.holds(book) == 1, "판매한 수 · 받지 않은 구매품의 수는 따로 센다")
	local again = Market.unpackBook(json(Market.packBook(book)))
	expect(again.seq == book.seq and same(again.list[id1], book.list[id1]) and again.list["h_" .. t1].hold == true and same(again.list["h_" .. t1].it, rowHat) and again.list["h_" .. t1].p == 1000, "저장했다 읽어도 같다(받은 수 · 보증금까지)")
	local dirty = json(Market.packBook(book))
	table.insert(dirty.list, { id = "bad1", b = "nowhere", it = rowHat, p = 5, t = 1, e = 2, hold = false })
	table.insert(dirty.list, { id = "bad2", b = "u", it = { g = "없는것", n = 1 }, p = 5, t = 1, e = 2, hold = false })
	table.insert(dirty.list, { id = "old1", b = "a_hat", it = rowHat, p = 5, t = 1, e = 2, hold = false }) -- 받은 수 · 보증금이 없던 꼴
	table.insert(dirty.list, { id = "odd1", b = "u", it = rowPot, p = 5, t = 1, e = 2, got = 99, d = -4, hold = false })
	table.insert(dirty.list, "깨진 줄")
	local cleaned = Market.unpackBook(dirty)
	expect(Market.count(cleaned) == 3 and cleaned.list.old1.got == 0 and cleaned.list.old1.d == 0 and cleaned.list.odd1.got == 0 and cleaned.list.odd1.d == 0, "꼴이 틀린 것은 읽지 않는다 · 말이 안 되는 수는 0으로")
	eq(Market.count(Market.unpackBook(nil)), 0, "경매장이 생기기 전의 저장 = 맡긴 것 없음")
	local acct = Account.new()
	expect(acct.market ~= nil and Market.count(acct.market) == 0, "새 계정의 맡긴 것은 비어 있다")
	acct.market = book
	local packed = json(Account.pack(acct))
	local acct2 = Account.unpack(packed)
	expect(acct2 ~= nil and Market.count(acct2.market) == 1 and Market.holds(acct2.market) == 1, "계정과 함께 저장되고 읽힌다")
	packed.market = nil
	expect(Market.count(Account.unpack(packed).market) == 0, "맡긴 것이 없던 예전 저장도 읽힌다")
end

-- ================= 2) 저장소의 장부(가짜 DataStore 위에서) =================
do
	RESET()
	local data = {}
	local failing = 0 -- 앞으로 이만큼의 호출이 오류를 낸다
	local fake = {
		GetAsync = function(_, key)
			if failing > 0 then
				failing -= 1
				error("저장소 오류")
			end
			return json(data[key])
		end,
		SetAsync = function(_, key, value)
			data[key] = json(value)
		end,
		UpdateAsync = function(_, key, fn)
			if failing > 0 then
				failing -= 1
				error("저장소 오류")
			end
			local value = fn(json(data[key]))
			if value ~= nil then
				data[key] = json(value)
			end
		end,
	}
	local names = {}
	SERVICE("DataStoreService", {
		GetDataStore = function(_, name)
			names[name] = true
			return fake
		end,
		GetOrderedDataStore = function()
			return fake
		end,
	})
	local Store = req("ServerScriptService/server/lune/modules/store")
	local ok, doc = Store.marketRead("u")
	expect(ok == true and doc == nil and names.LuneMarket_v2 == true and names.LuneMarket_v1 == nil, "빈 장부를 읽는다(LuneMarket_v2 — 처음 만든 꼴의 장부는 쓰지 않는다)")
	local wrote, a, b, after = Store.marketUpdate("u", function(old)
		expect(old == nil, "처음에는 문서가 없다")
		return { v = 2, list = { { id = "x" } } }, "가", "나"
	end)
	expect(wrote == true and a == "가" and b == "나" and after.list[1].id == "x" and data.b_u ~= nil and data.b_u.list[1].id == "x", "새 문서를 쓰고 결과 둘과 바꾼 뒤의 문서를 돌려준다(열쇠 b_<분류>)")
	wrote, a, b, after = Store.marketUpdate("u", function(old)
		return nil, "그대로", old.list[1].id
	end)
	expect(wrote == true and a == "그대로" and b == "x" and after.list[1].id == "x" and #data.b_u.list == 1, "nil을 돌려주면 쓰지 않는다(읽은 문서를 그대로 돌려준다)")
	failing = 2
	local done, res = false, nil
	task.spawn(function()
		res = { Store.marketUpdate("u", function(old)
			table.insert(old.list, { id = "y" })
			return old, "됨"
		end) }
		done = true
	end)
	advance(10)
	expect(done and res[1] == true and res[2] == "됨" and #data.b_u.list == 2, "두 번 실패해도 세 번째에 쓴다")
	failing = 99
	done = false
	task.spawn(function()
		res = { Store.marketUpdate("u", function(old)
			return old, "?"
		end) }
		done = true
	end)
	advance(10)
	expect(done and res[1] == false, "끝내 못 쓰면 false")
	done = false
	task.spawn(function()
		res = { Store.marketRead("u") }
		done = true
	end)
	advance(10)
	expect(done and res[1] == false, "끝내 못 읽으면 false")
	failing = 0
	expect(Store.isOffline() == false, "장부가 잠깐 안 된다고 저장소 전체를 메모리로 돌리지 않는다")
	ok, doc = Store.marketRead("u")
	expect(ok and #doc.list == 2, "다시 되면 저장소의 것을 읽는다")
	-- 저장소를 못 쓰는 곳(Studio — API 접근이 꺼져 있다): 메모리에 둔다
	RESET()
	SERVICE("DataStoreService", {
		GetDataStore = function()
			error("API 접근이 꺼져 있다")
		end,
		GetOrderedDataStore = function()
			error("API 접근이 꺼져 있다")
		end,
	})
	SERVICE("RunService", { IsStudio = function() return true end, Heartbeat = { Connect = function() end } }) -- Studio다(메모리 모드는 Studio에서만 — 2026-10-18)
	local Off = req("ServerScriptService/server/lune/modules/store")
	local w2, a2, _, after2 = Off.marketUpdate("e", function(old)
		return { v = 2, list = { { id = "m" } } }, old == nil
	end)
	local ok2, doc2 = Off.marketRead("e")
	expect(w2 == true and a2 == true and after2.list[1].id == "m" and ok2 == true and doc2.list[1].id == "m" and Off.isOffline() == true, "저장소가 없으면 그 서버의 메모리에서 올리고 읽는다")
	-- 라이브 서버(Studio가 아니다): 저장소를 못 열거나 못 읽어도 메모리 모드로 넘어가지 않는다 — 계정은 「읽지 못했다」로 알리고(빈 계정으로 다루지 않게) · 장부 · 이름 장부는 실패로 답한다(2026-10-18 검토)
	RESET()
	SERVICE("DataStoreService", {
		GetDataStore = function()
			error("잠깐 답하지 않는다")
		end,
		GetOrderedDataStore = function()
			error("잠깐 답하지 않는다")
		end,
	})
	SERVICE("RunService", { IsStudio = function() return false end, Heartbeat = { Connect = function() end } })
	local Live = req("ServerScriptService/server/lune/modules/store")
	local acct, failed = Live.loadAccount(55)
	expect(acct == nil and failed == true, "라이브: 계정을 읽지 못하면 「읽지 못했다」(빈 계정이 아니다)")
	local _, oldFailed = Live.loadOld(55)
	expect(oldFailed == true, "라이브: 예전 저장도 「읽지 못했다」")
	expect(Live.saveAccount(55, { v = 1 }) == false, "라이브: 저장하지 못했다고 답한다")
	expect(Live.marketUpdate("e", function() return { v = 1 } end) == false and (Live.marketRead("e")) == false, "라이브: 장부는 이 서버만의 메모리로 가지 않는다")
	expect(Live.nameOwner("달지기") == false and Live.claimName("달지기", 55) == nil, "라이브: 이름 장부를 못 쓰면 이름을 지을 수 없다")
	expect(Live.isOffline() == false, "라이브: 서버 전체가 메모리 모드로 넘어가지 않는다")
end

-- ================= 3) 서버의 흐름 =================
--  저장소는 가짜(계정 · 장부를 표에 둔다 — 서버를 새로 띄워도 남는다). 느리게 하거나(slow) 실패하게(fail) 할 수 있다.
local disk, boards = {}, {}
local names = {}
local fail = { save = false, update = false :: any, read = false }
local slow = 0
local log = {}
local function fakeStore()
	return {
		lock = function() return true end,
		unlock = function() end,
		loadAccount = function(id) return json(disk[id]) end,
		saveAccount = function(id, value)
			table.insert(log, "save:" .. id)
			if fail.save then
				return false
			end
			disk[id] = json(value)
			return true
		end,
		loadOld = function() return nil end,
		nameOwner = function(key) return names[key] end,
		claimName = function(key, id)
			if names[key] ~= nil and names[key] ~= id then
				return false
			end
			names[key] = id
			return true
		end,
		freeName = function(key) names[key] = nil end,
		rankSet = function() end,
		rankRaise = function() end,
		rankRemove = function() end,
		rankTop = function() return {} end,
		rankInfoSet = function() end,
		rankInfoGet = function() return nil end,
		rankInfoRemove = function() end,
		isOffline = function() return false end,
		marketRead = function(key)
			table.insert(log, "read:" .. key)
			if slow > 0 then
				task.wait(slow)
			end
			if fail.read then
				return false, nil
			end
			return true, json(boards[key])
		end,
		-- fail.update: "before" = 쓰지 못했다 · "after" = 썼는데 답이 오지 않았다
		marketUpdate = function(key, fn)
			table.insert(log, "update:" .. key)
			if slow > 0 then
				task.wait(slow)
			end
			if fail.update == "before" then
				return false, nil, nil, nil
			end
			local new, a, b = fn(json(boards[key]))
			if new ~= nil then
				boards[key] = json(new)
			end
			if fail.update == "after" then
				return false, nil, nil, nil
			end
			return true, a, b, json(boards[key])
		end,
	}
end
-- 서버 하나를 띄운다(앞의 서버는 그대로 꺼진 것 — 저장하지 않은 것은 사라진다). 시계는 이어 간다
local function server()
	local keep = clock.now
	RESET()
	clock.now = keep
	local handlers = {}
	local fired, published = {}, {} -- 보낸 것 · 다른 서버에 알린 것(「팔림」 — 2026-10-18)
	MOCK("ReplicatedStorage/shared/lune/net/net", {
		FireClient = function(name, player, ...)
			table.insert(fired, { name = name, player = player, args = { ... } })
		end,
		OnServer = function(name, fn)
			handlers[name] = fn
		end,
	})
	SERVICE("MessagingService", { PublishAsync = function(_, topic, data) table.insert(published, { topic = topic, data = data }) end, SubscribeAsync = function() end })
	local function signal()
		return { Connect = function() end }
	end
	SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
	SERVICE("RunService", { Heartbeat = signal() })
	SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
	MOCK("ServerScriptService/server/lune/modules/store", fakeStore())
	local sv = {
		World = req("ServerScriptService/server/lune/modules/world"),
		h = handlers,
		fired = fired,
		published = published,
		Market = req("ReplicatedStorage/shared/lune/sim/market"),
		Bag = req("ReplicatedStorage/shared/lune/sim/bag"),
		Items = req("ReplicatedStorage/shared/lune/sim/items"),
		SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated"),
		packets = req("ReplicatedStorage/shared/lune/net/packets"),
	}
	sv.World.start()
	return sv
end
-- 들어온다(캐릭터가 없으면 만든다) → 사람, 그 자리. 경매장은 어디서나 쓴다 — 들어온 자리(사당 안) 그대로 둔다
local function enter(sv, id: number, name: string, class: string)
	local p = { UserId = id, Name = "user" .. id, DisplayName = "user" .. id, attrs = {} }
	p.SetAttribute = function(self, k, v) self.attrs[k] = v end
	p.Kick = function() end
	local r = sv.h.Ready(p)
	local cid = r and r.select and r.select.chars[1] and r.select.chars[1].id
	if not cid then
		local made = sv.h.Chars(p, "create", name, class)
		expect(made ~= nil and made.ok == true, "캐릭터를 만든다 " .. name .. " " .. tostring(made and made.why))
		cid = made.id
	end
	expect(sv.h.Chars(p, "enter", cid) ~= nil, "캐릭터로 들어간다 " .. name)
	local s = sv.World.session(p)
	s.scene = "town" -- 경매장은 마을에서만(2026-10-21) — 새 캐릭터는 꿈(튜토리얼)에서 시작하므로 초승달 마을에 세운다
	return p, s
end
-- 가방을 비우고 달돈을 정한다
local function reset(sv, h, money: number)
	for i = 1, sv.Bag.size(h) do
		h.gear[i], h.use[i], h.etc[i] = false, false, false
	end
	h.money = money
end
-- 그 계정의 저장된 것에서: 달돈 · 판매한 수 · 받지 않은 구매품의 수 · 가방의 장비 수
local function saved(id: number)
	local a = disk[id]
	local hero = a and a.chars[1] and a.chars[1].hero
	local gear, sales, holds = 0, 0, 0
	for _, it in (hero and hero.bag and hero.bag.gear) or {} do
		if it then
			gear += 1
		end
	end
	for _, r in (a and a.market and a.market.list) or {} do
		if r.hold then
			holds += 1
		else
			sales += 1
		end
	end
	return { money = hero and hero.money, sales = sales, holds = holds, gear = gear }
end
-- 내 것에서 그 번호의 줄 · 그 조건의 첫 줄
local function mineOf(r, pred)
	for _, m in (r and r.mine) or {} do
		if pred(m) then
			return m
		end
	end
	return nil
end

do
	local sv = server()
	local Market, Bag, Items = sv.Market, sv.Bag, sv.Items
	local M, WHY, WORDS = Market.DATA, Market.WHY, Market.WORDS
	local DEP = M.deposit
	expect(sv.packets.Market ~= nil and sv.packets.Market.Kind == "Function" and sv.packets.Market.Direction == "ClientToServer" and sv.packets.Market.RateLimit.PerSecond <= 5, "경매장의 패킷(보내는 빠르기의 한도가 있다)")
	expect(sv.h.Market ~= nil, "서버가 받는다")
	-- 경매사 「금송」도 그대로 서 있다(말을 걸면 같은 창이 열린다)
	local there = false
	for _, n in sv.SCENES.scenes[M.scene].npcs do
		there = there or (n.id == M.npc and Items.data.NPCDO[n.id] == "auction")
	end
	expect(there, "경매사가 은달 항구에 서 있다")

	local pa, sa = enter(sv, 9101, "경매판매", "axion")
	local pb, sb = enter(sv, 9102, "경매구매", "riven")
	local pc, sc = enter(sv, 9103, "경매늦은", "mooni")
	local ha, hb, hc = sa.hero, sb.hero, sc.hero
	local potion = Items.potionFor(1)
	local other = Items.potionFor(30) -- 다른 소비 아이템(가방을 채울 때 쓴다)
	local quest
	for _, g in Items.data.GOODS do
		if g.quest and not quest then
			quest = g
		end
	end
	expect(other ~= nil and other.id ~= potion.id, "다른 물약이 있다")
	reset(sv, ha, 500)
	reset(sv, hb, 5000)
	reset(sv, hc, 5000)
	local hat = Items.make("hat", 10, 4)
	hat.star = 3
	local slotHat = Bag.add(ha, hat)
	expect(Bag.give(ha, potion.id, 20) == true and Bag.give(ha, quest.id, 1) == true, "팔 것을 넣는다")
	local slotPot, slotQuest
	for i = 1, Bag.size(ha) do
		if ha.use[i] and ha.use[i].item == potion.id then
			slotPot = i
		end
		if ha[quest.tab][i] and ha[quest.tab][i].item == quest.id then
			slotQuest = i
		end
	end

	-- ---- (가) 마을이면 어디서나 쓴다 · 막는 것들 ----
	--  2026-10-21 사용자 "경매장도 마을에서만 갈수있어야하구요": 새 캐릭터가 처음 서는 꿈(dream)은 마을이 아니다 → 셋 다 초승달 마을에 세운다
	sa.scene = "r1a1"
	expect(sv.h.Market(pa, "mine").why == WHY.town, "마을 밖(사냥터)에서는 쓰지 못한다")
	sa.scene = "dream"
	expect(sv.h.Market(pa, "mine").why == WHY.town, "꿈(튜토리얼)에서도 쓰지 못한다")
	for _, s in { sa, sb, sc } do
		s.scene = "town"
	end
	sa.shop = 1
	expect(sv.h.Market(pa, "mine").why == WHY.town, "달빛 상점 안에서는 쓰지 못한다")
	sa.shop = nil
	expect(sa.scene ~= M.scene, "(경매사가 없는 맵에 서 있다)")
	local r = sv.h.Market(pa, "mine")
	expect(r.ok == true and #r.mine == 0 and r.used == 0 and r.max == M.slots, "경매사 앞이 아니어도 마을이면 쓴다(메뉴에서 여는 창 — 메이플 옥션 방식)")
	sa.guest = true
	expect(sv.h.Market(pa, "mine").why == WHY.guest, "확인용 캐릭터는 쓰지 못한다")
	sa.guest = nil
	ha.alive = false
	expect(sv.h.Market(pa, "mine").why == WHY.dead, "쓰러진 채로는 쓰지 못한다")
	ha.alive = true
	expect(sv.h.Market(pa, "fly").ok == false and sv.h.Market(pa, "browse", "w_nobody").ok == false and sv.h.Market(pa, "browse", 3).ok == false, "모르는 일 · 없는 장부")
	for _, bad in { { 0, 24 }, { -5, 24 }, { 1.5, 24 }, { "100", 24 }, { M.priceMax + 1, 24 }, { 100, 12 }, { 100 }, "x" } do
		r = sv.h.Market(pa, "list", "gear", slotHat, 1, bad)
		expect(r.ok == false and r.why == WHY.price and ha.gear[slotHat] ~= false and ha.money == 500, "값 · 기간이 틀리면 올리지 않는다")
	end
	expect(sv.h.Market(pa, "list", "gear", slotHat, 1, nil).why == WHY.price, "값이 없으면 올리지 않는다")
	expect(sv.h.Market(pa, "list", "gear", 2, 1, { 100, 24 }).why == WHY.item and sv.h.Market(pa, "list", "gear", 999, 1, { 100, 24 }).why == WHY.item and sv.h.Market(pa, "list", "store", 1, 1, { 100, 24 }).why == WHY.item and sv.h.Market(pa, "list", "equip", "hat", 1, { 100, 24 }).why == WHY.item, "빈 칸 · 없는 칸 · 가방이 아닌 곳")
	expect(sv.h.Market(pa, "list", "use", slotPot, 21, { 100, 24 }).why == WHY.item and sv.h.Market(pa, "list", "use", slotPot, 0, { 100, 24 }).why == WHY.item and sv.h.Market(pa, "list", "use", slotPot, 2.5, { 100, 24 }).why == WHY.item, "가진 것보다 많이 · 0개 · 소수")
	r = sv.h.Market(pa, "list", quest.tab, slotQuest, 1, { 100, 24 })
	expect(r.ok == false and r.why == WHY.quest and Bag.count(ha, quest.id) == 1, "퀘스트의 물건은 못 올린다")
	ha.money = DEP - 1
	r = sv.h.Market(pa, "list", "gear", slotHat, 1, { 1000, 24 })
	expect(r.ok == false and r.why == WHY.deposit and ha.gear[slotHat] ~= false and ha.money == DEP - 1, "보증금이 모자라면 올리지 못한다")
	ha.money = 500
	eq(next(boards), nil, "아무것도 올라가지 않았다")
	eq(Market.count(sa.acct.market), 0, "맡긴 것도 없다")

	-- ---- (나) 올린다: 가방에서 빠지고 보증금을 낸다 · 계정을 먼저 저장한 뒤 장부에 적는다 ----
	table.clear(log)
	r = sv.h.Market(pa, "list", "gear", slotHat, 1, { 1000, 24 })
	expect(r.ok == true and r.used == 1 and typeof(r.msg) == "string" and #r.mine == 1 and r.mine[1].state == "selling" and r.mine[1].p == 1000 and r.mine[1].n == 1 and r.mine[1].left == 1, "장비를 올린다")
	local hatId = r.mine[1].id
	expect(ha.gear[slotHat] == false and ha.money == 500 - DEP, "가방에서 빠지고 보증금을 냈다")
	local iSave, iUpdate = table.find(log, "save:9101"), table.find(log, "update:a_hat")
	expect(iSave ~= nil and iUpdate ~= nil and iSave < iUpdate, "계정을 먼저 저장하고 그 뒤에 장부에 적는다")
	expect(saved(9101).sales == 1 and saved(9101).gear == 0 and saved(9101).money == 500 - DEP, "저장된 계정: 맡긴 것 하나 · 가방에는 없다 · 보증금이 빠졌다")
	local e = boards.a_hat.list[1]
	expect(#boards.a_hat.list == 1 and e.id == hatId and e.u == 9101 and e.sn == "경매판매" and e.p == 1000 and e.l == 1 and e.e - e.t == 24 * 3600 and e.it[1] == "hat" and e.it[3] == 4 and e.it[4] == 3, "장부의 줄: 판 사람 · 값 · 남은 수 · 기간 · 물건(성능 · 별 그대로)")
	r = sv.h.Market(pa, "list", "use", slotPot, 10, { 50, 48 })
	expect(r.ok == true and r.used == 2 and Bag.count(ha, potion.id) == 10 and ha.money == 500 - DEP * 2, "묶음에서 열 개를 개당 50에 올린다(48시간)")
	local potEntry = boards.u.list[1]
	local potId = potEntry.id
	expect(potEntry.it.g == potion.id and potEntry.it.n == 10 and potEntry.l == 10 and potEntry.p == 50 and potEntry.e - potEntry.t == 48 * 3600, "장부의 줄: 열 개 · 개당 50")
	-- ---- (다) 구경: 목록과 시세가 함께 온다 ----
	r = sv.h.Market(pb, "browse", "u")
	expect(r.ok == true and r.board == "u" and #r.rows == 1 and r.rows[1].id == potId and r.rows[1].mine == false and r.rows[1].sn == "경매판매" and r.rows[1].p == 50 and r.rows[1].l == 10 and r.rows[1].it.n == 10 and #r.trades == 0, "사는 사람이 본다(시세는 아직 비었다)")
	expect(sv.h.Market(pa, "browse", "u").rows[1].mine == true, "판 사람에게는 내 것으로 보인다")
	table.clear(log)
	sv.h.Market(pb, "browse", "a_suit")
	sv.h.Market(pc, "browse", "a_suit")
	sv.h.Market(pb, "browse", "a_suit", true)
	local reads = 0
	for _, l in log do
		if l == "read:a_suit" then
			reads += 1
		end
	end
	eq(reads, 1, "같은 분류를 잇달아 보면(새로 고침까지) 한 번만 읽는다")
	advance(M.cache + 1)
	sv.h.Market(pb, "browse", "a_suit")
	expect(table.find(log, "read:a_suit", 2) ~= nil, "시간이 지나면 다시 읽는다")

	-- ---- (라) 산다: 낱개로 · 산 것은 「완료」에 「낙찰」로 들어온다 ----
	hb.money = 149
	r = sv.h.Market(pb, "buy", "u", potId, 3, 50)
	expect(r.ok == false and r.why == WHY.money and hb.money == 149, "달돈이 모자라면 못 산다")
	hb.money = 5000
	expect(sv.h.Market(pb, "buy", "u", potId, 11, 50).why == WHY.count and hb.money == 5000, "남은 수보다 많이는 못 산다")
	expect(sv.h.Market(pb, "buy", "u", potId, 3, 49).why == WHY.changed and hb.money == 5000, "본 값과 다르면 사지 않는다(달돈은 그대로)")
	expect(sv.h.Market(pa, "buy", "u", potId, 1, 50).why == WHY.mine, "내가 올린 것은 못 산다")
	expect(sv.h.Market(pb, "buy", "u", "없는줄", 1, 50).why == WHY.gone and sv.h.Market(pb, "buy", "nowhere", potId, 1, 50).why == WHY.gone and sv.h.Market(pb, "buy", "u", potId, 0, 50).why == WHY.gone and sv.h.Market(pb, "buy", "u", potId, 1.5, 50).why == WHY.gone and sv.h.Market(pb, "buy", "u", potId, 1, "쉰").why == WHY.gone, "없는 줄 · 없는 장부 · 0개 · 소수 · 값이 아닌 것")
	table.clear(log)
	table.clear(sv.fired)
	r = sv.h.Market(pb, "buy", "u", potId, 3, 50)
	expect(r.ok == true and hb.money == 4850 and boards.u.list[1].l == 7 and r.rows[1].l == 7 and r.rows[1].it.n == 7, "셋을 샀다: 150을 치르고 장부에는 일곱이 남았다")
	-- 「팔림」(2026-10-18): 판 사람이 같은 서버에 있으면 그 사람에게 바로 — 다른 서버에는 알리지 않는다
	local soldMsg = nil
	for _, f in sv.fired do
		if f.name == "Sold" then
			soldMsg = f
		end
	end
	expect(soldMsg ~= nil and soldMsg.player == pa and soldMsg.args[1].n == 3 and type(soldMsg.args[1].name) == "string", "판 사람에게 「팔림」(셋)")
	expect(#sv.published == 0, "같은 서버면 다른 서버에 알리지 않는다")
	expect(Bag.count(hb, potion.id) == 0 and Market.holds(sb.acct.market) == 1 and Market.count(sb.acct.market) == 0, "산 것은 가방이 아니라 「완료」에 들어온다(판매한 수로는 세지 않는다)")
	local won = mineOf(r, function(m) return m.state == "hold" end)
	expect(won ~= nil and won.it.g == potion.id and won.it.n == 3 and won.p == 150, "「완료」의 「낙찰」: 물약 셋 · 치른 값 150")
	expect(#r.trades == 1 and r.trades[1].it.n == 3 and r.trades[1].p == 50, "시세에 남는다")
	expect(table.find(log, "save:9102") ~= nil and saved(9102).money == 4850 and saved(9102).holds == 1, "산 사람의 계정을 바로 저장한다")
	-- 수령
	for i = 1, Bag.size(hb) do
		hb.use[i] = { item = other.id, n = 1 }
	end
	expect(sv.h.Market(pb, "settle", won.id, "take").why == WHY.bag and Market.holds(sb.acct.market) == 1, "가방이 가득 차 있으면 수령하지 못한다(그대로 보관된다)")
	reset(sv, hb, 4850)
	r = sv.h.Market(pb, "settle", won.id, "take")
	expect(r.ok == true and Bag.count(hb, potion.id) == 3 and Market.holds(sb.acct.market) == 0 and #r.mine == 0, "「수령」: 가방으로 들어온다")
	expect(sv.h.Market(pb, "settle", won.id, "take").why == WHY.gone and Bag.count(hb, potion.id) == 3, "두 번 수령하지 못한다")
	-- 장비를 산다
	r = sv.h.Market(pb, "buy", "a_hat", hatId, 1, 1000)
	expect(r.ok == true and hb.money == 3850 and Bag.used(hb, "gear") == 0 and #r.rows == 0 and boards.a_hat.list[1].l == 0, "모자를 샀다: 목록에서 사라진다")
	won = mineOf(r, function(m) return m.state == "hold" end)
	r = sv.h.Market(pb, "settle", won.id, "take")
	local gotHat = hb.gear[1]
	expect(r.ok == true and gotHat and gotHat.slot == "hat" and gotHat.stage == 10 and gotHat.q == 4 and gotHat.star == 3 and typeof(gotHat.id) == "number", "수령한 것은 올린 그것이다(성능 · 별) — 가방의 새 번호가 붙는다")
	r = sv.h.Market(pc, "buy", "a_hat", hatId, 1, 1000)
	expect(r.ok == false and r.why == WHY.gone and hc.money == 5000, "늦은 사람은 못 산다(달돈은 그대로)")
	-- 받지 않은 구매품이 너무 많으면 더 사지 못한다
	local keepMax = M.holdMax
	M.holdMax = 1
	expect(sv.h.Market(pc, "buy", "u", potId, 1, 50).ok == true and sv.h.Market(pc, "buy", "u", potId, 1, 50).why == WHY.hold and hc.money == 4950 and boards.u.list[1].l == 6, "「완료」가 가득 차면 더 사지 못한다")
	M.holdMax = keepMax

	-- ---- (마) 대금 수령: 판매 중인 채로 팔린 만큼 · 다 팔린 것은 보증금까지 ----
	r = sv.h.Market(pa, "mine")
	local mHat = mineOf(r, function(m) return m.id == hatId end)
	local mPot = mineOf(r, function(m) return m.id == potId end)
	expect(mHat.state == "soldout" and mHat.due == 1 and mHat.pay == 950 and mHat.deposit == DEP, "모자: 다 팔렸다 — 받을 대금 950과 보증금")
	expect(mPot.state == "selling" and mPot.left == 6 and mPot.sold == 4 and mPot.due == 4 and mPot.pay == 190 and mPot.deposit == 0, "물약: 넷이 팔렸다 — 받을 대금 190(200에서 수수료 10)")
	local money0 = ha.money
	table.clear(log)
	r = sv.h.Market(pa, "settle", potId, "collect")
	expect(r.ok == true and ha.money == money0 + 190 and sa.acct.market.list[potId].got == 4 and boards.u.list[1].l == 6 and table.find(log, "update:u") == nil, "판매 중인 채로 대금만 받는다(장부는 고치지 않는다 — 받은 수는 계정에 적는다)")
	expect(sv.h.Market(pa, "settle", potId, "collect").why == WHY.nothing and ha.money == money0 + 190, "받을 것이 없으면 다시 받지 못한다")
	eq(sa.acct.ach.c.sold, 1, "업적 「첫 장사」: 판매 중에 대금을 받아도 센다")
	table.clear(log)
	r = sv.h.Market(pa, "settle", hatId, "collect")
	expect(r.ok == true and ha.money == money0 + 190 + 950 + DEP and r.used == 1 and string.find(r.msg, "950", 1, true) ~= nil, "다 팔린 것: 대금 950과 보증금을 받는다")
	eq(sa.acct.ach.c.sold, 2, "업적 「첫 장사」: 다 팔린 것의 대금을 받아도 센다(2026-10-26 — 전에는 세지 않아 「물건 10개 팔았는데 깨지지 않는다」)")
	iSave, iUpdate = table.find(log, "save:9101"), table.find(log, "update:a_hat")
	expect(iSave ~= nil and iUpdate ~= nil and iSave < iUpdate and #boards.a_hat.list == 0 and saved(9101).sales == 1, "계정을 저장한 뒤에 장부의 줄을 지운다")
	expect(sv.h.Market(pa, "settle", hatId, "collect").why == WHY.gone and ha.money == money0 + 190 + 950 + DEP, "두 번 받지 못한다")
	-- ---- (바) 판매 취소: 남은 것이 돌아온다 — 보증금은 돌려받지 못한다 ----
	money0 = ha.money
	r = sv.h.Market(pa, "settle", potId, "back")
	expect(r.ok == true and Bag.count(ha, potion.id) == 16 and #boards.u.list == 0 and r.used == 0 and ha.money == money0, "취소: 남은 여섯이 돌아온다(대금은 이미 받았다 · 보증금은 없다)")
	expect(sv.h.Market(pa, "settle", potId, "back").why == WHY.gone and Bag.count(ha, potion.id) == 16, "두 번 돌려받지 못한다")
	expect(sv.h.Market(pa, "settle", "남의줄", "back").why == WHY.gone and sv.h.Market(pa, "settle", 5, "back").why == WHY.gone, "없는 번호")
	-- 팔린 것의 대금을 받지 않은 채 취소하면: 남은 것과 대금을 함께 받는다
	reset(sv, ha, 1000)
	Bag.give(ha, potion.id, 10)
	r = sv.h.Market(pa, "list", "use", 1, 10, { 20, 24 })
	local mixId = r.mine[1].id
	reset(sv, hb, 1000)
	expect(sv.h.Market(pb, "buy", "u", mixId, 4, 20).ok == true, "넷이 팔린다")
	money0 = ha.money
	r = sv.h.Market(pa, "settle", mixId, "back")
	expect(r.ok == true and Bag.count(ha, potion.id) == 6 and ha.money == money0 + 76 and #boards.u.list == 0, "취소: 남은 여섯과 팔린 넷의 대금 76(80에서 수수료 4)을 받는다 — 보증금은 없다")
	expect(sv.h.Market(pa, "settle", mixId, "x").why == WHY.gone, "끝난 것은 없다")
	-- 모르는 일
	r = sv.h.Market(pa, "list", "use", 1, 1, { 20, 24 })
	expect(sv.h.Market(pa, "settle", r.mine[1].id, "뭔가").why == WHY.item and Market.count(sa.acct.market) == 1, "모르는 일은 하지 않는다")
	sv.h.Market(pa, "settle", r.mine[1].id, "back")

	-- ---- (사) 기간이 끝났다(미판매): 반환 · 재등록 ----
	reset(sv, ha, 1000)
	local s2 = Bag.add(ha, Items.make("suit", 10, 3))
	r = sv.h.Market(pa, "list", "gear", s2, 1, { 700, 24 })
	local suitId = r.mine[1].id
	expect(sv.h.Market(pa, "settle", suitId, "relist").why == WHY.gone, "판매 중인 것은 재등록하지 않는다")
	advance(25 * 3600)
	eq(#sv.h.Market(pb, "browse", "a_suit").rows, 0, "기간이 끝난 것은 목록에 없다")
	r = sv.h.Market(pb, "buy", "a_suit", suitId, 1, 700)
	expect(r.ok == false and r.why == WHY.gone and hb.money == 1000 - 80, "기간이 끝난 것은 못 산다")
	r = sv.h.Market(pa, "mine")
	expect(r.mine[1].state == "ended" and r.mine[1].left == 1 and r.mine[1].pay == 0 and r.mine[1].deposit == 0, "「미판매」로 보인다(보증금은 돌아오지 않는다)")
	for i = 1, Bag.size(ha) do
		ha.gear[i] = Items.make("glove", 1, 3)
	end
	expect(sv.h.Market(pa, "settle", suitId, "back").why == WHY.bag and boards.a_suit.list[1].c == nil, "가방이 가득 차면 반환받지 못한다(장부도 그대로)")
	reset(sv, ha, DEP - 1)
	expect(sv.h.Market(pa, "settle", suitId, "relist").why == WHY.deposit and boards.a_suit.list[1].c == nil, "보증금이 모자라면 재등록하지 못한다")
	ha.money = DEP + 5
	r = sv.h.Market(pa, "settle", suitId, "relist")
	expect(r.ok == true and ha.money == 5 and Bag.used(ha, "gear") == 0 and r.used == 1 and sa.acct.market.list[suitId] == nil, "재등록: 보증금을 다시 내고 같은 값으로 다시 올라간다")
	local again = r.mine[1]
	local newEntry = boards.a_suit.list[1]
	expect(#boards.a_suit.list == 1 and again.id ~= suitId and again.state == "selling" and newEntry.id == again.id and newEntry.p == 700 and newEntry.l == 1 and newEntry.e - newEntry.t == 24 * 3600, "새 줄: 같은 값 · 같은 기간(옛 줄은 지워졌다)")
	eq(#sv.h.Market(pb, "browse", "a_suit", true).rows, 1, "다시 목록에 보인다")
	advance(25 * 3600)
	reset(sv, ha, 0)
	r = sv.h.Market(pa, "settle", again.id, "back")
	expect(r.ok == true and Bag.used(ha, "gear") == 1 and ha.gear[1].slot == "suit" and #boards.a_suit.list == 0 and ha.money == 0, "반환: 물건이 돌아온다(보증금은 없다)")

	-- ---- (아) 열 건까지(받지 않은 구매품은 세지 않는다) ----
	reset(sv, ha, DEP * 20)
	Bag.give(ha, potion.id, 30)
	for i = 1, M.slots do
		expect(sv.h.Market(pa, "list", "use", 1, 1, { 10 + i, 24 }).ok == true, "올린다 " .. i)
	end
	r = sv.h.Market(pa, "list", "use", 1, 1, { 5, 24 })
	expect(r.ok == false and r.why == WHY.slots and r.used == M.slots and Bag.count(ha, potion.id) == 30 - M.slots, "열한 번째는 못 올린다")
	r = sv.h.Market(pb, "browse", "u", true)
	expect(#r.rows == M.slots and r.rows[1].p == 11 and r.rows[M.slots].p == 10 + M.slots, "싼 것부터 늘어선다")
	local cheap = r.rows[1]
	-- 올려 둔 것 하나를 내리고 다섯 개짜리 묶음을 올린다(같이 사 보는 데 쓴다)
	sv.h.Market(pa, "settle", r.rows[M.slots].id, "back")
	r = sv.h.Market(pa, "list", "use", 1, 5, { 7, 24 })
	expect(r.ok == true, "다섯 개를 개당 7에 올린다 " .. tostring(r.why))
	local fiveId = mineOf(r, function(m) return m.p == 7 end).id

	-- ---- (자) 두 사람이 같은 묶음을 같이 산다(저장소가 느리다): 남은 수만큼만 팔린다 ----
	slow = 1
	reset(sv, hb, 1000)
	reset(sv, hc, 1000)
	local rb, rc
	task.spawn(function()
		rb = sv.h.Market(pb, "buy", "u", fiveId, 4, 7)
	end)
	task.spawn(function()
		rc = sv.h.Market(pc, "buy", "u", fiveId, 3, 7)
	end)
	expect(sv.h.Market(pb, "mine").why == WHY.busy, "처리하는 동안에는 또 누르지 못한다")
	advance(10)
	expect(rb ~= nil and rc ~= nil and (rb.ok ~= rc.ok), "넷과 셋을 같이 사면(다섯뿐이다) 한 사람만 산다")
	local winner, loser, wq = if rb.ok then hb else hc, if rb.ok then hc else hb, if rb.ok then 4 else 3
	expect(winner.money == 1000 - 7 * wq and loser.money == 1000 and (if rb.ok then rc else rb).why == WHY.count, "산 사람만 치른다 — 못 산 사람의 달돈은 그대로(「남은 수보다 많다」)")
	eq(Market.entryById(boards.u, fiveId).l, 5 - wq, "장부에는 남은 수만큼만 남았다")
	expect(sv.h.Market(pb, "mine").ok == true, "끝나면 다시 쓸 수 있다")
	-- ---- (차) 사는 도중에 나간다: 산 것이 「완료」에 적힌 뒤에 저장하고 나간다 ----
	reset(sv, hc, 1000)
	local rl
	task.spawn(function()
		rl = sv.h.Market(pc, "buy", "u", cheap.id, 1, cheap.p)
	end)
	local left = false
	task.spawn(function()
		sv.World.removePlayer(pc)
		left = true
	end)
	expect(not left, "경매장의 일이 끝나기를 기다린다")
	advance(20)
	slow = 0
	expect(left and rl ~= nil and rl.ok == true, "일이 끝난 뒤에 나간다")
	expect(saved(9103).money == 1000 - cheap.p and saved(9103).holds >= 1, "저장된 계정: 값을 치렀고 산 것이 「완료」에 있다(사라지지 않았다)")

	-- ---- (카) 모두 받기 ----
	--  판 사람: 다 팔린 것 하나(cheap) · 일부가 팔린 것 하나(five) · 안 팔린 채 판매 중인 것들. 산 사람(pb): 낙찰 하나.
	advance(3)
	r = sv.h.Market(pa, "mine", true)
	local soldout = mineOf(r, function(m) return m.id == cheap.id end)
	local partial = mineOf(r, function(m) return m.id == fiveId end)
	expect(soldout.state == "soldout" and partial.state == "selling" and partial.due == wq, "다 팔린 것 하나 · 일부가 팔린 것 하나")
	money0 = ha.money
	local usedBefore = r.used
	r = sv.h.Market(pa, "all")
	local payAll = Market.payout(cheap.p) + DEP + Market.payout(7 * wq)
	expect(r.ok == true and ha.money == money0 + payAll and r.used == usedBefore - 1 and string.find(r.msg, "2", 1, true) ~= nil, "모두 받기: 다 팔린 것의 대금과 보증금 · 일부 팔린 것의 대금(판매 중인 것은 그대로 둔다)")
	expect(sa.acct.market.list[fiveId] ~= nil and sa.acct.market.list[fiveId].got == wq and Market.entryById(boards.u, fiveId) ~= nil, "일부 팔린 것은 계속 판매 중이다")
	r = sv.h.Market(pa, "all")
	expect(r.ok == false and r.why == WORDS.allNone and ha.money == money0 + payAll, "받을 것이 없으면 그렇게 알린다(두 번 받지 않는다)")
	-- 산 사람: 낙찰을 모두 받는다 — 가방이 가득 차면 남는다
	local holdsB = Market.holds(sb.acct.market)
	expect(holdsB >= 1, "산 사람의 「완료」에 낙찰이 있다")
	for i = 1, Bag.size(hb) do
		hb.use[i] = { item = other.id, n = 1 }
	end
	r = sv.h.Market(pb, "all")
	expect(r.ok == false and r.why == WHY.bag and Market.holds(sb.acct.market) == holdsB, "가방이 가득 차면 받지 못한다")
	reset(sv, hb, hb.money)
	r = sv.h.Market(pb, "all")
	expect(r.ok == true and Market.holds(sb.acct.market) == 0 and Bag.count(hb, potion.id) >= 1, "자리가 나면 모두 받는다")

	-- ---- (타) 저장하지 못했다 · 저장소가 답하지 않는다 ----
	--  (먼저 올려 둔 것을 모두 내린다)
	r = sv.h.Market(pa, "mine", true)
	for _, m in r.mine do
		sv.h.Market(pa, "settle", m.id, "back")
	end
	eq(Market.count(sa.acct.market), 0, "모두 내렸다")
	reset(sv, ha, 1000)
	local s3 = Bag.add(ha, Items.make("glove", 10, 5))
	-- 계정을 저장하지 못하면 올리지 않는다(가방으로 되돌리고 보증금도 돌려준다 — 장부에는 손대지 않는다)
	fail.save = true
	table.clear(log)
	r = sv.h.Market(pa, "list", "gear", s3, 1, { 400, 24 })
	fail.save = false
	expect(r.ok == false and r.why == WHY.save and Bag.used(ha, "gear") == 1 and ha.money == 1000 and Market.count(sa.acct.market) == 0 and table.find(log, "update:a_glove") == nil and boards.a_glove == nil, "저장하지 못하면 올리지 않는다")
	-- 장부에 쓰지 못했고(적히지 않았다) 답도 없다: 맡긴 채로 둔다 → 「완료」에서 돌려받는다(보증금도). 물건은 하나뿐이다
	fail.update = "before"
	r = sv.h.Market(pa, "list", "gear", 1, 1, { 400, 24 })
	fail.update = false
	expect(r.ok == false and r.why == WORDS.unsure and Bag.used(ha, "gear") == 0 and ha.money == 1000 - DEP and Market.count(sa.acct.market) == 1 and boards.a_glove == nil, "적혔는지 모르면 되돌리지 않는다(둘이 될 수 있다) — 맡긴 채로 둔다")
	local stuck = r.mine[1]
	expect(stuck ~= nil and stuck.state == "back" and stuck.left == 1 and stuck.deposit == DEP, "장부에 줄이 없으니 돌려받을 것으로 보인다(보증금도)")
	r = sv.h.Market(pa, "settle", stuck.id, "back")
	expect(r.ok == true and Bag.used(ha, "gear") == 1 and ha.gear[1].q == 5 and ha.money == 1000 and Market.count(sa.acct.market) == 0, "반환하면 그 물건과 보증금이 돌아온다(하나뿐이다)")
	-- 장부에 적혔는데 답이 없다: 맡긴 채로 둔다 → 판매 중으로 보이고, 팔리면 대금을 받는다. 물건은 하나뿐이다
	fail.update = "after"
	r = sv.h.Market(pa, "list", "gear", 1, 1, { 400, 24 })
	fail.update = false
	expect(r.ok == false and r.why == WORDS.unsure and Bag.used(ha, "gear") == 0 and #boards.a_glove.list == 1, "적혔는데 답이 없었다: 가방으로 되돌리지 않는다")
	local gloveId = boards.a_glove.list[1].id
	r = sv.h.Market(pa, "mine", true)
	expect(mineOf(r, function(m) return m.id == gloveId end).state == "selling", "판매 중으로 보인다")
	-- 살 때 적혔는데 답이 없다: 다시 읽어 이 구매가 적혀 있으면 산 것이다(달돈을 돌려받고 물건도 사라지는 일이 없다)
	reset(sv, hb, 1000)
	fail.update = "after"
	r = sv.h.Market(pb, "buy", "a_glove", gloveId, 1, 400)
	fail.update = false
	expect(r.ok == true and hb.money == 600 and Market.holds(sb.acct.market) == 1 and boards.a_glove.list[1].l == 0, "적혔는데 답이 없어도, 다시 읽어 내가 산 것이면 받는다(한 번만 팔렸다)")
	-- 살 때 쓰지 못했다(적히지 않았다): 달돈을 돌려준다 · 줄은 그대로
	reset(sv, ha, 1000)
	local s4 = Bag.add(ha, Items.make("shoes", 10, 3))
	r = sv.h.Market(pa, "list", "gear", s4, 1, { 250, 24 })
	expect(r.ok == true, "신발을 올린다 " .. tostring(r.why))
	local shoesId = boards.a_shoes.list[1].id
	local holdsNow = Market.holds(sb.acct.market)
	fail.update = "before"
	r = sv.h.Market(pb, "buy", "a_shoes", shoesId, 1, 250)
	fail.update = false
	expect(r.ok == false and r.why == WHY.off and hb.money == 600 and Market.holds(sb.acct.market) == holdsNow and boards.a_shoes.list[1].l == 1, "쓰지 못했으면 달돈을 돌려준다 · 줄은 판매 중 그대로")
	-- 취소할 때 답이 없다: 아무것도 주지 않는다(맡긴 것은 그대로 — 다음에 다시 견준다)
	fail.update = "before"
	r = sv.h.Market(pa, "settle", shoesId, "back")
	fail.update = false
	expect(r.ok == false and r.why == WHY.off and Bag.used(ha, "gear") == 0 and sa.acct.market.list[shoesId] ~= nil, "취소가 안 됐으면 물건을 주지 않는다")
	fail.read = true
	advance(M.cache + 1)
	expect(sv.h.Market(pb, "browse", "a_shoes").why == WHY.off, "장부를 읽지 못하면 그렇게 알린다")
	r = sv.h.Market(pa, "mine", true)
	expect(r.ok == true and #r.mine >= 1, "읽지 못해도 내 것은 보인다(그대로 둔다)")
	fail.read = false
	-- 처리하다 오류가 나도 다음에 쓸 수 있다(busy가 풀린다)
	local keepRows = Market.rows
	Market.rows = function()
		error("일부러 낸 오류")
	end
	r = sv.h.Market(pb, "browse", "a_shoes", true)
	Market.rows = keepRows
	expect(r.ok == false and r.why == WHY.off and sb.marketBusy == nil, "오류가 나도 막힌 채로 남지 않는다")
	expect(sv.h.Market(pb, "browse", "a_shoes").ok == true, "다음에는 된다")
	-- 다 팔린 것의 대금을 받을 때 계정을 저장하지 못했다 → 그 뒤의 저장이 됐다: 대금은 한 번만 받는다(장부에 남은 줄은 보관 기간이 지나면 지워진다)
	reset(sv, ha, 1000)
	Bag.give(ha, potion.id, 6)
	r = sv.h.Market(pa, "list", "use", 1, 3, { 200, 24 })
	expect(r.ok == true, "물약 셋을 개당 200에 올린다 " .. tostring(r.why))
	local lateId = mineOf(r, function(m) return m.p == 200 end).id
	reset(sv, hb, 1000)
	expect(sv.h.Market(pb, "buy", "u", lateId, 3, 200).ok == true, "다 팔린다")
	money0 = ha.money
	fail.save = true
	r = sv.h.Market(pa, "settle", lateId, "collect")
	fail.save = false
	expect(r.ok == true and ha.money == money0 + 570 + DEP and Market.entryById(boards.u, lateId) ~= nil, "저장하지 못했어도 대금은 받는다 — 장부의 줄은 남긴다")
	expect(sv.h.Market(pa, "list", "use", 1, 1, { 77, 24 }).ok == true and saved(9101).money == money0 + 570, "그 뒤의 저장이 됐다(대금이 저장됐다)")
	r = sv.h.Market(pa, "settle", lateId, "collect")
	expect(r.ok == false and r.why == WHY.gone and ha.money == money0 + 570, "남은 줄로 다시 받지 못한다")
	-- 다 팔린 장갑의 대금을 받을 때 계정을 저장하지 못했다 → 서버가 그대로 꺼진다: 장부의 줄을 지우지 않았으니 다음에 받는다(한 번만). 판 사람이 이 서버에서 하는 마지막 일이다
	local moneyDisk = saved(9101).money
	fail.save = true
	r = sv.h.Market(pa, "settle", gloveId, "collect")
	fail.save = false
	expect(r.ok == true and #boards.a_glove.list == 1 and boards.a_glove.list[1].l == 0, "저장하지 못했으면 장부의 줄을 남긴다")
	expect(saved(9101).money == moneyDisk and saved(9101).sales >= 2, "저장된 계정은 받기 전 그대로다(대금 없음 · 맡긴 것 있음)")

	-- ---- (파) 서버가 바뀐다: 올린 서버 · 산 서버 · 받는 서버가 달라도 된다 ----
	--  지금: 신발(250)이 판매 중, 장갑은 다 팔렸다(대금은 저장하지 못한 채 — 저장된 계정에는 맡긴 것이 남아 있다).
	sv.World.removePlayer(pb) -- 산 사람은 저장하고 나간다
	local sv2 = server() -- 판 사람의 서버는 그대로 꺼졌다(저장하지 않은 것은 사라진다)
	local pb2, sb2 = enter(sv2, 9102, "경매구매", "riven")
	local hb2 = sb2.hero
	local moneyB = hb2.money
	r = sv2.h.Market(pb2, "browse", "a_shoes")
	expect(r.ok == true and #r.rows == 1 and r.rows[1].id == shoesId, "다른 서버에서도 올린 것이 보인다")
	r = sv2.h.Market(pb2, "buy", "a_shoes", shoesId, 1, 250)
	expect(r.ok == true and hb2.money == moneyB - 250, "다른 서버에서 산다")
	local pub = sv2.published[#sv2.published]
	expect(pub ~= nil and pub.topic == "LuneSold" and pub.data.n == 1 and type(pub.data.u) == "number" and pub.data.u ~= pb2.UserId, "판 사람이 이 서버에 없으면 다른 서버들에 「팔림」을 알린다(MessagingService)")
	local holdShoes = mineOf(r, function(m) return m.state == "hold" and m.it[1] == "shoes" end)
	expect(holdShoes ~= nil, "「완료」에 신발이 있다")
	sv2.World.removePlayer(pb2)
	local sv3 = server()
	local pb3, sb3 = enter(sv3, 9102, "경매구매", "riven")
	for i = 1, sv3.Bag.size(sb3.hero) do
		sb3.hero.gear[i] = false
	end
	r = sv3.h.Market(pb3, "settle", holdShoes.id, "take")
	expect(r.ok == true and sv3.Bag.used(sb3.hero, "gear") == 1 and sb3.hero.gear[1].slot == "shoes", "또 다른 서버에서 수령한다")
	local pa3, sa3 = enter(sv3, 9101, "경매판매", "axion")
	local ha3 = sa3.hero
	money0 = ha3.money
	eq(money0, moneyDisk, "판 사람의 달돈은 저장된 그대로다(받기 전)")
	r = sv3.h.Market(pa3, "mine")
	local mShoes = mineOf(r, function(m) return m.id == shoesId end)
	local mGlove = mineOf(r, function(m) return m.id == gloveId end)
	expect(mShoes ~= nil and mShoes.state == "soldout" and mShoes.pay == sv3.Market.payout(250), "판 사람이 다시 들어오면 「판매 완료」로 보인다")
	expect(mGlove ~= nil and mGlove.state == "soldout" and mGlove.pay == sv3.Market.payout(400), "저장하지 못한 채 꺼졌던 장갑의 대금도 그대로 남아 있다 — 사라지지 않았다")
	r = sv3.h.Market(pa3, "settle", shoesId, "collect")
	expect(r.ok == true and ha3.money == money0 + sv3.Market.payout(250) + DEP, "다른 서버에서 대금과 보증금을 받는다")
	r = sv3.h.Market(pa3, "settle", gloveId, "collect")
	expect(r.ok == true and ha3.money == money0 + sv3.Market.payout(250) + sv3.Market.payout(400) + DEP * 2, "장갑의 대금도 한 번 받는다")
	expect(sv3.h.Market(pa3, "settle", gloveId, "collect").ok == false and sv3.h.Market(pa3, "settle", shoesId, "collect").ok == false, "두 번은 받지 못한다")
	expect(#boards.a_shoes.list == 0 and #boards.a_glove.list == 0, "받은 줄은 장부에서 지워진다")
	-- 일부만 팔린 묶음: 판 서버 · 산 서버가 달라도 팔린 만큼만 받는다
	for i = 1, sv3.Bag.size(ha3) do
		ha3.use[i] = false
	end
	sv3.Bag.give(ha3, potion.id, 10)
	r = sv3.h.Market(pa3, "mine", true)
	for _, m in r.mine do
		sv3.h.Market(pa3, "settle", m.id, "back")
	end
	for i = 1, sv3.Bag.size(ha3) do
		ha3.use[i] = false
	end
	sv3.Bag.give(ha3, potion.id, 10)
	ha3.money = 1000
	r = sv3.h.Market(pa3, "list", "use", 1, 10, { 30, 48 })
	local tenId = r.mine[1].id
	sb3.hero.money = 1000
	expect(sv3.h.Market(pb3, "buy", "u", tenId, 4, 30).ok == true, "넷이 팔린다")
	sv3.World.removePlayer(pa3)
	sv3.World.removePlayer(pb3)
	local sv4 = server()
	local pa4, sa4 = enter(sv4, 9101, "경매판매", "axion")
	local ha4 = sa4.hero
	money0 = ha4.money
	r = sv4.h.Market(pa4, "settle", tenId, "collect")
	expect(r.ok == true and ha4.money == money0 + sv4.Market.payout(120) and sa4.acct.market.list[tenId].got == 4, "다른 서버에서 팔린 넷의 대금을 받는다")
	sv4.World.removePlayer(pa4) -- 받은 수(got)가 저장된다
	local sv5 = server()
	local pa5, sa5 = enter(sv5, 9101, "경매판매", "axion")
	local pb5, sb5 = enter(sv5, 9102, "경매구매", "riven")
	local ha5 = sa5.hero
	expect(sv5.h.Market(pa5, "settle", tenId, "collect").why == sv5.Market.WHY.nothing, "받은 것은 서버가 바뀌어도 다시 받지 못한다")
	sb5.hero.money = 1000
	expect(sv5.h.Market(pb5, "buy", "u", tenId, 6, 30).ok == true, "남은 여섯이 팔린다")
	money0 = ha5.money
	r = sv5.h.Market(pa5, "settle", tenId, "collect")
	expect(r.ok == true and ha5.money == money0 + sv5.Market.payout(180) + DEP and sa5.acct.market.list[tenId] == nil, "다 팔리면 남은 여섯의 대금과 보증금을 받는다")
	-- 올리다가 서버가 꺼졌다(계정은 저장했고 장부에는 아직 적지 못했다): 다음에 들어와 돌려받는다(보증금도)
	for i = 1, sv5.Bag.size(ha5) do
		ha5.gear[i] = false
	end
	ha5.money = 1000
	local s5 = sv5.Bag.add(ha5, sv5.Items.make("hat", 20, 5))
	fail.update = "before"
	r = sv5.h.Market(pa5, "list", "gear", s5, 1, { 9000, 48 })
	fail.update = false
	expect(r.ok == false, "장부에 적지 못한 채")
	local sv6 = server() -- 그대로 꺼졌다
	local pa6, sa6 = enter(sv6, 9101, "경매판매", "axion")
	local ha6 = sa6.hero
	expect(sv6.Bag.used(ha6, "gear") == 0 and ha6.money == 1000 - DEP, "가방에는 없다(맡겼다) · 보증금이 빠져 있다")
	r = sv6.h.Market(pa6, "mine")
	local lost = mineOf(r, function(m) return m.it[1] == "hat" and m.it[2] == 20 end)
	expect(lost ~= nil and lost.state == "back", "맡긴 것으로 남아 있다 — 돌려받을 것으로 보인다")
	r = sv6.h.Market(pa6, "settle", lost.id, "back")
	expect(r.ok == true and sv6.Bag.used(ha6, "gear") == 1 and ha6.gear[1].stage == 20 and ha6.gear[1].q == 5 and ha6.money == 1000, "반환하면 물건과 보증금이 돌아온다 — 사라지지 않았다")
	-- 줄을 닫았는데(취소) 계정을 저장하지 못한 채 서버가 꺼졌다: 닫힌 줄과 맡긴 것이 남아 다음에 한 번만 돌려받는다
	r = sv6.h.Market(pa6, "list", "gear", 1, 1, { 9000, 24 })
	local closeId = r.mine[1].id
	expect(r.ok == true and saved(9101).sales == 1 and saved(9101).gear == 0, "다시 올린다(저장됐다)")
	fail.save = true
	r = sv6.h.Market(pa6, "settle", closeId, "back")
	fail.save = false
	expect(r.ok == true and sv6.Bag.used(ha6, "gear") == 1 and boards.a_hat.list[1].c == 1 and saved(9101).gear == 0 and saved(9101).sales == 1, "취소했지만 저장하지 못했다: 장부의 줄은 닫힌 채 남는다(저장된 계정에는 맡긴 것이 그대로)")
	local sv7 = server() -- 그대로 꺼졌다
	local pa7, sa7 = enter(sv7, 9101, "경매판매", "axion")
	local ha7 = sa7.hero
	eq(sv7.Bag.used(ha7, "gear"), 0, "가방에는 없다(저장되지 못했다)")
	r = sv7.h.Market(pa7, "mine")
	expect(r.mine[1].id == closeId and r.mine[1].state == "ended" and r.mine[1].left == 1, "닫힌 줄이 「미판매」로 보인다")
	local pb7, sb7 = enter(sv7, 9102, "경매구매", "riven")
	sb7.hero.money = 99999
	expect(sv7.h.Market(pb7, "buy", "a_hat", closeId, 1, 9000).why == sv7.Market.WHY.gone, "닫힌 줄은 아무도 못 산다")
	r = sv7.h.Market(pa7, "settle", closeId, "back")
	expect(r.ok == true and sv7.Bag.used(ha7, "gear") == 1 and #boards.a_hat.list == 0 and saved(9101).gear == 1 and saved(9101).sales == 0, "다시 반환하면 한 번만 돌아온다")
	expect(sv7.h.Market(pa7, "settle", closeId, "back").why == sv7.Market.WHY.gone and sv7.Bag.used(ha7, "gear") == 1, "두 번은 없다")
	-- 보관 기간이 지나면 사라진다
	ha7.money = 1000
	r = sv7.h.Market(pa7, "list", "gear", 1, 1, { 9000, 24 })
	expect(r.ok == true, "다시 올린다")
	advance(24 * 3600 + sv7.Market.KEEP + 10)
	r = sv7.h.Market(pa7, "mine", true)
	expect(#r.mine == 0 and r.used == 0, "보관 기간(1년)이 지난 것은 사라진다")
	-- 다른 캐릭터로 바꿔 들어가도 맡긴 것은 계정의 것이다
	sv7.Bag.give(ha7, potion.id, 2)
	r = sv7.h.Market(pa7, "list", "use", 1, 2, { 9, 24 })
	expect(r.ok == true and r.used == 1, "하나를 올려 둔다")
	sv7.h.Chars(pa7, "leave")
	local made = sv7.h.Chars(pa7, "create", "경매둘째", "reaper")
	expect(made ~= nil and made.ok == true and sv7.h.Chars(pa7, "enter", made.id) ~= nil, "둘째 캐릭터")
	eq(sv7.h.Market(pa7, "mine").used, 1, "같은 계정의 다른 캐릭터에게도 같은 것이 보인다")
end

-- ================= 4) 창에 적는 글 · 폭 =================
do
	RESET()
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
	local L = req("ReplicatedStorage/shared/lune/ui/layout")
	local Market = req("ReplicatedStorage/shared/lune/sim/market")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local View = req("ReplicatedStorage/shared/lune/ui/auctionView")
	local Format = req("ReplicatedStorage/shared/lune/ui/format")
	local pixelText = req("Client/ui/pixelText")
	pixelText.Register("small", KIT.font.small, {})
	pixelText.Register("body", KIT.font.body, {})
	local function width(text: string, font: string?): number
		return (pixelText.Measure(text, font or "small"))
	end
	local S, M, W = L.AUCTION, Market.DATA, Market.WORDS
	local NOW = 1700000000
	-- 창: 공방에 있고, 메뉴 · 키로 어디서나 연다(메이플 옥션 방식) · 레벨의 문턱이 없다 · 가장 작은 화면 틀에 들어간다
	local win
	local keys = {}
	for _, w in UI.windows do
		if w.id == "auction" then
			win = w
		end
		if w.key then
			keys[w.key] = (keys[w.key] or 0) + 1
		end
	end
	expect(win ~= nil and typeof(win.key) == "string" and win.from == 1 and win.name == W.title and keys[win.key] == 1, "경매장 창: 여는 키가 있고(다른 창과 겹치지 않는다) 레벨의 문턱이 없다")
	expect(S.w + L.WIN.pad * 2 <= UI.grid.min.w - L.WIN.edge * 2 and S.h + L.WIN.head + L.WIN.foot + L.WIN.top <= UI.grid.min.h, "가장 작은 화면 틀(스마트폰)에 들어간다")
	-- 단추에 「~다」로 끝나는 말을 쓰지 않는다(사용자 2026-10-13)
	for _, word in { W.buy, W.sell, W.register, W.back, W.cancel, W.collect, W.take, W.giveBack, W.relist, W.all, W.refresh, W.sortPrice, W.sortTime } do
		expect(typeof(word) == "string" and string.sub(word, -3) ~= "다", "단추의 글 " .. tostring(word))
	end
	-- 탭 · 분류 · 단추의 글이 제 칸에 든다
	local tabsW = 0
	for _, t in W.tabs do
		tabsW += width(t) + 16
	end
	expect(#W.tabs == 4 and #View.TABS == 4 and tabsW <= S.w - S.purseW - 8 - S.slotsW, "탭 넷이 지갑 · 판매한 수와 겹치지 않는다")
	expect(width(View.slots(M.slots, M.slots)) <= S.slotsW, "「판매 10 / 10」")
	expect(width("999.9억") <= S.purseW - 21, "지갑의 달돈")
	local cats = View.cats()
	for _, c in cats do
		expect(width(c.name) <= S.catW - 6, "분류의 이름 " .. c.name)
	end
	expect(#cats * (S.catW + S.catGap) + S.classW <= S.w - S.refreshW - 4, "분류 단추 · 직업 단추 · 새로 고침이 한 줄에 든다")
	for _, id in CLASSES.order do
		expect(width(View.className(id)) <= S.classW - 6, "직업의 이름 " .. View.className(id))
	end
	local class = CLASSES.order[1]
	local seenClass = {}
	for _ = 1, #CLASSES.order do
		seenClass[class] = true
		class = View.nextClass(class)
	end
	expect(class == CLASSES.order[1] and seenClass.salamander and seenClass.mooni, "직업 단추는 다섯 직업을 돈다")
	expect(width(W.refresh) <= S.refreshW - 6, "새로 고침")
	for _, mode in View.SORTS do
		expect(width(View.sortName(mode)) <= S.sortW - 6, "차례 단추 " .. View.sortName(mode))
	end
	expect(S.searchW + 8 + S.sortW + 8 + width(Format.fill(W.rows, { n = M.show })) <= S.w, "찾는 칸 · 차례 단추 · 「60건」이 한 줄에 든다")
	for _, word in { W.buy, W.cancel, W.collect, W.take, W.giveBack, W.relist, W.selling } do
		expect(width(word) <= S.btnW - 6, "줄의 단추 " .. word)
	end
	expect(width(W.buy) <= S.askW - 6 and width(W.cancel) <= S.askW - 6, "묻는 줄의 단추")
	expect(width(W.sell) <= S.sellW - 6 and width(W.back) <= S.backW - 6 and width(W.all) <= S.allW - 6, "「판매 등록」 · 「목록」 · 「모두 받기」")
	expect(width(W.register, "body") <= S.registerW - 6, "「등록」")
	for _, hrs in M.hours do
		expect(width(Format.fill(W.hours, { n = hrs })) <= S.hourW - 6, "기간의 단추")
	end
	local formW = S.w - S.formX - S.labelW
	expect(#M.hours * (S.hourW + 6) <= formW, "기간의 단추들이 양식에 든다")
	for _, label in { W.count, W.price, W.unitPrice, W.period, Format.fill(W.fee, { pct = M.fee }), W.deposit, W.get } do
		expect(width(label) <= S.labelW - 4, "양식의 이름표 " .. label)
	end
	expect(S.qtyField + 6 + S.ofW <= formW and S.priceField + 6 + 18 <= formW, "수량을 적는 칸과 「/ 20개」 · 값을 적는 칸과 달돈 그림이 양식에 든다")
	expect(width(View.of(9999)) <= S.ofW and width(W.count) <= S.qtyLabelW, "「/ 9999개」 · 「수량」이 제 칸에 든다")
	expect(width(Format.comma(M.priceMax)) <= S.priceW and width(W.unit) <= S.priceW, "가장 큰 값 · 「개당」이 값의 칸에 든다")
	expect(width(Format.fill(W.total, { n = Format.comma(M.priceMax * 999) })) <= formW, "합계")
	expect(width(Format.fill(W.left, { n = 48 })) <= S.leftW and width(Format.fill(W.leftMin, { n = 59 })) <= S.leftW, "남은 시간")
	expect(width(Format.fill(W.agoMin, { n = 59 })) <= S.leftW and width(Format.fill(W.agoHour, { n = 23 })) <= S.leftW and width(Format.fill(W.agoDay, { n = M.logDays })) <= S.leftW, "언제 거래됐나")
	expect(width("가나다라마바") <= S.sellerW and width("시험 판매자") <= S.sellerW, "판매자의 이름(여섯 글자)")
	local depositNote = Format.fill(W.depositNote, { n = Format.comma(M.deposit) })
	expect(width(depositNote) <= S.w and width(depositNote) <= (S.w - S.formX) * 2, "보증금의 알림(판매 탭 아래 한 줄 · 양식 아래 두 줄)")
	expect(width(Format.fill(W.keep, { n = M.keepDays })) <= S.w - S.allW - 8, "보관 기간의 알림이 「모두 받기」와 겹치지 않는다")
	for key, text in W.why do
		expect(width(text) <= S.w, "까닭의 글 " .. key)
	end
	for _, text in { W.empty, W.sellEmpty, W.doneEmpty, W.logEmpty, W.wait, W.lost, W.kept, W.unsure, W.allNone, Format.fill(W.allDone, { n = 110 }), Format.fill(W.allPart, { n = 110 }) } do
		expect(width(text) <= S.w, "알림의 글 " .. text)
	end
	expect(width(W.pick) <= S.listW - S.backW - 8 and width(W.none) <= S.listW - S.backW - 8, "등록 화면의 머리글이 「목록」과 겹치지 않는다")
	-- 줄의 폭: 구매 = [그림] 이름 · 판매자 · 남은 시간 · [달돈] 값 · 단추
	local cw = S.w - S.bar - 2
	local nameW = cw - S.btnW - 8 - S.priceW - 19 - 6 - S.leftW - 6 - S.sellerW - 6 - (S.icon + 6)
	expect(nameW >= 180, "구매 줄의 이름 칸 " .. nameW)
	local me = { level = 30, class = "axion" }
	local longest, longestSub, longName = 0, 0, ""
	for _, slot in Items.data.GEAR do
		for _, stage in { 1, 10, 20, 30, 150 } do
			for q = 1, #Items.data.QUALITY do
				local it = Items.make(slot, stage, q, "salamander")
				it.star = math.min(22, Items.starCap(stage))
				if width(View.name(it)) > longest then
					longest, longName = width(View.name(it)), View.name(it)
				end
				for _, viewer in { me, { level = 1, class = "axion" }, { level = 150, class = "salamander" } } do
					longestSub = math.max(longestSub, width((View.sub(it, viewer, nil))))
					local worn = Items.make(slot, stage, 5, "salamander")
					worn.star = it.star
					longestSub = math.max(longestSub, width((View.sub(it, viewer, worn))))
				end
			end
		end
	end
	expect(longest <= nameW, ("장비의 이름이 줄에 든다 %d / %d"):format(longest, nameW))
	expect(longestSub <= nameW, ("이름 아래의 한 줄이 줄에 든다 %d / %d"):format(longestSub, nameW))
	local bagRowW = S.listW - S.bar - 2 - (S.icon + 6)
	expect(longest <= bagRowW and longestSub <= bagRowW, "등록 화면의 왼쪽 목록에도 든다")
	local stackLong, bareLong = 0, ""
	for _, g in Items.data.GOODS do
		stackLong = math.max(stackLong, width(View.name({ item = g.id, n = g.stack })))
		if width(g.name) > width(bareLong) then
			bareLong = g.name
		end
	end
	expect(stackLong <= nameW and stackLong <= bagRowW, "묶음의 이름이 줄에 든다 " .. stackLong)
	-- 묻는 줄: 장비는 넓게, 묶음은 수를 고치는 단추의 왼쪽에
	local yesX = S.w - S.askW * 2 - 6
	local gearAsk = Format.fill(W.ask, { name = longName, price = Format.comma(M.priceMax) })
	expect(width(gearAsk) <= yesX - 8, ("살 때 묻는 글(장비) %d / %d"):format(width(gearAsk), yesX - 8))
	local stackAsk = Format.fill(W.askSum, { name = bareLong, price = Format.comma(9999999 * 999) })
	local qtyLabelX = yesX - 8 - S.ofW - 4 - S.qtyField - 4 - S.qtyLabelW
	expect(width(stackAsk) <= qtyLabelX - 8, ("살 때 묻는 글(묶음 — 가장 긴 이름 · 합계 9,999,999 x 999) %d / %d"):format(width(stackAsk), qtyLabelX - 8))
	expect(width(View.stock(9999)) <= nameW, "「남은 수량 9999개」가 줄에 든다")
	-- 판매 · 완료의 줄
	local sellNameW = cw - S.btnW - 8 - S.priceW - 19 - 8 - (S.icon + 6)
	local doneNameW = cw - S.btnW * 2 - 4 - 8 - S.priceW - 19 - 8 - (S.icon + 6)
	expect(longest <= doneNameW and stackLong <= doneNameW and doneNameW >= 200, "완료 줄의 이름 칸(단추 둘 옆) " .. doneNameW)
	expect(width(Format.fill(W.left, { n = 48 }) .. " · " .. Format.fill(W.remain, { n = 999, max = 999 })) <= sellNameW, "판매 중인 줄의 아래 글")
	expect(width(W.unsold .. " · " .. Format.fill(W.units, { n = 999 }) .. " · " .. Format.fill(W.soldN, { n = 999 })) <= doneNameW and width(W.sold .. " · " .. Format.fill(W.soldN, { n = 999 })) <= doneNameW, "완료 줄의 아래 글")
	-- 알림(이름이 들어가는 것): 가장 긴 이름으로
	for _, text in { Format.fill(W.listed, { name = longName }), Format.fill(W.bought, { name = longName }), Format.fill(W.returned, { name = longName }), Format.fill(W.taken, { name = longName }), Format.fill(W.relisted, { name = longName }),
		Format.fill(W.paid, { n = Format.comma(M.priceMax), fee = Format.comma(M.priceMax) }) .. Format.fill(W.paidDeposit, { n = Format.comma(M.deposit) }) } do
		expect(width(text) <= S.w, ("알림이 한 줄에 든다 %d — %s"):format(width(text), text))
	end
	-- 글
	local hat = Items.make("hat", 10, 4)
	hat.star = 3
	eq(View.name(hat), Items.name(hat), "장비의 이름: 이름만(2026-10-15 — 별은 아래 줄의 ★와 상세 판의 이름 위)")
	eq(View.tone(hat), "tier3", "장비의 이름 색 = 성능 단")
	local potion = Items.potionFor(1)
	eq(View.name({ item = potion.id, n = 5 }), potion.name .. " x5", "묶음의 이름: 이름 x수")
	eq(View.bare({ item = potion.id, n = 5 }), potion.name, "수를 뺀 이름")
	expect(View.isStack({ item = potion.id, n = 1 }) and not View.isStack(hat), "묶음인가")
	local subUp, toneUp = View.sub(hat, me, nil)
	expect(string.find(subUp, "★3", 1, true) == 1 and string.find(subUp, Items.data.WORDS.stat, 1, true) ~= nil and string.find(subUp, Items.data.WORDS.power, 1, true) ~= nil and toneUp == "accent", "쓸 수 있는 장비: 별 · 옵션 · 장착하면 오르는 전투력")
	eq(select(2, View.sub(hat, me, Items.make("hat", 20, 5))), "dim", "지금 것보다 못하면 흐리게")
	local subLv, toneLv = View.sub(Items.make("hat", 40, 3), me, nil)
	expect(toneLv == "red" and string.find(subLv, "40", 1, true) ~= nil, "레벨이 모자란 장비")
	local subJob, toneJob = View.sub(Items.make("weapon", 10, 3, "riven"), me, nil)
	expect(toneJob == "red" and subJob == Items.data.WORDS.otherJob, "다른 직업의 무기")
	eq(View.left(NOW + 24 * 3600, NOW), Format.fill(W.left, { n = 24 }), "남은 시간: 24시간")
	eq(View.left(NOW + 3599, NOW), Format.fill(W.leftMin, { n = 60 }), "한 시간이 안 되면 분으로")
	eq(View.left(NOW, NOW), "", "끝났으면 빈 글")
	eq(View.ago(NOW - 20, NOW), Format.fill(W.agoMin, { n = 1 }), "방금 = 1분 전")
	eq(View.ago(NOW - 59 * 60, NOW), Format.fill(W.agoMin, { n = 59 }), "59분 전")
	eq(View.ago(NOW - 3 * 3600, NOW), Format.fill(W.agoHour, { n = 3 }), "3시간 전")
	eq(View.ago(NOW - 50 * 3600, NOW), Format.fill(W.agoDay, { n = 2 }), "2일 전")
	-- 차례
	local rows = { { id = "a", p = 10, e = NOW + 900, it = Market.pack(hat) }, { id = "b", p = 20, e = NOW + 100, it = { g = potion.id, n = 3 } }, { id = "c", p = 30, e = NOW + 500, it = { g = potion.id, n = 1 } } }
	local byTime = View.sort(rows, "time")
	expect(byTime[1].id == "b" and byTime[2].id == "c" and byTime[3].id == "a" and rows[1].id == "a" and View.sort(rows, "price")[1].id == "a", "남은 시간 순 = 곧 끝나는 것부터(받은 표는 그대로) · 가격 순 = 받은 그대로")
	expect(View.nextSort("price") == "time" and View.nextSort("time") == "price" and View.sortName("price") == W.sortPrice and View.sortName("time") == W.sortTime, "차례 단추")
	-- 이름으로 찾기
	eq(#View.filter(rows, ""), 3, "빈 글이면 모두")
	eq(#View.filter(rows, potion.name), 2, "이름으로 찾는다")
	eq(#View.filter(rows, "lv.10"), 1, "영문은 대소문자를 가리지 않는다")
	eq(#View.filter(rows, "%d+"), 0, "글자 그대로 찾는다(무늬가 아니다)")
	-- 살 때
	local stackRow = { id = "b", p = 50, l = 7, it = { g = potion.id, n = 7 } }
	expect(View.askMax(stackRow, 1000) == 7 and View.askMax(stackRow, 120) == 2 and View.askMax(stackRow, 0) == 1 and View.askMax({ p = 5, it = Market.pack(hat) }, 1000) == 1, "살 수 있는 가장 큰 수: 남은 수 · 내 달돈으로")
	eq(View.ask(stackRow, 3), Format.fill(W.askSum, { name = potion.name, price = "150" }), "묶음을 살 때 묻는 글: 합친 값(수량은 옆의 칸에 적는다)")
	eq(View.ask(stackRow, nil), Format.fill(W.askSum, { name = potion.name, price = "0" }), "수량 칸이 비었으면 합계 0")
	-- 수량을 적는 칸(사용자 2026-10-13: "경매장  수량도 입력하는걸로 처리하는방향으로 해주세요")
	do
		local text, n = View.count("3", 7)
		expect(text == "3" and n == 3, "적은 수 그대로")
		text, n = View.count("12", 7)
		expect(text == "7" and n == 7, "올라온 수를 넘으면 그 수로")
		text, n = View.count("0a05x", 7)
		expect(text == "5" and n == 5, "숫자만 · 앞의 0은 뗀다")
		text, n = View.count("", 7)
		expect(text == "" and n == nil, "비었으면 수가 없다")
		text, n = View.count("000", 7)
		expect(text == "" and n == nil, "0은 수가 아니다")
		eq(View.stock(10), Format.fill(W.stock, { n = 10 }), "「남은 수량 10개」")
		eq(View.of(10), Format.fill(W.of, { n = 10 }), "「/ 10개」")
		-- 구매 목록의 줄: 묶음은 이름(수는 빼고)과 올라온 수 · 장비는 이름 +별과 전투력
		local name, sub, tone = View.rowText({ item = potion.id, n = 10 }, me, nil)
		expect(name == potion.name and sub == View.stock(10) and tone == "text", "묶음의 줄: 이름과 「남은 수량 10개」(사용자: \"수량이 몇개가 올라와있는지도 보여야\")")
		name, sub = View.rowText(hat, me, nil)
		expect(name == View.name(hat) and string.find(sub, "★", 1, true) ~= nil and string.find(sub, Items.data.WORDS.stat, 1, true) ~= nil, "장비의 줄: 이름과 별 · 옵션")
		-- 올라온 것을 눌렀을 때의 상세(사용자: "경매장에서 올라온거 눌러서 상세 볼수있어야합니다. 어떤아이템인지")
		local info = View.info(hat, me, nil)
		expect(info.name == View.name(hat) and #info.rows >= 4 and info.tone == "tier3", "장비의 상세: 이름 · 요구 레벨 · 성능 · 별 · 전투력 …")
		info = View.info({ item = potion.id, n = 10 }, me, nil)
		expect(info.name == potion.name and info.rows[1][1] == W.count and info.rows[1][2] == Format.fill(W.units, { n = 10 }) and #info.notes >= 1, "묶음의 상세: 올라온 수량 · 효과 · 설명")
	end
	eq(View.ask({ p = 1200, it = Market.pack(hat) }, 1), Format.fill(W.ask, { name = View.name(hat), price = "1,200" }), "장비를 살 때 묻는 글")
	-- 값을 적는 칸 · 양식
	eq(View.digits("12a3"), "123", "숫자만")
	eq(View.digits("00120"), "120", "앞의 0은 뗀다")
	eq(#View.digits("123456789012345"), #tostring(M.priceMax), "자릿수를 넘지 않는다")
	local f = View.form(10, "50", 24, 1000)
	expect(f.ok and f.price == 50 and f.total == 500 and f.fee == 25 and f.pay == 475 and f.deposit == M.deposit and f.short == false, "양식: 개당 50 x 10 = 합계 500 → 수수료 25 · 받는 금액 475 · 보증금")
	expect(View.form(1, "1000", 24, M.deposit - 1).ok == false and View.form(1, "1000", 24, M.deposit - 1).short == true, "보증금이 모자라면 「등록」이 눌리지 않는다")
	expect(View.form(1, "", 24, 1000).ok == false and View.form(1, "0", 24, 1000).ok == false and View.form(1, "100", 12, 1000).ok == false, "빈 값 · 0 · 틀린 기간이면 「등록」이 눌리지 않는다")
	-- 가방에서 올릴 수 있는 것: 퀘스트의 물건 · 부서진 장비는 빠진다
	local h = Hero.new(1, "axion")
	for i = 1, Bag.size(h) do
		h.gear[i], h.use[i], h.etc[i] = false, false, false
	end
	local quest
	for _, g in Items.data.GOODS do
		if g.quest and not quest then
			quest = g
		end
	end
	local broken = Items.make("suit", 10, 3)
	broken.broken = true
	Bag.add(h, hat)
	Bag.add(h, broken)
	Bag.give(h, potion.id, 7)
	Bag.give(h, quest.id, 1)
	local list = View.sellables(Bag.view(h))
	expect(#list == 2 and list[1].tab == "gear" and list[1].it.slot == "hat" and list[2].tab == "use" and list[2].it.n == 7, "올릴 수 있는 것만 — 탭의 차례대로")
	eq(#View.sellables(nil), 0, "가방이 아직 없으면 빈 목록")
	-- 내 것 나누기: 판매 탭(판매 중인 것) · 완료 탭(받을 것)
	local rowHat, rowPot = Market.pack(hat), { g = potion.id, n = 10 }
	local mine = {
		{ id = "s1", it = rowPot, p = 50, t = NOW, e = NOW + 47 * 3600, state = "selling", n = 10, left = 7, sold = 3, due = 3, pay = 143, deposit = 0 },
		{ id = "s2", it = rowHat, p = 1000, t = NOW, e = NOW + 3 * 3600, state = "selling", n = 1, left = 1, sold = 0, due = 0, pay = 0, deposit = 0 },
		{ id = "s3", it = rowHat, p = 1000, t = NOW, e = NOW, state = "soldout", n = 1, left = 0, sold = 1, due = 1, pay = 950, deposit = 100 },
		{ id = "s4", it = rowPot, p = 50, t = NOW, e = NOW, state = "ended", n = 10, left = 6, sold = 4, due = 4, pay = 190, deposit = 0 },
		{ id = "s5", it = rowHat, p = 1000, t = NOW, e = NOW, state = "back", n = 1, left = 1, sold = 0, due = 0, pay = 0, deposit = 100 },
		{ id = "h1", it = { g = potion.id, n = 3 }, p = 150, t = NOW, e = NOW, state = "hold", n = 3, left = 0, sold = 0, due = 0, pay = 0, deposit = 0 },
	}
	local selling = View.sellingRows(mine)
	expect(#selling == 2 and selling[1].id == "s1" and selling[2].id == "s2", "판매 탭: 판매 중인 것만")
	eq(View.sellNote(mine[1], NOW), Format.fill(W.left, { n = 47 }) .. " · " .. Format.fill(W.remain, { n = 7, max = 10 }), "묶음: 남은 시간 · 「7 / 10개 남음」")
	eq(View.sellNote(mine[2], NOW), Format.fill(W.left, { n = 3 }), "장비: 남은 시간만")
	local done = View.doneRows(mine)
	eq(#done, 5, "완료 탭: 대금을 받을 것(판매 중인 것도) · 다 팔린 것 · 미판매 둘 · 낙찰 — 안 팔린 판매 중인 것은 없다")
	local byId = {}
	for _, d in done do
		byId[d.row.id] = d
	end
	expect(byId.s1.kind == "sold" and byId.s1.amount == 143 and #byId.s1.buttons == 1 and byId.s1.buttons[1].what == "collect" and byId.s1.buttons[1].text == W.collect and byId.s1.it.n == 3, "일부 팔린 것: 「판매 완료 · 3개 판매」 — 대금 143 · 「대금 수령」")
	expect(byId.s3.kind == "sold" and byId.s3.amount == 1050 and byId.s3.text == W.sold and byId.s3.buttons[1].main == true, "다 팔린 것: 대금과 보증금을 합쳐 1,050")
	expect(byId.s4.kind == "unsold" and byId.s4.amount == 190 and #byId.s4.buttons == 2 and byId.s4.buttons[1].what == "back" and byId.s4.buttons[2].what == "relist" and byId.s4.it.n == 6 and string.find(byId.s4.text, W.unsold, 1, true) ~= nil, "미판매: 남은 여섯 — 「반환」 「재등록」(팔린 넷의 대금 190도 함께)")
	expect(byId.s5.kind == "unsold" and byId.s5.amount == 100 and #byId.s5.buttons == 2, "장부에 오르지 못한 것: 「미판매」 — 보증금이 돌아온다")
	expect(byId.h1.kind == "won" and byId.h1.text == W.won and byId.h1.amount == nil and byId.h1.buttons[1].what == "take" and byId.h1.buttons[1].text == W.take, "낙찰: 「수령」")
	eq(#View.doneRows(nil), 0, "아직 받은 것이 없으면 빈 목록")
	eq(View.tradeSub({ item = potion.id, n = 3 }), Format.fill(W.units, { n = 3 }), "시세의 아래 글: 묶음은 수")
	eq(View.tradeSub(hat), "", "장비는 빈 글")
end

-- ================= 5) 창을 화면 없이 눌러 본다 — 가짜 화면 부품 위의 진짜 창(client/lune/ui/auctionWindow.luau) · 진짜 서버 =================
--  부품(Ui)만 가짜다: 무엇이 놓였는지 · 보이는지 · 눌리는지를 적어 두고, 놓이는 글이 제 폭에 드는지 그때그때 잰다. 단추를 누르면 창의 코드가 서버의 onMarket을 그대로 부른다.
do
	table.clear(disk)
	table.clear(boards)
	table.clear(names)
	table.clear(log)
	fail.save, fail.update, fail.read = false, false, false
	slow = 0
	local sv = server()
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	local L = req("ReplicatedStorage/shared/lune/ui/layout")
	local Format = req("ReplicatedStorage/shared/lune/ui/format")
	local View = req("ReplicatedStorage/shared/lune/ui/auctionView")
	local pixelText = req("Client/ui/pixelText")
	pixelText.Register("small", KIT.font.small, {})
	pixelText.Register("body", KIT.font.body, {})
	local Market, Bag, Items = sv.Market, sv.Bag, sv.Items
	local W, WHY, M, S = Market.WORDS, Market.WHY, Market.DATA, L.AUCTION
	local DEP = M.deposit

	-- ---- 가짜 부품 ----
	local all, overflow = {}, {}
	local function node(kind: string, parent: any)
		local o = { kind = kind, parent = parent, children = {}, Visible = true, alive = true }
		function o.GetChildren(self)
			return table.clone(self.children)
		end
		function o.Destroy(self)
			self.alive = false
			if self.parent then
				local i = table.find(self.parent.children, self)
				if i then
					table.remove(self.parent.children, i)
				end
			end
		end
		if parent then
			table.insert(parent.children, o)
		end
		table.insert(all, o)
		return o
	end
	local function fits(o)
		local w = (pixelText.Measure(o.text, o.font))
		if o.text ~= "" and w > o.width * o.lines then
			table.insert(overflow, ("%s (%d > %d)"):format(o.text, w, o.width * o.lines))
		end
	end
	local Ui = { COLOR = setmetatable({}, { __index = function(_, k) return k end }), M = KIT.ui.metric }
	function Ui.group(parent, _x, _y, _w, _h, name)
		local o = node("group", parent)
		o.Name = name
		return o
	end
	function Ui.line(parent)
		return node("line", parent)
	end
	function Ui.scroll(parent, _x, _y, _w, h, contentH)
		local o = node("scroll", parent)
		o.h, o.contentH = h, contentH
		return o
	end
	function Ui.slot(parent)
		local o = node("slot", parent)
		return { frame = o, setOn = function(_, on) o.on = on end }
	end
	function Ui.smallIcon(parent, name)
		local o = node("icon", parent)
		o.icon = name
		return o
	end
	function Ui.setWorldIcon(label, name)
		label.icon = name
		label.Visible = name ~= nil
	end
	function Ui.text(parent, text, _x, _y, width, opts)
		opts = opts or {}
		local o = node("text", parent)
		o.text, o.width, o.font, o.lines, o.tone = text, width, opts.font or "small", opts.lines or 1, opts.color
		fits(o)
		local item = { node = o }
		function item.set(_, value)
			o.text = value
			fits(o)
		end
		function item.color(_, c)
			o.tone = c
		end
		function item.show(_, on)
			o.Visible = on
		end
		function item.move() end
		return item
	end
	function Ui.button(parent, text, _x, _y, w, onClick, opts)
		opts = opts or {}
		local o = node("button", parent)
		local h = opts.h or Ui.M.button
		o.text, o.width, o.font, o.lines = text, w - 6, opts.font or (if h >= Ui.M.button then "body" else "small"), 1
		o.enabled, o.main, o.onClick = true, opts.main == true, onClick
		fits(o)
		local item = { frame = o }
		function item.setEnabled(_, on)
			o.enabled = on
		end
		function item.setText(_, value)
			o.text = value
			fits(o)
		end
		function item.setMain(_, on)
			o.main = on
		end
		return item
	end
	function Ui.tab(parent, text, _x, _y, onClick)
		local o = node("tab", parent)
		o.text, o.onClick, o.enabled = text, onClick, true
		return { frame = o, width = (pixelText.Measure(text, "small")), setOn = function(_, on) o.on = on end }
	end
	function Ui.hit(parent)
		local o = node("hit", parent)
		o.enabled = true
		o.Activated = { Connect = function(_, fn) o.onClick = fn end }
		return o
	end
	function Ui.field(parent, _x, _y, _w, _h, placeholder)
		local o = node("field", parent)
		o.Text, o.placeholder = "", placeholder
		function o.GetPropertyChangedSignal(_self, _name)
			return { Connect = function(_, fn) o.changed = fn end }
		end
		return o
	end
	MOCK("Client/lune/ui/ui", Ui)
	-- 아이템 상세 판(창 옆의 작은 판)도 가짜: 무엇을 띄웠는지만 적어 둔다
	local detail = { owner = nil :: any, spec = nil :: any, shows = 0 }
	MOCK("Client/lune/ui/itemDetail", {
		show = function(owner, spec)
			if detail.spec == nil or detail.spec.key ~= spec.key then
				detail.shows += 1
			end
			detail.owner, detail.spec = owner, spec
		end,
		hide = function(owner)
			if owner == nil or detail.owner == owner then
				detail.owner, detail.spec = nil, nil
			end
		end,
	})
	local AuctionWindow = req("Client/lune/ui/auctionWindow")
	expect(AuctionWindow.wide == true, "넓은 창(혼자 뜬다)")
	local bw, bh = AuctionWindow.size()
	expect(bw == S.w and bh == S.h, "창의 크기는 공방의 치수")

	-- 그 창(root) 안에서 지금 보이는 것 가운데 n번째
	local function shown(o, root): boolean
		local under, at = false, o
		while at do
			if not at.alive or at.Visible == false then
				return false
			end
			under = under or at == root
			at = at.parent
		end
		return under
	end
	local function find(root, kind: string, text: string?, nth: number?)
		local k = 0
		for _, o in all do
			if o.kind == kind and (text == nil or o.text == text) and shown(o, root) then
				k += 1
				if k == (nth or 1) then
					return o
				end
			end
		end
		return nil
	end
	local function count(root, kind: string, text: string?): number
		local k = 0
		for _, o in all do
			if o.kind == kind and (text == nil or o.text == text) and shown(o, root) then
				k += 1
			end
		end
		return k
	end
	local function press(root, kind: string, text: string?, nth: number?)
		local o = find(root, kind, text, nth)
		expect(o ~= nil and o.enabled ~= false, ("눌린다: %s 「%s」"):format(kind, tostring(text)))
		if o and o.enabled ~= false then
			o.onClick()
		end
	end
	-- 그 글(의 일부)이 보이는가
	local function has(root, text: string): boolean
		for _, o in all do
			if o.kind == "text" and shown(o, root) and string.find(o.text, text, 1, true) then
				return true
			end
		end
		return false
	end
	-- 입력 칸에 적는다(Roblox처럼: 글이 바뀔 때마다 알린다 — 듣는 쪽이 글을 고치면 또 알린다)
	local function typeIn(box, text: string)
		box.Text = text
		for _ = 1, 4 do
			local before = box.Text
			box.changed()
			if box.Text == before then
				break
			end
		end
	end

	local pa, sa = enter(sv, 9201, "창판매자", "axion")
	local pb, sb = enter(sv, 9202, "창구매자", "riven")
	local ha, hb = sa.hero, sb.hero
	reset(sv, ha, 500)
	reset(sv, hb, 5000)
	local potion = Items.potionFor(1)
	local quest
	for _, g in Items.data.GOODS do
		if g.quest and not quest then
			quest = g
		end
	end
	local hat = Items.make("hat", 10, 4)
	hat.star = 3
	Bag.add(ha, hat)
	Bag.give(ha, potion.id, 20)
	Bag.give(ha, quest.id, 1)
	local hatName = View.name(hat)
	local function open(p, s)
		local body = node("body", nil)
		local ctx = {
			me = function()
				return { level = s.hero.level, class = s.hero.class, money = s.hero.money }
			end,
			bag = function()
				return Bag.view(s.hero)
			end,
			market = function(action, a, b, c, d)
				return sv.h.Market(p, action, a, b, c, d)
			end,
		}
		return body, AuctionWindow.build(body, ctx, S.w, S.h), ctx
	end

	-- ---- 판 사람: 연다 → 판매 탭 → 「판매 등록」 ----
	table.clear(log)
	local wa, va, ca = open(pa, sa)
	expect(count(wa, "tab") == 4 and find(wa, "tab", W.tabs[1]).on == true and find(wa, "tab", W.tabs[3]) ~= nil and find(wa, "tab", W.tabs[4]) ~= nil, "탭 넷(구매 · 판매 · 완료 · 시세) — 처음은 「구매」")
	expect(table.find(log, "read:w_axion") ~= nil, "열자마자 내 직업의 무기 목록을 묻는다")
	expect(has(wa, W.empty) and has(wa, View.slots(0, M.slots)) and has(wa, Format.fill(W.rows, { n = 0 })), "빈 목록 · 「판매 0 / 10」 · 「0건」")
	expect(count(wa, "button", W.buy) == 0 and find(wa, "button", W.cancel) == nil and find(wa, "button", W.sortPrice) ~= nil, "살 것이 없으면 「구매」도, 묻는 줄도 없다 · 차례 단추가 보인다")
	press(wa, "tab", W.tabs[2])
	expect(find(wa, "tab", W.tabs[2]).on == true and has(wa, W.sellEmpty) and find(wa, "button", W.sell) ~= nil and find(wa, "button", "무기") == nil and count(wa, "field") == 0, "판매 탭: 「판매 중인 물건이 없다」와 「판매 등록」(분류 · 찾는 칸은 없다)")
	expect(has(wa, Format.fill(W.depositNote, { n = Format.comma(DEP) })), "보증금의 알림이 보인다")
	press(wa, "button", W.sell)
	expect(has(wa, W.pick) and count(wa, "hit") == 2 and find(wa, "button", W.back) ~= nil and find(wa, "button", W.sell) == nil, "등록 화면: 올릴 수 있는 것 둘(모자 · 물약 — 퀘스트의 물건은 없다) · 「목록」")
	expect(find(wa, "button", W.register).enabled == false and count(wa, "field") == 1 and count(wa, "button", "-10") == 0, "고르기 전에는 「등록」이 눌리지 않는다 · 수량 칸도 없다(수를 고치는 단추는 이제 없다)")
	press(wa, "hit", nil, 1)
	expect(has(wa, hatName) and find(wa, "text", W.price) ~= nil and find(wa, "text", W.unitPrice) == nil and count(wa, "field") == 1, "모자를 골랐다: 이름표는 「가격」 — 수량 칸은 없다")
	local price = find(wa, "field")
	expect(price ~= nil and price.placeholder == "0", "값을 적는 칸")
	typeIn(price, "1,0a00")
	eq(price.Text, "1000", "숫자만 남는다")
	expect(find(wa, "text", "950") ~= nil and find(wa, "text", "50") ~= nil and find(wa, "text", Format.comma(DEP)) ~= nil, "수수료 50 · 보증금 · 받는 금액 950이 보인다")
	expect(find(wa, "button", Format.fill(W.hours, { n = 24 })).main == true and find(wa, "button", Format.fill(W.hours, { n = 48 })).main == false, "기간은 24시간부터")
	press(wa, "button", W.register)
	expect(boards.a_hat ~= nil and #boards.a_hat.list == 1 and boards.a_hat.list[1].p == 1000 and Bag.used(ha, "gear") == 0 and ha.money == 500 - DEP, "서버에 올라갔다(보증금을 냈다)")
	expect(has(wa, View.slots(1, M.slots)) and has(wa, Format.fill(W.listed, { name = Market.nameOf(boards.a_hat.list[1].it) })), "「판매 1 / 10」 · 올렸다는 알림")
	expect(find(wa, "button", W.sell) ~= nil and count(wa, "button", W.cancel) == 1 and has(wa, hatName) and find(wa, "text", "1,000") ~= nil and find(wa, "text", tostring(500 - DEP)) ~= nil, "판매 중인 목록으로 돌아온다: 모자와 「취소」 · 지갑이 줄었다")
	-- 묶음: 개당 가격 · 수를 고른다 · 48시간
	press(wa, "button", W.sell)
	expect(count(wa, "hit") == 1 and price.Text == "" and find(wa, "button", W.register).enabled == false, "등록 화면: 남은 것은 물약 — 양식은 비어 있다")
	press(wa, "hit", nil, 1)
	local qty = find(wa, "field", nil, 1) -- 수량을 적는 칸(값의 칸보다 위에 지어졌다)
	expect(count(wa, "field") == 2 and qty ~= price and qty.Text == "20" and find(wa, "text", View.of(20)) ~= nil and find(wa, "text", W.unitPrice) ~= nil and find(wa, "text", W.price) == nil, "물약: 수량 칸에 그 묶음 전부(20) · 「/ 20개」 · 이름표는 「개당 가격」")
	typeIn(qty, "35")
	eq(qty.Text, "20", "가진 수를 넘게 적으면 가진 수로")
	typeIn(qty, "")
	typeIn(price, "50")
	expect(find(wa, "button", W.register).enabled == false, "수량 칸이 비어 있으면 「등록」이 눌리지 않는다")
	typeIn(qty, "1x0")
	expect(qty.Text == "10" and has(wa, potion.name .. " x10") and find(wa, "button", W.register).enabled == true, "열 개(숫자만 남는다)")
	expect(has(wa, Format.fill(W.total, { n = "500" })) and find(wa, "text", "475") ~= nil and find(wa, "text", "25") ~= nil, "개당 50 x 10: 「합계 500」 · 수수료 25 · 받는 금액 475")
	press(wa, "button", Format.fill(W.hours, { n = 48 }))
	expect(find(wa, "button", Format.fill(W.hours, { n = 48 })).main == true, "48시간을 골랐다")
	press(wa, "button", W.register)
	expect(boards.u ~= nil and boards.u.list[1].it.n == 10 and boards.u.list[1].p == 50 and boards.u.list[1].l == 10 and boards.u.list[1].e - boards.u.list[1].t == 48 * 3600 and Bag.count(ha, potion.id) == 10 and ha.money == 500 - DEP * 2, "물약 열 개를 개당 50에 48시간 올렸다")
	expect(has(wa, View.slots(2, M.slots)) and count(wa, "button", W.cancel) == 2 and has(wa, Format.fill(W.remain, { n = 10, max = 10 })) and find(wa, "text", W.unit) ~= nil, "판매 중 둘: 묶음은 「10 / 10개 남음」과 「개당」")
	-- 보증금이 모자라면 「등록」이 눌리지 않는다
	local keepMoney = ha.money
	ha.money = DEP - 1
	press(wa, "button", W.sell)
	press(wa, "hit", nil, 1)
	typeIn(price, "9")
	expect(find(wa, "button", W.register).enabled == false and find(wa, "text", Format.comma(DEP)).tone == "red", "보증금이 모자라면 눌리지 않는다(보증금이 빨갛게 보인다)")
	ha.money = keepMoney
	va.refresh()
	expect(find(wa, "button", W.register).enabled == true and find(wa, "text", Format.comma(DEP)).tone == "dim", "달돈이 되면 눌린다")
	typeIn(price, "")
	press(wa, "button", W.back)
	expect(find(wa, "button", W.sell) ~= nil and count(wa, "button", W.cancel) == 2, "「목록」: 판매 중인 것들로 돌아온다")
	-- 내가 올린 것은 구매 탭에서 단추 대신 「판매 중」
	press(wa, "tab", W.tabs[1])
	press(wa, "button", "모자")
	expect(has(wa, hatName) and count(wa, "button", W.buy) == 0 and find(wa, "text", W.selling) ~= nil, "내가 올린 것에는 「구매」가 없다")

	-- ---- 사는 사람 ----
	table.clear(log)
	local wb, vb = open(pb, sb)
	expect(table.find(log, "read:w_riven") ~= nil and has(wb, W.empty), "사는 사람의 창: 제 직업의 무기부터")
	press(wb, "button", "무기")
	expect(find(wb, "button", View.className("riven")) ~= nil, "무기 분류에서는 직업 단추가 보인다")
	press(wb, "button", View.className("riven"))
	expect(find(wb, "button", View.className(View.nextClass("riven"))) ~= nil and table.find(log, "read:w_" .. View.nextClass("riven")) ~= nil, "직업 단추를 누르면 다음 직업의 무기를 묻는다")
	press(wb, "button", "모자")
	expect(find(wb, "button", View.className(View.nextClass("riven"))) == nil, "다른 분류에서는 직업 단추가 없다")
	expect(has(wb, hatName) and has(wb, "창판매자") and find(wb, "text", "1,000") ~= nil and count(wb, "button", W.buy) == 1 and has(wb, Format.fill(W.rows, { n = 1 })) and find(wb, "text", W.unit) == nil, "모자 분류: 이름 · 판매자 · 값 · 「구매」(장비에는 「개당」이 없다)")
	expect(find(wb, "button", "모자").main == true and find(wb, "button", "무기").main == false, "고른 분류가 밝다")
	hb.money = 10
	vb.refresh()
	expect(find(wb, "button", W.buy).enabled == false, "달돈이 모자라면 「구매」가 눌리지 않는다")
	hb.money = 5000
	vb.refresh()
	expect(find(wb, "button", W.buy).enabled == true, "달돈이 되면 눌린다")
	local search = find(wb, "field")
	typeIn(search, "없는이름")
	expect(has(wb, W.empty) and has(wb, Format.fill(W.rows, { n = 0 })) and count(wb, "button", W.buy) == 0, "찾는 이름이 없으면 빈 목록")
	typeIn(search, "")
	-- 줄을 누르면 그 물건의 상세가 뜬다(사용자 2026-10-13: "경매장에서 올라온거 눌러서 상세 볼수있어야합니다. 어떤아이템인지") — 한 번 더 누르면 닫힌다
	eq(detail.spec, nil, "누르기 전에는 상세가 없다")
	press(wb, "hit", nil, 1)
	expect(detail.owner == "auction" and detail.spec ~= nil and detail.spec.info.name == hatName and detail.spec.item.slot == "hat" and detail.spec.item.star == 3 and #detail.spec.info.rows >= 4, "모자의 줄을 누르면 상세: 이름 · 성능 · 별 · 전투력")
	expect(count(wb, "button", W.buy) == 1 and hb.money == 5000, "상세를 본다고 사지는 않는다")
	press(wb, "hit", nil, 1)
	eq(detail.spec, nil, "한 번 더 누르면 닫힌다")
	press(wb, "hit", nil, 1)
	detail.spec.onClose()
	eq(detail.spec, nil, "상세 판의 ×로도 닫힌다")
	press(wb, "hit", nil, 1)
	press(wb, "tab", W.tabs[3])
	eq(detail.spec, nil, "다른 탭으로 가면 닫힌다")
	press(wb, "tab", W.tabs[1])
	-- 장비를 산다: 한 번 더 묻는다(수량 칸은 없다) → 「완료」에 「낙찰」
	press(wb, "button", W.buy)
	expect(has(wb, Format.fill(W.ask, { name = hatName, price = "1,000" })) and count(wb, "button", W.buy) == 2 and find(wb, "button", W.cancel) ~= nil and count(wb, "field") == 1, "「…에 구매할까요?」와 「구매 · 취소」(수량 칸은 없다 — 보이는 칸은 찾는 칸뿐)")
	press(wb, "button", W.cancel)
	expect(count(wb, "button", W.buy) == 1 and find(wb, "button", W.cancel) == nil and hb.money == 5000, "「취소」하면 묻는 줄이 사라진다")
	press(wb, "button", W.buy)
	press(wb, "button", W.buy, 1) -- 묻는 줄의 「구매」(줄의 단추보다 먼저 지어졌다)
	expect(hb.money == 4000 and Bag.used(hb, "gear") == 0 and has(wb, W.empty) and has(wb, Format.fill(W.bought, { name = Market.nameOf(Market.pack(hat)) })) and find(wb, "text", "4000") ~= nil, "샀다: 달돈이 빠졌다 · 목록에서 사라진다 · 「완료에서 수령」 알림(아직 가방에는 없다)")
	press(wb, "tab", W.tabs[3])
	expect(find(wb, "tab", W.tabs[3]).on == true and has(wb, hatName) and find(wb, "text", W.won) ~= nil and count(wb, "button", W.take) == 1 and find(wb, "button", W.take).main == true and find(wb, "button", "모자") == nil, "완료 탭: 모자가 「낙찰」 — 「수령」")
	press(wb, "button", W.take)
	expect(Bag.used(hb, "gear") == 1 and hb.gear[1].star == 3 and hb.gear[1].q == 4 and has(wb, W.doneEmpty) and has(wb, Format.fill(W.taken, { name = Market.nameOf(Market.pack(hat)) })) and find(wb, "button", W.all).enabled == false, "수령: 모자가 가방에 들어왔다 · 「받을 것이 없다」")
	-- 묶음을 낱개로 산다
	press(wb, "tab", W.tabs[1])
	press(wb, "button", "소비")
	expect(find(wb, "text", potion.name) ~= nil and find(wb, "text", View.stock(10)) ~= nil and find(wb, "text", "50") ~= nil and find(wb, "text", W.unit) ~= nil, "소비 분류: 물약 — 「남은 수량 10개」 · 개당 50(사용자: \"수량이 몇개가 올라와있는지도 보여야\")")
	press(wb, "hit", nil, 1)
	expect(detail.spec ~= nil and detail.spec.info.name == potion.name and detail.spec.info.rows[1][2] == Format.fill(W.units, { n = 10 }), "물약의 줄을 누르면 상세: 올라온 수량 10개 · 효과")
	press(wb, "hit", nil, 1)
	press(wb, "button", W.buy)
	local buyQty = find(wb, "field", nil, 1) -- 묻는 줄의 수량 칸(찾는 칸보다 먼저 지어졌다)
	expect(buyQty ~= search and buyQty.placeholder == "1", "수량 칸이다")
	expect(count(wb, "field") == 2 and buyQty.Text == "1" and find(wb, "text", View.of(10)) ~= nil and find(wb, "text", W.count) ~= nil and has(wb, Format.fill(W.askSum, { name = potion.name, price = "50" })) and count(wb, "button", "+1") == 0, "묶음: 수량을 적는 칸 — 처음은 하나 · 「/ 10개」 · 합계 50")
	typeIn(buyQty, "25")
	expect(buyQty.Text == "10" and has(wb, Format.fill(W.askSum, { name = potion.name, price = "500" })), "올라온 수(10)를 넘게 적으면 그 수로 — 합계 500")
	typeIn(buyQty, "")
	expect(find(wb, "button", W.buy, 1).enabled == false and has(wb, Format.fill(W.askSum, { name = potion.name, price = "0" })), "수량 칸이 비어 있으면 「구매」가 눌리지 않는다")
	typeIn(buyQty, "3")
	expect(has(wb, Format.fill(W.askSum, { name = potion.name, price = "150" })) and find(wb, "button", W.buy, 1).enabled == true, "셋 — 합계 150")
	hb.money = 120
	vb.refresh()
	expect(find(wb, "button", W.buy, 1).enabled == false, "달돈이 모자라면 「구매」가 눌리지 않는다")
	hb.money = 4000
	vb.refresh()
	press(wb, "button", W.buy, 1)
	expect(hb.money == 3850 and boards.u.list[1].l == 7 and find(wb, "text", View.stock(7)) ~= nil and Bag.count(hb, potion.id) == 0, "셋을 샀다: 목록에는 「남은 수량 7개」가 남는다")
	-- 시세
	press(wb, "tab", W.tabs[4])
	expect(find(wb, "tab", W.tabs[4]).on == true and has(wb, potion.name) and has(wb, Format.fill(W.units, { n = 3 })) and has(wb, Format.fill(W.agoMin, { n = 1 })) and find(wb, "text", "50") ~= nil and count(wb, "button", W.buy) == 0 and find(wb, "button", W.sortPrice) == nil and find(wb, "button", "소비") ~= nil, "시세 탭: 물약 3개 · 개당 50 · 1분 전(분류 단추는 그대로 · 차례 단추와 「구매」는 없다)")
	press(wb, "button", "모자")
	expect(has(wb, Market.nameOf(Market.pack(hat))) or has(wb, View.bare(hat)), "모자 분류의 시세: 방금 팔린 모자")
	press(wb, "button", "옷")
	expect(has(wb, W.logEmpty), "거래가 없던 분류: 「최근 거래가 없다」")
	-- 완료: 모두 받기
	press(wb, "tab", W.tabs[3])
	expect(count(wb, "button", W.take) == 1 and has(wb, potion.name .. " x3") and find(wb, "button", W.all).enabled == true, "완료 탭: 물약 x3이 「낙찰」")
	press(wb, "button", W.all)
	expect(Bag.count(hb, potion.id) == 3 and has(wb, W.doneEmpty) and has(wb, Format.fill(W.allDone, { n = 1 })), "「모두 받기」: 물약 셋이 가방에 들어왔다")

	-- ---- 판 사람: 완료에서 대금 수령 · 판매 취소 ----
	press(wa, "tab", W.tabs[3])
	expect(count(wa, "button", W.collect) == 2 and find(wa, "text", W.sold) ~= nil and has(wa, W.sold .. " · " .. Format.fill(W.soldN, { n = 3 })) and find(wa, "text", Format.comma(950 + DEP)) ~= nil and find(wa, "text", "143") ~= nil, "완료 탭: 모자 「판매 완료」(대금 + 보증금) · 물약 「판매 완료 · 3개 판매」(143)")
	local before = ha.money
	press(wa, "button", W.collect, 1)
	expect(ha.money > before and count(wa, "button", W.collect) == 1, "하나를 받았다: 줄이 사라진다")
	press(wa, "button", W.all)
	expect(ha.money == before + 950 + DEP + 143 and has(wa, W.doneEmpty) and has(wa, View.slots(1, M.slots)), "「모두 받기」: 모자의 대금 950과 보증금 · 물약 셋의 대금 143 — 물약은 계속 판매 중")
	press(wa, "tab", W.tabs[2])
	expect(count(wa, "button", W.cancel) == 1 and has(wa, Format.fill(W.remain, { n = 7, max = 10 })), "판매 탭: 물약 「7 / 10개 남음」")
	press(wa, "button", W.cancel)
	expect(Bag.count(ha, potion.id) == 17 and has(wa, W.sellEmpty) and has(wa, View.slots(0, M.slots)), "취소: 남은 일곱이 돌아온다 · 「판매 중인 물건이 없다」")
	-- ---- 미판매: 반환 · 재등록 ----
	local suit = Items.make("suit", 10, 3)
	Bag.add(ha, suit)
	press(wa, "button", W.sell)
	eq(count(wa, "hit"), 2, "등록 화면: 가방의 새 장비가 목록에 생긴다")
	press(wa, "hit", nil, 1)
	typeIn(price, "700")
	expect(find(wa, "button", Format.fill(W.hours, { n = 48 })).main == true, "기간은 앞에서 고른 것(48시간)이 남아 있다")
	press(wa, "button", Format.fill(W.hours, { n = 24 }))
	press(wa, "button", W.register)
	expect(#boards.a_suit.list == 1 and count(wa, "button", W.cancel) == 1, "옷을 올렸다")
	advance(25 * 3600)
	press(wa, "tab", W.tabs[3])
	expect(find(wa, "text", W.unsold) ~= nil and count(wa, "button", W.giveBack) == 1 and count(wa, "button", W.relist) == 1 and count(wa, "button", W.collect) == 0, "기간이 끝났다: 「미판매」 — 「반환」 「재등록」")
	before = ha.money
	press(wa, "button", W.relist)
	expect(ha.money == before - DEP and has(wa, W.doneEmpty) and has(wa, Format.fill(W.relisted, { name = View.name(suit) })) and #boards.a_suit.list == 1 and boards.a_suit.list[1].c == nil, "재등록: 보증금을 다시 내고 다시 올라갔다")
	press(wa, "tab", W.tabs[2])
	expect(count(wa, "button", W.cancel) == 1 and has(wa, View.name(suit)), "판매 탭에 다시 판매 중으로 보인다")
	advance(25 * 3600)
	press(wa, "tab", W.tabs[3])
	press(wa, "button", W.giveBack)
	expect(Bag.used(ha, "gear") == 1 and has(wa, W.doneEmpty) and #boards.a_suit.list == 0, "반환: 옷이 가방으로 돌아왔다")

	-- ---- 서버의 답이 늦다: 기다리는 동안 「처리 중…」 · 단추가 눌리지 않는다 ----
	local real = ca.market
	ca.market = function(...)
		task.wait(1)
		return real(...)
	end
	press(wa, "tab", W.tabs[1])
	expect(has(wa, W.wait) and find(wa, "button", W.refresh).enabled == false and find(wa, "button", "모자").enabled == false, "기다리는 동안 「처리 중…」 — 단추가 꺼진다")
	advance(2)
	expect(not has(wa, W.wait) and find(wa, "button", W.refresh).enabled == true, "답이 오면 다시 눌린다")
	-- 차례 단추
	press(wa, "button", W.sortPrice)
	expect(find(wa, "button", W.sortTime) ~= nil and find(wa, "button", W.sortPrice) == nil, "차례 단추: 「남은 시간 순」으로 바뀐다")
	-- 답이 없다(보내는 빠르기의 한도 · 오류)
	ca.market = function()
		return nil
	end
	press(wa, "button", W.refresh)
	expect(has(wa, WHY.off) and find(wa, "button", W.refresh).enabled == true, "답이 없으면 그렇게 알리고 막히지 않는다")
	-- 답을 기다리는 사이에 창이 닫혔다: 탈이 없다
	ca.market = function(...)
		task.wait(1)
		return real(...)
	end
	press(wa, "button", W.refresh)
	va.destroy()
	advance(2)
	vb.destroy()
	eq(#overflow, 0, "칸을 넘는 글이 없다: " .. table.concat(overflow, " / "))
	eq(#warnings, 0, "경고가 없다: " .. table.concat(warnings, " / "))
end

-- ================= 6) 관리자의 시험 물건(메뉴 → 관리 → 아이템 → 「경매장 시험」) =================
--  혼자서도 사는 쪽을 해 볼 수 있게 「시험 판매자」의 물건을 올리고 치운다. 물건을 만들어 내는 일이라 관리자만 된다(서버가 계정 번호로 가린다).
do
	table.clear(disk)
	table.clear(boards)
	table.clear(names)
	fail.save, fail.update, fail.read = false, false, false
	slow = 0
	local sv = server()
	local Market, Bag = sv.Market, sv.Bag
	local Admin = req("ServerScriptService/server/lune/modules/admin")
	local adminId = next(Admin.IDS)
	local pu, su = enter(sv, 9301, "보통사람", "mooni")
	local pm, sm = enter(sv, adminId, "관리하는이", "riven")
	expect(sv.h.Admin(pu, "market", "fill") == nil and next(boards) == nil, "관리자가 아니면 아무 일도 일어나지 않는다(대답도 없다)")
	local r = sv.h.Admin(pm, "market", "fill")
	expect(r ~= nil and r.ok == true, "관리자는 시험 물건을 올린다 " .. tostring(r and r.msg))
	local total, weaponBoard = 0, "w_" .. sm.hero.class
	for _, doc in boards do
		for _, e in doc.list do
			total += 1
			expect(e.u == 0 and e.sn == "시험 판매자" and Market.unpack(e.it) ~= nil and e.l == Market.units(e.it), "시험 판매자의 줄(판 사람의 번호 0)")
		end
	end
	expect(total == 3 and boards[weaponBoard] ~= nil and boards.a_hat ~= nil and boards.u ~= nil, "셋: 관리자의 직업의 무기 · 모자 · 물약")
	expect(sv.h.Admin(pm, "market", "뭔가").ok == false, "모르는 일")
	-- 누구나 그 물건을 산다(산 것은 「완료」에 들어온다)
	reset(sv, su.hero, 5000)
	local rows = sv.h.Market(pu, "browse", "a_hat").rows
	expect(#rows == 1 and rows[1].sn == "시험 판매자" and rows[1].mine == false, "경매장에 보인다")
	r = sv.h.Market(pu, "buy", "a_hat", rows[1].id, 1, rows[1].p)
	expect(r.ok == true and su.hero.money == 5000 - rows[1].p and Market.holds(su.acct.market) == 1, "산다")
	expect(sv.h.Market(pu, "all").ok == true and Bag.used(su.hero, "gear") == 1, "수령한다")
	-- 치운다: 팔린 것까지 모두
	expect(sv.h.Admin(pu, "market", "clear") == nil and #boards.u.list == 1, "관리자가 아니면 치우지도 못한다")
	r = sv.h.Admin(pm, "market", "clear")
	expect(r.ok == true and string.find(r.msg, "3", 1, true) ~= nil, "치운다 " .. tostring(r.msg))
	for key, doc in boards do
		eq(#doc.list, 0, "장부가 비었다 " .. key)
	end
	eq(#sv.h.Market(pu, "browse", "u", true).rows, 0, "목록에서도 사라진다")
	-- 남이 올린 것은 치워지지 않는다
	r = sv.h.Market(pu, "list", "gear", 1, 1, { 123, 24 })
	expect(r.ok == true, "산 것을 되판다 " .. tostring(r.why))
	sv.h.Admin(pm, "market", "clear")
	eq(#boards.a_hat.list, 1, "다른 사람의 물건은 그대로다")
end
