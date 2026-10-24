-- 리틀 무니 — 대검 · 달 수정. 공격이 느리고 한 대 한 대가 무겁다(누르고 있는 기술 · 빠른 연타는 쓰지 않는다 — 사용자 지시 2026-10-05).
--   핵심 장치: 수정 공명(대검이 맞으면 그 자리에 수정이 맺히고, 수정 가까이에서 쓴 대검 기술은 수정에서도 같이 나간다).
--  공방 시험 탭의 dino-workshop/js/lune/kits/mooni.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   수정 둘까지(1차) → 넷까지(수정 군락)
--   수정 조각: 1.5초에 한 번 · 수정마다 하나(1차) → 둘씩(쌍조각) → 꿰뚫고 지나간다(꿰뚫는 조각) → 검 모양으로 커지고 1초에 한 번(수정 검)
--   달빛 칼날(3차 패시브): 다섯 번째 타마다 한 번 더 번진다 · 수호령 하나 → 둘(수호령 각성 — 시험판에는 하나만 있다. 둘째는 아직 없다)
--  Aseprite로 그린 수정(성역 · 방벽 · 감옥 · 수호령)은 점 자료(data/fxart.generated.luau)를 그림판에 그대로 찍는다 — g.art.mn_cr(앞) · g.art.mn_crb(뒤).
--  옮기며 바뀐 것: end → finish · until → till · 캔버스의 옮기고 뒤집어 그리기(translate · scale · drawImage) → ctx:blit · 오려 그리기(clip) → Fx.polyIn.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local crescentPts, starPts, poly, line, disc, drawCrystal, polyIn = Fx.crescentPts, Fx.starPts, Fx.poly, Fx.line, Fx.disc, Fx.drawCrystal, Fx.polyIn
local dash, buff, distSeg = Common.dash, Common.buff, Common.distSeg
local floor, sin, cos, min, max, abs, sqrt, atan2, PI = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.sqrt, math.atan2, math.pi
local function R(v: number): number
	return floor(v + 0.5)
end

local function crystals(g)
	local keep = {}
	for _, c in g.s.cr do
		if not c.dead and c.t < c.life then
			keep[#keep + 1] = c
		end
	end
	g.s.cr = keep
	return keep
end
-- 달 수정 하나를 세운다(넘치면 가장 오래된 것이 사라진다). force = 서버가 정한 자리(가까이 겹치는지 · 넘치는지 보지 않는다)
local function addCrystal(g, x: number, y: number, life: number?, force: boolean?)
	local list = crystals(g)
	if not force then
		for _, c in list do
			if abs(c.x - x) < 18 and abs(c.y - y) < 20 then
				return nil
			end
		end
		if #list >= (if g.sk("mn_grove") > 0 then 4 else 2) then
			list[1].dead = true
		end
	end
	local tone = g.tone
	local c = g.shot({ x = x, y = y, life = life or 20, back = true, cracked = false, draw = function(ctx, p)
		local h = min(15, p.t * 80) * min(1, (p.life - p.t) * 3)
		drawCrystal(ctx, p.x, p.y, 8, h, tone, p.cracked)
		if floor(p.t * 3) % 4 == 0 then
			ctx:style(tone.w)
			ctx:rect(R(p.x) + 3, R(p.y - h) - 2, 1, 3)
			ctx:rect(R(p.x) + 2, R(p.y - h) - 1, 3, 1)
		end
	end })
	table.insert(g.s.cr, c)
	g.fx.hex(x, y - 4, 2, 12, tone, { squash = 0.5 })
	return c
end
-- 공명: 가까운 수정마다
local function reson(g, fn, range: number?)
	for _, c in crystals(g) do
		if abs(c.x - g.x) < (range or 140) and abs(c.y - g.y) < 50 then
			fn(c)
		end
	end
end

-- 수정 조각 하나(사출기 — 1차에 배우고 2~4차 패시브가 강화한다): (x, y)에서 t에게 곧게 날아간다. 꿰뚫는 조각부터는 지나가며 길 위의 적을 모두 치고, 수정 검부터는 검 모양으로 크다.
--  o.land = 처음 닿은 순간에 부를 것
local function shard(g, x: number, y: number, t, o)
	if not t or t.dead >= 0 then
		return
	end
	local tone = g.tone
	local a = atan2(t.y - t.h - 8 - y, t.x - x)
	local c, s = cos(a), sin(a)
	local sword, pierce = g.sk("mn_shard4") > 0, g.sk("mn_shard3") > 0
	g.shot({
		x = x,
		y = y,
		vx = c * 280,
		vy = s * 280,
		life = 0.6,
		w = 10,
		h = 10,
		dmg = 4,
		ghost = true,
		o = { proc = true },
		draw = function(ctx, p)
			if sword then
				poly(ctx, { { p.x + c * 9, p.y + s * 9 }, { p.x - s * 2.5, p.y + c * 2.5 }, { p.x - c * 7, p.y - s * 7 }, { p.x + s * 2.5, p.y - c * 2.5 } }, tone.l)
				line(ctx, p.x - c * 5, p.y - s * 5, p.x + c * 6, p.y + s * 6, tone.w)
			else -- 수정에서 떨어져 나와 곧게 날아가는 작은 마름모
				poly(ctx, { { p.x + c * 5, p.y + s * 5 }, { p.x - s * 2, p.y + c * 2 }, { p.x - c * 4, p.y - s * 4 }, { p.x + s * 2, p.y - c * 2 } }, tone.l)
				ctx:style(tone.w)
				ctx:rect(R(p.x), R(p.y), 1, 1)
			end
		end,
		onHit = function(p, m)
			g.fx.pop(m.x, m.y - m.h - 8, tone, { r = 4 })
			if o and o.land then
				o.land()
				o.land = nil
			end
			if not pierce then
				p.dead = true
			end
		end,
	})
end
-- 대검이 맞았다: 수정마다(없으면 대검에서) 조각을 보낸다
local function shards(g, from)
	local src = {}
	for _, c in crystals(g) do
		src[#src + 1] = { c.x, c.y - 12 }
	end
	if #src == 0 then
		src[1] = { g.x, g.y - 14 }
	end
	local n = if g.sk("mn_shard2") > 0 then 2 else 1
	for i, q in src do
		for j = 0, n - 1 do
			g.after((i - 1) * 0.06 + j * 0.09, function()
				local t = g.nearest(190, { from = q[1] }) or from
				if not t or t.dead >= 0 then
					return
				end
				g.call("shard", q[1], q[2], t)
			end)
		end
	end
end

local function wave(g, x: number, dir: number, first: boolean) -- 달빛 파도: 바닥을 따라 굴러가는 물결 — 수정을 지나면 한 번 더 인다
	local tone = g.tone
	g.shot({
		x = x,
		y = g.y,
		vx = dir * 170,
		life = 0.9,
		w = 18,
		h = 26,
		dmg = if first then 7 else 4,
		ghost = true,
		o = { lift = 90 },
		passed = {},
		update = function(p)
			for _, c in crystals(g) do
				if not p.passed[c] and abs(c.x - p.x) < 8 then
					p.passed[c] = true
					g.fx.hex(c.x, c.y - 6, 3, 14, tone, { squash = 1, back = false })
					if first then
						wave(g, c.x + dir * 6, dir, false)
					end
				end
			end
		end,
		draw = function(ctx, p)
			for i = 0, 2 do
				poly(ctx, crescentPts(p.x - dir * i * 8, p.y, (if first then 12 else 8) - i * 2, 4, 15, 165, dir, 6), if i ~= 0 then tone.n else tone.l)
			end
		end,
	})
end

local function ray(g) -- 월광선: 한 번 내지르면 굵은 빛줄기가 뻗어 수정에서 꺾인다 — 마디를 지나는 적을 세 번 태운다
	local dir, pts, used, cs = g.dir, { { g.fwd(16), g.y - 11 } }, {}, crystals(g)
	local function pick(from, test)
		local best = nil
		for _, k in cs do
			if not used[k] and test(k) and (not best or abs(k.x - from) < abs(best.x - from)) then
				best = k
			end
		end
		return best
	end
	local c = pick(g.x, function(k)
		return (k.x - g.x) * dir > 10 and (k.x - g.x) * dir < 170 and abs(k.y - g.y) < 40
	end)
	while c and #pts < 5 do
		used[c] = true
		pts[#pts + 1] = { c.x, c.y - 10 }
		local from = c
		c = pick(from.x, function(k)
			return sqrt((k.x - from.x) ^ 2 + (k.y - from.y) ^ 2) < 150
		end)
	end
	local last = pts[#pts]
	pts[#pts + 1] = { last[1] + dir * (if #pts == 1 then 180 else 90), last[2] }
	g.s.ray, g.s.rayAt = pts, g.clock
	for _, t in { 0, 0.12, 0.24 } do
		g.after(t, function()
			for _, m in g.mobs() do
				for i = 1, #pts - 1 do
					if distSeg(m.x, m.y - m.h - 8, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]) < (if m.boss then 20 else 13) then
						g.hurt(m, 6, if t ~= 0 then {} else { stop = 0.05 })
						break
					end
				end
			end
		end)
	end
	for i = 2, #pts - 1 do
		g.fx.hex(pts[i][1], pts[i][2], 3, 20, g.tone, { squash = 1, back = false })
	end
	for i = 1, #pts - 1 do
		g.fx.shards((pts[i][1] + pts[i + 1][1]) / 2, (pts[i][2] + pts[i + 1][2]) / 2, 5, g.tone, { kind = "bar", speed = 80, up = 20, life = 0.35 })
	end
end
local RAY_LIFE = 0.5
local function drawRay(ctx, g) -- 굵은 빛줄기: 바깥 번짐 · 네온 · 밝은 속 · 흰 심 네 겹. 태울 때마다(세 번) 부풀고, 끝은 뾰족하며, 칼끝과 마디에서 섬광이 돈다. 가늘어지면 바로 꺼진다
	local p = g.s.ray
	if not p then
		return
	end
	local k = (g.clock - g.s.rayAt) / RAY_LIFE
	if k < 0 or k >= 1 then
		return
	end
	local tone, el = g.tone, k * RAY_LIFE
	local pulse = if el < 0.3 then max(0, 1 - (el % 0.12) / 0.08) else 0
	local th = if k < 0.06 then 17 * (k / 0.06) elseif k < 0.62 then 13 + 5 * pulse else 13 * (1 - (k - 0.62) / 0.38)
	if th < 3 then
		return
	end
	local function seg(a, b, w, c)
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local l = sqrt(dx * dx + dy * dy)
		if l == 0 then
			l = 1
		end
		local nx, ny = ((-dy / l) * w) / 2, ((dx / l) * w) / 2
		poly(ctx, { { a[1] + nx, a[2] + ny }, { b[1] + nx, b[2] + ny }, { b[1] - nx, b[2] - ny }, { a[1] - nx, a[2] - ny } }, c)
	end
	for _, layer in { { th + 8, tone.n, 0.3 }, { th, tone.n, 1 }, { th * 0.62, tone.l, 1 }, { th * 0.3, tone.w, 1 } } do
		local w, c = layer[1], layer[2]
		ctx:alpha(layer[3])
		for i = 1, #p - 1 do
			local a, b = p[i], p[i + 1]
			if i + 2 <= #p then
				seg(a, b, w, c)
				continue
			end
			-- 끝은 뾰족하게
			local dx, dy = b[1] - a[1], b[2] - a[2]
			local l = sqrt(dx * dx + dy * dy)
			if l == 0 then
				l = 1
			end
			local m = { b[1] - (dx / l) * 28, b[2] - (dy / l) * 28 }
			local nx, ny = ((-dy / l) * w) / 2, ((dx / l) * w) / 2
			seg(a, m, w, c)
			poly(ctx, { { m[1] + nx, m[2] + ny }, b, { m[1] - nx, m[2] - ny } }, c)
		end
		for i = 2, #p - 1 do -- 꺾이는 마디는 둥글게 잇는다
			disc(ctx, p[i][1], p[i][2], max(1, R(w * 0.5)), c)
		end
	end
	ctx:alpha(1)
	for i = 1, #p - 1 do -- 칼끝과 마디의 섬광
		poly(ctx, starPts(p[i][1], p[i][2], th * (if i > 1 then 1.15 else 0.95), g.clock * 9 + (i - 1)), tone.w)
	end
end

-- 만월 베기: 화면 끝까지 뻗는 아주 굵은 빛줄기 — 가장자리가 일렁이고, 밝은 마디가 줄기를 타고 달리며, 끝은 뾰족하다. 가늘어지면 바로 꺼진다
local function moonLaser(g)
	local dir, tone, x0, y, LEN = g.dir, g.tone, g.fwd(14), g.y - 13, 300
	g.fx.add(0.5, function(ctx, k)
		local th = if k < 0.08 then 30 * (k / 0.08) elseif k < 0.5 then 30 - 6 * ((k - 0.08) / 0.42) else 24 * (1 - (k - 0.5) / 0.5)
		local t = k * 0.5
		if th < 3 then
			return
		end
		for i = 0, LEN - 1, 2 do
			local w = th * min(1, 0.55 + i / 22) * min(1, (LEN - i) / 36) * (1 + 0.18 * max(0, sin(i * 0.06 - t * 60))) + sin(i * 1.3 + t * 90)
			local px = R(if dir > 0 then x0 + i else x0 - i - 2)
			if w < 1 then
				continue
			end
			ctx:alpha(0.3)
			ctx:style(tone.n)
			ctx:rect(px, R(y - w / 2 - 4), 2, R(w + 8))
			ctx:alpha(1)
			ctx:rect(px, R(y - w / 2), 2, R(w))
			ctx:style(tone.l)
			ctx:rect(px, R(y - w * 0.32), 2, R(w * 0.64))
			ctx:style(tone.w)
			ctx:rect(px, R(y - w * 0.16), 2, max(1, R(w * 0.32)))
		end
		ctx:alpha(1)
		disc(ctx, x0, y, R(th * 0.6), tone.l)
		poly(ctx, starPts(x0, y, th * 1.05, t * 10), tone.w) -- 칼끝의 섬광
	end)
	for i = 0, 9 do
		g.fx.shards(x0 + dir * (24 + i * 28), y, 2, tone, { kind = "bar", speed = 80, up = 10, life = 0.35 })
	end
	g.fx.streaks(g.fwd(150), g.y, 10, -dir, tone, { w = 280, h = 26 })
end

local function range(g)
	local x, y, tone = g.x, g.y, g.tone
	g.invert(0.07)
	g.shake(7, 0.4)
	g.fx.beam(x, y, 22, 230, tone, { life = 0.6 })
	g.fx.ring(x, y, 8, 60, tone)
	for i = 1, 8 do
		for _, s in { -1, 1 } do
			local sx, h = x + s * (48 + i * 15), 22 + ((i * 7) % 3) * 12 - i
			g.fx.spike(sx, y, 14, h, tone, { delay = 0.1 + i * 0.05, life = 0.8, lean = s * 5 })
			g.after(0.1 + i * 0.05, function()
				g.hitAt(sx, y, 10, 44, 4, { lift = 220 })
				g.fx.shards(sx, y - h, 2, tone, { up = 60 })
			end)
		end
	end
	g.hitAt(x, y, 62, 60, 6, { lift = 240 })
end

-- 달빛 낙하(4차 — 2026-10-24 사용자 "하늘이 어둡게물들고 빛줄기가 순차적으로 쾅쾅쾅 떨어지는 광역기 … 스킬 이펙트만 순차적으로 떨어지는거고 데미지는 스킬 실행하는시점에 동시판정들어가야한다"
--   → "전혀 광역기가 아니잖아 쿨타임 12초고 전맵에 닿아야하는거야 그리고 레이저는 에셋 레이저 똑같이 써도되는데 그게 달에서 순차적으로 발사되는식으로"):
--  판정: 쓰는 순간 그 맵의 모든 적(층 · 거리와 상관없이)이 한꺼번에 맞는다(한 번). 그 뒤는 그림만 — 피해는 없다.
--  ① 하늘이 물든다: 화면 전체(카메라 기준 · 뒤 그림판이라 사람 · 몬스터는 그 앞에 밝다)에 위가 짙고 아래로 옅어지는 남색 밤하늘 · 반짝이는 별 · 화면 위 가운데로 내려와 뜨는 큰 초승달
--  ② 초승달에서 맞은 적에게(가까운 차례로 FALL_N까지 — 적이 적으면 앞쪽 빈자리로) 레이저가 0.1초 간격으로 한 줄씩 발사된다 — 월광선과 같은 레이저(바깥 번짐 · 네온 · 밝은 속 · 흰 심, 끝은 뾰족)
--  ③ 닿은 자리마다 쾅 — 초승달 모양 충격파(반원) · 흰 섬광 · 별 반짝임 · 수정 파편
--  (처음 것은 액시온 「달기둥」과 같은 빛기둥 · 고리를 썼다 — 빛기둥(fx.beam) · 고리(fx.ring)는 쓰지 않는다)
local FALL_N, FALL_GAP = 8, 0.1 -- 레이저 수 · 사이(초)
local FALL_SPOTS = { 40, 100, 160, 70, 130 } -- 적이 다섯보다 적을 때 채우는 자리(내 앞 몇 도트)
local NIGHT = 0x10173a -- 물든 하늘의 빛깔(짙은 남색)
local FALL_LIFE = 1.9 -- 하늘이 물들어 있는 시간(초)
-- 초승달이 뜨는 자리(화면 위 가운데)
local function moonAt(g): (number, number)
	local cam = g.cam
	return cam.x + 192, cam.y + 34
end
-- 레이저 한 줄 a → b(굵기 th): 월광선(drawRay)과 같은 네 겹 · 끝은 뾰족
local function laser(ctx, tone, ax: number, ay: number, bx: number, by: number, th: number)
	local dx, dy = bx - ax, by - ay
	local l = max(1, sqrt(dx * dx + dy * dy))
	local ux, uy = dx / l, dy / l
	local mx, my = bx - ux * min(28, l * 0.3), by - uy * min(28, l * 0.3)
	for _, layer in { { th + 8, tone.n, 0.3 }, { th, tone.n, 1 }, { th * 0.62, tone.l, 1 }, { th * 0.3, tone.w, 1 } } do
		local w = layer[1]
		local nx, ny = -uy * w / 2, ux * w / 2
		ctx:alpha(layer[3])
		poly(ctx, { { ax + nx, ay + ny }, { mx + nx, my + ny }, { mx - nx, my - ny }, { ax - nx, ay - ny } }, layer[2])
		poly(ctx, { { mx + nx, my + ny }, { bx, by }, { mx - nx, my - ny } }, layer[2])
	end
	ctx:alpha(1)
end
local function fall(g)
	local x, y, dir, tone = g.x, g.y, g.dir, g.tone
	local spots = {}
	for _, m in g.mobs() do -- 판정은 여기 한 번: 맵의 모든 적
		g.hurt(m, 10, { stop = 0.06 })
		spots[#spots + 1] = { m.x, m.y - 6, abs(m.x - x) + abs(m.y - y) }
	end
	table.sort(spots, function(p, q)
		return p[3] < q[3]
	end)
	for i = #spots + 1, #FALL_SPOTS do
		spots[i] = { x + dir * FALL_SPOTS[i], y, 0 }
	end
	g.fx.add(FALL_LIFE, function(ctx, k)
		local cam, t = g.cam, k * FALL_LIFE
		local a = if k < 0.12 then k / 0.12 elseif k > 0.82 then (1 - k) / 0.18 else 1
		for b = 0, 5 do -- 위가 짙고 아래로 옅어지는 남색
			ctx:alpha(a * (0.78 - b * 0.1))
			ctx:style(NIGHT)
			ctx:rect(R(cam.x) - 8, R(cam.y) - 8 + b * 40, 400, 40)
		end
		for i = 1, 18 do -- 반짝이는 별
			if (floor(t * 9) + i) % 4 ~= 0 then
				local sx, sy = R(cam.x + (i * 67) % 384), R(cam.y + 8 + (i * 37) % 100)
				ctx:alpha(a * (if i % 3 == 0 then 1 else 0.7))
				ctx:style(if i % 3 == 0 then tone.w else tone.l)
				ctx:rect(sx, sy, 1, 1)
				if i % 5 == 0 then
					ctx:rect(sx - 1, sy, 3, 1)
					ctx:rect(sx, sy - 1, 1, 3)
				end
			end
		end
		local mx, my = moonAt(g)
		my -= 30 * max(0, 1 - t / 0.3) -- 위에서 내려와 뜬다
		ctx:alpha(a * 0.25)
		disc(ctx, mx, my, 22, tone.l)
		ctx:alpha(a)
		poly(ctx, crescentPts(mx, my, 15, 9, 95, 265, 1, 10), tone.w)
		poly(ctx, crescentPts(mx, my, 15, 3, 110, 250, 1, 8), tone.l)
		ctx:alpha(1)
	end, { back = true })
	for i = 1, min(FALL_N, #spots) do
		local bx, by = spots[i][1], spots[i][2]
		g.after(0.3 + (i - 1) * FALL_GAP, function() -- ② 달에서 레이저 발사
			g.fx.add(0.32, function(ctx, k)
				local sx, sy = moonAt(g)
				local th = if k < 0.12 then 12 * (k / 0.12) elseif k < 0.55 then 12 else 12 * (1 - (k - 0.55) / 0.45)
				if th >= 2 then
					laser(ctx, tone, sx, sy + 6, bx, by, th)
				end
			end)
			g.fx.add(0.32, function(ctx, k) -- ③ 쾅: 초승달 모양 충격파
				ctx:alpha(1 - k)
				poly(ctx, crescentPts(bx, by + 6, 10 + 34 * k, max(1, 7 * (1 - k)), 8, 172, 1, 9), tone.l)
				ctx:alpha(1)
			end, { back = true })
			g.fx.add(0.08, function(ctx)
				disc(ctx, bx, by, 9, tone.w)
			end)
			for j = 0, 2 do
				local ox = (j - 1) * 9
				g.fx.add(0.4, function(ctx, k)
					poly(ctx, starPts(bx + ox, by - 2 - j * 4 - 26 * k, max(1, 7 * (1 - k)), k * 3), if j == 1 then tone.w else tone.l)
				end)
			end
			g.fx.shards(bx, by + 3, 8, tone, { up = 130, kind = "tri" })
			g.shake(3, 0.08)
		end)
	end
end

-- ---- Aseprite로 그린 수정(assetpack/lune/fx/mooni_crystals.aseprite → 앞 · 뒤 두 장). { x, y, w, h } ----
local CR = { tall = { 0, 8, 15, 40 }, mid = { 18, 20, 14, 28 }, small = { 34, 32, 9, 16 }, prison = { 46, 8, 32, 40 }, spirit = { 82, 4, 11, 19 } }
-- 수정 한 개: 밑동 가운데가 (x, y). grow < 1이면 땅에서 솟는 중(윗부분부터 드러난다). o = { flip, sc, alpha, grow }
local function crystal(ctx, img, name: string, x: number, y: number, o)
	if not img then
		return
	end
	local r = CR[name]
	local w, h = r[3], r[4]
	local hh = max(1, R(h * min(1, (o and o.grow) or 1)))
	ctx:blit(img, r[1], r[2], w, hh, R(x), R(y), -floor(w / 2), -hh, o ~= nil and o.flip == true, (o and o.sc) or 1, (o and o.alpha) or 1)
end
local function ell(ctx, x: number, y: number, rx: number, ry: number, c: number)
	ctx:style(c)
	local n = R(ry)
	for dy = -n, n do
		local w = sqrt(max(0, 1 - (dy * dy) / (if ry * ry == 0 then 1 else ry * ry))) * rx
		if w >= 0.5 then
			ctx:rect(R(x - w), R(y + dy), R(w * 2), 1)
		end
	end
end
local function band(ctx, x: number, y: number, rx: number, ry: number, th: number, c: number) -- 속이 찬 띠(점선이 아니다)
	local pts, N = {}, 40
	for i = 0, N do
		local a = (6.2832 * i) / N
		pts[#pts + 1] = { x + cos(a) * rx, y + sin(a) * ry }
	end
	for i = N, 0, -1 do
		local a = (6.2832 * i) / N
		pts[#pts + 1] = { x + cos(a) * (rx - th), y + sin(a) * max(0.5, ry - th * 0.5) }
	end
	poly(ctx, pts, c)
end

-- 달의 성역: 하늘에서 내리는 달빛 · 바닥의 빛과 도는 별 문양 · 초승달 문장 · 둘레에 솟은 수정과 그 위의 빛기둥 · 둘레를 따라 일렁이는 빛의 장막(뒤쪽 반은 몸 뒤, 앞쪽 반은 몸 앞)
local SANCT = { { 180, "tall", false }, { 0, "tall", true }, { 212, "mid", true }, { 328, "mid", false }, { 245, "small", false }, { 295, "small", true }, { 148, "mid", true }, { 32, "mid", false }, { 115, "small", false }, { 65, "small", true } } -- { 각도, 그림, 뒤집기 } — sin > 0 = 앞
local PILLAR = { { 0, 22, 0.34, 5 }, { 22, 46, 0.2, 5 }, { 46, 74, 0.1, 3 } }
local function drawSanct(ctx, g, front: boolean)
	local x, y = g.s.sanct.x, g.s.sanct.y
	local tone, t, left = g.tone, g.clock, g.left("mn_sanct")
	local age = 20 - left
	local k, RX, RY, img = min(1, age * 2.5, left * 2), 92, 15, g.art.mn_cr
	local function flat(list)
		local out = {}
		for i, p in list do
			out[i] = { p[1], y + (p[2] - y) * (RY / RX) }
		end
		return out
	end
	if not front then
		local sway = sin(t * 0.7) * 6
		ctx:alpha(0.08 * k) -- 하늘에서 내리는 달빛(두 겹)
		poly(ctx, { { x - 30 + sway, y - 180 }, { x + 30 + sway, y - 180 }, { x + RX * 0.86, y }, { x - RX * 0.86, y } }, tone.l)
		ctx:alpha(0.08 * k)
		poly(ctx, { { x - 12 + sway, y - 180 }, { x + 12 + sway, y - 180 }, { x + RX * 0.5, y }, { x - RX * 0.5, y } }, tone.w)
		ctx:alpha(0.2 * k) -- 바닥의 빛(안쪽은 숨 쉬듯 밝아진다)
		ell(ctx, x, y, RX * k, RY * k, tone.l)
		ctx:alpha((0.12 + 0.06 * sin(t * 2.4)) * k)
		ell(ctx, x, y, RX * 0.6 * k, RY * 0.6 * k, tone.w)
		ctx:alpha(0.26 * k) -- 바닥에 누워 도는 별 문양 둘
		poly(ctx, flat(starPts(x, y, RX * 0.8 * k, t * 0.3)), tone.w)
		ctx:alpha(0.24 * k)
		poly(ctx, flat(starPts(x, y, RX * 0.5 * k, -t * 0.45 + 0.39)), tone.l)
		ctx:alpha(0.95 * k)
		band(ctx, x, y, RX * k, RY * k, 2, tone.l)
		ctx:alpha(0.8 * k)
		band(ctx, x, y, (RX - 6) * k, (RY - 1.5) * k, 1, tone.n)
		band(ctx, x, y, RX * 0.56 * k, RY * 0.56 * k, 1.5, tone.l)
		ctx:alpha(0.9 * k) -- 가운데 초승달 문장
		local moon = crescentPts(x - 5 * k, y, 30 * k, 12 * k, 55, 305, 1, 14)
		for _, p in moon do
			p[2] = y + (p[2] - y) * 0.163
		end
		poly(ctx, moon, tone.w)
		ctx:alpha(1)
	end
	local dx = -RX + 1
	while dx < RX do -- 빛의 장막: 둘레를 따라 이어진 한 장이 물결처럼 일렁인다
		local yy = RY * sqrt(1 - (dx * dx) / (RX * RX)) * (if front then 1 else -1)
		local h = R(max(0, 14 + 9 * sin(t * 1.6 + dx * 0.09) + 5 * sin(t * 2.7 - dx * 0.21)) * k)
		local px, py, h1 = R(x + dx), R(y + yy), R(h * 0.45)
		ctx:alpha((if front then 0.2 else 0.3) * k)
		ctx:style(tone.l)
		ctx:rect(px, py - h1, 2, h1)
		ctx:alpha((if front then 0.1 else 0.16) * k)
		ctx:style(tone.n)
		ctx:rect(px, py - h, 2, h - h1)
		ctx:alpha((if front then 0.35 else 0.5) * k)
		ctx:style(tone.w)
		ctx:rect(px, py - h - 1, 2, 1)
		dx += 2
	end
	ctx:alpha(1)
	for i, e in SANCT do
		local deg, name, flip = e[1], e[2], e[3]
		local a = deg * 0.01745
		local sn = sin(a)
		if (sn > 0.01) ~= front then
			continue
		end
		local grow = max(0, min(1, (age - 0.1 - abs(cos(a)) * 0.25) * 5)) * min(1, left * 2)
		if grow <= 0 then
			continue
		end
		local px, py = R(x + cos(a) * RX), R(y + sn * RY) + 1
		local top = py - CR[name][4] + 2
		if name ~= "small" and grow >= 1 then -- 수정 위로 서는 빛기둥(위로 갈수록 옅고 가늘다)
			local fl = 0.75 + 0.25 * sin(t * 3 + (i - 1) * 1.7)
			for _, q in PILLAR do
				ctx:alpha(q[3] * fl * (if front then 0.8 else 1))
				ctx:style(tone.l)
				ctx:rect(px - floor(q[4] / 2), top - q[2], q[4], q[2] - q[1])
			end
			ctx:alpha(0.55 * fl)
			ctx:style(tone.w)
			ctx:rect(px, top - 30, 1, 30)
			ctx:alpha(1)
		end
		crystal(ctx, img, name, px, py, { flip = flip, grow = grow })
	end
end

-- 수정 방벽: 둘레에 솟은 수정 일곱 + 그 위로 닫히는 깎인 면의 수정 돔(면마다 밝기가 다르고, 번갈아 번쩍이며, 반짝임이 훑고 지나간다)
local WALL = { { 150, "tall", false }, { 30, "tall", true }, { 118, "small", false }, { 62, "small", true }, { 205, "mid", true }, { 335, "mid", false }, { 270, "tall", false } }
local WALL_RX, WALL_RY = 50, 46
local FACE = { 0.1, 0.18, 0.12, 0.21, 0.11, 0.17 }
local function drawWall(ctx, g, front: boolean)
	local x, y = g.s.wall.x, g.s.wall.y
	local tone, t, left = g.tone, g.clock, g.left("mn_wall")
	local age, out, img = 8 - left, min(1, left * 3), g.art.mn_cr
	local dk = max(0, min(1, (age - 0.3) * 4)) * out
	if dk > 0 then
		local V = {}
		for i = 0, 6 do
			local a = (PI * i) / 6
			V[i + 1] = { x + cos(a) * WALL_RX, y - sin(a) * WALL_RY * dk }
		end
		local H = { x - 7, y - WALL_RY * 0.42 * dk }
		if not front then
			for i = 0, 5 do -- 깎인 면 여섯
				local flash = floor(t * 5) % 9 == i
				ctx:alpha((if flash then 0.36 else FACE[i + 1]) * dk)
				poly(ctx, { V[i + 1], V[i + 2], H }, if flash then tone.w elseif i % 2 == 1 then tone.l else tone.n)
			end
			ctx:alpha(0.32 * dk) -- 면 사이의 모서리
			for i = 1, 5 do
				line(ctx, V[i + 1][1], V[i + 1][2], H[1], H[2], tone.w)
			end
		else
			local V2 = {}
			for i, p in V do
				V2[i] = { x + (p[1] - x) * 0.95, y + (p[2] - y) * 0.95 }
			end
			ctx:alpha(0.92 * dk) -- 돔의 테두리(굵은 띠)
			for i = 1, 6 do
				poly(ctx, { V[i], V[i + 1], V2[i + 1], V2[i] }, if (i - 1) % 2 == 1 then tone.l else tone.w)
			end
			ctx:alpha(0.07 * dk) -- 안에 있는 것 위로 얇게 덮인 빛
			poly(ctx, V, tone.l)
			local u = (t * 0.7) % 1.7
			if u < 1 then -- 훑고 지나가는 반짝임(돔 안쪽만)
				local gx = x - WALL_RX - 20 + u * (WALL_RX * 2 + 20)
				ctx:alpha(0.45 * dk)
				polyIn(ctx, { { gx, y }, { gx + 6, y }, { gx + 24, y - WALL_RY }, { gx + 18, y - WALL_RY } }, tone.w, V)
				polyIn(ctx, { { gx + 10, y }, { gx + 12, y }, { gx + 30, y - WALL_RY }, { gx + 28, y - WALL_RY } }, tone.w, V)
			end
		end
		ctx:alpha(1)
	end
	for i, e in WALL do
		local a = e[1] * 0.01745
		local sn = sin(a)
		if (sn > 0.01) ~= front then
			continue
		end
		local grow = max(0, min(1, (age - (i - 1) * 0.04) * 6)) * out
		if grow > 0 then
			crystal(ctx, img, e[2], x + cos(a) * (WALL_RX - 4), y + sn * 7 + 1, { flip = e[3], grow = grow })
		end
	end
end

-- 수정 감옥(바인드): 적이 수정 속에 갇힌다 — 뒤쪽 수정 덩이(몸 뒤) → 몸 → 반투명한 앞면과 또렷한 모서리(몸 앞). 풀리기 직전에는 떨리며 금이 가고, 풀리면 깨져 흩어진다
local SPARK = { { -8, -21 }, { 6, -31 }, { 9, -12 }, { -3, -36 } }
local CRACK = { { 3, 6 }, { -2, 5 }, { 4, 6 }, { -1, 6 }, { 3, 7 } }
local function drawPrison(ctx, g, m, sc: number, front: boolean)
	local age = 10 - m.bind
	local grow, x, y, tone = min(1, age * 4), m.x + (if m.bind < 1.2 then R(sin(g.clock * 46)) else 0), m.y - m.h + 2, g.tone
	if not front then
		crystal(ctx, g.art.mn_crb, "prison", x, y, { sc = sc, grow = grow })
		return
	end
	crystal(ctx, g.art.mn_cr, "prison", x, y, { sc = sc, grow = grow, alpha = 0.5 })
	crystal(ctx, g.art.mn_cr and g.art.mn_cr.hi, "prison", x, y, { sc = sc, grow = grow })
	if grow < 1 then
		return
	end
	for i, d in SPARK do -- 반짝임
		if floor(g.clock * 3 + (i - 1) * 1.3) % 4 ~= 0 then
			continue
		end
		local px, py = R(x + d[1] * sc), R(y + d[2] * sc)
		ctx:style(tone.w)
		ctx:rect(px - 2, py, 5, 1)
		ctx:rect(px, py - 2, 1, 5)
	end
	if m.bind < 1.5 then -- 풀리기 직전: 금이 간다
		local px, py = x - 5 * sc, y - 34 * sc
		for _, d in CRACK do
			line(ctx, px, py, px + d[1] * sc, py + d[2] * sc, 0xffffff, sc)
			px += d[1] * sc
			py += d[2] * sc
		end
	end
end

local skills = {
	{ id = "mn_spin", key = "Q", air = true, shot = 0.5, segs = { { clip = "spin", fps = 15, walk = 0.6, ev = { [6] = function(g) -- 한 번 크게 돈다: 몸 둘레의 겹 고리 · 수정 둘레에서도
		g.fx.ring(g.x, g.y - 7, 8, 46, g.tone, { squash = 0.28, back = false, life = 0.28 })
		g.fx.ring(g.x, g.y - 7, 6, 34, g.tone, { squash = 0.28, back = false, life = 0.24, delay = 0.05 })
		g.fx.shards(g.x, g.y - 7, 8, g.tone, { kind = "mix", up = 20 })
		g.hit(-46, 46, 22, 4, 6, { kb = 90, stop = 0.05 })
		reson(g, function(c)
			g.fx.ring(c.x, c.y - 7, 4, 30, g.tone, { squash = 0.28, back = false, life = 0.22 })
			g.hitAt(c.x, c.y, 32, 22, 3, { proc = true })
		end)
	end } } } },
	{ id = "mn_thrust", key = "A", shot = 0.46, segs = { { clip = "thrust", fps = 16, ev = { [6] = function(g) -- 한 번 깊게 찌른다: 앞으로 뻗는 굵은 마름모 빛 · 수정에서도 한 줄
		g.fx.cut(g.fwd(42), g.y - 6, 80, 0, g.tone, { th = 4, life = 0.24 })
		g.fx.streaks(g.fwd(30), g.y - 1, 5, -g.dir, g.tone, { h = 10 })
		g.fx.shards(g.fwd(72), g.y - 6, 6, g.tone, { dir = g.dir, spread = 0.6, kind = "mix" })
		g.hit(4, 80, 16, 4, 7, { kb = 110, stop = 0.06 })
		reson(g, function(c)
			g.fx.cut(c.x + g.dir * 30, c.y - 9, 56, 0, g.tone, { th = 2 })
			g.hitAt(c.x + g.dir * 30, c.y, 30, 18, 3, { proc = true })
		end)
	end } } } },
	{ id = "mn_wave", key = "W", ground = true, shot = 0.75, segs = { { clip = "spin", fps = 16, ev = { [6] = function(g)
		g.fx.slash(g.fwd(4), g.y - 6, g.dir, 30, 100, -10, g.tone, { thick = 7 })
		wave(g, g.fwd(14), g.dir, true)
	end } } } },
	{ id = "mn_smash", key = "S", ground = true, shot = 0.72, segs = { { clip = "smash", fps = 18, ev = { [11] = function(g)
		local x, y, tone, dir = g.fwd(30), g.y, g.tone, g.dir
		g.fx.slash(g.fwd(6), g.y - 4, dir, 46, 120, -10, tone, { thick = 8, life = 0.26 })
		g.fx.ring(x, y, 4, 34, tone)
		g.fx.shards(x, y - 4, 10, tone, { up = 130, kind = "mix" })
		g.hit(0, 56, 48, 4, 10, { lift = 200, stop = 0.08 })
		g.shake(1, 0.1)
		for i = 1, 3 do
			local sx = x + dir * i * 15
			g.fx.spike(sx, y, 11, 26 - i * 5, tone, { delay = i * 0.05, lean = dir * 3 })
			g.after(i * 0.05, function()
				g.hitAt(sx, y, 9, 28, 2, { lift = 140 })
			end)
		end
	end } } } },
	{ id = "mn_plant", key = "Z", shot = 0.8, segs = { { clip = "smash", fps = 20, ev = { [11] = function(g) -- 박는 순간 바닥에서 육각 빛
		g.call("crystal", g.fwd(14), g.y) -- 수정은 서버가 심는다(방의 사람들이 같은 수정을 본다)
		g.fx.hex(g.fwd(14), g.y, 4, 26, g.tone, { squash = 0.35 })
	end } } } },
	buff("mn_tide", "1"),
	-- 달빛 치유: 동작을 6번째 장부터 초당 24장으로 — 회복이 드는 때 0.5초 → 0.17초 · 동작 0.9초 → 0.5초(2026-10-24 사용자 "무니 달빛치유 스킬 선딜 짧게 줄여")
	{ id = "mn_heal", key = "X", shot = 0.75, segs = { { clip = "heal", from = 6, fps = 24, ev = { [10] = function(g) -- 떠오르는 더하기 표시 + 수정마다 작은 고리
		g.fx.rise(g.x, g.y, 12, g.tone, { w = 26 })
		g.fx.ring(g.x, g.y, 4, 30, g.tone)
		for _, c in crystals(g) do
			g.fx.rise(c.x, c.y, 6, g.tone, { w = 18 })
			g.fx.ring(c.x, c.y, 2, 18, g.tone)
		end
		g.heal(1) -- 나와 가까운 파티원의 체력을 되돌린다(세기는 서버가 정한다)
	end } } } },
	{ id = "mn_burst", key = "E", shot = 0.56, segs = { { clip = "spin", fps = 16, ev = { [6] = function(g) -- 수정마다 육각으로 퍼지는 파편 고리. 금 간 수정은 한 번 더 터지면 사라진다
		local cs, tone = crystals(g), g.tone
		if #cs == 0 then
			g.fx.hex(g.x, g.y - 8, 4, 30, tone, { squash = 1, back = false })
			g.hitAt(g.x, g.y, 34, 40, 5, {})
			return
		end
		for _, c in cs do
			g.fx.hex(c.x, c.y - 8, 4, 46, tone, { squash = 1, back = false })
			g.fx.hex(c.x, c.y, 4, 40, tone, { squash = 0.3, delay = 0.05 })
			g.fx.shards(c.x, c.y - 8, 10, tone, { kind = "tri", speed = 130, up = 50 })
			g.hitAt(c.x, c.y, 46, 54, 10, { lift = 160, proc = true })
			if c.cracked then
				c.dead = true
			else
				c.cracked = true
			end
		end
		g.shake(1, 0.1)
	end } } } },
	{ id = "mn_ray", key = "D", shot = 0.52, segs = { { clip = "thrust", fps = 14, ev = { [6] = ray } } } },
	{ id = "mn_guard", key = "C", instant = true, shot = 2.4, cast = function(g) -- 수호령: 떠 있는 수정이 따라다니며 빛을 쏜다. 하나만 둔다 — 다시 쓰면 있던 것을 거두고 새로 깨운다
		local tone = g.tone
		if g.s.guard then
			g.s.guard.dead = true
		end
		g.fx.aura(g.x, g.y, tone, { r = 12, h = 30, rings = false })
		g.fx.hex(g.x - g.dir * 14, g.y - 26, 18, 5, tone, { squash = 1, back = false, life = 0.3 })
		g.s.guard = g.shot({
			x = g.x,
			y = g.y - 30,
			life = 60,
			at = 1,
			summon = "mn_guard",
			update = function(p, dt)
				p.x += (g.x - g.dir * 14 - p.x) * min(1, dt * 3)
				p.y = g.y - 31 + sin(p.t * 3) * 2
				p.at += dt
				if p.at > 2 then
					local m = g.nearest(150, { from = p.x })
					if m then
						p.at = 0
						g.fx.bolt(p.x, p.y, m.x, m.y - m.h - 8, tone, { jag = 2, th = 2 })
						g.fx.pop(m.x, m.y - m.h - 8, tone, { r = 5 })
						g.hurt(m, 4, { proc = true })
					end
				end
			end,
			finish = function(p)
				g.fx.shards(p.x, p.y, 6, tone, { kind = "tri", speed = 60, up = 30 })
			end,
			draw = function(ctx, p) -- Aseprite로 그린 수정 + 둘레를 도는 작은 조각 둘(뒤쪽은 수정 뒤, 앞쪽은 수정 앞)
				local by, grow = R(p.y), min(1, p.t * 5)
				for _, front in { false, true } do
					if front then
						crystal(ctx, g.art.mn_cr, "spirit", p.x, by + 10, { grow = grow })
						if p.at > 1.7 then -- 쏘기 직전에 번쩍
							ctx:style(tone.w)
							ctx:rect(R(p.x) - 3, by, 7, 1)
							ctx:rect(R(p.x), by - 3, 1, 7)
						end
					end
					for i = 0, 1 do
						local a = p.t * 3 + i * 3.1416
						local sn = sin(a)
						if (sn > 0) ~= front then
							continue
						end
						local ox, oy = R(p.x + cos(a) * 9), by + 2 + R(sn * 3)
						poly(ctx, { { ox, oy - 3 }, { ox + 2, oy }, { ox, oy + 3 }, { ox - 2, oy } }, if front then tone.l else tone.d)
					end
				end
			end,
		})
	end },
	buff("mn_bless", "2"),
	{ id = "mn_wall", key = "5", instant = true, shot = 0.9, cast = function(g) -- 수정이 차례로 솟고 돔이 닫힌다
		g.buff("mn_wall")
		g.s.wall = { x = g.x, y = g.y }
		g.fx.hex(g.x, g.y, 6, 50, g.tone, { squash = 0.3 })
		g.fx.aura(g.x, g.y, g.tone, { r = 30, h = 30, rings = false })
		g.shake(1, 0.12)
		for _, e in WALL do
			local a = e[1] * 0.01745
			g.fx.shards(g.x + cos(a) * 46, g.y + sin(a) * 7, 3, g.tone, { kind = "tri", up = 110, speed = 40 })
		end
	end },
	{ id = "mn_arc", key = "R", shot = 0.5, segs = { { clip = "thrust", fps = 16, ev = { [6] = function(g) -- 화면을 가로지르는 긴 검기 + 수정 자리마다 솟는 가시
		local dir = g.dir
		moonLaser(g)
		g.hit(0, 300, 34, 6, 14, { kb = 60 })
		g.shake(1, 0.1)
		for _, c in crystals(g) do
			if (c.x - g.x) * dir > 0 and (c.x - g.x) * dir < 300 then
				for i = -1, 1 do
					g.fx.spike(c.x + i * 12, c.y, 10, 24 - abs(i) * 7, g.tone, { delay = 0.05 + abs(i) * 0.04, lean = i * 3 })
				end
				g.hitAt(c.x, c.y, 24, 38, 5, { lift = 150, proc = true })
			end
		end
	end } } } },
	{ id = "mn_divide", key = "F", ground = true, shot = 0.7, segs = { -- 무거운 2연격: 크게 내려베고, 이어 누르면 크게 휩쓴다
		{ clip = "smash", fps = 18, ev = { [11] = function(g) -- 내려베기: 세로로 큰 초승달 + 앞으로 갈라지는 땅 · 수정에서도 세로 검기
			local tone, x = g.tone, g.fwd(26)
			g.fx.slash(g.fwd(4), g.y - 6, g.dir, 56, 125, -18, tone, { thick = 15, life = 0.3 })
			g.fx.cut(g.fwd(50), g.y - 1, 70, 0, tone, { th = 3, life = 0.4 })
			g.fx.shards(x, g.y - 6, 12, tone, { up = 140, kind = "mix" })
			g.hit(0, 60, 60, 4, 22, { stop = 0.1 })
			g.shake(1, 0.12)
			reson(g, function(c)
				g.fx.cut(c.x, c.y - 20, 44, 90, tone, { th = 3, life = 0.22 })
				g.hitAt(c.x, c.y, 16, 44, 6, { proc = true })
			end)
		end } },
		{ clip = "spin", fps = 15, needPress = true, ev = { [6] = function(g) -- 휩쓸기: 좌우로 뻗는 큰 초승달 둘 · 수정 둘레에 고리
			local tone = g.tone
			g.fx.slash(g.x, g.y - 9, g.dir, 54, -40, 60, tone, { thick = 13, life = 0.28 })
			g.fx.slash(g.x, g.y - 9, -g.dir, 54, -40, 60, tone, { thick = 13, life = 0.28 })
			g.fx.ring(g.x, g.y, 8, 56, tone)
			g.hit(-58, 58, 44, 4, 18, { stop = 0.1, kb = 80 })
			g.shake(1, 0.12)
			reson(g, function(c)
				g.fx.ring(c.x, c.y - 7, 4, 30, tone, { squash = 0.28, back = false, life = 0.22 })
				g.hitAt(c.x, c.y, 32, 24, 5, { proc = true })
			end)
		end } },
	} },
	{ id = "mn_sanct", key = "3", instant = true, shot = 1.2, cast = function(g) -- 달빛이 내리꽂히고, 가운데에서 바깥으로 수정이 차례로 솟는다
		g.buff("mn_sanct")
		g.s.sanct = { x = g.x, y = g.y }
		g.dim(0.4, 0.9)
		g.fx.beam(g.x, g.y, 26, 180, g.tone, { life = 0.5 })
		g.fx.aura(g.x, g.y, g.tone, { r = 40, h = 50, life = 0.7, rings = false })
		g.shake(2, 0.2)
		local sx, sy, tone = g.x, g.y, g.tone
		g.fx.add(0.25, function(ctx, k)
			poly(ctx, starPts(sx, sy - 14, 40 * (1 - k * 0.6), k * 0.8), if k < 0.5 then tone.w else tone.l)
		end)
		for _, e in SANCT do
			local a = e[1] * 0.01745
			local px, py = g.x + cos(a) * 92, g.y + sin(a) * 15
			g.after(0.1 + abs(cos(a)) * 0.25, function()
				g.fx.shards(px, py, 4, tone, { kind = "tri", up = 120, speed = 40 })
			end)
		end
	end },
	{ id = "mn_range", key = "G", shot = 0.75, segs = { { clip = "special", fps = 12, start = function(g)
		g.dim(0.55, 1.6)
		g.fx.rise(g.x, g.y, 14, g.tone, { w = 30 })
	end, ev = { [5] = range, [9] = function(g)
		g.hitAt(g.x, g.y, 62, 50, 4, {})
	end, [12] = function(g)
		g.fx.rise(g.x, g.y, 20, g.tone, { w = 200, life = 1.1 })
	end } } } },
	{ id = "mn_fall", key = "N", shot = 0.6, segs = { { clip = "heal", fps = 18, start = fall } } }, -- 달빛 낙하: 판정은 쓰는 순간 한 번(위 fall)
	{ id = "mn_prison", key = "B", shot = 1.2, segs = { { clip = "heal", fps = 20, ev = { [10] = function(g) -- 적을 수정 속에 가둔다: 육각 테가 조여 들고 → 발밑에서 수정이 솟아 몸을 삼키고 → 다 닫히면 별빛이 튄다
		local tone = g.tone
		g.shake(3, 0.15)
		for _, m in g.mobs() do
			if abs(m.x - g.x) < 150 and abs(m.y - g.y) < 40 and g.bind(m, 10, "crystal") then
				m.prison = true
				local sc, my = if m.boss then 2 else 1, m.y - m.h
				g.fx.hex(m.x, my - 14 * sc, 36 * sc, 12 * sc, tone, { squash = 1, back = false, life = 0.25 })
				for _, sd in { -1, 1 } do
					for i = 1, 2 do
						g.fx.spike(m.x + sd * (10 + i * 7) * sc, my, 8 * sc, (18 - i * 5) * sc, tone, { delay = 0.04 * i, life = 0.55, lean = sd * 3 })
					end
				end
				g.after(0.25, function()
					g.fx.add(0.18, function(ctx, k)
						poly(ctx, starPts(m.x, my - 24 * sc, 18 * sc * (1 - k * 0.7), k), tone.w)
					end)
					g.fx.shards(m.x, my - 18 * sc, 10, tone, { kind = "tri", speed = 80, up = 60 })
				end)
			end
		end
	end } } } },
	{ id = "mn_revive", key = "V", shot = 0.7, segs = { { clip = "heal", fps = 20, ev = { [10] = function(g) -- 쓰러진 자리에 내려오는 빛기둥
		g.fx.beam(g.fwd(30), g.y, 14, 130, g.tone, { life = 0.6 })
		g.fx.rise(g.fwd(30), g.y, 14, g.tone, { w = 20, life = 1.1 })
		g.fx.ring(g.fwd(30), g.y, 4, 24, g.tone)
		g.revive()
	end } } } },
	{ id = "mn_shard", key = "T" }, -- 사출기: 켜고 끈다(판정은 아래 onHit)
	dash("mn_dash", "run", 7, 170, 51),
}
for _, s in Common.commons do
	table.insert(skills, s)
end

local mooni = {
	tone = "mint",
	toggle = "mn_shard",
	icons = { c_hero = "moon", mn_shard = "crystal", mn_tide = "haste", mn_bless = "up", mn_wall = "shield", mn_sanct = "disc" },
	init = function(g)
		g.s = { cr = {}, n = 0, growAt = -9, shardAt = -9, ray = nil, rayAt = -9, wall = nil, sanct = nil, riseT = 0, guard = nil }
	end,
	haste = function(g)
		return if g.has("mn_tide") then 1.25 else 1
	end,
	mult = function(g)
		return 1 + (if g.has("mn_sanct") and g.s.sanct and abs(g.s.sanct.x - g.x) < 96 then 0.3 else 0) + (if g.has("mn_bless") then 0.05 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or o.proc then
			return
		end
		-- 맞은 자리에 수정이 맺힌다(수정 공명을 배웠을 때)
		if g.sk("mn_reson") > 0 and g.clock - g.s.growAt > 0.4 and g.rnd() < (if g.sk("mn_grove") > 0 then 0.5 else 0.3) then
			g.s.growAt = g.clock
			g.call("crystal", m.x + (g.rnd() - 0.5) * 12, m.y)
		end
		g.s.n += 1
		if g.sk("mn_edge") > 0 and g.s.n % 5 == 0 then
			g.call("edge", m) -- 달빛 칼날: 다섯 번째 타마다 한 번 더 번진다
		end
		if g.toggle and g.clock - g.s.shardAt > (if g.sk("mn_shard4") > 0 then 1 else 1.5) then
			g.s.shardAt = g.clock
			shards(g, m)
		end
	end,
	tick = function(g, dt)
		if g.has("mn_sanct") and g.s.sanct then -- 떠오르는 빛 · 내려앉는 빛 조각
			g.s.riseT += dt
			if g.s.riseT > 0.08 then
				g.s.riseT = 0
				local sx = g.s.sanct.x + (g.rnd() - 0.5) * 170
				g.fx.rise(sx, g.s.sanct.y, 1, g.tone, { w = 4, life = 1.2 })
				if g.rnd() < 0.3 then
					g.fx.shards(sx, g.s.sanct.y - 70 - g.rnd() * 40, 1, g.tone, { kind = "petal", speed = 10, up = -10, grav = 30, life = 1.4 })
				end
			end
		end
		for _, m in g.mobs() do -- 수정 감옥이 풀리면 깨져 흩어진다
			if m.prison and m.bind <= 0 then
				m.prison = false
				local sc, y, tone = if m.boss then 2 else 1, m.y - m.h, g.tone
				local mx = m.x
				g.fx.shards(mx, y - 18 * sc, 18, tone, { kind = "tri", speed = 130, up = 50 })
				g.fx.shards(mx, y - 8 * sc, 8, tone, { kind = "mix", speed = 80, up = 90 })
				g.fx.add(0.16, function(ctx, k)
					poly(ctx, starPts(mx, y - 18 * sc, 18 * sc * (1 - k * 0.7), k), tone.w)
				end)
			end
		end
	end,
	onBuffEnd = function(g, id) -- 방벽이 풀리면 돔이 깨져 흩어진다
		if id == "mn_wall" and g.s.wall then
			local x, y = g.s.wall.x, g.s.wall.y
			for i = 0, 6 do
				local a = (PI * i) / 6
				g.fx.shards(x + cos(a) * WALL_RX, y - sin(a) * WALL_RY, 4, g.tone, { kind = "tri", speed = 70, up = 20 })
			end
		end
	end,
	drawBack = function(ctx, g)
		if g.has("mn_sanct") and g.s.sanct then
			drawSanct(ctx, g, false)
		end
		if g.has("mn_wall") and g.s.wall then
			drawWall(ctx, g, false)
		end
	end,
	draw = function(ctx, g)
		drawRay(ctx, g)
		if g.has("mn_sanct") and g.s.sanct then
			drawSanct(ctx, g, true)
		end
		if g.has("mn_wall") and g.s.wall then
			drawWall(ctx, g, true)
		end
	end,
	drawBind = drawPrison,
	-- 서버가 정해 화면에 알리는 것(g.call)
	calls = {
		crystal = function(g, x, y)
			addCrystal(g, x, y)
		end,
		edge = function(g, m)
			g.fx.ring(m.x, m.y - m.h - 8, 4, 26, g.tone, { squash = 0.6, back = false, life = 0.25 })
			g.hitAt(m.x, m.y, 26, 28, 3, { proc = true })
		end,
		shard = shard,
	},
	-- 지금의 서버(1차 — sim/kit.luau)가 알리는 것. o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것) }
	procs = {
		-- o.i = 몇째 조각(쌍조각의 둘째는 조금 늦게 떠난다)
		shard = function(g, m, o)
			if (o.i or 0) > 0 then
				g.after(0.09 * o.i, function()
					shard(g, o.sx, o.sy, m, o)
				end)
			else
				shard(g, o.sx, o.sy, m, o)
			end
		end,
		reson = function(_g, _m, o) -- 수정에서 같이 나가는 타: 그림은 기술 쪽(reson)이 수정마다 그린다
			o.land()
		end,
		-- 서버의 달 수정이 섰다 · 사라졌다. c = { id, x, y }
		crystalAdd = function(g, c)
			local p = addCrystal(g, c.x, c.y, 20, true)
			if p then
				p.id = c.id
			end
		end,
		crystalGone = function(g, id)
			for _, c in g.s.cr do
				if c.id == id then
					c.dead = true
				end
			end
		end,
	},
	skills = skills,
}

return mooni
