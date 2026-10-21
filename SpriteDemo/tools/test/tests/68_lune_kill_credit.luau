-- 「달의 계승자」 — 퀘스트 · 일일 의뢰의 「몇 마리 잡기」를 누구에게 세 주는가(shared/lune/sim/room.luau Room:strike의 credit · 서버 world.luau applyResult).
--  사용자 2026-10-21: "퀘스트 깰때 몇마리 잡아라 이런거 있잖아요 내가 한대만 치면 다른사람이 잡아도 잡은걸로 판정이 들어가야해요"
--  보는 것: ① 파티가 아닌 사람이 한 대 치고 다른 사람이 잡으면 둘 다 센다(경험치는 잡은 사람만 — 그대로) ② 친 뒤 쓰러졌거나 맵을 떠난 사람은 세지 않는다
--   ③ 다시 나온 몬스터는 새로 센다(전에 친 것은 넘어가지 않는다) ④ 잡은 사람의 파티원(같은 맵)은 치지 않아도 센다(예전 그대로)
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")

local function solo(seed)
	local scene = table.clone(SCENES.scenes.hunt)
	scene.mobs = { scene.mobs[1] }
	return Room.new("hunt", scene, Random.new(seed))
end
local function hit(mul)
	return { box = { -400, 400, 200, 200 }, mul = mul, seg = 1, at = 0 }
end
local function ready(room, heroes)
	local mob = room.mobs[1]
	for _ = 1, 200 do
		room:step(heroes, 1 / 20)
		if mob.state ~= "spawn" and mob.state ~= "gone" and mob.state ~= "dead" then
			break
		end
	end
	return mob
end
local function has(list, id)
	return table.find(list, id) ~= nil
end

-- ① · ④
do
	local room = solo(1)
	local a, b, c = Hero.new(1, "axion"), Hero.new(2, "riven"), Hero.new(3, "mooni")
	local mob = room.mobs[1]
	for _, h in { a, b, c } do
		h.x, h.y, h.invuln = mob.x, mob.y, 99
	end
	local all = { [1] = a, [2] = b, [3] = c }
	ready(room, all)
	local tap = room:skillHit(a, hit(0.01), a.x, a.y, 1, 1)
	eq(#tap.kills, 0, "한 대(약하게)로는 쓰러지지 않는다")
	expect(mob.hp > 0 and mob.hp < mob.maxHp, "깎였다")
	local xa = a.xp
	local out = room:skillHit(b, hit(9999), b.x, b.y, 1, 1, { b, c }) -- b · c는 파티 · a는 남
	eq(#out.kills, 1, "b가 잡았다")
	local kill = out.kills[1]
	expect(kill.credit ~= nil, "잡은 기록에 credit이 있다")
	expect(has(kill.credit, 1), "한 대 친 a도 센다(파티가 아니어도)")
	expect(has(kill.credit, 2), "잡은 b는 센다")
	expect(has(kill.credit, 3), "b의 파티원 c(치지 않음 · 같은 맵)도 센다 — 예전 그대로")
	eq(#kill.credit, 3, "한 사람을 두 번 넣지 않는다")
	local gainIds = {}
	for _, g in kill.gains do
		table.insert(gainIds, g.hero)
	end
	expect(not has(gainIds, 1), "경험치는 a에게 가지 않는다(잡은 사람 · 그 파티만 — 그대로)")
	eq(a.xp, xa, "a의 경험치는 그대로")
	eq(mob.hitBy, nil, "쓰러지면 친 사람의 기록을 거둔다")
end

-- ② 친 뒤 쓰러졌다 · 맵을 떠났다
do
	local room = solo(2)
	local a, b = Hero.new(1, "axion"), Hero.new(2, "riven")
	local mob = room.mobs[1]
	for _, h in { a, b } do
		h.x, h.y, h.invuln = mob.x, mob.y, 99
	end
	ready(room, { [1] = a, [2] = b })
	room:skillHit(a, hit(0.01), a.x, a.y, 1, 1)
	a.alive = false
	local out = room:skillHit(b, hit(9999), b.x, b.y, 1, 1)
	expect(not has(out.kills[1].credit, 1), "친 뒤 쓰러진 사람은 세지 않는다")
	expect(has(out.kills[1].credit, 2), "잡은 사람은 센다")
end
do
	local room = solo(3)
	local a, b = Hero.new(1, "axion"), Hero.new(2, "riven")
	local mob = room.mobs[1]
	for _, h in { a, b } do
		h.x, h.y, h.invuln = mob.x, mob.y, 99
	end
	ready(room, { [1] = a, [2] = b })
	room:skillHit(a, hit(0.01), a.x, a.y, 1, 1)
	room:step({ [2] = b }, 1 / 20) -- a가 맵을 떠났다
	local out = room:skillHit(b, hit(9999), b.x, b.y, 1, 1)
	expect(out.kills[1] and not has(out.kills[1].credit, 1), "친 뒤 맵을 떠난 사람은 세지 않는다")
end

-- ③ 다시 나온 몬스터는 새로 센다
do
	local room = solo(4)
	local a, b = Hero.new(1, "axion"), Hero.new(2, "riven")
	local mob = room.mobs[1]
	for _, h in { a, b } do
		h.x, h.y, h.invuln = mob.x, mob.y, 99
	end
	local both = { [1] = a, [2] = b }
	ready(room, both)
	room:skillHit(a, hit(0.01), a.x, a.y, 1, 1)
	room:skillHit(b, hit(9999), b.x, b.y, 1, 1)
	expect(mob.state == "dead", "잡았다")
	ready(room, both)
	expect(mob.state ~= "dead" and mob.state ~= "gone" and mob.hp == mob.maxHp, "다시 나왔다")
	local out = room:skillHit(b, hit(9999), b.x, b.y, 1, 1)
	eq(#out.kills, 1, "b가 혼자 잡았다")
	expect(not has(out.kills[1].credit, 1), "전의 삶에서 친 a는 이번에는 세지 않는다")
	eq(#out.kills[1].credit, 1, "b 하나")
end
