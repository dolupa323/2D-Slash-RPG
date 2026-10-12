-- 「달의 계승자」 서버의 세계 — 사람들이 어느 장면에 있는지, 장면마다의 방(졸개 · 떨어진 것), 싸움의 판정과 보상.
--  셈은 shared/lune/sim(room · hero)이 하고, 여기는 사람(Player)과 패킷을 그 셈에 잇는 일만 한다.
--  서버 시간은 tick이 흘린 시간(World.now)으로 센다 — 테스트가 tick을 직접 불러 똑같이 돌릴 수 있다.
--  저장은 계정 하나에 통째로 한다(store.luau · sim/account.luau): 그 사람의 캐릭터들 + 캐릭터들이 같이 쓰는 창고. 들어올 때 읽고, 바뀌면 표시해 두었다가 틈틈이, 그리고 나갈 때 쓴다.
--  들어온 사람은 먼저 캐릭터 고르기 화면에 있다(Ready가 계정의 캐릭터들을 준다) — 만들기 · 삭제 · 들어가기는 Chars 패킷. 들어가야 세계에 캐릭터가 선다.
--  캐릭터의 이름은 만들 때 짓는다(Roblox의 이름을 쓰지 않는다 — 사용자 2026-10-10). 겹치는 이름은 이름 장부(store.luau)가 막고, 글 거르기(TextService)를 거친다.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lune = ReplicatedStorage.shared.lune
local Net = require(lune.net.net)
local G = require(lune.config.game)
local N = require(lune.config.numbers)
local SCENES = require(lune.data["scenes.generated"])
local COMBAT = require(lune.data["combat.generated"])
local Hero = require(lune.sim.hero)
local Account = require(lune.sim.account)
local Rank = require(lune.sim.rank) -- 명예의 전당(순위판 셋)
local Room = require(lune.sim.room)
local Bag = require(lune.sim.bag)
local Items = require(lune.sim.items)
local Party = require(lune.sim.party)
local Quests = require(lune.sim.quests)
local Daily = require(lune.sim.daily) -- 일일 의뢰(마을의 게시판)
local Kit = require(lune.sim.kit)
local Buffs = require(lune.sim.buffs)
local Passives = require(lune.sim.passives) -- 2~4차의 패시브(충격파 · 넘치는 힘 · 꺼지지 않는 불은 여기서 때를 본다)
local CLASSES = require(lune.data["classes.generated"])
local Store = require(script.Parent.store)
local Admin = require(script.Parent.admin) -- 누가 관리자인가(서버에만 있다)

local TICK = 1 / 20
local SNAP_EVERY = 2 -- 걸음 몇 번에 한 번 졸개의 모습을 보낸다(초당 10번)
local MOVE_SLACK = 90 -- 한 번의 보고에서 이보다 멀리 가 있으면 믿지 않는다(도트)
-- 장면을 옮긴 뒤 화면이 열릴 때까지(화면은 막을 치고 새 장면의 그림을 불러온다 — client/lune/curtain.luau):
--  LOAD_GUARD = 그동안 피해를 받지 않는 가장 긴 시간(초). 화면이 열려 첫 자리 보고나 첫 기술이 오면 거기서부터 보통의 들어선 뒤 보호(RULES.arrive)로 바뀐다
--  LOAD_STALE = 서버가 먼저 옮긴 뒤(마을로 돌아가기 · 관리 이동) 이 시간(초) 안에 온, 옮겨 놓은 자리에서 먼 자리 보고는 옮겨지기 전에 떠난 늦은 보고로 보고 받지 않는다(옛 장면의 자리를 새 장면의 자리로 믿지 않는다)
local LOAD_GUARD, LOAD_STALE = 12, 2
local WARP_SLACK, WARP_TIME = 280, 1.5 -- 2~4차의 스킬을 쓴 직후(초)에는 이만큼(도트) 멀리 간 자리도 받는다 — 순간이동하는 스킬(연막 순보 · 급습 · 연쇄 순보 …)과 길게 내달리는 스킬
local SAVE_EVERY = 60 -- 바뀐 캐릭터를 이 간격(초)으로 저장한다
local STOP_WAIT = 20 -- 서버가 닫힐 때 쓰고 있는 저장을 기다리는 시간의 위(초 — 로블록스가 닫히는 서버에 주는 30초 안)
-- 같은 계정이 다른 서버에서 하는 중일 때(modules/store.luau의 잠금): 이만큼 다시 물어 보고(서버를 옮겨 올 때 앞 서버가 저장을 끝내고 잠금을 푼다) 끝내 안 풀리면 내보낸다
local LOCK_TRIES, LOCK_WAIT = 6, 1.5
local LOCK_KICK = "이 계정은 다른 서버에서 하는 중입니다. 잠시 뒤에 다시 들어와 주세요."
local function holdAccount(userId: number): boolean
	return Store.lock == nil or Store.lock(userId) == true
end
local function kick(player, text: string)
	pcall(function()
		player:Kick(text)
	end)
end

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

-- 내 상태(화면에 보내는 것): 캐릭터의 모습에 걸린 버프 · 다시 쓰기까지 남은 시간 · 공격 속도의 배수를 얹는다(서버의 시간으로 셈한다)
local function selfView(s)
	local view = Hero.view(s.hero)
	view.buffs = Buffs.view(s.hero, World.now)
	view.haste = Buffs.haste(s.hero)
	-- 관리자에게만: 관리 창을 여는 단추가 보이고(화면), 지금 켜 둔 시험용 값들을 안다. 관리자가 아니면 이 칸들이 아예 없다
	if Admin.is(s.player) then
		view.admin = { xp = s.hero.xpBoost or 1, dmg = s.hero.dmgBoost or 1, god = s.hero.god == true }
	end
	return view
end
local function sendSelf(s)
	s.dirty = true
	fire("Self", s.player, selfView(s))
end
-- 방의 사람들에게: 이 사람에게 걸린 버프가 바뀌었다(그 사람의 몸에 버프의 모습이 보인다)
local function sendBuffs(s)
	local list = Buffs.view(s.hero, World.now).list
	for _, other in inRoom(s.scene) do
		if other ~= s then
			fire("Buffs", other.player, s.hero.id, list)
		end
	end
end

-- 가방 · 장비 · 창고가 바뀌었다(전투력도 바뀔 수 있어 내 상태도 같이 보낸다).
--  모으는 퀘스트의 숫자는 가방에 든 수다 — 가방이 바뀔 때마다 맞추고, 달라졌으면 퀘스트도 알린다(주웠다 · 버렸다 · 돌려줬다)
local function sendBag(s)
	if Hero.syncQuests(s.hero) then
		fire("Quests", s.player, Quests.view(s.hero.quests))
	end
	fire("Bag", s.player, Bag.view(s.hero))
	sendSelf(s)
end

--  pushed = 서버가 먼저 옮겼다(화면은 아직 모른다 — 마을로 돌아가기 · 관리 이동 · 확인용 명령): 화면이 그것을 알기 전에 보낸 옛 자리의 보고가 뒤따라 올 수 있다.
--   문(Travel)은 화면이 멈춰 서서 서버에 묻는 것이라 그런 보고가 없다
local function place(s, key: string, x: number, y: number, pushed: boolean?)
	s.scene = key
	s.hero.x, s.hero.y = x, y
	s.skill = nil
	Hero.arrive(s.hero) -- 들어선 뒤 잠깐은 피해를 받지 않는다
	s.jumped = true -- 다음 자리 보고는 거리와 상관없이 받는다
	-- 화면은 이제 막을 치고 새 장면의 그림을 불러온다: 화면이 열릴 때까지(첫 자리 보고 · 첫 기술 — arrived) 피해를 받지 않는다
	-- 마을 · 작은 마을에 들렀다: 쓰러졌을 때 돌아오는 곳이 된다(빠른 이동은 없다 — 걸어서 다닌다)
	if SCENES.homes[key] and s.hero.home ~= key then
		s.hero.home = key
		s.dirty = true
	end
	s.loading = World.now
	s.stale = if pushed then World.now else nil
	s.hero.invuln = math.max(s.hero.invuln, LOAD_GUARD)
end

-- 옮긴 뒤 화면이 열렸다(첫 자리 보고나 첫 기술이 왔다): 여기서부터 보통의 들어선 뒤 보호를 센다
local function arrived(s)
	if s.loading then
		s.loading = nil
		s.hero.invuln = COMBAT.rules.arrive
	end
end

-- 확인용 임시 캐릭터(Studio에서만): Workspace의 속성 LuneGuest = 직업 이름(axion · riven · reaper · mooni · salamander)을 적고 Play를 누르면
--  저장하지 않는 임시 캐릭터로 들어온다 — Lv.20쯤 · 1차 스킬을 모두 마스터(사출기 · 장치 · 패시브를 직업마다 바로 본다).
--  내 캐릭터의 저장은 읽지도 쓰지도 지우지도 않는다: 속성을 지우고 다시 Play를 누르면 내 캐릭터 그대로다. 실제 서버에서는 아무 일도 하지 않는다.
--  "new"를 적으면 처음 온 사람처럼 로딩 화면 · 캐릭터 만들기부터 Lv.1로 시작한다(게임의 첫 5분을 볼 때 — 2026-10-10).
--  "select"를 적으면 캐릭터가 셋 있는 임시 계정으로 캐릭터 고르기 화면부터 본다(삭제 · 이름 짓기 · 캐릭터를 바꿔 창고를 같이 쓰는지).
--  레벨을 같이 적으면("riven:120") 그 레벨로 들어온다 — 그 레벨까지 열린 차수의 스킬을 모두 마스터한다(2~4차를 본다). 안 적으면 Lv.22쯤(1차).
function World.guest(): (string?, number?, string?)
	local ok, value = pcall(function()
		return RunService:IsStudio() and workspace:GetAttribute("LuneGuest")
	end)
	if not ok or typeof(value) ~= "string" then
		return nil, nil, nil
	end
	if value == "new" or value == "select" then
		-- LuneGuest = "new": 처음 온 사람(아래 addPlayer) — 빈 계정으로 로딩 화면 · 캐릭터 만들기부터 Lv.1로 시작한다. 저장을 읽지도 쓰지도 않는다
		-- LuneGuest = "select": 캐릭터가 셋 있는 임시 계정(그 가운데 하나는 이름이 없다) — 캐릭터 고르기 · 삭제 · 이름 짓기 · 같이 쓰는 창고를 본다
		return value, nil, nil
	end
	-- "직업" · "직업:레벨" · "직업:레벨:cast"(2~4차의 쓰는 스킬을 퀵슬롯에 차례로 놓는다 — Ctrl · Q · A · W · S · E · D · R · F · 1 · 2)
	local class, level, mode = string.match(value, "^(%a+):?(%d*):?(%a*)$")
	if not class or CLASSES.classes[class] == nil then
		return nil, nil, nil
	end
	return class, tonumber(level), mode
end

local function guestHero(userId: number, class: string, level: number?, mode: string?)
	local h = Hero.new(userId, class)
	if level then
		while h.level < math.clamp(level, 1, N.MAX_LEVEL) do
			Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
		end
	else
		Hero.gainXp(h, 60000)
	end
	Hero.autoStat(h)
	-- 확인용 캐릭터는 그 레벨의 차수까지 전직한 것으로 친다(2~4차를 바로 본다). 전직 퀘스트를 보려면 LuneGuest = "new"로 만들어 Debug로 레벨을 올린다
	Hero.advanceAll(h)
	h.quests[Quests.FIRST.quest] = { done = true, c = {} } -- 첫 퀘스트(사제에게 기술을 배운다)도 끝낸 것으로
	for _, tier in CLASSES.classes[class].tiers do
		if tier.job <= h.job then
			for _, sk in tier.skills do
				if Hero.ready(sk.id) then -- 게임에 들어와 있는 스킬만(아직 없는 것은 진짜 캐릭터도 못 찍는다)
					h.skills[sk.id] = sk.max
				end
			end
		end
	end
	-- 사출기는 퀵슬롯의 윗줄 첫 칸(E)과 스마트폰의 그 단추에 놓아 둔다(바로 켜 본다)
	local toggle = Kit.data[class].toggle.id
	h.slots[7], h.tslots[7] = toggle, toggle
	-- 배운 설치 · 소환은 아랫줄의 빈 칸(W · S)에
	local free = 5
	for _, tier in CLASSES.classes[class].tiers do
		for _, sk in tier.skills do
			local placed = COMBAT.placed[sk.id]
			if free <= 6 and placed and not Buffs.instant(sk.id) and (h.skills[sk.id] or 0) > 0 then -- 바로 걸리는 버프이기도 한 것(작은 태양)은 버프 칸에 간다
				h.slots[free], h.tslots[free] = sk.id, sk.id
				free += 1
			end
		end
	end
	-- 배운 버프는 그 옆 칸들(D · R · F · 1 · 2)에 차수 차례로 놓아 둔다
	local at = 8
	for _, tier in CLASSES.classes[class].tiers do
		for _, sk in tier.skills do
			if at <= 12 and Buffs.instant(sk.id) and Buffs.learned(h, sk.id) then
				h.slots[at], h.tslots[at] = sk.id, sk.id
				at += 1
			end
		end
	end
	-- 2~4차의 쓰는 스킬을 차수 차례로 칸에 놓는다(확인용 — 물약 · 1차 기술의 칸을 덮는다. 대쉬(Shift)는 둔다)
	if mode == "cast" then
		local order, at = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12 }, 1
		for _, i in order do
			h.slots[i], h.tslots[i] = false, false
		end
		for _, tier in CLASSES.classes[class].tiers do
			for _, sk in tier.skills do
				if COMBAT.cast[sk.id] and (h.skills[sk.id] or 0) > 0 and order[at] then
					h.slots[order[at]], h.tslots[order[at]] = sk.id, sk.id
					at += 1
				end
			end
		end
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	return h
end

-- 지금 하고 있는 캐릭터를 계정의 표에 적는다(창고는 캐릭터가 아니라 계정에 — 같은 계정의 다른 캐릭터가 꺼낼 수 있다)
local function commit(s)
	if not s.hero or not s.acct or not s.cid then
		return
	end
	local c = Account.find(s.acct, s.cid)
	if c then
		local data = Hero.pack(s.hero)
		s.acct.store = data.bag.store
		data.bag.store = nil
		c.hero = data
	end
end

-- 명예의 전당: 지금 하는 캐릭터의 레벨 · 전투력을 순위판에 올린다(달라졌을 때만). 임시 계정의 것은 이 서버의 메모리에만 둔다(저장소에 쓰지 않는다)
local function pushRank(s)
	if not s.hero or not s.acct or not s.cid or s.name == "" then
		return
	end
	local h = s.hero
	local key = Rank.charKey(s.player.UserId, s.cid)
	local sent = s.rankSent or {}
	s.rankSent = sent
	local level, power = Rank.levelScore(h.level, h.xp, Hero.xpNeed(h)), Hero.power(h)
	if sent.key ~= key or sent.name ~= s.name then
		Store.rankInfoSet(key, { name = s.name, class = h.class }, s.guest == true)
		sent.key, sent.name, sent.level, sent.power = key, s.name, nil, nil
	end
	if sent.level ~= level then
		sent.level = level
		Store.rankSet("level", key, level, s.guest == true)
	end
	if sent.power ~= power then
		sent.power = power
		Store.rankSet("power", key, power, s.guest == true)
	end
end

-- 계정을 저장한다. 확인용 임시 계정은 계정의 표에만 적고(캐릭터를 바꿔 들어가도 창고 · 레벨이 이어지게) 저장소에는 쓰지 않는다
--  차례: 계정을 먼저 쓰고 순위판은 그 뒤에 쓴다(2026-10-12 — 그 앞에는 순위판(쓸 때마다 기다린다)을 먼저 써서, 서버가 닫히는 중이면 정작 계정이 마지막에 밀려 쓰이지 못할 수 있었다)
--  saving = 지금 저장소에 쓰고 있는 것의 수: 서버가 닫힐 때 World.stop이 이것이 0이 될 때까지 기다린다(나가는 사람의 저장이 끝나기 전에 서버가 닫히지 않게)
local saving = 0
local function saveAccount(s)
	if not s.acct or not s.loaded then
		return
	end
	commit(s)
	if s.guest then
		pushRank(s)
		return
	end
	s.dirty, s.soon = false, nil
	saving += 1
	local ok, err = pcall(Store.saveAccount, s.player.UserId, Account.pack(s.acct))
	if not ok then
		warn("[lune] 저장하다 오류: " .. tostring(err))
	end
	pcall(pushRank, s)
	saving -= 1
end

-- 곧 저장한다(키 설정 · 퀵슬롯처럼 바꾸자마자 나가기 쉬운 것): SAVE_SOON초 뒤에 — 그 사이 또 바꾸면 그때부터 다시 센다(연달아 바꾸는 동안에는 한 번만 쓴다)
--  사용자 2026-10-12: "지금 키세팅을하고 다시접속하면 키세팅이 초기화됩니다." — 바꾼 것은 60초마다 도는 저장을 기다렸고, 그 전에 나가면 나갈 때의 저장 하나에만 걸려 있었다
local SAVE_SOON = 4
local function saveSoon(s)
	s.dirty = true
	s.soon = os.clock() + SAVE_SOON
end

-- 이름표(다른 사람의 화면 — 채팅의 이름)에 쓰이게 사람에게 적어 둔다
local function markName(s)
	if not isBot(s.player) then
		s.player:SetAttribute("LuneName", if s.hero then s.name else nil)
	end
end

-- 들어온 사람의 자리를 만든다. 계정을 읽어 둔다 — 캐릭터는 고르기 화면에서 들어갈 때 선다(onChars의 enter).
--  계정이 없는데 예전 저장(계정이 생기기 전의 캐릭터 하나)이 있으면 그 캐릭터를 첫 캐릭터로 옮긴다(이름은 비어 있다 — 들어가기 전에 짓는다). 예전 저장은 그대로 둔다.
function World.addPlayer(player)
	if sessions[player] then
		return
	end
	local s = { player = player, hero = nil, acct = nil, cid = nil, scene = SCENES.start, skill = nil, jumped = true, loaded = false, dirty = false, name = "" }
	sessions[player] = s
	byUser[player.UserId] = s
	local guest, guestLevel, guestMode = World.guest()
	if guest == "new" or guest == "select" then
		s.guest = true -- 저장하지 않는 임시 계정: 캐릭터 만들기부터 해 본다(이름 장부에도 적지 않는다)
		s.acct = Account.new()
		if guest == "select" then
			for _, row in { { "달빛도끼", "axion", 12 }, { "밤의창", "riven", 31 }, { "", "mooni", 5 } } do
				local h = Hero.new(player.UserId, row[2])
				while h.level < row[3] do
					Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
				end
				h.quests[Quests.FIRST.quest] = { done = true, c = {} } -- 자란 캐릭터다: 첫 퀘스트는 끝낸 것으로(전직 퀘스트는 그대로 — Lv.31 캐릭터로 「2차 전직」을 받은 모습을 본다)
				Hero.autoStat(h)
				local data = Hero.pack(h)
				data.bag.store = nil
				Account.add(s.acct, row[1], row[2], data, 0)
			end
		end
		s.loaded = true
		return
	end
	if guest then
		s.guest = true -- 저장하지 않는다(removePlayer · saveAll · 확인용 reset이 모두 건너뛴다)
		s.hero = guestHero(player.UserId, guest, guestLevel, guestMode)
		s.name = "시험 " .. CLASSES.classes[guest].name
		local scene = SCENES.scenes[s.scene]
		s.hero.x, s.hero.y = scene.spawn.x, scene.spawn.y
		-- 확인용 캐릭터도 서 있는 마을에는 들른 것이다(보통 캐릭터는 들어올 때 place가 적는다)
		if SCENES.homes[s.scene] then
			s.hero.home = s.scene
		end
		roomOf(s.scene)
		s.loaded = true
		markName(s)
		return
	end
	-- 계정을 읽기 전에 이 서버가 그 계정을 잡는다: 다른 서버가 잡고 있으면 읽지 않는다(두 서버가 번갈아 저장하면 물건이 복사된다)
	local held = false
	for attempt = 1, LOCK_TRIES do
		if holdAccount(player.UserId) then
			held = true
			break
		end
		if attempt < LOCK_TRIES then
			task.wait(LOCK_WAIT)
		end
		if sessions[player] ~= s then
			return -- 기다리는 사이에 나갔다
		end
	end
	if not held then
		s.guest, s.locked = true, true -- 이 자리에서는 아무것도 저장하지 않는다
		warn(("[lune] %d의 계정을 다른 서버가 잡고 있다 — 내보낸다"):format(player.UserId))
		kick(player, LOCK_KICK)
		return
	end
	s.held = true
	local data = Store.loadAccount(player.UserId)
	local acct = if data then Account.unpack(data) else nil
	local adopted = false
	if not acct and not data then
		local old = Store.loadOld(player.UserId)
		if sessions[player] ~= s then
			return -- 읽는 사이에 나갔다
		end
		acct = Account.adopt(old, os.time())
		adopted = #acct.chars > 0
	end
	if sessions[player] ~= s then
		return -- 읽는 사이에 나갔다
	end
	if not acct then
		-- 저장된 것이 있는데 읽을 수 없는 꼴이다: 덮어쓰지 않게 이 자리에서는 저장하지 않는다
		warn(("[lune] %d의 계정을 읽을 수 없는 꼴이다 — 이번에는 저장하지 않는다"):format(player.UserId))
		acct = Account.new()
		s.guest = true
	end
	s.acct = acct
	s.loaded = true
	if adopted then
		saveAccount(s)
	end
end

-- 세계에서 나온다(캐릭터 고르기 화면으로 · 나갈 때): 저장하고, 파티에서 빠지고, 방 사람들의 이름표에서도 빠진다
local function leaveWorld(s)
	if s.hero then
		saveAccount(s)
	end
	local had, scene = s.hero ~= nil, s.scene
	local left = Party.leave(book, s.player.UserId)
	s.hero, s.cid, s.skill, s.name = nil, nil, nil, ""
	s.scene = SCENES.start
	sendParty(left)
	if had then
		sendWho(scene)
	end
end

function World.removePlayer(player)
	local s = sessions[player]
	sessions[player] = nil
	byUser[player.UserId] = nil
	if s and s.hero then
		saveAccount(s)
	end
	-- 저장을 끝낸 뒤에 계정의 잠금을 푼다(다른 서버로 옮겨 가면 그 서버가 바로 잡는다)
	if s and s.held and Store.unlock then
		Store.unlock(player.UserId)
	end
	sendParty(Party.leave(book, player.UserId))
	if s and s.hero then
		sendWho(s.scene)
	end
end

-- 바뀐 캐릭터를 모두 저장한다(틈틈이 · 서버가 닫힐 때)
--  저장하기 전에 계정의 잠금을 새로 고친다. 잠금을 잃었으면(이 서버가 오래 멈춰 있어 다른 서버가 넘겨받았다) 저장하지 않고 내보낸다 — 더 새로운 저장을 덮어쓰지 않게
function World.saveAll(onlyDirty: boolean?)
	for _, s in sessions do
		if s.held and not s.guest then
			if not holdAccount(s.player.UserId) then
				s.guest, s.locked, s.held = true, true, false
				warn(("[lune] %d의 계정의 잠금을 잃었다 — 저장하지 않고 내보낸다"):format(s.player.UserId))
				kick(s.player, LOCK_KICK)
			end
		end
		if s.hero and s.loaded and not s.guest and (s.dirty or not onlyDirty) then
			saveAccount(s)
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
	return { self = selfView(s), bag = Bag.view(s.hero), quests = Quests.view(s.hero.quests), scene = s.scene, x = s.hero.x, y = s.hero.y, room = room, id = s.hero.id, name = s.name }
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
		return if s.acct then { select = Account.view(s.acct) } else nil -- 캐릭터 고르기 화면부터
	end
	task.defer(sendWho, s.scene) -- 먼저 와 있던 사람들에게 내가 왔다고 알린다
	sendParty({ player.UserId })
	return describe(s)
end

-- 이름을 지을 수 있는가: 꼴 → 내 다른 캐릭터의 이름 → 글 거르기 → 이름 장부(남이 가진 이름). 돌려주는 것: 되는가, 안 되는 까닭
--  skip = 견주지 않을 내 캐릭터(이름이 없던 캐릭터에 이름을 지어 줄 때)
local TAKEN, LATER = Account.TEXT.taken, Account.TEXT.later
-- Roblox의 글 거르기를 거친다. 돌려주는 것: 물어봤는가(서비스가 답했는가), 걸러진 데 없이 그대로인가
--  Studio에서는 걸러 주지 않고 그대로 돌려준다 — 실제 서버에서만 걸러진다(그래서 우리 목록 Account.nameBanned가 따로 있다)
local function filtered(name: string, userId: number): (boolean, boolean)
	local asked, clean = pcall(function()
		return TextService:FilterStringAsync(name, userId):GetNonChatStringForBroadcastAsync()
	end)
	return asked, asked and clean == name
end

local function nameFree(s, name: any, skip: any?): (boolean, string?)
	local ok, why = Account.nameOk(name)
	if not ok then
		return false, why
	end
	if Account.hasName(s.acct, name, skip) then
		return false, TAKEN
	end
	if s.guest then
		return true, nil -- 임시 계정: 장부도 글 거르기도 거치지 않는다(저장하지 않는 캐릭터다)
	end
	-- Roblox의 글 거르기: 걸러진 데가 있으면 쓸 수 없다. 물어보지 못했을 때도 짓지 못한다(거르지 않은 이름이 남에게 보이면 안 된다)
	local asked, clean = filtered(name, s.player.UserId)
	if not asked then
		return false, LATER
	elseif not clean then
		return false, Account.TEXT.banned
	end
	local owner = Store.nameOwner(Account.nameKey(name))
	if owner == false then
		return false, LATER
	elseif owner ~= nil and owner ~= s.player.UserId then
		return false, TAKEN
	end
	return true, nil
end

-- 이름을 장부에 내 것으로 적는다(먼저 적은 사람이 갖는다). 돌려주는 것: 되는가, 안 되는 까닭
local function claim(s, name: string): (boolean, string?)
	if s.guest then
		return true, nil
	end
	local mine = Store.claimName(Account.nameKey(name), s.player.UserId, os.time())
	if mine == nil then
		return false, LATER
	elseif not mine then
		return false, TAKEN
	end
	return true, nil
end

-- 캐릭터 고르기 화면의 일(세계에 캐릭터가 서 있지 않을 때만 — leave만 빼고).
--  check(이름) → { ok, why }: 그 이름을 지을 수 있는가(중복 확인)
--  create(이름, 직업) → { ok, why, id, select }: Lv.1 캐릭터를 만든다
--  name(번호, 이름) → { ok, why, select }: 이름이 없는 캐릭터(계정이 생기기 전의 캐릭터)에 이름을 짓는다
--  delete(번호, 이름) → { ok, why, select }: 캐릭터를 지운다 — 그 캐릭터의 이름을 그대로 적어 보내야 한다(잘못 누른 것이 아님을 서버도 본다)
--  enter(번호) → Ready와 같은 것(self · bag · room …): 그 캐릭터로 세계에 들어간다
--  leave() → { select }: 세계에서 나와 고르기 화면으로(저장하고 나온다)
local function onChars(player, action: string, a: any, b: any)
	local s = sessions[player]
	if not s or not s.loaded or not s.acct then
		return nil
	end
	local acct = s.acct
	if action == "leave" then
		if s.hero then
			leaveWorld(s)
			markName(s)
		end
		return { select = Account.view(acct) }
	elseif s.hero then
		return nil
	end
	if action == "check" then
		local ok, why = nameFree(s, a)
		return { ok = ok, why = why }
	elseif action == "create" then
		if Account.full(acct) then
			return { ok = false, why = ("캐릭터는 %d명까지 만들 수 있습니다"):format(Account.MAX) }
		elseif typeof(b) ~= "string" or not CLASSES.classes[b] then
			return { ok = false, why = "없는 직업입니다" }
		end
		local ok, why = nameFree(s, a)
		if ok then
			ok, why = claim(s, a)
		end
		if not ok then
			return { ok = false, why = why }
		end
		local data = Hero.pack(Hero.new(player.UserId, b))
		data.bag.store = nil
		local c = Account.add(acct, a, b, data, os.time())
		saveAccount(s)
		return { ok = true, id = c.id, select = Account.view(acct) }
	elseif action == "name" then
		local c = Account.find(acct, a)
		if not c or c.name ~= "" then
			return { ok = false, why = "이름을 지을 수 없는 캐릭터입니다" }
		end
		local ok, why = nameFree(s, b, c.id)
		if ok then
			ok, why = claim(s, b)
		end
		if not ok then
			return { ok = false, why = why }
		end
		c.name = b
		saveAccount(s)
		return { ok = true, select = Account.view(acct) }
	elseif action == "delete" then
		local c = Account.find(acct, a)
		if not c then
			return { ok = false, why = "없는 캐릭터입니다" }
		elseif c.name ~= "" and b ~= c.name then
			return { ok = false, why = "캐릭터의 이름을 똑같이 적어야 지울 수 있습니다" }
		end
		Account.remove(acct, c.id)
		saveAccount(s)
		-- 명예의 전당에서도 뺀다
		local rankKey = Rank.charKey(player.UserId, c.id)
		Store.rankRemove("level", rankKey)
		Store.rankRemove("power", rankKey)
		Store.rankInfoRemove(rankKey)
		if c.name ~= "" and not s.guest then
			Store.freeName(Account.nameKey(c.name), player.UserId) -- 지운 캐릭터의 이름은 다시 누구나 지을 수 있다(내 제안)
		end
		return { ok = true, select = Account.view(acct) }
	elseif action == "enter" then
		local c = Account.find(acct, a)
		if not c then
			return nil
		elseif c.name == "" then
			return { ok = false, why = "이름을 먼저 지어야 합니다" }
		end
		-- 이름을 다시 본다: 지을 때는 괜찮았어도 그 뒤에 금칙어가 늘었거나 Roblox의 글 거르기가 달라졌을 수 있다
		--  (Studio에서는 글 거르기가 걸러 주지 않는다 — 거기서 지은 이름도 실제 서버에 들어올 때 여기서 걸린다). 걸리면 이름을 비우고 다시 짓게 한다. 물어보지 못했으면 그냥 들여보낸다.
		if not s.guest then
			local asked, clean = filtered(c.name, player.UserId)
			if Account.nameBanned(c.name) or (asked and not clean) then
				Store.freeName(Account.nameKey(c.name), player.UserId)
				c.name = ""
				saveAccount(s)
				return { ok = false, why = Account.TEXT.gone, select = Account.view(acct) }
			end
		end
		local hero = Hero.unpack(player.UserId, c.hero)
		if not hero then
			return { ok = false, why = "이 캐릭터를 읽을 수 없습니다" }
		end
		Bag.loadStore(hero, acct.store) -- 창고는 계정의 것: 어느 캐릭터로 들어가든 같은 창고다
		s.hero, s.cid, s.name = hero, c.id, c.name
		acct.last = c.id
		-- 첫 퀘스트를 아직 끝내지 않은 새 캐릭터는 사당 안(사제의 방)에서 시작한다 — 그 밖에는 마을의 시작 자리
		local startKey = Quests.firstScene(hero.quests, hero.level) or SCENES.start
		if not SCENES.scenes[startKey] then
			startKey = SCENES.start
		end
		local scene = SCENES.scenes[startKey]
		place(s, startKey, scene.spawn.x, scene.spawn.y)
		roomOf(s.scene)
		s.dirty = true
		s.rankSent = nil
		markName(s)
		pushRank(s) -- 들어오자마자 순위판에 올린다(명예의 전당)
		task.defer(sendWho, s.scene) -- 먼저 와 있던 사람들에게 내가 왔다고 알린다
		sendParty({ player.UserId })
		return describe(s)
	end
	return nil
end

-- ---------- 명예의 전당 ----------
--  판 셋의 위 열 줄. 서버가 Rank.REFRESH초마다 한 번만 읽어 둔 것을 준다(물을 때마다 저장소를 읽지 않는다).
local rankCache, rankAt = nil, -math.huge
local function rankBoards()
	if rankCache and World.now - rankAt < Rank.REFRESH then
		return rankCache
	end
	local boards = {}
	for _, board in Rank.BOARDS do
		boards[board] = Rank.view(board, Store.rankTop(board, Rank.TOP + 5), Store.rankInfoGet) -- 이름을 모르는 줄이 빠질 것을 생각해 조금 넉넉히 읽는다
	end
	rankCache, rankAt = boards, World.now
	return boards
end

local function onRank(player)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	pushRank(s) -- 내 것은 방금의 값으로
	if s.rankFresh ~= s.rankSent.level then
		s.rankFresh = s.rankSent.level
		rankCache = nil -- 내 레벨이 달라졌으면 다시 읽는다(내가 판에 있는지 바로 보이게)
	end
	return rankBoards()
end

-- 이 계정이 로벅스를 썼다: 계정에 더하고 후원 판에 올린다(이름은 지금 하는 캐릭터). 게임 안 상점(개발자 상품)이 생기면 그 영수증 처리에서 부른다 — 지금은 부르는 곳이 확인용 명령뿐이다.
function World.addSpent(player, robux: number)
	local s = sessions[player]
	if not s or not s.acct or typeof(robux) ~= "number" or robux <= 0 then
		return
	end
	s.acct.spent += math.floor(robux)
	local key = Rank.userKey(player.UserId)
	if s.name ~= "" then
		Store.rankInfoSet(key, { name = s.name, class = if s.hero then s.hero.class else false }, s.guest == true)
	end
	Store.rankSet("robux", key, s.acct.spent, s.guest == true)
	rankCache = nil
	saveAccount(s)
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
	-- 장면을 옮긴 직후: 옮겨 놓은 자리에서 먼 보고는 옮겨지기 전에 떠난 늦은 보고다(관리 이동처럼 서버가 먼저 옮기면, 화면이 그것을 알기 전에 보낸 옛 장면의 자리가 뒤따라 온다) — 받지 않는다.
	--  LOAD_STALE초가 지나면 예전처럼 받는다(어긋난 채 남지 않게)
	if s.stale then
		local near = math.abs(x - hero.x) <= MOVE_SLACK and math.abs(y - hero.y) <= MOVE_SLACK * 2
		if not near and World.now - s.stale < LOAD_STALE then
			return
		end
		s.stale = nil
	end
	arrived(s) -- 자리 보고가 왔다 = 화면이 열렸다
	-- 그 맵의 시작 자리로 온 것은 받는다(맵 아래로 떨어지면 화면이 시작 자리로 돌려놓는다 — 이것까지 막으면 그 뒤로 자리가 영영 어긋난다)
	local atSpawn = math.abs(x - scene.spawn.x) <= MOVE_SLACK and math.abs(y - scene.spawn.y) <= MOVE_SLACK * 2
	if not s.jumped and not atSpawn and (math.abs(x - hero.x) > MOVE_SLACK or math.abs(y - hero.y) > MOVE_SLACK * 2) then
		-- 순간이동하는 스킬을 쓴 직후에는 받는다(그 스킬이 갈 수 있는 거리 안에서)
		local warped = hero.warpAt ~= nil and World.now - hero.warpAt <= WARP_TIME and math.abs(x - hero.x) <= WARP_SLACK and math.abs(y - hero.y) <= MOVE_SLACK * 2
		if not warped then
			-- 순간이동은 믿지 않는다(서버가 아는 자리를 그대로 둔다) — 그리고 화면을 그 자리로 되돌린다.
			--  되돌리지 않으면 그 뒤의 보고가 모두 멀어서, 서버가 아는 자리와 화면의 자리가 영영 어긋난다(2026-10-07의 가시 고장과 같은 일)
			if World.now - (s.warpSent or -9) > 0.5 then
				s.warpSent = World.now
				fire("Warp", player, hero.x, hero.y)
			end
			return
		end
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
			if p.need and not Quests.reached(s.hero.quests, p.need) then
				return nil -- 그 퀘스트를 받아야 열리는 문(달의 사당 안의 「사당 지하」 — 메인 「불타는 마을」): 화면에도 보이지 않는다
			end
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

-- 쓰러진 사람이 마을로 돌아간다(「마을로 돌아갈까요?」 상자의 단추). 쓰러지고 조금 지난 뒤부터 받는다.
--  돌아가는 곳 = 마지막으로 들른 마을 · 작은 마을(없으면 시작 마을 — 설계 journey.js의 HOMES). 마을 사이를 바로 오가는 기능은 없다(사용자 2026-10-11: 걸어서 다닌다)
local function onReturn(player)
	local s = sessions[player]
	if not s or not s.hero or not Hero.canReturn(s.hero) then
		return
	end
	Hero.revive(s.hero)
	local homeKey = if s.hero.home and SCENES.homes[s.hero.home] and SCENES.scenes[s.hero.home] then s.hero.home else SCENES.start
	local scene = SCENES.scenes[homeKey]
	local from = s.scene
	place(s, homeKey, scene.spawn.x, scene.spawn.y, true)
	local room = roomOf(s.scene):describe(s.hero.id)
	room.who = roster(s.scene)
	fire("Revive", s.player, { scene = s.scene, x = s.hero.x, y = s.hero.y, room = room })
	sendSelf(s)
	sendWho(from)
	sendWho(s.scene)
	sendParty(Party.members(book, s.hero.id))
end

-- 판정의 결과를 방에 푼다: 맞은 것 · 잡은 것(경험치 · 퀘스트 · 떨어진 것) · 달 수정 · 내 상태. cur = 때린 사람의 자리 · key = 그 방
local function applyResult(cur, key: string, result)
	-- 무니의 달 수정이 생기거나 사라졌다
	if result.crystals or result.crystalGone then
		toRoom(key, "Crystal", { add = result.crystals or {}, gone = result.crystalGone or {} })
	end
	if #result.hits > 0 then
		toRoom(key, "Hits", cur.player.UserId, result.hits)
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
				-- 일일 의뢰: 받아 둔 의뢰의 그 맵 · 그 몬스터면 센다(함께 잡은 사람 모두)
				if Daily.onKill(gs.hero, kill.kind, key, os.time()) then
					gs.dirty = true
					fire("DailyView", gs.player, (Daily.view(gs.hero, os.time())))
				end
				-- 모으는 물건은 사람마다 따로 굴려 그 사람의 것으로 땅에 떨어진다(그 사람에게만 보인다) — 주워야 숫자가 오른다
				for n, q in Quests.drops(gs.hero.quests, kill.kind, key, questRng) do
					local d = roomOf(key):addDrop({ kind = "quest", amount = 1, quest = q.quest, step = q.step, name = q.name, icon = q.icon, goods = q.goods }, kill.x - n * 9, kill.y, gs.hero.id)
					fire("DropAdd", gs.player, Room.dropView(d))
				end
				if gain.xp > 0 then -- 스토리 보스는 경험치를 주지 않는다(퀘스트만 센다)
					fire("Gain", gs.player, { xp = gain.xp, ups = gain.ups, level = gain.level })
				end
				if gain.ups > 0 then
					fire("Quests", gs.player, Quests.view(gs.hero.quests)) -- 레벨이 되어 저절로 받은 퀘스트(전직 퀘스트)
				end
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
	if #result.kills > 0 or result.kit or result.heal then
		sendSelf(cur) -- 잡았다 · 장치의 모습이 바뀌었다(영혼 · 열기) · 체력을 되찾았다(생기 흡수)
	end
	if result.buffs then
		sendBuffs(cur) -- 걸린 버프의 시간이 바뀌었다(꺼지지 않는 불: 폭주 중에 쓰러뜨렸다)
	end
	if grew then
		sendWho(key) -- 레벨이 오른 사람의 이름표
	end
end

-- 같은 맵의 파티원(레벨 차이 20 안쪽 — 나도 든다): 경험치를 나누고, 회복 · 파티 버프가 닿는다. 혼자면 nil
local function matesIn(key: string, hero)
	local here, heroOf = {}, {}
	for _, o in inRoom(key) do
		if o.hero.alive then
			here[o.hero.id], heroOf[o.hero.id] = o.hero, o.hero
		end
	end
	local mates = {}
	for _, mid in Party.mates(book, hero.id, here) do
		table.insert(mates, heroOf[mid])
	end
	return if #mates > 1 then mates else nil
end

-- 같은 맵에 쓰러져 있는 파티원들(reach 안 — 소생이 일으킨다)
local function fallenIn(key: string, hero, reach: number)
	local here, heroOf = {}, {}
	for _, o in inRoom(key) do
		here[o.hero.id], heroOf[o.hero.id] = o.hero, o.hero
	end
	local out = {}
	for _, mid in Party.mates(book, hero.id, here) do
		local mate = heroOf[mid]
		if mate ~= hero and not mate.alive and math.abs(mate.x - hero.x) <= reach and math.abs(mate.y - hero.y) <= 80 then
			table.insert(out, mate)
		end
	end
	return out
end

-- 기술: 구간(seg)마다 한 번씩 온다. 첫 구간은 앞 기술이 끝난 뒤에만, 이어지는 구간은 앞 구간 도중이나 끝난 직후에만 받는다.
local function onSkill(player, id: string, seg: number, x: number, y: number, dir: number)
	local s = sessions[player]
	if s and s.hero then
		arrived(s) -- 기술을 쓴다 = 화면이 열렸다(옮긴 뒤의 긴 보호를 끝낸다)
	end
	-- 온오프 사출기: 누르면 켜고 끈다(쓰는 동작이 없다 — 켜 두면 주력기가 맞을 때 저절로 나간다. sim/kit.luau)
	if s and s.hero and s.hero.alive and Kit.isToggle(s.hero, id) then
		Kit.toggle(s.hero)
		sendSelf(s)
		return
	end
	-- 버프(갱신 · 파티 · 생존 · 극딜 · 공용): 누르면 바로 걸린다(쓰는 동작이 없다 — 다른 동작 중에도 걸린다). 파티 버프는 가까운 파티원에게도 걸린다
	if s and s.hero and s.hero.alive and Buffs.instant(id) then
		local hero = s.hero
		local pow = Buffs.cast(hero, id, World.now)
		if pow then
			-- 버프와 함께 놓이는 것(작은 태양)
			if COMBAT.placed[id] then
				hero.dir = dir
				local result = { hits = {}, kills = {} }
				roomOf(s.scene):place(hero, id, pow, result)
				applyResult(s, s.scene, result)
			end
			if math.abs(x - hero.x) <= 40 and math.abs(y - hero.y) <= 60 then
				hero.x, hero.y = x, y
			end
			local reach = Buffs.data[id].fx.party
			if reach then
				local here = {}
				for _, o in inRoom(s.scene) do
					if o.hero.alive then
						here[o.hero.id] = o
					end
				end
				for _, mid in Party.mates(book, hero.id, here) do
					local o = here[mid]
					if o and o ~= s and math.abs(o.hero.x - hero.x) <= reach and math.abs(o.hero.y - hero.y) <= math.min(reach, 120) then
						Buffs.give(o.hero, id, pow, hero.x, hero.y)
						sendSelf(o)
						sendBuffs(o)
					end
				end
			end
			-- 방의 다른 사람들에게: 이 사람이 버프를 건다(걸리는 순간의 이펙트)
			for _, other in inRoom(s.scene) do
				if other ~= s then
					fire("Act", other.player, hero.id, id, 1, hero.x, hero.y, dir, 0)
				end
			end
			sendSelf(s)
			sendBuffs(s)
		end
		return
	end
	-- 설치 · 소환 가운데 누르면 바로 놓이는 것(화로 · 망령 · 수호령): 쓰는 동작이 없다. 다시 쓰기 · 태우는 영혼을 본다
	local placed = COMBAT.placed[id]
	if s and s.hero and s.hero.alive and placed and placed.cast == "instant" then
		local hero = s.hero
		if placed.who ~= hero.class or (hero.skills[id] or 0) < 1 or (hero.cds[id] or 0) > World.now or (placed.cost and hero.kit.souls < placed.cost) then
			return
		end
		if placed.cost then
			hero.kit.souls -= placed.cost
		end
		if placed.cd > 0 then
			hero.cds[id] = World.now + placed.cd
		end
		if math.abs(x - hero.x) <= 40 and math.abs(y - hero.y) <= 60 then
			hero.x, hero.y = x, y
		end
		hero.dir = dir
		local result = { hits = {}, kills = {} }
		roomOf(s.scene):place(hero, id, Hero.skillScale(hero.skills[id], placed.max), result)
		for _, other in inRoom(s.scene) do
			if other ~= s then
				fire("Act", other.player, hero.id, id, 1, hero.x, hero.y, dir, 0)
			end
		end
		applyResult(s, s.scene, result)
		sendSelf(s)
		return
	end
	-- 2~4차의 쓰는 스킬(사냥기 · 보스기 · 공격기 · 큰 기술 · 바인드 · 회복): 직업 묶음의 그 스킬을 방이 돌린다(sim/caster.luau).
	--  구간마다 온다 — 누르고 있는 구간을 뗀 때 · 이어 누른 때 · 땅에 닿은 때는 화면만 안다. 방은 그 구간이 너무 이르지 않은지만 본다
	local castDef = COMBAT.cast[id]
	if s and s.hero and s.hero.alive and castDef then
		local hero = s.hero
		if castDef.who ~= hero.class or Hero.skillLevel(hero, id) < 1 or typeof(seg) ~= "number" then
			return
		end
		local now = World.now
		if seg == 1 then
			if (hero.cds[id] or 0) > now then
				return
			end
			if s.skill and now < s.skill.free - 0.1 then
				return -- 1차의 기술을 쓰는 중이다
			end
		end
		-- 쓴 자리: 서버가 아는 자리와 크게 다르지 않으면 화면이 말한 자리를 받아 적는다
		if math.abs(x - hero.x) <= 40 and math.abs(y - hero.y) <= 60 then
			hero.x, hero.y = x, y
		end
		local was = hero.dir
		hero.dir = dir
		local key = s.scene
		-- 소생: 닿는 거리 안에 쓰러진 파티원이 있을 때만 써진다(없으면 다시 쓰기도 돌지 않는다)
		local fallen = nil
		if castDef.heal and castDef.heal.revive then
			fallen = fallenIn(key, hero, castDef.heal.reach)
			if #fallen == 0 then
				hero.dir = was
				return
			end
		end
		local ok, lv = roomOf(key).caster:begin(hero, id, seg, matesIn(key, hero), { fallen = fallen })
		if not ok then
			hero.dir = was
			return
		end
		hero.warpAt = now -- 이 스킬이 몸을 옮길 수 있다(순간이동 · 돌진) — 잠깐은 멀리 간 자리 보고도 받는다(onMove)
		if seg == 1 and castDef.cd > 0 then
			hero.cds[id] = now + castDef.cd
		end
		for _, other in inRoom(key) do
			if other ~= s then
				fire("Act", other.player, hero.id, id, seg, hero.x, hero.y, dir, lv or 0)
			end
		end
		return
	end
	local def = COMBAT.skills[id]
	if not s or not def or not s.hero or not s.hero.alive or def.who ~= s.hero.class or Hero.skillLevel(s.hero, id) < 1 then
		return
	end
	if seg == 1 and roomOf(s.scene).caster:busy(s.hero) then
		return -- 2~4차의 스킬을 쓰는 중이다
	end
	local haste = Buffs.haste(s.hero) -- 공격 속도 버프: 동작과 타격이 그만큼 빨라진다(이동기는 그대로)
	if def.type == "move" then
		haste = 1
	end
	local segDef = def.segs[seg]
	if not segDef or seg ~= math.floor(seg) then
		return
	end
	local now = World.now
	local last = s.skill
	local prev = def.segs[seg - 1]
	local charged = nil -- 힘을 모아 쳤으면 { mul 피해의 배수, reach 더 닿는 거리, level 단계 }
	if seg == 1 then
		if last and now < last.free - 0.1 then
			return -- 앞 기술이 아직 안 끝났다
		end
		if def.cd > 0 and s.cds and s.cds[id] and now < s.cds[id] then
			return
		end
	elseif segDef.next or prev.charge then
		-- 한 번 더 눌러 잇는 구간(next) · 힘을 모으는 구간(charge)의 다음 구간: 바로 앞 구간이어야 한다.
		--  next = 앞 구간이 반쯤 지난 뒤부터 끝난 직후까지 / charge의 다음 = 앞 구간이 끝난 뒤부터, 끝까지 모으는 시간이 지난 직후까지(키를 뗄 때 온다)
		if not (last and last.id == id and last.seg == seg - 1) then
			return
		end
		local elapsed = now - last.at
		local hold = if prev.charge then Kit.chargeTime(s.hero, id) else 0
		local prevTime = prev.time / haste
		local from = if segDef.next then prevTime * 0.4 else prevTime - 0.15
		if elapsed < from or elapsed > prevTime + hold + 0.4 then
			return
		end
		if prev.charge then
			-- 모은 단계는 서버가 흐른 시간으로 셈한다(화면이 말한 단계를 믿지 않는다). 만월 동안에는 모으지 않아도 끝까지 모은 것으로 친다
			local held = if Buffs.full(s.hero) then hold else elapsed - prevTime
			local level, mul, reach = Kit.charge(s.hero, id, held)
			-- 넘치는 힘(액시온 4차): 끝까지 모은 강타를 맞힌 직후에는 모으지 않아도 높은 단계에서 시작한다(한 번 쓰면 사라진다)
			local surge = Passives.get(s.hero, "surge")
			local surged = false
			if surge and hold > 0 and s.hero.pass.surge > roomOf(s.scene).time and level < surge.surgeFrom then
				level = math.min(surge.surgeFrom, Kit.chargeLevels(s.hero))
				mul, reach = Kit.chargeAt(s.hero, level)
				s.hero.pass.surge = -1e9
				surged = true
			end
			if level > 0 then
				charged = { mul = mul, reach = reach, level = level, surged = surged } -- surged = 모으지 않고 얻은 단계(이 타로는 넘치는 힘이 다시 켜지지 않는다)
			end
		end
	else
		return -- 저절로 이어지는 구간은 서버가 잇는다(화면이 보낼 일이 없다)
	end
	local hero = s.hero
	-- 쓴 자리: 서버가 아는 자리와 크게 다르지 않으면 클라이언트가 말한 자리를 받아 적는다(판정은 맞는 순간의 자리로 한다)
	if math.abs(x - hero.x) <= 40 and math.abs(y - hero.y) <= 60 then
		hero.x, hero.y = x, y
	end
	hero.dir = dir
	-- 저절로 이어지는 뒤 구간은 한꺼번에 받는다 — 한 번 더 눌러 잇는 구간(next) · 힘을 모으는 구간(charge)의 다음 구간 앞에서 끊는다(그것들은 따로 온다)
	local free = now + segDef.time / haste
	local startAt = 0
	local segs = { seg }
	for i = seg + 1, #def.segs do
		if def.segs[i].next or def.segs[i - 1].charge then
			break
		end
		table.insert(segs, i)
		free += def.segs[i].time / haste
	end
	s.skill = { id = id, seg = segs[#segs], at = now, free = free }
	hero.actUntil = roomOf(s.scene).time + (free - now) -- 기술의 동작을 하는 동안(굳센 자세: 그동안은 받는 피해가 더 준다)
	if def.cd > 0 then
		s.cds = s.cds or {}
		s.cds[id] = now + def.cd
	end
	local key = s.scene
	-- 방의 다른 사람들에게: 이 사람이 이 기술의 이 구간을 쓴다(그 사람들의 화면에서 동작이 나온다)
	for _, other in inRoom(key) do
		if other ~= s then
			fire("Act", other.player, hero.id, id, seg, hero.x, hero.y, dir, if charged then charged.level else 0)
		end
	end
	-- 쓰는 동작이 있는 설치(연막탄 · 수정 심기 · 저승문): 그 동작의 그 장에서 놓인다(연막탄은 그 자리에 버프가 걸린다)
	if seg == 1 and placed and placed.cast == "seg" then
		table.insert(pending, {
			at = now + placed.at / haste,
			fn = function()
				local cur = sessions[player]
				if not cur or cur.scene ~= key or not cur.hero.alive then
					return
				end
				local pow = Hero.skillScale(cur.hero.skills[id] or 0, placed.max)
				local result = { hits = {}, kills = {} }
				if placed.buff and Buffs.is(id) then
					Buffs.give(cur.hero, id, pow, cur.hero.x, cur.hero.y)
					sendBuffs(cur)
				end
				roomOf(key):place(cur.hero, id, pow, result)
				applyResult(cur, key, result)
				sendSelf(cur)
			end,
		})
	end
	-- 충격파(액시온 2차): 끝까지 모아 친 대지 강타는 땅을 따라 넓게 한 번 더 나간다 — 그 타(가운데 타 + 가시 하나) 피해의 일부
	local shock, shockS = Passives.get(hero, "shock")
	if shock and id == "ax_slam" and charged and charged.level >= Kit.chargeLevels(hero) then
		local base, last = 0, 0
		for _, hit in def.hits do
			if hit.seg == seg and not hit.except then
				base += hit.mul
				last = math.max(last, hit.at)
			end
		end
		local wave = { box = { -110, 150, 30, 6 }, mul = base * shock.shock * shockS }
		table.insert(pending, {
			at = now + (last + 0.3) / haste,
			fn = function()
				local cur = sessions[player]
				if not cur or cur.scene ~= key or not cur.hero.alive then
					return
				end
				applyResult(cur, key, roomOf(key):skillHit(cur.hero, wave, cur.hero.x, cur.hero.y, dir, Hero.scale(cur.hero, id), matesIn(key, cur.hero), def.type, nil, charged))
			end,
		})
	end
	for _, index in segs do
		for _, hit in def.hits do
			if hit.seg == index then
				table.insert(pending, {
					at = now + (startAt + hit.at) / haste,
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
						local result = roomOf(key):skillHit(cur.hero, hit, cur.hero.x, cur.hero.y, dir, Hero.scale(cur.hero, id), if #mates > 1 then mates else nil, COMBAT.skills[id].type, id, charged)
						applyResult(cur, key, result)
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
		if drop.kind == "money" then
			sendSelf(s)
		else
			sendBag(s) -- 장비 · 달가루 · 퀘스트의 물건(가방의 기타 탭에 들어갔다 — 퀘스트의 숫자는 sendBag이 맞춘다)
		end
	elseif why == Bag.FULL then
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
local function onItem(player, action: string, a: any, b: any, c: any, d: any)
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
	elseif action == "move" then
		ok, why = Bag.move(h, a, b, c) -- 탭 · 옮길 칸 · 놓을 칸
	elseif action == "sort" then
		ok, why = Bag.sort(h, a)
	elseif action == "discard" then
		ok, why = Bag.discard(h, a, b, c) -- 탭 · 칸 · 버릴 수
	elseif action == "split" then
		ok, why = Bag.split(h, a, b, c, d) -- 탭 · 칸 · 덜어 낼 수 · 놓을 칸(안 주면 첫 빈 칸)
	elseif action == "sell" then
		-- 상점에 판다: 어느 상점(잡화 상인 · 대장장이) 앞에서나. 탭 · 칸 · 팔 수
		if not nearNpc(s, "shop") and not nearNpc(s, "smith") then
			why = "파는 사람 앞이 아니다"
		else
			result, why = Bag.sell(h, a, b, c)
			ok = result ~= nil
		end
	elseif action == "buy" then
		local stock = if typeof(a) == "string" then Items.stock(a) else nil
		if not stock then
			why = "없는 물건이다"
		elseif not nearNpc(s, if stock.npc == "merchant" then "shop" else "smith") then
			why = "파는 사람 앞이 아니다"
		else
			ok, why = Bag.buy(h, a, b)
		end
	elseif action == "craft" then
		-- 제작: 대장장이 앞에서. 재료(광석 · 가죽)와 달돈 → 그 단계의 장비 한 벌(성능은 보통 이상)
		if not nearNpc(s, "smith") then
			why = "대장장이 앞이 아니다"
		else
			local made
			made, why = Bag.craft(h, a, itemRng)
			ok = made ~= nil
			result = if made then { slot = made.slot, stage = made.stage, q = made.q, star = made.star, who = made.who } else nil
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
	elseif action == "storeIn" or action == "storeOut" or action == "storeMove" or action == "storeSort" then
		-- 창고: 맡기기 · 찾기(탭 · 칸 · 수 · 놓을 칸) · 창고 안에서 옮기기(탭 · 옮길 칸 · 놓을 칸) · 창고의 탭 정렬
		if h.level < OPEN.store then
			why = ("Lv.%d부터 쓴다"):format(OPEN.store)
		elseif not nearNpc(s, "store") then
			why = "창고지기 앞이 아니다"
		elseif action == "storeIn" then
			ok, why = Bag.storeIn(h, a, b, c, d)
		elseif action == "storeOut" then
			ok, why = Bag.storeOut(h, a, b, c, d)
		elseif action == "storeMove" then
			ok, why = Bag.move(h, a, b, c, true)
		else
			ok, why = Bag.sort(h, a, true)
		end
	else
		why = "모르는 일이다"
	end
	fire("ItemDone", player, { action = action, ok = ok == true, why = why, result = result })
	if ok then
		sendBag(s)
	end
end

-- 소비 아이템을 쓴다(퀵슬롯 · 가방의 「사용」). id = 그 아이템의 이름표(안 주면 지금 마실 수 있는 가장 좋은 물약)
local function onPotion(player, id: any)
	local s = sessions[player]
	if not s or not s.hero then
		return
	end
	-- 귀환 주문서: 쓰면 마을(쓰러졌을 때 돌아가는 곳)로 돌아간다. 쓰러져 있을 때 · 이미 마을일 때는 쓰이지 않는다(주문서도 줄지 않는다)
	local goods = Items.goods(id)
	if goods and goods.kind == "scroll" then
		local h = s.hero
		local why = nil
		if not h.alive then
			return
		elseif Bag.count(h, goods.id) <= 0 then
			why = "가진 주문서가 없다"
		elseif s.scene == SCENES.start then
			why = "이미 마을이다"
		end
		if why then
			fire("ItemDone", player, { action = "use", ok = false, why = why })
			return
		end
		Bag.take(h, goods.id, 1)
		s.skill = nil
		World.jump(player, SCENES.start)
		sendBag(s)
		sendParty(Party.members(book, player.UserId)) -- 파티원이 어느 맵에 있는지 바뀌었다
		return
	end
	local healed, why = Hero.drink(s.hero, id)
	if healed then
		sendBag(s)
	elseif why then
		fire("ItemDone", player, { action = "use", ok = false, why = why })
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
		saveSoon(s)
	end
end

-- 소리 설정을 바꿨다(메뉴 → 「소리 설정」): 계정에 적고 곧 저장한다 — 캐릭터 고르기 화면에 있을 때도 받는다
local function onSound(player, sound)
	local s = sessions[player]
	if s and s.acct and Account.setSound(s.acct, sound) then
		saveSoon(s)
	end
end

-- 퀵슬롯을 바꿨다(칸들 전체를 보낸다 — 꼴과 놓아도 되는 스킬인지는 Hero.setSlots가 본다). 서버가 가진 칸들을 돌려준다 — 말이 안 되는 것을 보냈으면 예전 것이 돌아가 화면이 되돌아간다
local function onSlots(player, list)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	if Hero.setSlots(s.hero, list) then
		saveSoon(s)
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
		saveSoon(s)
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

-- 전직하며 받은 공짜 초기화: 찍은 스킬을 모두 되돌린다(쓰러져 있거나 기술을 쓰는 중에는 안 된다)
local function onSkillReset(player)
	local s = sessions[player]
	if s and s.hero and s.hero.alive and not s.skill and Hero.freeReset(s.hero) then
		s.dirty = true
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
		elseif def.kind ~= "job" and SCENES.scenes[s.scene].region ~= def.region then
			why = "여기서는 받을 수 없는 퀘스트다" -- 주민은 제가 선 지역의 퀘스트만 준다(전직 퀘스트는 사제가 어디서든 준다)
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
	elseif action == "use" then
		-- 맵에 놓인 것 앞에서 ↑를 눌렀다(샘에서 물을 뜬다 · 깃발을 꺼낸다): 그 자리 가까이에 서 있어야 한다
		ok, why = Quests.use(h.quests, id, s.scene, h.x, h.y)
	elseif action == "drop" then
		ok, why = Hero.questDrop(h, id) -- 모으던 물건도 가방에서 사라진다
	else
		why = "모르는 일이다"
	end
	if ok then
		s.dirty = true
		fire("Quests", player, Quests.view(h.quests), done)
		sendBag(s) -- 돌려준 물건이 빠지고 보상의 물약이 들어왔다
	else
		fire("ItemDone", player, { action = "quest", ok = false, why = why })
	end
end

-- 일일 의뢰: 보기(어디서든 — 알리미와 게시판 위의 표시가 쓴다) · 받기 · 내기(그 게시판 앞에 서 있어야 한다).
--  사용자 2026-10-13: "게시판이랑 상호작용해서 일퀘받는거 좋습니다". 돌려주는 것 { ok, why, reward, view }
local function onDaily(player, action: string, region: any, i: any)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	local h, now = s.hero, os.time()
	local function reply(ok: boolean?, why: string?, reward: any)
		local view, fresh = Daily.view(h, now)
		if ok or fresh then
			s.dirty = true -- 받았다 · 냈다 · 날이 바뀌어 새 의뢰를 뽑았다
		end
		return { ok = ok == true, why = why, reward = reward, view = view }
	end
	if action == "view" then
		return reply(true, nil, nil)
	end
	local board = if typeof(region) == "string" then Daily.DATA.boards[region] else nil
	if not board or (action ~= "accept" and action ~= "turn") then
		return reply(nil, "모르는 일이다", nil)
	elseif not h.alive or s.scene ~= board.scene or not nearNpcId(s, board.npc) then
		return reply(nil, Daily.WORDS.far, nil)
	elseif h.level < Daily.FROM then
		return reply(nil, Daily.WORDS.early, nil)
	end
	if action == "accept" then
		local ok, why = Daily.accept(h, region, i, now)
		return reply(ok, why, nil)
	end
	local reward, why = Daily.turnIn(h, region, i, now)
	if not reward then
		return reply(nil, why, nil)
	end
	local ups = Hero.gainXp(h, reward.xp)
	fire("Gain", player, { xp = reward.xp, ups = ups, level = h.level })
	if ups > 0 then
		fire("Quests", player, Quests.view(h.quests)) -- 레벨이 되어 받을 수 있게 된 퀘스트
		sendWho(s.scene)
	end
	sendSelf(s) -- 달돈 · 레벨
	sendBag(s) -- 달가루(덤)
	return reply(true, nil, reward)
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
	local player = { UserId = -botN, Name = "Bot" .. botN }
	bots[player] = true
	local s = { player = player, hero = Hero.new(player.UserId, class), scene = scene, skill = nil, jumped = true, loaded = true, dirty = false, name = "달그림자" .. botN, botHome = x, botDir = 1, botSkill = World.now + 2 }
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

-- 그 장면의 시작 자리로 곧장 옮긴다(확인용 명령 goto · 자동 검사가 쓴다 — 서버 안에서만 부른다). 마을로 돌아갈 때와 같은 길(Revive)로 화면을 바꾼다
function World.jump(player, key: string): boolean
	local s = sessions[player]
	local scene = SCENES.scenes[key]
	if not s or not s.hero or not scene then
		return false
	end
	local from = s.scene
	place(s, key, scene.spawn.x, scene.spawn.y, true)
	local room = roomOf(s.scene):describe(s.hero.id)
	room.who = roster(s.scene)
	fire("Revive", player, { scene = s.scene, x = s.hero.x, y = s.hero.y, room = room })
	sendSelf(s)
	sendWho(from)
	sendWho(s.scene)
	return true
end

-- ---------- 관리자(어드민)의 시험용 명령 ----------
--  사용자 2026-10-11: "저만 쓸수있는 어드민용 탭 … 경험치 배율증가, 레벨 조정, 아이템발급 등등 … 누군가 해킹같은거해서 사용도 못해야하고 오직 어드민만 사용할수있어야합니다."
--  올 때마다 보낸 사람의 계정 번호로 관리자인지 다시 가린다(admin.luau). 관리자가 아니면 아무 일도 하지 않고 nil — 무엇이 있는지도 알려 주지 않는다.
--  값은 모두 여기서 범위와 꼴을 다시 본다(클라이언트가 보낸 값을 믿지 않는다). 돌려주는 것: { ok, msg }
local ADMIN_XP = { [1] = true, [2] = true, [5] = true, [10] = true, [50] = true, [100] = true }
local ADMIN_DMG = { [1] = true, [5] = true, [20] = true, [100] = true }
local function wholeIn(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == v and v == math.floor(v) and v >= lo and v <= hi
end
local function onAdmin(player, what: string, a: any, b: any, c: any)
	if not Admin.is(player) then
		return nil
	end
	local s = sessions[player]
	if not s or not s.hero then
		return { ok = false, msg = "캐릭터로 들어온 뒤에 쓴다" }
	end
	local h = s.hero
	local function done(msg: string)
		sendSelf(s)
		return { ok = true, msg = msg }
	end
	local function no(msg: string)
		return { ok = false, msg = msg }
	end
	if what == "xp" then
		if not ADMIN_XP[a] then
			return no("없는 배율이다")
		end
		h.xpBoost = if a == 1 then nil else a
		return done(("경험치 x%d"):format(a))
	elseif what == "dmg" then
		if not ADMIN_DMG[a] then
			return no("없는 배율이다")
		end
		h.dmgBoost = if a == 1 then nil else a
		return done(("피해 x%d"):format(a))
	elseif what == "god" then
		h.god = a == true or nil
		return done(if h.god then "무적을 켰다" else "무적을 껐다")
	elseif what == "heal" then
		local wasDown = not h.alive
		if wasDown then
			Hero.revive(h)
		end
		h.hp = h.maxHp
		if wasDown then
			-- 쓰러져 있었다: 화면도 일으킨다(소생을 받았을 때와 같은 알림 — 이것이 없으면 화면은 쓰러진 채 남아 움직이지도 문을 지나지도 못한다)
			fire("Raise", player, { hp = h.hp })
			sendWho(s.scene)
			sendParty(Party.members(book, player.UserId))
		end
		return done(if wasDown then "일으키고 체력을 채웠다" else "체력을 채웠다")
	elseif what == "level" then
		if not wholeIn(a, 1, N.MAX_LEVEL) then
			return no(("레벨은 1~%d"):format(N.MAX_LEVEL))
		end
		Hero.setLevel(h, a)
		fire("Quests", player, Quests.view(h.quests))
		sendWho(s.scene)
		return done(("Lv.%d · %d차(능력치 · 스킬은 다시 찍는다)"):format(h.level, h.job))
	elseif what == "job" then
		if not wholeIn(a, 1, #CLASSES.jobs) then
			return no("없는 차수다")
		elseif h.level < CLASSES.jobs[a].lv then
			return no(("%d차는 Lv.%d부터 — 레벨을 먼저 올린다"):format(a, CLASSES.jobs[a].lv))
		end
		Hero.setLevel(h, h.level, a)
		fire("Quests", player, Quests.view(h.quests))
		sendWho(s.scene)
		return done(("%d차(스킬은 다시 찍는다)"):format(h.job))
	elseif what == "skills" then
		if a == "max" then
			Hero.maxSkills(h)
			return done("열린 차수의 스킬을 모두 마스터했다")
		elseif a == "reset" then
			Hero.resetSkills(h)
			return done("스킬을 되돌렸다(포인트를 다시 쓴다)")
		end
		return no("모르는 일이다")
	elseif what == "stats" then
		if a ~= "reset" then
			return no("모르는 일이다")
		end
		Hero.resetStats(h)
		return done("능력치를 되돌렸다(점수를 다시 찍는다)")
	elseif what == "money" then
		if not wholeIn(a, 1, 100000000) then
			return no("달돈은 1~1억")
		end
		h.money = math.min(h.money + a, 2000000000)
		return done(("달돈 +%d"):format(a))
	elseif what == "dust" then
		if not wholeIn(a, 1, 1000000) then
			return no("달가루는 1~100만")
		end
		h.dust = math.min(h.dust + a, 100000000)
		sendBag(s)
		return done(("달가루 +%d"):format(a))
	elseif what == "gear" then
		-- 그 단계의 장비 한 벌(무기 + 방어구 넷 — 내 직업의 것): a = 단계 · b = 성능(1 낡은 ~ 5 빼어난) · c = 별
		if typeof(a) ~= "number" or not table.find(Items.data.STAGES, a) then
			return no("없는 단계다")
		elseif not wholeIn(b, 1, #Items.data.QUALITY) then
			return no("없는 성능이다")
		elseif not wholeIn(c, 0, Items.starCap(a)) then
			return no(("그 단계의 별은 0~%d"):format(Items.starCap(a)))
		elseif Bag.free(h) < #Items.data.GEAR then
			return no(("가방의 장비 칸이 %d칸 비어 있어야 한다"):format(#Items.data.GEAR))
		end
		for _, slot in Items.data.GEAR do
			local it = Items.make(slot, a, b, h.class)
			it.star = c
			Bag.add(h, it)
		end
		sendBag(s)
		return done(("Lv.%d 장비 한 벌(%s · 별 %d)"):format(a, Items.data.QUALITY[b].name, c))
	elseif what == "goods" then
		-- 소비 · 기타 아이템: a = 그 아이템의 이름표 · b = 수
		local goods = if typeof(a) == "string" then Items.goods(a) else nil
		if not goods then
			return no("없는 아이템이다")
		elseif not wholeIn(b, 1, 999) then
			return no("수는 1~999")
		end
		local ok, why = Bag.give(h, goods.id, b)
		if not ok then
			return no(why or "가방에 넣지 못했다")
		end
		Hero.syncQuests(h)
		fire("Quests", player, Quests.view(h.quests))
		sendBag(s)
		return done(("%s +%d"):format(goods.name, b))
	elseif what == "quests" then
		-- to = 그 메인 퀘스트를 받은 것으로 한다(그 앞의 메인들은 끝낸 것으로 · 레벨이 모자라면 그 레벨로) — 스토리 보스처럼 이야기의 뒤쪽을 바로 해 볼 때(예: quests to r1m7)
		if a == "to" then
			local def = Quests.def(b)
			if not def or def.kind ~= "main" then
				return no("메인 퀘스트의 이름표를 적는다(예: r1m7)")
			end
			if h.level < def.lv then
				Hero.setLevel(h, def.lv)
			end
			local cur = def
			while cur and cur.after do
				h.quests[cur.after] = { done = true, c = {} }
				cur = Quests.def(cur.after)
			end
			h.quests[def.id] = { done = false, c = {} }
			s.dirty = true
			Hero.syncQuests(h)
			fire("Quests", player, Quests.view(h.quests))
			sendWho(s.scene)
			return done(("「%s」을 받은 것으로 했다(앞의 메인은 끝낸 것으로)"):format(def.name))
		end
		-- 하는 중인 퀘스트의 할 일을 모두 채운다(잡기 · 살펴보기는 숫자를, 모으기는 그 물건을)
		if a ~= "fill" then
			return no("모르는 일이다")
		end
		local n = 0
		for _, id in Quests.active(h.quests) do
			local def, st = Quests.def(id), h.quests[id]
			for i, step in def.steps do
				if (st.c[i] or 0) < step.n then
					if step.type == "gather" and step.item then
						Bag.give(h, step.item, step.n - Bag.count(h, step.item))
					else
						st.c[i] = step.n
					end
					n += 1
				end
			end
		end
		Hero.syncQuests(h)
		fire("Quests", player, Quests.view(h.quests))
		sendBag(s)
		return done(("할 일 %d개를 채웠다 — 돌려주러 간다"):format(n))
	elseif what == "goto" then
		if typeof(a) ~= "string" or not SCENES.scenes[a] then
			return no("없는 맵이다")
		elseif not h.alive then
			return no("쓰러져 있다 — 먼저 체력을 채운다")
		end
		s.skill = nil
		World.jump(player, a)
		sendParty(Party.members(book, player.UserId))
		return { ok = true, msg = ("%s(으)로 옮겼다"):format(SCENES.scenes[a].name) }
	end
	return no("모르는 일이다")
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
		if ups > 0 then
			fire("Quests", player, Quests.view(hero.quests))
		end
	elseif what == "money" then
		hero.money += math.max(0, math.floor(n))
	elseif what == "hp" then
		hero.hp = math.clamp(math.floor(n), 1, hero.maxHp)
	elseif what == "dust" then
		hero.dust += math.max(0, math.floor(n))
		fire("Bag", player, Bag.view(hero))
	elseif what == "potion" then
		-- 확인용: 물약을 단마다 n병씩 가방에 넣는다(소비 탭 · 상세 판 · 퀵슬롯을 본다)
		for _, g in Items.data.GOODS do
			if g.kind == "potion" then
				Bag.give(hero, g.id, math.clamp(math.floor(n), 1, 999))
			end
		end
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
		-- 확인용: 발 앞에 퀘스트의 물건들을 하나씩 떨어뜨린다(그림과 줍기를 본다 — 주우면 가방의 기타 탭에 들어간다. 받지 않은 퀘스트의 것은 숫자가 오르지 않는다)
		local room = roomOf(s.scene)
		local i = 0
		for _, def in Quests.list do
			for k, step in def.steps do
				if step.type == "gather" then
					i += 1
					local d = room:addDrop({ kind = "quest", amount = 1, quest = def.id, step = k, name = step.name, icon = step.icon, goods = step.item }, hero.x + 10 + i * 16, hero.y, hero.id)
					fire("DropAdd", player, Room.dropView(d))
				end
			end
		end
	elseif what == "mats" then
		-- 확인용: 재료(광석 · 가죽)를 종류마다 n개씩, 귀환 주문서를 한 장 가방에 넣는다(제작 창과 귀환을 빨리 본다)
		for _, m in Items.data.MATS do
			Bag.give(hero, m.id, math.min(math.max(1, math.floor(n)), Bag.room(hero, m.id)))
		end
		Bag.give(hero, "scroll_return", 1)
		sendBag(s)
		return
	elseif what == "qitem" then
		-- 확인용: 하는 중인 퀘스트가 모으는 물건을 n개씩 가방에 넣는다(모으는 퀘스트 · 전직 퀘스트를 돌려주는 데까지 빨리 본다)
		for id, st in hero.quests do
			local def = Quests.def(id)
			if def and not st.done then
				for _, step in def.steps do
					if step.type == "gather" and step.item then
						Bag.give(hero, step.item, math.min(math.max(1, math.floor(n)), Bag.room(hero, step.item)))
					end
				end
			end
		end
		sendBag(s)
		return
	elseif what == "gear" then
		-- 확인용: 그 단계의 장비 다섯 부위를 가방에 넣는다(성능은 차례로)
		for i, slot in Items.data.GEAR do
			Bag.add(hero, Items.make(slot, math.max(1, math.floor(n)), ((i - 1) % #Items.data.QUALITY) + 1, hero.class))
		end
		fire("Bag", player, Bag.view(hero))
	elseif what == "tough" then
		-- 확인용: 이 방의 졸개들의 체력을 n배로 늘린다(쓰러지지 않고 오래 맞는다 — 사출기 · 장치가 나가는 것을 본다. 체력 띠는 방에 다시 들어와야 맞는다)
		for _, mob in roomOf(s.scene).mobs do
			mob.maxHp = math.floor(mob.maxHp * math.clamp(n, 1, 1000))
			mob.hp = mob.maxHp
		end
		return
	elseif what == "portal" then
		-- 확인용: 이 장면의 n째 문 앞으로 옮긴다(새 맵을 걸어 들어가 볼 때 — 그 자리에서 ↑를 누르면 문을 지난다). 화면도 그 자리로 맞춘다
		local p = SCENES.scenes[s.scene].portals[math.floor(n)]
		if p then
			place(s, s.scene, p.x, p.y)
			fire("Warp", player, p.x, p.y)
		end
		return
	elseif what == "npc" then
		-- 확인용: 이 장면의 n째 주민 앞(8점 옆)으로 옮긴다 — 그 자리에서 ↑를 누르면 말을 건다. 화면도 그 자리로 맞춘다
		local npc = (SCENES.scenes[s.scene].npcs or {})[math.floor(n)]
		if npc then
			place(s, s.scene, npc.x + 8, npc.y)
			fire("Warp", player, npc.x + 8, npc.y)
		end
		return
	elseif what == "spot" then
		-- 확인용: 이 장면의 n째 퀘스트의 자리(맵에 놓인 것 앞에서 ↑를 누르는 일 — 샘 · 깃발) 앞(12점 옆)으로 옮긴다. 화면도 그 자리로 맞춘다
		local spot = Quests.spotsIn(hero.quests, s.scene)[math.floor(n)]
		if spot then
			place(s, s.scene, spot.x - 12, spot.y)
			fire("Warp", player, spot.x - 12, spot.y)
		end
		return
	elseif what == "mob" then
		-- 확인용: 이 장면의 n째 졸개 곁(같은 층 · 그 졸개의 구간 안 · 20점 옆)으로 옮긴다 — 층이 많은 맵(망루)에서 그 몬스터가 치는 것을 볼 때. 화면도 그 자리로 맞춘다
		local m = roomOf(s.scene).mobs[math.floor(n)]
		if m then
			local x = math.clamp(m.x + 20, m.a, m.b)
			place(s, s.scene, x, m.y)
			fire("Warp", player, x, m.y)
		end
		return
	elseif what == "goto" then
		-- 확인용: 그 장면의 시작 자리로 곧장 옮긴다 — 문을 하나씩 지나지 않고 먼 맵을 본다. 마을로 돌아갈 때와 같은 길(Revive)로 화면을 바꾼다.
		--  n = 장면의 이름표를 가나다(ABC) 차례로 늘어놓았을 때의 번호(확인용 명령은 숫자만 받는다)
		local keys = {}
		for k in SCENES.scenes do
			table.insert(keys, k)
		end
		table.sort(keys)
		local key = keys[math.floor(n)]
		if key then
			World.jump(player, key)
		end
		return
	elseif what == "reset" then
		-- 세계에서 나와 캐릭터 고르기 화면의 상태로 돌아간다(저장하고 나온다 — 계정도 캐릭터도 지우지 않는다. 캐릭터를 지우는 것은 고르기 화면의 삭제뿐이다)
		if not s.acct then
			return -- 확인용 임시 캐릭터에게는 고르기 화면이 없다
		end
		leaveWorld(s)
		markName(s)
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
		-- 버프: 시간이 다 되면 사라진다(끝났을 때 알린다)
		if s.hero then
			local ended = Buffs.tick(s.hero, dt)
			if #ended > 0 then
				-- 꺼지지 않는 불(살라맨더 4차): 폭주가 끝나도 열기가 남는다
				if table.find(ended, "sl_overheat") and s.hero.pass then
					local keep = Passives.get(s.hero, "keep")
					if keep then
						s.hero.kit.heat = math.max(s.hero.kit.heat, keep.keep)
						s.hero.kit.heatT = 0
					end
					s.hero.pass.extended = 0
				end
				sendSelf(s)
				sendBuffs(s)
			end
		end
		-- 장치: 영혼이 흩어지고 열기가 식고 체력이 찬다(바뀌었을 때만 알린다)
		if s.hero and s.hero.alive then
			local changed, healed = Kit.tick(s.hero, dt)
			if changed or healed > 0 then
				sendSelf(s)
			end
		end
		if s.hero then
			Hero.tick(s.hero, dt) -- 쓰러진 사람은 저절로 일어나지 않는다(마을로 돌아갈지 묻는다 — onReturn)
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
					toRoom(key, "Shot", { id = e.id, x = e.x, y = e.y, dir = e.dir, speed = e.speed, range = e.range, kind = e.kind })
				elseif e.type == "cast" then
					toRoom(key, "MobCast", { id = e.id, kind = e.kind, x = e.x, y = e.y, dir = e.dir })
				elseif e.type == "shotEnd" then
					toRoom(key, "ShotEnd", e.id)
				elseif e.type == "dropGone" then
					toRoom(key, "DropGone", e.id, nil, 0)
				elseif e.type == "crystalGone" then
					toRoom(key, "Crystal", { add = {}, gone = { e.id } })
				elseif e.type == "self" then
					-- 그 사람의 장치의 모습이 바뀌었다(화로 곁에서 오른 열기)
					local hs = byId[e.hero]
					if hs then
						sendSelf(hs)
					end
				elseif e.type == "kit" then
					-- 조금 뒤에 들어간 타(붙는 불)
					local hs = byId[e.hero]
					if hs then
						applyResult(hs, key, e.result)
					end
				elseif e.type == "raised" then
					-- 소생을 받아 그 자리에서 일어났다
					local hs = byId[e.hero]
					if hs then
						fire("Raise", hs.player, { hp = hs.hero.hp })
						sendSelf(hs)
						sendParty(Party.members(book, hs.hero.id))
					end
				elseif e.type == "healed" then
					-- 누군가의 회복 스킬로 체력이 찼다
					local hs = byId[e.hero]
					if hs then
						sendSelf(hs)
						fire("Healed", hs.player, e.amount)
					end
				elseif e.type == "buffs" then
					-- 스킬이 버프를 걸거나 거뒀다
					local hs = byId[e.hero]
					if hs then
						sendSelf(hs)
						sendBuffs(hs)
					end
				elseif e.type == "cool" then
					local hs = byId[e.hero]
					if hs then
						fire("Cool", hs.player, e.skill, 0)
					end
				elseif e.type == "ward" then
					-- 죽음의 가호가 쓰러질 피해를 버텼다: 그 버프가 사라졌다
					local hs = byUser[e.hero]
					if hs then
						sendSelf(hs)
						sendBuffs(hs)
					end
				elseif e.type == "dodge" then
					local s = byId[e.hero]
					if s then
						fire("Dodge", s.player)
					end
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
		elseif room.bosses then
			room:idle() -- 아무도 없는 방: 서 있던 스토리 보스를 치운다(다시 들어오면 체력이 가득한 채 새로 선다)
		end
	end
end

function World.start()
	Net.OnServer("Ready", onReady)
	Net.OnServer("Move", onMove)
	Net.OnServer("Travel", onTravel)
	Net.OnServer("Skill", onSkill)
	Net.OnServer("Return", onReturn)
	Net.OnServer("Pickup", onPickup)
	Net.OnServer("Potion", onPotion)
	Net.OnServer("Chars", onChars)
	Net.OnServer("Rank", onRank)
	Net.OnServer("Debug", onDebug)
	Net.OnServer("Admin", onAdmin)
	Net.OnServer("Keys", onKeys)
	Net.OnServer("Sound", onSound)
	Net.OnServer("Daily", onDaily)
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
	Net.OnServer("SkillReset", onSkillReset)
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
		World.saveDue()
	end)
end

-- 곧 저장하기로 한 것(saveSoon — 키 설정 · 퀵슬롯)의 때가 됐으면 저장한다
function World.saveDue()
	local now = os.clock()
	for _, s in sessions do
		if s.soon and now >= s.soon then
			s.soon = nil
			if s.hero and s.loaded and not s.guest and s.dirty then
				task.spawn(saveAccount, s)
			end
		end
	end
end

function World.stop()
	World.saveAll(false)
	-- 나가는 사람의 저장(World.removePlayer — 그 사람은 이미 sessions에서 빠져 위의 saveAll이 보지 못한다)이 아직 쓰이는 중이면 끝날 때까지 기다린다(길어도 STOP_WAIT초).
	--  혼자 하다가 나가면 서버가 곧바로 닫힌다 — 기다리지 않으면 마지막에 바꾼 것(키 설정처럼 방금 바꾼 것)이 저장되지 못한 채 서버가 닫힐 수 있다
	local waited = 0
	while saving > 0 and waited < STOP_WAIT do
		waited += task.wait(0.1) or 0.1
	end
	-- 서버가 닫힌다: 저장한 뒤에 잡고 있던 계정을 모두 푼다
	for _, s in sessions do
		if s.held and Store.unlock then
			Store.unlock(s.player.UserId)
		end
	end
end

return World
