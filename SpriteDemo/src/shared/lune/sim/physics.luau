-- 횡스크롤 움직임 — 달리기 · 뛰기 · 떨어지기 · 발판. 화면과 상관없는 셈만 한다(클라이언트가 제 캐릭터를 움직이고, 서버가 같은 식으로 따져 본다).
--  공방 「횡스크롤 시험」 탭(dino-workshop/js/lune/luneTab.js)의 step()을 그대로 옮겼다.
--  장면의 칸(rows): "#" 막힌 칸 · "=" 아래에서 올라탈 수 있는 얇은 발판(↓를 누르면 내려간다) · "^" 가시 · "." 빈 칸.
--  body = { x, y, vx, vy, ground } — (x, y)는 발밑 가운데.  input = { mx = -1 | 0 | 1, jump = 이번 걸음에 뛰기를 눌렀나, down = ↓를 누르고 있나, speed = 빠르기 배수(없으면 1),
--          vx = 가로 빠르기를 직접 준다(대쉬 · 기술 중의 이동), float = 떨어지지 않는다(대쉬) }
local G = require(script.Parent.Parent.config.game)

local T = G.TILE
local HALF = G.BOX_W / 2

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

function P.newBody(scene)
	return { x = scene.spawn.x, y = scene.spawn.y, vx = 0, vy = 0, ground = false }
end

function P.respawn(scene, body)
	body.x, body.y, body.vx, body.vy, body.ground = scene.spawn.x, scene.spawn.y, 0, 0, false
end

-- 한 걸음(dt초). 맵 아래로 떨어져 시작 자리로 돌아갔으면 "respawn"을 돌려준다.
--  가시("^")는 닿아도 아무 일도 일어나지 않는다 — 사용자 2026-10-07: "가시맞고 돌아가는거 없애세요 가시맞고 돌아간다음에 몬스터랑 전투도안되고 고장나네요"
--   (고장난 까닭: 화면에서만 시작 자리로 옮겨지고 서버는 그 순간이동을 믿지 않아, 그 뒤로 서버가 아는 자리와 어긋났다. 맵 아래로 떨어진 때를 위해 서버는 시작 자리로 온 보고는 받는다 — world.luau의 onMove)
function P.step(scene, body, input, dt: number): string?
	local mx = input.mx or 0
	body.vx = if input.vx ~= nil then input.vx else mx * G.RUN * (input.speed or 1)
	if input.jump and body.ground and not input.float then
		body.vy = -G.JUMP
		body.ground = false
	end

	local nx = body.x + body.vx * dt
	if not P.solidBox(scene, nx, body.y) then
		body.x = nx
	end

	body.vy = if input.float then 0 else math.min(body.vy + G.GRAVITY * dt, G.MAX_FALL) -- 대쉬 중에는 높이를 지킨다
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
				if k == "#" or (k == "=" and body.y <= ty * T and not input.down) then
					land = ty * T
					break
				end
			end
			ty += 1
		end
		if land ~= nil and ny >= land then
			body.y, body.vy, body.ground = land, 0, true
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
	if not body.ground then
		return if body.vy < 0 then "jump" else "fall"
	end
	return if mx ~= 0 then "run" else "idle"
end

return P
