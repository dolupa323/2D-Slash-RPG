-- 유료 상품(로벅스)의 셈 — 화면 없이 돈다(서버의 server/lune/modules/cash.luau와 테스트가 같이 쓴다). 설계 = 공방 js/lune/design/bm.js(bm.generated).
--  사용자 2026-10-20: "1. 스타포스 관련은 판매하지않는다 2. 달가루, 달돈 계정당 수량 제한해서 판다 3. … 경매장에서 거래가능 4. (꾸밈) 된다 5. (월정액은) 패스느낌으로"
--   · "경험치 쿠폰 판매해도 됩니다. 꾸밈탈것 만들어도 됩니다. 만들어 봅시다"
--  계정의 것(acct.bm):
--   box = 구매 보관함 { { id = 아이템 이름표, n = 수 } … } — 산 것은 먼저 여기에 들어가고, 상점 창의 「받기」로 가방에 옮긴다(가방이 가득 차도 산 것을 잃지 않는다 · 메이플의 캐시 보관함)
--   rec = 처리한 결제 번호(PurchaseId) — 로블록스가 같은 결제를 다시 보내도 두 번 주지 않는다(최근 REC_KEEP개)
--   week · wc = 이번 주(한국 시각 월요일 0시부터)와 그 주에 산 수(상품 이름표 → 수) · once = 계정에 한 번(첫걸음 묶음)
--   slots = 사서 늘린 캐릭터 칸 · store = 확장권으로 늘린 창고(번) — 가방의 것은 캐릭터마다(h.bagPaid · sim/bag.luau)
--   pass = 달빛 패스(끝나는 때 · 달빛 · 받은 칸 — sim/pass.luau, 2026-10-20)
--   pets · mounts = 산 펫 · 탈것 { [이름] = true } · petOut = 꺼내 둔 펫(없으면 false — 계정의 모든 캐릭터가 같이) · mount = 고른 탈것(탄 동안인지는 서버의 그 사람의 것 — s.riding)
--  [제안] 값 · 수 · 한도는 모두 설계의 제안이다.
local lune = script.Parent.Parent
local D = require(lune.data["bm.generated"])
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)
local Pass = require(script.Parent.pass)
local RIDE = require(lune.data["ride.generated"])

local Cash = {}
Cash.REC_KEEP = 200
Cash.BOX_MAX = 300
Cash.RULES = D.rules

local PRODUCT, BY_RID = {}, {}
local PET, MOUNT = {}, {} -- 펫 · 탈것의 이름표(상품 이름과 같다 — design/ride.js)
for _, q in RIDE.pets do
	PET[q.id] = q
end
for _, q in RIDE.mounts do
	MOUNT[q.id] = q
end
Cash.PET, Cash.MOUNT, Cash.RIDE = PET, MOUNT, RIDE
for _, p in D.products do
	PRODUCT[p.id] = p
	if typeof(p.rid) == "number" and p.rid > 0 then
		BY_RID[p.rid] = p.id
	end
end
Cash.PRODUCTS = D.products

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0 and v >= lo and v <= hi
end

function Cash.new()
	return { box = {}, rec = {}, week = 0, wc = {}, once = {}, slots = 0, store = 0, pass = Pass.new(), pets = {}, mounts = {}, petOut = false, mount = false }
end

function Cash.product(key: any)
	return if typeof(key) == "string" then PRODUCT[key] else nil
end
-- 로블록스 상품 번호 → 이름표(번호가 없는 상품은 nil)
function Cash.byRid(rid: any): string?
	return BY_RID[rid]
end

-- 주 번호: 한국 시각(세계 표준시 + offset) 월요일 0시에 바뀐다. 1970-01-01은 목요일 → 나흘 뒤가 첫 월요일
function Cash.weekOf(now: number): number
	return math.floor((now + D.rules.week.offset * 3600 - 4 * 86400) / 604800)
end

-- 이번 주에 산 수 · 계정에 산 수
function Cash.bought(c, key: string, now: number): number
	local p = PRODUCT[key]
	if not p or not p.limit then
		return 0
	elseif p.limit.per == "week" then
		return if c.week == Cash.weekOf(now) then (c.wc[key] or 0) else 0
	elseif p.limit.per == "active" then
		return if Pass.active(c.pass, now) then 1 else 0 -- 달빛 패스: 지금 패스가 있나(끝난 뒤에 다시 산다)
	end
	return c.once[key] or 0
end

-- 주머니 · 상자의 레벨대: 계정에서 가장 높은 캐릭터 레벨을 레벨대로 내린다(1~9 → 1)
function Cash.bandOf(level: number): number
	local band = D.bands[1]
	for _, b in D.bands do
		if b <= level then
			band = b
		end
	end
	return band
end
function Cash.topLevel(acct, live: number?): number
	local top = if typeof(live) == "number" then live else 1 -- live = 지금 놀고 있는 캐릭터의 레벨(아직 저장 전일 수 있다)
	for _, c in acct.chars do
		local lv = if typeof(c.hero) == "table" and typeof(c.hero.level) == "number" then c.hero.level else 1
		top = math.max(top, lv)
	end
	return top
end

-- 살 수 있는가(구매 창을 띄우기 전에 서버가 본다). pending = 이 사람이 띄워 둔 · 아직 끝나지 않은 같은 상품의 구매 창 수
--  baseChars = 처음 캐릭터 칸 수(account.luau의 Account.MAX — 서로를 부르지 않으려고 받는다)
function Cash.canBuy(acct, key: any, now: number, pending: number?, baseChars: number?): (boolean, string?)
	local p = Cash.product(key)
	local c = acct.bm
	local wait = pending or 0
	if not p then
		return false, "없는 상품이다"
	elseif not c then
		return false, "계정을 읽지 못했다"
	elseif p.kind ~= "product" then
		return true -- 게임 패스 · 구독은 로블록스가 「이미 가졌다」를 막는다
	elseif key == "charx" and c.slots + wait >= D.rules.charCap - (baseChars or 6) then
		return false, ("캐릭터 칸이 가장 많다(%d칸)"):format(D.rules.charCap)
	elseif p.limit and Cash.bought(c, key, now) + wait >= p.limit.n then
		if p.limit.per == "week" then
			return false, ("이번 주에는 더 살 수 없다(한 주에 %d번 · 월요일 0시에 다시)"):format(p.limit.n)
		elseif p.limit.per == "active" then
			return false, ("달빛 패스가 %d일 남았다(끝난 뒤에 다시 산다)"):format(Pass.left(c.pass, now))
		end
		return false, if p.limit.n == 1 then "더 살 수 없다(계정에 한 번)" else ("더 살 수 없다(계정에 %d번)"):format(p.limit.n)
	elseif Cash.boxCount(c) >= Cash.BOX_MAX then
		return false, "구매 보관함이 가득 찼다 — 먼저 받아 주세요"
	end
	return true
end

function Cash.boxCount(c): number
	local n = 0
	for _, e in c.box do
		n += 1
	end
	return n
end

local function addBox(c, id: string, n: number)
	for _, e in c.box do
		if e.id == id then
			e.n += n
			return
		end
	end
	table.insert(c.box, { id = id, n = n })
end

-- 산 것을 준다(결제 하나 = 한 번). 같은 결제 번호를 두 번 받으면 주지 않는다(false, "dup").
--  준 것: 보관함의 아이템 · 계정의 칸. 구매 창을 띄운 뒤에 한도를 넘었더라도 돈을 받은 것은 반드시 준다(한도는 띄우기 전에 본다).
function Cash.grant(acct, key: string, receiptId: string, now: number, baseChars: number?, live: number?): (boolean, string?)
	local c = acct.bm
	local p = PRODUCT[key]
	if not p then
		return false, "없는 상품이다"
	end
	for _, r in c.rec do
		if r == receiptId then
			return false, "dup"
		end
	end
	local band = Cash.bandOf(Cash.topLevel(acct, live))
	if key == "money" then
		addBox(c, "bm_money_" .. band, 1)
	elseif key == "dust" then
		addBox(c, "bm_dust_" .. band, 1)
	elseif key == "bagx" or key == "storex" or key == "rename" or key == "exp" then
		addBox(c, "bm_" .. key, 1)
	elseif key == "charx" then
		c.slots = math.min(c.slots + 1, D.rules.charCap - (baseChars or 6))
	elseif key == "starter" then
		addBox(c, "bm_bagx", 1)
		addBox(c, "bm_money_" .. band, 1)
		addBox(c, "bm_dust_" .. band, 1)
	elseif PET[key] then
		c.pets[key] = true -- 펫: 산 계정에 바로(꺼내 둔 것이 없으면 바로 꺼낸다)
		c.petOut = c.petOut or key
	elseif MOUNT[key] then
		c.mounts[key] = true -- 탈것: 산 계정에 바로(고른 것이 없으면 그것을 고른다)
		c.mount = c.mount or key
	elseif key == "pass" then
		-- 달빛 패스: 지난 패스에서 받지 않은 칸은 먼저 보관함에(물약은 계정의 가장 높은 레벨) → 새 30일
		if not Pass.active(c.pass, now) then
			local potion = Items.potionFor(Cash.topLevel(acct, live))
			for _, g in Pass.claim(c.pass, if potion then potion.id else "potion1", band) do
				addBox(c, g.id, g.n)
			end
		end
		Pass.buy(c.pass, now)
	else
		return false, "아직 준비 중인 상품이다" -- 펫 · 탈것 · 스킨 · 순간이동 · 달빛 패스(그림 · 창이 생기면) — 번호가 없어 살 수도 없다
	end
	if p.limit and p.limit.per ~= "active" then
		if p.limit.per == "week" then
			local wk = Cash.weekOf(now)
			if c.week ~= wk then
				c.week, c.wc = wk, {}
			end
			c.wc[key] = (c.wc[key] or 0) + 1
		else
			c.once[key] = (c.once[key] or 0) + 1
		end
	end
	table.insert(c.rec, receiptId)
	while #c.rec > Cash.REC_KEEP do
		table.remove(c.rec, 1)
	end
	return true
end

-- 보관함에서 가방으로(i = 그 줄만 · 없으면 모두). 가방에 들어가는 만큼만 옮긴다 → 옮긴 수 · 남은 줄 수
function Cash.take(h, c, i: any?): (number, number)
	local moved = 0
	local list = if whole(i, 1, #c.box) then { c.box[i] } else table.clone(c.box)
	for _, e in list do
		local room = Bag.room(h, e.id)
		local k = math.min(room, e.n)
		if k > 0 and Bag.give(h, e.id, k) then
			e.n -= k
			moved += k
		end
	end
	for j = #c.box, 1, -1 do
		if c.box[j].n <= 0 then
			table.remove(c.box, j)
		end
	end
	return moved, #c.box
end

-- 유료 아이템을 쓴다(가방에서 하나 덜어 내는 것은 부른 쪽 — 쓸 수 있을 때만). → true · 결과 글 / nil · 쓸 수 없는 까닭
--  bmStore는 계정의 창고를 늘린다(부른 쪽이 창고 칸을 다시 맞춘다) · bmRename은 이름을 받아야 해서 부른 쪽이 따로 한다
function Cash.use(h, acct, def): (boolean?, string?)
	local c = acct.bm
	local R = D.rules
	if def.kind == "bmMoney" then
		h.money += def.amount
		return true, ("달돈 %s을 얻었다"):format(tostring(def.amount))
	elseif def.kind == "bmDust" then
		h.dust += def.amount
		return true, ("달가루 %s을 얻었다"):format(tostring(def.amount))
	elseif def.kind == "bmBag" then
		if (h.bagPaid or 0) >= R.bagSteps then
			return nil, "가방을 더 늘릴 수 없다"
		end
		Bag.growPaid(h)
		return true, ("가방이 %d칸이 되었다"):format(Bag.size(h))
	elseif def.kind == "bmStore" then
		if c.store >= R.storeSteps then
			return nil, "창고를 더 늘릴 수 없다"
		end
		c.store += 1
		return true, "창고가 늘었다"
	elseif def.kind == "bmExp" then
		if (h.expLeft or 0) + R.exp.add > R.exp.cap then
			return nil, ("더 쌓을 수 없다(%d시간까지)"):format(R.exp.cap // 3600)
		end
		h.expLeft = (h.expLeft or 0) + R.exp.add
		return true, ("사냥 경험치 %s배 — %d분 남음"):format(tostring(R.exp.mul), math.ceil(h.expLeft / 60))
	end
	return nil, "쓸 수 없는 아이템이다"
end

-- 달빛 패스: 한 일을 알린다(서버의 출석 · 일일 의뢰 · 토벌 · 처치) → 얻은 달빛
function Cash.passAdd(acct, key: string, now: number, n: number?): number
	if not acct or not acct.bm then
		return 0
	end
	return Pass.add(acct.bm.pass, key, now, n)
end
-- 달빛 패스의 받을 수 있는 보상을 모두 보관함에 → 받은 보상 수. level = 받는 캐릭터(물약) · live = 지금 놀고 있는 캐릭터의 레벨(주머니 · 상자의 레벨대)
function Cash.passClaim(acct, now: number, level: number, live: number?): number
	local c = acct.bm
	local potion = Items.potionFor(level)
	local gifts = Pass.claim(c.pass, if potion then potion.id else "potion1", Cash.bandOf(Cash.topLevel(acct, live)))
	for _, g in gifts do
		addBox(c, g.id, g.n)
	end
	return #gifts
end
-- 가진 펫 · 탈것의 이름표들(상품의 차례)
function Cash.ownList(set): { string }
	local out = {}
	for _, list in { RIDE.pets, RIDE.mounts } do
		for _, q in list do
			if set[q.id] then
				table.insert(out, q.id)
			end
		end
	end
	return out
end
-- 펫을 꺼낸다(id) · 넣는다(false) → true / nil · 까닭
function Cash.setPet(acct, id: any): (boolean?, string?)
	local c = acct.bm
	if id == false then
		c.petOut = false
		return true
	elseif typeof(id) ~= "string" or not c.pets[id] then
		return nil, "가진 펫이 아니다"
	end
	c.petOut = id
	return true
end
-- 탈 것을 고른다 → true / nil · 까닭(타고 내리는 것은 서버의 그 사람 — s.riding)
function Cash.setMount(acct, id: any): (boolean?, string?)
	local c = acct.bm
	if typeof(id) ~= "string" or not c.mounts[id] then
		return nil, "가진 탈것이 아니다"
	end
	c.mount = id
	return true
end

-- 경매장 등록 칸: 달빛 패스가 있는 동안 + auctionPlus
function Cash.marketPlus(acct, now: number): number
	return if acct and acct.bm and Pass.active(acct.bm.pass, now) then Pass.DATA.auctionPlus else 0
end

-- 사냥 경험치 배율(경험치 쿠폰)
function Cash.expMul(h): number
	return if (h.expLeft or 0) > 0 then D.rules.exp.mul else 1
end

-- ---------- 저장 ----------
function Cash.pack(c)
	local box = {}
	for _, e in c.box do
		table.insert(box, { id = e.id, n = e.n })
	end
	local pets, mounts = {}, {}
	for k in c.pets do
		table.insert(pets, k)
	end
	for k in c.mounts do
		table.insert(mounts, k)
	end
	table.sort(pets)
	table.sort(mounts)
	return { box = box, rec = table.clone(c.rec), week = c.week, wc = table.clone(c.wc), once = table.clone(c.once), slots = c.slots, store = c.store, pass = Pass.pack(c.pass), pets = pets, mounts = mounts, petOut = c.petOut, mount = c.mount }
end

-- 꼴이 이상한 것은 버린다(없는 아이템 · 이상한 수). 생기기 전의 저장 = 빈 것
function Cash.unpack(data: any, baseChars: number?)
	local c = Cash.new()
	if typeof(data) ~= "table" then
		return c
	end
	if typeof(data.box) == "table" then
		for _, e in data.box do
			if typeof(e) == "table" and typeof(e.id) == "string" and #e.id <= 40 and Items.goods(e.id) and whole(e.n, 1, 1e6) and #c.box < Cash.BOX_MAX then
				addBox(c, e.id, e.n)
			end
		end
	end
	if typeof(data.rec) == "table" then
		for _, r in data.rec do
			if typeof(r) == "string" and #r <= 80 and #c.rec < Cash.REC_KEEP then
				table.insert(c.rec, r)
			end
		end
	end
	c.week = if whole(data.week, 0, 1e7) then data.week else 0
	for _, field in { "wc", "once" } do
		if typeof(data[field]) == "table" then
			for k, n in data[field] do
				if PRODUCT[k] and whole(n, 0, 1e6) then
					c[field][k] = n
				end
			end
		end
	end
	c.slots = if whole(data.slots, 0, D.rules.charCap - (baseChars or 6)) then data.slots else 0
	c.store = if whole(data.store, 0, D.rules.storeSteps) then data.store else 0
	c.pass = Pass.unpack(data.pass)
	for _, pair in { { "pets", PET }, { "mounts", MOUNT } } do
		if typeof(data[pair[1]]) == "table" then
			for _, k in data[pair[1]] do
				if typeof(k) == "string" and pair[2][k] then
					c[pair[1]][k] = true
				end
			end
		end
	end
	c.petOut = if typeof(data.petOut) == "string" and c.pets[data.petOut] then data.petOut else false
	c.mount = if typeof(data.mount) == "string" and c.mounts[data.mount] then data.mount else false
	return c
end

-- 살 수 있게 된 상품인가: 로블록스 상품 번호가 있고(대시보드에서 만든 뒤) 게임에 만들어 둔 것(built — 펫 · 순간이동 · 꾸밈 · 패스는 아직)
function Cash.ready(p): boolean
	local hasId = (typeof(p.rid) == "number" and p.rid > 0) or (typeof(p.rid) == "string" and p.rid ~= "")
	return hasId and p.built == true
end

-- 상점 창에 보내는 것: 상품마다 살 수 있나(ready) · 산 수(주간이면 이번 주) · 패스를 가졌나 · 보관함 · 주머니 · 상자의 레벨대(band)
function Cash.view(acct, now: number, owned: any?, live: number?, prices: any?)
	local c = acct.bm
	local list = {}
	for _, p in D.products do
		local robux = if typeof(prices) == "table" and typeof(prices[p.id]) == "number" then prices[p.id] else p.robux -- 로블록스의 실제 값(대시보드에서 바꾸면 그 값) · 못 읽었으면 설계의 값
		table.insert(list, { id = p.id, ready = Cash.ready(p), bought = Cash.bought(c, p.id, now), own = (owned ~= nil and owned[p.id] == true) or c.pets[p.id] == true or c.mounts[p.id] == true, robux = robux }) -- own = 게임 패스를 가졌다 · 펫 · 탈것을 샀다
	end
	local box = {}
	for _, e in c.box do
		table.insert(box, { id = e.id, n = e.n })
	end
	return { list = list, box = box, band = Cash.bandOf(Cash.topLevel(acct, live)), slots = c.slots, store = c.store, pass = Pass.view(c.pass, now), pets = Cash.ownList(c.pets), mounts = Cash.ownList(c.mounts), petOut = c.petOut, mount = c.mount }
end

-- 확인용(테스트): 상품 표가 아이템 표와 맞는가
function Cash.check(): { string }
	local bad = {}
	for _, b in D.bands do
		for _, pre in { "bm_money_", "bm_dust_" } do
			local g = Items.goods(pre .. b)
			if not g or not g.paid or not (g.amount and g.amount > 0) then
				table.insert(bad, pre .. b)
			end
		end
	end
	for _, id in { "bm_bagx", "bm_storex", "bm_rename", "bm_exp" } do
		local g = Items.goods(id)
		if not g or not g.paid then
			table.insert(bad, id)
		end
	end
	return bad
end

return Cash
