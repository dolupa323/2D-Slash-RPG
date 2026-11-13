-- 매크로 확인의 셈(공방 js/lune/design/macro.js · 2026-10-23 사용자: "현재 게임에서 매크로 유저들이 많아 어떻게 잡을지 해결해봐").
--  서버가 재고(처치 · 움직인 칸 · 스킬을 누른 간격) 서버가 문제를 내고 채점한다. 화면도 서버도 모르는 순수한 셈이다(server/lune/modules/macroGuard.luau가 부른다).
--  st(세션마다) = { born 접속한 때 · rest 쉬지 않은 사냥이 시작된 때 · kills 처치한 때들 · moves[칸] = 마지막으로 선 때 · gaps 같은 스킬을 다시 누른 간격들(초) · last[스킬] = 누른 때(os.clock)
--                  · check 떠 있는 문제(kills = 떠 있는 동안 잡은 수) · passAt 마지막으로 통과한 때 · force 관리자가 보냄
--                  · saved = 계정에 남는 것 { fails = 놓친 때들 · stopped 보상 멈춤 · stopUntil 이때부터 다시 확인할 수 있다 · pending 문제가 떠 있는 채 나갔다
--                            · hs 지난 확인 뒤로 사냥한 초 · dr 이번 차례의 0~1(언제 띄울지 — 2026-11-13: 둘 다 계정에 남는다 · 아래 Macro.dueOf) · rn 룬의 사람 시계(server runeGuard.luau) } }
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

-- 날마다의 칸(KST 날짜마다 — 아래 Macro.note): m 사냥한 분 · ls 로그 점수 합 · rc 룬의 저주 속 사냥 분 · ci · cp · cf 확인(받음 · 통과 · 놓침 — 2026-11-13부터 cf는 「떠 있는 동안에도 잡았다」만) ·
--  bl 창 밖 입력 · bg · bm 미끼(주움 · 놓침) · rl 이어 사냥으로 다시 들어온 수(2026-11-13) · ca 자리를 비워 놓친 확인(점수에 넣지 않는다) · br2 길 위의 미끼를 주운 수(사람의 증거가 아니다) ·
--  kt · kz 키를 누른 수 · 그 가운데 한 프레임도 안 된 수 · tt · ts 터치 수 · 그 가운데 같은 점을 되풀이한 수(손의 기록 — 아래 Macro.inputNote)
local DAYF_ALL = { "m", "ls", "rc", "ci", "cp", "cf", "bl", "bg", "bm", "rl", "ca", "br2", "kt", "kz", "tt", "ts" }

-- 계정에 남는 것(Account.pack · unpack)
function Macro.newSaved()
	return { fails = {}, stopped = false, stopUntil = 0, pending = false, days = {}, eps = {}, br = "", warns = {}, jail = Macro.newJail(), run = nil :: any, relogs = {}, hs = 0, dr = nil :: number?, rn = nil :: any } -- run · relogs = 이어 사냥(2026-11-13 — 아래 Macro.new) -- days · eps · br · warns = 계정마다의 매크로 기록(2026-11-09 — 아래 Macro.total) · jail = 감옥(2026-11-11 — 아래 Macro.jailStart)
end
-- 감옥의 기록: n = 이 계정이 갇힌 횟수(줄지 않는다) · untilT = 이때까지 갇힌다(os.time — 0 = 갇히지 않았다) · from = 잡혀 온 자리 { k = 장면, x, y, cid = 그 캐릭터 } · log = { t 때, s 종합 점수, sec 길이 }
function Macro.newJail()
	return { n = 0, untilT = 0, from = nil :: any, log = {} }
end
local function unpackJail(raw: any)
	local j = Macro.newJail()
	if typeof(raw) == "table" then
		j.n = if typeof(raw.n) == "number" then math.max(0, math.floor(raw.n)) else 0
		j.untilT = if typeof(raw.untilT) == "number" then raw.untilT else 0
		local f = raw.from
		if typeof(f) == "table" and typeof(f.k) == "string" and typeof(f.x) == "number" and typeof(f.y) == "number" then
			j.from = { k = f.k, x = f.x, y = f.y, cid = if typeof(f.cid) == "number" then f.cid else nil }
		end
		if typeof(raw.log) == "table" then
			for _, e in raw.log do
				if typeof(e) == "table" and typeof(e.t) == "number" then
					table.insert(j.log, { t = e.t, s = if typeof(e.s) == "number" then e.s else 0, sec = if typeof(e.sec) == "number" then e.sec else 0 })
				end
			end
		end
	end
	return j
end
function Macro.unpack(raw: any)
	local m = Macro.newSaved()
	if typeof(raw) == "table" then
		m.fails = nums(raw.fails)
		m.stopped = raw.stopped == true
		m.stopUntil = if typeof(raw.stopUntil) == "number" then raw.stopUntil else 0
		m.pending = raw.pending == true
		-- 계정마다의 매크로 기록(2026-11-09): 꼴이 틀린 것은 버린다
		if typeof(raw.days) == "table" then
			for k, d in raw.days do
				if typeof(k) == "string" and typeof(d) == "table" then
					local c = {}
					for _, f in DAYF_ALL do
						if typeof(d[f]) == "number" then
							c[f] = d[f]
						end
					end
					m.days[k] = c
				end
			end
		end
		if typeof(raw.eps) == "table" then
			for _, e in raw.eps do
				if typeof(e) == "table" and typeof(e.t0) == "number" then
					table.insert(m.eps, { t0 = e.t0, t1 = if typeof(e.t1) == "number" then e.t1 else e.t0, map = if typeof(e.map) == "string" then e.map else "", peak = if typeof(e.peak) == "number" then e.peak else 0, how = if typeof(e.how) == "table" then e.how else nil })
				end
			end
		end
		m.br = if typeof(raw.br) == "string" then string.gsub(raw.br, "[^01]", "") else ""
		if typeof(raw.warns) == "table" then
			for _, w in raw.warns do
				if typeof(w) == "table" and typeof(w.t) == "number" then
					table.insert(m.warns, { t = w.t, s = if typeof(w.s) == "number" then w.s else 0, by = if w.by == "admin" then "admin" else "auto" })
				end
			end
		end
		m.jail = unpackJail(raw.jail)
		-- 이어 사냥(2026-11-13): 쉬지 않은 사냥의 시작 · 마지막 처치 · 확인의 때 · 마지막 통과 · 다시 들어온 때들
		local r = raw.run
		if typeof(r) == "table" and typeof(r.rest) == "number" and typeof(r.last) == "number" then
			m.run = { rest = r.rest, last = r.last, pass = if typeof(r.pass) == "number" then r.pass else 0 }
		end
		m.relogs = nums(raw.relogs)
		-- 확인의 때(2026-11-13): 사냥한 초 · 이번 차례의 0~1 · 룬의 사람 시계 { c 쿨 · g 가호 · b 힘(os.time) · h 룬을 푼 뒤 사냥한 초 }
		m.hs = if typeof(raw.hs) == "number" and raw.hs >= 0 and raw.hs < 1e7 then raw.hs else 0
		m.dr = if typeof(raw.dr) == "number" and raw.dr >= 0 and raw.dr <= 1 then raw.dr else nil
		local rn = raw.rn
		if typeof(rn) == "table" then
			local function num(v)
				return if typeof(v) == "number" and v >= 0 and v < 1e10 then v else 0
			end
			m.rn = { c = num(rn.c), g = num(rn.g), b = num(rn.b), h = num(rn.h) }
		end
	end
	return m
end
function Macro.pack(m)
	local j = m.jail
	return { fails = table.clone(m.fails), stopped = m.stopped or nil, stopUntil = if m.stopUntil > 0 then m.stopUntil else nil, pending = m.pending or nil,
		days = if next(m.days or {}) ~= nil then m.days else nil, eps = if m.eps and #m.eps > 0 then m.eps else nil, br = if m.br and m.br ~= "" then m.br else nil, warns = if m.warns and #m.warns > 0 then m.warns else nil,
		jail = if j and (j.n > 0 or j.untilT > 0) then { n = j.n, untilT = if j.untilT > 0 then j.untilT else nil, from = j.from, log = if #j.log > 0 then j.log else nil } else nil,
		run = m.run, relogs = if m.relogs and #m.relogs > 0 then m.relogs else nil, hs = if (m.hs or 0) > 0 then math.floor(m.hs) else nil, dr = m.dr, rn = m.rn }
end

function Macro.new(now: number, saved)
	local st = { born = now, rest = now, kills = {}, moves = {}, gaps = {}, last = {}, check = nil, passAt = 0, force = false, saved = saved or Macro.newSaved(), bait = require(script.Parent.rune).newStat() } -- bait = 별똥별 조각의 기록(2026-11-07 — sim/rune.luau)
	-- 이어 사냥(2026-11-13 사용자: "메크로가 게임을 나갔다가 들어왔다가 하면서 매크로 탐지 안당하면서 악용하면 아예 못잡아"):
	--  마지막 처치에서 rest초 안에 다시 들어왔다 → 쉬지 않은 사냥 시계 · 확인의 때 · 마지막 통과를 그대로 잇고 처음 first초의 봐주기도 없다 · 다시 들어온 때를 계정에 적는다(Macro.level · 관리 창)
	local run = st.saved.run
	if run and now >= run.last and now - run.last < D.rest then
		st.rest = run.rest
		st.passAt = run.pass or 0
		st.born = now - D.first
		st.prevKill = run.last
		st.relogged = true
		st.saved.relogs = st.saved.relogs or {}
		table.insert(st.saved.relogs, now)
		while #st.saved.relogs > 20 do
			table.remove(st.saved.relogs, 1)
		end
		Macro.note(st, "rl", 1, now)
	end
	return st
end
-- 지난 keep초 안에 이어 사냥으로 다시 들어온 수(2026-11-13)
function Macro.relogCount(st, now: number): number
	local R = D.relog
	local n = 0
	for _, t0 in (st.saved and st.saved.relogs) or {} do
		if R and now - t0 <= R.keep then
			n += 1
		end
	end
	return n
end

-- ---------- 행동 로그 분석(2026-11-09 — 공방 design/macro.js의 log · 상용 게임의 서버 로그 탐지를 옮긴 것) ----------
--  사용자: "다른 상용화게임들이 매크로 방지책으로 사용하는 알고리즘같은게 있을거아니야 로그나"
--  ① 자기 유사도(NCSOFT — 리니지 · 아이온 · 블레이드 & 소울, NDSS 2016): 사냥한 1분마다 행동 수의 벡터(스킬마다 · 줍기 · 물약 · 문 · 처치 · 지난 칸) →
--     이웃한 1분끼리의 코사인 유사도 — 평균이 높고 흩어짐이 작을수록 같은 일을 같은 비율로 되풀이한다(사람은 분마다 섞임이 바뀐다)
--  ② 같은 고리(NetEase NGUARD — KDD 2018): 행동의 차례에서 가장 많이 되풀이되는 고리(서로 다른 행동 셋 이상)가 덮는 몫 x 한 바퀴 시간의 흔들림 — 녹화 · 재생 매크로는 같은 고리를 같은 시간에 돈다
--  ③ 같은 길(서버의 이동 기록 — Mitterhofer 2009 · WoW): 지난 칸의 차례에서 ②와 같은 셈
--  합친 점수(0 ~ 1)는 매크로 확인을 일찍 띄우는 데에만 쓴다(Macro.level — 메이플 「거짓말탐지기 집중 발동」과 같은 쓰임) · 벌 · 정지 · 날파리에는 쓰지 않는다. 관리 창에 까닭과 숫자
local LG = D.log

local function logOf(st)
	local lg = st.log
	if not lg then
		lg = { cur = {}, curMin = nil, curKills = 0, vecs = {}, seq = {}, path = {}, lastCell = nil, at = -math.huge, result = nil }
		st.log = lg
	end
	return lg
end
-- 1분이 넘어갔다: 사냥한 1분(처치가 있었다)이면 그 벡터를 남긴다(최근 minutes개)
local function roll(lg, minute: number)
	if lg.curMin ~= nil and minute ~= lg.curMin then
		if lg.curKills > 0 and next(lg.cur) ~= nil then
			table.insert(lg.vecs, lg.cur)
			while #lg.vecs > LG.minutes do
				table.remove(lg.vecs, 1)
			end
		end
		lg.cur, lg.curKills = {}, 0
	end
	lg.curMin = minute
end
local function bump(lg, key: string, now: number)
	roll(lg, now // 60)
	lg.cur[key] = (lg.cur[key] or 0) + 1
end
-- 행동 하나(서버가 받은 것): kind = "s:<스킬>" · "pick" · "potion" · "hop". clock = 소수 초(os.clock) · now = os.time()
function Macro.act(st, kind: string, clock: number, now: number)
	local lg = logOf(st)
	bump(lg, kind, now)
	table.insert(lg.seq, { k = kind, t = clock })
	while #lg.seq > LG.seq do
		table.remove(lg.seq, 1)
	end
end
-- 지난 자리(서버가 받은 이동): 칸(LG.cell점)이 바뀔 때만
function Macro.cell(st, x: number, y: number, clock: number, now: number)
	local lg = logOf(st)
	local c = math.floor(x / LG.cell) .. "," .. math.floor(y / LG.cell)
	if c == lg.lastCell then
		return
	end
	lg.lastCell = c
	bump(lg, "c:" .. c, now)
	table.insert(lg.path, { k = c, t = clock })
	while #lg.path > LG.path do
		table.remove(lg.path, 1)
	end
end

local function ramp(v: number, lo: number, hi: number): number -- lo에서 0 → hi에서 1
	if hi == lo then
		return if v >= hi then 1 else 0
	end
	return math.clamp((v - lo) / (hi - lo), 0, 1)
end
local function cosine(a, b): number
	local dot, na, nb = 0, 0, 0
	for k, v in a do
		na += v * v
		local w = b[k]
		if w then
			dot += v * w
		end
	end
	for _, w in b do
		nb += w * w
	end
	if na == 0 or nb == 0 then
		return 0
	end
	return dot / math.sqrt(na * nb)
end
local function meanSd(list): (number, number)
	local n = #list
	if n == 0 then
		return 0, 0
	end
	local s = 0
	for _, v in list do
		s += v
	end
	local m = s / n
	local q = 0
	for _, v in list do
		q += (v - m) ^ 2
	end
	return m, math.sqrt(q / n)
end
-- ① 자기 유사도: { score, mean, sd, n } · 사냥한 1분이 minuteMin개보다 적으면 nil
local function simOf(lg)
	if #lg.vecs < LG.minuteMin then
		return nil
	end
	local cs = {}
	for i = 2, #lg.vecs do
		table.insert(cs, cosine(lg.vecs[i - 1], lg.vecs[i]))
	end
	local m, sd = meanSd(cs)
	return { score = ramp(m, LG.sim.lo, LG.sim.hi) * ramp(-sd, -LG.spread.hi, -LG.spread.lo), mean = m, sd = sd, n = #lg.vecs }
end
-- ② · ③ 가장 많이 되풀이되는 고리(길): list = { { k, t } } · R = LG.loop · LG.route → { score, cover, cv, laps, len } 또는 nil
--  고리마다 앞에서부터 겹치지 않게 세어 덮는 몫(cover)을 내고, 바로 이어진 두 번 사이를 한 바퀴로 그 시간의 변동 계수(cv)를 낸다
local function loopOf(list, R)
	local n = #list
	local best = nil
	for L = R.min, R.max do
		if n < L * R.need then
			break
		end
		local starts = {}
		for i = 1, n - L + 1 do
			local parts = table.create(L)
			for j = 0, L - 1 do
				parts[j + 1] = list[i + j].k
			end
			local key = table.concat(parts, "|")
			local s = starts[key]
			if not s then
				s = {}
				starts[key] = s
			end
			table.insert(s, i)
		end
		for key, s in starts do
			if #s >= R.need then
				local seen, d = {}, 0
				for part in string.gmatch(key, "[^|]+") do
					if not seen[part] then
						seen[part] = true
						d += 1
					end
				end
				if d >= R.distinct then
					local laps, cover, last = {}, 0, nil
					for _, i in s do
						if last == nil or i >= last + L then
							cover += L
							if last ~= nil and i == last + L then
								table.insert(laps, list[i].t - list[last].t)
							end
							last = i
						end
					end
					if #laps >= R.need - 1 then
						local m, sd = meanSd(laps)
						local cv = if m > 0 then sd / m else 1
						local frac = cover / n
						local score = ramp(frac, R.cover.lo, R.cover.hi) * ramp(-cv, -R.cv.hi, -R.cv.lo)
						if not best or score > best.score or (score == best.score and frac > best.cover) then
							best = { score = score, cover = frac, cv = cv, laps = #laps + 1, len = L, key = key, lap = m }
						end
					end
				end
			end
		end
	end
	return best
end
-- 합친 점수: { score(0 ~ 1), sim, loop, route } · every초마다 다시 셈한다(그 사이는 앞의 것)
function Macro.logScore(st, now: number)
	local lg = st.log
	if not lg then
		return nil
	end
	if lg.result and now - lg.at < LG.every then
		return lg.result
	end
	lg.at = now
	roll(lg, now // 60)
	local sim, loop, route = simOf(lg), loopOf(lg.seq, LG.loop), loopOf(lg.path, LG.route)
	local miss = 1
	if sim then
		miss *= 1 - LG.w.sim * sim.score
	end
	if loop then
		miss *= 1 - LG.w.loop * loop.score
	end
	if route then
		miss *= 1 - LG.w.route * route.score
	end
	lg.result = { score = 1 - miss, sim = sim, loop = loop, route = route }
	return lg.result
end

-- ---------- 계정마다의 매크로 기록 · 종합 점수 · 경고(2026-11-09 — 공방 design/macro.js의 record) ----------
--  사용자: "계정마다 종속된 로그기록이랑 점수를 내가 계속 볼수있어야해 초기화되는게아니라 … 미끼 … 먹냐 안먹냐 얼마나 안먹었냐 이런거 비율로 따져서 점수하고
--   그래서 종합점수로 쭉 내가 유저로그를 볼수있어야해 그래서 완전히 문제수준이고, 심각한 유저의 경우 채팅창에 경고 주고 개선되는지도 파악할수있어야해"
--  saved(계정에 남는다)에 더한 것: days[KST 날짜] = { m 사냥한 분 · ls 그 분들의 로그 점수 합 · rc 룬의 저주(runeCut 넘게)를 두고 사냥한 분 · ci · cp · cf 매크로 확인(받음 · 통과 · 놓침) ·
--   bl 창 밖 입력 · bg · bm 미끼(주움 · 놓침) } · eps = 의심 구간 { t0, t1, map, peak(%), how } · br = 미끼의 최근 결과("1" 주움 · "0" 놓침 — baitRing개) · warns = { t, s(그때 점수), by("auto" · "admin") }
local RC = D.record
local DAYF = DAYF_ALL

-- 그날의 열쇠(KST — 「20261109」)
function Macro.dayKey(now: number): string
	return os.date("!%Y%m%d", now + 9 * 3600)
end
local function dayOf(saved, now: number)
	local key = Macro.dayKey(now)
	local d = saved.days[key]
	if not d then
		d = {}
		saved.days[key] = d
		local keys = {}
		for k in saved.days do
			table.insert(keys, k)
		end
		if #keys > RC.days then -- 오래된 날부터 지운다(최근 RC.days일)
			table.sort(keys)
			for i = 1, #keys - RC.days do
				saved.days[keys[i]] = nil
			end
		end
	end
	return d
end
-- 그날의 칸 하나를 더한다
function Macro.note(st, field: string, n: number?, now: number)
	local d = dayOf(st.saved, now)
	d[field] = (d[field] or 0) + (n or 1)
end
-- 미끼(별똥별 조각)의 결과: 주웠다 · 놓쳤다(server runeGuard.luau가 부른다)
function Macro.baitResult(st, got: boolean, now: number)
	local s = st.saved
	s.br = string.sub((s.br or "") .. (if got then "1" else "0"), -RC.baitRing)
	Macro.note(st, if got then "bg" else "bm", 1, now)
end
-- 사냥한 1분의 「어떻게」(관리 창의 구간 줄): 되풀이한 고리(행동의 이름표 차례) · 같은 길 · 1분 되풀이
function Macro.how(r)
	if not r then
		return nil
	end
	local function pct(v: number): number
		return math.floor(v * 100 + 0.5)
	end
	return {
		loop = if r.loop and r.loop.score > 0 then { seq = r.loop.key, lap = math.floor(r.loop.lap * 10 + 0.5) / 10, laps = r.loop.laps, cv = pct(r.loop.cv), cover = pct(r.loop.cover) } else nil,
		route = if r.route and r.route.score > 0 then { n = r.route.len, lap = math.floor(r.route.lap * 10 + 0.5) / 10, laps = r.route.laps, cv = pct(r.route.cv), cover = pct(r.route.cover) } else nil,
		sim = if r.sim then pct(r.sim.mean) else nil,
	}
end
-- 사냥한 1분(서버가 1분마다 — 사냥 맵에서 사냥 중일 때): 로그 점수 · 룬의 저주 · 의심 구간(열기 · 늘이기 · 닫기)
--  score = 그때의 Macro.logScore · curse = hero.curse(0 ~ 1) · map = 장면의 이름표 · how = Macro.how
function Macro.minute(st, now: number, score: number, curse: number, map: string, how)
	Macro.note(st, "m", 1, now)
	if score > 0 then
		Macro.note(st, "ls", math.floor(score * 1000 + 0.5) / 1000, now)
	end
	if curse >= RC.runeCut then
		Macro.note(st, "rc", 1, now)
	end
	local E = RC.episode
	local eps = st.saved.eps
	local ep = st.epIdx and eps[st.epIdx]
	if score >= E.start then
		if not ep then
			table.insert(eps, { t0 = now, t1 = now, map = map, peak = 0 })
			while #eps > RC.eps do
				table.remove(eps, 1)
			end
			st.epIdx = #eps
			ep = eps[st.epIdx]
		end
		st.epLow = 0
	elseif ep and score < E["end"] then
		st.epLow = (st.epLow or 0) + 1
	end
	if ep then
		ep.t1 = now
		local p = math.floor(score * 100 + 0.5)
		if p > (ep.peak or 0) then
			ep.peak, ep.how, ep.map = p, how, map
		end
		if (st.epLow or 0) >= E.closeMin then
			Macro.endEp(st)
		end
	end
end
-- 의심 구간을 닫는다(사냥이 끊겼다 · 맵을 나갔다 · 점수가 내려간 채 이어졌다)
function Macro.endEp(st)
	st.epIdx, st.epLow = nil, nil
end

-- 종합 점수(0 ~ 100): 지난 span일의 기록 · 미끼의 최근 결과로 — 나간 사람의 계정 자료(saved)로도 셈한다(관리 창)
--  돌려주는 것: { score, grade("none" · "watch" · "problem" · "severe"), parts = { behave, bait, check, rune, blind(0 ~ 1) }, sum = 그 날들의 합, baitN, baitMiss }
function Macro.grade(score: number): string
	local G = RC.grade
	return if score >= G.severe then "severe" elseif score >= G.problem then "problem" elseif score >= G.watch then "watch" else "none"
end
local function scoreOf(sum, br: string?)
	local P = RC.parts
	local parts = {}
	parts.behave = if (sum.m or 0) > 0 then ramp((sum.ls or 0) / sum.m, P.behave.lo, P.behave.hi) else 0
	local n, miss = 0, 0
	if br then
		n = #br
		for i = 1, n do
			if string.sub(br, i, i) == "0" then
				miss += 1
			end
		end
	else
		n, miss = (sum.bg or 0) + (sum.bm or 0), sum.bm or 0
	end
	parts.bait = if n >= P.bait.need then ramp(miss / n, P.bait.lo, P.bait.hi) else 0
	parts.check = if (sum.ci or 0) >= P.check.need then ramp((sum.cf or 0) / sum.ci, P.check.lo, P.check.hi) else 0
	parts.rune = if (sum.m or 0) > 0 then ramp((sum.rc or 0) / sum.m, P.rune.lo, P.rune.hi) else 0
	parts.blind = ramp(sum.bl or 0, P.blind.lo, P.blind.hi)
	-- 손의 기록(2026-11-13 — design/macro.js input): 키를 한 프레임도 안 되게 누른 몫 · 폰에서 같은 점을 되풀이한 몫(큰 쪽)
	local IN = D.input
	local key = if (sum.kt or 0) >= IN.need then ramp((sum.kz or 0) / sum.kt, IN.key.lo, IN.key.hi) else 0
	local touch = if (sum.tt or 0) >= IN.need then ramp((sum.ts or 0) / sum.tt, IN.touch.lo, IN.touch.hi) else 0
	parts.input = math.max(key, touch)
	parts.inputKey = key -- (증거에 쓰는 키 쪽 — 아래 Macro.proof · 종합 점수에는 넣지 않는다)
	local keep = 1
	for k, v in parts do
		if P[k] then -- (inputKey는 점수에 넣지 않는다)
			keep *= 1 - P[k].w * v
		end
	end
	local score = math.floor((1 - keep) * 100 + 0.5)
	return score, parts, n, miss
end
function Macro.total(saved, now: number)
	local sum = {}
	for _, f in DAYF do
		sum[f] = 0
	end
	for i = 0, RC.span - 1 do
		local d = saved.days and saved.days[Macro.dayKey(now - i * 86400)]
		if d then
			for _, f in DAYF do
				sum[f] += d[f] or 0
			end
		end
	end
	local score, parts, n, miss = scoreOf(sum, saved.br or "")
	local out = { score = score, grade = Macro.grade(score), parts = parts, sum = sum, baitN = n, baitMiss = miss }
	out.human = Macro.human(out)
	out.proof = Macro.proof(out)
	return out
end
-- 증거가 있는가(2026-11-14 사용자: "지금 매크로가 아니라 애먼사람만 정지시키고있는데?" — 유저 글 "매크로가 너무 많이 뜹니다 무슨 3분에 한번씩 떠요 매크로 하고 잠깐 자리 비우면 6시간 정지에요" — 공방 design/macro.js의 proof): 확인이 떠 있는데도 사냥을 이어 간 놓침 · 한 프레임도 안 되는 키 누름.
--  벌(감옥 · 의심 높음 · 자동 경고)은 이것이 있을 때만 — 별똥별 · 룬 · 되풀이 사냥 · 다시 접속만으로는 확인을 「중간」으로 앞당기는 데까지
function Macro.proof(t): boolean
	local PR = D.proof
	if not PR or not t or not t.parts then
		return true -- (설계에 없으면 예전처럼)
	end
	return (t.parts.check or 0) >= PR.check or (t.parts.inputKey or 0) >= PR.key
end
-- 사람으로 보는가(2026-11-12 사용자: "사람다운 신호가 사람이라고 판단되면 감옥에 넣지않기로 하자" — 공방 design/macro.js의 record.human):
--  미끼를 baitNeed개 넘게 받아 bait 넘게 주웠다 · 매크로 확인을 checkNeed번 넘게 받아 놓친 것이 없다 · 룬의 저주 속 사냥 항목이 0 · 손의 기록 항목(input)이 0 — 넷 다
--  (2026-11-13: 창 밖 입력은 뺐다 — 사용자 "지금 창내림 세는것도 의미가 없고")
--  → 감옥(Macro.jailDue) · 자동 경고(Macro.warnDue)를 하지 않는다. 종합 점수 · 등급 · 기록은 그대로
function Macro.human(t): boolean
	local H = RC.human
	if not H or not t or not t.sum then
		return false
	end
	local s = t.sum
	local baitOk = (t.baitN or 0) >= H.baitNeed and ((t.baitN - (t.baitMiss or 0)) / t.baitN) >= H.bait
	local checkOk = (s.ci or 0) >= H.checkNeed and (s.cf or 0) == 0
	local runeOk = (t.parts and t.parts.rune or 0) <= 0
	local inputOk = (t.parts and t.parts.input or 0) <= 0
	return baitOk and checkOk and runeOk and inputOk
end
-- 하루의 점수(그날의 기록만 — 미끼도 그날 주운 · 놓친 수): 관리 창의 날마다 줄 · 경고 전 · 뒤 견주기
function Macro.dayScore(d): number
	return (scoreOf(d, nil))
end
-- 경고 전 · 뒤 span일의 날마다 점수 평균(사냥한 날만) — 뒤는 아직 지나지 않은 날까지
function Macro.warnEffect(saved, t: number, now: number): (number?, number?)
	local function avg(from: number, to: number): number?
		local s, n = 0, 0
		for day = from, to do
			local at = t + day * 86400
			if at <= now then
				local d = saved.days[Macro.dayKey(at)]
				if d and (d.m or 0) > 0 then
					s += Macro.dayScore(d)
					n += 1
				end
			end
		end
		return if n > 0 then s / n else nil
	end
	return avg(-RC.span, -1), avg(1, RC.span)
end
-- 경고할 때인가: 심각 · 그날 사냥 minHunt분 넘게 · 마지막 경고에서 every초 지남
function Macro.warnDue(st, now: number): boolean
	local t = st.total
	if not t or t.grade ~= "severe" or t.human or t.proof == false then -- (사람으로 보면 · 증거가 없으면 자동 경고도 하지 않는다 — 2026-11-12 · 2026-11-14)
		return false
	end
	local d = st.saved.days[Macro.dayKey(now)]
	if not d or (d.m or 0) < RC.warn.minHunt then
		return false
	end
	local last = st.saved.warns[#st.saved.warns]
	return not last or now - last.t >= RC.warn.every
end
function Macro.warned(st, now: number, by: string)
	table.insert(st.saved.warns, { t = now, s = if st.total then st.total.score else 0, by = by })
	while #st.saved.warns > RC.warns do
		table.remove(st.saved.warns, 1)
	end
end
-- 관리 창에 보낼 기록(계정 자료 saved로 — 접속 중이 아니어도): 종합 점수 · 항목 · 최근 14일 · 최근 구간 5 · 경고(전 · 뒤)
function Macro.recordView(saved, now: number)
	local t = Macro.total(saved, now)
	local function pct(v: number): number
		return math.floor(v * 100 + 0.5)
	end
	local days = {}
	for i = 0, 13 do
		local key = Macro.dayKey(now - i * 86400)
		local d = saved.days[key]
		if d and ((d.m or 0) > 0 or (d.ci or 0) > 0 or (d.bg or 0) + (d.bm or 0) > 0) then
			table.insert(days, { key = key, m = d.m or 0, ls = if (d.m or 0) > 0 then pct((d.ls or 0) / d.m) else 0, rc = d.rc or 0, ci = d.ci or 0, cp = d.cp or 0, cf = d.cf or 0, bl = d.bl or 0, bg = d.bg or 0, bm = d.bm or 0, rl = d.rl or 0,
				ca = d.ca or 0, br2 = d.br2 or 0, kt = d.kt or 0, kz = d.kz or 0, tt = d.tt or 0, ts = d.ts or 0, score = Macro.dayScore(d) }) -- (2026-11-13: 자리 비움 놓침 · 길 위 미끼 · 손의 기록)
		end
	end
	local eps = {}
	for i = #saved.eps, math.max(1, #saved.eps - 4), -1 do
		table.insert(eps, saved.eps[i])
	end
	local warns = {}
	for i = #saved.warns, math.max(1, #saved.warns - 4), -1 do
		local w = saved.warns[i]
		local before, after = Macro.warnEffect(saved, w.t, now)
		table.insert(warns, { t = w.t, s = w.s, by = w.by, before = before and math.floor(before + 0.5), after = after and math.floor(after + 0.5) })
	end
	return {
		score = t.score, grade = t.grade, human = t.human, proof = t.proof, -- human = 사람으로 본다(감옥 · 자동 경고 없음 — 2026-11-12) · proof = 증거가 있다(없으면 감옥 · 의심 높음 · 자동 경고 없음 — 2026-11-14)
		parts = { behave = pct(t.parts.behave), bait = pct(t.parts.bait), check = pct(t.parts.check), rune = pct(t.parts.rune), blind = pct(t.parts.blind), input = pct(t.parts.input or 0) },
		bait = { t.baitN - t.baitMiss, t.baitN }, sum = t.sum, days = days, eps = eps, warns = warns,
		jail = { n = saved.jail and saved.jail.n or 0, left = if saved.jail then math.max(0, saved.jail.untilT - now) else 0, last = saved.jail and saved.jail.log[#saved.jail.log] }, -- 감옥(2026-11-11): 횟수 · 남은 초 · 마지막 { t, s, sec }
	}
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
	if st.saved.stopped then
		-- 「사냥 보상 멈춤」인데도 잡은 수(2026-10-28 매크로 방지 날파리 — design/afk.js의 when.kills): 보상이 0인데 화면 위의 「사냥 보상 멈춤」을 누르지 않고 계속 잡는다 = 사람이 아니다
		st.stopKills = (st.stopKills or 0) + 1
	end
	local prev = st.kills[#st.kills] or st.prevKill -- (이어 사냥이면 나가기 전의 마지막 처치 — 2026-11-13)
	if prev == nil or now - prev >= D.rest then
		st.rest = now -- 한참 쉬다가 다시 잡기 시작했다
	end
	table.insert(st.kills, now)
	-- 이어 사냥을 위해 계정에 남긴다(2026-11-13 — 위 Macro.new): 쉬지 않은 사냥의 시작 · 마지막 처치 · 확인의 때 · 마지막 통과
	local run = st.saved.run
	if not run then
		st.saved.run = { rest = st.rest, last = now, pass = st.passAt }
	else
		run.rest, run.last, run.pass = st.rest, now, st.passAt
	end
	-- 확인의 때를 재는 「사냥한 초」(2026-11-13 — 계정에 남는다: 쉬어도 · 나갔다 들어와도 0이 되지 않는다): 바로 앞 처치에서 huntGap초 안이면 그 사이를 더한다
	if prev ~= nil and now >= prev and now - prev <= D.huntGap then
		st.saved.hs = (st.saved.hs or 0) + (now - prev)
	end
	-- 문제가 떠 있는 동안에도 잡았다(2026-11-13 — 놓쳤을 때 「자리를 비웠다」와 「잡으면서 무시했다」를 가른다: Macro.fail)
	if st.check then
		st.check.kills = (st.check.kills or 0) + 1
	end
	do -- 행동 로그(아래 Macro.logScore): 처치는 1분의 벡터에만(몬스터가 나오는 때를 따르므로 차례에는 넣지 않는다)
		local lg = logOf(st)
		bump(lg, "kill", now)
		lg.curKills += 1
	end
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
	Macro.note(st, "bl", 1, now) -- (계정의 기록 — 2026-11-09)
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
--  noLong = 오래 쉬지 않은 것(long)은 보지 않는다(매크로 방지 날파리 — 오래 사냥한 것만으로는 날아오지 않는다 · 2026-10-28)
function Macro.level(st, now: number, noLong: boolean?): string
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
		if cv < S.cv.mid then
			level = "mid" -- (2026-11-13 낮: 「높음」 → 「중간」까지 — 키를 누르고 있어도 간격이 고르다)
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
	-- (오래 쉬지 않은 사냥 = 의심 중간은 2026-11-13 낮에 뺐다 — 사용자 "매크로 방지그림이 너무 자주뜬다는데?": 보통 사람이 오래 사냥한다)
	-- 계정의 종합 점수(2026-11-09 — 아래 Macro.total · 서버가 1분마다 st.total): 심각 = 「의심 높음」 · 문제 = 「중간」만큼 자주 확인. 날파리(noLong)에는 쓰지 않는다
	if not noLong and st.total then
		if st.total.grade == "severe" and st.total.proof ~= false then
			return "high"
		elseif st.total.grade == "severe" or st.total.grade == "problem" then
			level = "mid" -- (증거 없는 「심각」은 「중간」까지 — 2026-11-14 애먼 사람이 3 ~ 5분마다 확인을 받았다)
		end
	end
	-- 행동 로그 분석(2026-11-09 — 위 Macro.logScore): 합친 점수가 level.mid를 넘으면 「중간」(2026-11-13 낮: 「높음」은 뺐다 — 한자리에서 되풀이해 사냥하는 사람도 높다). 날파리(noLong)에는 쓰지 않는다
	if not noLong then
		local r = Macro.logScore(st, now)
		if r and r.score >= LG.level.mid then
			level = "mid"
		end
	end
	-- 나갔다 들어오기(2026-11-13 — design/macro.js relog): 지난 keep초 안에 이어 사냥으로 다시 들어온 수가 mid · high번이면. 날파리(noLong)에는 쓰지 않는다
	if not noLong and D.relog then
		local n = Macro.relogCount(st, now)
		if n >= D.relog.mid then
			level = "mid" -- (high번도 「중간」까지 — 2026-11-14: 폰은 끊겨 다시 들어오기도 한다)
		end
	end
	-- 별똥별 조각(2026-11-07 — design/rune.js BAIT): 지난 한 시간 동안 하나도 줍지 않고 여럿 놓쳤다(누가 봐도 주울 것을 그냥 지나친다)
	--  (2026-11-13 낮: 「중간」까지 — 다니지 않던 자리에 떨어지게 된 뒤로 줍지 않는 사람도 있다. 놓친 비율은 종합 점수의 bait로 「심각」에 들어간다)
	local bl = require(script.Parent.rune).baitLevel(st.bait, now)
	if bl == "high" or bl == "mid" then
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
	if not Macro.hunting(st, now) then
		return nil
	end
	local level = Macro.level(st, now)
	if level ~= "high" and now - st.born < D.first then
		return nil
	end
	-- 2026-11-13 사용자: "매크로 방지 그림이 정해진 패턴으로 나와서 … 10분 나와버리면 9분 매크로 돌리고 게임 나갔다가 들어와서 다시 9분" —
	--  계정에 남는 「사냥한 초」(Macro.onKill이 더한다 — 쉬어도 · 나갔다 들어와도 0이 되지 않는다)가 이번 차례의 때(Macro.dueOf — 언제든 올 수 있다)를 넘으면
	local sv = st.saved
	if sv.dr == nil then
		sv.dr = rnd()
	end
	return if (sv.hs or 0) >= Macro.dueOf(level, sv.dr) then "issue" else nil
end

-- 이번 차례의 때(사냥한 초): floor + 지수 분포(평균 mean)를 cap에서 자른 것의 u(0~1) 자리 — u = 0이면 floor · 1이면 cap(design/macro.js wait)
--  지수 분포라 「지금까지 안 왔으니 n분은 안전」이 없다(앞으로 올 때의 분포가 지금까지 기다린 것과 상관없다)
function Macro.dueOf(level: string, u: number): number
	local w = D.wait[level] or D.wait.low
	local span = w.cap - w.floor
	local top = 1 - math.exp(-span / w.mean)
	local q = math.clamp(u, 0, 1) * top
	return w.floor + math.min(span, -w.mean * math.log(1 - q))
end

-- 지난 sec초 동안 그 사람이 서 본 가로 범위(같은 층 — y에서 위아래 half점 안의 칸): 가장 왼쪽 · 가장 오른쪽(점) · 없으면 nil
--  별똥별을 다녀간 적 없는 자리에 떨어뜨리는 데 쓴다(2026-11-13 — server runeGuard.luau)
function Macro.rangeX(st, now: number, sec: number, y: number, half: number?): (number?, number?)
	local c = D.suspect.still.cell
	local h = half or 48
	local lo, hi = nil, nil
	for key, t in st.moves do
		if now - t <= sec then
			local cx, cy = string.match(key, "^(-?%d+),(-?%d+)$")
			if cx and math.abs((tonumber(cy) :: number) * c + c / 2 - y) <= h then
				local x0 = (tonumber(cx) :: number) * c
				lo = if lo == nil then x0 else math.min(lo, x0)
				hi = if hi == nil then x0 + c else math.max(hi, x0 + c)
			end
		end
	end
	return lo, hi
end

-- 손의 기록(2026-11-13 — 화면 client inputStat.luau가 every초마다 보낸다 · server macroGuard.luau가 사냥 맵에서만 부른다): 꼴이 바르면 그날의 칸에 더한다 → 더했나
--  v = { kt, kz, tt, ts } — 정수 · 0 ~ max · kz ≤ kt · ts ≤ tt
function Macro.inputNote(st, v: any, now: number): boolean
	if typeof(v) ~= "table" then
		return false
	end
	local IN = D.input
	local function whole(x): number?
		return if typeof(x) == "number" and x == x and x % 1 == 0 and x >= 0 and x <= IN.max then x else nil
	end
	local kt, kz, tt, ts = whole(v.kt), whole(v.kz), whole(v.tt), whole(v.ts)
	if not kt or not kz or not tt or not ts or kz > kt or ts > tt or kt + tt == 0 then
		return false
	end
	Macro.note(st, "kt", kt, now)
	Macro.note(st, "kz", kz, now)
	Macro.note(st, "tt", tt, now)
	Macro.note(st, "ts", ts, now)
	return true
end
-- 길 위의 별똥별을 주웠다(사람의 증거로 치지 않는다 — 날마다 br2에만)
function Macro.baitRoute(st, now: number)
	Macro.note(st, "br2", 1, now)
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
	st.check = { token = token, top = top, cells = cells, answer = answer, deadline = now + D.time, tries = D.tries, kills = 0 }
	Macro.note(st, "ci", 1, now) -- (계정의 기록 — 2026-11-09)
	st.saved.hs, st.saved.dr = 0, nil -- 다음 차례는 다시 0부터 · 새로 뽑는다(2026-11-13)
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
--  answered = 세 번 틀렸다(대답은 했다). 시간이 다 된 놓침은 떠 있는 동안 activeKills마리 넘게 잡았을 때만 점수의 놓침(cf) — 아니면 자리를 비운 것(ca · 2026-11-13)
function Macro.fail(st, now: number, answered: boolean?): (number, number)
	-- 사다리(10분 · 1시간 · 6시간)는 「문제가 떠 있는 동안에도 사냥을 이어 간」 놓침만(2026-11-14 사용자: "지금 매크로가 아니라 애먼사람만 정지시키고있는데?" — 유저 글 "매크로가 너무 많이 뜹니다 무슨 3분에 한번씩 떠요 매크로 하고 잠깐 자리 비우면 6시간 정지에요") —
	--  전에는 자리를 비워 놓친 것 · 세 번 틀린 것도 세어, 하루에 네 번 자리를 비우면 6시간 보상 멈춤이었다. 그 놓침은 이제 0초(돌아와 「다시 확인」을 통과하면 바로 풀림)
	local active = ((st.check and st.check.kills) or 0) >= D.record.activeKills
	st.check = nil
	local m = st.saved
	local keep = {}
	for _, t in m.fails do
		if now - t < D.forget then
			table.insert(keep, t)
		end
	end
	if active then
		table.insert(keep, now)
	end
	m.fails = keep
	Macro.note(st, if active then "cf" else "ca", 1, now) -- (계정의 기록 — 2026-11-09 · 2026-11-13 자리 비움은 ca · 2026-11-14 세 번 틀림도 사냥을 잇지 않았으면 ca)
	local wait = if active then D.stop[math.min(#keep, #D.stop)] else 0
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
		st.passAt = now
		st.rest = now -- 다음 확인은 다시 쉬지 않은 사냥 시간을 채운 뒤
		st.saved.stopped, st.saved.stopUntil, st.saved.pending = false, 0, false
		st.stopKills = 0
		Macro.note(st, "cp", 1, now) -- (계정의 기록 — 2026-11-09)
		return "pass"
	end
	c.tries -= 1
	if c.tries <= 0 then
		Macro.fail(st, now, true)
		return "fail"
	end
	return "wrong"
end

-- 보상이 멈췄나 · 문제가 떠 있나(떠 있는 동안도 보상은 없다 — 대신 맞지 않는다)
function Macro.stopped(st): boolean
	return st.saved.stopped
end
-- 보상 멈춤이 된 뒤로(이 접속에서) 잡은 수 — 통과하거나 풀리면 0
function Macro.stopKills(st): number
	return if st.saved.stopped then st.stopKills or 0 else 0
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
	st.saved.dr = nil
	st.force = false
	st.saved.stopped, st.saved.stopUntil, st.saved.pending = false, 0, false
	st.saved.fails = {}
	st.stopKills = 0
end

-- ---------- 감옥(2026-11-11 사용자: "매크로 점수 너무 높으면 사냥 정지 아무것도 없는 검정방에 가둬버려 처음엔 5분가두고 그다음에 또 높으면 10분가두고") ----------
--  공방 design/macro.js의 jail. 종합 점수(Macro.total — 지난 7일)가 JL.min 넘고 · 이 접속(또는 지난 감옥)에서 사냥한 1분이 JL.hunt분 차면 가둔다.
--  n번째 감옥의 길이 = JL.time[n](넘으면 마지막 것 — 5분 · 10분 · 10분 …). 시계는 os.time이라 접속하지 않아도 흐른다.
--  옮기는 것은 서버(modules/macroGuard.luau Guard.jailWant · world.luau World.jailStep) — 여기는 셈만.
local JL = D.jail
local function jailOf(st)
	st.saved.jail = st.saved.jail or Macro.newJail()
	return st.saved.jail
end
function Macro.jailed(st, now: number): boolean
	return jailOf(st).untilT > now
end
function Macro.jailLeft(st, now: number): number
	return math.max(0, jailOf(st).untilT - now)
end
-- 계정 자료(저장된 것 · 아직 세션이 읽지 않은 것)만으로: 지금 갇혀 있나(들어올 때 검정 방에서 시작하게 — world.luau)
function Macro.jailedRaw(raw: any, now: number): boolean
	local j = typeof(raw) == "table" and raw.jail
	return typeof(j) == "table" and typeof(j.untilT) == "number" and j.untilT > now
end
-- 사냥한 1분(사냥 맵 · 사냥 중 — 서버가 1분마다)
function Macro.jailMinute(st)
	st.jailHunt = (st.jailHunt or 0) + 1
end
-- 가둘 때인가: 종합 점수 ≥ min · 사냥한 1분이 hunt분 · 갇혀 있지 않다 · 매크로 확인이 떠 있지 않다
function Macro.jailDue(st, now: number): boolean
	local t = st.total
	return t ~= nil and t.score >= JL.min and not t.human and t.proof ~= false and (st.jailHunt or 0) >= JL.hunt and not Macro.jailed(st, now) and not Macro.pending(st) -- (사람으로 보면 · 증거가 없으면 넣지 않는다 — 2026-11-12 · 2026-11-14)
end
-- 이번 감옥의 길이(초): n번째(1부터)
function Macro.jailTime(n: number): number
	return JL.time[math.clamp(n, 1, #JL.time)]
end
-- 가둔다: from = 잡혀 온 자리 { k, x, y } → 길이(초) · 몇 번째
function Macro.jailStart(st, now: number, from, sec0: number?): (number, number)
	local j = jailOf(st)
	j.n += 1
	local sec = sec0 or Macro.jailTime(j.n) -- (sec0 = 관리자가 정한 길이 — 2026-11-12 관리 창의 「감옥 10분 · 60분」)
	j.untilT = now + sec
	j.from = from
	table.insert(j.log, { t = now, s = if st.total then st.total.score else 0, sec = sec })
	while #j.log > JL.keep do
		table.remove(j.log, 1)
	end
	st.jailHunt = 0
	return sec, j.n
end
-- 시간이 다 됐다 · 관리자가 풀었다: 잡혀 온 자리를 돌려준다(한 번만 — 꺼낸 뒤에는 nil)
function Macro.jailFree(st)
	jailOf(st).untilT = 0
end
function Macro.jailTakeFrom(st)
	local j = jailOf(st)
	local f = j.from
	j.from = nil
	return f
end

return Macro
