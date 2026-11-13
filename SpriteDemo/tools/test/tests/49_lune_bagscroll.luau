-- 「달의 계승자」 — 가방의 칸이 스크롤된다(2026-10-15, client/lune/ui/bagWindow.luau를 화면 없이 돌려 본다).
--  사용자: "인벤토리 위아래 버튼으로 움직이는게아니라 스크롤이어야합니다. 모바일에서도 정상작동하게"
--  보는 것: ▲▼ 단추가 없다 · 칸들이 스크롤 틀 안에 있다 · 늘린 가방(48칸)은 칸이 다 있고 스크롤이 켜진다 · 24칸이면 꺼진다 · 탭을 바꾸면 맨 위로 ·
--   스마트폰에서 끌기는 잠깐 누르고 있어야 시작한다(가방이 hold를 넘긴다) · 끄는 동안 스크롤이 선다
--  2026-11-13 마우스를 올린 칸의 정보(PC — 메이플처럼): 고른 것이 없으면 정보만(단추 없음) · 벗어나면 닫힘 · 고르면 단추가 붙는다 · 손가락 · 다른 창의 상세 · 캐시 탭은 아니다 · 장비 창도 같다
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local lastInput = Enum.UserInputType.MouseMovement
SERVICE("UserInputService", { GetLastInputType = function() return lastInput end })
local BAG = Layout.BAG

local buttons, scrolls, cells, presses, madeTabs, shown = {}, {}, {}, {}, {}, {}
local function frame(name)
	local f = { Name = name, Visible = true, children = {}, AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(100, 100) }
	function f:Destroy() end
	return f
end
local any = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end })
local function text()
	local t = { frame = frame("Text") }
	function t.set() end
	function t.move() end
	function t.show() end
	function t.color() end
	return t
end
MOCK("Client/lune/stage", { ratio = 2.5, uiScale = 2 })
MOCK("Client/lune/ui/ui", {
	COLOR = any,
	box = function() -- (가득 찬 탭의 노란 점 — 2026-10-31)
		return frame("Box")
	end,
	tab = function(parent, name, x, y, fn)
		local t = { width = 40, click = fn, name = name, frame = frame("Tab") }
		function t.setOn() end
		table.insert(madeTabs, t)
		return t
	end,
	text = function()
		return text()
	end,
	button = function(parent, label, x, y, w, fn)
		local b = { frame = frame("Button"), label = label, click = fn }
		function b.setEnabled() end
		function b.setText() end
		table.insert(buttons, b)
		return b
	end,
	scroll = function(parent, x, y, w, h, contentH, barW)
		local s = frame("Scroll")
		s.CanvasSize = UDim2.fromOffset(0, contentH)
		s.CanvasPosition = Vector2.new(0, 0)
		s.ScrollingEnabled = contentH > h
		s.ScrollBarThickness = barW
		s.h = h
		table.insert(scrolls, s)
		return s
	end,
	line = function() return frame("Line") end,
	smallIcon = function() return frame("Icon") end,
})
MOCK("Client/lune/ui/itemCell", {
	size = function() return 40 end,
	icon = function() return "x" end,
	at = function() return nil end,
	over = function() return true end,
	new = function(parent, x, y, onClick)
		local c = { frame = frame("Cell"), parent = parent, x = x, y = y, onClick = onClick }
		c.hit = { InputBegan = { Connect = function(_, fn) c.began = fn end }, MouseEnter = { Connect = function(_, fn) c.enter = fn end }, MouseLeave = { Connect = function(_, fn) c.leave = fn end }, MouseButton2Click = { Connect = function(_, fn) c.right = fn end } }
		function c.set(_, item, o)
			c.item, c.o = item, o
		end
		table.insert(cells, c)
		return c
	end,
})
MOCK("Client/lune/ui/itemDetail", { show = function(_, spec) shown.spec = spec end, hide = function() shown.spec = nil end, pinned = function() return if shown.spec and not shown.spec.peek then shown.pinOwner or "bag" else nil end })
MOCK("Client/lune/ui/windows", { refresh = function() end })

local BagWindow = req("Client/lune/ui/bagWindow")
local bag = { size = 48, gear = {}, use = {}, etc = {}, growCost = false, dust = 0, essence = 0 }
bag.use[1] = { item = "potion1", n = 5 }
local me = { level = 10, money = 100, class = "riven" }
local dragging = false
local ctx = {
	ui = {},
	bag = function() return bag end,
	me = function() return me end,
	send = function() end,
	quick = {
		dragging = function() return dragging end,
		press = function(what, from, input, extra)
			table.insert(presses, { what = what, input = input, extra = extra })
		end,
	},
}
local w, h = BagWindow.size()
local view = BagWindow.build(frame("Body"), ctx, w, h)
for _, b in buttons do
	expect(b.label ~= "▲" and b.label ~= "▼", "▲▼ 단추가 없다(스크롤로 바꿨다) — " .. tostring(b.label))
end
eq(#scrolls, 1, "칸들은 스크롤 틀 하나 안에 있다")
local grid = scrolls[1]
for _, c in cells do
	expect(c.parent == grid, "칸은 스크롤 틀 안에 있다")
end
view.refresh()
local S = 40
eq(#cells, 48, "늘린 가방(48칸)은 칸이 마흔여덟")
expect(grid.ScrollingEnabled == true and grid.ScrollBarThickness > 0, "네 줄을 넘으면 스크롤이 켜지고 막대가 보인다")
eq(grid.CanvasSize.Y.Offset, 8 * S, "스크롤의 속 = 여덟 줄")
eq(cells[1].item and cells[1].item.n, nil, "장비 탭의 첫 칸은 비어 있다")
-- 탭을 바꾸면 맨 위부터
grid.CanvasPosition = Vector2.new(0, 120)
-- (탭 단추의 콜백은 Ui.tab이 받은 fn — 둘째 탭 = 소비)
-- 끌기: 스마트폰에서 잠깐 누르고 있어야 시작한다(가방이 hold를 넘긴다) · 끄는 동안 스크롤이 선다
cells[1].item = nil
view.refresh()
-- 소비 탭으로
local tabs = {}
for _, b in buttons do
	tabs[#tabs + 1] = b
end
-- 24칸이면 스크롤이 꺼진다
bag.size = 24
view.refresh()
expect(grid.ScrollingEnabled == false and grid.ScrollBarThickness == 0, "네 줄이면 스크롤이 없다")
eq(grid.CanvasSize.Y.Offset, 4 * S, "속 = 네 줄")
for i, c in cells do
	if i > 24 then
		eq(c.frame.Visible, false, "넘치는 칸은 숨긴다 " .. i)
	end
end
-- 끌기의 넘김
bag.size = 48
bag.gear[3] = { id = 7, slot = "hat", stage = 1, q = 2, star = 0 } -- (star — 마우스를 올린 칸의 정보가 별의 %를 센다)
view.refresh()
cells[3].item = bag.gear[3]
cells[3].began({ UserInputType = Enum.UserInputType.Touch, Position = Vector2.new(5, 5) })
local p = presses[#presses]
expect(p ~= nil and p.extra and p.extra.hold and p.extra.hold > 0 and p.extra.hold < 1, "스마트폰: 잠깐 누르고 있어야 끈다(hold)")
expect(typeof(p.extra.onStart) == "function", "끌기가 시작되면 알린다")
p.extra.onStart()
eq(grid.ScrollingEnabled, false, "끄는 동안은 스크롤이 선다")
p.extra.onEnd()
eq(grid.ScrollingEnabled, true, "끌기가 끝나면 스크롤이 다시 켜진다")
-- 마우스를 올린 칸(2026-11-13)
do
	bag.equip = {}
	shown.spec = nil
	view.refresh()
	cells[3].enter()
	local ps = shown.spec
	expect(ps ~= nil and ps.item == bag.gear[3] and #ps.buttons == 0, "마우스를 올리면 그 장비의 정보가 뜬다(단추 없이)")
	expect(ps and string.sub(ps.key, 1, 5) == "peek|", "올린 것의 판은 고른 것과 다른 열쇠(다시 그린다)")
	cells[4].enter() -- (빈 칸)
	eq(shown.spec and shown.spec.item, bag.gear[3], "빈 칸에 올려도 그대로(빈 칸은 띄우지 않는다)")
	cells[3].leave()
	eq(shown.spec, nil, "벗어나면 닫힌다")
	cells[3].enter()
	cells[3].onClick(bag.gear[3]) -- 누르면 고른다 → 단추가 붙는다
	view.refresh()
	expect(shown.spec and #shown.spec.buttons > 0 and string.sub(shown.spec.key, 1, 5) ~= "peek|", "누르면 지금처럼 고른다(단추)")
	cells[3].leave()
	expect(shown.spec and #shown.spec.buttons > 0, "고른 것은 마우스가 벗어나도 남는다")
	shown.spec.onClose()
	view.refresh()
	eq(shown.spec, nil, "닫으면 없다")
	-- 손가락: 폰은 누를 때도 MouseEnter가 온다 — 띄우지 않는다
	lastInput = Enum.UserInputType.Touch
	cells[3].enter()
	eq(shown.spec, nil, "손가락이면 띄우지 않는다")
	lastInput = Enum.UserInputType.MouseMovement
	-- 다른 창의 상세가 떠 있으면 띄우지 않는다
	ctx.ui.detail = "equip"
	cells[3].enter()
	eq(shown.spec, nil, "다른 창의 상세가 있으면 띄우지 않는다")
	ctx.ui.detail = nil
	-- 소비 탭의 물약
	expect(BagWindow.canPeek(true, false, false, nil, "bag", "use", false, false), "셈: 마우스 · 빈 상세 · 소비 탭")
	expect(not BagWindow.canPeek(true, false, false, nil, "bag", "cash", false, false), "셈: 캐시 탭은 아니다")
	expect(not BagWindow.canPeek(true, false, false, nil, "bag", "gear", true, false), "셈: 끄는 중은 아니다")
	expect(not BagWindow.canPeek(true, false, true, nil, "bag", "gear", false, false), "셈: 여러 개 분해 중은 아니다")
	expect(not BagWindow.canPeek(true, true, false, "bag", "bag", "gear", false, false), "셈: 고른 것이 있으면 아니다")
	expect(BagWindow.canPeek(true, false, false, "equip", "equip", "equip", false, false), "셈: 장비 창의 것이 떠 있으면 장비 창은 띄운다")
	-- 고른 것이 없으면 주인 표시를 푼다(2026-11-14 검토 — 남아 있으면 다른 창의 마우스 올림이 막혔다)
	ctx.ui.detail = "bag"
	shown.spec = nil
	view.refresh()
	eq(ctx.ui.detail, nil, "고른 것이 없으면 ui.detail = nil")
	-- 다른 창(대장장이 등)이 눌러서 띄운 판이 있으면 마우스 올림이 그 판을 닫지 않는다(2026-11-14 검토)
	local forge = { item = {}, buttons = { {} } }
	shown.spec, shown.pinOwner = forge, "forge"
	cells[3].enter()
	expect(shown.spec == forge, "대장장이의 판이 그대로")
	cells[3].leave()
	shown.spec, shown.pinOwner = nil, nil
	-- 오른쪽 클릭(2026-11-13 — PC: 두 번 누르기와 같은 일): 장비 = 장착 · 빈 칸은 아무것도
	local sent = {}
	local keepSend = ctx.send
	ctx.send = function(...) table.insert(sent, { ... }) end
	view.refresh()
	cells[3].right()
	expect(#sent == 1 and sent[1][1] == "Item" and sent[1][2] == "equip" and sent[1][3] == 7, "장비 칸을 오른쪽 클릭하면 장착한다")
	cells[4].right()
	eq(#sent, 1, "빈 칸의 오른쪽 클릭은 아무것도 하지 않는다")
	ctx.send = keepSend
end
view.destroy()

-- ---- 창고도 늘린 만큼 칸이 있고 스크롤한다(2026-10-18 검토 — 창고 칸을 늘려도(Bag.growStore) 처음 24칸만 지어 25칸부터 보이지도 꺼내지도 못했다) ----
do
	local UiMock = req("Client/lune/ui/ui")
	UiMock.M = { small = 10, body = 12, button = 24, pic = 18 }
	local ShopWindow = req("Client/lune/ui/shopWindow")
	table.clear(cells)
	table.clear(scrolls)
	local storeBag = { size = 24, gear = {}, use = {}, etc = {}, equip = {}, store = { gear = {}, use = {}, etc = {} }, storeSize = 32, growCost = false, dust = 0, essence = 0 }
	storeBag.store.gear[30] = { id = 9, slot = "hat", stage = 1, q = 2, star = 0 }
	local sctx = { ui = {}, bag = function() return storeBag end, me = function() return me end, send = function() end, quick = ctx.quick }
	local sw, sh = ShopWindow.size("store")
	local sview = ShopWindow.build(frame("Body"), sctx, sw, sh, "store")
	sview.refresh()
	eq(#scrolls, 1, "창고의 칸들은 스크롤 틀 하나 안에 있다")
	expect(#cells >= 30 and cells[30].item ~= nil and cells[30].item.id == 9, "늘린 창고(32칸)의 30째 칸이 지어지고 그 물건이 보인다")
	expect(scrolls[1].ScrollingEnabled == true and scrolls[1].ScrollBarThickness > 0, "네 줄을 넘으면 스크롤이 켜진다")
	eq(scrolls[1].CanvasSize.Y.Offset, 6 * 40, "스크롤의 속 = 여섯 줄(32칸)")
	storeBag.storeSize = 24
	storeBag.store.gear[30] = nil
	sview.refresh()
	expect(scrolls[1].ScrollingEnabled == false, "24칸이면 스크롤이 없다")
	-- 끌기: 스마트폰에서 잠깐 누르고 있어야 시작하고, 끄는 동안 스크롤이 선다(가방과 같다)
	storeBag.storeSize = 32
	storeBag.store.gear[2] = { id = 11, slot = "hat", stage = 1, q = 2, star = 0 }
	sview.refresh()
	table.clear(presses)
	cells[2].item = storeBag.store.gear[2]
	cells[2].began({ UserInputType = Enum.UserInputType.Touch, Position = Vector2.new(5, 5) })
	local sp = presses[#presses]
	expect(sp ~= nil and sp.extra.hold and sp.extra.hold > 0 and typeof(sp.extra.onStart) == "function", "창고의 끌기도 잠깐 누르고 있어야 시작한다")
	sp.extra.onStart()
	eq(scrolls[1].ScrollingEnabled, false, "끄는 동안 창고의 스크롤이 선다")
	sp.extra.onEnd()
	-- 마우스를 올린 칸(2026-11-13 — 가방과 같다): 정보만 · 벗어나면 닫힘
	shown.spec = nil
	sview.refresh()
	cells[2].enter()
	expect(shown.spec ~= nil and shown.spec.item == storeBag.store.gear[2] and #shown.spec.buttons == 0, "창고: 마우스를 올리면 정보만")
	cells[2].leave()
	eq(shown.spec, nil, "창고: 벗어나면 닫힌다")
	sview.destroy()
end

-- ---- 가방의 캐시 탭(2026-10-21 사용자 "인벤토리 가방에 캐시 탭을 넣던지 방법을 고안해서 펫을꺼내거나 넣는것, 라이딩을 타거나 내리는것 다 가능해야하고") ----
--  가진 펫 · 탈것이 칸에(꺼내 둔 것은 on) · 누르면 상세 판의 「꺼내기 · 넣기」 / 「타기 · 내리기」 · 「퀵슬롯」 · 두 번 누르면 바로 · 끌면 퀵슬롯에 그 이름표 · 정렬 · 늘리기는 없다
do
	local BMW = req("ReplicatedStorage/shared/lune/data/bm.generated").shop.words
	table.clear(cells)
	table.clear(buttons)
	table.clear(madeTabs)
	table.clear(presses)
	local calls = {}
	local cashView = nil
	local fetched = 0
	local cctx = setmetatable({
		cash = function() return cashView end,
		cashFetch = function() fetched += 1 end,
		myPet = function() return "pet_silver" end,
		myRide = function() return nil end,
		togglePet = function(id) table.insert(calls, { "pet", id }) end,
		petOne = function(id, add) table.insert(calls, { if add then "petAdd" else "petOff", id }) end,
		toggleRide = function(id) table.insert(calls, { "ride", id }) end,
		cashProduct = function(id) return { name = "이름 " .. id, line = "설명" } end,
	}, { __index = ctx })
	bag.size = 24
	local bview = BagWindow.build(frame("Body"), cctx, w, h)
	bview.refresh()
	eq(#madeTabs, 4, "가방의 탭은 넷(장비 · 소비 · 기타 · 캐시)")
	eq(madeTabs[4].name, BMW.bagTab, "넷째 탭 = 「캐시」")
	madeTabs[4].click()
	eq(fetched, 1, "캐시 탭을 처음 열면 가진 펫 · 탈것을 서버에 묻는다")
	cashView = { pets = { "pet_silver", "pet_scarf" }, mounts = { "mount_wolf" }, petOut = "pet_silver", mount = "mount_wolf" }
	bview.refresh()
	expect(cells[1].item and cells[1].item.ride == "pet_silver" and cells[1].item.on == true, "첫 칸 = 꺼내 둔 은빛 달토끼(점)")
	expect(cells[2].item and cells[2].item.ride == "pet_scarf" and not cells[2].item.on, "둘째 칸 = 목도리 달토끼")
	expect(cells[3].item and cells[3].item.ride == "mount_wolf" and cells[3].item.kind == "mount", "셋째 칸 = 달빛 늑대")
	eq(cells[4].item, nil, "그 뒤는 빈 칸")
	local sortB, growB
	for _, b in buttons do
		if b.label == "" then
			growB = b
		else
			sortB = sortB or b
		end
	end
	expect(sortB and sortB.frame.Visible == false, "캐시 탭에는 「정렬」이 없다")
	-- 누르면 상세 판: 「넣기」(꺼내 둔 펫) · 「퀵슬롯」
	cells[1].onClick(cells[1].item)
	bview.refresh()
	expect(shown.spec and shown.spec.buttons[1].text == BMW.petOff and shown.spec.buttons[2] ~= nil, "꺼내 둔 펫의 상세 = 「넣기」 · 「퀵슬롯」")
	shown.spec.buttons[1].onClick()
	expect(calls[#calls][1] == "pet" and calls[#calls][2] == "pet_silver", "「넣기」 → 그 펫을 넣는다")
	cells[3].onClick(cells[3].item)
	bview.refresh()
	eq(shown.spec and shown.spec.buttons[1].text, BMW.rideOn, "타지 않은 탈것 = 「타기」")
	shown.spec.buttons[1].onClick()
	expect(calls[#calls][1] == "ride" and calls[#calls][2] == "mount_wolf", "「타기」 → 그 탈것을 탄다")
	-- 두 번 누르기 = 바로
	local before = #calls
	cells[2].onClick(cells[2].item)
	cells[2].onClick(cells[2].item)
	expect(#calls == before + 1 and calls[#calls][2] == "pet_scarf", "두 번 누르면 그 펫을 꺼낸다")
	-- 끌기: 퀵슬롯에 놓을 이름표
	cells[3].began({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(5, 5) })
	eq(presses[#presses] and presses[#presses].what, "mount_wolf", "끌면 퀵슬롯에 그 탈것의 이름표")
	-- 같은 것을 여럿 가졌다(2026-11-10 뽑기의 「하나 더」): 칸에 가진 수 · 펫은 「더 꺼내기」 · 「하나 넣기」(하나씩) · 다른 것은 그대로
	cashView = { pets = { "pet_silver", "pet_scarf" }, mounts = { "mount_wolf" }, petsOut = { "pet_silver", "pet_silver" }, petOut = "pet_silver", mount = "mount_wolf", extra = { pet_silver = 1, mount_wolf = 2 } }
	cctx.myPets = function() return cashView.petsOut end
	bview.refresh()
	expect(cells[1].item and cells[1].item.n == 2 and cells[1].item.out == 2 and cells[1].item.on == true, "은빛 달토끼 = 가진 수 2 · 둘 다 꺼냄")
	eq(cells[2].item and cells[2].item.n, 1, "목도리 달토끼 = 하나")
	eq(cells[3].item and cells[3].item.n, 3, "달빛 늑대 = 셋")
	cells[1].onClick(cells[1].item)
	bview.refresh()
	local sp = shown.spec
	expect(sp and sp.buttons[1].text == BMW.petMore and sp.buttons[1].off == true, "둘 다 꺼냈으면 「더 꺼내기」는 꺼짐")
	expect(sp and sp.buttons[2].text == BMW.petLess and not sp.buttons[2].off, "「하나 넣기」")
	expect(sp and sp.buttons[3] ~= nil and #sp.buttons == 3, "「퀵슬롯」까지 셋")
	expect(sp and string.find(sp.info.sub, "2", 1, true) ~= nil, "부제에 가진 수 " .. tostring(sp and sp.info.sub))
	sp.buttons[2].onClick()
	expect(calls[#calls][1] == "petOff" and calls[#calls][2] == "pet_silver", "「하나 넣기」 → 하나만")
	cashView.petsOut = { "pet_silver" }
	bview.refresh()
	sp = shown.spec
	expect(sp and sp.buttons[1].text == BMW.petMore and not sp.buttons[1].off, "하나 꺼냈으면 「더 꺼내기」가 켜진다")
	sp.buttons[1].onClick()
	expect(calls[#calls][1] == "petAdd" and calls[#calls][2] == "pet_silver", "「더 꺼내기」 → 하나 더")
	cashView.petsOut = {}
	bview.refresh()
	eq(shown.spec and shown.spec.buttons[1].text, BMW.petOn, "하나도 안 꺼냈으면 「꺼내기」")
	cells[3].onClick(cells[3].item)
	bview.refresh()
	eq(shown.spec and shown.spec.buttons[1].text, BMW.rideOn, "탈것은 수가 많아도 「타기」 그대로")
	cctx.myPets = nil
	-- 한 화면(24칸)을 넘게 가지면(2026-11-10 사용자 "캐시칸이 적어서 그냥 템 증발해버리는데" — 전에는 스물다섯 번째부터 그려지지 않았다): 칸을 더 만들고 밀어서 본다
	local many = {}
	for i = 1, 31 do
		table.insert(many, "dskin_" .. i)
	end
	cashView = { pets = { "pet_silver", "pet_scarf" }, mounts = { "mount_wolf" }, petOut = "pet_silver", mount = "mount_wolf", dskins = many, dskin = "dskin_1" }
	bview.refresh()
	local G = scrolls[#scrolls]
	local shownN, last = 0, nil
	for _, c in cells do
		if c.frame.Visible and c.item then
			shownN += 1
			last = c.item
		end
	end
	eq(shownN, 34, "가진 것 서른넷이 모두 칸에 있다(펫 둘 · 탈것 하나 · 데미지 스킨 서른하나)")
	expect(last and last.ride == "dskin_31", "마지막 칸 = 서른한 번째 데미지 스킨")
	expect(G.ScrollingEnabled == true and G.ScrollBarThickness > 0, "한 화면을 넘으면 밀 수 있다")
	eq(G.CanvasSize.Y.Offset, math.ceil(34 / BAG.cols) * 40, "밀기 속 = 가진 것의 줄 수")
	cashView = { pets = { "pet_silver" }, mounts = {} }
	bview.refresh()
	expect(G.ScrollingEnabled == false and G.ScrollBarThickness == 0, "적게 가지면 밀기가 꺼진다")
	bview.destroy()
end
