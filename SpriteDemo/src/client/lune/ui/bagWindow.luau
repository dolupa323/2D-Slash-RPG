-- 가방 창 — 화면 오른쪽의 옆 판. 탭 셋(장비 · 소비 · 기타), 세 탭 모두 칸 여섯 x 넷이다(48칸까지 늘리면 ▲▼로 줄을 넘긴다).
--  사용자 2026-10-08: "지금 인벤토리 구조도 잘못되어있는데 … 품목이 고정되어있고 거기서 수량 1/8 이런식으로 표기하는게 인벤토리가 아닙니다."
--  → 가방은 탭마다 진짜 칸이다(공방 js/lune/design/items.js의 BAGPLAY — 셈은 shared/lune/sim/bag.luau):
--   · 칸에는 장비 하나 또는 소비 · 기타 아이템의 묶음(그림과 오른쪽 아래의 수)이 놓인다. 빈 칸은 비어 있고, 놓인 자리는 내가 옮기기 전까지 그대로다.
--   · 칸을 누르면 그 아이템의 상세가 창 옆의 작은 판에 뜬다(ui/itemDetail.luau) — 할 수 있는 일의 단추가 거기 있다:
--     장착 · 분해 / 사용 · 퀵슬롯 · 버리기 · 나누기 / (창고지기 앞) 맡기기 · (상점 앞) 팔기 · (대장장이의 강화 창) 강화.
--     "장비 탭에서 각각의 장비를 선택하면 … 작은모달이 떠서 아이템 스펙이 나와야합니다. 인벤토리에서 선택도 마찬가지입니다. 기타아이템, 소비아이템 모두 마찬가지입니다."
--   · 칸의 것을 끌어 다른 칸에 놓으면 옮겨진다(다른 것이 있으면 자리를 바꾸고, 같은 묶음이면 합친다). 소비 아이템은 끌어 퀵슬롯(스마트폰: 칸 단추)에 놓는다.
--   · 끌어서 창고 창에 놓으면 맡겨지고(놓은 칸에 — 묶음은 전부), 상점 창에 놓으면 팔지 묻는다
--     (사용자 2026-10-08: "소비, 기타아이템도 창고에 맡길수있어야하고, 상점에 팔기 가능해야하고 묶음나누기 가능해야하고 창고에 드래그앤 드랍으로 맡기기가능해야합니다").
--   · 같은 칸을 두 번 누르면 장비는 장착, 소비 아이템은 사용. 「정렬」은 그 탭을 앞에서부터 채운다.
--  달돈 · 달가루 · 정수는 칸을 차지하지 않는다 — 창 아래에 그림과 숫자로(공방 「돈 · 상점」 탭의 가방 규칙).
--  PC · 스마트폰이 같은 창이다: 누르기 = 톡, 끌기 = 누른 채 움직이기, 두 번 누르기 = 톡톡.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local Format = require(lune.ui.format)
local ItemInfo = require(lune.ui.itemInfo)
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local WORDS = require(lune.data["ui.generated"]).words -- 낱말(장착 · 정렬 …) — 공방에서 정한 것
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local ItemDetail = require(script.Parent.itemDetail)
local Windows = require(script.Parent.windows)

local C = Ui.COLOR
local D = Items.data
local BAG = Layout.BAG
local COLS, ROWS = BAG.cols, BAG.rows
local GRID_Y = BAG.gridY -- 칸들의 윗줄
local KEYS = D.BAG.keys -- 탭의 이름표("gear" · "use" · "etc")
local DOUBLE = 0.4 -- 이 안에 같은 칸을 다시 누르면 두 번 누른 것(초)

local BagWindow = { side = "right" } -- 가방은 늘 오른쪽에 뜬다(같이 열린 창은 왼쪽으로 간다)
BagWindow.COLS, BagWindow.ROWS = COLS, ROWS

function BagWindow.size(): (number, number)
	return Layout.bagBody(Stage.ratio)
end

-- 가방을 늘리는 단추의 글
function BagWindow.growText(cost: number): string
	return ("+%d칸 %s"):format(D.BAG.step, Format.short(cost))
end

-- 그 장비를 지금 낄 수 있는가(화면의 단추를 켜고 끄는 데 쓴다 — 서버가 다시 본다)
function BagWindow.canWear(me, it): boolean
	return not it.broken and (it.slot ~= "weapon" or it.who == me.class) and me.level >= Items.needLevel(it)
end

-- 그림과 숫자(달돈 · 달가루 · 정수). (x, y) = 그림의 왼쪽 위 — 숫자는 그 오른쪽에
local function purse(parent: Instance, icon: string, x: number, y: number, w: number)
	Ui.smallIcon(parent, icon, x, y)
	return Ui.text(parent, "", x + 21, y + 4, w - 21)
end
BagWindow.purse = purse

function BagWindow.build(body: Frame, ctx, w: number, _h: number)
	local ui = ctx.ui
	local S = ItemCell.size()
	local tab = 1
	local top = 0 -- 맨 윗줄이 몇째 줄인가(가방을 늘린 뒤 ▲▼로 넘긴다)
	local sel = nil :: { tab: string, slot: number, id: any }? -- 고른 칸(id = 장비의 번호 · 묶음의 이름표 — 칸의 것이 바뀌면 고른 것을 푼다)
	local ask = nil :: { kind: string, n: number? }? -- 수를 고르는 중(버리기 · 맡기기 · 팔기 · 나누기 — 장비 팔기는 n 없이 묻기만)
	local hot: number? = nil -- 끌던 것을 놓을 칸
	local lastClick = { slot = 0, t = 0 }
	local dragEnd = 0 -- 마지막으로 끌기를 끝낸 때(그 직후에 오는 "눌렀다"는 끌기의 끝이지 누른 것이 아니다)
	local view = {}

	local function key(): string
		return KEYS[tab]
	end
	local function unselect()
		sel, ask = nil, nil
	end
	-- 모든 창을 다시 그린다(상세 판은 하나뿐이라, 여기서 고르면 다른 창이 고른 것은 풀린다)
	local function redraw()
		Windows.refresh(ctx.me())
	end
	local function choose(tabKey: string, slot: number, it)
		sel = { tab = tabKey, slot = slot, id = if it.item then it.item else it.id }
		ask = nil
		ui.detail = "bag"
	end

	local tabs = {}
	local tx = 0
	for i, name in D.BAG.tabs do
		tabs[i] = Ui.tab(body, name, tx, 0, function()
			if tab ~= i then
				tab, top = i, 0
				unselect()
				redraw()
			end
		end)
		tx += tabs[i].width + 16
	end
	local count = Ui.text(body, "", w - BAG.countW, 0, BAG.countW, { align = "right", color = C.dim }) -- 찬 칸 / 가방의 칸
	local up = Ui.button(body, "▲", w - 36, -3, 17, function()
		top = math.max(0, top - 1)
		view.refresh()
	end, { h = 17 })
	local down = Ui.button(body, "▼", w - 17, -3, 17, function()
		top += 1
		view.refresh()
	end, { h = 17 })

	-- 고른 칸의 것으로 할 수 있는 일(상세 판의 단추 · 두 번 누르기가 같이 쓴다)
	local function wear(it)
		ctx.send("Item", "equip", it.id)
		unselect()
	end
	local function use(entry)
		ctx.send("Potion", entry.item)
	end
	-- 팔 때 묻는 것: 장비는 팔지 말지만, 묶음은 몇 개를(처음에는 전부). 팔 수 없는 것(퀘스트의 물건)은 nil
	local function sellAsk(tabKey: string, entry)
		if tabKey == "gear" then
			return { kind = "sellGear" }
		elseif Items.goodsSell(entry.item) > 0 then
			return { kind = "sell", n = entry.n }
		end
		return nil
	end

	local gridRoot = Ui.group(body, 0, GRID_Y, COLS * S, ROWS * S, "Grid")
	local cells = {}
	-- 화면의 그 자리에 있는 칸(가방의 몇째 칸인가 — 없으면 nil). 끌던 것을 놓을 때 쓴다
	local function slotAt(at: Vector2): number?
		local bag = ctx.bag()
		local i = ItemCell.at(cells, at)
		local n = if i then top * COLS + i else nil
		return if n and bag and n <= bag.size then n else nil
	end
	for i = 1, COLS * ROWS do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		local cell
		cell = ItemCell.new(gridRoot, col * S, row * S, function(it)
			local n = top * COLS + i
			local now = os.clock()
			-- 끌어서 놓은 것은 누른 것이 아니다(끌기를 끝낼 때 놓은 자리의 칸에도 "눌렀다"가 온다 — 그대로 받으면 방금 옮긴 것의 고르기가 풀린다)
			if ctx.quick.dragging() or now - dragEnd < 0.2 then
				return
			end
			local twice = it ~= nil and lastClick.slot == n and now - lastClick.t < DOUBLE
			lastClick = { slot = if twice then 0 else n, t = now }
			if not it then
				unselect()
			elseif twice then
				-- 두 번 누르기: 장비는 장착, 소비 아이템은 사용
				local me = ctx.me()
				if key() == "gear" and me and BagWindow.canWear(me, it) then
					wear(it)
				elseif key() == "use" then
					use(it)
				end
			else
				choose(key(), n, it)
			end
			redraw()
		end, S)
		cells[i] = cell
		-- 끌기: 칸의 것을 누른 채 움직이면 그림이 따라온다(ui/quickEdit.luau가 끌기를 맡는다).
		--  가방의 다른 칸 = 옮긴다 · 퀵슬롯 = 소비 아이템을 그 칸에 놓는다 · 창고 창 = 맡긴다 · 상점 창 = 팔지 묻는다
		cell.hit.InputBegan:Connect(function(input)
			local it = cell.item
			if not it then
				return
			end
			local from, tabKey = top * COLS + i, key()
			local moved = false
			ctx.quick.press(if tabKey == "use" then it.item else nil, nil, input, {
				icon = ItemCell.icon(it),
				size = S,
				onMove = function(at: Vector2)
					moved = true
					local to = slotAt(at)
					if hot ~= to then
						hot = to
						view.refresh()
					end
					if ui.storeHover then
						ui.storeHover(at, tabKey) -- 창고의 놓을 칸이 밝아진다
					end
				end,
				onDrop = function(at: Vector2): boolean
					local to = slotAt(at)
					if to and to ~= from then
						ctx.send("Item", "move", tabKey, from, to)
						-- 화면은 바로 옮긴다(서버가 가진 가방이 곧 다시 온다 — 그때 그것으로 맞춘다). 같은 묶음끼리 합치는 것은 서버의 셈을 기다린다
						local bag = ctx.bag()
						local list = if bag then bag[tabKey] else nil
						local a = if list then list[from] else nil
						local b = if list then list[to] else nil
						local merge = tabKey ~= "gear" and a and b and a.item == b.item
						if list and a and not merge then
							list[from], list[to] = b or false, a
						end
						-- 고른 것은 고른 채로 따라간다(합쳐지는 묶음이면 푼다)
						if sel and sel.tab == tabKey and (sel.slot == from or sel.slot == to) then
							if merge then
								unselect()
							else
								sel.slot = if sel.slot == from then to else from
							end
						end
					end
					if to then
						return true -- 가방의 칸에 놓았으면 여기서 끝(퀵슬롯에는 놓지 않는다)
					end
					-- 창고 창 위에 놓았다: 맡긴다(놓은 칸에 — 묶음은 전부)
					if ui.storeDrop and ui.storeDrop(at, tabKey, from) then
						if sel and sel.tab == tabKey and sel.slot == from then
							unselect()
						end
						return true
					end
					-- 상점 창 위에 놓았다: 그것을 고르고 팔지 묻는다(상세 판에 — 팔 수 없는 것이면 상세만 뜬다)
					if ui.shopDrop and ui.shopDrop(at) then
						choose(tabKey, from, it)
						ask = sellAsk(tabKey, it)
						redraw()
						return true
					end
					return false
				end,
				onEnd = function()
					if moved then
						dragEnd = os.clock()
					end
					if ui.storeHover then
						ui.storeHover(nil, nil)
					end
					if hot then
						hot = nil
						view.refresh()
					end
				end,
			})
		end)
	end

	-- 창고에서 끌어 온 것을 놓는 자리(ui/shopWindow.luau의 창고가 묻는다): 가방 창 위인가 · 그 탭의 어느 칸인가.
	--  다른 탭이 열려 있었으면 그 탭으로 넘긴다(찾은 것이 보이게)
	local panel = body.Parent :: GuiObject
	ui.bagDrop = function(at: Vector2, tabKey: string): (boolean, number?)
		if not ItemCell.over(panel, at) then
			return false, nil
		end
		local slot = if tabKey == key() then slotAt(at) else nil
		if tabKey ~= key() then
			tab, top = table.find(KEYS, tabKey) or tab, 0
			unselect()
		end
		return true, slot
	end
	-- 창고에서 「찾기」로 찾았을 때: 가방이 그 탭을 보여 준다(찾은 것이 보이게)
	ui.bagShow = function(tabKey: string)
		if tabKey ~= key() then
			tab, top = table.find(KEYS, tabKey) or tab, 0
			unselect()
		end
	end
	ui.bagHover = function(at: Vector2?, tabKey: string?)
		local to = if at and tabKey == key() then slotAt(at) else nil
		if hot ~= to then
			hot = to
			view.refresh()
		end
	end

	-- 칸 아래: 「정렬」 · 「+4칸 값」, 그 아래 지갑(달돈 · 달가루 · 정수)
	local fy = GRID_Y + ROWS * S + BAG.footY
	local sort = Ui.button(body, WORDS.sort, 0, fy, BAG.sortW, function()
		ctx.send("Item", "sort", key())
		unselect()
		view.refresh()
	end)
	sort.frame.Name = "Sort"
	local grow = Ui.button(body, "", w - BAG.growW, fy, BAG.growW, function()
		ctx.send("Item", "grow")
	end, { font = "small" })
	grow.frame.Name = "Grow"
	Ui.line(body, 0, fy + BAG.purseY - 5, w)
	local pw = Layout.purseW(w)
	local money = purse(body, "coin", -3, fy + BAG.purseY, pw)
	local dust = purse(body, "dust", pw - 3, fy + BAG.purseY, pw)
	local essence = purse(body, "orb", pw * 2 - 3, fy + BAG.purseY, pw)

	-- 고른 것의 상세 판(창 옆)
	local function detail(bag, me)
		if ui.detail ~= "bag" then
			unselect() -- 다른 창에서 골랐다
		end
		local entry = if sel then bag[sel.tab][sel.slot] else nil
		if sel and sel.tab == "gear" and (not entry or entry.id ~= sel.id) then
			-- 고른 장비가 다른 칸으로 갔으면(정렬 · 옮기기) 따라간다
			entry = nil
			for i = 1, bag.size do
				local it = bag.gear[i]
				if it and it.id == sel.id then
					sel.slot, entry = i, it
					break
				end
			end
		elseif sel and sel.tab ~= "gear" and entry and entry.item ~= sel.id then
			entry = nil -- 그 칸에 다른 것이 놓였다(정렬 · 옮기기)
		end
		if not sel or not entry then
			unselect()
			ItemDetail.hide("bag")
			return
		end
		local slot, tabKey, service = sel.slot, sel.tab, ui.service
		local spec = { item = entry, buttons = {}, onClose = function()
			unselect()
			redraw()
		end }
		local function button(text: string, onClick: () -> (), main: boolean?, off: boolean?)
			table.insert(spec.buttons, { text = text, main = main, off = off, onClick = onClick })
		end
		local function stopAsk()
			ask = nil
			view.refresh()
		end
		if tabKey == "gear" then
			local it = entry
			local worn = bag.equip[it.slot]
			local can = BagWindow.canWear(me, it)
			spec.info = ItemInfo.gear(it, me, worn, false)
			if ask and ask.kind == "sellGear" then
				spec.ask = ItemDetail.ask("sellGear", nil, 1, 1, {
					gain = function()
						return Items.sellPrice(it)
					end,
					yes = function()
						ctx.send("Item", "sell", "gear", slot)
						unselect()
						redraw()
					end,
					no = stopAsk,
				})
			else
				ask = nil
				button(WORDS.equip, function()
					wear(it)
					redraw()
				end, true, not can)
				button(WORDS.dismantle, function()
					ctx.send("Item", "dismantle", it.id)
					unselect()
					redraw()
				end)
				if service == "store" then
					button(WORDS.toStore, function()
						ctx.send("Item", "storeIn", "gear", slot)
						if ui.storeShow then
							ui.storeShow("gear") -- 창고가 그 탭을 보여 준다(맡긴 것이 보이게)
						end
						unselect()
						redraw()
					end)
				elseif service == "forge" then
					button(WORDS.toForge, function()
						ctx.toForge(it.id)
					end)
				elseif service == "shop" then
					button(WORDS.sell, function()
						ask = { kind = "sellGear" }
						view.refresh()
					end)
				end
			end
			spec.key = table.concat({ "gear", it.id, it.q, it.star, tostring(it.broken), me.level, if worn then worn.id else 0, if worn then worn.star else 0, service or "-", tostring(can), if ask then ask.kind else "-" }, "|")
		else
			local def = Items.goods(entry.item)
			local have = Bag.countIn(bag, entry.item)
			spec.info = ItemInfo.goods(entry.item, me, have)
			if ask and ask.n then
				-- 수를 고른다: 버리기 · 맡기기 · 팔기는 1 ~ 그 칸의 수, 나누기는 1 ~ 하나를 남긴 수
				local kind = ask.kind
				local hi = if kind == "split" then entry.n - 1 else entry.n
				if hi < 1 then
					ask = nil
				else
					local n = math.clamp(ask.n, 1, hi)
					ask.n = n
					spec.ask = ItemDetail.ask(kind, n, 1, hi, {
						gain = if kind == "sell" then function(count: number)
							return def.sell * count
						end else nil,
						set = function(v: number)
							ask = { kind = kind, n = v }
							view.refresh()
						end,
						yes = function(count: number)
							local action = if kind == "store" then "storeIn" else kind -- "discard" · "sell" · "split"
							ctx.send("Item", action, tabKey, slot, count)
							if kind == "store" and ui.storeShow then
								ui.storeShow(tabKey)
							end
							ask = nil
							redraw()
						end,
						no = stopAsk,
					})
				end
			else
				ask = nil
			end
			if not ask then
				if tabKey == "use" then
					button(WORDS.use, function()
						use(entry)
					end, true, def.lv ~= false and me.level < def.lv)
					button(WORDS.quick, function()
						ctx.quick.pick(entry.item) -- 퀵슬롯(스마트폰: 칸 단추)이 반짝인다 — 놓을 칸을 누른다
					end)
				end
				button(WORDS.discard, function()
					ask = { kind = "discard", n = entry.n } -- 처음에는 그 칸의 묶음 전부
					view.refresh()
				end)
				if entry.n > 1 then
					button(WORDS.split, function()
						ask = { kind = "split", n = math.floor(entry.n / 2) } -- 처음에는 절반
						view.refresh()
					end)
				end
				if service == "store" then
					button(WORDS.toStore, function()
						if entry.n == 1 then
							ctx.send("Item", "storeIn", tabKey, slot, 1)
							if ui.storeShow then
								ui.storeShow(tabKey)
							end
							unselect()
							redraw()
						else
							ask = { kind = "store", n = entry.n }
							view.refresh()
						end
					end)
				elseif service == "shop" and def.sell > 0 then
					button(WORDS.sell, function()
						ask = { kind = "sell", n = entry.n }
						view.refresh()
					end)
				end
			end
			spec.key = table.concat({ tabKey, slot, entry.item, entry.n, have, me.level, service or "-", if ask then ask.kind .. (ask.n or "") else "-" }, "|")
		end
		ItemDetail.show("bag", spec)
	end

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		for i, button in tabs do
			button:setOn(i == tab)
		end
		local list = bag[key()]
		-- 줄 넘기기: 늘린 가방은 네 줄을 넘는다
		local rows = math.ceil(bag.size / COLS)
		top = math.clamp(top, 0, math.max(0, rows - ROWS))
		local scroll = rows > ROWS
		up.frame.Visible = scroll
		down.frame.Visible = scroll
		up:setEnabled(top > 0)
		down:setEnabled(top < rows - ROWS)
		count:move(if scroll then w - BAG.countW - BAG.scrollW - 4 else w - BAG.countW, 0)
		local used = 0
		for i = 1, bag.size do
			if list[i] then
				used += 1
			end
		end
		count:set(("%d / %d"):format(used, bag.size))
		detail(bag, me) -- 고른 것이 사라졌으면 여기서 풀린다
		for i, cell in cells do
			local at = top * COLS + i
			local item = list[at] or nil
			cell:set(item, { locked = at > bag.size, selected = sel ~= nil and sel.tab == key() and sel.slot == at, hot = hot == at })
		end
		-- 가방 늘리기(세 탭이 함께 늘어난다 — 값이 적혀 있다). 다 늘렸으면 단추가 없다
		grow.frame.Visible = bag.growCost ~= false
		if bag.growCost ~= false then
			grow:setText(BagWindow.growText(bag.growCost))
			grow:setEnabled(me.money >= bag.growCost)
		end
		sort:setEnabled(used > 1)
		money:set(Format.short(me.money))
		dust:set(Format.short(bag.dust))
		essence:set(Format.short(bag.essence))
	end

	function view.destroy()
		ItemDetail.hide("bag")
		if ui.detail == "bag" then
			ui.detail = nil
		end
		ui.bagDrop, ui.bagHover, ui.bagShow = nil, nil, nil
	end
	return view
end

return BagWindow
