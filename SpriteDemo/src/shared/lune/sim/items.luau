-- 장비의 셈 — 이름 · 점수 · 떨어지는 것 · 강화 · 분해 · 별 옮기기. 화면도 서버도 모르는 순수한 셈이다.
--  수치는 data/items.generated.luau(공방 js/lune/design/items.js와 numbers.js · basics.js · economy.js에서 내보낸 것). 식은 공방과 같은 것을 다시 짰다 —
--  tools/test/tests/15_lune_items.luau가 공방에서 셈한 값(checks)과 맞춰 본다.
--  장비 하나 = { id(가진 사람 안에서의 번호), slot, stage(장비 단계), q(성능 단 1 낡은 … 5 빼어난), star, who(무기만: 어느 직업의 것),
--                fails(잇달아 떨어진 횟수), broken(부서져 흔적만 남았는가) }
local D = require(script.Parent.Parent.data["items.generated"])
local N = require(script.Parent.Parent.config.numbers)

local POWER = N.data.POWER
local E = D.ENHANCE

local Items = {}
Items.data = D
Items.NORMAL = D.NORMAL

local SLOT = {}
for i, s in D.SLOTS do
	SLOT[s.id] = s
	s.order = i
end
local ARMOR = {}
for _, id in D.ARMOR do
	ARMOR[id] = true
end
local STOCK = {}
for _, s in D.STOCK do
	STOCK[s.id] = s
end

local function round(v: number): number
	return math.floor(v + 0.5)
end

function Items.slot(id: string)
	return SLOT[id]
end

function Items.isArmor(id: string): boolean
	return ARMOR[id] == true
end

function Items.stock(id: string)
	return STOCK[id]
end

-- ---------- 만들기 · 꼴 ----------
function Items.make(slot: string, stage: number, q: number?, who: string?)
	assert(SLOT[slot], "없는 부위 " .. tostring(slot))
	return { slot = slot, stage = stage, q = q or D.NORMAL, star = 0, who = if slot == "weapon" then who else nil, fails = 0, broken = false }
end

-- 저장된 것 · 받은 것의 꼴이 맞는가
function Items.valid(it: any): boolean
	if typeof(it) ~= "table" or not SLOT[it.slot] then
		return false
	end
	local function whole(v, min, max)
		return typeof(v) == "number" and v == math.floor(v) and v >= min and v <= max
	end
	if not whole(it.stage, 1, 200) or not whole(it.q, 1, #D.QUALITY) or not whole(it.star, 0, E.max) then
		return false
	end
	if it.slot == "weapon" and D.KINDS[it.who] == nil then
		return false
	end
	return it.star <= Items.starCap(it.stage)
end

-- 같은 장비인가(부서진 것을 되살릴 때 쓴다): 부위 · 단계 · 무기라면 직업
function Items.same(a, b): boolean
	return a.slot == b.slot and a.stage == b.stage and a.who == b.who
end

-- 낄 수 있는 레벨(사냥 장비는 단계가 곧 레벨이다)
function Items.needLevel(it): number
	return it.need or it.stage
end

-- ---------- 이름 ----------
function Items.material(stage: number): string
	for _, m in D.MATERIAL do
		if stage < m.below then
			return m.name
		end
	end
	return D.MATERIAL[#D.MATERIAL].name
end

function Items.baseName(it): string
	if it.slot == "weapon" then
		return D.KINDS[it.who]
	end
	return Items.material(it.stage) .. " " .. SLOT[it.slot].name
end

function Items.name(it): string
	local head = if it.q == D.NORMAL then "" else D.QUALITY[it.q].name .. " "
	return ("%sLv.%d %s"):format(head, it.stage, Items.baseName(it))
end

-- ---------- 점수 · 전투력 · 방어 ----------
function Items.score(it): number
	if it.broken then
		return 0
	end
	return SLOT[it.slot].w * POWER.grow ^ it.stage * D.STAR ^ it.star * (1 + D.QUALITY[it.q].bonus / 100)
end

-- list = 끼고 있는 장비들(차례는 상관없다)
function Items.gearScore(list): number
	local sum = 0
	for _, it in list do
		sum += Items.score(it)
	end
	return sum / D.WSUM
end

function Items.power(level: number, eff: number, list): number
	return round(POWER.base * (POWER.levelShare * eff * POWER.grow ^ level + POWER.itemShare * Items.gearScore(list)))
end

-- 방어구가 줄여 주는 피해 %: 부위마다 4분의 1씩(빈 부위 · 부서진 것은 0)
function Items.cut(list, mobLv: number): number
	local sum = 0
	for _, it in list do
		if ARMOR[it.slot] and not it.broken then
			sum += N.armorCut(it.stage, mobLv)
		end
	end
	return sum / #D.ARMOR
end

function Items.starCap(stage: number): number
	for _, s in D.STARCAP do
		if stage < s.below then
			return s.cap
		end
	end
	return E.max
end

-- ---------- 처음 받는 차림 ----------
function Items.kit(who: string)
	local list = {}
	for _, slot in D.KIT.slots do
		table.insert(list, Items.make(slot, D.KIT.stage, D.NORMAL, who))
	end
	return list
end

-- ---------- 떨어지는 것 ----------
function Items.stageOf(mobLv: number): number
	if mobLv < 10 then
		return 1
	end
	return math.min(D.STAGES[#D.STAGES], math.floor(mobLv / 10) * 10)
end

function Items.rollQuality(rng): number
	local roll, acc = rng:NextNumber(0, 100), 0
	for i, q in D.QUALITY do
		acc += q.pct
		if roll < acc then
			return i
		end
	end
	return D.NORMAL
end

-- 몬스터 한 마리가 떨어뜨리는 장비(없으면 nil). who = 잡은 사람의 직업. mul = 확률에 곱하는 값(쓰러진 뒤의 벌칙 등)
function Items.rollDrop(rng, mobLv: number, who: string, mul: number?)
	local m = mul or 1
	local roll = rng:NextNumber(0, 100)
	local a, b, c = D.DROP.weapon * m, D.DROP.other * m, D.DROP.armor * m
	local stage = Items.stageOf(mobLv)
	if roll < a then
		return Items.make("weapon", stage, Items.rollQuality(rng), who)
	elseif roll < a + b then
		-- 다른 직업의 무기(넷 가운데 하나)
		local others = {}
		for class in D.KINDS do
			if class ~= who then
				table.insert(others, class)
			end
		end
		table.sort(others)
		return Items.make("weapon", stage, Items.rollQuality(rng), others[rng:NextInteger(1, #others)])
	elseif roll < a + b + c then
		return Items.make(D.ARMOR[rng:NextInteger(1, #D.ARMOR)], stage, Items.rollQuality(rng))
	end
	return nil
end

-- 달가루가 떨어지는 꼴: 확률(%)과 한 번에 떨어지는 양(소수일 수 있다). 평균 = 0.01 × (레벨/10)³
function Items.dustDrop(mobLv: number): (number, number)
	local avg = D.DUST.kill * (mobLv / 10) ^ 3
	local chance = math.min(D.DROP.dustChance / 100, avg)
	return chance * 100, avg / chance
end

-- 몬스터 한 마리가 떨어뜨리는 달가루(없으면 nil). 양의 소수 부분은 확률로 올린다 — 평균이 식과 꼭 같다
function Items.rollDust(rng, mobLv: number, mul: number?): number?
	local chance, amount = Items.dustDrop(mobLv)
	if rng:NextNumber(0, 100) >= chance * (mul or 1) then
		return nil
	end
	local whole = math.floor(amount)
	if rng:NextNumber(0, 1) < amount - whole then
		whole += 1
	end
	return math.max(1, whole)
end

-- ---------- 강화 ----------
-- star성에서 다음 별을 시도할 때 드는 달가루
function Items.enhanceDust(stage: number, star: number): number
	local unit = (stage / 10) ^ 3
	if star < E.lowBelow then
		return round(unit * (star + 1) / E.lowDiv)
	end
	return round(unit * (star + 1) ^ E.highPow / E.highDiv)
end

-- 그 별까지 한 번씩 붙었다고 본 달가루
function Items.starDust(stage: number, star: number): number
	local sum = 0
	for n = 0, star - 1 do
		sum += Items.enhanceDust(stage, n)
	end
	return sum
end

-- 다음 시도의 내용. guard = 파괴 막기를 켰는가.
--  { can(시도할 수 있는가), why, ok · fail · boom(%), dust, essence, drops(실패하면 떨어지는가), sure(반드시 성공인가), guard(파괴 막기를 쓸 수 있는 별인가) }
function Items.enhanceInfo(it, guard: boolean?)
	local s = it.star
	if it.broken then
		return { can = false, why = "부서짐" }
	end
	if s >= Items.starCap(it.stage) or s >= E.max then
		return { can = false, why = "상한" }
	end
	local row = E.table[s + 1]
	local canGuard = table.find(E.guard.stars, s + 1) ~= nil
	local useGuard = guard == true and canGuard
	local info = {
		can = true,
		ok = row[1],
		fail = row[2],
		boom = row[3],
		dust = Items.enhanceDust(it.stage, s) * (if useGuard then E.guard.cost else 1),
		essence = E.essence[s + 1],
		drops = s + 1 >= E.dropFrom and table.find(E.floors, s) == nil,
		sure = (it.fails or 0) >= E.chance,
		guard = canGuard,
	}
	if useGuard then
		info.fail += info.boom
		info.boom = 0
	end
	if info.sure then
		info.ok, info.fail, info.boom = 100, 0, 0
	end
	return info
end

-- 강화를 한 번 시도한다(값은 부른 쪽이 치른다). 결과: "ok" 붙음 · "fail" 그대로 · "drop" 한 단계 떨어짐 · "boom" 부서짐
function Items.enhance(it, rng, guard: boolean?): string
	local info = Items.enhanceInfo(it, guard)
	assert(info.can, "강화할 수 없는 장비")
	local roll = rng:NextNumber(0, 100)
	if roll < info.ok then
		it.star += 1
		it.fails = 0
		return "ok"
	elseif roll < info.ok + info.boom then
		it.star = math.min(E.boomTo, it.star)
		it.fails = 0
		it.broken = true
		return "boom"
	elseif info.drops then
		it.star -= 1
		it.fails = (it.fails or 0) + 1
		return "drop"
	end
	return "fail"
end

-- 부서진 장비를 같은 장비 하나로 되살린다(spare는 부른 쪽이 없앤다). 되살렸으면 true
function Items.restore(it, spare): boolean
	if not it.broken or spare.broken or not Items.same(it, spare) then
		return false
	end
	it.broken = false -- 별은 부서질 때 이미 12성(그보다 낮았으면 그대로)으로 내려 두었다
	it.fails = 0
	return true
end

-- ---------- 분해 · 별 옮기기 ----------
function Items.dismantle(it): number
	return round(D.DUST.dismantle * (it.stage / 10) ^ 3 + D.DUST.back / 100 * Items.starDust(it.stage, it.star))
end

-- 옛 장비의 별을 새 장비로 옮겼을 때 새 장비의 별(옛 별에서 하나를 뺀 만큼, 새 장비의 상한까지 — 이미 더 높으면 그대로)
function Items.transfer(from, to): number
	return math.max(to.star, math.min(Items.starCap(to.stage), math.max(0, from.star - 1)))
end

-- ---------- 상점 ----------
-- 그 물건의 값(물약은 내 레벨에 맞는 물약의 값)
function Items.stockPrice(stock, level: number): number
	if stock.id == "potion" then
		return N.potionAt(level).price
	end
	return stock.price
end

return Items
