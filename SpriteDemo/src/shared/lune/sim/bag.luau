-- 가방 · 장비 · 창고 — 캐릭터(sim/hero.luau의 표)가 가진 물건을 다루는 셈. 장비 하나의 셈은 sim/items.luau.
--  캐릭터의 표에 얹는 것: gear(가방의 장비 탭 — 차례가 곧 칸) · equip([부위] = 장비) · store(창고) · dust(달가루) · essence(보스의 정수) ·
--                        bagGrow(가방을 늘린 횟수) · nextItem(다음 장비 번호)
--  모든 함수는 되면 true(또는 결과), 안 되면 nil과 까닭(글)을 돌려준다. 어디서 할 수 있는지(주민 앞인지)는 서버(world.luau)가 본다.
local Items = require(script.Parent.items)

local D = Items.data
local BAG = D.BAG

local Bag = {}

local function stamp(h, it)
	it.id = h.nextItem
	h.nextItem += 1
	return it
end

-- 새 캐릭터: 처음 받는 차림을 입고 있다
function Bag.init(h)
	h.gear, h.equip, h.store = {}, {}, {}
	h.dust, h.essence, h.bagGrow, h.nextItem = 0, 0, 0, 1
	for _, it in Items.kit(h.class) do
		h.equip[it.slot] = stamp(h, it)
	end
end

function Bag.size(h): number
	return BAG.base + BAG.step * h.bagGrow
end

function Bag.storeSize(_h): number
	return BAG.storeBase
end

function Bag.free(h): number
	return Bag.size(h) - #h.gear
end

-- 물약을 얼마나 더 가질 수 있나(쓰는 것 탭의 칸마다 한 묶음)
function Bag.potionMax(h): number
	return BAG.potionStack * Bag.size(h)
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
	for i, it in h.gear do
		if it.id == id then
			return it, "gear", i
		end
	end
	for slot, it in h.equip do
		if it.id == id then
			return it, "equip", slot
		end
	end
	for i, it in h.store do
		if it.id == id then
			return it, "store", i
		end
	end
	return nil
end

-- 가방에 넣는다(주웠을 때 · 샀을 때)
function Bag.add(h, it): (boolean?, string?)
	if Bag.free(h) <= 0 then
		return nil, "가방이 가득 찼다"
	end
	table.insert(h.gear, stamp(h, it))
	return true
end

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

-- 가방의 장비를 낀다. 끼고 있던 것은 그 칸으로 들어간다
function Bag.equip(h, id: any): (boolean?, string?)
	local it, where, index = Bag.find(h, id)
	if not it or where ~= "gear" then
		return nil, "가방에 없는 장비다"
	end
	local ok, why = Bag.canWear(h, it)
	if not ok then
		return nil, why
	end
	local old = h.equip[it.slot]
	h.equip[it.slot] = it
	if old then
		h.gear[index] = old
	else
		table.remove(h.gear, index)
	end
	return true
end

function Bag.unequip(h, slot: any): (boolean?, string?)
	local it = if typeof(slot) == "string" then h.equip[slot] else nil
	if not it then
		return nil, "장착하고 있지 않다"
	elseif Bag.free(h) <= 0 then
		return nil, "가방이 가득 찼다"
	end
	h.equip[slot] = nil
	table.insert(h.gear, it)
	return true
end

-- 가방의 장비를 분해한다. 나온 달가루를 돌려준다
function Bag.dismantle(h, id: any): (number?, string?)
	local it, where, index = Bag.find(h, id)
	if not it or where ~= "gear" then
		return nil, "가방에 없는 장비다"
	end
	local dust = Items.dismantle(it)
	table.remove(h.gear, index)
	h.dust += dust
	return dust
end

-- 가방을 늘리는 값(더 못 늘리면 nil)
function Bag.growCost(h): number?
	return BAG.costs[h.bagGrow + 1]
end

function Bag.grow(h): (boolean?, string?)
	local cost = Bag.growCost(h)
	if not cost then
		return nil, "더 늘릴 수 없다"
	elseif h.money < cost then
		return nil, "달돈이 모자란다"
	end
	h.money -= cost
	h.bagGrow += 1
	return true
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
	if stock.id == "potion" then
		if h.potions + n > Bag.potionMax(h) then
			return nil, "물약을 더 가질 수 없다"
		end
		h.potions += n
	elseif stock.id == "dust" then
		h.dust += n
	else
		if Bag.free(h) <= 0 then
			return nil, "가방이 가득 찼다"
		end
		Bag.add(h, Items.make(stock.item.slot, stock.item.stage, D.NORMAL, h.class)) -- 상점의 것은 늘 보통
	end
	h.money -= cost
	return true
end

-- 강화를 한 번 시도한다. 결과("ok" · "fail" · "drop" · "boom")를 돌려준다
function Bag.enhance(h, id: any, rng, guard: boolean?): (string?, string?)
	local it, where = Bag.find(h, id)
	if not it or where == "store" then
		return nil, "가진 장비가 아니다"
	end
	local info = Items.enhanceInfo(it, guard)
	if not info.can then
		return nil, if info.why == "상한" then "더 붙일 수 없다" else "부서진 장비다"
	elseif h.dust < info.dust then
		return nil, "달가루가 모자란다"
	elseif h.essence < info.essence then
		return nil, "정수가 모자란다"
	end
	h.dust -= info.dust
	h.essence -= info.essence
	local result = Items.enhance(it, rng, guard)
	if result == "boom" and where == "equip" then
		-- 부서진 것은 끼고 있을 수 없다 — 가방으로(가득 찼어도 흔적은 들어간다)
		h.equip[it.slot] = nil
		table.insert(h.gear, it)
	end
	return result
end

local function take(h, where: string, index: any)
	if where == "gear" then
		table.remove(h.gear, index)
	elseif where == "equip" then
		h.equip[index] = nil
	end
end

-- 별 옮기기: from의 별(하나 낮춰)을 to로. from은 사라진다. 끼고 있던 것을 옮겼으면 새것을 낀다(낄 수 있을 때)
function Bag.transfer(h, fromId: any, toId: any): (boolean?, string?)
	local from, fromWhere, fromIndex = Bag.find(h, fromId)
	local to, toWhere = Bag.find(h, toId)
	if not from or not to or fromWhere == "store" or toWhere == "store" or from == to then
		return nil, "가진 장비가 아니다"
	elseif from.slot ~= to.slot then
		return nil, "같은 부위끼리만 옮긴다"
	elseif from.broken or to.broken then
		return nil, "부서진 장비다"
	elseif Items.transfer(from, to) <= to.star then
		return nil, "옮길 별이 없다"
	end
	to.star = Items.transfer(from, to)
	to.fails = 0
	take(h, fromWhere, fromIndex)
	if fromWhere == "equip" and toWhere == "gear" and Bag.canWear(h, to) then
		Bag.equip(h, to.id)
	end
	return true
end

-- 부서진 장비를 같은 장비 하나로 되살린다(spare는 가방에 있는 것 — 사라진다)
function Bag.restore(h, brokenId: any, spareId: any): (boolean?, string?)
	local it, where = Bag.find(h, brokenId)
	local spare, spareWhere, spareIndex = Bag.find(h, spareId)
	if not it or not spare or where ~= "gear" or spareWhere ~= "gear" or it == spare then
		return nil, "가방에 없는 장비다"
	elseif not Items.restore(it, spare) then
		return nil, "같은 장비가 아니다"
	end
	table.remove(h.gear, spareIndex)
	return true
end

function Bag.storeIn(h, id: any): (boolean?, string?)
	local it, where, index = Bag.find(h, id)
	if not it or where ~= "gear" then
		return nil, "가방에 없는 장비다"
	elseif #h.store >= Bag.storeSize(h) then
		return nil, "창고가 가득 찼다"
	end
	table.remove(h.gear, index)
	table.insert(h.store, it)
	return true
end

function Bag.storeOut(h, id: any): (boolean?, string?)
	local it, where, index = Bag.find(h, id)
	if not it or where ~= "store" then
		return nil, "창고에 없는 장비다"
	elseif Bag.free(h) <= 0 then
		return nil, "가방이 가득 찼다"
	end
	table.remove(h.store, index)
	table.insert(h.gear, it)
	return true
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
	if not Items.valid(it) or typeof(it.fails) ~= "number" or it.fails < 0 or it.fails > 9 then
		return nil
	end
	if it.slot ~= "weapon" then
		it.who = nil
	end
	return it
end

function Bag.pack(h)
	local out = { gear = {}, equip = {}, store = {}, dust = h.dust, essence = h.essence, grow = h.bagGrow }
	for i, it in h.gear do
		out.gear[i] = packItem(it)
	end
	for _, it in h.equip do
		table.insert(out.equip, packItem(it))
	end
	for i, it in h.store do
		out.store[i] = packItem(it)
	end
	return out
end

-- 저장된 것을 캐릭터에 얹는다. 저장된 것이 없으면(장비가 생기기 전의 캐릭터) 처음 차림 그대로 둔다. 꼴이 이상한 장비는 버린다.
function Bag.unpack(h, data: any)
	if typeof(data) ~= "table" or typeof(data.gear) ~= "table" or typeof(data.equip) ~= "table" then
		return
	end
	local function whole(v, min, max)
		return typeof(v) == "number" and v == math.floor(v) and v >= min and v <= max
	end
	h.gear, h.equip, h.store, h.nextItem = {}, {}, {}, 1
	h.bagGrow = if whole(data.grow, 0, BAG.times) then data.grow else 0
	h.dust = if whole(data.dust, 0, 9e15) then data.dust else 0
	h.essence = if whole(data.essence, 0, 9e9) then data.essence else 0
	for _, row in data.equip do
		local it = unpackItem(row)
		if it and not h.equip[it.slot] and not it.broken and (it.slot ~= "weapon" or it.who == h.class) then
			h.equip[it.slot] = stamp(h, it)
		end
	end
	for _, row in data.gear do
		local it = unpackItem(row)
		if it and #h.gear < Bag.size(h) then
			table.insert(h.gear, stamp(h, it))
		end
	end
	if typeof(data.store) == "table" then
		for _, row in data.store do
			local it = unpackItem(row)
			if it and #h.store < Bag.storeSize(h) then
				table.insert(h.store, stamp(h, it))
			end
		end
	end
end

-- ---------- 클라이언트에 보내는 것 ----------
local function viewItem(it)
	return { id = it.id, slot = it.slot, stage = it.stage, q = it.q, star = it.star, who = it.who, broken = it.broken, fails = it.fails or 0 }
end

function Bag.view(h)
	local out = { gear = {}, equip = {}, store = {}, size = Bag.size(h), storeSize = Bag.storeSize(h), dust = h.dust, essence = h.essence, growCost = Bag.growCost(h) or false }
	for i, it in h.gear do
		out.gear[i] = viewItem(it)
	end
	for slot, it in h.equip do
		out.equip[slot] = viewItem(it)
	end
	for i, it in h.store do
		out.store[i] = viewItem(it)
	end
	return out
end

return Bag
