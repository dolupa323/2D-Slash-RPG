-- 몬스터 레벨 규칙(클라이언트·서버 공용) — GAME_DESIGN.md §2.
--  종마다 자연 스폰 레벨 범위가 있다(townWorld.generated의 species[i].levelMin~levelMax, 공방 js/buns.js의 lv). 최대 100.
--  레벨이 곧 희귀도: 범위 안에서도 높은 레벨일수록 드물게 나온다(RollLevel — 범위 맨 아래가 가장 흔하고 위로 갈수록 선형으로 줄어듦).
--  예전 내보내기(범위가 없는 species)는 도감 순번으로 계산하던 옛 규칙으로 대신한다(공방에서 다시 보내면 사라짐).
-- 체력·경험치 공식도 여기에만 둔다(서버가 경험치를 줄 때 같은 공식으로 검증).
local world = require(script.Parent.Parent.data["townWorld.generated"])

local exports = {}

exports.MAX_LEVEL = 100
local LEGACY_LEVELS_PER_TIER = 5

-- 옛 규칙(속성 안 순번 = 단계, n단계 = Lv.5(n-1)~5n)
local tierOf = {}
do
	local count = {}
	for row, s in world.species do
		count[s.element] = (count[s.element] or 0) + 1
		tierOf[row] = count[s.element]
	end
end

-- 자연 스폰 레벨 범위(최소, 최대)
function exports.LevelRange(row: number): (number, number)
	local s = world.species[row]
	if s and s.levelMin and s.levelMax then
		return s.levelMin, s.levelMax
	end
	local tier = tierOf[row] or 1
	return math.max(1, (tier - 1) * LEGACY_LEVELS_PER_TIER), tier * LEGACY_LEVELS_PER_TIER
end

-- 스폰 레벨 뽑기: 범위 안 레벨 L의 가중치 = (최대 - L + 1) — 낮은 레벨이 흔하고 높은 레벨이 드물다
function exports.RollLevel(row: number, rng: Random): number
	local lo, hi = exports.LevelRange(row)
	local total = 0
	for level = lo, hi do
		total += hi - level + 1
	end
	local pick = rng:NextNumber() * total
	for level = lo, hi do
		pick -= hi - level + 1
		if pick < 0 then
			return level
		end
	end
	return lo
end

-- 레벨별 몬스터 체력(Lv.1 = 30, 레벨당 +10)
function exports.MaxHealth(level: number): number
	return 20 + level * 10
end

-- 몬스터 공격력(방어력을 빼기 전, 최소 1): Lv.1 = 6, 레벨당 +2
function exports.AttackDamage(level: number): number
	return 4 + level * 2
end

-- 처치 경험치(Lv.1 = 15, 레벨당 +5) — 플레이어 1레벨 필요 경험치는 100(balance.maxExperienceFor)
function exports.Experience(level: number): number
	return 10 + level * 5
end

return exports
