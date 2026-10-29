-- 「달의 계승자」 — 주간 보스의 데스 카운트(2026-10-27).
--  사용자: "보스 데스카운트는 사람마다 개인 데스카운트 5야 / 무니 소생같은건 데스카운트 소모안하고 살아나는거고"
--  보는 것: ① 싸우는 동안 쓰러져 「일어나기」(Return)를 누르면 하나 줄고 그 방(같은 방 번호)의 처음 자리에서 일어난다 — 마을로 가지 않는다
--   ② 다섯째에 쓰러지면 「나가기」 — 0이 되고 보스의 문 앞(그림자 능선)으로 ③ 사람마다 따로 센다 ④ 무니의 소생으로 일어나면 줄지 않는다
--   ⑤ 방의 상태(WeekView)에 사람마다의 남은 수가 실린다
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local TICK = 1 / 20

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
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end

local B = Weekly.boss("shadowarcher")
local MAX = Weekly.DATA.lives
eq(MAX, 5, "데스 카운트는 사람마다 5")

local uid = 10500
local function join(class: string, level: number)
	uid += 1
	local name = "데스" .. uid
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
-- 쓰러뜨린다(보스의 한 방 대신 — 들어선 뒤의 보호도 걷는다) · 쓰러진 상자가 뜨는 때(reviveWait)까지 기다린다
local function fall(s)
	s.hero.invuln, s.hero.inCine = 0, false
	Hero.hurt(s.hero, s.hero.hp + s.hero.maxHp)
	expect(not s.hero.alive, "쓰러졌다")
	run(COMBAT.rules.reviveWait + 0.2)
end

-- ①②③ 혼자: 다섯 번까지
do
	local p, s = join("riven", 52)
	local r = handlers.Week(p, "enter", B.id, "normal", false)
	expect(r and r.ok, "혼자 노말에 들어갔다")
	local key = s.scene
	expect(string.find(key, "#wn", 1, true) ~= nil, "주간의 방 " .. key)
	run(1)
	local room = World.room(key)
	eq(Weekly.livesLeft(room, s.hero.id), MAX, "처음에는 5")
	for n = MAX - 1, 1, -1 do
		fall(s)
		handlers.Return(p)
		eq(s.scene, key, ("일어나기: 같은 방에서 일어난다(%d 남음)"):format(n))
		expect(s.hero.alive and s.hero.hp == s.hero.maxHp, "체력이 가득한 채 일어났다")
		eq(Weekly.livesLeft(room, s.hero.id), n, "하나 줄었다")
		local sc = SCENES.scenes[key]
		expect(math.abs(s.hero.x - sc.spawn.x) <= 16, "방의 처음 자리에서")
		run(0.2)
	end
	local view = Weekly.roomView(room)
	eq(view.lives[tostring(s.hero.id)], 1, "방의 상태(WeekView)에 내 남은 수가 실린다")
	eq(view.livesMax, MAX, "방의 상태에 처음의 수가 실린다")
	-- 다섯째: 나가기
	fall(s)
	handlers.Return(p)
	eq(SCENES.base(s.scene), B.door.scene, "다 썼으면 보스의 문 앞(그림자 능선)으로 나간다")
	expect(s.hero.alive, "나가면서 일어난다")
	expect(math.abs(s.hero.x - (B.door.x - 30)) <= 16, "문 곁에")
	eq(Weekly.done(s.hero.rift, B.id, os.time()), nil, "나간 것은 격파가 아니다(다시 들어갈 수 있다)")
	World.removePlayer(p)
end

-- ③④ 파티: 사람마다 따로 · 무니의 소생은 줄지 않는다
do
	local pa, a = join("riven", 120) -- (소생은 무니의 4차 — 둘 다 그 레벨로)
	local pb, b = join("mooni", 120)
	handlers.Party(pa, "invite", pb.UserId)
	handlers.Party(pb, "accept")
	a.trust, a.stale = true, nil
	a.hero.x = B.door.x
	local r = handlers.Week(pa, "enter", B.id, "normal", true)
	expect(r and r.ok, "파티로 들어갔다")
	local key = a.scene
	eq(b.scene, key, "무니도 같은 방에")
	run(1)
	local room = World.room(key)
	-- 리븐이 한 번 쓰러져 스스로 일어난다
	fall(a)
	handlers.Return(pa)
	eq(Weekly.livesLeft(room, a.hero.id), MAX - 1, "리븐 4")
	eq(Weekly.livesLeft(room, b.hero.id), MAX, "무니는 그대로 5(사람마다 따로)")
	-- 리븐이 다시 쓰러지고 무니가 소생으로 일으킨다
	fall(a)
	b.hero.skills.mn_revive = 5
	b.hero.cds.mn_revive = nil
	b.trust, b.stale = true, nil
	b.hero.x, b.hero.y = a.hero.x + 10, a.hero.y
	handlers.Move(pb, b.hero.x, b.hero.y, 1)
	run(0.2)
	handlers.Skill(pb, "mn_revive", 1, b.hero.x, b.hero.y, 1)
	run(1.5)
	expect(a.hero.alive, "무니의 소생으로 일어났다")
	eq(a.scene, key, "그 자리(같은 방)에서")
	eq(Weekly.livesLeft(room, a.hero.id), MAX - 1, "소생으로 일어나면 데스 카운트가 줄지 않는다(4 그대로)")
	handlers.Return(pa)
	eq(Weekly.livesLeft(room, a.hero.id), MAX - 1, "살아 있을 때 「일어나기」를 보내도 줄지 않는다")
	World.removePlayer(pa)
	World.removePlayer(pb)
end

-- ⑥ 보스전에서 쓰러지면 약해짐(경험치 · 물건 덜 얻음)이 붙지 않는다(2026-10-27 사용자 "보스에서 죽는건 그 죽음패널티 들어가면안된다잉") — 사냥터에서는 그대로 붙는다
do
	local p, s = join("riven", 52)
	local r = handlers.Week(p, "enter", B.id, "normal", false)
	expect(r and r.ok, "혼자 노말에 들어갔다")
	run(1)
	local room = World.room(s.scene)
	local boss = nil
	for _, m in room.bosses do
		if m.kind == B.id then
			boss = m
		end
	end
	expect(room:bossFight(), "주간 보스의 방은 보스전")
	s.hero.weak, s.hero.invuln, s.hero.inCine = 0, 0, false
	room:hurtHero({}, s.hero, boss, 1, true)
	expect(not s.hero.alive, "보스의 즉사에 쓰러졌다")
	eq(s.hero.weak, 0, "보스전에서 쓰러지면 약해짐이 붙지 않는다")
	run(COMBAT.rules.reviveWait + 0.2)
	handlers.Return(p)
	eq(Weekly.livesLeft(room, s.hero.id), MAX - 1, "데스 카운트는 그대로 센다")
	-- 견줌: 사냥터의 졸개에게 쓰러지면 약해짐이 붙는다
	World.jump(p, "hunt")
	local hunt = World.room(s.scene)
	expect(not hunt:bossFight(), "사냥터는 보스전이 아니다")
	local mob = nil
	for _, m in hunt.mobs do
		if not m.boss then
			mob = m
			break
		end
	end
	s.hero.weak, s.hero.invuln, s.hero.inCine, s.hero.alive, s.hero.hp = 0, 0, false, true, 1
	hunt:hurtHero({}, s.hero, mob, 50)
	expect(not s.hero.alive, "사냥터에서 쓰러졌다")
	expect(s.hero.weak > 0, ("사냥터에서 쓰러지면 약해짐이 붙는다(%d초)"):format(s.hero.weak))
	World.removePlayer(p)
end
