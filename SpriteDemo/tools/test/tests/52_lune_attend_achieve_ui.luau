-- 「달의 계승자」 — 출석 · 업적 창을 화면 없이 돌려 본다(client/lune/ui/attendWindow.luau · achieveWindow.luau — 2026-10-15).
--  모양은 공방 시험 탭의 paintAttend · paintAchieve와 같다. 보는 것:
--   출석: 칸 28 · 받은 칸 「받음」(그림 없음) · 받을 칸은 테두리 · 큰 칸 ★ · 아래 줄 = 받을 칸들을 더한 것 · 칸을 누르면 그 칸 · 「받기」가 서버에 묻는다 · 가방이 차면 빨간 알림 · 받을 것이 없으면 흐림
--   업적: 점수 · 등급 · 다음 등급 · 탭 여섯 · 줄의 차례(받을 것 → 하는 중 → 받은 것) · 안 보이는 단계는 없다 · 숨김은 「???」 · 「받기」 · 「모두 받기」 · 스크롤 · 탭을 바꾸면 맨 위
local ATT = req("ReplicatedStorage/shared/lune/data/attend.generated")
local ACH = req("ReplicatedStorage/shared/lune/data/achieve.generated")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")

local made = {}
local function frame(name)
	local f = { Name = name, Visible = true, children = {}, Position = nil }
	function f:Destroy() end
	return f
end
local texts, buttons, slots, tabs, scrolls, hits = {}, {}, {}, {}, {}, {}
local function text(_, value, x, y, width, opts)
	local t = { value = value, x = x, y = y, width = width, shown = true, opts = opts or {} }
	t.label = { maxW = width }
	function t.label.SetMaxWidth(_, w)
		t.label.maxW = w
	end
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
local COLOR = setmetatable({}, { __index = function(_, k) return k end }) -- 색 = 그 이름(검사가 읽기 쉽게)
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	M = { small = 10, smallLine = 14, body = 12, button = 26 },
	measure = function(t) return #t * 3 end,
	text = text,
	group = function(parent, x, y, w, h, name)
		local f = frame(name)
		f.x, f.y = x, y
		return f
	end,
	slot = function(parent, x, y, s)
		local it = { frame = frame("Slot"), on = false, x = x, y = y }
		function it.setOn(_, on)
			it.on = on
		end
		table.insert(slots, it)
		return it
	end,
	smallIcon = function(parent, name, x, y)
		local f = frame("Icon")
		f.icon, f.parent = name, parent
		table.insert(made, f)
		return f
	end,
	pic = function(parent, name, x, y)
		local f = frame("Pic")
		f.pic = name
		return f
	end,
	setPic = function(label, name)
		label.pic = name
		label.Visible = name ~= nil
	end,
	setWorldIcon = function(label, name)
		label.icon = name
	end,
	hit = function(parent)
		local h = { Activated = { Connect = function(_, fn) table.insert(hits, { parent = parent, fn = fn }) end } }
		return h
	end,
	line = function() return frame("Line") end,
	box = function() return frame("Box") end,
	button = function(parent, label, x, y, w, fn, opts)
		local b = { frame = frame("Button"), label = label, click = fn, enabled = true, x = x, y = y, w = w, opts = opts }
		function b.setEnabled(_, on)
			b.enabled = on
		end
		function b.setText(_, v)
			b.label = v
		end
		table.insert(buttons, b)
		return b
	end,
	bar = function(parent, x, y, w, h)
		local b = { frame = frame("Bar"), ratio = 0 }
		function b.set(_, r)
			b.ratio = r
		end
		function b.setColor(_, c)
			b.tint = c
		end
		return b
	end,
	tab = function(parent, label, x, y, fn)
		local t = { frame = frame("Tab"), label = label, click = fn, width = #label * 3, on = false }
		function t.setOn(_, on)
			t.on = on
		end
		table.insert(tabs, t)
		return t
	end,
	scroll = function(parent, x, y, w, h, contentH, barW)
		local s = frame("Scroll")
		s.CanvasSize = UDim2.fromOffset(0, contentH)
		s.CanvasPosition = Vector2.new(0, 0)
		s.ScrollingEnabled = true
		s.ScrollBarThickness = barW
		table.insert(scrolls, s)
		return s
	end,
})

-- ---- 출석 ----
local AttendWindow = req("Client/lune/ui/attendWindow")
local sw, sh = AttendWindow.size()
eq(sw, Layout.ATTEND.w, "창의 폭 = 공방의 칸")
expect(sh + 44 + 14 + 16 <= 432, ("스마트폰의 화면 틀(432)에 들어간다 — %d"):format(sh + 74))
local attend = { month = 10, n = 12, got = 9, days = 28, today = true }
local asked = {}
local actx = {
	attend = function() return attend end,
	me = function() return { level = 12 } end,
	attendDo = function(action)
		table.insert(asked, action)
		attend = { month = 10, n = 12, got = 12, days = 28, today = true }
		return { view = attend, got = 3 }
	end,
}
local body = frame("Body")
local view = AttendWindow.build(body, actx, sw, sh)
eq(#slots, 28, "칸 스물여덟")
for k = 1, 28 do
	eq(slots[k].on, k > 9 and k <= 12, "받을 칸만 테두리 " .. k)
end
local function textOf(v)
	for _, t in texts do
		if t.value == v and t.shown then
			return t
		end
	end
	return nil
end
local takenShown = 0
for _, t in texts do
	if t.value == ATT.words.taken and t.shown then
		takenShown += 1
	end
end
eq(takenShown, 9, "받은 칸 아홉에 「받음」")
expect(textOf("10월 출석 12/28") ~= nil, "머리글")
expect(textOf("받을 칸 3") ~= nil, "아래 줄의 이름표 = 받을 칸 수")
local sumText = nil
for _, t in texts do
	if t.opts.color == "gold" and t.value and string.find(t.value, "달가루", 1, true) then
		sumText = t.value
	end
end
-- 10 · 11 · 12일을 더한 것
local want = {}
for k = 10, 12 do
	for key, n in ATT.rewards[k] do
		want[key] = (want[key] or 0) + n
	end
end
expect(sumText ~= nil and (want.dust == nil or string.find(sumText, "달가루 " .. want.dust, 1, true)), "받을 칸들을 더한 보상 — " .. tostring(sumText))
local stars = 0
for _, f in made do
	if f.icon == "star" then
		stars += 1
	end
end
eq(stars, #ATT.big, "큰 칸에 ★")
-- 칸을 누르면 그 칸
hits[20].fn()
expect(textOf("20일") ~= nil, "칸을 누르면 그 날")
hits[20].fn()
expect(textOf("받을 칸 3") ~= nil, "한 번 더 누르면 받을 것으로")
-- 받기
local take
for _, b in buttons do
	if b.label == ATT.words.take then
		take = b
	end
end
expect(take and take.enabled, "받을 것이 있으면 「받기」")
take.click()
eq(asked[1], "claim", "서버에 받기를 묻는다")
expect(textOf(ATT.words.got) ~= nil, "받았다는 알림")
expect(not take.enabled, "다 받으면 흐림")
-- 가방이 차면
actx.attendDo = function()
	return { view = { month = 10, n = 12, got = 10, days = 28 }, got = 1, why = "가방이 가득 찼다" }
end
attend = { month = 10, n = 12, got = 9, days = 28 }
view.refresh()
take.click()
local fullText = nil
for _, t in texts do
	if t.tint == "red" and t.shown then
		fullText = t.value
	end
end
expect(fullText ~= nil and string.find(fullText, "2", 1, true) ~= nil, "가방이 차면 남긴 칸 수를 빨갛게 — " .. tostring(fullText))

-- ---- 업적 ----
table.clear(texts)
table.clear(buttons)
table.clear(tabs)
local AchieveWindow = req("Client/lune/ui/achieveWindow")
local aw, ah = AchieveWindow.size()
expect(ah + 44 + 14 + 16 <= 432, ("스마트폰의 화면 틀에 들어간다 — %d"):format(ah + 74))
local rows = {}
for _, def in ACH.list do
	rows[def.id] = { have = 0, need = 10, st = if def.after then 0 else 1 }
end
rows.lv10 = { have = 10, need = 10, st = 3 }
rows.lv20 = { have = 20, need = 20, st = 2 }
rows.lv30 = { have = 22, need = 30, st = 1 }
rows.death1 = { have = 0, need = 1, st = 1 }
rows.fail1 = { have = 1, need = 1, st = 2 }
local ach = { score = 160, rows = rows }
local calls = {}
local cctx = {
	ach = function() return ach end,
	me = function() return { level = 12 } end,
	achDo = function(action, id)
		table.insert(calls, { action, id })
		if action == "claim" then
			rows[id].st = 3
		else
			for _, r in rows do
				if r.st == 2 then
					r.st = 3
				end
			end
		end
		return { view = ach, got = 1 }
	end,
}
local av = AchieveWindow.build(frame("Body2"), cctx, aw, ah)
eq(#tabs, #ACH.tabs, "탭 여섯")
expect(tabs[1].on, "처음은 성장 탭")
expect(textOf("업적 점수 160") ~= nil, "점수")
expect(textOf("실버 등급") ~= nil, "160점 = 실버")
expect(textOf("골드까지 140점") ~= nil, "다음 등급까지")
local order = AchieveWindow.rows(ach, "grow")
eq(order[1].def.id, "lv20", "받을 것이 맨 위")
eq(order[#order].def.id, "lv10", "받은 것은 맨 아래")
for _, r in order do
	expect(r.st > 0, "앞 단계를 해내지 않은 단계는 보이지 않는다 " .. r.def.id)
end
-- 숨김
tabs[6].click()
expect(tabs[6].on and not tabs[1].on, "기타 탭")
expect(textOf(ACH.words.hidden) ~= nil, "숨김 업적은 「???」")
local failRow = AchieveWindow.rows(ach, "etc")[1]
eq(failRow.def.id, "fail1", "해낸 숨김 업적은 받을 것으로 맨 위(이름이 보인다)")
-- 받기 · 모두 받기
local takeRow
for _, b in buttons do
	if b.label == ACH.words.take and b.frame.Visible then
		takeRow = b
		break
	end
end
expect(takeRow ~= nil, "해낸 줄에 「받기」")
takeRow.click()
eq(calls[1][1], "claim", "서버에 받기를 묻는다")
eq(calls[1][2], "fail1", "그 업적")
local all
for _, b in buttons do
	if b.label == ACH.words.takeAll then
		all = b
	end
end
expect(all and all.enabled, "남은 받을 것(Lv.20)이 있으면 「모두 받기」")
all.click()
eq(calls[2][1], "all", "모두 받기")
expect(not all.enabled, "다 받으면 흐림")
-- 스크롤 · 탭을 바꾸면 맨 위
local list = scrolls[#scrolls]
list.CanvasPosition = Vector2.new(0, 46)
tabs[2].click()
eq(list.CanvasPosition, Vector2.zero, "탭을 바꾸면 맨 위부터")
-- 등급
local g0 = AchieveWindow.gradeOf(0)
eq(g0, nil, "0점은 등급 없음")
local gTop, nTop, left, ratio = AchieveWindow.gradeOf(999)
eq(gTop, ACH.grades[#ACH.grades].name, "가장 높은 등급")
eq(nTop, nil, "그 위는 없다")
eq(ratio, 1, "띠가 가득")
