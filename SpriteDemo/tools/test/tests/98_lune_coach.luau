-- 「달의 계승자」 — 역마차(2026-10-26 사용자 "마을판정인곳이 엄청 많잖아 그럼 그 마을이랑 마을 사이를 이동할수있는 수단이 필요 … 메이플 스토리 택시처럼
--  배로 가야하는곳은 택시로 못가고 … 같은 대륙 판정인곳 안에서 택시로 왔다갔다 … 이 세계관에서는 택시라는 게 아니여야" → "npc 통해서 이동하는거야").
--  보는 것: ① 정류장은 걸어서 이어진 땅마다 묶인다(배로만 닿는 물마루 마을 쪽은 따로) ② 삯 = base + 문을 지나는 수 x step ③ 정류장마다 마부가 단단한 땅 위에 선다
--   ④ 서버: 마부 곁에서만 · 같은 땅만 · 달돈 · 몸의 상태
--   ④ 탔으면 달돈이 줄고 그 정류장의 시작 자리로 옮겨진다
local Coach = req("ReplicatedStorage/shared/lune/sim/coach")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local D = Coach.DATA
eq(D.name, "역마차", "이름은 택시가 아니라 역마차")
for _, key in D.stations do
	local sc = SCENES.scenes[key]
	expect(sc ~= nil and not sc.inst and not sc.indoor, "정류장은 언제든 갈 수 있는 바깥 맵이다 " .. key)
	expect(sc.rest == true or SCENES.homes[key] == true, "정류장은 마을이거나 쉬는 곳이다 " .. key)
end
for key in SCENES.homes do
	expect(Coach.isStation(key), "마을은 모두 정류장이다 " .. key)
end
-- 정류장마다 마부(같은 사람)가 시작 자리 곁 단단한 땅 위에 선다 · 문 · 다른 주민과 겹치지 않는다
local function coachIn(key)
	for _, n in SCENES.scenes[key].npcs or {} do
		if n.id == "coachman" then
			return n
		end
	end
	return nil
end
for _, key in D.stations do
	local sc = SCENES.scenes[key]
	local n = coachIn(key)
	expect(n ~= nil, "정류장에 마부가 있다 " .. key)
	if n then
		eq(n.role .. " " .. n.name, "역마차 마부", "마부의 이름표(「역마차 마부」) " .. key)
		local c, r = math.floor(n.x / 16) + 1, math.floor(n.y / 16) + 1
		local below, at = string.sub(sc.rows[r] or "", c, c), string.sub(sc.rows[r - 1] or "", c, c)
		expect((below == "#" or below == "=") and at == ".", ("마부가 땅 위에 선다 %s (%d, %d: 발밑 %s · 몸 %s)"):format(key, n.x, n.y, below, at))
		expect(math.abs(n.x - sc.spawn.x) <= 320 and n.y == math.floor(sc.spawn.y / 16 + 0.5) * 16, "마부는 시작 자리 곁 · 같은 높이에 있다 " .. key)
		for _, p in sc.portals or {} do
			expect(math.abs(p.x - n.x) >= 30, "마부가 문과 겹치지 않는다 " .. key)
		end
		for _, o in sc.npcs do
			if o ~= n then
				expect(math.abs(o.x - n.x) >= 30 or math.abs(o.y - n.y) > 40, ("마부가 다른 주민(%s)과 겹치지 않는다 %s"):format(o.id, key))
			end
		end
	end
end
for key, sc in SCENES.scenes do
	if not Coach.isStation(key) then
		eq(coachIn(key), nil, "정류장이 아닌 곳에는 마부가 없다 " .. key)
	end
end
local function names(list)
	local out = {}
	for _, x in list do
		table.insert(out, x.scene)
	end
	table.sort(out)
	return table.concat(out, " ")
end
eq(names(Coach.from("town")), "r1af r1bv r1cc", "초승달 마을에서: 1지역의 정류장만")
eq(names(Coach.from("ct")), "r2af r2bs", "은달 항구에서: 그 땅의 정류장만(배로 건너온 초승달 마을은 못 간다)")
eq(names(Coach.from("seat")), "seaf", "물마루 마을에서: 섬의 쉼터만")
expect(#Coach.from("port") >= 5, "등불 포구에서: 3 · 4지역의 정류장들")
eq(Coach.fare("town", "ct"), nil, "배로 가야 하는 곳은 못 간다")
eq(Coach.fare("town", "town"), nil, "지금 있는 곳은 못 간다")
eq(Coach.fare("hunt", "r1bv"), nil, "정류장이 아닌 곳에서는 못 탄다")
local near, far = Coach.fare("town", "r1af"), Coach.fare("town", "r1cc")
expect(near and far and near >= D.fare.base + D.fare.step and far > near, ("멀수록 비싸다(세 갈래 길 %s · 수비대 야영지 %s)"):format(tostring(near), tostring(far)))
eq((near - D.fare.base) % D.fare.step, 0, "삯 = base + 거쳐 가는 맵 수 x step")

-- 서버
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, book = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local p = { UserId = 9801, Name = "역마차손님", DisplayName = "역마차손님", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "마차손님", "riven")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local h = s.hero
expect(handlers.Coach ~= nil, "서버가 역마차를 받는다")
local function byCoach(key)
	World.jump(p, key)
	s.loading = nil
	local n = coachIn(key)
	h.x, h.y = n.x - 10, n.y
end
World.jump(p, "town")
s.loading = nil
h.money = 1000
h.x = coachIn("town").x + 160
local got = handlers.Coach(p, "r1bv")
expect(got and not got.ok and got.msg == Coach.WORDS.notHere and h.money == 1000, "마부 곁이 아니면(160도트 떨어져서) 못 탄다")
byCoach("town")
local fare = Coach.fare("town", "r1bv")
got = handlers.Coach(p, "r1bv")
expect(got and got.ok, "초승달 마을 → 고갯마루 주막 — " .. tostring(got and got.msg))
eq(SCENES.base(s.scene), "r1bv", "고갯마루 주막에 닿았다")
eq(h.money, 1000 - fare, "삯만큼 달돈이 줄었다")
local sx, sy = Coach.spot("r1bv")
expect(math.abs(h.x - sx) <= 16 and math.abs(h.y - sy) <= 32, "그 정류장의 시작 자리에 내린다")
byCoach("r1bv")
got = handlers.Coach(p, "ct")
expect(got and not got.ok and got.msg == Coach.WORDS.far, "배로 가야 하는 곳(은달 항구)은 못 간다")
World.jump(p, "hunt")
s.loading = nil
got = handlers.Coach(p, "town")
expect(got and not got.ok and got.msg == Coach.WORDS.notHere, "정류장이 아닌 곳에서는 못 탄다")
byCoach("r1bv")
h.money = 10
got = handlers.Coach(p, "town")
expect(got and not got.ok and got.msg == Coach.WORDS.poor and h.money == 10, "달돈이 모자라면 못 탄다(달돈은 그대로)")
h.money = 1000
h.alive = false
got = handlers.Coach(p, "town")
expect(got and not got.ok and SCENES.base(s.scene) == "r1bv", "쓰러져 있으면 못 탄다")
h.alive = true
h.inCheck = true
got = handlers.Coach(p, "town")
expect(got and not got.ok, "매크로 확인 문제가 떠 있으면 못 탄다")
h.inCheck = nil
got = handlers.Coach(p, "town")
expect(got and got.ok and SCENES.base(s.scene) == "town", "되돌아온다")
