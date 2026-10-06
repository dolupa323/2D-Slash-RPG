-- 미니맵의 자리 셈(그리지는 않는다 — 그리기는 client/lune/minimap.luau). 장면의 칸 격자를 작은 상자에 줄여 넣는다.
--  가로 · 세로를 같은 비율로 줄이고(맵의 생김새가 그대로 보이게) 상자 가운데에 놓는다. 좌표는 모두 상자 안의 도트.
local M = {}

-- 장면을 w x h 상자에 넣는 꼴.
--  돌려주는 것: { s = 한 칸이 몇 도트인가, w, h = 줄인 맵의 크기, ox, oy = 상자 안에서의 왼쪽 위,
--                ground = 땅 덩어리 { x, y, w, h }…, steps = 발판 { x, y, w, h }… }
function M.layout(scene, w: number, h: number)
	local s = math.min(w / scene.w, h / scene.h)
	local mw = math.max(1, math.min(w, math.floor(scene.w * s + 0.5)))
	local mh = math.max(1, math.min(h, math.floor(scene.h * s + 0.5)))
	local out = { s = s, w = mw, h = mh, ox = math.floor((w - mw) / 2), oy = math.floor((h - mh) / 2), ground = {}, steps = {} }

	-- 땅: 도트 한 줄(세로)마다 가장 위의 막힌 칸부터 바닥까지. 높이가 같은 줄은 하나로 잇는다
	local run = nil
	for c = 0, mw - 1 do
		local tx = math.min(scene.w - 1, math.floor((c + 0.5) / s))
		local top = nil
		for ty = 0, scene.h - 1 do
			if string.sub(scene.rows[ty + 1], tx + 1, tx + 1) == "#" then
				top = math.min(mh - 1, math.floor(ty * s))
				break
			end
		end
		if run and run.top == top then
			run.w += 1
		else
			run = { top = top, x = c, w = 1 }
			if top then
				table.insert(out.ground, run)
			end
		end
	end
	for _, g in out.ground do
		g.y, g.h, g.top = g.top, mh - g.top, nil
	end

	-- 발판: 가로로 이어진 "="를 한 도트 높이의 줄로
	for ty = 0, scene.h - 1 do
		local row = scene.rows[ty + 1]
		local from = nil
		for tx = 0, scene.w do
			local on = tx < scene.w and string.sub(row, tx + 1, tx + 1) == "="
			if on and not from then
				from = tx
			elseif not on and from then
				local x0 = math.min(mw - 1, math.floor(from * s))
				local x1 = math.max(x0 + 1, math.min(mw, math.floor(tx * s + 0.5)))
				table.insert(out.steps, { x = x0, y = math.min(mh - 1, math.floor(ty * s)), w = x1 - x0, h = 1 })
				from = nil
			end
		end
	end
	return out
end

-- 미니맵 상자의 폭: 맵 이름이 기본 폭에 다 들어가지 않으면 이름만큼 늘어난다(공방의 화면 규칙 — 글이 길면 상자가 늘어난다).
--  그래도 max(보스 체력 칸의 왼쪽)를 넘지는 않는다 — 그보다 긴 이름은 줄여 적는다.
function M.boxWidth(nameWidth: number, base: number, max: number, pad: number): number
	return math.clamp(nameWidth + pad * 2, base, max)
end

-- 미니맵 판 안의 자리: 옆 테두리 · 맵 이름 줄(그 아래부터 줄인 맵) · 아래 테두리, 맵 이름의 왼쪽(보석 그림 다음)과 오른쪽 여백
M.SIDE, M.TOP, M.BOTTOM, M.NAME_X, M.NAME_R = 3, 14, 3, 13, 4

-- 맵 이름이 들어가는 판의 폭(기본 폭부터 max까지)
function M.boxFor(nameWidth: number, base: number, max: number): number
	return math.clamp(nameWidth + M.NAME_X + M.NAME_R, base, max)
end

-- 장면 안의 한 점(도트 — 발밑)이 미니맵의 어느 도트인가(줄인 맵 안으로 가둔다)
function M.point(layout, tile: number, x: number, y: number): (number, number)
	local px = math.clamp(math.floor(x / tile * layout.s), 0, layout.w - 1)
	local py = math.clamp(math.floor(y / tile * layout.s), 0, layout.h - 1)
	return px, py
end

return M
