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
	local before, spentBefore = Cash.pack(acct.bm), acct.spent
	local ok, why = Cash.grant(acct, k, tostring(info.PurchaseId), W.now(), Account.MAX, s.hero and s.hero.level)
	if not ok then
		if why == "dup" then
			return Decision.PurchaseGranted -- 이미 준 결제(로블록스가 다시 보냈다)
		end
		acct.bm = Cash.unpack(before, Account.MAX)
		warn("[Cash] 줄 수 없는 상품", k, why)
		return Decision.NotProcessedYet
	end
	acct.spent += math.max(0, math.floor(tonumber(info.CurrencySpent) or 0))
	if W.saveNow(s) then
		addPending(info.PlayerId, k, -1)
		task.spawn(W.afterSpent, s)
		W.notify(s, k)
		return Decision.PurchaseGranted
	end
	acct.bm = Cash.unpack(before, Account.MAX)
	acct.spent = spentBefore
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
			c.petOut = c.petOut or def.pet
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
			if c.petOut == id then
				c.petOut = false
			end
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
	local ok, why = Cash.canBuy(s.acct, key, W.now(), CashServer.pending(uid, key), Account.MAX)
	if not ok then
		return false, why
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
		return false, "구매 창을 띄우지 못했다"
	end
	return true
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
function CashServer.owns(s, key: string): boolean
	local p = Cash.product(key)
	if not p or p.kind ~= "pass" or not (typeof(p.rid) == "number" and p.rid > 0) then
		return false
	end
	s.passes = s.passes or {}
	if s.passes[key] == nil then
		local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, s.player.UserId, p.rid)
		if not ok then
			return false -- 물어보지 못했다 — 다음에 다시
		end
		s.passes[key] = has == true
	end
	return s.passes[key]
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
