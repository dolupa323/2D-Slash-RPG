-- 「달의 계승자」 — 매크로의 행동 로그 분석(2026-11-09 사용자: "다른 상용화게임들이 매크로 방지책으로 사용하는 알고리즘같은게 있을거아니야 로그나")
--  shared/lune/sim/macro.luau의 Macro.act · Macro.cell · Macro.logScore(공방 design/macro.js의 log):
--   ① 자기 유사도(NCSOFT NDSS 2016) ② 같은 고리(NetEase NGUARD) ③ 같은 길(Mitterhofer 2009) — 합친 점수는 매크로 확인을 일찍 띄우는 데에만(날파리 · 벌에는 쓰지 않는다)
--  보는 것: 녹화 · 재생 매크로 = 「의심 높음」 · 보통 사람(섞인 행동 · 돌아다님 · 흔들리는 간격) = 로그로는 의심하지 않는다 · 한자리에서 한 키만 = 「의심 높음」까지는 아니다
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local D = Macro.DATA
local LG = D.log
local T0 = 1000000

expect(LG ~= nil and LG.level.mid < LG.level.high, "설계의 log(문턱 둘)")

local function cellX(i: number): number
	return i * LG.cell + 10
end
-- secs초를 0.05초 걸음으로: plan(t, rng) = 그 걸음에 할 일 { act = kind?, cell = 칸 번호?, kill = true? }
local function run(secs: number, seed: number, plan)
	local st = Macro.new(T0, nil)
	local rng = Random.new(seed)
	local t = 0
	while t < secs do
		local now = T0 + math.floor(t)
		local e = plan(t, rng)
		if e then
			if e.act then
				Macro.act(st, e.act, t, now)
				if string.sub(e.act, 1, 2) == "s:" then
					Macro.onSkill(st, string.sub(e.act, 3), t)
				end
			end
			if e.cell then
				Macro.onMove(st, cellX(e.cell), 176, now)
				Macro.cell(st, cellX(e.cell), 176, t, now)
			end
			if e.kill then
				Macro.onKill(st, now)
			end
		end
		t += 0.05
	end
	return st, T0 + math.floor(secs)
end

-- ① 녹화 · 재생 매크로: 같은 다섯 행동을 0.8초마다(±0.02초 — 서버가 받는 때의 흔들림) · 같은 여섯 칸의 길을 0.67초마다 · 3초마다 처치
do
	local LOOP = { "s:axe", "s:spin", "pick", "s:axe", "s:slam" }
	local ROUTE = { 1, 2, 3, 4, 3, 2 }
	local nextAct, nextMove, nextKill, ia, im = 0, 0, 0, 0, 0
	local st, now = run(20 * 60, 7, function(t, rng)
		local e = nil
		if t >= nextAct then
			ia = ia % #LOOP + 1
			e = { act = LOOP[ia] }
			nextAct = t + 0.8 + rng:NextNumber(-0.02, 0.02)
		end
		if t >= nextMove then
			im = im % #ROUTE + 1
			e = e or {}
			e.cell = ROUTE[im]
			nextMove = t + 0.67 + rng:NextNumber(-0.02, 0.02)
		end
		if t >= nextKill then
			e = e or {}
			e.kill = true
			nextKill = t + 3
		end
		return e
	end)
	local r = Macro.logScore(st, now)
	expect(r ~= nil, "매크로: 점수가 있다")
	if r then
		print(("[MACROLOG] 매크로: 점수 %.2f · 1분 되풀이 %s · 고리 %s · 길 %s"):format(r.score,
			if r.sim then ("%.3f(±%.3f)"):format(r.sim.mean, r.sim.sd) else "-",
			if r.loop then ("%.0f%% ±%.1f%% %d바퀴(길이 %d)"):format(r.loop.cover * 100, r.loop.cv * 100, r.loop.laps, r.loop.len) else "-",
			if r.route then ("%.0f%% ±%.1f%% %d바퀴(길이 %d)"):format(r.route.cover * 100, r.route.cv * 100, r.route.laps, r.route.len) else "-"))
		expect(r.score >= LG.level.high, ("매크로: 합친 점수 %.2f ≥ %.2f(의심 높음)"):format(r.score, LG.level.high))
		expect(r.loop ~= nil and r.loop.score > 0.8, "매크로: 같은 고리를 같은 시간에 돈다")
		expect(r.route ~= nil and r.route.score > 0.8, "매크로: 같은 길을 같은 시간에 돈다")
		expect(r.sim ~= nil and r.sim.mean > 0.98, "매크로: 1분마다 같은 비율")
	end
	eq(Macro.level(st, now), "high", "매크로: 의심 높음 → 매크로 확인을 일찍(3 ~ 5분)")
	expect(Macro.level(st, now, true) ~= "high", "날파리의 셈(noLong)에는 로그를 쓰지 않는다")
	-- every초 동안은 앞의 셈을 그대로
	local again = Macro.logScore(st, now + LG.every - 1)
	expect(again == r, "every초 안에는 다시 셈하지 않는다")
end

-- ② 보통 사람: 스킬 셋 · 줍기 · 물약을 섞어 0.4 ~ 1.8초마다 · 열 칸 사이를 0.3 ~ 2초마다 이리저리 · 2 ~ 5초마다 처치
do
	local KINDS = { "s:axe", "s:axe", "s:axe", "s:spin", "s:spin", "s:slam", "pick", "pick", "potion" }
	local nextAct, nextMove, nextKill, at = 0, 0, 0, 5
	local st, now = run(20 * 60, 11, function(t, rng)
		local e = nil
		if t >= nextAct then
			e = { act = KINDS[rng:NextInteger(1, #KINDS)] }
			nextAct = t + rng:NextNumber(0.4, 1.8)
		end
		if t >= nextMove then
			at = math.clamp(at + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextInteger(1, 2), 0, 9)
			e = e or {}
			e.cell = at
			nextMove = t + rng:NextNumber(0.3, 2)
		end
		if t >= nextKill then
			e = e or {}
			e.kill = true
			nextKill = t + rng:NextNumber(2, 5)
		end
		return e
	end)
	local r = Macro.logScore(st, now)
	if r then
		print(("[MACROLOG] 사람: 점수 %.2f · 1분 되풀이 %s · 고리 %s · 길 %s"):format(r.score,
			if r.sim then ("%.3f(±%.3f)"):format(r.sim.mean, r.sim.sd) else "-",
			if r.loop then ("%.0f%% ±%.1f%%"):format(r.loop.cover * 100, r.loop.cv * 100) else "-",
			if r.route then ("%.0f%% ±%.1f%%"):format(r.route.cover * 100, r.route.cv * 100) else "-"))
	end
	expect(r == nil or r.score < LG.level.mid, ("사람: 로그로는 의심하지 않는다(점수 %.2f < %.2f)"):format(r and r.score or 0, LG.level.mid))
end

-- ③ 한자리에서 한 키만(사람 — 0.6 ~ 1.0초마다 · 움직이지 않는다): 1분은 비슷하지만 고리(서로 다른 행동 셋)도 길도 없다 → 「의심 높음」까지는 아니다
do
	local nextAct, nextKill, moved = 0, 0, false
	local st, now = run(20 * 60, 23, function(t, rng)
		local e = nil
		if t >= nextAct then
			e = { act = "s:axe" }
			nextAct = t + rng:NextNumber(0.6, 1.0)
		end
		if not moved then
			moved = true
			e = e or {}
			e.cell = 3
		end
		if t >= nextKill then
			e = e or {}
			e.kill = true
			nextKill = t + rng:NextNumber(2, 4)
		end
		return e
	end)
	local r = Macro.logScore(st, now)
	if r then
		print(("[MACROLOG] 한 키만: 점수 %.2f · 1분 되풀이 %s"):format(r.score, if r.sim then ("%.3f(±%.3f)"):format(r.sim.mean, r.sim.sd) else "-"))
	end
	expect(r == nil or r.score < LG.level.high, ("한 키만: 로그로는 「의심 높음」까지 가지 않는다(점수 %.2f < %.2f)"):format(r and r.score or 0, LG.level.high))
	expect(r == nil or r.loop == nil or r.loop.score == 0, "한 키만: 같은 고리는 없다(서로 다른 행동 셋 이상만 고리)")
end

-- ④ 행동이 없으면 점수도 없다 · 10분이 안 되면 1분 되풀이는 아직 보지 않는다
do
	local st = Macro.new(T0, nil)
	eq(Macro.logScore(st, T0 + 60), nil, "행동이 없으면 nil")
	for i = 0, 5 * 60 do
		Macro.act(st, "s:axe", i, T0 + i)
		if i % 3 == 0 then
			Macro.onKill(st, T0 + i)
		end
	end
	local r = Macro.logScore(st, T0 + 5 * 60 + 1)
	expect(r ~= nil and r.sim == nil, "사냥한 1분이 minuteMin개 안 되면 1분 되풀이는 아직(nil)")
end

-- ⑤ 계정마다의 매크로 기록 · 종합 점수 · 경고(2026-11-09 사용자: "계정마다 종속된 로그기록이랑 점수를 내가 계속 볼수있어야해 초기화되는게아니라 … 미끼 … 비율로 따져서 점수하고 …
--  심각한 유저의 경우 채팅창에 경고 주고 개선되는지도 파악할수있어야해") — sim/macro.luau Macro.minute · baitResult · total · warnDue · warnEffect · recordView · pack/unpack
do
	local RC = D.record
	expect(RC ~= nil and RC.grade.watch < RC.grade.problem and RC.grade.problem < RC.grade.severe, "설계의 record(등급 셋)")
	local DAY0 = os.time({ year = 2026, month = 11, day = 1, hour = 3 }) -- (KST 정오쯤)
	-- 매크로처럼: 이레 동안 날마다 3시간 · 로그 점수 0.9 · 룬의 저주를 두고 · 미끼를 모두 놓친다 · 확인을 놓친다
	local st = Macro.new(DAY0, nil)
	for day = 0, 6 do
		local base = DAY0 + day * 86400
		for i = 0, 179 do
			Macro.minute(st, base + i * 60, 0.9, 1.0, "hunt", { loop = { seq = "s:ax_slam|pick|hop", lap = 4, laps = 40, cv = 1, cover = 99 } })
		end
		Macro.endEp(st)
		for _ = 1, 3 do
			Macro.baitResult(st, false, base + 3600)
		end
		Macro.note(st, "ci", 1, base + 7200)
		Macro.note(st, "cf", 1, base + 7260)
	end
	local now = DAY0 + 6 * 86400 + 4 * 3600
	local t = Macro.total(st.saved, now)
	print(("[MACROLOG] 매크로의 계정: 종합 %d(%s) · 행동 %.2f · 미끼 %.2f · 확인 %.2f · 룬 %.2f"):format(t.score, t.grade, t.parts.behave, t.parts.bait, t.parts.check, t.parts.rune))
	eq(t.grade, "severe", "매크로처럼 쓴 계정 = 심각")
	expect(t.parts.bait == 1 and t.baitN == 21 and t.baitMiss == 21, "미끼 21번을 모두 놓쳤다 → 미끼 점수 1(비율)")
	eq(#st.saved.eps, 7, "날마다 한 구간(의심 구간 — 언제 · 어디서 · 어떻게)")
	local e1 = st.saved.eps[1]
	expect(e1.t0 == DAY0 and e1.t1 == DAY0 + 179 * 60 and e1.map == "hunt" and e1.peak == 90 and e1.how and e1.how.loop.seq == "s:ax_slam|pick|hop", "구간: 처음 · 끝 · 맵 · 최고 점수 · 되풀이한 고리")
	local d0 = st.saved.days[Macro.dayKey(DAY0)]
	expect(d0 and d0.m == 180 and math.abs(d0.ls - 162) < 0.01 and d0.rc == 180 and d0.bm == 3 and d0.ci == 1 and d0.cf == 1, "그날의 합(사냥 180분 · 로그 합 · 룬을 두고 180분 · 미끼 놓침 3 · 확인 받음/놓침)")
	-- 계정에 남는다(저장 → 다시 읽기)
	local back = Macro.unpack(Macro.pack(st.saved))
	local t2 = Macro.total(back, now)
	expect(t2.score == t.score and #back.eps == 7 and back.br == st.saved.br, "저장했다 다시 읽어도 같은 기록 · 같은 점수(초기화되지 않는다)")
	-- 경고: 심각 · 그날 사냥 30분 넘게 · 하루에 한 번
	st.total = t
	expect(Macro.warnDue(st, now), "심각 · 그날 사냥 → 경고할 때")
	Macro.warned(st, now, "auto")
	expect(not Macro.warnDue(st, now + 3600), "경고한 뒤 하루 안에는 다시 하지 않는다")
	eq(Macro.level(st, now), "high", "심각한 계정 = 매크로 확인을 「의심 높음」만큼 자주")
	eq(Macro.level(st, now, true), "low", "날파리의 셈(noLong)에는 종합 점수를 쓰지 않는다")
	-- 개선되었나: 경고 뒤 이레는 사람처럼(로그 점수 0.05 · 미끼를 모두 줍는다 · 룬을 푼다)
	for day = 1, 7 do
		local base = now + day * 86400
		for i = 0, 59 do
			Macro.minute(st, base + i * 60, 0.05, 0, "hunt", nil)
		end
		for _ = 1, 3 do
			Macro.baitResult(st, true, base + 1800)
		end
	end
	local later = now + 8 * 86400
	local before, after = Macro.warnEffect(st.saved, now, later)
	print(("[MACROLOG] 경고 전 이레 평균 %s → 뒤 이레 평균 %s"):format(tostring(before and math.floor(before)), tostring(after and math.floor(after))))
	expect(before ~= nil and after ~= nil and before >= RC.grade.severe and after < RC.grade.watch, "경고 전은 심각 · 뒤는 정상(나아졌다)")
	local v = Macro.recordView(st.saved, later)
	expect(v.score < RC.grade.watch and #v.days >= 7 and #v.eps >= 1 and #v.warns == 1 and v.warns[1].before ~= nil and v.warns[1].after ~= nil, "관리 창의 기록: 지금 점수 · 날마다 · 구간 · 경고(전 · 뒤)")
	-- 보통 사람의 계정(로그 0.05 · 미끼를 거의 줍는다 · 확인 통과)
	local hs = Macro.new(DAY0, nil)
	for day = 0, 6 do
		local base = DAY0 + day * 86400
		for i = 0, 119 do
			Macro.minute(hs, base + i * 60, 0.05, if i < 10 then 0.5 else 0, "hunt", nil)
		end
		Macro.baitResult(hs, true, base + 600)
		Macro.baitResult(hs, day ~= 3, base + 1200)
		Macro.note(hs, "ci", 1, base + 3000)
		Macro.note(hs, "cp", 1, base + 3030)
	end
	local ht = Macro.total(hs.saved, now)
	print(("[MACROLOG] 사람의 계정: 종합 %d(%s)"):format(ht.score, ht.grade))
	eq(ht.grade, "none", "보통 사람의 계정 = 정상")
	eq(#hs.saved.eps, 0, "보통 사람에게는 의심 구간이 없다")
	-- 미끼가 need개보다 적으면 비율을 보지 않는다
	local fs = Macro.new(DAY0, nil)
	for _ = 1, D.record.parts.bait.need - 1 do
		Macro.baitResult(fs, false, DAY0)
	end
	eq(Macro.total(fs.saved, DAY0).parts.bait, 0, "미끼가 적으면(need개 미만) 비율을 보지 않는다")
	expect(#Macro.unpack({ br = "0101abc11" }).br == 6, "꼴이 틀린 기록은 버린다")
end
