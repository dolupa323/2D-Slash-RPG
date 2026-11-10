-- 로블록스 결제(로벅스) — 서버만. 셈은 shared/lune/sim/cash.luau, 설계는 공방 js/lune/design/bm.js(2026-10-20).
--  로블록스 공식 문서(developer-products · game-passes · subscriptions)에서 읽은 것:
--   · ProcessReceipt는 서버의 한 곳에서만 정한다 · 준 것이 확실할 때만 PurchaseGranted · 아니면 NotProcessedYet(그 사람이 다음에 들어올 때 다시 보낸다)
--   · PromptProductPurchaseFinished는 「샀다」가 아니다 — 주는 것은 ProcessReceipt에서만
--   · 게임 패스는 로블록스가 산 기록을 남기지 않는다(UserOwnsGamePassAsync로 본다) · 구독은 GetUserSubscriptionStatusAsync · Players.UserSubscriptionStatusChanged
--  같은 결제를 두 번 주지 않는다: 처리한 결제 번호를 계정 저장(acct.bm.rec)에 남기고, 준 것과 번호를 한 번의 저장으로 함께 적는다(계정 잠금 — 한 계정은 한 서버만 쓴다).
--  저장에 실패하면 준 것을 되돌리고 NotProcessedYet — 돈을 받고 주지 않는 일 · 두 번 주는 일 둘 다 없게.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local lune = game:GetService("ReplicatedStorage").shared.lune
local Cash = require(lune.sim.cash)
local Account = require(lune.sim.account)

local Coupons = require(script.Parent.coupons)
local Store = require(script.Parent.store)

local CashServer = {}
local W -- World가 넘겨주는 것: sessionOf(userId) · saveNow(s) · afterSpent(s) · notify(s, key) · now()
local pending = {} -- [userId] = { [상품] = 띄워 둔 구매 창 수 }

function CashServer.pending(userId: number, key: string): number
	return (pending[userId] and pending[userId][key]) or 0
end
local function addPending(userId: number, key: string, d: number)
	pending[userId] = pending[userId] or {}
	pending[userId][key] = math.max(0, (pending[userId][key] or 0) + d)
end
function CashServer.forget(userId: number)
	pending[userId] = nil
end

-- ---------- 한정 판매(2026-10-29 사용자: "거인 라이딩 황금으로 해서 한정 20개 판매로 해서 판매하고 다팔리면 안파는식으로") ----------
--  상품의 stock = 모든 서버를 합쳐 팔 수 있는 수(store.luau의 세계 기록 stock_<상품>). 구매 창을 띄우기 전에 한 개를 잡아 두고(HOLD초) · 결제가 오면 판 것으로 ·
--  사지 않고 창을 닫으면 놓는다. 남은 수는 STOCK_KEEP초마다 다시 읽어 상점 줄에 보낸다(「남은 n개」 · 다 팔리면 「품절」 — 구매 창을 띄우지 않는다)
CashServer.HOLD = 600 -- 잡아 두는 시간(초 — 로블록스의 구매 창이 떠 있을 만한 시간 · 제가 정한 것)
CashServer.STOCK_KEEP = 30
CashServer.clock = os.time
local stockLeft = {} -- [상품] = 남은 수(판 수만 뺀다 — 남이 잡아 둔 것은 빼지 않는다)
local function noteStock(key: string, rec)
	local p = Cash.product(key)
	if p and p.stock and typeof(rec) == "table" and typeof(rec.sold) == "number" then
		stockLeft[key] = math.max(0, p.stock - rec.sold)
	end
end
function CashServer.stocks(): { [string]: number }
	return stockLeft
end
-- 한정 판매하는 상품의 남은 수를 새로 읽는다
function CashServer.readStocks()
	for _, p in Cash.PRODUCTS do
		if p.stock then
			local ok, read, rec = pcall(Store.stockGet, p.id, CashServer.clock())
			if ok and read then
				noteStock(p.id, rec)
			end
		end
	end
end

-- 결제 하나를 처리한다(로블록스가 부른다 · 테스트와 Studio의 Debug도 같은 길로).
--  info = { PlayerId, ProductId, PurchaseId, CurrencySpent } · key = 상품(없으면 ProductId로 찾는다)
function CashServer.processReceipt(info, key: string?)
	local Decision = Enum.ProductPurchaseDecision
	local k = key or Cash.byRid(info.ProductId)
	if not k then
		warn("[Cash] 모르는 상품 번호", info.ProductId)
		return Decision.NotProcessedYet
	end
	local s = W.sessionOf(info.PlayerId)
	if not s or not s.acct or not s.loaded or s.guest then
		return Decision.NotProcessedYet -- 이 서버에 없거나 계정을 다 읽지 못했다 — 들어올 때 다시
	end
	local acct = s.acct
	local p = Cash.product(k)
	-- 한정 판매: 잡아 둔 것을 판 것으로 적는다(이미 준 결제 — 로블록스가 다시 보낸 것 — 은 다시 세지 않는다)
	local took = false
	if p and p.stock and not Cash.granted(acct.bm, tostring(info.PurchaseId)) then
		local done, rec = Store.stockTake(k, info.PlayerId, p.stock, CashServer.clock())
		if not done then
			return Decision.NotProcessedYet -- 기록에 닿지 못했다 — 로블록스가 다시 보낸다
		end
		took = true
		noteStock(k, rec)
	end
	local function untake()
		if took then
			local _, rec = Store.stockUntake(k, info.PlayerId, CashServer.clock(), CashServer.HOLD)
			noteStock(k, rec)
		end
	end
	-- 선물로 띄운 구매 창의 결제(2026-10-31): 받는 계정의 선물 상자에 넣고 산 사람의 계정에는 결제 번호만 남긴다
	local gift = acct.bm.gift
	if gift and gift.k == k then
		local pid = tostring(info.PurchaseId)
		if Cash.granted(acct.bm, pid) then
			return Decision.PurchaseGranted -- 이미 보낸 결제(로블록스가 다시 보냈다)
		end
		if not Store.bmGiftAdd(gift.uid, { k = k, rid = pid, from = s.name or "", to = gift.to, at = W.now() }) then
			untake()
			return Decision.NotProcessedYet -- 선물 상자에 닿지 못했다 — 로블록스가 다시 보낸다(같은 결제 번호는 상자에 한 번만 든다)
		end
		local spentBefore = acct.spent
		Cash.note(acct.bm, pid)
		acct.spent += math.max(0, math.floor(tonumber(info.CurrencySpent) or 0))
		acct.bm.gift = false
		if W.saveNow(s) then
			addPending(info.PlayerId, k, -1)
			task.spawn(W.afterSpent, s)
			CashServer.ping(gift.uid)
			W.giftSent(s, k, gift.to)
			return Decision.PurchaseGranted
		end
		local at = table.find(acct.bm.rec, pid)
		if at then
			table.remove(acct.bm.rec, at)
		end
		acct.spent, acct.bm.gift = spentBefore, gift
		untake()
		return Decision.NotProcessedYet
	end
	local before, spentBefore = Cash.pack(acct.bm), acct.spent
	local ok, why = Cash.grant(acct, k, tostring(info.PurchaseId), W.now(), Account.MAX, s.hero and s.hero.level)
	if not ok then
		if why == "dup" then
			return Decision.PurchaseGranted -- 이미 준 결제(로블록스가 다시 보냈다)
		end
		acct.bm = Cash.unpack(before, Account.MAX)
		warn("[Cash] 줄 수 없는 상품", k, why)
		untake()
		return Decision.NotProcessedYet
	end
	acct.spent += math.max(0, math.floor(tonumber(info.CurrencySpent) or 0))
	if s.hero and string.sub(k, 1, 6) == "wskin_" then
		s.hero.wskin = k -- 산 캐시 무기는 산 캐릭터가 바로 낀다(캐릭터마다 — 2026-11-03 · 계정의 것도 그대로: 아직 정하지 않은 캐릭터가 이어받는다)
	end
	if W.saveNow(s) then
		addPending(info.PlayerId, k, -1)
		task.spawn(W.afterSpent, s)
		W.notify(s, k)
		return Decision.PurchaseGranted
	end
	acct.bm = Cash.unpack(before, Account.MAX)
	acct.spent = spentBefore
	untake()
	return Decision.NotProcessedYet
end

-- 쿠폰을 쓴다(2026-10-21 — 메뉴의 「쿠폰」 창): text = 적은 글 → { ok, why?, pet?, mount? }
--  틀린 번호는 1분에 다섯 번까지(번호를 마구 넣어 맞히지 못하게) · 준 것과 쓴 쿠폰을 한 번의 저장으로 함께 적는다(저장에 실패하면 되돌린다 — 결제와 같다)
Coupons.TRIES, Coupons.WINDOW = 5, 60
function CashServer.coupon(s, text: any)
	if not s or not s.acct or not s.loaded or s.guest then
		return { ok = false, why = "지금은 쓸 수 없다" }
	end
	local now = W.now()
	local tries = {}
	for _, t in s.couponTries or {} do
		if now - t < Coupons.WINDOW then
			table.insert(tries, t)
		end
	end
	s.couponTries = tries
	if #tries >= Coupons.TRIES then
		return { ok = false, why = "잠시 뒤에 다시 적어 주세요" }
	end
	local code = Cash.couponCode(text)
	local def = Coupons.find(code)
	if not def then
		table.insert(tries, now)
		return { ok = false, why = "없는 쿠폰 번호다" }
	end
	local before = Cash.pack(s.acct.bm)
	local ok, got = Cash.redeem(s.acct, def, now)
	if not ok then
		return { ok = false, why = got }
	end
	if not W.saveNow(s) then
		s.acct.bm = Cash.unpack(before, Account.MAX)
		return { ok = false, why = "저장하지 못했다 — 잠시 뒤에 다시 적어 주세요" }
	end
	if got.pet or got.mount then
		W.notify(s, got.pet or got.mount) -- 화면이 가진 것을 다시 읽고 · 꺼낸 펫을 같은 맵의 사람들에게도
	end
	return { ok = true, pet = got.pet, mount = got.mount }
end

-- 쓴 쿠폰의 보상을 지금의 목록에 맞춘다(계정을 읽었을 때 — 2026-10-21 사용자: "지금 내 테스트 계정에서 다시 쿠폰을 입력할수없어서 동글이는 사라지고, 재까마귀를 테스트할수도없어").
--  쿠폰 펫을 까망 동글이 → 아기 재까마귀로 바꾸며, 이미 쓴 계정에는 쓴 기록만 남고 펫이 없었다 → 쓴 쿠폰이 지금 주는 펫이 없으면 넣어 준다(꺼내 둔 펫이 없으면 꺼낸다). 바뀌었으면 true
function CashServer.syncCoupons(acct): boolean
	local c, changed = acct.bm, false
	for code in c.coupons do
		local def = Coupons.find(code)
		if def and def.pet and Cash.PET[def.pet] and not c.pets[def.pet] then
			c.pets[def.pet] = true
			Cash.petAuto(c, def.pet)
			changed = true
		end
		if def and def.mount and Cash.MOUNT[def.mount] and not c.mounts[def.mount] then -- 쿠폰 탈것도 같이(2026-10-21)
			c.mounts[def.mount] = true
			c.mount = c.mount or def.mount
			changed = true
		end
	end
	return changed
end

-- 레벨 순위 1위 선물(2026-10-25 사용자: "사슴 라이딩인데 하얀색+황금색으로 된 사슴라이딩하나 만들자 만렙 축하선물로줄거야" → 바로 "랭킹 1등으로 한사람만주는거야 백금사슴"):
--  탈것 가운데 free = "max"인 것(백금 사슴)을 레벨 순위 1위 한 사람에게만 — 처음으로 Lv.150에 오른 캐릭터(세계 기록 firstMax — 순위판 1위에 고정된 그 캐릭터)로 게임에 있는 계정.
--  (2026-10-24 기록 = 강타) · 기록이 아직 없는 서버에서는 처음 만렙이 적히는 순간 그 사람이 받는다. world.luau가 1초마다 부른다.
--  넣었으면 곧바로 저장하고 화면에 알린다(CashGot — 「레벨 순위 1위 선물」). 고른 탈것이 없으면 그것을 고른다. 넣었으면 그 탈것의 이름표, 아니면 nil
local Rank = require(lune.sim.rank)
-- 2위 · 3위(2026-10-26 사용자: "만렙 두번째, 세번째로 찍은 사람들한테 보상으로 줄거야 1등 황금사슴 들어간거처럼 2등 실버사슴 3등 동색사슴이야"):
--  free = "max2" · "max3" — 만렙에 오른 차례의 세계 기록(maxTen — server titles.luau)의 둘째 · 셋째 캐릭터. 1위는 그대로 처음 만렙의 기록(firstMax)
--  받는 것(같은 날 사용자: "1위는 금은동 다주고 2위는 은 동 주고 3위는 동 주고"): 1위 = 금 · 은 · 동 · 2위 = 은 · 동 · 3위 = 동
CashServer.RANK_GIFTS = { { "max", "max2", "max3" }, { "max2", "max3" }, { "max3" } }
-- 순위 사슴(free = max · max2 · max3)의 이름표들(관리 창 「순위 사슴」 — 관리자가 모습을 본다)
function CashServer.rankMounts(): { string }
	local list = {}
	for id, def in Cash.MOUNT do
		if def.free == "max" or def.free == "max2" or def.free == "max3" then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end
function CashServer.maxGift(s): string?
	if not s.hero or not s.cid or not s.acct or not s.loaded or s.guest then
		return nil
	end
	local key = Rank.charKey(s.player.UserId, s.cid)
	local rank = nil
	local rec = require(script.Parent.firstMax).get()
	if rec and rec.key == key then
		rank = 1
	else
		local ten = require(script.Parent.titles).ten()
		if ten and ten[2] and ten[2].key == key then
			rank = 2
		elseif ten and ten[3] and ten[3].key == key then
			rank = 3
		end
	end
	if not rank then
		return nil -- 1 · 2 · 3위(만렙에 오른 차례)의 캐릭터가 아니다
	end
	local c = s.acct.bm
	local given = {}
	for _, want in CashServer.RANK_GIFTS[rank] do
		for id, def in Cash.MOUNT do
			if def.free == want and not c.mounts[id] then
				c.mounts[id] = true
				c.mount = c.mount or id -- (고른 탈것이 없으면 가장 높은 것 — 금 → 은 → 동의 차례로 넣는다)
				s.dirty = true
				table.insert(given, id)
			end
		end
	end
	if #given > 0 and W then
		W.saveNow(s) -- 저장한 뒤에 알린다(받은 것마다)
		for _, id in given do
			W.notify(s, id)
		end
	end
	return given[1]
end

-- 쿠폰 기록을 지운다(관리자 — 2026-10-21 사용자: "쿠폰 기록을 초기화해줘 쿠폰등록하는것부터 영상을찍어야해"): 쓴 쿠폰을 모두 잊고 쿠폰으로만 받는 펫 · 탈것(free)을 뺀다
--  (꺼내 둔 펫이면 넣고 · 고른 탈것이면 고르지 않은 것으로 — 타고 있었으면 내린다: 탄 동안인지는 서버의 s.riding이 bm.mount를 본다).
--  쿠폰을 처음 넣기 전의 계정으로 — 돌려주는 것: 지운 쿠폰의 수 · 뺀 펫 · 탈것의 수
function CashServer.resetCoupons(acct): (number, number)
	local c = acct.bm
	local codes, pets = 0, 0
	for code in c.coupons do
		c.coupons[code] = nil
		codes += 1
	end
	for id in c.pets do
		local def = Cash.PET[id]
		if def and def.free then
			c.pets[id] = nil
			pets += 1
			Cash.petRemove(c, id) -- (꺼내 둔 펫들에서도 — 2026-10-30)
		end
	end
	for id in c.mounts do
		local def = Cash.MOUNT[id]
		if def and def.free then
			c.mounts[id] = nil
			pets += 1
			if c.mount == id then
				c.mount = false
			end
		end
	end
	return codes, pets
end

-- 구매 창을 띄운다(서버가 한도를 본 뒤에만). → true / false · 까닭
local open: (any, string, any) -> (boolean, string?)
function CashServer.prompt(s, key: any): (boolean, string?)
	local p = Cash.product(key)
	if not p then
		return false, "없는 상품이다"
	elseif not s.acct or not s.loaded or s.guest then
		return false, "계정을 읽지 못했다"
	elseif not Cash.ready(p) then
		return false, "판매 준비 중" -- 상품 번호가 없거나 게임에 아직 만들지 않은 것
	end
	local uid = s.player.UserId
	-- 선물로 띄운 구매 창이 떠 있으면 같은 상품은 띄우지 않는다(결제가 누구의 것인지 섞이지 않게) · 닫힌 지난 것이면 지운다(나에게 산다)
	local gift = s.acct.bm.gift
	if gift and gift.k == key then
		if CashServer.pending(uid, key) > 0 then
			return false, Cash.WORDS.giftBusy
		end
		s.acct.bm.gift = false
	end
	-- 확률형 상품(2026-11-07 — 뽑기 상자 · 윤슬 조각): 로블록스 정책에서 확률형 유료 아이템이 막힌 계정(ArePaidRandomItemsRestricted)은 구매 창을 띄우지 않는다(design/bm.js BM_RULES.random)
	local RND = Cash.RULES.random
	if p.random and RND and RND.policy and typeof(s.policy) == "table" and s.policy.ArePaidRandomItemsRestricted == true then
		return false, Cash.WORDS.randomBlocked or "로블록스 정책으로 이 계정은 확률형 상품을 살 수 없다"
	end
	local ok, why = Cash.canBuy(s.acct, key, W.now(), CashServer.pending(uid, key), Account.MAX)
	if not ok then
		return false, why
	end
	return open(s, key, p)
end

-- 구매 창을 띄운다(살 수 있는지는 부른 쪽이 보았다 — 나에게 사기 · 선물하기)
open = function(s, key: string, p): (boolean, string?)
	local uid = s.player.UserId
	-- 한정 판매: 한 개를 잡아 둔 뒤에 구매 창을 띄운다(다 팔렸거나 남은 것을 모두 남이 잡았으면 띄우지 않는다)
	if p.stock then
		local held, rec = Store.stockHold(key, uid, p.stock, CashServer.clock(), CashServer.HOLD)
		noteStock(key, rec)
		if held == nil then
			return false, "지금은 남은 수를 확인할 수 없다 — 잠시 뒤에 다시"
		elseif not held then
			if typeof(rec) == "table" and rec.sold >= p.stock then
				return false, Cash.WORDS.soldOut
			end
			return false, "남은 것을 다른 분이 결제하는 중이다 — 잠시 뒤에 다시"
		end
	end
	local done, err = pcall(function()
		if p.kind == "product" then
			addPending(uid, key, 1)
			MarketplaceService:PromptProductPurchase(s.player, p.rid)
		elseif p.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(s.player, p.rid)
		else
			MarketplaceService:PromptSubscriptionPurchase(s.player, p.rid)
		end
	end)
	if not done then
		addPending(uid, key, -1)
		warn("[Cash] 구매 창을 띄우지 못했다", key, err)
		if p.stock then
			local _, rec = Store.stockRelease(key, uid, CashServer.clock())
			noteStock(key, rec)
		end
		return false, "구매 창을 띄우지 못했다"
	end
	return true
end

-- ---------- 선물하기(2026-10-31 사용자: "달빛상점에 모든 품목을 아이템 선물을 할수있게 해줘 다른사람에게 선물을 보낼수있게") ----------
--  보내는 쪽: 상점 창의 「선물」 → 받는 사람의 닉네임 → CashServer.gift가 본다(선물할 수 있는 상품 · 로블록스 정책 · 나 아님 · 받는 계정의 한도 — 아직 받지 않은 선물까지 센다) →
--   띄운 선물을 계정에 적고(acct.bm.gift) 구매 창을 띄운다 → 결제가 오면(processReceipt) 받는 계정의 선물 상자(store.luau bmgift_)에 넣고 산 사람의 계정에는 결제 번호만 → 모든 서버에 알린다.
--  받는 쪽: 그 계정이 있는 서버가 들어온 뒤 한 번 · 소식이 오면 한 번(CashServer.giftTick) 상자를 읽어 계정에 넣고(Cash.grant — 결제 번호 "g" .. 번호) 저장한 뒤에 상자에서 지운다.
--  게임 패스(영구 패스 셋)는 로블록스가 남에게 사 주지 못하게 해 빠진다(Cash.giftable).
--  로블록스 정책(rules.gift.policy — 제가 정한 것): 유료 아이템을 거래할 수 없는 계정(IsPaidItemTradingAllowed = false)은 보내지도 받지도 못한다(경매장의 막기와 같은 대로)
local Format = require(lune.ui.format)
local GIFT = Cash.RULES.gift or { policy = true, max = 100 }
local GW = Cash.WORDS

-- 이 사람은 로블록스 정책으로 선물을 보낼 수 없는가
function CashServer.giftLocked(s): boolean
	return GIFT.policy == true and typeof(s.policy) == "table" and s.policy.IsPaidItemTradingAllowed == false
end

-- 그 계정이 있는 서버에 「선물 상자를 열어 보라」고 알린다(관리자의 선물과 같은 소식 — gifts.luau)
function CashServer.ping(uid: number)
	local t = W.sessionOf(uid)
	if t then
		t.bmGiftDone = nil -- (이 서버에 있다 — 다음 1초에)
	end
	task.spawn(function()
		require(script.Parent.gifts).ping(uid)
	end)
end

-- 받는 계정: 이 서버에 있으면 그 계정 · 아니면 저장된 것을 읽는다 → 계정(없으면 nil) · 읽지 못했는가
local function giftAccount(uid: number): (any, boolean)
	local t = W.sessionOf(uid)
	if t and t.acct and t.loaded and not t.guest then
		return t.acct, false
	end
	local data, failed = Store.loadAccount(uid)
	if failed then
		return nil, true
	end
	local ok, acct = pcall(Account.unpack, data)
	return if ok then acct else nil, false
end

-- 선물의 구매 창을 띄운다 → 띄웠는가 · 까닭 · 받는 사람의 닉네임
function CashServer.gift(s, key: any, to: any): (boolean, string?, string?)
	local p = Cash.product(key)
	if not p or not Cash.giftable(key) then
		return false, GW.giftCant
	elseif not s.acct or not s.loaded or s.guest then
		return false, "계정을 읽지 못했다"
	elseif CashServer.giftLocked(s) then
		return false, GW.giftPolicy
	end
	local name = if typeof(to) == "string" then string.gsub(string.gsub(to, "^[ \t]+", ""), "[ \t]+$", "") else ""
	if name == "" or #name > 60 then
		return false, GW.giftNeedName
	end
	local uid = Store.nameOwner(Account.nameKey(name))
	if uid == false then
		return false, GW.giftRead
	elseif typeof(uid) ~= "number" then
		return false, Format.fill(GW.giftNoName, { name = name })
	end
	local buyer = s.player.UserId
	if uid == buyer then
		return false, GW.giftSelf
	end
	local busy = s.acct.bm.gift
	if CashServer.pending(buyer, key) > 0 or (busy and CashServer.pending(buyer, busy.k) > 0) then
		return false, GW.giftBusy
	end
	local acct, failed = giftAccount(uid)
	if failed then
		return false, GW.giftRead
	elseif not acct then
		return false, Format.fill(GW.giftNoName, { name = name })
	elseif GIFT.policy == true and acct.bm.lock == true then
		return false, GW.giftPolicyTo
	end
	local okList, list = Store.bmGiftList(uid)
	if not okList then
		return false, GW.giftRead
	elseif #list >= (GIFT.max or 100) then
		return false, GW.giftBox
	end
	local wait = 0
	for _, g in list do
		if g.k == key then
			wait += 1 -- (아직 받지 않은 같은 선물도 한도에 센다)
		end
	end
	local ok, why = Cash.canBuy(acct, key, W.now(), wait, Account.MAX)
	if not ok then
		return false, Format.fill(GW.giftTo, { why = why or "" })
	end
	s.acct.bm.gift = { k = key, uid = uid, to = name, at = W.now() }
	s.dirty = true
	local done, err = open(s, key, p)
	if not done then
		s.acct.bm.gift = false
		return false, err
	end
	return true, nil, name
end

-- 받은 선물을 계정에 넣는다(그 계정이 있는 서버 — giftTick이 부른다)
local function claimGifts(s)
	local uid = s.player.UserId
	local ok, list = Store.bmGiftList(uid)
	if not ok then
		s.bmGiftNext = os.clock() + 30
		return
	end
	if #list == 0 or W.sessionOf(uid) ~= s then
		s.bmGiftDone = #list == 0 or nil
		return
	end
	local acct = s.acct
	local before, done, got = Cash.pack(acct.bm), {}, {}
	for _, g in list do
		local put, why = Cash.grant(acct, g.k, "g" .. g.rid, W.now(), Account.MAX, s.hero and s.hero.level)
		if put then
			done[g.rid] = true
			table.insert(got, g)
		elseif why == "dup" then
			done[g.rid] = true -- (넣고 저장까지 했는데 상자에서 지우지 못했던 것)
		else
			warn("[Cash] 선물을 넣지 못했다", g.k, why)
		end
	end
	if #got > 0 and not W.saveNow(s) then
		acct.bm = Cash.unpack(before, Account.MAX)
		s.bmGiftNext = os.clock() + 30
		return
	end
	if next(done) then
		Store.bmGiftRemove(uid, done)
	end
	s.bmGiftDone = true
	for _, g in got do
		W.giftGot(s, g.k, g.from)
	end
end

-- 뽑기 겹침의 자동 보상(2026-11-10 사용자: "그사람이 가지고있는 캐시템이랑 산 상자를 비교하면 얼마나 사라졌는지 알수있는거아니야? 정확히 파악해야 내가 보상을하지 이거 엄청 큰문제야"):
--  세계에 들어온 뒤 한 번(world.luau의 1초 셈) — modules/dupfixBuys.luau(로블록스 판매 기록의 산 수)와 이 계정의 가진 것으로 sim/cash.luau Cash.dupfixAuto →
--  넣은 것이 있으면 바로 저장(못 하면 되돌리고 30초 뒤 다시) · 상자마다 화면 위 알림 「겹침 보상」(CashGot "dupfix:<상자>:<수>" — 선물로 받은 겹침 보상과 같은 알림)
function CashServer.dupfixAuto(s)
	if not s or s.fixDone or not s.acct or not s.loaded or s.guest or os.clock() < (s.fixNext or 0) then
		return
	end
	local DATA = require(script.Parent.dupfixBuys)
	local buy = DATA.buys[s.player.UserId]
	if not buy then
		s.fixDone = true
		return
	end
	local before = Cash.pack(s.acct.bm)
	local added = {}
	for _, r in Cash.dupfixAuto(s.acct.bm, buy, DATA.upTo, W.now()) do
		if r.add > 0 then
			table.insert(added, r)
		end
	end
	if #added > 0 and not W.saveNow(s) then
		s.acct.bm = Cash.unpack(before, Account.MAX)
		s.fixNext = os.clock() + 30
		return
	end
	s.fixDone = true
	for _, r in added do
		-- 원래 상품으로 준 것 = "fixitem:<아이템>:<수>"(그 아이템 · 이제 가진 수를 알린다) · 선택상자 = "dupfix:<상자>:<수>"
		W.giftGot(s, if r.sure then Cash.fixItemKey(r.sure, r.add) else Cash.dupfixKey(r.box, math.min(r.add, Cash.DUPFIX_MAX)), "운영자")
	end
end

-- 상자 판매 바로잡기(2026-11-10 사용자: "다시 다뺏고 안연상자를 산것보다 카테고리별로 +3인거야 그리고 상자별로 선택상자를 주는걸로"):
--  계정을 읽은 직후 한 번(world.luau — 결제를 받기 전) · modules/dupfixBuys.luau에 있는 사람만 · sim/cash.luau Cash.boxReset → 바로 저장(못 하면 되돌리고 다음 접속 때 다시).
--  했으면 true(세계에 들어오면 알림 — s.resetNote)
function CashServer.boxReset(s): boolean
	if not s or not s.acct or not s.loaded or s.guest then
		return false
	end
	local DATA = require(script.Parent.dupfixBuys)
	local buy = DATA.buys[s.player.UserId]
	if not buy then
		return false
	end
	local before = Cash.pack(s.acct.bm)
	local done = Cash.boxReset(s.acct.bm, buy, W.now(), DATA.reset or 1)
	if not done then
		return false
	end
	if not W.saveNow(s) then
		s.acct.bm = Cash.unpack(before, Account.MAX)
		return false
	end
	s.resetNote = true
	return true
end

-- 사람마다 1초에 한 번(world.luau): 이 계정의 로블록스 정책을 계정에 적고(남이 선물할 때 본다) · 들어온 뒤 한 번 · 소식이 오면 한 번 선물 상자를 연다
function CashServer.giftTick(s)
	if not s or not s.acct or not s.loaded or s.guest then
		return
	end
	if typeof(s.policy) == "table" then
		local lock = s.policy.IsPaidItemTradingAllowed == false
		if s.acct.bm.lock ~= lock then
			s.acct.bm.lock = lock
			s.dirty = true
		end
	end
	if s.bmGiftDone or s.bmGiftBusy or os.clock() < (s.bmGiftNext or 0) then
		return
	end
	s.bmGiftBusy = true
	task.spawn(function()
		local ok, err = pcall(claimGifts, s)
		s.bmGiftBusy = false
		if not ok then
			warn("[Cash] 선물 상자: " .. tostring(err))
			s.bmGiftNext = os.clock() + 30
		end
	end)
end

-- 상품의 실제 값(로블록스 — 대시보드에서 바꾼 값 · 가격 실험이 있으면 그 값). 못 읽은 상품은 화면이 설계의 값을 쓴다
--  로블록스 문서: MarketplaceService:GetProductInfoAsync(번호, Enum.InfoType.Product).PriceInRobux(GetProductInfo는 낡은 이름)
--  2026-10-21 사용자 "달빛상점 로딩 너무길다": 전에는 상점에 들어갈 때(prices()) 상품 열일곱을 하나씩 차례로 물어 그 답을 다 받을 때까지 상점이 열리지 않았다
--   (10분마다 한 번 · 하나도 못 읽으면 들어갈 때마다) → 이제는 서버가 켜질 때 뒤에서 한꺼번에(상품마다 따로) 묻고 10분마다 뒤에서 새로 받는다. prices()는 기다리지 않고 받아 둔 것을 준다
local PRICE_KEEP, PRICE_RETRY = 600, 30 -- 새로 받는 사이(초) · 하나도 못 읽었을 때 다시 묻는 사이(초)
local priceOf = {}
local priceBusy = false
local function fetchPrices()
	if priceBusy then
		return 0
	end
	priceBusy = true
	local left, got = 0, 0
	for _, p in Cash.PRODUCTS do
		if typeof(p.rid) == "number" and p.rid > 0 then
			left += 1
			task.spawn(function()
				local ok, info = pcall(function()
					-- 게임 패스는 InfoType.GamePass로 읽는다(로블록스 문서 「game passes」 — 2026-10-22: 전에는 모두 Product로 읽어 패스의 값을 못 읽었다)
					return MarketplaceService:GetProductInfoAsync(p.rid, if p.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
				end)
				if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
					priceOf[p.id] = info.PriceInRobux
					got += 1
				end
				left -= 1
			end)
		end
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 20 do
		task.wait(0.1)
	end
	priceBusy = false
	return got
end
CashServer.fetchPrices = fetchPrices
function CashServer.prices(): { [string]: number }
	return priceOf
end
-- 뒤에서 값을 받아 두기 시작한다(CashServer.start가 부른다 — 서버가 켜질 때)
local function keepPrices()
	task.spawn(function()
		while true do
			local got = fetchPrices()
			task.wait(if got > 0 then PRICE_KEEP else PRICE_RETRY)
		end
	end)
end

-- 게임 패스를 가졌는가(들어올 때 · 산 순간 — 로블록스가 산 기록을 주지 않으니 물어서 기억한다)
--  「가졌다」는 그 접속 내내 기억한다. 「안 가졌다」는 RECHECK초가 지나면 다시 묻는다(2026-10-24 사용자: "게임 밖에서 로블록스 측에서 패스결제하면 게임에서 패스 구매한걸로 적용이 안된다" —
--  전에는 들어올 때 한 번 물은 「안 가졌다」를 접속이 끝날 때까지 기억해, 게임 안에 있는 동안 로블록스 웹의 게임 페이지에서 산 패스는 다시 들어오기 전까지 적용되지 않았다.
--  로블록스의 그 함수도 「안 가졌다」는 잠깐만 기억한다고 한다 — DevForum의 보고, 공식 문서에는 적혀 있지 않다)
CashServer.RECHECK = 30
function CashServer.owns(s, key: string): boolean
	local p = Cash.product(key)
	if not p or p.kind ~= "pass" or not (typeof(p.rid) == "number" and p.rid > 0) then
		return false
	end
	s.passes = s.passes or {}
	s.passAsked = s.passAsked or {}
	if s.passes[key] == true then
		return true
	end
	local now = os.clock()
	if s.passes[key] == false and now - (s.passAsked[key] or -math.huge) < CashServer.RECHECK then
		return false
	end
	s.passAsked[key] = now
	local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, s.player.UserId, p.rid)
	if not ok then
		return s.passes[key] == true -- 물어보지 못했다 — 다음에 다시
	end
	s.passes[key] = has == true
	return s.passes[key]
end

-- 가지지 않았던 패스를 다시 물어, 새로 가진 것이 있으면 효과를 얹고 알린다(「구매가 적용되었다」 · 버프 줄의 「영구」). 새로 가진 패스의 목록
function CashServer.recheck(s): { string }
	if not s or not s.hero or s.guest then
		return {}
	end
	local before = table.clone(s.passes or {})
	CashServer.applyPasses(s)
	local got = {}
	for k, v in s.passes or {} do
		if v == true and before[k] ~= true then
			table.insert(got, k)
			if W then
				W.notify(s, k)
			end
		end
	end
	return got
end

-- 영구 게임 패스의 효과를 그 사람의 캐릭터에 얹는다(2026-10-22 — 경험치 1.25배 · 드롭률 1.25배 패스: 들어설 때 · 산 순간). 바뀌었으면 true
--  가졌는지는 로블록스에 묻는다(CashServer.owns — 처음 한 번만 · 그 뒤로는 기억한 것). 효과의 셈 = Cash.passEffect(공방 bm.js의 effect)
function CashServer.applyPasses(s): boolean
	local h = s and s.hero
	if not h or s.guest then
		return false
	end
	local own = {}
	for _, p in Cash.PRODUCTS do
		if p.kind == "pass" and typeof(p.effect) == "table" and Cash.ready(p) and CashServer.owns(s, p.id) then
			own[p.id] = true
		end
	end
	local xp, drop = Cash.passEffect(own)
	local changed = (h.passXp or 0) ~= xp or (h.passDrop or 0) ~= drop
	h.passXp, h.passDrop, h.passOwn = xp, drop, own
	return changed
end

-- 이벤트를 잇는다 — 진짜 로블록스의 이벤트일 때만(검사 틀 — 가짜 로블록스 — 에는 결제 서비스가 없다: 조용히 넘어간다)
local function on(get, fn)
	local ok, sig = pcall(get)
	if ok and typeof(sig) == "RBXScriptSignal" then
		sig:Connect(fn)
	end
end

function CashServer.start(hooks)
	W = hooks
	keepPrices() -- 상품의 값을 뒤에서 받아 둔다(상점에 들어갈 때 기다리지 않게 — 2026-10-21)
	task.spawn(function() -- 한정 판매의 남은 수(2026-10-29)
		while true do
			pcall(CashServer.readStocks)
			task.wait(CashServer.STOCK_KEEP)
		end
	end)
	-- 게임 밖(로블록스 웹)에서 산 게임 패스(2026-10-24): RECHECK초마다 게임에 있는 사람의 가지지 않은 패스를 다시 묻는다
	task.spawn(function()
		while true do
			task.wait(CashServer.RECHECK)
			local ok, list = pcall(function()
				return Players:GetPlayers()
			end)
			for _, pl in (if ok and typeof(list) == "table" then list else {}) do
				local s = W.sessionOf(pl.UserId)
				if s then
					pcall(CashServer.recheck, s)
				end
			end
		end
	end)
	pcall(function()
		MarketplaceService.ProcessReceipt = CashServer.processReceipt
	end)
	-- 구매 창이 닫혔다(샀든 안 샀든) — 띄워 둔 수만 줄인다(산 것은 ProcessReceipt가 준다)
	on(function()
		return MarketplaceService.PromptProductPurchaseFinished
	end, function(userId, productId, isPurchased)
		local k = Cash.byRid(productId)
		if k and not isPurchased then
			addPending(userId, k, -1)
			local s = W.sessionOf(userId)
			if s and s.acct and s.acct.bm.gift and s.acct.bm.gift.k == k and CashServer.pending(userId, k) <= 0 then
				s.acct.bm.gift = false -- 선물의 구매 창을 사지 않고 닫았다(2026-10-31)
			end
			local p = Cash.product(k)
			if p and p.stock then
				task.spawn(function() -- 한정 판매: 잡아 둔 것을 놓는다(사지 않았다)
					local _, rec = Store.stockRelease(k, userId, CashServer.clock())
					noteStock(k, rec)
				end)
			end
		end
	end)
	on(function()
		return MarketplaceService.PromptGamePassPurchaseFinished
	end, function(player, passId, purchased)
		local s = W.sessionOf(player.UserId)
		local k = Cash.byRid(passId)
		if s and k and purchased then
			s.passes = s.passes or {}
			s.passes[k] = true
			CashServer.applyPasses(s) -- 영구 패스의 효과를 바로(2026-10-22)
			W.notify(s, k)
		end
	end)
	on(function()
		return Players.PlayerRemoving
	end, function(player)
		CashServer.forget(player.UserId)
	end)
end

return CashServer
