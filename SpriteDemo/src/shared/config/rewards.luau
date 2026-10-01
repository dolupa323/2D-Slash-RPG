-- 몬스터 처치 보상 규칙(서버) — GAME_DESIGN.md §3.
--  기여도 = 그 몬스터에 넣은 피해 ÷ 최대 체력(펫 피해 포함 — M4부터). 개인 기준(파티 합산 없음), 씬이 바뀌면 사라진다.
--  기여도 CONTRIB_MIN 이상인 사람 모두 경험치·골드·재료를 받는다. 딜 1등(동점이면 먼저 때린 사람)은 M2부터 [포획 시도]/[재료 받기]를 고른다.
local exports = {}

exports.CONTRIB_MIN = 0.10

-- 재료는 몬스터마다 하나(그 몬스터의 특징이 담긴 아이템 — townWorld species[i].material = "Mat_<종 id>", 공방 js/materials.js)

-- 재료 개수: Lv1~24 = 1개, 25~49 = 2개, … Lv100 = 5개
function exports.MaterialCount(level: number): number
	return 1 + math.floor(level / 25)
end

-- 골드: 레벨 + 3 근처(±30%)
function exports.Gold(level: number, rng: Random): number
	local base = level + 3
	return math.max(1, math.round(base * rng:NextNumber(0.7, 1.3)))
end

return exports
