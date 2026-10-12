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

local floor, max, min = math.floor, math.max, math.min
local R = Fx.R
local T = Fx.TONE.pink

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

-- ---- 새 패턴의 예고(2026-10-12 밤 — 공방 design/bosses.js의 STORYBOSS_NEXT) ----
-- 표시된 자리(불씨 뿌리기 · 봉화 불기둥): 바닥의 굵은 줄(가로 2r) + 그 위로 차오르는 옅은 기둥(k = 0 → 1 — 다 차면 솟는다) · 끝이 가까우면 깜박인다.
--  fromX · fromY = 불씨가 날아오는 곳(보스의 화로 — 있으면 포물선을 그리며 날아와 k = 1에 그 자리에 닿는다)
function BossFx.spot(ctx, x: number, y: number, r: number, up: number, k: number, fromX: number?, fromY: number?)
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

-- 체력 구간의 포효(「봉화를 올린다」 · 「늑대의 포효」): 몸의 뒤에서 솟는 그림 + 긴 흔들림. S = 그 보스의 싸움 자료
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
function BossFx.wave(fx, who: string, x0: number, y: number, dir: number, def, age: number?, lo: number?, hi: number?)
	if def.fx then
		fx.sprite(who, def.fx, x0, y, dir, { loop = def.range / def.speed, vx = dir * def.speed, lo = lo, hi = hi, fade = 0.15, delay = -(age or 0) })
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
function BossFx.tell(ctx, x: number, y: number, dir: number, p, k: number, a: number, b: number, top: number?, aim: number?)
	if p.leap then
		local d = if (aim or x) > x then 1 elseif (aim or x) < x then -1 else dir
		local land = math.clamp((aim or x) - d * p.leap.aim, a, b)
		local x0, x1 = land + d * p.zone.from, land + d * p.zone.to
		BossFx.zone(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, d, k)
	elseif p.zone then
		local x0, x1 = x + dir * p.zone.from, x + dir * p.zone.to
		BossFx.zone(ctx, min(x0, x1), max(x0, x1), y, p.zone.up, dir, k)
	end
	if p.wave and p.wave.dir == "front" and not p.zone then
		-- 검기: 날아갈 길
		local x0 = x + dir * p.wave.at
		local x1 = math.clamp(x0 + dir * p.wave.range, a - 20, b + 20)
		BossFx.lane(ctx, min(x0, x1), max(x0, x1), y, dir, k)
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
	if top then
		BossFx.alert(ctx, x, y - top - 6, k)
	end
end

return BossFx
