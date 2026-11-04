-- 넷째 보스전 「용암 거인」의 기믹(2026-11-04 — 공방 design/weekboss.js lavagiant.gimmick · 설계 design/bosses.js BOSS_GIMMICK.lavagiant).
--  사용자(11-03): "1,2,3 페로 나눠서 왼팔 깨고 다음 스테이지 오른팔 깨고 다음스테이지 최종 몸통형태고 이 보스는 움직이지 않는 허수아비에 피가 많은 피돼지인 형태 …
--   반드시 파훼해야하는 공통 기믹같은걸 넣어서 실패하면 전멸기" → (11-04) "이제 용암거인 마저 만들면된다"
--  몸: 한 마리의 보스 — 체력을 부위(parts)의 몫으로 나눈다(왼팔 25% · 오른팔 25% · 몸통 50%). 지금 페이즈의 부위만 맞는다(mob.hitBox — 방의 mobsInBox가 본다).
--   부위의 체력이 다 닳으면(넘친 피해는 버린다) shift초 동안 맞지 않고(팔이 부서진다 · 가슴까지 솟는다) 다음 페이즈
--  공통 기믹 「대분화」: 숨구멍마다 마그마 혹(졸개 lavablister — 체력 = 거인 전체의 vents.hp몫) · count초 안에 다 깨면 휘청(받는 피해 x mul) · 남으면 방의 모두가 쓰러진다(무적 · 막기 무시) + 부위 체력 되찾음
--  끓어오르는 분화구(flood): every초마다 — 두 주먹을 쳐들고 울부짖고(tell초) → time초 동안 바닥의 사람은 tick초마다 최대 체력의 pct%(발판 위는 괜찮다). 그동안 패턴은 flood가 붙은 것만
--  심장 드러남(셋째 페이즈 · 몸통이 heart.at 아래로 한 번): 거인이 못에 가라앉고(맞지 않는다) 용암 심장(졸개 lavaheart)이 바닥 · 발판을 튀어 다닌다 → 깨면 솟아 받는 피해 x mul · 못 깨면 몸통 체력을 되찾는다
--  패턴의 칸(방 sim/room.luau가 부른다): grab = 움켜쥐기 · pull = 맞은 사람을 끌어온다 · band = 그 높이만 맞는 띠(끓는 숨) · roll = 떨어진 바위가 구른다 · spots.aim each · far · rand = 자리를 이 모듈이 고른다
--  방이 부른다: init · boss(보스의 한 걸음 — true면 방은 그 걸음을 더 하지 않는다) · can(패턴을 쓸 수 있는가) · spots(자리) · strike(칠 때) · dmgIn(거인이 받는 피해) · immune · tick(방의 한 걸음) · hitMul
--  화면에 알리는 것: events { type = "gim", k = 무엇, ... } → 서버(world.luau)가 방에 "Gim"으로(화면 client/lune/lavaView.luau) · 끌어오기 { type = "pull" }
--  숫자는 모두 설계(weekboss.js)의 것. 바인드는 언제나 걸린다(지금 패턴을 거둔다 — 방이 먼저 본다) · 「대분화까지」는 묶여도 흐른다
--  2026-11-04 다시(혼테일처럼 방 셋 — 사용자 "첫번째 거인의 손은 맵의 좌측, 혹은 우측 끝에서나오는거야 … 마지막 방은 거대한 얼굴 몸통이 나오는거야 손까지 제한시간이랑 데스카운트는 세방이 합쳐서 하나야"):
--   부위마다 따로 된 방(첫 굴 r3d5 · 둘째 굴 r3d6 · 분화구 r3d7 — 장면의 bosses에 stage). 그 방의 보스는 그 부위부터 선다(체력 = 그 부위의 위 끝 · 들어서면 spawn초 동안 손이 밀고 들어온다).
--   부위가 다 닳으면 shift초 동안 손이 굴 밖으로 빠져나가고 → room.lavaNext = { ph, hp }를 적는다 → 서버(world.luau의 toStage)가 방의 모두를 다음 방으로 옮긴다(흐른 시간 · 데스 카운트 · 체력은 그대로)
local Hero = require(script.Parent.hero)
local Buffs = require(script.Parent.buffs)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])

local Gim = {}
local HERO_W = 5
local TILE = 16

local function alive(h): boolean
	return h.alive and not h.inCine
end

-- 부위(지금 페이즈)의 체력 구간: lo ~ hi(전체 체력 기준) · 그 부위
local function partOf(mob, ph: number?)
	local P = mob.def.story.gimmick.parts
	local k = ph or mob.ph
	local lo, hi = 0, 1
	local acc = 0
	for i = #P, 1, -1 do
		local share = P[i].share
		if i == k then
			lo, hi = acc, acc + share
		end
		acc += share
	end
	return mob.maxHp * lo, mob.maxHp * hi, P[k]
end
Gim.partOf = partOf

-- 지금 부위의 남은 몫(0 ~ 1)
local function partFrac(mob): number
	local lo, hi = partOf(mob)
	return math.clamp((mob.hp - lo) / math.max(1, hi - lo), 0, 1)
end
Gim.partFrac = partFrac

-- 그 페이즈(방)의 숨구멍 자리: 방마다 따로 적은 것(at[페이즈] — 2026-11-04 방 셋) · 아니면 모두의 것
local function ventsAt(V, ph: number)
	return if typeof(V.at[1][1]) == "table" then V.at[ph] else V.at
end

local function setBox(mob)
	local _, _, P = partOf(mob)
	local b = P.box
	mob.hitBox = { b[1], b[2], b[3], b[4] }
end

local function newAdd(room, boss, kind: string, role: string, hp: number)
	local def = COMBAT.mobs[kind]
	local add = {
		id = #room.mobs + 1, kind = kind, def = def, lv = boss.lv, homeX = boss.x, y = boss.y, a = boss.a, b = boss.b, x = boss.x, dir = 1,
		state = "gone", t = 0, hp = hp, maxHp = hp, cd = 0, wait = 0, goal = boss.x, target = nil :: any, aggro = 0, struck = false, respawn = math.huge,
		add = true, away = true, gimAdd = role, hpAdd = true,
	}
	table.insert(room.mobs, add)
	table.insert(boss.adds, add)
	return add
end

function Gim.init(room, boss)
	local G = boss.def.story.gimmick
	boss.gimMod = "lava"
	boss.ph = boss.stage or 1 -- 몇째 방(그 부위부터 — 장면의 bosses의 stage)
	if boss.ph > 1 then
		local _, hi = partOf(boss, boss.ph)
		boss.startHp = hi -- 그 부위의 위 끝(앞 방에서 넘어온 체력이 있으면 서버가 다시 적는다 — world.luau의 toStage)
	end
	local ph = boss.ph
	boss.lava = {
		ventT = G.vents.first[ph], floodT = G.flood.every[ph], vents = nil, ventN = 0, flood = 0, floodTick = 0,
		stagger = 0, mul = 1, mulT = 0, grab = nil, grabAt = nil, heart = nil, heartDone = false, toShift = false, spots = nil, alt = 0,
	}
	boss.lava.blisters = {}
	local n = 0
	for k = 1, #G.parts do
		n = math.max(n, #ventsAt(G.vents, k))
	end
	for _ = 1, n do
		table.insert(boss.lava.blisters, newAdd(room, boss, G.vents.kind, "blister", 1))
	end
	boss.lava.heartAdd = newAdd(room, boss, G.heart.kind, "heart", 1)
	setBox(boss)
	room.lavaBoss = boss
end

-- 하던 것을 거둔다(예고 중이던 자리 · 연속기) — 바인드와 같은 법
local function cancel(room, mob)
	if mob.state == "tell" then
		room:bossSpotsOff(mob)
	end
	mob.pat, mob.chain, mob.chainRest, mob.chainPat, mob.quick, mob.alt = 0, nil, nil, 0, 1, 0
end

local function say(events, mob, k: string, extra)
	local e = { type = "gim", k = k, mob = mob.id }
	for a, v in extra or {} do
		e[a] = v
	end
	table.insert(events, e)
end

-- 쥔 사람을 놓는다(놓친다 · 내던진다 · 쓰러졌다)
local function release(room, mob, how: string, events)
	local g = mob.lava
	local gr = g.grab
	if not gr then
		return
	end
	g.grab = nil
	local h = gr.h
	if how == "crush" and h.alive and not h.god then
		-- 못 풀었다(2026-11-05 사용자 「못 풀면 즉사」): 무적 · 막기 · 죽음의 가호를 무시하고 쓰러진다(대분화와 같은 법 — 관리자의 시험용 무적만 빼고)
		h.invuln = 0
		local dmg = Hero.hurt(h, h.hp + h.maxHp, true)
		if dmg > 0 then
			table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = mob.x, dead = not h.alive })
		end
	elseif how == "throw" and h.alive then
		local G = gr.def
		local raw = h.maxHp * G.throw / 100
		local dmg = Hero.hurt(h, raw, true)
		if dmg > 0 then
			table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = mob.x, dead = not h.alive })
		end
		-- 그 쪽 벽으로 내던진다(방의 끝에서 24점 안)
		local side = mob.lava.grabSide or 1
		local x = if side > 0 then mob.b - 24 else mob.a + 24
		h.x = x
		table.insert(events, { type = "pull", hero = h.id, x = x })
	end
	say(events, mob, if how == "free" then "free" elseif how == "throw" then "thrown" elseif how == "crush" then "crush" else "drop", { hero = h.id })
	if mob.state == "grab" then
		mob.state, mob.t, mob.pat, mob.rest = "idle", 0, 0, 1.0
	end
end

-- 방의 모두가 쓰러진다(대분화 — 무적 · 막기 · 죽음의 가호를 무시한다 · 관리자의 시험용 무적만 빼고)
local function wipe(room, mob, heroes, events)
	for _, h in heroes do
		if h.alive and not h.inCine and not h.god then
			h.invuln = 0
			local dmg = Hero.hurt(h, h.hp + h.maxHp, true)
			if dmg > 0 then
				table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = mob.x, dead = not h.alive })
			end
		end
	end
end

-- 부위 체력을 되찾는다(그 부위의 몫 — 부위의 위 끝을 넘지 않는다)
local function regain(mob, k: number)
	local lo, hi = partOf(mob)
	mob.hp = math.min(hi, mob.hp + (hi - lo) * k)
end

-- 숨구멍에 혹을 밀어 올린다(지금 페이즈가 쓰는 자리)
local function ventsStart(room, mob, events)
	local g, V = mob.lava, mob.def.story.gimmick.vents
	local ph = mob.ph
	local use = table.clone(V.use[ph])
	local alt = V.alt[ph]
	if alt then
		g.alt += 1
		table.insert(use, alt[(g.alt - 1) % #alt + 1])
	end
	local list = {}
	for _, i in use do
		local add = g.blisters[i]
		local at = ventsAt(V, ph)[i]
		local hp = math.max(1, math.floor(mob.maxHp * V.hp + 0.5))
		add.away, add.state, add.t, add.hp, add.maxHp = false, "spawn", 0, hp, hp
		add.x, add.homeX, add.y, add.a, add.b = at[1] * TILE, at[1] * TILE, at[2] * TILE, at[1] * TILE - 1, at[1] * TILE + 1
		add.y0 = add.y -- (스냅샷이 높이를 보낸다 — 높은 발판 위의 혹)
		table.insert(list, { id = add.id, x = add.x, y = add.y, hp = hp })
	end
	g.ventN += 1
	g.vents = { t = V.count[ph], adds = {} }
	for _, i in use do
		table.insert(g.vents.adds, g.blisters[i])
	end
	say(events, mob, "vents", { n = g.ventN, t = V.count[ph], list = list })
end

local function ventsEnd(room, mob, ok: boolean, heroes, events)
	local g, V = mob.lava, mob.def.story.gimmick.vents
	for _, add in g.vents.adds do
		add.away, add.state, add.t = true, "gone", 0
	end
	g.vents = nil
	g.ventT = V.every[mob.ph]
	if ok then
		say(events, mob, "ventsOk", { t = V.stagger.time })
		-- 휘청: 지금 하던 것을 거두고 · 받는 피해 x mul(가라앉았거나 부위가 바뀌는 중이면 휘청은 없고 피해 배수만)
		g.mul, g.mulT = V.stagger.mul, V.stagger.time
		if mob.state ~= "shift" and not g.heart then
			release(room, mob, "drop", events)
			cancel(room, mob)
			mob.state, mob.t = "stagger", 0
			g.stagger = V.stagger.time
		end
	else
		regain(mob, V.regain)
		say(events, mob, "wipe", { hp = mob.hp })
		wipe(room, mob, heroes, events)
	end
end

-- 심장 드러남
local function heartStart(room, mob, events)
	local g, H = mob.lava, mob.def.story.gimmick.heart
	release(room, mob, "drop", events)
	cancel(room, mob)
	local lo, hi = partOf(mob)
	local add = g.heartAdd
	local hp = math.max(1, math.floor((hi - lo) * H.hp + 0.5))
	add.away, add.state, add.t, add.hp, add.maxHp = true, "gone", 0, hp, hp
	g.heart = { st = "sink", t = 0, life = H.time, hop = 0, spot = 0 }
	g.heartDone = true
	mob.state, mob.t, mob.hitBox = "sink", 0, false
	say(events, mob, "heart", { t = H.time, hp = hp, add = add.id })
end

-- 심장이 다음 자리로 튄다: 설계의 hops(분화구의 양옆 바닥 · 껍질 · 거인 앞 — 겨눈 사람 가까이로 치우치지 않게 차례대로)
local function heartHop(room, mob, events)
	local g = mob.lava
	local add = g.heartAdd
	local HOPS = mob.def.story.gimmick.heart.hops
	g.heart.spot = g.heart.spot % #HOPS + 1
	local at = HOPS[g.heart.spot]
	local fromX, fromY = add.x, add.y
	add.x, add.homeX, add.y, add.y0 = at[1] * TILE, at[1] * TILE, at[2] * TILE, at[2] * TILE
	add.a, add.b = add.x - 1, add.x + 1
	say(events, mob, "hop", { add = add.id, x0 = fromX, y0 = fromY, x = add.x, y = add.y, t = 0.35 })
end

local function stepHeart(room, mob, heroes, dt: number, events)
	local g, H = mob.lava, mob.def.story.gimmick.heart
	local hs = g.heart
	hs.t += dt
	if hs.st == "sink" then
		if hs.t >= H.sink then
			hs.st, hs.t = "under", 0
			mob.state, mob.t = "under", 0
			local add = g.heartAdd
			add.away, add.state, add.t = false, "spawn", 0
			add.x, add.homeX, add.y, add.y0 = mob.x, mob.x, mob.y, mob.y
			add.a, add.b = add.x - 1, add.x + 1
			heartHop(room, mob, events)
		end
	elseif hs.st == "under" then
		local add = g.heartAdd
		hs.life -= dt
		hs.hop += dt
		if add.state == "dead" or add.hp <= 0 then
			-- 깼다: 솟아 받는 피해 x mul
			add.away, add.state, add.t = true, "gone", 0
			g.mul, g.mulT = H.mul, H.buff
			hs.st, hs.t = "rise", 0
			mob.state, mob.t = "rise", 0
			say(events, mob, "heartOk", { t = H.buff })
		elseif hs.life <= 0 then
			add.away, add.state, add.t = true, "gone", 0
			regain(mob, H.regain)
			hs.st, hs.t = "rise", 0
			mob.state, mob.t = "rise", 0
			say(events, mob, "heartMiss", { hp = mob.hp })
		elseif hs.hop >= H.hop then
			hs.hop = 0
			heartHop(room, mob, events)
		end
	elseif hs.st == "rise" then
		if hs.t >= H.rise then
			g.heart = nil
			mob.state, mob.t, mob.rest = "idle", 0, 0.8
			setBox(mob)
		end
	end
end

-- 페이즈가 바뀐다(부위가 다 닳았다): shift초 동안 맞지 않는다
local function shiftStart(room, mob, events)
	local g, G = mob.lava, mob.def.story.gimmick
	release(room, mob, "drop", events)
	cancel(room, mob)
	g.toShift = false
	mob.state, mob.t, mob.hitBox = "shift", 0, false
	g.stagger, g.flood = 0, 0
	g.shiftT = G.shift[mob.ph]
	say(events, mob, if mob.ph == 1 then "armL" else "armR", { t = g.shiftT })
end

-- 거인이 칠 쪽 · 패턴을 고른다(걷지도 돌아보지도 않는다): 겨눌 사람 = 가장 가까운 살아 있는 사람
local function nearest(mob, heroes)
	local best, bd, bid = nil, math.huge, nil
	for id, h in heroes do
		if alive(h) and not Buffs.stealth(h) then
			local d = math.abs(h.x - mob.x)
			if d < bd then
				best, bd, bid = h, d, id
			end
		end
	end
	return best, bid
end

-- 보스의 한 걸음(방의 stepBoss가 맨 앞에 부른다). true면 방은 그 걸음을 더 하지 않는다(예고 · 친 뒤 · 바인드는 방이 한다)
function Gim.boss(room, mob, heroes, dt: number, events): boolean
	local g, G = mob.lava, mob.def.story.gimmick
	g.heroes = heroes
	-- 받는 피해 배수(휘청 · 심장을 깬 뒤)의 시간
	if g.mulT > 0 then
		g.mulT -= dt
		if g.mulT <= 0 then
			g.mul = 1
		end
	end
	-- 대분화: 혹이 다 깨졌는가 · 시간이 다 됐는가(묶여도 · 부위가 바뀌어도 흐른다)
	if g.vents then
		g.vents.t -= dt
		local left = 0
		for _, add in g.vents.adds do
			if not add.away and add.state ~= "dead" and add.state ~= "gone" then
				left += 1
			elseif add.state == "dead" and not add.away then
				add.away, add.state = true, "gone"
				say(events, mob, "pop", { add = add.id, x = add.x, y = add.y })
			end
		end
		if left == 0 then
			ventsEnd(room, mob, true, heroes, events)
		elseif g.vents.t <= 0 then
			ventsEnd(room, mob, false, heroes, events)
		end
	elseif mob.state ~= "shift" and not g.heart then
		g.ventT -= dt
		if g.ventT <= 0 then
			ventsStart(room, mob, events)
		end
	end
	-- 끓어오르는 분화구가 끓는 동안: tick초마다 바닥의 사람
	if g.flood > 0 then
		g.flood -= dt
		g.floodTick -= dt
		if g.floodTick <= 0 then
			g.floodTick = G.flood.tick
			for _, h in heroes do
				if alive(h) and mob.y - h.y < G.flood.up and h.y <= mob.y + 4 and not Buffs.guard(h) then
					local dmg = Hero.hurt(h, h.maxHp * G.flood.pct / 100, true)
					if dmg > 0 then
						table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = mob.x, dead = not h.alive })
					end
				end
			end
		end
		if g.flood <= 0 then
			say(events, mob, "floodEnd")
		end
	end
	-- 움켜쥔 사람: tick초마다 · 파티가 그동안 오른팔 체력의 free몫을 깎으면 놓친다(dmgIn이 센다) · 시간이 다 되면 내던진다
	if g.grab then
		local gr = g.grab
		gr.t -= dt
		gr.tick -= dt
		if not gr.h.alive then
			release(room, mob, "drop", events)
		elseif gr.freeLeft <= 0 then
			release(room, mob, "free", events)
		elseif gr.t <= 0 then
			release(room, mob, if gr.def.kill then "crush" else "throw", events) -- (kill = 못 풀면 즉사 — 2026-11-05)
		else
			gr.h.x, gr.h.y = gr.x, gr.y
			if gr.tick <= 0 then
				gr.tick = gr.def.tick
				local dmg = Hero.hurt(gr.h, gr.h.maxHp * gr.def.pct / 100, true)
				if dmg > 0 then
					table.insert(events, { type = "hurt", hero = gr.h.id, dmg = dmg, hp = gr.h.hp, from = mob.x, dead = not gr.h.alive })
				end
			end
			if mob.state ~= "grab" then
				mob.state, mob.t = "grab", 0
			end
			return true
		end
	end
	if mob.state == "dead" or mob.state == "gone" or mob.state == "spawn" then
		return false -- (방이 한다)
	end
	-- 부위가 다 닳았다 → 페이즈가 바뀐다
	if g.toShift and mob.state ~= "shift" then
		shiftStart(room, mob, events)
		return true
	end
	if mob.state == "shift" then
		if mob.t >= g.shiftT and not g.left then
			if mob.stage then
				-- 방이 여럿(2026-11-04): 손이 굴 밖으로 다 빠져나갔다 → 다음 방으로(서버가 옮긴다 — 이 방의 거인은 그 자세로 남는다)
				g.left = true
				room.lavaNext = { ph = mob.ph + 1, hp = mob.hp }
				say(events, mob, "next", { ph = mob.ph + 1 })
			else
				mob.ph += 1
				setBox(mob)
				mob.state, mob.t, mob.rest = "idle", 0, 1.0
				g.ventT = math.min(g.ventT, G.vents.first[mob.ph])
				g.floodT = G.flood.every[mob.ph]
				say(events, mob, "phase", { ph = mob.ph })
			end
		end
		return true
	end
	-- 심장 드러남(셋째 페이즈 · 한 번)
	if g.heart then
		stepHeart(room, mob, heroes, dt, events)
		return true
	end
	if mob.ph == 3 and not g.heartDone and partFrac(mob) <= G.heart.at and mob.state ~= "tell" and mob.state ~= "act" then
		heartStart(room, mob, events)
		return true
	end
	if mob.state == "stagger" then
		g.stagger -= dt
		if g.stagger <= 0 then
			mob.state, mob.t, mob.rest = "idle", 0, 0.6
		end
		return true
	end
	if mob.state == "boil" then
		-- 끓어오르는 분화구의 예고: 두 주먹을 쳐들고 울부짖는다 → 바닥이 끓는다
		if mob.t >= G.flood.tell then
			mob.state, mob.t, mob.rest = "idle", 0, 0.3
			g.flood, g.floodTick = G.flood.time, 0
			say(events, mob, "flood", { t = G.flood.time })
		end
		return true
	end
	if mob.state == "tell" then
		-- 움켜쥐기의 표시: 겨눈 사람을 따라가다 0.3초 전에 멈춘다
		local p = mob.def.story.patterns[mob.pat]
		if p and p.grab and g.grabAim then
			local h = heroes[g.grabAim]
			if h and h.alive and mob.t < p.tell - 0.3 then
				g.grabAt = { h.x, h.y }
			end
		end
		return false
	end
	if mob.state ~= "idle" and mob.state ~= "run" then
		return false
	end
	-- 쉬는 동안: 묶였으면 그대로 · 끓어오르는 분화구의 때 · 체력 구간의 분노 · 다음 패턴
	if (mob.bind or 0) > 0 or (mob.stun or 0) > 0 then
		return false -- (방의 바인드 셈)
	end
	mob.state = "idle"
	g.floodT -= dt
	if g.floodT <= 0 and g.flood <= 0 and not g.vents then
		g.floodT = G.flood.every[mob.ph]
		mob.state, mob.t = "boil", 0
		say(events, mob, "boil", { t = G.flood.tell })
		return true
	end
	local S = mob.def.story
	if S.phase and not mob.raged and mob.hp <= mob.maxHp * S.phase.at then
		mob.raged = true
		mob.state, mob.t, mob.pat = "roar", 0, 0
		mob.chain, mob.chainPat = nil, 0
		return true
	end
	mob.rest = math.max(0, mob.rest - dt)
	local target, tid = nearest(mob, heroes)
	mob.target = tid
	if not target then
		return true
	end
	if mob.rest <= 0 then
		local pick, i = room:bossPick(mob, math.abs(target.x - mob.x))
		if pick then
			local p = room:bossStart(mob, i, target)
			if p and p.grab then
				g.grabAim, g.grabAt = tid, { target.x, target.y }
				say(events, mob, "grabMark", { hero = tid, t = p.tell })
			end
		end
	end
	return true
end

-- 그 패턴을 지금 쓸 수 있는가(방의 bossCan이 더 본다): 페이즈 · 부위 체력의 몫 · 끓는 동안은 flood가 붙은 것만 · 그쪽 팔에 겨눌 사람이 있는가
function Gim.can(room, mob, p): boolean
	if p.ph and p.ph ~= mob.ph then
		return false
	end
	if p.pfrom and partFrac(mob) > p.pfrom then
		return false
	end
	local g = mob.lava
	if g.flood > 0 and not p.flood then
		return false
	end
	if p.side and p.zone and not p.chain then
		-- 그쪽(팔이 닿는 곳)에 사람이 하나도 없으면 쓰지 않는다
		local any = false
		for _, h in g.heroes or {} do
			if alive(h) and (h.x - mob.x) * p.side > 0 then
				any = true
				break
			end
		end
		if not any then
			return false
		end
	end
	return true
end

-- 이 모듈이 고르는 자리(spots.aim each · far · rand): { { x, 기다림 } } — 화면에도 그대로 보낸다(events)
function Gim.spots(room, mob, p, lo: number, hi: number)
	local sp = p.spots
	local g = mob.lava
	local list = {}
	if sp.aim == "each" then
		local n = 0
		for _, h in g.heroes or {} do
			if alive(h) then
				table.insert(list, { math.clamp(h.x, lo + sp.r, hi - sp.r), n * (sp.lag or 0), h.y })
				n += 1
			end
		end
	elseif sp.aim == "far" then
		local best, bd = nil, -1
		for _, h in g.heroes or {} do
			if alive(h) and math.abs(h.x - mob.x) > bd then
				best, bd = h, math.abs(h.x - mob.x)
			end
		end
		if best then
			table.insert(list, { math.clamp(best.x, lo + sp.r, hi - sp.r), 0, best.y })
		end
	elseif sp.aim == "rand" then
		for i = 1, sp.n do
			local x = room.rng:NextNumber(lo + sp.r, hi - sp.r)
			table.insert(list, { x, if i > sp.n / 2 then sp.lag else 0 })
		end
	else
		return nil
	end
	g.spots = list
	return list
end

-- 패턴이 칠 때(방의 bossStrike가 zone · wave 다음에 부른다): 움켜쥐기 · 끌어오기 · 숨의 띠 · 구르는 바위
function Gim.strike(room, mob, p, heroes, events)
	local g = mob.lava
	if p.grab and g.grabAt then
		local G = p.grab
		local got = nil
		for _, h in heroes do
			if alive(h) and math.abs(h.x - g.grabAt[1]) <= G.r + HERO_W and math.abs(h.y - g.grabAt[2]) <= G.r + 18 then
				got = h
				break
			end
		end
		if got and not Buffs.guard(got) then
			local lo, hi = partOf(mob)
			-- 쥔 주먹의 자리(설계 grab.at = 그쪽으로 몇 점 · 바닥에서 몇 점 — 쳐든 주먹): 그 사람을 높이 들어 올린다
			local side = p.side or 1
			local at = G.at or { 92, 96 }
			local hx, hy = mob.x + side * at[1], mob.y - at[2]
			g.grab = { h = got, t = G.hold, tick = G.tick, def = G, freeLeft = (hi - lo) * G.free, x = hx, y = hy }
			g.grabSide = side
			got.x, got.y = hx, hy
			say(events, mob, "grab", { hero = got.id, x = hx, y = hy, t = G.hold })
		else
			say(events, mob, "grabMiss", {})
		end
		g.grabAt, g.grabAim = nil, nil
	end
	if p.pull and p.zone then
		-- 그러쥐기: 맞은 사람(띠 안 · 발이 낮은 사람)을 거인 발밑으로
		local x0, x1 = mob.x + mob.dir * p.zone.from, mob.x + mob.dir * p.zone.to
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		local px = mob.x + mob.dir * p.pull.to
		for _, h in heroes do
			if alive(h) and h.x >= lo - HERO_W and h.x <= hi + HERO_W and mob.y - h.y < p.zone.up and h.y <= mob.y + 4 then
				h.x = px
				table.insert(events, { type = "pull", hero = h.id, x = px })
			end
		end
	end
	if p.band then
		-- 끓는 숨: 그쪽으로 from ~ to(방 끝까지) · 발이 바닥에서 lo ~ hi점인 사람만(낮은 발판)
		local B = p.band
		local x0, x1 = mob.x + mob.dir * B.from, mob.x + mob.dir * B.to
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		for _, h in heroes do
			local up = mob.y - h.y
			if alive(h) and h.x >= lo - HERO_W and h.x <= hi + HERO_W and up >= B.lo and up <= B.hi then
				room:hurtHero(events, h, mob, p.mul)
			end
		end
	end
	if p.roll and g.spots and g.spots[1] then
		-- 떨어진 바위가 거인에게서 먼 쪽으로 구른다(물결 — 방의 waves가 옮기고 맞힌다)
		local sx = g.spots[1][1]
		local dir = if sx >= mob.x then 1 else -1
		room.waves = room.waves or {}
		table.insert(room.waves, { mob = mob, x = sx, y = mob.y, dir = dir, wait = 0, left = p.roll.range, def = { speed = p.roll.speed, w = p.roll.w, up = p.roll.up, range = p.roll.range }, mul = p.mul, hit = {} })
		say(events, mob, "roll", { x = sx, dir = dir, speed = p.roll.speed, range = p.roll.range })
	end
end

-- 거인이 받는 피해: 맞지 않는 때면 0 · 휘청 · 심장을 깬 뒤 x mul · 지금 부위의 아래 끝까지만(다 닳으면 페이즈가 바뀐다) · 움켜쥔 동안의 놓치게 하는 몫
function Gim.dmgIn(room, mob, dmg: number, events): number
	local g = mob.lava
	if not g then
		return dmg
	end
	if mob.hitBox == false or mob.state == "spawn" then
		return 0 -- (방에 들어서는 동안 — 손이 밀고 들어오는 · 몸통이 솟는 중)
	end
	local d = math.max(1, math.floor(dmg * g.mul + 0.5))
	if g.grab then
		g.grab.freeLeft -= d
	end
	local lo = partOf(mob)
	if mob.ph < #mob.def.story.gimmick.parts and mob.hp - d <= lo then
		d = math.max(0, math.ceil(mob.hp - lo))
		g.toShift = true
	end
	return d
end

-- 맞지 않는 때인가(방에 들어서는 중 · 손이 빠져나가는 중 · 가라앉았다) — 직접 맞히는 것(불새 · 표식)도 막는다
function Gim.immune(room, mob): boolean
	return mob.hitBox == false or mob.state == "spawn"
end

function Gim.hitMul(room, mob): number
	return 1
end

-- 방의 한 걸음(혹 · 심장의 상태를 고친다 — 맞아 멈칫한 것은 곧 다시 선다)
function Gim.tick(room, heroes, dt: number, events)
	local boss = room.lavaBoss
	if not boss or not boss.lava then
		return
	end
	for _, add in boss.adds do
		if add.hpAdd and not add.away then
			if add.state == "spawn" and add.t >= 0.6 then
				add.state, add.t = "idle", 0
			elseif add.state == "hit" and add.t >= 0.15 then
				add.state, add.t = "idle", 0
			end
		end
	end
end

-- 방에 들어서 선 뒤 맞지 않는 시간(손이 굴 끝에서 밀고 들어오는 · 몸통이 솟는 — 설계 gimmick.spawn[페이즈] · 방의 stepBoss가 본다)
function Gim.spawnTime(mob): number
	local S = mob.def.story.gimmick.spawn
	return (S and S[mob.ph or 1]) or 0.8
end

Gim.cancel = cancel
return Gim
