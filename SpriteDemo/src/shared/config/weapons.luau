-- 무기 종류와 강화(「오문 닌자전」 NINJA_DESIGN.md §7) — 수치는 전부 여기서 고친다. 클라이언트·서버 공용.
--  무기 아이템은 shared/data/ninjaWeapons.luau(Class = 아래 CLASSES의 키, Level = 쓸 수 있는 레벨, Attack = 공격력).
--  종류마다 기본 공격의 범위·빠르기·세기가 다르다:
--   reach = 앞으로 닿는 거리(도트) · width = 옆 폭(도트) · speed = 공격 시간 배율(작을수록 빠름) · power = 기본 공격 피해 배율
--   (power는 기본 공격에만 — 투척 무기·인술은 공격력 그대로 쓴다)
--   hitFx = 맞은 몬스터 위에 나오는 팩 이펙트(shared/data/ninjaFx.generated.luau의 이름 — 팩 FX/Attack)
--  강화(대장간 NPC 곁에서): +1 ~ +MAX. 한 단계마다 무기 공격력의 BONUS만큼(최소 +1) 오른다.
--   재료 = 그 무기 레벨대의 주괴 × 목표 단계 + 엽전. 실패하면 재료·엽전만 없어지고 단계는 그대로(깨지지 않는다).
local combat = require(script.Parent.combat)

local exports = {}

exports.CLASSES = {
	sword = { name = "도검", reach = 20, width = 22, speed = 1.0, power = 1.0, hitFx = "hit_slash", desc = "빠르기와 범위가 고른 무기." },
	dual = { name = "쌍수", reach = 16, width = 18, speed = 0.7, power = 0.8, hitFx = "hit_cut2", desc = "짧지만 아주 빠르다." },
	heavy = { name = "대형", reach = 24, width = 30, speed = 1.45, power = 1.6, hitFx = "hit_cutx", desc = "느리지만 넓고 세다." },
	polearm = { name = "장병기", reach = 36, width = 12, speed = 1.1, power = 1.1, hitFx = "hit_cut", desc = "멀리 곧게 찌른다." },
	whip = { name = "채찍", reach = 30, width = 36, speed = 1.25, power = 0.95, hitFx = "hit_circle", desc = "넓게 휘둘러 여럿을 친다." },
}
-- 맨손(무기 없음) · 종류가 없는 옛 무기
exports.UNARMED = { name = "맨손", reach = combat.ATTACK_REACH, width = combat.ATTACK_WIDTH, speed = 1, power = 1, hitFx = "hit_claw" }
exports.THROW_HIT_FX = "hit_cut" -- 투척 무기에 맞았을 때

-- 무기 정의(items.luau의 한 줄) → 종류 수치
function exports.ClassOf(def)
	return (def and exports.CLASSES[def.Class or ""]) or exports.UNARMED
end

-- ---- 강화 ----
exports.MAX_PLUS = 10
exports.BONUS = 0.08
exports.RATE = { 1, 1, 1, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2 } -- [목표 단계] = 성공 확률
exports.UPGRADE_NPC = "blacksmith"
-- 무기 레벨 → 강화에 쓰는 주괴(위에서부터, 무기 레벨이 under보다 낮으면 그 주괴)
exports.BARS = {
	{ under = 20, item = "CopperBar" },
	{ under = 45, item = "IronBar" },
	{ under = 60, item = "SilverBar" },
	{ under = 90, item = "GoldBar" },
	{ under = math.huge, item = "MithrilBar" },
}

-- 강화 +plus가 더해 주는 공격력
function exports.Bonus(def, plus: number?): number
	local n = math.clamp(plus or 0, 0, exports.MAX_PLUS)
	if n <= 0 or not def or not def.Attack then
		return 0
	end
	return math.max(n, math.round(def.Attack * exports.BONUS * n))
end

-- 목표 단계(지금 +1)로 올리는 값: { bar = 주괴 아이템 id, bars = 개수, gold = 엽전, rate = 성공 확률 } — 더 못 올리면 nil
function exports.Cost(def, target: number)
	if not def or not def.Attack or target < 1 or target > exports.MAX_PLUS then
		return nil
	end
	local bar = exports.BARS[#exports.BARS].item
	for _, b in exports.BARS do
		if (def.Level or 1) < b.under then
			bar = b.item
			break
		end
	end
	return { bar = bar, bars = target, gold = math.round((20 + def.Attack * 4) * target), rate = exports.RATE[target] }
end

return exports
