-- 대장장이 창 — 대장장이 무쇠뿔에게 말을 걸면 가방과 나란히 뜬다. 탭 둘: 「제작」 · 「강화」.
--  사용자 2026-10-15: "대장장이에 상점이 있는게 문제임 상점 없어야함 제작, 강화만 하는곳임" · "강화에 드래그앤 드랍으로 둘수가 없음" ·
--   "제작 리스트에서 아이템 아이콘쪽 누르면 아이템 옵션이 나와야함 인벤토리에서 처럼" · "강화를 인벤토리에 있는것만 강화할수있음 장착중인건 바로 강화할수가 없음" ·
--   "별을 옮겨올 장비는 뭐에요 … 이거 없애고" · "강화가 아무런 연출없이 그냥 띡띡띡띢 이렇게 되면 안됩니다." · "아이템 이름 위에 별이 표기되는겁니다."
--  제작: 단계 탭(Lv.1 · 10 · 20) · 장비마다 한 줄([그림] 이름 · [달돈] 삯 · 「제작」 / 아랫줄 재료 둘). 그림을 누르면 창 옆에 그 장비의 상세 판(옵션 · 만들면 나오는 성능의 확률).
--  강화: 위 = 올린 장비(칸 · 그 오른쪽에 별 그림 두 줄과 이름) / 「★5 → ★6」과 성공 % · 오르는 옵션(「공격력 73 → 76」) · 실패하면 · [달가루] 드는 것 · 「파괴 방지」 · 「강화」 · 결과.
--        아래 = 고를 장비(스크롤): 첫 줄은 장착 중인 것(「장착」 표시 — 장비 창을 따로 열지 않아도 된다), 그 아래는 가방의 장비. 칸을 누르거나, 가방 창의 장비를 끌어다 이 창에 놓으면 올라간다.
--        부서진 장비를 올리면 「되살리기」 — 같은 장비를 하나 더 고른다(칸을 누른다).
--  강화 연출: 「강화」를 누르면 망치가 세 번 내려치고(칸이 번쩍이며 흔들리고 불티가 튄다) 결과가 뜬다 —
--   성공 = 금빛 테두리가 퍼지고 「강화 성공」 · 실패 = 「강화 실패」 · 떨어짐 = 붉게 「별이 하나 떨어졌다」 · 파괴 = 붉게 크게 흔들리며 「장비가 파괴되었다」.
--   그동안 단추는 잠기고, 올린 장비의 별은 결과가 뜰 때 바뀐다(서버는 바로 정한다 — 화면만 기다린다). 칸을 누르면 건너뛴다.
--  확률과 값은 shared/lune/sim/items.luau의 enhanceInfo, 오르는 옵션은 Items.options. 결과는 서버가 정한다(Item → ItemDone). 화면 왼쪽의 옆 판(ui/windows.luau — 가방이 오른쪽).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local ItemInfo = require(lune.ui.itemInfo)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local ItemDetail = require(script.Parent.itemDetail)

local C = Ui.COLOR
local D = Items.data
local W = 300
local CRAFT = Layout.CRAFT
local IC = Layout.SHOP.iconS -- 제작 줄의 그림 칸
local TX = IC + 6
local LINE = 16
local COST = 20

local ForgeWindow = {}
ForgeWindow.W = W
ForgeWindow.TABS = { { "craft", "제작" }, { "enhance", "강화" } }
ForgeWindow.COST, ForgeWindow.LINE = COST, LINE
-- 결과의 글과 색(연출이 끝난 뒤 결과 줄에 남는다)
ForgeWindow.RESULT = {
	ok = { "강화 성공 — 별이 하나 켜졌다", C.gold },
	fail = { "강화 실패 — 별은 그대로다", C.dim },
	drop = { "강화 실패 — 별이 하나 떨어졌다", C.red },
	boom = { "장비가 파괴되었다 — 흔적이 남았다", C.red },
	restore = { "되살렸다 — 12성", C.accent }, -- 부서진 장비를 같은 장비로 되살렸다(연출 없이 바로)
}
ForgeWindow.BIG = { ok = { "강화 성공", C.gold }, fail = { "강화 실패", C.text }, drop = { "강화 실패", C.red }, boom = { "파괴", C.red } } -- 칸 위에 크게
ForgeWindow.STRIKES = { 0.05, 0.4, 0.75 } -- 망치가 내려치는 때(초)
ForgeWindow.REVEAL = 1.05 -- 결과를 보이는 때(서버의 답이 늦으면 그때까지 기다린다)
ForgeWindow.END = 1.9 -- 연출이 끝나는 때
ForgeWindow.CRAFT_ROW, ForgeWindow.CRAFT_MATS = CRAFT.row, 2
ForgeWindow.CRAFT_MAKE_W, ForgeWindow.CRAFT_FEE_W = CRAFT.makeW, CRAFT.feeW

-- 몸의 크기(제작 · 강화가 같은 크기 — 탭을 바꿔도 창이 흔들리지 않는다)
-- 창의 제목 = 연 대장장이(「대장장이 담금」 — boot.luau가 연 때마다 적는다. 없으면 공방의 이름 「대장장이 무쇠뿔」). 2026-10-16: 은달 항구에도 대장장이가 생겼다
ForgeWindow.opener = nil :: string?
function ForgeWindow.title(_arg: any): string?
	return ForgeWindow.opener
end

function ForgeWindow.size(): (number, number)
	local S = ItemCell.size()
	return W, 24 + S + 4 + 3 * LINE + 4 + COST + 6 + Ui.M.button + 4 + LINE + 8 + 14 + 2 * S
end

local function pct(v: number): string
	return if v == math.floor(v) then ("%d%%"):format(v) else ("%.1f%%"):format(v)
end
ForgeWindow.pct = pct

-- 오르는 옵션의 글: 「공격력 73 → 76 (+3)」 · 방어구는 「올스탯 9 → 10 · 방어력 16 → 17」. it = 지금 장비
function ForgeWindow.gainText(it): string
	local now = Items.options(it).total
	local nextIt = table.clone(it)
	nextIt.star = it.star + 1
	local after = Items.options(nextIt).total
	local W2 = D.WORDS
	local parts = {}
	for _, k in ItemInfo.ORDER do
		if now[k] ~= nil then
			local d = after[k] - now[k]
			table.insert(parts, ("%s %s → %s%s"):format(W2[k], Format.short(now[k]), Format.short(after[k]), if d > 0 and k == "atk" then (" (+%s)"):format(Format.short(d)) else ""))
		end
	end
	return table.concat(parts, " · ")
end

-- 강화 칸에 적는 줄들(화면 없이 셈할 수 있게 따로 뺐다): { 별 · 확률(오른쪽), 오르는 옵션, 실패하면, 드는 달가루 }
function ForgeWindow.lines(it, info, bag): { string }
	if it.broken then
		return { "부서진 장비", "", "같은 장비를 하나 더 골라 「되살리기」(12성으로)", "" }
	elseif not info.can then
		return { ("★%d — 가장 높은 별이다"):format(it.star), "", "", "" }
	end
	local odds = if info.sure then "반드시 성공" else ("성공 %s"):format(pct(info.ok))
	local note = if info.first then "첫 강화 — 달가루 없이 반드시 붙는다"
		elseif info.sure then "두 번 떨어졌다 — 이번은 반드시 붙는다"
		elseif info.drops then ("실패하면 한 단계 떨어진다%s"):format(if info.boom > 0 then (" · 파괴 %s"):format(pct(info.boom)) else "")
		else "실패해도 별은 그대로다"
	return {
		("★%d → ★%d  %s"):format(it.star, it.star + 1, odds),
		ForgeWindow.gainText(it),
		note,
		("달가루 %s (가진 것 %s)"):format(Format.short(info.dust), Format.short(bag.dust)),
	}
end

-- 고를 장비의 목록: 장착 중인 것(부위 차례) · 그 다음 가방의 장비(칸 차례). { { it, worn } … }
function ForgeWindow.choices(bag)
	local out = {}
	for _, s in D.SLOTS do
		local it = bag.equip[s.id]
		if it then
			table.insert(out, { it = it, worn = true })
		end
	end
	for i = 1, #bag.gear do
		local it = bag.gear[i]
		if it then
			table.insert(out, { it = it, worn = false })
		end
	end
	return out
end

-- 가방(장착하지 않은 것)에 있는가 — 되살리기의 재료는 가방의 것만 받는다(서버의 Bag.restore와 같다 — 2026-10-18 검토)
local function inGear(bag, id: number?): boolean
	if not bag or not id then
		return false
	end
	for _, it in bag.gear do
		if it and it.id == id then
			return true
		end
	end
	return false
end

local function findIn(bag, id: number?)
	if not bag or not id then
		return nil
	end
	for _, it in bag.equip do
		if it.id == id then
			return it
		end
	end
	for _, it in bag.gear do
		if it and it.id == id then
			return it
		end
	end
	return nil
end
ForgeWindow.find = findIn

-- 제작 줄의 재료들 { { icon, text 「청동 광석 3/5」, ok } … } 와 다 모였는가
function ForgeWindow.craftParts(recipe, bag)
	local parts, enough = {}, true
	for _, need in recipe.needs do
		local have = Bag.countIn(bag, need.item)
		local g = Items.goods(need.item)
		table.insert(parts, { icon = g.icon, text = ("%s %d/%d"):format(g.name, math.min(have, 9999), need.n), ok = have >= need.n })
		enough = enough and have >= need.n
	end
	return parts, enough
end

-- 제작 줄의 상세 판: 보통 성능의 것으로 옵션을 보이고, 만들면 나오는 성능의 확률을 앞에 적는다
function ForgeWindow.craftInfo(recipe, me, bag)
	local item = Items.make(recipe.slot, recipe.stage, D.NORMAL, me.class)
	local info = ItemInfo.gear(item, { level = me.level, class = me.class, spec = me.spec }, bag and bag.equip[recipe.slot] or nil, false)
	local total = 0
	for _, x in D.CRAFTQ do
		total += x.pct
	end
	local odds = {}
	for _, x in D.CRAFTQ do
		table.insert(odds, ("%s %d%%"):format(D.QUALITY[x.q].name, math.floor(x.pct / total * 100 + 0.5)))
	end
	-- 만들기 전의 장비라 「분해하면 · 팔면」은 빼고 「만들면 성능: 보통 57% · 좋은 31% · 빼어난 11%」를 맨 앞에
	local notes = { { "만들면 성능: " .. table.concat(odds, " · "), "accent" } }
	for _, n in info.notes do
		if n[2] ~= "dim" then
			table.insert(notes, n)
		end
	end
	info.notes = notes
	return info, item
end

function ForgeWindow.build(body: Frame, ctx, w: number, h: number, arg: any)
	local ui = ctx.ui
	local S = ItemCell.size()
	local view = {}
	local panel = body.Parent :: GuiObject
	local tab = if arg == "craft" or arg == "enhance" then arg else "enhance"
	local guard = false
	local anim = nil -- 강화 연출 { t, seq(누를 때의 결과 번호), snap(누르기 전의 장비), id, revealed, result }
	local bound = false
	local craftTab = 1

	-- ---- 위: 탭 둘 · 지갑 ----
	local tabs = {}
	local tx = 0
	for i, t in ForgeWindow.TABS do
		tabs[i] = Ui.tab(body, t[2], tx, 2, function()
			if tab ~= t[1] then
				tab = t[1]
				ItemDetail.hide("forge")
				view.refresh()
			end
		end)
		tabs[i].frame.Name = "Tab_" .. t[1]
		tx += tabs[i].width + 16
	end
	local dustIcon = Ui.smallIcon(body, "dust", w - 72, -2)
	local dustText = Ui.text(body, "", w - 52, 2, 52, { align = "right", color = C.text })
	local coinIcon = Ui.smallIcon(body, "coin", w - 156, -2)
	local coinText = Ui.text(body, "", w - 136, 2, 60, { align = "right", color = C.gold })

	-- ---- 제작 ----
	local craftRoot = Ui.group(body, 0, 0, w, h, "Craft")
	local stages = {}
	for _, r in D.RECIPES do
		if not table.find(stages, r.stage) then
			table.insert(stages, r.stage)
		end
	end
	table.sort(stages)
	local me0 = ctx.me()
	for i, st in stages do
		if me0 and me0.level >= st then
			craftTab = i
		end
	end
	local stageTabs = {}
	local sx = 0
	for i, st in stages do
		stageTabs[i] = Ui.tab(craftRoot, "Lv." .. st, sx, 24, function()
			if craftTab ~= i then
				craftTab = i
				ui.craftResult = nil
				ItemDetail.hide("forge")
				view.refresh()
			end
		end)
		sx += stageTabs[i].width + 14
	end
	Ui.text(craftRoot, CRAFT.note, sx, 24, w - sx, { align = "right", color = C.dim })
	local perStage = 0
	for _, r in D.RECIPES do
		if r.stage == stages[1] then
			perStage += 1
		end
	end
	local rows = {}
	local bw, fw = CRAFT.makeW, CRAFT.feeW
	for i = 1, perStage do
		local y = 24 + CRAFT.tabH + (i - 1) * CRAFT.row
		local row = {}
		-- 윗줄: [만들 장비의 그림 — 누르면 상세 판] 이름 · [달돈] 삯 · 「제작」
		row.cell = Ui.slot(craftRoot, 0, y, IC)
		row.cell.frame.Name = "Icon"
		row.icon = Ui.smallIcon(row.cell.frame, "coin", 3, 3)
		Ui.hit(row.cell.frame).Activated:Connect(function()
			local me, bag = ctx.me(), ctx.bag()
			if row.recipe and me then
				local info, item = ForgeWindow.craftInfo(row.recipe, me, bag)
				ItemDetail.show("forge", { key = "craft:" .. row.recipe.id, info = info, item = item, buttons = {} })
			end
		end)
		row.name = Ui.text(craftRoot, "", TX, y + 5, w - TX - bw - 8 - fw - 22, { font = "body" })
		row.coin = Ui.smallIcon(craftRoot, "coin", w - bw - 8 - fw - 19, y + 3)
		row.fee = Ui.text(craftRoot, "", w - bw - 8 - fw, y + 7, fw, { align = "right", color = C.gold })
		row.make = Ui.button(craftRoot, "제작", w - bw, y + 1, bw, function()
			-- 빨리 두 번 누르면 두 번 만들어 재료를 두 번 썼다(2026-10-18 검토) — 0.8초 안의 다시 누름은 받지 않는다
			if row.recipe and os.clock() - (ForgeWindow.craftAt or -9) > 0.8 then
				ForgeWindow.craftAt = os.clock()
				ctx.send("Item", "craft", row.recipe.id)
			end
		end, { h = CRAFT.makeH })
		row.mats = {}
		for k = 1, ForgeWindow.CRAFT_MATS do
			local mx = TX + (k - 1) * CRAFT.matW
			row.mats[k] = { icon = Ui.smallIcon(craftRoot, "coin", mx, y + 25), text = Ui.text(craftRoot, "", mx + 21, y + 29, CRAFT.matW - 25, { color = C.dim }) }
		end
		row.lock = Ui.text(craftRoot, "", TX, y + 29, w - TX, { color = C.dim })
		rows[i] = row
	end
	local craftY = 24 + CRAFT.tabH + perStage * CRAFT.row + 4
	local craftResult = Ui.text(craftRoot, "", 0, craftY, w, { color = C.accent })
	Ui.text(craftRoot, CRAFT.hint, 0, craftY + 18, w, { color = C.dim })

	-- ---- 강화 ----
	local forgeRoot = Ui.group(body, 0, 0, w, h, "Enhance")
	local top = 24
	local target = ItemCell.new(forgeRoot, 0, top, function()
		if anim and not anim.revealed then
			anim.t = math.max(anim.t, ForgeWindow.REVEAL) -- 연출을 건너뛴다(결과가 왔으면 바로 보인다)
		elseif not anim then
			ui.forgeTarget, ui.forgeMat, ui.forgeResult = nil, nil, nil
			view.refresh()
		end
	end, S)
	target.frame.Name = "Target"
	local starsUi = Ui.stars(forgeRoot, S + 8, top + 1, w - S - 8)
	local name = Ui.text(forgeRoot, "", S + 8, top + 26, w - S - 8, { font = "body" })
	local y = top + S + 4
	local line1 = Ui.text(forgeRoot, "", 0, y, w, { font = "body", color = C.gold })
	local line2 = Ui.text(forgeRoot, "", 0, y + LINE + 2, w, { color = C.accent })
	local line3 = Ui.text(forgeRoot, "", 0, y + 2 * LINE + 2, w, { color = C.dim })
	y += 3 * LINE + 4
	local costIcon = Ui.smallIcon(forgeRoot, "dust", 0, y)
	local costText = Ui.text(forgeRoot, "", 21, y + 4, w - 21)
	y += COST + 6
	local shield = Ui.button(forgeRoot, "", 0, y, 120, function()
		guard = not guard
		view.refresh()
	end)
	shield.frame.Name = "Guard"
	local goW = 96
	local go = Ui.button(forgeRoot, "강화", w - goW, y, goW, function()
		local it = findIn(ctx.bag(), ui.forgeTarget)
		if not it or anim then
			return
		end
		if it.broken then
			local mat = findIn(ctx.bag(), ui.forgeMat)
			if mat then
				ctx.send("Item", "restore", it.id, mat.id)
				ui.forgeMat = nil
			end
			return
		end
		anim = { t = 0, seq = ui.forgeSeq or 0, snap = table.clone(it), id = it.id, revealed = false }
		ui.forgeResult, ui.forgeWhy = nil, nil -- 지난 「안 된 까닭」을 지운다(2026-10-18 검토)
		ctx.send("Item", "enhance", it.id, guard)
		view.startAnim()
	end, { main = true })
	go.frame.Name = "Go"
	y += Ui.M.button + 4
	local result = Ui.text(forgeRoot, "", 0, y, w)
	y += LINE + 8
	Ui.line(forgeRoot, 0, y - 4, w)
	local pickLabel = Ui.text(forgeRoot, "장착 중 · 가방의 장비 — 누르거나 끌어다 놓아 올린다", 0, y, w, { color = C.dim })
	y += 14
	local cols = math.max(1, math.floor(w / S))
	local listH = 2 * S
	local list = Ui.scroll(forgeRoot, 0, y, w + 6, listH, listH, 3)
	list.Name = "Choices"
	local picks = {}
	local function makePick(i: number)
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		local p = {}
		p.cell = ItemCell.new(list, col * S, row * S, function(it)
			if not it or anim then
				return
			end
			local cur = findIn(ctx.bag(), ui.forgeTarget)
			if cur and cur.broken and cur.id ~= it.id and Items.same(cur, it) and not it.broken and inGear(ctx.bag(), it.id) then
				ui.forgeMat = it.id -- 부서진 것을 되살릴 같은 장비(가방의 것만 — 장착한 것은 서버가 받지 않는다)
			else
				ui.forgeTarget, ui.forgeMat, ui.forgeResult = it.id, nil, nil
			end
			ui.forgeWhy = nil -- 다른 것을 골랐다: 지난 「안 된 까닭」을 지운다(2026-10-18 검토)
			view.refresh()
		end, S)
		p.tag = Ui.text(p.cell.frame, "장착", 3, 2, S - 6, { outline = true, color = C.accent, z = 7 })
		picks[i] = p
		return p
	end

	-- 강화 연출의 그림들(칸 위에 겹친다)
	local fx = Ui.group(forgeRoot, 0, top, S, S, "Fx")
	fx.ZIndex = 20
	local flash = Ui.box(fx, 0, 0, S, S, C.text, 1)
	flash.ZIndex = 21
	local ring = Ui.box(fx, 0, 0, S, S, C.gold, 1)
	ring.ZIndex = 20
	-- 망치: 자루가 위 · 머리가 아래(머리로 칸을 내려친다)
	local hammer = Ui.group(fx, 0, 0, 22, 22, "Hammer")
	hammer.ZIndex = 23
	local handle = Ui.box(hammer, 9, 0, 5, 13, Color3.fromRGB(110, 78, 52))
	local head = Ui.box(hammer, 0, 13, 22, 9, C.ink)
	Ui.box(head, 1, 1, 20, 7, Color3.fromRGB(150, 160, 176))
	head.ZIndex, handle.ZIndex = 24, 24
	hammer.Visible = false
	local sparks = {}
	for i = 1, 8 do
		local sp = Ui.box(fx, 0, 0, 3, 3, if i % 2 == 0 then C.gold else C.text)
		sp.ZIndex = 22
		sp.Visible = false
		sparks[i] = sp
	end
	local BIGX, BIGW = -24, S + 48 -- 큰 글은 칸의 가운데에(창 가운데면 이름 · 별과 겹친다)
	local big = Ui.text(forgeRoot, "", BIGX, top + math.floor(S / 2) - 8, BIGW, { font = "body", align = "center", outline = true, z = 25 })
	big:show(false)

	-- 연출 한 장(dt만큼 흐른다). 다 끝나면 false
	function view.step(dt: number): boolean
		if not anim then
			return false
		end
		anim.t += dt
		local t = anim.t
		-- 망치 세 번: 내려치기 전에 들고(위로), 치는 순간 칸이 번쩍 · 흔들림 · 불티
		local strike, since = 0, 99
		for i, at in ForgeWindow.STRIKES do
			if t >= at then
				strike, since = i, t - at
			end
		end
		local beforeReveal = not anim.revealed
		hammer.Visible = beforeReveal and t < ForgeWindow.REVEAL
		if hammer.Visible then
			local nextAt = ForgeWindow.STRIKES[strike + 1]
			-- 앞의 내려치기(첫 내려치기 전이면 연출의 시작 0초). 2026-10-21: 전에는 첫 내려치기 전에 STRIKES[0](없음)으로 빼서 장마다 오류가 났다(퍼블리시한 게임의 오류 보고 1,727번)
			local prevAt = ForgeWindow.STRIKES[strike] or 0
			local lift = if since < 0.1 then 0 elseif nextAt then math.min(1, math.max(0, t - prevAt - 0.1) / math.max(0.05, nextAt - prevAt - 0.15)) else 1
			hammer.Position = UDim2.fromOffset(math.floor(S / 2) - 11, math.floor(-6 - 14 * lift)) -- 치는 순간 머리가 칸의 윗쪽에 닿는다
		end
		flash.BackgroundTransparency = if beforeReveal and since < 0.12 then 0.35 + since * 5 else 1
		local shake = if beforeReveal and since < 0.1 then (if math.floor(t * 60) % 2 == 0 then 2 else -2) else 0
		target.frame.Position = UDim2.fromOffset(shake, top)
		for i, sp in sparks do
			local life = since
			sp.Visible = beforeReveal and life < 0.3 and strike > 0
			if sp.Visible then
				local a = (i / #sparks) * math.pi * 2 + strike
				local r = 6 + life * 70
				sp.Position = UDim2.fromOffset(math.floor(S / 2 + math.cos(a) * r), math.floor(S / 2 + math.sin(a) * r - life * 20))
			end
		end
		-- 결과: 서버의 답이 왔고 때가 됐으면 보인다(답이 오지 않으면 4초 뒤 그친다)
		local arrived = (ui.forgeSeq or 0) > anim.seq
		if beforeReveal and t >= ForgeWindow.REVEAL and arrived then
			anim.revealed = true
			anim.result = ui.forgeResult
			anim.t0 = t
			view.refresh()
		elseif beforeReveal and t >= 4 then
			anim = nil
			view.stopAnim()
			view.refresh()
			return false
		end
		if anim.revealed then
			local r = anim.result
			local k = t - anim.t0
			local show = r and ForgeWindow.BIG[r]
			big:show(show ~= nil)
			if show then
				big:set(show[1])
				big:color(show[2])
				big:move(BIGX, top + math.floor(S / 2) - 8 - math.floor(math.min(k, 0.3) * 20))
			end
			-- 성공: 금빛 테두리가 퍼진다 · 떨어짐 · 파괴: 붉게 번쩍 · 파괴는 크게 흔들린다
			if r == "ok" then
				local g = math.min(1, k / 0.6)
				ring.Size = UDim2.fromOffset(math.floor(S * (1 + g * 0.5)), math.floor(S * (1 + g * 0.5)))
				ring.Position = UDim2.fromOffset(math.floor(-S * g * 0.25), math.floor(-S * g * 0.25))
				ring.BackgroundTransparency = 0.4 + 0.6 * g
				ring.BackgroundColor3 = C.gold
			elseif r == "drop" or r == "boom" then
				flash.BackgroundColor3 = C.red
				flash.BackgroundTransparency = math.min(1, 0.3 + k * 1.5)
				if r == "boom" and k < 0.4 then
					target.frame.Position = UDim2.fromOffset(if math.floor(k * 50) % 2 == 0 then 4 else -4, top)
				end
			end
			if t >= ForgeWindow.END then
				anim = nil
				view.stopAnim()
				view.refresh()
				return false
			end
		end
		return true
	end
	function view.startAnim()
		view.refresh()
		if bound then
			return
		end
		local ok = pcall(function()
			RunService:BindToRenderStep("LuneForge", Enum.RenderPriority.Last.Value, function(dt)
				view.step(dt)
			end)
		end)
		bound = ok
	end
	function view.stopAnim()
		if bound then
			pcall(function()
				RunService:UnbindFromRenderStep("LuneForge")
			end)
			bound = false
		end
		hammer.Visible = false
		flash.BackgroundTransparency = 1
		flash.BackgroundColor3 = C.text
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.fromOffset(S, S)
		ring.Position = UDim2.fromOffset(0, 0)
		big:show(false)
		target.frame.Position = UDim2.fromOffset(0, top)
		for _, sp in sparks do
			sp.Visible = false
		end
	end
	function view.animating(): boolean
		return anim ~= nil
	end

	-- 가방 창의 장비를 끌어다 이 창에 놓으면 강화할 장비로 올린다(가방 창이 묻는다 — ui/bagWindow.luau)
	ui.forgeDrop = function(at: Vector2): boolean
		return ItemCell.over(panel, at)
	end

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		if ui.forgeTab then -- 다른 창에서 장비를 올렸다(가방 · 장비 창의 「강화」 · 끌어다 놓기) — 강화 탭으로
			tab, ui.forgeTab = ui.forgeTab, nil
			ItemDetail.hide("forge")
		end
		for i, t in tabs do
			t:setOn(ForgeWindow.TABS[i][1] == tab)
		end
		coinText:set(Format.short(me.money))
		dustText:set(Format.short(bag.dust))
		craftRoot.Visible = tab == "craft"
		forgeRoot.Visible = tab == "enhance"
		-- 제작
		for i, t in stageTabs do
			t:setOn(i == craftTab)
		end
		local k = 0
		for _, r in D.RECIPES do
			if r.stage == stages[craftTab] then
				k += 1
				local row = rows[k]
				if row then
					row.recipe = r
					local open = me.level >= r.from
					local item = Items.make(r.slot, r.stage, D.NORMAL, me.class)
					Ui.setWorldIcon(row.icon, ItemCell.icon(item))
					row.name:set(Items.name(item))
					row.name:color(if open then C.text else C.dim)
					local parts, enough = ForgeWindow.craftParts(r, bag)
					for j, m in row.mats do
						local q = if open then parts[j] else nil
						Ui.setWorldIcon(m.icon, if q then q.icon else nil)
						m.text:set(if q then q.text else "")
						m.text:color(if q and q.ok then C.green else C.dim)
					end
					row.lock:set(if open then "" else ("Lv.%d부터 만든다"):format(r.from))
					row.fee:set(if open then Format.short(r.money) else "")
					row.coin.Visible = open
					row.make.frame.Visible = open
					row.make:setEnabled(enough and me.money >= r.money)
				end
			end
		end
		local made = ui.craftResult
		craftResult:set(if made then ("%s — 만들었다"):format(ItemCell.label(made)) else "")
		if made then
			craftResult:color(ItemCell.color(made))
		end
		-- 강화
		local open = me.level >= D.OPEN.forge
		local list0 = ForgeWindow.choices(bag)
		for i = #picks + 1, math.max(#list0, cols * 2) do
			makePick(i)
		end
		local rowsN = math.max(2, math.ceil(#list0 / cols))
		list.CanvasSize = UDim2.fromOffset(0, rowsN * S)
		list.ScrollBarThickness = if rowsN > 2 then 3 else 0
		for i, p in picks do
			local c = list0[i]
			p.cell.frame.Visible = i <= rowsN * cols
			p.cell:set(if c then c.it else nil, { selected = c ~= nil and (c.it.id == ui.forgeTarget or c.it.id == ui.forgeMat) })
			p.tag:show(c ~= nil and c.worn)
		end
		local it = findIn(bag, ui.forgeTarget)
		if not it then
			ui.forgeTarget = nil
		end
		-- 연출 중에는 누르기 전의 장비를 보인다(별은 결과가 뜰 때 바뀐다)
		local shown = if anim and not anim.revealed and it and it.id == anim.id then anim.snap else it
		target:set(shown)
		if not open then
			starsUi:set(0, 0)
			name:set(("강화는 Lv.%d부터"):format(D.OPEN.forge))
			name:color(C.dim)
			line1:set("")
			line2:set("")
			line3:set("")
			costText:set("")
			costIcon.Visible = false
			go:setEnabled(false)
			shield.frame.Visible = false
			result:set("")
			return
		end
		if not shown then
			starsUi:set(0, 0)
			name:set("강화할 장비를 아래에서 고른다")
			name:color(C.dim)
			line1:set("")
			line2:set("")
			line3:set("")
			costText:set("")
			costIcon.Visible = false
			go:setEnabled(false)
			go:setText("강화")
			shield.frame.Visible = false
			result:set("")
			return
		end
		starsUi:set(shown.star, D.ENHANCE.max)
		name:set(ItemCell.label(shown))
		name:color(ItemCell.color(shown))
		local info = Items.enhanceInfo(shown, guard, Items.firstFree(me.forged, me.level, shown)) -- 첫 강화(별이 없는 제 레벨 + 10까지의 장비의 첫 별)는 공짜로 반드시 붙는다 — 서버와 같은 셈
		local texts = ForgeWindow.lines(shown, info, bag)
		line1:set(texts[1])
		line2:set(texts[2])
		line3:set(texts[3])
		costText:set(texts[4])
		costIcon.Visible = texts[4] ~= ""
		if shown.broken then
			local mat = findIn(bag, ui.forgeMat)
			go:setText("되살리기")
			go:setEnabled(mat ~= nil and not anim)
			shield.frame.Visible = false
		else
			go:setText("강화")
			go:setEnabled(info.can and bag.dust >= info.dust and not anim)
			shield.frame.Visible = info.can and info.guard == true
			shield:setText(if guard then "파괴 방지 켬" else "파괴 방지 끔")
			shield:setMain(guard)
		end
		local last = if anim and not anim.revealed then nil else ui.forgeResult
		local show = last and ForgeWindow.RESULT[last]
		result:set(if show then show[1] elseif ui.forgeWhy then ui.forgeWhy else "")
		result:color(if show then show[2] else C.red)
	end

	function view.destroy()
		ui.forgeDrop = nil
		view.stopAnim()
		ItemDetail.hide("forge")
		ui.craftResult = nil
	end
	view.refresh()
	return view
end

-- 장비를 올린다(가방 · 장비 창의 상세 판 「강화」 · 끌어다 놓기): 강화할 장비로. 부서진 것을 올려 둔 채 같은 장비를 올리면 되살릴 재료로
function ForgeWindow.put(ui, id: number, bag: any)
	local cur = findIn(bag, ui.forgeTarget)
	local it = findIn(bag, id)
	if cur and it and cur.broken and cur.id ~= it.id and Items.same(cur, it) and not it.broken and inGear(bag, id) then
		ui.forgeMat = id
	else
		ui.forgeTarget, ui.forgeMat = id, nil
	end
	ui.forgeResult, ui.forgeWhy = nil, nil
	ui.forgeTab = "enhance"
end

return ForgeWindow
