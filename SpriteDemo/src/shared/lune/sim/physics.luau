-- 횡스크롤 움직임 — 달리기 · 뛰기 · 떨어지기 · 발판. 화면과 상관없는 셈만 한다(클라이언트가 제 캐릭터를 움직이고, 서버가 같은 식으로 따져 본다).
--  공방 「횡스크롤 시험」 탭(dino-workshop/js/lune/luneTab.js)의 step()을 그대로 옮겼다.
--  장면의 칸(rows): "#" 막힌 칸 · "=" 아래에서 올라탈 수 있는 얇은 발판(↓를 누른 채 뛰기를 누르면 내려간다 — 하단 점프) · "^" 가시 · "." 빈 칸.
--  body = { x, y, vx, vy, ground, air = 땅을 떠난 뒤 공중에서 뛴 수(2단 점프 — 땅에 닿으면 0) } — (x, y)는 발밑 가운데.  input = { mx = -1 | 0 | 1, jump = 이번 걸음에 뛰기를 눌렀나, down = ↓를 누르고 있나, speed = 빠르기 배수(없으면 1),
--          vx = 가로 빠르기를 직접 준다(대쉬 · 기술 중의 이동), float = 떨어지지 않는다(대쉬), up = ↑를 누르고 있나(사다리) }
--  사다리(scene.ladders = { { x, top, bottom } } — 도트, 2026-10-16 밤): ↑를 누르면 잡고 곧게 오르고, ↓로 내린다. 오르는 동작 없이 쭉 미끄러지듯 — 사용자: "사다리 만들어서 기어올라가게도 만들고
--   올라가는 모션없이 그냥 쭈욱올라가게 간단하게 만들면됩니다". 꼭대기의 발판 위에서 ↓(뛰기 없이)를 누르면 잡고 내려간다(메이플처럼 — ↓ + 뛰기는 그대로 하단 점프). 뛰기 = 놓고 뛰어내린다
local G = require(script.Parent.Parent.config.game)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
-- 바닷속(scene.sea): 걷기는 조금 느리고, 뛰면 느리게 높이 떴다가 천천히 가라앉는다(공방 combat.js의 sea — 시험 탭과 같은 숫자)
local SEA = COMBAT.rules.sea

local T = G.TILE
local HALF = G.BOX_W / 2
local CLIMB = 80 -- 사다리를 오르내리는 빠르기(점/초 — 달리기 92보다 조금 느리게 · 제가 정한 것)
local GRAB = 7 -- 사다리 가운데에서 이만큼 안이면 잡는다(점)

local P = {}

-- 칸 하나. 맵 위는 빈 칸, 맵 아래와 좌우 밖은 막힌 칸이다.
function P.cell(scene, tx: number, ty: number): string
	if ty < 0 then
		return "."
	end
	if ty >= scene.h or tx < 0 or tx >= scene.w then
		return "#"
	end
	return string.sub(scene.rows[ty + 1], tx + 1, tx + 1)
end

-- 발밑 가운데가 (x, y)인 몸 상자가 막힌 칸에 걸리는가.
function P.solidBox(scene, x: number, y: number): boolean
	for ty = math.floor((y - G.BOX_H) / T), math.floor((y - 1) / T) do
		for tx = math.floor((x - HALF) / T), math.floor((x + HALF - 1) / T) do
			if P.cell(scene, tx, ty) == "#" then
				return true
			end
		end
	end
	return false
end

-- 가시(^)에 닿아 있는가: 발이 놓인 칸이 가시일 때(몸 폭에서 양옆 두 점씩 뺀 안쪽 — 스치기만 한 것은 치지 않는다). 가시 위로 뛰어넘는 동안에는 닿지 않는다.
--  닿으면 약한 피해를 입는다(서버 — sim/room.luau의 step. 사용자 2026-10-08: "맵에 가시 있잖아요 그거 닿으면 데미지 입게 약한데미지 입게하세요")
function P.onSpike(scene, x: number, y: number): boolean
	local ty = math.floor((y - 1) / T)
	for tx = math.floor((x - HALF + 2) / T), math.floor((x + HALF - 3) / T) do
		if P.cell(scene, tx, ty) == "^" then
			return true
		end
	end
	return false
end

-- 발밑이 얇은 발판(=)뿐인가 — 하단 점프를 할 수 있는 자리. 몸 폭 안의 발밑 칸에 막힌 칸(#)이 하나라도 있으면 아니다(그 칸이 받친다)
function P.onPlatform(scene, body): boolean
	local ty = math.floor(body.y / T)
	if body.y ~= ty * T then
		return false
	end
	local found = false
	for tx = math.floor((body.x - HALF) / T), math.floor((body.x + HALF - 1) / T) do
		local k = P.cell(scene, tx, ty)
		if k == "#" then
			return false
		elseif k == "=" then
			found = true
		end
	end
	return found
end

-- 그 자리에서 잡을 수 있는 사다리(번호 · 사다리) — 가로가 사다리 가운데에서 GRAB 안 · 세로가 꼭대기와 바닥 사이(양 끝 포함)
function P.ladderAt(scene, x: number, y: number): (number?, any)
	for i, l in scene.ladders or {} do
		if math.abs(x - l.x) <= GRAB and y >= l.top - 0.5 and y <= l.bottom + 0.5 then
			return i, l
		end
	end
	return nil, nil
end

function P.newBody(scene)
	return { x = scene.spawn.x, y = scene.spawn.y, vx = 0, vy = 0, ground = false }
end

function P.respawn(scene, body)
	body.x, body.y, body.vx, body.vy, body.ground = scene.spawn.x, scene.spawn.y, 0, 0, false
	body.air = 0
end

-- 한 걸음(dt초). 맵 아래로 떨어져 시작 자리로 돌아갔으면 "respawn"을 돌려준다.
--  가시("^")는 닿아도 시작 자리로 돌려보내지 않는다 — 사용자 2026-10-07: "가시맞고 돌아가는거 없애세요 가시맞고 돌아간다음에 몬스터랑 전투도안되고 고장나네요"
--   (2026-10-08부터는 닿으면 약한 피해를 입는다 — 위의 onSpike. 움직임은 그대로다)
--   (고장난 까닭: 화면에서만 시작 자리로 옮겨지고 서버는 그 순간이동을 믿지 않아, 그 뒤로 서버가 아는 자리와 어긋났다. 맵 아래로 떨어진 때를 위해 서버는 시작 자리로 온 보고는 받는다 — world.luau의 onMove)
function P.step(scene, body, input, dt: number): string?
	local mx = input.mx or 0
	local sea = if scene.sea then SEA else nil
	-- 사다리: 잡기(↑ — 꼭대기 아래에서 · ↓ — 꼭대기의 발판 위에서, 뛰기 없이)
	if not body.climb and not input.float and input.vx == nil and (input.up or (input.down and not input.jump and body.ground)) then
		local i, l = P.ladderAt(scene, body.x, body.y)
		if l and input.up and body.y > l.top + 0.5 then
			body.climb = i
		elseif l and input.down and math.abs(body.y - l.top) < 1 then
			body.climb, body.y = i, l.top + 1
		end
	end
	if body.climb then
		local l = (scene.ladders or {})[body.climb]
		if not l or input.float or input.vx ~= nil then
			body.climb = nil -- 사다리가 없는 장면으로 옮겼다 · 기술(대쉬)로 떨어져 나갔다
		elseif input.jump then
			body.climb = nil -- 뛰기: 놓는다(옆으로 누르고 있으면 그쪽으로 조금 뛰어내린다)
			body.vy = if mx ~= 0 then -G.JUMP * 0.5 else 0
			body.ground = false
			input = table.clone(input)
			input.jump = false
		else
			body.vx, body.vy, body.air = 0, 0, 0
			body.x = l.x
			local ny = body.y + ((if input.down then 1 else 0) - (if input.up then 1 else 0)) * CLIMB * dt
			if ny <= l.top then
				body.y, body.climb, body.ground = l.top, nil, true -- 꼭대기: 위의 발판에 선다
			elseif ny >= l.bottom then
				body.y, body.climb, body.ground = l.bottom, nil, true -- 바닥에 닿았다
			else
				body.y, body.ground = ny, false
			end
			return nil
		end
	end
	-- body.run · body.jump = 걸음 · 뛰는 힘의 배수(패시브 — 리븐의 날랜 몸 · 살라맨더의 뜨거운 피. 없으면 1)
	body.vx = if input.vx ~= nil then input.vx else mx * G.RUN * (input.speed or 1) * (body.run or 1) * (if sea then sea.run else 1)
	if input.jump and not body.ground and not input.float and (body.air or 0) < G.AIR_JUMPS then
		-- 2단 점프: 공중에서 뛰기를 한 번 더 누르면 그 자리에서 다시 뛰어오른다(전 직업 — 사용자 2026-10-11). 발판에서 걸어 떨어진 뒤에도 한 번 된다.
		--  땅에 닿으면 다시 센다. 바닷속에서도 같다(뛰는 힘만 바닷속의 것)
		body.air = (body.air or 0) + 1
		body.vy = -G.JUMP * G.JUMP2 * (body.jump or 1) * (if sea then sea.jump else 1)
	elseif input.jump and body.ground and not input.float then
		body.air = 0
		if input.down and P.onPlatform(scene, body) then
			-- 하단 점프: 발판 위에서 ↓ 를 누른 채 뛰기를 누르면 그 발판을 지나 내려간다(↓ 만으로는 내려가지 않는다).
			--  사용자 2026-10-08: "하단점프가 지금 그냥 아래키만 누르면 지금 하단점프인데 아래방향+점프키 여야 하단점프되어야합니다."
			--  발을 발판의 윗면 바로 아래로 옮긴다 — 그 발판은 더 받치지 않고, 그 아래의 발판 · 땅에는 평소처럼 선다
			body.y += 1
			body.vy = 0
			body.ground = false
		else
			body.vy = -G.JUMP * (body.jump or 1) * (if sea then sea.jump else 1)
			body.ground = false
		end
	end

	local nx = body.x + body.vx * dt
	if not P.solidBox(scene, nx, body.y) then
		body.x = nx
	end

	body.vy = if input.float then 0 else math.min(body.vy + G.GRAVITY * (if sea then sea.grav else 1) * dt, if sea then sea.fall else G.MAX_FALL) -- 대쉬 중에는 높이를 지킨다
	local ny = body.y + body.vy * dt
	if input.float then
		-- 떨어지지 않는다
	elseif body.vy >= 0 then
		-- 내려가는 중: 막힌 칸이나 발판 윗면에 선다
		local land: number? = nil
		local ty = math.floor(body.y / T)
		while ty <= math.floor(ny / T) and land == nil do
			for tx = math.floor((body.x - HALF) / T), math.floor((body.x + HALF - 1) / T) do
				local k = P.cell(scene, tx, ty)
				if k == "#" or (k == "=" and body.y <= ty * T) then
					land = ty * T
					break
				end
			end
			ty += 1
		end
		if land ~= nil and ny >= land then
			body.y, body.vy, body.ground = land, 0, true
			body.air = 0 -- 땅에 닿았다: 2단 점프를 다시 쓴다
		else
			body.y, body.ground = ny, false
		end
	elseif P.solidBox(scene, body.x, ny) then
		body.vy = 0 -- 머리가 닿았다
	else
		body.y, body.ground = ny, false
	end

	if body.y > scene.h * T + G.FALL_OUT then
		P.respawn(scene, body)
		return "respawn"
	end
	return nil
end

-- 지금 보일 동작 이름(서 있기 · 달리기 · 뛰기 · 떨어지기)
function P.clipOf(body, mx: number): string
	if body.climb then
		return "idle" -- 사다리: 오르는 동작 없이 서 있는 모습 그대로 미끄러진다(사용자 2026-10-16 밤)
	end
	if not body.ground then
		return if body.vy < 0 then "jump" else "fall"
	end
	return if mx ~= 0 then "run" else "idle"
end

return P
