-- 「달의 계승자」 — 땅 속에 끼지 않게(2026-10-21) · 폰의 점프 · 상호작용 단추도 끌어 옮기기(2026-10-21).
--  사용자(폰 스크린샷 — 세 갈래 길 오른쪽의 턱 안에 캐릭터가 박혀 있다): "모바일에서 내가 지금준 스크린샷처럼 대쉬하다가 맵을뚫고 낑기는 현상 발생합니다
--   그리고 모바일에서 상호작용, 점프키 같은거 위치 다 바꿀수있어야해요 드래그앤 드랍으로 다른 버튼들처럼"
--  보는 것: ① 끼었으면 꺼낸다(sim/physics.luau의 freeSpot · unstick — 위가 먼저) ② 모든 맵의 서는 자리(시작 · 문 · 간이 포탈 · 사람 · 사다리)는 땅 속이 아니다
--   ③ 서버: 다른 맵의 자리 보고는 받지 않는다 · 계속 어긋나면 서버의 맵으로 다시 보낸다 · 되돌려 보내는 자리 · 세우는 자리는 땅 속이 아니다 · 던전에서 나와 서는 자리
--   ④ 칸 셈: 점프 · 상호작용은 폰의 칸 13 · 14에 처음 놓이고 · 늘 하나씩 · 빼지도 덮지도 못하고 · 끌면 자리를 바꾼다 · PC의 퀵슬롯에는 놓이지 않는다 · 스킬을 다시 찍어도 남는다
--   ⑤ 폰 단추(client/lune/touch.luau를 가짜 화면으로): 점프 · 상호작용을 누르면 그 일을 하고 · 「단추 배치」에서 끌면 자리를 바꾸고 · 목록에서 골라도 바꾸고 · 「비우기」는 안 되고 · 판이 단추를 덮지 않는다
local P = req("ReplicatedStorage/shared/lune/sim/physics")
local G = req("ReplicatedStorage/shared/lune/config/game")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local Quick = req("ReplicatedStorage/shared/lune/ui/quick")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Rift = req("ReplicatedStorage/shared/lune/sim/rift")
local T = G.TILE

local function same(a, b)
	for i = 1, Quick.N do
		if (a[i] or false) ~= (b[i] or false) then
			return false
		end
	end
	return true
end

-- ① 꺼내기 — 스크린샷의 자리: 세 갈래 길(r1af)의 오른쪽 턱(x 336부터 한 칸 · x 368부터 두 칸) 안, 발 높이 176(아래 땅)
do
	local sc = SCENES.scenes.r1af
	expect(P.solidBox(sc, 385, 176), "세 갈래 길 x 385 · 발 176 = 턱 안(스크린샷의 자리)")
	local x, y = P.freeSpot(sc, 385, 176)
	expect(not P.solidBox(sc, x, y), ("꺼낸 자리는 땅 속이 아니다 (%s, %s)"):format(x, y))
	eq(y, 144, "위로 — 턱의 윗면(144)에 선다")
	eq(x, 385, "가로는 그대로")
	local bx, by = P.freeSpot(sc, 200, 176)
	expect(bx == 200 and by == 176, "끼지 않았으면 그대로")
	-- 한 칸 턱 바로 안(가장자리): 위로 한 칸
	x, y = P.freeSpot(sc, 345, 176)
	expect(not P.solidBox(sc, x, y) and y == 160 and x == 345, ("한 칸 턱 안 → 그 윗면 (%s, %s)"):format(x, y))
	-- 몸을 꺼내면 빠르기를 멈춘다
	local body = { x = 385, y = 176, vx = 520, vy = 30, ground = true }
	expect(P.unstick(sc, body), "끼었으면 꺼냈다고 알린다")
	expect(body.vx == 0 and body.vy == 0 and not P.solidBox(sc, body.x, body.y), "꺼낸 몸은 멈추고 땅 속이 아니다")
	expect(not P.unstick(sc, body), "다시 부르면 그대로")
	-- 대쉬로 턱을 향해 달려도 몸은 턱에 들어가지 않는다(물리 그대로 — 이 셈은 원래 막는다)
	local b2 = { x = 300, y = 176, vx = 0, vy = 0, ground = true }
	for _ = 1, 60 do
		P.step(sc, b2, { mx = 0, vx = 520, float = true }, 1 / 60)
		expect(not P.solidBox(sc, b2.x, b2.y), "대쉬 중에도 턱 안에 들어가지 않는다")
	end
	-- 모든 맵의 아무 자리나: 꺼낸 자리는 늘 땅 속이 아니다 · 맵 안이다
	local rng = Random.new(76)
	local bad = 0
	for key, s in SCENES.scenes do
		if typeof(s) == "table" and s.rows and s.w and s.h then
			for _ = 1, 40 do
				local px, py = rng:NextNumber(8, s.w * T - 8), rng:NextNumber(20, s.h * T)
				local fx, fy = P.freeSpot(s, px, py)
				if P.solidBox(s, fx, fy) or fx < 0 or fx > s.w * T then
					bad += 1
					if bad <= 3 then
						expect(false, ("%s (%d, %d) → (%d, %d)이 땅 속"):format(key, px, py, fx, fy))
					end
				end
			end
		end
	end
	eq(bad, 0, "모든 맵에서 꺼낸 자리는 땅 속이 아니다")
end

-- ② 서는 자리들
do
	local inWall = {}
	for key, s in SCENES.scenes do
		if typeof(s) == "table" and s.rows and s.spawn then
			local function check(what, x, y)
				if P.solidBox(s, x, y) then
					table.insert(inWall, ("%s %s (%d, %d)"):format(key, what, x, y))
				end
			end
			check("시작 자리", s.spawn.x, s.spawn.y)
			for _, p in s.portals or {} do
				check("문 → " .. tostring(p.to), p.x, p.y)
			end
			for _, w in s.warps or {} do
				check("간이 포탈 " .. tostring(w.id), w.x, w.y)
			end
			for _, n in s.npcs or {} do
				check("사람 " .. tostring(n.name), n.x, n.y)
			end
			for i, l in s.ladders or {} do
				for y = l.top, l.bottom, 4 do
					check("사다리 " .. i, l.x, y)
				end
			end
		end
	end
	eq(#inWall, 0, "서는 자리가 땅 속인 곳이 없다 " .. table.concat(inWall, " · ", 1, math.min(#inWall, 4)))
end

-- ③ 서버
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local p = { UserId = 7601, Name = "끼임시험", DisplayName = "끼임시험", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "끼임시험", "riven")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local function last(name: string)
	local got = nil
	for _, f in sent do
		if f.name == name and f.player == p then
			got = f
		end
	end
	return got
end
local function tickFor(sec: number)
	for _ = 1, math.floor(sec * 20 + 0.5) do
		World.tick(1 / 20)
	end
end
do
	World.jump(p, "r1af")
	eq(s.scene, "r1af", "세 갈래 길")
	local sc = SCENES.scenes.r1af
	tickFor(2.5) -- (관리 이동 직후 2초는 옮겨 놓은 자리에서 먼 보고를 늦은 보고로 본다 — LOAD_STALE)
	handlers.Move(p, 200, 176, 1, "r1af")
	eq(s.hero.x, 200, "이 맵의 자리 보고는 받는다")
	-- 다른 맵의 자리: 받지 않는다(늦은 보고 · 어긋난 화면)
	handlers.Move(p, 230, 176, 1, "hunt")
	eq(s.hero.x, 200, "다른 맵(달그림자 사냥터)의 자리 보고는 받지 않는다")
	handlers.Move(p, 210, 176, 1)
	eq(s.hero.x, 210, "맵을 적지 않은 보고는 예전처럼 받는다")
	-- 4초 넘게 계속 다른 맵이면: 서버의 맵으로 다시 보낸다(Revive)
	table.clear(sent)
	handlers.Move(p, 230, 176, 1, "hunt")
	tickFor(2)
	handlers.Move(p, 230, 176, 1, "hunt")
	expect(last("Revive") == nil, "2초는 기다린다(장면을 옮기는 중일 수 있다)")
	tickFor(2.5)
	handlers.Move(p, 230, 176, 1, "hunt")
	local rv = last("Revive")
	expect(rv ~= nil and rv.args[1].scene == "r1af", "4초 넘게 어긋나면 서버의 맵(세 갈래 길)으로 다시 보낸다")
	eq(s.scene, "r1af", "그대로 세 갈래 길")
	-- 되돌려 보내는 자리: 서버가 아는 자리가 땅 속이어도 꺼내서 보낸다
	tickFor(1)
	handlers.Move(p, 210, 176, 1, "r1af")
	s.hero.x, s.hero.y = 385, 176 -- (어떤 길로든 서버의 자리가 턱 안이 되었다고 치고)
	table.clear(sent)
	tickFor(1)
	handlers.Move(p, 30, 176, 1, "r1af") -- 너무 먼 보고 → 되돌려 보낸다
	local w = last("Warp")
	expect(w ~= nil, "먼 보고는 되돌려 보낸다(Warp)")
	if w then
		expect(not P.solidBox(sc, w.args[1], w.args[2]), ("되돌려 보내는 자리는 땅 속이 아니다 (%s, %s)"):format(tostring(w.args[1]), tostring(w.args[2])))
		eq(w.args[2], 144, "턱의 윗면으로")
	end
	expect(not P.solidBox(sc, s.hero.x, s.hero.y), "서버가 아는 자리도 꺼냈다")
	-- 문을 지나 들어선 자리 · 관리 이동으로 선 자리는 땅 속이 아니다
	for _, key in { "r1af", "hunt", "r2ah", "ct" } do
		World.jump(p, key)
		expect(not P.solidBox(SCENES.scenes[key], s.hero.x, s.hero.y), key .. ": 들어선 자리는 땅 속이 아니다")
	end
	-- 던전에서 나와 서는 자리(반달네 옛집 — 문이 선 높은 땅): 전에는 맵 시작 자리의 높이라 땅 속이었다
	local t = Rift.tier("dg1")
	local door = nil
	for _, q in SCENES.scenes[t.door.scene].portals do
		if q.dungeon == t.id then
			door = q
		end
	end
	expect(door ~= nil, "던전의 문")
	if door then
		expect(P.solidBox(SCENES.scenes.r2ah, door.x - 30, SCENES.scenes.r2ah.spawn.y), "(전의 자리 = 문 왼쪽 30점 · 시작 자리의 높이는 땅 속이었다)")
		expect(not P.solidBox(SCENES.scenes.r2ah, door.x - 30, door.y), "이제의 자리 = 문 왼쪽 30점 · 문의 높이는 땅 속이 아니다")
	end
end

-- ④ 칸 셈 — 점프 · 상호작용
do
	local J, I = "act_jump", "act_interact"
	eq(Quick.ACTS[J].home, 13, "점프는 처음에 칸 13")
	eq(Quick.ACTS[I].home, 14, "상호작용은 처음에 칸 14")
	eq(Quick.act(J), "jump", "점프")
	eq(Quick.act(I), "interact", "상호작용")
	expect(Quick.act("potion1") == nil and Quick.act(false) == nil, "다른 것은 아니다")
	local spot = {}
	for _, t in UI.touch do
		if t.slot then
			spot[t.slot] = t
		end
	end
	expect(spot[13] and spot[13].x == 340 and spot[13].y == 116, "칸 13의 단추 = 전의 점프 단추 자리(사냥기 위)")
	expect(spot[14] and spot[14].x == 82 and spot[14].y == 140, "칸 14의 단추 = 전의 상호작용 단추 자리(조이스틱 오른쪽)")
	for class, c in CLASSES.classes do
		local start = Quick.touchStart(c.skills)
		expect(start[13] == J and start[14] == I, class .. ": 새 캐릭터의 폰 배치에 점프 · 상호작용")
		local h = Hero.new(1, class)
		expect(h.tslots[13] == J and h.tslots[14] == I, class .. ": 새 캐릭터")
		expect(Quick.find(h.slots, J) == nil and Quick.find(h.slots, I) == nil, class .. ": PC의 퀵슬롯에는 없다")
	end
	local base = Quick.touchStart(CLASSES.classes.riven.skills)
	-- 끌어서 자리를 바꾼다(놓인 것끼리)
	local moved = Quick.place(base, J, 2)
	expect(moved and moved[2] == J and moved[13] == base[2], "점프를 칸 2(가장 큰 단추)로 끌면 사냥기와 자리를 바꾼다")
	moved = Quick.place(base, base[4], 14)
	expect(moved and moved[14] == base[4] and moved[4] == I, "대쉬를 상호작용 단추로 끌면 둘이 자리를 바꾼다")
	-- 빼지 못하고 · 밖에서 온 것으로 덮지 못한다
	expect(Quick.clear(base, 13) == nil and Quick.clear(base, 14) == nil, "점프 · 상호작용은 「비우기」가 안 된다")
	expect(Quick.place(base, "potion2", 13) == nil, "가방에서 끌어 온 물약으로 점프를 덮지 못한다")
	expect(Quick.place(base, "potion2", 6) ~= nil, "빈 칸에는 놓인다")
	-- 없으면 처음 칸에 · 둘이면 하나만 · 처음 칸에 있던 것은 빈 칸으로
	local old = table.clone(base)
	old[13], old[14] = false, false -- (이것이 생기기 전에 저장된 폰 배치)
	old[13] = "zz"
	local fixed = Quick.touchFix(old)
	expect(fixed[13] == J and fixed[14] == I, "예전 배치에도 점프 · 상호작용이 처음 칸에 들어온다")
	expect(Quick.find(fixed, "zz") ~= nil, "칸 13에 있던 것은 빈 단추로 옮겨진다")
	local twice = table.clone(base)
	twice[6] = J
	fixed = Quick.touchFix(twice)
	local n = 0
	for i = 1, Quick.N do
		if fixed[i] == J then
			n += 1
		end
	end
	eq(n, 1, "점프가 둘이면 하나만 남는다")
	expect(same(Quick.touchFix(fixed), fixed), "한 번 손본 것은 그대로")
	-- 서버: 폰 배치는 받고 · PC 배치에는 안 받는다 · 스킬을 다시 찍어도 남는다
	local h = Hero.new(2, "axion")
	local mine = table.clone(h.tslots)
	mine[13], mine[2] = mine[2], J
	expect(Hero.setSlots(h, mine, true) and h.tslots[2] == J and h.tslots[13] == mine[13], "폰 배치: 점프를 옮겨 보낸 것을 받는다")
	local pc = table.clone(h.slots)
	pc[6] = J
	expect(not Hero.setSlots(h, pc, false), "PC의 퀵슬롯에는 점프 · 상호작용을 놓지 못한다")
	Hero.resetSkills(h)
	expect(h.tslots[2] == J and Quick.find(h.tslots, I) ~= nil, "스킬을 처음부터 다시 찍어도 점프 · 상호작용은 남는다")
	local back = Hero.unpack(2, Hero.pack(h))
	expect(back and back.tslots[2] == J and back.tslots[14] == I, "저장하고 다시 읽어도 옮긴 자리 그대로")
	-- 접속한 사람: TouchSlots로 바꾸면 남는다
	local ts = table.clone(s.hero.tslots)
	local from13 = ts[13]
	ts[13], ts[3] = ts[3], from13
	local got = handlers.TouchSlots(p, ts)
	expect(got and got[3] == J, "접속한 사람의 폰 배치: 점프를 칸 3(보스기 단추)으로")
end

-- ⑤ 폰 단추(touch.luau를 가짜 화면으로)
do
	RESET()
	local function sig()
		local q = { fns = {} }
		function q:Connect(fn)
			table.insert(self.fns, fn)
			return { Disconnect = function() end }
		end
		function q:Fire(...)
			for _, f in self.fns do
				f(...)
			end
		end
		return q
	end
	local changed, ended = sig(), sig()
	SERVICE("UserInputService", { InputChanged = changed, InputEnded = ended, TouchEnabled = true, KeyboardEnabled = false })
	SERVICE("RunService", { Heartbeat = sig() })
	local function frame(name)
		local f = Instance.new("Frame")
		f.Name = name
		f.AbsolutePosition = Vector2.new(0, 0)
		f.GetChildren = function() return {} end
		f.Destroy = function() end
		return f
	end
	local uiRoot = frame("Ui")
	MOCK("Client/lune/stage", {
		ratio = 2, uiScale = 1, uiH = 432, insetTop = 0, ui = uiRoot,
		gui = { GetAttribute = function() return true end, GetAttributeChangedSignal = function() return sig() end },
		group = function(_, name) return frame(name) end,
		place = function(_, name) return frame(name) end,
		onResize = function() end,
	})
	local texts, hits, buttons = {}, {}, {}
	MOCK("Client/lune/ui/ui", {
		COLOR = setmetatable({}, { __index = function(_, k) return k end }),
		text = function(parent, text, x, y, width, opts)
			local item = { text = text, parent = parent, x = x, width = width, shown = true, label = { Frame = {} }, opts = opts }
			function item.set(self, v) self.text = v end
			function item.show(self, on) self.shown = on end
			function item.color(self, c) self.col = c end
			table.insert(texts, item)
			return item
		end,
		pic = function(_, name) return { name = name } end,
		setPic = function(pic, name) pic.name = name end,
		slot = function() local f = frame("Slot"); return { frame = f, setOn = function() end } end,
		hit = function(f) local h = { Activated = sig(), frame = f }; table.insert(hits, h); return h end,
		panel = function() return frame("Panel") end,
		scroll = function() return frame("Scroll") end,
		button = function(_, text, _, _, _, fn) local b = { text = text, fn = fn, frame = {} }; table.insert(buttons, b); return b end,
		box = function() return frame("Box") end,
		group = function(_, _, _, _, _, name) return frame(name) end,
	})
	MOCK("Client/lune/hud", { active = {}, marks = {}, countOf = function() return 0 end })
	local pressed = {}
	MOCK("Client/lune/input", {
		press = function(a) pressed[a] = true end,
		release = function(a) pressed[a] = false end,
	})
	UDim = UDim or { new = function(scale, offset) return { Scale = scale, Offset = offset } end } -- (가짜 화면에는 UDim이 없다 — 단추의 둥근 모서리)
	local Touch = req("Client/lune/touch")
	local applied, acts = {}, {}
	local choices = { { what = "act_jump", name = "점프" }, { what = "act_interact", name = "상호작용" } }
	Touch.init({
		choices = function() return choices end,
		apply = function(next) table.insert(applied, next); Touch.setSlots(next) end,
		repeats = function() return false end,
		onAct = function(down) table.insert(acts, down) end,
		onToggle = function() end,
		onMenu = function() end,
	})
	expect(Touch.on, "터치 화면이면 켜진다")
	-- 단추 틀(T + 번호)과 그 누르는 칸(Hit)
	local byNo, hitOf = {}, {}
	for _, inst in CREATED do
		if inst.ClassName == "Frame" and typeof(inst.Name) == "string" and string.match(inst.Name, "^T%d+$") then
			byNo[tonumber(string.sub(inst.Name, 2))] = inst
			local pos, size = inst.Position, inst.Size
			inst.AbsolutePosition = Vector2.new(pos.X.Offset, pos.Y.Offset)
			inst.AbsoluteSize = Vector2.new(size.X.Offset, size.Y.Offset)
		end
	end
	for _, inst in CREATED do
		if inst.ClassName == "TextButton" and inst.Name == "Hit" and inst.Parent then
			for no, f in byNo do
				if inst.Parent == f then
					hitOf[no] = inst
				end
			end
		end
	end
	local noOf = {}
	for _, t in UI.touch do
		if t.slot then
			noOf[t.slot] = t.no
		end
	end
	expect(hitOf[noOf[13]] ~= nil and hitOf[noOf[14]] ~= nil, "칸 13 · 14의 단추가 있다(전의 점프 · 상호작용 자리)")
	local function actText(no)
		for _, it in texts do
			if it.width == 80 and it.x == -40 and it.parent and it.parent.Parent == byNo[no] then
				return it
			end
		end
		return nil
	end
	local start = Quick.touchStart(CLASSES.classes.riven.skills)
	Touch.setSlots(start)
	local jt, it = actText(noOf[13]), actText(noOf[14])
	expect(jt and jt.shown and jt.text == "점프", "칸 13의 단추에 「점프」")
	expect(it and it.shown and it.text == "상호작용", "칸 14의 단추에 「상호작용」")
	Touch.setAct("npc")
	expect(it and it.text == "말 걸기", "주민 곁이면 「말 걸기」(전의 상호작용 단추와 같다)")
	Touch.setAct(nil)
	-- 누르기 · 떼기
	local finger = { UserInputType = Enum.UserInputType.Touch, Position = { X = 0, Y = 0 } }
	hitOf[noOf[13]].InputBegan:Fire(finger)
	expect(pressed.jump == true, "점프 단추를 누르면 뛰기를 누른다")
	ended:Fire(finger)
	expect(pressed.jump == false, "손을 떼면 뛰기를 뗀다")
	local f2 = { UserInputType = Enum.UserInputType.Touch, Position = { X = 0, Y = 0 } }
	hitOf[noOf[14]].InputBegan:Fire(f2)
	expect(acts[#acts] == true, "상호작용 단추를 누르면 상호작용")
	ended:Fire(f2)
	expect(acts[#acts] == false, "떼면 놓는다")
	eq(Touch.frameOf("jump"), byNo[noOf[13]], "튜토리얼이 가리키는 점프 단추 = 칸 13의 단추")
	-- 「단추 배치」: 점프를 칸 2(가장 큰 단추) 위로 끌어 놓는다
	Touch.arrange(true)
	local drag = { UserInputType = Enum.UserInputType.Touch, Position = { X = byNo[noOf[13]].AbsolutePosition.X + 10, Y = byNo[noOf[13]].AbsolutePosition.Y + 10 } }
	hitOf[noOf[13]].InputBegan:Fire(drag)
	expect(pressed.jump ~= true, "배치 중에 누르면 뛰지 않는다")
	local c2 = byNo[noOf[2]].AbsolutePosition + byNo[noOf[2]].AbsoluteSize / 2
	drag.Position = { X = c2.X, Y = c2.Y }
	changed:Fire(drag)
	ended:Fire(drag)
	local after = applied[#applied]
	expect(after and after[2] == "act_jump" and after[13] == start[2], "점프를 칸 2 위에 놓으면 사냥기와 자리를 바꾼다")
	eq(Touch.frameOf("jump"), byNo[noOf[2]], "점프 단추는 이제 칸 2의 자리")
	local jt2 = actText(noOf[2])
	expect(jt2 and jt2.shown and jt2.text == "점프", "칸 2의 단추에 「점프」가 적힌다")
	-- 목록에서 골라도 바꾼다: 칸 7을 고르고 「상호작용」
	local n0 = #applied
	Touch.arrange(true, 7)
	-- 목록의 칸: 그 칸의 글이 「상호작용」인 것 — 지금 그려진 목록의 것 하나만 누른다(누르면 목록이 다시 그려져 칸이 새로 생긴다)
	local pick = nil
	for _, h in table.clone(hits) do
		for _, tx in texts do
			if tx.parent == h.frame and tx.text == "상호작용" then
				pick = h
			end
		end
	end
	expect(pick ~= nil, "목록에 「상호작용」이 있다")
	if pick then
		pick.Activated:Fire()
	end
	local after2 = applied[#applied]
	expect(#applied > n0 and after2[7] == "act_interact" and not after2[14], "목록에서 「상호작용」을 고르면 고른 단추(칸 7)로 옮겨진다")
	-- 「비우기」: 점프 · 상호작용이 놓인 단추는 안 된다
	n0 = #applied
	Touch.arrange(true, 7)
	local clearBtn = nil
	for _, b in table.clone(buttons) do
		if b.text == "비우기" then
			clearBtn = b -- (지금 그려진 판의 것 = 마지막)
		end
	end
	if clearBtn then
		clearBtn.fn()
	end
	eq(#applied, n0, "상호작용이 놓인 단추는 「비우기」가 안 된다")
	Touch.arrange(false)
end
