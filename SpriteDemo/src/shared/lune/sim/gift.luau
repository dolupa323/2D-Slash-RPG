-- 보상 꾸러미 { money = 달돈, dust = 달가루, potion = 그 캐릭터의 레벨에 쓰는 물약(병), scroll = 귀환 주문서(장) } 를 캐릭터에게 준다 — 출석(sim/attend.luau) · 업적(sim/achieve.luau)이 같이 쓴다(2026-10-15).
--  가방에 다 들어가지 않으면 하나도 주지 않는다(받지 못한 것은 그대로 남아 다음에 다시 받는다).
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)
local Format = require(script.Parent.Parent.ui.format)

local Gift = {}

Gift.SCROLL = "scroll_return"

-- 꾸러미의 물건들 { { id, n } } — 그 캐릭터의 레벨로 물약을 고른다
function Gift.items(h, r): { { any } }
	local out = {}
	if (r.potion or 0) > 0 then
		table.insert(out, { Items.potionFor(h.level).id, r.potion })
	end
	if (r.scroll or 0) > 0 then
		table.insert(out, { Gift.SCROLL, r.scroll })
	end
	-- 아이템 { [id] = 수 }(2026-10-16 — 호감도 · 모험의 서의 선물). 이름 차례로(늘 같은 차례)
	if typeof(r.items) == "table" then
		local ids = {}
		for id, n in r.items do
			if typeof(n) == "number" and n > 0 then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			table.insert(out, { id, r.items[id] })
		end
	end
	return out
end

-- 준다. 다 들어가지 않으면 (nil, 까닭)
function Gift.give(h, r): (boolean?, string?)
	local given = {}
	for _, it in Gift.items(h, r) do
		local ok, why = Bag.give(h, it[1], it[2])
		if not ok then
			for _, back in given do
				Bag.take(h, back[1], back[2]) -- 앞에서 넣은 것을 되돌린다(하나도 주지 않는다)
			end
			return nil, why
		end
		table.insert(given, it)
	end
	h.money += r.money or 0
	h.dust += r.dust or 0
	return true
end

-- 꾸러미를 글로: 「달가루 30 · 귀환 주문서 3장」 (words = 그 창의 글 — money · dust · potion · scroll)
function Gift.text(r, words): string
	local parts = {}
	for _, k in { "money", "dust", "potion", "scroll" } do
		if (r[k] or 0) > 0 then
			table.insert(parts, Format.fill(words[k], { n = Format.short(r[k]) }))
		end
	end
	if typeof(r.items) == "table" then -- 아이템: 「들꽃 다발 3」
		local ids = {}
		for id in r.items do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local g = Items.goods(id)
			if g then
				table.insert(parts, ("%s %d"):format(g.name, r.items[id]))
			end
		end
	end
	return table.concat(parts, " · ")
end

-- 꾸러미의 첫 그림(작은 그림의 이름)과 수 — 칸에 그릴 것
function Gift.icon(r): (string, number)
	if (r.dust or 0) > 0 then
		return "dust", r.dust
	elseif (r.money or 0) > 0 then
		return "coin", r.money
	elseif (r.scroll or 0) > 0 then
		return "scroll", r.scroll
	end
	return "potion_s", r.potion or 0
end

return Gift
