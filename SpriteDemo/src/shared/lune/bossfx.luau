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

-- 예고: 맞을 자리(가로 lo~hi · 바닥 y에서 위로 up)가 칠해지고, 보스 쪽에서부터 짙게 차오른다(k = 0 → 1). 다 차면 친다. dir = 차오르는 쪽(1 = lo에서 hi로)
--  테두리는 두 점 굵기 · 끝이 가까우면(k > 0.7) 테두리가 희게 깜박인다
function BossFx.zone(ctx, lo: number, hi: number, y: number, up: number, dir: number, k: number)
	lo, hi, y = R(lo), R(hi), R(y)
	local w, fill = hi - lo, max(1, R((hi - lo) * k))
	local fx = if dir > 0 then lo else hi - fill
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	ctx:style(T.n)
	ctx:alpha(0.22)
	ctx:rect(lo, y - up, w, up)
	ctx:alpha(0.42)
	ctx:rect(fx, y - up, fill, up)
	ctx:alpha(1)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(lo, y - 2, w, 3)
	ctx:rect(lo, y - up, w, 1)
	ctx:rect(lo, y - up, 2, up)
	ctx:rect(hi - 2, y - up, 2, up)
	ctx:style(T.w)
	ctx:rect(if dir > 0 then fx + fill - 1 else fx, y - up, 1, up) -- 차오르는 앞머리의 흰 줄
end

-- 예고(내달리기): 바닥을 따라 벽까지 가는 띠 + 달릴 쪽을 가리키는 꺾쇠들(k에 따라 앞으로 흐른다)
function BossFx.lane(ctx, lo: number, hi: number, y: number, dir: number, k: number)
	lo, hi, y = R(lo), R(hi), R(y)
	local w = hi - lo
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	local slide = R(k * 64) % 16
	ctx:style(T.n)
	ctx:alpha(0.22)
	ctx:rect(lo, y - 14, w, 14)
	ctx:alpha(1)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(lo, y - 2, w, 3)
	ctx:rect(lo, y - 14, w, 1)
	ctx:style(if blink then T.w else T.l)
	local x = lo + 6
	while x < hi - 6 do
		local cx = if dir > 0 then x + slide else x + 15 - slide
		if cx >= lo + 5 and cx <= hi - 6 then
			for i = 0, 4 do
				ctx:rect(cx - dir * i, y - 8 - i, 2, 1)
				ctx:rect(cx - dir * i, y - 8 + i, 2, 1)
			end
		end
		x += 16
	end
end

-- 느낌표: (x, y) = 아래 끝의 가운데. 분홍 마름모 안의 흰 느낌표 — 예고하는 동안 보스의 머리 위에 뜬다. 끝이 가까우면 깜박인다
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

-- 예고(호령): 졸개가 나올 자리에 아래에서부터 솟는 빛줄(k만큼) + 그 위의 느낌표
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

-- ---- 그림자 사수(그림자 허수아비 — 2026-10-27)의 예고: 다른 보스와 다른 「저격수」의 표시(공방 bossfx.js의 aimLine · reticle · seed · crosshair를 줄마다 옮긴 것) ----
--  사용자: "지금 패턴표시랑 이펙트랑 너무 똑같잖아 달라야지 다른보슨데" — 그때까지 세 보스가 모두 같은 분홍 상자 · 기둥 · 꺾쇠 띠 · 「!」였다.
--  맞는 자리(판정)는 다른 보스와 같은 셈 그대로 한 점까지 보인다 — 모양만 다르다(색은 적의 분홍 T). 보스의 story.mark = "archer"면 이것을 쓴다
local SLATE = 0x232931
local function dashed(ctx, x0: number, x1: number, y: number, on: number, off: number, shift: number)
	local p = on + off
	local x = x0 - p + ((shift % p) + p) % p
	while x < x1 do
		local a, b = max(x0, x), min(x1, x + on)
		if b > a then
			ctx:rect(a, y, b - a, 1)
		end
		x += p
	end
end
-- 조준선: 화살이 날아갈 높이(바닥에서 fly)의 선 + 흐르는 흰 마디 · 쏘기 직전 세 점 굵기로 깜박 · 맞는 높이(발이 바닥에서 lift ~ up)는 위아래의 어두운 점선과 옅은 칠
function BossFx.aimLine(ctx, lo: number, hi: number, y: number, fly: number, lift: number, up: number, dir: number, k: number)
	lo, hi, y = R(lo), R(hi), R(y)
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	local ly, shift, b0, b1 = y - R(fly), R(k * 90) * dir, y - R(lift), y - R(up)
	ctx:style(T.n)
	ctx:alpha(0.16)
	ctx:rect(lo, b1, hi - lo, b0 - b1)
	ctx:alpha(0.7)
	ctx:style(T.d)
	dashed(ctx, lo, hi, b0 - 1, 3, 3, shift)
	dashed(ctx, lo, hi, b1, 3, 3, shift)
	ctx:alpha(1)
	ctx:style(T.d)
	ctx:rect(lo, ly - 1, hi - lo, 3)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(lo, ly, hi - lo, 1)
	if k > 0.7 then
		ctx:style(if blink then T.w else T.l)
		ctx:rect(lo, ly - 1, hi - lo, 3)
	else
		ctx:style(T.w)
		dashed(ctx, lo, hi, ly, 6, 10, shift)
	end
	local sx = if dir > 0 then lo else hi
	ctx:style(T.w)
	ctx:rect(sx - 4, ly, 9, 1)
	ctx:rect(sx, ly - 4, 1, 9)
end
local function ellipse(ctx, x: number, cy: number, rx: number, ry: number)
	for a = 0, 71 do
		local t = a / 72 * math.pi * 2
		ctx:rect(R(x + math.cos(t) * rx), R(cy + math.sin(t) * ry), 1, 1)
	end
end
local function edges(ctx, x: number, y: number, r: number, up: number)
	ctx:alpha(0.6)
	ctx:style(T.d)
	local j = 0
	while j < up do
		ctx:rect(x - r, y - j - 2, 1, 2)
		ctx:rect(x + r - 1, y - j - 2, 1, 2)
		j += 4
	end
	ctx:alpha(1)
end
-- 조준경(화살비의 자리): 바닥의 납작한 고리 + 십자 · 바깥 고리가 2.2배에서 좁혀 든다 · 하늘에서 내려오는 점선 · 판정의 양옆은 어두운 점선
function BossFx.reticle(ctx, x: number, y: number, r: number, up: number, k: number)
	x, y = R(x), R(y)
	k = math.clamp(k, 0, 1)
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	edges(ctx, x, y, r, up)
	ctx:style(if blink then T.w else T.n)
	ellipse(ctx, x, y - 3, r, 3)
	ctx:rect(x - r - 3, y - 3, r * 2 + 7, 1)
	ctx:rect(x, y - 8, 1, 9)
	local rr = r * (2.2 - 1.2 * k)
	ctx:alpha(0.4 + 0.6 * k)
	ctx:style(T.l)
	ellipse(ctx, x, y - 3, rr, max(3, rr * 0.25))
	ctx:alpha(0.65)
	ctx:style(if blink then T.w else T.l)
	local top, off = y - up - 70, R(k * 60) % 8
	local yy = top + off
	while yy < y - 10 do
		ctx:rect(x, R(yy), 1, 4)
		yy += 8
	end
	ctx:alpha(1)
end
-- 수정 씨앗(수정 덫의 자리): 바닥에 박힌 마름모 결정 · 갈라지는 금(k만큼) · 자라는 뾰족한 결정 넷 · 판정의 양옆은 어두운 점선
function BossFx.seed(ctx, x: number, y: number, r: number, up: number, k: number)
	x, y = R(x), R(y)
	k = math.clamp(k, 0, 1)
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	edges(ctx, x, y, r, up)
	local reach = R(r * min(1, k * 1.4))
	for i = 0, reach do
		local a = floor(i / 3) % 2
		ctx:style(T.d)
		ctx:rect(x + i, y - 3 - a, 1, 3)
		ctx:rect(x - i, y - 3 - (1 - a), 1, 3)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(x + i, y - 2 - a, 1, 1)
		ctx:rect(x - i, y - 2 - (1 - a), 1, 1)
	end
	for _, c in { { -0.75, 0.55, -1 }, { -0.3, 0.85, 0 }, { 0.25, 1, 0 }, { 0.7, 0.65, 1 } } do
		local h = R(18 * c[2] * k)
		if h >= 3 then
			local cx = R(x + c[1] * r)
			for j = 0, h - 1 do
				local q = j / h
				local half, sx = max(0, R(2.5 * (1 - q))), cx + R(c[3] * q * 2)
				ctx:style(SLATE)
				ctx:rect(sx - half - 1, y - 1 - j, half * 2 + 3, 1)
				ctx:style(if q > 0.8 or blink then T.w else T.n)
				ctx:rect(sx, y - 1 - j, 1, 1)
			end
		end
	end
	ctx:style(SLATE)
	for _, c in { { 11, 0 }, { 10, 1 }, { 9, 2 }, { 8, 2 }, { 7, 3 }, { 6, 3 }, { 5, 3 }, { 4, 3 }, { 3, 2 }, { 2, 2 }, { 1, 1 } } do
		ctx:rect(x - c[2] - 1, y - c[1], c[2] * 2 + 3, 1)
	end
	ctx:style(if blink then T.w else T.n)
	ctx:rect(x, y - 9, 1, 7)
	ctx:style(if blink then T.w else T.l)
	ctx:rect(x + 1, y - 7, 1, 3)
	ctx:style(T.w)
	ctx:rect(x, y - 11, 1, 1)
end
-- 조준 십자선(머리 위 — 다른 보스의 분홍 「!」 대신): (x, y) = 아래 끝의 가운데
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
-- 검은 가시밭(즉사 — 그림자 사수가 화살이 닿지 않는 안쪽 줄을 치는 패턴, 2026-10-27): 판정의 넓이(lo ~ hi · 바닥에서 up) 전체가 어두운 수정빛으로 짙어지고,
--  가운데에서 양쪽으로 바닥의 금이 번지며(k만큼) 그 위로 뾰족한 결정이 12점마다 자란다 · 양 끝 = 굵은 세로 줄(나가야 할 경계 — 쏘기 직전 흰색으로 깜박) · 위 끝 = 점선
--  다른 패턴(분홍 칠이 옅은 상자)보다 칠이 짙다 — 「맞으면 끝」인 것을 한눈에(공방 bossfx.js의 crystalField를 줄마다 옮긴 것)
function BossFx.crystalField(ctx, lo: number, hi: number, y: number, up: number, k: number)
	lo, hi, y = R(lo), R(hi), R(y)
	k = math.clamp(k, 0, 1)
	local top = R(up)
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	ctx:style(SLATE)
	ctx:alpha(0.2 + 0.3 * k)
	ctx:rect(lo, y - top, hi - lo, top)
	ctx:alpha(0.75)
	ctx:style(T.d)
	dashed(ctx, lo, hi, y - top, 4, 4, R(k * 40))
	ctx:alpha(1)
	local mid = R((lo + hi) / 2)
	local reach = R((hi - lo) / 2 * min(1, k * 1.6))
	for i = 0, reach do
		local a = floor(i / 3) % 2
		ctx:style(T.d)
		ctx:rect(mid + i, y - 3 - a, 1, 3)
		ctx:rect(mid - i, y - 3 - (1 - a), 1, 3)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(mid + i, y - 2 - a, 1, 1)
		ctx:rect(mid - i, y - 2 - (1 - a), 1, 1)
	end
	local x, n = lo + 6, 0
	while x <= hi - 6 do
		local h = R((10 + (n * 7) % 9) * k)
		if h >= 3 and math.abs(x - mid) <= reach then
			for j = 0, h - 1 do
				local q = j / h
				local half = max(0, R(2 * (1 - q)))
				ctx:style(SLATE)
				ctx:rect(x - half - 1, y - 1 - j, half * 2 + 3, 1)
				ctx:style(if q > 0.75 or blink then T.w else T.n)
				ctx:rect(x, y - 1 - j, 1, 1)
			end
		end
		x += 12
		n += 1
	end
	ctx:style(if blink then T.w else T.n)
	ctx:rect(lo, y - top, 2, top)
	ctx:rect(hi - 2, y - top, 2, top)
end

-- ---- 타락한 부단장(망령 기사 — 2026-10-28)의 예고: 그림자 사수 · 다른 보스와 다른 「대검 기사」의 표시(공방 bossfx.js의 swordBand · fallingSword · crescentBand · hornRings · plungeMark · crescentLane · pageMark · emberMark · swordSigil을 줄마다 옮긴 것) ----
--  맞는 자리(판정)는 다른 보스와 같은 셈 그대로 한 점까지 보인다(field) — 그 위에 패턴마다 다른 꼴(색은 적의 분홍 T). 보스의 story.mark = "knight"면 이것을 쓴다
local function blinkOf(k: number): boolean
	return k > 0.7 and floor(k * 40) % 2 == 0
end
-- 맞는 자리(가로 lo ~ hi · 바닥 y에서 위로 up — 발이 바닥에서 lift 위여야 맞는 것은 lift부터): 옅은 칠 · 위와 양옆의 어두운 점선 · 바닥의 굵은 줄(lift가 없을 때)
local function field(ctx, lo: number, hi: number, y: number, up: number, k: number, lift: number?)
	local lf = lift or 0
	local b0, b1, blink = y - R(lf), y - R(up), blinkOf(k)
	ctx:alpha(0.16 + 0.1 * k)
	ctx:style(T.n)
	ctx:rect(lo, b1, hi - lo, b0 - b1)
	ctx:alpha(0.7)
	ctx:style(T.d)
	dashed(ctx, lo, hi, b1, 3, 3, R(k * 30))
	local j = 0
	while j < b0 - b1 do
		ctx:rect(lo, b1 + j, 1, 2)
		ctx:rect(hi - 1, b1 + j, 1, 2)
		j += 4
	end
	ctx:alpha(1)
	if lf == 0 then
		ctx:style(if blink then T.w else T.n)
		ctx:rect(lo, y - 2, hi - lo, 3)
	end
end
-- 가로 칼(칼끝이 dir 쪽): 손잡이 끝 hx · 가운데 줄 cy · 칼날 길이 len(손잡이 · 코등이는 따로)
local function hSword(ctx, hx: number, cy: number, dir: number, len: number, blink: boolean)
	if len < 2 then
		return
	end
	local gx = hx + dir * 7
	local b0 = gx + dir * 3
	for i = 0, len - 1 do
		local x = b0 + dir * i
		local half = if i >= len - 6 then max(0, R(((len - 1 - i) / 6) * 2)) else 2
		ctx:style(T.d)
		ctx:rect(x, cy - half - 1, 1, half * 2 + 3)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(x, cy - half, 1, half * 2 + 1)
		if half >= 1 then
			ctx:style(T.w)
			ctx:rect(x, cy - half, 1, 1)
			ctx:style(T.l)
			ctx:rect(x, cy, 1, 1)
		end
	end
	local gl = min(gx, gx + dir * 2)
	ctx:style(T.d)
	ctx:rect(gl - 1, cy - 8, 5, 17)
	ctx:style(if blink then T.w else T.l)
	ctx:rect(gl, cy - 7, 3, 15) -- 코등이
	local hl = min(hx, gx)
	ctx:style(T.d)
	ctx:rect(hl, cy - 2, 8, 5)
	ctx:style(T.n)
	ctx:rect(hl + 1, cy - 1, 6, 3) -- 손잡이
end
-- 세로 칼(칼끝이 아래): 가운데 x · 칼끝 ty · 칼날 길이 len
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
function BossFx.swordBand(ctx, lo: number, hi: number, y: number, up: number, dir: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local base = if dir > 0 then lo else hi
	hSword(ctx, base, y - R(up * 0.55), dir, R((hi - lo - 12) * min(1, k * 1.2)), blinkOf(k))
end
function BossFx.fallingSword(ctx, lo: number, hi: number, y: number, up: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local mid, e = R((lo + hi) / 2), k * k * (3 - 2 * k)
	local top = y - R(up) - 46
	local ty, rx = R(top + (y - 4 - top) * e * 0.85), R(((hi - lo) / 2) * (0.3 + 0.7 * k))
	ctx:alpha(0.35 + 0.5 * k)
	ctx:style(T.d)
	ctx:rect(mid - rx, y - 4, rx * 2, 2) -- 바닥의 칼 그림자
	ctx:alpha(1)
	vSword(ctx, mid, ty, 34, blinkOf(k))
end
function BossFx.crescentBand(ctx, lo: number, hi: number, y: number, up: number, dir: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local w = hi - lo
	local n, blink = R(w * min(1, k * 1.15)), blinkOf(k)
	for i = 0, n - 1 do
		local x = if dir > 0 then lo + i else hi - 1 - i
		local h = max(1, R(up * 0.9 * math.sin(math.pi * i / max(1, w - 1))))
		local hin = R(h * 0.45)
		ctx:style(T.d)
		ctx:rect(x, y - 3 - h, 1, 2)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(x, y - 2 - h, 1, max(1, h - hin))
		ctx:style(T.w)
		ctx:rect(x, y - 2 - h, 1, 1)
	end
	if n > 2 and n < w then
		local head = if dir > 0 then lo + n else hi - n
		ctx:style(T.w)
		ctx:rect(head - 1, y - R(up), 2, R(up)) -- 쓸어 가는 앞머리
	end
end
function BossFx.hornRings(ctx, lo: number, hi: number, y: number, up: number, cx: number, cy: number, k: number)
	lo, hi, y, cx, cy, k = R(lo), R(hi), R(y), R(cx), R(cy), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local blink = blinkOf(k)
	for i = 0, 2 do -- 머리 높이에서 양쪽으로 퍼지는 울림 고리 셋
		local r = 10 + ((k * 54 + i * 18) % 54)
		ctx:alpha(0.35 + 0.65 * (1 - (r - 10) / 54))
		for s = -1, 1, 2 do
			for d = -55, 55, 4 do
				local t = d * math.pi / 180
				local px, py = R(cx + s * math.cos(t) * r), R(cy + math.sin(t) * r)
				ctx:style(T.d)
				ctx:rect(px - 1, py - 1, 3, 3)
				ctx:style(if blink then T.w elseif i == 0 then T.l else T.n)
				ctx:rect(px, py, 1, 1)
			end
		end
	end
	ctx:alpha(1)
	local slide, half = R(k * 48) % 12, R((hi - lo) / 2) -- 바닥: 양쪽 바깥으로 흐르는 꺾쇠(충격파가 바닥을 따라 퍼진다)
	ctx:style(if blink then T.w else T.l)
	for s = -1, 1, 2 do
		local o = 6 + slide
		while o < 46 do
			local x = cx + s * (half + o)
			for i = 0, 3 do
				ctx:rect(x - s * i, y - 6 - i, 2, 1)
				ctx:rect(x - s * i, y - 6 + i, 2, 1)
			end
			o += 12
		end
	end
end
function BossFx.plungeMark(ctx, lo: number, hi: number, y: number, up: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local mid, blink = R((lo + hi) / 2), blinkOf(k)
	local reach = R(((hi - lo) / 2) * min(1, k * 1.4)) -- 바닥의 갈라짐(가운데에서 양쪽으로)
	for i = 0, reach do
		local a = floor(i / 4) % 2
		ctx:style(T.d)
		ctx:rect(mid + i, y - 4 - a, 1, 3)
		ctx:rect(mid - i, y - 4 - (1 - a), 1, 3)
		ctx:style(if blink then T.w else T.l)
		ctx:rect(mid + i, y - 3 - a, 1, 1)
		ctx:rect(mid - i, y - 3 - (1 - a), 1, 1)
	end
	vSword(ctx, mid, y - R(up) - 8 + R(math.sin(k * 18) * 2), 26, blink) -- 꽂힐 자리 위에 떠 있는 칼(칼끝이 아래)
end
function BossFx.crescentLane(ctx, lo: number, hi: number, y: number, fly: number, lift: number, up: number, dir: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k, lift)
	local blink, ly, slide = blinkOf(k), y - R(((lift or 0) + up) / 2), R(k * 96) % 24 -- 초승달은 맞는 높이(lift ~ up)의 가운데에(fly는 그림의 높이 — 쓰지 않는다)
	local x0 = lo + 8
	while x0 < hi - 8 do -- 날아갈 높이에 흐르는 초승달(보스 쪽이 오목)
		local x = if dir > 0 then x0 + slide else x0 + 23 - slide
		if x >= lo + 6 and x <= hi - 7 then
			for d = -70, 70, 7 do
				local t = d * math.pi / 180
				local px, py = R(x + dir * (math.cos(t) * 7 - 4)), R(ly + math.sin(t) * 8)
				ctx:style(T.d)
				ctx:rect(px - 1, py - 1, 3, 3)
				ctx:style(if blink then T.w elseif math.abs(d) < 30 then T.w else T.l)
				ctx:rect(px, py, 1, 1)
			end
		end
		x0 += 24
	end
end
function BossFx.pageMark(ctx, x: number, y: number, r: number, up: number, k: number)
	x, y, k = R(x), R(y), math.clamp(k, 0, 1)
	local blink = blinkOf(k)
	edges(ctx, x, y, r, up)
	ctx:style(if blink then T.w else T.n)
	ellipse(ctx, x, y - 2, r, 2)
	ctx:rect(x - r, y - 2, r * 2, 1) -- 바닥의 납작한 고리
	local py, px = R(y - up - 56 + (up + 56 - 12) * k), x + R(math.sin(k * 9) * 5) -- 흔들리며 떨어지는 종이(9 x 11 — 기울기가 오간다)
	local skew = if math.sin(k * 9) > 0 then 1 else -1
	for j = 0, 10 do
		local sx = px - 4 + R((j - 5) * 0.25 * skew)
		ctx:style(T.d)
		ctx:rect(sx - 1, py + j, 11, 1)
		ctx:style(if j == 0 or j == 10 then T.d elseif blink then T.w else T.l)
		ctx:rect(sx, py + j, 9, 1)
		if j % 3 == 2 and j < 10 then
			ctx:style(T.n)
			ctx:rect(sx + 2, py + j, 5, 1)
		end
	end
	if k > 0.45 then -- 종이 귀퉁이의 불
		ctx:style(T.n)
		ctx:rect(px + 3, py - 3, 3, 3)
		ctx:style(T.w)
		ctx:rect(px + 4, py - 4, 1, 2)
	end
end
function BossFx.emberMark(ctx, x: number, y: number, r: number, up: number, k: number)
	x, y, k = R(x), R(y), math.clamp(k, 0, 1)
	local blink = blinkOf(k)
	edges(ctx, x, y, r, up)
	ctx:alpha(0.18 + 0.2 * k)
	ctx:style(T.n)
	ctx:rect(x - r, y - up, r * 2, up)
	ctx:alpha(1)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(x - r, y - 2, r * 2, 3)
	local h, fl = R(6 + 18 * k), floor(k * 30) % 2 -- 바닥에서 자라는 불씨(아래가 넓고 위가 뾰족 · 흔들린다)
	for j = 0, h - 1 do
		local q = j / h
		local half = R(4.5 * (1 - q) ^ 0.6 * min(1, q * 4 + 0.3))
		local sx = x + R(math.sin(q * 5 + fl) * q * 2)
		ctx:style(T.d)
		ctx:rect(sx - half - 1, y - 3 - j, half * 2 + 3, 1)
		ctx:style(if q > 0.7 or blink then T.w elseif q > 0.35 then T.l else T.n)
		ctx:rect(sx - half, y - 3 - j, half * 2 + 1, 1)
	end
end
-- 머리 위(다른 보스의 분홍 「!」 · 그림자 사수의 조준 십자선 대신): 칼끝이 아래인 작은 칼 — (x, y) = 아래 끝의 가운데
function BossFx.swordSigil(ctx, x: number, y: number, k: number)
	vSword(ctx, R(x), R(y) - 2, 12, blinkOf(k))
end

-- ---- 불씨 도둑 두목(2026-10-28)의 예고: 그림자 사수 · 부단장과 다른 「도둑」의 표시(공방 bossfx.js의 hookBand · sackRing · fuseRoom · hookLine · rollLane · bombMark · powderMark · bombSigil을 줄마다 옮긴 것) ----
--  맞는 자리(판정)는 다른 보스와 같은 셈(field) 그대로 — 그 위에 패턴마다 다른 꼴: 갈고리 칼 · 휘도는 자루 · 타 들어가는 도화선 · 사슬 · 구르는 공 · 폭탄 · 화약 자루. 보스의 story.mark = "thief"면 이것을 쓴다
-- 작은 폭탄(둥근 몸 7점 + 도화선 · 끝의 불티): (x, y) = 바닥 가운데 · fuse = 도화선의 길이(점)
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
-- 갈고리 베기: 맞는 자리 + 앞으로 낮게 자라는 갈고리 칼(끝이 위로 굽은 미늘)
function BossFx.hookBand(ctx, lo: number, hi: number, y: number, up: number, dir: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local blink, cy = blinkOf(k), y - R(up * 0.4)
	local base = if dir > 0 then lo else hi
	local len = R((hi - lo - 4) * min(1, k * 1.2))
	for i = 0, len - 1 do
		local x = base + dir * i
		ctx:style(T.d)
		ctx:rect(x, cy - 2, 1, 5)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(x, cy - 1, 1, 3)
		ctx:style(T.w)
		ctx:rect(x, cy - 1, 1, 1)
	end
	if len > 6 then
		local tx = base + dir * (len - 1)
		ctx:style(T.d)
		ctx:rect(tx - 1, cy - 8, 3, 8)
		ctx:rect(min(tx, tx - dir * 4) - 1, cy - 9, 6, 3)
		ctx:style(if blink then T.w else T.l)
		ctx:rect(tx, cy - 7, 1, 6)
		ctx:rect(min(tx, tx - dir * 3), cy - 8, 4, 1) -- 미늘(칼끝이 위로 굽어 몸 쪽으로)
	end
end
-- 자루 돌리기: 맞는 자리 + 몸 둘레의 점선 고리 · 그 고리를 따라 도는 자루(어두운 덩이와 분홍 단지 셋)
function BossFx.sackRing(ctx, lo: number, hi: number, y: number, up: number, cx: number, k: number)
	lo, hi, y, cx, k = R(lo), R(hi), R(y), R(cx), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local blink, rx, ry, cy = blinkOf(k), (hi - lo) / 2 - 2, up / 2, y - R(up / 2)
	ctx:style(if blink then T.w else T.l)
	for a = 0, 35 do
		if a % 2 == 0 then
			local t = a / 36 * math.pi * 2
			ctx:rect(R(cx + math.cos(t) * rx), R(cy + math.sin(t) * ry), 2, 1)
		end
	end
	local t = k * math.pi * 3
	local sx, sy = R(cx + math.cos(t) * rx), R(cy + math.sin(t) * ry)
	ctx:style(T.d)
	ctx:rect(sx - 5, sy - 4, 11, 9)
	ctx:style(SLATE)
	ctx:rect(sx - 4, sy - 3, 9, 7)
	ctx:style(if blink then T.w else T.n)
	for i = -1, 1 do
		ctx:rect(sx + i * 3, sy + 1, 2, 2) -- 단지 셋
	end
end
-- 큰 불단지(방 전체): 옅은 맞는 자리 + 방의 양 끝에서 보스 쪽으로 타 들어가는 도화선 둘(k = 1에 보스 발밑에서 만난다 — 그때 터진다)
function BossFx.fuseRoom(ctx, lo: number, hi: number, y: number, up: number, cx: number, k: number)
	lo, hi, y, cx, k = R(lo), R(hi), R(y), R(cx), math.clamp(k, 0, 1)
	ctx:alpha(0.08 + 0.12 * k)
	ctx:style(T.n)
	ctx:rect(lo, y - R(min(up, 90)), hi - lo, R(min(up, 90)))
	ctx:alpha(1)
	local blink = blinkOf(k)
	for s = -1, 1, 2 do
		local from = if s < 0 then lo else hi
		local at = R(from + (cx - from) * k)
		local a0, a1 = min(at, cx), max(at, cx)
		ctx:style(T.d)
		ctx:rect(a0, y - 4, a1 - a0, 3)
		ctx:style(T.l)
		dashed(ctx, a0, a1, y - 3, 2, 2, 0) -- 아직 타지 않은 도화선
		ctx:style(if blink then T.w else T.n)
		ctx:rect(at - 2, y - 6, 5, 5)
		ctx:style(T.w)
		ctx:rect(at - 1, y - 5, 3, 3) -- 불티
	end
end
-- 낚아채기: 갈고리가 날아갈 길(높이 0 ~ up — 뛰면 넘는다) + 앞으로 뻗는 사슬 · 끝의 갈고리
function BossFx.hookLine(ctx, lo: number, hi: number, y: number, up: number, dir: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local blink, cy = blinkOf(k), y - R(up * 0.5)
	local base = if dir > 0 then lo else hi
	local len = R((hi - lo) * min(1, k * 1.3))
	for i = 0, len - 1, 4 do -- 사슬 고리(가로 · 세로가 엇갈린다)
		local x = base + dir * i
		ctx:style(T.d)
		if (i / 4) % 2 == 0 then
			ctx:rect(min(x, x + dir * 3) - 1, cy - 2, 5, 4)
			ctx:style(if blink then T.w else T.l)
			ctx:rect(min(x, x + dir * 3), cy - 1, 3, 2)
		else
			ctx:rect(x - 1, cy - 3, 3, 6)
			ctx:style(if blink then T.w else T.l)
			ctx:rect(x, cy - 2, 1, 4)
		end
	end
	if len > 8 then
		local tx = base + dir * len
		ctx:style(T.d)
		ctx:rect(tx - 2, cy - 7, 4, 10)
		ctx:rect(min(tx, tx - dir * 5) - 1, cy + 1, 7, 4)
		ctx:style(if blink then T.w else T.n)
		ctx:rect(tx - 1, cy - 6, 2, 8)
		ctx:rect(min(tx, tx - dir * 4), cy + 2, 5, 2) -- 갈고리(아래가 몸 쪽으로 굽는다)
	end
end
-- 굴러 박치기: 방 끝까지의 낮은 맞는 자리 + 그 위를 굴러가는 공(몸을 만 두목 — 어두운 원 · 분홍 단지)
function BossFx.rollLane(ctx, lo: number, hi: number, y: number, up: number, dir: number, k: number)
	lo, hi, y, k = R(lo), R(hi), R(y), math.clamp(k, 0, 1)
	field(ctx, lo, hi, y, up, k)
	local blink, slide, r = blinkOf(k), R(k * 120) % 40, R(min(up, 26) / 2) - 2
	local x0 = lo + 8
	while x0 < hi - 8 do
		local x = if dir > 0 then x0 + slide else x0 + 39 - slide
		if x - r >= lo and x + r <= hi then
			local cy = y - r - 2
			ctx:style(T.d)
			ellipse(ctx, x, cy, r + 1, r + 1)
			ctx:style(if blink then T.w else T.l)
			ellipse(ctx, x, cy, r, r)
			local t = k * 20 * dir
			ctx:style(T.n)
			ctx:rect(R(x + math.cos(t) * (r - 3)) - 1, R(cy + math.sin(t) * (r - 3)) - 1, 3, 3) -- 도는 단지
		end
		x0 += 40
	end
end
-- 폭탄 깔기(줄지어 굴려 놓은 자리): 판정의 양옆 점선 + 바닥 고리 + 그 자리의 폭탄 — 도화선이 k만큼 타서 줄어든다
function BossFx.bombMark(ctx, x: number, y: number, r: number, up: number, k: number)
	x, y, k = R(x), R(y), math.clamp(k, 0, 1)
	local blink = blinkOf(k)
	edges(ctx, x, y, r, up)
	ctx:style(if blink then T.w else T.n)
	ellipse(ctx, x, y - 2, r, 2)
	bomb(ctx, x, y - 1, max(0, R(8 * (1 - k))), blink)
end
-- 화약 비(한 칸 걸러): 판정 + 하늘에서 흔들리며 떨어지는 화약 자루(묶은 목 · 흘리는 가루)
function BossFx.powderMark(ctx, x: number, y: number, r: number, up: number, k: number)
	x, y, k = R(x), R(y), math.clamp(k, 0, 1)
	local blink = blinkOf(k)
	edges(ctx, x, y, r, up)
	ctx:alpha(0.16 + 0.18 * k)
	ctx:style(T.n)
	ctx:rect(x - r, y - up, r * 2, up)
	ctx:alpha(1)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(x - r, y - 2, r * 2, 3)
	local py, px = R(y - up - 50 + (up + 50 - 14) * k), x + R(math.sin(k * 8) * 3)
	ctx:style(T.d)
	ctx:rect(px - 5, py, 11, 10)
	ctx:rect(px - 2, py - 3, 5, 3)
	ctx:style(SLATE)
	ctx:rect(px - 4, py + 1, 9, 8)
	ctx:style(if blink then T.w else T.l)
	ctx:rect(px - 1, py - 2, 3, 1) -- 묶은 목
	ctx:style(T.n)
	ctx:rect(px - 2, py + 4, 5, 2)
	ctx:style(T.d)
	for i = 1, 3 do -- 흘리는 가루
		ctx:rect(px - 3 + i * 2, py + 10 + i * 3 + floor(k * 30) % 3, 1, 1)
	end
end
-- 머리 위(분홍 「!」 대신): 불이 붙은 작은 폭탄 — (x, y) = 아래 끝의 가운데
function BossFx.bombSigil(ctx, x: number, y: number, k: number)
	bomb(ctx, R(x), R(y), 5, blinkOf(k))
end

-- ---- 새 패턴의 예고(2026-10-12 밤 — 공방 design/bosses.js의 STORYBOSS_NEXT) ----
-- 표시된 자리(불씨 뿌리기 · 봉화 불기둥): 바닥의 굵은 줄(가로 2r) + 그 위로 차오르는 옅은 기둥(k = 0 → 1 — 다 차면 솟는다) · 끝이 가까우면 깜박인다.
--  fromX · fromY = 불씨가 날아오는 곳(보스의 화로 — 있으면 포물선을 그리며 날아와 k = 1에 그 자리에 닿는다)
--  mark · grid = 그 보스의 표시 모양(mark "archer" = 그림자 사수: 화살비는 조준경 · 수정 덫(grid)은 씨앗 — 2026-10-27)
function BossFx.spot(ctx, x: number, y: number, r: number, up: number, k: number, fromX: number?, fromY: number?, mark: string?, grid: boolean?)
	if mark == "archer" then
		if grid then
			BossFx.seed(ctx, x, y, r, up, k)
		else
			BossFx.reticle(ctx, x, y, r, up, k)
		end
		return
	end
	if mark == "knight" then -- 타락한 부단장(2026-10-28): 금서의 불(grid)은 불씨 · 불타는 장부는 떨어지는 종이
		if grid then
			BossFx.emberMark(ctx, x, y, r, up, k)
		else
			BossFx.pageMark(ctx, x, y, r, up, k)
		end
		return
	end
	if mark == "thief" then -- 불씨 도둑 두목(2026-10-28): 화약 비(grid)는 떨어지는 화약 자루 · 폭탄 깔기는 굴려 놓은 폭탄
		if grid then
			BossFx.powderMark(ctx, x, y, r, up, k)
		else
			BossFx.bombMark(ctx, x, y, r, up, k)
		end
		return
	end
	x, y = R(x), R(y)
	k = math.clamp(k, 0, 1)
	local blink = k > 0.7 and floor(k * 40) % 2 == 0
	local h = R(up * k)
	ctx:style(T.n)
	ctx:alpha(0.18)
	ctx:rect(x - r, y - up, r * 2, up)
	ctx:alpha(0.42)
	ctx:rect(x - r, y - h, r * 2, h)
	ctx:alpha(1)
	ctx:style(if blink then T.w else T.n)
	ctx:rect(x - r, y - 2, r * 2, 3)
	ctx:rect(x - r, y - 6, 2, 4)
	ctx:rect(x + r - 2, y - 6, 2, 4)
	ctx:style(T.w)
	ctx:rect(x - r, y - h, r * 2, 1)
	if fromX and fromY and k < 1 then
		local function at(q: number): (number, number)
			return fromX + (x - fromX) * q, fromY + (y - 6 - fromY) * q - math.sin(math.pi * q) * 46
		end
		local ex, ey = at(k)
		local tx, ty = at(max(0, k - 0.05))
		local ux, uy = at(max(0, k - 0.1))
		ctx:style(T.d)
		ctx:rect(R(ux), R(uy), 2, 2)
		ctx:style(T.l)
		ctx:rect(R(tx) - 1, R(ty) - 1, 3, 3)
		ctx:style(T.n)
		ctx:rect(R(ex) - 2, R(ey) - 2, 5, 5)
		ctx:style(T.w)
		ctx:rect(R(ex) - 1, R(ey) - 1, 3, 3)
	end
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
	local clip, frame = loop("idle", 1)
	return clip, frame, state == "tell" or state == "act" or state == "dash"
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
	local archer = mark == "archer" -- 그림자 사수의 저격수 표시(2026-10-27 — 위 aimLine · crosshair)
	local knight = mark == "knight" -- 타락한 부단장의 대검 기사 표시(2026-10-28 — 위 swordBand · fallingSword · crescentBand · hornRings · plungeMark · crescentLane · swordSigil)
	local thief = mark == "thief" -- 불씨 도둑 두목의 도둑 표시(2026-10-28 — 위 hookBand · sackRing · fuseRoom · hookLine · rollLane · bombSigil)
	if p.zone and thief then -- 패턴의 동작(clip)마다 다른 꼴
		local x0, x1 = x + dir * p.zone.from, x + dir * p.zone.to
		local lo, hi = min(x0, x1), max(x0, x1)
		if p.bigjar then
			BossFx.fuseRoom(ctx, max(lo, a - 64), min(hi, b + 32), y, p.zone.up, x, k) -- 방 전체(±999)는 움직이는 범위 둘레까지만 그린다
		elseif p.clip == "slash" then
			BossFx.hookBand(ctx, lo, hi, y, p.zone.up, dir, k)
		elseif p.clip == "spin" then
			BossFx.sackRing(ctx, lo, hi, y, p.zone.up, x, k)
		else
			BossFx.zone(ctx, lo, hi, y, p.zone.up, dir, k)
		end
	elseif p.leap and p.zone then -- 치는 자리가 없는 도약(뒤로 물러서기 — 2026-10-27)은 그리지 않는다
		local d = if (aim or x) > x then 1 elseif (aim or x) < x then -1 else dir
		local land = math.clamp((aim or x) - d * p.leap.aim, a, b)
		local x0, x1 = land + d * p.zone.from, land + d * p.zone.to
		if knight then
			BossFx.plungeMark(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, k)
		else
			BossFx.zone(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, d, k)
		end
	elseif p.zone and knight then -- 패턴의 동작(clip)마다 다른 꼴
		local x0, x1 = x + dir * p.zone.from, x + dir * p.zone.to
		local lo, hi = min(x0, x1), max(x0, x1)
		if p.clip == "thrust" then
			BossFx.swordBand(ctx, lo, hi, y, p.zone.up, dir, k)
		elseif p.clip == "cleave" then
			BossFx.fallingSword(ctx, lo, hi, y, p.zone.up, k)
		elseif p.clip == "sweep" then
			BossFx.crescentBand(ctx, lo, hi, y, p.zone.up, dir, k)
		elseif p.clip == "horn" then
			BossFx.hornRings(ctx, lo, hi, y, p.zone.up, x, y - (top or 80) + 14, k)
		else
			BossFx.zone(ctx, lo, hi, y, p.zone.up, dir, k)
		end
	elseif p.zone then
		local x0, x1 = x + dir * p.zone.from, x + dir * p.zone.to
		if p.kill and archer then
			BossFx.crystalField(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, k) -- 즉사(검은 가시밭 — 2026-10-27)
		else
			BossFx.zone(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, dir, k)
		end
	end
	if p.wave and p.wave.dir == "front" and not p.zone then
		-- 검기: 날아갈 길
		local x0 = x + dir * p.wave.at
		local x1 = math.clamp(x0 + dir * p.wave.range, a - 20, b + 20)
		if archer then
			BossFx.aimLine(ctx, min(x0, x1), max(x0, x1), y, p.wave.fly or 0, p.wave.lift or 0, p.wave.up, dir, k)
		elseif knight then
			BossFx.crescentLane(ctx, min(x0, x1), max(x0, x1), y, p.wave.fly or 0, p.wave.lift or 0, p.wave.up, dir, k)
		else
			BossFx.lane(ctx, min(x0, x1), max(x0, x1), y - (if p.wave.lift then (p.wave.fly or 0) - 7 else 0), dir, k) -- 높은 화살은 날아가는 높이에 띠를(2026-10-27)
		end
	end
	if p.hook then -- 낚아채기(불씨 도둑 두목): 갈고리가 날아갈 길
		local x0 = x + dir * (p.hook.at or 0)
		local x1 = math.clamp(x0 + dir * p.hook.range, a - 20, b + 20)
		BossFx.hookLine(ctx, min(x0, x1), max(x0, x1), y, p.hook.up, dir, k)
	end
	if p.dash then
		local fin = if dir > 0 then b else a
		if thief then
			BossFx.rollLane(ctx, min(x, fin), max(x, fin), y, p.dash.up or 26, dir, k)
		else
			BossFx.lane(ctx, min(x, fin), max(x, fin), y, dir, k)
		end
	end
	if p.summon then
		for _, ax in p.summon.at do
			BossFx.callMark(ctx, ax, y, k)
		end
	end
	if top then
		if archer then
			BossFx.crosshair(ctx, x, y - top - 6, k)
		elseif knight then
			BossFx.swordSigil(ctx, x, y - top - 6, k)
		elseif thief then
			BossFx.bombSigil(ctx, x, y - top - 6, k)
		else
			BossFx.alert(ctx, x, y - top - 6, k)
		end
	end
end

return BossFx
