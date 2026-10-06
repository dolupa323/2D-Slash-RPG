-- 숫자 뼈대의 식 — 공방 설계 자료(dino-workshop/js/lune/design/numbers.js · economy.js)와 같은 식을 다시 짠 것.
--  상수는 data/numbers.generated.luau에서 읽는다(여기에 숫자를 직접 적지 않는다). 공방의 식을 고치면 여기도 같이 고친다 —
--  tools/test/tests/11_lune_numbers.luau가 공방에서 셈한 값(checks)과 맞춰 본다.
local D = require(script.Parent.Parent.data["numbers.generated"])

local C, POWER, BODY, STATS = D.CURVE, D.POWER, D.BODY, D.STATS
local MAX = D.MAX_LEVEL

local N = {}
N.MAX_LEVEL = MAX
N.data = D

local function round(v: number): number
	return math.floor(v + 0.5)
end

-- ---- 레벨과 경험치 ----
function N.minutesAt(L: number): number -- 그 레벨에서 다음 레벨까지 드는 분
	return C.T0 + C.C * L ^ C.K
end
function N.rateAt(L: number): number -- 같은 레벨 몬스터를 1분에 몇 마리 잡나
	return C.rate0 + (C.rate1 - C.rate0) * L / MAX
end
function N.killsAt(L: number): number
	return round(N.minutesAt(L) * N.rateAt(L))
end
function N.mobXp(L: number): number
	return round(C.xp0 * C.xpR ^ L)
end
function N.mobHp(L: number): number
	return round(C.hp0 * C.hpR ^ L)
end
function N.xpNeed(L: number): number -- 다음 레벨까지 필요한 경험치
	return N.killsAt(L) * N.mobXp(L)
end
-- 내 레벨과 몬스터 레벨의 차이에 따른 경험치 %(차이 10 안쪽 100 · 11~20은 한 레벨마다 5씩 줄어 50까지 · 21 넘으면 10)
function N.xpRate(myLevel: number, mobLevel: number): number
	local diff = math.abs(myLevel - mobLevel)
	local rule = D.XPRULE.diff
	if diff <= rule[1].upto then
		return rule[1].pct
	elseif diff <= rule[2].upto then
		return rule[1].pct - (rule[1].pct - rule[2].pct) * (diff - rule[1].upto) / (rule[2].upto - rule[1].upto)
	end
	return rule[3].pct
end
function N.spAt(L: number): number -- 그 레벨이 될 때 받는 스킬 포인트
	local sp = D.SP.early
	for _, step in D.SP.steps do
		if L >= step[1] then
			sp = step[2]
		end
	end
	return if L > D.SP.steps[#D.SP.steps][1] then 0 else sp
end

-- ---- 전투력 ----
function N.refPower(L: number): number -- 그 레벨의 사냥 장비를 다 찬 전투력
	return round(POWER.base * POWER.grow ^ L)
end

-- ---- 능력치 ----
function N.apAt(L: number): number -- 그 레벨까지 받은 능력치 점수
	return STATS.perLevel * (L - 1)
end
function N.statAttack(main: number, sub: number): number
	return STATS.mainW * main + STATS.subW * sub
end
-- 능력치 효율: 다 주 능력치에 찍었을 때 1. toHp = 체력에 찍은 점수 · toSub = 부 능력치에 찍은 점수
function N.statEff(L: number, toHp: number?, toSub: number?): number
	local hp, sub = toHp or 0, toSub or 0
	return N.statAttack(STATS.base + N.apAt(L) - hp - sub, STATS.base + sub) / N.statAttack(STATS.base + N.apAt(L), STATS.base)
end

-- ---- 맞는 쪽 ----
function N.baseHp(L: number): number
	return round(BODY.hp0 * BODY.hpR ^ L)
end
function N.hpOf(class: string, L: number, toHp: number?): number
	return round(N.baseHp(L) * BODY.classHp[class] * (1 + (toHp or 0) * STATS.hpPerPoint / 100))
end
function N.armorCut(armorLv: number, mobLv: number): number -- 방어구가 줄여 주는 피해 %
	return math.max(BODY.armor.min, math.min(BODY.armor.max, BODY.armor.same + BODY.armor.per10 * (armorLv - mobLv) / 10))
end
-- 한 방의 크기. kind = mob 일반 몬스터 · field 필드 보스 · lieutenant 부관 · boss · big · wipe
function N.hitOf(kind: string, mobLv: number, armorLv: number?): number
	return round(N.baseHp(mobLv) * BODY.hit[kind] / 100 * (1 - N.armorCut(armorLv or mobLv, mobLv) / 100))
end
-- 방어로 줄이기 전의 한 방(방어구는 sim/items.luau의 cut이 부위마다 셈한다)
function N.rawHit(kind: string, mobLv: number): number
	return N.baseHp(mobLv) * BODY.hit[kind] / 100
end
function N.deathMinutes(L: number): number -- 쓰러진 뒤 벌칙이 이어지는 분
	return round(BODY.death.min + (BODY.death.max - BODY.death.min) * L / MAX)
end
-- 그 레벨에 쓰는 물약(이름 · 회복 % · 값)
function N.potionAt(L: number)
	local best = BODY.potion[1]
	for _, p in BODY.potion do
		if p.lv <= L then
			best = p
		end
	end
	return best
end

-- ---- 달돈 ----
function N.killMoney(L: number): number -- 같은 레벨 몬스터 한 마리의 평균 달돈
	return L * (D.COIN.a + L / D.COIN.b)
end

return N
