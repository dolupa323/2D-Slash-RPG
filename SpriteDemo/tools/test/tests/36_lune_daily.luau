-- 「달의 계승자」 — 일일 의뢰(마을의 의뢰 게시판).
--  사용자 2026-10-13: "일일 퀘스트 필요합니다. 게시판이랑 상호작용해서 일퀘받는거 좋습니다. 근데 좀더 간결하게 해도 될거 같습니다.  5분쯤 걸리게 / 일일 의뢰는 10부터 열죠"
--  셈(shared/lune/sim/daily.luau) · 저장 · 알리미의 줄(shared/lune/ui/questPanel.luau) · 창(client/lune/ui/dailyWindow.luau)을 화면 없이 돌려 본다.
--  서버의 길(게시판 앞에서 받고 · 실제로 잡아 세고 · 낸다)은 13_lune_world.luau의 끝이 본다.
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local ITEMS = req("ReplicatedStorage/shared/lune/data/items.generated")
local L = req("ReplicatedStorage/shared/lune/ui/layout")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
local Panel = req("ReplicatedStorage/shared/lune/ui/questPanel")
local pixelText = req("Client/ui/pixelText")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})
local DD = Daily.DATA
local R = Daily.REGION
local NOW = 1700000000

local function same(a, b): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
-- DataStore가 하는 일의 흉내(차례로 놓인 표는 배열로, 그 밖의 표는 이름표가 글자인 표로)
local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local n = 0
	for _ in v do
		n += 1
	end
	local array = n > 0 and #v == n
	local out = {}
	for k, x in v do
		out[if array then k else tostring(k)] = json(x)
	end
	return out
end

-- ---- 1) 자료: 정해진 것 · 게시판 · 풀 ----
eq(DD.from, 10, "Lv.10부터 연다(사용자: \"일일 의뢰는 10부터 열죠\")")
eq(DD.perDay, 2, "하루 둘")
expect(DD.kills >= 20 and DD.kills <= 40 and DD.near >= DD.perDay, "의뢰 하나의 마릿수 · 뽑는 곳의 수")
expect(#DD.pay.xp == 150 and #DD.pay.money == 150 and #DD.pay.dust == 150, "보상은 레벨마다 하나")
for lv = 2, 150 do
	expect(DD.pay.xp[lv] >= DD.pay.xp[lv - 1] and DD.pay.money[lv] > DD.pay.money[lv - 1] and DD.pay.dust[lv] >= DD.pay.dust[lv - 1], "레벨이 오르면 보상이 줄지 않는다 Lv." .. lv)
end
local board = DD.boards[R]
expect(board ~= nil and SCENES.scenes[board.scene] ~= nil, "게시판이 있는 장면")
local boardNpc = nil
for _, n in SCENES.scenes[board.scene].npcs do
	if n.id == board.npc then
		boardNpc = n
	end
end
expect(boardNpc ~= nil and boardNpc.stone == true and boardNpc.name == board.name, "게시판이 마을에 놓여 있다(그림은 마을 그림의 것 — 이름표와 말만)")
eq(ITEMS.NPCDO[board.npc], "daily", "게시판 앞에서 ↑ = 일일 의뢰 창")
local onProp = false
for _, p in SCENES.scenes[board.scene].back do
	onProp = onProp or (p.id == "board" and p.x == boardNpc.x)
end
expect(onProp, "게시판의 자리 = 마을 그림에 놓인 게시판 소품의 자리")
local win = nil
for _, w in UI.windows do
	if w.id == "daily" then
		win = w
	end
end
expect(win ~= nil and win.key == false and win.from == DD.from, "일일 의뢰 창이 창의 목록에 있다(여는 키는 없다 · Lv.10부터)")
-- 풀: 레벨이 낮은 것부터 · 그 장면에 그 몬스터가 실제로 산다
for i, q in board.pool do
	local sc = SCENES.scenes[q.scene]
	local lives = false
	for _, m in (if sc then sc.mobs or {} else {}) do
		lives = lives or m.kind == q.mob
	end
	expect(lives, ("풀의 %s — 장면 %s에 그 몬스터(%s)가 있다"):format(q.name, tostring(q.scene), q.mob))
	expect(i == 1 or q.lv[1] >= board.pool[i - 1].lv[1], "풀은 레벨 차례다 " .. q.name)
	expect(pixelText.Measure(q.place, "small") <= L.DAILY.w - L.DAILY.btnW - 8, "맵의 이름이 칸에 든다 " .. q.place)
end

-- ---- 2) 그날의 의뢰: 공방의 셈과 같다 · 내 레벨에 맞는 사냥터 ----
for _, c in DD.checks do
	local got = Daily.pick(R, c.level, c.day)
	local mobs = {}
	for i, t in got do
		mobs[i] = t.mob
	end
	expect(same(mobs, c.mobs), ("Lv.%d %d일째의 의뢰가 공방의 것과 같다 — %s / %s"):format(c.level, c.day, table.concat(mobs, " "), table.concat(c.mobs, " ")))
end
for level = DD.from, 150 do
	local prev = ""
	for day = 0, 13 do
		local tasks = Daily.pick(R, level, day)
		eq(#tasks, DD.perDay, "하루 둘")
		expect(tasks[1].mob ~= tasks[2].mob, ("Lv.%d %d일째 — 서로 다른 몬스터"):format(level, day))
		for _, t in tasks do
			local q = Daily.entry(R, t.scene, t.mob)
			expect(q ~= nil and q.lv[1] <= level, ("Lv.%d — %s는 내 레벨로 갈 수 있는 사냥터다"):format(level, tostring(q and q.name)))
			expect(t.n == DD.kills and t.have == 0 and t.st == Daily.OPEN, "처음에는 받지 않은 것 · 0마리")
		end
		local key = tasks[1].mob .. "|" .. tasks[2].mob
		expect(key ~= prev, ("Lv.%d %d일째 — 어제와 같은 의뢰가 아니다"):format(level, day))
		prev = key
	end
end
-- 자정(한국 시간)에 날이 넘어간다
do
	local midnight = 86400 * 19700 - DD.offset * 3600 -- 한국 시간으로 자정인 순간
	eq(Daily.dayOf(midnight), Daily.dayOf(midnight - 1) + 1, "자정에 날이 바뀐다")
	eq(Daily.dayOf(midnight + 86399), Daily.dayOf(midnight), "그날의 끝까지 같은 날")
	eq(Daily.left(midnight), 86400, "자정에는 하루가 남았다")
	eq(Daily.left(midnight + 86399), 1, "자정 1초 전")
end

-- ---- 3) 하루의 흐름: 받는다 → 잡는다 → 낸다 → 덤 ----
local h = Hero.new(3601, "riven")
expect(next(h.daily) == nil, "새 캐릭터는 의뢰가 없다")
Hero.setLevel(h, DD.from - 1)
local v0 = Daily.view(h, NOW)
expect(next(v0.boards) == nil and v0.from == DD.from, "Lv.9에게는 게시판이 비어 있다")
expect(Daily.accept(h, R, 1, NOW) == nil and next(h.daily) == nil, "Lv.9는 받지 못한다")
expect(Daily.onKill(h, board.pool[1].mob, board.pool[1].scene, NOW) == false, "의뢰가 없으면 세지 않는다")
Hero.setLevel(h, 12)
local v1, fresh = Daily.view(h, NOW)
expect(fresh == true and v1.boards[R] ~= nil and #v1.boards[R].tasks == DD.perDay, "Lv.12: 오늘의 의뢰 둘이 생긴다(새로 뽑았다고 알린다 — 저장해야 한다)")
expect(select(2, Daily.view(h, NOW)) == false, "다시 보면 그대로다")
eq(Daily.mark(v1.boards[R]), "!", "안 받은 의뢰가 있다 = 게시판 위에 「!」")
expect(#Daily.tracked(v1) == 0, "받지 않은 의뢰는 알리미에 없다")
for _, t in v1.boards[R].tasks do
	expect(t.name ~= "" and t.place ~= "" and t.n == DD.kills and t.have == 0 and t.st == Daily.OPEN, "화면이 받는 의뢰: 이름 · 맵 · 수")
end
eq(v1.boards[R].pay.xp, DD.pay.xp[12], "보상은 내 레벨(12)의 것")
local t1, t2 = h.daily[R].tasks[1], h.daily[R].tasks[2]
-- 받기 전에는 세지 않는다
expect(Daily.onKill(h, t1.mob, t1.scene, NOW) == false and t1.have == 0, "받지 않은 의뢰는 세지 않는다")
expect(Daily.turnIn(h, R, 1, NOW) == nil, "받지 않은 의뢰는 내지 못한다")
expect(Daily.accept(h, R, 1, NOW) == true and t1.st == Daily.ON, "첫 의뢰를 받는다")
expect(Daily.accept(h, R, 1, NOW) == nil, "두 번 받지 못한다")
expect(Daily.accept(h, R, 3, NOW) == nil and Daily.accept(h, R, "x", NOW) == nil and Daily.accept(h, "r9", 1, NOW) == nil, "없는 의뢰 · 없는 지역")
-- 그 맵의 그 몬스터만 센다
expect(Daily.onKill(h, t1.mob, t1.scene, NOW) == true and t1.have == 1, "그 맵의 그 몬스터를 잡으면 센다")
expect(Daily.onKill(h, t2.mob, t2.scene, NOW) == false and t2.have == 0, "받지 않은 둘째 의뢰의 몬스터는 세지 않는다")
expect(Daily.onKill(h, t1.mob, "no_such_scene", NOW) == false and Daily.onKill(h, "warrior", t1.scene, NOW) == false and t1.have == 1, "다른 맵 · 다른 몬스터는 세지 않는다")
local v2 = Daily.view(h, NOW)
expect(#Daily.tracked(v2) == 1 and Daily.tracked(v2)[1].have == 1 and Daily.tracked(v2)[1].n == DD.kills, "받은 의뢰가 알리미에 뜬다")
expect(Daily.turnIn(h, R, 1, NOW) == nil and t1.st == Daily.ON, "다 잡기 전에는 내지 못한다")
for _ = 1, DD.kills + 5 do
	Daily.onKill(h, t1.mob, t1.scene, NOW)
end
eq(t1.have, DD.kills, "다 잡은 뒤에는 더 세지 않는다")
expect(Daily.isReady(t1) and Daily.mark(Daily.view(h, NOW).boards[R]) == "?", "다 잡았다 = 게시판 위에 「?」")
local money0, dust0 = h.money, h.dust
local r1 = Daily.turnIn(h, R, 1, NOW)
expect(r1 ~= nil and r1.xp == DD.pay.xp[12] and r1.money == DD.pay.money[12] and r1.dust == 0 and r1.all == false and r1.name ~= "", "첫 의뢰를 낸다: 경험치 · 달돈(덤은 아직)")
expect(h.money == money0 + r1.money and h.dust == dust0 and t1.st == Daily.DONE, "달돈이 는다 · 낸 것으로 바뀐다")
expect(Daily.turnIn(h, R, 1, NOW) == nil and h.money == money0 + r1.money, "두 번 내지 못한다")
eq(Daily.mark(Daily.view(h, NOW).boards[R]), "!", "둘째 의뢰가 남았다 = 「!」")
expect(Daily.accept(h, R, 2, NOW) == true, "둘째 의뢰를 받는다")
for _ = 1, DD.kills do
	Daily.onKill(h, t2.mob, t2.scene, NOW)
end
-- 저장: 싸고 풀어도 그대로다(저장소의 JSON을 거쳐도)
local packed = json(Hero.pack(h))
local back = Hero.unpack(3601, packed)
expect(back ~= nil and same(back.daily, h.daily), "다시 들어와도 의뢰의 상태가 남는다")
-- 레벨이 올라도 오늘의 의뢰는 그대로다(보상은 낼 때의 레벨)
Hero.setLevel(h, 20)
expect(select(2, Daily.view(h, NOW)) == false and h.daily[R].tasks[2] == t2, "레벨이 올라도 오늘 받은 의뢰는 바뀌지 않는다")
local r2 = Daily.turnIn(h, R, 2, NOW)
expect(r2 ~= nil and r2.all == true and r2.xp == DD.pay.xp[20] and r2.dust == DD.pay.dust[20] and r2.dust > 0, "둘째를 내면 덤(달가루)이 온다 — 낼 때의 레벨(20)의 것")
expect(h.dust == dust0 + r2.dust and h.daily[R].bonus == true, "달가루가 는다")
eq(Daily.mark(Daily.view(h, NOW).boards[R]), nil, "모두 냈다 = 표시가 없다")
expect(#Daily.tracked(Daily.view(h, NOW)) == 0, "모두 냈다 = 알리미에 없다")
-- 다음 날: 새 의뢰 · 어제 하던 것은 사라진다
local h2 = Hero.new(3602, "axion")
Hero.setLevel(h2, 15)
Daily.view(h2, NOW)
Daily.accept(h2, R, 1, NOW)
local old = h2.daily[R].tasks[1]
Daily.onKill(h2, old.mob, old.scene, NOW)
local TOMORROW = NOW + 86400
expect(Daily.onKill(h2, old.mob, old.scene, TOMORROW) == false and old.have == 1, "자정이 지나면 어제의 의뢰는 세지 않는다")
for _ = 1, DD.kills do
	Daily.onKill(h2, old.mob, old.scene, NOW)
end
expect(Daily.turnIn(h2, R, 1, TOMORROW) == nil, "다 잡고 안 낸 어제의 의뢰는 다음 날 내지 못한다(새 의뢰로 바뀐다)")
local v3, fresh3 = Daily.view(h2, TOMORROW)
expect(fresh3 == false and h2.daily[R].day == Daily.dayOf(TOMORROW) and h2.daily[R].tasks[1].st == Daily.OPEN and h2.daily[R].tasks[1].have == 0 and h2.daily[R].bonus == false, "다음 날: 새 의뢰 둘(받지 않은 것)")
expect(v3.boards[R].tasks[1].mob ~= old.mob or v3.boards[R].tasks[2].mob ~= Daily.pick(R, 15, Daily.dayOf(NOW))[2].mob, "어제와 다른 묶음이다")
-- 저장된 것이 이상하면 버린다(오늘의 의뢰를 새로 받는다) — 캐릭터는 그대로다
for _, bad in {
	"x",
	{ r1 = "x" },
	{ r1 = { day = -1, tasks = {}, bonus = false } },
	{ r1 = { day = 5, tasks = { { scene = "no", mob = "no", n = 30, have = 0, st = 0 }, { scene = "no", mob = "no", n = 30, have = 0, st = 0 } }, bonus = false } },
	{ r1 = { day = 5, tasks = { { scene = t1.scene, mob = t1.mob, n = 30, have = 99, st = 1 }, { scene = t2.scene, mob = t2.mob, n = 30, have = 0, st = 0 } }, bonus = false } },
	{ r1 = { day = 5, tasks = { { scene = t1.scene, mob = t1.mob, n = 30, have = 1, st = 7 }, { scene = t2.scene, mob = t2.mob, n = 30, have = 0, st = 0 } }, bonus = false } },
	{ r1 = { day = 5, tasks = { { scene = t1.scene, mob = t1.mob, n = 30, have = 1, st = 1 } }, bonus = false } },
} do
	expect(next(Daily.unpack(bad)) == nil, "이상한 저장은 버린다")
end
do
	local raw = Hero.pack(h)
	raw.daily = nil
	local old2 = Hero.unpack(3601, raw)
	expect(old2 ~= nil and next(old2.daily) == nil and old2.level == h.level, "일일 의뢰가 생기기 전의 저장: 의뢰만 없고 캐릭터는 그대로다")
end

-- ---- 4) 알리미의 줄: 받아 둔 의뢰가 「일일」로 뜬다 ----
do
	local h3 = Hero.new(3603, "mooni")
	Hero.setLevel(h3, 12)
	Daily.view(h3, NOW)
	Daily.accept(h3, R, 1, NOW)
	Daily.accept(h3, R, 2, NOW)
	local a = h3.daily[R].tasks[1]
	for _ = 1, 7 do
		Daily.onKill(h3, a.mob, a.scene, NOW)
	end
	local b = h3.daily[R].tasks[2]
	for _ = 1, DD.kills do
		Daily.onKill(h3, b.mob, b.scene, NOW)
	end
	local tracked = Daily.tracked(Daily.view(h3, NOW))
	eq(#tracked, 2, "받은 의뢰 둘")
	local rows0 = Panel.layout({}, {}, nil, nil, nil)
	local rows, height, shown = Panel.layout({}, {}, nil, nil, tracked)
	eq(#rows0, 0, "의뢰를 안 주면 줄이 없다(전과 같다)")
	eq(shown, 2, "알리미에 둘이 뜬다")
	expect(height <= Panel.H, ("PC의 칸에 든다(%d / %d)"):format(height, Panel.H))
	-- 스마트폰의 칸은 더 낮다: 그 높이를 주면 들어가는 데까지만 적는다(적어도 하나)
	local _, heightT, shownT = Panel.layout({}, {}, nil, Panel.H_TOUCH, tracked)
	expect(shownT >= 1 and heightT <= Panel.H_TOUCH, ("스마트폰의 칸에는 들어가는 만큼만(%d개 · %d / %d)"):format(shownT, heightT, Panel.H_TOUCH))
	local kinds = {}
	for _, r in rows do
		table.insert(kinds, r.kind)
		if r.kind == "quest" then
			expect(r.tag == "daily" and Panel.TAGS[r.tag] == "일일", "갈래의 표 = 「일일」")
			expect(pixelText.Measure(r.name, "body") <= Panel.INNER - Panel.TAG_W - Panel.TAG_GAP, "맵의 이름이 판에 든다 " .. r.name)
		elseif r.kind == "step" then
			expect(r.count == ("7/%d"):format(DD.kills) and r.have == 7 and r.n == DD.kills, "하는 중: 「7/30」")
			expect(pixelText.Measure(r.text, "small") <= Panel.INNER - 2 - Panel.COUNT_W and pixelText.Measure(r.count, "small") <= Panel.COUNT_W, "몬스터의 이름과 수가 판에 든다")
		elseif r.kind == "ready" then
			eq(r.text, Panel.DAILY_BACK, "다 잡았다: 「게시판에 낸다」")
			expect(pixelText.Measure(r.text, "small") <= Panel.INNER - 20, "그 글이 판에 든다")
		end
	end
	eq(table.concat(kinds, " "), "quest step quest ready", "줄의 차례")
	-- 풀의 모든 몬스터 이름이 알리미의 한 줄에 든다
	for _, q in board.pool do
		expect(pixelText.Measure(q.name, "small") <= Panel.INNER - 2 - Panel.COUNT_W, "알리미의 줄 — " .. q.name)
		expect(pixelText.Measure(q.place, "body") <= Panel.INNER - Panel.TAG_W - Panel.TAG_GAP, "알리미의 제목 — " .. q.place)
	end
end

-- ---- 5) 일일 의뢰 창을 화면 없이 지어 본다 ----
do
	local Format = req("ReplicatedStorage/shared/lune/ui/format")
	local ICONS = KIT.parts.icons.icons
	local made = {}
	local function frame(name: string?)
		return { Name = name or "Frame", Visible = true }
	end
	local any = setmetatable({}, { __index = function(_, k) return "color:" .. tostring(k) end })
	MOCK("Client/lune/ui/ui", {
		COLOR = any,
		M = L.M,
		measure = function(text: string, font: string?) return (pixelText.Measure(text, font or "small")) end,
		line = function(parent, x, y, w)
			local f = frame("Line")
			f.kind, f.parent, f.x, f.y, f.w, f.h = "line", parent, x, y, w, 1
			table.insert(made, f)
			return f
		end,
		text = function(parent, text, x, y, width, opts)
			local font = if opts and opts.font then opts.font else "small"
			local item = { kind = "text", parent = parent, value = text, x = x, y = y, w = width, h = if font == "body" then L.M.body else L.M.small, font = font, align = if opts and opts.align then opts.align else "left" }
			function item.set(_, v) item.value = v end
			function item.color(_, c) item.tint = c end
			function item.move(_, nx, ny) item.x, item.y = nx, ny end
			table.insert(made, item)
			return item
		end,
		button = function(parent, text, x, y, w, onClick, opts)
			local item = { kind = "button", parent = parent, value = text, x = x, y = y, w = w, h = if opts and opts.h then opts.h else L.M.button, click = onClick, frame = frame("Button"), main = opts ~= nil and opts.main == true }
			function item.setText(_, v) item.value = v end
			function item.setEnabled() end
			table.insert(made, item)
			return item
		end,
		bar = function(parent, x, y, w, h)
			local item = { kind = "bar", parent = parent, x = x, y = y, w = w, h = h, ratio = 0, frame = frame("Bar") }
			function item.set(_, r) item.ratio = r end
			function item.setColor(_, c) item.tint = c end
			table.insert(made, item)
			return item
		end,
		smallIcon = function(parent, name, x, y)
			local item = { kind = "icon", parent = parent, w = 18, h = 18, name = name, Visible = true, Position = UDim2.fromOffset(x, y) }
			table.insert(made, item)
			return item
		end,
	})
	local DailyWindow = req("Client/lune/ui/dailyWindow")
	local w, hgt = DailyWindow.size()
	expect(w + 36 <= 768 and hgt + 64 <= 432, "일일 의뢰 창이 스마트폰의 화면 틀(768x432)에 들어간다")
	local W = Daily.WORDS
	for _, word in { W.accept, W.turn } do
		expect(pixelText.Measure(word, "body") <= L.DAILY.btnW - 6, "단추의 글 " .. word)
	end
	expect(pixelText.Measure(W.each, "small") <= L.DAILY.labelW - 4 and pixelText.Measure(W.all, "small") <= L.DAILY.labelW - 4, "보상 줄의 이름표가 제 칸에 든다")
	expect(pixelText.Measure(W.head, "small") + pixelText.Measure(W.reset, "small") + 8 <= w, "머리글 둘이 한 줄에 든다")
	expect(ICONS.coin ~= nil and ICONS.dust ~= nil, "보상의 그림(달돈 · 달가루)")
	-- 가장 넓은 보상(Lv.150)도 한 줄에 든다
	expect(L.DAILY.labelW + pixelText.Measure(("%s %s"):format(W.xp, Format.short(DD.pay.xp[150])), "small") + 12 + 21 + pixelText.Measure(Format.short(DD.pay.money[150]), "small") <= w, "보상의 줄이 창의 폭에 든다(Lv.150)")
	-- 풀의 모든 의뢰 이름이 단추 왼쪽에 든다
	for _, q in board.pool do
		local name = DailyWindow.taskName({ name = q.name, n = DD.kills })
		expect(pixelText.Measure(name, "body") <= w - L.DAILY.btnW - 8, ("의뢰의 이름이 칸에 든다 「%s」"):format(name))
	end

	-- 서버 대신 셈을 바로 부른다(받기 · 내기)
	local hw = Hero.new(3604, "reaper")
	Hero.setLevel(hw, 12)
	local state = (Daily.view(hw, NOW))
	local calls = {}
	local body = frame("Body")
	local view = DailyWindow.build(body, {
		daily = function() return state end,
		dailyDo = function(action, region, i)
			table.insert(calls, action .. ":" .. tostring(i))
			if action == "accept" then
				Daily.accept(hw, region, i, NOW)
			else
				Daily.turnIn(hw, region, i, NOW)
			end
			state = (Daily.view(hw, NOW))
		end,
	}, w, hgt)
	local function of(kind: string)
		local out = {}
		for _, e in made do
			if e.kind == kind and e.parent == body then
				table.insert(out, e)
			end
		end
		table.sort(out, function(a, b)
			local ay, by = if a.Position then a.Position.Y.Offset else a.y, if b.Position then b.Position.Y.Offset else b.y
			if ay ~= by then
				return ay < by
			end
			return (if a.Position then a.Position.X.Offset else a.x) < (if b.Position then b.Position.X.Offset else b.x)
		end)
		return out
	end
	local buttons, bars = of("button"), of("bar")
	eq(#buttons, DD.perDay, "의뢰마다 단추 하나")
	eq(#bars, DD.perDay, "의뢰마다 진행 띠 하나")
	-- 겹치지 않고 창 안이다(보이는 것만 — 글은 실제 폭)
	local function tidy(label: string)
		local shown = {}
		for _, e in made do
			if e.parent == body then
				local x0, y0, x1, y1
				if e.kind == "icon" then
					x0, y0 = e.Position.X.Offset, e.Position.Y.Offset
					x1, y1 = x0 + 18, y0 + 18
				elseif e.kind == "text" then
					local tw = pixelText.Measure(e.value, e.font)
					expect(tw <= e.w, ("%s — 글이 제 칸에 든다 「%s」(%d / %d)"):format(label, e.value, tw, e.w))
					x0 = if e.align == "right" then e.x + e.w - tw else e.x
					x1, y0, y1 = x0 + tw, e.y, e.y + e.h
				else
					x0, y0, x1, y1 = e.x, e.y, e.x + e.w, e.y + e.h
				end
				local on = if e.kind == "text" then e.value ~= "" elseif e.kind == "button" or e.kind == "bar" then e.frame.Visible elseif e.kind == "icon" then e.Visible else true
				if on then
					table.insert(shown, { x0 = x0, y0 = y0, x1 = x1, y1 = y1, name = tostring(e.value or e.name or e.kind) })
				end
			end
		end
		for i, a in shown do
			expect(a.x0 >= 0 and a.x1 <= w and a.y0 >= 0 and a.y1 <= hgt, ("%s — 창 안이다 %s(%d~%d, %d~%d / %dx%d)"):format(label, a.name, a.x0, a.x1, a.y0, a.y1, w, hgt))
			for j = i + 1, #shown do
				local b = shown[j]
				expect(a.x1 <= b.x0 or b.x1 <= a.x0 or a.y1 <= b.y0 or b.y1 <= a.y0, ("%s — 겹친다: %s(%d~%d, %d~%d) · %s(%d~%d, %d~%d)"):format(label, a.name, a.x0, a.x1, a.y0, a.y1, b.name, b.x0, b.x1, b.y0, b.y1))
			end
		end
	end
	local function counts(): { string }
		local out = {}
		for _, e in of("text") do
			if e.align == "right" and e.y > L.DAILY.top and e.y < L.DAILY.top + DD.perDay * L.DAILY.row then
				table.insert(out, e.value)
			end
		end
		return out
	end
	-- 처음: 둘 다 「받는다」
	expect(buttons[1].frame.Visible and buttons[1].value == W.accept and buttons[2].frame.Visible and buttons[2].value == W.accept and buttons[1].main, "처음에는 둘 다 「받는다」(민트 단추)")
	expect(bars[1].ratio == 0 and bars[2].ratio == 0, "진행 띠는 비어 있다")
	local moneyText = Format.short(DD.pay.money[12])
	local seenPay = false
	for _, e in of("text") do
		seenPay = seenPay or e.value == moneyText
	end
	expect(seenPay, "보상에 내 레벨(12)의 달돈이 적힌다")
	tidy("처음")
	-- 받는다 → 「0/30」
	buttons[1].click()
	view.refresh()
	eq(calls[#calls], "accept:1", "「받는다」 = 받기를 청한다")
	expect(buttons[1].frame.Visible == false and counts()[1] == ("0/%d"):format(DD.kills), "받으면 단추 대신 「0/30」")
	local task = hw.daily[R].tasks[1]
	for _ = 1, 12 do
		Daily.onKill(hw, task.mob, task.scene, NOW)
	end
	state = (Daily.view(hw, NOW))
	view.refresh()
	expect(counts()[1] == ("12/%d"):format(DD.kills) and math.abs(bars[1].ratio - 12 / DD.kills) < 1e-9, "잡은 만큼 숫자와 띠가 찬다")
	tidy("하는 중")
	for _ = 1, DD.kills do
		Daily.onKill(hw, task.mob, task.scene, NOW)
	end
	state = (Daily.view(hw, NOW))
	view.refresh()
	expect(buttons[1].frame.Visible and buttons[1].value == W.turn and counts()[1] == "", "다 잡으면 「낸다」 단추")
	tidy("낼 수 있다")
	buttons[1].click()
	view.refresh()
	eq(calls[#calls], "turn:1", "「낸다」 = 내기를 청한다")
	expect(buttons[1].frame.Visible == false and counts()[1] == W.done and bars[1].ratio == 1, "내면 「완료」 · 띠가 가득")
	expect(buttons[2].frame.Visible and buttons[2].value == W.accept, "둘째는 그대로 「받는다」")
	tidy("하나를 냈다")
	-- 의뢰가 아직 없을 때(서버의 대답이 오기 전): 빈 창이어도 오류가 없다
	state = nil
	view.refresh()
	expect(buttons[1].frame.Visible == false and buttons[2].frame.Visible == false, "받은 것이 없으면 단추가 없다")
end
