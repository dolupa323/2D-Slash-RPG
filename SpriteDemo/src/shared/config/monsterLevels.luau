-- 몬스터 레벨 규칙(클라이언트·서버 공용) — 도감 순서(townWorld.generated의 species, 속성별 순번)가 곧 강함의 단계다.
--  속성마다 n번째 몬스터 = n단계. 1단계(불꽃병아리·물펭구·새싹토끼)는 자연 스폰 Lv.1~5,
--  2단계(불여우·조개수달·숲곰)는 Lv.5~10, n단계는 Lv.5(n-1)~5n.
-- 체력·경험치 공식도 여기에만 둔다(서버가 경험치를 줄 때 같은 공식으로 검증).
local world = require(script.Parent.Parent.data["townWorld.generated"])

local exports = {}

exports.LEVELS_PER_TIER = 5

-- 시트 줄 번호(species 순서, 1부터) → 속성 안 순번(단계)
local tierOf = {}
do
	local count = {}
	for row, s in world.species do
		count[s.element] = (count[s.element] or 0) + 1
		tierOf[row] = count[s.element]
	end
end

function exports.Tier(row: number): number
	return tierOf[row] or 1
end

-- 자연 스폰 레벨 범위(최소, 최대)
function exports.LevelRange(row: number): (number, number)
	local tier = exports.Tier(row)
	return math.max(1, (tier - 1) * exports.LEVELS_PER_TIER), tier * exports.LEVELS_PER_TIER
end

-- 레벨별 몬스터 체력(Lv.1 = 30, 레벨당 +10)
function exports.MaxHealth(level: number): number
	return 20 + level * 10
end

-- 처치 경험치(Lv.1 = 15, 레벨당 +5) — 플레이어 1레벨 필요 경험치는 100(balance.maxExperienceFor)
function exports.Experience(level: number): number
	return 10 + level * 5
end

return exports
