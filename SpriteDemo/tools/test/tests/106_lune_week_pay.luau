-- 「달의 계승자」 — 주간 보스의 격파 보상(2026-10-27) · 보상의 방(2026-10-28).
--  사용자 10-27: "자 이제 보스 보상 설계하면되지? 달가루랑 뭐줄까?" · "눈장식 확률 엄청 낮게해줘 노말에서는 안뜨고, 하드에서만 70제로 뜨는거야 이름을 멋있게 붙여야지"
--  사용자 10-28: "보스를 처치하면 자동으로 모두 보스 보상방으로 이동하고 보스 보상방에는 보상상자가 멋지게 잇고 상자를 열면 보상이 파티보상으로 흩부려지는 방식으로
--   그 파티에 최대 드롭률을 가지고잇는 유저의 드롭률로 적용되고, 그냥 파티보상으로 전부 지급되는거야 흩부려지는거야"
--  보는 것: ① 보스 창의 「격파 보상」 세 줄 · 창을 끝까지 짓는다 ② 격파 = 칭호 · 이번 주의 격파만(달가루 · 달돈은 아직) → box.after초 뒤 모두 보상의 방
--   ③ 상자: 곁에서만 열린다 · 한 번 · 달가루 · 달돈이 덩이로 흩어진다(합 = 사람마다의 보상 · 상자에서 튀어나온다) · 사라지지 않는다 · 하드는 이름 붙은 장비
--   ④ 파티: 덩이는 누가 주워도 모두에게 · 장비는 하나(누구나 줍는다) · 파티 밖은 못 줍는다 · 쓰러진 사람도 일어나서 온다
--   ⑤ 머무는 시간이 다 되면 줍지 않은 것을 나누고 보스의 문 앞으로 · 문으로 나가면 보스의 문 앞 ⑥ 칭호는 처음에만 ⑦ 관리 「희귀 장신구」 · 「보상의 방」 ⑧ 드롭률 배율
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Titles = req("ReplicatedStorage/shared/lune/sim/titles")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local B = Weekly.boss("shadowarcher")
local W = Weekly.DATA.words
local BOX = Weekly.BOX

-- ① 세 줄
do
	local n = Weekly.payLines(B, "normal")
	eq(n[1], "달가루 2,200 · 달돈 100,000", "노말 첫 줄")
	-- 칭호 없음(2026-10-28 사용자 "내가 이번보스 칭호 안준다고했잖아"): 칭호 줄을 빼고 장신구 줄이 둘째로
	local _, nAt = Weekly.payLines(B, "normal")
	eq(n[2], W.payHardOnly, "노말 둘째 줄: 장신구는 하드에서만(칭호 줄 없음)")
	eq(n[3], "", "노말 셋째 줄은 비었다")
	eq(nAt, 2, "민트로 칠하는 줄 = 둘째")
	expect(B.pay.normal.title == nil and B.pay.hard.title == nil, "그림자 사수는 칭호를 주지 않는다")
	local h = Weekly.payLines(B, "hard")
	eq(h[1], "달가루 6,400 · 달돈 300,000", "하드 첫 줄")
	eq(h[2], "아주 드물게 「흑수정 마안」 · 눈장식", "하드 둘째 줄: 장신구")
	eq(h[3], "", "하드 셋째 줄은 비었다")
	expect(B.normal.pay == nil and B.pay.normal.drop == nil, "노말에서는 장신구가 나오지 않는다")
	expect(B.pay.hard.drop.pct > 0 and B.pay.hard.drop.pct <= 5, ("하드의 장신구는 아주 낮은 확률(%s%%)"):format(tostring(B.pay.hard.drop.pct)))
	local u = Items.unique(B.pay.hard.drop.u)
	expect(u ~= nil and u.slot == "eye" and u.stage == 70, "하드의 장신구 = Lv.70 눈장식")
	-- 보상의 방의 자료
	local sc = SCENES.scenes[BOX.scene]
	expect(sc ~= nil and sc.vault == true and sc.chest ~= nil, "보상의 방(달의 보물고) · 상자의 자리")
	expect(SCENES.scenes[Weekly.boxKey(7)] == sc, "wkbox#7 = 보상의 방의 장면")
	expect(Weekly.isBox(Weekly.boxKey(7)) and not Weekly.isBox(BOX.scene) and not Weekly.isBox("r2b5#wn3"), "보상의 방 이름")
	expect(BOX.dust >= 2 and BOX.money >= 2, "달가루 · 달돈을 여러 덩이로 흩뿌린다")
end

-- 보스 창을 짓는다(ui/weeklyWindow.luau — 2026-10-27 세 줄을 넣었다)
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
		return strict(b, "단추(Ui.button)")
	end,
	measure = function(t) return #t * 4 end,
})
do
	local WeeklyWindow = req("Client/lune/ui/weeklyWindow")
	local ctx = { me = function() return { level = 72 } end, week = function() return nil end, weekDo = function() end, partyHere = function() return false end }
	local w, h = WeeklyWindow.size()
	local ok, view = pcall(WeeklyWindow.build, frame("Body"), ctx, w, h, B.id)
	expect(ok, "보스 창을 끝까지 짓는다 — " .. tostring(view))
	local function shows(s: string): boolean
		for _, t in texts do
			if t.text == s then
				return true
			end
		end
		return false
	end
	if ok then
		WeeklyWindow.mode = "hard"
		view.refresh()
		expect(shows("아주 드물게 「흑수정 마안」 · 눈장식"), "하드를 고르면 셋째 줄에 흑수정 마안")
		WeeklyWindow.mode = "normal"
		view.refresh()
		expect(shows("달가루 2,200 · 달돈 100,000") and shows(W.payHardOnly), "노말을 고르면 노말의 것")
	end
	expect(h > 0, "창의 높이")
end

-- ---------- 서버 ----------
local fired = {}
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
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
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
World.start()
local TICK = 1 / 20
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local uid = 10600
local function join(level: number)
	uid += 1
	local name = "보상" .. (uid % 100000)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "riven")
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, level, Hero.jobAt(level))
	s.hero.quests[B.quest] = { done = true, c = {} }
	World.jump(p, B.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = B.door.x
	return p, s
end
local function lastOf(p, name: string)
	local found = nil
	for _, f in fired do
		if f.player == p and f.name == name then
			found = f.args
		end
	end
	return found
end
-- 들어가서 보스를 쓰러뜨린 것으로(방의 셈 그대로 — Weekly.cleared). 돌려주는 것: 보스의 방
local function clear(p, s, mode: string, party: boolean?)
	local r = handlers.Week(p, "enter", B.id, mode, party == true)
	expect(r and r.ok, mode .. "에 들어갔다")
	run(1)
	local room = World.room(s.scene)
	Weekly.cleared(room)
	run(0.2)
	return room
end
-- 상자 곁으로 가서 연다
local function open(p, s)
	local c = SCENES.scenes[s.scene].chest
	s.hero.x, s.hero.y = c.x, c.y
	return handlers.Week(p, "open")
end
local function eyes(h)
	local n = 0
	for _, it in h.gear do
		if it and it.u == "archer_eye" then
			n += 1
		end
	end
	return n
end
-- 떨어진 것을 모두 줍는다(그 자리로 가서 줍기)
local function pickAll(p, s, room)
	local ids = {}
	for id in room.drops do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local d = room.drops[id]
		if d then
			s.hero.x, s.hero.y = d.x, d.y
			handlers.Pickup(p, id)
		end
	end
end

-- ② · ③ 노말 혼자: 격파 = 칭호만 → 보상의 방 → 상자 → 흩어진 덩이를 줍는다
do
	local p, s = join(52)
	local h = s.hero
	local dust0, money0 = h.dust, h.money
	local broom = clear(p, s, "normal")
	eq(h.dust, dust0, "격파한 순간에는 달가루가 들어오지 않는다(상자에서)")
	eq(h.money, money0, "달돈도")
	eq(next(h.titles or {}), nil, "칭호를 받지 않는다(2026-10-28)")
	eq(lastOf(p, "TitleGot"), nil, "칭호 획득 알림도 없다")
	local pay = lastOf(p, "WeekPay")
	expect(pay ~= nil and pay[1].first == true and pay[1].dust == nil, "격파 알림(보상은 상자에서)")
	expect(h.rift.week and h.rift.week[B.id] and h.rift.week[B.id].m == "normal", "이번 주의 격파를 적었다(격파한 순간에)")
	local wv = lastOf(p, "WeekView")
	expect(wv ~= nil and wv[1].state == "clear" and wv[1].box ~= nil and wv[1].box > 0, "「n초 뒤 보상의 방으로」의 남은 초")
	expect(not Weekly.isBox(s.scene), "아직 보스의 방")
	run(BOX.after + 0.2)
	expect(Weekly.isBox(s.scene), ("%s초 뒤 보상의 방으로(%s)"):format(BOX.after, s.scene))
	local room = World.room(s.scene)
	expect(room.box ~= nil and room.box.who[h.id] == true and not room.box.opened, "상자가 닫혀 있고 나는 받을 사람")
	expect(World.room(broom.key) == nil or #broom.drops == 0, "보스의 방에는 아무것도 떨어지지 않았다")
	local bv = lastOf(p, "BoxView")
	expect(bv ~= nil and bv[1].opened == false and bv[1].x == SCENES.scenes[BOX.scene].chest.x, "화면에 상자(닫힘 · 자리)")
	-- 멀리서는 안 열린다
	s.hero.x = SCENES.scenes[s.scene].spawn.x
	local far = handlers.Week(p, "open")
	expect(far and not far.ok and far.why == W.boxHint, "멀리서는 「상자 앞에서 ↑」")
	local r = open(p, s)
	expect(r and r.ok, "상자 곁에서 연다")
	expect(room.box.opened, "열렸다")
	local again = open(p, s)
	expect(again and not again.ok and again.why == "이미 열었다", "한 번만 열린다")
	local nd, nm, dsum, msum, gear, fromOk = 0, 0, 0, 0, 0, true
	for _, d in room.drops do
		if d.kind == "dust" then
			nd += 1
			dsum += d.amount
		elseif d.kind == "money" then
			nm += 1
			msum += d.amount
		elseif d.kind == "gear" then
			gear += 1
		end
		fromOk = fromOk and d.fromX == SCENES.scenes[BOX.scene].chest.x and d.delay ~= nil and d.keep == true and d.party == room.box.who
	end
	eq(nd, BOX.dust, "달가루 덩이 수")
	eq(nm, BOX.money, "달돈 덩이 수")
	eq(dsum, 2200, "달가루 덩이의 합 = 사람마다의 보상(2,200)")
	eq(msum, 100000, "달돈 덩이의 합 = 100,000")
	eq(gear, 0, "노말에서는 장신구가 나오지 않는다")
	expect(fromOk, "모두 상자에서 튀어나온다(from · delay) · 사라지지 않는다 · 받을 사람의 것")
	local adds = 0
	for _, f in fired do
		if f.player == p and f.name == "DropAdd" and f.args[1].fromX then
			adds += 1
		end
	end
	eq(adds, BOX.dust + BOX.money, "화면에 흩어지는 것을 알렸다")
	-- 떨어진 지 오래되어도 사라지지 않는다
	room.time += 600
	run(0.2)
	local left = 0
	for _ in room.drops do
		left += 1
	end
	eq(left, BOX.dust + BOX.money, "10분이 지나도 사라지지 않는다")
	-- 혼자 격파: 펫도 줍는다(2026-10-28 사용자 "혼자 솔로로 격파할경우에만 펫이먹을수잇어")
	local one = next(room.drops)
	local pd = room.drops[one]
	expect(not pd.nopet, "혼자 격파한 상자의 것은 펫도 줍는다")
	s.hero.x, s.hero.y = pd.x, pd.y
	local pgot = room:pickup(s.hero, one, 40)
	expect(pgot ~= nil, "펫의 줍기(reach)가 된다")
	pickAll(p, s, room)
	eq(h.dust - dust0, 2200, "주우면 달가루 +2,200")
	eq(h.money - money0, 100000, "주우면 달돈 +100,000")
	-- 머무는 시간이 다 되면 보스의 문 앞으로
	run(BOX.stay)
	eq(SCENES.base(s.scene), B.door.scene, "머무는 시간이 다 되면 보스의 문 앞(그림자 능선)으로")
	expect(math.abs(s.hero.x - (B.door.x - 30)) <= 16, "문 곁에")
	World.removePlayer(p)
end

-- ③ 하드 혼자: 이름 붙은 장비(이 시험에서는 반드시 나오게 — 확률만 바꾼다)
local pct0 = B.pay.hard.drop.pct
B.pay.hard.drop.pct = 100
do
	local p, s = join(72)
	local h = s.hero
	local dust0, money0 = h.dust, h.money
	clear(p, s, "hard")
	eq(next(h.titles or {}), nil, "하드도 칭호를 받지 않는다")
	run(BOX.after + 0.2)
	local room = World.room(s.scene)
	local ro = open(p, s)
	expect(ro and ro.ok, "하드: 상자를 연다")
	local eyeDrop = nil
	for _, d in room.drops do
		if d.kind == "gear" and d.item.u == "archer_eye" then
			eyeDrop = d
		end
	end
	expect(eyeDrop ~= nil, "하드: 흑수정 마안이 상자에서 흩어진다")
	pickAll(p, s, room)
	eq(h.dust - dust0, 6400, "하드: 달가루 +6,400")
	eq(h.money - money0, 300000, "하드: 달돈 +300,000")
	local eye = nil
	for _, it in h.gear do
		if it and it.u == "archer_eye" then
			eye = it
		end
	end
	expect(eye ~= nil, "주우면 흑수정 마안이 가방에")
	if eye then
		eq(Items.name(eye), "흑수정 마안", "이름")
		eq(eye.slot, "eye", "눈장식")
		eq(eye.stage, 70, "Lv.70")
		eq(eye.q, #Items.data.QUALITY, "성능 빼어난")
		expect(Items.valid(eye), "꼴이 맞다")
		local saved = Bag.pack(h)
		local h2 = Hero.new(1, "riven")
		Bag.unpack(h2, saved)
		eq(eyes(h2), 1, "저장했다 읽어도 이름표가 남는다")
		local before = Hero.power(h)
		expect(Bag.equip(h, eye.id), "낀다(Lv.72)")
		Hero.recalc(h)
		expect(Hero.power(h) > before, ("끼면 전투력이 오른다(%d → %d)"):format(before, Hero.power(h)))
	end
	local bad = table.clone(Items.makeUnique("archer_eye"))
	bad.stage = 10
	expect(not Items.valid(bad), "이름표와 단계가 다르면 꼴이 틀렸다")
	bad = Items.make("eye", 70, 5)
	bad.u = "nothing"
	expect(not Items.valid(bad), "모르는 이름표는 꼴이 틀렸다")
	World.removePlayer(p)
end

-- ④ 파티: 덩이는 누가 주워도 모두에게 · 장비는 하나(누구나 줍는다) · 파티 밖은 못 줍는다 · 쓰러진 사람도 일어나서 온다
do
	local pa, a = join(72)
	local pb, b = join(72)
	handlers.Party(pa, "invite", pb.UserId)
	handlers.Party(pb, "accept")
	a.trust, a.stale = true, nil
	a.hero.x = B.door.x
	local da, ma, db, mb = a.hero.dust, a.hero.money, b.hero.dust, b.hero.money
	clear(pa, a, "hard", true)
	expect(b.scene == a.scene, "둘이 파티로 들어가 격파했다")
	b.hero.alive, b.hero.hp = false, 0 -- (격파 직후 쓰러져 있었다)
	run(BOX.after + 0.2)
	expect(Weekly.isBox(a.scene) and b.scene == a.scene, "둘 다 같은 보상의 방으로")
	expect(b.hero.alive and b.hero.hp == b.hero.maxHp, "쓰러져 있던 사람도 일어나서 온다")
	local room = World.room(a.scene)
	expect(room.box.who[a.hero.id] and room.box.who[b.hero.id], "둘 다 받을 사람")
	open(pb, b)
	local gear = 0
	for _, d in room.drops do
		if d.kind == "gear" then
			gear += 1
		end
	end
	eq(gear, 1, "흑수정 마안은 파티에 하나(한 번 굴린다)")
	-- 파티 밖의 사람은 줍지 못한다(시간이 지나도)
	local any = next(room.drops)
	local stranger = { id = 99999, alive = true, x = room.drops[any].x, y = room.drops[any].y, gear = {}, equip = {}, dust = 0, money = 0 }
	room.time += 600
	local got, why = room:pickup(stranger, any)
	expect(got == nil and why == "남의 것", "파티 밖의 사람은 시간이 지나도 줍지 못한다")
	-- 파티로 격파: 펫은 줍지 못한다 — 직접 주워야 한다(사용자 "펫이먹지못하고, 다 직접 주워야해")
	local any2 = next(room.drops)
	local d2 = room.drops[any2]
	expect(d2.nopet == true, "파티로 격파한 상자의 것에는 nopet")
	a.hero.x, a.hero.y = d2.x, d2.y
	local pg, pwhy = room:pickup(a.hero, any2, 40)
	expect(pg == nil and pwhy == "펫은 줍지 못한다", "펫은 줍지 못한다")
	local dv = nil
	for _, f in fired do
		if f.name == "DropAdd" and f.args[1].id == any2 then
			dv = f.args[1]
		end
	end
	expect(dv ~= nil and dv.nopet == true, "화면에도 nopet(펫이 달려가지 않는다)")
	-- A가 모두 줍는다 → 달가루 · 달돈은 둘 다에게 · 장비는 A에게
	fired = {}
	pickAll(pa, a, room)
	eq(a.hero.dust - da, 6400, "주운 사람: 달가루 +6,400")
	eq(b.hero.dust - db, 6400, "줍지 않은 파티원도 달가루 +6,400(누가 주워도 모두에게)")
	eq(a.hero.money - ma, 300000, "주운 사람: 달돈 +300,000")
	eq(b.hero.money - mb, 300000, "줍지 않은 파티원도 달돈 +300,000")
	eq(eyes(a.hero) + eyes(b.hero), 1, "장비는 하나 — 주운 사람의 가방에")
	eq(eyes(a.hero), 1, "주운 A에게")
	local shared = nil
	for _, f in fired do
		if f.name == "DropGone" and typeof(f.args[4]) == "table" then
			shared = f.args[4]
		end
	end
	expect(shared ~= nil and table.find(shared, a.hero.id) ~= nil and table.find(shared, b.hero.id) ~= nil, "화면에 함께 받은 사람들(둘 다)을 알린다")
	-- ⑤-2 문으로 나가면 보스의 문 앞 · 다들 나가면 방이 닫힌다
	local key = a.scene
	local gate = SCENES.scenes[key].portals[1]
	for _, ss in { { pa, a }, { pb, b } } do
		ss[2].hero.x, ss[2].hero.y = gate.x, gate.y
		local t = handlers.Travel(ss[1], gate.to)
		expect(t ~= nil and SCENES.base(ss[2].scene) == B.door.scene, "보상의 방의 문 = 보스의 문 앞으로")
	end
	run(0.2)
	expect(not World.hasRoom(key), "다들 나가면 보상의 방이 닫힌다")
	World.removePlayer(pa)
	World.removePlayer(pb)
end

-- ⑤ 머무는 시간이 다 됐다(상자를 아무도 열지 않았다): 줍지 않은 달가루 · 달돈은 모두에게 · 장비는 그 가운데 하나의 가방에 → 보스의 문 앞으로
do
	local pa, a = join(72)
	local pb, b = join(72)
	handlers.Party(pa, "invite", pb.UserId)
	handlers.Party(pb, "accept")
	a.trust, a.stale = true, nil
	a.hero.x = B.door.x
	local da, ma, db, mb = a.hero.dust, a.hero.money, b.hero.dust, b.hero.money
	clear(pa, a, "hard", true)
	run(BOX.after + 0.2)
	local room = World.room(a.scene)
	fired = {}
	run(BOX.stay + 0.2)
	eq(SCENES.base(a.scene), B.door.scene, "다 되면 보스의 문 앞으로(A)")
	eq(SCENES.base(b.scene), B.door.scene, "B도")
	eq(a.hero.dust - da, 6400, "열지 않았어도 남은 달가루가 모두에게(A)")
	eq(b.hero.dust - db, 6400, "B도 달가루")
	eq(a.hero.money - ma, 300000, "A 달돈")
	eq(b.hero.money - mb, 300000, "B 달돈")
	eq(eyes(a.hero) + eyes(b.hero), 1, "줍지 않은 장비는 받을 사람 가운데 하나의 가방에")
	local leftA = lastOf(pa, "WeekPay")
	expect(leftA ~= nil and leftA[1].left == true and leftA[1].dust == 6400, "화면에 「남은 보상」")
	local n = 0
	for _ in room.drops do
		n += 1
	end
	eq(n, 0, "방의 떨어진 것은 비었다")
	World.removePlayer(pa)
	World.removePlayer(pb)
end
B.pay.hard.drop.pct = pct0

-- ⑦ 관리 「희귀 장신구」 · 「보상의 방」(관리자 = 게임의 주인 — 서버가 계정 번호로 가린다)
do
	uid = 10311679477 - 1 -- 다음 join이 게임의 주인(관리자)
	local p, s = join(72)
	local h = s.hero
	local r = handlers.Admin(p, "rare", 100)
	expect(r and r.ok and s.rareTest == 100, "관리자: 희귀 장신구 확률 100%")
	local bad = handlers.Admin(p, "rare", 150)
	expect(bad and bad.ok == false, "0 ~ 100%만")
	clear(p, s, "hard")
	run(BOX.after + 0.2)
	local room = World.room(s.scene)
	open(p, s)
	pickAll(p, s, room)
	eq(eyes(h), 1, "100%를 걸면 하드 격파의 상자에서 흑수정 마안이 나온다")
	r = handlers.Admin(p, "unique", "archer_eye")
	expect(r and r.ok, "흑수정 마안 받기")
	eq(eyes(h), 2, "가방에 하나 더")
	-- 「보상의 방」: 보스를 잡지 않고 상자를 열어 본다(나 혼자 · 이번 주의 격파는 그대로)
	local week0 = h.rift.week and h.rift.week[B.id] and table.clone(h.rift.week[B.id])
	r = handlers.Admin(p, "box", "hard")
	expect(r and r.ok and Weekly.isBox(s.scene), "관리 「보상의 방 · 하드」로 바로")
	local room2 = World.room(s.scene)
	expect(room2.box.who[h.id] and room2.box.mode == "hard", "나 혼자 받을 사람 · 하드")
	expect(open(p, s).ok, "상자를 연다")
	local ok2 = (h.rift.week and h.rift.week[B.id] and h.rift.week[B.id].w) == (week0 and week0.w)
	expect(ok2, "이번 주의 격파는 바뀌지 않는다")
	r = handlers.Admin(p, "rare", 0)
	expect(r and r.ok and s.rareTest == nil, "0 = 설계의 값으로 되돌린다")
	World.removePlayer(p)
	uid = 10700
	local p2, s2 = join(72)
	eq(handlers.Admin(p2, "rare", 100), nil, "관리자가 아니면 명령이 듣지 않는다")
	eq(handlers.Admin(p2, "box", "hard"), nil, "관리자가 아니면 「보상의 방」도")
	eq(s2.rareTest, nil, "확률이 걸리지 않았다")
	World.removePlayer(p2)
	local high = { NextNumber = function() return 99.9 end }
	eq(Weekly.roll(B, "hard", high), nil, "설계의 값(1.5%)에서 99.9가 나오면 안 나온다")
	local got = Weekly.roll(B, "hard", high, 100)
	eq(got and got.u, "archer_eye", "100%면 나온다")
	eq(Weekly.roll(B, "normal", high, 100), nil, "노말은 시험 확률을 걸어도 나오지 않는다(장신구가 없다)")
end

-- ⑧ 드롭률 배율(2026-10-27 사용자: "아니 마안 드롭률이 올라야해 파티에서 가장높은사람의 드롭률 배율로 적용되서 밸런스가 문제라면 기본 마안드롭률을 낮추면된다")
--   확률 = 기본 1.5% x 파티에서 가장 높은 사람의 드롭률 배율(쿠폰 1.5배 · 패스 1.25배 · 둘 다 1.75배) — 상자를 열 때 굴린다
do
	eq(B.pay.hard.drop.pct, 1.5, "기본 1.5%")
	local at2 = { NextNumber = function() return 2.0 end }
	eq(Weekly.roll(B, "hard", at2), nil, "굴린 값 2.0: 기본 1.5%면 안 나온다")
	eq(Weekly.roll(B, "hard", at2, nil, 1.25), nil, "패스(1.25배 = 1.875%)여도 안 나온다")
	local g1 = Weekly.roll(B, "hard", at2, nil, 1.5)
	eq(g1 and g1.u, "archer_eye", "쿠폰(1.5배 = 2.25%)이면 나온다")
	local g2 = Weekly.roll(B, "hard", at2, nil, 1.75)
	eq(g2 and g2.u, "archer_eye", "쿠폰 + 패스(1.75배 = 2.625%)면 나온다")
	local pct1 = B.pay.hard.drop.pct
	B.pay.hard.drop.pct = 60
	uid = 10800
	local pa, a = join(72)
	local pb, b = join(72)
	handlers.Party(pa, "invite", pb.UserId)
	handlers.Party(pb, "accept")
	b.hero.dropLeft = 600
	b.hero.passDrop = 0.25
	a.trust, a.stale = true, nil
	a.hero.x = B.door.x
	clear(pa, a, "hard", true)
	run(BOX.after + 0.2)
	local room = World.room(a.scene)
	eq(room.box.mul, 1.75, "받을 사람 가운데 가장 높은 배율(쿠폰 + 패스 = 1.75)")
	open(pa, a)
	local n = 0
	for _, d in room.drops do
		if d.kind == "gear" then
			n += 1
		end
	end
	eq(n, 1, "한 사람만 쿠폰 + 패스여도 상자의 확률에 그 배율이 붙는다(60% x 1.75 = 105% → 반드시 하나)")
	B.pay.hard.drop.pct = pct1
	World.removePlayer(pa)
	World.removePlayer(pb)
end

-- ⑨ 소비 아이템(2026-10-28 타락한 부단장 — 사용자 보상 설계 「소비 아이템」 · design/weekboss.js의 pay.goods): 큰 달빛 물약 · 귀환 주문서가 덩이로 흩어지고,
--   누가 주워도 받을 사람 모두에게(달가루 · 달돈처럼) · 가방이 가득 찬 사람은 들어가는 만큼만 + 알림 · 줍지 않고 방이 닫히면 모두에게
do
	local VB = Weekly.boss("fallenknight")
	local G = VB.pay.hard.goods
	local lines, at = Weekly.payLines(VB, "hard")
	eq(lines[2], "큰 달빛 물약 60개 · 귀환 주문서 3개", "보스 창의 둘째 줄 = 소비 아이템(칭호가 없는 보스)")
	eq(at, 3, "장신구 줄은 셋째(민트)")
	eq(Weekly.payLines(VB, "normal")[2], "큰 달빛 물약 30개 · 귀환 주문서 2개", "노말의 소비 아이템")
	expect(not table.concat(Weekly.payLines(B, "hard"), "|"):find("물약"), "그림자 사수는 소비 아이템이 없다(그대로 — 둘째 줄은 장신구)")
	local function joinV(level: number)
		uid += 1
		local name = "부단" .. (uid % 100000)
		local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
		handlers.Ready(p)
		local made = handlers.Chars(p, "create", name, "riven")
		handlers.Chars(p, "enter", made.id)
		World.wake(p)
		local s = World.session(p)
		Hero.setLevel(s.hero, level, Hero.jobAt(level))
		s.hero.quests[VB.quest] = { done = true, c = {} }
		World.jump(p, VB.door.scene)
		s.trust, s.stale = true, nil
		s.hero.x = VB.door.x
		return p, s
	end
	local function pairUp()
		local pa, a = joinV(80)
		local pb, b = joinV(80)
		handlers.Party(pa, "invite", pb.UserId)
		handlers.Party(pb, "accept")
		a.trust, a.stale = true, nil
		a.hero.x = VB.door.x
		local r = handlers.Week(pa, "enter", VB.id, "hard", true)
		expect(r and r.ok, "타락한 부단장 하드에 파티로 들어갔다")
		run(1)
		Weekly.cleared(World.room(a.scene))
		run(BOX.after + 0.4)
		expect(Weekly.isBox(a.scene) and b.scene == a.scene, "둘 다 보상의 방으로")
		return pa, a, pb, b, World.room(a.scene)
	end
	-- 줍기: B의 가방(소비 탭)을 가득 채워 둔다 — A가 모두 주우면 A는 다 받고, B는 하나도 못 받고 알림
	local pa, a, pb, b, room = pairUp()
	local full = { item = "potion1", n = 200 }
	for i = 1, Bag.size(b.hero) do
		b.hero.use[i] = table.clone(full)
	end
	eq(Bag.room(b.hero, "potion3"), 0, "(B의 소비 탭이 가득 찼다)")
	open(pa, a)
	local piles = {}
	for _, d in room.drops do
		if d.kind == "goods" then
			piles[d.goods] = (piles[d.goods] or 0) + 1
			expect(d.share == true and d.party ~= nil and d.nopet == true, "소비 아이템 덩이도 나눈다 · 파티의 것 · 펫은 못 줍는다")
		end
	end
	eq(piles.potion3, G[1].n / G[1].pile, ("큰 달빛 물약 덩이 %d개(%d병씩)"):format(G[1].n / G[1].pile, G[1].pile))
	eq(piles.scroll_return, G[2].n, "귀환 주문서 덩이 셋(한 장씩)")
	local pa0, ps0 = Bag.count(a.hero, "potion3"), Bag.count(a.hero, "scroll_return")
	fired = {}
	pickAll(pa, a, room)
	eq(Bag.count(a.hero, "potion3") - pa0, 60, "주운 A: 큰 달빛 물약 +60")
	eq(Bag.count(a.hero, "scroll_return") - ps0, 3, "주운 A: 귀환 주문서 +3")
	eq(Bag.count(b.hero, "potion3"), 0, "가방이 가득 찬 B는 받지 못했다")
	local shorts = 0
	for _, f in fired do
		if f.player == pb and f.name == "WeekPay" and typeof(f.args[1]) == "table" and f.args[1].short then
			shorts += 1
		end
	end
	eq(shorts, piles.potion3 + piles.scroll_return, "B에게 덩이마다 「가방이 가득 차 받지 못했다」")
	World.removePlayer(pa)
	World.removePlayer(pb)
	-- 아무도 줍지 않고 방이 닫힌다: 둘 다에게 소비 아이템이 들어간다(가방에 들어가는 만큼)
	pa, a, pb, b, room = pairUp()
	open(pa, a)
	local a0, b0 = Bag.count(a.hero, "potion3"), Bag.count(b.hero, "potion3")
	fired = {}
	run(BOX.stay + 1)
	eq(Bag.count(a.hero, "potion3") - a0, 60, "닫힐 때 A에게 큰 달빛 물약 60")
	eq(Bag.count(b.hero, "potion3") - b0, 60, "닫힐 때 B에게도 60")
	local left = lastOf(pa, "WeekPay")
	expect(left ~= nil and left[1].left == true and typeof(left[1].goods) == "table" and #left[1].goods == 2, "「남은 보상」 알림에 소비 아이템 둘")
	World.removePlayer(pa)
	World.removePlayer(pb)
end

-- ⑩ 불씨 도둑 두목의 보상(2026-10-29 사용자: "불씨두목 보상설계하자" → 초안 "오케이 좋아 이대로가자"): 앞의 두 보스와 같은 셈 —
--   노말 달가루 8,300 · 달돈 220,000 · 큰 달빛 물약 30 · 귀환 주문서 2 / 하드 17,500 · 660,000 · 60 · 3 + 「잿불 도적의 허리띠」(Lv.90 허리띠 · 빼어난 · 공격력 2) 1.5%
do
	local TB = Weekly.boss("thiefboss")
	expect(TB ~= nil and TB.pay ~= nil, "불씨 도둑 두목에 보상이 있다")
	local N_, H_ = TB.pay.normal, TB.pay.hard
	eq(N_.dust, 8300, "노말 달가루")
	eq(N_.money, 220000, "노말 달돈")
	eq(H_.dust, 17500, "하드 달가루")
	eq(H_.money, 660000, "하드 달돈 = 노말의 3배")
	eq(Weekly.payLines(TB, "normal")[2], "큰 달빛 물약 30개 · 귀환 주문서 2개", "노말의 소비 아이템")
	local hl, hat = Weekly.payLines(TB, "hard")
	eq(hl[2], "큰 달빛 물약 60개 · 귀환 주문서 3개", "하드의 소비 아이템")
	expect(hat == 3 and hl[3] ~= nil and hl[3]:find("잿불 도적의 허리띠", 1, true) ~= nil, "하드의 셋째 줄 = 장신구 — " .. tostring(hl[3]))
	eq(N_.drop, nil, "노말에는 장신구가 없다")
	eq(H_.drop.u, "thief_belt", "하드의 장신구")
	eq(H_.drop.pct, 1.5, "1.5%")
	local Items_ = req("ReplicatedStorage/shared/lune/sim/items")
	local u = Items_.unique("thief_belt")
	expect(u ~= nil and u.slot == "belt" and u.stage == 90 and u.q == Items_.unique("vice_pauldron").q and u.atk == 2 and u.boss == "thiefboss", "잿불 도적의 허리띠 = Lv.90 허리띠 · 빼어난(앞 보스의 장신구와 같은 성능) · 공격력 2")
	local it = Items_.makeUnique("thief_belt")
	expect(it ~= nil and Items_.name(it) == "잿불 도적의 허리띠", "장비로 만들어진다 — " .. tostring(it and Items_.name(it)))
	-- 보상의 방: 혼자 하드를 깨고 상자를 열면(줍지 않고 방이 닫힐 때) 달가루 · 달돈 · 소비 아이템이 들어온다
	uid += 1
	local name = "도둑" .. (uid % 100000)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "riven")
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, 98, Hero.jobAt(98))
	s.hero.quests[TB.quest] = { done = true, c = {} }
	World.jump(p, TB.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = TB.door.x
	local r = handlers.Week(p, "enter", TB.id, "hard", false)
	expect(r and r.ok, "불씨 도둑 두목 하드에 들어갔다 — " .. tostring(r and (r.why or r.msg)))
	run(1)
	Weekly.cleared(World.room(s.scene))
	run(BOX.after + 0.4)
	expect(Weekly.isBox(s.scene), "보상의 방으로")
	local d0, m0, p0, r0 = s.hero.dust, s.hero.money, Bag.count(s.hero, "potion3"), Bag.count(s.hero, "scroll_return")
	open(p, s)
	run(BOX.stay + 1)
	eq(s.hero.dust - d0, 17500, "하드: 달가루 +17,500")
	eq(s.hero.money - m0, 660000, "하드: 달돈 +660,000")
	eq(Bag.count(s.hero, "potion3") - p0, 60, "하드: 큰 달빛 물약 +60")
	eq(Bag.count(s.hero, "scroll_return") - r0, 3, "하드: 귀환 주문서 +3")
	World.removePlayer(p)
end
