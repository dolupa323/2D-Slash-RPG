-- 캐릭터 한 명의 상태와 성장 셈 — 체력 · 경험치와 레벨업 · 능력치 · 스킬 레벨 · 물약 · 쓰러짐 · 저장 꼴. 화면 · 네트워크와 상관없는 셈만 한다(서버가 쓴다).
--  수치는 config/numbers.luau(숫자 뼈대), data/combat.generated.luau(싸움의 기본 수치), data/classes.generated.luau(직업과 스킬 목록)에서 온다.
local N = require(script.Parent.Parent.config.numbers)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local CLASSES = require(script.Parent.Parent.data["classes.generated"])
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)
local Quests = require(script.Parent.quests)
local Quick = require(script.Parent.Parent.ui.quick)
local RULES = COMBAT.rules
local STATS = N.data.STATS
local STAT_IDS = { "str", "dex", "int", "luk", "hp" }
local SAVE_VERSION = 1

local Hero = {}
Hero.STAT_IDS = STAT_IDS

-- 직업의 스킬 정의(이름 · 갈래 · 마스터 레벨). 지금은 1차만 있다.
local function skillDef(class: string, id: string)
	local c = CLASSES.classes[class]
	if not c then
		return nil
	end
	for _, s in c.skills do
		if s.id == id then
			return s
		end
	end
	return nil
end
Hero.skillDef = skillDef

-- 처음부터 주는 기술(사냥기 · 보스기 · 이동기)을 레벨 1로
local function grants(class: string)
	local out = {}
	for _, s in CLASSES.classes[class].skills do
		if table.find(CLASSES.skillRule.start, s.type) then
			out[s.id] = 1
		end
	end
	return out
end

-- 그 레벨까지 받은 스킬 포인트
local function spEarned(level: number): number
	local n = 0
	for L = 2, level do
		n += N.spAt(L)
	end
	return n
end
Hero.spEarned = spEarned

-- 능력치 효율: 다 주 능력치에 찍었을 때 1
function Hero.eff(h): number
	local pair = STATS.classes[h.class]
	local main, sub = h.stats[pair[1]], h.stats[pair[2]]
	return N.statAttack(STATS.base + main, STATS.base + sub) / N.statAttack(STATS.base + N.apAt(h.level), STATS.base)
end

-- 전투력 = 10 × (0.3 × 능력치 효율 × 1.07^레벨 + 0.7 × 장비 점수). 장비 점수 = 끼고 있는 장비의 점수를 더해 부위 가중치의 합으로 나눈 것(sim/items.luau)
function Hero.power(h): number
	return Items.power(h.level, Hero.eff(h), Bag.worn(h))
end
-- 반올림하기 전의 전투력(피해의 셈에 쓴다 — 능력치 1점도 피해에 그대로 들어가게)
function Hero.powerRaw(h): number
	return Items.powerRaw(h.level, Hero.eff(h), Bag.worn(h))
end

-- 끼고 있는 방어구가 줄여 주는 피해 %(그 레벨의 몬스터에게 맞을 때)
function Hero.cut(h, mobLv: number): number
	return Items.cut(Bag.worn(h), mobLv)
end

-- 체력 상한을 다시 셈한다(레벨 · 체력에 찍은 점수)
function Hero.recalc(h)
	h.maxHp = N.hpOf(h.class, h.level, h.stats.hp)
	h.hp = math.min(h.hp, h.maxHp)
end

-- 새 캐릭터(Lv.1)
function Hero.new(id: any, class: string)
	assert(CLASSES.classes[class], "없는 직업 " .. tostring(class))
	local h = {
		id = id,
		class = class,
		level = 1,
		xp = 0,
		ap = 0, -- 아직 찍지 않은 능력치 점수
		stats = { str = 0, dex = 0, int = 0, luk = 0, hp = 0 }, -- 찍은 점수(처음 값 4는 빼고)
		sp = 0, -- 아직 쓰지 않은 스킬 포인트
		skills = grants(class), -- [스킬 id] = 레벨
		auto = false, -- true면 레벨업 때 능력치 · 스킬을 저절로 찍는다. 기본은 직접 찍는다(사용자 결정) — 창의 「자동으로 찍기」 · 「추천대로 찍기」는 한 번씩 누르는 단추다
		keys = {}, -- 바꾼 키 { [하는 일] = 키 이름 } — 기본과 다른 것만(클라이언트가 보낸 것을 꼴만 보고 담아 둔다)
		slots = Quick.start(CLASSES.classes[class].skills), -- 퀵슬롯: 칸마다 "potion" · 스킬의 이름표 · false(빈 칸) — shared/lune/ui/quick.luau
		-- 스마트폰의 단추 배치: 같은 열두 칸이지만 PC의 것과 따로 둔다 — PC에서는 손에 익은 키(E · D …)에, 폰에서는 큰 단추에 놓고 싶은 것이 서로 다르다(2026-10-08).
		--  한쪽에서 바꿔도 다른 쪽은 그대로다. 처음 차림은 같다(물약 · 사냥기 · 보스기 · 이동기)
		tslots = Quick.start(CLASSES.classes[class].skills),
		money = 0,
		potions = RULES.startPotions,
		hp = 0,
		maxHp = 0,
		alive = true,
		x = 0,
		y = 0,
		dir = 1,
		invuln = 0, -- 맞은 뒤 무적이 남은 시간(초)
		weak = 0, -- 쓰러진 뒤 벌칙이 남은 시간(초)
		potionWait = 0,
		revive = 0, -- 쓰러진 뒤 일어나기까지 남은 시간(초)
	}
	Bag.init(h) -- 처음 받는 차림(무기와 방어구 네 부위)을 입고 있다
	h.quests = {} -- 퀘스트의 상태(sim/quests.luau의 book)
	Quests.start(h.quests, h.level) -- 첫 메인 퀘스트는 저절로 받는다
	h.maxHp = N.hpOf(class, 1)
	h.hp = h.maxHp
	return h
end

function Hero.xpNeed(h): number
	return N.xpNeed(h.level)
end

-- ---------- 능력치 ----------
-- 능력치에 n점을 찍는다. 찍었으면 true.
function Hero.addStat(h, stat: string, n: number): boolean
	if not table.find(STAT_IDS, stat) or n ~= math.floor(n) or n < 1 or n > h.ap then
		return false
	end
	h.stats[stat] += n
	h.ap -= n
	Hero.recalc(h)
	return true
end

-- 남은 점수를 모두 주 능력치에(「자동으로 찍기」)
function Hero.autoStat(h): number
	local n = h.ap
	if n > 0 then
		Hero.addStat(h, STATS.classes[h.class][1], n)
	end
	return n
end

-- ---------- 스킬 ----------
function Hero.skillLevel(h, id: string): number
	return h.skills[id] or 0
end

-- 스킬 레벨에 따른 세기(레벨 1에서 floor, 마스터에서 1). 배우지 않았으면 0.
function Hero.skillScale(lv: number, max: number): number
	if lv <= 0 then
		return 0
	end
	local floor = CLASSES.skillRule.floor
	return floor + (1 - floor) * (if max > 1 then (lv - 1) / (max - 1) else 1)
end
function Hero.scale(h, id: string): number
	local def = skillDef(h.class, id)
	return if def then Hero.skillScale(Hero.skillLevel(h, id), def.max) else 0
end

-- 스킬 포인트 1점으로 스킬을 한 레벨 올린다. 올렸으면 true.
function Hero.skillUp(h, id: string): boolean
	local def = skillDef(h.class, id)
	if not def or h.sp < 1 or Hero.skillLevel(h, id) >= def.max then
		return false
	end
	h.skills[id] = Hero.skillLevel(h, id) + 1
	h.sp -= 1
	return true
end

-- 남은 스킬 포인트를 추천 순서로 모두 쓴다(「추천대로 찍기」): 사냥기 → 보스기 → 핵심 장치 → 버프 → 나머지
local PRIORITY = { mob = 1, boss = 2, core = 3, buff = 4 }
function Hero.autoSkill(h): number
	local list = table.clone(CLASSES.classes[h.class].skills)
	local index = {}
	for i, s in list do
		index[s.id] = i
	end
	table.sort(list, function(a, b)
		local pa, pb = PRIORITY[a.type] or 9, PRIORITY[b.type] or 9
		if pa ~= pb then
			return pa < pb
		end
		return index[a.id] < index[b.id]
	end)
	local spent = 0
	for _, s in list do
		while h.sp > 0 and Hero.skillUp(h, s.id) do
			spent += 1
		end
	end
	return spent
end

-- ---------- 경험치 ----------
-- 경험치를 얻는다. 오른 레벨 수를 돌려준다.
function Hero.gainXp(h, amount: number): number
	local ups = 0
	if h.level >= N.MAX_LEVEL then
		return 0
	end
	h.xp += amount
	while h.level < N.MAX_LEVEL and h.xp >= N.xpNeed(h.level) do
		h.xp -= N.xpNeed(h.level)
		h.level += 1
		h.ap += STATS.perLevel
		h.sp += N.spAt(h.level)
		ups += 1
	end
	if h.level >= N.MAX_LEVEL then
		h.xp = 0
	end
	if ups > 0 then
		if h.auto then
			Hero.autoStat(h)
			Hero.autoSkill(h)
		end
		h.maxHp = N.hpOf(h.class, h.level, h.stats.hp)
		h.hp = h.maxHp -- 레벨이 오르면 체력이 다 찬다
	end
	return ups
end

-- 몬스터를 잡았을 때의 경험치(레벨 차이 · 쓰러진 뒤의 벌칙을 넣은 값)
function Hero.killXp(h, mobLevel: number, mobHpMul: number): number
	local xp = N.mobXp(mobLevel) * mobHpMul * N.xpRate(h.level, mobLevel) / 100
	if h.weak > 0 then
		xp *= 1 - N.data.BODY.death.cut / 100
	end
	return math.max(1, math.floor(xp + 0.5))
end

-- ---------- 맞기 · 물약 · 쓰러짐 ----------
-- 맞는다. 실제로 들어간 피해를 돌려준다(무적 중이거나 쓰러져 있으면 0).
function Hero.hurt(h, amount: number): number
	if not h.alive or h.invuln > 0 then
		return 0
	end
	local dmg = math.max(1, math.floor(amount + 0.5))
	h.hp = math.max(0, h.hp - dmg)
	h.invuln = RULES.invuln
	if h.hp <= 0 then
		h.alive = false
		h.revive = RULES.reviveWait
		-- 벌칙은 숫자 뼈대대로 정해 둔 레벨부터(그 전에는 벌칙이 없다)
		if h.level >= N.data.BODY.death.free then
			h.weak = N.deathMinutes(h.level) * 60
		end
	end
	return dmg
end

-- 물약을 마신다. 회복한 양을 돌려준다(못 마셨으면 nil).
function Hero.drink(h): number?
	if not h.alive or h.potions <= 0 or h.potionWait > 0 or h.hp >= h.maxHp then
		return nil
	end
	local potion = N.potionAt(h.level)
	local heal = math.floor(h.maxHp * potion.heal / 100 + 0.5)
	local before = h.hp
	h.hp = math.min(h.maxHp, h.hp + heal)
	h.potions -= 1
	h.potionWait = N.data.BODY.cooldown.field
	return h.hp - before
end

-- 시간이 흐른다. 쓰러져 있다가 일어날 때가 되면 true를 돌려준다(일으키는 것은 부른 쪽이 한다).
function Hero.tick(h, dt: number): boolean
	h.invuln = math.max(0, h.invuln - dt)
	h.weak = math.max(0, h.weak - dt)
	h.potionWait = math.max(0, h.potionWait - dt)
	if not h.alive then
		h.revive -= dt
		return h.revive <= 0
	end
	return false
end

function Hero.revive(h)
	h.alive = true
	h.hp = h.maxHp
	h.invuln = 2
	h.revive = 0
end

-- ---------- 퀘스트 ----------
-- 퀘스트를 돌려주고 보상을 받는다. 돌려주는 것: 보상, 오른 레벨 수(안 됐으면 nil과 까닭)
function Hero.questDone(h, id: any)
	local reward, why = Quests.complete(h.quests, id)
	if not reward then
		return nil, why
	end
	h.money += reward.money
	h.potions = math.min(h.potions + reward.potions, Bag.potionMax(h))
	local ups = Hero.gainXp(h, reward.xp)
	return reward, ups
end

-- ---------- 키 설정 ----------
-- 바꾼 키의 표를 받아 둔다. 꼴이 맞는 것만 담는다(하는 일 이름 · 키 이름은 글자와 숫자, 마흔여덟 개까지). 담았으면 true.
local function cleanKeys(map: any)
	if typeof(map) ~= "table" then
		return nil
	end
	local out, n = {}, 0
	for action, key in map do
		if typeof(action) ~= "string" or typeof(key) ~= "string" or #action > 40 or #key > 24 then
			return nil
		end
		if not string.match(action, "^[%w:_]+$") or not string.match(key, "^%w+$") then
			return nil
		end
		n += 1
		if n > 48 then
			return nil
		end
		out[action] = key
	end
	return out
end

-- 퀵슬롯에 놓아도 되는 스킬인가: 이 직업이 키로 쓰는 기술(싸움 수치가 있는 것)이고 배운 것
function Hero.canSlot(h, id: string): boolean
	local def = COMBAT.skills[id]
	return def ~= nil and def.who == h.class and (h.skills[id] or 0) > 0
end

-- 퀵슬롯을 바꾼다(클라이언트가 보낸 칸들 — 꼴과 놓아도 되는 것인지를 본다). touch = 스마트폰의 단추 배치(tslots)를 바꾼다
function Hero.setSlots(h, list: any, touch: boolean?): boolean
	local slots = Quick.clean(list, function(id)
		return Hero.canSlot(h, id)
	end)
	if not slots then
		return false
	end
	if touch then
		h.tslots = slots
	else
		h.slots = slots
	end
	return true
end

function Hero.setKeys(h, map: any): boolean
	local keys = cleanKeys(map)
	if not keys then
		return false
	end
	h.keys = keys
	return true
end

-- ---------- 저장 ----------
-- 저장할 꼴(숫자와 글만). 자리 · 체력 · 무적 같은 그때그때의 것은 넣지 않는다.
function Hero.pack(h)
	return {
		v = SAVE_VERSION,
		class = h.class,
		level = h.level,
		xp = h.xp,
		ap = h.ap,
		stats = table.clone(h.stats),
		sp = h.sp,
		skills = table.clone(h.skills),
		auto = h.auto,
		keys = table.clone(h.keys),
		slots = table.clone(h.slots),
		tslots = table.clone(h.tslots),
		money = h.money,
		potions = h.potions,
		weak = math.floor(h.weak),
		bag = Bag.pack(h),
		quests = Quests.pack(h.quests),
	}
end

local function whole(v: any, min: number, max: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

-- 저장된 것에서 캐릭터를 되살린다. 꼴이 이상하면 nil(새로 골라야 한다).
--  점수가 받은 것보다 많이 찍혀 있으면(식이 바뀌었거나 자료가 깨졌을 때) 찍은 것을 모두 되돌려 준다 — 레벨과 돈은 지킨다.
function Hero.unpack(id: any, data: any)
	if typeof(data) ~= "table" or not CLASSES.classes[data.class] or not whole(data.level, 1, N.MAX_LEVEL) then
		return nil
	end
	local h = Hero.new(id, data.class)
	h.level = data.level
	h.xp = if typeof(data.xp) == "number" and data.xp >= 0 and data.xp < N.xpNeed(h.level) then math.floor(data.xp) else 0
	h.money = if whole(data.money, 0, 9e15) then data.money else 0
	h.potions = if whole(data.potions, 0, 9999) then data.potions else RULES.startPotions
	h.weak = if whole(data.weak, 0, 3600) then data.weak else 0
	h.auto = data.auto == true
	h.keys = cleanKeys(data.keys) or {}
	Bag.unpack(h, data.bag) -- 장비가 생기기 전에 저장된 캐릭터는 처음 차림을 받는다
	h.quests = Quests.unpack(data.quests)
	Quests.start(h.quests, h.level) -- 퀘스트가 생기기 전에 저장된 캐릭터도 첫 메인을 받는다

	-- 능력치: 찍은 것 + 남은 것 = 그 레벨까지 받은 것
	local earned = N.apAt(h.level)
	local used, ok = 0, typeof(data.stats) == "table"
	if ok then
		for _, s in STAT_IDS do
			if whole(data.stats[s], 0, earned) then
				h.stats[s] = data.stats[s]
				used += data.stats[s]
			else
				ok = false
			end
		end
	end
	if ok and used <= earned then
		h.ap = earned - used
	else
		h.stats = { str = 0, dex = 0, int = 0, luk = 0, hp = 0 }
		h.ap = earned
	end

	-- 스킬: 처음부터 주는 것은 늘 1 이상, 쓴 포인트는 받은 것을 넘지 않는다
	local base = grants(h.class)
	local spent, good = 0, typeof(data.skills) == "table"
	local skills = table.clone(base)
	if good then
		for sid, lv in data.skills do
			local def = skillDef(h.class, sid)
			if def and whole(lv, 0, def.max) then
				skills[sid] = math.max(lv, base[sid] or 0)
				spent += skills[sid] - (base[sid] or 0)
			else
				good = false
			end
		end
	end
	if good and spent <= spEarned(h.level) then
		h.skills = skills
		h.sp = spEarned(h.level) - spent
	else
		h.skills = base
		h.sp = spEarned(h.level)
	end
	-- 퀵슬롯: 저장된 것이 말이 되면 그대로, 아니면(퀵슬롯이 생기기 전에 저장된 캐릭터 포함) 처음 차림(Hero.new가 놓아 둔 것)
	if data.slots ~= nil then
		Hero.setSlots(h, data.slots)
	end
	-- 스마트폰의 단추 배치: 저장된 것이 말이 되면 그대로, 없으면(이것이 생기기 전에 저장된 캐릭터) 처음 차림
	if data.tslots ~= nil then
		Hero.setSlots(h, data.tslots, true)
	end

	h.maxHp = N.hpOf(h.class, h.level, h.stats.hp)
	h.hp = h.maxHp
	return h
end

-- 클라이언트에 보내는 내 상태
function Hero.view(h)
	return {
		class = h.class,
		level = h.level,
		xp = h.xp,
		need = N.xpNeed(h.level),
		hp = h.hp,
		maxHp = h.maxHp,
		money = h.money,
		potions = h.potions,
		ap = h.ap,
		stats = h.stats,
		sp = h.sp,
		skills = h.skills,
		power = Hero.power(h),
		keys = h.keys,
		slots = h.slots,
		tslots = h.tslots,
		alive = h.alive,
		weak = math.ceil(h.weak),
	}
end

return Hero
