-- 리틀 리퍼 — 낫. 핵심 장치: 영혼(쓰러뜨리거나 수확 기술을 맞히면 구슬이 몸 둘레를 돈다 · 일부 기술이 태워 쓴다).
--  공방 시험 탭의 dino-workshop/js/lune/kits/reaper.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   영혼 다섯까지(1차) → 여덟까지(영혼 주머니)
--   도깨비불: 2초에 한 번 하나(1차) → 영혼이 많을수록 여러 발 · 넷까지(떼도깨비불) → 맞은 적에게 3초 동안 붙어 태운다(붙는 불) → 1초에 한 번(원혼)
--  시험판은 영혼 셋을 갖고 시작한다(보여 주려고) — 게임은 0에서 시작한다.
--  옮기며 바뀐 이름: end → finish · until → till.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local crescentPts, starPts, poly, disc, oval, line = Fx.crescentPts, Fx.starPts, Fx.poly, Fx.disc, Fx.oval, Fx.line
local dash, buff, coilBind, bindCast = Common.dash, Common.buff, Common.coilBind, Common.bindCast
local floor, sin, cos, min, max, abs, ceil, PI = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.ceil, math.pi
local function R(v: number): number
	return floor(v + 0.5)
end

local function gain(g, n: number)
	g.s.souls = min(if g.sk("rp_soul2") > 0 then 8 else 5, g.s.souls + n)
end
local function spend(g, n: number) -- 사신화 동안은 줄지 않는다
	if not g.has("rp_form") then
		g.s.souls = max(0, g.s.souls - n)
	end
end
local DARK = { w = 0x232931, l = 0x12161c, n = 0xb11fa5, d = 0x12161c }

-- 도깨비불 한 발(사출기 — 1차에 배우고 2~4차 패시브가 강화한다): 꼬리를 끌며 흔들흔들 날아가 치고, (붙는 불부터) 붙어서 3초 동안 태운다.
--  i = 몇째 발(0부터) · n = 한 번에 나가는 수 · o.land = 닿은 순간에 부를 것
local function wisp(g, t, i: number, n: number, o)
	g.after(i * 0.05, function()
		g.shot({
			x = (o and o.sx) or (g.x + (i - n / 2) * 6),
			y = (o and o.sy) or (g.y - 20 - (i % 2) * 6),
			target = t,
			speed = 180,
			curl = 110,
			trail = {},
			update = function(p)
				table.insert(p.trail, { p.x, p.y })
				if #p.trail > 5 then
					table.remove(p.trail, 1)
				end
			end,
			draw = function(ctx, p)
				for k, q in p.trail do
					ctx:style(if k <= 2 then g.tone.d else g.tone.n)
					ctx:rect(R(q[1]), R(q[2]), 1, 1)
				end
				disc(ctx, p.x, p.y, 2, g.tone.n)
				ctx:style(g.tone.w)
				ctx:rect(R(p.x), R(p.y), 1, 1)
			end,
			onReach = function(p)
				g.hurt(t, 3, { proc = true })
				g.fx.pop(p.x, p.y, g.tone, { r = 4 })
				if o and o.land then
					o.land()
				end
				if g.sk("rp_wisp3") > 0 then
					for k = 1, 3 do
						g.after(k, function()
							if t.dead >= 0 then
								return
							end
							g.hurt(t, 1, { proc = true, quiet = true })
							g.fx.shards(t.x, t.y - t.h - 8, 2, g.tone, { kind = "petal", up = 50, speed = 14, grav = 0, life = 0.5 })
						end)
					end
				end
			end,
		})
	end)
end
-- 낫질이 맞았다: 가까운 적들에게 도깨비불을 보낸다(영혼 수만큼 — 넷까지)
local function wisps(g, from)
	local n = if g.sk("rp_wisp2") > 0 then min(4, 1 + floor(g.s.souls / 2)) else 1
	local list = {}
	for _, m in g.mobs() do
		if abs(m.x - from.x) < 160 then
			list[#list + 1] = m
		end
	end
	table.sort(list, function(a, b)
		return abs(a.x - from.x) < abs(b.x - from.x)
	end)
	for i = 0, n - 1 do
		local t = list[i % max(1, #list) + 1]
		if not t then
			return
		end
		g.call("wisp", t, i, n)
	end
end

local function advent(g)
	local x, y, dir, tone, souls = g.x, g.y - 16, g.dir, g.tone, g.s.souls
	spend(g, souls)
	g.invert(0.1)
	g.shake(8, 0.45)
	g.fx.slash(x, y, dir, 120, -28, 208, tone, { thick = 22, life = 0.42 })
	g.fx.slash(x, y, dir, 84, -20, 200, tone, { thick = 10, life = 0.5 })
	g.fx.shards(x, y, 26, tone, { speed = 200, up = 60, kind = "mix", life = 0.8 })
	for _, m in g.hitAt(x, g.y, 126, 70, 14 + souls * 3, { lift = 220 }) do
		g.fx.rise(m.x, m.y - 6, 9, tone, { life = 1.2 })
	end
end

-- 저승문: 허공에 뚫린 검은 구멍(블랙홀) — 둘레가 어두워지고, 칠흑 같은 속을 빛의 테가 두르고, 굵은 소용돌이 팔이 감겨 들며, 사방의 빛줄기와 땅의 돌 부스러기가 휘어 빨려 든다
local function drawGate(ctx, p, tone)
	local t = p.t
	local open, shut = min(1, t * 3), min(1, (p.life - t) * 4)
	local s = (1 - (1 - open) * (1 - open)) * shut
	local x, gy = R(p.x), R(p.y)
	local cy, RR, beat = gy - 31 + R(sin(t * 2.4) * 1.5), R(12 * s), max(0, 1 - (t % 0.5) / 0.22)
	if open < 1 then -- 허공이 세로로 찢기며 열린다
		local h = R(26 * (1 - open))
		ctx:style(tone.w)
		ctx:rect(x - 1, cy - h, 2, h * 2)
		ctx:style(tone.l)
		ctx:rect(x - 2, cy - floor(h / 2), 4, h)
	end
	if s < 0.05 then
		return
	end
	local function put(px, py, w, c)
		if py + w / 2 > gy then
			return
		end
		ctx:style(c)
		ctx:rect(R(px - w / 2), R(py - w / 2), w, w)
	end
	-- 둘레가 어두워지고 자줏빛이 번진다
	ctx:alpha(0.34 * s)
	disc(ctx, x, cy, RR + 17, 0x0b0e13)
	ctx:alpha(0.3 * s)
	disc(ctx, x, cy, RR + 9, tone.d)
	ctx:alpha(0.34 * s)
	disc(ctx, x, cy, RR + 5, tone.n)
	ctx:alpha(1)
	-- 땅에 진 그늘
	ctx:alpha(0.4 * s)
	ctx:style(0x0b0e13)
	ctx:rect(x - 22, gy, 44, 1)
	ctx:rect(x - 15, gy + 1, 30, 1)
	ctx:alpha(1)
	for arm = 0, 5 do -- 소용돌이: 굵은 팔 셋 + 사이의 어두운 팔 셋(끊기지 않게 한 점씩 이어 찍는다)
		local main = arm % 2 == 0
		local n = if main then 60 else 40
		local r, a = RR + 1, -t * (if main then 3.6 else 2.7) + arm * 1.0472
		for j = 0, n - 1 do
			local u = j / n
			local w = if main then (if u < 0.4 then 3 else 2) else (if u < 0.65 then 2 else 1)
			local c = if main then (if u < 0.16 then tone.w elseif u < 0.42 then tone.l elseif u < 0.75 then tone.n else tone.d) else (if u < 0.3 then tone.n else tone.d)
			put(x + cos(a) * r, cy + sin(a) * r, w, c)
			a += 1.05 / r
			r += 0.3 * s
		end
	end
	for i = 0, 13 do -- 빨려 드는 빛줄기: 중심을 향해 곧게, 가까울수록 굵고 밝다(둘레를 따라 늘어서지 않게 한다)
		local raw = t * 0.9 + i * 0.0714 + (i % 3) * 0.13
		local u, a0 = raw % 1, i * 2.4 + floor(raw) * 1.7
		local function pos(v)
			local r, a = RR + 3 + (1 - v) * (1 - v) * 44, a0 + v * 0.7
			return x + cos(a) * r, cy + sin(a) * r
		end
		local x0, y0 = pos(u)
		local x1, y1 = pos(min(1, u + 0.05))
		if u < 0.2 or y0 > gy - 1 or y1 > gy - 1 then
			continue
		end
		line(ctx, x0, y0, x1, y1, if u < 0.45 then tone.n elseif u < 0.75 then tone.l else tone.w, 2)
	end
	for i = 0, 6 do -- 땅에서 떠올라 빨려 드는 돌 부스러기
		local u, sx = (t * 0.55 + i / 7) % 1, x + (((i * 37) % 61) - 30)
		local w = if u < 0.6 then 2 else 1
		ctx:style(if i % 2 == 1 then 0x2f3742 else 0x56657a)
		ctx:rect(R(sx + (x - sx) * u * u), R(gy - 2 - u * u * (gy - cy - RR)), w, w)
	end
	-- 빛의 테와 칠흑 같은 속
	disc(ctx, x, cy, RR + 2, tone.n)
	disc(ctx, x, cy, RR + 1, tone.w)
	disc(ctx, x, cy, RR, 0x07090d)
	if beat > 0 then -- 맥박(0.5초마다 끌어당기며 친다): 테가 한 번 부푼다
		local r = RR + 3 + (1 - beat) * 6
		ctx:alpha(beat)
		local a = 0
		while a < 6.2832 do
			put(x + cos(a) * r, cy + sin(a) * r, 2, if beat > 0.5 then tone.w else tone.l)
			a += 0.9 / r
		end
		ctx:alpha(1)
	end
end

local skills = {
	{ id = "rp_double", key = "Q", shot = 0.5, segs = { { clip = "dslash", fps = 20, ev = {
		[3] = function(g)
			g.fx.slash(g.fwd(2), g.y - 10, g.dir, 32, -30, 70, g.tone, { thick = 6 })
			g.hit(-6, 44, 30, 4, 3, { kb = 40 })
		end,
		[9] = function(g)
			g.fx.slash(g.fwd(2), g.y - 10, g.dir, 36, 80, -35, g.tone, { thick = 7 })
			g.hit(-6, 48, 30, 4, 4, { kb = 90, stop = 0.04 })
		end,
	} } } },
	{ id = "rp_hook", key = "A", shot = 0.42, segs = { { clip = "slash", fps = 16, ev = { -- 갈고리 모양의 짧은 호 + 당기는 가는 줄
		[4] = function(g)
			local m = g.nearest(64, { front = true })
			local tx = if m then m.x else g.fwd(50)
			g.fx.cut((g.x + tx) / 2, g.y - 9, abs(tx - g.x), 0, g.tone, { th = 1, life = 0.18 })
			g.fx.slash(tx + g.dir * 6, g.y - 10, -g.dir, 10, -70, 100, g.tone, { thick = 4, life = 0.2 })
			g.hit(8, 64, 26, 4, 3, { pull = 170 })
		end,
		[6] = function(g)
			g.fx.slash(g.fwd(2), g.y - 10, g.dir, 24, 70, -30, g.tone, { thick = 5 })
			g.hit(-4, 44, 26, 4, 4, { stop = 0.04 })
		end,
	} } } },
	{ id = "rp_throw", key = "W", shot = 0.62, segs = { { clip = "slash", fps = 16, ev = { [5] = function(g) -- 도는 낫이 그리는 둥근 자국이 오가며 남는다
		local x0, dir, tone = g.fwd(12), g.dir, g.tone
		g.shot({
			x = x0,
			y = g.y - 10,
			life = 0.9,
			w = 22,
			h = 22,
			dmg = 5,
			o = {},
			every = { 0.07, function(p)
				g.fx.add(0.2, function(ctx, k)
					oval(ctx, p.lx, p.ly, 10, 10, if k < 0.5 then tone.n else tone.d, 1, 2)
				end)
			end },
			update = function(p)
				local k = p.t / p.life
				p.lx, p.ly = p.x, p.y
				p.x = x0 + dir * 135 * sin(PI * k)
				if k > 0.5 and not p.turned then
					p.turned = true
					table.clear(p.hitSet)
				end
			end,
			draw = function(ctx, p)
				local a = p.t * 900
				poly(ctx, crescentPts(p.x, p.y, 10, 6, a, a + 200, 1, 6), tone.l)
				poly(ctx, crescentPts(p.x, p.y, 10, 2.5, a + 20, a + 180, 1, 5), tone.w)
			end,
		})
	end } } } },
	{ id = "rp_ambush", key = "S", ground = true, shot = 0.78, segs = {
		{ clip = "sink", from = 0, to = 13, fps = 28, float = true },
		{ clip = "drop", from = 9, to = 22, fps = 20, float = true, start = function(g)
			local m = g.nearest(140)
			g.teleport(if m then m.x - g.dir * 4 else g.fwd(70))
		end, ev = { [14] = function(g)
			g.fx.ring(g.x, g.y, 6, 44, g.tone)
			g.fx.slash(g.x - g.dir * 6, g.y - 4, g.dir, 34, 170, -10, g.tone, { thick = 8, life = 0.28 })
			g.fx.shards(g.x, g.y - 4, 14, g.tone, { up = 130, kind = "mix" })
			g.hit(-34, 38, 40, 4, 7, { lift = 180, stop = 0.08 })
			g.shake(1, 0.1)
		end } },
	} },
	{ id = "rp_reap", key = "Z", shot = 0.44, segs = { { clip = "slash", fps = 13, ev = {
		[1] = function(g) -- 앞쪽의 적을 끌어당긴다: 빨려 드는 줄
			local x0, d0, tone = g.x, g.dir, g.tone
			for i = 0, 8 do
				local d, yy = 40 + i * 11, R(g.y - 3 - (i % 4) * 5)
				g.fx.add(0.3, function(ctx, k)
					ctx:style(if k < 0.5 then tone.l else tone.n)
					local x, l = x0 + d0 * d * (1 - k), max(1, R(12 * (1 - k)))
					ctx:rect(R(if d0 > 0 then x else x - l), yy, l, 1)
				end, { delay = i * 0.02 })
			end
			g.hit(16, 130, 34, 8, 0, { pull = 330 })
		end,
		[5] = function(g)
			g.fx.slash(g.fwd(0), g.y - 10, g.dir, 38, -35, 120, g.tone, { thick = 9, life = 0.3 })
			local hs = g.hit(-8, 50, 34, 4, 5, { kb = 30, stop = 0.06 })
			for _, m in hs do
				g.fx.rise(m.x, m.y - 6, 5, g.tone)
			end
			if #hs > 0 then
				gain(g, 1)
			end
		end,
	} } } },
	buff("rp_chill", "1"),
	{ id = "rp_drag", key = "E", shot = 0.72, segs = {
		{ clip = "dash", loop = true, dur = 0.5, fps = 26, float = true, trail = true, start = function(g)
			g.move(250, 0.5)
		end, every = { 0.03, function(g) -- 걸린 적을 끌고 간다 · 바닥을 긁는 자국
			for _, m in g.mobs() do
				if not m.boss and (m.x - g.x) * g.dir > -6 and (m.x - g.x) * g.dir < 24 and abs(m.y - g.y) < 20 then
					g.drag(m, g.x + g.dir * 16)
				end
			end
			local x, y, tone = R(g.x - g.dir * 6), R(g.y) - 1, g.tone
			g.fx.add(0.4, function(ctx, k)
				ctx:style(if k < 0.4 then tone.l else tone.n)
				ctx:rect(x - 4, y, 8, 1)
			end, { back = true })
		end } },
		{ clip = "slash", fps = 22, ev = { [5] = function(g)
			g.fx.slash(g.fwd(4), g.y - 6, g.dir, 34, -40, 130, g.tone, { thick = 9, life = 0.28 })
			g.hit(-6, 46, 40, 4, 8, { lift = 230, stop = 0.05 })
		end } },
	} },
	{ id = "rp_judge", key = "D", shot = 0.62, segs = { { clip = "slash", fps = 12, ev = { [2] = function(g) -- 적 머리 위 표시점 → 세로로 떨어지는 낫 모양 셋
		local m = g.boss() or g.nearest(260)
		if not m then
			return
		end
		local top = if m.boss then 44 else 28
		g.fx.pop(m.x, m.y - m.h - top, g.tone, { r = 6, life = 0.3 })
		for i = 0, 2 do
			g.after(0.14 + i * 0.16, function()
				if m.dead >= 0 then
					return
				end
				local x = m.x + (i - 1) * 5
				g.fx.cut(x, m.y - m.h - 46, 76, 90, g.tone, { th = 3, life = 0.18 })
				g.fx.slash(x - 6, m.y - m.h - 6, 1, 12, 200, 340, g.tone, { thick = 5, life = 0.2 })
				g.fx.ring(m.x, m.y, 2, 14, g.tone, { life = 0.2 })
				g.hurt(m, 9, { stop = if i == 2 then 0.05 else 0 })
			end)
		end
	end } } } },
	{ id = "rp_ghost", key = "X", instant = true, shot = 2.0, can = function(g)
		return g.s.souls >= 3
	end, cast = function(g) -- 망령: 어두운 실루엣이 따라다니며 벤다(눈은 그리지 않는다)
		spend(g, 3)
		local tone, x0 = g.tone, g.x - g.dir * 24
		g.fx.aura(x0, g.y, tone, { r = 12, h = 30 })
		g.fx.rise(x0, g.y, 10, tone, { w = 14 })
		g.shot({ x = x0, y = g.y, life = 60, at = 1, sw = 0, face = g.dir, summon = "rp_ghost", update = function(p, dt)
			p.x += (g.x - g.dir * 26 - p.x) * min(1, dt * 4)
			p.y = g.y
			p.sw = max(0, p.sw - dt)
			p.at += dt
			if p.at > 1.6 then
				local m = g.nearest(70, { from = p.x })
				if m then
					p.at, p.sw = 0, 0.35
					p.face = if m.x > p.x then 1 elseif m.x < p.x then -1 else 1
					g.fx.slash(p.x, p.y - 9, p.face, 26, -30, 70, tone, { thick = 5 })
					g.hurt(m, 5, { proc = true })
				end
			end
		end, draw = function(_ctx, p)
			local c, k = if p.sw > 0 then "dslash" else "idle", min(1, p.t * 3)
			g.sprite(c, if p.sw > 0 then 3 + floor((0.35 - p.sw) * 12) else floor(p.t * 8) % 9, p.x, p.y, if p.sw > 0 then p.face else g.dir, { color = 0x1b2028, alpha = 0.85 * k })
		end })
	end },
	buff("rp_ward", "2"),
	{ id = "rp_fade", key = "5", instant = true, shot = 0.3, cast = function(g)
		g.buff("rp_fade")
		g.fx.ring(g.x, g.y, 22, 6, g.tone, { life = 0.3 })
		g.fx.shards(g.x, g.y - 8, 8, g.tone, { kind = "dot", up = 40, speed = 30 })
	end },
	{ id = "rp_harvest", key = "R", shot = 0.34, segs = { { clip = "dslash", fps = 18, ev = {
		[3] = function(g) -- 화면 절반 길이의 납작한 초승달
			g.fx.slash(g.fwd(-10), g.y - 2, g.dir, 150, -6, 36, g.tone, { thick = 20, life = 0.34 })
			g.fx.slash(g.fwd(-10), g.y - 2, g.dir, 110, -4, 30, g.tone, { thick = 8, life = 0.4 })
			local hs = g.hit(-10, 160, 64, 4, 12, { kb = 60 })
			gain(g, min(3, #hs))
			g.shake(1, 0.1)
		end,
		[9] = function(g)
			g.fx.slash(g.fwd(-6), g.y - 2, g.dir, 90, 30, -6, g.tone, { thick = 10, life = 0.3 })
			g.hit(-10, 100, 50, 4, 6, { kb = 40 })
		end,
	} } } },
}

-- 참수: 세로로 긴 낫날 자국 + 한 박자 늦는 어두운 낫 그림자(영혼 하나를 태운다)
do
	local ev = {}
	for i, f in { 3, 6, 9 } do
		local n = i - 1
		ev[f] = function(g)
			local x = g.fwd(24) + (n - 1) * 3
			g.fx.cut(x, g.y - 26, 66, 90, g.tone, { th = 3, life = 0.18 })
			local hs = g.hit(0, 46, 60, 4, 8, { stop = 0.03 })
			if #hs > 0 and g.s.souls > 0 then
				spend(g, 1)
				g.after(0.12, function()
					g.fx.cut(x + 4, g.y - 26, 72, 96, DARK, { th = 5, life = 0.22 })
					for _, m in hs do
						g.hurt(m, 8, { proc = true })
					end
				end)
			end
		end
	end
	table.insert(skills, { id = "rp_behead", key = "F", shot = 0.44, segs = { { clip = "dslash", fps = 22, ev = ev } } })
end

local more = {
	{ id = "rp_form", key = "3", instant = true, shot = 0.5, cast = function(g)
		g.buff("rp_form")
		g.shake(3, 0.25)
		g.fx.aura(g.x, g.y, g.tone, { r = 24, h = 44 })
		g.fx.rise(g.x, g.y, 18, g.tone, { w = 50, life = 1.1 })
	end },
	{ id = "rp_advent", key = "G", shot = 1.14, segs = { { clip = "skill", fps = 13, float = true, start = function(g)
		g.dim(0.62, 2.1)
		g.fx.rise(g.x, g.y, 18, g.tone, { w = 60, life = 1.3 })
	end, ev = { [14] = advent, [16] = function(g)
		g.fx.ring(g.x, g.y, 20, 130, g.tone, { life = 0.5 })
		g.hitAt(g.x, g.y, 126, 70, 4, {})
	end } } } },
	{ id = "rp_chains", key = "B", shot = 1.0, segs = { { clip = "slash", fps = 14, ev = { [5] = function(g) -- 저승의 기운이 사슬처럼 휘감아 묶는다
		g.shake(3, 0.15)
		g.fx.ring(g.x, g.y, 6, 150, g.tone, { squash = 0.12, life = 0.45 })
		for _, m in g.mobs() do
			if abs(m.x - g.x) < 150 and abs(m.y - g.y) < 40 and g.bind(m, 10, "coil") then
				bindCast(g, m)
			end
		end
	end } } } },
	{ id = "rp_gate", key = "C", shot = 1.5, segs = { { clip = "slash", fps = 14, ev = { [5] = function(g)
		local tone, x, y = g.tone, g.fwd(52), g.y
		g.fx.cut(x, y - 31, 56, 90, tone, { th = 4, life = 0.3 }) -- 낫으로 허공을 가른다
		g.fx.shards(x, y - 31, 10, tone, { kind = "tri", speed = 90, up = 20 })
		g.shake(2, 0.15)
		g.s.gate = g.shot({
			x = x,
			y = y,
			life = 10,
			back = true,
			tick = 0.5,
			w = 70,
			h = 40,
			dmg = 2,
			o = { proc = true },
			update = function(p, dt)
				for _, m in g.mobs() do
					if not m.boss and m.bind <= 0 and abs(m.x - p.x) < 120 and abs(m.x - p.x) > 4 then
						g.drag(m, m.x + (if p.x > m.x then 1 else -1) * 46 * dt)
					end
				end
			end,
			finish = function(p) -- 닫힐 때: 한 점으로 오므라들었다가 별빛으로 터진다
				local cy = p.y - 31
				g.fx.add(0.22, function(ctx, k)
					poly(ctx, starPts(p.x, cy, 22 * (1 - k), k * 1.2), if k < 0.4 then tone.w else tone.l)
				end)
				g.fx.shards(p.x, cy, 14, tone, { kind = "mix", speed = 120, up = 30 })
			end,
			draw = function(ctx, p)
				drawGate(ctx, p, tone)
			end,
		})
	end } } } },
	{ id = "rp_wisp", key = "T" }, -- 사출기: 켜고 끈다(판정은 아래 onHit)
	dash("rp_dash", "dash", 11, 250, 125),
}
for _, s in more do
	table.insert(skills, s)
end
for _, s in Common.commons do
	table.insert(skills, s)
end

local reaper = {
	tone = "pink",
	toggle = "rp_wisp",
	icons = { c_hero = "moon", rp_wisp = "flame", rp_chill = "haste", rp_ward = "up", rp_fade = "shield", rp_form = "scythe" },
	init = function(g)
		g.s = { souls = 0, wispAt = -9, gate = nil }
	end,
	haste = function(g)
		return if g.has("rp_chill") then 1.25 else 1
	end,
	mult = function(g)
		return 1 + g.s.souls * 0.03 + (if g.has("rp_form") then 0.3 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	dim = function(g)
		return if g.has("rp_form") then 0.25 else 0
	end,
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or o.proc then
			return
		end
		if g.sk("rp_drain") > 0 and g.rnd() < 0.2 then
			g.call("drain") -- 생기 흡수
		end
		if g.has("rp_form") then
			g.call("shade", m, dmg) -- 그림자 낫이 따라 벤다
		end
		if g.toggle and g.clock - g.s.wispAt > (if g.sk("rp_wisp4") > 0 then 1 else 2) then
			g.s.wispAt = g.clock
			wisps(g, m)
		end
	end,
	onKill = function(g, m)
		local gate = g.s.gate
		local near = gate ~= nil and gate.t < gate.life and abs(gate.x - m.x) < 70
		gain(g, if near then 2 else 1)
		g.call("soul", m, near)
	end,
	tick = function(g)
		g.hero.alpha = if g.has("rp_fade") then 0.4 else 1
	end,
	drawBack = function(ctx, g)
		if g.has("rp_form") then
			g.sprite("skill", 10, g.x, g.y, g.dir, { color = 0x12161c, alpha = 0.8 }) -- 사신화: 등 뒤에 선 사신 그림자(시트의 그림)
		end
		if g.has("rp_fade") then -- 저승 걸음: 발밑의 어두운 웅덩이
			ctx:alpha(0.6)
			ctx:style(0x12161c)
			for dy = -2, 2 do
				ctx:rect(R(g.x) - 14 + abs(dy) * 3, R(g.y) + dy, 28 - abs(dy) * 6, 1)
			end
			ctx:alpha(1)
		end
	end,
	draw = function(ctx, g) -- 몸 둘레를 도는 영혼 구슬(핵심 장치)
		local n = g.s.souls
		for i = 0, n - 1 do
			local a = g.clock * 2.4 + (i * 6.283) / n
			local x, y = R(g.x + cos(a) * 14), R(g.y - 11 + sin(a) * 5)
			ctx:style(g.tone.n)
			ctx:rect(x - 1, y, 3, 1)
			ctx:rect(x, y - 1, 1, 3)
			ctx:style(g.tone.w)
			ctx:rect(x, y, 1, 1)
		end
	end,
	drawBind = coilBind,
	-- 서버가 정해 화면에 알리는 것(g.call)
	calls = {
		wisp = wisp,
		drain = function(g)
			g.fx.rise(g.x, g.y - 4, 2, g.tone, { w = 8, life = 0.5 })
		end,
		shade = function(g, m, dmg)
			g.after(0.12, function()
				if m.dead >= 0 then
					return
				end
				g.fx.cut(m.x + 3, m.y - m.h - 12, 36, 70, DARK, { th = 4, life = 0.2 })
				g.hurt(m, ceil(dmg * 0.5), { proc = true })
			end)
		end,
		soul = function(g, m, near)
			g.fx.rise(m.x, m.y - 6, if near then 8 else 4, g.tone, { life = 0.9 })
		end,
	},
	-- 지금의 서버(1차 — sim/kit.luau)가 알리는 따로 나가는 타. o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것) }
	procs = {
		-- o.i = 몇째 발 · o.n = 한 번에 나간 수(떼도깨비불)
		wisp = function(g, m, o)
			wisp(g, m, o.i or 0, o.n or 1, o)
		end,
	},
	skills = skills,
}

return reaper
