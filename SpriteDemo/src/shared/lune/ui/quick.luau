-- 퀵슬롯의 셈 — 화면 가운데 아래의 스킬 칸(여섯 x 두 줄). 그리지는 않는다: 화면(client/lune/hud.luau · boot.luau)과 서버(sim/hero.luau), 테스트가 같이 쓴다.
--  사용자 2026-10-07: "스킬키를 단축키에 등록하기 쉬워야합니다. … 드래그앤 드랍으로 배치도 되어야하고, 스킬탭에서 스킬아이콘을 꾹누르거나 클릭하면 퀵슬롯쪽이 반짝거리고 거기서 퀵슬롯을 누르면 배치된다던가"
--  키는 스킬이 아니라 칸에 붙는다(칸마다 키 하나). 칸에는 스킬의 이름표나 소비 아이템의 이름표("potion1" … — data/items.generated.luau의 GOODS)가 놓인다. 빈 칸은 false.
--   소비 아이템은 저마다 따로 놓는다(사용자 2026-10-08 — 가방의 진짜 아이템이다): 작은 달빛 물약과 큰 달빛 물약은 다른 칸. 칸의 숫자 = 가방에 든 그 아이템의 수.
--  값과 놓는 법은 공방 js/lune/design/ui.js의 QUICK · quickPlace · quickClear · quickStart(횡스크롤 시험 탭이 같은 셈으로 논다) — data/ui.generated.luau의 quick.
local UI = require(script.Parent.Parent.data["ui.generated"])
local ITEMS = require(script.Parent.Parent.data["items.generated"])

local GOODS = {}
for _, g in ITEMS.GOODS do
	GOODS[g.id] = g
end

local Q = {}
Q.DATA = UI.quick
Q.N = UI.quick.n -- 칸의 수
Q.COLS = UI.quick.cols -- 한 줄
Q.START_POTION = UI.quick.potion -- 새 캐릭터의 첫 칸에 놓이는 물약(작은 달빛 물약)
Q.OLD_POTION = "potion" -- 예전 저장의 물약 칸(물약이 한 가지였을 때의 이름표) — Q.renew가 지금의 이름표로 바꾼다

-- 칸에 놓인 것이 소비 아이템이면 그 자료(스킬이면 nil)
function Q.item(what: any)
	return if typeof(what) == "string" then GOODS[what] else nil
end

-- 칸에 놓인 것이 펫 · 탈것이면 "pet" · "mount"(2026-10-21 사용자: 가방의 캐시 탭에서 꺼내기 · 타기 — 퀵슬롯에 놓으면 그 키로 꺼내고 넣고 타고 내린다)
function Q.ride(what: any): string?
	if typeof(what) ~= "string" then
		return nil
	end
	if string.sub(what, 1, 4) == "pet_" then
		return "pet"
	elseif string.sub(what, 1, 6) == "mount_" then
		return "mount"
	end
	return nil
end

-- 칸에 놓인 것의 그림 이름(화면의 그림 24x24 — 공방의 아이콘 이름)
function Q.pic(what: string): string
	local g = GOODS[what]
	if g then
		return g.icon
	end
	if Q.ride(what) then
		return "ride_" .. what -- 펫 · 탈것의 그림(달빛 상점의 것과 같다)
	end
	return "skill_" .. what
end

-- 예전 저장의 칸들을 지금 꼴로: "potion" → potionId(그때 마시던 물약). 꼴이 다른 것은 그대로 돌려준다(Q.clean이 걸러 낸다)
function Q.renew(list: any, potionId: string): any
	if typeof(list) ~= "table" then
		return list
	end
	local out = table.clone(list)
	for k, v in out do
		if v == Q.OLD_POTION then
			out[k] = potionId
		end
	end
	return out
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

-- 칸에 놓는다: what(스킬 · 소비 아이템의 이름표)을 j째 칸에. 이미 다른 칸에 있던 것이면 두 칸이 자리를 바꾼다.
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

-- 칸에서 뺀다(소비 아이템도 빠진다 — 가방의 소비 탭에서 다시 끌어다 놓는다)
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
		if kind == "potion" then
			out[k] = Q.START_POTION
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

-- 스마트폰의 단추 배치. 단추가 있는 칸은 Q.TOUCH뿐이다(공방 basics.js의 TOUCH —
--  사용자 2026-10-13(폰에서 해 보고): "모바일에서 상호작용 버튼 아래에 있는 버튼 없애고" → 칸 1의 단추가 없어졌다. 칸 2 ~ 12의 열하나).
--  단추가 없는 칸에 놓인 것은 단추가 있는 첫 빈 칸으로 옮긴다(빈 칸이 없으면 뺀다) — 새 캐릭터의 물약은 칸 5로, 전에 칸 1에 놓아 둔 것도 들어올 때 옮겨진다.
--  공방 js/lune/design/ui.js의 quickTouchFix와 같은 셈(data/ui.generated.luau의 quick.touchCheck로 맞춰 본다)
Q.TOUCH = UI.quick.touch
local hasTouch = {}
for _, i in Q.TOUCH do
	hasTouch[i] = true
end
function Q.touchFix(slots)
	local out = copy(slots)
	for k = 1, Q.N do
		if not hasTouch[k] and out[k] then
			for _, j in Q.TOUCH do
				if not out[j] then
					out[j] = out[k]
					break
				end
			end
			out[k] = false
		end
	end
	return out
end
-- 새 캐릭터의 스마트폰 배치: 처음 차림(Q.start)에서 단추가 없는 칸의 것을 옮긴 것
function Q.touchStart(skills)
	return Q.touchFix(Q.start(skills))
end

-- 밖에서 온 칸들(클라이언트가 보낸 것 · 저장된 것)을 살핀다: 꼭 N칸, 칸마다 false · 놓아도 되는 것(ok(id)가 참 — 배운 스킬 · 소비 아이템), 겹치는 것 없이.
--  말이 되면 깨끗한 칸들을, 아니면 nil을 돌려준다
function Q.clean(list: any, ok: (string) -> boolean)
	if typeof(list) ~= "table" then
		return nil
	end
	local out = table.create(Q.N, false)
	local seen = {}
	for k in list do
		if typeof(k) ~= "number" or k < 1 or k > Q.N or k % 1 ~= 0 then
			return nil
		end
	end
	for i = 1, Q.N do
		local v = list[i]
		if v == nil or v == false then
			out[i] = false
		elseif typeof(v) == "string" and #v <= 40 and not seen[v] and ok(v) then
			seen[v] = true
			out[i] = v
		else
			return nil
		end
	end
	return out
end

-- 윗줄(둘째 줄)에 놓인 것이 있는가 — 있으면 윗줄도 늘 보인다
function Q.usesTop(slots): boolean
	for _, i in UI.quick.rows[2] do -- 윗줄의 칸(2026-10-21 — 번호가 아니라 줄의 표로: 새 칸 14는 윗줄 끝)
		if slots[i] then
			return true
		end
	end
	return false
end

return Q
