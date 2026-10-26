-- 「달의 계승자」 — 개인 연무장의 피해 측정 판(client/lune/dpsMeter.luau)을 화면 없이 돌려 본다(2026-10-26).
--  보는 것: 연무장 밖에서는 재지 않는다 · 첫 타에 재기 시작 · 누적 · 초당 피해 = 누적 ÷ 잰 시간 · 가장 큰 한 방 · idle초 동안 치지 않으면 멈춤(잰 시간이 서) · 다음 타 = 새 판 · 「초기화」 · 나가면 지움
local function frame(name)
	local f = { Name = name, Visible = true, Size = UDim2.fromOffset(1, 1), Position = UDim2.fromOffset(0, 0) }
	function f:FindFirstChild() return nil end
	return f
end
local texts = {}
local function textItem(t)
	local it = { text = t }
	function it.set(_, v) it.text = v end
	function it.color() end
	table.insert(texts, it)
	return it
end
local clicks = {}
MOCK("Client/lune/stage", { uiW = 960, uiH = 540, onResize = function() end })
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end }),
	M = { body = 12, small = 9, bodyLine = 16, button = 26 },
	group = function(_, x, y, w, h, name) return frame(name or "Group") end,
	panel = function() return frame("Panel") end,
	text = function(_, t) return textItem(t) end,
	button = function(_, text, x, y, w, fn) local b = { frame = frame("Button") } clicks[text] = fn return b end,
})
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local D = Layout.DOJO
local Meter = req("Client/lune/dpsMeter")
Meter.init(frame("Hud"))

Meter.add(500, 1)
eq(Meter.stats(2).total, 0, "연무장 밖에서는 재지 않는다")
Meter.show(true)
eq(Meter.stats(0).total, 0, "처음에는 비어 있다")
Meter.add(100, 10)
Meter.add(300, 11)
Meter.add(200, 12)
local s = Meter.stats(12)
eq(s.total, 600, "누적 피해")
eq(s.top, 300, "가장 큰 한 방")
eq(s.time, 2, "잰 시간 = 첫 타부터")
eq(s.dps, 300, "초당 피해 = 누적 ÷ 잰 시간")
eq(Meter.stats(14).dps, 150, "치지 않는 동안에도 시간이 흐른다(멈추기 전)")
-- idle초 동안 치지 않으면 멈춘다(잰 시간 = 마지막 타까지)
Meter.paint(12 + D.idle + 0.1, true)
local st = Meter.stats(100)
expect(st.stopped and st.time == 2 and st.dps == 300, ("%d초 동안 치지 않으면 멈춘다(마지막 타까지 — %s초)"):format(D.idle, tostring(st.time)))
-- 다음 타 = 새 판
Meter.add(50, 200)
local n = Meter.stats(200)
expect(n.total == 50 and n.top == 50 and not n.stopped, "멈춘 뒤의 첫 타는 새로 잰다")
-- 「초기화」
clicks[D.words.reset]()
eq(Meter.stats(201).total, 0, "「초기화」를 누르면 지운다")
-- 1초가 안 되면 초당 피해 = 누적 그대로(0으로 나누지 않는다)
Meter.add(70, 300)
eq(Meter.stats(300.5).dps, 70, "1초가 안 되면 누적 그대로")
-- 나가면 지운다
Meter.show(false)
Meter.show(true)
eq(Meter.stats(400).total, 0, "연무장을 나가면 판을 지운다")
-- 안내 글이 판의 폭 안에 든다(글자 수 — 작은 글씨 한 글자 9점까지로 어림)
for _, key in { "hint", "done" } do
	local t = string.gsub(D.words[key], "{n}", tostring(D.idle))
	expect(utf8.len(t) * 9 <= D.w - D.pad * 2, ("안내 「%s」이 판의 폭(%d) 안에 든다"):format(t, D.w - D.pad * 2))
end
