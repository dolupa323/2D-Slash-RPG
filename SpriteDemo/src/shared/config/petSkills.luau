-- 펫 패시브 스킬(M4) — GAME_DESIGN §2. 공방 js/skills.js와 같은 수치(초안, 사용자 확인 후 조정).
--  플레이어가 공격할 때마다(TownAttack) 함께 다니는 펫마다 발동 판정 → 서버가 피해(주인 기여도에 합산)·회복을 주고,
--  같은 씬 모두에게 PetSkill 연출 이벤트를 보낸다. 종별 스킬·이펙트는 shared/data/petSkills.generated.luau(공방 내보내기).
--  거리 단위는 도트(combat.luau와 같음).
local generated = require(script.Parent.Parent.data["petSkills.generated"])

local exports = {}

-- 패턴: 발동 확률(공격 1번당) · 피해 배율(× 펫 힘)
exports.PATTERNS = {
	bolt = { name = "투사체", proc = 0.30, mult = 1.0 }, -- 가장 가까운 몬스터 한 마리(사거리 BOLT_RANGE)
	burst = { name = "주변 원형", proc = 0.20, mult = 0.7 }, -- 플레이어 둘레 BURST_RADIUS 안 모두
	orbit = { name = "회전", proc = 0.15, mult = 0.35 }, -- ORBIT_TIME초 동안 둘레를 돌며 ORBIT_TICK초마다
	drop = { name = "낙하", proc = 0.20, mult = 1.3 }, -- 방금 맞힌(없으면 가까운) 몬스터 자리에 DROP_DELAY 뒤, 반지름 DROP_RADIUS
	buff = { name = "버프", proc = 0.15, mult = 0 }, -- 플레이어 체력을 최대 체력의 HEAL_RATIO만큼 회복
}

exports.PET_COOLDOWN = 0.8 -- 펫 한 마리가 연달아 쓰지 못하는 시간(초)
exports.HEAL_RATIO = 0.05
exports.BOLT_RANGE = 80
exports.BOLT_FLIGHT = 0.35 -- 날아가는 시간(초) — 도착할 때 피해
exports.BURST_RADIUS = 28
exports.BURST_DELAY = 0.25
exports.ORBIT_TIME = 3
exports.ORBIT_TICK = 0.5
exports.ORBIT_RADIUS = 30 -- 도는 원 반지름(도트) — 이 근처(±ORBIT_BAND)에 있는 몬스터가 맞는다
exports.ORBIT_BAND = 14
exports.DROP_DELAY = 0.4
exports.DROP_RADIUS = 16
exports.DROP_RANGE = 80 -- 맞힌 몬스터가 없을 때 고를 거리

-- 펫 힘 = 4 + 1.2 × 펫 레벨 (Lv1 5 · Lv10 16 · Lv50 64 · Lv100 124)
function exports.Power(level: number): number
	return 4 + 1.2 * level
end

function exports.Damage(pattern: string, level: number): number
	local p = exports.PATTERNS[pattern]
	return if p then math.max(1, math.round(exports.Power(level) * p.mult)) else 0
end

-- 종 id → { name, pattern, ... } (없으면 nil)
function exports.SkillOf(speciesId: string)
	return generated.species[speciesId]
end

exports.generated = generated

return exports
