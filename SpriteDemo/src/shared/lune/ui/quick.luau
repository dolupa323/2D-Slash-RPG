-- 퀵슬롯의 셈 — 화면 가운데 아래의 스킬 칸(여섯 x 두 줄). 그리지는 않는다: 화면(client/lune/hud.luau · boot.luau)과 서버(sim/hero.luau), 테스트가 같이 쓴다.
--  사용자 2026-10-07: "스킬키를 단축키에 등록하기 쉬워야합니다. … 드래그앤 드랍으로 배치도 되어야하고, 스킬탭에서 스킬아이콘을 꾹누르거나 클릭하면 퀵슬롯쪽이 반짝거리고 거기서 퀵슬롯을 누르면 배치된다던가"
--  키는 스킬이 아니라 칸에 붙는다(칸마다 키 하나). 칸에는 물약("potion")이나 스킬의 이름표가 놓인다. 빈 칸은 false.
--  값과 놓는 법은 공방 js/lune/design/ui.js의 QUICK · quickPlace · quickClear · quickStart(횡스크롤 시험 탭이 같은 셈으로 논다) — data/ui.generated.luau의 quick.
local UI = require(script.Parent.Parent.data["ui.generated"])

local Q = {}
Q.DATA = UI.quick
Q.N = UI.quick.n -- 칸의 수
Q.COLS = UI.quick.cols -- 한 줄
Q.POTION = "potion"

-- 칸에 놓인 것의 그림 이름(화면의 그림 24x24 — 공방의 아이콘 이름)
function Q.pic(what: string): string
	if what == Q.POTION then
		return "slot_potion"
	end
	return "skill_" .. what
end

local function copy(slots)
	local out = table.create(Q.N, false)
	for i = 1, Q.N do
		out[i] = slots[i] or false
	end
	return out
end

local function find(slots, what): number?
	for i = 1, Q.N do
		if slots[i] == what then
			return i
		end
	end
	return nil
end
Q.find = find

-- 칸에 놓는다: what(스킬의 이름표 · "potion")을 j째 칸에. 이미 다른 칸에 있던 것이면 두 칸이 자리를 바꾼다.
--  창(스킬 창 · 가방)에서 온 것이면 그 칸에 있던 것은 빠진다. 새 칸들을 돌려준다(못 놓으면 nil)
function Q.place(slots, what: string, j: number)
	if typeof(what) ~= "string" or what == "" or j < 1 or j > Q.N or j % 1 ~= 0 then
		return nil
	end
	local out = copy(slots)
	local i = find(out, what)
	if i == j then
		return out
	end
	local old = out[j]
	out[j] = what
	if i then
		out[i] = old
	end
	return out
end

-- 칸에서 뺀다(물약도 빠진다 — 가방의 소비 탭에서 다시 끌어다 놓는다)
function Q.clear(slots, i: number)
	if i < 1 or i > Q.N then
		return nil
	end
	local out = copy(slots)
	out[i] = false
	return out
end

-- 새 캐릭터의 칸: start의 차례대로(물약 · 사냥기 · 보스기 · 이동기 — 스킬은 그 갈래의 첫 스킬). skills = { { id, type } … }
function Q.start(skills)
	local out = table.create(Q.N, false)
	for k, kind in UI.quick.start do
		if kind == Q.POTION then
			out[k] = Q.POTION
		else
			for _, s in skills do
				if s.type == kind then
					out[k] = s.id
					break
				end
			end
		end
	end
	return out
end

-- 밖에서 온 칸들(클라이언트가 보낸 것 · 저장된 것)을 살핀다: 꼭 N칸, 칸마다 false · "potion" · 놓아도 되는 스킬(ok(id)가 참), 겹치는 것 없이(물약도 한 칸까지 — 없어도 된다).
--  말이 되면 깨끗한 칸들을, 아니면 nil을 돌려준다
function Q.clean(list: any, ok: (string) -> boolean)
	if typeof(list) ~= "table" then
		return nil
	end
	local out = table.create(Q.N, false)
	local seen = {}
	local potions = 0
	for k in list do
		if typeof(k) ~= "number" or k < 1 or k > Q.N or k % 1 ~= 0 then
			return nil
		end
	end
	for i = 1, Q.N do
		local v = list[i]
		if v == nil or v == false then
			out[i] = false
		elseif typeof(v) == "string" and #v <= 40 and not seen[v] and (v == Q.POTION or ok(v)) then
			seen[v] = true
			out[i] = v
			if v == Q.POTION then
				potions += 1
			end
		else
			return nil
		end
	end
	if potions > 1 then
		return nil
	end
	return out
end

-- 윗줄(둘째 줄)에 놓인 것이 있는가 — 있으면 윗줄도 늘 보인다
function Q.usesTop(slots): boolean
	for i = Q.COLS + 1, Q.N do
		if slots[i] then
			return true
		end
	end
	return false
end

return Q
