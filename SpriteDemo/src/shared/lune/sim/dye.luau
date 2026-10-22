-- 무기 · 로브 색(염색 — 2026-10-22). 설계 = 공방 js/lune/design/dye.js(→ data/dye.generated.luau).
--  사용자: "무기 색깔 바꾸는거 할수있어? 로브색깔이나" · "살라맨더 머리색 바뀌는걸로하죠"
--  캐릭터의 모습 h.look = { point = 무기 색의 이름표?, robe = 로브 색의 이름표? } — 없으면 원래 색. 저장 · 다른 사람의 화면(Who) · 캐릭터 고르기 화면에 같이 간다.
--  바꾸는 것: 가방의 「무기 염색약」 · 「로브 염색약」을 쓰면 색을 고르는 창 → Cash "dye"(server/lune/modules/world.luau)가 한 개를 쓰고 바꾼다
local DYE = require(script.Parent.Parent.data["dye.generated"])

local Dye = {}
Dye.data = DYE
Dye.BASE = "base" -- 「원래」(색을 지운다)
Dye.ITEM = { point = "bm_dyepoint", robe = "bm_dyerobe" } -- 고르는 곳 → 쓰는 염색약
Dye.PART = { bmDyePoint = "point", bmDyeRobe = "robe" } -- 염색약의 종류 → 고르는 곳

local BY = { point = {}, robe = {} }
for _, q in DYE.point do
	BY.point[q.id] = q
end
for _, q in DYE.robe do
	BY.robe[q.id] = q
end

-- 그 곳의 그 색(없으면 nil)
function Dye.find(part: any, id: any)
	local t = BY[part]
	return if t and typeof(id) == "string" then t[id] else nil
end

-- 고를 수 있는 것인가(「원래」도 된다)
function Dye.valid(part: any, id: any): boolean
	return BY[part] ~= nil and (id == Dye.BASE or Dye.find(part, id) ~= nil)
end

-- 저장된 것 · 받은 것을 깨끗한 모습으로(모르는 색은 버린다 — 색을 뺀 뒤에 저장된 캐릭터도 원래 색으로 들어온다)
function Dye.clean(look: any): { point: string?, robe: string? }
	local out = {}
	if typeof(look) == "table" then
		if Dye.find("point", look.point) then
			out.point = look.point
		end
		if Dye.find("robe", look.robe) then
			out.robe = look.robe
		end
	end
	return out
end

-- 그 캐릭터의 지금 색(없으면 「원래」)
function Dye.current(look: any, part: string): string
	return (typeof(look) == "table" and Dye.find(part, look[part]) and look[part]) or Dye.BASE
end

-- 색의 이름(「원래」 포함)
function Dye.name(part: string, id: string): string
	local q = Dye.find(part, id)
	return if q then q.name else DYE.words.base
end

-- 그 곳의 고를 수 있는 색(「원래」가 맨 앞)
function Dye.choices(part: string): { string }
	local list = { Dye.BASE }
	for _, q in (if part == "point" then DYE.point else DYE.robe) do
		table.insert(list, q.id)
	end
	return list
end

-- 바꾼다(가방에서 한 개를 덜어 내는 것은 부른 쪽). → true / nil · 까닭
function Dye.apply(h, part: any, id: any): (boolean?, string?)
	if not Dye.valid(part, id) then
		return nil, DYE.words.pick
	end
	h.look = Dye.clean(h.look)
	if Dye.current(h.look, part) == id then
		return nil, DYE.words.same
	end
	h.look[part] = if id == Dye.BASE then nil else id
	return true
end

return Dye
