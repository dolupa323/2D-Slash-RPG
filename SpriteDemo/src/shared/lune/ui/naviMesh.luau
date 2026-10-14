-- 길찾기가 맵을 아는 법 — 그 맵의 발판들과, 발판에서 발판으로 실제로 건너갈 수 있는 길(셈만 한다. 쓰는 곳: shared/lune/ui/navi.luau).
--  사용자 2026-10-13(게임 화면을 보이며): "지금 맵 이해가 없는상태로 길찾기를 구현하니까 이런일이 생기는데 지금 스크린샷을보면  올라가는 발판은 왼쪽에있는데
--   위에 있는 포탈은 오른쪽에 있으니까 오른쪽으로 가라고 화살표가 방향을 안내하잖아요 이거 말이 안되는거에요"
--  처음 것은 갈 곳의 가로 자리만 보고 왼쪽 · 오른쪽을 가리켰다(층이 다르면 가로를 먼저 맞춘 뒤 위 · 아래). 이제는:
--   ① 발판(surface): 맵의 칸(rows)에서 설 수 있는 칸이 가로로 이어진 것 하나하나(땅 · 얇은 발판 · 벽돌 위)
--   ② 건너가는 길(edge): 발판의 자리마다(여덟 점 간격) 캐릭터의 움직임(sim/physics.luau의 P.step — 게임과 같은 식)으로 실제로 뛰어 본다:
--        제자리 뛰기 · 옆으로 뛰기(방향을 누르는 시간을 달리하여) · 2단 점프 · 하단 점프 · 끝에서 걸어 떨어지기 → 다른 발판에 내려서면 그 길을 적는다
--   ③ 가는 길(route): 내가 선 발판에서 갈 곳의 발판까지 가장 빨리 가는 길(걷는 시간 + 뛰는 시간). 화살표는 그 길의 첫 걸음을 가리킨다:
--        뛸 자리까지 왼쪽 · 오른쪽 → 그 자리에 서면 위(뛴다) · 아래(하단 점프) · 옆(끝에서 내려선다 · 건너뛴다)
--  맵 하나를 다 재는 데 시간이 걸려 조금씩 나눠 잰다(Mesh.work — 다 잴 때까지는 navi가 예전의 셈으로 가리킨다).
local lune = script.Parent.Parent
local G = require(lune.config.game)
local SCENES = require(lune.data["scenes.generated"])
local P = require(lune.sim.physics)

local T = G.TILE
local HALF = G.BOX_W / 2

local Mesh = {}
Mesh.DT = 1 / 60 -- 뛰어 볼 때의 한 걸음(게임과 같은 잘기)
Mesh.SPACING = 8 -- 발판 위에서 뛰어 보는 자리의 간격(도트)
Mesh.HOLDS = { 0.1, 0.2, 0.32, 0.46, 9 } -- 옆으로 뛸 때 방향을 누르고 있는 시간(초 — 9 = 내려설 때까지)
Mesh.MAX_AIR = 3 -- 이보다 오래 떠 있으면 버린다(초)
Mesh.TAKE = 8 -- 뛸 자리에서 이만큼 안이면 「다 왔다 — 뛴다」(그쪽 옆 자리에서도 같은 뜀이 될 때 — 재는 간격과 같다: 되는 두 자리 사이는 어디서든 뛴다. 좁게 잡으면 걸어가는 동안 화살표가 옆 · 위 · 옆 · 위로 번갈아 바뀐다)
Mesh.TAKE_EDGE = 0.75 -- 그쪽 옆 자리에서는 안 되는 뜀이면(뛸 수 있는 구간의 끝) 그쪽으로는 이만큼만 — 구간 밖에 서서 뛰라고 하지 않는다
Mesh.NUDGE = 2 -- 구간의 끝에서 이만큼 옆에서도 되는지 다시 뛰어 본다(되면 그쪽으로 이만큼)
Mesh.NARROW = 3 -- 뛸 수 있는 구간이 이보다 좁은 뜀은 안내하지 않는다(걷는 한 걸음이 1.5점이다 — 그 자리에 설 수가 없다)
Mesh.NEAR_FIRST = 0.05 -- 값이 같은 길이 여럿이면(아래층 어디로든 하단 점프를 해도 걸리는 시간이 같다) 지금 선 자리에서 가까운 뜀을 고른다: 첫 걸음까지 걷는 시간에 이만큼 덤
Mesh.COST = { hop = 0.25, double = 0.2, side = 0.1, solo = 0.8 } -- 길을 고를 때의 덤(초): 건너갈 때마다 · 2단 점프 · 옆으로 뛰기 · 딱 한 자리에서만 되는 뜀(조금만 어긋나도 못 간다) — 같은 값이면 쉬운 길을 고른다
Mesh.UP_MIN = 10 -- 내려설 발판이 이만큼은 높아야 「위」 화살표다(같은 높이의 틈을 건너뛸 때는 옆 화살표)

-- ---------- ① 발판 ----------
-- 그 칸 위에 설 수 있는가: 막힌 칸이거나 얇은 발판이고, 그 위에 몸이 들어간다
local function standable(scene, tx: number, ty: number): boolean
	if ty < 1 or ty >= scene.h or tx < 0 or tx >= scene.w then
		return false
	end
	local k = P.cell(scene, tx, ty)
	if k ~= "#" and k ~= "=" then
		return false
	end
	-- 가시가 놓인 칸은 발판으로 치지 않는다(가시밭으로 내려서거나 가시밭을 걸어 지나는 길을 안내하지 않는다)
	if P.cell(scene, tx, ty - 1) == "^" then
		return false
	end
	return not P.solidBox(scene, tx * T + T / 2, ty * T)
end

-- 발판들: { id, ty, y(윗면), x0, x1(가운데가 설 수 있는 가로 구간), edges = {} }
local function surfacesOf(scene)
	local list, at = {}, {}
	for ty = 1, scene.h - 1 do
		local tx = 0
		while tx < scene.w do
			if standable(scene, tx, ty) then
				local from = tx
				while tx + 1 < scene.w and standable(scene, tx + 1, ty) do
					tx += 1
				end
				local s = { id = #list + 1, ty = ty, y = ty * T, x0 = from * T, x1 = (tx + 1) * T, edges = {} }
				table.insert(list, s)
				for k = from, tx do
					at[ty * 4096 + k] = s
				end
			end
			tx += 1
		end
	end
	return list, at
end

-- 발밑 가운데가 (x, y)일 때 선 발판(몸의 폭만큼 걸쳐 설 수 있다 — 가운데 · 왼쪽 끝 · 오른쪽 끝의 차례로 본다). 없으면 nil
local function standingOn(mesh, x: number, y: number)
	local ty = math.floor(y / T + 0.5)
	if math.abs(y - ty * T) > 0.01 then
		return nil
	end
	return mesh.at[ty * 4096 + math.floor(x / T)] or mesh.at[ty * 4096 + math.floor((x - HALF) / T)] or mesh.at[ty * 4096 + math.floor((x + HALF - 1) / T)]
end

-- (x, y)의 발밑에 있는 발판(공중에 떠 있는 것 · 조금 묻힌 것) — 주민 · 문 · 날아다니는 몬스터의 자리에 쓴다
local function below(mesh, x: number, y: number)
	local hit = standingOn(mesh, x, y)
	if hit then
		return hit
	end
	for ty = math.max(1, math.floor(y / T)), mesh.scene.h - 1 do
		local s = mesh.at[ty * 4096 + math.floor(x / T)]
		if s then
			return s
		end
	end
	return nil
end

-- ---------- ② 건너가는 길 ----------
-- 한 번 움직여 본다. move = { jump, double, down, dir, hold } → 내려선 자리 x, y, 걸린 시간(못 내려서면 nil)
local function try(scene, x: number, y: number, move)
	local body = { x = x, y = y, vx = 0, vy = 0, ground = true, air = 0 }
	local input = { mx = 0, jump = false, down = false }
	local t, left, doubled = 0, false, false
	local limit = Mesh.MAX_AIR
	for step = 1, math.ceil(limit / Mesh.DT) do
		input.mx = if t < move.hold then move.dir else 0
		input.jump, input.down = false, false
		if step == 1 then
			input.jump = move.jump or move.down or false
			input.down = move.down or false
		elseif move.double and left and not doubled and not body.ground and body.vy >= 0 then
			input.jump, doubled = true, true -- 가장 높이 떴을 때 한 번 더
		end
		local px = body.x
		if P.step(scene, body, input, Mesh.DT) == "respawn" then
			return nil
		end
		t += Mesh.DT
		if not body.ground then
			left = true
		elseif left then
			return body.x, body.y, t
		elseif not move.jump and not move.down and body.x == px then
			return nil -- 걸어서 끝까지 갔는데 벽에 막혔다
		elseif step > 1 and (move.jump or move.down) then
			return nil -- 뛰지 못했다(머리가 막혔다)
		end
	end
	return nil
end

-- 그 자리에서 해 볼 움직임들
local MOVES = {}
do
	for _, double in { false, true } do
		table.insert(MOVES, { kind = "jump", jump = true, double = double, dir = 0, hold = 0 })
		for _, dir in { -1, 1 } do
			for _, hold in Mesh.HOLDS do
				table.insert(MOVES, { kind = "jump", jump = true, double = double, dir = dir, hold = hold })
			end
		end
	end
	Mesh.MOVES = MOVES
end
local DROP = { kind = "drop", down = true, dir = 0, hold = 0 }
local DROPS = { DROP, { kind = "drop", down = true, dir = -1, hold = 9 }, { kind = "drop", down = true, dir = 1, hold = 9 } }

-- 길 하나를 적는다(같은 자리 · 같은 발판 · 같은 갈래의 길은 빠른 것 하나만)
local function note(mesh, s, x: number, move, lx: number?, ly: number?, t: number?)
	if not lx or not ly or not t then
		return
	end
	local to = standingOn(mesh, lx, ly)
	if not to or to == s then
		return
	end
	local cost = t + Mesh.COST.hop + (if move.double then Mesh.COST.double else 0) + (if move.dir ~= 0 and move.kind == "jump" then Mesh.COST.side else 0)
	local key = to.id * 100000 + math.floor(x) * 4 + (if move.kind == "jump" then 0 elseif move.kind == "drop" then 1 else 2)
	local old = s.byKey[key]
	if old and old.cost <= cost then
		return
	end
	local e = old or {}
	e.to, e.x, e.lx, e.kind, e.dir, e.double, e.hold, e.cost = to.id, x, lx, move.kind, move.dir, move.double or false, move.hold, cost
	if not old then
		s.byKey[key] = e
		table.insert(s.edges, e)
	end
end

-- 발판의 한 자리(x)에서 해 볼 것을 다 해 본다
local function sample(mesh, s, x: number)
	local scene = mesh.scene
	if P.solidBox(scene, x, s.y) then
		return
	end
	for _, move in MOVES do
		note(mesh, s, x, move, try(scene, x, s.y, move))
	end
	-- 하단 점프: 발밑이 얇은 발판뿐일 때
	if P.onPlatform(scene, { x = x, y = s.y }) then
		for _, move in DROPS do
			note(mesh, s, x, move, try(scene, x, s.y, move))
		end
	end
end

-- 맵 하나의 틀을 만든다(발판까지 — 길은 Mesh.work가 조금씩 잰다)
local cache = {}
function Mesh.of(sceneKey: string)
	local mesh = cache[sceneKey]
	if mesh then
		return mesh
	end
	local scene = SCENES.scenes[sceneKey]
	if not scene or not scene.rows then
		return nil
	end
	mesh = { key = sceneKey, scene = scene, ready = false, phase = "sample", todo = {}, at = {}, surfaces = {} }
	mesh.surfaces, mesh.at = surfacesOf(scene)
	for _, s in mesh.surfaces do
		s.byKey = {}
		local x = s.x0 + Mesh.SPACING / 2
		while x < s.x1 do
			table.insert(mesh.todo, { s, x })
			x += Mesh.SPACING
		end
		-- 끝에서 걸어 떨어진다(왼쪽 · 오른쪽)
		table.insert(mesh.todo, { s, s.x0 + Mesh.SPACING / 2, -1 })
		table.insert(mesh.todo, { s, s.x1 - Mesh.SPACING / 2, 1 })
	end
	mesh.total = #mesh.todo
	cache[sceneKey] = mesh
	return mesh
end

-- 길을 잰다: budget자리만큼(안 주면 끝까지). 다 쟀으면 true
function Mesh.work(sceneKey: string, budget: number?): boolean
	local mesh = Mesh.of(sceneKey)
	if not mesh then
		return false
	elseif mesh.ready then
		return true
	end
	local n = budget or math.huge
	while n > 0 and not mesh.ready do
		local job = table.remove(mesh.todo)
		if job == nil then
			if mesh.phase == "sample" then
				-- 뛸 자리는 구간이다: lo · hi = 뛸 자리에서 왼쪽 · 오른쪽으로 얼마나 어긋나도 되는가.
				--  옆 자리(여덟 점 옆)에서도 같은 발판으로 가는 뜀이 되면 그쪽은 넉넉히(TAKE). 안 되면 그쪽은 두 점 옆(NUDGE)에서 다시 뛰어 보고 정한다(다음 단계)
				mesh.phase = "refine"
				local step = Mesh.SPACING * 4
				for _, s in mesh.surfaces do
					for key, e in s.byKey do
						if e.kind ~= "walk" then
							local l, r = s.byKey[key - step] ~= nil, s.byKey[key + step] ~= nil
							e.lo, e.hi = if l then Mesh.TAKE else Mesh.TAKE_EDGE, if r then Mesh.TAKE else Mesh.TAKE_EDGE
							if not l then
								table.insert(mesh.todo, { s, e.x, nil, e, -1 })
							end
							if not r then
								table.insert(mesh.todo, { s, e.x, nil, e, 1 })
							end
							if not l and not r then
								e.solo = true -- 딱 한 자리에서만 되는 뜀: 값을 올린다(넉넉한 자리에서 뛰는 길을 먼저 고른다)
								e.cost += Mesh.COST.solo
							end
						end
					end
					s.byKey = nil
				end
			else
				-- 다 쟀다: 뛸 수 있는 구간이 너무 좁은 뜀(한두 점만 어긋나도 못 간다)은 안내하지 않는다 — 걷다가 그 자리를 지나쳐 화살표가 좌우로 오가게 된다
				for _, s in mesh.surfaces do
					for k = #s.edges, 1, -1 do
						local e = s.edges[k]
						if e.kind ~= "walk" and e.lo + e.hi < Mesh.NARROW then
							table.remove(s.edges, k)
						end
					end
				end
				mesh.ready = true
			end
			continue
		end
		local s, x, walk, edge, side = job[1], job[2], job[3], job[4], job[5]
		if edge then
			-- 구간의 끝을 잰다: 두 점 옆에서 같은 움직임을 해도 같은 발판에 내려서는가
			local nx = x + side * Mesh.NUDGE
			if standingOn(mesh, nx, s.y) == s and not P.solidBox(mesh.scene, nx, s.y) then
				local lx, ly = try(mesh.scene, nx, s.y, { kind = edge.kind, jump = edge.kind == "jump", down = edge.kind == "drop", double = edge.double, dir = edge.dir, hold = edge.hold })
				local to = if lx then standingOn(mesh, lx, ly) else nil
				if to and to.id == edge.to then
					if side < 0 then
						edge.lo = Mesh.NUDGE
					else
						edge.hi = Mesh.NUDGE
					end
				end
			end
		elseif walk then
			local move = { kind = "walk", dir = walk, hold = 9 }
			note(mesh, s, x, move, try(mesh.scene, x, s.y, move))
		else
			sample(mesh, s, x)
		end
		n -= 1
	end
	return mesh.ready
end

function Mesh.ready(sceneKey: string): boolean
	local mesh = cache[sceneKey]
	return mesh ~= nil and mesh.ready
end

-- 그 자리의 발판(선 자리 — 공중이면 nil) · 그 자리 발밑의 발판
function Mesh.standing(sceneKey: string, x: number, y: number)
	local mesh = Mesh.of(sceneKey)
	return if mesh then standingOn(mesh, x, y) else nil
end
function Mesh.below(sceneKey: string, x: number, y: number)
	local mesh = Mesh.of(sceneKey)
	return if mesh then below(mesh, x, y) else nil
end

-- ---------- ③ 가는 길 ----------
local memo = { key = nil :: string?, edge = nil :: any, cost = nil :: number? }
-- (x, y)에 서서 (tx, ty)로 가는 가장 빠른 길의 첫 걸음.
--  돌려주는 것: "same"(같은 발판이다) | 길의 첫 걸음(edge — { to, x(뛸 자리), lx(내려설 자리), kind = "jump" | "drop" | "walk", dir, double, hold }), 걸리는 시간 | nil(길이 없다 · 아직 다 못 쟀다 · 공중이다)
function Mesh.route(sceneKey: string, x: number, y: number, tx: number, ty: number)
	local mesh = Mesh.of(sceneKey)
	if not mesh or not mesh.ready then
		return nil
	end
	local from, goal = standingOn(mesh, x, y), below(mesh, tx, ty)
	if not from or not goal then
		return nil
	elseif from == goal then
		return "same", math.abs(tx - x) / G.RUN
	end
	-- 방금 셈한 것과 같은 물음이면(서 있을 때 · 두 점 안쪽으로 움직였을 때) 그 답을 그대로 — 장마다 부른다
	local memoKey = ("%s|%d|%d|%d|%d"):format(sceneKey, from.id, math.floor(x / 2), goal.id, math.floor(tx / 4))
	if memo.key == memoKey then
		return memo.edge, memo.cost
	end
	-- 가장 빠른 길(다익스트라): 상태 = 발판 + 그 발판에 내려선 자리(여덟 점 단위)
	local dist, first, where, open = {}, {}, {}, {}
	local function push(sid: number, px: number, cost: number, edge)
		local key = sid * 4096 + math.floor(px / 8)
		if dist[key] == nil or cost < dist[key] then
			dist[key], first[key], where[key] = cost, edge, { sid, px }
			open[key] = true
		end
	end
	push(from.id, x, 0, nil)
	local best, bestEdge = math.huge, nil
	while true do
		local key, low = nil, math.huge
		for k in open do
			if dist[k] < low then
				key, low = k, dist[k]
			end
		end
		if not key or low >= best then
			break
		end
		open[key] = nil
		local sid, px = where[key][1], where[key][2]
		if sid == goal.id then
			local total = low + math.abs(tx - px) / G.RUN
			if total < best then
				best, bestEdge = total, first[key]
			end
		else
			local head = first[key] == nil -- 첫 걸음을 고르는 중인가
			for _, e in mesh.surfaces[sid].edges do
				local walk = math.abs(e.x - px) / G.RUN
				push(e.to, e.lx, low + walk * (if head then 1 + Mesh.NEAR_FIRST else 1) + e.cost, first[key] or e)
			end
		end
	end
	memo.key, memo.edge, memo.cost = memoKey, bestEdge, if bestEdge then best else nil
	if not bestEdge then
		return nil
	end
	return bestEdge, best
end

-- 그 길을 뛸 자리에 서 있는가(뛸 수 있는 구간 안)
function Mesh.at(edge, x: number): boolean
	return edge.kind ~= "walk" and x >= edge.x - (edge.lo or Mesh.TAKE_EDGE) and x <= edge.x + (edge.hi or Mesh.TAKE_EDGE)
end

-- 화살표의 방향: 그 길의 첫 걸음을 (x)에 선 내가 어떻게 가는가 — "left" | "right"(뛸 자리로 간다 · 끝에서 내려선다 · 틈을 건너뛴다) | "up"(뛴다) | "down"(하단 점프)
function Mesh.dirOf(sceneKey: string, x: number, y: number, edge): string
	if edge.kind == "walk" then
		return if edge.dir < 0 then "left" else "right"
	elseif not Mesh.at(edge, x) then
		return if edge.x < x then "left" else "right"
	end
	return Mesh.actDir(sceneKey, y, edge)
end

-- 그 길을 뛸 때의 방향(뛸 자리에 섰다고 치고): "down"(하단 점프) · "up"(위의 발판으로 오른다) · "left" | "right"(같은 높이나 아래로 건너뛴다)
function Mesh.actDir(sceneKey: string, y: number, edge): string
	if edge.kind == "walk" then
		return if edge.dir < 0 then "left" else "right"
	elseif edge.kind == "drop" then
		return "down"
	end
	local mesh = Mesh.of(sceneKey)
	local to = mesh.surfaces[edge.to]
	if edge.dir ~= 0 and y - to.y < Mesh.UP_MIN then
		return if edge.dir < 0 then "left" else "right"
	end
	return "up"
end

-- 자동 검사용: 캐시를 비운다 · 발판과 길을 그대로 내준다
function Mesh.reset()
	table.clear(cache)
	memo.key = nil
end
Mesh.try = try

return Mesh
