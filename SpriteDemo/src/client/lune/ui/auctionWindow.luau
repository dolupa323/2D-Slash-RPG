-- 경매장 창 — 메뉴의 「경매장」(Y)으로 어디서나 연다. 은달 항구의 경매사 「금송」에게 말을 걸어도 열린다(넓은 창 — 혼자 쓴다).
--  사용자 2026-10-06: "경매장으로 전부 거래가능하게 할겁니다" · 2026-10-13: "경매장 부터 진행합시다.  알아서 조사하고 판단하고 해서  경매장 구현 해보세요"
--  **사용자 2026-10-13(처음 만든 것을 보고): "메이플 식 경매장을 말하는거긴합니다."** — 메이플스토리의 메이플 옥션 방식이다. 탭 넷:
--   구매 = 분류(무기 — 직업마다 · 모자 · 옷 · 장갑 · 신발 · 소비 · 기타) · 이름으로 찾기 · 차례(가격 낮은 순 / 남은 시간 순). 줄의 「구매」를 누르면 아래에서 한 번 더 묻는다 — 묶음은 수를 골라 낱개로 산다.
--          산 것은 「완료」에 「낙찰」로 들어온다.
--   판매 = 판매 중인 것들(「취소」)과 「판매 등록」 → 등록 화면: 왼쪽에 가방의 올릴 수 있는 물건, 오른쪽에 양식(수량 · 가격(묶음은 개당 가격) · 기간 · 수수료 · 보증금 · 받는 금액 · 「등록」).
--   완료 = 낙찰 → 「수령」 · 판매 완료 → 「대금 수령」 · 미판매 → 「반환」 「재등록」 · 아래에 「모두 받기」.
--   시세 = 그 분류에서 최근에 거래된 것들(이름 · 언제 · 개당 값).
--  사고 올리고 받는 것은 모두 서버가 정한다(ctx.market → Market — server/lune/modules/world.luau의 onMarket). 적는 글과 셈은 shared/lune/ui/auctionView.luau(자동 검사가 같은 것을 본다),
--  낱말과 숫자는 공방 js/lune/design/economy.js의 AUCTION, 치수는 UILAYOUT.auction. 아이템과 달돈은 늘 그림과 함께 적는다(사용자 2026-10-13).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Market = require(lune.sim.market)
local Items = require(lune.sim.items) -- (로벅스로 산 아이템인가 — paid · 2026-10-30)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local View = require(lune.ui.auctionView)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local ItemDetail = require(script.Parent.itemDetail)

local C = Ui.COLOR
local S = Layout.AUCTION
local M = Market.DATA
local W = Market.WORDS

local AuctionWindow = { wide = true }

function AuctionWindow.size(): (number, number)
	return S.w, S.h
end

-- [그림 칸] 하나(목록의 줄 · 양식의 위): 칸과 그 안의 그림
local function iconCell(parent: Instance, x: number, y: number)
	local cell = Ui.slot(parent, x, y, S.icon)
	cell.frame.Name = "Icon"
	local icon = Ui.smallIcon(cell.frame, "coin", 3, 3)
	icon.Visible = false
	return cell, icon
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		child:Destroy()
	end
end

-- 적는 칸을 보이거나 감춘다(칸의 틀째로)
local function showField(box, on: boolean)
	local holder = box.Parent
	if holder then
		holder.Visible = on
	else
		box.Visible = on
	end
end

function AuctionWindow.build(body: Frame, ctx, w: number, h: number)
	local view = {}
	local dead = false
	local me0 = ctx.me()
	local tab = "buy"
	local cat, class = "weapon", if me0 then me0.class else "axion"
	local rows, trades = {}, {} -- 구매 탭의 목록 · 시세(서버가 준 것)
	local mine = {} -- 내 것(판매 · 완료 탭이 나눠 쓴다)
	local used, max = 0, M.slots
	local serverNow, gotAt = os.time(), os.clock() -- 서버의 시계(남은 시간은 이것으로 센다)
	local busy = false
	local note, noteTone = "", "dim"
	local paidLock = false -- 이 계정은 로벅스로 산 아이템을 거래할 수 없다(로블록스 정책 — 서버가 대답마다 알린다 · 2026-10-30)
	local query, sort = "", View.SORTS[1]
	local ask, askQty = nil, 1 :: number? -- 사려고 묻는 중인 줄 · 그 수(수량 칸이 비었으면 nil)
	local detail = nil -- 상세를 보는 줄(구매 목록에서 누른 것)
	local sellView = "list" -- 판매 탭: "list" 판매 중인 것들 · "form" 등록 화면
	local pick = nil :: { tab: string, slot: number }? -- 등록 화면에서 고른 가방의 칸
	local count, priceText, hours = 1, "", M.hours[1]
	local sellKey = "" -- 가방의 올릴 수 있는 것들이 달라졌는지 견주는 글

	local pageH = h - S.top - S.footH
	local function now(): number
		return serverNow + math.floor(os.clock() - gotAt)
	end
	local function board(): string
		return View.board(cat, class)
	end

	local paint -- 아래에서 정한다: 단추의 쓸 수 있음 · 지갑 · 알림 줄
	local fillBuy, fillLog, fillSelling, fillBag, fillDone, paintForm

	-- 서버에 부탁한다(한 번에 하나). after(res) = 답이 온 뒤에 할 일
	local function call(action: string, a: any, b: any, c: any, d: any, after: ((any) -> ())?)
		if busy then
			return
		end
		busy = true
		note, noteTone = W.wait, "dim"
		paint()
		task.spawn(function()
			local res = ctx.market(action, a, b, c, d)
			busy = false
			if dead then
				return
			end
			if res then
				if typeof(res.now) == "number" then
					serverNow, gotAt = res.now, os.clock()
				end
				if typeof(res.used) == "number" then
					used, max = res.used, res.max or max
					-- 로벅스로 산 아이템을 거래할 수 없는 계정인가(로블록스 정책 — 서버가 대답마다 알린다 · 2026-10-30): 바뀌면 판매 목록을 다시 그린다
					local was = paidLock
					paidLock = res.paidLock == true
					if was ~= paidLock and fillBag then
						fillBag(true)
					end
				end
				if res.rows and res.board == board() then
					rows, trades = res.rows, res.trades or trades
					fillBuy()
					fillLog()
				end
				if res.mine then
					mine = res.mine
					fillSelling()
					fillDone()
				end
				note, noteTone = res.msg or res.why or "", if res.ok then "accent" else "red"
			else
				note, noteTone = W.why.off, "red"
			end
			if after then
				after(res)
			end
			paint()
			-- 답을 기다리는 사이에 탭을 바꿨다(그때의 부탁은 busy라 버려졌다): 그 탭의 것을 이어서 받아 온다(2026-10-18 검토 — 판매 · 완료가 빈 목록으로 남았다)
			if (tab == "sell" or tab == "done") and action ~= "mine" and not (res and res.mine) then
				call("mine", false)
			elseif (tab == "buy" or tab == "log") and action == "mine" then
				call("browse", board(), false)
			end
		end)
	end

	-- ---------- 위: 탭 · 판매한 수 · 지갑 ----------
	local tabs = {}
	local pages = {}
	local header -- 구매 · 시세가 같이 쓰는 머리(분류 · 찾기)
	local function showPages()
		for key, page in pages do
			page.Visible = key == tab
		end
		header.Visible = tab == "buy" or tab == "log"
	end
	local function setTab(id: string)
		if tab == id then
			return
		end
		tab, ask = id, nil
		showPages()
		if not busy then
			note = ""
		end
		if id == "buy" or id == "log" then
			fillBuy()
			fillLog()
			call("browse", board(), false)
		else
			sellView = "list"
			call("mine", false)
		end
		paint()
	end
	local tx = 0
	for i, id in View.TABS do
		tabs[i] = Ui.tab(body, W.tabs[i], tx, 0, function()
			setTab(id)
		end)
		tx += tabs[i].width + 16
	end
	Ui.smallIcon(body, "coin", w - S.purseW, -3)
	local money = Ui.text(body, "", w - S.purseW + 21, 1, S.purseW - 21, { color = C.gold })
	local slots = Ui.text(body, "", w - S.purseW - 8 - S.slotsW, 1, S.slotsW, { align = "right", color = C.dim })
	Ui.line(body, 0, 20, w)

	-- ---------- 아래: 알림 한 줄 — 살 때는 묻는 글 · (묶음이면) 수를 고치는 단추 · 「구매 · 취소」 ----------
	local fy = h - S.footH
	Ui.line(body, 0, fy + 2, w)
	local noteText = Ui.text(body, "", 0, fy + 12, w, { color = C.dim })
	local askBox = Ui.group(body, 0, fy + 7, w, S.btnH, "Ask")
	local yesX = w - S.askW * 2 - 6
	local ofX = yesX - 8 - S.ofW -- 「/ 10개」
	local qtyX = ofX - 6 - S.qtyField -- 수량을 적는 칸
	local qtyLabelX = qtyX - 4 - S.qtyLabelW -- 「수량」
	local askGear = Ui.text(askBox, "", 0, 5, yesX - 8, { color = C.gold }) -- 장비: 수를 고르지 않는다(글이 넓다)
	local askStack = Ui.text(askBox, "", 0, 5, qtyLabelX - 8, { color = C.gold })
	local askLabel = Ui.text(askBox, W.count, qtyLabelX, 5, S.qtyLabelW, { color = C.dim })
	-- 수량은 적는다(사용자 2026-10-13: "경매장  수량도 입력하는걸로 처리하는방향으로 해주세요") — 올라온 수를 넘으면 그 수로
	local askBoxQty = Ui.field(askBox, qtyX, 0, S.qtyField, S.btnH, "1")
	local askOf = Ui.text(askBox, "", ofX, 5, S.ofW, { color = C.dim })
	askBoxQty:GetPropertyChangedSignal("Text"):Connect(function()
		if not ask then
			return
		end
		local text, n = View.count(askBoxQty.Text, ask.l or 1)
		if text ~= askBoxQty.Text then
			askBoxQty.Text = text
			return
		end
		askQty = n
		paint()
	end)
	local askYes = Ui.button(askBox, W.buy, yesX, 0, S.askW, function()
		local r, q = ask, askQty
		if r and q then
			ask = nil
			call("buy", board(), r.id, q, r.p)
		end
	end, { main = true, h = S.btnH })
	Ui.button(askBox, W.cancel, w - S.askW, 0, S.askW, function()
		ask = nil
		paint()
	end, { h = S.btnH })

	-- ---------- 구매 · 시세의 머리: 분류 · 직업 · 새로 고침 · 찾는 칸 · 차례 ----------
	header = Ui.group(body, 0, S.top, w, S.listTop - S.top, "Header")
	local catButtons = {}
	local cats = View.cats()
	local function reload(force: boolean?)
		ask, rows, trades = nil, if force then rows else {}, if force then trades else {}
		if not force then
			fillBuy()
			fillLog()
		end
		call("browse", board(), force == true)
	end
	for i, c in cats do
		catButtons[i] = Ui.button(header, c.name, (i - 1) * (S.catW + S.catGap), 0, S.catW, function()
			if cat ~= c.id then
				cat = c.id
				reload(false)
			end
		end, { h = S.catH })
	end
	local classButton
	classButton = Ui.button(header, View.className(class), #cats * (S.catW + S.catGap), 0, S.classW, function()
		class = View.nextClass(class)
		classButton:setText(View.className(class))
		reload(false)
	end, { h = S.catH })
	local refresh = Ui.button(header, W.refresh, w - S.refreshW, 0, S.refreshW, function()
		reload(true)
	end, { h = S.catH })
	local searchY = S.searchY - S.top
	local search = Ui.field(header, 0, searchY, S.searchW, S.field, W.search)
	local sortButton
	sortButton = Ui.button(header, View.sortName(sort), S.searchW + 8, searchY, S.sortW, function()
		sort, ask = View.nextSort(sort), nil
		sortButton:setText(View.sortName(sort))
		fillBuy()
		paint()
	end, { h = S.field })
	local total = Ui.text(header, "", S.searchW + 8 + S.sortW + 8, searchY + 6, w - S.searchW - S.sortW - 16, { align = "right", color = C.dim })

	local listY = S.listTop
	local listH = h - S.listTop - S.footH - 4
	local cw = w - S.bar - 2 -- 미는 막대를 뺀 줄의 폭
	-- 값의 자리: [달돈] 값(오른쪽 맞춤 — 묶음은 그 아래 「개당」)
	local function priceAt(parent: Instance, px: number, y: number, price: number, stack: boolean)
		Ui.smallIcon(parent, "coin", px - 19, y + 5)
		Ui.text(parent, Format.comma(price), px, if stack then y + 3 else y + 9, S.priceW, { align = "right", color = C.gold })
		if stack then
			Ui.text(parent, W.unit, px, y + 15, S.priceW, { align = "right", color = C.dim })
		end
	end

	-- ---------- 구매 ----------
	local pBuy = Ui.group(body, 0, listY, w, listH, "Buy")
	pages.buy = pBuy
	local buyRows = {}
	fillBuy = function()
		clear(pBuy)
		buyRows = {}
		local me, bag = ctx.me(), ctx.bag()
		local shown = View.sort(View.filter(rows, query), sort)
		if tab == "buy" then
			total:set(Format.fill(W.rows, { n = #shown }))
		end
		if #shown == 0 or not me then
			Ui.text(pBuy, W.empty, 0, 10, w, { align = "center", color = C.dim })
			return
		end
		local sc = Ui.scroll(pBuy, 0, 0, w, listH, #shown * S.row, S.bar)
		local bx = cw - S.btnW
		local px = bx - 8 - S.priceW
		local lx = px - 19 - 6 - S.leftW
		local sx = lx - 6 - S.sellerW
		local nx = S.icon + 6
		local nw = sx - 6 - nx
		local t = now()
		for i, r in shown do
			local y = (i - 1) * S.row
			local it = View.item(r.it)
			if it then
				-- 줄(단추의 왼쪽)을 누르면 그 물건의 상세가 창 옆에 뜬다(사용자 2026-10-13: "경매장에서 올라온거 눌러서 상세 볼수있어야합니다. 어떤아이템인지") — 한 번 더 누르면 닫힌다
				local row = Ui.group(sc, 0, y, bx - 4, S.row, "Row")
				local cell, icon = iconCell(row, 0, 2)
				cell:setOn(detail ~= nil and detail.id == r.id)
				Ui.setWorldIcon(icon, ItemCell.icon(it))
				-- 묶음은 이름 아래에 올라온 수를 적는다(사용자: "수량이 있는 아이템인경우 수량이 몇개가 올라와있는지도 보여야")
				local name, sub, tone = View.rowText(it, me, if bag and not it.item then bag.equip[it.slot] else nil)
				Ui.text(row, name, nx, 2, nw, { color = C[View.tone(it)] or C.text })
				Ui.text(row, sub, nx, 15, nw, { color = C[tone] or C.dim })
				Ui.text(row, r.sn, sx, 9, S.sellerW, { color = C.dim })
				Ui.text(row, View.left(r.e, t), lx, 9, S.leftW, { align = "right", color = C.dim })
				priceAt(row, px, 0, r.p, View.isStack(it))
				Ui.hit(row).Activated:Connect(function()
					detail = if detail and detail.id == r.id then nil else r
					fillBuy()
					paint()
				end)
				if r.mine then
					Ui.text(sc, W.selling, bx, y + 9, S.btnW, { align = "center", color = C.dim }) -- 내가 올린 것: 단추 자리에 「판매 중」
				else
					local button = Ui.button(sc, W.buy, bx, y + 3, S.btnW, function()
						ask, askQty = r, 1
						askBoxQty.Text = "1"
						paint()
					end, { h = S.btnH })
					table.insert(buyRows, { row = r, button = button })
				end
			end
		end
	end

	-- ---------- 시세 ----------
	local pLog = Ui.group(body, 0, listY, w, listH, "Log")
	pages.log = pLog
	fillLog = function()
		clear(pLog)
		local shown = View.filter(trades, query)
		if tab == "log" then
			total:set(Format.fill(W.rows, { n = #shown }))
		end
		if #shown == 0 then
			Ui.text(pLog, W.logEmpty, 0, 10, w, { align = "center", color = C.dim })
			return
		end
		local sc = Ui.scroll(pLog, 0, 0, w, listH, #shown * S.row, S.bar)
		local px = cw - S.priceW
		local lx = px - 19 - 6 - S.leftW
		local nx = S.icon + 6
		local nw = lx - 6 - nx
		local t = now()
		for i, r in shown do
			local y = (i - 1) * S.row
			local it = View.item(r.it)
			if it then
				local _, icon = iconCell(sc, 0, y + 2)
				Ui.setWorldIcon(icon, ItemCell.icon(it))
				local sub = View.tradeSub(it)
				Ui.text(sc, View.bare(it), nx, if sub == "" then y + 9 else y + 2, nw, { color = C[View.tone(it)] or C.text })
				if sub ~= "" then
					Ui.text(sc, sub, nx, y + 15, nw, { color = C.dim })
				end
				Ui.text(sc, View.ago(r.t, t), lx, y + 9, S.leftW, { align = "right", color = C.dim })
				priceAt(sc, px, y, r.p, View.isStack(it))
			end
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if query ~= search.Text then
			query, ask = search.Text, nil
			fillBuy()
			fillLog()
			paint()
		end
	end)

	-- ---------- 판매 ----------
	local pSell = Ui.group(body, 0, S.top, w, pageH, "Sell")
	pages.sell = pSell
	-- (가) 판매 중인 것들
	local pList = Ui.group(pSell, 0, 0, w, pageH, "Selling")
	Ui.text(pList, W.selling, 0, 6, w - S.sellW - 8, { color = C.gold })
	local sellOpen = Ui.button(pList, W.sell, w - S.sellW, 0, S.sellW, function()
		sellView, ask = "form", nil
		fillBag(true)
		paint()
	end, { h = S.btnH, main = true })
	local sellingTop = 28
	local sellingH = pageH - sellingTop - 18
	local sellingHolder = Ui.group(pList, 0, sellingTop, w, sellingH, "List")
	Ui.text(pList, Format.fill(W.depositNote, { n = Format.comma(M.deposit) }), 0, pageH - 12, w, { color = C.dim })
	local sellingButtons = {}
	fillSelling = function()
		clear(sellingHolder)
		sellingButtons = {}
		local list = View.sellingRows(mine)
		if #list == 0 then
			Ui.text(sellingHolder, W.sellEmpty, 0, 10, w, { align = "center", color = C.dim })
			return
		end
		local sc = Ui.scroll(sellingHolder, 0, 0, w, sellingH, #list * S.row, S.bar)
		local bx = cw - S.btnW
		local px = bx - 8 - S.priceW
		local nx = S.icon + 6
		local nw = px - 19 - 8 - nx
		local t = now()
		for i, r in list do
			local y = (i - 1) * S.row
			local it = View.item(r.it)
			if it then
				local _, icon = iconCell(sc, 0, y + 2)
				Ui.setWorldIcon(icon, ItemCell.icon(it))
				Ui.text(sc, View.name(it), nx, y + 2, nw, { color = C[View.tone(it)] or C.text })
				Ui.text(sc, View.sellNote(r, t), nx, y + 15, nw, { color = C.accent })
				priceAt(sc, px, y, r.p, View.isStack(it))
				local button = Ui.button(sc, W.cancel, bx, y + 3, S.btnW, function()
					call("settle", r.id, "back")
				end, { h = S.btnH })
				table.insert(sellingButtons, button)
			end
		end
	end
	-- (나) 등록 화면: 왼쪽 = 가방의 올릴 수 있는 것, 오른쪽 = 양식
	local pForm = Ui.group(pSell, 0, 0, w, pageH, "Form")
	local bagHead = Ui.text(pForm, W.pick, 0, 2, S.listW - S.backW - 8, { color = C.dim })
	Ui.button(pForm, W.back, S.listW - S.backW, -3, S.backW, function()
		sellView = "list"
		paint()
	end, { h = 20 })
	local bagTop = 20
	local bagH = pageH - bagTop - 4
	local bagHolder = Ui.group(pForm, 0, bagTop, S.listW, bagH, "List")
	local bagCells = {}
	-- 로벅스로 산 아이템인데 이 계정은 거래할 수 없다(로블록스 정책 — 2026-10-30)
	local function locked(it): boolean
		return paidLock and it ~= nil and it.item ~= nil and (Items.goods(it.item) or {}).paid == true
	end
	-- 고른 칸의 물건(가방이 그 사이에 달라졌으면 nil)
	local function picked()
		local bag = ctx.bag()
		if not pick or not bag then
			return nil
		end
		local it = bag[pick.tab] and bag[pick.tab][pick.slot]
		return if it and Market.sellable(it) then it else nil
	end
	local fx, fw = S.formX, w - S.formX
	local vx = fx + S.labelW -- 값의 자리
	local _, formIcon = iconCell(pForm, fx, 0)
	local formName = Ui.text(pForm, "", fx + S.icon + 6, 0, fw - S.icon - 6, { font = "body" })
	local formSub = Ui.text(pForm, "", fx + S.icon + 6, 16, fw - S.icon - 6, { color = C.dim })
	local y1 = 34
	local countLabel = Ui.text(pForm, W.count, fx, y1 + 6, S.labelW - 4, { color = C.dim })
	local countBox = Ui.field(pForm, vx, y1, S.qtyField, S.field, "1")
	local countOf = Ui.text(pForm, "", vx + S.qtyField + 6, y1 + 6, S.ofW, { color = C.dim })
	countBox:GetPropertyChangedSignal("Text"):Connect(function()
		local it = picked()
		local text, n = View.count(countBox.Text, if it and it.item then it.n else 1)
		if text ~= countBox.Text then
			countBox.Text = text
			return
		end
		count = n or 0 -- 0 = 칸이 비었다(「등록」이 눌리지 않는다)
		paintForm()
	end)
	local y2 = y1 + S.formRow
	local priceLabel = Ui.text(pForm, W.price, fx, y2 + 6, S.labelW - 4, { color = C.dim })
	local priceBox = Ui.field(pForm, vx, y2, S.priceField, S.field, "0")
	Ui.smallIcon(pForm, "coin", vx + S.priceField + 6, y2 + 2)
	local totalText = Ui.text(pForm, "", vx, y2 + S.field + 3, fw - S.labelW, { color = C.dim })
	local y3 = y2 + S.formRow + 12
	Ui.text(pForm, W.period, fx, y3 + 6, S.labelW - 4, { color = C.dim })
	local hourButtons = {}
	for i, hrs in M.hours do
		hourButtons[i] = Ui.button(pForm, Format.fill(W.hours, { n = hrs }), vx + (i - 1) * (S.hourW + 6), y3, S.hourW, function()
			hours = hrs
			paintForm()
		end, { h = S.btnH })
	end
	local y4 = y3 + S.formRow
	Ui.text(pForm, Format.fill(W.fee, { pct = M.fee }), fx, y4, S.labelW - 4, { color = C.dim })
	local feeText = Ui.text(pForm, "", vx, y4, fw - S.labelW, { color = C.dim })
	local y5 = y4 + 16
	Ui.text(pForm, W.deposit, fx, y5, S.labelW - 4, { color = C.dim })
	local depositText = Ui.text(pForm, Format.comma(M.deposit), vx, y5, fw - S.labelW, { color = C.dim })
	local y6 = y5 + 16
	Ui.text(pForm, W.get, fx, y6 + 4, S.labelW - 4, { color = C.dim })
	local getIcon = Ui.smallIcon(pForm, "coin", vx - 3, y6)
	local getText = Ui.text(pForm, "", vx + 18, y6 + 4, fw - S.labelW - 18, { color = C.gold })
	local y7 = y6 + 26
	local register = Ui.button(pForm, W.register, vx, y7, S.registerW, function()
		local it = picked()
		local me = ctx.me()
		local form = View.form(count, priceText, hours, if me then me.money else 0)
		if it and pick and form.ok then
			call("list", pick.tab, pick.slot, if it.item then count else 1, { form.price, hours }, function(res)
				if res and res.ok then
					pick, priceText, sellView = nil, "", "list"
					priceBox.Text = ""
				end
				fillBag(true)
			end)
		end
	end, { main = true })
	Ui.text(pForm, Format.fill(W.depositNote, { n = Format.comma(M.deposit) }), fx, y7 + Ui.M.button + 8, fw, { color = C.dim, lines = 2 })
	priceBox:GetPropertyChangedSignal("Text"):Connect(function()
		local clean = View.digits(priceBox.Text)
		if clean ~= priceBox.Text then
			priceBox.Text = clean
			return
		end
		priceText = clean
		paintForm()
	end)
	paintForm = function()
		local it = picked()
		local me, bag = ctx.me(), ctx.bag()
		if not it then
			pick = nil
		end
		local stack = it ~= nil and it.item ~= nil
		if it and it.item then
			count = math.clamp(count, 0, it.n)
		else
			count = 1
		end
		Ui.setWorldIcon(formIcon, if it then ItemCell.icon(it) else nil)
		formName:set(if it then View.name(if it.item then { item = it.item, n = math.max(1, count) } else it) else "")
		formName:color(if it then C[View.tone(it)] or C.text else C.text)
		local sub = ""
		if it and me then
			sub = View.sub(it, me, if bag and not it.item then bag.equip[it.slot] else nil)
		end
		if locked(it) then
			sub = W.paidLock
		end
		formSub:set(sub)
		formSub:color(if locked(it) then C.red else C.dim)
		countLabel:show(stack)
		showField(countBox, stack)
		countOf:show(stack)
		countOf:set(if it and it.item then View.of(it.n) else "")
		priceLabel:set(if stack then W.unitPrice else W.price)
		local form = View.form(count, priceText, hours, if me then me.money else 0)
		totalText:set(if stack and form.price then Format.fill(W.total, { n = Format.comma(form.total) }) else "")
		for i, b in hourButtons do
			b:setMain(M.hours[i] == hours)
		end
		feeText:set(if form.price then Format.comma(form.fee) else "")
		depositText:color(if form.short then C.red else C.dim)
		getIcon.Visible = form.price ~= nil
		getText:set(if form.price then Format.comma(form.pay) else "")
		register:setEnabled(not busy and it ~= nil and form.ok and count >= 1 and used < max and not locked(it))
		for _, c in bagCells do
			c.cell:setOn(pick ~= nil and c.tab == pick.tab and c.slot == pick.slot)
		end
	end
	-- 왼쪽 목록: 가방의 올릴 수 있는 것들(가방이 달라졌을 때만 다시 그린다)
	fillBag = function(force: boolean?)
		local me, bag = ctx.me(), ctx.bag()
		local list = View.sellables(bag)
		local parts = {}
		for _, e in list do
			table.insert(parts, ("%s%d:%s"):format(e.tab, e.slot, View.name(e.it)))
		end
		local key = table.concat(parts, "|") .. (if paidLock then "|L" else "")
		if key == sellKey and not force then
			paintForm()
			return
		end
		sellKey = key
		clear(bagHolder)
		bagCells = {}
		bagHead:set(if #list == 0 then W.none else W.pick)
		if #list > 0 and me then
			local sc = Ui.scroll(bagHolder, 0, 0, S.listW, bagH, #list * S.row, S.bar)
			local rw = S.listW - S.bar - 2
			local nx = S.icon + 6
			for i, e in list do
				local row = Ui.group(sc, 0, (i - 1) * S.row, rw, S.row, "Row")
				local cell, icon = iconCell(row, 0, 2)
				Ui.setWorldIcon(icon, ItemCell.icon(e.it))
				Ui.text(row, View.name(e.it), nx, 2, rw - nx, { color = C[View.tone(e.it)] or C.text })
				local sub, tone = View.sub(e.it, me, if bag and not e.it.item then bag.equip[e.it.slot] else nil)
				if locked(e.it) then
					sub, tone = W.paidLock, "red"
				end
				Ui.text(row, sub, nx, 15, rw - nx, { color = C[tone] or C.dim })
				Ui.hit(row).Activated:Connect(function()
					pick = { tab = e.tab, slot = e.slot }
					count = if e.it.item then e.it.n else 1 -- 처음에는 그 묶음 전부
					countBox.Text = tostring(count)
					paintForm()
				end)
				bagCells[i] = { cell = cell, tab = e.tab, slot = e.slot }
			end
		end
		paintForm()
	end

	-- ---------- 완료 ----------
	local pDone = Ui.group(body, 0, S.top, w, pageH, "Done")
	pages.done = pDone
	local doneH = pageH - 30
	local doneHolder = Ui.group(pDone, 0, 0, w, doneH, "List")
	Ui.text(pDone, Format.fill(W.keep, { n = M.keepDays }), 0, pageH - 16, w - S.allW - 8, { color = C.dim })
	local allButton = Ui.button(pDone, W.all, w - S.allW, pageH - 24, S.allW, function()
		call("all")
	end, { h = S.btnH, main = true })
	local doneButtons = {}
	local doneCount = 0
	fillDone = function()
		clear(doneHolder)
		doneButtons = {}
		local list = View.doneRows(mine)
		doneCount = #list
		if #list == 0 then
			Ui.text(doneHolder, W.doneEmpty, 0, 10, w, { align = "center", color = C.dim })
			return
		end
		local sc = Ui.scroll(doneHolder, 0, 0, w, doneH, #list * S.row, S.bar)
		local bx2 = cw - S.btnW
		local bx1 = bx2 - 4 - S.btnW
		local px = bx1 - 8 - S.priceW
		local nx = S.icon + 6
		local nw = px - 19 - 8 - nx
		for i, d in list do
			local y = (i - 1) * S.row
			local it = View.item(d.it)
			if it then
				local _, icon = iconCell(sc, 0, y + 2)
				Ui.setWorldIcon(icon, ItemCell.icon(it))
				Ui.text(sc, View.name(it), nx, y + 2, nw, { color = C[View.tone(it)] or C.text })
				Ui.text(sc, d.text, nx, y + 15, nw, { color = C[d.tone] or C.text })
				if d.amount then
					Ui.smallIcon(sc, "coin", px - 19, y + 5)
					Ui.text(sc, Format.comma(d.amount), px, y + 9, S.priceW, { align = "right", color = C.gold })
				end
				-- 단추는 오른쪽 끝부터(하나면 맨 오른쪽 자리)
				for k, b in d.buttons do
					local x = if #d.buttons == 1 or k == 2 then bx2 else bx1
					local button = Ui.button(sc, b.text, x, y + 3, S.btnW, function()
						call("settle", d.row.id, b.what)
					end, { h = S.btnH, main = b.main })
					table.insert(doneButtons, button)
				end
			end
		end
	end

	-- ---------- 그린다 ----------
	paint = function()
		local me = ctx.me()
		for i, id in View.TABS do
			tabs[i]:setOn(id == tab)
		end
		money:set(if me then Format.short(me.money) else "")
		slots:set(View.slots(used, max))
		for i, c in cats do
			catButtons[i]:setMain(c.id == cat)
			catButtons[i]:setEnabled(not busy)
		end
		classButton.frame.Visible = cat == "weapon"
		classButton:setEnabled(not busy)
		refresh:setEnabled(not busy)
		sortButton.frame.Visible = tab == "buy"
		for _, b in buyRows do
			b.button:setEnabled(not busy and me ~= nil and me.money >= b.row.p)
		end
		for _, b in sellingButtons do
			b:setEnabled(not busy)
		end
		for _, b in doneButtons do
			b:setEnabled(not busy)
		end
		sellOpen:setEnabled(not busy and used < max)
		allButton:setEnabled(not busy and doneCount > 0)
		pList.Visible = sellView == "list"
		pForm.Visible = sellView == "form"
		-- 묻는 줄
		local asking = ask ~= nil and tab == "buy" and not busy
		askBox.Visible = asking
		noteText:show(not asking)
		if asking and ask then
			local it = View.item(ask.it)
			local stack = it ~= nil and View.isStack(it)
			local text = View.ask(ask, askQty)
			askGear:show(not stack)
			askStack:show(stack)
			askGear:set(if stack then "" else text)
			askStack:set(if stack then text else "")
			askLabel:show(stack)
			showField(askBoxQty, stack)
			askOf:show(stack)
			askOf:set(if stack then View.of(ask.l or 1) else "")
			askYes:setEnabled(me ~= nil and askQty ~= nil and me.money >= ask.p * askQty)
		end
		-- 상세: 구매 탭에서 누른 줄의 물건(그 줄이 목록에서 사라졌으면 닫는다)
		local shown = nil
		if detail and tab == "buy" and me then
			for _, r in rows do
				if r.id == detail.id then
					shown = r
				end
			end
		end
		local dit = if shown then View.item(shown.it) else nil
		if shown and dit then
			local bag = ctx.bag()
			ItemDetail.show("auction", {
				key = ("auction|%s|%d|%d"):format(shown.id, shown.l or 1, me.level),
				item = dit,
				info = View.info(dit, me, if bag and not dit.item then bag.equip[dit.slot] else nil),
				buttons = {},
				onClose = function()
					detail = nil
					fillBuy()
					paint()
				end,
			})
		else
			detail = nil
			ItemDetail.hide("auction")
		end
		noteText:set(note)
		noteText:color(C[noteTone] or C.dim)
		if tab == "sell" and sellView == "form" then
			paintForm()
		end
	end

	-- 내 상태(달돈 · 가방)가 바뀌었다
	function view.refresh()
		if dead then
			return
		end
		if tab == "sell" and sellView == "form" then
			fillBag(false)
		end
		paint()
	end

	function view.destroy()
		dead = true
		ItemDetail.hide("auction")
	end

	showPages()
	fillBuy()
	fillLog()
	fillSelling()
	fillDone()
	paint()
	call("browse", board(), false)
	return view
end

return AuctionWindow
