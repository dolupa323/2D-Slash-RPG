-- 「달의 계승자」 — 2026-11-05 사용자 제보 버그들(서버의 흐름 그대로).
--  ① 액시온 4차 사냥기 「초승달」: 끝까지 모은 뒤 오래(3초) 누르고 있다가 떼도 피해가 든다(그 전: 1.6초 넘으면 서버가 「뗐다」를 버려 그림만 날아갔다)
--  ② 리퍼의 망령 · 저승문 같은 설치 · 소환은 주인이 방을 떠나면 사라진다(그 전: 빈 방에 남았다가 주인이 돌아오면 안 보이는 채로 쳤다)
--  ③ 리븐 4차 사냥기 「무영 섬」: 조금 낮은 발판(40점 아래)의 적도 맞는다(그 전: 발밑 6점까지)
--  ④ 무니의 수호령 각성: 서버는 둘까지 둔다(화면도 둘 — kits/mooni.luau)
--  (리퍼 3차 그림자 흡혈이 다른 발판의 졸개를 옮기지 않는 것은 시험 117)
local TICK = 1 / 20
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Passives = req("ReplicatedStorage/shared/lune/sim/passives")

-- ② 떠나면 설치 · 소환이 사라진다(방의 셈)
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(2))
	local h = Hero.new(1, "reaper")
	Hero.setLevel(h, 150, Hero.jobAt(150))
	Hero.autoSkill(h)
	h.x, h.y = room.mobs[1].x - 30, room.mobs[1].y
	local placedId = nil
	for id in COMBAT.placed do
		if string.sub(id, 1, 3) == "rp_" then
			placedId = id
		end
	end
	expect(placedId ~= nil, "리퍼의 설치 · 소환이 있다")
	room:place(h, placedId, 1, { hits = {}, kills = {} })
	local mine = 0
	for _, p in room.placed or {} do
		if p.owner == h then
			mine += 1
		end
	end
	expect(mine > 0, "놓았다(" .. tostring(placedId) .. ")")
	room:forget(h)
	local left = 0
	for _, p in room.placed or {} do
		if p.owner == h then
			left += 1
		end
	end
	eq(left, 0, "방을 떠나면(Room:forget) 그 사람의 설치 · 소환이 사라진다")
end

-- ③ 무영 섬의 아래 판정
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(4))
	local h = Hero.new(2, "riven")
	Hero.setLevel(h, 150, Hero.jobAt(150))
	Hero.autoSkill(h)
	local m = room.mobs[1]
	for _, mm in room.mobs do
		mm.state, mm.t = "idle", 0
		mm.x = 9999 -- (다른 졸개는 멀리)
	end
	m.x = 400
	h.x, h.y, h.dir = 300, m.y - 40, 1 -- 리븐이 졸개보다 40점 위(졸개 = 낮은 발판)
	m.hp = m.maxHp
	local hp0 = m.hp
	expect(room.caster:begin(h, "rv_phantom", 1, nil), "무영 섬을 쓴다")
	for _ = 1, 40 do
		h.invuln = 5
		room:step({ h }, 1 / 60)
	end
	expect(m.hp < hp0, ("40점 낮은 발판의 졸개도 맞는다(%d → %d)"):format(hp0, m.hp))
end

-- ④ 수호령 각성 = 둘
do
	local h = Hero.new(3, "mooni")
	Hero.setLevel(h, 150, Hero.jobAt(150))
	Hero.autoSkill(h)
	h.skills.mn_guard2 = 1
	eq(Passives.count(h, "guards", 1), 2, "수호령 각성이면 서버는 수호령을 둘까지 둔다")
end

-- ① 초승달(서버의 흐름)
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
	lock = function() return true end, unlock = function() end,
	loadAccount = function(id) return disk[id] end, saveAccount = function(id, data) disk[id] = data; return true end, loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end, claimName = function(key, id) names[key] = id; return true end, freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end, marketRead = function() return true, nil end, marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local uid = 12800
local function join(class)
	uid += 1
	local p = { UserId = uid, Name = "b" .. uid, DisplayName = "b", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", "b" .. uid, class)
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, 150, Hero.jobAt(150))
	Hero.autoSkill(s.hero)
	World.jump(p, "hunt")
	s.trust, s.stale = true, nil
	return p, s
end
for _, hold in { 0.6, 1.6, 3.0, 6.0 } do
	local p, s = join("axion")
	run(1.5)
	local room = World.room(s.scene)
	local target = nil
	for _, m in room.mobs do
		if not m.away and not m.def.boss and not m.afk then
			target = m
			break
		end
	end
	expect(target ~= nil, "사냥터의 졸개")
	if target then
		target.state, target.t, target.hp, target.x = "idle", 0, target.maxHp, target.homeX -- (앞의 판에 쓰러졌으면 다시 세운다)
		s.hero.x, s.hero.y = target.x - 30, target.y
		handlers.Move(p, s.hero.x, s.hero.y, 1)
		run(0.2)
		s.hero.cds.ax_moonfall = nil
		local hp0 = target.hp
		handlers.Skill(p, "ax_moonfall", 1, s.hero.x, s.hero.y, 1)
		run(hold)
		handlers.Skill(p, "ax_moonfall", 2, s.hero.x, s.hero.y, 1)
		run(1.0)
		expect(target.hp < hp0, ("초승달: %.1f초 모았다가 떼도 피해가 든다(%d → %d)"):format(hold, hp0, target.hp))
	end
	World.removePlayer(p)
end
