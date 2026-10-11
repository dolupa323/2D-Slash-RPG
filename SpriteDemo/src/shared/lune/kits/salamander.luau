-- 살라맨더 — 불주먹. 핵심 장치: 열기(주먹이 맞으면 오르고 쉬면 식는다 · 달아오르면 기술마다 불꽃이 한 번 더 · 폭주면 가득 찬 채 고정).
--  공방 시험 탭의 dino-workshop/js/lune/kits/salamander.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   달아오름 50부터(1차) → 40부터 · 더 빨리 오르고 천천히 식는다(끓는 피)
--   불티: 맞을 때마다 하나(1차) → 달아오름 동안 둘(겹불티) → 옆의 적으로 한 번 옮겨붙는다(옮겨붙는 불티) → 세모 날개의 불새(불새)
--  열기의 수치(오르는 양 · 식는 빠르기 · 달아오름의 기준)는 설계 자료(COMBAT.kit.salamander.core — design/combat.js의 KIT1)를 쓴다.
--  옮기며 바뀐 것: end → finish · until → till · { ...flame, … } → flameWith · 오려 그리기(clip — 열 방출의 섬광이 땅 아래로 내려가지 않게) → 땅 위의 줄만 찍는다.
--  화염 광선의 광선(시트의 그림 waveproj)은 게임의 기술 자료(COMBAT.skills의 shots)가 따로 그린다 — 여기서는 판정과 불티만 낸다.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local poly, disc, oval, starPts, drawFist, drawBird = Fx.poly, Fx.disc, Fx.oval, Fx.starPts, Fx.drawFist, Fx.drawBird
local dash, buff, flame = Common.dash, Common.buff, Common.flame
local floor, sin, cos, min, max, abs, sqrt = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.sqrt
local function R(v: number): number
	return floor(v + 0.5)
end
local HEAT = COMBAT.kit.salamander.core -- gain · max · hot · cool · decay

local function flameWith(o)
	local out = table.clone(flame)
	for k, v in o do
		out[k] = v
	end
	return out
end
local function sign(v: number, zero: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else zero
end

-- 달아오름의 기준(끓는 피를 배우면 40)
local function hotAt(g): number
	return if g.sk("sl_heat2") > 0 then 40 else HEAT.hot
end
local function hot(g): boolean
	return g.s.heat >= hotAt(g) or g.has("sl_overheat")
end

-- 불티(사출기 — 1차에 배우고 2~4차 패시브가 강화한다): 휘어 날아가 닿는 곳에서 톡 터진다. hop = 맞힌 뒤 옆의 적으로 한 번 옮겨붙는다. 불새를 배우면 세모 날개의 새
--  o.land = 닿은 순간에 부를 것
local function ember(g, x: number, y: number, t, hop: boolean?, side: number?, o)
	if not t then
		return
	end
	local tone, sd, bird = g.tone, side or 1, g.sk("sl_ember4") > 0
	g.shot({
		x = x,
		y = y,
		target = t,
		speed = 220,
		curl = 150 * sd,
		draw = function(ctx, p)
			if bird then
				drawBird(ctx, p.x, p.y, 4, sign(t.x - p.x, 1), tone, p.t * 30)
			else -- 작은 불티: 밝은 점과 짧은 꼬리
				ctx:style(tone.n)
				ctx:rect(R(p.x) - 1, R(p.y) - 1, 3, 3)
				ctx:style(tone.w)
				ctx:rect(R(p.x), R(p.y), 1, 1)
			end
		end,
		onReach = function(p)
			g.hurt(t, 3, { proc = true })
			g.fx.pop(p.x, p.y, tone, { r = 4 })
			g.fx.shards(p.x, p.y, 2, tone, flame)
			if o and o.land then
				o.land()
			end
			if hop then
				ember(g, p.x, p.y, g.nearest(110, { from = t.x, ["not"] = t }), false, -sd)
			end
		end,
	})
end

local function fist(g, dmg: number) -- 앞으로 날아가는 각진 주먹 모양 불길
	local dir, tone = g.dir, g.tone
	g.shot({ x = g.fwd(14), y = g.y - 9, vx = dir * 270, life = 0.42, w = 14, h = 18, dmg = dmg, o = { kb = 60 }, draw = function(ctx, p)
		drawFist(ctx, p.x, p.y, 6, dir, tone)
	end, finish = function(p)
		g.fx.pop(p.x, p.y, tone, { r = 6 })
	end })
end

local function fireZone(g, x: number, y: number, w: number, life: number) -- 바닥에서 일렁이는 낮은 불길 줄(계속 태운다)
	local tone = g.tone
	return g.shot({ x = x, y = y, life = life, back = true, tick = 0.5, w = w, h = 22, dmg = 2, o = { proc = true }, draw = function(ctx, p)
		local k = min(1, (p.life - p.t) * 2)
		for i = -floor(w / 16), floor(w / 16) do
			local h, fx = (4 + 6 * abs(sin(p.t * 7 + i * 1.7))) * k, p.x + i * 8
			poly(ctx, { { fx - 4, p.y }, { fx + sin(p.t * 5 + i) * 2, p.y - h }, { fx + 4, p.y } }, if i % 2 ~= 0 then tone.n else tone.l)
		end
	end })
end

-- 불꽃 한 가닥: 밑동 (x, y)에서 ang(도, 90 = 위) 쪽으로 높이 h — 어두운 자주 · 네온 · 밝은 속 · 흰 심 네 겹, 끝이 sway만큼 휜다
local TONGUE = { { 1, "d" }, { 0.78, "n" }, { 0.52, "l" }, { 0.26, "w" } }
local function tongue(ctx, x: number, y: number, w: number, h: number, tone, o)
	if h < 2 then
		return
	end
	local ang, sway, core = (o and o.ang) or 90, (o and o.sway) or 0, not (o and o.core == false)
	local a = ang * 0.01745
	local dx, dy, px, py = cos(a), -sin(a), sin(a), cos(a)
	for _, layer in TONGUE do
		local k, key = layer[1], layer[2]
		if key == "w" and not core then
			continue
		end
		local ww, hh, sw = w * k, h * (0.55 + 0.45 * k), sway * k
		local pts = { { -ww / 2, 0 }, { -ww * 0.56 + sw * 0.2, hh * 0.36 }, { -ww * 0.2 + sw * 0.6, hh * 0.72 }, { sw, hh }, { ww * 0.26 + sw * 0.5, hh * 0.6 }, { ww * 0.56 + sw * 0.15, hh * 0.3 }, { ww / 2, 0 } }
		for i, p in pts do
			pts[i] = { x + px * p[1] + dx * p[2], y + py * p[1] + dy * p[2] }
		end
		poly(ctx, pts, tone[key])
	end
end
-- 불기둥: 솟구쳤다가 흔들리며 잦아드는 불꽃 + 양옆의 작은 불꽃 둘
local function pillar(g, x: number, y: number, w: number, h: number, o)
	local delay, life, seed = (o and o.delay) or 0, (o and o.life) or 0.55, (o and o.seed) or 0
	local tone = g.tone
	g.fx.add(life, function(ctx, k)
		local grow, t = if k < 0.16 then k / 0.16 else (1 - (k - 0.16) / 0.84) ^ 0.7, k * life
		if k < 0.6 then
			tongue(ctx, x - w * 0.45, y, w * 0.55, h * grow * 0.5, tone, { sway = -2 + sin(t * 30 + seed), core = false })
			tongue(ctx, x + w * 0.45, y, w * 0.55, h * grow * 0.42, tone, { sway = 2 + sin(t * 26 + seed), core = false })
		end
		tongue(ctx, x, y, w * (0.7 + 0.3 * grow), h * grow, tone, { sway = sin(t * 22 + seed) * w * 0.3, core = k < 0.55 })
	end, { delay = delay })
end
-- 연기: 불이 지나간 자리에서 피어오르는 어두운 덩이
local function smoke(g, x: number, y: number, n: number?, delay: number?)
	for i = 0, (n or 3) - 1 do
		local dx, r, vx, up = (g.rnd() - 0.5) * 14, 3 + g.rnd() * 3, (g.rnd() - 0.5) * 16, 26 + g.rnd() * 20
		g.fx.add(0.7 + g.rnd() * 0.3, function(ctx, k)
			ctx:alpha(0.5 * (1 - k))
			disc(ctx, x + dx + vx * k, y - 4 - up * k, max(1, R(r * (0.6 + k * 0.8))), if i % 2 == 1 then 0x393e46 else 0x515864)
			ctx:alpha(1)
		end, { delay = (delay or 0) + i * 0.05, back = true })
	end
end
-- 화염 강타 — 모으기: 머리 위에서 불티가 모여들며 불덩이가 자란다(불덩이 둘레로 불꽃 혀가 돈다)
local function gather(g, dur: number)
	local tone = g.tone
	g.shot({ x = g.x, y = g.y - 33, life = dur, update = function(p)
		p.x, p.y = g.x, g.y - 33
	end, draw = function(ctx, p)
		local k = p.t / p.life
		local r = R(3 + 7 * k)
		for i = 0, 5 do
			local a = i * 60 + p.t * 260
			tongue(ctx, p.x + cos(a * 0.01745) * r * 0.6, p.y - sin(a * 0.01745) * r * 0.6, 5, r * 0.9 + 3, tone, { ang = a, core = false })
		end
		disc(ctx, p.x, p.y, r, tone.n)
		disc(ctx, p.x, p.y, R(r * 0.7), tone.l)
		disc(ctx, p.x, p.y, max(1, R(r * 0.35)), tone.w)
		for i = 0, 5 do
			local u, a = (p.t * 3 + i * 0.17) % 1, i * 1.9 + 0.4
			local d = 28 * (1 - u) + r
			ctx:style(if u > 0.5 then tone.l else tone.n)
			ctx:rect(R(p.x + cos(a) * d), R(p.y - abs(sin(a)) * d * 0.8), 2, 2)
		end
	end })
end
-- 화염 강타 — 내리침: 한가운데서 부채꼴로 터지는 불꽃 다발과 흰 섬광 · 땅을 훑는 불의 쐐기 · 양옆으로 차례로 솟는 불기둥(달아오름이면 더 많고 높다) · 연기 · 그을린 자국
local SCORCH = { -17, -6, 4, 13, 22 }
local function slam(g)
	local x, y, tone, big = g.x, g.y, g.tone, hot(g)
	local n = if big then 5 else 3
	local reach = 54 + n * 8
	g.fx.add(0.42, function(ctx, k)
		local grow = if k < 0.2 then k / 0.2 else 1 - (k - 0.2) / 0.8
		for i = 0, 6 do
			tongue(ctx, x, y, 13, (if big then 48 else 38) * grow * (if i % 2 == 1 then 0.75 else 1), tone, { ang = 24 + i * 22, sway = sin(k * 20 + i) * 2, core = k < 0.5 })
		end
		if k < 0.3 then
			poly(ctx, starPts(x, y - 8, 30 * (1 - k * 2), k * 2), tone.w)
		end
	end)
	g.fx.add(0.3, function(ctx, k)
		local r = reach * (1 - (1 - k) * (1 - k))
		ctx:alpha(1 - k)
		for _, sd in { -1, 1 } do
			poly(ctx, { { x, y }, { x + sd * r, y }, { x + sd * r * 0.7, y - 7 * (1 - k) } }, tone.l)
			poly(ctx, { { x, y }, { x + sd * r * 0.8, y }, { x + sd * r * 0.5, y - 3 } }, tone.w)
		end
		ctx:alpha(1)
	end)
	for i = 1, n do
		for _, sd in { -1, 1 } do
			local px = x + sd * i * 19
			pillar(g, px, y, 14 - i, (if big then 56 else 40) - i * 6, { delay = i * 0.05, seed = i * sd })
			g.after(i * 0.05, function()
				g.fx.shards(px, y - 10, 2, tone, flame)
			end)
			g.after(i * 0.05 + 0.3, function()
				smoke(g, px, y - 6, 2)
			end)
		end
	end
	g.fx.shards(x, y - 6, 24, tone, flameWith({ speed = 180, up = 100 }))
	smoke(g, x, y - 10, 5, 0.25)
	g.fx.add(1.2, function(ctx, k)
		ctx:alpha(0.45 * (1 - k))
		ctx:style(0x12161c)
		ctx:rect(R(x - 30), R(y), 60, 1)
		ctx:rect(R(x - 20), R(y) + 1, 40, 1)
		ctx:alpha(1 - k)
		ctx:style(tone.n)
		for _, dx in SCORCH do
			if floor(k * 12 + dx + 40) % 3 ~= 0 then
				ctx:rect(R(x + dx), R(y), 1, 1)
			end
		end
		ctx:alpha(1)
	end, { back = true })
	g.hitAt(x, y, reach, 44, 8, { lift = 230, stop = 0.08 })
	g.shake(1, 0.12)
	local sun = g.s.sun
	if sun and not sun.dead and sun.t < sun.life then -- 작은 태양이 떠 있으면 떨어져 크게 터진다(극딜 연출)
		sun.dead = true
		g.endBuff("sl_sun")
		g.after(0.12, function()
			g.fx.beam(sun.x, y, 30, 140, tone, { life = 0.5 })
			for i = -3, 3 do
				pillar(g, sun.x + i * 26, y, 16, 70 - abs(i) * 12, { delay = abs(i) * 0.05, life = 0.7, seed = i })
			end
			g.fx.add(0.3, function(ctx, k)
				poly(ctx, starPts(sun.x, y - 24, 60 * (1 - k * 0.7), k), if k < 0.4 then tone.w else tone.l)
			end)
			g.fx.shards(sun.x, y - 20, 34, tone, flameWith({ speed = 240, up = 120 }))
			smoke(g, sun.x, y - 20, 8, 0.3)
			g.hitAt(sun.x, y, 100, 90, 25, { lift = 260 })
			g.shake(8, 0.5)
			g.invert(0.09)
		end)
	end
end
-- 열 방출: 몸이 하얗게 달아올랐다가 → 사방으로 불꽃 혀가 터져 나가고 → 어깨에서 김이 비스듬히 뿜어지고 → 땅을 타고 낮은 불길이 양옆으로 달린다. 열기만큼 크다
local STEAM = { { 60, 0 }, { 120, 0.02 }, { 28, 0.05 }, { 152, 0.07 } }
local function vent(g)
	local h, tone, x, cy, gy = g.s.heat, g.tone, g.x, g.y - 9, g.y
	local RR, N = 24 + h * 0.5, 12
	g.s.ventAt = g.clock
	g.fx.add(0.42, function(ctx, k)
		local e = 1 - (1 - k) * (1 - k)
		local r0, len = 6 + RR * 0.55 * e, (RR * 0.75 + 6) * (if k < 0.25 then k / 0.25 else 1 - (k - 0.25) / 0.75)
		for i = 0, N - 1 do
			local a = i * (360 / N) + 15
			local by = cy - sin(a * 0.01745) * r0 * 0.8
			if by > gy - 1 then
				continue
			end
			tongue(ctx, x + cos(a * 0.01745) * r0, by, 9 + h * 0.04, len * (if i % 2 == 1 then 0.8 else 1), tone, { ang = a, core = k < 0.5 })
		end
	end)
	g.fx.add(0.2, function(ctx, k) -- 몸에서 번지는 섬광(땅 아래로는 그리지 않는다)
		local r = R((10 + RR * 0.4) * (1 - k * 0.5))
		ctx:alpha(1 - k)
		for _, q in { { r, tone.l }, { R(r * 0.6), tone.w } } do
			local rr = q[1]
			ctx:style(q[2])
			local X, Y = R(x), R(cy)
			for dy = -rr, rr do
				if Y + dy < gy then
					local w = floor(sqrt(rr * rr - dy * dy + rr * 0.5))
					ctx:rect(X - w, Y + dy, w * 2 + 1, 1)
				end
			end
		end
		ctx:alpha(1)
	end)
	for _, q in STEAM do -- 김
		local a = q[1]
		g.fx.add(0.4, function(ctx, k)
			local c, sn = cos(a * 0.01745), sin(a * 0.01745)
			local l, w, sx, sy = (20 + h * 0.3) * (1 - (1 - k) * (1 - k)), 5 * (1 - k) + 1, x + c * 6, cy - 6 - sn * 4
			ctx:alpha(0.85 * (1 - k))
			poly(ctx, { { sx - sn, sy - c }, { sx + c * l - sn * w, sy - sn * l - c * w }, { sx + c * l + sn * w, sy - sn * l + c * w }, { sx + sn, sy + c } }, 0xeef6f6)
			ctx:alpha(1)
		end, { delay = q[2] })
	end
	for _, sd in { -1, 1 } do
		for i = 1, R(RR / 13) do
			pillar(g, x + sd * i * 13, gy, 9, 17 - i * 2 + h * 0.06, { delay = 0.03 * i, life = 0.4, seed = i })
		end
	end
	smoke(g, x, cy - 10, 4 + R(h / 30), 0.2)
	g.fx.shards(x, cy, 10 + R(h / 6), tone, flameWith({ speed = 150, up = 60 }))
	g.hitAt(x, gy, RR, 54, R(3 + h / 5), { kb = 120, lift = 120 })
	g.s.heat = 0
	g.shake(1 + h / 50, 0.15)
end
local function dragonEnd(g)
	local x, y, tone = g.fwd(24), g.y, g.tone
	g.invert(0.08)
	g.shake(8, 0.4)
	g.fx.ring(x, y - 8, 4, 40, tone, { squash = 1, back = false })
	g.fx.ring(x, y, 8, 70, tone)
	g.fx.beam(x, y, 26, 120, tone)
	g.fx.shards(x, y - 8, 28, tone, flameWith({ speed = 220, up = 110 }))
	g.hitAt(x, y, 56, 60, 12, { lift = 260, kb = 120 })
end

local skills = {
	{ id = "sl_beam", key = "Q", shot = 0.46, segs = { { clip = "wave", fps = 18, ev = { [7] = function(g)
		local x, y, gy, dir, tone = g.fwd(12), g.y - 9, g.y, g.dir, g.tone -- 시트의 광선(182x16)을 주먹 높이에 그대로 깐다
		g.shot({ x = x, y = y, life = 0.42, sprite = "waveproj", dir = dir, fps = 14 })
		g.fx.streaks(x + dir * 90, gy, 10, -dir, tone, { w = 170, h = 16 })
		for i = 0, 2 do
			g.after(i * 0.07, function()
				g.hitAt(x + dir * 91, gy, 91, 22, 3, if i == 2 then { kb = 120, dir = dir } else { dir = dir })
			end)
		end
		g.after(0.2, function()
			for i = 0, 8 do
				g.fx.shards(x + dir * (10 + i * 20), y, 2, tone, flame)
			end
		end)
	end } } } },
	{ id = "sl_punch", key = "A", shot = 0.6, segs = { { clip = "punch", fps = 22, ev = {
		[6] = function(g)
			g.fx.shards(g.fwd(22), g.y - 8, 6, g.tone, flameWith({ dir = g.dir, spread = 0.8 }))
			g.hit(0, 38, 24, 4, 3, { kb = 50 })
		end,
		[12] = function(g)
			g.fx.ring(g.fwd(24), g.y - 8, 3, 16, g.tone, { squash = 1, back = false, life = 0.2 })
			g.fx.shards(g.fwd(24), g.y - 8, 9, g.tone, flameWith({ dir = g.dir, spread = 0.9, speed = 130 }))
			g.hit(0, 42, 26, 4, 5, { kb = 150, stop = 0.05 })
		end,
	} } } },
	{ id = "sl_slam", key = "W", ground = true, shot = 0.78, segs = { { clip = "slam", fps = 16, ev = { [3] = function(g)
		gather(g, 8 / 16)
	end, [11] = slam } } } },
}

-- 불꽃 돌진: 적에게 달려들며 친다 — 꺾인 불 자국 + 맞는 순간 별 모양 불티. 이어 누르면 세 번까지
do
	local segs = {}
	for i = 0, 2 do
		segs[i + 1] = { clip = "dash", loop = true, dur = 0.15, fps = 20, float = true, trail = true, needPress = i > 0, start = function(g)
			local m, x0 = g.nearest(130, { front = i == 0 }), g.x
			if not m then
				g.move(260, 0.12)
				return
			end
			g.face(sign(m.x - g.x, g.dir))
			local tx = m.x - g.dir * 12
			g.move(abs(tx - g.x) / 0.12, 0.12)
			g.after(0.13, function()
				g.fx.cut((x0 + g.x) / 2, g.y - 8, abs(g.x - x0) + 12, (i - 1) * 12, g.tone, { life = 0.3, th = 3 })
				g.fx.pop(m.x, m.y - m.h - 8, g.tone, { r = 8 })
				g.fx.shards(m.x, m.y - m.h - 8, 4, g.tone, flame)
				g.hurt(m, 6, { stop = 0.04, kb = 40 })
			end)
		end }
	end
	table.insert(skills, { id = "sl_rush", key = "S", shot = 0.2, segs = segs })
end

local more = {
	buff("sl_tempo", "1"),
	{ id = "sl_vent", key = "Z", instant = true, shot = 0.16, cast = vent },
	{ id = "sl_meteor", key = "E", shot = 1.3, segs = { { clip = "slam", fps = 20, ev = { [11] = function(g) -- 꼬리를 끄는 불덩이가 포물선으로 날아가 불바다를 남긴다
		local dir, tone = g.dir, g.tone
		g.shot({
			x = g.x,
			y = g.y - 34,
			vx = dir * 150,
			vy = -150,
			g = 420,
			life = 2.5,
			every = { 0.04, function(p)
				g.fx.shards(p.x, p.y, 1, tone, flameWith({ speed = 10, up = 0, life = 0.3 }))
			end },
			draw = function(ctx, p)
				disc(ctx, p.x, p.y, 5, tone.n)
				disc(ctx, p.x, p.y, 3, tone.l)
				ctx:style(tone.w)
				ctx:rect(R(p.x) - 1, R(p.y) - 1, 2, 2)
			end,
			finish = function(p)
				local gy = floor(p.y / 16) * 16
				g.fx.ring(p.x, gy, 6, 42, tone)
				g.fx.shards(p.x, gy - 4, 16, tone, flameWith({ speed = 150, up = 90 }))
				g.hitAt(p.x, gy, 42, 44, 8, { lift = 150 })
				fireZone(g, p.x, gy, 76, 6)
			end,
		})
	end } } } },
	{ id = "sl_barrage", key = "D", shot = 0.8, holdFor = 2, segs = {
		{ clip = "punch", from = 0, to = 12, loopFrom = 6, fps = 36, hold = true, max = 3, min = 0.4, every = { 0.08, function(g) -- 앞에 겹쳐 찍히는 주먹 자국들
			if g.held < 0.16 then
				return
			end
			local x, y = g.fwd(20 + g.rnd() * 18), g.y - 4 - g.rnd() * 15
			g.fx.ring(x, y, 1, 6, g.tone, { squash = 1, back = false, life = 0.12 })
			g.hit(0, 44, 26, 4, 2, {})
		end } },
		{ clip = "punch", from = 11, fps = 18, ev = { [12] = function(g) -- 마무리: 큰 꽃 모양 폭발 — 그때의 열기만큼 세다
			local h, x, y = g.s.heat, g.fwd(28), g.y - 9
			for i = 0, 7 do
				local a = i * 45
				g.fx.cut(x + cos(a * 0.01745) * 12, y - sin(a * 0.01745) * 12, 22 + h * 0.12, a, g.tone, { th = 5, life = 0.3 })
			end
			g.fx.ring(x, y, 4, 30, g.tone, { squash = 1, back = false })
			g.fx.shards(x, y, 14, g.tone, flameWith({ speed = 160 }))
			g.hit(0, 60, 44, 4, R(10 + h / 5), { kb = 160, stop = 0.08 })
			g.shake(1, 0.12)
		end } },
	} },
	{ id = "sl_furnace", key = "X", instant = true, shot = 0.8, cast = function(g) -- 화로: 곁에 있으면 열기가 식지 않고 오른다
		local tone = g.tone
		g.fx.ring(g.fwd(18), g.y, 3, 20, tone)
		g.s.furnace = g.shot({ x = g.fwd(18), y = g.y, life = 10, back = true, tick = 0.5, w = 50, h = 30, dmg = 2, o = { proc = true }, draw = function(ctx, p)
			poly(ctx, { { p.x - 7, p.y - 7 }, { p.x + 7, p.y - 7 }, { p.x + 4, p.y }, { p.x - 4, p.y } }, 0x232931)
			ctx:style(0x56657a)
			ctx:rect(R(p.x) - 8, R(p.y) - 8, 16, 2)
			for i = -1, 1 do
				local h = 5 + 4 * abs(sin(p.t * 8 + i * 2))
				poly(ctx, { { p.x + i * 4 - 3, p.y - 8 }, { p.x + i * 4 + sin(p.t * 6 + i), p.y - 8 - h }, { p.x + i * 4 + 3, p.y - 8 } }, if i ~= 0 then tone.n else tone.l)
			end
			for i = 0, 3 do
				local k = (p.t * 0.7 + i * 0.25) % 1
				ctx:style(tone.l)
				ctx:rect(R(p.x + sin(i * 2 + p.t * 2) * 12), R(p.y - 14 - k * 16), 1, 1)
			end
		end })
	end },
	buff("sl_warm", "2"),
	{ id = "sl_cross", key = "5", instant = true, shot = 0.3, cast = function(g)
		g.buff("sl_cross")
		g.fx.ring(g.x, g.y - 9, 4, 20, g.tone, { squash = 0.9, back = false })
		g.fx.shards(g.x, g.y - 9, 10, g.tone, flameWith({ speed = 90 }))
	end },
	{ id = "sl_tide", key = "R", ground = true, shot = 0.62, segs = { { clip = "wave", fps = 18, ev = { [7] = function(g) -- 계단처럼 솟았다 꺼지는 불 세모들이 양쪽으로 달려간다
		local tone = g.tone
		g.shake(1, 0.1)
		g.fx.ring(g.x, g.y, 4, 30, tone)
		for _, s in { -1, 1 } do
			g.shot({
				x = g.x + s * 10,
				y = g.y,
				vx = s * 200,
				life = 0.9,
				w = 28,
				h = 34,
				dmg = 10,
				ghost = true,
				dir = s,
				o = { lift = 140 },
				every = { 0.05, function(p)
					g.fx.shards(p.x, p.y - 8, 1, tone, flameWith({ speed = 20 }))
				end },
				draw = function(ctx, p)
					for i = 0, 3 do
						local h, x = (20 - i * 4) * (0.7 + 0.3 * sin(p.t * 22 + i)), p.x - s * i * 9
						poly(ctx, { { x - 5, p.y }, { x + s * 2, p.y - h }, { x + 5, p.y } }, if i % 2 == 1 then tone.n else tone.l)
					end
				end,
			})
		end
	end } } } },
	{ id = "sl_king", key = "F", shot = 0.95, segs = { -- 누를 때마다 좌우 주먹: 첫 주먹 → 둘째 주먹 → 셋째에 겹 폭발
		{ clip = "punch", from = 0, to = 9, fps = 26, ev = { [6] = function(g)
			fist(g, 9)
		end } },
		{ clip = "punch", from = 10, fps = 24, needPress = true, ev = { [12] = function(g)
			fist(g, 9)
		end } },
		{ clip = "punch", from = 0, to = 9, fps = 22, needPress = true, ev = { [6] = function(g)
			local x, y = g.fwd(60), g.y - 9
			fist(g, 0)
			g.after(0.16, function()
				g.fx.ring(x, y, 4, 34, g.tone, { squash = 1, back = false })
				g.fx.ring(x, y, 2, 22, g.tone, { squash = 1, back = false, delay = 0.06 })
				g.fx.shards(x, y, 20, g.tone, flameWith({ speed = 180 }))
				g.hitAt(x, g.y, 44, 50, 16, { kb = 150, stop = 0.08 })
				g.shake(1, 0.12)
			end)
		end } },
	} },
	{ id = "sl_overheat", key = "3", instant = true, shot = 0.5, cast = function(g)
		g.buff("sl_overheat")
		g.shake(3, 0.25)
		g.fx.ring(g.x, g.y, 6, 44, g.tone)
		g.fx.aura(g.x, g.y, g.tone, { r = 22, h = 40 })
		g.fx.shards(g.x, g.y - 8, 20, g.tone, flameWith({ speed = 130, up = 100 }))
	end },
	{ id = "sl_sun", key = "4", instant = true, shot = 0.9, cast = function(g) -- 작은 태양: 머리 위에 떠서 불씨를 쏜다
		local tone = g.tone
		g.buff("sl_sun")
		g.fx.aura(g.x, g.y, tone, { r = 14, h = 44 })
		g.s.sun = g.shot({
			x = g.x,
			y = g.y - 46,
			life = 20,
			at = 0,
			summon = "sl_sun",
			update = function(p, dt)
				p.x += (g.x - p.x) * min(1, dt * 4)
				p.y = g.y - 46 + sin(p.t * 2) * 2
				p.at += dt
				if p.at > 0.6 then
					local m = g.nearest(140, { from = p.x })
					if m then
						p.at = 0
						g.shot({ x = p.x, y = p.y, target = m, speed = 240, draw = function(ctx, q)
							ctx:style(tone.l)
							ctx:rect(R(q.x) - 1, R(q.y) - 1, 3, 3)
						end, onReach = function(q)
							g.hurt(m, 3, { proc = true })
							g.fx.pop(q.x, q.y, tone, { r = 3 })
						end })
					end
				end
			end,
			draw = function(ctx, p)
				local k = min(1, p.t * 3)
				disc(ctx, p.x, p.y, R(8 * k), tone.n)
				disc(ctx, p.x, p.y, R(6 * k), tone.l)
				disc(ctx, p.x, p.y, R(2 * k), tone.w)
				for i = 0, 5 do
					local a = p.t * 3 + i * 1.047
					ctx:style(if i % 2 == 1 then tone.l else tone.n)
					ctx:rect(R(p.x + cos(a) * 12), R(p.y + sin(a) * 12), 2, 2)
				end
				oval(ctx, p.x, p.y, 15, 15, tone.d, 1, 3, p.t * 9)
			end,
		})
	end },
	{ id = "sl_dragon", key = "G", shot = 0.88, segs = {
		{ clip = "dash", fps = 16, loop = true, dur = 0.62, float = true, trail = true, start = function(g)
			g.dim(0.4, 1.3)
			g.move(310, 0.62)
			g.fx.ring(g.x, g.y - 8, 4, 26, g.tone, { squash = 1, back = false })
		end, every = { 0.045, function(g) -- 지나간 자리에 불길이 남아 계속 태운다
			local x, y, tone = g.x - g.dir * 8, g.y, g.tone
			g.fx.spike(x, y, 9, 12 + g.rnd() * 10, tone, { life = 1.1 })
			g.fx.shards(x, y - 6, 2, tone, flame)
			g.hitAt(g.x, y, 16, 26, 2, { kb = 20 })
			g.shot({ x = x, y = y, life = 1.1, w = 12, h = 16, dmg = 1, tick = 0.35, o = { proc = true } })
		end } },
		{ clip = "punch", from = 9, fps = 18, ev = { [12] = dragonEnd } },
	} },
	{ id = "sl_ember", key = "T" }, -- 사출기: 켜고 끈다(판정은 아래 onHit)
	dash("sl_roll", "dash", 3, 430, 73),
}
for _, s in more do
	table.insert(skills, s)
end
for _, s in Common.commons do
	table.insert(skills, s)
end

local salamander = {
	tone = "pink",
	toggle = "sl_ember",
	icons = { c_hero = "moon", sl_ember = "star", sl_tempo = "haste", sl_warm = "up", sl_cross = "shield", sl_overheat = "flame", sl_sun = "disc" },
	init = function(g)
		g.s = { heat = 0, lastHit = -9, emberAt = -9, aura = 0, step = 0, sun = nil, furnace = nil }
	end,
	haste = function(g)
		return 1 + (if g.has("sl_tempo") then 0.25 else 0) + (if g.has("sl_warm") then 0.1 else 0)
	end,
	speed = function(g)
		return if hot(g) then 1.15 else 1
	end,
	heroTint = function(g) -- 열 방출: 몸이 잠깐 하얗게 달아오른다
		return if g.clock - (g.s.ventAt or -9) < 0.12 then { 0xffffff, 0.85 } else nil
	end,
	mult = function(g)
		return 1 + (if hot(g) then 0.15 else 0) + (if g.has("sl_overheat") then 0.3 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	hot = hot,
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or o.proc then
			return
		end
		if g.sk("sl_heat") > 0 then
			g.s.heat = min(HEAT.max, g.s.heat + HEAT.gain * (if g.sk("sl_heat2") > 0 then 1.3 else 1))
			g.s.lastHit = g.clock
		end
		if hot(g) then
			g.call("flame", m) -- 달아오름: 불꽃이 한 번 더 터진다
		end
		if g.toggle and g.clock - g.s.emberAt > 0.25 then
			g.s.emberAt = g.clock
			for i = 0, if hot(g) and g.sk("sl_ember2") > 0 then 1 else 0 do
				g.call("ember", m.x, m.y - m.h - 10, g.nearest(130, { from = m.x, ["not"] = m }) or m, if i ~= 0 then -1 else 1)
			end
		end
	end,
	tick = function(g, dt)
		local f = g.s.furnace
		local nearFurnace = f ~= nil and f.t < f.life and abs(f.x - g.x) < 60
		if g.has("sl_overheat") then
			g.s.heat = HEAT.max
		elseif nearFurnace then
			g.s.heat = min(HEAT.max, g.s.heat + 5 * dt)
		elseif g.authority and g.clock - g.s.lastHit > HEAT.cool then -- 식는 것은 서버가 셈한다(화면은 받은 값을 그린다)
			g.s.heat = max(0, g.s.heat - HEAT.decay * (if g.sk("sl_heat2") > 0 then 0.6 else 1) * dt)
		end
		if g.has("sl_overheat") then -- 폭주: 몸 둘레에 계속 타오르는 불, 발자국마다 불
			g.s.aura += dt
			if g.s.aura > 0.06 then
				g.s.aura = 0
				g.fx.shards(g.x + (g.rnd() - 0.5) * 12, g.y - 2 - g.rnd() * 16, 1, g.tone, flameWith({ speed = 8, up = 50, life = 0.5 }))
			end
			if g.ground and abs(g.hero.vx) > 1 then
				g.s.step += dt
				if g.s.step > 0.12 then
					g.s.step = 0
					g.fx.spike(g.x - g.dir * 4, g.y, 6, 7 + g.rnd() * 5, g.tone, { life = 0.5 })
				end
			end
		end
	end,
	drawBack = function(ctx, g) -- 맞불: 몸을 두른 불꽃 고리
		if g.has("sl_cross") then
			for i = 0, 11 do
				local a = g.clock * 5 + i * 0.5236
				local x, y = g.x + cos(a) * 15, g.y - 9 + sin(a) * 12
				ctx:style(if i % 2 == 1 then g.tone.n else g.tone.l)
				ctx:rect(R(x) - 1, R(y) - 1, 2 + (if i % 3 == 0 then 1 else 0), 2)
			end
		end
	end,
	draw = function(ctx, g) -- 열기 막대(발밑의 이름표 바로 아래 — 핵심 장치): 눈금을 넘으면 달아오름. 열기를 배운 내 캐릭터에만 보인다
		if g.sk("sl_heat") <= 0 then
			return
		end
		-- 발밑에서 Common.GAUGE_DOWN만큼 아래: 이름표(발밑 2~9점)에 가리지 않는다(사용자 2026-10-11: "캐릭터 아래에 게이지 보여주는 스킬들이 … 닉네임이랑 겹쳐서 가려버리는 문제")
		local x, y, w = R(g.x) - 9, R(g.y) + Common.GAUGE_DOWN, R((18 * g.s.heat) / 100)
		ctx:style(0x12161c)
		ctx:rect(x - 1, y - 1, 20, 4)
		ctx:style(if hot(g) then (if floor(g.clock * 10) % 2 == 1 then g.tone.l else g.tone.n) else g.tone.d)
		ctx:rect(x, y, w, 2)
		ctx:style(0xeef6f6)
		ctx:rect(x + R(18 * hotAt(g) / 100), y - 1, 1, 4)
	end,
	-- 서버가 정해 화면에 알리는 것(g.call)
	calls = {
		-- 불티 하나: (x, y)에서 t에게. 옮겨붙는 것은 옮겨붙는 불티를 배웠을 때
		ember = function(g, x, y, t, side)
			ember(g, x, y, t, g.sk("sl_ember3") > 0, side)
		end,
		flame = function(g, m)
			g.fx.shards(m.x, m.y - m.h - 8, 3, g.tone, flame)
			g.hurt(m, 1, { proc = true, quiet = true })
		end,
	},
	-- 지금의 서버(1차 — sim/kit.luau)가 알리는 따로 나가는 타. o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것) }
	procs = {
		-- o.i = 몇째 불티(겹불티의 둘째는 반대로 휜다) · o.hop = 앞의 불티가 맞힌 뒤 옮겨붙은 것(조금 늦게 떠난다)
		ember = function(g, m, o)
			local function go()
				ember(g, o.sx, o.sy, m, false, if o.i == 1 then -1 else 1, o)
			end
			if o.hop then
				g.after(0.3, go)
			else
				go()
			end
		end,
		flame = function(g, m, o)
			g.fx.shards(m.x, m.y - m.h - 8, 3, g.tone, flame)
			o.land()
		end,
	},
	skills = skills,
}

return salamander
