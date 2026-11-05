-- 넷째 보스전 「용암 거인」의 기믹을 화면에 그린다(2026-11-04 — 서버 sim/lavagim.luau가 보내는 "Gim" 신호마다 · 공방 luneTab.js의 lava* 함수와 같은 꼴).
--  ① 대분화(vents · pop · ventsOk · wipe): 숨구멍의 혹마다 아래에 빛나는 고리와 머리 위의 체력 띠 · 보스 창의 패턴 줄에 「대분화까지 n초」(bv.note) · 깨지면 분홍 조각 ·
--     다 깨면 「숨이 막혔다! 휘청!」 · 남으면 방 전체의 흰 · 분홍 섬광과 큰 흔들림(모두 쓰러진다 — 서버가 정한다)
--  ② 끓어오르는 분화구(boil · flood · floodEnd): 예고 동안 바닥 위로 「용암이 차오를 높이」의 끓는 선 · 끓는 동안 바닥 전체에 넘실대는 용암(발판 위는 덮지 않는다)
--  ③ 움켜쥐기(grabMark · grab · free · thrown · crush · drop · grabMiss): 겨눈 사람의 발밑에 분홍 고리가 돈다(fx_grabmark — 따라다닌다 · 2026-11-06 발톱 셋을 뺐다:
--     2026-11-05 사용자 "머리위에 아이콘뜨는것도 구리고" — 전에는 머리 위의 분홍 손 아이콘) → 잡히면 내 몸이 쥔 주먹의 자리에 묶인다(ctx.hold — boot.luau) · 못 풀면 즉사(crush)
--  ④ 사람마다 · 가장 먼 사람 · 방 곳곳의 자리(spots): 서버가 고른 자리에 예고(BossFx.spot 'lava') → 때가 되면 솟는다 · 구르는 바위(roll)
--  ⑤ 심장(heart · hop · heartOk · heartMiss): 튀는 자리 사이의 포물선 꼬리 · 머리 위의 체력 띠
--  ⑥ 부위(armL · armR · phase): 손이 굴 밖으로 물러나며 떨어지는 바위 조각 · 큰 흔들림(2026-11-04 방 셋 — 그다음 서버가 다음 방으로 옮긴다)
--  글 · 조각의 자리 = 지금 부위의 가운데(partMid — 첫 굴의 보스 자리는 오른쪽 벽 · 둘째 굴은 왼쪽 벽이라 그 자리면 화면 끝이다)
--  말(words)은 설계의 gimmick.words(영문은 lang). 그림은 코드로(겹친 빛 · 조각) — 보스의 이펙트 시트(Codex)가 나오면 터짐 · 대분화를 그 그림으로 바꾼다
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fx = require(ReplicatedStorage.shared.lune.fx)
local BossFx = require(ReplicatedStorage.shared.lune.bossfx)
local disc, poly, starPts = Fx.disc, Fx.poly, Fx.starPts
local sin, min, max, floor = math.sin, math.min, math.max, math.floor

local LavaView = {}
local PINK = { d = 0xb11fa5, n = 0xff3e9f, l = 0xff7ea2, w = 0xffffff }
local ROCK = { d = 0x232931, n = 0x393e46, l = 0x515864, w = 0x7c8ea2 }

local function bossOf(bv)
	local b = bv.list[1]
	return b and b.m
end
local function whoOf(bv): string?
	local m = bossOf(bv)
	return m and m.sprite and m.sprite.who
end
local function floorY(bv): number
	local m = bossOf(bv)
	return (m and m.info and m.info.y) or 176
end
-- 그 부위(k — 없으면 지금 체력의 부위)의 상자 가운데(가로)
local function partMid(m, k: number?): number
	local S = m and m.def and m.def.story
	local P = S and S.gimmick and S.gimmick.parts
	if not P or not m.info then
		return (m and m.x) or 384
	end
	local b = P[k or BossFx.phaseOf(m.hp, m.info.maxHp, P)].box
	return m.x + (b[1] + b[2]) / 2
end
-- 그 몬스터(졸개)의 화면 자리
local function mobOf(bv, id: number)
	local list = bv.mobs and bv.mobs.mobs -- (MobsView.mobs — 몬스터 번호마다)
	return list and list[id]
end

function LavaView.new(bv, ctx)
	local lv = { bv = bv, ctx = ctx, vents = nil, boilAt = nil, boilT = 0, floodTill = 0, mark = nil, spots = {}, heart = nil }
	local fx = bv.fx
	-- 늘 그리는 층(1e9초): 혹의 고리 · 체력 띠 · 끓는 바닥 · 손 표시 · 사람마다의 자리 · 심장의 체력 띠 · 「대분화까지」
	fx.add(1e9, function(c)
		local now = os.clock()
		local fy = floorY(bv)
		-- 끓어오르는 분화구: 예고 = 바닥 위 6점의 끓는 선(깜박) · 끓는 동안 = 바닥 전체의 용암(위 끝이 넘실댄다)
		local lo, hi = bv.lo or 0, bv.hi or 768
		if lv.boilAt and now - lv.boilAt < lv.boilT then
			local k = (now - lv.boilAt) / lv.boilT
			local blink = k > 0.7 and floor(k * 40) % 2 == 0
			for x = floor(lo), floor(hi) - 1, 3 do
				local wv = floor(sin((x + now * 60) / 7) * 1.5 + 0.5)
				c:alpha(0.8)
				c:style(if blink then PINK.w else PINK.l)
				c:rect(x, fy - 7 + wv, 2, 1)
			end
			c:alpha(0.18 + 0.2 * k)
			c:style(PINK.n)
			c:rect(floor(lo), fy - 6, floor(hi - lo), 6)
			c:alpha(1)
		end
		if now < lv.floodTill then
			for x = floor(lo), floor(hi) - 1 do
				local top = 4 + floor(sin((x + now * 45) / 9) * 1.6 + sin((x - now * 30) / 4) * 0.8 + 0.5)
				c:alpha(0.85)
				c:style(PINK.d)
				c:rect(x, fy - top, 1, top + 2)
				c:style(PINK.n)
				c:rect(x, fy - top, 1, max(1, top - 2))
				c:style(PINK.l)
				c:rect(x, fy - top, 1, 1)
			end
			c:alpha(1)
		end
		-- 숨구멍의 혹: 발밑의 빛나는 고리 · 머리 위의 체력 띠
		if lv.vents then
			for _, v in lv.vents.list do
				local m = mobOf(bv, v.id)
				if m and m.state ~= "gone" and m.state ~= "dead" then
					local x, y = floor((m.x or v.x) + 0.5), floor(v.y + 0.5)
					local pulse = 0.4 + 0.3 * sin(now * 8 + v.id)
					c:alpha(pulse)
					c:style(PINK.l)
					for a = 0, 23 do
						local t = a / 24 * math.pi * 2
						c:rect(floor(x + math.cos(t) * 14 + 0.5), floor(y - 1 + sin(t) * 3 + 0.5), 1, 1)
					end
					c:alpha(1)
					local f = math.clamp((m.hp or 0) / max(1, v.hp), 0, 1)
					c:style(ROCK.d)
					c:rect(x - 12, y - 24, 24, 4)
					c:style(PINK.n)
					c:rect(x - 11, y - 23, floor(22 * f + 0.5), 2)
				end
			end
		end
		-- 심장: 머리 위의 체력 띠
		if lv.heart then
			local m = mobOf(bv, lv.heart.id)
			if m and m.state ~= "gone" and m.state ~= "dead" then
				local x, y = floor((m.x or 0) + 0.5), floor(((m.info and m.info.y) or fy) + 0.5)
				local f = math.clamp((m.hp or 0) / max(1, lv.heart.hp or m.info.maxHp or 1), 0, 1)
				c:style(ROCK.d)
				c:rect(x - 14, y - 28, 28, 4)
				c:style(PINK.w)
				c:rect(x - 13, y - 27, floor(26 * f + 0.5), 2)
			end
		end
		-- 움켜쥐기의 표시: 겨눈 사람의 발밑에 도는 분홍 고리(fx_grabmark — 0.3초 전부터는 그 자리에 멈춘다)
		if lv.mark then
			local mk = lv.mark
			local k = math.clamp((now - mk.at) / mk.T, 0, 1)
			if k >= 1 then
				lv.mark = nil
			elseif now - mk.at < mk.T - 0.3 then
				local px, py = ctx.heroPos(mk.hero)
				if px and mk.rec then
					mk.rec.x, mk.rec.y = px, py
				end
			end
		end
		-- 사람마다 · 가장 먼 사람 · 방 곳곳의 자리: 예고 → 때가 되면 솟는다(BossView의 표시된 자리와 같은 셈)
		for i = #lv.spots, 1, -1 do
			local sp = lv.spots[i]
			local age = now - sp.at
			if age >= sp.T then
				table.remove(lv.spots, i)
				BossFx.blast(fx, whoOf(bv) or "", sp.x, sp.y, sp.def, bv.shake)
				if bv.sound then
					bv:sound(sp.def.sfx)
				end
			else
				BossFx.spot(c, sp.x, sp.y, sp.def.r, sp.def.up, age / sp.T, nil, nil, "lava")
			end
		end
		-- 보스 창의 패턴 줄: 「대분화까지 n초」
		if lv.vents then
			local left = max(0, lv.vents.t - (now - lv.vents.at))
			bv.note = string.format("%s %d", (ctx.words and ctx.words.vents) or "", math.ceil(left))
		else
			bv.note = nil
		end
	end)
	return lv
end

local function burst(bv, x: number, y: number, n: number, big: number)
	local fx = bv.fx
	fx.add(0.2, function(c, k)
		c:alpha(1 - k * 0.5)
		poly(c, starPts(x, y, (10 + 12 * k) * big, k * 0.6), if k < 0.4 then PINK.w else PINK.l)
		disc(c, x, y, (6 - 3 * k) * big, PINK.n)
		c:alpha(1)
	end)
	fx.shards(x, y, n, PINK, { kind = "tri", up = 110, speed = 110 })
end

-- ctx = { me · words · float(글, x, y) · heroPos(번호) → x, y · hold(x, y, 초 | nil) · dim(세기, 초) }
function LavaView.event(lv, e)
	local bv, fx, ctx = lv.bv, lv.bv.fx, lv.ctx
	local W = ctx.words or {}
	local k = e.k
	local m = bossOf(bv)
	local bx, fy = partMid(m), floorY(bv)
	local now = os.clock()
	if k == "vents" then
		lv.vents = { list = e.list or {}, t = e.t or 20, at = now }
		for _, v in lv.vents.list do
			v.hp = v.hp or 1 -- (혹의 체력 — 서버가 세울 때 정해 함께 보낸다)
			burst(bv, v.x, v.y - 8, 6, 0.8)
		end
		ctx.float(W.vents or "", bx, fy - 170)
	elseif k == "pop" then
		-- 혹이 터진다: 이 보스의 마그마 덩이 그림(fx_splash — 없으면 코드로 그린 섬광)
		if not fx.sprite(whoOf(bv) or "", "fx_splash", e.x or bx, e.y or fy, 1, {}) then
			burst(bv, e.x or bx, (e.y or fy) - 8, 10, 1)
		end
		bv.shake(2, 0.12)
	elseif k == "ventsOk" then
		lv.vents = nil
		ctx.float(W.ventsOk or "", bx, fy - 170)
		bv.shake(3, 0.3)
	elseif k == "wipe" then
		lv.vents = nil
		ctx.float(W.wipe or "", bx, fy - 170)
		ctx.dim(0.9, 0.6) -- 방 전체가 하얗게(쓰러짐은 서버의 hurt)
		fx.add(0.9, function(c, kk)
			c:alpha(0.7 * (1 - kk))
			c:style(if kk < 0.3 then PINK.w else PINK.l)
			c:rect(floor(bv.lo or 0), fy - 220, floor((bv.hi or 768) - (bv.lo or 0)), 230)
			c:alpha(1)
		end)
		for i = 0, 7 do
			-- 대분화: 방 곳곳에서 용암 기둥이 솟는다(이 보스의 fx_geyser — 없으면 코드로 그린 섬광)
			local x = (bv.lo or 0) + ((bv.hi or 768) - (bv.lo or 0)) * (i + 0.5) / 8
			if not fx.sprite(whoOf(bv) or "", "fx_geyser", x, fy, if i % 2 == 0 then 1 else -1, { delay = i * 0.04 }) then
				burst(bv, x, fy - 20, 6, 1.6)
			end
		end
		bv.shake(6, 0.8)
	elseif k == "boil" then
		lv.boilAt, lv.boilT = now, e.t or 3
		ctx.float(W.flood or "", bx, fy - 170)
	elseif k == "flood" then
		lv.boilAt = nil
		lv.floodTill = now + (e.t or 6)
		bv.shake(2, 0.3)
	elseif k == "floodEnd" then
		lv.floodTill = 0
	elseif k == "grabMark" then
		local px, py = ctx.heroPos(e.hero)
		local T = e.t or 1.5
		local rec = px and fx.sprite(whoOf(bv) or "", "fx_grabmark", px, py, 1, {}) or nil
		if rec then
			rec.life = T -- 발밑에 도는 분홍 고리(2026-11-06 — pixelfx rune-circle · 제 빠르기로 돌며 예고 시간 동안 · 그 전: 발톱 셋이 조여 오는 장 여섯 — 사용자 "손 아래에 이상하게 발톱이 세개가생겨")
		end
		lv.mark = { hero = e.hero, at = now, T = T, rec = rec }
	elseif k == "grab" then
		if lv.mark and lv.mark.rec then
			lv.mark.rec.t = lv.mark.rec.life
		end
		lv.mark = nil
		ctx.float(W.grab or "", e.x or bx, (e.y or fy) - 30)
		if e.hero == ctx.me then
			ctx.hold(e.x, e.y, e.t or 4)
		end
		bv.shake(3, 0.2)
	elseif k == "free" or k == "thrown" or k == "drop" or k == "crush" then
		if e.hero == ctx.me then
			ctx.hold(nil)
		end
		if k == "crush" then
			-- 못 풀어 짓눌렸다(즉사 — 2026-11-05): 쥔 주먹의 자리에서 분홍 섬광 · 바위 조각 · 크게 흔들림
			local px, py = ctx.heroPos(e.hero)
			ctx.float(W.crush or "", px or bx, (py or fy) - 30)
			burst(bv, px or bx, (py or fy) - 10, 12, 1.6)
			fx.shards(px or bx, (py or fy) - 10, 6, ROCK, { kind = "tri", up = 90, speed = 120 })
			bv.shake(5, 0.5)
		elseif k ~= "drop" then
			ctx.float((if k == "free" then W.free else W.thrown) or "", bx, fy - 120)
		end
	elseif k == "grabMiss" then
		if lv.mark and lv.mark.rec then
			lv.mark.rec.t = lv.mark.rec.life
		end
		lv.mark = nil
	elseif k == "spots" then
		local p = m and m.def.story.patterns[e.pat or 0]
		if p and p.spots then
			for _, s in e.list or {} do
				table.insert(lv.spots, { x = s[1], y = if s[3] and p.spots.up < 150 then s[3] else fy, at = now, T = (p.tell or 1) + (s[2] or 0), def = p.spots })
			end
		end
	elseif k == "roll" then
		BossFx.wave(fx, whoOf(bv) or "", e.x or bx, fy, e.dir or 1, { speed = e.speed or 160, range = e.range or 200, w = 12, up = 18 }, 0, bv.lo, bv.hi)
	elseif k == "heart" then
		ctx.float(W.heart or "", bx, fy - 150)
		lv.heart = { id = e.add, hp = e.hp }
		bv.shake(3, 0.4)
	elseif k == "hop" then
		lv.heart = lv.heart or {}
		lv.heart.id = e.add
		local mm = mobOf(bv, e.add)
		lv.heart.hp = lv.heart.hp or (mm and mm.info and mm.info.maxHp)
		local x0, y0, x1, y1, T = e.x0 or bx, e.y0 or fy, e.x or bx, e.y or fy, e.t or 0.35
		fx.add(T + 0.2, function(c, kk)
			local q = min(1, kk * (T + 0.2) / T)
			for j = 0, 5 do
				local u = max(0, q - j * 0.05)
				local x = x0 + (x1 - x0) * u
				local y = y0 + (y1 - y0) * u - sin(u * math.pi) * 40 - 8
				c:alpha(0.8 - j * 0.12)
				c:style(if j == 0 then PINK.w else PINK.l)
				c:rect(floor(x + 0.5) - 1, floor(y + 0.5) - 1, 3, 3)
			end
			c:alpha(1)
		end)
	elseif k == "heartOk" then
		ctx.float(W.heartOk or "", bx, fy - 150)
		lv.heart = nil
		bv.shake(4, 0.4)
	elseif k == "heartMiss" then
		ctx.float(W.heartMiss or "", bx, fy - 150)
		lv.heart = nil
	elseif k == "armL" or k == "armR" then
		-- 손이 굴 밖으로 물러난다(그 부위의 가운데에서 · 벽 쪽으로): 굴의 천장 · 틈에서 바위 조각이 떨어지고 크게 흔들린다
		local cx = partMid(m, if k == "armL" then 1 else 2)
		local wall = if k == "armL" then 1 else -1
		ctx.float((if k == "armL" then W.armL else W.armR) or "", cx, fy - 120)
		for i = 0, 5 do
			fx.shards(cx + wall * (i * 18 - 30), fy - 150 + i * 4, 3, ROCK, { kind = "tri", up = 20, speed = 90 })
		end
		burst(bv, cx, fy - 60, 12, 1.8)
		bv.shake(5, 0.8)
	end
end

return LavaView
