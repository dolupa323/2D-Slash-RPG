-- 가방 창 — 탭 셋(장비 · 쓰는 것 · 재료). 장비 탭은 밝은 판 위의 칸(여덟 칸 x 세 줄이 보인다 — 48칸까지 늘리면 ▲▼로 줄을 넘긴다)에
--  장비의 아이콘이 놓이고, 고르면 아래에 이름 · 성능 · 끼면 달라지는 전투력이 뜬다.
--  단추: 끼기 · 분해 · (옆에 열린 창에 따라) 올리기(강화) / 맡기기(창고) / 칸 늘리기. 끼기 · 분해는 서버에 부탁한다(Item).
--  달돈 · 달가루는 칸을 차지하지 않는다 — 창 아래의 어두운 칸에 숫자로(공방 「돈 · 상점」 탭의 가방 규칙).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local N = require(lune.config.numbers)
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Kit = require(script.Parent.kit)
local ItemCell = require(script.Parent.itemCell)

local C = Kit.COLOR
local D = Items.data
local COLS, ROWS, S = 8, 3, ItemCell.SIZE

local BagWindow = { height = 152 }
BagWindow.COLS, BagWindow.ROWS = COLS, ROWS
BagWindow.GROW_W = 58 -- 「+4칸 16만」이 들어가는 단추의 폭(테스트 15가 본다)

-- 가방의 장비를 끼면 전투력이 얼마나 달라지나(끼고 있는 같은 부위와 견주어)
function BagWindow.powerDiff(bag, it): number
	local old = bag.equip[it.slot]
	local diff = Items.score(it) - (if old then Items.score(old) else 0)
	local P = N.data.POWER
	return math.floor(P.base * P.itemShare * diff / D.WSUM + (if diff >= 0 then 0.5 else -0.5))
end

-- 고른 장비 아래에 적는 한 줄(폭 166에 들어가야 한다 — 테스트 15가 본다)
function BagWindow.detail(bag, me, it): string
	if it.broken then
		return "부서졌다 — 같은 장비로 되살린다"
	elseif it.slot == "weapon" and it.who ~= me.class then
		return "다른 직업의 무기"
	elseif me.level < Items.needLevel(it) then
		return ("Lv.%d부터 낀다"):format(Items.needLevel(it))
	end
	local diff = BagWindow.powerDiff(bag, it)
	local bonus = D.QUALITY[it.q].bonus
	local text = ("끼면 전투력 %s%s"):format(if diff >= 0 then "+" else "-", Format.short(math.abs(diff)))
	if bonus ~= 0 then
		text = ("성능 %s%d%% · %s"):format(if bonus > 0 then "+" else "", bonus, text)
	end
	return text
end

-- 가방을 늘리는 단추의 글
function BagWindow.growText(cost: number): string
	return ("+4칸 %s"):format(Format.short(cost))
end

-- 어두운 칸에 아이콘과 숫자(달돈 · 달가루)
local function purse(parent: Instance, icon: string, x: number, y: number, w: number)
	Kit.part(parent, "field", x, y, w, 13)
	Kit.icon(parent, icon, x - 1, y - 3).ZIndex = 2
	return Kit.text(parent, "", x + 18, y + 2, w - 22, { align = "right" })
end
BagWindow.purse = purse

function BagWindow.build(body: Frame, ctx, w: number, _h: number)
	local ui = ctx.ui
	local tab = 1
	local top = 0 -- 맨 윗줄이 몇째 줄인가(가방을 늘린 뒤 ▲▼로 넘긴다)
	local selected: number? = nil
	local view = {}

	local tabs = {}
	local tx = 2
	for i, name in D.BAG.tabs do
		local tw = Kit.measure(name) + 10
		tabs[i] = Kit.tab(body, name, tx, 0, tw, function()
			tab = i
			view.refresh()
		end)
		tx += tw + 1
	end
	local count = Kit.text(body, "", w - 64, 2, 30, { align = "right", color = C.dim })
	local up = Kit.button(body, "▲", w - 31, 0, 14, 12, function()
		top = math.max(0, top - 1)
		view.refresh()
	end)
	local down = Kit.button(body, "▼", w - 16, 0, 14, 12, function()
		top += 1
		view.refresh()
	end)

	local gw, gh = COLS * S + 6, ROWS * S + 6
	local paper = Kit.group(body, 2, 12, gw, gh)
	Kit.part(paper, "paper", 0, 0, gw, gh)
	local gridRoot = Kit.group(paper, 3, 3, COLS * S, ROWS * S)
	local cells = {}
	for i = 1, COLS * ROWS do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		cells[i] = ItemCell.new(gridRoot, col * S, row * S, function(it)
			selected = if it then it.id else nil
			view.refresh()
		end)
	end
	-- 쓰는 것 · 재료 탭: 아이콘과 글 한 줄씩
	local listRoot = Kit.group(paper, 3, 3, COLS * S, ROWS * S)
	local lines = {}
	for i = 1, 3 do
		lines[i] = { icon = Kit.icon(listRoot, nil, 1, 1 + (i - 1) * S), text = Kit.text(listRoot, "", 23, 6 + (i - 1) * S, COLS * S - 26, { color = C.ink }) }
	end

	local name = Kit.text(body, "", 4, 81, w - 8)
	local detail = Kit.text(body, "", 4, 92, w - 8, { color = C.dim })
	local function pick(): any
		local bag = ctx.bag()
		if not bag or not selected then
			return nil
		end
		for _, it in bag.gear do
			if it.id == selected then
				return it
			end
		end
		return nil
	end
	local wear = Kit.button(body, "끼기", 2, 105, 52, 14, function()
		local it = pick()
		if it then
			ctx.send("Item", "equip", it.id)
		end
	end, { kind = "orange" })
	local apart = Kit.button(body, "분해", 56, 105, 52, 14, function()
		local it = pick()
		if it then
			ctx.send("Item", "dismantle", it.id)
			selected = nil
		end
	end)
	local extra = Kit.button(body, "", 110, 105, BagWindow.GROW_W, 14, function()
		local it = pick()
		if not it then
			return
		end
		if ui.service == "store" then
			ctx.send("Item", "storeIn", it.id)
			selected = nil
		elseif ui.service == "forge" then
			ctx.toForge(it.id)
		end
	end)
	local grow = Kit.button(body, "", 110, 105, BagWindow.GROW_W, 14, function()
		ctx.send("Item", "grow")
	end)
	local money = purse(body, "coin", 3, 121, 82)
	local dust = purse(body, "dust", 88, 121, 80)

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		for i, button in tabs do
			button:setOn(i == tab)
		end
		gridRoot.Visible = tab == 1
		listRoot.Visible = tab ~= 1
		local it = if tab == 1 then pick() else nil
		-- 줄 넘기기: 늘린 가방은 세 줄을 넘는다
		local rows = math.ceil(bag.size / COLS)
		top = math.clamp(top, 0, math.max(0, rows - ROWS))
		up.frame.Visible = tab == 1 and rows > ROWS
		down.frame.Visible = tab == 1 and rows > ROWS
		up:setEnabled(top > 0)
		down:setEnabled(top < rows - ROWS)
		if tab == 1 then
			count:set(("%d/%d"):format(#bag.gear, bag.size))
			for i, cell in cells do
				local at = top * COLS + i
				local item = bag.gear[at]
				cell:set(item, { locked = at > bag.size, selected = item ~= nil and item.id == selected })
			end
		else
			count:set("")
			local rowsOf = {}
			if tab == 2 then
				table.insert(rowsOf, { "potion_s", ("%s %d병"):format(N.potionAt(me.level).name, me.potions) })
			else
				table.insert(rowsOf, { "dust", ("달가루 %s"):format(Format.short(bag.dust)) })
				table.insert(rowsOf, { "orb", ("보스의 정수 %s"):format(Format.short(bag.essence)) })
			end
			for i, line in lines do
				local row = rowsOf[i]
				Kit.setIcon(line.icon, if row then row[1] else nil)
				line.text:set(if row then row[2] else "")
			end
		end
		-- 고른 장비
		if it then
			name:set(ItemCell.label(it))
			name:color(ItemCell.color(it))
			detail:set(BagWindow.detail(bag, me, it))
		else
			name:set(if tab == 1 then "장비를 고른다" else "")
			name:color(C.dim)
			detail:set("")
		end
		local canWear = it ~= nil and not it.broken and (it.slot ~= "weapon" or it.who == me.class) and me.level >= Items.needLevel(it)
		wear:setEnabled(canWear)
		apart:setEnabled(it ~= nil)
		wear.frame.Visible = tab == 1
		apart.frame.Visible = tab == 1
		-- 셋째 단추: 옆에 열린 창에 따라 달라진다. 아무것도 없으면 가방 늘리기(값이 적혀 있다)
		local service = ui.service
		local useExtra = tab == 1 and (service == "store" or service == "forge")
		extra.frame.Visible = useExtra
		grow.frame.Visible = tab == 1 and not useExtra and bag.growCost ~= false
		if useExtra then
			extra:setText(if service == "store" then "맡기기" else "올리기")
			extra:setEnabled(it ~= nil)
		elseif bag.growCost ~= false then
			grow:setText(BagWindow.growText(bag.growCost))
			grow:setEnabled(me.money >= bag.growCost)
		end
		money:set(Format.short(me.money))
		dust:set(Format.short(bag.dust))
	end
	return view
end

return BagWindow
