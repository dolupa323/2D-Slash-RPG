-- 셋째 보스전 「불씨 도둑 두목」의 기믹(2026-10-28 — 공방 design/bosses.js BOSS_GIMMICK.thiefboss · design/weekboss.js thiefboss.gimmick).
--  사용자: "오케이 불씨 도둑 두목으로 하고 여기서부터는 재밌는 기믹같은것도 넣어보자" → "다넣어보자" → "아니 바인드 잘거는것도 실력이야 그렇게 하고 기믹은 맘에든다 이대로 작업해보자"
--   ① 되받아치기: 두목이 던진 불씨 폭탄(졸개 thiefbomb — 체력 1 · 움직이지 않는다)은 땅에 떨어져 fuse초 뒤 터진다. 누구든 맞히면 두목에게 되날아가(back초) 터진다
--      → 휘청(stagger초 — 받는 피해 x mul · 하던 것을 거둔다) · 등의 단지 하나가 깨진다 · 두목 체력의 self만큼
--   ② 단지 털기: 등의 단지 n개 — 남은 단지 하나마다 두목이 받는 피해 −cut. 깨지면 「되찾은 불씨」가 바닥에 life초 — 밟으면 방의 모두에게 「화롯골의 불씨」(데미지 + · max까지 겹친다)
--      체력 refill의 각 비율에서 한 번씩: 포효 없이 뒤쪽 불씨 더미(stash)로 달려가 time초 동안 다시 채운다 — 그동안 되돌린 폭탄에 맞으면 하나만 채우고 휘청
--   ③ 연막 분신: 연기 속에서 셋 — 진짜에게 need번 맞히면 휘청, 가짜(졸개 thiefdecoy)를 치면 그을음이 터지고 친 사람의 화면이 blind초 어둡다,
--      time초가 지나도 못 찾으면 진짜가 겨눈 사람 둘레 세 자리에 불단지를 떨어뜨린다
--   + 낚아채기(hook): 갈고리가 곧게 날아가 처음 닿은 사람을 두목 앞으로 끌어오고 걸린 버프 하나를 턴다(두목이 boost초 동안 세진다)
--   + 큰 불단지(bigjar): 모으는 동안(예고) 작은 폭탄 tellBombs개를 던진다 — 그 폭탄을 되돌리면 휘청으로 끊기고(단지가 두목 위에서 깨져 체력의 jarSelf), 바인드도 끊는다
--  방(sim/room.luau)이 부른다: init(보스를 세울 때) · boss(보스의 한 걸음 — 휘청 · 다시 채우기 · 연막이 이끌면 true) · strike(패턴이 칠 때) · tick(방의 한 걸음) ·
--   dmgIn(두목이 받는 피해) · addHit(폭탄 · 가짜가 맞아 쓰러짐 — 경험치 · 물건 없음) · hitMul(두목이 치는 세기 — 턴 버프)
--  화면에 알리는 것: events { type = "gim", k = 무엇, ... } → 서버(world.luau)가 방에 "Gim"으로 · 끌어오기는 { type = "pull" } · 버프가 바뀌면 { type = "buffs" }
--  숫자는 모두 설계(weekboss.js)의 것. 바인드는 언제나 걸린다(사용자 "바인드 잘거는것도 실력이야" — 보스의 셈 room.luau가 먼저 본다)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local Buffs = require(script.Parent.buffs)

local Gim = {}
local HERO_W = 5

local function alive(h): boolean
	return h.alive and not h.inCine
end

-- 그 사람이 (x0 ~ x1) 땅의 띠(높이 up) 안에 있는가 — 두목이 선 땅(y) 기준
local function near(h, y: number, x0: number, x1: number, up: number): boolean
	return alive(h) and h.x >= x0 - HERO_W and h.x <= x1 + HERO_W and y - h.y < up and h.y <= y + 4
end

local function newAdd(room, boss, kind: string, role: string)
	local def = COMBAT.mobs[kind]
	local add = {
		id = #room.mobs + 1, kind = kind, def = def, lv = boss.lv, homeX = boss.x, y = boss.y, a = boss.a, b = boss.b, x = boss.x, dir = 1,
		state = "gone", t = 0, hp = 1, maxHp = 1, cd = 0, wait = 0, goal = boss.x, target = nil :: any, aggro = 0, struck = false, respawn = math.huge,
		add = true, away = true, gimAdd = role,
	}
	table.insert(room.mobs, add)
	table.insert(boss.adds, add)
	return add
end

function Gim.init(room, boss)
	local G = boss.def.story.gimmick
	if not G then
		return
	end
	boss.gim = { jars = G.jars.n, stagger = 0, done = {}, refill = nil, smoke = nil, stolen = -1e9, flying = {}, back = {}, bombs = {}, decoys = {} }
	for _ = 1, G.bomb.max do
		table.insert(boss.gim.bombs, newAdd(room, boss, G.bomb.kind, "bomb"))
	end
	for _ = 1, G.decoy.n do
		table.insert(boss.gim.decoys, newAdd(room, boss, G.decoy.kind, "decoy"))
	end
	room.embers = room.embers or {}
	room.hooks = room.hooks or {}
	room.gimN = room.gimN or 0
end

-- 방 전체에서 보스를 찾는다(폭탄 · 가짜의 주인)
local function owner(room, add)
	for _, m in room.bosses or {} do
		if m.gim then
			for _, a in m.adds do
				if a == add then
					return m
				end
			end
		end
	end
	return nil
end

-- 하던 것을 거둔다(예고 중이던 자리 · 연속기 · 뛰어오른 것) — 바인드와 같은 법
local function cancel(room, mob)
	if mob.state == "tell" then
		room:bossSpotsOff(mob)
	end
	mob.pat, mob.chain, mob.chainRest, mob.chainPat, mob.quick, mob.alt = 0, nil, nil, 0, 1, 0
end

-- 휘청: t초 · 하던 것을 거둔다
local function stagger(room, mob, t: number, events)
	local g = mob.gim
	cancel(room, mob)
	g.stagger = math.max(g.stagger, t)
	mob.state, mob.t = "stagger", 0
	table.insert(events, { type = "gim", k = "stagger", mob = mob.id, t = g.stagger })
end

-- 단지 하나가 깨진다 → 되찾은 불씨가 바닥에
local function breakJar(room, mob, events)
	local g, G = mob.gim, mob.def.story.gimmick
	if g.jars <= 0 then
		return
	end
	g.jars -= 1
	room.gimN += 1
	local x = math.clamp(mob.x - mob.dir * (20 + room.rng:NextNumber(0, 24)), mob.a, mob.b)
	local e = { id = room.gimN, x = x, y = mob.y, t = G.ember.life }
	table.insert(room.embers, e)
	table.insert(events, { type = "gim", k = "jar", mob = mob.id, jars = g.jars, ember = e.id, x = x, y = mob.y })
end

-- 폭탄 n개를 던진다(겨눈 사람들의 발밑 · 비어 있는 폭탄 자리만큼)
local function throwBombs(room, mob, n: number, mul: number, heroes, events)
	local G = mob.def.story.gimmick
	local targets = {}
	for _, h in heroes do
		if alive(h) then
			table.insert(targets, h)
		end
	end
	if #targets == 0 then
		return
	end
	local thrown = 0
	for _, add in mob.gim.bombs do
		if thrown >= n then
			break
		end
		if add.away and add.state == "gone" and not add.flying then
			thrown += 1
			local h = targets[(thrown - 1) % #targets + 1]
			local spread = if thrown > #targets then (room.rng:NextNumber(-1, 1) * G.bomb.spread) else room.rng:NextNumber(-0.3, 0.3) * G.bomb.spread
			local x = math.clamp(h.x + spread, mob.a + 8, mob.b - 8)
			add.x, add.homeX, add.y, add.flying, add.mul = x, x, mob.y, G.bomb.fly, mul
			add.fuse = G.bomb.fuse
			table.insert(events, { type = "gim", k = "throw", mob = mob.id, add = add.id, x0 = mob.x + mob.dir * 10, x = x, y = mob.y, t = G.bomb.fly })
		end
	end
end

-- 연막: 두목과 가짜 둘이 방의 세 자리로 흩어진다(두목은 그 가운데 아무 자리)
local function smokeStart(room, mob, events)
	local G = mob.def.story.gimmick
	local g = mob.gim
	local lo, hi = mob.a + 40, mob.b - 40
	local spots = {}
	local n = #g.decoys + 1
	for i = 1, n do
		spots[i] = lo + (hi - lo) * (i - 0.5) / n
	end
	local me = room.rng:NextInteger(1, n)
	mob.x = spots[me]
	local k = 0
	for i, x in spots do
		if i ~= me then
			k += 1
			local d = g.decoys[k]
			d.away, d.state, d.t, d.hp, d.x, d.homeX, d.y, d.dir = false, "idle", 0, 1, x, x, mob.y, mob.dir
			d.goal = x
		end
	end
	cancel(room, mob)
	g.smoke = { t = 0, hits = 0, home = mob.x, goal = mob.x }
	mob.state, mob.t = "sneak", 0 -- (패턴을 친 뒤 방의 셈이 "act"로 덮어도 다음 걸음에 Gim.boss가 되돌린다)
	table.insert(events, { type = "gim", k = "smoke", mob = mob.id, t = G.decoy.time, x = mob.x })
end

local function smokeEnd(room, mob, found: boolean, heroes, events)
	local G = mob.def.story.gimmick
	local g = mob.gim
	g.smoke = nil
	for _, d in g.decoys do
		if not d.away then
			d.away, d.state, d.t = true, "gone", 0
			table.insert(events, { type = "gim", k = "pop", add = d.id, x = d.x, y = d.y, quiet = true })
		end
	end
	table.insert(events, { type = "gim", k = "clear", mob = mob.id, found = found })
	if found then
		stagger(room, mob, G.decoy.stagger, events)
		return
	end
	-- 못 찾았다: 진짜가 연기 속에서 뛰어올라 겨눈 사람 둘레 세 자리에 불단지를 떨어뜨린다(BossPat의 표시된 자리처럼 — 예고 lag초 뒤 터진다)
	mob.state, mob.t, mob.rest = "idle", 0, 0.8
	local target
	for _, h in heroes do
		if alive(h) and (not target or math.abs(h.x - mob.x) < math.abs(target.x - mob.x)) then
			target = h
		end
	end
	if target then
		room.blasts = room.blasts or {}
		local D = G.decoy.drop
		for i = -1, 1 do
			local x = math.clamp(target.x + i * D.spread, mob.a, mob.b)
			table.insert(room.blasts, { mob = mob, x = x, y = mob.y, t = D.tell, def = D, mul = D.hit })
		end
		table.insert(events, { type = "gim", k = "drop", mob = mob.id, x = target.x, spread = D.spread, t = D.tell })
	end
end

-- 보스의 한 걸음 앞에서: 휘청 · 다시 채우기 · 연막이 이끌면 true(그 걸음은 여기서 끝)
function Gim.boss(room, mob, heroes, dt: number, events): boolean
	local g = mob.gim
	if not g then
		return false
	end
	local G = mob.def.story.gimmick
	-- 묶였다(바인드 — 기믹 동작 중에도 걸린다 · 사용자 "바인드 잘거는것도 실력이야"): 연막 속이면 진짜가 드러나고, 다시 채우던 중이면 끊긴다(채운 만큼 그대로). 서 있는 것은 방의 셈이 이끈다
	if (mob.bind or 0) > 0 then
		if g.smoke then
			smokeEnd(room, mob, true, heroes, events)
		end
		if g.refill then
			g.refill = nil
			table.insert(events, { type = "gim", k = "filled", mob = mob.id, jars = g.jars })
		end
		if g.stagger > 0 then
			g.stagger = math.max(0, g.stagger - dt)
		end
		return false
	end
	if g.stagger > 0 then
		g.stagger = math.max(0, g.stagger - dt)
		if g.stagger <= 0 then
			mob.state, mob.t, mob.rest = "idle", 0, 0.6
			table.insert(events, { type = "gim", k = "recover", mob = mob.id })
		end
		return true
	end
	if g.smoke then
		-- 진짜도 가짜와 똑같이 제자리 둘레를 천천히 걷는다(서 있으면 바로 티가 난다 — 그림도 같은 걷기 · 같은 빠르기)
		local s = g.smoke
		s.t += dt
		if math.abs(s.goal - mob.x) < 2 then
			s.goal = math.clamp(s.home + room.rng:NextNumber(-30, 30), mob.a, mob.b)
		end
		mob.dir = if s.goal > mob.x then 1 else -1
		mob.x += mob.dir * math.min(math.abs(s.goal - mob.x), G.decoy.walk * dt)
		mob.state = "sneak"
		if s.t >= G.decoy.time then
			smokeEnd(room, mob, false, heroes, events)
		end
		return true
	end
	if g.refill then
		local r = g.refill
		if r.phase == "go" then
			-- 뒤쪽 불씨 더미로 달려간다
			local dx = G.jars.stash - mob.x
			if math.abs(dx) <= 4 then
				r.phase, r.t = "fill", 0
				mob.state, mob.t = "refill", 0
				mob.dir = if dx ~= 0 then (if dx > 0 then 1 else -1) else mob.dir
			else
				mob.dir = if dx > 0 then 1 else -1
				mob.x += mob.dir * math.min(math.abs(dx), G.jars.run * dt)
				mob.state = "walk"
			end
		else
			r.t += dt
			if r.t >= G.jars.time then
				g.jars = G.jars.n
				g.refill = nil
				mob.state, mob.t, mob.rest = "idle", 0, 0.5
				table.insert(events, { type = "gim", k = "filled", mob = mob.id, jars = g.jars })
			end
		end
		return true
	end
	-- 다시 채우기를 시작한다: 쉬고 있을 때(패턴 중이 아닐 때) · 체력이 그 비율 아래로
	if mob.state == "idle" then
		for i, at in G.jars.refill do
			if not g.done[i] and mob.hp <= mob.maxHp * at then
				g.done[i] = true
				if g.jars < G.jars.n then
					g.refill = { phase = "go", t = 0 }
					table.insert(events, { type = "gim", k = "refill", mob = mob.id, x = G.jars.stash })
					return true
				end
			end
		end
	end
	-- 큰 불단지를 모으는 동안: 작은 폭탄을 던진다(되돌려 맞히면 휘청으로 끊긴다)
	if mob.state == "tell" then
		local p = mob.def.story.patterns[mob.pat]
		if p and p.bigjar and not mob.jarThrown and mob.t >= p.bigjar.throwAt then
			mob.jarThrown = true
			throwBombs(room, mob, p.bigjar.bombs, p.mul, heroes, events)
		end
	else
		mob.jarThrown = nil
	end
	return false
end

-- 패턴이 칠 때(예고가 끝난 때)
function Gim.strike(room, mob, p, heroes, events)
	if not mob.gim then
		return
	end
	if p.bombs then
		throwBombs(room, mob, p.bombs.n, p.mul, heroes, events)
	end
	if p.hook then
		room.gimN += 1
		local x = mob.x + mob.dir * 16
		table.insert(room.hooks, { id = room.gimN, mob = mob, x = x, dir = mob.dir, left = p.hook.range, def = p.hook, mul = p.mul })
		table.insert(events, { type = "gim", k = "hook", mob = mob.id, id = room.gimN, x = x, y = mob.y - p.hook.at, dir = mob.dir, speed = p.hook.speed, range = p.hook.range })
	end
	if p.decoy then
		smokeStart(room, mob, events)
	end
	if p.bigjar then
		table.insert(events, { type = "gim", k = "bigjar", mob = mob.id, x = mob.x }) -- 방 전체가 터진다(맞는 것은 zone)
	end
end

-- 되돌린 폭탄이 두목에게 닿았다
local function backHit(room, mob, events)
	local G = mob.def.story.gimmick
	local g = mob.gim
	local self = math.floor(mob.maxHp * G.bomb.self + 0.5)
	local jarCut = mob.state == "tell" and mob.def.story.patterns[mob.pat] and mob.def.story.patterns[mob.pat].bigjar
	if jarCut then
		self += math.floor(mob.maxHp * jarCut.self + 0.5) -- 큰 불단지가 두목 위에서 깨졌다
	end
	if self > 0 and mob.hp > self then
		mob.hp -= self
	end
	table.insert(events, { type = "gim", k = "backhit", mob = mob.id, x = mob.x, dmg = self, jar = jarCut ~= nil })
	if g.refill and g.refill.phase == "fill" then
		g.jars = math.min(G.jars.n, g.jars + 1) -- 채우던 중이면 하나만 채우고 끝난다
		g.refill = nil
		table.insert(events, { type = "gim", k = "filled", mob = mob.id, jars = g.jars })
	elseif g.refill then
		g.refill = nil
	end
	breakJar(room, mob, events)
	stagger(room, mob, if jarCut then G.stagger.jar else G.stagger.time, events)
end

-- 방의 한 걸음(폭탄의 도화선 · 되날아가는 폭탄 · 갈고리 · 되찾은 불씨 · 가짜의 걸음)
function Gim.tick(room, heroes, dt: number, events)
	for _, mob in room.bosses or {} do
		local g = mob.gim
		if not g or mob.state == "gone" then
			continue
		end
		local G = mob.def.story.gimmick
		if mob.state == "dead" then
			-- 쓰러지면 남은 폭탄 · 가짜가 사라진다
			for _, a in mob.adds do
				if a.gimAdd and not a.away then
					a.away, a.state, a.t, a.flying = true, "gone", 0, nil
				end
			end
			continue
		end
		-- 1초마다 남은 단지 수 · 연막 중인가를 알린다(화면이 머리 위에 남은 단지를 그린다 — 늦게 들어온 사람도 1초 안에 맞춘다)
		g.beat = (g.beat or 0) - dt
		if g.beat <= 0 then
			g.beat = 1
			table.insert(events, { type = "gim", k = "jars", mob = mob.id, jars = g.jars, smoke = g.smoke ~= nil })
		end
		for _, add in g.bombs do
			if add.flying then
				add.flying -= dt
				if add.flying <= 0 then
					add.flying = nil
					add.away, add.state, add.t, add.hp = false, "idle", 0, 1
				end
			elseif not add.away and add.state ~= "dead" then
				add.fuse -= dt
				if add.fuse <= 0 then
					-- 터진다
					for _, h in heroes do
						if near(h, add.y, add.x - G.bomb.r, add.x + G.bomb.r, G.bomb.up) then
							room:hurtHero(events, h, mob, G.bomb.hit)
						end
					end
					add.away, add.state, add.t = true, "gone", 0
					table.insert(events, { type = "gim", k = "boom", add = add.id, x = add.x, y = add.y })
				end
			end
		end
		for i = #g.back, 1, -1 do
			local b = g.back[i]
			b.t -= dt
			if b.t <= 0 then
				table.remove(g.back, i)
				if mob.hp > 0 then
					backHit(room, mob, events)
				end
			end
		end
		-- 가짜는 제자리 둘레를 천천히 걷는다(진짜도 연막 동안 같은 빠르기로 — Gim.boss)
		if g.smoke then
			for _, d in g.decoys do
				if not d.away then
					if math.abs(d.goal - d.x) < 2 then
						d.goal = math.clamp(d.homeX + room.rng:NextNumber(-30, 30), mob.a, mob.b)
					end
					d.dir = if d.goal > d.x then 1 else -1
					d.x += d.dir * math.min(math.abs(d.goal - d.x), G.decoy.walk * dt)
					d.state = "run" -- (졸개가 걷는 상태 — 화면이 걷기 그림을 튼다)
				end
			end
		end
	end
	-- 갈고리: 곧게 날아가 처음 닿은 사람을 끌어온다
	for i = #(room.hooks or {}), 1, -1 do
		local k = room.hooks[i]
		local step = k.def.speed * dt
		k.x += k.dir * step
		k.left -= step
		local got = nil
		for _, h in heroes do
			if near(h, k.mob.y, k.x - 8, k.x + 8, k.def.up) then
				got = h
				break
			end
		end
		if got then
			room:hurtHero(events, got, k.mob, k.mul)
			local px = math.clamp(k.mob.x + k.mob.dir * k.def.pull, k.mob.a, k.mob.b)
			got.x = px
			table.insert(events, { type = "pull", hero = got.id, x = px })
			-- 걸린 버프 하나를 턴다(보스 기믹의 버프는 빼고)
			local ids = {}
			for id, b in got.buffs do
				if b.t > 0 and not (Buffs.data[id] and Buffs.data[id].gim) then
					table.insert(ids, id)
				end
			end
			if #ids > 0 then
				table.sort(ids)
				local id = ids[room.rng:NextInteger(1, #ids)]
				got.buffs[id] = nil
				k.mob.gim.stolen = room.time + k.def.boost.time
				table.insert(events, { type = "buffs", hero = got.id })
				table.insert(events, { type = "gim", k = "steal", mob = k.mob.id, hero = got.id, buff = id })
			end
		end
		if got or k.left <= 0 then
			table.remove(room.hooks, i)
			table.insert(events, { type = "gim", k = "hookEnd", id = k.id, hero = got and got.id or nil })
		end
	end
	-- 되찾은 불씨: 밟으면 방의 모두에게 「화롯골의 불씨」(겹친다)
	for i = #(room.embers or {}), 1, -1 do
		local e = room.embers[i]
		e.t -= dt
		local by = nil
		for _, h in heroes do
			if alive(h) and math.abs(h.x - e.x) <= 12 and math.abs(h.y - e.y) <= 24 then
				by = h
				break
			end
		end
		if by then
			local boss = room.bosses and room.bosses[1]
			local G = boss and boss.def.story.gimmick
			if G then
				for _, h in heroes do
					if h.alive then
						local had = h.buffs[G.ember.buff]
						local pow = math.min(G.ember.max, (if had and had.t > 0 then had.pow else 0) + 1)
						Buffs.give(h, G.ember.buff, pow, e.x, e.y)
						table.insert(events, { type = "buffs", hero = h.id })
					end
				end
			end
			table.remove(room.embers, i)
			table.insert(events, { type = "gim", k = "ember", id = e.id, hero = by.id })
		elseif e.t <= 0 then
			table.remove(room.embers, i)
			table.insert(events, { type = "gim", k = "emberGone", id = e.id })
		end
	end
end

-- 두목이 받는 피해: 남은 단지 하나마다 −cut · 휘청이면 x mul. 연막 동안 진짜를 맞힌 수를 센다
function Gim.dmgIn(room, mob, dmg: number, events): number
	local g = mob.gim
	if not g then
		return dmg
	end
	local G = mob.def.story.gimmick
	local mul = (1 - G.jars.cut * g.jars) * (if g.stagger > 0 then G.stagger.mul else 1)
	if g.smoke then
		g.smoke.hits += 1
		if g.smoke.hits >= G.decoy.need then
			smokeEnd(room, mob, true, nil, events)
		end
	end
	return math.max(1, math.floor(dmg * mul + 0.5))
end

-- 두목이 치는 세기의 배수: 털어 간 버프로 boost초 동안 +
function Gim.hitMul(room, mob): number
	local g = mob.gim
	if g and g.stolen > room.time then
		for _, p in mob.def.story.patterns do
			if p.hook then
				return 1 + p.hook.boost.dmg
			end
		end
	end
	return 1
end

-- 폭탄 · 가짜가 맞아 쓰러졌다(경험치 · 물건 · 퀘스트의 숫자 없음)
function Gim.addHit(room, hero, add, events)
	local boss = owner(room, add)
	add.away, add.state, add.t, add.flying = true, "gone", 0, nil
	if not boss then
		return
	end
	local G = boss.def.story.gimmick
	if add.gimAdd == "bomb" then
		table.insert(boss.gim.back, { t = G.bomb.back })
		table.insert(events, { type = "gim", k = "bat", add = add.id, x = add.x, y = add.y, to = boss.x, toY = boss.y, t = G.bomb.back, hero = hero.id })
	elseif add.gimAdd == "decoy" then
		table.insert(events, { type = "gim", k = "pop", add = add.id, x = add.x, y = add.y, hero = hero.id, blind = G.decoy.blind })
	end
end

Gim.cancel = cancel
return Gim
