-- 「달의 계승자」 — 용암 거인의 팔: 겨눌 자리 = 손(2026-11-10 사용자 "용암거인 팔의 히트박스 문제야 무슨 거의 겨드랑이쪽에 판정이있어서 용암거인팔패턴에서 손에있어야해 거기에 데미지가떠야하는거고"). 보는 것:
--  ① 부위마다 겨눌 자리(Gim.aimAt — 남은 체력으로 부위를 고른다): 왼팔 = 벽에서 손 쪽 · 오른팔 = 반대 · 몸통 = 가운데 · 부위가 없는 몬스터 = 없다
--  ② 서버(sim/caster.luau): 손 앞(벽에서 300점 넘게 떨어진 자리)에 서도 리퍼 「단죄」가 거인을 골라 피해를 낸다(전에는 벽까지 280점을 넘어 아무것도 고르지 못했다)
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local LavaGim = req("ReplicatedStorage/shared/lune/sim/lavagim")
local DT = 1 / 30

-- ① 겨눌 자리
local room = Room.new("r3d5#wn7", SCENES.scenes.r3d5, Random.new(7))
local m = room.bosses[1]
local parts = m.def.story.gimmick.parts
local larm = LavaGim.aimAt(m.def, m.maxHp, m.maxHp)
expect(larm ~= nil and larm[1] < -100 and larm[2] > 0, "왼팔의 겨눌 자리 = 벽에서 손 쪽(왼쪽 100점 넘게)")
local rarm = LavaGim.aimAt(m.def, m.maxHp * (1 - parts[1].share) - 1, m.maxHp)
expect(rarm ~= nil and rarm[1] > 100, "오른팔의 겨눌 자리 = 반대쪽(오른쪽 100점 넘게)")
local body = LavaGim.aimAt(m.def, m.maxHp * 0.3, m.maxHp)
expect(body ~= nil and body[1] == 0, "몸통 = 가운데")
eq(LavaGim.aimAt(COMBAT.mobs.shroom or {}, 10, 10), nil, "부위가 없는 몬스터는 겨눌 자리가 없다")
for _, p in parts do
	local b = p.box
	expect(p.aim[1] >= b[1] and p.aim[1] <= b[2], p.name .. ": 겨눌 자리가 판정 상자 안(가로)")
	expect(p.aim[2] >= b[3] and p.aim[2] <= b[4], p.name .. ": 겨눌 자리가 판정 상자 안(높이)")
end

-- ② 손 앞에서 「단죄」
local h = Hero.new(701, "reaper")
Hero.setLevel(h, 150)
h.skills.rp_judge = 20
Hero.recalc(h)
h.hp = h.maxHp
local heroes = { [h.id] = h }
for _ = 1, math.floor((LavaGim.spawnTime(m) + 0.4) / DT) do
	room:step(heroes, DT)
end
local handX = m.x + larm[1]
h.x, h.y, h.dir, h.invuln = handX - 140, 176, 1, 99
expect(math.abs(m.x - h.x) > 280, ("벽(보스의 자리)에서 280점 넘게 떨어진 자리(%d)"):format(math.abs(m.x - h.x)))
local hp0 = m.hp
local ok = room.caster:begin(h, "rp_judge", 1, {}, {})
expect(ok, "「단죄」를 쓴다")
for _ = 1, math.floor(1.6 / DT) do
	h.invuln, h.hp = 99, h.maxHp
	h.x, h.y = handX - 140, 176
	room:step(heroes, DT)
end
expect(m.hp < hp0, ("손 앞에서 쓴 「단죄」가 거인(왼팔)에게 피해(%d → %d)"):format(hp0, m.hp))
