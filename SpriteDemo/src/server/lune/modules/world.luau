-- 「달의 계승자」 서버의 세계 — 사람들이 어느 장면에 있는지, 장면마다의 방(졸개 · 떨어진 것), 싸움의 판정과 보상.
--  셈은 shared/lune/sim(room · hero)이 하고, 여기는 사람(Player)과 패킷을 그 셈에 잇는 일만 한다.
--  서버 시간은 tick이 흘린 시간(World.now)으로 센다 — 테스트가 tick을 직접 불러 똑같이 돌릴 수 있다.
--  캐릭터는 store.luau가 저장한다 — 들어올 때 읽고, 바뀌면 표시해 두었다가 틈틈이, 그리고 나갈 때 쓴다.
--  처음 온 사람은 캐릭터가 없다 — 직업을 고르면(Choose) 생긴다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lune = ReplicatedStorage.shared.lune
local Net = require(lune.net.net)
local G = require(lune.config.game)
local SCENES = require(lune.data["scenes.generated"])
local COMBAT = require(lune.data["combat.generated"])
local Hero = require(lune.sim.hero)
local Room = require(lune.sim.room)
local Bag = require(lune.sim.bag)
local Items = require(lune.sim.items)
local Party = require(lune.sim.party)
local Quests = require(lune.sim.quests)
local Format = require(lune.ui.format)
local CLASSES = require(lune.data["classes.generated"])
local Store = require(script.Parent.store)

local TICK = 1 / 20
local SNAP_EVERY = 2 -- 걸음 몇 번에 한 번 졸개의 모습을 보낸다(초당 10번)
local MOVE_SLACK = 90 -- 한 번의 보고에서 이보다 멀리 가 있으면 믿지 않는다(도트)
local SAVE_EVERY = 60 -- 바뀐 캐릭터를 이 간격(초)으로 저장한다

local World = {}
World.now = 0

local sessions = {} -- [Player] = { player, hero, scene, skill = { id, seg, at }, moved }
local rooms = {} -- [장면 이름] = Room
local pending = {} -- 조금 뒤에 풀 판정들 { at, fn }
local ticks = 0
local acc = 0
local seed = 20261006
local questRng = Random.new(seed + 78) -- 퀘스트의 모으는 물건을 굴린다(기술 판정보다 앞에 있어야 한다)

local byUser = {} -- [사람 번호] = 그 사람의 자리(sessions의 것)
local book = Party.newBook() -- 파티 장부(sim/party.luau)

-- 확인용 가짜 사람인가. 가짜 사람은 표(table)이고, 진짜는 Player다 — 진짜 Player에서 없는 값을 읽으면 오류가 나므로 꼭 이 함수로 묻는다
local bots = {} -- [가짜 사람] = true
local function isBot(player): boolean
	return bots[player] == true
end

-- 보내기는 여기를 거친다. 가짜 사람에게는 보내지 않는다
local function fire(name: string, player, ...)
	if isBot(player) then
		return
	end
	Net.FireClient(name, player, ...)
end

local function roomOf(key: string)
	local room = rooms[key]
	if not room then
		seed += 1
		room = Room.new(key, SCENES.scenes[key], Random.new(seed))
		rooms[key] = room
	end
	return room
end

local function inRoom(key: string)
	local list = {}
	for _, s in sessions do
		if s.hero and s.scene == key then
			table.insert(list, s)
		end
	end
	return list
end

local function toRoom(key: string, name: string, ...)
	for _, s in inRoom(key) do
		fire(name, s.player, ...)
	end
end

-- 그 방 사람들의 이름표를 방 사람들에게 다시 알린다(누가 들고 났을 때 · 레벨이 올랐을 때)
local function roster(key: string)
	local list = {}
	for _, s in inRoom(key) do
		table.insert(list, { id = s.hero.id, name = s.name, class = s.hero.class, level = s.hero.level })
	end
	return list
end
local function sendWho(key: string)
	toRoom(key, "Who", key, roster(key))
end

-- 파티원들에게 파티의 모습을 알린다. ids = 알릴 사람들(파티에서 나간 사람도 넣으면 "파티 없음"을 받는다)
local function sendParty(ids)
	for _, id in ids do
		local s = byUser[id]
		if s and s.hero then
			local party = Party.of(book, id)
			local info = { leader = if party then party.leader else false, members = {} }
			if party then
				for _, m in party.members do
					local ms = byUser[m]
					if ms and ms.hero then
						table.insert(info.members, { id = m, name = ms.name, class = ms.hero.class, level = ms.hero.level, hp = ms.hero.hp, maxHp = ms.hero.maxHp, scene = ms.scene })
					end
				end
			end
			fire("PartyInfo", s.player, info)
		end
	end
end

local function sendSelf(s)
	s.dirty = true
	fire("Self", s.player, Hero.view(s.hero))
end

-- 가방 · 장비 · 창고가 바뀌었다(전투력도 바뀔 수 있어 내 상태도 같이 보낸다)
local function sendBag(s)
	fire("Bag", s.player, Bag.view(s.hero))
	sendSelf(s)
end

local function place(s, key: string, x: number, y: number)
	s.scene = key
	s.hero.x, s.hero.y = x, y
	s.skill = nil
	s.jumped = true -- 다음 자리 보고는 거리와 상관없이 받는다
end

-- 들어온 사람의 자리를 만든다. 저장된 캐릭터가 있으면 되살리고, 없으면 직업을 고를 때까지 비워 둔다.
function World.addPlayer(player)
	if sessions[player] then
		return
	end
	local s = { player = player, hero = nil, scene = SCENES.start, skill = nil, jumped = true, loaded = false, dirty = false, name = Format.safeName(player.DisplayName, player.Name) }
	sessions[player] = s
	byUser[player.UserId] = s
	local data = Store.load(player.UserId)
	if sessions[player] ~= s then
		return -- 읽는 사이에 나갔다
	end
	if data then
		s.hero = Hero.unpack(player.UserId, data)
	end
	if s.hero then
		local scene = SCENES.scenes[s.scene]
		s.hero.x, s.hero.y = scene.spawn.x, scene.spawn.y
		roomOf(s.scene)
	end
	s.loaded = true
end

function World.removePlayer(player)
	local s = sessions[player]
	sessions[player] = nil
	byUser[player.UserId] = nil
	if s and s.hero and s.loaded then
		Store.save(player.UserId, Hero.pack(s.hero))
	end
	-- 파티에서 빠지고, 방 사람들의 이름표에서도 빠진다
	local left = Party.leave(book, player.UserId)
	sendParty(left)
	if s and s.hero then
		sendWho(s.scene)
	end
end

-- 바뀐 캐릭터를 모두 저장한다(틈틈이 · 서버가 닫힐 때)
function World.saveAll(onlyDirty: boolean?)
	for player, s in sessions do
		if s.hero and s.loaded and (s.dirty or not onlyDirty) then
			s.dirty = false
			Store.save(player.UserId, Hero.pack(s.hero))
		end
	end
end

function World.session(player)
	return sessions[player]
end

function World.room(key: string)
	return roomOf(key)
end

-- ---------- 패킷 ----------
local function describe(s)
	local room = roomOf(s.scene):describe(s.hero.id)
	room.who = roster(s.scene)
	return { self = Hero.view(s.hero), bag = Bag.view(s.hero), quests = Quests.view(s.hero.quests), scene = s.scene, x = s.hero.x, y = s.hero.y, room = room, id = s.hero.id, name = s.name }
end

local function onReady(player)
	World.addPlayer(player)
	local s = sessions[player]
	-- 저장된 것을 읽는 중이면 잠깐 기다린다
	local waited = 0
	while s and not s.loaded and waited < 10 do
		task.wait(0.1)
		waited += 0.1
	end
	if not s or not s.loaded then
		return nil
	end
	if not s.hero then
		return { choose = true }
	end
	task.defer(sendWho, s.scene) -- 먼저 와 있던 사람들에게 내가 왔다고 알린다
	sendParty({ player.UserId })
	return describe(s)
end

-- 직업 고르기: 캐릭터가 없는 사람만. 고르면 Lv.1 캐릭터가 생긴다.
local function onChoose(player, class: string)
	local s = sessions[player]
	if not s or not s.loaded or s.hero or not CLASSES.classes[class] then
		return nil
	end
	s.hero = Hero.new(player.UserId, class)
	local scene = SCENES.scenes[SCENES.start]
	place(s, SCENES.start, scene.spawn.x, scene.spawn.y)
	roomOf(s.scene)
	s.dirty = true
	Store.save(player.UserId, Hero.pack(s.hero))
	task.defer(sendWho, s.scene)
	return describe(s)
end

local function onMove(player, x: number, y: number, dir: number)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return
	end
	local scene = SCENES.scenes[s.scene]
	local hero = s.hero
	if x < 0 or x > scene.w * G.TILE or y < -200 or y > scene.h * G.TILE + G.FALL_OUT then
		return
	end
	-- 그 맵의 시작 자리로 온 것은 받는다(맵 아래로 떨어지면 화면이 시작 자리로 돌려놓는다 — 이것까지 막으면 그 뒤로 자리가 영영 어긋난다)
	local atSpawn = math.abs(x - scene.spawn.x) <= MOVE_SLACK and math.abs(y - scene.spawn.y) <= MOVE_SLACK * 2
	if not s.jumped and not atSpawn and (math.abs(x - hero.x) > MOVE_SLACK or math.abs(y - hero.y) > MOVE_SLACK * 2) then
		return -- 순간이동은 믿지 않는다(서버가 아는 자리를 그대로 둔다)
	end
	s.jumped = false
	hero.x, hero.y, hero.dir = x, y, dir
end

local function onTravel(player, to: string)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return nil
	end
	local scene = SCENES.scenes[s.scene]
	for _, p in scene.portals do
		if p.to == to and math.abs(p.x - s.hero.x) <= 28 and math.abs(p.y - s.hero.y) <= 28 then
			local dest = SCENES.scenes[to]
			local x, y = dest.spawn.x, dest.spawn.y
			for _, back in dest.portals do
				if back.to == s.scene then
					x, y = back.x, back.y
				end
			end
			local from = s.scene
			place(s, to, x, y)
			local room = roomOf(to):describe(s.hero.id)
			room.who = roster(to)
			sendWho(from)
			sendWho(to)
			sendParty(Party.members(book, player.UserId)) -- 파티원이 어느 맵에 있는지 바뀌었다
			return { scene = to, x = x, y = y, room = room }
		end
	end
	return nil
end

-- 기술: 구간(seg)마다 한 번씩 온다. 첫 구간은 앞 기술이 끝난 뒤에만, 이어지는 구간은 앞 구간 도중이나 끝난 직후에만 받는다.
local function onSkill(player, id: string, seg: number, x: number, y: number, dir: number)
	local s = sessions[player]
	local def = COMBAT.skills[id]
	if not s or not def or not s.hero or not s.hero.alive or def.who ~= s.hero.class or Hero.skillLevel(s.hero, id) < 1 then
		return
	end
	local segDef = def.segs[seg]
	if not segDef or seg ~= math.floor(seg) then
		return
	end
	local now = World.now
	local last = s.skill
	if seg == 1 or not segDef.next then
		if seg ~= 1 and not (last and last.id == id and last.seg == seg - 1) then
			return
		end
		if seg == 1 and last and now < last.free - 0.1 then
			return -- 앞 기술이 아직 안 끝났다
		end
		if seg == 1 and def.cd > 0 and s.cds and s.cds[id] and now < s.cds[id] then
			return
		end
	else
		-- 한 번 더 눌러 잇는 구간: 바로 앞 구간이어야 하고, 그 구간이 반쯤 지난 뒤부터 끝난 직후까지
		if not (last and last.id == id and last.seg == seg - 1) then
			return
		end
		local prev = def.segs[seg - 1]
		local elapsed = now - last.at
		if elapsed < prev.time * 0.4 or elapsed > prev.time + 0.4 then
			return
		end
	end
	local hero = s.hero
	-- 쓴 자리: 서버가 아는 자리와 크게 다르지 않으면 클라이언트가 말한 자리를 받아 적는다(판정은 맞는 순간의 자리로 한다)
	if math.abs(x - hero.x) <= 40 and math.abs(y - hero.y) <= 60 then
		hero.x, hero.y = x, y
	end
	hero.dir = dir
	-- 구간이 저절로 이어지는 기술(next가 아닌 뒤 구간)은 첫 구간에서 한꺼번에 받는다
	local free = now + segDef.time
	local startAt = 0
	local segs = { seg }
	if seg == 1 then
		for i = 2, #def.segs do
			if def.segs[i].next then
				break
			end
			table.insert(segs, i)
			free += def.segs[i].time
		end
	end
	s.skill = { id = id, seg = segs[#segs], at = now, free = free }
	if def.cd > 0 then
		s.cds = s.cds or {}
		s.cds[id] = now + def.cd
	end
	local key = s.scene
	-- 방의 다른 사람들에게: 이 사람이 이 기술의 이 구간을 쓴다(그 사람들의 화면에서 동작이 나온다)
	for _, other in inRoom(key) do
		if other ~= s then
			fire("Act", other.player, hero.id, id, seg, hero.x, hero.y, dir)
		end
	end
	for _, index in segs do
		for _, hit in def.hits do
			if hit.seg == index then
				table.insert(pending, {
					at = now + startAt + hit.at,
					fn = function()
						local cur = sessions[player]
						if not cur or cur.scene ~= key or not cur.hero.alive then
							return
						end
						-- 맞는 순간의 자리에서 판정한다(걸으면서 쓰는 기술이 있다). 세기는 스킬 레벨을 따른다
						-- 같은 맵의 파티원(레벨 차이 20 안쪽)과 경험치를 나눈다
						local here, heroOf = {}, {}
						for _, o in inRoom(key) do
							if o.hero.alive then
								here[o.hero.id], heroOf[o.hero.id] = o.hero, o.hero
							end
						end
						local mates = {}
						for _, mid in Party.mates(book, cur.hero.id, here) do
							table.insert(mates, heroOf[mid])
						end
						local result = roomOf(key):skillHit(cur.hero, hit, cur.hero.x, cur.hero.y, dir, Hero.scale(cur.hero, id), if #mates > 1 then mates else nil, COMBAT.skills[id].type)
						if #result.hits > 0 then
							toRoom(key, "Hits", player.UserId, result.hits)
						end
						local grew = false
						for _, kill in result.kills do
							for _, gain in kill.gains do
								local gs = byUser[gain.hero]
								if gs then
									-- 퀘스트: 함께 잡은 사람 모두에게 잡은 것으로 쳐 준다
									if #Quests.onKill(gs.hero.quests, kill.kind, key) > 0 then
										gs.dirty = true
										fire("Quests", gs.player, Quests.view(gs.hero.quests))
									end
									-- 모으는 물건은 사람마다 따로 굴려 그 사람의 것으로 땅에 떨어진다(그 사람에게만 보인다) — 주워야 숫자가 오른다
									for n, q in Quests.drops(gs.hero.quests, kill.kind, key, questRng) do
										local d = roomOf(key):addDrop({ kind = "quest", amount = 1, quest = q.quest, step = q.step, name = q.name, icon = q.icon }, kill.x - n * 9, kill.y, gs.hero.id)
										fire("DropAdd", gs.player, Room.dropView(d))
									end
									fire("Gain", gs.player, { xp = gain.xp, ups = gain.ups, level = gain.level })
									if gs ~= cur then
										sendSelf(gs)
									end
									grew = grew or gain.ups > 0
								end
							end
							if kill.drop then
								toRoom(key, "DropAdd", Room.dropView(kill.drop))
							end
							for _, d in kill.loot do
								toRoom(key, "DropAdd", Room.dropView(d))
							end
						end
						if #result.kills > 0 then
							sendSelf(cur)
						end
						if grew then
							sendWho(key) -- 레벨이 오른 사람의 이름표
						end
					end,
				})
			end
		end
		startAt += def.segs[index].time
	end
end

local function onPickup(player, dropId: number)
	local s = sessions[player]
	if not s or not s.hero then
		return
	end
	local drop, why = roomOf(s.scene):pickup(s.hero, dropId)
	if drop then
		toRoom(s.scene, "DropGone", drop.id, player.UserId, drop.amount)
		if drop.kind == "quest" then
			-- 퀘스트의 물건: 주운 만큼 그 퀘스트의 숫자가 오른다
			if Quests.onLoot(s.hero.quests, drop.quest, drop.step) then
				s.dirty = true
				fire("Quests", player, Quests.view(s.hero.quests))
			end
		elseif drop.kind == "money" then
			sendSelf(s)
		else
			sendBag(s)
		end
	elseif why == "가방이 가득 찼다" then
		fire("ItemDone", player, { action = "pickup", ok = false, why = why })
	end
end

-- 그 주민 앞에 서 있는가(상점 · 강화 · 창고는 주민 앞에서만)
local NPC_REACH = 64
local function nearNpc(s, kind: string): boolean
	for _, n in SCENES.scenes[s.scene].npcs or {} do
		if Items.data.NPCDO[n.id] == kind and math.abs(n.x - s.hero.x) <= NPC_REACH and math.abs(n.y - s.hero.y) <= 40 then
			return true
		end
	end
	return false
end

-- 물건을 다룬다. 까닭 없이 안 되는 일은 없다 — 안 되면 까닭을 돌려보낸다
local OPEN = Items.data.OPEN
local itemRng = Random.new(seed + 77)
local function onItem(player, action: string, a: any, b: any)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return
	end
	local h = s.hero
	local ok, why, result = nil, nil, nil
	if action == "equip" then
		ok, why = Bag.equip(h, a)
	elseif action == "unequip" then
		ok, why = Bag.unequip(h, a)
	elseif action == "dismantle" then
		result, why = Bag.dismantle(h, a)
		ok = result ~= nil
	elseif action == "grow" then
		ok, why = Bag.grow(h)
	elseif action == "buy" then
		local stock = if typeof(a) == "string" then Items.stock(a) else nil
		if not stock then
			why = "없는 물건이다"
		elseif not nearNpc(s, if stock.npc == "merchant" then "shop" else "smith") then
			why = "파는 사람 앞이 아니다"
		else
			ok, why = Bag.buy(h, a, b)
		end
	elseif action == "enhance" or action == "transfer" or action == "restore" then
		if h.level < OPEN.forge then
			why = ("Lv.%d부터 한다"):format(OPEN.forge)
		elseif not nearNpc(s, "smith") then
			why = "대장장이 앞이 아니다"
		elseif action == "enhance" then
			result, why = Bag.enhance(h, a, itemRng, b == true)
			ok = result ~= nil
		elseif action == "transfer" then
			ok, why = Bag.transfer(h, a, b)
		else
			ok, why = Bag.restore(h, a, b)
		end
	elseif action == "storeIn" or action == "storeOut" then
		if h.level < OPEN.store then
			why = ("Lv.%d부터 쓴다"):format(OPEN.store)
		elseif not nearNpc(s, "store") then
			why = "창고지기 앞이 아니다"
		elseif action == "storeIn" then
			ok, why = Bag.storeIn(h, a)
		else
			ok, why = Bag.storeOut(h, a)
		end
	else
		why = "모르는 일이다"
	end
	fire("ItemDone", player, { action = action, ok = ok == true, why = why, result = result })
	if ok then
		sendBag(s)
	end
end

local function onPotion(player)
	local s = sessions[player]
	if s and s.hero and Hero.drink(s.hero) then
		sendSelf(s)
	end
end

local function onStatAdd(player, stat: string, n: number)
	local s = sessions[player]
	if s and s.hero and Hero.addStat(s.hero, stat, n) then
		sendSelf(s)
	end
end

local function onKeys(player, map)
	local s = sessions[player]
	if s and s.hero and Hero.setKeys(s.hero, map) then
		s.dirty = true
	end
end

-- 퀵슬롯을 바꿨다(칸들 전체를 보낸다 — 꼴과 놓아도 되는 스킬인지는 Hero.setSlots가 본다). 서버가 가진 칸들을 돌려준다 — 말이 안 되는 것을 보냈으면 예전 것이 돌아가 화면이 되돌아간다
local function onSlots(player, list)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	if Hero.setSlots(s.hero, list) then
		s.dirty = true
	end
	return s.hero.slots
end

-- 스마트폰의 단추 배치를 바꿨다(PC의 퀵슬롯과 따로 — 같은 식으로 본다)
local function onTouchSlots(player, list)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	if Hero.setSlots(s.hero, list, true) then
		s.dirty = true
	end
	return s.hero.tslots
end

local function onStatAuto(player)
	local s = sessions[player]
	if s and s.hero and Hero.autoStat(s.hero) > 0 then
		sendSelf(s)
	end
end

local function onSkillUp(player, id: string)
	local s = sessions[player]
	if s and s.hero and Hero.skillUp(s.hero, id) then
		sendSelf(s)
	end
end

local function onSkillAuto(player)
	local s = sessions[player]
	if s and s.hero and Hero.autoSkill(s.hero) > 0 then
		sendSelf(s)
	end
end

-- 그 주민 앞에 서 있는가(퀘스트를 받고 돌려줄 때)
local function nearNpcId(s, npcId: any): boolean
	for _, n in SCENES.scenes[s.scene].npcs or {} do
		if n.id == npcId and math.abs(n.x - s.hero.x) <= NPC_REACH and math.abs(n.y - s.hero.y) <= 40 then
			return true
		end
	end
	return false
end

-- 퀘스트: 받기 · 돌려주기 · 그만두기
local function onQuest(player, action: string, id: any)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return
	end
	local h = s.hero
	local def = Quests.def(id)
	local ok, why, done = nil, nil, nil
	if not def then
		why = "없는 퀘스트다"
	elseif action == "accept" then
		if not nearNpcId(s, def.giver) then
			why = "퀘스트를 주는 사람 앞이 아니다"
		else
			ok, why = Quests.accept(h.quests, h.level, id)
		end
	elseif action == "complete" then
		if not nearNpcId(s, def.endNpc) then
			why = "돌려줄 사람 앞이 아니다"
		else
			local reward, ups = Hero.questDone(h, id)
			if reward then
				ok, done = true, id
				fire("Gain", player, { xp = reward.xp, ups = ups, level = h.level, quest = def.name })
				if ups > 0 then
					sendWho(s.scene)
				end
			else
				why = ups
			end
		end
	elseif action == "drop" then
		ok, why = Quests.drop(h.quests, id)
	else
		why = "모르는 일이다"
	end
	if ok then
		s.dirty = true
		fire("Quests", player, Quests.view(h.quests), done)
		sendSelf(s)
	else
		fire("ItemDone", player, { action = "quest", ok = false, why = why })
	end
end

-- 파티: 초대 · 받기 · 거절 · 나가기. Lv.10부터(공방 「기본 · UI」 탭의 UNLOCK). 초대는 같은 맵에 있는 사람에게만.
local PARTY_FROM = 10
local function partyNote(player, why: string)
	fire("ItemDone", player, { action = "party", ok = false, why = why })
end
local function onParty(player, action: string, target: any)
	local s = sessions[player]
	if not s or not s.hero then
		return
	end
	local me = player.UserId
	if action == "invite" then
		local other = if typeof(target) == "number" then byUser[target] else nil
		if s.hero.level < PARTY_FROM then
			return partyNote(player, ("파티는 Lv.%d부터 맺는다"):format(PARTY_FROM))
		elseif not other or not other.hero or other.scene ~= s.scene then
			return partyNote(player, "같은 맵에 있는 사람만 초대한다")
		elseif other.hero.level < PARTY_FROM then
			return partyNote(player, ("상대가 Lv.%d이 안 됐다"):format(PARTY_FROM))
		end
		local ok, why = Party.invite(book, me, target, World.now)
		if not ok then
			return partyNote(player, why)
		end
		fire("PartyAsk", other.player, { from = me, name = s.name })
		if isBot(other.player) then
			other.botAccept = World.now + 1 -- 확인용 가짜 사람은 조금 뒤에 받는다
		end
	elseif action == "accept" then
		local party, why = Party.accept(book, me, World.now)
		fire("PartyAsk", player, { from = false })
		if not party then
			return partyNote(player, why)
		end
		sendParty(party.members)
	elseif action == "decline" then
		local from = Party.decline(book, me)
		fire("PartyAsk", player, { from = false })
		local fs = from and byUser[from]
		if fs then
			partyNote(fs.player, ("%s — 초대를 거절했다"):format(s.name))
		end
	elseif action == "leave" then
		local left = Party.leave(book, me)
		sendParty(left)
		sendParty({ me })
	end
end

-- 같은 파티인가 · 어느 맵에 있나(채팅이 누구에게 갈지 정할 때 쓴다 — server/lune/modules/chat.luau)
function World.sameParty(a: number, b: number): boolean
	return Party.same(book, a, b)
end
function World.sceneOf(userId: number): string?
	local s = byUser[userId]
	return if s and s.hero then s.scene else nil
end

-- 확인용 가짜 사람(Studio에서만): 다른 사람이 어떻게 보이는지 · 파티가 되는지를 혼자서 본다. 제자리에서 오가며 사냥기를 쓴다
local botN = 0
local onSkill2 = nil :: any
local function addBot(scene: string, x: number, y: number, class: string)
	botN += 1
	local player = { UserId = -botN, Name = "Bot" .. botN, DisplayName = "달그림자" .. botN }
	bots[player] = true
	local s = { player = player, hero = Hero.new(player.UserId, class), scene = scene, skill = nil, jumped = true, loaded = true, dirty = false, name = Format.safeName(player.DisplayName, player.Name), botHome = x, botDir = 1, botSkill = World.now + 2 }
	Hero.gainXp(s.hero, 20000) -- Lv.10을 넘겨 파티를 맺을 수 있게
	Hero.autoStat(s.hero)
	s.hero.x, s.hero.y = x, y
	sessions[player] = s
	byUser[player.UserId] = s
	sendWho(scene)
	return s
end
local function stepBots(dt: number)
	for player, s in sessions do
		if isBot(player) and s.hero and s.hero.alive then
			local h = s.hero
			if not s.skill or World.now >= s.skill.free then
				h.x += s.botDir * 36 * dt
				h.dir = s.botDir
				if math.abs(h.x - s.botHome) > 40 then
					s.botDir = if h.x > s.botHome then -1 else 1
				end
			end
			if World.now >= s.botSkill then
				s.botSkill = World.now + 2.5
				for id, def in COMBAT.skills do
					if def.who == h.class and def.type == "mob" then
						onSkill2(player, id, 1, h.x, h.y, h.dir)
					end
				end
			end
			if s.botAccept and World.now >= s.botAccept then
				s.botAccept = nil
				local party = Party.accept(book, player.UserId, World.now)
				if party then
					sendParty(party.members)
				end
			end
		end
	end
end

-- 확인용 명령 — Studio에서만 듣는다(실제 서버에서는 아무 일도 하지 않는다)
local function inStudio(): boolean
	local ok, result = pcall(function()
		return RunService:IsStudio()
	end)
	return ok and result == true
end

local function onDebug(player, what: string, n: number)
	local s = sessions[player]
	if not inStudio() or not s or not s.hero then
		return
	end
	local hero = s.hero
	if what == "xp" then
		local ups = Hero.gainXp(hero, math.max(0, n))
		fire("Gain", player, { xp = n, ups = ups, level = hero.level })
	elseif what == "money" then
		hero.money += math.max(0, math.floor(n))
	elseif what == "hp" then
		hero.hp = math.clamp(math.floor(n), 1, hero.maxHp)
	elseif what == "dust" then
		hero.dust += math.max(0, math.floor(n))
		fire("Bag", player, Bag.view(hero))
	elseif what == "bot" then
		-- 확인용: 내 옆에 가짜 사람을 세운다(n = 1 리븐 · 2 리퍼 · 3 무니 · 4 살라맨더 · 그 밖 액시온)
		local class = ({ "riven", "reaper", "mooni", "salamander" })[math.floor(n)] or "axion"
		addBot(s.scene, hero.x + 50, hero.y, class)
		return
	elseif what == "botInvite" then
		-- 확인용: 가짜 사람이 나를 파티에 초대한다
		for other, os in sessions do
			if isBot(other) and os.scene == s.scene and Party.invite(book, other.UserId, player.UserId, World.now) then
				fire("PartyAsk", player, { from = other.UserId, name = os.name })
				break
			end
		end
		return
	elseif what == "drop" then
		-- 확인용: 발 앞에 그 단계의 장비 하나와 달가루를 떨어뜨린다
		local room = roomOf(s.scene)
		local stage = math.max(1, math.floor(n))
		local gear = room:addDrop({ kind = "gear", item = Items.make("weapon", stage, 5, hero.class), amount = 1 }, hero.x + 24, hero.y, hero.id)
		local dust = room:addDrop({ kind = "dust", amount = 7 }, hero.x + 40, hero.y, hero.id)
		toRoom(s.scene, "DropAdd", Room.dropView(gear))
		toRoom(s.scene, "DropAdd", Room.dropView(dust))
		local coin = room:addDrop({ kind = "money", amount = 12 }, hero.x + 58, hero.y, hero.id) -- 달돈의 그림도 본다
		toRoom(s.scene, "DropAdd", Room.dropView(coin))
	elseif what == "qdrop" then
		-- 확인용: 발 앞에 퀘스트의 물건들을 하나씩 떨어뜨린다(그림과 줍기를 본다 — 받지 않은 퀘스트의 것은 주워도 숫자가 오르지 않는다)
		local room = roomOf(s.scene)
		local i = 0
		for _, def in Quests.list do
			for k, step in def.steps do
				if step.type == "gather" then
					i += 1
					local d = room:addDrop({ kind = "quest", amount = 1, quest = def.id, step = k, name = step.name, icon = step.icon }, hero.x + 10 + i * 16, hero.y, hero.id)
					fire("DropAdd", player, Room.dropView(d))
				end
			end
		end
	elseif what == "gear" then
		-- 확인용: 그 단계의 장비 다섯 부위를 가방에 넣는다(성능은 차례로)
		for i, slot in Items.data.GEAR do
			Bag.add(hero, Items.make(slot, math.max(1, math.floor(n)), ((i - 1) % #Items.data.QUALITY) + 1, hero.class))
		end
		fire("Bag", player, Bag.view(hero))
	elseif what == "reset" then
		s.hero = nil
		s.dirty = false
		Store.erase(player.UserId)
		return
	end
	sendSelf(s)
end

-- ---------- 시간 ----------
function World.tick(dt: number)
	World.now += dt
	ticks += 1
	-- 때가 된 판정
	for i = #pending, 1, -1 do
		if pending[i].at <= World.now then
			local job = table.remove(pending, i)
			job.fn()
		end
	end
	stepBots(dt)
	-- 사람: 무적 · 벌칙 · 물약 대기 시간, 쓰러졌으면 마을에서 일어난다
	for _, s in sessions do
		if s.hero and Hero.tick(s.hero, dt) then
			Hero.revive(s.hero)
			local scene = SCENES.scenes[SCENES.start]
			local from = s.scene
			place(s, SCENES.start, scene.spawn.x, scene.spawn.y)
			local room = roomOf(s.scene):describe(s.hero.id)
			room.who = roster(s.scene)
			fire("Revive", s.player, { scene = s.scene, x = s.hero.x, y = s.hero.y, room = room })
			sendSelf(s)
			sendWho(from)
			sendWho(s.scene)
			sendParty(Party.members(book, s.hero.id))
		end
	end
	-- 파티원의 체력과 자리(어느 맵)를 1초에 한 번 알린다
	if ticks % 20 == 0 then
		for _, party in book.parties do
			sendParty(party.members)
		end
	end
	-- 방: 사람이 있는 방만 돌린다
	for key, room in rooms do
		local here = inRoom(key)
		if #here > 0 then
			local heroes = {}
			local byId = {}
			for _, s in here do
				heroes[s.hero.id] = s.hero
				byId[s.hero.id] = s
			end
			for _, e in room:step(heroes, dt) do
				if e.type == "hurt" then
					local s = byId[e.hero]
					if s then
						fire("Hurt", s.player, { dmg = e.dmg, hp = e.hp, from = e.from, dead = e.dead })
						sendSelf(s)
					end
				elseif e.type == "shot" then
					toRoom(key, "Shot", { id = e.id, x = e.x, y = e.y, dir = e.dir, speed = e.speed, range = e.range })
				elseif e.type == "shotEnd" then
					toRoom(key, "ShotEnd", e.id)
				elseif e.type == "burst" then
					toRoom(key, "Burst", { mob = e.mob, x = e.x, y = e.y })
				elseif e.type == "dropGone" then
					toRoom(key, "DropGone", e.id, nil, 0)
				end
			end
			if ticks % SNAP_EVERY == 0 and #room.mobs > 0 then
				toRoom(key, "Snap", key, room:snapshot())
			end
			-- 사람들의 자리: 둘 이상 있을 때만 보낸다
			if ticks % SNAP_EVERY == 0 and #here > 1 then
				local list = {}
				for i, s in here do
					list[i] = { s.hero.id, math.floor(s.hero.x + 0.5), math.floor(s.hero.y + 0.5), s.hero.dir, s.hero.alive }
				end
				toRoom(key, "Heroes", key, list)
			end
		end
	end
end

function World.start()
	Net.OnServer("Ready", onReady)
	Net.OnServer("Move", onMove)
	Net.OnServer("Travel", onTravel)
	Net.OnServer("Skill", onSkill)
	Net.OnServer("Pickup", onPickup)
	Net.OnServer("Potion", onPotion)
	Net.OnServer("Choose", onChoose)
	Net.OnServer("Debug", onDebug)
	Net.OnServer("Keys", onKeys)
	Net.OnServer("Item", onItem)
	Net.OnServer("Party", onParty)
	Net.OnServer("Quest", onQuest)
	onSkill2 = onSkill
	Net.OnServer("Slots", onSlots)
	Net.OnServer("TouchSlots", onTouchSlots)
	Net.OnServer("StatAdd", onStatAdd)
	Net.OnServer("StatAuto", onStatAuto)
	Net.OnServer("SkillUp", onSkillUp)
	Net.OnServer("SkillAuto", onSkillAuto)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(World.addPlayer, player)
	end)
	Players.PlayerRemoving:Connect(World.removePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(World.addPlayer, player)
	end
	local saveT = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = math.min(acc + dt, TICK * 5)
		while acc >= TICK do
			acc -= TICK
			World.tick(TICK)
		end
		saveT += dt
		if saveT >= SAVE_EVERY then
			saveT = 0
			task.spawn(World.saveAll, true)
		end
	end)
end

function World.stop()
	World.saveAll(false)
end

return World
