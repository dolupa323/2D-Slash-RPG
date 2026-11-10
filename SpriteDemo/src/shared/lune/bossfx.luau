--!native
--!optimize 2
-- 스토리 보스의 예고와 이펙트 — 공방 시험 탭의 dino-workshop/js/lune/bossfx.js를 줄마다 옮긴 것(고칠 때는 시험 탭에서 먼저 고치고 여기를 맞춘다).
--  사용자 2026-10-11: "패턴, 스킬 이펙트는 따로 만드셔야해요" — 몸의 동작 그림은 사용자가, 맞을 자리의 예고와 치는 순간의 이펙트는 여기서 그린다.
--  사용자 2026-10-12 밤: "패턴 이팩트들 스킬이펙트 재사용하지말고 새로 만드세요 퀄리티 높게"
--    → 치는 순간 · 물결 · 불기둥 · 포효의 이펙트는 이제 패턴마다의 제 그림(스프라이트)이다 — 그 보스의 동작 묶음에 fx_로 시작하는 동작으로 실려 있다(공방 design/bosses.js의 BOSS_FXART · BOSS_FX).
--      여기서는 그 그림을 제자리 · 제때에 틀 뿐이다: fx.sprite(누구의, 동작, x, y, 보는 쪽, { delay 늦게 · back 몸의 뒤 · loop 돌려 트는 시간 · vx 가는 빠르기 · lo · hi 그 밖에서는 안 그림 · fade 끝에서 사라지는 몫 })
--      (그 앞에는 캐릭터 기술의 이펙트 부품 — fx.luau의 고리 · 가시 · 파편 · 초승달 · 빛기둥 — 을 조립해 그렸다. 캐릭터의 기술과 같은 그림이라 보스의 것으로 보이지 않았다)
--    맞을 자리의 예고(붉은 자리 · 띠 · 느낌표 · 둥근 표시)는 그대로 코드로 그린다 — 판정의 자리를 한 점까지 정확히 보여 줘야 하는 표시다. 색은 적의 분홍(Fx.TONE.pink).
--  싸움의 자료는 data/combat.generated.luau의 mobs[보스].story(공방 design/bosses.js의 STORYBOSS) — 패턴에 붙어 오는 이펙트: p.fx(치는 순간) · p.spots.fx · p.wave.fx · p.leap.fx · p.summon.fx · p.dash.trail · p.dash.crash · 보스의 phase.fx
--  그리는 일은 화면에서만 일어난다(서버는 부르지 않는다).
local Fx = require(script.Parent.fx)
local COMBAT = require(script.Parent.data["combat.generated"])

local floor, max, min = math.floor, math.max, math.min
local R = Fx.R
local T = Fx.TONE.pink

local BossFx = {}

-- ---- 이펙트 그림이 아직 없는 보스(2026-10-24 — 주간 보스 넷 · 공방 design/weekboss.js): 코드로 그리는 이펙트 ----
--  솟는 기둥 · 바닥을 가는 물결 · 내려친 자리의 빛을 그 보스의 네 색(story.tone — d 어두운 · n 몸 · l 밝은 · w 흰)으로, 굵은 덩어리로 그린다(2026-10-13 사용자: 납작한 색 + 흰 줄은 기각 — 네 단의 굵은 모양).
--  그림(BOSS_FX)이 생기면 그것을 쓴다(def.fx · p.fx가 있으면 여기는 지나간다)
local toneCache = {}
local function toneOf(who: string)
	if toneCache[who] then
		return toneCache[who]
	end
	local m = COMBAT.mobs[who]
	local t = m and m.story and m.story.tone
	local function hx(c)
		return c[1] * 65536 + c[2] * 256 + c[3]
	end
	local out = if t then { d = hx(t.d), n = hx(t.n), l = hx(t.l), w = hx(t.w) } else T
	toneCache[who] = out
	return out
end
BossFx.toneOf = toneOf

-- 솟는 기둥 하나(표시된 자리가 터질 때 — 0.5초): 아래에서 위로 up만큼 치솟았다가 가늘어지며 사라진다. 바닥에 넓은 받침 · 위로 튀는 조각 셋
function BossFx.pillarPlain(ctx, x: number, y: number, r: number, up: number, k: number, tone)
	x, y = R(x), R(y)
	local rise = min(1, k / 0.18)
	local fade = max(0, (k - 0.35) / 0.65)
	local h = R(up * 1.15 * rise)
	local half = max(1, R(r * (1 - fade * 0.7)))
	ctx:alpha(1 - fade * 0.6)
	ctx:style(tone.d)
	ctx:rect(x - half - 2, y - h, half * 2 + 4, h)
	ctx:rect(x - r - 4, y - 4, r * 2 + 8, 4)
	ctx:style(tone.n)
	ctx:rect(x - half, y - h, half * 2, h)
	ctx:style(tone.l)
	ctx:rect(x - max(1, half - 3), y - h, max(2, half * 2 - 6), h)
	ctx:style(tone.w)
	ctx:rect(x - max(1, floor(half / 3)), y - h, max(2, floor(half / 3) * 2), h)
	ctx:rect(x - r - 2, y - 2, r * 2 + 4, 2)
	for i = -1, 1 do
		local px = x + i * (r - 2)
		local py = y - h - R(10 * k) - (if i == 0 then 6 else 0)
		ctx:style(tone.l)
		ctx:rect(px - 1, py - 1, 3, 3)
		ctx:style(tone.w)
		ctx:rect(px, py, 1, 1)
	end
	ctx:alpha(1)
end

-- 물결 하나의 머리(바닥을 가는 것 — 높이 up): 앞이 높고 뒤로 낮아지는 쐐기 + 흰 마루. dir = 가는 쪽
function BossFx.crestPlain(ctx, x: number, y: number, dir: number, up: number, w: number, tone, a: number)
	x, y = R(x), R(y)
	local len = max(10, w * 3)
	ctx:alpha(a)
	for i = 0, len - 1 do
		local hgt = max(2, R(up * (1 - i / len) ^ 1.4))
		local cx = x - dir * i
		ctx:style(if i < 2 then tone.w elseif i < len * 0.3 then tone.l elseif i < len * 0.7 then tone.n else tone.d)
		ctx:rect(cx, y - hgt, 1, hgt)
		if i >= 2 then
			ctx:style(tone.w)
			ctx:rect(cx, y - hgt, 1, 1)
		end
	end
	ctx:style(tone.d)
	ctx:rect(R(x - dir * len) - (if dir > 0 then 0 else -1), y - 1, len, 1)
	ctx:alpha(1)
end

-- 내려친 자리의 빛(0.3초): 맞는 자리의 바닥을 따라 굵은 띠가 번쩍이고 위로 짧은 빛살이 선다
function BossFx.slamPlain(ctx, lo: number, hi: number, y: number, up: number, k: number, tone)
	lo, hi, y = R(lo), R(hi), R(y)
	local a = 1 - k
	local h = max(3, R(min(up, 40) * 0.5 * (1 - k)))
	ctx:alpha(a)
	ctx:style(tone.d)
	ctx:rect(lo, y - h - 2, hi - lo, h + 2)
	ctx:style(tone.n)
	ctx:rect(lo + 2, y - h, hi - lo - 4, h)
	ctx:style(tone.l)
	ctx:rect(lo + 4, y - max(2, R(h * 0.5)), hi - lo - 8, max(2, R(h * 0.5)))
	ctx:style(tone.w)
	ctx:rect(lo, y - 1, hi - lo, 1)
	local step = 14
	local xx = lo + 6
	while xx < hi - 4 do
		local sh = R((h + 8) * (0.6 + 0.4 * math.sin(xx * 0.7)))
		ctx:style(tone.l)
		ctx:rect(xx, y - sh, 2, sh)
		ctx:style(tone.w)
		ctx:rect(xx, y - sh, 2, 2)
		xx += step
	end
	ctx:alpha(1)
end

-- ---- 맞을 자리의 예고(경고 장판) — 2026-11-09 사용자: "경고장판 개념을 잘 모르는거같은데 지금 이것저것 너무많이들어가 그냥 단색 희미한 영역만 보이는거야 이렇게 복잡하게 작업할 필요가없어" ----
--  맞을 자리(판정의 네모 그대로 — 가로 lo ~ hi · 바닥 y에서 위로 up · 발이 바닥에서 lift 위여야 맞는 것은 lift부터)를 적의 분홍 한 색으로 희미하게 칠한다 — 그것뿐(테두리 · 줄 · 금 · 칼 · 폭탄 같은 모양은 없다).
--  끝이 가까워질수록 조금 짙어진다(0.16 → 0.28). 그 전(2026-10-27)의 보스마다 다른 장판 모양 · 11-09 오전의 Pixelbolt 조각은 뺐다 — 보스마다 다른 것은 머리 위 표시(아래)만. 공방 js/lune/bossfx.js의 area와 같은 셈
function BossFx.area(ctx, lo: number, hi: number, y: number, up: number, k: number, lift: number?)
	lo, hi = R(lo), R(hi)
	local b0, b1 = R(y - (lift or 0)), R(y - up)
	if hi <= lo or b0 <= b1 then
		return
	end
	ctx:alpha(0.16 + 0.12 * math.clamp(k, 0, 1))
	ctx:style(T.n)
	ctx:rect(lo, b1, hi - lo, b0 - b1)
	ctx:alpha(1)
end

-- ---- 머리 위의 표시(장판이 아니다 — 보스마다 다르다: 「!」 · 그림자 사수 조준 십자 · 부단장 칼 · 도둑 두목 폭탄 · 용암 거인 용암 방울) · 졸개가 나올 자리 ----
local SLATE = 0x232931
local function blinkOf(k: number): boolean
	return k > 0.7 and floor(k * 40) % 2 == 0
end
function BossFx.alert(ctx, x: number, y: number, k: number)
	x, y = R(x), R(y)
	local hot = k > 0.7 and floor(k * 40) % 2 == 0
	ctx:style(T.d)
	for i = 0, 9 do
		ctx:rect(x - i, y - 18 + i, i * 2 + 1, 1)
		ctx:rect(x - i, y - i, i * 2 + 1, 1)
	end
	ctx:style(if hot then T.w else T.n)
	for i = 0, 7 do
		ctx:rect(x - i, y - 16 + i, i * 2 + 1, 1)
		ctx:rect(x - i, y - 2 - i, i * 2 + 1, 1)
	end
	ctx:style(if hot then T.n else T.w)
	ctx:rect(x - 1, y - 14, 3, 7)
	ctx:rect(x - 1, y - 6, 3, 2)
end
function BossFx.callMark(ctx, x: number, y: number, k: number)
	x, y = R(x), R(y)
	local h = R(48 * k)
	ctx:style(T.n)
	ctx:alpha(0.3)
	ctx:rect(x - 5, y - h, 11, h)
	ctx:alpha(1)
	ctx:rect(x - 5, y - 2, 11, 3)
	local j = 0
	while j < h do
		ctx:rect(x, y - 2 - j, 1, 2)
		j += 4
	end
	BossFx.alert(ctx, x, y - h - 4, k)
end
function BossFx.crosshair(ctx, x: number, y: number, k: number)
	x, y = R(x), R(y - 10)
	local hot = k > 0.7 and floor(k * 40) % 2 == 0
	local rr = 7
	ctx:style(T.d)
	for a = 0, 47 do
		local t = a / 48 * math.pi * 2
		ctx:rect(R(x + math.cos(t) * rr) - 1, R(y + math.sin(t) * rr) - 1, 3, 3)
	end
	ctx:style(if hot then T.w else T.n)
	for a = 0, 47 do
		local t = a / 48 * math.pi * 2
		ctx:rect(R(x + math.cos(t) * rr), R(y + math.sin(t) * rr), 1, 1)
	end
	ctx:rect(x - rr - 3, y, 5, 1)
	ctx:rect(x + rr - 1, y, 5, 1)
	ctx:rect(x, y - rr - 3, 1, 5)
	ctx:rect(x, y + rr - 1, 1, 5)
	ctx:style(if hot then T.n else T.w)
	ctx:rect(x - 1, y - 1, 3, 3)
end
local function vSword(ctx, x: number, ty: number, len: number, blink: boolean)
	for i = 0, len - 1 do
		local yy = ty - i
		local half = if i < 6 then max(0, R((i / 6) * 2)) else 2
		ctx:style(T.d)
		ctx:rect(x - half - 1, yy, half * 2 + 3, 1)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(x - half, yy, half * 2 + 1, 1)
		if half >= 1 then
			ctx:style(T.w)
			ctx:rect(x - half, yy, 1, 1)
			ctx:style(T.l)
			ctx:rect(x, yy, 1, 1)
		end
	end
	local gy = ty - len
	ctx:style(T.d)
	ctx:rect(x - 8, gy - 4, 17, 5)
	ctx:style(if blink then T.w else T.l)
	ctx:rect(x - 7, gy - 3, 15, 3) -- 코등이
	ctx:style(T.d)
	ctx:rect(x - 2, gy - 12, 5, 8)
	ctx:style(T.n)
	ctx:rect(x - 1, gy - 11, 3, 7) -- 손잡이
end
function BossFx.swordSigil(ctx, x: number, y: number, k: number)
	vSword(ctx, R(x), R(y) - 2, 12, blinkOf(k))
end
local function bomb(ctx, x: number, y: number, fuse: number, blink: boolean)
	ctx:style(T.d)
	ctx:rect(x - 3, y - 7, 7, 7)
	ctx:rect(x - 4, y - 6, 9, 5)
	ctx:style(SLATE)
	ctx:rect(x - 3, y - 6, 7, 5)
	ctx:rect(x - 2, y - 7, 5, 7)
	ctx:style(T.w)
	ctx:rect(x - 2, y - 5, 1, 1) -- 반짝임
	ctx:style(T.d)
	for i = 1, fuse do
		ctx:rect(x + 1 + floor(i / 2), y - 7 - i, 1, 1)
	end
	local sx, sy = x + 1 + floor(fuse / 2), y - 8 - fuse
	ctx:style(if blink then T.w else T.n)
	ctx:rect(sx - 1, sy - 1, 3, 3)
	ctx:style(T.w)
	ctx:rect(sx, sy, 1, 1)
end
function BossFx.bombSigil(ctx, x: number, y: number, k: number)
	bomb(ctx, R(x), R(y), 5, blinkOf(k))
end
function BossFx.magmaSigil(ctx, x: number, y: number, k: number)
	x, y = R(x), R(y)
	local blink = blinkOf(k)
	ctx:style(SLATE)
	ctx:rect(x - 3, y - 7, 7, 7)
	ctx:rect(x - 1, y - 10, 3, 3)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(x - 2, y - 6, 5, 5)
	ctx:rect(x, y - 9, 1, 3)
	ctx:style(T.w)
	ctx:rect(x - 1, y - 5, 1, 1)
end

-- 표시된 자리(떨어지는 곳 · 솟는 곳 — 모든 보스): 그 자리의 기둥(가로 x ± r · 바닥에서 up — 하늘까지(999)는 230점까지만)을 희미하게 칠한다(위 area).
--  fromX · fromY · mark · grid는 쓰지 않는다(2026-11-09 — 날아오는 불씨 · 보스마다의 모양을 뺐다 · 부르는 쪽은 그대로)
function BossFx.spot(ctx, x: number, y: number, r: number, up: number, k: number, _fromX: number?, _fromY: number?, _mark: string?, _grid: boolean?)
	BossFx.area(ctx, x - r, x + r, y, min(up, 230), k)
end

-- ---- 패턴의 이펙트 그림을 튼다(who = 그 보스 — 그림은 그 보스의 동작 묶음에 있다) ----
-- 불기둥이 솟는다(표시된 자리 하나 — 한 번). def = 그 패턴의 spots
function BossFx.blast(fx, who: string, x: number, y: number, def, shake: ((number, number) -> ())?)
	if def.fx then
		fx.sprite(who, def.fx, x, y, 1)
	elseif fx.add then
		local t0, tone = os.clock(), toneOf(who) -- 그림이 없는 보스: 코드로 그린 기둥(2026-10-24)
		fx.add(0.5, function(ctx)
			BossFx.pillarPlain(ctx, x, y, def.r or 14, def.up or 50, min(1, (os.clock() - t0) / 0.5), tone)
		end)
	end
	if shake then
		shake(2, 0.12)
	end
end

-- 뛰어오르는 자리(도약 찍기): 박차는 먼지
function BossFx.jump(fx, who: string, p, x: number, y: number)
	if p.leap and p.leap.fx then
		fx.sprite(who, p.leap.fx, x, y, 1)
	end
end

-- 체력 구간의 포효(「불씨가 타오른다」 · 「간수의 포효」): 몸의 뒤에서 솟는 그림 + 긴 흔들림. S = 그 보스의 싸움 자료
function BossFx.roar(fx, who: string, S, x: number, y: number, shake: ((number, number) -> ())?)
	if S.phase and S.phase.fx then
		fx.sprite(who, S.phase.fx, x, y, 1, { back = true })
	end
	if shake then
		shake(4, 0.4)
	end
end

-- 치는 순간의 화면 흔들림(세기, 초) — 보스의 큰 한 방에만
local SHAKE = { smash = { 3, 0.22 }, quake = { 3, 0.22 }, leap = { 3, 0.22 }, sweep = { 2, 0.15 }, slash = { 3, 0.2 }, bladewave = { 2, 0.12 }, storm = { 2, 0.12 }, beacon = { 3, 0.25 } }

-- 치는 순간의 이펙트(한 번): p = 패턴 · (x, y) = 보스의 발밑 가운데 · dir = 보는 쪽 · shake(세기, 초) = 화면 흔들기(없어도 된다)
--  p.fx = { { clip, dx 보는 쪽으로, dy 위로, delay, back } … } · 호령은 졸개가 나오는 자리마다 p.summon.fx도
function BossFx.strike(fx, who: string, p, x: number, y: number, dir: number, shake: ((number, number) -> ())?)
	for _, e in p.fx or {} do
		fx.sprite(who, e.clip, x + dir * (e.dx or 0), y - (e.dy or 0), dir, { delay = e.delay or 0, back = e.back == true })
	end
	if not p.fx and p.zone and fx.add then
		-- 그림이 없는 보스: 맞는 자리에 코드로 그린 빛(2026-10-24)
		local t0, tone = os.clock(), toneOf(who)
		local a, b = x + dir * p.zone.from, x + dir * p.zone.to
		local lo, hi = min(a, b), max(a, b)
		fx.add(0.3, function(ctx)
			BossFx.slamPlain(ctx, lo, hi, y, p.zone.up, min(1, (os.clock() - t0) / 0.3), tone)
		end)
	end
	if p.summon and p.summon.fx then
		for _, ax in p.summon.at do
			fx.sprite(who, p.summon.fx, ax, y, 1)
		end
	end
	local s = SHAKE[p.id]
	if s and shake then
		shake(s[1], s[2])
	end
end

-- 내달리기가 끝났다(벽에 닿았다): 그 자리에서 터진다. p = 그 내달리기 패턴
function BossFx.crash(fx, who: string, p, x: number, y: number, dir: number, shake: ((number, number) -> ())?)
	local e = p and p.dash and p.dash.crash
	if e then
		fx.sprite(who, e.clip, x + dir * (e.dx or 0), y, dir)
	end
	if shake then
		shake(3, 0.2)
	end
end

-- 물결 하나: 생긴 자리 x0에서 dir 쪽으로 range를 speed로 간다(판정은 서버 — 여기는 그림만). 그 그림(def.fx)을 가는 동안 돌려 튼다
--  lo · hi = 방의 양 끝(벽 안쪽) — 그 밖으로는 그리지 않는다(서버의 판정도 벽에서 멈춘다) · age = 이미 흐른 시간(화면이 조금 늦게 알았을 때 — 음수면 그만큼 늦게 떠난다: 연속 검기)
--  fly = 그 그림을 바닥에서 몇 점 위에 그리는가(날아가는 화살 — 2026-10-27 그림자 사수 · 판정은 up · lift 그대로)
function BossFx.wave(fx, who: string, x0: number, y: number, dir: number, def, age: number?, lo: number?, hi: number?)
	y -= def.fly or 0
	if def.fx then
		fx.sprite(who, def.fx, x0, y, dir, { loop = def.range / def.speed, vx = dir * def.speed, lo = lo, hi = hi, fade = 0.15, delay = -(age or 0), drop = def.drop, dropT = def.dropT }) -- drop = 쇠뇌 높이에서 날아가는 높이로 내려오는 점(2026-10-27)
	elseif fx.add then
		-- 그림이 없는 보스: 코드로 그린 물결의 머리(판정과 같은 자리 · 같은 빠르기 — 서버는 sim/room.luau가 옮긴다)
		local t0, tone, life = os.clock() - (age or 0), toneOf(who), def.range / def.speed
		fx.add(life + max(0, -(age or 0)) + 0.05, function(ctx)
			local t = os.clock() - t0
			if t < 0 or t > life then
				return
			end
			local x = x0 + dir * def.speed * t
			if (lo and x < lo) or (hi and x > hi) then
				return
			end
			BossFx.crestPlain(ctx, x, y, dir, def.up or 16, def.w or 8, tone, if t > life - 0.15 then max(0, (life - t) / 0.15) else 1)
		end)
	end
end

-- 내달리는 동안(부르는 쪽이 p.dash.trail.every초마다 부른다): 발밑의 먼지
function BossFx.dashTrail(fx, who: string, p, x: number, y: number, dir: number)
	local e = p and p.dash and p.dash.trail
	if e then
		fx.sprite(who, e.clip, x + dir * (e.dx or 0), y, dir)
	end
end

-- 동작 그림이 없을 때: 대기 그림을 움직여 대신한다 — 앞으로(보는 쪽) · 위로 몇 점. 그림이 오면 쓰지 않는다
--  예고 = 몸을 들어 올리며 뒤로 젖힌다(호령은 제자리에서 떤다 · 내달리기는 뒤로 물러앉는다) · 치는 순간 = 앞으로 크게 내리꽂았다가 돌아온다 · 내달리기 = 앞으로 숙인다
function BossFx.pose(state: string, p, t: number): (number, number)
	if not p then
		return 0, 0
	end
	if state == "tell" then
		local k = min(1, t / p.tell)
		local e = k * k * (3 - 2 * k)
		if p.dash then
			return -R(6 * e), 0
		elseif p.summon then
			return 0, R(3 * e) + floor(t * 12) % 2
		end
		return -R(5 * e), R(7 * e)
	elseif state == "act" then
		if p.summon then
			return 0, 4
		end
		return R(10 * max(0, 1 - t / 0.2)), -1
	elseif state == "dash" then
		return 5, 0
	end
	return 0, 0
end

-- 보스의 몸이 지금 보여 줄 동작과 장 — 받은 동작 그림을 패턴의 시간에 맞춘다(공방 design/bosses.js의 BOSS_ANIM에 까닭 · 시험 탭 bossfx.js의 body와 같은 셈).
--   state 상태 · p 패턴(없으면 nil) · t 그 상태가 된 뒤 흐른 시간 · now 흐르는 시간(돌려 트는 동작) · clips = 그 보스의 동작(chars의 clips — frames · fps) · anim = { fps, 동작 = { hit, to } }(장의 번호는 0부터)
--   tail = 방금 친 동작이 아직 남았으면 { clip, t(친 뒤 흐른 시간) }, 아니면 nil
--   돌려주는 것: 동작 · 장(1부터) · 대기 그림을 움직여 대신하는가(그 동작의 그림이 없을 때)
--     예고: 0 ~ hit-2째 장(치켜드는 동작)을 제 빠르기로 틀고 다 틀면 그 자세로 멈춘다(예고가 더 짧으면 빨리 튼다) → 마지막 한 장 시간에 hit-1째 장(휘두르는 도중) → 치는 순간에 hit째 장 → 그 뒤는 제 빠르기로 to까지
function BossFx.body(state: string, p, t: number, now: number, clips, anim, tail): (string, number, boolean)
	local fps = (anim and anim.fps) or 12
	local function loop(clip: string, k: number): (string, number, boolean)
		local c = clips[clip]
		return clip, floor(now * (c.fps or fps) * k) % #c.frames + 1, false
	end
	if state == "roar" and clips.roar then
		-- 체력 구간의 포효: 그 동작을 한 번 튼다(끝 장에서 멈춘다)
		return "roar", min(#clips.roar.frames, floor(t * (clips.roar.fps or fps)) + 1), false
	end
	-- 보스의 기믹(2026-10-28 불씨 도둑 두목 — sim/thiefgim.luau): 휘청 = 젖혀지는 장을 한 번 → 어지러운 두 장을 되풀이 · 채우기 = 두 장을 되풀이 · 걸어감(불씨 더미로) = 걷기 · 연막 속 = 걷기(sneak)
	local L = anim and anim.loops
	local function hold(clip: string): (string, number, boolean)
		local c = clips[clip]
		local r = L and L[clip]
		local f = floor(t * (c.fps or fps))
		if r and f >= r[1] - 1 then
			f = r[1] - 1 + (f - (r[1] - 1)) % (r[2] - r[1] + 1)
		end
		return clip, min(#c.frames, f + 1), false
	end
	if state == "stagger" and clips.stagger then
		return hold("stagger")
	elseif state == "refill" and clips.refill then
		return hold("refill")
	elseif state == "walk" and clips.run then
		return loop("run", 1.5)
	elseif state == "sneak" and clips.run then
		return loop("run", 1) -- 연막 속을 천천히 걷는다(가짜 두목 = 졸개의 걷기와 같은 빠르기)
	elseif state == "tell" and p and p.dash and clips[p.clip] and L and L[p.clip] then
		-- 구르기의 예고: 웅크리는 장들을 예고 동안 차례로(공이 되기 바로 앞에서 멈춘다)
		local r = L[p.clip]
		return p.clip, min(r[1] - 1, floor(t / max(0.01, p.tell) * (r[1] - 1)) + 1), false
	elseif state == "dash" and p and clips[p.clip] and L and L[p.clip] then
		-- 구르기(굴러 박치기): 공 두 장을 되풀이
		local c, r = clips[p.clip], L[p.clip]
		return p.clip, r[1] + floor(now * (c.fps or fps)) % (r[2] - r[1] + 1), false
	end
	local a = if p and not p.dash and clips[p.clip] and anim then anim[p.clip] else nil
	if state == "tell" and a then
		-- 치기 바로 앞의 s장(hit-s ~ hit-1 — 휘두르는 도중)은 예고의 마지막 s장 시간에만 차례로. 그 앞까지는 제 빠르기로 틀고 다 치켜든 자세(hit-s-1)에서 멈춰 기다린다
		--   swing = 휘두르는 도중의 장 수(공방 design/bosses.js의 BOSS_SHEET — 성벽 거인 · 쇠사슬 간수의 내려치기는 둘). 없으면 하나
		local s = a.swing or 1
		local lead = s / fps
		if t >= p.tell - lead then
			return p.clip, min(a.hit - 1, a.hit - s + floor((t - (p.tell - lead)) * fps)) + 1, false
		end
		return p.clip, min(a.hit - s - 1, floor(t * max(fps, (a.hit - s) / (p.tell - lead)))) + 1, false
	elseif state == "act" and a then
		return p.clip, min(a.to, a.hit + floor(t * fps)) + 1, false
	elseif state == "dash" and clips.run then
		return loop("run", 2) -- 내달리기: 걷는 그림을 두 배 빠르게
	elseif state == "idle" and tail and anim and anim[tail.clip] then
		local f = anim[tail.clip].hit + floor(tail.t * fps)
		if f <= anim[tail.clip].to then
			return tail.clip, f + 1, false
		end
	end
	if state == "run" and clips.run then
		return loop("run", 1)
	end
	-- 기믹이 정한 상태(용암 거인 — 2026-11-04: grab 쥐고 있다 · boil 끓어오르는 분화구 · shift 부위가 부서진다 · sink · under · rise 못 속으로 · 못뿐 · 솟음)는
	--  같은 이름의 동작을 한 번 틀고 끝 장에서 멈춘다(loop가 있으면 그 구간을 되풀이)
	if state ~= "idle" and state ~= "tell" and state ~= "act" and state ~= "dash" and state ~= "roar" and clips[state] then
		return hold(state)
	end
	local clip, frame = loop("idle", 1)
	return clip, frame, state == "tell" or state == "act" or state == "dash"
end

-- 부위가 있는 보스(용암 거인 — 2026-11-04)의 페이즈: 남은 체력으로(서버 sim/lavagim.luau의 partOf와 같은 셈 — 부위의 아래 끝과 같으면 다음 부위)
function BossFx.phaseOf(hp: number, maxHp: number, parts): number
	local acc = 0
	local ph = #parts
	for i = #parts, 1, -1 do
		if hp > maxHp * acc then
			ph = i
		end
		acc += parts[i].share
	end
	return ph
end
-- 페이즈마다 그림이 다른 동작(idle → idle2 · stagger → stagger3 …): 그 페이즈의 이름이 있으면 그것. phaseClips = body에 넘길 동작 묶음(같은 이름으로 그 페이즈의 것을 찾는다)
local phaseCache = setmetatable({}, { __mode = "k" })
function BossFx.phaseName(clips, name: string, ph: number): string
	if ph > 1 and clips[name .. ph] then
		return name .. ph
	end
	return name
end
function BossFx.phaseClips(clips, ph: number)
	local byPh = phaseCache[clips]
	if not byPh then
		byPh = {}
		phaseCache[clips] = byPh
	end
	if not byPh[ph] then
		byPh[ph] = setmetatable({}, { __index = function(_, k)
			return clips[BossFx.phaseName(clips, k, ph)]
		end })
	end
	return byPh[ph]
end

-- 쓰러진 보스의 몸 — 쓰러지는 동작 그림(death)이 있을 때. 없으면 nil(부르는 쪽이 전처럼 선 채로 사라지게 한다). 시험 탭 bossfx.js의 fall과 같은 셈.
--   t = 쓰러진 뒤 흐른 시간 · 돌려주는 것: 동작 · 장(1부터) · 또렷한 정도(1 → 0)
--   그 동작을 제 빠르기로 한 번 틀고 마지막 장(쓰러져 누운 장)에서 멈춘다 → anim.fall.hold초 뒤부터 fade초에 걸쳐 사라진다(공방 design/bosses.js의 BOSS_FALL)
function BossFx.fall(t: number, clips, anim): (string?, number, number)
	local c = clips.death
	local F = anim and anim.fall
	if not c or not F then
		return nil, 1, 1
	end
	local fps = c.fps or anim.fps or 12
	local over = t - #c.frames / fps - F.hold
	return "death", min(#c.frames, floor(t * fps) + 1), if over <= 0 then 1 else max(0, 1 - over / F.fade)
end

-- 예고를 그린다(상태가 tell인 동안 장마다): (x, y) = 보스의 발밑 가운데(바닥) · dir = 보는 쪽 · p = 패턴 · k = 0 → 1 · a · b = 움직이는 범위(내달리기의 끝) · top = 몸의 높이(머리 위에 느낌표를 띄운다 — nil이면 느낌표 없이)
--  aim = 겨눈 자리(도약 찍기 — 내려앉아 찍을 자리를 그린다. 뛰기 직전까지 겨눈 사람을 따라온다)
function BossFx.tell(ctx, x: number, y: number, dir: number, p, k: number, a: number, b: number, top: number?, aim: number?, mark: string?)
	-- 맞을 자리마다 area 하나(2026-11-09 — 위 area): 도약 찍기 = 내려앉을 자리(겨눈 사람을 따라온다) · 치는 자리 · 낮은 띠 · 날아갈 길 · 갈고리 · 내달리기 — 방 전체(±999)는 방의 둘레까지만
	local function span(u: number, v: number): (number, number)
		return math.clamp(min(u, v), a - 20, b + 20), math.clamp(max(u, v), a - 20, b + 20)
	end
	if p.band then -- 끓는 숨 · 가로 열선(발이 바닥에서 lo 위)
		local lo, hi = span(x + dir * p.band.from, x + dir * p.band.to)
		BossFx.area(ctx, lo, hi, y, if p.band.lines then 230 else p.band.hi, k, p.band.lo or 0)
	end
	if p.leap and p.zone then
		local d = if (aim or x) > x then 1 elseif (aim or x) < x then -1 else dir
		local land = math.clamp((aim or x) - d * p.leap.aim, a, b)
		local lo, hi = span(land + d * p.zone.from, land + d * p.zone.to)
		BossFx.area(ctx, lo, hi, y, min(p.zone.up, 230), k)
	elseif p.zone then
		local lo, hi = span(x + dir * p.zone.from, x + dir * p.zone.to)
		BossFx.area(ctx, lo, hi, y, min(p.zone.up, 230), k)
	end
	if p.wave and p.wave.dir == "front" and not p.zone then -- 검기 · 화살이 날아갈 길(맞는 높이)
		local x0 = x + dir * p.wave.at
		local lo, hi = span(x0, x0 + dir * p.wave.range)
		BossFx.area(ctx, lo, hi, y, p.wave.up, k, p.wave.lift or 0)
	end
	if p.hook then -- 낚아채기(불씨 도둑 두목)
		local x0 = x + dir * (p.hook.at or 0)
		local lo, hi = span(x0, x0 + dir * p.hook.range)
		BossFx.area(ctx, lo, hi, y, p.hook.up, k)
	end
	if p.dash then -- 내달리기
		local lo, hi = span(x, if dir > 0 then b else a)
		BossFx.area(ctx, lo, hi, y, p.dash.up or 26, k)
	end
	if p.summon then
		for _, ax in p.summon.at do
			BossFx.callMark(ctx, ax, y, k)
		end
	end
	if top then
		if mark == "archer" then
			BossFx.crosshair(ctx, x, y - top - 6, k)
		elseif mark == "knight" then
			BossFx.swordSigil(ctx, x, y - top - 6, k)
		elseif mark == "thief" then
			BossFx.bombSigil(ctx, x, y - top - 6, k)
		elseif mark == "lava" then
			BossFx.magmaSigil(ctx, x, y - top - 6, k)
		else
			BossFx.alert(ctx, x, y - top - 6, k)
		end
	end
end

return BossFx
