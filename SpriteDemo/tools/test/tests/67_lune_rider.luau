-- 「달의 계승자」 — 탈것을 탄 영웅(client/lune/rideView.luau · 2026-10-21).
--  사용자: "캐릭터가 탑승한모습이 자연스럽지않아요" — 골라 주신 것: 앉은 자리가 어긋남 · 영웅이 너무 큼 · 상반신만 꽂혀 보임 · 영웅이 굳어 있음 ·
--   "탑승할때 플레이어도 idle 재생하면될듯 그 위치에서"
--  보는 것: ① 탄 동안 영웅의 크기 = 원래 크기(riderSize 1 — 사용자 "캐릭터가 탈것 탔을때 너무작다 크기는 원래대로해야겠네") ② update가 자리와 그 배를 돌려준다(내리면 nil)
--   ③ 영웅의 발 = 기준점 + seat + 그 장의 bob — 동작마다 한 자리(사용자 "플레이어 흔들림 없애고") ④ 달리기는 질주 여섯 장 · 장마다 _front(등 아래만 영웅 앞에)
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local stage = { scale = 5 }
MOCK("Client/lune/stage", stage)
local Real = req("Client/lune/sprite")

local last = {}
MOCK("Client/lune/sprite", {
	new = function(_, id)
		local s = { char = CHARS.chars[id] or { id = id }, label = { Visible = true } }
		function s.set(_, clip, f, x, y, dir)
			last[id] = { clip = clip, f = f, x = x, y = y, dir = dir }
		end
		function s.destroy() end
		return s
	end,
	frameAt = function(_, _, t)
		return 1 + math.floor(t * 12) % 6
	end,
	sizeOn = Real.sizeOn,
})
local RideView = req("Client/lune/rideView")

-- ① 크기
eq(RIDE.riderSize, 1, "탄 영웅은 원래 크기")
for _, k in { 3, 4, 5, 6 } do
	stage.scale = k
	local px = k * Real.sizeOn(RIDE.riderSize)
	expect(math.abs(px - math.floor(px + 0.5)) < 1e-9, ("배율 %d에서 탄 영웅의 한 점 %.2f화소 — 정수여야"):format(k, px))
end
stage.scale = 5
eq(Real.sizeOn(RIDE.riderSize), 1, "1080p: 원래 크기(한 점 5화소)")

-- ② · ③ 자리와 크기
for _, m in RIDE.mounts do
	local rv = RideView.new({}, 4, nil)
	rv:setRide(m.id)
	local seen = {}
	for i = 0, 5 do
		local now = i / 12 + 0.001
		local x, y, s = rv:update(now, 1 / 60, 300, 200, 1, true, false, false)
		expect(x ~= nil and s ~= nil, m.id .. ": 탄 동안 영웅의 자리 · 크기를 돌려준다")
		local f = 1 + math.floor(now * 12) % 6
		local ms = Real.sizeOn(CHARS.chars[m.id].size or 1) -- 탈것은 size배로 그린다(영웅의 자리도 그 배)
		eq(y, 200 + (m.seat.dy + (m.bob.run[f] or 0)) * ms, m.id .. (": 달리기 %d장 — 발 = 기준점 + (seat + bob) x 탈것의 배"):format(f))
		eq(x, 300 + (m.seat.dx + ((m.bobx and m.bobx.run and m.bobx.run[f]) or 0)) * ms, m.id .. ": 안장의 열(x 탈것의 배)")
		eq(s, Real.sizeOn(RIDE.riderSize), m.id .. ": 줄여 그리는 배")
		seen[y] = true
		expect(m.seat.dy + (m.bob.run[f] or 0) < -8, m.id .. ": 영웅의 발은 탈것의 등 위(땅보다 8점 넘게 위)")
	end
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	-- 2026-10-21 사용자 "플레이어 흔들림 없애고" → 달리는 동안 영웅은 한 자리(높이 한 가지)
	eq(kinds, 1, m.id .. ": 달리는 동안 영웅이 흔들리지 않는다(높이 한 가지)")
	local x, y, s = rv:update(1, 1 / 60, 300, 200, 1, true, false, true)
	expect(x == nil and y == nil and s == nil, m.id .. ": 사다리 · 기술 중(감춤)에는 nil — 영웅은 제 크기 · 제 동작")
	-- ④ 질주 여섯 장 · 장마다 영웅 앞에 다시 그리는 등
	local c = CHARS.chars[m.id]
	-- (거대 탈것 「이끼 골렘」은 질주가 아니라 느린 걷기 네 장 — 2026-10-22 · 시험 80)
	local runN = if m.id == "mount_golem" then 4 else 6
	eq(#c.clips.run.frames, runN, m.id .. (if runN == 6 then ": 달리기 = 질주 여섯 장" else ": 달리기 = 느린 걷기 네 장"))
	eq(#c.clips.run_front.frames, runN, m.id .. ": 장마다 등(_front)")
	eq(#m.bob.run, runN, m.id .. ": 장마다 영웅의 높이")
	rv:destroy()
end

-- ⑤ 질주에서 어깨가 서 있는 그림보다 뒤인 늑대 · 멧돼지는 영웅도 뒤로(2026-10-21 사용자 "늑대 탑승위치가 갑자기 앞쪽으로가서 엄청나게 이상함 · 돼지도 같은문제")
for _, m in RIDE.mounts do
	local sum = 0
	for _, v in m.bobx.run do
		sum += v
	end
	local mean = sum / #m.bobx.run
	if m.id == "mount_wolf" or m.id == "mount_boar" then
		expect(mean <= -2, ("%s: 달리는 동안 영웅이 어깨를 따라 뒤로(평균 %.1f점)"):format(m.id, mean))
	else
		expect(math.abs(mean) <= 1, ("%s: 사슴은 그대로(평균 %.1f점)"):format(m.id, mean))
	end
	eq(m.bobx.idle[1], 0, m.id .. ": 서 있을 때는 서 있는 그림의 자리")
end

-- ⑥ 탈것의 크기 · 빠르기(2026-10-21 사용자 "탈것들의 크기가 좀더 커야하고, 속도도 더 빨라야함")
local G = req("ReplicatedStorage/shared/lune/config/game")
for _, m in RIDE.mounts do
	local size = CHARS.chars[m.id].size
	expect(size ~= nil and size > 1, m.id .. ": 탈것은 원래보다 크게 그린다")
	for _, k in { 3, 4, 5, 6 } do
		stage.scale = k
		local px = k * Real.sizeOn(size)
		expect(math.abs(px - math.floor(px + 0.5)) < 1e-9, ("%s: 배율 %d에서 한 점 %.2f화소 — 정수여야"):format(m.id, k, px))
	end
	stage.scale = 5
end
expect(RIDE.mountSpeed > 1, ("탄 동안 더 빠르다(%.2f배)"):format(RIDE.mountSpeed))
expect(G.RUN * RIDE.mountSpeed < 300, ("탄 동안의 빠르기 %.0f점/초 — 서버의 이동 몫(300점/초) 안"):format(G.RUN * RIDE.mountSpeed))
