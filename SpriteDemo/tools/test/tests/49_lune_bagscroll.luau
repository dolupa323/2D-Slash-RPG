-- 「달의 계승자」 — 가방의 칸이 스크롤된다(2026-10-15, client/lune/ui/bagWindow.luau를 화면 없이 돌려 본다).
--  사용자: "인벤토리 위아래 버튼으로 움직이는게아니라 스크롤이어야합니다. 모바일에서도 정상작동하게"
--  보는 것: ▲▼ 단추가 없다 · 칸들이 스크롤 틀 안에 있다 · 늘린 가방(48칸)은 칸이 다 있고 스크롤이 켜진다 · 24칸이면 꺼진다 · 탭을 바꾸면 맨 위로 ·
--   스마트폰에서 끌기는 잠깐 누르고 있어야 시작한다(가방이 hold를 넘긴다) · 끄는 동안 스크롤이 선다
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local BAG = Layout.BAG

local buttons, scrolls, cells, presses = {}, {}, {}, {}
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
		local t = { width = 40, click = fn }
		function t.setOn() end
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
MOCK("Client/lune/ui/itemDetail", { show = function() end, hide = function() end })
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
