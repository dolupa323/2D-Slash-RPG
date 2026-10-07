-- 「달의 계승자」 — 서버의 세계(server/lune/modules/world.luau): 들어오기 · 자리 보고 · 문 · 기술(구간과 이어 누르기) · 보상 · 줍기 · 물약 · 쓰러졌다 일어나기
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
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
-- 가짜 저장소: 읽고 쓴 것을 적어 둔다
local disk = {}
local saves = 0
MOCK("ServerScriptService/server/lune/modules/store", {
	load = function(userId) return disk[userId] end,
	save = function(userId, data) disk[userId] = data; saves += 1; return true end,
	isOffline = function() return false end,
	erase = function(userId) disk[userId] = nil end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
for name, def in packets do
	if def.Direction == "ClientToServer" then
		expect(handlers[name] ~= nil, "핸들러가 있는 패킷 " .. name)
	end
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

-- 가짜 플레이어: 진짜 Player처럼 없는 값을 읽으면 오류가 난다(서버 코드가 Player에 없는 값을 읽는 실수를 여기서 잡는다)
local function person(t)
	t.DisplayName = t.DisplayName or t.Name
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
local function goTo(player, target)
	local trip = nil
	for _ = 1, 8 do
		local ss = World.session(player)
		if ss.scene == target then
			break
		end
		local hop = routeNext(ss.scene, target)
		for _, portal in SCENES.scenes[ss.scene].portals do
			if portal.to == hop then
				ss.jumped = true
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
-- 처음 온 사람은 캐릭터가 없다 — 직업을 골라야 한다
local empty = handlers.Ready(p1)
expect(empty ~= nil and empty.choose == true, "처음 온 사람은 직업을 고른다")
handlers.Move(p1, 10, 10, 1)
handlers.Skill(p1, "ax_slam", 1, 0, 0, 1)
handlers.Potion(p1)
eq(handlers.Travel(p1, "hunt"), nil, "캐릭터가 없으면 아무것도 못 한다")
eq(handlers.Choose(p1, "wizard"), nil, "없는 직업은 고를 수 없다")
local first = handlers.Choose(p1, "axion")
expect(first ~= nil and first.self.class == "axion", "직업을 고르면 캐릭터가 생긴다")
eq(handlers.Choose(p1, "riven"), nil, "이미 캐릭터가 있으면 다시 고를 수 없다")
expect(disk[p1.UserId] ~= nil and disk[p1.UserId].class == "axion", "고르자마자 저장한다")
eq(handlers.Ready(p1).self.class, "axion", "다시 물으면 그 캐릭터를 준다")
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
			s1.jumped = true
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
	s.jumped = true
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
handlers.Skill(p1, "ax_slam", 1, s1.hero.x, s1.hero.y, 1)
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
		handlers.Skill(p1, "ax_slam", 1, s1.hero.x, s1.hero.y, 1)
	end
	run(slam.time + 0.15)
	if not s1.hero.alive then
		run(RULES.reviveWait + 0.5) -- 쓰러졌으면 마을에서 일어나 다시 사냥터로
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
local drop = adds[1].args[1]
expect(drop.kind == "money" and drop.amount > 0, "떨어진 것의 짜임")
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
local pots = s1.hero.potions
run(1.1)
handlers.Potion(p1)
expect(s1.hero.hp > 1 and s1.hero.potions == pots - 1, "물약을 마신다")
handlers.Potion(p1)
eq(s1.hero.potions, pots - 1, "바로 또 마시지는 못한다")

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
handlers.Skill(p1, "ax_slam", 1, s1.hero.x, s1.hero.y, 1)
handlers.Move(p1, s1.hero.x + 5, s1.hero.y, 1)
run(RULES.reviveWait + 0.2)
expect(s1.hero.alive and s1.hero.hp == s1.hero.maxHp, "일어나면 체력이 다 찬다")
eq(s1.scene, SCENES.start, "마을에서 일어난다")
eq(#got("Revive", p1), 1, "일어났다는 알림")

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
handlers.Skill(p2, "ax_slam", 1, s2b.hero.x, s2b.hero.y, 1)
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
		for key, sc in SCENES.scenes do
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
		s3.jumped = true
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
		handlers.Item(p3, "buy", "potion", 3)
		expect(last("ItemDone").ok == false and last("ItemDone").why == "파는 사람 앞이 아니다", "건물 밖(마을)에서는 못 산다")
		goTo(p3, mkey)
		eq(s3.scene, mkey, "잡화점 문으로 들어간다")
		eq(h3.x, SCENES.scenes[mkey].portals[1].x, "들어가면 나가는 문 앞에 선다")
		s3.jumped = true
		h3.x, h3.y = m.x + 150, m.y -- 같은 방 안이지만 멀다
	end
	table.clear(sent)
	handlers.Item(p3, "buy", "potion", 3)
	expect(last("ItemDone").ok == false and last("ItemDone").why == "파는 사람 앞이 아니다", "멀리서는 못 산다")
	stand("merchant")
	local pots3 = h3.potions
	handlers.Item(p3, "buy", "potion", 3)
	eq(h3.potions, pots3 + 3, "상인 앞에서 물약을 산다")
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
	Bag.add(h3, spareHat)
	table.clear(sent)
	handlers.Item(p3, "storeIn", spareHat.id)
	expect(last("ItemDone").why == "창고지기 앞이 아니다", "창고지기 앞이 아니면 못 맡긴다")
	stand("keeper")
	handlers.Item(p3, "storeIn", spareHat.id)
	eq(#h3.store, 1, "창고에 맡긴다")
	handlers.Item(p3, "storeOut", spareHat.id)
	eq(#h3.store, 0, "창고에서 찾는다")
	-- 모르는 일 · 이상한 인자
	table.clear(sent)
	handlers.Item(p3, "fly", 1)
	expect(last("ItemDone").ok == false, "모르는 일은 안 된다")
	handlers.Item(p3, "equip", { 1 })
	handlers.Item(p3, "buy", "potion", -4)
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
	local pb = person({ UserId = 202, Name = "moonB", DisplayName = "月の人" }) -- 글꼴에 없는 글자 → 아이디로
	local pc = person({ UserId = 203, Name = "moonC" })
	local function last(name, player)
		local list = got(name, player)
		return list[#list] and list[#list].args
	end
	handlers.Ready(pa)
	table.clear(sent)
	local startA = handlers.Choose(pa, "axion")
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
	eq(names[201], "달지기", "한글 이름은 그대로")
	eq(names[202], "moonB", "글꼴에 없는 이름은 아이디로")
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
	sc.jumped = true
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
	sa.jumped, sb.jumped = true, true
	handlers.Move(pa, target.x - 12, target.y, 1)
	handlers.Move(pb, target.x - 30, target.y, 1)
	local xpB, lvB = sb.hero.xp, sb.hero.level
	table.clear(sent)
	local killed = false
	for _ = 1, 60 do
		sa.jumped = true
		handlers.Move(pa, math.clamp(target.x - 12, 8, 1500), target.y, 1)
		handlers.Skill(pa, "ax_slam", 1, sa.hero.x, sa.hero.y, 1)
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
	sb2.jumped = true
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
	expect(start.quests ~= nil and start.quests.r1m1 ~= nil, "새 캐릭터는 첫 메인을 받고 시작한다")
	local sq = World.session(pq)
	local hq = sq.hero
	local function last(name)
		local list = got(name, pq)
		return list[#list] and list[#list].args
	end
	-- 주민 앞에 선다: 건물 안의 주민이면 그 문으로 들어간다
	local function at(id)
		for key, sc in SCENES.scenes do
			for _, n in sc.npcs or {} do
				if n.id == id then
					goTo(pq, key)
					eq(sq.scene, key, "주민이 있는 곳으로 간다 " .. id)
					sq.jumped = true
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
	at("master")
	local money0 = hq.money
	table.clear(sent)
	handlers.Quest(pq, "complete", "r1m1")
	local q1 = last("Quests")
	expect(q1 ~= nil and q1[1].r1m1.done == true and q1[2] == "r1m1", "사제 앞에서 첫 메인을 끝낸다")
	expect(hq.money > money0 and hq.level >= 2, "보상(달돈 · 경험치)을 받는다")
	expect(last("Gain")[1].quest == "달의 부름", "경험치 알림에 퀘스트 이름이 온다")
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
			sq.jumped = true
			handlers.Move(pq, math.clamp(target.x - 12, 8, 1500), target.y, 1)
			handlers.Skill(pq, "ax_slam", 1, hq.x, hq.y, 1)
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
	eq(Quests.mark(hq.quests, 4, "elder"), "!", "다음 메인(빛 없는 갑옷)은 Lv.4가 되면 촌장에게서")
	eq(Quests.mark(hq.quests, 3, "elder"), nil, "Lv.3에는 아직 표시가 없다")
	-- 나갔다 들어와도 그대로
	World.removePlayer(pq)
	local again = handlers.Ready(pq)
	expect(again.quests.r1m2 ~= nil and again.quests.r1m2.done == true, "끝낸 퀘스트가 그대로")
end
