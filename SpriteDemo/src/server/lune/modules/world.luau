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
local Caster = require(lune.sim.caster) -- 몸을 옮기는 스킬의 목록(Caster.MOVERS — onMove)
local Bag = require(lune.sim.bag)
local Items = require(lune.sim.items)
local Party = require(lune.sim.party)
local Quests = require(lune.sim.quests)
local Daily = require(lune.sim.daily) -- 일일 의뢰(마을의 게시판)
local Tutorial = require(lune.sim.tutorial) -- 튜토리얼 「달빛 꿈」(2026-10-14)
local Cine = require(lune.cine) -- 퀘스트 연출(2026-10-15): 본 장면의 id를 거른다
local Market = require(lune.sim.market) -- 경매장의 셈(장부를 바꾸는 법 · 맡긴 것과 견주는 법)
local Format = require(lune.ui.format) -- 글 속의 {이름}을 채운다(경매장의 알림)
local Kit = require(lune.sim.kit)
local Buffs = require(lune.sim.buffs)
local Quick = require(lune.ui.quick) -- 스마트폰의 단추 배치(단추가 없는 칸의 것을 옮긴다)
local Passives = require(lune.sim.passives) -- 2~4차의 패시브(충격파 · 넘치는 힘 · 꺼지지 않는 불은 여기서 때를 본다)
local CLASSES = require(lune.data["classes.generated"])
local Store = require(script.Parent.store)
local Cash = require(lune.sim.cash) -- 유료 상품의 셈(구매 보관함 · 결제 번호 · 주간 수 — 2026-10-20)
local Town = require(lune.sim.town) -- 마을인가(달빛 상점 · 경매장은 마을에서만 — 2026-10-21)
local SHOPSPACE = require(lune.data["bm.generated"]).shop.space -- 달빛 상점의 공간(글 · 키)
local CashServer = require(script.Parent.cash) -- 로블록스 결제(ProcessReceipt · 구매 창 · 게임 패스)
local Admin = require(script.Parent.admin) -- 누가 관리자인가(서버에만 있다)
local Analytics = require(script.Parent.analytics) -- 플레이어 데이터 기록(로블록스 분석 — 2026-10-15)
local Attend = require(lune.sim.attend) -- 출석(계정에 하루 한 칸 — 2026-10-15)
local Achieve = require(lune.sim.achieve) -- 업적(계정이 같이 쌓는다 — 2026-10-15)
local Rift = require(lune.sim.rift) -- 수정 틈 토벌(은달 항구의 반복 던전 — 2026-10-16)
local Voyage = require(lune.sim.voyage) -- 배(초승달 마을 ↔ 은달 항구 — 선장에게 말을 건다 · 2026-10-16)
local Bond = require(lune.sim.bond) -- 2편의 호감도 · 모험의 서 · 달조각 · 숨은 이야기(캐릭터마다 — 2026-10-16)

local TICK = 1 / 20
local SNAP_EVERY = 2 -- 걸음 몇 번에 한 번 졸개의 모습을 보낸다(초당 10번)
local MOVE_SLACK = 90 -- 한 번의 보고에서 이보다 멀리 가 있으면 믿지 않는다(도트)
-- 시간에 따른 몫(2026-10-18 검토): 보고마다 MOVE_SLACK까지 받으면 연달아 보내 순식간에 맵 끝까지 갔다(1초에 1,800점쯤) — 가로로는 1초에 MOVE_RATE점씩 차고
--  MOVE_CAP점까지 모이는 몫 안에서만 받는다. 달리기 92점/초 · 버프 · 1차 대쉬(짧게 200~520점/초)가 넉넉히 들어간다. 맵을 옮긴 직후의 첫 보고는 JUMP_SLACK 안에서만
local MOVE_RATE, MOVE_CAP, JUMP_SLACK = 300, 180, 360
-- 위로 가는 몫(2026-10-18 검토: 세로는 보고마다 180점까지만 보아 연달아 보내면 날았다) — 1초에 UP_RATE점씩 차고 UP_CAP점까지.
--  뛰기 57점 + 공중 뛰기 41점(0.8초쯤) · 사다리 1초에 80점 · 도약 49점이 넉넉히 든다. 떨어지는 것(아래로)은 세지 않는다
local UP_RATE, UP_CAP = 240, 160
-- 그 자리 가까이(MOVE_SLACK 안)에 맵의 바닥이 뚫린 칸이 있는가 — 거기서만 맵 아래로 떨어질 수 있다(onMove의 시작 자리 받기)
local function holeNear(scene, x: number): boolean
	local bottom = scene.h - 1
	for tx = math.floor((x - MOVE_SLACK) / G.TILE), math.floor((x + MOVE_SLACK) / G.TILE) do
		if tx >= 0 and tx < scene.w and string.sub(scene.rows[bottom + 1], tx + 1, tx + 1) ~= "#" then
			return true
		end
	end
	return false
end
-- 장면을 옮긴 뒤 화면이 열릴 때까지(화면은 막을 치고 새 장면의 그림을 불러온다 — client/lune/curtain.luau):
--  LOAD_GUARD = 그동안 피해를 받지 않는 가장 긴 시간(초). 화면이 열려 첫 자리 보고나 첫 기술이 오면 거기서부터 보통의 들어선 뒤 보호(RULES.arrive)로 바뀐다
--  LOAD_STALE = 서버가 먼저 옮긴 뒤(마을로 돌아가기 · 관리 이동) 이 시간(초) 안에 온, 옮겨 놓은 자리에서 먼 자리 보고는 옮겨지기 전에 떠난 늦은 보고로 보고 받지 않는다(옛 장면의 자리를 새 장면의 자리로 믿지 않는다)
local LOAD_GUARD, LOAD_STALE = 12, 2
local WARP_SLACK, WARP_TIME = 280, 1.5 -- 2~4차의 스킬을 쓴 직후(초)에는 이만큼(도트) 멀리 간 자리도 받는다 — 순간이동하는 스킬(연막 순보 · 급습 · 연쇄 순보 …)과 길게 내달리는 스킬
local SAVE_EVERY = 60 -- 바뀐 캐릭터를 이 간격(초)으로 저장한다
local STOP_WAIT = 20 -- 서버가 닫힐 때 쓰고 있는 저장을 기다리는 시간의 위(초 — 로블록스가 닫히는 서버에 주는 30초 안)
-- 같은 계정이 다른 서버에서 하는 중일 때(modules/store.luau의 잠금): 이만큼 다시 물어 보고(서버를 옮겨 올 때 앞 서버가 저장을 끝내고 잠금을 푼다) 끝내 안 풀리면 내보낸다
-- 계정을 잡을 때 기다리는 수 · 사이(초) — 1.5초 x 24번 = 36초.
--  2026-10-21 퍼블리시한 게임의 오류 보고: 게임을 고쳐 올린 때(서버들이 닫히며 사람들을 새 서버로 옮김) 「계정을 다른 서버가 잡고 있다 — 내보낸다」가 열 명 넘게.
--  닫히는 서버는 Roblox가 주는 30초 안에 모두를 저장하고 잠금을 푸는데(World.stop), 전에는 새 서버가 7.5초(1.5초 x 6번)만 기다리고 내보냈다 → 30초보다 길게 기다린다
--  (화면은 서버가 답할 때까지 2초마다 다시 묻는다 — 60초까지: client boot의 Ready)
local LOCK_TRIES, LOCK_WAIT = 24, 1.5
-- (내보내는 글은 로블록스의 창이 띄운다 — 우리 글꼴 · 영문 바꾸기를 거치지 않아 두 말로 함께 적는다: 2026-10-27 영문)
local LOCK_KICK = "이 계정은 다른 서버에서 하는 중입니다. 잠시 뒤에 다시 들어와 주세요. / This account is playing on another server. Please rejoin in a moment."
local LOAD_KICK = "저장소가 지금 답하지 않습니다. 잠시 뒤에 다시 들어와 주세요. / Save data is not responding right now. Please rejoin in a moment." -- 계정을 읽지 못했다(2026-10-18 검토: 빈 계정으로 들여보내면 저장된 것을 덮어썼다)
local function holdAccount(userId: number): boolean
	return Store.lock == nil or Store.lock(userId) == true
end
local function kick(player, text: string)
	pcall(function()
		player:Kick(text)
	end)
end

local World = {}
-- 이동 몫을 지금까지의 시간만큼 채운다(onMove · skillPlace)
--  흐른 시간 = 서버 시계(World.now)와 실제 시계(os.clock) 가운데 긴 것: 서버가 잠깐 멈추면 World.now는 0.25초까지만 흐르게 되어 있어(Heartbeat의 acc),
--  그동안 정상으로 걸은 거리도 몫을 넘어 되돌려질 수 있었다(2026-10-18 검토 — 자동 검사는 World.now만 흘린다)
local function refillMove(s)
	local clock = os.clock()
	local dt = math.max(0, World.now - (s.moveAt or World.now), clock - (s.moveClock or clock))
	s.moveBudget = math.min(MOVE_CAP, (s.moveBudget or MOVE_CAP) + dt * MOVE_RATE)
	s.upBudget = math.min(UP_CAP, (s.upBudget or UP_CAP) + dt * UP_RATE)
	s.moveAt, s.moveClock = World.now, clock
end
-- 기술을 쓴 자리: 화면이 말한 자리가 서버가 아는 자리 곁(가로 40 · 세로 60)이면 받아 적는다 — 이동 몫에서 뺀다(2026-10-18 검토:
--  몫 밖이라, 받아 주지 않을 기술 요청을 연달아 보내 1초에 300점 넘게 옆으로 · 480점 위아래로 갔다)
local function skillPlace(s, x: number, y: number)
	local hero = s.hero
	local dx = math.abs(x - hero.x)
	if dx > 40 or math.abs(y - hero.y) > 60 then
		return
	end
	refillMove(s)
	local up = math.max(0, hero.y - y)
	if dx <= s.moveBudget and up <= s.upBudget then
		s.moveBudget -= dx
		s.upBudget -= up
		hero.x, hero.y = x, y
	end
end
World.now = 0

local sessions = {} -- [Player] = { player, hero, scene, skill = { id, seg, at }, moved }
local leaving = {} -- [UserId] = true — 나가며 저장하는 중(World.removePlayer · addPlayer가 기다린다)
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
		-- 방이 스스로 치는 것(독 · 소환 · 장판)도 그 순간의 같은 맵 파티원과 경험치 · 퀘스트를 나눈다(2026-10-18 검토 — 전에는 쓴 사람 혼자)
		room.matesOf = function(h)
			return World.matesIn(key, h)
		end
		room.alliesOf = function(h) -- 치유 · 수호령이 닿는 같은 맵의 파티원 모두(레벨 차이를 보지 않는다 — 2026-10-24)
			return World.alliesIn(key, h)
		end
		rooms[key] = room
	end
	return room
end

-- 그 방에 있는 사람들. 달빛 상점에 들어가 있는 사람(s.shop)은 빠진다(2026-10-21 사용자 "메이플스토리 캐시샵처럼 아예 무적공간으로 들어가버리는 형태"):
--  다른 사람의 이름표에서 사라지고 · 방이 돌 때 몬스터가 노리거나 때리지 못하고(room:step에 들지 않는다) · 방의 소식을 받지 않는다. 나오면 moveTo로 같은 자리에 다시 들어온다
local function inRoom(key: string)
	local list = {}
	for _, s in sessions do
		if s.hero and s.scene == key and not s.shop then
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
		-- pet = 꺼내 둔 펫 · ride = 탄 탈것(2026-10-20 — 다른 사람의 화면도 같이 그린다)
		local bm = s.acct and s.acct.bm
		table.insert(list, { id = s.hero.id, name = s.name, class = s.hero.class, level = s.hero.level, pet = bm and bm.petOut or false, ride = if s.riding and bm then bm.mount else false, look = s.hero.look, wskin = bm and bm.wskin or false, dskin = bm and bm.dskin or false, title = s.hero.title or false }) -- dskin = 장착한 데미지 스킨(2026-10-29 — 그 사람이 때린 숫자의 모습) -- look = 무기 · 로브 색(염색 — 2026-10-22) · wskin = 장착한 캐시 무기(2026-10-23) · title = 단 칭호(2026-10-26)
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
	view.tut = Tutorial.pack(s.hero.tut) -- 튜토리얼의 진행(꿈의 미션 판)
	view.tutSkip = s.acct ~= nil and s.acct.tutDone == true -- 「건너뛰기」를 보일까(이 계정이 한 번 끝냈다)
	view.haste = Buffs.haste(s.hero)
	view.chargeCut = Kit.chargeCut(s.hero) -- 힘이 모이는 시간을 줄이는 몫(액시온 「전투 호흡」 — 2026-10-28)
	local here = s.scene and rooms[s.scene] -- (방을 새로 짓지 않는다 — 옮기는 중이면 없다)
	view.surge = if here and s.hero.pass then math.max(0, s.hero.pass.surge - here.time) else 0 -- 넘치는 힘의 남은 초(화면이 2단계에서 모으기 시작한다 — 2026-10-28)
	view.titles, view.title = require(lune.sim.titles).owned(s.hero), s.hero.title or false -- 가진 칭호 · 단 칭호(능력치 창 · 내 이름표 — 2026-10-26)
	if s.acct then
		view.attReady = Attend.ready(s.acct.att) -- 받을 출석 칸 · 업적 보상의 수(「메뉴」 단추의 점 — 2026-10-15)
		view.achReady = Achieve.ready(s.acct.ach)
	end
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
-- 다시 들어올 때 시작할 장면(과 자리 — 없으면 그 장면의 시작 자리): 마지막으로 있던 맵 그대로. 다만 —
--  배 · 비행선의 갑판 = 그 탈것이 닿는 곳(내리는 자리) · 토벌의 방(rf1#번호) · 스토리 보스의 방 · 꿈 = 그 맵에서 가장 가까운 마을(ret)
--  · 없어진 장면(맵을 고쳐 지웠다) = 마지막으로 들른 마을 · 시작 마을. 마지막 맵이 없는 옛 저장 = 마지막으로 들른 마을
local voyageLanding: (any) -> (number, number)
local function resumeScene(h): (string, number?, number?)
	local key = h.last
	local home = if h.home and SCENES.homes[h.home] and rawget(SCENES.scenes, h.home) then h.home else SCENES.start
	if typeof(key) ~= "string" then
		return home, nil, nil
	end
	local base = string.match(key, "^(.-)#w?[nh]?%d+$") or key
	local sc = rawget(SCENES.scenes, base)
	if not sc then
		return home, nil, nil
	end
	local ride = Voyage.onShip(base)
	if ride then
		local x, y = voyageLanding(ride)
		return ride.to, x, y
	end
	if base ~= key or sc.rift or sc.inst or (sc.bosses and #sc.bosses > 0) or Tutorial.isDream(base) then
		return if sc.ret and rawget(SCENES.scenes, sc.ret) then sc.ret else home, nil, nil
	end
	return base, nil, nil
end

-- 파티마다 따로 들어가는 장면(scene.inst — 공방 export: 스토리 보스의 방 · 이야기의 방 · 꿈)에 들어갈 때의 방 이름.
--  사용자 2026-10-21: "파티마다 따로 되어야합니다 … 한서버에 100명 있으면 차례를 엄청나게 기다려야하는겁니다. 설계부터가 잘못됬어요 솔로게임처럼되어있습니다"
--  이미 그 장면의 방에 있으면 그 방 그대로 · 같은 파티의 누가 그 장면의 방에 있으면 그 방 · 아니면 새 방(<장면>#번호 — 수정 틈 토벌의 방과 같은 꼴). 사람이 없어진 방은 닫는다(World 고리)
local instSerial = 0
local function roomKeyFor(s, key: string): string
	local sc = rawget(SCENES.scenes, key)
	if not sc or not sc.inst then
		return key -- 여느 장면 · 이미 방의 이름(#번호)
	end
	if s.scene and s.scene ~= key and SCENES.base(s.scene) == key then
		return s.scene
	end
	-- 개인 연무장(inst "solo" — 2026-10-26 사용자: "개인연무장은 개인한명만 들어갈수있고 각각플레이어는 따로쓰는거야"): 파티원의 방으로도 들어가지 않는다 — 늘 새 방
	for _, uid in (if sc.inst == "solo" then {} else Party.members(book, s.player.UserId)) do
		local ms = byUser[uid]
		-- (주간 보스의 방 <방>#wn번호 · #wh번호에는 따라 들어가지 않는다 — 보스의 문에서 들어간 사람만: 2026-10-24)
		if ms and ms ~= s and ms.hero and ms.scene and ms.scene ~= key and SCENES.base(ms.scene) == key and not string.find(ms.scene, "#w", 1, true) then
			return ms.scene
		end
	end
	instSerial += 1
	return key .. "#" .. instSerial
end

-- 그 사람을 그 장면(방)의 (x, y)에 둔다. 파티마다 따로 들어가는 장면이면 그 파티의 방으로 — 부른 쪽은 옮긴 뒤 s.scene을 쓴다(넘긴 key와 다를 수 있다)
local function place(s, key: string, x: number, y: number, pushed: boolean?)
	key = roomKeyFor(s, key)
	if not Voyage.onShip(key) then
		s.voyage = nil -- 배에서 내렸다(닿았거나 · 귀환 주문서 · 쓰러져 돌아감)
	end
	-- 방마다 시계가 따로다: 캐릭터에 적힌 방의 시각을 새 방의 시계로(Hero.shiftClock — 2026-10-18 검토)
	local fromRoom = if s.scene then rooms[s.scene] else nil
	if fromRoom and s.scene ~= key then
		Hero.shiftClock(s.hero, roomOf(key).time - fromRoom.time)
		fromRoom:forget(s.hero) -- 떠난 방에 남은 늦은 타를 버린다(Room:forget)
	end
	s.scene = key
	require(script.Parent.macroGuard).onScene(s, key) -- 매크로 확인: 마을 · 실내에 들르면 쉼(2026-10-23)
	s.hero.x, s.hero.y = Room.physics.freeSpot(SCENES.scenes[key], x, y) -- 세우는 자리가 땅 속이면 가장 가까운 빈 자리로(화면도 같은 셈으로 꺼낸다 — 2026-10-21 폰에서 끼임)
	s.skill = nil
	s.hero.last = key -- 다시 들어오면 여기서 시작한다(resumeScene이 들어가면 안 되는 곳을 가린다)
	Hero.arrive(s.hero) -- 들어선 뒤 잠깐은 피해를 받지 않는다
	s.jumped = true -- 다음 자리 보고는 거리와 상관없이 받는다
	-- 화면은 이제 막을 치고 새 장면의 그림을 불러온다: 화면이 열릴 때까지(첫 자리 보고 · 첫 기술 — arrived) 피해를 받지 않는다
	-- 마을 · 작은 마을에 들렀다: 쓰러졌을 때 돌아오는 곳이 된다(빠른 이동은 없다 — 걸어서 다닌다)
	if SCENES.homes[key] and s.hero.home ~= key then
		s.hero.home = key
		s.dirty = true
	end
	if s.acct then
		Achieve.visited(s.acct.ach, key) -- 업적: 그 지역의 맵을 모두 들른다
	end
	-- 퀘스트의 「들르기」(2026-10-16 — 「항구의 첫날」처럼 도시를 둘러보는 퀘스트)
	if #Quests.onVisit(s.hero.quests, key) > 0 then
		s.dirty = true
		fire("Quests", s.player, Quests.view(s.hero.quests))
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
		-- 화면이 열렸다: 방 사람들과 버프의 모습(거신의 큰 몸 등)을 서로 알린다(2026-10-18 검토 — 버프는 바뀔 때만 보내, 새로 온 사람에게는 먼저 와 있던 사람의 버프가 보이지 않았다)
		if s.hero then
			sendBuffs(s)
			for _, other in inRoom(s.scene) do
				if other ~= s and other.hero then
					fire("Buffs", s.player, other.hero.id, Buffs.view(other.hero, World.now).list)
				end
			end
		end
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
	h.tut = Tutorial.finished() -- 꿈(튜토리얼)도 깬 것으로
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
	h.tslots = Quick.touchFix(h.tslots) -- 스마트폰에는 칸 1의 단추가 없다(2026-10-13) — 거기 놓인 것은 단추가 있는 빈 칸으로
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

-- 명예의 전당의 판(서버가 Rank.REFRESH초마다 한 번 읽어 둔 것 — 아래 rankBoards). pushRank가 관리자의 줄을 지우면 비운다
local rankCache, rankAt = nil, -math.huge
-- 명예의 전당: 지금 하는 캐릭터의 레벨 · 전투력을 순위판에 올린다(달라졌을 때만). 임시 계정의 것은 이 서버의 메모리에만 둔다(저장소에 쓰지 않는다)
local function pushRank(s)
	if not s.hero or not s.acct or not s.cid or s.name == "" then
		return
	end
	local h = s.hero
	local key = Rank.charKey(s.player.UserId, s.cid)
	-- 관리자 계정의 캐릭터는 명예의 전당에 올리지 않는다(2026-10-15 사용자: "명예의 전당집계에서 제 어드민 계정 캐릭터들은 올라가면안됩니다") — 이미 올라간 것은 지운다(한 번)
	if Admin.is(s.player) then
		if s.rankCleared ~= key then
			s.rankCleared = key
			Store.rankRemove("level", key)
			Store.rankRemove("power", key)
			Store.rankInfoRemove(key)
			rankCache = nil
		end
		return
	end
	local sent = s.rankSent or {}
	s.rankSent = sent
	local fixAt = Rank.MAX_FIX[key] -- 저장본에서 찾은 오른 때(2026-10-24 — sim/rank.luau)
	if h.level >= N.MAX_LEVEL and fixAt and (not h.maxAt or h.maxAt > fixAt) then
		h.maxAt = fixAt
		s.dirty = true
	end
	if h.level >= N.MAX_LEVEL and not h.maxAt then
		h.maxAt = os.time() -- 만렙에 오른 때가 적히기 전(2026-10-24)에 만렙이 되었고 MAX_FIX에도 없는 캐릭터: 서버가 처음 본 때로 채운다
		s.dirty = true
	end
	local level, power = Rank.levelScore(h.level, h.xp, Hero.xpNeed(h), h.maxAt), Hero.power(h)
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
local stopping = false -- 서버가 닫히는 중(World.stop)
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
	local ok, done = pcall(Store.saveAccount, s.player.UserId, Account.pack(s.acct))
	if not ok then
		warn("[lune] 저장하다 오류: " .. tostring(done))
	end
	if not ok or done == false then
		s.dirty = true -- 저장하지 못했다: 다음 틈틈이 저장에서 다시 해 본다(2026-10-18 검토 — 전에는 다른 것이 바뀔 때까지 다시 하지 않았다)
	end
	if not stopping then
		pcall(pushRank, s) -- (서버가 닫히는 중이면 순위판은 건너뛴다 — 계정의 저장이 30초 안에 다 끝나게)
	end
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
	-- 같은 서버에서 막 나간 그 사람의 저장이 아직 쓰이는 중이면 끝날 때까지 기다린다(길어도 20초) — 그 전에 읽으면 옛 계정을 읽고,
	--  앞 자리의 잠금 풀기가 새 자리의 잠금을 풀었다(잠금이 서버 번호로만 적힌다 — 2026-10-18 검토)
	local waitedLeave = 0
	while leaving[player.UserId] and waitedLeave < 20 do
		waitedLeave += task.wait(0.2) or 0.2
	end
	if sessions[player] then
		return
	end
	local s = { player = player, hero = nil, acct = nil, cid = nil, scene = SCENES.start, skill = nil, jumped = true, loaded = false, dirty = false, name = "" }
	sessions[player] = s
	-- 로블록스의 정책(나라 · 나이에 따라 다르다 — 유료 아이템 거래 등). 읽지 못하면 nil(막지 않는다)
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and typeof(info) == "table" then
			s.policy = info
		end
	end)
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
				h.tut = Tutorial.finished()
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
	-- 읽지 못했다(라이브의 저장소가 답하지 않는다): 빈 계정으로 들여보내면 나갈 때 저장된 것을 덮어쓴다 — 저장하지 않고 내보낸다(잠금도 푼다)
	local function cannotRead()
		s.guest, s.locked = true, true
		if s.held and Store.unlock then
			Store.unlock(player.UserId)
		end
		s.held = false
		warn(("[lune] %d의 계정을 읽지 못했다 — 저장하지 않고 내보낸다"):format(player.UserId))
		kick(player, LOAD_KICK)
	end
	if sessions[player] ~= s then
		if Store.unlock then
			Store.unlock(player.UserId) -- 잡는 사이에 나갔다: 잠금을 남기지 않는다(150초 동안 다른 서버로 못 들어갔다 — 2026-10-18 검토)
		end
		s.held = false
		return
	end
	local data, failed = Store.loadAccount(player.UserId)
	if failed then
		cannotRead()
		return
	end
	-- 계정을 푸는 데서 오류가 나면(망가진 저장) 읽지 못한 것으로 친다 — 덮어쓰지 않고 다시 들어오라고 알린다(2026-10-18 검토: 오류로 멈춰 40초 동안 검은 화면이었다)
	local acct = nil
	if data then
		local okU, res = pcall(Account.unpack, data)
		if not okU then
			warn("[lune] 계정을 풀지 못했다: " .. tostring(res))
			cannotRead()
			return
		end
		acct = res
	end
	local adopted = false
	if not acct and not data then
		local old, oldFailed = Store.loadOld(player.UserId)
		if oldFailed then
			cannotRead()
			return
		end
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
	-- 쓴 쿠폰의 보상을 지금의 목록에 맞춘다(쿠폰 펫을 바꿨을 때 — CashServer.syncCoupons · 2026-10-21)
	if CashServer.syncCoupons(acct) and not s.guest then
		saveAccount(s)
	elseif adopted then
		saveAccount(s)
	end
	Analytics.joined(s)
end

-- 세계에서 나온다(캐릭터 고르기 화면으로 · 나갈 때): 저장하고, 파티에서 빠지고, 방 사람들의 이름표에서도 빠진다
-- 파티에서 뺀다: 남은 파티원들을 돌려주고, 이 사람이 보낸 초대를 받은 사람들의 초대 상자를 닫는다(2026-10-18 검토: 30초 동안 남아 「받기」를 누르면 「받은 초대가 없다」)
local function partyLeave(uid: number)
	local left, _, cleared = Party.leave(book, uid)
	for _, to in cleared or {} do
		local ts = byUser[to]
		if ts then
			fire("PartyAsk", ts.player, { from = false })
		end
	end
	return left
end

local KEEP_TIME = 600 -- 캐릭터 고르기로 나갔다가 이 시간(초) 안에 같은 캐릭터로 다시 들어오면 체력 · 다시 쓰기 · 물약 대기를 이어 간다
local function leaveWorld(s)
	if s.hero then
		Analytics.finish(s) -- 모아 둔 달돈의 기록을 보낸다
		saveAccount(s)
		-- 체력 · 다시 쓰기(2~4차 · 버프) · 물약 대기는 저장하지 않는다 — 캐릭터 고르기를 오가 가득 찬 체력 · 다 돈 다시 쓰기로 돌아오지 않게 이 세션에 잠깐 둔다(2026-10-18 검토)
		if s.cid then
			s.keep = s.keep or {}
			s.keep[s.cid] = { at = World.now, hp = s.hero.hp, alive = s.hero.alive, cds = table.clone(s.hero.cds or {}), potionWait = s.hero.potionWait }
		end
	end
	local had, scene = s.hero ~= nil, s.scene
	if s.hero and scene and rooms[scene] then
		rooms[scene]:forget(s.hero) -- (캐릭터 고르기로 — 남은 늦은 타를 버린다)
	end
	local left = partyLeave(s.player.UserId)
	s.hero, s.cid, s.skill, s.name = nil, nil, nil, ""
	s.scene = SCENES.start
	sendParty(left)
	if had then
		sendWho(scene)
	end
end

-- 경매장의 일(저장소를 기다리는 중)이 끝나기를 기다린다: 값을 치른 물건 · 받은 대금이 가방에 들어오기 전에 저장하고 나가지 않게(길어도 MARKET_WAIT초)
local MARKET_WAIT = 120 -- (2026-10-18 검토: 15초면 「모두 받기」 여럿 · 느린 저장소에서 경매장의 일이 끝나기 전에 저장하고 나가, 물건 · 달돈을 잃거나 서버를 옮기면 둘이 될 수 있었다)
local function marketIdle(s)
	local waited = 0
	while s.marketBusy and waited < MARKET_WAIT do
		waited += task.wait(0.1) or 0.1
	end
end

function World.removePlayer(player)
	local s = sessions[player]
	sessions[player] = nil
	byUser[player.UserId] = nil
	-- 파티에서는 저장을 기다리기 전에 뺀다(2026-10-18 검토: 경매장 · 저장을 기다리는 동안(길면 15초) 나간 사람이 파티장으로 남았고, 저장이 오류를 내면 영영 남았다)
	sendParty(partyLeave(player.UserId))
	leaving[player.UserId] = true -- 나가며 저장하는 중(같은 서버로 곧바로 다시 들어오면 이 저장이 끝난 뒤에 읽는다 — addPlayer)
	if s and s.hero and s.scene and rooms[s.scene] then
		rooms[s.scene]:forget(s.hero) -- 나간 사람의 늦게 드는 타를 버린다(Room:forget)
	end
	if s and s.hero then
		marketIdle(s)
		pcall(Analytics.finish, s)
		saveAccount(s)
	elseif s and s.dirty and s.loaded and not s.guest then
		saveAccount(s) -- 캐릭터 고르기 화면에서 바꾼 것(소리 설정)을 남기고 나간다(2026-10-18 검토)
	end
	-- 저장을 끝낸 뒤에 계정의 잠금을 푼다(다른 서버로 옮겨 가면 그 서버가 바로 잡는다)
	if s and s.held and Store.unlock then
		Store.unlock(player.UserId)
	end
	leaving[player.UserId] = nil
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
		if (s.hero or s.dirty) and s.loaded and not s.guest and (s.dirty or not onlyDirty) then -- 캐릭터 고르기 화면에서 바꾼 것(소리 설정)도(2026-10-18 검토)
			local ok, err = pcall(saveAccount, s) -- 한 사람의 오류가 나머지의 저장을 막지 않게(2026-10-18 검토)
			if not ok then
				warn("[lune] 저장하다 오류: " .. tostring(err))
			end
		end
	end
end

function World.session(player)
	return sessions[player]
end

function World.room(key: string)
	return roomOf(key)
end
-- 그 방이 열려 있는가(만들지 않고 본다 — 빈 토벌의 방을 닫았는지 볼 때)
function World.hasRoom(key: string): boolean
	return rooms[key] ~= nil
end

-- ---------- 패킷 ----------
local function describe(s)
	local room = roomOf(s.scene):describe(s.hero.id)
	room.who = roster(s.scene)
	return { self = selfView(s), bag = Bag.view(s.hero), quests = Quests.view(s.hero.quests), bond = Bond.view(s.hero, os.time()), scene = s.scene, x = s.hero.x, y = s.hero.y, room = room, id = s.hero.id, name = s.name }
end

local function onReady(player)
	World.addPlayer(player)
	local s = sessions[player]
	-- 저장된 것을 읽는 중이면 기다린다 — 잠금을 기다리고(6번 x 1.5초) 읽기를 다시 해 보는 동안(2026-10-18 검토: 10초면 모자라 검은 화면에 멈췄다).
	--  그 사이에 내보내졌으면(다른 서버가 잡고 있다 · 읽지 못했다) 곧 끊긴다
	local waited = 0
	while s and not s.loaded and not s.locked and sessions[player] == s and waited < 40 do
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
-- Roblox의 글 거르기(모두에게 보이는 글 — Broadcast). 가려진 데(#)가 있으면 두 번 더 물어 한 번이라도 깨끗하면 깨끗한 것으로 본다(2026-10-25 사용자: "Ryuville 이라는 닉네임이 왜 … 사용못하는 닉네임으로 걸리는거야?" —
--  우리 금칙어에는 걸리지 않는 이름이 들어올 때 Roblox의 거르기에 가려져 이름이 지워졌다. Roblox의 거르기는 같은 글도 때에 따라 다르게 · 잘못 가린다는 보고가 있다:
--  devforum.roblox.com/t/inconsistency-of-filtering/33736 · /t/text-being-falsely-censored-at-a-much-higher-rate/4743424). 돌려주는 것: 물어봤는가, 깨끗한가
local function filtered(name: string, userId: number): (boolean, boolean)
	local askedAny = false
	for _ = 1, 3 do -- (묻는 것 자체가 Roblox에 다녀오는 시간이 걸린다 — 따로 기다리지 않는다)
		local asked, out = pcall(function()
			return TextService:FilterStringAsync(name, userId):GetNonChatStringForBroadcastAsync()
		end)
		askedAny = askedAny or asked
		if asked and out == name then
			return true, true
		end
	end
	return askedAny, false
end

local NAME_BURST, NAME_GAP = 5, 3 -- 이름 확인(저장소에 묻는 것): 한 사람이 한 번에 5번까지 · 3초마다 한 번씩 다시 찬다
local function nameFree(s, name: any, skip: any?): (boolean, string?)
	local ok, why = Account.nameOk(name, Admin.is(s.player)) -- 관리자 계정은 운영자 이름(운영자 · GM …)을 지을 수 있다(2026-10-29)
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
local function onCharsInner(player, action: string, a: any, b: any)
	local s = sessions[player]
	if not s or not s.loaded or not s.acct then
		return nil
	end
	local acct = s.acct
	if action == "leave" then
		if s.hero then
			marketIdle(s) -- 경매장의 일이 끝난 뒤에 나온다(받을 것이 그 캐릭터의 가방에 들어간 뒤에)
			leaveWorld(s)
			markName(s)
		end
		return { select = Account.view(acct) }
	elseif s.hero then
		return nil
	end
	if action == "check" then
		-- 저장소 · 글 거르기에 묻는 이름 확인은 한 사람이 한 번에 NAME_BURST번까지 · NAME_GAP초마다 한 번씩 다시 찬다(2026-10-18 검토: 새 이름을 1초에 두 번씩
		--  끝없이 물어 서버의 저장소 몫을 다 쓰면, 들어오는 사람의 계정을 읽지 못해 내보내졌다). 이름의 꼴만 보는 것(글자 수 · 쓸 수 없는 글자)은 그대로 곧장 답한다
		if Account.nameOk(a) then
			local nowC = os.clock()
			s.nameTokens = math.min(NAME_BURST, (s.nameTokens or NAME_BURST) + (nowC - (s.nameAt or nowC)) / NAME_GAP)
			s.nameAt = nowC
			if s.nameTokens < 1 then
				return { ok = false, why = "잠시 뒤에 다시 확인해 주세요" }
			end
			s.nameTokens -= 1
		end
		local ok, why = nameFree(s, a)
		return { ok = ok, why = why }
	elseif action == "create" then
		if Account.full(acct) then
			return { ok = false, why = ("캐릭터는 %d명까지 만들 수 있습니다"):format(Account.maxChars(acct)) }
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
		Analytics.made(s)
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
		-- 이름을 다시 본다: 지은 뒤에 우리 금칙어(Account.nameBanned)가 늘었으면 이름을 비우고 다시 짓게 한다.
		--  Roblox의 글 거르기로는 이제 비우지 않는다(2026-10-26 사용자: "LaNu 라는 닉네임도 지금 똑같은 방식으로 날아갔어 … 이런일이 절대 생기면안된다").
		--  전에는 들어올 때마다 다시 물어 가려져 오면 비웠다 — 지을 때 거르기를 거친 이름(「Ryuville」 · 「LaNu」)이 Roblox의 거르기가 그때그때 달라 지워졌다(세 번 물어도 · S220).
		--  지을 때 모두에게 보이는 글(Broadcast)로 거른 이름이다. 지금 가려져 오면 서버 출력에만 남긴다(제가 정한 것 — create.roblox.com/docs/ui/text-filtering).
		if not s.guest then
			-- 운영자 사칭(2026-10-29 사용자: "이미 생성된경우 닉네임 변경할수있도록 안내해주고 사용 못하게 해야한다"): 관리자 계정이 아니면 같은 길로 이름을 비우고 까닭을 알린다
			--  → 고르기 화면에 그 캐릭터가 「이름 짓기」로 남는다(레벨 · 아이템 · 퀘스트는 그대로). 비운 이름은 장부에서 놓아 준다(그 이름은 다시 누구도 지을 수 없다 — nameOk)
			local staffOk = Admin.is(player)
			if Account.nameBanned(c.name, staffOk) then
				local staff = not staffOk and Account.nameStaff(c.name)
				Store.freeName(Account.nameKey(c.name), player.UserId)
				warn(("[이름] 들어올 때 이름을 비웠다(%s): %s"):format(if staff then "운영자 사칭" else "금칙어", c.name))
				c.name = ""
				saveAccount(s)
				return { ok = false, why = if staff then Account.TEXT.staffGone else Account.TEXT.gone, select = Account.view(acct) }
			end
			task.spawn(function()
				local asked, clean = filtered(c.name, player.UserId)
				if asked and not clean then
					warn(("[이름] Roblox 글 거르기가 지금은 가린다(이름은 그대로 둔다): %s · %d"):format(c.name, player.UserId))
				end
			end)
		end
		local hero = Hero.unpack(player.UserId, c.hero)
		if not hero then
			return { ok = false, why = "이 캐릭터를 읽을 수 없습니다" }
		end
		-- 창고를 늘리는 부탁(「창고 칸 +4」 — 2026-10-18): 이 캐릭터가 이미 끝낸 것은 계정에 붙인다(그 보상이 생기기 전에 끝낸 캐릭터)
		for id, st in hero.quests do
			local def = Quests.def(id)
			if st.done and def and (def.reward.store or 0) > 0 then
				acct.storeGot[id] = true
			end
		end
		hero.storeExtra = Account.storeExtra(acct)
		Bag.loadStore(hero, acct.store) -- 창고는 계정의 것: 어느 캐릭터로 들어가든 같은 창고다
		-- 뺀 맵에 남은 저장(반달 나루 — 2026-10-16 밤): 마지막 맵 · 마지막으로 들른 마을을 그 자리를 대신하는 곳으로(scenes의 gone)
		if hero.last and SCENES.gone[string.match(hero.last, "^(.-)#w?[nh]?%d+$") or hero.last] then
			hero.last = SCENES.gone[string.match(hero.last, "^(.-)#w?[nh]?%d+$") or hero.last]
		end
		if hero.home and SCENES.gone[hero.home] then
			hero.home = SCENES.gone[hero.home]
		end
		s.hero, s.cid, s.name = hero, c.id, c.name
		task.spawn(function() -- 영구 게임 패스(경험치 · 드롭률 1.25배 — 2026-10-22): 로블록스에 물어 이 캐릭터에 얹는다(묻는 동안 들어서는 것을 기다리지 않게)
			if CashServer.applyPasses(s) and s.hero == hero then
				sendSelf(s)
			end
		end)
		acct.last = c.id
		-- 첫 퀘스트를 아직 끝내지 않은 새 캐릭터는 사당 안(사제의 방)에서 시작한다 — 그 밖에는 마지막으로 있던 맵(없으면 마지막 마을 · 시작 마을)
		--  사용자 2026-10-16 밤: "게임을 시작하면 항상 초승달마을에서 시작합니다" → 메이플처럼 나갔던 맵의 시작 자리에서 다시 시작한다(resumeScene)
		local startKey, startX, startY = Quests.firstScene(hero.quests, hero.level), nil, nil
		if not startKey then
			startKey, startX, startY = resumeScene(hero)
		end
		if not hero.tut.done and SCENES.scenes[Tutorial.SCENE] then
			startKey, startX, startY = Tutorial.SCENE, nil, nil -- 꿈에서 깨지 않은 새 캐릭터는 꿈(튜토리얼)에서 시작한다(2026-10-14) · 자리는 꿈의 시작 자리(이어하기의 자리를 쓰지 않는다 — 2026-10-18 검토)
		end
		if not SCENES.scenes[startKey] then
			startKey, startX, startY = SCENES.start, nil, nil
		end
		local scene = SCENES.scenes[startKey]
		place(s, startKey, startX or scene.spawn.x, startY or scene.spawn.y)
		-- 꿈의 물약 미션에서 다시 들어왔다: 체력은 저장하지 않아 가득 찬 채라 물약을 마실 수 없다 — 그 미션이면 다시 조금 다친 채로(tutChanged와 같은 셈 · 2026-10-18 검토)
		if Tutorial.isDream(s.scene) then
			local def = Tutorial.current(hero.tut)
			if def and Tutorial.kind(def) == "potion" and hero.hp > hero.maxHp * 0.6 then
				hero.hp = math.floor(hero.maxHp * 0.6)
			end
		end
		-- 캐릭터 고르기로 잠깐 나갔다 온 같은 캐릭터: 체력 · 다시 쓰기 · 물약 대기를 이어 간다(leaveWorld의 keep — 쓰러진 채 나갔으면 마을에서 가득 찬 채로)
		local kept = s.keep and s.keep[c.id]
		if kept then
			s.keep[c.id] = nil
			if World.now - kept.at <= KEEP_TIME then
				if kept.alive and kept.hp > 0 then
					hero.hp = math.clamp(math.floor(kept.hp), 1, hero.hp) -- (꿈의 물약 미션이면 위에서 덜어 둔 체력보다 많아지지 않게)
				end
				for k, v in kept.cds do
					if v > World.now then
						hero.cds[k] = v
					end
				end
				hero.potionWait = math.max(hero.potionWait or 0, (kept.potionWait or 0) - (World.now - kept.at))
			end
		end
		roomOf(s.scene)
		s.dirty = true
		s.rankSent = nil
		markName(s)
		pushRank(s) -- 들어오자마자 순위판에 올린다(명예의 전당)
		Analytics.begin(s) -- 이 캐릭터의 기록을 시작한다(레벨 · 퀘스트 · 달돈을 이 때부터 견준다)
		-- 출석: 오늘 처음이면 칸이 찬다(어느 캐릭터든 계정에 하루 한 칸) — 화면이 판을 물을 때 「오늘 처음」(fresh)이라 알려 창을 한 번 띄운다
		if Attend.checkIn(acct.att, os.time()) then
			Achieve.add(acct.ach, "attend")
			Cash.passAdd(acct, "attend", os.time()) -- 달빛 패스: 출석 = 달빛 2(2026-10-20)
			s.attFresh = true
		end
		s.achAlive = hero.alive
		task.defer(sendWho, s.scene) -- 먼저 와 있던 사람들에게 내가 왔다고 알린다
		sendParty({ player.UserId })
		return describe(s)
	end
	return nil
end


-- 캐릭터 만들기 · 들어가기 · 지우기 · 나오기는 한 사람에 하나씩(2026-10-18 검토): 저장소를 기다리는 사이에 「지우기」가 끼어들면, 지운 캐릭터로 들어가
--  창고가 저장되지 않는 채 물건을 꺼내 경매에 올리면 물건이 둘이 됐다 · 만들기 둘을 같이 보내면 이름이 장부에만 남거나 같은 이름이 둘 생겼다. 이름 확인(check)은 읽기만 해서 막지 않는다
local function onChars(player, action: string, a: any, b: any)
	local s = sessions[player]
	if action == "check" or not s then
		return onCharsInner(player, action, a, b)
	end
	if s.charsBusy then
		return { ok = false, why = "앞의 일을 처리하고 있습니다. 잠시만 기다려 주세요" }
	end
	s.charsBusy = true
	local ok, res = pcall(onCharsInner, player, action, a, b)
	s.charsBusy = false
	if not ok then
		warn("[lune] 캐릭터 일에서 오류: " .. tostring(res))
		return nil
	end
	return res
end

-- ---------- 명예의 전당 ----------
--  판 셋의 위 열 줄. 서버가 Rank.REFRESH초마다 한 번만 읽어 둔 것을 준다(물을 때마다 저장소를 읽지 않는다).

local function rankBoards()
	if rankCache and World.now - rankAt < Rank.REFRESH then
		return rankCache
	end
	local boards = {}
	for _, board in Rank.BOARDS do
		-- 관리자 계정의 줄은 거른다(지금 들어와 있지 않은 관리자의 캐릭터가 예전에 올라가 있어도 — 2026-10-15)
		local rows = {}
		for _, row in Store.rankTop(board, Rank.TOP + 10) do -- 이름을 모르는 줄 · 관리자의 줄이 빠질 것을 생각해 넉넉히 읽는다
			if not Admin.isId(Rank.userOf(row.key)) then
				table.insert(rows, row)
			end
		end
		if board == "level" then
			-- 찾아 둔 오른 때(강타 · 0NJ4 · 여왕)의 점수가 옛 점수로 낮으면 올린다(2026-10-29 — sim/rank.luau의 fixMax). 서버가 처음 읽을 때는 판에 안 보이는 것도
			Rank.fixMax(rows, function(key, score)
				Store.rankRaise("level", key, score)
			end, not World.maxFixed)
			World.maxFixed = true
		end
		-- 운영자로 보일 수 있는 이름(2026-10-29 — 이미 판에 올라간 것)은 이름을 바꿀 때까지 판에서 뺀다(관리자의 줄은 위에서 이미 뺐다)
		local view, keys = Rank.view(board, rows, function(key)
			local info = Store.rankInfoGet(key)
			if info and typeof(info.name) == "string" and info.name ~= "" and Account.nameStaff(info.name) then
				return nil
			end
			return info
		end)
		local first = if board == "level" then require(script.Parent.firstMax).get() else nil
		boards[board] = if first then Rank.pinFirst(view, first, keys, N.MAX_LEVEL) else view -- 만렙 최초 달성은 레벨 판 1위에 고정(2026-10-24)
	end
	rankCache, rankAt = boards, World.now
	return boards
end

local function onRank(player)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	-- 내 것은 방금의 값으로(관리자는 올리지 않는다 — rankSent가 없다). 순위판에 쓰는 것은 한 사람이 30초에 한 번(2026-10-18 검토: 장비를 바꿔 끼며
	--  순위판을 거듭 열면 열 때마다 저장소에 써서 서버의 쓰기 몫을 다 쓸 수 있었다 — 저장할 때마다도 쓴다)
	if s.rankPushAt == nil or World.now - s.rankPushAt >= 30 then
		s.rankPushAt = World.now
		pushRank(s)
	end
	local sent = s.rankSent
	if sent and s.rankFresh ~= sent.level then
		s.rankFresh = sent.level
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
	if Admin.is(player) then
		saveAccount(s)
		return -- 관리자 계정은 후원 판에 올리지 않는다(2026-10-15)
	end
	local key = Rank.userKey(player.UserId)
	if s.name ~= "" then
		Store.rankInfoSet(key, { name = s.name, class = if s.hero then s.hero.class else false }, s.guest == true)
	end
	Store.rankSet("robux", key, s.acct.spent, s.guest == true)
	rankCache = nil
	saveAccount(s)
end

-- 달조각이 있는 맵들(자리 보고마다 볼 맵만)
local SHARD_SCENES = {}
for _, x in Bond.DATA.shards do
	SHARD_SCENES[x.scene] = true
end

local moveTo: (any, string, number, number) -> () -- 그 사람을 그 장면의 (x, y)로 옮긴다(화면에는 Revive — 아래에서 채운다)
local function onMove(player, x: number, y: number, dir: number, key: any)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return
	end
	local scene = SCENES.scenes[s.scene]
	local hero = s.hero
	require(script.Parent.macroGuard).onMove(s, x, y) -- 매크로 확인: 들른 칸(2026-10-23)
	-- 다른 맵(방)의 자리(2026-10-21): 서버가 아는 맵의 자리로 받지 않는다 — 받으면 그 맵의 땅 속을 「서버가 아는 자리」로 적었다가 화면을 그리로 되돌려 보낼 수 있었다
	--  (사용자 2026-10-21 폰: "대쉬하다가 맵을뚫고 낑기는 현상"). 4초 넘게 계속 다른 맵이면 화면과 서버가 어긋난 것이다(문의 대답이 늦어 화면만 옛 맵에 남았다 …) — 서버의 맵으로 다시 보낸다
	if typeof(key) == "string" and key ~= s.scene then
		s.wrongSince = s.wrongSince or World.now
		if World.now - s.wrongSince >= 4 and World.now - (s.resyncAt or -99) >= 4 then
			s.wrongSince, s.resyncAt = nil, World.now
			moveTo(s, s.scene, hero.x, hero.y)
		end
		return
	end
	s.wrongSince = nil
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
	-- 그 맵의 시작 자리로 온 것은 받는다(맵 아래로 떨어지면 화면이 시작 자리로 돌려놓는다 — 이것까지 막으면 그 뒤로 자리가 영영 어긋난다).
	--  떨어질 수 있었을 때만이다: 서버가 아는 자리 가까이에 맵의 바닥이 뚫린 곳이 있을 때(2026-10-18 검토: 아무 데서나 시작 자리로 옮겨 보스의 패턴을 피할 수 있었다)
	local atSpawn = math.abs(x - scene.spawn.x) <= MOVE_SLACK and math.abs(y - scene.spawn.y) <= MOVE_SLACK * 2 and holeNear(scene, hero.x)
	local dx, dy = math.abs(x - hero.x), math.abs(y - hero.y)
	refillMove(s)
	if hero.warpMark then -- 서버가 몸을 옮기는 스킬을 돌렸다(sim/caster.luau) — 그 뒤의 첫 보고부터 WARP_TIME초
		-- 옮긴 지 WARP_TIME초가 지난 표시는 버린다(2026-10-25 — 서버가 몸을 옮기는 돌격 · 망령 돌진 · 불꽃 돌진 뒤 몇 초 지나 온 먼 보고까지 받았다)
		if typeof(hero.warpMark) ~= "number" or roomOf(s.scene).time - hero.warpMark <= WARP_TIME then
			hero.warpAt = World.now
		end
		hero.warpMark = nil
	end
	local jumpedOk = s.jumped and dx <= JUMP_SLACK and dy <= JUMP_SLACK -- 맵을 옮긴 직후의 첫 보고(아무 데나가 아니라 넉넉한 거리 안 — 2026-10-18 검토)
	-- 자동 검사만 세우는 표시: 다음 보고 하나를 거리와 상관없이 받는다(서버의 세션에만 있다 — 화면이 보내는 어떤 것으로도 서지 않는다).
	--  검사가 졸개 곁 · 문 앞으로 사람을 바로 옮길 때 쓴다(전에는 s.jumped가 그 구실을 했다 — 2026-10-18에 그것을 좁혔다)
	local trusted = s.trust == true
	s.trust = nil
	local up = math.max(0, hero.y - y) -- 위로 간 만큼(화면의 y는 아래로 는다)
	if not trusted and not jumpedOk and not atSpawn and (dx > MOVE_SLACK or dy > MOVE_SLACK * 2 or dx > s.moveBudget or up > s.upBudget) then
		-- 순간이동하는 스킬을 쓴 직후에는 받는다(그 스킬이 갈 수 있는 거리 안에서) — 한 번 쓰면 한 번만(2026-10-18 검토: 보고마다 받아 1.5초 동안 끝없이 갔다)
		local warped = hero.warpAt ~= nil and World.now - hero.warpAt <= WARP_TIME and math.abs(x - hero.x) <= WARP_SLACK and math.abs(y - hero.y) <= MOVE_SLACK * 2
		if warped then
			hero.warpAt = nil
		else
			-- 순간이동은 믿지 않는다(서버가 아는 자리를 그대로 둔다) — 그리고 화면을 그 자리로 되돌린다.
			--  되돌리지 않으면 그 뒤의 보고가 모두 멀어서, 서버가 아는 자리와 화면의 자리가 영영 어긋난다(2026-10-07의 가시 고장과 같은 일)
			if World.now - (s.warpSent or -9) > 0.5 then
				s.warpSent = World.now
				hero.x, hero.y = Room.physics.freeSpot(scene, hero.x, hero.y) -- 되돌려 보낼 자리도 땅 속이면 꺼내서(2026-10-21 — 끼임)
				fire("Warp", player, hero.x, hero.y)
			end
			return
		end
	end
	s.jumped = false
	s.moveBudget = math.max(0, s.moveBudget - dx)
	s.upBudget = math.max(0, s.upBudget - up)
	hero.x, hero.y, hero.dir = x, y, dir
	-- 달조각(2026-10-16 — 로스트아크의 모코코 씨앗): 닿으면 줍는다
	if SHARD_SCENES[s.scene] then
		local id = Bond.touchShard(hero.bond, s.scene, x, y)
		if id then
			s.dirty = true
			if s.acct then
				Achieve.add(s.acct.ach, "shard") -- 업적: 달조각(2026-10-16)
			end
			fire("BondView", player, Bond.view(hero, os.time()), { kind = "shard", id = id })
		end
	end
end

local tutChanged: (any) -> () -- 튜토리얼의 진행이 바뀌었을 때(아래 applyResult 앞에서 채운다)
local riftExitSpot: (any?) -> (number, number) -- 토벌에서 나와 서는 곳 = 토벌대장 앞 · 던전 = 그 문 앞(아래 onRift 곁에서 채운다)
-- 튜토리얼의 미션을 넘겼다(before째부터 지금 앞까지): 넘긴 미션마다 경험치(design/tutorial.js의 xp — 수련 인형 앞까지는 Lv.1 몫의 share씩, upAt 미션에서 Lv.2가 되게 채운다).
--  「경험치 · 레벨 업」이 화면에 뜨게 Gain을 보낸다. 그 뒤의 미션은 경험치가 없다
local function tutAdvanced(s, before: number)
	local h = s.hero
	local X = Tutorial.DATA.xp
	local upIndex = 0
	for i, def in Tutorial.STEPS do
		if def.id == X.upAt then
			upIndex = i
		end
	end
	local gained, ups = 0, 0
	for i = before, math.min(h.tut.step - 1, Tutorial.TOTAL) do
		if h.level == 1 and i <= upIndex then
			local left = N.xpNeed(1) - h.xp
			local amount = if i == upIndex then left else math.min(math.floor(N.xpNeed(1) * X.share), left - 1)
			if amount > 0 then
				ups += Hero.gainXp(h, amount)
				gained += amount
			end
		end
	end
	if gained > 0 then
		fire("Gain", s.player, { xp = gained, ups = ups, level = h.level })
	end
	-- 「능력치 찍기 · 스킬 찍기」의 차례인데 이미 다 찍었다(미션 전에 창을 열어 찍었다): 그 미션은 끝난 것으로 넘긴다 — 찍을 점수가 없어 막히지 않게
	while true do
		local d = Tutorial.current(h.tut)
		local k = if d then Tutorial.kind(d) else ""
		if (k == "stat" and (h.ap or 0) <= 0) or (k == "sp" and (h.sp or 0) <= 0) then
			Tutorial.onEvent(h.tut, k)
		else
			break
		end
	end
	tutChanged(s)
end
-- 서버가 아는 일(잡기 · 줍기 · 물약 · 능력치 · 스킬)이 꿈에서 일어났다
local function tutEvent(s, kind: string)
	if not Tutorial.isDream(s.scene) or s.hero.tut.done then
		return
	end
	local before = s.hero.tut.step
	if Tutorial.onEvent(s.hero.tut, kind) then
		tutAdvanced(s, before)
	elseif kind == "kill" then
		tutChanged(s) -- 셋 가운데 몇을 잡았는지(판의 셈)
	end
end
-- 튜토리얼(꿈): "done" n = 화면만 아는 n째 미션(걷기 · 뛰기 · 내려가기 · 말 걸기 · 기술 · 창)을 끝냈다 · "skip" = 꿈을 건너뛰고 사당에서 깨어난다(이 계정이 한 번 끝낸 뒤에만)
local function onTut(player, action: string, n: any)
	local s = sessions[player]
	if not s or not s.hero or not Tutorial.isDream(s.scene) or s.hero.tut.done then
		return nil
	end
	if action == "done" then
		local before = s.hero.tut.step
		if Tutorial.report(s.hero.tut, n) then
			tutAdvanced(s, before)
		end
		return { tut = Tutorial.pack(s.hero.tut) }
	elseif action == "skip" and s.acct and s.acct.tutDone and s.hero.alive then
		Tutorial.finish(s.hero.tut)
		local to = Tutorial.DATA.exit
		local dest = SCENES.scenes[to]
		local from = s.scene
		place(s, to, dest.spawn.x, dest.spawn.y)
		s.dirty = true
		sendSelf(s)
		local room = roomOf(to):describe(s.hero.id)
		room.who = roster(to)
		sendWho(from)
		sendWho(to)
		return { scene = to, x = dest.spawn.x, y = dest.spawn.y, room = room }
	end
	return nil
end

-- 퀘스트 연출(장면 — shared/lune/cine.luau): 장면이 도는 동안은 맞지 않는다(90초가 넘으면 저절로 풀린다 — 화면이 「끝났다」를 못 보냈을 때). 본 장면은 캐릭터에 적는다
local function onCine(player, action: string, id: any)
	local s = sessions[player]
	if not s or not s.hero then
		return
	end
	local h = s.hero
	if action == "on" then
		-- 아직 안 본 장면 하나에 한 번만(2026-10-18 검토: 「on」을 90초마다 보내면 영원히 맞지 않았다 — 스토리 보스까지)
		--  그 장면이 나올 때(맵 · 퀘스트 — Cine.fits)일 때만 · 틀면 본 것으로 적는다(나갔다 들어와 다시 틀지 못하게 — 2026-10-18 검토)
		if not Cine.known(id) or h.cine[id] or not Cine.fits(id, s.scene, h.quests) then
			return
		end
		s.cineOn = s.cineOn or {}
		if s.cineOn[id] then
			return
		end
		s.cineOn[id] = true
		h.cine[id] = true
		s.dirty = true
		h.inCine = true
		local at = os.clock()
		s.cineAt = at
		task.delay(90, function()
			if s.cineAt == at then
				h.inCine = false
			end
		end)
	elseif action == "off" then
		h.inCine = false
		s.cineAt = nil
	elseif action == "seen" and Cine.known(id) and not h.cine[id] then
		h.cine[id] = true
		s.dirty = true
	end
end

-- 간이 포탈(2026-10-15 — 사용자: "사냥터 안에서 끝에서 끝으로 이동하는 간이 포탈 … 메이플에 있습니다"): 그 앞에 서 있으면 같은 맵의 짝 자리로 옮기고 화면에 알린다(Warp)
local function onHop(player, id: string)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return
	end
	local warps = SCENES.scenes[s.scene].warps or {}
	for _, w in warps do
		if w.id == id and math.abs(w.x - s.hero.x) <= 28 and math.abs(w.y - s.hero.y) <= 28 then
			for _, t in warps do
				if t.id == w.at then
					s.hero.x, s.hero.y = t.x, t.y
					s.jumped = true -- 다음 자리 보고는 거리와 상관없이 받는다
					fire("Warp", player, t.x, t.y)
					return
				end
			end
		end
	end
end

local function onTravel(player, to: string)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return nil
	end
	local scene = SCENES.scenes[s.scene]
	for _, p in scene.portals do
		if p.to == to and math.abs(p.x - s.hero.x) <= 28 and math.abs(p.y - s.hero.y) <= 28 then
			if p.dungeon or p.weekly then
				return nil -- 던전의 문(2026-10-21) · 보스의 문(2026-10-24): 맵을 옮기지 않는다 — 앞에서 ↑ = 던전 · 보스 창(들어가기는 Rift · Week "enter")
			end
			if not Quests.portalOpen(s.hero.quests, p) then
				return nil -- 그 퀘스트를 받아야 · 끝내야 열리는 문(달의 사당 안의 「사당 지하」 · 마을의 나루): 화면에도 보이지 않는다
			end
			local waking = Tutorial.isDream(s.scene)
			if waking and not Tutorial.canExit(s.hero.tut) then
				return nil -- 꿈의 빛나는 문: 미션을 다 하기 전에는 열리지 않는다
			end
			-- @home = 들어온 마을(개인 연무장의 나가는 문 — 2026-10-26): 마지막으로 들른 마을 · 작은 마을(없으면 시작 마을) · 그 마을의 연무장 문 앞으로(아래 back)
			if to == "@home" then
				to = if s.hero.home and SCENES.homes[s.hero.home] and rawget(SCENES.scenes, s.hero.home) then s.hero.home else SCENES.start
			end
			local dest = SCENES.scenes[to]
			local x, y = dest.spawn.x, dest.spawn.y
			for _, back in dest.portals do
				if back.to == SCENES.base(s.scene) then -- (따로 된 방에서 나왔으면 그 장면의 문으로)
					x, y = back.x, back.y
				elseif back.weekly and require(lune.sim.weekly).boss(back.weekly) and require(lune.sim.weekly).boss(back.weekly).room == SCENES.base(s.scene) then -- (지역 이름의 한도 — 여기서 부른다)
					x, y = back.x - 30, back.y -- 보스 방에서 걸어 나왔다: 그 보스의 문 앞(2026-10-27 — 그림자 능선 꼭대기의 무너진 아치. 전에는 그 맵의 처음 자리로 떨어졌다)
				end
			end
			local broom = rooms[s.scene]
			if broom and broom.box then
				to, x, y = World.boxDoor(broom.box.boss) -- 보상의 방에서 나왔다: 그 보스의 문 앞(2026-10-28 — 방의 문은 하나라도 보스마다 다른 곳으로)
			end
			local fromTier = Rift.tierOfKey(s.scene)
			if fromTier then
				x, y = riftExitSpot(fromTier) -- 토벌에서 나왔다: 토벌대장 앞 · 던전에서 나왔다: 그 문 앞
			end
			local from = s.scene
			place(s, to, x, y)
			to = s.scene -- 파티마다 따로 들어가는 장면이면 그 파티의 방(r1c4#5)
			if waking then -- 꿈에서 깨어났다: 튜토리얼을 마친다 · 이 계정의 다음 캐릭터는 건너뛸 수 있다
				Tutorial.finish(s.hero.tut)
				if s.acct then
					s.acct.tutDone = true
				end
				s.dirty = true
				sendSelf(s)
			end
			local room = roomOf(to):describe(s.hero.id)
			room.who = roster(to)
			sendWho(from)
			sendWho(to)
			sendParty(Party.members(book, player.UserId)) -- 파티원이 어느 맵에 있는지 바뀌었다
			return { scene = to, x = s.hero.x, y = s.hero.y, room = room } -- place가 땅 속에서 꺼낸 자리(2026-10-21)
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
	-- 주간 보스의 방에서 싸우는 동안(2026-10-27 데스 카운트 — sim/weekly.luau): 마을로 가지 않는다. 하나 쓰고 그 방의 처음 자리에서 일어난다(「일어나기」) ·
	--  다 썼으면(「나가기」) 보스의 문 앞으로. 파티원의 소생으로 일어난 사람은 여기에 오지 않는다(줄지 않는다)
	local wroom = rooms[s.scene]
	if wroom and wroom.weekly and wroom.weekly.state == "fight" then
		local Weekly = require(lune.sim.weekly) -- (지역 이름의 한도 — 여기서 부른다)
		if Weekly.useLife(wroom, s.hero.id) > 0 then
			local sc = SCENES.scenes[s.scene]
			moveTo(s, s.scene, sc.spawn.x, sc.spawn.y)
		else
			local b = Weekly.boss(wroom.weekly.boss)
			local dsc = SCENES.scenes[b.door.scene]
			local dy = dsc.spawn.y
			for _, p in dsc.portals do
				if p.weekly == b.id then
					dy = p.y
				end
			end
			moveTo(s, b.door.scene, b.door.x - 30, dy)
		end
		return
	end
	Hero.revive(s.hero)
	local homeKey = if s.hero.home and SCENES.homes[s.hero.home] and SCENES.scenes[s.hero.home] then s.hero.home else SCENES.start
	if not s.hero.tut.done and SCENES.scenes[Tutorial.SCENE] then
		homeKey = if Tutorial.isDream(s.scene) then s.scene else Tutorial.SCENE -- 꿈(튜토리얼)에서 쓰러지면 꿈의 처음으로(마을로 나가지 않는다 · 그 꿈의 방 그대로)
	end
	local scene = SCENES.scenes[homeKey]
	local from = s.scene
	place(s, homeKey, scene.spawn.x, scene.spawn.y, true)
	local room = roomOf(s.scene):describe(s.hero.id)
	room.who = roster(s.scene)
	fire("Revive", s.player, { scene = s.scene, x = s.hero.x, y = s.hero.y, room = room })
	if Tutorial.isDream(homeKey) then
		tutChanged(s) -- 꿈에서 되살아났다: 물약 미션이면 다시 조금 다친 채로(체력이 가득하면 물약을 마실 수 없어 미션이 막혔다 — 2026-10-18 검토)
	end
	sendSelf(s)
	sendWho(from)
	sendWho(s.scene)
	sendParty(Party.members(book, s.hero.id))
end

-- 튜토리얼(꿈)의 진행이 바뀌었다: 저장할 것으로 적고 내 상태를 보낸다. 물약 미션의 차례가 되면 꿈속에서 조금 다친다(체력이 가득하면 물약을 마실 수 없다 — 체력 60%)
tutChanged = function(s)
	s.dirty = true
	local def = Tutorial.current(s.hero.tut)
	if def and Tutorial.kind(def) == "potion" and s.hero.hp > s.hero.maxHp * 0.6 then
		s.hero.hp = math.floor(s.hero.maxHp * 0.6)
	end
	sendSelf(s)
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
	local guard = if #result.kills > 0 then require(script.Parent.macroGuard) else nil -- 매크로 확인: 처치를 센다(2026-10-23)
	for _, kill in result.kills do
		-- 매크로 확인의 처치 = 그 몬스터를 실제로 때린 사람만(kill.hitters — 경험치를 나눠 받는 같은 맵의 파티원은 세지 않는다: 2026-10-26 파티를 맺고 잠수한 사람이 문제를 받았다)
		if guard then
			for _, id in kill.hitters or {} do
				local hs = byUser[id]
				if hs then
					guard.onKill(hs)
				end
			end
		end
		for _, gain in kill.gains do
			local gs = byUser[gain.hero]
			if gs then
				if gs.acct then
					Achieve.killed(gs.acct.ach, kill.kind, key, #kill.gains > 1) -- 업적: 처치 · 파티로 처치(함께 잡은 사람이 있다) · 그 지역의 몬스터 종류
					Cash.passAdd(gs.acct, "kill", os.time(), 1) -- 달빛 패스: 몬스터 100마리마다 달빛 2
				end
				Bond.onKill(gs.hero.bond, kill.kind) -- 모험의 서: 그곳의 몬스터 종류마다 100마리
				if kill.elite then
					Analytics.custom(gs, "FieldElite", 1, key) -- 사냥터 정예를 잡았다(2026-10-18 — 맵마다 얼마나 자주 잡히는지로 30마리 · 10배를 맞춘다)
				end
				-- 튜토리얼(꿈): 수련 인형을 센다 · 잡은 사람 앞에 물약 하나를 반드시 떨어뜨린다(줍기 미션 — design/tutorial.js의 dropItem)
				if Tutorial.isDream(key) and not gs.hero.tut.done then
					tutEvent(gs, "kill")
					local pid = Items.potionFor(1).id
					local g = Items.goods(pid)
					if g then
						local d = roomOf(key):addDrop({ kind = "goods", goods = pid, amount = 1, name = g.name, icon = g.icon }, kill.x + 10, kill.y, gs.hero.id)
						fire("DropAdd", gs.player, Room.dropView(d))
					end
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
		-- 퀘스트 · 일일 의뢰 · 모으는 물건: 잡은 사람 · 같은 맵의 파티원 + 그 몬스터를 한 대라도 친 사람(kill.credit — Room:strike)
		--  사용자 2026-10-21: "몇마리 잡아라 … 내가 한대만 치면 다른사람이 잡아도 잡은걸로 판정이 들어가야해요"
		for _, id in kill.credit or {} do
			local gs = byUser[id]
			if gs then
				if #Quests.onKill(gs.hero.quests, kill.kind, key) > 0 then
					gs.dirty = true
					fire("Quests", gs.player, Quests.view(gs.hero.quests))
				end
				-- 일일 의뢰: 받아 둔 의뢰의 그 맵 · 그 몬스터면 센다
				if Daily.onKill(gs.hero, kill.kind, key, os.time()) then
					gs.dirty = true
					fire("DailyView", gs.player, (Daily.view(gs.hero, os.time())))
				end
				-- 모으는 물건은 사람마다 따로 굴려 그 사람의 것으로 땅에 떨어진다(그 사람에게만 보인다) — 주워야 숫자가 오른다
				for n, q in Quests.drops(gs.hero.quests, kill.kind, key, questRng) do
					local d = roomOf(key):addDrop({ kind = "quest", amount = 1, quest = q.quest, step = q.step, name = q.name, icon = q.icon, goods = q.goods }, kill.x - n * 9, kill.y, gs.hero.id)
					fire("DropAdd", gs.player, Room.dropView(d))
				end
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
World.matesIn = matesIn -- (방의 matesOf — roomOf가 이것보다 위에 있어 World를 거친다)
-- 같은 맵의 파티원 모두(레벨 차이를 보지 않는다 — 나도 든다): 무니의 치유 · 수호령이 닿는 사람(2026-10-24 — sim/party.luau의 Party.near). 혼자면 nil
World.alliesIn = function(key: string, hero)
	local here, heroOf = {}, {}
	for _, o in inRoom(key) do
		if o.hero.alive then
			here[o.hero.id], heroOf[o.hero.id] = o.hero, o.hero
		end
	end
	local list = {}
	for _, mid in Party.near(book, hero.id, here) do
		table.insert(list, heroOf[mid])
	end
	return if #list > 1 then list else nil
end

-- 같은 맵에 쓰러져 있는 파티원들(reach 안 — 소생이 일으킨다)
local function fallenIn(key: string, hero, reach: number)
	local here, heroOf = {}, {}
	for _, o in inRoom(key) do
		here[o.hero.id], heroOf[o.hero.id] = o.hero, o.hero
	end
	local out = {}
	for _, mid in Party.near(book, hero.id, here) do -- (레벨 차이를 보지 않는다 — 2026-10-24)
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
		if s.riding then
			s.riding = false -- 기술을 쓰면 탈것에서 내린다(design/ride.js — 화면은 먼저 내린다)
			sendWho(s.scene)
		end
		if seg == nil or seg == 1 then
			require(script.Parent.macroGuard).onSkill(s, id) -- 매크로 확인: 같은 스킬을 다시 누른 간격(2026-10-23)
		end
		-- 매크로 확인 문제가 떠 있는 동안은 스킬을 받지 않는다(2026-10-24 사용자 "매크로 완전히 파훼할수있어야해" — 전에는 문제가 떠 있어도 매크로가 계속 쳤다)
		if s.hero.inCheck then
			return
		end
		s.hero.inCine = false -- 기술을 쓴다 = 장면을 보는 중이 아니다(장면 동안 맞지 않는 것을 싸움에 쓰지 못하게 — 2026-10-18 검토)
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
			skillPlace(s, x, y)
			local reach = Buffs.data[id].fx.party
			if reach then
				-- Party.mates는 [번호] = 캐릭터(level을 본다)를 받는다 — 세션을 넘기면 level이 없어 오류가 났다(2026-10-18 검토: 파티원에게 버프가 가지 않았다)
				local here, sessionOf = {}, {}
				for _, o in inRoom(s.scene) do
					if o.hero.alive then
						here[o.hero.id], sessionOf[o.hero.id] = o.hero, o
					end
				end
				for _, mid in Party.near(book, hero.id, here) do -- 같은 맵의 파티원 모두(레벨 차이를 보지 않는다 — 2026-10-24: 전에는 경험치 나누기의 목록이라 20레벨 넘게 차이 나면 받지 못했다)
					local o = sessionOf[mid]
					-- reach 9999 = 같은 맵의 파티원 모두(높이도 보지 않는다 — 2026-10-23: 120도트 위 · 아래 층의 파티원은 「같은 맵 모두」인데도 받지 못했다)
					if o and o ~= s and (reach >= 9999 or (math.abs(o.hero.x - hero.x) <= reach and math.abs(o.hero.y - hero.y) <= math.min(reach, 120))) then
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
		skillPlace(s, x, y)
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
		-- 쓴 자리: 서버가 아는 자리와 크게 다르지 않으면 화면이 말한 자리를 받아 적는다(이동 몫 안에서) — 받아 주지 않는 기술이면 되돌린다(2026-10-18 검토)
		local ox, oy, ob = hero.x, hero.y, s.moveBudget
		skillPlace(s, x, y)
		local ok, lv = roomOf(key).caster:begin(hero, id, seg, matesIn(key, hero), { fallen = fallen })
		if not ok then
			hero.dir = was
			hero.x, hero.y, s.moveBudget = ox, oy, ob
			return
		end
		-- 이 스킬이 몸을 옮긴다(순간이동 · 돌진) — 잠깐은 멀리 간 자리 보고도 받는다(onMove). 몸을 옮기는 스킬만이다(2026-10-18 검토 — Caster.MOVERS:
		--  서버가 그 스킬을 돌리며 g.move · g.teleport를 부른 적이 있는 것. 처음 쓰는 때는 그 순간에 hero.warpMark가 선다)
		if Caster.MOVERS[id] then
			hero.warpAt = now
		end
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
	if roomOf(s.scene).caster:busy(s.hero) then
		return -- 2~4차의 스킬을 쓰는 중이다(뒤 구간도 — 2026-10-18 검토: 전에는 첫 구간만 보아 겹쳐 쓸 수 있었다)
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
	-- 이 구간이 시작한 때로 적는 시각: 조금 일찍 온 요청(네트워크의 흔들림)은 받되, 시각은 앞 동작이 끝난 때로 적는다 —
	--  일찍 받은 만큼이 쌓여 기술이 빨라지지 않게(2026-10-18 검토: 1차 연속기를 앞당겨 보내 1.7배쯤 빨랐다)
	local start = now
	if seg == 1 then
		if last and now < last.free - 0.1 then
			return -- 앞 기술이 아직 안 끝났다
		end
		if last and last.free > now then
			start = last.free
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
		-- 화면은 앞 구간이 끝난 뒤에 다음 구간을 보낸다(boot) — 끝나기 0.15초 전부터 받는다(전에는 next를 앞 구간의 40%부터 받아 연속기를 앞당길 수 있었다)
		local from = prevTime - 0.15
		if elapsed < from or elapsed > prevTime + hold + 0.4 then
			return
		end
		start = math.max(now, last.at + prevTime)
		if prev.charge then
			-- 모은 단계는 서버가 흐른 시간으로 셈한다(화면이 말한 단계를 믿지 않는다). 만월 동안에는 모으지 않아도 끝까지 모은 것으로 친다
			local held = if Buffs.full(s.hero) then hold else elapsed - prevTime
			-- 넘치는 힘(액시온 4차): 끝까지 모은 강타를 맞힌 직후(3초)의 강타는 2단계에서 모으기 시작한다 — 톡 치면 2단계, 두 단계만 더 모으면 끝까지(한 번 쓰면 사라진다).
			--  2026-10-28 사용자 "넘치는힘 패시브가 적용되는게 맞아?": 전에는 「적어도 2단계」였다 — 누르고 있으면 0단계부터 다시 세어 아무 이득이 없었다(끝까지 모으면 저절로 나가는 액시온은 늘 누르고 있다)
			local surge = Passives.get(s.hero, "surge")
			local surged = surge ~= nil and hold > 0 and not Buffs.full(s.hero) and s.hero.pass.surge > roomOf(s.scene).time
			local level, mul, reach = Kit.charge(s.hero, id, held, if surged then surge.surgeFrom else nil)
			if surged then
				s.hero.pass.surge = -1e9
			end
			if level > 0 then
				charged = { mul = mul, reach = reach, level = level, surged = surged } -- surged = 모으지 않고 얻은 단계(이 타로는 넘치는 힘이 다시 켜지지 않는다)
			end
		end
	else
		return -- 저절로 이어지는 구간은 서버가 잇는다(화면이 보낼 일이 없다)
	end
	local hero = s.hero
	-- 쓴 자리: 서버가 아는 자리와 크게 다르지 않으면 클라이언트가 말한 자리를 받아 적는다(판정은 맞는 순간의 자리로 한다 · 이동 몫 안에서)
	skillPlace(s, x, y)
	hero.dir = dir
	-- 저절로 이어지는 뒤 구간은 한꺼번에 받는다 — 한 번 더 눌러 잇는 구간(next) · 힘을 모으는 구간(charge)의 다음 구간 앞에서 끊는다(그것들은 따로 온다)
	local free = start + segDef.time / haste
	local startAt = (start - now) * haste -- 늦은 판정의 때(아래 pending — 동작의 시간으로 적고 haste로 나눈다)도 그 시각부터
	local segs = { seg }
	for i = seg + 1, #def.segs do
		if def.segs[i].next or def.segs[i - 1].charge then
			break
		end
		table.insert(segs, i)
		free += def.segs[i].time / haste
	end
	s.skill = { id = id, seg = segs[#segs], at = start, free = free }
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
			at = start + placed.at / haste,
			fn = function()
				local cur = sessions[player]
				if not cur or cur.scene ~= key or cur.hero ~= hero or not hero.alive then
					return -- 나갔다 · 맵을 옮겼다 · 다른 캐릭터로 다시 들어왔다(2026-10-18 검토 — 옛 캐릭터의 스킬이 새 캐릭터로 맞지 않게)
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
	-- 충격파(액시온 2차 — 2026-10-28 리마스터: 한 번 더 치지 않는다 · 사용자 "딜도 단일타수로 빵 뜨고"): 끝까지 모아 친 대지 강타는 그 타가 세지고(shock),
	--  양옆의 가시가 땅을 따라 wide도트까지 닿으며, 맞은 보통 적을 stun초 넘어뜨린다(설계 PASSIVE.ax_shock)
	local hits = def.hits
	local shock, shockS = Passives.get(hero, "shock")
	if shock and id == "ax_slam" and charged and charged.level >= Kit.chargeLevels(hero) then
		hits = {}
		for i, hit in def.hits do
			local h = table.clone(hit)
			h.mul = hit.mul * (1 + shock.shock * shockS)
			h.stun = shock.stun
			if hit.except then
				h.box = { -shock.wide, shock.wide, hit.box[3], hit.box[4] }
			end
			hits[i] = h
		end
	end
	for _, index in segs do
		for _, hit in hits do
			if hit.seg == index then
				table.insert(pending, {
					at = now + (startAt + hit.at) / haste,
					fn = function()
						local cur = sessions[player]
						if not cur or cur.scene ~= key or cur.hero ~= hero or not hero.alive then
							return -- 나갔다 · 맵을 옮겼다 · 다른 캐릭터로 다시 들어왔다(2026-10-18 검토)
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

-- 하나를 줍는다(Z 키 · 펫이 같이 쓴다 — reach = 펫이 줍는 거리) → 주운 것 / nil · 까닭
local function pickupDrop(s, dropId: number, reach: number?)
	local player = s.player
	local drop, why = roomOf(s.scene):pickup(s.hero, dropId, reach)
	if drop then
		toRoom(s.scene, "DropGone", drop.id, player.UserId, drop.amount, drop.paid) -- paid = 함께 받은 사람들(보상의 방의 달가루 · 달돈 덩이 — 2026-10-28)
		for _, id in drop.paid or {} do
			local ps = byUser[id]
			if ps and ps ~= s then
				ps.dirty = true
				sendSelf(ps)
				sendBag(ps)
			end
		end
		-- 보상의 방의 소비 아이템 덩이(2026-10-28): 가방이 가득 차 다 받지 못한 사람에게 알린다
		for id, k in drop.short or {} do
			local ps = byUser[id]
			if ps then
				fire("WeekPay", ps.player, { short = { item = drop.goods, n = k } })
			end
		end
		tutEvent(s, "pickup") -- 튜토리얼(꿈): 주웠다
		if drop.kind == "money" then
			sendSelf(s)
		else
			sendBag(s) -- 장비 · 달가루 · 퀘스트의 물건(가방의 기타 탭에 들어갔다 — 퀘스트의 숫자는 sendBag이 맞춘다)
		end
	elseif why == Bag.FULL and not reach then
		fire("ItemDone", player, { action = "pickup", ok = false, why = why })
	end
	return drop, why
end
local function onPickup(player, dropId: number)
	local s = sessions[player]
	if not s or not s.hero then
		return
	end
	pickupDrop(s, dropId)
end
-- 펫이 줍는다(2026-10-20 — 사용자 10-06 「자동으로 줍는 펫은 유료」 · 10-20 「줍기는 펫의 기능」 · 「좀멀리서 쫓아오는 느낌이야 아이템주우면서」):
--  화면의 펫이 떨어진 것까지 달려가 닿으면 PetPick(번호)이 온다(client/lune/rideView.luau). 받는 것: 펫을 꺼내 두었고 · 살아 있고 · 펫이 하나 주운 지 every초가 지났고 ·
--  그것이 영웅에게서 reach + slack점 안(펫이 달려가는 동안 영웅이 움직인 만큼) — 주인 · 가방은 Z 키로 줍는 것과 같다(Room:pickup)
local PETRULE = Cash.RIDE.pet
local function onPetPick(player, dropId: number)
	local s = sessions[player]
	if not (s and s.hero and s.hero.alive and s.acct and s.acct.bm.petOut) or s.guest then
		return
	end
	if (s.petT or 0) > World.now then
		return
	end
	local q = Cash.PET[s.acct.bm.petOut]
	local every = if q and not q.free and PETRULE.suck then PETRULE.suck.every else PETRULE.every -- 로벅스 펫은 빨아들인다(더 자주 — 2026-10-22)
	s.petT = World.now + every * 0.8 -- 화면이 every초마다 보낸다(조금 일찍 와도 받는다 — 프레임의 어긋남)
	local sucks = q and not q.free and PETRULE.suck
	pickupDrop(s, dropId, if sucks and PETRULE.suck.reach then PETRULE.suck.reach else PETRULE.reach + PETRULE.slack) -- 로벅스 펫은 더 먼 것까지(10-22 「범위 더크게」)
end

-- 그 주민 앞에 서 있는가(상점 · 강화 · 창고는 주민 앞에서만)
local NPC_REACH = 64
local function nearNpc(s, kind: string): boolean
	for _, n in SCENES.scenes[s.scene].npcs or {} do
		if Items.data.NPCDO[n.id] == kind and Bond.opened(s.hero.bond, n.id) and math.abs(n.x - s.hero.x) <= NPC_REACH and math.abs(n.y - s.hero.y) <= 40 then -- 만나면 열리는 사람은 인사를 나눈 뒤(2026-10-16)
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
		if result and s.acct then
			Achieve.add(s.acct.ach, "dismantle") -- 업적: 장비를 n개 분해한다
		end
		ok = result ~= nil
	elseif action == "dismantleMany" then
		-- 여러 개 분해(2026-10-22): a = 장비 번호들 · 업적은 분해한 수만큼
		local n
		result, why, n = Bag.dismantleMany(h, a)
		if result and s.acct then
			Achieve.add(s.acct.ach, "dismantle", n)
		end
		ok = result ~= nil
	elseif action == "dismantleGoods" then
		-- 물약 · 귀환 주문서를 분해한다(2026-10-27): a = 탭 · b = 칸 · c = 수 → 달가루(장비 분해 업적에는 세지 않는다)
		result, why = Bag.dismantleGoods(h, a, b, c)
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
		if not nearNpc(s, "shop") then -- 잡화 상인만 사 준다(2026-10-15 — 대장장이는 상점이 없다: 제작 · 강화만)
			why = "파는 사람 앞이 아니다"
		else
			result, why = Bag.sell(h, a, b, c)
			ok = result ~= nil
		end
	elseif action == "sellMany" then
		-- 여러 개 판매(2026-10-23): a = 장비 번호들 · 잡화 상인 앞에서만(한 칸 팔기와 같다)
		if not nearNpc(s, "shop") then
			why = "파는 사람 앞이 아니다"
		else
			result, why = Bag.sellMany(h, a)
			ok = result ~= nil
		end
	elseif action == "buyback" then
		-- 되산다(2026-10-18): 잡화 상인 앞에서 · a = 되사기 목록의 차례
		if not nearNpc(s, "shop") then
			why = "파는 사람 앞이 아니다"
		else
			ok, why = Bag.buyBack(h, a)
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
			if made and s.acct then
				Achieve.add(s.acct.ach, "craft") -- 업적: 대장간에서 장비를 처음 만든다
			end
			ok = made ~= nil
			result = if made then { slot = made.slot, stage = made.stage, q = made.q, star = made.star, who = made.who } else nil
		end
	elseif action == "enhance" or action == "restore" then -- (별 옮기기 「transfer」는 2026-10-15에 뺐다)
		if h.level < OPEN.forge then
			why = ("Lv.%d부터 한다"):format(OPEN.forge)
		elseif not nearNpc(s, "smith") then
			why = "대장장이 앞이 아니다"
		elseif action == "enhance" then
			local it = Bag.find(h, a)
			local aim = if it then (it.star or 0) + 1 else 0
			result, why = Bag.enhance(h, a, itemRng, b == true)
			ok = result ~= nil
			if ok then
				Analytics.custom(s, "Enhance", aim, result) -- 값 = 노린 별 · 결과(ok · fail · drop · boom)
				if s.acct then
					if result == "ok" then
						Achieve.forged(s.acct.ach, aim) -- 업적: 장비 하나를 n성까지
					else
						Achieve.add(s.acct.ach, "fail") -- 업적(숨김): 강화가 처음으로 붙지 않는다
					end
				end
			end
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
	-- 귀환 주문서: 쓰면 그 맵에서 가장 가까운 마을(장면의 ret — 문을 가장 적게 지나 닿는 마을 · 작은 마을, export가 셈한다)로 돌아간다.
	--  사용자 2026-10-16: "마을귀환 주문서라는게 가장가까운 마을로 이동하는 귀환주문서지 초승달마을로 고정 귀환하는 주문서가 아닙니다" (전에는 늘 초승달 마을이었다)
	--  쓰러져 있을 때 · 이미 마을일 때 · 배 위 · 꿈에서는 쓰이지 않는다(주문서도 줄지 않는다)
	local goods = Items.goods(id)
	-- 유료 상품으로 받은 아이템(2026-10-20 — sim/cash.luau): 달돈 주머니 · 달가루 상자 · 가방 · 창고 확장권 · 경험치 쿠폰. 이름 바꾸기 주문서는 이름을 받아야 해서 onCash의 rename으로
	if goods and goods.paid then
		local h = s.hero
		if not h.alive then
			return
		end
		local ok, msg = nil, nil
		if goods.kind == "bmRename" then
			msg = "가방에서 쓰면 새 이름을 적는 칸이 열린다" -- 이름은 Cash "rename"이 바꾼다(그때 주문서를 쓴다)
		elseif goods.kind == "bmDyePoint" or goods.kind == "bmDyeRobe" then
			msg = "가방에서 쓰면 색을 고르는 창이 열린다" -- 색은 Cash "dye"가 바꾼다(그때 염색약을 쓴다 — 2026-10-22)
		elseif Bag.count(h, goods.id) <= 0 then
			msg = "가진 것이 없다"
		else
			ok, msg = Cash.use(h, s.acct, goods)
		end
		if not ok then
			fire("ItemDone", player, { action = "use", ok = false, why = msg })
			return
		end
		Bag.take(h, goods.id, 1)
		if goods.kind == "bmStore" then
			h.storeExtra = Account.storeExtra(s.acct)
			Bag.growStore(h, h.storeExtra)
		end
		s.dirty = true
		saveSoon(s)
		sendBag(s)
		sendSelf(s)
		fire("ItemDone", player, { action = "use", ok = true, why = msg })
		return
	end
	if goods and goods.kind == "scroll" then
		local h = s.hero
		local here = SCENES.scenes[s.scene]
		local to = here and here.ret
		if here and here.dojo then
			-- 개인 연무장(2026-10-26): 두 마을에서 들어와 장면에 가장 가까운 마을이 없다 — 들어온 마을(마지막으로 들른 마을 · 없으면 시작 마을)로
			to = if h.home and SCENES.homes[h.home] and rawget(SCENES.scenes, h.home) then h.home else SCENES.start
		end
		local why = nil
		if not h.alive then
			return
		elseif Bag.count(h, goods.id) <= 0 then
			why = "가진 주문서가 없다"
		elseif SCENES.homes[s.scene] then
			why = "이미 마을이다"
		elseif Voyage.onShip(s.scene) then
			why = "배 위에서는 쓸 수 없다"
		elseif not to or not SCENES.scenes[to] then
			why = "여기서는 쓸 수 없다"
		end
		if why then
			fire("ItemDone", player, { action = "use", ok = false, why = why })
			return
		end
		Bag.take(h, goods.id, 1)
		s.skill = nil
		World.jump(player, to)
		sendBag(s)
		sendParty(Party.members(book, player.UserId)) -- 파티원이 어느 맵에 있는지 바뀌었다
		return
	end
	-- 달빛 부적(쓰러진 벌칙을 푼다) · 능력치 초기화 주문서(찍은 능력치를 되돌린다) — 2026-10-18: 설계에만 있던 둘
	if goods and (goods.kind == "charm" or goods.kind == "reset") then
		local h = s.hero
		local why = nil
		if not h.alive then
			return
		elseif Bag.count(h, goods.id) <= 0 then
			why = "가진 것이 없다"
		elseif goods.kind == "charm" and (h.weak or 0) <= 0 then
			why = "약해진 상태가 아니다"
		elseif goods.kind == "reset" and (h.stats.str + h.stats.dex + h.stats.int + h.stats.luk + h.stats.hp) <= 0 then
			why = "찍은 능력치가 없다"
		end
		if why then
			fire("ItemDone", player, { action = "use", ok = false, why = why })
			return
		end
		Bag.take(h, goods.id, 1)
		if goods.kind == "charm" then
			h.weak, h.weakWas = 0, nil
		else
			Hero.resetStats(h)
		end
		s.dirty = true
		sendBag(s)
		sendSelf(s)
		fire("ItemDone", player, { action = "use", ok = true, why = if goods.kind == "charm" then "약해짐이 풀렸다" else "능력치를 모두 되돌렸다" })
		return
	end
	local healed, why = Hero.drink(s.hero, id)
	if healed then
		fire("ItemDone", player, { action = "potion", ok = true, wait = s.hero.potionWait }) -- 다시 마시기까지(화면이 물약 칸에 남은 시간을 그린다 — 2026-10-27 3초)
		sendBag(s)
		tutEvent(s, "potion") -- 튜토리얼(꿈): 물약을 마셨다
	elseif why then
		fire("ItemDone", player, { action = "use", ok = false, why = why })
	end
end

local function onStatAdd(player, stat: string, n: number)
	local s = sessions[player]
	if s and s.hero and Hero.addStat(s.hero, stat, n) then
		sendSelf(s)
		tutEvent(s, "stat") -- 튜토리얼(꿈): 능력치를 찍었다
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
		tutEvent(s, "stat")
	end
end

local function onSkillUp(player, id: string)
	local s = sessions[player]
	if s and s.hero and Hero.skillUp(s.hero, id) then
		sendSelf(s)
		tutEvent(s, "sp") -- 튜토리얼(꿈): 스킬 포인트를 찍었다
	end
end

local function onSkillAuto(player)
	local s = sessions[player]
	if s and s.hero and Hero.autoSkill(s.hero) > 0 then
		sendSelf(s)
		tutEvent(s, "sp")
	end
end

-- 전직하며 받은 공짜 초기화: 찍은 스킬을 모두 되돌린다(쓰러져 있거나 기술을 쓰는 중에는 안 된다)
local function onSkillReset(player)
	local s = sessions[player]
	-- 「쓰는 중」 = 1차 기술의 동작이 아직 끝나지 않았다 · 2~4차 스킬이 도는 중(2026-10-18 검토: s.skill은 맵을 옮길 때만 지워져, 1차 기술을 한 번 쓰면 초기화가 말없이 막혔다)
	local busy = s and s.hero and ((s.skill and World.now < s.skill.free) or roomOf(s.scene).caster:busy(s.hero))
	if s and s.hero and s.hero.alive and not busy and Hero.freeReset(s.hero) then
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
		elseif not Quests.givesIn(def, SCENES.scenes[s.scene].region, SCENES.scenes[s.scene].also) then
			why = "여기서는 받을 수 없는 퀘스트다" -- 주민은 제가 선 지역(과 also — 은달 항구 = 수정 숲)의 퀘스트만 준다(전직 퀘스트는 사제가 어디서든 준다)
		else
			ok, why = Quests.accept(h.quests, h.level, id)
			if ok then
				for npc in h.bond.met do
					Quests.onMeet(h.quests, npc) -- 받기 전에 이미 인사를 나눈 사람(「항구의 첫날」의 만나기 — 2026-10-16)
				end
			end
		end
	elseif action == "complete" then
		if not nearNpcId(s, def.endNpc) then
			why = "돌려줄 사람 앞이 아니다"
		else
			local reward, ups = Hero.questDone(h, id)
			if reward then
				ok, done = true, id
				if (reward.store or 0) > 0 and s.acct and not s.acct.storeGot[id] then
					s.acct.storeGot[id] = true -- 창고는 계정의 것 — 같은 부탁을 다른 캐릭터가 또 해도 한 번만 늘어난다
					Bag.growStore(h, Account.storeExtra(s.acct))
				end
				if reward.open == "tome" then
					fire("BondView", player, Bond.view(h, os.time()), { kind = "open" })
				end
				fire("Gain", player, { xp = reward.xp, ups = ups, level = h.level, quest = def.name, money = reward.money }) -- money = 보상의 달돈(획득 알림 — 2026-10-18)
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
		-- 돌려주는 사람이 없는 퀘스트(endNpc false — 던전의 문 「수정 틈의 문」 2026-10-21): 다 했으면 그 자리에서 끝난다
		if ok and def.endNpc == false and Quests.isReady(h.quests, id) then
			local reward, ups = Hero.questDone(h, id)
			if reward then
				done = id
				fire("Gain", player, { xp = reward.xp, ups = ups, level = h.level, quest = def.name, money = reward.money })
				if ups > 0 then
					sendWho(s.scene)
				end
			end
		end
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
	elseif not Bond.opened(h.bond, board.npc) then
		return reply(nil, "먼저 인사를 나눠야 한다", nil) -- 만나면 열리는 사람(의뢰 접수원 — 2026-10-16)
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
	Analytics.custom(s, "DailyDone", 1, region)
	if s.acct then
		Achieve.add(s.acct.ach, "daily") -- 업적: 일일 의뢰를 n개
		Cash.passAdd(s.acct, "daily", os.time()) -- 달빛 패스: 일일 의뢰 하나 = 달빛 3
	end
	fire("Gain", player, { xp = reward.xp, ups = ups, level = h.level, money = reward.money, dust = reward.dust }) -- 달돈 · 달가루도 획득 알림에(2026-10-18 검토)
	if ups > 0 then
		fire("Quests", player, Quests.view(h.quests)) -- 레벨이 되어 받을 수 있게 된 퀘스트
		sendWho(s.scene)
	end
	sendSelf(s) -- 달돈 · 레벨
	sendBag(s) -- 달가루(덤)
	return reply(true, nil, reward)
end

-- ---------- 출석 · 업적(2026-10-15) ----------
--  사용자: "출석보상, 업적 만들어야합니다". 셈은 shared/lune/sim/attend.luau · achieve.luau, 표는 계정의 것(acct.att · acct.ach — 어느 캐릭터로 들어가도 같다).
--  보상은 「받기」를 누른 캐릭터에게(물약은 그 캐릭터의 레벨의 것). 해낸 업적은 화면 위의 띠(AchDone)로 알리고, 받을 것의 수는 내 상태(attReady · achReady)로 보낸다(「메뉴」의 점).

-- 업적을 셀 때의 사정: 계정의 캐릭터들 가운데 가장 높은 레벨 · 차수, 직업마다의 레벨, 지금 캐릭터의 퀘스트, 지금 가진 장비의 가장 높은 별, 출석의 표
local function achCtx(s)
	local h = s.hero
	local ctx = { level = h.level, job = h.job, classes = { [h.class] = h.level }, quests = h.quests, star = 0, att = s.acct.att }
	for _, c in s.acct.chars do
		if c.id ~= s.cid and typeof(c.hero) == "table" then
			local lv = if typeof(c.hero.level) == "number" then c.hero.level else 1
			local job = if typeof(c.hero.job) == "number" then c.hero.job else 1
			ctx.level = math.max(ctx.level, lv)
			ctx.job = math.max(ctx.job, job)
			ctx.classes[c.class] = math.max(ctx.classes[c.class] or 0, lv)
		end
	end
	for _, it in h.equip do
		ctx.star = math.max(ctx.star, it.star or 0)
	end
	for _, it in h.gear do
		if it then
			ctx.star = math.max(ctx.star, it.star or 0)
		end
	end
	return ctx
end

-- 새로 해낸 업적을 적고 알린다(화면 위의 띠 · 메뉴의 점)
local function achCheck(s)
	if not s.hero or not s.acct then
		return
	end
	local fresh = Achieve.check(s.acct.ach, achCtx(s))
	if #fresh > 0 then
		s.dirty = true
		fire("AchDone", s.player, fresh)
		sendSelf(s)
	end
end

-- 출석: "view" = 판(오늘 처음 들어와 칸이 찼으면 fresh — 화면이 창을 한 번 띄운다) · "claim" = 받지 않은 칸을 앞에서부터 모두
local function onAttend(player, action: string)
	local s = sessions[player]
	if not s or not s.hero or not s.acct then
		return nil
	end
	local now = os.time()
	local att = s.acct.att
	if action == "claim" then
		local got, why = Attend.claim(att, s.hero)
		if got > 0 then
			s.dirty = true
			sendBag(s) -- 가방 · 달돈 · 달가루 · 메뉴의 점
		end
		return { view = Attend.view(att, now), got = got, why = why }
	end
	local fresh = s.attFresh == true
	s.attFresh = nil
	return { view = Attend.view(att, now), fresh = fresh }
end

-- 2편의 도시 생활(2026-10-16 — sim/bond.luau): "view" · "meet" 사람(처음 인사 — 그 사람 앞: 그 사람의 기능이 열리고 「만나기」가 찬다) ·
--  "read" 이야기(숨은 이야기 — 그 앞에서 ↑) · "tome" 곳, %(모험의 서의 보상). 돌려주는 것 { ok, why, view, note }
--  (사용자 2026-10-16 "호감도는 왜만드는거고" — 호감도의 talk · gift · claim은 뺐다)
local function onBond(player, action: string, a: any, b: any)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	local h, now = s.hero, os.time()
	local ok, why, note = true, nil, nil
	if action == "meet" then
		if not nearNpcId(s, a) then
			ok, why = false, "그 사람 앞이 아니다"
		elseif not Bond.isMeet(a) then
			ok, why = false, "인사할 사람이 아니다"
		else
			local first = Bond.meet(h.bond, a)
			if first then
				s.dirty = true
				if #Quests.onMeet(h.quests, a) > 0 then
					fire("Quests", player, Quests.view(h.quests))
				end
			end
			note = { kind = "meet", npc = a, first = first, opens = Bond.DATA.meet[a].opens }
		end
	elseif action == "read" then
		local first, w = Bond.read(h.bond, a, s.scene, h.x, h.y)
		if first == nil then
			ok, why = false, w
		else
			if first then
				s.dirty = true
				if s.acct then
					Achieve.add(s.acct.ach, "story") -- 업적: 숨은 이야기
				end
			end
			note = { kind = "story", id = a, first = first }
		end
	elseif action == "tome" then
		local r, w = Bond.claimTome(h, h.quests, a, b)
		if r then
			s.dirty = true
			note = { kind = "tome", area = a, pct = b, reward = r }
			sendBag(s)
		else
			ok, why = false, w
		end
	elseif action ~= "view" then
		ok, why = false, "모르는 일이다"
	end
	return { ok = ok, why = why, view = Bond.view(h, now), note = note }
end

-- 업적: "view" = 점수와 업적마다의 진행 · "claim" id = 그 업적의 보상 · "all" = 받을 것을 모두
-- ---------- 수정 틈 토벌(2026-10-16 — sim/rift.luau · 공방 design/city.js의 RIFT) ----------
--  광장의 토벌대장 앞에서 「입장」: 같은 맵에 있는 파티원(그 단계의 레벨이 되는 사람)이 함께 rf1#번호의 따로 된 방으로 간다.
--  방이 완료되면 그 방의 사람마다 보상(하루 횟수가 남았으면) · back초 뒤 광장으로. 실패하면 조금 뒤 광장으로. 빈 토벌의 방은 치운다
riftExitSpot = function(t: any?): (number, number)
	if Rift.isDungeon(t) then
		-- 던전에서 나왔다: 그 문의 왼쪽 앞 · 문이 선 땅의 높이(반달네 옛집의 높은 땅 — 2026-10-21 고침: 전에는 맵 시작 자리의 높이(한 칸 아래)라 땅 속에 섰다)
		local dsc = SCENES.scenes[t.door.scene]
		for _, p in dsc.portals do
			if p.dungeon == t.id then
				return p.x - 30, p.y
			end
		end
		return t.door.x - 30, dsc.spawn.y
	end
	local sc = SCENES.scenes[Rift.DATA.scene]
	for _, n in sc.npcs or {} do
		if n.id == Rift.DATA.npc then
			return n.x - 24, n.y
		end
	end
	return sc.spawn.x, sc.spawn.y
end
-- 그 사람을 그 장면의 (x, y)로 옮긴다(화면에는 Revive로 — World.jump와 같다). (onMove가 먼저 쓴다 — 위에서 이름만 지었다)
moveTo = function(s, key: string, x: number, y: number)
	local from = s.scene
	if not s.hero.alive then
		Hero.revive(s.hero) -- 화면은 「Revive」를 받으면 살아난 것으로 본다 — 서버도 맞춘다(2026-10-18 검토: 쓰러진 채 옮겨지면 쓰러진 상자 없이 멈췄다)
	end
	place(s, key, x, y, true)
	key = s.scene -- (파티마다 따로 들어가는 장면이면 그 파티의 방)
	local room = roomOf(key):describe(s.hero.id)
	room.who = roster(key)
	fire("Revive", s.player, { scene = key, x = s.hero.x, y = s.hero.y, room = room }) -- place가 땅 속에서 꺼낸 자리(2026-10-21)
	sendSelf(s)
	sendWho(from)
	sendWho(key)
	sendParty(Party.members(book, s.hero.id))
end
local function riftReply(s, ok: boolean?, why: string?)
	local now = os.time()
	local done = {} -- 던전마다 오늘 끝냈는가(2026-10-21)
	for _, t in Rift.DUNGEON.tiers do
		done[t.id] = Rift.dungeonDone(s.hero.rift, t.id, now)
	end
	return { ok = ok == true, why = why, left = Rift.left(s.hero.rift, now), clears = s.hero.rift.clears, dungeonDone = done }
end
-- 던전에 들어간다(2026-10-21 — 수정 거울숲): 그 문 앞(같은 맵 · 가로 60점 안)에서 · 문이 열렸고(퀘스트) · 레벨 · 오늘 아직 안 했을 때.
--  party = true면 같은 맵의 파티원도 함께(그 사람도 들어갈 수 있을 때 · 장면을 보는 중이 아닐 때 — 넷까지) · 아니면 혼자
local riftSerial = 0
local function onRift(player, action: string, id: any, party: any)
	local s = sessions[player]
	if not s or not s.hero then
		return nil
	end
	if action == "view" then
		return riftReply(s, true)
	elseif action ~= "enter" then
		return riftReply(s, nil, "모르는 일이다")
	end
	local function dungeonEnter(s, t, party: boolean) -- (world.luau의 지역 이름이 Luau의 한도(200)에 닿아 onRift 안에 둔다)
		local now = os.time()
		if s.scene ~= t.door.scene or math.abs(s.hero.x - t.door.x) > 60 then
			return riftReply(s, nil, "던전의 문 앞에서 들어갈 수 있다")
		end
		local why = Rift.canDungeon(s.hero, t, now)
		if why then
			return riftReply(s, nil, why)
		end
		local going = { s }
		if party then
			for _, uid in Party.members(book, s.player.UserId) do
				local ms = byUser[uid]
				if ms and ms ~= s and ms.hero and ms.scene == s.scene and #going < Rift.DUNGEON.party and not Rift.canDungeon(ms.hero, t, now) and not ms.hero.inCine then
					table.insert(going, ms)
				end
			end
			if #going < 2 then
				return riftReply(s, nil, Rift.DUNGEON.words.partyNone)
			end
		end
		riftSerial += 1
		local key = t.id .. "#" .. riftSerial
		local room = roomOf(key)
		local sc = SCENES.scenes[key]
		for i, ms in going do
			moveTo(ms, key, sc.spawn.x + (i - 1) * 12, sc.spawn.y)
			Analytics.custom(ms, "DungeonEnter", 1, t.id)
		end
		toRoom(key, "RiftView", Rift.view(room))
		return riftReply(s, true)
	end
	local t = Rift.tier(id)
	if t and Rift.isDungeon(t) then
		return dungeonEnter(s, t, party == true)
	end
	if not t then
		return riftReply(s, nil, "모르는 토벌이다")
	elseif s.scene ~= Rift.DATA.scene or not nearNpcId(s, Rift.DATA.npc) then
		return riftReply(s, nil, "토벌대장 앞에서 들어갈 수 있다")
	elseif not Bond.opened(s.hero.bond, Rift.DATA.npc) then
		return riftReply(s, nil, "먼저 인사를 나눠야 한다") -- 만나면 열리는 사람(토벌대장 — 2026-10-16)
	end
	local why = Rift.canEnter(s.hero, t)
	if why then
		return riftReply(s, nil, why)
	end
	riftSerial += 1
	local key = t.id .. "#" .. riftSerial
	local room = roomOf(key)
	local sc = SCENES.scenes[key]
	local going: { any } = { s }
	for _, uid in Party.members(book, player.UserId) do
		local ms = byUser[uid]
		-- 같은 맵의 파티원이 함께 들어간다 — 그 사람도 토벌대장과 인사를 나눴고 · 장면(퀘스트 연출)을 보는 중이 아닐 때만(2026-10-18 검토: 인사 전의 파티원 · 장면 중인 파티원도 끌려갔다)
		if ms and ms ~= s and ms.hero and ms.hero.alive and ms.scene == s.scene and #going < Rift.DATA.party and not Rift.canEnter(ms.hero, t)
			and Bond.opened(ms.hero.bond, Rift.DATA.npc) and not ms.hero.inCine then
			table.insert(going, ms)
		end
	end
	for i, ms in going do
		moveTo(ms, key, sc.spawn.x + (i - 1) * 12, sc.spawn.y)
		Analytics.custom(ms, "RiftEnter", 1, t.id)
	end
	toRoom(key, "RiftView", Rift.view(room))
	return riftReply(s, true)
end
-- 완료: 그 방의 사람마다 보상(오늘 횟수가 남았으면 경험치 · 달돈 · 달가루 · 확률로 장비). 횟수가 없으면 보상 없이 끝낸 수만 센다
local function riftPay(key: string, room)
	local t = Rift.tier(room.rift.tier)
	local now = os.time()
	if Rift.isDungeon(t) then
		-- 던전 완료(2026-10-21): 오늘 처음이면 끝낸 때 내 레벨의 한 레벨 경험치의 pay.need배를 한꺼번에 · 하루 한 번(한국 시간 자정에 다시)
		for _, s in inRoom(key) do
			local h = s.hero
			s.dirty = true
			if not Rift.dungeonMark(h.rift, t.id, now) then
				fire("RiftPay", s.player, { none = true, dungeon = true })
				continue
			end
			local xp = Rift.dungeonXp(h.level)
			local ups = Hero.gainXp(h, xp)
			Analytics.custom(s, "DungeonClear", 1, t.id)
			fire("Gain", s.player, { xp = xp, ups = ups, level = h.level })
			if ups > 0 then
				fire("Quests", s.player, Quests.view(h.quests))
				sendWho(key)
			end
			sendSelf(s)
			fire("RiftPay", s.player, { xp = xp, dungeon = true })
		end
		return
	end
	for _, s in inRoom(key) do
		local h = s.hero
		h.rift.clears += 1
		s.dirty = true
		if s.acct then
			Achieve.add(s.acct.ach, "rift") -- 업적: 토벌을 n번
			Cash.passAdd(s.acct, "rift", now) -- 달빛 패스: 토벌 한 번 = 달빛 3
		end
		Analytics.custom(s, "RiftClear", 1, t.id)
		if not Rift.use(h.rift, now) then
			fire("RiftPay", s.player, { none = true, left = 0 })
			continue
		end
		local pay = t.pay
		local ups = Hero.gainXp(h, pay.xp)
		h.money += pay.money
		h.dust += pay.dust
		local gear = Rift.rollGear(t, room.lootRng, h.class)
		local full = false
		if gear then
			if Bag.add(h, gear) then
				sendBag(s)
			else
				gear, full = nil, true
			end
		end
		fire("Gain", s.player, { xp = pay.xp, ups = ups, level = h.level, money = pay.money, dust = pay.dust }) -- 달돈 · 달가루도 획득 알림에(2026-10-18 검토)
		if ups > 0 then
			fire("Quests", s.player, Quests.view(h.quests))
			sendWho(key)
		end
		sendSelf(s)
		sendBag(s)
		fire("RiftPay", s.player, { xp = pay.xp, money = pay.money, dust = pay.dust, gear = gear, gearName = if gear then Items.name(gear) else nil, full = full, left = Rift.left(h.rift, now) })
	end
end

-- ---------- 탈것(2026-10-16 — sim/voyage.luau · 공방 design/city.js의 VOYAGE) ----------
--  그 탈것의 사람(선장 · 뱃사공 · 승강장 일꾼) 앞에서 「탑승」 → 갑판(ship_out · ship_sea_out · air_out …)으로 옮기고, time초 뒤 tick이 닿는 곳에 내려 준다.
--  npcId = 말을 건 사람(한 장면에 탈것이 여럿 — 은달 항구: 선장 · 뱃사공 · 승강장 일꾼). 돌려주는 것 { ok, why, time, dest }.
--  화면에는 Voyage 이벤트로 { left, dest }(갑판에 오름) · { arrived = 장면 }(닿음)
function voyageLanding(r): (number, number)
	local sc = SCENES.scenes[r.to]
	if r.at then
		return r.at[1] * SCENES.tile, r.at[2] * SCENES.tile
	end
	for _, n in sc.npcs or {} do
		if n.id == r.npc then
			return n.x - 32, n.y -- 그 사람의 왼쪽(닿는 곳에도 같은 사람이 서서 돌아가는 길을 태운다)
		end
	end
	return sc.spawn.x, sc.spawn.y
end
local function onSail(player, npcId: any)
	local s = sessions[player]
	if not s or not s.hero or not s.hero.alive then
		return nil
	end
	local r = Voyage.route(s.scene, if typeof(npcId) == "string" then npcId else nil)
	if not r or not nearNpcId(s, r.npc) then
		return { ok = false, why = "태워 주는 사람 앞에서 오른다" }
	elseif not Voyage.open(s.hero.quests, r) then
		return { ok = false, why = r.locked or "아직은 탈 수 없다" }
	end
	local sc = SCENES.scenes[r.ship]
	moveTo(s, r.ship, sc.spawn.x, sc.spawn.y)
	s.voyage = { at = World.now + Voyage.DATA.time, route = r }
	fire("Voyage", player, { left = Voyage.DATA.time, dest = r.dest, to = r.to })
	Analytics.custom(s, "Sail", 1, r.to)
	return { ok = true, time = Voyage.DATA.time, dest = r.dest }
end

local function onAchieve(player, action: string, id: any)
	local s = sessions[player]
	if not s or not s.hero or not s.acct then
		return nil
	end
	local a = s.acct.ach
	achCheck(s) -- 창을 연 그때의 것으로
	local got, why = 0, nil
	if action == "claim" then
		local ok
		ok, why = Achieve.claim(a, s.hero, id)
		got = if ok then 1 else 0
	elseif action == "all" then
		got, why = Achieve.claimAll(a, s.hero)
	end
	if got > 0 then
		s.dirty = true
		sendBag(s)
	end
	return { view = Achieve.view(a, achCtx(s)), got = got, why = why }
end

-- 시계(1초마다): 업적을 보고, 쓰러졌는지 보고, 게임 중에 자정이 지났으면 출석 칸을 채운다
local function achTick(s, dt: number)
	if not s.hero or not s.acct then
		return
	end
	s.achT = (s.achT or 0) + dt
	if s.achT < 1 then
		return
	end
	s.achT = 0
	local alive = s.hero.alive
	if s.achAlive and not alive then
		Achieve.add(s.acct.ach, "death") -- 업적(숨김): 처음으로 쓰러진다
	end
	s.achAlive = alive
	if Attend.checkIn(s.acct.att, os.time()) then
		Achieve.add(s.acct.ach, "attend")
		Cash.passAdd(s.acct, "attend", os.time()) -- 달빛 패스
		s.dirty = true
		fire("AttendNew", s.player)
		sendSelf(s)
	end
	achCheck(s)
end

-- ---------- 경매장 ----------
--  사용자 2026-10-06: "경매장으로 전부 거래가능하게 할겁니다" · 2026-10-13: "경매장 부터 진행합시다.  알아서 조사하고 판단하고 해서  경매장 구현 해보세요"
--  **사용자 2026-10-13(처음 만든 것을 보고): "메이플 식 경매장을 말하는거긴합니다."** — 메이플 옥션 방식: 메뉴에서 어디서나 연다(주민 앞이 아니어도 된다) ·
--   소비와 기타 아이템은 개당 가격으로 올리고 낱개로 팔린다 · 올릴 때 보증금 · 산 것은 「완료」에 「낙찰」로 들어와 「수령」한다 · 대금 수령 · 반환 · 재등록 · 모두 받기.
--  셈은 sim/market.luau, 장부는 Store.marketRead / marketUpdate(분류마다 문서 하나 — UpdateAsync로만 바꾼다).
--  물건 · 달돈이 복사되거나 사라지지 않게 하는 차례(바꾸지 말 것 — tools/test/tests/41_lune_market.luau가 하나씩 일부러 고장을 내서 본다):
--   올리기   = 가방에서 뺀다 · 보증금을 낸다 → 계정의 「맡긴 것」에 적는다 → **계정을 저장한다** → 장부에 줄을 더한다
--              (저장하지 못했으면 올리지 않는다 · 장부가 찼으면 되돌린다 · 저장소가 답하지 않으면 적혔는지 모르니 맡긴 채로 둔다 — 「완료」가 장부와 견주어 알려 준다)
--   사기     = 달돈을 먼저 뺀다 → 장부의 줄에서 남은 수를 줄인다(남은 수만큼만 된다) → 산 것을 「맡긴 것」에 「낙찰」로 적는다 → 계정을 바로 저장한다. 못 샀으면 달돈을 돌려준다
--   대금 수령 = (판매 중인 채로) 팔린 만큼의 대금을 받고 「맡긴 것」의 받은 수(got)를 늘린다 — 장부는 고치지 않는다(받은 것의 기록은 판 사람의 계정이다)
--   끝내기   = (취소 · 반환 · 재등록 · 다 팔린 것) 줄을 닫는다(남은 수가 굳는다) → 남은 것을 돌려받고 대금을 받고 맡긴 것에서 지운다 → **계정을 저장한다** → 저장됐을 때에만 장부의 줄을 지운다
--  어느 차례에서 서버가 꺼져도 「맡긴 것」과 장부의 줄이 남아 다음에 같은 셈을 다시 한다(Market.resolve). 값을 치른 뒤 저장하기 전에 꺼지는 한 곳만 산 것이 사라진다(바로 저장해 그 틈을 줄였다).
--  사람마다 한 번에 하나만 처리한다(s.marketBusy) · 처리하는 동안에는 나가는 저장 · 서버의 닫힘이 기다린다(marketIdle · saving).
local MARKET = Market.DATA
local MWHY = Market.WHY
local MWORDS = Market.WORDS
local MARKET_FRESH = 2 -- 「지금의 것」을 달라고 해도 이만큼(초) 안에 읽은 것은 다시 읽지 않는다(새로 고침을 마구 눌러도 저장소를 덜 읽는다 — 사고 닫는 것은 어차피 UpdateAsync가 지금의 문서로 판단한다)
local marketCache = {} -- [장부] = { at = 읽은 때(os.clock), doc } — 구경하는 사람들이 같은 문서를 MARKET.cache초 동안 같이 본다
local function marketKeep(board: string, doc: any)
	marketCache[board] = { at = os.clock(), doc = doc }
end
-- 저장소를 다시 읽는 새로 고침(강제)은 한 사람이 10초에 한 번 — 둘러보기 · 내 목록 · 사기의 다시 읽기가 같이 쓴다(2026-10-18 검토: 서버의 읽기 몫을 다 쓸 수 있었다)
local function canForce(s): boolean
	if s.marketForceAt ~= nil and os.clock() - s.marketForceAt < 10 then
		return false
	end
	s.marketForceAt = os.clock()
	return true
end
local function marketDoc(board: string, force: boolean?): (boolean, any)
	local c = marketCache[board]
	if c and os.clock() - c.at < (if force then MARKET_FRESH else MARKET.cache) then
		return true, c.doc
	end
	local started = os.clock()
	local ok, doc = Store.marketRead(board, force == true) -- (새로 고침 · 받을 것을 견줄 때는 로블록스의 4초 캐시도 거치지 않는다)
	-- 읽는 사이에 더 새로운 장부(쓰고 받은 것)가 들어왔으면 이 읽기로 덮지 않는다 — 옛 사본이 새 것을 덮어 「돌려받기」가 잘못 나올 수 있었다(2026-10-18 검토)
	local now = marketCache[board]
	if ok and not (now and now.at > started) then
		marketKeep(board, doc)
	elseif ok and now then
		return ok, now.doc
	end
	return ok, doc
end
-- 계정을 지금 저장한다 → 됐는가(저장소를 못 쓰는 Studio에서는 메모리에 둔 것으로 친다). 안 됐으면 틈틈이 도는 저장이 다시 한다
local function saveNow(s): boolean
	if not s.acct or not s.loaded or s.guest then
		return false
	end
	commit(s)
	s.dirty, s.soon = false, nil
	saving += 1
	local ok, done = pcall(Store.saveAccount, s.player.UserId, Account.pack(s.acct))
	saving -= 1
	if (ok and done == true) or Store.isOffline() then
		return true
	end
	s.dirty = true
	return false
end
-- 그 물건(장부의 꼴)이 가방에 들어가는가 · 넣는다
local function marketRoom(h, row): boolean
	local it = Market.unpack(row)
	if not it then
		return false
	elseif it.item then
		return Bag.room(h, it.item) >= it.n
	end
	return Bag.free(h, "gear") >= 1
end
local function marketGive(h, row): boolean
	local it = Market.unpack(row)
	if not it then
		return false
	elseif it.item then
		return Bag.give(h, it.item, it.n) == true
	end
	return Bag.add(h, it) ~= nil
end
-- 「완료」에 맡아 둔다(산 것 · 그 사이에 가방이 차서 못 넣은 것) → 그 번호
local function marketHold(s, row, paid: number, now: number): string
	local book = s.acct.market
	local id = "h_" .. Market.nextToken(book, now)
	book.list[id] = { hold = true, it = row, p = paid, t = now, e = now }
	return id
end
-- 돌려받는다: 가방에 넣고, 그 사이에 가방이 찼으면 맡아 둔다 → 가방에 들어갔는가
local function marketTake(s, row, now: number): boolean
	if marketGive(s.hero, row) then
		return true
	end
	marketHold(s, row, 0, now)
	return false
end
-- 「맡긴 것」 하나를 장부와 견준다 → 읽었는가, 그 줄(없으면 nil), 견준 답
local function marketLook(s, id: string, hd, now: number, force: boolean?)
	if hd.hold then
		return true, nil, Market.resolve(hd, nil, now)
	end
	local got, doc = marketDoc(hd.b, force)
	if not got then
		return false, nil, nil
	end
	local entry = Market.entryIn(doc, id, s.player.UserId, now)
	return true, entry, Market.resolve(hd, entry, now)
end
-- 내 것의 모습(판매 탭 · 완료 탭이 나눠 쓴다): 줄마다 { id, it, p(개당 — 산 것은 치른 값), t, e, state, n, left, sold, due, pay(지금 받을 대금 — 수수료를 뗀 것), deposit(함께 돌아오는 보증금) }
--  state = hold(낙찰 — 수령할 것) · selling · ended(미판매 — 반환 / 재등록) · soldout(다 팔렸다) · back(장부에 없다 — 반환). 보관 기간이 지난 것은 여기서 지운다
local function marketMine(s, now: number, force: boolean?)
	local book, rows = s.acct.market, {}
	local ids = {}
	for id in book.list do
		table.insert(ids, id)
	end
	for _, id in ids do
		local hd = book.list[id]
		if hd.hold then
			table.insert(rows, { id = id, it = hd.it, p = hd.p, t = hd.t, e = hd.t, state = "hold", n = Market.units(hd.it), left = 0, sold = 0, due = 0, pay = 0, deposit = 0 })
		else
			local ok, _, r = marketLook(s, id, hd, now, force)
			if ok and r.state == "void" then
				book.list[id] = nil
				s.dirty = true
			else
				-- 장부를 읽지 못했으면 그대로 둔다(판매 중으로 보인다)
				local q = if ok then r else { state = "selling", n = Market.units(hd.it), left = Market.units(hd.it) - (hd.got or 0), sold = hd.got or 0, due = 0 }
				local am = Market.amount(hd, q)
				table.insert(rows, { id = id, it = hd.it, p = hd.p, t = hd.t, e = hd.e, state = q.state, n = q.n, left = q.left, sold = q.sold, due = q.due, pay = am.pay, deposit = am.deposit })
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return a.id < b.id
	end)
	return rows
end
-- 맡아 둔 것(낙찰 · 못 넣은 것)을 받는다 → 됐는가, 까닭
local function marketReceive(s, id: string, hd): (boolean, string?)
	if not marketGive(s.hero, hd.it) then
		return false, MWHY.bag
	end
	s.acct.market.list[id] = nil
	saveSoon(s)
	return true, nil
end
-- 판매 중인 채로, 팔린 만큼의 대금만 받는다(장부는 고치지 않는다 — 받은 수는 계정에 적는다) → 받은 대금, 수수료
local function marketCollect(s, hd, r): (number, number)
	local am = Market.amount(hd, r)
	s.hero.money += am.pay
	hd.got = (hd.got or 0) + r.due
	if am.pay > 0 and s.acct then
		Achieve.add(s.acct.ach, "sold") -- 업적: 경매장에서 물건이 처음 팔린다(대금을 받을 때 센다)
	end
	saveSoon(s)
	return am.pay, am.fee
end
-- 끝낸다(취소 · 반환 · 재등록 · 다 팔린 것의 마지막 대금): 줄을 닫는다 → 남은 것을 돌려받고(relist면 새로 올린다) 대금을 받고 맡긴 것에서 지운다 → 계정을 저장한다 → 저장됐을 때에만 줄을 지운다
--  돌려주는 것: 됐는가, 까닭, { left(돌려받은 수), pay, fee, deposit, inBag(가방에 들어갔는가), relisted, lost }
local function marketFinish(s, id: string, hd, now: number, relist: boolean?)
	local h, book, userId = s.hero, s.acct.market, s.player.UserId
	local ok, entry, r = marketLook(s, id, hd, now, true)
	if not ok then
		return false, MWHY.off, nil
	elseif r.state == "void" then
		book.list[id] = nil
		saveSoon(s)
		return true, nil, { lost = true, left = 0, pay = 0, fee = 0, deposit = 0, inBag = true }
	end
	local left = r.left
	if relist then
		if left <= 0 or r.state == "selling" then
			return false, MWHY.gone, nil
		elseif h.money < MARKET.deposit then
			return false, MWHY.deposit, nil
		end
	elseif left > 0 and not marketRoom(h, Market.withUnits(hd.it, left)) then
		return false, MWHY.bag, nil
	end
	if left > 0 then
		-- 닫는다: 그 사이에 더 팔렸으면 남은 수가 줄어 있다(늘지는 않는다). 둔 장부(사본)에 없어도 늘 장부에 묻는다 — 사본이 옛 것이면
		--  팔리는 중인 물건을 「돌려받기」로 처리해 물건이 둘이 될 수 있었다(2026-10-18 검토). 장부의 답(none)이 맞는 답이다
		local wrote, res, l2, after = Store.marketUpdate(hd.b, function(old)
			return Market.txClose(old, id, userId, now)
		end)
		if not wrote then
			marketCache[hd.b] = nil
			return false, MWHY.off, nil
		end
		marketKeep(hd.b, after)
		if res == "none" then
			entry = nil
			r = Market.resolve(hd, nil, now)
			left = r.left
		else
			entry = entry or true -- (장부에 있었다: 끝낸 뒤에 장부의 줄을 정리한다 — txSettle)
			left = math.min(left, if typeof(l2) == "number" then l2 else left)
			r = Market.resolve(hd, { l = left, c = 1, e = hd.e }, now)
		end
	end
	local am = Market.amount(hd, r)
	h.money += am.pay + am.deposit
	if am.pay > 0 then
		-- 업적 「첫 장사」(대금을 받을 때 센다): 다 팔린 것 · 끝난 것의 마지막 대금도(2026-10-26 사용자 — 플레이어 "물건 10개 정도 팔았는데 깨지질 않네요": 전에는 판매 중에 일부 받는 marketCollect에서만 셌다)
		Achieve.add(s.acct.ach, "sold")
	end
	book.list[id] = nil
	local out = { left = left, pay = am.pay, fee = am.fee, deposit = am.deposit, inBag = true, relisted = false, lost = false }
	local newId, newRow = nil, nil
	if left > 0 then
		local row = Market.withUnits(hd.it, left)
		if relist then
			-- 같은 값 · 같은 기간으로 다시 올린다(보증금을 다시 낸다)
			local hours = math.floor((hd.e - hd.t) / 3600 + 0.5)
			if not Market.hoursOk(hours) then
				hours = MARKET.hours[1]
			end
			h.money -= MARKET.deposit
			newId, newRow = Market.nextId(book, userId, now), row
			book.list[newId] = { b = hd.b, it = row, p = hd.p, t = now, e = now + hours * 3600, got = 0, d = MARKET.deposit }
			out.relisted = true
		else
			out.inBag = marketTake(s, row, now)
		end
	end
	local saved = saveNow(s)
	if saved and entry then
		local wrote, _, _, after = Store.marketUpdate(hd.b, function(old)
			return Market.txSettle(old, id, userId, now)
		end)
		if wrote then
			marketKeep(hd.b, after)
		else
			marketCache[hd.b] = nil
		end
	end
	if newId and saved then
		local nh = book.list[newId]
		local fresh = Market.entry(newId, userId, s.name, newRow, nh.p, (nh.e - nh.t) / 3600, now)
		local wrote, whyFull, _, after = Store.marketUpdate(hd.b, function(old)
			return Market.txList(old, fresh, now)
		end)
		if wrote and whyFull then
			-- 분류가 가득 찼다: 다시 올리지 않고 돌려받는다(보증금도)
			book.list[newId] = nil
			h.money += MARKET.deposit
			out.relisted = false
			out.inBag = marketTake(s, newRow, now)
			saveSoon(s)
		elseif wrote then
			marketKeep(hd.b, after)
		else
			marketCache[hd.b] = nil -- 적혔는지 모른다: 맡긴 채로 둔다(「완료」가 견준다)
		end
	end
	sendSelf(s)
	sendBag(s)
	return true, nil, out
end
-- 끝낸 결과의 알림 글
local function marketFinishMsg(hd, out): string
	if out.lost then
		return MWORDS.lost
	end
	local parts = {}
	if out.relisted then
		table.insert(parts, Format.fill(MWORDS.relisted, { name = Market.nameOf(Market.withUnits(hd.it, out.left)) }))
	elseif out.left > 0 then
		table.insert(parts, if out.inBag then Format.fill(MWORDS.returned, { name = Market.nameOf(Market.withUnits(hd.it, out.left)) }) else MWORDS.kept)
	end
	if out.pay > 0 or out.fee > 0 then
		local text = Format.fill(MWORDS.paid, { n = Format.comma(out.pay), fee = Format.comma(out.fee) })
		if out.deposit > 0 then
			text ..= Format.fill(MWORDS.paidDeposit, { n = Format.comma(out.deposit) })
		end
		table.insert(parts, text)
	end
	return table.concat(parts, " · ")
end
-- ---------- 경매장에서 내 물건이 팔렸다(2026-10-18) ----------
--  산 사람의 서버가 알린다: 판 사람이 이 서버에 있으면 바로(「Sold」), 아니면 다른 서버들에(MessagingService의 SOLD_TOPIC — 그 사람이 있는 서버가 받아 알린다).
--  화면은 획득 알림에 「팔림: 「이름」 xN」 한 줄 · 「경매」 단추에 점. 대금은 전처럼 「완료」에서 받는다(알림은 보이기만 — 못 받아도 잃는 것이 없다)
local SOLD_TOPIC = "LuneSold"
local function soldHere(userId: number, name: string, n: number): boolean
	for p, s in sessions do
		if p.UserId == userId and s.hero then
			fire("Sold", p, { name = name, n = n })
			return true
		end
	end
	return false
end
function World.notifySold(userId: number, name: string, n: number)
	if soldHere(userId, name, n) then
		return
	end
	task.spawn(function()
		pcall(function()
			game:GetService("MessagingService"):PublishAsync(SOLD_TOPIC, { u = userId, name = name, n = n })
		end)
	end)
end
local function listenSold()
	task.spawn(function()
		pcall(function()
			game:GetService("MessagingService"):SubscribeAsync(SOLD_TOPIC, function(msg)
				local d = msg and msg.Data
				if typeof(d) == "table" and typeof(d.u) == "number" and typeof(d.name) == "string" and typeof(d.n) == "number" then
					soldHere(d.u, d.name, d.n)
				end
			end)
		end)
	end)
end

-- 유료 상품으로 받은 아이템(GOODS의 paid)을 거래하지 못하게 해야 하는 이용자인가 — 로블록스 정책의 값(IsPaidItemTradingAllowed)이 false일 때만(읽지 못했으면 막지 않는다)
--  공식 문서는 이 규칙을 확률형 결과물에 대해 적었다. 우리 유료 아이템은 확률이 없지만, 막힌 이용자에게는 같은 대로 막아 둔다(2026-10-20 — design/bm.js)
local PAID_LOCKED = "이 계정은 유료 상품으로 받은 아이템을 거래할 수 없다(로블록스 정책)"
local function paidLocked(s, row: any): boolean
	if typeof(row) ~= "table" or typeof(row.g) ~= "string" then
		return false
	end
	local def = Items.goods(row.g)
	return def ~= nil and def.paid == true and typeof(s.policy) == "table" and s.policy.IsPaidItemTradingAllowed == false
end

local function onMarket(player, action: string, a: any, b: any, c: any, d: any)
	local s = sessions[player]
	if not s or not s.hero or not s.acct then
		return nil
	end
	local h, now, userId, book = s.hero, os.time(), player.UserId, s.acct.market
	local function reply(ok: boolean?, why: string?, extra: any)
		local out = extra or {}
		out.ok, out.why, out.now = ok == true, why, now
		out.used, out.max = Market.count(book), MARKET.slots + Cash.marketPlus(s.acct, now) -- 달빛 패스가 있는 시즌이면 칸이 더(2026-10-20)
		return out
	end
	if s.guest then
		return reply(nil, MWHY.guest)
	elseif s.shop or not Town.is(s.scene) then
		return reply(nil, MWHY.town) -- 경매장은 마을에서만(2026-10-21 사용자 "경매장도 마을에서만 갈수있어야하구요") · 달빛 상점 안에서도 아니다
	elseif not h.alive then
		return reply(nil, MWHY.dead)
	elseif s.marketBusy then
		return reply(nil, MWHY.busy)
	end
	local function listing(board: string, doc: any)
		return { rows = Market.rows(doc, now, userId), trades = Market.trades(doc, now), board = board }
	end
	local function work()
		if action == "mine" then
			return reply(true, nil, { mine = marketMine(s, now, a == true and canForce(s)) })
		elseif action == "browse" then
			-- a = 장부 · b = 지금의 것으로(새로 고침). 목록과 시세(그 분류의 최근 거래)를 함께 준다
			if not Market.isBoard(a) then
				return reply(nil, MWHY.item)
			end
			-- 새로 고침(저장소를 다시 읽는다)은 한 사람이 10초에 한 번(2026-10-18 검토: 장부를 돌아가며 새로 고쳐 서버의 저장소 몫을 다 쓸 수 있었다) — 그 사이에는 둔 것을 보여 준다
			local got, doc = marketDoc(a, b == true and canForce(s))
			if not got then
				return reply(nil, MWHY.off)
			end
			return reply(true, nil, listing(a, doc))
		elseif action == "list" then
			-- a = 가방의 탭 · b = 칸 · c = 수(묶음) · d = { 값(개당), 시간 }
			local price, hours = if typeof(d) == "table" then d[1] else nil, if typeof(d) == "table" then d[2] else nil
			if (a ~= "gear" and a ~= "use" and a ~= "etc") or typeof(b) ~= "number" or b ~= math.floor(b) or b < 1 or b > Bag.size(h) then
				return reply(nil, MWHY.item)
			end
			local held = h[a][b]
			if not held then
				return reply(nil, MWHY.item)
			elseif not Market.priceOk(price) or not Market.hoursOk(hours) then
				return reply(nil, MWHY.price)
			elseif Market.count(book) >= MARKET.slots + Cash.marketPlus(s.acct, now) then
				return reply(nil, MWHY.slots)
			end
			local row
			if a == "gear" then
				row = Market.pack(held)
			else
				if typeof(c) ~= "number" or c ~= math.floor(c) or c < 1 or c > held.n then
					return reply(nil, MWHY.item)
				end
				row = { g = held.item, n = c }
			end
			local can, whyNot = Market.sellable(Market.unpack(row))
			local board = Market.boardOf(row)
			if can and paidLocked(s, row) then
				return reply(nil, PAID_LOCKED)
			end
			if not can or not board then
				return reply(nil, whyNot or MWHY.item)
			elseif h.money < MARKET.deposit then
				return reply(nil, MWHY.deposit)
			end
			-- 가방에서 빼고 보증금을 낸 뒤 맡긴 것에 적고, 계정을 먼저 저장한다
			if a == "gear" then
				h.gear[b] = false
			else
				held.n -= row.n
				if held.n <= 0 then
					h[a][b] = false
				end
			end
			h.money -= MARKET.deposit
			local id = Market.nextId(book, userId, now)
			book.list[id] = { b = board, it = row, p = price, t = now, e = now + hours * 3600, got = 0, d = MARKET.deposit }
			local function undo() -- 올리지 않았다: 가방으로 되돌리고 보증금을 돌려준다(그 사이에 가방이 찼으면 맡아 둔다)
				book.list[id] = nil
				h.money += MARKET.deposit
				marketTake(s, row, now)
				saveSoon(s)
				sendBag(s)
				sendSelf(s)
			end
			if not saveNow(s) then
				undo()
				return reply(nil, MWHY.save)
			end
			local entry = Market.entry(id, userId, s.name, row, price, hours, now)
			local wrote, whyFull, _, doc = Store.marketUpdate(board, function(old)
				return Market.txList(old, entry, now)
			end)
			sendBag(s)
			sendSelf(s)
			if not wrote then
				-- 저장소가 답하지 않았다: 줄이 적혔는지 알 수 없다 — 되돌리면 물건이 둘이 될 수 있으니 맡긴 채로 둔다(「완료」가 장부와 견준다: 줄이 있으면 판매 중, 없으면 반환)
				marketCache[board] = nil
				return reply(nil, MWORDS.unsure, { mine = marketMine(s, now, false) })
			elseif whyFull then
				undo()
				return reply(nil, whyFull)
			end
			marketKeep(board, doc)
			return reply(true, nil, { msg = Format.fill(MWORDS.listed, { name = Market.nameOf(row) }), mine = marketMine(s, now, false) })
		elseif action == "buy" then
			-- a = 장부 · b = 줄 · c = 사는 수 · d = 본 값(개당)
			if not Market.isBoard(a) or typeof(b) ~= "string" or not Market.priceOk(d) or typeof(c) ~= "number" or c ~= math.floor(c) or c < 1 or c > 9999 then
				return reply(nil, MWHY.gone)
			end
			local got, doc = marketDoc(a, false)
			local seen = if got then Market.entryById(doc, b) else nil
			if got and not seen and canForce(s) then
				got, doc = marketDoc(a, true)
				seen = if got then Market.entryById(doc, b) else nil
			end
			if not got then
				return reply(nil, MWHY.off)
			elseif not seen or Market.stateOf(seen, now) ~= "selling" or not Market.unpack(seen.it) then
				return reply(nil, MWHY.gone, listing(a, doc))
			elseif seen.u == userId then
				return reply(nil, MWHY.mine)
			elseif c > seen.l then
				return reply(nil, MWHY.count, listing(a, doc))
			elseif paidLocked(s, seen.it) then
				return reply(nil, PAID_LOCKED)
			end
			local cost = d * c
			if h.money < cost then
				return reply(nil, MWHY.money)
			elseif Market.holds(book) >= MARKET.holdMax then
				return reply(nil, MWHY.hold)
			end
			local token = Market.nextToken(book, now)
			h.money -= cost -- 먼저 뺀다(저장소를 기다리는 동안 같은 달돈을 다른 데 쓰지 못한다) — 못 사면 돌려준다
			local wrote, why, entry, after = Store.marketUpdate(a, function(old)
				return Market.txBuy(old, b, userId, c, d, now, token)
			end)
			if not wrote then
				-- 저장소가 답하지 않았다: 다시 읽어, 이 구매가 적혀 있으면 산 것이다 — 반드시 지금의 값으로(fresh). 캐시의 옛 값을 읽으면
				--  적힌 구매를 「못 샀다」로 보고 돈을 돌려줘, 물건은 아무에게도 가지 않고 판 사람은 대금을 받았다(2026-10-27 — 시험 101이 재현)
				local again, doc2 = Store.marketRead(a, true)
				local mineNow = if again then Market.boughtBy(doc2, b, userId, token) else nil
				if mineNow then
					wrote, why, entry, after = true, nil, mineNow, doc2
				end
			end
			if not wrote or why or not entry then
				h.money += cost
				if wrote then
					marketKeep(a, after)
				else
					marketCache[a] = nil
				end
				return reply(nil, why or MWHY.off, listing(a, if wrote then after else doc))
			end
			marketKeep(a, after)
			-- 산 것은 「완료」에 「낙찰」로 들어온다(거기서 수령한다 — 메이플 옥션)
			local row = Market.withUnits(entry.it, c)
			World.notifySold(seen.u, Market.nameOf(row), c) -- 판 사람에게 「팔림」(2026-10-18)
			marketHold(s, row, cost, now)
			saveNow(s) -- 값을 치른 물건은 바로 저장한다
			sendSelf(s)
			local extra = listing(a, after)
			extra.msg = Format.fill(MWORDS.bought, { name = Market.nameOf(row) })
			extra.mine = marketMine(s, now, false)
			return reply(true, nil, extra)
		elseif action == "settle" then
			-- a = 내 것의 번호 · b = 하려는 일: "take" 수령(낙찰) · "collect" 대금 수령 · "back" 판매 취소 / 반환 · "relist" 재등록
			local hd = if typeof(a) == "string" then book.list[a] else nil
			if not hd then
				return reply(nil, MWHY.gone, { mine = marketMine(s, now, false) })
			end
			if hd.hold then
				local ok, why = marketReceive(s, a, hd)
				if not ok then
					return reply(nil, why)
				end
				sendBag(s)
				return reply(true, nil, { msg = Format.fill(MWORDS.taken, { name = Market.nameOf(hd.it) }), mine = marketMine(s, now, false) })
			end
			if b == "collect" then
				local ok, _, r = marketLook(s, a, hd, now, true)
				if not ok then
					return reply(nil, MWHY.off)
				elseif r.state == "selling" then
					-- 아직 팔리는 중: 팔린 만큼의 대금만 받는다
					if r.due <= 0 then
						return reply(nil, MWHY.nothing, { mine = marketMine(s, now, false) })
					end
					local pay, fee = marketCollect(s, hd, r)
					sendSelf(s)
					return reply(true, nil, { msg = Format.fill(MWORDS.paid, { n = Format.comma(pay), fee = Format.comma(fee) }), mine = marketMine(s, now, false) })
				end
			elseif b ~= "back" and b ~= "relist" then
				return reply(nil, MWHY.item)
			end
			local ok, why, out = marketFinish(s, a, hd, now, b == "relist")
			if not ok then
				return reply(nil, why, { mine = marketMine(s, now, false) })
			end
			return reply(true, nil, { msg = marketFinishMsg(hd, out), mine = marketMine(s, now, false) })
		elseif action == "all" then
			-- 모두 받기: 낙찰을 수령하고, 팔린 것의 대금을 받고, 끝난 것(미판매 · 다 팔린 것)을 돌려받는다. 판매 중인 것은 그대로 둔다(대금만 받는다)
			local ids = {}
			for id in book.list do
				table.insert(ids, id)
			end
			table.sort(ids)
			local done, stuck, paid = 0, false, 0
			for _, id in ids do
				local hd = book.list[id]
				if hd and hd.hold then
					if marketReceive(s, id, hd) then
						done += 1
					else
						stuck = true
					end
				elseif hd then
					local ok, _, r = marketLook(s, id, hd, now, true)
					if not ok then
						stuck = true
					elseif r.state == "selling" then
						if r.due > 0 then
							paid += marketCollect(s, hd, r)
							done += 1
						end
					else
						local fine, _, out = marketFinish(s, id, hd, now, false)
						if fine then
							done += 1
							paid += if out then out.pay + out.deposit else 0
						else
							stuck = true
						end
					end
				end
			end
			sendSelf(s)
			sendBag(s)
			local msg = if done == 0 then (if stuck then MWHY.bag else MWORDS.allNone) else Format.fill(if stuck then MWORDS.allPart else MWORDS.allDone, { n = done })
			return reply(done > 0, if done == 0 then msg else nil, { msg = if done > 0 then msg else nil, mine = marketMine(s, now, false), paid = paid })
		end
		return reply(nil, MWHY.item)
	end
	s.marketBusy = true
	saving += 1
	local ok, out = pcall(work)
	saving -= 1
	s.marketBusy = nil
	if not ok then
		warn("[lune] 경매장을 처리하다 오류: " .. tostring(out))
		return reply(nil, MWHY.off)
	end
	return out
end

-- 파티: 초대 · 받기 · 거절 · 나가기. 처음부터 맺는다(사용자 2026-10-13: "게임시작부터 그냥 열리면되지 왜 10부터인가요?" — 전에는 Lv.10부터였다). 초대는 같은 맵에 있는 사람에게만.
--  문턱은 공방의 창 목록(data/ui.generated.luau의 windows — 파티 창이 열리는 레벨)에서 읽는다: 화면과 서버가 같은 수를 쓴다
local PARTY_FROM = 1
for _, w in require(ReplicatedStorage.shared.lune.data["ui.generated"]).windows do
	if w.id == "party" then
		PARTY_FROM = w.from
	end
end
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
		-- 업적: 다른 사람과 처음 파티를 맺는다 — 들어온 사람과 파티의 다른 사람들 모두(이미 해낸 사람에게는 셈만 오른다)
		for _, uid in party.members do
			local ms = byUser[uid]
			if ms and ms.acct then
				Achieve.add(ms.acct.ach, "party")
			end
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
		local left = partyLeave(me)
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
	if not s.hero.alive then
		Hero.revive(s.hero) -- (moveTo와 같다 — 관리 이동으로 쓰러진 사람을 옮겼다)
	end
	place(s, key, scene.spawn.x, scene.spawn.y, true)
	local room = roomOf(s.scene):describe(s.hero.id)
	room.who = roster(s.scene)
	fire("Revive", player, { scene = s.scene, x = s.hero.x, y = s.hero.y, room = room })
	sendSelf(s)
	sendWho(from)
	sendWho(s.scene)
	return true
end

-- 꿈(튜토리얼)을 마친 것으로 하고 사당에서 깨어나게 한다(자동 검사 · 관리 — 2026-10-14). 꿈 밖에 있어도 튜토리얼을 마친 것으로 고친다
function World.wake(player): boolean
	local s = sessions[player]
	if not s or not s.hero then
		return false
	end
	Tutorial.finish(s.hero.tut)
	if s.acct then
		s.acct.tutDone = true
	end
	s.dirty = true
	if Tutorial.isDream(s.scene) then
		return World.jump(player, Tutorial.DATA.exit)
	end
	sendSelf(s)
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
	if what == "macroList" then
		-- 매크로 확인(2026-10-23): 이 서버의 사람들(의심이 높은 차례) · 최근 일
		local guard = require(script.Parent.macroGuard)
		local rows = guard.list(sessions)
		return { ok = true, msg = ("이 서버의 사람 %d명"):format(#rows), rows = rows, log = guard.log }
	elseif what == "macroSend" or what == "macroClear" then
		-- 그 사람에게 지금 문제를 보낸다 · 보상 멈춤과 놓친 기록을 풀어 준다(a = 그 사람의 UserId)
		local target = byUser[a]
		if not target or not target.hero then
			return no("이 서버에 없는 사람이다")
		end
		local guard = require(script.Parent.macroGuard)
		if what == "macroSend" then
			guard.force(target)
			return { ok = true, msg = (target.name or "") .. "에게 매크로 확인을 보냈다" }
		end
		guard.clear(target)
		return { ok = true, msg = (target.name or "") .. "의 보상 멈춤을 풀었다" }
	elseif what == "ban" then
		-- 정지(2026-10-26 사용자: "클라 라는 닉네임 유저 찾아서 ip 까지 딴다음에 아예 게임못하게 정지시켜"): a = 닉네임 · b = "find" · "ban" · "unban" — 로블록스의 정지(server/lune/modules/ban.luau)
		return require(script.Parent.ban).run(player, a, b)
	elseif what == "candy" or what == "candyClear" then
		-- 기간 이벤트의 사탕(2026-10-29 사용자: "나 어드민 호박사탕 지급 탭 만들어주고" — 관리 창 「이벤트」 탭): a = 이벤트의 이름표 · b = 받을 사람의 닉네임(""이면 나) · c = 수
		--  나 · 이 서버에 그 캐릭터로 있는 사람 = 바로 가방에 · 그 밖 = 선물 상자(server/lune/modules/gifts.luau — 다른 서버에 있으면 곧 · 접속하지 않았으면 다음에 그 캐릭터로 들어올 때)
		--  candyClear = 내 사탕을 모두 뺀다(모자랄 때를 시험할 때)
		local e = require(lune.sim.event).def(a)
		if not e then
			return no("없는 이벤트다")
		end
		local cid = e.candy.id
		local cname = (Items.goods(cid) or {}).name or cid
		if what == "candyClear" then
			local had = Bag.count(h, cid)
			if had > 0 then
				Bag.take(h, cid, had)
			end
			s.dirty = true
			sendBag(s)
			return done(("%s %d개를 뺐다"):format(cname, had))
		end
		local Gifts = require(script.Parent.gifts)
		if not wholeIn(c, 1, Gifts.MAX) then
			return no(("수는 1~%d"):format(Gifts.MAX))
		end
		local name = if typeof(b) == "string" then string.gsub(string.gsub(b, "^[ 	]+", ""), "[ 	]+$", "") else ""
		if name == "" or Account.nameKey(name) == Account.nameKey(s.name or "") then
			local ok, why = Bag.give(h, cid, c)
			if not ok then
				return no(why or Bag.FULL)
			end
			s.dirty = true
			sendBag(s)
			return done(("나에게 %s +%d"):format(cname, c))
		end
		local uid, shown = require(script.Parent.ban).find(name)
		if not uid then
			return no(shown)
		end
		local t = byUser[uid]
		if t and t.hero and t.name and Account.nameKey(t.name) == Account.nameKey(shown) and Bag.give(t.hero, cid, c) then
			t.dirty = true
			sendBag(t)
			fire("Megaphone", t.player, Format.fill(Gifts.WORDS.got, { what = ("%s +%d"):format(cname, c) }))
			return { ok = true, msg = ("%s에게 %s +%d — 바로 들어갔다(이 서버)"):format(t.name, cname, c) }
		end
		local stored, told = Gifts.send(uid, Account.nameKey(shown), cid, c, os.time())
		if not stored then
			return no("선물 상자에 적지 못했다 — 다시 눌러 주세요")
		end
		return { ok = true, msg = ("%s에게 %s +%d — %s"):format(shown, cname, c, if told then "접속 중이면 곧 · 아니면 다음 접속 때" else "다음 접속 때(다른 서버에 알리지 못했다)") }
	elseif what == "megaphone" then
		-- 확성기(2026-10-21 사용자: "모든 서버에 확성기로 말할수있나? 어드민기능으로 확성기같은게 필요한데") — 글을 거른 뒤 모든 서버의 모두에게(server/lune/modules/megaphone.luau)
		local ok, msg = require(script.Parent.megaphone).send(player, a, os.time())
		return { ok = ok, msg = msg }
	elseif what == "title" then
		-- 칭호를 내 캐릭터에 넣어 보기 · 모두 빼기(2026-10-26 사용자: "나 어드민으로 껴볼수있게 해야지 난디자인을 봐야하는데"): a = 칭호의 이름표(받고 바로 단다) · ""(가진 칭호를 모두 뺀다).
		--  세계 기록(1위 · 열 사람)은 건드리지 않는다 — 이 캐릭터에만. 방 사람들의 이름표에도 바로
		local Titles = require(lune.sim.titles)
		if a == "" then
			-- 모두 뺀다 — 운영자 칭호(rule admin)는 갖고 있되 떼기만 한다(빼도 1초 뒤에 서버가 다시 넣어 달아 버린다)
			for id in h.titles do
				local t = Titles.def(id)
				if not (t and t.rule == "admin") then
					h.titles[id] = nil
				end
			end
			h.title = nil
		elseif Titles.def(a) then
			Titles.give(h, a)
			Titles.wear(h, a)
		else
			return no("없는 칭호다")
		end
		s.dirty = true
		sendWho(s.scene)
		return done(if a == "" then "칭호를 모두 뺐다" else ("「%s」를 달았다"):format(Titles.def(a).name))
	elseif what == "rankMounts" then
		-- 순위 사슴(백금 · 실버 · 동색 — free max · max2 · max3) 넣어 보기 · 빼기(2026-10-26 사용자: "그리고 나도 볼수있어야지"): 내 계정에만 · 바로 저장 · 가방 「캐시」 탭과 방 사람들의 화면을 고친다
		if a ~= "give" and a ~= "take" then
			return no("모르는 일이다")
		end
		local c = s.acct.bm
		local n = 0
		for _, id in CashServer.rankMounts() do
			if a == "give" and not c.mounts[id] then
				c.mounts[id] = true
				n += 1
			elseif a == "take" and c.mounts[id] then
				c.mounts[id] = nil
				n += 1
				if c.mount == id then
					c.mount = false -- 고른 탈것이었으면 고르지 않은 것으로(타고 있었으면 내린다 — 탄 동안인지는 bm.mount를 본다)
				end
			end
		end
		if not saveNow(s) then
			return no("저장하지 못했다 — 다시 눌러 주세요")
		end
		fire("CashGot", player, "")
		sendWho(s.scene)
		return done(if a == "give" then ("순위 사슴 %d마리를 넣었다(가방 「캐시」 탭)"):format(n) else ("순위 사슴 %d마리를 뺐다"):format(n))
	elseif what == "coupons" then
		-- 쿠폰 기록 지우기(내 계정 — 쿠폰을 처음 넣는 것부터 다시 해 볼 때 · 2026-10-21): 쓴 쿠폰 · 쿠폰 펫 · 쿠폰 탈것을 지우고 바로 저장 · 화면과 같은 맵의 사람들에게 알린다
		local codes, pets = CashServer.resetCoupons(s.acct)
		if not saveNow(s) then
			return no("저장하지 못했다 — 다시 눌러 주세요")
		end
		fire("CashGot", player, "") -- 화면이 가진 것을 다시 읽는다(가방의 캐시 탭)
		sendWho(s.scene) -- 꺼내 둔 쿠폰 펫 · 타고 있던 쿠폰 탈것이 사라진다
		return done(("쿠폰 기록 %d개 · 쿠폰 펫 · 탈것 %d개를 지웠다"):format(codes, pets))
	elseif what == "xp" then
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
	elseif what == "rare" then
		-- 주간 보스의 이름 붙은 장비의 확률(%)을 시험할 때(2026-10-27 사용자 "나는 이런 희귀아이템 확률조절해서 테스트할수있게해줘"): 이 세션에만 · 저장하지 않는다.
		--  이 사람이 든 파티의 격파에만 걸린다(격파로 적힌 사람 가운데 누구라도 걸어 두었으면 그 가운데 가장 큰 값) · 0 = 설계의 값
		if typeof(a) ~= "number" or a ~= a or a < 0 or a > 100 then
			return no("0 ~ 100%")
		end
		s.rareTest = if a > 0 then a else nil
		return done(if a > 0 then ("희귀 장신구 확률 %d%%(내가 든 파티의 격파에만)"):format(a) else "희귀 장신구 확률: 설계의 값")
	elseif what == "box" then
		-- 보상의 방을 바로 열어 본다(2026-10-28): 첫 주간 보스 · 노말 · 하드 — 나 혼자 · 이번 주의 격파를 적지 않는다 · 상자의 보상은 진짜로 들어온다(관리자의 계정)
		local Weekly = require(lune.sim.weekly)
		local mode = if a == "hard" then "hard" else "normal"
		local b = Weekly.DATA.bosses[1]
		if not b or not h.alive then
			return no("쓰러져 있다")
		end
		World.openBoxFor({ s }, b.id, mode, { [h.id] = true }, Cash.dropMul(h), s.rareTest)
		return done(("보상의 방(%s)"):format(Weekly.DATA.modes[mode].name))
	elseif what == "fly" then
		-- 매크로 방지 날파리를 지금 나에게(2026-10-28 — 매크로로 보일 때를 기다리지 않고 본다): 사냥터에서만
		if not require(script.Parent.macroGuard).huntScene(s.scene) then
			return no("사냥터에서만 부를 수 있다")
		elseif not h.alive then
			return no("쓰러져 있다")
		elseif not roomOf(s.scene):sendFly(h) then
			return no("이미 날파리가 쫓고 있다")
		end
		fire("Fly", player)
		return done("날파리를 불렀다")
	elseif what == "unique" then
		-- 이름 붙은 장비를 바로 받는다(끼워 보기 · 강화해 보기 — 2026-10-27)
		local Items_ = require(lune.sim.items) -- (지역 이름의 한도 — 여기서 부른다)
		if not Items_.unique(a) then
			return no("모르는 이름표다")
		elseif Bag.free(h, "gear") < 1 then
			return no("가방의 장비 칸이 한 칸 비어 있어야 한다")
		end
		local it = Items_.makeUnique(a)
		Bag.add(h, it)
		s.dirty = true
		sendBag(s)
		return done(("「%s」를 가방에"):format(Items_.name(it)))
	elseif what == "week" then
		-- 주간 보스를 바로 해 볼 때(2026-10-27 그림자 사수 — 10-24에 「보스」 탭과 같이 뺀 것을 하나만 다시): 그 보스 퀘스트와 그 앞의 메인을 끝낸 것으로 ·
		--  레벨이 노말 입장보다 낮으면 올린다 · 이번 주 격파 기록을 지운다 · 보스의 문 앞으로 옮긴다
		local Weekly = require(lune.sim.weekly) -- (지역 이름의 한도 — 여기서 부른다)
		local b0 = Weekly.boss(a)
		if not b0 then
			return no("모르는 보스다")
		end
		local q = Quests.def(b0.quest)
		local cur = q and q.after and Quests.def(q.after)
		while cur do
			h.quests[cur.id] = { done = true, c = {} }
			cur = cur.after and Quests.def(cur.after)
		end
		h.quests[b0.quest] = { done = true, c = {} }
		if h.level < b0.normal.need then
			Hero.setLevel(h, b0.normal.need)
		end
		h.rift = h.rift or {}
		if h.rift.week then
			h.rift.week[b0.id] = nil
		end
		s.dirty = true
		Hero.syncQuests(h)
		fire("Quests", player, Quests.view(h.quests))
		local dsc = SCENES.scenes[b0.door.scene]
		local dy = dsc.spawn.y
		for _, p in dsc.portals do
			if p.weekly == b0.id then
				dy = p.y
			end
		end
		moveTo(s, b0.door.scene, b0.door.x - 30, dy)
		sendSelf(s)
		return done(("「%s」의 문 앞으로 — 보스 퀘스트 끝냄 · 이번 주 기록 지움"):format(b0.name))
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
	elseif what == "market" then
		-- 경매장을 혼자서 해 볼 때: 「시험 판매자」의 물건 셋(내 직업의 무기 · 모자 · 물약)을 올린다(fill) · 그 물건들을 모두 치운다(clear).
		--  판 사람이 없는 줄(번호 0)이라 사도 대금은 아무에게도 가지 않는다. 물건을 만들어 내는 일이니 관리자만 — 위에서 계정 번호로 가렸다
		local now = os.time()
		if a == "fill" then
			local stage = Items.stageOf(h.level)
			local weapon = Items.make("weapon", stage, 4, h.class)
			weapon.star = math.min(3, Items.starCap(stage))
			local potion = Items.potionFor(h.level)
			local rows = { { Market.pack(weapon), 1000 }, { Market.pack(Items.make("hat", stage, 3)), 300 } }
			if potion then
				table.insert(rows, { { g = potion.id, n = math.min(10, potion.stack) }, 500 })
			end
			local n = 0
			for i, r in rows do
				local board = Market.boardOf(r[1])
				if board then
					local entry = Market.entry(("0_%d_%d"):format(now, i), 0, "시험 판매자", r[1], r[2], MARKET.hours[1], now)
					local wrote, why = Store.marketUpdate(board, function(old)
						return Market.txList(old, entry, now)
					end)
					if wrote and not why then
						n += 1
					end
					marketCache[board] = nil
				end
			end
			return { ok = n > 0, msg = ("경매장에 시험 물건 %d개를 올렸다"):format(n) }
		elseif a == "clear" then
			local n = 0
			for _, board in Market.boards() do
				local wrote, removed = Store.marketUpdate(board, function(old)
					return Market.txPurge(old, 0, now)
				end)
				if wrote and typeof(removed) == "number" then
					n += removed
				end
				marketCache[board] = nil
			end
			return { ok = true, msg = ("경매장의 시험 물건 %d개를 치웠다"):format(n) }
		end
		return no("모르는 일이다")
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
	if what == "cash" then
		-- Studio에서만: n번째 상품을 산 것처럼(로블록스 결제 없이 ProcessReceipt와 같은 길) — 결제 번호는 매번 새로
		local p = Cash.PRODUCTS[math.floor(n)]
		if p then
			CashServer.processReceipt({ PlayerId = player.UserId, ProductId = 0, PurchaseId = ("debug-%d-%d"):format(os.time(), math.random(1, 1e9)), CurrencySpent = 0 }, p.id)
		end
	elseif what == "xp" then
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
-- ---------- 보상의 방(2026-10-28 — sim/weekly.luau · 공방 design/weekboss.js의 box) — World의 함수로(이 파일의 지역 이름은 한도에 닿아 있다) ----------
-- 그 보스의 문 앞(장면 · x · y): 보스의 방 · 보상의 방에서 나갈 때
function World.boxDoor(bossId: string)
	local Weekly = require(lune.sim.weekly)
	local b = Weekly.boss(bossId)
	local dsc = SCENES.scenes[b.door.scene]
	local dy = dsc.spawn.y
	for _, p in dsc.portals do
		if p.weekly == b.id then
			dy = p.y
		end
	end
	return b.door.scene, b.door.x - 30, dy
end

-- 격파한 보스의 방 → 새 보상의 방(wkbox#번호): 방의 사람 모두(쓰러진 사람은 일으켜서). 받을 사람 · 드롭률은 격파할 때 적어 둔 것(room.weekly의 who · mul · test)
World.boxSerial = 0
function World.toBox(room, here)
	local wk = room.weekly
	return World.openBoxFor(here, wk.boss, wk.mode, wk.who or {}, wk.mul, wk.test)
end
-- 사람들(list)을 새 보상의 방으로(관리 「보상의 방」도 이 길로 — 격파를 적지 않고 나 혼자)
function World.openBoxFor(here, bossId: string, mode: string, who, mul: number?, test: number?)
	local Weekly = require(lune.sim.weekly)
	World.boxSerial += 1
	local bkey = Weekly.boxKey(World.boxSerial)
	local broom = roomOf(bkey)
	Weekly.startBox(broom, bossId, mode, who, mul, test)
	local sc = SCENES.scenes[bkey]
	for i, s in here do
		if not s.hero.alive then
			Hero.revive(s.hero)
		end
		moveTo(s, bkey, sc.spawn.x + (i - 1) * 12, sc.spawn.y)
	end
	broom.box.changed = false
	toRoom(bkey, "BoxView", Weekly.boxView(broom))
	return bkey
end

-- 보상의 방이 끝난다(머무는 시간이 다 됐다 · 다들 나갔다): 상자를 아무도 열지 않았으면 열어서, 줍지 않은 달가루 · 달돈은 받을 사람 모두에게(사람마다 같은 합) ·
--  줍지 않은 장비는 받을 사람 가운데 가방에 자리가 있는 하나(차례를 섞어)에게. 접속해 있지 않은 사람에게는 주지 못한다(제가 정한 것 — 사용자 "그냥 파티보상으로 전부 지급되는거야")
function World.boxSettle(room)
	local Weekly = require(lune.sim.weekly)
	local bx = room.box
	if not bx or bx.settled then
		return
	end
	bx.settled = true
	if not bx.opened then
		Weekly.openBox(room, room.lootRng or room.rng)
	end
	local left = Weekly.boxLeft(room)
	local takers = {}
	for id in bx.who do
		local s = byUser[id]
		if s and s.hero and s.hero.id == id then
			table.insert(takers, s)
			if left.dust > 0 or left.money > 0 or #left.goods > 0 then
				s.hero.dust += left.dust
				s.hero.money += left.money
				-- 줍지 않은 소비 아이템(2026-10-28): 사람마다 가방에 들어가는 만큼 · 못 받은 것은 알린다
				local got = {}
				for _, g in left.goods do
					local n = math.min(g.n, Bag.room(s.hero, g.id))
					if n > 0 and Bag.give(s.hero, g.id, n) then
						table.insert(got, { id = g.id, n = n })
					else
						n = 0
					end
					if n < g.n then
						fire("WeekPay", s.player, { short = { item = g.id, n = g.n - n } })
					end
				end
				s.dirty = true
				fire("WeekPay", s.player, { left = true, dust = left.dust, money = left.money, goods = got })
				sendSelf(s)
				sendBag(s)
			end
		end
	end
	local rng = room.lootRng or room.rng
	for _, it in left.items do
		for i = #takers, 2, -1 do
			local j = rng:NextInteger(1, i)
			takers[i], takers[j] = takers[j], takers[i]
		end
		for _, s in takers do
			if Bag.add(s.hero, it) then
				s.dirty = true
				sendBag(s)
				fire("WeekPay", s.player, { item = it.u, mine = true })
				break
			end
		end
	end
end

-- 매크로로 보이는 사람에게 날파리를 보낸다(1초마다 — World.tick · 2026-10-28 사용자 "그냥 뜨는게 아니라 어느정도 매크로라고 판명되면 뜨는걸로하자"). 보냈으면 true
--  사냥터에서 · 매크로 확인을 놓친 「사냥 보상 멈춤」이거나 매크로 의심(누르는 간격이 지나치게 고르다 · 한자리에서 잡는다)일 때(modules/macroGuard.luau의 flyWanted — design/afk.js의 when).
--  문제가 떠 있는 동안 · 연출 중 · 배 위 · 시험용 손님(봇)은 빼고. 잡혀도 아직 그러면 AFK.again초 뒤에 또(World의 함수로 — 지역 이름의 한도)
function World.flyIfMacro(s): boolean
	local AFK = COMBAT.afk
	local h = s.hero
	if not h then
		return false
	end
	local Guard = require(script.Parent.macroGuard)
	-- 더 쫓을 까닭이 없으면(확인을 통과해 보상 멈춤이 풀렸다 · 문제가 떴다 · 사냥터가 아니다 · 장면을 본다) 붙어 있던 날파리도 떠난다(room.luau stepFly — 2026-10-29 사용자
	--  "날파리 작동이 메크로가 아닌 일반인에게 적용되서 괴롭히지않는지 확인하고": 전에는 통과한 뒤에도 이미 붙은 날파리가 그 사람이 쓰러지거나 맵을 떠날 때까지 찔렀다)
	local wanted = h.alive and not h.inCheck and not h.inCine and not s.voyage and not isBot(s.player) and Guard.huntScene(s.scene) and Guard.flyWanted(s)
	h.flyAway = not wanted or nil
	if not wanted or World.now < (s.flyNext or 0) then
		return false
	end
	local room = roomOf(s.scene)
	if room:flyOf(h.id) or not room:sendFly(h) then
		return false
	end
	s.flyNext = World.now + AFK.again
	fire("Fly", s.player)
	return true
end

function World.tick(dt: number)
	World.now += dt
	ticks += 1
	-- 때가 된 판정
	for i = #pending, 1, -1 do
		if pending[i].at <= World.now then
			local job = table.remove(pending, i)
			-- 하나가 잘못돼도(2026-10-18 검토) 나머지 판정 · 이 틱의 다른 일(버프 · 방 · 저장)은 이어 간다
			local ok, err = pcall(job.fn)
			if not ok then
				warn("[lune] 늦은 판정: " .. tostring(err))
			end
		end
	end
	stepBots(dt)
	-- 사람: 무적 · 벌칙 · 물약 대기 시간, 쓰러졌으면 마을에서 일어난다
	for _, s in sessions do
		-- 매크로 확인(2026-10-23): 1초마다 — 때가 되면 문제를 보낸다 · 시간이 다 된 문제는 놓침
		s.macroT = (s.macroT or 0) + dt
		if s.macroT >= 1 and s.hero then
			s.macroT = 0
			require(script.Parent.macroGuard).tick(s, s.scene)
			-- 매크로 방지 날파리(2026-10-28 — design/afk.js): 매크로로 보이면 날파리를 보낸다(World.flyIfMacro)
			World.flyIfMacro(s)
			-- 관리자의 선물(2026-10-29 — server/lune/modules/gifts.luau): 그 캐릭터로 들어온 뒤 한 번 · 다른 서버에서 「보냈다」는 소식이 오면 한 번 — 그 캐릭터의 것을 꺼내 가방에
			if s.cid and s.name and s.name ~= "" and not s.guest and not isBot(s.player) and not s.giftBusy and s.giftKey ~= tostring(s.cid) .. ":" .. s.name then
				s.giftKey, s.giftBusy = tostring(s.cid) .. ":" .. s.name, true
				task.spawn(function()
					local Gifts = require(script.Parent.gifts)
					local got, kept = Gifts.take(s.player.UserId, Account.nameKey(s.name), function(id, n)
						if not s.hero then
							return 0
						end
						local put = math.min(n, Bag.room(s.hero, id))
						if put > 0 then
							Bag.give(s.hero, id, put)
						end
						return put
					end, os.time())
					s.giftBusy = false
					if #got > 0 and sessions[s.player] == s then
						local parts = {}
						for _, g in got do
							local def = Items.goods(g.id)
							table.insert(parts, ("%s +%d"):format(def and def.name or g.id, g.n))
						end
						s.dirty = true
						sendBag(s)
						fire("Megaphone", s.player, Format.fill(Gifts.WORDS.got, { what = table.concat(parts, " · ") }) .. (if kept then " · " .. Gifts.WORDS.kept else ""))
					end
				end)
			end
			CashServer.maxGift(s) -- 레벨 순위 1위 선물(백금 사슴 — 2026-10-25): 처음 만렙(세계 기록)의 캐릭터로 있으면 계정에 넣는다 — 한 사람만(이미 있으면 아무것도 하지 않는다)
			-- 칭호(2026-10-26 — server/lune/modules/titles.luau): 처음 만렙 · 만렙 열 사람의 기록에 있는 캐릭터면 준다(받았으면 알림 · 이름표). 기록에 적는 것은 만렙 최초 달성과 같은 사람만
			local gotTitles, lostTitles = require(script.Parent.titles).grant(s, require(script.Parent.firstMax).get(), s.cid ~= nil and s.name ~= "" and not s.guest and not isBot(s.player) and not Admin.is(s.player) and not World.studio and not Store.isOffline(), World.now, Admin.is(s.player)) -- (운영자 칭호 = 관리자 계정만 — 2026-10-26)
			if #gotTitles > 0 then
				s.dirty = true
				fire("TitleGot", s.player, gotTitles)
				sendSelf(s)
				sendWho(s.scene)
			end
			if lostTitles and #lostTitles > 0 then -- 황금왕이 다른 계정으로 넘어갔다(2026-10-29): 알리고 이름표에서도 뗀다
				fire("TitleGot", s.player, lostTitles, true)
				sendSelf(s)
				sendWho(s.scene)
			end
			-- 만렙 최초 달성(2026-10-24): 이 접속에서 경험치로 막 만렙이 된 캐릭터(h.maxNow)이고 아직 세계 기록이 없으면 적어 본다 — 관리자 · 확인용 임시 계정 · 시험 봇 · Studio는 빼고.
			--  (2026-10-24 사용자: "만렙 달성 알림같은거 이상한사람으로 뜨면 안된다" — 전에는 만렙인 캐릭터가 들어오기만 해도 적어 봐서, 이미 만렙이던 사람 · Studio의 시험 캐릭터가 「처음」으로 적힐 수 있었다)
			if s.hero.maxNow and s.hero.level >= N.MAX_LEVEL and s.cid and s.name ~= "" and not s.guest and not isBot(s.player) and not Admin.is(s.player) and not World.studio and not Store.isOffline() then
				local FirstMax = require(script.Parent.firstMax)
				if not FirstMax.get() then
					FirstMax.try({ key = Rank.charKey(s.player.UserId, s.cid), name = s.name, class = s.hero.class }, World.now)
				end
			end
		end
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
			if not s.guest then
				s.hero.played = (s.hero.played or 0) + dt -- 이 캐릭터로 논 시간(저장한다)
			end
			Analytics.tick(s, dt) -- 레벨 · 퀘스트 · 쓰러짐을 1초마다 보고, 달돈을 60초마다 보낸다
			achTick(s, dt) -- 업적 · 출석(1초마다)
		end
	end
	-- 파티원의 체력과 자리(어느 맵)를 1초에 한 번 알린다
	if ticks % 20 == 0 then
		for _, party in book.parties do
			sendParty(party.members)
		end
	end
	-- 배: 때가 되면 닿는 곳(선장 곁)에 내려 준다
	for _, vs in sessions do
		if vs.voyage and vs.hero and World.now >= vs.voyage.at then
			local r = vs.voyage.route
			vs.voyage = nil
			local x, y = voyageLanding(r)
			moveTo(vs, r.to, x, y)
			fire("Voyage", vs.player, { arrived = r.to, dest = r.dest })
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
				elseif e.type == "elite" then
					toRoom(key, "Elite", { room = key, mob = e.mob, kind = e.kind, x = e.x, y = e.y }) -- 사냥터 정예가 나왔다(2026-10-18)
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
				elseif e.type == "gim" then
					toRoom(key, "Gim", e) -- 보스의 기믹(불씨 도둑 두목 — 폭탄 · 단지 · 불씨 · 연막 · 갈고리 — sim/thiefgim.luau · 화면 thiefView.luau)
				elseif e.type == "pull" then
					local s = byId[e.hero]
					if s then
						s.hero.warpAt = World.now -- 갈고리에 끌려왔다: 그 뒤 잠깐은 멀리 간 자리 보고도 받는다(끌려오기 전에 보낸 자리 · 끌려온 뒤의 자리)
						fire("Pull", s.player, e.x)
					end
				end
			end
			if room.rift then
				-- 토벌: 바뀐 상태를 알리고, 완료면 보상 · 때가 되면 광장으로
				if room.rift.changed then
					room.rift.changed = false
					toRoom(key, "RiftView", Rift.view(room))
					if room.rift.state == "clear" and not room.rift.paid then
						room.rift.paid = true
						riftPay(key, room)
					end
				end
				if Rift.due(room) then
					local t = Rift.tier(room.rift.tier)
					local x, y = riftExitSpot(t)
					local back = if Rift.isDungeon(t) then t.door.scene else Rift.DATA.scene
					for _, s in here do
						if s.hero.alive then
							moveTo(s, back, x, y)
						end
					end
				end
			end
			if room.weekly then
				-- 주간 보스(2026-10-24 — sim/weekly.luau): 바뀐 상태를 알리고, 격파면 방의 사람마다 이번 주의 격파를 적는다 · 때가 되면 보스의 문 앞으로
				local Weekly = require(lune.sim.weekly) -- (world.luau의 지역 이름이 Luau의 한도에 닿아 여기서 부른다)
				local wk = room.weekly
				if wk.changed then
					wk.changed = false
					toRoom(key, "WeekView", Weekly.roomView(room))
					if wk.state == "clear" and not wk.paid then
						wk.paid = true
						local now = os.time()
						-- 격파(2026-10-28 — 보상은 보상의 방의 상자에서: sim/weekly.luau의 openBox · 사용자 "보스를 처치하면 자동으로 모두 보스 보상방으로 이동하고 …"):
						--  그 주의 격파로 적힌 사람 = 받을 사람(who) · 처음이면 그 난이도의 칭호. 드롭률 = 받을 사람 가운데 가장 높은 것(드롭률 쿠폰 · 패스) · 관리자가 걸어 둔 시험의 확률.
						--  box.after초 뒤 방의 사람 모두 보상의 방으로(아래 Weekly.toBox)
						local b = Weekly.boss(wk.boss)
						wk.who, wk.mul, wk.test = {}, 1, nil
						for _, s in here do
							local first = Weekly.mark(s.hero.rift, wk.boss, wk.mode, now)
							s.dirty = true
							Analytics.custom(s, "WeeklyClear", 1, wk.boss .. "_" .. wk.mode)
							if first then
								wk.who[s.hero.id] = true
								wk.mul = math.max(wk.mul, Cash.dropMul(s.hero))
								if s.rareTest then
									wk.test = math.max(wk.test or 0, s.rareTest)
								end
								local title = Weekly.giveTitle(s.hero, b, wk.mode)
								if title then
									fire("TitleGot", s.player, { title })
								end
							end
							fire("WeekPay", s.player, { boss = wk.boss, mode = wk.mode, first = first, view = Weekly.view(s.hero.rift, now) })
						end
					end
				end
				if Weekly.toBox(room) then
					wk.boxAt = nil -- 한 번만
					World.toBox(room, here)
				end
				if Weekly.due(room) then
					local b = Weekly.boss(wk.boss)
					local dsc = SCENES.scenes[b.door.scene]
					local dy = dsc.spawn.y
					for _, p in dsc.portals do
						if p.weekly == b.id then
							dy = p.y
						end
					end
					wk.backAt = nil -- 한 번만
					for _, s in here do
						moveTo(s, b.door.scene, b.door.x - 30, dy)
					end
				end
			end
			if room.box then
				-- 보상의 방(2026-10-28 — sim/weekly.luau): 상자가 열렸다 · 머무는 시간 · 다 되면 남은 것을 나누고 보스의 문 앞으로
				local Weekly = require(lune.sim.weekly) -- (지역 이름의 한도 — 여기서 부른다)
				Weekly.boxStep(room, dt)
				if room.box.changed then
					room.box.changed = false
					toRoom(key, "BoxView", Weekly.boxView(room))
				end
				if Weekly.boxDue(room) and not room.box.settled then
					World.boxSettle(room)
					local dscene, dx, dy = World.boxDoor(room.box.boss)
					for _, s in here do
						if not s.hero.alive then
							Hero.revive(s.hero)
						end
						moveTo(s, dscene, dx, dy)
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
		elseif Rift.tierOfKey(key) or SCENES.base(key) ~= key then
			if room.box then
				World.boxSettle(room) -- 보상의 방이 비었다(다들 나갔다): 줍지 않은 것을 받을 사람들에게(2026-10-28)
			end
			rooms[key] = nil -- 아무도 없는 따로 된 방(토벌 · 파티마다 따로 들어가는 장면 — r1c4#5)은 닫는다(다시 들어가면 새 방 — 스토리 보스도 체력이 가득한 채 새로 선다)
		elseif room.bosses then
			room:idle() -- 아무도 없는 방: 서 있던 스토리 보스를 치운다(다시 들어오면 체력이 가득한 채 새로 선다)
		end
	end
end

-- 유료 상품의 창(2026-10-20 — 공방 js/lune/design/bm.js): a = 하는 일 · b = 그 값
--  "view" → 상품 표 · 보관함 · "buy" b = 상품 → 서버가 한도를 본 뒤 구매 창(주는 것은 ProcessReceipt) · "take" b = 보관함의 줄(없으면 모두) → 가방으로
--  "rename" b = 새 이름 → 이름 바꾸기 주문서 하나를 쓰고 이 캐릭터의 이름을 바꾼다(처음 지을 때와 같은 검사)
local function onCash(player, a: any, b: any)
	local s = sessions[player]
	if not s or not s.acct then
		return { ok = false, why = "아직 들어오지 않았다" }
	end
	local now = os.time()
	if a == "view" then
		CashServer.recheck(s) -- 상점을 열 때 가지지 않았던 패스를 다시 묻는다(게임 밖에서 산 것 — 2026-10-24 · 30초에 한 번까지)
		local view = Cash.view(s.acct, now, s.passes, s.hero and s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok = true
		view.riding = s.riding == true
		return view
	elseif a == "enter" then
		-- 달빛 상점에 들어간다(2026-10-21): 마을에서만 · 살아 있을 때. 들어가 있는 동안 맵에서 빠진다(inRoom) — 다른 사람에게 사라졌다고 알린다
		if not s.hero then
			return { ok = false, why = "캐릭터로 들어간 뒤에 들어간다" }
		elseif not s.shop then
			if not Town.is(s.scene) then
				return { ok = false, why = SHOPSPACE.words.townOnly }
			elseif not s.hero.alive then
				return { ok = false, why = "쓰러져 있을 때는 들어갈 수 없다" }
			end
			s.shop = World.now
			local room = rooms[s.scene]
			if room then
				room:forget(s.hero) -- 남은 늦은 타를 버린다
			end
			sendWho(s.scene)
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok = true
		view.riding = s.riding == true
		return view
	elseif a == "leave" then
		-- 나온다: 들어간 자리로 다시(맵의 그림 · 몬스터 · 사람을 처음부터 받는다 — moveTo가 Revive로 그 장면을 보낸다)
		if s.shop and s.hero then
			s.shop = nil
			moveTo(s, s.scene, s.hero.x, s.hero.y)
		end
		s.shop = nil
		return { ok = true }
	elseif a == "buy" then
		if not s.shop then
			return { ok = false, why = "달빛 상점 안에서 산다" }
		end
		local ok, why = CashServer.prompt(s, b)
		return { ok = ok, why = why }
	elseif a == "take" then
		if not s.hero then
			return { ok = false, why = "캐릭터로 들어간 뒤에 받는다" }
		end
		local moved, left = Cash.take(s.hero, s.acct.bm, b)
		if moved > 0 then
			s.dirty = true
			sendBag(s)
			saveSoon(s)
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero and s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok = moved > 0
		view.why = if moved > 0 then nil elseif left > 0 then "가방에 자리가 없다" else "받을 것이 없다"
		return view
	elseif a == "pet" then
		-- 펫을 꺼낸다(이름표) · 넣는다(false) — 계정의 모든 캐릭터가 같이(2026-10-20)
		local ok, why = Cash.setPet(s.acct, b)
		if ok then
			s.dirty = true
			saveSoon(s)
			if s.scene then
				sendWho(s.scene)
			end
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero and s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok, view.why = ok == true, why
		return view
	elseif a == "wskin" then
		-- 캐시 무기를 장착한다(이름표) · 해제한다(false) — 계정의 모든 캐릭터의 무기(2026-10-23) → 방 사람들의 화면에도(Who)
		local ok, why = Cash.setWskin(s.acct, b)
		if ok then
			s.dirty = true
			saveSoon(s)
			if s.scene and not s.shop then
				sendWho(s.scene)
			end
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero and s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok, view.why = ok == true, why
		return view
	elseif a == "dskin" then
		-- 데미지 스킨을 장착한다(이름표) · 해제한다(false) — 계정의 것(2026-10-29 할로윈 · 사용자 "데미지스킨은 캐시탭에서 꼈다 뺏다 할수있어야하고") → 방 사람들의 화면에도(Who)
		local ok, why = Cash.setDskin(s.acct, b)
		if ok then
			s.dirty = true
			saveSoon(s)
			if s.scene and not s.shop then
				sendWho(s.scene)
			end
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero and s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok, view.why = ok == true, why
		return view
	elseif a == "ride" then
		-- 탄다(탈것의 이름표 — 고른 것도 바뀐다) · 내린다(false). 사다리 위에서 감추는 것은 화면이 한다
		local ok, why = true, nil
		if b == false then
			s.riding = false
		else
			ok, why = Cash.setMount(s.acct, b)
			if ok then
				s.riding = true
				s.dirty = true
				saveSoon(s)
			end
		end
		if s.scene then
			sendWho(s.scene)
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero and s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok, view.why, view.riding = ok == true, why, s.riding == true
		return view
	elseif a == "pass" then
		-- 달빛 패스: 받을 수 있는 보상을 모두 보관함에(물약은 이 캐릭터의 레벨의 것)
		if not s.hero then
			return { ok = false, why = "캐릭터로 들어간 뒤에 받는다" }
		end
		local got = Cash.passClaim(s.acct, now, s.hero.level, s.hero.level)
		if got > 0 then
			s.dirty = true
			saveSoon(s)
		end
		local view = Cash.view(s.acct, now, s.passes, s.hero.level, CashServer.prices(), CashServer.stocks())
		view.ok = got > 0
		view.got = got
		view.why = if got > 0 then nil else "받을 보상이 없다"
		return view
	elseif a == "rename" then
		local h = s.hero
		local c = s.cid and Account.find(s.acct, s.cid)
		if not h or not c then
			return { ok = false, why = "캐릭터로 들어간 뒤에 쓴다" }
		elseif Bag.count(h, "bm_rename") <= 0 then
			return { ok = false, why = "이름 바꾸기 주문서가 없다" }
		elseif typeof(b) ~= "string" or b == c.name then
			return { ok = false, why = "새 이름을 적어 주세요" }
		end
		local ok, why = nameFree(s, b, c.id)
		if ok then
			ok, why = claim(s, b)
		end
		if not ok then
			return { ok = false, why = why }
		end
		local old = c.name
		Bag.take(h, "bm_rename", 1)
		c.name, s.name = b, b
		if old ~= "" then
			pcall(Store.freeName, Account.nameKey(old), player.UserId)
		end
		markName(s)
		s.rankSent = nil
		pushRank(s)
		sendBag(s)
		sendSelf(s)
		saveNow(s)
		return { ok = true, name = b }
	elseif a == "dye" then
		-- 염색약(2026-10-22 — sim/dye.luau · 사용자 "무기 색깔 바꾸는거 할수있어? 로브색깔이나"): b = { part = point · robe, id = 색 · "base"(원래) }.
		--  그 곳의 염색약을 하나 쓰고 이 캐릭터의 색을 바꾼다 → 저장 · 방 사람들의 화면(Who — 다른 사람에게도 그 색으로)
		local Dye = require(lune.sim.dye)
		local h = s.hero
		local part = if typeof(b) == "table" then b.part else nil
		local item = Dye.ITEM[part]
		if not h or not item then
			return { ok = false, why = "캐릭터로 들어간 뒤에 쓴다" }
		elseif Bag.count(h, item) <= 0 then
			return { ok = false, why = Dye.data.words.none }
		end
		local ok, why = Dye.apply(h, part, b.id)
		if not ok then
			return { ok = false, why = why }
		end
		Bag.take(h, item, 1)
		sendBag(s)
		sendSelf(s)
		if not s.shop then
			sendWho(s.scene)
		end
		saveNow(s)
		return { ok = true, part = part, id = b.id, name = Dye.name(part, b.id), look = h.look }
	end
	return { ok = false, why = "모르는 요청" }
end

function World.start()
	-- 플레이어 데이터 기록(server/lune/modules/analytics.luau): 관리자 · 확인용 캐릭터 · 봇은 적지 않는다. 달돈 · 진행을 바꾸는 요청은 Analytics.wrap으로 감싼다(무엇이 달돈을 바꿨는가)
	Analytics.init({
		skip = function(s)
			return s.guest == true or isBot(s.player) or Admin.isId(s.player.UserId)
		end,
	})
	listenSold() -- 다른 서버에서 내 서버의 사람의 물건이 팔렸다는 알림(2026-10-18)
	-- 관리자의 확성기(2026-10-21): 다른 서버에서 보낸 것도 이 서버의 모두에게(캐릭터 고르기 화면에 있는 사람도)
	require(script.Parent.megaphone).start(function(text: string)
		for p in sessions do
			fire("Megaphone", p, text)
		end
	end)
	-- 만렙 최초 달성(2026-10-24): 어느 서버에서 처음 만렙이 나오면 이 서버의 모두에게 축하 알림 · 레벨 판을 바로 다시 읽는다(1위 박제)
	require(script.Parent.firstMax).start(function(rec)
		rankCache = nil
		for p in sessions do
			fire("FirstMax", p, { name = rec.name, class = rec.class, level = N.MAX_LEVEL })
		end
	end)
	-- 칭호(2026-10-26): 만렙 열 사람의 기록을 읽어 둔다(주는 것은 1초마다 — 아래 사람마다의 일)
	require(script.Parent.titles).start()
	-- 관리자의 선물(2026-10-29): 다른 서버에서 「그 계정에 보냈다」 — 이 서버에 있으면 다음 1초에 상자를 연다(사람마다의 일)
	require(script.Parent.gifts).start(function(uid: number)
		local t = byUser[uid]
		if t then
			t.giftKey = nil
		end
	end)
	-- 칭호를 단다 · 뗀다(능력치 창의 「칭호」 줄 — ""이면 뗀다). 가진 것만 — 방 사람들의 이름표에도 바로
	Net.OnServer("Title", function(player, id)
		local s = sessions[player]
		if s and s.hero and require(lune.sim.titles).wear(s.hero, id) then
			s.dirty = true
			sendSelf(s)
			sendWho(s.scene)
		end
	end)
	-- 달빛 상점 안(s.shop)에서는 받지 않는 일 — 움직임 · 기술 · 줍기 · 물약 · 문 · 경매장 · 퀘스트 · 아이템 …(맵에서 빠져 있다 — 2026-10-21)
	World.studio = select(2, pcall(function() return RunService:IsStudio() end)) == true -- Studio에서 도는가(만렙 최초 달성을 적지 않는다 — 2026-10-24)
	local function outside(fn)
		return function(player, ...)
			local s = sessions[player]
			if s and s.shop then
				return nil
			end
			return fn(player, ...)
		end
	end
	World.outside = outside
	onMove, onTravel, onTut, onCine, onHop, onSkill, onReturn = outside(onMove), outside(onTravel), outside(onTut), outside(onCine), outside(onHop), outside(onSkill), outside(onReturn)
	onPickup, onPetPick, onPotion, onDaily, onBond, onRift, onSail = outside(onPickup), outside(onPetPick), outside(onPotion), outside(onDaily), outside(onBond), outside(onRift), outside(onSail)
	onItem, onQuest = outside(onItem), outside(onQuest)
	Net.OnServer("Ready", onReady)
	Net.OnServer("Move", onMove)
	Net.OnServer("Travel", Analytics.wrap("Travel", onTravel, World.session))
	Net.OnServer("Tut", Analytics.wrap("Tut", onTut, World.session))
	Net.OnServer("Cine", Analytics.wrap("Cine", onCine, World.session))
	Net.OnServer("Hop", Analytics.wrap("Hop", onHop, World.session))
	Net.OnServer("Skill", Analytics.wrap("Skill", onSkill, World.session))
	Net.OnServer("Return", Analytics.wrap("Return", onReturn, World.session))
	Net.OnServer("Pickup", Analytics.wrap("Pickup", onPickup, World.session))
	Net.OnServer("PetPick", Analytics.wrap("PetPick", onPetPick, World.session))
	Net.OnServer("Potion", Analytics.wrap("Potion", onPotion, World.session))
	Net.OnServer("Chars", onChars)
	Net.OnServer("Rank", onRank)
	Net.OnServer("Debug", onDebug)
	Net.OnServer("Admin", onAdmin)
	Net.OnServer("Keys", onKeys)
	Net.OnServer("Sound", onSound)
	Net.OnServer("Daily", Analytics.wrap("Daily", onDaily, World.session))
	Net.OnServer("Attend", Analytics.wrap("Attend", onAttend, World.session))
	Net.OnServer("Achieve", Analytics.wrap("Achieve", onAchieve, World.session))
	Net.OnServer("Bond", Analytics.wrap("Bond", onBond, World.session))
	Net.OnServer("Rift", Analytics.wrap("Rift", onRift, World.session))
	-- 주간 보스(2026-10-24 — sim/weekly.luau · 공방 design/weekboss.js): "view" → 보스마다 이번 주의 격파 · "enter" 보스 · 난이도 · 파티인가 → 그 보스의 문 앞(같은 맵 · 가로 60점 안)에서,
	--  문이 열렸고(보스 퀘스트) · 레벨 · 이번 주 아직이면 <방>#wn번호 · #wh번호의 따로 된 방으로. party = 같은 맵의 파티원(그 사람도 들어갈 수 있을 때 · 넷까지)도 함께
	local weekSerial = 0
	Net.OnServer("Week", Analytics.wrap("Week", outside(function(player, action: any, id: any, mode: any, party: any)
		local Weekly = require(lune.sim.weekly)
		local s = sessions[player]
		if not s or not s.hero then
			return nil
		end
		local now = os.time()
		local function reply(ok: boolean?, why: string?)
			return { ok = ok == true, why = why, view = Weekly.view(s.hero.rift, now) }
		end
		if action == "view" then
			return reply(true)
		elseif action == "open" then
			-- 보상의 방의 상자를 연다(2026-10-28 — 받을 사람이 상자 곁에서 ↑): 보상이 흩어진다(sim/weekly.luau의 openBox)
			local room = rooms[s.scene]
			local why = if room then Weekly.canOpen(room, s.hero) else "보상 상자가 없다"
			if why then
				return reply(nil, why)
			end
			local list, item = Weekly.openBox(room, room.lootRng or room.rng)
			for _, d in list or {} do
				toRoom(s.scene, "DropAdd", Room.dropView(d))
			end
			room.box.changed = false
			toRoom(s.scene, "BoxView", Weekly.boxView(room))
			if item then
				Analytics.custom(s, "WeeklyUnique", 1, item.u)
			end
			return reply(true)
		elseif action ~= "enter" then
			return reply(nil, "모르는 일이다")
		end
		local b = Weekly.boss(id)
		if not b or (mode ~= "normal" and mode ~= "hard") then
			return reply(nil, "모르는 보스다")
		elseif s.scene ~= b.door.scene or math.abs(s.hero.x - b.door.x) > 60 then
			return reply(nil, "보스의 문 앞에서 들어갈 수 있다")
		end
		local why = Weekly.canEnter(s.hero, b, mode, now)
		if why then
			return reply(nil, why)
		end
		local going = { s }
		if party == true then
			for _, uid in Party.members(book, s.player.UserId) do
				local ms = byUser[uid]
				if ms and ms ~= s and ms.hero and ms.scene == s.scene and #going < Weekly.DATA.party and not Weekly.canEnter(ms.hero, b, mode, now) and not ms.hero.inCine then
					table.insert(going, ms)
				end
			end
			if #going < 2 then
				return reply(nil, Weekly.DATA.words.partyNone)
			end
		end
		weekSerial += 1
		local key = Weekly.key(b, mode, weekSerial)
		local room = roomOf(key)
		local sc = SCENES.scenes[key]
		for i, ms in going do
			moveTo(ms, key, sc.spawn.x + (i - 1) * 12, sc.spawn.y)
			Analytics.custom(ms, "WeeklyEnter", 1, b.id .. "_" .. mode)
		end
		toRoom(key, "WeekView", Weekly.roomView(room))
		return reply(true)
	end), World.session))
	Net.OnServer("Sail", Analytics.wrap("Sail", onSail, World.session))
	Net.OnServer("Market", Analytics.wrap("Market", onMarket, World.session))
	Net.OnServer("Cash", Analytics.wrap("Cash", onCash, World.session))
	Net.OnServer("Macro", function(player, action, a, b) -- 매크로 확인의 대답 · 「다시 확인」(2026-10-23 — modules/macroGuard.luau)
		local s = sessions[player]
		if not s or not s.hero then
			return { result = "bad" }
		end
		return require(script.Parent.macroGuard).onRemote(s, action, a, b)
	end)
	-- 로블록스 결제: 산 것은 이 셈으로만 준다(server/lune/modules/cash.luau)
	CashServer.start({
		sessionOf = function(userId)
			return byUser[userId]
		end,
		saveNow = saveNow,
		afterSpent = function(s)
			if Admin.is(s.player) or s.guest then
				return -- 관리자 계정은 후원 판에 올리지 않는다(2026-10-15)
			end
			local key = Rank.userKey(s.player.UserId)
			if s.name ~= "" then
				pcall(Store.rankInfoSet, key, { name = s.name, class = if s.hero then s.hero.class else false }, false)
			end
			pcall(Store.rankSet, "robux", key, s.acct.spent, false)
			rankCache = nil
		end,
		notify = function(s, key)
			fire("CashGot", s.player, key)
			if Cash.product(key) and Cash.product(key).kind == "pass" and s.hero then
				sendSelf(s) -- 산 영구 패스의 효과(버프 줄의 「영구」 — 2026-10-22)
			end
			if (Cash.PET[key] or Cash.MOUNT[key]) and s.scene then
				sendWho(s.scene) -- 산 펫을 바로 꺼냈다(꺼내 둔 것이 없었으면) — 다른 사람의 화면에도
			end
		end,
		now = os.time,
	})
	Net.OnServer("Item", Analytics.wrap("Item", onItem, World.session))
	Net.OnServer("Party", onParty)
	Net.OnServer("Quest", Analytics.wrap("Quest", onQuest, World.session))
	onSkill2 = onSkill
	Net.OnServer("Slots", onSlots)
	Net.OnServer("TouchSlots", onTouchSlots)
	Net.OnServer("StatAdd", onStatAdd)
	Net.OnServer("StatAuto", onStatAuto)
	Net.OnServer("SkillUp", onSkillUp)
	Net.OnServer("SkillAuto", onSkillAuto)
	Net.OnServer("SkillReset", onSkillReset)
	-- 능력치 초기화: 찍은 능력치(힘 · 민첩 · 지능 · 운 · 체력)를 모두 되돌려 받는다 — 공짜 · 몇 번이든(2026-10-21 사용자: "스텟, 스킬 초기화 완전무료로 풀겠습니다")
	--  (이 파일의 지역 이름이 Luau의 한도(200)에 닿아 여기에 바로 적는다)
	-- 역마차(2026-10-26 — sim/coach.luau): 정류장의 마부 곁에서 같은 땅의 다른 정류장으로. 마부 곁 · 갈 곳 · 삯 · 달돈 · 몸의 상태를 서버가 다시 본다
	--  (이 파일의 지역 이름이 Luau의 한도(200)에 닿아 여기에 바로 적는다)
	Net.OnServer("Coach", Analytics.wrap("Coach", function(player, to)
		local Coach = require(lune.sim.coach)
		local W = Coach.WORDS
		local s = sessions[player]
		if not s or not s.hero then
			return nil
		end
		local h = s.hero
		if not h.alive or h.inCheck or h.inCine or s.voyage or s.shop or s.loading then
			return { ok = false, msg = W.busy }
		end
		if not nearNpcId(s, "coachman") then
			return { ok = false, msg = W.notHere } -- 마부 곁에서만(2026-10-26 사용자 "npc 통해서 이동하는거야")
		end
		local fare = Coach.fare(s.scene, to)
		if not fare then
			return { ok = false, msg = if Coach.isStation(s.scene) then W.far else W.notHere }
		elseif h.money < fare then
			return { ok = false, msg = W.poor }
		end
		h.money -= fare
		s.dirty = true
		local x, y = Coach.spot(to)
		moveTo(s, to, x, y)
		Analytics.custom(s, "Coach", fare, to)
		return { ok = true, msg = Format.fill(W.done, { name = SCENES.scenes[to].name }) }
	end, World.session))
	-- 기간 이벤트의 상점(2026-10-29 — sim/event.luau · 할로윈의 호박 마녀의 상점 창): 기간 · 마녀 곁 · 사탕 · 가진 것 · 한도 · 가방(받을 자리)을 서버가 다시 본다
	--  (이 파일의 지역 이름이 Luau의 한도(200)에 닿아 여기에 바로 적는다)
	Net.OnServer("EventTrade", Analytics.wrap("EventTrade", function(player, evId, itemId)
		local Event = require(lune.sim.event)
		local s = sessions[player]
		if not s or not s.hero or not s.acct then
			return nil
		end
		local h, c = s.hero, s.acct.bm
		local e = Event.def(evId)
		local W = e and e.words
		if not e then
			return { ok = false, msg = "?" }
		elseif not Event.on(e.id) then
			return { ok = false, msg = W.off }
		elseif not h.alive or h.inCheck or h.inCine or s.voyage or s.shop or s.loading or not nearNpcId(s, e.npc) then
			return { ok = false, msg = W.far }
		end
		local item = Event.item(e, itemId)
		if not item then
			return { ok = false, msg = "?" }
		end
		local band = Cash.bandOf(Cash.topLevel(s.acct, h.level))
		local what = Event.what(e, item, h.level, band)
		local have = Bag.count(h, e.candy.id)
		local owned = Event.owned(e, item, h, c)
		if owned then
			return { ok = false, msg = if item.limit then W.soldOut else W.once }
		elseif have < item.cost then
			return { ok = false, msg = Format.fill(W.short, { have = have, n = item.cost }) }
		end
		-- 받을 자리를 먼저 본다(사탕을 덜기 전에)
		local giveId, giveN = nil, 0
		if item.kind == "potion" then
			local pd = Items.potionFor(h.level)
			giveId, giveN = pd and pd.id, item.n
		elseif item.kind == "goods" then
			giveId, giveN = item.goods, item.n or 1
		end
		if giveId and Bag.room(h, giveId) < giveN then
			return { ok = false, msg = Bag.FULL }
		end
		Bag.take(h, e.candy.id, item.cost)
		local who = false -- 방 사람들의 화면이 바뀌는가(칭호 · 스킨)
		if giveId then
			Bag.give(h, giveId, giveN)
		elseif item.kind == "title" then
			local Titles = require(lune.sim.titles)
			if Titles.give(h, item.title) then
				fire("TitleGot", s.player, { item.title })
				who = true
			end
		elseif item.kind == "mount" then
			c.mounts[item.ride] = true
		elseif item.kind == "pet" then
			c.pets[item.ride] = true
			c.petOut = c.petOut or item.ride
			who = true
		elseif item.kind == "dskin" then
			c.dskins[item.dskin] = true
			c.dskin = c.dskin or item.dskin -- 낀 것이 없으면 바로 낀다(캐시 무기와 같다)
			who = true
		elseif item.kind == "dust" then
			-- 달가루 랜덤 상자(이어서 사용자 "달가루 상자는 더 비싸야해 … 엄청 조금줄수도 엄청 많이줄수도있는 랜덤박스로"): 서버가 굴린다 — 그 레벨대 달가루 상자의 x배(design/event.js의 roll)
			local got, pick = Event.dustRoll(item, band, math.random())
			h.dust += got
			what = Format.fill(W[pick.say or "dustGot"] or W.dustGot, { n = Format.comma(got) })
			item = table.clone(item)
			item.big = pick.big
		end
		if item.limit then
			local key = Event.countKey(e, item)
			c.ev[key] = (c.ev[key] or 0) + 1
		end
		s.dirty = true
		saveSoon(s)
		sendBag(s)
		sendSelf(s)
		if who then
			sendWho(s.scene)
		end
		Analytics.custom(s, "EventTrade", item.cost, e.id .. ":" .. item.id)
		return { ok = true, msg = if item.kind == "dust" then what else Format.fill(W.bought, { what = what }), big = item.big, view = Cash.view(s.acct, World.now, s.passes, h.level, CashServer.prices(), CashServer.stocks()) }
	end, World.session))
	Net.OnServer("Coupon", function(player, text) -- 쿠폰(2026-10-21 — 셈은 CashServer.coupon)
		return CashServer.coupon(sessions[player], text)
	end)
	Net.OnServer("StatReset", function(player)
		local s = sessions[player]
		if s and s.hero and s.hero.alive and Hero.statsSpent(s.hero) then
			Hero.resetStats(s.hero)
			s.dirty = true
			sendSelf(s)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(World.addPlayer, player)
	end)
	Players.PlayerRemoving:Connect(World.removePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(World.addPlayer, player)
	end
	local saveT = 0
	RunService.Heartbeat:Connect(function(dt)
		-- 저장의 때를 먼저 센다(2026-10-18 검토: 틱에서 오류가 나면 그 뒤의 저장 세기까지 건너뛰어, 오류가 이어지면 영영 저장하지 않았다)
		saveT += dt
		if saveT >= SAVE_EVERY then
			saveT = 0
			task.spawn(World.saveAll, true)
		end
		World.saveDue()
		acc = math.min(acc + dt, TICK * 5)
		while acc >= TICK do
			acc -= TICK
			World.tick(TICK)
		end
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
	-- 서버가 닫힌다(Roblox가 기다려 주는 30초 안): 사람마다 따로 · 한꺼번에 저장한다 — 잠금 새로 고침 · 순위판은 건너뛴다
	--  (2026-10-18 검토: 한 사람씩 차례로 잠금 · 계정 · 순위판을 써서, 사람이 많으면 뒤쪽 사람의 마지막 1분이 저장되지 못할 수 있었다)
	stopping = true
	for _, s in sessions do
		if (s.hero or s.dirty) and s.loaded and not s.guest then
			task.spawn(function()
				local ok, err = pcall(saveAccount, s)
				if not ok then
					warn("[lune] 저장하다 오류: " .. tostring(err))
				end
			end)
		end
	end
	-- 나가는 사람의 저장(World.removePlayer — 그 사람은 이미 sessions에서 빠져 위의 saveAll이 보지 못한다)이 아직 쓰이는 중이면 끝날 때까지 기다린다(길어도 STOP_WAIT초).
	--  혼자 하다가 나가면 서버가 곧바로 닫힌다 — 기다리지 않으면 마지막에 바꾼 것(키 설정처럼 방금 바꾼 것)이 저장되지 못한 채 서버가 닫힐 수 있다
	local waited = 0
	while saving > 0 and waited < STOP_WAIT do
		waited += task.wait(0.1) or 0.1
	end
	-- 서버가 닫힌다: 저장한 뒤에 잡고 있던 계정을 모두 푼다
	for _, s in sessions do
		if s.held and Store.unlock then
			pcall(Store.unlock, s.player.UserId)
		end
	end
end

return World
