-- 달빛 패스의 셈(2026-10-20) — 화면 없이 돈다(서버 · 테스트가 같이 쓴다). 설계 = 공방 js/lune/design/bm.js의 BM_PASS(bm.generated의 pass).
--  사용자 2026-10-20: "달빛패스에 자동줍기는 아니에요 줍기는 펫의 기능이에요" · "달빛 패스도 개발자 상품에 등록해야해요" ·
--   "근데 달빛패스에 시즌이라는 개념이 필요가 없잖아" → 산 때부터 days일(30). 모두가 같이 쓰는 시즌 · 무료 아랫줄은 없다.
--  그 30일 동안 놀면 「달빛」이 쌓이고 per마다 칸이 하나 열린다(steps칸 · 하루 dayCap까지 — 하루는 한국 시각 0시에 바뀐다). 칸마다 보상.
--  30일이 지나도 연 칸의 보상은 받을 수 있다(다시 사면 받지 않은 것을 먼저 보관함에 넣고 — sim/cash.luau — 새 30일).
--  계정의 것(acct.bm.pass — 저장은 sim/cash.luau의 Cash.pack이 함께):
--   ends = 패스가 끝나는 때(os.time · 0 = 산 적 없음) · pts = 이번 패스의 달빛 · day · dayPts = 오늘(한국 날짜)과 오늘 얻은 달빛 ·
--   kills = 다음 「몬스터 n마리」까지 센 수 · p = 받은 칸 { [칸] = true } · n = 산 번수
local lune = script.Parent.Parent
local D = require(lune.data["bm.generated"]).pass

local Pass = {}
Pass.DATA = D
local DAY = 86400

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0 and v >= lo and v <= hi
end
local function dayOf(now: number): number
	return math.floor((now + D.offset * 3600) / DAY)
end

function Pass.new()
	return { ends = 0, pts = 0, day = 0, dayPts = 0, kills = 0, p = {}, n = 0 }
end

function Pass.active(ps, now: number): boolean
	return now < ps.ends
end
-- 남은 날(올림 — 마지막 날이면 1) · 패스가 없으면 0
function Pass.left(ps, now: number): number
	return if Pass.active(ps, now) then math.ceil((ps.ends - now) / DAY) else 0
end

-- 달빛을 얻는다(패스가 있는 동안 · 하루 상한까지) → 얻은 수
local function gain(ps, n: number, now: number): number
	local d = dayOf(now)
	if ps.day ~= d then
		ps.day, ps.dayPts = d, 0
	end
	local add = math.max(0, math.min(n, D.dayCap - ps.dayPts, D.steps * D.per - ps.pts))
	ps.pts += add
	ps.dayPts += add
	return add
end

-- 한 일을 알린다: "daily" 일일 의뢰 하나 · "attend" 출석 · "rift" 토벌 한 번 · "kill"(n마리 — killEach마다 달빛) → 얻은 달빛(패스가 없으면 0)
function Pass.add(ps, key: string, now: number, n: number?): number
	if not Pass.active(ps, now) then
		return 0
	end
	if key == "kill" then
		ps.kills += n or 1
		local got = 0
		while ps.kills >= D.killEach do
			ps.kills -= D.killEach
			got += gain(ps, D.gain.kill, now)
		end
		return got
	end
	local g = D.gain[key]
	return if g then gain(ps, g, now) else 0
end

function Pass.reached(ps): number
	return math.min(D.steps, ps.pts // D.per)
end

-- 받을 수 있는 칸들 { { step, kind, n } } — 연 칸까지 · 아직 받지 않은 것(패스가 끝난 뒤에도 — 다시 살 때까지)
function Pass.ready(ps)
	local out = {}
	for step = 1, Pass.reached(ps) do
		if not ps.p[step] then
			local pd = D.paid[step]
			table.insert(out, { step = step, kind = pd[1], n = pd[2] })
		end
	end
	return out
end

-- 보상 하나의 아이템: potion = 받는 캐릭터의 레벨의 물약(potionId) · scroll = 귀환 주문서 · exp = 경험치 쿠폰 · money · dust = 레벨대(band)의 주머니 · 상자
function Pass.itemOf(kind: string, potionId: string, band: number): string
	if kind == "potion" then
		return potionId
	elseif kind == "scroll" then
		return "scroll_return"
	elseif kind == "exp" then
		return "bm_exp"
	end
	return ("bm_%s_%d"):format(kind, band)
end

-- 받을 수 있는 것을 모두 받았다고 적는다 → 줄 아이템 { { id, n } } (보관함에 넣는 것은 부른 쪽 — sim/cash.luau)
function Pass.claim(ps, potionId: string, band: number)
	local gifts = {}
	for _, r in Pass.ready(ps) do
		ps.p[r.step] = true
		table.insert(gifts, { id = Pass.itemOf(r.kind, potionId, band), n = r.n })
	end
	return gifts
end

-- 패스를 샀다: 새 30일(달빛 · 받은 칸을 비운다 — 받지 않은 것은 부른 쪽이 먼저 Pass.claim으로 보관함에).
--  아직 패스가 있는데 결제가 또 왔으면(구매 창을 띄운 뒤에 다른 곳에서 산 경우) 끝나는 때만 30일 늘린다 — 받은 돈은 반드시 준다
function Pass.buy(ps, now: number)
	ps.n += 1
	if Pass.active(ps, now) then
		ps.ends += D.days * DAY
		return
	end
	ps.ends = now + D.days * DAY
	ps.pts, ps.kills, ps.p = 0, 0, {}
	ps.day, ps.dayPts = dayOf(now), 0
end

-- 화면에 보내는 것
function Pass.view(ps, now: number)
	local p = {}
	for k in ps.p do
		table.insert(p, k)
	end
	local d = dayOf(now)
	return {
		active = Pass.active(ps, now),
		left = Pass.left(ps, now),
		ended = ps.ends > 0 and not Pass.active(ps, now),
		pts = ps.pts,
		today = if ps.day == d and Pass.active(ps, now) then ps.dayPts else 0,
		reached = Pass.reached(ps),
		p = p,
		ready = #Pass.ready(ps),
	}
end

-- ---------- 저장 ----------
function Pass.pack(ps)
	local p = {}
	for k in ps.p do
		table.insert(p, k)
	end
	table.sort(p)
	return { ends = ps.ends, pts = ps.pts, day = ps.day, dayPts = ps.dayPts, kills = ps.kills, p = p, n = ps.n }
end
function Pass.unpack(data: any)
	local ps = Pass.new()
	if typeof(data) ~= "table" then
		return ps
	end
	ps.ends = if whole(data.ends, 0, 1e11) then data.ends else 0
	ps.pts = if whole(data.pts, 0, D.steps * D.per) then data.pts else 0
	ps.day = if whole(data.day, 0, 1e7) then data.day else 0
	ps.dayPts = if whole(data.dayPts, 0, D.dayCap) then data.dayPts else 0
	ps.kills = if whole(data.kills, 0, D.killEach) then data.kills else 0
	ps.n = if whole(data.n, 0, 1e6) then data.n else 0
	if typeof(data.p) == "table" then
		for _, st in data.p do
			if whole(st, 1, D.steps) then
				ps.p[st] = true
			end
		end
	end
	return ps
end

return Pass
