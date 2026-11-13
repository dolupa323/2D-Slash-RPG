-- 「달의 계승자」 — 보스 연습(2026-11-10 — 공방 design/weekboss.js의 practice · sim/weekly.luau · 서버 world.luau "Week" · 보스 창 client/lune/ui/weeklyWindow.luau).
--  사용자: "보스 연습모드도 추가해야해 내가 그 주에 그 보스를 클리어해도 도전할수있게 보상은 안주는 그냥 연습모드인거지"
--  메이플의 연습 모드를 따른다(넥슨 공식 가이드): 그 주의 격파와 상관없이 · 입장 조건(보스 퀘스트 · 레벨)은 같다 · 보상 · 경험치 · 퀘스트 없음 · 하루 20번(모든 보스 합)
--  보는 것: ① 방 이름(#wpn · #wph) ② 이번 주 격파한 뒤에도 연습은 들어간다 · 격파는 막힌다 ③ 하루 20번 · 다음 날 다시 · 저장
--   ④ 연습으로 격파: 이번 주 격파 · 보상의 방 없이 back초 뒤 문 앞으로 · 보스를 잡은 것으로 퀘스트에 세지 않는다 ⑤ 파티는 사람마다 하나
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local TICK = 1 / 20

local handlers = {}
local revives = {} -- [UserId] = 마지막으로 받은 Revive(2026-11-12 — 파티가 한꺼번에 들어가는가)
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, e)
		if name == "Revive" then
			revives[player.UserId] = e
		end
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
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local Rift = req("ReplicatedStorage/shared/lune/sim/rift")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end

local B = Weekly.boss("shadowarcher")
-- 서버의 시계: 모듈은 시험의 os.time(1,700,000,000 + 흐른 초 — tools/test/run.py의 osMock)을 쓴다 · 시험 코드의 os.time은 진짜 시계라 그 값으로 견준다(주 · 날이 바뀌지 않는 몇 분 안)
local SNOW = 1_700_000_000 + 60
local P = Weekly.PRACTICE
eq(P.perDay, false, "횟수 제한 없음(2026-11-10 사용자 \"연습모드 횟수 무한으로해야해\" — 전에는 하루 20번)")

-- ① 방 이름
do
	eq(Weekly.key(B, "normal", 7, true), B.room .. "#wpn7", "연습 노말의 방 = #wpn")
	eq(Weekly.key(B, "hard", 7, true), B.room .. "#wph7", "연습 하드의 방 = #wph")
	eq(Weekly.key(B, "normal", 7), B.room .. "#wn7", "격파의 방은 그대로 #wn")
	local m, b, p = Weekly.ofKey(B.room .. "#wph7")
	expect(m == "hard" and b == B and p == true, "연습의 방을 읽는다(하드 · 그 보스 · 연습)")
	local m2, _, p2 = Weekly.ofKey(B.room .. "#wn7")
	expect(m2 == "normal" and p2 == false, "격파의 방은 연습이 아니다")
	eq(Weekly.stageKey("r3d5#wpn12", "r3d6"), "r3d6#wpn12", "용암 거인의 다음 방도 연습 그대로")
end

local uid = 14100
local function join(class: string, level: number)
	uid += 1
	local name = "연습" .. uid
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, level, Hero.jobAt(level))
	s.hero.quests[B.quest] = { done = true, c = {} }
	s.hero.hp = s.hero.maxHp
	World.jump(p, B.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = B.door.x
	return p, s
end
local function toDoor(p, s)
	World.jump(p, B.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = B.door.x
	s.hero.hp, s.hero.alive = s.hero.maxHp, true
end
local function bossOf(key)
	for _, m in World.room(key).bosses do
		if m.kind == B.id then
			return m
		end
	end
	return nil
end

-- ②④ 이번 주에 격파한 뒤: 격파는 막히고 연습은 들어간다 · 연습으로 격파해도 기록 · 보상 없이 문 앞으로
do
	local p, s = join("riven", 60)
	local now = SNOW
	Weekly.mark(s.hero.rift, B.id, "normal", now)
	local r0 = handlers.Week(p, "enter", B.id, "normal", false, false)
	expect(r0 and not r0.ok and r0.why == Weekly.DATA.words.done, "이번 주에 격파했다: 격파로는 못 들어간다")
	local before = Weekly.practiceLeft(s.hero.rift, now)
	expect(before >= 1e6, "남은 연습 = 제한 없음")
	local r = handlers.Week(p, "enter", B.id, "normal", false, true)
	expect(r and r.ok, "연습으로는 들어간다(이번 주 격파와 상관없이)")
	local key = s.scene
	expect(string.find(key, "#wpn", 1, true) ~= nil, "연습의 방 " .. key)
	expect(Weekly.practiceLeft(s.hero.rift, now) >= 1e6, "써도 그대로(제한 없음)")
	run(1)
	local room = World.room(key)
	expect(room.weekly and room.weekly.practice == true, "방이 연습인 것을 안다")
	eq(Weekly.roomView(room).practice, true, "방의 상태(WeekView)에 연습이 실린다 — 화면 「노말 연습 · 15:00」")
	local m = bossOf(key)
	expect(m ~= nil, "보스가 섰다(그 난이도 그대로)")
	-- 격파
	local weekBefore = table.clone(s.hero.rift.week)
	s.hero.x = m.x - 20
	room:strike(s.hero, m, m.hp + 10, m.x, {}, { hits = {}, kills = {} })
	expect(room.weekly.state == "clear", "격파")
	expect(room.weekly.boxAt == nil and room.weekly.backAt ~= nil, "보상의 방이 없고 문 앞으로 갈 때가 적혔다")
	run(1)
	eq(s.hero.rift.week[B.id].w, weekBefore[B.id].w, "이번 주의 격파 기록은 그대로(연습은 적지 않는다)")
	run(P.back + 0.5)
	eq(SCENES.base(s.scene), B.door.scene, ("back(%d)초 뒤 보스의 문 앞으로 — 보상의 방이 아니다"):format(P.back))
	World.removePlayer(p)
end

-- ④ 보스를 잡은 것으로 퀘스트 · 업적에 세지 않는다(kills의 credit이 비었다)
do
	local p, s = join("riven", 60)
	local r = handlers.Week(p, "enter", B.id, "normal", false, true)
	expect(r and r.ok, "연습 입장")
	run(1)
	local room = World.room(s.scene)
	local m = bossOf(s.scene)
	local out = { hits = {}, kills = {} }
	room:strike(s.hero, m, m.hp + 10, m.x, {}, out)
	local k = out.kills[1]
	expect(k ~= nil and #k.credit == 0 and #k.gains == 0, "연습에서 잡은 보스: 퀘스트 · 업적의 셈 없음")
	toDoor(p, s)
	-- 격파의 방에서는 센다(비교)
	local r2 = handlers.Week(p, "enter", B.id, "normal", false, false)
	expect(r2 and r2.ok, "이번 주 아직 안 했으면 격파로 들어간다")
	run(1)
	local room2 = World.room(s.scene)
	local m2 = bossOf(s.scene)
	local out2 = { hits = {}, kills = {} }
	room2:strike(s.hero, m2, m2.hp + 10, m2.x, {}, out2)
	expect(out2.kills[1] and #out2.kills[1].credit >= 1, "격파의 방에서 잡은 보스는 센다(그대로)")
	World.removePlayer(p)
end

-- ③ 하루 20번 · 다음 날 다시 · 저장
do
	local h = Hero.new(1, "riven")
	local now = 1_800_000_000
	for _ = 1, 50 do
		Weekly.practiceUse(h.rift, now)
	end
	h.quests[B.quest] = { done = true, c = {} }
	Hero.setLevel(h, 60)
	eq(Weekly.canEnter(h, B, "normal", now, true), nil, "쉰 번을 써도 연습은 들어간다(제한 없음)")
	eq(Weekly.canEnter(h, B, "normal", now, false), nil, "격파(이번 주 아직)는 그대로 들어간다")
	local v = Weekly.view(h.rift, now)
	expect(v.prac >= 1e5 and v.pracMax == 0, "보스 창에 보내는 것: 남은 연습 = 큰 수(무한을 싣지 않는다) · 하루의 수 0 = 제한 없음")
end

-- ⑤ 파티: 들어간 사람마다 하나
do
	local pa, a = join("riven", 60)
	local pb, b = join("axion", 60)
	handlers.Party(pa, "invite", pb.UserId)
	handlers.Party(pb, "accept")
	a.trust, a.stale = true, nil
	a.hero.x = B.door.x
	local r = handlers.Week(pa, "enter", B.id, "normal", true, true)
	expect(r and r.ok, "파티로 연습")
	eq(b.scene, a.scene, "둘 다 같은 연습의 방")
	-- 2026-11-12 사용자 "보스입장하고 파티원이 바로 안보여": 먼저 옮겨진 사람(방장)이 받은 방 목록에도 파티원이 이미 있다(World.moveGroup — 화면의 막이 파티원 그림까지 받은 뒤에 걷힌다)
	local ra = revives[pa.UserId]
	local names = {}
	for _, w in (ra and ra.room and ra.room.who) or {} do
		names[w.id] = true
	end
	expect(names[a.hero.id] and names[b.hero.id], "방장이 받은 방 목록에 둘 다 있다(전에는 저만)")
	local now = SNOW
	expect(Weekly.practiceLeft(a.hero.rift, now) >= 1e6 and Weekly.practiceLeft(b.hero.rift, now) >= 1e6, "파티로 들어가도 제한 없음")
	World.removePlayer(pa)
	World.removePlayer(pb)
end
local _ = COMBAT
