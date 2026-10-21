-- 수량 창의 셈(client/lune/ui/countBox.luau가 쓴다 · 자동 검사가 그대로 부른다 — 2026-10-21).
--  사용자: "잡화상점에서 물약이나 달가루 구매할때 1개 아니면 10개밖에 못사잖아 이거 수량 입력하는 모달 받아서 처리해야지 이렇게하면안되는거야 모든 곳에서 수량받아서 처리해"
--  수를 정하는 일: buy 사기 · sell 팔기 · discard 버리기 · store 맡기기 · take 찾기 · split 나누기(공방 js/lune/design/ui.js의 WORDS.ask · UILAYOUT.count)
local CountPick = {}

-- 적은 글 → 고친 글 · 그 수(비었으면 nil): 숫자만 · 맨 앞의 0은 뗀다 · hi를 넘으면 hi로(경매장의 수량 칸과 같은 셈)
function CountPick.parse(text: string, hi: number): (string, number?)
	local s = string.gsub(text, "%D", "")
	s = string.sub((string.gsub(s, "^0+", "")), 1, #tostring(math.max(1, hi)) + 1) -- 한 자리 더(넘게 적으면 최대로 — 넘는 것을 알아야 한다)
	local n = tonumber(s)
	if not n then
		return "", nil
	elseif n > hi then
		return tostring(hi), hi
	end
	return s, n
end

-- 고를 수 있는 가장 많은 수: 나누기 = 하나를 남긴 수 · 나머지 = 그 칸의 수
function CountPick.hi(kind: string, have: number): number
	return if kind == "split" then have - 1 else have
end

-- 처음 적혀 있는 수: 사기 1 · 나누기 절반 · 나머지 그 칸의 전부(메이플스토리처럼 — 제가 정한 것)
function CountPick.first(kind: string, hi: number): number
	if kind == "buy" then
		return math.min(1, hi)
	elseif kind == "split" then
		return math.max(1, math.floor((hi + 1) / 2))
	end
	return hi
end

-- 상점에서 한 번에 살 수 있는 가장 많은 수: 한 번에 파는 수(stock.max) · 가진 달돈으로 · 가방의 자리(room — 모르면 nil)
function CountPick.buyMax(stockMax: number, price: number, money: number, room: number?): number
	local n = stockMax
	if price > 0 then
		n = math.min(n, math.floor(money / price))
	end
	if room then
		n = math.min(n, room)
	end
	return math.max(0, n)
end

-- [−] · [+]: 한 칸씩(lo ~ hi 안) · 비어 있었으면 [+]는 lo · [−]는 lo
function CountPick.step(n: number?, d: number, lo: number, hi: number): number
	if not n then
		return lo
	end
	return math.clamp(n + d, lo, math.max(lo, hi))
end

return CountPick
