-- 「달의 계승자」 — 처음부터 2차 전직까지 끊김 없이 해 보는 가상의 플레이.
--  사용자 2026-10-11: "스스로 검증해보세요 게임을 시작해서 30까지 찍는걸 유저가 자연스럽게 플레이할수있는지"
--  만든 까닭: Studio에서 손으로 해 보면(키를 보내고 → 화면을 보고 → 다음 키를 보낸다) 그 사이의 빈 시간에 캐릭터가 서서 맞는다 — Lv.4에 그렇게 한 번 쓰러졌다.
--   그래서 진짜 서버의 셈(world.luau) 위에서, 사람이 하듯 한 순간도 쉬지 않고 움직이는 가상의 플레이어를 Lv.1부터 돌려 본다.
--  가상의 플레이어가 하는 일(화면이 알려 주는 것만 따른다 — 알리미의 길잡이 · 퀘스트 창):
--   ① 돌려줄 퀘스트가 있으면 그 주민에게 걸어가 돌려준다 ② 받을 수 있는 메인 · 부탁이 있으면 그 주민에게 걸어가 받는다
--   ③ 하는 중인 퀘스트의 맵에서 그 몬스터를 잡는다(없으면 내 레벨에 맞는 사냥터에서 아무 몬스터나) ④ 떨어진 것을 줍고, 더 좋은 장비면 장착한다
--   ⑤ 체력이 절반 아래면 물약을 마신다 ⑥ 물약이 다섯 병 아래면 잡화 상인에게 걸어가 산다 ⑦ 레벨이 오르면 「자동으로 찍기」 · 「추천대로 찍기」
--   ⑧ 쓰러지면 「마을로 돌아간다」.
--  걷는 것: 달리는 빠르기(92도트/초)로 한 틱씩 옮긴다(맵을 지나는 동안 몬스터가 닿으면 맞는다). 층을 오르내리는 데는 48도트에 0.9초를 쓴다(뛰는 시간의 어림).
--   ⑨ Lv.8 · 10 · 13 · 16 · 20 · 22 · 24 · 26 · 28에 한 번씩 대장장이에게 들른다: 그 레벨대(Lv.1 · 10 · 20)의 장비가 아닌 부위는 제작하고(재료가 모자라면 상점에서 산다 — Lv.10의 것만 판다),
--      끼고 있는 장비를 달가루가 닿는 데까지 강화한다(달가루가 모자라면 산다 · 달돈 500은 물약 값으로 남긴다). gear = false로 부르면 이것을 하지 않는다(떨어진 장비만 낀다).
--  사냥기만 쓴다(대쉬 · 보스기 · 사출기는 안 쓴다) — 서툰 사람의 플레이에 가깝다.
--  결과는 [PLAY] 줄로 찍는다. 그냥 돌리면(python tools/test/run.py) 한 직업을 Lv.8까지만 보고, 끝까지 보려면: LUNE_PLAY=axion,salamander python tools/test/run.py 29_lune_playthrough
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local G = req("ReplicatedStorage/shared/lune/config/game")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local TICK = 1 / 20
local SPEED = G.RUN

local handlers = {}
local gains = 0 -- 잡아서 받은 경험치 알림의 수(= 잡은 마릿수)
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, _player, data)
		if name == "Gain" and typeof(data) == "table" and data.quest == nil then
			gains += 1
		end
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, book = {}, {}
local rankDisk, rankInfo = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function(board, key, score) rankDisk[board] = rankDisk[board] or {}; rankDisk[board][key] = score end,
	rankRemove = function(board, key) if rankDisk[board] then rankDisk[board][key] = nil end end,
	rankTop = function() return {} end,
	rankInfoSet = function(key, info) rankInfo[key] = info end,
	rankInfoGet = function(key) return rankInfo[key] end,
	rankInfoRemove = function(key) rankInfo[key] = nil end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local ItemInfo = req("ReplicatedStorage/shared/lune/ui/itemInfo")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
World.start()

local function person(t)
	t.attrs = {}
	t.SetAttribute = function(self, key, value) self.attrs[key] = value end
	return t
end
local function routeNext(from, target)
	local prev, queue = { [from] = from }, { from }
	while #queue > 0 do
		local cur = table.remove(queue, 1)
		if cur == target then
			while prev[cur] ~= from do
				cur = prev[cur]
			end
			return cur
		end
		for _, portal in SCENES.scenes[cur].portals do
			if not prev[portal.to] then
				prev[portal.to] = cur
				table.insert(queue, portal.to)
			end
		end
	end
	return nil
end
local function clock(t: number): string
	return ("%d:%02d"):format(math.floor(t / 3600), math.floor(t % 3600 / 60))
end

-- 1지역의 사냥터들(몬스터가 있는 장면)과 그 몬스터의 가장 낮은 레벨 — 내 레벨에 맞는 사냥터를 고를 때(월드맵의 풀빛 이름과 같은 규칙)
local GROUNDS = {}
for key, sc in SCENES.scenes do
	if sc.region == "r1" and #(sc.mobs or {}) > 0 then
		local lo = math.huge
		for _, m in sc.mobs do
			lo = math.min(lo, m.lv)
		end
		table.insert(GROUNDS, { key = key, lo = lo })
	end
end
table.sort(GROUNDS, function(a, b)
	if a.lo ~= b.lo then
		return a.lo < b.lo
	end
	return a.key < b.key
end)

-- 한 사람의 플레이. goal = { level = 멈출 레벨, job = 2차 전직까지 }, cap = 게임 안 시간의 한도(초). 돌려주는 것: 기록
local uid = 2900
local GEAR_AT = { 8, 10, 13, 16, 20, 22, 24, 26, 28 }
local function play(class: string, goal, cap: number, gear: boolean?)
	uid += 1
	local p = person({ UserId = uid, Name = "play" .. uid })
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", "해본다" .. uid, class)
	handlers.Chars(p, "enter", made.id)
	local s = World.session(p)
	local h = s.hero
	local t0 = World.now
	local stat = { kills = 0, deaths = 0, potions = 0, bought = 0, trips = 0, quests = 0, stuck = 0, levels = {}, log = {}, diedAt = {}, forge = 0, crafted = 0, shopGear = 0, stars = 0 }
	local gearNext = 1 -- GEAR_AT의 다음 차례
	local places = {} -- 장면마다: 머문 시간 · 잡은 수 · 마신 물약 · 쓰러진 수(어느 사냥터가 위험한지 본다)
	local function placeOf(key: string)
		local r = places[key]
		if not r then
			r = { key = key, time = 0, kills = 0, potions = 0, deaths = 0, lo = 99, hi = 0 }
			places[key] = r
		end
		return r
	end
	local gainsWas = 0
	local skip = {} -- 받지 못한 퀘스트(다시 가지 않는다)
	gains = 0
	local function now(): number
		return World.now - t0
	end
	local function note(text: string)
		table.insert(stat.log, ("%s Lv.%d %s"):format(clock(now()), h.level, text))
	end

	-- 사냥기(1차)와 서는 거리
	local skillId, skill = nil, nil
	for id, sk in COMBAT.skills do
		if sk.who == class and sk.type == "mob" and sk.job == 1 then
			skillId, skill = id, sk
		end
	end
	local reach = 0
	for _, hit in skill.hits do
		reach = math.max(reach, hit.box[2])
	end
	local stand = math.min(reach - 10, 30)
	-- 보스기(1차): 스토리 보스(망루의 부관 · 정찰대장 — 2026-10-11)에게는 이것을 쓴다(보스에게 제 힘을 낸다)
	local bossSkillId, bossSkill = nil, nil
	for id, sk in COMBAT.skills do
		if sk.who == class and sk.type == "boss" and sk.job == 1 then
			bossSkillId, bossSkill = id, sk
		end
	end
	local bossReach = 0
	for _, hit in bossSkill.hits do
		bossReach = math.max(bossReach, hit.box[2])
	end
	local bossStand = math.min(bossReach - 10, 30)

	local function potionCount(): number
		local n = 0
		for _, g in Items.data.GOODS do
			if g.kind == "potion" then
				n += Bag.count(h, g.id)
			end
		end
		return n
	end
	local lastLevel = h.level
	-- 한 틱: 시간이 흐르고, 체력이 절반 아래면 물약을 마시고, 레벨이 올랐으면 점수를 찍는다
	local function tickOne()
		-- 스토리 보스의 방: 가상의 플레이어는 예고를 보고 다 피한다고 친다(물러나거나 뛰는 움직임까지 흉내 내지는 않는다 — 예고 · 내달리기 · 물결이 있는 동안 맞지 않게 둔다).
		--  그래서 이 검사는 보스에게 얼마나 맞는지는 재지 못한다(보스를 잡는 데 걸리는 시간 · 그 뒤의 길이 이어지는지를 본다). 불려 나온 검병에게는 보통처럼 맞는다
		do
			local room = World.room(s.scene)
			local danger = room.waves ~= nil and #room.waves > 0
			for _, b in room.bosses or {} do
				danger = danger or b.state == "tell" or b.state == "dash"
			end
			if danger and not PLAY_NODODGE then -- LUNE_PLAY_NODODGE=1: 피하지 않고 서서 친다(그래도 깨지는지 잰다 — 사용자 2026-10-11: "깰수가 없는 수준")
				h.invuln = math.max(h.invuln, 0.3)
			end
		end
		World.tick(TICK)
		local here = placeOf(s.scene)
		here.time += TICK
		here.kills += gains - gainsWas
		gainsWas = gains
		here.lo, here.hi = math.min(here.lo, h.level), math.max(here.hi, h.level)
		if h.alive and h.hp < h.maxHp * 0.5 then
			local c0 = potionCount()
			if c0 > 0 then
				handlers.Potion(p)
				if potionCount() < c0 then
					stat.potions += 1
					here.potions += 1
				end
			end
		end
		if h.level ~= lastLevel then
			lastLevel = h.level
			handlers.StatAuto(p)
			handlers.SkillAuto(p)
			stat.kills = gains
			table.insert(stat.levels, { level = h.level, t = now(), kills = gains, deaths = stat.deaths, potions = stat.potions, money = h.money, scene = s.scene, hp = h.maxHp, power = Hero.power(h) })
		end
	end
	local function wait(seconds: number)
		for _ = 1, math.ceil(seconds / TICK) do
			tickOne()
		end
	end
	-- 걷는다: 층이 다르면 먼저 오르내리고(시간만 쓴다), 달리는 빠르기로 한 틱씩. 쓰러지면 false
	local function walkTo(x: number, y: number): boolean
		if not h.alive then
			return false
		end
		if math.abs(h.y - y) > 2 then
			wait(math.abs(h.y - y) / 48 * 0.9)
			if not h.alive then
				return false
			end
			-- 층을 바꾸는 것은 검사의 지름길이다(사다리 · 발판을 타는 길을 셈하지 않는다): 서버의 자리를 바로 옮긴다
			--  (2026-10-18: 이동 판정이 「막 옮긴 직후」에도 아무 데나 받지 않게 되어 Move로는 먼 층으로 가지 못한다)
			h.y = y
			s.jumped, s.stale, s.moveAt = false, nil, nil
		end
		local guard = 0
		while math.abs(h.x - x) > 1 do
			if not h.alive then
				return false
			end
			local d = math.clamp(x - h.x, -SPEED * TICK, SPEED * TICK)
			s.jumped, s.stale = true, nil
			handlers.Move(p, h.x + d, h.y, if d >= 0 then 1 else -1)
			tickOne()
			guard += 1
			if guard > 4000 then
				return false
			end
		end
		return h.alive
	end
	-- 맵에서 맵으로(문을 따라)
	local function travel(target: string): boolean
		for _ = 1, 40 do
			if SCENES.base(s.scene) == target then -- (파티마다 따로 들어가는 장면의 방 — r1c4#5 · 2026-10-21)
				return true
			end
			local hop = routeNext(s.scene, target)
			if not hop then
				return false
			end
			local went = false
			for _, portal in SCENES.scenes[s.scene].portals do
				if portal.to == hop then
					if not walkTo(portal.x, portal.y) then
						return false
					end
					went = handlers.Travel(p, hop) and true or false
					break
				end
			end
			if not went then
				return false
			end
		end
		return SCENES.base(s.scene) == target
	end
	local function npcAt(key: string, npcId: string)
		for _, n in SCENES.scenes[key].npcs or {} do
			if n.id == npcId then
				return n
			end
		end
		return nil
	end
	local function goNpc(def, npcId: string): boolean
		local key = Quests.npcScene(def, npcId)
		if not key or not travel(key) then
			return false
		end
		local n = npcAt(key, npcId)
		return n ~= nil and walkTo(n.x + 8, n.y)
	end
	-- 더 좋은 장비면 장착하고, 가방이 차 가면 안 쓰는 장비를 분해한다
	local function tidy()
		for i = 1, Bag.size(h) do
			local it = h.gear[i]
			if it and Bag.canWear(h, it) then
				local cur = h.equip[it.slot]
				if not cur or ItemInfo.wearDiff(it, cur, Hero.specView(h)) > 0 then -- 바꾸면 전투력이 오르는가(2026-10-15 스펙 — 장비의 옵션으로)
					handlers.Item(p, "equip", it.id)
				end
			end
		end
		if Bag.free(h) <= 3 then
			for i = 1, Bag.size(h) do
				local it = h.gear[i]
				if it then
					handlers.Item(p, "dismantle", it.id)
				end
			end
		end
	end
	-- 내 것이 가까이 떨어져 있으면 걸어가 줍는다
	local function loot(room)
		for _ = 1, 8 do
			local best, bd = nil, 140
			for _, d in room.drops do
				if d.owner == h.id and math.abs(d.y - h.y) <= 24 then
					local dist = math.abs(d.x - h.x)
					if dist < bd then
						best, bd = d, dist
					end
				end
			end
			if not best or not walkTo(best.x, h.y) then
				break
			end
			handlers.Pickup(p, best.id)
			if room.drops[best.id] then
				break -- 못 주웠다(가방이 가득 찼다)
			end
		end
		tidy()
	end
	-- 한 마리와 싸운다: 사냥기가 닿는 자리에 서서 되풀이해 쓴다. 60초 안에 못 잡으면 그만둔다
	local function fight(mob): boolean
		local began = World.now
		while mob.hp > 0 and h.alive do
			local dir = if mob.x >= h.x then 1 else -1
			local useId, use, far = skillId, skill, stand
			if mob.boss then
				useId, use, far = bossSkillId, bossSkill, bossStand
			end
			local tx = math.clamp(mob.x - far * dir, 8, SCENES.scenes[s.scene].w * G.TILE - 8)
			if math.abs(h.x - tx) > 6 or math.abs(h.y - mob.y) > 2 then
				if not walkTo(tx, mob.y) then
					return false
				end
				dir = if mob.x >= h.x then 1 else -1
			end
			for i, seg in use.segs do
				handlers.Skill(p, useId, i, h.x, h.y, dir)
				wait(seg.time)
			end
			if World.now - began > (if mob.boss then 600 else 60) then
				return false
			end
		end
		return mob.hp <= 0
	end
	-- 그 맵에서 사냥한다: want(몬스터의 종류 — 없으면 아무거나)를 가까운 것부터. done()이 참이 되거나 시간이 다 되면 멈춘다
	local function hunt(sceneKey: string, want: string?, seconds: number, done: () -> boolean)
		if not travel(sceneKey) then
			return
		end
		local room = World.room(s.scene) -- (파티마다 따로 들어가는 장면이면 그 방 — r1c4#5)
		local tEnd = World.now + seconds
		while World.now < tEnd and h.alive and not done() do
			local best, bd = nil, math.huge
			for _, mob in room.mobs do
				if mob.hp > 0 and not mob.away and (want == nil or mob.kind == want) then -- away = 서 있지 않은 스토리 보스 · 불리지 않은 검병
					local d = math.abs(mob.x - h.x) + math.abs(mob.y - h.y) * 2
					if d < bd then
						best, bd = mob, d
					end
				end
			end
			if best then
				fight(best)
				if h.alive then
					loot(room)
				end
			else
				wait(0.5)
			end
		end
	end
	-- 물약이 모자라면 잡화 상인에게 다녀온다(가까운 상인 — 문을 따라)
	local function shopping()
		if potionCount() >= 5 or h.money < 6 * 10 then
			return
		end
		local seen, queue, at = { [s.scene] = true }, { s.scene }, 1
		local where, who = nil, nil
		while queue[at] and not where do
			local key = queue[at]
			at += 1
			for _, n in SCENES.scenes[key].npcs or {} do
				if Items.data.NPCDO[n.id] == "shop" then
					where, who = key, n
					break
				end
			end
			for _, portal in SCENES.scenes[key].portals do
				if not seen[portal.to] then
					seen[portal.to] = true
					table.insert(queue, portal.to)
				end
			end
		end
		if not where or not travel(where) or not walkTo(who.x + 8, who.y) then
			return
		end
		local stock = Items.stock("potion1")
		local n = math.min(60, math.floor(h.money * 0.8 / Items.stockPrice(stock, h.level)))
		if n >= 1 then
			local c0 = potionCount()
			handlers.Item(p, "buy", "potion1", n)
			stat.bought += potionCount() - c0
			stat.trips += 1
		end
	end
	-- 대장장이에게 들른다: 그 레벨대의 장비를 맞추고(제작 → 상점), 강화한다
	local function smithing()
		if gear == false or not GEAR_AT[gearNext] or h.level < GEAR_AT[gearNext] then
			return
		end
		while GEAR_AT[gearNext] and h.level >= GEAR_AT[gearNext] do
			gearNext += 1
		end
		-- 그 일을 하는 주민(NPCDO)을 가장 가까운 장면에서 찾아 그 앞으로 간다
		local function goTo(kind: string): boolean
			local seen, queue, at = { [s.scene] = true }, { s.scene }, 1
			local where, who = nil, nil
			while queue[at] and not where do
				local key = queue[at]
				at += 1
				for _, n in SCENES.scenes[key].npcs or {} do
					if Items.data.NPCDO[n.id] == kind then
						where, who = key, n
						break
					end
				end
				for _, portal in SCENES.scenes[key].portals do
					if not seen[portal.to] then
						seen[portal.to] = true
						table.insert(queue, portal.to)
					end
				end
			end
			return where ~= nil and travel(where) and walkTo(who.x + 8, who.y)
		end
		-- 달가루는 잡화 상인이 판다(2026-10-15 — 대장장이의 상점을 없앴다): 끼고 있는 것을 10성까지 올리는 데 드는 만큼(평균 시도 수로) · 달돈 500은 물약 값으로 남긴다
		if h.level >= Items.data.OPEN.forge and goTo("shop") then
			local want = 0
			for _, it in h.equip do
				for star = it.star, 9 do
					local row = Items.data.ENHANCE.table[star + 1]
					want += Items.enhanceDust(it.stage, star) * 100 / row[1]
				end
			end
			local need = math.floor(math.max(0, want - h.dust))
			local afford = math.floor(math.max(0, h.money - 500) / Items.stockPrice(Items.stock("dust")))
			if math.min(need, afford) > 0 then
				handlers.Item(p, "buy", "dust", math.min(need, afford))
			end
		end
		if not goTo("smith") then
			return
		end
		stat.forge += 1
		local stage = if h.level >= 20 then 20 elseif h.level >= 10 then 10 else 1
		for _, slot in { "weapon", "hat", "suit", "glove", "shoes" } do
			local cur = h.equip[slot]
			if not cur or cur.stage < stage then
				local used = Bag.used(h, "gear")
				handlers.Item(p, "craft", ("c%d_%s"):format(stage, slot))
				if Bag.used(h, "gear") > used then
					stat.crafted += 1
				end -- (대장장이가 팔던 Lv.10 장비는 없다 — 2026-10-15)
			end
		end
		tidy()
		for _, slot in { "weapon", "suit", "hat", "glove", "shoes" } do
			for _ = 1, 12 do
				local it = h.equip[slot]
				if not it then
					break
				end
				local info = Items.enhanceInfo(it, false, h.forged ~= true and it.star == 0)
				if not info.can then
					break
				end
				if h.dust < info.dust then
					break -- 달가루는 상인에게서 미리 사 왔다(대장장이는 팔지 않는다)
				end
				local star = it.star
				handlers.Item(p, "enhance", it.id, false)
				local after = h.equip[slot]
				if not after then
					tidy() -- 부서졌다(1지역의 별에서는 일어나지 않는다) — 가방의 것을 다시 낀다
					break
				elseif after.star > star then
					stat.stars += 1
				elseif h.dust < info.dust then
					break
				end
			end
		end
	end
	-- 퀘스트: 돌려주기 → 메인 받기 → 부탁 받기. 무엇인가 했으면 true
	local function questRound(): boolean
		for _, id in Quests.active(h.quests) do
			if Quests.state(h.quests, h.level, id) == "ready" and not skip[id] then
				local def = Quests.def(id)
				if goNpc(def, def.endNpc) then
					handlers.Quest(p, "complete", id)
					if h.quests[id] and h.quests[id].done then
						stat.quests += 1
						note(("「%s」 끝"):format(def.name))
					else
						skip[id] = true
						note(("「%s」을 돌려주지 못했다"):format(def.name))
					end
				end
				return true
			end
		end
		-- 전직 퀘스트: 레벨이 되면 사제에게 가서 받는다(2026-10-11부터 저절로 받지 않는다 — 화면은 「달이 부른다」와 알리미의 길잡이로 알린다)
		for _, job in Quests.openJobs(h.quests, h.level) do
			if not skip[job.id] then
				if goNpc(job, job.giver) then
					handlers.Quest(p, "accept", job.id)
					if h.quests[job.id] then
						note(("「%s」 받음"):format(job.name))
					else
						skip[job.id] = true
						note(("「%s」을 받지 못했다"):format(job.name))
					end
				end
				return true
			end
		end
		local def, why = Quests.nextMain(h.quests, h.level)
		if def and why == "open" and not def.auto and not skip[def.id] and def.region == "r1" then
			if goNpc(def, def.giver) then
				handlers.Quest(p, "accept", def.id)
				if h.quests[def.id] then
					note(("「%s」 받음"):format(def.name))
				else
					skip[def.id] = true
					note(("「%s」을 받지 못했다"):format(def.name))
				end
			end
			return true
		end
		for _, side in Quests.openSides(h.quests, h.level) do
			if side.region == "r1" and not skip[side.id] then
				if goNpc(side, side.giver) then
					handlers.Quest(p, "accept", side.id)
					if h.quests[side.id] then
						note(("부탁 「%s」 받음"):format(side.name))
					else
						skip[side.id] = true
					end
				end
				return true
			end
		end
		return false
	end
	-- 하는 중인 퀘스트의 아직 못 한 일(전직 → 메인 → 부탁)
	local function todo()
		for _, id in Quests.active(h.quests) do
			local def, st = Quests.def(id), h.quests[id]
			if not skip[id] then
				for i, step in def.steps do
					if (st.c[i] or 0) < step.n then
						return def, step, i
					end
				end
			end
		end
		return nil
	end
	local function ground(): string
		local pick = GROUNDS[1].key
		for _, g in GROUNDS do
			if g.lo <= h.level then
				pick = g.key
			end
		end
		return pick
	end

	-- 튜토리얼 「달빛 꿈」(2026-10-14): 새 캐릭터는 꿈에서 시작한다 — 미션을 차례로 한다. 화면만 아는 일(걷기 · 뛰기 · 내려가기 · 말 걸기 · 기술 · 창)은 그 자리에 가서 화면처럼 "끝냈다"고 알리고,
	--  잡기 · 줍기 · 물약 · 빛나는 문은 실제로 한다(서버가 센다). 다 하면 사당에서 깨어난다
	local function dream()
		local Tut = req("ReplicatedStorage/shared/lune/sim/tutorial")
		if not Tut.isDream(s.scene) then -- (꿈은 사람마다 따로 된 방 — dream#번호)
			return
		end
		local sc = SCENES.scenes[Tut.SCENE]
		local guard = 0
		while not h.tut.done and guard < 80 and h.alive do
			guard += 1
			local def = Tut.current(h.tut)
			local kind, step = Tut.kind(def), h.tut.step
			if guard == 1 or step ~= (stat.dreamStep or 0) then
				stat.dreamStep = step
				note(("꿈 %d/%d %s(%s)"):format(step, Tut.TOTAL, def.title, kind))
			end
			if kind == "zone" then
				for _, z in sc.tut do
					if z.id == def.check.zone then
						walkTo((z.a + z.b) / 2, z.y)
					end
				end
				handlers.Tut(p, "done", step)
			elseif kind == "talk" then
				local n = npcAt(Tut.SCENE, def.check.talk)
				if n then
					walkTo(n.x + 8, n.y)
				end
				handlers.Tut(p, "done", step)
			elseif Tut.CLIENT[kind] then
				if kind == "walk" then
					walkTo(h.x + def.check.walk + 8, h.y)
				end
				handlers.Tut(p, "done", step)
			elseif kind == "kill" or kind == "pickup" then
				hunt(Tut.SCENE, nil, 120, function()
					return h.tut.step ~= step
				end)
			elseif kind == "potion" then
				handlers.Potion(p)
			elseif kind == "stat" then
				handlers.StatAuto(p)
			elseif kind == "sp" then
				handlers.SkillAuto(p)
			elseif kind == "exit" then
				travel(Tut.DATA.exit)
			end
			if h.tut.step == step and not h.tut.done then
				wait(0.2)
			end
		end
		note(if h.tut.done then "꿈에서 깨어났다(튜토리얼 끝)" else "꿈에서 깨지 못했다(튜토리얼이 막혔다)")
		stat.dreamDone = h.tut.done
		if not h.tut.done then
			local def = Tut.current(h.tut)
			error(("꿈에서 깨지 못했다 — %d째 미션 「%s」(%s) · Lv.%d · 장면 %s · 체력 %d/%d"):format(h.tut.step, def and def.title or "?", def and Tut.kind(def) or "?", h.level, s.scene, h.hp, h.maxHp))
		end
	end
	dream()
	note("시작")
	while now() < cap do
		if (goal.job and h.job >= goal.job) or (not goal.job and h.level >= goal.level) then
			break
		end
		if not h.alive then
			stat.deaths += 1
			placeOf(s.scene).deaths += 1
			table.insert(stat.diedAt, ("Lv.%d %s"):format(h.level, SCENES.scenes[s.scene].name))
			note(("쓰러짐 — %s"):format(SCENES.scenes[s.scene].name))
			local guard = 0
			while not Hero.canReturn(h) and guard < 400 do
				World.tick(TICK)
				guard += 1
			end
			handlers.Return(p)
			if not h.alive then
				stat.stuck += 1
				break
			end
			continue
		end
		shopping()
		smithing()
		if not h.alive then
			continue
		end
		if questRound() then
			continue
		end
		local def, step, index = todo()
		if def and step.type == "use" then
			if travel(def.scene) and walkTo(step.x - 10, step.y) then
				handlers.Quest(p, "use", def.id)
				if (h.quests[def.id].c[index] or 0) < step.n then
					skip[def.id] = true
					note(("「%s」의 자리에서 ↑가 듣지 않았다"):format(def.name))
				end
			end
		elseif def then
			local st = h.quests[def.id]
			local c0 = st.c[index] or 0
			hunt(def.scene, step.mob, if COMBAT.mobs[step.mob].boss then 900 else 240, function() -- 스토리 보스는 체력이 일반 몬스터의 수십 배다
				return (st.c[index] or 0) >= step.n
			end)
			if h.alive and (st.c[index] or 0) == c0 then
				stat.stuck += 1
				skip[def.id] = true
				note(("「%s」의 %s — 4분 동안 하나도 못 했다"):format(def.name, step.name))
			end
		else
			-- 할 퀘스트가 없다: 내 레벨에 맞는 사냥터에서 레벨이 오를 때까지(길어도 5분씩 끊어 다시 본다)
			local lv = h.level
			hunt(ground(), nil, 300, function()
				return h.level ~= lv
			end)
		end
	end
	stat.kills = gains
	stat.time = now()
	stat.level = h.level
	stat.job = h.job
	stat.money = h.money
	stat.left = potionCount()
	stat.power = Hero.power(h)
	stat.class = class
	stat.places = {}
	for _, r in places do
		if r.kills > 0 then
			table.insert(stat.places, r)
		end
	end
	table.sort(stat.places, function(a, b)
		if a.lo ~= b.lo then
			return a.lo < b.lo
		end
		return a.key < b.key
	end)
	stat.gear = gear
	World.removePlayer(p)
	World.removePlayer(p) -- 끝난 캐릭터는 내보낸다(남아 있으면 다음 직업을 도는 동안 그 캐릭터도 셈해 실제 시간이 늘어진다 — 2026-10-15)
	return stat
end

local function report(stat)
	print(("[PLAY] ===== %s%s — %s에 Lv.%d(%d차) · 잡은 수 %d · 쓰러짐 %d · 물약 %d병(산 것 %d병 · 상점 %d번) · 끝낸 퀘스트 %d · 달돈 %d · 전투력 %d · 대장간 %d번(제작 %d · 상점 장비 %d · 붙인 별 %d) ====="):format(
		stat.class, if stat.gear == false then "(떨어진 장비만)" else "", clock(stat.time), stat.level, stat.job, stat.kills, stat.deaths, stat.potions, stat.bought, stat.trips, stat.quests, stat.money, stat.power, stat.forge, stat.crafted, stat.shopGear, stat.stars))
	local prevT, prevK, prevD, prevP = 0, 0, 0, 0
	for _, r in stat.levels do
		print(("[PLAY] %s Lv.%-2d %s(+%4.1f분) · %3d마리 · 쓰러짐 %d · 물약 %2d · 달돈 %5d · 체력 %4d · 전투력 %4d · %s"):format(
			stat.class, r.level, clock(r.t), (r.t - prevT) / 60, r.kills - prevK, r.deaths - prevD, r.potions - prevP, r.money, r.hp, r.power, SCENES.scenes[r.scene].name))
		prevT, prevK, prevD, prevP = r.t, r.kills, r.deaths, r.potions
	end
	for _, line in stat.log do
		print("[PLAY] " .. stat.class .. " · " .. line)
	end
	-- 사냥터마다: 머문 시간 · 잡은 수 · 한 마리에 든 시간(걷기 · 줍기 · 기다리기까지) · 물약(10분에 몇 병) · 쓰러진 수
	for _, r in stat.places do
		print(("[PLAY] %s 곳 %-10s Lv.%d~%d · %5.1f분 · %4d마리(한 마리 %4.1f초) · 물약 %3d병(10분에 %4.1f병) · 쓰러짐 %d"):format(
			stat.class, SCENES.scenes[r.key].name, r.lo, r.hi, r.time / 60, r.kills, r.time / math.max(1, r.kills), r.potions, r.potions / math.max(1, r.time / 600), r.deaths))
	end
	if #stat.diedAt > 0 then
		print("[PLAY] " .. stat.class .. " 쓰러진 곳: " .. table.concat(stat.diedAt, " / "))
	end
end

-- 만약에: LUNE_PLAY_XP=2로 돌리면 Lv.10부터 받는 경험치(사냥 · 퀘스트)를 그 배로 친다 — 「한 레벨에 드는 경험치를 절반으로 줄이면 얼마나 걸리나」를 설계를 고치지 않고 미리 본다
if typeof(PLAY_XP) == "number" and PLAY_XP ~= 1 then
	local real = Hero.gainXp
	Hero.gainXp = function(hero, amount: number)
		return real(hero, if hero.level >= 10 then amount * PLAY_XP else amount)
	end
	print(("[PLAY] 만약에: Lv.10부터 경험치 x%g"):format(PLAY_XP))
end
local want = PLAY_FULL -- 끝까지 볼 직업들("axion,salamander") — tools/test/run.py가 환경 변수 LUNE_PLAY를 넘겨 준다. 없으면 짧게만 본다
if typeof(want) == "string" and want ~= "" then
	for _, class in string.split(want, ",") do
		local name, mode = string.match(class, "^(%a+)(%d*)$")
		if name and CLASSES.classes[name] then
			-- 이름 뒤에 0을 붙이면("axion0") 대장장이에게 들르지 않는다(떨어진 장비만 낀다)
			local stat = play(name, { job = 2 }, 40 * 3600, mode ~= "0")
			report(stat)
			expect(stat.job >= 2, ("%s: 2차 전직까지 간다(Lv.%d · %s)"):format(class, stat.level, clock(stat.time)))
		end
	end
else
	-- 늘 도는 짧은 검사: 가장 느린 직업(액시온)으로 Lv.8까지 — 막히지 않고, 한 시간 안에, 거의 쓰러지지 않고 간다
	local stat = play("axion", { level = 8 }, 2 * 3600)
	report(stat)
	expect(stat.level >= 8, ("Lv.8까지 간다(지금 Lv.%d · %s)"):format(stat.level, clock(stat.time)))
	expect(stat.stuck == 0, ("막힌 퀘스트가 없다(%d번)"):format(stat.stuck))
	expect(stat.quests >= 4, ("그동안 퀘스트를 넷 넘게 끝낸다(%d개)"):format(stat.quests))
end
