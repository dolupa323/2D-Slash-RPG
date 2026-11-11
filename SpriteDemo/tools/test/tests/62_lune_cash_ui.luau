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
local Format = req("ReplicatedStorage/shared/lune/ui/format")

local created = {} -- 만든 틀(선택 상자의 칸을 이름으로 찾는다 — 2026-11-10)
local function frame(name)
	local f = { Name = name, Visible = true, children = {} }
	function f:Destroy() end
	table.insert(created, f)
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
local worldIcons = {}
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
	worldIcon = function(_, name, x, y, sz)
		local f = frame("WorldIcon")
		f.icon, f.x, f.y, f.size = name, x, y, sz
		table.insert(worldIcons, f) -- (선택 상자의 칸 — 2026-11-10)
		return f
	end,
	hit = function(parent)
		local h = { Activated = { Connect = function(_, fn) parent.click = fn end }, MouseEnter = { Connect = function(_, fn) parent.hover = fn end }, MouseLeave = { Connect = function(_, fn) parent.leave = fn end } } -- (진짜 Ui.hit = TextButton — 카드는 떠날 때 테두리를 되돌린다 · 2026-11-10)
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
	eq(v.ready, p.built == true, "게임에 만들어 둔 것은 살 수 있다(2026-11-11 루나로 — 상품 번호가 없어도) " .. v.id .. tostring(hasId))
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
			if typeof(a) == "table" then -- 나눠 받기(2026-11-06): { i = 줄, n = 몇 개 }
				local e = view.box[a.i]
				local k = math.min(e.n, a.n)
				e.n -= k
				if e.n <= 0 then
					table.remove(view.box, a.i)
				end
				return { ok = true, list = view.list, box = view.box, moved = k }
			elseif a then
				table.remove(view.box, a)
			else
				view.box = {}
			end
			return { ok = true, list = view.list, box = view.box }
		elseif action == "rename" then
			return { ok = true, name = a }
		elseif action == "buy" then
			return { ok = true, spent = 99, luna = 901 } -- (루나로 샀다 — 2026-11-11: 쓴 루나 · 남은 루나)
		elseif action == "gift" then
			return { ok = true, to = typeof(a) == "table" and a.to or nil, spent = 99 } -- (루나로 보냈다 — 2026-11-11)
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
expect(textOf(Format.fill(W.head, { n = "0" })) ~= nil, "안내 한 줄 = 지금 루나(2026-11-11 — 처음 0)")
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
-- 「구매」 → 먼저 확인 자리(2026-11-11 루나: 묶음이 없어도 1개 · 지금 루나 — 로블록스의 구매 창이 없어 한 번 더 누른다) → 그 자리의 「구매」 → 서버에 묻는다
local function buttonFramed(name)
	for _, b in buttons do
		if b.frame.Name == name then
			return b
		end
	end
	return nil
end
view.luna = 1000
local buy = buttonsNamed(W.buy)[1]
expect(buy ~= nil and buy.enabled, "「구매」가 켜져 있다")
buy.click()
eq(#calls, 0, "바로 사지 않는다 — 확인 자리")
expect(textOf(Format.fill(W.qtyHead, { have = Format.comma(1000) })) ~= nil, "확인 자리: 지금 루나 1,000")
local p1 = buttonFramed("Pick1")
expect(p1 ~= nil and p1.frame.Visible and p1.label == W.buy and p1.enabled, "1개의 「구매」")
expect(not buttonFramed("Pick2").frame.Visible, "묶음이 없으면 1개만")
p1.click()
eq(calls[1][1], "buy", "서버에 구매를 묻는다")
eq(calls[1][2], "starter", "그 상품")
expect(textOf(Format.fill(W.bought, { name = Cash.product("starter").name, n = "99", have = "901" })) ~= nil, "산 뒤의 알림 — 쓴 루나 · 남은 루나")
-- 영구 게임 패스(로벅스 — 루나와 따로 · 2026-11-11 사용자 "패스는 아예 별도입니다"): 값은 「249 로벅스」 · 「구매」는 확인 자리 없이 서버에 묻는다(로블록스의 구매 창)
do
	local pr
	for _, r in CashWindow.rows(view, 1) do
		if r.id == "xp125" then
			pr = r
		end
	end
	eq(pr and pr.price, Format.fill(W.packPrice, { n = Format.comma(Cash.product("xp125").robux) }), "영구 패스의 값 = 로벅스")
end
-- 루나가 모자라면 그 자리의 단추가 「충전하기」 → 「루나 충전」 탭(묶음 여섯)
view.luna = 10
buttonsNamed(W.buy)[1].click()
local p1b = buttonFramed("Pick1")
expect(p1b.label == W.toCharge and p1b.enabled, "모자라면 「충전하기」")
eq(#calls, 1, "모자라면 서버에 묻지 않는다")
p1b.click()
expect(tabs[T.luna].on, "「루나 충전」 탭으로")
local lrows = CashWindow.rows(view, T.luna)
eq(#lrows, 6, "루나 묶음 여섯")
expect(lrows[1].charge and lrows[1].name == Format.fill(W.packName, { n = "50" }) and lrows[1].price == Format.fill(W.packPrice, { n = "50" }), "「루나 50」 · 「50 로벅스」")
eq(lrows[1].state, if Cash.packReady(Cash.LUNA.packs[1]) then "charge" else "soon", "상품 번호가 있어야 「충전」(없으면 「준비 중」)")
expect(textOf(W.lunaHint) ~= nil, "탭 아래 안내")
tabs[1].click()
view.luna = 1000
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
-- 나눠 받기(2026-11-06 사용자 "수령을 나눠서 할수있어야해"): 2개 이상인 줄의 「받기」 → 받을 수를 고르는 모습([-] [수] [+] [모두] … 「받기」)
local function btnNamed(name)
	for _, b in buttons do
		if b.frame.Name == name then
			return b
		end
	end
	return nil
end
local nCalls = #calls
takes[2].click()
eq(calls[#calls][1], "take", "1개뿐인 줄(달돈 주머니)은 바로 받는다")
eq(calls[#calls][2], 2, "둘째 줄")
nCalls = #calls
takes = buttonsNamed(W.take)
takes[1].click()
eq(#calls, nCalls, "2개인 줄은 바로 받지 않고 몇 개를 받을지 묻는다")
expect(textOf(W.takeHead) ~= nil, "「몇 개를 받을까」")
expect(textOf(Format.fill(W.takeHave, { n = 2 })) ~= nil, "「보관함에 2개」")
local go, less, more = btnNamed("TakeGo"), btnNamed("TakeLess"), btnNamed("TakeMore")
expect(go and go.frame.Visible, "「받기」가 보인다")
expect(less and less.enabled and more and not more.enabled, "처음 = 모두(2) — 「-」만 켜짐")
less.click()
expect(not less.enabled and more.enabled, "1개로 줄였다")
go.click()
eq(calls[#calls][1], "take", "서버에 받기를 묻는다")
expect(typeof(calls[#calls][2]) == "table" and calls[#calls][2].i == 1 and calls[#calls][2].n == 1, "첫 줄에서 1개")
expect(textOf("1개를 가방에 넣었다") ~= nil, "받은 수의 알림")
expect(not go.frame.Visible, "받으면 목록으로")
expect(textOf("x1") ~= nil, "보관함에 1개가 남았다")
local all = buttonsNamed(W.takeAll)[1]
expect(all and all.enabled, "남은 것이 있으면 「모두 받기」")
all.click()
eq(calls[#calls][2], nil, "모두 받기 = 줄 없이")
expect(not all.enabled, "다 받으면 꺼진다")
expect(textOf(W.boxEmpty) ~= nil, "빈 보관함")
-- 여러 개를 한 번에(2026-11-06 사용자 "여러수량을 한번에 구매요청하고 로벅스도 그 개수에맞춰"): 묶음이 있는 상품(경험치 쿠폰)의 「구매」 → 1개 · 5개 · 10개 → 고른 묶음의 구매 창
do
	tabs[1].click()
	local acts = {}
	for _, b in buttons do
		if b.frame.Name == "Act" then
			table.insert(acts, b)
		end
	end
	view.luna = 1000 -- (루나가 넉넉하다 — 2026-11-11)
	local k = table.find(BM.shop.rows.conv, "exp")
	local n0 = #calls
	acts[k].click()
	eq(#calls, n0, "묶음이 있으면 바로 사지 않고 몇 개를 살지 묻는다")
	expect(textOf(Format.fill(W.qtyHead, { have = Format.comma(1000) })) ~= nil, "「몇 개를 살까 — 지금 루나 1,000」")
	for i, n in { 1, 5, 10 } do
		local b = btnNamed("Pick" .. i)
		expect(b ~= nil and b.frame.Visible and b.enabled, ("%d개의 「구매」"):format(n))
		expect(textOf(Format.fill(W.qty, { n = n })) ~= nil, ("「%d개」"):format(n))
	end
	expect(textOf(Format.fill(W.price, { n = 245 })) ~= nil, "5개 = 245 로벅스(49 x 5)")
	expect(textOf(Format.fill(W.price, { n = 490 })) ~= nil, "10개 = 490 로벅스")
	btnNamed("Pick2").click()
	eq(calls[#calls][1], "buy", "고른 묶음을 산다")
	eq(calls[#calls][2], "exp_x5", "경험치 쿠폰 5개")
	expect(not btnNamed("Pick2").frame.Visible, "구매 창을 띄우면 목록으로")
	local ck = table.find(BM.shop.rows.conv, "charx")
	n0 = #calls
	acts[ck].click()
	eq(#calls, n0, "묶음이 없는 상품(캐릭터 칸 +1)도 확인 자리를 거친다(2026-11-11 루나 — 1개만)")
	btnNamed("Pick1").click()
	eq(calls[#calls][2], "charx", "확인 자리의 「구매」로 산다")
end
-- 선물하기(2026-10-31 사용자 "달빛상점에 모든 품목을 아이템 선물을 할수있게 해줘"): 「선물하기」 → 줄의 단추가 「선물」(영구 패스 = 「선물 불가」) →
--  「선물」 → 목록 자리에 닉네임 칸 → 「보내기」 → 서버에 gift { id, to } → 목록으로 · 「구매 창을 띄웠다 — 결제가 끝나면 「받는이」에게 간다」
do
	tabs[1].click()
	local function named(name)
		for _, b in buttons do
			if b.frame.Name == name then
				return b
			end
		end
		return nil
	end
	local gm, go, backB = named("GiftMode"), named("GiftGo"), named("GiftBack")
	expect(gm and gm.label == W.giftMode, "안내 줄 오른쪽에 「선물하기」")
	expect(backB and not backB.frame.Visible, "처음에는 「돌아가기」가 없다")
	gm.click()
	expect(gm.label == W.giftBack, "누르면 「구매하기」로 바뀐다")
	expect(textOf(W.giftHead) ~= nil, "안내 줄 = 선물할 상품의 「선물」을 누른다")
	local byId = {}
	for _, r in CashWindow.rows(view, 1, true) do
		byId[r.id] = r
	end
	eq(byId.starter.state, "gift", "첫걸음 묶음 = 「선물」")
	eq(byId.xp125 and byId.xp125.state, "noGift", "경험치 1.25배 패스 = 「선물 불가」(게임 패스 — 로벅스로 따로)")
	eq(byId.yunseul and byId.yunseul.state, "gift", "윤슬 조각(확률형)도 「선물」(2026-11-11)")
	view.randomLock = true
	local locked = {}
	for _, r in CashWindow.rows(view, 1, true) do
		locked[r.id] = r
	end
	eq(locked.yunseul.state, "noGift", "뽑기 제한 계정 = 확률형은 「선물 불가」")
	eq(locked.starter.state, "gift", "뽑기 제한 계정도 확률형이 아닌 것은 「선물」")
	view.randomLock = nil
	eq(byId.starter.count, nil, "선물할 때는 내가 산 수를 적지 않는다(받는 사람의 것은 서버가 본다)")
	expect(#buttonsNamed(W.giftNo) >= 1, "화면에 「선물 불가」")
	local giftB = buttonsNamed(W.gift)[1]
	expect(giftB and giftB.enabled, "「선물」이 켜져 있다")
	local before = #calls
	giftB.click()
	eq(#calls, before, "「선물」은 서버에 묻지 않고 닉네임 칸을 띄운다")
	expect(scrolls[1].Visible == false and backB.frame.Visible, "목록 자리에 닉네임 칸 · 아래 「돌아가기」")
	expect(textOf(W.giftText) ~= nil, "받는 사람이 접속하면 들어간다는 안내")
	local toField
	for _, f in fields do
		if f.Name == "GiftTo" then
			toField = f
		end
	end
	expect(toField ~= nil and toField.PlaceholderText == W.giftPh, "받는 사람의 닉네임 칸")
	go.click()
	eq(#calls, before, "닉네임이 비었으면 묻지 않는다")
	expect(textOf(W.giftNeedName) ~= nil, "「받는 사람의 닉네임을 적어 주세요」")
	toField.Text = "받는이"
	go.click()
	eq(calls[#calls][1], "gift", "서버에 선물을 묻는다")
	expect(typeof(calls[#calls][2]) == "table" and calls[#calls][2].id == "starter" and calls[#calls][2].to == "받는이", "그 상품 · 그 닉네임")
	expect(scrolls[1].Visible and not backB.frame.Visible, "보내면 목록으로")
	expect(textOf(req("ReplicatedStorage/shared/lune/ui/format").fill(W.giftAsked, { to = "받는이", n = "99" })) ~= nil, "「「받는이」에게 보냈다 — 루나 99」(2026-11-11 루나)")
	-- 로블록스 정책으로 막힌 계정: 줄이 모두 「선물 불가」
	view.giftLock = true
	cv.refresh()
	for _, r in CashWindow.rows(view, 1, true) do
		eq(r.state, "noGift", "막힌 계정은 모두 「선물 불가」 " .. r.id)
	end
	view.giftLock = nil
	gm.click()
	expect(gm.label == W.giftMode and textOf(Format.fill(W.head, { n = Format.comma(view.luna or 0) })) ~= nil, "다시 누르면 「구매」로")
end
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
local conv = CashWindow.rows(view, T.pet) -- 펫은 「펫」 탭(2026-10-21) · 2026-11-07부터 펫은 「윤슬 펫 상자」 한 줄(펫 셋을 따로 파는 줄은 껐다)
local box
for _, r in conv do
	expect(string.sub(r.id, 1, 4) ~= "pet_", "펫 탭에 펫을 따로 파는 줄이 없다(상자에서만) " .. r.id)
	if r.id == "petbox" then
		box = r
	end
end
expect(box ~= nil and box.random == true, "펫 탭 = 윤슬 펫 상자(확률형 — 「확률 보기」)")
eq(box and box.use, nil, "상자 줄에 꺼내기 · 넣기가 없다")
eq(box and box.count, nil, "상자 줄에 「산 수」를 적지 않는다")
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
local lookRows = CashWindow.rows(view, T.look)
local at = 1 -- 꾸밈 탭의 첫 탈것 줄(2026-11-07부터 맨 위는 「윤슬 탈것 상자」 — 탈것이 아니라 미리보기에 보내지 않는다 · 줄의 틀은 칸마다 하나라 previews[i] = i째 줄)
for i, r in lookRows do
	if string.sub(r.id, 1, 6) == "mount_" then
		at = i
		break
	end
end
previews[at].click()
previews[at].hover()
eq(seen[1], lookRows[at].id, "꾸밈 탭의 탈것 줄을 누르면 그 탈것을 미리보기에")
local n0 = #seen
previews[1].click() -- 맨 위의 상자 줄
eq(#seen, n0, "꾸밈 탭의 상자 줄은 미리보기에 보내지 않는다")
eq(#seen, 2, "올려 두어도 미리보기에(PC)")
tabs[T.money].click() -- 재화 탭: 펫 · 탈것이 아니다
previews[1].click()
eq(#seen, 2, "재화 줄은 미리보기에 보내지 않는다")
tabs[T.pet].click() -- 펫 탭(2026-10-21 — 펫은 편의가 아니라 제 탭에) · 2026-11-07부터 첫 줄 = 윤슬 펫 상자(펫이 아니라 미리보기에 보내지 않는다)
local before = #seen
previews[1].click()
eq(#seen, before, "펫 탭의 상자 줄은 미리보기에 보내지 않는다")
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

-- 한정 판매(2026-10-29 사용자: "거인 라이딩 황금으로 해서 한정 20개 판매로 해서 판매하고 다팔리면 안파는식으로"): 꾸밈 탭의 황금 골렘 줄 = 「한정 20개 · 남은 n개」 · 다 팔리면 「품절」(구매가 꺼진다)
do
	local W = BM.shop.words
	local function golemRow(left)
		local v = Cash.view(acct, NOW, nil, nil, nil, { mount_golem_gold = left })
		for _, e in v.list do
			if e.id == "mount_golem_gold" then
				e.ready = true -- (대시보드 번호가 들어간 뒤의 모습)
			end
		end
		for _, r in CashWindow.rows(v, T.look) do
			if r.id == "mount_golem_gold" then
				return r
			end
		end
		return nil
	end
	local r7 = golemRow(7)
	expect(r7 ~= nil and r7.state == "buy", "남은 것이 있으면 「구매」")
	eq(r7 and r7.count, (W.stockLeft:gsub("{max}", "20"):gsub("{n}", "7")), "남은 수를 띄운다")
	local r0 = golemRow(0)
	eq(r0 and r0.state, "soldOut", "다 팔리면 「품절」")
	expect(r0 and r0.full == true, "남은 수는 빨간 글")
	expect(W.soldOut == "품절", "품절의 글")
end

-- 화면 가득의 달빛 상점(2026-11-10 사용자 "달빛상점 접속 ui를 좀 메이플 캐시샵처럼 전체화면으로해서 좀 둘러보기도 좋게 개편을 해줘"): 상품 = 카드 · 꾸밈 탭의 작은 분류
do
	-- 배치: 1080p(960 x 540) = 4줄 · 폰(768 x 432) = 3줄 · 미리보기 + 판이 화면 안 · 카드는 가장 좁게 card.min
	local F = BM.shop.full
	for _, c in { { 960, 540, 4, "PC 1080p" }, { 768, 432, 3, "폰" }, { 1152, 648, 5, "PC 1366x768" } } do
		local L = Layout.shopFull(c[1], c[2])
		eq(L.cols, c[3], c[4] .. ": 카드 줄 수")
		expect(L.cardW >= F.card.min, c[4] .. ": 카드 폭 " .. L.cardW)
		expect(L.previewX + L.previewW < L.panelX and L.panelX + L.panelW <= c[1] - F.pad + 0.5, c[4] .. ": 미리보기 · 판이 가로로 화면 안")
		expect(L.previewY + L.h <= c[2], c[4] .. ": 세로로 화면 안")
		expect(L.cols * L.cardW + (L.cols - 1) * L.gap <= L.bodyW, c[4] .. ": 카드 줄이 판 안")
	end
	-- 창 모드(F11 아님 — 2026-11-10 사용자 "달빛상점 f11 안누르면 해상도가 안맞아서 나갈수가없어"): 화면 위를 Roblox 단추 띠가 덮는 높이(inset)만큼 윗줄 · 판을 내린다 · 그래도 화면 안
	for _, c in { { 1152, 648, 30 }, { 768, 432, 21 }, { 960, 540, 0 } } do
		local Li = Layout.shopFull(c[1], c[2], c[3])
		eq(Li.top, c[3], ("%dx%d: 윗줄(제목 · 「나가기」)이 띠 아래로 %d"):format(c[1], c[2], c[3]))
		expect(Li.previewY >= c[3] + F.topH and Li.panelY == Li.previewY, ("%dx%d: 미리보기 · 판이 윗줄 아래"):format(c[1], c[2]))
		expect(Li.previewY + Li.h <= c[2] - F.pad + 0.5, ("%dx%d: 띠만큼 내려도 판의 아래가 화면 안"):format(c[1], c[2]))
		expect(Li.leaveX + BM.shop.space.leaveW <= c[1], ("%dx%d: 「나가기」가 화면 안(가로)"):format(c[1], c[2]))
	end
	local L = Layout.shopFull(960, 540)
	table.clear(texts)
	table.clear(buttons)
	table.clear(tabs)
	table.clear(scrolls)
	table.clear(previews)
	local gv = CashWindow.build(frame("Full"), ctx, L.bodyW, L.bodyH, nil, L)
	local list = scrolls[1]
	expect(list ~= nil, "카드 목록(밀기 틀)")
	-- 꾸밈 탭: 작은 분류 넷 · 처음은 「전체」 · 「뽑기 상자」를 누르면 상자 넷만
	local look = nil
	for _, t in tabs do
		if t.label == BM.shop.tabs[T.look][2] then
			look = t
		end
	end
	look.click()
	local chips = {}
	for _, b in buttons do
		if b.frame.Name and string.sub(b.frame.Name, 1, 5) == "Chip_" then
			chips[string.sub(b.frame.Name, 6)] = b
		end
	end
	for _, c in BM.shop.sub.look do
		expect(chips[c.id] ~= nil and chips[c.id].frame.Visible, "꾸밈 탭의 작은 분류 " .. c.name)
	end
	expect(chips.all.main == true, "처음은 「전체」")
	local function shownNames()
		local out = {}
		for _, b in buttons do
			if b.frame.Name == "Act" and b.frame.Visible and b.label ~= nil then
				table.insert(out, b)
			end
		end
		return out
	end
	local allN = #CashWindow.rows(ctx.cash(), T.look)
	local cardsNow = 0
	for _, t in texts do
		if t.shown and t.opts and t.opts.font == "body" and t.opts.align == "center" and t.value ~= "" then
			cardsNow += 1
		end
	end
	expect(cardsNow >= allN, ("「전체」 = 꾸밈의 모든 카드(%d · 이름 %d)"):format(allN, cardsNow))
	chips.box.click()
	expect(chips.box.main == true and chips.all.main == false, "「뽑기 상자」를 골랐다")
	local boxNames = {}
	for _, id in BM.shop.sub.look[2].ids do
		for _, p in BM.products do
			if p.id == id then
				boxNames[p.name] = true
			end
		end
	end
	local shown, others = 0, 0
	for _, t in texts do
		if t.shown and t.opts and t.opts.font == "body" and t.opts.align == "center" and t.value ~= "" then
			if boxNames[t.value] then
				shown += 1
			end
		end
	end
	local _ = shownNames
	eq(shown, 4, "뽑기 상자 넷의 카드")
	-- 다른 탭으로 가면 작은 분류가 숨고 「전체」로
	tabs[1].click()
	expect(not chips.box.frame.Visible, "편의 탭에는 작은 분류가 없다")
	look.click()
	expect(chips.all.main == true, "꾸밈으로 돌아오면 「전체」")
	local _ = others
	local _ = gv
end

-- 선택 상자(2026-11-10 상자 판매 바로잡기 — 가방에서 쓰면 "pick:<상자>"): 크기 · 제목 · 그 상자의 것 칸(그림 · 이름 · 드문 것 금빛 · 가진 수) · 고르고 「받기」 → 서버에 그것
do
	local Gacha = req("ReplicatedStorage/shared/lune/sim/gacha")
	local box = Gacha.box("dmgskin")
	local pw, ph = CashWindow.size("pick:dmgskin")
	eq(pw, Layout.CASH.w, "선택 상자 창의 폭")
	eq(ph, CashWindow.pickH("dmgskin"), "선택 상자 창의 높이")
	expect(ph + 44 + 14 + 16 <= 432, ("스마트폰의 화면 틀(432)에 들어간다 — %d"):format(ph + 74))
	expect(string.find(CashWindow.title("pick:dmgskin"), "데미지 스킨 상자", 1, true) ~= nil, "제목 = 그 상자 — " .. CashWindow.title("pick:dmgskin"))
	eq(CashWindow.pickOf("pick:nobox"), nil, "없는 상자는 상점")
	-- 칸이 창 안에 든다(모든 상자)
	for _, bid in { "petbox", "mountbox", "bubblebox", "dmgskin", "tagskin" } do
		local n = #Gacha.box(bid).pool
		local lx, ly = CashWindow.pickCell(n)
		expect(lx + Layout.CASH.selCellW <= Layout.CASH.w and ly + Layout.CASH.selCellH <= CashWindow.pickH(bid) - 26, "마지막 칸이 창 안 — " .. bid)
	end
	table.clear(texts)
	table.clear(buttons)
	table.clear(worldIcons)
	bag.use = { { item = "bm_pick_dmgskin", n = 1 } }
	view.dskins = { "dsk_mint" }
	view.extra = { dsk_mint = 1 }
	local pv = CashWindow.build(frame("BodyPick"), ctx, pw, ph, "pick:dmgskin")
	eq(#worldIcons, #box.pool, "칸마다 그림")
	expect(worldIcons[1].size == Layout.CASH.selIcon, "그림 = 칸 크기에 맞춤")
	expect(textOf("선택 상자 1개") ~= nil, "가진 선택 상자")
	expect(textOf("가진 수 2") ~= nil, "가진 것의 가진 수(민트 — 1 + 하나 더)")
	local aurora = textOf("오로라 데미지 스킨")
	expect(aurora ~= nil and aurora.opts.color == COLOR.gold, "드문 것은 금빛")
	local go = buttonsNamed(W.pickGo)[1]
	expect(go ~= nil and not go.enabled, "고르기 전에는 「받기」가 꺼진다")
	-- 칸을 누른다(ui.hit의 click — 칸 틀)
	local cell = nil
	for _, f in created do
		if f.Name == "Pick_dsk_aurora" then
			cell = f
		end
	end
	expect(cell ~= nil and cell.click ~= nil, "칸을 누를 수 있다")
	if cell and cell.click then
		cell.click()
	end
	expect(go.enabled, "고르면 켜진다")
	go.click()
	expect(calls[#calls][1] == "pick" and calls[#calls][2] == "dsk_aurora", "서버에 고른 것")
	bag.use = { { item = "bm_pick_dmgskin", n = 0 } }
	pv.refresh()
	expect(not go.enabled, "선택 상자를 다 쓰면 꺼진다")
	view.dskins, view.extra = nil, nil
end
