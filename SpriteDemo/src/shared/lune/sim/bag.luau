-- 가방 · 장비 · 창고 — 캐릭터(sim/hero.luau의 표)가 가진 물건을 다루는 셈. 장비 하나의 셈은 sim/items.luau.
--  사용자 2026-10-08: "지금 인벤토리 구조도 잘못되어있는데 … 품목이 고정되어있고 거기서 수량 1/8 이런식으로 표기하는게 인벤토리가 아닙니다."
--  → 가방은 탭 셋(gear 장비 · use 소비 · etc 기타)이고 탭마다 진짜 칸이다(메이플스토리의 가방 — 공방 js/lune/design/items.js의 BAGPLAY):
--    칸은 비어 있을 수 있고(false), 놓인 자리는 옮기기 전까지 그대로다. 장비는 한 칸에 하나, 소비 · 기타 아이템은 한 칸에 한 묶음({ item = 이름표, n = 수 } — 겹치는 수는 아이템마다).
--  창고도 가방과 같은 짜임이다(사용자 2026-10-08: "소비, 기타아이템도 창고에 맡길수있어야하고 … 창고에 드래그앤 드랍으로 맡기기가능해야합니다"): 탭 셋 · 탭마다 칸(길이 Bag.storeSize).
--  캐릭터의 표에 얹는 것: gear · use · etc(칸들 — 길이는 늘 Bag.size) · equip([부위] = 장비) · store({ gear · use · etc } — 창고의 칸들) · dust(달가루) · essence(보스의 정수) ·
--                        bagGrow(가방을 늘린 횟수 — 세 탭이 함께 늘어난다) · nextItem(다음 장비 번호)
--  달돈 · 달가루 · 정수는 칸을 차지하지 않는다(숫자로만 갖는다).
--  모든 함수는 되면 true(또는 결과), 안 되면 nil과 까닭(글)을 돌려준다. 어디서 할 수 있는지(주민 앞인지)는 서버(world.luau)가 본다.
local Items = require(script.Parent.items)

local D = Items.data
local BAG = D.BAG
local FULL = "가방이 가득 찼다"

local Bag = {}
Bag.TABS = BAG.keys -- { "gear", "use", "etc" } — 공방의 탭 차례(장비 · 소비 · 기타)
Bag.FULL = FULL

local function stamp(h, it)
	it.id = h.nextItem
	h.nextItem += 1
	return it
end

local function whole(v: any, min: number, max: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

local function blank(n: number)
	return table.create(n, false)
end

local function isTab(tab: any): boolean
	return tab == "gear" or tab == "use" or tab == "etc"
end

-- 새 캐릭터: 처음 받는 차림을 입고 있다. 가방은 비어 있다
function Bag.init(h)
	h.bagGrow = 0
	h.bagPaid = 0 -- 가방 확장권(유료)으로 늘린 번
	h.gear, h.use, h.etc = blank(BAG.base), blank(BAG.base), blank(BAG.base)
	h.equip = {}
	h.store = { gear = blank(BAG.storeBase), use = blank(BAG.storeBase), etc = blank(BAG.storeBase) }
	h.dust, h.essence, h.nextItem = 0, 0, 1
	for _, it in Items.kit(h.class) do
		h.equip[it.slot] = stamp(h, it)
	end
end

-- 탭 하나의 칸 수(세 탭이 같다)
function Bag.size(h): number
	return BAG.base + BAG.step * (h.bagGrow + (h.bagPaid or 0)) -- bagPaid = 가방 확장권으로 늘린 번(유료 — 2026-10-20 · sim/cash.luau)
end

-- 창고의 탭 하나의 칸 수(세 탭이 같다) — 24칸 + 계정이 받은 「창고 칸」 보상(h.storeExtra — 서버가 계정의 storeGot으로 맞춘다 · 2026-10-18)
function Bag.storeSize(h): number
	return BAG.storeBase + (if h and typeof(h.storeExtra) == "number" then h.storeExtra else 0)
end

-- 창고의 칸이 늘었다: 탭마다 빈 칸을 뒤에 붙인다(놓인 것은 그대로)
function Bag.growStore(h, extra: number)
	h.storeExtra = math.max(if typeof(h.storeExtra) == "number" then h.storeExtra else 0, extra) -- 줄이지는 않는다(2026-10-18 검토 — 줄면 뒤 칸의 것을 저장에서 잃는다)
	local size = Bag.storeSize(h)
	for _, tab in { "gear", "use", "etc" } do
		local list = h.store and h.store[tab]
		if list then
			for i = 1, size do
				if list[i] == nil then
					list[i] = false
				end
			end
		end
	end
end

-- ---------- 칸들에서의 셈(가방의 탭과 창고의 탭이 같이 쓴다) ----------  list = 칸들 · size = 그 길이
local function freeIn(list, size: number): number?
	for i = 1, size do
		if not list[i] then
			return i
		end
	end
	return nil
end

local function countIn(list, size: number, id: string): number
	local n = 0
	for i = 1, size do
		local s = list[i]
		if s and s.item == id then
			n += s.n
		end
	end
	return n
end

-- 그 아이템이 몇 개 더 들어가나(덜 찬 묶음의 남은 자리 + 빈 칸마다 한 묶음)
local function roomIn(list, size: number, def): number
	local room = 0
	for i = 1, size do
		local s = list[i]
		if not s then
			room += def.stack
		elseif s.item == def.id then
			room += def.stack - s.n
		end
	end
	return room
end

-- n개를 넣는다(들어갈 자리가 있는지는 부른 쪽이 본다): to가 비어 있거나 같은 묶음이면 그 칸부터, 그다음 같은 것이 든 칸, 넘치면 첫 빈 칸에 새 묶음
local function putIn(list, size: number, def, n: number, to: number?)
	local left = n
	if to and to >= 1 and to <= size then
		local s = list[to]
		if not s then
			local add = math.min(left, def.stack)
			list[to] = { item = def.id, n = add }
			left -= add
		elseif s.item == def.id then
			local add = math.min(left, def.stack - s.n)
			s.n += add
			left -= add
		end
	end
	for i = 1, size do
		local s = list[i]
		if left > 0 and s and s.item == def.id and s.n < def.stack then
			local add = math.min(left, def.stack - s.n)
			s.n += add
			left -= add
		end
	end
	for i = 1, size do
		if left > 0 and not list[i] then
			local add = math.min(left, def.stack)
			list[i] = { item = def.id, n = add }
			left -= add
		end
	end
end

-- 그 탭의 칸들과 길이: inStore = 창고의 것인가(아니면 가방)
local function slotsOf(h, tab: string, inStore: boolean?)
	if inStore then
		return h.store[tab], Bag.storeSize(h)
	end
	return h[tab], Bag.size(h)
end

local function firstFree(h, tab: string): number?
	return freeIn(h[tab], Bag.size(h))
end

-- 그 탭의 찬 칸 수 · 빈 칸 수(탭을 안 주면 장비 탭)
function Bag.used(h, tab: string?): number
	local list, n = h[tab or "gear"], 0
	for i = 1, Bag.size(h) do
		if list[i] then
			n += 1
		end
	end
	return n
end

function Bag.free(h, tab: string?): number
	return Bag.size(h) - Bag.used(h, tab)
end

-- 끼고 있는 장비들
function Bag.worn(h)
	local list = {}
	for _, it in h.equip do
		table.insert(list, it)
	end
	return list
end

-- 번호로 찾는다: 장비, 있는 곳("gear" · "equip" · "store"), 그 안의 자리(칸 번호나 부위)
function Bag.find(h, id: any)
	if typeof(id) ~= "number" then
		return nil
	end
	for i = 1, Bag.size(h) do
		local it = h.gear[i]
		if it and it.id == id then
			return it, "gear", i
		end
	end
	for slot, it in h.equip do
		if it.id == id then
			return it, "equip", slot
		end
	end
	for i = 1, Bag.storeSize(h) do
		local it = h.store.gear[i]
		if it and it.id == id then
			return it, "store", i
		end
	end
	return nil
end

-- 장비를 가방에 넣는다(주웠을 때 · 샀을 때): 장비 탭의 첫 빈 칸에. 들어간 칸을 돌려준다
function Bag.add(h, it): (number?, string?)
	local at = firstFree(h, "gear")
	if not at then
		return nil, FULL
	end
	h.gear[at] = stamp(h, it)
	return at
end

-- ---------- 소비 · 기타 아이템(묶음) ----------
-- 가방에 든 그 아이템의 수(모든 칸의 합)
function Bag.count(h, id: any): number
	local def = Items.goods(id)
	if not def then
		return 0
	end
	return countIn(h[def.tab], Bag.size(h), id)
end

-- 그 아이템이 몇 개 더 들어가나(덜 찬 묶음의 남은 자리 + 빈 칸마다 한 묶음)
function Bag.room(h, id: any): number
	local def = Items.goods(id)
	if not def then
		return 0
	end
	return roomIn(h[def.tab], Bag.size(h), def)
end

-- 아이템을 n개 넣는다: 같은 것이 든 칸부터 채우고, 넘치면 첫 빈 칸에 새 묶음. 다 들어가지 않으면 하나도 넣지 않는다
function Bag.give(h, id: any, n: any): (boolean?, string?)
	local def = Items.goods(id)
	if not def or not whole(n, 1, 1e6) then
		return nil, "없는 물건이다"
	elseif Bag.room(h, id) < n then
		return nil, FULL
	end
	putIn(h[def.tab], Bag.size(h), def, n, nil)
	return true
end

-- 아이템을 n개 덜어 낸다(앞 칸의 묶음부터). 모자라면 하나도 덜지 않는다
function Bag.take(h, id: any, n: any): (boolean?, string?)
	local def = Items.goods(id)
	if not def or not whole(n, 1, 1e6) or Bag.count(h, id) < n then
		return nil, "가진 것이 모자란다"
	end
	local list, left = h[def.tab], n
	for i = 1, Bag.size(h) do
		local s = list[i]
		if left > 0 and s and s.item == id then
			local cut = math.min(left, s.n)
			s.n -= cut
			left -= cut
			if s.n == 0 then
				list[i] = false
			end
		end
	end
	return true
end

-- ---------- 칸을 다루는 일 ----------
-- 칸의 것을 다른 칸으로 옮긴다: 빈 칸이면 옮기고, 다른 것이 있으면 자리를 바꾸고, 같은 소비 · 기타 아이템이면 합친다(넘치는 만큼은 남는다).
--  inStore = 창고 안에서 옮긴다(가방과 창고 사이는 Bag.storeIn · Bag.storeOut)
function Bag.move(h, tab: any, from: any, to: any, inStore: boolean?): (boolean?, string?)
	if not isTab(tab) then
		return nil, "옮길 수 없는 칸이다"
	end
	local list, size = slotsOf(h, tab, inStore)
	if not whole(from, 1, size) or not whole(to, 1, size) then
		return nil, "옮길 수 없는 칸이다"
	end
	local a, b = list[from], list[to]
	if not a then
		return nil, "빈 칸이다"
	elseif from == to then
		return true
	end
	if tab ~= "gear" and b and b.item == a.item then
		local add = math.min(a.n, Items.goods(a.item).stack - b.n)
		if add > 0 then
			b.n += add
			a.n -= add
			if a.n == 0 then
				list[from] = false
			end
			return true
		end
	end
	list[from], list[to] = b or false, a
	return true
end

-- 그 탭을 앞에서부터 채운다. 장비: 부위 → (무기는 내 직업의 것 먼저) → 레벨이 높은 것 → 성능 → 강화 — 부서진 것은 맨 뒤. 소비 · 기타: 같은 것끼리 합친 뒤 목록(GOODS)의 차례.
--  inStore = 창고의 그 탭을 정렬한다
function Bag.sort(h, tab: any, inStore: boolean?): (boolean?, string?)
	if not isTab(tab) then
		return nil, "없는 탭이다"
	end
	local list, size = slotsOf(h, tab, inStore)
	local next = blank(size)
	if tab == "gear" then
		local items = {}
		for i = 1, size do
			if list[i] then
				table.insert(items, list[i])
			end
		end
		table.sort(items, function(a, b)
			if a.broken ~= b.broken then
				return b.broken
			end
			local sa, sb = Items.slot(a.slot).order, Items.slot(b.slot).order
			if sa ~= sb then
				return sa < sb
			end
			local ma, mb = a.who == h.class, b.who == h.class
			if ma ~= mb then
				return ma
			elseif (a.who or "") ~= (b.who or "") then
				return (a.who or "") < (b.who or "")
			elseif a.stage ~= b.stage then
				return a.stage > b.stage
			elseif a.q ~= b.q then
				return a.q > b.q
			elseif a.star ~= b.star then
				return a.star > b.star
			end
			return a.id < b.id
		end)
		for i, it in items do
			next[i] = it
		end
	else
		local total, ids = {}, {}
		for i = 1, size do
			local s = list[i]
			if s then
				if not total[s.item] then
					total[s.item] = 0
					table.insert(ids, s.item)
				end
				total[s.item] += s.n
			end
		end
		table.sort(ids, function(a, b)
			return Items.goods(a).order < Items.goods(b).order
		end)
		local at = 1
		for _, id in ids do
			local stack, left = Items.goods(id).stack, total[id]
			while left > 0 do
				next[at] = { item = id, n = math.min(left, stack) }
				left -= next[at].n
				at += 1
			end
		end
	end
	if inStore then
		h.store[tab] = next
	else
		h[tab] = next
	end
	return true
end

-- 묶음을 나눈다: 그 칸의 묶음에서 n개를 덜어 빈 칸(to가 비어 있으면 그 칸, 아니면 첫 빈 칸)에 새 묶음으로 놓는다. 정렬하면 다시 합쳐진다
function Bag.split(h, tab: any, slot: any, n: any, to: any): (boolean?, string?)
	if tab ~= "use" and tab ~= "etc" then
		return nil, "묶음이 아니다"
	end
	local list, size = h[tab], Bag.size(h)
	if not whole(slot, 1, size) or not list[slot] then
		return nil, "빈 칸이다"
	end
	local s = list[slot]
	if not whole(n, 1, s.n - 1) then
		return nil, "나눌 수 없는 수다"
	end
	local at = if whole(to, 1, size) and not list[to] then to else freeIn(list, size)
	if not at then
		return nil, FULL
	end
	s.n -= n
	list[at] = { item = s.item, n = n }
	return true
end

-- 상점에 판다(어느 상점 앞인지는 서버가 본다). 받은 달돈을 돌려준다. n = 묶음에서 팔 수(안 주면 전부 — 장비는 늘 하나). 퀘스트의 물건은 팔 수 없다
-- ---------- 되사기(2026-10-18 — 메이플스토리의 재구매처럼) ----------
--  상점에 판 것을 이번 접속 동안 가장 최근 BUYBACK개까지 기억한다(저장하지 않는다 — 나갔다 들어오면 비어 있다). 판 값 그대로 되산다
Bag.BUYBACK = 10
local function remember(h, tab: string, thing, price: number)
	h.buyback = h.buyback or {}
	table.insert(h.buyback, 1, { tab = tab, thing = thing, price = price })
	while #h.buyback > Bag.BUYBACK do
		table.remove(h.buyback)
	end
end

-- 되산다: i = 되사기 목록의 차례(1 = 가장 최근에 판 것)
function Bag.buyBack(h, i: any): (boolean?, string?)
	local list = h.buyback or {}
	if not whole(i, 1, #list) then
		return nil, "없는 것이다"
	end
	local b = list[i]
	if h.money < b.price then
		return nil, "달돈이 모자란다"
	end
	if b.tab == "gear" then
		if Bag.free(h) <= 0 then
			return nil, FULL
		end
		Bag.add(h, b.thing)
	else
		local ok, why = Bag.give(h, b.thing.item, b.thing.n)
		if not ok then
			return nil, why
		end
	end
	h.money -= b.price
	table.remove(list, i)
	return true
end

function Bag.sell(h, tab: any, slot: any, n: any): (number?, string?)
	if not isTab(tab) or not whole(slot, 1, Bag.size(h)) or not h[tab][slot] then
		return nil, "빈 칸이다"
	end
	local e = h[tab][slot]
	if tab == "gear" then
		local price = Items.sellPrice(e)
		h.gear[slot] = false
		h.money += price
		remember(h, "gear", e, price)
		return price
	end
	local one = Items.goodsSell(e.item)
	if one <= 0 then
		return nil, "팔 수 없는 물건이다"
	end
	local count = if n == nil then e.n else n
	if not whole(count, 1, e.n) then
		return nil, "팔 수 없는 수다"
	end
	e.n -= count
	if e.n == 0 then
		h[tab][slot] = false
	end
	h.money += one * count
	remember(h, tab, { item = e.item, n = count }, one * count)
	return one * count
end

-- 소비 · 기타 아이템을 버린다(그 칸의 묶음에서 n개 — 되돌릴 수 없다). 장비는 버리지 않고 분해한다
function Bag.discard(h, tab: any, slot: any, n: any): (boolean?, string?)
	if tab ~= "use" and tab ~= "etc" then
		return nil, "장비는 분해한다"
	elseif not whole(slot, 1, Bag.size(h)) or not h[tab][slot] then
		return nil, "빈 칸이다"
	end
	local s = h[tab][slot]
	if not whole(n, 1, s.n) then
		return nil, "버릴 수 없는 수다"
	end
	s.n -= n
	if s.n == 0 then
		h[tab][slot] = false
	end
	return true
end

-- ---------- 장비 ----------
-- 낄 수 있는가
function Bag.canWear(h, it): (boolean?, string?)
	if it.broken then
		return nil, "부서진 장비다"
	elseif it.slot == "weapon" and it.who ~= h.class then
		return nil, "다른 직업의 무기다"
	elseif h.level < Items.needLevel(it) then
		return nil, ("Lv.%d부터 장착할 수 있다"):format(Items.needLevel(it))
	end
	return true
end

-- 가방의 장비를 낀다. 끼고 있던 것은 그 칸으로 들어간다(없었으면 그 칸은 빈다)
function Bag.equip(h, id: any): (boolean?, string?)
	local it, where, index = Bag.find(h, id)
	if not it or where ~= "gear" then
		return nil, "가방에 없는 장비다"
	end
	local ok, why = Bag.canWear(h, it)
	if not ok then
		return nil, why
	end
	h.gear[index] = h.equip[it.slot] or false
	h.equip[it.slot] = it
	return true
end

-- 끼고 있는 것을 가방으로(첫 빈 칸에 — to를 주면 그 칸이 비어 있을 때 그 칸에)
function Bag.unequip(h, slot: any, to: any): (boolean?, string?)
	local it = if typeof(slot) == "string" then h.equip[slot] else nil
	if not it then
		return nil, "장착하고 있지 않다"
	end
	local at = if whole(to, 1, Bag.size(h)) and not h.gear[to] then to else firstFree(h, "gear")
	if not at then
		return nil, FULL
	end
	h.equip[slot] = nil
	h.gear[at] = it
	return true
end

-- 가방의 장비를 분해한다. 나온 달가루를 돌려준다
function Bag.dismantle(h, id: any): (number?, string?)
	local it, where, index = Bag.find(h, id)
	if not it or where ~= "gear" then
		return nil, "가방에 없는 장비다"
	end
	local dust = Items.dismantle(it)
	h.gear[index] = false
	h.dust += dust
	return dust
end

-- 여러 개 분해(2026-10-22 사용자: "장비 분해를 한번에 여러개 할수있게 해달라"): ids = 장비 번호들 → 받은 달가루 · 분해한 수(가방에 없는 것 · 겹친 것은 건너뛴다 · 하나도 없으면 nil · 까닭)
Bag.BULK_MAX = 200
function Bag.dismantleMany(h, ids: any): (number?, string?, number?)
	if typeof(ids) ~= "table" then
		return nil, "고른 장비가 없다"
	end
	local n0 = 0
	for _ in ids do
		n0 += 1
		if n0 > Bag.BULK_MAX then
			return nil, "한 번에 너무 많다"
		end
	end
	local seen, total, n = {}, 0, 0
	for _, id in ids do
		if (typeof(id) == "number" or typeof(id) == "string") and not seen[id] then
			seen[id] = true
			local it, where, index = Bag.find(h, id)
			if it and where == "gear" then
				total += Items.dismantle(it)
				h.gear[index] = false
				n += 1
			end
		end
	end
	if n == 0 then
		return nil, "가방에 없는 장비다"
	end
	h.dust += total
	return total, nil, n
end

-- 가방을 늘리는 값(더 못 늘리면 nil)
function Bag.growCost(h): number?
	return BAG.costs[h.bagGrow + 1]
end

-- 가방을 늘린다: 세 탭이 함께 step칸씩 늘어난다
function Bag.grow(h): (boolean?, string?)
	local cost = Bag.growCost(h)
	if not cost then
		return nil, "더 늘릴 수 없다"
	elseif h.money < cost then
		return nil, "달돈이 모자란다"
	end
	h.money -= cost
	h.bagGrow += 1
	for _, tab in Bag.TABS do
		for i = #h[tab] + 1, Bag.size(h) do
			h[tab][i] = false
		end
	end
	return true
end

-- 가방 확장권(유료 — 2026-10-20): 달돈으로 늘리는 것과 같이 세 탭이 함께 step칸 는다. 몇 번까지인가는 부른 쪽(sim/cash.luau)이 본다
function Bag.growPaid(h)
	h.bagPaid = (h.bagPaid or 0) + 1
	for _, tab in Bag.TABS do
		for i = #h[tab] + 1, Bag.size(h) do
			h[tab][i] = false
		end
	end
end

-- 상점에서 산다. n = 몇 개(장비는 하나씩)
function Bag.buy(h, stockId: any, n: any): (boolean?, string?)
	local stock = if typeof(stockId) == "string" then Items.stock(stockId) else nil
	if not stock then
		return nil, "없는 물건이다"
	end
	if typeof(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > stock.max then
		return nil, "살 수 없는 수다"
	elseif h.level < stock.from then
		return nil, ("Lv.%d부터 산다"):format(stock.from)
	end
	local cost = Items.stockPrice(stock, h.level) * n
	if h.money < cost then
		return nil, "달돈이 모자란다"
	end
	if stock.goods then
		local ok, why = Bag.give(h, stock.goods, n)
		if not ok then
			return nil, why
		end
	elseif stock.id == "dust" then
		h.dust += n
	else
		if Bag.free(h) <= 0 then
			return nil, FULL
		end
		Bag.add(h, Items.make(stock.item.slot, stock.item.stage, D.NORMAL, h.class)) -- 상점의 것은 늘 보통
	end
	h.money -= cost
	return true
end

-- 제작(대장장이): 그 단계의 재료와 달돈으로 장비 한 벌을 만든다. 만든 장비를 돌려준다(안 되면 nil과 까닭).
--  만든 것의 성능은 보통 · 좋은 · 빼어난 가운데 하나다(낡은 · 허름한 것은 나오지 않는다). 재료는 가방의 기타 탭에서 빠진다
function Bag.craft(h, recipeId: any, rng)
	local r = Items.recipe(recipeId)
	if not r then
		return nil, "없는 제작법이다"
	elseif h.level < r.from then
		return nil, ("Lv.%d부터 만든다"):format(r.from)
	end
	for _, need in r.needs do
		if Bag.count(h, need.item) < need.n then
			return nil, "재료가 모자란다"
		end
	end
	if h.money < r.money then
		return nil, "달돈이 모자란다"
	elseif Bag.free(h) <= 0 then
		return nil, FULL
	end
	for _, need in r.needs do
		Bag.take(h, need.item, need.n)
	end
	h.money -= r.money
	local it = Items.make(r.slot, r.stage, Items.rollCraftQuality(rng), h.class)
	Bag.add(h, it)
	return it
end

-- 강화를 한 번 시도한다. 결과("ok" · "fail" · "drop" · "boom")를 돌려준다
function Bag.enhance(h, id: any, rng, guard: boolean?): (string?, string?)
	local it, where = Bag.find(h, id)
	if not it or where == "store" then
		return nil, "가진 장비가 아니다"
	end
	-- 그 캐릭터의 첫 강화: 달가루 없이 반드시 붙는다(한 번뿐). 별이 없는 장비에 첫 별을 붙일 때만이다 — 이 규칙이 생기기 전의 캐릭터가 높은 별에서 공짜로 넘어가지 못하게
	local first = Items.firstFree(h.forged, h.level, it) -- 제 레벨 + 10까지의 장비(사냥터에서 주운 조금 높은 것은 되게 · 2026-10-18 검토: 계정 창고의 훨씬 높은 장비에 공짜 첫 별을 붙이고 분해로 달가루를 받을 수 있었다)
	local info = Items.enhanceInfo(it, guard, first)
	if not info.can then
		return nil, if info.why == "상한" then "더 붙일 수 없다" else "부서진 장비다"
	elseif h.dust < info.dust then
		return nil, "달가루가 모자란다"
	elseif h.essence < info.essence then
		return nil, "정수가 모자란다"
	elseif where == "equip" and info.boom > 0 and Bag.free(h) <= 0 then
		-- 부서지면 흔적이 가방에 들어간다(부서진 것은 끼고 있을 수 없다) — 들어갈 칸이 있어야 시도한다
		return nil, "가방에 빈 칸이 하나 있어야 한다"
	end
	h.dust -= info.dust
	h.essence -= info.essence
	local result = Items.enhance(it, rng, guard, first)
	h.forged = true
	if result == "boom" and where == "equip" then
		h.equip[it.slot] = nil
		h.gear[firstFree(h, "gear") :: number] = it
	end
	return result
end

local function take(h, where: string, index: any)
	if where == "gear" then
		h.gear[index] = false
	elseif where == "equip" then
		h.equip[index] = nil
	end
end

-- (별 옮기기 Bag.transfer는 2026-10-15에 뺐다 — 사용자: "별을 옮겨올 장비는 뭐에요 이런거 하라고 한적없는데 왜 만든건지 이거 없애고")

-- 부서진 장비를 같은 장비 하나로 되살린다(spare는 가방에 있는 것 — 사라진다)
function Bag.restore(h, brokenId: any, spareId: any): (boolean?, string?)
	local it, where = Bag.find(h, brokenId)
	local spare, spareWhere, spareIndex = Bag.find(h, spareId)
	if not it or not spare or where ~= "gear" or spareWhere ~= "gear" or it == spare then
		return nil, "가방에 없는 장비다"
	elseif not Items.restore(it, spare) then
		return nil, "같은 장비가 아니다"
	end
	h.gear[spareIndex] = false
	return true
end

-- 한쪽 칸들(src)의 것을 다른 쪽 칸들(dst — 같은 탭)로 나른다: 가방 → 창고 · 창고 → 가방.
--  n = 묶음에서 나를 수(안 주면 전부 — 장비는 늘 하나). to = 놓을 칸(비어 있거나 같은 묶음일 때만 그 칸부터 — 아니면 알아서: 같은 묶음에 겹치고 넘치면 첫 빈 칸).
--  다 들어가지 않으면 하나도 나르지 않는다(fullWhy)
local function carry(tab: any, src, srcSize: number, dst, dstSize: number, slot: any, n: any, to: any, fullWhy: string): (boolean?, string?)
	if not whole(slot, 1, srcSize) or not src[slot] then
		return nil, "빈 칸이다"
	end
	local e = src[slot]
	local want = if whole(to, 1, dstSize) then to else nil
	if tab == "gear" then
		local at = if want and not dst[want] then want else freeIn(dst, dstSize)
		if not at then
			return nil, fullWhy
		end
		src[slot] = false
		dst[at] = e
		return true
	end
	local def = Items.goods(e.item)
	local count = if n == nil then e.n else n
	if not whole(count, 1, e.n) then
		return nil, "옮길 수 없는 수다"
	elseif roomIn(dst, dstSize, def) < count then
		return nil, fullWhy
	end
	putIn(dst, dstSize, def, count, want)
	e.n -= count
	if e.n == 0 then
		src[slot] = false
	end
	return true
end

-- 가방의 칸의 것을 창고에 맡긴다(같은 탭의 창고로 — 장비 · 소비 · 기타 모두). n = 묶음에서 맡길 수(안 주면 전부) · to = 놓을 창고 칸(끌어다 놓은 칸 — 안 주면 알아서)
Bag.NO_STORE = "퀘스트 물건은 맡길 수 없다"
function Bag.storeIn(h, tab: any, slot: any, n: any, to: any): (boolean?, string?)
	if not isTab(tab) then
		return nil, "없는 탭이다"
	end
	-- 퀘스트 물건은 맡기지 않는다(메이플처럼 — 2026-10-18 검토): 창고는 계정의 캐릭터가 같이 써서, 한 캐릭터가 모은 것을 다른 캐릭터가 꺼내 그 퀘스트를 바로 끝냈다
	local e = if tab ~= "gear" and whole(slot, 1, Bag.size(h)) then h[tab][slot] else nil
	if e and Items.goods(e.item) and Items.goods(e.item).kind == "quest" then
		return nil, Bag.NO_STORE
	end
	return carry(tab, h[tab], Bag.size(h), h.store[tab], Bag.storeSize(h), slot, n, to, "창고가 가득 찼다")
end

-- 창고의 칸의 것을 가방으로 찾는다. n = 묶음에서 찾을 수(안 주면 전부) · to = 놓을 가방 칸
function Bag.storeOut(h, tab: any, slot: any, n: any, to: any): (boolean?, string?)
	if not isTab(tab) then
		return nil, "없는 탭이다"
	end
	return carry(tab, h.store[tab], Bag.storeSize(h), h[tab], Bag.size(h), slot, n, to, FULL)
end

-- 창고의 그 탭에 찬 칸 수
function Bag.stored(h, tab: string?): number
	local list, n = h.store[tab or "gear"], 0
	for i = 1, Bag.storeSize(h) do
		if list[i] then
			n += 1
		end
	end
	return n
end

-- ---------- 저장 ----------
local function packItem(it)
	return { it.slot, it.stage, it.q, it.star, it.who or "", it.fails or 0, if it.broken then 1 else 0 }
end

local function unpackItem(row: any)
	if typeof(row) ~= "table" then
		return nil
	end
	local it = { slot = row[1], stage = row[2], q = row[3], star = row[4], who = if row[5] ~= "" then row[5] else nil, fails = row[6], broken = row[7] == 1 }
	-- 별이 그 단계의 상한을 넘으면(설계의 상한이 줄었다) 장비를 버리지 않고 상한으로 맞춘다(2026-10-18 검토)
	if typeof(it.stage) == "number" and it.stage >= 1 and it.stage <= 200 and typeof(it.star) == "number" and it.star > Items.starCap(it.stage) then
		it.star = Items.starCap(it.stage)
	end
	if not Items.valid(it) or typeof(it.fails) ~= "number" or it.fails < 0 or it.fails > 9 then
		return nil
	end
	if it.slot ~= "weapon" then
		it.who = nil
	end
	return it
end

-- 칸들을 저장할 꼴로: 칸의 차례 그대로(빈 칸은 false), 맨 뒤의 빈 칸들은 뺀다
local function packSlots(list, size: number, one)
	local out, last = {}, 0
	for i = 1, size do
		if list[i] then
			last = i
		end
	end
	for i = 1, last do
		local v = list[i]
		out[i] = if v then one(v) else false
	end
	return out
end

local function packStack(s)
	return { s.item, s.n }
end

function Bag.pack(h)
	local size, storeSize = Bag.size(h), Bag.storeSize(h)
	local out = { equip = {}, dust = h.dust, essence = h.essence, grow = h.bagGrow, paid = h.bagPaid or 0 }
	out.gear = packSlots(h.gear, size, packItem)
	out.use = packSlots(h.use, size, packStack)
	out.etc = packSlots(h.etc, size, packStack)
	for _, it in h.equip do
		table.insert(out.equip, packItem(it))
	end
	-- 창고: 가방과 같은 꼴(탭마다 칸들)
	out.store = Bag.packStore(h)
	return out
end

-- 창고만 저장할 꼴로. 창고는 계정의 캐릭터들이 같이 쓴다(사용자 2026-10-10) — 서버가 이것을 캐릭터가 아니라 계정에 적는다(sim/account.luau)
function Bag.packStore(h)
	local storeSize = Bag.storeSize(h)
	return { gear = packSlots(h.store.gear, storeSize, packItem), use = packSlots(h.store.use, storeSize, packStack), etc = packSlots(h.store.etc, storeSize, packStack) }
end

-- 저장된 묶음 칸들을 읽는다(꼴이 맞는 것만 — 없는 아이템 · 다른 탭의 것 · 겹치는 수를 넘는 것은 버린다)
local function unpackStacks(list, size: number, tab: string, rows: any)
	if typeof(rows) ~= "table" then
		return
	end
	-- 겹치는 수를 넘는 묶음(설계의 겹치는 수가 줄었다)은 버리지 않고 그 수로 맞춘 뒤 넘친 것을 빈 칸에 나눠 놓는다(2026-10-18 검토 — 전에는 묶음째 버렸다)
	local over = {}
	for i = 1, size do
		local row = rows[i]
		local def = if typeof(row) == "table" then Items.goods(row[1]) else nil
		if def and def.tab == tab and whole(row[2], 1, 1e6) then
			list[i] = { item = def.id, n = math.min(row[2], def.stack) }
			if row[2] > def.stack then
				table.insert(over, { def = def, n = row[2] - def.stack })
			end
		end
	end
	for _, o in over do
		for i = 1, size do
			if o.n <= 0 then
				break
			end
			if not list[i] then
				local n = math.min(o.n, o.def.stack)
				list[i] = { item = o.def.id, n = n }
				o.n -= n
			end
		end
	end
end

-- 저장된 창고를 캐릭터에 얹는다(있던 창고는 비우고 새로 채운다 — 꼴이 이상한 것은 버린다). store가 없으면 빈 창고.
--  창고는 계정의 것이라, 캐릭터로 들어갈 때 서버가 계정의 창고를 이것으로 얹는다(새로 만든 캐릭터에게도).
--  탭마다 칸들. 예전 저장(창고가 장비만 맡던 때 — 장비를 차례로 늘어놓은 것)은 장비 탭의 앞 칸부터 그대로 놓는다
function Bag.loadStore(h, store: any)
	local storeSize = Bag.storeSize(h)
	-- 저장된 것이 지금의 칸 수보다 뒤에 있으면(퀘스트의 「창고 칸」 보상 자료가 줄었다 등) 그만큼 칸을 늘려 둔다 — 물건을 잃지 않게(2026-10-18 검토). 망가진 저장에 대비해 200칸까지
	if typeof(store) == "table" then
		local far = 0
		for _, rows in { if typeof(store.gear) == "table" then store.gear else store, store.use, store.etc } do
			if typeof(rows) == "table" then
				for i, row in rows do
					if typeof(i) == "number" and i == math.floor(i) and typeof(row) == "table" and i > far then
						far = i
					end
				end
			end
		end
		far = math.min(far, 200)
		if far > storeSize then
			h.storeExtra = far - BAG.storeBase
			storeSize = far
		end
	end
	h.store = { gear = blank(storeSize), use = blank(storeSize), etc = blank(storeSize) }
	if typeof(store) ~= "table" then
		return
	end
	local gearRows = if typeof(store.gear) == "table" then store.gear else store
	for i = 1, storeSize do
		local it = unpackItem(gearRows[i])
		if it then
			h.store.gear[i] = stamp(h, it)
		end
	end
	unpackStacks(h.store.use, storeSize, "use", store.use)
	unpackStacks(h.store.etc, storeSize, "etc", store.etc)
end

-- 저장된 것을 캐릭터에 얹는다. 저장된 것이 없으면(장비가 생기기 전의 캐릭터) 처음 차림 그대로 둔다. 꼴이 이상한 것은 버린다.
--  돌려주는 것: 소비 · 기타 칸이 생기기 전에 저장된 것인가(true면 부른 쪽 — sim/hero.luau — 이 예전의 물약 수와 퀘스트의 숫자를 아이템으로 옮겨 준다)
function Bag.unpack(h, data: any): boolean
	if typeof(data) ~= "table" or typeof(data.gear) ~= "table" or typeof(data.equip) ~= "table" then
		return true -- 저장된 가방이 없다: Bag.init이 만든 것 그대로(창고도 빈 채로)
	end
	h.equip, h.nextItem = {}, 1
	h.bagGrow = if whole(data.grow, 0, BAG.times) then data.grow else 0
	h.bagPaid = if whole(data.paid, 0, 16) then data.paid else 0 -- 가방 확장권(유료)으로 늘린 번 — 생기기 전의 저장 = 0
	h.dust = if whole(data.dust, 0, 9e15) then data.dust else 0
	h.essence = if whole(data.essence, 0, 9e9) then data.essence else 0
	-- 저장된 것이 지금의 가방 칸 수보다 뒤에 있으면(설계의 가방 칸이 줄었다) 넓히기를 그만큼 더 쳐 둔다 — 물건을 잃지 않게(창고의 loadStore와 같다 · 2026-10-18 검토)
	do
		local far = 0
		for _, key in { "gear", "use", "etc" } do
			if typeof(data[key]) == "table" then
				for i, v in data[key] do
					if typeof(i) == "number" and v and i > far then
						far = i
					end
				end
			end
		end
		while Bag.size(h) < far and h.bagGrow < BAG.times do
			h.bagGrow += 1
		end
	end
	local size, storeSize = Bag.size(h), Bag.storeSize(h)
	h.gear, h.use, h.etc = blank(size), blank(size), blank(size)
	for _, row in data.equip do
		local it = unpackItem(row)
		if it and not h.equip[it.slot] and not it.broken and (it.slot ~= "weapon" or it.who == h.class) then
			h.equip[it.slot] = stamp(h, it)
		end
	end
	-- 장비 칸: 저장된 차례가 곧 칸이다(칸이 생기기 전의 저장은 빈 데 없이 앞에서부터 — 그대로 앞 칸들에 놓인다)
	for i = 1, size do
		local it = unpackItem(data.gear[i])
		if it then
			h.gear[i] = stamp(h, it)
		end
	end
	Bag.loadStore(h, data.store)
	local legacy = typeof(data.use) ~= "table" or typeof(data.etc) ~= "table"
	if not legacy then
		unpackStacks(h.use, size, "use", data.use)
		unpackStacks(h.etc, size, "etc", data.etc)
	end
	return legacy
end

-- ---------- 클라이언트에 보내는 것 ----------
local function viewItem(it)
	return { id = it.id, slot = it.slot, stage = it.stage, q = it.q, star = it.star, who = it.who, broken = it.broken, fails = it.fails or 0 }
end

-- 칸들을 보낼 꼴로(길이 size — 빈 칸은 false)
local function viewSlots(src, size: number)
	local out = { gear = blank(size), use = blank(size), etc = blank(size) }
	for i = 1, size do
		local it = src.gear[i]
		if it then
			out.gear[i] = viewItem(it)
		end
		for _, tab in { "use", "etc" } do
			local s = src[tab][i]
			if s then
				out[tab][i] = { item = s.item, n = s.n }
			end
		end
	end
	return out
end

-- gear · use · etc = 가방의 칸들(길이 size — 빈 칸은 false). 소비 · 기타의 칸 = { item = 이름표, n = 수 }. store = 창고({ gear · use · etc } — 길이 storeSize)
function Bag.view(h)
	local size = Bag.size(h)
	local out = viewSlots(h, size)
	out.equip, out.size, out.storeSize = {}, size, Bag.storeSize(h)
	out.dust, out.essence, out.growCost = h.dust, h.essence, Bag.growCost(h) or false
	out.store = viewSlots(h.store, out.storeSize)
	for slot, it in h.equip do
		out.equip[slot] = viewItem(it)
	end
	-- 되사기 목록(가장 최근에 판 것부터): 장비 = gear(그 장비) · 소비 · 기타 = item · n · 값
	out.buyback = {}
	for i, b in h.buyback or {} do
		out.buyback[i] = if b.tab == "gear" then { gear = viewItem(b.thing), price = b.price } else { item = b.thing.item, n = b.thing.n, price = b.price }
	end
	return out
end

-- 가득 찬 탭들(2026-10-18 — 보낸 것(Bag.view)에서): "gear" · "use" · "etc" 가운데 빈 칸이 없는 것. 화면이 가방 단추에 점을 찍고 획득 알림에 알린다
Bag.TABS = { "gear", "use", "etc" }
function Bag.fullTabs(view): { string }
	local out = {}
	for _, tab in Bag.TABS do
		local list = view and view[tab]
		if list then
			local free = false
			for i = 1, view.size or #list do
				if not list[i] then
					free = true
					break
				end
			end
			if not free then
				table.insert(out, tab)
			end
		end
	end
	return out
end

-- 보낸 것(Bag.view)에서 그 아이템의 수를 센다(클라이언트가 퀵슬롯의 숫자 · 상세 판에 쓴다)
function Bag.countIn(view, id: any): number
	local def = Items.goods(id)
	if not def or not view or not view[def.tab] then
		return 0
	end
	local n = 0
	for _, s in view[def.tab] do
		if s and s.item == id then
			n += s.n
		end
	end
	return n
end

-- 보낸 것(Bag.view)에서 그 아이템이 가방에 몇 개 더 들어가나(Bag.room과 같은 셈 — 수량 창이 「최대」를 정한다 · 2026-10-21)
function Bag.roomInView(view, id: any): number
	local def = Items.goods(id)
	if not def or not view or not view[def.tab] then
		return 0
	end
	return roomIn(view[def.tab], view.size or #view[def.tab], def)
end
-- 창고에 몇 개 더 들어가나(보낸 것의 store · storeSize에서)
function Bag.storeRoomInView(view, id: any): number
	local def = Items.goods(id)
	if not def or not view or not view.store or not view.store[def.tab] then
		return 0
	end
	return roomIn(view.store[def.tab], view.storeSize or #view.store[def.tab], def)
end

return Bag
