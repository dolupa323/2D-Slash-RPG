-- 확률 창에 적는 것(2026-11-07 — 로블록스의 확률형 아이템 규정 create.roblox.com/docs/production/monetization/paid-random-items:
--  무작위로 나오는 것은 쓰거나 사기 전에 나올 수 있는 모든 것과 그 확률(%)을 보인다 — 합이 100%. 「확률 보기」 단추로 연다).
--  그리지는 않는다: client/lune/ui/oddsWindow.luau가 그린다. 돌려주는 것 { title, head = { 글 … }, rows = { { 이름, 값, 색 } … }, foot = 글? }
--  윤슬 조각(Odds.reroll): 줄마다 아직 나오지 않은 종류 가운데 하나(같은 확률) · 값은 범위의 정수 가운데 하나(같은 확률) — 공방 js/lune/design/items.js의 oddsLines와 같은 글
--  상자(Odds.box — sim/gacha.luau): 이미 가진 것은 빠진 내 확률(사람마다 다르다 — 규정의 「한 사람이 하나만 가질 수 있는 것」)
local Items = require(script.Parent.Parent.sim.items)
local Format = require(script.Parent.format)

local Odds = {}

-- 확률(%)을 소수 넷째 자리까지(「7.1429%」)
function Odds.pct(p: number): string
	return ("%.4f%%"):format(p)
end

-- 윤슬 조각 — stage = 그 장비의 착용 레벨(줄 수 · 값의 범위가 레벨로 정해진다)
function Odds.reroll(stage: number)
	local EX = Items.EXTRA
	local W = EX.words
	local n, k = Items.exCount(stage), #EX.pool
	local head = { W.oddsCount }
	for i = 1, n do
		table.insert(head, Format.fill(W.oddsLine, { n = i, k = k - i + 1, p = ("%.4f"):format(100 / (k - i + 1)) }))
	end
	table.insert(head, W.oddsValue)
	local rows = {}
	for _, p in EX.pool do
		local lo, hi = Items.exRange(p.id, stage)
		local unit = if p.pct then "%" else ""
		table.insert(rows, { p.name, ("+%d%s ~ +%d%s"):format(lo, unit, hi, unit), "extra" })
	end
	return { title = W.oddsTitle, head = head, rows = rows, foot = Format.fill(W.oddsFoot or "", { lv = stage }) }
end

-- 뽑기 상자(2026-11-07 — sim/gacha.luau): cashView = 서버의 Cash.view(가진 펫 · 탈것 목록)
--  2026-11-10부터 가진 것도 나온다 → 확률은 모든 사람이 같다(합 100%) · 줄 = 나올 수 있는 것마다 [이름 · 확률](드문 것은 금색 · 가진 것은 이름 뒤에 「· 가진 것」을 흐리게) ·
--  머리 글 = 가진 것이 나오면 윤슬 조각 n개(드문 것 m개)로
function Odds.box(boxId: string, cashView: any)
	local Gacha = require(script.Parent.Parent.sim.gacha)
	local BM = require(script.Parent.Parent.data["bm.generated"])
	local RIDE = require(script.Parent.Parent.data["ride.generated"])
	local W = BM.shop.words
	local names = {}
	for _, list in { RIDE.pets, RIDE.mounts, (BM.bubbles and BM.bubbles.list) or {}, (BM.dskins and BM.dskins.list) or {}, (BM.nametags and BM.nametags.list) or {} } do -- (말풍선 꾸밈 — 2026-11-07 · 데미지 스킨 · 이름표 테두리 — 2026-11-10)
		for _, q in list do
			names[q.id] = q.name
		end
	end
	local boxName = boxId
	for _, p in BM.products do
		if p.id == boxId then
			boxName = p.name
		end
	end
	local owned = Gacha.ownedFromView(cashView, boxId)
	local rows = {}
	for _, e in Gacha.odds(boxId) do
		local name = names[e.id] or e.id
		table.insert(rows, { if owned[e.id] then name .. " · " .. (W.oddsBoxOwn or "") else name, Odds.pct(e.pct), if e.rare then "gold" elseif owned[e.id] then "dim" else "text" })
	end
	return { title = Format.fill(W.oddsBox or "{box}", { box = boxName }), head = { W.oddsBoxHead or "" }, rows = rows, foot = "" } -- (가진 것이 나오면 하나 더 — 2026-11-10 · 그 전의 「윤슬 조각 n개」는 뺐다)
end

return Odds
