-- 캐릭터 한 명의 상태와 성장 셈 — 체력 · 경험치와 레벨업 · 능력치 · 스킬 레벨 · 물약 · 쓰러짐 · 저장 꼴. 화면 · 네트워크와 상관없는 셈만 한다(서버가 쓴다).
--  수치는 config/numbers.luau(숫자 뼈대), data/combat.generated.luau(싸움의 기본 수치), data/classes.generated.luau(직업과 스킬 목록)에서 온다.
local N = require(script.Parent.Parent.config.numbers)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local CLASSES = require(script.Parent.Parent.data["classes.generated"])
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)
local Quests = require(script.Parent.quests)
local Daily = require(script.Parent.daily)
local Bond = require(script.Parent.bond)
local Rift = require(script.Parent.rift)
local Tutorial = require(script.Parent.tutorial)
local Cash = require(script.Parent.cash) -- 유료 상품(경험치 쿠폰의 배율 · 2026-10-20)
local Kit = require(script.Parent.kit) -- 1차의 온오프 사출기 · 핵심 장치 · 패시브
local Buffs = require(script.Parent.buffs) -- 2~4차의 버프
local Passives = require(script.Parent.passives) -- 2~4차의 패시브
local Quick = require(script.Parent.Parent.ui.quick)
local RIDEIDS = {} -- 펫 · 탈것의 이름표(퀵슬롯에 놓을 수 있다 — 2026-10-21)
do
	local RIDE = require(script.Parent.Parent.data["ride.generated"])
	for _, p in RIDE.pets do
		RIDEIDS[p.id] = true
	end
	for _, m in RIDE.mounts do
		RIDEIDS[m.id] = true
	end
end
local RULES = COMBAT.rules
local STATS = N.data.STATS
local STAT_IDS = { "str", "dex", "int", "luk", "hp" }
local SAVE_VERSION = 1

local Hero = {}
Hero.STAT_IDS = STAT_IDS

-- 직업의 스킬 정의(이름 · 갈래 · 마스터 레벨). 지금은 1차만 있다.
-- 직업의 모든 차수의 스킬(1~4차 + 공용): [직업][스킬] = { def, job }
local ALL = {}
for class, c in CLASSES.classes do
	local map = {}
	for _, t in c.tiers do
		for _, s in t.skills do
			map[s.id] = { def = s, job = t.job }
		end
	end
	ALL[class] = map
end

local function skillDef(class: string, id: string)
	local e = ALL[class] and ALL[class][id]
	return if e then e.def else nil
end
Hero.skillDef = skillDef

-- 그 스킬의 차수(없는 스킬이면 nil)
function Hero.skillJob(class: string, id: string): number?
	local e = ALL[class] and ALL[class][id]
	return if e then e.job else nil
end

-- 그 스킬이 게임에 들어와 있는가(효과가 있는가 — COMBAT.ready: 기술 · 1차의 사출기 · 장치 · 패시브 · 수치가 있는 버프 · 사출기 강화 · 설치 · 소환).
--  아직 없는 스킬에는 포인트가 찍히지 않고, 처음부터 주는 기술로도 주지 않는다 — 찍히는데 효과가 없는 일이 없게(사용자 2026-10-08: 1차의 사출기 · 장치가 그랬다)
local READY = COMBAT.ready
function Hero.ready(id: any): boolean
	return READY[id] == true
end

-- 그 레벨에 닿을 수 있는 차수(레벨만 본 것). 실제 차수는 캐릭터가 갖고 있다(h.job) — 전직 퀘스트를 돌려줘야 오른다(2026-10-10).
--  전직 퀘스트가 아직 없는 차수(지금은 3 · 4차 — 그 지역을 다듬을 때 만든다)는 레벨만 되면 저절로 오른다
function Hero.jobAt(level: number): number
	local job = 1
	for _, j in CLASSES.jobs do
		if j.lv <= level then
			job = math.max(job, j.job)
		end
	end
	return job
end

-- 처음부터 주는 기술(사냥기 · 보스기 · 이동기)을 레벨 1로 — 그 차수까지의 것 모두(게임에 들어와 있는 것만)
local function grants(class: string, job: number?)
	local out = {}
	job = job or 1
	for _, t in CLASSES.classes[class].tiers do
		if t.job <= job then
			for _, s in t.skills do
				if READY[s.id] and table.find(CLASSES.skillRule.start, s.type) then
					out[s.id] = 1
				end
			end
		end
	end
	return out
end

-- 그 직업이 그 차수의 스킬을 모두 마스터하는 데 드는 스킬 포인트(처음부터 주는 레벨 1은 뺀다. 아직 게임에 없는 스킬의 것도 센다 — 그 스킬이 열리면 거기에 쓴다)
--  그 차수 동안 받는 포인트는 이것을 넘지 않는다: 스킬을 다 찍으면 남는 포인트가 없다.
--  사용자 2026-10-11: "스킬 전부 마스터했는데 왜 1차에 남는 스킬포인트가 12 가있는건지?" — 레벨업마다 3점씩 1차 동안 84점을 받는데 다 찍는 데는 72점이 들었다(2차 +2 · 3차 +22~27 · 4차 +4~14점씩 남았다)
local needOf: { [string]: number } = {}
local function spNeed(class: string, job: number): number
	local key = class .. ":" .. job
	local n = needOf[key]
	if n == nil then
		n = 0
		for _, t in CLASSES.classes[class].tiers do
			if t.job == job then
				for _, s in t.skills do
					n += s.max - (if READY[s.id] and table.find(CLASSES.skillRule.start, s.type) then 1 else 0)
				end
			end
		end
		needOf[key] = n
	end
	return n
end
Hero.spNeed = spNeed

-- 그 차수 동안 받은 스킬 포인트. 받은 SP는 그때의 차수 스킬에만 쓴다(설계 basics.js의 SPRULE) — 2차로 전직하면 그 뒤로 받는 SP는 2차 스킬에 쓰고, 1차에서 남긴 SP는 1차 스킬에 계속 쓴다.
--  class를 주면 그 직업이 그 차수에 드는 만큼까지만 센다(다 받았으면 그 차수의 남은 레벨에서는 더 받지 않는다). 안 주면 레벨업마다 받는 양을 그대로 더한다
local function spEarnedIn(level: number, job: number, class: string?): number
	local j = CLASSES.jobs[job]
	local n = 0
	if j then
		for L = math.max(2, j.lv), math.min(level, j["until"]) do
			n += N.spAt(L)
		end
	end
	return if class then math.min(n, spNeed(class, job)) else n
end
Hero.spEarnedIn = spEarnedIn

-- 그 레벨까지 받은 스킬 포인트(class를 주면 차수마다 그 직업이 드는 만큼까지)
local function spEarned(level: number, class: string?): number
	local n = 0
	if class then
		for _, j in CLASSES.jobs do
			n += spEarnedIn(level, j.job, class)
		end
	else
		for L = 2, level do
			n += N.spAt(L)
		end
	end
	return n
end
Hero.spEarned = spEarned

-- 그 레벨이 될 때 그 직업이 받는 스킬 포인트: 보통은 N.spAt(L) — 그 차수에 드는 만큼을 다 받았으면 0(마지막에는 모자란 만큼만)
function Hero.spGain(class: string, level: number): number
	return spEarned(level, class) - spEarned(level - 1, class)
end

-- 그 차수의 스킬에 쓴 포인트 · 남은 포인트
local function spSpentIn(class: string, mine: number, skills, job: number): number
	local base = grants(class, mine) -- mine = 그 캐릭터의 차수
	local n = 0
	for id, lv in skills do
		local e = ALL[class][id]
		if e and e.job == job then
			n += lv - (base[id] or 0)
		end
	end
	return n
end
function Hero.spLeft(h, job: number): number
	return spEarnedIn(h.level, job, h.class) - spSpentIn(h.class, h.job, h.skills, job)
end

-- ---------- 스펙(2026-10-15 — 공방 numbers.js 2-1: 메이플의 스탯 공격력 방식) ----------
--  사용자 2026-10-15: "어디는 전투력 어디는 공격력 강화하면 뭐가오르는건지 하나도 직관적이지가 않아요 … 데미지가 어떤 계산식으로 적용되는지 … 싹다 다시"
--  스탯 공격력 = (주스탯 x 4 + 부스탯) x 공격력 x (1 + 공격력%) / 100 x (1 + 데미지%) x (1 + 최종 데미지%)
--   · 주스탯 · 부스탯(그리고 화면의 힘 · 민첩 · 지능 · 운) = 처음 4 + 찍은 점수 + 장비의 올스탯 · 공격력 = 무기의 공격력(별까지) · 방어력 = 방어구의 합
--   · 공격력% = 패시브(Passives.atkPct) x 리퍼의 영혼(Kit.attack) · 데미지% = 버프(Buffs.dmg) · 최종 데미지 = 패시브(Passives.finalMul)
--  피해 = 스탯 공격력 x 스킬 % x (0.9 ~ 1.1) x (맞는 상대면 1.5) x (크리티컬이면 크리티컬 데미지) — 셈은 sim/room.luau · caster.luau(Hero.powerRaw x 영혼 x 버프 x 패시브)
function Hero.spec(h)
	local pair = STATS.classes[h.class]
	local gear = Items.sum(Bag.worn(h))
	local stats = {}
	for id, pts in h.stats do
		stats[id] = STATS.base + pts + (if id == "hp" then 0 else gear.stat)
	end
	return { main = stats[pair[1]], sub = stats[pair[2]], atk = gear.atk, def = gear.def, stats = stats, gearStat = gear.stat }
end
-- 곱하기 전의 스탯 공격력 = (주스탯 x 4 + 부스탯) x 공격력 / 100
function Hero.attackBase(h): number
	local sp = Hero.spec(h)
	return N.statAtk(sp.main, sp.sub, sp.atk)
end
-- 크리티컬의 기댓값(1 + 확률 x (데미지 배수 - 1)) — 전투력에 넣는다
local function critExp(h): number
	local chance, mul = Passives.crit(h, false)
	return 1 + chance / 100 * (mul - 1)
end
-- 전투력 = 버프를 뺀 스탯 공격력 x 크리티컬의 기댓값 — 한 숫자로 견주는 힘(명예의 전당 · 「장착하면 전투력 +n」). 영혼 · 피의 계약처럼 싸우는 동안 변하는 것은 넣지 않는다
--  sp = 이미 셈한 Hero.spec(내 상태를 보낼 때 한 번만 셈한다)
function Hero.power(h, sp: any?): number
	local s = sp or Hero.spec(h)
	return math.floor(N.statAtk(s.main, s.sub, s.atk) * (1 + Passives.atkPct(h)) * (1 + Passives.sumOf(h, "final")) * critExp(h) + 0.5)
end
-- 피해의 셈이 쓰는 값(= 곱하기 전의 스탯 공격력). 그 위에 영혼(Kit.attack) · 버프(Buffs.dmg) · 패시브(Passives.atk)를 곱한다
--  관리자의 시험용 피해 배율(h.dmgBoost — 저장하지 않는다)은 여기에만 곱한다: 보이는 전투력과 순위(Hero.power)는 그대로다
function Hero.powerRaw(h): number
	return Hero.attackBase(h) * (h.dmgBoost or 1)
end
-- 아이템 상세의 「장착하면 전투력 +n」을 셈하는 재료(화면에 보낸다 — shared/lune/ui/itemInfo.luau): 주스탯 · 부스탯 · 공격력 · k(전투력 = statAtk x k)
function Hero.specView(h, spec: any?)
	local sp = spec or Hero.spec(h)
	return { main = sp.main, sub = sp.sub, atk = sp.atk, k = (1 + Passives.atkPct(h)) * (1 + Passives.sumOf(h, "final")) * critExp(h) }
end

-- 끼고 있는 방어구가 줄여 주는 피해 %(그 레벨의 몬스터에게 맞을 때)
function Hero.cut(h, mobLv: number): number
	return Items.cut(Bag.worn(h), mobLv)
end

-- 체력 상한을 다시 셈한다(레벨 · 체력에 찍은 점수)
-- 최대 체력: 직업 · 레벨 · 찍은 체력에 패시브(액시온의 묵직한 몸)를 곱한다
local function maxHpOf(h): number
	return math.floor(N.hpOf(h.class, h.level, h.stats.hp) * Kit.maxHp(h) + 0.5)
end
Hero.maxHpOf = maxHpOf

function Hero.recalc(h)
	h.maxHp = maxHpOf(h)
	h.hp = math.min(h.hp, h.maxHp)
end

-- 새 캐릭터(Lv.1)
function Hero.new(id: any, class: string)
	assert(CLASSES.classes[class], "없는 직업 " .. tostring(class))
	local h = {
		id = id,
		class = class,
		level = 1,
		job = 1, -- 차수(1~4). 전직 퀘스트를 돌려주면 오른다(Hero.advance)
		xp = 0,
		ap = 0, -- 아직 찍지 않은 능력치 점수
		stats = { str = 0, dex = 0, int = 0, luk = 0, hp = 0 }, -- 찍은 점수(처음 값 4는 빼고)
		sp = 0, -- 아직 쓰지 않은 스킬 포인트
		skills = grants(class), -- [스킬 id] = 레벨
		auto = false, -- true면 레벨업 때 능력치 · 스킬을 저절로 찍는다. 기본은 직접 찍는다(사용자 결정) — 창의 「자동으로 찍기」 · 「추천대로 찍기」는 한 번씩 누르는 단추다
		keys = {}, -- 바꾼 키 { [하는 일] = 키 이름 } — 기본과 다른 것만(클라이언트가 보낸 것을 꼴만 보고 담아 둔다)
		slots = Quick.start(CLASSES.classes[class].skills), -- 퀵슬롯: 칸마다 스킬 · 소비 아이템의 이름표 · false(빈 칸) — shared/lune/ui/quick.luau
		-- 스마트폰의 단추 배치: 같은 열두 칸이지만 PC의 것과 따로 둔다 — PC에서는 손에 익은 키(E · D …)에, 폰에서는 큰 단추에 놓고 싶은 것이 서로 다르다(2026-10-08).
		--  한쪽에서 바꿔도 다른 쪽은 그대로다. 처음 차림은 같다(물약 · 사냥기 · 보스기 · 이동기)
		tslots = Quick.touchStart(CLASSES.classes[class].skills), -- 스마트폰의 단추 배치: 단추가 없는 칸 1의 물약은 칸 5로(ui/quick.luau의 touchFix)
		money = 0,
		forged = false, -- 강화를 해 본 적이 있는가(첫 강화는 달가루 없이 반드시 붙는다 — sim/bag.luau의 Bag.enhance)
		resets = 0, -- 공짜로 스킬을 되돌릴 수 있는 횟수(전직할 때마다 한 번 — 쌓이지 않는다. Hero.freeReset)
		last = nil :: string?, -- 마지막으로 있던 장면(다시 들어오면 거기서 시작한다 — 2026-10-16 밤, 사용자: "게임을 시작하면 항상 초승달마을에서 시작합니다". world.luau의 resumeScene)
		home = nil :: string?, -- 마지막으로 들른 마을 · 작은 마을(쓰러졌을 때 돌아가는 곳 — 없으면 시작 마을. 어느 장면이 마을인가는 scenes.generated의 homes · 서버가 본다)
		hp = 0,
		maxHp = 0,
		alive = true,
		x = 0,
		y = 0,
		dir = 1,
		invuln = 0, -- 맞은 뒤 무적이 남은 시간(초)
		weak = 0, -- 쓰러진 뒤 벌칙이 남은 시간(초)
		expLeft = 0, -- 경험치 쿠폰(유료)이 남은 시간(초) — 게임 안에 있는 동안만 준다(Hero.tick)
		potionWait = 0,
		revive = 0, -- 쓰러진 뒤 일어나기까지 남은 시간(초)
	}
	Kit.init(h) -- 사출기 · 장치의 그때그때의 상태(h.kit)
	Buffs.init(h) -- 걸린 버프 · 다시 쓰기(h.buffs · h.cds — 저장하지 않는다)
	Passives.init(h) -- 패시브의 그때그때의 상태(h.pass — 저장하지 않는다)
	Bag.init(h) -- 처음 받는 차림(무기와 방어구 네 부위)을 입고 있다
	Bag.give(h, Items.potionFor(1).id, RULES.startPotions) -- 처음 받는 물약(가방의 소비 탭 첫 칸)
	h.quests = {} -- 퀘스트의 상태(sim/quests.luau의 book)
	h.daily = {} -- 일일 의뢰의 상태(sim/daily.luau — 지역마다 그날의 의뢰들)
	h.rift = Rift.new() -- 수정 틈 토벌의 하루 보상 횟수(sim/rift.luau — 2026-10-16)
	h.bond = Bond.new() -- 2편의 만나면 열림 · 모험의 서 · 달조각 · 숨은 이야기(sim/bond.luau — 2026-10-16)
	h.tut = Tutorial.new() -- 튜토리얼 「달빛 꿈」(sim/tutorial.luau): 새 캐릭터는 꿈에서 시작한다(2026-10-14). 되살린 · 자란 캐릭터는 마친 것으로 고쳐 둔다
	h.cine = {} -- 본 퀘스트 연출(장면) { [id] = true } — 한 캐릭터에 한 번만 튼다(2026-10-15 — shared/lune/cine.luau)
	h.inCine = false -- 장면이 도는 중(맞지 않는다 — 저장하지 않는다. 서버가 90초 뒤에 저절로 푼다)
	h.played = 0 -- 이 캐릭터로 논 시간(초 · 저장한다 — 서버가 센다. 로블록스 분석의 LevelUp 값 · 2026-10-15)
	Quests.start(h.quests, h.level) -- (저절로 받는 퀘스트는 이제 없다 — 첫 퀘스트도 사제에게 말을 걸어 받는다)
	h.maxHp = maxHpOf(h)
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
--  게임에 들어와 있는 스킬만 · 열린 차수의 스킬만 · 그 차수의 포인트로 · 먼저 배워야 하는 스킬(needs — 사출기 강화 → 사출기)을 1이라도 찍었을 때
--  (먼저 배워야 하는 스킬이 게임에 아직 없으면 그 조건은 보지 않는다 — 만월은 깊은 호흡이 들어오기 전에도 배운다)
function Hero.skillUp(h, id: string): boolean
	local e = ALL[h.class][id]
	if not e or not READY[id] then
		return false
	end
	local def = e.def
	if e.job > h.job or Hero.spLeft(h, e.job) < 1 or Hero.skillLevel(h, id) >= def.max then
		return false
	end
	if def.needs and READY[def.needs] and Hero.skillLevel(h, def.needs) < 1 then
		return false
	end
	h.skills[id] = Hero.skillLevel(h, id) + 1
	h.sp -= 1
	if Kit.skill(id) then
		Hero.recalc(h) -- 패시브가 최대 체력을 바꾼다(묵직한 몸)
	end
	return true
end

-- 남은 스킬 포인트를 추천 순서로 모두 쓴다(「추천대로 찍기」): 사냥기 → 보스기 → 핵심 장치 → 버프 → 나머지
--  차수마다 그 차수의 포인트를 쓴다. 먼저 배워야 하는 스킬 때문에 건너뛴 것은 한 바퀴 더 돌아 찍는다
local PRIORITY = { mob = 1, boss = 2, core = 3, buff = 4 }
function Hero.autoSkill(h): number
	local spent = 0
	for _, t in CLASSES.classes[h.class].tiers do
		if t.job > h.job then
			continue
		end
		local list = table.clone(t.skills)
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
		for _ = 1, 2 do
			for _, s in list do
				while Hero.skillUp(h, s.id) do
					spent += 1
				end
			end
		end
	end
	return spent
end

-- 새 차수가 열렸으면 그 차수의 처음부터 주는 기술(사냥기 · 보스기)을 레벨 1로 준다
function Hero.grantJob(h)
	for id in grants(h.class, h.job) do
		if (h.skills[id] or 0) < 1 then
			h.skills[id] = 1
		end
	end
end

-- 전직 퀘스트가 없는 차수는 레벨만 되면 오른다(앞 차수를 건너뛰지는 않는다). 올랐으면 true
local function autoJobs(h): boolean
	local rose = false
	while true do
		local nextJob = CLASSES.jobs[h.job + 1]
		if not nextJob or h.level < nextJob.lv or Quests.jobQuest(nextJob.job) then
			break
		end
		h.job = nextJob.job
		rose = true
	end
	return rose
end

-- 새 차수의 사냥기 · 보스기를 앞 차수의 것이 놓여 있던 칸에 넣는다(설계 basics.js의 JOBFLOW: "사냥기와 보스기가 윗차수의 것으로 바뀌어 스킬 칸에 들어온다")
local function slotJob(h, job: number)
	for _, t in CLASSES.classes[h.class].tiers do
		if t.job == job then
			for _, s in t.skills do
				if s.replaces and (h.skills[s.id] or 0) > 0 then
					for _, slots in { h.slots, h.tslots } do
						local i = Quick.find(slots, s.replaces)
						if i and not Quick.find(slots, s.id) then
							slots[i] = s.id
						end
					end
				end
			end
		end
	end
end

-- 그 레벨이 닿을 수 있는 차수까지 전직한 것으로 친다 — 전직 퀘스트도 끝낸 것으로 적는다(확인용 캐릭터 LuneGuest = "직업:레벨" · 자동 검사가 쓴다. 진짜 캐릭터는 퀘스트로만 오른다)
function Hero.advanceAll(h)
	while h.job < Hero.jobAt(h.level) and Hero.advance(h, h.job + 1) do
	end
	Quests.jobsDone(h.quests, h.job)
end

-- 전직한다: 바로 다음 차수로, 그 차수의 레벨이 됐을 때만. 했으면 true
function Hero.advance(h, job: any): boolean
	local j = if typeof(job) == "number" then CLASSES.jobs[job] else nil
	if not j or job ~= h.job + 1 or h.level < j.lv then
		return false
	end
	local from = h.job
	h.job = job
	h.resets = 1 -- 전직하면 스킬 포인트 초기화 한 번이 공짜(설계 basics.js의 SPRULE: "전직할 때마다 한 번은 공짜로 되돌릴 수 있다" — 안 쓰고 다음 전직을 해도 한 번이다)
	autoJobs(h)
	Hero.grantJob(h)
	for at = from + 1, h.job do
		slotJob(h, at)
	end
	if h.auto then
		Hero.autoSkill(h)
	end
	return true
end

-- ---------- 관리자(어드민)의 시험용 — 서버의 관리자 명령(server/lune/modules/world.luau의 onAdmin)만 부른다 ----------
-- 레벨을 그 값으로 맞춘다(올리기도 내리기도): 능력치 · 스킬을 처음으로 되돌리고 그 레벨까지의 점수를 새로 준다(찍지 않은 채로). 가방 · 장비 · 달돈 · 퀘스트 · 키는 그대로.
--  차수: job을 주면 그 차수로(그 레벨이 닿을 수 있는 데까지), 안 주면 지금의 차수를 지킨다(레벨이 모자라면 낮아진다)
function Hero.setLevel(h, level: number, job: number?)
	level = math.clamp(math.floor(level), 1, N.MAX_LEVEL)
	local want = math.clamp(math.floor(job or h.job), 1, Hero.jobAt(level))
	h.level, h.xp = level, 0
	h.stats = { str = 0, dex = 0, int = 0, luk = 0, hp = 0 }
	h.ap = N.apAt(level)
	h.job = 1
	h.skills = grants(h.class)
	h.sp = spEarned(level, h.class)
	while h.job < want and Hero.advance(h, h.job + 1) do
	end
	Quests.jobsDone(h.quests, h.job)
	-- 지금의 차수보다 위의 전직 퀘스트는 받기 전으로 되돌린다(차수를 내렸을 때 — 그 레벨이 되면 다시 「달이 부른다」로 받는다)
	for j = h.job + 1, #CLASSES.jobs do
		local def = Quests.jobQuest(j)
		if def then
			h.quests[def.id] = nil
		end
	end
	Quests.start(h.quests, h.level)
	-- 칸에 놓인 것 가운데 이제 배우지 않은 스킬은 뺀다
	for _, slots in { h.slots, h.tslots } do
		for i, id in slots do
			if typeof(id) == "string" and not Quick.item(id) and (h.skills[id] or 0) < 1 then
				slots[i] = false
			end
		end
	end
	h.maxHp = maxHpOf(h)
	h.hp = h.maxHp
end

-- 열린 차수의 스킬(게임에 들어와 있는 것)을 모두 마스터한다 · 스킬을 처음(차수가 주는 레벨 1)으로 되돌린다 · 찍은 능력치를 모두 되돌려 받는다
function Hero.maxSkills(h)
	for _, tier in CLASSES.classes[h.class].tiers do
		if tier.job <= h.job then
			for _, sk in tier.skills do
				if Hero.ready(sk.id) then
					h.skills[sk.id] = sk.max
				end
			end
		end
	end
	h.maxHp = maxHpOf(h)
end
-- 스킬 초기화(공짜 · 몇 번이든 — 2026-10-21 사용자: "스텟, 스킬 초기화 완전무료로 풀겠습니다"): 찍은 스킬을 모두 되돌려(처음부터 주는 레벨 1만 남는다) 포인트를 다시 쓴다.
--  찍은 것이 없으면(처음부터 주는 것뿐) false. 전에는 전직할 때마다 한 번(h.resets) — 그 수는 저장의 꼴을 지키려고 남겨 두었고 쓰지 않는다
function Hero.freeReset(h): boolean
	local base = grants(h.class, h.job)
	local spent = false
	for id, lv in h.skills do
		if lv ~= (base[id] or 0) then
			spent = true
		end
	end
	if not spent then
		return false
	end
	Hero.resetSkills(h)
	return true
end

-- 찍은 능력치가 있는가(능력치 초기화 — 공짜 · 몇 번이든, 2026-10-21)
function Hero.statsSpent(h): boolean
	for _, n in h.stats do
		if n > 0 then
			return true
		end
	end
	return false
end

function Hero.resetSkills(h)
	h.skills = grants(h.class, h.job)
	h.sp = spEarned(h.level, h.class) -- 찍은 것이 없다: 받은 포인트가 그대로 남는다
	for _, slots in { h.slots, h.tslots } do
		for i, id in slots do
			if typeof(id) == "string" and not Quick.item(id) and (h.skills[id] or 0) < 1 then
				slots[i] = false
			end
		end
	end
	h.maxHp = maxHpOf(h)
	h.hp = math.min(h.hp, h.maxHp)
end
function Hero.resetStats(h)
	for stat, n in h.stats do
		h.ap += n
		h.stats[stat] = 0
	end
	Hero.recalc(h)
end

-- ---------- 경험치 ----------
-- 경험치를 얻는다. 오른 레벨 수를 돌려준다.
function Hero.gainXp(h, amount: number): number
	local ups = 0
	if h.level >= N.MAX_LEVEL then
		return 0
	end
	h.xp += amount * (h.xpBoost or 1) -- 관리자의 시험용 경험치 배율(저장하지 않는다 — 서버의 관리자 명령만 정한다)
	while h.level < N.MAX_LEVEL and h.xp >= N.xpNeed(h.level) do
		h.xp -= N.xpNeed(h.level)
		h.level += 1
		h.ap += STATS.perLevel
		h.sp += Hero.spGain(h.class, h.level) -- 그 차수의 스킬을 다 찍을 만큼 받았으면 더 받지 않는다
		ups += 1
	end
	if h.level >= N.MAX_LEVEL then
		h.xp = 0
	end
	if ups > 0 then
		local from = h.job
		autoJobs(h)
		Hero.grantJob(h)
		for at = from + 1, h.job do
			slotJob(h, at)
		end
		Quests.start(h.quests, h.level) -- (저절로 받는 퀘스트는 이제 없다 — 전직 퀘스트는 레벨이 되면 사제에게 가서 받는다. 화면이 "달이 부른다"로 알린다)
		if h.auto then
			Hero.autoStat(h)
			Hero.autoSkill(h)
		end
		h.maxHp = maxHpOf(h)
		if h.alive ~= false then
			h.hp = h.maxHp -- 레벨이 오르면 체력이 다 찬다(쓰러져 있으면 그대로 — 파티원이 잡은 몫으로 오를 때 · 2026-10-18 검토)
		end
	end
	return ups
end

-- 몬스터를 잡았을 때의 경험치(레벨 차이 · 쓰러진 뒤의 벌칙을 넣은 값)
function Hero.killXp(h, mobLevel: number, mobHpMul: number): number
	local xp = N.mobXp(mobLevel) * mobHpMul * N.xpRate(h.level, mobLevel) / 100
	if h.weak > 0 then
		xp *= 1 - N.data.BODY.death.cut / 100
	end
	xp *= Cash.expMul(h) -- 경험치 쿠폰(사냥 경험치만 — 2026-10-20 사용자 「경험치 쿠폰 판매해도 됩니다」)
	return math.max(1, math.floor(xp + 0.5))
end

-- ---------- 맞기 · 물약 · 쓰러짐 ----------
-- 맞는다. 실제로 들어간 피해를 돌려준다(무적 중이거나 쓰러져 있으면 0).
function Hero.hurt(h, amount: number): number
	if not h.alive or h.invuln > 0 or h.god or h.inCine then -- god = 관리자의 시험용 무적(저장하지 않는다) · inCine = 퀘스트 연출이 도는 중
		return 0
	end
	local dmg = math.max(1, math.floor(amount + 0.5))
	h.hp = math.max(0, h.hp - dmg)
	h.invuln = RULES.invuln
	if h.hp <= 0 then
		h.alive = false
		h.revive = RULES.reviveWait -- 이 시간이 지나야 마을로 돌아갈 수 있다(쓰러지는 동작 · 비석이 서는 동안)
		h.weakWas = h.weak -- 소생으로 그 자리에서 일어나면 이번 벌칙은 없던 일이 된다
		-- 벌칙은 숫자 뼈대대로 정해 둔 레벨부터(그 전에는 벌칙이 없다)
		if h.level >= N.data.BODY.death.free then
			h.weak = N.deathMinutes(h.level) * 60
		end
	end
	return dmg
end

-- 가방에 든 물약의 수(모든 단의 합)
function Hero.potions(h): number
	local n = 0
	for _, g in Items.data.GOODS do
		if g.kind == "potion" then
			n += Bag.count(h, g.id)
		end
	end
	return n
end

-- 지금 마실 수 있는 가장 좋은 물약(가방에 있고 내 레벨에 쓸 수 있는 것 — 없으면 nil)
function Hero.bestPotion(h)
	local best = nil
	for _, g in Items.data.GOODS do
		if g.kind == "potion" and g.lv <= h.level and Bag.count(h, g.id) > 0 and (not best or g.heal > best.heal) then
			best = g
		end
	end
	return best
end

-- 소비 아이템을 쓴다(지금은 물약뿐): id = 그 아이템의 이름표(안 주면 지금 마실 수 있는 가장 좋은 물약). 회복한 양을 돌려준다(못 썼으면 nil과 까닭).
function Hero.drink(h, id: any): (number?, string?)
	local def = if id == nil then Hero.bestPotion(h) else Items.goods(id)
	if not def or def.kind ~= "potion" or Bag.count(h, def.id) <= 0 then
		return nil, "가진 물약이 없다"
	elseif h.level < def.lv then
		return nil, ("Lv.%d부터 쓸 수 있다"):format(def.lv)
	elseif not h.alive or h.potionWait > 0 or h.hp >= h.maxHp then
		return nil -- 쓰러졌다 · 아직 다시 쓸 수 없다 · 체력이 가득하다(까닭을 띄우지 않는다 — 키를 누르고 있을 때마다 뜨면 시끄럽다)
	end
	local heal = math.floor(h.maxHp * def.heal / 100 + 0.5)
	local before = h.hp
	h.hp = math.min(h.maxHp, h.hp + heal)
	Bag.take(h, def.id, 1)
	h.potionWait = N.data.BODY.cooldown.field
	return h.hp - before
end

-- 시간이 흐른다. 쓰러져 있다가 일어날 때가 되면 true를 돌려준다(일으키는 것은 부른 쪽이 한다).
function Hero.tick(h, dt: number): boolean
	h.invuln = math.max(0, h.invuln - dt)
	h.weak = math.max(0, h.weak - dt)
	h.expLeft = math.max(0, (h.expLeft or 0) - dt)
	h.potionWait = math.max(0, h.potionWait - dt)
	-- 쓰러져 있는 동안: 저절로 일어나지 않는다 — 그 자리에 비석이 서고, 마을로 돌아갈지는 그 사람이 정한다(사용자 2026-10-08:
	--  "죽으면 비석 세우고, 모달띄워서 마을로 갈거냐고 물어보는 딜레이를 넣읍시다"). 그 사이에 파티원이 소생으로 일으켜 줄 수 있다
	if not h.alive then
		h.revive = math.max(0, h.revive - dt)
	end
	return false
end

-- 쓰러진 사람이 마을로 돌아갈 수 있는가(쓰러지고 조금 지난 뒤부터)
function Hero.canReturn(h): boolean
	return not h.alive and h.revive <= 0
end

-- 맵에 들어섰다: 잠깐(RULES.arrive초) 피해를 받지 않는다 — 들어서자마자 맞지 않게(문 곁에도 몬스터가 있다. 공방 combat.js의 arrive)
-- 방(맵)마다 시계가 따로다(방의 time은 0에서 시작해 사람이 있을 때만 흐르고, 토벌 방은 들 때마다 새로 짓는다).
--  캐릭터에 적힌 방의 시각들을 새 방의 시계로 옮긴다 — delta = 새 방의 시각 − 옛 방의 시각(서버 world.luau의 place가 부른다 · 2026-10-18 검토:
--  옛 방의 시계가 앞서 있으면 리퍼의 도깨비불 · 무니의 수정 조각 · 리븐의 독이 새 방의 시계가 따라잡을 때까지 멈췄고, 거꾸로면 살라맨더의 연속이 끝나지 않았다)
local CLOCK_PASS = { "streakAt", "pressAt", "surge", "rekindle", "venom" }
function Hero.shiftClock(h, delta: number)
	if delta == 0 or delta ~= delta then
		return
	end
	if h.kit and typeof(h.kit.at) == "number" then
		h.kit.at += delta
	end
	if typeof(h.actUntil) == "number" then
		h.actUntil += delta
	end
	local p = h.pass
	if p then
		for _, k in CLOCK_PASS do
			if typeof(p[k]) == "number" then
				p[k] += delta
			end
		end
	end
end

function Hero.arrive(h)
	h.invuln = math.max(h.invuln, RULES.arrive)
end

-- 마을에서 일어난다(체력이 가득)
function Hero.revive(h)
	h.alive = true
	h.hp = h.maxHp
	h.invuln = 2
	h.revive = 0
	h.weakWas = nil
end

-- 소생을 받아 그 자리에서 일어난다: 최대 체력의 share만큼으로. 쓰러지며 받은 벌칙(약해짐)은 없던 일이 된다
function Hero.raise(h, share: number)
	h.alive = true
	h.hp = math.clamp(math.floor(h.maxHp * share + 0.5), 1, h.maxHp)
	h.invuln = 2
	h.revive = 0
	if h.weakWas ~= nil then
		h.weak = h.weakWas
	end
	h.weakWas = nil
end

-- ---------- 퀘스트 ----------
-- 모으는 일의 숫자를 가방에 맞춘다(가방에 든 수가 곧 숫자다). 바뀌었으면 true
function Hero.syncQuests(h): boolean
	return Quests.sync(h.quests, function(item)
		return Bag.count(h, item)
	end)
end

-- 퀘스트를 돌려주고 보상을 받는다. 돌려주는 것: 보상, 오른 레벨 수(안 됐으면 nil과 까닭)
--  모은 물건은 가방에서 빠진다. 보상의 물약(내 레벨에 쓸 수 있는 가장 좋은 물약)이 들어갈 칸이 없으면 돌려주지 못한다
Hero.SCROLL = "scroll_return" -- 귀환 주문서(퀘스트의 보상으로 주는 것)
function Hero.questDone(h, id: any)
	local def = Quests.def(id)
	local potion = Items.potionFor(h.level)
	if def and def.reward.potions > 0 and Quests.isReady(h.quests, id) and Bag.room(h, potion.id) < def.reward.potions then
		return nil, "가방의 소비 칸이 모자란다"
	end
	-- 보상의 귀환 주문서(첫머리의 퀘스트 — 사용자 2026-10-13: "완전 초반부 퀘스트에서 마을귀환주문서를 뿌려야합니다")가 들어갈 칸이 없으면 돌려주지 못한다
	if def and (def.reward.scrolls or 0) > 0 and Quests.isReady(h.quests, id) and Bag.room(h, Hero.SCROLL) < def.reward.scrolls then
		return nil, "가방의 소비 칸이 모자란다"
	end
	-- 전직 퀘스트는 바로 다음 차수일 때만 돌려준다(2026-10-18 검토 — 끝냈는데 전직이 되지 않는 일이 없게)
	if def and def.reward.job and Quests.isReady(h.quests, id) and def.reward.job ~= h.job + 1 then
		return nil, "앞의 전직을 먼저 마쳐야 한다"
	end
	-- 보상의 장비(전직할 때 받는 무기)가 들어갈 칸이 없으면 돌려주지 못한다
	if def and def.reward.gear and Quests.isReady(h.quests, id) and Bag.free(h) <= 0 then
		return nil, Bag.FULL
	end
	local reward, why = Quests.complete(h.quests, id)
	if not reward then
		return nil, why
	end
	for _, t in Quests.takes(id) do
		Bag.take(h, t.item, math.min(t.n, Bag.count(h, t.item)))
	end
	h.money += reward.money
	if reward.potions > 0 then
		Bag.give(h, potion.id, reward.potions)
	end
	if (reward.scrolls or 0) > 0 then
		Bag.give(h, Hero.SCROLL, reward.scrolls)
	end
	if reward.gear then
		Bag.add(h, Items.make(reward.gear.slot, reward.gear.stage, Items.NORMAL, h.class)) -- 보상의 장비는 내 직업의 것 · 성능은 보통
	end
	if reward.open == "tome" then
		h.bond.open = true -- 모험의 서가 열린다(「항구의 첫날」)
	end
	Hero.syncQuests(h) -- 같은 물건을 모으는 다른 퀘스트의 숫자
	if reward.job then
		Hero.advance(h, reward.job) -- 전직 퀘스트: 다음 차수가 열린다
	end
	local ups = Hero.gainXp(h, reward.xp)
	return reward, ups
end

-- 퀘스트를 그만둔다. 모으던 물건도 사라진다(다른 퀘스트가 같은 것을 모으고 있으면 남는다) — 다시 받으면 처음부터다
function Hero.questDrop(h, id: any): (boolean?, string?)
	local ok, why = Quests.drop(h.quests, id)
	if not ok then
		return nil, why
	end
	for _, t in Quests.takes(id) do
		local have = Bag.count(h, t.item)
		if have > 0 and not Quests.wants(h.quests, t.item) then
			Bag.take(h, t.item, have)
		end
	end
	Hero.syncQuests(h)
	return true
end

-- ---------- 키 설정 ----------
-- 바꾼 키의 표를 받아 둔다. 꼴이 맞는 것만 담는다(하는 일 이름 · 키 이름은 글자와 숫자, 마흔여덟 개까지). 담았으면 true.
-- lenient = 저장된 것을 읽을 때: 맞지 않는 짝만 버리고 나머지는 지킨다(2026-10-18 검토 — 전에는 짝 하나 때문에 키 설정 전체가 처음으로 돌아갔다)
local function cleanKeys(map: any, lenient: boolean?)
	if typeof(map) ~= "table" then
		return nil
	end
	local out, n = {}, 0
	for action, key in map do
		if typeof(action) ~= "string" or typeof(key) ~= "string" or #action > 40 or #key > 24 or not string.match(action, "^[%w:_]+$") or not string.match(key, "^%w+$") then
			if lenient then
				continue
			end
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
	if RIDEIDS[id] then
		return true -- 펫 · 탈것(2026-10-21 — 칸의 키로 꺼내고 타기. 가진 것인지는 쓸 때 서버가 본다: Cash.setPet · setMount)
	end
	local goods = Items.goods(id)
	if goods then
		return goods.tab == "use" -- 소비 아이템은 가진 것이 없어도 놓아 둘 수 있다(다 써도 칸에 남는다 — 숫자가 0)
	end
	if Kit.isToggle(h, id) then
		return true -- 배운 온오프 사출기(칸의 키로 켜고 끈다)
	end
	if Buffs.learned(h, id) then
		return true -- 배운 버프(칸의 키로 건다)
	end
	local placed = COMBAT.placed[id]
	if placed and placed.who == h.class and (h.skills[id] or 0) > 0 then
		return true -- 배운 설치 · 소환
	end
	local cast = COMBAT.cast[id]
	if cast and cast.who == h.class and (h.skills[id] or 0) > 0 then
		return true -- 배운 2~4차의 쓰는 스킬
	end
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
		h.tslots = Quick.touchFix(slots) -- 단추가 없는 칸(칸 1)에 놓인 것은 단추가 있는 빈 칸으로 — 전에 저장해 둔 배치도 들어올 때 이 길로 옮겨진다
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
		job = h.job,
		xp = h.xp,
		ap = h.ap,
		stats = table.clone(h.stats),
		sp = h.sp,
		skills = table.clone(h.skills),
		auto = h.auto,
		keys = table.clone(h.keys),
		slots = table.clone(h.slots),
		tslots = table.clone(h.tslots),
		kitOn = h.kit.on, -- 온오프 사출기를 켜 두었는가(다시 들어와도 그대로다)
		money = h.money,
		forged = h.forged == true,
		home = h.home or false,
		last = (if h.alive == false then h.home else h.last) or false, -- 쓰러진 채 나가면 다시 들어올 때 마을에서(그 자리에서 가득 찬 채로 살아나지 않게 — 2026-10-18 검토)
		resets = h.resets or 0,
		weak = math.floor(h.weak),
		expLeft = math.floor(h.expLeft or 0),
		bag = Bag.pack(h),
		quests = Quests.pack(h.quests),
		daily = Daily.pack(h.daily),
		bond = Bond.pack(h.bond),
		rift = Rift.pack(h.rift),
		tut = Tutorial.pack(h.tut),
		cine = Hero.cineList(h),
		played = math.floor(h.played or 0),
	}
end

-- 본 장면의 목록(저장 · 화면에 보내는 꼴 — 글의 배열)
function Hero.cineList(h): { string }
	local list = {}
	for id in h.cine do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

local function whole(v: any, min: number, max: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

-- 저장된 것에서 캐릭터를 되살린다. 꼴이 이상하면 nil(새로 골라야 한다).
--  점수가 받은 것보다 많이 찍혀 있으면(식이 바뀌었거나 자료가 깨졌을 때) 찍은 것을 모두 되돌려 준다 — 레벨과 돈은 지킨다.
function Hero.unpack(id: any, data: any)
	if typeof(data) ~= "table" or not CLASSES.classes[data.class] or not whole(data.level, 1, 1e6) then
		return nil
	end
	local h = Hero.new(id, data.class)
	h.level = math.min(data.level, N.MAX_LEVEL) -- (최고 레벨이 줄었으면 그 레벨로 — 캐릭터를 못 쓰게 되지 않게 · 2026-10-18 검토)
	-- 차수: 저장된 것(그 레벨에 닿을 수 있는 데까지). 전직 퀘스트가 생기기 전에 저장된 캐릭터(2026-10-10 이전)는 레벨만 되면 전직했으므로 그 레벨의 차수 그대로다
	h.job = if whole(data.job, 1, #CLASSES.jobs) then math.min(data.job, Hero.jobAt(h.level)) else Hero.jobAt(h.level)
	h.xp = if typeof(data.xp) == "number" and data.xp >= 0 and data.xp < N.xpNeed(h.level) then math.floor(data.xp) else 0
	h.money = if whole(data.money, 0, 9e15) then data.money else 0
	h.weak = if whole(data.weak, 0, 3600) then data.weak else 0
	h.expLeft = if whole(data.expLeft, 0, Cash.RULES.exp.cap) then data.expLeft else 0 -- 경험치 쿠폰 — 생기기 전의 저장 = 0
	-- 공짜 초기화: 이것이 생기기 전에 전직한 캐릭터(2026-10-11 이전 — 저장에 없다)는 한 번 받는다
	h.resets = if whole(data.resets, 0, 1) then data.resets elseif data.resets == nil and h.job >= 2 then 1 else 0
	h.last = if typeof(data.last) == "string" and #data.last <= 40 then data.last else nil -- 없는 장면이면 서버가 마지막 마을 · 시작 마을로(world.luau의 resumeScene)
	h.home = if typeof(data.home) == "string" then data.home else nil -- 없는 장면 · 마을이 아닌 장면이면 서버가 시작 마을로 돌려보낸다(world.luau의 onReturn). 옛 저장의 towns(걷어낸 빠른 이동)는 읽지 않는다
	h.forged = data.forged == true -- 이것이 생기기 전에 저장된 캐릭터(2026-10-11 이전)는 한 번 더 받는다(첫 강화가 공짜로 반드시 붙는다)
	h.auto = data.auto == true
	h.keys = cleanKeys(data.keys, true) or {}
	local oldBag = Bag.unpack(h, data.bag) -- 장비가 생기기 전에 저장된 캐릭터는 처음 차림을 받는다
	h.quests = Quests.unpack(data.quests)
	h.daily = Daily.unpack(data.daily) -- 일일 의뢰가 생기기 전의 저장 = 빈 것(게시판에 가면 오늘의 의뢰를 받는다)
	h.rift = Rift.unpack(data.rift) -- 토벌의 하루 보상 횟수(그 전의 저장 = 오늘 아직 안 함)
	h.bond = Bond.unpack(data.bond) -- 2편의 만나면 열림 · 모험의 서(2026-10-16 — 그 전의 저장 = 빈 것 · 예전 호감도의 점수는 버린다)
	h.tut = Tutorial.unpack(data.tut) -- 튜토리얼이 생기기 전의 캐릭터(2026-10-14 이전) = 마친 것
	h.cine = {} -- 본 장면(퀘스트 연출이 생기기 전의 저장 = 아무것도 안 봤다 — 장면은 퀘스트를 받고 · 다 하고 · 돌려줄 때 트므로 지난 퀘스트의 장면은 다시 나오지 않는다)
	if typeof(data.cine) == "table" then
		for i, id in data.cine do
			if typeof(id) == "string" and #id <= 40 and typeof(i) == "number" and i <= 400 then
				h.cine[id] = true
			end
		end
	end
	h.played = if whole(data.played, 0, 1e10) then data.played else 0 -- (이것이 생기기 전의 저장 = 0부터 센다)
	Quests.jobsDone(h.quests, h.job) -- 이미 닿은 차수의 전직 퀘스트는 끝낸 것으로(다시 받지 않게)
	autoJobs(h)
	Quests.start(h.quests, h.level) -- 퀘스트가 생기기 전에 저장된 캐릭터도 첫 메인을 받는다
	-- 소비 · 기타 칸이 생기기 전에 저장된 캐릭터(2026-10-08 이전): 숫자로만 갖고 있던 것을 가방의 아이템으로 옮긴다 — 잃는 것이 없게.
	--  물약 = 그때 마시던 물약(내 레벨의 것)으로 그 수만큼 · 퀘스트의 물건 = 하는 중인 퀘스트가 세어 둔 수만큼
	local myPotion = Items.potionFor(h.level).id
	if oldBag then
		Bag.take(h, Items.potionFor(1).id, Bag.count(h, Items.potionFor(1).id)) -- Hero.new가 넣어 둔 처음 물약 대신 저장된 수를 넣는다
		local n = if whole(data.potions, 0, 9999) then data.potions else RULES.startPotions
		if n > 0 then
			Bag.give(h, myPotion, math.min(n, Bag.room(h, myPotion)))
		end
		for id, st in h.quests do
			local def = Quests.def(id)
			if def and not st.done then
				for i, step in def.steps do
					local have = st.c[i] or 0
					if step.type == "gather" and step.item and have > 0 then
						Bag.give(h, step.item, math.min(have, Bag.room(h, step.item)))
					end
				end
			end
		end
	end
	Hero.syncQuests(h) -- 가방에 든 수가 곧 퀘스트의 숫자다

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
	local base = grants(h.class, h.job)
	local spent, good = 0, typeof(data.skills) == "table"
	local skills = table.clone(base)
	if good then
		for sid, lv in data.skills do
			local def = skillDef(h.class, sid)
			if def and whole(lv, 0, 1e6) then
				-- 게임에 아직 없는 스킬에 찍혀 있던 것(그 스킬을 막기 전의 저장)은 포인트로 돌려준다 · 최고 레벨이 줄었으면 그 레벨까지(넘친 것은 포인트로)
				if READY[sid] then
					skills[sid] = math.max(math.min(lv, def.max), base[sid] or 0)
					spent += skills[sid] - (base[sid] or 0)
				end
			end
			-- 없어진 스킬은 그것만 빼고 포인트로 돌려준다(2026-10-18 검토 — 전에는 스킬 하나 때문에 찍은 것을 모두 되돌렸다)
		end
	end
	-- 차수마다: 열리지 않은 차수의 스킬은 없고, 그 차수에 쓴 포인트는 그 차수 동안 받은 것을 넘지 않는다
	if good then
		for _, j in CLASSES.jobs do
			local used = spSpentIn(h.class, h.job, skills, j.job)
			if used > spEarnedIn(h.level, j.job, h.class) or (j.job > h.job and used > 0) then
				good = false
			end
		end
	end
	if good and spent <= spEarned(h.level, h.class) then
		h.skills = skills
		h.sp = spEarned(h.level, h.class) - spent
	else
		h.skills = base
		h.sp = spEarned(h.level, h.class)
	end
	-- 퀵슬롯: 저장된 것이 말이 되면 그대로, 아니면(퀵슬롯이 생기기 전에 저장된 캐릭터 포함) 처음 차림(Hero.new가 놓아 둔 것)
	--  예전 저장의 물약 칸("potion" — 물약이 한 가지였을 때)은 그때 마시던 물약의 칸으로 바꾼다(놓아 둔 자리가 그대로 남는다)
	--  칸 하나가 맞지 않으면(그 스킬의 포인트를 돌려받았다 · 아이템의 이름표가 바뀌었다) 그 칸만 비운다(2026-10-18 검토 — 전에는 배치 전체가 처음 차림으로 돌아갔다)
	local function salvage(list)
		if typeof(list) ~= "table" then
			return list
		end
		local out, seen = table.create(Quick.N, false), {}
		for i = 1, Quick.N do
			local v = list[i]
			if typeof(v) == "string" and #v <= 40 and not seen[v] and Hero.canSlot(h, v) then
				seen[v] = true
				out[i] = v
			end
		end
		return out
	end
	if data.slots ~= nil then
		Hero.setSlots(h, salvage(Quick.renew(data.slots, myPotion)))
	end
	-- 스마트폰의 단추 배치: 저장된 것이 말이 되면 그대로, 없으면(이것이 생기기 전에 저장된 캐릭터) 처음 차림
	if data.tslots ~= nil then
		Hero.setSlots(h, salvage(Quick.renew(data.tslots, myPotion)), true)
	end

	h.kit.on = data.kitOn == true and Kit.level(h, "toggle") > 0
	h.maxHp = maxHpOf(h)
	h.hp = h.maxHp
	return h
end

-- 클라이언트에 보내는 내 상태
-- 장비 창의 능력치 표(2026-10-14 — 사용자: "장비 탭에 … 현재 스텟, 공격력 등 여러 수치가 다 출력되어야하고 크리티컬 확률, 크리티컬 데미지 이런것도 다 나와야합니다").
--  서버가 피해 · 맞는 피해를 셈하는 바로 그 값들이다(지금 걸린 버프 · 패시브 · 리퍼의 영혼까지):
--  (2026-10-14의 꼴 — 아래 2026-10-15 줄이 지금의 것) atk = 100% 한 타의 피해 { 작게, 크게 }(전투력 x 영혼 x 버프 x 패시브 x 피해 숫자의 배율 · 흩어짐 ±spread% — 메이플의 스탯 공격력. 사냥기 · 보스기가 맞는 상대에게는 +targetBonus%, 치명타는 그 위에 곱한다)
--  crit = 치명타 확률(%) · critDmg = 치명타 피해(%) · dmg = 주는 피해(버프 · 영혼 +%) · final = 최종 피해(패시브 +%) · haste = 공격 속도(+%)
--  cut = 받는 피해가 줄어드는 몫(버프 · 패시브 %) · guard = 방어구가 줄여 주는 피해(%, 내 레벨의 몬스터에게) · run · jump = 이동 속도 · 점프력(%)
--  2026-10-15 스펙을 다시 짜며: atk = 스탯 공격력 { 작게, 크게 }(지금 걸린 버프 · 영혼까지 — 흩어짐 ±spread%) · attack = 공격력(무기 x 공격력%) · def = 방어력 ·
--   stats = 힘 · 민첩 · 지능 · 운 · 체력(처음 4 + 찍은 점수 + 장비의 올스탯) · gearStat = 장비의 올스탯 · dmg = 데미지 % · final = 최종 데미지 % ·
--   cut = 받는 피해 감소 %(방어력 · 버프 · 패시브 · 무니의 지키는 마음 — 내 레벨의 몬스터에게 맞을 때. 피하기는 넣지 않는다)
function Hero.sheet(h, spec: any?)
	local sp = spec or Hero.spec(h)
	local attack = sp.atk * (1 + Passives.atkPct(h)) * Kit.attack(h)
	local dmg = Buffs.dmg(h)
	local final = Passives.finalMul(h)
	local base = N.statAtk(sp.main, sp.sub, attack) * dmg * final * (h.dmgBoost or 1) * RULES.dmgScale
	local chance, mul = Passives.crit(h, false)
	local run, jump = Kit.move(h)
	local guard = Items.cut(Bag.worn(h), h.level)
	return {
		atk = { math.floor(base * (1 - RULES.spread / 100) + 0.5), math.floor(base * (1 + RULES.spread / 100) + 0.5) },
		attack = math.floor(attack + 0.5),
		def = sp.def,
		stats = sp.stats,
		gearStat = sp.gearStat,
		crit = chance,
		critDmg = mul * 100,
		dmg = (dmg - 1) * 100,
		final = (final - 1) * 100,
		haste = (Buffs.haste(h) - 1) * 100,
		cut = (1 - (1 - guard / 100) * Buffs.cut(h) * Passives.cut(h, false) * Kit.cut(h, false)) * 100,
		guard = guard,
		run = run * 100,
		jump = jump * 100,
	}
end

function Hero.view(h)
	local sp = Hero.spec(h) -- 스펙은 한 번만 셈한다(전투력 · 상세의 재료 · 능력치 표가 같이 쓴다)
	return {
		cine = Hero.cineList(h), -- 본 퀘스트 연출(화면이 다시 틀지 않게)
		class = h.class,
		level = h.level,
		xp = h.xp,
		need = N.xpNeed(h.level),
		hp = h.hp,
		maxHp = h.maxHp,
		money = h.money,
		potions = Hero.potions(h), -- 가방에 든 물약의 수(모든 단의 합 — 확인용. 화면의 숫자는 가방에서 아이템마다 센다)
		ap = h.ap,
		stats = h.stats,
		sp = h.sp,
		job = h.job, -- 지금의 차수(스킬 창의 탭이 열린다)
		resets = h.resets or 0, -- 공짜로 스킬을 되돌릴 수 있는 횟수(스킬 창의 「초기화」 단추)
		forged = h.forged == true, -- 강화를 해 본 적이 있는가(아니면 강화 창이 「첫 강화」를 알린다)
		sps = { math.max(0, Hero.spLeft(h, 1)), math.max(0, Hero.spLeft(h, 2)), math.max(0, Hero.spLeft(h, 3)), math.max(0, Hero.spLeft(h, 4)) }, -- 차수마다 남은 스킬 포인트
		skills = h.skills,
		power = Hero.power(h, sp),
		spec = Hero.specView(h, sp), -- 아이템 상세의 「장착하면 전투력 +n」을 셈하는 재료(2026-10-15)
		sheet = Hero.sheet(h, sp), -- 장비 창의 능력치 표(위의 Hero.sheet)
		keys = h.keys,
		slots = h.slots,
		tslots = h.tslots,
		kit = Kit.view(h), -- 사출기를 켰는가 · 영혼 · 열기(화면의 버프 자리 · 칸의 켜진 표시)
		run = (Kit.move(h)), -- 걸음의 배수(날랜 몸 · 뜨거운 피) — 화면이 그 빠르기로 걷는다
		jump = select(2, Kit.move(h)), -- 뛰는 힘의 배수
		alive = h.alive,
		weak = math.ceil(h.weak),
		expLeft = math.ceil(h.expLeft or 0), -- 경험치 쿠폰의 남은 시간(오른쪽 위 버프 줄)
	}
end

return Hero
