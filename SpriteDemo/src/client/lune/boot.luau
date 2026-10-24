-- 「달의 계승자」(횡스크롤 MMORPG) 클라이언트의 시작점. shared/config/features.luau의 GAME이 "lune"일 때 client/init.client.luau가 부른다.
--  지금 단계(L2): 처음 오면 직업을 고르고(다섯), 마을과 사냥터를 오가고, 졸개를 기술로 잡아 경험치를 얻고, 떨어진 달돈을 Z로 줍고, 맞으면 체력이 줄고 물약(Ctrl)을 마신다.
--  내 캐릭터의 움직임은 여기서 셈한다(shared/lune/sim/physics.luau를 1/60초 걸음으로). 졸개 · 체력 · 경험치 · 돈의 진실은 서버가 갖는다 —
--  여기는 "하고 싶다"를 보내고, 서버가 알려 준 것을 그린다.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local lune = ReplicatedStorage.shared.lune
local P = require(lune.sim.physics)
local Net = require(lune.net.net)
local Format = require(lune.ui.format)
local Tags = require(lune.ui.tags)
local SCENES = require(lune.data["scenes.generated"])
local ASSETS = require(lune.data["assets.generated"])
local COMBAT = require(lune.data["combat.generated"])
local CHARS = require(lune.data["chars.generated"]) -- 캐릭터와 졸개의 동작(관리 창의 「보스 크기」가 고운 그림이 있는지 본다)
local RIDE_DATA = require(lune.data["ride.generated"]) -- 탈것 · 펫(탄 동안의 빠르기 mountSpeed)
local CLASSES = require(lune.data["classes.generated"])
local Stage = require(script.Parent.stage)
local SceneView = require(script.Parent.sceneView)
local Sprite = require(script.Parent.sprite)
local WeaponFx = require(script.Parent.weaponFx) -- 캐시 무기의 피어오르는 점(2026-10-23)
local Input = require(script.Parent.input)
local MobsView = require(script.Parent.mobsView)
local Overlay = require(script.Parent.overlay)
local Effects = require(script.Parent.effects)
local Cast = require(script.Parent.cast) -- 기술의 이펙트(시험 탭의 것을 옮긴 것)
local Hud = require(script.Parent.hud)
local Title = require(script.Parent.title) -- 처음 화면: 로딩 → START → 캐릭터 고르기(만들기 · 삭제 · 들어가기)
local Music = require(script.Parent.music) -- 장면마다의 배경 음악 · 징글
local MUSIC = require(lune.data["music.generated"])
local Windows = require(script.Parent.ui.windows)
local StatWindow = require(script.Parent.ui.statWindow)
local SkillWindow = require(script.Parent.ui.skillWindow)
local KeysWindow = require(script.Parent.ui.keysWindow)
local SoundWindow = require(script.Parent.ui.soundWindow) -- 설정(메뉴 → 「설정」 — 소리 · 화면)
local ViewOpts = require(script.Parent.viewOpts) -- 화면 설정: 다른 사람의 스킬 효과 · 피해 숫자를 보일지(2026-10-18)
local DailyWindow = require(script.Parent.ui.dailyWindow) -- 일일 의뢰(마을의 의뢰 게시판 앞에서 ↑)
local AttendWindow = require(script.Parent.ui.attendWindow) -- 출석(메뉴 → 「출석」 · 그날 처음 들어오면 한 번 — 2026-10-15)
local AchieveWindow = require(script.Parent.ui.achieveWindow) -- 업적(메뉴 → 「업적」 — 2026-10-15)
local CashWindow = require(script.Parent.ui.cashWindow) -- 달빛 상점(메뉴 → 「달빛 상점」 — 로벅스 상점 2026-10-20)
local CouponWindow = require(script.Parent.ui.couponWindow) -- 쿠폰(메뉴 → 「쿠폰」 — 쿠폰 번호를 적으면 그 펫을 준다 · 2026-10-21)
local CashShop = require(script.Parent.cashShop) -- 달빛 상점의 공간(2026-10-21 — 메이플 캐시샵처럼 들어가는 곳 · 마을에서만)
local Town = require(lune.sim.town) -- 마을인가(달빛 상점 · 경매장은 마을에서만 — 2026-10-21)
local RideView = require(script.Parent.rideView) -- 펫 · 탈것(2026-10-20)
local VoyageView = require(script.Parent.voyageView) -- 배의 갑판에서 「○○까지 n초」(2026-10-16)
local VistaView = require(script.Parent.vistaView) -- 성의 테라스에 들어서면 화면 가득 잠깐 보이는 경관(2026-10-16 밤)
local TomeWindow = require(script.Parent.ui.tomeWindow) -- 모험의 서(메뉴 → 「모험의 서」 — 2026-10-16)
local RiftWindow = require(script.Parent.ui.riftWindow) -- 수정 틈 토벌(광장의 토벌대장 앞에서 ↑ — 2026-10-16)
local Voyage = require(lune.sim.voyage) -- 배(2026-10-16)
local RiftView = require(script.Parent.riftView) -- 토벌 중의 판(물결 · 남은 몬스터 · 시간) · 끝의 판(보상)
local Bond = require(ReplicatedStorage.shared.lune.sim.bond) -- 2편의 호감도 · 모험의 서 · 달조각 · 숨은 이야기(셈 — 화면은 서버가 준 view를 그린다)
local AchieveSim = require(ReplicatedStorage.shared.lune.sim.achieve) -- 업적 달성의 띠(이름 · 할 일)
local AuctionWindow = require(script.Parent.ui.auctionWindow) -- 경매장(메뉴 · Y — 은달 항구의 경매사 앞에서 ↑로도)
local TALK_HOLD = { first = 0.35, next = 0.16 } -- 말하는 중에 뛰기 키를 누르고 있으면: 처음 넘어가기까지 · 그 뒤 한 마디씩 넘어가는 사이(초)
local Talk = require(script.Parent.ui.talk)
local CineView = require(script.Parent.cineView) -- 퀘스트 연출(장면 — 2026-10-15)
local HallStones = require(script.Parent.hallStones) -- 명예의 전당: 비석에 새긴 순위(2026-10-15)
local Cine = require(lune.cine)
local Ui = require(script.Parent.ui.ui)
local TutView = require(script.Parent.tutorial) -- 튜토리얼 「달빛 꿈」의 미션 판(2026-10-14)
local Tutorial = require(lune.sim.tutorial)
local Kit = require(script.Parent.ui.kit) -- 부품 그림(퀘스트의 자리 위에 뜨는 「!」)
local Touch = require(script.Parent.touch)
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local Market = require(lune.sim.market) -- 경매장의 글(「팔림」 알림 — 2026-10-18)
local REVIVE_GAP = require(lune.sim.party).LEVEL_GAP -- 소생이 닿는 레벨 차이(서버의 fallenIn과 같다)
local Buffs = require(lune.sim.buffs) -- 2~4차의 버프(걸 수 있는지 · 다시 쓰기)
local Kitset = require(lune.kitset) -- 직업 묶음(2~4차의 쓰는 스킬의 구간 — 동작과 이펙트)
local Caster = require(lune.sim.caster) -- 2~4차의 쓰는 스킬의 셈(구간의 시간 · 모으는 단계 — 서버와 같은 것)
local KitSim = require(lune.sim.kit) -- 1차의 온오프 사출기 · 핵심 장치 · 패시브의 셈(서버와 같은 것 — 켤 수 있는지 · 얼마나 모이는지를 화면도 안다)
local BagWindow = require(script.Parent.ui.bagWindow)
local EquipWindow = require(script.Parent.ui.equipWindow)
local ShopWindow = require(script.Parent.ui.shopWindow)
local ForgeWindow = require(script.Parent.ui.forgeWindow)
local ItemCell = require(script.Parent.ui.itemCell)
local Others = require(script.Parent.othersView)
local PartyHud = require(script.Parent.partyHud)
local PartyWindow = require(script.Parent.ui.partyWindow)
local Chat = require(script.Parent.chat)
local Quests = require(lune.sim.quests)
local Daily = require(lune.sim.daily) -- 일일 의뢰(마을의 게시판)
local Navi = require(lune.ui.navi) -- 퀘스트 길찾기(셈)
local NaviArrow = require(script.Parent.naviArrow) -- 길찾기의 화살표(캐릭터 머리 위)
local QuestHud = require(script.Parent.questHud)
local Guide = require(script.Parent.guide)
local MapName = require(script.Parent.mapName) -- 맵에 들어서면 위 가운데에 지역 · 맵 이름이 잠깐(2026-10-18)
local GainLog = require(script.Parent.gainLog) -- 얻은 것을 줄로 쌓는 획득 알림(2026-10-18)
local QuestWindow = require(script.Parent.ui.questWindow)
local Grave = require(script.Parent.grave) -- 쓰러진 자리의 비석
local DeathBox = require(script.Parent.ui.deathBox) -- 쓰러졌을 때 묻는 상자(마을로 돌아갈까요?)
local HallWindow = require(script.Parent.ui.hallWindow) -- 명예의 전당(순위판 셋)
local MapWindow = require(script.Parent.ui.mapWindow) -- 월드맵(지역의 맵들)
local BossView = require(script.Parent.bossView) -- 스토리 보스: 예고 · 이펙트 · 화면 위의 체력 바
local Curtain = require(script.Parent.curtain) -- 막: 장면이 바뀔 때 화면을 덮고 그 사이에 새 장면의 그림을 다 불러온다
local AdminWindow = require(script.Parent.ui.adminWindow) -- 관리 창(관리자에게만 메뉴에 보인다 — 명령은 서버가 계정 번호로 다시 가린다)

local STEP = 1 / 60
local MAX_STEPS = 5 -- 한 화면에 따라잡는 걸음 수(멈칫했다가 순간이동하지 않게)
local REPORT = 0.1 -- 내 자리를 서버에 알리는 간격(초)
local RULES = COMBAT.rules
local LINES = RULES.lines -- 타수 나누기: 줄이 뜨는 사이(stagger초) · 줄 사이의 높이(rise점) — 공방 design/combat.js의 COMBAT.lines
local UI_HUD = require(lune.data["ui.generated"]).hud
local UI_DATA = require(lune.data["ui.generated"]) -- 창의 목록(키 없이 「메뉴」 안에 두는 창 — menu · need)
local QUICK = require(lune.data["ui.generated"]).quick -- 퀵슬롯(칸 수 · 칸마다의 기본 키 · 글)
local Quick = require(lune.ui.quick)
local Layout = require(lune.ui.layout)
local QuickEdit = require(script.Parent.ui.quickEdit)

local Boot = {}
local mySkills = {} -- 내 직업의 기술(사냥기 · 보스기 · 이동기 차례로) { id, name, type, order, cd }

local state = {
	bond = nil :: any, -- 2편의 도시 생활(서버의 Bond.view — 2026-10-16)
	rift = nil :: any, -- 수정 틈 토벌의 내 기록(서버의 onRift — { left, clears, why })
	shards = {} :: { any }, -- 이 장면의 아직 못 주운 달조각 { id, x, y, frame }
	who = "axion",
	sceneKey = SCENES.start,
	view = nil :: any,
	over = nil :: any, -- 이 장면의 이름표 · 체력 띠 · 알림 글이 놓이는 층(화면 틀 — overlay)
	mobs = nil :: any,
	fx = nil :: any,
	body = nil :: any,
	sprite = nil :: any,
	me = nil :: any, -- 서버가 알려 준 내 상태
	myId = nil :: any, -- 내 번호와 이름표에 적는 이름
	myName = "",
	others = nil :: any, -- 같은 맵의 다른 사람들(othersView)
	party = nil :: any, -- 서버가 알려 준 내 파티 { leader, members }
	partySet = {} :: { [any]: boolean }, -- 파티원의 번호들
	tag = nil :: any, -- 내 이름표
	quests = {} :: any, -- 서버가 알려 준 내 퀘스트의 상태(sim/quests.luau의 book)
	npcNames = {} :: { [string]: string }, -- 주민 id → 이름(알리미의 「샛별에게 간다」)
	drawQuests = nil :: any, -- 퀘스트가 바뀌었을 때 화면(표시 · 알리미 · 창)을 고치는 함수
	daily = nil :: any, -- 일일 의뢰의 상태(서버가 준 것 — sim/daily.luau의 view)
	navi = nil :: string?, -- 길찾기를 켠 퀘스트(알리미의 화살표 단추 — 이름표)
	naviDir = nil :: string?, -- 지금 화살표의 방향(공중에 뜬 동안에는 땅에 있을 때의 것을 그대로 둔다)
	naviScene = nil :: string?, -- 그 방향을 셈한 맵
	naviArrow = nil :: any, -- 머리 위의 화살표
	fetchDaily = nil :: any, -- 일일 의뢰의 상태를 서버에 다시 묻는 함수(들어왔을 때 · 레벨이 올랐을 때)
	jobSeen = {} :: { [string]: boolean }, -- 받았다고 알린 전직 퀘스트(「달이 부른다」는 받는 순간 한 번만 뜬다)
	spots = {} :: { any }, -- 이 장면에서 ↑를 누를 수 있는 퀘스트의 자리들 { quest, x, y, place, act, mark(! 그림), tag(「↑ 물을 뜬다」) }
	onJob = nil :: any, -- 전직했을 때(칸을 서버의 것으로 맞춘다)
	guide = nil :: any, -- 지금 띄울 조작 안내를 고르는 함수(client/lune/guide.luau)
	bag = nil :: any, -- 서버가 알려 준 가방 · 장비 · 창고(sim/bag.luau의 view)
	-- 창들이 같이 보는 것. detail = 아이템 상세 판을 띄운 창("bag" · "equip" · "shop" — 판은 하나뿐이라 한 창에서 고르면 다른 창이 고른 것은 풀린다)
	--  service = 가방 옆에 열린 것("forge" 강화 창 · "store" 창고 · "shop" 상점 — 가방의 상세 판에 강화 · 맡기기 · 팔기 단추가 생긴다).
	--  bagDrop · bagHover · storeDrop · storeHover · shopDrop = 끌던 것을 놓는 자리를 창끼리 묻는 길(가방 ↔ 창고 · 가방 → 상점 — 그 창이 열려 있는 동안만 있다)
	ui = {
		service = nil :: string?,
		npc = nil :: any,
		forgeTarget = nil :: number?,
		forgeMat = nil :: number?,
		forgeResult = nil :: string?,
		forgeSeq = 0, -- 강화의 결과가 온 횟수(대장장이 창의 연출이 결과를 기다린다 — 2026-10-15)
		forgeWhy = nil :: string?, -- 강화가 안 된 까닭
		forgeTab = nil :: string?, -- 대장장이 창을 그 탭으로(다른 창에서 장비를 올렸을 때)
		forgeDrop = nil :: any, -- 가방의 장비를 끌어다 대장장이 창에 놓는 자리
		craftResult = nil :: any,
		detail = nil :: string?,
		bagDrop = nil :: any,
		bagHover = nil :: any,
		bagShow = nil :: any,
		storeDrop = nil :: any,
		storeHover = nil :: any,
		storeShow = nil :: any,
		shopDrop = nil :: any,
	},
	openNpc = nil :: any, -- 주민이 해 주는 일(상점 · 강화 · 창고)을 여는 함수 — 열었으면 true
	dir = 1,
	clip = "idle",
	clipT = 0,
	clock = 0, -- 걸음으로 센 시간
	now = 0, -- 화면으로 센 시간(그리기 · 이어 그리기에 쓴다)
	acc = 0,
	skill = nil :: any, -- 쓰는 중인 기술 { id, def, seg, t, queued }
	cds = {} :: { [string]: number },
	haste = 1, -- 공격 속도의 배수(버프)
	full = false, -- 만월: 강타를 모으지 않아도 끝까지 모은 것으로 나간다
	buffs = {} :: { any }, -- 걸린 버프(서버가 준 것 — 남은 시간은 받은 때부터 센다)
	buffAt = 0,
	busy = false, -- 문을 지나는 중
	dead = false,
	blink = 0,
	hurtT = 0, -- 맞는 동작이 남은 시간
	holdT = 0, -- 멈칫(타격감): 내가 때린 순간 내 캐릭터와 몬스터의 그림이 멈춰 있는 남은 시간(초 — 그림만. 움직임과 서버의 셈은 그대로 흐른다)
	holdAt = -9, -- 마지막으로 멈칫한 때
	holdNow = 0, -- 멈칫하는 동안 몬스터를 그리는 시계(멈춘 순간의 것)
	deadT = 0, -- 쓰러진 뒤 흐른 시간
	reportT = 0,
	pickT = 0,
	sentX = -1,
	sentY = -1,
	sentDir = 0,
}
Boot.state = state

-- 그림을 불러온다. only = 이름이 이 글들 가운데 하나로 시작하는 것만(없으면 모두) · notify(끝난 수, 모두) = 한 장이 끝날 때마다(로딩 화면의 띠)
local function preload(only: { string }?, notify: ((number, number) -> ())?)
	local list = {}
	for name, id in ASSETS do
		local want = only == nil
		for _, head in only or {} do
			if string.sub(name, 1, #head) == head then
				want = true
			end
		end
		if id ~= "" and want then
			table.insert(list, id)
		end
	end
	local total, done = #list, 0
	if total > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(list, function()
				done += 1
				if notify then
					notify(done, total)
				end
			end)
		end)
	end
	if notify then
		notify(total, total)
	end
end

-- 장면을 바꿔 그린다. room = 서버가 준 그 방의 모습(졸개 · 떨어진 것)
-- 직업 묶음(shared/lune/kits)이 그리는 내 장치의 값: 영혼(리퍼 — 몸 둘레의 구슬) · 열기(살라맨더 — 발밑의 막대). 서버가 준 값을 그대로 넘긴다
local function syncKit()
	local kit = state.me and state.me.kit
	local a = state.actor
	if not kit or not a then
		return
	end
	local s = a.g.s
	if s.souls ~= nil then
		s.souls = kit.souls
	end
	if s.heat ~= nil then
		s.heat = kit.heat
	end
end

-- 달 수정(무니)이 섰다 · 사라졌다: 그 수정의 주인(무니)의 묶음이 그린다. c = { id, owner, x, y, life }
local function crystalAdd(c)
	local cast = state.cast
	local a = cast.actors[c.owner]
	if not a then
		local o = state.others and state.others.list[c.owner]
		a = if o then cast:actor(c.owner, o.class, false) else nil
	end
	local add = a and a.kit and a.kit.procs and a.kit.procs.crystalAdd
	if add then
		add(a.g, c)
	end
end
local function crystalGone(id: number)
	for _, a in state.cast.actors do
		local gone = a.kit and a.kit.procs and a.kit.procs.crystalGone
		if gone then
			gone(a.g, id)
		end
	end
end

-- 내 펫이 떨어진 것에 닿았다(2026-10-20 — rideView.luau): 서버가 펫을 꺼내 두었는지 · 영웅에게서 가까운지 · 주인을 확인하고 줍는다(world.luau의 onPetPick)
local function petPick(id: number, x: number?, y: number?)
	if x and y and state.fx then
		state.fx:pull(id, x, y) -- 펫 쪽으로 빨려 든다(자석 — 2026-10-21)
	end
	Net.FireServer("PetPick", id)
end

-- 펫 꺼내기 · 넣기와 탈것 타기 · 내리기(2026-10-21 사용자: "펫을 넣고 빼는거, 라이딩을 타는거 이런게 달빛상점에 들어가서 하는게 아닙니다" —
--  가방의 캐시 탭 · 퀵슬롯 · N 키가 같이 쓴다). 서버가 정하고 이름표(Who)로 알린다 — 화면의 펫 · 탈것은 그것을 따른다
-- 소비 아이템(물약 · 주문서)을 쓴다 — 서버의 빈도 제한(초당 3번) 안으로: 0.34초 안에 거듭 누른 것은 보내지 않는다
--  (2026-10-21 퍼블리시한 게임의 오류 보고: 'Potion' 요청이 빈도 제한을 넘어 버려졌다 — 버려진 누름은 아무 일도 하지 않았다). what = 그 아이템(nil = 지금 마실 수 있는 가장 좋은 물약)
local potionSent = -9
state.sendPotion = function(what: string?)
	if os.clock() - potionSent < 0.34 then
		return
	end
	potionSent = os.clock()
	Net.FireServer("Potion", what)
end
local function cashInvoke(action: string, a: any)
	local ok, res = pcall(Net.Invoke, "Cash", action, a)
	if ok and res and res.list then
		state.cash = res
		Windows.refresh(state.me)
	end
	if ok and res and res.why and state.fx and state.body then
		state.fx:float(res.why, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
	end
	return if ok then res else nil
end
-- 앞의 꺼내기 · 타기 요청이 끝나기 전에 누른 것은 보내지 않는다(2026-10-21 — 연달아 누르면 서버가 Cash 요청의 빈도 제한(초당 3 · 한꺼번에 6)을 넘긴 것을 버리고
--  「'Cash' 요청이 빈도 제한을 넘어 버려졌다」를 남겼다 · 버려진 누름은 아무 일도 하지 않았다)
local toggling = false
local function once(fn)
	if toggling then
		return
	end
	toggling = true
	task.spawn(function()
		pcall(fn)
		toggling = false
	end)
end
-- 가진 펫 · 탈것을 서버에 묻는다(폰의 단추 배치 목록이 쓴다 — 받으면 그 목록을 다시 그린다 · 묻는 중에는 다시 묻지 않는다)
local cashFetching = false
state.cashFetchNow = function()
	if cashFetching then
		return
	end
	cashFetching = true
	task.spawn(function()
		local ok, res = pcall(Net.Invoke, "Cash", "view")
		cashFetching = false
		if ok and res and res.list then
			state.cash = res
			Touch.rechoose()
		end
	end)
end
-- id = 그 펫(꺼내 둔 것이면 넣는다)
-- 내 그림의 모습(2026-10-23): 염색(캐릭터의 것 — Self의 look) + 장착한 캐시 무기(계정의 것 — Who의 wskin)
state.lookOf = function(look: any)
	return { point = if typeof(look) == "table" then look.point else nil, robe = if typeof(look) == "table" then look.robe else nil, skin = state.mySkin }
end
-- 캐시 무기: id = 그것(장착한 것이면 해제한다) — 가방의 캐시 탭(2026-10-23)
state.toggleWskin = function(id: string)
	once(function()
		cashInvoke("wskin", if state.mySkin == id then false else id)
	end)
end
state.togglePet = function(id: string)
	once(function()
		cashInvoke("pet", if state.myPet == id then false else id)
	end)
end
-- id = 그 탈것(타고 있는 것이면 내린다) · nil = 고른 탈것으로 타거나 내린다(N 키)
state.toggleRide = function(id: string?)
	once(function()
		if state.myRide and (id == nil or state.myRide == id) then
			cashInvoke("ride", false)
			return
		end
		local want = id or (state.cash and state.cash.mount) or nil
		if want == nil then
			local ok, res = pcall(Net.Invoke, "Cash", "view")
			if ok and res and res.list then
				state.cash = res
				want = res.mount or nil
			end
		end
		if want == nil then
			if state.fx and state.body then
				state.fx:float(CashWindow.WORDS.noMount, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
			end
			return
		end
		cashInvoke("ride", want)
	end)
end

-- 막이 걷힌 뒤(2026-10-18): 경관이 있는 곳이면 경관(제 이름을 띄운다 — 맵 이름은 겹치므로 띄우지 않는다), 아니면 맵 이름
local function afterLift()
	local v = state.vistaPending
	state.vistaPending = nil
	if v then
		VistaView.show(v)
	else
		MapName.show(state.sceneKey)
	end
end
local function enterScene(key: string, x: number, y: number, room)
	local scene = SCENES.scenes[key]
	assert(scene, "없는 장면 " .. tostring(key))
	-- 퀘스트 연출: 도는 장면은 끝낸다(장면이 세운 것은 이전 맵의 층에 있다) · 줄도 비운다(그 주민 앞에서 틀려던 것 — 새 맵의 장면은 들어선 뒤에 다시 줄 세운다)
	if CineView.active() then
		CineView.stop()
	end
	state.cineQueue = {}
	if Windows.isOpen("auction") and not Town.is(key) then
		Windows.close("auction") -- 경매장은 마을에서만(2026-10-21) — 마을 밖으로 나가면 닫는다
	end
	Talk.hush() -- 주민의 혼잣말 말풍선(화면 틀의 층에 있어 맵을 지워도 남는다)
	HallStones.leave()
	-- 이전 장면의 것을 치운다. 하나를 치우다 오류가 나도 나머지를 마저 치우고 새 장면을 그린다 — 치우기는 이 함수의 맨 앞이라, 여기서 멈추면 새 장면이 통째로 안 그려진다
	--  (2026-10-13: 이펙트를 치우다 난 오류 하나로 문을 지난 뒤의 화면이 깨졌다 — 캐릭터와 몬스터가 없고 이전 맵이 남았다). 오류는 출력 창에 알린다
	local function clear(what: string, thing: any, method: string)
		if thing then
			local ok, err = pcall(thing[method], thing)
			if not ok then
				warn(("[lune] 이전 장면의 %s을(를) 치우다 오류: %s"):format(what, tostring(err)))
			end
		end
	end
	clear("내 캐릭터", state.sprite, "destroy")
	clear("펫 · 탈것", state.ride, "destroy")
	clear("몬스터", state.mobs, "destroy")
	clear("보스", state.boss, "destroy")
	clear("이펙트", state.fx, "destroy")
	clear("다른 사람들", state.others, "destroy")
	clear("맵", state.view, "destroy")
	clear("이름표의 층", state.over, "Destroy") -- 이름표(내 것 포함) · 체력 띠 · 알림 글은 이 층과 함께 사라진다
	table.clear(state.spots) -- 퀘스트의 자리 표시도 위의 두 층과 함께 사라졌다(새 장면의 것은 아래 drawQuests가 만든다)
	table.clear(state.shards) -- 달조각도(새 장면의 것은 drawQuests가 만든다)
	if MUSIC.hidden[key] and state.sceneKey ~= key then
		Music.sfx("secret3") -- 숨은 방에 들어섰다(징글이 아니라 효과음 — 사용자 2026-10-14: 숨은 방 진입 징글은 없다)
	end
	state.sceneKey = key
	Music.scene(key) -- 그 장면의 배경 음악(같은 곡이면 이어 튼다)
	state.over = Overlay.layer("Scene", 10)
	state.view = SceneView.new(Stage.view, key, scene, state.over)
	HallStones.enter(scene, state.over) -- 명예의 전당이면 비석 면에 순위를 새긴다
	state.body = P.newBody(scene)
	state.body.x, state.body.y = x, y
	P.unstick(scene, state.body) -- 들어선 자리가 땅 속이면 꺼낸다(2026-10-21)
	if state.me then
		state.body.run, state.body.jump = state.me.run or 1, state.me.jump or 1 -- 걸음 · 뛰는 힘의 배수(패시브)는 장면이 바뀌어도 그대로
	end
	state.sprite = Sprite.new(state.view.heroLayer, state.who)
	state.wfx = state.wfx or WeaponFx.new() -- 캐시 무기의 점(장면이 바뀌어도 하나 — 없어진 그림의 점은 스스로 거둔다)
	-- 내 펫 · 탈것: 들어선 방의 이름표(room.who)에서 읽는다(2026-10-21 사용자 "펫은 게임 종료할때 소환되어있는게 게임 종료하고 재접속하면 그대로 소환 되어야하고" —
	--  서버는 꺼내 둔 펫을 저장하고 이름표에 실어 보냈지만, 화면은 따로 오는 Who에서만 읽어 접속한 뒤 누가 드나들기 전까지 펫이 없었다)
	for _, w in (room and room.who) or {} do
		if state.myId ~= nil and w.id == state.myId then
			state.myPet, state.myRide = w.pet or nil, w.ride or nil
			state.mySkin = w.wskin or nil -- 장착한 캐시 무기(계정의 것 — 2026-10-23)
		end
	end
	state.sprite:setLook(state.lookOf(state.me and state.me.look)) -- 무기 · 로브 색(염색 — 2026-10-22) · 캐시 무기(2026-10-23)
	state.ride = RideView.new(state.view.heroLayer, 1, scene) -- 내 펫 · 탈것(영웅의 ZIndex 1 — 탈것 · 펫은 그 뒤, 탈것의 등은 그 앞 · 펫은 이 맵의 땅 위를 걷는다)
	state.ride:setPet(state.myPet)
	state.ride:setRide(state.myRide)
	state.mobs = MobsView.new(state.view.mobLayer, room, state.over)
	RiftView.enter(room.rift) -- 토벌의 방이면 위 가운데의 판(아니면 숨긴다)
	BossView.setWeekly(room.weekly) -- 주간 보스의 방이면 보스 체력 바 위에 난이도 · 남은 시간(아니면 숨긴다 — 2026-10-24)
	if not Voyage.onShip(key) then
		VoyageView.stop() -- 배에서 내렸다
	end
	VistaView.stop()
	state.vistaPending = scene.vista -- 경관(성의 테라스): 들어설 때마다 한 번 — 막이 걷힌 뒤에 띄운다(afterLift — 2026-10-18 검토: 막 뒤에서 밝아지기가 먼저 지나갔다)
	table.clear(state.npcNames)
	for _, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			state.npcNames[n.id] = n.name
		end
	end
	if state.drawQuests then
		state.drawQuests()
	end
	state.others = Others.new(state.view.heroLayer, state.over, state.myId, scene.ladders, scene) -- 사다리 위의 다른 사람은 오르기 동작으로(2026-10-16 밤) · 그 사람의 펫도 이 맵의 땅 위를 걷는다
	state.others.graveLayer = state.view.graveLayer
	state.others:setWho(room.who or {})
	state.grave = Grave.new(state.view.graveLayer) -- 내 비석(쓰러졌을 때만 보인다)
	state.tag = Ui.tag(state.over, Others.tagText(if state.me then state.me.level else 1, state.myName), Ui.COLOR.text, 220, true, Others.levelText(if state.me then state.me.level else 1)) -- 판 바깥 왼쪽에 레벨(2026-10-21)
	state.tagLevel = if state.me then state.me.level else 1
	PartyHud.set(state.party, state.myId, key)
	state.fx = Effects.new(state.view.topLayer, state.over, state.view.heroLayer)
	state.others.fx = state.fx -- 다른 사람의 대쉬도 같은 효과를 낸다
	for _, d in room.drops do
		state.fx:addDrop(d)
	end
	-- 기술의 이펙트: 나와 방의 사람들이 쓰는 기술을 시험 탭과 같은 그림으로 돌린다
	state.cast = Cast.new(state.view, scene, state.fx, state.mobs)
	state.push = nil
	state.boss = BossView.new(state.mobs, state.cast, state.fx, scene, {
		-- 보스가 포효한다: 가까이(150점 안) 땅을 딛고 있으면 0.25초 동안 dist만큼 밀려난다(피해는 없다 — 시험 탭과 같다)
		push = function(x: number, dist: number)
			local b = state.body
			if b and b.ground and math.abs(b.x - x) < 150 then
				state.push = { v = (if b.x >= x then 1 else -1) * dist / 0.25, t = 0.25 }
			end
		end,
		-- 보스가 나타나 있는 동안은 보스의 곡, 쓰러지거나 사라지면 이 맵의 곡으로(같은 곡이면 이어 튼다)
		music = function(track: string?)
			if track then
				Music.play(track)
			else
				Music.scene(key)
			end
		end,
	}) -- 스토리 보스가 서는 방이면 그 예고와 이펙트 · 잔상 · 화면 흔들림(없는 방에서는 아무것도 하지 않는다)
	state.actor = state.cast:actor(state.myId or 0, state.who, true)
	state.actor.x, state.actor.y = x, y
	-- 걸려 있는 버프의 모습(거신의 큰 몸 등) · 공격 속도를 새 장면의 몸에도(2026-10-18 검토: 문을 지나면 내 상태가 다시 오지 않아 사라졌다)
	if state.buffs then
		state.cast:setBuffs(state.actor, state.buffs)
	end
	state.actor.haste = state.haste or 1
	-- 직업 묶음의 스킬이 내 몸을 옮긴다(밀고 나가기 · 뛰기 · 돌아보기 · 순간이동). 자리는 여기(화면)가 정하고 서버에 알린다
	state.cast.control = {
		move = function(v: number, t: number)
			local sk = state.skill
			if sk and sk.kit then
				sk.imp = { v = v * state.dir, t = t }
			end
		end,
		hop = function(v: number)
			state.body.vy, state.body.ground = -v, false
		end,
		face = function(d: number)
			state.dir = d
		end,
		teleport = function(tx: number): number?
			local sceneNow = SCENES.scenes[state.sceneKey]
			tx = math.clamp(tx, 8, sceneNow.w * 16 - 8)
			if P.solidBox(sceneNow, tx, state.body.y) then
				return nil
			end
			state.body.x = tx
			state.reportT = REPORT -- 옮긴 자리를 바로 알린다
			return tx
		end,
	}
	syncKit()
	-- 방에 서 있는 달 수정(무니)
	for _, c in room.crystals or {} do
		crystalAdd(c)
	end
	state.clip, state.clipT, state.skill = "idle", 0, nil
	state.sentX = -1
	Talk.close()
end

-- ---------- 장면 바꾸기(문 · 마을로 돌아가기 · 관리 이동) ----------
--  막을 치고(페이드 아웃) → 막 뒤에서 새 장면을 그리고 → 그 장면에 쓰인 그림이 다 불러와지면 → 막을 걷는다(페이드 인). 그동안 캐릭터는 멈춰 있다(state.busy — 자리 보고도 하지 않는다).
--   사용자 2026-10-11: "게임 시작시, 포탈 이용시 페이드 아웃 로딩 걸고 그 사이에 이미지 정확히 다 로드 해야합니다. 지금 그냥 포탈로 넘어간다음에 이미지들 로드 안되서 바로 안뜹니다."
--  한 번에 하나씩 돈다: 도는 중에 또 옮겨지면(서버가 잇달아 옮겼다) 막을 걷지 않고 이어서 그린다. 장면을 그리다 오류가 나도 막은 걷히고 캐릭터는 다시 움직인다
--   (전에는 문을 지나다 오류가 나면 state.busy가 켜진 채 남아 그 뒤로 아무것도 할 수 없었다).
--  want = 서버가 준 것 { scene, x, y, room } 또는 그것을 돌려주는 함수(문: 서버에 묻는다 — nil을 돌려주면 옮기지 않는다)
local sceneNext: any = nil
local sceneRunning = false
local function showLoaded()
	Curtain.load({ Stage.gui })
end
local function goScene(want: any)
	sceneNext = want
	state.busy = true
	if sceneRunning then
		return -- 돌고 있는 것이 이어서 처리한다
	end
	sceneRunning = true
	task.spawn(function()
		Curtain.cover()
		while sceneNext ~= nil do
			local job = sceneNext
			sceneNext = nil
			if typeof(job) == "function" then
				local ok, got = pcall(job)
				job = if ok then got else nil
			end
			if typeof(job) == "table" and job.scene then
				local ok, err = pcall(enterScene, job.scene, job.x, job.y, job.room)
				if not ok then
					warn("[lune] 장면을 그리지 못했다 " .. tostring(job.scene) .. ": " .. tostring(err))
				end
				showLoaded()
			end
		end
		Curtain.lift()
		afterLift() -- 막이 걷히면 맵 이름(2026-10-18) · 경관이 있는 곳이면 경관
		sceneRunning = false
		Input.flush() -- 까만 동안 누른 것은 버린다
		state.busy = false
	end)
end

-- ---------- 기술 ----------
local function startSeg(id: string, seg: number, lv: number?)
	local def = COMBAT.skills[id]
	local sk = { id = id, def = def, seg = seg, t = 0, queued = false, vx = nil :: number?, move = 0, shown = {} }
	if seg == 1 and def.cd > 0 then
		state.cds[id] = state.clock + def.cd
	end
	-- 첫 구간과, 한 번 더 눌러 잇는 구간 · 힘을 모으는 구간의 다음 구간만 서버에 알린다(저절로 이어지는 구간은 서버가 알아서 잇는다).
	--  힘을 모으는 구간의 다음 = 키를 뗀 때(또는 끝까지 모인 때) 나간다 — 서버가 그 사이의 시간으로 모은 단계를 셈한다
	if seg == 1 or def.segs[seg].next or def.segs[seg - 1].charge then
		Net.FireServer("Skill", id, seg, state.body.x, state.body.y, state.dir)
	end
	if def.type == "move" then
		sk.vx = state.dir * def.speed
		sk.move = def.dist / def.speed
		-- 대쉬의 효과(시험 탭과 같다): 시작할 때 속도선, 가는 동안 잔상(stepSkill)
		state.fx:streaks(state.body.x, state.body.y, def.speed, state.dir, CLASSES.classes[state.who].tone)
	else
		-- 그 구간의 이펙트(휘두른 자국 · 고리 · 파편 …). lv = 모은 단계
		local a = state.actor
		a.x, a.y, a.dir = state.body.x, state.body.y, state.dir
		state.cast:start(a, id, seg, lv or 0)
	end
	state.skill = sk
end

-- 장치의 셈(sim/kit.luau)에 넘길 내 모습: 직업과 배운 스킬
local function kitHero()
	return { class = state.who, skills = if state.me then state.me.skills else {} }
end

-- ---------- 2~4차의 쓰는 스킬(직업 묶음의 그 스킬) ----------
--  구간은 여기(화면)가 잇는다 — 시험 탭의 step()과 같은 법: 보통 구간은 끝 장을 넘기면 · loop는 dur 뒤에 · hold는 키를 떼면(min ~ max) · charge는 키를 떼거나 끝까지 모이면 · till은 조건이 되면.
--  구간이 시작될 때마다 서버에 알리고(Skill), 판정과 피해는 서버가 같은 스킬을 돌려 정한다(sim/caster.luau). 이펙트는 cast.luau가 그 구간을 돌린다.
--  땅에서 쓰는 기술(ground)을 공중에서 쓰면 내리꽂는 것은 아직 없다 — 땅에서만 써진다.
local function kitLast(s): number
	return Caster.lastFrame(state.who, s)
end
-- 그 구간의 지금 장(0부터): 되풀이 구간은 끝 장을 넘으면 loopFrom으로 돌아간다
local function kitFrame(sk): number
	local s = sk.s
	local from, to = s.from or 0, sk.last
	local f = from + math.floor(sk.t * (s.fps or 14))
	if not (s.loop or s.hold or s.charge or s.till) then
		return math.min(to, f)
	end
	local lf = s.loopFrom or from
	return if f <= to then f else lf + ((f - to - 1) % (to - lf + 1))
end

local function startKit(id: string, seg: number, lv: number?)
	local kdef = Kitset.skill(id)
	local body = state.body
	local prev = state.skill
	local sk = if prev and prev.kit and prev.id == id then prev else { kit = true, id = id, kdef = kdef, lv = 0, air = not body.ground, avx = body.vx or 0, action = nil :: any }
	sk.seg, sk.s, sk.t, sk.pressed, sk.imp = seg, kdef.segs[seg], 0, false, nil
	sk.lv = lv or sk.lv
	sk.last = kitLast(sk.s)
	state.skill = sk
	Net.FireServer("Skill", id, seg, body.x, body.y, state.dir)
	local a = state.actor
	a.x, a.y, a.dir, a.ground, a.vx, a.vy = body.x, body.y, state.dir, body.ground, body.vx or 0, body.vy or 0
	state.cast:start(a, id, seg, sk.lv)
end

local function stepKit()
	local sk = state.skill
	local s, body, a = sk.s, state.body, state.actor
	sk.t += STEP * (if s.charge then 1 else state.haste) -- 공격 속도 버프: 동작이 그만큼 빨라진다(힘 모으기 구간은 그대로)
	a.x, a.y, a.dir, a.ground, a.vx, a.vy = body.x, body.y, state.dir, body.ground, body.vx or 0, body.vy or 0
	local down = sk.action ~= nil and Input.held(sk.action)
	local done
	if s.loop then
		done = sk.t >= s.dur
	elseif s.hold then
		done = (not down and sk.t >= (s.min or 0.15)) or sk.t >= (s.max or 3)
	elseif s.charge then
		-- 힘 모으기: 이 구간의 동작이 끝난 뒤에도 키를 누르고 있으면 단계가 오른다(서버가 같은 시간으로 센다). 만월이면 모으지 않아도 가득
		local per, levels = Caster.chargeOf(kitHero(), s)
		local base = Caster.segTime(state.who, s)
		local lv = if levels > 0 and state.full then levels else math.clamp(math.floor((sk.t - base) / per + 1e-6), 0, levels)
		if lv > sk.lv then
			sk.lv = lv
			state.cast:chargeUp(a, lv)
		end
		done = sk.t >= base and (not down or sk.lv >= levels)
	elseif s.till then
		done = s.till(a.g) == true or sk.t >= (s.max or 1.5)
	else
		done = (s.from or 0) + math.floor(sk.t * (s.fps or 14)) > sk.last
	end
	if done then
		local nextS = sk.kdef.segs[sk.seg + 1]
		if nextS and (not nextS.needPress or sk.pressed) then
			startKit(sk.id, sk.seg + 1, sk.lv)
		else
			state.skill = nil
			a.charge = 0 -- 머리 위의 모은 단계를 지운다
		end
	end
end

-- 머리 위의 힘 모으기 단계를 지운다
local function clearPips()
	if state.actor then
		state.actor.charge = 0
	end
end

-- action = 그 기술을 쓴 키(Input의 이름 — "slot:3" · "tslot:2" …). 힘을 모을 때 그 키를 누르고 있는지 본다
-- 퀘스트의 자리(맵에 놓인 것 앞에서 ↑를 누르는 일): 그 위에 주민 머리 위의 것과 같은 「!」를 띄운다. 자리는 이 장면의 것만 — 퀘스트가 바뀌거나 장면이 바뀌면 다시 만든다
local function clearSpots()
	for _, sp in state.spots do
		sp.mark:Destroy()
		sp.tag.Frame:Destroy()
	end
	table.clear(state.spots)
end
local function drawSpots()
	clearSpots()
	if not state.view or not state.over then
		return
	end
	local spots = Quests.spotsIn(state.quests or {}, state.sceneKey)
	-- 숨은 이야기(2026-10-16 — 그 앞에서 ↑로 읽는다): 아직 안 읽은 것만 「!」가 뜬다(읽은 것도 다시 읽을 수 있다 — 표시 없이)
	for _, st in Bond.DATA.stories do
		if st.scene == state.sceneKey then
			local read = state.bond ~= nil and state.bond.story[st.id] == true
			table.insert(spots, { story = st.id, x = st.x, y = st.y, up = 30, act = st.act, place = st.name, quiet = read })
		end
	end
	for _, sp in spots do
		sp.mark = Kit.part(state.view.topLayer, SceneView.MARK["!"], 0, 0)
		sp.mark.Visible = not sp.quiet
		sp.mark.Name = "SpotMark"
		sp.mark.ZIndex = 6
		sp.tag = Ui.tag(state.over, ("↑ %s"):format(sp.act), Ui.COLOR.accent, 220)
		sp.tag.Frame.Visible = false
		table.insert(state.spots, sp)
	end
end
-- 달조각(2026-10-16 — 로스트아크의 모코코 씨앗): 이 장면의 아직 못 주운 것을 땅 위에 띄운다(닿으면 서버가 줍는다 — BondView)
local function clearShards()
	for _, sh in state.shards do
		sh.frame:Destroy()
	end
	table.clear(state.shards)
end
local function drawShards()
	clearShards()
	if not state.view then
		return
	end
	for _, x in Bond.DATA.shards do
		if x.scene == state.sceneKey and not (state.bond and state.bond.shard[x.id]) then
			local frame = Kit.group(state.view.topLayer, 0, 0, Kit.ICON, Kit.ICON)
			Kit.icon(frame, "shard_moon", 0, 0)
			local scale = Instance.new("UIScale")
			scale.Scale = 0.75
			scale.Parent = frame
			frame.Name = "Shard_" .. x.id
			frame.ZIndex = 6
			table.insert(state.shards, { id = x.id, x = x.x, y = x.y, frame = frame })
		end
	end
end
state.drawShards = drawShards

-- 가까이에 있는 자리(없으면 nil)
local function nearSpot(x: number, y: number)
	for _, sp in state.spots do
		if math.abs(sp.x - x) <= Quests.USE_REACH.x and math.abs(sp.y - y) <= Quests.USE_REACH.y then
			return sp
		end
	end
	return nil
end

-- 새 캐릭터는 첫 퀘스트 「첫 기술」을 끝내야(사제에게 말을 걸어야) 기술을 쓴다 — 그때 스킬 칸이 생긴다
local function skillsLocked(): boolean
	if require(script.Parent.ui.macroWindow).isOpen() then
		return true -- 매크로 확인 문제가 떠 있는 동안은 스킬을 쓰지 못한다(서버도 받지 않는다 — 2026-10-24)
	end
	if Tutorial.isDream(state.sceneKey) then
		return false -- 꿈(튜토리얼)에서는 첫 사냥기를 써 본다(사제에게 배우기 전이어도)
	end
	return state.me ~= nil and Quests.isNew(state.quests or {}, state.me.level)
end

-- 전직할 레벨이 됐다: 화면 가운데에 「달이 부른다」 — 그믐 사제에게 가서 전직 퀘스트를 받으라고 알린다(받을 수 있게 된 때 한 번).
--  퀘스트는 저절로 받지 않는다(사용자 2026-10-11) — 전에는 이때 퀘스트가 저절로 들어왔다
local function jobCall()
	if not state.me then
		return
	end
	for _, def in Quests.openJobs(state.quests or {}, state.me.level) do
		if not state.jobSeen[def.id] then
			state.jobSeen[def.id] = true
			Guide.banner("달이 부른다", ("%s에게 가서 「%s」 퀘스트를 받는다"):format(state.npcNames[def.giver] or "그믐 사제", def.name), 6)
		end
	end
end

local function trySkill(id: string, action: string?)
	if skillsLocked() then
		return
	end
	-- 온오프 사출기: 누르면 켜고 끈다(쓰는 동작이 없다 — 서버가 바꾸고 내 상태로 돌려준다)
	if KitSim.isToggle(kitHero(), id) then
		if not state.dead and not state.busy and state.clock - (state.toggleAt or -9) > 0.3 then
			state.toggleAt = state.clock
			Net.FireServer("Skill", id, 1, state.body.x, state.body.y, state.dir)
		end
		return
	end
	-- 버프(갱신 · 파티 · 생존 · 극딜 · 공용): 누르면 바로 걸린다 — 쓰는 동작이 없고, 다른 동작 중에도 걸린다. 걸리는 순간의 이펙트는 바로 내고, 버프는 서버가 건다
	-- 설치 · 소환 가운데 누르면 바로 놓이는 것(화로 · 망령 · 수호령)도 같다 — 태우는 영혼이 모자라면 놓이지 않는다
	local placed = COMBAT.placed[id]
	if placed and placed.cast == "instant" and not Buffs.is(id) then
		local me = state.me
		if state.dead or state.busy or not me or placed.who ~= state.who or (me.skills[id] or 0) < 1 or (state.cds[id] or 0) > state.clock then
			return
		end
		if placed.cost and (not me.kit or me.kit.souls < placed.cost) then
			return
		end
		state.cds[id] = state.clock + math.max(placed.cd, 0.5)
		local a = state.actor
		a.x, a.y, a.dir = state.body.x, state.body.y, state.dir
		state.cast:instant(a, id)
		Net.FireServer("Skill", id, 1, state.body.x, state.body.y, state.dir)
		return
	end
	if Buffs.instant(id) then
		if state.dead or state.busy or not state.me or not Buffs.learned(kitHero(), id) or (state.cds[id] or 0) > state.clock then
			return
		end
		state.cds[id] = state.clock + math.max(Buffs.data[id].cd, 0.5)
		local a = state.actor
		a.x, a.y, a.dir = state.body.x, state.body.y, state.dir
		state.cast:instant(a, id)
		Net.FireServer("Skill", id, 1, state.body.x, state.body.y, state.dir)
		return
	end
	-- 2~4차의 쓰는 스킬(사냥기 · 보스기 · 공격기 · 큰 기술 · 바인드 · 회복)
	local castDef = COMBAT.cast[id]
	if castDef then
		local me = state.me
		if castDef.who ~= state.who or state.dead or state.busy or not me or (me.skills[id] or 0) < 1 then
			return
		end
		local kdef = Kitset.skill(id)
		local cur = state.skill
		if cur and not kdef.instant then
			-- 같은 키를 한 번 더: 이어 누르는 구간이 나간다(암살의 마무리 · 염왕권 …)
			if cur.kit and cur.id == id then
				cur.pressed = true
				cur.action = action or cur.action
			end
			return
		end
		if (state.cds[id] or 0) > state.clock then
			return
		end
		local a = state.actor
		a.x, a.y, a.dir = state.body.x, state.body.y, state.dir
		if kdef.instant then
			-- 쓰는 동작이 없는 것(열 방출): 다른 동작 중에도 바로 나간다
			state.cds[id] = state.clock + math.max(castDef.cd, 0.5)
			state.cast:instant(a, id)
			Net.FireServer("Skill", id, 1, state.body.x, state.body.y, state.dir)
			return
		end
		-- 뛰는 중에도 쓰는 것: 사냥기 · 보스기(묶음이 따로 정한 것은 그대로). 땅에서 쓰는 기술은 땅에서만
		local airOk = if kdef.air ~= nil then kdef.air else (castDef.type == "mob" or castDef.type == "boss")
		if not state.body.ground and (not airOk or kdef.ground) then
			return
		end
		if kdef.can and not kdef.can(a.g) then
			return
		end
		-- 소생: 닿는 거리 안에 쓰러진 파티원이 있을 때만 써진다
		if castDef.heal and castDef.heal.revive then
			local found = false
			for oid, o in state.others.list do
				-- 레벨 차이도 서버와 같게(Party.LEVEL_GAP 20 — 2026-10-18 검토: 화면은 써지고 다시 쓰기가 돌았는데 서버는 아무것도 하지 않았다)
				if o.placed and not o.alive and state.partySet[oid] and math.abs(o.x - state.body.x) <= castDef.heal.reach and math.abs(o.y - state.body.y) <= 80
					and math.abs((o.level or 0) - (if state.me then state.me.level else 0)) <= REVIVE_GAP then
					found = true
				end
			end
			if not found then
				return
			end
		end
		if castDef.cd > 0 then
			state.cds[id] = state.clock + castDef.cd
		end
		startKit(id, 1, 0)
		state.skill.action = action
		return
	end
	local def = COMBAT.skills[id]
	if not def or def.who ~= state.who or state.dead or state.busy then
		return
	end
	local sk = state.skill
	if sk then
		if sk.kit then
			-- 자유 구간(몰아치기 — 2026-10-25)에서 대쉬: 돌던 채로 대쉬만큼 미끄러진다(대쉬의 빠르기 · 거리 · 다시 쓰기 그대로 — 서버의 이동 몫 초당 300점 안)
			if sk.s and sk.s.free and def.type == "move" and not sk.imp and (state.cds[id] or 0) <= state.clock then
				state.cds[id] = state.clock + def.cd
				sk.imp = { v = state.dir * def.speed, t = def.dist / def.speed }
				state.fx:streaks(state.body.x, state.body.y, def.speed, state.dir, CLASSES.classes[state.who].tone)
			end
			return -- 2~4차의 스킬을 쓰는 중이다
		end
		-- 같은 키를 한 번 더: 이어지는 구간이 있으면 예약한다
		local nextSeg = def.segs[sk.seg + 1]
		if sk.id == id and nextSeg and nextSeg.next then
			sk.queued = true
			sk.action = action or sk.action
		end
		return
	end
	if (state.cds[id] or 0) > state.clock then
		return
	end
	startSeg(id, 1)
	state.skill.action = action
end

-- 쓰는 중인 기술을 한 걸음 진행한다. 끝났으면 nil이 된다.
local function stepSkill()
	local sk = state.skill
	if not sk then
		return
	end
	if sk.kit then
		stepKit()
		return
	end
	sk.t += STEP * (if sk.vx ~= nil then 1 else state.haste) -- 공격 속도 버프: 동작이 그만큼 빨라진다(이동기는 그대로)
	local segDef = sk.def.segs[sk.seg]
	-- 대쉬로 가는 동안: 그 순간의 몸을 직업 색 실루엣으로 남긴다(잔상)
	if sk.vx ~= nil and sk.t < sk.move then
		local frame = segDef.from + math.min(segDef.to - segDef.from, math.floor(sk.t * segDef.fps)) + 1
		state.fx:trail(sk, STEP, state.who, segDef.clip, frame, state.body.x, state.body.y, state.dir, CLASSES.classes[state.who].tone)
	end
	-- 기술에 딸린 날아가는 그림(화염 광선 등)
	for i, shot in sk.def.shots do
		if shot.seg == sk.seg and not sk.shown[i] and sk.t >= shot.at then
			sk.shown[i] = true
			state.fx:addSprite(state.who, shot.clip, state.body.x + state.dir * shot.dx, state.body.y + shot.dy, state.dir, shot.life, shot.fps)
		end
	end
	if sk.t >= segDef.time then
		local nextSeg = sk.def.segs[sk.seg + 1]
		local go = nextSeg ~= nil and (not nextSeg.next or sk.queued)
		-- 힘 모으기(액시온): 이 구간이 끝났을 때 그 키를 누르고 있으면 모은다(동작은 끝 장에서 멈춰 있다) — 떼거나 끝까지 모이면 다음 구간이 나간다.
		--  머리 위에 모인 단계가 뜬다. 톡 누르면(누르고 있지 않으면) 예전처럼 바로 나간다
		if go and segDef.charge then
			local me = kitHero()
			local max = KitSim.chargeTime(me, sk.id)
			-- 만월: 모으지 않아도 끝까지 모은 것으로 나간다
			if max > 0 and state.full and (sk.level or 0) < KitSim.chargeLevels(me) then
				sk.level = KitSim.chargeLevels(me)
				state.cast:chargeUp(state.actor, sk.level)
			elseif max > 0 and sk.action ~= nil and Input.held(sk.action) and (sk.hold or 0) < max then
				sk.hold = (sk.hold or 0) + STEP
				-- 단계가 오를 때마다 고리가 오므라들고, 머리 위에 모인 단계만큼 점이 뜬다(시험 탭과 같다)
				local level = KitSim.charge(me, sk.id, sk.hold)
				if level > (sk.level or 0) then
					sk.level = level
					state.cast:chargeUp(state.actor, level)
				end
				return
			end
		end
		clearPips()
		if go then
			local action = sk.action
			startSeg(sk.id, sk.seg + 1, sk.level)
			state.skill.action = action
		else
			state.skill = nil
		end
	end
end

-- ---------- 한 걸음 ----------
local function step()
	local scene = SCENES.scenes[state.sceneKey]
	local body = state.body
	state.clock += STEP
	state.blink = math.max(0, state.blink - STEP)
	state.hurtT = math.max(0, state.hurtT - STEP)
	if state.dead then
		state.deadT += STEP
		-- 쓰러지고 조금 뒤: 마을로 돌아갈지 묻는다(저절로 가지 않는다 — 단추를 누르거나, 파티원이 소생으로 일으켜 줄 때까지 비석으로 남는다)
		if state.deadT >= RULES.reviveWait and not DeathBox.shown() then
			DeathBox.show(Hud.root, function()
				Net.FireServer("Return")
			end, math.ceil(((state.me and state.me.weak) or 0) / 60))
		end
	end
	if state.dead or state.busy then
		P.step(scene, body, { mx = 0 }, STEP)
		return
	end
	-- 퀘스트 연출(장면)이 도는 동안: 걷지 않고 스킬도 쓰지 않는다. ↑ · 스페이스 = 넘기기(스페이스를 누르고 있으면 쭉) · Esc = 건너뛰기(cineView.luau)
	if CineView.active() then
		local go = Input.take("up")
		if Input.take("jump") then
			go, state.talkHold = true, os.clock() + TALK_HOLD.first
		elseif Input.held("jump") and state.talkHold and os.clock() >= state.talkHold then
			go, state.talkHold = true, os.clock() + TALK_HOLD.next
		end
		if go then
			CineView.input("next")
		end
		P.step(scene, body, { mx = 0 }, STEP)
		return
	end

	-- 말하는 중에는 뛰기 키(Space)로도 다음 말로 넘긴다 — 누르고 있으면 쭉 넘어간다(마지막 말에서는 그 일을 한다: 수락 · 완료)
	--  사용자 2026-10-13: "스페이스로 쭉 스킵  퀘스트 받고 … 다시 돌아와서 완료하고 스페이스꾹 누르면 다음 퀘스트 하나 받아지고 이렇게 퀘스트 루프가 자연스럽게"
	if Talk.npc then
		local skip = false
		if Input.take("jump") then
			skip, state.talkHold = true, os.clock() + TALK_HOLD.first
		elseif Input.held("jump") and state.talkHold and os.clock() >= state.talkHold then
			skip, state.talkHold = true, os.clock() + TALK_HOLD.next
		end
		if skip then
			Talk.next(Talk.npc)
		end
	else
		state.talkHold = nil
	end
	-- 대화창이 떠 있는 동안에는 걷지 않고 스킬도 쓰지 않는다 — ↑로도 넘긴다(2026-10-14: 일반 도트 게임의 대화창처럼)
	if Talk.npc then
		if Talk.inMenu() and Input.take("down") then
			Talk.menuMove(1) -- 고르는 말: ↓ = 다음 줄(2026-10-18)
		end
		if Input.take("up") then
			Talk.next(Talk.npc)
		end
		P.step(scene, body, { mx = 0 }, STEP)
		return
	end
	-- 퀘스트를 돌려준 자리에서 그 주민이 줄 것이 또 있으면 말을 잇는다(서버가 끝냈다고 알려 온 뒤에) — 끝내고 그대로 다음 것을 받는다
	local chain = state.chain
	if chain then
		if CineView.active() or #state.cineQueue > 0 then
			chain.till = os.clock() + 3 -- 돌려준 뒤의 장면이 끝날 때까지 다음 퀘스트의 말을 기다린다
		elseif os.clock() > chain.till or state.sceneKey ~= chain.scene or math.abs(chain.npc.x - body.x) > 44 then
			state.chain = nil
		elseif not Talk.npc and state.quests and state.quests[chain.done] and state.quests[chain.done].done then
			state.chain = nil
			state.questTalk(chain.npc)
		end
	end
	-- 문 앞에서 ↑: 서버에 묻고, 허락하면 그 장면으로
	local wantUp = Input.take("up") and body.ground and not state.skill
	local hop = wantUp and state.view:warpNear(body.x, body.y)
	if hop then
		-- 간이 포탈: 서버가 같은 맵의 짝 자리로 옮기고 Warp로 알린다(막 없이 바로). 옮겨지기 전에 ↑를 거듭 누른 것은 보내지 않는다(0.6초 —
		--  2026-10-21 퍼블리시한 게임의 오류 보고: 'Hop' 요청이 빈도 제한(초당 2번)을 넘어 버려졌다)
		if os.clock() - (state.hopSent or -9) >= 0.6 then
			state.hopSent = os.clock()
			Net.FireServer("Hop", hop.id)
		end
		wantUp = false
	end
	if wantUp then
		local portal = state.view:portalNear(body.x, body.y)
		if portal and portal.dungeon then
			-- 던전의 문(2026-10-21 — 수정 거울숲): 맵을 옮기지 않고 던전 창을 연다(문에서 멀어지면 닫힌다 — 아래 state.ui.npc). 오늘 끝냈는가는 서버에 묻는다
			state.ui.npc, state.ui.scene = { x = portal.x, y = portal.y }, state.sceneKey
			Windows.open("dungeon", portal.dungeon)
			task.spawn(function()
				local wc = Windows.context()
				if wc and wc.riftDo then
					wc.riftDo("view")
				end
			end)
			Music.sfx("secret4")
			return
		end
		if portal and portal.weekly then
			-- 보스의 문(2026-10-24 — 주간 보스): 맵을 옮기지 않고 보스 창을 연다(문에서 멀어지면 닫힌다). 이번 주에 격파했는가는 서버에 묻는다
			state.ui.npc, state.ui.scene = { x = portal.x, y = portal.y }, state.sceneKey
			Windows.open("weekly", portal.weekly)
			task.spawn(function()
				local wc = Windows.context()
				if wc and wc.weekDo then
					wc.weekDo("view")
				end
			end)
			Music.sfx("secret4")
			return
		end
		if portal then
			-- 서버에 묻는 것과 막을 치는 것을 같이 시작한다(막이 다 덮일 즈음 대답이 와 있다). 서버가 받아 주지 않으면 그 자리에서 막만 다시 걷힌다
			local from = state.sceneKey
			local reply, answered = nil, false
			task.spawn(function()
				local ok, result = pcall(Net.Invoke, "Travel", portal.to)
				reply, answered = if ok then result else nil, true
			end)
			goScene(function()
				local t0 = os.clock()
				while not answered and os.clock() - t0 < 10 do
					task.wait()
				end
				return if reply and state.sceneKey == from then reply else nil
			end)
			return
		end
		-- 경관의 자리(성의 테라스 가운데)에서 ↑: 경관을 다시 본다(2026-10-16 밤)
		if scene.vista and scene.vista.x and math.abs(body.x - scene.vista.x) <= 40 and not VistaView.showing() then
			VistaView.show(scene.vista)
			return
		end
		-- 퀘스트의 자리 앞이면(샘 · 깃발): 서버에 알린다 — 숫자가 오르면 그 자리의 표시가 사라진다
		local spot = nearSpot(body.x, body.y)
		if spot and spot.story then
			-- 숨은 이야기: 서버가 그 앞인지 보고 적어 둔다 → 대화창에 글을 띄운다(2026-10-16)
			local st = Bond.story(spot.story)
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Bond", "read", spot.story)
				if ok and res and res.ok and st then
					state.setBond(res.view)
					Talk.start({ id = "__story", name = st.name, x = st.x, y = st.y }, st.text, Bond.DATA.tome.words.part.story)
					if res.note and res.note.first and state.fx then
						Music.sfx("secret4")
						state.fx:float(Format.fill(Bond.DATA.tome.words.read, { name = st.name }), st.x, st.y - 40, Effects.MINT, 1.6)
					end
				end
			end)
			return
		elseif spot then
			Net.FireServer("Quest", "use", spot.quest)
			Music.sfx("secret4") -- 살펴보기(샘에서 물 뜨기 · 깃발 꺼내기 …)
			if state.fx then
				state.fx:float(spot.act, spot.x, spot.y - 34, Effects.MINT, 1.2)
			end
			return
		end
		-- 닫힌 던전의 문 앞(그 퀘스트를 끝내기 전 — 2026-10-21): 「수정 문이 굳게 닫혀 있다」와 누구에게 들으면 되는지
		for _, p in scene.portals do
			if p.weekly and math.abs(p.x - body.x) <= 40 and math.abs(p.y - body.y) <= 40 and not Quests.portalOpen(state.quests, p) then
				-- 닫힌 보스의 문(그 보스 퀘스트를 끝내기 전 — 2026-10-24)
				if state.fx then
					local WW = require(lune.sim.weekly).DATA.words
					state.fx:float(WW.closed, p.x, p.y - 70, Effects.MINT, 1.6)
					state.fx:float(WW.closedHint, p.x, p.y - 56, Effects.MINT, 2.2)
				end
				return
			end
			if p.dungeon and math.abs(p.x - body.x) <= 40 and math.abs(p.y - body.y) <= 40 and not Quests.portalOpen(state.quests, p) then
				if state.fx then
					local DW = require(lune.sim.rift).DUNGEON.words
					state.fx:float(DW.closed, p.x, p.y - 70, Effects.MINT, 1.6)
					state.fx:float(DW.closedHint, p.x, p.y - 56, Effects.MINT, 2.2)
				end
				return
			end
		end
		-- 주민 앞이면: 해 주는 일(상점 · 강화 · 창고)이 있으면 그 창을 열고, 없으면 말을 건다(한 번 더 누르면 다음 말)
		local npc = state.view:npcNear(body.x, body.y)
		if npc then
			local at = Quests.atNpc(state.quests, if state.me then state.me.level else 1, npc.id, scene.region, scene.also)
			if Talk.with(npc) then
				Talk.next(npc) -- 말하는 중이면 다음 말로
			elseif state.questTalk(npc) then
				-- 퀘스트의 말을 시작했다(돌려줄 것부터, 없으면 받을 것 하나)
			elseif state.sailTalk(npc) then
				-- 선장: 배에 오를까 묻는다(2026-10-16)
			elseif state.openNpc and state.openNpc(npc) then
				-- 상점 · 강화 · 창고가 열렸다
			elseif #at.wait > 0 then
				local def = Quests.def(at.wait[1])
				Talk.start(npc, def.wait, def.name)
			else
				Talk.next(npc)
			end
		end
	end
	-- 일을 봐 주던 주민에게서 멀어지면 그 창이 닫힌다
	if state.ui.npc and (state.sceneKey ~= state.ui.scene or math.abs(state.ui.npc.x - body.x) > 60 or math.abs(state.ui.npc.y - body.y) > 40) then -- 서버의 nearNpc(가로 64 · 세로 40)보다 조금 안쪽에서 닫는다(2026-10-18 검토: 창은 열려 있는데 서버가 「앞이 아니다」라고 했다)
		state.ui.npc = nil
		Windows.close("shop")
		Windows.close("forge")
		Windows.close("daily")
		Windows.close("rift") -- 토벌 창도(2026-10-18 검토: 「입장」 뒤 토벌의 방 안에서도 열려 있었다)
		Windows.close("dungeon") -- 던전 창도(2026-10-21 — 문에서 멀어지면 · 들어가면)
		Windows.close("weekly") -- 보스 창도(2026-10-24)
	end
	-- 말하던 주민에게서 멀어지면 대화가 닫힌다
	if Talk.npc and math.abs(Talk.npc.x - body.x) > 44 then
		Talk.close()
	end

	for id, def in COMBAT.skills do
		if def.who == state.who and Input.take("skill:" .. id) then
			trySkill(id)
		end
	end
	-- 퀵슬롯: 그 칸의 키를 누르면 칸에 놓인 것(물약 · 스킬)을 쓴다. 스마트폰의 칸 단추("tslot:")도 같은 길 — 놓인 것만 따로다(state.touchSlots)
	for i = 1, Quick.N do
		for _, from in { { "slot:", state.slots }, { "tslot:", state.touchSlots } } do
			if Input.take(from[1] .. i) then
				local what = from[2][i]
				local goods = what and Quick.item(what) and Items.goods(what)
				if goods and goods.kind == "bmRename" then
					Windows.open("cash", "rename", true) -- 이름 바꾸기 주문서: 새 이름을 적는 칸(이름이 바뀔 때 서버가 주문서를 쓴다)
				elseif goods and (goods.kind == "bmDyePoint" or goods.kind == "bmDyeRobe") then
					Windows.open("cash", if goods.kind == "bmDyePoint" then "dye:point" else "dye:robe", true) -- 염색약: 색을 고르는 창(바꿀 때 서버가 염색약을 쓴다 — 2026-10-22)
				elseif what and Quick.item(what) then
					state.sendPotion(what) -- 소비 아이템: 그 칸에 놓인 바로 그 아이템을 쓴다
				elseif what and Quick.ride(what) == "pet" then
					state.togglePet(what) -- 펫: 꺼낸다 · 넣는다(2026-10-21 — 가방의 캐시 탭에서 퀵슬롯에)
				elseif what and Quick.ride(what) == "mount" then
					state.toggleRide(what) -- 탈것: 탄다 · 내린다
				elseif what and Quick.act(what) then
					-- 점프 · 상호작용(폰의 칸 단추 — touch.luau가 바로 뛰기 · 상호작용을 누른다 · 2026-10-21): 여기서는 할 일이 없다
				elseif what then
					trySkill(what, from[1] .. i) -- 그 칸의 키(힘을 모을 때 누르고 있는지 본다)
				end
			end
		end
	end
	if Input.take("potion") then
		state.sendPotion(nil)
	end
	-- 탈것 타기 · 내리기(N — 제가 정한 키 · 2026-10-20): 고른 탈것으로(없으면 알린다 — 상점에서 산다)
	if Input.take("ride") and not state.dead then
		state.toggleRide(nil)
	end
	-- 창을 여는 키(아직 열리지 않은 창은 Windows가 열어 주지 않는다 — 누른 키는 여기서 받아 버린다)
	for _, w in Windows.all() do
		if Input.take("win:" .. w.id) then
			state.openWin(w.id)
		end
	end
	-- 줍기: 누르고 있으면 가까운 것부터 차례로
	state.pickT -= STEP
	if Input.held("pickup") and state.pickT <= 0 then
		local id = state.fx:dropNear(body.x, body.y, RULES.pickup)
		if id then
			Net.FireServer("Pickup", id)
			state.pickT = 0.15
		end
	end

	local mx = Input.axis()
	local sk = state.skill
	local input
	if sk and sk.kit then
		-- 2~4차의 스킬 중(시험 탭과 같은 법): 걸으며 쓰는 구간은 그 빠르기로 걷고(돌아볼 수 있는 구간은 돌아본다), 밀고 나가는 것(g.move)은 그 빠르기로,
		--  뛰다가 쓴 것은 땅에 닿을 때까지 뛰던 기세를 잇고, float 구간은 떨어지지 않는다
		local s = sk.s
		body.climb = nil -- 기술을 쓰면 사다리를 놓는다(2026-10-18 검토 — 걸으며 쓰는 기술은 사다리에 붙은 채였다)
		if mx ~= 0 and s.turn then
			state.dir = mx
		end
		if sk.air and body.ground then
			sk.air = false
		end
		local vx: number? = nil
		if sk.imp then
			local use = math.min(STEP * state.haste, sk.imp.t) -- 공격 속도를 탄다: 더 빨리 가고 그만큼 일찍 끝난다(거리는 같다)
			vx = sk.imp.v * use / STEP
			sk.imp.t -= use
			if sk.imp.t <= 1e-9 then
				sk.imp = nil
			end
		elseif sk.air and not s.walk then
			vx = sk.avx
		end
		if vx ~= nil then
			input = { mx = 0, vx = vx, float = s.float == true, down = false }
		elseif s.free then
			-- 자유 구간(몰아치기 — 2026-10-25 사용자 "몰아치기 는 범위늘리고 키다운하는동안 점프 대쉬 할수있게해 이속도 원래이속으로 다닐수있고"): 누르고 있는 동안 제 빠르기로 걷고 · 뛰고(2단 점프까지) · 대쉬한다(대쉬는 trySkill이 sk.imp로 얹는다 — 위)
			input = { mx = mx, jump = Input.take("jump"), down = Input.held("down") }
		elseif (s.walk or 0) > 0 then
			input = { mx = mx, speed = s.walk, float = s.float == true, down = false }
		else
			input = { mx = 0, vx = 0, float = s.float == true, down = false }
		end
		Input.take("jump")
	elseif sk then
		-- 기술 중: 걷지 않는다(걸으며 쓰는 기술은 느리게 걷는다). 이동기(대쉬)는 보는 쪽으로 밀고 나가며 떨어지지 않는다
		body.climb = nil -- 기술을 쓰면 사다리를 놓는다(2026-10-18 검토)
		local moving = sk.vx ~= nil and sk.t < sk.move
		local walk = sk.def.segs[sk.seg].walk or 0
		if moving then
			input = { mx = 0, vx = sk.vx, float = true, down = false }
		elseif walk > 0 then
			input = { mx = mx, speed = walk, down = false }
		else
			input = { mx = 0, vx = 0, down = false }
		end
		Input.take("jump")
	else
		if mx ~= 0 then
			state.dir = mx
		end
		input = { mx = mx, jump = Input.take("jump"), down = Input.held("down"), up = Input.held("up") or Input.held("climb") } -- up = 사다리를 오른다(2026-10-16 밤 · climb = 폰의 조이스틱을 위로 — 2026-10-17)
		-- 탄 동안은 더 빨리(2026-10-21 사용자 "속도도 더 빨라야함" — ride.generated의 mountSpeed · 사다리 위에서는 탈것을 감추고 제 빠르기)
		--  탈것에 speed가 있으면 그것(쿠폰 탈것 「떠도는 책」 = 1 — 사용자 "이동속도는 유료보다 느리게 그냥 플레이어 이동속도로")
		if state.ride and state.ride:riding() and body.climb == nil then
			local m = RideView.MOUNT[state.ride.rideId]
			input.speed = (m and m.speed) or RIDE_DATA.mountSpeed or 1
		end
		if input.jump and input.down and body.ground and P.onPlatform(scene, body) then
			TutView.dropped = true -- 튜토리얼: 얇은 발판을 내려왔다(↓ + 뛰기)
		end
	end
	if state.push then
		-- 보스의 포효에 밀려나는 중(기술을 쓰는 중이 아니면)
		if not state.skill then
			input = { mx = 0, vx = state.push.v, down = false }
		end
		state.push.t -= STEP
		if state.push.t <= 0 then
			state.push = nil
		end
	end
	local airWas = body.air or 0
	P.step(scene, body, input, STEP)
	-- 막힌 칸 안에 끼었으면 바로 가장 가까운 빈 자리로 꺼낸다(위가 먼저 — sim/physics.luau의 freeSpot). 사다리를 탄 동안은 보지 않는다
	--  사용자 2026-10-21(폰): "대쉬하다가 맵을뚫고 낑기는 현상" — 끼면 걷기 · 뛰기 · 대쉬가 다 막혔다
	if body.climb == nil and P.unstick(scene, body) then
		state.reportT = REPORT -- 꺼낸 자리를 바로 알린다
	end
	if (body.air or 0) > airWas and state.fx then
		state.fx:hop(body.x, body.y) -- 2단 점프: 공중에서 발을 구른 자리에 점이 흩어진다
	end
	stepSkill()

	local clip = if state.skill then "skill" else P.clipOf(body, mx)
	if clip ~= state.clip then
		state.clip, state.clipT = clip, 0
	elseif clip ~= "climb" or input.up or input.down then
		state.clipT += STEP -- 사다리 위에서 멈춰 있으면 오르기 동작도 그 장에서 멈춘다
	end

	-- 내 자리를 서버에 알린다(바뀌었을 때만)
	state.reportT += STEP
	-- (실제 시간으로도 0.08초 사이를 둔다 — 화면이 멈췄다가 밀린 걸음을 한꺼번에 따라잡을 때 한 장면에 여러 번 보내 서버의 빈도 제한(초당 20)을 넘었다: 2026-10-21 오류 보고 'Move')
	if state.reportT >= REPORT and os.clock() - (state.reportClock or -9) >= 0.08 then
		state.reportClock = os.clock()
		state.reportT = 0
		local x, y = math.floor(body.x * 10 + 0.5) / 10, math.floor(body.y * 10 + 0.5) / 10
		if x ~= state.sentX or y ~= state.sentY or state.dir ~= state.sentDir then
			state.sentX, state.sentY, state.sentDir = x, y, state.dir
			Net.FireServer("Move", x, y, state.dir, state.sceneKey) -- 어느 맵의 자리인가(2026-10-21 — 서버는 다른 맵의 늦은 보고를 받지 않는다)
		end
	end
end

local paintBuffs: () -> () -- 버프 자리를 그린다(아래에서 짓는다)
-- 폰의 「메뉴」 단추의 점(2026-10-18): 받을 출석 · 업적 · 모험의 서(state.moreMark)에 더해 — 폰에서는 가방 · 경매 단추가 「메뉴」 안에 있어 그 점(가방이 가득 참 · 팔림)도 여기에 모은다
local function phoneMark()
	Touch.markMenu(state.moreMark == true or Hud.marks.bag == true or Hud.marks.auction == true)
end

-- ---------- 퀘스트 연출(장면 — 2026-10-15) ----------
--  사용자: "현재 메인 퀘스트 라인 너무스토리 몰입이 안됩니다 … 몰입되는 중간에 연출이 있는것도아니고 다른게임들 어떻게 스토리 진행하는지 좀 파악하고 만들어야합니다."
--  때(공방 js/lune/design/cine.js): 퀘스트를 받은 뒤(accept — 장의 첫 퀘스트면 장의 이름) · 할 일을 다 한 순간(goal) · 돌려준 뒤(complete) · 그 퀘스트를 하는 중에 맵에 들어섰을 때(enter) · 받기 전에 그 맵에 들어섰을 때(before)
--  한 캐릭터에 한 번만(서버가 캐릭터에 적는다 — me.cine). 줄을 서서 하나씩 튼다(막이 덮였거나 · 쓰러졌거나 · 주민과 말하는 중에는 기다린다)
state.cineQueue = {}
state.cineSeen = {}
local function cineSeen()
	local seen = table.clone(state.cineSeen)
	if state.me and state.me.cine then
		for _, id in state.me.cine do
			seen[id] = true
		end
	end
	for _, c in state.cineQueue do
		seen[c.id] = true
	end
	return seen
end
local function queueCine(list)
	for _, c in list do
		table.insert(state.cineQueue, c)
	end
end
local function cineWorld()
	return {
		hero = function()
			return { x = state.body.x, y = state.body.y, dir = state.dir }
		end,
		npc = function(id: string)
			if not state.view then
				return nil
			end
			for _, npc in state.view.npcs do
				if npc.def.id == id then
					return { x = npc.def.x, y = npc.def.y, dir = npc.def.dir, name = npc.def.name }
				end
			end
			return nil
		end,
		npcName = function(id: string)
			local a = CineView.npcArt(id)
			return a and a.name
		end,
		boss = function()
			if not state.mobs then
				return nil
			end
			for _, m in state.mobs.mobs do
				if m.def.story and m.state ~= "dead" then
					return { x = m.x, y = m.info.y } -- 높이는 info에(2026-10-18 검토: m.y는 없어 nil이었다)
				end
			end
			return nil
		end,
		cls = state.who,
		heroName = state.myName,
	}
end
-- 줄의 맨 앞 장면을 튼다(틀 수 있을 때)
-- 「메뉴」 판(PC · 폰) · 폰의 단추 배치를 닫는다: 장면 · 대화가 시작될 때(2026-10-18 검토: 그 판들이 대화창 · 장면 위에 떠서 누를 수 있었고,
--  폰에서는 판을 닫는 「메뉴」 단추가 숨어 고를 수밖에 없었다)
local function closeMenus()
	if state.closeMore then
		state.closeMore()
	end
	if state.closeTouchMenu then
		state.closeTouchMenu()
	end
	if Touch.arranging then
		Touch.arrange(false)
	end
end

local function playCine()
	if CineView.active() or #state.cineQueue == 0 or state.busy or state.dead or Curtain.covered() or not state.view then
		return
	end
	if Talk.npc and Talk.npc ~= Talk.CINE then
		return
	end
	local def = table.remove(state.cineQueue, 1)
	if state.cineSeen[def.id] or (state.me and state.me.cine and table.find(state.me.cine, def.id)) then
		return
	end
	-- 기술을 쓰는 중이면 그 기술을 멈춘다(2026-10-18 검토: 마지막 한 마리를 잡은 「목표 달성」 장면이 기술 도중에 오면 캐릭터가 휘두르는 자세로 굳었고, 장면 뒤에 남은 동작 · 대쉬가 나갔다)
	state.skill, state.push = nil, nil
	clearPips()
	Net.FireServer("Cine", "on", def.id) -- 그동안 맞지 않는다(어느 장면인지 알린다 — 서버는 아직 안 본 장면만 받는다)
	closeMenus()
	for _ = 1, 20 do -- 열린 창도 닫는다(장면의 위에 그려지고 단추가 눌렸다)
		if not Windows.closeTop() then
			break
		end
	end
	Hud.root.Visible = false
	if Touch.root then
		Touch.root.Visible = false
	end
	CineView.play(def, cineWorld(), state.view.mobLayer)
end

local function draw(dt: number)
	local body = state.body
	local char = state.sprite.char
	local sk = state.skill
	local poseClip: string, poseFrame: number -- 지금의 동작과 장(1부터)
	if sk and sk.kit then
		poseClip, poseFrame = sk.s.clip, kitFrame(sk) + 1
	elseif sk then
		local segDef = sk.def.segs[sk.seg]
		poseClip, poseFrame = segDef.clip, segDef.from + math.min(segDef.to - segDef.from, math.floor(sk.t * segDef.fps)) + 1
	elseif state.dead then
		-- 쓰러지는 동작을 한 번 틀고 마지막 장에서 멈춘다
		local n = #char.clips.death.frames
		poseClip, poseFrame = "death", math.min(n, math.floor(state.deadT * char.clips.death.fps) + 1)
	elseif state.hurtT > 0 then
		local n = #char.clips.hurt.frames
		poseClip, poseFrame = "hurt", math.min(n, math.floor((0.25 - state.hurtT) * 12) + 1)
	else
		poseClip = if state.clip == "skill" then "idle" else state.clip
		poseFrame = Sprite.frameAt(char, poseClip, state.clipT, poseClip == "jump")
	end
	-- 멈칫(타격감): 그동안은 방금의 동작과 장을 그대로 그린다
	local held = state.holdT > 0
	if held then
		state.holdT -= dt
		if state.heldClip then
			poseClip, poseFrame = state.heldClip, state.heldFrame
		end
	else
		state.heldClip, state.heldFrame = poseClip, poseFrame
	end
	-- 맞은 직후에는 깜빡인다
	local alpha = 0
	if not state.dead and state.blink > 0 and math.floor(state.now * 12) % 2 == 0 then
		alpha = 0.55
	end
	-- 이펙트를 돌리는 쪽에 내 모습을 알린다(자리 · 보는 쪽 · 지금의 동작과 장 · 배운 스킬 · 켜 둔 사출기)
	local cast, me = state.cast, state.actor
	-- 몸을 그린다 — 버프가 입히는 모습까지(거신의 두 배 · 비치는 몸 · 실루엣 · 윤곽을 따라 도는 빛 · 얹는 색): cast.luau의 look
	-- 탈것: 탄 동안 영웅은 서기 모습으로 앉는 자리에(사다리 위 · 기술 중 · 쓰러짐 · 맞음에는 탈것을 감추고 제 동작 그대로 — rideView.luau)
	local hx, hy = body.x, body.y
	if state.ride then
		local hide = body.climb ~= nil or sk ~= nil or state.dead or state.hurtT > 0
		-- 내 펫은 떨어진 것에 닿으면 서버에 알린다(PetPick — 서버가 거리 · 주인을 확인하고 줍는다)
		local rx, ry, rs = state.ride:update(state.now, dt, body.x, body.y, state.dir, math.abs(body.vx or 0) > 1, not body.ground, hide, state.fx and state.fx.drops, petPick)
		state.actor.rideSize = rs -- 탄 동안 영웅을 작게(cast.luau의 look이 곱한다 · 내리면 nil)
		if rx then
			hx, hy = rx, ry
			if not held then
				poseClip, poseFrame = "idle", Sprite.frameAt(char, "idle", state.now, false)
			end
		end
	end
	cast:look(me, state.sprite, poseClip, poseFrame, hx, hy, state.dir, alpha)
	-- 쓰러지는 동작이 끝나면 몸 대신 비석이 선다
	local downFor = if state.dead then state.deadT - #char.clips.death.frames / char.clips.death.fps else -1
	if downFor >= 0 then
		Grave.put(state.grave, body.x, body.y, downFor)
		state.sprite.label.Visible = false
	else
		state.grave.Visible = false
	end
	me.x, me.y, me.dir, me.ground, me.vx, me.vy = body.x, body.y, state.dir, body.ground, body.vx or 0, body.vy or 0
	if state.me then
		me.skills = state.me.skills
		me.toggle = state.me.kit ~= nil and state.me.kit.on == true
	end
	-- 지금의 동작과 장(0부터 — 시험 탭의 것과 같다): 분신 · 윤곽 · 잔상이 이 모습을 따라 그린다
	if sk and sk.kit then
		me.pose = { clip = sk.s.clip, f = kitFrame(sk) }
	elseif sk then
		local segDef = sk.def.segs[sk.seg]
		me.pose = { clip = segDef.clip, f = segDef.from + math.min(segDef.to - segDef.from, math.floor(sk.t * segDef.fps)) }
	elseif state.dead or state.hurtT > 0 then
		me.pose = nil
	else
		local clip = if state.clip == "skill" then "idle" else state.clip
		me.pose = { clip = clip, f = Sprite.frameAt(char, clip, state.clipT, clip == "jump") - 1 }
	end
	state.view.shakeX, state.view.shakeY = cast.sx, cast.sy
	-- 퀘스트 연출(장면): 맵에 들어섰을 때의 장면을 줄 세우고, 줄의 맨 앞을 튼다. 도는 동안은 카메라 · 주민의 자리 · 내 캐릭터가 보는 쪽이 장면의 것
	if state.cineScene ~= state.sceneKey and not state.busy and not Curtain.covered() and state.quests then
		state.cineScene = state.sceneKey
		local seen = cineSeen()
		queueCine(Cine.before(state.sceneKey, state.quests, seen))
		for id, st in state.quests do
			if not st.done then
				queueCine(Cine.findAll("enter", id, state.sceneKey, seen))
			end
		end
	end
	playCine()
	CineView.update(dt)
	local cst = CineView.state()
	state.view.camOverride = if cst then cst.cam else nil
	state.view.npcOver = if cst then cst.over else nil
	if cst then
		if cst.over.hero and cst.over.hero.dir then
			state.dir = cst.over.hero.dir
		end
		if cst.shakeT > 0 then
			state.view.shakeX += math.random(-cst.shakeA, cst.shakeA)
			state.view.shakeY += math.random(-cst.shakeA, cst.shakeA)
		end
	end
	-- 퀘스트 동안의 맵 모습(불타는 마을의 붉은 하늘 — 장면 밖에서도)
	do
		local active = {}
		for id, st in state.quests or {} do
			active[id] = not st.done
		end
		local hex, a = Cine.lookAt(state.sceneKey, active)
		CineView.setLook(if hex then Color3.fromHex(hex) else nil, a)
	end
	state.view:update(body.x, body.y, state.now, body.ground)
	HallStones.update()
	-- 스마트폰의 상호작용 단추가 지금 할 일: 떨어진 물건 → 문 → 주민의 차례로 가까운 것
	if Touch.on then
		Touch.setAct(if state.dead then nil elseif state.fx and state.fx:dropNear(body.x, body.y, RULES.pickup) then "pickup" elseif state.view:portalNear(body.x, body.y) or state.view:warpNear(body.x, body.y) then "portal" elseif nearSpot(body.x, body.y) then "spot" elseif state.view:npcNear(body.x, body.y) then "npc" elseif SCENES.scenes[state.sceneKey].vista and SCENES.scenes[state.sceneKey].vista.x and math.abs(body.x - SCENES.scenes[state.sceneKey].vista.x) <= 40 then "vista" else nil)
	end
	state.mobs:update(if held then state.holdNow else state.now) -- 멈칫하는 동안은 몬스터의 그림도 멈춘 순간 그대로(하얗게 번쩍인 채)
	state.boss:update(dt)
	RiftView.update(dt)
	VoyageView.update(dt)
	VistaView.update(dt)
	state.others:update(state.now, state.partySet)
	-- 다른 사람들: 그 사람의 자리에서 그 사람의 기술의 이펙트가 돈다
	for id, o in state.others.list do
		if o.placed then
			local a = cast:actor(id, o.class, false)
			a.x, a.y, a.dir = o.x, o.y, o.dir
			-- 그 사람의 몸에도 버프가 입히는 모습을 그린다(분신 · 윤곽은 그 사람의 지금 동작을 따라 그린다). 비석이 선 사람은 몸을 그리지 않는다
			if o.clip and not o.fallen then
				a.pose = { clip = o.clip, f = o.frame - 1 }
				a.rideSize = o.rideSize -- 탄 사람은 안장 위에 작게(othersView가 그린 자리 · 크기 그대로 — 전에는 o.x · o.y로 다시 그려 탄 사람이 땅으로 내려갔다)
				cast:look(a, o.sprite, o.clip, o.frame, o.hx or o.x, o.hy or o.y, o.dir, 0)
			end
		end
	end
	Cast.speed = tonumber(Stage.gui:GetAttribute("FxSpeed")) or 1 -- 확인용: PlayerGui.LuneStage의 속성 FxSpeed(예: 0.05)로 이펙트를 느리게 돌려 본다
	cast:update(dt)
	cast:draw()
	-- 캐시 무기의 피어오르는 점(2026-10-23): 내 영웅 · 다른 사람들의 그림(그린 뒤)
	if state.wfx then
		local list = { state.sprite }
		for _, o in state.others.list do
			table.insert(list, o.sprite)
		end
		state.wfx:step(list, dt)
	end
	-- 이름표(발밑): 모두 제 주인의 발밑 그 자리에 둔다 — 옮기지 않는다(사용자 2026-10-07: 내 이름이 주민 이름 아래로 밀려 내려가던 것).
	--  겹치면 앞선 것만 보인다: 내 것 → 다른 사람들 → 주민 · 문 → 다친 졸개
	local tags = { { x = Overlay.x(body.x) - math.floor(state.tag.Width / 2), y = Overlay.y(body.y) + Others.TAG_DOWN, w = state.tag.Width, frame = state.tag.Frame, move = true } }
	for _, t in state.others:tags() do
		t.move = true
		table.insert(tags, t)
	end
	for _, t in state.view:tagList() do
		table.insert(tags, t)
	end
	-- 달조각: 땅 위에서 천천히 오르내린다
	for i, sh in state.shards do
		local bob = math.floor(math.sin(state.clock * 2.4 + i) * 2 + 0.5)
		sh.frame.Position = UDim2.fromOffset(math.floor(sh.x - Kit.ICON * 0.375 + 0.5), sh.y - Kit.ICON * 0.75 - 6 + bob)
	end
	-- 퀘스트의 자리: 「!」는 늘 그 위에서 까딱이고, 「↑ 물을 뜬다」는 가까이 섰을 때만 뜬다
	for i, sp in state.spots do
		local mw, mh = sp.mark.Size.X.Offset, sp.mark.Size.Y.Offset
		sp.mark.Position = UDim2.fromOffset(math.floor(sp.x - mw / 2 + 0.5), sp.y - sp.up - mh + (if math.floor(state.clock * 2 + i) % 2 == 0 then 0 else 1)) -- up = 그 자리에 놓인 것의 키보다 조금 높게(자료)
		local near = math.abs(sp.x - body.x) <= Quests.USE_REACH.x and math.abs(sp.y - body.y) <= Quests.USE_REACH.y
		if near then
			table.insert(tags, { x = Overlay.x(sp.x) - math.floor(sp.tag.Width / 2), y = Overlay.y(sp.y - sp.up - mh) - Ui.TAG_H - 2, w = sp.tag.Width, frame = sp.tag.Frame, move = true })
		else
			sp.tag.Frame.Visible = false
		end
	end
	for _, t in state.mobs:tags() do
		t.move = true
		table.insert(tags, t)
	end
	local cineHide = CineView.hideTags() -- 장면의 암전 · 큰 그림 위로 이름표가 비치지 않게
	for i, on in Tags.visible(tags, Ui.TAG_H) do
		local t = tags[i]
		t.frame.Visible = on and not cineHide
		if t.move then
			t.frame.Position = UDim2.fromOffset(t.x, t.y)
		end
	end
	-- 스킬 칸: 다시 쓰기까지 남은 시간
	for _, sk in mySkills do
		Hud.setCooldown(sk.id, (state.cds[sk.id] or 0) - state.clock, sk.cd)
		Touch.setCooldown(sk.id, (state.cds[sk.id] or 0) - state.clock, sk.cd)
	end
	for id, def in COMBAT.placed do
		if def.cd > 0 and def.cast == "instant" and def.who == state.who and not Buffs.is(id) then
			Hud.setCooldown(id, (state.cds[id] or 0) - state.clock, def.cd)
			Touch.setCooldown(id, (state.cds[id] or 0) - state.clock, def.cd)
		end
	end
	for id, def in Buffs.data do
		if def.cd > 0 and def.cast ~= "seg" and (def.who == "all" or def.who == state.who) then
			Hud.setCooldown(id, (state.cds[id] or 0) - state.clock, def.cd)
			Touch.setCooldown(id, (state.cds[id] or 0) - state.clock, def.cd)
		end
	end
	for id, def in COMBAT.cast do
		if def.cd >= 1 and def.who == state.who then
			Hud.setCooldown(id, (state.cds[id] or 0) - state.clock, def.cd)
			Touch.setCooldown(id, (state.cds[id] or 0) - state.clock, def.cd)
		end
	end
	paintBuffs()
	if not state.skill or state.dead then
		clearPips()
	end
	state.fx:update(state.now, dt)
	-- 주민의 혼잣말(2026-10-14 — 머리 위 말풍선은 이것만): 가까이(IDLE.near) 있는 주민이 IDLE.gap초마다 한 줄. 한 번에 한 명 · 대화창이 떠 있으면 쉰다
	if state.view and not Talk.npc and not Talk.saying() then
		state.idleT = state.idleT or setmetatable({}, { __mode = "k" })
		local I = Format.IDLE
		for _, npc in state.view.npcs do
			local d = npc.def
			local said = d.idle or d.lines
			if said and #said > 0 and not d.stone then -- 게시판 · 비석(stone)은 혼잣말을 하지 않는다
				local t = (state.idleT[d] or (I.gap[1] + math.random() * (I.gap[2] - I.gap[1]))) - dt
				state.idleT[d] = t
				if t <= 0 then
					state.idleT[d] = I.gap[1] + math.random() * (I.gap[2] - I.gap[1])
					if math.abs(d.x - body.x) < I.near and math.abs(d.y - body.y) < 80 then
						Talk.say(d, said[math.random(#said)])
						break
					end
				end
			end
		end
	end
	Talk.place() -- 대화창의 글자가 한 글자씩 나오고, 혼잣말 말풍선은 그 주민을 따라간다
end

-- 장치의 모습을 화면에 옮긴다(내 상태가 올 때마다): 걸음 · 뛰는 힘의 배수 · 켜 둔 사출기의 칸 · 버프 자리(켜 둔 사출기) · 영혼과 열기(직업 묶음이 그린다)
local function applyKit(me)
	local kit = me.kit
	if not kit or not state.who then
		return -- 아직 직업을 고르기 전
	end
	if state.body then
		state.body.run, state.body.jump = me.run or 1, me.jump or 1
	end
	local k = KitSim.data[state.who]
	local active = {}
	if kit.on then
		active[k.toggle.id] = true
	end
	if kit.on and not state.kitOn and state.cast then
		state.cast:toggled(state.actor) -- 사출기를 켜는 순간: 발밑의 작은 기운(시험 탭과 같다)
	end
	state.kitOn = kit.on
	Hud.setActive(active)
	Touch.refresh()
	-- 버프: 걸린 것(남은 시간은 화면이 센다) · 공격 속도 · 다시 쓰기까지 남은 시간
	local view = me.buffs or { list = {}, cds = {} }
	state.buffs, state.buffAt = view.list, state.now
	state.haste = me.haste or 1
	state.full = false
	for _, b in view.list do
		if Buffs.data[b.id] and Buffs.data[b.id].fx.full then
			state.full = true
		end
	end
	for id, left in view.cds do
		state.cds[id] = state.clock + left
	end
	if state.cast then
		state.cast:setBuffs(state.actor, view.list)
		state.actor.haste = state.haste
	end
	syncKit()
end

-- 버프 그림의 설명(2026-10-18 — 공방 ui.js BUFFTIP · 시험 탭의 buffTipOf와 같은 글): 칸마다 { kind, title, tag, lines } — Hud가 마우스를 올리면 띄운다
local BUFFTIP = UI_DATA.buffTip
local SkillDamage = require(lune.ui.skillDamage)
local skillInfo = {} -- [스킬] = 설계의 한 줄(이름 · 최고 레벨 · 설명) — 다섯 직업의 1차 스킬과 차수마다의 스킬
for _, c in CLASSES.classes do
	for _, sk in c.skills or {} do
		skillInfo[sk.id] = sk
	end
	for _, tier in c.tiers or {} do
		for _, sk in tier.skills or {} do
			skillInfo[sk.id] = sk
		end
	end
end
local function leftText(s: number): string
	local t = if s >= 60 then Format.fill(BUFFTIP.min, { m = math.ceil(s / 60) }) else Format.fill(BUFFTIP.sec, { s = math.ceil(s) })
	return Format.fill(BUFFTIP.left, { t = t })
end
-- 그 스킬의 효과 한 줄: 내가 배운 스킬이면 그 레벨의 「지금」 글(스킬 창과 같다), 아니면(파티원이 건 버프) 스킬의 설명
-- 그 레벨의 효과 글은 스킬과 레벨로만 정해진다 — 기억해 두고 다시 쓴다(버프 줄이 매 장면 부른다 · 2026-10-18 검토)
local effectMemo: { [string]: string } = {}
local function effectOf(id: string): string
	local lv = state.me and state.me.skills and state.me.skills[id] or 0
	local key = id .. ":" .. lv
	local memo = effectMemo[key]
	if memo then
		return memo
	end
	local text = if lv > 0 then SkillDamage.text(id, lv) else nil
	local out = text or (skillInfo[id] and skillInfo[id].text) or ""
	effectMemo[key] = out
	return out
end
local function nameOf(id: string): string
	return skillInfo[id] and skillInfo[id].name or id
end

-- 퀵슬롯 칸의 설명(2026-10-18 — PC에서 칸에 마우스를 올리면): 스킬 = 이름 · 갈래 · Lv · 설명 · 그 레벨의 효과 / 소비 아이템 = 이름 · 가진 수 · 설명
Hud.slotTipOf = function(what: string)
	if Windows.isOpen("skill") then
		return nil -- 스킬 창이 열려 있으면(칸을 고치는 중) 설명을 띄우지 않는다(시험 탭과 같다 — 2026-10-18 검토)
	end
	local goods = Items.goods(what)
	if goods then
		return { kind = "main", title = goods.name, tag = ("x%d"):format(Bag.countIn(state.bag, what)), lines = { goods.text or "" } }
	end
	if Quick.ride(what) then
		local prod = CashWindow.product(what)
		local on = if Quick.ride(what) == "pet" then state.myPet == what else state.myRide == what
		local W = CashWindow.WORDS
		return { kind = "main", title = if prod then prod.name else what, tag = if on then (if Quick.ride(what) == "pet" then W.petOutTag else W.rideTag) else "", lines = { if prod then prod.line or "" else "" } }
	end
	local sk = skillInfo[what]
	if not sk then
		return nil
	end
	local lv = state.me and state.me.skills and state.me.skills[what] or 0
	local typeName = CLASSES.types and CLASSES.types[sk.type] or ""
	-- 효과 줄은 그 레벨의 효과가 있을 때만(배우지 않았으면 effectOf가 설명을 돌려줘 같은 글이 두 줄 나왔다 — 2026-10-18 검토)
	local effect = if lv > 0 then SkillDamage.text(what, lv) else nil
	return { kind = "sub", title = sk.name, tag = if lv > 0 then ("%s · Lv.%d"):format(typeName, lv) else typeName, lines = if effect and effect ~= "" and effect ~= sk.text then { sk.text or "", effect } else { sk.text or "" } }
end

-- 버프 자리(오른쪽 위): 켜 둔 사출기(시간 없이 맨 오른쪽) → 걸린 버프(건 차례로 — 그림 아래에 남은 초) → 열기(살라맨더).
--  장마다 부르지만 글이 바뀔 때(1초에 한 번)만 다시 그린다(Hud.setBuffs)
paintBuffs = function()
	local me = state.me
	if not me or not me.kit or not state.who then
		return
	end
	local k = KitSim.data[state.who]
	local list = {}
	if me.kit.on then
		table.insert(list, { pic = "skill_" .. k.toggle.id, text = "", tip = { kind = "sub", title = nameOf(k.toggle.id), tag = BUFFTIP.on, lines = { effectOf(k.toggle.id), BUFFTIP.onLine } } })
	end
	local passed = state.now - (state.buffAt or state.now)
	for _, b in state.buffs or {} do
		local left = b.t - passed
		if left > 0 then
			table.insert(list, { pic = "skill_" .. b.id, text = tostring(math.ceil(left)), hot = left < 5, tip = { kind = "sub", title = nameOf(b.id), tag = "", lines = { effectOf(b.id), leftText(left) } } })
		end
	end
	-- 열기(살라맨더): 발밑의 막대(직업 묶음이 그린다)는 이름표에 가려 잘 보이지 않는다 — 버프 자리에 값을 같이 적는다(달아오르면 노랑)
	if state.who == "salamander" and me.kit.heat > 0 then
		table.insert(list, { pic = "skill_" .. k.core.id, text = tostring(me.kit.heat), hot = me.kit.hot, tip = { kind = "sub", title = nameOf(k.core.id), tag = "", lines = { Format.fill(BUFFTIP.heat, { n = me.kit.heat }), effectOf(k.core.id) } } })
	end
	-- 약해짐(쓰러진 벌칙 — 경험치 · 물건을 덜 얻는다): 해골 그림 · 1분이 넘으면 「N분」, 그 아래는 초(2026-10-18 — 전에는 보이지 않아 왜 덜 얻는지 알 수 없었다)
	local weak = (state.weakLeft or 0) - (state.now - (state.weakAt or state.now))
	if weak > 0 and not state.dead then
		table.insert(list, { pic = "buff_death", text = if weak >= 60 then ("%d분"):format(math.ceil(weak / 60)) else tostring(math.ceil(weak)), tip = { kind = "none", title = BUFFTIP.weak.title, tag = "", lines = { BUFFTIP.weak.text, leftText(weak), BUFFTIP.weak.hint } } })
	end
	-- 경험치 쿠폰(유료 — 2026-10-20): 쿠폰 그림 · 남은 시간(게임 안에 있는 동안만 준다 — 서버의 Hero.tick)
	local expLeft = (state.expLeft or 0) - (state.now - (state.expAt or state.now))
	if expLeft > 0 and BUFFTIP.exp then
		table.insert(list, { pic = "buff_exp", text = if expLeft >= 60 then ("%d분"):format(math.ceil(expLeft / 60)) else tostring(math.ceil(expLeft)), tip = { kind = "none", title = BUFFTIP.exp.title, tag = "", lines = { BUFFTIP.exp.text, leftText(expLeft), BUFFTIP.exp.hint } } })
	end
	-- 영구 게임 패스(2026-10-22 — 경험치 · 드롭률 1.25배 패스): 버프 줄 끝에 그 상품의 그림 · 시간 대신 「영구」 · 설명 = 더하는 몫(%)
	if me.passes and BUFFTIP.pass then
		for _, id in { "xp125", "drop125" } do
			local p = if me.passes[id] then CashWindow.product(id) else nil
			if p and typeof(p.effect) == "table" then
				local lines = {}
				if (p.effect.xp or 0) > 0 then
					table.insert(lines, Format.fill(BUFFTIP.pass.xp, { n = math.floor(p.effect.xp * 100 + 0.5) }))
				end
				if (p.effect.drop or 0) > 0 then
					table.insert(lines, Format.fill(BUFFTIP.pass.drop, { n = math.floor(p.effect.drop * 100 + 0.5) }))
				end
				table.insert(lines, BUFFTIP.pass.hint)
				table.insert(list, { pic = p.icon, text = BUFFTIP.forever, tip = { kind = "none", title = p.name, tag = "", lines = lines } })
			end
		end
	end
	Hud.setBuffs(list)
	QuestHud.setBuffs(#list > 0) -- 퀘스트 알리미는 버프가 없을 때만 그 자리로 올라붙는다
end

-- ---------- 서버가 알려 주는 것 ----------
local function listen()
	local myId = Players.LocalPlayer.UserId
	Net.OnClient("Self", function(me)
		local jobWas = state.me and state.me.job
		state.me = me
		if state.sprite then
			state.sprite:setLook(state.lookOf(me.look)) -- 무기 · 로브 색(염색약을 쓰면 서버가 다시 보낸다) · 캐시 무기
		end
		state.weakLeft, state.weakAt = me.weak or 0, state.now -- 쓰러진 벌칙(약해짐)의 남은 초 — 받은 때부터 화면이 센다(paintBuffs)
		state.expLeft, state.expAt = me.expLeft or 0, state.now -- 경험치 쿠폰(유료)의 남은 초
		if jobWas and me.job and me.job > jobWas and state.onJob then
			state.onJob(me) -- 전직했다: 윗차수의 사냥기 · 보스기가 놓인 칸을 서버의 것으로 맞춘다
		elseif state.onJob and me.slots and me.skills then
			-- 스킬을 되돌렸다(초기화): 서버가 칸에서 배우지 않은 스킬을 뺐다 — 화면의 칸도 서버의 것으로(2026-10-18 검토: 사라진 스킬이 칸에 남아 다음 고치기가 한 번 튕겼다)
			for _, what in state.slots or {} do
				if what and not Quick.item(what) and not Quick.ride(what) and (me.skills[what] or 0) <= 0 then -- (펫 · 탈것은 스킬이 아니다 — 2026-10-21)
					state.onJob(me)
					break
				end
			end
		end
		Hud.setLocked(skillsLocked()) -- 스킬 칸의 잠금은 내 상태가 올 때마다 맞춘다(레벨이 먼저 오르는 경우에도 풀린다)
		applyKit(me)
		Hud.setSelf(me)
		local mark = (me.attReady or 0) + (me.achReady or 0) > 0 or (state.bond ~= nil and Bond.ready(state.bond)) -- 받을 출석 칸 · 업적 보상(2026-10-15) · 호감도 · 모험의 서의 보상(2026-10-16)
		Hud.markMenu("more", mark)
		state.moreMark = mark
		phoneMark()
		Windows.refresh(me)
		if state.tag and state.tagLevel ~= me.level then
			state.tagLevel = me.level
			state.tag:SetText(Others.tagText(me.level, state.myName))
			Ui.tagLead(state.tag, Others.levelText(me.level))
			if state.drawQuests then
				state.drawQuests() -- 레벨이 올라 새로 받을 수 있는 퀘스트의 표시
			end
		end
		if state.afterSelf then
			state.afterSelf(me)
		end
	end)
	Net.OnClient("Snap", function(key, list)
		if key == state.sceneKey and state.mobs then
			state.mobs:apply(list, state.now)
		end
	end)
	-- 때린 사람의 직업 색(민트 · 분홍) — 센 타격의 숫자에 쓴다
	local function toneOf(id: any): string
		local class = state.who
		if id ~= myId and state.others and state.others.list[id] then
			class = state.others.list[id].class
		end
		local def = class and CLASSES.classes[class]
		return if def then def.tone else "mint"
	end
	-- 그 번호의 사람(나 · 방의 다른 사람)의 이펙트 쪽 모습 — 없으면 nil
	local function actorOf(id: any)
		if id == state.myId then
			return state.actor
		end
		local o = state.others and state.others.list[id]
		return if o then state.cast:actor(id, o.class, false) else nil
	end
	Net.OnClient("Hits", function(by, list)
		local tone = toneOf(by)
		for _, h in list do
			local m = state.mobs and state.mobs:get(h.mob)
			if m then
				m.hp = h.hp
				-- 시험 탭과 같은 자리 · 같은 색: 발밑에서 16도트 위(우두머리는 30)에서 뜬다. 치명타는 때린 사람 직업의 밝은 색(보통의 타는 희다).
				--  맞는 순간 파편이 튀고, 쓰러지면 세모 파편이 터진다(시험 탭의 hurt)
				--  타수 나누기(sim/lines.luau): 한 타가 여러 줄(h.lines — 줄마다의 피해, 합 = h.dmg)로 오면 메이플처럼 한 줄씩 stagger초 사이로 rise점씩 위에 쌓여 뜬다(다다다다).
				--   번쩍임 · 파편 · 멈칫은 첫 줄에, 쓰러지는 파편은 마지막 줄에. 데미지 소리는 줄마다
				local lines = h.lines or { h.dmg }
				local function land(line: number)
					local first, last = line == 1, line == #lines
					-- 색: 보통의 타는 흰 숫자, 크리티컬만 때린 사람 직업의 밝은 색 숫자(사용자 2026-10-14: "크리티컬이 아닌 일반공격이 하얀색, 크리티컬이 뜨는게 색깔들어간 데미지 폰트") — 센 타도 크리티컬이 아니면 희다.
					--  크리티컬은 줄마다 따로 굴린다(h.crits[몇째 줄] — 서버의 Room:strike). crits가 없으면 그 타 전체가 크리티컬인가(h.crit — 흘리기 · 쪼개지 않은 타)
					local crit = if h.crits then h.crits[line] == true else h.crit == true
					local mine = by == state.myId
					if mine or ViewOpts.nums then -- 다른 사람의 피해 숫자는 설정의 「화면」에서 끌 수 있다(2026-10-18)
						state.fx:number(lines[line], m.x, m.info.y - MobsView.topOf(m) - LINES.rise * (line - 1), if crit then Effects.BIG[tone] else Effects.DEAL, crit)
					end
					-- 타격감(공방 combat.js의 hit): 몬스터가 하얗게 번쩍이며 때린 쪽의 반대로 조금 밀리고, 맞은 자리에 불꽃과 파편이 튄다.
					--  내가 직접 때린 타(따로 나가는 사출기 · 장치의 타는 빼고)에는 그림이 잠깐 멈칫한다 — gap초에 한 번만(연타가 굼떠지지 않게)
					local a = actorOf(by)
					local dir = if m.x >= (if a then a.x else state.body.x) then 1 else -1
					if first then
						MobsView.hit(m, state.now, dir)
					end
					if (first or (last and h.dead)) and (mine or ViewOpts.fx) then -- 맞은 자리의 불꽃 · 파편(다른 사람의 것은 「스킬 효과」를 끄면 없다 — 몬스터의 번쩍임은 그대로)
						state.cast:hurt(m, Cast.tone(tone), h.big, h.dead and last, dir)
					end
					local H = RULES.hit
					if first and by == state.myId and not h.proc and state.now - state.holdAt >= H.gap then
						state.holdAt, state.holdNow = state.now, state.now
						state.holdT = if h.big or h.dead then H.holdBig else H.hold
					end
					-- 데미지 소리: 내 타의 숫자가 뜰 때마다 한 번(사용자 2026-10-14: "출력되는 데미지는 이소리를 아주 짧게 재생합니다. 한 틱당 한번재생" —
					--  3타 기술이 한 마리에 맞으면 타타타 세 번, 세 마리에 같이 맞으면 마리마다 — 그래서 이 소리는 틈(gap)이 0이다). 다른 사람의 타는 소리 없이 숫자만(내 판단)
					--  줄마다는 짧게(다다다다) 내다가 그 타의 마지막 줄은 끝까지 낸다(사용자 2026-10-14: "데미지 출력음 다다다다 하다가 마지막 출력음은 끝까지 출력")
					if by == state.myId then
						Music.sfx("damage", last)
					end
				end
				-- 따로 나가는 타(사출기 · 장치): 그 직업의 이펙트가 날아가 닿는 순간에 숫자가 뜬다(달빛 도끼 · 표창 · 도깨비불 · 수정 조각 · 불티 · 불꽃).
				--  그 사람이 아직 화면에 없으면(방금 들어왔다) 숫자만 바로 띄운다
				if not (h.proc and (by == state.myId or ViewOpts.fx) and state.cast:proc(actorOf(by), h.proc, m, h.sx, h.sy, function()
					land(1)
				end, h)) then
					land(1)
				end
				-- 둘째 줄부터: stagger초 사이로 하나씩(그 사이에 장면이 바뀌었으면 띄우지 않는다)
				if #lines > 1 then
					local mobsNow = state.mobs
					for line = 2, #lines do
						task.delay((line - 1) * LINES.stagger, function()
							if state.mobs == mobsNow then
								land(line)
							end
						end)
					end
				end
				-- 표식(리븐): 졸개 머리 위에 남는다
				if h.dead then
					m.mark = 0
				elseif h.mark then
					m.mark, m.markT = h.markN or 1, h.mark -- 깊은 표식을 배운 리븐의 것은 셋까지 겹친다
				end
			end
		end
	end)
	-- 무니의 달 수정이 서고 사라진다
	Net.OnClient("Crystal", function(e)
		if not state.fx then
			return
		end
		for _, id in e.gone do
			crystalGone(id)
		end
		for _, c in e.add do
			crystalAdd(c)
		end
	end)
	-- 피했다(리븐의 날랜 몸)
	Net.OnClient("Dodge", function()
		if state.fx then
			state.fx:float("회피", state.body.x, state.body.y - 30, Effects.MINT, 0.9)
			state.blink = RULES.invuln
		end
	end)
	-- 서버가 내 자리를 바로잡는다(너무 멀리 간 자리 보고를 받지 않았다)
	Net.OnClient("Warp", function(x, y)
		if state.body and typeof(x) == "number" and typeof(y) == "number" then
			state.body.x, state.body.y, state.body.vx, state.body.vy = x, y, 0, 0
			P.unstick(SCENES.scenes[state.sceneKey], state.body) -- 되돌려 준 자리가 땅 속이면 꺼낸다(2026-10-21 — 폰에서 끼임)
			state.body.climb = nil -- 사다리를 잡고 있었으면 놓는다(그대로면 다음 장에 사다리로 끌려가 서버와 엇갈렸다 — 2026-10-18 검토)
			state.push = nil -- 밀려나는 중 · 스킬이 몸을 밀고 나가는 중이면 멈춘다(그대로면 다시 멀어져 한 번 더 되돌려졌다 — 2026-10-18 검토)
			if state.skill then
				state.skill.imp = nil
			end
			state.sentX = -1
		end
	end)
	-- 누군가의 회복 스킬로 체력이 찼다(달빛 치유): 머리 위에 민트색 숫자
	Net.OnClient("Healed", function(amount)
		if state.fx and typeof(amount) == "number" then
			state.fx:number(amount, state.body.x, state.body.y - 22, Effects.MINT)
		end
	end)
	-- 스킬의 다시 쓰기가 바뀌었다(종결이 적을 쓰러뜨리면 바로 다시 쓴다)
	Net.OnClient("Cool", function(skillId, left)
		if typeof(skillId) == "string" then
			state.cds[skillId] = state.clock + (tonumber(left) or 0)
		end
	end)
	Net.OnClient("Hurt", function(e)
		state.fx:number(e.dmg, state.body.x, state.body.y - 22, Effects.HURT) -- 머리 바로 위에서 뜬다(졸개의 숫자가 발밑에서 16 위인 것과 같은 느낌) · 맞는 소리는 없다(사용자 2026-10-14)
		state.blink = RULES.invuln
		if not state.skill then
			state.hurtT = 0.25 -- 기술을 쓰는 중이 아니면 맞는 동작을 잠깐 보인다
		end
		if e.dead then
			state.dead = true
			state.deadT = 0
			if Talk.npc and Talk.npc ~= Talk.CINE then
				Talk.close() -- 대화창이 떠 있으면 닫는다(대화창이 늘 보이는 화면을 가려 쓰러진 상자가 보이지 않았다 — 2026-10-18 검토)
			end
			state.skill = nil
			state.body.climb, state.push = nil, nil -- 사다리 위에서 쓰러지면 비석이 공중에 남지 않게(2026-10-18 검토)
			state.fx:float("쓰러졌다", state.body.x, state.body.y - 46, Effects.PINK, 2.2)
			Music.sfx("gameover") -- 효과음(배경 음악은 줄이지 않는다 — 사용자 2026-10-14: 사망 징글은 없다)
		end
	end)
	Net.OnClient("Gain", function(e)
		state.fx:float("+" .. e.xp, state.body.x, state.body.y - 34, Effects.MINT)
		GainLog.xp(e.xp)
		if typeof(e.money) == "number" and e.money > 0 then
			GainLog.money(e.money) -- 퀘스트 · 일일 의뢰 · 토벌 보상의 달돈(2026-10-18)
		end
		if typeof(e.dust) == "number" and e.dust > 0 then
			GainLog.dust(e.dust)
		end
		if e.ups > 0 then
			GainLog.level(e.level)
			-- 레벨 업 연출(2026-10-18): 화면 위쪽 가운데의 큰 알림 + 캐릭터 둘레의 빛(전에는 머리 위 글씨와 소리뿐이었다)
			Guide.banner(("레벨 업! Lv.%d"):format(e.level), nil, 2.5)
			if state.cast and state.actor then
				state.cast:levelUp(state.actor)
			end
			state.fx:float("레벨 업! Lv." .. e.level, state.body.x, state.body.y - 48, Effects.GOLD, 1.8)
			Music.jingle("victory")
			if e.level >= Daily.FROM then
				if e.level - e.ups < Daily.FROM then
					Guide.banner(Daily.WORDS.open, Daily.WORDS.openHint, 6) -- Lv.10: 「일일 의뢰가 열렸다」
				end
				if state.fetchDaily then
					state.fetchDaily()
				end
			end
		end
	end)
	Net.OnClient("DropAdd", function(d)
		if state.fx then
			state.fx:addDrop(d)
		end
	end)
	Net.OnClient("DropGone", function(id, taker, amount)
		local d = state.fx and state.fx:removeDrop(id)
		if d and taker == state.myId then
			Music.sfx(if d.kind == "gear" or d.kind == "quest" or d.kind == "goods" then "pick" else "coin") -- 내가 주웠다
		end
		if d and taker == myId then
			if d.kind == "gear" then
				state.fx:float(ItemCell.label(d.item), d.x, d.y - 18, ItemCell.color(d.item), 1.6)
				GainLog.item(ItemCell.label(d.item), ItemCell.color(d.item))
			elseif d.kind == "quest" or d.kind == "goods" then
				state.fx:float("+1 " .. tostring(d.name), d.x, d.y - 18, if d.kind == "quest" then Effects.GOLD else Effects.MINT, 1.2) -- 퀘스트의 물건은 노랑 · 재료와 물약은 민트
				GainLog.item(tostring(d.name), if d.kind == "quest" then Ui.COLOR.gold else nil)
			elseif d.kind == "dust" then
				state.fx:float("+" .. Format.short(amount) .. " 달가루", d.x, d.y - 18, Effects.MINT)
				GainLog.dust(amount or 0)
			else
				state.fx:float("+" .. Format.short(amount) .. " 달돈", d.x, d.y - 18, Effects.GOLD)
				GainLog.money(amount or 0)
			end
		end
	end)
	-- 같은 맵의 다른 사람들: 이름표 · 자리 · 기술
	Net.OnClient("Who", function(key, roster)
		-- 내 펫 · 탈것(서버가 정한 것 — 펫을 꺼냈다 · 탔다 · 기술을 써서 내렸다)
		for _, w in roster do
			if w.id == state.myId then
				local changed = state.myPet ~= (w.pet or nil) or state.myRide ~= (w.ride or nil) or state.mySkin ~= (w.wskin or nil)
				state.myPet, state.myRide = w.pet or nil, w.ride or nil
				state.mySkin = w.wskin or nil -- 장착한 캐시 무기(2026-10-23)
				if state.sprite then
					state.sprite:setLook(state.lookOf(state.me and state.me.look))
				end
				if state.ride then
					state.ride:setPet(state.myPet)
					state.ride:setRide(state.myRide)
				end
				if changed and state.me then
					Windows.refresh(state.me) -- 가방의 캐시 탭(꺼내 둔 펫 · 타는 탈것의 점)
				end
			end
		end
		if key == state.sceneKey and state.others then
			local before = {}
			for id in state.others.list do
				before[id] = true
			end
			state.others:setWho(roster)
			-- 맵을 떠난 사람의 효과(영혼 · 수정 · 열기 · 버프의 모습)를 걷는다(2026-10-18 검토: 남아서 그 자리에 계속 그려졌다)
			if state.cast then
				for id in before do
					if not state.others.list[id] and id ~= state.myId then
						state.cast:drop(id)
					end
				end
			end
			Windows.refresh(state.me)
		end
	end)
	Net.OnClient("Heroes", function(key, list)
		if key == state.sceneKey and state.others then
			state.others:apply(list, state.now)
		end
	end)
	-- 방의 누군가에게 걸린 버프가 바뀌었다: 그 사람의 몸에 버프의 모습이 보인다
	Net.OnClient("Buffs", function(id, list)
		local o = state.others and state.others.list[id]
		if o and state.cast then
			state.cast:setBuffs(state.cast:actor(id, o.class, false), list)
		end
	end)
	Net.OnClient("Act", function(id, skillId, seg, x, y, dir, lv)
		-- 다른 사람이 버프를 건다 · 설치 · 소환을 놓는다(바로 놓이는 것): 그 순간의 이펙트
		if Buffs.instant(skillId) or (COMBAT.placed[skillId] and COMBAT.placed[skillId].cast == "instant") then
			local o = state.others and state.others.list[id]
			if o and state.cast and ViewOpts.fx then -- 다른 사람의 스킬 효과(설정의 「화면」에서 끌 수 있다 — 2026-10-18)
				local a = state.cast:actor(id, o.class, false)
				a.x, a.y, a.dir = x, y, dir
				state.cast:instant(a, skillId)
			end
			return
		end
		-- 2~4차의 스킬 가운데 쓰는 동작이 없는 것(열 방출)
		if COMBAT.cast[skillId] and Kitset.skill(skillId) and Kitset.skill(skillId).instant then
			local o = state.others and state.others.list[id]
			if o and state.cast and ViewOpts.fx then -- 다른 사람의 스킬 효과(설정의 「화면」에서 끌 수 있다 — 2026-10-18)
				local a = state.cast:actor(id, o.class, false)
				a.x, a.y, a.dir = x, y, dir
				state.cast:instant(a, skillId)
			end
			return
		end
		if state.others then
			state.others:act(id, skillId, seg, x, y, dir, state.now)
			-- 그 사람의 기술의 이펙트(이동기는 othersView가 잔상 · 속도선을 낸다)
			local o = state.others.list[id]
			local def = COMBAT.skills[skillId] or COMBAT.cast[skillId]
			if o and def and def.type ~= "move" and state.cast and ViewOpts.fx then
				local a = state.cast:actor(id, o.class, false)
				a.x, a.y, a.dir = x, y, dir
				state.cast:start(a, skillId, seg, lv or 0)
			end
		end
	end)
	-- 파티
	Net.OnClient("PartyInfo", function(info)
		state.party = info
		table.clear(state.partySet)
		for _, m in info.members do
			state.partySet[m.id] = true
		end
		PartyHud.set(info, state.myId, state.sceneKey)
		Windows.refresh(state.me)
	end)
	Net.OnClient("PartyAsk", function(ask)
		PartyHud.ask(ask)
	end)
	-- 퀘스트: 바뀐 상태. doneId = 방금 끝낸 퀘스트
	Net.OnClient("Quests", function(book, doneId)
		local lockedWas = skillsLocked()
		-- 방금 받은 퀘스트: 머리 위에 「○○ 수락」
		for id, st in book do
			local q = Quests.def(id)
			if q and not st.done and not (state.quests or {})[id] then
				if state.fx then
					state.fx:float(("「%s」 수락"):format(q.name), state.body.x, state.body.y - 84, Effects.MINT, 2)
				end
				-- 메인 · 전직 퀘스트는 받으면 길찾기가 켜진다(사용자 2026-10-13: "메인 퀘스트는 수락하면  길찾기가 활성화가 되는게 디폴트입니다") — 알리미의 화살표 단추로 끈다
				if q.kind == "main" or q.kind == "job" then
					state.navi = id
				end
			end
		end
		-- 퀘스트 연출: 받은 퀘스트(장의 이름 · 받은 뒤의 장면) · 할 일을 다 한 퀘스트 · 돌려준 퀘스트의 장면을 줄 세운다(들어올 때의 첫 상태는 거른다)
		if state.quests then
			local old, seen = state.quests, cineSeen()
			for id, st in book do
				if not st.done and not old[id] then
					queueCine(Cine.findAll("accept", id, nil, seen))
				end
				if old[id] and Quests.isReady(book, id) and not Quests.isReady(old, id) then
					queueCine(Cine.findAll("goal", id, state.sceneKey, seen))
				end
			end
			if doneId then
				queueCine(Cine.findAll("complete", doneId, nil, seen))
			end
		end
		state.quests = book
		if state.drawQuests then
			state.drawQuests()
		end
		local def = doneId and Quests.def(doneId)
		if def and state.fx and def.kind ~= "job" then -- 전직은 화면 가운데의 큰 알림이 알린다
			state.fx:float(("「%s」 완료"):format(def.name), state.body.x, state.body.y - 84, Effects.GOLD, 2.2) -- 쌓인 이름표 · 레벨 업 글씨보다 위에
			GainLog.quest(def.name)
			Music.sfx("success") -- 효과음(사용자 2026-10-14: 퀘스트 완료 징글은 없다)
		end
		-- 사제에게 첫 기술을 배웠다: 스킬 칸이 생긴다
		if lockedWas and not skillsLocked() then
			Hud.setLocked(false)
			Guide.banner("기술을 배웠다", "화면 아래에 스킬 칸이 생겼다", 4)
		end
		-- 그 퀘스트를 끝내야 열리는 문이 열렸다(초승달 마을의 작은 나루 — 「불타는 마을」): 어디에 무엇이 열렸는지 알린다
		if def then
			for _, o in Quests.opens(def.id) do
				Guide.banner(Quests.OPENED.head, Quests.OPENED.line:format(o.place, o.label), 7)
			end
		end
		-- 전직 퀘스트: 받을 수 있게 됐다("달이 부른다") · 돌려줘서 전직했다
		jobCall()
		if def and def.kind == "job" and def.reward.job then
			Guide.banner(("%d차 전직"):format(def.reward.job), "스킬 창에 새 스킬이 열렸다 — 사냥기와 보스기가 새것으로 바뀌었다", 6)
			Music.jingle("jobup")
		end
	end)
	Net.OnClient("Bag", function(bag)
		state.bag = bag
		-- 가방이 가득 찼다(2026-10-18): 가방 단추에 점 · 새로 가득 찬 탭은 획득 알림에 한 줄(들어올 때의 첫 상태는 알리지 않는다)
		local full, now = Bag.fullTabs(bag), {}
		Hud.markMenu("bag", #full > 0)
		phoneMark()
		for _, tab in full do
			now[tab] = true
			if state.bagFull and not state.bagFull[tab] then
				local i = table.find(Bag.TABS, tab) or 1
				GainLog.add("note", Format.fill(UI_DATA.words.bagFull, { tab = Items.data.BAG.tabs[i] }), Ui.COLOR.red)
			end
		end
		state.bagFull = now
		Hud.setCounts() -- 퀵슬롯에 놓인 소비 아이템의 수
		Touch.setCounts()
		Windows.refresh(state.me)
	end)
	-- 물건을 다룬 결과: 안 됐으면 까닭을 머리 위에, 강화의 결과는 강화 창에
	Net.OnClient("ItemDone", function(e)
		if e.action == "enhance" then
			-- 대장장이 창의 연출이 이 결과를 기다린다(번호가 오르면 보인다) — 안 됐으면 까닭을 창의 결과 줄에
			state.ui.forgeResult = if e.ok then e.result else nil
			state.ui.forgeWhy = if e.ok then nil else e.why
			state.ui.forgeSeq = (state.ui.forgeSeq or 0) + 1
		elseif e.action == "restore" and not e.ok then
			state.ui.forgeWhy = e.why -- 되살리기가 안 됐다: 대장장이 창의 결과 줄에(머리 위에만 떴다 — 2026-10-18 검토)
		elseif e.action == "restore" and e.ok then
			state.ui.forgeResult, state.ui.forgeWhy, state.ui.forgeMat = "restore", nil, nil -- 「되살렸다 — 12성」(대장장이 창의 RESULT — 붉은 「안 된 까닭」 줄이 아니다)
		elseif (e.action == "dismantle" or e.action == "dismantleMany") and e.ok and state.fx then -- (여러 개 분해도 — 2026-10-22)
			state.fx:float("+" .. Format.short(e.result) .. " 달가루", state.body.x, state.body.y - 34, Effects.MINT)
		elseif (e.action == "sell" or e.action == "sellMany") and e.ok and state.fx then -- (여러 개 판매도 — 2026-10-23)
			state.fx:float("+" .. Format.short(e.result) .. " 달돈", state.body.x, state.body.y - 34, Effects.GOLD) -- 상점에 팔았다
		elseif e.action == "use" and e.ok and e.why and state.fx then
			state.fx:float(e.why, state.body.x, state.body.y - 46, Effects.MINT, 1.6) -- 달빛 부적 · 능력치 초기화 주문서를 썼다(「약해짐이 풀렸다」 · 「능력치를 모두 되돌렸다」 — 2026-10-18 검토: 전에는 실패만 띄웠다)
		elseif e.action == "craft" and e.ok and e.result then
			state.ui.craftResult = e.result -- 대장장이가 만들어 준 장비(제작 창이 이름을 적는다)
			if state.fx then
				state.fx:float(ItemCell.label(e.result), state.body.x, state.body.y - 34, ItemCell.color(e.result), 1.8)
			end
		end
		if not e.ok and e.why and state.fx then
			state.fx:float(e.why, state.body.x, state.body.y - 46, Effects.PINK, 1.4)
		end
		Windows.refresh(state.me)
	end)
	Net.OnClient("Shot", function(s)
		if state.fx then
			state.fx:addShot(s, state.now)
		end
	end)
	Net.OnClient("MobCast", function(e)
		if state.fx then
			state.fx:addMobCast(e.kind, e.x, e.y, e.dir)
		end
	end)
	Net.OnClient("ShotEnd", function(id)
		if state.fx then
			state.fx:endShot(id)
		end
	end)
	-- 경매장에 올린 것이 팔렸다(2026-10-18 — 다른 서버의 구매도 서버가 옮겨 준다): 획득 알림 한 줄 · 「경매」 단추의 점(경매장을 열면 꺼진다)
	-- 관리자의 확성기(2026-10-21 — 모든 서버의 모두에게): 화면 위 큰 알림 「공지」(8초 · 두 줄까지) + 채팅 알림 글(다 보인다)
	Net.OnClient("Megaphone", function(text)
		if typeof(text) ~= "string" then
			return
		end
		pcall(Guide.banner, "공지", text, 8)
		Chat.note("[공지] " .. text)
	end)
	-- 만렙 최초 달성(2026-10-24 사용자 "150만렙 맨 처음 찍는 유저 나타나면 바로 전서버에 축하알림뜨면서 레벨 랭킹 1위 실시간 박제되게"):
	--  모든 서버의 모두에게 화면 위 큰 알림 「축하」(10초) + 채팅 알림 글 · 명예의 전당 비석을 바로 다시 받는다(레벨 판 1위에 고정 — 서버의 rankBoards)
	Net.OnClient("FirstMax", function(e)
		if typeof(e) ~= "table" or typeof(e.name) ~= "string" then
			return
		end
		local Rank = require(lune.sim.rank)
		local text = Format.fill(Rank.FIRST_TEXT, { name = e.name, level = tonumber(e.level) or 150 })
		pcall(Guide.banner, Rank.FIRST_TITLE, text, 10)
		Chat.note(("[%s] %s"):format(Rank.FIRST_TITLE, text))
		HallStones.soon()
	end)
	Net.OnClient("Sold", function(e)
		if typeof(e) ~= "table" then
			return
		end
		GainLog.add("note", Format.fill(Market.WORDS.soldNote, { name = tostring(e.name), n = tonumber(e.n) or 1 }), Ui.COLOR.gold)
		if not Windows.isOpen("auction") then
			Hud.markMenu("auction", true)
			phoneMark()
		end
	end)
	-- 사냥터 정예가 나왔다(2026-10-18 — 공방 combat.js FIELD_ELITE): 나온 자리의 높이로 옮겨 그리고(다른 층의 자리일 수 있다) 화면 위 가운데에 알림
	Net.OnClient("Elite", function(e)
		if e.room ~= state.sceneKey then
			return -- 그새 맵을 옮겼다
		end
		local m = state.mobs and state.mobs.mobs[e.mob]
		if m then
			m.info.y = e.y
		end
		if state.cast and e.x then
			state.cast:eliteRise(e.x, e.y) -- 그 자리에서 분홍 기운이 솟는다
		end
		local def = COMBAT.mobs[e.kind]
		local words = COMBAT.fieldElite.words
		Guide.banner(Format.fill(words.head, { name = if def then def.name else "" }), words.sub, 3)
	end)
	-- 서버가 나를 다른 장면으로 옮겼다(마을로 돌아가기 · 관리 이동): 문을 지날 때와 같은 길로(막 → 그리기 → 그림 불러오기 → 막 걷기)
	Net.OnClient("Revive", function(e)
		state.dead = false
		Input.flush() -- 쓰러져 있는 동안 누른 것은 버린다
		DeathBox.hide()
		goScene(e)
	end)
	-- 소생을 받아 그 자리에서 일어났다(관리의 「체력 채우기」로 일어났을 때도)
	Net.OnClient("Raise", function(_e)
		state.dead = false
		Input.flush()
		state.blink = 2
		DeathBox.hide()
		if state.fx then
			state.fx:float("일어났다", state.body.x, state.body.y - 46, Effects.MINT, 1.6)
		end
	end)
end

-- 확인용: 지금 상태를 화면 틀의 속성으로 적어 둔다(Studio에서 읽어 본다)
local function debugMarks()
	local gui = Stage.gui
	gui:SetAttribute("Scene", state.sceneKey)
	gui:SetAttribute("HeroX", math.floor(state.body.x + 0.5))
	gui:SetAttribute("HeroY", math.floor(state.body.y + 0.5))
	gui:SetAttribute("Dead", state.dead)
	gui:SetAttribute("Class", state.who)
	if state.me then
		gui:SetAttribute("Power", state.me.power)
		gui:SetAttribute("Level", state.me.level)
		gui:SetAttribute("Hp", state.me.hp)
		gui:SetAttribute("Xp", state.me.xp)
		gui:SetAttribute("Money", state.me.money)
		gui:SetAttribute("Potions", state.me.potions)
	end
end

function Boot.start()
	Stage.init()
	Overlay.init()
	Input.init()
	-- 퀵슬롯 · 스마트폰 단추에 놓인 소비 아이템의 숫자 = 가방에 든 그 아이템의 수
	Hud.countOf = function(id: string): number
		return Bag.countIn(state.bag, id)
	end
	Hud.init()
	listen()

	-- 처음 화면에 쓰는 그림(제목 · 캐릭터 · 화면 부품 · 글자판)만 먼저 불러온다 — 나머지는 로딩 화면이 뜬 채로 불러온다
	Hud.root.Visible = false
	preload({ "title_", "chars_", "ui_kit", "font_", "shop_" }, nil) -- shop_ = 달빛 상점의 배경(2026-10-21 — 처음에 받아 두어 상점에 들어갈 때 기다림이 거의 없게)
	local first = Net.Invoke("Ready")
	for _ = 1, 30 do -- 서버가 아직 계정을 읽는 중이었다(답이 비었다): 조금 뒤 다시 묻는다(2026-10-18 검토 — 전에는 검은 화면에 멈췄다 · 서버는 잠긴 계정을 40초까지 기다린다)
		if first then
			break
		end
		task.wait(2)
		first = Net.Invoke("Ready")
	end
	if first and first.select then
		Music.import(first.select.sound) -- 계정에 저장된 소리 설정(처음 화면부터 그 크기로)
		ViewOpts.import(first.select.sound) -- 같은 표의 화면 설정(다른 사람의 스킬 효과 · 피해 숫자)
		Music.play(MUSIC.title)
		-- 로딩 화면 → START → 캐릭터 고르기. 캐릭터로 들어가면 서버가 준 내 상태와 방을 받아 이어 간다(그동안 늘 보이는 화면은 숨긴다)
		first = Title.run(first.select, {
			invoke = function(action: string, a: any, b: any)
				return Net.Invoke("Chars", action, a, b)
			end,
			preload = function(notify)
				preload(nil, notify)
			end,
		})
	else
		preload(nil, nil) -- 확인용 임시 캐릭터(LuneGuest = 직업): 처음 화면 없이 바로 들어간다
	end
	if not (first and first.self) then
		-- 끝내 받지 못했다: 검은 화면에 멈추지 않고 알린다(2026-10-18 검토 — 전에는 assert로 화면 코드가 멈춰 빈 화면만 남았다)
		local why = Ui.text(Stage.ui, "서버에 연결하지 못했습니다. 다시 들어와 주세요.", 0, math.floor(Stage.uiH / 2) - 8, Stage.uiW, { font = "body", align = "center", outline = true })
		why.label.Frame.ZIndex = 500
		warn("[lune] 서버에서 캐릭터를 받지 못했다")
		return
	end
	Hud.root.Visible = true
	-- 서버가 준 캐릭터를 화면의 상태에 얹는다(처음 들어올 때 · 캐릭터 고르기 화면에서 다른 캐릭터로 들어올 때)
	local function adopt(got)
		state.me = got.self
		state.navi = nil -- 길찾기는 캐릭터마다 다시 켠다
		Hud.resetHp() -- 들어온 캐릭터의 체력에서 다시 시작한다(앞 캐릭터와 견준 효과가 뜨지 않게)
		state.myId, state.myName = got.id, got.name
		state.quests = got.quests or {}
		state.bond = got.bond
		state.bag = got.bag
		-- 가방이 가득 찼는가: 들어올 때의 것은 알리지 않고 가방 단추의 점만(캐릭터를 바꿔도 앞 캐릭터의 것이 남지 않게 — 2026-10-18)
		state.bagFull = {}
		local fullNow = Bag.fullTabs(got.bag)
		for _, tab in fullNow do
			state.bagFull[tab] = true
		end
		Hud.markMenu("bag", #fullNow > 0)
		phoneMark()
		state.who = got.self.class
		state.dead, state.skill, state.party = false, nil, nil
		table.clear(state.cds)
		-- 캐릭터마다 다른 것(2026-10-18 검토): 본 장면(새 캐릭터가 첫 장면을 못 보던 것) · 약해짐의 남은 시간 · 꿈의 미션 판 · 메뉴의 점
		table.clear(state.cineSeen)
		table.clear(state.cineQueue)
		state.cineScene = nil
		state.weakLeft, state.weakAt = got.self.weak or 0, state.now
		state.expLeft, state.expAt = got.self.expLeft or 0, state.now
		TutView.reset()
		do
			local me = got.self
			local mark = (me.attReady or 0) + (me.achReady or 0) > 0 or (got.bond ~= nil and Bond.ready(got.bond))
			Hud.markMenu("more", mark)
			state.moreMark = mark
			phoneMark()
		end
		-- 「달이 부른다」는 캐릭터마다 다시 센다(받을 수 있는 전직 퀘스트가 있으면 들어온 뒤 한 번 알린다)
		table.clear(state.jobSeen)
		Hud.setLocked(skillsLocked())
		Hud.setSelf(got.self)
		applyKit(got.self)
		Hud.setName(state.myName)
		-- 내 직업의 기술(사냥기 · 보스기 · 이동기 차례로)과 그 기본 키
		local order = { mob = 1, boss = 2, move = 3 }
		table.clear(mySkills)
		for id, def in COMBAT.skills do
			if def.who == state.who then
				table.insert(mySkills, { id = id, name = def.name, type = def.type, order = order[def.type] or 9, cd = def.cd })
			end
		end
		table.sort(mySkills, function(a, b)
			return a.order < b.order
		end)
		-- 칸에 놓인 것은 서버가 저장해 둔 것(없으면 처음 차림)
		state.slots = got.self.slots or Quick.start(CLASSES.classes[state.who].skills)
		state.touchSlots = got.self.tslots or Quick.touchStart(CLASSES.classes[state.who].skills) -- 스마트폰의 단추 배치(PC의 퀵슬롯과 따로 저장한다 · 단추가 없는 칸 1은 비운다)
	end
	adopt(first)
	-- 퀵슬롯: 키는 스킬이 아니라 칸에 붙는다(칸마다 하나 — 공방의 QUICK.keys)
	for i, name in QUICK.keys do
		Input.bind("slot:" .. i, (Enum.KeyCode :: any)[name])
	end

	-- 창: 능력치 · 스킬 · 키 설정. 여는 키는 공방에서 정한 것(P · K — 키 설정은 메뉴에서)
	local function keyName(action: string): string
		local key = Input.BIND[action]
		return Format.key(if key then key.Name else "-")
	end
	-- 메뉴 단추: 앞의 여섯(가방 · 장비 · 능력치 · 스킬 · 퀘스트 · 월드맵 — 열린 것만)은 그림 단추로, 나머지 창과 키 설정은 「메뉴」 단추 안에
	--  월드맵은 2026-10-11에 꺼냈다(사용자: "이 기본 버튼에 월드맵도 있어야합니다. 메뉴를 누르고 월드맵누르는게 아니라")
	-- 화면 아래의 그림 단추(나머지 창은 「메뉴」 안에): 무엇을 어느 차례로 놓는가는 설계에 있다(공방 design/ui.js의 menu.row).
	--  경매장은 2026-10-13에 꺼냈다(사용자: "경매장도 아이콘써서 버튼으로 해주세요")
	local MAIN = {}
	for _, id in Layout.MENU.row do
		MAIN[id] = true
	end
	-- 관리자인가(서버가 내 상태에 admin 칸을 넣어 줬는가) — 「메뉴」 안에 「관리」가 보인다. 관리자가 아닌 사람이 창을 억지로 띄워도 서버는 명령을 듣지 않는다
	local function isAdmin(): boolean
		return state.me ~= nil and state.me.admin ~= nil
	end
	local morePanel: Frame? = nil
	local function closeMore()
		if morePanel then
			morePanel:Destroy()
			morePanel = nil
		end
	end
	state.closeMore = closeMore -- (장면 · 대화가 시작되면 닫는다 — closeMenus)
	local function toggleMore()
		if morePanel then
			closeMore()
			return
		end
		local items = {}
		for _, w in Windows.list() do
			if not MAIN[w.id] then
				table.insert(items, { id = w.id, name = w.name })
			end
		end
		-- 키 없이 「메뉴」 안에 두는 창(공방 basics.js의 via '메뉴에서' — 출석 · 업적 · 호감도 · 모험의 서). need = 'tome'이면 모험의 서를 받은 뒤(「항구의 첫날」 — 2026-10-16)
		for _, w in UI_DATA.windows do
			if w.menu and Windows.info(w.id) and (not w.need or (state.bond and state.bond.open)) then
				table.insert(items, { id = w.id, name = w.name })
			end
		end
		-- (키 설정 · 게임 설정은 위의 「메뉴에서」 창들에 든다 — 전에는 여기서 한 번 더 넣어 둘씩 보였다: 2026-10-18 검토)
		if isAdmin() then
			table.insert(items, { id = "admin", name = "관리" })
		end
		table.insert(items, { id = "@chars", name = "캐릭터 선택" }) -- 저장하고 캐릭터 고르기 화면으로 돌아간다
		local w, rowH = 132, 28
		local h = #items * rowH + 14
		local r = UI_HUD.menu
		local holder = Stage.place(Stage.ui, "More", r.at, r.x + r.w - w, r.y - h - 6, w, h)
		holder.ZIndex = 160
		local panel = Ui.panel(holder, 0, 0, w, h)
		for i, item in items do
			Ui.button(panel, item.name, 8, 8 + (i - 1) * rowH, w - 16, function()
				closeMore()
				if item.id == "@chars" then
					state.toSelect()
				else
					Windows.toggle(item.id)
				end
			end, { h = 24 }).frame.Name = "More_" .. item.id
		end
		morePanel = holder
	end
	local function onMenu(id: string)
		if id == "more" then
			toggleMore()
		else
			closeMore()
			state.openWin(id)
		end
	end
	-- 키가 적힌 자리(스킬 칸 · 메뉴 단추 · 물약 칸)를 지금의 키로 다시 적는다
	local function drawKeyHints()
		local list = {}
		for i = 1, Quick.N do
			list[i] = { what = state.slots[i] or false, key = keyName("slot:" .. i) }
		end
		Hud.setSlots(list)
		Touch.setSlots(state.touchSlots) -- 스마트폰의 칸 단추(놓인 것은 PC와 따로다)
		local menu, open = {}, {}
		for _, w in Windows.list() do
			open[w.id] = w
		end
		for _, id in Layout.MENU.row do
			local w = open[id]
			if w then
				table.insert(menu, { id = w.id, name = w.name, key = keyName("win:" .. w.id) })
			end
		end
		table.insert(menu, { id = "more", name = "메뉴", key = "" })
		closeMore()
		Hud.setMenu(menu, onMenu)
		if state.me then
			Hud.setSelf(state.me)
		end
	end
	-- 주민이 해 주는 일의 창을 연다(가방이 옆에 같이 뜬다). kind = merchant · store · forge(대장장이 — arg = 처음 탭 "craft" · "enhance")
	--  2026-10-15: 대장장이의 상점을 없앴다(사용자: "상점 없어야함 제작, 강화만 하는곳임") — 대장장이 창 하나에 제작 · 강화 탭
	local function openService(kind: string, arg: any)
		if kind == "forge" then
			Windows.close("shop")
			Windows.open("forge", arg)
		else
			Windows.open("shop", kind)
		end
		Windows.open("bag", nil, true) -- 가방 창이 아직 열리지 않은 레벨(Lv.1)이어도 같이 띄운다 — 창고 · 상점은 가방과 짝이다
	end
	-- 그 주민과 퀘스트의 말을 시작한다: 돌려줄 것이 있으면 그것부터, 없으면 받을 것 하나(한 번에 하나만 — 퀘스트는 한 줄이다). 시작했으면 true
	--  돌려주면 state.chain에 적어 둔다 — 서버가 끝냈다고 알려 오면 그 주민이 줄 다음 것으로 말이 이어진다(그리는 고리가 잇는다)
	state.questTalk = function(npc): boolean
		if Tutorial.isDream(state.sceneKey) then
			return false -- 꿈(튜토리얼)의 샛별은 퀘스트를 주지 않는다
		end
		local level = if state.me then state.me.level else 1
		local here = SCENES.scenes[state.sceneKey]
		local at = Quests.atNpc(state.quests or {}, level, npc.id, here.region, here.also)
		local function ready(id)
			local def = Quests.def(id)
			Talk.start(npc, def.done, def.name, function()
				state.chain = { npc = npc, scene = state.sceneKey, done = def.id, till = os.clock() + 3 }
				Net.FireServer("Quest", "complete", def.id)
			end, "완료")
		end
		local function offer(id)
			local def = Quests.def(id)
			Talk.start(npc, def.offer, def.name, function()
				Net.FireServer("Quest", "accept", def.id)
				Music.sfx("secret2") -- 퀘스트 수락
			end, "수락")
		end
		-- 할 일이 둘 넘으면(돌려줄 · 받을 · 하는 중인 퀘스트) 고르는 말(2026-10-18 — 메이플스토리의 NPC 대화처럼. 전에는 정해진 차례로 하나씩만 나왔다)
		local menu = Quests.talkMenu(at, Talk.LINES)
		if menu then
			local items = {}
			for _, m in menu do
				table.insert(items, { text = m.text, color = if m.kind == "ready" then Ui.COLOR.gold elseif m.kind == "offer" then Ui.COLOR.accent elseif m.kind == "wait" then Ui.COLOR.dim else Ui.COLOR.text })
			end
			Input.take("down") -- 앞서 눌러 둔 ↓(아래 발판 · 사다리 · 폰의 막대)가 남아 첫 장에 줄을 옮기지 않게(2026-10-18 검토)
			Talk.menu(npc, items, function(i)
				local m = menu[i]
				if m.kind == "ready" then
					ready(m.id)
				elseif m.kind == "offer" then
					offer(m.id)
				elseif m.kind == "wait" then
					local def = Quests.def(m.id)
					Talk.start(npc, def.wait, def.name)
				else
					Talk.start(npc, npc.lines)
				end
			end)
			return true
		end
		if #at.ready > 0 then
			ready(at.ready[1])
			return true
		elseif #at.offer > 0 then
			offer(at.offer[1])
			return true
		end
		return false
	end
	-- 탈것(2026-10-16): 떠나는 탈것의 사람(마을의 선장 · 부두의 선장과 뱃사공 · 꼭대기의 승강장 일꾼)에게 말을 걸면 「○○로 가는 배」 → 「탑승」 → 서버가 갑판으로 옮긴다
	--  2026-10-23 사용자: "갈건지 말건지 안물어보고 그냥 바로 배태워버리는데 이러면안된다 물어봐야해" → 마지막 장 = 묻는 말(r.ask) + 「탑승」 · 「거절」 단추(그 장은 단추로만 — Talk.start의 ask)
	state.sailTalk = function(npc): boolean
		local r = Voyage.route(state.sceneKey, npc.id)
		if not r then
			return false -- 갑판 위의 사람 · 탈것이 없는 사람은 그냥 말만 한다
		end
		local W = Voyage.DATA.words
		if not Voyage.open(state.quests or {}, r) then
			Talk.start(npc, { r.locked or "아직은 탈 수 없다." }, npc.role)
			return true
		end
		local said = table.clone(r.lines)
		if r.ask then
			table.insert(said, r.ask)
		end
		Talk.start(npc, said, npc.role, function()
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Sail", npc.id)
				if ok and res and not res.ok and res.why and state.fx and state.body then
					state.fx:float(res.why, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
				end
			end)
		end, W.board, { ask = true })
		return true
	end
	state.openNpc = function(npc): boolean
		-- 만나면 열림(2026-10-16 — 호감도 대신): 그 사람에게 처음 말을 걸면 인사(누구이고 무엇을 하는지)를 나누고, 끝나면 그 기능이 열려 바로 그 창이 뜬다
		if Bond.isMeet(npc.id) and state.bond and not (state.bond.met or {})[npc.id] then
			local m = Bond.DATA.meet[npc.id]
			Talk.start(npc, m.lines, npc.role, function()
				task.spawn(function()
					local ok, res = pcall(Net.Invoke, "Bond", "meet", npc.id)
					if ok and res and res.view then
						state.setBond(res.view, res.note)
						if res.ok and state.view and state.view:npcNear(state.body.x, state.body.y) == npc then
							state.openNpc(npc) -- 열린 그 창을 바로
						end
					end
				end)
			end, "인사")
			return true
		end
		local kind = Items.data.NPCDO[npc.id]
		local who = if npc.role and npc.name then npc.role .. " " .. npc.name else nil -- 창의 제목(대장장이 · 창고지기가 마을 · 도시에 따로 있다 — 2026-10-16)
		ForgeWindow.opener = who -- (창고는 계정의 것이라 제목이 늘 「창고」다)
		local level = state.me.level
		if kind == "daily" then
			-- 의뢰 게시판: 일일 의뢰 창(Lv.10부터 — 그 앞에는 「Lv.10부터 의뢰를 받을 수 있다」는 말만 뜬다)
			local dregion = Daily.regionAt(state.sceneKey, npc.id)
			local dboard = dregion and Daily.DATA.boards[dregion]
			if not dboard or level < math.max(Daily.FROM, dboard.from or 0) then
				return false -- 아직 열리지 않았다(은달 항구의 의뢰소는 Lv.30부터 — 그 앞에는 그냥 말을 건다)
			end
			if state.fetchDaily then
				state.fetchDaily() -- 날이 바뀌었으면 새 의뢰가 온다
			end
			Windows.open("daily", Daily.regionAt(state.sceneKey, npc.id), true) -- 그 게시판의 지역(초승달 마을 · 은달 항구 — 2026-10-16)
		elseif kind == "rift" then
			-- 토벌대장: 토벌 창(단계 · 남은 보상 — 들어가는 레벨은 단계마다 창이 가른다)
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Rift", "view")
				if ok and res then
					state.rift = res
					Windows.refresh(state.me)
				end
			end)
			Windows.open("rift", nil, true)
		elseif kind == "auction" then
			-- 경매사: 경매장 창(넓은 창 — 다른 창을 닫고 혼자 뜬다). 메뉴의 「경매장」(Y)으로 여는 것과 같은 창이다(메이플 옥션 방식 — 주민에게서 멀어져도 닫히지 않는다)
			Windows.open("auction", nil, true)
		elseif kind == "hall" then
			-- 명예의 전당의 비석: 그 비석의 순위판을 연다(hall_level → "level")
			Windows.open("hall", string.match(npc.id, "^hall_(%a+)$") or "level", true)
		elseif kind == "shop" then
			openService("merchant")
		elseif kind == "smith" then
			-- 대장장이: 강화가 열린 뒤(Lv.8)에는 강화 창부터, 그 전에는 상점부터(상점에서 「제작하러 가기」로 재료 제작을 한다 — 제작은 Lv.1부터)
			openService("forge", if level >= Items.data.OPEN.forge then "enhance" else "craft") -- 강화가 열리기 전(Lv.8)에는 제작 탭부터
		elseif kind == "store" and level >= Items.data.OPEN.store then
			openService("store")
		else
			return false
		end
		Talk.close()
		state.ui.npc, state.ui.scene = npc, state.sceneKey
		return true
	end
	Windows.init({
		me = function()
			return state.me
		end,
		bag = function()
			return state.bag
		end,
		party = function()
			return state.party
		end,
		myId = function() -- 내 번호(월드맵이 파티원 가운데 나를 뺀다 — 2026-10-18)
			return state.myId
		end,
		quests = function()
			return state.quests
		end,
		-- 길찾기를 켠 퀘스트 · 일일 의뢰의 모습(월드맵의 「가는 길」이 그 퀘스트를 따른다)
		navi = function()
			return state.navi
		end,
		daily = function()
			return state.daily
		end,
		-- 명예의 전당의 순위(서버에 묻는다)
		rank = function()
			return Net.Invoke("Rank")
		end,
		-- 관리자의 시험용 명령(서버가 계정 번호로 가린다 — 관리자가 아니면 nil이 온다)
		admin = function(what: string, a: any, b: any, c: any)
			local ok, got = pcall(Net.Invoke, "Admin", what, a, b, c)
			return if ok then got else nil
		end,
		-- 관리 창의 「보스 크기」: 보스의 그림만 그 크기(제가 드린 서 있는 그림의 몇 %)로 바꿔 그려 본다 — 싸움의 자리는 설계값(combat의 story.show) 그대로다. 값 없이 부르면 지금 크기(%)만 돌려준다
		bossShow = function(percent: number?): number?
			local base = 1
			for _, def in COMBAT.mobs do
				if def.story and def.story.show then
					base = def.story.show
					break
				end
			end
			-- 고운 그림(동작에 k가 적힌 것)이 하나도 없으면 바꿔 볼 것이 없다 → nil(관리 창이 그 줄을 그리지 않는다). 2026-10-12부터 보스의 동작은 도트 그림이라 지금은 없다
			local fine = false
			for _, char in CHARS.chars do
				for _, clip in char.clips do
					if clip.k then
						fine = true
					end
				end
			end
			if not fine then
				return nil
			end
			if percent then
				Sprite.preview = percent / 100 / base
			end
			return math.floor(Sprite.preview * base * 100 + 0.5)
		end,
		npcNames = function()
			return state.npcNames
		end,
		-- 내가 있는 장면(월드맵이 내 자리를 찍는다)
		scene = function()
			return state.sceneKey
		end,
		myId = function()
			return state.myId
		end,
		-- 같은 맵에 있는 다른 사람들(파티 창의 초대 목록)
		others = function()
			return if state.others then state.others:roster() else {}
		end,
		ui = state.ui,
		openService = openService,
		-- 강화 창에 장비를 올린다(가방 · 장비 창의 「올리기」)
		toForge = function(id: number)
			ForgeWindow.put(state.ui, id, state.bag)
			Windows.refresh(state.me)
		end,
		-- 열린 창이 바뀌었다: 가방 옆에 무엇이 열려 있는지 적어 두고 모두 다시 그린다
		changed = function()
			state.ui.service = if Windows.isOpen("forge") then "forge" elseif not Windows.isOpen("shop") then nil elseif Windows.argOf("shop") == "store" then "store" else "shop"
			if not Windows.isOpen("forge") then
				state.ui.forgeTarget, state.ui.forgeMat, state.ui.forgeResult = nil, nil, nil
			end
			local openSet = {}
			for _, w in Windows.all() do
				openSet[w.id] = Windows.isOpen(w.id)
			end
			Hud.setOpen(openSet)
			if openSet.auction then
				Hud.markMenu("auction", false) -- 경매장을 열었다: 「팔림」의 점을 끈다
				phoneMark()
			end
			GainLog.setCovered(Windows.sideOpen("right"))
			QuestHud.setCovered(Windows.sideOpen("right")) -- 오른쪽 창이 퀘스트 알리미의 자리를 덮는다 — 그동안은 알리미를 감춘다(글이 겹쳐 비친다)
			QuickEdit.setOpen(Windows.isOpen("skill") or Windows.isOpen("bag")) -- 스킬 · 소비 아이템을 골라 놓는 것은 그 창이 열려 있을 때(칸끼리 끄는 것은 늘 된다)
			Windows.refresh(state.me)
		end,
		-- 퀵슬롯에 스킬을 놓는 일(스킬 창이 스킬을 고르거나 끌 때 부른다 — ui/quickEdit.luau)
		quick = QuickEdit,
		send = function(name: string, ...)
			Net.FireServer(name, ...)
		end,
		-- 키 설정 창에 늘어놓는 "하는 일"
		actions = function()
			local out = {
				{ action = "left", name = "왼쪽으로" },
				{ action = "right", name = "오른쪽으로" },
				{ action = "up", name = "문 · 주민" },
				{ action = "down", name = "아래 발판" },
				{ action = "jump", name = "뛰기" },
				{ action = "pickup", name = "줍기" },
				{ action = "ride", name = "탈것 타기 · 내리기" },
			}
			for _, w in Windows.list() do
				table.insert(out, { action = "win:" .. w.id, name = w.name })
			end
			-- 스킬의 키는 여기서 바꾸지 않는다 — 스킬은 스킬 창에서 퀵슬롯에 놓고, 여기서는 칸의 키만 바꾼다
			for i = 1, Quick.N do
				table.insert(out, { action = "slot:" .. i, name = Format.fill(QUICK.words.slot, { n = i }) })
			end
			return out
		end,
		saveKeys = function()
			Net.FireServer("Keys", Input.export())
			drawKeyHints()
		end,
		resetKeys = function()
			Input.reset()
		end,
		-- 출석 · 업적(2026-10-15): 서버가 준 판 · 받기(서버가 정한다). 창을 열 때 지금의 것을 받아 온다
		attend = function()
			return state.attend
		end,
		attendFetch = function()
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Attend", "view")
				if ok and res and res.view then
					state.attend = res.view
					if state.me then
						Windows.refresh(state.me)
					end
				end
			end)
		end,
		attendDo = function(action: string)
			local ok, res = pcall(Net.Invoke, "Attend", action)
			if not ok or not res then
				return nil
			end
			state.attend = res.view
			return res
		end,
		ach = function()
			return state.ach
		end,
		achFetch = function()
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Achieve", "view")
				if ok and res and res.view then
					state.ach = res.view
					if state.me then
						Windows.refresh(state.me)
					end
				end
			end)
		end,
		-- 2편의 도시 생활(2026-10-16): 서버가 준 상태 · 받기 · 선물(서버가 정한다 — 선물은 그 사람 앞이어야 한다)
		bond = function()
			return state.bond
		end,
		bondFetch = function()
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Bond", "view")
				if ok and res and res.view then
					state.setBond(res.view)
				end
			end)
		end,
		bondDo = function(action: string, a: any, b: any)
			local ok, res = pcall(Net.Invoke, "Bond", action, a, b)
			if not ok or not res then
				return nil
			end
			if res.view then
				state.setBond(res.view, res.note)
			end
			return res
		end,
		nearNpc = function(id: string): boolean
			local body = state.body
			for _, n in SCENES.scenes[state.sceneKey].npcs or {} do
				if n.id == id and body and math.abs(n.x - body.x) <= 60 and math.abs(n.y - body.y) <= 40 then
					return true
				end
			end
			return false
		end,
		-- 수정 틈 토벌: 내 기록(남은 보상) · 들어가기(서버가 정한다 — 토벌대장 앞이어야 한다. 들어가면 서버가 옮긴다)
		rift = function()
			return state.rift
		end,
		-- 같은 맵에 파티원이 있는가(던전 창의 「파티 입장」 — 2026-10-21)
		partyHere = function(): boolean
			for _, m in (state.party and state.party.members) or {} do
				if m.id ~= state.myId and m.scene == state.sceneKey then
					return true
				end
			end
			return false
		end,
		-- 주간 보스(2026-10-24): 서버의 마지막 대답 { ok, why, view = { done, reset } } · 묻기 / 들어가기
		week = function()
			return state.week
		end,
		weekDo = function(action: string, id: any, mode: any, party: boolean?)
			local ok, res = pcall(Net.Invoke, "Week", action, id, mode, party == true)
			if not ok or not res then
				return nil
			end
			state.week = res
			if not res.ok and res.why and state.fx and state.body then
				state.fx:float(res.why, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
			end
			Windows.refresh(state.me)
			return res
		end,
		riftDo = function(action: string, id: any, party: boolean?)
			local ok, res = pcall(Net.Invoke, "Rift", action, id, party == true) -- party = 던전에 파티로 들어간다(2026-10-21)
			if not ok or not res then
				return nil
			end
			state.rift = res
			if not res.ok and res.why and state.fx and state.body then
				state.fx:float(res.why, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
			end
			Windows.refresh(state.me)
			return res
		end,
		achDo = function(action: string, id: string?)
			local ok, res = pcall(Net.Invoke, "Achieve", action, id)
			if not ok or not res then
				return nil
			end
			state.ach = res.view
			return res
		end,
		-- 달빛 상점(2026-10-20): 서버의 상점 상태(Cash.view — 상품마다 살 수 있나 · 산 수 · 보관함) · 구매(서버가 한도를 보고 로블록스의 구매 창을 띄운다) · 받기 · 이름 바꾸기
		cash = function()
			return state.cash
		end,
		cashFetch = function()
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Cash", "view")
				if ok and res and res.list then
					state.cash = res
					if state.me then
						Windows.refresh(state.me)
					end
				end
			end)
		end,
		cashDo = function(action: string, a: any)
			local ok, res = pcall(Net.Invoke, "Cash", action, a)
			if not ok or not res then
				return nil
			end
			if res.list then
				state.cash = res -- 받기는 새 상태를 같이 준다
			end
			return res
		end,
		openRename = function()
			Windows.open("cash", "rename", true) -- 가방에서 이름 바꾸기 주문서를 썼다 → 이름을 적는 칸
		end,
		-- 염색약(2026-10-22): 가방 · 퀵슬롯에서 쓰면 색을 고르는 창(part = point · robe) · 내 직업 · 지금 색(창의 미리보기)
		openDye = function(part: string)
			Windows.open("cash", "dye:" .. part, true)
		end,
		myClass = function()
			return state.who
		end,
		myLook = function()
			return state.me and state.me.look
		end,
		-- 일일 의뢰: 서버가 준 상태 · 받기와 내기(서버가 정한다 — 게시판 앞이어야 한다)
		daily = function()
			return state.daily
		end,
		dailyDo = function(action: string, region: string, i: number)
			local ok, res = pcall(Net.Invoke, "Daily", action, region, i)
			if not ok or not res then
				return
			end
			state.daily = res.view
			if res.reward then
				Music.sfx("success")
				if state.fx then
					state.fx:float(Format.fill(Daily.WORDS.got, { name = res.reward.name }), state.body.x, state.body.y - 84, Effects.GOLD, 2.2)
					if res.reward.dust > 0 then
						state.fx:float(Format.fill(Daily.WORDS.bonus, { n = res.reward.dust }), state.body.x, state.body.y - 98, Effects.MINT, 2.6)
					end
				end
			elseif not res.ok and res.why and state.fx then
				state.fx:float(res.why, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
			end
			if state.drawQuests then
				state.drawQuests()
			end
		end,
		-- 경매장: 서버에 부탁하고 답을 기다린다(창이 그 답으로 다시 그린다 — ui/auctionWindow.luau). 답이 없으면 nil
		market = function(action: string, a: any, b: any, c: any, d: any)
			local ok, res = pcall(Net.Invoke, "Market", action, a, b, c, d)
			if ok and typeof(res) == "table" then
				return res
			end
			return nil
		end,
		-- 소리 설정을 바꿨다: 계정에 저장한다
		saveSound = function()
			Net.FireServer("Sound", ViewOpts.into(Music.export())) -- 소리 · 화면 설정을 한 표로
		end,
	})
	-- 지금 쓰는 배치: 스마트폰 단추가 켜져 있으면 단추 배치(touchSlots), 아니면 PC의 퀵슬롯(slots). 스킬 창 · 가방에서 놓는 것도 지금 쓰는 쪽에 놓인다
	local quickHooks = {
		slots = function()
			return if Touch.on then state.touchSlots else state.slots
		end,
		-- 칸들을 바꿨다: 화면은 바로 고치고 서버에 알린다. 서버가 가진 칸들이 돌아오면 그것으로 맞춘다(받아들이지 않았으면 되돌아간다)
		apply = function(next)
			local touch = Touch.on
			local function put(value)
				if touch then
					state.touchSlots = value
				else
					state.slots = value
				end
			end
			put(next)
			state.slotSeq = (state.slotSeq or 0) + 1
			local seq = state.slotSeq
			drawKeyHints()
			task.spawn(function()
				local ok, result = pcall(Net.Invoke, if touch then "TouchSlots" else "Slots", next)
				if ok and typeof(result) == "table" and seq == state.slotSeq then
					put(result)
					drawKeyHints()
					Windows.refresh(state.me)
				end
			end)
		end,
		-- 그 스킬을 퀵슬롯에 놓을 수 있는가: ok · passive(늘 켜져 있는 것) · unlearned(아직 안 배웠다) · later(게임에 아직 없다). kind = 스킬의 갈래
		state = function(id: string, kind: string?): string
			local def = COMBAT.skills[id]
			if def and def.who == state.who then
				return if state.me and (state.me.skills[id] or 0) > 0 then "ok" else "unlearned"
			end
			-- 버프 · 설치 · 소환: 배웠으면 칸에 놓는다(누르면 걸린다 · 놓인다)
			if Buffs.is(id) then
				return if state.me and Buffs.learned(kitHero(), id) then "ok" else "unlearned"
			end
			local placedDef = COMBAT.placed[id]
			if placedDef and placedDef.who == state.who then
				return if state.me and (state.me.skills[id] or 0) > 0 then "ok" else "unlearned"
			end
			-- 2~4차의 쓰는 스킬
			local castDef = COMBAT.cast[id]
			if castDef and castDef.who == state.who then
				return if state.me and (state.me.skills[id] or 0) > 0 then "ok" else "unlearned"
			end
			-- 1차의 온오프 사출기: 배웠으면 칸에 놓는다(누르면 켜고 끈다). 핵심 장치 · 패시브는 늘 켜져 있다
			local kitSkill = KitSim.skill(id)
			if kitSkill and kitSkill.who == state.who and kitSkill.role == "toggle" then
				return if state.me and (state.me.skills[id] or 0) > 0 then "ok" else "unlearned"
			end
			return if kind == "passive" or kind == "core" then "passive" else "later"
		end,
		changed = function()
			if state.me then
				Windows.refresh(state.me)
			end
		end,
	}
	QuickEdit.init(quickHooks)
	Windows.register("stat", StatWindow)
	Windows.register("skill", SkillWindow)
	Windows.register("keys", KeysWindow)
	Windows.register("sound", SoundWindow)
	Windows.register("daily", DailyWindow) -- 일일 의뢰(마을의 의뢰 게시판 앞에서 ↑)
	Windows.register("attend", AttendWindow) -- 출석(메뉴 → 「출석」 · 그날 처음 들어오면 한 번)
	Windows.register("achieve", AchieveWindow) -- 업적(메뉴 → 「업적」)
	Windows.register("coupon", CouponWindow) -- 쿠폰(메뉴 → 「쿠폰」 — 2026-10-21)
	Windows.register("cash", CashWindow) -- 달빛 상점의 판(창으로는 이름 바꾸기 칸 · 염색만 — 가방에서 주문서 · 염색약을 쓰면. 상점은 들어가는 공간: cashShop.luau)
	CashWindow.ctx = Windows.context() -- (염색 창의 제목이 내 직업을 본다 — 살라맨더는 「머리 색」)
	-- 가방의 캐시 탭(2026-10-21): 펫 꺼내기 · 넣기 · 탈것 타기 · 내리기 · 지금 꺼낸 것 · 상품의 이름(창 ctx에 더한다)
	do
		local wctx = Windows.context()
		wctx.togglePet = state.togglePet
		wctx.toggleRide = state.toggleRide
		wctx.toggleWskin = state.toggleWskin -- 캐시 무기(2026-10-23)
		wctx.mySkin = function()
			return state.mySkin
		end
		wctx.myPet = function()
			return state.myPet
		end
		wctx.myRide = function()
			return state.myRide
		end
		wctx.cashProduct = CashWindow.product
		-- 쿠폰(2026-10-21): 서버에 번호를 보낸다 → (보냈는가, { ok, why?, pet? }) · 받으면 가진 펫 · 탈것을 다시 읽는다
		wctx.coupon = function(text: string)
			return pcall(Net.Invoke, "Coupon", text)
		end
		wctx.couponGot = function()
			state.cash = nil
			if state.cashFetchNow then
				state.cashFetchNow()
			end
			Windows.refresh(state.me)
		end
	end
	-- 달빛 상점의 공간(2026-10-21 사용자 "메이플스토리 캐시샵처럼 아예 무적공간으로 들어가버리는 형태 … 캐시샵은 마을에서만"): 창 ctx에 더한 것
	local function notice(text: string?)
		if text and state.fx then
			state.fx:float(text, state.body.x, state.body.y - 46, Effects.MINT, 1.6)
		end
	end
	local touchWas = true
	state.shopCtx = setmetatable({
		who = function()
			return state.who
		end,
		myPet = function()
			return state.myPet
		end,
		myRide = function()
			return state.myRide
		end,
		invoke = function(action: string)
			local ok, res = pcall(Net.Invoke, "Cash", action)
			return if ok then res else nil
		end,
		notice = notice,
		townOk = function()
			return Town.is(state.sceneKey) and not state.dead and not state.busy and not CineView.active()
		end,
		setCash = function(res)
			state.cash = res
		end,
		onOpen = function()
			-- 들어간다: 열린 창 · 메뉴를 닫고 · 움직이지 않게 · 게임 화면과 HUD를 숨긴다(공간이 화면을 다 덮는다 — 그 뒤의 것을 그리지 않게)
			if state.closeMore then
				state.closeMore()
			end
			for _, w in Windows.all() do
				if Windows.isOpen(w.id) then
					Windows.close(w.id)
				end
			end
			state.busy = true
			Hud.root.Visible = false
			local touch = Stage.ui:FindFirstChild("Touch")
			if touch then
				touchWas = touch.Visible
				touch.Visible = false
			end
			Stage.view.Visible = false
		end,
		onClose = function()
			Hud.root.Visible = true
			local touch = Stage.ui:FindFirstChild("Touch")
			if touch then
				touch.Visible = touchWas
			end
			Stage.view.Visible = true
			state.busy = false
		end,
		afterLeave = function()
			-- 서버가 들어간 자리로 다시 보낸다(Revive → goScene). 끝내 오지 않으면 3초 뒤에 막을 걷는다
			task.delay(3, function()
				if Curtain.covered() and not sceneRunning then
					Curtain.lift()
				end
			end)
		end,
	}, { __index = Windows.context() })
	-- 창 · 공간을 연다(단추 줄 · 메뉴 · 키): 달빛 상점 = 들어가는 공간 · 경매장 = 마을에서만(2026-10-21 사용자 "경매장도 마을에서만 갈수있어야하구요")
	state.openWin = function(id: string)
		if id == "cash" then
			CashShop.enter(state.shopCtx)
		elseif id == "auction" and not Windows.isOpen("auction") and not Town.is(state.sceneKey) then
			notice(Market.WHY.town)
		else
			Windows.toggle(id)
		end
	end
	Windows.register("tome", TomeWindow) -- 모험의 서(메뉴 → 「모험의 서」 — 2026-10-16)
	Windows.register("rift", RiftWindow) -- 수정 틈 토벌(토벌대장 앞에서 ↑ — 2026-10-16)
	Windows.register("dungeon", require(script.Parent.ui.dungeonWindow)) -- 던전(그 문 앞에서 ↑ — 2026-10-21 · 수정 거울숲)
	Windows.register("weekly", require(script.Parent.ui.weeklyWindow)) -- 주간 보스(그 보스의 문 앞에서 ↑ — 2026-10-24)
	Windows.register("auction", AuctionWindow) -- 경매장(메뉴 · Y — 메이플 옥션 방식. 은달 항구의 경매사 앞에서 ↑로도)
	Windows.register("bag", BagWindow)
	Windows.register("equip", EquipWindow)
	Windows.register("shop", ShopWindow)
	Windows.register("forge", ForgeWindow)
	Windows.register("party", PartyWindow)
	Windows.register("quest", QuestWindow)
	Windows.register("hall", HallWindow)
	Windows.register("admin", AdminWindow) -- 관리(메뉴 → 관리 — 관리자에게만 보인다)
	Windows.register("map", MapWindow) -- 월드맵(M): 그 지역의 맵들 · 내가 있는 곳 · 퀘스트를 받고 돌려줄 곳 · 내 레벨에 맞는 사냥터
	for _, w in Windows.all() do
		Input.bind("win:" .. w.id, Enum.KeyCode[w.key])
	end
	Windows.setLevel(first.self.level)
	-- 여기까지가 기본 키다. 저장해 둔 것이 있으면 그 위에 입힌다(사용자 결정: 기본 키를 주되 자유롭게 바꾼다)
	Input.markDefaults()
	Input.import(first.self.keys)
	state.drawKeyHints = drawKeyHints -- 튜토리얼(꿈)에서 가방 단추를 넣고 뺄 때 다시 그린다
	drawKeyHints()

	Talk.init()
	CineView.init(Overlay.root) -- 퀘스트 연출(장면): 세계를 덮는 것(대화창 아래) · 글 · 단추(대화창 위)
	CineView.onEnd = function(def)
		Input.flush() -- 장면 동안 누른 것은 버린다(넘기기 · 건너뛰기로 누른 ↑ · 스페이스가 남지 않게)
		state.cineSeen[def.id] = true
		Net.FireServer("Cine", "seen", def.id)
		Net.FireServer("Cine", "off", nil)
		Hud.root.Visible = Talk.npc == nil
		if Touch.root then
			Touch.root.Visible = Talk.npc == nil and Touch.on
		end
	end
	-- 여러 사람이 말하는 대화의 이름표(「@id 」): hero = 내 캐릭터의 이름 · 주민 = 그 주민의 이름
	Talk.nameOf = function(id: string)
		if id == "hero" then
			return state.myName
		end
		local a = CineView.npcArt(id)
		return a and a.name
	end
	TutView.init(Stage.ui)
	Talk.onFinish = function(npc)
		if Tutorial.isDream(state.sceneKey) then
			TutView.talked = npc.id -- 튜토리얼: 그 주민과 말을 끝냈다
		end
	end
	TutView.onSkip = function()
		goScene(function()
			local ok, res = pcall(Net.Invoke, "Tut", "skip", nil)
			return if ok then res else nil
		end)
	end
	PartyHud.init(Hud.root, function(name: string, ...)
		Net.FireServer(name, ...)
	end)
	-- 채팅은 Roblox의 기본 채팅이다(chat.luau — 창 · 입력줄 · 채널 탭을 켜고 색과 이름만 맞춘다). 글을 치는 동안에는 게임의 키를 받지 않고, PC에서는 파티원 칸을 채팅 창의 아래로 내린다
	Chat.init()
	-- 글을 치는 중 = 채팅의 입력줄 · 수량 창이 떠 있는 동안(2026-10-21 — 수량 칸 밖을 눌러도 Q · W …가 스킬로 나가지 않게)
	local CountBoxMod = require(script.Parent.ui.countBox)
	Input.typing = function(): boolean
		return Chat.focused() or CountBoxMod.shown()
	end
	-- 한글 입력 상태로 보이는 글쇠가 이어지면(input.luau의 Input.poll — 2026-10-21 사용자 "로블록스에서 한글쓴다음에 키가 안먹히는 버그"): 화면 위 큰 알림으로 한/영 키를 알린다(1분에 한 번)
	Input.onIme = function()
		pcall(Guide.banner, Input.IME_WORDS.head, Input.IME_WORDS.line, 6)
	end
	local function placeParty()
		PartyHud.setTop(if Touch.on then 0 else Chat.bottom)
	end
	Chat.onMoved = placeParty
	state.placeParty = placeParty
	QuestHud.init(Hud.root)
	BossView.init(Hud.root)
	RiftView.init(Hud.root)
	VoyageView.init(Hud.root)
	VistaView.init(Hud.root)
	Guide.init(Hud.root)
	MapName.init(Hud.root)
	GainLog.init(Hud.root)
	-- 전직해서 칸이 바뀌었다(서버가 윗차수의 사냥기 · 보스기를 앞 차수의 자리에 넣었다)
	state.onJob = function(me)
		state.slots = me.slots or state.slots
		state.touchSlots = me.tslots or state.touchSlots
		drawKeyHints()
	end
	-- 조작 안내에 적는 것: 그 갈래의 것이 놓인 칸의 키와 이름("mob" 사냥기 · "boss" 보스기 · "move" 이동기 · "potion" 물약). 칸에 없으면 nil
	local function slotOf(kind: string): (string?, string?)
		for i = 1, Quick.N do
			local what = state.slots[i]
			if what then
				if kind == "potion" then
					if Quick.item(what) then
						return keyName("slot:" .. i), "물약"
					end
				else
					local def = COMBAT.skills[what]
					if def and def.type == kind then
						return keyName("slot:" .. i), def.name
					end
				end
			end
		end
		return nil, nil
	end
	state.slotOf, state.keyName = slotOf, keyName -- 튜토리얼의 미션 판이 쓴다
	-- 튜토리얼(꿈)에서 반짝일 단추를 이름으로 찾는다(2026-10-14): pc:skill · pc:potion = 아래의 칸 · menu:<창> = 아래의 그림 단추 · inside:stat|skill = 창 안의 자동 단추 ·
	--  touch:pad|jump|interact|menu = 스마트폰 단추 · touch:skill|potion = 그것이 놓인 스마트폰 칸 · touchmenu:<창> = 열린 스마트폰 메뉴의 그 줄
	local function slotWith(list, want: string): number?
		for i = 1, Quick.N do
			local what = list[i]
			if what then
				if want == "potion" and Quick.item(what) then
					return i
				elseif want ~= "potion" and COMBAT.skills[what] and COMBAT.skills[what].type == "mob" then
					return i
				end
			end
		end
		return nil
	end
	state.tutFind = function(name: string): GuiObject?
		local kind, arg = string.match(name, "^([%w]+):(.+)$")
		if kind == "pc" then
			local i = slotWith(state.slots, arg)
			return if i and Hud.slots[i] then Hud.slots[i].frame else nil
		elseif kind == "menu" then
			local m = Hud.menu and Hud.menu[arg]
			return if m then m.frame else nil
		elseif kind == "inside" then
			return if arg == "stat" then StatWindow.autoFrame elseif arg == "skill" then SkillWindow.autoFrame else nil
		elseif kind == "touch" then
			if arg == "skill" or arg == "potion" then
				local i = slotWith(state.touchSlots or {}, arg)
				return if i then Touch.frameOf("slot", i) else nil
			end
			return Touch.frameOf(arg)
		elseif kind == "touchmenu" then
			return state.touchMenuItems and state.touchMenuItems[arg] or nil
		end
		return nil
	end
	state.guide = function()
		local me = state.me
		if not me or state.dead or not state.view or not state.body or Tutorial.isDream(state.sceneKey) then
			return nil -- 꿈(튜토리얼)에서는 미션 판이 가르친다
		end
		local npc = state.view:npcNear(state.body.x, state.body.y)
		return Guide.pick({
			level = me.level,
			quests = state.quests,
			scene = state.sceneKey,
			touch = Touch.on,
			nearNpc = if npc then npc.id else nil,
			drop = state.fx ~= nil and state.fx:dropNear(state.body.x, state.body.y, RULES.pickup) ~= nil,
			hpShare = me.hp / math.max(1, me.maxHp),
			potions = me.potions or 0,
			ap = me.ap or 0,
			sp = me.sp or 0,
			key = keyName,
			slotOf = slotOf,
		})
	end
	-- 대화창이 떠 있는 동안: 그 주민의 머리 위 표시 · 아래쪽 화면(체력 · 스킬 칸 · 단추) · 스마트폰의 터치 단추를 숨긴다(대화창은 판 · 단추를 눌러 넘긴다 — 2026-10-14)
	Talk.onToggle = function(npc)
		if state.view then
			state.view:setTalking(if npc then npc.id else nil)
		end
		if npc then
			closeMenus()
		end
		Hud.root.Visible = npc == nil and not CineView.active() -- 장면이 도는 동안은 말이 끝나도 숨긴 채
		if Touch.root then
			Touch.root.Visible = npc == nil and Touch.on and not CineView.active()
		end
	end
	-- 퀘스트가 바뀌면: 주민 머리 위의 표시 · 알리미 · 열려 있는 창
	state.fetchDaily = function()
		task.spawn(function()
			local ok, res = pcall(Net.Invoke, "Daily", "view")
			if ok and res and res.view then
				state.daily = res.view
				if state.drawQuests then
					state.drawQuests()
				end
			end
		end)
	end
	Net.OnClient("DailyView", function(view)
		state.daily = view
		if state.drawQuests then
			state.drawQuests()
		end
	end)
	state.fetchDaily() -- 들어온 캐릭터의 일일 의뢰(알리미 · 게시판 위의 표시)
	-- 출석(2026-10-15): 그날 처음 들어왔으면(서버가 fresh로 알린다) 출석 창을 한 번 띄운다 — 꿈(튜토리얼) · 장면 연출 중에는 띄우지 않는다
	state.fetchAttend = function()
		task.spawn(function()
			local ok, res = pcall(Net.Invoke, "Attend", "view")
			if not ok or not res or not res.view then
				return
			end
			state.attend = res.view
			if res.fresh and not Tutorial.isDream(state.sceneKey) and not CineView.active() and not Windows.isOpen("attend") then
				Windows.open("attend")
			elseif state.me then
				Windows.refresh(state.me)
			end
		end)
	end
	state.fetchAttend()
	Net.OnClient("AttendNew", function()
		if state.fetchDaily then
			state.fetchDaily() -- 자정이 지났다: 일일 의뢰도 새로(2026-10-18 검토: 접속한 채 자정을 넘기면 어제의 의뢰가 남고 잡아도 세지 않았다)
		end
		state.fetchAttend() -- 게임 중에 자정이 지나 칸이 찼다
	end)
	-- 업적 달성: 화면 위 가운데의 띠(길잡이의 큰 알림 — 노란 제목 「업적 달성 · 이름」 + 할 일 한 줄) · 소리는 없다(퀘스트 완료와 같다). 열린 업적 창은 다시 받아 온다
	-- 2편의 도시 생활(2026-10-16): 서버가 준 상태를 얹는다 — 「우호」부터 열리는 퀘스트 · 달조각 · 숨은 이야기의 표시 · 창 · 메뉴의 점. note = 무슨 일이 있었나(알림 글)
	state.setBond = function(view, note)
		if typeof(view) ~= "table" then
			return
		end
		local wasOpen = state.bond and state.bond.open
		state.bond = view
		if state.drawQuests then
			state.drawQuests() -- 자리 · 달조각을 다시
		end
		local mark = Bond.ready(view) or (state.me ~= nil and ((state.me.attReady or 0) + (state.me.achReady or 0) > 0))
		Hud.markMenu("more", mark)
		state.moreMark = mark
		phoneMark()
		local body = state.body
		if note and state.fx and body then
			if note.kind == "shard" then
				local have, total = 0, 0
				for _, a in view.tome do
					have += a.parts.shard[1]
					total += a.parts.shard[2]
				end
				Music.sfx("secret3")
				state.fx:float(Format.fill(Bond.DATA.tome.words.found, { a = have, b = total }), body.x, body.y - 60, Effects.MINT, 1.8)
			elseif note.kind == "meet" and note.first then
				Music.sfx("secret2")
				Guide.banner(note.opens, "인사를 나눴다 — 이제 맡길 수 있다", 2.5) -- 만나면 열림(2026-10-16)
			elseif note.kind == "open" then
				Guide.banner(Bond.DATA.tome.words.title, "메뉴 → 「모험의 서」", 2.5)
			end
		end
		if state.me then
			Windows.refresh(state.me)
		end
	end
	-- 매크로 확인(2026-10-23 — ui/macroWindow.luau · 서버 modules/macroGuard.luau): 문제가 왔다 · 보상 멈춤 · 결과
	do
		local MacroWindow = require(script.Parent.ui.macroWindow)
		MacroWindow.say = function(text: string, good: boolean)
			if state.fx and state.body then
				state.fx:float(text, state.body.x, state.body.y - 46, if good then Effects.MINT else Effects.PINK, 1.8)
			end
		end
		Net.OnClient("MacroView", function(v)
			MacroWindow.update(v)
		end)
		-- 새 문제가 떴다: 열려 있는 창 · 달빛 상점 · 대화를 모두 닫는다(2026-10-24 사용자 "매크로 뭐 다른 ui 열면 안열린다고")
		MacroWindow.onOpen = function()
			while Windows.closeTop() do
			end
			if CashShop.isOpen() then
				CashShop.leave(state.shopCtx)
			end
			Talk.close()
		end
		-- 게임 창이 앞에 있는가를 서버에 알린다(창이 앞에 없는데 스킬이 들어오면 매크로로 본다 — 서버 modules/macroGuard.luau · 2026-10-24)
		local UIS = game:GetService("UserInputService")
		local function focus(on: boolean)
			task.spawn(pcall, Net.Invoke, "Macro", "focus", on)
		end
		UIS.WindowFocused:Connect(function()
			focus(true)
		end)
		UIS.WindowFocusReleased:Connect(function()
			focus(false)
		end)
	end
	-- 배(2026-10-16 — sim/voyage.luau): 갑판에 올랐다 · 닿았다
	Net.OnClient("Voyage", function(v)
		if typeof(v) ~= "table" then
			return
		end
		if v.arrived then
			VoyageView.stop()
			Guide.banner(Format.fill(Voyage.DATA.words.arrive, { dest = v.dest or "" }), "", 2.2)
		elseif v.left then
			VoyageView.start(v.left, v.dest or "")
		end
	end)
	-- 수정 틈 토벌(2026-10-16): 방의 상태가 바뀌었다 · 완료의 보상
	Net.OnClient("RiftView", function(view)
		RiftView.set(view)
		if view and view.state == "clear" then
			Music.sfx("success")
		end
	end)
	-- 주간 보스(2026-10-24): 방의 상태(싸움 · 격파 · 시간 끝) · 격파했다(보상은 아직 없다 — 사용자: 보상설계는 나중에)
	Net.OnClient("WeekView", function(view)
		BossView.setWeekly(view)
		if view and view.state == "clear" then
			Music.sfx("success")
			local b = require(lune.sim.weekly).boss(view.boss)
			local WW = require(lune.sim.weekly).DATA.words
			Guide.banner(Format.fill(WW.clear, { name = if b then b.name else "" }), Format.fill(WW.back, { s = math.ceil(view.back or 0) }), 3)
		elseif view and view.state == "fail" then
			local WW = require(lune.sim.weekly).DATA.words
			Guide.banner(WW.fail, Format.fill(WW.back, { s = math.ceil(view.back or 0) }), 3)
		end
	end)
	Net.OnClient("WeekPay", function(p)
		if p and p.view then
			state.week = { ok = true, view = p.view }
		end
	end)
	Net.OnClient("RiftPay", function(p)
		RiftView.pay(p)
		if state.rift and p then
			state.rift.left = p.left or state.rift.left
		end
	end)
	Net.OnClient("BondView", function(view, note)
		state.setBond(view, note)
	end)
	-- 로벅스로 산 것이 보관함에 들어왔다(서버의 ProcessReceipt가 저장까지 마친 뒤 — 2026-10-20): 가운데 위 알림 · 상점 창을 고쳐 그린다
	Net.OnClient("CashGot", function(key)
		local p = CashWindow.product(key) -- 상점에서 팔지 않는 펫 · 탈것(쿠폰 · 만렙 축하 선물)도 이름이 있다(2026-10-25 — 전에는 상품 목록에서만 찾아 알림이 뜨지 않았다)
		if p and p.free == "max" then
			local W = CashWindow.WORDS
			Guide.banner(W.giftMax or CashWindow.TITLE, Format.fill(W.gotOwn, { name = p.name }), 4) -- 만렙 축하 선물(백금 사슴)
		elseif p and not p.free then -- (쿠폰 펫 · 탈것은 쿠폰 창이 알린다 — 예전처럼 띠를 띄우지 않는다)
			local W = CashWindow.WORDS
			Guide.banner(CashWindow.TITLE, if key == "charx" then W.gotSlot elseif key == "pass" then W.gotPass elseif string.sub(key, 1, 4) == "pet_" or string.sub(key, 1, 6) == "mount_" then Format.fill(W.gotOwn, { name = p.name }) else Format.fill(W.got, { name = p.name }), 3)
		end
		task.spawn(function()
			local ok, res = pcall(Net.Invoke, "Cash", "view")
			if ok and res and res.list then
				state.cash = res
				CashShop.refresh(state.me) -- 달빛 상점 안이면 그 판도
				if state.me and Windows.isOpen("cash") then
					Windows.refresh(state.me)
				end
			end
		end)
	end)
	Net.OnClient("AchDone", function(ids)
		if typeof(ids) ~= "table" then
			return
		end
		for _, id in ids do
			local def = AchieveSim.BY[id]
			if def then
				Guide.banner(("%s · %s"):format(AchieveSim.WORDS.banner, def.name), def.text, 2.5)
			end
		end
		if Windows.isOpen("achieve") then
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Achieve", "view")
				if ok and res and res.view then
					state.ach = res.view
					if state.me then
						Windows.refresh(state.me)
					end
				end
			end)
		end
	end)
	-- 길찾기(알리미의 화살표 단추): 누른 퀘스트를 켜고(같은 것을 다시 누르면 끈다) 알리미를 다시 그린다. 화살표는 그리는 고리가 장마다 놓는다
	state.naviArrow = NaviArrow.new()
	QuestHud.onNavi = function(key: string)
		state.navi = if state.navi == key then nil else key
		if state.drawQuests then
			state.drawQuests()
		end
	end
	state.drawQuests = function()
		local level = if state.me then state.me.level else 1
		if state.view then
			state.view:setMarks(function(npcId: string)
				if Tutorial.isDream(state.sceneKey) then
					return nil -- 꿈(튜토리얼)에는 퀘스트 표시가 없다
				end
				-- 의뢰 게시판: 낼 의뢰가 있으면 「?」 · 안 받은 의뢰가 있으면 「!」
				for region, board in Daily.DATA.boards do
					if board.npc == npcId and board.scene == state.sceneKey then
						local mk = if level >= math.max(Daily.FROM, board.from or 0) and state.daily then Daily.mark(state.daily.boards[region]) else nil
						return if mk and board.green then "D" .. mk else mk -- 기도 탑은 초록 「!」 · 「?」(2026-10-25)
					end
				end
				local here = SCENES.scenes[state.sceneKey]
				return Quests.markFull(state.quests, level, npcId, here.region, here.also) -- 메인은 금빛 초승달의 「!」 · 「?」(2026-10-24)
			end)
			-- 그 퀘스트를 받아야 열리는 문(달의 사당 안의 「사당 지하」 — 메인 「불타는 마을」): 받기 전에는 보이지 않는다
			state.view:setPortals(function(p)
				return Quests.portalOpen(state.quests, p)
			end)
		end
		-- 길찾기: 켜 둔 퀘스트에 더 안내할 것이 없으면(끝냈다 · 의뢰가 바뀌었다) 끈다
		if state.navi and not Navi.target(state.navi, state.quests, level, state.daily) then
			state.navi = nil
		end
		QuestHud.navi = state.navi
		QuestHud.set(state.quests, state.npcNames, level, Daily.tracked(state.daily))
		drawSpots() -- 맵에 놓인 것 앞에서 ↑를 누르는 퀘스트의 자리
		drawShards() -- 달조각(2026-10-16)
		Windows.refresh(state.me)
	end

	-- 스마트폰 단추(터치 화면이면 저절로 켜진다)
	local touchMenu: Frame? = nil
	state.closeTouchMenu = function() -- (장면 · 대화가 시작되면 닫는다 — closeMenus)
		if touchMenu then
			touchMenu:Destroy()
			touchMenu = nil
		end
	end
	Touch.init({
		-- 칸 단추에 놓을 수 있는 것: 물약과 배운(쓸 수 있는) 스킬 — 놓을 것의 목록에 뜬다
		choices = function()
			-- 소비 아이템: 가방에 있는 것과 이미 단추에 놓아 둔 것(다 써서 0개여도 놓아 둔 것은 남는다)
			local list = {}
			-- 점프 · 상호작용(2026-10-21 사용자: "상호작용, 점프키 같은거 위치 다 바꿀수있어야해요 드래그앤 드랍으로 다른 버튼들처럼"): 고르면 고른 단추와 자리를 바꾼다
			for _, id in { "act_jump", "act_interact" } do
				if Quick.ACTS[id] then
					table.insert(list, { what = id, name = Quick.ACTS[id].name })
				end
			end
			for _, g in Items.data.GOODS do
				if g.tab == "use" and (Bag.countIn(state.bag, g.id) > 0 or Quick.find(state.touchSlots, g.id)) then
					table.insert(list, { what = g.id, name = g.short })
				end
			end
			for _, sk in mySkills do
				if quickHooks.state(sk.id) == "ok" then
					table.insert(list, { what = sk.id, name = sk.name })
				end
			end
			-- 배운 버프 · 설치 · 소환(쓰는 동작이 있는 것은 위의 기술 목록에 있다)
			for _, t in CLASSES.classes[state.who].tiers do
				for _, sk in t.skills do
					local placedDef = COMBAT.placed[sk.id]
					if not COMBAT.skills[sk.id] and ((Buffs.is(sk.id) and Buffs.learned(kitHero(), sk.id)) or ((placedDef ~= nil or COMBAT.cast[sk.id] ~= nil) and (state.me.skills[sk.id] or 0) > 0)) then
						table.insert(list, { what = sk.id, name = sk.name })
					end
				end
			end
			-- 가진 펫 · 탈것(2026-10-21 점검 — PC는 가방의 캐시 탭에서 퀵슬롯으로 끌어 놓는다 · 폰은 여기서 단추에 놓는다. 누르면 꺼내기 · 넣기 / 타기 · 내리기)
			local cash = state.cash
			if not cash and state.cashFetchNow then
				state.cashFetchNow() -- 아직 모르면 묻는다(받으면 목록이 다시 그려진다)
			end
			for _, kind in { "pets", "mounts" } do
				for _, id in (cash and cash[kind]) or {} do
					local prod = CashWindow.product(id)
					table.insert(list, { what = id, name = if prod then prod.name else id })
				end
			end
			for _, id in state.touchSlots do
				if id and Quick.ride(id) and not (cash and (table.find(cash.pets or {}, id) or table.find(cash.mounts or {}, id))) then
					local prod = CashWindow.product(id)
					table.insert(list, { what = id, name = if prod then prod.name else id }) -- 놓아 둔 것은 목록에 남긴다
				end
			end
			-- 배운 온오프 사출기
			local toggle = KitSim.data[state.who].toggle.id
			if KitSim.isToggle(kitHero(), toggle) then
				for _, sk in CLASSES.classes[state.who].skills do
					if sk.id == toggle then
						table.insert(list, { what = toggle, name = sk.name })
					end
				end
			end
			return list
		end,
		apply = quickHooks.apply,
		-- 누르고 있으면 이어서 쓰는 스킬: 공격 스킬(사냥기 · 보스기)
		--  힘을 모을 수 있는 기술(힘 모으기를 배운 액시온의 강타 기술)은 이어 쓰지 않는다 — 누르고 있으면 모인다
			repeats = function(id: string): boolean
			-- 2~4차의 사냥기 · 보스기도 이어 쓴다 — 누르고 있는 것(몰아치기 · 난도질 · 난타) · 모으는 것(초승달 가르기) · 이어 누르는 것은 빼고
			local castDef = COMBAT.cast[id]
			if castDef then
				if castDef.type ~= "mob" and castDef.type ~= "boss" then
					return false
				end
				for _, s in Kitset.skill(id).segs or {} do
					if s.hold or s.charge or s.needPress then
						return false
					end
				end
				return true
			end
			local def = COMBAT.skills[id]
			return def ~= nil and (def.type == "mob" or def.type == "boss") and KitSim.chargeTime(kitHero(), id) == 0
		end,
		-- 상황 단추: 떨어진 것이 가까우면 줍고, 아니면 ↑(문 · 주민)
		onAct = function(down: boolean)
			if not down then
				Input.release("pickup")
				Input.release("up")
			elseif state.fx and state.fx:dropNear(state.body.x, state.body.y, RULES.pickup) then
				Input.press("pickup")
			else
				Input.press("up")
			end
		end,
		onToggle = function(on: boolean)
			Hud.setTouch(on)
			QuestHud.setTouch(on)
			GainLog.setTouch(on)
			if state.placeParty then
				state.placeParty() -- 폰에서는 파티원 칸을 제자리에(채팅 창은 Roblox 단추로 여닫는다)
			end
		end,
		-- 메뉴: 창 이름이 적힌 큰 단추들
		onMenu = function()
			if touchMenu then
				touchMenu:Destroy()
				touchMenu = nil
				return
			end
			local items = Windows.list() -- 키 설정은 넣지 않는다(손가락 단추에는 바꿀 키가 없다)
			-- 키 없이 「메뉴」 안에 두는 창(출석 · 업적 · 모험의 서 · 게임 설정 — PC의 「메뉴」와 같다). 전에는 빠져 폰에서는 출석 · 업적을 열 수 없었다(2026-10-18 검토)
			for _, w in UI_DATA.windows do
				if w.menu and w.id ~= "keys" and Windows.info(w.id) and (not w.need or (state.bond and state.bond.open)) then
					table.insert(items, { id = w.id, name = w.name })
				end
			end
			state.touchMenuItems = {}
			if state.me ~= nil and state.me.admin ~= nil then
				table.insert(items, { id = "admin", name = "관리" }) -- 관리자에게만
			end
			table.insert(items, { id = "@arrange", name = "단추 배치" }) -- 스킬 · 물약을 단추에 놓는다
			table.insert(items, { id = "@chars", name = "캐릭터 선택" }) -- 저장하고 캐릭터 고르기 화면으로 돌아간다
			-- 단추가 화면보다 길면(폰의 화면 틀은 768x432 — 단추 열셋이면 520) 판은 화면에 들어가는 만큼만 서고, 그 안에서 위아래로 민다
			--  사용자 2026-10-13(폰에서 해 보고): "메뉴탭 열었을때 스크롤이 되어야해 모든메뉴를 접근할수가 없다" — 치수는 Layout.touchMenu(공방 ui.js의 UILAYOUT.touchMenu)
			local m = Layout.touchMenu(#items, Stage.uiH)
			local K = Layout.TOUCHMENU
			local holder = Stage.place(Stage.ui, "TouchMenu", "tc", 480 - m.w / 2, m.top, m.w, m.h)
			holder.ZIndex = 160
			local panel = Ui.panel(holder, 0, 0, m.w, m.h)
			local list = Ui.scroll(panel, K.pad, K.pad, m.w - K.pad * 2, m.viewH, m.contentH, K.bar)
			list.Name = "List"
			list.ZIndex = 2
			for i, win in items do
				local itemBtn = Ui.button(list, win.name, 0, (i - 1) * K.row, m.btnW, function()
					holder:Destroy()
					touchMenu = nil
					if win.id == "@arrange" then
						Touch.arrange(true)
					elseif win.id == "@chars" then
						state.toSelect()
					else
						-- PC의 단추 줄 · 키와 같은 길(2026-10-21 점검): 「달빛 상점」 = 들어가는 공간(마을에서만) · 경매장 = 마을에서만.
						--  전에는 여기서 창을 바로 열어(Windows.toggle) 폰에서는 상점이 예전처럼 창으로 열리고 마을 밖에서도 열렸다
						state.openWin(win.id)
					end
				end, { h = K.btnH, font = "body", main = win.id == "@arrange" })
				state.touchMenuItems[win.id] = itemBtn.frame -- 튜토리얼(꿈)이 그 줄을 반짝이게 한다
			end
			touchMenu = holder
		end,
	})

	Touch.setCounts()

	-- 내 상태가 올 때마다: 레벨이 올라 새 창이 열리면 메뉴 칸이 생기고 한 번 반짝인다 · 스마트폰 물약 단추의 남은 수
	state.afterSelf = function(me)
		jobCall() -- 전직할 레벨이 됐으면 「달이 부른다」
		local fresh = Windows.setLevel(me.level)
		if #fresh > 0 then
			drawKeyHints()
			for _, id in fresh do
				Hud.flashMenu(id)
			end
		end
	end

	-- 게임에 들어온다: 처음 화면(캐릭터 고르기) 위로 막을 치고 → 그 뒤에서 게임 화면을 그리고 → 그림이 다 불러와지면 막을 걷는다(아래 — 화면이 돌기 시작한 뒤)
	Curtain.cover()
	enterScene(first.scene, first.x, first.y, first.room)
	Title.close() -- 게임 화면이 그려졌다: 처음 화면을 걷는다
	state.busy = true

	-- 캐릭터 고르기 화면으로 돌아간다(메뉴 → 캐릭터 선택): 서버가 저장하고 세계에서 빼 준 뒤, 고르기 화면에서 고른 캐릭터로 다시 들어온다.
	--  그동안 게임 화면은 멈춰 있다(자리 보고 · 기술 · 창을 여는 키를 받지 않는다). 확인용 임시 캐릭터(LuneGuest = 직업)에게는 고르기 화면이 없다.
	state.toSelect = function()
		if state.paused then
			return
		end
		state.paused = true
		Input.paused = true
		while Windows.closeTop() do
		end
		Talk.close()
		local left = Net.Invoke("Chars", "leave", nil, nil)
		if not (left and left.select) then
			state.paused, Input.paused = false, false
			if state.fx then
				state.fx:float("이 캐릭터로는 캐릭터 선택으로 갈 수 없다", state.body.x, state.body.y - 46, Effects.MINT, 1.6)
			end
			return
		end
		-- 게임 화면의 것(이름표 · 문 위의 글 · 손가락 단추)은 고르기 화면 위에 비치지 않게 숨긴다
		local touchWas = Touch.root ~= nil and Touch.root.Visible
		Hud.root.Visible = false
		Overlay.root.Visible = false
		if Touch.root then
			Touch.root.Visible = false
		end
		DeathBox.hide()
		Guide.clear()
		PartyHud.ask(nil) -- 앞 캐릭터가 받은 파티 초대는 지운다(서버는 이미 지웠다 — 2026-10-18 검토)
		closeMenus()
		Music.play(MUSIC.title)
		local got = Title.run(left.select, {
			skipLoading = true,
			invoke = function(action: string, a: any, b: any)
				return Net.Invoke("Chars", action, a, b)
			end,
		})
		adopt(got)
		state.daily = nil
		state.fetchDaily() -- 바꿔 들어온 캐릭터의 일일 의뢰
		state.attend, state.ach = nil, nil
		state.fetchAttend() -- 출석 칸(오늘 처음이면 창이 뜬다 — 계정에 하루 한 번이라 대개는 이미 찼다)
		Windows.resetLevel(got.self.level)
		Input.reset()
		Input.import(got.self.keys)
		drawKeyHints()
		Touch.setCounts()
		Curtain.cover() -- 고르기 화면 위로 막을 치고, 그 뒤에서 게임 화면을 그린다
		enterScene(got.scene, got.x, got.y, got.room)
		Hud.root.Visible = true
		Overlay.root.Visible = true
		if Touch.root then
			Touch.root.Visible = touchWas
		end
		Title.close()
		state.acc = 0
		state.busy = true
		state.paused, Input.paused = false, false
		task.spawn(function()
			showLoaded() -- 그 장면의 그림이 다 불러와진 뒤에 막을 걷는다
			Curtain.lift()
			afterLift()
			Input.flush()
			state.busy = false
		end)
	end

	local markT = 0
	RunService:BindToRenderStep("LuneFrame", Enum.RenderPriority.Camera.Value - 1, function(dt)
		if state.paused then
			return -- 캐릭터 고르기 화면에 가 있다
		end
		state.now += dt
		state.acc = math.min(state.acc + dt, STEP * MAX_STEPS)
		while state.acc >= STEP do
			state.acc -= STEP
			step()
		end
		draw(dt)
		if CashShop.isOpen() then
			CashShop.step(state.now, dt) -- 달빛 상점의 미리보기(내 캐릭터 · 펫 · 탈것)
			if Input.take("win:cash") then
				CashShop.leave(state.shopCtx) -- ` 키를 한 번 더: 나온다
			end
		end
		Hud.step(dt) -- 체력 바의 효과
		QuestHud.step(state.now) -- 켠 길찾기 단추의 빛
		-- 길찾기의 화살표: 켜 둔 퀘스트의 지금 진행에 맞는 쪽을 머리 위에(쓰러졌거나 장면을 바꾸는 중에는 숨긴다)
		if state.naviArrow then
			local dirNow = nil
			if state.navi and not state.dead and not state.busy and state.me and not CineView.active() then -- 장면이 도는 동안은 화살표를 숨긴다
				Navi.prepare(state.sceneKey) -- 이 맵의 발판과 길을 조금씩 잰다(다 재면 화살표가 발판을 따라 가리킨다)
				-- 땅에 서 있는 동안 1초에 10번만 다시 셈한다(맵이 바뀌었거나 방향이 없으면 바로 — 2026-10-18 검토: 매 장면 맵 사이의 길 · 발판 길을 다시 셈했다)
				if state.naviDir == nil or state.naviScene ~= state.sceneKey or (state.body.ground and state.now - (state.naviAt or -9) >= 0.1) then
					state.naviAt = state.now
					local mobs = {}
					if state.mobs then
						for id, m in state.mobs.mobs do
							if m.state ~= "gone" and m.state ~= "dead" then
								-- 길찾기는 { id, kind, x, y }를 본다 — 화면의 몬스터는 종류 · 높이를 info에 둔다(2026-10-18 검토: 그대로 넘겨 종류가 맞지 않아 사냥터에서 화살표가 몬스터를 가리키지 않고 사라졌다)
								table.insert(mobs, { id = id, kind = m.info.kind, x = m.x, y = m.info.y })
							end
						end
					end
					local arrow = Navi.arrow(state.navi, state.sceneKey, state.body.x, state.body.y, state.quests, state.me.level, state.daily, mobs)
					state.naviDir, state.naviScene = if arrow then arrow.dir else "none", state.sceneKey
				end
				-- 뛰어오른 동안에는 땅에 있을 때의 방향을 그대로 둔다(공중에서는 선 발판이 없어 길을 셈하지 못한다 — 화살표가 깜빡이지 않게)
				dirNow = state.naviDir
			else
				state.naviDir = nil
			end
			state.naviArrow:set(dirNow, state.body.x, state.body.y, state.now)
		end
		if state.me and state.body then
			if state.skill then
				TutView.cast = true -- 튜토리얼: 기술을 썼다
			end
			-- 꿈(튜토리얼)에서는 Lv.1이어도 가방이 열린다(「가방 열기」 미션) — 꿈을 나서면 거둔다. 바뀌면 화면 아래의 단추 줄을 다시 그린다
			local dreaming = Tutorial.isDream(state.sceneKey)
			if (Windows.extra.bag == true) ~= dreaming then
				Windows.extra.bag = if dreaming then true else nil
				if not dreaming then
					Windows.close("bag")
				end
				if state.drawKeyHints then
					state.drawKeyHints()
				end
			end
			local skillKey, skillName = state.slotOf("mob")
			TutView.update({
				tut = state.me.tut, skip = state.me.tutSkip, scene = state.sceneKey, zones = SCENES.scenes[state.sceneKey] and SCENES.scenes[state.sceneKey].tut,
				body = state.body, touch = Touch.on, key = state.keyName, dt = dt,
				skill = if skillKey then ("%s 키 「%s」"):format(skillKey, skillName or "") else nil, potion = (state.slotOf("potion")),
				windows = { bag = Windows.isOpen("bag"), stat = Windows.isOpen("stat"), skill = Windows.isOpen("skill") }, find = state.tutFind,
			})
		end
		Guide.step(dt)
		MapName.step(dt, (BossView.box ~= nil and BossView.box.Visible) or (RiftView.box ~= nil and RiftView.box.Visible) or CineView.active() or Windows.anyOpen()) -- 보스 체력 · 토벌 · 던전의 판(같은 위 가운데 — 2026-10-21) · 퀘스트 연출이 그 자리를 쓰거나 창이 열리면(창의 윗부분과 겹친다 — 2026-10-18) 바로 사라진다. 보스 체력은 칸이 보일 때만(전에는 한 번 보인 보스의 이름이 남아, 첫 보스 뒤로 맵 이름이 영영 안 떴다 — 2026-10-18 검토)
		GainLog.step(dt)
		markT += dt
		if markT >= 0.25 then
			markT = 0
			debugMarks()
			Guide.setHint(if Talk.npc then nil else state.guide()) -- 말풍선이 떠 있는 동안은 안내를 걷는다
		end
	end)
	-- 처음 장면의 그림이 다 불러와지면 막을 걷는다(그때까지 캐릭터는 멈춰 있다)
	task.spawn(function()
		showLoaded()
		Curtain.lift()
		afterLift()
		Input.flush()
		state.busy = false
	end)
	print(("[lune] 시작 — 장면 %s · 캐릭터 %s · 배율 x%s"):format(state.sceneKey, state.who, tostring(math.floor(Stage.scale * 100 + 0.5) / 100)))
end

return Boot
