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
		expect(#sc.layers == 1 and sc.layers[1].f == 0 and sc.layers[1].w == S.view[1] and sc.layers[1].h == S.view[2], key .. " 실내는 화면만 한 방 그림 한 장")
		eq(sc.w * T, S.view[1], key .. " 실내는 한 화면 폭")
		expect(not sc.tall, key .. " 실내는 카메라가 세로로 움직이지 않는다")
	else
		eq(x, sc.w * T, key .. " 바닥 그림 폭 = 맵 폭")
	end
	for _, l in sc.layers do
		expect(A[l.img] ~= nil and l.w > 0 and l.f >= 0 and l.f < 1, key .. " 배경 층 " .. l.img)
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
		expect(S.scenes[p.to] ~= nil, key .. " 문이 가는 장면 " .. p.to)
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
			eq(#dest.portals, 1, p.to .. " 나가는 문은 하나")
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
	run(town, b2, { mx = 0, down = true }, 0.6)
	expect(b2.ground and b2.y == town.spawn.y, "↓로 길에 내려온다 " .. b2.y)
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
	eq(hb.y, plat.floor, "↓를 누르면 발판을 지나 아래로 내려온다")
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
