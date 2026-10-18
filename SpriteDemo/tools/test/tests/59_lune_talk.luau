-- 「달의 계승자」 — 대화창(client/lune/ui/talk.luau)을 화면 없이 실제로 돌려 본다(2026-10-18).
--  까닭: 같은 날 넣은 「고르는 말」(한 주민에게 할 일이 둘 넘으면 줄마다 하나 — ↓ 옮기기 · ↑ 고르기)에서 코드 검토가 버그 둘을 찾았다
--  (고르는 말이 떠 있는데 장면의 말이 오면 말이 비고 다음 ↑가 옛 고르기를 했다 · 앞서 눌러 둔 ↓로 둘째 줄에서 열렸다 — 뒤의 것은 boot가 막는다).
--  보는 것: 처음 짓기 · 말이 차례로 넘어가고 끝나면 닫힘 · 고르는 말(옮기기 · 끝에서 처음으로 · 고르기 · 줄 누르기) · 고르는 말 위로 다른 말이 오면 걷힘 · 닫기
NumberSequence = { new = function(a, b) return { a, b } end }
SERVICE("UserInputService", { InputBegan = { Connect = function() end }, TouchEnabled = false })

local function frame(name)
	local f = { Name = name, Visible = true, ZIndex = 1, BackgroundTransparency = 0, ImageTransparency = 0, Image = "", Size = UDim2.fromOffset(1, 1), Position = UDim2.fromOffset(0, 0), children = {} }
	function f:Destroy()
		self.destroyed = true
	end
	function f:FindFirstChild(n)
		for _, c in self.children do
			if c.Name == n then
				return c
			end
		end
		return nil
	end
	function f:GetDescendants()
		return {}
	end
	function f:IsA()
		return false
	end
	function f:SetAttribute() end
	return f
end
local function textItem()
	local f = frame("Text")
	local it = { label = { Frame = f, Width = 40, SetMaxWidth = function() end }, text = "", frame = f }
	function it.set(_, v)
		it.text = v
		it.label.Width = #v * 4
	end
	function it.move() end
	function it.show(_, on)
		f.Visible = on
	end
	function it.color() end
	function it.size()
		return it.label.Width, 12
	end
	return it
end
local hits = {} -- [틀의 이름] = 누르면 부르는 것
local any = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end })
MOCK("Client/lune/stage", { uiW = 960, uiH = 540, ratio = 2.5, group = function(_, name) return frame(name) end })
MOCK("Client/lune/overlay", { root = frame("Overlay"), x = function(v) return v end, y = function(v) return v end })
MOCK("Client/lune/ui/ui", {
	COLOR = any,
	M = { body = 12, small = 9, bodyLine = 16, smallLine = 13, button = 26 },
	group = function(_, x, y, w, h, name) return frame(name or "Group") end,
	panel = function() local p = frame("Panel") table.insert(p.children, frame("Back")) return p end, -- 판(속의 바탕 「Back」을 layout이 찾는다)
	box = function() return frame("Box") end,
	part = function(_, name) return frame(name) end,
	text = function() return textItem() end,
	keycap = function() local k = { frame = frame("Key") } function k.move() end function k.set() end function k.show() end return k end,
	button = function(_, text, x, y, w, onClick)
		local b = { frame = frame("Button"), click = onClick, text = text }
		function b.setText(_, v) b.text = v end
		function b.setMain() end
		function b.setEnabled() end
		function b.move() end
		return b
	end,
	hit = function(parent)
		local h = { Name = "Hit" }
		h.Activated = { Connect = function(_, fn) hits[parent.Name] = fn end }
		return h
	end,
	measure = function(t) return #t * 4 end,
})
MOCK("Client/modules/ui/pixelText", { Fit = function(t) return t end, Measure = function(t) return #t * 4 end })

local Talk = req("Client/lune/ui/talk")
Talk.init()
expect(Talk.npc == nil, "처음에는 말하는 중이 아니다")

-- ---- 말이 차례로 넘어가고, 끝나면 닫힌다 ----
local npc = { id = "squire", name = "하늬", x = 0, y = 0, lines = { "평소의 말" } }
local finished = 0
Talk.start(npc, { "첫 말", "둘째 말" }, "수정 숲으로", function() finished += 1 end, "수락")
expect(Talk.npc == npc and Talk.index == 1, "말을 시작했다")
Talk.next(npc) -- 나오는 중이면 다 보이게
Talk.next(npc)
expect(Talk.index == 2, "다음 말로")
Talk.next(npc)
Talk.next(npc)
expect(Talk.npc == nil and finished == 1, "마지막 말 뒤에는 그 일을 하고 닫힌다")

-- ---- 고르는 말 ----
local picked = nil
local items = { { text = "완료 가능 「수정 숲으로」" }, { text = "새 퀘스트 「새는 나룻배」" }, { text = "대화하기" } }
Talk.menu(npc, items, function(i) picked = i end)
expect(Talk.inMenu() and Talk.menuSelected() == 1, "고르는 말은 첫 줄에서 열린다")
Talk.menuMove(1)
eq(Talk.menuSelected(), 2, "↓ = 다음 줄")
Talk.menuMove(1)
Talk.menuMove(1)
eq(Talk.menuSelected(), 1, "끝에서 ↓ = 처음으로")
Talk.menuMove(-1)
eq(Talk.menuSelected(), 3, "처음에서 ↑ 옮기기 = 끝으로")
Talk.next(npc)
expect(picked == 3 and not Talk.inMenu() and Talk.npc == nil, "↑ · 스페이스 = 고른 줄의 일(그리고 닫힌다)")
-- 줄을 누르면 그것
picked = nil
Talk.menu(npc, items, function(i) picked = i end)
expect(hits["MenuRow2"] ~= nil, "줄마다 누르는 자리")
hits["MenuRow2"]()
expect(picked == 2 and not Talk.inMenu(), "줄을 누르면 그 줄을 고른다")
-- 고르는 말이 떠 있는데 다른 말(장면 · 이야기)이 오면 고르는 말을 걷는다(2026-10-18 검토)
picked = nil
Talk.menu(npc, items, function(i) picked = i end)
Talk.cine("샛별", "장면의 한 말")
expect(not Talk.inMenu() and Talk.npc == Talk.CINE, "장면의 말이 오면 고르는 말이 걷힌다")
Talk.cine(nil, nil)
expect(Talk.npc == nil and picked == nil, "장면이 닫혀도 옛 고르기를 하지 않는다")
Talk.menu(npc, items, function(i) picked = i end)
Talk.start(npc, { "다른 말" })
expect(not Talk.inMenu(), "다른 말을 시작하면 고르는 말이 걷힌다")
Talk.next(npc)
Talk.next(npc)
expect(picked == nil, "그 말을 넘겨도 옛 고르기를 하지 않는다")
-- 닫기(X · Esc · 거절)
Talk.menu(npc, items, function(i) picked = i end)
Talk.close()
expect(not Talk.inMenu() and Talk.npc == nil and picked == nil, "닫으면 아무것도 고르지 않는다")
-- 줄은 D.lines개까지(넘는 것은 버린다)
local many = {}
for i = 1, 12 do
	many[i] = { text = "줄 " .. i }
end
Talk.menu(npc, many, function() end)
Talk.menuMove(-1)
expect(Talk.menuSelected() <= 12 and Talk.menuSelected() >= 1, "많아도 줄 안에서 옮긴다")
Talk.close()
