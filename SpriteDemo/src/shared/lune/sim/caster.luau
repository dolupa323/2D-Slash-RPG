-- 2~4차의 쓰는 스킬(사냥기 · 보스기 · 따로 쓰는 공격기 · 큰 기술 · 바인드 · 회복)을 서버에서 돌린다.
--  사용자 2026-10-08: "2~4차 사출기, 설치기, 버프 다 옮겨야합니다" → "작업 이어서 하세요"(남은 2~4차).
--  동작과 판정은 직업 묶음(shared/lune/kits — 공방 시험 탭의 kits/*.js를 줄마다 옮긴 것)의 그 스킬이다. 화면(client/lune/cast.luau)은 같은 묶음을 "보이기만" 돌리고,
--  여기서는 "진짜로" 돌린다: g.hit · g.hitAt · g.hurt가 피해를 주고, g.bind가 묶고, g.teleport가 자리를 옮기고, g.s의 영혼 · 열기 · 수정은 캐릭터 · 방의 것이다.
--  구간은 화면이 잇는다(Skill 패킷 — 누르고 있는 구간을 뗀 때 · 이어 누른 때 · 땅에 닿은 때는 화면만 안다). 여기서는 그 구간이 너무 이르지 않은지만 보고,
--  구간 안의 일(장 번호에 걸린 타 · 되풀이 타 · 늦게 터지는 것 · 날아가는 것)은 서버의 시간으로 터뜨린다.
--  피해: 묶음에 적힌 값(3 · 6 · 12 …)은 "몫"이다. 스킬마다 빈 방에서 열 번 써 보고(profile) "붙어 있는 적 한 마리가 다 맞았을 때의 몫의 합 W"와 "한 번 쓰는 시간 T"를 재서,
--   몫 w인 타의 피해 = 스탯 공격력(2026-10-15 — 예전의 전투력) x rate x (T + cdTime) x 스킬 레벨의 세기 x w / W — 그 합이 설계의 피해(공방 design/combat.js의 CASTRULE)가 된다.
--  사출기 · 표식 · 영혼 · 열기 · 수정처럼 "맞힌 뒤에 따라붙는 것"은 묶음의 onHit이 아니라 1차와 같은 길(Room:kitAfter — 수치는 KIT1 · KITUP)로 붙는다.
local root = script.Parent.Parent
local COMBAT = require(root.data["combat.generated"])
local CHARS = require(root.data["chars.generated"])
local G = require(root.config.game)
local Kitset = require(root.kitset)
local Hero = require(script.Parent.hero)
local Kit = require(script.Parent.kit)
local Buffs = require(script.Parent.buffs)
local Passives = require(script.Parent.passives)
local Physics = require(script.Parent.physics)
local Lines = require(script.Parent.lines) -- 타수 나누기(한 타를 여러 줄로)

local CAST = COMBAT.cast
local RULE = COMBAT.castRule
local RULES = COMBAT.rules
local KIT = COMBAT.kit

local floor, max, min, abs, sqrt, sin = math.floor, math.max, math.min, math.abs, math.sqrt, math.sin
local SUB = 1 / 60 -- 한 걸음을 이보다 잘게 나눠 돌린다(빠르게 날아가는 것이 적을 건너뛰지 않게)
local GRACE = 0.3 -- 구간이 제 시간을 다 쓴 뒤 다음 구간의 알림을 기다리는 시간(초)
local EARLY = 0.15 -- 화면의 시계가 이만큼 앞서 있어도 받는다(초)
local BIG_W = 12 -- 센 타격으로 치는 몫(시험 탭: 12 넘는 피해는 직업의 밝은 색으로 뜬다)
local PULL = 1 / 3.9 -- 시험 탭의 끌어당기는 빠르기(도트/초 — 0.02^t로 줄어든다)를 옮겨지는 거리로 바꾼다(1 / ln 50)
local TRIALS = 10 -- 재 볼 때 쓰는 횟수(다섯 번째마다 터지는 것 같은 것까지 고르게 든다)
local EMPTY = {}
local NOOP = function() end
local FX = setmetatable({}, {
	__index = function()
		return NOOP
	end,
})
local TONE = { n = 0, l = 0, w = 0, d = 0 }

local Caster = {}
Caster.__index = Caster
Caster.data = CAST
Caster.makeDry = nil :: any -- 재 볼 때 쓰는 빈 방을 짓는 함수(sim/room.luau가 넣어 준다 — 여기서 방을 부르면 서로 물린다)

local function aliveMob(m): boolean
	return m.state ~= "dead" and m.state ~= "gone" and m.state ~= "spawn"
end

function Caster.is(id: any): boolean
	return typeof(id) == "string" and CAST[id] ~= nil
end

-- ---------- 구간의 시간 ----------
local function lastFrame(who: string, s): number
	if s.to then
		return s.to
	end
	local clip = CHARS.chars[who].clips[s.clip]
	return if clip then #clip.frames - 1 else 0
end
-- 그 구간의 동작을 한 번 트는 시간(초 — 공격 속도를 곱하기 전)
local function segTime(who: string, s): number
	return (lastFrame(who, s) - (s.from or 0) + 1) / (s.fps or 14)
end
Caster.segTime = segTime
Caster.lastFrame = lastFrame

-- 힘을 모으는 구간: 한 단계가 모이는 시간 · 모을 수 있는 단계(배우지 않았으면 0)
local function chargeOf(hero, s): (number, number)
	local core = KIT[hero.class].core
	if not core.bonus or (hero.skills[core.id] or 0) < 1 then
		return s.per or RULE.charge, 0
	end
	return s.per or RULE.charge, Kit.chargeLevels(hero) -- 깊은 호흡(3차)을 배우면 3단계
end
Caster.chargeOf = chargeOf

-- 그 구간이 스스로 끝나는 때 · 다음 구간으로 넘어갈 수 있는 가장 이른 때(구간의 시간으로 — 공격 속도를 곱한 뒤의 흐름)
local function segLimit(hero, s): number
	if s.loop then
		return s.dur
	elseif s.hold then
		return s.max or 3
	elseif s.charge then
		local per, levels = chargeOf(hero, s)
		return segTime(hero.class, s) + per * levels
	elseif s.till then
		return s.max or 1.5
	end
	return segTime(hero.class, s)
end
local function segNeed(hero, s): number
	if s.loop then
		return s.dur
	elseif s.hold then
		return s.min or 0.15
	elseif s.till then
		return 0
	end
	return segTime(hero.class, s)
end

-- ---------- 방마다 하나 ----------
function Caster.new(room)
	local self = setmetatable({}, Caster)
	self.room = room
	self.actors = {} -- [캐릭터] = 그 사람의 손잡이와 쓰는 중인 스킬
	self.timers = {}
	self.shots = {}
	self.events = {} -- 방의 한 걸음에 실어 보낼 일(체력이 찬 사람 …)
	self.errors = {} -- 묶음의 코드가 낸 오류(테스트가 본다)
	self.probe = nil :: any -- 재는 중(빈 방): 피해를 주지 않고 몫만 받아 적는다 fn(mob, w, o)
	self.dry = false -- 재는 중: 몸의 움직임(뛰기 · 밀고 나가기)을 여기서 흉내 낸다
	return self
end

local function newOut()
	return { hits = {}, kills = {} }
end

-- 직업 묶음이 읽는 값을 졸개에 얹는다(시험 탭의 졸개와 같은 이름): h 뜬 높이(게임에는 없다 — 0) · boss · dead(쓰러졌으면 0 이상) · max · 걸린 것들
local function dress(m)
	m.h = m.alt or 0 -- 나는 몬스터는 떠 있는 높이(방이 셈한다 — room.luau)
	m.boss = m.def.boss == true
	m.dead = if aliveMob(m) then -1 else 0
	m.max = m.maxHp
	m.mark = m.mark or 0
	m.markT = m.markT or 0
	m.bind = m.bind or 0
	m.bindImm = m.bindImm or 0
	m.stun = m.stun or 0
	m.rend = m.rend or 0
	m.cracks = m.cracks or 0
end

function Caster:syncMobs()
	for _, m in self.room.mobs do
		dress(m)
	end
end

-- 묶음의 코드에 들어가기 전 · 나온 뒤: 리븐의 표식은 사람마다 따로라(mob.marks[그 사람]) 그 사람의 것을 졸개의 mark에 비춰 주고, 묶음이 지운 것(터뜨렸다)을 받아 적는다.
--  무니의 수정은 묶음이 dead로 적은 것(금 간 수정이 한 번 더 터졌다)을 방에서 치운다
function Caster:enter(a)
	if a.hero.class == "riven" then
		local now, id = self.room.time, a.hero.id
		for _, m in self.room.mobs do
			local till = m.marks and m.marks[id] or 0
			m.mark = if aliveMob(m) then self.room:marksOf(a.hero, m) else 0 -- 깊은 표식을 배웠으면 셋까지 겹친다
			m.markT = max(0, till - now)
			m.markWas = m.mark
		end
	end
end

function Caster:leave(a)
	local hero, room = a.hero, self.room
	if hero.class == "riven" then
		for _, m in room.mobs do
			if (m.markWas or 0) > 0 and m.mark <= 0 and m.marks then
				m.marks[hero.id] = nil -- 묶음이 표식을 태웠다(터뜨렸다)
				if m.markN then
					m.markN[hero.id] = nil
				end
			end
			m.mark, m.markWas = 0, nil
		end
	elseif hero.class == "mooni" then
		for i = #room.crystals, 1, -1 do
			local c = room.crystals[i]
			if c.dead and c.owner == hero.id then
				table.remove(room.crystals, i)
				table.insert(self.events, { type = "crystalGone", id = c.id })
			end
		end
	end
end

-- 묶음의 함수 하나를 그 스킬의 것으로 부른다(ctx = 그 타가 어느 스킬의 것인가 — 늦게 터지는 것 · 날아가는 것은 스킬이 끝난 뒤에도 제 스킬의 세기로 친다)
function Caster:run(a, ctx, fn, ...)
	local prev = a.ctx
	a.ctx = ctx
	self:enter(a)
	local ok, err = pcall(fn, ...)
	if not ok then
		table.insert(self.errors, tostring(err))
		warn("[lune] 스킬 " .. tostring(ctx and ctx.id) .. ": " .. tostring(err))
	end
	self:leave(a)
	a.ctx = prev
end

-- ---------- 피해 ----------
-- 2~4차의 쓰는 스킬의 레벨에 따른 세기: 레벨 1에서 RULE.floor(78.6%) → 마스터에서 1(배우지 않았으면 0).
--  사용자 2026-10-08: "당연히 1차 마스터보다 2차 1레벨 스킬이 강해야합니다. 이건 기본이에요" — 새 차수의 스킬은 레벨 1에서 앞 차수의 같은 갈래 스킬을 마스터한 것의 1.1배,
--  마스터하면 1.4배다(공방 design/combat.js의 CASTRULE: 차수의 배수 = 1.4^(차수 − 1) · floor = 1.1 ÷ 1.4). 1차의 스킬 · 버프 · 패시브는 그대로 40% → 100%(Hero.skillScale)
local function castScale(lv: number, max: number): number
	if lv <= 0 then
		return 0
	end
	return RULE.floor + (1 - RULE.floor) * (if max > 1 then (lv - 1) / (max - 1) else 1)
end
Caster.scale = castScale

-- 그 스킬의 몫 1의 세기(전투력에 곱한다). lv = 모은 단계
local function unitOf(hero, id: string, lv: number): number
	local def = CAST[id]
	local base = Caster.profile(id, 0)
	local p = if lv > 0 then Caster.profile(id, lv) else base
	local scale = castScale(hero.skills[id] or 0, def.max)
	local core = KIT[hero.class].core
	local charge = if lv > 0 and core.bonus then 1 + lv * Kit.chargeBonus(hero.skills[core.id] or 0, COMBAT.kitSkill[core.id].max) else 1
	return def.rate * (base.time + def.cdTime) * scale * charge / p.w
end

-- 그 스킬의 한 타를 몇 줄로 적는가(타수 나누기 — sim/lines.luau): 빈 방에서 잰 「붙어 있는 적 한 마리가 한 번 쓸 때 맞는 타의 수」로. 극딜기(큰 기술 — nuke)는 더 많이
function Caster.lines(id: string): number
	local def = CAST[id]
	if not def then
		return 1
	end
	return Lines.count(Caster.profile(id, 0).hits, def.type == "nuke", def.job) -- 차수마다 줄의 수가 다르다
end

function Caster:context(a, id: string, lv: number, mates)
	local def = CAST[id]
	return { id = id, lv = lv, kind = if def.type == "mob" or def.type == "boss" then def.type else nil, unit = if self.probe then 1 else unitOf(a.hero, id, lv), lines = if self.probe then 1 else Caster.lines(id), mates = mates }
end

-- 졸개 하나에게 몫 w의 타. 맞았으면 true(landed에 적는다)
function Caster:strike(a, m, w: number, o, landed): boolean
	if not aliveMob(m) then
		return false
	end
	local hero, room, ctx = a.hero, self.room, a.ctx
	-- 끌어당기기 · 넘어뜨리기: 보통 적만(묶인 적은 빼고)
	if not m.def.boss and (m.bind or 0) <= 0 then
		if o.pull then
			local toward = if m.x > hero.x then -1 else 1
			m.x = math.clamp(m.x + toward * min(o.pull * PULL, max(0, abs(m.x - hero.x) - 10)), m.a, m.b)
		end
		if o.stun then
			m.stun = max(m.stun or 0, o.stun)
		end
	end
	if w <= 0 then
		return true
	end
	if self.probe then
		self.probe(m, w, o)
		return true
	end
	if not ctx then
		return false
	end
	local power = Hero.powerRaw(hero) * Kit.attack(hero) * Buffs.dmg(hero) * Passives.atk(hero)
	local roll = 1 + room.rng:NextNumber(-RULES.spread, RULES.spread) / 100
	local fit = if (ctx.kind == "mob" and m.def.boss) or (ctx.kind == "boss" and not m.def.boss) then 1 else 1 + RULES.targetBonus / 100
	-- 패시브가 그 적에게 붙이는 것(넘어진 적 · 체력 · 거리 · 이어 맞히기 · 모은 단계 · 옛 사냥기)
	local mul, crit = Passives.vs(hero, m, { skill = ctx.id, charge = ctx.lv, now = room.time }), false
	-- 치명타: 모든 직업의 기술 타가 확률로(1차와 같은 셈 — sim/room.luau의 skillHit). 흘리기 = 피한 뒤의 첫 베기는 반드시
	-- 여러 줄로 쪼개지는 타는 줄마다 따로 굴린다(sim/room.luau의 Room:strike의 crit — 흘리기의 반드시 크리티컬은 그 베기의 줄 모두)
	local critChance, critMul, sure = Passives.crit(hero, room:marksOf(hero, m) > 0)
	local perLine = not o.proc and (ctx.lines or 1) > 1 and not sure
	if sure or (not perLine and critChance > 0 and room.rng:NextNumber(0, 100) < critChance) then
		crit = true
		mul *= critMul
		if sure then
			hero.pass.sure = false
		end
	end
	local dmg = max(1, floor(power * ctx.unit * w * roll * RULES.dmgScale * fit * mul + 0.5))
	local extra = {}
	if w >= BIG_W or crit then
		extra.big = true
	end
	if crit then
		extra.crit = true
	end
	-- 밀리는 것: 미는 타(kb)만 조금 민다 — 빠르게 여러 번 치는 기술(난도질 · 난타 · 놓인 불길)이 적을 범위 밖으로 밀어내지 않게(시험 탭도 미는 타만 민다)
	local dead, dealt = room:strike(hero, m, dmg, if o.kb then hero.x else m.x, ctx.mates, a.out, extra, if o.proc then nil else ctx.lines, if perLine then { chance = critChance, mul = critMul } else nil) -- 타수 나누기: 사출기처럼 따라 나가는 타는 한 줄
	m.dead = if dead then 0 else -1
	if dead then
		m.cracks, m.bind, m.rend, m.stun, m.mark = 0, 0, 0, 0, 0
	end
	if not o.proc then
		Passives.onHit(hero, m, room.time) -- 이어 맞힌 수 · 이어 때린 수(살라맨더)
		-- 넘치는 힘(액시온 4차): 끝까지 모은 강타를 맞히면 잠깐 동안 다음 강타가 높은 단계에서 시작한다
		if (ctx.lv or 0) > 0 and not ctx.surged and ctx.lv >= Kit.chargeLevels(hero) then
			local surge = Passives.get(hero, "surge")
			if surge then
				hero.pass.surge = room.time + surge.surge
			end
		end
	end
	table.insert(landed, { mob = m, dmg = dealt, dead = dead })
	return true
end

-- 맞힌 뒤에 따라붙는 것(사출기 · 표식 · 영혼 · 열기 · 수정): 1차와 같은 길로. o.mark = 표식을 남기는 타 · o.proc = 따라붙지 않는 타
function Caster:follow(a, landed, o)
	if self.probe or o.proc or #landed == 0 or not a.ctx then
		return
	end
	local hero, room = a.hero, self.room
	local power = Hero.powerRaw(hero) * Kit.attack(hero) * Buffs.dmg(hero) * Passives.atk(hero)
	room:kitAfter(hero, landed, hero.x, hero.y, nil, power, a.ctx.mates, a.out, { mark = o.mark == true })
	if o.mark and hero.class == "riven" then
		for _, l in landed do
			local m = l.mob
			local n = room:marksOf(hero, m)
			if n > 0 then
				m.mark, m.markWas = n, n -- 방금 남긴 표식(묶음이 이어서 읽는다)
			end
		end
	end
end

function Caster:box(a, x0: number, x1: number, y0: number, y1: number, cx: number, w: number, o)
	local list = self.room:mobsInBox(x0, x1, y0, y1, cx)
	local landed = {}
	for _, m in list do
		self:strike(a, m, w, o, landed)
	end
	self:follow(a, landed, o)
	return list
end

-- ---------- 손잡이 ----------
local function makeG(self, a)
	local hero, room = a.hero, self.room
	local g = { fx = FX, s = {}, PW = if room.scene then room.scene.w * G.TILE else 4096, art = {}, authority = true }
	local GET = {
		x = function()
			return hero.x
		end,
		y = function()
			return hero.y
		end,
		dir = function()
			return hero.dir
		end,
		tone = function()
			return TONE
		end,
		ground = function()
			return if self.dry then a.ground else true
		end,
		big = function()
			return Buffs.big(hero)
		end,
		lv = function() -- 모은 단계: 그 타가 딸린 스킬의 것(늦게 터지는 것은 다른 스킬을 쓰는 중에도 제 스킬의 단계로 친다)
			return if a.ctx then a.ctx.lv elseif a.skill then a.skill.lv else 0
		end,
		held = function()
			return if a.skill then a.skill.t else 0
		end,
		clock = function()
			return room.time
		end,
		toggle = function()
			return Kit.firing(hero)
		end,
		hero = function()
			return a.body
		end,
		cam = function()
			return { x = 0, y = 0 }
		end,
	}
	setmetatable(g, {
		__index = function(_, key)
			local get = GET[key]
			return if get then get() else nil
		end,
	})
	function g.rnd(): number
		return room.rng:NextNumber()
	end
	function g.fwd(d: number): number
		return hero.x + hero.dir * d
	end
	function g.hit(from: number, to: number, up: number, down: number, w: number, o)
		local k = Buffs.big(hero) * Passives.reach(hero) -- 거신 · 낫 숙련 · 영혼 주머니: 닿는 거리(앞 · 위)가 그만큼 는다
		local x0, x1 = hero.x + hero.dir * from * k, hero.x + hero.dir * to * k
		return self:box(a, min(x0, x1), max(x0, x1), hero.y - up * k, hero.y + down, hero.x, w or 0, o or EMPTY)
	end
	function g.hitAt(x: number, y: number, hw: number, h: number, w: number, o)
		return self:box(a, x - hw, x + hw, y - h, y + 6, x, w or 0, o or EMPTY)
	end
	function g.hurt(m, w: number, o): boolean
		local landed = {}
		local ok = self:strike(a, m, w or 0, o or EMPTY, landed)
		self:follow(a, landed, o or EMPTY)
		return ok
	end
	function g.mobs()
		local out = {}
		for _, m in room.mobs do
			if aliveMob(m) then
				out[#out + 1] = m
			end
		end
		return out
	end
	function g.nearest(range: number, o)
		local from, not_, front = (o and o.from) or hero.x, o and o["not"], o and o.front
		local best, bd = nil, range
		for _, m in room.mobs do
			if not aliveMob(m) or m == not_ or abs(m.y - hero.y) > 60 or (front and (m.x - hero.x) * hero.dir < -8) then
				continue
			end
			local d = abs(m.x - from)
			if d <= bd then
				bd, best = d, m
			end
		end
		return best
	end
	function g.boss()
		local best = nil
		for _, m in room.mobs do
			if aliveMob(m) and abs(m.x - hero.x) < 280 and (not best or m.maxHp > best.maxHp) then
				best = m
			end
		end
		return best
	end
	g.shake, g.stop, g.invert, g.dim, g.ghost, g.sprite, g.call = NOOP, NOOP, NOOP, NOOP, NOOP, NOOP, NOOP
	-- 소생(무니 4차): 쓰러져 비석이 선 파티원을 그 자리에서 일으킨다 — 최대 체력의 일부로(설계 CASTRULE.heal의 revive). 쓰러진 벌칙도 없던 일이 된다
	function g.revive()
		local ctx = a.ctx
		local def = ctx and CAST[ctx.id]
		local h = def and def.heal
		if not h or not h.revive or self.probe then
			return
		end
		local share = h.revive * Hero.skillScale(hero.skills[ctx.id] or 0, def.max)
		for _, mate in ctx.fallen or {} do
			if not mate.alive and abs(mate.x - hero.x) <= h.reach and abs(mate.y - hero.y) <= 80 then
				Hero.raise(mate, share)
				table.insert(self.events, { type = "raised", hero = mate.id, by = hero.id })
			end
		end
	end
	function g.after(d: number, fn)
		table.insert(self.timers, { t = d, fn = fn, a = a, ctx = a.ctx })
	end
	function g.shot(o)
		local p = { t = 0, acc = 0, hitSet = {}, dir = hero.dir, who = hero.class, w = 0, h = 0, dmg = 0, life = 1, a = a, ctx = a.ctx }
		for k, v in o do
			p[k] = v
		end
		table.insert(self.shots, p)
		return p
	end
	-- 몸을 옮기는 것: 걷기 · 뛰기는 화면이 하고 제 자리를 알려 온다(여기서는 재 볼 때만 흉내 낸다). 순간이동은 서버도 그 자리로 옮겨 적는다 —
	--  화면이 알려 오는 자리가 멀어도 그 스킬을 쓴 직후에는 받는다(server world.luau의 onMove — 스킬을 받을 때 warpAt을 적는다)
	function g.move(v: number, t: number)
		if self.dry then
			a.imp = { v = v * hero.dir, t = t }
		end
	end
	function g.hop(v: number)
		if self.dry then
			a.body.vy, a.ground = -v, false
		end
	end
	function g.face(d: number)
		hero.dir = d
	end
	function g.teleport(x: number): boolean
		local scene = room.scene
		if scene then
			x = math.clamp(x, 8, scene.w * G.TILE - 8)
			if Physics.solidBox(scene, x, hero.y) then
				return false
			end
		end
		hero.x = x
		return true
	end
	function g.drag(m, x: number)
		if not m.def.boss and aliveMob(m) then
			m.x = math.clamp(x, m.a, m.b)
		end
	end
	function g.buff(id: string)
		local def = Buffs.data[id]
		if def and (hero.skills[id] or 0) > 0 then
			Buffs.give(hero, id, Hero.skillScale(hero.skills[id], def.max), hero.x, hero.y)
			table.insert(self.events, { type = "buffs", hero = hero.id })
		end
	end
	function g.has(id: string): boolean
		return Buffs.has(hero, id)
	end
	function g.left(id: string): number
		local b = hero.buffs[id]
		return if b then b.t else 0
	end
	function g.endBuff(id: string)
		if hero.buffs[id] then
			hero.buffs[id] = nil
			table.insert(self.events, { type = "buffs", hero = hero.id })
		end
	end
	function g.resetCd(id: string)
		if hero.cds[id] then
			hero.cds[id] = nil
			table.insert(self.events, { type = "cool", hero = hero.id, skill = id })
		end
	end
	function g.sk(id: string): number
		return hero.skills[id] or 0
	end
	-- 바인드: 풀린 뒤 한동안은 다시 묶이지 않는다. 묶인 적은 그동안 움직이지도 치지도 못한다(sim/room.luau의 stepMob)
	function g.bind(m, t: number, kind: string?): boolean
		if not aliveMob(m) or (m.bindImm or 0) > 0 then
			return false
		end
		m.bind, m.bindKind, m.bindImm = t, kind, t + RULE.bindImm
		return true
	end
	-- 회복(무니의 달빛 치유): 나와 가까운 파티원의 체력을 되돌린다 — 세기는 설계(CASTRULE.heal)의 것
	function g.heal(k: number?)
		local ctx = a.ctx
		local def = ctx and CAST[ctx.id]
		local h = def and def.heal
		if not h or self.probe then
			return
		end
		local s = Hero.skillScale(hero.skills[ctx.id] or 0, def.max) * (k or 1)
		for _, mate in ctx.mates or { hero } do
			if mate.alive and abs(mate.x - hero.x) <= h.reach and abs(mate.y - hero.y) <= 80 then
				local amount = min(mate.maxHp - mate.hp, floor(mate.maxHp * h.hp * s + 0.5))
				if amount > 0 then
					mate.hp += amount
					table.insert(self.events, { type = "healed", hero = mate.id, amount = amount, by = hero.id })
				end
			end
		end
	end
	function g.chargeMax(): number
		local _, levels = chargeOf(hero, EMPTY)
		return levels
	end
	return g
end

-- 묶음의 g.s 가운데 캐릭터 · 방의 것: 영혼 · 열기(sim/kit.luau의 h.kit) · 달 수정(방의 crystals)
local function bridge(self, a)
	local hero, room, s = a.hero, self.room, a.g.s
	rawset(s, "souls", nil)
	rawset(s, "heat", nil)
	rawset(s, "cr", nil)
	setmetatable(s, {
		__index = function(_, key)
			if key == "souls" then
				return hero.kit.souls
			elseif key == "heat" then
				return hero.kit.heat
			elseif key == "cr" then
				local list = {}
				for _, c in room.crystals do
					if c.owner == hero.id then
						c.t, c.life = 0, 1 -- 방에 있는 동안은 살아 있다(시간은 방이 센다)
						list[#list + 1] = c
					end
				end
				return list
			end
			return nil
		end,
		__newindex = function(t, key, value)
			if key == "souls" then
				if hero.kit.souls ~= value then
					hero.kit.souls, hero.kit.soulT = value, 0
					a.out.kit = true
				end
			elseif key == "heat" then
				if hero.kit.heat ~= value then
					hero.kit.heat, hero.kit.heatT = value, 0
					a.out.kit = true
				end
			elseif key ~= "cr" then
				rawset(t, key, value)
			end
		end,
	})
end

function Caster:actor(hero)
	local a = self.actors[hero]
	if a then
		return a
	end
	local kit = Kitset.of(hero.class)
	a = { hero = hero, kit = kit, skill = nil, ctx = nil, out = newOut(), body = { vx = 0, vy = 0, scale = 1, alpha = 1 }, ground = true, imp = nil, last = nil }
	a.g = makeG(self, a)
	if kit and kit.init then
		kit.init(a.g)
	end
	bridge(self, a)
	self.actors[hero] = a
	return a
end

-- 그 사람이 스킬을 쓰는 중인가(다른 기술을 시작하지 못한다)
function Caster:busy(hero): boolean
	local a = self.actors[hero]
	local sk = a and a.skill
	return sk ~= nil and not sk.done and sk.t < sk.need - EARLY
end

-- 그 사람이 스킬의 동작을 하는 중인가(굳센 자세 — 그동안은 받는 피해가 더 준다)
function Caster:acting(hero): boolean
	local a = self.actors[hero]
	return a ~= nil and a.skill ~= nil and not a.skill.done
end

-- 그 사람의 것을 모두 거둔다(방을 나갔다 · 쓰러졌다)
function Caster:drop(hero)
	local a = self.actors[hero]
	if not a then
		return
	end
	self.actors[hero] = nil
	for i = #self.timers, 1, -1 do
		if self.timers[i].a == a then
			table.remove(self.timers, i)
		end
	end
	for i = #self.shots, 1, -1 do
		if self.shots[i].a == a then
			table.remove(self.shots, i)
		end
	end
end

-- 구간을 닫는다: 다 틀고 넘어가는 구간이면 아직 안 터진 장의 일을 마저 터뜨리고(화면의 시계가 조금 앞섰을 때), 끝날 때의 일을 부른다
local function closeSeg(self, a)
	local sk = a.skill
	if not sk or sk.done then
		return
	end
	sk.done = true
	local s = sk.s
	if not (s.hold or s.charge or s.till) then
		for _, e in s.evs do
			if not sk.fired[e[1]] then
				sk.fired[e[1]] = true
				self:run(a, sk.ctx, e[2], a.g)
			end
		end
	end
	if s.finish then
		self:run(a, sk.ctx, s.finish, a.g)
	end
end

local function endSkill(self, a)
	local sk = a.skill
	if sk then
		closeSeg(self, a)
		a.last = { id = sk.id, i = sk.i, at = self.room.time, ctx = sk.ctx }
		if a.skill == sk then
			a.skill = nil
		end
	end
end

-- 그 스킬의 그 구간이 시작됐다(화면이 알렸다). 받았으면 true와 모은 단계.
--  첫 구간: 앞 스킬이 (거의) 끝났을 때만. 이어지는 구간: 바로 앞 구간이 제 시간을 (거의) 다 썼을 때만 — 누르고 있는 구간은 가장 짧은 시간, 조건을 기다리는 구간은 언제든.
--  info = 그 밖에 넘기는 것 { fallen = 쓰러져 있는 파티원들(소생이 일으킨다) }
function Caster:begin(hero, id: string, seg: number, mates, info): (boolean, number?)
	local def = CAST[id]
	local skill, kit = Kitset.skill(id)
	if not def or not skill or not kit or kit.who ~= hero.class or not hero.alive or seg ~= floor(seg) then
		return false, nil
	end
	local a = self:actor(hero)
	local cur = a.skill
	if skill.instant then
		if seg ~= 1 or (cur and self:busy(hero)) then
			return false, nil
		end
		self:run(a, self:context(a, id, 0, mates), skill.cast, a.g)
		return true, 0
	end
	local s = skill.segs and skill.segs[seg]
	if not s then
		return false, nil
	end
	local lv, ctx = 0, nil
	local surged = false -- 모으지 않고 얻은 단계(넘치는 힘) — 이 타로는 넘치는 힘이 다시 켜지지 않는다
	if seg == 1 then
		if cur then
			if self:busy(hero) then
				return false, nil
			end
			endSkill(self, a)
		end
		ctx = self:context(a, id, 0, mates)
		ctx.fallen = info and info.fallen
	else
		local prev = skill.segs[seg - 1]
		if cur and cur.id == id and cur.i == seg - 1 then
			if cur.t < cur.need - EARLY then
				return false, nil -- 앞 구간이 아직 한창이다
			end
			if prev.charge then
				-- 모은 단계는 서버가 흐른 시간으로 셈한다(화면이 말한 단계를 믿지 않는다). 만월 동안에는 모으지 않아도 끝까지 모은 것으로 친다
				local per, levels = chargeOf(hero, prev)
				lv = if Buffs.full(hero) then levels else math.clamp(floor((cur.t - segTime(hero.class, prev)) / per + 0.08), 0, levels)
				-- 넘치는 힘(액시온 4차): 끝까지 모은 강타를 맞힌 직후에는 모으지 않아도 높은 단계에서 시작한다(한 번 쓰면 사라진다)
				local surge = Passives.get(hero, "surge")
				if surge and levels > 0 and hero.pass.surge > self.room.time and lv < surge.surgeFrom then
					lv = min(surge.surgeFrom, levels)
					hero.pass.surge = -1e9
					surged = true
				end
			end
			ctx = cur.ctx
			closeSeg(self, a)
		elseif not cur and a.last and a.last.id == id and a.last.i == seg - 1 and self.room.time - a.last.at <= GRACE + 0.2 then
			ctx = a.last.ctx -- 앞 구간이 막 끝났다(알림이 조금 늦었다)
		else
			return false, nil
		end
		if lv > 0 or not ctx then
			ctx = self:context(a, id, lv, mates)
			ctx.surged = surged
		end
	end
	local sk = { id = id, def = skill, i = seg, s = s, t = 0, lv = lv, fired = {}, acc = 0, ctx = ctx, limit = segLimit(hero, s), need = segNeed(hero, s), done = false, wait = 0 }
	a.skill = sk
	if s.start then
		self:run(a, ctx, s.start, a.g)
	end
	return true, lv
end

-- ---------- 한 걸음 ----------
function Caster:sub(h: number)
	local room = self.room
	self:syncMobs()
	-- 늦게 터지는 것
	local timers = self.timers
	for i = #timers, 1, -1 do
		local t = timers[i]
		t.t -= h
		if t.t <= 0 then
			table.remove(timers, i)
			self:run(t.a, t.ctx, t.fn)
		end
	end
	-- 쓰는 중인 스킬: 구간의 장 번호에 맞춰 일을 터뜨린다
	for hero, a in self.actors do
		local sk = a.skill
		if self.dry then
			-- 재는 중: 몸의 움직임을 흉내 낸다(밀고 나가기 · 뛰었다 떨어지기)
			if a.imp then
				hero.x += a.imp.v * h
				a.imp.t -= h
				if a.imp.t <= 0 then
					a.imp = nil
				end
			end
			if not a.ground then
				a.body.vy = min(a.body.vy + G.GRAVITY * h, G.MAX_FALL)
				hero.y += a.body.vy * h
				if a.body.vy >= 0 and hero.y >= a.floor then
					hero.y, a.body.vy, a.ground = a.floor, 0, true
				end
			end
		end
		if not sk then
			continue
		end
		if not hero.alive then
			a.skill = nil
			continue
		end
		local s = sk.s
		if sk.done then
			sk.wait += h
			if sk.wait >= GRACE then
				endSkill(self, a)
			end
			continue
		end
		local haste = if s.charge then 1 else Buffs.haste(hero) -- 공격 속도 버프: 동작 · 타격 시점 · 되풀이 타격 간격이 빨라진다(힘 모으기 구간은 그대로)
		sk.t += h * haste
		local f = (s.from or 0) + floor(sk.t * (s.fps or 14))
		for _, e in s.evs do
			if f >= e[1] and not sk.fired[e[1]] then
				sk.fired[e[1]] = true
				self:run(a, sk.ctx, e[2], a.g)
			end
		end
		if s.every and a.skill == sk then
			sk.acc += h * haste
			while sk.acc >= s.every[1] and a.skill == sk do
				sk.acc -= s.every[1]
				self:run(a, sk.ctx, s.every[2], a.g)
			end
		end
		if a.skill == sk and sk.t >= sk.limit then
			closeSeg(self, a) -- 제 시간을 다 썼다: 다음 구간의 알림을 조금 기다린다
		end
	end
	-- 날아가는 것 · 놓인 것(시험 탭의 그 줄들)
	local shots = self.shots
	for i = #shots, 1, -1 do
		local p = shots[i]
		local a = p.a
		p.t += h
		if p.target then -- 쫓아가는 것: 닿으면 onReach
			local tm = p.target
			local tx, ty = tm.x, tm.y - (if tm.def.boss then 14 else 7)
			local d = sqrt((tx - p.x) ^ 2 + (ty - p.y) ^ 2)
			if not aliveMob(tm) then
				table.remove(shots, i)
				continue
			end
			if d < 6 then
				if p.onReach then
					self:run(a, p.ctx, p.onReach, p)
				end
				table.remove(shots, i)
				continue
			end
			local sp = (p.speed or 200) * h
			p.x += ((tx - p.x) / d) * sp
			p.y += ((ty - p.y) / d) * sp + (p.curl or 0) * sin(p.t * 12) * h
		else
			if p.g then
				p.vy = (p.vy or 0) + p.g * h
			end
			p.x += (p.vx or 0) * h
			p.y += (p.vy or 0) * h
		end
		if p.update then
			self:run(a, p.ctx, p.update, p, h)
		end
		if p.every then
			p.acc += h
			while p.acc >= p.every[1] do
				p.acc -= p.every[1]
				self:run(a, p.ctx, p.every[2], p)
			end
		end
		if p.dmg ~= 0 then
			for _, m in room.mobs do
				-- 몸의 크기: 병사는 반폭 7 · 높이 12. 새 몬스터는 종류마다 다르다(def.body · lift) · 나는 몬스터는 뜬 높이만큼 위에 있다
				local hh, hw, up = if m.def.boss then 26 else 12, 7, 0
				if m.def.body then
					hw, up, hh = m.def.body[1] / 2 + 1, (m.def.lift or 0) + (m.alt or 0), m.def.body[2]
				end
				if not aliveMob(m) or abs(m.x - p.x) > p.w / 2 + hw or m.y - up < p.y - p.h / 2 - 2 or m.y - up - hh > p.y + p.h / 2 then
					continue
				end
				local was = p.hitSet[m]
				if was ~= nil and not (p.tick and p.t - was >= p.tick) then
					continue
				end
				p.hitSet[m] = p.t
				self:run(a, p.ctx, function()
					local o = p.o or EMPTY
					local landed = {}
					self:strike(a, m, p.dmg, o, landed)
					self:follow(a, landed, o)
					if p.onHit then
						p.onHit(p, m)
					end
				end)
			end
		end
		-- 벽 · 땅에 닿으면 끝난다(재는 빈 방에는 칸이 없다 — 발밑 높이를 땅으로 친다)
		local wall = ((p.vx or 0) ~= 0 or (p.vy or 0) ~= 0) and not p.ghost
		if wall then
			if room.scene then
				wall = Physics.cell(room.scene, floor(p.x / G.TILE), floor(p.y / G.TILE)) == "#"
			else
				wall = self.dry and a.floor ~= nil and p.y >= a.floor
			end
		end
		if p.dead or p.t >= p.life or wall then
			if p.finish then
				self:run(a, p.ctx, p.finish, p, wall)
			end
			table.remove(shots, i)
		end
	end
end

-- 방의 한 걸음(heroes = 지금 방에 있는 사람들 { [번호] = 캐릭터 }). 일어난 일을 events에 적는다: "kit"(맞은 것 · 잡은 것 — 그 사람의 일) · "healed" · "buffs" · "crystalGone"
function Caster:step(heroes, dt: number, events)
	local here = {}
	for _, h in heroes do
		here[h] = true
	end
	for hero in self.actors do
		if not here[hero] then
			self:drop(hero)
		end
	end
	if next(self.actors) == nil then
		return
	end
	local n = max(1, math.ceil(dt / SUB - 1e-6))
	for _ = 1, n do
		self:sub(dt / n)
	end
	self:flush(events)
end

-- 모인 결과를 일로 내보낸다(구간이 시작될 때 바로 터진 것도 여기서 나간다)
function Caster:flush(events)
	for hero, a in self.actors do
		local out = a.out
		if #out.hits > 0 or #out.kills > 0 or out.kit or out.heal or out.crystals or out.crystalGone then
			table.insert(events, { type = "kit", hero = hero.id, result = out })
			a.out = newOut()
		end
	end
	for _, e in self.events do
		table.insert(events, e)
	end
	table.clear(self.events)
end

-- ---------- 재 보기 ----------
-- 그 스킬을 빈 방에서 열 번 써 보고 잰다: time = 한 번 쓰는 데 걸리는 시간(초) · w = 붙어 있는 적 한 마리가 다 맞았을 때의 몫의 합 · hits = 맞는 횟수.
--  화면이 하는 일(구간 잇기)을 흉내 낸다: 이어 누르는 구간은 바로 누르고, 누르고 있는 구간은 가장 짧게, 모으는 구간은 lv단계까지만 모은다.
--  캐릭터는 그 스킬만 배운 모습이다(영혼 · 열기 · 표식 · 수정 없음) — 장치가 얹는 것은 여기에 들지 않는다. 설계가 따로 정한 값(CAST의 w · time)이 있으면 그것을 쓴다
local PROFILE = {}
local X0, Y0 = 2000, 176

-- 화면이 하는 일(구간 잇기)을 흉내 내어 그 스킬을 한 번 쓴다 — 재 볼 때와 테스트가 쓴다(self.dry = true인 방에서). 걸린 시간(초)을 돌려준다.
--  이어 누르는 구간은 바로 누르고, 누르고 있는 구간은 hold초(없으면 가장 짧게), 모으는 구간은 lv단계까지만 모은다. tick() = 방의 시간을 SUB만큼 흘리고 self:sub(SUB)를 부르는 함수
function Caster:dryCast(hero, id: string, lv: number, tick, hold: number?): number
	local skill = Kitset.skill(id)
	local a = self:actor(hero)
	a.floor = a.floor or hero.y
	a.ground, a.body.vy, a.imp = true, 0, nil
	if skill.instant then
		self:run(a, self:context(a, id, 0, nil), skill.cast, a.g)
		return 0
	end
	assert(self:begin(hero, id, 1, nil), "시작하지 못했다 " .. id)
	local t, st = 0, 0 -- st = 이 구간에 들어선 뒤 흐른 시간
	a.skill.limit = math.huge -- 구간을 끝내는 것은 이쪽이다
	while a.skill and t < 12 do
		tick()
		t += SUB
		st += SUB
		local sk = a.skill
		if not sk then
			break
		end
		local s = sk.s
		local over
		if s.loop then
			over = st >= s.dur
		elseif s.hold then
			over = st >= math.max(s.min or 0.15, math.min(hold or 0, s.max or 3))
		elseif s.charge then
			over = st >= segTime(hero.class, s) + (s.per or RULE.charge) * lv + (if lv > 0 then 0.02 else 0)
		elseif s.till then
			over = s.till(a.g) or st >= (s.max or 1.5)
		else
			over = st >= segTime(hero.class, s)
		end
		if over then
			local nextS = skill.segs[sk.i + 1]
			if nextS then
				-- 다음 구간: 모은 단계는 이쪽이 정한다(시간으로 세는 것은 begin의 일이다 — 따로 테스트한다)
				closeSeg(self, a)
				local ctx = sk.ctx
				if s.charge and lv > 0 then
					ctx = self:context(a, id, lv, ctx.mates)
				end
				a.skill = { id = id, def = skill, i = sk.i + 1, s = nextS, t = 0, lv = ctx.lv, fired = {}, acc = 0, ctx = ctx, limit = math.huge, need = segNeed(hero, nextS), done = false, wait = 0 }
				st = 0
				if nextS.start then
					self:run(a, ctx, nextS.start, a.g)
				end
			else
				endSkill(self, a)
			end
		end
	end
	return t
end

local function measure(id: string, lv: number)
	local def = CAST[id]
	assert(Caster.makeDry, "재 볼 방을 짓는 함수가 없다(sim/room.luau가 넣는다)")
	local at = X0 + (def.at or 14) -- 적이 서 있는 자리: 붙어 있다(몸이 나아가거나 멀리 던지는 기술은 설계가 정한 자리 — 그 타가 떨어지는 곳)
	local room, dummy = Caster.makeDry(at, Y0)
	local self = Caster.new(room)
	self.dry = true
	local total, hits = 0, 0
	self.probe = function(m, w)
		if m == dummy then
			total += w
			hits += 1
		end
	end
	local hero = Hero.new(0, def.who)
	hero.skills = { [id] = 1 }
	local time = 0
	local function tick()
		room.time += SUB
		self:sub(SUB)
	end
	for _ = 1, TRIALS do
		hero.x, hero.y, hero.dir = X0, Y0, 1
		dummy.x, dummy.stun, dummy.bind, dummy.bindImm = at, 0, 0, 0
		time += self:dryCast(hero, id, lv, tick)
	end
	-- 남은 것(늦게 터지는 것 · 놓인 불길)이 다 끝날 때까지 돌린다
	local guard = 0
	while (#self.timers > 0 or #self.shots > 0) and guard < 20 do
		tick()
		guard += SUB
	end
	return { time = time / TRIALS, w = total / TRIALS, hits = hits / TRIALS, errors = self.errors }
end

function Caster.profile(id: string, lv: number?)
	local key = id .. ":" .. tostring(lv or 0)
	local p = PROFILE[key]
	if not p then
		local def = CAST[id]
		p = measure(id, lv or 0)
		p.measured = p.w
		if def.w then
			p.w = def.w
		end
		if def.time then
			p.time = def.time
		end
		if p.w <= 0 then
			p.w = 1 -- 빈 방에서는 맞는 것이 없는 스킬(묶기만 하는 것 · 회복)
		end
		PROFILE[key] = p
	end
	return p
end

return Caster
