-- 상점 · 창고 창 — 주민에게 말을 걸면 가방과 나란히 뜬다(공방 「기본 · UI」 탭). arg = 누구의 것인가:
--   "merchant" 잡화 상인(물약 · Lv.1 방어구) · "smith" 대장장이(달가루 · Lv.10 무기와 방어구) · "store" 창고지기(맡겨 둔 장비)
--  값과 물건은 공방 설계 자료(js/lune/design/items.js의 STOCK)에서 온다. 사고 맡기는 것은 서버에 부탁한다(Item).
--  화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local N = require(lune.config.numbers)
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local BagWindow = require(script.Parent.bagWindow)

local C = Ui.COLOR
local D = Items.data
local COLS = 6 -- 창고의 칸: 가방과 같은 여섯 칸
local ROW = Ui.M.button + 4 -- 상점의 한 줄
local SHOP = Layout.SHOP
local W = SHOP.w
local MAX_ROWS = SHOP.rows -- 상점에 놓이는 물건의 줄 수(창의 높이)

local ShopWindow = {}
ShopWindow.NAME_W, ShopWindow.PRICE_W, ShopWindow.BUY_W = SHOP.nameW, SHOP.priceW, SHOP.buyW -- 물건 이름 · 값 · 사는 단추(들)의 칸
ShopWindow.TITLE = { merchant = "잡화 상인 반달", smith = "대장장이 무쇠뿔", store = "창고" }

function ShopWindow.title(arg: string): string
	return ShopWindow.TITLE[arg] or "상점"
end

function ShopWindow.size(arg: string): (number, number)
	if arg == "store" then
		local S = ItemCell.size()
		return COLS * S, math.ceil(D.BAG.storeBase / COLS) * S + 96
	end
	return W, MAX_ROWS * ROW + Ui.M.button + 12 + 32
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

function ShopWindow.build(body: Frame, ctx, w: number, h: number, arg: string)
	local view = {}

	if arg == "store" then
		-- 창고: 칸을 누르면 고르고, 「찾기」로 가방에 넣는다
		local S = ItemCell.size()
		local selected: number? = nil
		local cells = {}
		local rows = math.ceil(D.BAG.storeBase / COLS)
		for i = 1, COLS * rows do
			local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
			cells[i] = ItemCell.new(body, col * S, row * S, function(it)
				selected = if it then it.id else nil
				view.refresh()
			end, S)
		end
		local y = rows * S + 12
		local name = Ui.text(body, "", 0, y, w, { font = "body" })
		local out = Ui.button(body, "찾기", 0, y + 24, 96, function()
			if selected then
				ctx.send("Item", "storeOut", selected)
				selected = nil
			end
		end, { main = true })
		local held = Ui.text(body, "", 104, y + 32, w - 104, { align = "right", color = C.dim })
		Ui.text(body, "가방에서 고르고 「맡기기」", 0, y + 62, w, { color = C.dim })
		function view.refresh()
			local bag = ctx.bag()
			if not bag then
				return
			end
			local picked = nil
			for i, cell in cells do
				local it = bag.store[i]
				if it and it.id == selected then
					picked = it
				end
				cell:set(it, { locked = i > bag.storeSize, selected = it ~= nil and it.id == selected })
			end
			if picked then
				name:set(ItemCell.label(picked))
				name:color(ItemCell.color(picked))
			else
				name:set("")
			end
			out:setEnabled(picked ~= nil)
			held:set(("맡긴 것 %d / %d"):format(#bag.store, bag.storeSize))
		end
		return view
	end

	-- 상점: 물건마다 한 줄(이름 · 값 · 사기). 물약과 달가루는 열 개씩도 산다
	local rows = {}
	local bx = w - ShopWindow.BUY_W
	for i, stock in stockOf(arg) do
		local y = (i - 1) * ROW
		local many = stock.max > 1
		local name = Ui.text(body, "", 0, y + 7, ShopWindow.NAME_W, { font = "body" })
		local price = Ui.text(body, "", bx - 8 - ShopWindow.PRICE_W, y + 8, ShopWindow.PRICE_W, { align = "right", color = C.gold })
		local half = math.floor((ShopWindow.BUY_W - 6) / 2)
		local one = Ui.button(body, if many then "1" else "사기", bx, y, if many then half else ShopWindow.BUY_W, function()
			ctx.send("Item", "buy", stock.id, 1)
		end)
		local ten = if many
			then Ui.button(body, "10", bx + half + 6, y, half, function()
				ctx.send("Item", "buy", stock.id, 10)
			end)
			else nil
		-- 아직 살 수 없는 것은 값과 단추 자리에 "Lv.10부터"
		local lock = Ui.text(body, "", ShopWindow.NAME_W, y + 8, w - ShopWindow.NAME_W, { align = "right", color = C.dim })
		rows[i] = { stock = stock, name = name, price = price, one = one, ten = ten, lock = lock }
	end
	local fy = h - 28
	local swap = if arg == "smith"
		then Ui.button(body, "강화하러 가기", 0, fy - Ui.M.button - 12, w, function()
			ctx.openService("forge")
		end, { main = true })
		else nil
	Ui.line(body, 0, fy - 6, w)
	local money = BagWindow.purse(body, "coin", -3, fy, 90)
	local dust = BagWindow.purse(body, "dust", 96, fy, 90)

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		for _, row in rows do
			local stock = row.stock
			local cost = Items.stockPrice(stock, me.level)
			local label = stock.name
			if stock.id == "potion" then
				label = N.potionAt(me.level).name
			elseif stock.id == "w10" then
				label = Items.name(Items.make("weapon", stock.item.stage, D.NORMAL, me.class))
			end
			local open = me.level >= stock.from
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
		if swap then
			swap:setEnabled(me.level >= D.OPEN.forge)
		end
		money:set(Format.short(me.money))
		dust:set(Format.short(bag.dust))
	end
	return view
end

return ShopWindow
