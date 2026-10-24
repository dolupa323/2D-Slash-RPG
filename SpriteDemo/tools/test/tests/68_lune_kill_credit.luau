-- 「달의 계승자」 — 퀘스트 · 일일 의뢰의 「몇 마리 잡기」를 누구에게 세 주는가(shared/lune/sim/room.luau Room:strike의 credit · 서버 world.luau applyResult).
--  사용자 2026-10-21: "퀘스트 깰때 몇마리 잡아라 이런거 있잖아요 내가 한대만 치면 다른사람이 잡아도 잡은걸로 판정이 들어가야해요"
--  보는 것: ① 파티가 아닌 사람이 한 대 치고 다른 사람이 잡으면 둘 다 센다 ② 친 뒤 쓰러졌거나 맵을 떠난 사람은 세지 않는다
--   ③ 다시 나온 몬스터는 새로 센다(전에 친 것은 넘어가지 않는다) ④ 잡은 사람의 파티원(같은 맵)은 치지 않아도 센다(예전 그대로)
--   ⑤ 경험치는 때린 만큼 나눈다 · 떨어지는 것은 가장 많이 깎은 사람의 것(2026-10-22 사용자 "지금 필드에서 막타 뺏기면 경험치도 못먹나?" → "때린만큼 나눠받기로 하자")
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
	expect(has(gainIds, 1), "한 대 친 a도 경험치를 받는다(때린 만큼 — 2026-10-22)")
	expect(a.xp > xa, "a의 경험치가 올랐다")
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

-- ⑤ 때린 만큼 나눈다: a가 체력의 70%를 깎고 남(b)이 남은 30%로 막타 → a는 혼자 잡을 때의 70% · b는 30% · 떨어지는 것은 a의 것
do
	local room = solo(5)
	local a, b = Hero.new(1, "axion"), Hero.new(2, "riven")
	local mob = room.mobs[1]
	for _, h in { a, b } do
		h.x, h.y, h.invuln = mob.x, mob.y, 99
	end
	ready(room, { [1] = a, [2] = b })
	mob.fieldElite = true -- (사냥터 정예 — 달돈이 반드시 떨어져 주인을 본다)
	local seventy = math.floor(mob.maxHp * 0.7)
	mob.hitBy = { [1] = seventy }
	mob.hp = mob.maxHp - seventy
	local full = Hero.killXp(a, mob.lv, mob.def.hp) -- 혼자 잡을 때의 경험치(정예 배수 앞)
	local xa, xb = a.xp, b.xp
	local out = room:skillHit(b, hit(9999), b.x, b.y, 1, 1)
	eq(#out.kills, 1, "b가 막타")
	local kill = out.kills[1]
	local got = {}
	for _, g in kill.gains do
		got[g.hero] = g.xp
	end
	expect(got[1] and got[2], "둘 다 경험치를 받는다")
	local ratio = got[1] / got[2]
	expect(math.abs(ratio - seventy / (mob.maxHp - seventy)) < 0.1, ("a : b = 깎은 체력의 비(%.2f — 기대 %.2f)"):format(ratio, seventy / (mob.maxHp - seventy)))
	local want = full * COMBAT.fieldElite.xp
	expect(math.abs(got[1] + got[2] - want) <= 1.5, ("둘의 합 = 한 마리(정예)의 경험치(%d + %d ≈ %.1f)"):format(got[1], got[2], want))
	eq(a.xp - xa, got[1], "a의 경험치가 그만큼 오른다")
	eq(b.xp - xb, got[2], "b의 경험치가 그만큼 오른다")
	expect(kill.drop ~= nil and kill.drop.owner == 1, "떨어진 달돈은 가장 많이 깎은 a의 것(막타 b가 아니라)")
	expect(has(kill.credit, 1) and has(kill.credit, 2), "퀘스트 숫자는 둘 다")
end

-- ⑥ 혼자 잡으면 예전 그대로(다 받는다) · 막타를 남에게 뺏겨도 내가 거의 다 깎았으면 거의 다 받는다
do
	local room = solo(6)
	local a = Hero.new(1, "axion")
	local mob = room.mobs[1]
	a.x, a.y, a.invuln = mob.x, mob.y, 99
	ready(room, { [1] = a })
	local full = Hero.killXp(a, mob.lv, mob.def.hp)
	local out = room:skillHit(a, hit(9999), a.x, a.y, 1, 1)
	eq(out.kills[1].gains[1].xp, math.max(1, math.floor(full + 0.5)), "혼자 잡으면 한 마리의 경험치를 다")
	eq(#out.kills[1].gains, 1, "받는 사람은 하나")
end
