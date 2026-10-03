-- 포획 규칙(클라이언트·서버 공용) — GAME_DESIGN.md §3. 공방 js/bells.js captureChance와 같은 공식.
--  전투 중에 소비 단축칸(1·2·3)에 놓은 방울을 쓰면 바라보는 방향으로 직선으로 날아가고, 처음 맞은 몬스터에게 포획을 시도한다.
--  자격: 아무도 안 때린 몬스터이거나, 던진 사람이 지금 그 몬스터의 딜 1등일 때만(아니면 튕겨 나감 — "포획 불가").
--  종합 포획 확률 = 방울 기본 포획률 + 레벨 보정 + 체력 보정 (+ 속성 방울 + 잘 만든 방울), 1% ~ 95%.
--  실패하면 몬스터는 도망간다(쓰러뜨린 게 아니라 아무도 재료를 못 받음). 그냥 쓰러뜨리면 = 재료 받기.
--  화면에 보이는 건 가방 방울 상세의 "기본 포획률"뿐 — 종합 확률은 보여 주지 않는다. 판정·굴리기는 서버만.
local exports = {}

-- 방울 등급(1~5) → 기본 포획률. 아이템 id = "Bell<등급>"(shared/data/items.luau)
exports.BASE_RATE = { 0.30, 0.45, 0.60, 0.75, 0.90 }
exports.LEVEL_PENALTY = 0.008 -- 레벨 보정: 몬스터 레벨 1당 −0.8%p
exports.HP_BONUS = 0.50 -- 체력 보정: 깎인 체력 비율 × 최대 +50%p
exports.ELEMENT_BONUS = 0.10 -- 속성 방울 속성 == 몬스터 속성(속성 방울은 M6)
exports.WELL_MADE_BONUS = 0.05 -- 잘 만든 방울(M6)
exports.MIN_CHANCE = 0.01
exports.MAX_CHANCE = 0.95
exports.HINT_HP = 0.3 -- 체력이 이 비율 이하면 몬스터 머리 위에 작은 방울 표시(숫자 없음)

-- 던지기
exports.THROW_RANGE = 80 -- 날아가는 거리(도트)
exports.THROW_WIDTH = 7 -- 직선에서 이만큼(도트) 옆까지 맞음
exports.THROW_SPEED = 180 -- 도트/초
exports.THROW_COOLDOWN = 0.8 -- 초
-- 흔들림(딸랑): 판정을 SHAKES번으로 나눠 굴린다. 한 번 통과 확률 = 종합 확률^(1/SHAKES) → 다 통과하면 성공(전체 확률은 그대로).
-- 딸랑 횟수 = 통과한 판정 수(확률이 낮으면 0~1번 만에 깨지고, 높을수록 끝까지 버팀) — 포켓몬 볼 흔들림과 같은 원리.
exports.SHAKES = 3
exports.RING_TIME = 0.35 -- 룬 문양 원이 그려지는 시간
exports.DING_TIME = 0.45 -- 딸랑 한 번(방울 흔들림 + 몬스터 꿈틀)

-- 맞은 뒤 결과가 보이기까지(서버는 이 시간 뒤에 결과를 적용한다)
function exports.RevealTime(dings: number): number
	return exports.RING_TIME + exports.DING_TIME * dings + 0.15
end

-- 흔들림 판정: (딸랑 횟수, 성공 여부)
function exports.RollShakes(chance: number, rng: Random): (number, boolean)
	local per = chance ^ (1 / exports.SHAKES)
	local dings = 0
	for _ = 1, exports.SHAKES do
		if rng:NextNumber() < per then
			dings += 1
		else
			break
		end
	end
	return dings, dings == exports.SHAKES
end

function exports.BaseRate(tier: number): number
	return exports.BASE_RATE[tier] or exports.BASE_RATE[1]
end

-- 종합 포획 확률
function exports.Chance(level: number, tier: number, hpRatio: number, elementMatch: boolean?, wellMade: boolean?): number
	local p = exports.BaseRate(tier)
		- exports.LEVEL_PENALTY * level
		+ exports.HP_BONUS * (1 - math.clamp(hpRatio, 0, 1))
	if elementMatch then
		p += exports.ELEMENT_BONUS
	end
	if wellMade then
		p += exports.WELL_MADE_BONUS
	end
	return math.clamp(p, exports.MIN_CHANCE, exports.MAX_CHANCE)
end

return exports
