-- 리틀 리퍼 — 낫. 핵심 장치: 영혼(쓰러뜨리거나 수확 기술을 맞히면 구슬이 몸 둘레를 돈다 · 일부 기술이 태워 쓴다).
--  공방 시험 탭의 dino-workshop/js/lune/kits/reaper.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   영혼 다섯까지(1차) → 여덟까지(영혼 주머니)
--   혼불(그 전 이름 도깨비불): 2초에 한 번 하나(1차) → 영혼이 많을수록 여러 발 · 넷까지(떼혼불) → 맞은 적에게 3초 동안 붙어 태운다(붙는 불) → 1초에 한 번(원혼)
--  2026-10-31 리퍼 리마스터(그림자 속의 사신 — 끌어모아 베어 쓰러뜨리고 → 넋과 피를 거두고 → 영혼이 가득 차면 사신의 일격): 처치 = 넋 거두기(harvestFx — 넋 · 피가 빨려 든다 ·
--   생기 흡수는 서버가 처치 때만) · 사신의 일격(procs.reap — 서버 room.luau Room:reaperKill) · 이중 낫질 둘째 타 = 끌어당김 · 회전 낫 → 망령 낫 · 단죄 · 대수확에 사신 그림자
--  시험판은 영혼 셋을 갖고 시작한다(보여 주려고) — 게임은 0에서 시작한다.
--  옮기며 바뀐 이름: end → finish · until → till.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local crescentPts, starPts, poly, disc, oval, line = Fx.crescentPts, Fx.starPts, Fx.poly, Fx.disc, Fx.oval, Fx.line
local dash, buff, coilBind, bindCast = Common.dash, Common.buff, Common.coilBind, Common.bindCast
local floor, sin, cos, min, max, abs, ceil, PI = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.ceil, math.pi
local COMBAT = require(script.Parent.Parent.data["combat.generated"]) -- 망령 돌진의 레벨마다의 거리(moveCast — 2026-10-25)
local hands, ghostRush, harvestFx, reaperShade, formSlash, drawSoul, summonGhost, ghostSwing -- (아래 도우미 — 스킬 표보다 먼저 이름만)
--  2026-10-31 게이지 직업(사용자: "메이플 루미너스 처럼 사신화가 1차부터 있고 사신 게이지가 있어 … 일반스킬이 사신스킬로 바뀌고 성능이 우수해지는거지 … 4차에서 변신하면 광역기 난사하는수준으로"):
--   g.s.gauge = 사신 게이지(서버 sim/kit.luau Kit.gainGauge가 채운다 — 화면은 받아 그린다) · 사신화(rp_form 버프) 동안 등 뒤에 사신 그림자(2026-11-01 몸이 커지던 것을 뺐다) ·
--   기술마다 칠흑의 큰 낫(formSlash) · 맞힐 때마다 그림자 낫(서버 room.luau → procs.shade). 영혼(souls) · 사신의 일격은 뺐다
local function R(v: number): number
	return floor(v + 0.5)
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
	local n = if g.sk("rp_wisp2") > 0 then min(4, 1 + (if g.has("rp_form") then 4 else floor((g.s.gauge or 0) / 34))) else 1 -- (떼혼불: 게이지 34마다 하나 더 · 사신화 동안 넷)
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
	local x, y, dir, tone, formed = g.x, g.y - 16, g.dir, g.tone, g.has("rp_form") -- 사신화 중에 쓰면 두 배(2026-10-31 — 그 전: 영혼을 모두 태워 그만큼)
	g.invert(0.1)
	g.shake(8, 0.45)
	g.fx.slash(x, y, dir, 120, -28, 208, tone, { thick = 22, life = 0.42 })
	g.fx.slash(x, y, dir, 84, -20, 200, tone, { thick = 10, life = 0.5 })
	g.fx.shards(x, y, 26, tone, { speed = 200, up = 60, kind = "mix", life = 0.8 })
	if formed then
		reaperShade(g, x - dir * 14, g.y, dir, 0.5, 2)
		g.fx.slash(x, y, dir, 150, -28, 208, DARK, { thick = 26, life = 0.45 })
	end
	for _, m in g.hitAt(x, g.y, 126, 70, if formed then 28 else 14, { lift = 220 }) do
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

-- 백귀야행(4차 광역기 · 다시 쓰기 12초 · 맵 전체 — 2026-10-24 사용자 "무니, 리븐 광역기 만든것처럼 엑시온, 리퍼, 살라맨더 4차 스킬포인트 조정해서 그 빈포인트로 투자하는 완전 멋진 광역기만들자"):
--  낫을 치켜들면(skill 동작) 망령 열여섯이 몸에서 쏟아져 양쪽 화면 끝까지 물결치며 날아간다(둥근 머리 · 꼬리 셋 · 검은 눈 — 하나씩 높이 · 빠르기 · 너울이 다르다).
--  망령이 지나가는 차례로 적마다 할퀸 자국 셋이 나고 흰 영혼이 뽑혀 나와 리퍼에게 휘어 날아와 스민다. 판정은 쓰는 순간 한 번: 맵의 모든 적.
--  이름 · 모양 · 숫자는 제가 정한 것(사신 강림의 겹 초승달 · 단죄의 떨어지는 낫과 겹치지 않게 「망령 떼」로)
local PARADE_N, PARADE_SPEED, PARADE_LIFE = 16, 760, 0.8
local EYE = 0x141a26
local function ghostAt(gh, t: number)
	return gh.x0 + gh.side * gh.speed * t, gh.y0 - gh.alt + sin(t * gh.freq + gh.ph) * gh.amp
end
local function drawGhost(ctx, gh, t: number, tone)
	local x, y = ghostAt(gh, t)
	for j = 3, 1, -1 do -- 꼬리(뒤로 갈수록 작고 어둡다)
		local tx, ty = ghostAt(gh, max(0, t - j * 0.025))
		disc(ctx, tx, ty + 1, max(1, gh.r - j), if j == 3 then tone.d else tone.n)
	end
	disc(ctx, x, y, gh.r + 1, tone.n)
	disc(ctx, x, y, gh.r, tone.w)
	ctx:style(EYE)
	ctx:rect(R(x) - 2, R(y) - 1, 1, 2)
	ctx:rect(R(x) + 1, R(y) - 1, 1, 2)
end
local function parade(g)
	local x0, y0, tone = g.x, g.y - 18, g.tone
	g.shake(3, 0.3)
	local ghosts = {}
	for i = 1, PARADE_N do
		ghosts[i] = { x0 = x0, y0 = y0, side = if i % 2 == 0 then 1 else -1, delay = (i - 1) * 0.022, speed = PARADE_SPEED * (0.8 + g.rnd() * 0.4), alt = g.rnd() * 50 - 10, amp = 4 + g.rnd() * 8, freq = 12 + g.rnd() * 8, ph = g.rnd() * 6.28, r = 3 + floor(g.rnd() * 3) }
	end
	local life = PARADE_LIFE + 0.4
	g.fx.add(life, function(ctx, k)
		local t = k * life
		for _, gh in ghosts do
			local lt = t - gh.delay
			if lt > 0 and lt < PARADE_LIFE then
				ctx:alpha(if lt < PARADE_LIFE - 0.15 then 1 else (PARADE_LIFE - lt) / 0.15)
				drawGhost(ctx, gh, lt, tone)
			end
		end
		ctx:alpha(1)
	end)
	-- 판정은 여기 한 번: 맵의 모든 적 — 할퀸 자국 · 뽑혀 나오는 영혼은 망령이 지나가는 차례로
	for _, m in g.mobs() do
		g.hurt(m, 12, { stop = 0.08 })
		local mx, my = m.x, m.y - (m.h or 16) / 2 - 2
		g.after(min(0.6, abs(mx - x0) / PARADE_SPEED + 0.05), function()
			for i = -1, 1 do
				g.fx.cut(mx + i * 4, my, 20, 65, tone, { th = 2, life = 0.2, delay = (i + 1) * 0.03 })
			end
			local hx, hy = g.x, g.y - 20
			g.fx.add(0.55, function(ctx, k) -- 영혼: 적에게서 흰 구슬이 솟았다가 리퍼에게로 휘어 날아온다
				local e = k * k
				local px, py = mx + (hx - mx) * e, my - 30 * sin(k * PI) + (hy - my) * e
				disc(ctx, px, py, 3, tone.n)
				disc(ctx, px, py, 2, tone.w)
			end)
		end)
	end
	g.after(0.7, function()
		g.fx.ring(g.x, g.y, 4, 40, tone, { squash = 0.35, back = true, life = 0.4 })
		g.fx.aura(g.x, g.y, tone, { r = 14, h = 30 })
	end)
end

-- 그림자 흡혈(3차 사냥기 — 2026-11-03 사용자 "그냥 큰 낫의 날이 좌우로 하나씩 해서 플레이어 중간으로 쓸어오는식으로" · 그 전 S312 ~ S314: 사슬낫(던져 붙잡아 끌어오기)):
--  양옆(176도트)에 큰 낫날이 하나씩 솟아(0 ~ 0.1) → 리퍼 쪽 가운데로 쓸어 온다(0.1 ~ 0.34 · 갈수록 빠르게 · 빠르기 줄을 끄는 장) → 가운데에서 만나 번쩍(0.34) → 부서진다.
--  그림 = Codex가 그린 장면을 점으로 옮긴 것(공방 assetpack/lune/fx/raw_rp_reap.png → fx/reaper_reap.png · tools/build_lune_reaper_sickle.py reap 8 — 한 점 = 받은 그림 8화소 · 낫날 42도트) ·
--  코드로 그리는 것은 없다 — 받은 장면을 자리 · 때에 맞춰 찍기만 한다(오른쪽 날은 그린 그대로 왼쪽으로 · 왼쪽 날은 뒤집는다). 맞은 적의 번쩍임 = 사슬낫 때 받은 그림(fx/reaper_sickle.png의 bite).
--  판정: 한 번(단타 — 쓸어 오는 도중 0.18초) · 양옆 196 · 위 64 · 아래 32 · 12마리까지 · 끌어 모으기(gather — 제 발판 안에서 리퍼 쪽으로(2026-11-05 — 그 전: 지형과 상관없이) · 보스는 빼고 · 서버 Room:pullMob —
--   2026-11-03 사용자 "일반몬스터는 지형상관없이 쫙 끌려와야"). 때 · 크기는 제가 정한 것
--  공방 kits/reaper.js와 줄마다 같다. 장(공방 fx/reaper_reap.json · reaper_sickle.json): { x, y, w, h, 기준 x, 기준 y } — 기준 = 칸 가운데
local RP = {
	rise = { 0, 0, 33, 45, 15, 24 },
	blade = { 34, 0, 35, 42, 16, 22 },
	rush = { 70, 0, 41, 43, 20, 24 },
	shatter = { 112, 0, 33, 30, 16, 19 },
	clash = { 146, 0, 31, 47, 15, 26 },
}
local BITE = { { 218, 0, 13, 14, 6, 8 }, { 232, 0, 34, 32, 18, 18 }, { 267, 0, 29, 24, 15, 14 } }
local REAP = { from = 176, to = 16, life = 0.5, rise = 0.1, sweep = 0.34, hitAt = 0.18, high = 21, reach = 196, up = 64, down = 32, pull = 800, targets = 12 }
-- 피 줄기(넋 거두기 — 처치): 리퍼의 색 한 벌
local BLOOD = { w = 0xffffff, l = 0xff7ea2, n = 0xff3e9f, d = 0xb11fa5 }
-- 장 하나를 기준점 (x, y)에 찍는다 · flip = 기준점에서 좌우로 뒤집는다(왼쪽의 날)
local function blitF(ctx, img, f, x: number, y: number, flip: boolean, alpha: number?)
	if img then
		ctx:blit(img, f[1], f[2], f[3], f[4], R(x), R(y), -f[5], -f[6], flip, 1, alpha or 1)
	end
end
-- 그때 t(초)의 날: d = 리퍼에게서의 거리 · f = 장 · a = 보이는 정도
local function reapAt(t: number)
	if t < REAP.rise then
		return { d = REAP.from, f = RP.rise, a = t / REAP.rise }
	elseif t < REAP.sweep then
		local u = (t - REAP.rise) / (REAP.sweep - REAP.rise)
		return { d = REAP.from - (REAP.from - REAP.to) * u * u, f = if u < 0.2 then RP.blade else RP.rush, a = 1 }
	end
	return { d = REAP.to, f = RP.shatter, a = max(0, 1 - (t - REAP.sweep) / (REAP.life - REAP.sweep)) }
end
-- 맞은 적의 번쩍임(3장 — 0.05초씩)
local function bite(g, x: number, y: number, flip: boolean)
	g.fx.add(0.15, function(ctx, k)
		blitF(ctx, g.art.rp_sickle, BITE[min(3, floor(k * 3) + 1)], x, y, flip)
	end)
end
-- 피 줄기: 적의 몸 → 리퍼의 가슴으로 휘어 드는 핏방울 셋(지나온 길이 이어진 띠) — 넋 거두기(처치)가 쓴다
local function drawSiphon(ctx, x0: number, y0: number, x1: number, y1: number, k: number)
	local cx, cy = (x0 + x1) / 2, min(y0, y1) - 26
	local function at(u: number): (number, number)
		return (1 - u) * (1 - u) * x0 + 2 * (1 - u) * u * cx + u * u * x1, (1 - u) * (1 - u) * y0 + 2 * (1 - u) * u * cy + u * u * y1
	end
	for i = 0, 2 do
		local u = max(0, min(1, (k - i * 0.12) / 0.62))
		if u > 0 and u < 1 then
			for j = 8, 1, -1 do -- 이어진 띠
				local ax, ay = at(max(0, u - j * 0.035))
				local bx, by = at(max(0, u - (j - 1) * 0.035))
				line(ctx, ax, ay, bx, by, if j > 4 then BLOOD.d else BLOOD.n, 1)
			end
			local px, py = at(u)
			disc(ctx, px, py, 2, BLOOD.n)
			ctx:style(BLOOD.l)
			ctx:rect(R(px), R(py) - 1, 1, 1)
		end
	end
end
-- 대수확(4차 사냥기 — 2026-11-03 사용자 "4차 사냥기도 플레이어 중심 사거리로 사신이 멋지게 세로로 베어내는 스킬로 바뀌어야해 그래서 3차사냥이고 모아서 4차사냥기로 한번에 처리하는 구조로" →
--  "사신이펙트도 조금만더 연하게 그리고 크기가 크고 베어내는 이펙트도 있으면서 연기는 좀 불규칙하게 전면으로 휘날리는느낌 그리고 스킬 이펙트 크기로 범위를 어림잡을수있어야함" →
--  "아니 이런게아니고 사신이뒤에서 베는모션을하고 사라지고 베이는 모션이 나오면서 다다다다 이런식이야" → "사신형태 이거아니야 원래 다른스킬들이랑 사신이펙트 다르잖아 그리고 4차 베어내는 이펙트 둥근거 쓰지마" → "pixelfx써보자" →
--  "손톱효과 만 남기고 다른 이상한 베어내는것처럼 넣은효과는 빼고 손톱효과를 조금 얇게 만들수있나? 그리고 손톱효과를 블랙+핑크 색깔로"):
--  그림자 흡혈이 리퍼 코앞에 모은 적을 한 번에 벤다.
--  ① 사신 그림자 — 다른 스킬(사신의 일격 · 단죄 · 사신화)과 같은 모습: 리퍼의 베는 동작(dslash)을 칠흑으로(reaperShade와 같다) · 세 배 크기로 리퍼 등 뒤(18)에 ·
--     0 ~ 6째 장을 0.05초씩(젖힘 → 3째 장에 벤다 → 거둠 — 9째 장의 둥근 큰 휘두름은 쓰지 않는다) · 진하기 0.7(다른 스킬의 0.85보다 연하게) · 0.25초부터 사라진다 · 캐릭터 뒤(그림자 층).
--  ② 베이는 자국(캐릭터 앞): 사신이 베는 순간(0.15 — 한 번 친다)부터 0.045초마다 여덟 번(4차 피해 숫자 줄 여덟과 같은 박자) — 판정(양옆 120 · 위 80)을 여덟 칸으로 나눈 자리를
--     뒤섞은 차례로 하나씩(칸 안에서 조금씩 · 높이 12 ~ 72) — 터지는 자리로 범위를 어림잡는다. 자국 = 손톱 할퀴기 하나(pixelfx github.com/patch-gg/pixelfx · MIT의 melee/claw-swipe를
--     고친 우리 것 lune/reaper-claw — 굵기 0.6배 · 검정 + 분홍 · 빛무리 없이 · 아홉 장 · 1초에 15장 = 0.6초 — 분홍으로 그어져 → 검게 식어 → 점선 흉터로 사라진다) · 아무렇게나 뒤집는다.
--     (그 전 같은 날: X 베기(melee/double-slash)도 섞었다 — "이상한 베어내는것처럼 넣은효과는 빼고")
--  ③ 날리는 연기(캐릭터 앞 · 옅게 0.55): 사신이 사라지기 시작할 때(0.25) 사신의 몸 둘레(앞뒤 40 · 높이 10 ~ 60)에서 다섯 자락이 저마다 늦게(0 ~ 0.15초) 앞쪽 위로 날아간다.
--  그림: 사신 = 리퍼의 동작 그림 그대로(따로 그린 것이 없다) · 자국 = pixelfx(공방 vendor/pixelfx — tools/build_lune_pfx.py harvest5 → fx/reaper_harvest5.png · 1초에 15장) ·
--  연기 = Codex(raw_rp_harvest2b.png 아래 칸 — fx/reaper_harvest4.png에서 그대로). 그 전(같은 날 · 쓰지 않는다): Codex로 그린 큰 사신(fx/reaper_harvest.png · 2 · 3) · Codex 자국(fx/reaper_harvest4.png).
--  판정: 한 번(0.15초) · 리퍼를 가운데로 양옆 120 · 위 80 · 아래 8 · 15마리까지(그림자 흡혈이 모은 12마리를 한 번에). 크기 · 때 · 진하기 · 자국과 연기의 수 · 자리 · 빠르기는 제가 정한 것
--  공방 kits/reaper.js와 줄마다 같다. 장(공방 fx/reaper_harvest5.json): { x, y, w, h, 기준 x, 기준 y } — 자국 = 그 효과의 장들을 덮는 네모의 가운데 · 연기 자락 = 칸 가운데
local CUT = { { { 358, 39, 1, 1, 0, 0 }, { 213, 0, 21, 35, 4, 18 }, { 0, 0, 36, 38, 10, 18 }, { 90, 0, 40, 37, 14, 18 }, { 131, 0, 46, 37, 20, 20 }, { 37, 0, 52, 38, 26, 20 }, { 178, 0, 34, 37, 8, 20 }, { 235, 0, 25, 31, 0, 20 }, { 261, 0, 24, 31, -2, 20 } } } -- 베이는 자국(우리 할퀴기 — pixelfx lune/reaper-claw) x 아홉 장
local WISP = { { { 66, 39, 30, 14, 14, 7 }, { 320, 0, 58, 16, 28, 8 }, { 190, 39, 46, 9, 24, 4 } }, { { 286, 0, 33, 19, 15, 10 }, { 0, 39, 65, 15, 32, 7 }, { 237, 39, 63, 8, 32, 3 } }, { { 156, 39, 33, 12, 17, 6 }, { 97, 39, 58, 13, 30, 6 }, { 301, 39, 56, 8, 28, 3 } } } -- 연기 자락 셋 x 세 걸음(뭉침 → 늘어나 말림 → 흩어짐)
local HARV = {
	shade = 3, back = 18, frames = 7, step = 0.05, alpha = 0.7, fade = 0.25, hit = 0.15, reach = 120, up = 80, down = 8, targets = 15,
	cuts = 8, every = 0.045, fps = 15, cutSpread = 115, cutLow = 12, cutHigh = 72, wisps = 5, wispBack = 40, wispLow = 10, wispHigh = 60, late = 0.15,
	drift = { 25, 50 }, climb = { 8, 20 }, wispLife = { 0.5, 0.7 }, haze = 0.55,
}
local function harvest(g)
	local x, gy, dir = g.x, g.y, g.dir
	local flip, sx, life = dir < 0, x - dir * HARV.back, HARV.frames * HARV.step
	g.shot({ x = sx, y = gy, life = life, draw = function(_ctx, p) -- ① 사신 그림자(세 배 · 리퍼 등 뒤): 젖힌다 → 벤다 → 거두며 사라진다
		local f = min(HARV.frames - 1, floor(p.t / HARV.step))
		local a = HARV.alpha * max(0, min(1, p.t * 12 + 0.3, if p.t < HARV.fade then 1 else (life - p.t) / (life - HARV.fade)))
		g.sprite("dslash", f, p.x, p.y, dir, { color = 0x12161c, alpha = a, scale = HARV.shade })
	end })
	g.after(HARV.hit, function() -- 사신이 베는 순간 한 번 친다 — 리퍼 둘레의 적을 한 번에
		local hs = g.hit(-HARV.reach, HARV.reach, HARV.up, HARV.down, 18, { stop = 0.08, targets = HARV.targets })
		g.shake(2, 0.15)
		for i = 1, min(3, #hs) do
			harvestFx(g, hs[i], false) -- 맞은 적의 넋이 빨려 든다(셋까지)
		end
		local slots = {} -- ② 베이는 자국: 판정을 여덟 칸으로 나눈 자리를 뒤섞은 차례로 — 다다다다
		for i = 1, HARV.cuts do
			slots[i] = i - 1
		end
		for i = #slots, 2, -1 do
			local j = floor(g.rnd() * i) + 1
			slots[i], slots[j] = slots[j], slots[i]
		end
		for i, s in slots do
			local w = 2 * HARV.cutSpread / HARV.cuts
			local cx, cy = x - HARV.cutSpread + (s + 0.2 + g.rnd() * 0.6) * w, gy - HARV.cutLow - g.rnd() * (HARV.cutHigh - HARV.cutLow)
			local c, cf = CUT[floor(g.rnd() * #CUT) + 1], g.rnd() < 0.5
			g.fx.add(#c / HARV.fps, function(ctx, k)
				blitF(ctx, g.art.rp_harvest5, c[min(#c, floor(k * #c) + 1)], cx, cy, cf, if k < 0.7 then 1 else 1 - (k - 0.7) / 0.3)
			end, { delay = (i - 1) * HARV.every })
		end
	end)
	g.after(HARV.fade, function() -- ③ 날리는 연기(캐릭터 앞): 사신이 사라지기 시작할 때 그 몸 둘레에서 앞쪽 위로
		for i = 1, HARV.wisps do
			local w, wx, wy = WISP[(i - 1) % 3 + 1], sx + (g.rnd() * 2 - 1) * HARV.wispBack, gy - HARV.wispLow - g.rnd() * (HARV.wispHigh - HARV.wispLow)
			local vx, vy = dir * (HARV.drift[1] + g.rnd() * (HARV.drift[2] - HARV.drift[1])), -(HARV.climb[1] + g.rnd() * (HARV.climb[2] - HARV.climb[1]))
			local wl = HARV.wispLife[1] + g.rnd() * (HARV.wispLife[2] - HARV.wispLife[1])
			g.fx.add(wl, function(ctx, k)
				blitF(ctx, g.art.rp_harvest5, w[if k < 0.25 then 1 elseif k < 0.6 then 2 else 3], wx + vx * k * wl, wy + vy * k * wl, flip, HARV.haze * (if k < 0.15 then k / 0.15 else 1 - (k - 0.15) / 0.85))
			end, { delay = g.rnd() * HARV.late })
		end
	end)
end
function hands(g)
	local x, gy = g.x, g.y
	g.fx.add(REAP.life, function(ctx, k) -- 양쪽의 큰 낫날(왼쪽은 뒤집는다)
		local st = reapAt(k * REAP.life)
		for _, side in { 1, -1 } do
			blitF(ctx, g.art.rp_reap, st.f, x + side * st.d, gy - REAP.high, side < 0, st.a)
		end
	end)
	g.after(REAP.sweep, function() -- 가운데에서 만나 번쩍
		g.fx.add(0.14, function(ctx, k)
			blitF(ctx, g.art.rp_reap, RP.clash, x, gy - REAP.high - 2, false, 1 - k * k)
		end)
	end)
	g.after(REAP.hitAt, function() -- 한 번 친다(단타) — 쓸어 오며 리퍼 코앞으로 끌어당긴다
		local hit = g.hit(-REAP.reach, REAP.reach, REAP.up, REAP.down, 12, { pull = REAP.pull, gather = true, stop = 0.06, targets = REAP.targets })
		g.shake(2, 0.12)
		for i, m in hit do -- 맞은 적의 번쩍임(넷까지)
			if i > 4 then
				break
			end
			local mx, my = m.x, m.y - 12
			g.after((i - 1) * 0.02, function()
				bite(g, mx, my, mx < x)
			end)
		end
	end)
end

-- 망령 돌진(3차 이동기 — 2026-10-25 사용자 "리퍼도 망령돌진 일반 이동기로 변경하고 사냥기 추가하자 리븐작업한것처럼"): 피해는 없다(리븐 연쇄 순보와 같게 — 마스터 5 · 다시 쓰기 5초 · 공중에서도).
--  유령처럼 몸이 비치며 앞으로 미끄러진다 — 아주 짧은 순간이동을 steps번(0.03초마다 · 지나는 자리마다 잔상) · 바닥을 긁는 자국 · 끝에서 작은 영혼 불씨. 거리(모두 합친 것)는 스킬 레벨마다(공방 combat.js의 MOVECAST → moveCast.dist)
function ghostRush(g)
	local mc = COMBAT.moveCast and COMBAT.moveCast.rp_drag
	local steps = if mc then mc.steps else 6
	local total = if mc then mc.dist[math.clamp(g.sk("rp_drag"), 1, #mc.dist)] else 90
	local tone = g.tone
	for i = 0, steps - 1 do
		g.after(i * 0.03, function()
			local x0 = g.x
			g.ghost()
			g.teleport(g.fwd(total / steps))
			local x1, y = g.x, R(g.y) - 1
			g.fx.add(0.4, function(ctx, k) -- 바닥을 긁는 자국
				ctx:style(if k < 0.4 then tone.l else tone.n)
				ctx:rect(R(min(x0, x1)), y, max(1, R(abs(x1 - x0))), 1)
			end, { back = true })
		end)
	end
	g.after(steps * 0.03, function()
		g.fx.shards(g.x, g.y - 10, 5, tone, { kind = "dot", up = 40, speed = 30, life = 0.35 })
	end)
end
-- ---------- 2026-10-31 리퍼 리마스터의 그림(공방 kits/reaper.js와 같다) ----------
-- 넋: 꼬리 긴 분홍 불꽃 — 머리(분홍 · 가운데 흰 점 · 위로 밝은 끝) · 지나온 자리(어두운 분홍 → 분홍 → 밝은 분홍)
function drawSoul(ctx, x: number, y: number, trail, tone)
	for i, p in trail do
		ctx:style(if i <= 2 then tone.d elseif i <= 4 then tone.n else tone.l)
		local sz = if i <= 3 then 1 else 2
		ctx:rect(R(p[1]) - floor(sz / 2), R(p[2]) - floor(sz / 2), sz, sz)
	end
	disc(ctx, x, y, 2, tone.n)
	ctx:style(tone.w)
	ctx:rect(R(x), R(y), 1, 1)
	ctx:style(tone.l)
	ctx:rect(R(x), R(y) - 2, 1, 1)
end
-- 넋 거두기(사용자: "피흡도 처치시 흡혈로 해서 … 이펙트도 멋지게 기존 이펙트랑 잘어우러지고"): 쓰러진 적의 몸에서 넋이 빠져나와 위로 떠올랐다가(0.3) 리퍼의 가슴으로 휘어 들고,
--  blood면 그 곁으로 핏방울 셋이 그림자 흡혈과 같은 핏빛 줄기로 따라 든다 → 닿는 순간 가슴에 핏빛 고리 · 분홍 알갱이(되찾은 체력 · 영혼 하나). 대수확은 넋만(blood = false)
function harvestFx(g, m, blood: boolean)
	local tone = g.tone
	local mx, my = m.x, m.y - m.h - 10
	local trail = {}
	g.fx.ring(mx, my, 2, 9, if blood then BLOOD else tone, { life = 0.2 })
	if blood then
		g.fx.shards(mx, my, 4, BLOOD, { kind = "dot", speed = 50, up = 40, life = 0.3 })
	end
	g.fx.add(0.6, function(ctx, k)
		local px, py, sy = g.x, g.y - 14, my - 16
		local x, y
		if k < 0.3 then
			local u = k / 0.3
			x, y = mx + sin(u * 6) * 1.5, my - 16 * u
		else
			local u = (k - 0.3) / 0.7
			local cx, cy = (mx + px) / 2, min(sy, py) - 24
			x = (1 - u) * (1 - u) * mx + 2 * (1 - u) * u * cx + u * u * px
			y = (1 - u) * (1 - u) * sy + 2 * (1 - u) * u * cy + u * u * py
		end
		table.insert(trail, { x, y })
		if #trail > 6 then
			table.remove(trail, 1)
		end
		drawSoul(ctx, x, y, trail, tone)
	end)
	if blood then
		local px0, py0 = g.x, g.y - 14
		g.fx.add(0.45, function(ctx, k)
			drawSiphon(ctx, mx, my, px0, py0, k)
		end, { delay = 0.1 })
	end
	g.after(0.58, function()
		if blood then
			g.fx.pop(g.x, g.y - 14, BLOOD, { r = 5 })
		end
		g.fx.shards(g.x, g.y - 14, 4, tone, { kind = "dot", up = 30, speed = 30, life = 0.3 })
	end)
end
-- 사신 그림자: 리퍼의 베는 동작(dslash)을 칠흑으로 — (x, y)에 face쪽을 보고 life초 동안 프레임 from부터(사신의 일격 · 단죄 · 대수확)
function reaperShade(g, x: number, y: number, face: number, life: number, from: number)
	g.shot({ x = x, y = y, life = life, draw = function(_ctx, p)
		local f = min(9, from + floor(p.t / 0.05))
		g.sprite("dslash", f, p.x, p.y, face, { color = 0x12161c, alpha = 0.85 * min(1, (p.life - p.t) * 5, p.t * 12 + 0.3) })
	end })
end
-- 사신 기술(사신화 동안 — 2026-10-31 게이지 직업): 그 기술의 앞에 칠흑의 큰 낫(굵은 초승달 · 가운데 분홍 날) — len = 그 기술이 닿는 길이(도트)
function formSlash(g, len: number)
	if not g.has("rp_form") then
		return
	end
	g.fx.slash(g.fwd(2), g.y - 12, g.dir, len * 0.6, -45, 75, DARK, { thick = 16, life = 0.3 })
	g.fx.slash(g.fwd(2), g.y - 12, g.dir, len * 0.5, -35, 65, g.tone, { thick = 4, life = 0.32 })
	g.fx.shards(g.fwd(len * 0.4), g.y - 14, 6, g.tone, { kind = "mix", speed = 90, life = 0.35 })
end
local RIM = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
-- 망령의 몸(소환 망령): 그 동작의 장을 분홍 테두리(사방 한 점) 위에 칠흑으로 — 어두운 땅 · 몬스터 위에서도 보이게
local function rimSprite(g, clip: string, f: number, x: number, y: number, face: number, a: number)
	for _, o in RIM do
		g.sprite(clip, f, x + o[1], y + o[2], face, { color = 0xff3e9f, alpha = a * 0.75 })
	end
	g.sprite(clip, f, x, y, face, { color = 0x12161c, alpha = a })
end

-- 망령(3차 소환 — 2026-11-01 사용자 "망령소환하면 망령이 캐릭터를 쫓아다니는게 아니라 자율적으로 돌아다니면서 공격해야지"): 어두운 실루엣(분홍 테두리 · 눈은 그리지 않는다)이 둥실 떠서
--  둘레(sight)의 가장 가까운 적에게 날아가(초당 speed) 붙고 · 적이 없으면 리퍼 둘레 ±wander를 떠돈다(roamEvery초마다 곳을 고른다) · 리퍼에게서 leash보다 멀어지면 돌아온다.
--  수는 공방 combat.js의 PLACED.rp_ghost(서버 room.luau Room:roam이 같은 셈으로 움직여 친다). 치는 것은 서버가 정한다 — 서버가 친 때(procs.summon) 그 자리에 가장 가까운 망령이 휘두른다.
--  셋까지(망령 군단) · 넘치면 먼저 부른 것이 사라진다(서버의 Room:place와 같다). 공방 kits/reaper.js와 같다(시험판은 망령이 스스로 친다 — 서버가 없다)
local GHOST = COMBAT.placed.rp_ghost
function ghostSwing(g, p, m)
	p.sw = 0.35
	p.face = if m.x > p.x then 1 elseif m.x < p.x then -1 else p.face
	g.fx.slash(p.x, p.y - 9, p.face, 26, -30, 70, g.tone, { thick = 5 })
	g.fx.cut(m.x, m.y - 12, 16, 70, g.tone, { th = 2, life = 0.16 })
end
local function roamGhost(g, p, dt: number)
	p.sw = max(0, p.sw - dt)
	local tx, ty
	if abs(p.x - g.x) > GHOST.leash or abs(p.y - g.y) > GHOST.leash then -- 너무 멀어졌다: 리퍼에게 돌아온다
		tx, ty = g.x - g.dir * GHOST.back, g.y
	else
		local m, bd = nil, GHOST.sight
		for _, q in g.mobs() do
			local d = abs(q.x - p.x)
			if abs(q.y - p.y) <= 60 and d <= bd then
				m, bd = q, d
			end
		end
		if m then
			tx, ty = m.x - (if m.x >= p.x then 1 else -1) * GHOST.range * 0.6, m.y
		else -- 떠돈다
			if p.wx == nil or g.clock >= p.wanderAt then
				p.wx, p.wanderAt = g.x + (g.rnd() * 2 - 1) * GHOST.wander, g.clock + GHOST.roamEvery
			end
			tx, ty = p.wx, g.y
		end
	end
	local dx, dy = tx - p.x, ty - p.y
	local d = math.sqrt(dx * dx + dy * dy)
	if d > 1 then
		local k = min(1, GHOST.speed * dt / d)
		p.x += dx * k
		p.y += dy * k
		if abs(dx) > 2 and p.sw <= 0 then
			p.face = if dx > 0 then 1 else -1
		end
	end
end
function summonGhost(g)
	local tone, x0 = g.tone, g.x - g.dir * GHOST.back
	g.fx.aura(x0, g.y, tone, { r = 12, h = 30 })
	g.fx.rise(x0, g.y, 10, tone, { w = 14 })
	local keep = if g.sk("rp_ghost2") > 0 then 3 else 1 -- 망령 군단
	local list = {}
	for _, q in g.s.ghosts or {} do
		if q.t < q.life then
			table.insert(list, q)
		end
	end
	while #list >= keep do -- 넘치면 먼저 부른 것이 사라진다
		local old = table.remove(list, 1)
		old.life = old.t
	end
	g.s.ghosts = list
	table.insert(list, g.shot({ x = x0, y = g.y, life = 60, sw = 0, face = g.dir, summon = "rp_ghost", update = function(p, dt)
		roamGhost(g, p, dt)
	end, draw = function(_ctx, p)
		local c = if p.sw > 0 then "dslash" else "idle"
		local k = min(1, p.t * 3, (p.life - p.t) * 3)
		local bob = if p.sw > 0 then 0 else R(sin(p.t * 3) * 2) - 2 -- (둥실 떠 있다)
		rimSprite(g, c, if p.sw > 0 then 3 + floor((0.35 - p.sw) * 12) else floor(p.t * 8) % 9, p.x, p.y + bob, p.face, 0.85 * k) -- (분홍 테두리 — 망령 낫의 망령과 같은 몸)
	end }))
end

local skills = {
	{ id = "rp_double", key = "Q", shot = 0.5, segs = { { clip = "dslash", fps = 20, ev = {
		[3] = function(g)
			g.fx.slash(g.fwd(2), g.y - 10, g.dir, 32, -30, 70, g.tone, { thick = 6 })
			g.hit(-6, 44, 30, 4, 3, {})
			formSlash(g, 60)
		end,
		[9] = function(g) -- 둘째 타는 안쪽으로 감기며 끌어당긴다(2026-10-31 — 그 전: 멀리 밀었다): 낫 끝에서 리퍼 쪽으로 빨려 드는 줄 둘
			g.fx.slash(g.fwd(2), g.y - 10, g.dir, 36, 80, -35, g.tone, { thick = 7 })
			for i = 0, 1 do
				g.fx.cut(g.fwd(30), g.y - 6 - i * 7, 34, 0, g.tone, { th = 1, life = 0.16, delay = i * 0.03 })
			end
			g.hit(-6, 48, 30, 4, 4, { pull = 120, stop = 0.04 })
			formSlash(g, 66)
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
			formSlash(g, 60)
		end,
	} } } },
	{ id = "rp_throw", key = "W", shot = 0.62, segs = { { clip = "slash", fps = 16, ev = { [5] = function(g) -- 회전 낫: 도는 낫이 그리는 둥근 자국이 오가며 남는다(2026-11-01 사용자 "원래 리퍼 2차 사냥기 반달같은거 날리는스킬은? 그게 더좋은데 … 리마스터 이전을 말하는거야" — 10-31 리마스터의 망령 낫을 빼고 리마스터 전의 회전 낫으로 되돌렸다)
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
			formSlash(g, 70)
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
			for i = 1, min(4, #hs) do
				harvestFx(g, hs[i], false) -- 넋이 빨려 든다(사신 게이지가 크게 찬다 — 서버의 kitAfter)
			end
			formSlash(g, 70)
		end,
	} } } },
	buff("rp_chill", "1"),
	{ id = "rp_hands", key = "E", shot = 0.5, segs = { { clip = "slash", fps = 20, ev = { [4] = function(g) -- 그림자 흡혈(위 hands — 처음 「망자의 손」)
		hands(g)
	end } } } },
	{ id = "rp_drag", key = "V", air = true, shot = 0.3, segs = { -- 망령 돌진(이동기 — 위 ghostRush): 몸이 비치며 앞으로 미끄러진다
		{ clip = "dash", loop = true, dur = 0.2, fps = 26, float = true, start = ghostRush },
	} },
	{ id = "rp_judge", key = "D", shot = 0.62, segs = { { clip = "slash", fps = 12, ev = { [2] = function(g) -- 적 머리 위 표시점 → 세로로 떨어지는 낫 모양 셋
		local m = g.boss() or g.nearest(260)
		if not m then
			return
		end
		local top = if m.boss then 44 else 28
		g.fx.pop(m.x, m.y - m.h - top, g.tone, { r = 6, life = 0.3 })
		reaperShade(g, m.x + (if m.x >= g.x then 1 else -1) * (if m.boss then 26 else 14), m.y, if m.x >= g.x then -1 else 1, 0.6, 3) -- 적 등 뒤에 선 사신 그림자(2026-10-31)
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
	{ id = "rp_ghost", key = "X", instant = true, shot = 2.0, cast = function(g) -- 망령: 스스로 떠돌며 벤다(위 summonGhost — 2026-11-01 · 그 전: 등 뒤를 따라다녔다)
		summonGhost(g)
	end },
	{ id = "rp_fade", key = "5", instant = true, shot = 0.3, cast = function(g)
		g.buff("rp_fade")
		g.fx.ring(g.x, g.y, 22, 6, g.tone, { life = 0.3 })
		g.fx.shards(g.x, g.y - 8, 8, g.tone, { kind = "dot", up = 40, speed = 30 })
	end },
	{ id = "rp_harvest", key = "R", shot = 0.34, segs = { { clip = "dslash", fps = 18, ev = { [1] = function(g) -- 큰 사신의 세로 베기(위 harvest — 2026-11-03)
		harvest(g)
	end } } } },
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
			if #hs > 0 and g.has("rp_form") then -- 사신화 중이면 타마다 그림자 낫이 한 번 더(2026-10-31 — 그 전: 영혼을 하나씩 태워)
				g.after(0.12, function()
					g.fx.cut(x + 4, g.y - 26, 72, 96, DARK, { th = 5, life = 0.22 })
					for _, m in hs do
						g.hurt(m, 8, { proc = true })
					end
				end)
			end
		end
	end
	-- 2026-11-05 사용자 "보스기 퍼뎀 3차가 4차보다 쎈경우는 없어야한다": 22 → 13장/초 · 0.44 → 0.74초 — 가장 빠른 보스기라 한 번에 넣는 %가 3차 단죄 만렙보다 작았다(Lv.1 510% < 722%). 초당 세기(rate)는 그대로(공방 kits/reaper.js와 같다)
	table.insert(skills, { id = "rp_behead", key = "F", shot = 0.74, segs = { { clip = "dslash", fps = 13, ev = ev } } })
end

local more = {
	{ id = "rp_form", key = "3", instant = true, shot = 0.5, cast = function(g) -- 사신화(1차 — 사신 게이지가 가득할 때): 칠흑의 기운이 솟고 몸이 커지며 사신이 된다
		g.buff("rp_form")
		g.shake(4, 0.3)
		g.invert(0.08)
		g.fx.ring(g.x, g.y, 8, 60, DARK, { life = 0.4 })
		g.fx.ring(g.x, g.y, 6, 44, g.tone, { life = 0.35 })
		g.fx.aura(g.x, g.y, g.tone, { r = 26, h = 50 })
		g.fx.rise(g.x, g.y, 22, g.tone, { w = 56, life = 1.2 })
		g.fx.shards(g.x, g.y - 16, 16, g.tone, { kind = "mix", speed = 140, up = 60, life = 0.6 })
		reaperShade(g, g.x - g.dir * 10, g.y, g.dir, 0.5, 0)
	end },
	{ id = "rp_parade", key = "N", shot = 1.0, segs = { { clip = "skill", fps = 13, float = true, start = function(g) -- 백귀야행(위 parade)
		g.dim(0.65, 1.6)
	end, ev = { [4] = parade } } } },
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
	icons = { c_hero = "moon", rp_wisp = "flame", rp_chill = "haste", rp_fade = "shield", rp_form = "scythe" },
	init = function(g)
		g.s = { gauge = 0, wispAt = -9, gate = nil, ghosts = {} }
	end,
	haste = function(g)
		return if g.has("rp_chill") then 1.25 else 1
	end,
	mult = function(g)
		return 1 + (if g.has("rp_form") then 0.4 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	dim = function(g)
		return if g.has("rp_form") then 0.25 else 0
	end,
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or o.proc then
			return
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
		g.call("soul", m, near)
	end,
	-- 화면: 이 리퍼가 적을 쓰러뜨렸다(boot.luau의 Hits → Cast:killed — 서버가 쓰러뜨린 사람을 알려 준다) → 넋 · 피가 빨려 든다(되찾는 체력은 서버가 처치 때)
	onKillFx = function(g, m)
		harvestFx(g, m, true)
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
	-- 사신 게이지 막대(발밑의 이름표 바로 아래 — 2026-11-01 사용자 "게이지 샐래맨더 게이지처럼하면되잖아": 살라맨더의 열기 막대와 같은 꼴 · 그 전: 몸 둘레를 도는 구슬).
	--  채우는 동안 진한 색(d) · 가득하면 깜빡인다(l ↔ n — 사신화를 쓸 수 있다) · 사신화 동안은 남은 시간만큼(깜빡인다 — 처음 받은 남은 시간이 가득). 게이지를 배운 내 캐릭터에만 보인다
	draw = function(ctx, g)
		if g.sk("rp_soul") <= 0 then
			return
		end
		local x, y = R(g.x) - 9, R(g.y) + Common.gaugeDown(g)
		local form, full = g.has("rp_form"), (g.s.gauge or 0) >= 100
		local k
		if form then
			g.s.formTotal = max(g.s.formTotal or 0, g.left("rp_form"))
			k = g.left("rp_form") / max(0.01, g.s.formTotal)
		else
			g.s.formTotal = nil
			k = (g.s.gauge or 0) / 100
		end
		ctx:style(0x12161c)
		ctx:rect(x - 1, y - 1, 20, 4)
		ctx:style(if form or full then (if floor(g.clock * 10) % 2 == 1 then g.tone.l else g.tone.n) else g.tone.d)
		ctx:rect(x, y, R(18 * min(1, k)), 2)
	end,
	drawBind = coilBind,
	-- 서버가 정해 화면에 알리는 것(g.call)
	calls = {
		wisp = wisp,
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
			harvestFx(g, m, true)
			if near then
				g.fx.rise(m.x, m.y - 6, 6, g.tone, { life = 0.9 }) -- (저승문 곁 — 영혼 둘)
			end
		end,
	},
	-- 지금의 서버(1차 — sim/kit.luau)가 알리는 따로 나가는 타. o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것) }
	procs = {
		-- o.i = 몇째 발 · o.n = 한 번에 나간 수(떼혼불)
		wisp = function(g, m, o)
			wisp(g, m, o.i or 0, o.n or 1, o)
		end,
		-- 망령이 쳤다(서버 room.luau Room:roam의 망령 — 2026-11-01): 서버가 알린 망령의 자리(sx, sy)에서 가장 가까운 망령이 그 적에게 다가가 낫을 휘두른다 → 숫자
		summon = function(g, m, o)
			local best, bd = nil, math.huge
			for _, p in g.s.ghosts or {} do
				local d = abs(p.x - o.sx) + abs(p.y - 12 - o.sy)
				if p.t < p.life and d < bd then
					best, bd = p, d
				end
			end
			if best then
				best.x += (o.sx - best.x) * 0.6 -- (서버의 자리 쪽으로 — 화면의 망령이 조금 어긋나 있어도 그 적에게 붙는다)
				best.y += (o.sy + 12 - best.y) * 0.6
				ghostSwing(g, best, m)
			end
			if o.land then
				o.land()
			end
		end,
		-- 그림자 낫(사신화 — 서버 room.luau kitAfter): 맞은 적에게 한 박자 늦게 칠흑의 낫 자국 → 숫자
		shade = function(g, m, o)
			g.after(0.1, function()
				local y = m.y - m.h - 12
				g.fx.cut(m.x + 3, y, 36, 70, DARK, { th = 4, life = 0.2 })
				g.fx.cut(m.x - 2, y, 24, -50, g.tone, { th = 2, life = 0.16, delay = 0.02 })
				if o.land then
					o.land()
				end
			end)
		end,
	},
	skills = skills,
}

return reaper
