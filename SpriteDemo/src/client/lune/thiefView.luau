-- 셋째 보스전 「불씨 도둑 두목」의 기믹을 화면에 그린다(2026-10-28 — 서버 sim/thiefgim.luau가 보내는 "Gim" 신호마다).
--  ① 폭탄: 두목의 손에서 포물선으로 날아가 떨어진다(throw) → 바닥의 폭탄은 졸개(thiefbomb — 도화선의 불티가 깜빡이는 그림)로 보인다 → 터짐(boom) / 맞혀서 되날아감(bat) → 두목에게 터짐(backhit)
--  ② 단지: 깨지면 유리 조각 · 분홍 불씨가 튀고(jar) 바닥에 「되찾은 불씨」가 남는다(줍거나 사라질 때까지 일렁인다 — ember · emberGone) · 다시 채우기(refill · filled)
--  ③ 연막(smoke): 방이 어두워지고 연기가 흐른다 · 진짜 두목의 발밑에만 분홍 불티가 떨어진다 · 가짜를 치면 그을음(pop — 친 사람은 화면이 잠깐 어둡다) · 걷힘(clear) · 못 찾으면 떨어지는 불단지(drop)
--  + 갈고리(hook · hookEnd — 곧게 날아가는 갈고리 칼과 두목의 손까지 이어진 줄) · 버프 털림(steal) · 휘청(stagger · recover — 머리 위를 도는 별) · 큰 불단지(bigjar — 방 전체의 섬광)
--  그림은 지금 코드로 그린다(겹친 빛 · 연기 · 조각). 보스의 이펙트 시트(Codex)가 나오면 터짐 · 연기 · 그을음을 그 그림으로 바꾼다. 말(words)은 설계의 gimmick.words(영문은 lang)
local Fx = require(game:GetService("ReplicatedStorage").shared.lune.fx)
local disc, poly, line, starPts = Fx.disc, Fx.poly, Fx.line, Fx.starPts
local sin, cos, min, max, floor, random = math.sin, math.cos, math.min, math.max, math.floor, math.random

local ThiefView = {}
local PINK = { d = 0xb11fa5, n = 0xff3e9f, l = 0xff7ea2, w = 0xffffff }
local GLASS = { d = 0x7c8ea2, n = 0xa9bccb, l = 0xcfdde6, w = 0xffffff }
local SMOKE = { 0x393e46, 0x515864, 0x7c8ea2 }
local SOOT = { 0x232931, 0x393e46 }

-- 그 방의 보스(화면의 몬스터): 지금 그려지는 자리
local function bossOf(bv)
	local b = bv.list[1]
	return b and b.m
end
local function posOf(m): (number, number)
	return m.x or 0, (m.info and m.info.y) or 0
end
-- 보스의 키(맞는 몸의 높이 — 2026-10-28 0.8배로 줄인 뒤 64점). 머리 위 · 등의 단지 · 손의 높이는 이것의 몫으로 잡는다(본래 80점일 때의 자리 그대로)
local function hOf(m): number
	local S = m and m.def and m.def.story
	return (S and S.body and S.body[2]) or 64
end
-- 보스가 있으면 그 자리, 없으면 (x, y)
local function bpos(m, x: number, y: number): (number, number)
	if m then
		return posOf(m)
	end
	return x, y
end

-- 폭탄 하나(둥근 검은 몸 · 왼쪽 위의 반짝임 · 깜빡이는 분홍 불티)
local function bomb(ctx, x: number, y: number, t: number)
	ctx:alpha(1)
	disc(ctx, x, y, 5, 0x232931)
	disc(ctx, x, y, 4, 0x393e46)
	disc(ctx, x - 1.5, y - 1.5, 1.2, 0x7c8ea2)
	line(ctx, x + 2, y - 4, x + 4, y - 7, 0x7c8ea2)
	disc(ctx, x + 4, y - 8, if floor(t * 16) % 2 == 0 then 1.6 else 0.9, if floor(t * 16) % 2 == 0 then PINK.l else PINK.n)
end

-- 연기 한 덩이(커지며 옅어진다)
local function puff(fx, x: number, y: number, r: number, life: number, cols, o)
	local dx, dy = (o and o.dx) or 0, (o and o.dy) or -10
	fx.add(life, function(ctx, k)
		ctx:alpha(0.75 * (1 - k))
		disc(ctx, x + dx * k, y + dy * k, r * (0.6 + 0.6 * k), cols[1])
		ctx:alpha(0.55 * (1 - k))
		disc(ctx, x + dx * k - r * 0.25, y + dy * k - r * 0.3, r * (0.35 + 0.45 * k), cols[2] or cols[1])
		ctx:alpha(1)
	end, { delay = (o and o.delay) or 0 })
end

-- 그 보스의 그림 묶음 이름(이펙트 그림 fx_* 은 보스의 동작 묶음에 있다 — bossView와 같다)
local function whoOf(bv): string?
	local m = bossOf(bv)
	return m and m.sprite and m.sprite.who
end

-- 터짐: 그 보스의 폭탄 터짐 그림(fx_boom — 분홍 불 · 검은 화약 연기 · 쇠 조각) · 큰 것은 양옆에 둘 더 · 바닥의 그을음.
--  (그림이 아직 없으면: 흰 · 분홍 별빛 → 겹친 연기 — 코드로 그린 처음 판)
local function boom(bv, x: number, y: number, big: number)
	local fx = bv.fx
	if bv.sound then
		bv:sound("boss_boom") -- 보스의 소리(2026-10-28 — bossView의 hooks.sfx · 공방 music.js boss_boom)
	end
	local who = whoOf(bv)
	if who and fx.sprite(who, "fx_boom", x, y, 1, {}) then
		if big >= 1.4 then
			fx.sprite(who, "fx_boom", x - 22 * big, y + 4, -1, { delay = 0.07 })
			fx.sprite(who, "fx_boom", x + 22 * big, y + 4, 1, { delay = 0.12 })
		end
		fx.shards(x, y - 6, floor(4 * big), PINK, { kind = "dot", up = 90, speed = 90 })
		bv.shake(if big > 1 then 3 else 2, if big > 1 then 0.22 else 0.14)
		return
	end
	fx.add(0.18, function(ctx, k)
		ctx:alpha(1 - k * 0.5)
		poly(ctx, starPts(x, y - 8 * big, (16 + 10 * k) * big, k * 0.6), if k < 0.4 then PINK.w else PINK.l)
		disc(ctx, x, y - 8 * big, (9 - 5 * k) * big, PINK.n)
		ctx:alpha(1)
	end)
	for i = 0, 3 do
		puff(fx, x + (i - 1.5) * 8 * big, y - 6 * big, (7 + random() * 3) * big, 0.6 + i * 0.05, SMOKE, { dy = -14 * big, dx = (i - 1.5) * 4, delay = 0.05 })
	end
	fx.shards(x, y - 6, floor(8 * big), PINK, { kind = "tri", up = 110, speed = 110 })
	fx.add(1.0, function(ctx, k)
		ctx:alpha(0.6 * (1 - k))
		for dx = -14 * big, 14 * big, 2 do
			ctx:style(0x232931)
			ctx:rect(floor(x + dx), floor(y), 2, 1)
		end
		ctx:alpha(1)
	end, { back = true })
	bv.shake(if big > 1 then 3 else 2, if big > 1 then 0.22 else 0.14)
end

function ThiefView.new(bv, ctx)
	local tv = { bv = bv, ctx = ctx, embers = {}, hooks = {}, smoke = nil, jars = nil, hide = false }
	-- 머리 위의 남은 단지(2026-10-28 — 보스 그림에는 늘 셋이 매달려 있어 몇 개 깨졌는지 보이지 않는다): 칸 셋 · 남은 것은 분홍 · 깨진 것은 빈 칸.
	--  서버가 1초마다(jars) · 깨질 때(jar) · 채울 때(filled) 알린다. 연막 동안에는 숨긴다(진짜가 드러나지 않게). 공방 luneTab.js의 drawGim과 같은 자리 · 꼴
	bv.fx.add(1e9, function(c)
		local m = bossOf(bv)
		if not m or tv.hide or not tv.jars or m.state == "dead" or m.state == "gone" then
			return
		end
		local G = m.def and m.def.story and m.def.story.gimmick
		local n = if G then G.jars.n else 3
		local x, y = posOf(m)
		local top = y - ((m.def.story.body and m.def.story.body[2]) or 80)
		for i = 0, n - 1 do
			local bx, by = floor(x - (n - 1) * 5 + i * 10 + 0.5), floor(top - 24 + 0.5)
			c:alpha(1)
			c:style(0x232931)
			c:rect(bx - 3, by - 3, 7, 7)
			c:style(if i < tv.jars then PINK.n else 0x393e46)
			c:rect(bx - 2, by - 2, 5, 5)
			if i < tv.jars then
				c:style(PINK.w)
				c:rect(bx - 1, by - 1, 1, 1)
			end
		end
	end)
	return tv
end

-- ctx = { me = 내 캐릭터의 번호 · float(글, x, y, 색) · words(설계의 gimmick.words) · dim(세기, 초) · body() → 내 몸 }
function ThiefView.event(tv, e)
	local bv, fx, ctx = tv.bv, tv.bv.fx, tv.ctx
	local W = ctx.words or {}
	local k = e.k
	if e.jars then
		tv.jars = e.jars -- (jars · jar · filled — 머리 위의 남은 단지)
	end
	if k == "jars" then
		tv.hide = e.smoke == true
	elseif k == "throw" then
		if bv.sound then
			bv:sound("boss_shot") -- (폭탄 던지기 패턴은 치는 순간에도 같은 소리 — 0.08초 안의 둘째는 나지 않는다)
		end
		local y0, x0, x1, y1, T = e.y - 70, e.x0, e.x, e.y, e.t
		fx.add(T, function(c, q)
			bomb(c, x0 + (x1 - x0) * q, y0 + (y1 - 6 - y0) * q - sin(q * math.pi) * 46, q * T)
		end)
	elseif k == "boom" then
		boom(bv, e.x, e.y, 1)
	elseif k == "bat" then
		if bv.sound then
			bv:sound("boss_shot") -- 쳐 낸 폭탄이 되날아간다
		end
		-- 맞혀서 되날아간다: 분홍 꼬리를 끌며 두목의 가슴으로
		local x0, y0, x1, y1, T = e.x, e.y - 6, e.to, e.toY - hOf(bossOf(bv)) * 0.5, e.t
		fx.add(T, function(c, q)
			local x, y = x0 + (x1 - x0) * q, y0 + (y1 - y0) * q - sin(q * math.pi) * 18
			for i = 1, 5 do
				local qq = max(0, q - i * 0.05)
				c:alpha(0.5 * (1 - i / 6))
				disc(c, x0 + (x1 - x0) * qq, y0 + (y1 - y0) * qq - sin(qq * math.pi) * 18, 3.5 - i * 0.5, PINK.l)
			end
			bomb(c, x, y, q * T * 3)
		end)
		fx.shards(e.x, e.y - 6, 5, PINK, { kind = "dot", up = 60, speed = 70 })
	elseif k == "backhit" then
		local x, y = bpos(bossOf(bv), e.x, 176)
		local h = hOf(bossOf(bv))
		boom(bv, x, y - h * 0.375, if e.jar then 1.8 else 1.4)
		if ctx.float then
			ctx.float(W.stagger or "", x, y - h - 30, PINK.l)
		end
	elseif k == "stagger" then
		local m = bossOf(bv)
		local T = e.t
		if m then
			fx.add(T, function(c, q)
				local x, y = posOf(m)
				for i = 0, 2 do
					local a = q * T * 5 + i * 2.09
					c:alpha(1)
					poly(c, starPts(x + cos(a) * 14, y - hOf(m) - 18 + sin(a) * 4, 3.2, a), if i == 0 then PINK.w else PINK.l)
				end
			end)
		end
	elseif k == "jar" then
		if bv.sound then
			bv:sound("boss_glass")
		end
		local m = bossOf(bv)
		if m then
			local x, y = posOf(m)
			local h = hOf(m)
			local jx = x - (m.dir or 1) * h * 0.325
			local who = whoOf(bv)
			if not (who and fx.sprite(who, "fx_jar", jx, y - h * 0.425, m.dir or 1, {})) then -- 단지가 깨진다(그림 fx_jar — 유리 조각 · 분홍 불씨: 그림의 가운데가 바닥 줄에서 21점 위)
				fx.shards(jx, y - h * 0.7, 10, GLASS, { kind = "tri", up = 80, speed = 100 })
				fx.shards(jx, y - h * 0.7, 8, PINK, { kind = "dot", up = 60, speed = 70 })
			end
		end
		-- 바닥에 남은 「되찾은 불씨」: 줍거나 사라질 때까지 일렁인다
		local em = { id = e.ember, x = e.x, y = e.y, live = true, t = 0 }
		tv.embers[e.ember] = em
		local who = whoOf(bv)
		em.rec = who and fx.sprite(who, "fx_ember", e.x, e.y, 1, { loop = 20, back = true }) -- 바닥의 되찾은 불씨(그림 fx_ember를 돌려 튼다 — 주우면 끝낸다)
		fx.add(20, function(c, q)
			if em.rec then
				return
			end
			if not em.live then
				return
			end
			em.t += 1 / 60
			local b = sin(em.t * 4) * 1.5
			c:alpha(0.35)
			disc(c, em.x, em.y - 7 + b, 7, PINK.n)
			c:alpha(1)
			poly(c, { { em.x - 4, em.y - 3 + b }, { em.x, em.y - 14 + b - sin(em.t * 9) }, { em.x + 4, em.y - 3 + b } }, PINK.n)
			poly(c, { { em.x - 2, em.y - 3 + b }, { em.x, em.y - 9 + b }, { em.x + 2, em.y - 3 + b } }, PINK.w)
		end)
	elseif k == "ember" or k == "emberGone" then
		local em = tv.embers[e.id]
		if em then
			em.live = false
			tv.embers[e.id] = nil
			if em.rec then
				em.rec.t = em.rec.life
			end
			if k == "ember" then
				fx.shards(em.x, em.y - 6, 10, PINK, { kind = "dot", up = 90, speed = 30, grav = -60, life = 0.7 })
				if ctx.float then
					ctx.float(W.ember or "", em.x, em.y - 30, PINK.l)
				end
			end
		end
	elseif k == "refill" then
		local m = bossOf(bv)
		if m and ctx.float then
			local x, y = posOf(m)
			ctx.float(W.refill or "", x, y - hOf(m) - 30, PINK.l)
		end
	elseif k == "filled" then
		local m = bossOf(bv)
		if m then
			local x, y = posOf(m)
			fx.shards(x - (m.dir or 1) * hOf(m) * 0.325, y - hOf(m) * 0.7, 8, PINK, { kind = "dot", up = 40, speed = 30, grav = -40 })
		end
	elseif k == "smoke" then
		-- 방이 연기로 덮인다: 어둡게 · 흐르는 연기 · 진짜 두목의 발밑에만 분홍 불티(머리 위의 남은 단지는 숨긴다)
		tv.hide = true
		if bv.sound then
			bv:sound("boss_smoke")
		end
		if ctx.dim then
			ctx.dim(0.45, e.t)
		end
		local lo, hi = bv.roomLo or 0, bv.roomHi or 768
		local who = whoOf(bv)
		for i = 0, 14 do
			local x = lo + (hi - lo) * (i + 0.5) / 15
			if who and i % 2 == 0 then
				fx.sprite(who, "fx_smoke", x, e.y or 176, if i % 4 == 0 then 1 else -1, { delay = i * 0.02 }) -- 연막탄의 연기(그림 fx_smoke)
			end
			puff(fx, x, e.y or 176, 16 + random() * 8, e.t, SMOKE, { dx = (random() - 0.5) * 30, dy = -6, delay = i * 0.02 })
		end
		local m = bossOf(bv)
		tv.smoke = { live = true }
		local S = tv.smoke
		fx.add(e.t, function(c, q)
			if not S.live or not m then
				return
			end
			local x, y = posOf(m)
			for i = 0, 3 do
				local f = (q * e.t * 2 + i * 0.25) % 1
				c:alpha(1 - f)
				c:style(if i % 2 == 0 then PINK.n else PINK.l)
				c:rect(floor(x - 10 + i * 6 + sin(i * 2.3) * 3), floor(y - 4 - (1 - f) * 10), 2, 2)
			end
			c:alpha(1)
		end)
	elseif k == "pop" then
		if bv.sound then
			bv:sound("boss_smoke") -- 가짜가 그을음으로 터진다
		end
		local who = whoOf(bv)
		if who then
			fx.sprite(who, "fx_soot", e.x, e.y, 1, {}) -- 가짜가 그을음으로 터진다(그림 fx_soot)
		end
		puff(fx, e.x, e.y - 30, 18, 0.7, SOOT, { dy = -16 })
		puff(fx, e.x - 10, e.y - 20, 12, 0.6, SOOT, { dy = -10, dx = -8, delay = 0.04 })
		puff(fx, e.x + 10, e.y - 20, 12, 0.6, SOOT, { dy = -10, dx = 8, delay = 0.04 })
		fx.shards(e.x, e.y - 24, 8, { d = 0x232931, n = 0x393e46, l = 0x515864, w = 0x7c8ea2 }, { kind = "dot", up = 70, speed = 80 })
		if e.hero and e.hero == ctx.me and ctx.dim and e.blind then
			ctx.dim(0.7, e.blind) -- 가짜를 쳤다: 그을음에 눈이 잠깐 가린다
		end
	elseif k == "clear" then
		tv.hide = false
		if tv.smoke then
			tv.smoke.live = false
			tv.smoke = nil
		end
		local m = bossOf(bv)
		if m and ctx.float then
			local x, y = posOf(m)
			ctx.float(if e.found then (W.found or "") else (W.miss or ""), x, y - hOf(m) - 30, PINK.l)
		end
	elseif k == "drop" then
		-- 못 찾았다: 진짜가 뛰어올라 세 자리에 불단지를 떨어뜨린다(t초 뒤 터진다)
		for i = -1, 1 do
			local x = e.x + i * e.spread
			fx.add(e.t, function(c, q)
				c:alpha(0.35 + 0.35 * q)
				c:style(PINK.d)
				c:rect(floor(x - 14), floor((e.y or 176) - 1), 28, 2)
				c:alpha(1)
				local y = (e.y or 176) - 120 + 110 * q * q
				disc(c, x, y, 7, GLASS.l)
				disc(c, x, y + 1, 5, PINK.n)
			end, { back = true })
			task.delay(e.t, function()
				boom(bv, x, e.y or 176, 1.1)
			end)
		end
	elseif k == "hook" then
		local hk = { x = e.x, live = true }
		tv.hooks[e.id] = hk
		local m = bossOf(bv)
		local T = e.range / e.speed
		fx.add(T + 0.2, function(c, q)
			if not hk.live then
				return
			end
			hk.x = e.x + e.dir * min(e.range, e.speed * q * (T + 0.2))
			local hx, hy = hk.x, e.y
			local bx, by = bpos(m, e.x - e.dir * 16, e.y + 34)
			bx, by = bx + ((m and m.dir) or e.dir) * 16, by - hOf(m) * 0.425
			c:alpha(1)
			line(c, bx, by, hx - e.dir * 6, hy, 0x393e46)
			c:style(0xa9bccb)
			c:rect(floor(hx - (if e.dir > 0 then 10 else 0)), floor(hy - 3), 10, 5)
			c:style(0xffffff)
			c:rect(floor(hx - (if e.dir > 0 then 10 else 0)), floor(hy + 2), 10, 1)
			c:style(0xa9bccb)
			c:rect(floor(hx + (if e.dir > 0 then 0 else -2)), floor(hy - 6), 2, 4)
		end)
	elseif k == "hookEnd" then
		local hk = tv.hooks[e.id]
		if hk then
			hk.live = false
			tv.hooks[e.id] = nil
			if e.hero then
				fx.shards(hk.x, e.y or 150, 6, GLASS, { kind = "tri", up = 50, speed = 80 })
			end
		end
	elseif k == "steal" then
		if e.hero == ctx.me and ctx.float and ctx.body then
			local b = ctx.body()
			ctx.float(W.steal or "", b.x, b.y - 46, PINK.l)
		end
	elseif k == "bigjar" then
		local x, y = bpos(bossOf(bv), e.x, 176)
		if not whoOf(bv) then
			boom(bv, x, y - 40, 2.6) -- (그림이 있으면 치는 순간의 fx_bigjar — bosses.js BOSS_FX — 가 터진다)
		end
		bv.shake(5, 0.4)
		if ctx.dim then
			ctx.dim(0.35, 0.5)
		end
		local lo, hi = bv.roomLo or 0, bv.roomHi or 768
		for i = 0, 10 do
			local px = lo + (hi - lo) * i / 10
			fx.add(0.5, function(c, q)
				c:alpha(0.8 * (1 - q))
				poly(c, { { px - 8, y }, { px, y - 30 * (1 - q) - 10 }, { px + 8, y } }, if i % 2 == 0 then PINK.n else PINK.l)
				c:alpha(1)
			end, { delay = math.abs(px - x) / 900 })
		end
	end
end

return ThiefView
