-- 「달의 계승자」 — 직업 안의 스킬 세기 차례(2026-11-06 사용자: "캐릭터들 보스 dps 밸런스 점검하고 캐릭터 안에서 2차,3차 보스기가 4차 보스기보다 강한경우나, 사냥기가 보스기보다 강한경우가 있으면안된다").
--  재는 법(진짜 서버의 셈 — 시험 104의 손을 그대로): Lv.150 · 4차 · 그 직업의 모든 스킬 마스터 · Lv.150 사냥 장비 「보통」 무기 17강 · 방어구 5강(용암 거인의 잣대) ·
--   보스 한 마리(그림자 사수의 방 · Lv.150 · 체력은 아주 크게 · 사람을 치지 않는다 · 체력 51%로 붙잡아 둔다)에 붙어 서서 그 스킬 하나만 쓴다(버프는 끊기지 않게 · 사출기는 켜 둔다 —
--   어느 스킬을 재든 같다 · 설치 · 소환 · 다른 공격기는 쓰지 않는다). 누르고 있는 스킬은 짧게 · 길게 둘 다 재서 센 쪽. 4차 보스기는 Lv.1로도 잰다.
--  보는 것: ① 1 · 2 · 3차 보스기 < 4차 보스기(Lv.1도) ② 사냥기 < 같은 차수의 보스기 ③ 어느 사냥기도 4차 보스기(만렙)보다 약하다 — 한 마리(보스)에게 초당 들어간 피해
--   (「새 차수 Lv.1 > 앞 차수 마스터」는 초당으로는 적어 두기만 한다)
--  늘 보는 것은 설계의 % 셈(시험 126). 진짜로 재는 것은 LUNE_SKILLDPS=1일 때만(5분쯤): LUNE_SKILLDPS=1 python tools/test/run.py 131_lune_skill_dps
if not SKILL_DPS then
	print("[SKILLDPS] 재는 것은 건너뜀(LUNE_SKILLDPS=1이면 직업마다 사냥기 · 보스기를 하나씩 보스에게 써서 잰다 — 5분쯤)")
	return
end
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local TICK = 1 / 60
local LV, STAR, SECS, WARM = 150, { weapon = 17, armor = 5 }, 20, 4

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

-- 보스: 그림자 사수의 방 · 하드 · Lv.150 · 체력은 아주 크게(시험 104의 LUNE_RAID_LV와 같은 법)
local B = Weekly.boss("shadowarcher")
local MODE = "hard"
do
	local m = table.clone(B[MODE])
	m.lv, m.hp = LV, 1e6
	B[MODE] = m
	local wk = COMBAT.mobs[B.id].story.week
	local w2 = table.clone(wk[MODE])
	w2.lv, w2.hp = LV, 1e6
	wk[MODE] = w2
end

-- ---------- 캐릭터: Lv.150 · 모든 스킬 마스터 ----------
local uid = 13100
local function make(class: string)
	uid += 1
	local name = "세기" .. uid
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	local h = s.hero
	Hero.setLevel(h, LV, Hero.jobAt(LV))
	Hero.autoStat(h)
	Hero.autoSkill(h)
	for _, t in CLASSES.classes[h.class].tiers do
		if t.job <= h.job then
			for _, sk in t.skills do
				h.skills[sk.id] = sk.max
			end
		end
	end
	h.quests[B.quest] = { done = true, c = {} }
	local stage = Items.stageOf(LV)
	for _, slot in Items.data.GEAR do
		local it = Items.make(slot, stage, Items.data.NORMAL, class)
		it.star = if slot == "weapon" then STAR.weapon else STAR.armor
		h.equip[slot] = it
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	return p, s
end

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
-- 버프 · 사출기는 늘 · 공격은 그 스킬 하나만
local function planOf(h, only: string)
	local plan = { buffs = {}, toggle = nil, filler = only }
	for id, lv in h.skills do
		if lv >= 1 then
			local k = kindOf(h, id)
			if k == "toggle" then
				plan.toggle = id
			elseif k == "buff" then
				table.insert(plan.buffs, id)
			end
		end
	end
	table.sort(plan.buffs)
	return plan
end

-- ---------- 손(시험 104의 Hand 그대로 — 설치 · 다른 공격기 없이) ----------
local Hand = {}
Hand.__index = Hand
function Hand.new(p, s, only: string, hold: string)
	return setmetatable({ p = p, s = s, h = s.hero, plan = planOf(s.hero, only), hold = hold, act = nil, uses = 0, segs = {} }, Hand)
end
function Hand:stand(m, at: number)
	local s, h = self.s, self.h
	s.trust, s.stale = true, nil
	h.x, h.y, h.dir = m.x - at, m.y, 1
end
function Hand:send(id: string, seg: number)
	handlers.Skill(self.p, id, seg, self.h.x, self.h.y, 1)
end
function Hand:instants(m, now: number)
	local h, plan = self.h, self.plan
	if plan.toggle and not h.kit.on then
		self:stand(m, 14)
		self:send(plan.toggle, 1)
	end
	for _, id in plan.buffs do
		local b = h.buffs[id]
		if (not b or b.t < 2) and (h.cds[id] or 0) <= now then
			self:stand(m, 14)
			self:send(id, 1)
		end
	end
end
function Hand:step(m, room, now: number)
	local h = self.h
	h.hp, h.alive, h.invuln, h.inCheck = h.maxHp, true, 1, nil
	self:instants(m, now)
	local act = self.act
	if act and act.kind == "first" then
		-- 1차의 스킬: 힘을 모으는 구간(charge)은 끝까지 모은 뒤 · 한 번 더 누르는 구간(next)은 앞 구간이 끝날 때 다음 구간을 보낸다(화면이 하듯 — 서버 world.luau의 1차 스킬)
		local sk = self.s.skill
		local def = COMBAT.skills[act.id]
		if sk and sk.id == act.id and def and def.segs then
			local sg, nxt = def.segs[sk.seg], def.segs[sk.seg + 1]
			if sg and nxt and (sg.charge or nxt.next) then
				local wait = sg.time / Buffs.haste(h) + (if sg.charge then Kit.chargeTime(h, act.id) else 0)
				if act.sent ~= sk.seg + 1 and now - sk.at >= wait + 0.02 then
					act.sent = sk.seg + 1
					self.segs[sk.seg + 1] = (self.segs[sk.seg + 1] or 0) + 1
					self:send(act.id, sk.seg + 1)
				end
			elseif now >= sk.free then
				self.act = nil
			end
		elseif now >= self.s.skill.free then
			self.act = nil
		end
	elseif act and act.kind == "cast" then
		local a = room.caster.actors[h]
		local sk = a and a.skill
		if act.wait then
			if now - act.t0 >= act.wait then
				self.act = nil
			end
		elseif not sk or sk.id ~= act.id then
			if act.charge and a and a.last and a.last.id == act.id and a.last.i == act.charge then
				local nextSeg = act.charge + 1
				act.charge = nil
				self:send(act.id, nextSeg)
			else
				self.act = nil
			end
		else
			local seg = sk.s
			self.segs[sk.i] = (self.segs[sk.i] or 0) + (if act.seen ~= sk.i then 1 else 0) -- (구간마다 몇 번 들어갔나 — 두 번째 누르기가 먹었나를 본다)
			act.seen = sk.i
			act.charge = if seg.charge then sk.i else nil
			local over
			if seg.loop then
				over = sk.t >= seg.dur
			elseif seg.hold then
				local want = if self.hold == "max" then (seg.max or 3) else math.max(seg.min or 0.15, 0)
				over = sk.t >= want - 1e-6
			elseif seg.charge then
				local per, levels = Caster.chargeOf(h, seg)
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
	local id = self.plan.filler
	local k = kindOf(h, id)
	if k == "first" then
		if self.s.cds and self.s.cds[id] and now < self.s.cds[id] then
			return
		end
		self:stand(m, 14)
		local before = self.s.skill
		self:send(id, 1)
		if self.s.skill ~= before then
			self.act = { kind = "first", id = id }
			self.uses += 1
		end
	elseif k == "cast" then
		if (h.cds[id] or 0) > now then
			return
		end
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
			self.uses += 1
		elseif Kitset.skill(id).instant then
			self.uses += 1
		end
	end
end

local function bossIn(key: string)
	local room = World.room(key)
	for _, m in room.bosses do
		if m.kind == B.id then
			return m, room
		end
	end
	return nil, room
end

-- 한 판: 그 스킬 하나만 SECS초(WARM초 뒤부터) → 초당 피해 · 쓴 횟수
local function fight(class: string, only: string, hold: string, lv1: boolean)
	local p, s = make(class)
	if lv1 then
		s.hero.skills[only] = 1
		Hero.recalc(s.hero)
	end
	World.jump(p, B.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = B.door.x
	local r = handlers.Week(p, "enter", B.id, MODE, false)
	assert(r and r.ok, "들어가지 못했다: " .. tostring(r and r.why))
	local key = s.scene
	local hand = Hand.new(p, s, only, hold)
	local dealt, t = 0, 0
	while t < WARM + SECS do
		local m, room = bossIn(key)
		if m and m.state ~= "spawn" then
			hand:step(m, room, World.now)
		end
		s.hero.inCine = true
		World.tick(TICK)
		t += TICK
		m = bossIn(key)
		if m then
			local keep = math.floor(m.maxHp * 0.51)
			if t > WARM then
				dealt += math.max(0, keep - m.hp)
			end
			m.hp = keep
		end
	end
	World.removePlayer(p)
	local segs = {}
	for i = 1, 6 do
		if hand.segs[i] then
			table.insert(segs, ("%d:%d"):format(i, hand.segs[i]))
		end
	end
	return dealt / SECS, hand.uses, table.concat(segs, " ")
end
local function hasHold(id: string): boolean
	for _, sg in (Kitset.skill(id) or {}).segs or {} do
		if sg.hold then
			return true
		end
	end
	return false
end
local function best(class: string, id: string, lv1: boolean): (number, number, string)
	local d, n, sg = fight(class, id, "min", lv1)
	if hasHold(id) then
		local d2, n2, sg2 = fight(class, id, "max", lv1)
		if d2 > d then
			d, n, sg = d2, n2, sg2
		end
	end
	return d, n, sg
end

-- ---------- 재기 ----------
local result = {}
for _, class in CLASSES.order do
	if RAID_ONLY and class ~= RAID_ONLY then
		continue
	end
	local C = CLASSES.classes[class]
	local row = { boss = {}, mob = {}, name = {} }
	for _, tier in C.tiers do
		for _, sk in tier.skills do
			if (sk.type == "boss" or sk.type == "mob") and tier.job >= 1 and not row[sk.type][tier.job] then
				local dps, n, sg = best(class, sk.id, false)
				row[sk.type][tier.job] = { id = sk.id, name = sk.name, dps = dps, n = n, segs = sg }
				print(("[SKILLDPS]   %s %s %s: 초당 %.0f · %d번 · 구간 %s"):format(class, sk.type, sk.id, dps, n, sg))
			end
		end
	end
	for job = 2, 4 do -- 2 · 3 · 4차 보스기는 Lv.1로도(「새 차수의 레벨 1 > 앞 차수 마스터」 — 사용자 2026-10-08 "이건 기본이에요")
		local b = row.boss[job]
		if b then
			b.lv1 = best(class, b.id, true)
		end
	end
	local b4 = row.boss[4]
	result[class] = row
	local parts = {}
	for job = 1, 4 do
		local b, mo = row.boss[job], row.mob[job]
		table.insert(parts, ("%d차 보스기 %s %.0f · 사냥기 %s %.0f"):format(job, b and b.name or "-", b and b.dps or 0, mo and mo.name or "-", mo and mo.dps or 0))
	end
	print(("[SKILLDPS] %-10s | %s | Lv.1 = 2차 %.0f · 3차 %.0f · 4차 %.0f"):format(class, table.concat(parts, " | "), row.boss[2] and row.boss[2].lv1 or 0, row.boss[3] and row.boss[3].lv1 or 0, b4 and b4.lv1 or 0))
end

-- ---------- 검사 ----------
for class, row in result do
	local b4 = row.boss[4]
	expect(b4 ~= nil and b4.dps > 0, class .. ": 4차 보스기를 쟀다")
	if not b4 then
		continue
	end
	for job = 1, 3 do
		local b = row.boss[job]
		if b then
			expect(b.dps < b4.lv1, ("%s: %d차 보스기 %s 초당 %.0f < 4차 보스기 %s Lv.1 초당 %.0f"):format(class, job, b.name, b.dps, b4.name, b4.lv1))
		end
	end
	-- (「새 차수의 레벨 1 > 앞 차수 마스터」(사용자 2026-10-08)는 스킬 창의 % — 시험 126이 본다. 초당으로는 적어 두기만 한다: 1 → 2차는 1차의 손맛을 건드려야 해 사용자에게 물었다 · 2026-11-06)
	for job = 2, 4 do
		local b, prev = row.boss[job], row.boss[job - 1]
		if b and prev and b.lv1 and b.lv1 <= prev.dps then
			print(("[SKILLDPS] (적어 둠) %s: %d차 보스기 %s Lv.1 초당 %.0f ≤ %d차 보스기 %s 마스터 초당 %.0f"):format(class, job, b.name, b.lv1, job - 1, prev.name, prev.dps))
		end
	end
	for job = 1, 4 do
		local mo, b = row.mob[job], row.boss[job]
		if mo and b then
			expect(mo.dps < b.dps, ("%s: %d차 사냥기 %s 초당 %.0f < 같은 차수의 보스기 %s 초당 %.0f(보스 한 마리)"):format(class, job, mo.name, mo.dps, b.name, b.dps))
		end
		if mo then
			expect(mo.dps < b4.dps, ("%s: %d차 사냥기 %s 초당 %.0f < 4차 보스기 %s 초당 %.0f"):format(class, job, mo.name, mo.dps, b4.name, b4.dps))
		end
	end
end
