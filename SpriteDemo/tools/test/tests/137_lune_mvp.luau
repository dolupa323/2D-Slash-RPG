-- 「달의 계승자」 — 주간 보스 격파의 MVP(2026-11-07 사용자: "보스 종료시 로스트아크 mvp 처럼 딜량이나 팀기여 이런거 따라서 mvp 출력되어야해") — sim/weekly.luau의 Weekly.note · statOf · mvp
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local CITY = req("ReplicatedStorage/shared/lune/data/city.generated")
local M = CITY.weekly.mvp

expect(M ~= nil and M.min == 2, "MVP는 두 사람 이상일 때(로스트아크와 같다)")
local b = Weekly.boss("shadowarcher")
local room = {}
Weekly.start(room, "normal", b)
local boss, add = { kind = b.id }, { kind = "arrowpost" }
-- 1: 보스 피해가 많다 · 2: 기믹을 많이 · 3: 쓰러짐이 많다
Weekly.note(room, 1, boss, 600)
Weekly.note(room, 2, boss, 300)
Weekly.note(room, 3, boss, 100)
Weekly.note(room, 2, add, 80)
Weekly.note(room, 1, add, 20)
Weekly.useLife(room, 3)
Weekly.useLife(room, 3)
local st = Weekly.statOf(room, 2)
expect(st.dmg == 300 and st.gim == 80 and st.deaths == 0, "사람마다 보스 피해 · 기믹 피해 · 쓰러짐을 센다")
local res = Weekly.mvp(room, { { id = 1, name = "가" }, { id = 2, name = "나" }, { id = 3, name = "다" } })
eq(#res.rows, 3, "사람마다 한 줄")
eq(res.mvp, 1, "점수(피해 70% · 기믹 20% · 생존 10%)가 가장 높은 사람이 MVP")
expect(res.rows[1].mvp == true and res.rows[1].id == 1, "MVP가 맨 위")
expect(math.abs(res.rows[1].dmg - 0.6) < 1e-6, "피해의 몫 60%")
local byId = {}
for _, r in res.rows do
	byId[r.id] = r
end
expect(byId[1].best.dmg and byId[2].best.gim, "분야마다 가장 높은 사람(피해 · 기믹)")
expect(byId[1].best.life == true, "쓰러짐이 가장 적은 사람(같으면 앞 사람)")
eq(byId[3].deaths, 2, "쓰러진 수")
-- 혼자: MVP 없이 줄만
local solo = {}
Weekly.start(solo, "normal", b)
Weekly.note(solo, 9, boss, 500)
local r1 = Weekly.mvp(solo, { { id = 9, name = "혼자" } })
expect(r1.mvp == nil and #r1.rows == 1 and r1.rows[1].mvp == nil, "혼자면 MVP가 없다")
-- 싸움이 끝난 뒤의 피해는 세지 않는다
Weekly.cleared(room)
Weekly.note(room, 3, boss, 9999)
eq(Weekly.statOf(room, 3).dmg, 100, "격파 뒤에는 세지 않는다")
