-- 타수 나누기(2026-10-14) — 공격 스킬의 한 타를 여러 줄(숫자 여럿)로 쪼갠다. 피해의 합은 그대로다.
--  사용자: "현재 스킬들 거의다 타수가 너무 적습니다. 동일데미지에서 타수분할을 하세요 7~8번 다다다다다 데미지가 올라오는맛이 있어야합니다.
--   극딜기의 경우 더 높은 타수가 들어가야하구요 100% 데미지로 1타가 아닌 10% 데미지로 10번 이런식이여야합니다."
--  규칙은 공방 design/combat.js의 COMBAT.lines(→ combat.generated의 rules.lines): 한 번 쓸 때 붙어 있는 적 한 마리가 받는 줄이 per(극딜기 = 큰 기술은 nuke)쯤 되게
--   타마다의 줄 수 = per ÷ (한 번 쓸 때 그 적이 맞는 타의 수)를 반올림(1 ~ max), 그래도 per - 1보다 적으면 한 줄 더. 공방의 linesFor · firstLines와 같은 셈이다(스킬 창의 글이 같은 수를 적는다).
--  쪼개는 것은 서버(sim/room.luau의 Room:strike — 피해는 한 번에 넣고 숫자만 여러 줄로 적는다), 줄을 하나씩 위로 쌓아 띄우는 것은 화면(client/lune/boot.luau의 Hits).
local root = script.Parent.Parent
local COMBAT = require(root.data["combat.generated"])

local R = COMBAT.rules.lines

local Lines = {}
Lines.R = R

-- 타마다의 줄 수. hits = 한 번 쓸 때 그 적이 맞는 타의 수(평균이어도 된다) · nuke = 극딜기
function Lines.count(hits: number, nuke: boolean?): number
	if not hits or hits <= 0 then
		return 1
	end
	local per = if nuke then R.nuke else R.per
	local L = math.clamp(math.floor(per / hits + 0.5), 1, R.max)
	if hits * L < per - 1 then
		L = math.min(R.max, L + 1) -- 반올림으로 모자라면(여섯 타 → 1줄씩 = 6) 한 줄 더: 적어도 per - 1(보통 7 · 극딜기 14)
	end
	return L
end

-- 1차의 사냥기 · 보스기: 가운데 타(범위 밖으로 번진 타 — except — 는 빼고)의 수로 정한다. 공격 스킬이 아니면 1
local first: { [string]: number } = {}
function Lines.first(id: string?): number
	if not id then
		return 1
	end
	local got = first[id]
	if got then
		return got
	end
	local def = COMBAT.skills[id]
	local n = 0
	if def and def.job == 1 and def.hits then
		for _, h in def.hits do
			if not h.except then
				n += 1
			end
		end
	end
	got = if n > 0 then Lines.count(n, false) else 1
	first[id] = got
	return got
end

-- 피해 total을 n줄로 쪼갠다(줄마다 ±jitter만큼 다르게 — 합은 꼭 total, 줄마다 1 이상). rng = 방의 Random(없으면 고르게 나눈다)
function Lines.split(total: number, n: number, rng: Random?): { number }
	n = math.clamp(math.floor(n), 1, math.max(1, math.floor(total)))
	if n == 1 then
		return { total }
	end
	local weights, sum = table.create(n), 0
	for i = 1, n do
		local w = 1 + (if rng then rng:NextNumber(-R.jitter, R.jitter) else 0)
		weights[i] = w
		sum += w
	end
	local out, given, acc = table.create(n), 0, 0
	for i = 1, n do
		acc += weights[i]
		local upto = if i == n then total else math.floor(total * acc / sum + 0.5)
		local d = math.max(1, upto - given)
		if i < n then
			d = math.min(d, total - given - (n - i)) -- 남은 줄이 1씩은 가져가게
		else
			d = total - given
		end
		out[i] = d
		given += d
	end
	return out
end

return Lines
