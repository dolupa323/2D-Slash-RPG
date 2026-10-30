-- 리틀 리븐 — 창. 핵심 장치: 표식(베기에 맞은 적에게 쌓인다). 2026-10-30 리마스터(사용자: "표식을 남겨서 순간이동과 빠른이동을하면서 공격하고 이런 캐릭터인데 날렵하고 베어내고, 스킬이 연계되고 화려한 방식으로"):
--  표식 → 순간이동(섬영 · 배후 교차 …)이 표식으로 날아가 베며 터뜨린다 → 터뜨리면 섬영이 바로 돌아와 다음 표식으로(같은 적 3초) → 순간이동 직후 1초는 연계(그림자 일격 — 서버 caster g.teleport · Passives.crit · Room:kitAfter).
--  순간이동의 그림(blink): 떠난 자리에 잔상 · 민트 결정 연기, 지나간 길에 가는 빛줄기, 나타난 자리에 세모 조각. 잔영 베기(사출기) = 적 등 뒤에 나타나 베는 내 잔영(procs.star)
--  공방 시험 탭의 dino-workshop/js/lune/kits/riven.js를 줄마다 옮긴 것. 시험판은 4차까지 다 배운 모습이라 스킬 레벨로 갈리는 곳에만 g.sk(스킬)을 덧붙였다(설계 jobs.js의 글대로):
--   표식 1(1차) → 3까지 겹친다(깊은 표식) · 스미는 독(3차 패시브)
--   그림자 표창: 40%로 하나(1차) → 둘(쌍표창) → 맞힌 뒤 한 번 튕긴다(되돌아오는 표창) → 70% · 표식이 가득한 적에게 터진다(피의 표창)
--   분신 하나(그림자 분신) → 둘(쌍영)
--  옮기지 않은 것: hud(월식 동안 하늘의 달을 검게 가린다 — 시험 맵의 달 자리에 맞춘 그림이라 맵마다 달 자리가 다른 게임에는 맞지 않는다. 어두워지는 것은 dim으로 그대로다).
--  옮기며 바뀐 이름: end → finish · until → till.
local Fx = require(script.Parent.Parent.fx)
local Common = require(script.Parent.common)
local COMBAT = require(script.Parent.Parent.data["combat.generated"]) -- 연쇄 순보의 레벨마다의 거리(moveCast — 2026-10-24)
local poly, disc, line, crescentPts = Fx.poly, Fx.disc, Fx.line, Fx.crescentPts
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
local RAD = math.pi / 180
-- 섬영이 찾는 거리(2026-10-31 사용자 "섬영 판정이 너무 안좋아 어느정도 자동추적이랑 좀 멀어도 바로 인식되면서 순간적으로 이동이 되어야해" — 170 · 130 → 260 · 220, 위아래 60 → 72):
--  STEP_RANGE = 표식이 있는 적(앞뒤) · STEP_NEAR = 표식이 없을 때 가까운 적(뒤는 60도트 더 먼 것으로) · STEP_DY = 위아래 · STEP_LOCK = 같은 적을 다시 터뜨려 다시 쓰기를 되돌릴 수 있기까지(초) — 제가 정한 것
local STEP_RANGE, STEP_NEAR, STEP_DY, STEP_LOCK = 260, 220, 72, 3
-- 표식이 터진다: 머리 위 초승달 표식이 부풀며 하얗게 → X자 칼자국 · 세모 조각.
--  표식 공명(3차 패시브 — 2026-10-30 리마스터 · 전에는 스미는 독): 둘레 reson도트의 다른 표식이 민트 번개로 이어져 함께 터진다(그 표식 수 x 4 x resonShare — 공방 combat.js PASSIVE.rv_venom).
--  chain = false면 잇지 않는다(화면의 표식을 모두 터뜨릴 때 · 이어 터진 것)
local RESON = COMBAT.passive and COMBAT.passive.rv_venom and COMBAT.passive.rv_venom.fx or { reson = 90, resonShare = 0.5 }
local function burst(g, m, chain: boolean?)
	local x, y, tone = m.x, m.y - m.h - 8, g.tone
	if chain ~= false and g.sk("rv_venom") > 0 then
		for _, n in g.mobs() do
			if n ~= m and (n.mark or 0) > 0 and abs(n.x - m.x) <= RESON.reson and abs(n.y - m.y) <= 60 then
				local k = n.mark
				n.mark = 0
				g.fx.bolt(x, y, n.x, n.y - n.h - 8, tone, { jag = 4, life = 0.2 })
				g.after(0.06, function()
					if n.dead >= 0 then
						return
					end
					g.hurt(n, max(1, R(4 * k * RESON.resonShare)), { proc = true })
					burst(g, n, false)
				end)
			end
		end
	end
	g.fx.add(0.22, function(ctx, k)
		ctx:alpha(1 - k)
		poly(ctx, crescentPts(x, y, 5 + 12 * k, 3 + 2 * (1 - k), 60, 300, 1), if k < 0.4 then tone.w else tone.l)
		ctx:alpha(1)
	end)
	g.fx.cut(x, y, 40, 40, tone, { th = 4 })
	g.fx.cut(x, y, 40, -40, tone, { th = 4, delay = 0.05 })
	g.fx.pop(x, y, tone, { r = 7 })
	g.fx.shards(x, y, 8, tone, { kind = "tri", speed = 90 })
end
-- 화면의 표식을 모두 터뜨린다(표식 수만큼 세다)
local function detonate(g, per: number?)
	for _, m in g.mobs() do
		if m.mark > 0 then
			local k = m.mark
			m.mark = 0
			g.hurt(m, (per or 4) * k, { lift = 120 })
			burst(g, m, false)
		end
	end
end
-- 민트 결정 연기(리븐의 special 동작에 그려진 연기와 같은 결): 둥근 덩이들이 둥글게 부풀며 흩어지고 가운데가 하얗게 빛났다가 사라진다
local function puff(g, x: number, y: number, s: number?)
	local sz, tone = s or 1, g.tone
	g.fx.add(0.34, function(ctx, k)
		ctx:alpha(min(1, 2 * (1 - k)))
		for i = 0, 7 do
			local a = math.pi * (i + 0.5) / 8
			local d = (5 + 13 * k) * sz
			local r = max(1, R((4 - 3 * k) * sz * (if i % 2 == 1 then 0.8 else 1)))
			disc(ctx, x + cos(a) * d * 1.3, y - 3 - sin(a) * d, r, if i % 3 == 0 then tone.l else tone.n)
		end
		disc(ctx, x, y - 4 - 6 * k * sz, max(1, R((5 - 4 * k) * sz)), tone.w)
		ctx:alpha(1)
	end)
	g.fx.shards(x, y - 8, R(4 * sz), tone, { kind = "tri", speed = 50, up = 40, life = 0.35 })
end
-- 순간이동: 떠난 자리에 잔상 · 결정 연기, 지나간 길에 가는 빛줄기 · 속도선, 나타난 자리에 세모 조각(벽이면 옮기지 않는다 → false)
local function blink(g, x: number): boolean
	local x0, y = g.x, g.y
	g.ghost()
	puff(g, x0, y)
	if not g.teleport(x) then
		return false
	end
	local len, mid = abs(g.x - x0), (x0 + g.x) / 2
	if len > 8 then
		g.fx.cut(mid, y - 9, len, 0, g.tone, { th = 2, life = 0.18 })
		g.fx.streaks(mid, y - 6, 4, if g.x > x0 then 1 else -1, g.tone, { w = len })
	end
	g.fx.shards(g.x, y - 8, 4, g.tone, { kind = "tri", speed = 40, up = 30, life = 0.3 })
	return true
end
-- 잔영 베기(사출기 — 2026-10-30 리마스터 · 전에는 그림자 표창): 적 t의 등 뒤(fromX의 반대쪽)에 내 잔영이 나타나 사선으로 벤다. 피해 · 표식은 서버(Room:kitAfter)가 정하고
--  화면은 그림만 — land = 벤 순간(피해 숫자). 잔영 = 내 베는 동작(slash 3~6장)을 민트 실루엣으로 0.035초마다. 공방 riven.js의 shade와 같은 그림
local function shade(g, t, fromX: number, land)
	if not t or t.dead >= 0 then
		if land then
			land()
		end
		return
	end
	local side = if t.x >= fromX then 1 else -1
	local x, tone = t.x + side * (if t.boss then 26 else 14), g.tone
	puff(g, x, t.y, 0.6)
	for i = 0, 3 do
		g.after(i * 0.035, function()
			g.shade("slash", 3 + i, x, t.y, -side, tone.n)
		end)
	end
	g.after(0.08, function()
		g.fx.cut(t.x, t.y - t.h - 10, 34, side * 42, tone, { th = 3, life = 0.18 })
		g.fx.cut(t.x, t.y - t.h - 10, 22, -side * 30, tone, { th = 2, life = 0.14, delay = 0.03 })
		g.fx.pop(t.x, t.y - t.h - 10, tone)
		if (t.mark or 0) >= 3 and g.sk("rv_star4") > 0 then
			g.fx.shards(t.x, t.y - t.h - 10, 6, tone, { kind = "tri", speed = 80 }) -- 잔영 폭발(표식이 가득한 적)
		end
		if land then
			land()
		end
	end)
end
-- 초승 베기(1차 사냥기 — 2026-10-30 리마스터 · 전에는 창바람 세 갈래): 앞을 크게 휘감는 초승달 칼날(밖 · 안 두 겹) → 벤 자리에 남은 가는 초승달 칼자국이 0.12초 뒤 하얗게 빛나고 세모 조각으로 부서진다.
--  닿는 곳은 그대로(앞 88 · 위 44도트 — 서버는 공방 design/combat.js SKILLS.rv_fan의 hits)
local function crescent(g)
	local tone, dir, cx, cy = g.tone, g.dir, g.fwd(30), g.y - 12
	g.fx.slash(cx, cy, dir, 44, -25, 55, tone, { thick = 12, life = 0.22 })
	g.fx.slash(cx - dir * 6, cy, dir, 32, -15, 45, tone, { thick = 6, life = 0.18 })
	g.fx.streaks(g.fwd(36), g.y - 4, 4, -dir, tone, { w = 60, h = 24 })
	g.after(0.12, function()
		g.fx.add(0.16, function(ctx, k)
			poly(ctx, crescentPts(cx, cy, 42, 2.5 * (1 - k) + 1, -20, 50, dir), if k < 0.4 then tone.w else tone.l)
		end)
		for _, a in { -12, 15, 42 } do
			g.fx.shards(cx + dir * cos(a * RAD) * 42, cy - sin(a * RAD) * 42, 3, tone, { kind = "tri", speed = 70, up = 30, life = 0.35, dir = dir })
		end
	end)
end
-- 배후 교차(2차 보스기 — 2026-10-30 리마스터 · 전에는 제자리 X자): 앞 70도트 안의 가장 가까운 적의 등 뒤로 순간이동해 돌아서서 X자로 긋는다. 없으면 제자리
local function behind(g)
	local m = g.nearest(70, { front = true })
	local side = g.dir
	if m and blink(g, m.x + side * (if m.boss then 30 else 18)) then
		g.face(-side)
	end
	g.s.cx = if m then m.x else g.fwd(26)
end
-- 섬영(2차 — 2026-10-30 리마스터 · 전에는 연막 순보: 화면의 표식을 모두 터뜨렸다): 표식이 있는 가장 가까운 적(STEP_RANGE 안 · 같은 층 · 그 적을 STEP_LOCK초 안에 터뜨린 적이 없는 것)에게
--  순간이동해 등 뒤에서 X자로 벤다. 그 적의 표식을 터뜨리면(표식 수만큼 세다) 섬영의 다시 쓰기가 바로 돌아온다(서버 g.resetCd → 화면의 다시 쓰기도 지운다) → 다음 표식으로.
--  표식이 없으면 앞 130 안의 가까운 적에게 · 그것도 없으면 앞으로 80
local function flash(g)
	g.s.lock = g.s.lock or {}
	local lock, t, bd = g.s.lock, nil, STEP_RANGE
	for _, m in g.mobs() do
		if (m.mark or 0) > 0 and abs(m.y - g.y) <= STEP_DY and (lock[m] or -1) <= g.clock then
			local d = abs(m.x - g.x)
			if d <= bd then
				bd, t = d, m
			end
		end
	end
	g.s.marked = t
	if not t then -- 표식이 없으면 가까운 적(앞을 먼저 — 뒤는 60도트 더 먼 것으로 친다)
		local bs = STEP_NEAR
		for _, m in g.mobs() do
			if abs(m.y - g.y) <= STEP_DY then
				local d = abs(m.x - g.x)
				local sc = d + (if (m.x - g.x) * g.dir < -8 then 60 else 0)
				if d <= STEP_NEAR and sc <= bs then
					bs, t = sc, m
				end
			end
		end
	end
	g.s.st = t
	if t then
		local side = if t.x > g.x then 1 elseif t.x < g.x then -1 else g.dir
		if blink(g, t.x + side * (if t.boss then 30 else 18)) then
			g.face(-side)
		else
			g.face(side)
		end
	else
		blink(g, g.fwd(100))
	end
end
local function flashHit(g)
	local t, tone = g.s.st, g.tone
	local cx = if t then t.x else g.fwd(20)
	g.fx.cut(cx, g.y - 9, 66, 30, tone, { th = 4 })
	g.fx.cut(cx, g.y - 9, 66, -30, tone, { th = 4, delay = 0.04 })
	if t and t.dead < 0 then
		g.hitAt(t.x, t.y, 26, 28, 4, { stop = 0.05 }) -- 맞는 곳 = 그 적의 자리 둘레(2026-10-31 — 내 자리 · 보는 쪽과 상관없이: 옮겨 간 뒤 0.03초 사이에 움직여도 맞는다)
	else
		g.hit(-10, 40, 28, 4, 4, { stop = 0.05 })
	end
	if t and t == g.s.marked and t.dead < 0 and (t.mark or 0) > 0 then
		local k = t.mark
		t.mark = 0
		g.hurt(t, 4 * k, { lift = 80 })
		burst(g, t)
		g.s.lock[t] = g.clock + STEP_LOCK
		for m, till in g.s.lock do -- 지난 것은 치운다(쓰러진 적이 남지 않게)
			if till <= g.clock then
				g.s.lock[m] = nil
			end
		end
		g.resetCd("rv_step")
	end
	if g.has("rv_eclipse") then
		g.resetCd("rv_step") -- 월식(4차 극딜 버프): 섬영을 다시 쓰기 없이 이어 쓴다
	end
end
-- 섬광 연참(3차 사냥기 — 2026-10-30 리마스터 · 전에는 그림자 창 넷): 앞 RUSH_REACH도트 안 · 같은 층의 적 RUSH_N마리까지(표식이 있는 적부터 · 그다음 가까운 차례)에게 RUSH_STEP초마다 순간이동해
--  등 뒤(지나온 쪽의 반대)에 나타나 몸을 사선으로 가른다 · 표식. 적이 없으면 앞으로 90 순간이동하며 그 길을 벤다. 끝난 자리에 선다 — 숫자는 제가 정한 것
local RUSH_N, RUSH_REACH, RUSH_STEP = 5, 150, 0.06
local function flashRush(g)
	local dir, x0 = g.dir, g.x
	local list = {}
	for _, m in g.mobs() do
		if abs(m.y - g.y) <= 60 and (m.x - x0) * dir > -8 and abs(m.x - x0) <= RUSH_REACH then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		local am, bm = (a.mark or 0) > 0, (b.mark or 0) > 0
		if am ~= bm then
			return am
		end
		return abs(a.x - x0) < abs(b.x - x0)
	end)
	if #list == 0 then
		local from = g.x
		blink(g, g.fwd(90))
		local mid, len = (from + g.x) / 2, abs(g.x - from)
		g.fx.cut(mid, g.y - 10, len + 20, 0, g.tone, { th = 4, life = 0.22 })
		g.hitAt(mid, g.y, len / 2 + 10, 26, 4, { mark = true })
		return
	end
	for i = 1, min(RUSH_N, #list) do
		local m = list[i]
		g.after((i - 1) * RUSH_STEP, function()
			if m.dead >= 0 then
				return
			end
			local side = if m.x >= g.x then 1 else -1
			if blink(g, m.x + side * (if m.boss then 26 else 14)) then
				g.face(-side)
			end
			local y = m.y - m.h - 10
			g.fx.cut(m.x, y, 42, side * (if i % 2 == 0 then -50 else 50), g.tone, { th = 4, life = 0.22 })
			g.fx.pop(m.x, y, g.tone, { r = 5 })
			g.hurt(m, 4, { mark = true, stop = 0.03 })
		end)
	end
end
-- 월영 비수(3차 — 2026-10-30 리마스터 · 전에는 연막탄): 처음 누르면 발밑에 표식 비수를 꽂는다(DAGGER_LIFE초 — 그동안은 다시 쓰기가 돌지 않는다: 꽂은 순간 서버가 다시 쓰기를 지운다).
--  비수가 있을 때 누르면 비수 자리로 순간이동하며 지나간 길의 적을 모두 베고 표식 — 그때부터 다시 쓰기. 비수가 사라지거나 DAGGER_FAR도트보다 멀면 새로 꽂는다
local DAGGER_LIFE, DAGGER_FAR = 10, 400
local function drawDagger(tone)
	return function(ctx, p) -- 땅에 꽂힌 비수: 땅에 번진 빛 두 줄 · 민트 날(끝이 땅에 들어간다) · 코등이 · 어두운 손잡이 · 머리 · 위에 뜬 초승달 표식
		local k = min(1, p.t * 6)
		local x, gy = R(p.x), R(p.y)
		local y = R(p.y - (1 - k) * 12)
		ctx:alpha(min(1, (p.life - p.t) * 2))
		ctx:style(tone.n)
		ctx:rect(x - 6, gy, 13, 1)
		ctx:style(tone.l)
		ctx:rect(x - 3, gy, 7, 1)
		poly(ctx, { { x - 2, y - 8 }, { x + 3, y - 8 }, { x + 1, y }, { x, y } }, tone.l)
		line(ctx, x, y - 8, x, y - 1, tone.w)
		ctx:style(tone.n)
		ctx:rect(x - 4, y - 10, 9, 2)
		ctx:style(0x2a3340)
		ctx:rect(x - 1, y - 15, 3, 5)
		ctx:style(tone.l)
		ctx:rect(x - 1, y - 17, 3, 2)
		local my = R(y - 25 + sin(p.t * 4) * 1.5)
		poly(ctx, crescentPts(x + 1, my, 4, 2.6, 70, 290, 1), tone.n)
		poly(ctx, crescentPts(x + 1, my, 4, 1, 110, 250, 1), tone.l)
		ctx:alpha(1)
	end
end
local function dagger(g)
	local d, tone = g.s.dagger, g.tone
	if d and d.t < d.life and abs(d.x - g.x) <= DAGGER_FAR then -- 돌아오기
		local from = g.x
		d.t = d.life
		g.s.dagger = nil
		if blink(g, d.x) then
			local mid, len = (from + g.x) / 2, abs(g.x - from)
			g.fx.cut(mid, g.y - 10, len + 20, 0, tone, { th = 5, life = 0.26 })
			g.fx.streaks(mid, g.y - 4, 8, if g.x > from then 1 elseif g.x < from then -1 else g.dir, tone, { w = len })
			g.hitAt(mid, g.y, len / 2 + 12, 30, 6, { mark = true, stop = 0.05 })
		end
		g.fx.shards(d.x, g.y - 6, 10, tone, { kind = "tri", speed = 90 })
		g.fx.pop(d.x, g.y - 8, tone, { r = 8 })
		g.shake(2, 0.12)
		return
	end
	if d then
		d.t = d.life -- (멀리 두고 온 것은 사라진다)
	end
	g.s.dagger = g.shot({ x = g.x, y = g.y, life = DAGGER_LIFE, draw = drawDagger(tone) })
	g.fx.shards(g.x, g.y - 4, 5, tone, { kind = "tri", speed = 50, up = 30, life = 0.3 })
	g.resetCd("rv_smoke") -- 꽂은 동안은 다시 쓰기가 돌지 않는다(돌아올 때 돈다)
end
-- 무영 섬(4차 사냥기 — 2026-10-30 리마스터 · 전에는 보이지 않는 창질 여섯): 앞 164도트 안의 적 사이를(없으면 허공의 자리를) PH_STEP초마다 여섯 번 오가며 긋고 처음 자리로 돌아온다.
--  그은 자리마다 칼자국이 허공에 남았다가 한꺼번에 하얗게 빛나며 세모 조각으로 부서진다 — 그 순간 앞이 맞는다(판정은 전과 같다: 앞 84 둘레 80 · 위 46 · 세 번). 자주 쓰는 사냥기라 흔들림은 없다
--  2026-10-31 사용자 "무영섬은 너무 범위가 작고": 찾는 곳 앞 164 → 240도트 · 위아래 60 → 72 · 맞는 곳 앞 4~164 · 위 46 → 앞 0~248 · 위 60(PH_REACH)
local PH_N, PH_STEP, PH_REACH = 6, 0.04, 248
local function phantom(g)
	local x0, y, dir, tone, cx = g.x, g.y, g.dir, g.tone, g.fwd(PH_REACH / 2)
	local foes, cuts = {}, {}
	for _, m in g.mobs() do
		if abs(m.y - y) <= 72 and (m.x - x0) * dir > -8 and abs(m.x - x0) <= PH_REACH - 8 then
			table.insert(foes, m)
		end
	end
	for i = 0, PH_N - 1 do
		local m = if #foes > 0 then foes[i % #foes + 1] else nil
		local side = if i % 2 == 1 then -1 else 1
		local tx = if m then m.x + side * 12 else cx + (g.rnd() - 0.5) * 180
		local ty = (if m then m.y - m.h - 10 else y - 14) + (g.rnd() - 0.5) * 10
		local ang = side * (30 + g.rnd() * 40)
		table.insert(cuts, { tx, ty, ang })
		g.after(i * PH_STEP, function()
			g.ghost()
			g.teleport(tx)
			g.face(side * dir)
			g.fx.cut(tx, ty, 54, ang, tone, { th = 3, life = 0.42 })
		end)
	end
	g.after(PH_N * PH_STEP, function()
		g.ghost()
		g.teleport(x0)
		g.face(dir)
	end)
	g.after(PH_N * PH_STEP + 0.12, function()
		for _, c in cuts do
			g.fx.cut(c[1], c[2], 66, c[3], tone, { th = 5, life = 0.2 })
			g.fx.shards(c[1], c[2], 4, tone, { kind = "tri", speed = 80, life = 0.35 })
		end
	end)
	for _, t in { 0, 0.05, 0.1 } do
		g.after(PH_N * PH_STEP + 0.12 + t, function()
			g.hitAt(cx, y, PH_REACH / 2, 60, 4, { mark = t == 0 })
		end)
	end
end
-- 암살 연계(4차 보스기 — 2026-10-30 리마스터): 누르면 앞 80 안의 가장 가까운 적의 등 뒤로 순간이동해 돌아서서 여섯 번 찌른다 → 한 번 더 누르면 머리 위에서 떨어지는 잔영과 함께 세로로 내리꽂는다
local function killStart(g)
	local m = g.nearest(80, { front = true })
	local side = g.dir
	if m and blink(g, m.x + side * (if m.boss then 30 else 16)) then
		g.face(-side)
	end
end
local function killDive(g)
	local tx, ty = g.fwd(24), g.y
	for i = 0, 3 do
		g.after(i * 0.03, function()
			g.shade("slash", 5 + i, tx - g.dir * 6, ty - 40 + i * 12, g.dir, g.tone.n)
		end)
	end
end
-- 표식의 그림(머리 위 — 화면 cast.luau가 top을 준다): 표식 하나마다 민트 초승달 하나 — 위아래로 살짝 흔들리고, 가득하면(셋) 하얗게 빛난다. 전에는 작은 + 셋
local function drawMarks(ctx, g, m, _sc, front, top)
	if not front or (m.mark or 0) <= 0 or not top then
		return
	end
	local n, tone = m.mark, g.tone
	local full = n >= 3
	for i = 0, n - 1 do
		local x, y = m.x - (n - 1) * 4 + i * 8, R(top - 20 + sin(g.clock * 5 + i * 1.3) * 1.5) -- (체력 띠 위)
		poly(ctx, crescentPts(x + 1, y, 4, 2.6, 70, 290, 1), if full then tone.l else tone.n)
		poly(ctx, crescentPts(x + 1, y, 4, 1, 110, 250, 1), if full then tone.w else tone.l)
	end
end

local chainSteps, cleaveRush -- (아래 도우미 — 스킬 표보다 먼저 이름만)
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
	{ id = "rv_fan", key = "Q", shot = 0.4, segs = { { clip = "slash", fps = 20, ev = { [5] = function(g) -- 초승 베기(위 crescent)
		crescent(g)
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
	-- 질풍 일섬(2026-10-31 사용자 "질풍일섬이 너무 뻑뻑하고, 두번이 아니라 일회성 베기로 가고 판정좀더 좋아야할거같아"): 다시 쓰기 0.5초(이어 쓰기) → 없음 · 누르는 순간 내달려(0.14초 · 84도트 — 전에는 3장째부터 0.2초 · 68)
	--  내달리기가 끝나는 순간 한 번에 벤다(전에는 그 뒤 0.2초 늦게) · 맞는 곳: 지나온 길의 앞뒤 20도트 더 · 위 34(전에는 앞뒤 15 · 위 26) · 동작 26장/초(전에는 20)
	{ id = "rv_gale", key = "W", air = true, shot = 0.42, segs = { { clip = "slash", fps = 26, float = true, trail = true, start = function(g)
		g.s.from = g.x
		g.move(600, 0.14)
		g.after(0.14, function()
			local mid, len = (g.s.from + g.x) / 2, abs(g.x - g.s.from) + 40
			g.fx.cut(mid, g.y - 10, len, 0, g.tone, { th = 5, life = 0.24 })
			g.fx.cut(mid, g.y - 12, len * 0.7, g.dir * 6, g.tone, { th = 2, life = 0.18, delay = 0.03 })
			g.fx.streaks(mid, g.y - 2, 8, -g.dir, g.tone, { w = len })
			g.fx.shards(g.x, g.y - 10, 4, g.tone, { kind = "tri", speed = 70, dir = g.dir })
			g.hitAt(mid, g.y, len / 2, 34, 4, { mark = true, stop = 0.03 })
		end)
	end } } },
	{ id = "rv_cross", key = "S", shot = 0.52, segs = { { clip = "dslash", fps = 22, start = behind, ev = { -- 배후 교차(위 behind): 등 뒤로 순간이동해 돌아서서 X자
		[4] = function(g)
			g.fx.cut(g.s.cx, g.y - 9, 38, 45, g.tone, { th = 4 })
			g.hit(-10, 54, 30, 4, 5, { mark = true })
		end,
		[10] = function(g)
			g.fx.cut(g.s.cx, g.y - 9, 38, -45, g.tone, { th = 4 })
			g.fx.pop(g.s.cx, g.y - 9, g.tone, { r = 7 })
			g.hit(-10, 54, 30, 4, 6, { mark = true, stop = 0.04 })
		end,
	} } } },
	-- 섬영(위 flash · flashHit — 2026-10-31 사용자 "섬영 거의 그냥 쉽게 쓸수있어야해 지금 너무 선딜, 후딜이 길어"): 동작이 없는 기술(instant) — 누르는 순간 옮겨 가고 0.03초 뒤 벤다.
	--  anytime = 다른 스킬을 쓰는 중에도 쓴다(서버 caster:begin · world의 1차 기술 중 막기가 이것은 받는다 — 하던 동작은 새 자리에서 이어 간다)
	{ id = "rv_step", key = "Z", instant = true, anytime = true, shot = 0.2, cast = function(g)
		flash(g)
		g.after(0.03, function()
			flashHit(g)
		end)
	end },
	buff("rv_quick", "1"),
	{ id = "rv_lance", key = "E", shot = 0.5, segs = { { clip = "slash", fps = 20, ev = { [3] = flashRush } } } }, -- 섬광 연참(위 flashRush)
	{ id = "rv_chain", key = "V", air = true, shot = 0.35, segs = { -- 연쇄 순보(이동기): 연기 속으로 사라졌다가 앞으로 순간이동을 세 번 잇는다
		{ clip = "smokeout", from = 0, to = 5, fps = 30, float = true },
		{ clip = "smokein", fps = 26, float = true, start = chainSteps },
	} },
	{ id = "rv_flurry", key = "D", shot = 0.8, holdFor = 2, segs = {
		{ clip = "dslash", from = 0, to = 10, loopFrom = 4, fps = 40, hold = true, max = 3, min = 0.3, every = { 0.125, function(g) -- 잔영 난무(2026-10-30 리마스터): 앞에 겹겹이 쌓이는 짧은 벤 자국 + 적 둘레(등 뒤 · 머리 위 · 비스듬히 위)에 번갈아 나타나 베는 잔영
			g.s.n += 1
			g.fx.cut(g.fwd(18 + g.rnd() * 16), g.y - 5 - g.rnd() * 13, 14 + g.rnd() * 12, (g.rnd() - 0.5) * 130, g.tone, { life = 0.12, th = 2 })
			g.hit(0, 46, 26, 4, 2, { mark = g.s.n % 4 == 0 })
			local t = g.nearest(60, { front = true })
			if t then
				local spot = ({ { 14, 0 }, { -2, -24 }, { 10, -14 } })[g.s.n % 3 + 1]
				local x, y = t.x + g.dir * spot[1], t.y + spot[2]
				local face = if spot[1] > 0 then -g.dir else g.dir
				for i = 0, 2 do
					g.after(i * 0.03, function()
						g.shade("dslash", 4 + i * 2, x, y, face, g.tone.n)
					end)
				end
				g.fx.cut(t.x, t.y - t.h - 8 - g.rnd() * 10, 22 + g.rnd() * 10, (g.rnd() - 0.5) * 140, g.tone, { life = 0.12, th = 2 })
			end
		end } },
		{ clip = "dslash", from = 11, fps = 24 }, -- 떼면 동작을 끝까지 마무리한다
	} },
	buff("rv_clone", "2", function(g)
		g.ghost()
	end),
	{ id = "rv_smoke", key = "C", shot = 0.4, segs = { { clip = "cast", fps = 18, ev = { [2] = dagger } } } }, -- 월영 비수(위 dagger): 꽂기 → 한 번 더 누르면 돌아오기
	{ id = "rv_slip", key = "5", instant = true, shot = 0.3, cast = function(g)
		g.buff("rv_slip")
		g.fx.streaks(g.x, g.y - 4, 8, g.dir, g.tone)
		g.fx.ring(g.x, g.y, 18, 4, g.tone, { life = 0.25 })
	end },
	{ id = "rv_phantom", key = "R", shot = 0.3, segs = { { clip = "slash", fps = 26, walk = 1, ev = { [5] = phantom } } } }, -- 무영 섬(위 phantom)
}

-- 암살 연계: 적의 등 뒤로 순간이동해 여섯 번 찌르고(killStart), 한 번 더 누르면 머리 위에서 내리꽂는 마무리(killDive)
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
		{ clip = "dslash", fps = 30, start = killStart, ev = ev },
		{ clip = "slash", fps = 20, needPress = true, start = killDive, ev = { [5] = function(g) -- 마무리: 머리 위에서 떨어지는 잔영 → 세로 큰 벤 자국 — 표식이 많을수록 세다
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
			blink(g, t.x - g.dir * 12)
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
		g.s = { n = 0, dagger = nil, lock = {}, link = -1, lx = nil, lf = 0 }
	end,
	haste = function(g)
		return if g.has("rv_quick") then 1.25 else 1
	end,
	mult = function(g)
		return 1 + (if g.has("rv_eclipse") then 0.3 else 0) + (if g.has("c_hero") then 0.05 else 0)
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
	drawMarks = drawMarks,
	tick = function(g, dt)
		-- 연계(그림자 일격): 순간이동(한 번에 30도트 넘게 옮겨졌다)한 뒤 1초 — 몸에서 민트 빛 알갱이가 흩날린다(그림만 — 크리티컬 데미지 · 표식 +는 서버)
		if g.s.lx and abs(g.x - g.s.lx) > 30 and g.sk("rv_back") > 0 then
			g.s.link = g.clock + 1
		end
		g.s.lx = g.x
		if g.clock < (g.s.link or -1) then
			g.s.lf = (g.s.lf or 0) - dt
			if g.s.lf <= 0 then
				g.s.lf = 0.05
				g.fx.shards(g.x - g.dir * 4, g.y - 6 - g.rnd() * 14, 1, g.tone, { kind = "dot", up = 10, speed = 8, life = 0.3, grav = -20 })
			end
		end
		g.hero.sil = if g.has("rv_slip") then 0x14665f else nil
		g.hero.alpha = if g.has("rv_slip") then 0.75 else 1
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
		-- 잔영 하나(서버가 정한 것 — 그림만): low = 맞은 적(겹 잔영) · 아니면 가까운 다른 적
		star = function(g, t, low)
			shade(g, t, if low then g.x - g.dir * 40 else g.x)
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
		-- 잔영 베기(2026-10-30 리마스터 — 전에는 표창): 적 등 뒤(o.sx — 서버가 정한 떠나는 자리의 반대쪽)에 잔영이 나타나 벤다. o.hop = 앞의 잔영이 벤 뒤 다음 적으로(잔영 연격 — 조금 늦게)
		star = function(g, m, o)
			local function go()
				shade(g, m, o.sx or g.x, o.land)
			end
			if o.hop then
				g.after(0.16, go)
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
