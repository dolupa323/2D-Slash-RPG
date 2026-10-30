-- 「달의 계승자」 — 여러 개 분해 · 더 똑똑한 펫 · 로벅스 펫의 빨아들이기(2026-10-22).
--  사용자: "장비 분해를 한번에 여러개 할수있게 해달라, 펫이 너무 멍청해서 조금이라도 높은턱이 있으면 멍청하게 못줍는다 펫 지능 상향해라
--   로벅스 펫은 자석범위로 빨아들이는 형태로 한다 원래이미 펫을 가지고 있는사람들도 패치 적용되면 똑같이 적용 되어야한다 누락되면안된다"
--  보는 것: ① Bag.dismantleMany(달가루 = 하나씩 분해한 것의 합 · 겹친 것 · 없는 것은 건너뜀 · 하나도 없으면 안 됨 · 너무 많으면 안 됨) ② 서버(Item "dismantleMany" · 업적의 수)
--   ③ 쿠폰 펫도: 두 칸 턱 위 · 떠 있는 발판 위의 것을 주우러 올라간다 ④ 로벅스 펫: 오르지 못하는 높은 곳도 둘레 원 안이면 빨아들인다 · 쿠폰 펫은 아니다
--   ⑤ 로벅스 펫은 펫의 종류로 정해진다(이미 가진 사람의 계정에 따로 적는 것이 없다) ⑥ 펫이 막힌 칸 안에 들어가지 않는다
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local Physics = req("ReplicatedStorage/shared/lune/sim/physics")
local P = RIDE.pet

-- ① 여러 개 분해의 셈
do
	local h = Hero.new(7801, "riven")
	local ids, want = {}, 0
	for i = 1, 5 do
		local it = Items.make(if i == 1 then "weapon" else "hat", 1, 2, if i == 1 then "riven" else nil)
		expect(Bag.add(h, it), "장비를 가방에 넣는다 " .. i)
		table.insert(ids, it.id)
		if i <= 3 then
			want += Items.dismantle(it)
		end
	end
	local dust0 = h.dust
	local got, why, n = Bag.dismantleMany(h, { ids[1], ids[2], ids[3], ids[2], 999999 })
	eq(n, 3, "셋을 분해했다(겹친 것 · 없는 것은 건너뛴다) — " .. tostring(why))
	eq(got, want, "받은 달가루 = 하나씩 분해한 것의 합")
	eq(h.dust, dust0 + want, "달가루가 늘었다")
	local left = 0
	for _, it in h.gear do
		if it then
			left += 1
		end
	end
	eq(left, 2, "가방에 둘이 남았다")
	local g2, w2 = Bag.dismantleMany(h, { 999999 })
	expect(g2 == nil and w2 ~= nil, "가방에 없는 것만이면 안 된다")
	expect(Bag.dismantleMany(h, "x") == nil, "목록이 아니면 안 된다")
	local many = {}
	for i = 1, Bag.BULK_MAX + 1 do
		many[i] = i
	end
	expect(Bag.dismantleMany(h, many) == nil, "한 번에 " .. Bag.BULK_MAX .. "개 넘게는 안 된다")
end

-- ③ ~ ⑥ 펫
local last = {}
MOCK("Client/lune/sprite", {
	new = function(_, id)
		local s = { char = { id = id }, label = { Visible = true } }
		function s.set(_, clip, _, x, y, dir)
			last = { clip = clip, x = x, y = y, dir = dir }
		end
		function s.destroy() end
		return s
	end,
	frameAt = function()
		return 1
	end,
})
local RideView = req("Client/lune/rideView")
-- 시험 맵(칸 16점, 땅의 윗면 176): 두 칸 턱(x 320~447 · 윗면 144 — 32 위) · 떠 있는 얇은 발판(x 544~607 · 윗면 144) · 높은 기둥(x 800~831 · 윗면 112 — 64 위, 펫이 오르지 못하게 넓은 바닥 없이)
local W, H = 70, 14
local grid = {}
for ty = 0, H - 1 do
	grid[ty] = {}
	for tx = 0, W - 1 do
		grid[ty][tx] = if ty >= 11 or tx <= 1 or tx >= W - 2 then "#" else "."
	end
end
for ty = 9, 10 do
	for tx = 20, 27 do
		grid[ty][tx] = "#"
	end
end
for tx = 34, 37 do
	grid[9][tx] = "="
end
for ty = 7, 10 do
	for tx = 50, 51 do
		grid[ty][tx] = "#"
	end
end
local rows = {}
for ty = 0, H - 1 do
	local r = {}
	for tx = 0, W - 1 do
		r[tx + 1] = grid[ty][tx]
	end
	rows[ty + 1] = table.concat(r)
end
local scene = { w = W, h = H, rows = rows, spawn = { x = 100, y = 176 } }
local GROUND = 176
local now, DT = 0, 1 / 60
local inWall = false
local function run(rv, sec, x, drops, onPick)
	for _ = 1, math.floor(sec / DT + 0.5) do
		now += DT
		rv:update(now, DT, x, GROUND, 1, false, false, false, drops, onPick)
		local b = rv.body
		if b and Physics.solidBox(scene, b.x, b.y) then
			inWall = true
		end
	end
end
local function fresh(id: string, x: number)
	local rv = RideView.new({}, 1, scene)
	rv:setPet(id)
	rv:update(now, DT, x, GROUND, 1, false, false, false, nil, nil)
	return rv
end
local function picker()
	local got = {}
	return got, function(id)
		got[id] = true
	end
end

-- ⑤ 어느 펫이 빨아들이나: 펫의 종류로 정해진다
for _, q in RIDE.pets do
	eq(RideView.sucks(q.id), not q.free, q.id .. (if q.free then ": 쿠폰 펫은 달려가서 줍는다" else ": 로벅스 펫은 빨아들인다"))
end
expect(P.climb > 24 and P.hop > 0 and P.suck and P.suck.r > P.magnet, "새 수치(climb · hop · suck)")

-- ③ 쿠폰 펫(아기 재까마귀)도 두 칸 턱 위의 것을 주우러 올라간다
do
	local rv = fresh("pet_crow", 280)
	run(rv, 1, 280)
	local got, onPick = picker()
	run(rv, 5, 280, { [1] = { x = 336, y = 144 } }, onPick)
	expect(got[1], "쿠폰 펫: 두 칸(32점) 턱 위의 것을 올라가서 줍는다")
end
do
	local rv = fresh("pet_crow", 560)
	run(rv, 1, 560)
	local got, onPick = picker()
	run(rv, 5, 560, { [2] = { x = 580, y = 144 } }, onPick)
	expect(got[2], "쿠폰 펫: 떠 있는 발판 위의 것을 밑에서 뛰어올라 줍는다")
end
-- ④ 로벅스 펫: 오르지 못하는 높은 기둥 위의 것도 둘레 원 안이면 빨아들인다
do
	local rv = fresh("pet_silver", 870)
	run(rv, 1.5, 870)
	local px = rv.body.x
	local got, onPick = picker()
	local drops = { [3] = { x = 815, y = 112 } }
	local dx, dy = 815 - px, (112 - 4) - (rv.body.y - 6)
	local dist = math.sqrt(dx * dx + dy * dy)
	run(rv, 1, 870, drops, onPick)
	if dist <= P.suck.r then
		expect(got[3], ("로벅스 펫: 64점 위 기둥 꼭대기의 것도 원(%d점) 안이면 빨아들인다 — 거리 %.0f"):format(P.suck.r, dist))
	else
		expect(false, ("(시험 맵의 자리가 원 밖이다 — 거리 %.0f)"):format(dist))
	end
	-- 같은 자리에서 쿠폰 펫은 빨아들이지 않는다(올라가지도 못한다)
	local rv2 = fresh("pet_crow", 870)
	run(rv2, 1.5, 870)
	local got2, onPick2 = picker()
	run(rv2, 2, 870, { [4] = { x = 815, y = 112 } }, onPick2)
	expect(not got2[4], "쿠폰 펫은 기둥 꼭대기의 것을 빨아들이지 않는다")
	-- 로벅스 펫은 자주(suck.every초마다) — 둘레의 셋을 1초 안에
	local rv3 = fresh("pet_lantern", 300)
	run(rv3, 1, 300)
	local bx = rv3.body.x
	local got3, onPick3 = picker()
	run(rv3, 1, 300, { [5] = { x = bx + 30, y = GROUND }, [6] = { x = bx - 30, y = GROUND }, [7] = { x = bx + 50, y = GROUND } }, onPick3)
	expect(got3[5] and got3[6] and got3[7], "로벅스 펫: 둘레의 셋을 1초 안에 빨아들인다")
	-- 10-22 사용자 "로벅스 펫 빨아들이기 범위 더크게": 원 suck.r(160) — 펫에게서 140점 떨어진 것도 빨아들인다 · 쿠폰 펫은 아니다
	expect(P.suck.r >= 160 and P.suck.reach >= P.suck.r + P.behind, "범위 160 이상 · 서버가 받는 거리 = 펫이 영웅 뒤에 있어도 원 끝까지")
	local got4, onPick4 = picker()
	run(rv3, 1, 300, { [8] = { x = rv3.body.x + 140, y = GROUND } }, onPick4)
	expect(got4[8], "로벅스 펫: 140점 떨어진 것도 빨아들인다")
	local rv4 = fresh("pet_crow", 300)
	run(rv4, 1, 300)
	local got5, onPick5 = picker()
	run(rv4, 0.05, 300, { [9] = { x = rv4.body.x + 140, y = GROUND } }, onPick5)
	expect(not got5[9], "쿠폰 펫은 140점 떨어진 것을 그 자리에서 빨아들이지 않는다")
end
expect(not inWall, "⑥ 펫이 막힌 칸 안에 들어가지 않았다")

-- ② 서버: Item "dismantleMany" · 업적의 수 · 로벅스 펫의 줍기 간격
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
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local p = { UserId = 7810, Name = "분해시험", DisplayName = "분해시험", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "분해시험", "riven")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
do
	local h = s.hero
	local ids = {}
	for i = 1, 4 do
		local it = Items.make("hat", 1, 2, nil)
		Bag.add(h, it)
		table.insert(ids, it.id)
	end
	local dust0, ach0 = h.dust, (s.acct.ach.c.dismantle or 0)
	table.clear(sent)
	handlers.Item(p, "dismantleMany", ids)
	local done = nil
	for _, f in sent do
		if f.name == "ItemDone" and f.player == p then
			done = f.args[1]
		end
	end
	expect(done and done.ok and done.action == "dismantleMany" and done.result == h.dust - dust0, "서버가 한꺼번에 분해하고 받은 달가루를 알린다")
	eq((s.acct.ach.c.dismantle or 0) - ach0, 4, "업적 「장비 분해」는 분해한 수만큼 오른다")
	for _, id in ids do
		local it = Bag.find(h, id)
		expect(it == nil, "분해한 장비는 가방에 없다")
	end
end
-- 서버: 로벅스 펫이 빨아들인 먼 것(영웅에게서 200점)도 받는다 · 쿠폰 펫은 128점 넘게는 받지 않는다(10-22 「범위 더크게」)
do
	local room = World.room(s.scene)
	local function far(id, petId)
		s.acct.bm.pets[petId] = true
		s.acct.bm.petsOut, s.acct.bm.petOut = { petId }, petId -- (꺼내 둔 펫들 — 2026-10-30)
		s.petT = nil
		room.drops[id] = { id = id, kind = "money", amount = 1, x = s.hero.x + 200, y = s.hero.y, owner = s.hero.id, born = room.time }
		handlers.PetPick(p, id)
		return room.drops[id] == nil
	end
	expect(far(990001, "pet_silver"), "서버: 로벅스 펫은 영웅에게서 200점 떨어진 것도 받는다")
	expect(not far(990002, "pet_crow"), "서버: 쿠폰 펫은 200점 떨어진 것을 받지 않는다")
	-- 펫 셋(2026-10-30): 둘째 칸(slot)의 펫으로 줍는다 · 펫마다 간격을 따로 센다(첫째가 막 주웠어도 둘째는 바로 줍는다) · 그 칸의 펫의 종류로 거리를 본다
	s.acct.bm.pets.pet_silver, s.acct.bm.pets.pet_crow = true, true
	s.acct.bm.petsOut, s.acct.bm.petOut = { "pet_crow", "pet_silver" }, "pet_crow"
	s.petT = nil
	local function drop(id, dx)
		room.drops[id] = { id = id, kind = "money", amount = 1, x = s.hero.x + dx, y = s.hero.y, owner = s.hero.id, born = room.time }
	end
	drop(990003, 20)
	handlers.PetPick(p, 990003, 1)
	expect(room.drops[990003] == nil, "서버: 첫째 펫(쿠폰 펫)이 가까운 것을 줍는다")
	drop(990004, 200)
	handlers.PetPick(p, 990004, 2)
	expect(room.drops[990004] == nil, "서버: 바로 이어 둘째 펫(로벅스 펫)이 먼 것을 줍는다 — 펫마다 간격 · 그 펫의 거리")
	drop(990005, 20)
	handlers.PetPick(p, 990005, 1)
	expect(room.drops[990005] ~= nil, "서버: 첫째 펫은 아직 간격 안(곧바로 또 줍지 못한다)")
	drop(990006, 20)
	handlers.PetPick(p, 990006, 3)
	expect(room.drops[990006] ~= nil, "서버: 꺼내 두지 않은 셋째 칸은 줍지 못한다")
end
World.removePlayer(p)
