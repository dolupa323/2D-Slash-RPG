-- 「달의 계승자」 — 펫이 따라오고 줍는 모습을 화면 없이 돌려 본다(client/lune/rideView.luau). 수치 = 공방 design/ride.js의 RIDE.pet.
--  10-20 사용자: "플레이어랑 펫이 거리가 좀 있어야하고 좀멀리서 쫓아오는 느낌이야 아이템주우면서"
--  10-21 사용자: "펫도 지형에 걸려야해요 지금 펫 지형 다뚫고 다니는데 지형에 걸려서 플레이어에게 가지 못하는 거리가 되어버리면 그때는 텔레포트 해서 붙는방식으로
--   메이플스토리에서 일반펫이 어떻게 작동하는지를 파악하고 , 그에맞춰 작업하면 됩니다."
--  시험 맵(칸 16점): 평지(땅의 윗면 176) · 얇은 발판(=, 윗면 128 — 땅보다 48 위) · 낮은 대지(윗면 160 — 턱 16) · 높은 벽(128) · 구덩이(폭 48)
--  보는 것: ① 서 있으면 뒤 44점 · 땅 위 ② 달리면 뒤로 처져 따라온다 ③ 멈추면 다가온다 ④ 서서 돌아서도 제 쪽에 ⑤ 떨어진 것에 달려가 줍는다(제 높이의 것만)
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

-- ① 서 있으면 뒤 44점 · 땅 위
local rv = fresh(200, GROUND, 1)
run(rv, 2, 200, GROUND, 1, false, false)
expect(math.abs(last.x - (200 - P.behind)) <= 2, ("① 서 있는 영웅의 뒤 %d점(실제 %d)"):format(P.behind, 200 - last.x))
eq(last.y, GROUND, "① 땅 위에 선다")
eq(last.clip, "idle", "① 멈춰 있다")

-- ② 오른쪽으로 3초 달린다(92점/초 · 평지)
local t0 = now
run(rv, 3, function(t)
	return 200 + 92 * (t - t0)
end, GROUND, 1, true, false)
local hx = 200 + 92 * 3
local lag = hx - last.x
expect(lag >= 55 and lag <= 85, ("② 달리는 영웅의 뒤로 처져 따라온다(55~85점 — 실제 %d)"):format(lag))
eq(last.clip, "run", "② 뛰며 따라온다")
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
expect(picked[3] and picked[2] and picked[3].t - picked[2].t >= P.every - 0.02, "⑤ 둘째는 every초 뒤")
local high = { [10] = { x = hx - 20, y = GROUND - 40 } } -- 펫보다 40점 위(위 발판에 떨어진 것)
local highPicked = 0
run(rv, 2, hx, GROUND, -1, false, false, high, function()
	highPicked += 1
end)
eq(highPicked, 0, "⑤ 제 높이(위 18 · 아래 4점)가 아닌 것은 줍지 않는다(메이플: 펫의 위 50 · 아래 10px)")

-- ⑥ 턱(16점): 영웅이 낮은 대지 위 x 700에 선다 — 펫이 웅크렸다 뛰어 올라 뒤 44점에
run(rv, 4, 700, MESA, 1, false, false)
eq(last.y, MESA, "⑥ 턱을 뛰어 올라 대지 위에 선다")
expect(math.abs(last.x - (700 - P.behind)) <= 3, ("⑥ 대지 위 영웅의 뒤 %d점(실제 %d)"):format(P.behind, 700 - last.x))

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

-- ⑨ 높은 벽(x 896~911): 영웅이 벽 너머 x 950에 · 펫은 벽 앞에서 걸려 → 순간 이동
rv = fresh(860, GROUND, 1)
w0 = rv.warps
last.inWall = nil
run(rv, 4, 950, GROUND, 1, false, false)
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
