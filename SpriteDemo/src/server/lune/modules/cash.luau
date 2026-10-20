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

-- 상품의 실제 값(로블록스 — 대시보드에서 바꾼 값 · 가격 실험이 있으면 그 값). 10분 동안 기억한다 · 못 읽으면 nil(화면은 설계의 값)
--  로블록스 문서: MarketplaceService:GetProductInfoAsync(번호, Enum.InfoType.Product).PriceInRobux(GetProductInfo는 낡은 이름)
local PRICE_KEEP = 600
local priceAt, priceOf = 0, {}
function CashServer.prices(): { [string]: number }
	local now = os.clock()
	if now - priceAt < PRICE_KEEP and next(priceOf) ~= nil then
		return priceOf
	end
	priceAt = now
	for _, p in Cash.PRODUCTS do
		if typeof(p.rid) == "number" and p.rid > 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(p.rid, Enum.InfoType.Product)
			end)
			if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
				priceOf[p.id] = info.PriceInRobux
			end
		end
	end
	return priceOf
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

-- 이벤트를 잇는다 — 진짜 로블록스의 이벤트일 때만(검사 틀 — 가짜 로블록스 — 에는 결제 서비스가 없다: 조용히 넘어간다)
local function on(get, fn)
	local ok, sig = pcall(get)
	if ok and typeof(sig) == "RBXScriptSignal" then
		sig:Connect(fn)
	end
end

function CashServer.start(hooks)
	W = hooks
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
