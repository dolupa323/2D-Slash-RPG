-- 달빛 상점 — 메뉴 → 「달빛 상점」(2026-10-20 · 사용자: "경험치 쿠폰 판매해도 됩니다. 꾸밈탈것 만들어도 됩니다. 만들어 봅시다").
--  모양은 공방 시험 탭의 js/lune/ui/paint.js(paintCash · ?lunedemo=cash)와 같다. 글 · 탭 · 상품의 차례는 공방 design/bm.js(BM_SHOP → data/bm.generated.luau의 shop).
--   안내 한 줄 · 탭 다섯(편의 · 재화 · 꾸밈 · 패스 · 보관함 — 받을 것이 있으면 「보관함」 옆에 금빛 수) · 줄의 스크롤 · 아래 「모두 받기」와 알림.
--   상품의 줄: [그림 칸] 이름 · 꼬리표(거래 가능 / 계정) / 한 줄 설명(재화 = 지금 사면 드는 양) / 횟수 · 오른쪽 = 값 · 「구매」(못 사면 「준비 중」 · 다 산 것은 꺼진 「구매」 · 가진 패스는 「보유」).
--  루나(2026-11-11 — 공방 bm.js LUNA): 상품은 루나로 산다 · 안내 줄 = 지금 루나 · 「루나 충전」 탭의 「충전」 → ctx.cashDo("charge", 묶음) → 로블록스의 구매 창(결제가 끝나면 서버가 루나를 더하고 CashGot).
--   「구매」는 늘 수 고르기 자리(묶음이 없으면 1개만 · 지금 루나)에서 한 번 더 누른다 → ctx.cashDo("buy", 상품) → 서버가 루나로 바로 판다(모자라면 그 자리의 단추가 「충전하기」).
--  (루나 전) 사는 것: 「구매」 → ctx.cashDo("buy", 상품) → 서버가 한도를 보고 로블록스의 구매 창을 띄운다(server/lune/modules/cash.luau) →
--   결제가 끝나면 서버(ProcessReceipt)가 보관함에 넣고 "CashGot"을 보낸다(boot가 알림을 띄우고 창을 고쳐 그린다). 결제를 이 창이 셈하지는 않는다.
--  보관함 → 가방: 「받기」 · 「모두 받기」 → ctx.cashDo("take", 줄?). 이름 바꾸기(arg "rename"): 가방에서 「이름 바꾸기 주문서」를 쓰면 이 창이 이름 칸으로 열린다 → ctx.cashDo("rename", 새 이름).
--  선물하기(2026-10-31): 안내 줄 오른쪽의 「선물하기」로 바꾸면 줄의 「구매」가 「선물」이 된다(영구 패스 = 「선물 불가」) → 누르면 목록 자리에 닉네임 칸 →
--   「보내기」 → ctx.cashDo("gift", { id, to }) → 서버가 받는 계정의 한도 · 로블록스 정책을 보고 구매 창을 띄운다(server/lune/modules/cash.luau CashServer.gift).
--  염색(arg "dye:point" · "dye:robe" — 2026-10-22): 가방에서 「무기 염색약」 · 「로브 염색약」을 쓰면 색을 고르는 모습으로 열린다 → ctx.cashDo("dye", { part, id }). 모양은 공방 paint.js의 paintDye(?lunedemo=cashdye)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lune = ReplicatedStorage.shared.lune
local BM = require(lune.data["bm.generated"])
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)
local Stage = require(script.Parent.Parent.stage)
local Sprite = require(script.Parent.Parent.sprite)
local Dye = require(lune.sim.dye)
local Gacha = require(lune.sim.gacha) -- 선택 상자의 고르는 모습(2026-11-10)
local DYE = Dye.data

local C = Ui.COLOR
local S = Layout.CASH
local SHOP = BM.shop
local W = SHOP.words
local NAME_MAX = 12 -- 이름 칸에 적을 수 있는 글자 수(캐릭터를 만들 때의 칸과 같다 — client/lune/title.luau)

local CashWindow = {}
local keepName: (TextBox, () -> ()) -> ()
CashWindow.PRODUCTS = BM.products
CashWindow.WORDS = W
CashWindow.TITLE = SHOP.title
local BY = {}
for _, p in BM.products do
	BY[p.id] = p
end
-- 상점에서 팔지 않는 펫 · 탈것(쿠폰으로 받는 「아기 재까마귀」 · 「떠도는 책」 — ride.generated의 pets[].free · mounts[].free · 2026-10-21): 이름 · 한 줄 설명 · 그림만 상품처럼
local RIDE_DATA = require(lune.data["ride.generated"])
for _, list in { RIDE_DATA.pets, RIDE_DATA.mounts } do
	for _, q in list do
		if (q.free or q.box) and not BY[q.id] then -- (box = 윤슬 상자의 펫 · 탈것 — 2026-11-07)
			BY[q.id] = { id = q.id, name = q.name, line = q.line or "", icon = "ride_" .. q.id, free = q.free, box = q.box }
		end
	end
end
-- 묶음(2026-11-06 「여러 개를 한 번에」 — 공방 bm.js BM_PACKS): 그 상품과 그것을 담은 묶음들 { { id, n } }(1개부터 수의 차례) · 묶음이 없는 상품은 nil
local PACKS = {}
for _, p in BM.products do
	if typeof(p.of) == "string" and BY[p.of] then
		PACKS[p.of] = PACKS[p.of] or { { id = p.of, n = 1 } }
		table.insert(PACKS[p.of], { id = p.id, n = p.n or 1 })
	end
end
for _, list in PACKS do
	table.sort(list, function(a, b)
		return a.n < b.n
	end)
end
function CashWindow.packs(id: string)
	return PACKS[id]
end
-- 그 상품(이름 · 한 줄 설명 · 그림 — 퀵슬롯의 설명 · 가방의 캐시 탭이 쓴다). 쿠폰 펫도 든다(위)
function CashWindow.product(id: string)
	return BY[id]
end
-- 줄을 만들어 둘 수: 가장 긴 탭(편의)과 보관함에 들 수 있는 아이템의 가짓수(주머니 · 상자의 레벨대 x 2 + 확장권 · 주문서 · 쿠폰 넷) 가운데 큰 것
local MOST = #BM.bands * 2 + 4
for _, ids in SHOP.rows do
	MOST = math.max(MOST, #ids)
end

-- 염색의 모습이면 고르는 곳(point · robe)
local function dyePart(arg: any): string?
	local part = if typeof(arg) == "string" and string.sub(arg, 1, 4) == "dye:" then string.sub(arg, 5) else nil
	return if part and Dye.ITEM[part] then part else nil
end
CashWindow.dyePart = dyePart
function CashWindow.dyeH(): number
	return S.dyeY + S.dyeBox + S.dyeBtnY + Ui.M.button
end

-- 선택 상자의 모습이면 그 상자(arg "pick:<상자>" — 2026-11-10 상자 판매 바로잡기)
local function pickOf(arg: any): string?
	local bid = if typeof(arg) == "string" and string.sub(arg, 1, 5) == "pick:" then string.sub(arg, 6) else nil
	return if bid and Gacha.box(bid) then bid else nil
end
CashWindow.pickOf = pickOf
-- 그 칸의 자리(창의 속 기준 — i는 1부터) · 창의 높이(칸의 줄 수 + 「받기」)
function CashWindow.pickCell(i: number): (number, number)
	local col, row = (i - 1) % S.selCols, (i - 1) // S.selCols
	return col * (S.selCellW + S.selGap), S.selY + row * (S.selCellH + S.selGap)
end
-- 칸은 PICK_ROWS줄까지 보이고 그보다 많으면 그 안에서 위아래로 민다(2026-11-13 — 데미지 스킨이 열셋이 되어 넷째 줄이 폰의 화면 틀 432를 넘었다 · 제가 정한 것)
local PICK_ROWS = 3
CashWindow.PICK_ROWS = PICK_ROWS
function CashWindow.pickRows(bid: string): number
	return math.ceil(#((Gacha.box(bid) or {}).pool or {}) / S.selCols)
end
function CashWindow.pickH(bid: string): number
	return S.selY + math.min(PICK_ROWS, CashWindow.pickRows(bid)) * (S.selCellH + S.selGap) + S.selBtnY + Ui.M.button
end

-- 상자 결과물을 선물하는 모습이면 그 물건(arg "giftItem:<물건>" — 2026-11-11)
local function giftItemOf(arg: any): string?
	local id = if typeof(arg) == "string" and string.sub(arg, 1, 9) == "giftItem:" then string.sub(arg, 10) else nil
	local g = id and Items.goods(id)
	return if g and g.kind == "bmCos" then id else nil
end
CashWindow.giftItemOf = giftItemOf

function CashWindow.size(arg: any): (number, number)
	if arg == "rename" or giftItemOf(arg) then
		return S.w, S.renameH
	elseif dyePart(arg) then
		return S.w, CashWindow.dyeH()
	elseif pickOf(arg) then
		return S.w, CashWindow.pickH(pickOf(arg) :: string)
	end
	return S.w, S.listY + S.rows * S.row + S.footY + Ui.M.button
end
-- 염색 창의 제목: 무기 색 · 로브 색(살라맨더의 무기 색은 「머리 색」 — 사용자 10-22 "살라맨더 머리색 바뀌는걸로하죠")
function CashWindow.dyeTitle(part: string, class: string?): string
	local hero = class and DYE.heroes[class]
	return if part == "robe" then DYE.words.title.robe elseif hero and hero.hair then DYE.words.title.hair else DYE.words.title.point
end
function CashWindow.title(arg: any): string
	local bid = pickOf(arg)
	if bid then
		return Format.fill(W.pickTitle or "{box}", { box = (BY[bid] and BY[bid].name) or bid })
	end
	local part = dyePart(arg)
	if part then
		local ctx = CashWindow.ctx
		return CashWindow.dyeTitle(part, ctx and ctx.myClass and ctx.myClass())
	end
	if giftItemOf(arg) then
		return W.giftItem
	end
	return if arg == "rename" then W.renameTitle else SHOP.title
end

-- 달빛 패스의 칸(공방 paint.js의 passCells와 같은 셈). pv = 서버의 Pass.view({ reached(연 칸), p(받은 칸) }) — 산 때부터 30일 · 시즌 · 무료 줄은 없다(사용자 10-20)
local PD = BM.pass
local PW = PD.words
function CashWindow.passCells(pv)
	local p = {}
	for _, k in (pv and pv.p) or {} do
		p[k] = true
	end
	local reached = (pv and pv.reached) or 0
	local out = {}
	for i, pd in PD.paid do
		local open = i <= reached
		table.insert(out, { step = i, paid = pd, open = open, gotP = p[i] == true, ready = open and not p[i] })
	end
	return out
end
function CashWindow.passCellW(w: number): number
	return math.floor((w - (S.passCols - 1) * S.passGap) / S.passCols)
end
function CashWindow.passCellText(c): string
	return Format.fill(PW.cell, { n = c.step, paid = ("%s %d"):format(PD.kinds[c.paid[1]].name, c.paid[2]) })
end

-- 보관함의 수(모든 줄의 수를 더한 것)
function CashWindow.boxCount(view): number
	local n = 0
	for _, e in (view and view.box) or {} do
		n += e.n
	end
	return n
end

-- 선물할 수 있는 상품인가(서버의 Cash.giftable과 같다 — 개발자 상품만 · 확률형은 뺀다 · 영구 게임 패스는 로벅스로 따로 산다: 로블록스가 남에게 사 주지 못하게 한다)
function CashWindow.giftable(id: string): boolean
	local p = BY[id]
	return p ~= nil and p.kind == "product" -- (뽑기 상자 · 윤슬 조각도 — 2026-11-11 · 뽑기 제한 계정은 rows가 「선물 불가」)
end
-- 그 상품의 루나 값(2026-11-11 — 서버의 Cash.view의 luna · 없으면 설계의 값)
function CashWindow.lunaOf(view, id: string): number
	for _, v in (view and view.list) or {} do
		if v.id == id and typeof(v.luna) == "number" then
			return v.luna
		end
	end
	local p = BY[id]
	return (p and (p.luna or p.robux)) or 0
end
-- 그 상품의 값의 글(「49 루나」)
function CashWindow.priceOf(view, id: string): string
	return Format.fill(W.price, { n = Format.comma(CashWindow.lunaOf(view, id)) })
end

-- 그 탭의 줄들(공방 paint.js의 cashRows와 같은 셈). view = 서버의 Cash.view
-- gift = 선물하기의 모습(줄의 단추가 「선물」 — 내가 산 수 · 가진 것은 보지 않는다: 받는 사람의 것은 서버가 본다)
function CashWindow.rows(view, tab: number, gift: boolean?)
	local key = SHOP.tabs[tab] and SHOP.tabs[tab][1]
	local out = {}
	if key == "luna" then
		-- 루나 충전(2026-11-11): 묶음마다 [그림] 「루나 n」 · 한 줄 · 값(로벅스 — 서버가 읽은 실제 값) · 「충전」(상품 번호가 없으면 「준비 중」 · 선물하기에서는 「선물 불가」)
		local byId = {}
		for _, q in (view and view.packs) or {} do
			byId[q.id] = q
		end
		for _, q in (BM.luna and BM.luna.packs) or {} do
			local v = byId[q.id] or {}
			table.insert(out, { id = q.id, charge = true, icon = q.icon or BM.luna.icon, name = Format.fill(W.packName, { n = Format.comma(q.n) }), text = Format.fill(W.packText, { n = Format.comma(q.n) }),
				price = Format.fill(W.packPrice, { n = Format.comma(v.robux or q.robux) }), state = if gift then "noGift" elseif v.ready then "charge" else "soon", tag = "", tagTone = "dim" })
		end
		return out
	elseif key == "box" then
		for i, e in (view and view.box) or {} do
			local g = Items.goods(e.id)
			local from = g and SHOP.boxOf[g.kind] and BY[SHOP.boxOf[g.kind]]
			local text = if from then from.line else ""
			if g and g.kind == "bmMoney" then
				text = Format.fill(W.boxMoney, { n = Format.comma(g.amount) })
			elseif g and g.kind == "bmDust" then
				text = Format.fill(W.boxDust, { n = Format.comma(g.amount) })
			end
			table.insert(out, { box = i, item = e.id, icon = if g and g.icon then g.icon else "bm_starter", name = if g then g.name else e.id, text = text, n = e.n })
		end
		return out
	end
	local list = {}
	for _, v in (view and view.list) or {} do
		list[v.id] = v
	end
	local band = (view and view.band) or 1
	for _, id in SHOP.rows[key] or {} do
		local p = BY[id]
		local v = list[id] or {}
		local lim = p.limit
		local bought = v.bought or 0
		local full = lim ~= false and lim ~= nil and bought >= lim.n
		local text = p.line
		if id == "money" or id == "dust" then
			local g = Items.goods(("bm_%s_%d"):format(id, band))
			if g then
				text = Format.fill(if id == "money" then W.nowMoney else W.nowDust, { n = Format.comma(g.amount), band = band })
			end
		end
		-- 가진 펫 · 탈것: 「보유」만(2026-10-21 사용자 "펫을 넣고 빼는거, 라이딩을 타는거 이런게 달빛상점에 들어가서 하는게 아닙니다. 달빛상점은 구매를 하는곳이에요" —
		--  꺼내기 · 넣기 · 타기 · 내리기는 가방의 캐시 탭 · 퀵슬롯 · N 키에서)
		local isPet, isMount = string.sub(id, 1, 4) == "pet_", string.sub(id, 1, 6) == "mount_"
		local on = if isPet then (view ~= nil and table.find(view.petsOut or { view.petOut }, id) ~= nil) elseif isMount then (view ~= nil and view.riding == true and view.mount == id) else false
		-- 한정 판매(2026-10-29 황금 골렘): 남은 수를 띄우고, 다 팔렸으면 「품절」(구매 단추가 꺼진다)
		local soldOut = p.stock and not v.own and typeof(v.left) == "number" and v.left <= 0
		local state = if v.own then "own" elseif not v.ready then "soon" elseif soldOut then "soldOut" elseif full then "full" else "buy"
		if gift then
			state = if not CashWindow.giftable(id) or (view ~= nil and view.giftLock == true) or (p.random and view ~= nil and view.randomLock == true) then "noGift" elseif not v.ready then "soon" elseif soldOut then "soldOut" else "gift"
		end
		-- 뽑기 상자(2026-11-07): 나올 것이 남지 않으면 「모두 보유」(구매 단추 대신) · random = 줄 셋째 칸의 「확률 보기」
		if v.boxLeft ~= nil and v.boxLeft <= 0 and not gift then
			state = "own"
		end
		table.insert(out, {
			id = id,
			icon = p.icon,
			name = p.name,
			random = p.random == true,
			boxAll = v.boxLeft ~= nil and v.boxLeft <= 0,
			tag = if p.trade then W.trade else W.account,
			tagTone = if p.trade then "accent" else "dim",
			text = text,
			-- 루나의 값(2026-11-11 — 서버의 Cash.view) · 영구 게임 패스는 로벅스(로블록스에서 읽은 실제 값 — 루나와 따로: 사용자 "패스는 아예 별도입니다 패스는 로벅스로 구매하게하면됩니다")
			price = if p.kind == "pass" then Format.fill(W.packPrice, { n = Format.comma(v.robux or p.robux) }) else Format.fill(W.price, { n = Format.comma(v.luna or p.luna or p.robux) }),
			state = state,
			on = on == true,
			count = if p.stock and (gift or not v.own) then Format.fill(W.stockLeft, { n = if typeof(v.left) == "number" then v.left else p.stock, max = p.stock })
				elseif lim and not gift and not ((isPet or isMount) and v.own) then Format.fill(if lim.per == "week" then W.week else W.once, { n = bought, max = lim.n })
				else nil,
			full = (full and not gift) or soldOut == true,
		})
	end
	return out
end

-- 이름 칸: 띄어쓰기는 적히지 않고 너무 길게도 적히지 않는다(캐릭터를 만들 때의 칸과 같다 — 자세한 규칙은 서버가 알려 준다). 글이 바뀌면 changed()
keepName = function(field: TextBox, changed: () -> ())
	local ok, sig = pcall(function()
		return field:GetPropertyChangedSignal("Text")
	end)
	if not (ok and typeof(sig) == "RBXScriptSignal") then
		return
	end
	sig:Connect(function()
		local bare = string.gsub(field.Text, "[ \t\r\n]", "") -- (%s 대신 — 한글의 가운데 바이트를 지우지 않게 · 2026-10-21)
		if bare ~= field.Text then
			field.Text = bare
			return
		end
		local n = utf8.len(field.Text)
		if n and n > NAME_MAX then
			field.Text = string.sub(field.Text, 1, (utf8.offset(field.Text, NAME_MAX + 1) :: number) - 1)
			return
		end
		changed()
	end)
end

-- 이름 바꾸기의 모습: 안내 · 가진 주문서 · [이름 칸] 「변경」 · 알림
local function buildRename(body: Frame, ctx, w: number)
	local view = {}
	local note, tone = nil, nil
	local busy = false
	Ui.text(body, W.renameText, 0, 2, w, { color = C.dim })
	local have = Ui.text(body, "", 0, 18, w, {})
	local fw = w - S.btnW - 8
	local field = Ui.field(body, 0, S.renameY, fw, Ui.M.button, W.renamePh)
	local go
	go = Ui.button(body, W.renameGo, w - S.btnW, S.renameY, S.btnW, function()
		local name = field.Text
		if busy or name == "" then
			return
		end
		busy = true
		local res = ctx.cashDo("rename", name)
		busy = false
		if res and res.ok then
			note, tone = Format.fill(W.renameDone, { name = res.name or name }), C.green
			field.Text = ""
		else
			note, tone = (res and res.why) or W.renamePh, C.red
		end
		view.refresh()
	end, { main = true })
	go.frame.Name = "RenameGo"
	local noteText = Ui.text(body, "", 0, S.renameY + Ui.M.button + 8, w, { color = C.dim })
	keepName(field, function()
		view.refresh()
	end)
	function view.refresh()
		local n = Bag.countIn(ctx.bag(), "bm_rename")
		have:set(Format.fill(W.renameHave, { n = n }))
		have:color(if n > 0 then C.gold else C.red)
		go:setEnabled(n > 0 and field.Text ~= "" and not busy)
		noteText:set(note or "")
		noteText:color(tone or C.dim)
	end
	view.refresh()
	return view
end

-- 꺼낸 상자 결과물의 선물(2026-11-11 사용자: "꺼내팔기 한다음에 경매장에 거래가능하게만들면된다 선물하기도 가능하게"): 그림 · 이름 · 안내 / [닉네임] 「보내기」 / 알림 · 가진 수
--  → ctx.cashDo("giftItem", { id, to }) — 서버가 가방에서 하나를 빼 받는 사람의 선물 상자에(받으면 보관함)
local function buildGiftItem(body: Frame, ctx, w: number, id: string)
	local view = {}
	local note, tone = nil, nil
	local busy = false
	local g = Items.goods(id)
	Ui.slot(body, 0, 0, S.iconS)
	local icon = Ui.pic(body, nil, 2, 2)
	Ui.setPic(icon, g and g.icon or nil)
	Ui.text(body, (g and g.name) or id, S.textX, 1, w - S.textX, { font = "body" })
	local have = Ui.text(body, "", S.textX, 17, w - S.textX, {})
	local fw = w - S.btnW - 8
	local field = Ui.field(body, 0, S.renameY, fw, Ui.M.button, W.giftPh)
	field.Name = "GiftItemTo"
	local go
	go = Ui.button(body, W.giftGo, w - S.btnW, S.renameY, S.btnW, function()
		local to = field.Text
		if busy or to == "" then
			return
		end
		busy = true
		local res = ctx.cashDo("giftItem", { id = id, to = to })
		busy = false
		if res and res.ok then
			note, tone = Format.fill(W.giftItemDone or "", { to = res.to or to }), C.green
			field.Text = ""
		else
			note, tone = (res and res.why) or W.giftNeedName, C.red
		end
		view.refresh()
	end, { main = true })
	go.frame.Name = "GiftItemGo"
	local noteText = Ui.text(body, "", 0, S.renameY + Ui.M.button + 8, w, { color = C.dim, lines = 2 })
	keepName(field, function()
		note, tone = nil, nil
		view.refresh()
	end)
	function view.refresh()
		local n = Bag.countIn(ctx.bag(), id)
		have:set(Format.fill(W.giftItemHave or "", { n = n }))
		have:color(if n > 0 then C.gold else C.red)
		go:setEnabled(n > 0 and field.Text ~= "" and not busy)
		noteText:set(note or W.giftItemText or "") -- (보내기 전에는 안내 — 받는 사람이 접속하면 보관함에)
		noteText:color(tone or C.dim)
	end
	view.refresh()
	return view
end

local function rgbOf(n: number): Color3
	return Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end
-- 색 칸의 색: 무기 = 두 색(본색 · 밝은 날 — 그 영웅의 무기를 그 색으로) · 로브 = 한 색
function CashWindow.dyeChip(part: string, class: string, id: string): { Color3 }
	local hero = DYE.heroes[class] or DYE.heroes.axion
	if part == "point" then
		local two = if id == Dye.BASE then hero.base else hero.chips[id]
		return { rgbOf(two[1]), rgbOf(two[2]) }
	end
	local q = Dye.find("robe", id)
	return { rgbOf(if q then q.rgb else DYE.bodyRgb) }
end
-- 그 칸의 자리(창의 속 기준) — i는 1부터(「원래」가 1)
function CashWindow.dyeCell(i: number): (number, number)
	local col, row = (i - 1) % S.dyeCols, (i - 1) // S.dyeCols
	return S.dyeGX + col * (S.dyeCellW + S.dyeGap), S.dyeY + row * (S.dyeCellH + S.dyeGap)
end

-- 염색의 모습: 안내 · 가진 염색약 · 왼쪽 미리보기(내 캐릭터가 고른 색으로 숨 쉰다) · 오른쪽 색 칸(「원래」 + 색) · 알림 · 「변경」
local DYE_BIND = "LuneDyePreview"
local function buildDye(body: Frame, ctx, w: number, part: string)
	local view = {}
	local DW = DYE.words
	local class = (ctx.myClass and ctx.myClass()) or "axion"
	local item = Dye.ITEM[part]
	local function myLook()
		return Dye.clean(ctx.myLook and ctx.myLook())
	end
	local pick = Dye.current(myLook(), part)
	local note, tone, busy = nil, nil, false
	Ui.text(body, DW.text, 0, 2, w, { color = C.dim })
	local have = Ui.text(body, "", 0, 18, w, {})
	-- 미리보기: 판 안은 게임 도트(한 도트 = 화면 틀 dyeDot점을 화면의 정수 화소로 반올림 — 공방 탭과 같은 크기)
	local box = S.dyeBox
	Ui.box(body, 0, S.dyeY, box, box, C.line)
	local pv = Ui.box(body, 1, S.dyeY + 1, box - 2, box - 2, C.ink)
	pv.ClipsDescendants = true
	local dotPx = math.max(1, math.floor(S.dyeDot * Stage.uiScale + 0.5))
	local ratio = dotPx / Stage.uiScale
	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundTransparency = 1
	world.BorderSizePixel = 0
	world.Size = UDim2.fromOffset((box - 2) / ratio, (box - 2) / ratio)
	world.Parent = pv
	local grow = Instance.new("UIScale")
	grow.Scale = ratio
	grow.Parent = world
	local hero = Sprite.new(world, class, 2)
	-- 서 있는 첫 장의 보이는 폭을 판 가운데에(발밑을 가운데에 두면 한쪽으로 긴 무기 — 액시온의 도끼 — 가 판 밖으로 잘린다)
	local f1 = hero.char.clips.idle.frames[1]
	local mid = if f1 then f1[6] + f1[4] / 2 - hero.char.ox else 0
	local cx, floor = math.floor((box - 2) / ratio / 2 - mid), math.floor((box - 2) * 0.8 / ratio)
	local function preview()
		local l = myLook()
		l[part] = if pick == Dye.BASE then nil else pick
		hero:setLook(l)
	end
	preview()
	local t0 = os.clock()
	pcall(RunService.UnbindFromRenderStep, RunService, DYE_BIND)
	RunService:BindToRenderStep(DYE_BIND, Enum.RenderPriority.Last.Value, function()
		hero:set("idle", Sprite.frameAt(hero.char, "idle", os.clock() - t0, false), cx, floor, 1)
	end)
	-- 색 칸
	local cells = {}
	local cw = S.dyeCellW - S.dyeChipPad * 2
	for i, id in Dye.choices(part) do
		local x, y = CashWindow.dyeCell(i)
		local frame = Ui.box(body, x, y, S.dyeCellW, S.dyeCellH, C.line)
		frame.Name = "Dye_" .. id
		Ui.box(frame, 1, 1, S.dyeCellW - 2, S.dyeCellH - 2, C.panel)
		local chips = CashWindow.dyeChip(part, class, id)
		local each = math.floor(cw / #chips)
		for k, c in chips do
			local cwk = if k == #chips then cw - each * (k - 1) else each
			Ui.box(frame, S.dyeChipPad + each * (k - 1), 4, cwk, S.dyeChipH, c)
		end
		local name = Ui.text(frame, Dye.name(part, id), 1, S.dyeNameY, S.dyeCellW - 2, { align = "center" })
		local hit = Ui.hit(frame)
		hit.Activated:Connect(function()
			if busy then
				return
			end
			pick = id
			note = nil
			preview()
			view.refresh()
		end)
		cells[i] = { id = id, frame = frame, name = name }
	end
	local btnY = S.dyeY + box + S.dyeBtnY
	local noteText = Ui.text(body, "", 0, btnY + math.floor((Ui.M.button - Ui.M.small) / 2), w - S.btnW - 8, { color = C.dim })
	local go
	go = Ui.button(body, DW.go, w - S.btnW, btnY, S.btnW, function()
		if busy then
			return
		end
		busy = true
		view.refresh()
		local res = ctx.cashDo("dye", { part = part, id = pick })
		busy = false
		if res and res.ok then
			note, tone = Format.fill(DW.done, { name = res.name or Dye.name(part, pick) }), C.green
		else
			note, tone = (res and res.why) or DW.none, C.red
		end
		view.refresh()
	end, { main = true })
	go.frame.Name = "DyeGo"
	function view.refresh()
		local n = Bag.countIn(ctx.bag(), item)
		have:set(Format.fill(DW.have, { n = n }))
		have:color(if n > 0 then C.gold else C.red)
		local now = Dye.current(myLook(), part)
		for _, c in cells do
			c.frame.BackgroundColor3 = if c.id == pick then C.accent else C.line
			c.name:color(if c.id == pick then C.accent elseif c.id == now then C.text else C.dim)
		end
		go:setEnabled(n > 0 and pick ~= now and not busy)
		noteText:set(note or (if pick == now and n > 0 then DW.pick else ""))
		noteText:color(tone or C.dim)
	end
	function view.destroy()
		pcall(RunService.UnbindFromRenderStep, RunService, DYE_BIND)
	end
	view.refresh()
	return view
end

-- 선택 상자의 모습(2026-11-10 상자 판매 바로잡기 — 가방 · 퀵슬롯에서 선택 상자를 쓰면): 안내 · 가진 선택 상자 · 그 상자의 것 칸(그림 · 이름 — 드문 것은 금빛 · 가진 수) ·
--  알림 · 「받기」 → ctx.cashDo("pick", 고른 것) — 서버가 선택 상자를 하나 쓰고 그것을 준다(가진 것이면 하나 더). 칸의 그림 = 가방 캐시 탭과 같은 것(ItemCell.icon)
local PICK_KIND = { pet = "pet", mount = "mount", dskin = "dskin", bubble = "bubble", ntag = "ntag" }
local function buildPick(body: Frame, ctx, w: number, bid: string)
	local ItemCell = require(script.Parent.itemCell)
	local CashSim = require(lune.sim.cash)
	local view = {}
	local b = Gacha.box(bid)
	local item = "bm_pick_" .. bid
	local pick, note, tone, busy = nil, nil, nil, false
	Ui.text(body, W.pickHint or "", 0, 2, w, { color = C.dim })
	local have = Ui.text(body, "", 0, 18, w, {})
	local cells = {}
	-- 줄이 많으면 칸들을 미는 판 안에(2026-11-13)
	local rows = CashWindow.pickRows(bid)
	local holder: Instance = body
	local dy = 0
	if rows > PICK_ROWS then
		local viewH = PICK_ROWS * (S.selCellH + S.selGap)
		holder = Ui.scroll(body, 0, S.selY, w, viewH, rows * (S.selCellH + S.selGap), S.scrollW)
		holder.Name = "PickList"
		dy = S.selY
	end
	for i, e in b.pool do
		local id = e[1]
		local x, y = CashWindow.pickCell(i)
		local frame = Ui.box(holder, x, y - dy, S.selCellW, S.selCellH, C.line)
		frame.Name = "Pick_" .. id
		Ui.box(frame, 1, 1, S.selCellW - 2, S.selCellH - 2, C.panel)
		Ui.worldIcon(frame, ItemCell.icon({ ride = id, kind = PICK_KIND[b.kind] or "mount" }), math.floor((S.selCellW - S.selIcon) / 2), 2, S.selIcon)
		local rare = table.find(b.rare or {}, id) ~= nil
		Ui.text(frame, CashSim.itemName(id), 2, S.selNameY, S.selCellW - 4, { align = "center", lines = 2, color = if rare then C.gold else C.text })
		local own = Ui.text(frame, "", 2, S.selOwnY, S.selCellW - 4, { align = "center", color = C.dim })
		local hit = Ui.hit(frame)
		hit.Activated:Connect(function()
			if busy then
				return
			end
			pick = id
			note = nil
			view.refresh()
		end)
		cells[i] = { id = id, frame = frame, own = own }
	end
	local btnY = CashWindow.pickH(bid) - Ui.M.button
	local noteText = Ui.text(body, "", 0, btnY + math.floor((Ui.M.button - Ui.M.small) / 2), w - S.btnW - 8, { color = C.dim })
	local go
	go = Ui.button(body, W.pickGo or "", w - S.btnW, btnY, S.btnW, function()
		if busy or not pick then
			return
		end
		busy = true
		view.refresh()
		local res = ctx.cashDo("pick", pick)
		busy = false
		if res and res.ok then
			note, tone = Format.fill(W.pickDone or "", { name = CashSim.itemName(pick) }), C.green
		else
			note, tone = (res and res.why) or "", C.red
		end
		view.refresh()
	end, { main = true })
	go.frame.Name = "PickGo"
	-- 가진 수(상점 상태 — 목록에 있으면 1 + 더 받은 수)
	local function owned(id: string): number
		local v = ctx.cash and ctx.cash()
		if not v then
			return 0
		end
		local list = (if b.kind == "pet" then v.pets elseif b.kind == "bubble" then v.bubbles elseif b.kind == "dskin" then v.dskins elseif b.kind == "ntag" then v.ntags else v.mounts) or {}
		if not table.find(list, id) then
			return 0
		end
		return 1 + ((typeof(v.extra) == "table" and v.extra[id]) or 0)
	end
	function view.refresh()
		local n = Bag.countIn(ctx.bag(), item)
		have:set(Format.fill(W.pickHave or "", { n = n }))
		have:color(if n > 0 then C.gold else C.red)
		for _, c in cells do
			c.frame.BackgroundColor3 = if c.id == pick then C.accent else C.line
			local k = owned(c.id)
			c.own:set(if k > 0 then Format.fill(W.pickOwn or "", { n = k }) else "")
		end
		go:setEnabled(n > 0 and pick ~= nil and not busy)
		noteText:set(note or (if pick == nil and n > 0 then W.pickNone or "" else ""))
		noteText:color(tone or C.dim)
	end
	function view.destroy() end
	view.refresh()
	return view
end

-- grid = 화면 가득의 달빛 상점(2026-11-10 — Layout.shopFull의 cols · cardW · cardH · gap): 상품을 줄 대신 카드로 줄지어(그림 크게 · 이름 · 한 줄 · 값 · 「구매」 · 위 오른쪽 「확률 보기」) ·
--  꾸밈 탭에는 작은 분류(SHOP.sub — 전체 · 뽑기 상자 · 탈것 · 캐시 무기) · 목록은 판의 아래 끝까지. 없으면 예전의 줄(창 · 시험)
function CashWindow.build(body: Frame, ctx, w: number, h: number, arg: any, grid: any?)
	CashWindow.ctx = ctx
	if arg == "rename" then
		return buildRename(body, ctx, w)
	end
	local giftItem = giftItemOf(arg)
	if giftItem then
		return buildGiftItem(body, ctx, w, giftItem)
	end
	local part = dyePart(arg)
	if part then
		return buildDye(body, ctx, w, part)
	end
	local pickBid = pickOf(arg)
	if pickBid then
		return buildPick(body, ctx, w, pickBid)
	end
	local view = {}
	local tab = 1
	local note, noteTone = nil, nil
	local waiting = false -- 답을 기다리는 중(두 번 눌러 구매 창이 둘 뜨지 않게)
	local giftMode, giftId = false, nil -- 선물하기(2026-10-31): 줄의 단추가 「선물」 · 닉네임 칸을 띄운 상품
	local giftNote, giftTone = nil, nil
	-- 수 고르기(2026-11-06): pick = { buy = 상품 }(1개 · 5개 · 10개 — 선물하기면 고른 묶음으로 닉네임 칸) · { box = 보관함의 줄, id, n, icon, name }(나눠 받기 — takeN개)
	local pick, takeN = nil, 1
	local textW = w - S.textX - S.sideW - 8
	local head = Ui.text(body, W.head, 0, 2, w - S.giftW - 8, { color = C.dim })
	local giftBtn = Ui.button(body, W.giftMode, w - S.giftW, 0, S.giftW, function()
		giftMode = not giftMode
		giftId, note, noteTone, pick = nil, nil, nil, nil
		view.refresh()
	end, { h = S.giftH })
	giftBtn.frame.Name = "GiftMode"
	local tabs = {}
	local tx = 0
	local list: ScrollingFrame
	local passBox: Frame
	for i, t in SHOP.tabs do
		local item = Ui.tab(body, t[2], tx, S.tabY, function()
			if tab ~= i then
				tab = i
				note, giftId, pick = nil, nil, nil
				list.CanvasPosition = Vector2.zero -- 다른 탭은 맨 위부터
				view.refresh()
			end
		end)
		item.frame.Name = "Tab_" .. t[1]
		tabs[i] = item
		tx += item.width + 14
	end
	-- 보관함에 받을 것이 있으면 「보관함」 옆에 금빛 수(보관함 탭은 맨 끝이라 다른 탭이 밀리지 않는다)
	local boxN = Ui.text(body, "", tx - 14 + 4, S.tabY, 40, { color = C.gold })
	Ui.line(body, 0, S.listY - 6, w)
	local FULL = SHOP.full
	-- 작은 분류(화면 가득일 때 · 꾸밈 탭 — 2026-11-10 메이플 캐시샵의 작은 분류 탭): 누르면 그 분류의 것만
	local chip = "all"
	local chipsUi = {}
	if grid and SHOP.sub then
		for key, list_ in SHOP.sub do
			local cx = 0
			for _, c in list_ do
				local cw = Ui.measure(c.name) + 18
				local b = Ui.button(body, c.name, cx, S.listY, cw, function()
					if chip ~= c.id then
						chip = c.id
						list.CanvasPosition = Vector2.zero
						view.refresh()
					end
				end, { h = FULL.chipH, font = "small" })
				b.frame.Name = "Chip_" .. c.id
				table.insert(chipsUi, { key = key, id = c.id, btn = b })
				cx += cw + FULL.chipGap
			end
		end
	end
	local function listTop(): number
		local key = SHOP.tabs[tab][1]
		return if grid and SHOP.sub and SHOP.sub[key] then S.listY + FULL.chipH + 8 else S.listY
	end
	local fy = if grid then h - Ui.M.button else S.listY + S.rows * S.row + S.footY -- 아래 줄(「모두 받기」 · 알림)

	-- 상품 · 보관함의 줄: 스크롤 틀(rows개가 보이고 나머지는 민다 — 마우스 휠 · 손가락). 막대는 판의 오른쪽 여백에
	list = if grid then Ui.scroll(body, 0, S.listY, w, fy - S.footY - S.listY, MOST * (grid.cardH + grid.gap), S.scrollW) else Ui.scroll(body, 0, S.listY, w + 10, S.rows * S.row, MOST * S.row, S.scrollW)
	list.Name = "List"
	local empty = Ui.text(body, W.boxEmpty, 0, S.listY + 20, w, { align = "center", color = C.dim })
	local rowsUi = {}
	-- 줄 · 카드의 단추: 사기 · 받기 · 선물(묶음이 있으면 수 고르기 · 선물이면 닉네임 칸)
	local function onAct(r)
		if waiting or not r.act then
			return
		end
		if r.act.charge then
			-- 루나 충전(2026-11-11): 로블록스의 구매 창 → 결제가 끝나면 서버가 루나를 더하고 알린다(CashGot)
			waiting = true
			local res = ctx.cashDo("charge", r.act.charge)
			waiting = false
			if res and res.ok then
				note, noteTone = W.chargeAsked, C.dim
			else
				note, noteTone = (res and res.why) or W.soon, C.red
			end
			view.refresh()
			return
		end
		if r.act.gift then
			if CashWindow.packs(r.act.gift) then
				pick, note = { buy = r.act.gift }, nil -- 묶음이 있으면 몇 개를 선물할지 먼저(2026-11-06)
			else
				giftId, giftNote, giftTone = r.act.gift, nil, nil -- 닉네임 칸을 띄운다
			end
			view.refresh()
			return
		end
		-- 여러 개를 한 번에(2026-11-06): 묶음이 있는 상품의 「구매」 → 1개 · 5개 · 10개 / 보관함에 2개 이상인 줄의 「받기」 → 받을 수
		-- 영구 게임 패스(로벅스 — 루나와 따로): 로블록스의 게임 패스 구매 창을 바로(그 창이 확인이다)
		if r.act.id and BY[r.act.id] and BY[r.act.id].kind == "pass" then
			waiting = true
			local res = ctx.cashDo("buy", r.act.id)
			waiting = false
			if res and res.ok then
				note, noteTone = W.asked, C.dim
			else
				note, noteTone = (res and res.why) or W.soon, C.red
			end
			view.refresh()
			return
		end
		-- 2026-11-11 루나: 「구매」는 묶음이 없어도 이 자리(1개 · 값 · 지금 루나)에서 한 번 더 누른다 — 로블록스의 구매 창이 없으니 잘못 누른 한 번에 루나가 나가지 않게
		if r.act.id then
			pick, note = { buy = r.act.id }, nil
			view.refresh()
			return
		elseif r.act.box and (r.act.n or 1) > 1 then
			pick, note = { box = r.act.box, id = r.act.item, n = r.act.n, icon = r.act.icon, name = r.act.name }, nil
			takeN = r.act.n
			view.refresh()
			return
		end
		waiting = true
		local act = r.act
		local res = if act.box then ctx.cashDo("take", act.box) elseif act.pet ~= nil then ctx.cashDo("pet", act.pet) elseif act.ride ~= nil then ctx.cashDo("ride", act.ride) else ctx.cashDo("buy", act.id)
		waiting = false
		note, noteTone = nil, nil
		if res and res.why then
			note, noteTone = res.why, C.red
		elseif act.box and res and res.ok then
			note, noteTone = Format.fill(W.taken, { n = res.moved or act.n }), C.green
		elseif (act.pet ~= nil or act.ride ~= nil) and res and res.ok then
			note, noteTone = nil, nil -- 꺼냈다 · 탔다(화면의 펫 · 탈것이 바로 보인다)
		elseif res and res.ok then
			note, noteTone = W.asked, C.dim
		end
		view.refresh()
	end
	-- 확률 보기(2026-11-07 — 로블록스 규정: 확률형 상품은 사기 전에 모든 결과의 확률 %) → 확률 창(ui/oddsWindow.luau)
	local function onOdds(r)
		if r.oddsArg then
			require(script.Parent.windows).open("odds", r.oddsArg)
		end
	end
	-- 펫 · 탈것 · 캐시 무기: 그림 · 이름 쪽을 누르면(PC는 올려 두기만 해도) 달빛 상점의 미리보기에 내 캐릭터와 같이(2026-10-21 — 메이플 캐시샵의 미리보기)
	local function previewHit(r, holder: Frame)
		local hit = Ui.hit(holder)
		local function show()
			if r.preview and ctx.cashPreview then
				ctx.cashPreview(r.preview)
			end
		end
		hit.Activated:Connect(show)
		hit.MouseEnter:Connect(function()
			show()
			if r.stroke then
				r.stroke.Color = C.accent -- (카드: 올린 것을 민트 테두리로)
			end
		end)
		hit.MouseLeave:Connect(function()
			if r.stroke then
				r.stroke.Color = C.line
			end
		end)
	end
	for i = 1, MOST do
		local r
		if grid then
			-- 카드(2026-11-10): 테두리 판 · 가운데 큰 그림(24점 그림의 두 배) · 이름 · 한 줄 · 횟수 · 값 · 아래 「구매」 · 위 왼쪽 꼬리표 · 위 오른쪽 「확률 보기」
			local CARD = FULL.card
			local cw, ch = grid.cardW, grid.cardH
			local f = Ui.group(list, ((i - 1) % grid.cols) * (cw + grid.gap), ((i - 1) // grid.cols) * (ch + grid.gap), cw, ch, "Card" .. i)
			r = { frame = f, card = true }
			local back = Ui.box(f, 0, 0, cw, ch, C.panel2)
			back.Name = "Back"
			local stroke = Instance.new("UIStroke")
			stroke.Color = C.line
			stroke.Thickness = 1
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = back
			r.stroke = stroke
			Ui.slot(f, math.floor((cw - CARD.slot) / 2), CARD.iconY, CARD.slot)
			r.icon = Ui.pic(f, nil, math.floor((cw - 48) / 2), CARD.iconY + math.floor((CARD.slot - 48) / 2))
			r.icon.Size = UDim2.fromOffset(48, 48)
			r.icon.ZIndex = 2
			r.name = Ui.text(f, "", 4, CARD.nameY, cw - 8, { font = "body", align = "center" })
			r.tag = Ui.text(f, "", 6, 5, cw - 12, {})
			r.text = Ui.text(f, "", 4, CARD.textY, cw - 8, { color = C.dim, align = "center", lines = CARD.textLines or 1, line = Ui.M.smallLine })
			r.count = Ui.text(f, "", 4, CARD.countY, cw - 8, { color = C.accent, align = "center" })
			r.price = Ui.text(f, "", 4, CARD.priceY, cw - 8, { align = "center", color = C.gold })
			r.own = Ui.text(f, W.own, 4, CARD.btnY + 6, cw - 8, { align = "center", color = C.green })
			previewHit(r, Ui.group(f, 0, 0, cw, CARD.btnY - 2, "Preview"))
			r.odds = Ui.button(f, W.odds or "", cw - CARD.oddsW - 5, 4, CARD.oddsW, function()
				onOdds(r)
			end, { h = 14, font = "small" })
			r.btn = Ui.button(f, W.buy, 8, CARD.btnY, cw - 16, function()
				onAct(r)
			end, { main = true, h = CARD.btnH })
		else
			local f = Ui.group(list, 0, (i - 1) * S.row, w, S.row, "Row" .. i)
			r = { frame = f }
			Ui.slot(f, 0, 2, S.iconS)
			r.icon = Ui.pic(f, nil, 2, 4)
			r.name = Ui.text(f, "", S.textX, 3, textW, { font = "body" })
			r.tag = Ui.text(f, "", S.textX, 5, 80, {})
			r.text = Ui.text(f, "", S.textX, 19, textW, { color = C.dim })
			r.count = Ui.text(f, "", S.textX, S.countY, textW, { color = C.accent })
			r.price = Ui.text(f, "", w - S.sideW, S.priceY, S.sideW, { align = "right", color = C.gold })
			r.own = Ui.text(f, W.own, w - S.sideW, S.btnY + 6, S.sideW, { align = "right", color = C.green })
			-- 확률 보기: 줄 셋째 칸의 작은 단추
			r.odds = Ui.button(f, W.odds or "", S.textX, S.countY - 2, 64, function()
				onOdds(r)
			end, { h = 14, font = "small" })
			r.btn = Ui.button(f, W.buy, w - S.btnW, S.btnY, S.btnW, function()
				onAct(r)
			end, { main = true, h = 22 })
			previewHit(r, Ui.group(f, 0, 0, w - S.btnW - 6, S.row, "Preview"))
		end
		r.odds.frame.Name = "Odds"
		r.odds.frame.Visible = false
		r.btn.frame.Name = "Act"
		rowsUi[i] = r
	end

	-- 달빛 패스(개발자 상품 · 산 때부터 30일 — 2026-10-20): 그림 · 이름 · 값 · 「구매」(있으면 「보유」) / 남은 날 · 달빛 · 띠 / 칸 30(10 x 3) / 고른 칸의 보상 · 「보상 받기」
	passBox = Ui.group(body, 0, S.listY + S.passY, w, S.rows * S.row, "Pass")
	local passSel = nil
	local passRow = { cells = {} }
	do
		local PROD = BY.pass
		Ui.slot(passBox, 0, 0, S.iconS)
		Ui.pic(passBox, PROD.icon, 2, 2)
		Ui.text(passBox, PROD.name, S.textX, 1, textW, { font = "body" })
		Ui.text(passBox, if PROD.trade then W.trade else W.account, S.textX + Ui.measure(PROD.name, "body") + 6, 3, 60, { color = C.dim })
		passRow.price = Ui.text(passBox, "", S.textX, 17, textW, { color = C.gold })
		passRow.own = Ui.text(passBox, W.own, w - S.sideW, 8, S.sideW, { align = "right", color = C.green })
		passRow.buy = Ui.button(passBox, W.buy, w - S.btnW, 3, S.btnW, function()
			if waiting then
				return
			end
			if giftMode then
				giftId, giftNote, giftTone = "pass", nil, nil
				view.refresh()
				return
			end
			waiting = true
			local res = ctx.cashDo("buy", "pass")
			waiting = false
			note, noteTone = nil, nil
			if res and res.why then
				note, noteTone = res.why, C.red
			elseif res and res.ok then
				note, noteTone = W.asked, C.dim
			end
			view.refresh()
		end, { main = true, h = 22 })
		passRow.buy.frame.Name = "PassBuy"
		passRow.season = Ui.text(passBox, "", 0, S.passInfoY, w, { color = C.dim })
		passRow.pts = Ui.text(passBox, "", 0, S.passInfoY, w, { align = "right" })
		local stepW = Ui.measure(Format.fill(PW.step, { n = PD.steps, max = PD.steps })) + 8
		passRow.bar = Ui.bar(passBox, 0, S.passBarY, w - stepW, 6, C.accent, C.panel2)
		passRow.step = Ui.text(passBox, "", 0, S.passBarY - 2, w, { align = "right" })
		local cw = CashWindow.passCellW(w)
		for i = 1, PD.steps do
			local cx = ((i - 1) % S.passCols) * (cw + S.passGap)
			local cy = S.passGridY + ((i - 1) // S.passCols) * (S.passCellH + S.passGap)
			local edge = Ui.box(passBox, cx, cy, cw, S.passCellH, C.line)
			edge.Name = "Step" .. i
			local fill = Ui.box(edge, 1, 1, cw - 2, S.passCellH - 2, C.panel2)
			fill.Name = "Fill"
			local cell = { edge = edge, fill = fill }
			cell.num = Ui.text(edge, tostring(i), 3, 2, cw - 4, {})
			cell.icon = Ui.smallIcon(edge, PD.kinds.potion.icon, math.floor((cw - 18) / 2), S.passCellH - 20)
			cell.tick = {}
			for k, d in { { 0, 2 }, { 1, 3 }, { 2, 4 }, { 3, 3 }, { 4, 2 }, { 5, 1 }, { 6, 0 } } do
				local t = Ui.box(edge, cw - 10 + d[1], S.passCellH - 9 + d[2], 1, 2, C.green)
				t.Name = "Tick" .. k
				table.insert(cell.tick, t)
			end
			Ui.hit(edge).Activated:Connect(function()
				passSel = if passSel == i then nil else i
				view.refresh()
			end)
			passRow.cells[i] = cell
		end
		local dy = S.passGridY + 3 * (S.passCellH + S.passGap) + 2
		passRow.detail = Ui.text(passBox, "", 0, dy + 6, w - S.btnW - 8, { color = C.dim })
		passRow.claim = Ui.button(passBox, PW.claim, w - S.btnW, dy, S.btnW, function()
			if waiting then
				return
			end
			waiting = true
			local res = ctx.cashDo("pass")
			waiting = false
			note, noteTone = nil, nil
			if res and res.ok then
				note, noteTone = Format.fill(PW.got, { n = res.got or 0 }), C.green
			elseif res and res.why then
				note, noteTone = res.why, C.red
			end
			view.refresh()
		end, { main = true, h = 22 })
		passRow.claim.frame.Name = "PassClaim"
	end

	Ui.line(body, 0, fy - 5, w)
	local all = Ui.button(body, W.takeAll, 0, fy, S.allW, function()
		if waiting then
			return
		end
		waiting = true
		local before = CashWindow.boxCount(ctx.cash())
		local res = ctx.cashDo("take")
		waiting = false
		note, noteTone = nil, nil
		if res and res.why then
			note, noteTone = res.why, C.red
		elseif res and res.ok then
			note, noteTone = Format.fill(W.taken, { n = before - CashWindow.boxCount(ctx.cash()) }), C.green
		end
		view.refresh()
	end, { main = true })
	all.frame.Name = "TakeAll"
	local noteText = Ui.text(body, "", S.allW + 10, fy + math.floor((Ui.M.button - Ui.M.small) / 2), w - S.allW - 10, { color = C.dim })

	-- 선물의 닉네임 칸(2026-10-31): 목록 자리에 — 고른 상품 · 값 · 안내 / [받는 사람의 닉네임] 「보내기」 / 알림(세 줄까지) · 아래 「돌아가기」(「모두 받기」 자리)
	local giftBox = Ui.group(body, 0, S.listY, w, S.rows * S.row, "Gift")
	Ui.slot(giftBox, 0, 2, S.iconS)
	local gIcon = Ui.pic(giftBox, nil, 2, 4)
	local gName = Ui.text(giftBox, "", S.textX, 3, textW, { font = "body" })
	local gPrice = Ui.text(giftBox, "", w - S.sideW, S.priceY, S.sideW, { align = "right", color = C.gold })
	Ui.text(giftBox, W.giftText, S.textX, 19, w - S.textX, { color = C.dim })
	local gField = Ui.field(giftBox, 0, S.giftFieldY, w - S.btnW - 8, Ui.M.button, W.giftPh)
	gField.Name = "GiftTo"
	local gGo
	gGo = Ui.button(giftBox, W.giftGo, w - S.btnW, S.giftFieldY, S.btnW, function()
		if waiting or not giftId then
			return
		end
		if gField.Text == "" then
			giftNote, giftTone = W.giftNeedName, C.red
			view.refresh()
			return
		end
		waiting = true
		local res = ctx.cashDo("gift", { id = giftId, to = gField.Text })
		waiting = false
		if res and res.ok then
			giftId = nil -- 목록으로 — 아래 알림 줄에 「보냈다 — 루나 n」(2026-11-11 루나)
			note, noteTone = Format.fill(W.giftAsked, { to = res.to or gField.Text, n = Format.comma(res.spent or 0) }), C.green
			gField.Text = ""
		else
			giftNote, giftTone = (res and res.why) or W.giftNeedName, C.red
		end
		view.refresh()
	end, { main = true })
	gGo.frame.Name = "GiftGo"
	local gNote = Ui.text(giftBox, "", 0, S.giftFieldY + Ui.M.button + 8, w, { color = C.dim, lines = 3 })
	keepName(gField, function()
		giftNote, giftTone = nil, nil
		view.refresh()
	end)
	-- 수 고르기(2026-11-06 사용자: "여러수량을 한번에 구매요청하고 로벅스도 그 개수에맞춰" · "수령을 나눠서 할수있어야해"): 목록 자리에 —
	--  고른 것의 줄(그림 · 이름 · 안내) / 사기 = 1개 · 5개 · 10개(값 · 「구매」 — 선물하기면 「선물」 → 닉네임 칸) / 받기 = [-] [수] [+] [모두] … 「받기」 · 「보관함에 n개」 · 아래 「돌아가기」
	local pickBox = Ui.group(body, 0, S.listY, w, S.rows * S.row, "Pick")
	Ui.slot(pickBox, 0, 2, S.iconS)
	local pIcon = Ui.pic(pickBox, nil, 2, 4)
	local pName = Ui.text(pickBox, "", S.textX, 3, textW, { font = "body" })
	local pSide = Ui.text(pickBox, "", w - S.sideW, S.priceY, S.sideW, { align = "right", color = C.gold })
	local pHead = Ui.text(pickBox, "", S.textX, 19, w - S.textX, { color = C.dim })
	local opts = {}
	for k = 1, 3 do
		local y = S.pickY + (k - 1) * S.pickRow
		local o = {}
		o.qty = Ui.text(pickBox, "", S.textX, y + 4, 80, { font = "body" })
		o.price = Ui.text(pickBox, "", 0, y + 6, w - S.btnW - 8, { align = "right", color = C.gold })
		o.btn = Ui.button(pickBox, W.buy, w - S.btnW, y, S.btnW, function()
			if o.toCharge and not waiting then
				-- 루나가 모자란다(2026-11-11): 「루나 충전」 탭으로
				for ti, tt in SHOP.tabs do
					if tt[1] == "luna" then
						tab = ti
					end
				end
				pick, note = nil, nil
				list.CanvasPosition = Vector2.zero
				view.refresh()
				return
			end
			if waiting or not o.id then
				return
			end
			if giftMode then
				giftId, giftNote, giftTone, pick = o.id, nil, nil, nil -- 고른 묶음의 닉네임 칸
				view.refresh()
				return
			end
			waiting = true
			local bought = o.id
			local res = ctx.cashDo("buy", o.id)
			waiting = false
			note, noteTone = nil, nil
			if res and res.why then
				note, noteTone = res.why, C.red
			elseif res and res.ok then
				local bp = BY[bought]
				note, noteTone, pick = Format.fill(W.bought, { name = (bp and bp.name) or bought, n = Format.comma(res.spent or 0), have = Format.comma(res.luna or 0) }), C.green, nil -- (루나로 샀다 — 2026-11-11)
			end
			view.refresh()
		end, { main = true, h = 22 })
		o.btn.frame.Name = "Pick" .. k
		opts[k] = o
	end
	local function setTake(n: number)
		takeN = math.clamp(math.floor(n), 1, math.max(1, (pick and pick.n) or 1))
		view.refresh()
	end
	local ty = S.pickY
	local minus = Ui.button(pickBox, "-", 0, ty, S.stepW, function()
		setTake(takeN - 1)
	end)
	minus.frame.Name = "TakeLess"
	local qField = Ui.field(pickBox, S.stepW + 4, ty, S.qtyW, Ui.M.button, "1")
	qField.Name = "TakeN"
	local plus = Ui.button(pickBox, "+", S.stepW + 8 + S.qtyW, ty, S.stepW, function()
		setTake(takeN + 1)
	end)
	plus.frame.Name = "TakeMore"
	local maxB = Ui.button(pickBox, W.takeMax, S.stepW * 2 + 12 + S.qtyW, ty, S.maxW, function()
		setTake((pick and pick.n) or 1)
	end)
	maxB.frame.Name = "TakeMax"
	local takeGo = Ui.button(pickBox, W.take, w - S.btnW, ty, S.btnW, function()
		if waiting or not (pick and pick.box) then
			return
		end
		waiting = true
		local want = takeN
		local res = ctx.cashDo("take", { i = pick.box, n = want })
		waiting = false
		note, noteTone = nil, nil
		if res and res.why then
			note, noteTone = res.why, C.red
		elseif res and res.ok then
			note, noteTone, pick = Format.fill(W.taken, { n = res.moved or want }), C.green, nil
		end
		view.refresh()
	end, { main = true })
	takeGo.frame.Name = "TakeGo"
	local pHave = Ui.text(pickBox, "", 0, ty + Ui.M.button + 8, w, { color = C.dim })
	-- 받을 수의 칸: 숫자만 · 1 ~ 보관함의 수(적는 동안 빈 칸이어도 된다 — 다 적으면 그 수)
	do
		local ok, sig = pcall(function()
			return qField:GetPropertyChangedSignal("Text")
		end)
		if ok and typeof(sig) == "RBXScriptSignal" then
			sig:Connect(function()
				local digits = string.gsub(qField.Text, "[^0-9]", "")
				if digits ~= qField.Text then
					qField.Text = digits
					return
				end
				local n = tonumber(digits)
				if n and pick and pick.n then
					local k = math.clamp(n, 1, pick.n)
					if k ~= takeN then
						takeN = k
						view.refresh()
					end
					if tostring(k) ~= digits then
						qField.Text = tostring(k)
					end
				end
			end)
		end
	end

	local back = Ui.button(body, W.giftCancel, 0, fy, S.allW, function()
		if pick then
			pick = nil
		else
			giftId = nil
		end
		view.refresh()
	end)
	back.frame.Name = "GiftBack"

	function view.refresh()
		local v = ctx.cash()
		local key = SHOP.tabs[tab][1]
		for i, t in tabs do
			t:setOn(i == tab)
		end
		local n = CashWindow.boxCount(v)
		boxN:set(if n > 0 then tostring(n) else "")
		local isPass = key == "pass"
		local lock = v ~= nil and v.giftLock == true -- 로블록스 정책으로 선물을 보낼 수 없는 계정
		local form = giftId ~= nil
		-- 수 고르기: 보관함의 줄이 바뀌었으면(다른 것이 받아졌다) 닫는다 · 받을 수는 그 줄의 수 안에서
		if pick and pick.box then
			local e = v and v.box and v.box[pick.box]
			if not e or e.id ~= pick.id then
				pick = nil
			else
				pick.n = e.n
				takeN = math.clamp(takeN, 1, math.max(1, e.n))
			end
		end
		local picking = pick ~= nil and not form
		-- (수 고르기의 단추 · 칸은 그 모습일 때만 — 아래에서 켠다)
		for _, o in opts do
			o.btn.frame.Visible = false
		end
		for _, b in { minus, plus, maxB, takeGo } do
			b.frame.Visible = false
		end
		head:set(if giftMode then W.giftHead else Format.fill(W.head, { n = Format.comma((v and v.luna) or 0) })) -- (지금 루나 — 2026-11-11)
		giftBtn:setText(if giftMode then W.giftBack else W.giftMode)
		giftBtn:setMain(giftMode)
		giftBox.Visible = form
		pickBox.Visible = picking
		passBox.Visible = isPass and not form and not picking
		list.Visible = not isPass and not form and not picking
		all.frame.Visible = not form and not picking
		back.frame.Visible = form or picking
		local rows = if isPass then {} else CashWindow.rows(v, tab, giftMode)
		-- 작은 분류(화면 가득 · 꾸밈 탭): 고른 분류의 것만 · 다른 탭으로 가면 「전체」
		local subs = if grid and SHOP.sub then SHOP.sub[key] else nil
		if not subs then
			chip = "all"
		end
		local chipIds = nil
		for _, c in subs or {} do
			if c.id == chip and c.ids then
				chipIds = {}
				for _, id in c.ids do
					chipIds[id] = true
				end
			end
		end
		if chipIds then
			local kept = {}
			for _, r in rows do
				if r.id and chipIds[r.id] then
					table.insert(kept, r)
				end
			end
			rows = kept
		end
		local showList = not isPass and not form and not picking
		for _, cu in chipsUi do
			cu.btn.frame.Visible = showList and cu.key == key
			cu.btn:setMain(cu.id == chip)
		end
		local top = listTop()
		if grid then
			list.Position = UDim2.fromOffset(0, top)
			list.Size = UDim2.fromOffset(w, fy - S.footY - top)
		end
		empty:move(0, top + 20)
		empty:show(not form and not picking and not isPass and #rows == 0)
		if picking then
			local buying = pick.buy ~= nil
			local p = if buying then BY[pick.buy] else nil
			Ui.setPic(pIcon, if p then p.icon else pick.icon)
			pName:set(if p then p.name else (pick.name or ""))
			pSide:set(if buying then "" else ("x%d"):format(pick.n or 0))
			local have = (v and v.luna) or 0
			pHead:set(if not buying then W.takeHead elseif giftMode then Format.fill(W.qtyGift, { have = Format.comma(have) }) else Format.fill(W.qtyHead, { have = Format.comma(have) }))
			local packs = if buying then (CashWindow.packs(pick.buy) or { { id = pick.buy, n = 1 } }) else {} -- (묶음이 없으면 1개만 — 2026-11-11)
			local seen = {}
			for _, e in (v and v.list) or {} do
				seen[e.id] = e
			end
			for k, o in opts do
				local pk = packs[k]
				o.id, o.toCharge = nil, nil
				o.qty:show(pk ~= nil)
				o.price:show(pk ~= nil)
				o.btn.frame.Visible = pk ~= nil
				if pk then
					local e = seen[pk.id] or {}
					local state = if giftMode then (if lock then "noGift" elseif not e.ready then "soon" else "gift") elseif not e.ready then "soon" else "buy"
					if state == "buy" and have < CashWindow.lunaOf(v, pk.id) then
						state = "short" -- 루나가 모자란다(2026-11-11) → 단추 「충전하기」
					end
					o.qty:set(Format.fill(W.qty, { n = pk.n }))
					o.price:set(CashWindow.priceOf(v, pk.id))
					o.price:color(if state == "soon" then C.dim else C.gold)
					o.btn:setText(if state == "soon" then W.soon elseif state == "gift" then W.gift elseif state == "noGift" then W.giftNo elseif state == "short" then W.toCharge else W.buy)
					o.btn:setEnabled(state == "buy" or state == "gift" or state == "short")
					o.id = if state == "buy" or state == "gift" then pk.id else nil
					o.toCharge = state == "short" or nil
				end
			end
			for _, b in { minus, plus, maxB, takeGo } do
				b.frame.Visible = not buying
			end
			local fieldFrame = qField.Parent
			if fieldFrame and fieldFrame:IsA("GuiObject") then
				fieldFrame.Visible = not buying
			end
			pHave:show(not buying)
			if not buying then
				minus:setEnabled(takeN > 1)
				plus:setEnabled(takeN < (pick.n or 1))
				maxB:setEnabled(takeN < (pick.n or 1))
				pHave:set(Format.fill(W.takeHave, { n = pick.n or 0 }))
				local focused = false
				pcall(function()
					focused = qField:IsFocused()
				end)
				if not focused and qField.Text ~= tostring(takeN) then
					qField.Text = tostring(takeN)
				end
			end
		end
		if form then
			local p = BY[giftId]
			Ui.setPic(gIcon, p and p.icon or nil)
			gName:set(p and p.name or giftId)
			gPrice:set(CashWindow.priceOf(v, giftId))
			gNote:set(giftNote or (if lock then W.giftPolicy else ""))
			gNote:color(giftTone or (if lock then C.red else C.dim))
			gGo:setEnabled(not lock)
		end
		for i, ru in rowsUi do
			local r = rows[i]
			ru.frame.Visible = r ~= nil
			ru.act = nil
			ru.odds.frame.Visible = false -- (확률 보기 — 확률형 상품의 줄만 아래에서 켠다)
			ru.preview = if r and typeof(r.id) == "string" and (string.sub(r.id, 1, 4) == "pet_" or string.sub(r.id, 1, 6) == "mount_" or string.sub(r.id, 1, 6) == "wskin_") then r.id else nil -- (캐시 무기 — 미리보기의 내 캐릭터가 그 무기를 든다 · 2026-11-10 사용자 "캐쉬무기들 미리보기가 되어야하고")
			if r then
				Ui.setPic(ru.icon, r.icon)
				ru.name:set(r.name)
				local nw = Ui.measure(r.name, "body")
				ru.tag:set(r.tag or "")
				ru.tag:color(C[r.tagTone or "dim"] or C.dim)
				if not ru.card then
					ru.tag:move(S.textX + nw + 6, 5) -- (카드는 위 왼쪽 귀퉁이 그대로)
				end
				ru.text:set(r.text)
				if r.box then
					ru.count:set("")
					ru.price:set(("x%d"):format(r.n))
					ru.price:color(C.gold)
					ru.own:show(false)
					ru.btn.frame.Visible = true
					ru.btn:setText(W.take)
					ru.btn:setEnabled(true)
					ru.btn:setMain(true)
					ru.act = { box = r.box, n = r.n, item = r.item, icon = r.icon, name = r.name }
				elseif r.charge then
					-- 루나 충전의 줄(2026-11-11): 값 = 로벅스 · 「충전」
					ru.count:set("")
					ru.price:set(r.price)
					ru.price:color(if r.state == "charge" then C.gold else C.dim)
					ru.own:show(false)
					ru.btn.frame.Visible = true
					ru.btn:setText(if r.state == "charge" then W.charge elseif r.state == "noGift" then W.giftNo else W.soon)
					ru.btn:setEnabled(r.state == "charge")
					ru.btn:setMain(true)
					ru.act = if r.state == "charge" then { charge = r.id } else nil
				elseif r.state == "pet" or r.state == "mount" then
					ru.count:set("")
					ru.price:set(W.own)
					ru.price:color(C.green)
					ru.own:show(false)
					ru.btn.frame.Visible = true
					ru.btn:setText(r.use)
					ru.btn:setEnabled(true)
					ru.btn:setMain(not r.on)
					if r.state == "pet" then
						ru.act = { pet = if r.on then false else r.id }
					else
						ru.act = { ride = if r.on then false else r.id }
					end
				else
					ru.btn:setMain(true)
					ru.odds.frame.Visible = r.random == true
					ru.oddsArg = if r.random then (if string.sub(r.id, 1, 7) == "yunseul" then "reroll:150" else "box:" .. r.id) else nil
					ru.own:set(if r.boxAll then (W.boxAll or W.own) else W.own)
					ru.count:set(if r.random then "" else (r.count or ""))
					ru.count:color(if r.full then C.red else C.accent)
					ru.price:set(r.price)
					ru.price:color(if r.state == "soon" or r.state == "soldOut" then C.dim else C.gold)
					ru.own:show(r.state == "own")
					ru.btn.frame.Visible = r.state ~= "own"
					ru.btn:setText(if r.state == "soon" then W.soon elseif r.state == "soldOut" then W.soldOut elseif r.state == "gift" then W.gift elseif r.state == "noGift" then W.giftNo else W.buy)
					ru.btn:setEnabled(r.state == "buy" or r.state == "gift")
					ru.act = if r.state == "buy" then { id = r.id } elseif r.state == "gift" then { gift = r.id } else nil
				end
			end
		end
		if grid then
			local lines = math.ceil(#rows / grid.cols)
			local contentH = math.max(0, lines * (grid.cardH + grid.gap) - grid.gap)
			local viewH = fy - S.footY - top
			list.CanvasSize = UDim2.fromOffset(0, math.max(viewH, contentH))
			list.ScrollingEnabled = contentH > viewH
			list.ScrollBarThickness = if contentH > viewH then S.scrollW else 0
		else
			list.CanvasSize = UDim2.fromOffset(0, math.max(S.rows, #rows) * S.row)
			list.ScrollingEnabled = #rows > S.rows
			list.ScrollBarThickness = if #rows > S.rows then S.scrollW else 0
		end
		if isPass then
			local pv = (v and v.pass) or {}
			local pr = CashWindow.rows(v, tab, giftMode)[1]
			passRow.price:set(pr.price)
			passRow.price:color(if pr.state == "soon" then C.dim else C.gold)
			passRow.own:show(pv.active == true and not giftMode)
			passRow.buy.frame.Visible = pv.active ~= true or giftMode -- (선물은 내 패스가 있어도 — 받는 사람의 것은 서버가 본다)
			passRow.buy:setText(if pr.state == "soon" then W.soon elseif pr.state == "gift" then W.gift elseif pr.state == "noGift" then W.giftNo else W.buy)
			passRow.buy:setEnabled(if giftMode then pr.state == "gift" else pr.state == "buy" and pv.active ~= true)
			passRow.season:set(if pv.active then Format.fill(PW.left, { left = pv.left or 0 }) elseif pv.ended then PW.ended else PW.off)
			passRow.season:color(if pv.active then C.accent else C.dim)
			passRow.pts:set(Format.fill(PW.pts, { n = pv.pts or 0, today = pv.today or 0, cap = PD.dayCap }))
			passRow.bar:set(if (pv.reached or 0) >= PD.steps then 1 else ((pv.pts or 0) % PD.per) / PD.per)
			passRow.step:set(Format.fill(PW.step, { n = pv.reached or 0, max = PD.steps }))
			local me = ctx.me and ctx.me()
			local potion = Items.potionFor(if me then me.level else 1)
			local cells = CashWindow.passCells(pv)
			for i, c in cells do
				local cu = passRow.cells[i]
				cu.edge.BackgroundColor3 = if c.ready then C.gold elseif passSel == c.step then C.accent elseif c.open then C.accentDark else C.line
				cu.fill.BackgroundColor3 = if c.open then C.panelHot else C.panel2
				cu.num:color(if c.open then C.text else C.off)
				Ui.setWorldIcon(cu.icon, if c.paid[1] == "potion" and potion then potion.icon else PD.kinds[c.paid[1]].icon)
				cu.icon.ImageTransparency = if c.gotP then 0.6 else 0 -- 받은 칸 = 흐리게
				for _, t in cu.tick do
					t.Visible = c.gotP
				end
			end
			local sel = passSel and cells[passSel]
			passRow.detail:set(if sel then CashWindow.passCellText(sel) else PD.lines[1])
			passRow.detail:color(if sel then C.text else C.dim)
			passRow.claim:setEnabled((pv.ready or 0) > 0)
		end
		all:setEnabled(n > 0)
		-- 뽑기 제한 계정의 선물하기(2026-11-11): 아래 줄에 까닭(빨강) — 「선물이 안 된다고 떠야지」
		local randomNote = giftMode and v ~= nil and v.randomLock == true and not note and not form
		noteText:set(if form then "" elseif randomNote then (W.giftRandomNote or W.giftRandomBox or "") else note or (if key == "box" and n > 0 then W.boxHint elseif key == "luna" then (W.lunaHint or "") else ""))
		noteText:color(if randomNote then C.red else noteTone or C.dim)
	end
	if ctx.cashFetch then
		ctx.cashFetch() -- 열 때 서버의 지금 것을 받아 온다(받으면 다시 그린다)
	end
	view.refresh()
	return view
end

return CashWindow
