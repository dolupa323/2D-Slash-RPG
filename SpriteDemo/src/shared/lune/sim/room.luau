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
local Kit = require(script.Parent.kit)
local Buffs = require(script.Parent.buffs)
local Caster = require(script.Parent.caster) -- 2~4차의 쓰는 스킬(직업 묶음의 그 스킬을 방이 돌린다)
local Passives = require(script.Parent.passives) -- 2~4차의 패시브
local Quests = require(script.Parent.quests) -- 스토리 보스: 그 퀘스트를 하는 사람이 있을 때만 선다
local BossPat = require(script.Parent.bosspat) -- 스토리 보스: 표시된 자리 · 도약 · 물결의 자리와 시간(화면과 같은 셈)
local RULES = COMBAT.rules
local CASTRULE = COMBAT.castRule
local KIT = COMBAT.kit
local UP = COMBAT.kitUp -- 사출기 강화(2~4차 패시브)
local PLACED = COMBAT.placed -- 설치 · 소환 -- 1차의 온오프 사출기 · 핵심 장치 · 패시브(직업마다 — sim/kit.luau)

local SEE_Y = 28 -- 이만큼 높이가 다르면 알아채지 못한다(다른 층)
local BODY_W, BODY_H = 6, 14 -- 졸개의 몸(반폭, 높이) — 병사
-- 새 몬스터는 종류마다 몸이 다르다(def.body = { 폭, 높이 } · def.lift = 그림이 땅에서 뜬 높이). 나는 몬스터는 지금 높이(mob.alt)만큼 더 떠 있다.
-- 돌려주는 것: 반폭, 몸의 아래 끝이 발밑(y)에서 위로 얼마, 몸의 높이
local function bodyOf(mob): (number, number, number)
	local b = mob.def.body
	if b then
		return b[1] / 2, (mob.def.lift or 0) + (mob.alt or 0), b[2]
	end
	return BODY_W, 0, BODY_H
end
local HERO_W, HERO_H = 5, 17
local SPAWN_TIME, DEAD_TIME = 0.8, 0.9
local STEP_TIME = 0.25 -- 스토리 보스가 치면서 내딛는 걸음에 걸리는 시간(초)
local BIG_HIT = 1.4 -- 센 타격: 세기 배수가 이만큼 넘는 타(대지 강타의 내려찍기 1.43 · 삼단 베기의 셋째 타 2.05 같은 것). 그 숫자는 직업의 밝은 색으로 뜬다(공방 시험 탭의 "12 넘는 피해"에 해당)

local Room = {}
Room.__index = Room
Room.bodyOf = bodyOf

function Room.new(key: string, scene, rng)
	local self = setmetatable({}, Room)
	self.key = key
	self.scene = scene
	self.rng = rng
	self.lootRng = Random.new(#key * 7919 + 101) -- 재료 · 귀한 드롭을 굴리는 난수(졸개의 움직임을 굴리는 난수와 따로 — 드롭을 더해도 싸움의 흐름이 달라지지 않는다)
	self.time = 0
	self.mobs = {}
	self.shots = {}
	self.casts = {} -- 몬스터의 마법(몸 동작과 따로 뜨는 것): { id, x, y, t, mob, def = atk.cast, done }
	self.drops = {}
	self.crystals = {} -- 무니의 달 수정 { id, owner, x, y, till } — 세운 차례대로
	self.nextId = 1
	self.caster = Caster.new(self) -- 2~4차의 쓰는 스킬을 돌리는 것(sim/caster.luau)
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
			alt = if kind.fly then kind.fly.alt else nil, -- 나는 몬스터: 지금 땅에서 뜬 높이(덮칠 때 내려왔다 올라간다)
		}
		if scene.story then
			mob.state, mob.away = "gone", true -- 이야기의 방(사당 지하): 그 퀘스트를 하는 사람이 올 때까지 없다(Room:stepStory)
		end
		table.insert(self.mobs, mob)
	end
	-- 스토리 보스(장면의 bosses — 공방 design/bosses.js의 STORYBOSS): 졸개의 목록 끝에 자리를 잡아 둔다(번호가 바뀌지 않게). 처음에는 없다(state "gone" · away) —
	--  그 퀘스트를 하는 사람이 방에 있을 때만 나타난다(Room:stepPresence). 부르는 졸개(호령)의 자리도 미리 잡아 둔다(away — 불릴 때 나온다)
	local function hpOf(lv: number, kind): number
		return math.max(1, math.floor(N.mobHp(lv) * kind.hp * RULES.dmgScale * (1 + RULES.targetBonus / 100) + 0.5))
	end
	for _, def in scene.bosses or {} do
		local kind = COMBAT.mobs[def.kind]
		local maxHp = hpOf(def.lv, kind)
		local boss = {
			id = #self.mobs + 1, kind = def.kind, def = kind, lv = def.lv, homeX = def.x, y = def.y, a = def.range[1], b = def.range[2], x = def.x, dir = -1,
			state = "gone", t = 0, hp = maxHp, maxHp = maxHp, cd = 0, wait = 0, goal = def.x, target = nil :: any, aggro = 0, struck = false, respawn = math.huge,
			boss = true, away = true, pat = 0, rest = 0, used = {}, adds = {},
		}
		table.insert(self.mobs, boss)
		self.bosses = self.bosses or {}
		table.insert(self.bosses, boss)
		for _, p in kind.story.patterns do
			if p.summon then
				local ak = COMBAT.mobs[p.summon.kind]
				local hp = hpOf(p.summon.lv, ak)
				for i = 1, p.summon.max do
					local x = p.summon.at[(i - 1) % #p.summon.at + 1]
					local add = {
						id = #self.mobs + 1, kind = p.summon.kind, def = ak, lv = p.summon.lv, homeX = x, y = def.y, a = def.range[1], b = def.range[2], x = x, dir = 1,
						state = "gone", t = 0, hp = hp, maxHp = hp, cd = 0, wait = 0, goal = x, target = nil :: any, aggro = 0, struck = false, respawn = math.huge,
						add = true, away = true,
					}
					table.insert(self.mobs, add)
					table.insert(boss.adds, add)
				end
			end
		end
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
		if canSee(mob, h, range) and not Buffs.stealth(h) then -- 연막 안의 사람은 놓친다
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
	-- 리븐의 날랜 몸: 확률로 피한다(맞을 수 있을 때만 굴린다 — 피한 뒤에도 맞은 뒤처럼 잠깐은 다시 맞지 않는다)
	local dodge = Kit.dodge(h) + Passives.dodge(h) -- 흘리기(4차): 회피 +
	if dodge > 0 and h.alive and h.invuln <= 0 and self.rng:NextNumber(0, 1) < dodge then
		h.invuln = RULES.invuln
		Passives.dodged(h) -- 흘리기: 피하면 다음 베기가 반드시 표식 치명타
		table.insert(events, { type = "dodge", hero = h.id })
		return
	end
	-- 생존기(버티기 · 그림자 숨기 · 저승 걸음 · 맞불): 그동안은 피해를 받지 않는다
	if Buffs.guard(h) then
		return
	end
	-- 끼고 있는 방어구만큼 덜 아프다. 무니의 지키는 마음은 거기에 더 줄인다(제 수정 곁에서는 두 배). 버프(달의 축복 · 수정 방벽 · 달의 성역)도 줄인다
	-- 패시브(굳센 자세 — 기술을 쓰는 동안에는 더 · 달궈진 몸 — 달아오름 동안)도 줄인다
	local casting = (h.actUntil or 0) > self.time or self.caster:acting(h)
	local raw = N.rawHit("mob", mob.lv) * (1 - Hero.cut(h, mob.lv) / 100) * mul * Kit.cut(h, self:nearCrystal(h)) * Buffs.cut(h) * Passives.cut(h, casting)
	-- 죽음의 가호: 쓰러질 피해를 한 번 버틴다(체력 1로 남는다)
	if h.alive and h.invuln <= 0 and raw >= h.hp and Buffs.ward(h) then
		local lost = h.hp - 1
		h.hp, h.invuln = 1, RULES.invuln
		table.insert(events, { type = "ward", hero = h.id })
		if lost > 0 then
			table.insert(events, { type = "hurt", hero = h.id, dmg = lost, hp = 1, from = mob.x, dead = false })
		end
		return
	end
	-- 재점화(살라맨더 4차): 쓰러질 피해를 받으면 열기를 모두 태워 버틴다(오래에 한 번)
	if h.alive and h.invuln <= 0 and raw >= h.hp then
		local left = Passives.rekindle(h, self.time)
		if left then
			local lost = math.max(0, h.hp - left)
			h.hp, h.invuln = left, RULES.invuln
			table.insert(events, { type = "self", hero = h.id })
			table.insert(events, { type = "hurt", hero = h.id, dmg = lost, hp = h.hp, from = mob.x, dead = false })
			return
		end
	end
	local dmg = Hero.hurt(h, raw)
	if dmg > 0 then
		table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = mob.x, dead = not h.alive })
	end
end

function Room:stepMob(mob, heroes, dt: number, events)
	if mob.boss then
		return self:stepBoss(mob, heroes, dt, events)
	end
	local def, atk = mob.def, mob.def.atk
	mob.t += dt
	mob.cd = math.max(0, mob.cd - dt)
	-- 묶였거나(바인드 — 저승 사슬 · 수정 감옥) 넘어져 있으면(지진) 움직이지도 치지도 못한다 — 맞고 멈칫하는 동작만 마저 한다
	if ((mob.bind or 0) > 0 or (mob.stun or 0) > 0) and mob.state ~= "gone" and mob.state ~= "dead" and mob.state ~= "spawn" then
		if mob.state ~= "hit" or mob.t >= RULES.stagger then
			mob.state, mob.struck = "idle", false
		end
		return
	end

	if mob.state == "gone" then
		if mob.away then
			return -- 보스가 부르는 졸개: 불릴 때까지 없다
		end
		mob.respawn -= dt
		if mob.respawn <= 0 then
			mob.state, mob.t, mob.x, mob.hp, mob.target, mob.cd = "spawn", 0, mob.homeX, mob.maxHp, nil, 0
			mob.marks = nil
			mob.bind, mob.bindImm, mob.stun, mob.rend, mob.cracks = 0, 0, 0, 0, 0
		end
		return
	elseif mob.state == "dead" then
		if mob.t >= DEAD_TIME then
			mob.state, mob.respawn = "gone", RULES.respawn
			if mob.add then
				mob.away = true -- 불려 나온 졸개는 저절로 다시 나오지 않는다
			end
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
		if def.fly then
			-- 나는 몬스터의 덮치기: 내려오는 동안(windup) 덮칠 자리로 다가가며 낮아지고, 그 뒤 time까지 다시 올라간다. 높이는 상태와 시간에서만 나온다(화면도 같은 식으로 셈한다 — mobsView)
			local k = if mob.t < atk.windup then mob.t / atk.windup else math.max(0, 1 - (mob.t - atk.windup) / (atk.time - atk.windup))
			mob.alt = def.fly.alt - (def.fly.alt - def.fly.low) * (k * k * (3 - 2 * k))
			if mob.t < atk.windup then
				mob.x += ((mob.diveX or mob.x) - mob.x) * math.min(1, dt * 7)
			end
		end
		if not mob.struck and mob.t >= atk.windup then
			mob.struck = true
			if atk.shot then
				-- 화살: 보는 쪽으로 곧게 날아간다. 새 몬스터는 나오는 자리(dx · dy)와 크기(w · h)가 따로 있다(빈 투구의 덩어리)
				local shot = { id = self.nextId, x = mob.x + mob.dir * (atk.shot.dx or 8), y = mob.y - (atk.shot.dy or 9), dir = mob.dir, speed = atk.shot.speed, left = atk.shot.range, mob = mob }
				-- 나오는 자리가 몸에서 먼 것(빈 투구의 덩어리는 27점 앞에서 생긴다): 몸과 그 자리 사이에 바짝 붙어 선 사람은 쏘는 순간 맞는다 — 붙어 서면 안 맞는 빈 곳이 없게(2026-10-09 Play에서 찾음). 맞혔으면 덩어리는 날아가지 않는다
				local point = false
				if atk.shot.dx then
					local hh = (atk.shot.h or 0) / 2
					for _, h in heroes do
						local dx = (h.x - mob.x) * mob.dir
						if h.alive and dx >= -HERO_W and dx < atk.shot.dx and shot.y - hh <= h.y and shot.y + hh >= h.y - HERO_H then
							self:hurtHero(events, h, mob, atk.mul)
							point = true
						end
					end
				end
				if not point then
					self.nextId += 1
					table.insert(self.shots, shot)
					table.insert(events, { type = "shot", id = shot.id, x = shot.x, y = shot.y, dir = shot.dir, speed = shot.speed, range = shot.left, kind = mob.kind })
				end
			elseif atk.cast then
				-- 마법: 몸 동작과 따로, 그때 겨눈 사람의 자리에 뜬다(발밑 = 몬스터와 같은 층의 땅 · 몸 = 그 사람의 몸 가운데). 예고(wait) 뒤에 그 안에 있는 사람이 맞는다 — 비키면 맞지 않는다(아래 Room:step)
				if target and target.alive then
					-- 앞(front) = 몬스터의 앞에 붙는다(등불 해파리의 번개 줄기): 앞에 있으면 맞고 뒤로 돌아가면 안 맞는다
					local front = atk.cast.place == "front"
					local cast = {
						id = self.nextId,
						x = if front then mob.x + mob.dir * atk.cast.from[1] else target.x,
						y = if front then mob.y - atk.cast.from[2] elseif atk.cast.place == "feet" then mob.y else target.y - 10,
						t = 0,
						mob = mob,
						def = atk.cast,
						done = false,
						dir = mob.dir,
					}
					self.nextId += 1
					table.insert(self.casts, cast)
					table.insert(events, { type = "cast", id = cast.id, kind = mob.kind, x = cast.x, y = cast.y, dir = cast.dir })
				end
			elseif atk.burst then
				-- 터뜨린다(폭탄병 · 포자 주머니): 둘레의 사람이 모두 맞는다. 터뜨려도 사라지지 않는다 — 동작이 끝나면 cd를 기다렸다가 또 터뜨리고, 잡히면 경험치와 물건을 준다
				--  (사용자 2026-10-11: "폭탄병 지혼자 터져서 없어지는거 없어야합니다. 공격하고 사냥당하는 일반 몬스터여야하는거에요")
				for _, h in heroes do
					if h.alive and math.abs(h.x - mob.x) <= atk.burst and math.abs(h.y - mob.y) <= atk.burst then
						self:hurtHero(events, h, mob, atk.mul)
					end
				end
			elseif target and target.alive then
				-- both = 앞뒤 모두 닿는다(바위 게의 집게 · 굴 두더지 · 덮치는 박쥐)
				local dx = (target.x - mob.x) * mob.dir
				if (if atk.both or def.fly then math.abs(dx) <= atk.reach + 6 else dx >= -6 and dx <= atk.reach + 6) and math.abs(target.y - mob.y) <= atk.up then
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
	if def.fly then
		mob.alt = def.fly.alt -- 덮치는 동안이 아니면 제 높이에 떠 있다
	end
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
		if def.fly then
			-- 나는 몬스터: 사람이 좌우 fly.see 안(같은 층)에 들면 그 자리로 덮친다. 쫓지는 않는다 — 덮치지 않을 때는 아래의 어슬렁대로 오간다
			if mob.cd <= 0 and math.abs(dx) <= def.fly.see and math.abs(target.y - mob.y) <= SEE_Y then
				mob.state, mob.t, mob.struck, mob.diveX = "atk", 0, false, math.clamp(target.x, mob.a, mob.b)
				return
			end
		else
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
	end
	-- 제자리 몬스터(굴 두더지): 오가지 않는다
	if def.speed <= 0 then
		mob.state = "idle"
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

-- ---------- 스토리 보스(공방 design/bosses.js의 STORYBOSS → COMBAT.mobs[보스].story) ----------
--  사용자 2026-10-11: "리워드 없는 스토리보스로 … 그냥 이야기에서 지나치는 스토리보스로" · "패턴, 스킬 이펙트는 따로 만드셔야해요"
--  상태: gone(없다) → spawn(나타남) → idle · run(쉬며 다가옴) → tell(예고 — 맞을 자리가 바닥에 그려진다) → act(친다) / dash(내달린다) → idle(굳어 있다 = rest) … → dead → gone
--  pat = 지금 하는 패턴의 차례(없으면 0 — 화면에 같이 보낸다: snapshot의 아홉째). 맞아도 멈칫하지 않고 밀리지 않는다. 묶이거나(바인드) 넘어지면 하던 것을 그만둔다.
--  2026-10-12 밤(사용자: "패턴이 너무적습니다. 뻔하고 … 패턴좀 멋있게 만드세요" → 시험 탭에서 먼저 만든 뒤 "추가 패턴 적용하고 …"): 패턴을 다시 짰다 — 시험 탭 luneTab.js의 stepStory를 옮긴 것.
--   · 고르기: 겨눈 사람과의 거리(reach 안 · far 밖)와 체력(from) · 쉬는 시간(every)으로 쓸 수 있는 것을 추리고, 그 가운데 몫(w)대로 뽑는다. 방금 쓴 것은 다른 것이 있으면 뽑지 않는다.
--   · 연속기(chain): 적힌 패턴들을 쉬지 않고 잇는다(첫 번째는 제 예고대로 · 둘째부터 예고 · 굳는 시간이 quick배 · 칠 때마다 chainStep만큼 다가선다). only = 연속기 안에서만 쓰는 패턴.
--   · 표시된 자리(spots): 예고가 시작될 때 바닥의 자리들이 정해지고(self.blasts), 예고가 끝나면(자리마다 더 기다린 뒤) 터진다 — 그 위에 선 사람이 맞는다.
--   · 도약(leap): 예고가 끝나면 뛰어올라 time초 뒤 겨눈 자리(mob.aim — 뛰기 0.25초 전까지 겨눈 사람을 따라간다)에 내려앉으며 친다.
--   · 물결(wave): dir = "front"면 보는 쪽으로만 · n개를 gap초 간격으로(검기 · 연속 검기).
--   · 체력 구간(story.phase): 체력이 at 아래로 내려가면 한 번 포효한다(roar — time초 동안 치지 않는다). 그 뒤로 쉬는 시간이 rage배 · 걸음이 1.15배.
--  화면에 더 보내는 것(snapshot의 열째 ~ 열두째): 겨눈 자리(aim) · 연속기의 차례(chainPat — 0이면 연속기가 아니다) · 지금 패턴이 빠른가(quick).

-- 보스를 치운다(그 퀘스트를 하는 사람이 없어졌다 · 쓰러진 뒤). 부른 졸개와 물결도 같이 사라진다
function Room:bossAway(mob)
	mob.state, mob.t, mob.away, mob.pat, mob.target = "gone", 0, true, 0, nil
	mob.bind, mob.bindImm, mob.stun, mob.rend, mob.cracks, mob.marks = 0, 0, 0, 0, 0, nil
	for _, add in mob.adds do
		add.state, add.t, add.away, add.target = "gone", 0, true, nil
		add.bind, add.bindImm, add.stun, add.rend, add.cracks, add.marks = 0, 0, 0, 0, 0, nil
	end
	if self.waves then
		for i = #self.waves, 1, -1 do
			if self.waves[i].mob == mob then
				table.remove(self.waves, i)
			end
		end
	end
	self:bossSpotsOff(mob)
	mob.chain, mob.chainPat, mob.quick, mob.aim, mob.alt = nil, 0, 1, 0, 0
end

-- 그 보스가 표시해 둔 자리들을 거둔다(묶여서 예고가 끊겼다 · 쓰러졌다 · 사라졌다)
function Room:bossSpotsOff(mob)
	if self.blasts then
		for i = #self.blasts, 1, -1 do
			if self.blasts[i].mob == mob then
				table.remove(self.blasts, i)
			end
		end
	end
end

-- 방에 아무도 없다(서버가 알린다): 서 있던 보스를 치운다 — 다시 들어오면 체력이 가득한 채 새로 선다
function Room:idle()
	for _, mob in self.bosses or {} do
		if not mob.away then
			self:bossAway(mob)
		end
	end
end

-- 이야기의 방(scene.story — 사당 지하 · 메인 「불타는 마을」): 졸개는 그 졸개를 잡는 퀘스트를 하는 중인 사람이 방에 있을 때만 나온다.
--  그런 사람이 오면 하나씩 차례로 나타나고(쓰러뜨리면 여느 졸개처럼 다시 나온다 — 밀려드는 병사), 다 잡았거나 그런 사람이 없으면 모두 사라진다.
--  사용자 2026-10-13: "사당지하 개발 해야합니다." — 퀘스트를 끝낸 뒤의 지하는 병사가 없는 조용한 방이다(비석을 읽을 수 있다)
Room.STORY_STAGGER = 0.5 -- 졸개가 하나씩 나타나는 간격(초)
-- 졸개는 종류마다 따로 본다: 정예 검병은 「불타는 마을」을 하는 사람이, 낡은 수련 인형은 2차 전직을 하는 사람이 있을 때만(2026-10-13)
function Room:stepStory(heroes)
	local want = {}
	for _, mob in self.mobs do
		if not mob.def.story and not mob.add and want[mob.kind] == nil then
			want[mob.kind] = false
			for _, h in heroes do
				if Quests.wantsMob(h.quests, mob.kind, self.key) then
					want[mob.kind] = true
					break
				end
			end
		end
	end
	local n = {}
	for _, mob in self.mobs do
		if not mob.def.story and not mob.add then
			n[mob.kind] = (n[mob.kind] or 0) + 1
			if want[mob.kind] and mob.away then
				mob.away = false
				mob.state, mob.t, mob.respawn = "gone", 0, Room.STORY_STAGGER * n[mob.kind]
			elseif not want[mob.kind] and not mob.away then
				mob.away = true
				mob.state, mob.t, mob.target = "gone", 0, nil
				mob.bind, mob.bindImm, mob.stun, mob.rend, mob.cracks, mob.marks = 0, 0, 0, 0, 0, nil
			end
		end
	end
end

-- 누가 서야 하는가: 이야기의 차례로, 그 보스를 잡는 퀘스트를 하는 중인 사람이 방에 있는 첫 보스 하나. 나머지는 없다
function Room:stepPresence(heroes)
	local want = nil
	for _, mob in self.bosses do
		if not want then
			for _, h in heroes do
				if Quests.wantsKill(h.quests, mob.kind, self.key) then
					want = mob
					break
				end
			end
		end
	end
	for _, mob in self.bosses do
		if mob == want then
			if mob.away then
				mob.away = false
				mob.state, mob.t, mob.x, mob.hp, mob.dir, mob.target = "spawn", 0, mob.homeX, mob.maxHp, -1, nil
				mob.pat, mob.rest, mob.used = 0, 0, {}
				mob.raged, mob.lastPat, mob.chain, mob.chainPat, mob.quick, mob.aim, mob.alt = false, 0, nil, 0, 1, 0, 0
			end
		elseif not mob.away and mob.state ~= "dead" then
			self:bossAway(mob)
		end
	end
end

-- 그 자리(바닥 mob.y · 가로 lo~hi · 바닥에서 위로 up)에 그 사람의 발이 걸리는가 — 발이 up보다 높이 떠 있으면 걸리지 않는다(낮은 것은 뛰어서 넘는다)
local function inZone(mob, h, lo: number, hi: number, up: number): boolean
	return h.alive and h.x >= lo - HERO_W and h.x <= hi + HERO_W and mob.y - h.y < up and h.y <= mob.y + 4
end

-- 예고가 끝났다(도약은 내려앉았다): 친다
function Room:bossStrike(mob, p, heroes, events)
	if p.zone then
		local x0, x1 = mob.x + mob.dir * p.zone.from, mob.x + mob.dir * p.zone.to
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		for _, h in heroes do
			if inZone(mob, h, lo, hi, p.zone.up) then
				self:hurtHero(events, h, mob, p.mul)
			end
		end
	end
	if p.wave then
		-- 물결이 바닥을 따라 간다(Room:step이 옮기고 맞힌다 — 한 사람은 한 물결에 한 번): 내려찍은 자리에서 양쪽으로(땅 울림) · 보는 쪽으로만(검기) · 여럿이 잇달아(연속 검기 — wait초 뒤에 떠난다)
		self.waves = self.waves or {}
		for _, w in BossPat.waves(p, mob.dir) do
			table.insert(self.waves, { mob = mob, x = mob.x + mob.dir * p.wave.at, y = mob.y, dir = w[1], wait = w[2], left = p.wave.range, def = p.wave, mul = p.mul, hit = {} })
		end
	end
	if p.summon then
		-- 호령: 서 있지 않은 자리의 졸개를 n까지 방의 양 끝에서 내보낸다
		local out = 0
		for _, add in mob.adds do
			if out < p.summon.n and add.away then
				out += 1
				add.away = false
				add.state, add.t, add.x, add.hp, add.target, add.cd, add.aggro = "spawn", 0, add.homeX, add.maxHp, nil, 0, 0
				add.dir = if add.homeX < mob.x then 1 else -1
				add.goal, add.wait = mob.x, 0
				add.bind, add.bindImm, add.stun, add.rend, add.cracks, add.marks = 0, 0, 0, 0, 0, nil
			end
		end
	end
end

-- 그 패턴을 지금 쓸 수 있는가(겨눈 사람과의 거리 dist)
function Room:bossCan(mob, p, dist: number): boolean
	local ok = not p.only and (not p.from or mob.hp <= mob.maxHp * p.from) and (not p.every or self.time - (mob.used[p.id] or -math.huge) >= p.every)
		and (not p.reach or dist <= p.reach) and (not p.far or dist >= p.far)
	if ok and p.summon then
		ok = false
		for _, add in mob.adds do
			if add.away then
				ok = true -- 부를 자리가 남아 있다
				break
			end
		end
	end
	return ok
end

-- 다음에 쓸 패턴: 쓸 수 있는 것 가운데 몫(w — 없으면 1)대로 하나. 방금 쓴 것은 다른 것이 있으면 뽑지 않는다. 없으면 nil(더 다가간다)
function Room:bossPick(mob, dist: number)
	local P = mob.def.story.patterns
	local pool, fresh = {}, {}
	for i, p in P do
		if self:bossCan(mob, p, dist) then
			table.insert(pool, i)
			if i ~= mob.lastPat then
				table.insert(fresh, i)
			end
		end
	end
	if #fresh > 0 then
		pool = fresh
	end
	if #pool == 0 then
		return nil, 0
	end
	local total = 0
	for _, i in pool do
		total += P[i].w or 1
	end
	local r = self.rng:NextNumber(0, total)
	local pick = pool[#pool]
	for _, i in pool do
		r -= P[i].w or 1
		if r <= 0 then
			pick = i
			break
		end
	end
	return P[pick], pick
end

local function patIndex(S, id: string): number
	for i, p in S.patterns do
		if p.id == id then
			return i
		end
	end
	error("스토리 보스: 없는 패턴 " .. id)
end

-- 그 패턴을 예고부터 시작한다. quick = 연속기 안에서 예고 · 굳는 시간을 줄이는 비율(없으면 1) · target = 겨눈 사람(없어도 된다 — 그러면 보는 쪽 앞을 겨눈다)
function Room:bossBegin(mob, i: number, quick: number?, target)
	local S = mob.def.story
	local p = S.patterns[i]
	mob.state, mob.t, mob.pat, mob.quick = "tell", 0, i, quick or 1
	mob.landed, mob.alt = false, 0
	mob.slide = if quick then mob.chainStep or 0 else 0
	if target then
		local dx = target.x - mob.x
		if dx ~= 0 then
			mob.dir = sign(dx)
		end
	end
	mob.aim = if target then target.x else mob.x + mob.dir * ((p.leap and p.leap.aim or 0) + 30)
	if p.spots then
		-- 표시되는 자리들이 지금 정해진다 — 예고가 끝나면(자리마다 더 기다린 뒤) 터진다
		self.blasts = self.blasts or {}
		local lo, hi = BossPat.bounds(self.scene)
		local tell = BossPat.tell(p, mob.quick)
		for _, sp in BossPat.spots(p, mob.aim, lo, hi) do
			table.insert(self.blasts, { mob = mob, x = sp[1], y = mob.y, t = tell + sp[2], def = p.spots, mul = p.mul })
		end
	end
	return p
end

-- 쉬는 틈의 배율: 포효한 뒤에는 짧아진다
local function rageOf(mob, S): number
	return if mob.raged and S.phase then S.phase.rage or 1 else 1
end

-- 고른 패턴(i째)을 쓴다: 연속기면 그 첫 패턴부터(첫 번째는 제 예고대로 — 둘째부터 quick배: bossDone), 아니면 그 패턴을. 쓴 때와 차례를 적는다(every · 방금 쓴 것 피하기)
function Room:bossStart(mob, i: number, target)
	local S = mob.def.story
	local pick = S.patterns[i]
	mob.used[pick.id] = self.time
	mob.lastPat = i
	if pick.chain then
		mob.chain = table.clone(pick.chain)
		mob.chainQuick, mob.chainStep, mob.chainPat = pick.quick, pick.chainStep or 0, i
		mob.chainRest = 1.8 * rageOf(mob, S) -- 다 끝나면 길게 쉰다(때릴 틈)
		return self:bossBegin(mob, patIndex(S, table.remove(mob.chain, 1)), nil, target)
	end
	mob.chain, mob.chainRest, mob.chainPat = nil, nil, 0
	return self:bossBegin(mob, i, nil, target)
end
-- 그 패턴이 끝났다: 연속기면 쉬지 않고 다음 것으로, 아니면 쉰다
function Room:bossDone(mob, p, heroes)
	local S = mob.def.story
	if mob.chain and #mob.chain > 0 then
		local id = table.remove(mob.chain, 1)
		self:bossBegin(mob, patIndex(S, id), mob.chainQuick, if mob.target then heroes[mob.target] else nil)
		return
	end
	mob.state, mob.t, mob.pat, mob.rest = "idle", 0, 0, mob.chainRest or p.rest * rageOf(mob, S)
	mob.chain, mob.chainRest, mob.chainPat, mob.quick, mob.alt = nil, nil, 0, 1, 0
end

function Room:stepBoss(mob, heroes, dt: number, events)
	local S = mob.def.story
	mob.t += dt
	if mob.state == "gone" then
		return
	elseif mob.state == "dead" then
		-- 쓰러지는 동작 그림이 있는 보스(S.fall초 — 그 동작 + 누워 있는 시간 + 사라지는 시간)는 그 그림이 다 보일 때까지 치우지 않는다
		if mob.t >= (S.fall or DEAD_TIME) then
			self:bossAway(mob)
		end
		return
	elseif mob.state == "spawn" then
		if mob.t >= SPAWN_TIME then
			mob.state, mob.t, mob.rest = "idle", 0, S.pause
		end
		return
	end
	-- 묶였거나 넘어져 있다: 하던 것을 그만두고 선다(풀리면 잠깐 뒤에 다시 고른다). 예고하던 중이면 표시해 둔 자리도 거둔다. 뛰어오른 중이면 그 자리에 내려선다
	if (mob.bind or 0) > 0 or (mob.stun or 0) > 0 then
		if mob.state ~= "idle" then
			if mob.state == "tell" then
				self:bossSpotsOff(mob)
			end
			mob.state, mob.t, mob.pat = "idle", 0, 0
			mob.chain, mob.chainRest, mob.chainPat, mob.quick, mob.alt = nil, nil, 0, 1, 0
		end
		mob.rest = math.max(mob.rest, 0.4)
		return
	end
	if mob.state == "roar" then
		-- 체력 구간의 포효: 그동안은 치지 않는다(때릴 틈)
		if mob.t >= S.phase.time then
			mob.state, mob.t, mob.rest = "idle", 0, 0.5
		end
		return
	end
	local p = S.patterns[mob.pat]
	local quick = mob.quick or 1
	if mob.state == "tell" then
		local tell = BossPat.tell(p, quick)
		local target = if mob.target then heroes[mob.target] else nil
		if (mob.slide or 0) > 0 then
			-- 연속기: 예고하면서 한 걸음 다가선다(서는 거리 keep 안으로는 들어가지 않는다)
			if target and target.alive then
				local dx = target.x - mob.x
				local mv = math.min(mob.slide, 130 * dt, math.max(0, math.abs(dx) - S.keep))
				mob.x = math.clamp(mob.x + sign(dx) * mv, mob.a, mob.b)
			end
			mob.slide -= 130 * dt
		end
		if p.leap and mob.t < tell - 0.25 and target and target.alive then
			mob.aim = target.x -- 도약: 뛰기 0.25초 전까지 겨눈 사람을 따라간다
		end
		if mob.t >= tell then
			mob.t = 0
			if p.leap then
				-- 뛰어오른다 — 내려앉을 때 친다
				mob.leapFrom = mob.x
				mob.leapTo, mob.dir = BossPat.leapTo(p, mob.x, mob.dir, mob.aim, mob.a, mob.b)
				mob.landed = false
			else
				self:bossStrike(mob, p, heroes, events)
			end
			if p.dash then
				mob.state, mob.dashHit = "dash", {}
			else
				mob.state = "act"
			end
		end
		return
	elseif mob.state == "act" then
		if p.leap and not mob.landed then
			local k = math.min(1, mob.t / p.leap.time)
			mob.x = mob.leapFrom + (mob.leapTo - mob.leapFrom) * k
			mob.alt = BossPat.leapAlt(p, mob.t)
			if k >= 1 then
				mob.landed, mob.alt = true, 0
				self:bossStrike(mob, p, heroes, events)
			end
		end
		-- 치면서 한 걸음 내디딘다: 처음 STEP_TIME초 안에 다 간다(act = 친 뒤에 굳어 있는 시간 — 받은 공격 그림의 길이에 맞춰 길다. 그동안 걷지도 돌아서지도 않는다)
		local act = BossPat.act(p, quick)
		local stepT = math.min(act, STEP_TIME)
		if p.step and stepT > 0 then
			local part = math.min(mob.t, stepT) - math.min(mob.t - dt, stepT)
			if part > 0 then
				mob.x = math.clamp(mob.x + mob.dir * p.step * part / stepT, mob.a, mob.b)
			end
		end
		if mob.t >= act then
			self:bossDone(mob, p, heroes)
		end
		return
	elseif mob.state == "dash" then
		-- 내달리기: 보는 쪽의 끝까지. 달리는 몸에 닿은 사람은 한 번 맞는다(발이 up보다 높이 떠 있으면 넘어간다)
		local hw = bodyOf(mob)
		mob.x = math.clamp(mob.x + mob.dir * p.dash.speed * dt, mob.a, mob.b)
		for id, h in heroes do
			if not mob.dashHit[id] and inZone(mob, h, mob.x - hw, mob.x + hw, p.dash.up) then
				mob.dashHit[id] = true
				self:hurtHero(events, h, mob, p.mul)
			end
		end
		if mob.x <= mob.a or mob.x >= mob.b then
			mob.dashHit = nil
			self:bossDone(mob, p, heroes)
		end
		return
	end
	-- 쉬며 다가온다: 가장 가까운 살아 있는 사람을 본다(연막 안의 사람은 놓친다)
	mob.rest = math.max(0, mob.rest - dt)
	local target, bestD = nil, math.huge
	for id, h in heroes do
		if h.alive and not Buffs.stealth(h) then
			local d = math.abs(h.x - mob.x)
			if d < bestD then
				target, bestD = h, d
				mob.target = id
			end
		end
	end
	if not target then
		mob.state, mob.target = "idle", nil
		return
	end
	local dx = target.x - mob.x
	if dx ~= 0 then
		mob.dir = sign(dx)
	end
	-- 체력 구간: 한 번 포효한다 — 그 뒤로 새 패턴이 열리고(from) 쉬는 틈이 짧아진다
	if S.phase and not mob.raged and mob.hp <= mob.maxHp * S.phase.at then
		mob.raged = true
		mob.state, mob.t, mob.pat = "roar", 0, 0
		mob.chain, mob.chainPat = nil, 0
		return
	end
	if mob.rest <= 0 then
		local pick, i = self:bossPick(mob, math.abs(dx))
		if pick then
			self:bossStart(mob, i, target)
			return
		end
	end
	if math.abs(dx) > S.keep then
		mob.x = math.clamp(mob.x + mob.dir * mob.def.speed * (if mob.raged then 1.15 else 1) * dt, mob.a, mob.b)
		mob.state = "run"
	else
		mob.state = "idle"
	end
end

-- 한 걸음. 일어난 일의 목록을 돌려준다: hurt(사람이 맞음) · shot(화살이 생김) · shotEnd
function Room:step(heroes, dt: number)
	local events = {}
	self.time += dt
	self.heroes = heroes -- 지금 방에 있는 사람들(스토리 보스를 쓰러뜨리면 모두에게 잡은 것으로 친다 — Room:strike)
	if self.bosses then
		self:stepPresence(heroes)
	end
	if self.scene and self.scene.story then
		self:stepStory(heroes)
	end
	for _, mob in self.mobs do
		-- 졸개에 걸린 것이 풀려 간다: bind 묶임 · bindImm 다시 묶이지 않는 시간 · stun 넘어짐 · rend 갈라짐(받는 피해 +)
		if (mob.bind or 0) > 0 then
			mob.bind = math.max(0, mob.bind - dt)
		end
		if (mob.bindImm or 0) > 0 then
			mob.bindImm = math.max(0, mob.bindImm - dt)
		end
		if (mob.stun or 0) > 0 then
			mob.stun = math.max(0, mob.stun - dt)
		end
		if (mob.rend or 0) > 0 then
			mob.rend = math.max(0, mob.rend - dt)
		end
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
				local sd = s.mob.def.atk.shot
				local hw, hh = (sd.w or 4) / 2, (sd.h or 0) / 2 -- 날아가는 것의 반폭 · 반높이(화살은 점이다)
				if h.alive and math.abs(h.x - s.x) <= HERO_W + hw and s.y - hh <= h.y and s.y + hh >= h.y - HERO_H then
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
	-- 몬스터의 마법: 뜬 자리에 고정되어 예고(wait)가 지나면 그 안의 사람이 모두 맞는다. 끝(life)까지 남았다가 사라진다
	for i = #self.casts, 1, -1 do
		local c = self.casts[i]
		c.t += dt
		local front = c.def.place == "front"
		if front then
			-- 몬스터를 따라 붙는다. 쓴 몬스터가 쓰러졌으면 사라진다
			if c.mob.state == "dead" then
				table.remove(self.casts, i)
				continue
			end
			c.x, c.y = c.mob.x + c.dir * c.def.from[1], c.mob.y - c.def.from[2]
		end
		if not c.done and c.t >= c.def.wait then
			c.done = true
			for _, h in heroes do
				if not h.alive then
					continue
				end
				local inside = false
				if front then
					local dx = (h.x - c.x) * c.dir
					inside = dx >= -HERO_W and dx <= c.def.w + HERO_W and math.abs(h.y - 10 - c.y) <= c.def.h + 10
				elseif math.abs(h.x - c.x) <= c.def.w + HERO_W + 1 then
					inside = if c.def.place == "feet" then h.y > c.y - c.def.h and h.y - HERO_H < c.y + 2 else math.abs(h.y - 10 - c.y) <= c.def.h + 10
				end
				if inside then
					self:hurtHero(events, h, c.mob, c.mob.def.atk.mul)
				end
			end
		end
		if c.t >= c.def.life then
			table.remove(self.casts, i)
		end
	end
	-- 스토리 보스의 물결(땅 울림): 바닥을 따라 가며, 닿은 사람은 한 번 맞는다(발이 up보다 높이 떠 있으면 넘어간다)
	if self.waves then
		for i = #self.waves, 1, -1 do
			local w = self.waves[i]
			if (w.wait or 0) > 0 then
				w.wait -= dt -- 연속 검기: 차례를 기다린다
				continue
			end
			local move = w.def.speed * dt
			w.x += w.dir * move
			w.left -= move
			for id, h in heroes do
				if not w.hit[id] and h.alive and math.abs(h.x - w.x) <= w.def.w + HERO_W and w.y - h.y < w.def.up and h.y <= w.y + 4 then
					w.hit[id] = true
					self:hurtHero(events, h, w.mob, w.mul)
				end
			end
			if w.left <= 0 or Physics.cell(self.scene, math.floor(w.x / 16), math.floor((w.y - 1) / 16)) == "#" then
				table.remove(self.waves, i)
			end
		end
	end
	-- 스토리 보스가 표시한 자리(불씨 뿌리기 · 봉화 불기둥): 때가 되면 터진다 — 그 위에 선 사람이 맞는다(발이 up보다 높이 떠 있으면 안 맞는다). 보스가 쓰러지면 사라진다
	if self.blasts then
		for i = #self.blasts, 1, -1 do
			local b = self.blasts[i]
			if b.mob.state == "dead" or b.mob.state == "gone" then
				table.remove(self.blasts, i)
				continue
			end
			b.t -= dt
			if b.t <= 0 then
				for _, h in heroes do
					if h.alive and math.abs(h.x - b.x) <= b.def.r + HERO_W and b.y - h.y < b.def.up and h.y <= b.y + 4 then
						self:hurtHero(events, h, b.mob, b.mul)
					end
				end
				table.remove(self.blasts, i)
			end
		end
	end
	-- 설치 · 소환
	if self.placed and #self.placed > 0 then
		self:stepPlaced(heroes, dt, events)
	end
	-- 조금 뒤에 넣기로 한 타(붙는 불): 때가 된 것을 풀어 그 사람의 일로 알린다
	if self.laters then
		for i = #self.laters, 1, -1 do
			local job = self.laters[i]
			if self.time >= job.at then
				table.remove(self.laters, i)
				local result = { hits = {}, kills = {} }
				job.fn(result)
				if #result.hits > 0 then
					table.insert(events, { type = "kit", hero = job.hero.id, result = result })
				end
			end
		end
	end
	-- 가시: 닿아 있으면 약한 피해 — 최대 체력의 spike%. 맞은 뒤 잠깐(invuln)은 다시 맞지 않아, 닿아 있는 동안 그 간격으로 한 번씩 든다.
	--  사용자 2026-10-08: "맵에 가시 있잖아요 그거 닿으면 데미지 입게 약한데미지 입게하세요". 피해를 받지 않는 버프(버티기 …) 동안에는 들지 않는다
	if self.scene then
		for _, h in heroes do
			if h.alive and h.invuln <= 0 and Physics.onSpike(self.scene, h.x, h.y) and not Buffs.guard(h) then
				local dmg = Hero.hurt(h, math.max(1, h.maxHp * RULES.spike / 100))
				if dmg > 0 then
					table.insert(events, { type = "hurt", hero = h.id, dmg = dmg, hp = h.hp, from = h.x, dead = not h.alive })
				end
			end
		end
	end
	-- 쉬는 곳(쉼터 · 작은 마을 · 마을 — 장면의 rest): 그 자리에 wait초 가만히 서 있으면 every초마다 최대 체력의 heal%가 찬다. 움직이거나 맞으면 처음부터 다시 센다.
	--  승인받은 맵 배치 계획의 "쉼터 · 작은 마을에서 쉬면 체력이 찬다"(숫자는 [제안] — combat.js의 COMBAT.rest). h.rest = { t = 가만히 선 시간, x, y = 그 자리, hp = 그때의 체력 }
	if self.scene and self.scene.rest then
		local R = RULES.rest
		for _, h in heroes do
			local r = h.rest
			if not r or not h.alive or math.abs(h.x - r.x) > 0.5 or math.abs(h.y - r.y) > 0.5 or h.hp < r.hp then
				h.rest = { t = 0, x = h.x, y = h.y, hp = h.hp }
			elseif h.hp >= h.maxHp then
				r.t, r.hp = 0, h.hp
			else
				local before = r.t
				r.t += dt
				if r.t >= R.wait + R.every and math.floor((r.t - R.wait) / R.every) > math.floor((before - R.wait) / R.every) then
					local gain = math.min(h.maxHp - h.hp, math.max(1, math.floor(h.maxHp * R.heal / 100 + 0.5)))
					h.hp += gain
					table.insert(events, { type = "healed", hero = h.id, amount = gain })
				end
				r.hp = h.hp
			end
		end
	end
	-- 2~4차의 쓰는 스킬: 구간의 타 · 늦게 터지는 것 · 날아가는 것
	self.caster:step(heroes, dt, events)
	-- 스미는 독(리븐 3차): 표식이 있는 적은 초마다 독 피해를 받는다 — 표식 수만큼 세다
	for _, hero in heroes do
		if hero.class == "riven" and hero.alive and hero.pass then
			local fx, s = Passives.get(hero, "venom")
			if fx and self.time >= hero.pass.venom then
				hero.pass.venom = self.time + 1
				local result = nil
				local power = Hero.powerRaw(hero) * Kit.attack(hero) * Buffs.dmg(hero) * Passives.atk(hero)
				for _, mob in self.mobs do
					local n = self:marksOf(hero, mob)
					if n > 0 and mob.state ~= "dead" and mob.state ~= "gone" and mob.state ~= "spawn" then
						result = result or { hits = {}, kills = {} }
						self:proc(hero, mob, power * N.data.POWER.dps * fx.venom * s * n * RULES.dmgScale * (1 + RULES.targetBonus / 100), "venom", mob.x, mob.y - 12, nil, result)
					end
				end
				if result then
					table.insert(events, { type = "kit", hero = hero.id, result = result })
				end
			end
		end
	end
	-- 달 수정: 때가 되면 사라진다
	for i = #self.crystals, 1, -1 do
		local c = self.crystals[i]
		if self.time >= c.till then
			table.remove(self.crystals, i)
			table.insert(events, { type = "crystalGone", id = c.id })
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
			local hw, up, hh = bodyOf(mob)
			if mob.x + hw >= x0 and mob.x - hw <= x1 and mob.y - up >= y0 and mob.y - up - hh <= y1 then
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
		mob.bind, mob.stun, mob.rend, mob.cracks = 0, 0, 0, 0
		return true
	end
	if mob.boss then
		return false -- 스토리 보스는 맞아도 하던 동작을 멈추지 않고 밀리지 않는다
	end
	-- 멈칫한다 · 조금 밀린다(폭탄병도 다른 몬스터처럼 맞으면 터뜨리던 것을 멈춘다)
	mob.state, mob.t = "hit", 0
	if mob.def.speed > 0 then -- 제자리 몬스터(굴 두더지)는 밀리지 않는다
		mob.x = math.clamp(mob.x + sign(mob.x - fromX) * 3, mob.a, mob.b)
	end
	return false
end

-- 그 졸개가 살아서 맞을 수 있는가
local function alive(mob): boolean
	return mob.state ~= "dead" and mob.state ~= "gone" and mob.state ~= "spawn"
end

-- (x, y)에서 가장 가까운, 살아 있는 졸개(range 안 — except는 빼고). 사출기가 날아갈 곳을 찾는다
function Room:nearestMob(x: number, y: number, range: number, except: any)
	local best, bestD = nil, math.huge
	for _, mob in self.mobs do
		if mob ~= except and alive(mob) and math.abs(mob.y - y) <= 60 then
			local d = math.abs(mob.x - x)
			if d <= range and d < bestD then
				best, bestD = mob, d
			end
		end
	end
	return best
end

-- 졸개 하나에게 피해를 넣고 일을 적는다(out.hits — 쓰러지면 out.kills에 경험치 · 떨어지는 것까지). 쓰러졌으면 true.
--  extra = 그 타에 붙는 표시: proc(사출기 · 장치의 이름 — "echo" · "star" · "wisp" · "shard" · "ember" · "flame" · "reson") · sx · sy(그것이 날아오는 자리) · crit(치명타) · big(센 타)
function Room:strike(hero, mob, dmg: number, fromX: number, mates, out, extra): boolean
	-- 갈라짐(액시온의 쪼개기)이 걸린 적은 누구에게 맞든 더 아프다
	if (mob.rend or 0) > 0 then
		dmg = math.max(1, math.floor(dmg * (1 + CASTRULE.rend) + 0.5))
	end
	local dead = self:damageMob(mob, dmg, fromX, hero.id)
	local entry = { mob = mob.id, dmg = dmg, hp = mob.hp, dead = dead }
	if extra then
		for k, v in extra do
			entry[k] = v
		end
	end
	table.insert(out.hits, entry)
	if dead then
		mob.marks = nil
		-- 리퍼의 영혼: 쓰러뜨리면 하나
		if Kit.gainSoul(hero) then
			out.kit = true
		end
		-- 꺼지지 않는 불(살라맨더 4차): 폭주 중에 쓰러뜨리면 폭주가 늘어난다
		local burst = hero.buffs.sl_overheat
		if burst and hero.pass then
			local fx = Passives.get(hero, "extend")
			if fx and hero.pass.extended < fx.extendMax then
				local add = math.min(fx.extend, fx.extendMax - hero.pass.extended)
				burst.t += add
				burst.dur += add
				hero.pass.extended += add
				out.buffs = true
			end
		end
		-- 저승문 곁에서 쓰러진 적은 영혼을 더 준다
		for _, p in self.placed or {} do
			if p.owner == hero and p.def.souls and math.abs(p.x - mob.x) <= p.def.near then
				for _ = 2, p.def.souls do
					Kit.gainSoul(hero)
				end
			end
		end
		-- 스토리 보스와 그가 부른 졸개: 경험치도 물건도 주지 않는다(보상은 그 메인 퀘스트의 것뿐). 보스는 방에 있는 모두에게 잡은 것으로 친다 — 서버가 gains의 사람마다 퀘스트를 센다
		if mob.boss or mob.add then
			local gains = {}
			if mob.boss then
				for _, h in self.heroes or { hero } do
					table.insert(gains, { hero = h.id, xp = 0, ups = 0, level = h.level })
				end
			end
			table.insert(out.kills, { mob = mob.id, kind = mob.kind, x = mob.x, y = mob.y, xp = 0, ups = 0, gains = gains, loot = {} })
			return dead
		end
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
	return dead
end

-- 사출기 · 장치가 따로 넣는 한 타(그 졸개 하나에게). (sx, sy) = 그것이 날아오는 자리(화면이 그린다)
--  tag = 그 타에 더 붙는 표시(i 몇째 발 · n 한 번에 나간 수 · hop 튕긴 것 · up 배운 강화(화면이 그 모습으로 그린다))
function Room:proc(hero, mob, dmg: number, kind: string, sx: number, sy: number, mates, out, tag)
	local extra = { proc = kind, sx = math.floor(sx + 0.5), sy = math.floor(sy + 0.5) }
	if tag then
		for k, v in tag do
			extra[k] = v
		end
	end
	self:strike(hero, mob, math.max(1, math.floor(dmg + 0.5)), hero.x, mates, out, extra)
end

-- 설치 · 소환(COMBAT.placed — 공방 design/combat.js의 PLACED)을 놓는다. pow = 세기(그 스킬 레벨의 배수). 달 수정을 심는 것은 out에 적힌다(Crystal로 알린다).
--  놓인 것 = { skill, def, owner(그 사람), x, y, till(사라지는 때), next(다음에 치는 때), pow } — 따라다니는 것은 같은 것을 하나만 둔다(다시 쓰면 새것으로 바뀐다)
function Room:place(hero, id: string, pow: number, out)
	local def = PLACED[id]
	local x, y = hero.x + hero.dir * (def.ahead or 0), hero.y
	if def.kind == "crystal" then
		self:addCrystal(hero, x, y, out)
		return nil
	end
	if not (def.tick or def.every or def.pull or def.heat) then
		return nil -- 버프만 거는 것(연막탄)
	end
	self.placed = self.placed or {}
	if def.kind == "follow" then
		-- 따라다니는 것은 같은 것을 하나만 둔다 — 망령 군단 · 수호령 각성(4차)을 배웠으면 그 수까지(넘치면 먼저 부른 것이 사라진다)
		local keep = if id == "rp_ghost" then Passives.count(hero, "ghosts", 1) elseif id == "mn_guard" then Passives.count(hero, "guards", 1) else 1
		local have = 0
		for i = #self.placed, 1, -1 do
			local q = self.placed[i]
			if q.owner == hero and q.skill == id then
				have += 1
				if have >= keep then
					table.remove(self.placed, i)
				end
			end
		end
	end
	local p = { skill = id, def = def, owner = hero, x = x, y = y, till = self.time + def.life, next = self.time + (def.tick or def.every or 0), pow = pow }
	table.insert(self.placed, p)
	return p
end

-- 놓인 것들의 한 걸음: 태우고(field의 tick) · 치고(follow의 every) · 끌어당기고 · 열기를 올린다. 때가 됐거나 주인이 방에 없으면 사라진다
function Room:stepPlaced(heroes, dt: number, events)
	local here = {}
	for _, h in heroes do
		here[h] = true
	end
	local fit = RULES.dmgScale * (1 + RULES.targetBonus / 100)
	for i = #self.placed, 1, -1 do
		local p = self.placed[i]
		local def, hero = p.def, p.owner
		if self.time >= p.till or not here[hero] or not hero.alive then
			table.remove(self.placed, i)
			continue
		end
		if def.kind == "follow" then
			p.x, p.y = hero.x - hero.dir * def.back, hero.y
		end
		local result = nil
		local power = Hero.powerRaw(hero) * Kit.attack(hero) * Buffs.dmg(hero) * Passives.atk(hero)
		if self.time >= p.next and (def.tick or def.every) then
			local gap = def.tick or def.every
			p.next += gap
			local targets = if def.tick then self:mobsInBox(p.x - def.w / 2, p.x + def.w / 2, p.y - def.h, p.y + 6, p.x) else { self:nearestMob(p.x, p.y, def.range, nil) }
			for _, mob in targets do
				result = result or { hits = {}, kills = {} }
				local roll = 1 + self.rng:NextNumber(-RULES.spread, RULES.spread) / 100
				self:proc(hero, mob, power * def.mul * gap * p.pow * fit * roll, if def.tick then "field" else "summon", p.x, p.y - 12, nil, result)
			end
		end
		if def.pull then
			for _, mob in self.mobs do
				local dx = p.x - mob.x
				if alive(mob) and not mob.def.boss and math.abs(dx) < def.reach and math.abs(dx) > 4 and math.abs(mob.y - p.y) <= 60 then
					mob.x = math.clamp(mob.x + sign(dx) * def.pull * dt, mob.a, mob.b)
				end
			end
		end
		if def.heat and hero.class == "salamander" and Kit.level(hero, "core") > 0 and math.abs(hero.x - p.x) <= def.near then
			local kit, max = hero.kit, KIT.salamander.core.max
			local before = kit.heat
			kit.heat, kit.heatT = math.min(max, kit.heat + def.heat * dt), 0 -- 곁에 있으면 식지 않고 오른다
			if math.floor(before / 5) ~= math.floor(kit.heat / 5) then
				table.insert(events, { type = "self", hero = hero.id })
			end
		end
		if result then
			table.insert(events, { type = "kit", hero = hero.id, result = result })
		end
	end
end

-- 조금 뒤에 넣을 타(붙는 불 — 도깨비불이 붙어서 초마다 태운다): after초 뒤에 fn(out)을 부른다. 방의 한 걸음(step)이 때가 된 것을 풀어 "kit" 일로 알린다
function Room:later(hero, after: number, fn)
	self.laters = self.laters or {}
	table.insert(self.laters, { at = self.time + after, hero = hero, fn = fn })
end

-- 표식을 남긴다(리븐): 그 졸개에게 time초. 그 졸개가 이번에 맞은 기록에 mark(남은 초)를 적어 화면에 알린다
--  깊은 표식(3차)을 배웠으면 겹친다(marks까지) — 그 졸개의 기록에 markN(겹친 수)도 적는다
function Room:mark(hero, mob, out)
	local time = KIT.riven.core.time
	local n = math.min(Passives.count(hero, "marks", 1), self:marksOf(hero, mob) + 1)
	mob.marks = mob.marks or {}
	mob.markN = mob.markN or {}
	mob.marks[hero.id] = self.time + time
	mob.markN[hero.id] = n
	for i = #out.hits, 1, -1 do
		if out.hits[i].mob == mob.id then
			out.hits[i].mark = time
			out.hits[i].markN = n
			break
		end
	end
end

-- 그 사람이 그 졸개에 남긴 표식의 수(없으면 0)
function Room:marksOf(hero, mob): number
	if mob.marks and (mob.marks[hero.id] or 0) > self.time then
		return (mob.markN and mob.markN[hero.id]) or 1
	end
	return 0
end

-- 달 수정을 세운다(무니): 내 다른 수정과 apart보다 가까우면 세우지 않고, max개가 넘으면 가장 오래된 것이 사라진다. 생긴 것 · 사라진 것을 out.crystals · out.crystalGone에 적는다
function Room:addCrystal(hero, x: number, y: number, out)
	local core = KIT.mooni.core
	local mine = {}
	for _, c in self.crystals do
		if c.owner == hero.id then
			if math.abs(c.x - x) < core.apart and math.abs(c.y - y) < 20 then
				return
			end
			table.insert(mine, c)
		end
	end
	if #mine >= Passives.count(hero, "crystals", core.max) then -- 수정 군락(3차): 넷까지
		local old = mine[1] -- 먼저 세운 것이 앞에 있다
		table.remove(self.crystals, table.find(self.crystals, old))
		out.crystalGone = out.crystalGone or {}
		table.insert(out.crystalGone, old.id)
	end
	local grove, groveS = Passives.get(hero, "crystals") -- 수정 군락: 지속 +
	local c = { id = self.nextId, owner = hero.id, x = math.floor(x + 0.5), y = y, till = self.time + core.life * (1 + (if grove then grove.life * groveS else 0)) }
	self.nextId += 1
	table.insert(self.crystals, c)
	out.crystals = out.crystals or {}
	table.insert(out.crystals, Room.crystalView(c, self.time))
end

function Room.crystalView(c, now: number)
	return { id = c.id, owner = c.owner, x = c.x, y = c.y, life = math.max(0, c.till - now) }
end

-- 그 사람이 제 수정 곁에 있는가(무니의 지키는 마음)
function Room:nearCrystal(h): boolean
	if h.class ~= "mooni" then
		return false
	end
	local near = KIT.mooni.core.near
	for _, c in self.crystals do
		if c.owner == h.id and math.abs(c.x - h.x) <= near and math.abs(c.y - h.y) <= 50 then
			return true
		end
	end
	return false
end

-- 기술의 한 타. hero가 (x, y)에서 dir 쪽을 보고 쓴 기술의 hit(판정 하나)를 푼다. scale = 스킬 레벨에 따른 세기(없으면 1).
--  mates = 경험치를 함께 나눌 사람들(hero도 든다 — 같은 맵의 파티원. 없으면 혼자). 떨어진 것은 그 사람들도 바로 주울 수 있다.
--  돌려주는 것: { hits = { { mob, dmg, hp, dead, big, crit, proc, sx, sy, mark } … }, kills = { { mob, xp, ups, gains = { { hero, xp, ups, level } … }, drop, loot } … },
--				 kit(장치의 모습이 바뀌었다) · heal(되찾은 체력) · crystals · crystalGone(생긴 · 사라진 수정) }
--  kind = 그 기술의 갈래: 사냥기("mob")는 일반 몬스터에게, 보스기("boss")는 보스에게 피해가 targetBonus% 더 뜬다 — 맞지 않는 상대에게는 그 보정이 없다(체력은 보정만큼 크다)
--   (사용자 2026-10-07: "보스기는 보스 공격시 추가데미지, 사냥기는 일반 몹 공격시 추가 데미지 … 지금 그냥 보스기로 사냥하는게 더빠른현상이 생깁니다")
--  skillId = 그 기술(1차의 사출기 · 장치가 따라붙는 기술이면 맞힌 뒤에 그것들이 나간다 — sim/kit.luau) · opts = { mul 피해의 배수, reach 더 닿는 거리 }(힘 모으기)
function Room:skillHit(hero, hit, x: number, y: number, dir: number, scale: number?, mates, kind: string?, skillId: string?, opts)
	local box = hit.box
	local reach = if opts then opts.reach or 0 else 0
	local boost = if opts then opts.mul or 1 else 1
	-- 반올림하지 않은 전투력으로 셈한다(능력치 1점도 피해에 들어간다). 리퍼의 영혼은 공격력에 곱한다
	local power = Hero.powerRaw(hero) * Kit.attack(hero) * Buffs.dmg(hero) * Passives.atk(hero) -- 버프(달의 함성 · 만월 · 월식 …) · 패시브(숙련 · 달인 · 최종 피해)는 주는 피해에 곱한다
	local info = { skill = skillId, charge = if opts then opts.level or 0 else 0, now = self.time }
	local _, _, sure = Passives.crit(hero) -- 흘리기(리븐): 피한 뒤의 첫 베기는 반드시 치명타
	local out = { hits = {}, kills = {} }
	local follows = skillId ~= nil and Kit.follows(skillId) and COMBAT.skills[skillId].who == hero.class
	local landed = {} -- 이 타(제 범위)에 맞은 것들 { mob, dmg, dead }
	local big = Buffs.big(hero) * Passives.reach(hero) -- 거신 · 낫 숙련 · 영혼 주머니: 기술이 닿는 거리(앞 · 위)가 그만큼 는다
	-- 상자 하나를 (cx, cy)에서 푼다. share = 피해의 몫(수정의 공명은 그 일부) · tag = 그 타에 붙는 표시(없으면 기술의 제 타)
	local function sweep(cx: number, cy: number, share: number, tag)
		local xa, xb = cx + dir * box[1] * big, cx + dir * (box[2] + reach) * big
		local x0, x1 = math.min(xa, xb), math.max(xa, xb)
		for _, mob in self:mobsInBox(x0, x1, cy - box[3] * big, cy + box[4], cx) do
			local roll = 1 + self.rng:NextNumber(-RULES.spread, RULES.spread) / 100
			-- 가운데 타에 이미 맞은 적은 빼는 타(hit.except = 그 범위): 한 적이 같은 것을 두 번 맞지 않는다
			if hit.except then
				local e = hit.except
				local ea, eb = cx + dir * e[1] * big, cx + dir * (e[2] + reach) * big
				local hw, up, hh = bodyOf(mob)
				if mob.x + hw >= math.min(ea, eb) and mob.x - hw <= math.max(ea, eb) and mob.y - up >= cy - e[3] * big and mob.y - up - hh <= cy + e[4] then
					continue
				end
			end
			-- 쓰임의 보정: 사냥기는 일반 몬스터에게, 보스기는 보스에게 피해가 targetBonus% 더 뜬다(다른 갈래의 기술은 누구에게나 뜬다). 맞지 않는 상대에게는 보정이 없다
			local fit = if (kind == "mob" and mob.def.boss) or (kind == "boss" and not mob.def.boss) then 1 else 1 + RULES.targetBonus / 100
			local mul = hit.mul * (scale or 1) * boost * share * Passives.vs(hero, mob, info)
			-- 치명타: 모든 직업의 기술 타가 확률로(기본 + 패시브 + 리븐의 표식이 있는 적). 흘리기 = 피한 뒤의 첫 베기는 반드시
			local critChance, critMul = Passives.crit(hero, self:marksOf(hero, mob) > 0)
			local crit = sure or (critChance > 0 and self.rng:NextNumber(0, 100) < critChance)
			if crit then
				mul *= critMul
			end
			local dmg = math.max(1, math.floor(power * mul * roll * RULES.dmgScale * fit + 0.5)) -- dmgScale = 피해 숫자의 배율(올린 만큼 숫자로 보이게 — 공방 combat.js)
			local extra = if tag then table.clone(tag) else {}
			if hit.mul * boost * share >= BIG_HIT or crit then
				extra.big = true
			end
			if crit then
				extra.crit = true
			end
			local dead = self:strike(hero, mob, dmg, cx, mates, out, extra)
			if not tag then
				Passives.onHit(hero, mob, self.time) -- 이어 맞힌 수 · 이어 때린 수(살라맨더의 주먹 숙련 · 몰아붙이기)
				if not dead and (hit.pull or 0) > 0 then
					-- 끌어온다: 쓴 사람 쪽으로(제 범위 안에서만)
					local toward = if mob.x > x then -1 else 1
					mob.x = math.clamp(mob.x + toward * math.min(hit.pull, math.max(0, math.abs(mob.x - x) - 10)), mob.a, mob.b)
				end
				table.insert(landed, { mob = mob, dmg = dmg, dead = dead })
			end
		end
	end
	sweep(x, y, 1, nil)
	if sure and #landed > 0 and hero.pass then
		hero.pass.sure = false -- 흘리기의 반드시 치명타는 한 번 쓰면 사라진다
	end
	-- 넘치는 힘(액시온 4차): 끝까지 모은 강타를 맞히면 잠깐 동안 다음 강타가 높은 단계에서 시작한다
	if opts and not opts.surged and (opts.level or 0) > 0 and opts.level >= Kit.chargeLevels(hero) and #landed > 0 and hero.pass then
		local surge = Passives.get(hero, "surge")
		if surge then
			hero.pass.surge = self.time + surge.surge
		end
	end
	if follows then
		self:kitAfter(hero, landed, x, y, sweep, power, mates, out)
		-- 그림자 분신(리븐의 버프): 분신이 내 베기를 조금 뒤에 따라 벤다 — 맞은 적마다 그 타 피해의 일부. 표식을 남기는 베기였으면 분신의 것도 남긴다
		local share, after = Buffs.echo(hero)
		if share > 0 and #landed > 0 then
			local marks = hero.class == "riven" and Kit.level(hero, "core") > 0
			local fromX, fromY = x - dir * 13, y - 12
			self:later(hero, after, function(res)
				for _, l in landed do
					if alive(l.mob) then
						self:proc(hero, l.mob, l.dmg * share, "clone", fromX, fromY, mates, res)
						if marks and alive(l.mob) then
							self:mark(hero, l.mob, res)
						end
					end
				end
			end)
		end
	end
	return out
end

-- 1차의 사출기 · 장치 · 패시브가 따라 나간다(그 직업의 도끼질 · 베기 · 낫질 · 대검 · 주먹의 한 타 뒤에). landed = 그 타에 맞은 것들 · sweep = 같은 상자를 다른 자리에서 푸는 함수(수정의 공명)
--  opts = 2~4차의 스킬(sim/caster.luau)이 부를 때: sweep이 없다(수정에서 한 번 더 나가는 것은 그 스킬의 묶음이 제 손으로 한다) · mark = 표식을 남기는 타인가(묶음이 타마다 정한다)
function Room:kitAfter(hero, landed, x: number, y: number, sweep, power: number, mates, out, opts)
	local class, st, kit = hero.class, hero.kit, KIT[hero.class]
	local now = self.time
	-- 무니 · 수정 공명: 수정 곁에서 쓴 대검은 수정에서도 같은 범위로 한 번 더 나간다(제 타가 맞든 안 맞든)
	if sweep and class == "mooni" and Kit.level(hero, "core") > 0 then
		local share = kit.core.share * Kit.scale(hero, "core")
		for _, c in table.clone(self.crystals) do
			if c.owner == hero.id and math.abs(c.x - x) <= kit.core.near and math.abs(c.y - y) <= 50 then
				sweep(c.x, c.y, share, { proc = "reson", sx = c.x, sy = c.y })
			end
		end
	end
	if #landed == 0 then
		return
	end
	local first = landed[1].mob
	if class == "reaper" then
		-- 생기 흡수: 낫 기술의 한 타가 맞을 때마다(몇 마리가 맞든 한 번)
		local s = Kit.scale(hero, "passive")
		if s > 0 and hero.alive and hero.hp < hero.maxHp then
			-- 깊은 흡수(3차): 되찾는 체력 + · 영혼이 가득하면 그 배
			local deep, deepS = Passives.get(hero, "drain")
			local more = if deep then (1 + deep.drain * deepS) * (if hero.kit.souls >= Kit.soulMax(hero) then deep.fullMul else 1) else 1
			local heal = math.min(hero.maxHp - hero.hp, math.max(1, math.floor(hero.maxHp * kit.passive.heal / 100 * s * more + 0.5)))
			hero.hp += heal
			out.heal = (out.heal or 0) + heal
		end
	elseif class == "riven" then
		-- 표식: 베기에 맞은 적에게
		if Kit.level(hero, "core") > 0 and (not opts or opts.mark) then
			for _, l in landed do
				if not l.dead then
					self:mark(hero, l.mob, out)
				end
			end
		end
	elseif class == "mooni" then
		-- 수정이 맺힌다: 맞은 적의 발밑에
		if Kit.level(hero, "core") > 0 and self.rng:NextNumber(0, 100) < kit.core.chance then
			self:addCrystal(hero, first.x, first.y, out)
		end
		-- 달빛 칼날(3차): 대검이 맞은 횟수가 every번째일 때마다 그 타 피해의 일부가 둘레로 번진다
		local edge, edgeS = Passives.get(hero, "edge")
		if edge and hero.pass then
			for _, l in landed do
				hero.pass.edge += 1
				if hero.pass.edge % edge.every == 0 then
					for _, o in self.mobs do
						if alive(o) and math.abs(o.x - l.mob.x) <= edge.range + BODY_W and math.abs(o.y - l.mob.y) <= 20 then
							self:proc(hero, o, l.dmg * edge.edge * edgeS, "edge", l.mob.x, l.mob.y - 8, mates, out)
						end
					end
				end
			end
		end
	elseif class == "salamander" and Kit.level(hero, "core") > 0 then
		-- 열기가 오르고, 달아올라 있으면 맞은 적마다 불꽃이 한 번 더
		out.kit = true
		if Kit.gainHeat(hero) then
			local share = kit.core.share * Kit.scale(hero, "core")
			for _, l in landed do
				if alive(l.mob) then
					self:proc(hero, l.mob, l.dmg * share, "flame", l.mob.x, l.mob.y, mates, out)
				end
			end
		end
	end
	-- 온오프 사출기(켜 두었을 때). 2~4차의 강화 패시브(COMBAT.kitUp)가 하나 더 내보내고 · 번지고 튕기고 · 더 자주 더 세게 한다
	if not Kit.firing(hero) then
		return
	end
	local tg, s = kit.toggle, Kit.scale(hero, "toggle")
	local fit = RULES.dmgScale * (1 + RULES.targetBonus / 100) -- 사냥기도 보스기도 아닌 것은 누구에게나 보정이 붙은 숫자로 뜬다(skillHit과 같은 법)
	local ups = UP[class]
	-- 그 강화의 자료와 세기(배우지 않았으면 0)
	local function up(role: string)
		local def = ups[role]
		return def, if def then Hero.skillScale(hero.skills[def.id] or 0, def.max) else 0
	end
	local two, twoS = up("two")
	local fast, fastS = up("fast")
	-- 화면에 알리는 것: 배운 강화(1 = 하나 더 · 2 = 셋째 갈래 · 4 = 넷째 갈래) — 남의 화면도 그 모습으로 그린다
	local third = ups.splash or ups.hop or ups.burn or ups.pierce
	local thirdS = Hero.skillScale(hero.skills[third.id] or 0, third.max)
	local bits = (if twoS > 0 then 1 else 0) + (if thirdS > 0 then 2 else 0) + (if fastS > 0 then 4 else 0)
	local more = 1 + (fast.more or 0) * fastS
	if class == "axion" then
		-- 메아리 도끼: 도끼질이 맞은 횟수가 every번째일 때마다 그 적 머리 위에서. 겹 메아리 = 하나 더 · 울리는 메아리 = 떨어진 자리 둘레로 번진다 · 달 그림자 도끼 = 두 번째 타마다 · 더 세게
		local every = if fastS > 0 then fast.every else tg.every
		for _, l in landed do
			st.n += 1
			if st.n % every == 0 and alive(l.mob) then
				local base = l.dmg * tg.share * s * more
				self:proc(hero, l.mob, base, "echo", l.mob.x, l.mob.y - 60, mates, out, { i = 0, up = bits })
				if twoS > 0 and alive(l.mob) then
					self:proc(hero, l.mob, base * two.share * twoS, "echo", l.mob.x, l.mob.y - 60, mates, out, { i = 1, up = bits })
				end
				if thirdS > 0 then
					for _, o in self.mobs do
						if o ~= l.mob and alive(o) and math.abs(o.x - l.mob.x) <= third.range + BODY_W and math.abs(o.y - l.mob.y) <= 20 then
							self:proc(hero, o, base * third.share * thirdS, "splash", l.mob.x, l.mob.y, mates, out)
						end
					end
				end
			end
		end
	elseif class == "riven" then
		-- 그림자 표창: 확률로, 가까운 다른 적(없으면 그 적)에게 — 표식을 남긴다. 쌍표창 = 맞은 적에게도 하나 · 되돌아오는 표창 = 한 번 튕긴다 · 피의 표창 = 확률이 오르고 표식이 있는 적에게 더 세다
		local chance = tg.chance + (if fastS > 0 then (fast.chance - tg.chance) * fastS else 0)
		local function throw(target, dmg: number, i: number, fromX: number, fromY: number)
			local marked = target.marks ~= nil and (target.marks[hero.id] or 0) > self.time
			local hit = dmg * (if marked then 1 + fast.marked * fastS else 1)
			self:proc(hero, target, hit, "star", fromX, fromY, mates, out, { i = i, up = bits })
			if alive(target) and Kit.level(hero, "core") > 0 then
				self:mark(hero, target, out)
			end
			if thirdS > 0 then
				local nextOne = self:nearestMob(target.x, target.y, third.range, target)
				if nextOne then
					self:proc(hero, nextOne, hit * third.share * thirdS, "star", target.x, target.y - 10, mates, out, { i = i, hop = true, up = bits })
					if alive(nextOne) and Kit.level(hero, "core") > 0 then
						self:mark(hero, nextOne, out)
					end
				end
			end
		end
		for _, l in landed do
			if self.rng:NextNumber(0, 100) < chance then
				local base = l.dmg * tg.share * s
				local target = self:nearestMob(l.mob.x, l.mob.y, tg.range, l.mob) or (if alive(l.mob) then l.mob else nil)
				if target then
					throw(target, base, 0, hero.x, hero.y - 12)
				end
				if twoS > 0 and alive(l.mob) then
					throw(l.mob, base * two.share * twoS, 1, hero.x, hero.y - 6)
				end
			end
		end
	elseif class == "salamander" then
		-- 불티: 맞을 때마다, 가까운 다른 적(없으면 그 적)에게. 겹불티 = 달아오름 동안 하나 더 · 옮겨붙는 불티 = 옆의 적으로 한 번 · 불새 = 더 세게
		local function throw(target, dmg: number, i: number, fromX: number, fromY: number)
			self:proc(hero, target, dmg, "ember", fromX, fromY, mates, out, { i = i, up = bits })
			if thirdS > 0 then
				local nextOne = self:nearestMob(target.x, target.y, third.range, target)
				if nextOne then
					self:proc(hero, nextOne, dmg * third.share * thirdS, "ember", target.x, target.y - 10, mates, out, { i = i, hop = true, up = bits })
				end
			end
		end
		for _, l in landed do
			local target = self:nearestMob(l.mob.x, l.mob.y, tg.range, l.mob) or (if alive(l.mob) then l.mob else nil)
			if target then
				local base = l.dmg * tg.share * s * more
				throw(target, base, 0, l.mob.x, l.mob.y - 10)
				if twoS > 0 and Kit.hot(hero) and alive(target) then
					throw(target, base * two.share * twoS, 1, l.mob.x, l.mob.y - 10)
				end
			end
		end
	elseif class == "reaper" then
		-- 도깨비불: cd초에 한 번, 맞은 적(쓰러졌으면 가까운 적)에게. 떼도깨비불 = 영혼 둘마다 하나 더 · 붙는 불 = 붙어서 초마다 태운다 · 원혼 = 더 자주(초당 피해는 그대로) · 더 세게
		local cd = tg.cd - (if fastS > 0 then (tg.cd - fast.cd) * fastS else 0)
		if now - st.at >= cd then
			local list = {}
			for _, mob in self.mobs do
				if alive(mob) and math.abs(mob.x - first.x) <= tg.range and math.abs(mob.y - first.y) <= 60 then
					table.insert(list, mob)
				end
			end
			table.sort(list, function(p, q)
				return math.abs(p.x - first.x) < math.abs(q.x - first.x)
			end)
			if #list > 0 then
				st.at = now
				local n = if twoS > 0 then math.min(two.max, 1 + math.floor(st.souls / 2)) else 1
				for i = 0, n - 1 do
					local target = list[i % #list + 1]
					if alive(target) then
						local roll = 1 + self.rng:NextNumber(-RULES.spread, RULES.spread) / 100
						local dmg = power * tg.mul * (cd / tg.cd) * s * more * fit * roll * (if i == 0 then 1 else two.share * twoS)
						self:proc(hero, target, dmg, "wisp", hero.x + (i - n / 2) * 6, hero.y - 20 - (i % 2) * 6, mates, out, { i = i, n = n, up = bits })
						if thirdS > 0 then
							for k = 1, third.ticks do
								self:later(hero, k, function(o2)
									if alive(target) and hero.alive then
										self:proc(hero, target, dmg * third.share * thirdS, "burn", target.x, target.y - 8, mates, o2)
									end
								end)
							end
						end
					end
				end
			end
		end
	elseif class == "mooni" then
		-- 수정 조각: cd초에 한 번, 내 수정마다 하나(수정이 없으면 대검에서 하나) — 가까운 적에게. 쌍조각 = 하나 더 · 꿰뚫는 조각 = 뒤의 적까지 · 수정 검 = 더 자주(초당 피해는 그대로) · 더 세게
		local cd = tg.cd - (if fastS > 0 then (tg.cd - fast.cd) * fastS else 0)
		if now - st.at >= cd then
			local sources = {}
			for _, c in self.crystals do
				if c.owner == hero.id then
					table.insert(sources, { c.x, c.y - 12, c.y })
				end
			end
			if #sources == 0 then
				sources = { { hero.x, hero.y - 14, hero.y } }
			end
			for _, src in sources do
				local target = self:nearestMob(src[1], src[3], tg.range, nil)
				if target then
					st.at = now
					for i = 0, if twoS > 0 then 1 else 0 do
						if not alive(target) then
							break
						end
						local roll = 1 + self.rng:NextNumber(-RULES.spread, RULES.spread) / 100
						local dmg = power * tg.mul * (cd / tg.cd) * s * more * fit * roll * (if i == 0 then 1 else two.share * twoS)
						local dirTo = if target.x >= src[1] then 1 else -1
						local tx, ty = target.x, target.y
						self:proc(hero, target, dmg, "shard", src[1], src[2], mates, out, { i = i, up = bits })
						if thirdS > 0 then
							-- 꿰뚫는다: 그 적 뒤(날아가는 쪽)의 적들
							local behind = {}
							for _, mob in self.mobs do
								if mob ~= target and alive(mob) and (mob.x - tx) * dirTo > 0 and math.abs(mob.x - tx) <= third.range and math.abs(mob.y - ty) <= 30 then
									table.insert(behind, mob)
								end
							end
							table.sort(behind, function(p, q)
								return math.abs(p.x - tx) < math.abs(q.x - tx)
							end)
							for k = 1, math.min(third.n, #behind) do
								self:proc(hero, behind[k], dmg * third.share * thirdS, "pierce", tx, ty - 10, mates, out)
							end
						end
					end
				end
			end
		end
	end
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
	-- 떨어지는 것은 모두 방의 드롭 난수로 굴린다(졸개의 움직임을 굴리는 난수와 따로 — 드롭의 확률을 고쳐도 싸움의 흐름이 달라지지 않는다)
	local lootRng = self.lootRng or self.rng
	local item = Items.rollDrop(lootRng, mob.lv, hero.class, mul)
	if item then
		table.insert(out, self:addDrop({ kind = "gear", item = item, amount = 1 }, mob.x + (#out + 1) * 9, mob.y, hero.id))
	end
	local dust = Items.rollDust(lootRng, mob.lv, mul)
	if dust then
		table.insert(out, self:addDrop({ kind = "dust", amount = dust }, mob.x + (#out + 1) * 9, mob.y, hero.id))
	end
	-- 재료(그 레벨대의 광석 · 가죽)와 낮은 확률의 귀한 것(물약 · 귀환 주문서): 가방에 들어가는 아이템이 제 그림 그대로 떨어진다(kind = "goods")
	local function goods(id: string)
		local g = Items.goods(id)
		if g then
			table.insert(out, self:addDrop({ kind = "goods", goods = id, amount = 1, name = g.name, icon = g.icon }, mob.x + (#out + 1) * 9, mob.y, hero.id))
		end
	end
	for _, id in Items.rollMats(lootRng, mob.lv, mul) do
		goods(id)
	end
	for _, id in Items.rollRare(lootRng, mob.lv, mul) do
		goods(id)
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
	-- 퀘스트의 물건은 그 퀘스트를 하는 사람의 것이다(시간이 지나도 남이 줍지 못한다). 주우면 가방의 기타 탭에 들어간다 — 퀘스트의 숫자는 부른 쪽이 가방에 맞춘다(Hero.syncQuests)
	if d.kind == "quest" and d.owner ~= hero.id then
		return nil, "남의 것"
	end
	if d.kind == "quest" or d.kind == "goods" then
		local ok, why = Bag.give(hero, d.goods, d.amount)
		if not ok then
			return nil, why
		end
	elseif d.kind == "gear" then
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
		-- 일곱째 · 여덟째 = 묶인 시간 · 넘어진 시간(초 — 없으면 0): 화면이 휘감는 기운 · 수정 감옥을 그린다
		-- 아홉째 = 스토리 보스가 지금 하는 패턴의 차례(없으면 0): 화면이 예고와 이펙트를 그린다
		-- 열째 = 겨눈 자리(도약이 내려앉을 데 · 불씨가 떨어질 데 — 없으면 0) · 열한째 = 연속기의 차례(0이면 연속기가 아니다) · 열두째 = 지금 패턴이 그 연속기의 quick배로 빠른가(1 — 연속기의 둘째부터)
		list[i] = { mob.id, math.floor(mob.x * 10 + 0.5) / 10, mob.dir, mob.state, math.floor(mob.t * 100 + 0.5) / 100, mob.hp, math.floor((mob.bind or 0) * 10 + 0.5) / 10, math.floor((mob.stun or 0) * 10 + 0.5) / 10, mob.pat or 0, math.floor((mob.aim or 0) + 0.5), mob.chainPat or 0, if (mob.quick or 1) ~= 1 then 1 else 0 }
	end
	return list
end

-- 2~4차의 스킬을 재 볼 때 쓰는 빈 방: 졸개 하나가 (x, y)에 서 있다(쓰러지지 않는다). 방과 그 졸개를 돌려준다(sim/caster.luau의 profile)
Caster.makeDry = function(x: number, y: number)
	local dry = setmetatable({ key = "dry", scene = nil, rng = Random.new(7), time = 0, mobs = {}, shots = {}, drops = {}, crystals = {}, nextId = 1 }, Room)
	local mob = { id = 1, kind = "trainee", def = COMBAT.mobs.trainee, lv = 1, homeX = x, y = y, a = x - 2000, b = x + 2000, x = x, dir = -1, state = "idle", t = 0, hp = 1e12, maxHp = 1e12, cd = 0, wait = 0, goal = x, aggro = 0, struck = false, respawn = 0 }
	dry.mobs[1] = mob
	return dry, mob
end

-- 방에 들어온 사람에게 한 번 주는 것(졸개의 종류 · 레벨 · 체력, 떨어져 있는 것). heroId = 그 사람 — 남의 퀘스트 물건은 보여 주지 않는다
function Room:describe(heroId: any?)
	local mobs, drops = {}, {}
	for i, mob in self.mobs do
		mobs[i] = { id = mob.id, kind = mob.kind, lv = mob.lv, y = mob.y, maxHp = mob.maxHp, name = mob.def.name, boss = mob.boss or nil }
	end
	for _, d in self.drops do
		if d.kind == "quest" and d.owner ~= heroId then
			continue
		end
		table.insert(drops, Room.dropView(d))
	end
	local crystals = {}
	for i, c in self.crystals do
		crystals[i] = Room.crystalView(c, self.time)
	end
	return { key = self.key, mobs = mobs, drops = drops, crystals = crystals, snap = self:snapshot() }
end

return Room
