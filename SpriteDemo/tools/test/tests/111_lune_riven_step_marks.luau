-- 「달의 계승자」 — 리븐 「연막 순보」가 표식을 터뜨린 뒤의 표식(sim/caster.luau의 enter · leave · room.luau의 Room:mark, 2026-10-29).
--  사용자 제보: "연막순보를 썼을때 표식을 모두 터트리지만 표식이 남아있다고 표시되는 경우가 있습니다 그 이후로 다시 연막순보를 쓰면 표식이 터지는 이펙트는 있지만 데미지는 안들어갑니다"
--  까닭: 터뜨린 타에 붙은 그림자 표창(확률)이 그 적에게 표식을 새로 남기고 화면에 알렸는데(맞은 기록의 mark), 스킬이 끝날 때 서버가 「묶음이 태운 표식」을 지우며 새 표식까지 지웠다.
--  보는 것: 화면에 「표식 있음」을 알린 적은 서버에도 표식이 있다 · 다음 연막 순보가 그 표식을 진짜로 터뜨린다(터지는 피해가 들어간다) · 표창이 나가지 않으면 터뜨린 표식은 사라진다
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local SUB = 1 / 60
local X, Y = 200, 176 -- 사냥터(hunt — 폭 608도트) 안: 순간이동이 맵 끝으로 밀리지 않게

local function setup(starOn: boolean)
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(7))
	local h = Hero.new(1, "riven")
	h.level = 60
	h.skills = { rv_step = 10, rv_mark = 10, rv_star = 10 }
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y, h.dir = X, Y, 1
	if starOn then
		Kit.toggle(h)
	end
	for _, m in room.mobs do
		m.state = "gone" -- 다른 적은 없다(그림자 표창이 「가까운 다른 적(없으면 그 적)」 — 늘 그 적에게)
	end
	local foe = room.mobs[1]
	foe.state, foe.a, foe.b, foe.y = "idle", 0, 9000, Y
	foe.hp, foe.maxHp = 1e12, 1e12
	foe.x = X + 60
	return room, h, foe
end

-- 연막 순보 한 번(서버가 돌린다): 구간 1 → 구간 2(순간이동 · 베기 · 터뜨리기). 돌려주는 것: 이번에 그 적의 맞은 기록에 화면으로 알린 표식(mark)이 있었는가 · 터지는 타의 피해 합
local function step(room, h, foe): (boolean, number)
	local c = room.caster
	local a = c:actor(h)
	a.out = { hits = {}, kills = {} }
	local skill = Kitset.skill("rv_step")
	expect(c:begin(h, "rv_step", 1, nil), "연막 순보 구간 1")
	for _ = 1, math.ceil(Caster.segTime("riven", skill.segs[1]) / SUB) + 1 do
		room.time += SUB
		c:sub(SUB)
	end
	expect(c:begin(h, "rv_step", 2, nil), "연막 순보 구간 2")
	for _ = 1, 60 do
		room.time += SUB
		c:sub(SUB)
	end
	local told, burst = false, 0
	for _, e in a.out.hits do
		if e.mob == foe.id then
			if e.mark then
				told = true
			end
		end
	end
	burst = 1e12 - foe.hp
	return told, burst
end

-- ① 그림자 표창이 늘 나갈 때(확률 100): 터뜨린 뒤 표창이 새 표식을 남긴다 → 서버에도 있다
do
	COMBAT.kit.riven.toggle.chance = 100
	local room, h, foe = setup(true)
	room:mark(h, foe, { hits = {} })
	expect(room:marksOf(h, foe) > 0, "처음 표식")
	local told = step(room, h, foe)
	expect(told, "터뜨린 타의 그림자 표창이 새 표식을 남겨 화면에 알렸다")
	expect(room:marksOf(h, foe) > 0, "화면에 알린 표식은 서버에도 남아 있다(전에는 스킬이 끝날 때 함께 지웠다)")
	-- 다음 연막 순보는 그 표식을 진짜로 터뜨린다: 표식이 있을 때의 피해가 표식이 없을 때보다 크다
	local hpBefore = foe.hp
	step(room, h, foe)
	local withMark = hpBefore - foe.hp
	local room2, h2, foe2 = setup(true)
	step(room2, h2, foe2) -- 표식 없이(표창은 터뜨리는 타가 아니라 베기에만 붙는다)
	local noMark = 1e12 - foe2.hp
	expect(noMark > 0, "표식이 없어도 베기는 맞는다 — " .. noMark)
	expect(withMark > noMark * 1.2, ("두 번째 순보는 남은 표식을 터뜨린다(피해 %.0f · 표식 없이 %.0f)"):format(withMark, noMark))
end

-- ② 그림자 표창이 꺼져 있으면: 터뜨린 표식은 서버에서도 사라진다(화면에도 알리지 않는다)
do
	local room, h, foe = setup(false)
	room:mark(h, foe, { hits = {} })
	local told = step(room, h, foe)
	-- 베기(g.hit)는 표식을 남기지 않는 타 · 표창이 없다 → 새 표식이 없다
	expect(not told, "새 표식을 알리지 않았다")
	eq(room:marksOf(h, foe), 0, "터뜨린 표식은 지워진다")
end
