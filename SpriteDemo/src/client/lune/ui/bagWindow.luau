-- 가방 창 — 화면 오른쪽의 옆 판(승인된 시안 hd_bag — 던그리드의 가방처럼). 탭 셋(장비 · 쓰는 것 · 재료).
--  장비 탭은 칸 여섯 x 넷(48칸까지 늘리면 ▲▼로 줄을 넘긴다)에 장비의 그림이 놓이고, 고르면 아래에 이름(글자색 = 등급) · 성능 · 끼면 달라지는 전투력이 뜬다.
--  단추: 장착(사용자 2026-10-07: "끼기 가 아니라 장착입니다") · 분해 · (옆에 열린 창에 따라) 올리기(강화) / 맡기기(창고) / 칸 늘리기. 장착 · 분해는 서버에 부탁한다(Item).
--  달돈 · 달가루는 칸을 차지하지 않는다 — 창 아래에 그림과 숫자로(공방 「돈 · 상점」 탭의 가방 규칙).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local N = require(lune.config.numbers)
local Quests = require(lune.sim.quests)
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local WORDS = require(lune.data["ui.generated"]).words -- 낱말(장착 …) — 공방에서 정한 것
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)

local C = Ui.COLOR
local D = Items.data
local BAG = Layout.BAG
local COLS, ROWS = BAG.cols, BAG.rows
local GRID_Y = BAG.gridY -- 칸들의 윗줄

local BagWindow = { side = "right" } -- 가방은 늘 오른쪽에 뜬다(같이 열린 창은 왼쪽으로 간다)
BagWindow.COLS, BagWindow.ROWS = COLS, ROWS

function BagWindow.size(): (number, number)
	return Layout.bagBody(Stage.ratio)
end

-- 가방의 장비를 끼면 전투력이 얼마나 달라지나(끼고 있는 같은 부위와 견주어)
function BagWindow.powerDiff(bag, it): number
	local old = bag.equip[it.slot]
	local diff = Items.score(it) - (if old then Items.score(old) else 0)
	local P = N.data.POWER
	return math.floor(P.base * P.itemShare * diff / D.WSUM + (if diff >= 0 then 0.5 else -0.5))
end

-- 고른 장비 아래에 적는 한 줄
function BagWindow.detail(bag, me, it): string
	if it.broken then
		return "부서졌다 — 같은 장비로 되살린다"
	elseif it.slot == "weapon" and it.who ~= me.class then
		return "다른 직업의 무기"
	elseif me.level < Items.needLevel(it) then
		return ("Lv.%d부터 %s"):format(Items.needLevel(it), WORDS.equip)
	end
	local diff = BagWindow.powerDiff(bag, it)
	local bonus = D.QUALITY[it.q].bonus
	local text = ("%s 전투력 %s%s"):format(WORDS.equipIf, if diff >= 0 then "+" else "-", Format.short(math.abs(diff)))
	if bonus ~= 0 then
		text = ("성능 %s%d%% · %s"):format(if bonus > 0 then "+" else "", bonus, text)
	end
	return text
end

-- 가방을 늘리는 단추의 글
function BagWindow.growText(cost: number): string
	return ("+4칸 %s"):format(Format.short(cost))
end

-- 그림과 숫자(달돈 · 달가루). (x, y) = 그림의 왼쪽 위 — 숫자는 그 오른쪽에
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
	local selected: number? = nil
	local view = {}

	local tabs = {}
	local tx = 0
	for i, name in D.BAG.tabs do
		tabs[i] = Ui.tab(body, name, tx, 0, function()
			tab = i
			view.refresh()
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

	local gridRoot = Ui.group(body, 0, GRID_Y, COLS * S, ROWS * S, "Grid")
	local cells = {}
	for i = 1, COLS * ROWS do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		cells[i] = ItemCell.new(gridRoot, col * S, row * S, function(it)
			selected = if it then it.id else nil
			view.refresh()
		end, S)
	end
	-- 쓰는 것 · 재료 탭: 두 단으로 — 칸에 그림, 그 옆에 이름과 개수. 재료 탭에는 지금 모으는 퀘스트의 물건이 먼저 나온다
	--  (사용자 2026-10-07: "퀘스트 아이템이나 , 기타아이템들은 왜 … 그림도없고 그냥 텍스트로만 오르나요?" — 주운 물건을 가방에서 그림과 함께 본다)
	local listRoot = Ui.group(body, 0, GRID_Y, COLS * S, ROWS * S, "List")
	local lines = {}
	local half = math.floor(COLS * S / 2)
	for i = 1, ROWS * 2 do
		local holder = Ui.group(listRoot, ((i - 1) % 2) * half, ((i - 1) // 2) * S, half, S, "Item" .. i)
		Ui.slot(holder, 0, 0, S)
		lines[i] = {
			frame = holder,
			icon = Ui.worldIcon(holder, nil, 0, 0, S),
			name = Ui.text(holder, "", S + 8, math.floor(S / 2) - 12, half - S - 10, {}),
			count = Ui.text(holder, "", S + 8, math.floor(S / 2) + 2, half - S - 10, { color = C.gold }),
			what = nil :: string?, -- 퀵슬롯에 놓을 수 있는 것이면 그 이름("potion")
		}
		-- 소비 아이템은 끌어다 퀵슬롯에 놓는다(누르면 칸들이 반짝이고 칸을 눌러 놓아도 된다) — ui/quickEdit.luau
		local line = lines[i]
		local grab = Instance.new("TextButton")
		grab.Name = "Grab"
		grab.Text = ""
		grab.BackgroundTransparency = 1
		grab.Size = UDim2.fromOffset(half, S)
		grab.ZIndex = 6
		grab.Parent = holder
		grab.InputBegan:Connect(function(input)
			if line.what then
				ctx.quick.press(line.what, nil, input)
			end
		end)
		grab.Activated:Connect(function()
			if line.what then
				ctx.quick.pick(line.what)
			end
		end)
	end

	local iy = GRID_Y + ROWS * S + 12
	local name = Ui.text(body, "", 0, iy, w, { font = "body" })
	local detail = Ui.text(body, "", 0, iy + 20, w)
	local need = Ui.text(body, "", 0, iy + 34, w, { color = C.dim })
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
	local by = iy + 54
	local bw = Layout.bagButtonW(w) -- 단추 셋이 같은 폭
	local wear = Ui.button(body, WORDS.equip, 0, by, bw, function()
		local it = pick()
		if it then
			ctx.send("Item", "equip", it.id)
		end
	end, { main = true })
	wear.frame.Name = "Wear"
	local apart = Ui.button(body, "분해", bw + BAG.gap, by, bw, function()
		local it = pick()
		if it then
			ctx.send("Item", "dismantle", it.id)
			selected = nil
		end
	end)
	apart.frame.Name = "Apart"
	local restX, restW = (bw + BAG.gap) * 2, w - (bw + BAG.gap) * 2
	local extra = Ui.button(body, "", restX, by, restW, function()
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
	extra.frame.Name = "Extra"
	local grow = Ui.button(body, "", restX, by, restW, function()
		ctx.send("Item", "grow")
	end, { font = "small" })
	grow.frame.Name = "Grow"
	Ui.line(body, 0, by + 34, w)
	local money = purse(body, "coin", -3, by + 39, 90)
	local dust = purse(body, "dust", 96, by + 39, 90)

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
		-- 줄 넘기기: 늘린 가방은 네 줄을 넘는다
		local rows = math.ceil(bag.size / COLS)
		top = math.clamp(top, 0, math.max(0, rows - ROWS))
		local scroll = tab == 1 and rows > ROWS
		up.frame.Visible = scroll
		down.frame.Visible = scroll
		up:setEnabled(top > 0)
		down:setEnabled(top < rows - ROWS)
		count:move(if scroll then w - BAG.countW - BAG.scrollW - 4 else w - BAG.countW, 0)
		if tab == 1 then
			count:set(("%d / %d"):format(#bag.gear, bag.size))
			for i, cell in cells do
				local at = top * COLS + i
				local item = bag.gear[at]
				cell:set(item, { locked = at > bag.size, selected = item ~= nil and item.id == selected })
			end
		else
			count:set("")
			local rowsOf = {}
			if tab == 2 then
				table.insert(rowsOf, { "potion_s", N.potionAt(me.level).name, ("%d병"):format(me.potions), "potion" })
			else
				-- 지금 모으는 퀘스트의 물건(가진 수 / 모을 수), 그 뒤에 달가루 · 보스의 정수
				for _, q in Quests.items(ctx.quests() or {}) do
					table.insert(rowsOf, { q.icon, q.name, ("%d / %d"):format(q.have, q.n) })
				end
				table.insert(rowsOf, { "dust", "달가루", Format.short(bag.dust) })
				table.insert(rowsOf, { "orb", "보스의 정수", Format.short(bag.essence) })
			end
			for i, line in lines do
				local row = rowsOf[i]
				line.frame.Visible = row ~= nil
				line.what = if row then row[4] else nil
				if row then
					Ui.setWorldIcon(line.icon, row[1])
					line.name:set(row[2])
					line.count:set(row[3])
				end
			end
		end
		-- 고른 장비
		if it then
			name:set(ItemCell.label(it))
			name:color(ItemCell.color(it))
			detail:set(BagWindow.detail(bag, me, it))
			local slot = Items.slot(it.slot)
			need:set(("Lv.%d부터 · %s"):format(Items.needLevel(it), if slot then slot.name else ""))
		else
			name:set(if tab == 1 then "장비를 고른다" else "")
			name:color(C.dim)
			detail:set("")
			need:set("")
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
