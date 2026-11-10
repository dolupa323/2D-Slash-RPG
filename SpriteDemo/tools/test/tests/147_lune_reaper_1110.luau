-- 「달의 계승자」 — 리퍼 2026-11-10(사용자: "리퍼 피흡 보스전에서도 피흡살짝되게 작은수치로 추가로줘 · 리퍼 4차 보스기 사거리 증가시켜주고 퍼뎀 살짝버프하고 공속 살짝빠르게해줘 · 참수는 조금더 사신화게이지차게"). 보는 것:
--  ① 보스에게 낫 기술이 맞으면 최대 체력의 boss% · bossGap초에 한 번까지(보스가 아닌 적 · 기믹 졸개는 아니다) ② 참수가 맞으면 사신 게이지가 보통 타(hit)보다 더 ③ 참수의 수(배수 · 빠르기 · 판정 앞 60)
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local _Room = req("ReplicatedStorage/shared/lune/sim/room") -- (Caster.makeDry를 단다)
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local KP = COMBAT.kit.reaper.passive
local GA = COMBAT.kit.reaper.core.gauge
expect(KP.boss and KP.boss > 0 and KP.boss <= 0.5 and KP.bossGap >= 0.3, ("보스전의 작은 흡혈 %s%% · %s초"):format(tostring(KP.boss), tostring(KP.bossGap)))
expect(GA.behead > GA.hit, ("참수의 게이지 %s > 보통 타 %s"):format(tostring(GA.behead), tostring(GA.hit)))
expect(COMBAT.cast.rp_behead.tune > COMBAT.cast.rp_judge.tune, "참수의 배수가 단죄보다 크다")
local sk = Kitset.skill("rp_behead")
eq(sk.segs[1].fps, 14, "참수 14장/초(13 → 14)")
-- 판정 = 처음 대수확처럼 앞 160(2026-11-10 사용자 "범위 너무작잖아 엄청 커도된다 원래 사냥기 쓰는것처럼"): 앞 150점의 적도 맞는다
do
	local _R = req("ReplicatedStorage/shared/lune/sim/room")
	local room, foe = Caster.makeDry(1150, 176)
	local c = Caster.new(room)
	c.dry = true
	local hh = Hero.new(2, "reaper")
	Hero.setLevel(hh, 150)
	hh.skills.rp_behead = 30
	Hero.recalc(hh)
	hh.x, hh.y, hh.dir = 1000, 176, 1
	local hp0 = foe.hp
	expect(c:begin(hh, "rp_behead", 1, {}, {}), "참수를 쓴다")
	for _ = 1, 60 do
		room.time += 1 / 60
		c:sub(1 / 60)
	end
	expect(foe.hp < hp0, ("앞 150점의 적이 맞는다(%d → %d)"):format(hp0, foe.hp))
end

local room, foe = Caster.makeDry(1000, 176)
local h = Hero.new(1, "reaper")
Hero.setLevel(h, 150)
h.job = 4
h.skills.rp_drain, h.skills.rp_soul = 10, 10
Hero.recalc(h)
h.x, h.y = 990, 176
foe.def = setmetatable({ boss = true }, { __index = foe.def })
h.hp = math.floor(h.maxHp * 0.5)
local hp0 = h.hp
local g0 = h.kit.gauge or 0
room:kitAfter(h, { { mob = foe, dmg = 100, dead = false } }, h.x, h.y, nil, 1, {}, { hits = {}, kills = {} }, { id = "rp_behead" })
local want = math.max(1, math.floor(h.maxHp * KP.boss / 100 + 0.5))
eq(h.hp - hp0, want, ("보스에게 맞으면 최대 체력의 %s%%(%d)"):format(tostring(KP.boss), want))
expect((h.kit.gauge or 0) - g0 >= GA.behead * 0.99, ("참수 게이지 +%.1f"):format((h.kit.gauge or 0) - g0))
local hp1 = h.hp
room:kitAfter(h, { { mob = foe, dmg = 100, dead = false } }, h.x, h.y, nil, 1, {}, { hits = {}, kills = {} }, { id = "rp_behead" })
eq(h.hp, hp1, "bossGap초 안에는 더 되찾지 않는다")
room.time += KP.bossGap + 0.01
room:kitAfter(h, { { mob = foe, dmg = 100, dead = false } }, h.x, h.y, nil, 1, {}, { hits = {}, kills = {} }, { id = "rp_harvest" })
eq(h.hp - hp1, want, "bossGap초 뒤에는 다시")
local room2, mob = Caster.makeDry(1000, 176)
local hp2 = h.hp
room2:kitAfter(h, { { mob = mob, dmg = 100, dead = false } }, h.x, h.y, nil, 1, {}, { hits = {}, kills = {} }, { id = "rp_harvest" })
eq(h.hp, hp2, "보스가 아닌 적에게는 맞혀도 되찾지 않는다(처치 때만 — 그대로)")
