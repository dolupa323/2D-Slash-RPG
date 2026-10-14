-- 경매장의 셈 — 장부(저장소의 문서 하나)를 바꾸는 법과, 계정의 「맡긴 것」을 장부와 견주는 법. 저장소는 모른다(읽고 쓰는 것은 server/lune/modules/store.luau, 흐름은 world.luau).
--  사용자 2026-10-06: "경매장으로 전부 거래가능하게 할겁니다" · 2026-10-13: "경매장 부터 진행합시다.  알아서 조사하고 판단하고 해서  경매장 구현 해보세요"
--  **사용자 2026-10-13(처음 만든 것을 보고): "메이플 식 경매장을 말하는거긴합니다."** — 메이플스토리의 메이플 옥션 방식이다:
--    값을 매겨 올리고 그 값에 바로 산다(입찰 없음) · 소비와 기타 아이템은 **개당 가격**으로 올리고 **낱개로** 팔린다 · 올릴 때 보증금(다 팔리면 돌려받는다) ·
--    산 것 · 대금 · 안 팔린 것은 모두 「완료」에서 받는다(수령 · 대금 수령 · 반환 / 재등록) · 분류마다 최근 거래를 남겨 시세로 보여 준다.
--  규칙과 숫자는 공방 js/lune/design/economy.js의 AUCTION(→ data/items.generated.luau의 MARKET).
--
--  장부(분류마다 하나 — 무기는 직업마다 w_<직업> · 방어구는 부위마다 a_<부위> · 소비 u · 기타 e): { v = 2, list = { 줄 … }, log = { 최근 거래 … } }
--   줄 = { id, u = 판 사람(번호), sn = 그 캐릭터의 이름, it = 올린 물건(처음의 수 그대로), p = 값(개당), t = 올린 때, e = 기간이 끝나는 때(os.time),
--          l = 남은 수(장비는 1 → 0), c = 1(판 사람이 닫았다 — 더 팔리지 않는다. 없으면 열려 있다), b = 최근 구매 몇 건 { { u = 산 사람, q = 수, k = 그 구매의 표 } … } }
--   물건(it) = 장비 { slot, stage, q, star, who("" = 없음), fails, broken(0/1) } · 묶음 { g = 이름표, n = 수 }
--   최근 거래(log) = { { it = 그때 팔린 것(묶음은 팔린 수), p = 개당 값, t = 때 } … } — 새것이 뒤에. logMax건 · logDays일까지만 둔다.
--  한 줄은 장부의 UpdateAsync 한 번으로만 바뀐다(아래의 tx…는 그때 불리는 함수 — 받은 문서를 고치지 않고, 여러 번 불려도 같은 답을 낸다):
--    올리기 = 줄을 더한다 · 사기 = 남은 수를 줄인다 · 닫기 = 「닫았다」를 적는다(취소 · 반환 · 재등록의 첫걸음) · 매듭 = 줄을 지운다(판 사람의 계정이 저장된 뒤)
--   두 서버에서 같은 줄을 같이 사려 해도 남은 수만큼만 팔린다.
--
--  물건과 달돈이 복사되거나 사라지지 않게(계정의 「맡긴 것」 — acct.market.list):
--    판 것   [줄 번호] = { b = 장부, it = 올린 물건, p = 개당 값, t, e, got = 대금을 받은 수, d = 낸 보증금 }
--    산 것   ["h_…"]   = { hold = true, it = 산 물건, p = 치른 값, t } — 「완료」의 「낙찰」(「수령」하면 가방으로)
--   판 물건의 운명은 「맡긴 것」과 장부의 줄을 견주어 정한다(Market.resolve):
--     팔린 수 = 올린 수 − 줄의 남은 수 · 받을 대금 = (팔린 수 − got)개의 값. **대금을 받으면 got만 늘린다 — 장부는 고치지 않는다**(받은 것의 기록은 판 사람의 계정이다).
--     줄이 없다 → back(올린 것이 장부에 적히지 못했다 — 물건과 보증금이 돌아온다) · 보관 기간(KEEP)이 지났다 → void(사라진다)
--   올릴 때: 가방에서 빼 「맡긴 것」에 넣고 **계정을 먼저 저장한 뒤** 장부에 줄을 더한다.
--   끝낼 때(취소 · 반환 · 다 팔린 것): 줄을 닫는다(남은 수가 굳는다) → 남은 것을 돌려받고 대금을 받고 「맡긴 것」에서 지운다 → **계정을 저장한 뒤에야** 줄을 지운다.
--    도중에 서버가 꺼지면 「맡긴 것」과 닫힌 줄이 남아 있어 다음에 같은 셈을 다시 한다 — 같은 대금을 두 번 받거나 물건이 둘이 되는 길이 없다.
--   장부가 끝없이 불어나지 않게, 기간이 끝나고 KEEP이 지난 줄은 지운다(그때는 「맡긴 것」도 void다).
local Items = require(script.Parent.items)
local CLASSES = require(script.Parent.Parent.data["classes.generated"])

local D = Items.data
local M = D.MARKET

local Market = {}
Market.DATA = M
Market.WORDS = M.words
Market.WHY = M.words.why
Market.KEEP = M.keepDays * 86400 -- 기간이 끝난 뒤 보관하는 시간(초)
Market.LOG_KEEP = M.logDays * 86400 -- 시세에 남겨 두는 시간(초)
Market.VERSION = 2

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

-- ---------- 물건의 꼴 ----------
-- 가방의 것(장비 · 묶음 { item, n }) → 장부에 적는 꼴
function Market.pack(it: any)
	if typeof(it) ~= "table" then
		return nil
	elseif it.item ~= nil then
		return { g = it.item, n = it.n }
	end
	return { it.slot, it.stage, it.q, it.star, it.who or "", it.fails or 0, if it.broken then 1 else 0 }
end

-- 장부의 꼴 → 가방의 것(꼴이 맞지 않으면 nil). 장비에는 번호(id)가 없다 — 가방에 넣을 때 붙는다
function Market.unpack(row: any)
	if typeof(row) ~= "table" then
		return nil
	end
	if row.g ~= nil then
		local def = Items.goods(row.g)
		if not def or not whole(row.n, 1, def.stack) then
			return nil
		end
		return { item = row.g, n = row.n }
	end
	local it = { slot = row[1], stage = row[2], q = row[3], star = row[4], who = if row[5] ~= "" then row[5] else nil, fails = row[6], broken = row[7] == 1 }
	if not Items.valid(it) or not whole(it.fails, 0, 9) then
		return nil
	end
	if it.slot ~= "weapon" then
		it.who = nil
	end
	return it
end

-- 그 물건의 수(장비는 하나) · 같은 물건을 n개로(장비는 그대로 — 새 표를 돌려준다)
function Market.units(row: any): number
	if typeof(row) == "table" and row.g ~= nil then
		return if typeof(row.n) == "number" then row.n else 0
	end
	return 1
end
function Market.withUnits(row: any, n: number)
	if row.g ~= nil then
		return { g = row.g, n = n }
	end
	return table.clone(row)
end

-- 올릴 수 있는 물건인가 → true, 아니면 nil과 까닭. 퀘스트의 물건 · 부서진 장비는 못 올린다
function Market.sellable(it: any): (boolean?, string?)
	local row = Market.pack(it)
	local back = Market.unpack(row)
	if not back then
		return nil, Market.WHY.item
	end
	if back.item then
		local def = Items.goods(back.item)
		if def.quest then
			return nil, Market.WHY.quest
		end
	elseif back.broken then
		return nil, Market.WHY.item -- 부서진 장비(강화하다 부서진 것 — 되살려야 쓴다)는 올리지 못한다(내 판단: 모르고 사는 일이 없게)
	end
	return true
end

-- 그 물건이 올라가는 장부의 이름
function Market.boardOf(row: any): string?
	local it = Market.unpack(row)
	if not it then
		return nil
	elseif it.item then
		return if Items.goods(it.item).tab == "use" then "u" else "e"
	elseif it.slot == "weapon" then
		return "w_" .. tostring(it.who)
	end
	return "a_" .. it.slot
end

-- 화면의 분류: 무기(직업마다 장부가 다르다) · 방어구의 부위들 · 소비 · 기타 → { { id, name, weapon } … }
function Market.cats()
	local out = {}
	for _, slot in D.GEAR do
		local name = slot
		for _, def in D.SLOTS do
			if def.id == slot then
				name = def.name
			end
		end
		table.insert(out, { id = slot, name = name, weapon = slot == "weapon" })
	end
	table.insert(out, { id = "use", name = D.BAG.tabs[2], weapon = false })
	table.insert(out, { id = "etc", name = D.BAG.tabs[3], weapon = false })
	return out
end
function Market.catBoard(cat: string, class: string): string
	if cat == "weapon" then
		return "w_" .. class
	elseif cat == "use" then
		return "u"
	elseif cat == "etc" then
		return "e"
	end
	return "a_" .. cat
end
-- 있는 장부 모두(무기는 직업마다 · 방어구는 부위마다 · 소비 · 기타)
function Market.boards(): { string }
	local out = {}
	for _, id in CLASSES.order do
		table.insert(out, "w_" .. id)
	end
	for _, slot in D.GEAR do
		if slot ~= "weapon" then
			table.insert(out, "a_" .. slot)
		end
	end
	table.insert(out, "u")
	table.insert(out, "e")
	return out
end
-- 있는 장부의 이름인가(밖에서 온 글을 그대로 열쇠로 쓰지 않는다)
function Market.isBoard(key: any): boolean
	if typeof(key) ~= "string" then
		return false
	elseif key == "u" or key == "e" then
		return true
	end
	local kind, rest = string.match(key, "^(%a)_(%w+)$")
	if kind == "w" then
		return CLASSES.classes[rest] ~= nil
	elseif kind == "a" and rest ~= "weapon" then
		for _, slot in D.GEAR do
			if slot == rest then
				return true
			end
		end
	end
	return false
end

-- 글로 적는 물건의 이름(알림에 쓴다): 장비 = 이름 +별 · 묶음 = 이름 x수
function Market.nameOf(row: any): string
	local it = Market.unpack(row)
	if not it then
		return "?"
	elseif it.item then
		local def = Items.goods(it.item)
		return if it.n > 1 then ("%s x%d"):format(def.name, it.n) else def.name
	end
	local name = Items.name(it)
	return if it.star > 0 then ("%s +%d"):format(name, it.star) else name
end

-- ---------- 값 ----------
-- 값(개당)은 1부터 priceMax까지의 정수
function Market.priceOk(p: any): boolean
	return whole(p, 1, M.priceMax)
end
function Market.hoursOk(h: any): boolean
	for _, v in M.hours do
		if v == h then
			return true
		end
	end
	return false
end
-- 대금(amount)을 받을 때 떼는 수수료 · 받는 금액
function Market.fee(amount: number): number
	return math.floor(amount * M.fee / 100)
end
function Market.payout(amount: number): number
	return amount - Market.fee(amount)
end

-- ---------- 장부 ----------
-- 줄의 상태: "soldout"(다 팔렸다) · "ended"(판 사람이 닫았거나 기간이 끝났다 — 남은 것이 있다) · "selling"
function Market.stateOf(entry, now: number): string
	if entry.l <= 0 then
		return "soldout"
	elseif entry.c == 1 or now >= entry.e then
		return "ended"
	end
	return "selling"
end

-- 장부를 읽을 꼴로(없거나 꼴이 깨졌으면 빈 장부). 보관 기간이 지난 줄 · 오래된 거래 기록은 버린다. 받은 표는 건드리지 않고 새 표를 돌려준다
local function fresh(doc: any, now: number)
	local list, log = {}, {}
	if typeof(doc) == "table" and typeof(doc.list) == "table" then
		for _, e in doc.list do
			if typeof(e) == "table" and typeof(e.id) == "string" and typeof(e.e) == "number" and typeof(e.l) == "number" and now < e.e + Market.KEEP then
				local copy = table.clone(e) -- 받은 줄을 고치지 않는다(저장소가 이 함수를 다시 불러도 같은 답)
				copy.b = if typeof(e.b) == "table" then table.clone(e.b) else {}
				table.insert(list, copy)
			end
		end
	end
	if typeof(doc) == "table" and typeof(doc.log) == "table" then
		for _, r in doc.log do
			if typeof(r) == "table" and typeof(r.t) == "number" and now < r.t + Market.LOG_KEEP then
				table.insert(log, r)
			end
		end
		while #log > M.logMax do
			table.remove(log, 1)
		end
	end
	return { v = Market.VERSION, list = list, log = log }
end
Market.fresh = fresh

local function find(list, id: any)
	for i, e in list do
		if e.id == id then
			return e, i
		end
	end
	return nil, nil
end

-- 새 줄(price = 개당 값)
function Market.entry(id: string, userId: number, seller: string, row: any, price: number, hours: number, now: number)
	return { id = id, u = userId, sn = seller, it = row, p = price, t = now, e = now + hours * 3600, l = Market.units(row), b = {} }
end

-- 올린다: 새 장부, 아니면 nil과 까닭(판매 중인 줄이 cap에 찼다). 같은 번호가 이미 있으면 올린 것으로 친다(다시 불렸다)
function Market.txList(doc: any, entry, now: number)
	local out = fresh(doc, now)
	local selling = 0
	for _, e in out.list do
		if e.id == entry.id then
			return out, nil
		end
		if Market.stateOf(e, now) == "selling" then
			selling += 1
		end
	end
	if selling >= M.cap then
		return nil, Market.WHY.full
	end
	table.insert(out.list, entry)
	return out, nil
end

-- 그 줄에 그 표(token)의 구매가 적혀 있는가
local function bought(e, buyerId: number, token: string): boolean
	for _, r in e.b or {} do
		if typeof(r) == "table" and r.u == buyerId and r.k == token then
			return true
		end
	end
	return false
end

-- 산다: 새 장부와 그 줄, 아니면 nil과 까닭. q = 사는 수 · price = 사는 사람이 본 값(개당) · token = 이 구매의 표(같은 구매가 두 번 불려도 한 번만 친다)
function Market.txBuy(doc: any, id: any, buyerId: number, q: number, price: any, now: number, token: string)
	local out = fresh(doc, now)
	local e = find(out.list, id)
	if e and bought(e, buyerId, token) then
		return nil, nil, e -- 이 구매는 이미 적혀 있다(다시 불렸다): 그대로 둔다 — 산 것으로 친다
	elseif not e or e.l <= 0 or e.c == 1 then
		return nil, Market.WHY.gone, nil
	elseif now >= e.e then
		return nil, Market.WHY.expired, nil
	elseif e.u == buyerId then
		return nil, Market.WHY.mine, nil
	elseif e.p ~= price then
		return nil, Market.WHY.changed, nil
	elseif not whole(q, 1, e.l) then
		return nil, Market.WHY.count, nil
	end
	e.l -= q
	table.insert(e.b, { u = buyerId, q = q, k = token })
	while #e.b > M.lastBuys do
		table.remove(e.b, 1)
	end
	table.insert(out.log, { it = Market.withUnits(e.it, q), p = e.p, t = now })
	while #out.log > M.logMax do
		table.remove(out.log, 1)
	end
	return out, nil, e
end

-- 줄을 닫는다(판 사람이 — 취소 · 반환 · 재등록의 첫걸음): 더 팔리지 않고 남은 수가 굳는다. 돌려주는 것: 새 장부(바뀐 것이 없으면 nil), "closed" · "none"(줄이 없다), 굳은 남은 수
function Market.txClose(doc: any, id: any, userId: number, now: number)
	local out = fresh(doc, now)
	local e = find(out.list, id)
	if not e or e.u ~= userId then
		return nil, "none", 0
	elseif e.c == 1 then
		return nil, "closed", e.l
	end
	e.c = 1
	return out, "closed", e.l
end

-- 줄을 지운다(판 사람의 계정이 저장된 뒤 — 그 줄에서 받을 것을 다 받았다). 없으면 그대로
function Market.txSettle(doc: any, id: any, userId: number, now: number)
	local out = fresh(doc, now)
	local e, i = find(out.list, id)
	if not e or e.u ~= userId then
		return nil, "none"
	end
	table.remove(out.list, i)
	return out, "ok"
end

-- 그 사람의 줄을 모두 지운다(관리자의 시험 물건을 치울 때 — 판 사람의 번호가 0인 줄). 돌려주는 것: 새 장부(지운 것이 없으면 nil), 지운 수
function Market.txPurge(doc: any, userId: number, now: number)
	local out = fresh(doc, now)
	local kept, removed = {}, 0
	for _, e in out.list do
		if e.u == userId then
			removed += 1
		else
			table.insert(kept, e)
		end
	end
	if removed == 0 then
		return nil, 0
	end
	out.list = kept
	return out, removed
end

-- 사려는 사람에게 보여 줄 줄들: 판매 중인 것만, 싼 것부터(값이 같으면 먼저 올린 것부터) show개까지 → { { id, it(남은 수로), p(개당), sn, e, t, l, mine } … }
function Market.rows(doc: any, now: number, viewer: number?)
	local rows = {}
	for _, e in fresh(doc, now).list do
		if Market.stateOf(e, now) == "selling" and Market.unpack(e.it) then
			table.insert(rows, { id = e.id, it = Market.withUnits(e.it, e.l), p = e.p, sn = e.sn, e = e.e, t = e.t, l = e.l, mine = e.u == viewer })
		end
	end
	table.sort(rows, function(a, b)
		if a.p ~= b.p then
			return a.p < b.p
		elseif a.t ~= b.t then
			return a.t < b.t
		end
		return a.id < b.id
	end)
	while #rows > M.show do
		table.remove(rows)
	end
	return rows
end

-- 시세: 그 분류의 최근 거래(새것부터 show개까지) → { { it, p(개당), t } … }
function Market.trades(doc: any, now: number)
	local log = fresh(doc, now).log
	local out = {}
	for i = #log, 1, -1 do
		local r = log[i]
		if Market.unpack(r.it) and typeof(r.p) == "number" then
			table.insert(out, { it = r.it, p = r.p, t = r.t })
			if #out >= M.show then
				break
			end
		end
	end
	return out
end

-- 장부에서 그 번호의 줄(누구의 것이든)
function Market.entryById(doc: any, id: any)
	if typeof(doc) ~= "table" or typeof(doc.list) ~= "table" then
		return nil
	end
	for _, e in doc.list do
		if typeof(e) == "table" and e.id == id and typeof(e.l) == "number" then
			return e
		end
	end
	return nil
end
-- 그 줄에 그 사람의 그 구매(token)가 적혀 있으면 그 줄(저장소가 답하지 않았을 때 — 적혔는지 다시 읽어 본다)
function Market.boughtBy(doc: any, id: any, buyerId: number, token: string)
	local e = Market.entryById(doc, id)
	if e and bought(e, buyerId, token) then
		return e
	end
	return nil
end
-- 장부에서 내 줄을 찾는다. 보관 기간이 지난 줄은 없는 것으로 본다(장부를 고칠 때 버려지는 줄 — fresh와 같은 규칙: 그때는 맡긴 것도 void다)
function Market.entryIn(doc: any, id: string, userId: number, now: number)
	local e = Market.entryById(doc, id)
	if e and e.u == userId and typeof(e.e) == "number" and now < e.e + Market.KEEP then
		return e
	end
	return nil
end

-- ---------- 계정의 「맡긴 것」 ----------
-- 새 계정의 것
function Market.newBook()
	return { seq = 0, list = {} }
end

-- 다음 줄의 번호(판 사람 안에서 겹치지 않는다 · 사람 번호가 들어 있어 사람끼리도 겹치지 않는다)
function Market.nextId(book, userId: number, now: number): string
	book.seq += 1
	return ("%d_%d_%d"):format(userId, now, book.seq)
end
-- 구매 하나의 표(때와 차례 — 서버가 꺼졌다 켜져 차례가 되돌아가도 때가 달라 겹치지 않는다)
function Market.nextToken(book, now: number): string
	book.seq += 1
	return ("%d_%d"):format(now, book.seq)
end

-- 올려 둔 것의 수(다 받기 전의 것도 센다 — 판매 slots) · 받지 않은 구매품의 수(holdMax)
function Market.count(book): number
	local n = 0
	for _, h in book.list do
		if not h.hold then
			n += 1
		end
	end
	return n
end
function Market.holds(book): number
	local n = 0
	for _, h in book.list do
		if h.hold then
			n += 1
		end
	end
	return n
end

-- 「맡긴 것」 하나와 장부의 그 줄(없으면 nil)을 견준다 → { state, n(올린 수), left(장부에 남은 수 — 돌려받을 수), sold(팔린 수), due(대금을 아직 받지 않은 수) }
--  state: "hold"(산 것 — 수령할 것) · "selling" · "ended"(닫혔거나 기간이 끝났다 — 남은 것을 돌려받는다) · "soldout"(다 팔렸다) · "back"(줄이 없다 — 물건이 돌아온다) · "void"(보관 기간이 지났다)
function Market.resolve(handle, entry: any, now: number)
	if handle.hold then
		return { state = "hold", n = Market.units(handle.it), left = 0, sold = 0, due = 0 }
	end
	local n, got = Market.units(handle.it), handle.got or 0
	if not entry then
		local gone = now >= handle.e + Market.KEEP
		return { state = if gone then "void" else "back", n = n, left = math.max(0, n - got), sold = got, due = 0 }
	end
	local left = math.clamp(entry.l, 0, n)
	local sold = n - left
	return { state = Market.stateOf(entry, now), n = n, left = left, sold = sold, due = math.max(0, sold - got) }
end

-- 지금 받을 금액. r = resolve의 답 → { gross(팔린 값), fee(수수료), pay(대금 — 수수료를 뗀 것), deposit(돌려받는 보증금) }
--  보증금은 다 팔렸을 때(남은 수 0) 마지막 대금과 함께, 그리고 올린 것이 장부에 적히지 못했을 때(back) 돌아온다. 취소 · 미판매는 돌려받지 못한다(메이플 옥션)
function Market.amount(handle, r)
	local gross = r.due * handle.p
	local fee = Market.fee(gross)
	local deposit = 0
	if (r.state ~= "back" and r.left == 0) or (r.state == "back" and (handle.got or 0) == 0) then
		deposit = handle.d or 0
	end
	return { gross = gross, fee = fee, pay = gross - fee, deposit = deposit }
end

-- 저장할 꼴 · 읽기(꼴이 맞는 것만)
function Market.packBook(book)
	local rows = {}
	for id, h in book.list do
		table.insert(rows, { id = id, b = h.b or "", it = h.it, p = h.p or 0, t = h.t or 0, e = h.e or 0, got = h.got or 0, d = h.d or 0, hold = h.hold == true })
	end
	table.sort(rows, function(a, b)
		return a.id < b.id
	end)
	return { seq = book.seq, list = rows }
end
function Market.unpackBook(data: any)
	local book = Market.newBook()
	if typeof(data) ~= "table" then
		return book
	end
	book.seq = if whole(data.seq, 0, 9e9) then data.seq else 0
	if typeof(data.list) == "table" then
		for _, r in data.list do
			if typeof(r) == "table" and typeof(r.id) == "string" and #r.id <= 60 and Market.unpack(r.it) and whole(r.p, 0, 9e15) and whole(r.t, 0, 9e12) then
				if r.hold == true then
					book.list[r.id] = { hold = true, it = r.it, p = r.p, t = r.t, e = r.t }
				elseif Market.isBoard(r.b) and whole(r.e, 0, 9e12) then
					local n = Market.units(r.it)
					book.list[r.id] = { b = r.b, it = r.it, p = r.p, t = r.t, e = r.e, got = if whole(r.got, 0, n) then r.got else 0, d = if whole(r.d, 0, 9e9) then r.d else 0 }
				end
			end
		end
	end
	return book
end

return Market
