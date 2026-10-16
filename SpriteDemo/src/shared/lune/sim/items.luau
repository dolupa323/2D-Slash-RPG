-- 장비의 셈 — 이름 · 옵션 · 떨어지는 것 · 강화 · 분해. 화면도 서버도 모르는 순수한 셈이다(별 옮기기는 2026-10-15에 뺐다).
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
-- 소비 · 기타 아이템(가방의 칸에 묶음으로 놓인다 — 공방 js/lune/design/items.js의 GOODS). order = 목록의 차례(정렬할 때 쓴다)
local GOODS = {}
for i, g in D.GOODS do
	GOODS[g.id] = g
	g.order = i
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

-- 소비 · 기타 아이템의 자료(없는 이름표면 nil): { id, tab("use" · "etc"), kind("potion" · "quest"), name, icon, stack, text, lv · heal(물약), from · quest · need(퀘스트의 물건) }
function Items.goods(id: any)
	return if typeof(id) == "string" then GOODS[id] else nil
end

-- 상점에 팔 때의 값(헐값 — 공방 js/lune/design/items.js의 SELL · gearSell과 같은 셈). 장비: 그 단계 몬스터 한 마리의 달돈 x (무기 · 그 밖의 몫 — D.SELL) x 20% — 성능과 별은 값에 들어가지 않는다
function Items.sellPrice(it): number
	local mult = if it.slot == "weapon" then D.SELL.weapon else D.SELL.other
	return math.max(1, math.floor(D.SELL.rate * mult * N.killMoney(it.stage) + 1e-9))
end

-- 소비 · 기타 아이템 하나를 상점에 팔 때의 값(0 = 팔 수 없다 — 퀘스트의 물건)
function Items.goodsSell(id: any): number
	local g = if typeof(id) == "string" then GOODS[id] else nil
	return if g then g.sell else 0
end

-- 그 레벨에서 쓸 수 있는 가장 좋은 물약(새 캐릭터의 물약 · 퀘스트 보상의 물약)
function Items.potionFor(level: number)
	local best = nil
	for _, g in D.GOODS do
		if g.kind == "potion" and g.lv <= level and (not best or g.lv > best.lv) then
			best = g
		end
	end
	return best
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

-- ---------- 옵션 · 방어 ----------  (2026-10-15 — 공방 numbers.js 2-1 · items.js의 gearOpt와 같은 셈)
--  무기 = 공격력 · 방어구 = 올스탯 · 방어력 · 장신구 = 올스탯(방어구의 절반). 성능이 기본 옵션에 % 로, 별이 그 위에 % 로 붙는다(레벨이 높은 장비일수록 기본 옵션이 커서 별 하나에 더 오른다).
--  돌려주는 것 { base = 별 없이, total = 별까지 } — 각각 { atk } 또는 { stat, def } 또는 { stat }. 부서진 것(흔적)은 모두 0
local SPEC = N.data.SPEC
function Items.options(it)
	local q = 1 + D.QUALITY[it.q].bonus / 100
	local base
	if it.slot == "weapon" then
		base = { atk = round(N.weaponAtk(it.stage) * q) }
	elseif ARMOR[it.slot] then
		base = { stat = round(N.armorStat(it.stage) * q), def = round(N.armorDef(it.stage) * q) }
	else
		base = { stat = round(N.armorStat(it.stage) * SPEC.acc.stat * q) }
	end
	local total = {}
	if it.broken then
		for k in base do
			base[k], total[k] = 0, 0
		end
		return { base = base, total = total }
	end
	local pct = N.starPct(if it.slot == "weapon" then "weapon" else "armor", it.star) / 100
	for k, v in base do
		total[k] = round(v * (1 + pct))
	end
	return { base = base, total = total }
end

-- 끼고 있는 장비들의 옵션 합 { atk, stat, def } — 피해 · 맞는 피해마다 불리므로 장비마다 표를 만들지 않고 바로 셈한다(Items.options와 같은 셈)
function Items.sum(list)
	local atk, stat, def = 0, 0, 0
	for _, it in list do
		if not it.broken then
			local q = 1 + D.QUALITY[it.q].bonus / 100
			if it.slot == "weapon" then
				atk += round(round(N.weaponAtk(it.stage) * q) * (1 + N.starPct("weapon", it.star) / 100))
			else
				local k = 1 + N.starPct("armor", it.star) / 100
				if ARMOR[it.slot] then
					stat += round(round(N.armorStat(it.stage) * q) * k)
					def += round(round(N.armorDef(it.stage) * q) * k)
				else
					stat += round(round(N.armorStat(it.stage) * SPEC.acc.stat * q) * k)
				end
			end
		end
	end
	return { atk = atk, stat = stat, def = def }
end

-- 받는 피해 감소 %: 끼고 있는 방어구의 방어력 합으로(같은 레벨 방어구 넷 = 30% · 빈 부위 · 부서진 것은 0)
function Items.cut(list, mobLv: number): number
	return N.cutOf(Items.sum(list).def, mobLv)
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

-- ---------- 재료 · 제작 · 낮은 확률의 귀한 드롭 ----------
--  사용자 2026-10-11: "그냥 일반몬스터들이 확률에 따라서 레벨 10 몬스터 잡다가 적은확률로 10렙제 아이템, 방어구를 드롭하는겁니다. 안뜨면 재료를 모아서 대장장이에서 만들수도 있구요.
--    … 그냥 몬스터에 간단하게 일반아이템 드롭되고, 낮은확률로 이것저것 리워드 드롭되게해서 반복사냥 mmorpg 개념으로 가야하는겁니다."
--  값은 공방 js/lune/design/items.js의 MATS · MATDROP · RECIPES · CRAFTQ · RARE(모두 제안)
local RECIPE = {}
for i, r in D.RECIPES do
	RECIPE[r.id] = r
	r.order = i
end

-- 그 레벨의 몬스터가 떨어뜨리는 재료들(가방의 기타 탭에 놓이는 아이템의 이름표 — 광석 · 가죽)
function Items.matsAt(mobLv: number): { string }
	local out = {}
	for _, m in D.MATS do
		if mobLv >= m.lv[1] and mobLv <= m.lv[2] then
			table.insert(out, m.id)
		end
	end
	return out
end

-- 몬스터 한 마리가 떨어뜨리는 재료(이름표들 — 없으면 빈 표). 재료마다 따로 굴린다(둘 다 나올 수도 있다)
function Items.rollMats(rng, mobLv: number, mul: number?): { string }
	local out = {}
	for _, id in Items.matsAt(mobLv) do
		if rng:NextNumber(0, 100) < D.MATDROP.pct * (mul or 1) then
			table.insert(out, id)
		end
	end
	return out
end

-- 낮은 확률의 귀한 것(소비 아이템의 이름표들): 그 몬스터의 레벨에 쓰는 물약 · 귀환 주문서
function Items.rollRare(rng, mobLv: number, mul: number?): { string }
	local out = {}
	for _, r in D.RARE do
		if mobLv >= (r.from or 0) and rng:NextNumber(0, 100) < r.pct * (mul or 1) then -- from = 그 레벨부터의 몬스터(선물 — 2026-10-16)
			if r.id == "potion" then
				table.insert(out, Items.potionFor(mobLv).id)
			elseif r.goods then
				table.insert(out, r.goods)
			end
		end
	end
	return out
end

-- 제작법(없는 이름표면 nil): { id, slot, stage, from(만들 수 있는 레벨), needs = { { item, n } … }, money }
function Items.recipe(id: any)
	return if typeof(id) == "string" then RECIPE[id] else nil
end

-- 만든 장비의 성능 단: 보통 이상만(D.CRAFTQ의 비율 — 떨어질 때의 보통 · 좋은 · 빼어난의 비율 그대로)
function Items.rollCraftQuality(rng): number
	local total = 0
	for _, x in D.CRAFTQ do
		total += x.pct
	end
	local roll = rng:NextNumber(0, total)
	for _, x in D.CRAFTQ do
		if roll < x.pct then
			return x.q
		end
		roll -= x.pct
	end
	return D.NORMAL
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
	-- 적어도 1(2026-10-15 — 상한을 풀며 Lv.1 장비가 공짜로 22성까지 가지 않게)
	if star < E.lowBelow then
		return math.max(1, round(unit * (star + 1) / E.lowDiv))
	end
	return math.max(1, round(unit * (star + 1) ^ E.highPow / E.highDiv))
end

-- 그 별까지 한 번씩 붙었다고 본 달가루
function Items.starDust(stage: number, star: number): number
	local sum = 0
	for n = 0, star - 1 do
		sum += Items.enhanceDust(stage, n)
	end
	return sum
end

-- 다음 시도의 내용. guard = 파괴 막기를 켰는가 · first = 그 캐릭터의 첫 강화인가(달가루 없이 반드시 붙는다 — 공방 basics.js의 FORGE.first).
--  { can(시도할 수 있는가), why, ok · fail · boom(%), dust, essence, drops(실패하면 떨어지는가), sure(반드시 성공인가), guard(파괴 막기를 쓸 수 있는 별인가), first(첫 강화인가) }
function Items.enhanceInfo(it, guard: boolean?, first: boolean?)
	local s = it.star
	if it.broken then
		return { can = false, why = "부서짐" }
	end
	if s >= E.max then -- 모든 장비가 22성까지(사용자 2026-10-15)
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
	-- 첫 강화: 공짜로, 반드시 붙는다(파괴 막기도 필요 없다)
	if first then
		info.first = true
		info.sure = true
		info.dust, info.essence = 0, 0
	end
	if info.sure then
		info.ok, info.fail, info.boom = 100, 0, 0
	end
	return info
end

-- 강화를 한 번 시도한다(값은 부른 쪽이 치른다). 결과: "ok" 붙음 · "fail" 그대로 · "drop" 한 단계 떨어짐 · "boom" 부서짐
function Items.enhance(it, rng, guard: boolean?, first: boolean?): string
	local info = Items.enhanceInfo(it, guard, first)
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

-- ---------- 분해 ----------
function Items.dismantle(it): number
	-- Lv.10부터는 적어도 1(분해했는데 0이 나오지 않게 — 공방의 dismantleDust와 같은 셈)
	return math.max(if it.stage >= 10 then 1 else 0, round(D.DUST.dismantle * (it.stage / 10) ^ 3 + D.DUST.back / 100 * Items.starDust(it.stage, it.star)))
end


-- ---------- 상점 ----------
-- 그 물건의 값(물약도 단마다 따로 판다 — 값이 레벨을 따라 달라지지 않는다)
function Items.stockPrice(stock, _level: number?): number
	return stock.price
end

return Items
