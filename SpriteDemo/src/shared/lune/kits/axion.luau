-- 리틀 액시온 — 큰 도끼. 핵심 장치: 힘 모으기(강타 키를 누르고 있으면 단계가 오른다 · 만월이면 모으지 않아도 가득).
--  공방 시험 탭의 dino-workshop/js/lune/kits/axion.js를 줄마다 옮긴 것(동작 · 이펙트 · 판정의 자리와 때). 시험판은 4차까지 다 배운 모습이라,
--  스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로): 메아리 도끼 하나(1차) → 둘(겹 메아리) → 떨어진 자리에 충격파(울리는 메아리) → 두 번째 타마다 · 더 크게(달 그림자 도끼),
--  힘 모으기 2단계(1차) → 3단계(깊은 호흡), 끝까지 모은 강타의 충격파(충격파).
--  시험판의 피해 값(3 · 6 · 12 …)은 그대로 적어 둔다 — 게임에서는 "몫"으로만 쓴다(수치는 design/combat.js와 서버가 정한다).
--  옮기며 바뀐 이름: end → finish · until → till(Luau의 예약어).
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local crescentPts, starPts, poly, drawAxe = Fx.crescentPts, Fx.starPts, Fx.poly, Fx.drawAxe
local dash, buff = Common.dash, Common.buff
local floor, sin, cos, min, max, abs, sqrt = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.sqrt

-- 메아리 도끼(사출기 — 1차에 배우고 2~4차 패시브가 강화한다): 달빛 도끼가 떨어지고, (울리는 메아리부터) 떨어진 자리에 작은 충격파가 번진다
--  o.land = 떨어진 순간에 부를 것(화면이 그 타의 피해 숫자를 이때 띄운다)
local function dropAxe(g, m, i: number, o)
	local size = if g.sk("ax_echo4") > 0 then 13 else 10
	g.after(i * 0.12, function()
		if m.dead >= 0 then
			return
		end
		g.shot({
			x = m.x + (if i ~= 0 then 7 else -3),
			y = m.y - m.h - 50,
			vy = 290,
			life = 0.16,
			ghost = true,
			draw = function(ctx, p)
				drawAxe(ctx, p.x, p.y, size, g.tone, 0.85)
			end,
			finish = function(p)
				g.hurt(m, 5, { proc = true })
				g.fx.pop(p.x, p.y + 4, g.tone)
				if g.sk("ax_echo3") > 0 then
					g.fx.ring(m.x, m.y, 2, 16, g.tone, { life = 0.22 })
					g.hitAt(m.x, m.y, 16, 20, 2, { proc = true })
				end
				if o and o.land then
					o.land()
				end
			end,
		})
	end)
end

-- 대지 강타: 모은 단계만큼 넓어진다. 끝까지 모으면 충격파(패시브)가 땅을 따라 한 번 더
local function slam(g)
	local lv, x, y, tone = g.lv, g.fwd(20 * g.big), g.y, g.tone
	local n = 3 + lv * 2
	g.fx.ring(x, y, 6, 44 + lv * 12, tone)
	g.fx.ring(x, y, 4, 28, tone, { delay = 0.08 })
	g.fx.shards(x, y - 4, 10 + lv * 4, tone, { up = 150, kind = "mix", speed = 120 })
	g.hit(-12, 48 + lv * 10, 44, 4, 5 + lv * 3, { lift = 210, stop = 0.06 })
	if lv >= 2 then
		g.shake(1, 0.12) -- 모아 쳤을 때만 아주 약하게
	end
	for i = 1, n do
		for _, s in { -1, 1 } do
			local sx = x + s * (10 + i * 15)
			g.fx.spike(sx, y, 12, max(8, 30 - i * 3), tone, { delay = i * 0.05, lean = s * 4 })
			g.after(i * 0.05, function()
				g.hitAt(sx, y, 9, 30, 2, { lift = 150 })
			end)
		end
	end
	if lv >= 3 and g.sk("ax_shock") > 0 then
		for i = 1, 6 do
			for _, s in { -1, 1 } do
				g.after(0.3 + i * 0.05, function()
					local sx = x + s * (n * 15 + i * 24)
					g.fx.ring(sx, y, 2, 13, tone, { life = 0.2 })
					g.hitAt(sx, y, 12, 20, 3, { lift = 110 })
				end)
			end
		end
	end
end

local function pillars(g)
	local x0, y, dir, tone = g.fwd(20), g.y, g.dir, g.tone
	g.invert(0.08)
	g.shake(7, 0.4)
	g.hit(-12, 48, 44, 4, 6, { lift = 200 })
	g.fx.shards(x0, y - 4, 16, tone, { up = 170, kind = "mix", speed = 140 })
	for i = 0, 5 do
		g.after(0.06 + i * 0.09, function()
			local x = x0 + dir * (14 + i * 30)
			g.fx.beam(x, y, 20, 230, tone)
			g.fx.ring(x, y, 4, 28, tone)
			g.fx.shards(x, y - 6, 7, tone, { up = 150, kind = "mix" })
			g.hitAt(x, y, 15, 230, 8, { lift = 250 })
			g.shake(4, 0.12)
		end)
	end
end

-- 달빛 파동(사냥용 광역기 — 화면 대부분, 위 · 아래층까지 닿고 피해는 약하다)
--   찍는 순간: 도끼 끝의 별빛 + 양옆으로 피어오르는 큰 초승달 한 쌍 + 화면이 잠깐 어두워진다
--   퍼짐: 초승달 일곱이 사방으로 층을 뚫고 날아간다(커지며 얇아지고, 뒤에 잔상 둘) → 지나간 자리에 달가루가 내려앉는다
--   맞음: 초승달이 닿는 때에 맞춰 적마다 초승달 한 쌍이 맞물리고 별빛이 튄다
local PULSE = { x = 180, up = 140, down = 80, life = 0.48, dirs = { 12, 38, 64, 90, 116, 142, 168 } }
local PULSE_GHOST = { { 0.17, 0.2 }, { 0.085, 0.42 } }
local DUST = { n = 0x2f3742, l = 0x56657a }
local function pulse(g)
	local x, y, tone = g.x, g.y, g.tone
	local cy, RX, RY, ax = y - 10, PULSE.x, PULSE.up - 12, g.fwd(16)
	local function ease(k)
		return 1 - (1 - k) * (1 - k)
	end
	g.dim(0.42, 0.55)
	g.shake(2, 0.15)
	g.fx.add(0.2, function(ctx, k)
		poly(ctx, starPts(ax, y - 5, 34 * (1 - k * 0.75), k * 0.7), if k < 0.45 then tone.w else tone.l)
		if k < 0.5 then
			poly(ctx, starPts(ax, y - 5, 15 * (1 - k), 0.39 + k), tone.w)
		end
	end)
	for _, d in { -1, 1 } do
		g.fx.slash(x, y - 2, d, 44, -8, 104, tone, { thick = 14, life = 0.32 })
		g.fx.slash(x, y - 2, d, 26, 0, 96, tone, { thick = 8, life = 0.24 })
	end
	g.fx.shards(ax, y - 4, 14, tone, { up = 170, kind = "tri", speed = 120 })
	g.fx.shards(ax, y - 1, 8, DUST, { kind = "dot", up = 100, speed = 80 })
	local function at(deg, e)
		local a = deg * 0.01745
		return x + cos(a) * RX * e, cy - sin(a) * RY * e, math.atan2(sin(a) * RY, cos(a) * RX) / 0.01745
	end
	local function moon(ctx, deg, e, k, c, core)
		local px, py, phi = at(deg, e)
		local r = 11 + 25 * e
		local ccx, ccy = px - cos(phi * 0.01745) * r, py + sin(phi * 0.01745) * r
		poly(ctx, crescentPts(ccx, ccy, r, r * (0.62 - k * 0.32), phi - 62, phi + 62, 1, 8), c)
		if core then
			poly(ctx, crescentPts(ccx, ccy, r, r * 0.2, phi - 46, phi + 46, 1, 8), core)
		end
	end
	g.fx.add(PULSE.life, function(ctx, k)
		local e, fade = ease(k), if k > 0.78 then (1 - k) / 0.22 else 1
		for _, deg in PULSE.dirs do
			for _, b in PULSE_GHOST do -- 잔상 둘
				if e > b[1] + 0.05 then
					ctx:alpha(b[2] * fade)
					moon(ctx, deg, e - b[1], k, tone.n, nil)
				end
			end
			ctx:alpha(fade)
			moon(ctx, deg, e, k, if k < 0.72 then tone.l else tone.n, if k < 0.62 then tone.w else nil)
		end
		ctx:alpha(1)
	end)
	for _, deg in PULSE.dirs do -- 달가루 · 세모 파편
		for _, e in { 0.3, 0.55, 0.8, 0.97 } do
			local px, py = at(deg, e)
			g.after(PULSE.life * (1 - sqrt(1 - e)) + 0.03, function()
				g.fx.rise(px, py, 2, tone, { w = 26, speed = -16, life = 0.9 })
				if e > 0.5 then
					g.fx.shards(px, py, 1, tone, { kind = "tri", speed = 30, up = 20, life = 0.5 })
				end
			end)
		end
	end
	for _, m in g.mobs() do
		local dx, dy = m.x - x, m.y - m.h - y
		if abs(dx) > RX or dy < -PULSE.up or dy > PULSE.down then
			continue -- 층을 가리지 않는다: 범위 안이면 위층 · 아래층도 맞는다
		end
		local u = min(1, sqrt((dx / RX) ^ 2 + ((dy + 10) / RY) ^ 2))
		g.after(PULSE.life * (1 - sqrt(1 - u)), function()
			if m.dead >= 0 then
				return
			end
			local mx, my, sc = m.x, m.y - m.h - (if m.boss then 20 else 8), if m.boss then 1.6 else 1
			for _, d in { -1, 1 } do
				g.fx.slash(mx, my, d, 13 * sc, -62, 72, tone, { thick = 5 * sc, life = 0.24 }) -- 맞물리는 초승달 한 쌍
			end
			g.fx.add(0.16, function(ctx, k)
				poly(ctx, starPts(mx, my, 10 * sc * (1 - k * 0.6), 0.39), if k < 0.5 then tone.w else tone.l)
			end)
			g.hurt(m, 3, { lift = 70 })
		end)
	end
end

-- 만월: 달을 그리지 않고 기운이 몸을 감돈다 — 뒤에서 일렁이며 오르는 불꽃 모양의 기운 세 겹 + 몸을 따라 오르는 빛 가닥(윤곽 빛은 heroGlow). 발밑에 점으로 테를 그리지 않는다
local AURA_A, AURA_W = { 0.36, 0.5, 0.45 }, { 1, 0.62, 0.26 }
local function drawAura(ctx, x: number, y: number, sc: number, tone, t: number, k: number)
	local H, W = 46 * sc * k, 18 * sc
	local colors = { tone.n, tone.l, tone.w }
	for layer = 0, 2 do -- 바깥(네온) · 가운데(밝음) · 속(흰빛) 세 겹
		ctx:alpha(AURA_A[layer + 1])
		ctx:style(colors[layer + 1])
		local dy = 0
		while dy < H do
			local u = dy / H
			local base = W * AURA_W[layer + 1] * (1 - u) ^ 0.75 * (0.5 + 0.5 * sin(min(1, u * 3.2) * 1.5708))
			local sway = (sin(t * 8 + dy * 0.42 + layer * 1.7) * 2.4 + sin(t * 5.1 - dy * 0.27) * 1.6) * u * sc
			local w = base + sin(t * 13 + dy * 0.9 + layer) * 1.3 * u * sc
			if w >= 0.6 then
				ctx:rect(floor(x + sway - w + 0.5), floor(y - dy + 0.5), floor(w * 2 + 0.5), 1)
			end
			dy += 1
		end
	end
	ctx:alpha(1)
	for i = 0, 7 do
		local u = (t * 0.85 + i / 8) % 1
		local px, py, l = x + sin(i * 2.4 + t * 1.4) * W * 0.85 * (1 - u * 0.55), y - u * H * 0.96, floor(5 * (1 - u) * sc + 0.5) + 1
		ctx:style(if u < 0.45 then tone.w else tone.l)
		ctx:rect(floor(px + 0.5), floor(py - l + 0.5), 1, l)
	end
end

-- 처단의 균열: 적 둘레를 도는 빛 조각이 칠 때마다 하나씩 늘어난다(다섯이 차면 모여서 터진다). 뒤로 도는 조각은 몸 뒤, 앞으로 도는 조각은 몸 앞
local function stackShards(ctx, g, n: number, cx: number, cy: number, rx: number, ry: number, k: number, front: boolean)
	local tone = g.tone
	for i = 0, n - 1 do
		local a = g.clock * 2.4 + i * 1.2566
		local sn = sin(a)
		if (sn > 0) ~= front then
			continue
		end
		local x, y = floor(cx + cos(a) * rx + 0.5), floor(cy + sn * ry + 0.5)
		local h, w = (if front then 6 else 4.5) * k, (if front then 3 else 2.5) * k
		poly(ctx, { { x, y - h }, { x + w, y }, { x, y + h }, { x - w, y } }, if front then tone.n else tone.d)
		poly(ctx, { { x, y - h + 1 }, { x + w - 1.2, y }, { x, y + h - 2 }, { x - w + 1.2, y } }, if front then tone.l else tone.n)
		ctx:style(tone.w)
		ctx:rect(x - 1, floor(y - h * 0.5 + 0.5), 1, floor(h * 0.8 + 0.5))
		if front and floor(g.clock * 6 + i) % 4 == 0 then
			ctx:rect(x - 2, y - floor(h + 0.5) - 2, 5, 1)
			ctx:rect(x, y - floor(h + 0.5) - 4, 1, 5)
		end
	end
end
local function drawStacks(ctx, g, m, sc: number, front: boolean)
	local n = m.cracks
	if not n or n == 0 then
		return
	end
	local cx, cy, rx, ry, k = m.x, m.y - m.h - 8 * sc, 14 * sc, 4.5 * sc, if sc > 1 then 1.5 else 1
	stackShards(ctx, g, n, cx, cy, rx, ry, k, front) -- 빛 조각만 돈다(궤도는 그리지 않는다)
end

local OUTLINE = { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

local skills = {
	{ id = "ax_slam", key = "Q", ground = true, shot = 1.15, holdFor = 0.9, segs = { { clip = "smash", from = 0, to = 3, loopFrom = 2, fps = 16, charge = true }, { clip = "smash", from = 4, fps = 18, ev = { [7] = slam } } } },
	{
		id = "ax_combo",
		key = "A",
		shot = 0.86,
		segs = { -- 이어 누르면 3단. 제자리에서 벤다(앞으로 나가지 않는다) · 화면을 흔들지 않는다
			{ clip = "atk3", from = 0, to = 7, fps = 20, ev = { [3] = function(g)
				g.fx.slash(g.fwd(6), g.y - 9, g.dir, 30 * g.big, -30, 60, g.tone, { thick = 6 })
				g.hit(-4, 44, 26, 4, 3, { kb = 50 })
			end } },
			{ clip = "atk3", from = 8, to = 12, fps = 20, needPress = true, ev = { [9] = function(g)
				g.fx.slash(g.fwd(6), g.y - 9, g.dir, 32 * g.big, 70, -30, g.tone, { thick = 6 })
				g.hit(-4, 46, 26, 4, 3, { kb = 70 })
			end } },
			{ clip = "atk3", from = 13, to = 22, fps = 18, needPress = true, ev = { [15] = function(g)
				g.fx.slash(g.fwd(4), g.y - 6, g.dir, 40 * g.big, -40, 150, g.tone, { thick = 9, life = 0.3 })
				g.fx.shards(g.fwd(26), g.y - 14, 10, g.tone, { up = 110, kind = "mix" })
				g.hit(-8, 50, 46, 4, 6, { lift = 230, kb = 40, stop = 0.06 })
			end } },
		},
	},
	{
		id = "ax_crescent",
		key = "W",
		shot = 0.95,
		holdFor = 0.6,
		segs = {
			{ clip = "atk1", from = 0, to = 2, loopFrom = 1, fps = 14, charge = true },
			{ clip = "atk1", from = 3, fps = 16, ev = { [3] = function(g)
				local dir, tone, lv = g.dir, g.tone, g.lv
				local r = 15 + lv * 3
				g.fx.streaks(g.fwd(20), g.y - 2, 6, -dir, tone, { w = 30 })
				for _, a in if lv >= 3 then { -0.4, 0, 0.4 } else { 0 } do
					g.shot({
						x = g.fwd(16),
						y = g.y - 11,
						vx = dir * 230,
						vy = a * 150,
						life = 0.75,
						w = 14,
						h = 30 + lv * 6,
						dmg = 4 + lv * 2,
						o = { kb = 60 },
						ghost = a ~= 0,
						every = { 0.04, function(p)
							g.fx.shards(p.x - dir * 6, p.y + (g.rnd() - 0.5) * 18, 1, tone, { speed = 30, up = 10, life = 0.35 })
						end },
						draw = function(ctx, p)
							poly(ctx, crescentPts(p.x - dir * 8, p.y, r, r * 0.55, -75, 75, dir), if p.t / p.life > 0.8 then tone.n else tone.l)
							poly(ctx, crescentPts(p.x - dir * 8, p.y, r, r * 0.2, -55, 55, dir), tone.w)
						end,
						finish = function(p)
							g.fx.shards(p.x, p.y, 8, tone, { kind = "mix" })
						end,
					})
				end
			end } },
		},
	},
}

-- 쪼개기: 세로로 두 번 쪼갠다 — 맞은 적에게 "갈라짐"
do
	local segs = {}
	for i = 0, 1 do
		segs[i + 1] = { clip = "atk3", from = 8, to = 12, fps = 20, ev = { [9] = function(g)
			local x = g.fwd(22 + i * 5)
			g.fx.cut(x, g.y - 14, 46, 84 - i * 10, g.tone, { th = 4, life = 0.25 })
			if i ~= 0 then
				g.fx.shards(x, g.y - 10, 8, g.tone, { kind = "bar", up = 20, speed = 110 })
			end
			for _, m in g.hit(0, 46, 44, 4, 6 + i * 2, { stop = 0.04 }) do
				m.rend = 5
			end
		end } }
	end
	table.insert(skills, { id = "ax_rend", key = "S", shot = 0.62, segs = segs })
end

local more = {
	buff("ax_breath", "1"),
	{
		id = "ax_whirl",
		key = "E",
		ground = true,
		shot = 0.85,
		holdFor = 2,
		segs = {
			{
				clip = "atk3",
				from = 3,
				to = 12,
				fps = 28,
				hold = true,
				max = 3,
				min = 0.3,
				walk = 0.6,
				turn = true,
				start = function(g)
					g.s.w = 1
				end,
				finish = function(g)
					g.s.spun = g.held
				end,
				every = { 0.16, function(g)
					g.s.w = -g.s.w
					g.fx.slash(g.x, g.y - 9, g.s.w, 32 * g.big, -30, 70, g.tone, { thick = 6, life = 0.2 })
					g.hit(-40, 40, 28, 4, 2, {})
				end },
			},
			{ clip = "smash", from = 3, fps = 20, ev = { [7] = function(g)
				local k = min(3, g.s.spun or 0)
				g.fx.ring(g.x, g.y, 8, 50 + k * 14, g.tone)
				g.fx.ring(g.x, g.y, 4, 30, g.tone, { delay = 0.06 })
				g.fx.shards(g.x, g.y - 6, 12 + k * 4, g.tone, { kind = "mix", up = 120 })
				g.hit(-52 - k * 8, 52 + k * 8, 40, 4, 5 + k * 4, { lift = 220 })
				g.shake(1, 0.1)
			end } },
		},
	},
	{
		id = "ax_leap",
		key = "D",
		air = true,
		shot = 0.95,
		segs = { -- 뛰어오르는 동작 · 떨어지는 동작은 팩의 것을 그대로 쓰고, 땅에 닿은 뒤에만 내려찍는 장을 쓴다
			{
				clip = "jump",
				fps = 12,
				loopFrom = 3,
				till = function(g)
					return g.hero.vy >= 0
				end,
				max = 0.8,
				start = function(g)
					if g.ground then
						g.hop(250)
					end
					g.move(85, 0.5)
					g.s.top = g.y
				end,
			},
			{
				clip = "fall",
				fps = 12,
				till = function(g)
					return g.ground
				end,
				max = 1.4,
				every = { 0.03, function(g)
					g.s.top = min(g.s.top, g.y)
				end },
			},
			{ clip = "smash", from = 7, fps = 18, ev = { [7] = function(g) -- 떨어진 높이만큼 세다: 세로 줄 + 사방으로 가는 금
				local fall, x, y = g.y - g.s.top, g.fwd(18), g.y
				g.fx.cut(x, y - 44, 86, 90, g.tone, { th = 3, life = 0.2 })
				for _, c in { { 8, 46 }, { 172, 46 }, { 24, 30 }, { 156, 30 }, { 40, 18 }, { 140, 18 } } do
					local a, l = c[1], c[2]
					g.fx.cut(x + cos(a * 0.01745) * l * 0.5, y - 1 - sin(a * 0.01745) * l * 0.2, l, a, g.tone, { th = 2, life = 0.35, delay = 0.03 })
				end
				g.fx.ring(x, y, 3, 20, g.tone, { life = 0.2 })
				g.hit(-42, 42, 46, 4, floor(12 + fall * 0.15 + 0.5), { stop = 0.08 }) -- 등 뒤 42도트까지 친다 — 뛰어넘은 적(붙어 있던 적)도 맞는다(사용자 2026-10-08: "등뒤도 타격범위가있게")
				g.shake(1, 0.1)
			end } },
		},
	},
	{ id = "ax_pulse", key = "Z", shot = 0.56, segs = { { clip = "smash", fps = 18, start = function(g) -- 사냥용 광역기: 위 · 아래층까지 넓게, 약하게
		g.fx.rise(g.x, g.y, 10, g.tone, { w = 36 })
	end, ev = { [7] = pulse } } } },
	buff("ax_roar", "2", function(g)
		for i = 0, 2 do
			g.fx.slash(g.fwd(4), g.y - 12, g.dir, 12 + i * 10, -45, 45, g.tone, { thick = 3, life = 0.3 + i * 0.08 })
		end
	end),
	{ id = "ax_brace", key = "5", instant = true, shot = 0.5, cast = function(g) -- 발을 땅에 박고 몸이 굳는다
		g.buff("ax_brace")
		for _, s in { -1, 1 } do
			g.fx.cut(g.x + s * 9, g.y - 1, 14, if s > 0 then 8 else 172, g.tone, { th = 2, life = 0.4 })
			g.fx.shards(g.x + s * 6, g.y - 1, 4, g.tone, { kind = "dot", dir = s, spread = 0.5, speed = 60, up = 30, life = 0.4 })
		end
	end },
	{ id = "ax_moonfall", key = "R", shot = 0.36, segs = { { clip = "atk3", from = 13, to = 22, fps = 18, ev = { [15] = function(g) -- 화면 높이의 초승달이 앞으로 쓸고 간다
		local dir, tone = g.dir, g.tone
		g.shot({
			x = g.fwd(10),
			y = g.y - 40,
			vx = dir * 300,
			life = 0.5,
			w = 26,
			h = 116,
			dmg = 14,
			ghost = true,
			o = { kb = 80, lift = 150 },
			every = { 0.03, function(p)
				g.fx.shards(p.x - dir * 10, p.y + (g.rnd() - 0.5) * 90, 1, tone, { speed = 20, up = 0, life = 0.4, kind = "bar" })
			end },
			draw = function(ctx, p)
				poly(ctx, crescentPts(p.x - dir * 44, p.y, 60, 24, -72, 72, dir, 9), tone.l)
				poly(ctx, crescentPts(p.x - dir * 44, p.y, 60, 9, -60, 60, dir, 9), tone.w)
			end,
		})
	end } } } },
	{ id = "ax_execute", key = "F", ground = true, shot = 0.62, segs = { { clip = "smash", from = 2, fps = 26, ev = { [7] = function(g) -- 칠 때마다 적 둘레를 도는 빛 조각이 하나씩 늘다가 다섯째에 모여서 터진다
		local x = g.fwd(20)
		g.fx.cut(x, g.y - 16, 34, 90, g.tone, { th = 3, life = 0.16 })
		g.fx.ring(x, g.y, 3, 18, g.tone, { life = 0.2 })
		for _, m in g.hit(0, 42, 44, 4, 12, { stop = 0.04 }) do
			local sc = if m.boss then 2 else 1
			local cy = m.y - m.h - 8 * sc
			m.cracks += 1
			if m.cracks < 5 then
				g.fx.pop(m.x + 13 * sc * cos(g.clock * 2.4 + (m.cracks - 1) * 1.2566), cy, g.tone, { r = 4 })
				continue
			end
			m.cracks = 0
			g.fx.shards(m.x, cy, 10, g.tone, { kind = "tri", up = 0, speed = 30, life = 0.12 }) -- 돌던 조각이 흩어지며 터진다
			g.after(0.1, function()
				g.fx.beam(m.x, m.y, 12, 76, g.tone, { life = 0.3 })
				g.fx.shards(m.x, cy, 16, g.tone, { kind = "tri", up = 110, speed = 120 })
				g.hurt(m, 40, {})
				g.shake(1, 0.12)
			end)
		end
	end } } } },
	{ id = "ax_fullmoon", key = "3", instant = true, shot = 0.8, cast = function(g) -- 둘레의 기운이 몸으로 모여들었다가 솟구친다
		g.buff("ax_fullmoon")
		g.fx.aura(g.x, g.y, g.tone, { r = 22, h = 44, rings = false })
		g.fx.shards(g.x, g.y - 10, 14, g.tone, { kind = "dot", up = 110, speed = 50, grav = -40, life = 0.7 })
		g.shake(2, 0.2)
	end },
	{ id = "ax_titan", key = "4", instant = true, shot = 0.4, cast = function(g)
		g.buff("ax_titan")
		g.shake(4, 0.3)
		g.fx.ring(g.x, g.y, 6, 50, g.tone)
		g.fx.aura(g.x, g.y, g.tone, { r = 24, h = 46 })
		for _, a in { 10, 170, 30, 150 } do
			g.fx.cut(g.x + cos(a * 0.01745) * 20, g.y - 1, 40, a, g.tone, { th = 2, life = 0.4 })
		end
	end },
	{ id = "ax_pillars", key = "G", shot = 1.0, segs = { { clip = "smash", fps = 11, start = function(g)
		g.dim(0.5, 1.5)
		g.fx.ring(g.x, g.y, 46, 4, g.tone, { life = 0.5 })
		g.fx.rise(g.x, g.y, 12, g.tone)
	end, ev = { [7] = pillars } } } },
	{ id = "ax_quake", key = "X", shot = 0.75, segs = { { clip = "smash", fps = 16, ev = { [7] = function(g) -- 땅을 따라 번지는 톱니 물결 — 보통 적을 넘어뜨린다
		local x, y, dir = g.fwd(14), g.y, g.dir
		g.shake(2, 0.2)
		for i = 1, 10 do
			g.after(i * 0.035, function()
				local sx = x + dir * i * 15
				g.fx.spike(sx, y, 11, 7 + (i % 2) * 6, g.tone, { life = 0.25, lean = dir * 3 })
				g.hitAt(sx, y, 10, 24, 2, { stun = 1.5 })
			end)
		end
	end } } } },
	{ id = "ax_echo", key = "T" }, -- 사출기: 켜고 끈다(판정은 아래 onHit)
	dash("ax_dash", "dash", 11, 200, 100),
}
for _, s in more do
	table.insert(skills, s)
end
for _, s in Common.commons do
	table.insert(skills, s)
end

local axion = {
	tone = "mint",
	toggle = "ax_echo",
	icons = { c_hero = "moon", ax_echo = "axe", ax_breath = "haste", ax_roar = "up", ax_brace = "shield", ax_fullmoon = "disc", ax_titan = "big" },
	init = function(g)
		g.s = { hits = 0, step = 0 }
	end,
	chargeMax = function(g)
		return if g.sk("ax_charge2") > 0 then 3 else 2
	end,
	chargeFull = function(g)
		return g.has("ax_fullmoon")
	end,
	haste = function(g)
		return if g.has("ax_breath") then 1.25 else 1
	end,
	mult = function(g)
		return 1 + (if g.has("ax_roar") then 0.1 else 0) + (if g.has("ax_fullmoon") then 0.3 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	-- 도끼질이 맞았다: 켜 두었으면 세 번째(달 그림자 도끼부터는 두 번째) 타마다 달빛 도끼가 떨어진다(겹 메아리부터는 둘)
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or not g.toggle or o.proc then
			return
		end
		g.s.hits += 1
		if g.s.hits % (if g.sk("ax_echo4") > 0 then 2 else 3) ~= 0 then
			return
		end
		for i = 0, if g.sk("ax_echo2") > 0 then 1 else 0 do
			g.call("echo", m, i)
		end
	end,
	tick = function(g, dt)
		g.hero.scale = if g.has("ax_titan") then 2 else 1 -- 거신: 몸이 두 배, 걸을 때마다 발밑에 금
		if g.has("ax_titan") and g.ground and abs(g.hero.vx) > 1 then
			g.s.step += dt
			if g.s.step > 0.28 then
				g.s.step = 0
				g.fx.cut(g.x, g.y - 1, 16, 12, g.tone, { life = 0.3, th = 2 })
				g.fx.cut(g.x, g.y - 1, 12, 150, g.tone, { life = 0.3, th = 2 })
			end
		end
	end,
	onBuffEnd = function(g, id)
		if id == "ax_brace" then
			g.fx.shards(g.x, g.y - 10, 10, g.tone, { kind = "tri", speed = 90, up = 40 }) -- 버티기가 풀리면 굳었던 빛이 깨져 흩어진다
		end
	end,
	-- 버티기: 몸이 굳는다 — 흰 윤곽 + 몸에 얹힌 밝은 빛. 만월: 윤곽을 따라 도는 빛
	heroGlow = function(g)
		return if g.has("ax_brace") then 0xffffff elseif g.has("ax_fullmoon") then g.tone.l else nil
	end,
	heroTint = function(g)
		return if g.has("ax_brace") then { g.tone.l, 0.4 } else nil
	end,
	mobGlow = function(g, m) -- 쪼개기의 "갈라짐": 몸 윤곽이 번갈아 빛난다
		return if (m.rend or 0) > 0 then (if floor(g.clock * 8) % 2 == 1 then g.tone.l else g.tone.n) else nil
	end,
	drawMarks = drawStacks,
	drawBack = function(ctx, g)
		if g.has("ax_brace") and g.pose then
			local sc = g.hero.scale
			for _, d in OUTLINE do
				g.sprite(g.pose.clip, g.pose.f, g.x + d[1], g.y + d[2], g.dir, { color = g.tone.n, scale = sc, alpha = 0.75 })
			end
		end
		if g.has("ax_fullmoon") then
			drawAura(ctx, g.x, g.y, g.hero.scale, g.tone, g.clock, min(1, (30 - g.left("ax_fullmoon")) * 4, g.left("ax_fullmoon") * 2))
		end
	end,
	-- (시험판의 draw — 버티기 동안 몸 위를 비스듬히 훑는 반짝임 — 은 캔버스의 오려 그리기(clip)를 쓴다. 게임의 그림판에는 그것이 없어 옮기지 않았다)
	-- 서버가 정해 화면에 알리는 것(g.call): 이름 → 하는 일
	calls = {
		echo = dropAxe,
	},
	-- 서버(sim/room.luau의 kitAfter)가 알리는 따로 나가는 타: 이름 → 그 이펙트.
	--  o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것 — 피해 숫자가 이때 뜬다) · i(몇째 것 — 겹 메아리의 둘째 도끼는 1) }
	procs = {
		echo = function(g, m, o)
			dropAxe(g, m, o.i or 0, o)
		end,
	},
	skills = skills,
}

return axion
