-- 「달의 계승자」 — 서버의 세계(server/lune/modules/world.luau): 들어오기 · 자리 보고 · 문 · 기술(구간과 이어 누르기) · 보상 · 줍기 · 물약 · 쓰러졌다 일어나기
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local packets = req("ReplicatedStorage/shared/lune/net/packets")
local RULES = COMBAT.rules
local TICK = 1 / 20

-- ---- 가짜 네트워크 · 서비스 ----
local sent = {}
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		expect(packets[name] ~= nil and packets[name].Direction == "ServerToClient", "정의된 서버→클라 패킷 " .. tostring(name))
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		expect(packets[name] ~= nil and packets[name].Direction == "ClientToServer", "정의된 클라→서버 패킷 " .. tostring(name))
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
-- 가짜 저장소: 읽고 쓴 것을 적어 둔다. disk = 계정들 · oldDisk = 계정이 생기기 전의 저장(캐릭터 하나) · nameBook = 이름 장부(이름 → 가진 사람)
local disk = {}
local oldDisk = {}
local nameBook = {}
local rankDisk, rankInfo = {}, {} -- 명예의 전당: [판][열쇠] = 점수 · [열쇠] = { name, class }
local saves = 0
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(userId) return disk[userId] end,
	saveAccount = function(userId, data) disk[userId] = data; saves += 1; return true end,
	loadOld = function(userId) return oldDisk[userId] end,
	nameOwner = function(key) return nameBook[key] end,
	claimName = function(key, userId)
		if nameBook[key] ~= nil and nameBook[key] ~= userId then
			return false
		end
		nameBook[key] = userId
		return true
	end,
	freeName = function(key, userId)
		if nameBook[key] == userId then
			nameBook[key] = nil
		end
	end,
	rankSet = function(board, key, score) rankDisk[board] = rankDisk[board] or {}; rankDisk[board][key] = score end,
	rankRemove = function(board, key) if rankDisk[board] then rankDisk[board][key] = nil end end,
	rankTop = function(board, n)
		local rows = {}
		for key, score in rankDisk[board] or {} do
			table.insert(rows, { key = key, score = score })
		end
		table.sort(rows, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.key < b.key end)
		while #rows > n do table.remove(rows) end
		return rows
	end,
	rankInfoSet = function(key, info) rankInfo[key] = info end,
	rankInfoGet = function(key) return rankInfo[key] end,
	rankInfoRemove = function(key) rankInfo[key] = nil end,
	isOffline = function() return false end,
})
-- 가짜 글 거르기: "욕설"이 든 글은 #으로 가린다(가려진 데가 있는 이름은 지을 수 없다)
SERVICE("TextService", {
	FilterStringAsync = function(_, text, _userId)
		return { GetNonChatStringForBroadcastAsync = function() return (string.gsub(text, "욕설", "##")) end }
	end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
for name, def in packets do
	if def.Direction == "ClientToServer" then
		expect(handlers[name] ~= nil, "핸들러가 있는 패킷 " .. name)
		-- 클라이언트가 보내는 패킷은 인자의 꼴과 보내는 빠르기의 한도가 꼭 있어야 한다(없으면 진짜 서버에서 받는 순간 오류가 난다 — 2026-10-08의 Return)
		expect(typeof(def.Args) == "table", "인자의 꼴이 있는 패킷 " .. name)
		expect(typeof(def.RateLimit) == "table" and def.RateLimit.PerSecond > 0 and def.RateLimit.Burst >= 1, "보내는 빠르기의 한도가 있는 패킷 " .. name)
	end
end

-- 뒤의 검사들이 짧게 쓰는 들어오기: 캐릭터가 있으면 마지막에 하던 캐릭터로 바로 들어가고(Ready), 없으면 만들어서 들어간다(Choose — 이름을 안 주면 "시험<번호>")
--  진짜 차례(고르기 화면 → 중복 확인 → 만들기 → 들어가기)는 아래 「들어오기」에서 패킷 그대로 본다
--  새 캐릭터는 사당 안에서 시작한다(2026-10-10). 뒤의 검사들은 마을의 시작 자리에서 보던 것들이라, 짧은 들어오기는 들어온 뒤 마을의 시작 자리로 옮겨 놓는다(World.jump — 그동안 보낸 것은 지운다)
local rawReady
local function toTown(p, r)
	if r and r.self and r.scene ~= SCENES.start then
		local n0 = #sent
		World.jump(p, SCENES.start)
		for i = #sent, n0 + 1, -1 do
			sent[i] = nil
		end
		return (rawReady or handlers.Ready)(p)
	end
	return r
end
local function enterAgain(p)
	local r = rawReady(p)
	if r and r.select then
		if #r.select.chars == 0 then
			return { choose = true }
		end
		return toTown(p, handlers.Chars(p, "enter", r.select.last or r.select.chars[1].id))
	end
	return r
end
local function createAndEnter(p, class, name)
	local made = handlers.Chars(p, "create", name or ("시험" .. p.UserId), class)
	if not made or not made.ok then
		return nil
	end
	return toTown(p, handlers.Chars(p, "enter", made.id))
end

local function got(name, player)
	local out = {}
	for _, e in sent do
		if e.name == name and (player == nil or e.player == player) then
			table.insert(out, e)
		end
	end
	return out
end
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
-- 대지 강타를 화면이 하듯 쓴다: 첫 구간(도끼를 치켜든다 — 힘을 모으는 구간)을 보내고, 그 구간이 끝나면(hold초 더 누르고 있다가) 둘째 구간(내려찍기)을 보낸다.
--  힘을 모으는 구간의 다음 구간은 서버가 저절로 잇지 않는다 — 키를 뗄 때 화면이 보낸다(누르고 있던 시간으로 모은 단계를 서버가 셈한다)
local function castSlam(p, x, y, dir, hold)
	handlers.Skill(p, "ax_slam", 1, x, y, dir)
	run(COMBAT.skills.ax_slam.segs[1].time + (hold or 0))
	handlers.Skill(p, "ax_slam", 2, x, y, dir)
end

-- 가짜 플레이어: 진짜 Player처럼 없는 값을 읽으면 오류가 난다(서버 코드가 Player에 없는 값을 읽는 실수를 여기서 잡는다)
local function person(t)
	t.DisplayName = t.DisplayName or t.Name
	t.attrs = {}
	t.SetAttribute = function(self, key, value)
		self.attrs[key] = value
	end
	return setmetatable(t, {
		__index = function(_, key)
			error(("%s is not a valid member of Player"):format(tostring(key)), 2)
		end,
	})
end

-- 맵의 차례를 따라 그 장면까지 간다(문 앞으로 옮겨 놓고 지나간다). 마지막으로 지난 문의 결과를 돌려준다
local function routeNext(from, target)
	local prev, queue = { [from] = from }, { from }
	while #queue > 0 do
		local cur = table.remove(queue, 1)
		if cur == target then
			while prev[cur] ~= from do
				cur = prev[cur]
			end
			return cur
		end
		for _, portal in SCENES.scenes[cur].portals do
			if not prev[portal.to] then
				prev[portal.to] = cur
				table.insert(queue, portal.to)
			end
		end
	end
	return nil
end
-- 주민을 찾는 차례: 같은 주민이 여러 장면에 있다(반달 = 잡화점 안 · 고갯마루 주막 · 반달 나루 / 샛별 = 마을 · 갈림목 쉼터들).
--  건물 안(in_) → 마을 → 나머지는 이름 차례 — 늘 같은 곳을 고른다
local NPC_ORDER = {}
for key in SCENES.scenes do
	table.insert(NPC_ORDER, key)
end
table.sort(NPC_ORDER, function(a, b)
	local function rank(k)
		return if k:sub(1, 3) == "in_" then 0 elseif k == "town" then 1 else 2
	end
	if rank(a) ~= rank(b) then
		return rank(a) < rank(b)
	end
	return a < b
end)
local function goTo(player, target)
	local trip = nil
	for _ = 1, 32 do
		local ss = World.session(player)
		if ss.scene == target then
			break
		end
		local hop = routeNext(ss.scene, target)
		for _, portal in SCENES.scenes[ss.scene].portals do
			if portal.to == hop then
				ss.jumped, ss.stale = true, nil
				handlers.Move(player, portal.x, portal.y, 1)
			end
		end
		trip = handlers.Travel(player, hop)
		if not trip then
			return nil
		end
	end
	return trip
end

-- ---- 1) 들어오기 ----
local p1 = person({ UserId = 101, Name = "계승자1" })
local p2 = person({ UserId = 102, Name = "계승자2" })
-- 처음 온 사람은 캐릭터가 없다 — 캐릭터 고르기 화면에서 만들어야 한다
local empty = handlers.Ready(p1)
expect(empty ~= nil and empty.select ~= nil and #empty.select.chars == 0, "처음 온 사람은 빈 캐릭터 고르기 화면을 받는다")
expect(empty.select.max >= 5, "만들 수 있는 캐릭터의 수가 온다 " .. tostring(empty.select.max))
handlers.Move(p1, 10, 10, 1)
handlers.Skill(p1, "ax_slam", 1, 0, 0, 1)
handlers.Potion(p1)
eq(handlers.Travel(p1, "hunt"), nil, "캐릭터가 없으면 아무것도 못 한다")
eq(handlers.Chars(p1, "enter", 1), nil, "없는 캐릭터로는 들어갈 수 없다")
-- 이름: 꼴 · 글 거르기 · 중복 확인
eq(handlers.Chars(p1, "check", "달").ok, false, "한 글자 이름은 안 된다")
eq(handlers.Chars(p1, "check", "달빛 검").ok, false, "띄어쓰기가 든 이름은 안 된다")
eq(handlers.Chars(p1, "check", "일이삼사오육칠").ok, false, "한글 일곱 자는 길다")
eq(handlers.Chars(p1, "check", "욕설쟁이").ok, false, "글 거르기에 걸린 이름은 안 된다")
eq(handlers.Chars(p1, "check", "운영자").ok, false, "운영하는 사람인 척하는 이름은 안 된다")
eq(handlers.Chars(p1, "check", "달빛도끼").ok, true, "지을 수 있는 이름")
expect(nameBook["달빛도끼"] == nil, "확인만으로는 이름을 갖지 않는다")
eq(handlers.Chars(p1, "create", "달빛도끼", "wizard").ok, false, "없는 직업으로는 만들 수 없다")
eq(handlers.Chars(p1, "create", "달", "axion").ok, false, "안 되는 이름으로는 만들 수 없다")
local made = handlers.Chars(p1, "create", "달빛도끼", "axion")
expect(made ~= nil and made.ok == true and made.id == 1, "캐릭터를 만든다")
eq(#made.select.chars, 1, "고르기 화면에 캐릭터가 하나 생겼다")
eq(made.select.chars[1].name, "달빛도끼", "지은 이름 그대로")
eq(made.select.chars[1].class, "axion", "고른 직업")
eq(made.select.chars[1].level, 1, "Lv.1")
eq(nameBook["달빛도끼"], p1.UserId, "이름 장부에 내 이름으로 적혔다")
expect(disk[p1.UserId] ~= nil and disk[p1.UserId].chars[1].hero.class == "axion", "만들자마자 저장한다")
eq(World.session(p1).hero, nil, "만들기만 해서는 세계에 서지 않는다")
-- 남이 가진 이름은 지을 수 없다(영문은 대소문자를 가리지 않는다)
eq(handlers.Ready(p2).select.max, empty.select.max, "둘째 사람도 고르기 화면부터")
local taken = handlers.Chars(p2, "check", "달빛도끼")
expect(taken.ok == false and taken.why == "이미 있는 이름입니다", "남이 가진 이름은 중복이다")
eq(handlers.Chars(p2, "create", "달빛도끼", "mooni").ok, false, "남이 가진 이름으로는 만들 수 없다")
eq(handlers.Chars(p1, "create", "MoonAxe", "riven").ok, true, "둘째 캐릭터(영문 이름)")
eq(handlers.Chars(p2, "check", "moonaxe").ok, false, "대소문자만 다른 이름도 중복이다")
eq(handlers.Chars(p1, "check", "달빛도끼").ok, false, "내 다른 캐릭터의 이름도 중복이다")
-- 삭제: 이름을 똑같이 적어야 지워진다. 지운 이름은 다시 지을 수 있다
eq(handlers.Chars(p1, "delete", 2, "moonaxe").ok, false, "이름을 다르게 적으면 지워지지 않는다")
eq(handlers.Chars(p1, "delete", 9, "MoonAxe").ok, false, "없는 캐릭터는 지울 수 없다")
local gone = handlers.Chars(p1, "delete", 2, "MoonAxe")
expect(gone.ok == true and #gone.select.chars == 1, "이름을 똑같이 적으면 지워진다")
eq(#disk[p1.UserId].chars, 1, "지운 것도 바로 저장한다")
eq(nameBook["moonaxe"], nil, "지운 캐릭터의 이름은 장부에서 빠진다")
eq(handlers.Chars(p2, "check", "moonaxe").ok, true, "그 이름을 다른 사람이 지을 수 있다")
-- 들어가기
local first = handlers.Chars(p1, "enter", 1)
expect(first ~= nil and first.self.class == "axion", "캐릭터를 골라 들어간다")
-- 새 캐릭터는 사당 안(첫 퀘스트를 주는 사제의 방)의 문 앞에서 시작한다 — 뒤의 검사는 마을의 시작 자리에서 본다
eq(first.scene, "in_shrine", "새 캐릭터는 사당 안에서 시작한다")
eq(first.x, SCENES.scenes.in_shrine.spawn.x, "사당의 문 앞")
expect((first.quests or {}).r1m1 == nil, "첫 퀘스트 「첫 기술」도 저절로 받지 않는다(사제에게 말을 걸어 받는다 — 2026-10-11)")
do
	local near = false
	for _, n in SCENES.scenes.in_shrine.npcs do
		near = near or n.id == "master"
	end
	expect(near, "그 방에 첫 퀘스트를 돌려받는 사제가 있다")
end
first = toTown(p1, first)
eq(first.name, "달빛도끼", "내 이름은 지은 이름이다(Roblox의 이름이 아니다)")
eq(p1.attrs.LuneName, "달빛도끼", "다른 사람의 화면(채팅)에 쓰일 이름을 적어 둔다")
eq(handlers.Chars(p1, "create", "하나더", "riven"), nil, "세계에 있는 동안에는 캐릭터를 만들 수 없다")
eq(handlers.Chars(p1, "delete", 1, "달빛도끼"), nil, "세계에 있는 동안에는 캐릭터를 지울 수 없다")
eq(disk[p1.UserId].last, false, "들어간 것은 다음 저장 때 적힌다")
eq(handlers.Ready(p1).self.class, "axion", "들어간 뒤에 다시 물으면 그 캐릭터를 준다")
-- 뒤의 검사들은 짧은 들어오기를 쓴다
rawReady = handlers.Ready
handlers.Ready = enterAgain
handlers.Choose = createAndEnter
eq(first.scene, SCENES.start, "처음 장면은 마을")
eq(first.self.level, 1, "Lv.1")
eq(first.self.hp, N.hpOf("axion", 1), "체력")
eq(first.self.potions, RULES.startPotions, "처음 물약")
eq(#first.room.mobs, 0, "마을에는 졸개가 없다")
local s1 = World.session(p1)
eq(s1.hero.x, SCENES.scenes.town.spawn.x, "시작 자리")

-- ---- 2) 자리 보고와 문 ----
handlers.Move(p1, s1.hero.x + 10, s1.hero.y, 1)
eq(s1.hero.x, SCENES.scenes.town.spawn.x + 10, "자리를 받아 적는다")
handlers.Move(p1, s1.hero.x + 500, s1.hero.y, 1)
eq(s1.hero.x, SCENES.scenes.town.spawn.x + 10, "순간이동은 믿지 않는다")
handlers.Move(p1, -50, 0, 1)
eq(s1.hero.x, SCENES.scenes.town.spawn.x + 10, "맵 밖은 받지 않는다")
-- 그 맵의 시작 자리로 온 것은 멀어도 받는다(맵 아래로 떨어지면 화면이 시작 자리로 돌려놓는다 — 이것을 막으면 그 뒤로 서버가 아는 자리와 영영 어긋난다.
--  사용자 2026-10-07: "가시맞고 돌아간다음에 몬스터랑 전투도안되고 고장나네요" — 가시의 되돌리기는 없앴고, 같은 고장이 다시 나지 않게 이 길을 열어 두었다)
do
	local spawn = SCENES.scenes.town.spawn
	handlers.Move(p1, spawn.x + 300, spawn.y, 1)
	eq(s1.hero.x, spawn.x + 10, "먼 곳으로의 순간이동은 여전히 믿지 않는다")
	local far = World.session(p1)
	far.hero.x = spawn.x + 300 -- 서버가 아는 자리가 먼 곳일 때
	handlers.Move(p1, spawn.x, spawn.y, 1)
	eq(s1.hero.x, spawn.x, "시작 자리로 돌아온 것은 받는다")
	handlers.Move(p1, spawn.x + 10, spawn.y, 1)
	eq(s1.hero.x, spawn.x + 10, "그 뒤의 자리 보고도 받는다(어긋나지 않는다)")
end
-- 문에서 먼 곳에서는 못 간다
handlers.Move(p1, s1.hero.x + 80, s1.hero.y, 1)
handlers.Move(p1, s1.hero.x + 80, s1.hero.y, 1)
eq(handlers.Travel(p1, "hunt"), nil, "문 앞이 아니면 못 간다")
eq(handlers.Travel(p1, "nowhere"), nil, "없는 장면으로는 못 간다")
-- 문 앞으로 걸어가서 간다
local gate = SCENES.scenes.town.portals[1]
while math.abs(s1.hero.x - gate.x) > 10 do
	handlers.Move(p1, s1.hero.x + (if gate.x > s1.hero.x then 1 else -1) * 60, gate.y, 1)
end
local trip = handlers.Travel(p1, gate.to)
expect(trip ~= nil and trip.scene == gate.to, "문으로 다음 맵(마을 어귀)에 간다")
eq(s1.scene, gate.to, "서버가 아는 장면이 바뀐다")
eq(#trip.room.mobs, #SCENES.scenes[gate.to].mobs, "그 맵의 졸개 목록을 받는다")
eq(handlers.Travel(p1, "hunt"), nil, "들어온 문 앞에서는 건너편 문으로 못 간다")
trip = goTo(p1, "hunt")
expect(trip ~= nil and trip.scene == "hunt", "마을 어귀를 지나 사냥터에 간다")
eq(s1.scene, "hunt", "사냥터에 왔다")
eq(#trip.room.mobs, #SCENES.scenes.hunt.mobs, "사냥터의 졸개 목록을 받는다")
local back = SCENES.scenes.hunt.portals[1]
eq(trip.x, back.x, "마을로 가는 문 앞에 선다")

-- ---- 2-1) 건물의 문: 마을의 문 앞에서 그 건물의 실내로, 실내의 문 앞에서 들어갔던 그 문 앞으로 ----
do
	expect(goTo(p1, SCENES.start) ~= nil, "마을로 돌아온다")
	local town = SCENES.scenes[SCENES.start]
	local doors = 0
	for _, door in town.portals do
		local inside = SCENES.scenes[door.to]
		if inside.indoor then
			doors += 1
			eq(handlers.Travel(p1, door.to), nil, "문 앞이 아니면 못 들어간다 " .. door.to)
			s1.jumped, s1.stale = true, nil
			handlers.Move(p1, door.x, door.y, 1)
			local into = handlers.Travel(p1, door.to)
			expect(into ~= nil and into.scene == door.to, "문 앞에서 들어간다 " .. door.to)
			local exit = inside.portals[1]
			expect(into.x == exit.x and into.y == exit.y, "들어가면 나가는 문 앞에 선다 " .. door.to)
			eq(#into.room.mobs, 0, "실내에는 졸개가 없다 " .. door.to)
			eq(s1.scene, door.to, "서버가 아는 장면이 바뀐다 " .. door.to)
			local out = handlers.Travel(p1, SCENES.start)
			expect(out ~= nil and out.scene == SCENES.start, "나가는 문으로 마을에 나온다 " .. door.to)
			expect(out.x == door.x and out.y == door.y, ("들어갔던 그 문 앞으로 나온다 %s (%d, %d)"):format(door.to, out.x, out.y))
		end
	end
	expect(doors >= 5, "들어갈 수 있는 건물이 다섯")
	expect(goTo(p1, "hunt") ~= nil, "다시 사냥터로")
	eq(s1.scene, "hunt", "사냥터에 왔다(다음 검사를 위해)")
end

-- ---- 3) 졸개의 모습이 온다 ----
table.clear(sent)
run(1)
local snaps = got("Snap", p1)
expect(#snaps >= 8 and #snaps <= 12, "1초에 열 번쯤 온다 " .. #snaps)
eq(snaps[1].args[1], "hunt", "어느 장면의 것인지")
eq(#snaps[1].args[2], #SCENES.scenes.hunt.mobs, "졸개 수만큼")

-- ---- 4) 기술 ----
local room = World.room("hunt")
local foe = nil
for _, mob in room.mobs do
	if mob.kind == "warrior" then
		foe = mob
		break
	end
end
run(1) -- 나타나는 동작이 끝날 때까지
-- 졸개 옆으로 간다(순간이동은 안 되므로 걸어서)
local function walkTo(x, y)
	local s = World.session(p1)
	s.jumped, s.stale = true, nil
	handlers.Move(p1, x, y, 1)
end
walkTo(foe.x - 20, foe.y)
local slam = COMBAT.skills.ax_slam
local combo = COMBAT.skills.ax_combo
table.clear(sent)
local hp0 = foe.hp
handlers.Skill(p1, "ax_combo", 1, s1.hero.x, s1.hero.y, 1)
eq(#got("Hits"), 0, "누르자마자 맞지는 않는다")
run(combo.hits[1].at + 0.06)
local hits = got("Hits", p1)
expect(#hits == 1, "맞는 때가 되면 맞는다")
eq(hits[1].args[1], p1.UserId, "누가 쳤는지")
expect(foe.hp < hp0, "졸개의 체력이 준다")
-- 이어 누르기: 둘째 타는 첫 타 도중에만 이어진다
table.clear(sent)
handlers.Skill(p1, "ax_combo", 3, s1.hero.x, s1.hero.y, 1)
run(0.6)
eq(#got("Hits"), 0, "둘째 타를 건너뛰고 셋째 타를 쓸 수는 없다")
run(1)
handlers.Skill(p1, "ax_combo", 2, s1.hero.x, s1.hero.y, 1)
run(0.6)
eq(#got("Hits"), 0, "첫 타가 끝나고 한참 뒤에는 이어지지 않는다")
-- 제대로: 1 → 2 → 3
walkTo(foe.x - 20, foe.y)
handlers.Skill(p1, "ax_combo", 1, s1.hero.x, s1.hero.y, 1)
run(combo.segs[1].time * 0.8)
handlers.Skill(p1, "ax_combo", 2, s1.hero.x, s1.hero.y, 1)
run(combo.segs[2].time * 0.8)
handlers.Skill(p1, "ax_combo", 3, s1.hero.x, s1.hero.y, 1)
run(combo.segs[3].time + 0.1)
expect(#got("Hits") >= 2, "이어 누르면 세 타가 차례로 나간다 " .. #got("Hits"))
-- 기술 도중에 다른 기술을 시작할 수 없다
table.clear(sent)
walkTo(foe.x - 20, foe.y)
castSlam(p1, s1.hero.x, s1.hero.y, 1)
handlers.Skill(p1, "ax_combo", 1, s1.hero.x, s1.hero.y, 1)
run(slam.time + 0.3)
local total = 0
for _, e in got("Hits") do
	total += 1
end
expect(total >= 1, "대지 강타가 맞는다")
-- 남의 직업 기술 · 없는 기술 · 이상한 구간은 받지 않는다
table.clear(sent)
handlers.Skill(p1, "no_such", 1, 0, 0, 1)
handlers.Skill(p1, "ax_slam", 9, 0, 0, 1)
handlers.Skill(p1, "ax_slam", 1.5, 0, 0, 1)
run(1)
eq(#got("Hits"), 0, "없는 기술 · 이상한 구간은 버린다")

-- ---- 5) 잡으면 경험치 · 달돈, 주우면 내 것 ----
table.clear(sent)
local kills = 0
for _ = 1, 400 do
	local target = nil
	for _, mob in room.mobs do
		if mob.state ~= "dead" and mob.state ~= "gone" and mob.state ~= "spawn" then
			target = mob
			break
		end
	end
	if target then
		walkTo(target.x - 14, target.y)
		castSlam(p1, s1.hero.x, s1.hero.y, 1)
	end
	run(slam.time + 0.15)
	if not s1.hero.alive then
		run(RULES.reviveWait + 0.5) -- 쓰러졌으면 마을로 돌아가 일어나 다시 사냥터로
		handlers.Return(p1)
		s1.scene = "hunt"
	end
	kills = #got("Gain", p1)
	if kills >= 12 then
		break
	end
end
expect(kills >= 12, "졸개를 열두 마리 잡는다 " .. kills)
expect(s1.hero.level >= 2 or s1.hero.xp >= 12 * 10, ("경험치가 쌓인다 — Lv.%d, 경험치 %d"):format(s1.hero.level, s1.hero.xp))
local adds = got("DropAdd", p1)
expect(#adds >= 2, "달돈이 떨어진다 " .. #adds)
-- 떨어지는 것은 달돈 말고도 있다(장비 · 달가루 · 재료 · 물약) — 달돈 하나를 골라 줍는 것을 본다
local drop = nil
local kinds = {}
for _, e in adds do
	local d = e.args[1]
	kinds[d.kind] = (kinds[d.kind] or 0) + 1
	if d.kind == "money" and not drop then
		drop = d
	end
	expect(d.kind == "money" or d.kind == "gear" or d.kind == "dust" or d.kind == "goods" or d.kind == "quest", "떨어진 것의 갈래 " .. tostring(d.kind))
	if d.kind == "goods" then
		expect(typeof(d.name) == "string" and typeof(d.icon) == "string" and d.amount == 1, "재료 · 물약은 이름과 그림이 실려 온다")
	end
end
expect(drop ~= nil and drop.kind == "money" and drop.amount > 0, "떨어진 것의 짜임")
table.clear(sent)
s1.hero.alive = true
walkTo(drop.x + 300, drop.y)
handlers.Pickup(p1, drop.id)
eq(#got("DropGone"), 0, "멀리서는 못 줍는다")
walkTo(drop.x, drop.y)
local money0 = s1.hero.money
handlers.Pickup(p1, drop.id)
eq(#got("DropGone", p1), 1, "주우면 방 사람들에게 알린다")
eq(s1.hero.money, money0 + drop.amount, "달돈이 는다")
expect(#got("Self", p1) >= 1, "내 상태가 다시 온다")

-- ---- 6) 물약 ----
table.clear(sent)
s1.hero.hp = 1
s1.hero.invuln = 5 -- 물약을 보는 동안에는 맞지 않게
local HeroSim = req("ReplicatedStorage/shared/lune/sim/hero")
local pots = HeroSim.potions(s1.hero)
run(1.1)
handlers.Potion(p1)
expect(s1.hero.hp > 1 and HeroSim.potions(s1.hero) == pots - 1, "물약을 마신다")
expect(#got("Bag", p1) >= 1, "물약을 마시면 가방이 다시 온다(소비 탭의 수가 준다)")
handlers.Potion(p1)
eq(HeroSim.potions(s1.hero), pots - 1, "바로 또 마시지는 못한다")
-- 퀵슬롯의 칸에 놓인 바로 그 물약을 쓴다(이름표를 보낸다) · 없는 것 · 아직 못 쓰는 것은 까닭이 온다
run(1.1)
s1.hero.hp = 1
handlers.Potion(p1, "potion1")
eq(HeroSim.potions(s1.hero), pots - 2, "이름표로 고른 물약을 마신다")
run(1.1)
s1.hero.hp = 1
table.clear(sent)
handlers.Potion(p1, "potion2")
do
	local done = got("ItemDone", p1)
	expect(#done == 1 and done[1].args[1].ok == false and done[1].args[1].why == "가진 물약이 없다", "없는 물약은 못 마신다")
end
handlers.Potion(p1, "no_such")
handlers.Potion(p1, { 1 })
eq(HeroSim.potions(s1.hero), pots - 2, "이상한 요청에는 물약이 줄지 않는다")

-- ---- 7) 쓰러졌다가 마을에서 일어난다 ----
table.clear(sent)
s1.hero.invuln = 0
s1.hero.hp = 1
walkTo(foe.homeX, foe.y)
for _ = 1, 400 do
	World.tick(TICK)
	if not s1.hero.alive then
		break
	end
end
expect(not s1.hero.alive, "졸개에게 맞아 쓰러진다")
expect(#got("Hurt", p1) >= 1, "맞았다는 알림이 온다")
castSlam(p1, s1.hero.x, s1.hero.y, 1)
handlers.Move(p1, s1.hero.x + 5, s1.hero.y, 1)
-- 저절로 마을로 가지 않는다: 그 자리에 쓰러져(비석) 있다가, 「마을로 돌아간다」를 눌러야 간다(쓰러진 직후에는 받지 않는다)
handlers.Return(p1)
expect(not s1.hero.alive, "쓰러진 직후에는 돌아가지 못한다")
run(RULES.reviveWait + 0.2)
expect(not s1.hero.alive and s1.scene == "hunt", "저절로 일어나지 않는다")
eq(#got("Revive", p1), 0, "아직 일어나지 않았다")
run(30)
expect(not s1.hero.alive and s1.scene == "hunt", "오래 지나도 그 자리에 쓰러져 있다")
handlers.Return(p1)
expect(s1.hero.alive and s1.hero.hp == s1.hero.maxHp, "일어나면 체력이 다 찬다")
eq(s1.scene, SCENES.start, "마을에서 일어난다")
eq(#got("Revive", p1), 1, "일어났다는 알림")
handlers.Return(p1)
eq(#got("Revive", p1), 1, "살아 있는 사람의 요청은 버린다")

-- ---- 8) 두 사람: 같은 방 사람만 받는다 ----
handlers.Ready(p2)
expect(handlers.Choose(p2, "mooni") ~= nil, "둘째 사람은 무니")
table.clear(sent)
run(0.5)
eq(#got("Snap"), 0, "마을에는 졸개가 없어 보낼 것이 없다")
local s2 = World.session(p2)
expect(goTo(p2, "hunt") ~= nil, "둘째 사람이 사냥터에 간다")
table.clear(sent)
run(0.5)
expect(#got("Snap", p2) >= 4, "사냥터에 있는 사람은 받는다")
eq(#got("Snap", p1), 0, "마을에 있는 사람은 사냥터의 것을 받지 않는다")
-- 능력치 · 스킬 요청
local s2b = World.session(p2)
s2b.hero.auto = false
req("ReplicatedStorage/shared/lune/sim/hero").gainXp(s2b.hero, N.xpNeed(1) + N.xpNeed(2)) -- Lv.3: 능력치 10점 · 스킬 포인트 6점
eq(s2b.hero.ap, 10, "능력치 점수")
eq(s2b.hero.sp, 6, "스킬 포인트")
table.clear(sent)
handlers.StatAdd(p2, "str", 3)
eq(s2b.hero.stats.str, 3, "능력치를 찍는다")
handlers.StatAdd(p2, "str", 99)
eq(s2b.hero.stats.str, 3, "가진 것보다 많이는 안 된다")
handlers.StatAuto(p2)
eq(s2b.hero.ap, 0, "자동으로 찍기")
handlers.SkillUp(p2, "mn_spin")
eq(s2b.hero.skills.mn_spin, 2, "스킬을 올린다")
handlers.SkillUp(p2, "ax_slam")
eq(s2b.hero.sp, 5, "남의 스킬은 안 된다")
handlers.SkillAuto(p2)
eq(s2b.hero.sp, 0, "추천대로 찍기")
expect(#got("Self", p2) >= 4, "바뀔 때마다 내 상태가 온다")
-- 남의 직업 기술은 쓸 수 없다
table.clear(sent)
castSlam(p2, s2b.hero.x, s2b.hero.y, 1)
run(1.2)
eq(#got("Hits", p2), 0, "남의 직업 기술은 버린다")

-- 나가면 저장하고 지운다 → 다시 들어오면 그대로다
local lv, money, str = s2b.hero.level, s2b.hero.money, s2b.hero.stats.str
s2b.hero.money = money + 123
local before = saves
World.removePlayer(p2)
eq(World.session(p2), nil, "나가면 지운다")
expect(saves > before, "나갈 때 저장한다")
local again = handlers.Ready(p2)
expect(again ~= nil and again.self ~= nil, "다시 들어온다")
eq(again.self.class, "mooni", "직업이 그대로")
eq(again.self.level, lv, "레벨이 그대로")
eq(again.self.money, money + 123, "돈이 그대로")
eq(again.self.stats.str, str, "능력치가 그대로")
eq(again.self.skills.mn_spin, s2b.hero.skills.mn_spin, "스킬이 그대로")
eq(again.scene, SCENES.start, "마을에서 시작한다")
-- 확인용 명령은 Studio가 아니면 듣지 않는다(테스트의 가짜 서버는 Studio가 아니다)
local xpBefore = World.session(p2).hero.xp
handlers.Debug(p2, "xp", 99999)
eq(World.session(p2).hero.xp, xpBefore, "실제 서버에서는 확인용 명령이 듣지 않는다")
handlers.Debug(p2, "reset", 0)
expect(World.session(p2).hero ~= nil, "캐릭터를 지우지도 않는다")

-- 틈틈이 저장: 바뀐 사람만
local n0 = saves
World.saveAll(true)
local n1 = saves
handlers.StatAuto(p2)
World.session(p2).hero.ap = 1
handlers.StatAuto(p2)
World.saveAll(true)
expect(saves == n1 + 1, ("바뀐 사람만 저장한다(%d → %d → %d)"):format(n0, n1, saves))

-- ---- 물건 다루기(Item): 끼기 · 분해 · 상점 · 강화 · 창고 — 주민 앞에서만 되는 것과 레벨이 되어야 되는 것 ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local OPEN = Items.data.OPEN
	local p3 = person({ UserId = 103, Name = "계승자3" })
	handlers.Ready(p3)
	local start = handlers.Choose(p3, "axion")
	expect(start ~= nil and start.bag ~= nil, "처음 받는 것에 가방이 들어 있다")
	eq(start.bag.size, Items.data.BAG.base, "가방 24칸")
	expect(start.bag.equip.weapon ~= nil, "무기를 끼고 있다")
	local s3 = World.session(p3)
	local h3 = s3.hero
	local function last(name)
		local list = got(name, p3)
		return list[#list] and list[#list].args[1]
	end
	-- 주민은 제 건물 안(실내 장면)에 있다 — 어느 장면의 누구인지 찾고, 그 앞에 서려면 문으로 들어간다
	local function npc(id)
		for _, key in NPC_ORDER do
			local sc = SCENES.scenes[key]
			for _, n in sc.npcs or {} do
				if n.id == id then
					return n, key
				end
			end
		end
		error("없는 주민 " .. id)
	end
	local function stand(id)
		local n, key = npc(id)
		goTo(p3, key)
		eq(s3.scene, key, "주민이 있는 곳으로 간다 " .. id)
		s3.jumped, s3.stale = true, nil
		h3.x, h3.y = n.x + 10, n.y
	end
	local it = Items.make("hat", 1, 5)
	Bag.add(h3, it)
	table.clear(sent)
	handlers.Item(p3, "equip", it.id)
	expect(last("ItemDone").ok == true, "낀다")
	eq(h3.equip.hat, it, "모자가 바뀌었다")
	eq(#got("Bag", p3), 1, "가방이 다시 온다")
	expect(#got("Self", p3) >= 1, "전투력이 바뀌니 내 상태도 다시 온다")
	-- 분해는 어디서나
	local junkId = h3.gear[1].id
	table.clear(sent)
	handlers.Item(p3, "dismantle", junkId)
	expect(last("ItemDone").ok == true and last("ItemDone").result ~= nil, "분해한다")
	eq(Bag.find(h3, junkId), nil, "분해한 것은 없다")
	-- 상점: 파는 사람 앞에서만
	h3.money = 100000
	do
		local m, mkey = npc("merchant")
		expect(SCENES.scenes[mkey].indoor == true, "상인은 건물 안에 있다")
		table.clear(sent)
		handlers.Item(p3, "buy", "potion1", 3)
		expect(last("ItemDone").ok == false and last("ItemDone").why == "파는 사람 앞이 아니다", "건물 밖(마을)에서는 못 산다")
		goTo(p3, mkey)
		eq(s3.scene, mkey, "잡화점 문으로 들어간다")
		eq(h3.x, SCENES.scenes[mkey].portals[1].x, "들어가면 나가는 문 앞에 선다")
		s3.jumped, s3.stale = true, nil
		h3.x, h3.y = m.x + 150, m.y -- 같은 방 안이지만 멀다
	end
	table.clear(sent)
	handlers.Item(p3, "buy", "potion1", 3)
	expect(last("ItemDone").ok == false and last("ItemDone").why == "파는 사람 앞이 아니다", "멀리서는 못 산다")
	stand("merchant")
	local pots3 = Bag.count(h3, "potion1")
	handlers.Item(p3, "buy", "potion1", 3)
	eq(Bag.count(h3, "potion1"), pots3 + 3, "상인 앞에서 물약을 산다(가방의 소비 탭에 들어온다)")
	table.clear(sent)
	handlers.Item(p3, "buy", "potion2", 1)
	expect(last("ItemDone").ok == false and string.find(last("ItemDone").why, "Lv.30") ~= nil, "윗단의 물약은 그 레벨부터 산다")
	-- 가방의 칸: 옮기기 · 정렬 · 버리기는 어디서나(서버가 꼴을 본다)
	do
		local slot1 = h3.use[1]
		expect(slot1 ~= false and slot1.item == "potion1", "물약은 소비 탭 첫 칸에 있다")
		table.clear(sent)
		handlers.Item(p3, "move", "use", 1, 7)
		expect(last("ItemDone").ok == true and h3.use[1] == false and h3.use[7] == slot1, "칸의 것을 다른 칸으로 옮긴다")
		local bagSent = got("Bag", p3)
		expect(#bagSent == 1 and bagSent[1].args[1].use[7].item == "potion1" and bagSent[1].args[1].use[1] == false, "옮긴 가방이 다시 온다(빈 칸은 false)")
		handlers.Item(p3, "sort", "use")
		expect(h3.use[1] ~= false and h3.use[7] == false, "정렬하면 앞에서부터 채워진다")
		local before = Bag.count(h3, "potion1")
		handlers.Item(p3, "discard", "use", 1, 2)
		eq(Bag.count(h3, "potion1"), before - 2, "두 개를 버린다")
		table.clear(sent)
		handlers.Item(p3, "discard", "use", 1, 99999)
		handlers.Item(p3, "discard", "gear", 1, 1)
		handlers.Item(p3, "move", "use", 1, 999)
		handlers.Item(p3, "move", "bad", 1, 2)
		handlers.Item(p3, "move", "use", "a", { 2 })
		handlers.Item(p3, "sort", 7)
		eq(Bag.count(h3, "potion1"), before - 2, "이상한 요청에는 아무것도 바뀌지 않는다")
		expect(last("ItemDone").ok == false, "안 되는 일은 까닭과 함께 돌아온다")
		run(2) -- 빈도 제한을 넘지 않게
	end
	table.clear(sent)
	handlers.Item(p3, "buy", "dust", 10)
	expect(last("ItemDone").ok == false, "달가루는 상인이 팔지 않는다")
	-- 강화: Lv.8부터, 대장장이 앞에서
	stand("smith")
	h3.dust = 1000
	local wid = h3.equip.weapon.id
	table.clear(sent)
	handlers.Item(p3, "enhance", wid)
	expect(last("ItemDone").ok == false and string.find(last("ItemDone").why, "Lv." .. OPEN.forge) ~= nil, "강화는 Lv.8부터")
	h3.level = OPEN.forge
	stand("merchant")
	table.clear(sent)
	handlers.Item(p3, "enhance", wid)
	expect(last("ItemDone").why == "대장장이 앞이 아니다", "대장장이 앞이 아니면 못 한다")
	stand("smith")
	local got1 = false
	for _ = 1, 40 do
		table.clear(sent)
		handlers.Item(p3, "enhance", wid)
		local done = last("ItemDone")
		if done.ok and done.result == "ok" then
			got1 = true
			break
		end
		run(0.2) -- 빈도 제한을 넘지 않게
	end
	expect(got1 and h3.equip.weapon.star >= 1, "대장장이 앞에서 별을 붙인다")
	handlers.Item(p3, "buy", "dust", 10)
	eq(h3.dust >= 10, true, "대장장이는 달가루를 판다")
	-- 창고: Lv.4부터(지금 Lv.8), 창고지기 앞에서
	local spareHat = Items.make("hat", 1, 3)
	local spareAt = Bag.add(h3, spareHat)
	table.clear(sent)
	handlers.Item(p3, "storeIn", "gear", spareAt)
	expect(last("ItemDone").why == "창고지기 앞이 아니다", "창고지기 앞이 아니면 못 맡긴다")
	stand("keeper")
	handlers.Item(p3, "storeIn", "gear", spareAt, nil, 5)
	expect(Bag.stored(h3) == 1 and h3.store.gear[5] == spareHat and h3.gear[spareAt] == false, "창고의 고른 칸에 맡긴다(끌어다 놓은 칸)")
	handlers.Item(p3, "storeMove", "gear", 5, 2)
	expect(h3.store.gear[2] == spareHat and h3.store.gear[5] == false, "창고 안에서 옮긴다")
	handlers.Item(p3, "storeOut", "gear", 2, nil, spareAt)
	expect(Bag.stored(h3) == 0 and h3.gear[spareAt] == spareHat, "창고에서 가방의 고른 칸으로 찾는다")
	run(2) -- 빈도 제한을 넘지 않게
	-- 소비 · 기타 아이템도 맡긴다(사용자 2026-10-08): 몇 개만 · 전부 · 창고의 탭 정렬
	do
		local useAt = nil
		for i = 1, Bag.size(h3) do
			if h3.use[i] and h3.use[i].item == "potion1" then
				useAt = i
				break
			end
		end
		local have = h3.use[useAt].n
		expect(have >= 3, "맡길 물약이 있다")
		table.clear(sent)
		handlers.Item(p3, "storeIn", "use", useAt, 2)
		expect(last("ItemDone").ok == true and h3.use[useAt].n == have - 2 and h3.store.use[1].item == "potion1" and h3.store.use[1].n == 2, "물약 두 개를 맡긴다")
		local sentBag = got("Bag", p3)
		expect(#sentBag == 1 and sentBag[1].args[1].store.use[1].n == 2 and sentBag[1].args[1].store.gear[1] == false, "창고의 칸들이 탭마다 온다")
		handlers.Item(p3, "storeMove", "use", 1, 9)
		handlers.Item(p3, "storeSort", "use")
		expect(h3.store.use[1] ~= false and h3.store.use[9] == false, "창고의 탭을 정렬한다")
		handlers.Item(p3, "storeOut", "use", 1, 1)
		expect(h3.store.use[1].n == 1 and Bag.count(h3, "potion1") == have - 1, "하나만 찾는다")
		handlers.Item(p3, "storeOut", "use", 1)
		expect(h3.store.use[1] == false and Bag.count(h3, "potion1") == have, "나머지를 전부 찾는다")
		table.clear(sent)
		handlers.Item(p3, "storeIn", "use", useAt, 99999)
		handlers.Item(p3, "storeIn", "bad", 1)
		handlers.Item(p3, "storeOut", "use", 3)
		handlers.Item(p3, "storeMove", "use", 1, 999)
		handlers.Item(p3, "storeSort", { 1 })
		expect(last("ItemDone").ok == false and Bag.count(h3, "potion1") == have and Bag.stored(h3, "use") == 0, "이상한 요청에는 아무것도 바뀌지 않는다")
		run(2)
		-- 묶음 나누기는 어디서나
		handlers.Item(p3, "split", "use", useAt, 1)
		expect(h3.use[useAt].n == have - 1 and Bag.count(h3, "potion1") == have and Bag.used(h3, "use") == 2, "묶음에서 하나를 덜어 새 묶음으로 놓는다")
		handlers.Item(p3, "sort", "use")
		eq(Bag.used(h3, "use"), 1, "정렬하면 다시 합쳐진다")
		-- 상점에 팔기: 상점(잡화 상인 · 대장장이) 앞에서만
		local money0 = h3.money
		table.clear(sent)
		handlers.Item(p3, "sell", "use", 1, 1)
		expect(last("ItemDone").ok == false and last("ItemDone").why == "파는 사람 앞이 아니다" and h3.money == money0, "창고지기 앞에서는 팔지 못한다")
		stand("merchant")
		table.clear(sent)
		handlers.Item(p3, "sell", "use", 1, 2)
		local one = Items.goodsSell("potion1")
		expect(last("ItemDone").ok == true and last("ItemDone").result == 2 * one and h3.money == money0 + 2 * one and Bag.count(h3, "potion1") == have - 2, "상인 앞에서 물약 둘을 판다")
		expect(#got("Bag", p3) == 1 and #got("Self", p3) >= 1, "판 뒤에 가방과 달돈이 다시 온다")
		local junk = Items.make("glove", 10, 2)
		local junkAt = Bag.add(h3, junk)
		run(1.5)
		stand("smith")
		handlers.Item(p3, "sell", "gear", junkAt)
		expect(h3.gear[junkAt] == false and h3.money == money0 + 2 * one + Items.sellPrice(junk), "대장장이도 사 준다(장비)")
		local m2 = h3.money
		handlers.Item(p3, "sell", "gear", junkAt)
		handlers.Item(p3, "sell", "use", 1, 99999)
		handlers.Item(p3, "sell", "bad", 1, 1)
		handlers.Item(p3, "split", "use", 1, 99999)
		handlers.Item(p3, "split", "gear", 1, 1)
		eq(h3.money, m2, "이상한 요청에는 달돈이 늘지 않는다")
		run(2)
	end
	stand("keeper")
	-- 모르는 일 · 이상한 인자
	table.clear(sent)
	handlers.Item(p3, "fly", 1)
	expect(last("ItemDone").ok == false, "모르는 일은 안 된다")
	handlers.Item(p3, "equip", { 1 })
	handlers.Item(p3, "buy", "potion1", -4)
	handlers.Item(p3, "transfer", wid, wid)
	expect(h3.equip.weapon ~= nil, "이상한 요청에도 장비는 그대로다")
	-- 나갔다 들어와도 장비가 그대로
	local star3 = h3.equip.weapon.star
	World.removePlayer(p3)
	local back3 = handlers.Ready(p3)
	expect(back3 ~= nil and back3.bag ~= nil, "다시 들어온다")
	eq(back3.bag.equip.weapon.star, star3, "무기의 별이 그대로")
	eq(back3.bag.equip.hat.q, 5, "낀 모자가 그대로")
end

-- ---- 여럿이: 방 사람들의 이름표 · 자리 · 기술 알림 · 파티(초대 · 받기 · 경험치 나누기 · 나가기) ----
do
	local Hero2 = req("ReplicatedStorage/shared/lune/sim/hero")
	local pa = person({ UserId = 201, Name = "moonA", DisplayName = "달지기" })
	local pb = person({ UserId = 202, Name = "moonB", DisplayName = "月の人" }) -- Roblox의 이름은 어디에도 쓰이지 않는다
	local pc = person({ UserId = 203, Name = "moonC" })
	local function last(name, player)
		local list = got(name, player)
		return list[#list] and list[#list].args
	end
	handlers.Ready(pa)
	table.clear(sent)
	local startA = handlers.Choose(pa, "axion", "달지기")
	expect(startA.room.who ~= nil and #startA.room.who >= 1, "들어올 때 방 사람들의 이름표를 받는다")
	eq(startA.name, "달지기", "내 이름")
	eq(startA.id, 201, "내 번호")
	handlers.Ready(pb)
	handlers.Choose(pb, "riven")
	run(0.1)
	local who = last("Who", pa)
	expect(who ~= nil and who[1] == SCENES.start, "누가 들어오면 방 사람들에게 이름표가 다시 온다")
	local names = {}
	for _, w in who[2] do
		names[w.id] = w.name
	end
	eq(names[201], "달지기", "이름표는 지은 이름이다")
	eq(names[202], "시험202", "둘째 사람도 지은 이름이다(Roblox의 이름이 아니다)")
	-- 자리: 방에 둘 이상 있으면 온다
	table.clear(sent)
	run(0.3)
	local heroes = last("Heroes", pa)
	expect(heroes ~= nil and heroes[1] == SCENES.start and #heroes[2] >= 2, "방 사람들의 자리가 온다")
	-- 파티는 Lv.10부터
	local sa, sb = World.session(pa), World.session(pb)
	table.clear(sent)
	handlers.Party(pa, "invite", 202)
	expect(last("ItemDone", pa)[1].why == "파티는 Lv.10부터 맺는다", "Lv.10 전에는 초대하지 못한다")
	Hero2.gainXp(sa.hero, 20000)
	Hero2.gainXp(sb.hero, 20000)
	expect(sa.hero.level >= 10 and sb.hero.level >= 10, "둘 다 Lv.10을 넘겼다")
	-- 다른 맵에 있는 사람은 초대하지 못한다
	handlers.Ready(pc)
	handlers.Choose(pc, "mooni")
	local sc = World.session(pc)
	Hero2.gainXp(sc.hero, 20000)
	sc.jumped, sc.stale = true, nil
	local gateC
	for _, portal in SCENES.scenes[SCENES.start].portals do
		gateC = portal
	end
	expect(goTo(pc, "hunt") ~= nil, "셋째는 사냥터로")
	table.clear(sent)
	handlers.Party(pa, "invite", 203)
	expect(last("ItemDone", pa)[1].why == "같은 맵에 있는 사람만 초대한다", "다른 맵의 사람은 초대하지 못한다")
	handlers.Party(pa, "invite", 999)
	handlers.Party(pa, "invite", "x")
	-- 초대 → 받기
	run(1.1)
	table.clear(sent)
	handlers.Party(pa, "invite", 202)
	local ask = last("PartyAsk", pb)
	expect(ask ~= nil and ask[1].from == 201 and ask[1].name == "달지기", "초대받은 사람에게 알림이 간다")
	run(1.1)
	handlers.Party(pb, "accept")
	local info = last("PartyInfo", pa)
	expect(info ~= nil and info[1].leader == 201 and #info[1].members == 2, "파티가 생겼다")
	expect(last("PartyInfo", pb) ~= nil, "파티원도 받는다")
	expect(World.sameParty(201, 202) and not World.sameParty(201, 203), "같은 파티인지 안다")
	eq(World.sceneOf(203), "hunt", "어느 맵에 있는지 안다")
	-- 파티원의 체력은 1초에 한 번 다시 온다
	table.clear(sent)
	run(1.1)
	expect(#got("PartyInfo", pa) >= 1, "파티의 모습이 틈틈이 다시 온다")
	-- 함께 사냥: 둘 다 사냥터로 가서 하나가 잡으면 둘 다 경험치를 받는다
	for _, pp in { pa, pb } do
		expect(goTo(pp, "hunt") ~= nil, "사냥터로")
	end
	local room = World.room("hunt")
	local target
	for _, m in room.mobs do
		if m.state ~= "dead" and m.state ~= "gone" and m.state ~= "spawn" then
			target = m
			break
		end
	end
	expect(target ~= nil, "잡을 졸개가 있다")
	sa.hero.invuln, sb.hero.invuln = 999, 999
	sa.jumped, sb.jumped, sb.stale = true, nil, true
	handlers.Move(pa, target.x - 12, target.y, 1)
	handlers.Move(pb, target.x - 30, target.y, 1)
	local xpB, lvB = sb.hero.xp, sb.hero.level
	table.clear(sent)
	local killed = false
	for _ = 1, 60 do
		sa.jumped, sa.stale = true, nil
		handlers.Move(pa, math.clamp(target.x - 12, 8, 1500), target.y, 1)
		castSlam(pa, sa.hero.x, sa.hero.y, 1)
		run(1.2)
		if target.state == "dead" or target.state == "gone" then
			killed = true
			break
		end
	end
	expect(killed, "파티장이 졸개를 잡았다")
	expect(#got("Act", pb) >= 1, "옆 사람에게 기술을 쓴다는 알림이 간다")
	eq(#got("Act", pa), 0, "쓴 사람에게는 가지 않는다")
	expect(sb.hero.xp ~= xpB or sb.hero.level ~= lvB, "잡지 않은 파티원도 경험치를 받는다")
	expect(#got("Gain", pb) >= 1, "파티원에게 경험치 알림이 간다")
	-- 나가기
	table.clear(sent)
	handlers.Party(pb, "leave")
	local after = last("PartyInfo", pa)
	expect(after ~= nil and #after[1].members == 0, "혼자 남으면 파티가 흩어진다")
	expect(not World.sameParty(201, 202), "이제 남남")
	-- 접속을 끊으면 파티에서도 빠진다
	run(1.1)
	handlers.Party(pa, "invite", 202)
	run(1.1)
	handlers.Party(pb, "accept")
	expect(World.sameParty(201, 202), "다시 맺었다")
	table.clear(sent)
	World.removePlayer(pb)
	expect(not World.sameParty(201, 202), "나간 사람은 파티에서 빠진다")
	expect(last("PartyInfo", pa) ~= nil, "남은 사람에게 알린다")
	expect(last("Who", pa) ~= nil, "방 사람들의 이름표에서도 빠진다")
	-- 거절
	handlers.Ready(pb)
	local sb2 = World.session(pb)
	sb2.jumped, sb2.stale = true, nil
	goTo(pb, "hunt")
	run(1.1)
	table.clear(sent)
	handlers.Party(pa, "invite", 202)
	run(1.1)
	handlers.Party(pb, "decline")
	expect(last("ItemDone", pa) ~= nil and string.find(last("ItemDone", pa)[1].why, "거절") ~= nil, "거절하면 초대한 사람이 안다")
	expect(not World.sameParty(201, 202), "거절하면 파티가 안 된다")
end

-- ---- 퀘스트(Quest): 주민 앞에서 받고, 잡으면 세고, 주민 앞에서 돌려준다 ----
do
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local pq = person({ UserId = 301, Name = "questor" })
	handlers.Ready(pq)
	local start = handlers.Choose(pq, "axion")
	expect(start.quests ~= nil and start.quests.r1m1 == nil, "새 캐릭터는 받은 퀘스트 없이 시작한다(첫 메인도 사제에게 말을 걸어 받는다)")
	local sq = World.session(pq)
	local hq = sq.hero
	local function last(name)
		local list = got(name, pq)
		return list[#list] and list[#list].args
	end
	-- 주민 앞에 선다: 건물 안의 주민이면 그 문으로 들어간다
	local function at(id)
		for _, key in NPC_ORDER do
			local sc = SCENES.scenes[key]
			for _, n in sc.npcs or {} do
				if n.id == id then
					goTo(pq, key)
					eq(sq.scene, key, "주민이 있는 곳으로 간다 " .. id)
					sq.jumped, sq.stale = true, nil
					hq.x, hq.y = n.x + 8, n.y
					return
				end
			end
		end
		error("없는 주민 " .. id)
	end
	-- 사제 앞이 아니면 돌려주지 못한다
	at("guide")
	table.clear(sent)
	handlers.Quest(pq, "complete", "r1m1")
	expect(last("ItemDone")[1].why == "돌려줄 사람 앞이 아니다", "멀리서는 돌려주지 못한다")
	-- 받는 것도 주는 사람 앞에서만
	table.clear(sent)
	handlers.Quest(pq, "accept", "r1m1")
	expect(last("ItemDone")[1].why == "퀘스트를 주는 사람 앞이 아니다" and hq.quests.r1m1 == nil, "멀리서는 받지 못한다")
	at("master")
	-- 받지 않은 퀘스트는 돌려주지 못한다 → 사제에게 말을 걸어 받는다(저절로 받지 않는다 — 사용자 2026-10-11) → 할 일이 없어 바로 돌려줄 수 있다
	table.clear(sent)
	handlers.Quest(pq, "complete", "r1m1")
	expect(last("ItemDone")[1].ok == false and hq.quests.r1m1 == nil, "받지 않은 퀘스트는 돌려주지 못한다")
	table.clear(sent)
	handlers.Quest(pq, "accept", "r1m1")
	local q0 = last("Quests")
	expect(q0 ~= nil and q0[1].r1m1 ~= nil and q0[1].r1m1.done == false and q0[2] == nil, "사제 앞에서 첫 메인을 받는다")
	eq(Quests.state(hq.quests, hq.level, "r1m1"), "ready", "할 일이 없어 받자마자 돌려줄 수 있다")
	local money0 = hq.money
	table.clear(sent)
	handlers.Quest(pq, "complete", "r1m1")
	local q1 = last("Quests")
	expect(q1 ~= nil and q1[1].r1m1.done == true and q1[2] == "r1m1", "사제 앞에서 첫 메인을 끝낸다")
	expect(hq.money > money0 and hq.level >= 2, "보상(달돈 · 경험치)을 받는다")
	expect(last("Gain")[1].quest == "첫 기술", "경험치 알림에 퀘스트 이름이 온다")
	-- 받기: 주는 사람 앞에서
	at("master")
	table.clear(sent)
	handlers.Quest(pq, "accept", "r1m2")
	expect(last("ItemDone")[1].why == "퀘스트를 주는 사람 앞이 아니다", "멀리서는 받지 못한다")
	at("guide")
	handlers.Quest(pq, "accept", "r1m2")
	eq(Quests.state(hq.quests, hq.level, "r1m2"), "active", "샛별 앞에서 받는다")
	handlers.Quest(pq, "accept", "r1m4")
	handlers.Quest(pq, "accept", 7)
	handlers.Quest(pq, "fly", "r1m2")
	-- 마을 어귀에서 수습 검병을 잡으면 센다
	local defQ = Quests.def("r1m2")
	expect(goTo(pq, defQ.scene) ~= nil, "퀘스트의 맵(마을 어귀)으로")
	hq.invuln = 9999
	local room = World.room(defQ.scene)
	local killed = 0
	for _ = 1, 400 do
		if Quests.state(hq.quests, hq.level, "r1m2") == "ready" then
			break
		end
		local target
		for _, m in room.mobs do
			if m.kind == defQ.steps[1].mob and m.state ~= "dead" and m.state ~= "gone" and m.state ~= "spawn" then
				target = m
				break
			end
		end
		if target then
			sq.jumped, sq.stale = true, nil
			handlers.Move(pq, math.clamp(target.x - 12, 8, 1500), target.y, 1)
			castSlam(pq, hq.x, hq.y, 1)
			run(1.2)
			if target.state == "dead" or target.state == "gone" then
				killed += 1
			end
		else
			run(1)
		end
	end
	eq(Quests.state(hq.quests, hq.level, "r1m2"), "ready", ("수습 검병 다섯을 잡았다(잡은 수 %d)"):format(killed))
	expect(#got("Quests", pq) >= 5, "잡을 때마다 퀘스트의 상태가 온다")
	-- 돌려주기는 마을의 샛별에게
	table.clear(sent)
	handlers.Quest(pq, "complete", "r1m2")
	expect(last("ItemDone")[1].ok == false, "마을 밖에서는 돌려주지 못한다")
	expect(goTo(pq, SCENES.start) ~= nil, "마을로")
	at("guide")
	handlers.Quest(pq, "complete", "r1m2")
	eq(Quests.state(hq.quests, hq.level, "r1m2"), "done", "샛별에게 돌려준다")
	eq(Quests.mark(hq.quests, 4, "elder"), "!", "다음 메인(빈 갑옷)은 Lv.4가 되면 촌장에게서")
	eq(Quests.mark(hq.quests, 3, "elder"), nil, "Lv.3에는 아직 표시가 없다")
	-- 모으는 퀘스트의 물건은 가방의 기타 탭에 들어가는 진짜 아이템이다 — 가방에 든 수가 곧 퀘스트의 숫자(사용자 2026-10-08)
	do
		local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
		local def3 = Quests.def("r1m3")
		local step3 = def3.steps[1]
		local item = step3.item
		expect(typeof(item) == "string" and req("ReplicatedStorage/shared/lune/sim/items").goods(item) ~= nil, "모으는 물건은 아이템 목록에 있다")
		hq.level = math.max(hq.level, def3.lv)
		at("elder")
		handlers.Quest(pq, "accept", "r1m3")
		eq(Quests.state(hq.quests, hq.level, "r1m3"), "active", "촌장에게서 빈 갑옷을 받는다")
		local room3 = World.room(sq.scene)
		local function dropOne()
			return room3:addDrop({ kind = "quest", amount = 1, quest = "r1m3", step = 1, name = step3.name, icon = step3.icon, goods = item }, hq.x, hq.y, hq.id)
		end
		table.clear(sent)
		handlers.Pickup(pq, dropOne().id)
		eq(Bag.count(hq, item), 1, "주운 물건이 가방의 기타 탭에 들어온다")
		expect(hq.etc[1] ~= false and hq.etc[1].item == item and hq.etc[1].n == 1, "기타 탭 첫 칸의 묶음")
		eq(hq.quests.r1m3.c[1], 1, "가방에 든 수가 퀘스트의 숫자다")
		expect(#got("Quests", pq) == 1 and #got("Bag", pq) == 1, "퀘스트와 가방이 함께 온다")
		run(0.3)
		handlers.Pickup(pq, dropOne().id)
		run(0.3)
		handlers.Pickup(pq, dropOne().id)
		eq(hq.etc[1].n, 3, "같은 것은 한 칸에 겹친다")
		eq(hq.quests.r1m3.c[1], 3, "셋을 모았다")
		-- 버리면 숫자도 준다
		table.clear(sent)
		handlers.Item(pq, "discard", "etc", 1, 1)
		eq(Bag.count(hq, item), 2, "하나를 버렸다")
		eq(hq.quests.r1m3.c[1], 2, "버리면 퀘스트의 숫자도 준다")
		expect(#got("Quests", pq) == 1, "퀘스트의 상태가 다시 온다")
		-- 기타 탭이 가득 차면 줍지 못하고 물건은 땅에 남는다
		local keep = table.clone(hq.etc)
		for i = 2, Bag.size(hq) do
			hq.etc[i] = { item = "etc_cloth", n = 9999 }
		end
		hq.etc[1].n = 9999
		local stuck = dropOne()
		run(0.3)
		table.clear(sent)
		handlers.Pickup(pq, stuck.id)
		expect(last("ItemDone") ~= nil and last("ItemDone")[1].why == Bag.FULL, "가방이 가득 차면 까닭이 온다")
		expect(room3.drops[stuck.id] ~= nil, "줍지 못한 물건은 땅에 남는다")
		hq.etc = keep
		hq.etc[1] = { item = item, n = 2 }
		-- 다 모아 돌려주면 모은 만큼 가방에서 빠진다
		Bag.give(hq, item, step3.n) -- 넉넉히(모을 수보다 둘 많다)
		run(0.3)
		handlers.Item(pq, "sort", "etc") -- 가방을 건드리면 숫자가 맞춰진다
		eq(hq.quests.r1m3.c[1], step3.n, "모을 수를 넘게 가져도 숫자는 모을 수까지")
		eq(Quests.state(hq.quests, hq.level, "r1m3"), "ready", "다 모았다")
		table.clear(sent)
		handlers.Quest(pq, "complete", "r1m3")
		eq(Quests.state(hq.quests, hq.level, "r1m3"), "done", "촌장에게 돌려준다")
		eq(Bag.count(hq, item), 2, "모을 수만큼만 가방에서 빠진다(남은 둘은 그대로)")
		expect(#got("Bag", pq) >= 1, "돌려주면 가방이 다시 온다")
	end
	-- 맵에 놓인 것 앞에서 ↑를 누르는 퀘스트(2026-10-11): 「할아버지의 옛이야기」 — 고갯마루 노인에게 받아, 무너진 다리의 샘 앞에서 ↑, 노인에게 돌려준다
	do
		local defU = nil
		for _, d in req("ReplicatedStorage/shared/lune/data/quests.generated").list do
			if d.name == "할아버지의 옛이야기" then
				defU = d
			end
		end
		expect(defU ~= nil and defU.playable and defU.steps[1].type == "use", "「할아버지의 옛이야기」는 ↑를 누르는 퀘스트다")
		local stepU = defU.steps[1]
		hq.level = math.max(hq.level, defU.lv)
		at(defU.giver)
		handlers.Quest(pq, "accept", defU.id)
		eq(Quests.state(hq.quests, hq.level, defU.id), "active", "노인에게 받는다")
		expect(goTo(pq, defU.scene) ~= nil, "무너진 다리로")
		sq.jumped, sq.stale = true, nil
		hq.x, hq.y = stepU.x + 120, stepU.y
		table.clear(sent)
		handlers.Quest(pq, "use", defU.id)
		expect(last("ItemDone") ~= nil and last("ItemDone")[1].why == "그 자리 앞이 아니다", "멀리서는 물을 뜨지 못한다")
		eq(hq.quests[defU.id].c[1] or 0, 0, "숫자는 그대로")
		hq.x, hq.y = stepU.x - 12, stepU.y
		table.clear(sent)
		handlers.Quest(pq, "use", defU.id)
		local qu = last("Quests")
		expect(qu ~= nil and qu[1][defU.id].c[1] == 1 and qu[1][defU.id].done == false, "샘 앞에서 ↑ — 숫자가 올라 화면으로 간다")
		eq(Quests.state(hq.quests, hq.level, defU.id), "ready", "돌려주러 간다")
		table.clear(sent)
		handlers.Quest(pq, "use", defU.id)
		expect(hq.quests[defU.id].c[1] == 1 and last("ItemDone")[1].why == "여기서 할 일이 없다", "한 번 더 눌러도 더 오르지 않는다")
		at(defU.endNpc)
		local moneyU = hq.money
		handlers.Quest(pq, "complete", defU.id)
		eq(Quests.state(hq.quests, hq.level, defU.id), "done", "노인에게 돌려준다")
		expect(hq.money > moneyU, "달돈을 받는다")
	end
	-- 나갔다 들어와도 그대로
	World.removePlayer(pq)
	local again = handlers.Ready(pq)
	expect(again.quests.r1m2 ~= nil and again.quests.r1m2.done == true, "끝낸 퀘스트가 그대로")
	expect(again.bag.etc[1] ~= false and again.bag.etc[1].n == 2, "가방의 기타 아이템도 그대로(놓인 칸까지)")
end

-- ---- 1차의 장치: 사출기를 켜고 끄기 · 힘 모으기(패킷으로) ----
do
	local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
	local pk = person({ UserId = 401, Name = "kit" })
	handlers.Ready(pk)
	handlers.Choose(pk, "axion")
	goTo(pk, "hunt")
	local sk = World.session(pk)
	local hk = sk.hero
	local roomK = World.room("hunt")
	-- 배우기 전: 사출기의 패킷은 아무 일도 하지 않는다
	table.clear(sent)
	handlers.Skill(pk, "ax_echo", 1, hk.x, hk.y, 1)
	eq(hk.kit.on, false, "배우지 않은 사출기는 켜지지 않는다")
	eq(#got("Self", pk), 0, "배우지 않은 사출기: 돌려줄 것이 없다")
	-- 배우면: 누를 때마다 켜지고 꺼지고, 내 상태가 돌아온다
	hk.skills.ax_echo = 1
	handlers.Skill(pk, "ax_echo", 1, hk.x, hk.y, 1)
	eq(hk.kit.on, true, "사출기를 켠다")
	local selfs = got("Self", pk)
	expect(#selfs == 1 and selfs[1].args[1].kit.on == true, "켠 것이 내 상태로 돌아온다")
	expect(sk.skill == nil, "사출기를 켜는 것은 기술을 쓰는 것이 아니다(동작 · 다시 쓰기가 없다)")
	handlers.Skill(pk, "ax_echo", 1, hk.x, hk.y, 1)
	eq(hk.kit.on, false, "한 번 더 누르면 꺼진다")
	-- 남의 직업의 사출기는 켜지지 않는다
	hk.skills.rv_star = 1
	handlers.Skill(pk, "rv_star", 1, hk.x, hk.y, 1)
	eq(hk.kit.on, false, "남의 직업의 사출기")
	hk.skills.rv_star = nil

	-- 힘 모으기: 같은 졸개를 그냥 친 것과 끝까지 모아 친 것. 모은 단계는 서버가 흐른 시간으로 셈한다
	local slamK = COMBAT.skills.ax_slam
	-- 졸개 하나만 곁에 세워 두고(쓰러지지 않게 체력을 넉넉히) 나머지는 멀리 치운다
	local foeK = roomK.mobs[1]
	local function place()
		for i, m in roomK.mobs do
			m.state, m.t = "idle", 0
			m.a, m.b = 0, 4000
			m.hp, m.maxHp = 1e12, 1e12
			m.x, m.y = hk.x + 1200 + i * 30, hk.y
		end
		foeK.x = hk.x + 20
		hk.hp, hk.alive, hk.invuln = hk.maxHp, true, 5
	end
	local function slamDamage(hold)
		place()
		table.clear(sent)
		castSlam(pk, hk.x, hk.y, 1, hold)
		run(slamK.time + 0.3)
		local sum, n = 0, 0
		for _, e in got("Hits", pk) do
			for _, h in e.args[2] do
				if h.mob == foeK.id then
					sum += h.dmg
					n += 1
				end
			end
		end
		run(1) -- 다음 것을 쓸 수 있을 때까지
		return sum, n
	end
	-- 배우기 전에는 오래 눌러도 그대로(늦게 뗀 것은 받지 않는다)
	local per = Kit.data.axion.core.per.ax_slam
	local levels = Kit.data.axion.core.levels
	eq(Kit.chargeTime(hk, "ax_slam"), 0, "배우기 전에는 모을 수 없다")
	hk.skills.ax_charge = 10
	eq(Kit.chargeTime(hk, "ax_slam"), per * levels, "끝까지 모으는 시간")
	-- 피해는 조금씩 흔들린다(roll) — 여러 번 쳐서 가장 큰 것끼리 견준다
	local plain, full, half = 0, 0, 0
	for _ = 1, 12 do
		local a, an = slamDamage(0)
		local b, bn = slamDamage(per * levels + 0.05)
		local c = slamDamage(per + 0.05)
		expect(an >= 1 and bn >= 1, "강타가 맞는다 " .. an .. " " .. bn)
		plain, full, half = math.max(plain, a), math.max(full, b), math.max(half, c)
	end
	local _, mulFull = Kit.charge(hk, "ax_slam", per * levels)
	local _, mulHalf = Kit.charge(hk, "ax_slam", per)
	expect(mulFull > mulHalf and mulHalf > 1, "모을수록 세다 " .. mulHalf .. " " .. mulFull)
	expect(full > plain * (mulFull - 0.25) and full < plain * (mulFull + 0.25), ("끝까지 모은 강타는 그 배수만큼 세다 %d → %d (x%.2f)"):format(plain, full, mulFull))
	expect(half > plain * (mulHalf - 0.2) and half < plain * (mulHalf + 0.2), ("한 단계 모은 강타 %d → %d (x%.2f)"):format(plain, half, mulHalf))
	-- 끝까지 모으는 시간을 한참 넘겨 뗀 것은 받지 않는다(내려찍기가 나가지 않는다)
	place()
	table.clear(sent)
	castSlam(pk, hk.x, hk.y, 1, per * levels + 1)
	run(slamK.time + 0.3)
	eq(#got("Hits", pk), 0, "너무 늦게 뗀 강타는 나가지 않는다")
	World.removePlayer(pk)
end

-- ---- 확인용 임시 캐릭터(Studio의 LuneGuest): 내 저장을 읽지도 쓰지도 지우지도 않는다 ----
do
	local pg = person({ UserId = 501, Name = "owner" })
	handlers.Ready(pg)
	handlers.Choose(pg, "axion")
	World.removePlayer(pg)
	local kept = disk[501]
	expect(kept ~= nil, "내 캐릭터가 저장돼 있다")
	local realGuest = World.guest
	eq(realGuest(), nil, "평소에는 임시 캐릭터가 아니다")
	World.guest = function()
		return "riven"
	end
	local first = handlers.Ready(pg)
	local sg = World.session(pg)
	eq(sg.guest, true, "임시 캐릭터로 들어왔다")
	eq(first.self.class, "riven", "고른 직업의 캐릭터다")
	expect(first.self.level >= 10, "레벨이 올라 있다 " .. first.self.level)
	eq(first.self.skills.rv_star, COMBAT.kitSkill.rv_star.max, "1차 스킬을 마스터했다(사출기)")
	eq(first.self.skills.rv_fan, COMBAT.skills.rv_fan.max, "1차 스킬을 마스터했다(주력기)")
	eq(first.self.slots[7], "rv_star", "사출기가 퀵슬롯에 놓여 있다")
	-- 바뀌어도 · 틈틈이 저장해도 · 지우라고 해도 · 나가도 내 저장은 그대로다
	handlers.Skill(pg, "rv_star", 1, sg.hero.x, sg.hero.y, 1)
	eq(sg.hero.kit.on, true, "임시 캐릭터로 사출기를 켠다")
	World.saveAll(false)
	handlers.Debug(pg, "reset", 0)
	expect(sg.hero ~= nil, "임시 캐릭터로는 나가기(reset)가 듣지 않는다")
	eq(handlers.Chars(pg, "leave"), nil, "임시 캐릭터에게는 고르기 화면이 없다")
	World.removePlayer(pg)
	expect(disk[501] == kept, "내 저장은 그대로다 — 임시 캐릭터는 한 번도 저장하지 않는다(저장했다면 새 표로 바뀐다)")
	-- 속성을 지우고 다시 들어오면 내 캐릭터다
	World.guest = realGuest
	local again = handlers.Ready(pg)
	eq(again.self.class, "axion", "다시 들어오면 내 캐릭터다")
	eq(World.session(pg).guest, nil, "임시 캐릭터가 아니다")
	World.removePlayer(pg)
end

-- ---- 버프: 거는 패킷 · 다시 쓰기 · 방의 사람들에게 알림 · 공격 속도 ----
do
	local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
	local realGuest = World.guest
	World.guest = function()
		return "axion", 120
	end
	local pb = person({ UserId = 601, Name = "buffer" })
	local first = handlers.Ready(pb)
	World.guest = realGuest
	eq(first.self.job, 4, "Lv.120은 4차")
	eq(first.self.skills.ax_fullmoon, COMBAT.buffs.ax_fullmoon.max, "임시 캐릭터는 열린 차수의 스킬을 모두 마스터했다")
	expect(first.self.buffs ~= nil and #first.self.buffs.list == 0, "처음에는 걸린 버프가 없다")
	eq(first.self.haste, 1, "공격 속도 그대로")
	local sb = World.session(pb)
	local hb = sb.hero
	-- 옆에 다른 사람(같은 방): 걸리는 순간과 걸린 버프를 본다
	local po = person({ UserId = 602, Name = "watcher" })
	handlers.Ready(po)
	if not World.session(po).hero then
		handlers.Choose(po, "riven")
	end
	eq(World.session(po).scene, sb.scene, "같은 방에 있다")
	table.clear(sent)
	handlers.Skill(pb, "ax_breath", 1, hb.x, hb.y, 1)
	expect(Buffs.has(hb, "ax_breath"), "전투 호흡이 걸렸다")
	local selfs = got("Self", pb)
	expect(#selfs >= 1 and selfs[#selfs].args[1].buffs.list[1].id == "ax_breath", "걸린 버프가 내 상태로 온다")
	expect(math.abs(selfs[#selfs].args[1].haste - 1.25) < 1e-6, "공격 속도 +25%가 내 상태로 온다")
	expect(#got("Act", po) == 1 and got("Act", po)[1].args[2] == "ax_breath", "방의 다른 사람에게 걸리는 순간이 간다")
	expect(#got("Buffs", po) == 1 and got("Buffs", po)[1].args[2][1].id == "ax_breath", "방의 다른 사람에게 걸린 버프가 간다")
	eq(#got("Buffs", pb), 0, "나에게는 Buffs가 오지 않는다(내 상태로 온다)")
	-- 극딜: 다시 쓰기 중에는 걸리지 않는다
	handlers.Skill(pb, "ax_fullmoon", 1, hb.x, hb.y, 1)
	expect(Buffs.has(hb, "ax_fullmoon"), "만월이 걸렸다")
	table.clear(sent)
	run(31)
	eq(Buffs.has(hb, "ax_fullmoon"), false, "30초 뒤에 사라진다")
	expect(#got("Self", pb) >= 1, "사라지면 내 상태가 다시 온다")
	expect(#got("Buffs", po) >= 1, "사라지면 방의 사람들에게도 알린다")
	table.clear(sent)
	handlers.Skill(pb, "ax_fullmoon", 1, hb.x, hb.y, 1)
	eq(Buffs.has(hb, "ax_fullmoon"), false, "다시 쓰기 중에는 걸리지 않는다")
	eq(#got("Act", po), 0, "걸리지 않았으면 알리지 않는다")
	-- 공격 속도: 전투 호흡 동안 타격이 그만큼 빨리 맞는다
	goTo(pb, "hunt")
	local roomB = World.room("hunt")
	local foe = roomB.mobs[1]
	local function firstHitAfter()
		for i, m in roomB.mobs do
			m.state, m.t, m.a, m.b = "idle", 0, 0, 4000
			m.hp, m.maxHp = 1e12, 1e12
			m.x, m.y = hb.x + 1200 + i * 30, hb.y
		end
		foe.x = hb.x + 20
		hb.hp, hb.alive, hb.invuln = hb.maxHp, true, 30
		run(2)
		foe.x, foe.state = hb.x + 20, "idle"
		-- 대지 강타의 내려찍기: 구간이 시작된 뒤 0.167초에 맞는다(공격 속도 +25%면 0.133초 — 서버의 한 걸음 0.05초로도 갈린다)
		handlers.Skill(pb, "ax_slam", 1, hb.x, hb.y, 1)
		run(COMBAT.skills.ax_slam.segs[1].time)
		table.clear(sent)
		handlers.Skill(pb, "ax_slam", 2, hb.x, hb.y, 1)
		local t = 0
		while #got("Hits", pb) == 0 and t < 2 do
			World.tick(TICK)
			t += TICK
		end
		run(1.5)
		return t
	end
	table.clear(hb.buffs) -- 앞에서 건 전투 호흡이 아직 남아 있다 — 버프가 없을 때부터 잰다
	local slow = firstHitAfter()
	handlers.Skill(pb, "ax_breath", 1, hb.x, hb.y, 1)
	expect(Buffs.has(hb, "ax_breath"), "전투 호흡을 다시 건다")
	local fast = firstHitAfter()
	expect(fast < slow - 0.01, ("전투 호흡 동안 타격이 더 빨리 맞는다 %.2f → %.2f"):format(slow, fast))
	World.removePlayer(pb)
	World.removePlayer(po)
end

-- ---- 2~4차의 쓰는 스킬(sim/caster.luau): 거는 패킷 · 구간 · 다시 쓰기 · 방의 사람들에게 알림 · 멀리 간 자리 ----
do
	local Kitset = req("ReplicatedStorage/shared/lune/kitset")
	local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local function near(x, y, tol, msg)
		expect(math.abs(x - y) <= tol * math.max(1, math.abs(y)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(y), tostring(x)))
	end
	local realGuest = World.guest
	World.guest = function()
		return "axion", 120, "cast"
	end
	local pc = person({ UserId = 701, Name = "caster" })
	local first = handlers.Ready(pc)
	World.guest = realGuest
	eq(first.self.slots[2], "ax_rend", "임시 캐릭터(cast): 2~4차의 스킬이 칸에 놓여 있다")
	local sc = World.session(pc)
	local hc = sc.hero
	for id in COMBAT.passive do
		hc.skills[id] = nil -- 패시브가 얹는 것은 따로 본다(22_lune_passives.luau) — 여기서는 스킬 그대로의 피해를 잰다
	end
	local pw = person({ UserId = 702, Name = "watcher2" })
	handlers.Ready(pw)
	if not World.session(pw).hero then
		handlers.Choose(pw, "riven")
	end
	-- 사냥터로 옮겨 적 하나를 앞에 세운다
	local scene = goTo(pc, "hunt")
	goTo(pw, "hunt")
	expect(scene ~= nil and sc.scene == "hunt", "사냥터")
	local room = World.room("hunt")
	local foe = room.mobs[1]
	local function place()
		for i, m in room.mobs do
			m.state, m.t, m.a, m.b = "idle", 0, 0, 4000
			m.hp, m.maxHp = 1e12, 1e12
			m.x, m.y = hc.x + 1200 + i * 30, hc.y
		end
		foe.x, foe.state = hc.x + 20, "idle"
		hc.hp, hc.alive, hc.invuln = hc.maxHp, true, 60
	end
	place()
	run(1)
	place()
	table.clear(sent)
	-- 쪼개기: 두 구간(같은 동작 두 번)이 차례로 온다 — 구간마다 한 타
	local segs = Kitset.skill("ax_rend").segs
	local T1 = Caster.segTime("axion", segs[1])
	handlers.Skill(pc, "ax_rend", 2, hc.x, hc.y, 1)
	run(0.3)
	eq(#got("Hits", pc), 0, "둘째 구간부터 시작하지 못한다")
	handlers.Skill(pc, "ax_rend", 1, hc.x, hc.y, 1)
	expect(#got("Act", pw) == 1 and got("Act", pw)[1].args[2] == "ax_rend" and got("Act", pw)[1].args[3] == 1, "방의 다른 사람에게 그 구간이 간다")
	handlers.Skill(pc, "ax_slam", 1, hc.x, hc.y, 1)
	run(T1)
	eq(#got("Hits", pc), 1, "첫 구간의 한 타(그동안 1차 기술은 못 쓴다)")
	handlers.Skill(pc, "ax_rend", 2, hc.x, hc.y, 1)
	run(T1 + 0.2)
	eq(#got("Hits", pc), 2, "둘째 구간의 한 타")
	eq(#got("Act", pw), 2, "둘째 구간도 방에 알린다")
	near(foe.rend, 5, 0.1, "갈라짐이 걸렸다")
	-- 피해: 두 타의 합 = 설계의 피해(보스기는 보스가 아니면 보정이 없다 · 둘째 타는 갈라진 적이라 +20%)
	local p = Caster.profile("ax_rend", 0)
	local a, b = got("Hits", pc)[1].args[2][1].dmg, got("Hits", pc)[2].args[2][1].dmg
	local unit = Hero.powerRaw(hc) * COMBAT.cast.ax_rend.rate * p.time * COMBAT.rules.dmgScale / p.w
	near(a, unit * 6, 0.11, "첫 타 = 몫 6")
	near(b, unit * 8 * 1.2, 0.11, "둘째 타 = 몫 8 x 갈라짐")
	-- 다시 쓰기: 달빛 기둥(60초)
	run(1)
	place()
	table.clear(sent)
	handlers.Skill(pc, "ax_pillars", 1, hc.x, hc.y, 1)
	run(2.5)
	local n = #got("Hits", pc)
	expect(n >= 2, "달빛 기둥이 맞았다 " .. n)
	expect((hc.cds.ax_pillars or 0) > World.now + 50, "다시 쓰기 60초가 걸렸다")
	handlers.Skill(pc, "ax_pillars", 1, hc.x, hc.y, 1)
	run(2.5)
	eq(#got("Hits", pc), n, "다시 쓰기 중에는 나가지 않는다")
	-- 남의 직업의 스킬 · 배우지 않은 스킬
	table.clear(sent)
	handlers.Skill(pc, "rv_kill", 1, hc.x, hc.y, 1)
	hc.skills.ax_moonfall = 0
	handlers.Skill(pc, "ax_moonfall", 1, hc.x, hc.y, 1)
	run(1.5)
	eq(#got("Hits", pc), 0, "남의 직업 · 배우지 않은 스킬은 버린다")
	eq(#got("Act", pw), 0, "방에도 알리지 않는다")
	-- 멀리 간 자리: 평소에는 받지 않고 화면을 되돌린다(Warp) · 2~4차의 스킬을 쓴 직후에는 받는다(순간이동 · 돌진)
	run(3)
	-- 맵의 시작 자리에서 먼 곳으로 걸어가 둔다(시작 자리로 온 보고는 늘 받는다 — 떨어졌다 돌아온 것)
	local far = SCENES.scenes.hunt.spawn.x + 400
	while math.abs(hc.x - far) > 1 do
		handlers.Move(pc, hc.x + math.clamp(far - hc.x, -60, 60), hc.y, 1)
	end
	table.clear(sent)
	local x0 = hc.x
	handlers.Move(pc, x0 + 200, hc.y, 1)
	eq(hc.x, x0, "멀리 간 자리는 받지 않는다")
	expect(#got("Warp", pc) == 1 and got("Warp", pc)[1].args[1] == x0, "화면을 서버가 아는 자리로 되돌린다")
	handlers.Move(pc, x0 + 200, hc.y, 1)
	eq(#got("Warp", pc), 1, "되돌리라는 말은 잠깐에 한 번만 보낸다")
	handlers.Move(pc, x0 + 30, hc.y, 1)
	eq(hc.x, x0 + 30, "가까운 자리는 받는다")
	place()
	handlers.Skill(pc, "ax_execute", 1, hc.x, hc.y, 1)
	local x1 = hc.x
	handlers.Move(pc, x1 + 200, hc.y, 1)
	eq(hc.x, x1 + 200, "스킬을 쓴 직후에는 멀리 간 자리도 받는다")
	handlers.Move(pc, x1 + 800, hc.y, 1)
	eq(hc.x, x1 + 200, "그래도 너무 멀면 받지 않는다")
	run(2)
	handlers.Move(pc, hc.x + 200, hc.y, 1)
	eq(hc.x, x1 + 200, "조금 지나면 다시 받지 않는다")
	World.removePlayer(pc)
	World.removePlayer(pw)
end

-- ---- 2~4차의 패시브 가운데 서버가 때를 보는 것: 충격파(끝까지 모아 친 대지 강타가 한 번 더) · 넘치는 힘 · 꺼지지 않는 불 ----
do
	local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
	local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
	local realGuest = World.guest
	World.guest = function()
		return "axion", 120
	end
	local pp = person({ UserId = 801, Name = "passive" })
	handlers.Ready(pp)
	World.guest = realGuest
	local sp = World.session(pp)
	local hp = sp.hero
	goTo(pp, "hunt")
	local room = World.room("hunt")
	local foe = room.mobs[1]
	local function place()
		for i, m in room.mobs do
			m.state, m.t, m.a, m.b = "idle", 0, 0, 4000
			m.hp, m.maxHp = 1e12, 1e12
			m.x, m.y = hp.x + 1200 + i * 30, hp.y
		end
		foe.x, foe.state = hp.x + 20, "idle"
		hp.hp, hp.alive, hp.invuln = hp.maxHp, true, 60
	end
	-- 대지 강타를 hold초 모아 치고, 그 적이 맞은 횟수와 피해의 합을 센다
	local function slam(hold: number): (number, number)
		place()
		run(1.5)
		place()
		table.clear(sent)
		castSlam(pp, hp.x, hp.y, 1, hold)
		run(1.6)
		local n, sum = 0, 0
		for _, e in got("Hits", pp) do
			for _, h in e.args[2] do
				if h.mob == foe.id and not h.proc then
					n += 1
					sum += h.dmg
				end
			end
		end
		return n, sum
	end
	for id in COMBAT.passive do
		hp.skills[id] = nil
	end
	hp.kit.on = false
	hp.skills.ax_charge = 10
	local full = Kit.chargeTime(hp, "ax_slam") + 0.05
	-- 피해는 타마다 ±10% 흩어진다 — 여러 번 쳐서 합으로 견준다
	local function many(times: number): (number, number)
		local n, sum = 0, 0
		for _ = 1, times do
			local c, d = slam(full)
			n, sum = c, sum + d
		end
		return n, sum
	end
	local n0, d0 = many(12)
	eq(n0, 2, "끝까지 모은 대지 강타: 가운데 타 + 가시")
	-- 충격파
	hp.skills.ax_shock = 10
	local n1, d1 = many(12)
	eq(n1, 3, "충격파: 땅을 따라 한 번 더")
	expect(math.abs(d1 / d0 - (1 + COMBAT.passive.ax_shock.fx.shock)) < 0.06, ("충격파의 피해 = 그 타의 40%% (%.2f)"):format(d1 / d0))
	local nTap = slam(0)
	eq(nTap, 2, "모으지 않은 강타에는 충격파가 없다")
	hp.skills.ax_shock = nil
	-- 넘치는 힘: 끝까지 모은 강타를 맞힌 직후(3초 안)의 강타는 모으지 않아도 2단계다
	local _, tap = slam(0)
	hp.skills.ax_charge3 = 10
	slam(full)
	expect(hp.pass.surge > room.time, "넘치는 힘이 켜졌다")
	place()
	table.clear(sent)
	castSlam(pp, hp.x, hp.y, 1, 0)
	run(1.6)
	local surged = 0
	for _, e in got("Hits", pp) do
		for _, h in e.args[2] do
			if h.mob == foe.id and not h.proc then
				surged += h.dmg
			end
		end
	end
	local _, mul = Kit.chargeAt(hp, 2)
	mul = Kit.chargeAt(hp, 2)
	expect(math.abs(surged / tap - mul) < 0.15 * mul, ("모으지 않아도 2단계의 피해가 나간다 (%.2f, 기대 %.2f)"):format(surged / tap, mul))
	expect(hp.pass.surge < room.time, "한 번 쓰면 사라진다")
	-- 꺼지지 않는 불(살라맨더): 폭주가 끝나면 열기가 50에서 시작한다
	World.guest = function()
		return "salamander", 120
	end
	local ps = person({ UserId = 802, Name = "ember" })
	handlers.Ready(ps)
	World.guest = realGuest
	local hs = World.session(ps).hero
	hs.kit.heat = 0
	handlers.Skill(ps, "sl_overheat", 1, hs.x, hs.y, 1)
	expect(Buffs.has(hs, "sl_overheat"), "폭주를 건다")
	hs.buffs.sl_overheat.t = 0.2
	hs.kit.heat = 0
	run(0.5)
	eq(Buffs.has(hs, "sl_overheat"), false, "폭주가 끝났다")
	eq(hs.kit.heat, COMBAT.passive.sl_embers.fx.keep, "꺼지지 않는 불: 열기 50이 남는다")
	World.removePlayer(pp)
	World.removePlayer(ps)
end

-- ---- 소생(무니 4차): 쓰러져 비석이 선 파티원을 그 자리에서 일으킨다 ----
do
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local realGuest = World.guest
	World.guest = function()
		return "mooni", 120
	end
	local pm = person({ UserId = 901, Name = "healer" })
	handlers.Ready(pm)
	World.guest = function()
		return "axion", 120
	end
	local pf = person({ UserId = 902, Name = "fallen" })
	handlers.Ready(pf)
	World.guest = realGuest
	local sm, sf = World.session(pm), World.session(pf)
	local hm, hf = sm.hero, sf.hero
	goTo(pm, "hunt")
	goTo(pf, "hunt")
	local room = World.room("hunt")
	for i, m in room.mobs do
		m.state, m.t, m.a, m.b = "idle", 0, 0, 9000
		m.hp, m.maxHp = 1e12, 1e12
		m.x = 6000 + i * 30
	end
	hf.x, hf.y = hm.x + 60, hm.y
	-- 파티가 아니면 일으키지 못한다 · 쓰러진 파티원이 없으면 써지지 않는다(다시 쓰기도 돌지 않는다)
	expect(hf.invuln > 2, "맵에 들어서면 잠깐 피해를 받지 않는다(Hero.arrive)")
	hf.invuln = 0 -- 맵에 들어선 직후의 보호(Hero.arrive — 2.5초)를 걷는다
	Hero.hurt(hf, 1e9)
	expect(not hf.alive, "쓰러졌다")
	table.clear(sent)
	handlers.Skill(pm, "mn_revive", 1, hm.x, hm.y, 1)
	run(1.2)
	expect(not hf.alive, "파티원이 아니면 소생이 닿지 않는다")
	eq(hm.cds.mn_revive, nil, "써지지 않았으니 다시 쓰기도 돌지 않는다")
	eq(#got("Act", pf), 0, "동작도 나가지 않는다")
	-- 파티를 맺는다
	run(1.1)
	handlers.Party(pm, "invite", 902)
	run(1.1)
	handlers.Party(pf, "accept")
	expect(World.sameParty(901, 902), "같은 파티")
	-- 멀리 쓰러져 있으면 닿지 않는다
	hf.x = hm.x + 400
	handlers.Skill(pm, "mn_revive", 1, hm.x, hm.y, 1)
	run(1.2)
	expect(not hf.alive, "멀리 쓰러진 파티원에게는 닿지 않는다")
	-- 곁에 쓰러져 있으면 그 자리에서 일어난다: 최대 체력의 50%(마스터) · 쓰러진 벌칙이 없던 일이 된다
	hf.x = hm.x + 60
	local weakWas = hf.weakWas
	expect(hf.weak > 0, "쓰러져서 벌칙을 받았다(Lv.10부터)")
	table.clear(sent)
	handlers.Skill(pm, "mn_revive", 1, hm.x, hm.y, 1)
	run(1.2)
	expect(hf.alive, "소생: 그 자리에서 일어났다")
	eq(sf.scene, "hunt", "마을로 가지 않는다")
	eq(hf.hp, math.floor(hf.maxHp * COMBAT.cast.mn_revive.heal.revive + 0.5), "최대 체력의 50%로")
	eq(hf.weak, weakWas, "쓰러진 벌칙이 없던 일이 된다")
	eq(#got("Raise", pf), 1, "일어났다는 알림이 그 사람에게 간다")
	eq(#got("Revive", pf), 0, "마을에서 일어난 것이 아니다")
	expect((hm.cds.mn_revive or 0) > World.now + 200, "다시 쓰기 300초가 돈다")
	handlers.Return(pf)
	eq(sf.scene, "hunt", "일어난 사람의 돌아가기 요청은 버린다")
	World.removePlayer(pm)
	World.removePlayer(pf)
end

-- ---- 계정: 캐릭터 여럿 · 같이 쓰는 창고(사용자 2026-10-10: "첫번째 캐릭터가 아이템을 창고에 넣고, 두번째 캐릭터로 접속해서 그 아이템을 창고에서 뺄수 있어야합니다") ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local Hero3 = req("ReplicatedStorage/shared/lune/sim/hero")
	local Account = req("ReplicatedStorage/shared/lune/sim/account")
	local px = person({ UserId = 1201, Name = "acct" })
	local function keeper()
		for _, key in NPC_ORDER do
			for _, n in SCENES.scenes[key].npcs or {} do
				if n.id == "keeper" then
					return n, key
				end
			end
		end
		error("창고지기가 없다")
	end
	-- 창고지기 앞에 선다(창고는 Lv.4부터라 레벨도 올려 둔다)
	local function atKeeper()
		local s = World.session(px)
		Hero3.gainXp(s.hero, 20000)
		local n, key = keeper()
		goTo(px, key)
		eq(s.scene, key, "창고지기가 있는 곳으로 간다")
		s.jumped, s.stale = true, nil
		s.hero.x, s.hero.y = n.x + 10, n.y
		return s.hero
	end
	local function useSlot(h, item)
		for i = 1, Bag.size(h) do
			if h.use[i] and h.use[i].item == item then
				return i
			end
		end
		return nil
	end
	eq(#rawReady(px).select.chars, 0, "빈 계정")
	local a = handlers.Chars(px, "create", "창고하나", "axion")
	local b = handlers.Chars(px, "create", "창고둘", "mooni")
	expect(a.ok and b.ok and a.id ~= b.id, "캐릭터 둘을 만든다")
	-- 첫 캐릭터: 모자 하나와 물약 둘을 창고에 넣는다
	expect(handlers.Chars(px, "enter", a.id).self.class == "axion", "첫 캐릭터로 들어간다")
	local sx = World.session(px)
	local ha = atKeeper()
	local hat = Items.make("hat", 1, 4)
	local hatAt = Bag.add(ha, hat)
	handlers.Item(px, "storeIn", "gear", hatAt, nil, 3)
	handlers.Item(px, "storeIn", "use", useSlot(ha, "potion1"), 2)
	expect(ha.store.gear[3] == hat and ha.store.use[1] and ha.store.use[1].n == 2, "첫 캐릭터가 창고에 넣었다")
	local levelA = ha.level
	-- 고르기 화면으로 나온다: 저장하고, 세계에서 빠진다
	local back = handlers.Chars(px, "leave")
	expect(back ~= nil and back.select ~= nil and #back.select.chars == 2, "나오면 고르기 화면의 표가 온다")
	eq(back.select.last, a.id, "마지막으로 하던 캐릭터가 적혀 있다")
	eq(back.select.chars[1].level, levelA, "오른 레벨이 고르기 화면에 보인다")
	eq(sx.hero, nil, "세계에서 빠졌다")
	eq(px.attrs.LuneName, nil, "이름표도 지워졌다")
	local saved = disk[1201]
	expect(saved.store ~= nil and saved.store.gear[3] ~= false and saved.store.use[1][2] == 2, "창고는 계정에 적힌다")
	eq(saved.chars[1].hero.bag.store, nil, "캐릭터에는 창고를 적지 않는다")
	handlers.Move(px, 10, 10, 1)
	eq(handlers.Travel(px, "hunt"), nil, "고르기 화면에서는 세계의 일을 못 한다")
	-- 둘째 캐릭터: 같은 창고가 보이고, 꺼낼 수 있다
	local inB = handlers.Chars(px, "enter", b.id)
	expect(inB.self.class == "mooni" and inB.name == "창고둘" and inB.self.level == 1, "둘째 캐릭터로 들어간다(Lv.1)")
	expect(inB.bag.store.gear[3] ~= false and inB.bag.store.gear[3].slot == "hat" and inB.bag.store.gear[3].q == 4, "첫 캐릭터가 넣은 모자가 둘째 캐릭터의 창고에 있다")
	eq(inB.bag.store.use[1].n, 2, "물약 둘도 있다")
	local hb = atKeeper()
	local potionsB = Bag.count(hb, "potion1")
	local free = nil
	for i = 1, Bag.size(hb) do
		if not hb.gear[i] then
			free = i
			break
		end
	end
	handlers.Item(px, "storeOut", "gear", 3, nil, free)
	handlers.Item(px, "storeOut", "use", 1)
	expect(hb.gear[free] ~= false and hb.gear[free].slot == "hat" and hb.gear[free].q == 4, "둘째 캐릭터가 그 모자를 꺼냈다")
	eq(Bag.count(hb, "potion1"), potionsB + 2, "물약 둘도 꺼냈다")
	eq(Bag.stored(hb), 0, "창고의 장비 칸이 비었다")
	-- 나갔다가 다시: 마지막 캐릭터는 둘째. 첫 캐릭터로 들어가 보면 창고가 비어 있다(같은 창고다)
	World.removePlayer(px)
	local sel = rawReady(px).select
	eq(sel.last, b.id, "마지막으로 하던 캐릭터는 둘째다")
	local inA = handlers.Chars(px, "enter", a.id)
	expect(inA.bag.store.gear[3] == false and inA.bag.store.use[1] == false, "둘째가 꺼낸 것은 첫째의 창고에도 없다")
	eq(inA.self.level, levelA, "첫 캐릭터의 레벨은 그대로다")
	handlers.Chars(px, "leave")
	-- 캐릭터는 정해진 수까지
	for i = 3, Account.MAX do
		eq(handlers.Chars(px, "create", "채우기" .. i, "riven").ok, true, "캐릭터 " .. i)
	end
	local over = handlers.Chars(px, "create", "하나더", "riven")
	expect(over.ok == false and nameBook["하나더"] == nil, "꽉 차면 만들 수 없고, 이름도 갖지 않는다")
	World.removePlayer(px)

	-- 저장의 꼴: 읽지 못한 캐릭터도 다시 적는다(읽는 쪽의 실수로 사라지지 않게)
	local packed = Account.pack(Account.unpack({ next = 3, last = 2, chars = { { id = 1, name = "하나", class = "axion", hero = { class = "axion", level = 3 } }, { id = 2, name = "이상", class = "없는직업", hero = {} } } }))
	eq(#packed.chars, 2, "꼴이 다른 캐릭터도 저장에는 남는다")
	eq(packed.next, 3, "다음 번호가 그대로")
	eq(packed.last, false, "읽지 못한 캐릭터는 마지막 캐릭터가 아니다")
	eq(Account.unpack("x"), nil, "표가 아니면 읽지 않는다")
	-- 이름의 꼴
	for name, fine in { ["달빛"] = true, ["Moon"] = true, ["달1"] = false, ["달빛12"] = true, ["abc"] = false, ["abcdefghijkl"] = true, ["abcdefghijklm"] = false, ["ㄱㄴㄷㄹ"] = false, ["달★빛"] = false, ["GM"] = false, ["관리자님"] = false, [""] = false } do
		eq((Account.nameOk(name)), fine, "이름 " .. name)
	end
	eq((Account.nameOk(123)), false, "글이 아닌 이름")
	-- 이름의 예외 처리(사용자 2026-10-10: "닉네임에서 영어, 한글 모두 욕이나, 몇자 제한이라던가 예외처리 다 한거지?") — 규칙은 공방의 js/lune/design/names.js
	local cases = {
		-- 길이: 한글 2칸 · 영문/숫자 1칸으로 4~12칸
		{ "달", false, "한글 한 자" }, { "달빛", true, "한글 두 자" }, { "일이삼사오육", true, "한글 여섯 자" }, { "일이삼사오육칠", false, "한글 일곱 자" },
		{ "abc", false, "영문 세 자" }, { "abcd", true, "영문 네 자" }, { "abcdefghijkl", true, "영문 열두 자" }, { "abcdefghijklm", false, "영문 열세 자" },
		{ "달a", false, "한글 하나 + 영문 하나(3칸)" }, { "달ab", true, "한글 하나 + 영문 둘(4칸)" }, { "달빛Moon", true, "섞은 이름(8칸)" }, { "달빛검사Moon1", false, "섞어서 13칸" },
		-- 글자
		{ "달 빛", false, "띄어쓰기" }, { " 달빛", false, "앞의 빈칸" }, { "달빛\n", false, "줄바꿈" }, { "달빛!", false, "기호" }, { "달_빛", false, "밑줄" }, { "달빛★", false, "별표" },
		{ "ㅋㅋㅋㅋ", false, "낱자(자음)" }, { "ㅏㅏㅏㅏ", false, "낱자(모음)" }, { "月光月光", false, "한자" }, { "つきつき", false, "일본 글자" }, { "ａｂｃｄ", false, "전각 영문" }, { "달빛\u{200B}검", false, "보이지 않는 글자" }, { "달빛😀", false, "이모지" },
		{ "1234", false, "숫자만" }, { "달빛12", true, "한글 + 숫자" }, { "Moon99", true, "영문 + 숫자" },
		{ string.rep("가", 4000), false, "아주 긴 글" }, { "\xff\xfe달빛", false, "깨진 글" },
		-- 운영하는 사람 · 게임인 척
		{ "운영자", false, "운영자" }, { "달빛운영자", false, "운영자가 든 이름" }, { "GM", false, "GM(길이도 짧다)" }, { "Admin1", false, "admin" }, { "ADMIN", false, "ADMIN(대문자)" }, { "Roblox", false, "roblox" }, { "달의계승자", false, "게임의 이름" },
		-- 욕설 · 성적인 말 · 혐오 표현: 한글 · 영문 · 대문자 · 숫자를 끼운 것 · 숫자로 바꿔 적은 것
		{ "씨발", false, "한글 욕" }, { "시발놈아", false, "욕이 든 이름" }, { "시1발", false, "숫자를 끼운 욕" }, { "병신", false, "병신" }, { "개새끼", false, "개새끼" }, { "섹스", false, "성적인 말" },
		{ "fuck", false, "영문 욕" }, { "FuCk", false, "대소문자를 섞은 욕" }, { "sh1t", false, "숫자로 바꿔 적은 욕(1 → i)" }, { "b1tch", false, "b1tch" }, { "fu1ck", false, "숫자를 끼운 영문 욕" }, { "xxfuckxx", false, "욕이 든 영문 이름" }, { "n1gg4", false, "숫자 둘로 바꿔 적은 말" },
		{ "hitler", false, "hitler" }, { "일베충", false, "혐오 표현" },
		-- 멀쩡한 이름은 막지 않는다
		{ "시바견", true, "시바견" }, { "소년검사", true, "「년」이 든 멀쩡한 이름" }, { "Shift", true, "Shift" }, { "달빛도끼", true, "달빛도끼" }, { "Knight7", true, "Knight7" },
	}
	for _, c in cases do
		local ok, why = Account.nameOk(c[1])
		eq(ok, c[2], "이름의 꼴 — " .. c[3])
		expect(ok or (typeof(why) == "string" and why ~= ""), "안 되는 까닭을 알려 준다 — " .. c[3])
	end
	-- 공방(tools/build_lune_names.mjs)과 게임이 같은 답을 내는가: 공방이 맞춰 본 이름들(막혀야 하는 것 · 통과해야 하는 것)을 게임의 셈으로 다시 본다.
	--  사용자 2026-10-10(「성관계장인」이 통과되는 사진): "조금만 우회해도 문제되는 닉네임이 통과됩니다."
	local NAMES = req("ReplicatedStorage/shared/lune/data/names.generated")
	expect(#NAMES.ko > 2000 and #NAMES.en > 300, "금칙어 표가 들어 있다(한글 " .. #NAMES.ko .. " · 영문 " .. #NAMES.en .. ")")
	expect(#NAMES.check.block >= 80 and #NAMES.check.pass >= 150, "맞춰 볼 이름이 들어 있다")
	for _, n in NAMES.check.block do
		eq(Account.nameBanned(n), true, "막혀야 하는 이름 — " .. n)
	end
	for _, n in NAMES.check.pass do
		eq(Account.nameBanned(n), false, "통과해야 하는 이름 — " .. n)
	end
	eq(handlers.Chars(px, "check", "성관계장인"), nil, "(세션이 없으면 답하지 않는다)")
	local _, whyBad = Account.nameOk("fuck")
	local _, whyShort = Account.nameOk("달")
	expect(whyBad == Account.TEXT.banned and whyShort == Account.TEXT.short and whyBad ~= whyShort, "까닭마다 다른 글이다(욕설은 어느 말이 걸렸는지 알려 주지 않는다)")
end

-- ---- 명예의 전당: 레벨 · 전투력 · 후원의 순위판(사용자 2026-10-10: "명예의 전당 … 최대 로벅스 결제자, 전투력 랭킹, 레벨 랭킹 이렇게 캐릭터 닉네임 보여주는") ----
do
	local Hero4 = req("ReplicatedStorage/shared/lune/sim/hero")
	local Rank = req("ReplicatedStorage/shared/lune/sim/rank")
	local ph1 = person({ UserId = 1601, Name = "hall1" })
	local ph2 = person({ UserId = 1602, Name = "hall2" })
	table.clear(rankDisk) -- 앞의 검사들이 올려 둔 캐릭터들을 치운다(판은 위 열 줄만 보인다)
	table.clear(rankInfo)
	rawReady(ph1)
	rawReady(ph2)
	eq(handlers.Rank(ph1), nil, "캐릭터로 들어가기 전에는 순위를 주지 않는다")
	local m1 = handlers.Chars(ph1, "create", "전당하나", "axion")
	local m2 = handlers.Chars(ph2, "create", "전당둘", "riven")
	handlers.Chars(ph1, "enter", m1.id)
	handlers.Chars(ph2, "enter", m2.id)
	Hero4.gainXp(World.session(ph2).hero, 30000) -- 둘째가 레벨이 더 높다
	local function find(list, name)
		for i, row in list do
			if row.name == name then
				return i, row
			end
		end
		return nil, nil
	end
	run(Rank.REFRESH + 1) -- 서버가 순위를 다시 읽을 때까지
	local boards = handlers.Rank(ph2)
	expect(boards ~= nil and boards.level ~= nil and boards.power ~= nil and boards.robux ~= nil, "판 셋이 온다")
	local i1, r1 = find(boards.level, "전당하나")
	local i2, r2 = find(boards.level, "전당둘")
	expect(i1 ~= nil and i2 ~= nil and i2 < i1, "레벨이 높은 캐릭터가 위에 있다")
	expect(r2.value == ("Lv.%d"):format(World.session(ph2).hero.level) and r2.class == "riven", "이름 · 직업 · 레벨이 적혀 있다 " .. tostring(r2.value))
	expect(r1.value == "Lv.1", "Lv.1 캐릭터도 올라 있다")
	expect(#boards.level <= Rank.TOP and #boards.power <= Rank.TOP, "판마다 열 줄까지")
	expect(find(boards.power, "전당둘") ~= nil, "전투력 판에도 올라 있다")
	eq(find(boards.robux, "전당둘"), nil, "쓴 로벅스가 없으면 후원 판에는 없다")
	-- 후원: 계정이 쓴 로벅스가 쌓이고, 그때 하던 캐릭터의 이름으로 오른다
	World.addSpent(ph1, 400)
	World.addSpent(ph1, 100)
	World.addSpent(ph1, -5)
	local _, rb = find(handlers.Rank(ph1).robux, "전당하나")
	expect(rb ~= nil and rb.value == "500", "쓴 로벅스가 쌓여 후원 판에 오른다")
	eq(disk[1601].spent, 500, "계정에 저장된다")
	-- 캐릭터를 지우면 판에서도 빠진다
	handlers.Chars(ph2, "leave")
	eq(handlers.Chars(ph2, "delete", m2.id, "전당둘").ok, true, "캐릭터를 지운다")
	run(Rank.REFRESH + 1)
	eq(find(handlers.Rank(ph1).level, "전당둘"), nil, "지운 캐릭터는 순위판에서 빠진다")
	World.removePlayer(ph1)
	World.removePlayer(ph2)
	eq(Rank.levelOf(Rank.levelScore(37, 50, 100)), 37, "레벨 순위의 점수에서 레벨을 다시 읽는다")
	expect(Rank.levelScore(37, 60, 100) > Rank.levelScore(37, 50, 100) and Rank.levelScore(38, 0, 100) > Rank.levelScore(37, 99, 100), "같은 레벨이면 경험치가 많은 쪽이, 레벨이 높으면 늘 위다")
end

-- ---- 이름을 더 쓸 수 없게 된 캐릭터: 들어갈 때 다시 본다(지은 뒤에 금칙어가 늘었거나, 글 거르기가 걸러 주지 않는 Studio에서 지은 이름) ----
do
	local Account = req("ReplicatedStorage/shared/lune/sim/account")
	local pr = person({ UserId = 1501, Name = "renamer" })
	rawReady(pr)
	expect(handlers.Chars(pr, "create", "착한이름", "axion").ok and handlers.Chars(pr, "create", "둘째이름", "riven").ok, "캐릭터 둘")
	World.removePlayer(pr)
	-- 저장된 이름이 지금의 규칙으로는 안 되는 것이 되었다고 치자: 하나는 우리 목록에, 하나는 Roblox의 글 거르기에 걸린다
	disk[1501].chars[1].name = "성관계장인"
	nameBook["성관계장인"] = 1501
	disk[1501].chars[2].name = "욕설대장"
	nameBook["욕설대장"] = 1501
	local sel = rawReady(pr).select
	eq(sel.chars[1].name, "성관계장인", "고르기 화면에는 저장된 이름이 그대로 온다")
	local out = handlers.Chars(pr, "enter", sel.chars[1].id)
	expect(out ~= nil and out.ok == false and out.self == nil, "우리 목록에 걸리는 이름으로는 들어가지 못한다")
	eq(out.why, Account.TEXT.gone, "새로 지으라고 알려 준다")
	eq(out.select.chars[1].name, "", "이름이 비워졌다")
	eq(nameBook["성관계장인"], nil, "그 이름은 장부에서 빠졌다")
	eq(disk[1501].chars[1].name, "", "비운 것을 바로 저장한다")
	local out2 = handlers.Chars(pr, "enter", sel.chars[2].id)
	expect(out2.ok == false and out2.select.chars[2].name == "", "Roblox의 글 거르기에 걸리는 이름도 비워진다")
	eq(World.session(pr).hero, nil, "세계에 서지 않았다")
	-- 새로 지으면 들어간다(캐릭터의 레벨 · 물건은 그대로다 — 이름만 다시 짓는다)
	eq(handlers.Chars(pr, "name", sel.chars[1].id, "다시지음").ok, true, "이름을 새로 짓는다")
	local inn = handlers.Chars(pr, "enter", sel.chars[1].id)
	expect(inn.self ~= nil and inn.name == "다시지음", "새 이름으로 들어간다")
	World.removePlayer(pr)
end

-- ---- 계정이 생기기 전의 저장(캐릭터 하나)은 첫 캐릭터가 된다 — 이름을 지어야 들어간다. 예전 저장은 그대로 둔다 ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local Hero3 = req("ReplicatedStorage/shared/lune/sim/hero")
	local old = Hero3.new(1301, "riven")
	Hero3.gainXp(old, 5000)
	old.money = 777
	local at = Bag.add(old, Items.make("hat", 1, 2))
	Bag.storeIn(old, "gear", at, nil, 2)
	oldDisk[1301] = Hero3.pack(old)
	local keptOld = oldDisk[1301]
	local pm = person({ UserId = 1301, Name = "oldie", DisplayName = "옛사람" })
	local sel = rawReady(pm).select
	expect(#sel.chars == 1 and sel.chars[1].name == "" and sel.chars[1].class == "riven" and sel.chars[1].level == old.level, "예전 캐릭터가 이름 없이 첫 캐릭터로 와 있다")
	expect(disk[1301] ~= nil and disk[1301].store ~= nil, "옮긴 계정을 바로 저장한다(창고는 계정으로)")
	expect(oldDisk[1301] == keptOld, "예전 저장은 그대로 둔다")
	eq(handlers.Chars(pm, "enter", 1).ok, false, "이름이 없으면 들어갈 수 없다")
	eq(handlers.Chars(pm, "name", 1, "달").ok, false, "안 되는 이름은 지을 수 없다")
	eq(handlers.Chars(pm, "name", 9, "옛계승자").ok, false, "없는 캐릭터에는 지을 수 없다")
	eq(handlers.Chars(pm, "name", 1, "옛계승자").ok, true, "이름을 짓는다")
	eq(nameBook["옛계승자"], 1301, "이름 장부에 적혔다")
	eq(handlers.Chars(pm, "name", 1, "또바꾸기").ok, false, "이름은 한 번만 짓는다")
	local inn = handlers.Chars(pm, "enter", 1)
	expect(inn.self ~= nil and inn.name == "옛계승자", "지은 이름으로 들어간다")
	eq(inn.self.money, 777, "돈이 그대로")
	eq(inn.self.level, old.level, "레벨이 그대로")
	expect(inn.bag.store.gear[2] ~= false and inn.bag.store.gear[2].slot == "hat", "예전 캐릭터의 창고가 계정의 창고가 됐다")
	World.removePlayer(pm)
	-- 다시 들어오면 계정을 읽는다(예전 저장을 또 옮기지 않는다)
	local again = rawReady(pm).select
	expect(#again.chars == 1 and again.chars[1].name == "옛계승자", "다시 들어와도 캐릭터는 하나다")
	World.removePlayer(pm)
end

-- ---- 확인용 임시 계정(LuneGuest = "new"): 캐릭터 만들기부터 해 보되 저장도 이름 장부도 건드리지 않는다 ----
do
	local realGuest = World.guest
	World.guest = function()
		return "new"
	end
	local pn = person({ UserId = 1401, Name = "newbie" })
	eq(#rawReady(pn).select.chars, 0, "빈 계정으로 시작한다")
	local made = handlers.Chars(pn, "create", "임시하나", "salamander")
	expect(made.ok == true and nameBook["임시하나"] == nil, "만들 수 있고, 이름 장부에는 적지 않는다")
	eq(handlers.Chars(pn, "check", "임시하나").ok, false, "임시 계정 안에서도 같은 이름은 중복이다")
	local inn = handlers.Chars(pn, "enter", made.id)
	expect(inn.self.level == 1 and inn.self.class == "salamander", "Lv.1로 들어간다")
	World.saveAll(false)
	expect(handlers.Chars(pn, "leave").select ~= nil, "고르기 화면으로 나올 수 있다")
	World.removePlayer(pn)
	eq(disk[1401], nil, "저장된 것이 없다")
	-- "select": 캐릭터가 셋 있는 임시 계정(하나는 이름이 없다)
	World.guest = function()
		return "select"
	end
	local sel = rawReady(pn).select
	expect(#sel.chars == 3 and sel.chars[1].level == 12 and sel.chars[2].level == 31 and sel.chars[3].name == "", "임시 계정에 캐릭터 셋이 있다")
	eq(handlers.Chars(pn, "enter", sel.chars[3].id).ok, false, "이름이 없는 캐릭터는 이름을 지어야 들어간다")
	expect(handlers.Chars(pn, "enter", sel.chars[2].id).self.level == 31, "Lv.31 캐릭터로 들어간다")
	-- 임시 계정에서도 캐릭터를 바꾸면 창고가 이어진다(저장소에는 쓰지 않고 계정의 표에만 적는다) — Studio에서 같이 쓰는 창고를 볼 때 쓴다
	do
		local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
		local sn = World.session(pn)
		local at = nil
		for i = 1, Bag.size(sn.hero) do
			if sn.hero.use[i] and sn.hero.use[i].item == "potion1" then
				at = i
			end
		end
		expect(Bag.storeIn(sn.hero, "use", at, 3) == true, "창고에 물약 셋을 넣는다(셈만 — 창고지기 앞인지는 위에서 봤다)")
		handlers.Chars(pn, "leave")
		local other = handlers.Chars(pn, "enter", sel.chars[1].id)
		expect(other.bag.store.use[1] ~= false and other.bag.store.use[1].n == 3, "임시 계정의 다른 캐릭터에게도 그 창고가 보인다")
	end
	World.removePlayer(pn)
	eq(disk[1401], nil, "이것도 저장하지 않는다")
	World.guest = realGuest
end

-- ---- 시작과 전직 퀘스트의 흐름(2026-10-10): 사당 안에서 시작 → 첫 기술 → 다시 들어오면 마을 / Lv.30에 전직 퀘스트를 저절로 받는다 → 조각 열 개 → 사제에게 돌려주면 2차 ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local pj = person({ UserId = 1501, Name = "jobber" })
	rawReady(pj)
	local made = handlers.Chars(pj, "create", "전직시험", "axion")
	local start = handlers.Chars(pj, "enter", made.id)
	local sj = World.session(pj)
	local hj = sj.hero
	local function last(name)
		local list = got(name, pj)
		return list[#list] and list[#list].args
	end
	eq(start.scene, "in_shrine", "새 캐릭터는 사당 안에서 시작한다")
	eq(start.self.job, 1, "1차로 시작한다")
	-- 첫 퀘스트: 사제 앞에서 돌려준다 → 다시 들어오면 마을의 시작 자리
	local master
	for _, n in SCENES.scenes.in_shrine.npcs do
		if n.id == "master" then
			master = n
		end
	end
	sj.jumped, sj.stale = true, nil
	hj.x, hj.y = master.x + 10, master.y
	eq(hj.quests.r1m1, nil, "새 캐릭터는 「첫 기술」을 아직 받지 않았다")
	handlers.Quest(pj, "accept", "r1m1")
	expect(hj.quests.r1m1 ~= nil and not hj.quests.r1m1.done, "사제에게 말을 걸어 「첫 기술」을 받는다")
	handlers.Chars(pj, "leave")
	eq(handlers.Chars(pj, "enter", made.id).scene, "in_shrine", "받기만 하고 끝내지 않은 캐릭터는 다시 들어와도 사당 안이다")
	sj = World.session(pj)
	hj = sj.hero
	sj.jumped, sj.stale = true, nil
	hj.x, hj.y = master.x + 10, master.y
	handlers.Quest(pj, "complete", "r1m1")
	expect(hj.quests.r1m1.done == true, "한 번 더 말을 걸어 「첫 기술」을 끝낸다")
	handlers.Chars(pj, "leave")
	local back = handlers.Chars(pj, "enter", made.id)
	eq(back.scene, SCENES.start, "첫 퀘스트를 끝낸 캐릭터는 마을에서 시작한다")
	sj = World.session(pj)
	hj = sj.hero
	-- Lv.29 → 30: 전직 퀘스트를 저절로 받고(화면에 알린다), 차수는 아직 1이다
	while hj.level < 29 do
		Hero.gainXp(hj, N.xpNeed(hj.level) - hj.xp)
	end
	eq(hj.quests.job2, nil, "Lv.29에는 전직 퀘스트가 없다")
	World.guestDebug = nil
	table.clear(sent)
	local ups = Hero.gainXp(hj, N.xpNeed(hj.level) - hj.xp)
	eq(ups, 1, "Lv.30이 된다")
	eq(hj.quests.job2, nil, "Lv.30이 되어도 전직 퀘스트를 저절로 받지 않는다(사제에게 가서 받는다 — 2026-10-11)")
	eq(Quests.state(hj.quests, hj.level, "job2"), "open", "Lv.30이면 받을 수 있다")
	local guideJ = Quests.guide(hj.quests, hj.level, { master = "그믐 사제" })
	expect(guideJ[1] ~= nil and guideJ[1].kind == "job" and guideJ[1].title == "! 2차 전직" and guideJ[1].line == "그믐 사제에게 받는다 · 달의 사당", "알리미의 길잡이 맨 위에 전직 퀘스트: " .. tostring(guideJ[1] and guideJ[1].line))
	eq(Quests.listOpen(hj.quests, hj.level)[1], "job2", "퀘스트 창의 「시작 가능」 맨 위에도")
	eq(hj.job, 1, "퀘스트를 돌려주기 전에는 1차다")
	eq(Hero.view(hj).job, 1, "화면에도 1차로 보낸다(스킬 창의 II 탭이 잠겨 있다)")
	eq(hj.skills.ax_crescent, nil, "2차의 사냥기가 아직 없다")
	local jobDef = Quests.def("job2")
	eq(jobDef.scene, "r1c3", "전직 퀘스트의 물건은 망루 3층에서 모은다")
	-- 조각이 모자라면 돌려주지 못한다
	local n2, key2 = master, "in_shrine"
	goTo(pj, key2)
	sj.jumped, sj.stale = true, nil
	hj.x, hj.y = n2.x + 10, n2.y
	-- 사제에게 말을 걸어 받는다
	table.clear(sent)
	handlers.Quest(pj, "complete", "job2")
	expect(last("ItemDone")[1].ok == false and hj.quests.job2 == nil, "받지 않은 전직 퀘스트는 돌려주지 못한다")
	table.clear(sent)
	handlers.Quest(pj, "accept", "job2")
	expect(hj.quests.job2 ~= nil and not hj.quests.job2.done, "사제에게 말을 걸어 전직 퀘스트를 받는다")
	eq(Quests.active(hj.quests)[1], "job2", "알리미의 맨 위에 전직 퀘스트가 온다")
	eq(#Quests.guide(hj.quests, hj.level, {}) > 0 and Quests.guide(hj.quests, hj.level, {})[1].kind == "job", false, "받은 뒤에는 길잡이에서 빠진다")
	table.clear(sent)
	handlers.Quest(pj, "complete", "job2")
	expect(last("ItemDone")[1].ok == false, "조각이 모자라면 전직하지 못한다")
	eq(hj.job, 1, "그대로 1차다")
	-- 조각 열 개: 망루 3층의 수련 인형이 떨어뜨린다(여기서는 가방에 넣어 준다 — 떨어지고 줍는 것은 위의 퀘스트 검사가 본다)
	local step = jobDef.steps[1]
	eq(step.n, 10, "열 개")
	Bag.give(hj, step.item, 10)
	Hero.syncQuests(hj)
	expect(Quests.isReady(hj.quests, "job2"), "열 개를 모으면 돌려줄 수 있다")
	eq(handlers.Quest(pj, "drop", "job2"), nil, "전직 퀘스트는 그만둘 수 없다(아무 일도 없다)")
	expect(hj.quests.job2 ~= nil, "그만두지 못했다")
	local slotWas = table.find(hj.slots, "ax_slam")
	table.clear(sent)
	handlers.Quest(pj, "complete", "job2")
	eq(hj.job, 2, "사제에게 돌려주면 2차로 전직한다")
	eq(hj.skills.ax_crescent, 1, "2차의 사냥기가 레벨 1로 생긴다")
	eq(Bag.count(hj, step.item), 0, "조각은 가방에서 빠진다")
	expect(slotWas ~= nil and hj.slots[slotWas] == "ax_crescent", "사냥기의 칸에 2차의 사냥기가 들어온다")
	expect(last("Quests") ~= nil and last("Quests")[2] == "job2", "화면에 전직 퀘스트를 끝냈다고 알린다")
	expect(last("Self") ~= nil and last("Self")[1].job == 2, "내 상태에 2차가 실려 온다")
	expect(Hero.skillUp(hj, "ax_crescent"), "이제 2차의 스킬을 올린다(Lv.30에 받은 포인트로)")
	-- 저장하고 다시 들어와도 2차 그대로 · 전직 퀘스트를 다시 받지 않는다
	handlers.Chars(pj, "leave")
	local again = handlers.Chars(pj, "enter", made.id)
	eq(again.self.job, 2, "다시 들어와도 2차다")
	expect(again.quests.job2 ~= nil and again.quests.job2.done == true, "전직 퀘스트는 끝낸 채다")
	-- 전직 퀘스트가 생기기 전에 저장된 캐릭터(차수가 적혀 있지 않다): 그 레벨의 차수 그대로 · 전직 퀘스트를 받지 않는다
	do
		local old = Hero.pack(World.session(pj).hero)
		old.job = nil
		old.quests.job2 = nil
		local h = Hero.unpack(1, old)
		eq(h.job, 2, "예전 저장은 그 레벨의 차수로 읽는다")
		expect(h.quests.job2 ~= nil and h.quests.job2.done == true, "예전 저장의 캐릭터는 전직 퀘스트를 다시 받지 않는다")
		eq(h.skills.ax_crescent, 2, "찍어 둔 2차 스킬도 그대로다")
		-- 차수를 레벨보다 높게 적어 둔 저장(깨진 자료)은 그 레벨이 닿는 데까지만
		local bad = Hero.pack(World.session(pj).hero)
		bad.job = 4
		eq(Hero.unpack(1, bad).job, 2, "레벨이 닿지 않는 차수는 읽지 않는다")
	end
	World.removePlayer(pj)
end

-- ---- 재료 · 제작 · 귀환 주문서(2026-10-11): 떨어진 재료를 줍는다 → 대장장이 앞에서 만든다 → 귀환 주문서로 마을에 돌아온다 ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local pc = person({ UserId = 1877, Name = "crafter" })
	handlers.Ready(pc)
	handlers.Choose(pc, "riven")
	local sc = World.session(pc)
	local hc = sc.hero
	local function last(name)
		local list = got(name, pc)
		return list[#list] and list[#list].args
	end
	-- 떨어진 재료를 줍는다: 가방의 기타 탭에 들어온다
	goTo(pc, "r1a1")
	local room = World.room("r1a1")
	local ore = Items.matsAt(1)[1]
	local d = room:addDrop({ kind = "goods", goods = ore, amount = 1, name = Items.goods(ore).name, icon = Items.goods(ore).icon }, hc.x, hc.y, hc.id)
	table.clear(sent)
	handlers.Pickup(pc, d.id)
	eq(Bag.count(hc, ore), 1, "떨어진 재료를 주우면 가방에 들어온다")
	expect(#got("Bag", pc) >= 1, "가방이 다시 온다")
	-- 제작은 대장장이 앞에서만
	local r = Items.recipe("c1_weapon")
	for _, need in r.needs do
		Bag.give(hc, need.item, need.n)
	end
	hc.money = 1000
	table.clear(sent)
	handlers.Item(pc, "craft", "c1_weapon")
	expect(last("ItemDone")[1].ok == false and last("ItemDone")[1].why == "대장장이 앞이 아니다", "사냥터에서는 못 만든다")
	local smith, skey
	for key, scn in SCENES.scenes do
		for _, n in scn.npcs or {} do
			if n.id == "smith" and scn.region == "r1" then
				smith, skey = n, key
			end
		end
	end
	goTo(pc, skey)
	sc.jumped, sc.stale = true, nil
	hc.x, hc.y = smith.x + 10, smith.y
	local gearWas = Bag.used(hc, "gear")
	table.clear(sent)
	handlers.Item(pc, "craft", "c1_weapon")
	local done = last("ItemDone")[1]
	expect(done.ok == true and done.result ~= nil and done.result.slot == "weapon" and done.result.stage == 1 and done.result.who == "riven", ("대장장이 앞에서 만든다 — 만든 장비가 실려 온다(%s · %s · %s %s %s)"):format(tostring(done.ok), tostring(done.why), tostring(done.result and done.result.slot), tostring(done.result and done.result.stage), tostring(done.result and done.result.who)))
	expect(done.result.q >= Items.NORMAL, "성능은 보통 이상")
	eq(Bag.used(hc, "gear"), gearWas + 1, "가방에 들어온다")
	eq(hc.money, 1000 - r.money, "삯이 빠진다")
	expect(#got("Bag", pc) >= 1, "가방이 다시 온다")
	-- 귀환 주문서: 마을 밖에서 쓰면 마을의 시작 자리로 · 주문서가 하나 준다 · 마을에서는 쓰이지 않는다
	Bag.give(hc, "scroll_return", 3)
	table.clear(sent)
	handlers.Potion(pc, "scroll_return")
	eq(sc.scene, SCENES.start, "마을의 건물 안에서 써도 마을의 시작 자리로 나온다")
	goTo(pc, "r1a1")
	local before = Bag.count(hc, "scroll_return")
	table.clear(sent)
	handlers.Potion(pc, "scroll_return")
	eq(sc.scene, SCENES.start, "귀환 주문서를 쓰면 마을로 돌아온다")
	eq(hc.x, SCENES.scenes[SCENES.start].spawn.x, "마을의 시작 자리")
	eq(Bag.count(hc, "scroll_return"), before - 1, "주문서가 하나 준다")
	expect(last("Revive") ~= nil and last("Revive")[1].scene == SCENES.start, "화면에 마을로 옮겼다고 알린다")
	table.clear(sent)
	handlers.Potion(pc, "scroll_return")
	eq(Bag.count(hc, "scroll_return"), before - 1, "마을에서는 쓰이지 않는다(주문서도 줄지 않는다)")
	expect(last("ItemDone")[1].ok == false and last("ItemDone")[1].why == "이미 마을이다", "까닭을 알린다")
	-- 물약은 그대로 마신다(귀환 주문서를 넣으며 망가지지 않았다)
	hc.hp = 1
	handlers.Potion(pc, "potion1")
	expect(hc.hp > 1, "물약을 마신다")
	World.removePlayer(pc)
end

-- ---- 일일 의뢰(Daily): 게시판 앞에서 받고, 그 맵의 그 몬스터를 잡으면 세고, 게시판에 낸다 ----
--  사용자 2026-10-13: "일일 퀘스트 필요합니다. 게시판이랑 상호작용해서 일퀘받는거 좋습니다. … 일일 의뢰는 10부터 열죠"
do
	local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
	local HeroD = req("ReplicatedStorage/shared/lune/sim/hero")
	local DD = Daily.DATA
	local pd = person({ UserId = 351, Name = "dailyman" })
	handlers.Ready(pd)
	expect(handlers.Choose(pd, "axion", "의뢰시험") ~= nil, "일일 의뢰를 해 볼 캐릭터")
	local sd = World.session(pd)
	local hd = sd.hero
	local function last(name)
		local list = got(name, pd)
		return list[#list] and list[#list].args
	end
	local board = DD.boards.r1
	local function atBoard(dx: number)
		goTo(pd, board.scene)
		eq(sd.scene, board.scene, "게시판이 있는 마을로")
		for _, n in SCENES.scenes[board.scene].npcs do
			if n.id == board.npc then
				sd.jumped, sd.stale = true, nil
				hd.x, hd.y = n.x + dx, n.y
			end
		end
	end
	-- Lv.9: 아직 없다
	HeroD.setLevel(hd, DD.from - 1)
	atBoard(6)
	local r = handlers.Daily(pd, "view")
	expect(r ~= nil and next(r.view.boards) == nil, "Lv.9에게는 의뢰가 없다")
	r = handlers.Daily(pd, "accept", "r1", 1)
	expect(r.ok == false and r.why == Daily.WORDS.early, "Lv.9는 게시판 앞에서도 받지 못한다")
	-- Lv.12: 의뢰 둘
	HeroD.setLevel(hd, 12)
	HeroD.autoStat(hd)
	HeroD.maxSkills(hd)
	r = handlers.Daily(pd, "view")
	expect(r.ok and #r.view.boards.r1.tasks == DD.perDay and sd.dirty == true, "Lv.12: 오늘의 의뢰 둘(새로 뽑은 것은 저장한다)")
	local task = r.view.boards.r1.tasks[1]
	-- 멀리서는 받지 못한다 · 말이 안 되는 것
	atBoard(300)
	r = handlers.Daily(pd, "accept", "r1", 1)
	expect(r.ok == false and r.why == Daily.WORDS.far and hd.daily.r1.tasks[1].st == Daily.OPEN, "게시판에서 멀면 받지 못한다")
	atBoard(6)
	expect(handlers.Daily(pd, "accept", "r9", 1).ok == false and handlers.Daily(pd, "fly", "r1", 1).ok == false and handlers.Daily(pd, "accept", "r1", 9).ok == false, "없는 지역 · 모르는 일 · 없는 의뢰")
	r = handlers.Daily(pd, "accept", "r1", 1)
	expect(r.ok == true and r.view.boards.r1.tasks[1].st == Daily.ON, "게시판 앞에서 받는다")
	-- 그 맵으로 가서 그 몬스터를 잡는다(끝의 셋만 진짜로 잡는다)
	expect(goTo(pd, task.scene) ~= nil, "의뢰의 맵으로 — " .. task.place)
	hd.invuln = 9999
	hd.daily.r1.tasks[1].have = DD.kills - 3
	local room = World.room(task.scene)
	table.clear(sent)
	local killed = 0
	for _ = 1, 300 do
		if hd.daily.r1.tasks[1].have >= DD.kills then
			break
		end
		local target
		for _, m in room.mobs do
			if m.kind == task.mob and m.state ~= "dead" and m.state ~= "gone" and m.state ~= "spawn" then
				target = m
				break
			end
		end
		if target then
			target.hp = 1
			sd.jumped, sd.stale = true, nil
			handlers.Move(pd, math.clamp(target.x - 12, 8, 3000), target.y, 1)
			castSlam(pd, hd.x, hd.y, 1)
			run(1.2)
			if target.state == "dead" or target.state == "gone" then
				killed += 1
			end
		else
			run(1)
		end
	end
	eq(hd.daily.r1.tasks[1].have, DD.kills, ("그 맵의 %s를 잡아 30을 채웠다(진짜로 잡은 수 %d)"):format(task.name, killed))
	local pushed = got("DailyView", pd)
	expect(#pushed >= 3 and pushed[#pushed].args[1].boards.r1.tasks[1].have == DD.kills, "잡을 때마다 의뢰의 상태가 온다")
	-- 내는 것은 게시판 앞에서만
	local money0, level0 = hd.money, hd.level
	r = handlers.Daily(pd, "turn", "r1", 1)
	expect(r.ok == false and r.why == Daily.WORDS.far and hd.money == money0, "사냥터에서는 내지 못한다")
	atBoard(-8)
	table.clear(sent)
	r = handlers.Daily(pd, "turn", "r1", 1)
	expect(r.ok == true and r.reward ~= nil and r.reward.money == DD.pay.money[level0] and r.reward.xp == DD.pay.xp[level0] and r.reward.dust == 0 and r.reward.name == task.name, "게시판 앞에서 낸다: 내 레벨의 보상")
	expect(hd.money == money0 + r.reward.money and r.view.boards.r1.tasks[1].st == Daily.DONE, "달돈이 늘고 「완료」가 된다")
	expect(last("Gain") ~= nil and last("Gain")[1].xp == r.reward.xp, "경험치를 받았다고 알린다")
	expect(handlers.Daily(pd, "turn", "r1", 1).ok == false, "두 번 내지 못한다")
	-- 둘째: 받고 → (셈으로 채우고) → 내면 덤
	expect(handlers.Daily(pd, "accept", "r1", 2).ok == true, "둘째 의뢰를 받는다")
	hd.daily.r1.tasks[2].have = DD.kills
	local dust0, lv = hd.dust, hd.level
	r = handlers.Daily(pd, "turn", "r1", 2)
	expect(r.ok == true and r.reward.all == true and r.reward.dust == DD.pay.dust[lv] and hd.dust == dust0 + r.reward.dust, "둘을 다 내면 덤으로 달가루")
	-- 캐릭터 고르기로 나갔다 들어와도 남는다
	local keep = Daily.pack(hd.daily)
	handlers.Chars(pd, "leave")
	local again = enterAgain(pd)
	expect(again ~= nil, "다시 들어온다")
	local hd2 = World.session(pd).hero
	expect(hd2.daily.r1 ~= nil and hd2.daily.r1.day == keep.r1.day and hd2.daily.r1.bonus == true and hd2.daily.r1.tasks[1].st == Daily.DONE and hd2.daily.r1.tasks[2].st == Daily.DONE, "다시 들어와도 오늘의 의뢰는 낸 그대로다(다시 받지 못한다)")
	-- 다음 날(저장된 것이 어제의 것): 새 의뢰 둘
	hd2.daily.r1.day -= 1
	r = handlers.Daily(pd, "view")
	expect(r.view.boards.r1.tasks[1].st == Daily.OPEN and r.view.boards.r1.tasks[2].st == Daily.OPEN and r.view.boards.r1.bonus == false, "날이 바뀌면 새 의뢰 둘")
	World.removePlayer(pd)
end

-- ---- 사당 지하(메인 「불타는 마을」): 퀘스트를 받아야 문이 열리고, 내려가면 병사가 밀려들고, 열둘을 잡으면 사라진다 ----
--  사용자 2026-10-13: "사당지하 개발 해야합니다."
do
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local HeroC = req("ReplicatedStorage/shared/lune/sim/hero")
	local def = Quests.def("r1m9")
	expect(def ~= nil and def.name == "불타는 마을" and def.scene == "in_cellar", "1지역의 마지막 메인 「불타는 마을」은 사당 지하에서 한다")
	local step = def.steps[1]
	expect(#def.steps == 1 and step.type == "kill" and step.n >= 8, "할 일 = 지하로 밀려든 병사를 잡는다")
	local cellar, shrine = SCENES.scenes.in_cellar, SCENES.scenes.in_shrine
	expect(cellar ~= nil and cellar.story == true and cellar.rest == false and cellar.indoor == true, "사당 지하: 이야기의 방 · 쉬는 곳이 아니다")
	local down = nil
	for _, pt in shrine.portals do
		if pt.to == "in_cellar" then
			down = pt
		end
	end
	expect(down ~= nil and down.need == "r1m9", "사당 안에 지하로 내려가는 문이 있다(「불타는 마을」을 받아야 열린다)")
	expect(#cellar.mobs >= 3, "지하에 병사의 자리가 있다")
	for _, m in cellar.mobs do
		expect(m.kind == step.mob and m.lv == def.lv, "지하의 병사 = 퀘스트가 잡으라는 것 · 그 레벨")
	end
	local tablet = cellar.npcs and cellar.npcs[1]
	expect(tablet ~= nil and tablet.stone == true and #tablet.lines >= 1, "지하에 읽을거리(비석)가 있다")

	local pc = person({ UserId = 371, Name = "cellarman" })
	handlers.Ready(pc)
	expect(handlers.Choose(pc, "axion", "지하시험") ~= nil, "사당 지하를 해 볼 캐릭터")
	local sc = World.session(pc)
	local hc = sc.hero
	HeroC.setLevel(hc, def.lv)
	HeroC.autoStat(hc)
	HeroC.maxSkills(hc)
	hc.invuln = 9999
	local function standAt(key, x, y)
		expect(goTo(pc, key) ~= nil or sc.scene == key, "간다 " .. key)
		sc.jumped, sc.stale = true, nil
		hc.x, hc.y = x, y
	end
	-- 퀘스트를 받기 전: 사당 안의 문은 닫혀 있다
	standAt("in_shrine", down.x, down.y)
	expect(handlers.Travel(pc, "in_cellar") == nil and sc.scene == "in_shrine", "「불타는 마을」을 받기 전에는 지하로 내려가지 못한다")
	-- 받은 것으로(앞의 메인은 끝낸 것으로): 문이 열린다
	local cur = def
	while cur and cur.after do
		hc.quests[cur.after] = { done = true, c = {} }
		cur = Quests.def(cur.after)
	end
	hc.quests.r1m9 = { done = false, c = {} }
	local trip = handlers.Travel(pc, "in_cellar")
	expect(trip ~= nil and trip.scene == "in_cellar" and sc.scene == "in_cellar", "받은 뒤에는 내려간다")
	expect(math.abs(hc.x - cellar.portals[1].x) <= 1, "올라가는 문 앞에 선다")
	local room = World.room("in_cellar")
	local function standing(): number
		local n = 0
		for _, m in room.mobs do
			if m.state ~= "gone" then
				n += 1
			end
		end
		return n
	end
	-- 병사가 하나씩 나타난다
	run(0.2)
	expect(standing() < #room.mobs, "한꺼번에 나타나지 않는다(하나씩)")
	run(4)
	eq(standing(), #room.mobs, "조금 뒤에는 병사가 모두 나와 있다")
	-- 열둘을 잡는다
	table.clear(sent)
	local killed = 0
	for _ = 1, 600 do
		if Quests.isReady(hc.quests, "r1m9") then
			break
		end
		local target
		for _, m in room.mobs do
			if m.state ~= "dead" and m.state ~= "gone" and m.state ~= "spawn" then
				target = m
				break
			end
		end
		if target then
			target.hp = 1
			sc.jumped, sc.stale = true, nil
			handlers.Move(pc, math.clamp(target.x - 12, 8, 376), target.y, 1)
			castSlam(pc, hc.x, hc.y, 1)
			run(1.2)
			if target.state == "dead" or target.state == "gone" then
				killed += 1
			end
		else
			run(1)
		end
	end
	expect(Quests.isReady(hc.quests, "r1m9"), ("병사 %d을 잡았다(잡은 수 %d)"):format(step.n, killed))
	expect(killed >= step.n - 1, "쓰러뜨린 병사는 다시 밀려든다(자리 넷으로 열둘을 채운다)")
	-- 다 잡으면 남은 병사가 사라진다 · 다시 나오지 않는다
	run(0.2)
	eq(standing(), 0, "다 잡으면 병사가 모두 사라진다")
	run(30)
	eq(standing(), 0, "다시 나오지 않는다")
	-- 퀘스트가 없는 사람만 있으면 병사가 없다
	local pv = person({ UserId = 372, Name = "visitor" })
	handlers.Ready(pv)
	expect(handlers.Choose(pv, "riven", "구경꾼") ~= nil, "퀘스트가 없는 사람")
	expect(World.jump(pv, "in_cellar") == true, "(확인용으로 옮긴다)")
	run(3)
	eq(standing(), 0, "그 퀘스트를 하지 않는 사람에게는 병사가 나오지 않는다")
	-- 촌장에게 돌려준다: 경험치와 달돈 · 끝
	local elderAt = nil
	for key, scn in SCENES.scenes do
		for _, n in scn.npcs or {} do
			if n.id == def.endNpc then
				elderAt = { key = key, x = n.x, y = n.y }
			end
		end
	end
	expect(elderAt ~= nil, "돌려줄 사람(촌장)이 있다")
	standAt(elderAt.key, elderAt.x + 8, elderAt.y)
	local money0 = hc.money
	handlers.Quest(pc, "complete", "r1m9")
	eq(Quests.state(hc.quests, hc.level, "r1m9"), "done", "촌장에게 돌려준다 — 1지역의 메인을 끝까지 했다")
	expect(hc.money > money0, "보상(달돈)을 받는다")
	-- 끝낸 뒤에도 지하에 내려갈 수 있다(조용한 방 — 비석을 읽는다)
	standAt("in_shrine", down.x, down.y)
	expect(handlers.Travel(pc, "in_cellar") ~= nil, "끝낸 뒤에도 내려갈 수 있다")
	run(3)
	eq(standing(), 0, "끝낸 뒤의 지하에는 병사가 없다")
	World.removePlayer(pc)
	World.removePlayer(pv)
end
