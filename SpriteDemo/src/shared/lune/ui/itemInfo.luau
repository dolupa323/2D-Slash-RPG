-- 아이템의 상세 — 가방 · 장비 창에서 고른 아이템을 창 옆의 작은 판에 적는 것(그리지는 않는다: client/lune/ui/itemDetail.luau가 그린다).
--  사용자 2026-10-08: "장비 탭에서 각각의 장비를 선택하면 그 해당장비가 장비창 옆에 작은모달이 떠서 아이템 스펙이 나와야합니다. 인벤토리에서 선택도 마찬가지입니다. 기타아이템, 소비아이템 모두 마찬가지입니다."
--  글과 차례는 공방 js/lune/design/items.js의 gearInfo · goodsInfo와 같다(낱말은 data/items.generated.luau의 WORDS) — tools/test/tests/15_lune_items.luau가 공방의 본보기(checks.info)와 맞춰 본다.
--  돌려주는 것 { name, tone(이름의 색), sub(이름 아래의 갈래), rows = { { 이름, 값, 색 } … }, notes = { { 글, 색 } … }, stars · starMax(장비 — 이름 위에 그리는 별) }
--  2026-10-15 스펙을 다시 짜며: 이름에 「+n」을 붙이지 않는다(별은 이름 위에 별 그림으로 — 1성에 별 하나) · 「강화 +n / 상한」 · 「전투력 +n」 줄 대신 옵션 줄
--   (무기 「공격력 +73 (65 +8)」 · 방어구 「올스탯」 · 「방어력」 — 괄호 안 = 기본 + 별이 붙인 몫) · 「장착하면 전투력 ±n」은 내 스펙(me.spec — 서버의 Hero.specView)으로 셈한다
--   색 = "text" · "dim" · "accent" · "red" · "gold" · "tier0"~"tier4"(성능 단: 낡은 … 빼어난)
local Items = require(script.Parent.Parent.sim.items)
local N = require(script.Parent.Parent.config.numbers)
local CLASSES = require(script.Parent.Parent.data["classes.generated"])
local Format = require(script.Parent.format)

local D = Items.data
local W = D.WORDS
local SPEC = N.data.SPEC
local STATS = N.data.STATS

local I = {}
-- 옵션의 차례(상세 판 · 강화 창): 올스탯 · 공격력 · 방어력(공방 items.js의 OPT_ORDER — 2026-10-28 방어구 · 장신구에도 공격력이 붙어서)
I.ORDER = { "stat", "atk", "def" }

-- 스펙이 오지 않았을 때(본보기 · 시험)의 스펙: 그 레벨의 점수를 다 주스탯에 · 그 장비들만 · 패시브 없이(공방 items.js의 specOf와 같은 셈)
function I.specOf(level: number, list)
	local all, atk = 0, 0
	for _, it in list do
		local o = Items.options(it).total
		all += o.stat or 0
		atk += o.atk or 0
	end
	return { main = STATS.base + STATS.perLevel * (level - 1) + all, sub = STATS.base + all, atk = atk, k = 1 + SPEC.crit.chance / 100 * (SPEC.crit.mul - 1) }
end

-- 그 레벨의 본보기 캐릭터의 스펙(같은 레벨 보통 무기 + 방어구 넷 · 찍은 점수는 다 주스탯 · 패시브 없이 — 공방 items.js의 refSpec) — 내 스펙을 모를 때 쓴다
function I.refSpec(level: number)
	local all = 4 * N.armorStat(level)
	return { main = STATS.base + STATS.perLevel * (level - 1) + all, sub = STATS.base + all, atk = N.weaponAtk(level) + 4 * math.max(1, math.floor(N.armorAtk(level) + 0.5)), k = 1 + SPEC.crit.chance / 100 * (SPEC.crit.mul - 1) } -- (방어구 넷의 공격력도 — 2026-10-28)
end

-- 지금 장착한 것(worn — 없으면 nil)을 it로 바꾸면 달라지는 전투력. sp = 내 스펙 { main, sub, atk, k } · cls = 내 직업(추가 옵션의 힘 · 민첩 · 지능 · 운이 주스탯 · 부스탯인가 — 없으면 올스탯만)
--  추가 옵션(2026-11-07): 올스탯 · 공격력 · 그 직업의 주 · 부스탯 · 데미지 % · 최종 데미지 %를 넣는다(크리티컬 확률 · 데미지는 넣지 않는다 — 내 지금 크리티컬을 화면이 모른다)
function I.wearDiff(it, worn, sp, cls: string?): number
	local a = Items.options(it).total
	local b = if worn then Items.options(worn).total else {}
	local ea = Items.exSum({ it })
	local eb = if worn then Items.exSum({ worn }) else {}
	local function dx(k: string): number
		return (ea[k] or 0) - (eb[k] or 0)
	end
	local ds, da = (a.stat or 0) - (b.stat or 0) + dx("all"), (a.atk or 0) - (b.atk or 0) + dx("atk")
	local pair = cls and STATS.classes and STATS.classes[cls]
	local dm, dsub = ds + (if pair then dx(pair[1]) else 0), ds + (if pair then dx(pair[2]) else 0)
	local mul = (1 + dx("dmg") / 100) * (1 + dx("final") / 100)
	local raw = (N.statAtk(sp.main + dm, sp.sub + dsub, sp.atk + da) * mul - N.statAtk(sp.main, sp.sub, sp.atk)) * sp.k
	return math.sign(raw) * math.floor(math.abs(raw) + 0.5)
end

-- 추가 옵션 한 줄의 값(2026-11-07): 「+12」 · % 옵션은 「+3%」
local EXOPT = {}
for _, p in (Items.EXTRA.pool or {}) do
	EXOPT[p.id] = p
end
function I.exText(k: string, v: number): string
	local p = EXOPT[k]
	return if p and p.pct then ("+%d%%"):format(v) else "+" .. Format.short(v)
end
-- 추가 옵션들을 줄로(큐브 창의 BEFORE · AFTER — 2026-11-10): { { 이름, 값 } … }
function I.exRows(ex: any): { { string } }
	local out = {}
	for _, e in (if typeof(ex) == "table" then ex else {}) do
		local p = EXOPT[e.k]
		if p then
			table.insert(out, { p.name, I.exText(e.k, e.v) })
		end
	end
	return out
end
-- 옵션 줄(올스탯 · 공격력 · 방어력)과 같은 추가 옵션의 종류
local EXSAME = { stat = "all", atk = "atk", def = "def" }

-- 옵션 한 줄의 값: 「+68」 · 별이 붙었으면 「+68 (65 +3)」
function I.optText(base: number, total: number): string
	if total > base then
		return ("+%s (%s +%s)"):format(Format.short(total), Format.short(base), Format.short(total - base))
	end
	return "+" .. Format.short(total)
end

-- 장비의 상세. me = { level, class, spec(내 스펙 — 없으면 그 레벨 · 장착한 것으로 셈한다) } · worn = 같은 부위에 장착한 것(없으면 nil) · isWorn = 이 장비가 바로 장착한 그것인가(장비 창에서 골랐다)
function I.gear(it, me, worn: any, isWorn: boolean?)
	local slot, q, need = Items.slot(it.slot), D.QUALITY[it.q], Items.needLevel(it)
	local tier = "tier" .. (it.q - 1)
	local o = Items.options(it)
	local rows = { { W.need, "Lv." .. need, if me.level >= need then "text" else "red" } }
	local cls = Items.classOf(it) -- 무기 · 보스 주화의 방어구(2026-11-05 — 그 직업만)
	if cls and CLASSES.classes[cls] then
		table.insert(rows, { W.job, CLASSES.classes[cls].name, if cls == me.class then "text" else "red" })
	end
	table.insert(rows, { W.quality, if q.bonus == 0 then q.name else ("%s %s%d%%"):format(q.name, if q.bonus > 0 then "+" else "", q.bonus), tier })
	-- 추가 옵션(2026-11-07 — 사용자 "장비 능력치 옆에 연두색으로 + 몇 이라고 뜨고 거기에는 특별한 옵션들이뜬다"): 같은 종류의 옵션 줄 끝에 연두 「+n」(4째 칸) ·
	--  그 장비에 없는 줄(무기의 방어력 · 올스탯 …)과 그 밖의 것(힘 · 크리티컬 확률 …)은 아래에 줄마다 연두로(추가 옵션의 차례대로). 부서진 장비(흔적)는 쳐 주지 않아 보이지 않는다
	local ex = {}
	if not it.broken and typeof(it.ex) == "table" then
		for _, e in it.ex do
			ex[e.k] = (ex[e.k] or 0) + e.v
		end
	end
	local shownEx = {}
	for _, k in I.ORDER do
		if o.base[k] ~= nil then
			local ek = EXSAME[k]
			local add = ex[ek]
			if add then
				shownEx[ek] = true
			end
			table.insert(rows, { W[k], I.optText(o.base[k], o.total[k]), if k == "def" then "text" else "gold", if add then I.exText(ek, add) else nil })
		end
	end
	if not it.broken and typeof(it.ex) == "table" then
		for _, e in it.ex do
			if not shownEx[e.k] and EXOPT[e.k] then
				table.insert(rows, { EXOPT[e.k].name, I.exText(e.k, e.v), "extra" })
			end
		end
	end
	local notes = {}
	if it.broken then
		table.insert(notes, { W.brokenNote, "red" })
	elseif isWorn then
		table.insert(notes, { W.worn, "accent" })
	elseif cls ~= nil and cls ~= me.class then
		table.insert(notes, { W.otherJob, "red" })
	elseif me.level < need then
		table.insert(notes, { Format.fill(W.needLv, { n = need }), "red" })
	else
		local d = I.wearDiff(it, worn, me.spec or I.refSpec(me.level), me.class)
		if d > 0 then
			table.insert(notes, { Format.fill(W.wearUp, { n = Format.short(d) }), "accent" })
		elseif d < 0 then
			table.insert(notes, { Format.fill(W.wearDown, { n = Format.short(-d) }), "red" })
		else
			table.insert(notes, { W.wearSame, "dim" })
		end
	end
	if not isWorn then
		table.insert(notes, { Format.fill(W.dust, { n = Format.short(Items.dismantle(it)) }), "dim" })
		table.insert(notes, { Format.fill(W.sell, { n = Format.short(Items.sellPrice(it)) }), "dim" })
	end
	local name = Items.name(it)
	if it.broken then
		name = name .. " " .. W.broken
	end
	local u = Items.unique(it.u)
	if u then
		table.insert(notes, 1, { u.text, "text" }) -- 이름 붙은 장비(보스 — 2026-10-27)의 글을 맨 위에
		-- 세트 효과(2026-11-05 — Items.setBonus): 「화심 세트 3/5」 · 단계마다 「2세트 — 올스탯 +20」(지금 받는 단계는 민트 · 아직은 흐림). 낀 수 = me.equip(장착한 것 — 없으면 0)
		local set = u.set and Items.gearSet(u.set)
		if set then
			local worn = {}
			for _, e in (me.equip or {}) do
				table.insert(worn, e)
			end
			local have = Items.setCounts(worn)[set.id] or 0
			local top = set.steps[#set.steps].n
			local at = 2
			table.insert(notes, at, { Format.fill(W.setHead, { name = set.name, n = have, max = top }), "gold" })
			for _, st in set.steps do
				local parts = {}
				for _, k in I.ORDER do
					if (st[k] or 0) > 0 then
						table.insert(parts, ("%s +%d"):format(W[k], st[k]))
					end
				end
				at += 1
				table.insert(notes, at, { Format.fill(W.setStep, { n = st.n, what = table.concat(parts, " · ") }), if have >= st.n then "accent" else "dim" })
			end
		end
	end
	return {
		name = name,
		tone = if it.broken then "red" else tier,
		sub = if it.slot == "weapon" then slot.kind else slot.kind .. " · " .. slot.name,
		rows = rows,
		notes = notes,
		stars = it.star,
		starMax = D.ENHANCE.max,
	}
end

-- 소비 · 기타 아이템의 상세. id = 이름표 · n = 가방에 든 수(모든 칸의 합)
function I.goods(id: string, me, n: number)
	local g = Items.goods(id)
	local rows = { { W.have, Format.fill(W.count, { n = n }), "text" } }
	if g.kind == "potion" then
		table.insert(rows, { W.effect, Format.fill(W.heal, { n = g.heal }), "accent" })
		table.insert(rows, { W.useLv, "Lv." .. g.lv, if me.level >= g.lv then "text" else "red" })
		table.insert(rows, { W.wait, Format.fill(W.sec, { n = N.data.BODY.cooldown.field }), "text" })
	end
	table.insert(rows, { W.stack, Format.fill(W.upTo, { n = g.stack }), "dim" })
	local notes = { { g.text, "text" } }
	if g.kind == "potion" and me.level < g.lv then
		table.insert(notes, { Format.fill(W.useNeed, { n = g.lv }), "red" })
	end
	if g.from then
		table.insert(notes, { Format.fill(W.from, { mob = g.from }), "dim" })
	end
	if g.quest then
		table.insert(notes, { Format.fill(W.quest, { quest = g.quest, n = g.need }), "dim" })
	end
	if g.sell > 0 then
		table.insert(notes, { Format.fill(W.sellEach, { n = Format.short(g.sell) }), "dim" })
	end
	return {
		name = g.name,
		tone = "text",
		sub = if g.kind == "quest" then W.tab[g.tab] .. " · " .. W.questItem else W.tab[g.tab],
		rows = rows,
		notes = notes,
	}
end

return I
