--!native
--!optimize 2
-- 스토리 보스의 예고와 이펙트 — 공방 시험 탭의 dino-workshop/js/lune/bossfx.js를 줄마다 옮긴 것(고칠 때는 시험 탭에서 먼저 고치고 여기를 맞춘다).
--  사용자 2026-10-11: "패턴, 스킬 이펙트는 따로 만드셔야해요" — 몸의 동작 그림은 사용자가, 맞을 자리의 예고와 치는 순간의 이펙트는 여기서 코드로 그린다(fx.luau와 같은 말투: 한 점 단위 · 네온 한 벌).
--  사용자 같은 날(해 보고): "뭐 보스 패턴도 없고 이펙트도없고 …" → 처음 것은 얇은 선과 작은 고리뿐이라 싸우는 동안 눈에 들어오지 않았다. 크게 다시 만들었다:
--    예고 = 맞을 자리를 짙게 칠하고(차오른다) 머리 위에 느낌표 · 치는 순간 = 맞는 자리 전체를 채우는 번쩍임 + 솟는 가시 일곱 + 파편 + 화면 흔들림 · 내달리기 = 잔상과 속도선, 벽에 닿으면 터진다.
--  색은 적의 분홍(Fx.TONE.pink — 정예 병사의 불티와 같은 색). 싸움의 자료는 data/combat.generated.luau의 mobs[보스].story(공방 design/bosses.js의 STORYBOSS).
--  그리는 일은 화면에서만 일어난다(서버는 부르지 않는다).
local Fx = require(script.Parent.fx)

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local R = Fx.R
local T = Fx.TONE.pink
local HEAD = 88 -- 호령의 고리가 퍼지는 높이(발밑에서 머리까지 — 보스의 그림이 바뀌면 같이 고친다)

local BossFx = {}

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

-- 물결의 마루(땅 울림): 바닥을 따라 가는 뾰족한 물결 + 뒤에 남는 금과 튀는 점. k = 0 → 1(끝에서 사라진다)
function BossFx.crest(ctx, x: number, y: number, dir: number, k: number)
	x, y = R(x), R(y)
	ctx:alpha(if k > 0.85 then max(0, (1 - k) / 0.15) else 1)
	ctx:style(T.d)
	ctx:rect(x - 9, y - 4, 18, 4)
	ctx:style(T.n)
	ctx:rect(x - 7, y - 8, 14, 6)
	ctx:rect(x - 5, y - 12, 10, 4)
	ctx:style(T.l)
	ctx:rect(x - 3 + dir * 2, y - 15, 6, 9)
	ctx:style(T.w)
	ctx:rect(x - 1 + dir * 3, y - 17, 3, 6)
	ctx:style(T.n)
	for i = 1, 5 do
		ctx:rect(x - dir * (9 + i * 5), y - 1 - (i % 2) * 2, 3, 2)
	end
	ctx:alpha(1)
end

local CALL_RINGS = { { 56, 0 }, { 40, 0.12 }, { 26, 0.24 } }

-- 치는 순간의 이펙트(한 번): p = 패턴 · (x, y) = 보스의 발밑 가운데 · dir = 보는 쪽 · shake(세기, 초) = 화면 흔들기(보스의 큰 한 방에만 — 없어도 된다)
function BossFx.strike(fx, p, x: number, y: number, dir: number, shake: ((number, number) -> ())?)
	if p.id == "smash" or p.id == "quake" then -- 내려찍기 · 땅 울림: 맞는 자리 전체가 번쩍이고 땅이 갈라진다 — 겹 고리 + 솟는 돌 가시 일곱 + 튀는 파편 + 피어오르는 먼지
		local a, b = p.zone.from, p.zone.to
		local w, ix = b - a, x + dir * (a + b) / 2
		fx.beam(ix, y, w * 0.9, p.zone.up, T, { life = 0.22 })
		fx.ring(ix, y, 8, w * 0.7, T, { life = 0.5 })
		fx.ring(ix, y, 4, w * 0.45, T, { life = 0.4, delay = 0.08 })
		for i = 0, 6 do
			local dx = (i - 3) * (w / 7)
			fx.spike(ix + dx, y, 10, 34 - abs(i - 3) * 7, T, { life = 0.6, delay = abs(i - 3) * 0.035, lean = dx * 0.15 })
		end
		fx.shards(ix, y - 2, 22, T, { speed = 130, up = 110, kind = "mix", life = 0.7 })
		fx.rise(ix, y, 10, T, { w = w, speed = 40, life = 0.8 })
		if shake then
			shake(3, 0.22)
		end
	elseif p.id == "sweep" then -- 휩쓸기: 땅을 스치는 굵은 띠 — 바닥 바로 위의 긴 줄 둘 + 줄지어 터지는 먼지 + 피어오르는 점
		local a, b = p.zone.from, p.zone.to
		local w, mid = b - a, (a + b) / 2
		fx.cut(x + dir * mid, y - 6, w, 0, T, { life = 0.34, th = 7 })
		fx.cut(x + dir * mid, y - 12, w * 0.7, 0, T, { life = 0.28, th = 3, delay = 0.04 })
		for i = 0, 7 do
			fx.pop(x + dir * (a + 8 + i * (w - 16) / 7), y - 5, T, { r = 4, life = 0.2 + i * 0.03 })
		end
		fx.rise(x + dir * mid, y, 12, T, { w = w, speed = 30, life = 0.7 })
		fx.shards(x + dir * mid, y - 2, 14, T, { speed = 110, up = 40, kind = "dot", dir = dir, spread = 0.7, life = 0.5 })
		if shake then
			shake(2, 0.15)
		end
	elseif p.id == "slash" then -- 내리베기: 맞는 자리의 끝까지 닿는 큰 초승달 둘 + 땅에 긋는 한 줄 + 파편
		local b = p.zone.to
		local r = b * 0.72
		fx.slash(x + dir * (b - r), y - r * 0.5, dir, r, -80, 75, T, { thick = r * 0.34, life = 0.4 })
		fx.slash(x + dir * (b - r), y - r * 0.5, dir, r * 0.72, -60, 60, T, { thick = r * 0.16, life = 0.3 })
		fx.cut(x + dir * b * 0.7, y - 3, b * 0.6, 0, T, { life = 0.3, th = 4 })
		fx.shards(x + dir * b * 0.8, y - 6, 16, T, { speed = 120, up = 70, kind = "mix", dir = dir, spread = 0.9, life = 0.6 })
		if shake then
			shake(3, 0.2)
		end
	elseif p.id == "call" then -- 호령: 머리 위에서 퍼지는 세 겹 고리 + 몸에서 오르는 점 + 졸개가 나오는 자리의 빛기둥과 고리
		for _, q in CALL_RINGS do
			fx.ring(x, y - HEAD, 6, q[1], T, { life = 0.55, squash = 1, back = false, delay = q[2] })
		end
		fx.rise(x, y - 20, 14, T, { w = 40, speed = 50, life = 0.9 })
		for _, ax in p.summon.at do
			fx.beam(ax, y, 18, 80, T, { life = 0.6 })
			fx.ring(ax, y, 4, 22, T, { life = 0.5 })
			fx.shards(ax, y - 4, 8, T, { speed = 70, up = 60, kind = "mix" })
		end
	elseif p.id == "charge" then -- 내달리기: 박차는 자리의 고리 + 속도선 + 뒤로 튀는 흙
		fx.ring(x, y, 6, 34, T, { life = 0.35 })
		fx.streaks(x, y, 14, dir, T, { len = 30 })
		fx.shards(x - dir * 10, y - 2, 10, T, { speed = 90, up = 40, kind = "dot", dir = -dir, spread = 0.6 })
	end
end

-- 내달리기가 끝났다(벽에 닿았다): 그 자리에서 터진다
function BossFx.crash(fx, x: number, y: number, dir: number, shake: ((number, number) -> ())?)
	fx.ring(x + dir * 14, y, 6, 40, T, { life = 0.4 })
	fx.shards(x + dir * 18, y - 20, 18, T, { speed = 120, up = 80, kind = "mix", dir = -dir, spread = 1, life = 0.6 })
	fx.rise(x, y, 8, T, { w = 30, speed = 40, life = 0.7 })
	if shake then
		shake(3, 0.2)
	end
end

-- 물결 하나: 생긴 자리 x0에서 dir 쪽으로 range를 speed로 간다(판정은 서버 — 여기는 그림만). age = 이미 흐른 시간(화면이 조금 늦게 알았을 때)
--  lo · hi = 방의 양 끝(벽 안쪽) — 그 밖으로는 그리지 않는다(서버의 판정도 벽에서 멈춘다)
function BossFx.wave(fx, x0: number, y: number, dir: number, def, age: number?, lo: number?, hi: number?)
	fx.add(def.range / def.speed, function(ctx, k)
		local x = x0 + dir * def.range * k
		if x >= (lo or -math.huge) and x <= (hi or math.huge) then
			BossFx.crest(ctx, x, y, dir, k)
		end
	end, { delay = -(age or 0) })
end

-- 내달리는 동안(부르는 쪽이 0.05초쯤마다 부른다): 속도선과 발밑의 먼지
function BossFx.dashTrail(fx, x: number, y: number, dir: number)
	fx.streaks(x - dir * 8, y, 4, dir, T, { len = 26 })
	fx.pop(x - dir * 16, y - 3, T, { r = 3, life = 0.2 })
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
	local a = if p and not p.dash and clips[p.clip] and anim then anim[p.clip] else nil
	if state == "tell" and a then
		-- 치기 바로 앞의 장(hit-1 — 휘두르는 도중)은 예고의 마지막 한 장 시간에만. 그 앞까지는 제 빠르기로 틀고 다 치켜든 자세(hit-2)에서 멈춰 기다린다
		local lead = 1 / fps
		if t >= p.tell - lead then
			return p.clip, a.hit, false
		end
		return p.clip, min(a.hit - 2, floor(t * max(fps, (a.hit - 1) / (p.tell - lead)))) + 1, false
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

-- 예고를 그린다(상태가 tell인 동안 장마다): (x, y) = 보스의 발밑 가운데(바닥) · dir = 보는 쪽 · p = 패턴 · k = 0 → 1 · a · b = 움직이는 범위(내달리기의 끝) · top = 몸의 높이(머리 위에 느낌표를 띄운다)
function BossFx.tell(ctx, x: number, y: number, dir: number, p, k: number, a: number, b: number, top: number?)
	if p.zone then
		local x0, x1 = x + dir * p.zone.from, x + dir * p.zone.to
		BossFx.zone(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, dir, k)
	end
	if p.dash then
		local fin = if dir > 0 then b else a
		BossFx.lane(ctx, min(x, fin), max(x, fin), y, dir, k)
	end
	if p.summon then
		for _, ax in p.summon.at do
			BossFx.callMark(ctx, ax, y, k)
		end
	end
	BossFx.alert(ctx, x, y - (top or 80) - 6, k)
end

return BossFx
