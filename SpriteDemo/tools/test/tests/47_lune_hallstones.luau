-- 「달의 계승자」 — 명예의 전당의 비석에 새긴 순위(client/lune/hallStones.luau, 2026-10-15)를 화면 없이 돌려 본다.
--  사용자: "명예의 전당이 상호작용해서 나오는 방식인데 그게 아니고 그냥 비석그림위에 비석에 새겨진것처럼 보여야합니다."
--  보는 것: 비석 셋에 글이 생긴다 · 순위가 오면 줄이 채워지고 면 안에 놓인다 · 면에 들어가는 만큼만 · 긴 이름은 폭이 줄어든다 · 나가면 거둔다 · 비석에는 말을 걸지 않는다
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local ITEMS = req("ReplicatedStorage/shared/lune/data/items.generated")

local made = {}
local function frame(name)
	local f = { Name = name, Visible = true, children = {} }
	function f:Destroy()
		self.destroyed = true
	end
	table.insert(made, f)
	return f
end
local texts = {}
MOCK("Client/lune/stage", {
	uiW = 960, uiH = 540, ratio = 2.5,
	group = function(parent, name)
		return frame(name)
	end,
})
MOCK("Client/lune/overlay", { camX = 0, camY = 26, x = function(v) return math.floor((v - 0) * 2.5 + 0.5) end, y = function(v) return math.floor((v - 26) * 2.5 + 0.5) end })
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end }),
	M = { small = 10, smallLine = 14, body = 12, bodyLine = 18 },
	text = function(parent, text, x, y, width, opts)
		local it = { text = text, x = x, y = y, width = width, shown = true, align = opts and opts.align }
		it.label = { Width = 0, maxW = width }
		function it.label.SetShadow(_, c)
			it.shadow = c
		end
		function it.label.SetMaxWidth(_, w)
			it.label.maxW = w
		end
		function it.set(_, v)
			it.text = v
			it.label.Width = math.min(it.label.maxW, #v * 5)
		end
		function it.move(_, nx, ny)
			it.x, it.y = nx, ny
		end
		function it.show(_, on)
			it.shown = on
		end
		table.insert(texts, it)
		return it
	end,
	measure = function(t)
		return #t * 5
	end,
})
MOCK("ReplicatedStorage/shared/lune/net/net", { Invoke = function() return nil end })

local Stones = req("Client/lune/hallStones")
local hall = SCENES.scenes.in_hall
expect(hall ~= nil, "명예의 전당이 있다")
local faces = 0
for _, n in hall.npcs do
	if n.stone then
		expect(typeof(n.face) == "table" and #n.face == 4, "비석 면의 자리 " .. n.id)
		faces += 1
		eq(ITEMS.NPCDO and ITEMS.NPCDO[n.id], nil, "비석에는 창이 없다(↑로 아무 일도 없다) " .. n.id)
	end
end
eq(faces, 3, "비석 셋(후원 · 전투력 · 레벨)")

local rows = {}
for i = 1, 10 do
	rows[i] = { name = if i == 3 then "아주아주아주긴이름이에요" else "이름" .. i, class = "riven", value = tostring(1000 - i) }
end
Stones.fetch = function()
	return { robux = { rows[1] }, power = rows, level = rows }
end
local root = frame("Over")
Stones.enter(hall, root)
local mine = #texts
eq(mine, 3 * 10 * 3, "비석마다 열 줄 x (순위 · 이름 · 값)")
for _, t in texts do
	expect(t.shadow ~= nil, "글은 새긴 모양(밝은 테두리)이다")
end
Stones.update() -- 순위를 받으러 간다(task.spawn — 가짜 시계)
-- (가짜 task.spawn은 바로 돈다)
Stones.update()
-- 순위가 들어온 줄은 비석 면 안에 있다
local function faceOf(id)
	for _, n in hall.npcs do
		if n.id == id then
			return n.face
		end
	end
	return nil
end
local f = faceOf("hall_power")
local x0, y0 = math.floor(f[1] * 2.5 + 0.5), math.floor((f[2] + 26 - 26) * 2.5 + 0.5)
local x1, y1 = math.floor((f[3] + 1) * 2.5 + 0.5), math.floor((f[4] + 1) * 2.5 + 0.5)
local shown, inside = 0, true
for _, t in texts do
	if t.shown and t.text ~= "" and t.y >= y0 - 2 and t.y <= y1 and t.x >= x0 - 4 and t.x <= x1 then
		shown += 1
	end
end
expect(shown >= 3 * 7, ("전투력의 비석 면 안에 줄이 일곱 넘게 새겨진다(%d)"):format(shown))
local fit = math.floor(((y1 - 3) - (y0 + 4)) / 14)
expect(fit <= 10, "면에 들어가는 만큼만 — " .. fit)
-- 긴 이름은 폭이 줄어든다
local long
for _, t in texts do
	if t.text == rows[3].name then
		long = t
	end
end
expect(long ~= nil and long.label.maxW < 120, "긴 이름은 면의 폭에 맞춰 줄인다")
-- 후원의 비석: 한 사람뿐이면 한 줄만
local robuxShown = 0
f = faceOf("hall_robux")
for _, t in texts do
	if t.shown and t.x >= math.floor(f[1] * 2.5) - 4 and t.x <= math.floor((f[3] + 1) * 2.5) and t.text ~= "" then
		robuxShown += 1
	end
end
eq(robuxShown, 3, "후원의 비석은 한 줄(순위 · 이름 · 값)")
-- 나가면 거둔다
Stones.leave()
local destroyed = 0
for _, m in made do
	if m.destroyed then
		destroyed += 1
	end
end
expect(destroyed >= 1, "나가면 비석의 글을 거둔다")
Stones.update()
-- 비석이 없는 장면에서는 아무것도 하지 않는다
local before = #texts
Stones.enter(SCENES.scenes.town, root)
eq(#texts, before, "비석이 없는 장면에서는 글을 만들지 않는다")
