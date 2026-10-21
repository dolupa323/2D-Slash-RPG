-- 「달의 계승자」 — 파티마다 따로 들어가는 장면(scenes의 inst — 스토리 보스의 방 · 이야기의 방 · 꿈 · 서버 world.luau roomKeyFor).
--  사용자 2026-10-21: "파티마다 따로 되어야합니다. 지금 왜냐면 지금 어떤사람은 성벽거인 퀘스트고 어떤사람은 망루 꼭대기 퀘스트인데 공간을 같이써버리면
--   만약에 한서버에 100명 있으면 차례를 엄청나게 기다려야하는겁니다. 설계부터가 잘못됬어요 솔로게임처럼되어있습니다."
--  보는 것: ① 자료 — 망루 꼭대기 · 사당 지하 · 꿈에 inst ② 파티가 아닌 사람은 저마다 다른 방 · 같은 파티는 같은 방 ③ 여럿이 같은 보스 퀘스트를 해도 방마다 보스가 서 있다(기다리지 않는다)
--   ④ 문으로 들어가고 나오기(나오면 그 장면의 문 앞) ⑤ 빈 방은 닫힌다 ⑥ 방 이름으로도 퀘스트 · 길 · 장면을 그 장면으로 본다 ⑦ 새 캐릭터의 꿈도 사람마다 따로
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Tutorial = req("ReplicatedStorage/shared/lune/sim/tutorial")
local WM = req("ReplicatedStorage/shared/lune/ui/worldmap")
local Cine = req("ReplicatedStorage/shared/lune/cine")

-- ① 자료
for _, key in { "r1c4", "in_cellar", Tutorial.SCENE } do
	eq(SCENES.scenes[key].inst, "party", key .. ": 파티마다 따로 들어가는 장면")
end
for _, key in { "town", "hunt", "r1c3", "in_shrine" } do
	eq(SCENES.scenes[key].inst, nil, key .. ": 여느 장면(모두가 같이 쓴다)")
end
eq(SCENES.base("r1c4#12"), "r1c4", "방 이름 → 장면")
eq(SCENES.base("r1c4"), "r1c4", "장면은 그대로")
expect(Tutorial.isDream(Tutorial.SCENE .. "#3") and Tutorial.isDream(Tutorial.SCENE) and not Tutorial.isDream("town"), "꿈의 방도 꿈이다")

-- ⑥ 방 이름으로도 그 장면으로 본다
do
	local book = { r1m7 = { done = false, c = {} } }
	expect(Quests.wantsKill(book, "towerlieutenant", "r1c4#7"), "방에서도 그 퀘스트의 보스가 필요하다")
	eq(#Quests.onKill(book, "towerlieutenant", "r1c4#7"), 1, "방에서 잡아도 센다")
	local path = WM.path("r1c4#7", "r1c4")
	expect(path ~= nil and #path == 1, "방에서 그 장면으로 가는 길 = 제자리")
	local _ = Cine
end

-- ②~⑤ 서버
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
local DT = 1 / 20
local function tick(seconds: number)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		World.tick(DT)
	end
end
local people = {}
local function person(id: number)
	local p = { UserId = id, Name = "방" .. id, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	handlers.Ready(p)
	local c = handlers.Chars(p, "create", "방" .. id, "riven")
	handlers.Chars(p, "enter", c.id)
	table.insert(people, p)
	return p, World.session(p)
end

-- ⑦ 새 캐릭터의 꿈: 사람마다 따로
local pa, sa = person(6901)
local pb, sb = person(6902)
local pc, sc = person(6903)
expect(Tutorial.isDream(sa.scene) and Tutorial.isDream(sb.scene), "새 캐릭터는 꿈에서 시작한다")
expect(sa.scene ~= sb.scene and sa.scene ~= Tutorial.SCENE, "꿈은 사람마다 따로 된 방 — " .. sa.scene .. " · " .. sb.scene)
for _, p in { pa, pb, pc } do
	World.wake(p)
end
tick(0.2)
eq(World.room(sa.scene) and true, true, "(깨어난 곳의 방)")

-- ② 같은 파티는 같은 방 · 남은 다른 방
handlers.Party(pa, "invite", 6902)
handlers.Party(pb, "accept")
expect(World.sameParty(6901, 6902), "a · b는 파티")
expect(not World.sameParty(6901, 6903), "c는 남")
World.jump(pc, "r1c4")
World.jump(pa, "r1c4")
World.jump(pb, "r1c4")
expect(SCENES.base(sa.scene) == "r1c4" and sa.scene ~= "r1c4", "a는 따로 된 방에 — " .. sa.scene)
eq(sb.scene, sa.scene, "파티원 b는 a의 방으로")
expect(sc.scene ~= sa.scene and SCENES.base(sc.scene) == "r1c4", "남인 c는 제 방으로 — " .. sc.scene)
expect(not World.hasRoom("r1c4"), "모두가 같이 쓰는 방은 없다")

-- ③ 여럿이 같은 보스 퀘스트: 방마다 보스가 서 있다(차례를 기다리지 않는다)
local solos = {}
for i = 1, 6 do
	local p, s = person(6910 + i)
	World.wake(p)
	Hero.setLevel(s.hero, 25)
	Quests.finishBefore(s.hero.quests, "r1m7")
	expect(Quests.accept(s.hero.quests, s.hero.level, "r1m7"), "「성벽 거인」을 받는다")
	World.jump(p, "r1c4")
	table.insert(solos, s)
end
tick(1.5)
local seen = {}
for i, s in solos do
	expect(not seen[s.scene], ("%d째 사람의 방이 남과 겹치지 않는다"):format(i))
	seen[s.scene] = true
	local room = World.room(s.scene)
	local boss = room and room.bosses and room.bosses[1]
	expect(boss ~= nil and not boss.away and boss.state ~= "gone", ("%d째 사람의 방에도 성벽 거인이 바로 서 있다"):format(i))
end

-- ④ 문으로 오르내리기
do
	local p, s = person(6930)
	World.wake(p)
	World.jump(p, "r1c3")
	local door
	for _, pt in SCENES.scenes.r1c3.portals do
		if pt.to == "r1c4" then
			door = pt
		end
	end
	s.trust, s.stale = true, nil
	s.hero.x, s.hero.y = door.x, door.y
	local trip = handlers.Travel(p, "r1c4")
	expect(trip ~= nil and trip.scene == s.scene and SCENES.base(trip.scene) == "r1c4" and trip.scene ~= "r1c4", "망루 3층의 문으로 올라가면 제 방 — " .. tostring(trip and trip.scene))
	expect(trip.room ~= nil and trip.room.key == s.scene, "그 방의 모습이 온다")
	local back = SCENES.scenes.r1c4.portals[1]
	s.trust, s.stale = true, nil
	s.hero.x, s.hero.y = back.x, back.y
	local room = s.scene
	local down = handlers.Travel(p, back.to)
	expect(down ~= nil and s.scene == "r1c3", "내려가면 망루 3층")
	expect(math.abs(s.hero.x - door.x) <= 1 and math.abs(s.hero.y - door.y) <= 1, "올라갔던 문 앞에 선다")
	tick(0.2)
	expect(not World.hasRoom(room), "⑤ 아무도 없는 방은 닫힌다")
end

-- ⑤ 파티원이 남아 있으면 방은 그대로
do
	local room = sa.scene
	World.jump(pa, "r1c3")
	tick(0.2)
	expect(World.hasRoom(room), "b가 남아 있으면 방은 그대로")
	World.jump(pa, "r1c4")
	eq(sa.scene, room, "a가 다시 올라오면 b가 있는 그 방")
	World.jump(pa, "r1c3")
	World.jump(pb, "r1c3")
	tick(0.2)
	expect(not World.hasRoom(room), "둘 다 나가면 닫힌다")
end
for _, p in people do
	World.removePlayer(p)
end
