-- 「달의 계승자」 — 펫이 따라오고 줍는 모습을 화면 없이 돌려 본다(client/lune/rideView.luau). 수치 = 공방 design/ride.js의 RIDE.pet.
--  10-20 사용자: "플레이어랑 펫이 거리가 좀 있어야하고 좀멀리서 쫓아오는 느낌이야 아이템주우면서"
--  10-21 사용자: "펫도 지형에 걸려야해요 지금 펫 지형 다뚫고 다니는데 지형에 걸려서 플레이어에게 가지 못하는 거리가 되어버리면 그때는 텔레포트 해서 붙는방식으로
--   메이플스토리에서 일반펫이 어떻게 작동하는지를 파악하고 , 그에맞춰 작업하면 됩니다."
--  시험 맵(칸 16점): 평지(땅의 윗면 176) · 얇은 발판(=, 윗면 128 — 땅보다 48 위) · 낮은 대지(윗면 160 — 턱 16) · 높은 벽(128) · 구덩이(폭 48)
--  보는 것: ① 서 있으면 뒤 44점 · 땅 위 ② 달리면 뒤로 처져 따라온다 ③ 멈추면 다가온다 ④ 서서 돌아서도 제 쪽에 ⑤ 떨어진 것에 달려가 줍는다(펫에서 원 안 — 자석)
--   ⑥ 턱은 웅크렸다 뛰어 오른다 ⑦ 영웅이 위 발판이면 따라 오르지 않고 아래에서 기다린다(메이플의 일반 펫) ⑧ 영웅이 아래면 얇은 발판에서 하단 점프로 내려온다
--   ⑨ 높은 벽에 걸려 못 가면 영웅에게 순간 이동 ⑩ 같은 높이의 구덩이는 뛰어 건넌다 ⑪ 멀어지면 영웅의 발밑 땅으로 ⑫ 영웅이 사다리 · 공중이면 기다렸다가 땅에 서면
--   ⑬ 남의 펫(onPick 없음)은 줍지 않는다 ⑭ 펫이 땅을 뚫고 지나가지 않는다(언제나 막힌 칸 밖)
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local Physics = req("ReplicatedStorage/shared/lune/sim/physics")
local P = RIDE.pet

local last = {}
MOCK("Client/lune/sprite", {
	new = function(_, id)
		local s = { char = { id = id }, label = { Visible = true } }
		function s.set(_, clip, _, x, y, dir)
			last = { clip = clip, x = x, y = y, dir = dir }
		end
		function s.destroy() end
		return s
	end,
	frameAt = function()
		return 1
	end,
})
local RideView = req("Client/lune/rideView")

-- 시험 맵: 80칸 x 14줄
local W, H = 80, 14
local grid = {}
for ty = 0, H - 1 do
	grid[ty] = {}
	for tx = 0, W - 1 do
		grid[ty][tx] = if ty >= 11 or tx <= 1 or tx >= W - 2 then "#" else "."
	end
end
for tx = 4, 9 do
	grid[8][tx] = "=" -- 얇은 발판: x 64~159 · 윗면 128
end
for tx = 40, 47 do
	grid[10][tx] = "#" -- 낮은 대지: x 640~767 · 윗면 160(턱 16)
end
for ty = 2, 10 do
	grid[ty][56] = "#" -- 높은 벽: x 896~911 · 높이 144
end
for ty = 11, H - 1 do
	for tx = 62, 64 do
		grid[ty][tx] = "." -- 구덩이: x 992~1039
	end
end
local rows = {}
for ty = 0, H - 1 do
	local r = {}
	for tx = 0, W - 1 do
		r[tx + 1] = grid[ty][tx]
	end
	rows[ty + 1] = table.concat(r)
end
local scene = { w = W, h = H, rows = rows, spawn = { x = 200, y = 176 } }
local GROUND, PLAT, MESA = 176, 128, 160

expect(P.behind >= 40 and P.warpX > 0 and P.warpY > 0 and P.stuck > 0 and P.windup > 0, "규칙의 값")

local now, DT = 0, 1 / 60
local function run(rv, sec, x, y, dir, moving, air, drops, onPick)
	local n = math.floor(sec / DT + 0.5)
	for _ = 1, n do
		now += DT
		local hx = if typeof(x) == "function" then x(now) else x
		rv:update(now, DT, hx, y, dir, moving, air, false, drops, onPick)
		local b = rv.body
		if b and Physics.solidBox(scene, b.x, b.y) then
			last.inWall = true -- ⑭ 막힌 칸 안
		end
	end
end
local function fresh(x, y, dir, id)
	local rv = RideView.new({}, 1, scene)
	rv:setPet(id or "pet_silver")
	rv:update(now, DT, x, y, dir, false, false, false, nil, nil)
	return rv
end

-- ① 서 있으면 뒤 behind점(64 — 2026-10-21 사용자 "펫이 거리를 더 벌려야합니다") · 땅 위
local rv = fresh(200, GROUND, 1)
run(rv, 2, 200, GROUND, 1, false, false)
expect(math.abs(last.x - (200 - P.behind)) <= 2, ("① 서 있는 영웅의 뒤 %d점(실제 %d)"):format(P.behind, 200 - last.x))
eq(last.y, GROUND, "① 땅 위에 선다")
eq(last.clip, "idle", "① 멈춰 있다")

-- ② 오른쪽으로 3초 달린다(92점/초 · 평지) — 순간 이동 없이(2026-10-21 사용자 "마을을 일자로 달리면 계속 팅기듯이": 전에는 1.2초마다 「걸렸다」며 순간 이동했다)
local t0 = now
local wRun = rv.warps
local gaps = {}
run(rv, 3, function(t)
	local x = 200 + 92 * (t - t0)
	return x
end, GROUND, 1, true, false)
-- 같은 빠르기로 따라오는 1초 동안: 영웅이 그려지는 점과 펫이 그려지는 점의 간격이 흔들리지 않는다(전에는 펫의 자리를 따로 반올림해 장마다 한 점씩 떨렸다)
local flips, prevGap = 0, nil
for _ = 1, 60 do
	now += DT
	local x = 200 + 92 * (now - t0)
	rv:update(now, DT, x, GROUND, 1, true, false, false)
	local gap = math.floor(x + 0.5) - last.x
	if prevGap and gap ~= prevGap then
		flips += 1
	end
	prevGap = gap
end
expect(flips <= 2, ("② 따라오는 동안 영웅과의 간격이 흔들리지 않는다(1초에 바뀐 횟수 %d)"):format(flips))
local hx = 200 + 92 * (now - t0)
local lag = hx - last.x
eq(rv.warps, wRun, "② 곧게 달리는 4초 동안 순간 이동하지 않는다")
expect(lag >= P.behind + 10 and lag <= P.behind + 40, ("② 달리는 영웅의 뒤로 처져 따라온다(%d~%d점 — 실제 %d)"):format(P.behind + 10, P.behind + 40, lag))
eq(last.clip, "idle", "② 달려도 그림은 서기 하나(사용자 10-21 — 펫은 자리만 옮긴다)")
eq(last.y, GROUND, "② 땅 위로")

-- ③ 멈추면 다가와 44점에 ④ 서서 돌아서도 제 쪽에
run(rv, 3, hx, GROUND, 1, false, false)
expect(math.abs((hx - last.x) - P.behind) <= 3, ("③ 멈추면 다가와 뒤 %d점(실제 %d)"):format(P.behind, hx - last.x))
run(rv, 2, hx, GROUND, -1, false, false)
expect(last.x < hx and math.abs((hx - last.x) - P.behind) <= 3, "④ 돌아서도 펫은 제가 있던 쪽(왼쪽)에 남는다")

-- ⑤ 영웅의 오른쪽 60점에 떨어진 것 — 펫이 달려가 줍는다 · 위 발판 높이의 것은 줍지 않는다
local picked = {}
local drops = { [7] = { x = hx + 60, y = GROUND } }
local function onPick(id)
	table.insert(picked, { id = id, t = now })
	drops[id] = nil
end
run(rv, 2.5, hx, GROUND, -1, false, false, drops, onPick)
eq(#picked, 1, "⑤ 떨어진 것에 닿아 줍는다")
eq(picked[1] and picked[1].id, 7, "⑤ 그 번호")
drops[8] = { x = hx + 20, y = GROUND }
drops[9] = { x = hx + 24, y = GROUND }
run(rv, 2, hx, GROUND, -1, false, false, drops, onPick)
eq(#picked, 3, "⑤ 나란한 둘을 차례로")
local every = if RideView.sucks(rv.petId) then P.suck.every else P.every -- (은빛 달토끼 = 로벅스 펫: 빨아들이는 간격 — 2026-10-22)
expect(picked[3] and picked[2] and picked[3].t - picked[2].t >= every - 0.02, "⑤ 둘째는 줍는 간격(every · 로벅스 펫은 suck.every) 뒤")
local high = { [10] = { x = hx - 20, y = GROUND - 40 } } -- 펫보다 40점 위(위 발판에 떨어진 것)
local highPicked = 0
run(rv, 2, hx, GROUND, -1, false, false, high, function()
	highPicked += 1
end)
-- (2026-10-22 사용자 "로벅스 펫은 자석범위로 빨아들이는 형태로": 전에는 「40점 위의 것은 줍지 않는다」였다 — 은빛 달토끼는 로벅스 펫이라 둘레 suck.r점 안이면 빨아들인다)
eq(highPicked, 1, "⑤ 로벅스 펫은 40점 위의 것도 둘레 원 안이면 빨아들인다")
-- ⑤-자석(2026-10-21 사용자 "펫의 줍기판정이 살짝 자석처럼 … 원형판정으로 지형이 좀 안좋거나 , 펫이 잘 올라가지 못하더라도 주워지게"):
--  펫이 오를 수 없는 곳(땅보다 18점 위 — 공중의 턱)에 놓인 것도 원 안이면 줍는다 · 그 자리에 서지 않아도 지나가며
local ledge = { [11] = { x = hx - 30, y = GROUND - 18 } }
local got = {}
run(rv, 2, hx, GROUND, -1, false, false, ledge, function(id, px, py)
	table.insert(got, { id = id, x = px, y = py })
	ledge[id] = nil
end)
eq(#got, 1, "⑤ 오르지 못하는 턱 위(18점 위)의 것도 원 안이면 줍는다")
expect(got[1] and typeof(got[1].x) == "number" and typeof(got[1].y) == "number", "⑤ 주울 때 펫의 자리를 알린다(그것이 펫 쪽으로 빨려 드는 그림)")

-- ⑥ 턱(16점): 영웅이 낮은 대지 위 x 700에 선다 — 펫이 웅크렸다 뛰어 올라 뒤 44점에
run(rv, 4, 700, MESA, 1, false, false)
eq(last.y, MESA, "⑥ 턱을 뛰어 올라 대지 위에 선다")
expect(math.abs(last.x - (700 - P.behind)) <= 3, ("⑥ 대지 위 영웅의 뒤 %d점(실제 %d)"):format(P.behind, 700 - last.x))

-- ⑥-2(2026-10-28 사용자 "무료펫 상하 단차를 조금더 수월하게 움직이게하자 지금 언덕을 잘 못넘어"): 한 칸(16점) 턱은 뛰지 않고 걸어 오른다 · 웅크려 멈추지 않는다
rv = fresh(560, GROUND, 1)
local airT, stopT = 0, 0
local px0 = rv.body.x
for _ = 1, math.floor(2.5 / DT + 0.5) do
	now += DT
	local bx = rv.body.x
	rv:update(now, DT, 760, MESA, 1, true, false, false)
	if not rv.body.ground then
		airT += DT
	end
	if rv.body.x <= bx and rv.body.x < 760 - P.behind - 3 then
		stopT += DT
	end
end
eq(rv.body.y, MESA, "⑥-2 한 칸 턱 위로 올라섰다")
eq(airT, 0, "⑥-2 뛰지 않고 걸어 올랐다(공중에 뜬 시간 0)")
eq(rv.warps, 1, "⑥-2 순간 이동하지 않았다(처음 꺼낼 때 한 번뿐 — 전에는 턱 앞을 낭떠러지로 읽어 1.2초 서 있다가 순간 이동했다)")
expect(rv.body.x > px0 + 100 and stopT < 0.1, ("⑥-2 턱 앞에서 멈칫하지 않았다(멈춘 시간 %.2f초)"):format(stopT))
expect(P.stepUp ~= nil and P.stepUp >= 16 and P.stepUp < 32 and P.windup <= 0.1, "걸어 오르는 높이 = 한 칸 · 더 높은 턱 앞의 웅크림은 짧게")

-- ⑦ 영웅이 위 얇은 발판(윗면 128 — 48점 위)에: 펫은 땅에서 기다린다(순간 이동 안 함)
rv = fresh(120, GROUND, 1)
local w0 = rv.warps
run(rv, 3, 120, PLAT, 1, false, false)
eq(last.y, GROUND, "⑦ 영웅이 위 발판이면 따라 오르지 않는다(메이플의 일반 펫)")
eq(rv.warps, w0, "⑦ 가까우니 순간 이동하지 않는다")

-- ⑧ 펫이 얇은 발판 위 · 영웅이 아래 땅으로: 하단 점프로 내려온다
rv = fresh(120, PLAT, 1)
eq(rv.body.y, PLAT, "⑧ 처음에는 영웅과 같은 발판 위")
w0 = rv.warps
run(rv, 3, 120, GROUND, 1, false, false)
eq(last.y, GROUND, "⑧ 영웅을 따라 아래 땅으로 내려왔다")
eq(rv.warps, w0, "⑧ 순간 이동이 아니라 걸어서(하단 점프)")

-- ⑨ 높은 벽(x 896~911): 영웅이 벽 너머 x 980에 · 펫은 벽 앞에서 걸려 → 순간 이동
--  (영웅이 behind점 안이면 기다린다 — 2026-10-21 behind 44 → 64로 벌리며 영웅을 950 → 980으로: 벽 앞의 펫과 89점)
rv = fresh(860, GROUND, 1)
w0 = rv.warps
last.inWall = nil
run(rv, 4, 980, GROUND, 1, false, false)
expect(rv.warps > w0, "⑨ 벽에 걸려 못 가면 순간 이동")
expect(last.x > 911, ("⑨ 벽 너머 영웅 곁으로(펫 x %d)"):format(last.x))
eq(last.y, GROUND, "⑨ 영웅의 발밑 땅")

-- ⑩ 구덩이(x 992~1039): 영웅이 건너편 x 1090(같은 높이) — 펫이 뛰어 건넌다
rv = fresh(960, GROUND, 1)
w0 = rv.warps
run(rv, 4, 1090, GROUND, 1, false, false)
expect(last.x > 1039 and last.y == GROUND, ("⑩ 구덩이를 뛰어 건넜다(펫 x %d · y %d)"):format(last.x, last.y))
eq(rv.warps, w0, "⑩ 순간 이동이 아니라 뛰어서")

-- ⑪ 멀어지면(문 · 순간 이동) 영웅의 발밑 땅으로
rv = fresh(100, GROUND, 1)
w0 = rv.warps
run(rv, DT * 2, 100 + P.warpX + 80, GROUND, 1, false, false) -- x 564(평지)
expect(rv.warps > w0 and math.abs(last.x - (100 + P.warpX + 80 - P.behind)) <= 2, "⑪ 가로로 멀어지면 영웅의 뒤로 바로")

-- ⑫ 영웅이 사다리 위(공중 · 땅보다 100점 위)면 기다리고, 위의 땅에 서면 그리로
rv = fresh(300, GROUND, 1)
w0 = rv.warps
run(rv, 1, 300, GROUND - 100, 1, false, true)
eq(rv.warps, w0, "⑫ 영웅이 사다리 · 공중이면 기다린다")
eq(last.y, GROUND, "⑫ 그동안 땅에")
run(rv, DT * 2, 120, PLAT, 1, false, false) -- 영웅이 위 발판에 섰다(땅에서 48 위 — 가까우면 기다리는 높이)
eq(rv.warps, w0, "⑫ 위 발판(48점 위 · warpY 72 안)이면 그대로 기다린다")

-- ⑬ 남의 펫(onPick 없음)은 따라다니기만
local other = fresh(500, GROUND, 1, "pet_scarf")
run(other, 2, 500, GROUND, 1, false, false, { [13] = { x = 520, y = GROUND } }, nil)
expect(math.abs(last.x - (500 - P.behind)) <= 2, "⑬ 남의 펫은 줍지 않고 따라다니기만")

-- ⑭ 어느 때에도 막힌 칸 안에 있지 않았다
expect(not last.inWall, "⑭ 펫이 땅 · 벽을 뚫고 지나가지 않는다")

-- ⑮ 펫 셋(2026-10-30 사용자 "펫 현재 한마리만 낄수있는데 3마리까지 낄수있게해줘"): 둘째 · 셋째는 따로 된 판 · 영웅 뒤로 gap점씩 더 · 줍는 것도 펫마다(차례 slot을 서버에 알린다)
do
	local three = RideView.new({}, 1, scene)
	three:setPets({ "pet_silver", "pet_lantern", "pet_scarf" })
	expect(three.petId == "pet_silver" and three.extra[2] and three.extra[2].petId == "pet_lantern" and three.extra[3] and three.extra[3].petId == "pet_scarf", "⑮ 펫 셋: 첫째는 이 판 · 둘째 · 셋째는 따로 된 판")
	eq(three.extra[3].behind - three.extra[2].behind, P.gap, "⑮ 셋째는 둘째보다 gap점 더 뒤")
	three:update(now, DT, 300, GROUND, 1, false, false, false, nil, nil)
	run(three, 2, 300, GROUND, 1, false, false)
	expect(math.abs(three.extra[3].body.x - (300 - P.behind - 2 * P.gap)) <= 2, ("⑮ 셋째는 영웅 뒤 %d점(실제 %d)"):format(P.behind + 2 * P.gap, 300 - three.extra[3].body.x))
	local slots = {}
	local far = { [21] = { x = 300 - P.behind - 2 * P.gap - 6, y = GROUND } } -- 셋째 펫 곁
	run(three, 1, 300, GROUND, 1, false, false, far, function(id, _, _, slot)
		slots[id] = slot
	end)
	expect(slots[21] ~= nil, "⑮ 펫 셋 가운데 누군가 줍는다(차례 " .. tostring(slots[21]) .. ")")
	three:setPets({ "pet_silver" })
	expect(three.extra[2] == nil and three.extra[3] == nil, "⑮ 하나로 줄이면 둘째 · 셋째 판이 걷힌다")
	three:destroy()
end
