-- 「달의 계승자」 — 수량 창(client/lune/ui/countBox.luau · shared/lune/ui/countPick.luau · 2026-10-21).
--  사용자: "잡화상점에서 물약이나 달가루 구매할때 1개 아니면 10개밖에 못사잖아 이거 수량 입력하는 모달 받아서 처리해야지 이렇게하면안되는거야 모든 곳에서 수량받아서 처리해"
--  보는 것: ① 적은 글 고르기(숫자만 · 맨 앞 0 · 최대를 넘으면 최대) ② 처음 수 · 가장 많은 수(나누기 · 사기 = 달돈 · 가방의 자리) ③ 가방 · 창고에 더 들어가는 수(서버의 셈과 같다)
--   ④ 창: 적고 확인 → 그 수로 · 비면 확인이 안 된다 · [−] [+] [최대] · Enter · 취소 · 달돈이 모자라면 확인이 안 된다 · 창의 주인이 닫히면 같이 닫힌다
--   ⑤ 글이 칸에 들어간다 · 줄의 치수 ⑥ 상점에 「1 · 10」 단추가 없고 모든 곳이 수량 창을 쓴다
local CountPick = req("ReplicatedStorage/shared/lune/ui/countPick")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")

-- ① 적은 글
local function parse(text, hi)
	local t, n = CountPick.parse(text, hi)
	return t .. "|" .. tostring(n)
end
eq(parse("12", 99), "12|12", "숫자 그대로")
eq(parse("1a2", 99), "12|12", "숫자만")
eq(parse("005", 99), "5|5", "맨 앞의 0은 뗀다")
eq(parse("150", 99), "99|99", "최대를 넘으면 최대로")
eq(parse("", 99), "|nil", "비면 수가 없다")
eq(parse("0", 99), "|nil", "0은 수가 아니다")
eq(parse("123456", 9999), "9999|9999", "아무리 길게 적어도 최대로")
-- ② 처음 수 · 가장 많은 수
eq(CountPick.hi("split", 10), 9, "나누기는 하나를 남긴다")
eq(CountPick.hi("discard", 10), 10, "버리기는 그 칸의 전부까지")
eq(CountPick.first("buy", 99), 1, "사기는 처음 1")
eq(CountPick.first("split", 9), 5, "나누기는 처음 절반(10개 → 5)")
eq(CountPick.first("sell", 10), 10, "팔기 · 버리기 · 맡기기 · 찾기는 처음 전부")
eq(CountPick.buyMax(99, 100, 1250, nil), 12, "달돈으로 살 수 있는 만큼")
eq(CountPick.buyMax(99, 100, 1e9, 40), 40, "가방에 들어가는 만큼")
eq(CountPick.buyMax(10, 100, 1e9, nil), 10, "한 번에 파는 수까지")
eq(CountPick.buyMax(99, 100, 50, nil), 0, "하나도 못 사면 0")
eq(CountPick.step(nil, 1, 1, 9), 1, "비어 있으면 [+]는 1")
eq(CountPick.step(9, 1, 1, 9), 9, "최대에서 [+]는 그대로")
eq(CountPick.step(1, -1, 1, 9), 1, "1에서 [−]는 그대로")

-- ③ 더 들어가는 수: 보낸 것(Bag.view)의 셈 = 서버의 셈(Bag.room)
do
	local h = Hero.new(1, "riven")
	Bag.init(h)
	local potion = nil
	for _, s in Items.data.STOCK do
		if s.goods and not potion then
			potion = s.goods
		end
	end
	potion = potion or "potion1"
	Bag.give(h, potion, 7)
	local view = Bag.view(h)
	eq(Bag.roomInView(view, potion), Bag.room(h, potion), "가방에 더 들어가는 수 = 서버의 셈")
	expect(Bag.storeRoomInView(view, potion) > 0, "빈 창고에는 들어간다")
end

-- ④ 창
local function signal()
	local sig = { fns = {} }
	function sig:Connect(fn)
		table.insert(self.fns, fn)
		return { Disconnect = function() end }
	end
	function sig:Fire(...)
		for _, f in self.fns do
			f(...)
		end
	end
	return sig
end
local buttons, texts, fields = {}, {}, {}
local function frame(name)
	return { Name = name, Visible = true, Destroy = function(self) self.dead = true end }
end
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function(_, k) return k end }),
	M = { small = 10, body = 12, button = 26, smallLine = 14 },
	panel = function() return frame("Panel") end,
	slot = function() return { frame = frame("Slot") } end,
	smallIcon = function() return frame("Icon") end,
	text = function(_, text)
		local t = { text = text, tone = nil }
		function t:set(v) self.text = v end
		function t:color(c) self.tone = c end
		function t:show() end
		table.insert(texts, t)
		return t
	end,
	button = function(_, text, _x, _y, _w, onClick)
		local b = { text = text, onClick = onClick, enabled = true, frame = frame("Button") }
		function b:setEnabled(v) self.enabled = v end
		buttons[#buttons + 1] = b
		return b
	end,
	field = function()
		local changed = signal()
		local f = { FocusLost = signal(), Name = "Field", TextXAlignment = nil }
		local store = { Text = "" }
		f.GetPropertyChangedSignal = function() return changed end
		f.CaptureFocus = function() end
		setmetatable(f, {
			__index = function(_, k) return store[k] end,
			__newindex = function(_, k, v)
				local old = store[k]
				store[k] = v
				if k == "Text" and old ~= v then
					changed:Fire()
				end
			end,
		})
		table.insert(fields, f)
		return f
	end,
})
local groups = {}
MOCK("Client/lune/stage", { ui = frame("Ui"), group = function(_, name)
	local g = frame(name)
	table.insert(groups, g)
	return g
end })
SERVICE("UserInputService", { TouchEnabled = false, KeyboardEnabled = true })
local CountBox = req("Client/lune/ui/countBox")
local function find(text)
	for i = #buttons, 1, -1 do
		if buttons[i].text == text then
			return buttons[i]
		end
	end
	return nil
end
local W = UI.words
local KW = UI.layout.count.words
local got = nil
local function open(spec)
	table.clear(buttons)
	table.clear(texts)
	table.clear(fields)
	got = nil
	spec.onYes = function(n)
		got = n
	end
	return CountBox.open(spec)
end
-- 사기: 처음 1 · 적은 수로 산다
open({ owner = "shop", kind = "buy", icon = "potion", name = "작은 달빛 물약", hi = 40, each = 50, money = 100000 })
expect(CountBox.shown() and CountBox.owner() == "shop", "상점이 띄운 수량 창")
eq(fields[1].Text, "1", "사기는 처음 1")
eq(CountBox.value(), 1, "지금의 수 1")
CountBox.type("25")
eq(CountBox.value(), 25, "적은 수 25")
local sum = nil
for _, t in texts do
	if t.text == string.gsub(KW.cost, "{n}", "1,250") then
		sum = t
	end
end
expect(sum ~= nil, "합계 1,250이 보인다 — 50 x 25")
find(W.ask.buy[2]).onClick()
eq(got, 25, "「사기」 → 25개를 산다")
expect(not CountBox.shown(), "확인하면 닫힌다")
-- 최대를 넘게 적으면 최대로 · [최대] · [−] [+]
open({ owner = "shop", kind = "buy", icon = "dust", name = "달가루", hi = 40, each = 50, money = 100000 })
CountBox.type("999")
eq(fields[1].Text, "40", "최대를 넘게 적으면 최대(40)로")
find("-").onClick()
eq(CountBox.value(), 39, "[−] 한 칸")
find("+").onClick()
eq(CountBox.value(), 40, "[+] 한 칸")
expect(not find("+").enabled, "최대에서는 [+]가 눌리지 않는다")
CountBox.type("3")
find(KW.max).onClick()
eq(CountBox.value(), 40, "[최대]")
-- 비면 확인이 안 된다 · Enter
CountBox.type("")
expect(not find(W.ask.buy[2]).enabled, "비면 「사기」가 눌리지 않는다")
find(W.ask.buy[2]).onClick()
eq(got, nil, "(비었을 때 누르면 아무 일도 없다)")
CountBox.type("7")
fields[1].FocusLost:Fire(true)
eq(got, 7, "Enter = 확인")
-- 달돈이 모자라면
open({ owner = "shop", kind = "buy", icon = "potion", name = "물약", hi = 99, each = 100, money = 250 })
CountBox.type("5")
local short = false
for _, t in texts do
	short = short or (t.text == KW.short and t.tone == "red")
end
expect(short and not find(W.ask.buy[2]).enabled, "달돈이 모자라면 빨간 글 · 「사기」가 눌리지 않는다")
-- 취소
local cancelled = false
open({ owner = "bag", kind = "discard", icon = "potion", name = "물약", hi = 12, onNo = nil })
eq(fields[1].Text, "12", "버리기는 처음 그 칸의 전부")
find(W.askNo).onClick()
expect(not CountBox.shown() and got == nil, "「취소」 → 아무것도 하지 않고 닫힌다")
local _ = cancelled
-- 팔기: 받을 달돈
open({ owner = "bag", kind = "sell", icon = "potion", name = "물약", hi = 10, gainEach = 7 })
local gain = false
for _, t in texts do
	gain = gain or t.text == string.gsub(KW.gain, "{n}", "70")
end
expect(gain, "팔기: 받을 달돈 +70(7 x 10)")
-- 창의 주인이 닫히면 같이 닫힌다(다른 창이 닫히면 그대로)
CountBox.hide("shop")
expect(CountBox.shown(), "다른 창(상점)이 닫혀도 가방의 수량 창은 그대로")
CountBox.hide("bag")
expect(not CountBox.shown(), "가방이 닫히면 같이 닫힌다")
-- 나누기: 처음 절반
open({ owner = "bag", kind = "split", icon = "potion", name = "물약", hi = CountPick.hi("split", 10) })
eq(fields[1].Text, "5", "나누기는 처음 절반")
CountBox.hide()

-- ⑤ 글이 칸에 들어간다 · 줄의 치수
do
	local K = UI.layout.count
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	local pixelText = req("Client/ui/pixelText")
	pixelText.Register("small", KIT.font.small, {})
	pixelText.Register("body_o", KIT.font.body_o, {})
	local inner = K.w - K.pad * 2
	local half = math.floor((inner - 6) / 2)
	for kind, pair in W.ask do
		expect(pixelText.Measure(pair[1], "body_o") <= inner, ("묻는 글 「%s」이 한 줄에"):format(pair[1]))
		expect(pixelText.Measure(pair[2], "body_o") <= half - 6, ("단추 「%s」"):format(pair[2]))
		local _k = kind
	end
	expect(pixelText.Measure(W.askNo, "body_o") <= inner - half - 6 - 6, "「취소」")
	expect(pixelText.Measure(KW.max, "body_o") <= K.maxW - 6, "「최대」")
	local halfNote = math.floor(inner / 2)
	expect(pixelText.Measure((string.gsub(string.gsub(KW.range, "{lo}", "1"), "{hi}", "9999")), "small") <= halfNote, "범위 「1 ~ 9999개」")
	expect(pixelText.Measure((string.gsub(KW.cost, "{n}", "999,999,999")), "small") <= inner - halfNote, "합계(아홉 자리)")
	expect(pixelText.Measure(KW.short, "small") <= inner - halfNote, "「달돈이 모자란다」")
	expect(pixelText.Measure((string.gsub(KW.gain, "{n}", "9,999,999")), "small") <= inner - halfNote, "받을 달돈(일곱 자리)")
	expect(K.stepW * 2 + K.fieldW + K.gap * 2 + K.gap + K.maxW <= inner, "[−] 칸 [+] [최대]가 한 줄에")
	expect(K.fieldY + 26 <= K.noteY and K.noteY + 14 <= K.buttonY and K.buttonY + 26 + K.pad <= K.h, "줄이 겹치지 않고 창 안에")
	expect(K.itemY + K.iconS <= K.fieldY, "그림 줄 아래에 수량 줄")
	expect(K.w <= 768 - 32 and K.h <= 432 - 32, "가장 작은 화면(768 x 432)에도 들어간다")
end

-- ⑥ 상점의 물건 가운데 여럿 사는 것(물약 · 달가루 · 부적 · 주문서)은 수량 창 — 상점 창의 「1 · 10」 단추는 없다(이름 · 값만 · 단추는 「사기」 하나)
do
	local many = 0
	for _, s in Items.data.STOCK do
		if (s.max or 1) > 1 then
			many += 1
		end
	end
	expect(many >= 3, "여럿 사는 물건이 있다(물약 · 귀환 주문서 · 달가루 · 부적) — " .. many)
end
