-- 「달의 계승자」 — 매크로를 정확하게(2026-11-13 사용자: "매크로 방지 그림이 정해진 패턴으로 나와서 … 10분 나와버리면 9분 매크로 돌리고 게임 나갔다가 들어와서 다시 9분" ·
--  "룬한번 사람이 까버리고 가호 받은상태에서 15분 매크로 돌려버리고 15분 끝나기전에 게임 껐다가 다시들어와서" · "지금 창내림 세는것도 의미가 없고" ·
--  "지금 거의 무슨 무고밴이 더많아 일반 유저를 매크로라고 낙인을 찍는경우가 많고 진짜 매크로는 잡지도못하고").
--  sim/macro.luau(dueOf · hs · fail의 cf/ca · inputNote · total) · client inputStat.luau · sim/rune.luau(owes · place) · server runeGuard.luau(사람 시계 · 길 밖의 별똥별)
--  보는 것: ① 확인의 때 — 지수 분포(floor ~ cap) · 「n분까지는 안전」이 없다 ② 사냥한 초는 쉬어도 · 다시 들어와도 이어진다 · 확인이 뜨면 0
--   ③ 놓침: 떠 있는 동안 잡았으면 cf(점수) · 자리를 비웠으면 ca(점수 밖) ④ 무게: 행동만으로는 45 · 창 밖은 0 · 손의 기록(키 · 터치)
--   ⑤ 화면의 손의 기록(한 프레임 · 느린 화면 · 같은 점 · 바로 앞의 것은 빼고) ⑥ 별똥별은 다니지 않던 자리에 · 없으면 「길 위」(주워도 사람의 증거가 아니다)
--   ⑦ 룬의 사람 시계(계정에 남는다 — 다시 들어와도 · 채널을 옮겨도 15분이면 그 맵에 바로 룬)
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local Rune = req("ReplicatedStorage/shared/lune/sim/rune")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local D = Macro.DATA
local RC = D.record
local fired = {}
MOCK("ReplicatedStorage/shared/lune/net/net", { FireClient = function(name, player, v) table.insert(fired, { name = name, player = player, v = v }) end, OnServer = function() end })

local function hunt(st, t0, sec, every)
	local t = t0
	while t < t0 + sec do
		Macro.onKill(st, t)
		t += every
	end
	return t
end

-- ① 확인의 때
do
	for _, lv in { "low", "mid", "high" } do
		local w = D.wait[lv]
		eq(Macro.dueOf(lv, 0), w.floor, lv .. ": u = 0 → floor")
		expect(math.abs(Macro.dueOf(lv, 1) - w.cap) < 1e-6, lv .. ": u = 1 → cap")
		local prev = -1
		for i = 0, 20 do
			local d = Macro.dueOf(lv, i / 20)
			expect(d >= prev, lv .. ": u가 크면 늦다")
			prev = d
		end
	end
	expect(Macro.dueOf("low", 0.5) < Macro.dueOf("low", 0.5) + 1 and Macro.dueOf("high", 0.5) < Macro.dueOf("mid", 0.5) and Macro.dueOf("mid", 0.5) < Macro.dueOf("low", 0.5), "의심이 높으면 같은 차례의 때가 이르다")
	-- 「n분까지는 안전」이 없다: 의심 낮음에서 floor(5분) 뒤 첫 2분 안에 뜰 몫이 10% 넘는다(전에는 15분 전에는 0%)
	local rng = Random.new(7)
	local early, sum, N = 0, 0, 4000
	for _ = 1, N do
		local d = Macro.dueOf("low", rng:NextNumber())
		sum += d
		if d < D.wait.low.floor + 120 then
			early += 1
		end
	end
	print(("[MACRO] 의심 낮음의 확인: 평균 %.1f분 · 5 ~ 7분 사이 %.1f%%"):format(sum / N / 60, early / N * 100))
	expect(early / N > 0.1, "의심 낮음: 15 ~ 17분 사이에도 10% 넘게 뜬다(정해진 때가 없다)")
	expect(sum / N > 20 * 60 and sum / N < 30 * 60, "의심 낮음의 평균은 약 25분(2026-11-13 낮 사용자 \"너무 자주뜬다\" — 전에는 사실상 15 ~ 25분)")
	-- 지난 확인 뒤 적어도: 낮음 15분 · 중간 10분 · 높음 5분(2026-11-13 낮)
	expect(D.wait.low.floor >= 900 and D.wait.mid.floor >= 600 and D.wait.high.floor >= 300, "확인과 확인 사이 적어도 15 · 10 · 5분")
end

-- ② 사냥한 초: 쉬어도 · 다시 들어와도 이어진다 · 확인이 뜨면 0
do
	local st = Macro.new(0, nil)
	local t = hunt(st, 0, 540, 6) -- 9분
	local h1 = st.saved.hs
	expect(h1 >= 530 and h1 <= 540, "9분 사냥 = 사냥한 초 약 540(" .. h1 .. ")")
	-- 나갔다 20분 뒤 들어온다(이어 사냥도 아니다 — 15분 넘게 쉬었다)
	local back = Macro.new(t + 1200, Macro.unpack(Macro.pack(st.saved)))
	expect(not back.relogged, "20분 쉬었다 = 이어 사냥은 아니다")
	eq(back.saved.hs, h1, "그래도 사냥한 초는 그대로(계정에 남는다)")
	local dr = 0.3
	back.saved.dr = dr
	local t2 = hunt(back, t + 1200, 540, 6)
	expect(back.saved.hs >= 2 * 530, "또 9분 → 18분(" .. back.saved.hs .. ")")
	local due = Macro.dueOf(Macro.level(back, t2), dr)
	eq(Macro.tick(back, t2, { hunt = true }, function() return dr end) == "issue", back.saved.hs >= due, "때를 넘었으면 확인(9분 하고 쉬기를 되풀이해도 쌓인다)")
	-- 확인이 뜨면 0 · 새로 뽑는다
	Macro.issue(back, t2, function(n) return n end)
	eq(back.saved.hs, 0, "확인이 뜨면 사냥한 초 0")
	eq(back.saved.dr, nil, "다음 차례는 새로 뽑는다")
	-- 처치 사이가 huntGap초 넘으면 더하지 않는다
	local s3 = Macro.new(0, nil)
	Macro.onKill(s3, 0)
	Macro.onKill(s3, D.huntGap + 5)
	eq(s3.saved.hs, 0, "처치 사이가 1분 넘으면(쉼) 더하지 않는다")
	local bad = Macro.unpack({ hs = -5, dr = 3 })
	expect(bad.hs == 0 and bad.dr == nil, "꼴이 틀린 것은 버린다")
end

-- ③ 놓침: 잡으면서 무시 = cf · 자리 비움 = ca
do
	local now = 1700000000
	local st = Macro.new(now, nil)
	Macro.issue(st, now, function(n) return n end)
	Macro.fail(st, now + 61)
	local d = st.saved.days[Macro.dayKey(now)]
	expect((d.ca or 0) == 1 and (d.cf or 0) == 0, "떠 있는 동안 잡지 않았다 = 자리를 비웠다(ca — 점수에 넣지 않는다)")
	st.saved.stopped = false
	Macro.issue(st, now + 100, function(n) return n end)
	for i = 1, RC.activeKills do
		Macro.onKill(st, now + 100 + i * 5)
	end
	Macro.fail(st, now + 161)
	expect((d.cf or 0) == 1, "떠 있는 동안 activeKills마리 잡았다 = 잡으면서 무시했다(cf)")
	-- 자리 비움만 여러 번이면 확인 항목은 0
	local s2 = Macro.newSaved()
	s2.days[Macro.dayKey(now)] = { ci = 6, ca = 6, cf = 0, m = 60 }
	eq(Macro.total(s2, now).parts.check, 0, "자리를 비워 놓친 것은 확인 항목에 넣지 않는다")
	-- 세 번 틀린 것은 대답을 한 것 = cf
	local s4 = Macro.new(now, nil)
	local v = Macro.issue(s4, now, function(n) return n end)
	local wrong = {}
	for i, c in v.cells do
		if not table.find(v.top, c.kind) and #wrong < 3 then
			table.insert(wrong, i)
		end
	end
	for _ = 1, D.tries do
		Macro.answer(s4, v.token, wrong, now + 1)
	end
	eq(s4.saved.days[Macro.dayKey(now)].ca or 0, 1, "세 번 틀림이라도 그동안 사냥하지 않았으면 ca(2026-11-14 사용자 — 애먼 사람이 걸린다 — 전에는 cf)")
	eq(s4.saved.days[Macro.dayKey(now)].cf or 0, 0, "cf(확인 점수 · 사다리)에 들지 않는다")
end

-- ④ 무게
do
	local now = 1700000000
	local key = Macro.dayKey(now)
	local s = Macro.newSaved()
	s.days[key] = { m = 600, ls = 600 } -- 행동 로그 점수 평균 1(되풀이하는 사냥 — 사람도 높다)
	local t = Macro.total(s, now)
	eq(t.score, 45, "행동만으로는 45(주의) — 감옥(80)에 닿지 않는다")
	s.days[key].bl = 50
	eq(Macro.total(s, now).score, 45, "창 밖 입력은 점수에 없다")
	-- 손의 기록
	local st = Macro.new(now, s)
	expect(not Macro.inputNote(st, { kt = 10, kz = 11, tt = 0, ts = 0 }, now), "kz > kt는 버린다")
	expect(not Macro.inputNote(st, { kt = 1.5, kz = 0, tt = 0, ts = 0 }, now), "정수가 아니면 버린다")
	expect(not Macro.inputNote(st, { kt = D.input.max + 1, kz = 0, tt = 0, ts = 0 }, now), "너무 크면 버린다")
	expect(not Macro.inputNote(st, "x", now), "표가 아니면 버린다")
	expect(Macro.inputNote(st, { kt = 200, kz = 2, tt = 0, ts = 0 }, now), "바른 꼴은 받는다")
	eq(Macro.total(s, now).parts.input, 0, "누른 수가 need보다 적으면 보지 않는다")
	Macro.inputNote(st, { kt = 200, kz = 2, tt = 0, ts = 0 }, now)
	eq(Macro.total(s, now).parts.input, 0, "사람처럼(한 프레임 1%) = 0")
	local sk = Macro.newSaved() -- (날마다의 칸은 더해진다 — 새 계정으로)
	sk.days[key] = { m = 600, ls = 600 }
	Macro.inputNote(Macro.new(now, sk), { kt = 400, kz = 396, tt = 0, ts = 0 }, now)
	local ti = Macro.total(sk, now)
	expect(ti.parts.input > 0.9, ("키를 거의 모두 한 프레임 안에 = 손 항목 1에 가깝다(%.2f)"):format(ti.parts.input))
	expect(ti.score >= 80, "행동 + 손 = 감옥의 선(" .. ti.score .. ")")
	-- 터치
	local s5 = Macro.newSaved()
	local st5 = Macro.new(now, s5)
	Macro.inputNote(st5, { kt = 0, kz = 0, tt = 400, ts = 80 }, now)
	eq(Macro.total(s5, now).parts.input, 0, "같은 점 20% = 손가락(0)")
	local s6 = Macro.newSaved()
	Macro.inputNote(Macro.new(now, s6), { kt = 0, kz = 0, tt = 400, ts = 390 }, now)
	expect(Macro.total(s6, now).parts.input > 0.9, "같은 점을 거의 늘 = 오토 클리커")
	-- 사람으로 봄: 손 항목이 있으면 아니다
	local sh = Macro.newSaved()
	sh.days[key] = { m = 300, ls = 300, ci = 5, cp = 5, cf = 0, bg = 12, bm = 0 }
	sh.br = string.rep("1", 12)
	expect(Macro.total(sh, now).human, "미끼 · 확인 · 룬 · 손이 깨끗하면 사람")
	sh.days[key].kt, sh.days[key].kz = 400, 380
	expect(not Macro.total(sh, now).human, "손 항목이 있으면 사람으로 보지 않는다")
	local view = Macro.recordView(sh, now)
	expect(view.parts.input > 0 and view.days[1].kt == 400 and view.days[1].kz == 380, "관리 창의 기록에 손 항목 · 날마다 키의 수")
end

-- ⑤ 화면의 손의 기록(client inputStat.luau)
do
	SERVICE("UserInputService", { InputBegan = { Connect = function() end }, InputEnded = { Connect = function() end }, GetFocusedTextBox = function() return nil end })
	local IS = req("Client/lune/inputStat")
	local c = IS.new()
	IS.keyDown(c, "Z", 1.0)
	IS.keyUp(c, "Z", 1.0004) -- 같은 프레임(0.4ms)
	IS.keyDown(c, "X", 2.0)
	IS.keyUp(c, "X", 2.09) -- 사람(90ms)
	IS.keyDown(c, "C", 3.0)
	IS.keyUp(c, "C", 3.0001, true) -- 화면이 느린 때 — 세지 않는다
	IS.keyUp(c, "V", 4.0) -- 누른 적 없는 뗌 — 세지 않는다
	local out = IS.take(c)
	expect(out and out.kt == 2 and out.kz == 1, "누른 수 2 · 한 프레임 1(느린 화면 · 짝 없는 뗌은 뺀다)")
	eq(IS.take(c), nil, "꺼낸 뒤 0 — 없으면 보내지 않는다")
	-- 터치: 같은 점(바로 앞의 것은 빼고)
	local c2 = IS.new()
	IS.touch(c2, 100.2, 200.4)
	IS.touch(c2, 100.4, 200.1) -- 바로 앞과 같은 점 — 세지 않는다(사람도 잇달아 같은 곳을 누른다)
	IS.touch(c2, 300, 50)
	IS.touch(c2, 100, 200) -- 앞앞과 같은 점 = 되풀이
	local o2 = IS.take(c2)
	expect(o2 and o2.tt == 4 and o2.ts == 1, "터치 4 · 같은 점 1(" .. tostring(o2 and o2.ts) .. ")")
	-- 오토 클리커: 두 점을 번갈아
	local c3 = IS.new()
	for i = 1, 100 do
		IS.touch(c3, if i % 2 == 0 then 500 else 520, 300)
	end
	local o3 = IS.take(c3)
	expect(o3.ts >= 95, "두 점을 번갈아 누르는 오토 클리커 = 거의 모두 같은 점(" .. o3.ts .. ")")
end

-- ⑥ 별똥별: 다니지 않던 자리에
do
	local RG = req("ServerScriptService/server/lune/modules/runeGuard")
	local M = Rune.DATA.bait.route.margin
	local room = { onFloor = function(_, x) return math.clamp(x, 0, 800) end } -- (0 ~ 800점의 층)
	local now = 1700000000
	local st = Macro.new(now, nil)
	for x = 200, 300, 8 do
		Macro.onMove(st, x, 160, now - 10)
	end
	local a, b = Macro.rangeX(st, now, 300, 160)
	expect(a and b and a <= 200 and b >= 300 and a >= 160 and b <= 352, ("서 본 가로 범위(%s ~ %s)"):format(tostring(a), tostring(b)))
	local hero = { x = 250, y = 160 }
	for _ = 1, 50 do
		local x, route = RG.offRoute(room, st, hero, now)
		expect(x ~= nil and route == false, "자리가 있다")
		if x then
			expect((x <= a - M or x >= b + M) and x >= 0 and x <= 800 and math.abs(x - hero.x) <= Rune.DATA.bait.route.far, ("다니지 않던 자리 · 같은 층 · 곁(%d)"):format(x))
		end
	end
	-- 층 전체를 다녔다 → 자리가 없다(길 위로 — 곁에 떨어뜨리고 주워도 사람의 증거가 아니다)
	local st2 = Macro.new(now, nil)
	for x = 0, 800, 16 do
		Macro.onMove(st2, x, 160, now - 10)
	end
	local x2 = RG.offRoute(room, st2, hero, now)
	eq(x2, nil, "층 전체를 다니면 다니지 않던 자리가 없다")
	-- 오래전에 다닌 칸은 보지 않는다
	local a3 = Macro.rangeX(st2, now + 1000, 300, 160)
	eq(a3, nil, "route.sec초보다 오래된 칸은 보지 않는다")
	-- 다른 층의 칸은 보지 않는다
	local st3 = Macro.new(now, nil)
	Macro.onMove(st3, 600, 400, now - 5)
	eq(Macro.rangeX(st3, now, 300, 160), nil, "다른 층의 칸은 보지 않는다")
	-- 길 위의 것을 주우면 br2만(사람의 증거 bg · br에는 넣지 않는다)
	local ms = Macro.new(now, nil)
	Macro.baitRoute(ms, now)
	local d = ms.saved.days[Macro.dayKey(now)]
	expect(d.br2 == 1 and (d.bg or 0) == 0 and ms.saved.br == "", "길 위 미끼를 주웠다 = br2만")
end

-- ⑦ 룬의 사람 시계
do
	local R = Rune.DATA.rune
	eq(R.own, 900, "룬을 푼 뒤 15분 사냥하면 그 사람 몫의 룬")
	local m, p = Rune.newMap(), Rune.newPlayer()
	p.h = R.own - 1
	expect(not Rune.owes(m, p), "15분이 되기 전에는 아니다")
	p.h = R.own
	expect(Rune.owes(m, p), "15분 = 그 맵에 룬이 없으면 바로")
	Rune.place(m, 100, 10, 20)
	expect(not Rune.owes(m, p) and m.rune and m.rune.x == 10, "룬이 놓였다(이미 있으면 더 놓지 않는다)")
	local arrows = Rune.start(m, p, 100, 10, 20, function() return 1 end)
	eq(Rune.answer(m, p, arrows, 101), "done", "해방")
	eq(p.h, 0, "해방하면 그 사람의 시계 0")
	-- 서버: 계정에 남고(다시 들어와도 · 채널을 옮겨도) 15분이면 새 맵에 바로
	local RG = req("ServerScriptService/server/lune/modules/runeGuard")
	local sessions = {}
	RG.bind({ roomOf = function() return nil end, sessionsIn = function(key)
		local out = {}
		for _, x in sessions do
			if x.scene == key then
				table.insert(out, x)
			end
		end
		return out
	end })
	local function now0()
		return 1700000000 + math.floor(clock.now)
	end
	local saved = Macro.newSaved()
	saved.rn = { c = 0, g = 0, b = 0, h = R.own - 20 } -- (지난 접속에서 룬을 푼 뒤 14분 40초 사냥했다)
	local hero = Hero.new(91, "axion")
	hero.level = 30
	local s = { player = { UserId = 91 }, scene = "r1a3#c4", hero = hero, macro = Macro.new(now0(), saved) } -- (새 채널 — 그 맵에는 아직 아무도 사냥하지 않았다)
	table.insert(sessions, s)
	local placed = false
	for _ = 1, 40 do
		table.insert(s.macro.kills, now0())
		clock.now += 1
		RG.tick(s, s.scene)
		for _, f in fired do
			if f.name == "RuneMap" and f.player == s.player and typeof(f.v) == "table" and f.v.rune then
				placed = true
			end
		end
	end
	expect(placed, "다시 들어와 새 채널에서 20초 더 사냥하자 그 맵에 바로 룬(전에는 그 맵에서 다시 15분)")
	expect(s.macro.saved.rn.h >= R.own, "룬을 푼 뒤 사냥한 초가 계정에 남는다(" .. tostring(s.macro.saved.rn.h) .. ")")
	-- 쿨 · 가호도 계정에서 읽는다
	local saved2 = Macro.newSaved()
	saved2.rn = { c = now0() + 600, g = now0() + 600, b = 0, h = 0 }
	local s2 = { player = { UserId = 92 }, scene = "r1a3", hero = Hero.new(92, "axion"), macro = Macro.new(now0(), saved2) }
	RG.tick(s2, s2.scene)
	eq(s2.rune.cdUntil, saved2.rn.c, "다시 들어와도 룬의 쿨이 그대로(전에는 접속마다 0)")
	eq(s2.rune.guardUntil, saved2.rn.g, "가호도 그대로")
	local packed = Macro.unpack(Macro.pack(saved2))
	expect(packed.rn and packed.rn.c == saved2.rn.c, "저장했다 읽어도 같다")
	expect(Macro.unpack({ rn = { c = "x", g = -1 } }).rn.c == 0, "꼴이 틀린 값은 0")
end
