-- 「달의 계승자」 — 매크로 방지 날파리(2026-10-28 — 공방 design/afk.js · sim/room.luau의 sendFly · stepFly · server world.luau의 flyIfMacro · modules/macroGuard.luau의 flyWanted).
--  사용자: "사냥터에서 잠수방지 몬스터 나오게해 몬스터는 hp1인데 날아다니면서 날파리로 유저를 쫓아와서 계속 툭툭쳐 …" → 같은 날 "날파리 딜이 너무쎄다 딜줄이고, 그냥 뜨는게 아니라 어느정도 매크로라고 판명되면 뜨는걸로하자"
--  보는 것: ① 사냥터의 방에만 날파리의 자리(처음에는 없다) ② 보내면 옆 위에서 나타나 날아와 맴돈다(서서 치는 공격이 닿는 높이)
--   ③ 찌를 때마다 최대 체력의 AFK.hit%(5% — 같은 날 "날파리 기준을 좀 유하게 잡자 지금 일반유저들도 잠깐 10초 눈떼면 죽는다": 10% · 0.7초 → 5% · 1.2초) — 스무 번이면 쓰러진다(약해짐이 붙는다) ④ 쫓는 동안 물약을 마실 수 없다 ⑤ 쓰러뜨리면 날파리는 사라진다
--   ⑥ 한 대에 잡히고 아무것도 주지 않는다 ⑦ 모습에 높이가 실린다
--   ⑧ 서버(2026-10-28 "진짜 매크로여야 나오는수준으로"): 잠수만으로는 · 확인을 놓친 것만으로는 오지 않는다 · 「사냥 보상 멈춤」인데도 30마리 넘게 계속 잡으면 온다 · 매크로 의심(높음 · 중간)으로는 오지 않는다 · 오래 사냥한 것만으로는 오지 않는다 · 문제를 푸는 동안 찌르지 않는다 · 마을에서는 안 온다
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local AFK = COMBAT.afk
local DT = 1 / 20

eq(AFK.kind, "afkfly", "날파리의 종류")
local FDEF = COMBAT.mobs[AFK.kind]
expect(FDEF ~= nil and FDEF.afk == true and FDEF.bare == true, "날파리의 싸움 자료(afk · 그림 없는 맞음 · 쓰러짐)")
expect(AFK.hover + AFK.bob + 0.01 < 16, "서서 치는 공격이 닿는 높이(발에서 16점) 안에 뜬다")
expect(AFK.every > COMBAT.rules.invuln, "찌르는 간격이 맞은 뒤 잠깐 맞지 않는 시간보다 길다")

-- ① 방의 자리
local hunt = SCENES.scenes.hunt
expect(Room.huntRoom(hunt), "사냥터는 날파리의 자리를 둔다")
expect(not Room.huntRoom(SCENES.scenes.town), "마을에는 없다")
local room = Room.new("hunt", hunt, Random.new(3))
local flies = {}
for _, m in room.mobs do
	if m.afk then
		table.insert(flies, m)
		expect(m.state == "gone" and m.away and m.hp == 1 and m.maxHp == 1, "날파리의 자리: 처음에는 없다 · 체력 1")
	end
end
eq(#flies, AFK.slots, "자리의 수")
eq(room.mobs[#room.mobs].afk, true, "목록 끝에 둔다(졸개의 번호가 바뀌지 않게)")

-- 사냥터의 졸개는 치지 않게: 졸개 없는 같은 장면(날파리만 본다)
local quiet = table.clone(hunt)
quiet.mobs = { table.clone(hunt.mobs[1]) }
quiet.mobs[1].x, quiet.mobs[1].range = 20, { 8, 24 } -- 하나만 멀리(사냥터로 셈한다)
local r = Room.new("quiet", quiet, Random.new(5))
local h = Hero.new(1, "riven")
Hero.setLevel(h, 40, Hero.jobAt(40))
h.hp = h.maxHp
h.x, h.y = 600, hunt.spawn.y
for _, m in r.mobs do
	if not m.afk then
		m.away, m.state = true, "gone" -- 그 하나도 치우기
	end
end
local heroes = { [h.id] = h }
local function run(seconds)
	local all = {}
	for _ = 1, math.floor(seconds / DT + 0.5) do
		Hero.tick(h, DT)
		for _, e in r:step(heroes, DT) do
			table.insert(all, e)
		end
	end
	return all
end

-- ② 보내기
expect(r:sendFly(h), "보낸다")
expect(not r:sendFly(h), "이미 쫓는 날파리가 있으면 또 보내지 않는다")
local fly = r:flyOf(h.id)
expect(fly ~= nil and fly.state == "spawn", "나타난다")
eq(math.abs(fly.x - h.x), AFK.from, "옆으로 from점에서")
eq(h.y - fly.y, AFK.up, "위로 up점에서")
-- 다가온다: 나타난 뒤 날아와 곁에 붙는다
local dist0 = math.abs(fly.x - h.x)
run(0.5)
expect(math.abs(fly.x - h.x) < dist0, "다가온다")
h.invuln = 99 -- (아직 맞지 않게 — 붙는 자리만 본다)
run(2)
expect(math.abs(fly.x - h.x) <= AFK.orbit.r + 1, ("곁에서 맴돈다(%.1f점)"):format(fly.x - h.x))
local up = h.y - fly.y
expect(up >= AFK.hover - AFK.bob - 0.5 and up <= AFK.hover + AFK.bob + 0.5, ("발밑에서 hover점 위(%.1f)"):format(up))
-- 서서 치는 공격의 상자(발밑에서 16점 위까지 · 곁 30점)에 걸린다
local inBox = false
for _, m in r:mobsInBox(h.x - 30, h.x + 30, h.y - 16, h.y, h.x) do
	if m == fly then
		inBox = true
	end
end
expect(inBox, "서서 치는 공격에 맞는다")

-- ④ 물약: 쫓는 동안 막힌다
Bag.give(h, Items.potionFor(40).id, 5)
h.hp = math.floor(h.maxHp / 2)
h.potionWait = 0
local healed, why = Hero.drink(h, nil)
eq(healed, nil, "쫓는 동안 물약을 마실 수 없다")
eq(why, AFK.words.potion, "까닭: " .. tostring(AFK.words.potion))

-- ③ 찌르기: 한 번에 최대 체력의 hit% · 방어와 상관없이
h.hp, h.invuln = h.maxHp, 0
local hurts = {}
local need = math.ceil(100 / AFK.hit) -- 쓰러지기까지 찌르는 수(10%면 열 번)
for _, e in run(AFK.every * need + 0.5) do
	if e.type == "hurt" then
		table.insert(hurts, e)
	end
end
expect(#hurts >= 3, ("계속 찌른다 %d번 · 남은 체력 %d / %d · 약해짐 %s"):format(#hurts, h.hp, h.maxHp, tostring(h.weak)))
local one = math.ceil(h.maxHp * AFK.hit / 100) -- (올림 — need번이면 반드시 쓰러진다: 내림이면 체력 1이 남을 수 있다)
eq(hurts[1] and hurts[1].dmg, one, ("한 번에 최대 체력의 %d%%"):format(AFK.hit))
expect(not h.alive, ("%d번이면 쓰러진다"):format(need))
expect(AFK.hit <= 10, ("한 번에 최대 체력의 %d%%(2026-10-28 \"날파리 딜이 너무쎄다\" — 25%% → 10%%)"):format(AFK.hit))
expect(h.weak > 0, "사냥터라 약해짐이 붙는다")
-- ⑤ 쓰러뜨리면 날아가 사라진다
run(1.5)
eq(r:flyOf(h.id), nil, "쓰러뜨린 뒤에는 쫓지 않는다")
eq(fly.state, "gone", "사라졌다")
expect(fly.away, "다시 보낼 때까지 없다")
-- 물약 막힘은 조금 뒤 풀린다
run(AFK.lock + 0.1)
eq(h.flyLock, 0, "날파리가 없으면 물약 막힘이 풀린다")

-- ⑥ 한 대에 잡힌다 · 아무것도 주지 않는다
h.alive, h.hp, h.weak, h.invuln = true, h.maxHp, 0, 99
expect(r:sendFly(h), "다시 보낸다")
fly = r:flyOf(h.id)
run(1.2)
local out = { hits = {}, kills = {} }
local xp0, money0, dust0 = h.xp, h.money, h.dust
local dead = r:strike(h, fly, 1, h.x, nil, out)
expect(dead, "한 대에 쓰러진다(체력 1)")
eq(#out.kills, 1, "잡은 것으로 적힌다")
local k = out.kills[1]
expect(k.xp == 0 and #k.gains == 0 and #k.credit == 0 and #k.loot == 0 and k.drop == nil and k.hitters == nil, "경험치 · 퀘스트의 숫자 · 떨어지는 것 · 매크로 확인의 처치가 없다")
eq(h.xp, xp0, "경험치 그대로")
expect(h.money == money0 and h.dust == dust0, "달돈 · 달가루 그대로")
run(1.5)
eq(fly.state, "gone", "잡힌 날파리도 사라진다")

-- ⑦ 모습에 높이가 실린다(날파리만)
h.invuln = 99
r:sendFly(h)
fly = r:flyOf(h.id)
run(0.3)
local snap = r:snapshot()
local row = snap[fly.id]
expect(row[13] ~= nil and math.abs(row[13] - fly.y) < 0.11, "열셋째 = 날파리의 높이")
for _, m in r.mobs do
	if not m.afk then
		eq(snap[m.id][13], nil, "다른 몬스터는 높이를 보내지 않는다")
	end
end
-- 떠나면(방에 없으면) 사라진다
heroes[h.id] = nil
run(1.5)
eq(fly.state, "gone", "쫓던 사람이 맵을 떠나면 사라진다")

-- ⑧ 서버: 매크로로 보이면 보낸다
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		if name == "Fly" then
			player.flies = (player.flies or 0) + 1
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
World.start()
local function tick(seconds)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		World.tick(DT)
	end
end
local uid = 10700
local function join(scene: string)
	uid += 1
	local name = "잠수" .. uid
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, key, v) self.attrs[key] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "axion")
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, 30, Hero.jobAt(30))
	s.hero.hp = s.hero.maxHp
	s.hero.god = true -- (사냥터의 졸개에게 쓰러지지 않게 — 날파리가 오는지만 본다)
	World.jump(p, scene)
	s.trust, s.stale = true, nil
	handlers.Move(p, s.hero.x, s.hero.y, 1)
	return p, s
end
local Guard = req("ServerScriptService/server/lune/modules/macroGuard")
-- 2026-10-28 사용자 "그냥 뜨는게 아니라 어느정도 매크로라고 판명되면 뜨는걸로하자": 잠수만으로는 오지 않는다 · 「사냥 보상 멈춤」 · 매크로 의심이면 온다
local p1, s1 = join("hunt")
tick(150)
eq(p1.flies, nil, "사냥터에서 2분 넘게 가만히 있어도(잠수만으로는) 오지 않는다")
expect(s1.macro ~= nil, "매크로 확인이 시작됐다")
-- 매크로 확인을 놓쳐 「사냥 보상 멈춤」 — 그것만으로는(자리를 비운 사람) 오지 않고, 그 뒤로도 계속 잡으면 온다
s1.macro.saved.stopped, s1.macro.saved.stopUntil = true, os.time() + 600
tick(3)
eq(p1.flies, nil, "확인을 놓친 것만으로는(그 뒤로 잡지 않았다) 오지 않는다")
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
for _ = 1, AFK.when.kills - 1 do
	Macro.onKill(s1.macro, os.time())
end
tick(3)
eq(p1.flies, nil, ("보상 멈춤 뒤 %d마리로는 아직 오지 않는다"):format(AFK.when.kills - 1))
Macro.onKill(s1.macro, os.time())
tick(1.5)
eq(p1.flies, 1, ("「사냥 보상 멈춤」인데도 %d마리를 잡으면 날파리가 온다(알림)"):format(AFK.when.kills))
local f1 = World.room(s1.scene):flyOf(s1.hero.id)
expect(f1 ~= nil, "날파리가 쫓는다")
-- 잡혀도 아직 그러면 again초 뒤에 또
World.room(s1.scene):damageMob(f1, 1, f1.x, nil)
tick(AFK.again + 2)
eq(p1.flies, 2, "잡혀도 아직 보상 멈춤이면 또 온다")
-- 매크로 확인 문제가 떠 있는 동안: 날파리가 찌르지 않고 새로 오지도 않는다
Guard.force(s1)
tick(1.2)
expect(s1.hero.inCheck == true, "문제가 떴다")
local f2 = World.room(s1.scene):flyOf(s1.hero.id)
local poked = false
for _ = 1, 60 do
	tick(DT)
	if f2 and f2.state == "atk" then
		poked = true
	end
end
expect(not poked, "문제를 푸는 동안 날파리는 맴돌기만 한다(찌르지 않는다)")
World.removePlayer(p1)
-- 매크로 의심: 같은 스킬을 누르는 간격이 지나치게 고르다(high)
local p2, s2 = join("hunt")
tick(1.2)
s2.macro.gaps = {}
for k = 1, 40 do
	s2.macro.gaps[k] = 2.0
end
tick(1.5)
eq(p2.flies, nil, "누르는 간격이 기계처럼 고른 것(의심 높음)만으로는 오지 않는다 — 재사용 대기 중인 키를 연타하는 사람도 그렇게 잡힌다")
World.removePlayer(p2)
-- 보상 멈춤 뒤에 잡은 수는 보상 멈춤인 동안만 센다 · 다시 확인을 통과하거나 풀리면 0
do
	local st = Macro.new(os.time())
	Macro.onKill(st, os.time())
	eq(Macro.stopKills(st), 0, "보상 멈춤이 아니면 세지 않는다")
	st.saved.stopped = true
	for _ = 1, 5 do
		Macro.onKill(st, os.time())
	end
	eq(Macro.stopKills(st), 5, "보상 멈춤 뒤에 잡은 수")
	Macro.clear(st)
	eq(Macro.stopKills(st), 0, "풀리면 0")
end
-- 2026-10-28 "날파리 기준을 좀 유하게": 의심 「중간」으로는 오지 않는다 — 꽤 고른 간격(변동 4%) · 10분 동안 거의 한자리(32점 칸 셋 안)에서 30마리 넘게
local p5, s5 = join("hunt")
tick(1.2)
s5.macro.gaps = {}
for k = 1, 40 do
	s5.macro.gaps[k] = if k % 2 == 0 then 2.08 else 1.92
end
eq(Macro.level(s5.macro, os.time(), true), "mid", "(꽤 고른 간격 = 의심 중간)")
tick(3)
eq(p5.flies, nil, "의심 중간(꽤 고른 간격)으로는 오지 않는다")
s5.macro.gaps = {}
s5.macro.kills = {}
for k = 1, 40 do
	s5.macro.kills[k] = os.time() - 400 + k * 5
end
s5.macro.moves = { os.time() - 300 }
eq(Macro.level(s5.macro, os.time(), true), "mid", "(10분 동안 한자리에서 40마리 = 의심 중간)")
tick(3)
eq(p5.flies, nil, "한자리에서 사냥하는 것(의심 중간)으로는 오지 않는다")
World.removePlayer(p5)
-- 오래 쉬지 않고 사냥한 것만으로는 오지 않는다(의심의 long은 보지 않는다)
local p3, s3 = join("hunt")
tick(1.2)
s3.macro.rest = os.time() - 7200
tick(1.5)
eq(p3.flies, nil, "두 시간 쉬지 않은 것만으로는 오지 않는다")
World.removePlayer(p3)
-- 마을에서는 보상 멈춤이어도 오지 않는다
local p4, s4 = join("town")
tick(1.2)
s4.macro.saved.stopped, s4.macro.saved.stopUntil = true, os.time() + 600
tick(3)
eq(p4.flies, nil, "마을에서는 오지 않는다")
World.removePlayer(p4)
-- 2026-10-29 사용자 "날파리 작동이 메크로가 아닌 일반인에게 적용되서 괴롭히지않는지 확인하고": 확인을 통과해 보상 멈춤이 풀리면 붙어 있던 날파리도 곧바로 떠난다
--  (전에는 통과한 뒤에도 그 사람이 쓰러지거나 맵을 떠날 때까지 찔렀다) · 맵을 바꿔 사냥터가 아닌 곳이면 쫓지 않는다
do
	local p6, s6 = join("hunt")
	tick(1.2)
	s6.macro.saved.stopped, s6.macro.saved.stopUntil = true, 0 -- (첫 번째 놓침 — 곧바로 다시 확인할 수 있다)
	for _ = 1, AFK.when.kills do
		Macro.onKill(s6.macro, os.time())
	end
	tick(2.5)
	local room6 = World.room(s6.scene)
	local f6 = room6:flyOf(s6.hero.id)
	expect(f6 ~= nil, "(보상 멈춤 뒤 30마리 — 날파리가 쫓는다)")
	-- 「사냥 보상 멈춤」을 눌러 확인을 통과했다
	local res = Guard.onRemote(s6, "again")
	local check = res and res.check
	expect(check ~= nil, "(다시 확인 — 문제가 떴다)")
	local picks = {}
	for i, ok in s6.macro.check.answer do
		if ok then
			table.insert(picks, i)
		end
	end
	local r2 = Guard.onRemote(s6, "answer", check.token, picks)
	eq(r2 and r2.result, "pass", "(통과)")
	tick(1.5)
	eq(room6:flyOf(s6.hero.id), nil, "통과하면 붙어 있던 날파리가 떠난다")
	local poked = false
	for _ = 1, 80 do
		tick(DT)
		for _, m in room6.mobs do
			if m.afk and m.state == "atk" then
				poked = true
			end
		end
	end
	expect(not poked, "통과한 뒤에는 찌르지 않는다")
	tick(AFK.again + 2)
	eq(room6:flyOf(s6.hero.id), nil, "통과한 뒤에는 다시 오지 않는다")
	World.removePlayer(p6)
end
