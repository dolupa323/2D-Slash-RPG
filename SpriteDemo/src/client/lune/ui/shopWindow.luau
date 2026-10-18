-- 상점 · 창고 창 — 주민에게 말을 걸면 가방과 나란히 뜬다(공방 「기본 · UI」 탭). arg = 누구의 것인가:
--   "merchant" 잡화 상인(물약 · 귀환 주문서 · Lv.1 방어구 · 달가루) · "store" 창고지기(맡겨 둔 것). 대장장이는 상점이 없다(2026-10-15 — 제작 · 강화는 ui/forgeWindow.luau)
--  값과 물건은 공방 설계 자료(js/lune/design/items.js의 STOCK)에서 온다. 사고 팔고 맡기는 것은 서버에 부탁한다(Item).
--  사용자 2026-10-08: "소비, 기타아이템도 창고에 맡길수있어야하고, 상점에 팔기 가능해야하고 묶음나누기 가능해야하고 창고에 드래그앤 드랍으로 맡기기가능해야합니다."
--   · 창고는 가방과 같은 짜임이다: 탭 셋(장비 · 소비 · 기타) · 탭마다 칸 여섯 x 넷. 가방의 것을 끌어다 창고의 칸에 놓으면 맡겨지고(놓은 칸에 — 묶음은 전부),
--     창고의 것을 끌어다 가방에 놓으면 찾아진다. 창고 안에서도 끌어서 옮기고 「정렬」한다. 칸을 누르면 상세 판(「찾기」 — 묶음은 몇 개를 찾을지 고른다), 두 번 누르면 전부 찾는다.
--   · 상점: 가방의 것을 끌어다 상점 창에 놓으면 팔지 묻는다(가방의 상세 판에 — ui/bagWindow.luau). 상세 판의 「팔기」도 같은 일이다.
--  사용자 2026-10-13: "대장간 장비제작이나, 상점에서 소비템 구매하는거나  메이플스토리처럼 아이템 아이콘이 보여야합니다"
--   · 상점의 줄마다 그 물건의 그림(가방의 그 그림 — 칸 안에) · 값 앞에 달돈 그림. 제작의 줄마다 만들 장비의 그림과 재료의 그림(그 앞에는 글뿐이었다).
--     자리는 공방 시험 탭의 js/lune/ui/paint.js(paintShop · paintCraft)와 같다 — 치수는 공방 설계 자료(UILAYOUT.shop · craft).
--  화면 오른쪽 · 왼쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local ItemInfo = require(lune.ui.itemInfo)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local WORDS = require(lune.data["ui.generated"]).words
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local BagWindow = require(script.Parent.bagWindow)
local ItemDetail = require(script.Parent.itemDetail)
local Windows = require(script.Parent.windows)

local C = Ui.COLOR
local D = Items.data
local COLS = Layout.BAG.cols -- 창고의 칸: 가방과 같은 여섯 칸
local BAR = 3 -- 늘린 창고의 스크롤 막대 두께(가방 창과 같다 — 2026-10-18)
local HOLD = 0.3 -- 스마트폰: 잠깐 누르고 있다가 밀어야 끈다(그 전에 밀면 스크롤 — 가방 창과 같은 값)
local ROW = Ui.M.button + 4 -- 상점의 한 줄
local SHOP = Layout.SHOP
local CRAFT = Layout.CRAFT
local STORE = Layout.STORE
local W = SHOP.w
local MAX_ROWS = SHOP.rows -- 상점에 놓이는 물건의 줄 수(창의 높이)
local IC = SHOP.iconS -- 줄의 아이콘 칸(그 안에 18x18 그림)
local TX = IC + 6 -- 아이콘 칸의 오른쪽 — 이름이 시작하는 자리
local KEYS = D.BAG.keys -- 탭의 이름표("gear" · "use" · "etc")
local DOUBLE = 0.4 -- 이 안에 같은 칸을 다시 누르면 두 번 누른 것(초)

local ShopWindow = {}
ShopWindow.NAME_W, ShopWindow.PRICE_W, ShopWindow.BUY_W = SHOP.nameW, SHOP.priceW, SHOP.buyW -- 물건 이름 · 값 · 사는 단추(들)의 칸
ShopWindow.TITLE = { merchant = "잡화 상인 반달", store = WORDS.storeName }
ShopWindow.BACK_HEAD = "되사기 — 이번 접속에 판 것(판 값 그대로)" -- 2026-10-18
ShopWindow.BACK_BUY = "되사기"

function ShopWindow.title(arg: string): string
	return ShopWindow.TITLE[arg] or "상점"
end

function ShopWindow.size(arg: string): (number, number)
	if arg == "store" then
		return Layout.storeBody(Stage.ratio, D.BAG.storeBase)
	end
	return W, MAX_ROWS * ROW + 32 -- (2026-10-15: 대장장이의 단추 줄을 뺐다 — 상점은 잡화 상인뿐)
end

local function stockOf(npc: string)
	local list = {}
	for _, s in D.STOCK do
		if s.npc == npc then
			table.insert(list, s)
		end
	end
	return list
end
ShopWindow.stockOf = stockOf

-- 상점의 그 물건의 그림 이름(가방에 들어왔을 때의 그 그림): 물약 · 주문서 = 그 아이템의 것 · 장비 = 부위와 재질(무기는 내 직업의 것) · 달가루
function ShopWindow.stockIcon(stock, class: string): string
	if stock.goods then
		local g = Items.goods(stock.goods)
		return if g then g.icon else ""
	elseif stock.item then
		return ItemCell.icon(Items.make(stock.item.slot, stock.item.stage, D.NORMAL, class))
	end
	return "dust"
end

-- 창고: 탭 셋 · 칸 · 끌어서 맡기기와 찾기
local function buildStore(body: Frame, ctx, w: number)
	local view = {}
	local ui = ctx.ui
	local S = ItemCell.size()
	local base = D.BAG.storeBase -- 창의 높이는 처음 칸 수(네 줄)로 — 늘린 창고는 그 안에서 위아래로 민다
	local rowsN = math.ceil(base / COLS)
	local function sizeNow(): number
		local bag = ctx.bag()
		return if bag and bag.storeSize then bag.storeSize else base
	end
	local tab = 1
	local sel = nil :: { tab: string, slot: number, id: any }? -- 고른 칸(id = 장비의 번호 · 묶음의 이름표)
	local ask: number? = nil -- 찾을 수를 고르는 중이면 그 수
	local hot: number? = nil -- 끌던 것을 놓을 칸
	local lastClick = { slot = 0, t = 0 }
	local dragEnd = 0
	local panel = body.Parent :: GuiObject

	local function key(): string
		return KEYS[tab]
	end
	local function unselect()
		sel, ask = nil, nil
	end
	local function redraw()
		Windows.refresh(ctx.me())
	end
	-- 찾는다: 창고의 그 칸의 것을 가방으로(n = 묶음에서 찾을 수 — 안 주면 전부 · to = 놓을 가방 칸). 가방은 그 탭을 보여 준다(찾은 것이 보이게)
	local function take(tabKey: string, slot: number, n: number?, to: number?)
		ctx.send("Item", "storeOut", tabKey, slot, n, to)
		if ui.bagShow then
			ui.bagShow(tabKey)
		end
	end

	local tabs = {}
	local tx = 0
	for i, name in D.BAG.tabs do
		tabs[i] = Ui.tab(body, name, tx, 0, function()
			if tab ~= i then
				tab = i
				unselect()
				redraw()
			end
		end)
		tx += tabs[i].width + 16
	end
	local count = Ui.text(body, "", w - Layout.BAG.countW, 0, Layout.BAG.countW, { align = "right", color = C.dim }) -- 찬 칸 / 창고의 칸

	local gridRoot = Ui.scroll(body, 0, STORE.gridY, COLS * S, rowsN * S, rowsN * S, BAR) -- 칸들(늘린 창고는 위아래로 스크롤)
	gridRoot.Name = "Grid"
	local cells = {}
	local function slotAt(at: Vector2): number?
		if not ItemCell.over(gridRoot, at) then
			return nil -- 스크롤로 가려진 칸은 아니다
		end
		local i = ItemCell.at(cells, at)
		return if i and i <= sizeNow() then i else nil
	end
	-- 칸 하나를 짓는다(2026-10-18 검토: 창고 칸을 늘려도(Bag.growStore) 처음 24칸만 지어 25칸부터 보이지도 꺼내지도 못했다 — 가방 창처럼 늘어난 만큼 더 짓고 위아래로 민다)
	local function makeCell(i: number)
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		local cell
		cell = ItemCell.new(gridRoot, col * S, row * S, function(it)
			local now = os.clock()
			-- 끌어서 놓은 것은 누른 것이 아니다(놓은 자리의 칸에도 "눌렀다"가 온다)
			if ctx.quick.dragging() or now - dragEnd < 0.2 then
				return
			end
			local twice = it ~= nil and lastClick.slot == i and now - lastClick.t < DOUBLE
			lastClick = { slot = if twice then 0 else i, t = now }
			if not it then
				unselect()
			elseif twice then
				take(key(), i, nil, nil) -- 두 번 누르기: 전부 찾는다
				unselect()
			else
				sel = { tab = key(), slot = i, id = if it.item then it.item else it.id }
				ask = nil
				ui.detail = "shop"
			end
			redraw()
		end, S)
		cells[i] = cell
		-- 끌기: 창고의 다른 칸 = 창고 안에서 옮긴다 · 가방 창 = 찾는다(놓은 칸에 — 묶음은 전부)
		cell.hit.InputBegan:Connect(function(input)
			local it = cell.item
			if not it then
				return
			end
			local from, tabKey = i, key()
			local moved = false
			ctx.quick.press(nil, nil, input, {
				icon = ItemCell.icon(it),
				size = S,
				hold = HOLD,
				onStart = function()
					gridRoot.ScrollingEnabled = false -- 끄는 동안은 칸들이 움직이지 않는다(늘린 창고는 스크롤한다)
				end,
				onMove = function(at: Vector2)
					moved = true
					local to = slotAt(at)
					if hot ~= to then
						hot = to
						view.refresh()
					end
					if ui.bagHover then
						ui.bagHover(at, tabKey) -- 가방의 놓을 칸이 밝아진다
					end
				end,
				onDrop = function(at: Vector2): boolean
					local to = slotAt(at)
					if to and to ~= from then
						ctx.send("Item", "storeMove", tabKey, from, to)
						-- 화면은 바로 옮긴다(같은 묶음끼리 합치는 것은 서버의 셈을 기다린다)
						local bag = ctx.bag()
						local list = if bag then bag.store[tabKey] else nil
						local a = if list then list[from] else nil
						local b = if list then list[to] else nil
						local merge = tabKey ~= "gear" and a and b and a.item == b.item
						if list and a and not merge then
							list[from], list[to] = b or false, a
						end
						if sel and sel.tab == tabKey and (sel.slot == from or sel.slot == to) then
							if merge then
								unselect()
							else
								sel.slot = if sel.slot == from then to else from
							end
						end
					end
					if to then
						return true
					end
					if ui.bagDrop then
						local over, slot = ui.bagDrop(at, tabKey)
						if over then
							take(tabKey, from, nil, slot)
							if sel and sel.tab == tabKey and sel.slot == from then
								unselect()
							end
							return true
						end
					end
					return false
				end,
				onEnd = function()
					if moved then
						dragEnd = os.clock()
					end
					if ui.bagHover then
						ui.bagHover(nil, nil)
					end
					if hot then
						hot = nil
						view.refresh()
					end
				end,
			})
		end)
	end
	for i = 1, COLS * rowsN do
		makeCell(i)
	end

	-- 가방에서 끌어 온 것을 놓는 자리(ui/bagWindow.luau가 묻는다): 창고 창 위면 맡긴다 — 그 탭이 열려 있으면 놓은 칸에, 다른 탭이 열려 있었으면 그 탭으로 넘긴다
	ui.storeDrop = function(at: Vector2, tabKey: string, from: number): boolean
		if not ItemCell.over(panel, at) then
			return false
		end
		local to = if tabKey == key() then slotAt(at) else nil
		ctx.send("Item", "storeIn", tabKey, from, nil, to)
		if tabKey ~= key() then
			tab = table.find(KEYS, tabKey) or tab
			unselect()
		end
		return true
	end
	-- 가방의 「맡기기」로 맡겼을 때: 창고가 그 탭을 보여 준다
	ui.storeShow = function(tabKey: string)
		if tabKey ~= key() then
			tab = table.find(KEYS, tabKey) or tab
			unselect()
		end
	end
	ui.storeHover = function(at: Vector2?, tabKey: string?)
		local to = if at and tabKey == key() then slotAt(at) else nil
		if hot ~= to then
			hot = to
			view.refresh()
		end
	end

	-- 칸 아래: 「정렬」과 안내 글
	local fy = STORE.gridY + rowsN * S + STORE.footY
	local sort = Ui.button(body, WORDS.sort, 0, fy, STORE.sortW, function()
		ctx.send("Item", "storeSort", key())
		unselect()
		view.refresh()
	end)
	sort.frame.Name = "Sort"
	Ui.text(body, WORDS.storeHint, STORE.sortW + 10, fy + 8, w - STORE.sortW - 10, { align = "right", color = C.dim })

	-- 고른 것의 상세 판(창 옆): 「찾기」 — 묶음은 몇 개를 찾을지 고른다
	local function detail(bag, me)
		if ui.detail ~= "shop" then
			unselect() -- 다른 창에서 골랐다
		end
		local list = if sel then bag.store[sel.tab] else nil
		local entry = if sel and list then list[sel.slot] else nil
		if sel and sel.tab == "gear" and (not entry or entry.id ~= sel.id) then
			entry = nil
			for i = 1, bag.storeSize do
				local it = list[i]
				if it and it.id == sel.id then
					sel.slot, entry = i, it
					break
				end
			end
		elseif sel and sel.tab ~= "gear" and entry and entry.item ~= sel.id then
			entry = nil
		end
		if not sel or not entry then
			unselect()
			ItemDetail.hide("shop")
			return
		end
		local slot, tabKey = sel.slot, sel.tab
		local spec = { item = entry, buttons = {}, onClose = function()
			unselect()
			redraw()
		end }
		if tabKey == "gear" then
			ask = nil
			spec.info = ItemInfo.gear(entry, me, bag.equip[entry.slot], false)
			table.insert(spec.buttons, { text = WORDS.take, main = true, onClick = function()
				take("gear", slot, nil, nil)
				unselect()
				redraw()
			end })
			spec.key = table.concat({ "store", entry.id, entry.q, entry.star, tostring(entry.broken), me.level }, "|")
		else
			spec.info = ItemInfo.goods(entry.item, me, entry.n) -- 가진 수 = 창고의 그 묶음
			if ask then
				local n = math.clamp(ask, 1, entry.n)
				ask = n
				spec.ask = ItemDetail.ask("take", n, 1, entry.n, {
					set = function(v: number)
						ask = v
						view.refresh()
					end,
					yes = function(countNow: number)
						take(tabKey, slot, countNow, nil)
						ask = nil
						view.refresh()
					end,
					no = function()
						ask = nil
						view.refresh()
					end,
				})
			else
				table.insert(spec.buttons, { text = WORDS.take, main = true, onClick = function()
					if entry.n == 1 then
						take(tabKey, slot, 1, nil)
						unselect()
						redraw()
					else
						ask = entry.n -- 처음에는 그 묶음 전부
						view.refresh()
					end
				end })
			end
			spec.key = table.concat({ "store", tabKey, slot, entry.item, entry.n, me.level, if ask then ask else "-" }, "|")
		end
		ItemDetail.show("shop", spec)
	end

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		for i, button in tabs do
			button:setOn(i == tab)
		end
		local list = bag.store[key()]
		-- 늘린 창고: 네 줄을 넘는 만큼 칸을 더 짓고 스크롤 틀의 속을 늘린다(가방 창과 같다)
		local rows = math.ceil(bag.storeSize / COLS)
		for i = #cells + 1, rows * COLS do
			makeCell(i)
		end
		local scroll = rows > rowsN
		gridRoot.CanvasSize = UDim2.fromOffset(0, math.max(rowsN, rows) * S)
		gridRoot.ScrollingEnabled = scroll and not ctx.quick.dragging()
		gridRoot.ScrollBarThickness = if scroll then BAR else 0
		local used = 0
		for i = 1, bag.storeSize do
			if list[i] then
				used += 1
			end
		end
		count:set(("%d / %d"):format(used, bag.storeSize))
		detail(bag, me)
		for i, cell in cells do
			local item = list[i] or nil
			cell:set(item, { locked = i > bag.storeSize, selected = sel ~= nil and sel.tab == key() and sel.slot == i, hot = hot == i })
		end
		sort:setEnabled(used > 1)
	end

	function view.destroy()
		ItemDetail.hide("shop")
		if ui.detail == "shop" then
			ui.detail = nil
		end
		ui.storeDrop, ui.storeHover, ui.storeShow = nil, nil, nil
	end
	return view
end

-- (제작은 2026-10-15에 대장장이 창으로 옮겼다 — ui/forgeWindow.luau. 대장장이의 상점은 없앴다: 사용자 "상점 없어야함 제작, 강화만 하는곳임")

function ShopWindow.build(body: Frame, ctx, w: number, h: number, arg: string)
	if arg == "store" then
		return buildStore(body, ctx, w)
	end
	local view = {}
	local ui = ctx.ui
	local panel = body.Parent :: GuiObject

	-- 상점: 물건마다 한 줄([그림] 이름 · [달돈] 값 · 사기). 물약(단마다 따로 판다 — 가방의 소비 탭에 들어온다)과 달가루는 열 개씩도 산다
	local rows = {}
	local bx = w - ShopWindow.BUY_W
	-- 물건이 창의 줄(MAX_ROWS)보다 많으면 목록이 스크롤한다(2026-10-18 — 달빛 부적 · 능력치 초기화 주문서로 열둘이 됐다. 창은 스마트폰의 화면 틀에 들어가야 한다)
	local stocks = stockOf(arg)
	local list = Ui.scroll(body, 0, 0, w, MAX_ROWS * ROW, #stocks * ROW, 3)
	for i, stock in stocks do
		local y = (i - 1) * ROW
		local many = stock.max > 1
		-- [그 물건의 그림(칸 안에)] 이름 · [달돈] 값 · 사는 단추 — 살 수 없는 것도 그림은 보인다
		local cell = Ui.slot(list, 0, y + 1, IC)
		cell.frame.Name = "Icon"
		local icon = Ui.smallIcon(cell.frame, "coin", 3, 3)
		local name = Ui.text(list, "", TX, y + 7, ShopWindow.NAME_W, { font = "body" })
		local coin = Ui.smallIcon(list, "coin", bx - 8 - ShopWindow.PRICE_W - 19, y + 4)
		local price = Ui.text(list, "", bx - 8 - ShopWindow.PRICE_W, y + 8, ShopWindow.PRICE_W, { align = "right", color = C.gold })
		local half = math.floor((ShopWindow.BUY_W - 6) / 2)
		local one = Ui.button(list, if many then "1" else "사기", bx, y, if many then half else ShopWindow.BUY_W, function()
			ctx.send("Item", "buy", stock.id, 1)
		end)
		local ten = if many
			then Ui.button(list, "10", bx + half + 6, y, half, function()
				ctx.send("Item", "buy", stock.id, 10)
			end)
			else nil
		-- 아직 살 수 없는 것은 값과 단추 자리에 "Lv.10부터"
		local lock = Ui.text(list, "", TX + ShopWindow.NAME_W, y + 8, w - TX - ShopWindow.NAME_W, { align = "right", color = C.dim })
		rows[i] = { stock = stock, icon = icon, coin = coin, name = name, price = price, one = one, ten = ten, lock = lock }
	end
	-- 되사기(2026-10-18 — 메이플의 재구매): 물건의 줄 아래에 머리 한 줄 「되사기 — 이번 접속에 판 것」과 판 것들(가장 최근 것부터 · 판 값 그대로). 판 것이 없으면 감춘다
	local backY = #stocks * ROW
	local backHead = Ui.text(list, ShopWindow.BACK_HEAD, 0, backY + 8, w, { color = C.dim })
	local backs = {}
	for i = 1, Bag.BUYBACK do
		local y = backY + i * ROW
		local cell = Ui.slot(list, 0, y + 1, IC)
		cell.frame.Name = "BackIcon"
		local icon = Ui.smallIcon(cell.frame, "coin", 3, 3)
		local name = Ui.text(list, "", TX, y + 7, ShopWindow.NAME_W, { font = "body" })
		local coin = Ui.smallIcon(list, "coin", bx - 8 - ShopWindow.PRICE_W - 19, y + 4)
		local price = Ui.text(list, "", bx - 8 - ShopWindow.PRICE_W, y + 8, ShopWindow.PRICE_W, { align = "right", color = C.gold })
		local buy = Ui.button(list, ShopWindow.BACK_BUY, bx, y, ShopWindow.BUY_W, function()
			ctx.send("Item", "buyback", i)
		end)
		backs[i] = { cell = cell, icon = icon, name = name, coin = coin, price = price, buy = buy }
	end
	local fy = h - 28
	Ui.line(body, 0, fy - 6, w)
	local money = BagWindow.purse(body, "coin", -3, fy, 90)
	local dust = BagWindow.purse(body, "dust", 96, fy, 90)
	-- 팔기: 가방의 것을 끌어다 이 창에 놓는다(가방의 상세 판이 팔지 묻는다)
	Ui.text(body, WORDS.shopHint, SHOP.hintX, fy + 4, w - SHOP.hintX, { align = "right", color = C.dim })
	ui.shopDrop = function(at: Vector2): boolean
		return ItemCell.over(panel, at)
	end

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		for _, row in rows do
			local stock = row.stock
			local cost = Items.stockPrice(stock, me.level)
			local label = stock.name
			local open = me.level >= stock.from
			Ui.setWorldIcon(row.icon, ShopWindow.stockIcon(stock, me.class))
			row.coin.Visible = open
			row.name:set(label)
			row.name:color(if open then C.text else C.dim)
			row.price:set(if open then Format.short(cost) else "")
			row.lock:set(if open then "" else ("Lv.%d부터"):format(stock.from))
			row.one.frame.Visible = open
			row.one:setEnabled(me.money >= cost)
			if row.ten then
				row.ten.frame.Visible = open
				row.ten:setEnabled(me.money >= cost * 10)
			end
		end
		-- 되사기의 줄들
		local sold = bag.buyback or {}
		backHead:show(#sold > 0)
		for i, b in backs do
			local e = sold[i]
			local on = e ~= nil
			b.cell.frame.Visible, b.coin.Visible, b.buy.frame.Visible = on, on, on
			b.name:show(on)
			b.price:show(on)
			if e then
				local goods = e.item and Items.goods(e.item)
				Ui.setWorldIcon(b.icon, if e.gear then ItemCell.icon(e.gear) elseif goods then goods.icon else "")
				b.name:set(if e.gear then ItemCell.label(e.gear) elseif goods then ("%s x%d"):format(goods.name, e.n) else "")
				b.name:color(if e.gear then ItemCell.color(e.gear) else C.text)
				b.price:set(Format.short(e.price))
				b.buy:setEnabled(me.money >= e.price)
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, math.max(MAX_ROWS * ROW, #stocks * ROW + (if #sold > 0 then ROW * (#sold + 1) else 0)))
		list.ScrollingEnabled = #stocks + (if #sold > 0 then #sold + 1 else 0) > MAX_ROWS
		money:set(Format.short(me.money))
		dust:set(Format.short(bag.dust))
	end

	function view.destroy()
		ui.shopDrop = nil
	end
	return view
end

return ShopWindow
