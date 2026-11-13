-- 룬 · 별똥별 조각의 셈(공방 js/lune/design/rune.js · 2026-11-07 사용자: "메이플 룬을 답습해서 만들자 미끼두는 방식도 채용하자 누가봐도 먹어야되게 보이는 별똥별 조각이 떨어지고
--  그걸 안먹는 걸 로그나 정보로 수집해서 매크로 위험수치를 판단할수있게"). 화면도 서버도 모르는 순수한 셈 — server/lune/modules/runeGuard.luau가 부르고 시험(136)이 직접 돌린다.
--  맵(m) = { huntSince 사냥이 이어진 처음 때 · lastKill 마지막 처치 · rune { x, y, born, id } | nil · nextId }
--  사람(p) = { cdUntil 다음 룬을 풀 수 있는 때 · guardUntil 다른 맵의 저주를 받지 않는 때 · buffUntil 경험치가 오르는 때 · try { arrows, deadline, map } | nil · retryAt
--             · bait { nextAt, cur { id, x, y, untilAt } | nil, nextId } }
--  별똥별의 기록(stat — 매크로 확인의 st.bait) = { shown = { 때 … }, got = { 때 … }, missed = { 때 … } }
--  시각 now = os.time()(초)
local D = require(script.Parent.Parent.data["rune.generated"])

local Rune = {}
Rune.DATA = D
local R, B = D.rune, D.bait

-- ---------- 룬(맵마다) ----------
function Rune.newMap()
	return { huntSince = nil :: number?, lastKill = nil :: number?, rune = nil, nextId = 1 }
end
--  h = 룬을 푼 뒤(또는 처음부터) 사냥한 초 — own초가 되면 그 사람이 선 사냥 맵에 룬이 없으면 바로 나온다(2026-11-13 · server runeGuard.luau가 쌓고 계정에 남긴다)
function Rune.newPlayer()
	return { cdUntil = 0, guardUntil = 0, buffUntil = 0, h = 0, try = nil, retryAt = 0, bait = { nextAt = nil :: number?, cur = nil, nextId = 1 } }
end
-- 그 사람 몫의 룬(2026-11-13 사용자: "룬한번 사람이 까버리고 가호 받은상태에서 15분 매크로 돌려버리고 15분 끝나기전에 게임 껐다가 다시들어와서"):
--  룬을 푼 뒤 own초 넘게 사냥했는데 지금 선 맵에 룬이 없다 → 그 맵에 바로 나올 때인가(맵의 룬은 맵마다라 채널 · 서버를 옮기면 처음부터였다)
function Rune.owes(m, p): boolean
	return m ~= nil and m.rune == nil and p ~= nil and (p.h or 0) >= R.own
end
-- 룬을 그 자리에 놓는다(Rune.tick이 고른 때가 아닌 때 — 위 Rune.owes)
function Rune.place(m, now: number, x: number, y: number)
	m.rune = { x = x, y = y, born = now, id = m.nextId }
	m.nextId += 1
end

-- 그 맵에서 잡았다: 사냥이 끊겼으면(B.hunt.window초 넘게 처치가 없었다) 사냥 시계를 지금부터
function Rune.onKill(m, now: number)
	if not m.huntSince or not m.lastKill or now - m.lastKill > B.hunt.window then
		m.huntSince = now
	end
	m.lastKill = now
end

-- 룬이 나올 때가 됐나(룬이 없고 · appear초 동안 사냥이 이어졌다). spot() → x, y(땅 위의 자리 — 없으면 nil)
function Rune.tick(m, now: number, spot: () -> (number?, number?)): boolean
	if m.rune or not m.huntSince or not m.lastKill or now - m.lastKill > B.hunt.window then
		if m.lastKill and now - m.lastKill > B.hunt.window then
			m.huntSince = nil -- 사냥이 끊겼다 — 다음 처치부터 다시 잰다
		end
		return false
	end
	if now - m.huntSince < R.appear then
		return false
	end
	local x, y = spot()
	if not x or not y then
		return false
	end
	m.rune = { x = x, y = y, born = now, id = m.nextId }
	m.nextId += 1
	return true
end

-- 저주의 단계(0 = 없다): 룬이 나온 뒤 after초부터 1단계 · every초마다 하나씩 · 가장 높은 단계까지
function Rune.stage(m, now: number): number
	local r = m.rune
	if not r then
		return 0
	end
	local over = now - r.born - R.curse.after
	if over < 0 then
		return 0
	end
	return math.min(#R.curse.cut, 1 + math.floor(over / R.curse.every))
end
-- 그 사람의 저주 단계(2026-11-12 사용자: "다른사람이 룬의저주를 만든자리를 그 대상자가 아닌사람이 들어갔다가 나오면 룬의 저주가 걸려버려 … 사냥터가 기준이아니라 그 유저가 기준인거야"):
--  n = 그 사람이 룬이 나와 있는 사냥 맵에서 사냥하며 룬을 두고 지나간 초(server runeGuard가 쌓는다) → 0 = 없다 · after초부터 1단계 · every초마다 하나씩(맵의 셈 Rune.stage와 같은 숫자)
function Rune.stageOf(n: number): number
	local over = n - R.curse.after
	if over < 0 then
		return 0
	end
	return math.min(#R.curse.cut, 1 + math.floor(over / R.curse.every))
end
-- 그 맵에서 그 사람이 덜 받는 몫(0 ~ 1): 가호가 있으면 0
function Rune.cutFor(m, p, now: number): number
	if p and p.guardUntil > now then
		return 0
	end
	local s = Rune.stage(m, now)
	return if s > 0 then R.curse.cut[s] else 0
end
-- 경험치에 곱하는 배율(룬의 힘 — 해방한 뒤 buff.time초)
function Rune.xpMul(p, now: number): number
	return if p and p.buffUntil > now then 1 + R.buff.xp else 1
end

-- 해방을 시작한다(↑ — 룬 곁에서). 돌려주는 것: 화살표들(서버가 고른다) | nil, 까닭("none" · "far" · "cool" · "wait")
function Rune.start(m, p, now: number, x: number, y: number, rnd: (number) -> number)
	local r = m.rune
	if not r then
		return nil, "none"
	end
	if math.abs(x - r.x) > R.reach.x or math.abs(y - r.y) > R.reach.y then
		return nil, "far"
	end
	if p.cdUntil > now then
		return nil, "cool"
	end
	if p.retryAt > now then
		return nil, "wait"
	end
	local arrows = {}
	for i = 1, R.keys do
		arrows[i] = R.arrows[rnd(#R.arrows)]
	end
	p.try = { arrows = arrows, deadline = now + R.time, rune = r.id }
	return arrows, nil
end

-- 누른 화살표들의 대답. 돌려주는 것: "done"(해방) · "wrong" · "late" · "none"(풀 것이 없다 — 다른 사람이 먼저 풀었다)
function Rune.answer(m, p, keys: any, now: number): string
	local t = p.try
	p.try = nil
	if not t then
		return "none"
	end
	if not m.rune or m.rune.id ~= t.rune then
		return "none"
	end
	if now > t.deadline then
		p.retryAt = now + R.retry
		return "late"
	end
	if typeof(keys) ~= "table" or #keys ~= #t.arrows then
		p.retryAt = now + R.retry
		return "wrong"
	end
	for i, a in t.arrows do
		if keys[i] ~= a then
			p.retryAt = now + R.retry
			return "wrong"
		end
	end
	m.rune = nil
	m.huntSince = now -- 다음 룬은 다시 appear초 사냥한 뒤
	p.buffUntil = now + R.buff.time
	p.cdUntil = now + R.cooldown
	p.guardUntil = now + R.guard
	p.h = 0 -- 그 사람 몫의 다음 룬은 다시 own초 사냥한 뒤(2026-11-13)
	return "done"
end

-- 화면에 보낼 맵의 모습(룬의 자리 · 저주 단계)
function Rune.mapView(m, now: number)
	local r = m.rune
	return { rune = if r then { x = r.x, y = r.y, id = r.id } else nil, stage = Rune.stage(m, now) }
end

-- ---------- 별똥별 조각(사람마다) ----------
local function pushTime(list: { number }, now: number)
	table.insert(list, now)
	while list[1] and now - list[1] > B.window do
		table.remove(list, 1)
	end
end
function Rune.newStat()
	return { shown = {}, got = {}, missed = {} }
end

-- 1초마다: 떨어뜨릴 때인가 · 떠 있던 것이 사라졌나. hunting = 지금 사냥 중(지난 B.hunt.window초 안에 B.hunt.kills마리 넘게). 돌려주는 것: "drop" · "miss" · nil
function Rune.baitTick(p, stat, now: number, hunting: boolean, rnd: (number, number) -> number): string?
	local b = p.bait
	if b.cur then
		if now > b.cur.untilAt then
			b.cur = nil
			pushTime(stat.missed, now)
			return "miss"
		end
		return nil
	end
	if not hunting then
		return nil
	end
	if not b.nextAt then
		b.nextAt = now + rnd(B.every[1], B.every[2])
		return nil
	end
	if now >= b.nextAt then
		b.nextAt = now + rnd(B.every[1], B.every[2])
		return "drop"
	end
	return nil
end
-- 떨어뜨린다(서버가 자리를 정한 뒤). route = 그 사람이 다니던 길 위(주워도 사람의 증거로 치지 않는다 — 2026-11-13)
function Rune.baitDrop(p, stat, now: number, x: number, y: number, route: boolean?)
	local b = p.bait
	b.cur = { id = b.nextId, x = x, y = y, untilAt = now + B.life, route = route == true }
	b.nextId += 1
	pushTime(stat.shown, now)
	return b.cur
end
-- 몸이 닿았다(서버의 내 자리로 잰다): 주웠나
function Rune.baitPick(p, stat, now: number, id: any, x: number, y: number): boolean
	local c = p.bait.cur
	if not c or c.id ~= id or now > c.untilAt then
		return false
	end
	if math.abs(x - c.x) > 16 or math.abs(y - c.y) > 28 then
		return false
	end
	p.bait.cur = nil
	pushTime(stat.got, now)
	return true
end
-- 매크로 의심(매크로 확인의 Macro.level이 쓴다): 지난 window초 동안 하나도 줍지 않고 놓친 수가 high · mid 넘으면
function Rune.baitLevel(stat, now: number): string?
	if not stat then
		return nil
	end
	local function count(list)
		local n = 0
		for _, t in list do
			if now - t <= B.window then
				n += 1
			end
		end
		return n
	end
	if count(stat.got) > 0 then
		return nil
	end
	local miss = count(stat.missed)
	if miss >= B.high then
		return "high"
	elseif miss >= B.mid then
		return "mid"
	end
	return nil
end
-- 관리 창의 「매크로」 탭에 적는 것(지난 window초): 주운 수 · 떨어진 수
function Rune.baitCounts(stat, now: number): (number, number)
	if not stat then
		return 0, 0
	end
	local got, shown = 0, 0
	for _, t in stat.got do
		if now - t <= B.window then
			got += 1
		end
	end
	for _, t in stat.shown do
		if now - t <= B.window then
			shown += 1
		end
	end
	return got, shown
end

return Rune
