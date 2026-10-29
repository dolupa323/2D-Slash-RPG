-- 리틀 액시온 — 큰 도끼. 핵심 장치: 힘 모으기(강타 키를 누르고 있으면 단계가 오른다 · 모을수록 몸이 커진다 · 만월이면 모으지 않아도 가득).
--  2026-10-28 리마스터(사용자 "차징을 모으고 한방에 강력한데미지를 보이는거야 딜도 단일타수로 빵 뜨고 … 많은 타수로 패시브를 터트려 딜을 넣는형식이 이상해 커지고 차징해서 한방 빵 이런식이여야해"):
--  도끼 기술은 거의 다 「모았다가 한 방」 — 여러 번 베던 것(삼단 베기 · 쪼개기 두 번 · 몰아치기 · 회전 내려치기 세 번 · 처단의 쌓기)을 한 방으로 바꿨다. 이름표(ax_combo …)는 그대로.
--  같은 날 두 번째(사용자 "사냥이 너무 안좋아졌어 … 풀차징해서 때리는 한방이 더쎄야해 시간을 생각해서 dps 계산을해서 설계를해야해 … 차징중에 느리게 이동 및 방향전환이 가능해야하고"):
--   모은 한 방의 피해는 모은 시간만큼 커진다(sim/kit.luau의 Kit.chargeMul) · 모으는 구간의 한 단계(per) = 사냥기 0.2초 · 보스기 0.3초 ·
--   모으는 동안 0.5배로 걷고 돌아본다(walk · turn — 대지 분쇄는 그대로 제 빠르기로 걷고 뛰고 대쉬한다). 머리 위의 점 대신 차오르는 게이지(client/lune/cast.luau).
--  공방 시험 탭의 dino-workshop/js/lune/kits/axion.js를 줄마다 옮긴 것(동작 · 이펙트 · 판정의 자리와 때). 시험판은 4차까지 다 배운 모습이라,
--  스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로): 메아리 도끼(1차 — 끝까지 모아 친 한 방에만) → 울리는 메아리(떨어진 자리에 충격파) → 만근(더 크게),
--  힘 모으기 2단계(1차) → 3단계(깊은 호흡) → 4단계(만근), 끝까지 모은 대지 강타가 더 멀리 · 넘어뜨린다(충격파).
--  시험판의 피해 값(3 · 6 · 12 …)은 그대로 적어 둔다 — 게임에서는 "몫"으로만 쓴다(수치는 design/combat.js와 서버가 정한다).
--  옮기며 바뀐 이름: end → finish · until → till(Luau의 예약어).
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local crescentPts, starPts, poly = Fx.crescentPts, Fx.starPts, Fx.poly
local line = Fx.line -- 월광 균열의 금(2026-10-24)
local COMBAT = require(script.Parent.Parent.data["combat.generated"]) -- 돌격의 레벨마다의 거리(moveCast — 2026-10-25)
local dash, buff = Common.dash, Common.buff
local floor, sin, cos, min, max, abs, sqrt = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.sqrt

-- 힘 모으기의 단계 수(sim/kit.luau의 Kit.chargeLevels와 같다): 1차 2 · 깊은 호흡(3차) 3 · 만근(4차) +1
local function levelsOf(g): number
	return (if g.sk("ax_charge2") > 0 then 3 else 2) + (if g.sk("ax_echo4") > 0 then 1 else 0)
end
-- 끝까지 모았다(만월 동안에는 늘 — 서버도 그 단계로 센다)
local function full(g): boolean
	return g.lv > 0 and g.lv >= levelsOf(g)
end

-- 메아리 도끼(사출기 — 2026-10-28 리마스터: 끝까지 모아 친 한 방이 맞은 적마다 한 번 더 · 피해는 서버 sim/room.luau의 kitAfter가 정한다).
--  같은 날 사용자 "이런느낌 말고 도끼박히는느낌말고 리븐 스킬이펙트중에 베어내는효과 있거든 그런식으로 베어내는 이펙트로 나오는걸로하자 단타로":
--  날아와 박히는 도끼(S275 · S276 — 그 그림 assetpack/lune/fx/echo_axe는 공방에 남겨 두었다) 대신 맞은 적의 몸을 사선으로 한 번 베어 낸다
--  (fx.cut — 리븐의 그림자 난무 · 천지 가르기의 벤 자국과 같은 그리는 법: 순식간에 그어진 흰 줄이 밝은 색 · 직업 색으로 가늘어지며 사라진다).
--  액시온답게: 리븐(35° · X자 둘)과 달리 한 줄 · 가파르게(등 뒤 위에서 앞 아래로 55° — 도끼를 내려찍는 결) · 굵게. 그 타가 맞고 ECHO초 뒤(메아리) · 여럿이면 GAP초씩.
--  만근(4차)이면 더 길고 굵게 · 우두머리는 1.6배 길게. 울리는 메아리(3차) = 벤 적의 발밑 양옆에 작은 수정 가시. o.land = 벤 순간(화면이 그 타의 피해 숫자를 이때 띄운다). 숫자는 제가 정한 값
local ECHO, GAP = 0.1, 0.03
local function echoCut(g, m, o)
	local now = g.clock
	if g.s.echoAt == now then
		g.s.echoN += 1
	else
		g.s.echoAt, g.s.echoN = now, 0
	end
	local big, tone = g.sk("ax_echo4") > 0, g.tone
	g.after(ECHO + g.s.echoN * GAP, function()
		local dir = g.dir
		local mx, my = m.x, m.y - (m.h or 16) / 2
		local sc = if m.boss then 1.6 else 1
		g.fx.cut(mx, my, (if big then 60 else 48) * sc, -dir * 55, tone, { th = if big then 6 else 5, life = 0.2 })
		g.fx.shards(mx, my, 3, tone, { kind = "tri", up = 40, speed = 60, dir = dir, spread = 0.6, life = 0.3 })
		if g.sk("ax_echo3") > 0 then
			for _, sd in { -1, 1 } do
				g.fx.spike(mx + sd * 10, m.y, 4, 8, tone, { delay = 0.03, lean = sd * 2 })
			end
			g.hitAt(mx, m.y, 16, 20, 2, { proc = true })
		end
		g.hurt(m, 5, { proc = true })
		if o and o.land then
			o.land()
		end
	end)
end

-- 대지 강타(1차 사냥기): 가운데 한 방 + 양옆으로 번지는 수정 가시(가운데에 맞지 않은 적만 가시가 닿는 때에 한 번 — 한 적에 한 숫자 · 설계 SKILLS.ax_slam). 모은 단계만큼 넓다.
--  충격파(2차 패시브 — 2026-10-28 리마스터, 전에는 땅을 따라 한 번 더 쳤다): 끝까지 모아 치면 가시가 양옆 150도트까지 번지고 맞은 보통 적을 1.5초 넘어뜨린다(피해 +는 서버 — world.luau)
local function slam(g)
	local lv, x, y, tone = g.lv, g.fwd(20 * g.big), g.y, g.tone
	local shock = full(g) and g.sk("ax_shock") > 0
	local stun = if shock then 1.5 else nil
	local reach = if shock then 150 else 84 + lv * 10
	local n = floor((reach - 10) / 15) + 1
	g.fx.ring(x, y, 6, 44 + lv * 12, tone)
	g.fx.ring(x, y, 4, 28, tone, { delay = 0.08 })
	g.fx.shards(x, y - 4, 10 + lv * 4, tone, { up = 150, kind = "mix", speed = 120 })
	local center = {}
	for _, m in g.hit(-12, 48 + lv * 10, 44, 4, 10, { lift = 210, stop = 0.06, stun = stun }) do
		center[m] = true
	end
	if lv >= 2 then
		g.shake(1, 0.12) -- 모아 쳤을 때만 아주 약하게
	end
	for i = 1, n do
		for _, s in { -1, 1 } do
			g.fx.spike(x + s * (10 + i * 15), y, 12, max(8, 30 - min(i, 7) * 3), tone, { delay = i * 0.05, lean = s * 4 })
		end
	end
	for _, m in g.mobs() do
		local d = abs(m.x - x)
		if not center[m] and d <= reach and abs(m.y - y) <= 30 then
			g.after(max(1, floor((d - 10) / 15)) * 0.05, function()
				g.hurt(m, 3, { lift = 150, stun = stun })
			end)
		end
	end
end

-- 도끼 내려찍기(1차 보스기 — 2026-10-28 리마스터, 예전 「삼단 베기」): 등 뒤로 젖힌 도끼를 머리 위에서 한 번 내려찍는다 — 모은 만큼 큰 반달 자국 · 땅의 금 · 파편
local function chop(g)
	local lv, tone = g.lv, g.tone
	local x = g.fwd(26)
	g.fx.slash(g.fwd(4), g.y - 8, g.dir, (40 + lv * 8) * g.big, -40, 150, tone, { thick = 9 + lv * 2, life = 0.3 })
	g.fx.cut(x, g.y - 1, 30 + lv * 10, 0, tone, { th = 2, life = 0.35 })
	g.fx.ring(x, g.y, 3, 20 + lv * 8, tone, { life = 0.22 })
	g.fx.shards(x, g.y - 4, 10 + lv * 4, tone, { kind = "bar", up = 90, speed = 110 })
	g.hit(-8, 54 + lv * 10, 46, 4, 10, { kb = 40, stop = 0.06 + lv * 0.02 })
	if lv >= 2 then
		g.shake(1, 0.12)
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

local OUTLINE = { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

-- 월광 균열(4차 광역기 · 다시 쓰기 12초 · 맵 전체 — 2026-10-24 사용자 "무니, 리븐 광역기 만든것처럼 엑시온, 리퍼, 살라맨더 4차 스킬포인트 조정해서 그 빈포인트로 투자하는 완전 멋진 광역기만들자"):
--  도끼를 땅에 내리찍으면(smash 7장) 그 자리에서 양쪽 화면 끝까지 땅이 갈라진다 — 꺾인 금이 0.4초 만에 번지고 곁가지가 난다(어두운 테 + 깜빡이는 빛나는 속).
--  금이 닿는 차례로 적마다 발밑에서 돌가시 셋이 솟고 달빛이 터지며 띄운다(다른 층의 적에게는 금이 세로로 타고 오른다). 판정은 찍는 순간 한 번: 맵의 모든 적.
--  이름 · 모양 · 숫자는 제가 정한 것(달빛 기둥의 빛기둥 · 지진의 톱니 물결과 겹치지 않게 「땅의 금」으로)
local CRACK_W, CRACK_SPEED = 520, 1300 -- 금이 번지는 거리(양쪽 · 도트) · 빠르기(초당 도트)
local function crackLine(x0: number, y: number, side: number, rnd)
	local pts, branches = { { x0, y } }, {}
	local x = x0
	while abs(x - x0) < CRACK_W do
		x += side * (10 + rnd() * 10)
		pts[#pts + 1] = { x, y + (rnd() - 0.5) * 5 }
		if rnd() < 0.22 then
			local bx, by = x, y
			local b = { { bx, by } }
			for _ = 1, 3 do
				bx += side * (4 + rnd() * 6)
				by += (if rnd() < 0.5 then -1 else 1) * (3 + rnd() * 5)
				b[#b + 1] = { bx, by }
			end
			branches[#branches + 1] = { at = abs(x - x0), pts = b }
		end
	end
	return pts, branches
end
local function drawCrack(ctx, pts, x0: number, reach: number, tone, glow: boolean)
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		if abs(q[1] - x0) > reach then
			break
		end
		line(ctx, p[1], p[2], q[1], q[2], tone.d, 3)
		line(ctx, p[1], p[2], q[1], q[2], if glow then tone.w else tone.l, 1)
	end
end
local function crack(g)
	local x0, y, tone = g.fwd(10), g.y, g.tone
	g.shake(6, 0.4)
	g.invert(0.06)
	g.fx.ring(x0, y, 6, 64, tone, { squash = 0.3, back = true, life = 0.5 })
	g.fx.shards(x0, y - 4, 12, tone, { kind = "tri", speed = 120, up = 90, life = 0.6 })
	-- 판정은 여기 한 번: 맵의 모든 적 — 솟는 그림은 금이 닿는 차례로
	for _, m in g.mobs() do
		g.hurt(m, 12, { lift = 160, stop = 0.08 })
		local mx, my = m.x, m.y
		local climb = y - my -- 다른 층(위면 +)
		g.after(min(0.42, abs(mx - x0) / CRACK_SPEED), function()
			if abs(climb) > 12 then
				local pts, n = {}, max(2, floor(abs(climb) / 10))
				for i = 0, n do
					pts[#pts + 1] = { mx + (if i == 0 or i == n then 0 else (g.rnd() - 0.5) * 8), y - climb * i / n }
				end
				g.fx.add(0.5, function(ctx, k)
					ctx:alpha(if k < 0.6 then 1 else (1 - k) / 0.4)
					drawCrack(ctx, pts, mx, 9999, tone, k < 0.3)
					ctx:alpha(1)
				end)
			end
			for i = -1, 1 do
				g.fx.spike(mx + i * 7, my, 7, 14 + (1 - abs(i)) * 10, tone, { life = 0.45, lean = i * 3 })
			end
			g.fx.pop(mx, my - 10, tone, { r = 9, life = 0.2 })
			g.fx.shards(mx, my - 6, 6, tone, { kind = "tri", speed = 80, up = 110, life = 0.5 })
		end)
	end
	-- 양쪽으로 번지는 금 — 0.4초에 화면 끝까지, 그 뒤 빛이 바래며 사라진다
	for _, side in { -1, 1 } do
		local pts, branches = crackLine(x0, y, side, g.rnd)
		g.fx.add(1.1, function(ctx, k)
			local t = k * 1.1
			local reach = min(CRACK_W, t * CRACK_SPEED)
			local glow = (t * 12) % 1 < 0.5 -- 깜빡이는 속
			ctx:alpha(if t < 0.75 then 1 else max(0, (1.1 - t) / 0.35))
			drawCrack(ctx, pts, x0, reach, tone, glow)
			for _, b in branches do
				if b.at <= reach then
					drawCrack(ctx, b.pts, x0, 9999, tone, glow)
				end
			end
			ctx:alpha(1)
		end)
	end
end

local skills = {
	{ id = "ax_slam", key = "Q", ground = true, shot = 1.4, holdFor = 1.15, segs = { { clip = "smash", from = 0, to = 3, loopFrom = 2, fps = 16, charge = true, per = 0.2, walk = 0.5, turn = true }, { clip = "smash", from = 4, fps = 18, ev = { [7] = slam } } } },
	-- 도끼 내려찍기(위 chop): 도끼를 등 뒤로 젖힌 채 모은다(atk3 12~14장) → 떼면 머리 위에서 내려찍는다(15장)
	{ id = "ax_combo", key = "A", shot = 1.63, holdFor = 1.52, segs = { { clip = "atk3", from = 12, to = 14, loopFrom = 13, fps = 14, charge = true, per = 0.3, walk = 0.5, turn = true }, { clip = "atk3", from = 15, to = 22, fps = 18, ev = { [15] = chop } } } },
	{
		id = "ax_crescent",
		key = "W",
		shot = 1.27,
		holdFor = 1.12,
		segs = {
			{ clip = "atk1", from = 0, to = 2, loopFrom = 1, fps = 14, charge = true, per = 0.2, walk = 0.5, turn = true },
			{ clip = "atk1", from = 3, fps = 16, ev = { [3] = function(g)
				-- 모은 단계만큼 큰 초승달 하나(2026-10-28 리마스터 — 전에는 끝까지 모으면 셋으로 갈라졌다)
				local dir, tone, lv = g.dir, g.tone, g.lv
				local r = 15 + lv * 6 -- 사냥이 넓게(2026-10-28 — 끝까지(4단계) 모으면 높이 86 · 262도트를 간다. 전에는 70 · 232 — 제가 정한 값)
				g.fx.streaks(g.fwd(20), g.y - 2, 6 + lv * 2, -dir, tone, { w = 30 + lv * 6 })
				g.shot({
					x = g.fwd(16),
					y = g.y - 11 - lv * 5,
					vx = dir * (230 + lv * 30),
					life = 0.75,
					w = 14 + lv * 3,
					h = 30 + lv * 14,
					dmg = 4 + lv * 2,
					o = { kb = 60 + lv * 10 },
					every = { 0.04, function(p)
						g.fx.shards(p.x - dir * 6, p.y + (g.rnd() - 0.5) * (18 + lv * 8), 1, tone, { speed = 30, up = 10, life = 0.35 })
					end },
					draw = function(ctx, p)
						poly(ctx, crescentPts(p.x - dir * 8, p.y, r, r * 0.55, -75, 75, dir), if p.t / p.life > 0.8 then tone.n else tone.l)
						poly(ctx, crescentPts(p.x - dir * 8, p.y, r, r * 0.2, -55, 55, dir), tone.w)
					end,
					finish = function(p)
						g.fx.shards(p.x, p.y, 8 + lv * 2, tone, { kind = "mix" })
					end,
				})
			end } },
		},
	},
	-- 쪼개기(2026-10-28 리마스터 — 전에는 두 번 쪼갰다): 도끼를 뒤로 젖혀 모았다가(atk3 6~8장) 위에서 아래로 한 번 크게 쪼갠다 — 맞은 적에게 "갈라짐"
	{ id = "ax_rend", key = "S", shot = 1.63, holdFor = 1.52, segs = {
		{ clip = "atk3", from = 6, to = 8, loopFrom = 7, fps = 14, charge = true, per = 0.3, walk = 0.5, turn = true },
		{ clip = "atk3", from = 9, to = 14, fps = 18, ev = { [9] = function(g)
			local lv, tone = g.lv, g.tone
			local x = g.fwd(24)
			g.fx.cut(x, g.y - 14 - lv * 3, 46 + lv * 10, 84, tone, { th = 4 + lv, life = 0.28 })
			g.fx.cut(x, g.y - 1, 24 + lv * 8, 0, tone, { th = 2, life = 0.3 }) -- 땅의 금
			g.fx.shards(x, g.y - 10, 8 + lv * 3, tone, { kind = "bar", up = 20, speed = 110 })
			for _, m in g.hit(0, 46 + lv * 10, 44, 4, 10, { stop = 0.05 + lv * 0.02 }) do
				m.rend = 5
			end
			if lv >= 2 then
				g.shake(1, 0.1)
			end
		end } },
	} },
}

-- 돌격(3차 이동기 — 예전 「도약 강타」 · 2026-10-25 사용자 "샐래맨더도 불꽃돌진 일반이동기로 쿨타임달고 보스기 추가 … 액시온도 도약강타 일반 이동기로 바꾸고 앞으로 돌진하는스킬로 바꾸고 쿨타임달고 보스기 새로 만들어"): 피해는 없다(리븐 · 리퍼와 같게 — 마스터 5 · 다시 쓰기 5초 · 공중에서도).
--  도끼를 앞세우고 아주 짧은 순간이동을 steps번(0.03초마다 · 잔상 · 발밑에 튀는 흙먼지) · 끝에서 작은 고리 · 흔들림. 거리는 스킬 레벨마다(공방 combat.js의 MOVECAST → moveCast.dist)
local function assault(g)
	local mc = COMBAT.moveCast and COMBAT.moveCast.ax_leap
	local steps = if mc then mc.steps else 6
	local total = if mc then mc.dist[math.clamp(g.sk("ax_leap"), 1, #mc.dist)] else 90
	local tone = g.tone
	for i = 0, steps - 1 do
		g.after(i * 0.03, function()
			g.ghost()
			g.teleport(g.fwd(total / steps))
			g.fx.shards(g.x - g.dir * 6, g.y - 1, 2, tone, { kind = "dot", dir = -g.dir, spread = 0.5, speed = 50, up = 30, life = 0.3 })
		end)
	end
	g.after(steps * 0.03, function()
		g.fx.ring(g.fwd(10), g.y, 3, 18, tone, { life = 0.2 })
		g.shake(1, 0.08)
	end)
end
-- 천근 내려치기(3차 보스기 — 2026-10-28 리마스터, 예전 「회전 내려치기」 세 번): 머리 위로 치켜든 도끼(atk3 0~2장)에 힘을 모았다가 앞의 적을 한 번 무겁게 내려친다(3장)
--  큰 반달 자국 · 내리꽂는 빛줄기 · 땅의 금 · 파편
local function heavy(g)
	local lv, tone = g.lv, g.tone
	local x = g.fwd(28)
	g.fx.slash(g.fwd(10), g.y - 16, g.dir, (42 + lv * 8) * g.big, 150, -45, tone, { thick = 10 + lv * 2, life = 0.3 })
	g.fx.beam(x, g.y, 8 + lv * 2, 50 + lv * 14, tone, { life = 0.22 })
	g.fx.cut(x, g.y - 1, 40 + lv * 10, 0, tone, { th = 3, life = 0.4 })
	g.fx.shards(x, g.y - 4, 12 + lv * 4, tone, { kind = "bar", up = 70, speed = 120 })
	g.hit(0, 54 + lv * 10, 50, 4, 10, { stop = 0.08 + lv * 0.02, kb = 60 })
	if lv >= 2 then
		g.shake(2, 0.12)
	end
end
-- 대지 분쇄(3차 사냥기 — 2026-10-28 리마스터, 예전 「몰아치기」): 누르고 있는 동안 도끼를 치켜들고 힘을 모은다 — 그동안 제 빠르기로 걷고 · 뛰고 · 대쉬한다(2026-10-25 사용자 "몰아치기 는 범위늘리고 키다운하는동안 점프 대쉬 할수있게해 이속도 원래이속으로 다닐수있고" 그대로).
--  떼면(또는 끝까지 모이면) 몸 둘레의 땅을 한 번에 내려찍는다 — 모은 단계만큼 넓다(±64 + 20 x 단계 — 4단계면 ±144. 같은 날 사냥이 넓게 14 → 20 · 제가 정한 값)
local function shatter(g)
	local lv, x, y, tone = g.lv, g.x, g.y, g.tone
	local w = 64 + lv * 20
	local n = 3 + lv
	g.fx.ring(x, y, 8, w, tone)
	g.fx.ring(x, y, 4, 30 + lv * 6, tone, { delay = 0.06 })
	g.fx.shards(x, y - 6, 12 + lv * 5, tone, { kind = "mix", up = 140, speed = 130 })
	for i = 1, n do
		for _, s in { -1, 1 } do
			g.fx.spike(x + s * i * w / n, y, 10, max(8, 26 - i * 3), tone, { delay = i * 0.03, lean = s * 4 })
		end
	end
	g.hit(-w, w, 46, 4, 10, { lift = 220, stop = 0.05 })
	if lv >= 2 then
		g.shake(1, 0.12)
	end
end
-- 월광 처단(4차 보스기 — 2026-10-28 리마스터, 예전 「처단」의 쌓아 터뜨리기): 치켜든 도끼에 모았다가 내려찍으면 맞은 적마다 하늘에서 달빛 기둥이 내리꽂힌다 — 한 방
local function execute(g)
	local lv, tone = g.lv, g.tone
	local x = g.fwd(22)
	g.fx.cut(x, g.y - 16, 34 + lv * 8, 90, tone, { th = 3 + lv, life = 0.2 })
	g.fx.ring(x, g.y, 3, 24 + lv * 8, tone, { life = 0.24 })
	for _, m in g.hit(0, 42 + lv * 10, 44, 4, 12, { stop = 0.06 + lv * 0.02 }) do
		local sc = if m.boss then 2 else 1
		local mx, cy = m.x, m.y - m.h - 6 * sc
		g.fx.beam(mx, m.y, (6 + lv * 2) * sc, 90 + lv * 20, tone, { life = 0.3 })
		g.fx.add(0.2, function(ctx, k)
			poly(ctx, starPts(mx, cy, (9 + lv * 2) * sc * (1 - k * 0.6), 0.39 + k), if k < 0.5 then tone.w else tone.l)
		end)
		g.fx.shards(mx, cy, 10 + lv * 3, tone, { kind = "tri", up = 110, speed = 120 })
	end
	if lv >= 2 then
		g.shake(1, 0.12)
	end
end

local more = {
	buff("ax_breath", "1"),
	-- 대지 분쇄(위 shatter): 모으는 동안 걷고 · 뛰고 · 대쉬한다
	{ id = "ax_whirl", key = "E", shot = 1.4, holdFor = 1.15, segs = {
		{ clip = "smash", from = 0, to = 3, loopFrom = 2, fps = 16, charge = true, per = 0.2, walk = 1, free = true, turn = true },
		{ clip = "smash", from = 4, fps = 18, ev = { [7] = shatter } },
	} },
	{ id = "ax_wheel", key = "D", shot = 1.63, holdFor = 1.52, segs = { -- 천근 내려치기(위 heavy)
		{ clip = "atk3", from = 0, to = 2, loopFrom = 1, fps = 14, charge = true, per = 0.3, walk = 0.5, turn = true },
		{ clip = "atk3", from = 3, to = 8, fps = 18, ev = { [3] = heavy } },
	} },
	{ id = "ax_leap", key = "V", air = true, shot = 0.3, segs = { -- 돌격(이동기 — 위 assault)
		{ clip = "dash", loop = true, dur = 0.2, fps = 20, float = true, start = assault },
	} },
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
	-- 달 가르기: 도끼를 등 뒤로 젖혀 모았다가(2026-10-28 리마스터 — 모을 수 있게) 화면 높이의 초승달이 앞으로 쓸고 간다 — 모은 만큼 크다
	{ id = "ax_moonfall", key = "R", shot = 1.27, holdFor = 1.12, segs = {
		{ clip = "atk3", from = 12, to = 14, loopFrom = 13, fps = 14, charge = true, per = 0.2, walk = 0.5, turn = true },
		{ clip = "atk3", from = 15, to = 22, fps = 18, ev = { [15] = function(g)
			local dir, tone, lv = g.dir, g.tone, g.lv
			local k = 1 + lv * 0.08 -- 끝까지(4단계) 모아도 1.32배(화면 높이를 넘지 않게)
			g.shot({
				x = g.fwd(10),
				y = g.y - 40 * k,
				vx = dir * 300,
				life = 0.5 + lv * 0.08, -- 끝까지 모으면 246도트를 간다(같은 날 사냥이 넓게 0.05 → 0.08 · 제가 정한 값)
				w = 26 * k,
				h = 116 * k,
				dmg = 14,
				ghost = true,
				o = { kb = 80, lift = 150 },
				every = { 0.03, function(p)
					g.fx.shards(p.x - dir * 10, p.y + (g.rnd() - 0.5) * 90 * k, 1, tone, { speed = 20, up = 0, life = 0.4, kind = "bar" })
				end },
				draw = function(ctx, p)
					poly(ctx, crescentPts(p.x - dir * 44 * k, p.y, 60 * k, 24 * k, -72, 72, dir, 9), tone.l)
					poly(ctx, crescentPts(p.x - dir * 44 * k, p.y, 60 * k, 9 * k, -60, 60, dir, 9), tone.w)
				end,
			})
			if lv >= 2 then
				g.shake(1, 0.1)
			end
		end } },
	} },
	{ id = "ax_execute", key = "F", ground = true, shot = 1.8, holdFor = 1.55, segs = { -- 월광 처단(위 execute)
		{ clip = "smash", from = 0, to = 3, loopFrom = 2, fps = 16, charge = true, per = 0.3, walk = 0.5, turn = true },
		{ clip = "smash", from = 4, fps = 22, ev = { [7] = execute } },
	} },
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
	{ id = "ax_crack", key = "B", shot = 1.0, segs = { { clip = "smash", fps = 14, start = function(g) -- 월광 균열(위 crack)
		g.dim(0.45, 1.4)
	end, ev = { [7] = crack } } } },
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
	{ id = "ax_echo", key = "T" }, -- 사출기: 켜고 끈다(끝까지 모아 친 한 방에 — 서버 sim/room.luau의 kitAfter가 정해 procs.echo로 알린다)
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
	grow = 0.15, -- 모은 단계마다 몸을 그만큼 크게 그린다(화면만 — 판정은 그대로 · client/lune/cast.luau의 look · 2026-10-28 리마스터 고르심 「모을 때마다」)
	init = function(g)
		g.s = { step = 0 }
	end,
	chargeMax = levelsOf,
	chargeFull = function(g)
		return g.has("ax_fullmoon")
	end,
	mult = function(g)
		return 1 + (if g.has("ax_roar") then 0.1 else 0) + (if g.has("ax_fullmoon") then 0.3 else 0) + (if g.has("c_hero") then 0.05 else 0)
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
	-- 서버(sim/room.luau의 kitAfter)가 알리는 따로 나가는 타: 이름 → 그 이펙트.
	--  o = { sx, sy(날아오는 자리) · land(닿은 순간에 부를 것 — 피해 숫자가 이때 뜬다) } — 같은 때에 온 것은 echoCut이 차례로 늦춘다
	procs = {
		echo = function(g, m, o)
			echoCut(g, m, o)
		end,
	},
	skills = skills,
}

return axion
