-- 달빛 상점 — 메뉴 → 「달빛 상점」(2026-10-20 · 사용자: "경험치 쿠폰 판매해도 됩니다. 꾸밈탈것 만들어도 됩니다. 만들어 봅시다").
--  모양은 공방 시험 탭의 js/lune/ui/paint.js(paintCash · ?lunedemo=cash)와 같다. 글 · 탭 · 상품의 차례는 공방 design/bm.js(BM_SHOP → data/bm.generated.luau의 shop).
--   안내 한 줄 · 탭 다섯(편의 · 재화 · 꾸밈 · 패스 · 보관함 — 받을 것이 있으면 「보관함」 옆에 금빛 수) · 줄의 스크롤 · 아래 「모두 받기」와 알림.
--   상품의 줄: [그림 칸] 이름 · 꼬리표(거래 가능 / 계정) / 한 줄 설명(재화 = 지금 사면 드는 양) / 횟수 · 오른쪽 = 값 · 「구매」(못 사면 「준비 중」 · 다 산 것은 꺼진 「구매」 · 가진 패스는 「보유」).
--  사는 것: 「구매」 → ctx.cashDo("buy", 상품) → 서버가 한도를 보고 로블록스의 구매 창을 띄운다(server/lune/modules/cash.luau) →
--   결제가 끝나면 서버(ProcessReceipt)가 보관함에 넣고 "CashGot"을 보낸다(boot가 알림을 띄우고 창을 고쳐 그린다). 결제를 이 창이 셈하지는 않는다.
--  보관함 → 가방: 「받기」 · 「모두 받기」 → ctx.cashDo("take", 줄?). 이름 바꾸기(arg "rename"): 가방에서 「이름 바꾸기 주문서」를 쓰면 이 창이 이름 칸으로 열린다 → ctx.cashDo("rename", 새 이름).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local BM = require(lune.data["bm.generated"])
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.CASH
local SHOP = BM.shop
local W = SHOP.words
local NAME_MAX = 12 -- 이름 칸에 적을 수 있는 글자 수(캐릭터를 만들 때의 칸과 같다 — client/lune/title.luau)

local CashWindow = {}
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
		if q.free and not BY[q.id] then
			BY[q.id] = { id = q.id, name = q.name, line = q.line or "", icon = "ride_" .. q.id, free = q.free }
		end
	end
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

function CashWindow.size(arg: any): (number, number)
	if arg == "rename" then
		return S.w, S.renameH
	end
	return S.w, S.listY + S.rows * S.row + S.footY + Ui.M.button
end
function CashWindow.title(arg: any): string
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

-- 그 탭의 줄들(공방 paint.js의 cashRows와 같은 셈). view = 서버의 Cash.view
function CashWindow.rows(view, tab: number)
	local key = SHOP.tabs[tab] and SHOP.tabs[tab][1]
	local out = {}
	if key == "box" then
		for i, e in (view and view.box) or {} do
			local g = Items.goods(e.id)
			local from = g and SHOP.boxOf[g.kind] and BY[SHOP.boxOf[g.kind]]
			local text = if from then from.line else ""
			if g and g.kind == "bmMoney" then
				text = Format.fill(W.boxMoney, { n = Format.comma(g.amount) })
			elseif g and g.kind == "bmDust" then
				text = Format.fill(W.boxDust, { n = Format.comma(g.amount) })
			end
			table.insert(out, { box = i, icon = if g and g.icon then g.icon else "bm_starter", name = if g then g.name else e.id, text = text, n = e.n })
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
		local on = if isPet then (view and view.petOut == id) elseif isMount then (view ~= nil and view.riding == true and view.mount == id) else false
		local state = if v.own then "own" elseif not v.ready then "soon" elseif full then "full" else "buy"
		table.insert(out, {
			id = id,
			icon = p.icon,
			name = p.name,
			tag = if p.trade then W.trade else W.account,
			tagTone = if p.trade then "accent" else "dim",
			text = text,
			price = Format.fill(W.price, { n = v.robux or p.robux }), -- 서버가 읽은 로블록스의 실제 값(없으면 설계의 값)
			state = state,
			on = on == true,
			count = if lim and not ((isPet or isMount) and v.own) then Format.fill(if lim.per == "week" then W.week else W.once, { n = bought, max = lim.n }) else nil,
			full = full,
		})
	end
	return out
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
	-- 띄어쓰기는 적히지 않고 너무 길게도 적히지 않는다(캐릭터를 만들 때의 칸과 같다 — 자세한 규칙은 서버의 중복 확인이 알려 준다)
	local ok, changed = pcall(function()
		return field:GetPropertyChangedSignal("Text")
	end)
	if ok and typeof(changed) == "RBXScriptSignal" then
		changed:Connect(function()
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
			view.refresh()
		end)
	end
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

function CashWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	if arg == "rename" then
		return buildRename(body, ctx, w)
	end
	local view = {}
	local tab = 1
	local note, noteTone = nil, nil
	local waiting = false -- 답을 기다리는 중(두 번 눌러 구매 창이 둘 뜨지 않게)
	local textW = w - S.textX - S.sideW - 8
	Ui.text(body, W.head, 0, 2, w, { color = C.dim })
	local tabs = {}
	local tx = 0
	local list: ScrollingFrame
	local passBox: Frame
	for i, t in SHOP.tabs do
		local item = Ui.tab(body, t[2], tx, S.tabY, function()
			if tab ~= i then
				tab = i
				note = nil
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

	-- 상품 · 보관함의 줄: 스크롤 틀(rows개가 보이고 나머지는 민다 — 마우스 휠 · 손가락). 막대는 판의 오른쪽 여백에
	list = Ui.scroll(body, 0, S.listY, w + 10, S.rows * S.row, MOST * S.row, S.scrollW)
	list.Name = "List"
	local empty = Ui.text(body, W.boxEmpty, 0, S.listY + 20, w, { align = "center", color = C.dim })
	local rowsUi = {}
	for i = 1, MOST do
		local f = Ui.group(list, 0, (i - 1) * S.row, w, S.row, "Row" .. i)
		local r = { frame = f }
		Ui.slot(f, 0, 2, S.iconS)
		r.icon = Ui.pic(f, nil, 2, 4)
		r.name = Ui.text(f, "", S.textX, 3, textW, { font = "body" })
		r.tag = Ui.text(f, "", S.textX, 5, 80, {})
		r.text = Ui.text(f, "", S.textX, 19, textW, { color = C.dim })
		r.count = Ui.text(f, "", S.textX, S.countY, textW, { color = C.accent })
		r.price = Ui.text(f, "", w - S.sideW, S.priceY, S.sideW, { align = "right", color = C.gold })
		r.own = Ui.text(f, W.own, w - S.sideW, S.btnY + 6, S.sideW, { align = "right", color = C.green })
		r.btn = Ui.button(f, W.buy, w - S.btnW, S.btnY, S.btnW, function()
			if waiting or not r.act then
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
				note, noteTone = Format.fill(W.taken, { n = act.n }), C.green
			elseif (act.pet ~= nil or act.ride ~= nil) and res and res.ok then
				note, noteTone = nil, nil -- 꺼냈다 · 탔다(화면의 펫 · 탈것이 바로 보인다)
			elseif res and res.ok then
				note, noteTone = W.asked, C.dim
			end
			view.refresh()
		end, { main = true, h = 22 })
		r.btn.frame.Name = "Act"
		-- 펫 · 탈것의 줄: 그림 · 이름 쪽을 누르면(PC는 올려 두기만 해도) 달빛 상점의 미리보기에 내 캐릭터와 같이(2026-10-21 — 메이플 캐시샵의 미리보기. 단추 자리는 비운다)
		local pv = Ui.group(f, 0, 0, w - S.btnW - 6, S.row, "Preview")
		local hit = Ui.hit(pv)
		local function show()
			if r.preview and ctx.cashPreview then
				ctx.cashPreview(r.preview)
			end
		end
		hit.Activated:Connect(show)
		hit.MouseEnter:Connect(show)
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

	local fy = S.listY + S.rows * S.row + S.footY
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

	function view.refresh()
		local v = ctx.cash()
		local key = SHOP.tabs[tab][1]
		for i, t in tabs do
			t:setOn(i == tab)
		end
		local n = CashWindow.boxCount(v)
		boxN:set(if n > 0 then tostring(n) else "")
		local isPass = key == "pass"
		passBox.Visible = isPass
		list.Visible = not isPass
		local rows = if isPass then {} else CashWindow.rows(v, tab)
		empty:show(not isPass and #rows == 0)
		for i, ru in rowsUi do
			local r = rows[i]
			ru.frame.Visible = r ~= nil
			ru.act = nil
			ru.preview = if r and typeof(r.id) == "string" and (string.sub(r.id, 1, 4) == "pet_" or string.sub(r.id, 1, 6) == "mount_") then r.id else nil
			if r then
				Ui.setPic(ru.icon, r.icon)
				ru.name:set(r.name)
				local nw = Ui.measure(r.name, "body")
				ru.tag:set(r.tag or "")
				ru.tag:color(C[r.tagTone or "dim"] or C.dim)
				ru.tag:move(S.textX + nw + 6, 5)
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
					ru.act = { box = r.box, n = r.n }
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
					ru.count:set(r.count or "")
					ru.count:color(if r.full then C.red else C.accent)
					ru.price:set(r.price)
					ru.price:color(if r.state == "soon" then C.dim else C.gold)
					ru.own:show(r.state == "own")
					ru.btn.frame.Visible = r.state ~= "own"
					ru.btn:setText(if r.state == "soon" then W.soon else W.buy)
					ru.btn:setEnabled(r.state == "buy")
					ru.act = if r.state == "buy" then { id = r.id } else nil
				end
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, math.max(S.rows, #rows) * S.row)
		list.ScrollingEnabled = #rows > S.rows
		list.ScrollBarThickness = if #rows > S.rows then S.scrollW else 0
		if isPass then
			local pv = (v and v.pass) or {}
			local pr = CashWindow.rows(v, tab)[1]
			passRow.price:set(pr.price)
			passRow.price:color(if pr.state == "soon" then C.dim else C.gold)
			passRow.own:show(pv.active == true)
			passRow.buy.frame.Visible = pv.active ~= true
			passRow.buy:setText(if pr.state == "soon" then W.soon else W.buy)
			passRow.buy:setEnabled(pr.state == "buy" and pv.active ~= true)
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
		noteText:set(note or (if key == "box" and n > 0 then W.boxHint else ""))
		noteText:color(noteTone or C.dim)
	end
	if ctx.cashFetch then
		ctx.cashFetch() -- 열 때 서버의 지금 것을 받아 온다(받으면 다시 그린다)
	end
	view.refresh()
	return view
end

return CashWindow
