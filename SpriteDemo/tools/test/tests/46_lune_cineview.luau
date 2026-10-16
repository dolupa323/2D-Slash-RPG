-- 「달의 계승자」 — 퀘스트 연출(장면)의 그리기(client/lune/cineView.luau)를 화면 없이 돌려 본다(2026-10-15).
--  화면 모듈은 Play에서야 오류가 드러난다 — 가짜 화면 틀(stage · overlay · ui · talk · pixelText)을 끼우고, 모든 장면을 처음부터 끝까지 그린다:
--   오류 없이 끝나는가 · 말이 대화창(Talk.cine)으로 가는가 · 장면이 세운 것이 생겼다가 거둬지는가 · 끝나면 onEnd가 한 번 · 건너뛰기 · 이름표를 숨길 때
local Cine = req("ReplicatedStorage/shared/lune/cine")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

NumberSequence = { new = function(a, b) return { a, b } end }
SERVICE("UserInputService", { InputBegan = { Connect = function() end }, TouchEnabled = false })

local made = {}
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
		local out = {}
		local function walk(x)
			for _, c in x.children do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(self)
		return out
	end
	function f:IsA(class)
		return class == "ImageLabel" and self.image == true
	end
	function f:SetAttribute() end
	table.insert(made, f)
	return f
end
local function child(parent, f)
	if parent and parent.children then
		table.insert(parent.children, f)
	end
	return f
end
local function textItem(parent)
	local f = child(parent, frame("Text"))
	local it = { label = { Frame = f, Width = 40 }, text = "" }
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
local any = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end })
MOCK("Client/lune/stage", {
	uiW = 960, uiH = 540, ratio = 2.5,
	image = function(parent, name)
		local f = child(parent, frame(name))
		f.image = true
		return f
	end,
	group = function(parent, name)
		return child(parent, frame(name))
	end,
})
MOCK("Client/lune/overlay", { x = function(v) return v end, y = function(v) return v end })
MOCK("Client/lune/ui/ui", {
	COLOR = any,
	M = { body = 12, small = 9, bodyLine = 16, smallLine = 13, button = 26 },
	group = function(parent, x, y, w, h, name)
		return child(parent, frame(name or "Group"))
	end,
	box = function(parent)
		return child(parent, frame("Box"))
	end,
	part = function(parent, name)
		local f = child(parent, frame(name))
		f.image = true
		return f
	end,
	text = function(parent)
		return textItem(parent)
	end,
	keycap = function(parent)
		local k = { frame = child(parent, frame("Key")) }
		function k.move() end
		return k
	end,
	button = function(parent, text, x, y, w, onClick)
		local b = { frame = child(parent, frame("Button")), click = onClick }
		return b
	end,
	hit = function(parent)
		local h = child(parent, frame("Hit"))
		h.Activated = { Connect = function(_, fn) h.fire = fn end }
		return h
	end,
	measure = function(t)
		return #t * 4
	end,
})
local talk = { lines = {}, closed = 0, full = true }
MOCK("Client/lune/ui/talk", {
	CINE = { id = "__cine" },
	cine = function(name, text)
		if text then
			table.insert(talk.lines, { name = name, text = text })
		else
			talk.closed += 1
		end
	end,
	cineFull = function()
		return talk.full
	end,
	cineReveal = function()
		talk.full = true
	end,
})
MOCK("Client/modules/ui/pixelText", { Fit = function(t) return t end })

local View = req("Client/lune/cineView")
local root = frame("Root")
View.init(root)
expect(not View.active(), "처음에는 장면이 없다")
local ended = {}
View.onEnd = function(def)
	table.insert(ended, def.id)
end
local function world()
	return {
		hero = function()
			return { x = 200, y = 176, dir = 1 }
		end,
		npc = function(id)
			if id == "master" or id == "elder" or id == "guide" or id == "oldman" or id == "guard1" then
				return { x = 250, y = 176, dir = -1, name = id }
			end
			return nil
		end,
		npcName = function(id)
			return id
		end,
		boss = function()
			return { x = 320, y = 176 }
		end,
		cls = "salamander",
		heroName = "시험",
	}
end

for _, def in Cine.DATA.list do
	table.clear(talk.lines)
	local layer = frame("World")
	local before = #ended
	View.play(def, world(), layer)
	expect(View.active(), def.id .. ": 틀면 장면이 있다")
	local t, guard = 0, 0
	local sawActor, sawHide = false, false
	while View.active() and guard < 20000 do
		guard += 1
		View.update(1 / 30)
		t += 1 / 30
		if #layer.children > 0 then
			sawActor = true
		end
		sawHide = sawHide or View.hideTags()
		local st = View.state()
		if st and st.wait and (st.wait.input == "say" or st.wait.input == "note") then
			View.input("next")
		end
	end
	expect(not View.active(), ("%s: 끝까지 돈다(%.1f초)"):format(def.id, t))
	eq(#ended, before + 1, def.id .. ": 끝나면 onEnd가 한 번")
	eq(ended[#ended], def.id, def.id .. ": onEnd가 그 장면을 알린다")
	local says = 0
	for _, s in def.steps do
		if s.say then
			says += 1
		end
	end
	eq(#talk.lines, says, def.id .. ": 말이 모두 대화창으로 갔다")
	for _, ln in talk.lines do
		expect(not string.find(ln.text, "{", 1, true), def.id .. ": 대화창의 말에 바꿔 넣지 못한 자리가 없다")
	end
	local spawns = false
	for _, s in def.steps do
		spawns = spawns or s.spawn ~= nil
	end
	if spawns then
		expect(sawActor, def.id .. ": 장면이 세운 것을 그렸다")
		local alive = 0
		for _, c in layer.children do
			if not c.destroyed then
				alive += 1
			end
		end
		eq(alive, 0, def.id .. ": 끝나면 세운 것을 거둔다")
	end
	local hides = false
	for _, s in def.steps do
		hides = hides or s.picture ~= nil or (s.fade == 1)
	end
	if hides then
		expect(sawHide, def.id .. ": 암전 · 큰 그림 동안 이름표를 숨긴다")
	end
	expect(not View.hideTags(), def.id .. ": 끝나면 이름표를 다시 보인다")
end
-- 건너뛰기
do
	local def = Cine.DATA.list[1]
	View.play(def, world(), frame("World"))
	View.update(1 / 30)
	View.input("skip")
	View.update(1 / 30)
	expect(not View.active(), "건너뛰면 장면이 끝난다")
end
-- 퀘스트 동안의 맵 모습
View.setLook(Color3.fromRGB(255, 74, 46), 0.22)
View.setLook(nil, 0)
expect(true, "맵 모습을 덮고 걷는다(오류 없이)")
