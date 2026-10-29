-- 「달의 계승자」 — 주간 보스(레이드)의 설계 DPS: 4인 파티가 딜 손실 없이 낼 수 있는 초당 피해를 진짜 서버의 셈으로 잰다(2026-10-27).
--  사용자: "설계를 4인 레이드로 잡았으면 그 레이드 시간이 15분이면 그 레벨에 맞는 전직 차수 스킬 dps 랑 평균 장비 수준 계산하고 4인파티 버프 중첩같은거 계산해서
--   4인이 낼수있는 dps 를 뽑아두고 15분 레이드라면 최대 출력 dps 일때 즉, 딜로스 없이 뽑을수 있는 dps 일때 12분정도 여유클이 나오고 15분이면 3분 여유가 있으면
--   조금 딜로스있는 파티도 클리어가 되는구조로 짜야하는거야"
--  재는 법(설계의 셈은 공방 js/lune/design/weekboss.js의 RAIDDPS — 기준을 바꾸면 거기와 여기를 같이 고친다):
--   · 캐릭터 = 그 난이도의 입장 레벨(노말 Lv.50 = 2차 · 하드 Lv.70 = 3차) · 능력치와 스킬 포인트는 게임의 「추천대로 찍기」(Hero.autoStat · autoSkill)
--   · 장비 = 그 레벨의 사냥 장비(무기 + 방어구 넷) · 성능 「보통」 · 별은 RAIDDPS.gear의 것(설계 numbers.js LOADOUTS의 본보기 차림)
--   · 돌리기 = 딜 손실이 없는 손: 사출기 켜기 · 버프는 끊기지 않게 다시 걸기 · 설치 · 소환 · 따로 쓰는 공격기는 다시 쓰기가 돌면 바로 · 남는 시간은 가장 센 보스기.
--     기술의 구간은 화면이 하듯 보낸다(서버가 빈 방에서 재 보는 Caster:dryCast의 법 그대로 — 모으는 기술은 끝까지 모으고, 누르고 있는 기술은 짧게 · 길게 둘 다 재서 센 쪽).
--     보스는 사람을 치지 못하게 막고(맞아서 끊기는 손실이 없다) 사람은 기술마다 보스에게 붙어 선다(움직이는 손실이 없다).
--     보스의 체력은 재는 동안 51%로 붙잡아 둔다(싸움 내내의 평균 50% 근처 · 절반의 변신이 일어나지 않게)
--   · 파티 = 서로 다른 직업 넷(다섯 직업이라 다섯 벌) — 파티 버프(무니의 달의 숨결 = 같은 맵 모두의 공격 속도 · 액시온의 달의 함성 …)가 겹친다
--  늘 보는 것: 기록해 둔 측정값(weekboss.js RAIDDPS.measured)으로 지금의 체력이면 몇 초에 깨는가(첫 보스의 체력은 사용자의 수 — 2026-10-27). 진짜로 재는 것은 LUNE_RAID=1일 때만(2분쯤):
--   LUNE_RAID=1 python tools/test/run.py 104_lune_raid_dps → [RAID] 줄 · 맨 아래의 검사: 가장 약한 직업 조합도 최대 출력이면 제한 시간 안에 깬다.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local TICK = 1 / 60

local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
World.start()

local B = Weekly.boss("shadowarcher")
if RAID_LV then
	-- (LUNE_RAID_LV — 새 보스의 체력을 볼 때: 그 입장 레벨 + 2의 보스로 · 재는 동안 쓰러지지 않게 체력을 아주 크게 — 2026-10-29 용암 거인)
	for _, mode in { "normal", "hard" } do
		local m = table.clone(B[mode])
		m.lv, m.hp = RAID_LV[mode] + 2, 1e6
		B[mode] = m
		local wk = COMBAT.mobs[B.id].story.week -- (방의 보스는 이 표에서 레벨 · 체력을 읽는다 — sim/room.luau)
		local w2 = table.clone(wk[mode])
		w2.lv, w2.hp = m.lv, m.hp
		wk[mode] = w2
	end
end
local RAID = Weekly.DATA.raid -- 설계의 기준(weekboss.js RAIDDPS)
expect(RAID ~= nil, "설계의 기준(RAIDDPS)이 게임에 들어와 있다")

-- 기록해 둔 측정값(RAIDDPS.measured의 평균)으로 지금의 체력이면 최대 출력 4인 파티가 몇 초에 깨는가를 적는다 — 늘 본다.
--  2026-10-27 사용자: "625118에다가 하드는 더높게 해서 만들어 이거 첫보스니까 패턴은 악랄하게 피는 적게" — 첫 보스의 체력은 사용자의 수라 12분에 맞추지 않는다(견주는 값만 적는다).
--  진짜로 재는 것은 LUNE_RAID=1일 때만(2분쯤 걸린다)
local FIT = COMBAT.rules.dmgScale * (1 + COMBAT.rules.targetBonus / 100)
for _, mode in { "normal", "hard" } do
	local m0 = B[mode]
	expect((RAID.avg[mode] or 0) > 0, mode .. ": 4인 최대 출력이 기록돼 있다")
	local hp = N.mobHp(m0.lv) * m0.hp * FIT
	print(("[RAID] %s 체력 %d(%s배) — 기록한 4인 최대 출력(초당 %d)이면 %.0f초 · %d분이 되는 배수 = %.0f"):format(
		mode, math.floor(hp + 0.5), tostring(m0.hp), RAID.avg[mode], hp / RAID.avg[mode], RAID.target / 60, RAID.avg[mode] * RAID.target / (N.mobHp(m0.lv) * FIT)))
end
expect(B.hard.hp * N.mobHp(B.hard.lv) > B.normal.hp * N.mobHp(B.normal.lv), "하드의 체력이 노말보다 많다")
if not RAID_FULL then
	print("[RAID] 재는 것은 건너뜀(LUNE_RAID=1이면 4인 최대 출력을 진짜로 잰다 — 2분쯤)")
	return
end

-- ---------- 캐릭터 ----------
local uid = 10400
local function make(class: string, level: number, star)
	uid += 1
	local name = "레이드" .. uid
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	local h = s.hero
	Hero.setLevel(h, level, Hero.jobAt(level))
	Hero.autoStat(h)
	Hero.autoSkill(h)
	h.quests[B.quest] = { done = true, c = {} }
	local stage = Items.stageOf(level)
	for _, slot in Items.data.GEAR do
		local it = Items.make(slot, stage, Items.data.NORMAL, class)
		it.star = if slot == "weapon" then star.weapon else star.armor
		h.equip[slot] = it
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	return p, s
end

-- ---------- 스킬의 갈래 ----------
--  instant = 누르면 바로(사출기 · 버프 · 바로 놓이는 설치/소환) · cast = 2~4차의 쓰는 스킬 · first = 1차의 길로 쓰는 것(동작이 있는 설치)
local function kindOf(h, id: string): string?
	if Kit.isToggle(h, id) then
		return "toggle"
	elseif Buffs.instant(id) then
		return "buff"
	elseif COMBAT.placed[id] and COMBAT.placed[id].cast == "instant" then
		return "place"
	elseif COMBAT.cast[id] then
		return "cast"
	elseif COMBAT.skills[id] then
		return "first"
	end
	return nil
end

-- 그 캐릭터가 보스에게 쓰는 것들: 버프 · 사출기 · 설치 · 소환 · 다시 쓰기가 있는 공격기 + 남는 시간을 채우는 보스기 하나
local function kitOf(h)
	local plan = { buffs = {}, places = {}, firsts = {}, attacks = {}, filler = nil, toggle = nil }
	local bestJob = -1
	for id, lv in h.skills do
		if lv < 1 then
			continue
		end
		local k = kindOf(h, id)
		if k == "toggle" then
			plan.toggle = id
		elseif k == "buff" then
			table.insert(plan.buffs, id)
		elseif k == "place" then
			table.insert(plan.places, id)
		elseif k == "first" then
			local def = COMBAT.skills[id]
			if def.type == "install" then
				table.insert(plan.firsts, id)
			elseif def.type == "boss" and def.job > bestJob then
				bestJob, plan.filler = def.job, id
			end
		elseif k == "cast" then
			local def = COMBAT.cast[id]
			if def.type == "boss" and def.job > bestJob then
				bestJob, plan.filler = def.job, id
			elseif (def.type == "attack" or def.type == "nuke") and def.cd > 0 then
				table.insert(plan.attacks, id)
			end
		end
	end
	for _, list in { plan.buffs, plan.places, plan.firsts, plan.attacks } do
		table.sort(list)
	end
	return plan
end

-- ---------- 방 ----------
local function bossIn(key: string)
	local room = World.room(key)
	for _, m in room.bosses do
		if m.kind == B.id then
			return m, room
		end
	end
	return nil, room
end

-- ---------- 한 사람의 손(딜 손실이 없는) ----------
--  hold = 누르고 있는 구간을 얼마나: "min"(가장 짧게) · "max"(가장 길게)
local Hand = {}
Hand.__index = Hand
function Hand.new(p, s, hold: string)
	local self = setmetatable({ p = p, s = s, h = s.hero, plan = kitOf(s.hero), hold = hold, act = nil, last = {}, uses = {} }, Hand)
	return self
end
function Hand:stand(m, at: number)
	local s, h = self.s, self.h
	s.trust, s.stale = true, nil
	h.x, h.y, h.dir = m.x - at, m.y, 1
end
function Hand:send(id: string, seg: number)
	handlers.Skill(self.p, id, seg, self.h.x, self.h.y, 1)
end
function Hand:count(id: string)
	self.uses[id] = (self.uses[id] or 0) + 1
end
-- 바로 쓰는 것들(시간을 쓰지 않는다): 사출기 · 버프 · 바로 놓이는 설치/소환
function Hand:instants(m, now: number)
	local h, plan = self.h, self.plan
	if plan.toggle and not h.kit.on then
		self:stand(m, 14)
		self:send(plan.toggle, 1)
	end
	for _, id in plan.buffs do
		local b = h.buffs[id]
		-- 끝나기 2초 전에 다시 건다(파티원이 걸어 준 같은 버프가 있어도 내 것으로 — 지속은 같다)
		if (not b or b.t < 2) and (h.cds[id] or 0) <= now then
			self:stand(m, 14)
			self:send(id, 1)
			self:count(id)
		end
	end
	for _, id in plan.places do
		local def = COMBAT.placed[id]
		local dur = def.dur or 0
		-- 따라다니는 것(하나만 — 다시 쓰면 새것)은 지속이 다 됐을 때 · 놓는 것은 다시 쓰기가 돌면 바로
		local again = if def.kind == "follow" then (now - (self.last[id] or -1e9)) >= math.max(dur - 1, 1) else true
		if again and (h.cds[id] or 0) <= now and (not def.cost or h.kit.souls >= def.cost) then
			self:stand(m, 14)
			local before = h.cds[id]
			self:send(id, 1)
			if h.cds[id] ~= before or def.cd == 0 then
				self.last[id] = now
				self:count(id)
			end
		end
	end
end
-- 시간을 쓰는 다음 일을 고른다: 동작이 있는 설치 → 다시 쓰기가 돈 공격기 → 보스기
function Hand:pick(now: number): string?
	local h, s = self.h, self.s
	for _, id in self.plan.firsts do
		if not (s.cds and s.cds[id] and now < s.cds[id]) then
			return id
		end
	end
	for _, id in self.plan.attacks do
		if (h.cds[id] or 0) <= now then
			return id
		end
	end
	return self.plan.filler
end
-- 한 걸음: 하던 것을 잇거나, 끝났으면 다음 것을 시작한다
function Hand:step(m, room, now: number)
	local h = self.h
	h.hp, h.alive, h.invuln, h.inCheck = h.maxHp, true, 1, nil
	self:instants(m, now)
	local act = self.act
	if act and act.kind == "first" then
		if now >= self.s.skill.free then
			self.act = nil
		end
	elseif act and act.kind == "cast" then
		local a = room.caster.actors[h]
		local sk = a and a.skill
		if act.wait then
			-- 「때까지」 구간이 있는 스킬(뛰어올라 떨어질 때까지): 서버는 끝을 모른다 — 빈 방에서 잰 한 번의 시간만큼은 쓴다(정직한 화면)
			if now - act.t0 >= act.wait then
				self.act = nil
			end
		elseif not sk or sk.id ~= act.id then
			self.act = nil
		else
			local seg = sk.s
			local over
			if seg.loop then
				over = sk.t >= seg.dur
			elseif seg.hold then
				local want = if self.hold == "max" then (seg.max or 3) else math.max(seg.min or 0.15, 0)
				over = sk.t >= want - 1e-6
			elseif seg.charge then
				local per, levels = (seg.per or COMBAT.castRule.charge), Kit.chargeLevels(h)
				over = sk.t >= Caster.segTime(h.class, seg) + per * levels + 0.02
			elseif seg.till then
				over = true
			else
				over = sk.t >= sk.need
			end
			if over then
				local def = Kitset.skill(act.id)
				if def.segs[sk.i + 1] then
					self:send(act.id, sk.i + 1)
				elseif act.till then
					act.wait = Caster.profile(act.id, 0).time / Buffs.haste(h)
				else
					self.act = nil
				end
			end
		end
	end
	if self.act then
		return
	end
	local id = self:pick(now)
	if not id then
		return
	end
	local k = kindOf(h, id)
	if k == "first" then
		self:stand(m, 14)
		local before = self.s.skill
		self:send(id, 1)
		if self.s.skill ~= before then
			self.act = { kind = "first", id = id }
			self:count(id)
		end
	else
		local def = COMBAT.cast[id]
		self:stand(m, def.at or 14)
		self:send(id, 1)
		local a = room.caster.actors[h]
		if a and a.skill and a.skill.id == id and a.skill.i == 1 then
			local till = false
			for _, sg in Kitset.skill(id).segs or {} do
				if sg.till then
					till = true
				end
			end
			self.act = { kind = "cast", id = id, t0 = now, till = till }
			self:count(id)
		elseif Kitset.skill(id).instant then
			self:count(id)
		end
	end
end

-- ---------- 한 판: 들어가서 warm초 뒤부터 secs초 동안 보스에게 들어간 피해 ----------
local function fight(classes: { string }, mode: string, holds: { [string]: string }?, secs: number, warm: number)
	local m0 = B[mode]
	local level = (RAID_LV and RAID_LV[mode]) or m0.need -- (LUNE_RAID_LV — 새 보스의 체력을 볼 때 그 입장 레벨로: 2026-10-29)
	local star = RAID.gear[mode]
	local ps, hands = {}, {}
	for i, class in classes do
		local p, s = make(class, level, star)
		World.jump(p, B.door.scene)
		s.hero.x, s.hero.y = B.door.x, s.hero.y
		ps[i] = { p = p, s = s }
	end
	if #ps > 1 then
		for i = 2, #ps do
			handlers.Party(ps[1].p, "invite", ps[i].p.UserId)
			handlers.Party(ps[i].p, "accept")
		end
	end
	local lead = ps[1]
	lead.s.trust, lead.s.stale = true, nil
	lead.s.hero.x = B.door.x
	local r = handlers.Week(lead.p, "enter", B.id, mode, #ps > 1)
	assert(r and r.ok, "들어가지 못했다: " .. tostring(r and r.why))
	local key = lead.s.scene
	for _, e in ps do
		assert(e.s.scene == key, "파티원이 같은 방에 들지 못했다")
		table.insert(hands, Hand.new(e.p, e.s, (holds and holds[e.s.hero.class]) or "min"))
	end
	local dealt, t = 0, 0
	local by = {} -- 혼자일 때: 그 걸음에 쓰고 있던 기술마다 들어간 피해(늦게 터지는 것 · 사출기도 그때의 기술에 붙는다 — 대강의 몫)
	local total = warm + secs
	local m, room = bossIn(key)
	assert(m, "보스가 없다")
	while t < total do
		m, room = bossIn(key)
		local now = World.now
		if m and m.state ~= "spawn" then
			for _, hand in hands do
				hand:step(m, room, now)
			end
		end
		for _, hand in hands do
			hand.h.inCine = true -- 보스가 사람을 치지 못한다(맞아서 끊기는 손실 없음 — 기술을 쓸 때 서버가 false로 돌린다)
		end
		World.tick(TICK)
		t += TICK
		m = bossIn(key)
		if m then
			local hold = math.floor(m.maxHp * 0.51)
			if t > warm then
				local d = math.max(0, hold - m.hp)
				dealt += d
				if #hands == 1 then
					local id = hands[1].act and hands[1].act.id or "-"
					by[id] = (by[id] or 0) + d
				end
			end
			m.hp = hold
		end
	end
	local out = { dps = dealt / secs, maxHp = m and m.maxHp or 0, heroes = {}, by = by, total = dealt }
	for i, e in ps do
		local h = e.s.hero
		out.heroes[i] = { class = h.class, power = Hero.power(h), uses = hands[i].uses, filler = hands[i].plan.filler }
		out.skills = table.clone(h.skills)
	end
	for _, e in ps do
		World.removePlayer(e.p)
	end
	return out
end

local function usesText(u)
	local list = {}
	for id, n in u do
		table.insert(list, ("%s %d"):format(id, n))
	end
	table.sort(list)
	return table.concat(list, " · ")
end

-- ---------- 재기 ----------
local SECS, WARM = RAID.secs, RAID.warm
local result = {}
for _, mode in { "normal", "hard" } do
	local m0 = B[mode]
	result[mode] = { solo = {}, party = {} }
	-- 혼자(제 버프만): 누르고 있는 기술은 짧게 · 길게 둘 다 재서 센 쪽을 파티에서 쓴다
	local holds = {}
	for _, class in CLASSES.order do
		local best = nil
		for _, hold in { "min", "max" } do
			local r = fight({ class }, mode, { [class] = hold }, SECS, WARM)
			if not best or r.dps > best.dps then
				best = r
				best.hold = hold
			end
			if hold == "min" then
				-- 누르고 있는 구간이 없는 직업은 한 번만 잰다
				local has = false
				for _, id in { r.heroes[1].filler } do
					for _, sg in (Kitset.skill(id) or {}).segs or {} do
						if sg.hold then
							has = true
						end
					end
				end
				if not has then
					break
				end
			end
		end
		holds[class] = best.hold
		result[mode].solo[class] = best
		local h = best.heroes[1]
		print(("[RAID] %s Lv.%d 혼자 %-10s | 초당 %7.0f | 전투력 %d | 보스기 %s(누르기 %s) | %s"):format(mode, (RAID_LV and RAID_LV[mode]) or m0.need, class, best.dps, h.power, tostring(h.filler), best.hold, usesText(h.uses)))
		-- 보스기 한 번에 들어간 피해 ÷ 설계의 한 번(전투력 x rate x (쓰는 시간 + 다시 쓰기 몫) x 스킬 레벨의 세기 x 보스기 1.5) — 1을 크게 넘으면 설계보다 세다
		local f = h.filler
		local def = f and COMBAT.cast[f]
		if def then
			local lv = best.skills[f] or 0
			local scale = COMBAT.castRule.floor + (1 - COMBAT.castRule.floor) * (if def.max > 1 then (lv - 1) / (def.max - 1) else 1)
			local one = h.power * def.rate * (Caster.profile(f, 0).time + def.cdTime) * scale * (1 + COMBAT.rules.targetBonus / 100)
			local per = (best.by[f] or 0) / math.max(1, h.uses[f] or 0)
			local parts = {}
			for id, d in best.by do
				table.insert(parts, ("%s %.0f%%"):format(id, d / math.max(1, best.total) * 100))
			end
			table.sort(parts)
			print(("[RAID]    %s Lv.%d/%d · 한 번 %.2f초(빈 방) · 한 번의 피해 %.0f = 설계의 %.2f배 | 몫: %s"):format(f, lv, def.max, Caster.profile(f, 0).time, per, per / one, table.concat(parts, " · ")))
		end
	end
	-- 파티: 서로 다른 직업 넷(다섯 벌)
	for skip = 1, #CLASSES.order do
		local four = {}
		for i, class in CLASSES.order do
			if i ~= skip then
				table.insert(four, class)
			end
		end
		local r = fight(four, mode, holds, SECS, WARM)
		local solo = 0
		for _, class in four do
			solo += result[mode].solo[class].dps
		end
		r.buffGain = r.dps / solo
		r.without = CLASSES.order[skip]
		table.insert(result[mode].party, r)
		print(("[RAID] %s Lv.%d 파티(%s 빼고) | 초당 %7.0f | 혼자 넷의 합 %7.0f | 파티 버프로 x%.3f | 보스 체력 %d → %.1f분"):format(
			mode, (RAID_LV and RAID_LV[mode]) or m0.need, CLASSES.order[skip], r.dps, solo, r.buffGain, r.maxHp, r.maxHp / r.dps / 60))
	end
	local sum, lo, hi = 0, math.huge, 0
	for _, r in result[mode].party do
		sum += r.dps
		lo, hi = math.min(lo, r.dps), math.max(hi, r.dps)
	end
	local avg = sum / #result[mode].party
	result[mode].avg, result[mode].lo, result[mode].hi = avg, lo, hi
	local hp = result[mode].party[1].maxHp
	local mul = avg * RAID.target / (N.mobHp(m0.lv) * COMBAT.rules.dmgScale * (1 + COMBAT.rules.targetBonus / 100))
	print(("[RAID] %s 파티 평균 초당 %.0f(가장 약한 파티 %.0f · 가장 센 파티 %.0f) | 지금 체력 %d → 평균 %.1f분 · 약한 파티 %.1f분 | %d초에 맞추는 체력 배수 hp = %.2f"):format(
		mode, avg, lo, hi, hp, hp / avg / 60, hp / lo / 60, RAID.target, mul))
end

-- ---------- 검사: 가장 약한 직업 조합도 최대 출력이면 제한 시간 안에 깬다 ----------
for _, mode in { "normal", "hard" } do
	local r = result[mode]
	local hp = r.party[1].maxHp
	local loMin = hp / r.lo / 60
	expect(RAID_LV ~= nil or loMin * 60 <= Weekly.DATA.time, ("%s: 가장 약한 직업 조합도 최대 출력이면 제한 시간 안에 깬다(%.1f분 ≤ %d분)"):format(mode, loMin, Weekly.DATA.time / 60))
end
