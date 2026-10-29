-- 리틀 리븐 — 창. 핵심 장치: 표식(베기에 맞은 적에게 쌓이고, 순보 계열이 터뜨린다 · 표식 있는 적은 초마다 독).
--  공방 시험 탭의 dino-workshop/js/lune/kits/riven.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   표식 1(1차) → 3까지 겹친다(깊은 표식) · 스미는 독(3차 패시브)
--   그림자 표창: 40%로 하나(1차) → 둘(쌍표창) → 맞힌 뒤 한 번 튕긴다(되돌아오는 표창) → 70% · 표식이 가득한 적에게 터진다(피의 표창)
--   분신 하나(그림자 분신) → 둘(쌍영)
--  옮기지 않은 것: hud(월식 동안 하늘의 달을 검게 가린다 — 시험 맵의 달 자리에 맞춘 그림이라 맵마다 달 자리가 다른 게임에는 맞지 않는다. 어두워지는 것은 dim으로 그대로다).
--  옮기며 바뀐 이름: end → finish · until → till.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local COMBAT = require(script.Parent.Parent.data["combat.generated"]) -- 연쇄 순보의 레벨마다의 거리(moveCast — 2026-10-24)
local poly, disc, starPts, line, crescentPts = Fx.poly, Fx.disc, Fx.starPts, Fx.line, Fx.crescentPts
local dash, buff = Common.dash, Common.buff
local floor, sin, cos, min, max, abs, ceil = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.ceil
local R = Fx.R -- 반올림(그림의 점 자리)

local riven

local function mark(g, m, n: number?)
	if m.dead >= 0 then
		return
	end
	local cap = if g.sk("rv_mark2") > 0 then 3 else 1
	m.mark = min(cap, m.mark + (n or 1) * (if g.has("rv_eclipse") then 2 else 1))
	m.markT = 8
end
local function burst(g, m)
	g.fx.cut(m.x, m.y - m.h - 8, 34, 40, g.tone)
	g.fx.cut(m.x, m.y - m.h - 8, 34, -40, g.tone, { delay = 0.05 })
	g.fx.shards(m.x, m.y - m.h - 8, 6, g.tone, { kind = "mix" })
end
-- 화면의 표식을 모두 터뜨린다(표식 수만큼 세다)
local function detonate(g, per: number?)
	for _, m in g.mobs() do
		if m.mark > 0 then
			local k = m.mark
			m.mark = 0
			g.hurt(m, (per or 4) * k, { lift = 120 })
			burst(g, m)
		end
	end
end
-- 그림자 표창(사출기 — 1차에 배우고 2~4차 패시브가 강화한다): 표창이 날아가 표식을 남긴다. hop = 맞힌 뒤 다른 적에게 한 번 튕긴다. 표식이 가득한 적에게는 터진다
--  o.land = 닿은 순간에 부를 것(화면이 그 타의 피해 숫자를 이때 띄운다)
local function star(g, from, t, hop: boolean?, o)
	if not t then
		return
	end
	local tone = g.tone
	g.shot({
		x = from.x or g.x,
		y = from.y or (g.y - 12),
		target = t,
		speed = 280,
		curl = 70,
		draw = function(ctx, p)
			poly(ctx, starPts(p.x, p.y, 5, p.t * 22), tone.n)
			poly(ctx, starPts(p.x, p.y, 2.5, p.t * 22), tone.w)
		end,
		onReach = function(p)
			local full = t.mark >= 3 and g.sk("rv_star4") > 0
			g.hurt(t, if full then 5 else 2, { proc = true })
			mark(g, t)
			g.fx.pop(p.x, p.y, tone)
			if full then
				g.fx.shards(p.x, p.y, 5, tone, { kind = "tri", speed = 80 })
			end
			if o and o.land then
				o.land()
			end
			if hop then
				star(g, { x = p.x, y = p.y }, g.nearest(120, { from = t.x, ["not"] = t }), false)
			end
		end,
	})
end

local lance, chainSteps, cleaveRush -- (아래 도우미 — 스킬 표보다 먼저 이름만)
-- 그림자 창(3차 사냥기 — 2026-10-24 사용자 "사냥기는 새로 설계해서 넣어"): 그림자 창 넷이 높이를 조금씩 달리해(땅 · 위로 6 · 12 · 18도트) 앞 130도트까지 차례로 꿰뚫고 지나간다.
--  창마다 그 높이의 띠(앞 10 ~ 130 · 위 10 아래 6도트)에 든 적을 한 번씩 · 맞은 적에게 표식. 그림: 어두운 자루 · 민트 잎날 · 뒤에 남는 꼬리 · 끝에서 작은 섬광
--  범위를 줄였다(2026-10-24 사용자 "그림자창 범위 너무 넓어 3차스킬인데 조정하고"): 앞 190 → 130도트 · 높이 72 → 18도트(제 층만 — 위층의 적은 맞지 않는다). 4차 무영참(앞 4 ~ 164 · 높이 46)보다 좁다. 숫자는 제가 정한 것
local LANES = { 0, 6, 12, 18 }
local LANCE_REACH = 130
function lance(g)
	local x, y, dir, tone = g.x, g.y, g.dir, g.tone
	for i, up in LANES do
		local ly, delay = y - up, (i - 1) * 0.06
		g.after(delay, function()
			g.fx.add(0.26, function(ctx, k)
				local u = min(1, k / 0.55)
				local hx, tx, yy = x + dir * (10 + (LANCE_REACH - 10) * u), x + dir * (10 + (LANCE_REACH - 10) * max(0, u - 0.4)), R(ly - 9)
				ctx:alpha(if k < 0.55 then 1 else (1 - k) / 0.45)
				line(ctx, tx, yy, hx, yy, tone.n, 1) -- 꼬리
				line(ctx, hx - dir * 46, yy - 1, hx - dir * 13, yy - 1, tone.d, 3) -- 자루
				poly(ctx, { { hx + dir * 5, yy }, { hx - dir * 9, yy - 5 }, { hx - dir * 16, yy }, { hx - dir * 9, yy + 5 } }, tone.n) -- 잎날
				poly(ctx, { { hx + dir * 2, yy }, { hx - dir * 9, yy - 2 }, { hx - dir * 13, yy }, { hx - dir * 9, yy + 2 } }, tone.w)
				ctx:alpha(1)
			end)
		end)
		-- 맞는 띠 = 그 창이 그려진 높이(잎날의 위끝 = 창 높이 + 13점)부터 바닥(발밑 + 6점)까지 — 창이 몸을 지나가는 적은 모두 맞는다
		--  (2026-10-26 사용자: "그림자창 y축 범위가 이펙트랑 일치안해서 그런듯함" — 전에는 창 높이의 위 10 · 아래 6점이라 그림보다 6점 낮았고 맨 위 창의 그림(32점)에 닿지 않았다. 위층(32점 위)은 그대로 안 맞는다)
		g.after(delay + 0.08, function()
			g.hitAt(x + dir * (LANCE_REACH + 10) / 2, y, (LANCE_REACH - 10) / 2, up + 13, 4, { mark = true, stop = 0.03 })
		end)
		g.after(delay + 0.15, function()
			g.fx.shards(x + dir * LANCE_REACH, ly - 9, 3, tone, { kind = "bar", speed = 60, up = 10, life = 0.25 })
		end)
	end
end

-- 연쇄 순보(3차 이동기 — 2026-10-24 사용자 "리븐 3차스킬 연쇄순보는 쿨타임 5초 이동기로 재설계 … 마스터레벨 5짜리 이동기"): 피해는 없다.
--  앞으로 순간이동을 steps번 잇는다 — 순간이동마다 잔상 · 속도선 · 작은 연기. 거리(모두 합친 것)는 스킬 레벨마다(공방 combat.js의 MOVECAST → moveCast.dist)
function chainSteps(g)
	local mc = COMBAT.moveCast and COMBAT.moveCast.rv_chain
	local steps = if mc then mc.steps else 3
	local total = if mc then mc.dist[math.clamp(g.sk("rv_chain"), 1, #mc.dist)] else 90
	for i = 0, steps - 1 do
		g.after(i * 0.07, function()
			local x0 = g.x
			g.ghost()
			g.fx.shards(x0, g.y - 8, 4, g.tone, { kind = "dot", up = 40, speed = 30, life = 0.3 })
			g.teleport(g.fwd(total / steps))
			g.fx.streaks((x0 + g.x) / 2, g.y - 6, 5, -g.dir, g.tone, { w = max(8, abs(g.x - x0)) })
			g.fx.shards(g.x, g.y - 8, 3, g.tone, { kind = "dot", up = 30, speed = 20, life = 0.25 })
		end)
	end
end

-- 천지 가르기(4차 · 다시 쓰기 12초 · 맵 전체 — 2026-10-24 다시 만듦(2026-10-24 사용자 "천지가르기 리메이크할게 그냥 리븐이 엄청나게 빨리 이동하면서 … 광역기야" → 같은 날 "천지가르기 그림자난무처럼 베어 내는 이펙트를 빠르게 하는걸로하자")):
--  ① 연기 속으로 사라졌다가 ② 리븐이 좌우로 번갈아 여섯 번 내달린다(순간이동 0.05초마다 · 지난 자리마다 잔상) — 내달릴 때마다 그 길을 가로지르는 긴 벤 자국(그림자 난무의 벤 자국을 빠르게)
--  ③ 처음 자리로 돌아와 큰 X자 · 반전 섬광 ④ 내달리기 시작하는 순간 맵의 모든 적(층 · 거리와 상관없이)이 한꺼번에 맞고 표식 — 적마다 짧은 X자 벤 자국(그림만 차례로)
--  처음 것(번개)은 같은 날 벤 자국으로 바꿨다. 내달리는 거리 · 차례 · 각도는 제가 정한 것
local RUSH = { 150, -120, 190, -160, 110, 0 } -- 처음 자리에서 앞(+) · 뒤(−)로 몇 도트(마지막 0 = 처음 자리로 돌아온다)
local RUSH_ANG = { 18, -24, 8, -14, 30, -10 } -- 내달릴 때마다 긋는 벤 자국의 기울기(그림자 난무와 같은 결)
local RUSH_GAP = 0.05
function cleaveRush(g)
	local x0, y, dir, tone = g.x, g.y, g.dir, g.tone
	g.dim(0.5, 1.0)
	-- 판정은 여기 한 번: 맵의 모든 적 — 적마다 짧은 X자 벤 자국은 그림만 차례로
	for i, m in g.mobs() do
		g.hurt(m, 12, { mark = true, stop = 0.1 })
		local mx, my = m.x, m.y - (m.h or 16) / 2 - 4
		local t = min(0.4, (i - 1) * 0.025)
		g.fx.cut(mx, my, 40, 35, tone, { th = 3, life = 0.18, delay = t })
		g.fx.cut(mx, my, 40, -35, tone, { th = 3, life = 0.18, delay = t + 0.04 })
	end
	-- 좌우로 번갈아 내달린다: 지난 자리에 잔상 · 지나간 길을 가로지르는 긴 벤 자국
	for i, off in RUSH do
		g.after((i - 1) * RUSH_GAP, function()
			local ax = g.x
			g.ghost()
			g.teleport(x0 + dir * off)
			local bx = g.x
			if bx ~= ax then
				g.face(if bx > ax then 1 else -1)
			end
			g.fx.cut((ax + bx) / 2, y - 10, abs(bx - ax) + 70, RUSH_ANG[i], tone, { th = 4, life = 0.22 })
			g.fx.shards(bx, y - 10, 4, tone, { kind = "mix", speed = 60, life = 0.3 })
			g.shake(1, 0.05)
		end)
	end
	-- 처음 자리로 돌아왔다: 큰 X자 · 반전 섬광 · 흔들림
	g.after(#RUSH * RUSH_GAP, function()
		g.face(dir)
		g.invert(0.06)
		g.fx.cut(g.x, y - 10, 200, 35, tone, { th = 6, life = 0.3 })
		g.fx.cut(g.x, y - 10, 200, -35, tone, { th = 6, life = 0.3, delay = 0.04 })
		g.shake(4, 0.25)
	end)
end

local skills = {
	{ id = "rv_fan", key = "Q", shot = 0.4, segs = { { clip = "slash", fps = 20, ev = { [5] = function(g) -- 부채꼴로 퍼지는 가는 벤 자국 세 줄
		for _, a in { 16, 0, -16 } do
			g.fx.cut(g.fwd(44), g.y - 10 - a * 0.7, 80, a * g.dir, g.tone, { th = 2, life = 0.22 })
		end
		g.fx.streaks(g.fwd(40), g.y, 5, -g.dir, g.tone, { w = 70, h = 30 })
		g.hit(0, 88, 44, 6, 3, { mark = true })
	end } } } },
	{ id = "rv_double", key = "A", shot = 0.5, segs = { { clip = "dslash", fps = 22, ev = { -- 제자리에서 두 번 벤다
		[4] = function(g)
			g.fx.slash(g.fwd(4), g.y - 8, g.dir, 30, -25, 45, g.tone, { thick = 5 })
			g.hit(-4, 44, 24, 4, 2, { kb = 30, mark = true })
		end,
		[8] = function(g)
			g.fx.ring(g.x, g.y - 8, 6, 26, g.tone, { squash = 0.5, back = false, life = 0.2 })
			g.hit(-28, 28, 26, 4, 1, {})
		end,
		[10] = function(g)
			g.fx.slash(g.fwd(4), g.y - 8, g.dir, 34, 50, -25, g.tone, { thick = 6 })
			g.hit(-4, 48, 24, 4, 3, { kb = 80, mark = true })
		end,
	} } } },
	{ id = "rv_gale", key = "W", air = true, cd = 0.5, shot = 0.52, segs = { { clip = "slash", fps = 20, float = true, trail = true, start = function(g)
		g.s.from = g.x
	end, ev = {
		[3] = function(g)
			g.move(340, 0.2)
		end,
		[5] = function(g)
			g.after(0.2, function()
				local mid, len = (g.s.from + g.x) / 2, abs(g.x - g.s.from) + 30
				g.fx.cut(mid, g.y - 8, len, 0, g.tone, { th = 4, life = 0.26 })
				g.fx.streaks(mid, g.y - 2, 8, -g.dir, g.tone, { w = len })
				g.hitAt(mid, g.y, len / 2, 26, 4, { mark = true, stop = 0.04 })
			end)
		end,
	} } } },
	{ id = "rv_cross", key = "S", shot = 0.52, segs = { { clip = "dslash", fps = 22, ev = { -- 적 몸 위에서 교차하는 벤 자국 둘(제자리 — 물러나지 않는다)
		[4] = function(g)
			local m = g.nearest(54, { front = true })
			g.s.cx = if m then m.x else g.fwd(26)
			g.fx.cut(g.s.cx, g.y - 9, 34, 45, g.tone, { th = 4 })
			g.hit(0, 54, 30, 4, 5, { mark = true })
		end,
		[10] = function(g)
			g.fx.cut(g.s.cx, g.y - 9, 34, -45, g.tone, { th = 4 })
			g.hit(0, 54, 30, 4, 6, { mark = true, stop = 0.04 })
		end,
	} } } },
	{ id = "rv_step", key = "Z", shot = 0.42, segs = {
		{ clip = "smokeout", from = 0, to = 6, fps = 26, float = true },
		{ clip = "smokein", fps = 22, float = true, start = function(g)
			local m = g.nearest(130)
			if m then
				g.teleport(m.x + g.dir * 20)
				g.face(-g.dir)
			else
				g.teleport(g.fwd(80))
			end
			g.fx.streaks(g.x, g.y - 4, 6, g.dir, g.tone)
		end, ev = { [2] = function(g)
			g.fx.cut(g.x, g.y - 9, 70, 30, g.tone, { th = 4 })
			g.fx.cut(g.x, g.y - 9, 70, -30, g.tone, { th = 4, delay = 0.04 })
			g.hit(-36, 36, 28, 4, 4, { stop = 0.05 })
			detonate(g)
		end } },
	} },
	buff("rv_quick", "1"),
	{ id = "rv_lance", key = "E", shot = 0.5, segs = { { clip = "slash", fps = 20, ev = { [4] = function(g)
		lance(g)
	end } } } },
	{ id = "rv_chain", key = "V", air = true, shot = 0.35, segs = { -- 연쇄 순보(이동기): 연기 속으로 사라졌다가 앞으로 순간이동을 세 번 잇는다
		{ clip = "smokeout", from = 0, to = 5, fps = 30, float = true },
		{ clip = "smokein", fps = 26, float = true, start = chainSteps },
	} },
	{ id = "rv_flurry", key = "D", shot = 0.8, holdFor = 2, segs = {
		{ clip = "dslash", from = 0, to = 10, loopFrom = 4, fps = 40, hold = true, max = 3, min = 0.3, every = { 0.125, function(g) -- 앞에 겹겹이 쌓이는 짧은 벤 자국
			g.s.n += 1
			g.fx.cut(g.fwd(18 + g.rnd() * 16), g.y - 5 - g.rnd() * 13, 14 + g.rnd() * 12, (g.rnd() - 0.5) * 130, g.tone, { life = 0.12, th = 2 })
			g.hit(0, 46, 26, 4, 2, { mark = g.s.n % 4 == 0 })
		end } },
		{ clip = "dslash", from = 11, fps = 24 }, -- 떼면 동작을 끝까지 마무리한다
	} },
	buff("rv_clone", "2", function(g)
		g.ghost()
	end),
	{ id = "rv_smoke", key = "C", shot = 0.6, segs = { { clip = "cast", fps = 18, ev = { [2] = function(g) -- 바닥에 깔려 일렁이는 둥근 연기 덩이
		local SMOKE = { 0x2f3742, 0x393e46, 0x47546a }
		g.s.smoke = g.shot({ x = g.x, y = g.y, life = 8, draw = function(ctx, p)
			local k = min(1, p.t * 4, (p.life - p.t) * 2)
			ctx:alpha(0.8 * k)
			for i = 0, 8 do
				disc(ctx, p.x + (i - 4) * 9 + sin(p.t * 2 + i) * 3, p.y - 7 - (i % 3) * 5 + cos(p.t * 1.6 + i * 2) * 2, 7 + (i % 3) * 2, SMOKE[i % 3 + 1])
			end
			ctx:alpha(1)
		end })
	end } } } },
	{ id = "rv_slip", key = "5", instant = true, shot = 0.3, cast = function(g)
		g.buff("rv_slip")
		g.fx.streaks(g.x, g.y - 4, 8, g.dir, g.tone)
		g.fx.ring(g.x, g.y, 18, 4, g.tone, { life = 0.25 })
	end },
	{ id = "rv_phantom", key = "R", shot = 0.3, segs = { { clip = "slash", fps = 26, walk = 1, ev = { [5] = function(g) -- 허공에 제각각 기운 벤 자국 여섯이 한꺼번에
		local cx, cy = g.fwd(84), g.y - 14
		for i = 0, 5 do
			g.fx.cut(cx + (g.rnd() - 0.5) * 120, cy + (g.rnd() - 0.5) * 34, 50 + g.rnd() * 34, g.rnd() * 180, g.tone, { life = 0.22, th = 3, delay = i * 0.012 })
		end
		for _, t in { 0, 0.05, 0.1 } do
			g.after(t, function()
				g.hitAt(cx, g.y, 80, 46, 4, { mark = t == 0 })
			end)
		end
	end } } } },
}

-- 암살: 여섯 번 찌르고, 한 번 더 누르면 마무리 일격
do
	local ev = {}
	for i, f in { 2, 3, 4, 5, 6, 7 } do
		local n = i - 1
		ev[f] = function(g)
			g.fx.cut(g.fwd(20), g.y - 9 + (n - 2.5) * 3, 34, (n - 2.5) * 7 * g.dir, g.tone, { life = 0.1, th = 2 })
			g.hit(0, 44, 28, 4, 3, { mark = n % 2 == 0 })
		end
	end
	table.insert(skills, { id = "rv_kill", key = "F", shot = 0.86, segs = {
		{ clip = "dslash", fps = 30, ev = ev },
		{ clip = "slash", fps = 20, needPress = true, ev = { [5] = function(g) -- 마무리: 세로 큰 벤 자국 — 표식이 많을수록 세다
			g.fx.cut(g.fwd(24), g.y - 22, 96, 88, g.tone, { th = 6, life = 0.3 })
			g.shake(1, 0.1)
			for _, m in g.hit(0, 52, 60, 4, 0, {}) do
				local k = m.mark
				m.mark = 0
				g.hurt(m, 18 + k * 8, { stop = 0.08 })
				if k > 0 then
					burst(g, m)
				end
			end
		end } },
	} })
end

table.insert(skills, { id = "rv_cleave", key = "B", shot = 0.9, segs = { -- 천지 가르기(위 cleaveRush): 연기 속으로 사라졌다가 좌우로 내달리며 벤다
	{ clip = "smokeout", from = 0, to = 5, fps = 30, float = true },
	{ clip = "dslash", fps = 24, float = true, start = cleaveRush },
} })
table.insert(skills, { id = "rv_eclipse", key = "3", instant = true, shot = 0.6, cast = function(g)
	g.buff("rv_eclipse")
	g.fx.aura(g.x, g.y, g.tone, { r = 20, h = 34 })
	g.fx.ring(g.x, g.y - 9, 50, 6, g.tone, { squash = 1, back = false, life = 0.4 })
	g.shake(2, 0.2)
end })

-- 그림자 난무: 화면을 다섯 번 긋고 X자로 마무리한다
do
	local ANG = { 18, -24, 8, -14, 30 }
	local ev = {}
	for i, f in { 14, 18, 22, 26, 30 } do
		ev[f] = function(g)
			g.fx.cut(g.s.at, g.y - 10, 170, ANG[i], g.tone, { th = 4, life = 0.24 })
			g.fx.shards(g.s.at + (g.rnd() - 0.5) * 80, g.y - 10, 5, g.tone, { kind = "mix" })
			g.hitAt(g.s.at, g.y, 84, 44, 3, { mark = true })
			g.shake(2, 0.08)
		end
	end
	ev[31] = function(g)
		g.invert(0.07)
		g.shake(6, 0.3)
		g.fx.cut(g.s.at, g.y - 10, 190, 35, g.tone, { th = 6, life = 0.3 })
		g.fx.cut(g.s.at, g.y - 10, 190, -35, g.tone, { th = 6, life = 0.3, delay = 0.05 })
		g.fx.ring(g.s.at, g.y, 10, 90, g.tone)
		g.hitAt(g.s.at, g.y, 90, 50, 6, { lift = 200 })
		detonate(g, 6)
	end
	table.insert(skills, { id = "rv_shadow", key = "G", shot = 1.74, segs = { { clip = "special", fps = 18, float = true, start = function(g)
		g.dim(0.55, 2.0)
		g.s.at = g.x
	end, ev = ev } } })
end

table.insert(skills, {
	id = "rv_execute",
	key = "X",
	shot = 0.3,
	can = function(g)
		for _, m in g.mobs() do
			if m.mark > 0 then
				return true
			end
		end
		return g.boss() ~= nil
	end,
	segs = { { clip = "smokein", fps = 20, float = true, start = function(g)
		local t = nil
		for _, m in g.mobs() do
			if m.mark > 0 and abs(m.x - g.x) < 230 and (not t or m.mark > t.mark) then
				t = m
			end
		end
		t = t or g.boss()
		g.s.ex = t
		if t then
			g.teleport(t.x - g.dir * 12)
		end
	end, ev = { [2] = function(g) -- 표식이 한 점으로 빨려 들었다가 세로로 터진다
		local m = g.s.ex
		if not m or m.dead >= 0 then
			return
		end
		local k = m.mark
		m.mark = 0
		g.fx.ring(m.x, m.y - m.h - 8, 26, 3, g.tone, { squash = 1, back = false, life = 0.12 })
		g.fx.cut(m.x, m.y - m.h - 14, 76, 90, g.tone, { th = 6, life = 0.3, delay = 0.1 })
		g.fx.ring(m.x, m.y, 4, 30, g.tone, { delay = 0.1 })
		g.after(0.1, function()
			g.hurt(m, 20 + k * 8, { stop = 0.1 })
			g.shake(3, 0.15)
			if m.dead >= 0 then
				g.resetCd("rv_execute")
			end
		end)
	end } } },
})
table.insert(skills, { id = "rv_star", key = "T" }) -- 사출기: 켜고 끈다(판정은 아래 onHit)
table.insert(skills, dash("rv_dash", "dash", 4, 520, 57))
for _, s in Common.commons do
	table.insert(skills, s)
end

riven = {
	tone = "mint",
	toggle = "rv_star",
	icons = { c_hero = "moon", rv_star = "star", rv_quick = "haste", rv_clone = "twin", rv_slip = "shield", rv_eclipse = "eclipse" },
	init = function(g)
		g.s = { venom = 0, n = 0, smoke = nil }
	end,
	haste = function(g)
		return if g.has("rv_quick") then 1.25 else 1
	end,
	mult = function(g)
		return 1 + (if g.has("rv_eclipse") then 0.3 else 0) + (if riven.inSmoke(g) then 0.2 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	inSmoke = function(g)
		local s = g.s.smoke
		return s ~= nil and s.t < s.life and abs(s.x - g.x) < 40
	end,
	dim = function(g)
		return if g.has("rv_eclipse") then 0.42 else 0
	end,
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or o.proc then
			return
		end
		if o.mark then
			mark(g, m)
		end
		if g.has("rv_clone") then
			g.call("clone", m, dmg, o.mark == true) -- 분신이 반 박자 늦게 따라 벤다
		end
		if g.toggle and g.rnd() < (if g.sk("rv_star4") > 0 then 0.7 else 0.4) then
			g.call("star", g.nearest(150, { from = m.x, ["not"] = m }) or m, false)
			if g.sk("rv_star2") > 0 then
				g.call("star", m, true)
			end
		end
	end,
	tick = function(g, dt)
		g.s.venom += dt
		if g.s.venom >= 1 then -- 스미는 독
			g.s.venom = 0
			if g.sk("rv_venom") > 0 then
				for _, m in g.mobs() do
					if m.mark > 0 then
						g.hurt(m, m.mark, { proc = true, quiet = true })
						g.fx.shards(m.x, m.y - m.h - 6, 1, g.tone, { kind = "dot", up = 30, speed = 10, life = 0.5 })
					end
				end
			end
		end
		g.hero.sil = if g.has("rv_slip") then 0x14665f else nil
		g.hero.alpha = if g.has("rv_slip") then 0.75 elseif riven.inSmoke(g) then 0.6 else 1
	end,
	drawBack = function(_ctx, g) -- 그림자 분신: 내 모습 그대로의 민트색 실루엣이 뒤따른다
		-- 탈것을 탄 동안(2026-10-26 사용자 "리븐 캐릭터가 탈것을 탔을때 그림자 분신이 엄청나게 이상하게 나온다 … 리븐 그림자를 완전 별도 캐릭터처럼 따로 움직이게"):
		--  전에는 분신이 안장 위의 내 모습(서기)을 땅에서 그대로 따라 그려, 나는 탈것에 올라가 있는데 분신은 땅에 선 채 남았다.
		--  이제는 분신이 따로 걷는 그림자가 된다 — 탈것 뒤를 제 발로 뒤따라 달리고(늦게 따라붙는다) · 멈추면 선다. 내리면 다시 내 모습을 그대로 따른다
		if g.has("rv_clone") and g.riding then
			local s, now = g.s, g.clock
			local dt = min(0.1, now - (s.shadeT or now))
			s.shadeT = now
			s.shadeX = s.shadeX or {}
			for i = 0, if g.sk("rv_clone2") > 0 then 1 else 0 do
				local want = g.x - g.dir * (26 + i * 14)
				local was = s.shadeX[i] or want
				local x = was + (want - was) * min(1, dt * (5 - i))
				s.shadeX[i] = x
				local moving = abs(x - was) > dt * 6
				local clip = if moving then "run" else "idle"
				g.sprite(clip, floor(now * 10) % g.frames(clip), x, g.y, if moving then (if want > was then 1 else -1) else g.dir, { color = if i ~= 0 then 0x1fa89c else 0x3effd7, alpha = 0.5 - i * 0.15 })
			end
			return
		end
		g.s.shadeX = nil
		if g.has("rv_clone") and g.pose then
			for i = 0, if g.sk("rv_clone2") > 0 then 1 else 0 do
				g.sprite(g.pose.clip, g.pose.f, g.x - g.dir * (13 + i * 11), g.y, g.dir, { color = if i ~= 0 then 0x1fa89c else 0x3effd7, alpha = 0.5 - i * 0.15 })
			end
		end
	end,
	-- 서버가 정해 화면에 알리는 것(g.call)
	calls = {
		-- 표창 하나: low = 내 손에서(둘째 표창) · 아니면 몸에서. 튕기는 것은 되돌아오는 표창을 배웠을 때
		star = function(g, t, low)
			star(g, if low then { x = g.x, y = g.y - 6 } else {}, t, g.sk("rv_star3") > 0)
		end,
		clone = function(g, m, dmg, marks)
			g.after(0.15, function()
				if m.dead >= 0 then
					return
				end
				g.fx.cut(m.x, m.y - m.h - 8, 20, (g.rnd() - 0.5) * 120, g.tone, { life = 0.14, th = 2 })
				g.hurt(m, ceil(dmg * 0.4), { proc = true })
				if marks then
					mark(g, m)
				end
			end)
		end,
	},
	-- 지금의 서버(1차 — sim/kit.luau)가 알리는 따로 나가는 타. o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것) }
	procs = {
		-- o.hop = 앞의 표창이 맞힌 뒤 튕겨 온 것(조금 늦게 떠난다)
		star = function(g, m, o)
			local function go()
				star(g, { x = o.sx, y = o.sy }, m, false, o)
			end
			if o.hop then
				g.after(0.3, go)
			else
				go()
			end
		end,
		-- 그림자 분신이 반 박자 늦게 따라 벤 타(sim/room.luau의 skillHit — COMBAT.buffs.rv_clone)
		clone = function(g, m, o)
			g.fx.cut(m.x, m.y - m.h - 8, 20, (g.rnd() - 0.5) * 120, g.tone, { life = 0.14, th = 2 })
			o.land()
		end,
	},
	skills = skills,
}

return riven
