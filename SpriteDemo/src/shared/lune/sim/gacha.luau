-- 뽑기 상자(2026-11-07 — 공방 js/lune/design/bm.js의 BM_BOX · 달빛 상점의 「윤슬 펫 상자」 · 「윤슬 탈것 상자」) — 화면 없이 도는 셈(서버 · 화면 · 테스트가 같이 쓴다).
--  사용자: "펫을 랜덤 뽑기형식으로 변경해서 지금있는 로벅스 펫들도 포함해서 … 엄청이쁜 펫은 확률이 낮게" · "새로운 라이딩 뽑기 상자를 만들고 … 엄청 이쁘고 멋지고 화려한 라이딩만 확률 낮게"
--  로블록스의 확률형 아이템 규정(create.roblox.com/docs/production/monetization/paid-random-items):
--   · 사기 전에 나올 수 있는 모든 것과 그 확률(%)을 보인다 — 합 100%(화면의 「확률 보기」 = shared/lune/ui/odds.luau의 Odds.box가 이 셈을 쓴다)
--   · (2026-11-10까지) 가진 것을 뺀 확률이었다 → 지금은 모든 사람이 같은 확률 · 가진 것이 나오면 같은 것을 하나 더(sim/cash.luau의 Cash.count)
--  owned = { [이름] = true }(계정의 pets · mounts — sim/cash.luau)
local D = require(script.Parent.Parent.data["bm.generated"])

local Gacha = {}
Gacha.BOXES = D.boxes or {}

function Gacha.box(id: any)
	return if typeof(id) == "string" then Gacha.BOXES[id] else nil
end

-- 그 상자의 확률: { { id, pct(%), rare } … }(합 100 · 모든 사람이 같다) — 공방 bm.js의 boxOdds와 같은 셈
--  2026-11-10 사용자 "중복도 나올수있게해줘 지금 가챠인데 이미가진건 안나오면 뭐의미가 없어" → 가진 것도 나온다(owned는 이제 쓰지 않는다 — 전에는 가진 것을 빼고 남은 것끼리 나눴다).
--   가진 것이 나오면 같은 것을 하나 더 준다(가진 수가 는다 — sim/cash.luau · 2026-11-10 사용자가 고른 것 「같은 것을 하나 더 준다」. 그 전에는 윤슬 조각 2 · 5개로 바꿨다)
function Gacha.odds(id: any, _owned: any?): { any }
	local b = Gacha.box(id)
	local out = {}
	if not b then
		return out
	end
	local sum = 0
	for _, e in b.pool do
		sum += e[2]
	end
	if sum <= 0 then
		return out
	end
	for _, e in b.pool do
		table.insert(out, { id = e[1], pct = e[2] / sum * 100, rare = table.find(b.rare or {}, e[1]) ~= nil })
	end
	return out
end

-- 아직 나올 수 있는 것의 수
function Gacha.left(id: any, owned: any?): number
	return #Gacha.odds(id, owned)
end

-- 연다: 나온 것의 이름(남은 것이 없으면 nil)
function Gacha.roll(id: any, owned: any?, rng: any?): string?
	local list = Gacha.odds(id, owned)
	if #list == 0 then
		return nil
	end
	local r = (rng or Random.new()):NextNumber(0, 100)
	local acc = 0
	for _, e in list do
		acc += e.pct
		if r < acc then
			return e.id
		end
	end
	return list[#list].id
end

-- 그 상자가 보는 「가진 것」(계정의 bm — 펫 상자 = pets · 탈것 상자 = mounts)
function Gacha.ownedOf(c, id: any)
	local b = Gacha.box(id)
	if not b or typeof(c) ~= "table" then
		return {}
	end
	return (if b.kind == "pet" then c.pets elseif b.kind == "bubble" then c.bubbles elseif b.kind == "dskin" then c.dskins elseif b.kind == "ntag" then c.ntags else c.mounts) or {} -- (bubble = 말풍선 상자 — 2026-11-07 · dskin · ntag = 데미지 스킨 · 이름표 테두리 상자 — 2026-11-10)
end

-- 화면이 받은 것(Cash.view의 pets · mounts 목록)에서 가진 것의 표
function Gacha.ownedFromView(view, id: any)
	local b = Gacha.box(id)
	local out = {}
	if not b or typeof(view) ~= "table" then
		return out
	end
	for _, name in (if b.kind == "pet" then view.pets elseif b.kind == "bubble" then view.bubbles elseif b.kind == "dskin" then view.dskins elseif b.kind == "ntag" then view.ntags else view.mounts) or {} do
		out[name] = true
	end
	return out
end

return Gacha
