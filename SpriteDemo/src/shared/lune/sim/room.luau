-- 맵 한 곳의 싸움 — 졸개의 움직임과 공격, 기술의 판정, 잡았을 때의 보상, 떨어진 것. 화면 · 네트워크와 상관없는 셈만 한다(서버가 쓴다).
--  수치는 data/combat.generated.luau(공방 js/lune/design/combat.js)와 config/numbers.luau에서 온다.
--  졸개는 제 발판의 범위(range) 안에서만 움직인다(뛰어내리지 않는다). 좌표는 도트, (x, y)는 발밑 가운데.
--  heroes = { [id] = sim/hero.luau의 캐릭터 } — 이 방에 있는 사람들.
local N = require(script.Parent.Parent.config.numbers)
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local Hero = require(script.Parent.hero)
local Items = require(script.Parent.items)
local Bag = require(script.Parent.bag)
local Party = require(script.Parent.party)
local Physics = require(script.Parent.physics)
local RULES = COMBAT.rules

local SEE_Y = 28 -- 이만큼 높이가 다르면 알아채지 못한다(다른 층)
local BODY_W, BODY_H = 6, 14 -- 졸개의 몸(반폭, 높이)
local HERO_W, HERO_H = 5, 17
local SPAWN_TIME, DEAD_TIME = 0.8, 0.9
local BIG_HIT = 1.4 -- 센 타격: 세기 배수가 이만큼 넘는 타(대지 강타의 내려찍기 1.43 · 삼단 베기의 셋째 타 2.05 같은 것). 그 숫자는 직업의 밝은 색으로 뜬다(공방 시험 탭의 "12 넘는 피해"에 해당)

local Room = {}
Room.__index = Room

function Room.new(key: string, scene, rng)
	local self = setmetatable({}, Room)
	self.key = key
	self.scene = scene
	self.rng = rng
	self.time = 0
	self.mobs = {}
	self.shots = {}
	self.drops = {}
	self.nextId = 1
	for _, def in scene.mobs do
		local kind = COMBAT.mobs[def.kind]
		-- 피해 숫자의 배율(dmgScale)과 쓰임의 보정(targetBonus — 맞는 갈래의 기술은 피해가 그만큼 더 뜬다)만큼 체력도 크다: 맞는 기술로 잡는 타수는 그대로다
		local maxHp = math.max(1, math.floor(N.mobHp(def.lv) * kind.hp * RULES.dmgScale * (1 + RULES.targetBonus / 100) + 0.5))
		local mob = {
			id = #self.mobs + 1,
			kind = def.kind,
			def = kind,
			lv = def.lv,
			homeX = def.x,
			y = def.y,
			a = def.range[1],
			b = def.range[2],
			x = def.x,
			dir = if #self.mobs % 2 == 0 then 1 else -1,
			state = "spawn",
			t = 0,
			hp = maxHp,
			maxHp = maxHp,
			cd = 0,
			wait = rng:NextNumber(0, 1.5),
			goal = def.x,
			target = nil :: any,
			aggro = 0,
			struck = false,
			respawn = 0,
		}
		table.insert(self.mobs, mob)
	end
	return self
end

local function sign(v: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else 0
end

local function canSee(mob, h, range: number): boolean
	return h.alive and math.abs(h.y - mob.y) <= SEE_Y and math.abs(h.x - mob.x) <= range
end

-- 가장 가까운, 알아챌 수 있는 사람
function Room:findTarget(mob, heroes)
	local best, bestD = nil, math.huge
	for id, h in heroes do
		local range = if mob.target == id then mob.def.see * 1.6 else mob.def.see
		if canSee(mob, h, range) then
			local d = math.abs(h.x - mob.x)
			if d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best
end

-- 졸개가 사람을 친다. 들어간 피해가 있으면 일(hurt)을 적는다.
function Room:hurtHero(events, h, mob, mul: number)
	local raw = N.rawHit("mob", mob.lv) * (1 - Hero.cut(h, mob.lv) / 100) * mul -- 끼고 있는 방어구만큼 덜 아프다
	local dmg = Hero.hurt(h, raw)
	if dmg > 0 then
		table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = mob.x, dead = not h.alive })
	end
end

function Room:stepMob(mob, heroes, dt: number, events)
	local def, atk = mob.def, mob.def.atk
	mob.t += dt
	mob.cd = math.max(0, mob.cd - dt)

	if mob.state == "gone" then
		mob.respawn -= dt
		if mob.respawn <= 0 then
			mob.state, mob.t, mob.x, mob.hp, mob.target, mob.cd = "spawn", 0, mob.homeX, mob.maxHp, nil, 0
		end
		return
	elseif mob.state == "dead" then
		if mob.t >= DEAD_TIME then
			mob.state, mob.respawn = "gone", RULES.respawn
		end
		return
	elseif mob.state == "spawn" then
		if mob.t >= SPAWN_TIME then
			mob.state, mob.t = "idle", 0
		end
		return
	elseif mob.state == "hit" then
		if mob.t >= RULES.stagger then
			mob.state, mob.t = "idle", 0
		end
		return
	elseif mob.state == "atk" then
		local target = mob.target and heroes[mob.target]
		if not mob.struck and mob.t >= atk.windup then
			mob.struck = true
			if atk.shot then
				-- 화살: 보는 쪽으로 곧게 날아간다
				local shot = { id = self.nextId, x = mob.x + mob.dir * 8, y = mob.y - 9, dir = mob.dir, speed = atk.shot.speed, left = atk.shot.range, mob = mob }
				self.nextId += 1
				table.insert(self.shots, shot)
				table.insert(events, { type = "shot", id = shot.id, x = shot.x, y = shot.y, dir = shot.dir, speed = shot.speed, range = shot.left })
			elseif atk.burst then
				-- 터진다: 둘레의 사람이 모두 맞고, 졸개는 사라진다(잡은 것으로 치지 않는다)
				for _, h in heroes do
					if h.alive and math.abs(h.x - mob.x) <= atk.burst and math.abs(h.y - mob.y) <= atk.burst then
						self:hurtHero(events, h, mob, atk.mul)
					end
				end
				mob.state, mob.t, mob.hp, mob.target = "dead", 0, 0, nil
				table.insert(events, { type = "burst", mob = mob.id, x = mob.x, y = mob.y })
				return
			elseif target and target.alive then
				local dx = (target.x - mob.x) * mob.dir
				if dx >= -6 and dx <= atk.reach + 6 and math.abs(target.y - mob.y) <= atk.up then
					self:hurtHero(events, target, mob, atk.mul)
				end
			end
		end
		if mob.t >= atk.time then
			mob.state, mob.t, mob.cd = "idle", 0, atk.cd
		end
		return
	end

	-- 서 있기 · 어슬렁 · 쫓기
	mob.aggro = math.max(0, mob.aggro - dt)
	local targetId = self:findTarget(mob, heroes)
	if not targetId and mob.aggro > 0 and mob.target and heroes[mob.target] and heroes[mob.target].alive then
		targetId = mob.target -- 맞았으면 멀리 있어도 한동안 쫓는다
	end
	mob.target = targetId
	local target = targetId and heroes[targetId]
	if target then
		local dx = target.x - mob.x
		if dx ~= 0 then
			mob.dir = sign(dx)
		end
		local sameFloor = math.abs(target.y - mob.y) <= atk.up
		if mob.cd <= 0 and sameFloor and math.abs(dx) <= atk.reach * 0.9 then
			mob.state, mob.t, mob.struck = "atk", 0, false
			return
		end
		if def.chase > 0 and math.abs(dx) > atk.reach * 0.6 then
			mob.x = math.clamp(mob.x + mob.dir * def.chase * dt, mob.a, mob.b)
			mob.state = "run"
		else
			mob.state = "idle"
		end
		return
	end
	-- 어슬렁: 잠깐 서 있다가 범위 안의 다른 자리로 걷는다
	if mob.wait > 0 then
		mob.wait -= dt
		mob.state = "idle"
		if mob.wait <= 0 then
			mob.goal = self.rng:NextNumber(mob.a, mob.b)
		end
		return
	end
	local dx = mob.goal - mob.x
	if math.abs(dx) < 1 then
		mob.wait = self.rng:NextNumber(0.6, 2.2)
		mob.state = "idle"
	else
		mob.dir = sign(dx)
		mob.x += mob.dir * math.min(def.speed * dt, math.abs(dx))
		mob.state = "run"
	end
end

-- 한 걸음. 일어난 일의 목록을 돌려준다: hurt(사람이 맞음) · shot(화살이 생김) · shotEnd · burst(폭탄병이 터짐)
function Room:step(heroes, dt: number)
	local events = {}
	self.time += dt
	for _, mob in self.mobs do
		self:stepMob(mob, heroes, dt, events)
	end
	-- 화살
	for i = #self.shots, 1, -1 do
		local s = self.shots[i]
		local move = s.speed * dt
		s.x += s.dir * move
		s.left -= move
		local done = s.left <= 0 or Physics.cell(self.scene, math.floor(s.x / 16), math.floor(s.y / 16)) == "#"
		if not done then
			for _, h in heroes do
				if h.alive and math.abs(h.x - s.x) <= HERO_W + 2 and s.y <= h.y and s.y >= h.y - HERO_H then
					self:hurtHero(events, h, s.mob, s.mob.def.atk.mul)
					done = true
					break
				end
			end
		end
		if done then
			table.insert(events, { type = "shotEnd", id = s.id })
			table.remove(self.shots, i)
		end
	end
	-- 떨어진 것: 오래되면 사라진다
	for id, d in self.drops do
		if self.time - d.born >= RULES.dropLife then
			self.drops[id] = nil
			table.insert(events, { type = "dropGone", id = id })
		end
	end
	return events
end

-- 상자(x0~x1, y0~y1)에 걸리는 살아 있는 졸개들(가까운 것부터, RULES.maxTargets마리까지)
function Room:mobsInBox(x0: number, x1: number, y0: number, y1: number, cx: number)
	local list = {}
	for _, mob in self.mobs do
		if mob.state ~= "dead" and mob.state ~= "gone" and mob.state ~= "spawn" then
			if mob.x + BODY_W >= x0 and mob.x - BODY_W <= x1 and mob.y >= y0 and mob.y - BODY_H <= y1 then
				table.insert(list, mob)
			end
		end
	end
	table.sort(list, function(p, q)
		return math.abs(p.x - cx) < math.abs(q.x - cx)
	end)
	for i = #list, RULES.maxTargets + 1, -1 do
		list[i] = nil
	end
	return list
end

-- 졸개가 맞는다. 쓰러졌으면 true.
function Room:damageMob(mob, dmg: number, fromX: number, byId: any): boolean
	mob.hp = math.max(0, mob.hp - dmg)
	mob.target, mob.aggro = byId, 5
	if mob.hp <= 0 then
		mob.state, mob.t, mob.target = "dead", 0, nil
		return true
	end
	-- 멈칫한다(터지려는 폭탄병은 멈추지 않는다) · 조금 밀린다
	if not (mob.state == "atk" and mob.def.atk.burst) then
		mob.state, mob.t = "hit", 0
	end
	mob.x = math.clamp(mob.x + sign(mob.x - fromX) * 3, mob.a, mob.b)
	return false
end

-- 기술의 한 타. hero가 (x, y)에서 dir 쪽을 보고 쓴 기술의 hit(판정 하나)를 푼다. scale = 스킬 레벨에 따른 세기(없으면 1).
--  mates = 경험치를 함께 나눌 사람들(hero도 든다 — 같은 맵의 파티원. 없으면 혼자). 떨어진 것은 그 사람들도 바로 주울 수 있다.
--  돌려주는 것: { hits = { { mob, dmg, hp, dead, big } … }, kills = { { mob, xp, ups, gains = { { hero, xp, ups, level } … }, drop, loot } … } }
--  kind = 그 기술의 갈래: 사냥기("mob")는 일반 몬스터에게, 보스기("boss")는 보스에게 피해가 targetBonus% 더 뜬다 — 맞지 않는 상대에게는 그 보정이 없다(체력은 보정만큼 크다)
--   (사용자 2026-10-07: "보스기는 보스 공격시 추가데미지, 사냥기는 일반 몹 공격시 추가 데미지 … 지금 그냥 보스기로 사냥하는게 더빠른현상이 생깁니다")
function Room:skillHit(hero, hit, x: number, y: number, dir: number, scale: number?, mates, kind: string?)
	local box = hit.box
	local xa, xb = x + dir * box[1], x + dir * box[2]
	local x0, x1 = math.min(xa, xb), math.max(xa, xb)
	local power = Hero.powerRaw(hero) -- 반올림하지 않은 전투력으로 셈한다(능력치 1점도 피해에 들어간다)
	local out = { hits = {}, kills = {} }
	for _, mob in self:mobsInBox(x0, x1, y - box[3], y + box[4], x) do
		local roll = 1 + self.rng:NextNumber(-RULES.spread, RULES.spread) / 100
		-- 가운데 타에 이미 맞은 적은 빼는 타(hit.except = 그 범위): 한 적이 같은 것을 두 번 맞지 않는다
		if hit.except then
			local e = hit.except
			local ea, eb = x + dir * e[1], x + dir * e[2]
			if mob.x + BODY_W >= math.min(ea, eb) and mob.x - BODY_W <= math.max(ea, eb) and mob.y >= y - e[3] and mob.y - BODY_H <= y + e[4] then
				continue
			end
		end
		-- 쓰임의 보정: 사냥기는 일반 몬스터에게, 보스기는 보스에게 피해가 targetBonus% 더 뜬다(다른 갈래의 기술은 누구에게나 뜬다). 맞지 않는 상대에게는 보정이 없다
		local fit = if (kind == "mob" and mob.def.boss) or (kind == "boss" and not mob.def.boss) then 1 else 1 + RULES.targetBonus / 100
		local dmg = math.max(1, math.floor(power * hit.mul * (scale or 1) * roll * RULES.dmgScale * fit + 0.5)) -- dmgScale = 피해 숫자의 배율(올린 만큼 숫자로 보이게 — 공방 combat.js)
		local dead = self:damageMob(mob, dmg, x, hero.id)
		if not dead and (hit.pull or 0) > 0 then
			-- 끌어온다: 쓴 사람 쪽으로(제 범위 안에서만)
			local toward = if mob.x > x then -1 else 1
			mob.x = math.clamp(mob.x + toward * math.min(hit.pull, math.max(0, math.abs(mob.x - x) - 10)), mob.a, mob.b)
		end
		table.insert(out.hits, { mob = mob.id, dmg = dmg, hp = mob.hp, dead = dead, big = if hit.mul >= BIG_HIT then true else nil })
		if dead then
			local list = mates or { hero }
			local share = Party.share(#list)
			local gains, myXp, myUps = {}, 0, 0
			for _, mate in list do
				-- 사람마다 제 레벨 차이 · 벌칙을 넣은 경험치에 나눈 몫을 곱한다
				local xp = math.max(1, math.floor(Hero.killXp(mate, mob.lv, mob.def.hp) * share + 0.5))
				local ups = Hero.gainXp(mate, xp)
				table.insert(gains, { hero = mate.id, xp = xp, ups = ups, level = mate.level })
				if mate == hero then
					myXp, myUps = xp, ups
				end
			end
			local drop, loot = self:dropFor(hero, mob), self:lootFor(hero, mob)
			if #list > 1 then
				local friends = {}
				for _, mate in list do
					friends[mate.id] = true
				end
				if drop then
					drop.friends = friends
				end
				for _, d in loot do
					d.friends = friends
				end
			end
			table.insert(out.kills, { mob = mob.id, kind = mob.kind, x = mob.x, y = mob.y, xp = myXp, ups = myUps, gains = gains, drop = drop, loot = loot })
		end
	end
	return out
end

-- 잡은 졸개가 떨어뜨리는 달돈(열에 여섯). 장비와 달가루는 lootFor.
function Room:dropFor(hero, mob)
	if self.rng:NextNumber(0, 100) >= N.data.COIN.chance then
		return nil
	end
	local base = N.killMoney(mob.lv) * mob.def.hp / (N.data.COIN.chance / 100)
	local amount = base * (1 + self.rng:NextNumber(-RULES.moneySpread, RULES.moneySpread) / 100)
	if hero.weak > 0 then
		amount *= 1 - N.data.BODY.death.cut / 100
	end
	local drop = { id = self.nextId, kind = "money", amount = math.max(1, math.floor(amount + 0.5)), x = mob.x, y = mob.y, owner = hero.id, born = self.time }
	self.nextId += 1
	self.drops[drop.id] = drop
	return drop
end

-- 잡은 졸개가 떨어뜨리는 장비와 달가루(없으면 빈 표). 쓰러진 뒤의 벌칙 동안에는 덜 나온다.
function Room:lootFor(hero, mob)
	local out = {}
	local mul = if hero.weak > 0 then 1 - N.data.BODY.death.cut / 100 else 1
	local item = Items.rollDrop(self.rng, mob.lv, hero.class, mul)
	if item then
		table.insert(out, self:addDrop({ kind = "gear", item = item, amount = 1 }, mob.x + (#out + 1) * 9, mob.y, hero.id))
	end
	local dust = Items.rollDust(self.rng, mob.lv, mul)
	if dust then
		table.insert(out, self:addDrop({ kind = "dust", amount = dust }, mob.x + (#out + 1) * 9, mob.y, hero.id))
	end
	return out
end

-- 물건 하나를 (x, y)에 떨어뜨린다. owner = 얼마 동안 혼자 주울 수 있는 사람
function Room:addDrop(drop, x: number, y: number, owner: any)
	drop.id, drop.x, drop.y, drop.owner, drop.born = self.nextId, x, y, owner, self.time
	self.nextId += 1
	self.drops[drop.id] = drop
	return drop
end

-- 방 사람들에게 알릴 때의 꼴(떨어진 것 하나)
function Room.dropView(d)
	return { id = d.id, kind = d.kind, amount = d.amount, x = d.x, y = d.y, name = d.name, icon = d.icon, item = if d.item then { slot = d.item.slot, stage = d.item.stage, q = d.item.q, star = d.item.star, who = d.item.who } else nil }
end

-- 줍는다. 주웠으면 그 물건을, 아니면 nil과 까닭을 돌려준다.
function Room:pickup(hero, dropId: number)
	local d = self.drops[dropId]
	if not d then
		return nil, "없음"
	end
	if not hero.alive then
		return nil, "쓰러짐"
	end
	if math.abs(d.x - hero.x) > RULES.pickup or math.abs(d.y - hero.y) > RULES.pickup + 12 then
		return nil, "멀다"
	end
	if d.owner ~= hero.id and not (d.friends and d.friends[hero.id]) and self.time - d.born < RULES.dropOwn then
		return nil, "남의 것"
	end
	-- 퀘스트의 물건은 그 퀘스트를 하는 사람의 것이다(시간이 지나도 남이 줍지 못한다). 숫자를 올리는 것은 부른 쪽(Quests.onLoot)
	if d.kind == "quest" and d.owner ~= hero.id then
		return nil, "남의 것"
	end
	if d.kind == "gear" then
		local ok, why = Bag.add(hero, d.item)
		if not ok then
			return nil, why
		end
	elseif d.kind == "dust" then
		hero.dust += d.amount
	elseif d.kind == "money" then
		hero.money += d.amount
	end
	self.drops[dropId] = nil
	return d
end

-- 지금 졸개들의 모습(화면에 그릴 것만)
function Room:snapshot()
	local list = {}
	for i, mob in self.mobs do
		list[i] = { mob.id, math.floor(mob.x * 10 + 0.5) / 10, mob.dir, mob.state, math.floor(mob.t * 100 + 0.5) / 100, mob.hp }
	end
	return list
end

-- 방에 들어온 사람에게 한 번 주는 것(졸개의 종류 · 레벨 · 체력, 떨어져 있는 것). heroId = 그 사람 — 남의 퀘스트 물건은 보여 주지 않는다
function Room:describe(heroId: any?)
	local mobs, drops = {}, {}
	for i, mob in self.mobs do
		mobs[i] = { id = mob.id, kind = mob.kind, lv = mob.lv, y = mob.y, maxHp = mob.maxHp, name = mob.def.name }
	end
	for _, d in self.drops do
		if d.kind == "quest" and d.owner ~= heroId then
			continue
		end
		table.insert(drops, Room.dropView(d))
	end
	return { key = self.key, mobs = mobs, drops = drops, snap = self:snapshot() }
end

return Room
