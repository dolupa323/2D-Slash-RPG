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
	eq(x, sc.w * T, key .. " 바닥 그림 폭 = 맵 폭")
	for _, l in sc.layers do
		expect(A[l.img] ~= nil and l.w > 0 and l.f >= 0 and l.f < 1, key .. " 배경 층 " .. l.img)
	end
	expect(A[sc.props] ~= nil, key .. " 놓인 것 그림")
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

-- 가시와 낭떠러지: 시작 자리로 돌아간다
local fake = { w = 6, h = 4, spawn = { x = 24, y = 48 }, rows = { "......", "......", "......", "###^.#" } }
local fb = P.newBody(fake)
run(fake, fb, { mx = 0 }, 0.5)
expect(fb.ground and fb.y == 48, "작은 시험 맵에 선다")
local ev = nil
for _ = 1, 120 do
	ev = P.step(fake, fb, { mx = 1 }, DT)
	if ev then
		break
	end
end
eq(ev, "respawn", "가시에 닿으면 시작 자리로")
eq(fb.x, fake.spawn.x, "시작 자리로 돌아왔다")
eq(fb.vy, 0, "돌아오면 멈춰 있다")
