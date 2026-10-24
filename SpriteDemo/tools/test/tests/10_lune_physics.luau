-- 「달의 계승자」 — 내보낸 자료(캐릭터 · 장면)의 짜임과 횡스크롤 움직임(달리기 · 뛰기 · 발판 · 벽 · 가시)
local G = req("ReplicatedStorage/shared/lune/config/game")
local P = req("ReplicatedStorage/shared/lune/sim/physics")
local S = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local C = req("ReplicatedStorage/shared/lune/data/chars.generated")
local A = req("ReplicatedStorage/shared/lune/data/assets.generated")
local T = G.TILE
local DT = 1 / 60

-- ---- 1) 자료의 짜임 ----
eq(S.view[1], G.VIEW_W, "화면 가로")
eq(S.view[2], G.VIEW_H, "화면 세로")
eq(S.tile, T, "칸 크기")
expect(S.scenes[S.start] ~= nil, "처음 장면이 있음")
local sceneCount = 0
for key, sc in S.scenes do
	sceneCount += 1
	eq(#sc.rows, sc.h, key .. " 줄 수")
	for _, row in sc.rows do
		eq(#row, sc.w, key .. " 줄 길이")
	end
	-- 바닥 그림 조각이 이어져 맵 전체를 덮는다
	local x = 0
	for _, g in sc.ground do
		eq(g.x, x, key .. " 바닥 조각이 이어짐")
		expect(g.w <= 1024 and g.h <= 1024, key .. " 바닥 조각 크기")
		expect(A[g.img] ~= nil, key .. " 바닥 그림이 에셋 목록에 있음 " .. g.img)
		x += g.w
	end
	if sc.indoor then
		-- 건물의 실내: 방 그림 한 장(층)이 바닥까지 다 그린다 — 바닥 그림 · 소품 그림이 없고, 한 화면이다
		eq(x, 0, key .. " 실내에는 바닥 그림이 없다")
		if sc.ship then
			-- 배의 갑판(2026-10-16): 하늘 · 흘러가는 바다(d — 점/초) · 배 한 장(화면만 한 그림, 맨 위)
			local top = sc.layers[#sc.layers]
			local drift = false
			for _, l in sc.layers do
				drift = drift or (typeof(l.d) == "number" and l.d ~= 0)
			end
			expect(#sc.layers >= 2 and top.f == 0 and top.w == S.view[1] and top.h == S.view[2] and drift, key .. " 배는 흘러가는 바다 위에 화면만 한 배 그림 한 장")
		else
			expect(#sc.layers == 1 and sc.layers[1].f == 0 and sc.layers[1].w == S.view[1] and sc.layers[1].h == S.view[2], key .. " 실내는 화면만 한 방 그림 한 장")
		end
		eq(sc.w * T, S.view[1], key .. " 실내는 한 화면 폭")
		expect(not sc.tall, key .. " 실내는 카메라가 세로로 움직이지 않는다")
	else
		eq(x, sc.w * T, key .. " 바닥 그림 폭 = 맵 폭")
	end
	for _, l in sc.layers do
		-- 따라오는 정도 f: 0~1(멀수록 작다). 2 = 맵과 똑같이 움직이는 벽 — 오르는 맵에서는 한 화면 폭의 맵에서만(망루 · 종탑의 안: 세로로 쌓인 벽), 오르지 않는 맵에서는 가로로 이어 붙는다(수정 회랑)
		--  2026-10-09: 넓은 오르는 맵(봉인으로 내려가는 계단)도 된다 — 벽은 가로로 이어 붙고, 세로로는 벽 그림이 맵의 높이를 다 덮어야 한다
		expect(A[l.img] ~= nil and l.w > 0 and l.f >= 0 and (l.f < 1 or (l.f == 2 and (not sc.tall or sc.w * T <= S.view[1] or l.y + l.h >= sc.h * T))), key .. " 배경 층 " .. l.img)
	end
	expect(if sc.indoor then sc.props == false and #sc.back == 0 else A[sc.props] ~= nil, key .. " 놓인 것 그림")
	eq(#sc.front, 0, key .. " 캐릭터 앞에 놓인 것은 없다(캐릭터를 가린다)")
	for _, list in { sc.back, sc.front } do
		for _, p in list do
			expect(sc.rects[p.id] ~= nil, key .. " 놓인 것의 그림 자리 " .. p.id)
		end
	end
	-- 시작 자리와 문은 땅 위에 서 있다(발밑이 막힌 칸, 몸은 걸리지 않음)
	local spots = { { "시작 자리", sc.spawn } }
	for _, p in sc.portals do
		expect(S.scenes[p.to] ~= nil or p.weekly == p.to, key .. " 문이 가는 장면 " .. p.to) -- 보스의 문(2026-10-24): 가는 곳 = 보스의 이름표(맵을 옮기지 않는다 — 보스 창)
		table.insert(spots, { "문 " .. p.to, p })
	end
	for _, n in sc.npcs or {} do
		table.insert(spots, { "주민 " .. n.name, n })
		expect(#n.lines >= 1 and n.cell >= 0, key .. " 주민 대사와 그림 칸 " .. n.name)
	end
	for _, m in sc.mobs do
		local def = req("ReplicatedStorage/shared/lune/data/combat.generated").mobs[m.kind]
		expect(def ~= nil and C.chars[def.sprite] ~= nil, key .. " 졸개 그림 " .. m.kind) -- 그림을 빌려 쓰는 졸개가 있다(수습 검병 = 검병의 그림)
		table.insert(spots, { "졸개 " .. m.kind, m })
	end
	for _, s in spots do
		expect(not P.solidBox(sc, s[2].x, s[2].y), ("%s %s: 몸이 막힌 칸에 걸리지 않음"):format(key, s[1]))
		local under = P.cell(sc, math.floor(s[2].x / T), math.floor(s[2].y / T))
		expect(s[2].y % T == 0 and (under == "#" or under == "="), ("%s %s: 땅이나 발판 위에 서 있음"):format(key, s[1]))
	end
	if sc.npcs then
		expect(A[sc.npcSheet] ~= nil and #sc.npcCell == 2, key .. " 주민 그림")
	end
end
expect(sceneCount >= 2, "장면이 둘 이상")

-- 마을: 층이 있는 맵(엘리니아 방식) — 건물의 문은 그 건물의 실내로 가고, 실내의 문은 그 건물의 문으로 돌아온다. 일을 봐 주는 주민은 실내에 있다
do
	local town0 = S.scenes[S.start]
	expect(town0.tall == true, "마을은 카메라가 세로로도 따라가는 맵")
	local doors, inside = 0, {}
	for _, p in town0.portals do
		local dest = S.scenes[p.to]
		if dest.indoor then
			doors += 1
			-- 나가는 문은 하나(마을로). 그 밖의 문은 그 방에서 내려가는 지하뿐이다 — 퀘스트를 받아야 열리고(need), 지하의 문은 다시 그 방으로 올라온다(달의 사당 → 사당 지하. 2026-10-13)
			local outs = 0
			for _, q in dest.portals do
				if q.to == S.start then
					outs += 1
				else
					local under = S.scenes[q.to]
					expect((typeof(q.need) == "string" or typeof(q.need) == "table") and under ~= nil and under.indoor == true, p.to .. " 의 다른 문은 퀘스트로 열리는 지하다 — " .. tostring(q.to))
					expect(under ~= nil and #under.portals == 1 and under.portals[1].to == p.to, tostring(q.to) .. " 에서 올라오는 문은 하나 — 그 방으로")
				end
			end
			eq(outs, 1, p.to .. " 나가는 문은 하나")
			eq(dest.portals[1].to, S.start, p.to .. " 나가는 문은 마을로")
			expect(dest.npcs ~= nil and #dest.npcs >= 1, p.to .. " 안에 주민이 있다")
			for _, n in dest.npcs do
				inside[n.id] = p.to
			end
			eq(dest.spawn.x, dest.portals[1].x, p.to .. " 시작 자리는 문 앞")
		end
	end
	expect(doors >= 5, "들어갈 수 있는 건물이 다섯 " .. doors)
	for _, id in { "merchant", "smith", "keeper", "elder", "master" } do
		expect(inside[id] ~= nil, "건물 안에 있는 주민 " .. id)
	end
	for _, n in town0.npcs or {} do
		expect(inside[n.id] == nil, "밖에 선 주민은 안에도 있지 않다 " .. n.id)
	end
	-- 건물의 문은 높이가 서로 다르다(평평한 한 줄이 아니다)
	local heights, kinds = {}, 0
	for _, p in town0.portals do
		if not heights[p.y] then
			heights[p.y] = true
			kinds += 1
		end
	end
	expect(kinds >= 3, "문이 놓인 높이가 셋 이상 " .. kinds)
end

-- 캐릭터: 다섯 직업과 졸개 넷, 움직이는 데 쓰는 동작, 장마다 판 안에 들어 있음
for _, page in C.pages do
	expect(A[page] ~= nil, "캐릭터 판이 에셋 목록에 있음 " .. page)
end
for _, id in { "axion", "riven", "reaper", "mooni", "salamander" } do
	local c = C.chars[id]
	expect(c ~= nil, "직업 그림 " .. id)
	for _, clip in { "idle", "run", "jump", "fall" } do
		expect(c.clips[clip] ~= nil and #c.clips[clip].frames >= 1, ("%s.%s"):format(id, clip))
	end
end
local frames = 0
for id, c in C.chars do
	for name, clip in c.clips do
		expect(clip.fps > 0, ("%s.%s fps"):format(id, name))
		local fw, fh = clip.fw or c.fw, clip.fh or c.fh
		for _, f in clip.frames do
			if f then
				frames += 1
				expect(C.pages[f[1]] ~= nil, ("%s.%s 판 번호"):format(id, name))
				expect(f[2] >= 0 and f[3] >= 0 and f[2] + f[4] <= 1024 and f[3] + f[5] <= 1024, ("%s.%s 판 안"):format(id, name))
				expect(f[6] >= 0 and f[7] >= 0 and f[6] + f[4] <= fw and f[7] + f[5] <= fh, ("%s.%s 칸 안"):format(id, name))
			end
		end
	end
end
expect(frames > 600, "장 수 " .. frames)

-- ---- 2) 움직임 ----
local town = S.scenes.town
local function run(scene, body, input, seconds)
	local ev = nil
	for _ = 1, math.floor(seconds / DT + 0.5) do
		local jump = input.jump
		ev = P.step(scene, body, input, DT) or ev
		if jump then
			input.jump = false -- 누른 순간 한 번만
		end
	end
	return ev
end

-- 서 있기: 시작 자리에 내려서서 그대로 있다
local b = P.newBody(town)
run(town, b, { mx = 0 }, 0.5)
expect(b.ground, "시작 자리에 선다")
eq(b.y, town.spawn.y, "선 높이")
eq(P.clipOf(b, 0), "idle", "서 있는 동작")

-- 달리기: 1초에 RUN도트
local x0 = b.x
run(town, b, { mx = 1 }, 1)
expect(math.abs((b.x - x0) - G.RUN) < 0.01, "1초에 " .. G.RUN .. "도트: " .. (b.x - x0))
eq(P.clipOf(b, 1), "run", "달리는 동작")

-- 뛰기: 가장 높이 올라간 높이 ≈ JUMP² / (2 · GRAVITY), 같은 자리에 내려선다
--  (마을의 흙섬은 길에서 한 번 뛰면 올라서는 높이다 — 머리 위에 섬이 없는 자리로 옮겨서 잰다)
do
	local open = nil
	for tx = 2, town.w - 3 do
		local clear = true
		for ty = 0, math.floor(town.spawn.y / T) - 1 do
			for dx = -1, 1 do
				if P.cell(town, tx + dx, ty) ~= "." then
					clear = false
				end
			end
		end
		if clear and not open then
			open = tx
		end
	end
	expect(open ~= nil, "마을에 머리 위가 트인 길이 있다")
	b.x = open * T + T / 2
	run(town, b, { mx = 0 }, 0.2)
end
local top, y0 = b.y, b.y
local input = { mx = 0, jump = true }
local sawJump, sawFall = false, false
for _ = 1, 120 do
	P.step(town, b, input, DT)
	input.jump = false
	top = math.min(top, b.y)
	local clip = P.clipOf(b, 0)
	sawJump = sawJump or clip == "jump"
	sawFall = sawFall or clip == "fall"
end
local want = G.JUMP * G.JUMP / (2 * G.GRAVITY)
expect(math.abs((y0 - top) - want) < 3, ("뛰는 높이 %.1f(기대 %.1f)"):format(y0 - top, want))
expect(b.ground and b.y == y0, "뛴 뒤 같은 높이에 내려선다")
expect(sawJump and sawFall, "뛰는 동작과 떨어지는 동작이 차례로 나온다")
-- 공중에서는 다시 뛰지 못한다
input = { mx = 0, jump = true }
P.step(town, b, input, DT)
input.jump = true
P.step(town, b, input, DT)
local vyAir = b.vy
expect(vyAir > -G.JUMP, "공중에서 뛰기를 눌러도 다시 솟지 않는다")
run(town, b, { mx = 0 }, 2)

-- 맵 끝: 왼쪽 · 오른쪽 밖으로 나가지 못한다
run(town, b, { mx = -1 }, 30)
expect(b.x >= G.BOX_W / 2 and b.x < T, "왼쪽 끝에서 멈춘다 " .. b.x)
run(town, b, { mx = 1 }, 30)
expect(b.x < town.w * T - G.BOX_W / 2 + 1 and b.x > town.w * T - T, "오른쪽 끝에서 멈춘다 " .. b.x)

-- 마을의 흙섬: 길에서 뛰어 가장 낮은 흙섬(= 칸)에 올라선다 — 한 번의 점프로 닿는 높이여야 한다
do
	local lowest: any = nil
	for ty = 0, town.h - 1 do
		for tx = 0, town.w - 1 do
			if P.cell(town, tx, ty) == "=" and (lowest == nil or ty > lowest.ty) then
				lowest = { tx = tx, ty = ty }
			end
		end
	end
	expect(lowest ~= nil, "마을에 흙섬이 있다")
	local rise = town.spawn.y - lowest.ty * T
	expect(rise > 0 and rise <= 48, "가장 낮은 흙섬은 길에서 한 번에 뛰어오를 높이 " .. rise)
	local b2 = P.newBody(town)
	b2.x, b2.y = lowest.tx * T + T / 2 + 4, town.spawn.y
	run(town, b2, { mx = 0 }, 0.2)
	local hop = { mx = 0, jump = true }
	run(town, b2, hop, 1.2)
	expect(b2.ground and b2.y == lowest.ty * T, ("길에서 뛰어 흙섬에 선다(높이 %d, 선 곳 %d)"):format(lowest.ty * T, b2.y))
	-- 하단 점프: ↓ 만으로는 내려가지 않는다 · ↓ 를 누른 채 뛰기를 눌러야 내려온다(사용자 2026-10-08)
	run(town, b2, { mx = 0, down = true }, 0.6)
	expect(b2.ground and b2.y == lowest.ty * T, "↓ 만 눌러서는 흙섬에서 내려가지 않는다 " .. b2.y)
	expect(P.onPlatform(town, b2), "흙섬 위는 하단 점프를 할 수 있는 자리")
	run(town, b2, { mx = 0, down = true, jump = true }, 0.8)
	expect(b2.ground and b2.y == town.spawn.y, "↓ + 뛰기로 길에 내려온다 " .. b2.y)
	-- 막힌 땅에서는 하단 점프가 없다: ↓ + 뛰기는 보통의 점프
	expect(not P.onPlatform(town, b2), "길(막힌 칸)은 하단 점프를 할 수 없는 자리")
	local up = { mx = 0, down = true, jump = true }
	P.step(town, b2, up, DT)
	expect(b2.vy < 0 and not b2.ground, "길에서 ↓ + 뛰기는 보통의 점프")
	run(town, b2, { mx = 0 }, 1.2)
end

-- 사냥터: 얇은 발판(=)에 아래에서 올라타고, ↓로 내려온다
local hunt = S.scenes.hunt
local plat = nil
for ty = 0, hunt.h - 1 do
	for tx = 1, hunt.w - 2 do
		-- 발판 칸 위가 비어 있고, 그 아래 네 칸 안에 땅이 있는 곳(뛰어서 닿는 높이)
		if P.cell(hunt, tx, ty) == "=" and P.cell(hunt, tx, ty - 1) == "." and not plat then
			for d = 1, 3 do
				if P.cell(hunt, tx, ty + d) == "#" and P.cell(hunt, tx, ty + d - 1) ~= "#" then
					plat = { tx = tx, ty = ty, floor = (ty + d) * T }
					break
				end
			end
		end
	end
end
expect(plat ~= nil, "사냥터에 뛰어서 닿는 발판이 있음")
if plat then
	local px = plat.tx * T + T / 2
	local hb = { x = px, y = plat.floor, vx = 0, vy = 0, ground = true }
	expect(not P.solidBox(hunt, hb.x, hb.y), "발판 아래 자리가 비어 있음")
	run(hunt, hb, { mx = 0, jump = true }, 1.5)
	eq(hb.y, plat.ty * T, "아래에서 뛰어 발판 위에 선다")
	expect(hb.ground, "발판 위에서 땅에 선 것으로 친다")
	run(hunt, hb, { mx = 0, down = true }, 1)
	eq(hb.y, plat.ty * T, "↓ 만 눌러서는 발판에서 내려가지 않는다")
	run(hunt, hb, { mx = 0, down = true, jump = true }, 1)
	eq(hb.y, plat.floor, "↓ + 뛰기(하단 점프)로 발판을 지나 아래로 내려온다")
	-- 내려오는 길에 ↓ 를 계속 누르고 있어도 그 아래의 발판 · 땅에는 선다(한 번에 한 층)
	expect(hb.ground, "하단 점프 뒤 아래에 선다")
end

-- 막힌 칸: 옆에서 밀어도 들어가지 못한다
local wall = nil
for ty = 1, hunt.h - 2 do
	for tx = 2, hunt.w - 2 do
		if not wall and P.cell(hunt, tx, ty) == "#" and P.cell(hunt, tx - 1, ty) == "." and P.cell(hunt, tx - 1, ty + 1) == "#" then
			wall = { tx = tx, ty = ty }
		end
	end
end
expect(wall ~= nil, "사냥터에 옆이 막힌 턱이 있음")
if wall then
	local wb = { x = (wall.tx - 1) * T + T / 2, y = (wall.ty + 1) * T, vx = 0, vy = 0, ground = true }
	run(hunt, wb, { mx = 1 }, 2)
	expect(wb.x < wall.tx * T - G.BOX_W / 2 + 1, "턱 앞에서 멈춘다 " .. wb.x)
end

-- 가시: 닿아도 아무 일도 일어나지 않는다(사용자 2026-10-07 — 시작 자리로 돌려보내던 것을 없앴다). 발밑의 가시 칸을 그냥 지나간다
local spikes = { w = 6, h = 4, spawn = { x = 8, y = 48 }, rows = { "......", "......", "..^^..", "######" } }
local sb = P.newBody(spikes)
run(spikes, sb, { mx = 0 }, 0.5)
expect(sb.ground and sb.y == 48, "가시가 있는 시험 맵에 선다")
local sev = nil
for _ = 1, 40 do
	sev = sev or P.step(spikes, sb, { mx = 1 }, DT)
end
eq(sev, nil, "가시에 닿아도 돌아가지 않는다")
expect(sb.x > 48 and sb.y == 48 and sb.ground, "가시 칸을 지나 그대로 걷는다")
-- 구덩이: 맵의 맨 아래는 막혀 있어서 구덩이에 빠져도 그 바닥에 선다(시작 자리로 돌아가지 않는다)
local fake = { w = 6, h = 4, spawn = { x = 24, y = 48 }, rows = { "......", "......", "......", "###..#" } }
local fb = P.newBody(fake)
run(fake, fb, { mx = 0 }, 0.5)
expect(fb.ground and fb.y == 48, "작은 시험 맵에 선다")
local ev = nil
for _ = 1, 240 do
	ev = ev or P.step(fake, fb, { mx = 1 }, DT)
end
eq(ev, nil, "구덩이에 빠져도 돌아가지 않는다")
expect(fb.ground and fb.y == fake.h * G.TILE, "구덩이의 바닥(맵의 맨 아래)에 선다")
-- 맵 아래로 벗어난 자리에 있으면(있을 수 없는 일 — 안전장치) 시작 자리로 돌아간다
fb.x, fb.y, fb.ground = 24, fake.h * G.TILE + G.FALL_OUT + 20, false
eq(P.step(fake, fb, { mx = 0 }, DT), "respawn", "맵 아래로 벗어나면 시작 자리로")
eq(fb.x, fake.spawn.x, "시작 자리로 돌아왔다")
eq(fb.vy, 0, "돌아오면 멈춰 있다")

-- ---- 2단 점프(2026-10-11 — 사용자: "점프하고 바로 점프 즉 2단점프가 가능하게해주세요 전 직업입니다.") ----
do
	local flat = { w = 12, h = 14, spawn = { x = 96, y = 208 }, rows = {} }
	for i = 1, 13 do
		flat.rows[i] = "............"
	end
	flat.rows[14] = "############"
	local function fresh()
		local b = P.newBody(flat)
		run(flat, b, { mx = 0 }, 0.5)
		return b
	end
	local b = fresh()
	expect(b.ground and b.y == 208, "평평한 시험 맵에 선다")
	-- 한 번 뛴 높이
	local top1 = b.y
	P.step(flat, b, { mx = 0, jump = true }, DT)
	for _ = 1, 150 do
		P.step(flat, b, { mx = 0 }, DT)
		top1 = math.min(top1, b.y)
	end
	local h1 = 208 - top1
	expect(b.ground and b.y == 208 and h1 > 50 and h1 < 60, "한 번 뛰면 57점쯤 오른다 " .. h1)
	-- 꼭대기에서 한 번 더: 훨씬 높이 오르고(첫 번째의 85%만큼 더), 제자리에 내린다
	b = fresh()
	local top2, again = b.y, false
	P.step(flat, b, { mx = 0, jump = true }, DT)
	for _ = 1, 240 do
		local press = not again and not b.ground and b.vy >= 0
		again = again or press
		P.step(flat, b, { mx = 0, jump = press }, DT)
		top2 = math.min(top2, b.y)
	end
	local h2 = 208 - top2
	expect(again and h2 > h1 * 1.6 and h2 < h1 * 1.8, ("꼭대기에서 한 번 더 뛰면 %d점 → %d점"):format(h1, h2))
	expect(b.ground and b.y == 208 and b.air == 0, "땅에 닿으면 다시 센다")
	-- 세 번째는 듣지 않는다(공중에서는 한 번만)
	b = fresh()
	P.step(flat, b, { mx = 0, jump = true }, DT)
	run(flat, b, { mx = 0 }, 0.1)
	P.step(flat, b, { mx = 0, jump = true }, DT)
	eq(b.air, 1, "공중에서 한 번 뛰었다")
	run(flat, b, { mx = 0 }, 0.1)
	local vy = b.vy
	P.step(flat, b, { mx = 0, jump = true }, DT)
	expect(b.vy > vy and b.air == 1, "공중에서 두 번은 뛰지 못한다(그대로 떨어진다)")
	-- 땅에 내린 뒤에는 다시 두 번 다 된다
	run(flat, b, { mx = 0 }, 2)
	expect(b.ground, "내렸다")
	P.step(flat, b, { mx = 0, jump = true }, DT)
	run(flat, b, { mx = 0 }, 0.2)
	P.step(flat, b, { mx = 0, jump = true }, DT)
	expect(b.air == 1 and b.vy < 0, "내린 뒤에 다시 2단 점프")
	-- 뛰지 않고 떨어지는 중에도 한 번 된다(발판에서 걸어 나온 뒤)
	local ledge = { w = 8, h = 14, spawn = { x = 24, y = 96 }, rows = {} }
	for i = 1, 13 do
		ledge.rows[i] = "........"
	end
	ledge.rows[7] = "###....."
	ledge.rows[14] = "########"
	local lb = P.newBody(ledge)
	run(ledge, lb, { mx = 0 }, 0.5)
	expect(lb.ground and lb.y == 96, "턱 위에 선다")
	run(ledge, lb, { mx = 1 }, 0.5)
	expect(not lb.ground and lb.vy > 0, "턱에서 걸어 나와 떨어진다")
	P.step(ledge, lb, { mx = 0, jump = true }, DT)
	expect(lb.vy < 0 and lb.air == 1, "떨어지는 중에 뛰어오른다")
	-- 뛰는 힘의 배수(패시브)는 두 번째에도 곱한다
	b = fresh()
	b.jump = 1.2
	P.step(flat, b, { mx = 0, jump = true }, DT)
	run(flat, b, { mx = 0 }, 0.2)
	P.step(flat, b, { mx = 0, jump = true }, DT)
	expect(math.abs(b.vy + G.JUMP * G.JUMP2 * 1.2) < G.GRAVITY * DT + 0.01, "두 번째에도 뛰는 힘의 배수가 든다")
end

-- ---- 오르는 맵(망루 · 종탑 · 망대)의 층 바닥: 어디서든 하단 점프로 내려간다(2026-10-11 — 사용자: "망루에서 하단점프가 안되는 영역이있습니다.") ----
--  전에는 층 바닥이 막힌 칸(#)이라 구멍의 발판 네 칸에서만 내려갈 수 있었다. 맨 아래층(37줄)은 땅이라 내려가지 않는다
for _, key in { "r1c1", "r1c2", "r1c3", "r2c3", "r4b3" } do
	local sc = S.scenes[key]
	expect(sc ~= nil and sc.h == 40, key .. ": 오르는 맵")
	for _, row in { 7, 13, 19, 25, 31 } do
		for col = 2, sc.w - 3 do
			local b = P.newBody(sc)
			b.x, b.y, b.vx, b.vy, b.ground = col * T + 8, row * T, 0, 0, true
			expect(not P.solidBox(sc, b.x, b.y), ("%s %d줄 %d칸: 설 수 있다"):format(key, row, col))
			expect(P.onPlatform(sc, b), ("%s %d줄 %d칸: 하단 점프가 되는 바닥"):format(key, row, col))
			P.step(sc, b, { mx = 0, jump = true, down = true }, DT)
			run(sc, b, { mx = 0 }, 1.5)
			expect(b.ground and b.y > row * T and b.y <= 37 * T, ("%s %d줄 %d칸: 아래층에 내린다(%d)"):format(key, row, col, b.y))
		end
	end
	-- 맨 아래층은 내려가지 않는다(뛰어오른다)
	local b = P.newBody(sc)
	b.x, b.y, b.vx, b.vy, b.ground = 12 * T, 37 * T, 0, 0, true
	expect(not P.onPlatform(sc, b), key .. ": 맨 아래층은 땅이다")
end

-- ---- 사다리(2026-10-16 밤 — 사용자: "사다리 만들어서 기어올라가게도 만들고 올라가는 모션없이 그냥 쭈욱올라가게") ----
--  ↑ = 잡고 곧게 오른다(사다리 가운데로) · 꼭대기의 발판에 선다 · 꼭대기에서 ↓ = 잡고 내려간다 · 뛰기 = 놓는다 · ↓ + 뛰기 = 하단 점프(잡지 않는다) · 오르는 동안 서 있는 모습
do
	local ct = S.scenes.ct
	expect(ct.ladders ~= nil and #ct.ladders >= 3 and A[ct.ladderImg] ~= nil, "은달 항구에 사다리 셋 · 그림이 에셋 목록에")
	for i, l in ct.ladders do
		expect(l.top < l.bottom and l.x > 0 and l.x < ct.w * T, "사다리의 자리 " .. i)
	end
	local l = ct.ladders[1]
	local body = { x = l.x + 4, y = l.bottom, vx = 0, vy = 0, ground = true }
	for _ = 1, 3 do
		P.step(ct, body, { mx = 0, up = true }, DT)
	end
	expect(body.climb ~= nil and body.x == l.x and body.y < l.bottom, "↑ = 잡고 오른다 · 사다리 가운데로")
	eq(P.clipOf(body, 0), "climb", "사다리 위 = 오르기 동작(사용자 2026-10-16 밤 \"사다리 올라가는 모션 만들어서 적용해줘\")")
	for _, who in { "axion", "riven", "reaper", "mooni", "salamander" } do
		local c = C.chars[who].clips.climb
		expect(c ~= nil and #c.frames == 4, "오르기 동작 네 장 " .. who)
	end
	local t = 3 * DT
	while body.climb and t < 10 do
		P.step(ct, body, { mx = 1, up = true }, DT) -- (옆으로 눌러도 사다리 위에서는 옆으로 가지 않는다)
		t += DT
	end
	expect(body.climb == nil and body.y == l.top and body.ground, "꼭대기의 발판에 선다")
	expect(math.abs(t - (l.bottom - l.top) / 80) < 0.2, ("곧은 빠르기(80점/초) — %.2f초"):format(t))
	P.step(ct, body, { mx = 0 }, DT)
	eq(body.y, l.top, "꼭대기에 그대로 선다")
	P.step(ct, body, { mx = 0, down = true }, DT)
	expect(body.climb ~= nil and body.y > l.top, "꼭대기에서 ↓ = 잡고 내려간다")
	P.step(ct, body, { mx = 0, jump = true }, DT)
	expect(body.climb == nil, "뛰기 = 놓는다")
	body.x, body.y, body.vx, body.vy, body.ground, body.climb = l.x, l.top, 0, 0, true, nil
	P.step(ct, body, { mx = 0, down = true, jump = true }, DT)
	expect(body.climb == nil and not body.ground, "꼭대기에서 ↓ + 뛰기는 하단 점프(사다리를 잡지 않는다)")
	local far = { x = l.x + 40, y = l.bottom, vx = 0, vy = 0, ground = true }
	P.step(ct, far, { mx = 0, up = true }, DT)
	expect(far.climb == nil, "사다리에서 멀면 ↑로 잡지 않는다")
	local dash = { x = l.x, y = l.bottom - 20, vx = 0, vy = 0, ground = false, climb = 1 }
	P.step(ct, dash, { mx = 0, vx = 120, float = true }, DT)
	expect(dash.climb == nil, "기술(대쉬)로 움직이면 사다리를 놓는다")
	-- ↑를 누른 채(폰은 막대를 비스듬히) 옆으로 뛰어도 뛰어내린다 — 바로 다시 잡지 않는다(2026-10-18 검토)
	local hold = { x = l.x, y = l.bottom - 30, vx = 0, vy = 0, ground = false, climb = 1 }
	P.step(ct, hold, { mx = 1, up = true, jump = true }, DT)
	expect(hold.climb == nil and hold.vy < 0, "↑ + 옆 + 뛰기 = 놓고 뛰어내린다")
	for _ = 1, 5 do
		P.step(ct, hold, { mx = 1, up = true }, DT)
	end
	expect(hold.climb == nil and hold.x > l.x, "↑를 누르고 있어도 곧바로 다시 잡지 않는다(옆으로 떨어져 나간다)")
end
