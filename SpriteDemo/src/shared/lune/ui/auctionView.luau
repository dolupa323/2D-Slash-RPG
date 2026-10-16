-- 경매장 창에 적는 글과 셈 — 그리지는 않는다(client/lune/ui/auctionWindow.luau가 그린다). 자동 검사가 화면 없이 같은 것을 본다.
--  메이플 옥션 방식(사용자 2026-10-13: "메이플 식 경매장을 말하는거긴합니다"): 탭 넷 — 구매 · 판매 · 완료 · 시세.
--  낱말과 숫자는 공방 js/lune/design/economy.js의 AUCTION(data/items.generated.luau의 MARKET), 치수는 UILAYOUT.auction.
--  서버가 주는 것: 목록의 줄 { id, it(남은 수로), p 개당 값, sn 판매자, e 끝나는 때, t, l 남은 수, mine } · 시세의 줄 { it(팔린 수로), p 개당 값, t } ·
--   내 것의 줄 { id, it, p, t, e, state(hold · selling · ended · soldout · back), n 올린 수, left 남은 수, sold, due 대금을 받지 않은 수, pay 지금 받을 대금, deposit 함께 돌아오는 보증금 }.
local Items = require(script.Parent.Parent.sim.items)
local Market = require(script.Parent.Parent.sim.market)
local CLASSES = require(script.Parent.Parent.data["classes.generated"])
local ItemInfo = require(script.Parent.itemInfo)
local Format = require(script.Parent.format)

local D = Items.data
local M = Market.DATA
local W = Market.WORDS
local IW = D.WORDS

local V = {}
V.TABS = { "buy", "sell", "done", "log" } -- 탭의 차례(W.tabs와 같다: 구매 · 판매 · 완료 · 시세)
V.SORTS = { "price", "time" } -- 구매 목록의 차례: 가격 낮은 순 · 남은 시간 순
V.PRICE_DIGITS = #tostring(M.priceMax) -- 값을 적는 칸의 자릿수

-- 분류(무기 · 방어구의 부위들 · 소비 · 기타)와, 그 분류의 장부(무기는 직업마다 다르다)
function V.cats()
	return Market.cats()
end
function V.board(cat: string, class: string): string
	return Market.catBoard(cat, class)
end
-- 무기의 직업을 바꾸는 단추: 다음 직업 · 그 이름
function V.nextClass(class: string): string
	local i = table.find(CLASSES.order, class) or 0
	return CLASSES.order[i % #CLASSES.order + 1]
end
function V.className(class: string): string
	local c = CLASSES.classes[class]
	return if c then c.name else "?"
end

-- 장부의 물건 → 가방의 꼴(그림 · 이름에 쓴다 — 꼴이 깨졌으면 nil)
function V.item(row: any)
	return Market.unpack(row)
end
-- 묶음인가
function V.isStack(it): boolean
	return it.item ~= nil
end

-- 이름: 장비 = 이름(별은 이름 아래 줄의 「★5」 · 상세 판의 이름 위 — 2026-10-15) · 묶음 = 이름 x수
function V.name(it): string
	if it.item then
		local g = Items.goods(it.item)
		return if it.n > 1 then ("%s x%d"):format(g.name, it.n) else g.name
	end
	return Items.name(it)
end
-- 수를 뺀 이름(살 때 묻는 글 — 수는 따로 적는다)
function V.bare(it): string
	return if it.item then Items.goods(it.item).name else V.name(it)
end
-- 이름의 색: 장비 = 성능 단(낡은 … 빼어난) · 묶음 = 보통 글
function V.tone(it): string
	return if it.item then "text" else "tier" .. (it.q - 1)
end
-- 이름 아래의 한 줄과 그 색. 장비 = 그 장비의 전투력과, 지금 것과 바꾸면 달라지는 전투력(다른 직업의 무기 · 레벨이 모자라면 그 말만) · 묶음 = 그 아이템의 설명
--  me = { level, class } · worn = 내가 그 부위에 장착한 것(없으면 nil)
function V.sub(it, me, worn: any): (string, string)
	if it.item then
		return Items.goods(it.item).text or "", "dim"
	end
	local need = Items.needLevel(it)
	if it.slot == "weapon" and it.who ~= me.class then
		return IW.otherJob, "red"
	elseif me.level < need then
		return Format.fill(IW.needLv, { n = need }), "red"
	end
	-- 머리: 「★5 · 공격력 +73」(무기) · 「★2 · 올스탯 +9」(방어구 — 방어력은 상세 판에) — 2026-10-15 스펙(그 전에는 「전투력 +n」)
	local o = Items.options(it).total
	local head = if o.atk then ("%s %s"):format(IW.atk, Format.short(o.atk)) else ("%s %s"):format(IW.stat, Format.short(o.stat or 0)) -- 줄이 좁아 「+」 없이
	if it.star > 0 then
		head = ("★%d %s"):format(it.star, head)
	end
	local d = ItemInfo.wearDiff(it, worn, me.spec or ItemInfo.refSpec(me.level))
	if d > 0 then
		return head .. " · " .. Format.fill(IW.wearUp, { n = Format.short(d) }), "accent"
	elseif d < 0 then
		return head .. " · " .. Format.fill(IW.wearDown, { n = Format.short(-d) }), "dim"
	end
	return head, "dim"
end

-- 남은 시간: 한 시간부터는 「23시간 남음」, 그 아래는 「12분 남음」(끝났으면 빈 글)
function V.left(e: number, now: number): string
	local sec = e - now
	if sec <= 0 then
		return ""
	elseif sec >= 3600 then
		return Format.fill(W.left, { n = math.floor(sec / 3600) })
	end
	return Format.fill(W.leftMin, { n = math.max(1, math.ceil(sec / 60)) })
end
-- 언제 거래됐나(시세): 「5분 전」 · 「3시간 전」 · 「2일 전」
function V.ago(t: number, now: number): string
	local sec = math.max(0, now - t)
	if sec < 3600 then
		return Format.fill(W.agoMin, { n = math.max(1, math.floor(sec / 60)) })
	elseif sec < 86400 then
		return Format.fill(W.agoHour, { n = math.floor(sec / 3600) })
	end
	return Format.fill(W.agoDay, { n = math.floor(sec / 86400) })
end

-- 구매 목록의 차례: "price" = 받은 그대로(싼 것부터) · "time" = 곧 끝나는 것부터. 새 표를 돌려준다
function V.sortName(mode: string): string
	return if mode == "time" then W.sortTime else W.sortPrice
end
function V.nextSort(mode: string): string
	return if mode == "time" then "price" else "time"
end
function V.sort(rows, mode: string)
	local out = table.clone(rows)
	if mode == "time" then
		table.sort(out, function(a, b)
			if a.e ~= b.e then
				return a.e < b.e
			elseif a.p ~= b.p then
				return a.p < b.p
			end
			return a.id < b.id
		end)
	end
	return out
end

-- 이름으로 찾기: 그 글이 이름에 들어 있는 줄만(빈 글이면 모두). 영문은 대소문자를 가리지 않는다. 목록 · 시세 모두(줄에 it가 있다)
function V.filter(rows, query: string?)
	local q = string.lower((string.gsub(query or "", "^%s*(.-)%s*$", "%1")))
	if q == "" then
		return rows
	end
	local out = {}
	for _, r in rows do
		if string.find(string.lower(Market.nameOf(r.it)), q, 1, true) then
			table.insert(out, r)
		end
	end
	return out
end

-- 「판매 3 / 10」
function V.slots(used: number, max: number): string
	return Format.fill(W.slots, { n = used, max = max })
end

-- ---------- 구매: 묻는 글 ----------
-- 살 수 있는 가장 큰 수(남은 수 · 내 달돈으로)
function V.askMax(row, money: number): number
	return math.max(1, math.min(row.l or 1, math.floor(money / row.p)))
end
-- 묻는 글: 장비 = 「이름」 — 1,200 달돈에 구매할까요? · 묶음 = 「이름」 — 합계 1,500 달돈(수량은 그 옆의 칸에 적는다 — qty가 비었으면 0으로 셈한다)
function V.ask(row, qty: number?): string
	local it = Market.unpack(row.it)
	if not it then
		return "?"
	elseif it.item then
		return Format.fill(W.askSum, { name = V.bare(it), price = Format.comma(row.p * (qty or 0)) })
	end
	return Format.fill(W.ask, { name = V.name(it), price = Format.comma(row.p) })
end
-- 수량을 적는 칸: 숫자만 · 맨 앞의 0은 뗀다 · max를 넘으면 max로 → 고친 글, 그 수(비었으면 nil)
function V.count(text: string, max: number): (string, number?)
	local s = string.gsub(text, "%D", "")
	s = string.sub((string.gsub(s, "^0+", "")), 1, 4)
	local n = tonumber(s)
	if not n then
		return "", nil
	elseif n > max then
		return tostring(max), max
	end
	return s, n
end
-- 묶음의 올라온 수: 「남은 수량 10개」(구매 목록의 줄) · 「/ 10개」(수량 칸 옆)
function V.stock(n: number): string
	return Format.fill(W.stock, { n = n })
end
function V.of(n: number): string
	return Format.fill(W.of, { n = n })
end
-- 구매 목록의 한 줄에 적는 것: 이름 · 그 아래 한 줄 · 그 색. 묶음 = 이름(수는 빼고)과 「남은 수량 10개」 · 장비 = 이름 +별과 전투력
function V.rowText(it, me, worn: any): (string, string, string)
	if it.item then
		return V.bare(it), V.stock(it.n), "text"
	end
	local sub, tone = V.sub(it, me, worn)
	return V.name(it), sub, tone
end
-- 올라온 것을 눌렀을 때의 상세(아이템 상세 판 — ui/itemInfo.luau의 것): 묶음은 「가진 수」 대신 올라온 「수량」을 적는다
function V.info(it, me, worn: any)
	if it.item then
		local info = ItemInfo.goods(it.item, me, it.n)
		info.rows[1] = { W.count, Format.fill(W.units, { n = it.n }), "text" }
		return info
	end
	return ItemInfo.gear(it, me, worn, false)
end

-- ---------- 판매 ----------
-- 가방(서버가 보낸 꼴 — Bag.view)에서 올릴 수 있는 것들 { { tab, slot, it } … } — 탭의 차례(장비 · 소비 · 기타) · 칸의 차례대로
function V.sellables(bag)
	local out = {}
	if not bag then
		return out
	end
	for _, tab in D.BAG.keys do
		local list = bag[tab]
		for i = 1, bag.size do
			local it = list and list[i]
			if it and Market.sellable(it) then
				table.insert(out, { tab = tab, slot = i, it = it })
			end
		end
	end
	return out
end

-- 값을 적는 칸: 숫자만, 맨 앞의 0은 떼고, 자릿수를 넘지 않게
function V.digits(text: string): string
	local s = string.gsub(text, "%D", "")
	s = string.gsub(s, "^0+", "")
	return string.sub(s, 1, V.PRICE_DIGITS)
end

-- 판매 양식의 셈. n = 올리는 수(장비는 1) · priceText = 적은 값(개당) · money = 내 달돈
--  → { ok 올릴 수 있는가, price(개당), total(합계 = 개당 x 수), fee 다 팔렸을 때의 수수료, pay 다 팔렸을 때 받는 대금, deposit 보증금, short(보증금이 모자란가) }
function V.form(n: number, priceText: string, hours: any, money: number)
	local price = tonumber(V.digits(priceText))
	local short = money < M.deposit
	if not price or not Market.priceOk(price) then
		return { ok = false, price = nil, total = 0, fee = 0, pay = 0, deposit = M.deposit, short = short }
	end
	local total = price * n
	return { ok = Market.hoursOk(hours) and not short, price = price, total = total, fee = Market.fee(total), pay = Market.payout(total), deposit = M.deposit, short = short }
end

-- 판매 중인 것들(판매 탭) · 그 줄의 아래 글: 남은 시간(묶음은 「7 / 10개 남음」도)
function V.sellingRows(mine)
	local out = {}
	for _, r in mine or {} do
		if r.state == "selling" then
			table.insert(out, r)
		end
	end
	return out
end
function V.sellNote(row, now: number): string
	local left = V.left(row.e, now)
	if row.n > 1 then
		local remain = Format.fill(W.remain, { n = row.left, max = row.n })
		return if left ~= "" then left .. " · " .. remain else remain
	end
	return left
end

-- ---------- 완료 ----------
-- 받을 것들(완료 탭): 낙찰(산 것) → 「수령」 · 판매 완료(대금을 받지 않은 것) → 「대금 수령」 · 미판매(기간이 끝났거나 장부에 오르지 못했다) → 「반환」 「재등록」
--  → { { row, kind("won" · "sold" · "unsold"), it(그 줄에 그릴 물건 — 받을 수로), text, tone, amount(값 자리 — 없으면 nil), buttons = { { text, what, main } … } } … }
function V.doneRows(mine)
	local out = {}
	for _, r in mine or {} do
		if r.state == "hold" then
			table.insert(out, { row = r, kind = "won", it = r.it, text = W.won, tone = "accent", amount = nil, buttons = { { text = W.take, what = "take", main = true } } })
		elseif r.state == "soldout" or (r.state == "selling" and r.due > 0) then
			local text = if r.n > 1 then W.sold .. " · " .. Format.fill(W.soldN, { n = r.due }) else W.sold
			table.insert(out, { row = r, kind = "sold", it = Market.withUnits(r.it, math.max(1, r.due)), text = text, tone = "gold", amount = r.pay + r.deposit, buttons = { { text = W.collect, what = "collect", main = true } } })
		elseif r.state == "ended" or r.state == "back" then
			local text = W.unsold
			if r.n > 1 then
				text ..= " · " .. Format.fill(W.units, { n = r.left })
				if r.due > 0 then
					text ..= " · " .. Format.fill(W.soldN, { n = r.due })
				end
			end
			local buttons = { { text = W.giveBack, what = "back", main = false } }
			if r.left > 0 then
				table.insert(buttons, { text = W.relist, what = "relist", main = false })
			end
			local amount = r.pay + r.deposit
			table.insert(out, { row = r, kind = "unsold", it = Market.withUnits(r.it, math.max(1, r.left)), text = text, tone = "dim", amount = if amount > 0 then amount else nil, buttons = buttons })
		end
	end
	return out
end

-- ---------- 시세 ----------
-- 시세의 줄 아래 글: 묶음 = 「3개」 · 장비 = 빈 글
function V.tradeSub(it): string
	return if it.item then Format.fill(W.units, { n = it.n }) else ""
end

return V
