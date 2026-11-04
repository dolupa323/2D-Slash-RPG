-- 1차의 온오프 사출기 · 핵심 장치 · 패시브 — 직업마다 셋(공방 js/lune/design/combat.js의 KIT1 → data/combat.generated.luau의 kit).
--  사용자 2026-10-08: "스킬중에 지금 온오프, 차지 이런거 구현 안된건가요" · "지금 옮기던 작업을 하다가 만거죠?" — 사냥기 · 보스기 · 이동기만 옮기고 멈춰 있던 것을 마저 옮겼다.
--   액시온   메아리 도끼(도끼질 세 번째 타마다 달빛 도끼) · 힘 모으기(강타 기술의 키를 누르고 있으면 모인다) · 묵직한 몸(최대 체력 +)
--   리븐     그림자 표창(베기가 맞으면 40%로 표창) · 표식(표식이 있는 적에게 치명타) · 날랜 몸(걸음 · 뛰는 힘 · 회피)
--   리퍼     혼불(낫질이 맞으면 2초에 한 번) · 사신 게이지(맞히면 · 쓰러뜨리면 찬다 — 가득하면 사신화 · 2026-10-31 게이지 직업) · 생기 흡수(쓰러뜨리면 체력 회복)
--   무니     수정 조각(대검이 맞으면 1.5초에 한 번, 수정마다 조각) · 수정 공명(수정이 맺히고, 곁에서 쓴 대검이 수정에서도 나간다) · 지키는 마음(받는 피해 -)
--   살라맨더 불티(주먹이 맞을 때마다) · 열기(맞히면 오르고 50부터 달아오름 — 불꽃이 한 번 더) · 뜨거운 피(체력이 찬다 · 달아오르면 걸음 +)
--  여기는 화면도 방도 모르는 셈이다: 캐릭터의 표(sim/hero.luau)에 얹는 상태 h.kit과, 레벨에 따른 값들. 맞혔을 때 따라 나가는 것(사출기 · 표식 · 수정 …)은 sim/room.luau가 이 값으로 푼다.
--  모든 "세기"는 마스터했을 때의 값이고, 그 스킬의 레벨에 따른 배수(레벨 1에서 40% → 마스터 100%)를 곱한다. 확률 · 시간 · 개수는 레벨과 상관없다.
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local CLASSES = require(script.Parent.Parent.data["classes.generated"])

local KIT = COMBAT.kit -- [직업] = { skills, toggle, core, passive }
local SKILL = COMBAT.kitSkill -- [스킬] = { who, role, max }
local PASS = COMBAT.passive -- 2~4차의 패시브가 장치를 키운다(깊은 호흡 = 3단계 · 영혼 주머니 = 영혼 8 · 끓는 피 = 열기) — 셈은 sim/passives.luau, 여기서는 장치의 크기만 읽는다
local FLOOR = CLASSES.skillRule.floor
local Buffs = require(script.Parent.buffs) -- (사신화의 조건 · 시간을 버프에 건다 — 아래 Buffs.hooks)

local Kit = {}
Kit.data = KIT

local FOLLOW = {} -- [기술] = true: 장치와 사출기가 따라붙는 기술(도끼질 · 베기 · 낫질 · 대검 · 주먹)
for _, k in KIT do
	for _, id in k.skills do
		FOLLOW[id] = true
	end
end

-- 스킬 레벨의 효과(sim/hero.luau의 skillScale과 같은 셈 — 레벨 1에서 floor, 마스터에서 1. 배우지 않았으면 0)
local function scaleOf(lv: number, max: number): number
	if lv <= 0 then
		return 0
	end
	return FLOOR + (1 - FLOOR) * (if max > 1 then (lv - 1) / (max - 1) else 1)
end

-- 2~4차의 패시브 하나의 값과 세기(배우지 않았으면 nil, 0)
local function pass(h, id: string)
	local def = PASS[id]
	local lv = h.skills[id] or 0
	if not def or lv <= 0 or def.who ~= h.class then
		return nil, 0
	end
	return def.fx, scaleOf(lv, def.max)
end

-- 힘 모으기의 단계(액시온: 깊은 호흡을 배우면 3단계) · 모으는 영혼의 수(리퍼: 영혼 주머니) · 달아오르는 열기(살라맨더: 끓는 피)
function Kit.chargeLevels(h): number
	local fx = pass(h, "ax_charge2")
	local n = if fx then fx.levels else (KIT[h.class].core.levels or 0)
	-- 만근(액시온 4차 — 옛 「달 그림자 도끼」 자리 · 2026-10-28 리마스터): 한 단계 더(4단계 — 설계 KITUP.axion.fast.levels)
	local up = COMBAT.kitUp[h.class]
	local fast = up and up.fast
	if fast and fast.levels and h.skills and (h.skills[fast.id] or 0) > 0 then
		n += fast.levels
	end
	return n
end
-- ---------- 리퍼의 사신 게이지 · 사신화(2026-10-31 사용자: "게이지 직업으로 설계하자 메이플 루미너스 처럼 사신화가 1차부터 있고 사신 게이지가 있어 …
--  게이지를 채우는데 너무 오래걸리면안되고, 전직을 할수록 게이지가 빨리차는 형식으로 4차에서 변신하면 광역기 난사하는수준으로") — 수치는 공방 combat.js의 KIT1.reaper.core ----------
local GAUGE = KIT.reaper.core.gauge
local FORM = KIT.reaper.core.form
Kit.FORM = "rp_form" -- 사신화(버프 · 1차부터 처음부터 준다)
function Kit.gaugeMax(): number
	return GAUGE.max
end
-- 사신으로 변해 있는가
function Kit.formed(h): boolean
	return h.buffs ~= nil and Buffs.has(h, Kit.FORM)
end
-- 게이지가 가득한가(사신화를 쓸 수 있다)
function Kit.formReady(h): boolean
	return h.class == "reaper" and (h.kit.gauge or 0) >= GAUGE.max and not Kit.formed(h)
end
-- 사신화의 시간: 차수마다 + 사신의 그릇(3차) + 사신 각성(4차)
function Kit.formTime(h): number
	local t = FORM.dur[math.clamp(h.job or 1, 1, #FORM.dur)]
	for _, id in { "rp_soul2", "rp_awaken" } do
		local fx, s = pass(h, id)
		if fx and fx.formTime then
			t += fx.formTime * s
		end
	end
	return t
end
-- 게이지를 채운다: kind = "hit"(낫 기술이 맞았다 — 한 번 쓸 때 한 번) · "kill"(쓰러뜨렸다) · "reap"(영혼 수확이 맞았다). n = 몇 번어치(저승문 곁의 처치 = 2).
--  차수의 배수(전직할수록 빨리) x 수확의 계약 x 사신 게이지의 레벨. 사신화 동안에는 차지 않는다. 바뀌었으면 true
function Kit.gainGauge(h, kind: string, n: number?): boolean
	if h.class ~= "reaper" or Kit.level(h, "core") < 1 or Kit.formed(h) then
		return false
	end
	local k = h.kit
	local before = k.gauge or 0
	if before >= GAUGE.max then
		return false
	end
	local fx, s = pass(h, "rp_pact")
	local add = (GAUGE[kind] or 0) * (n or 1) * GAUGE.job[math.clamp(h.job or 1, 1, #GAUGE.job)] * (1 + (if fx and fx.gauge then fx.gauge * s else 0)) * Kit.scale(h, "core")
	k.gauge = math.min(GAUGE.max, before + add)
	return k.gauge ~= before
end
-- 사신화 동안 다시 쓰기가 없는 기술인가(사신 각성 — 사냥기 · 공격기: 광역 난사). typ = 그 기술의 갈래(COMBAT.skills · cast의 type)
function Kit.noCd(h, typ: any): boolean
	if h.class ~= "reaper" or not Kit.formed(h) or (typ ~= "mob" and typ ~= "attack") then
		return false
	end
	local fx = pass(h, "rp_awaken")
	return fx ~= nil and fx.nocd == true
end
-- 사신화(버프)를 거는 조건 · 시간 · 건 뒤: 게이지가 가득할 때만 · 시간은 Kit.formTime · 걸면 게이지가 빈다
Buffs.hooks = Buffs.hooks or {}
Buffs.hooks[Kit.FORM] = {
	can = function(h)
		return Kit.formReady(h)
	end,
	dur = function(h)
		return Kit.formTime(h)
	end,
	cast = function(h)
		h.kit.gauge = 0
	end,
}
function Kit.hotAt(h): number
	local fx = pass(h, "sl_heat2")
	return if fx then fx.hot else KIT.salamander.core.hot
end

-- 그 스킬이 어느 직업의 어느 갈래인가({ who, role("toggle" · "core" · "passive"), max } — 장치가 아니면 nil)
function Kit.skill(id: any)
	return if typeof(id) == "string" then SKILL[id] else nil
end

-- 그 캐릭터의 그 갈래의 자료 · 레벨 · 세기(레벨의 효과)
function Kit.def(h, role: string)
	return KIT[h.class][role]
end

function Kit.level(h, role: string): number
	return h.skills[KIT[h.class][role].id] or 0
end

function Kit.scale(h, role: string): number
	local def = KIT[h.class][role]
	return scaleOf(h.skills[def.id] or 0, SKILL[def.id].max)
end

-- 그 기술에 장치와 사출기가 따라붙는가
function Kit.follows(skillId: any): boolean
	return FOLLOW[skillId] == true
end

-- 캐릭터에 얹는 그때그때의 상태. 저장하는 것은 사출기를 켰는지(on)뿐이다(sim/hero.luau의 pack)
--  n = 사출기가 센 타수 · at = 사출기가 마지막으로 나간 때(방의 시간) · gauge = 리퍼의 사신 게이지(2026-10-31 — 그 전: souls 영혼) · heat · heatT = 열기와 마지막으로 맞힌 뒤 흐른 시간 · regen = 아직 차지 않은 회복의 소수
function Kit.init(h)
	h.kit = { on = false, n = 0, at = -1e9, gauge = 0, heat = 0, heatT = 0, regen = 0 }
end

-- ---------- 온오프 사출기 ----------
-- 그 스킬이 이 캐릭터의 (배운) 사출기인가
function Kit.isToggle(h, id: any): boolean
	local def = KIT[h.class].toggle
	return def.id == id and (h.skills[id] or 0) > 0
end

-- 사출기를 켜고 끈다. 바뀐 뒤의 상태를 돌려준다(배우지 않았으면 nil)
function Kit.toggle(h): boolean?
	if Kit.level(h, "toggle") < 1 then
		return nil
	end
	h.kit.on = not h.kit.on
	return h.kit.on
end

-- 사출기가 나가는가(켜 두었고 배웠다)
function Kit.firing(h): boolean
	return h.kit.on and Kit.level(h, "toggle") > 0
end

-- ---------- 늘 걸려 있는 것 ----------
-- 공격력의 배수(2026-10-31 — 리퍼의 영혼 하나마다 +3%는 뺐다: 사신 게이지는 그 자체로 세지지 않는다 · 세지는 것은 사신화)
function Kit.attack(_h): number
	return 1
end

-- 최대 체력의 배수: 액시온의 묵직한 몸
function Kit.maxHp(h): number
	if h.class == "axion" then
		return 1 + KIT.axion.passive.hp / 100 * Kit.scale(h, "passive")
	end
	return 1
end

-- 달아올랐는가(살라맨더: 열기가 hot 이상)
function Kit.hot(h): boolean
	return h.class == "salamander" and Kit.level(h, "core") > 0 and h.kit.heat >= Kit.hotAt(h)
end

-- 걸음 · 뛰는 힘의 배수: 리븐의 날랜 몸 · 살라맨더의 뜨거운 피(달아오름 동안)
function Kit.move(h): (number, number)
	if h.class == "riven" then
		local p, s = KIT.riven.passive, Kit.scale(h, "passive")
		return 1 + p.run / 100 * s, 1 + p.jump / 100 * s
	elseif h.class == "salamander" and Kit.hot(h) then
		return 1 + KIT.salamander.passive.run / 100 * Kit.scale(h, "passive"), 1
	end
	return 1, 1
end

-- 맞지 않을 확률(0~1): 리븐의 날랜 몸
function Kit.dodge(h): number
	if h.class == "riven" then
		return KIT.riven.passive.dodge / 100 * Kit.scale(h, "passive")
	end
	return 0
end

-- 받는 피해의 배수: 무니의 지키는 마음(near = 내 수정 곁인가 — 그러면 두 배로 준다)
function Kit.cut(h, near: boolean?): number
	if h.class == "mooni" then
		local p = KIT.mooni.passive
		return 1 - p.cut / 100 * Kit.scale(h, "passive") * (if near then p.nearMul else 1)
	end
	return 1
end

-- ---------- 힘 모으기(액시온) ----------
-- 단계마다 오르는 초당 피해(레벨 1 ~ 마스터 사이를 고르게 — 공방의 chargeBonus와 같은 셈)
function Kit.chargeBonus(lv: number, max: number): number
	if lv <= 0 then
		return 0
	end
	local b = KIT.axion.core.bonus
	return b[1] + (b[2] - b[1]) * (if max > 1 then (lv - 1) / (max - 1) else 1)
end

-- 힘이 모이는 시간을 줄이는 몫(액시온 「전투 호흡」 — 2026-10-28 리마스터: 공격 속도 대신 모으는 시간 −25%). 서버의 영웅은 걸린 버프에서, 화면의 영웅(kitHero)은 서버가 준 chargeCut
local BUFF = COMBAT.buffs
function Kit.chargeCut(h): number
	if typeof(h.buffs) ~= "table" then
		return math.clamp(h.chargeCut or 0, 0, 0.6)
	end
	local cut = 0
	for id, b in h.buffs do
		local fx = BUFF[id] and BUFF[id].fx
		if fx and fx.chargeCut then
			cut += fx.chargeCut * (b.pow or 1)
		end
	end
	return math.clamp(cut, 0, 0.6)
end

-- 모아 친 한 방의 피해 배수(2026-10-28 사용자 "차징안하고 여러대 때리는거보다 풀차징해서 때리는 한방이 더쎄야해 시간을 생각해서 dps 계산을해서 설계를해야해"):
--  모은 시간만큼(그동안 톡톡 쳤으면 넣었을 피해) x 단계마다 초당 피해 +bonus — 그래서 n단계로 치면 초당 피해가 늘 1 + n x bonus배다.
--  base = 모으지 않고 한 번 다 쓰는 시간 · per = 한 단계가 모이는 시간(전투 호흡을 빼기 전 — 전투 호흡은 빨리 모일 뿐 한 방은 그대로라 그만큼 초당 피해가 오른다)
function Kit.chargeMul(h, level: number, base: number, per: number): number
	local core = KIT[h.class].core
	if level <= 0 or not core.bonus or base <= 0 then
		return 1
	end
	return (1 + level * Kit.chargeBonus(h.skills[core.id] or 0, SKILL[core.id].max)) * (base + level * per) / base
end

-- 1차의 그 기술을 모으지 않고 한 번 다 쓰는 시간(구간들의 시간을 더한 것 — 공격 속도를 곱하기 전)
local function firstTime(skillId: string): number
	local t = 0
	for _, s in COMBAT.skills[skillId].segs do
		t += s.time
	end
	return t
end

-- 그 기술을 held초 동안 모았을 때: 단계 · 피해의 배수 · 더 닿는 거리(도트). 모을 수 없는 기술 · 배우지 않았으면 0 · 1 · 0
--  from = 이 단계에서 모으기 시작한다(넘치는 힘 — 끝까지 모은 강타를 맞힌 직후의 강타는 2단계부터 · 2026-10-28)
function Kit.charge(h, skillId: string, held: number, from: number?): (number, number, number)
	local core = KIT[h.class].core
	local per = core.per and core.per[skillId]
	local lv = h.skills[core.id] or 0
	if not per or lv < 1 then
		return 0, 1, 0
	end
	local level = math.clamp(math.floor(math.max(held, 0) / (per * (1 - Kit.chargeCut(h))) + 1e-6) + (from or 0), 0, Kit.chargeLevels(h))
	return level, Kit.chargeMul(h, level, firstTime(skillId), per), level * core.reach
end

-- 그 기술을 가장 오래 모으는 시간(초 — 모을 수 없으면 0)
function Kit.chargeTime(h, skillId: string): number
	local core = KIT[h.class].core
	local per = core.per and core.per[skillId]
	if not per or (h.skills[core.id] or 0) < 1 then
		return 0
	end
	return per * (1 - Kit.chargeCut(h)) * Kit.chargeLevels(h)
end

-- 1차의 그 기술을 그 단계로 쳤을 때의 피해의 배수 · 더 닿는 거리(서버가 단계를 따로 정했을 때 — 넘치는 힘)
function Kit.chargeAt(h, level: number, skillId: string): (number, number)
	local core = KIT[h.class].core
	local per = core.per and core.per[skillId]
	if not per then
		return 1, 0
	end
	return Kit.chargeMul(h, level, firstTime(skillId), per), level * (core.reach or 0)
end

-- ---------- 맞혔을 때 · 쓰러뜨렸을 때(방이 부른다) ----------
-- 주먹이 맞았다: 열기가 오른다(살라맨더). 맞힌 뒤에 달아올라 있는지를 돌려준다.
--  cast = 그 판(2026-11-04 사용자 "게이지도 3타정도 치면 4번째 공격이 강화공격으로"): 한 판에 한 번만 오른다 — 세 판이면 가득(gain 34 · 차수 배수는 뺐다). 없으면(시험 · 놓인 것) 부를 때마다
function Kit.gainHeat(h, cast): boolean
	if h.class ~= "salamander" or Kit.level(h, "core") < 1 then
		return false
	end
	if cast then
		if cast.heated then
			return Kit.hot(h)
		end
		cast.heated = true
	end
	local core, k = KIT.salamander.core, h.kit
	local fx, s = pass(h, "sl_heat2") -- 끓는 피: 더 빨리 오른다
	k.heat = math.min(core.max, k.heat + core.gain * (1 + (if fx then fx.gain * s else 0)))
	k.heatT = 0
	return k.heat >= Kit.hotAt(h)
end

-- ---------- 살라맨더의 강화판(2026-11-04 사용자 "게이지를 가득채우면 불길에 휩싸이면서 사냥기, 보스기 가 강화되고 강화된 스킬들은 퀵슬롯에서 빛나는거야 그리고 그 스킬을 사용하면
--  열기가 모두 소모되면서 원래스킬이아니라 더 강력한 스킬이 나가는거라고") — 수치는 공방 combat.js의 KIT1.salamander.core.enh · 패시브 폭열 · 용광로 심장 · 백열(PASSIVE의 enh · enhAfter) ----------
-- 그 판(첫 구간)을 강화판으로 쓰는가: 열기가 가득(폭주면 늘) 찬 채 쓴 사냥기 · 보스기면 열기를 모두 쓰고(용광로 심장이면 enhAfter에서 다시 · 폭주는 그대로) 그 판의 모든 타에 곱할 배수를 돌려준다
--  (1 + enh.x[차수] x 열기의 세기 + 패시브의 enh — 아니면 nil). want = 화면이 그 판을 강화판으로 그렸는가: false면 강화하지 않고 열기는 그대로 남는다 · nil이면 서버가 혼자 정한다(시퀀스 · 잴 때)
function Kit.empower(h, kind: string?, want: boolean?): number?
	if h.class ~= "salamander" or want == false or (kind ~= "mob" and kind ~= "boss") or Kit.level(h, "core") < 1 then
		return nil
	end
	local core, k = KIT.salamander.core, h.kit
	local over = h.buffs ~= nil and h.buffs.sl_overheat ~= nil
	if k.heat < core.max and not over then
		return nil
	end
	local more, after = 0, 0
	for id, def in PASS do
		if def.who == h.class and (def.fx.enh or def.fx.enhAfter) then
			local fx, s = pass(h, id)
			if fx then
				more += (fx.enh or 0) * s
				after += (fx.enhAfter or 0) * s
			end
		end
	end
	if not over then
		k.heat, k.heatT = math.min(core.max, after), 0
	end
	return 1 + core.enh.x[math.clamp(h.job or 1, 1, #core.enh.x)] * Kit.scale(h, "core") + more
end

-- ---------- 한 걸음 ----------
-- 시간이 흐른다: 영혼이 흩어지고, 열기가 식고, 체력이 찬다. 돌려주는 것: 장치의 모습이 바뀌었는가(화면에 알린다) · 되찾은 체력(없으면 0)
function Kit.tick(h, dt: number): (boolean, number)
	local k = h.kit
	local changed, healed = false, 0
	if h.class == "salamander" then
		local core = KIT.salamander.core
		if h.buffs and h.buffs.sl_overheat then
			-- 폭주: 열기가 가득한 채 고정(2026-11-03 — 그 전에는 화면만 가득으로 그리고 서버는 식혔다. 이제 강화판이 서버의 열기를 본다)
			if k.heat < core.max then
				k.heat, changed = core.max, true
			end
			k.heatT = 0
		elseif k.heat > 0 then
			k.heatT += dt
			if k.heatT > core.cool then
				local before = k.heat
				local fx, s = pass(h, "sl_heat2") -- 끓는 피: 천천히 식는다
				local hot = Kit.hotAt(h)
				k.heat = math.max(0, k.heat - core.decay * (1 - (if fx then fx.slow * s else 0)) * math.min(dt, k.heatT - core.cool)) -- cool초를 넘긴 만큼만 식는다
				-- 화면의 숫자(5 단위) · 달아오름이 바뀔 때만 알린다
				changed = math.floor(before / 5) ~= math.floor(k.heat / 5) or (before >= hot) ~= (k.heat >= hot)
			end
		end
		-- 뜨거운 피: 초마다 최대 체력의 regen%
		local s = Kit.scale(h, "passive")
		if s > 0 and h.alive and h.hp < h.maxHp then
			k.regen += h.maxHp * KIT.salamander.passive.regen / 100 * s * dt
			if k.regen >= 1 then
				healed = math.min(math.floor(k.regen), h.maxHp - h.hp)
				k.regen -= math.floor(k.regen)
				h.hp += healed
			end
		else
			k.regen = 0
		end
	end
	return changed, healed
end

-- ---------- 화면에 보내는 것 ----------
-- on = 사출기를 켰는가 · gauge = 사신 게이지(정수 — 리퍼) · heat = 열기(정수) · hot = 달아올랐는가
function Kit.view(h)
	local k = h.kit
	return { on = k.on, gauge = math.floor(k.gauge or 0), heat = math.floor(k.heat), hot = Kit.hot(h) }
end

return Kit
