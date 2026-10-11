-- 2~4차의 패시브(사출기 강화 말고의 것) — 공방 js/lune/design/combat.js의 PASSIVE → data/combat.generated.luau의 passive.
--  사용자 2026-10-08: "작업 이어서 하세요"(남은 2~4차). 패시브 = { who · job · max · fx(세기 — 마스터했을 때의 값) }.
--  세기에는 그 스킬의 레벨에 따른 배수(레벨 1에서 40% → 마스터 100%)를 곱한다. 개수 · 시간 · 기준(단계 · 영혼 · 수정의 수 …)은 배우기만 하면 그 값이다.
--  여기서는 셈만 한다(방 · 캐릭터의 셈이 부른다):
--    주는 피해 — atk(공격력에 늘 곱한다) · vs(그 적에게만 붙는 것: 넘어진 적 · 체력이 많은/적은 적 · 먼 거리 · 이어 맞히기 · 모은 단계 · 옛 사냥기)
--    받는 피해 — cut · dodge(회피 +) · rekindle(쓰러질 피해를 버틴다)
--    표식 치명타(리븐) — crit · 닿는 거리 — reach · 그 밖의 값은 get(캐릭터, 열쇠)로 읽는다(단계 · 영혼 · 수정 · 표식의 수 …)
--  캐릭터에 얹는 그때그때의 상태(저장하지 않는다): h.pass = { streak · streakAt(이어 맞힌 수 · 마지막으로 맞힌 때) · press · pressN · pressAt(이어 때리는 적 · 수 · 때) ·
--    sure(피했다 — 다음 베기가 반드시 치명타) · surge(이때까지 다음 강타가 높은 단계에서 시작한다) · rekindle(다시 버틸 수 있는 때) · edge(대검이 맞은 횟수) · venom(독이 다음에 드는 때) · extended(폭주가 늘어난 시간) }
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local CLASSES = require(script.Parent.Parent.data["classes.generated"])
local Kit = require(script.Parent.kit)

local PASS = COMBAT.passive
local RULES = COMBAT.rules
local FLOOR = CLASSES.skillRule.floor

-- 직업마다: 그 열쇠가 든 패시브들 { [직업] = { [열쇠] = { 스킬 … } } }
local BY = {}
for id, def in PASS do
	BY[def.who] = BY[def.who] or {}
	for key in def.fx do
		BY[def.who][key] = BY[def.who][key] or {}
		table.insert(BY[def.who][key], id)
	end
end
for _, keys in BY do
	for _, list in keys do
		table.sort(list)
	end
end

local Passives = {}
Passives.data = PASS

function Passives.is(id: any): boolean
	return typeof(id) == "string" and PASS[id] ~= nil
end

function Passives.init(h)
	h.pass = { streak = 0, streakAt = -1e9, press = nil, pressN = 0, pressAt = -1e9, sure = false, surge = -1e9, rekindle = -1e9, edge = 0, venom = 0, extended = 0 }
end

-- 그 패시브의 세기(레벨의 배수 — 배우지 않았으면 0)
local function scaleOf(h, id: string): number
	local def = PASS[id]
	local lv = h.skills[id] or 0
	if lv <= 0 or def.who ~= h.class then
		return 0
	end
	return FLOOR + (1 - FLOOR) * (if def.max > 1 then (lv - 1) / (def.max - 1) else 1)
end
Passives.scale = scaleOf

-- 그 열쇠의 값 x 세기를 그 직업의 패시브에서 모두 더한다
local function sum(h, key: string): number
	local list = BY[h.class] and BY[h.class][key]
	if not list then
		return 0
	end
	local total = 0
	for _, id in list do
		local s = scaleOf(h, id)
		if s > 0 then
			total += PASS[id].fx[key] * s
		end
	end
	return total
end
Passives.sum = sum

-- 그 열쇠가 든 패시브를 배웠으면 그 패시브의 값들(fx)과 세기 — 여럿이면 처음 것(배우지 않았으면 nil)
function Passives.get(h, key: string)
	local list = BY[h.class] and BY[h.class][key]
	if list then
		for _, id in list do
			local s = scaleOf(h, id)
			if s > 0 then
				return PASS[id].fx, s
			end
		end
	end
	return nil, 0
end

-- 세기와 상관없는 값(단계 · 영혼 · 수정 · 표식 · 망령 · 수호령의 수 …): 배웠으면 그 값, 아니면 base
function Passives.count(h, key: string, base: number): number
	local fx = Passives.get(h, key)
	return if fx then fx[key] else base
end

-- ---------- 주는 피해 ----------
-- 공격력에 늘 곱하는 것: 공격력 + · 최종 피해 + · 피의 계약(잃은 체력만큼)
function Passives.atk(h): number
	local mul = (1 + sum(h, "atk")) * (1 + sum(h, "final"))
	local pact = sum(h, "pact")
	if pact > 0 and h.maxHp > 0 then
		mul *= 1 + pact * math.clamp(1 - h.hp / h.maxHp, 0, 1)
	end
	return mul
end

-- 그 적에게만 붙는 것. info = { skill 그 기술 · charge 모은 단계 · now 방의 시간 }
function Passives.vs(h, mob, info): number
	local class = BY[h.class]
	if not class then
		return 1
	end
	local mul = 1
	if class.stunned and ((mob.stun or 0) > 0 or (mob.bind or 0) > 0) then
		mul *= 1 + sum(h, "stunned")
	end
	if class.healthy then
		local fx, s = Passives.get(h, "healthy")
		if fx then
			if mob.hp >= mob.maxHp * fx.healthyAt then
				mul *= 1 + fx.healthy * s
			end
			if info and (info.charge or 0) > 0 then
				mul *= 1 + fx.perCharge * s * info.charge
			end
		end
	end
	if class.low then
		local fx, s = Passives.get(h, "low")
		if fx and mob.hp < mob.maxHp * fx.lowAt then
			mul *= 1 + fx.low * s
		end
	end
	if class.far then
		local fx, s = Passives.get(h, "far")
		if fx and math.abs(mob.x - h.x) >= fx.farAt then
			mul *= 1 + fx.far * s
		end
	end
	local p = h.pass
	if class.streak and p then
		local fx, s = Passives.get(h, "streak")
		if fx and p.streak > 0 and info and info.now - p.streakAt <= fx.streakTime then
			mul *= 1 + fx.streak * s * math.min(p.streak, fx.streakMax)
		end
	end
	if class.press and p then
		local fx, s = Passives.get(h, "press")
		if fx and p.press == mob and info and info.now - p.pressAt <= fx.pressTime then
			mul *= 1 + fx.press * s * math.min(p.pressN, fx.pressMax)
		end
	end
	-- 옛 사냥기의 피해 +
	if class.skills and info and info.skill then
		for _, id in class.skills do
			local s = scaleOf(h, id)
			if s > 0 and table.find(PASS[id].fx.skills, info.skill) then
				mul *= 1 + PASS[id].fx.boost * s
			end
		end
	end
	return mul
end

-- 기술의 한 타가 그 적에게 맞았다: 이어 맞힌 수 · 이어 때린 수를 센다(살라맨더)
function Passives.onHit(h, mob, now: number)
	local p = h.pass
	local class = BY[h.class]
	if not p or not class then
		return
	end
	if class.streak then
		local fx = Passives.get(h, "streak")
		if fx then
			p.streak = if now - p.streakAt <= fx.streakTime then math.min(fx.streakMax, p.streak + 1) else 1
			p.streakAt = now
		end
	end
	if class.press then
		local fx = Passives.get(h, "press")
		if fx then
			p.pressN = if p.press == mob and now - p.pressAt <= fx.pressTime then math.min(fx.pressMax, p.pressN + 1) else 1
			p.press, p.pressAt = mob, now
		end
	end
end

-- 치명타(사용자 2026-10-08: "치명타 확률과 치명타 터지는건 만들겁니다"): 모든 직업의 기술 타가 확률로 치명타가 된다.
--  돌려주는 것: 확률(%) · 피해의 배수 · 반드시 치명타인가(리븐의 흘리기 — 피한 직후. 쓰면 사라진다). marked = 그 적에게 내 표식이 있는가(리븐)
--   확률 = 기본(RULES.critChance) + 패시브(창 숙련) + 표식이 있는 적이면 표식의 것 · 배수 = 기본(RULES.critMul) + 패시브(달인) + 표식이 있는 적이면 급소
function Passives.crit(h, marked: boolean?): (number, number, boolean)
	local chance, mul = RULES.critChance + sum(h, "crit"), RULES.critMul + sum(h, "critMul")
	if marked and h.class == "riven" then
		chance += COMBAT.kit.riven.core.crit * Kit.scale(h, "core")
		mul += sum(h, "markCritMul")
	end
	return chance, mul, h.pass ~= nil and h.pass.sure == true
end

-- 기술이 닿는 거리의 배수(리퍼: 낫 숙련 · 영혼이 많을 때의 영혼 주머니)
function Passives.reach(h): number
	local class = BY[h.class]
	if not class or not class.reach then
		return 1
	end
	local add = 0
	for _, id in class.reach do
		local s = scaleOf(h, id)
		local fx = PASS[id].fx
		if s > 0 and (not fx.reachAt or h.kit.souls >= fx.reachAt) then
			add += fx.reach * s
		end
	end
	return 1 + add
end

-- ---------- 받는 피해 ----------
-- 받는 피해의 배수. casting = 기술을 쓰는 중인가(굳센 자세)
function Passives.cut(h, casting: boolean?): number
	local class = BY[h.class]
	if not class then
		return 1
	end
	local mul = 1
	if class.cut then
		local fx, s = Passives.get(h, "cut")
		if fx then
			mul *= 1 - (if casting then fx.cutCast else fx.cut) * s
		end
	end
	if class.cutHot and Kit.hot(h) then
		mul *= 1 - sum(h, "cutHot")
	end
	return mul
end

-- 회피에 더하는 것(0~1)
function Passives.dodge(h): number
	return sum(h, "dodge") / 100
end

-- 피했다: 흘리기를 배웠으면 다음 베기가 반드시 표식 치명타
function Passives.dodged(h)
	local fx = Passives.get(h, "sure")
	if fx and h.pass then
		h.pass.sure = true
	end
end

-- 쓰러질 피해를 받았다(살라맨더의 재점화): 버틸 수 있으면 열기를 모두 태우고, 남길 체력을 돌려준다(못 버티면 nil). now = 방의 시간
function Passives.rekindle(h, now: number): number?
	local fx, s = Passives.get(h, "rekindle")
	if not fx or not h.pass or now < h.pass.rekindle then
		return nil
	end
	h.pass.rekindle = now + fx.cd
	h.kit.heat = 0
	return math.max(1, math.floor(h.maxHp * fx.rekindle * s + 0.5))
end

return Passives
