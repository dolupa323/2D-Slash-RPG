-- 「달의 계승자」 — 달빛 상점 창을 화면 없이 돌려 본다(client/lune/ui/cashWindow.luau — 2026-10-20).
--  모양은 공방 시험 탭의 paintCash(?lunedemo=cash)와 같다. 보는 것:
--   창이 스마트폰의 화면 틀에 들어간다 · 탭 다섯 · 상품 번호가 없으면 모두 「준비 중」 · 번호가 있어도 게임에 아직 없는 상품(펫 · 순간이동 · 꾸밈 · 패스)은 「준비 중」 ·
--   재화 탭 = 지금 사면 드는 양(가장 높은 캐릭터의 레벨대) · 주간 횟수를 다 쓰면 꺼진 「구매」와 빨간 「이번 주 3/3」 · 「구매」가 서버에 묻는다 ·
--   보관함 = 받을 것의 수(탭 옆) · 「받기」 · 「모두 받기」 · 패스 탭 · 이름 바꾸기(주문서가 없으면 꺼짐 · 「변경」이 서버에 묻는다)
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Items = req("ReplicatedStorage/shared/lune/sim/items")

local function frame(name)
	local f = { Name = name, Visible = true, children = {} }
	function f:Destroy() end
	return f
end
local texts, buttons, tabs, scrolls, fields, pics, previews = {}, {}, {}, {}, {}, {}, {}
local function text(_, value, x, y, width, opts)
	local t = { value = value, x = x, y = y, width = width, shown = true, opts = opts or {}, tint = (opts or {}).color }
	function t.set(_, v)
		t.value = v
	end
	function t.color(_, c)
		t.tint = c
	end
	function t.move(_, nx, ny)
		t.x, t.y = nx, ny
	end
	function t.show(_, on)
		t.shown = on
	end
	table.insert(texts, t)
	return t
end
local COLOR = setmetatable({}, { __index = function(_, k) return k end }) -- 색 = 그 이름
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	M = { small = 10, smallLine = 14, body = 12, button = 26 },
	measure = function(t) return #t * 3 end,
	text = text,
	group = function(_, x, y, w, h, name)
		local f = frame(name)
		f.x, f.y = x, y
		if name == "Preview" then
			table.insert(previews, f) -- 펫 · 탈것 줄의 미리보기 자리(2026-10-21)
		end
		return f
	end,
	slot = function() return { frame = frame("Slot"), setOn = function() end } end,
	pic = function(_, name)
		local f = frame("Pic")
		f.pic = name
		table.insert(pics, f)
		return f
	end,
	setPic = function(label, name)
		label.pic = name
	end,
	line = function() return frame("Line") end,
	box = function(_, x, y, w, h, color)
		local f = frame("Box")
		f.BackgroundColor3 = color
		return f
	end,
	smallIcon = function(_, name)
		local f = frame("Icon")
		f.icon = name
		f.ImageTransparency = 0
		return f
	end,
	setWorldIcon = function(label, name)
		label.icon = name
	end,
	hit = function(parent)
		local h = { Activated = { Connect = function(_, fn) parent.click = fn end }, MouseEnter = { Connect = function(_, fn) parent.hover = fn end } }
		return h
	end,
	bar = function()
		local b = { frame = frame("Bar"), ratio = 0 }
		function b.set(_, r)
			b.ratio = r
		end
		return b
	end,
	field = function(_, x, y, w, h, placeholder)
		local f = { Text = "", PlaceholderText = placeholder }
		table.insert(fields, f)
		return f
	end,
	button = function(_, label, x, y, w, fn, opts)
		local b = { frame = frame("Button"), label = label, click = fn, enabled = true, x = x, y = y, w = w, opts = opts }
		function b.setEnabled(_, on)
			b.enabled = on
		end
		function b.setText(_, v)
			b.label = v
		end
		function b.setMain(_, on)
			b.main = on
		end
		table.insert(buttons, b)
		return b
	end,
	tab = function(_, label, x, y, fn)
		local t = { frame = frame("Tab"), label = label, click = fn, width = #label * 3, on = false, x = x }
		function t.setOn(_, on)
			t.on = on
		end
		table.insert(tabs, t)
		return t
	end,
	scroll = function(_, x, y, w, h, contentH, barW)
		local s = frame("Scroll")
		s.CanvasSize = UDim2.fromOffset(0, contentH)
		s.CanvasPosition = Vector2.new(0, 0)
		s.ScrollingEnabled = true
		s.ScrollBarThickness = barW
		table.insert(scrolls, s)
		return s
	end,
})
local function textOf(v)
	for _, t in texts do
		if t.value == v and t.shown then
			return t
		end
	end
	return nil
end
local function buttonsNamed(label)
	local out = {}
	for _, b in buttons do
		if b.label == label and b.frame.Visible then
			table.insert(out, b)
		end
	end
	return out
end
local W = BM.shop.words

local CashWindow = req("Client/lune/ui/cashWindow")
local cw, ch = CashWindow.size()
eq(cw, Layout.CASH.w, "창의 폭 = 공방의 칸")
expect(ch + 44 + 14 + 16 <= 432, ("스마트폰의 화면 틀(432)에 들어간다 — %d"):format(ch + 74))
local rw, rh = CashWindow.size("rename")
expect(rh < ch, "이름 바꾸기는 작은 창")
eq(CashWindow.title("rename"), W.renameTitle, "이름 바꾸기의 제목")
eq(CashWindow.title(nil), BM.shop.title, "상점의 제목")

-- 서버가 보내는 것(진짜 셈 — sim/cash.luau의 Cash.view): Lv.34 캐릭터가 있는 계정
local NOW = 1760900000
local acct = Account.new()
local hero = Hero.new(1, "riven")
hero.level = 34
Account.add(acct, "상점손님", "riven", Hero.pack(hero), NOW)
local view = Cash.view(acct, NOW, nil)
eq(view.band, 30, "가장 높은 캐릭터 Lv.34 → 주머니 · 상자는 Lv.30")
eq(Cash.view(acct, NOW, nil, 41).band, 40, "지금 놀고 있는 캐릭터가 저장 전에 Lv.41이 되었으면 → Lv.40")
for _, v in view.list do
	local p = Cash.product(v.id)
	local hasId = typeof(p.rid) == "number" and p.rid > 0
	eq(v.ready, hasId and p.built == true, "대시보드 번호가 있고 게임에 만들어 둔 것만 살 수 있다 " .. v.id)
end
-- 상품 번호를 넣은 뒤(대시보드에서 만든 뒤): 만들어 둔 것만 살 수 있다
local saved = {}
for i, p in BM.products do
	saved[i] = p.rid
	p.rid = 1000 + i
end
view = Cash.view(acct, NOW, nil)
for _, v in view.list do
	local p = Cash.product(v.id)
	eq(v.ready, p.built == true, "번호가 있어도 게임에 만들어 둔 것만 살 수 있다 " .. v.id)
end
local calls = {}
local bag = { use = { { item = "bm_rename", n = 0 } }, gear = {}, etc = {} }
local ctx = {
	cash = function() return view end,
	bag = function() return bag end,
	cashDo = function(action, a)
		table.insert(calls, { action, a })
		if action == "take" then
			if a then
				table.remove(view.box, a)
			else
				view.box = {}
			end
			return { ok = true, list = view.list, box = view.box }
		elseif action == "rename" then
			return { ok = true, name = a }
		end
		return { ok = true }
	end,
}
view.box = { { id = "bm_exp", n = 2 }, { id = "bm_money_30", n = 1 } }
local body = frame("Body")
local cv = CashWindow.build(body, ctx, cw, ch)
eq(#tabs, #BM.shop.tabs, "탭 다섯")
-- 탭의 차례(이름표 → 번호 — 2026-10-21: 「펫」 탭을 더하고 「패스」 탭을 껐다)
local T = {}
for i, t in BM.shop.tabs do
	T[t[1]] = i
end
expect(tabs[1].on, "처음은 편의 탭")
expect(textOf(W.head) ~= nil, "안내 한 줄")
expect(textOf("3") ~= nil, "보관함 옆에 받을 것의 수(경험치 쿠폰 2 + 주머니 1)")
-- 편의 탭: 첫 줄 = 첫걸음 묶음
local rows = CashWindow.rows(view, 1)
eq(#rows, #BM.shop.rows.conv, "편의 탭의 상품 수")
eq(rows[1].id, "starter", "첫 줄 = 첫걸음 묶음")
eq(rows[1].state, "buy", "만들어 둔 상품은 「구매」")
eq(rows[1].count, "산 수 0/1", "계정에 한 번 — 산 수")
local tele
for _, r in rows do
	if r.id == "tele" then
		tele = r
	end
end
eq(tele and tele.state, "soon", "순간이동의 돌(아직 없음)은 번호가 있어도 「준비 중」")
expect(#buttonsNamed(W.soon) >= 1, "화면에 「준비 중」 단추")
-- 「구매」 → 서버에 묻는다
local buy = buttonsNamed(W.buy)[1]
expect(buy ~= nil and buy.enabled, "「구매」가 켜져 있다")
buy.click()
eq(calls[1][1], "buy", "서버에 구매를 묻는다")
eq(calls[1][2], "starter", "그 상품")
expect(textOf(W.asked) ~= nil, "구매 창을 띄웠다는 알림")
-- 재화 탭: 드는 양 · 주간 횟수
acct.bm.week = Cash.weekOf(NOW)
acct.bm.wc = { dust = 3 }
local box = view.box
view = Cash.view(acct, NOW, nil)
view.box = box
tabs[T.money].click()
expect(tabs[T.money].on and not tabs[1].on, "재화 탭")
local money = Items.goods("bm_money_30")
expect(textOf(("지금 사면 달돈 %s(Lv.30)"):format(req("ReplicatedStorage/shared/lune/ui/format").comma(money.amount))) ~= nil, "지금 사면 드는 달돈(Lv.30)")
local cr = CashWindow.rows(view, T.money)
eq(cr[2].id, "dust", "둘째 줄 = 달가루 상자")
-- 2026-10-22 사용자 "달빛상점에서 달가루 상자, 달돈주머니 구매 제한 푼다" — 이번 주에 셋을 샀어도 「구매」(전에는 꺼지고 빨간 「이번 주 3/3」)
eq(cr[2].state, "buy", "이번 주에 셋을 샀어도 또 산다")
expect(textOf("이번 주 3/3") == nil, "「이번 주 n/3」 줄이 없다")
local offBuy = 0
for _, b in buttonsNamed(W.buy) do
	if not b.enabled then
		offBuy += 1
	end
end
eq(offBuy, 0, "재화 탭의 「구매」가 모두 켜져 있다")
-- 보관함: 받기 · 모두 받기
tabs[T.box].click()
local takes = buttonsNamed(W.take)
eq(#takes, 2, "보관함의 줄마다 「받기」")
expect(textOf("x2") ~= nil, "경험치 쿠폰 x2")
expect(textOf(("쓰면 달돈 %s"):format(req("ReplicatedStorage/shared/lune/ui/format").comma(money.amount))) ~= nil, "주머니에 든 양")
takes[1].click()
eq(calls[#calls][1], "take", "서버에 받기를 묻는다")
eq(calls[#calls][2], 1, "첫 줄")
expect(textOf("2개를 가방에 넣었다") ~= nil, "받은 수의 알림")
local all = buttonsNamed(W.takeAll)[1]
expect(all and all.enabled, "남은 것이 있으면 「모두 받기」")
all.click()
eq(calls[#calls][2], nil, "모두 받기 = 줄 없이")
expect(not all.enabled, "다 받으면 꺼진다")
expect(textOf(W.boxEmpty) ~= nil, "빈 보관함")
-- 패스 탭: 2026-10-21 사용자 "달빛패스 일딴 비활성화해" — 탭이 없다(다시 켜면 아래가 돈다)
if not T.pass then
	expect(#tabs == #BM.shop.tabs and tabs[#tabs].label ~= "패스", "「패스」 탭이 없다")
else
	-- 패스 탭(달빛 패스 — 개발자 상품 · 산 때부터 30일 · 칸 30): 남은 날 · 달빛 · 칸 · 「보상 받기」
	view.pass = { active = false, ended = false, left = 0, pts = 0, today = 0, reached = 0, p = {}, ready = 0 }
	tabs[T.pass].click()
	eq(scrolls[1].Visible, false, "패스 탭에는 상품 목록이 없다")
	expect(textOf(BM.pass.words.off) ~= nil, "산 적이 없으면 「사면 30일 동안 달빛이 쌓인다」")
	local buyPass, claim
	for _, b in buttons do
		if b.frame.Name == "PassBuy" then
			buyPass = b
		elseif b.frame.Name == "PassClaim" then
			claim = b
		end
	end
	expect(buyPass and buyPass.enabled and buyPass.label == W.buy, "번호가 있으면 「구매」")
	expect(claim and not claim.enabled, "받을 칸이 없으면 「보상 받기」 꺼짐")
	view.pass = { active = true, ended = false, left = 18, pts = 125, today = 8, reached = 12, p = { 1, 2, 3 }, ready = 9 }
	cv.refresh()
	expect(textOf("패스 18일 남음") ~= nil, "남은 날")
	expect(textOf("달빛 125 · 오늘 8/12") ~= nil, "달빛 · 오늘")
	expect(textOf("12/30칸") ~= nil, "연 칸")
	expect(textOf(W.own) ~= nil and not buyPass.frame.Visible, "패스가 있는 동안 = 「보유」 · 「구매」 없음")
	local cells = CashWindow.passCells(view.pass)
	eq(#cells, 30, "칸 서른")
	expect(cells[4].ready and not cells[3].ready and not cells[13].ready, "연 칸(4~12)만 · 받은 칸(1~3)은 아니다 · 13칸은 아직")
	expect(claim.enabled, "받을 칸이 있으면 「보상 받기」")
	claim.click()
	eq(calls[#calls][1], "pass", "서버에 패스 보상을 묻는다")
	eq(CashWindow.passCellText(cells[10]), "10칸 — 달돈 주머니 1", "칸의 보상 글")
	view.pass = { active = false, ended = true, left = 0, pts = 300, today = 0, reached = 30, p = {}, ready = 30 }
	cv.refresh()
	expect(textOf(BM.pass.words.ended) ~= nil, "끝난 뒤 = 「패스가 끝났다 — 다시 사면 새 30일」")
	expect(buyPass.frame.Visible and buyPass.enabled, "끝난 뒤에는 다시 「구매」")
end
for i, p in BM.products do
	p.rid = saved[i]
end

-- 가진 펫 · 탈것(2026-10-21 사용자 "펫을 넣고 빼는거, 라이딩을 타는거 이런게 달빛상점에 들어가서 하는게 아닙니다. 달빛상점은 구매를 하는곳이에요"):
--  줄에는 「보유」만 — 「꺼내기 · 넣기 · 타기 · 내리기」 단추는 상점에 없다(가방의 캐시 탭 · 퀵슬롯 · N 키)
view.list = Cash.view(acct, NOW, nil).list
for _, v in view.list do
	if v.id == "pet_scarf" or v.id == "mount_boar" then
		v.own = true
	end
end
view.petOut, view.mount, view.riding = "pet_scarf", "mount_boar", true
local conv = CashWindow.rows(view, T.pet) -- 펫은 「펫」 탭(2026-10-21)
local scarf
for _, r in conv do
	if r.id == "pet_scarf" then
		scarf = r
	end
end
eq(scarf.state, "own", "가진 펫의 줄 = 「보유」")
eq(scarf.use, nil, "가진 펫의 줄에 꺼내기 · 넣기가 없다")
eq(scarf.count, nil, "가진 펫의 줄에 「산 수 1/1」을 적지 않는다")
local boar
for _, r in CashWindow.rows(view, T.look) do
	if r.id == "mount_boar" then
		boar = r
	end
end
eq(boar.state, "own", "가진 탈것의 줄 = 「보유」")
tabs[T.look].click()
for _, word in { W.petOn, W.petOff, W.rideOn, W.rideOff } do
	eq(#buttonsNamed(word), 0, "상점에 「" .. word .. "」 단추가 없다")
end

-- 달빛 상점의 공간(2026-10-21): 펫 · 탈것의 줄을 누르면(PC는 올려 두면) 미리보기에 — 그 밖의 줄은 아무것도 하지 않는다
local seen = {}
ctx.cashPreview = function(id)
	table.insert(seen, id)
end
expect(#previews >= 1, "줄마다 미리보기 자리가 있다")
previews[1].click() -- 꾸밈 탭의 첫 줄(탈것)
previews[1].hover()
eq(seen[1], CashWindow.rows(view, T.look)[1].id, "꾸밈 탭 첫 줄을 누르면 그 탈것을 미리보기에")
eq(#seen, 2, "올려 두어도 미리보기에(PC)")
tabs[T.money].click() -- 재화 탭: 펫 · 탈것이 아니다
previews[1].click()
eq(#seen, 2, "재화 줄은 미리보기에 보내지 않는다")
tabs[T.pet].click() -- 펫 탭(2026-10-21 — 펫은 편의가 아니라 제 탭에)
previews[1].click()
eq(seen[#seen], BM.shop.rows.pet[1], "펫 탭의 첫 줄을 누르면 그 펫을 미리보기에")
tabs[T.look].click()
eq(CashWindow.product("pet_silver").name, BM.products[(function()
	for i, p in BM.products do
		if p.id == "pet_silver" then
			return i
		end
	end
	return 1
end)()].name, "상품을 이름표로 찾는다(퀵슬롯의 설명 · 가방의 캐시 탭)")

-- 이름 바꾸기(가방에서 주문서를 쓴 때)
table.clear(texts)
table.clear(buttons)
local rv = CashWindow.build(frame("Body2"), ctx, rw, rh, "rename")
local go = buttonsNamed(W.renameGo)[1]
expect(go ~= nil and not go.enabled, "주문서가 없으면 「변경」이 꺼진다")
expect(textOf("가진 주문서 0장") ~= nil, "가진 주문서 수")
bag.use[1].n = 1
fields[#fields].Text = "새이름"
rv.refresh()
expect(go.enabled, "주문서가 있고 이름을 적으면 켜진다")
go.click()
eq(calls[#calls][1], "rename", "서버에 이름 바꾸기를 묻는다")
eq(calls[#calls][2], "새이름", "적은 이름")
expect(textOf("이름이 「새이름」이 되었다") ~= nil, "바뀐 이름의 알림")
eq(fields[#fields].Text, "", "칸을 비운다")
