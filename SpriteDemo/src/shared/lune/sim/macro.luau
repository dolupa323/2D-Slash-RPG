-- 매크로 확인의 셈(공방 js/lune/design/macro.js · 2026-10-23 사용자: "현재 게임에서 매크로 유저들이 많아 어떻게 잡을지 해결해봐").
--  서버가 재고(처치 · 움직인 칸 · 스킬을 누른 간격) 서버가 문제를 내고 채점한다. 화면도 서버도 모르는 순수한 셈이다(server/lune/modules/macroGuard.luau가 부른다).
--  st(세션마다) = { born 접속한 때 · rest 쉬지 않은 사냥이 시작된 때 · kills 처치한 때들 · moves[칸] = 마지막으로 선 때 · gaps 같은 스킬을 다시 누른 간격들(초) · last[스킬] = 누른 때(os.clock)
--                  · draw 이번 차례의 0~1(언제 띄울지) · check 떠 있는 문제 · passAt 마지막으로 통과한 때 · force 관리자가 보냄
--                  · saved = 계정에 남는 것 { fails = 놓친 때들 · stopped 보상 멈춤 · stopUntil 이때부터 다시 확인할 수 있다 · pending 문제가 떠 있는 채 나갔다 } }
--  시각: now = os.time()(초) · 스킬 간격만 os.clock()(소수 초)
local D = require(script.Parent.Parent.data["macro.generated"])

local Macro = {}
Macro.DATA = D

local function nums(list: any): { number }
	local out = {}
	if typeof(list) == "table" then
		for _, v in list do
			if typeof(v) == "number" then
				table.insert(out, v)
			end
		end
	end
	return out
end

-- 계정에 남는 것(Account.pack · unpack)
function Macro.newSaved()
	return { fails = {}, stopped = false, stopUntil = 0, pending = false }
end
function Macro.unpack(raw: any)
	local m = Macro.newSaved()
	if typeof(raw) == "table" then
		m.fails = nums(raw.fails)
		m.stopped = raw.stopped == true
		m.stopUntil = if typeof(raw.stopUntil) == "number" then raw.stopUntil else 0
		m.pending = raw.pending == true
	end
	return m
end
function Macro.pack(m)
	return { fails = table.clone(m.fails), stopped = m.stopped or nil, stopUntil = if m.stopUntil > 0 then m.stopUntil else nil, pending = m.pending or nil }
end

function Macro.new(now: number, saved)
	return { born = now, rest = now, kills = {}, moves = {}, gaps = {}, last = {}, draw = nil :: number?, check = nil, passAt = 0, force = false, saved = saved or Macro.newSaved() }
end

-- 지난 sec초 동안의 처치 수
local function killsIn(st, now: number, sec: number): number
	local n = 0
	for i = #st.kills, 1, -1 do
		if now - st.kills[i] > sec then
			break
		end
		n += 1
	end
	return n
end

function Macro.onKill(st, now: number)
	local prev = st.kills[#st.kills]
	if prev == nil or now - prev >= D.rest then
		st.rest = now -- 한참 쉬다가 다시 잡기 시작했다
	end
	table.insert(st.kills, now)
	local keep = math.max(D.hunt.window, D.suspect.still.window)
	while #st.kills > 0 and now - st.kills[1] > keep do
		table.remove(st.kills, 1)
	end
end

-- 마을 · 실내에 들렀다: 그곳에 Macro.REST_STAY초 넘게 머물러야 「쉼」(2026-10-24 — 전에는 들르기만 해도 쉼이라, 마을을 잠깐 오가는 매크로는 확인이 뜨기 전에 시계가 0으로 돌아갔다)
--  같은 날 120 → 600초(10분 — 사용자 "매크로 완전히 파훼할수있어야해": 몇 분마다 마을에 2분씩 들르는 매크로도 확인을 피했다. 제가 정한 것)
Macro.REST_STAY = 600

-- 게임 창이 앞에 없는데 들어온 스킬(2026-10-24): Macro.BLIND.n번이 Macro.BLIND.window초 안에 오면 바로 문제를 낸다(사냥 중일 때).
--  로블록스는 창이 앞에 없으면 키 · 마우스를 받지 않는다 — 그때 스킬이 들어오면 사람이 아니라 프로그램이 보낸 것이다. 숫자는 제가 정한 것
Macro.BLIND = { n = 5, window = 120 }
function Macro.onBlind(st, now: number)
	st.blind = st.blind or {}
	table.insert(st.blind, now)
	while #st.blind > 0 and now - st.blind[1] > Macro.BLIND.window do
		table.remove(st.blind, 1)
	end
end
function Macro.blindHit(st): boolean
	return st.blind ~= nil and #st.blind >= Macro.BLIND.n
end
function Macro.onRest(st, now: number)
	st.restEnter = now
end

function Macro.onMove(st, x: number, y: number, now: number)
	local c = D.suspect.still.cell
	st.moves[math.floor(x / c) .. "," .. math.floor(y / c)] = now
end

-- 스킬을 썼다: 같은 스킬을 다시 누른 간격(minGap초 넘는 것만 — 동작이 끝나기를 기다린 연타는 늘 고르게 오므로 뺀다)
function Macro.onSkill(st, id: string, clock: number)
	local last = st.last[id]
	st.last[id] = clock
	if last then
		local gap = clock - last
		if gap > D.suspect.minGap and gap < 30 then
			table.insert(st.gaps, gap)
			while #st.gaps > D.suspect.keep do
				table.remove(st.gaps, 1)
			end
		end
	end
end

-- 의심: "high" · "mid" · "low"(띄우는 때만 앞당긴다)
function Macro.level(st, now: number): string
	local S = D.suspect
	local level = "low"
	if #st.gaps >= S.min then
		local sum = 0
		for _, g in st.gaps do
			sum += g
		end
		local mean = sum / #st.gaps
		local var = 0
		for _, g in st.gaps do
			var += (g - mean) ^ 2
		end
		local cv = math.sqrt(var / #st.gaps) / mean
		if cv < S.cv.high then
			return "high"
		elseif cv < S.cv.mid then
			level = "mid"
		end
	end
	if killsIn(st, now, S.still.window) >= S.still.kills then
		local cells = 0
		for _, t in st.moves do
			if now - t <= S.still.window then
				cells += 1
			end
		end
		if cells <= S.still.cells then
			level = "mid"
		end
	end
	if now - st.rest >= S.long then
		level = "mid"
	end
	return level
end

-- 지금 사냥 중인가(지난 window초 동안 kills마리 넘게)
function Macro.hunting(st, now: number): boolean
	return killsIn(st, now, D.hunt.window) >= D.hunt.kills
end

-- 쉬지 않고 사냥한 초
function Macro.huntFor(st, now: number): number
	return if Macro.hunting(st, now) then now - st.rest else 0
end

-- 한 번 볼 때 할 일: "issue"(문제를 낸다) · "expire"(떠 있던 문제의 시간이 다 됐다 — 놓침) · nil
--  ctx = { hunt = 사냥 맵인가 } · rnd() = 0~1
function Macro.tick(st, now: number, ctx, rnd: () -> number): string?
	if st.check then
		return if now > st.check.deadline then "expire" else nil
	end
	if st.force then
		return "issue" -- 관리자가 보냈다(사냥 중이 아니어도)
	end
	if not ctx.hunt then
		if st.restEnter and now - st.restEnter >= Macro.REST_STAY then
			st.rest, st.restEnter = now, nil -- 마을 · 실내에 오래 머물렀다 = 쉼
		end
		return nil
	end
	st.restEnter = nil -- 다시 사냥 맵(잠깐 들른 것은 쉼이 아니다)
	if st.saved.pending then
		return "issue" -- 문제가 떠 있는 채 나갔다 → 다시 사냥 맵에 서면 다시 낸다
	end
	if st.saved.stopped then
		return nil -- 보상이 멈춘 동안은 그 사람이 「다시 확인」을 누른다
	end
	if Macro.blindHit(st) then
		st.blind = nil
		return "issue" -- 게임 창이 앞에 없는데 스킬이 계속 들어왔다: 통과한 지 얼마 안 됐어도 바로(2026-10-24)
	end
	if not Macro.hunting(st, now) or now - st.passAt < D.afterPass then
		return nil
	end
	local level = Macro.level(st, now)
	if level ~= "high" and now - st.born < D.first then
		return nil
	end
	if st.draw == nil then
		st.draw = rnd()
	end
	local g = D.gap[level]
	local due = g[1] + (g[2] - g[1]) * st.draw
	return if now - st.rest >= due then "issue" else nil
end

-- 문제를 낸다: 위의 셋(top) · 아래 아홉(cells — { kind, flip }) · 답(answer[칸] = true). 화면에 보낼 것(view)을 돌려준다
--  rnd(n) = 1~n의 정수
function Macro.issue(st, now: number, rnd: (number) -> number)
	local pool = table.clone(D.pool)
	for i = #pool, 2, -1 do
		local j = rnd(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local top, cells = {}, {}
	for i = 1, D.pick do
		top[i] = pool[i]
	end
	for i = 1, D.cells do
		cells[i] = { kind = pool[i], flip = rnd(2) == 2 }
	end
	for i = #cells, 2, -1 do
		local j = rnd(i)
		cells[i], cells[j] = cells[j], cells[i]
	end
	local answer = {}
	for i, c in cells do
		if table.find(top, c.kind) then
			answer[i] = true
		end
	end
	local token = tostring(rnd(1e9))
	st.check = { token = token, top = top, cells = cells, answer = answer, deadline = now + D.time, tries = D.tries }
	st.force = false
	st.saved.pending = true
	return Macro.view(st, now)
end

-- 화면에 보낼 것(답은 보내지 않는다)
function Macro.view(st, now: number)
	local c = st.check
	if not c then
		return nil
	end
	return { token = c.token, top = table.clone(c.top), cells = table.clone(c.cells), left = math.max(0, c.deadline - now), tries = c.tries }
end

-- 놓쳤다: 보상 멈춤(24시간 안의 n번째 놓침이면 stop[n]초 뒤부터 다시 확인할 수 있다) → n, 기다릴 초
function Macro.fail(st, now: number): (number, number)
	st.check = nil
	st.draw = nil
	local m = st.saved
	local keep = {}
	for _, t in m.fails do
		if now - t < D.forget then
			table.insert(keep, t)
		end
	end
	table.insert(keep, now)
	m.fails = keep
	local wait = D.stop[math.min(#keep, #D.stop)]
	m.stopped, m.stopUntil, m.pending = true, now + wait, false
	return #keep, wait
end

-- 대답: picks = 고른 칸들(셋). → "pass" · "wrong"(남은 기회가 있다) · "fail"(놓침) · "bad"(떠 있는 문제가 아니다)
function Macro.answer(st, token: any, picks: any, now: number): string
	local c = st.check
	if not c or token ~= c.token then
		return "bad"
	end
	if now > c.deadline then
		Macro.fail(st, now)
		return "fail"
	end
	local seen, ok = {}, typeof(picks) == "table"
	local n = 0
	if ok then
		for _, i in picks do
			n += 1
			if typeof(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > #c.cells or seen[i] then
				ok = false
				break
			end
			seen[i] = true
		end
	end
	if ok and n == D.pick then
		for i in seen do
			ok = ok and c.answer[i] == true
		end
	else
		ok = false
	end
	if ok then
		st.check = nil
		st.draw = nil
		st.passAt = now
		st.rest = now -- 다음 확인은 다시 쉬지 않은 사냥 시간을 채운 뒤
		st.saved.stopped, st.saved.stopUntil, st.saved.pending = false, 0, false
		return "pass"
	end
	c.tries -= 1
	if c.tries <= 0 then
		Macro.fail(st, now)
		return "fail"
	end
	return "wrong"
end

-- 보상이 멈췄나 · 문제가 떠 있나(떠 있는 동안도 보상은 없다 — 대신 맞지 않는다)
function Macro.stopped(st): boolean
	return st.saved.stopped
end
function Macro.pending(st): boolean
	return st.check ~= nil
end
-- 보상 멈춤에서 「다시 확인」을 누를 수 있나 · 몇 초 뒤에
function Macro.retryIn(st, now: number): number
	return math.max(0, st.saved.stopUntil - now)
end

-- 관리자: 지금 보낸다 · 풀어 준다
function Macro.forceNow(st)
	st.force = true
end
function Macro.clear(st)
	st.check = nil
	st.draw = nil
	st.force = false
	st.saved.stopped, st.saved.stopUntil, st.saved.pending = false, 0, false
	st.saved.fails = {}
end

return Macro
