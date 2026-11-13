-- 「달의 계승자」 — 나갔다 들어오기로 매크로 확인을 피하지 못하게(2026-11-13 사용자: "게임 사냥터 채널있잖아 여기서 메크로가 게임을 나갔다가 들어왔다가 하면서
--  매크로 탐지 안당하면서 악용하면 아예 못잡아"). sim/macro.luau Macro.new(이어 사냥) · onKill(계정에 남김) · level(relog) · 공방 design/macro.js relog
--  보는 것: ① 사냥 중에 나갔다 15분 안에 들어오면 쉬지 않은 사냥 시계 · 확인의 때 · 마지막 통과를 잇고 처음 5분 봐주기가 없다 → 26분째에 확인이 온다(전에는 다시 0부터)
--   ② 다시 들어온 수가 계정에 남는다(날마다 rl) · 한 시간에 3번 = 의심 중간 · 5번 = 의심 높음 ③ 15분 넘게 쉬었다 들어오면 새로 ④ 저장했다 읽어도 같다
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local D = Macro.DATA
local R = D.relog
expect(R ~= nil and R.mid == 3 and R.high == 5 and R.keep == 3600, "다시 들어오기의 숫자(공방 macro.js relog)")
local function rnd()
	return 1 -- (확인의 때 = 늦은 끝 — low 25분)
end
local function hunt(st, t0, sec, every)
	local t = t0
	while t < t0 + sec do
		Macro.onKill(st, t)
		t += every
	end
	return t
end
local function relog(st, now)
	local back = Macro.unpack(Macro.pack(st.saved)) -- (계정에 저장 → 다시 읽기 = 다른 서버로 들어가도 같다)
	return Macro.new(now, back)
end

-- ① 이어 사냥
local st = Macro.new(0, nil)
local t = hunt(st, 0, 600, 6) -- 10분 사냥
eq(Macro.tick(st, t, { hunt = true }, rnd), nil, "10분: 아직 확인 없음")
local rest0 = st.rest
st = relog(st, t + 30) -- 30초 뒤 다시 들어온다
expect(st.relogged == true, "사냥 중에 나갔다 30초 만에 들어왔다 = 이어 사냥")
eq(st.rest, rest0, "쉬지 않은 사냥 시계를 잇는다(0부터가 아니다)")
expect(t + 30 - st.born >= D.first, "처음 5분 봐주기가 없다")
eq(Macro.relogCount(st, t + 30), 1, "다시 들어온 수 1")
local key = Macro.dayKey(t + 30)
eq(st.saved.days[key] and st.saved.days[key].rl, 1, "계정의 날마다 기록에 재접속 1")
t = hunt(st, t + 30, 600, 6) -- 또 10분
st = relog(st, t + 20)
t = hunt(st, t + 20, 700, 6) -- 또 11분 남짓(합 31분 넘게 사냥 — 의심 중간의 가장 늦은 때 30분: 2026-11-13 낮)
eq(Macro.tick(st, t, { hunt = true }, rnd), "issue", "나갔다 들어오기를 끼워도 31분째에는 확인이 온다(전에는 접속마다 0부터라 오지 않았다)")

-- ② 자주 다시 들어오면 의심
local s2 = Macro.new(0, nil)
local t2 = hunt(s2, 0, 120, 6)
for i = 1, 2 do
	s2 = relog(s2, t2 + 10)
	t2 = hunt(s2, t2 + 10, 120, 6)
end
eq(Macro.relogCount(s2, t2), 2, "두 번")
expect(Macro.level(s2, t2) ~= "mid" and Macro.level(s2, t2) ~= "high", "두 번은 아직(의심 낮음)")
s2 = relog(s2, t2 + 10)
t2 = hunt(s2, t2 + 10, 120, 6)
eq(Macro.level(s2, t2), "mid", "한 시간에 세 번 = 의심 중간(확인이 8 ~ 12분마다)")
for i = 1, 2 do
	s2 = relog(s2, t2 + 10)
	t2 = hunt(s2, t2 + 10, 120, 6)
end
eq(Macro.level(s2, t2), "mid", "다섯 번도 의심 중간까지(2026-11-14 사용자 — 애먼 사람이 걸린다 — 폰은 끊겨 다시 들어오기도 한다)")
eq(Macro.relogCount(s2, t2 + R.keep + 10), 0, "한 시간이 지나면 다시 들어온 수가 풀린다(그때의 의심은 다른 것 — 쉬지 않은 사냥 1시간 등 — 으로만)")

-- ③ 15분 넘게 쉬었다 들어오면 새로
local s3 = Macro.new(0, nil)
local t3 = hunt(s3, 0, 600, 6)
s3 = relog(s3, t3 + D.rest + 5)
expect(not s3.relogged, "15분 넘게 쉬었다 들어오면 이어 사냥이 아니다")
eq(Macro.relogCount(s3, t3 + D.rest + 5), 0, "다시 들어온 수에도 세지 않는다")
-- 사냥하지 않고 나갔다 들어온 것(처치 기록 없음)도 이어 사냥이 아니다
local s4 = relog(Macro.new(0, nil), 100)
expect(not s4.relogged, "사냥 기록이 없으면 이어 사냥이 아니다")

-- ④ 저장의 꼴
local packed = Macro.pack(st.saved)
expect(typeof(packed.run) == "table" and typeof(packed.run.rest) == "number" and typeof(packed.relogs) == "table", "이어 사냥 · 다시 들어온 때를 저장한다")
local bad = Macro.unpack({ run = { rest = "x" }, relogs = { 1, "a", 3 } })
expect(bad.run == nil and #bad.relogs == 2, "꼴이 틀린 것은 버린다")
