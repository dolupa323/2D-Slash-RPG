-- 룬 · 별똥별 조각의 화면(2026-11-07 — 서버 modules/runeGuard.luau · 셈 sim/rune.luau · 설계 공방 js/lune/design/rune.js).
--  ① 룬: 맵의 땅 위에 떠서 숨 쉬는 달빛 수정(라벤더 · 흰 속 · 둘레를 도는 별 셋 · 발밑의 고리). 저주가 걸리면 수정이 검붉게 일렁이고 둘레에 어두운 기운.
--     곁에 서면 머리 위에 「↑ 룬 해방」 → ↑ → 화면 가운데의 판(「룬 해방」 · 화살표 넷 · 남은 시간 띠) → 방향키(또는 판의 화살표 단추)를 차례대로.
--  ② 별똥별 조각: 하늘에서 반짝이며 떨어져 땅 위에서 떠 있는 금빛 별(둘레의 빛 · 반짝임 · 위로 오르는 금가루) — 몸이 닿으면 줍는다(서버가 다시 잰다).
--  그림은 점 그림판(장면의 cast.fx — 맵을 옮기면 attach로 다시 단다). 글 · 판은 화면 틀(Stage.ui).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local D = require(lune.data["rune.generated"])
local Fx = require(lune.fx)
local Net = require(lune.net.net)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local Input = require(script.Parent.input)

local R, B = D.rune, D.bait
local W = R.words
local C = Ui.COLOR
local disc, poly, starPts = Fx.disc, Fx.poly, Fx.starPts
local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

local RuneView = {}
local hooks: any = nil -- boot가 단다: { float(글, x, y, Color3), banner(제목, 줄), body() → 내 몸 { x, y } | nil, blocked() → 창 · 대화 · 장면 중 }
local view: any = { rune = nil, stage = 0 }
local mapAt = os.clock() -- view를 받은 때(남은 시간들을 흘린다)
local bait: any = nil -- { id, x, y, untilAt, born, picking }
local prompt: any = nil -- 해방 판 { holder, arrows, at, deadline, slots, bar }
local starting = false
local GOLD = { d = 0x8a6a20, n = 0xc99a32, l = 0xffe39a, w = 0xffffff }
local MOON = { d = 0x4d4d6b, n = 0x9a8fd0, l = 0xcdc6f0, w = 0xffffff }
local CURSE = { d = 0x2b1030, n = 0x6b1f4a, l = 0xb14a7a }

function RuneView.init(h)
	hooks = h
end

-- 서버가 알린 맵의 모습: { rune = { x, y, id } | nil, stage, buffLeft, cdLeft, guardLeft }
function RuneView.setMap(v)
	if typeof(v) ~= "table" then
		return
	end
	local had, stageWas = view.rune, tonumber(view.curse) or 0
	view, mapAt = v, os.clock()
	if v.rune and not had and hooks and hooks.banner then
		hooks.banner(W.appeared, W.hint)
	end
	-- 내 저주의 단계가 올랐을 때만(2026-11-12 — 저주는 그 사람이 룬을 두고 사냥한 시간으로 쌓인다: 맵의 단계로 알리면 막 들어온 사람에게도 떴다)
	local st = tonumber(v.curse) or 0
	if st > stageWas and R.curse.cut[st] and hooks and hooks.banner then
		hooks.banner(Format.fill(W.curse, { n = st, p = floor(R.curse.cut[st] * 100 + 0.5) }), W.curseHint)
	end
	if not v.rune and prompt then
		RuneView.closePrompt()
	end
end
-- 서버가 알린 별똥별: { id, x, y, life } 또는 { gone = id }
function RuneView.setBait(v)
	if typeof(v) ~= "table" then
		return
	end
	if v.gone then
		if bait and bait.id == v.gone then
			bait = nil
		end
		return
	end
	bait = { id = v.id, x = v.x, y = v.y, untilAt = os.clock() + (tonumber(v.life) or B.life), born = os.clock(), picking = false }
end
-- 맵을 옮겼다: 그 장면의 점 그림판에 다시 단다(룬 · 별은 서버가 새로 알린다)
function RuneView.attach(fx)
	bait = nil
	view = { rune = nil, stage = 0, buffLeft = view.buffLeft, cdLeft = view.cdLeft, guardLeft = view.guardLeft, curse = view.curse } -- (내게 붙은 저주는 맵을 옮겨도 남는다 — 2026-11-10)
	RuneView.closePrompt()
	if not fx or not fx.add then
		return
	end
	fx.add(1e9, function(ctx)
		RuneView.draw(ctx, os.clock())
	end)
end

-- 남은 초(받은 뒤로 흐른 만큼 뺀다)
local function left(k: string): number
	return math.max(0, (tonumber(view[k]) or 0) - (os.clock() - mapAt))
end
function RuneView.buffLeft(): number
	return left("buffLeft")
end
function RuneView.guardLeft(): number
	return left("guardLeft")
end
-- 내게 붙은 룬의 저주 단계(0 = 없다 — 맵을 옮겨도 · 다시 접속해도 남는다: 서버 runeGuard의 hero.runeCurse)
function RuneView.curse(): number
	return tonumber(view.curse) or 0
end

-- ---------- 그리기 ----------
local function drawRune(ctx, x: number, y: number, t: number, stage: number)
	local bob = floor(sin(t * 2.2) * 2 + 0.5)
	local cy = y - 18 + bob
	local cursed = stage > 0
	local glowC = if cursed then CURSE.n else MOON.n
	-- 발밑의 고리(납작한 타원) · 오르는 빛
	ctx:alpha(0.55)
	for i = 0, 23 do
		local a = i / 24 * 6.2832 + t * 0.8
		ctx:style(if i % 3 == 0 then (if cursed then CURSE.l else MOON.l) else glowC)
		ctx:rect(floor(x + cos(a) * 13 + 0.5), floor(y - 1 + sin(a) * 3 + 0.5), 1, 1)
	end
	-- 둘레의 빛(숨 쉰다)
	ctx:alpha(0.18 + 0.1 * sin(t * 3))
	disc(ctx, x, cy, 13, glowC)
	ctx:alpha(0.3)
	disc(ctx, x, cy, 8, if cursed then CURSE.l else MOON.l)
	ctx:alpha(1)
	-- 수정(마름모 두 겹)
	poly(ctx, { { x, cy - 10 }, { x + 6, cy }, { x, cy + 10 }, { x - 6, cy } }, if cursed then CURSE.d else MOON.d)
	poly(ctx, { { x, cy - 9 }, { x + 5, cy }, { x, cy + 9 }, { x - 5, cy } }, if cursed then CURSE.n else MOON.n)
	poly(ctx, { { x, cy - 7 }, { x + 2, cy - 1 }, { x, cy + 5 }, { x - 3, cy } }, if cursed then CURSE.l else MOON.l)
	ctx:style(MOON.w)
	ctx:rect(x - 1, cy - 5, 1, 3)
	-- 둘레를 도는 별 셋(금빛)
	for i = 0, 2 do
		local a = t * 1.6 + i * 2.094
		local px, py = x + cos(a) * 11, cy + sin(a) * 4
		ctx:alpha(if sin(a) < 0 then 0.5 else 1)
		ctx:style(GOLD.l)
		ctx:rect(floor(px + 0.5), floor(py + 0.5), 1, 1)
	end
	ctx:alpha(1)
end

local function drawBait(ctx, b, t: number)
	local age = t - b.born
	local x, rest = b.x, b.y - 9
	local y = rest
	if age < 0.55 then -- 하늘에서 비스듬히 떨어진다(꼬리)
		local k = age / 0.55
		y = rest - (1 - k) * 110
		x = b.x + (1 - k) * 34
		for i = 1, 6 do
			ctx:alpha(0.6 * (1 - i / 7))
			ctx:style(if i < 3 then GOLD.w else GOLD.l)
			ctx:rect(floor(x + i * 3 + 0.5), floor(y - i * 9 + 0.5), 2, 2)
		end
		ctx:alpha(1)
	else
		y = rest + floor(sin(t * 3.2) * 2 + 0.5)
	end
	local blink = b.untilAt - os.clock() < 4 and (floor(t * 8) % 2 == 0) -- 사라지기 4초 전부터 깜빡인다
	-- 2026-11-09 사용자 "누가봐도 먹어야하는것처럼 보여야해": 떨어진 뒤에는 하늘에서 내리는 빛기둥 · 위에서 까딱이는 화살표 · 별을 키웠다(7 → 10점 · 둘레의 빛 11 → 15)
	if age >= 0.55 then
		local pa = 0.14 + 0.08 * sin(t * 4)
		ctx:alpha(pa)
		ctx:style(GOLD.l)
		ctx:rect(floor(x - 3 + 0.5), floor(y - 78 + 0.5), 7, 78)
		ctx:alpha(pa * 1.8)
		ctx:style(GOLD.w)
		ctx:rect(floor(x + 0.5), floor(y - 78 + 0.5), 1, 78)
		local ay = floor(y - 30 + sin(t * 5) * 3 + 0.5)
		ctx:alpha(0.95)
		for r = 0, 3 do
			ctx:style(GOLD.d)
			ctx:rect(floor(x - 4 + r + 0.5), ay + r, 9 - r * 2, 1)
			ctx:style(if r == 0 then GOLD.w else GOLD.l)
			ctx:rect(floor(x - 3 + r + 0.5), ay + r, math.max(1, 7 - r * 2), 1)
		end
	end
	-- 둘레의 빛 · 넓어지는 고리
	ctx:alpha(0.14 + 0.06 * sin(t * 6)) -- (넓힌 빛이 어두운 땅에서 탁해 보여 옅게)
	disc(ctx, x, y, 15, GOLD.l)
	local ring = (t * 0.9) % 1
	ctx:alpha(0.5 * (1 - ring))
	for i = 0, 19 do
		local a = i / 20 * 6.2832
		ctx:style(GOLD.l)
		ctx:rect(floor(x + cos(a) * (9 + ring * 14) + 0.5), floor(y + sin(a) * (9 + ring * 14) + 0.5), 1, 1)
	end
	ctx:alpha(if blink then 0.45 else 1)
	-- 별(바깥 금빛 · 속 흰빛 · 돈다)
	poly(ctx, starPts(x, y, 10, t * 0.8), GOLD.n)
	poly(ctx, starPts(x, y, 7, t * 0.8), GOLD.l)
	poly(ctx, starPts(x, y, 3.5, t * 0.8), GOLD.w)
	-- 반짝임(네 갈래 · 번갈아)
	local tw = (t * 1.3) % 1
	if tw < 0.35 then
		local s = floor(2 + tw * 12)
		ctx:style(GOLD.w)
		ctx:rect(x + 10, y - 11 - s, 1, s * 2 + 1)
		ctx:rect(x + 10 - s, y - 11, s * 2 + 1, 1)
	end
	-- 오르는 금가루
	for i = 0, 5 do
		local u = (t * 0.7 + i / 6) % 1
		ctx:alpha((1 - u) * 0.9)
		ctx:style(GOLD.l)
		ctx:rect(floor(x - 8 + i * 3 + sin(t * 2 + i) * 2 + 0.5), floor(y + 5 - u * 24 + 0.5), 1, 1)
	end
	ctx:alpha(1)
end

function RuneView.draw(ctx, t: number)
	local r = view.rune
	if r then
		drawRune(ctx, r.x, r.y, t, view.stage or 0)
	end
	if bait then
		drawBait(ctx, bait, t)
	end
end

-- ---------- 곁 · 해방 ----------
function RuneView.near(x: number, y: number): boolean
	local r = view.rune
	return r ~= nil and abs(x - r.x) <= R.reach.x and abs(y - r.y) <= R.reach.y
end
-- 지금 곁의 룬을 해방할 수 있나(룬이 1순위 — 2026-11-12): 곁에 있고 · 내 쿨이 끝났고 · 화살표 판이 떠 있지 않다. 쿨 중이면 폰의 상호작용 단추는 줍기로(룬 곁의 전리품도 주울 수 있게)
function RuneView.ready(x: number, y: number): boolean
	return RuneView.near(x, y) and left("cdLeft") <= 0 and not prompt and not starting
end
-- 머리 위의 글(boot의 이름표 자리 셈): 곁에 서 있으면 「↑ 룬 해방」
function RuneView.hint(x: number, y: number): (string?, number?, number?)
	local r = view.rune
	if r and not prompt and RuneView.near(x, y) then
		return W.hint, r.x, r.y - 34
	end
	return nil
end

local ARROW_ROWS = { -- 11 x 11 위쪽 화살표(돌려서 넷)
	".....#.....", "....###....", "...#####...", "..#######..", ".#########.", "###########", "....###....", "....###....", "....###....", "....###....", "....###....",
}
local function arrowAt(parent: Instance, dir: string, x: number, y: number, color: Color3)
	local g = Ui.group(parent, x, y, 11, 11, "Arrow")
	for ry, row in ARROW_ROWS do
		for rx = 1, 11 do
			if string.sub(row, rx, rx) == "#" then
				local px, py = rx - 1, ry - 1
				if dir == "down" then
					py = 10 - py
				elseif dir == "left" then
					px, py = py, px
				elseif dir == "right" then
					px, py = 10 - py, px
				end
				Ui.box(g, px, py, 1, 1, color)
			end
		end
	end
	return g
end

function RuneView.closePrompt()
	if prompt then
		Input.capture(nil)
		prompt.holder:Destroy()
		prompt = nil
	end
end

local function answer()
	if not prompt or prompt.sent then
		return
	end
	prompt.sent = true
	local keys = table.clone(prompt.keys)
	task.spawn(function()
		local ok, res = pcall(Net.Invoke, "Rune", "answer", keys)
		RuneView.closePrompt()
		if not ok or typeof(res) ~= "table" then
			return
		end
		local body = hooks and hooks.body and hooks.body()
		if res.result == "done" then
			view.buffLeft, view.cdLeft, view.guardLeft, mapAt = res.buffLeft, res.cdLeft, R.guard, os.clock()
			if hooks and hooks.banner then
				hooks.banner(Format.fill(W.done, { p = floor(R.buff.xp * 100 + 0.5), m = floor(R.buff.time / 60 + 0.5) }), nil)
			end
		elseif (res.result == "wrong" or res.result == "late") and body and hooks.float then
			hooks.float(Format.fill(if res.result == "wrong" then W.wrong else W.late, { s = res.retry or R.retry }), body.x, body.y - 46, Color3.fromRGB(255, 126, 162))
		end
	end)
end

local function press(dir: string)
	if not prompt or prompt.sent then
		return
	end
	local n = #prompt.keys + 1
	if n > #prompt.arrows then
		return
	end
	prompt.keys[n] = dir
	local slot = prompt.slots[n]
	if slot then
		local good = prompt.arrows[n] == dir
		slot.fill.BackgroundColor3 = if good then C.accent else C.red
	end
	if n >= #prompt.arrows then
		answer()
	else
		RuneView.listen()
	end
end
local KEY_DIR = { [Enum.KeyCode.Up] = "up", [Enum.KeyCode.Down] = "down", [Enum.KeyCode.Left] = "left", [Enum.KeyCode.Right] = "right", [Enum.KeyCode.W] = "up", [Enum.KeyCode.S] = "down", [Enum.KeyCode.A] = "left", [Enum.KeyCode.D] = "right" }
function RuneView.listen()
	Input.capture(function(code: Enum.KeyCode)
		local dir = KEY_DIR[code]
		if dir then
			press(dir)
		elseif prompt then
			RuneView.listen() -- 화살표가 아닌 키는 넘긴다
		end
	end)
end

-- 판: 「룬 해방」 · 「화살표를 차례대로 누르세요」 · 화살표 넷(칸 — 누르면 민트 · 틀리면 빨강) · 남은 시간 띠 · 아래에 누를 수 있는 화살표 단추 넷(폰)
local function openPrompt(arrows, time: number)
	RuneView.closePrompt()
	local n = #arrows
	local cell, gap = 26, 6
	local w = math.max(220, n * cell + (n - 1) * gap + 40)
	local h = 132
	local layer = Stage.group(Stage.ui, "Rune", 900) -- (매크로 확인 950 아래 · 창 · 메뉴 위)
	local holder = Stage.place(layer, "RunePrompt", "tc", math.floor((Stage.REF_W - w) / 2), 150, w, h)
	Ui.panel(holder, 0, 0, w, h)
	Ui.text(holder, W.head, 0, 10, w, { font = "body", align = "center", color = C.gold })
	Ui.text(holder, W.press, 0, 28, w, { align = "center", color = C.dim })
	local x0 = math.floor((w - (n * cell + (n - 1) * gap)) / 2)
	local slots = {}
	for i, a in arrows do
		local box = Ui.box(holder, x0 + (i - 1) * (cell + gap), 46, cell, cell, C.ink)
		local fill = Ui.box(box, 1, 1, cell - 2, cell - 2, C.panel2)
		arrowAt(fill, a, math.floor((cell - 2 - 11) / 2), math.floor((cell - 2 - 11) / 2), Color3.fromRGB(255, 255, 255))
		slots[i] = { box = box, fill = fill }
	end
	local barBack = Ui.box(holder, 16, 80, w - 32, 4, C.ink)
	local bar = Ui.box(barBack, 0, 0, w - 32, 4, C.gold)
	-- 누를 수 있는 화살표 단추(폰 · 마우스)
	local bw = 34
	local bx0 = math.floor((w - (4 * bw + 3 * 6)) / 2)
	for i, dir in { "left", "up", "down", "right" } do
		local b = Ui.button(holder, "", bx0 + (i - 1) * (bw + 6), 94, bw, function()
			press(dir)
		end, { h = 26 })
		arrowAt(b.frame, dir, math.floor((bw - 11) / 2), 7, Color3.fromRGB(207, 221, 230))
	end
	prompt = { holder = layer, arrows = arrows, keys = {}, slots = slots, bar = bar, barW = w - 32, deadline = os.clock() + time, time = time, sent = false }
	RuneView.listen()
end

-- ↑ — 곁에 룬이 있으면 해방을 시작한다(서버가 화살표를 고른다). 돌려주는 것: 이 ↑를 썼나
function RuneView.tryStart(x: number, y: number): boolean
	if not RuneView.near(x, y) or prompt or starting then
		return false
	end
	starting = true
	task.spawn(function()
		local ok, res = pcall(Net.Invoke, "Rune", "start")
		starting = false
		if not ok or typeof(res) ~= "table" then
			return
		end
		if res.arrows then
			openPrompt(res.arrows, tonumber(res.time) or R.time)
			return
		end
		local body = hooks and hooks.body and hooks.body()
		if body and hooks.float then
			local text = if res.why == "cool" then Format.fill(W.cool, { m = floor((res.cdLeft or 0) / 60), s = floor((res.cdLeft or 0) % 60) })
				elseif res.why == "wait" then Format.fill(W.wrong, { s = math.ceil(res.retryLeft or R.retry) })
				else nil
			if text then
				hooks.float(text, body.x, body.y - 46, Color3.fromRGB(255, 126, 162))
			end
		end
	end)
	return true
end

-- 장마다(boot): 해방 판의 남은 시간 · 별똥별에 닿았나
function RuneView.step(_dt: number)
	if prompt then
		local leftT = prompt.deadline - os.clock()
		prompt.bar.Size = UDim2.fromOffset(math.max(0, math.floor(prompt.barW * leftT / prompt.time)), 4)
		if leftT <= -0.5 and not prompt.sent then
			answer() -- 시간이 지났다: 서버가 「late」로 채점한다
		end
	end
	local body = hooks and hooks.body and hooks.body()
	if bait and body and not bait.picking and os.clock() - bait.born > 0.55 and abs(body.x - bait.x) <= 12 and abs(body.y - bait.y) <= 24 then
		local b = bait
		b.picking = true
		task.spawn(function()
			local ok, res = pcall(Net.Invoke, "Rune", "bait", b.id)
			if ok and typeof(res) == "table" and res.got then
				if bait == b then
					bait = nil
				end
				if hooks and hooks.float then
					hooks.float(Format.fill(B.words.got, { n = res.dust or 0 }), b.x, b.y - 30, Color3.fromRGB(255, 227, 154))
				end
				if hooks and hooks.picked then
					hooks.picked(b.x, b.y)
				end
			else
				b.picking = false
			end
		end)
	end
end

return RuneView
