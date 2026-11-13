-- 「달의 계승자」 — 채널(2026-11-12 사용자: "현재 vip 서버를 매크로로 인해서 닫았는데 그래서 사냥터에 사람이 너무 겹치는 현상이 발생한다 그래서 메이플스토리처럼 한 서버에 채널을 두어서
--  채널변경으로 사냥터를 별개로 쓸수있는개념을 도입할수있나?"). sim/channel.luau · server world.luau(roomKeyFor · World.onChannel · leastChannel · resumeScene) · 공방 design/world.js CHANNELS
--  보는 것: ① 셈 — 방 이름 <맵>#c<n> · 채널 1은 맵 이름 그대로 · 사냥 맵만 나뉜다(마을 · 꿈 · 검정 방 · 따로 들어가는 방은 아니다) · 장면의 자료 · 설계의 이름(SCENES.base)
--   ② 서버 — 들어올 때 사람이 가장 적은 채널 · 같은 사냥 맵이어도 채널이 다르면 다른 방 · 마을은 같은 방 · 「이동」으로 그 자리 그대로 옮겨진다 · 10초 안에는 다시 못 바꾼다
--   · 사냥 맵을 옮겨 다녀도 그 채널 · 다시 들어오면 그 맵(방 이름이 아니라)
local Channel = req("ReplicatedStorage/shared/lune/sim/channel")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

-- ① 셈
expect(Channel.COUNT >= 2, "채널이 둘 넘게(" .. Channel.COUNT .. ")")
expect(Channel.splits("hunt"), "사냥 맵(달그림자 사냥터)은 채널마다 나뉜다")
expect(not Channel.splits("town"), "마을은 나뉘지 않는다")
expect(not Channel.splits("dream"), "꿈(튜토리얼)은 나뉘지 않는다")
expect(not Channel.splits("jail"), "검정 방은 나뉘지 않는다")
eq(Channel.key("hunt", 1), "hunt", "채널 1 = 맵 이름 그대로")
eq(Channel.key("hunt", 3), "hunt#c3", "채널 3 = hunt#c3")
eq(Channel.key("town", 3), "town", "마을은 채널과 상관없이 그대로")
eq(Channel.key("hunt#c2", 3), "hunt#c2", "이미 방의 이름이면 그대로")
eq(SCENES.base("hunt#c3"), "hunt", "방 이름 → 설계의 맵 이름")
expect(SCENES.scenes["hunt#c3"] == SCENES.scenes.hunt, "채널의 방은 그 맵의 자료를 쓴다")
local b, n = Channel.split("hunt#c4")
expect(b == "hunt" and n == 4, "방 이름을 맵 · 채널로")
eq(Channel.least({ [1] = 3, [2] = 1, [3] = 1 }), 4, "사람이 가장 적은 채널(아무도 없는 4)")
local fill = Channel.DATA.fill
eq(Channel.pick({ [1] = fill - 1 }), 1, "채널 1에 " .. fill .. "명이 찰 때까지는 채널 1(사람이 적은 서버에서 갈라지지 않게)")
eq(Channel.pick({ [1] = fill, [2] = 2, [3] = 0 }), 3, "찬 뒤로는 사람이 가장 적은 채널")
-- 보스의 문 · 던전의 문이 있는 맵은 나누지 않는다(2026-11-12 사용자 "보스갈때는 신경쓸필요없지?")
local doors = 0
for key, sc in SCENES.scenes do
	for _, p in sc.portals or {} do
		if p.weekly or p.dungeon then
			doors += 1
			expect(not Channel.splits(key), "문이 있는 맵은 채널로 나누지 않는다: " .. key)
		end
	end
end
expect(doors >= 4, "보스 · 던전의 문을 모두 봤다(" .. doors .. ")")
expect(Channel.valid(1) and Channel.valid(Channel.COUNT) and not Channel.valid(0) and not Channel.valid(Channel.COUNT + 1) and not Channel.valid(1.5), "바른 번호")

-- ② 서버
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
	FireAllClients = function() end,
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
local function join(uid, name)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "axion")
	handlers.Chars(p, "enter", made.id)
	local s = World.session(p)
	s.hero.tut.done = true
	return p, s, made.id
end
local pa, a = join(8561, "채널하나")
local pb, b, bcid = join(8562, "채널둘")
eq(a.channel, 1, "처음 들어온 사람 = 채널 1")
eq(b.channel, 1, "사람이 적으면 다음 사람도 채널 1")
b.channel = 2 -- (채널 1이 찬 서버에서 들어온 것처럼)
World.jump(pa, "hunt")
World.jump(pb, "hunt")
eq(a.scene, "hunt", "채널 1의 방 = hunt")
eq(b.scene, "hunt#c2", "채널 2의 방 = hunt#c2")
expect(World.room("hunt") ~= World.room("hunt#c2"), "같은 사냥 맵이어도 채널이 다르면 다른 방(몬스터도 따로)")
World.jump(pa, "town")
World.jump(pb, "town")
eq(a.scene, b.scene, "마을은 같은 방(" .. tostring(a.scene) .. ")")
-- 「이동」: 사냥 맵에 선 채로 채널 1로 → 그 자리 그대로 hunt
World.jump(pb, "hunt")
b.loading = nil
local x0 = b.hero.x
local list = handlers.Channel(pb, "list")
expect(list and list.ok and list.now == 2 and #list.counts == Channel.COUNT and list.splits == true, "목록: 지금 채널 · 채널마다 사람 수 · 여기는 나뉘는 맵")
local r = handlers.Channel(pb, "go", 1)
expect(r and r.ok and r.now == 1, "채널 1로 옮겼다")
eq(b.scene, "hunt", "그 맵의 채널 1 방으로")
expect(math.abs(b.hero.x - x0) <= 16, "그 자리 그대로(" .. x0 .. " → " .. b.hero.x .. ")")
local r2 = handlers.Channel(pb, "go", 3)
expect(r2 and not r2.ok and r2.wait > 0, "바꾸고 10초 안에는 다시 못 바꾼다 — " .. tostring(r2 and r2.why))
for _ = 1, 12 do
	World.tick(1)
end
b.loading = nil
local r3 = handlers.Channel(pb, "go", 3)
expect(r3 and r3.ok, "10초 뒤에는 바꾼다")
eq(b.scene, "hunt#c3", "채널 3의 방")
expect(not handlers.Channel(pb, "go", 99).ok, "없는 채널은 안 된다")
-- 비어도 채널의 사냥터 방은 닫히지 않는다(2026-11-14 사용자 "전체기로 사냥터 몹 잡은다음에 포탈 나갔다가 들어오면 몹이 바로 리젠되어버리는데 이거 악용 사냥법"):
--  잡은 몹은 다시 나타나기까지 남은 시간 그대로(아무도 없는 동안 방이 돌지 않는다) — 전에는 비면 닫혀 다시 들어가면 몹이 가득한 새 방
do
	local room3 = World.room("hunt#c3")
	local m1 = room3.mobs[1]
	expect(m1 ~= nil, "채널 3의 방에 몹이 있다")
	if m1 then
		m1.state, m1.respawn = "gone", 999
	end
	World.jump(pb, "town")
	for _ = 1, 3 do
		World.tick(1)
	end
	b.loading = nil
	World.jump(pb, "hunt")
	eq(b.scene, "hunt#c3", "다시 채널 3의 방으로")
	expect(World.room("hunt#c3") == room3, "비었다 들어와도 같은 방(닫히지 않았다)")
	expect(m1 == nil or m1.state == "gone", "잡은 몹은 다시 들어와도 그대로 없다(바로 다시 나타나지 않는다)")
end
-- 사냥 맵을 옮겨 다녀도 그 채널: 다른 사냥 맵으로
local other = nil
for key in SCENES.scenes do
	if key ~= "hunt" and Channel.splits(key) then
		other = key
		break
	end
end
if other then
	World.jump(pb, other)
	eq(b.scene, other .. "#c3", "다른 사냥 맵도 채널 3의 방(" .. other .. ")")
end
-- 마을에서 바꾸면 다음 사냥 맵부터
for _ = 1, 12 do
	World.tick(1)
end
World.jump(pb, "town")
b.loading = nil
local r4 = handlers.Channel(pb, "go", 2)
expect(r4 and r4.ok and r4.splits == false, "마을에서도 바꾼다(여기는 나뉘지 않는 곳)")
eq(b.scene, "town", "마을은 그대로")
World.jump(pb, "hunt")
eq(b.scene, "hunt#c2", "다음 사냥 맵부터 채널 2")
-- 보스의 문 앞: 문의 맵은 채널과 상관없이 같은 방 — 채널 4의 사람도 문의 맵에서는 모두와 같은 방 · 「문 앞」이다
do
	local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
	local bb = Weekly.boss("shadowarcher")
	if bb then
		World.jump(pb, bb.door.scene)
		eq(b.scene, bb.door.scene, "그림자 사수의 문의 맵 = 채널과 상관없이 같은 방")
		b.hero.x = bb.door.x
		expect(World.atDoor(b, bb), "보스 문 앞")
	end
end
-- 파티: 파티원이 있는 사냥 맵에 들어가면 그 사람의 채널로 따라간다(흩어져 들어와도 같은 방)
World.jump(pa, "town")
World.jump(pb, "town")
handlers.Party(pa, "invite", pb.UserId) -- (초대는 같은 방에서 — 마을은 채널로 나뉘지 않는다)
handlers.Party(pb, "accept")
World.jump(pa, "hunt")
eq(a.scene, "hunt", "파티장은 채널 1의 사냥터")
World.jump(pb, "hunt")
eq(b.scene, "hunt", "채널 2였던 파티원이 들어오면 파티장의 방(채널 1)으로")
eq(b.channel, 1, "그 사람의 채널도 1로")
for _ = 1, 12 do
	World.tick(1)
end
b.loading = nil
local r5 = handlers.Channel(pb, "go", 4)
expect(r5 and r5.ok and b.scene == "hunt#c4", "스스로 바꾸면 파티원이 있어도 고른 채널(" .. tostring(b.scene) .. ")")
handlers.Party(pb, "leave")
-- 다시 들어오면 그 맵(방 이름이 아니라) — 채널은 그때 다시 정한다
b.hero.level = 5 -- (Lv.1 새 캐릭터는 늘 사제의 사당에서 시작한다 — Quests.firstScene)
b.dirty = true
World.removePlayer(pb)
handlers.Ready(pb)
handlers.Chars(pb, "enter", bcid)
local b2 = World.session(pb)
eq(SCENES.base(b2.scene), "hunt", "다시 들어오면 그 사냥 맵(" .. tostring(b2.scene) .. ")")
World.removePlayer(pa)
World.removePlayer(pb)
