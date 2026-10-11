--!native
--!optimize 2
-- 이펙트 — 공방 시험 탭의 dino-workshop/js/lune/fx.js를 줄마다 옮긴 것(사용자 2026-10-08: "시험탭의 이펙트를 게임으로 옮기세요").
--  Luneblade 시트 안 이펙트(납작한 다각형 휘두름 · 속 빈 세모 파편 · 점)와 같은 말투로 코드로 그린다. 모두 1점 단위로 찍는다 · 그러데이션 없음 ·
--  색은 캐릭터의 네온 한 벌(밝음 w → l → n → d). 이름 · 인자 · 수치는 fx.js와 같다 — 고칠 때는 시험 탭에서 먼저 고치고 여기를 맞춘다.
--  달라진 것은 말투뿐이다: ctx.fillStyle = c → ctx:style(c) · ctx.globalAlpha = a → ctx:alpha(a) · ctx.fillRect → ctx:rect (client/lune/canvas.luau) · 색 '#rrggbb' → 0xRRGGBB ·
--  점의 목록은 { x, y }(1부터). 버프 아이콘 · 피해 숫자(num)는 옮기지 않았다(게임은 화면 틀의 그림과 ui/kit.luau의 숫자를 쓴다).
--  직업 묶음(shared/lune/kits)이 모양을 그릴 때 이 도우미들을 쓴다 — 그리는 일은 화면에서만 일어난다(서버는 부르지 않는다).
local COMBAT = require(script.Parent.data["combat.generated"])

local floor, ceil, sin, cos, sqrt, abs, max, min, random, PI = math.floor, math.ceil, math.sin, math.cos, math.sqrt, math.abs, math.max, math.min, math.random, math.pi
local RAD = PI / 180
local function R(v: number): number
	return floor(v + 0.5)
end

local Fx = {}
Fx.R = R

-- 직업 색(mint · pink): n 직업 색 · l 밝은 색 · w 흰색 · d 어두운 색 — fx.js의 TONE(공방이 내보낸 값)
Fx.TONE = {}
for name, t in COMBAT.fx.tones do
	local function hex(c)
		return c[1] * 65536 + c[2] * 256 + c[3]
	end
	Fx.TONE[name] = { n = hex(t.n), l = hex(t.l), w = hex(t.w), d = hex(t.d) }
end
local DASHFX = COMBAT.fx.dash
Fx.DASHFX = DASHFX

local function line(ctx, x0: number, y0: number, x1: number, y1: number, c: number, th: number?)
	local t = th or 1
	ctx:style(c)
	x0, y0, x1, y1 = R(x0), R(y0), R(x1), R(y1)
	local dx, dy = abs(x1 - x0), abs(y1 - y0)
	local sx, sy = if x0 < x1 then 1 else -1, if y0 < y1 then 1 else -1
	local e = dx - dy
	for _ = 1, 2000 do
		ctx:rect(x0, y0, t, t)
		if x0 == x1 and y0 == y1 then
			break
		end
		local e2 = e * 2
		if e2 > -dy then
			e -= dy
			x0 += sx
		end
		if e2 < dx then
			e += dx
			y0 += sy
		end
	end
end
Fx.line = line

-- 다각형을 가로줄로 채운다
local function poly(ctx, pts, c: number)
	ctx:style(c)
	local y0, y1 = math.huge, -math.huge
	for _, p in pts do
		y0 = min(y0, p[2])
		y1 = max(y1, p[2])
	end
	local n = #pts
	local xs = {}
	for y = floor(y0), ceil(y1) do
		table.clear(xs)
		local sy = y + 0.5
		for i = 1, n do
			local a, b = pts[i], pts[i % n + 1]
			if (a[2] <= sy and b[2] > sy) or (b[2] <= sy and a[2] > sy) then
				xs[#xs + 1] = a[1] + ((sy - a[2]) / (b[2] - a[2])) * (b[1] - a[1])
			end
		end
		table.sort(xs)
		for i = 1, #xs - 1, 2 do
			local a, b = R(xs[i]), R(xs[i + 1])
			if b > a then
				ctx:rect(a, y, b - a, 1)
			end
		end
	end
end
Fx.poly = poly

-- 다각형 pts를 채우되 다각형 clip의 안쪽만(캔버스의 오려 그리기 clip 대신 — 수정 돔 위를 훑는 반짝임)
local function crossings(pts, sy: number)
	local xs = {}
	local n = #pts
	for i = 1, n do
		local a, b = pts[i], pts[i % n + 1]
		if (a[2] <= sy and b[2] > sy) or (b[2] <= sy and a[2] > sy) then
			xs[#xs + 1] = a[1] + ((sy - a[2]) / (b[2] - a[2])) * (b[1] - a[1])
		end
	end
	table.sort(xs)
	return xs
end
function Fx.polyIn(ctx, pts, c: number, clip)
	ctx:style(c)
	local y0, y1 = math.huge, -math.huge
	for _, p in pts do
		y0 = min(y0, p[2])
		y1 = max(y1, p[2])
	end
	for y = floor(y0), ceil(y1) do
		local xs, cs = crossings(pts, y + 0.5), crossings(clip, y + 0.5)
		for i = 1, #xs - 1, 2 do
			for j = 1, #cs - 1, 2 do
				local a, b = R(max(xs[i], cs[j])), R(min(xs[i + 1], cs[j + 1]))
				if b > a then
					ctx:rect(a, y, b - a, 1)
				end
			end
		end
	end
end

local function disc(ctx, cx: number, cy: number, r: number, c: number)
	ctx:style(c)
	cx, cy = R(cx), R(cy)
	local dy = -r
	while dy <= r do
		local w = floor(sqrt(r * r - dy * dy + r * 0.5))
		ctx:rect(cx - w, cy + dy, w * 2 + 1, 1)
		dy += 1
	end
end
Fx.disc = disc

-- dash = 끊는 간격, phase = 끊긴 자리를 돌리는 값
local function oval(ctx, cx: number, cy: number, rx: number, ry: number, c: number, th: number?, dash: number?, phase: number?)
	local t, d = th or 1, dash or 0
	ctx:style(c)
	local n, ph = max(16, ceil((rx + ry) * 2.2)), floor(phase or 0)
	for i = 0, n - 1 do
		if d ~= 0 and floor((i + ph + n * 64) / d) % 2 == 1 then
			continue
		end
		local a = (i / n) * PI * 2
		ctx:rect(R(cx + cos(a) * rx), R(cy + sin(a) * ry), t, t)
	end
end
Fx.oval = oval

-- 초승달 다각형: 가운데 (cx, cy), 바깥 반지름 r, 가장 두꺼운 곳 thick, 각 a0→a1(도 · 0 = 앞 · 90 = 위), dir = 보는 쪽
local function crescentPts(cx: number, cy: number, r: number, thick: number, a0: number, a1: number, dir: number, seg: number?)
	local n = seg or 7
	local out = {}
	for i = 0, n do
		local a = (a0 + ((a1 - a0) * i) / n) * RAD
		out[#out + 1] = { cx + dir * cos(a) * r, cy - sin(a) * r }
	end
	for i = n, 0, -1 do
		local u = i / n
		local a, rr = (a0 + (a1 - a0) * u) * RAD, r - thick * sin(PI * u)
		out[#out + 1] = { cx + dir * cos(a) * rr, cy - sin(a) * rr }
	end
	return out
end
Fx.crescentPts = crescentPts

-- 가늘고 긴 마름모(벤 자국): 가운데 (x, y), 길이 len, 각 ang(도), 가장 두꺼운 곳 th
local function cutPts(x: number, y: number, len: number, ang: number, th: number)
	local c, s, h = cos(ang * RAD), -sin(ang * RAD), len / 2
	return { { x - c * h, y - s * h }, { x - s * th, y + c * th }, { x + c * h, y + s * h }, { x + s * th, y - c * th } }
end
Fx.cutPts = cutPts

-- ---- 모양(스킬이 날아가는 것 · 놓이는 것을 그릴 때 쓴다) ----
function Fx.hexPts(x: number, y: number, r: number, squash: number?)
	local q = squash or 1
	local out = {}
	for i = 0, 5 do
		out[i + 1] = { x + cos(i * 1.0472) * r, y + sin(i * 1.0472) * r * q }
	end
	return out
end
local hexPts = Fx.hexPts

function Fx.starPts(x: number, y: number, r: number, rot: number?)
	local o = {}
	local base = rot or 0
	for i = 0, 7 do
		local a, rr = base + i * 0.7854, if i % 2 == 1 then r * 0.35 else r
		o[i + 1] = { x + cos(a) * rr, y + sin(a) * rr }
	end
	return o
end

-- 도끼: 날(초승달)과 자루. s = 크기, 날이 아래를 본다
function Fx.drawAxe(ctx, x: number, y: number, s: number, tone, alpha: number?)
	ctx:alpha(alpha or 1)
	line(ctx, x, y - s, x, y + s * 0.2, tone.d, max(1, R(s / 6)))
	poly(ctx, crescentPts(x, y - s * 0.2, s * 0.9, s * 0.5, 200, 340, 1, 6), tone.l)
	poly(ctx, crescentPts(x, y - s * 0.2, s * 0.9, s * 0.2, 215, 325, 1, 5), tone.w)
	ctx:alpha(1)
end

-- 달 수정: 두 면짜리 뾰족한 육각 기둥. (x, y) = 바닥 가운데
function Fx.drawCrystal(ctx, x: number, y: number, w: number, h: number, tone, cracked: boolean?)
	local t = y - h
	poly(ctx, { { x - w / 2, y }, { x - w / 2, t + w * 0.6 }, { x, t }, { x, y } }, tone.l)
	poly(ctx, { { x, y }, { x, t }, { x + w / 2, t + w * 0.6 }, { x + w / 2, y } }, tone.n)
	line(ctx, x, t + 2, x, y - 1, tone.w)
	if cracked then
		line(ctx, x - 2, t + h * 0.3, x + 1, t + h * 0.55, 0x232931)
		line(ctx, x + 1, t + h * 0.55, x - 1, y - 2, 0x232931)
	end
end

-- 주먹: 각진 네모 덩어리 + 뒤로 끌리는 꼬리
function Fx.drawFist(ctx, x: number, y: number, s: number, dir: number, tone)
	poly(ctx, { { x - dir * s * 2.2, y }, { x - dir * s * 0.6, y - s * 0.7 }, { x - dir * s * 0.6, y + s * 0.7 } }, tone.d)
	poly(ctx, { { x - dir * s * 0.7, y - s }, { x + dir * s * 0.7, y - s }, { x + dir * s, y - s * 0.4 }, { x + dir * s, y + s * 0.6 }, { x + dir * s * 0.5, y + s }, { x - dir * s * 0.7, y + s } }, tone.n)
	poly(ctx, { { x - dir * s * 0.2, y - s * 0.6 }, { x + dir * s * 0.6, y - s * 0.6 }, { x + dir * s * 0.6, y }, { x - dir * s * 0.2, y } }, tone.l)
end

-- 세모 날개의 새
function Fx.drawBird(ctx, x: number, y: number, s: number, dir: number, tone, flap: number?)
	local w = s * (0.6 + 0.4 * sin(flap or 0))
	poly(ctx, { { x + dir * s, y }, { x - dir * s * 0.6, y - w }, { x - dir * s * 0.2, y } }, tone.l)
	poly(ctx, { { x + dir * s, y }, { x - dir * s * 0.6, y + w * 0.7 }, { x - dir * s * 0.2, y } }, tone.n)
	ctx:style(tone.w)
	ctx:rect(R(x + dir * s * 0.4), R(y) - 1, 1, 1)
end

-- 기운이 휘감는 띠(바인드): 두 가닥이 몸을 감아 돈다. 뒤로 도는 반은 몸 뒤(front = false), 앞으로 도는 반은 몸 앞에 그린다
function Fx.drawCoil(ctx, x: number, y: number, w: number, h: number, t: number, tone, front: boolean)
	for r = 0, 1 do
		for i = 0, h * 2 - 1 do
			local a = t * 5 + i * 0.26 + r * PI
			local d = cos(a)
			if (d > 0) ~= front then
				continue
			end
			local xx = x + sin(a) * w * (0.78 + 0.22 * sin(i * 0.15 + t * 2))
			ctx:style(if abs(d) < 0.3 then tone.d elseif front then (if d > 0.85 then tone.w else tone.l) else tone.n)
			ctx:rect(R(xx) - 1, R(y - i * 0.5), if front then 3 else 2, 1)
		end
	end
	if front then
		for i = 0, 5 do
			local k = (t * 0.7 + i * 0.17) % 1
			ctx:style(if i % 2 == 1 then tone.l else tone.w)
			ctx:rect(R(x + sin(t * 5 + i * 1.3) * (w + 3)), R(y - k * (h + 4)), 1, 1)
		end
	end
end

-- 보름달: 겹 달무리(돌아가는 끊긴 고리) · 빛살 · 밝은 가장자리 · 그늘진 초승달 면 · 분화구
local CRATERS = { { -0.3, -0.28, 0.2 }, { 0.12, 0.34, 0.14 }, { -0.02, 0.02, 0.09 }, { -0.42, 0.3, 0.08 } }
function Fx.drawMoon(ctx, x: number, y: number, r: number, tone, t: number)
	ctx:alpha(0.22)
	disc(ctx, x, y, r + 10, tone.n)
	ctx:alpha(0.32)
	disc(ctx, x, y, r + 5, tone.l)
	ctx:alpha(1)
	oval(ctx, x, y, r + 13, r + 13, tone.n, 1, 3, t * 7)
	oval(ctx, x, y, r + 8, r + 8, tone.l, 1, 2, -t * 5)
	for i = 0, 11 do
		local a, r0 = i * 0.5236 + t * 0.35, r + 16 + (i % 2) * 2
		local r1 = r0 + 3 + (i % 3) * 2 + sin(t * 3 + i) * 1.5
		line(ctx, x + cos(a) * r0, y + sin(a) * r0, x + cos(a) * r1, y + sin(a) * r1, if i % 2 == 1 then tone.l else tone.n)
	end
	disc(ctx, x, y, r, tone.l)
	poly(ctx, crescentPts(x, y, r, r * 0.42, -75, 55, 1, 9), tone.n)
	poly(ctx, crescentPts(x, y, r, r * 0.2, 110, 250, 1, 8), tone.w)
	for _, c in CRATERS do
		local dx, dy, cr = c[1], c[2], c[3]
		disc(ctx, x + dx * r, y + dy * r, max(1, R(cr * r)), tone.n)
		ctx:style(tone.w)
		ctx:rect(R(x + dx * r - cr * r * 0.5), R(y + dy * r - cr * r * 0.7), 1, 1)
	end
	for i = 0, 3 do
		local a, d = t * 1.3 + i * 1.5708, r + 11
		ctx:style(tone.w)
		ctx:rect(R(x + cos(a) * d) - 1, R(y + sin(a) * d), 3, 1)
		ctx:rect(R(x + cos(a) * d), R(y + sin(a) * d) - 1, 1, 3)
	end
end

local POP = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 }, { -0.7, -0.7 } }
local MIX = { "tri", "dot", "tri", "bar" }

-- 이펙트 한 벌(화면마다 하나). 부르는 법은 fx.js의 createFx()가 돌려주는 것과 같다 — fx.ring(x, y, …)처럼 점으로 부른다
function Fx.new()
	local list, parts = {}, {}
	local api = {}
	-- draw(ctx, k) — k = 0→1. back = 캐릭터 뒤(바닥 고리 · 가시), delay = 늦게 시작
	local function add(life: number, draw, o)
		list[#list + 1] = { t = -((o and o.delay) or 0), life = life, draw = draw, back = (o ~= nil and o.back == true) }
	end
	api.add = add

	-- 휘두른 자국: 흰 초승달이 쓸고 지나간 뒤 가늘어지며 남는다
	function api.slash(x: number, y: number, dir: number, r: number, a0: number, a1: number, tone, o)
		local thick = (o and o.thick) or r * 0.42
		local life = (o and o.life) or 0.24
		add(life, function(ctx, k)
			if k < 0.3 then
				poly(ctx, crescentPts(x, y, r, thick, a0, a0 + (a1 - a0) * min(1, k / 0.22), dir), tone.w)
				return
			end
			local t = if k < 0.6 then thick * 0.7 elseif k < 0.85 then thick * 0.4 else thick * 0.18
			poly(ctx, crescentPts(x, y, r, t, a0 + (a1 - a0) * (k - 0.3) * 0.5, a1, dir), if k < 0.6 then tone.l else tone.n)
		end)
	end

	function api.cut(x: number, y: number, len: number, ang: number, tone, o)
		local life, th, delay = (o and o.life) or 0.2, (o and o.th) or 3, (o and o.delay) or 0
		add(life, function(ctx, k)
			local g = if k < 0.25 then k / 0.25 else 1
			poly(ctx, cutPts(x, y, len * g, ang, if k < 0.35 then th elseif k < 0.7 then th * 0.6 else 0.8), if k < 0.35 then tone.w elseif k < 0.7 then tone.l else tone.n)
		end, { delay = delay })
	end

	-- 퍼지는 고리(바닥에 누운 타원): 두께가 줄다가 끊어지며 사라진다
	function api.ring(x: number, y: number, r0: number, r1: number, tone, o)
		local life, squash, delay = (o and o.life) or 0.36, (o and o.squash) or 0.3, (o and o.delay) or 0
		local back = not (o and o.back == false)
		add(life, function(ctx, k)
			local r = r0 + (r1 - r0) * (1 - (1 - k) * (1 - k))
			oval(ctx, x, y, r, max(1, r * squash), if k < 0.25 then tone.w elseif k < 0.6 then tone.l else tone.n, if k < 0.5 then 2 else 1, if k > 0.72 then 3 else 0)
		end, { back = back, delay = delay })
	end

	-- 버프를 거는 순간: 발밑에서 퍼지는 겹 고리 + 몸 둘레로 솟는 빛줄(머리 위에는 아무것도 띄우지 않는다)
	function api.aura(x: number, y: number, tone, o)
		local r, h, life = (o and o.r) or 16, (o and o.h) or 26, (o and o.life) or 0.5
		if not (o and o.rings == false) then
			api.ring(x, y, 3, r + 6, tone, { life = life * 0.8 })
			api.ring(x, y, 2, r, tone, { life = life * 0.6, delay = 0.08 })
		end
		for i = 0, 8 do
			local dx, d, hh = (i - 4) * (r / 4.5) + (random() - 0.5) * 2, random() * 0.18, h * (0.5 + random() * 0.6)
			add(life, function(ctx, k)
				local top, len = y - 2 - hh * min(1, k * 1.6), max(1, R(hh * 0.45 * (1 - k)))
				ctx:style(if k < 0.35 then tone.w elseif k < 0.7 then tone.l else tone.n)
				ctx:rect(R(x + dx), R(top), 1, len)
			end, { delay = d })
		end
	end

	-- 퍼지는 육각 테두리(수정 계열)
	function api.hex(x: number, y: number, r0: number, r1: number, tone, o)
		local life, squash, delay = (o and o.life) or 0.4, (o and o.squash) or 0.4, (o and o.delay) or 0
		local back = not (o and o.back == false)
		add(life, function(ctx, k)
			if k > 0.75 and floor(k * 40) % 2 == 1 then
				return
			end
			local p = hexPts(x, y, r0 + (r1 - r0) * (1 - (1 - k) * (1 - k)), squash)
			local c = if k < 0.25 then tone.w elseif k < 0.6 then tone.l else tone.n
			for i = 1, 6 do
				local q = p[i % 6 + 1]
				line(ctx, p[i][1], p[i][2], q[1], q[2], c, if k < 0.5 then 2 else 1)
			end
		end, { back = back, delay = delay })
	end

	-- 두 점을 잇는 꺾인 빛줄(순간이동 자국 · 꺾이는 빛)
	function api.bolt(x0: number, y0: number, x1: number, y1: number, tone, o)
		local life, jag, th = (o and o.life) or 0.22, (o and o.jag) or 5, (o and o.th) or 1
		local n = max(2, R(sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) / 14))
		local pts = {}
		for i = 0, n do
			local mid = i > 0 and i < n
			pts[i + 1] = { x0 + ((x1 - x0) * i) / n + (if mid then (random() - 0.5) * jag * 2 else 0), y0 + ((y1 - y0) * i) / n + (if mid then (random() - 0.5) * jag * 2 else 0) }
		end
		add(life, function(ctx, k)
			if k > 0.6 and floor(k * 30) % 2 == 1 then
				return
			end
			for i = 1, n do
				line(ctx, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], if k < 0.3 then tone.w elseif k < 0.6 then tone.l else tone.n, th)
			end
		end)
	end

	-- 작은 터짐: 네 갈래 짧은 줄(맞는 순간)
	function api.pop(x: number, y: number, tone, o)
		local r, life = (o and o.r) or 5, (o and o.life) or 0.16
		add(life, function(ctx, k)
			local a, b, c = r * (0.4 + k), r * (0.9 + k), if k < 0.5 then tone.w else tone.l
			for _, d in POP do
				line(ctx, x + d[1] * a, y + d[2] * a, x + d[1] * b, y + d[2] * b, c)
			end
		end)
	end

	-- 빛기둥: 바닥 (x, y)에서 위로 h. 순식간에 굵어졌다가 가늘어진다
	function api.beam(x: number, y: number, w: number, h: number, tone, o)
		local life, delay = (o and o.life) or 0.42, (o and o.delay) or 0
		add(life, function(ctx, k)
			local g = if k < 0.12 then k / 0.12 elseif k < 0.5 then 1 else 1 - (k - 0.5) / 0.5
			local ww = max(1, R(w * g))
			ctx:style(tone.n)
			ctx:rect(R(x - ww / 2), R(y - h), ww, h)
			if ww > 3 then
				local w2 = R(ww * 0.6)
				ctx:style(tone.l)
				ctx:rect(R(x - w2 / 2), R(y - h), w2, h)
			end
			if ww > 6 and k < 0.5 then
				local w3 = R(ww * 0.28)
				ctx:style(tone.w)
				ctx:rect(R(x - w3 / 2), R(y - h), w3, h)
			end
			if k < 0.6 then
				oval(ctx, x, y, ww * 0.9 + 3, 2, tone.l, 1)
			end
		end, { delay = delay })
	end

	-- 솟는 수정 가시: 두 면(밝은 면 · 네온 면)짜리 세모. 솟았다가 가라앉는다
	function api.spike(x: number, y: number, w: number, h: number, tone, o)
		local life, delay, lean = (o and o.life) or 0.5, (o and o.delay) or 0, (o and o.lean) or 0
		add(life, function(ctx, k)
			local hh = h * (if k < 0.18 then k / 0.18 elseif k < 0.65 then 1 else (1 - k) / 0.35)
			local ax, ay = x + lean * (hh / h), y - hh
			poly(ctx, { { x - w / 2, y }, { ax, ay }, { x + w * 0.1, y } }, if k < 0.14 then tone.w else tone.l)
			poly(ctx, { { x + w * 0.1, y }, { ax, ay }, { x + w / 2, y } }, if k < 0.14 then tone.w else tone.n)
		end, { back = true, delay = delay })
	end

	-- 파편: 속 빈 세모(tri) · 점(dot) · 꽃잎 같은 마름모(petal) · 빠른 줄(bar)
	function api.shards(x: number, y: number, n: number, tone, o)
		local speed, up, grav, life = (o and o.speed) or 90, (o and o.up) or 50, (o and o.grav) or 240, (o and o.life) or 0.55
		local kind, dir, spread = (o and o.kind) or "tri", (o and o.dir) or 0, (o and o.spread) or 1
		for i = 0, n - 1 do
			local a = if dir ~= 0 then (if dir > 0 then 0 else PI) + (random() - 0.5) * PI * spread else random() * PI * 2
			local v = speed * (0.35 + random() * 0.75)
			local kd = if kind == "mix" then MIX[i % 4 + 1] else kind
			parts[#parts + 1] = {
				x = x,
				y = y,
				vx = cos(a) * v,
				vy = sin(a) * v * 0.6 - up * (0.4 + random() * 0.8),
				g = grav,
				t = 0,
				life = life * (0.6 + random() * 0.7),
				kind = kd,
				size = if kd == "tri" then 2 + random() * 3 else 1 + (if random() < 0.3 then 1 else 0),
				rot = random() * 6,
				vr = (random() - 0.5) * 12,
				c = if i % 3 == 0 then tone.l else tone.n,
			}
		end
	end

	-- 위로 떠오르는 점(영혼 · 치유)
	function api.rise(x: number, y: number, n: number, tone, o)
		local w, speed, life = (o and o.w) or 16, (o and o.speed) or 34, (o and o.life) or 0.9
		for i = 0, n - 1 do
			parts[#parts + 1] = {
				x = x + (random() - 0.5) * w,
				y = y - random() * 10,
				vx = (random() - 0.5) * 10,
				vy = -speed * (0.5 + random()),
				g = 0,
				t = -random() * 0.2,
				life = life * (0.6 + random() * 0.6),
				kind = if random() < 0.3 then "plus" else "dot",
				size = 1,
				rot = 0,
				vr = 0,
				c = if i % 2 == 1 then tone.l else tone.n,
			}
		end
	end

	-- 속도선
	function api.streaks(x: number, y: number, n: number, dir: number, tone, o)
		local S = DASHFX.streak
		local w, h, len, life = (o and o.w) or S.w, (o and o.h) or S.h, (o and o.len) or 18, (o and o.life) or S.life
		for _ = 1, n do
			local sx, sy, l = x + (random() - 0.5) * w, y - random() * h, len * (0.5 + random())
			add(life * (0.6 + random() * 0.6), function(ctx, k)
				ctx:style(if k < 0.5 then tone.l else tone.n)
				ctx:rect(R(sx - dir * k * S.slide - (if dir > 0 then l * (1 - k) else 0)), R(sy), max(1, R(l * (1 - k))), 1)
			end, { delay = random() * S.delay })
		end
	end

	function api.update(dt: number)
		for i = #list, 1, -1 do
			local f = list[i]
			f.t += dt
			if f.t >= f.life then
				table.remove(list, i)
			end
		end
		for i = #parts, 1, -1 do
			local p = parts[i]
			p.t += dt
			if p.t < 0 then
				continue
			end
			p.vy += p.g * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.rot += p.vr * dt
			if p.t >= p.life then
				table.remove(parts, i)
			end
		end
	end

	function api.draw(ctx, back: boolean)
		for _, f in list do
			if f.back == back and f.t >= 0 then
				f.draw(ctx, f.t / f.life)
			end
		end
		if back then
			return
		end
		for _, p in parts do
			if p.t < 0 then
				continue
			end
			local k = p.t / p.life
			ctx:style(p.c)
			if p.kind == "dot" then
				if k < 0.8 or floor(p.t * 30) % 2 == 1 then
					ctx:rect(R(p.x), R(p.y), p.size, p.size)
				end
			elseif p.kind == "plus" then
				ctx:rect(R(p.x) - 1, R(p.y), 3, 1)
				ctx:rect(R(p.x), R(p.y) - 1, 1, 3)
			elseif p.kind == "petal" then
				local s = if k < 0.6 then 2 else 1
				ctx:rect(R(p.x) - s, R(p.y), s * 2 + 1, 1)
				ctx:rect(R(p.x), R(p.y) - s, 1, s * 2 + 1)
				if s > 1 then
					ctx:rect(R(p.x) - 1, R(p.y) - 1, 3, 3)
				end
			elseif p.kind == "bar" then
				line(ctx, p.x, p.y, p.x - p.vx * 0.04, p.y - p.vy * 0.04, p.c)
			else
				local s = p.size * (if k < 0.7 then 1 else (1 - k) / 0.3 + 0.3)
				local x0, y0 = p.x + cos(p.rot) * s, p.y + sin(p.rot) * s
				local x1, y1 = p.x + cos(p.rot + 2.094) * s, p.y + sin(p.rot + 2.094) * s
				local x2, y2 = p.x + cos(p.rot + 4.188) * s, p.y + sin(p.rot + 4.188) * s
				line(ctx, x0, y0, x1, y1, p.c)
				line(ctx, x1, y1, x2, y2, p.c)
				line(ctx, x2, y2, x0, y0, p.c)
			end
		end
	end

	-- 남아 있는 것이 있는가(없으면 그림판을 건드리지 않는다)
	function api.busy(): boolean
		return #list > 0 or #parts > 0
	end

	return api
end

return Fx
