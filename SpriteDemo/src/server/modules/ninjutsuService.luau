-- 유파 · 전직 · 스킬(서버) — 「오문 닌자전」 NINJA_DESIGN.md §0-1 · §0-6. 수치·종류·스킬 나무는 shared/config/ninjutsu.luau.
--  전직(메이플식): data.Job = 0(견습) ~ 4. 모두 마을 스승(ninjutsu.CHANGE_NPC) 곁에서.
--   ChooseSchool(유파): Job 0이면 1차 전직 — Lv.10 이상이어야 하고, 고른 유파에 든다(Job = 1). Job 1 이상이면 유파 바꾸기(엽전 CHANGE_COST —
--    옛 유파 스킬에 쓴 SP는 돌려받고 새 유파의 주력기 · 핵심 장치를 1레벨로 받는다).
--   JobAdvance(): 다음 전직 레벨(30 · 60 · 100)이 됐으면 Job + 1. (전직 시험은 나중에 붙인다.)
--   전직하면 SP_ON_JOB을 받고 그 전직의 주력기 · 핵심 장치를 1레벨로 배운다.
--  스킬 포인트: data.SP[전직] = 안 쓴 SP(레벨업마다 progressionService가 지금 전직에 SP_PER_LEVEL씩 넣는다).
--   LearnSkill(id): 그 스킬 전직의 SP 1을 써서 +1(마스터 레벨까지). data.Ninjutsu[id] = 스킬 레벨(0/없음 = 안 배움).
--   SetSkillSlot(칸, id): 배운 쓰는 인술을 단축칸(1~SLOTS)에 넣는다("" = 비움). 처음 배우면 빈 칸에 저절로 들어간다.
--   바뀌면 SchoolUpdated(유파, 스킬 레벨표, 전직 단계, SP, 단축칸).
--  UseNinjutsu(칸, 바라보는 방향): 그 칸에 넣은 인술. 서버가 배웠는지 · 쿨타임 · 기력(또는 생기)을 확인한 뒤 쓴다.
--   같은 씬 모두에게 NinjutsuCast(연출) → 피해는 townMonsters.Damage(source "nin:<인술 id>") — 기여도·반격·처치 규칙이 기본 공격과 같다.
--   대상이 없어 못 쓰는 인술(번개 — 가까운 적 없음, 치유 — 체력 가득)은 기력·쿨타임을 쓰지 않는다.
--  핵심 장치(유파마다 하나 — 그 패시브를 배웠을 때):
--   불씨(f_ember)  — 불 인술(ember)이 맞은 몬스터에 쌓임(사람마다 따로). 하나마다 interval초에 한 번 피해("nin:burn").
--   서리(i_frost)  — 얼음 인술(frost)이 맞은 몬스터에 쌓임. 하나마다 느려지고 stacks가 되면 얼어붙는다(멈춤).
--   생기(p_vigor)  — 풀 인술이 맞을 때마다 내게 쌓임. 회복 인술(vigorCost)이 쓴다.
--   견고(r_firm)   — 몬스터에게 맞을 때마다 내게 쌓임. 하나마다 받는 피해가 줄어든다.
--   전하(t_charge) — 공격이 맞을 때마다 내게 쌓임. 하나마다 기본 공격이 빨라진다.
--   내게 쌓이는 것은 CoreUpdated(스킬 id, 값, 최대, 남은 초)로 화면에 알린다.
--  2차 스킬의 종류(shared/config/ninjutsu.luau 머리말): zone(설치) · buff(파티 버프) · detonate(점화) · shatter(깨뜨리기) · discharge(방전)
--   · decoy(얼음 분신) · counter(되받아치기) + line/projectile의 덧붙임(hits · follow · segments · pull · shots · single · mark · firmBonus).
--  기력: 서버가 갖는다(저장하지 않음 — 접속하면 가득). 값이 바뀔 때만 EnergyUpdated(지금 값, 최대, 초당 회복) — 그 사이는 클라가 이어서 센다.
--   기본 공격이 맞으면(townMonsters.OnPlayerAttack) 맞은 몬스터 수 × ENERGY_PER_HIT.
--  두루마리(UseScroll — server/modules/shops.luau UseItem이 부른다): 자기 유파 두루마리 1개 → 지금 전직의 SP +1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local townMonsters = require(script.Parent.townMonsters)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local world = townWorld.data
local SK = ninjutsu.SKILLS
local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)
local DIRS = { up = Vector2.new(0, -1), down = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }
local CORE_OF = { plant = "p_vigor", rock = "r_firm", thunder = "t_charge" } -- 내게 쌓이는 핵심 장치

local exports = {}
local energy = {} -- [userId] = { value, at(os.clock) }
local ready = {} -- [userId] = { [인술 id | "dash"] = 다시 쓸 수 있는 시각 }
local cores = {} -- [userId] = { id, value, untilT? } — 생기 · 견고 · 전하(유파에 따라 하나)
local counters = {} -- [userId] = 기본 공격이 맞은 횟수(달궈진 칼날 · 정전기)
local guardUntil = {} -- [userId] = 방어 인술이 끝나는 시각(견고가 더 쌓인다)
local counterUntil = {} -- [userId] = { untilT, skill, level, key } — 되받아치기 자세가 끝나는 시각
local haste = {} -- [userId] = { value, untilT } — 질풍(공격 속도 버프)
local zones = {} -- 설치한 자리 목록(불기둥 · 얼음 벽 · 치유꽃 · 번개 덫): { n, owner, id, key, x, y, untilT, dead }
local zoneSerial = 0

local function levelOf(data, id: string): number
	return if data then ninjutsu.LevelOf(data.Ninjutsu, id) else 0
end

-- ---- 기력(기력 단련 c_energy가 최대 · 회복을 늘린다) ----
local function energyStats(player: Player): (number, number)
	local l = levelOf(persistence.Get(player), "c_energy")
	return ninjutsu.ENERGY_MAX + SK.c_energy.maxPerLevel * l, ninjutsu.ENERGY_REGEN + SK.c_energy.regenPerLevel * l
end

local function energyOf(player: Player, now: number)
	local max, regen = energyStats(player)
	local e = energy[player.UserId]
	if not e then
		e = { value = max, at = now }
		energy[player.UserId] = e
	end
	e.value = math.min(max, e.value + (now - e.at) * regen)
	e.at = now
	return e
end

local function sendEnergy(player: Player)
	local e = energyOf(player, os.clock())
	local max, regen = energyStats(player)
	Net.FireClient("EnergyUpdated", player, e.value, max, regen)
end

function exports.GetEnergy(player: Player): number
	return energyOf(player, os.clock()).value
end

function exports.AddEnergy(player: Player, amount: number)
	local e = energyOf(player, os.clock())
	e.value = math.clamp(e.value + amount, 0, (energyStats(player)))
	sendEnergy(player)
end

-- ---- 도우미 ----
local function toScene(key: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient("NinjutsuCast", player, key, ...)
	end
end

local function feetOf(player: Player): Vector2?
	local position = heroTracking.GetPosition(player.UserId)
	return position and position / world.scale
end

local function nearNpc(player: Player, npcType: string): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local feet = feetOf(player)
	if not d or not feet then
		return false
	end
	for _, n in d.npcs do
		if n.type == npcType and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD then
			return true
		end
	end
	return false
end

-- ---- 스킬 포인트 · 단축칸 ----
local function ensure(data)
	data.Ninjutsu = data.Ninjutsu or {}
	if typeof(data.SP) ~= "table" then
		data.SP = { 0, 0, 0, 0 }
	end
	if typeof(data.SkillSlots) ~= "table" then
		data.SkillSlots = { "", "", "", "" }
	end
end

local function sendSkills(player: Player, data)
	Net.FireClient("SchoolUpdated", player, data.School, data.Ninjutsu, data.Job or 0, data.SP, data.SkillSlots)
end

-- 쓰는 인술이면 빈 단축칸에 넣는다(이미 있으면 그대로)
local function fillSlot(data, id: string)
	if not ninjutsu.IsActive(id) or table.find(data.SkillSlots, id) then
		return
	end
	for slot = 1, ninjutsu.SLOTS do
		if (data.SkillSlots[slot] or "") == "" then
			data.SkillSlots[slot] = id
			return
		end
	end
end

-- 그 전직의 주력기 · 핵심 장치를 1레벨로(이미 배웠으면 그대로)
local function learnAuto(data, job: number)
	for _, id in ninjutsu.AutoFor(data.School, job) do
		if levelOf(data, id) < 1 then
			data.Ninjutsu[id] = 1
		end
		fillSlot(data, id)
	end
end

local function grantJob(data, job: number)
	ensure(data)
	data.SP[job] = (data.SP[job] or 0) + ninjutsu.SP_ON_JOB
	learnAuto(data, job)
end

-- ---- 핵심 장치 ----
-- 내게 쌓이는 것(생기 · 견고 · 전하): 스킬 id · 지금 값(시간이 지나 사라졌으면 0) · 그 패시브 레벨. 안 배웠으면 nil
local function coreOf(player: Player, data): (string?, number, number)
	local id = CORE_OF[data and data.School or ""]
	local level = if id then levelOf(data, id) else 0
	if not id or level < 1 then
		return nil, 0, 0
	end
	local c = cores[player.UserId]
	if not c or c.id ~= id then
		c = { id = id, value = 0 }
		cores[player.UserId] = c
	end
	if c.untilT and os.clock() >= c.untilT then
		c.value, c.untilT = 0, nil
	end
	return id, c.value, level
end

local function setCore(player: Player, id: string, value: number)
	local def = SK[id]
	local c = cores[player.UserId]
	c.value = math.clamp(value, 0, def.stacks)
	c.untilT = if def.seconds and c.value > 0 then os.clock() + def.seconds else nil
	Net.FireClient("CoreUpdated", player, id, c.value, def.stacks, def.seconds)
end

function exports.GetCore(player: Player): number
	local _, value = coreOf(player, persistence.Get(player))
	return value
end

-- 내게 쌓이는 핵심 장치를 amount만큼 더한다(그 패시브를 배웠을 때만)
function exports.AddCore(player: Player, amount: number)
	local id, value = coreOf(player, persistence.Get(player))
	if id then
		setCore(player, id, value + amount)
	end
end

-- 불씨: 그 사람이 그 몬스터에 붙인 불씨를 n개 더한다. 붙어 있는 동안 interval초마다 피해.
local function addEmber(key: string, m, player: Player, n: number)
	local level = levelOf(persistence.Get(player), "f_ember")
	if level < 1 or n <= 0 then
		return
	end
	local def = SK.f_ember
	local now = os.clock()
	m.ember = m.ember or {}
	local e = m.ember[player.UserId]
	if e and now < e.untilT then
		e.stacks = math.min(def.stacks, e.stacks + n)
		e.untilT = now + def.seconds
		return
	end
	e = { stacks = math.min(def.stacks, n), untilT = now + def.seconds }
	m.ember[player.UserId] = e
	local function tick()
		if not m.ember or m.ember[player.UserId] ~= e or os.clock() >= e.untilT then
			return
		end
		local amount = math.max(1, math.round(inventoryService.GetAttackDamage(player) * (def.power + def.perLevel * level) * e.stacks))
		if townMonsters.Damage(key, m.id, player, amount, "nin:burn") then
			task.delay(def.interval, tick)
		else
			e.untilT = 0
		end
	end
	task.delay(def.interval, tick)
end

-- 서리: 그 몬스터에 n개 더한다. 하나마다 느려지고, stacks가 되면 얼어붙고 다시 0부터.
local function addFrost(key: string, m, player: Player, n: number)
	local level = levelOf(persistence.Get(player), "i_frost")
	if level < 1 or n <= 0 then
		return
	end
	local def = SK.i_frost
	local now = os.clock()
	local f = m.frost
	if not f or now >= f.untilT then
		f = { stacks = 0, untilT = 0 }
		m.frost = f
	end
	f.stacks += n
	f.untilT = now + def.seconds
	if f.stacks >= def.stacks then
		f.stacks = 0
		m.frozenUntil = now + def.freeze + def.perLevel * level -- 얼어붙음(깨뜨리기가 본다)
		townMonsters.Stun(key, m.id, def.freeze + def.perLevel * level)
	else
		townMonsters.Slow(key, m.id, 1 - def.slowPer * f.stacks, def.seconds)
	end
end

-- 맞은 몬스터에게 덧붙는 효과(불씨 · 서리 · 느려짐 · 멈춤 · 밀림 · 불붙음). away = 밀려나는 방향(단위 벡터)
local function applyEffects(key: string, m, player: Player, skill, attack: number, scale: number, away: Vector2?)
	if skill.ember then
		addEmber(key, m, player, skill.ember)
	end
	if skill.frost then
		addFrost(key, m, player, skill.frost)
	end
	if skill.slow then
		townMonsters.Slow(key, m.id, skill.slow.mult, skill.slow.seconds)
	end
	if skill.stun then
		townMonsters.Stun(key, m.id, skill.stun)
	end
	if skill.push and away then
		townMonsters.Push(key, m.id, away.X * skill.push, away.Y * skill.push)
	end
	if skill.burn then
		local tick = math.max(1, math.round(attack * skill.burn.power * scale))
		for i = 1, skill.burn.ticks do
			task.delay(i * skill.burn.interval, townMonsters.Damage, key, m.id, player, tick, "nin:burn")
		end
	end
end

-- 전하: 공격(기본 · 인술)이 맞으면 1
local function gainCharge(player: Player)
	local coreId, value = coreOf(player, persistence.Get(player))
	if coreId == "t_charge" then
		setCore(player, coreId, value + 1)
	end
end

-- 그 몬스터가 지금 얼어붙어 있는가(서리 5로 멈춘 동안)
local function frozen(m, now: number): boolean
	return m.frozenUntil ~= nil and now < m.frozenUntil
end

-- 2차 패시브가 주는 피해 배율: 타오르는 마음(불씨가 걸린 적 수) · 차가운 피(서리/얼어붙은 적) · 감전(내 번개에 맞은 적)
local function passiveMult(key: string, m, player: Player, data): number
	local uid = player.UserId
	local now = os.clock()
	local mult = 1
	local school = data.School
	if school == "fire" then
		local level = levelOf(data, "f_drain")
		if level >= 1 then
			local n = 0
			for _, other in townMonsters.Living(key) do
				local e = other.ember and other.ember[uid]
				if e and now < e.untilT and e.stacks > 0 then
					n += 1
				end
			end
			mult *= 1 + (SK.f_drain.base + SK.f_drain.perLevel * level) * math.min(SK.f_drain.cap, n)
		end
	elseif school == "ice" then
		local level = levelOf(data, "i_cold")
		if level >= 1 and (frozen(m, now) or (m.frost and now < m.frost.untilT and m.frost.stacks > 0)) then
			mult *= 1 + SK.i_cold.perLevel * level
		end
	elseif school == "thunder" then
		local level = levelOf(data, "t_shock")
		if level >= 1 and m.shock and now < (m.shock[uid] or 0) then
			mult *= 1 + SK.t_shock.base + SK.t_shock.perLevel * level
		end
	end
	return mult
end

-- 인술 한 번 맞음. source = "nin:<id>"(씨앗이 터질 때 "<id>:burst" 등), power를 주면 skill.power 대신 쓴다.
local function hit(key: string, m, player: Player, source: string, skill, attack: number, scale: number, mult: number, away: Vector2?, power: number?): boolean
	local data = persistence.Get(player)
	local amount = math.max(1, math.round(attack * (power or skill.power) * scale * mult * passiveMult(key, m, player, data)))
	if not townMonsters.Damage(key, m.id, player, amount, "nin:" .. source) then
		return false
	end
	applyEffects(key, m, player, skill, attack, scale, away)
	gainCharge(player) -- 전하: 인술이 맞을 때마다(번개 유파만 쌓인다)
	local now = os.clock()
	if skill.school == "thunder" and levelOf(data, "t_shock") >= 1 then -- 감전: 다음 번개부터 더 아프다
		m.shock = m.shock or {}
		m.shock[player.UserId] = now + SK.t_shock.seconds
	end
	if skill.root then -- 뿌리 표식(가시 씨앗 · 덩굴 묶기)
		m.rootUntil = now + skill.root
	end
	if skill.school == "plant" then -- 생기: 풀 인술이 맞을 때마다(뿌리 내림 — 뿌리 표식이 있는 적이면 더)
		local coreId, value, level = coreOf(player, data)
		if coreId == "p_vigor" then
			local gain = SK.p_vigor.perHit + SK.p_vigor.perLevel * level
			local root = levelOf(data, "p_root")
			if root >= 1 and m.rootUntil and now < m.rootUntil then
				gain *= 1 + SK.p_root.vigorPerLevel * root
			end
			setCore(player, coreId, value + gain)
		end
	end
	return true
end

-- ---- 대쉬(이동기) ----
-- 벽에 막히기 전까지 갈 수 있는 거리(2도트씩 살핀다 — 클라 topDownHero와 같은 셈)
function exports.DashDistance(key: string, feet: Vector2, dir: Vector2, distance: number): number
	local d = townWorld.Get(key)
	local box = world.playerFeet
	local reached = 0
	for step = 2, distance, 2 do
		local p = feet + dir * step
		if townWorld.BoxBlocked(d, p.X, p.Y, box.halfW, box.h) then
			break
		end
		reached = step
	end
	return reached
end

-- 같은 씬에서 그 자리 둘레 radius 안에 있는 플레이어들(파티 버프 · 치유꽃)
local function playersNear(key: string, at: Vector2, radius: number): { Player }
	local out = {}
	for _, other in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		local feet = feetOf(other)
		if feet and (feet - at).Magnitude <= radius then
			table.insert(out, other)
		end
	end
	return out
end

-- 설치(zone): 그 자리에 seconds초 동안 남아 interval초마다 둘레 radius에 효과. once면 처음 적이 닿을 때 한 번 터지고 사라진다(덫).
--  같은 사람이 같은 스킬을 limit개 넘게 놓으면 가장 오래된 것이 사라진다. 연출: NinjutsuCast(id … targets = { 번호 }) / 끝날 때 "zone_end"(distance = 번호).
local function endZone(z)
	if not z.dead then
		z.dead = true
		table.remove(zones, table.find(zones, z))
		toScene(z.key, z.owner.UserId, "zone_end", z.x, z.y, 0, 0, z.n, {})
	end
end

local function placeZone(player: Player, key: string, id: string, skill, level: number, at: Vector2)
	local mine = {}
	for _, z in zones do
		if z.owner == player and z.id == id then
			table.insert(mine, z)
		end
	end
	while #mine >= (skill.limit or 1) do
		endZone(table.remove(mine, 1))
	end
	zoneSerial += 1
	local z = { n = zoneSerial, owner = player, id = id, key = key, x = at.X, y = at.Y, untilT = os.clock() + skill.seconds, dead = false }
	table.insert(zones, z)
	local scale = ninjutsu.Scale(id, level)
	local function tick()
		if z.dead then
			return
		end
		if os.clock() >= z.untilT or not player.Parent or townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId)) ~= key then
			endZone(z)
			return
		end
		local attack = inventoryService.GetAttackDamage(player)
		local touched = false
		for _, m in townMonsters.Living(key) do
			if (Vector2.new(m.x, m.y) - at).Magnitude <= skill.radius then
				touched = true
				if skill.power then
					hit(key, m, player, id, skill, attack, scale, 1, nil)
				else
					applyEffects(key, m, player, skill, attack, scale, nil)
				end
			end
		end
		if skill.heal then
			for _, other in playersNear(key, at, skill.radius) do
				local d = persistence.Get(other)
				if d then
					progressionService.Heal(other, math.max(1, math.round(balance.maxHealthFor(d.Level) * skill.heal * scale)))
				end
			end
		end
		if skill.once and touched then
			endZone(z)
			return
		end
		task.delay(skill.interval, tick)
	end
	task.delay(skill.interval, tick)
	return z
end

-- 버프: 나와 둘레 radius 안의 같은 씬 플레이어에게. attack = 공격력 + · haste = 걸음/공격 속도 + · regen = 2초마다 최대 체력의 그 비율 회복
local function applyBuff(player: Player, key: string, id: string, skill, level: number, feet: Vector2)
	local b = skill.buff
	for _, other in playersNear(key, feet, skill.radius) do
		if b.attack then
			local value = b.attack + (b.attackPerLevel or 0) * level
			inventoryService.SetAttackBuff(other, 1 + value, skill.seconds)
			Net.FireClient("BuffUpdated", other, "attack", value, skill.seconds)
			Net.FireClient("Notify", other, ("%s: 공격력 +%d%% (%d초)"):format(skill.name, math.round(value * 100), skill.seconds))
		end
		if b.haste then
			local value = b.haste + (b.hastePerLevel or 0) * level
			haste[other.UserId] = { value = value, untilT = os.clock() + skill.seconds }
			Net.FireClient("BuffUpdated", other, "haste", value, skill.seconds)
			Net.FireClient("Notify", other, ("%s: 걸음 · 공격 속도 +%d%% (%d초)"):format(skill.name, math.round(value * 100), skill.seconds))
		end
		if b.regen then
			local untilT = os.clock() + skill.seconds
			local function tick()
				local d = persistence.Get(other)
				if not d or not other.Parent or os.clock() > untilT then
					return
				end
				progressionService.Heal(other, math.max(1, math.round(balance.maxHealthFor(d.Level) * b.regen * ninjutsu.Scale(id, level))))
				task.delay(2, tick)
			end
			task.delay(2, tick)
			Net.FireClient("BuffUpdated", other, "regen", b.regen, skill.seconds)
			Net.FireClient("Notify", other, ("%s: 조금씩 회복 (%d초)"):format(skill.name, skill.seconds))
		end
	end
end

-- 인술 실행. 못 쓰면(대상 없음 등) false + 이유 — 기력·쿨타임을 쓰지 않는다.
local function cast(player: Player, key: string, id: string, skill, level: number, feet: Vector2, dir: Vector2): (boolean, string?)
	local uid = player.UserId
	local attack = inventoryService.GetAttackDamage(player)
	local scale = ninjutsu.Scale(id, level)
	local kind = skill.kind
	if kind == "projectile" or kind == "seed" then
		local origin = feet - Vector2.new(0, ninjutsu.HAND_Y)
		-- 견고를 실어 던지는 인술(바위 던지기): 견고 하나마다 피해 +, 쓰면 견고를 다 쓴다
		local firmMult = 1
		if skill.firmBonus then
			local coreId, value = coreOf(player, persistence.Get(player))
			if coreId == "r_firm" and value > 0 then
				firmMult = 1 + skill.firmBonus * value
				setCore(player, coreId, 0)
			end
		end
		do
			local function fire()
				local hitT, first = skill.range, nil
				for _, m in townMonsters.Living(key) do
					local rel = Vector2.new(m.x, m.y - ninjutsu.BODY_Y) - origin
					local along = rel:Dot(dir)
					local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
					if along >= 0 and along <= hitT and side <= skill.width + 3 then
						hitT, first = along, m
					end
				end
				toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, hitT, {})
				task.delay(hitT / skill.speed, function()
					if kind == "seed" then
						-- 처음 닿은 몬스터에 박히고, fuse초 뒤 그 몬스터가 있는 자리 둘레에 터진다
						if first and hit(key, first, player, id, skill, attack, scale, 1, nil) then
							task.delay(skill.fuse, function()
								local at = Vector2.new(first.x, first.y)
								for _, m in townMonsters.Living(key) do
									if (Vector2.new(m.x, m.y) - at).Magnitude <= skill.radius then
										hit(key, m, player, id .. ":burst", skill, attack, scale, 1, nil, skill.burstPower)
									end
								end
							end)
						end
						return
					end
					if skill.single then
						-- 한 마리만 맞는 투척(뇌전 수리검): 표식이 이미 있으면 번개가 한 번 더 떨어진다
						if first then
							local mark = skill.mark
							local marked = mark and first.mark and os.clock() < (first.mark[uid] or 0)
							if hit(key, first, player, id, skill, attack, scale, 1, nil) and mark then
								if marked then
									hit(key, first, player, id .. ":mark", skill, attack, scale, 1, nil, mark.power)
								end
								first.mark = first.mark or {}
								first.mark[uid] = os.clock() + mark.seconds
							end
						end
						return
					end
					local at = origin + dir * hitT + Vector2.new(0, ninjutsu.BODY_Y) -- 발 높이로 내려서 잰다
					for _, m in townMonsters.Living(key) do
						if (Vector2.new(m.x, m.y) - at).Magnitude <= skill.radius then
							hit(key, m, player, id, skill, attack, scale, firmMult, dir)
						end
					end
				end)
			end
			fire() -- 첫 발은 바로, 나머지는 shotGap초씩 늦게(연달아 던지는 인술)
			for shot = 2, skill.shots or 1 do
				task.delay((shot - 1) * (skill.shotGap or 0), fire)
			end
		end
	elseif kind == "line" then
		-- hits · interval: 여러 번(follow면 그때그때 내 자리에서). segments: 줄을 나눠 앞에서부터 segDelay초씩 늦게 터진다(falloff배씩 약해짐).
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.length, {})
		local segments = skill.segments or 1
		for h = 1, skill.hits or 1 do
			for seg = 1, segments do
				task.delay((skill.delay or 0) + (h - 1) * (skill.interval or 0) + (seg - 1) * (skill.segDelay or 0), function()
					local from = if skill.follow then feetOf(player) or feet else feet
					local origin = from - Vector2.new(0, ninjutsu.HAND_Y)
					local lo, hi = skill.length * (seg - 1) / segments, skill.length * seg / segments
					for _, m in townMonsters.Living(key) do
						local rel = Vector2.new(m.x, m.y - ninjutsu.BODY_Y) - origin
						local along = rel:Dot(dir)
						local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
						if along >= (if seg == 1 then 0 else lo) and along <= hi and side <= skill.width then
							if hit(key, m, player, id, skill, attack, scale, (skill.falloff or 1) ^ (seg - 1), dir) and skill.pull then
								townMonsters.Push(key, m.id, -dir.X * skill.pull, -dir.Y * skill.pull) -- 끌어당김
							end
						end
					end
				end)
			end
		end
	elseif kind == "circle" then
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.radius, {})
		for i = 1, skill.hits or 1 do
			task.delay((skill.delay or 0) + (i - 1) * (skill.interval or 0), function()
				for _, m in townMonsters.Living(key) do
					local rel = Vector2.new(m.x, m.y) - feet
					if rel.Magnitude <= skill.radius then
						hit(key, m, player, id, skill, attack, scale, 1, if rel.Magnitude > 0 then rel.Unit else dir)
					end
				end
			end)
		end
		if skill.firmGain then -- 발 구르기: 견고 +
			local coreId, value = coreOf(player, persistence.Get(player))
			if coreId == "r_firm" then
				setCore(player, coreId, value + skill.firmGain)
			end
		end
	elseif kind == "shatter" then
		-- 깨뜨리기: 둘레의 얼어붙은 적은 "깨짐"(큰 피해 + 조각이 옆의 적에게), 얼지 않은 적은 서리
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.radius, {})
		task.delay(skill.delay or 0, function()
			local now = os.clock()
			local living = townMonsters.Living(key)
			for _, m in living do
				if (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius then
					if frozen(m, now) then
						m.frozenUntil = nil
						local plain = table.clone(skill)
						plain.frost = nil
						if hit(key, m, player, id, plain, attack, scale, skill.shatter.mult, nil) then
							for _, other in living do
								if other ~= m and (Vector2.new(other.x, other.y) - Vector2.new(m.x, m.y)).Magnitude <= skill.shatter.shardRadius then
									hit(key, other, player, id .. ":shard", plain, attack, scale, 1, nil, skill.shatter.shard)
								end
							end
						end
					else
						hit(key, m, player, id, skill, attack, scale, 1, nil)
					end
				end
			end
		end)
	elseif kind == "detonate" then
		-- 점화: 둘레에서 내 불씨가 걸린 적이 모두 터진다(불씨 수만큼 세게). 터질 때 옆의 적에게 불씨가 옮겨붙는다.
		local now = os.clock()
		local targets = {}
		local living = townMonsters.Living(key)
		for _, m in living do
			local e = m.ember and m.ember[uid]
			if e and now < e.untilT and e.stacks > 0 and (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius then
				table.insert(targets, { m = m, stacks = e.stacks })
			end
		end
		if #targets == 0 then
			return false, "불씨가 걸린 적이 없어요"
		end
		local ids = {}
		for _, t in targets do
			table.insert(ids, t.m.id)
		end
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.radius, ids)
		local plain = table.clone(skill)
		plain.ember = nil
		for _, t in targets do
			t.m.ember[uid].untilT = 0 -- 불씨를 다 쓴다
			if hit(key, t.m, player, id, plain, attack, scale, t.stacks, nil) then
				for _, other in living do
					if other ~= t.m and (Vector2.new(other.x, other.y) - Vector2.new(t.m.x, t.m.y)).Magnitude <= skill.spread then
						addEmber(key, other, player, skill.spreadEmber)
					end
				end
			end
		end
	elseif kind == "discharge" then
		-- 방전: 전하를 모두 써서 둘레에 번개(전하가 많을수록 넓고 세다)
		local coreId, value = coreOf(player, persistence.Get(player))
		if coreId ~= "t_charge" or value < 1 then
			return false, "전하가 없어요"
		end
		local radius = skill.radius + skill.radiusPer * value
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, radius, {})
		setCore(player, coreId, 0)
		task.delay(skill.delay or 0, function()
			for _, m in townMonsters.Living(key) do
				if (Vector2.new(m.x, m.y) - feet).Magnitude <= radius then
					hit(key, m, player, id, skill, attack, scale, 1, nil, skill.power + skill.powerPer * value)
				end
			end
			setCore(player, "t_charge", 0) -- 방전으로 맞힌 것은 전하로 치지 않는다
		end)
	elseif kind == "zone" then
		local at = feet + dir * (skill.offset or 0)
		local z = placeZone(player, key, id, skill, level, at)
		toScene(key, uid, id, at.X, at.Y, dir.X, dir.Y, skill.seconds, { z.n })
	elseif kind == "buff" then
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, 1.2, {})
		applyBuff(player, key, id, skill, level, feet)
	elseif kind == "decoy" then
		-- 얼음 분신: 나를 쫓던 둘레의 적이 seconds초 동안 나를 놓치고, 분신이 깨지며 둘레에 서리
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.seconds, {})
		for _, m in townMonsters.Living(key) do
			if (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius and m.aggro == uid then
				m.aggro, m.target = nil, nil
				townMonsters.Stun(key, m.id, skill.seconds)
			end
		end
		task.delay(skill.seconds, function()
			for _, m in townMonsters.Living(key) do
				if (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius then
					addFrost(key, m, player, skill.frost)
				end
			end
		end)
	elseif kind == "counter" then
		-- 되받아치기: window초 동안 막는 자세 — 그 사이에 맞으면(OnPlayerHurt) 피해 없이 충격파로 되받아친다
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.window, {})
		counterUntil[uid] = { untilT = os.clock() + skill.window, skill = skill, level = level, key = key, id = id }
	elseif kind == "chain" then
		local living = townMonsters.Living(key)
		local chain, used = {}, {}
		local from, reach = feet, skill.range
		for _ = 1, 1 + skill.jumps do
			local best, bestD = nil, reach
			for _, m in living do
				local d = (Vector2.new(m.x, m.y) - from).Magnitude
				if not used[m.id] and d <= bestD then
					best, bestD = m, d
				end
			end
			if not best then
				break
			end
			used[best.id] = true
			table.insert(chain, best)
			from, reach = Vector2.new(best.x, best.y), skill.jumpRange
		end
		if #chain == 0 then
			return false, "가까이에 적이 없어요"
		end
		local ids = {}
		for _, m in chain do
			table.insert(ids, m.id)
		end
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, 0, ids)
		for i, m in chain do
			hit(key, m, player, id, skill, attack, scale, skill.falloff ^ (i - 1), nil)
		end
	elseif kind == "heal" then
		local data = persistence.Get(player)
		local maxHealth = data and balance.maxHealthFor(data.Level)
		if not data or (data.Health or maxHealth) >= maxHealth then
			return false, "체력이 이미 가득해요"
		end
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, 0, {})
		progressionService.Heal(player, math.max(1, math.round(maxHealth * skill.ratio * scale)))
	elseif kind == "guard" then
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.seconds, {})
		townMonsters.SetGuard(player, skill.mult, skill.seconds)
		guardUntil[uid] = os.clock() + skill.seconds
	else
		return false, nil
	end
	if skill.selfHeal then -- 쓰면서 내 체력도 회복(만개 등)
		local data = persistence.Get(player)
		if data then
			progressionService.Heal(player, math.max(1, math.round(balance.maxHealthFor(data.Level) * skill.selfHeal * scale)))
		end
	end
	return true, nil
end

-- 두루마리 쓰기: 자기 유파 것이면 지금 전직의 SP +1 → true(호출한 쪽이 1개 줄인다)
function exports.UseScroll(player: Player, def): boolean
	local data = persistence.Get(player)
	if not data or def.Type ~= "Scroll" then
		return false
	end
	if not ninjutsu.SCHOOL_INFO[data.School or ""] or (data.Job or 0) < 1 then
		Net.FireClient("Notify", player, "먼저 유파를 골라야 해요")
		return false
	end
	if def.School ~= data.School then
		Net.FireClient("Notify", player, ("%s 유파의 두루마리예요"):format(ninjutsu.SCHOOL_INFO[def.School].name))
		return false
	end
	ensure(data)
	data.SP[data.Job] = (data.SP[data.Job] or 0) + 1
	persistence.MarkDirty(player)
	sendSkills(player, data)
	Net.FireClient("Notify", player, ("스킬 포인트 +1 (%d차)"):format(data.Job))
	return true
end

function exports.load()
	Net.OnServer("ChooseSchool", function(player: Player, school: string)
		local data = persistence.Get(player)
		if not data or not ninjutsu.SCHOOL_INFO[school] or data.School == school then
			return
		end
		if not nearNpc(player, ninjutsu.CHANGE_NPC) then
			Net.FireClient("Notify", player, "유파는 마을 스승 곁에서 고를 수 있어요")
			return
		end
		ensure(data)
		local first = (data.Job or 0) == 0
		if first then
			-- 1차 전직: 견습 닌자가 유파에 든다
			if data.Level < ninjutsu.JOB_LEVELS[1] then
				Net.FireClient("Notify", player, ("Lv.%d부터 유파에 들 수 있어요"):format(ninjutsu.JOB_LEVELS[1]))
				return
			end
			data.Job = 1
			data.School = school
			grantJob(data, 1)
		else
			if (data.Gold or 0) < ninjutsu.CHANGE_COST then
				Net.FireClient("Notify", player, ("엽전이 모자라요(%d 필요)"):format(ninjutsu.CHANGE_COST))
				return
			end
			currencyService.AddGold(player, -ninjutsu.CHANGE_COST)
			-- 옛 유파 스킬에 쓴 SP는 돌려받는다(전직하며 그냥 받은 1레벨은 빼고). 공용 스킬은 그대로.
			local old = data.School
			local keep = {}
			for id, level in data.Ninjutsu do
				local s = SK[id]
				local job = ninjutsu.JobOf(id)
				if s and s.school == "" then
					keep[id] = level
				elseif s and job and s.school == old then
					local free = if table.find(ninjutsu.AutoFor(old, job), id) then 1 else 0
					data.SP[job] = (data.SP[job] or 0) + math.max(0, level - free)
				end
			end
			data.Ninjutsu = keep
			data.School = school
			data.SkillSlots = { "", "", "", "" }
			for job = 1, data.Job do
				learnAuto(data, job)
			end
		end
		ready[player.UserId] = nil
		cores[player.UserId] = nil
		persistence.MarkDirty(player)
		task.spawn(persistence.Save, player, false) -- 유파는 캐릭터의 정체성 — 바로 저장
		sendSkills(player, data)
		Net.FireClient("Notify", player, if first
			then ("1차 전직! %s 유파의 %s이(가) 되었어요"):format(ninjutsu.SCHOOL_INFO[school].name, ninjutsu.JOB_NAMES[1])
			else ("%s 유파로 옮겼어요"):format(ninjutsu.SCHOOL_INFO[school].name))
	end)

	-- 2 · 3 · 4차 전직: 다음 전직 레벨이 됐으면 스승 곁에서
	Net.OnServer("JobAdvance", function(player: Player)
		local data = persistence.Get(player)
		local job = data and data.Job or 0
		if not data or job < 1 or job >= #ninjutsu.JOB_LEVELS then
			return
		end
		if not nearNpc(player, ninjutsu.CHANGE_NPC) then
			Net.FireClient("Notify", player, "전직은 마을 스승 곁에서 할 수 있어요")
			return
		end
		local need = ninjutsu.JOB_LEVELS[job + 1]
		if data.Level < need then
			Net.FireClient("Notify", player, ("%d차 전직은 Lv.%d부터예요"):format(job + 1, need))
			return
		end
		data.Job = job + 1
		grantJob(data, data.Job)
		persistence.MarkDirty(player)
		task.spawn(persistence.Save, player, false)
		sendSkills(player, data)
		local id = ninjutsu.AutoFor(data.School, data.Job)[1]
		Net.FireClient("Notify", player, ("%d차 전직! %s이(가) 되어 %s을(를) 배웠어요"):format(data.Job, ninjutsu.JOB_NAMES[data.Job], id and SK[id].name or "스킬 포인트"))
	end)

	-- 스킬 배우기 · 올리기: 그 스킬 전직의 SP 1
	Net.OnServer("LearnSkill", function(player: Player, id: string)
		local data = persistence.Get(player)
		local job = ninjutsu.JobOf(id)
		if not data or not job or not ninjutsu.Belongs(id, data.School) or (data.Job or 0) < job then
			return
		end
		ensure(data)
		local level = levelOf(data, id)
		if level >= ninjutsu.MaxOf(id) then
			return
		end
		if (data.SP[job] or 0) < 1 then
			Net.FireClient("Notify", player, ("%d차 스킬 포인트가 없어요"):format(job))
			return
		end
		data.SP[job] -= 1
		data.Ninjutsu[id] = level + 1
		if level == 0 then
			fillSlot(data, id)
		end
		persistence.MarkDirty(player)
		sendSkills(player, data)
		if id == "c_energy" then
			sendEnergy(player)
		end
	end)

	-- 단축칸에 인술 넣기("" = 비움). 같은 인술은 한 칸에만.
	Net.OnServer("SetSkillSlot", function(player: Player, slot: number, id: string)
		local data = persistence.Get(player)
		if not data or slot ~= math.floor(slot) or slot < 1 or slot > ninjutsu.SLOTS then
			return
		end
		ensure(data)
		if id ~= "" and (not ninjutsu.IsActive(id) or not ninjutsu.Belongs(id, data.School) or levelOf(data, id) < 1) then
			return
		end
		for i = 1, ninjutsu.SLOTS do
			if id ~= "" and data.SkillSlots[i] == id then
				data.SkillSlots[i] = ""
			end
		end
		data.SkillSlots[slot] = id
		persistence.MarkDirty(player)
		sendSkills(player, data)
	end)

	Net.OnServer("UseNinjutsu", function(player: Player, slot: number, facing: string)
		local data = persistence.Get(player)
		if not data or slot ~= math.floor(slot) or slot < 1 or slot > ninjutsu.SLOTS then
			return
		end
		ensure(data)
		local id = data.SkillSlots[slot] or ""
		local skill = SK[id]
		local dir = DIRS[facing]
		if not skill or not dir or not ninjutsu.IsActive(id) then
			return
		end
		local level = levelOf(data, id)
		if level < 1 or not ninjutsu.Belongs(id, data.School) or (data.Job or 0) < (ninjutsu.JobOf(id) or math.huge) then
			return
		end
		local now = os.clock()
		local mine = ready[player.UserId] or {}
		ready[player.UserId] = mine
		if now < (mine[id] or 0) then
			return
		end
		local e = energyOf(player, now)
		if e.value < skill.cost then
			Net.FireClient("Notify", player, "기력이 모자라요")
			return
		end
		local coreId, coreValue = coreOf(player, data)
		if skill.vigorCost and (coreId ~= "p_vigor" or coreValue < skill.vigorCost) then
			Net.FireClient("Notify", player, "생기가 모자라요")
			return
		end
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local feet = feetOf(player)
		if not key or not feet then
			return
		end
		local ok, why = cast(player, key, id, skill, level, feet, dir)
		if not ok then
			if why then
				Net.FireClient("Notify", player, why)
			end
			return
		end
		e.value -= skill.cost
		mine[id] = now + skill.cooldown
		sendEnergy(player)
		if skill.vigorCost then
			setCore(player, "p_vigor", coreValue - skill.vigorCost)
		end
	end)

	-- 대쉬: 견습 = 구르기, 1차 전직부터 유파의 대쉬. 움직임은 클라이언트가 하고(위치는 복제로 따라온다),
	--  순수 이동기라 피해 · 상태 이상이 없다 — 서버는 쿨타임 · 기력만 확인하고 같은 씬에 연출을 알린다(NinjutsuCast "dash_<id>").
	Net.OnServer("UseDash", function(player: Player, facing: string)
		local data = persistence.Get(player)
		local dir = DIRS[facing]
		if not data or not dir then
			return
		end
		local id, dash = ninjutsu.DashFor(data.School, data.Job)
		local now = os.clock()
		local mine = ready[player.UserId] or {}
		ready[player.UserId] = mine
		if now < (mine.dash or 0) then
			return
		end
		local e = energyOf(player, now)
		if e.value < dash.cost then
			Net.FireClient("Notify", player, "기력이 모자라요")
			return
		end
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local feet = feetOf(player)
		if not key or not feet then
			return
		end
		local dist = exports.DashDistance(key, feet, dir, dash.distance)
		mine.dash = now + dash.cooldown
		if dash.cost > 0 then
			e.value -= dash.cost
			sendEnergy(player)
		end
		toScene(key, player.UserId, "dash_" .. id, feet.X, feet.Y, dir.X, dir.Y, dist, {})
	end)

	-- 기본 공격이 맞으면: 기력 · 전하 · 달궈진 칼날(불) · 정전기(번개)
	townMonsters.OnPlayerAttack(function(player: Player, key: string, _feet, _facing, hitIds)
		if #hitIds == 0 then
			return
		end
		exports.AddEnergy(player, #hitIds * ninjutsu.ENERGY_PER_HIT)
		gainCharge(player)
		local data = persistence.Get(player)
		local uid = player.UserId
		counters[uid] = (counters[uid] or 0) + 1
		for _, id in { "f_blade", "t_static" } do
			local def = SK[id]
			local level = levelOf(data, id)
			if level >= 1 and data.School == def.school and counters[uid] % def.every == 0 then
				local amount = math.max(1, math.round(inventoryService.GetAttackDamage(player) * (def.power + def.perLevel * level)))
				local done = 0
				for _, m in townMonsters.Living(key) do
					if table.find(hitIds, m.id) and (id ~= "t_static" or done == 0) then -- 정전기는 한 마리에게만
						done += 1
						if townMonsters.Damage(key, m.id, player, amount, "nin:" .. id) and def.ember then
							addEmber(key, m, player, def.ember)
						end
					end
				end
			end
		end
	end)

	-- 몬스터에게 맞을 때: 얼음 갑옷(피해 감소 + 때린 적에게 서리) · 견고(피해 감소 + 쌓임)
	townMonsters.OnPlayerHurt(function(player: Player, key: string, m, damage: number): number
		local data = persistence.Get(player)
		-- 되받아치기: 자세 중에 맞으면 피해 없이 둘레에 충격파 + 견고 가득
		local c = counterUntil[player.UserId]
		if c and os.clock() < c.untilT then
			counterUntil[player.UserId] = nil
			local feet = feetOf(player)
			local attack = inventoryService.GetAttackDamage(player)
			if feet then
				for _, other in townMonsters.Living(c.key) do
					if (Vector2.new(other.x, other.y) - feet).Magnitude <= c.skill.radius then
						hit(c.key, other, player, c.id, c.skill, attack, ninjutsu.Scale(c.id, c.level), 1, nil)
					end
				end
			end
			local coreId = coreOf(player, data)
			if coreId == "r_firm" then
				setCore(player, coreId, SK.r_firm.stacks)
			end
			return 0
		end
		local root = levelOf(data, "p_root")
		if root >= 1 and data.School == "plant" and m.rootUntil and os.clock() < m.rootUntil then
			damage *= 1 - SK.p_root.reducePerLevel * root -- 뿌리 표식이 있는 적은 덜 아프게 때린다
		end
		local heavy = levelOf(data, "r_heavy")
		if heavy >= 1 and data.School == "rock" then
			damage *= 1 - SK.r_heavy.perLevel * heavy
		end
		local armor = levelOf(data, "i_armor")
		if armor >= 1 and data.School == "ice" then
			damage *= 1 - SK.i_armor.perLevel * armor
			addFrost(key, m, player, SK.i_armor.frost)
		end
		local coreId, value, level = coreOf(player, data)
		if coreId == "r_firm" then
			local def = SK.r_firm
			damage *= 1 - (def.reduce + def.perLevel * level) * value
			local guarded = os.clock() < (guardUntil[player.UserId] or 0)
			setCore(player, coreId, value + (if guarded then def.guardGain else 1))
		end
		return damage
	end)

	-- 전하: 하나마다 기본 공격이 빨라진다(공격 간격 × 이 배율)
	townMonsters.OnAttackSpeed(function(player: Player): number
		local mult = 1
		local coreId, value, level = coreOf(player, persistence.Get(player))
		if coreId == "t_charge" then
			mult /= 1 + (SK.t_charge.speedPer + SK.t_charge.perLevel * level) * value
		end
		local h = haste[player.UserId]
		if h and os.clock() < h.untilT then
			mult /= 1 + h.value -- 질풍
		end
		return mult
	end)

	Players.PlayerRemoving:Connect(function(player)
		energy[player.UserId] = nil
		ready[player.UserId] = nil
		cores[player.UserId] = nil
		counters[player.UserId] = nil
		guardUntil[player.UserId] = nil
		counterUntil[player.UserId] = nil
		haste[player.UserId] = nil
		for i = #zones, 1, -1 do
			if zones[i].owner == player then
				endZone(zones[i])
			end
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports
