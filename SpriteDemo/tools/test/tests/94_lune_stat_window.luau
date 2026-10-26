-- 「달의 계승자」 — 능력치 창(client/lune/ui/statWindow.luau)을 화면 없이 짓고 채워 본다(2026-10-26).
--  까닭: 사용자 "스텟창 버그났잖아 … 능력치 열면 아예고장나는데" — 「칭호」 줄을 넣으며 글 칸(Ui.text)에 없는 .frame을 적어 창을 짓다 멈췄다(능력치 이름 · 숫자 · 「자동으로 찍기」가 비었다).
--   그때까지 능력치 창을 짓는 시험이 없었다. 가짜 부품은 진짜와 같은 모양이다 — 없는 칸을 읽으면 바로 오류(진짜 Ui.text는 label · set · color · move · show · size만 있다)
NumberSequence = { new = function(a, b) return { a, b } end }
local function frame(name)
	local f = { Name = name, Visible = true, ZIndex = 1, Size = UDim2.fromOffset(1, 1), Position = UDim2.fromOffset(0, 0), AbsolutePosition = Vector2.new(400, 100), children = {} }
	function f:Destroy() end
	function f:GetPropertyChangedSignal() return { Connect = function() end } end
	return f
end
local function strict(t, what)
	return setmetatable(t, { __index = function(_, k)
		error(("%s에 없는 칸 「%s」을 읽었다"):format(what, tostring(k)), 2)
	end })
end
local texts = {}
local function textItem(t)
	local label = { Frame = frame("Text"), Width = 40, Height = 12 }
	local it = { label = label, text = t, shown = true }
	function it.set(_, v) it.text = v end
	function it.color(_, c) it.c = c end
	function it.move() end
	function it.show(_, on) it.shown = on end
	function it.size() return 40, 12 end
	function it.destroy() end
	table.insert(texts, it)
	return strict(it, "글 칸(Ui.text)")
end
local buttons = {}
MOCK("Client/lune/stage", { uiW = 960, uiH = 540, uiScale = 1, ui = frame("Ui") })
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end }),
	M = { body = 12, small = 9, bodyLine = 16, smallLine = 13, button = 26 },
	WIN = { pad = 12 },
	group = function(_, x, y, w, h, name) return frame(name or "Group") end,
	part = function(_, name) return frame(name) end,
	box = function() return frame("Box") end,
	line = function() return frame("Line") end,
	text = function(_, t) return textItem(t) end,
	button = function(_, text, x, y, w, onClick)
		local b = { frame = frame("Button"), click = onClick, text = text, enabled = true }
		function b.setText(_, v) b.text = v end
		function b.setEnabled(_, on) b.enabled = on end
		function b.setMain() end
		buttons[text] = b
		return strict(b, "단추(Ui.button)")
	end,
	measure = function(t) return #t * 4 end,
})
local StatWindow = req("Client/lune/ui/statWindow")
local Titles = req("ReplicatedStorage/shared/lune/sim/titles")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local sent = {}
local ctx = { send = function(...) table.insert(sent, { ... }) end }
local w, h = StatWindow.size()
local ok, view = pcall(StatWindow.build, frame("Body"), ctx, w, h)
expect(ok, "능력치 창을 끝까지 짓는다 — " .. tostring(view))
if ok then
	local me = { class = "riven", level = 150, ap = 5, stats = { str = 10, dex = 0, int = 0, luk = 0, hp = 0 }, power = 12345, maxHp = 9999,
		sheet = nil, titles = { "max1", "max10" }, title = "max1" }
	local ok2, err = pcall(view.refresh, me)
	expect(ok2, "내 상태로 채운다 — " .. tostring(err))
	local function has(text)
		for _, it in texts do
			if it.text == text then
				return true
			end
		end
		return false
	end
	expect(has("남은 점수 5"), "남은 점수가 적힌다")
	for _, id in N.data.STATS.order do
		expect(has(N.data.STATS.names[id]), "능력치 이름 " .. N.data.STATS.names[id])
	end
	expect(has(Titles.def("max1").name), "단 칭호의 이름이 적힌다")
	expect(buttons["자동으로 찍기"] ~= nil and buttons["자동으로 찍기"].enabled, "「자동으로 찍기」가 있고 눌린다")
	-- 「바꾸기」 = 다음 칭호(1위 → 열 사람)
	local change = buttons[Titles.WORDS.change]
	expect(change ~= nil and change.enabled, "칭호 「바꾸기」가 눌린다")
	if change then
		change.click()
		local last = sent[#sent]
		expect(last and last[1] == "Title" and last[2] == "max10", "「바꾸기」 = 다음 칭호를 서버에 보낸다")
	end
	-- 칭호가 없으면 「없음」 · 단추가 꺼진다
	me.titles, me.title = {}, false
	view.refresh(me)
	expect(has(Titles.WORDS.none), "칭호가 없으면 「없음」")
	expect(change and not change.enabled, "칭호가 없으면 「바꾸기」가 꺼진다")
end
