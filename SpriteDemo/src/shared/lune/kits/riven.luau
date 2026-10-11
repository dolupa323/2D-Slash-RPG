-- 리틀 리븐 — 창. 핵심 장치: 표식(베기에 맞은 적에게 쌓이고, 순보 계열이 터뜨린다 · 표식 있는 적은 초마다 독).
--  공방 시험 탭의 dino-workshop/js/lune/kits/riven.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   표식 1(1차) → 3까지 겹친다(깊은 표식) · 스미는 독(3차 패시브)
--   그림자 표창: 40%로 하나(1차) → 둘(쌍표창) → 맞힌 뒤 한 번 튕긴다(되돌아오는 표창) → 70% · 표식이 가득한 적에게 터진다(피의 표창)
--   분신 하나(그림자 분신) → 둘(쌍영)
--  옮기지 않은 것: hud(월식 동안 하늘의 달을 검게 가린다 — 시험 맵의 달 자리에 맞춘 그림이라 맵마다 달 자리가 다른 게임에는 맞지 않는다. 어두워지는 것은 dim으로 그대로다).
--  옮기며 바뀐 이름: end → finish · until → till.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local poly, disc, starPts = Fx.poly, Fx.disc, Fx.starPts
local dash, buff = Common.dash, Common.buff
local floor, sin, cos, min, max, abs, ceil = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.ceil

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
	{ id = "rv_chain", key = "E", shot = 0.45, segs = { { clip = "smokein", loop = true, dur = 0.72, float = true, fps = 30, start = function(g) -- 적과 적 사이를 잇는 꺾인 빛줄
		local list = {}
		for _, m in g.mobs() do
			if abs(m.x - g.x) < 180 and abs(m.y - g.y) < 50 then
				list[#list + 1] = m
			end
		end
		local gx = g.x
		table.sort(list, function(a, b)
			if a.mark ~= b.mark then
				return a.mark > b.mark
			end
			return abs(a.x - gx) < abs(b.x - gx)
		end)
		local px, py = g.x, g.y - 9
		for i = 0, min(#list, 5) - 1 do
			local m = list[i + 1]
			g.after(i * 0.12, function()
				if m.dead >= 0 then
					return
				end
				local side = if i % 2 == 1 then 1 else -1
				if g.teleport(m.x + side * 10) then
					g.face(-side)
				end
				g.fx.bolt(px, py, g.x, g.y - 9, g.tone)
				px = g.x
				g.fx.cut(m.x, m.y - m.h - 8, 28, 30 * side, g.tone, { th = 3 })
				g.hurt(m, 6, { mark = true })
				g.ghost()
			end)
		end
	end } } },
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
