-- 「달의 계승자」 — 문에 닿을 수 있는가.
--  장면마다 시작 자리에서, 그리고 문마다(그 문으로 들어왔을 때) 다른 모든 문까지 걷기 · 뛰기 · 하단 점프만으로 갈 수 있는지 게임의 움직임 식(sim/physics)으로 따져 본다.
--  만든 까닭(2026-10-10): 숨은 방의 문을 높이 뜬 발판 위에 냈는데, Play에서는 순간이동으로만 그 자리에 서 봤다 — 뛰어서 닿는지는 본 적이 없었다.
--  따지는 법: 설 수 있는 칸 하나하나에서 옆 칸으로 걷기 · 턱에서 걸어 떨어지기 · 뛰기(제자리 / 한쪽으로 끝까지 / 잠깐만 밀기 / 조금 늦게 밀기) · 하단 점프를 실제 식으로 돌려 내려앉는 칸을 잇는다.
--   뛰는 자리는 칸의 가운데와, 턱 끝(몸의 절반이 턱 밖으로 나간 자리 — 그보다 더 끝에 서야만 닿는 곳은 닿지 않는 곳으로 친다).
--   몬스터 · 가시는 보지 않는다(가시는 약한 피해만 주고 길을 막지 않는다). 맵 아래로 떨어지면 시작 자리로 돌아간다.
local G = req("ReplicatedStorage/shared/lune/config/game")
local P = req("ReplicatedStorage/shared/lune/sim/physics")
local S = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local T = G.TILE
local DT = 1 / 60
local HALF = G.BOX_W / 2
local NEAR = 26 -- 문에 들어갈 수 있는 거리(client/lune/sceneView.luau의 portalNear와 같다)

-- 문의 자료: 화면(sceneView.luau)이 문마다 포탈의 그림과 「↑ 어디로」를 그리며 읽는 값이 모두 있어야 한다.
--  만든 까닭(2026-10-10): 포탈의 그림을 넣으면서 문의 이름표(id)를 그대로 읽었는데, 새로 지은 맵의 문에는 id가 없어 그 맵에 들어서는 순간 화면이 멈췄다 — 화면 코드는 자동 검사가 돌리지 못하니 자료의 꼴을 여기서 본다
do
	local MUSIC = req("ReplicatedStorage/shared/lune/data/music.generated")
	local PORTAL = req("ReplicatedStorage/shared/lune/data/portal.generated")
	expect(PORTAL.w > 0 and PORTAL.h > 0 and PORTAL.frames > 0 and PORTAL.fps > 0 and PORTAL.near.x > 0 and PORTAL.near.y > 0, "포탈 그림의 값")
	for sceneKey, sc in S.scenes do
		for i, p in sc.portals do
			local at = ("%s의 문 %d"):format(sceneKey, i)
			expect(typeof(p.x) == "number" and typeof(p.y) == "number", at .. ": 자리")
			expect(typeof(p.to) == "string" and (S.scenes[p.to] ~= nil or p.weekly == p.to or (p.to == "@home" and sc.dojo == true)), at .. ": 가는 곳") -- 보스의 문(2026-10-24) · 개인 연무장의 나가는 문 = 들어온 마을(@home — 2026-10-26)
			expect(typeof(p.label) == "string" and p.label ~= "", at .. ": 어디로 가는지의 글")
			expect(p.h == nil or typeof(p.h) == "number", at .. ": 문의 높이")
		end
		local track = MUSIC.scene[sceneKey]
		expect(typeof(track) == "string" and MUSIC.tracks[track] ~= nil, sceneKey .. ": 배경 음악")
	end
	for _, j in { "victory", "jobup" } do -- 레벨 업 · 전직(2026-10-14 사용자: 퀘스트 완료 · 사망 · 숨은 방에는 징글이 없다 — 효과음만)
		expect(MUSIC.jingles[j] ~= nil and MUSIC.jingles[j].sec > 0, "징글 " .. j)
	end
	expect(MUSIC.tracks[MUSIC.title] ~= nil, "처음 화면의 곡")
end

local function key(tx: number, ty: number): number
	return ty * 4096 + tx
end

-- 설 수 있는 칸: 발밑 칸(tx, ty)이 막힌 칸 · 얇은 발판이고, 그 위에 선 몸이 걸리지 않는다
local function stand(sc, tx: number, ty: number): boolean
	if tx < 0 or tx >= sc.w or ty < 0 or ty >= sc.h then
		return false
	end
	local k = P.cell(sc, tx, ty)
	return (k == "#" or k == "=") and not P.solidBox(sc, tx * T + T / 2, ty * T)
end

-- 내려앉은 자리의 칸. 발 가운데가 허공이면(턱에 걸쳐 선 것) 몸이 걸친 옆 칸
local function landed(sc, x: number, y: number): number?
	local ty = math.floor(y / T)
	if y ~= ty * T then
		return nil
	end
	local tx = math.floor(x / T)
	if stand(sc, tx, ty) then
		return key(tx, ty)
	end
	local l, r = math.floor((x - HALF) / T), math.floor((x + HALF - 1) / T)
	if stand(sc, l, ty) then
		return key(l, ty)
	elseif stand(sc, r, ty) then
		return key(r, ty)
	end
	return nil
end

-- (x, y)에서 plan대로 움직여 다시 땅에 닿는 자리. plan(걸음, 떠 있는가) → mx, 뛰기, ↓
--  돌려주는 것: 칸의 열쇠 · "spawn"(맵 아래로 떨어졌다) · nil(땅을 떠나지 않았거나 너무 오래 걸린다)
local function fly(sc, x: number, y: number, ground: boolean, plan): (number | string)?
	local body = { x = x, y = y, vx = 0, vy = 0, ground = ground }
	local air = not ground
	for i = 1, 300 do
		local mx, jump, down = plan(i, air)
		if P.step(sc, body, { mx = mx, jump = jump, down = down }, DT) == "respawn" then
			return "spawn"
		end
		if not body.ground then
			air = true
		elseif air then
			return landed(sc, body.x, body.y)
		elseif i > 40 then
			return nil -- 벽에 막혀 땅을 떠나지 못했다
		end
	end
	return nil
end

-- 뛰는 법: { 처음 몇 걸음 동안의 방향, 그 걸음 수, 그 뒤의 방향 }
local JUMPS = { { 0, 0, 0 } }
for _, d in { -1, 1 } do
	table.insert(JUMPS, { d, 0, d }) -- 한쪽으로 끝까지
	table.insert(JUMPS, { d, 8, 0 }) -- 잠깐만 밀기(좁은 발판에 내려앉기)
	table.insert(JUMPS, { d, 16, 0 })
	table.insert(JUMPS, { 0, 10, d }) -- 조금 늦게 밀기(머리 위의 턱을 비켜 오르기)
	table.insert(JUMPS, { 0, 20, d })
end

-- 장면의 길 그림: 칸 → 그 칸에서 한 번의 움직임으로 갈 수 있는 칸들. 시작 자리의 열쇠도 함께 돌려준다
local sims = 0
local function graphOf(sc)
	local start = fly(sc, sc.spawn.x, sc.spawn.y, false, function()
		return 0, false, false
	end)
	local edges: { [number]: { [number | string]: boolean } } = {}
	for ty = 0, sc.h - 1 do
		for tx = 0, sc.w - 1 do
			if stand(sc, tx, ty) then
				local out = {}
				edges[key(tx, ty)] = out
				local cx, y = tx * T + T / 2, ty * T
				local function add(to)
					if to ~= nil then
						out[to] = true
					end
				end
				local starts = { cx }
				for _, d in { -1, 1 } do
					if stand(sc, tx + d, ty) then
						out[key(tx + d, ty)] = true -- 옆 칸으로 걷기
					else
						-- 턱에서 걸어 떨어지기(떨어지면서 그대로 밀기 · 놓기 · 되돌아 밀기)
						for _, after in { d, 0, -d } do
							sims += 1
							add(fly(sc, cx, y, true, function(_, air)
								return if air then after else d, false, false
							end))
						end
						-- 턱 끝에서 뛰기: 몸의 절반이 턱 밖으로 나간 자리
						local ex = if d > 0 then (tx + 1) * T else tx * T
						if not P.solidBox(sc, ex, y) then
							table.insert(starts, ex)
						end
					end
				end
				for _, sx in starts do
					for _, j in JUMPS do
						sims += 1
						add(fly(sc, sx, y, true, function(i)
							return if i <= j[2] or j[2] == 0 then j[1] else j[3], i == 1, false
						end))
					end
				end
				-- 튜토리얼의 꿈(sc.tut — 2026-10-14): 「두 번 뛰기」 미션의 높은 바위는 일부러 한 번 뛰기로 닿지 않는다 — 공중에서 한 번 더 뛰는 길도 센다(다른 맵의 기준은 그대로 한 번 뛰기)
				if sc.tut then
					for _, sx in starts do
						for _, j in JUMPS do
							for _, again in { 12, 20, 26 } do
								sims += 1
								add(fly(sc, sx, y, true, function(i)
									return if i <= j[2] or j[2] == 0 then j[1] else j[3], i == 1 or i == again, false
								end))
							end
						end
					end
				end
				if P.cell(sc, tx, ty) == "=" then
					for _, d in { 0, -1, 1 } do
						sims += 1
						add(fly(sc, cx, y, true, function(i)
							return d, i == 1, i == 1
						end)) -- 하단 점프
					end
				end
			end
		end
	end
	return edges, start
end

local function reachFrom(edges, from, start): { [number]: boolean }
	local seen: { [number]: boolean } = {}
	local queue = { from }
	seen[from] = true
	local head = 1
	while head <= #queue do
		local k = queue[head]
		head += 1
		for to in edges[k] or {} do
			local t = if to == "spawn" then start else to
			if t ~= nil and not seen[t] then
				seen[t] = true
				table.insert(queue, t)
			end
		end
	end
	return seen
end

local function touches(seen, p): boolean
	local ty = math.floor(p.y / T)
	for tx = math.floor((p.x - NEAR) / T), math.floor((p.x + NEAR) / T) do
		if seen[key(tx, ty)] and math.abs(tx * T + T / 2 - p.x) < NEAR then
			return true
		end
	end
	return false
end

-- 문 앞에 내려앉은 칸(그 문으로 들어왔을 때 서는 자리)
local function arrive(sc, p)
	return fly(sc, p.x, p.y, false, function()
		return 0, false, false
	end)
end

-- 먼저 이 따지는 법이 맞는지: 뛰는 높이는 57도트 — 세 줄(48도트) 위의 발판에는 닿고, 네 줄(64도트) 위의 발판에는 닿지 않아야 한다. 발판을 딛고 한 번 더 뛰면 닿는다
do
	local function room(extra: { [number]: string })
		local rows = {}
		for ty = 0, 13 do
			rows[ty + 1] = extra[ty] or (if ty >= 11 then string.rep("#", 20) else string.rep(".", 20))
		end
		return { w = 20, h = 14, rows = rows, spawn = { x = 24, y = 176 }, portals = {} }
	end
	local low, high = { x = 3 * T + 8, y = 8 * T }, { x = 10 * T, y = 7 * T }
	local sc = room({ [8] = "..===...............", [7] = "...............==..." })
	local edges, start = graphOf(sc)
	local seen = reachFrom(edges, start :: number, start)
	expect(touches(seen, low), "따지는 법: 세 줄 위의 발판에는 닿는다")
	expect(not touches(seen, { x = 16 * T, y = 7 * T }), "따지는 법: 네 줄 위의 발판에는 닿지 않는다(디딜 발판이 멀다)")
	sc = room({ [8] = "..===...............", [7] = ".........==........." })
	edges, start = graphOf(sc)
	seen = reachFrom(edges, start :: number, start)
	expect(touches(seen, high), "따지는 법: 세 줄 위의 발판을 딛고 옆으로 네 칸 떨어진 한 줄 위의 발판에는 닿는다")
	sc = room({ [8] = "..==................", [7] = ".............==....." })
	edges, start = graphOf(sc)
	seen = reachFrom(edges, start :: number, start)
	expect(touches(seen, low) and not touches(seen, { x = 14 * T, y = 7 * T }), "따지는 법: 옆으로 아홉 칸 떨어진 발판에는 닿지 않는다")
end

local scenes, doors = 0, 0
for id, sc in S.scenes do
	scenes += 1
	local edges, start = graphOf(sc)
	expect(type(start) == "number", id .. " 시작 자리에서 땅에 선다")
	if type(start) == "number" then
		local seen = reachFrom(edges, start, start)
		for _, p in sc.portals do
			doors += 1
			expect(touches(seen, p), `{id}: 시작 자리에서 「{p.label}」({p.to}) 문까지 걸어서 · 뛰어서 닿는다`)
		end
		-- 문으로 들어온 자리에서도 다른 문에 모두 닿는다(들어왔다가 갇히지 않는다)
		for _, p in sc.portals do
			local at = arrive(sc, p)
			expect(type(at) == "number", `{id}: 「{p.label}」 문 앞에 설 수 있다`)
			if type(at) == "number" then
				local from = reachFrom(edges, at, start)
				for _, q in sc.portals do
					if q ~= p then
						expect(touches(from, q), `{id}: 「{p.label}」 문으로 들어와서 「{q.label}」({q.to}) 문까지 닿는다`)
					end
				end
			end
		end
	end
end
-- 퀘스트의 자리(맵에 놓인 것 앞에서 ↑를 누르는 일 — 샘 · 깃발): 그 맵의 시작 자리에서 걸어서 · 뛰어서 그 앞에 설 수 있어야 한다
do
	local QD = req("ReplicatedStorage/shared/lune/data/quests.generated")
	local spots = 0
	for _, def in QD.list do
		for _, step in def.steps do
			if step.type == "use" then
				spots += 1
				local sc = S.scenes[def.scene]
				local edges, start = graphOf(sc)
				expect(type(start) == "number", def.scene .. " 시작 자리에서 땅에 선다")
				if type(start) == "number" then
					local seen = reachFrom(edges, start, start)
					expect(touches(seen, { x = step.x, y = step.y }), `{def.name}: {def.scene}의 자리 「{step.place}」({step.x}, {step.y}) 앞에 설 수 있다`)
				end
			end
		end
	end
	expect(spots >= 2, "퀘스트의 자리를 모두 봤다")
end
expect(scenes >= 80, "장면을 모두 봤다")
expect(doors >= 150, "문을 모두 봤다")
