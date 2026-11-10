-- 유료 상품(로벅스)의 셈 — 화면 없이 돈다(서버의 server/lune/modules/cash.luau와 테스트가 같이 쓴다). 설계 = 공방 js/lune/design/bm.js(bm.generated).
--  사용자 2026-10-20: "1. 스타포스 관련은 판매하지않는다 2. 달가루, 달돈 계정당 수량 제한해서 판다 3. … 경매장에서 거래가능 4. (꾸밈) 된다 5. (월정액은) 패스느낌으로"
--   · "경험치 쿠폰 판매해도 됩니다. 꾸밈탈것 만들어도 됩니다. 만들어 봅시다"
--  계정의 것(acct.bm):
--   box = 구매 보관함 { { id = 아이템 이름표, n = 수 } … } — 산 것은 먼저 여기에 들어가고, 상점 창의 「받기」로 가방에 옮긴다(가방이 가득 차도 산 것을 잃지 않는다 · 메이플의 캐시 보관함)
--   rec = 처리한 결제 번호(PurchaseId) — 로블록스가 같은 결제를 다시 보내도 두 번 주지 않는다(최근 REC_KEEP개)
--   week · wc = 이번 주(한국 시각 월요일 0시부터)와 그 주에 산 수(상품 이름표 → 수) · once = 계정에 한 번(첫걸음 묶음)
--   slots = 사서 늘린 캐릭터 칸 · store = 확장권으로 늘린 창고(번) — 가방의 것은 캐릭터마다(h.bagPaid · sim/bag.luau)
--   pass = 달빛 패스(끝나는 때 · 달빛 · 받은 칸 — sim/pass.luau, 2026-10-20)
--   pets · mounts = 산 펫 · 탈것 { [이름] = true } · petsOut = 꺼내 둔 펫들(꺼낸 차례 · Cash.PET_MAX까지 — 2026-10-30) · petOut = 그 첫째(없으면 false — 그 전의 저장 · 코드가 보는 것 · 늘 맞춘다 · 계정의 모든 캐릭터가 같이) · mount = 고른 탈것(탄 동안인지는 서버의 그 사람의 것 — s.riding)
--   wskins = 산 캐시 무기 { [이름] = true } · wskin = 장착한 것(없으면 false — 계정의 모든 캐릭터의 무기 · 2026-10-23 design/wskin.js)
--   dskins = 가진 데미지 스킨 { [이름] = true } · dskin = 장착한 것(없으면 false — 내가 때린 숫자의 모습 · 2026-10-29 할로윈 · design/event.js의 dskins)
--   ev = 기간 이벤트의 상점에서 산 수 { ["<이벤트>:<해>:<물건>"] = 수 }(한도가 있는 것 — 할로윈의 달가루 상자 · 2026-10-29)
--   gift = 띄운 선물의 구매 창 { k = 상품, uid = 받는 계정, to = 받는 사람의 닉네임, at = 띄운 때 }(없으면 false — 결제가 오면 그 사람에게 · 2026-10-31 선물하기)
--   lock = 로블록스 정책에서 유료 아이템을 거래할 수 없는 계정이다(들어올 때 서버가 적는다 — 남이 이 계정에 선물할 때 본다)
--  [제안] 값 · 수 · 한도는 모두 설계의 제안이다.
local lune = script.Parent.Parent
local D = require(lune.data["bm.generated"])
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)
local Pass = require(script.Parent.pass)
local RIDE = require(lune.data["ride.generated"])
local Gacha = require(script.Parent.gacha) -- 뽑기 상자(2026-11-07)

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
local WSKIN = {} -- 캐시 무기의 이름표(상품 이름과 같다 — dye.generated의 skins · 2026-10-23)
for _, q in require(lune.data["dye.generated"]).skins do
	WSKIN[q.id] = q
end
Cash.WSKIN = WSKIN
local DSKIN = {} -- 데미지 스킨의 이름표(기간 이벤트의 것 — event.generated의 dskins · 2026-10-29)
for _, e in require(lune.data["event.generated"]).list do
	for _, q in e.dskins or {} do
		DSKIN[q.id] = q
	end
end
for _, q in (D.dskins and D.dskins.list) or {} do -- 데미지 스킨 상자의 것(2026-11-10 — 공방 design/dmgskin.js)
	DSKIN[q.id] = q
end
Cash.DSKIN = DSKIN
local NTAG = {} -- 이름표 테두리(2026-11-10 — 이름표 테두리 상자 · bm.generated의 nametags · 공방 design/nametag.js)
for _, q in (D.nametags and D.nametags.list) or {} do
	NTAG[q.id] = q
end
Cash.NTAG = NTAG
local BUBBLE = {} -- 말풍선 꾸밈의 이름표(2026-11-07 — bm.generated의 bubbles · 공방 design/bubble.js)
for _, q in (D.bubbles and D.bubbles.list) or {} do
	BUBBLE[q.id] = q
end
Cash.BUBBLE = BUBBLE
for _, p in D.products do
	PRODUCT[p.id] = p
	if typeof(p.rid) == "number" and p.rid > 0 then
		BY_RID[p.rid] = p.id
	end
end
Cash.PRODUCTS = D.products
Cash.WORDS = D.shop.words

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0 and v >= lo and v <= hi
end

-- 한꺼번에 꺼내 둘 수 있는 펫의 수(2026-10-30 사용자: "펫 현재 한마리만 낄수있는데 3마리까지 낄수있게해줘" — 메이플의 멀티펫처럼 셋이 따로 따라다니며 따로 줍는다)
Cash.PET_MAX = 3
-- 꺼내 둔 펫들(꺼낸 차례) — 그 전의 저장(petOut 하나)이면 그것 하나
function Cash.petsOut(c): { string }
	if typeof(c.petsOut) == "table" then
		return c.petsOut
	end
	return if typeof(c.petOut) == "string" then { c.petOut } else {}
end
local function syncPets(c)
	c.petsOut = Cash.petsOut(c)
	c.petOut = c.petsOut[1] or false
end
-- 새로 얻은 펫(산 것 · 쿠폰 · 이벤트): 꺼내 둔 펫이 하나도 없으면 바로 꺼낸다(그 전과 같다)
function Cash.petAuto(c, id: string)
	syncPets(c)
	if #c.petsOut == 0 then
		table.insert(c.petsOut, id)
	end
	syncPets(c)
end
-- 그 펫을 넣는다(없어진 펫 — 쿠폰 기록 지우기 · 꺼내 둔 같은 펫 모두)
function Cash.petRemove(c, id: string)
	syncPets(c)
	local at = table.find(c.petsOut, id)
	while at do
		table.remove(c.petsOut, at)
		at = table.find(c.petsOut, id)
	end
	syncPets(c)
end

-- 가진 수(2026-11-10 사용자: 뽑기에서 가진 것이 나오면 "같은 것을 하나 더 준다" — 그 전에는 윤슬 조각으로 바꿨다):
--  가진 것이면 1 + 더 받은 수(c.extra = { [이름표] = 수 } — 펫 · 탈것 · 캐시 무기 · 데미지 스킨 · 말풍선 · 이름표 테두리의 이름표는 서로 겹치지 않는다) · 없으면 0.
--  펫은 같은 펫을 그 수만큼 함께 꺼낸다(PET_MAX까지) · 다른 것은 수만 늘고 쓰임은 같다
local function owns(c, id: any): boolean
	if typeof(c) ~= "table" or typeof(id) ~= "string" then
		return false
	end
	for _, k in { "pets", "mounts", "wskins", "dskins", "bubbles", "ntags" } do
		if typeof(c[k]) == "table" and c[k][id] == true then
			return true
		end
	end
	return false
end
function Cash.count(c, id: any): number
	if not owns(c, id) then
		return 0
	end
	local more = typeof(c.extra) == "table" and c.extra[id] or 0
	return 1 + (if typeof(more) == "number" then more else 0)
end
-- 꺼내 둔 그 펫의 수
function Cash.petOutCount(c, id: any): number
	local n = 0
	for _, k in Cash.petsOut(c) do
		if k == id then
			n += 1
		end
	end
	return n
end

-- 겹침 보상(2026-11-10 사용자: "이미 샀는데 증발된사람들한테 소급적용 해줘야해 이미 날아간사람은 사기를당한거잖아 돈관련된건 철저하게해야해"):
--  S386 ~ S393 사이에 뽑기 상자에서 가진 것이 나오면 그 아이템 대신 윤슬 조각을 주었다 — 무엇이 겹쳤는지는 저장되지 않았다(결제 번호만).
--  → 운영자가 관리 창 「보상」에서 그 사람(닉네임) · 상자 · 횟수를 보내면(server — 달빛 상점 선물 상자의 길: 접속하지 않았어도 다음 접속 때)
--    계정에 c.dupfix[상자] = 남은 횟수가 쌓이고, 그 사람이 가방 「캐시」 탭에서 그 상자에서 나오는 가진 것을 골라 「겹침 보상 받기」 → 그것을 하나 더(Cash.dupfixUse).
--  보낼 때의 이름표 = "dupfix:<상자>:<횟수>"(선물 상자의 k — Cash.grant가 받는다). 받은 윤슬 조각은 되찾지 않는다(제가 정한 것)
Cash.DUPFIX_MAX = 99
function Cash.dupfixKey(box: string, n: number): string
	return ("dupfix:%s:%d"):format(box, n)
end
function Cash.dupfixOf(key: any): (string?, number?)
	if typeof(key) ~= "string" then
		return nil
	end
	local box, n = string.match(key, "^dupfix:([%w_]+):(%d+)$")
	local k = tonumber(n)
	if box and Gacha.box(box) and k and k >= 1 and k <= Cash.DUPFIX_MAX then
		return box, k
	end
	return nil
end
-- 원래 상품으로 준 겹침 보상(2026-11-10 사용자: "최대한 원래 상품으로 지급하고 그게 추론되지 않는경우는 선택상자로 지급하자"): 알림 · 기록의 이름표 "fixitem:<아이템>:<수>"
function Cash.fixItemKey(id: string, n: number): string
	return ("fixitem:%s:%d"):format(id, n)
end
function Cash.fixItemOf(key: any): (string?, number?)
	if typeof(key) ~= "string" then
		return nil
	end
	local id, n = string.match(key, "^fixitem:([%w_]+):(%d+)$")
	return id, tonumber(n)
end
-- 캐시 아이템의 이름(펫 · 탈것 · 캐시 무기 · 데미지 스킨 · 말풍선 · 이름표 테두리)
function Cash.itemName(id: any): string
	local q = PET[id] or MOUNT[id] or WSKIN[id] or DSKIN[id] or BUBBLE[id] or NTAG[id]
	return if q and typeof(q.name) == "string" then q.name else tostring(id)
end
-- 그 아이템이 나오는 상자들(뽑기 상자의 pool)
local function boxesOf(id: any): { string }
	local out = {}
	for bid, b in Gacha.BOXES do
		for _, e in b.pool or {} do
			if e[1] == id then
				table.insert(out, bid)
			end
		end
	end
	table.sort(out)
	return out
end
-- 그 아이템에 쓸 수 있는 겹침 보상의 상자(남은 것이 있는 첫 상자) · 남은 횟수
function Cash.dupfixFor(c, id: any): (string?, number)
	if not owns(c, id) or typeof(c.dupfix) ~= "table" then
		return nil, 0
	end
	for _, bid in boxesOf(id) do
		local n = c.dupfix[bid]
		if typeof(n) == "number" and n > 0 then
			return bid, n
		end
	end
	return nil, 0
end
Cash.DUPFIX_NONE = "이 아이템에 받을 겹침 보상이 없다"
-- 겹침 보상 한 번을 그 아이템에 쓴다 → true · 받은 뒤의 가진 수 / nil · 까닭
function Cash.dupfixUse(acct, id: any): (boolean?, any)
	local c = acct.bm
	local bid, left = Cash.dupfixFor(c, id)
	if not bid then
		return nil, Cash.DUPFIX_NONE
	end
	c.extra = if typeof(c.extra) == "table" then c.extra else {}
	c.extra[id] = (c.extra[id] or 0) + 1
	c.dupfix[bid] = if left > 1 then left - 1 else nil
	return true, Cash.count(c, id)
end

-- 결제의 기록(2026-11-10 — "돈관련된건 철저하게"): 받은 결제마다 { r = 결제 번호, k = 상품, t = 때, g = 뽑기에서 나온 것, n = 그 뒤의 가진 수(겹쳤을 때) } · 최근 LOG_KEEP개.
--  산 것 · 선물로 받은 것(결제 번호 "g…") · 겹침 보상이 모두 남는다 — 무엇을 주었는지 나중에 확인한다(전에는 결제 번호만 남아 겹침을 되짚을 수 없었다)
Cash.LOG_KEEP = 200
local function logBuy(c, receiptId: string, key: string, now: number, got: any?, n: any?)
	c.log = if typeof(c.log) == "table" then c.log else {}
	table.insert(c.log, { r = string.sub(receiptId, 1, 80), k = string.sub(key, 1, 60), t = math.floor(now), g = if typeof(got) == "string" then got else nil, n = n })
	while #c.log > Cash.LOG_KEEP do
		table.remove(c.log, 1)
	end
end

-- 겹침의 자동 보상(2026-11-10 사용자: "그사람이 가지고있는 캐시템이랑 산 상자를 비교하면 얼마나 사라졌는지 알수있는거아니야? 정확히 파악해야 내가 보상을하지"):
--  상자 하나 = 새것 하나(가진 것에 더해진다) 또는 윤슬 조각(겹침 · 다 가졌을 때) — 그러니 사라진 수 = 산 수 − 그 상자의 것 가운데 가진 수.
--  상자의 것은 상자에서만 나온다(쿠폰 · 이벤트에 없다 — 2026-11-10 확인) · 옛 상점의 달토끼 셋만 따로 팔았다 → buy.direct(따로 산 것)는 가진 수에서 뺀다.
--  buy = server/lune/modules/dupfixBuys.luau의 한 사람(로블록스 판매 기록에서 센 산 수 · upTo = 그 기록을 받은 때).
--  새 서버의 결제는 결제의 기록(log)에 남는다: upTo까지의 것은 산 수에서 빼고(그때는 겹쳐도 하나 더) · 새것이 나온 것은 가진 수에서 뺀다(언제든).
--  주는 것 = 사라진 수 − 이미 준 수(fixGiven):
--   · 겹침은 그때 이미 가진 것만 나온다 → 그 상자의 것을 지금 한 종류만 가졌으면(따로 산 달토끼도 셈) 사라진 것은 모두 그것 = 원래 상품을 바로 하나씩 더(extra · sure = 그 이름표)
--   · 두 종류 이상이면 어느 것인지 기록으로 가릴 수 없다 → 선택상자(dupfix — 받는 사람이 그 상자의 가진 것을 골라 하나 더)
--   (사용자 2026-11-10 "최대한 원래 상품으로 지급하고 그게 추론되지 않는경우는 선택상자로 지급하자". 윤슬 조각의 수(보통 2 · 드문 5)로 가리는 것은 쓰지 않는다 — 상자와 상관없이 한 칸에 합쳐지고 꺼내거나 쓰면 준다)
--  dry = 셈만(관리 창의 조회). 돌려주는 것: { { box, bought, owned, lost, given, add, sure } … }(상자의 차례)
function Cash.dupfixAuto(c, buy, upTo: number, now: number, dry: boolean?)
	local rows = {}
	if typeof(buy) ~= "table" then
		return rows
	end
	local direct = {}
	for _, id in (typeof(buy.direct) == "table" and buy.direct) or {} do
		direct[id] = true
	end
	local ids = {}
	for bid in Gacha.BOXES do
		table.insert(ids, bid)
	end
	table.sort(ids)
	for _, bid in ids do
		local bought = buy[bid]
		if typeof(bought) == "number" and bought > 0 then
			local loggedPre, loggedNew = 0, 0
			for _, e in (typeof(c.log) == "table" and c.log) or {} do
				if e.k == bid then
					if (e.t or 0) <= upTo then
						loggedPre += 1
					end
					if e.g ~= nil and e.n == nil then
						loggedNew += 1
					end
				end
			end
			local owned, kinds, only = 0, 0, nil
			for _, e in Gacha.BOXES[bid].pool or {} do
				if owns(c, e[1]) then
					kinds += 1 -- (따로 산 것도 — 겹칠 수 있었던 것)
					only = e[1]
					if not direct[e[1]] then
						owned += 1
					end
				end
			end
			local sure = if kinds == 1 then only else nil
			owned = math.max(0, owned - loggedNew)
			-- 그 상자의 것을 하나도 안 가졌으면 겹침일 수 없다(겹침은 가진 것만 · 첫 상자는 늘 새것) — 산 기록만 있는 것은 아직 들어오지 않은 결제다(로블록스가 다시 보낸다) → 주지 않는다(두 번 받지 않게)
			local lost = if kinds == 0 then 0 else math.max(0, (bought - loggedPre) - owned)
			local given = (typeof(c.fixGiven) == "table" and c.fixGiven[bid]) or 0
			local add = math.max(0, lost - given)
			if add > 0 and not dry then
				c.fixGiven = if typeof(c.fixGiven) == "table" then c.fixGiven else {}
				c.fixGiven[bid] = given + add
				if sure then
					c.extra = if typeof(c.extra) == "table" then c.extra else {}
					c.extra[sure] = (c.extra[sure] or 0) + add
					logBuy(c, ("auto%d_%s_%d"):format(upTo, bid, given + add), Cash.fixItemKey(sure, add), now, sure, Cash.count(c, sure))
				else
					c.dupfix = if typeof(c.dupfix) == "table" then c.dupfix else {}
					c.dupfix[bid] = math.min((c.dupfix[bid] or 0) + add, 999)
					logBuy(c, ("auto%d_%s_%d"):format(upTo, bid, given + add), Cash.dupfixKey(bid, math.min(add, Cash.DUPFIX_MAX)), now)
				end
			end
			table.insert(rows, { box = bid, bought = bought - loggedPre, owned = owned, lost = lost, given = given, add = add, sure = sure })
		end
	end
	return rows
end

function Cash.new()
	return { box = {}, rec = {}, week = 0, wc = {}, once = {}, slots = 0, store = 0, pass = Pass.new(), pets = {}, mounts = {}, petsOut = {}, petOut = false, mount = false, coupons = {}, wskins = {}, wskin = false, dskins = {}, dskin = false, bubbles = {}, bubble = false, ntags = {}, ntag = false, extra = {}, dupfix = {}, fixGiven = {}, boxReset = 0, log = {}, ev = {}, gift = false, lock = false } -- coupons = 이 계정이 쓴 쿠폰 { [번호] = 쓴 때 }(2026-10-21) · extra = 더 받은 수(2026-11-10 — Cash.count) · dupfix · log = 아래
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

-- 뽑기 상자의 것 하나를 계정에 준다(bid = 상자 · got = 그것): 가진 것이면 하나 더(가진 수 — 2026-11-10) · 아니면 계정에(낀 것 · 꺼낸 펫이 없으면 바로) → 하나 더였으면 그 뒤의 가진 수
local function giveBoxItem(c, bid: string, got: string): number?
	local b = Gacha.box(bid)
	if Gacha.ownedOf(c, bid)[got] then
		c.extra = if typeof(c.extra) == "table" then c.extra else {}
		c.extra[got] = (c.extra[got] or 0) + 1
		return Cash.count(c, got)
	elseif b.kind == "pet" then
		c.pets[got] = true
		Cash.petAuto(c, got)
	elseif b.kind == "bubble" then
		c.bubbles[got] = true -- 말풍선 꾸밈(2026-11-07): 낀 것이 없으면 바로 낀다
		c.bubble = c.bubble or got
	elseif b.kind == "dskin" then
		c.dskins[got] = true -- 데미지 스킨(2026-11-10 데미지 스킨 상자): 낀 것이 없으면 바로 낀다
		c.dskin = c.dskin or got
	elseif b.kind == "ntag" then
		c.ntags[got] = true -- 이름표 테두리(2026-11-10 이름표 테두리 상자): 낀 것이 없으면 바로 낀다
		c.ntag = c.ntag or got
	else
		c.mounts[got] = true
		c.mount = c.mount or got
	end
	return nil
end
-- 뽑기 상자 하나를 연다(산 것 · 안 연 상자 — 같은 셈): 정해진 확률로 하나 → giveBoxItem · 나올 것이 없으면 윤슬 조각(spare) → c.lastBox(서버가 연출에 싣고 지운다)
local function openBox(c, bid: string): (string?, number?)
	local got = Gacha.roll(bid)
	local dupN = nil
	if got then
		dupN = giveBoxItem(c, bid, got)
	else
		addBox(c, "yunseul", (D.rules.random and D.rules.random.spare) or 3)
	end
	c.lastBox = { k = bid, got = got or false, n = dupN } -- (서버가 알림에 싣고 지운다 — 저장하지 않는다 · n = 가진 것이 나와 하나 더 받은 뒤의 가진 수)
	return got, dupN
end

-- 산 것을 준다(결제 하나 = 한 번). 같은 결제 번호를 두 번 받으면 주지 않는다(false, "dup").
--  준 것: 보관함의 아이템 · 계정의 칸. 구매 창을 띄운 뒤에 한도를 넘었더라도 돈을 받은 것은 반드시 준다(한도는 띄우기 전에 본다).
-- 이 결제를 이미 주었는가(로블록스가 같은 결제를 다시 보낼 수 있다 — 한정 판매의 수를 두 번 세지 않게 · 2026-10-29)
function Cash.granted(c, receiptId: string): boolean
	for _, r in (c and c.rec) or {} do
		if r == receiptId then
			return true
		end
	end
	return false
end

-- 처리한 결제 번호로 적는다(최근 REC_KEEP개 — 선물로 보낸 결제는 산 사람의 계정에 번호만 남는다)
function Cash.note(c, receiptId: string)
	table.insert(c.rec, receiptId)
	while #c.rec > Cash.REC_KEEP do
		table.remove(c.rec, 1)
	end
end

-- 선물할 수 있는 상품인가(2026-10-31 선물하기): 로블록스 개발자 상품만 — 게임 패스 · 구독은 로블록스가 남에게 사 주지 못하게 한다
function Cash.giftable(key: any): boolean
	local p = Cash.product(key)
	return p ~= nil and p.kind == "product" and Cash.ready(p) and p.random ~= true -- (확률형 — 뽑기 상자 · 윤슬 조각은 선물하지 않는다: 받는 사람의 확률을 보낸 사람이 볼 수 없다 · 2026-11-07)
end

function Cash.grant(acct, key: string, receiptId: string, now: number, baseChars: number?, live: number?): (boolean, string?)
	local c = acct.bm
	local fixBox, fixN = Cash.dupfixOf(key)
	if fixBox then
		-- 겹침 보상(운영자가 보낸 것 — 위의 dupfix): 결제 번호처럼 한 번만 받는다
		if Cash.granted(c, receiptId) then
			return false, "dup"
		end
		addBox(c, "bm_pick_" .. fixBox, fixN) -- (2026-11-10 상자 판매 바로잡기부터: 고르는 표 대신 선택 상자 — 그 상자의 것 하나를 골라 받는다)
		Cash.note(c, receiptId)
		logBuy(c, receiptId, key, now)
		return true
	end
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
	-- 묶음(2026-11-06 「여러 개를 한 번에」 — bm.js BM_PACKS): of = 담긴 상품 · n = 수 → 그 상품을 n개(결제는 하나 · 결제 번호도 하나)
	local base = if typeof(p.of) == "string" and PRODUCT[p.of] then p.of else key
	local cnt = if typeof(p.n) == "number" and p.n >= 1 then math.floor(p.n) else 1
	if base == "money" then
		addBox(c, "bm_money_" .. band, cnt)
	elseif base == "dust" then
		addBox(c, "bm_dust_" .. band, cnt)
	elseif base == "bagx" or base == "storex" or base == "rename" or base == "exp" or base == "drop" or base == "dyepoint" or base == "dyerobe" then -- (염색약 — 2026-10-22 · 드롭률 쿠폰 — 2026-10-27)
		addBox(c, "bm_" .. base, cnt)
	elseif base == "yunseul" then
		addBox(c, "yunseul", cnt) -- 윤슬 조각(2026-11-07 — 장비 추가 옵션의 재설정 도구 · 묶음 5 · 10개)
	elseif Gacha.box(key) then
		-- 뽑기 상자(2026-11-07): 사는 순간 연다 — 정해진 확률로 하나(Gacha.roll · 2026-11-10부터 가진 것도 나온다)
		--  가진 것이 나오면 같은 것을 하나 더(2026-11-10 사용자 "캐시템 뽑기로 뽑은거 중복 지급이안되는데 그냥 삭제되는데?" → 고른 것 「같은 것을 하나 더 준다」 —
		--   그 전에는 윤슬 조각 2 · 5개로 바꿨다): 가진 수(c.extra)가 늘고, 연출이 그것과 「가진 수 n」을 보인다
		openBox(c, key)
	elseif key == "charx" then
		c.slots = math.min(c.slots + 1, D.rules.charCap - (baseChars or 6))
	elseif key == "starter" then
		addBox(c, "bm_bagx", 1)
		addBox(c, "bm_money_" .. band, 1)
		addBox(c, "bm_dust_" .. band, 1)
	elseif PET[key] then
		c.pets[key] = true -- 펫: 산 계정에 바로(꺼내 둔 것이 없으면 바로 꺼낸다)
		Cash.petAuto(c, key)
	elseif MOUNT[key] then
		c.mounts[key] = true -- 탈것: 산 계정에 바로(고른 것이 없으면 그것을 고른다)
		c.mount = c.mount or key
	elseif WSKIN[key] then
		c.wskins[key] = true -- 캐시 무기: 산 계정에 바로 · 바로 장착한다(산 것이 바로 보이게 — 제가 정한 것)
		c.wskin = key
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
	Cash.note(c, receiptId)
	logBuy(c, receiptId, key, now, c.lastBox and c.lastBox.k == key and c.lastBox.got or nil, c.lastBox and c.lastBox.k == key and c.lastBox.n or nil)
	return true
end

-- 보관함에서 가방으로(i = 그 줄만 · 없으면 모두 · n = 그 줄에서 몇 개 — 없으면 그 줄을 모두 · 2026-11-06 사용자 "수령을 나눠서 할수있어야해").
--  가방에 들어가는 만큼만 옮긴다 → 옮긴 수 · 남은 줄 수
function Cash.take(h, c, i: any?, n: any?): (number, number)
	local moved = 0
	local one = whole(i, 1, #c.box)
	local list = if one then { c.box[i] } else table.clone(c.box)
	local want = if one and whole(n, 1, 1e6) then n else math.huge
	for _, e in list do
		local room = Bag.room(h, e.id)
		local k = math.min(room, e.n, want)
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
	elseif def.kind == "bmDrop" then
		-- 드롭률 쿠폰(2026-10-27 — 경험치 쿠폰과 같은 꼴): 30분 · 겹쳐 쓰면 늘고 3시간까지
		if (h.dropLeft or 0) + R.drop.add > R.drop.cap then
			return nil, ("더 쌓을 수 없다(%d시간까지)"):format(R.drop.cap // 3600)
		end
		h.dropLeft = (h.dropLeft or 0) + R.drop.add
		return true, ("장비 · 재료 %s배 — %d분 남음"):format(tostring(R.drop.mul), math.ceil(h.dropLeft / 60))
	elseif def.kind == "bmBox" and Gacha.box(def.box) then
		-- 안 연 상자(2026-11-10 상자 판매 바로잡기): 그 자리에서 연다 — 산 것과 같은 셈(openBox · 가진 것이면 하나 더) · 결제의 기록에도(open:<상자>)
		local got, n = openBox(c, def.box)
		logBuy(c, ("open%d_%s"):format(os.time(), def.id), "open:" .. def.box, os.time(), got, n)
		return true, if got then ("「%s」이(가) 나왔다"):format(Cash.itemName(got)) else ""
	end
	return nil, "쓸 수 없는 아이템이다"
end

-- 선택 상자를 쓴다(2026-11-10 상자 판매 바로잡기): id = 고른 것 → 그것이 나오는 상자의 선택 상자(bm_pick_<상자>)를 가방에서 하나 쓰고 그것을 준다(가진 것이면 하나 더)
--  → true · 받은 뒤의 가진 수 / nil · 까닭
function Cash.pickBox(h, acct, id: any): (boolean?, any)
	local c = acct.bm
	if typeof(id) ~= "string" then
		return nil, "고를 것을 고른다"
	end
	for _, bid in boxesOf(id) do
		local item = "bm_pick_" .. bid
		if h and Bag.count(h, item) > 0 then
			Bag.take(h, item, 1)
			giveBoxItem(c, bid, id)
			logBuy(c, ("pick%d_%s"):format(os.time(), id), "pick:" .. bid, os.time(), id, Cash.count(c, id))
			return true, Cash.count(c, id)
		end
	end
	return nil, "그 상자의 선택 상자가 없다"
end

-- 상자 판매 바로잡기(2026-11-10 사용자: "다시 다뺏고 안연상자를 산것보다 카테고리별로 +3인거야 그리고 상자별로 선택상자를 주는걸로"):
--  buy = server/lune/modules/dupfixBuys.luau의 한 사람(로블록스 판매 기록에서 센 산 수 · direct = 옛 상점에서 따로 산 달토끼) · ver = 바로잡기의 차례(계정에 한 번 — c.boxReset).
--  산 상자마다: 그 상자의 것을 모두 거둔다(가진 것 · 하나 더 받은 수 · 남은 겹침 보상 — 따로 산 달토끼는 하나를 남긴다) → 보관함에 안 연 상자(산 수 + 3) · 선택 상자 하나.
--  보관함의 윤슬 조각도 거둔다(이 사람들은 윤슬 조각을 산 적이 없고 보스 보상은 가방으로 간다 = 보관함의 것은 모두 겹침에서 나온 것 — 가방의 것은 보스 보상과 섞여 두었다 · 제가 정한 것).
--  낀 것 · 꺼낸 펫 · 고른 탈것이 사라졌으면 푼다. → { taken = { [이름표] = 거둔 수 }, boxes = { [상자] = 안 연 상자 수 }, shards = 거둔 윤슬 조각 } / 이미 했으면 nil
Cash.RESET_PLUS = 3
function Cash.boxReset(c, buy, now: number, ver: number)
	if typeof(buy) ~= "table" or c.boxReset == ver then
		return nil
	end
	local direct = {}
	for _, id in (typeof(buy.direct) == "table" and buy.direct) or {} do
		direct[id] = true
	end
	local ids = {}
	for bid in Gacha.BOXES do
		table.insert(ids, bid)
	end
	table.sort(ids)
	local out = { taken = {}, boxes = {}, shards = 0 }
	for _, bid in ids do
		local bought = buy[bid]
		if typeof(bought) == "number" and bought > 0 then
			local set = Gacha.ownedOf(c, bid)
			for _, e in Gacha.BOXES[bid].pool or {} do
				local id = e[1]
				local had = Cash.count(c, id)
				if set[id] then
					if direct[id] then
						if had > 1 then
							out.taken[id] = had - 1 -- (따로 산 것 하나는 남긴다)
						end
					else
						set[id] = nil
						out.taken[id] = had
					end
				end
				if typeof(c.extra) == "table" then
					c.extra[id] = nil
				end
			end
			if typeof(c.dupfix) == "table" then
				c.dupfix[bid] = nil
			end
			if typeof(c.fixGiven) == "table" then
				c.fixGiven[bid] = nil
			end
			addBox(c, "bm_box_" .. bid, bought + Cash.RESET_PLUS)
			addBox(c, "bm_pick_" .. bid, 1)
			out.boxes[bid] = bought + Cash.RESET_PLUS
		end
	end
	for i = #c.box, 1, -1 do
		if c.box[i].id == "yunseul" then
			out.shards += c.box[i].n
			table.remove(c.box, i)
		end
	end
	if c.mount and not c.mounts[c.mount] then
		c.mount = false
	end
	if c.dskin and not c.dskins[c.dskin] then
		c.dskin = false
	end
	if c.bubble and not c.bubbles[c.bubble] then
		c.bubble = false
	end
	if c.ntag and not c.ntags[c.ntag] then
		c.ntag = false
	end
	local keep = {}
	for _, k in Cash.petsOut(c) do
		local n = 0
		for _, q in keep do
			if q == k then
				n += 1
			end
		end
		if c.pets[k] and n < Cash.count(c, k) then
			table.insert(keep, k)
		end
	end
	c.petsOut = keep
	syncPets(c)
	c.boxReset = ver
	logBuy(c, ("reset%d"):format(ver), "boxreset", now)
	return out
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
-- 가진 말풍선 꾸밈(설계의 차례 — 2026-11-07)
function Cash.bubbleList(set): { string }
	local out = {}
	for _, q in (D.bubbles and D.bubbles.list) or {} do
		if set[q.id] then
			table.insert(out, q.id)
		end
	end
	return out
end
-- 가진 이름표 테두리(설계의 차례 — 2026-11-10)
function Cash.ntagList(set): { string }
	local out = {}
	for _, q in (D.nametags and D.nametags.list) or {} do
		if set[q.id] then
			table.insert(out, q.id)
		end
	end
	return out
end
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
-- 가진 캐시 무기의 이름표들(상품의 차례)
-- 가진 데미지 스킨의 목록(정해진 차례 — 2026-10-29)
function Cash.dskinList(set): { string }
	local out = {}
	for _, e in require(lune.data["event.generated"]).list do
		for _, q in e.dskins or {} do
			if set[q.id] then
				table.insert(out, q.id)
			end
		end
	end
	for _, q in (D.dskins and D.dskins.list) or {} do -- (데미지 스킨 상자의 것 — 2026-11-10)
		if set[q.id] then
			table.insert(out, q.id)
		end
	end
	return out
end
function Cash.skinList(set): { string }
	local out = {}
	for _, q in require(lune.data["dye.generated"]).skins do
		if set[q.id] then
			table.insert(out, q.id)
		end
	end
	return out
end
-- 펫을 꺼낸다(id · on이 false가 아니면 — 꺼내 둔 펫들에 더한다: PET_MAX까지) · 그 펫을 넣는다(id, false) · 모두 넣는다(false) → true / nil · 까닭
--  2026-10-30 셋까지(사용자 "펫 … 3마리까지 낄수있게해줘") — 그 전에는 꺼내면 있던 것과 바꿨다
Cash.PET_FULL = "펫은 셋까지 꺼내 둘 수 있다"
function Cash.setPet(acct, id: any, on: any?): (boolean?, string?)
	local c = acct.bm
	syncPets(c)
	if id == false then
		table.clear(c.petsOut)
	elseif typeof(id) ~= "string" or not c.pets[id] then
		return nil, "가진 펫이 아니다"
	else
		local at = table.find(c.petsOut, id)
		if on == false then
			Cash.petRemove(c, id) -- (같은 펫을 여럿 꺼냈으면 모두 — 하나씩은 Cash.petOne · 2026-11-10)
		elseif not at then
			if #c.petsOut >= Cash.PET_MAX then
				return nil, Cash.PET_FULL
			end
			table.insert(c.petsOut, id)
		end
	end
	syncPets(c)
	return true
end
-- 같은 펫을 하나 더 꺼낸다(add) · 하나 넣는다(2026-11-10 — 가진 수만큼 · PET_MAX까지): 가방 캐시 탭의 「하나 더 꺼내기」 · 「하나 넣기」
Cash.PET_NO_MORE = "더 꺼낼 같은 펫이 없다"
function Cash.petOne(acct, id: any, add: boolean): (boolean?, string?)
	local c = acct.bm
	syncPets(c)
	if typeof(id) ~= "string" or not c.pets[id] then
		return nil, "가진 펫이 아니다"
	end
	if add then
		if Cash.petOutCount(c, id) >= Cash.count(c, id) then
			return nil, Cash.PET_NO_MORE
		elseif #c.petsOut >= Cash.PET_MAX then
			return nil, Cash.PET_FULL
		end
		table.insert(c.petsOut, id)
	else
		for i = #c.petsOut, 1, -1 do -- (마지막에 꺼낸 것부터)
			if c.petsOut[i] == id then
				table.remove(c.petsOut, i)
				break
			end
		end
	end
	syncPets(c)
	return true
end
-- 캐시 무기를 장착한다(이름표) · 해제한다(false) → true / nil · 까닭. hero = 그 캐릭터에(2026-11-03 사용자 "무기스킨 캐릭마다 낄수있게해달라고하네 지금은 하나끼면 전캐릭 다 적용되잖아
--  캐릭터 각각 뭐껴놨으면 그걸로 되야되는거지" — 가진 것은 계정의 것 · 낀 것은 캐릭터마다). hero가 없으면 계정의 것(이 캐릭터별이 생기기 전의 낀 것 — 아직 정하지 않은 캐릭터가 한 번 이어받는다)
function Cash.setWskin(acct, id: any, hero: any?): (boolean?, string?)
	local c = acct.bm
	if id ~= false and (typeof(id) ~= "string" or not c.wskins[id]) then
		return nil, "가진 캐시 무기가 아니다"
	end
	if hero then
		hero.wskin = id
	else
		c.wskin = id
	end
	return true
end
-- 그 캐릭터가 낀 캐시 무기(이름표 · 없으면 false): 아직 정하지 않은 캐릭터(이것이 생기기 전에 만든 것)는 계정에 껴 두었던 것을 한 번 이어받는다 · 가진 것이 아니면 뺀다
function Cash.heroWskin(acct, hero): string | false
	local c = acct and acct.bm
	if not hero then
		return false
	end
	if hero.wskin == nil then
		hero.wskin = if c and typeof(c.wskin) == "string" and c.wskins[c.wskin] then c.wskin else false
	end
	if typeof(hero.wskin) == "string" and not (c and c.wskins[hero.wskin]) then
		hero.wskin = false
	end
	return hero.wskin
end
-- 말풍선 꾸밈을 장착한다 · 해제한다(false) → true / nil · 까닭(2026-11-07 — 데미지 스킨과 같다)
function Cash.setBubble(acct, id: any): (boolean?, string?)
	local c = acct.bm
	if id == false then
		c.bubble = false
		return true
	elseif typeof(id) ~= "string" or not c.bubbles[id] then
		return nil, "가진 말풍선 꾸밈이 아니다"
	end
	c.bubble = id
	return true
end
-- 이름표 테두리를 장착한다 · 해제한다(false) → true / nil · 까닭(2026-11-10 — 말풍선 꾸밈과 같다)
function Cash.setNtag(acct, id: any): (boolean?, string?)
	local c = acct.bm
	if id == false then
		c.ntag = false
		return true
	elseif typeof(id) ~= "string" or not c.ntags[id] then
		return nil, "가진 이름표 테두리가 아니다"
	end
	c.ntag = id
	return true
end
-- 데미지 스킨을 장착한다(이름표) · 해제한다(false) → true / nil · 까닭(2026-10-29 — 사용자 "데미지스킨은 캐시탭에서 꼈다 뺏다 할수있어야하고")
function Cash.setDskin(acct, id: any): (boolean?, string?)
	local c = acct.bm
	if id == false then
		c.dskin = false
		return true
	elseif typeof(id) ~= "string" or not c.dskins[id] then
		return nil, "가진 데미지 스킨이 아니다"
	end
	c.dskin = id
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

-- 사냥 경험치 배율: 경험치 쿠폰(30분 1.5배)과 영구 게임 패스(h.passXp — 경험치 1.25배 패스 = 0.25)를 더한다(둘 다면 1.75배 — 2026-10-22 제가 정한 것)
function Cash.expMul(h): number
	return 1 + (if (h.expLeft or 0) > 0 then D.rules.exp.mul - 1 else 0) + (h.passXp or 0)
end
-- 장비 · 재료 · 귀한 물건이 나올 확률의 배율: 드롭률 쿠폰(30분 1.5배 — 2026-10-27)과 영구 게임 패스(h.passDrop — 드롭률 1.25배 패스 = 0.25)를 더한다(둘 다면 1.75배).
--  달돈 · 달가루 · 퀘스트 물건에는 붙지 않는다(sim/room.luau의 lootFor). 주간 보스의 이름 붙은 장비에는 파티에서 가장 높은 사람의 이 배율이 붙는다(sim/weekly.luau의 roll — 2026-10-27)
function Cash.dropMul(h): number
	return 1 + (if (h.dropLeft or 0) > 0 then D.rules.drop.mul - 1 else 0) + (h.passDrop or 0)
end
-- 영구 게임 패스의 효과를 더한다: owned = { [상품] = true } → 경험치 · 드롭에 더할 몫(상품의 effect — 공방 bm.js)
function Cash.passEffect(owned: any): (number, number)
	local xp, drop = 0, 0
	for _, p in D.products do
		if p.kind == "pass" and typeof(p.effect) == "table" and typeof(owned) == "table" and owned[p.id] == true then
			xp += p.effect.xp or 0
			drop += p.effect.drop or 0
		end
	end
	return xp, drop
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
	local wskins = {}
	for k in c.wskins do
		table.insert(wskins, k)
	end
	table.sort(wskins)
	local dskins = {}
	for k in c.dskins do
		table.insert(dskins, k)
	end
	table.sort(dskins)
	local extra = {} -- 더 받은 수(2026-11-10 — 가진 것만)
	for k, n in (typeof(c.extra) == "table" and c.extra) or {} do
		if owns(c, k) and whole(n, 1, 9999) then
			extra[k] = n
		end
	end
	local dupfix = {}
	for k, n in (typeof(c.dupfix) == "table" and c.dupfix) or {} do
		if Gacha.box(k) and whole(n, 1, 999) then
			dupfix[k] = n
		end
	end
	local log = {}
	for _, e in (typeof(c.log) == "table" and c.log) or {} do
		table.insert(log, { r = e.r, k = e.k, t = e.t, g = e.g, n = e.n })
	end
	local fixGiven = {}
	for k, n in (typeof(c.fixGiven) == "table" and c.fixGiven) or {} do
		if Gacha.box(k) and whole(n, 1, 9999) then
			fixGiven[k] = n
		end
	end
	return { boxReset = c.boxReset or 0, fixGiven = fixGiven, log = log, dupfix = dupfix, extra = extra, ntags = Cash.ntagList(c.ntags), ntag = c.ntag, bubbles = Cash.bubbleList(c.bubbles), bubble = c.bubble, dskins = dskins, dskin = c.dskin, ev = table.clone(c.ev), box = box, rec = table.clone(c.rec), week = c.week, wc = table.clone(c.wc), once = table.clone(c.once), slots = c.slots, store = c.store, pass = Pass.pack(c.pass), pets = pets, mounts = mounts, petsOut = table.clone(Cash.petsOut(c)), petOut = c.petOut, mount = c.mount, coupons = table.clone(c.coupons), wskins = wskins, wskin = c.wskin, gift = if c.gift then table.clone(c.gift) else false, lock = c.lock == true }
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
	for _, pair in { { "pets", PET }, { "mounts", MOUNT }, { "wskins", WSKIN }, { "dskins", DSKIN }, { "bubbles", BUBBLE }, { "ntags", NTAG } } do
		if typeof(data[pair[1]]) == "table" then
			for _, k in data[pair[1]] do
				if typeof(k) == "string" and pair[2][k] then
					c[pair[1]][k] = true
				end
			end
		end
	end
	-- 더 받은 수(2026-11-10 — 가진 것만 · 이상한 수는 버린다)
	if typeof(data.extra) == "table" then
		local n = 0
		for k, v in data.extra do
			if owns(c, k) and whole(v, 1, 9999) and n < 300 then
				c.extra[k] = v
				n += 1
			end
		end
	end
	-- 겹침 보상의 남은 횟수 · 결제의 기록(2026-11-10)
	if typeof(data.dupfix) == "table" then
		for k, v in data.dupfix do
			if typeof(k) == "string" and Gacha.box(k) and whole(v, 1, 999) then
				c.dupfix[k] = v
			end
		end
	end
	c.boxReset = if whole(data.boxReset, 0, 1000) then data.boxReset else 0 -- 상자 판매 바로잡기를 한 차례(2026-11-10 — Cash.boxReset)
	if typeof(data.fixGiven) == "table" then -- 자동 보상으로 이미 준 수(2026-11-10 — Cash.dupfixAuto)
		for k, v in data.fixGiven do
			if typeof(k) == "string" and Gacha.box(k) and whole(v, 1, 9999) then
				c.fixGiven[k] = v
			end
		end
	end
	if typeof(data.log) == "table" then
		for _, e in data.log do
			if typeof(e) == "table" and typeof(e.r) == "string" and #e.r <= 80 and typeof(e.k) == "string" and #e.k <= 60 and whole(e.t, 0, 1e10) and #c.log < Cash.LOG_KEEP then
				table.insert(c.log, { r = e.r, k = e.k, t = e.t, g = if typeof(e.g) == "string" and #e.g <= 40 then e.g else nil, n = if whole(e.n, 1, 1e4) then e.n else nil })
			end
		end
	end
	-- 꺼내 둔 펫들(2026-10-30 — 가진 것 · PET_MAX까지) · 그 전의 저장은 petOut 하나. 같은 펫은 가진 수까지(2026-11-10)
	c.petsOut = {}
	for _, k in (if typeof(data.petsOut) == "table" then data.petsOut else { data.petOut }) do
		if typeof(k) == "string" and c.pets[k] and Cash.petOutCount(c, k) < Cash.count(c, k) and #c.petsOut < Cash.PET_MAX then
			table.insert(c.petsOut, k)
		end
	end
	syncPets(c)
	c.mount = if typeof(data.mount) == "string" and c.mounts[data.mount] then data.mount else false
	c.wskin = if typeof(data.wskin) == "string" and c.wskins[data.wskin] then data.wskin else false
	c.dskin = if typeof(data.dskin) == "string" and c.dskins[data.dskin] then data.dskin else false
	c.bubble = if typeof(data.bubble) == "string" and c.bubbles[data.bubble] then data.bubble else false -- 말풍선 꾸밈(2026-11-07)
	c.ntag = if typeof(data.ntag) == "string" and c.ntags[data.ntag] then data.ntag else false -- 이름표 테두리(2026-11-10)
	if typeof(data.ev) == "table" then
		local n = 0
		for k, v in data.ev do
			if typeof(k) == "string" and #k <= 60 and whole(v, 0, 1e6) and n < 100 then
				c.ev[k] = v
				n += 1
			end
		end
	end
	local g = data.gift
	if typeof(g) == "table" and PRODUCT[g.k] and whole(g.uid, 1, 1e15) and typeof(g.to) == "string" and #g.to <= 60 and whole(g.at, 0, 1e10) then
		c.gift = { k = g.k, uid = g.uid, to = g.to, at = g.at }
	end
	c.lock = data.lock == true
	if typeof(data.coupons) == "table" then
		local n = 0
		for code, at in data.coupons do
			if typeof(code) == "string" and #code <= Cash.COUPON_MAX and whole(at, 0, 1e10) and n < 200 then
				c.coupons[code] = at
				n += 1
			end
		end
	end
	return c
end

-- ---------- 쿠폰(2026-10-21 사용자: "쿠폰 코드 입력창있어야하고 그 쿠폰 입력하면 그 기본펫 지급하는 방식으로 합니다") ----------
--  쿠폰의 목록은 서버에만 있다(server/lune/modules/coupons.luau — 화면에 보내지 않는다). 여기는 적은 글을 고르는 셈과 주는 셈만.
Cash.COUPON_MAX = 24 -- 쿠폰 번호의 가장 긴 글자 수
-- 적은 글 → 쿠폰 번호의 꼴(앞뒤 빈칸 · 가운데 빈칸 · 줄표를 빼고 대문자로). 쓸 수 없는 글이면 nil
function Cash.couponCode(text: any): string?
	if typeof(text) ~= "string" or #text > 64 then
		return nil
	end
	local code = string.upper((string.gsub(text, "[ \t\r\n%-]", "")))
	if code == "" or #code > Cash.COUPON_MAX or string.find(code, "[^%w]") then
		return nil
	end
	return code
end
-- 쿠폰을 쓴다: def = 서버의 쿠폰 { code, pet?, mount?, from?, till? } · 됐으면 true와 받은 것({ pet = 이름표, mount = 이름표 }), 아니면 false와 까닭
function Cash.redeem(acct, def, now: number): (boolean, any)
	local c = acct.bm
	if def.from and now < def.from then
		return false, "아직 쓸 수 없는 쿠폰이다"
	elseif def.till and now > def.till then
		return false, "기간이 지난 쿠폰이다"
	elseif c.coupons[def.code] then
		return false, "이미 쓴 쿠폰이다"
	end
	if def.pet and not PET[def.pet] then
		return false, "없는 펫이다"
	elseif def.mount and not MOUNT[def.mount] then
		return false, "없는 탈것이다"
	end
	if def.pet then
		c.pets[def.pet] = true -- 펫: 계정에 바로(꺼내 둔 것이 없으면 바로 꺼낸다 — 산 펫과 같다)
		Cash.petAuto(c, def.pet)
	end
	if def.mount then
		c.mounts[def.mount] = true -- 탈것(2026-10-21 쿠폰 탈것 「떠도는 책」): 계정에 바로(고른 것이 없으면 그것을 고른다 — 산 탈것과 같다)
		c.mount = c.mount or def.mount
	end
	c.coupons[def.code] = now
	return true, { pet = def.pet, mount = def.mount }
end

-- 살 수 있게 된 상품인가: 로블록스 상품 번호가 있고(대시보드에서 만든 뒤) 게임에 만들어 둔 것(built — 펫 · 순간이동 · 꾸밈 · 패스는 아직)
function Cash.ready(p): boolean
	local hasId = (typeof(p.rid) == "number" and p.rid > 0) or (typeof(p.rid) == "string" and p.rid ~= "")
	return hasId and p.built == true
end

-- 상점 창에 보내는 것: 상품마다 살 수 있나(ready) · 산 수(주간이면 이번 주) · 패스를 가졌나 · 보관함 · 주머니 · 상자의 레벨대(band)
--  stocks = 한정 판매의 남은 수 { [상품] = n }(서버가 세계 기록에서 읽은 것 — 2026-10-29) → 줄의 left(모르면 nil)
function Cash.view(acct, now: number, owned: any?, live: number?, prices: any?, stocks: any?, hero: any?) -- hero = 지금 캐릭터(낀 캐시 무기 — 2026-11-03)
	local c = acct.bm
	local list = {}
	for _, p in D.products do
		local robux = if typeof(prices) == "table" and typeof(prices[p.id]) == "number" then prices[p.id] else p.robux -- 로블록스의 실제 값(대시보드에서 바꾸면 그 값) · 못 읽었으면 설계의 값
		table.insert(list, { id = p.id, ready = Cash.ready(p), bought = Cash.bought(c, p.id, now), own = (owned ~= nil and owned[p.id] == true) or c.pets[p.id] == true or c.mounts[p.id] == true or c.wskins[p.id] == true, robux = robux, left = if p.stock and typeof(stocks) == "table" and typeof(stocks[p.id]) == "number" then stocks[p.id] else nil, boxLeft = if Gacha.box(p.id) then Gacha.left(p.id, Gacha.ownedOf(c, p.id)) else nil }) -- boxLeft = 뽑기 상자에서 아직 나올 수 있는 것의 수(2026-11-07) -- own = 게임 패스를 가졌다 · 펫 · 탈것을 샀다 · left = 한정 판매의 남은 수
	end
	local box = {}
	for _, e in c.box do
		table.insert(box, { id = e.id, n = e.n })
	end
	return { list = list, box = box, band = Cash.bandOf(Cash.topLevel(acct, live)), slots = c.slots, store = c.store, pass = Pass.view(c.pass, now), pets = Cash.ownList(c.pets), mounts = Cash.ownList(c.mounts), petsOut = table.clone(Cash.petsOut(c)), petOut = c.petOut, mount = c.mount, wskins = Cash.skinList(c.wskins), wskin = if hero then Cash.heroWskin(acct, hero) else c.wskin, dskins = Cash.dskinList(c.dskins), dskin = c.dskin, bubbles = Cash.bubbleList(c.bubbles), bubble = c.bubble, ntags = Cash.ntagList(c.ntags), ntag = c.ntag, ev = table.clone(c.ev), extra = table.clone(c.extra or {}), dupfix = table.clone(c.dupfix or {}) } -- extra = 더 받은 수(가방 캐시 탭의 「×n」 — 2026-11-10)
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
	for _, id in { "bm_bagx", "bm_storex", "bm_rename", "bm_exp", "bm_drop", "bm_dyepoint", "bm_dyerobe" } do
		local g = Items.goods(id)
		if not g or not g.paid then
			table.insert(bad, id)
		end
	end
	return bad
end

return Cash
