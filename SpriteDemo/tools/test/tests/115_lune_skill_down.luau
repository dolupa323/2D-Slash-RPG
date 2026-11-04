-- 「달의 계승자」 — 스킬 창의 「−」(2026-10-31 사용자: "스킬포인트 초기화 했을때 + 옆에 - 버튼도 만들어서 좀 편의있게 스킬 찍을수있게 해줘").
--  보는 것(sim/hero.luau Hero.skillDown · canSkillDown): 하나 내리면 포인트가 그 차수로 돌아온다 · 처음 주는 레벨 아래로 못 내린다 ·
--   다른 배운 스킬이 먼저 배워야 하는 스킬이면 1 아래로 못 내린다 · 0이 되면 퀵슬롯에서 빠진다 · 내리고 다시 올리면 그대로
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")

local h = Hero.new(1, "riven")
Hero.setLevel(h, 60, Hero.jobAt(60))
Hero.autoSkill(h)
local sp0 = h.sp
-- 처음 주는 레벨(1차 사냥기 · 보스기 · 이동기)은 1 아래로 못 내린다
local start = nil
for _, sk in CLASSES.classes.riven.tiers[1].skills do
	if sk.type == "mob" then
		start = sk.id
	end
end
expect(start ~= nil, "1차 사냥기가 있다")
while Hero.skillLevel(h, start) > 1 do
	expect(Hero.skillDown(h, start), "1차 사냥기를 하나 내린다")
end
eq(Hero.skillLevel(h, start), 1, "처음 주는 레벨까지만")
expect(not Hero.skillDown(h, start), "처음 주는 레벨 아래로는 못 내린다")
expect(h.sp > sp0, "내린 만큼 포인트가 돌아왔다")

-- 포인트는 그 차수로 돌아온다
local before = Hero.spLeft(h, 2)
expect(Hero.skillLevel(h, "rv_cross") > 0, "2차 보스기를 배웠다")
expect(Hero.skillDown(h, "rv_cross"), "2차 보스기를 하나 내린다")
eq(Hero.spLeft(h, 2), before + 1, "2차의 남은 포인트가 하나 늘었다")
expect(Hero.skillUp(h, "rv_cross"), "다시 올린다")
eq(Hero.spLeft(h, 2), before, "다시 올리면 그대로")

-- 먼저 배워야 하는 스킬: 잔영 베기(rv_star) ← 겹 잔영(rv_star2)
h.skills.rv_star, h.skills.rv_star2 = 1, 1
expect(not Hero.canSkillDown("riven", h.job, h.skills, "rv_star"), "겹 잔영을 배운 동안 잔영 베기는 0으로 못 내린다")
expect(Hero.skillDown(h, "rv_star2"), "겹 잔영을 먼저 내린다")
expect(Hero.skillDown(h, "rv_star"), "그 뒤에는 잔영 베기도 0으로")
eq(h.skills.rv_star, nil, "0이면 지운다")

-- 0이 되면 퀵슬롯에서 빠진다
h.skills.rv_step = 1
h.slots[5] = "rv_step"
expect(Hero.skillDown(h, "rv_step"), "섬영을 0으로")
eq(h.slots[5], false, "퀵슬롯에서 빠졌다")
expect(not Hero.skillDown(h, "rv_step"), "0인 스킬은 더 못 내린다")
expect(not Hero.skillDown(h, "ax_roar"), "다른 직업의 스킬은 못 내린다")
