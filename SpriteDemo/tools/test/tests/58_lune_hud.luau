-- 「달의 계승자」 — 늘 보이는 화면(client/lune/hud.luau)을 화면 없이 실제로 돌려 본다(2026-10-18).
--  까닭: 같은 날 넣은 설명 판(버프 · 경험치 줄 · 퀵슬롯 칸)에서 아래쪽에 선언한 지역 변수(TIP)를 위쪽 함수가 써서, 마우스를 올릴 때마다 오류가 나고 판이 쌓이는 버그가 있었다
--  (컴파일 · 다른 검사는 지나갔다 — 화면 모듈은 GUI가 있어야 해서 돌려 보지 않았다). 몬스터 그리기 검사(24)처럼 가짜 화면 틀 · UI 부품을 끼워 hud.luau는 진짜로 돌린다.
--  보는 것: 처음 짓기 · 내 상태 · 버프 줄과 그 설명(마우스 · 손가락) · 경험치 줄의 설명 · 퀵슬롯 칸 · 칸의 설명 · 다시 쓰기의 덮개와 끝난 순간의 반짝임 · 다 쓴 물약의 붉은 0 · 메뉴 단추의 점
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})

-- ---- 가짜 화면 틀 ----
local frames = {} -- 만든 틀들(이름으로 찾는다)
local function frame(name: string?, parent)
	local f = { Name = name or "Frame", Visible = true, Parent = parent, ZIndex = 1, BackgroundTransparency = 0, ImageTransparency = 0,
		Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(10, 10), AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(10, 10) }
	function f:Destroy()
		self.destroyed = true
	end
	function f:FindFirstChild(n)
		return frame(n, self)
	end
	table.insert(frames, f)
	return f
end
local function alive(name: string): number
	local n = 0
	for _, f in frames do
		if f.Name == name and not f.destroyed then
			n += 1
		end
	end
	return n
end
local COLOR = setmetatable({}, { __index = function(_, k) return k end }) -- 색은 이름 그대로(붉은 0을 「red」로 본다)
local M = { small = 10, body = 12, pic = 18, button = 24, key = 12 }
local function textItem(parent, text, x, y, w, opts)
	local item = { value = text, x = x, y = y, w = w, shown = true, tint = opts and opts.color, frame = frame("Text", parent) }
	item.label = { SetMaxWidth = function() end, Frame = frame("Label", parent) }
	function item.set(_, v) item.value = v end
	function item.color(_, c) item.tint = c end
	function item.move(_, nx, ny) item.x, item.y = nx, ny end
	function item.show(_, on) item.shown = on end
	function item.size() return pixelText.Measure(item.value, (opts and opts.font) or "small"), 10 end
	return item
end
MOCK("Client/lune/stage", {
	ui = frame("StageUi"),
	uiW = 960,
	uiScale = 1,
	group = function(parent, name) return frame(name, parent) end,
	placeRect = function(parent, name) return frame(name, parent) end,
	atPosition = function(_, x, y) return UDim2.fromOffset(x, y) end,
	onResize = function() end,
})
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	M = M,
	text = textItem,
	box = function(parent, x, y, w, h, color, alpha) local f = frame("Box", parent) f.BackgroundColor3 = color f.BackgroundTransparency = alpha or 0 return f end,
	pic = function(parent, name) local f = frame("Pic", parent) f.pic = name return f end,
	setPic = function(f, name) f.pic = name end,
	measure = function(text) return (pixelText.Measure(text, "small")) end,
	group = function(parent, x, y, w, h, name) local f = frame(name, parent) f.Position = UDim2.fromOffset(x, y) return f end,
	part = function(parent, name) return frame(name, parent) end,
	slot = function(parent) local s = { frame = frame("Slot", parent), on = false } function s.setOn(_, on) s.on = on end return s end,
	bar = function(parent) local b = { frame = frame("Bar", parent), fill = frame("Fill", parent), ratio = 0 } function b.set(_, r) b.ratio = r end return b end,
	keycap = function(parent) local k = { value = "" } function k.set(_, v) k.value = v end function k.color() end return k end,
	hit = function(f) return { Activated = { Connect = function(_, fn) f.click = fn end } } end,
})
local lastInput: any = Enum.UserInputType.MouseMovement
SERVICE("UserInputService", { GetLastInputType = function() return lastInput end, GetMouseLocation = function() return Vector2.new(5, 5) end })
SERVICE("GuiService", { GetGuiInset = function() return Vector2.new(0, 0) end })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local Hud = req("Client/lune/hud")
Hud.init()
local function button(name: string, nth: number?): any
	local k = 0
	for _, inst in CREATED do
		if inst.ClassName == "TextButton" and inst.Name == name and not inst.destroyed and not (inst.Parent and inst.Parent.destroyed) then
			k += 1
			if k == (nth or 1) then
				return inst
			end
		end
	end
	return nil
end

-- ---- 내 상태 · 경험치 줄의 설명 ----
Hud.setSelf({ level = 12, hp = 100, maxHp = 200, xp = 483, need = 1120, ap = 0, sp = 0 })
local xpOver = button("XpOver")
expect(xpOver ~= nil, "경험치 줄 위에 누르는 자리")
xpOver.MouseEnter:Fire()
expect(Hud.xpTip ~= nil and alive("XpTip") == 1, "마우스를 올리면 경험치 설명")
local t = Hud.xpTipText(483, 1120, 12)
expect(t.lines[1] == "483 / 1,120 (43.12%)" and t.lines[2] == "다음 레벨까지 637", "경험치 설명의 글 — " .. t.lines[1] .. " / " .. t.lines[2])
Hud.setSelf({ level = 12, hp = 100, maxHp = 200, xp = 500, need = 1120, ap = 0, sp = 0 })
expect(alive("XpTip") == 1, "떠 있는 동안 경험치가 오르면 새 판 하나로(쌓이지 않는다)")
xpOver.MouseLeave:Fire()
expect(Hud.xpTip == nil and alive("XpTip") == 0, "벗어나면 닫힌다")

-- ---- 버프 줄과 그 설명 ----
local tipOf = function(title) return { kind = "sub", title = title, tag = "", lines = { "효과 한 줄", "남은 시간 12초" } } end
Hud.setBuffs({ { pic = "skill_ax_breath", text = "12", tip = tipOf("전투 호흡") }, { pic = "buff_death", text = "12분", tip = { kind = "none", title = "약해짐", tag = "", lines = { "쓰러진 벌칙", "남은 시간 12분", "달빛 부적" } } } })
local over1 = button("Over", 1)
expect(over1 ~= nil and button("Over", 2) ~= nil, "버프 그림마다 누르는 자리")
over1.MouseEnter:Fire()
expect(Hud.tipAt == 1 and alive("BuffTip") == 1, "마우스를 올리면 그 버프의 설명")
over1.MouseEnter:Fire()
expect(alive("BuffTip") == 1, "다시 올려도 판은 하나")
over1.MouseLeave:Fire()
expect(Hud.tipAt == nil and alive("BuffTip") == 0, "벗어나면 닫힌다")
-- 손가락: 누를 때 MouseEnter도 오지만 그것으로 열지 않는다 — 톡 = 열기 · 한 번 더 = 닫기
lastInput = Enum.UserInputType.Touch
local over2 = button("Over", 2)
over2.MouseEnter:Fire()
expect(Hud.tipAt == nil, "손가락의 MouseEnter로는 열지 않는다")
over2.Activated:Fire({ UserInputType = Enum.UserInputType.Touch })
expect(Hud.tipAt == 2 and alive("BuffTip") == 1, "톡 하면 연다")
-- 1초마다 칸을 다시 지어도(남은 시간이 바뀜) 손가락으로 연 설명은 이어서 뜬다
Hud.setBuffs({ { pic = "skill_ax_breath", text = "11", tip = tipOf("전투 호흡") }, { pic = "buff_death", text = "11분", tip = { kind = "none", title = "약해짐", tag = "", lines = { "쓰러진 벌칙", "남은 시간 11분" } } } })
expect(Hud.tipAt == 2 and alive("BuffTip") == 1, "칸을 다시 지어도 설명이 이어진다(하나)")
button("Over", 2).Activated:Fire({ UserInputType = Enum.UserInputType.Touch })
expect(Hud.tipAt == nil and alive("BuffTip") == 0, "한 번 더 톡 하면 닫는다")
lastInput = Enum.UserInputType.MouseMovement

-- ---- 퀵슬롯: 칸 · 칸의 설명 · 다시 쓰기 ----
Hud.countOf = function(id) return if id == "potion1" then 0 else 5 end
Hud.setSlots({ { what = "potion1", key = "LeftControl" }, { what = "ax_slam", key = "Q" } })
local potion = Hud.slots[1]
expect(potion.count.value == "0" and potion.count.tint == "red", "다 쓴 물약은 붉은 0")
Hud.countOf = function() return 7 end
Hud.setCounts()
expect(potion.count.value == "7" and potion.count.tint == "text", "다시 생기면 흰 숫자")
Hud.slotTipOf = function(what) return { kind = "sub", title = what, tag = "사냥기 · Lv.3", lines = { "설명", "효과" } } end
local hit2 = button("Hit", 2)
expect(hit2 ~= nil, "칸마다 누르는 자리")
for _ = 1, 3 do
	hit2.MouseEnter:Fire()
end
expect(Hud.slotTipAt == 2 and alive("SlotTip") == 1, "칸에 마우스를 올리면 설명 하나(여러 번 올려도 쌓이지 않는다)")
hit2.MouseLeave:Fire()
expect(Hud.slotTipAt == nil and alive("SlotTip") == 0, "벗어나면 닫힌다")
Hud.showSlotTip(3)
expect(alive("SlotTip") == 0, "빈 칸에는 설명이 없다")
Hud.setCooldown("ax_slam", 3, 5)
local skill = Hud.slots[2]
expect(skill.veil.Visible == true and skill.wait.value == "3", "다시 쓰기의 덮개와 남은 초")
Hud.setCooldown("ax_slam", 0, 5)
expect(skill.veil.Visible == false and skill.readyT > 0, "다시 쓰기가 끝나면 반짝임이 시작된다")
Hud.step(0.1)
expect(skill.ready.Visible == true and skill.ready.BackgroundTransparency < 1, "반짝이는 동안 하얀 덮개가 보인다")
Hud.step(1)
expect(skill.ready.Visible == false, "곧 사라진다")

-- ---- 메뉴 단추의 점: 단추를 다시 지어도 남는다 ----
local menu = { { id = "bag", name = "가방" }, { id = "auction", name = "경매장" }, { id = "more", name = "메뉴" } }
Hud.setMenu(menu, function() end)
Hud.markMenu("bag", true)
Hud.setMenu(menu, function() end)
expect(Hud.menu.bag.dot.Visible == true and Hud.menu.auction.dot.Visible ~= true, "가방의 점이 단추를 다시 지은 뒤에도 남는다")
Hud.markMenu("bag", false)
Hud.setMenu(menu, function() end)
expect(Hud.menu.bag.dot.Visible ~= true, "끈 점은 다시 지어도 꺼져 있다")
