-- 「달의 계승자」 — 보스 기믹 = 트루 데미지 · 무니의 치유 · 소생 · 파티 버프가 보스 방에서 닿는다(2026-11-05).
--  사용자: "무니 소생이나 힐같은거 잘적용되어야하고 살라나, 무니 피해감소, 리퍼 피흡 이런 유틸들로 보스 기믹을 씹는경우는 없어야한다 트루데미지로 들어와야해"
--  보는 것: ① Room:hurtHero — 보통 공격은 방어구 · 무니의 피해 감소 버프로 줄고 · 기믹(pierce) · 즉사(kill)는 그대로 들어온다(생존기 · 죽음의 가호 · 회피도 막지 못한다)
--   ② 용암 거인의 끓는 바닥 — 생존기 중에도 최대 체력의 %가 그대로 · ③ 리퍼의 처치 흡혈 — 기믹의 졸개(마그마 혹)를 잡아서는 차지 않는다(보통 몬스터는 찬다)
--   ④ 서버의 흐름(용암 거인의 방 — 파티 둘): 무니의 달빛 치유가 다친 파티원에게 · 달의 축복이 파티원에게 · 소생이 쓰러진 파티원을 그 자리에서 일으킨다(데스 카운트가 줄지 않는다)
local TICK = 1 / 20
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local Reveal = req("ReplicatedStorage/shared/lune/sim/reveal")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local Room = req("ReplicatedStorage/shared/lune/sim/room")

-- ---- ① 트루 데미지 ----
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(3))
	local mob = room.mobs[1]
	local function hero()
		local h = Hero.new(1, "mooni")
		Hero.setLevel(h, 120, Hero.jobAt(120))
		h.hp = h.maxHp
		return h
	end
	local function hit(h, kill, pierce)
		h.invuln = 0
		local before = h.hp
		room:hurtHero({}, h, mob, 1, kill, pierce)
		return before - h.hp
	end
	local plain = hit(hero(), nil, nil)
	local hb = hero()
	Buffs.give(hb, "mn_wall", 1, hb.x, hb.y)
	Buffs.give(hb, "mn_bless", 1, hb.x, hb.y)
	local reduced = hit(hb, nil, nil)
	expect(reduced < plain, ("보통 공격: 피해 감소 버프면 덜 아프다(%d < %d)"):format(reduced, plain))
	local hp = hero()
	Buffs.give(hp, "mn_wall", 1, hp.x, hp.y)
	Buffs.give(hp, "mn_bless", 1, hp.x, hp.y)
	local trueHit = hit(hp, nil, true)
	local raw = hit(hero(), nil, true)
	eq(trueHit, raw, "기믹(트루 데미지): 피해 감소 버프와 상관없이 같은 피해")
	expect(raw > plain, ("기믹은 방어구로도 줄지 않는다(%d > 방어구로 준 %d)"):format(raw, plain))
	-- 생존기 · 죽음의 가호 · 재점화로 즉사 · 기믹을 막지 못한다
	local guardId = nil
	for id, def in Buffs.data do
		if def.fx and def.fx.guard then
			guardId = id
		end
	end
	expect(guardId ~= nil, "생존기 버프가 있다")
	local hg = hero()
	Buffs.give(hg, guardId, 1, hg.x, hg.y)
	eq(hit(hg, nil, nil), 0, "보통 공격: 생존기 중이면 0")
	expect(hit(hg, nil, true) > 0, "기믹: 생존기 중에도 들어온다")
	local hk = hero()
	Buffs.give(hk, guardId, 1, hk.x, hk.y)
	hit(hk, true, nil)
	expect(not hk.alive, "즉사 패턴: 생존기로 버티지 못한다")
	local wardId = nil
	for id, def in Buffs.data do
		if def.fx and def.fx.ward then
			wardId = id
		end
	end
	if wardId then
		local hw = hero()
		Buffs.give(hw, wardId, 1, hw.x, hw.y)
		hit(hw, true, nil)
		expect(not hw.alive, "즉사 패턴: 죽음의 가호로 버티지 못한다")
	end
	local hr = Hero.new(2, "riven")
	Hero.setLevel(hr, 150, Hero.jobAt(150))
	local hits = 0
	for _ = 1, 60 do
		hr.hp, hr.invuln, hr.alive = hr.maxHp, 0, true
		local b = hr.hp
		room:hurtHero({}, hr, mob, 0.01, nil, true)
		if hr.hp < b then
			hits += 1
		end
	end
	eq(hits, 60, "기믹은 리븐의 회피로도 피하지 못한다(60번 모두)")
end

-- ---- ④ 서버의 흐름 ----
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
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
Reveal.at.lavagiant = Reveal.clock() - 1 -- (출현한 뒤 — 자동 검사의 시계)
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local B = Weekly.boss("lavagiant")
local uid = 12700
local function join(class: string)
	uid += 1
	local name = "기믹" .. uid
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, 150, Hero.jobAt(150))
	s.hero.quests[B.quest] = { done = true, c = {} }
	s.hero.hp = s.hero.maxHp
	World.jump(p, B.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = B.door.x
	return p, s
end
local pa, a = join("riven")
local pb, b = join("mooni")
handlers.Party(pa, "invite", pb.UserId)
handlers.Party(pb, "accept")
a.trust, a.stale = true, nil
a.hero.x = B.door.x
local r = handlers.Week(pa, "enter", B.id, "normal", true)
expect(r and r.ok, "파티로 용암 거인에 들어갔다 — " .. tostring(r and r.why))
run(1)
local key = a.scene
eq(b.scene, key, "무니도 같은 방에")
local room = World.room(key)
local function near()
	b.trust, b.stale = true, nil
	b.hero.x, b.hero.y = a.hero.x + 10, a.hero.y
	handlers.Move(pb, b.hero.x, b.hero.y, 1)
	run(0.2)
end
-- ② 끓는 바닥(용암 거인의 기믹): 생존기 중에도 최대 체력의 %가 그대로 — Lava의 flood를 직접 돌린다
do
	local guardId = nil
	for id, def in Buffs.data do
		if def.fx and def.fx.guard then
			guardId = id
		end
	end
	local boss = nil
	for _, m in room.bosses do
		if m.kind == B.id then
			boss = m
		end
	end
	expect(boss ~= nil and boss.lava ~= nil, "용암 거인")
	if boss and boss.lava then
		Buffs.give(a.hero, guardId, 1, a.hero.x, a.hero.y)
		a.hero.invuln, a.hero.hp = 0, a.hero.maxHp
		a.hero.y = boss.y -- 바닥
		boss.lava.flood, boss.lava.floodTick = 5, 0
		local hp0 = a.hero.hp
		req("ReplicatedStorage/shared/lune/sim/lavagim").boss(room, boss, { [a.hero.id] = a.hero }, TICK, {}) -- (거인의 기믹 한 걸음 — 패턴은 돌리지 않는다)
		local pct = boss.def.story.gimmick.flood.pct
		eq(hp0 - a.hero.hp, math.floor(a.hero.maxHp * pct / 100 + 0.5), ("끓는 바닥: 생존기 중에도 최대 체력의 %d%%"):format(pct))
		boss.lava.flood = 0
		a.hero.buffs[guardId] = nil
	end
end
-- ③ 리퍼의 처치 흡혈: 기믹의 졸개를 잡아서는 차지 않는다
do
	local rp = Hero.new(9, "reaper")
	Hero.setLevel(rp, 150, Hero.jobAt(150))
	Hero.autoSkill(rp) -- (직업 패시브 — 처치 흡혈을 찍는다)
	rp.hp = math.floor(rp.maxHp * 0.5)
	local add = nil
	for _, m in room.mobs do
		if m.gimAdd then
			add = m
		end
	end
	expect(add ~= nil, "기믹의 졸개(마그마 혹 · 심장)가 방에 있다")
	local hp0 = rp.hp
	room:reaperKill(rp, add or {}, 100, {}, {}, nil)
	eq(rp.hp, hp0, "마그마 혹을 잡아도 흡혈로 차지 않는다")
	local hunt = Room.new("hunt", SCENES.scenes.hunt, Random.new(4))
	hunt:reaperKill(rp, hunt.mobs[1], 100, {}, {}, nil)
	expect(rp.hp > hp0, "보통 몬스터를 잡으면 찬다")
end
-- ④ 무니의 달빛 치유: 다친 파티원에게
do
	a.hero.hp = math.floor(a.hero.maxHp * 0.3)
	a.hero.invuln = 1
	b.hero.skills.mn_heal = COMBAT.cast.mn_heal.max
	b.hero.cds.mn_heal = nil
	near()
	local hp0 = a.hero.hp
	handlers.Skill(pb, "mn_heal", 1, b.hero.x, b.hero.y, 1)
	run(1.5)
	expect(a.hero.hp > hp0, ("무니의 달빛 치유가 용암 거인의 방에서 파티원에게 들어갔다(%d → %d)"):format(hp0, a.hero.hp))
end
-- 달의 축복(파티 버프): 파티원에게도
do
	b.hero.skills.mn_bless = 10
	b.hero.cds.mn_bless = nil
	near()
	handlers.Skill(pb, "mn_bless", 1, b.hero.x, b.hero.y, 1)
	run(0.8)
	expect(b.hero.buffs.mn_bless ~= nil, "달의 축복이 무니에게")
	expect(a.hero.buffs.mn_bless ~= nil, "달의 축복이 같은 방의 파티원에게도")
end
-- 소생: 쓰러진 파티원을 그 자리에서 — 데스 카운트가 줄지 않는다
do
	local lives = Weekly.livesLeft(room, a.hero.id)
	a.hero.invuln, a.hero.inCine = 0, false
	Hero.hurt(a.hero, a.hero.hp + a.hero.maxHp)
	expect(not a.hero.alive, "리븐이 쓰러졌다")
	run(COMBAT.rules.reviveWait + 0.2)
	b.hero.skills.mn_revive = 5
	b.hero.cds.mn_revive = nil
	near()
	handlers.Skill(pb, "mn_revive", 1, b.hero.x, b.hero.y, 1)
	run(1.5)
	expect(a.hero.alive, "무니의 소생으로 용암 거인의 방에서 일어났다")
	eq(a.scene, key, "그 자리(같은 방)에서")
	eq(Weekly.livesLeft(room, a.hero.id), lives, "데스 카운트가 줄지 않는다")
end
