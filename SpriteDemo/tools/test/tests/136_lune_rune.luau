-- 「달의 계승자」 — 룬 · 별똥별 조각(2026-11-07 사용자: "메이플 룬을 답습해서 만들자 미끼두는 방식도 채용하자 누가봐도 먹어야되게 보이는 별똥별 조각이 떨어지고
--  그걸 안먹는 걸 로그나 정보로 수집해서 매크로 위험수치를 판단할수있게") — shared/lune/sim/rune.luau · 설계 공방 js/lune/design/rune.js
local Rune = req("ReplicatedStorage/shared/lune/sim/rune")
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local R, B = Rune.DATA.rune, Rune.DATA.bait

-- ① 설계의 숫자(메이플과 같은 것: 15분 · 넷 · 3초 · +100% 3분 · 50/70/90/100%)
eq(R.appear, 900, "룬은 그 맵에서 15분 사냥하면 나온다")
eq(R.keys, 4, "화살표 넷")
eq(R.retry, 3, "틀리면 3초 뒤 다시")
eq(R.buff.xp, 1, "해방하면 경험치 +100%")
eq(R.buff.time, 180, "3분")
eq(R.cooldown, 900, "다음 룬까지 15분")
eq(table.concat(R.curse.cut, ","), "0.5,0.7,0.9,1", "저주 50 · 70 · 90 · 100%")

-- ② 나오기: 사냥이 이어진 지 appear초 — 끊기면(B.hunt.window초 넘게 처치 없음) 다시 잰다
local m = Rune.newMap()
local spot = function()
	return 100, 160
end
local t = 1000
Rune.onKill(m, t)
for s = 1, R.appear - 1, 60 do
	Rune.onKill(m, t + s)
end
expect(not Rune.tick(m, t + R.appear - 1, spot), "15분이 되기 전에는 나오지 않는다")
Rune.onKill(m, t + R.appear)
expect(Rune.tick(m, t + R.appear, spot), "15분 이어서 사냥하면 나온다")
expect(m.rune ~= nil and m.rune.x == 100 and m.rune.y == 160, "몬스터가 서는 자리에")
local m2 = Rune.newMap()
Rune.onKill(m2, 0)
Rune.onKill(m2, 500)
Rune.onKill(m2, 500 + B.hunt.window + 1) -- 끊겼다
expect(not Rune.tick(m2, 1000, spot), "사냥이 끊기면 처음부터 다시 잰다")

-- ③ 저주: 나온 뒤 after초부터 1단계 · every초마다
local born = m.rune.born
eq(Rune.stage(m, born + R.curse.after - 1), 0, "5분 전에는 저주가 없다")
eq(Rune.stage(m, born + R.curse.after), 1, "5분이면 1단계")
eq(Rune.stage(m, born + R.curse.after + R.curse.every), 2, "다시 5분이면 2단계")
eq(Rune.stage(m, born + R.curse.after + R.curse.every * 9), #R.curse.cut, "가장 높은 단계에서 멈춘다")
local p = Rune.newPlayer()
eq(Rune.cutFor(m, p, born + R.curse.after), 0.5, "1단계 = 50% 덜")

-- ④ 해방: 멀면 못 한다 · 화살표는 서버가 고른다 · 틀리면 3초 · 맞으면 룬이 사라지고 저주가 풀린다
local now = born + R.curse.after + 10
local arrows, why = Rune.start(m, p, now, 300, 160, function(n)
	return 1
end)
expect(arrows == nil and why == "far", "멀면 시작하지 못한다")
arrows = Rune.start(m, p, now, 105, 160, function(n)
	return ((now % n) + 1)
end)
expect(arrows ~= nil and #arrows == R.keys, "화살표 넷을 받는다")
local wrong = table.clone(arrows)
wrong[1] = if wrong[1] == "up" then "down" else "up"
eq(Rune.answer(m, p, wrong, now + 1), "wrong", "틀리면 wrong")
local a2, why2 = Rune.start(m, p, now + 2, 105, 160, function()
	return 1
end)
expect(a2 == nil and why2 == "wait", "틀린 뒤 3초 안에는 다시 못 한다")
local a3 = Rune.start(m, p, now + 4, 105, 160, function()
	return 2
end)
eq(Rune.answer(m, p, a3, now + 4 + R.time + 1), "late", "시간이 지나면 late")
local late = now + 4 + R.time + 1 -- (늦은 대답의 때 — 그 뒤 retry초)
local a4 = Rune.start(m, p, late + R.retry, 105, 160, function()
	return 3
end)
eq(Rune.answer(m, p, a4, late + R.retry + 1), "done", "차례대로 맞게 누르면 해방")
eq(m.rune, nil, "룬이 사라진다")
now = late + R.retry + 1
eq(Rune.stage(m, now), 0, "맵의 저주가 풀린다")
eq(Rune.xpMul(p, now + 1), 1 + R.buff.xp, "경험치 +100%")
eq(Rune.xpMul(p, now + R.buff.time + 1), 1, "3분 뒤에는 그대로")
-- 쿨 · 가호
local m3 = Rune.newMap()
m3.rune = { x = 0, y = 0, born = now, id = 9 }
local a5, why5 = Rune.start(m3, p, now + 20, 0, 0, function()
	return 1
end)
expect(a5 == nil and why5 == "cool", "15분 안에는 다른 룬을 풀지 못한다")
eq(Rune.cutFor(m3, p, now + R.curse.after + 30), 0, "해방한 사람은 다른 맵의 저주를 받지 않는다(가호)")
local other = Rune.newPlayer()
expect(Rune.cutFor(m3, other, now + R.curse.after + 30) > 0, "가호가 없는 사람은 받는다")
-- 다른 사람이 먼저 풀면
local m4 = Rune.newMap()
m4.rune = { x = 0, y = 0, born = 0, id = 1 }
local pa, pb = Rune.newPlayer(), Rune.newPlayer()
local A = Rune.start(m4, pa, 10, 0, 0, function()
	return 1
end)
local Bk = Rune.start(m4, pb, 10, 0, 0, function()
	return 1
end)
eq(Rune.answer(m4, pa, A, 11), "done", "먼저 푼 사람")
eq(Rune.answer(m4, pb, Bk, 11), "none", "늦은 사람은 풀 것이 없다")

-- ⑤ 경험치에 붙는다(Hero.killXp): 룬의 힘 · 룬의 저주
local h = Hero.new(1, "axion")
h.level = 100
local base = Hero.killXp(h, 100, 1)
h.runeXp = 2
eq(Hero.killXp(h, 100, 1), math.floor(base * 2 + 0.5), "룬의 힘 = 경험치 두 배")
h.runeXp = nil
h.curse = 0.5
expect(math.abs(Hero.killXp(h, 100, 1) - base * 0.5) <= 1, "저주 1단계 = 경험치 반")
h.curse = nil

-- ⑥ 별똥별 조각: 사냥 중일 때만 · 떨어진 것 · 주운 것 · 놓친 것 · 의심
local q = Rune.newPlayer()
local st = Rune.newStat()
local fixed = function(a, b)
	return a
end
eq(Rune.baitTick(q, st, 0, false, fixed), nil, "사냥 중이 아니면 떨어지지 않는다")
eq(Rune.baitTick(q, st, 0, true, fixed), nil, "처음에는 다음 때를 정한다")
eq(Rune.baitTick(q, st, B.every[1], true, fixed), "drop", "때가 되면 떨어진다")
local c = Rune.baitDrop(q, st, B.every[1], 200, 160)
expect(not Rune.baitPick(q, st, B.every[1] + 1, c.id, 260, 160), "멀면 줍지 못한다")
expect(Rune.baitPick(q, st, B.every[1] + 1, c.id, 205, 160), "닿으면 줍는다")
eq(#st.got, 1, "주운 것을 센다")
-- 놓치기만 하는 사람(매크로): 한 시간 안에 mid · high
local bot = Rune.newPlayer()
local bs = Rune.newStat()
local tt = 10000
for i = 1, B.high do
	tt += B.every[1]
	Rune.baitDrop(bot, bs, tt, 0, 0)
	eq(Rune.baitTick(bot, bs, tt + B.life + 1, true, fixed), "miss", "줍지 않으면 놓침 " .. i)
end
eq(Rune.baitLevel(bs, tt + B.life + 1), "high", "한 시간 동안 하나도 줍지 않고 " .. B.high .. "번 놓치면 high")
local some = Rune.newStat()
for i = 1, B.mid do
	table.insert(some.missed, tt)
end
eq(Rune.baitLevel(some, tt), "mid", B.mid .. "번이면 mid")
table.insert(some.got, tt)
eq(Rune.baitLevel(some, tt), nil, "하나라도 주웠으면 의심하지 않는다")
-- 매크로 확인의 의심에 들어간다
local ms = Macro.new(tt, nil)
ms.bait = bs
eq(Macro.level(ms, tt + B.life + 1, true), "mid", "매크로 확인의 의심 = 중간(확인이 더 자주 뜬다 — 2026-11-13 낮: 별똥별만으로는 「높음」이 아니다)")
local g, shown = Rune.baitCounts(st, B.every[1] + 2)
expect(g == 1 and shown == 1, "관리 창의 「별똥별 1/1」")

-- ⑦ 룬의 저주는 사람에게 붙어 다닌다(2026-11-10 사용자 "룬의 저주는 사냥터를옮기던뭐하던 해도 룬의저주가 없어지면안된다" — server modules/runeGuard.luau):
--  사냥터를 옮겨도 · 마을에 들렀다 와도 · 다시 접속해도(캐릭터 저장) 남는다 · 깎는 것은 사냥터에서만 · 어느 맵이든 룬을 직접 해방하면 풀린다 ·
--  그 맵에 서 있는 동안 누군가 그 맵의 룬을 해방하면 그 맵에서 받은 저주도 풀린다
do
	local fired = {}
	MOCK("ReplicatedStorage/shared/lune/net/net", {
		FireClient = function(name, player, v)
			table.insert(fired, { name = name, player = player, v = v })
		end,
		OnServer = function() end,
	})
	local RG = req("ServerScriptService/server/lune/modules/runeGuard")
	local sessions = {}
	RG.bind({
		roomOf = function() return nil end,
		sessionsIn = function(key)
			local out = {}
			for _, x in sessions do
				if x.scene == key then
					table.insert(out, x)
				end
			end
			return out
		end,
	})
	local A, Bm = "r1a1", "r1a3" -- (사냥터 둘)
	local function sess(id)
		local hero = Hero.new(id, "axion")
		hero.level = 30
		local x = { player = { UserId = id }, scene = A, hero = hero, macro = { kills = {} } } -- macro.kills = 그 사람이 잡은 때(저주는 그 사람이 사냥할 때만 쌓인다 — 2026-11-12)
		table.insert(sessions, x)
		return x
	end
	local function now0()
		return 1700000000 + math.floor(clock.now) -- (서버의 모듈이 보는 시계 — mock.luau osMock)
	end
	local sa, sb = sess(71), sess(72)
	local function tickAll()
		for _, x in sessions do
			RG.tick(x, x.scene)
		end
	end
	-- 맵 A에서 사냥을 이어 룬이 나오고 2단계 저주가 되기까지
	for _ = 1, math.ceil((R.appear + R.curse.after + R.curse.every + 5) / 30) do
		RG.onKill(A)
		for _, x in sessions do
			table.insert(x.macro.kills, now0()) -- (둘 다 맵 A에서 잡고 있다)
		end
		for _ = 1, 30 do -- (1초마다 — 저주의 초를 쌓는 셈이 1초씩 본다)
			clock.now += 1
			tickAll()
			for _, x in sessions do
				if x.scene == A then
					table.insert(x.macro.kills, now0())
				end
			end
		end
	end
	expect(sa.hero.curse ~= nil and sa.hero.curse >= R.curse.cut[2] - 1e-9, ("맵 A의 저주 2단계 이상(%s)"):format(tostring(sa.hero.curse)))
	local stageA = sa.hero.runeCurse and sa.hero.runeCurse.s or 0
	expect(stageA >= 2 and sa.hero.runeCurse.map == A, "저주가 사람에게 붙었다(단계 · 맵)")
	-- 2026-11-12(사용자 "다른사람이 룬의저주를 만든자리를 그 대상자가 아닌사람이 들어갔다가 나오면 룬의 저주가 걸려버려 … 그 유저가 기준인거야"):
	--  저주가 쌓인 맵 A에 새 사람(sc)이 들어와 잠깐 사냥하고 나가면 아무것도 받지 않는다 · 잡지 않고 오래 서 있어도(구경) 받지 않는다 · 룬을 두고 5분 넘게 사냥하면 그때부터 그 사람의 저주
	do
		local sc = sess(73)
		for _ = 1, 60 do -- 1분 사냥
			table.insert(sc.macro.kills, now0())
			clock.now += 1
			RG.tick(sc, A)
		end
		eq(sc.hero.curse, nil, "저주 맵에 막 들어와 1분 사냥: 깎지 않는다(맵의 저주를 물려받지 않는다)")
		expect(sc.hero.runeCurse == nil or sc.hero.runeCurse.s == 0, "새 사람의 저주 단계 0")
		sc.scene = Bm
		clock.now += 1
		RG.tick(sc, Bm)
		eq(sc.hero.curse, nil, "나와서 다른 사냥터: 저주 없음")
		local sd = sess(74)
		for _ = 1, R.curse.after + 60 do -- 잡지 않고 6분 서 있다(구경)
			clock.now += 1
			RG.tick(sd, A)
		end
		eq(sd.hero.curse, nil, "잡지 않고 서 있기만 한 사람: 저주 없음")
		sc.scene = A
		for _ = 1, R.curse.after + 10 do -- 룬을 두고 5분 넘게 사냥
			table.insert(sc.macro.kills, now0())
			clock.now += 1
			RG.tick(sc, A)
		end
		eq(sc.hero.runeCurse and sc.hero.runeCurse.s, 1, "룬을 두고 5분 넘게 사냥하면 그 사람의 저주 1단계")
		for i = #sessions, 1, -1 do
			if sessions[i] == sc or sessions[i] == sd then
				table.remove(sessions, i)
			end
		end
		-- 옛 저장(n이 없다 — 맵의 저주를 물려받은 것)은 한 번 풀린다
		local old = Hero.pack(Hero.new(75, "axion"))
		old.runeCurse = { s = 3, map = A }
		eq(Hero.unpack(75, old).runeCurse, nil, "옛 꼴의 저주(n 없음)는 풀어 준다")
	end
	-- 다른 사냥터로: 남는다
	sa.scene = Bm
	RG.onScene(sa, Bm)
	clock.now += 1
	RG.tick(sa, Bm)
	eq(sa.hero.curse, R.curse.cut[stageA], "다른 사냥터로 옮겨도 저주가 그대로")
	-- 마을에 들렀다(깎지 않는다 — 사냥터에서만) → 다시 사냥터: 그대로
	sa.scene = "town"
	clock.now += 1
	RG.tick(sa, "town")
	eq(sa.hero.curse, nil, "마을에서는 깎지 않는다")
	expect(sa.hero.runeCurse ~= nil and sa.hero.runeCurse.s == stageA, "마을에서도 저주는 붙어 있다")
	sa.scene = Bm
	clock.now += 1
	RG.tick(sa, Bm)
	eq(sa.hero.curse, R.curse.cut[stageA], "다시 사냥터: 그대로")
	-- 다시 접속(캐릭터 저장 → 불러오기): 남는다
	local packed = Hero.pack(sa.hero)
	local back = Hero.unpack(sa.hero.id, packed)
	expect(back.runeCurse ~= nil and back.runeCurse.s == stageA and back.runeCurse.map == A, "저장했다 불러와도 저주가 남는다")
	-- 화면에 알린다(내게 붙은 저주의 단계)
	local last = nil
	for _, f in fired do
		if f.name == "RuneMap" and f.player == sa.player then
			last = f.v
		end
	end
	eq(last and last.curse, stageA, "화면에 내 저주의 단계를 알린다")
	-- 맵 A에 남은 사람(sb)이 그 맵의 룬을 해방 → sb는 풀린다 · 맵 B에 있는 sa는 그대로(제 손으로 풀어야)
	local runeAt = nil
	for _, f in fired do
		if f.name == "RuneMap" and f.player == sb.player and f.v and f.v.rune then
			runeAt = f.v.rune
		end
	end
	expect(runeAt ~= nil, "맵 A에 룬이 있다")
	if runeAt then
		sb.hero.x, sb.hero.y = runeAt.x, runeAt.y
	end
	local ok = RG.onRemote(sb, "start")
	expect(ok and ok.arrows, "맵 A의 룬 해방 시작(룬 곁)" .. (if ok and ok.why then " — " .. ok.why else ""))
	if ok and ok.arrows then
		local res = RG.onRemote(sb, "answer", ok.arrows)
		eq(res and res.result, "done", "맵 A의 룬 해방")
	end
	eq(sb.hero.runeCurse, nil, "푼 사람은 저주가 풀린다")
	clock.now += 1
	RG.tick(sa, Bm)
	eq(sa.hero.curse, R.curse.cut[stageA], "다른 맵에 있던 사람은 그대로(맵 A의 룬이 풀렸어도 — 사냥터를 옮겨 피할 수 없게)")
	-- 저주를 지닌 채 룬이 없는 사냥터(다른 채널의 방 · 다른 맵)에서 사냥하면 그 자리에 룬이 놓인다(2026-11-14 사용자 "다른 채널에서 뜬 룬이 본인채널에도 저주가 걸려버린다" —
	--  전에는 「그 사람 몫」(룬을 푼 뒤 오래 사냥)일 때만 놓여, 남의 룬으로 생긴 저주를 다른 채널에서 풀 길이 없었다)
	local C2 = A .. "#c2"
	sa.scene = C2
	RG.onScene(sa, C2)
	local mark = #fired
	table.insert(sa.macro.kills, now0())
	clock.now += 1
	RG.tick(sa, C2)
	local placed = nil
	for i = mark + 1, #fired do
		local f = fired[i]
		if f.name == "RuneMap" and f.player == sa.player and f.v and f.v.rune then
			placed = f.v.rune
		end
	end
	expect(placed ~= nil, "저주를 지닌 사람이 룬 없는 채널의 방에서 사냥하면 그 방에 룬이 놓인다(풀 수 있다)")
	if placed then
		sa.hero.x, sa.hero.y = placed.x, placed.y
		local ok2 = RG.onRemote(sa, "start")
		if ok2 and ok2.arrows then
			local res2 = RG.onRemote(sa, "answer", ok2.arrows)
			eq(res2 and res2.result, "done", "그 룬을 풀었다")
		end
		eq(sa.hero.runeCurse, nil, "다른 채널에서 생긴 저주도 지금 채널에서 풀린다")
	end
end
