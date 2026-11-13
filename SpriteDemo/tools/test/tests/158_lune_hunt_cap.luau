-- 「달의 계승자」 — 하루 사냥 시간(2026-11-12 사용자: "신지역 공개하고 6시간 이상 사냥하면 경험치, 달돈,달가루 이런거 사냥파밍 다 불가능하게 해줘 자원이 안뜨게
--  사냥가능 시간이 모두 소진되었습니다 이렇게 서버가 종료됬다가 꺼진다고 시간이 다시 채워진다거나 그러면 안되고 절대 시간으로 처리되어야한다").
--  공방 design/world.js HUNT_CAP · server world.luau World.huntCapStep · sim/room.luau(경험치 · 달돈 · 떨어지는 것) · 매크로 기록 days[오늘].m(계정에 저장)
--  보는 것: ① 남은 분 알림 · 다 쓰면 사냥 맵에서 hero.huntCap · 화면에 「다 썼다」 ② 방이 경험치 0 · 달돈 · 장비 · 달가루 없음 ③ 마을에서는 표시가 없다
--   ④ 저장했다 다시 들어와도(서버가 꺼졌다 켜진 것과 같다) 그대로 ⑤ 다음 날(한국 시간 0시) 다시 채워진다 ⑥ 관리자 계정은 빼고 ⑦ 윤슬 호수가 열렸다
local handlers, fired = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end,
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
local disk, book = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local WMD = req("ReplicatedStorage/shared/lune/data/worldmap.generated")
local HC = SCENES.huntCap
eq(HC.minutes, 360, "하루 6시간(360분 — 사용자의 숫자)")
-- 2026-11-13 사용자 "사냥제한은 롤백하자" → 꺼 두었다(HC.on = false): 다 써도 표시 · 알림이 없다. 아래는 켰을 때의 셈을 그대로 본다(시험 안에서만 켠다)
eq(HC.on, false, "사냥 시간 제한은 꺼져 있다(롤백)")
HC.on = true
local function now0()
	return 1700000000 + math.floor(clock.now) -- (서버의 모듈이 보는 시계 — mock.luau osMock)
end
World.start()
local function enter(uid, name)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "axion")
	handlers.Chars(p, "enter", made.id)
	local s = World.session(p)
	s.hero.tut.done = true
	s.hero.level = 20
	return p, s, made.id
end
local p, s, cid = enter(8581, "여섯시간")
World.jump(p, "hunt")
World.tick(1.1)
local function lastTime()
	local v = nil
	for _, f in fired do
		if f.name == "HuntTime" and f.player == p then
			v = f.args[1]
		end
	end
	return v
end
local function setUsed(m)
	local key = Macro.dayKey(now0())
	s.macro.saved.days[key] = s.macro.saved.days[key] or {}
	s.macro.saved.days[key].m = m
end

-- ① 남은 분 · 다 쓴다
setUsed(HC.minutes - 1)
World.tick(1.1)
local v = lastTime()
expect(v and v.left == 1 and not v.over and v.hunt, "359분: 1분 남았다(사냥 맵)")
eq(s.hero.huntCap, nil, "아직 보상이 나온다")
setUsed(HC.minutes)
World.tick(1.1)
v = lastTime()
expect(v and v.left == 0 and v.over and v.crossed, "360분: 「사냥 가능 시간이 모두 소진되었습니다」(방금 다 썼다)")
eq(s.hero.huntCap, true, "사냥 맵에서 보상 없음 표시")

-- ② 방이 주지 않는다
local room = World.room(s.scene)
local mob = nil
for _, m in room.mobs do
	mob = m
	break
end
expect(mob ~= nil, "사냥터에 몬스터가 있다")
if mob then
	eq(room:dropFor(s.hero, mob), nil, "달돈이 떨어지지 않는다")
	local loot = room:lootFor(s.hero, mob)
	eq(#loot, 0, "장비 · 재료 · 달가루가 떨어지지 않는다")
	-- 실제로 잡아 본다: 경험치 0 · 달돈 · 떨어지는 것 없음
	local xp0, lv0 = s.hero.xp, s.hero.level
	local out = { hits = {}, kills = {} }
	room:strike(s.hero, mob, 1e12, mob.x, nil, out)
	local k = out.kills[1]
	expect(k ~= nil, "잡았다")
	if k then
		eq(k.xp, 0, "잡아도 경험치 0")
		expect(k.drop == nil and #(k.loot or {}) == 0, "잡아도 달돈 · 장비 · 달가루 없음")
	end
	expect(s.hero.xp == xp0 and s.hero.level == lv0, "경험치 그대로")
end

-- ③ 마을: 표시 없음(보상의 일이 없는 곳)
World.jump(p, "town")
World.tick(1.1)
eq(s.hero.huntCap, nil, "마을에서는 사냥터의 표시가 없다")
v = lastTime()
expect(v and v.over and not v.hunt, "화면: 다 썼다 · 지금은 사냥 맵이 아니다(띠 없음)")

-- ④ 저장 → 다시 들어온다(서버가 꺼졌다 켜진 것과 같다): 그대로
World.jump(p, "hunt")
World.tick(1.1)
World.removePlayer(p)
handlers.Ready(p)
handlers.Chars(p, "enter", cid)
s = World.session(p)
World.jump(p, "hunt")
World.tick(1.1)
World.tick(1.1)
eq(s.hero.huntCap, true, "다시 들어와도 다 쓴 그대로(계정에 저장된 오늘의 사냥한 분)")

-- ⑤ 다음 날(한국 시간 0시): 다시 채워진다
local day0 = Macro.dayKey(now0())
local guard = 0
while Macro.dayKey(now0()) == day0 and guard < 30 do
	clock.now += 3600
	guard += 1
end
World.tick(1.1)
v = lastTime()
expect(v and v.left == HC.minutes and not v.over, "다음 날: 다시 360분")
eq(s.hero.huntCap, nil, "다음 날: 보상이 나온다")

-- ⑥ 관리자 계정은 빼고
local pa, sa = enter(10311679477, "관리시험꾼")
World.jump(pa, "hunt")
local key = Macro.dayKey(now0())
World.tick(1.1)
sa.macro.saved.days[key] = { m = HC.minutes + 100 }
World.tick(1.1)
eq(sa.hero.huntCap, nil, "관리자는 다 써도 보상이 나온다(시험)")

-- ⑦ 윤슬 호수가 열렸다(2026-11-12 사용자 "신지역 공개하고")
local r5 = WMD.regions and WMD.regions.r5
expect(r5 ~= nil and not r5.closed, "월드맵의 윤슬 호수가 닫혀 있지 않다")
World.removePlayer(p)
World.removePlayer(pa)

-- 꺼 두면(지금): 다 써도 사냥터의 표시가 없다
do
	HC.on = false
	local p2, s2 = enter(8582, "제한없음")
	World.jump(p2, "hunt")
	World.tick(1.1)
	s2.macro.saved.days[Macro.dayKey(now0())] = { m = HC.minutes + 50 }
	World.tick(1.1)
	eq(s2.hero.huntCap, nil, "꺼 두면 6시간을 넘겨도 보상이 나온다")
	World.removePlayer(p2)
end
