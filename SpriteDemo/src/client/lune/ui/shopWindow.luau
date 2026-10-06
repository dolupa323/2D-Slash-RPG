-- 상점 · 창고 창 — 주민에게 말을 걸면 가방과 나란히 뜬다(공방 「기본 · UI」 탭). arg = 누구의 것인가:
--   "merchant" 잡화 상인(물약 · Lv.1 방어구) · "smith" 대장장이(달가루 · Lv.10 무기와 방어구) · "store" 창고지기(맡겨 둔 장비)
--  값과 물건은 공방 설계 자료(js/lune/design/items.js의 STOCK)에서 온다. 사고 맡기는 것은 서버에 부탁한다(Item).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local N = require(lune.config.numbers)
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Kit = require(script.Parent.kit)
local ItemCell = require(script.Parent.itemCell)
local BagWindow = require(script.Parent.bagWindow)

local C = Kit.COLOR
local D = Items.data
local COLS, S = 8, ItemCell.SIZE
local ROW = 15 -- 상점의 한 줄

local ShopWindow = { height = 150 }
ShopWindow.NAME_W, ShopWindow.PRICE_W, ShopWindow.LOCK_W = 100, 30, 64 -- 물건 이름 · 값 · "Lv.10부터"의 칸(테스트 15가 글이 들어가는지 본다)
ShopWindow.TITLE = { merchant = "잡화 상인 반달", smith = "대장장이 무쇠뿔", store = "창고" }

function ShopWindow.title(arg: string): string
	return ShopWindow.TITLE[arg] or "상점"
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

function ShopWindow.build(body: Frame, ctx, w: number, _h: number, arg: string)
	local view = {}

	if arg == "store" then
		-- 창고: 칸을 누르면 고르고, 「찾기」로 가방에 넣는다
		local selected: number? = nil
		local cells = {}
		local rows = math.ceil(D.BAG.storeBase / COLS)
		local gw, gh = COLS * S + 6, rows * S + 6
		local paper = Kit.group(body, 2, 0, gw, gh)
		Kit.part(paper, "paper", 0, 0, gw, gh)
		for i = 1, COLS * rows do
			local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
			cells[i] = ItemCell.new(paper, 3 + col * S, 3 + row * S, function(it)
				selected = if it then it.id else nil
				view.refresh()
			end)
		end
		local name = Kit.text(body, "", 4, gh + 3, w - 8)
		local out = Kit.button(body, "찾기", 2, gh + 16, 52, 14, function()
			if selected then
				ctx.send("Item", "storeOut", selected)
				selected = nil
			end
		end, { kind = "orange" })
		local held = Kit.text(body, "", 58, gh + 19, w - 62, { align = "right", color = C.dim })
		Kit.text(body, "가방에서 고르고 「맡기기」", 4, gh + 35, w - 8, { color = C.dim })
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
			held:set(("맡긴 것 %d/%d"):format(#bag.store, bag.storeSize))
		end
		return view
	end

	-- 상점: 물건마다 한 줄(이름 · 값 · 사기). 물약과 달가루는 열 개씩도 산다
	local rows = {}
	for i, stock in stockOf(arg) do
		local y = 1 + (i - 1) * ROW
		local many = stock.max > 1
		if i > 1 then
			Kit.box(body, 2, y - 1, w - 4, 1, C.frameLo)
		end
		local name = Kit.text(body, "", 4, y + 2, ShopWindow.NAME_W)
		local price = Kit.text(body, "", 4 + ShopWindow.NAME_W, y + 2, ShopWindow.PRICE_W, { align = "right", color = C.yellow })
		local bx = 4 + ShopWindow.NAME_W + ShopWindow.PRICE_W + 3
		local one = Kit.button(body, if many then "1" else "사기", bx, y, if many then 15 else 33, 13, function()
			ctx.send("Item", "buy", stock.id, 1)
		end)
		local ten = if many
			then Kit.button(body, "10", bx + 16, y, 17, 13, function()
				ctx.send("Item", "buy", stock.id, 10)
			end)
			else nil
		-- 아직 살 수 없는 것은 값과 단추 자리에 "Lv.10부터"
		local lock = Kit.text(body, "", 4 + ShopWindow.NAME_W, y + 2, ShopWindow.LOCK_W, { align = "right", color = C.dim })
		rows[i] = { stock = stock, name = name, price = price, one = one, ten = ten, lock = lock }
	end
	local swap = if arg == "smith"
		then Kit.button(body, "강화하러 가기", 2, 97, w - 4, 14, function()
			ctx.openService("forge")
		end, { kind = "orange" })
		else nil
	local money = BagWindow.purse(body, "coin", 3, 117, 82)
	local dust = BagWindow.purse(body, "dust", 88, 117, 80)

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
			row.name:color(if open then C.white else C.dim)
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
