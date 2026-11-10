-- 살라맨더 — 불주먹. 핵심 장치: 열기(주먹이 맞으면 오르고 쉬면 식는다 · 달아오르면 기술마다 불꽃이 한 번 더 · 폭주면 가득 찬 채 고정).
--  리마스터 둘째 판(2026-11-04): 터뜨리는 스킬(11-03의 큰 한 방 셋 — 열 방출 · 용광로 주먹 · 작은 태양)을 뺐다. 열기가 가득 차면 머리 위에 불꽃 갓이 넘실댄다(drawBack — 캐시 무기의 색).
--   뺀 셋의 이름표는 강화판을 키우는 패시브(폭열 · 용광로 심장 · 백열)가 되었다(퀵슬롯에서는 빠지고 찍은 포인트는 남는다)
--  셋째 판(같은 날 사용자 "열기가 가득차서 공격하면 열기폭발이 터지는게 아니라 강화된 공격이 나가는거라고 게이지를 가득채우면 불길에 휩싸이면서 사냥기, 보스기 가 강화되고
--   강화된 스킬들은 퀵슬롯에서 빛나는거야 그리고 그 스킬을 사용하면 열기가 모두 소모되면서 원래스킬이아니라 더 강력한 스킬이 나가는거라고"): 둘째 판의 열기 폭발을 뺐다 →
--   가득 찬 채 사냥기 · 보스기를 쓰면 열기를 모두 써서 그 판이 「강화판」(g.s.enh — 기술마다 더 큰 모습 · 넓은 범위)으로 나간다. 서버 sim/kit.luau의 Kit.empower가 정하고 그 판의 모든 타에 배수를 곱한다
--   (화면은 cast.luau의 start가 그 판의 첫 구간에서 g.s.enh를 놓는다 — 내 것은 아래 ready로 정해 서버에 함께 보내고, 남의 것은 서버가 알린다). 사냥기 · 보스기의 퀵슬롯 칸이 빛난다(hud.luau)
--  공방 시험 탭의 dino-workshop/js/lune/kits/salamander.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   달아오름 50부터(1차) → 40부터 · 더 빨리 오르고 천천히 식는다(끓는 피)
--   불티: 맞을 때마다 하나(1차) → 달아오름 동안 둘(겹불티) → 옆의 적으로 한 번 옮겨붙는다(옮겨붙는 불티) → 세모 날개의 불새(불새)
--  열기의 수치(오르는 양 · 식는 빠르기 · 달아오름의 기준)는 설계 자료(COMBAT.kit.salamander.core — design/combat.js의 KIT1)를 쓴다.
--  옮기며 바뀐 것: end → finish · until → till · { ...flame, … } → flameWith · 함수 선언의 끌어올림 → 아래 도우미의 이름을 먼저(tongue · pillar).
--  화염 광선의 광선(시트의 그림 waveproj)은 sprite를 단 날아가는 것 — 화면은 cast.luau의 g.shot이 그 그림을 띄운다(2026-11-04 4차로 옮기며: 그 전 1차일 때는 COMBAT.skills의 shots가 그렸다).
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local poly, disc, starPts, drawFist, drawBird = Fx.poly, Fx.disc, Fx.starPts, Fx.drawFist, Fx.drawBird
local line = Fx.line -- 화룡 승천의 뿔(2026-10-24)
local dash, buff, flame = Common.dash, Common.buff, Common.flame
local floor, sin, cos, min, max, abs, sqrt = math.floor, math.sin, math.cos, math.min, math.max, math.abs, math.sqrt
local function R(v: number): number
	return floor(v + 0.5)
end
local HEAT = COMBAT.kit.salamander.core -- gain · tier · max · hot · cool · decay · enh(강화판 — x)
local tongue, pillar -- (아래 도우미 — 불덩이 던지기가 먼저 부른다)

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
	return g.s.heat >= hotAt(g) or g.s.hotOn == true or g.has("sl_overheat") -- (hotOn = 서버의 달아오름 — 열기를 써도 이어진다 · 2026-11-07)
end
-- 가득 찼는가(사냥기 · 보스기가 강화판으로 나간다 — 폭주 동안은 늘 가득)
local function full(g): boolean
	return g.s.heat >= HEAT.max or g.has("sl_overheat")
end
-- 별 모양 섬광(강화판의 큰 타 — 흰 심이 잦아들며 분홍으로)
local function flash(g, x: number, y: number, r: number, life: number?)
	local tone = g.tone
	g.fx.add(life or 0.22, function(ctx, k)
		poly(ctx, starPts(x, y, r * (1 - k * 0.6), k), if k < 0.4 then tone.w else tone.l)
	end)
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

local function fist(g, dmg: number) -- 앞으로 날아가는 각진 주먹 모양 불길(강화판: 1.5배 · 꼬리 불티)
	local dir, tone, enh = g.dir, g.tone, g.s.enh == true
	-- 날아가는 거리 0.42 → 0.55초 = 113 → 149점(2026-11-10 사용자 "살라 4차 보스기 가로 사거리 조금더 길어져야한다" · 제가 정한 것)
	g.shot({ x = g.fwd(14), y = g.y - 9, vx = dir * 270, life = 0.55, w = if enh then 20 else 14, h = if enh then 24 else 18, dmg = dmg, o = { kb = 60 }, draw = function(ctx, p)
		drawFist(ctx, p.x, p.y, if enh then 9 else 6, dir, tone)
	end, every = if enh then { 0.04, function(p)
		g.fx.shards(p.x - dir * 8, p.y, 1, tone, flameWith({ speed = 16 }))
	end } else nil, finish = function(p)
		g.fx.pop(p.x, p.y, tone, { r = if enh then 9 else 6 })
	end })
end

-- 불덩이 던지기의 불덩이 하나(2026-10-27 — 공방 kits/salamander.js의 meteorOrb를 줄마다 옮긴 것): 손 높이로 곧게 140점 날아갔다가 0.6초 만에 손으로 돌아온다
--  (그사이 영웅이 움직이면 그 손으로) · 불덩이마다 한 번 꿰뚫어 태운다(2026-11-04 1차로 옮기며 — 그 전 3차에서는 가는 길 · 오는 길에 한 번씩) · dmg = 그 불덩이의 몫(셋째는 4).
--  1차의 피해는 서버가 design/combat.js의 SKILLS.sl_meteor 상자로 정한다(world.luau) — 여기 dmg는 공방과 같게 둔 것
local ORB = { reach = 140, life = 0.6, up = 12, enh = 200 } -- enh = 강화판이 날아가는 거리(2026-11-04 — 강화된 사냥기는 범위가 엄청나게)
-- 화염 해일의 파도(2026-11-04 — 2차 사냥기 · 사용자 "4차 레이저 두께가 두꺼워져야하고 왜 뒤로도 불꽃이 터지냐 2차 사냥기 화염해일의 범위가 너무 넓잖아 밸류를 조절하라고 이전에 조정전 4차사냥기일때보다 훨씬좋잖아 평균 2차 사냥기 밸류에 맞춰야지"):
--  다른 직업의 2차 사냥기(초승달 가르기 · 질풍 일섬 · 회전 낫 · 달빛 파도 — 한쪽으로 120 ~ 260점 · 높이 22 ~ 34)에 맞춰 양쪽 90점씩(모두 180) · 위 30 · 아래 10으로 줄였다(그 전 같은 날: 한쪽 180 · 위 72 · 아래 32 — 조정 전 4차 때의 180 · 위아래 17보다 넓었다).
--  up · down = 파도가 지나는 자리의 위 · 아래로 맞는 높이 · speed x life = 한쪽으로 가는 거리 · tri = 맨 앞 불 세모의 높이 · n = 세모 수 · gap = 세모 사이 · hw = 세모 밑변의 반
--  pillar = 강화판에서 지나는 자리마다 솟는 불기둥의 높이. 값은 제가 정한 것(공방 kits/salamander.js의 TIDE와 같다)
local TIDE = {
	base = { up = 30, down = 10, speed = 180, life = 0.5, w = 28, tri = 26, n = 5, gap = 10, hw = 7, pillar = 0 },
	enh = { up = 50, down = 20, speed = 250, life = 0.6, w = 36, tri = 36, n = 6, gap = 12, hw = 9, pillar = 40 },
}
-- 굵은 광선(4차 화염 광선 — 2026-11-04 사용자 "4차 레이저 두께가 두꺼워져야하고" · 공방 kits/salamander.js의 thickBeam과 같다): 시트의 광선(waveproj · 16점)을 이 직업의 네 겹으로 두께 th까지 감싼다 —
--  손에서 끝까지 0.06초에 뻗고 · 위아래 가장자리가 일렁이다가 · 끝 무렵 가늘어지며 사라진다
local BEAM_LAYERS = { { 1, "d" }, { 0.74, "n" }, { 0.46, "l" }, { 0.18, "w" } }
local function thickBeam(g, x: number, y: number, dir: number, len: number, th: number, life: number?)
	local tone, N, life0 = g.tone, 14, life or 0.42
	g.fx.add(life0, function(ctx, k)
		local reach, thin, t = len * min(1, k / 0.15), if k < 0.6 then 1 else 1 - (k - 0.6) / 0.4, k * life0
		for _, layer in BEAM_LAYERS do
			local h = th * layer[1] * thin
			if h >= 1 then
				local top, bot = {}, {}
				for i = 0, N do
					local u = i / N
					local taper = if u < 0.08 then 0.4 + 0.6 * u / 0.08 else 1
					table.insert(top, { x + dir * reach * u, y - (h / 2) * taper * (0.8 + 0.2 * sin(t * 40 + i * 1.7)) })
					table.insert(bot, 1, { x + dir * reach * u, y + (h / 2) * taper * (0.8 + 0.2 * sin(t * 36 + i * 2.3)) })
				end
				for _, q in bot do
					table.insert(top, q)
				end
				poly(ctx, top, tone[layer[2]])
			end
		end
	end)
end
local function meteorOrb(g, dmg: number?)
	local dir, tone, enh = g.dir, g.tone, g.s.enh == true -- 강화판: 큰 불덩이 · 꼬리 불꽃 · 140 → 200점 · 맞는 크기 16 x 16 → 30 x 60 · 돌아서는 끝에서 불기둥
	local r, reach = if enh then 7 else 5, if enh then ORB.enh else ORB.reach
	local function hand(): number
		return g.fwd(8)
	end
	g.fx.ring(hand(), g.y - ORB.up, 1, 8, tone, { squash = 1, back = false, life = 0.14 })
	g.shot({
		x = hand(),
		y = g.y - ORB.up,
		life = ORB.life,
		w = if enh then 30 else 16,
		h = if enh then 60 else 16,
		dmg = dmg or 3,
		o = {},
		every = { 0.03, function(p)
			g.fx.shards(p.x, p.y, if enh then 2 else 1, tone, flameWith({ speed = 12, up = 0, life = 0.22 }))
		end },
		update = function(p)
			local k = min(1, p.t / p.life)
			p.k = k
			p.x = hand() + dir * reach * sin(math.pi * k)
			p.y = g.y - ORB.up
			if k > 0.5 and not p.turned then
				p.turned = true
				if enh then
					pillar(g, p.x, g.y, 14, 54, { life = 0.45, seed = p.x })
				end
			end
		end,
		draw = function(ctx, p)
			if enh then -- 꼬리 불꽃: 나아가는 쪽의 반대로
				tongue(ctx, p.x, p.y, 8, 13, tone, { ang = if dir * (if (p.k or 0) < 0.5 then 1 else -1) > 0 then 172 else 8, core = false })
			end
			disc(ctx, p.x, p.y, r, tone.n)
			disc(ctx, p.x, p.y, r - 2, tone.l)
			ctx:style(tone.w)
			ctx:rect(R(p.x) - 1, R(p.y) - 1, if enh then 3 else 2, if enh then 3 else 2)
		end,
		finish = function(_p) -- 받기: 손에서 작게 번쩍
			g.fx.ring(hand(), g.y - ORB.up, 1, 7, tone, { squash = 1, back = false, life = 0.12 })
			g.fx.shards(hand(), g.y - ORB.up, 4, tone, flameWith({ speed = 50, life = 0.25 }))
		end,
	})
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
function tongue(ctx, x: number, y: number, w: number, h: number, tone, o)
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
function pillar(g, x: number, y: number, w: number, h: number, o)
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
	local tone, grow = g.tone, if g.s.enh then 11 else 7 -- 강화판: 불덩이가 더 크게 자란다
	g.shot({ x = g.x, y = g.y - 33, life = dur, update = function(p)
		p.x, p.y = g.x, g.y - 33
	end, draw = function(ctx, p)
		local k = p.t / p.life
		local r = R(3 + grow * k)
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
--  3차 사냥기(2026-11-04 사용자 "스킬을 재배치해서 밸류랑 스킬퍼뎀을좀 재조정하자 … 3차 사냥기를 화염강타" — 그 전 2차): 보통 판도 넓게 — 불기둥 여섯 쌍(달아오름이면 일곱) · 양옆 78(94) → 130(151) · 위 44 → 56
--  강화판(2026-11-04 — "강화공격 사냥기 적용될때 사냥범위가 엄청나야하고" · 같은 날 "y축을 과도하게 길게 늘이지마"): 불기둥 일곱 쌍(양옆 190 · 위 96 — 불기둥이 그 끝 · 그 높이까지 선다) · 불꽃 다발 아홉 · 큰 섬광
local SCORCH = { -17, -6, 4, 13, 22 }
local function slam(g)
	local x, y, tone, enh = g.x, g.y, g.tone, g.s.enh == true
	local big = hot(g) or enh
	local n = if enh or big then 7 else 6
	local step = if enh then 27 else 21
	local reach, up = if enh then 190 else n * step + 4, if enh then 1.6 else 1.15
	g.fx.add(0.42, function(ctx, k)
		local grow = if k < 0.2 then k / 0.2 else 1 - (k - 0.2) / 0.8
		for i = 0, (if enh then 8 else 6) do
			tongue(ctx, x, y, if enh then 15 else 13, (if big then 48 else 38) * up * grow * (if i % 2 == 1 then 0.75 else 1), tone, { ang = if enh then 18 + i * 18 else 24 + i * 22, sway = sin(k * 20 + i) * 2, core = k < 0.5 })
		end
		if k < 0.3 then
			poly(ctx, starPts(x, y - 8, (if enh then 50 else 30) * (1 - k * 2), k * 2), tone.w)
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
			local px = x + sd * i * step
			pillar(g, px, y, (if enh then 18 else 15) - i, if enh then 88 - i * 6 else (if big then 64 else 54) - i * 5, { delay = i * (if enh then 0.04 else 0.045), seed = i * sd })
			g.after(i * 0.05, function()
				g.fx.shards(px, y - 10, 2, tone, flame)
			end)
			g.after(i * 0.05 + 0.3, function()
				smoke(g, px, y - 6, 2)
			end)
		end
	end
	g.fx.shards(x, y - 6, if enh then 34 else 24, tone, flameWith({ speed = if enh then 220 else 180, up = 100 }))
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
	g.hitAt(x, y, reach, if enh then 96 else 56, 8, { lift = 230, stop = 0.08 })
	g.shake(1, 0.12)
end
-- 화산권(4차 극딜기 sl_dragon · 다시 쓰기 60초) — 2026-10-26 다시 지음(사용자 "살라맨더 4차 60초쿨 극딜기 … 돌진하는 매커니즘을 좀 빼고 스킬설계를 다시해봐"):
--  전에는 「화염 질주」 — 310도트를 돌진하며 불길을 남기고 끝에서 터졌다(쓰면 몸이 멀리 가 버려 보스 앞에서 쓰기 어려웠다).
--  이제는 제자리에서: 땅을 내려치면(slam) 앞의 땅이 갈라지며 달아오르고 → 거대한 불주먹이 땅에서 솟구쳐 적을 띄운다(한 번) → 꼭대기에서 크게 터진다(한 번) → 그 자리가 4초 동안 불탄다.
--  솟는 주먹은 살라맨더의 주먹 모양(drawFist)을 위로 세운 것 · 둘레의 불꽃 혀와 불기둥 · 연기는 이 직업의 것. 이름 · 모양 · 숫자는 제가 정한 것
local VOLCANO_AT, VOLCANO_W = 70, 150 -- 솟는 자리(내 앞 몇 도트) · 터지고 불타는 너비
local function upFist(ctx, x: number, y: number, s: number, tone) -- 위로 치켜든 주먹(앞에서 본 모습): 팔목 · 어두운 테 · 손가락 마디 넷(밝은 윗면 · 사이의 금) · 가로지르는 엄지 · 반짝임. (x, y) = 주먹의 가운데
	poly(ctx, { { x - s * 0.55, y + s * 0.6 }, { x + s * 0.55, y + s * 0.6 }, { x + s * 0.8, y + s * 2.6 }, { x - s * 0.8, y + s * 2.6 } }, tone.d) -- 팔목
	poly(ctx, { { x - s * 0.45, y + s * 0.6 }, { x + s * 0.2, y + s * 0.6 }, { x + s * 0.3, y + s * 2.6 }, { x - s * 0.6, y + s * 2.6 } }, tone.n)
	local function box(x0: number, y0: number, x1: number, y1: number, c, cut: number)
		poly(ctx, { { x0 + cut, y0 }, { x1 - cut, y0 }, { x1, y0 + cut }, { x1, y1 - cut }, { x1 - cut, y1 }, { x0 + cut, y1 }, { x0, y1 - cut }, { x0, y0 + cut } }, c)
	end
	box(x - s - 1, y - s * 0.85 - 1, x + s + 1, y + s * 0.85 + 1, tone.d, s * 0.35) -- 어두운 테
	box(x - s, y - s * 0.85, x + s, y + s * 0.85, tone.n, s * 0.3) -- 주먹
	local fw = s * 0.5
	for i = 0, 3 do -- 손가락 마디 넷: 밝은 윗면 · 사이의 어두운 금
		local fx0 = x - s + i * fw
		box(fx0 + 1, y - s * 0.8, fx0 + fw - 1, y - s * 0.15, tone.l, 1)
		if i > 0 then
			line(ctx, fx0, y - s * 0.85, fx0, y + s * 0.05, tone.d, 1)
		end
	end
	box(x - s * 0.95, y + s * 0.12, x + s * 0.35, y + s * 0.5, tone.l, 1) -- 엄지(앞을 가로지른다)
	line(ctx, x - s * 0.95, y + s * 0.52, x + s * 0.35, y + s * 0.52, tone.d, 1)
	ctx:style(tone.w)
	ctx:rect(R(x - s * 0.8), R(y - s * 0.72), 2, 1) -- 반짝임
end
local function volcanoCrack(g) -- 쓰기 시작: 앞의 땅이 갈라지며 붉게 달아오른다(솟을 자리를 미리 알린다)
	local cx, y, tone = g.fwd(VOLCANO_AT), g.y, g.tone
	g.fx.add(0.55, function(ctx, k)
		local w = VOLCANO_W / 2 * min(1, k * 2.5)
		for i = -6, 6 do
			local x0 = cx + i * w / 6
			local x1 = cx + (i + 1) * w / 6
			if i < 6 then
				line(ctx, x0, y + (if i % 2 == 0 then 0 else 1), x1, y + (if i % 2 == 0 then 1 else 0), if k > 0.6 and i % 2 == 0 then tone.w else tone.l, 1)
			end
		end
		for i = -3, 3 do
			tongue(ctx, cx + i * w / 3, y, 5, (4 + 5 * abs(sin(k * 14 + i))) * min(1, k * 2), tone, { core = false })
		end
	end, { back = true })
end
local function volcano(g) -- 내려친 순간: 솟는 불주먹(한 번) → 꼭대기에서 터짐(한 번) → 불타는 땅
	local cx, y, tone = g.fwd(VOLCANO_AT), g.y, g.tone
	g.shake(4, 0.2)
	g.fx.add(0.2, function(ctx, k)
		poly(ctx, starPts(cx, y - 4, 34 * (1 - k * 0.6), k * 2), if k < 0.5 then tone.w else tone.l)
	end)
	g.fx.add(0.42, function(ctx, k) -- 땅에서 솟구치는 거대한 불주먹 + 감싸는 불꽃 혀
		local rise = if k < 0.55 then 1 - (1 - k / 0.55) ^ 2 else 1
		local fy = y - 10 - 56 * rise
		for i = -2, 2 do
			tongue(ctx, cx + i * 9, y, 14 - abs(i) * 2, (66 - abs(i) * 14) * rise, tone, { sway = sin(k * 24 + i) * 3, core = i == 0 })
		end
		upFist(ctx, cx, fy, 13, tone)
	end)
	g.fx.shards(cx, y - 10, 18, tone, flameWith({ speed = 120, up = 220 }))
	g.hitAt(cx, y, VOLCANO_W / 2 - 5, 100, 8, { lift = 280, stop = 0.06 }) -- 솟구침: 띄운다
	g.after(0.3, function() -- 꼭대기에서 터진다: 큰 섬광 · 양옆으로 차례로 솟는 불기둥 · 불티 · 연기
		local top = y - 66
		g.invert(0.08)
		g.shake(8, 0.4)
		g.fx.add(0.3, function(ctx, k)
			poly(ctx, starPts(cx, top, 64 * (1 - k * 0.7), k), if k < 0.4 then tone.w else tone.l)
		end)
		for i = -4, 4 do
			pillar(g, cx + i * 18, y, 16 - abs(i), 74 - abs(i) * 11, { delay = abs(i) * 0.04, life = 0.7, seed = i })
		end
		g.fx.shards(cx, top, 34, tone, flameWith({ speed = 240, up = 80 }))
		smoke(g, cx, y - 20, 8, 0.25)
		g.hitAt(cx, y, VOLCANO_W / 2, 90, 14, { kb = 120, stop = 0.1 }) -- 터짐
		fireZone(g, cx, y, VOLCANO_W, 4) -- 터진 자리가 4초 동안 불탄다
	end)
end

-- 화룡 승천(4차 광역기 · 다시 쓰기 12초 · 맵 전체 — 2026-10-24 사용자 "무니, 리븐 광역기 만든것처럼 엑시온, 리퍼, 살라맨더 4차 스킬포인트 조정해서 그 빈포인트로 투자하는 완전 멋진 광역기만들자"):
--  주먹을 내지르면(punch 4장) 불꽃 용이 주먹에서 뛰쳐나와 화면을 휘감아 난다 — 앞으로 화면 끝까지 → 위로 감아 돌아 뒤쪽 끝까지 → 하늘로 솟구친다(1.2초).
--  몸 = 마디 스물넷(머리에서 꼬리로 작아지는 불덩이 · 어두운 테 · 밝은 등 · 등 가시) · 머리 = 큰 불덩이 + 벌린 턱 · 뿔 둘 · 흰 눈 · 지나간 자리에 불티.
--  용의 머리가 지나가는 차례로 적마다 불꽃이 터진다. 판정은 쓰는 순간 한 번: 맵의 모든 적. 이름 · 모양 · 길은 제가 정한 것(화염 질주의 돌진 · 불새와 겹치지 않게 「하늘을 나는 용」으로)
local WYRM_T, WYRM_SEG = 1.2, 24
local WYRM_PATH = { { 10, -14 }, { 150, -40 }, { 300, -24 }, { 340, -84 }, { 180, -104 }, { -80, -76 }, { -290, -96 }, { -270, -170 }, { -90, -230 }, { 10, -340 } } -- (앞 · 위) 도트 — 앞 = 주먹 쪽
local function wyrmAt(x0: number, y0: number, dir: number, u: number)
	local n = #WYRM_PATH - 1
	local f = math.clamp(u, 0, 1) * n
	local i = math.min(n - 1, floor(f))
	local t = f - i
	local p0, p1, p2, p3 = WYRM_PATH[max(1, i)], WYRM_PATH[i + 1], WYRM_PATH[i + 2], WYRM_PATH[math.min(n + 1, i + 3)]
	local function cr(a: number, b: number, c: number, d: number): number -- 캣멀롬 곡선(점을 지나는 부드러운 길)
		return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
	end
	return x0 + dir * cr(p0[1], p1[1], p2[1], p3[1]), y0 + cr(p0[2], p1[2], p2[2], p3[2])
end
local function drawWyrm(ctx, x0: number, y0: number, dir: number, u: number, tone)
	for j = WYRM_SEG, 1, -1 do
		local uj = u - j * 0.011
		if uj > 0 then
			local x, y = wyrmAt(x0, y0, dir, uj)
			local r = max(2, floor(7 - j * 0.22))
			disc(ctx, x, y, r + 1, tone.d)
			disc(ctx, x, y, r, tone.n)
			disc(ctx, x, y - 1, max(1, r - 2), tone.l)
			if j % 3 == 0 then -- 등 가시
				poly(ctx, { { x - 2, y - r }, { x + 2, y - r }, { x, y - r - 4 } }, tone.l)
			end
		end
	end
	local hx, hy = wyrmAt(x0, y0, dir, u)
	local nx = wyrmAt(x0, y0, dir, min(1, u + 0.01))
	local f = if nx >= hx then 1 else -1 -- 머리는 나아가는 쪽을 본다
	disc(ctx, hx, hy, 9, tone.d)
	disc(ctx, hx, hy, 8, tone.n)
	disc(ctx, hx - f, hy - 2, 5, tone.l)
	poly(ctx, { { hx + f * 4, hy - 3 }, { hx + f * 15, hy - 6 }, { hx + f * 6, hy } }, tone.n) -- 벌린 턱(위)
	poly(ctx, { { hx + f * 4, hy + 2 }, { hx + f * 13, hy + 6 }, { hx + f * 5, hy + 5 } }, tone.d) -- 벌린 턱(아래)
	line(ctx, hx - f * 2, hy - 7, hx - f * 9, hy - 15, tone.l, 2) -- 뿔
	line(ctx, hx + f, hy - 8, hx - f * 4, hy - 17, tone.l, 2)
	disc(ctx, hx + f * 2, hy - 3, 1, tone.w) -- 눈
	disc(ctx, hx + f * 17, hy - 2, 3, tone.l) -- 입김
	disc(ctx, hx + f * 21, hy - 3, 2, tone.w)
end
local function wyrm(g)
	local x0, y0, dir, tone = g.fwd(10), g.y - 14, g.dir, g.tone
	g.shake(3, 0.3)
	local embers = {}
	for i = 1, 44 do
		embers[i] = { u = g.rnd(), dx = (g.rnd() - 0.5) * 10, dy = (g.rnd() - 0.5) * 10, c = if g.rnd() < 0.5 then tone.l else tone.n }
	end
	local life = WYRM_T + 0.5
	g.fx.add(life, function(ctx, k)
		local t = k * life
		for _, e in embers do -- 지나간 자리의 불티(위로 떠오르며 꺼진다)
			local age = t - e.u * WYRM_T
			if age > 0 and age < 0.45 then
				local ex, ey = wyrmAt(x0, y0, dir, e.u)
				ctx:alpha(1 - age / 0.45)
				ctx:style(e.c)
				ctx:rect(R(ex + e.dx), R(ey + e.dy - age * 30), 2, 2)
			end
		end
		ctx:alpha(if t < WYRM_T then 1 else max(0, (life - t) / 0.5))
		drawWyrm(ctx, x0, y0, dir, t / WYRM_T, tone)
		ctx:alpha(1)
	end)
	-- 판정은 여기 한 번: 맵의 모든 적 — 불꽃은 용의 머리가 그 적에게 가장 가까이 지나가는 때에
	for _, m in g.mobs() do
		g.hurt(m, 12, { stop = 0.08 })
		local mx, my = m.x, m.y - (m.h or 16) / 2
		local best, bu = math.huge, 0
		for s = 0, 60 do
			local px, py = wyrmAt(x0, y0, dir, s / 60)
			local d = (px - mx) ^ 2 + ((py - my) * 0.5) ^ 2
			if d < best then
				best, bu = d, s / 60
			end
		end
		g.after(bu * WYRM_T, function()
			g.fx.pop(mx, my, tone, { r = 9, life = 0.2 })
			g.fx.shards(mx, my, 7, tone, flame)
			g.fx.ring(mx, my + (m.h or 16) / 2, 3, 18, tone, { squash = 0.35, life = 0.3 })
		end)
	end
	g.after(WYRM_T * 0.78, function() -- 하늘로 솟구친다
		g.invert(0.05)
		g.shake(5, 0.3)
	end)
end

local skills = {
	{ id = "sl_beam", key = "R", shot = 0.46, segs = { { clip = "wave", fps = 18, ev = { [7] = function(g)
		local x, y, gy, dir, tone = g.fwd(12), g.y - 9, g.y, g.dir, g.tone -- 시트의 광선(182x16)을 주먹 높이에 그대로 깐다(그림 = cast.luau의 sprite)
		-- 4차 사냥기(2026-11-04 사용자 "… 4차 사냥기를 화염 광선으로" — 그 전 1차): 광선이 화면 끝까지(182 → 364 — 시트의 광선을 둘 잇는다) · 굵게(위 thickBeam — 두께 22 · 강화판 32) · 위로 22 → 34.
		--  강화판(사용자 "강화공격 사냥기 적용될때 사냥범위가 엄청나야하고"): 위로 66 · 광선을 따라 끝까지 차례로 불기둥 · 손에 별 모양 섬광. 앞으로만(같은 날 "왜 뒤로도 불꽃이 터지냐" — 뒤로도 쏘던 것을 뺐다)
		local enh, L = g.s.enh == true, 182
		thickBeam(g, x, y, dir, L * 2, if enh then 32 else 22)
		g.shot({ x = x, y = y, life = 0.42, sprite = "waveproj", dir = dir, fps = 14 })
		g.after(0.03, function()
			g.shot({ x = x + dir * 182, y = y, life = 0.39, sprite = "waveproj", dir = dir, fps = 14 })
		end)
		g.fx.streaks(x + dir * (L - 1), gy, 14, -dir, tone, { w = L * 2 - 12, h = 16 })
		local D = if enh then 40 else 28 -- 아래로 더(2026-11-04 사용자 "화염광선 하단판정이 더 후하게 들어가야해"): 발밑 6 → 34(강화판 46)까지 — hitAt의 상자는 y - h ~ y + 6이라 y를 D만큼 내리고 h에 D를 더한다
		for i = 0, 2 do
			g.after(i * 0.07, function()
				g.hitAt(x + dir * L, gy + D, L, (if enh then 66 else 34) + D, 3, if i == 2 then { kb = 120, dir = dir } else { dir = dir })
			end)
		end
		g.after(0.2, function()
			for i = 0, 17 do
				g.fx.shards(x + dir * (10 + i * 20), y, 2, tone, flame)
			end
		end)
		if enh then
			flash(g, x, y, 22)
			for i = 1, 14 do
				pillar(g, x + dir * i * 26, gy, 12, 62 - (i % 2) * 12, { delay = i * 0.025, life = 0.45, seed = i })
			end
		end
	end } } } },
	{ id = "sl_punch", key = "A", shot = 0.6, segs = { { clip = "punch", fps = 22, ev = {
		[6] = function(g)
			g.fx.shards(g.fwd(22), g.y - 8, 6, g.tone, flameWith({ dir = g.dir, spread = 0.8 }))
			g.hit(0, 38, 24, 4, 3, { kb = 50 })
			if g.s.enh then -- 강화판: 주먹 앞에 큰 불주먹
				local x, y, dir, tone = g.fwd(22), g.y - 9, g.dir, g.tone
				g.fx.add(0.16, function(ctx, k)
					ctx:alpha(1 - k)
					drawFist(ctx, x + dir * 8 * k, y, 8, dir, tone)
					ctx:alpha(1)
				end)
			end
		end,
		[12] = function(g)
			g.fx.ring(g.fwd(24), g.y - 8, 3, 16, g.tone, { squash = 1, back = false, life = 0.2 })
			g.fx.shards(g.fwd(24), g.y - 8, 9, g.tone, flameWith({ dir = g.dir, spread = 0.9, speed = 130 }))
			g.hit(0, 42, 26, 4, 5, { kb = 150, stop = 0.05 })
			if g.s.enh then -- 강화판: 둘째 타에 별 모양 섬광 · 앞으로 부채꼴 불꽃 혀
				local x, y, dir, tone = g.fwd(26), g.y - 8, g.dir, g.tone
				flash(g, x, y, 28)
				g.fx.add(0.3, function(ctx, k)
					local len = 26 * (if k < 0.3 then k / 0.3 else 1 - (k - 0.3) / 0.7)
					for i = -2, 2 do
						tongue(ctx, x, y, 10, len * (if i % 2 ~= 0 then 0.75 else 1), tone, { ang = (if dir > 0 then 0 else 180) + i * 22, core = k < 0.5 })
					end
				end)
				g.fx.shards(x, y, 12, tone, flameWith({ dir = dir, spread = 0.9, speed = 170 }))
			end
		end,
	} } } },
	-- 화염 강타: 선딜을 줄였다(2026-10-26 사용자 "샐러맨더 2차 사냥기 선딜좀줄이자") — 팔을 든 5째 장부터 초당 20장(전에는 0째 장부터 16장): 내리치기까지 0.69 → 0.30초 · 한 번 0.70초(전 1.19초).
	--  불덩이를 모으는 그림은 첫 장에서 바로(내리칠 때까지 0.3초). 장 · 빠르기는 제가 정한 것(3차 불덩이 던지기와 같은 법 — S218)
	{ id = "sl_slam", key = "E", ground = true, shot = 0.45, segs = { { clip = "slam", from = 5, fps = 20, ev = { [5] = function(g)
		gather(g, 6 / 20)
	end, [11] = slam } } } },
}

-- 불꽃 돌진(2차 이동기 — 2026-10-25 사용자 "샐래맨더도 불꽃돌진 일반이동기로 쿨타임달고 보스기 추가 … 액시온도 도약강타 일반 이동기로 바꾸고 앞으로 돌진하는스킬로 바꾸고 쿨타임달고 보스기 새로 만들어"): 피해는 없다(리븐 · 리퍼와 같게 — 마스터 5 · 다시 쓰기 5초 · 공중에서도).
--  아주 짧은 순간이동을 steps번(0.03초마다 · 잔상) · 바닥에 남는 불티 줄 · 끝에서 작은 불꽃. 거리(모두 합친 것)는 스킬 레벨마다(공방 combat.js의 MOVECAST → moveCast.dist)
local function fireRush(g)
	local mc = COMBAT.moveCast and COMBAT.moveCast.sl_rush
	local steps = if mc then mc.steps else 6
	local total = if mc then mc.dist[math.clamp(g.sk("sl_rush"), 1, #mc.dist)] else 90
	local tone = g.tone
	for i = 0, steps - 1 do
		g.after(i * 0.03, function()
			local x0 = g.x
			g.ghost()
			g.teleport(g.fwd(total / steps))
			g.fx.shards((x0 + g.x) / 2, g.y - 2, 2, tone, flameWith({ speed = 12, up = 30, life = 0.35 }))
		end)
	end
	g.after(steps * 0.03, function()
		g.fx.pop(g.fwd(6), g.y - 8, tone, { r = 6, life = 0.16 })
		g.fx.shards(g.x, g.y - 8, 6, tone, flame)
	end)
end
-- 작열권(2차 보스기 — 2026-10-25 사용자 "샐래맨더도 불꽃돌진 일반이동기로 쿨타임달고 보스기 추가 … 액시온도 도약강타 일반 이동기로 바꾸고 앞으로 돌진하는스킬로 바꾸고 쿨타임달고 보스기 새로 만들어"): 주먹을 크게 내질러(punch 6장) 앞의 적에 박고(한 번) · 0.12초 뒤 그 자리에서 불꽃이 X자로 터진다(한 번 더). 이름 · 모양 · 숫자는 제가 정한 것
--  강화판(2026-11-04): 1.5배의 불주먹 · X에 十까지 겹친 불꽃(여덟 갈래) · 별 모양 섬광 · 터지는 둘레 24 → 34
local function blast(g)
	local enh = g.s.enh == true
	local x, y, dir, tone = g.fwd(if enh then 30 else 26), g.y - 9, g.dir, g.tone
	g.fx.add(0.18, function(ctx, k) -- 앞으로 뻗는 큰 불주먹
		ctx:alpha(1 - k * 0.6)
		drawFist(ctx, x - dir * 8 + dir * 10 * k, y, if enh then 9 else 6, dir, tone)
		ctx:alpha(1)
	end)
	g.hit(0, if enh then 52 else 44, if enh then 34 else 28, 4, 4, { kb = 20, stop = 0.05 })
	g.after(0.12, function()
		for _, a in (if enh then { 45, -45, 0, 90 } else { 45, -45 }) do
			g.fx.cut(x, y, if enh then (if a % 90 ~= 0 then 50 else 40) else 34, a, tone, { th = if enh then 7 else 5, life = 0.25 })
		end
		g.fx.ring(x, y, 3, 22, tone, { squash = 1, back = false, life = 0.25 })
		if enh then
			flash(g, x, y, 30)
		end
		g.fx.shards(x, y, if enh then 18 else 10, tone, flameWith({ speed = if enh then 160 else 120 }))
		g.hitAt(x, g.y, if enh then 34 else 24, if enh then 40 else 30, 6, { kb = 80, stop = 0.06 })
		g.shake(1, 0.1)
	end)
end
table.insert(skills, { id = "sl_blast", key = "S", shot = 0.6, segs = { { clip = "punch", fps = 22, ev = { [6] = blast } } } })
table.insert(skills, { id = "sl_rush", key = "V", air = true, shot = 0.3, segs = { -- 불꽃 돌진(이동기 — 위 fireRush)
	{ clip = "dash", loop = true, dur = 0.2, fps = 20, float = true, start = fireRush },
} })

local more = {
	buff("sl_tempo", "1"),
	-- 불덩이 던지기(2026-10-27 다시 — 사용자: "곡사로 던지는게아니라 메이플스토리에 플레임 위자드처럼 직사로 던지고 던지고 던지고 받고받고받고 …"):
	--  팔을 내뻗는 장(wave 10~13)을 세 번 — 장마다 불덩이 하나를 곧게(meteorOrb) → 셋이 차례로 손에 돌아오는 동안 자세를 거둔다(wave 14~17). 그 앞의 포물선 · 불바다는 뺐다
	{ id = "sl_meteor", key = "Q", shot = 0.7, segs = {
		{ clip = "wave", from = 10, to = 13, fps = 24, ev = { [12] = function(g)
			meteorOrb(g, 3)
		end } },
		{ clip = "wave", from = 10, to = 13, fps = 24, ev = { [12] = function(g)
			meteorOrb(g, 3)
		end } },
		{ clip = "wave", from = 10, to = 13, fps = 24, ev = { [12] = function(g)
			meteorOrb(g, 4) -- 셋째(마무리)가 조금 세다
		end } },
		{ clip = "wave", from = 14, to = 17, fps = 48 }, -- 자세를 곧 거둔다 — 불덩이는 그 뒤에 돌아와 손에 잡힌다. 후딜(셋째를 던진 뒤) 0.58 → 0.17초(2026-10-27 사용자 "3차 불덩이 날릴때 날리고 후 경직이 너무심해")
	} },
	{ id = "sl_barrage", key = "D", shot = 0.8, holdFor = 2, segs = {
		{ clip = "punch", from = 0, to = 12, loopFrom = 6, fps = 36, hold = true, max = 3, min = 0.4, every = { 0.08, function(g) -- 앞에 겹쳐 찍히는 주먹 자국들
			if g.held < 0.16 then
				return
			end
			local x, y, dir, tone = g.fwd(20 + g.rnd() * 18), g.y - 4 - g.rnd() * 15, g.dir, g.tone
			if g.s.enh then -- 강화판: 불주먹이 찍힌다
				g.fx.add(0.12, function(ctx, k)
					ctx:alpha(1 - k)
					drawFist(ctx, x, y, 4, dir, tone)
					ctx:alpha(1)
				end)
				g.fx.shards(x, y, 2, tone, flameWith({ dir = dir, spread = 0.6 }))
			else
				g.fx.ring(x, y, 1, 6, tone, { squash = 1, back = false, life = 0.12 })
			end
			g.hit(0, 44, 26, 4, 2, {})
		end } },
		{ clip = "punch", from = 11, fps = 18, ev = { [12] = function(g) -- 마무리: 큰 꽃 모양 폭발 — 그때의 열기만큼 세다(강화판은 열기 가득의 세기 · 열두 갈래 · 별 모양 섬광 · 더 넓게)
			local enh = g.s.enh == true
			local h, x, y = if enh then 100 else g.s.heat, g.fwd(if enh then 34 else 28), g.y - 9
			for i = 0, (if enh then 11 else 7) do
				local a = i * (if enh then 30 else 45)
				g.fx.cut(x + cos(a * 0.01745) * 12, y - sin(a * 0.01745) * 12, (if enh then 30 else 22) + h * 0.12, a, g.tone, { th = if enh then 6 else 5, life = 0.3 })
			end
			if enh then
				flash(g, x, y, 40, 0.26)
			end
			g.fx.ring(x, y, 4, 30, g.tone, { squash = 1, back = false })
			g.fx.shards(x, y, if enh then 24 else 14, g.tone, flameWith({ speed = 160 }))
			g.hit(0, if enh then 74 else 60, if enh then 54 else 44, 4, R(10 + h / 8), { kb = 160, stop = 0.08 }) -- 열기만큼: h / 5 → h / 8(2026-10-27 사용자 "살라 난타 조금 너프하자" — 열기 100이면 30 → 22.5)
			g.shake(1, 0.12)
		end } },
	} },
	buff("sl_warm", "2"),
	{ id = "sl_cross", key = "5", instant = true, shot = 0.3, cast = function(g)
		g.buff("sl_cross")
		g.fx.ring(g.x, g.y - 9, 4, 20, g.tone, { squash = 0.9, back = false })
		g.fx.shards(g.x, g.y - 9, 10, g.tone, flameWith({ speed = 90 }))
	end },
	{ id = "sl_tide", key = "W", air = true, shot = 0.62, segs = { { clip = "wave", from = 3, to = 8, fps = 18, float = true, ev = { [7] = function(g) -- 선딜 0.39 → 0.18 → 0.22초(2026-10-27 사용자 "샐래맨더 4차 화염해일 선딜 좀 줄이자" — 불을 모아 웅크린 3째 장부터 · 10-28 "공속이 너무 빨라졌어 … 지금은 너무빨라" → 초당 22 → 18장) -- 계단처럼 솟았다 꺼지는 불 세모들이 양쪽으로 달려간다
		-- 뛰는 중에도 쓴다 — 쓰는 동안 그 자리에 떠 있고 불길은 그 높이에서 나간다(2026-10-25 사용자 "점프해서 쓰면 그 점프한 위치에서 해일이 나가야지 다 떨어지고나서 나가면어떻게하라는거야" —
		--  처음엔 떨어지며 쓰고 불길은 발밑 땅을 따라 굴렀다)
		--  강화판(2026-11-04): 해일이 1.5배 높고(세모 다섯) · 지나는 자리마다 불기둥이 솟는다 · 맞는 크기 28 x 34 → 34 x 44
		--  큰 파도(위 TIDE — 맞는 상자는 파도 밑동에서 위 up · 아래 down: 날아가는 것의 y를 그 가운데에 놓고 밑동은 off만큼 아래에 그린다) · 강화판은 더 크고 멀리 · 지나는 자리마다 불기둥
		local tone, gy, enh = g.tone, g.y, g.s.enh == true
		local T = if enh then TIDE.enh else TIDE.base
		local off = (T.up - T.down) / 2
		g.shake(1, 0.1)
		g.fx.ring(g.x, gy, 4, 30, tone)
		for _, s in { -1, 1 } do
			g.shot({
				x = g.x + s * 10,
				y = gy - off,
				vx = s * T.speed,
				life = T.life,
				w = T.w,
				h = T.up + T.down,
				dmg = 10,
				ghost = true,
				dir = s,
				o = { lift = 140 },
				every = { 0.05, function(p)
					local by = p.y + off
					g.fx.shards(p.x, by - T.tri * 0.4, if enh then 3 else 2, tone, flameWith({ speed = 30, up = 70 }))
					if enh then
						p.n = (p.n or 0) + 1
						if p.n % 2 == 0 then
							pillar(g, p.x - s * 20, by, 16, T.pillar, { life = 0.45, seed = p.n })
						end
					end
				end },
				draw = function(ctx, p)
					local by = p.y + off
					for i = 0, T.n - 1 do
						local h, x = (T.tri - i * T.tri / (T.n + 1)) * (0.7 + 0.3 * sin(p.t * 22 + i)), p.x - s * i * T.gap
						poly(ctx, { { x - T.hw, by }, { x + s * 3, by - h }, { x + T.hw, by } }, if i % 2 == 1 then tone.n else tone.l)
					end
				end,
			})
		end
	end } }, { clip = "wave", from = 9, to = 17, fps = 32, float = true } } }, -- 해일을 보낸 뒤 자세를 거둔다 — 선딜 0.22초 · 후딜 0.39초 · 한 번 0.61초(10-27 0.45초 → 10-28 사용자 "공속이 너무 빨라졌어 원래 이전보다는 빨라야하는게 맞는데 지금은 너무빨라" — 처음 1.0초보다는 빠르게 · 공방 kits/salamander.js와 같다)
	{ id = "sl_king", key = "F", shot = 0.95, segs = { -- 누를 때마다 좌우 주먹: 첫 주먹 → 둘째 주먹 → 셋째에 겹 폭발
		{ clip = "punch", from = 0, to = 9, fps = 26, ev = { [6] = function(g)
			fist(g, 9)
		end } },
		{ clip = "punch", from = 10, fps = 24, needPress = true, ev = { [12] = function(g)
			fist(g, 9)
		end } },
		{ clip = "punch", from = 0, to = 9, fps = 22, needPress = true, ev = { [6] = function(g)
			-- 셋째 폭발: 앞 60 → 70 · 둘레 44 → 62(강화판 56 → 76) — 앞 16 ~ 104 → 8 ~ 132점(2026-11-10 사용자 "살라 4차 보스기 가로 사거리 조금더 길어져야한다" · 붙어 선 적도 맞게 가까운 쪽도 덮는다 · 이펙트도 그만큼 · 제가 정한 것)
			local x, y, gy, enh = g.fwd(70), g.y - 9, g.y, g.s.enh == true
			fist(g, 0)
			g.after(0.16, function()
				g.fx.ring(x, y, 4, 48, g.tone, { squash = 1, back = false })
				g.fx.ring(x, y, 2, 32, g.tone, { squash = 1, back = false, delay = 0.06 })
				if enh then -- 강화판: 별 모양 섬광 · 양옆 72까지 불기둥(터지는 둘레 62 → 76)
					flash(g, x, y, 60, 0.26)
					for i = -3, 3 do
						pillar(g, x + i * 24, gy, 14 - abs(i), 52 - abs(i) * 8, { delay = 0.03 * abs(i), life = 0.5, seed = i })
					end
				end
				g.fx.shards(x, y, if enh then 34 else 24, g.tone, flameWith({ speed = 210 }))
				g.hitAt(x, gy, if enh then 76 else 62, if enh then 60 else 50, 16, { kb = 150, stop = 0.08 })
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
	{ id = "sl_wyrm", key = "B", shot = 0.9, segs = { { clip = "punch", fps = 16, start = function(g) -- 화룡 승천(위 wyrm)
		g.dim(0.5, 1.6)
	end, ev = { [4] = wyrm } } } },
	{ id = "sl_dragon", key = "G", ground = true, shot = 0.75, segs = { -- 화산권(위 volcano — 돌진 없이 제자리에서)
		{ clip = "slam", from = 5, fps = 20, start = function(g) -- (화염 강타와 같은 장 — 내려치기까지 0.3초)
			g.dim(0.4, 1.3)
			volcanoCrack(g)
		end, ev = { [11] = volcano } },
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

-- 가득 찬 열기 — 불꽃 갓(2026-11-04 사용자 "열기 가득차서 불타오르는 이펙트상태 있잖아 좀더 멋지고 간략하게 수정하고 캐쉬 무기의 색깔에 영향받게해줘"):
--  머리 위로 불꽃 셋이 솟아 뒤(왼쪽)로 기울며 넘실댄다 — 1초에 fps장 · 네 장. 몸 뒤에 그려 머리 덩어리 · 뿔이 앞에 온다. 장마다 머리 자리(data/salaHeads.generated — 가면의 왼쪽 위 · 발밑에서)를 따라간다.
--  o 테 · m 가운데 · l 밝은 · c 심 = 색 넷(어두운 것부터): 캐시 무기를 장착했으면 그 재질의 네 색(dye.generated의 skins[].ramp) · 아니면 이 직업의 분홍.
--  그 전(같은 날): pixelfx로 만든 휘날리는 불(fxart의 sl_fullheat — 35 x 37 · 18장) — 크고 어수선했다. 공방 kits/salamander.js와 같다(모양 · 크기 · 빠르기는 제가 정한 것)
local HEADS = require(script.Parent.Parent.data["salaHeads.generated"])
local DYE = require(script.Parent.Parent.data["dye.generated"])
local CREST = { dx = -2, dy = -9, fps = 10, pink = { 0xb11fa5, 0xff3e9f, 0xff7ea2, 0xffd6e6 }, frames = {
	{ ".o.........", ".mo....o...", ".mlo...mo..", "omlmo.oml.o", "mllmmomllom", "mlcllmlclml", "mlccllcccll", ".lcccccccl." },
	{ "......o....", ".o....mo...", ".mo...mlo..", "omlo.omll.o", "mlmmomllmom", "mlclmllclml", "mlccllcccll", ".lcccccccl." },
	{ "..o........", ".om.....o..", ".mlo...om..", "omll.omlo.o", "mllmomlmmom", "mlclmllclml", "mlccllcccll", ".lcccccccl." },
	{ "........o..", ".o.....om..", "omo...oml..", "mlmo.omllo.", "mllmomlmmom", "mlclmllclml", "mlccllcccll", ".lcccccccl." },
} }
local CREST_IDX = { o = 1, m = 2, l = 3, c = 4 }
local function crestRamp(g)
	local id = g.wskin
	if id then
		for _, q in DYE.skins do
			if q.id == id and q.ramp then
				return q.ramp
			end
		end
	end
	return CREST.pink
end

local salamander = {
	tone = "pink",
	toggle = "sl_ember",
	icons = { c_hero = "moon", sl_ember = "star", sl_tempo = "haste", sl_warm = "up", sl_cross = "shield", sl_overheat = "flame" },
	init = function(g)
		g.s = { heat = 0, lastHit = -9, emberAt = -9, aura = 0, step = 0, fullOn = false, enh = false, enhAt = -9 }
	end,
	haste = function(g)
		return 1 + (if g.has("sl_tempo") then 0.25 else 0) + (if g.has("sl_warm") then 0.1 else 0)
	end,
	speed = function(g)
		return if hot(g) then 1.15 else 1
	end,
	heroTint = function(g) -- 강화판을 쓴 순간: 몸이 잠깐 하얗게 달아오른다
		return if g.clock - g.s.enhAt < 0.12 then { 0xffffff, 0.85 } else nil
	end,
	mult = function(g)
		return 1 + (if hot(g) then 0.15 else 0) + (if g.has("sl_overheat") then 0.3 else 0) + (if g.has("c_hero") then 0.05 else 0)
	end,
	hot = hot,
	-- 강화판을 쓸 수 있는가(열기를 배웠고 가득 · 폭주 — 화면의 미리 셈: 진짜는 서버 sim/kit.luau Kit.empower) — 사냥기 · 보스기의 퀵슬롯 칸이 빛난다(boot.luau → hud.luau · touch.luau)
	ready = function(g)
		return g.sk("sl_heat") > 0 and full(g)
	end,
	-- 강화판으로 쓴다(cast.luau의 start가 그 판의 첫 구간에서 부른다): 몸이 하얗게 번쩍 · 휘날리던 불이 걷혀 사방으로 흩어진다.
	--  내 화면의 열기는 서버가 알려 줄 때까지 비운다(용광로 심장이면 서버가 enhAfter를 알려 준다 · 폭주는 그대로 — boot.luau의 syncKit은 그사이 늦게 온 가득을 받지 않는다)
	empower = function(g)
		g.s.enhAt = g.clock
		if not g.has("sl_overheat") then
			g.s.heat = 0
		end
		g.fx.shards(g.x, g.y - 12, 14, g.tone, flameWith({ speed = 110, up = 90 }))
	end,
	onHit = function(g, m, dmg, o)
		if not dmg or dmg == 0 or o.proc then
			return
		end
		if g.sk("sl_heat") > 0 and not g.s.enh then -- (강화판의 타는 열기를 채우지 않는다 — 서버 sim/room.luau kitAfter의 opts.enh)
			g.s.heat = min(HEAT.max, g.s.heat + HEAT.gain * (if g.sk("sl_heat2") > 0 then 1.3 else 1)) -- (화면의 미리 셈 — 진짜는 서버 sim/kit.luau Kit.gainHeat: 한 판에 한 번)
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
		if g.has("sl_overheat") then
			g.s.heat = HEAT.max
		elseif g.authority and g.clock - g.s.lastHit > HEAT.cool then -- 식는 것은 서버가 셈한다(화면은 받은 값을 그린다)
			g.s.heat = max(0, g.s.heat - HEAT.decay * (if g.sk("sl_heat2") > 0 then 0.6 else 1) * dt)
		end
		-- 가득 찼다(사냥기 · 보스기가 강화판으로 나간다): 머리에서 불티가 한 번 확(그 뒤로는 drawBack의 불꽃 갓 — 같은 색)
		if full(g) and not g.s.fullOn and g.sk("sl_heat") > 0 then
			g.s.fullOn = true
			local r = crestRamp(g)
			g.fx.shards(g.x, g.y - 18, 8, { d = r[1], n = r[2], l = r[3], w = r[4] }, flameWith({ speed = 70, up = 90 }))
		elseif not full(g) then
			g.s.fullOn = false
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
	drawBack = function(ctx, g) -- 가득 찬 열기: 머리 위의 불꽃 갓(위 CREST) · 맞불: 몸을 두른 불꽃 고리
		local pose = g.pose
		local head = g.s.fullOn and pose and pose.clip ~= "death" and not g.riding and HEADS[pose.clip] and HEADS[pose.clip][(pose.f or 0) + 1] -- (쓰러지는 동안 · 탈것 위에서는 없다)
		if head then
			local F = CREST.frames[floor(g.clock * CREST.fps) % #CREST.frames + 1]
			local r, k, x0, y0, flip = crestRamp(g), (g.hero and g.hero.scale) or 1, R(g.x), R(g.y), g.dir < 0 -- k = 몸의 크기(거신 — 몸처럼 발밑에서 커진다)
			local sz = math.max(1, R(k))
			for j, row in F do
				for i = 1, #row do
					local c = CREST_IDX[string.sub(row, i, i)]
					if c then
						local dx, dy = (head[1] + CREST.dx + i - 1) * k, (head[2] + CREST.dy + j - 1) * k
						ctx:style(r[c])
						ctx:rect(R(if flip then x0 - dx - sz else x0 + dx), R(y0 + dy), sz, sz)
					end
				end
			end
		end
		if g.has("sl_cross") then
			for i = 0, 11 do
				local a = g.clock * 5 + i * 0.5236
				local x, y = g.x + cos(a) * 15, g.y - 9 + sin(a) * 12
				ctx:style(if i % 2 == 1 then g.tone.n else g.tone.l)
				ctx:rect(R(x) - 1, R(y) - 1, 2 + (if i % 3 == 0 then 1 else 0), 2)
			end
		end
	end,
	draw = function(ctx, g) -- 열기 막대(발밑의 이름표 바로 아래 — 핵심 장치): 눈금을 넘으면 달아오름(깜빡) · 가득이면 하얗게 깜빡(사냥기 · 보스기가 강화판으로 나간다). 열기를 배운 내 캐릭터에만 보인다
		if g.sk("sl_heat") <= 0 then
			return
		end
		-- 발밑에서 Common.GAUGE_DOWN만큼 아래: 이름표(발밑 2~9점)에 가리지 않는다(사용자 2026-10-11: "캐릭터 아래에 게이지 보여주는 스킬들이 … 닉네임이랑 겹쳐서 가려버리는 문제")
		local x, y, w = R(g.x) - 9, R(g.y) + Common.gaugeDown(g), R((18 * g.s.heat) / 100) -- (칭호를 달았으면 칭호 줄 밑 — 2026-10-28)
		ctx:style(0x12161c)
		ctx:rect(x - 1, y - 1, 20, 4)
		local blink = floor(g.clock * 10) % 2 == 1
		ctx:style(if g.s.heat >= HEAT.max then (if blink then 0xffffff else g.tone.l) elseif hot(g) then (if blink then g.tone.l else g.tone.n) else g.tone.n)
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
