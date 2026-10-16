-- 출석 보상의 셈 — 계정에 하루 한 칸, 한 달에 28칸(공방 js/lune/design/attend.js — 2026-10-15 · 사용자: "출석보상, 업적 만들어야합니다"; 판 · 수 · 보상은 제 제안).
--  계정의 표 acct.att = { m = 그 판의 달(연*100 + 월 · 한국 시간), n = 찬 칸, got = 받은 칸(앞에서부터), last = 마지막으로 찬 날(날 번호), total = 지금까지 출석한 날 }
--  그날 처음 캐릭터로 들어오면(어느 캐릭터든) 칸이 하나 찬다(checkIn). 「받기」 = 받지 않은 칸을 앞에서부터 모두(claim) — 가방이 차면 거기서 멈춘다.
--  달이 바뀌면 새 판(받지 않은 칸은 사라진다). 하루 · 달은 한국 시간(세계 표준시 +9)으로 센다 — 일일 의뢰와 같다.
local D = require(script.Parent.Parent.data["attend.generated"])
local Gift = require(script.Parent.gift)

local Attend = {}
Attend.DATA = D
Attend.WORDS = D.words

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

-- 날 번호(한국 시간의 자정마다 하나씩)
function Attend.dayOf(now: number): number
	return math.floor((now + D.offset * 3600) / 86400)
end

-- 달(연*100 + 월 · 한국 시간)
function Attend.monthOf(now: number): number
	local t = os.date("!*t", math.floor(now + D.offset * 3600)) :: any
	return t.year * 100 + t.month
end

function Attend.new()
	return { m = 0, n = 0, got = 0, last = -1, total = 0 }
end

function Attend.pack(t)
	return { m = t.m, n = t.n, got = t.got, last = t.last, total = t.total }
end

-- 저장된 것(없거나 꼴이 이상하면 새 판)
function Attend.unpack(v: any)
	local t = Attend.new()
	if typeof(v) ~= "table" then
		return t
	end
	t.m = if whole(v.m, 0, 999912) then v.m else 0
	t.n = if whole(v.n, 0, D.days) then v.n else 0
	t.got = if whole(v.got, 0, t.n) then v.got else 0
	t.last = if whole(v.last, -1, 1e7) then v.last else -1
	t.total = if whole(v.total, 0, 1e6) then v.total else 0
	return t
end

-- 오늘 처음이면 칸을 채운다(달이 바뀌었으면 새 판부터). 새로 찼으면 true
function Attend.checkIn(t, now: number): boolean
	local day = Attend.dayOf(now)
	if t.last == day then
		return false
	end
	local m = Attend.monthOf(now)
	if t.m ~= m then
		t.m, t.n, t.got = m, 0, 0
	end
	t.last = day
	if t.n < D.days then
		t.n += 1
	end
	t.total += 1
	return true
end

-- 받을 칸의 수
function Attend.ready(t): number
	return t.n - t.got
end

-- 받지 않은 칸을 앞에서부터 모두 받는다. 받은 칸의 수와(가방이 차서 멈췄으면) 까닭
function Attend.claim(t, h): (number, string?)
	local claimed = 0
	while t.got < t.n do
		local ok, why = Gift.give(h, D.rewards[t.got + 1])
		if not ok then
			return claimed, why
		end
		t.got += 1
		claimed += 1
	end
	return claimed, nil
end

-- 화면에 보내는 것: 그 판의 달(월) · 찬 칸 · 받은 칸 · 오늘 찼는가
function Attend.view(t, now: number)
	return { month = t.m % 100, n = t.n, got = t.got, days = D.days, today = t.last == Attend.dayOf(now) }
end

return Attend
