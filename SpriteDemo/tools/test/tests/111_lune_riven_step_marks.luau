-- 「달의 계승자」 — 리븐 「섬영」(2026-10-30 리마스터 — 전에는 「연막 순보」)이 표식을 터뜨린 뒤의 표식 · 다시 쓰기 · 순간이동(sim/caster.luau의 enter · leave · room.luau의 Room:mark, kits/riven.luau의 flash).
--  2026-10-29 사용자 제보(연막 순보 때): "연막순보를 썼을때 표식을 모두 터트리지만 표식이 남아있다고 표시되는 경우가 있습니다 그 이후로 다시 연막순보를 쓰면 표식이 터지는 이펙트는 있지만 데미지는 안들어갑니다"
--  까닭: 터뜨린 타에 붙은 사출기(지금은 잔영 베기)가 그 적에게 표식을 새로 남기고 화면에 알렸는데, 스킬이 끝날 때 서버가 「묶음이 태운 표식」을 지우며 새 표식까지 지웠다.
--  보는 것: ① 화면에 「표식 있음」을 알린 적은 서버에도 표식이 있다 · 다음 섬영이 그 표식을 진짜로 터뜨린다 ② 사출기가 꺼져 있으면 터뜨린 표식은 사라진다
--   ③ 섬영(2026-10-30): 표식을 터뜨리면 다시 쓰기가 바로 돌아온다 · 같은 적은 3초 안에 다시 되돌리지 않는다 · 표식이 없으면 되돌리지 않는다 · 적의 등 뒤로 순간이동해 돌아선다 · 그림자 일격의 연계 시계
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

-- 섬영 한 번(서버가 돌린다 — 구간 하나: 순간이동 · 베기 · 터뜨리기). 돌려주는 것: 이번에 그 적의 맞은 기록에 화면으로 알린 표식(mark)이 있었는가 · 그 적이 받은 피해 합
local function step(room, h, foe): (boolean, number)
	local c = room.caster
	local a = c:actor(h)
	a.out = { hits = {}, kills = {} }
	local hp0 = foe.hp
	expect(c:begin(h, "rv_step", 1, nil), "섬영 구간 1")
	for _ = 1, 60 do
		room.time += SUB
		c:sub(SUB)
	end
	local told = false
	for _, e in a.out.hits do
		if e.mob == foe.id and e.mark then
			told = true
		end
	end
	return told, hp0 - foe.hp
end

-- ① 잔영 베기(사출기)가 늘 나갈 때(확률 100): 터뜨린 뒤 잔영이 새 표식을 남긴다 → 서버에도 있다
do
	COMBAT.kit.riven.toggle.chance = 100
	local room, h, foe = setup(true)
	room:mark(h, foe, { hits = {} })
	expect(room:marksOf(h, foe) > 0, "처음 표식")
	local told = step(room, h, foe)
	expect(told, "터뜨린 타의 잔영이 새 표식을 남겨 화면에 알렸다")
	expect(room:marksOf(h, foe) > 0, "화면에 알린 표식은 서버에도 남아 있다(전에는 스킬이 끝날 때 함께 지웠다)")
	-- 다음 섬영(같은 적은 3초 뒤 — 그 사이는 터뜨려도 다시 쓰기를 되돌리지 않는다)은 그 표식을 진짜로 터뜨린다: 표식이 있을 때의 피해가 표식이 없을 때보다 크다
	room.time += 3.1
	h.x, h.dir = X, 1
	local _, withMark = step(room, h, foe)
	local room2, h2, foe2 = setup(true)
	local _, noMark = step(room2, h2, foe2) -- 표식 없이(잔영은 터뜨리는 타가 아니라 베기에만 붙는다)
	expect(noMark > 0, "표식이 없어도 베기는 맞는다 — " .. noMark)
	expect(withMark > noMark * 1.2, ("두 번째 섬영은 남은 표식을 터뜨린다(피해 %.0f · 표식 없이 %.0f)"):format(withMark, noMark))
end

-- ② 잔영 베기가 꺼져 있으면: 터뜨린 표식은 서버에서도 사라진다(화면에도 알리지 않는다)
do
	local room, h, foe = setup(false)
	room:mark(h, foe, { hits = {} })
	local told = step(room, h, foe)
	-- 베기(g.hit)는 표식을 남기지 않는 타 · 잔영이 없다 → 새 표식이 없다
	expect(not told, "새 표식을 알리지 않았다")
	eq(room:marksOf(h, foe), 0, "터뜨린 표식은 지워진다")
end

-- ③ 섬영: 다시 쓰기를 되돌린다 · 같은 적은 3초 · 등 뒤로 순간이동 · 연계(그림자 일격)
do
	local room, h, foe = setup(false)
	h.skills.rv_back = 10
	Hero.recalc(h)
	room:mark(h, foe, { hits = {} })
	h.cds.rv_step = room.time + 3 -- (세계 world.luau가 쓴 순간 적는 것 — 여기서는 손으로)
	step(room, h, foe)
	eq(h.cds.rv_step, nil, "표식을 터뜨리면 섬영의 다시 쓰기가 바로 돌아온다")
	expect(h.x > foe.x, ("적의 등 뒤로 순간이동했다(나 %.0f · 적 %.0f)"):format(h.x, foe.x))
	eq(h.dir, -1, "돌아서서 적을 본다")
	expect((h.pass.link or -1) > room.time - 0.5, "그림자 일격: 순간이동한 뒤 연계 시계가 켜졌다(순간이동한 때 + 1초 — 시험은 그 뒤 1초를 돌렸다)")
	-- 같은 적에게 곧바로 다시: 표식을 새로 얹어도 3초 안이면 되돌리지 않는다
	room:mark(h, foe, { hits = {} })
	h.cds.rv_step = room.time + 3
	step(room, h, foe)
	expect(h.cds.rv_step ~= nil, "같은 적은 3초 안에 다시 터뜨려도 다시 쓰기를 되돌리지 않는다")
	-- 표식이 없으면 되돌리지 않는다
	local room2, h2, foe2 = setup(false)
	h2.cds.rv_step = room2.time + 3
	local _, dmg = step(room2, h2, foe2)
	expect(dmg > 0, "표식이 없어도 가까운 적에게 가서 벤다")
	expect(h2.cds.rv_step ~= nil, "표식을 터뜨리지 않았으면 다시 쓰기 그대로")
end

-- ④ 표식 공명(2026-10-30 — 전에는 스미는 독): 섬영이 터뜨린 표식 둘레(90도트)의 다른 표식도 함께 터진다 · 월식 동안 섬영은 다시 쓰기를 늘 되돌린다
do
	local room, h, foe = setup(false)
	h.skills.rv_venom = 10
	Hero.recalc(h)
	local near = room.mobs[2]
	near.state, near.a, near.b, near.y = "idle", 0, 9000, Y
	near.hp, near.maxHp = 1e12, 1e12
	near.x = foe.x + 50
	room:mark(h, foe, { hits = {} })
	room:mark(h, near, { hits = {} })
	step(room, h, foe)
	expect(near.hp < 1e12, "표식 공명: 둘레의 표식도 함께 터져 피해를 받는다")
	eq(room:marksOf(h, near), 0, "표식 공명: 함께 터진 표식은 사라진다")
	-- 월식: 표식을 터뜨리지 않아도 되돌린다
	local room2, h2, foe2 = setup(false)
	h2.skills.rv_eclipse = 10
	Hero.recalc(h2)
	req("ReplicatedStorage/shared/lune/sim/buffs").give(h2, "rv_eclipse", 1, h2.x, h2.y)
	h2.cds.rv_step = room2.time + 3
	step(room2, h2, foe2)
	eq(h2.cds.rv_step, nil, "월식: 섬영을 다시 쓰기 없이 이어 쓴다")
end

-- ⑤ 암살 연계: 등 뒤로 순간이동해 돌아선다 · 무영 섬: 오간 뒤 처음 자리로 돌아온다
do
	for _, id in { "rv_kill", "rv_phantom" } do
		local room, h, foe = setup(false)
		h.skills[id] = 20
		Hero.recalc(h)
		local c = room.caster
		c:actor(h).out = { hits = {}, kills = {} }
		expect(c:begin(h, id, 1, nil), id .. " 구간 1")
		for _ = 1, 40 do
			room.time += SUB
			c:sub(SUB)
		end
		if id == "rv_kill" then
			expect(h.x > foe.x and h.dir == -1, ("암살 연계: 적의 등 뒤로 순간이동해 돌아섰다(나 %.0f · 적 %.0f)"):format(h.x, foe.x))
		else
			expect(math.abs(h.x - X) < 1, ("무영 섬: 처음 자리로 돌아왔다(%.0f)"):format(h.x))
			expect(foe.hp < 1e12, "무영 섬: 앞의 적이 맞았다")
		end
	end
end

-- ⑥ 섬영은 다른 스킬을 쓰는 중에도 쓴다(2026-10-31 사용자 "섬영 거의 그냥 쉽게 쓸수있어야해 지금 너무 선딜, 후딜이 길어" — 동작이 없는 기술 · anytime)
do
	local room, h, foe = setup(false)
	h.skills.rv_flurry = 20
	h.skills.rv_kill = 20
	Hero.recalc(h)
	local c = room.caster
	c:actor(h).out = { hits = {}, kills = {} }
	expect(c:begin(h, "rv_kill", 1, nil), "암살 연계를 쓰기 시작했다")
	for _ = 1, 3 do
		room.time += SUB
		c:sub(SUB)
	end
	expect(c:busy(h), "아직 동작 중이다")
	expect(c:begin(h, "rv_step", 1, nil), "그 사이에도 섬영이 나간다")
	local Kitset = req("ReplicatedStorage/shared/lune/kitset")
	expect(Kitset.skill("rv_step").instant and Kitset.skill("rv_step").anytime, "섬영 = 동작이 없는 기술 · 언제든")
	expect(not Kitset.skill("rv_cleave").anytime, "다른 스킬은 그대로 동작 중에는 못 쓴다")
end
