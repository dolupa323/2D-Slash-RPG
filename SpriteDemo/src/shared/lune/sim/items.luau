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

-- 보스만 주는 이름 붙은 장비(2026-10-27 — 공방 js/lune/design/items.js의 UNIQUES · 사용자 "하드에서만 70제로 뜨는거야 이름을 멋있게 붙여야지"):
--  장비에 u(이름표)가 붙는다 — 이름 · 상세의 글은 그것의 것, 세기는 같은 부위 · 단계 · 성능의 장비와 같다(별 강화도 된다)
local UNIQUE = {}
for _, u in D.UNIQUES or {} do
	UNIQUE[u.id] = u
end
function Items.unique(id: any)
	return if typeof(id) == "string" then UNIQUE[id] else nil
end
-- q = 성능(주지 않으면 그 이름표의 것 — 보스 주화 장비는 교환할 때 굴려서 준다: 2026-11-05 사용자 "빼어난 확정 아니고 교환할때 샤냥터 드롭 장비처럼 랜덤값으로")
function Items.makeUnique(id: string, q: number?)
	local u = UNIQUE[id]
	assert(u, "없는 이름표 " .. tostring(id))
	local it = Items.make(u.slot, u.stage, q or u.q, u.who) -- who = 그 직업의 무기(보스 주화 장비 — 2026-11-05 화심 창 · 화심 큰 도끼 …)
	it.u = id
	return it
end
-- 그 장비를 낄 수 있는 직업(없으면 nil = 누구나 — 무기는 who · 보스 주화의 방어구는 그 이름표의 who: 2026-11-05 "무니는 무니 방어구 밖에 못쓰는거야 150제는")
function Items.classOf(it): string?
	if it.slot == "weapon" then
		return it.who
	end
	local u = it.u and UNIQUE[it.u]
	return if u then u.who else nil
end
-- 세기의 배(보스 주화 장비 — 2026-11-05 「140제 22성 = 150제 18성」: 공방 bosscoin.js의 match) · 그 밖은 1
local function mulOf(it): number
	local u = it.u and UNIQUE[it.u]
	return (u and u.mul) or 1
end
Items.mulOf = mulOf
-- 경매장에 올리지 못하는 것인가(2026-11-05 보스 주화: 거인의 심장핵 · 화심 주화 · 화심 장비 — design/bosscoin.js의 bound). it = 장비 · 또는 { item = 소비 · 기타 아이템의 이름표 }
function Items.bound(it: any): boolean
	if typeof(it) ~= "table" then
		return false
	end
	if it.item ~= nil then
		local g = Items.goods(it.item)
		return g ~= nil and g.bound == true
	end
	local u = it.u and UNIQUE[it.u]
	return u ~= nil and u.bound == true
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
	if it.u ~= nil then
		local u = UNIQUE[it.u]
		if not u or u.slot ~= it.slot or u.stage ~= it.stage or (it.slot == "weapon" and u.who ~= nil and u.who ~= it.who) then
			return false -- 모르는 이름표 · 부위나 단계가 다르다 · 직업마다의 무기인데 직업이 다르다(방어구의 직업은 이름표에 — Items.classOf)
		end
	end
	return it.star <= Items.starCap(it.stage)
end

-- 같은 장비인가(부서진 것을 되살릴 때 쓴다): 부위 · 단계 · 무기라면 직업
function Items.same(a, b): boolean
	return a.slot == b.slot and a.stage == b.stage and a.who == b.who and a.u == b.u
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
	local u = it.u and UNIQUE[it.u]
	if u then
		-- 이름 붙은 장비(보스 — 2026-10-27). 성능을 굴려 받는 것(보스 주화 — roll)은 사냥 장비처럼 앞에 성능(「빼어난 화심 창」 · 보통은 이름만)
		if u.roll and it.q ~= D.NORMAL and D.QUALITY[it.q] then
			return D.QUALITY[it.q].name .. " " .. u.name
		end
		return u.name
	end
	local head = if it.q == D.NORMAL then "" else D.QUALITY[it.q].name .. " "
	return ("%sLv.%d %s"):format(head, it.stage, Items.baseName(it))
end

-- ---------- 옵션 · 방어 ----------  (2026-10-15 — 공방 numbers.js 2-1 · items.js의 gearOpt와 같은 셈)
--  무기 = 공격력 · 방어구 = 올스탯 · 공격력 · 방어력 · 장신구 = 올스탯 · 공격력(방어구의 절반). 성능이 기본 옵션에 % 로, 별이 그 위에 % 로 붙는다(레벨이 높은 장비일수록 기본 옵션이 커서 별 하나에 더 오른다).
--  공격력은 2026-10-28 방어구 · 장신구에도(사용자 "다른 장비들도 공격력 기본옵션으로 붙이고 스타포스할때 같이올라가게") — 적어도 1 · 이름 붙은 장비는 제 값(u.atk — 흑수정 마안 2)
--  돌려주는 것 { base = 별 없이, total = 별까지 } — 각각 { atk } 또는 { stat, atk, def } 또는 { stat, atk }. 부서진 것(흔적)은 모두 0
local SPEC = N.data.SPEC
-- 방어구 · 장신구의 기본 공격력(k = 1 방어구 · SPEC.acc.atk 장신구 — 적어도 1). 이름 붙은 장비는 제 값
local function gearAtk(it, k: number, q: number): number
	local u = it.u and UNIQUE[it.u]
	if u and u.atk then
		return u.atk
	end
	return math.max(1, round(N.armorAtk(it.stage) * k * q * mulOf(it)))
end
function Items.options(it)
	local q = 1 + D.QUALITY[it.q].bonus / 100
	local mq = q * mulOf(it) -- (보스 주화 장비의 세기 배 — 2026-11-05)
	local base
	if it.slot == "weapon" then
		base = { atk = round(N.weaponAtk(it.stage) * mq) }
	elseif ARMOR[it.slot] then
		base = { stat = round(N.armorStat(it.stage) * mq), atk = gearAtk(it, 1, q), def = round(N.armorDef(it.stage) * mq) }
	else
		base = { stat = round(N.armorStat(it.stage) * SPEC.acc.stat * q), atk = gearAtk(it, SPEC.acc.atk, q) }
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
			local mq = q * mulOf(it)
			if it.slot == "weapon" then
				atk += round(round(N.weaponAtk(it.stage) * mq) * (1 + N.starPct("weapon", it.star) / 100))
			else
				local k = 1 + N.starPct("armor", it.star) / 100
				if ARMOR[it.slot] then
					stat += round(round(N.armorStat(it.stage) * mq) * k)
					atk += round(gearAtk(it, 1, q) * k)
					def += round(round(N.armorDef(it.stage) * mq) * k)
				else
					stat += round(round(N.armorStat(it.stage) * SPEC.acc.stat * q) * k)
					atk += round(gearAtk(it, SPEC.acc.atk, q) * k)
				end
			end
		end
	end
	-- 세트 효과(2026-11-05 — 공방 bosscoin.js GEARSETS · 보스 전리품 · 화심): 그 세트의 것을 n개 끼면 n까지의 단계를 모두
	local bonus = Items.setBonus(list)
	-- 추가 옵션(2026-11-07): 공격력 · 올스탯 · 방어력은 여기 더한다(힘 · 민첩 · 지능 · 운은 Hero.spec이 ex로 · % 옵션은 패시브 · 키트 · 버프의 셈이)
	local ex = Items.exSum(list)
	return { atk = atk + bonus.atk + (ex.atk or 0), stat = stat + bonus.stat + (ex.all or 0), def = def + bonus.def + (ex.def or 0), ex = ex }
end

-- ---------- 세트 효과(2026-11-05 사용자: "지금 출시된 보스들의 장신구 세트효과가 있어야해 2세트 효과 , 3세트효과 이런식으로 150제 장비도 세트효과 추가하고 너무강력하진않게 하지만 맞추는 메리트는 있게") ----------
--  이름 붙은 장비의 set(보스 전리품 = 보스의 장신구 넷 · 화심 = 무기 + 방어구 넷 — 직업이 달라도 같은 세트)을 부위마다 센다(부서진 것은 세지 않는다)
local SETS = {}
for _, g in D.GEARSETS or {} do
	SETS[g.id] = g
end
function Items.gearSet(id: any)
	return if typeof(id) == "string" then SETS[id] else nil
end
-- 끼고 있는 것들에서 세트마다 낀 수 { [세트] = n }
function Items.setCounts(list): { [string]: number }
	local n = {}
	local seen = {}
	for _, it in list do
		local u = it.u and UNIQUE[it.u]
		if u and u.set and SETS[u.set] and not it.broken and not seen[it.slot] then
			seen[it.slot] = true
			n[u.set] = (n[u.set] or 0) + 1
		end
	end
	return n
end
-- 세트 효과의 합 { stat, atk, def }
function Items.setBonus(list)
	local out = { stat = 0, atk = 0, def = 0 }
	for id, n in Items.setCounts(list) do
		for _, st in SETS[id].steps do
			if n >= st.n then
				out.stat += st.stat or 0
				out.atk += st.atk or 0
				out.def += st.def or 0
			end
		end
	end
	return out
end

-- ---------- 추가 옵션(2026-11-07 — 공방 js/lune/design/items.js 4-1b의 EXTRA · 사용자 "모든 장비에 메이플스토리 추가옵션 같은 개념을 부여할거야") ----------
--  장비마다 it.ex = { { k = 종류, v = 값 }, … } — 줄 수 = 착용 레벨로(150 이상 3 · 70 이상 2 · 그 아래 1) · 종류는 겹치지 않게 같은 확률 · 값은 범위의 정수 하나(같은 확률).
--  장비가 가방 · 장비 칸 · 창고에 처음 들어올 때(bag.luau의 stamp) 없으면 굴린다 — 떨어진 것 · 만든 것 · 산 것 · 보스 · 주화 교환 · 이날 전에 생긴 옛 장비 모두.
--  별(강화)은 추가 옵션에 붙지 않는다(메이플과 같다). 부서진 장비(흔적)의 추가 옵션은 쳐 주지 않는다(되살리면 그대로).
--  값의 뜻: str · dex · int · luk · all · atk · def = 그만큼 더한다 · hp · crit · critDmg · dmg · final · cut · run = % 더한다
local EX = D.EXTRA or { counts = {}, pool = {}, pctMin = 0.3 }
local EXPOOL = {}
for i, p in EX.pool do
	EXPOOL[p.id] = p
	p.order = i
end
Items.EXTRA = EX
local EXRNG = Random.new()
-- 그 레벨 장비의 추가 옵션 줄 수
function Items.exCount(stage: number): number
	for _, c in EX.counts do
		if stage >= c.min then
			return c.n
		end
	end
	return 0
end
-- 그 옵션의 값 범위(정수 · 적어도 1) — 공방 extraRange와 같은 셈
function Items.exRange(id: string, stage: number): (number, number)
	local o = EXPOOL[id]
	if not o then
		return 0, 0
	end
	if o.pct then
		local s = math.clamp(stage / 150, EX.pctMin, 1)
		local lo = math.max(1, round(o.lo * s))
		return lo, math.max(lo, round(o.hi * s))
	end
	local b = if o.base == "stat" then N.armorStat(stage) elseif o.base == "watk" then N.weaponAtk(stage) else N.armorDef(stage)
	local lo = math.max(1, round(o.lo * b))
	return lo, math.max(lo, round(o.hi * b))
end
-- 새로 굴린다(줄 수는 그 레벨의 것) — { { k, v }, … }
function Items.rollExtra(stage: number, rng: any?): { any }
	local r = rng or EXRNG
	local left = {}
	for _, p in EX.pool do
		table.insert(left, p.id)
	end
	local out = {}
	for _ = 1, math.min(Items.exCount(stage), #left) do
		local k = table.remove(left, r:NextInteger(1, #left))
		local lo, hi = Items.exRange(k, stage)
		table.insert(out, { k = k, v = r:NextInteger(lo, hi) })
	end
	return out
end
-- 꼴이 맞는가: 줄 수가 그 레벨의 것 · 아는 종류 · 겹치지 않는다 · 값은 1 이상의 정수
function Items.exValid(it): boolean
	local ex = it.ex
	if typeof(ex) ~= "table" or #ex ~= Items.exCount(it.stage) then
		return false
	end
	local seen = {}
	for _, e in ex do
		if typeof(e) ~= "table" or not EXPOOL[e.k] or seen[e.k] or typeof(e.v) ~= "number" or e.v ~= math.floor(e.v) or e.v < 1 or e.v > 1e6 then
			return false
		end
		seen[e.k] = true
	end
	return true
end
-- 없으면(또는 꼴이 틀리면) 굴려 붙인다
--  (자동 검사의 가짜 환경은 shared.LUNE_NOEXTRA = true — 옛 검사들이 정한 숫자를 보게 · 추가 옵션의 검사(tests/133)만 끈다)
function Items.ensureExtra(it, rng: any?)
	if typeof(shared) == "table" and shared.LUNE_NOEXTRA then
		return it
	end
	if typeof(it) == "table" and SLOT[it.slot] and typeof(it.stage) == "number" and not Items.exValid(it) then
		it.ex = Items.rollExtra(it.stage, rng)
	end
	return it
end
-- 장비 하나의 저장 줄(가방 · 창고 — bag.luau · 경매장 — market.luau가 같이 쓴다):
--  { 부위, 단계, 성능, 별, 직업(무기 — 아니면 ""), 잇단 실패, 부서짐(1 · 0), 이름표(보스의 이름 붙은 장비 — 2026-10-27), 추가 옵션(2026-11-07 — Items.packEx) }
--  이름표가 없으면 8째는 비우고(추가 옵션이 있으면 false — 줄에 빈 데가 없게), 추가 옵션이 없으면 9째를 비운다
function Items.packRow(it)
	local row = { it.slot, it.stage, it.q, it.star, it.who or "", it.fails or 0, if it.broken then 1 else 0 }
	if it.u then
		row[8] = it.u
	end
	local ex = Items.packEx(it)
	if ex then
		row[8] = it.u or false
		row[9] = ex
	end
	return row
end
-- 저장 꼴: { 종류, 값, 종류, 값, … }(평평하게 — 가방 · 창고 · 경매장의 줄 9째)
function Items.packEx(it): any
	if typeof(it.ex) ~= "table" then
		return nil
	end
	local out = {}
	for _, e in it.ex do
		table.insert(out, e.k)
		table.insert(out, e.v)
	end
	return out
end
function Items.unpackEx(row: any): any
	if typeof(row) ~= "table" then
		return nil
	end
	local out = {}
	for i = 1, #row - 1, 2 do
		table.insert(out, { k = row[i], v = row[i + 1] })
	end
	return out
end
-- 보낼 꼴(화면 — 아이템 상세): 그대로 복사
function Items.viewEx(it): any
	if typeof(it.ex) ~= "table" then
		return nil
	end
	local out = {}
	for i, e in it.ex do
		out[i] = { k = e.k, v = e.v }
	end
	return out
end
-- 끼고 있는 것들의 추가 옵션 합 { [종류] = 값 }(부서진 것은 빼고)
function Items.exSum(list): { [string]: number }
	local out = {}
	for _, it in list do
		if not it.broken and typeof(it.ex) == "table" then
			for _, e in it.ex do
				out[e.k] = (out[e.k] or 0) + e.v
			end
		end
	end
	return out
end
-- 캐릭터가 끼고 있는 것의 그 종류 합(h.equip — 패시브 · 키트 · 버프의 셈이 부른다)
function Items.exOf(h, key: string): number
	local n = 0
	if typeof(h) ~= "table" or typeof(h.equip) ~= "table" then
		return 0
	end
	for _, it in h.equip do
		if not it.broken and typeof(it.ex) == "table" then
			for _, e in it.ex do
				if e.k == key then
					n += e.v
				end
			end
		end
	end
	return n
end
-- 재설정(윤슬 조각): 줄 수 그대로 새로 굴린다
function Items.reroll(it, rng: any?)
	it.ex = Items.rollExtra(it.stage, rng)
	return it.ex
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
-- 그 캐릭터의 첫 강화로 치는가(달가루 없이 반드시 붙는다): 강화를 해 본 적이 없고 · 별이 없는 장비이고 · 제 레벨 + 10까지의 장비.
--  서버(Bag.enhance)와 화면(대장간 창)이 같은 셈을 쓴다(2026-10-18 검토: 화면은 「+10」을 보지 않아 높은 장비에도 「첫 강화」를 보이고, 서버는 보통 강화로 달가루를 받았다)
function Items.firstFree(forged: any, level: number?, it): boolean
	return forged ~= true and it.star == 0 and it.stage <= (level or 1) + 10
end

function Items.enhanceInfo(it, guard: boolean?, first: boolean?)
	local s = it.star
	if it.broken then
		return { can = false, why = "부서짐" }
	end
	if s >= E.max then -- 모든 장비가 22성까지(사용자 2026-10-15)
		return { can = false, why = "상한" }
	end
	local row = E.table[s + 1]
	local sure = (it.fails or 0) >= E.chance -- 찬스 타임: 반드시 붙는다 — 파괴 방지가 필요 없다(2026-10-18 검토: 켜 두면 값만 세 배로 받았다)
	local canGuard = table.find(E.guard.stars, s + 1) ~= nil and not sure and not first
	local useGuard = guard == true and canGuard
	local info = {
		can = true,
		ok = row[1],
		fail = row[2],
		boom = row[3],
		dust = Items.enhanceDust(it.stage, s) * (if useGuard then E.guard.cost else 1),
		essence = E.essence[s + 1],
		drops = s + 1 >= E.dropFrom and table.find(E.floors, s) == nil,
		sure = sure,
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
-- 물약 · 귀환 주문서를 n개 분해하면 받는 달가루(2026-10-27 사용자: "포션이랑 마을귀환주문서 분해할수있게하고 분해하면 소량의 달가루") — 하나의 몫(dust — 소수)에 n을 곱해 내린다. 분해할 수 없는 것은 nil
function Items.goodsDust(id: any, n: number): number?
	local def = Items.goods(id)
	if not def or typeof(def.dust) ~= "number" or def.dust <= 0 then
		return nil
	end
	return math.floor(def.dust * n + 1e-9)
end

function Items.dismantle(it): number
	-- Lv.10부터는 적어도 1(분해했는데 0이 나오지 않게 — 공방의 dismantleDust와 같은 셈)
	return math.max(if it.stage >= 10 then 1 else 0, round(D.DUST.dismantle * (it.stage / 10) ^ 3 + D.DUST.back / 100 * Items.starDust(it.stage, it.star)))
end


-- ---------- 상점 ----------
-- 그 물건의 값(물약도 단마다 따로 판다 — 값이 레벨을 따라 달라지지 않는다)
-- 상점의 값: 레벨에 따라 오르는 것(달빛 부적 · 능력치 초기화 — perLv)은 내 레벨 x perLv(2026-10-18 — 설계 economy.js의 PRICE)
function Items.stockPrice(stock, level: number?): number
	if stock.perLv then
		return stock.perLv * math.max(1, level or 1)
	end
	return stock.price
end

return Items
