-- 아이템의 상세 — 가방 · 장비 창에서 고른 아이템을 창 옆의 작은 판에 적는 것(그리지는 않는다: client/lune/ui/itemDetail.luau가 그린다).
--  사용자 2026-10-08: "장비 탭에서 각각의 장비를 선택하면 그 해당장비가 장비창 옆에 작은모달이 떠서 아이템 스펙이 나와야합니다. 인벤토리에서 선택도 마찬가지입니다. 기타아이템, 소비아이템 모두 마찬가지입니다."
--  글과 차례는 공방 js/lune/design/items.js의 gearInfo · goodsInfo와 같다(낱말은 data/items.generated.luau의 WORDS) — tools/test/tests/15_lune_items.luau가 공방의 본보기(checks.info)와 맞춰 본다.
--  돌려주는 것 { name, tone(이름의 색), sub(이름 아래의 갈래), rows = { { 이름, 값, 색 } … }, notes = { { 글, 색 } … } }
--   색 = "text" · "dim" · "accent" · "red" · "gold" · "tier0"~"tier4"(성능 단: 낡은 … 빼어난)
local Items = require(script.Parent.Parent.sim.items)
local N = require(script.Parent.Parent.config.numbers)
local CLASSES = require(script.Parent.Parent.data["classes.generated"])
local Format = require(script.Parent.format)

local D = Items.data
local W = D.WORDS
local POWER = N.data.POWER

local I = {}

-- 그 장비 하나가 주는 전투력(부서진 것은 0)
function I.power(it): number
	return math.floor(POWER.base * POWER.itemShare * Items.score(it) / D.WSUM + 0.5)
end

-- 지금 장착한 것(worn — 없으면 nil)과 바꾸면 달라지는 전투력
function I.wearDiff(it, worn): number
	local raw = POWER.base * POWER.itemShare * (Items.score(it) - (if worn then Items.score(worn) else 0)) / D.WSUM
	return math.sign(raw) * math.floor(math.abs(raw) + 0.5)
end

-- 장비의 상세. me = { level, class } · worn = 같은 부위에 장착한 것(없으면 nil) · isWorn = 이 장비가 바로 장착한 그것인가(장비 창에서 골랐다)
function I.gear(it, me, worn: any, isWorn: boolean?)
	local slot, q, need = Items.slot(it.slot), D.QUALITY[it.q], Items.needLevel(it)
	local tier = "tier" .. (it.q - 1)
	local rows = { { W.need, "Lv." .. need, if me.level >= need then "text" else "red" } }
	if it.slot == "weapon" then
		table.insert(rows, { W.job, CLASSES.classes[it.who].name, if it.who == me.class then "text" else "red" })
	end
	table.insert(rows, { W.quality, if q.bonus == 0 then q.name else ("%s %s%d%%"):format(q.name, if q.bonus > 0 then "+" else "", q.bonus), tier })
	table.insert(rows, { W.star, ("+%d / %d"):format(it.star, Items.starCap(it.stage)), "text" })
	table.insert(rows, { W.power, "+" .. Format.short(I.power(it)), "gold" })
	if Items.isArmor(it.slot) then
		local cut = if it.broken then 0 else N.armorCut(it.stage, me.level) / #D.ARMOR
		table.insert(rows, { W.cut, ("%.1f%%"):format(math.floor(cut * 10 + 0.5) / 10), "text" })
	end
	local notes = {}
	if it.broken then
		table.insert(notes, { W.brokenNote, "red" })
	elseif isWorn then
		table.insert(notes, { W.worn, "accent" })
	elseif it.slot == "weapon" and it.who ~= me.class then
		table.insert(notes, { W.otherJob, "red" })
	elseif me.level < need then
		table.insert(notes, { Format.fill(W.needLv, { n = need }), "red" })
	else
		local d = I.wearDiff(it, worn)
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
	elseif it.star > 0 then
		name = ("%s +%d"):format(name, it.star)
	end
	return {
		name = name,
		tone = if it.broken then "red" else tier,
		sub = if it.slot == "weapon" then slot.kind else slot.kind .. " · " .. slot.name,
		rows = rows,
		notes = notes,
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
