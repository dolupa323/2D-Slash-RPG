-- 「달의 계승자」 — 개인 연무장(2026-10-26) — 서버의 흐름 그대로.
--  사용자: "마을에서 포탈 타서 개인연무장으로 갈수있는거 만들고 개인연무장은 개인한명만 들어갈수있고 각각플레이어는 따로쓰는거야 거기서 dps 측정할수있는 허수아비같은게 있는거지"
--  보는 것: ① 초승달 마을 · 은달 항구의 문 → 연무장 ② 들어갈 때마다 그 사람만의 방(같은 파티도 따로) ③ 수련 인형 = 쓰러지지 않는다 · 움직이지 않는다 · 치지 않는다 · 보상이 없다
--   ④ 나가는 문 = 들어온 마을의 그 문 앞 ⑤ 쉬는 곳(매크로 확인의 사냥 시간에 들지 않는다) ⑥ 다시 들어오면 마을에서
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local TICK = 1 / 20

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
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local function join(uid, name, cls)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	local s = World.session(p)
	s.hero.level, s.hero.job = 60, 3
	s.hero.tut.done = true
	return p, s
end
local function doorOf(sceneKey, to)
	for _, d in SCENES.scenes[sceneKey].portals do
		if d.to == to then
			return d
		end
	end
	return nil
end
local function standAt(p, s, sceneKey, x, y)
	World.jump(p, sceneKey)
	s.trust, s.stale = true, nil
	s.hero.x, s.hero.y = x, y
	handlers.Move(p, x, y, 1)
end

-- ① 문이 있다
local dojo = SCENES.scenes.in_dojo
expect(dojo ~= nil and dojo.dojo == true and dojo.inst == "solo", "연무장 장면(dojo · 한 사람의 방)")
expect(dojo.rest == true, "쉬는 곳(매크로 확인의 사냥 시간에 들지 않는다)")
eq(#dojo.mobs, 3, "수련 인형 셋")
local townDoor, cityDoor = doorOf("town", "in_dojo"), doorOf("ct", "in_dojo")
expect(townDoor ~= nil, "초승달 마을에 연무장 문")
expect(cityDoor ~= nil, "은달 항구에 연무장 문")
local exit = doorOf("in_dojo", "@home")
expect(exit ~= nil, "연무장의 나가는 문 = 들어온 마을(@home)")

-- ② 그 사람만의 방 — 같은 파티도 따로
local pa, a = join(9101, "연무도끼", "axion")
local pb, b = join(9102, "연무무니", "mooni")
World.jump(pa, "town")
World.jump(pb, "town")
handlers.Party(pa, "invite", 9102)
handlers.Party(pb, "accept")
expect(World.sameParty(9101, 9102), "둘은 파티")
standAt(pa, a, "town", townDoor.x, townDoor.y)
local ra = handlers.Travel(pa, "in_dojo")
expect(ra ~= nil and string.match(ra.scene, "^in_dojo#") ~= nil, "마을의 문 → 연무장의 방 " .. tostring(ra and ra.scene))
standAt(pb, b, "town", townDoor.x, townDoor.y)
local rb = handlers.Travel(pb, "in_dojo")
expect(rb ~= nil and rb.scene ~= ra.scene, ("같은 파티여도 따로 된 방(%s · %s)"):format(tostring(ra and ra.scene), tostring(rb and rb.scene)))

-- ③ 수련 인형: 쳐도 쓰러지지 않고 · 보상이 없고 · 움직이지도 치지도 않는다
local room = World.room(a.scene)
run(1.5)
local dummy = room.mobs[1]
expect(dummy and dummy.kind == "dummy", "수련 인형")
local x0, xp0, money0, hp0 = dummy.x, a.hero.xp, a.hero.money, a.hero.hp
a.hero.dmgBoost = 1000
a.trust, a.stale = true, nil
a.hero.x, a.hero.y, a.hero.dir = dummy.x - 16, dummy.y, 1
handlers.Move(pa, a.hero.x, a.hero.y, 1)
local before = #sent
for _ = 1, 10 do
	handlers.Skill(pa, "ax_combo", 1, a.hero.x, a.hero.y, 1)
	run(0.25) -- 도끼 내려찍기(2026-10-28 액시온 리마스터): 모으는 구간 뒤에 내려찍는 구간을 보낸다
	handlers.Skill(pa, "ax_combo", 2, a.hero.x, a.hero.y, 1)
	run(0.6)
end
local dealt = 0
for i = before + 1, #sent do
	local e = sent[i]
	if e.name == "Hits" and e.player == pa then
		for _, h in e.args[2] or {} do
			dealt += h.dmg or 0
		end
	end
end
expect(dealt > 0, "피해가 들어간다(피해 숫자가 뜬다) " .. dealt)
expect(dummy.state ~= "dead" and dummy.state ~= "gone" and dummy.hp == dummy.maxHp, "쓰러지지 않는다(체력이 늘 가득)")
eq(a.hero.xp, xp0, "경험치가 없다")
eq(a.hero.money, money0, "달돈이 없다")
eq(#room.drops, 0, "떨어지는 것이 없다")
run(10)
eq(dummy.x, x0, "움직이지 않는다")
eq(a.hero.hp, hp0, "치지 않는다(10초 곁에 서 있어도 체력 그대로)")

-- ④ 나가는 문 = 들어온 마을의 그 문 앞
a.hero.x, a.hero.y = exit.x, exit.y
handlers.Move(pa, exit.x, exit.y, 1)
local out = handlers.Travel(pa, "@home")
expect(out ~= nil and out.scene == "town", "초승달 마을로 나간다 " .. tostring(out and out.scene))
expect(out and math.abs(out.x - townDoor.x) <= 2, "마을의 연무장 문 앞으로")
-- 은달 항구에서 들어오면 은달 항구로
standAt(pa, a, "ct", cityDoor.x, cityDoor.y)
eq(a.hero.home, "ct", "은달 항구에 들렀다(돌아갈 마을)")
local rc = handlers.Travel(pa, "in_dojo")
expect(rc ~= nil and string.match(rc.scene, "^in_dojo#") ~= nil, "은달 항구의 문 → 연무장")
a.hero.x, a.hero.y = exit.x, exit.y
handlers.Move(pa, exit.x, exit.y, 1)
local out2 = handlers.Travel(pa, "@home")
expect(out2 ~= nil and out2.scene == "ct" and math.abs(out2.x - cityDoor.x) <= 2, "은달 항구의 그 문 앞으로 " .. tostring(out2 and out2.scene))

-- ⑤-2 연무장에서 귀환 주문서 = 들어온 마을로(장면에 가장 가까운 마을이 없다 — 2026-10-26: 전에는 「여기서는 쓸 수 없다」)
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	standAt(pa, a, "ct", cityDoor.x, cityDoor.y)
	handlers.Travel(pa, "in_dojo")
	expect(string.match(a.scene, "^in_dojo#") ~= nil, "(은달 항구에서 연무장으로)")
	Bag.give(a.hero, "scroll_return", 2)
	local n0 = Bag.count(a.hero, "scroll_return")
	handlers.Potion(pa, "scroll_return")
	eq(a.scene, "ct", "연무장에서 귀환 주문서 = 들어온 마을(은달 항구)")
	eq(Bag.count(a.hero, "scroll_return"), n0 - 1, "주문서 하나를 쓴다")
end
-- ⑥ 연무장에서 나간 채로 다시 들어오면 마을에서
standAt(pa, a, "ct", cityDoor.x, cityDoor.y)
handlers.Travel(pa, "in_dojo")
local saved = a.hero.last
World.removePlayer(pa)
local back = handlers.Ready(pa)
local again = handlers.Chars(pa, "enter", back.select.chars[1].id)
expect(again and again.scene and not string.find(again.scene, "in_dojo", 1, true), ("연무장에서 나갔다 다시 들어오면 마을에서(%s → %s)"):format(tostring(saved), tostring(again and again.scene)))
