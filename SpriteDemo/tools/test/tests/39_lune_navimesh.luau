-- 「달의 계승자」 — 길찾기가 맵을 안다(shared/lune/ui/naviMesh.luau · navi.luau): 발판 · 건너가는 길 · 가는 길의 첫 걸음.
--  사용자 2026-10-13(게임 화면을 보이며): "지금 맵 이해가 없는상태로 길찾기를 구현하니까 이런일이 생기는데 지금 스크린샷을보면  올라가는 발판은 왼쪽에있는데
--   위에 있는 포탈은 오른쪽에 있으니까 오른쪽으로 가라고 화살표가 방향을 안내하잖아요 이거 말이 안되는거에요 무슨짓인지..."
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local G = req("ReplicatedStorage/shared/lune/config/game")
local P = req("ReplicatedStorage/shared/lune/sim/physics")
local Mesh = req("ReplicatedStorage/shared/lune/ui/naviMesh")
local Navi = req("ReplicatedStorage/shared/lune/ui/navi")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local T = G.TILE

-- 화살표를 그대로 따라가 본다(게임의 움직임으로): 왼쪽 · 오른쪽이면 그쪽으로 걷고, 뛸 자리에 서면 그 길의 움직임(뛰기 · 2단 점프 · 하단 점프 · 걸어 내려서기)을 한다.
--  (tx, ty)의 발판에서 그 자리 곁에 닿으면 건너간 횟수를 돌려준다. 못 닿으면 nil과 까닭
local function follow(key: string, x: number, y: number, tx: number, ty: number): (number?, string?)
	local scene = SCENES.scenes[key]
	local body = { x = x, y = y, vx = 0, vy = 0, ground = true, air = 0 }
	local hops, input = 0, { mx = 0, jump = false, down = false }
	local from = Mesh.standing(key, x, y)
	for _ = 1, 60 * 120 do
		if body.ground then
			local now = Mesh.standing(key, body.x, body.y)
			if now == nil then
				return nil, ("발판이 아닌 데 섰다(%d, %d)"):format(body.x, body.y)
			elseif now ~= from then
				hops, from = hops + 1, now -- 걸어 내려서서 다른 발판에 왔다
			end
			local edge = Mesh.route(key, body.x, body.y, tx, ty)
			if edge == nil then
				return nil, ("길이 없다(%d, %d)"):format(body.x, body.y)
			elseif edge == "same" then
				if math.abs(tx - body.x) <= Navi.NEAR_X then
					return hops, nil
				end
				input.mx = if tx < body.x then -1 else 1
			else
				local dir = Mesh.dirOf(key, body.x, body.y, edge)
				if edge.kind == "walk" then
					expect(dir == (if edge.dir < 0 then "left" else "right"), "걸어 내려서는 쪽을 가리킨다")
					input.mx = edge.dir
				elseif not Mesh.at(edge, body.x) then
					expect(dir == (if edge.x < body.x then "left" else "right"), "뛸 자리 쪽을 가리킨다")
					input.mx = if edge.x < body.x then -1 else 1
				else
					-- 뛸 자리다: 그 길의 움직임을 한다(선 자리 그대로에서 — 뛸 자리에서 몇 점 어긋나 있다)
					expect(dir == "up" or dir == "down" or dir == (if edge.dir < 0 then "left" else "right"), "뛸 자리에서는 위 · 아래 · 건너뛸 쪽")
					local lx, ly = Mesh.try(scene, body.x, body.y, { kind = edge.kind, jump = edge.kind == "jump", down = edge.kind == "drop", double = edge.double, dir = edge.dir, hold = edge.hold })
					if not lx then
						return nil, ("뛸 자리(%d, %d)에서 그 움직임이 안 된다(%s · 방향 %d · 누르는 시간 %.2f)"):format(body.x, body.y, edge.kind, edge.dir, edge.hold)
					end
					body.x, body.y, body.vx, body.vy, body.ground = lx, ly, 0, 0, true
					hops += 1
					from = Mesh.standing(key, lx, ly)
					if hops > 40 then
						return nil, "건너가기만 마흔 번"
					end
					continue
				end
			end
		end
		-- 걷는다(공중이면 — 끝에서 내려서는 중 — 누르던 쪽 그대로)
		input.jump, input.down = false, false
		local before, grounded = body.x, body.ground
		if P.step(scene, body, input, 1 / 60) == "respawn" then
			return nil, "맵 아래로 떨어졌다"
		end
		if grounded and body.ground and body.x == before then
			return nil, ("걷다가 막혔다(%d, %d)"):format(body.x, body.y)
		end
	end
	return nil, "시간이 다 됐다"
end

-- ---- 1) 말씀하신 자리: 옛 망루(위층의 문은 오른쪽, 올라가는 발판은 왼쪽) ----
do
	local key = "r1c1"
	local sc = SCENES.scenes[key]
	expect(Mesh.work(key), "옛 망루 1층을 다 쟀다")
	-- 층들: 방의 폭을 다 덮는 얇은 바닥(=)과 그 사이의 작은 발판. 바닥에서 바로 위 바닥까지는 2단 점프로도 닿지 않는다(작은 발판을 디뎌야 한다)
	local floors, ledges = {}, {}
	for ty = 1, sc.h - 1 do
		local row = sc.rows[ty + 1]
		local n = select(2, string.gsub(row, "=", ""))
		if n >= sc.w - 6 then
			table.insert(floors, ty)
		elseif n > 0 then
			ledges[ty] = (string.find(row, "=", 1, true) :: number) - 1 -- 작은 발판의 첫 칸
		end
	end
	expect(#floors >= 3, "얇은 바닥이 여러 층이다")
	local checked = 0
	for i = 2, #floors do
		local upper, lower = floors[i - 1], floors[i]
		local ledgeRow, ledgeTx = nil, nil
		for ty, tx in ledges do
			if ty > upper and ty < lower then
				ledgeRow, ledgeTx = ty, tx
			end
		end
		if ledgeRow then
			local ledgeX = ledgeTx * T + 2 * T -- 작은 발판의 가운데쯤
			local left = ledgeX < sc.w * T / 2
			-- 아래 바닥에서, 작은 발판의 반대쪽 끝에 서서, 위 바닥의 같은 쪽 끝(작은 발판의 반대쪽)에 있는 곳으로 간다 — 스크린샷의 자리
			local hx = if left then (sc.w - 5) * T else 5 * T
			local edge = Mesh.route(key, hx, lower * T, hx, upper * T)
			expect(edge ~= nil and edge ~= "same", ("위층으로 가는 길이 있다(%d층 → %d층)"):format(lower, upper))
			if edge and edge ~= "same" then
				local dir = Mesh.dirOf(key, hx, lower * T, edge)
				eq(dir, if left then "left" else "right", ("갈 곳은 바로 위지만 화살표는 올라가는 발판 쪽을 가리킨다(발판은 %s)"):format(if left then "왼쪽" else "오른쪽"))
				-- 그 첫 걸음은 작은 발판으로 오르는 것이다
				local to = Mesh.of(key).surfaces[edge.to]
				eq(to.ty, ledgeRow, "첫 걸음 = 작은 발판에 오른다")
				-- 작은 발판 밑에 서면 「위」
				eq(Mesh.dirOf(key, edge.x, lower * T, edge), "up", "뛸 자리에 서면 위를 가리킨다")
				expect(edge.lo ~= nil and edge.hi ~= nil and edge.lo + edge.hi >= Mesh.TAKE, "뛸 자리는 한 점이 아니라 구간이다")
				-- 작은 발판 위에서는: 다시 「위」(바닥을 지나 올라선다) → 위 바닥에서는 갈 곳 쪽
				local e2 = Mesh.route(key, edge.lx, ledgeRow * T, hx, upper * T)
				expect(e2 ~= nil and e2 ~= "same" and Mesh.of(key).surfaces[e2.to].ty == upper, "작은 발판에서 위 바닥으로")
				local hops, why = follow(key, hx, lower * T, hx, upper * T)
				expect(hops ~= nil and hops >= 2 and hops <= 3, ("화살표를 따라가면 두세 번 건너 닿는다 — %s"):format(tostring(why or hops)))
				checked += 1
			end
		end
	end
	expect(checked >= 2, "층 사이를 확인했다 " .. checked)
	-- 내려갈 때: 위 바닥에서 아래 바닥의 곳으로 — 「아래」(하단 점프)이지 옆이 아니다
	local upper, lower = floors[1], floors[2]
	local mid = sc.w * T / 2
	local edge = Mesh.route(key, mid, upper * T, mid, lower * T)
	expect(edge ~= nil and edge ~= "same" and edge.kind == "drop", "아래층으로는 하단 점프")
	if edge and edge ~= "same" then
		local d = Mesh.dirOf(key, edge.x, upper * T, edge)
		eq(d, "down", "하단 점프를 할 자리에서는 아래를 가리킨다")
	end
end

-- ---- 2) 1지역의 모든 맵: 들어오는 자리마다(문 · 처음 서는 자리) 모든 문 · 주민 · 몬스터의 자리까지 길이 있고, 화살표를 따라가면 실제로 닿는다 ----
local maps, routes, walked, worst = 0, 0, 0, 0
for key, sc in SCENES.scenes do
	if sc.region == "r1" and sc.rows then
		maps += 1
		expect(Mesh.work(key), "다 쟀다 " .. key)
		local mesh = Mesh.of(key)
		expect(mesh.total <= 420, ("재는 자리의 수 %s %d — 한 장에 %d자리씩이면 %.1f초"):format(key, mesh.total, Navi.MESH_BUDGET, mesh.total / Navi.MESH_BUDGET / 60))
		worst = math.max(worst, mesh.total)
		local starts, goals = {}, {}
		if sc.spawn then
			table.insert(starts, { "처음 서는 자리", sc.spawn.x, sc.spawn.y })
		end
		for _, p in sc.portals or {} do
			table.insert(starts, { "문 " .. p.to, p.x, p.y })
			table.insert(goals, { "문 " .. p.to, p.x, p.y })
		end
		for _, n in sc.npcs or {} do
			table.insert(goals, { "주민 " .. n.id, n.x, n.y })
		end
		for _, m in sc.mobs or {} do
			table.insert(goals, { "몬스터 " .. m.kind, m.x, m.y })
		end
		for _, a in starts do
			local from = Mesh.below(key, a[2], a[3])
			expect(from ~= nil, ("들어오는 자리가 발판 위다 %s — %s(%d, %d)"):format(key, a[1], a[2], a[3]))
			if from then
				for _, b in goals do
					local to = Mesh.below(key, b[2], b[3])
					expect(to ~= nil, ("갈 곳이 발판 위다 %s — %s(%d, %d)"):format(key, b[1], b[2], b[3]))
					if to then
						local sx = math.clamp(a[2], from.x0 + 1, from.x1 - 1)
						local edge = Mesh.route(key, sx, from.y, b[2], b[3])
						routes += 1
						expect(edge ~= nil, ("길이 있다 %s: %s → %s"):format(key, a[1], b[1]))
						if edge and edge ~= "same" then
							local hops, why = follow(key, sx, from.y, b[2], b[3])
							walked += 1
							expect(hops ~= nil, ("화살표를 따라가면 닿는다 %s: %s → %s — %s"):format(key, a[1], b[1], tostring(why)))
						end
					end
				end
			end
		end
	end
end
expect(maps >= 20 and routes >= 200 and walked >= 60, ("맵 %d · 길 %d · 따라가 본 것 %d"):format(maps, routes, walked))
print(("[MESH] 1지역 맵 %d곳 · 길 %d개(그 가운데 발판을 건너는 %d개를 화살표대로 따라가 봄) · 가장 많이 재는 맵 %d자리"):format(maps, routes, walked, worst))

-- ---- 3) 화살표(Navi.arrow)가 그 길을 쓴다 ----
do
	-- 「마을 밖의 그림자」를 다 하고 옛 망루 1층에 서 있다 치고: 돌려줄 주민에게 가는 문을 겨눈다 — 그 문이 다른 층이면 화살표는 발판을 따라간다
	local key = "r1c1"
	local sc = SCENES.scenes[key]
	local book = { r1m1 = { done = true, c = {} }, r1m2 = { done = false, c = { 5 } } }
	local target = Navi.target("r1m2", book, 30, nil)
	expect(target ~= nil and target.scene ~= key, "돌려줄 곳은 다른 맵이다")
	local ax, ay, what, portal = Navi.aim(key, 0, 0, target, book, {})
	expect(what == "portal" and portal ~= nil, "나가는 문을 겨눈다")
	-- 문과 다른 층의 바닥마다 서 본다
	local tried = 0
	for ty = 1, sc.h - 1 do
		local row = sc.rows[ty + 1]
		if select(2, string.gsub(row, "[=#]", "")) >= sc.w - 6 and ty * T ~= ay and ty > 2 and string.sub(sc.rows[ty], 4, 4) == "." then
			for _, hx in { 5 * T, sc.w * T / 2, (sc.w - 5) * T } do
				local out = Navi.arrow("r1m2", key, hx, ty * T, book, 30, nil, {})
				expect(out ~= nil and out.mapped and out.edge ~= nil, ("맵을 알고 가리킨다(%d, %d)"):format(hx, ty * T))
				if out and out.edge then
					eq(out.dir, Mesh.dirOf(key, hx, ty * T, out.edge), "화살표 = 그 길의 첫 걸음")
					-- 예전의 셈(겨눈 자리의 가로만 본다)과 다를 수 있다: 뛸 자리가 문의 반대쪽이면 반대쪽을 가리킨다
					if out.edge.kind ~= "walk" and not Mesh.at(out.edge, hx) then
						eq(out.dir, if out.edge.x < hx then "left" else "right", "뛸 자리 쪽")
					end
					tried += 1
				end
			end
		end
	end
	expect(tried >= 6, "여러 층 · 여러 자리에서 봤다 " .. tried)
	-- 같은 발판이면: 문 쪽으로, 다 오면 ↑
	local psurf = Mesh.below(key, ax, ay)
	local out = Navi.arrow("r1m2", key, math.clamp(ax + 80, psurf.x0 + 8, psurf.x1 - 8), psurf.y, book, 30, nil, {})
	if math.abs(math.clamp(ax + 80, psurf.x0 + 8, psurf.x1 - 8) - ax) > Navi.NEAR_X then
		expect(out ~= nil and out.mapped and out.edge == nil and out.dir == "left", "문과 같은 발판: 문 쪽으로")
	end
	out = Navi.arrow("r1m2", key, ax + 4, psurf.y, book, 30, nil, {})
	expect(out ~= nil and out.dir == "enter", "문 앞: ↑를 누른다")
end

-- ---- 4) 조금씩 잰다: 다 잴 때까지는 예전의 셈으로 가리키고(멈추지 않는다), 다 재면 맵을 알고 가리킨다 ----
do
	Mesh.reset()
	local key = "r1c1"
	local sc = SCENES.scenes[key]
	local book = { r1m1 = { done = true, c = {} }, r1m2 = { done = false, c = { 5 } } }
	expect(not Mesh.ready(key), "처음에는 재지 않았다")
	local out = Navi.arrow("r1m2", key, sc.w * T / 2, (sc.h - 3) * T, book, 30, nil, {})
	expect(out ~= nil and out.mapped == false and out.dir ~= nil, "다 재기 전: 예전의 셈으로 가리킨다")
	local calls = 0
	while not Navi.prepare(key) do
		calls += 1
		if calls > 5000 then
			break
		end
	end
	local total = Mesh.of(key).total
	-- 자리마다 뛰어 본 뒤, 뛸 수 있는 구간의 끝을 한 번 더 잰다(그만큼 더 걸린다)
	expect(Mesh.ready(key) and calls >= math.floor(total / Navi.MESH_BUDGET) - 1 and calls <= math.ceil(total / Navi.MESH_BUDGET) * 2, ("한 장에 %d자리씩 재서 %d장 만에 끝난다(자리 %d)"):format(Navi.MESH_BUDGET, calls, total))
	expect(calls / 60 <= 2, ("길찾기를 켜고 2초 안에 맵을 다 잰다(%.1f초)"):format(calls / 60))
	expect(Navi.prepare(key) == true, "다 잰 뒤에는 바로 끝난다")
	-- 공중에 떠 있으면(선 발판이 없다) 길을 셈하지 않는다 — boot가 땅에 있을 때의 방향을 그대로 둔다
	eq(Mesh.route(key, sc.w * T / 2, (sc.h - 3) * T - 20, 5 * T, 7 * T), nil, "공중에서는 길을 셈하지 않는다")
	expect(Mesh.standing(key, sc.w * T / 2, (sc.h - 3) * T) ~= nil, "바닥에 서 있다")
end

-- ---- 4-2) 화살표가 흔들리지 않는다 ----
--  사용자 2026-10-13: "하단을 가르킬때는 왜 고장나면서 지진난것처럼 동작하나요?"
--  까닭: 아래층으로는 위층의 어디에서 하단 점프를 해도 걸리는 시간이 같다(내려가서 걷나, 걷고 내려가나) — 값이 같은 길이 여럿이라 아래층의 몬스터가 조금 움직일 때마다
--        내려갈 자리가 이리저리 바뀌었고, 화살표가 아래 · 왼쪽 · 오른쪽으로 장마다 바뀌었다(가만히 서 있어도 4초에 서른아홉 번).
do
	local key = "r1c1"
	local sc = SCENES.scenes[key]
	Mesh.work(key)
	local floors = {}
	for ty = 1, sc.h - 1 do
		if select(2, string.gsub(sc.rows[ty + 1], "=", "")) >= sc.w - 6 then
			table.insert(floors, ty)
		end
	end
	local upY, downY = floors[2] * T, floors[3] * T
	-- 위층에 가만히 서 있고 아래층의 몬스터가 오간다: 화살표는 줄곧 「아래」
	for _, hx in { 150, 200.3, 251.7, 301 } do
		local flips, last = 0, nil
		for f = 0, 240 do
			local tx = 120 + 100 * (1 + math.sin(f / 40))
			local e = Mesh.route(key, hx, upY, tx, downY)
			local d = if e == nil then "nil" elseif e == "same" then "same" else Mesh.dirOf(key, hx, upY, e)
			if last and d ~= last then
				flips += 1
			end
			last = d
			expect(d == "down", ("아래층의 몬스터에게: 선 자리에서 바로 「아래」(자리 %.1f · 몬스터 %.0f — %s)"):format(hx, tx, d))
		end
		eq(flips, 0, ("가만히 서 있으면 화살표가 바뀌지 않는다(자리 %.1f)"):format(hx))
	end
	-- 위층을 걸어가는 동안(한 걸음 1.5점): 화살표가 번갈아 바뀌지 않는다
	for _, goal in { 330, 60 } do
		local flips, last = 0, nil
		for px = 110, 300, 1.53 do
			local e = Mesh.route(key, px, upY, goal, downY)
			local d = if e == nil then "nil" elseif e == "same" then "same" else Mesh.dirOf(key, px, upY, e)
			if last and d ~= last then
				flips += 1
			end
			last = d
		end
		expect(flips <= 2, ("걸어가는 동안 화살표가 번갈아 바뀌지 않는다(바뀐 횟수 %d)"):format(flips))
	end
	-- 위층으로 갈 때도: 뛸 수 있는 구간 안에서는 어디서든 「위」(구간 = 되는 자리들 사이 — 재는 간격만큼)
	expect(Mesh.TAKE >= Mesh.SPACING, "되는 두 자리 사이는 어디서든 뛴다")
	-- 뛸 수 있는 구간이 걷는 한 걸음보다 좁은 뜀은 없다(그 자리에 설 수가 없어 화살표가 좌우로 오간다)
	local step = G.RUN / 60
	for _, s in Mesh.of(key).surfaces do
		for _, e in s.edges do
			if e.kind ~= "walk" then
				expect(e.lo + e.hi >= Mesh.NARROW and e.lo + e.hi > step * 1.5, ("뛸 수 있는 구간이 넉넉하다(%.2f점)"):format(e.lo + e.hi))
			end
		end
	end
	-- 겨누던 몬스터를 그대로 겨눈다: 둘이 비슷한 거리에서 오가도 이쪽저쪽으로 바뀌지 않는다
	local target = { scene = key, kind = "hunt", mob = "warrior" }
	local a, b = { kind = "warrior", x = 100, y = upY }, { kind = "warrior", x = 300, y = upY }
	local ax = Navi.aim(key, 195, upY, target, {}, { a, b })
	eq(ax, 100, "더 가까운 것을 겨눈다")
	local changes, prev = 0, ax
	for f = 1, 120 do
		a.x, b.x = 100 + 12 * math.sin(f / 5), 300 - 12 * math.sin(f / 5) -- 둘 다 195에서 95~107점: 번갈아 가까워진다
		local nx = Navi.aim(key, 197, upY, target, {}, { a, b })
		if (nx < 200) ~= (prev < 200) then
			changes += 1
		end
		prev = nx
	end
	eq(changes, 0, "비슷한 거리의 두 몬스터 사이에서 겨누는 것이 바뀌지 않는다")
	b.x = 210
	local nx = Navi.aim(key, 197, upY, target, {}, { a, b })
	eq(nx, 210, "훨씬 가까운 것이 생기면 그것으로 바꾼다")
	local only = Navi.aim(key, 197, upY, target, {}, { a })
	eq(only, a.x, "겨누던 것이 쓰러지면 남은 것으로")
end

-- ---- 5) 나머지 지역의 맵도 잴 수 있다(오류 없이 · 발판이 있다) ----
do
	local n = 0
	for key, sc in SCENES.scenes do
		if sc.region ~= "r1" and sc.rows then
			local mesh = Mesh.of(key)
			expect(mesh ~= nil and #mesh.surfaces >= 1, "발판이 있다 " .. key)
			n += 1
		end
	end
	expect(n >= 50, "다른 지역의 맵 " .. n)
end
