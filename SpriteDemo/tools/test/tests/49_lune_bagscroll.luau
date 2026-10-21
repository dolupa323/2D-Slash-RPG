-- 「달의 계승자」 — 가방의 칸이 스크롤된다(2026-10-15, client/lune/ui/bagWindow.luau를 화면 없이 돌려 본다).
--  사용자: "인벤토리 위아래 버튼으로 움직이는게아니라 스크롤이어야합니다. 모바일에서도 정상작동하게"
--  보는 것: ▲▼ 단추가 없다 · 칸들이 스크롤 틀 안에 있다 · 늘린 가방(48칸)은 칸이 다 있고 스크롤이 켜진다 · 24칸이면 꺼진다 · 탭을 바꾸면 맨 위로 ·
--   스마트폰에서 끌기는 잠깐 누르고 있어야 시작한다(가방이 hold를 넘긴다) · 끄는 동안 스크롤이 선다
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
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
	tab = function(parent, name, x, y, fn)
		local t = { width = 40, click = fn, name = name }
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
		c.hit = { InputBegan = { Connect = function(_, fn) c.began = fn end } }
		function c.set(_, item, o)
			c.item, c.o = item, o
		end
		table.insert(cells, c)
		return c
	end,
})
MOCK("Client/lune/ui/itemDetail", { show = function(_, spec) shown.spec = spec end, hide = function() shown.spec = nil end })
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
bag.gear[3] = { id = 7, slot = "hat", stage = 1, q = 2 }
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
	bview.destroy()
end
