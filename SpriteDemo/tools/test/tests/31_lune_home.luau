-- 「달의 계승자」 — 돌아가는 마을: 쓰러졌을 때 마지막으로 들른 마을 · 작은 마을에서 일어난다(없으면 시작 마을).
--  마을 사이를 바로 오가는 기능은 없다 — 사용자 2026-10-11: "달빛문같은걸 넣지는 않습니다 … 지금은 걸어다닌다고 보면됩니다"(전에 넣었던 명령 Gate · 캐릭터의 towns는 걷어냈다).
--  설계: 공방 js/lune/design/journey.js의 HOMES → data/scenes.generated.luau의 homes.
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local PACKETS = req("ReplicatedStorage/shared/lune/net/packets")

-- ---- 1) 자료 ----
expect(SCENES.homes[SCENES.start] == true, "시작 마을은 돌아가는 마을이다")
expect(SCENES.homes.town and SCENES.homes.r1bv, "초승달 마을 · 고갯마루 주막")
expect(not SCENES.homes.r1cc and not SCENES.homes.hunt and not SCENES.homes.in_shrine, "쉼터(수비대 야영지) · 사냥터 · 건물 안은 아니다")
for key in SCENES.homes do
	local sc = SCENES.scenes[key]
	expect(sc ~= nil and #(sc.mobs or {}) == 0, "돌아가는 마을에는 몬스터가 없다 " .. key)
end
local packets = PACKETS.list or PACKETS
eq(packets.Gate, nil, "마을 사이를 바로 오가는 명령은 없다")

-- ---- 2) 서버 ----
local handlers = {}
local sent = {}
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
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
World.start()
eq(handlers.Gate, nil, "서버도 그 명령을 듣지 않는다")

local p = { UserId = 4101, Name = "길손4101", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "길손4101", "riven")
local first = handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local h = s.hero
eq(SCENES.base(first.scene), "dream", "새 캐릭터는 꿈(튜토리얼)에서 시작한다") -- (꿈은 사람마다 따로 된 방 — dream#번호 · 2026-10-21)
-- 꿈에서 쓰러지면 꿈의 처음으로(마을로 나가지 않는다 · 그 꿈의 방 그대로)
local dreamRoom = s.scene
h.alive, h.hp, h.revive = false, 0, 0
handlers.Return(p)
expect(h.alive and s.scene == dreamRoom, "꿈에서 쓰러지면 그 꿈으로 — " .. tostring(s.scene))
World.wake(p)
eq(s.scene, "in_shrine", "꿈에서 깨면 사당 안이다")
eq(h.home, nil, "사당 안은 마을이 아니다 — 돌아갈 마을이 아직 없다")
-- 아직 마을에 들르지 않고 쓰러지면 시작 마을에서 일어난다
h.alive, h.hp, h.revive = false, 0, 0
handlers.Return(p)
expect(h.alive and s.scene == SCENES.start, "돌아갈 마을이 없으면 시작 마을 — " .. tostring(s.scene))
eq(h.home, "town", "초승달 마을에 들른 것이 됐다")
handlers.Move(p, h.x, h.y, 1)
-- 주막에 들른 뒤 그 너머의 사냥터에서 쓰러지면 주막에서 일어난다
Hero.setLevel(h, 30)
expect(World.jump(p, "r1bv"), "주막에 들른다")
eq(h.home, "r1bv", "돌아올 곳이 주막이 된다")
expect(World.jump(p, "r1b3"), "주막 너머의 사냥터로(무너진 다리 — 망루 아래는 2026-10-15에 지웠다)")
eq(h.home, "r1bv", "사냥터는 돌아올 곳이 아니다 — 마지막으로 들른 마을 그대로")
h.alive, h.hp, h.revive = false, 0, 0
handlers.Return(p)
expect(h.alive and s.scene == "r1bv", "쓰러지면 마지막으로 들른 마을(주막)에서 일어난다 — " .. tostring(s.scene))
expect(h.x == SCENES.scenes.r1bv.spawn.x and h.y == SCENES.scenes.r1bv.spawn.y, "그 마을의 시작 자리에")
handlers.Move(p, h.x, h.y, 1)
-- 쉼터(수비대 야영지)는 마을이 아니다
World.jump(p, "r1cc")
eq(h.home, "r1bv", "쉼터에 들러도 돌아올 곳은 그대로")
-- 저장: 돌아올 곳은 남고, 들른 마을의 목록(걷어낸 빠른 이동)은 저장하지도 화면에 보내지도 않는다
local packed = Hero.pack(h)
eq(packed.home, "r1bv", "저장에 돌아올 곳이 남는다")
eq(packed.towns, nil, "들른 마을의 목록은 저장하지 않는다")
eq(Hero.view(h).towns, nil, "화면에도 보내지 않는다")
eq(Hero.unpack(4101, packed).home, "r1bv", "다시 들어와도 그대로다")
-- 옛 저장(빠른 이동이 있던 하루 동안의 것): towns가 들어 있어도 탈 없이 읽고 버린다
packed.towns = { "town", "r1bv", 5 }
local back = Hero.unpack(4101, packed)
expect(back ~= nil and back.towns == nil and back.home == "r1bv", "옛 저장의 towns는 읽지 않는다")
-- 깨진 저장: 없는 장면 · 마을이 아닌 장면이 돌아올 곳이면 시작 마을로 돌려보낸다
for _, bad in { "nowhere", "hunt", 7 } do
	packed.home = bad
	local hb = Hero.unpack(4101, packed)
	expect(hb ~= nil, "깨진 home도 읽기는 한다 " .. tostring(bad))
	s.hero = hb
	World.jump(p, "r1b4") -- 사냥터에 선다(place는 사냥터에서 home을 건드리지 않는다)
	hb.alive, hb.hp, hb.revive = false, 0, 0
	handlers.Return(p)
	expect(hb.alive and s.scene == SCENES.start, "돌아올 곳이 깨졌으면 시작 마을 — " .. tostring(bad) .. " → " .. tostring(s.scene))
end

-- ---- 3) 다시 들어오면 마지막으로 있던 맵에서(2026-10-16 밤 — 사용자: "게임을 시작하면 항상 초승달마을에서 시작합니다") ----
--  메이플처럼 나갔던 맵의 시작 자리 · 배 위였으면 닿는 곳 · 토벌의 방 · 스토리 보스의 방 · 꿈이면 그 맵에서 가장 가까운 마을 · 없어진 맵이면 마지막 마을
do
	local Voyage = req("ReplicatedStorage/shared/lune/sim/voyage")
	local p2 = { UserId = 4102, Name = "길손4102", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	handlers.Ready(p2)
	local mk = handlers.Chars(p2, "create", "길손4102", "axion")
	handlers.Chars(p2, "enter", mk.id)
	local s2 = World.session(p2)
	World.wake(p2) -- 꿈에서 깬다(튜토리얼을 마친다)
	local function relog(prep: () -> ()?)
		if prep then
			prep()
		end
		World.removePlayer(p2) -- 저장하고 나간다
		handlers.Ready(p2)
		return handlers.Chars(p2, "enter", mk.id), World.session(p2)
	end
	-- 첫 퀘스트를 끝낸 캐릭터로(새 캐릭터는 사당에서 시작한다)
	local Q = req("ReplicatedStorage/shared/lune/sim/quests")
	local firstId = Q.FIRST and Q.FIRST.quest or nil
	if firstId then
		s2.hero.quests[firstId] = { done = true, c = {} }
	end
	Hero.setLevel(s2.hero, 30)
	World.jump(p2, "r1bv")
	World.jump(p2, "r1b3")
	local got, ss = relog()
	eq(ss.scene, "r1b3", "나갔던 사냥터(무너진 다리)에서 다시 시작한다")
	eq(got.scene, "r1b3", "화면에도 그 장면")
	eq(ss.hero.x, SCENES.scenes.r1b3.spawn.x, "그 맵의 시작 자리")
	World.jump(p2, "ct_inn")
	got, ss = relog()
	eq(ss.scene, "ct_inn", "건물 안(여관)에서 나갔으면 그 안에서")
	local r = Voyage.route("town", "captain")
	got, ss = relog(function()
		World.jump(p2, r.ship)
	end)
	eq(ss.scene, r.to, "배 위에서 나갔으면 배가 닿는 곳(은달 항구)")
	eq(ss.hero.x, r.at[1] * SCENES.tile, "부두의 내리는 자리")
	got, ss = relog(function()
		World.jump(p2, "rf1#9")
	end)
	eq(ss.scene, SCENES.scenes.rf1.ret, "토벌의 방에서 나갔으면 가장 가까운 마을(은달 항구)")
	got, ss = relog(function()
		World.jump(p2, "r1c4")
	end)
	expect(ss.scene == SCENES.scenes.r1c4.ret and SCENES.homes[ss.scene], "스토리 보스의 방에서 나갔으면 가장 가까운 마을 — " .. tostring(ss.scene))
	got, ss = relog(function()
		World.jump(p2, "r2bs")
		s2 = World.session(p2)
		s2.hero.last = "nowhere_old_map"
	end)
	eq(ss.scene, "r2bs", "없어진 맵이면 마지막으로 들른 마을(기사단 본당)")
	got, ss = relog(function()
		World.session(p2).hero.last = nil
	end)
	eq(ss.scene, "r2bs", "마지막 맵이 없는 옛 저장 = 마지막으로 들른 마을")
	-- 뺀 맵(반달 나루 r2t — 2026-10-16 밤)에 남은 저장: 마지막 맵 · 마지막으로 들른 마을 = 그 자리를 대신하는 은달 항구(scenes의 gone)
	got, ss = relog(function()
		local h = World.session(p2).hero
		h.last, h.home = "r2t", "r2t"
	end)
	eq(ss.scene, "ct", "반달 나루에서 나간 저장은 은달 항구에서 시작한다")
	eq(ss.hero.home, "ct", "마지막으로 들른 마을(반달 나루)도 은달 항구로")
	local packed2 = Hero.pack(ss.hero)
	expect(typeof(packed2.last) == "string", "저장에 마지막 맵이 들어간다")
	World.removePlayer(p2)
end
