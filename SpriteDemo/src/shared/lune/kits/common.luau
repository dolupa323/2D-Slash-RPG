-- 직업 묶음들이 같이 쓰는 것 — 공방 시험 탭의 dino-workshop/js/lune/kits/common.js를 줄마다 옮긴 것.
--  대쉬 · 바로 걸리는 버프 · 공용 스킬(달의 용사 · 용사의 의지) · 작은 도우미.
--  버프를 걸 때는 발밑 고리와 몸 둘레로 솟는 빛줄만 낸다 — 머리 위에는 아무것도 띄우지 않는다(사용자 지시 2026-10-05). 걸린 버프는 화면 오른쪽 위 버프 표시에 나온다.
--  입력 수가 많은 주력기(사냥기 · 보스기)는 화면을 흔들지 않는다 — 꼭 필요하면 1 정도로 아주 약하게.
--  옮기며 바뀐 이름: 구간 · 날아가는 것의 end → finish(Luau의 예약어).
local Fx = require(script.Parent.Parent.fx)
local drawCoil, oval = Fx.drawCoil, Fx.oval
local DASHFX = Fx.DASHFX

local Common = {}

-- 대쉬: 속도(점/초)와 거리(점)는 직업마다 다르다(설계의 speed · dist와 같아야 한다 — 규칙 검사가 본다). 동작은 0~to 장을 거리 ÷ 속도 시간에 맞춰 돌린다
function Common.dash(id: string, clip: string, to: number, speed: number, dist: number)
	local time = dist / speed
	return {
		id = id,
		key = "Shift",
		air = true,
		shot = math.min(0.18, time * 0.7),
		speed = speed,
		dist = dist,
		segs = {
			{
				clip = clip,
				fps = (to + 1) / time,
				to = to,
				float = true,
				trail = true,
				start = function(g)
					g.move(speed, time)
					local S = DASHFX.streak
					g.fx.streaks(g.x, g.y - S.up, math.floor(S.base + speed / S.perSpeed + 0.5), g.dir, g.tone, { len = S.len + speed / S.lenPerSpeed })
				end,
			},
		},
	}
end

-- 지속 시간과 다시 쓰기 시간은 설계(jobs.js)에서 읽는다
function Common.buff(id: string, key: string, cast: ((any) -> ())?)
	return {
		id = id,
		key = key,
		instant = true,
		shot = 0.3,
		cast = function(g)
			g.buff(id)
			g.fx.aura(g.x, g.y, g.tone)
			if cast then
				cast(g)
			end
		end,
	}
end

local WHITE = { w = 0xffffff, l = 0xeef6f6, n = 0xcfdde6, d = 0x93a6b8 }
Common.commons = {
	Common.buff("c_hero", "6"),
	{
		id = "c_will",
		key = "7",
		instant = true,
		shot = 0.2,
		cast = function(g)
			g.fx.aura(g.x, g.y, WHITE, { r = 14, h = 22 })
		end,
	},
}
Common.commonIcons = { c_hero = "moon" }
-- 꽃잎처럼 흩어지는 불티(살라맨더) 파편 설정
Common.flame = { up = 70, kind = "petal", grav = 60, life = 0.7 }
-- 캐릭터에 붙여 그리는 막대(살라맨더의 열기 …)의 자리: 발밑에서 이만큼 아래(게임의 도트). 발밑 2~9점에는 이름표가 떠 있다 — 그 바로 아래에 놓는다
--  (사용자 2026-10-11: "캐릭터 아래에 게이지 보여주는 스킬들이있는데 이게 닉네임이랑 겹쳐서 가려버리는 문제가있습니다." 이름표는 움직이지 않는다 — 막대를 옮긴다)
Common.GAUGE_DOWN = 10
-- 칭호를 단 사람(g.titled — 화면이 그 사람의 이름표에 칭호가 있으면 단다): 이름표 아래의 칭호 줄 밑으로 내린다(2026-10-28 사용자 "살라같은 게이지 캐릭터들 칭호에 게이지 겹치는문제 해결하고").
--  GAUGE_TITLED = 칭호 줄의 아래 끝(게임의 도트) — 화면(client boot)이 이름표 · 칭호의 높이(화면 틀의 점)를 지금의 배율로 도트로 바꿔 장마다 넣는다(18은 처음 값)
Common.GAUGE_TITLED = 18
function Common.gaugeDown(g): number
	return if g.titled then math.max(Common.GAUGE_DOWN, Common.GAUGE_TITLED) else Common.GAUGE_DOWN
end

-- 점에서 선분까지의 거리(빛줄기 판정)
function Common.distSeg(px: number, py: number, x0: number, y0: number, x1: number, y1: number): number
	local dx, dy = x1 - x0, y1 - y0
	local l = dx * dx + dy * dy
	if l == 0 then
		l = 1
	end
	local t = math.max(0, math.min(1, ((px - x0) * dx + (py - y0) * dy) / l))
	return math.sqrt((px - x0 - dx * t) ^ 2 + (py - y0 - dy * t) ^ 2)
end

-- 바인드: 기운이 몸을 휘감아 돈다(뒤쪽 반은 몸 뒤, 앞쪽 반은 몸 앞) + 발밑에 도는 고리
function Common.coilBind(ctx, g, m, sc: number, front: boolean)
	local y, fade = m.y - m.h, math.min(1, m.bind * 2)
	ctx:alpha(fade)
	drawCoil(ctx, m.x, y, 9 * sc, 15 * sc, g.clock, g.tone, front)
	if not front then
		oval(ctx, m.x, m.y, 12 * sc, 3 * sc, g.tone.l, 1, 2, g.clock * 9)
		oval(ctx, m.x, m.y, 9 * sc, 2 * sc, g.tone.n, 1, 2, -g.clock * 7)
	end
	ctx:alpha(1)
end

-- 바인드가 걸리는 순간: 둘레에서 조여 드는 고리 둘 + 아래에서 위로 감아 오르는 빛
function Common.bindCast(g, m)
	local y, tone = m.y - m.h - (if m.boss then 14 else 7), g.tone
	g.fx.ring(m.x, y, 34, 8, tone, { squash = 0.9, back = false, life = 0.3 })
	g.fx.ring(m.x, y, 24, 6, tone, { squash = 0.9, back = false, life = 0.3, delay = 0.08 })
	g.fx.aura(m.x, m.y, tone, { r = if m.boss then 18 else 10, h = if m.boss then 40 else 22 })
	g.fx.shards(m.x, y, 6, tone, { kind = "dot", up = 60, speed = 50 })
end

return Common
