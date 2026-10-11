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
local CLASSES = require(lune.data["classes.generated"])
local Stage = require(script.Parent.stage)
local SceneView = require(script.Parent.sceneView)
local Sprite = require(script.Parent.sprite)
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
local Talk = require(script.Parent.ui.talk)
local Ui = require(script.Parent.ui.ui)
local Kit = require(script.Parent.ui.kit) -- 부품 그림(퀘스트의 자리 위에 뜨는 「!」)
local Touch = require(script.Parent.touch)
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
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
local QuestHud = require(script.Parent.questHud)
local Guide = require(script.Parent.guide)
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
local UI_HUD = require(lune.data["ui.generated"]).hud
local QUICK = require(lune.data["ui.generated"]).quick -- 퀵슬롯(칸 수 · 칸마다의 기본 키 · 글)
local Quick = require(lune.ui.quick)
local QuickEdit = require(script.Parent.ui.quickEdit)

local Boot = {}
local mySkills = {} -- 내 직업의 기술(사냥기 · 보스기 · 이동기 차례로) { id, name, type, order, cd }

local state = {
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

local function enterScene(key: string, x: number, y: number, room)
	local scene = SCENES.scenes[key]
	assert(scene, "없는 장면 " .. tostring(key))
	if state.sprite then
		state.sprite:destroy()
	end
	if state.mobs then
		state.mobs:destroy()
	end
	if state.boss then
		state.boss:destroy()
	end
	if state.fx then
		state.fx:destroy()
	end
	if state.others then
		state.others:destroy()
	end
	if state.view then
		state.view:destroy()
	end
	if state.over then
		state.over:Destroy() -- 이름표(내 것 포함) · 체력 띠 · 알림 글은 이 층과 함께 사라진다
	end
	table.clear(state.spots) -- 퀘스트의 자리 표시도 위의 두 층과 함께 사라졌다(새 장면의 것은 아래 drawQuests가 만든다)
	if MUSIC.hidden[key] and state.sceneKey ~= key then
		Music.jingle("strange") -- 숨은 방에 들어섰다
	end
	state.sceneKey = key
	Music.scene(key) -- 그 장면의 배경 음악(같은 곡이면 이어 튼다)
	state.over = Overlay.layer("Scene", 10)
	state.view = SceneView.new(Stage.view, key, scene, state.over)
	state.body = P.newBody(scene)
	state.body.x, state.body.y = x, y
	if state.me then
		state.body.run, state.body.jump = state.me.run or 1, state.me.jump or 1 -- 걸음 · 뛰는 힘의 배수(패시브)는 장면이 바뀌어도 그대로
	end
	state.sprite = Sprite.new(state.view.heroLayer, state.who)
	state.mobs = MobsView.new(state.view.mobLayer, room, state.over)
	table.clear(state.npcNames)
	for _, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			state.npcNames[n.id] = n.name
		end
	end
	if state.drawQuests then
		state.drawQuests()
	end
	state.others = Others.new(state.view.heroLayer, state.over, state.myId)
	state.others.graveLayer = state.view.graveLayer
	state.others:setWho(room.who or {})
	state.grave = Grave.new(state.view.graveLayer) -- 내 비석(쓰러졌을 때만 보인다)
	state.tag = Ui.tag(state.over, Others.tagText(if state.me then state.me.level else 1, state.myName), Ui.COLOR.text, 220, true)
	state.tagLevel = if state.me then state.me.level else 1
	PartyHud.set(state.party, state.myId, key)
	state.fx = Effects.new(state.view.topLayer, state.over, state.view.heroLayer)
	state.others.fx = state.fx -- 다른 사람의 대쉬도 같은 효과를 낸다
	for _, d in room.drops do
		state.fx:addDrop(d)
	end
	-- 기술의 이펙트: 나와 방의 사람들이 쓰는 기술을 시험 탭과 같은 그림으로 돌린다
	state.cast = Cast.new(state.view, scene, state.fx, state.mobs)
	state.boss = BossView.new(state.mobs, state.cast, state.fx, scene) -- 스토리 보스가 서는 방이면 그 예고와 이펙트 · 잔상 · 화면 흔들림(없는 방에서는 아무것도 하지 않는다)
	state.actor = state.cast:actor(state.myId or 0, state.who, true)
	state.actor.x, state.actor.y = x, y
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
		sceneRunning = false
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
	for _, sp in Quests.spotsIn(state.quests or {}, state.sceneKey) do
		sp.mark = Kit.part(state.view.topLayer, SceneView.MARK["!"], 0, 0)
		sp.mark.Name = "SpotMark"
		sp.mark.ZIndex = 6
		sp.tag = Ui.tag(state.over, ("↑ %s"):format(sp.act), Ui.COLOR.accent, 220)
		sp.tag.Frame.Visible = false
		table.insert(state.spots, sp)
	end
end
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
				if o.placed and not o.alive and state.partySet[oid] and math.abs(o.x - state.body.x) <= castDef.heal.reach and math.abs(o.y - state.body.y) <= 80 then
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
			end)
		end
	end
	if state.dead or state.busy then
		P.step(scene, body, { mx = 0 }, STEP)
		return
	end

	-- 문 앞에서 ↑: 서버에 묻고, 허락하면 그 장면으로
	local wantUp = Input.take("up") and body.ground and not state.skill
	if wantUp then
		local portal = state.view:portalNear(body.x, body.y)
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
		-- 퀘스트의 자리 앞이면(샘 · 깃발): 서버에 알린다 — 숫자가 오르면 그 자리의 표시가 사라진다
		local spot = nearSpot(body.x, body.y)
		if spot then
			Net.FireServer("Quest", "use", spot.quest)
			if state.fx then
				state.fx:float(spot.act, spot.x, spot.y - 34, Effects.MINT, 1.2)
			end
			return
		end
		-- 주민 앞이면: 해 주는 일(상점 · 강화 · 창고)이 있으면 그 창을 열고, 없으면 말을 건다(한 번 더 누르면 다음 말)
		local npc = state.view:npcNear(body.x, body.y)
		if npc then
			local at = Quests.atNpc(state.quests, if state.me then state.me.level else 1, npc.id, scene.region)
			if Talk.with(npc) then
				Talk.next(npc) -- 말하는 중이면 다음 말로
			elseif #at.ready > 0 then
				local def = Quests.def(at.ready[1])
				Talk.start(npc, def.done, def.name, function()
					Net.FireServer("Quest", "complete", def.id)
				end, "끝낸다")
			elseif #at.offer > 0 then
				local def = Quests.def(at.offer[1])
				Talk.start(npc, def.offer, def.name, function()
					Net.FireServer("Quest", "accept", def.id)
				end, "받는다")
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
	if state.ui.npc and (state.sceneKey ~= state.ui.scene or math.abs(state.ui.npc.x - body.x) > 70) then
		state.ui.npc = nil
		Windows.close("shop")
		Windows.close("forge")
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
				if what and Quick.item(what) then
					Net.FireServer("Potion", what) -- 소비 아이템: 그 칸에 놓인 바로 그 아이템을 쓴다
				elseif what then
					trySkill(what, from[1] .. i) -- 그 칸의 키(힘을 모을 때 누르고 있는지 본다)
				end
			end
		end
	end
	if Input.take("potion") then
		Net.FireServer("Potion")
	end
	-- 창을 여는 키(아직 열리지 않은 창은 Windows가 열어 주지 않는다 — 누른 키는 여기서 받아 버린다)
	for _, w in Windows.all() do
		if Input.take("win:" .. w.id) then
			Windows.toggle(w.id)
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
		elseif (s.walk or 0) > 0 then
			input = { mx = mx, speed = s.walk, float = s.float == true, down = false }
		else
			input = { mx = 0, vx = 0, float = s.float == true, down = false }
		end
		Input.take("jump")
	elseif sk then
		-- 기술 중: 걷지 않는다(걸으며 쓰는 기술은 느리게 걷는다). 이동기(대쉬)는 보는 쪽으로 밀고 나가며 떨어지지 않는다
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
		input = { mx = mx, jump = Input.take("jump"), down = Input.held("down") }
	end
	local airWas = body.air or 0
	P.step(scene, body, input, STEP)
	if (body.air or 0) > airWas and state.fx then
		state.fx:hop(body.x, body.y) -- 2단 점프: 공중에서 발을 구른 자리에 점이 흩어진다
	end
	stepSkill()

	local clip = if state.skill then "skill" else P.clipOf(body, mx)
	if clip ~= state.clip then
		state.clip, state.clipT = clip, 0
	else
		state.clipT += STEP
	end

	-- 내 자리를 서버에 알린다(바뀌었을 때만)
	state.reportT += STEP
	if state.reportT >= REPORT then
		state.reportT = 0
		local x, y = math.floor(body.x * 10 + 0.5) / 10, math.floor(body.y * 10 + 0.5) / 10
		if x ~= state.sentX or y ~= state.sentY or state.dir ~= state.sentDir then
			state.sentX, state.sentY, state.sentDir = x, y, state.dir
			Net.FireServer("Move", x, y, state.dir)
		end
	end
end

local paintBuffs: () -> () -- 버프 자리를 그린다(아래에서 짓는다)

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
	cast:look(me, state.sprite, poseClip, poseFrame, body.x, body.y, state.dir, alpha)
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
	state.view:update(body.x, body.y, state.now, body.ground)
	-- 스마트폰의 상호작용 단추가 지금 할 일: 떨어진 물건 → 문 → 주민의 차례로 가까운 것
	if Touch.on then
		Touch.setAct(if state.dead then nil elseif state.fx and state.fx:dropNear(body.x, body.y, RULES.pickup) then "pickup" elseif state.view:portalNear(body.x, body.y) then "portal" elseif nearSpot(body.x, body.y) then "spot" elseif state.view:npcNear(body.x, body.y) then "npc" else nil)
	end
	state.mobs:update(if held then state.holdNow else state.now) -- 멈칫하는 동안은 몬스터의 그림도 멈춘 순간 그대로(하얗게 번쩍인 채)
	state.boss:update(dt)
	state.others:update(state.now, state.partySet)
	-- 다른 사람들: 그 사람의 자리에서 그 사람의 기술의 이펙트가 돈다
	for id, o in state.others.list do
		if o.placed then
			local a = cast:actor(id, o.class, false)
			a.x, a.y, a.dir = o.x, o.y, o.dir
			-- 그 사람의 몸에도 버프가 입히는 모습을 그린다(분신 · 윤곽은 그 사람의 지금 동작을 따라 그린다). 비석이 선 사람은 몸을 그리지 않는다
			if o.clip and not o.fallen then
				a.pose = { clip = o.clip, f = o.frame - 1 }
				cast:look(a, o.sprite, o.clip, o.frame, o.x, o.y, o.dir, 0)
			end
		end
	end
	Cast.speed = tonumber(Stage.gui:GetAttribute("FxSpeed")) or 1 -- 확인용: PlayerGui.LuneStage의 속성 FxSpeed(예: 0.05)로 이펙트를 느리게 돌려 본다
	cast:update(dt)
	cast:draw()
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
	for i, on in Tags.visible(tags, Ui.TAG_H) do
		local t = tags[i]
		t.frame.Visible = on
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
	Talk.place() -- 말풍선은 그 주민을 따라간다
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
		table.insert(list, { pic = "skill_" .. k.toggle.id, text = "" })
	end
	local passed = state.now - (state.buffAt or state.now)
	for _, b in state.buffs or {} do
		local left = b.t - passed
		if left > 0 then
			table.insert(list, { pic = "skill_" .. b.id, text = tostring(math.ceil(left)), hot = left < 5 })
		end
	end
	-- 열기(살라맨더): 발밑의 막대(직업 묶음이 그린다)는 이름표에 가려 잘 보이지 않는다 — 버프 자리에 값을 같이 적는다(달아오르면 노랑)
	if state.who == "salamander" and me.kit.heat > 0 then
		table.insert(list, { pic = "skill_" .. k.core.id, text = tostring(me.kit.heat), hot = me.kit.hot })
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
		if jobWas and me.job and me.job > jobWas and state.onJob then
			state.onJob(me) -- 전직했다: 윗차수의 사냥기 · 보스기가 놓인 칸을 서버의 것으로 맞춘다
		end
		Hud.setLocked(skillsLocked()) -- 스킬 칸의 잠금은 내 상태가 올 때마다 맞춘다(레벨이 먼저 오르는 경우에도 풀린다)
		applyKit(me)
		Hud.setSelf(me)
		Windows.refresh(me)
		if state.tag and state.tagLevel ~= me.level then
			state.tagLevel = me.level
			state.tag:SetText(Others.tagText(me.level, state.myName))
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
				-- 시험 탭과 같은 자리 · 같은 색: 발밑에서 16도트 위(우두머리는 30)에서 뜬다. 센 타격(치명타도)은 때린 사람 직업의 밝은 색.
				--  맞는 순간 파편이 튀고, 쓰러지면 세모 파편이 터진다(시험 탭의 hurt)
				local function land()
					state.fx:number(h.dmg, m.x, m.info.y - MobsView.topOf(m), if h.big then Effects.BIG[tone] else Effects.DEAL, h.big)
					-- 타격감(공방 combat.js의 hit): 몬스터가 하얗게 번쩍이며 때린 쪽의 반대로 조금 밀리고, 맞은 자리에 불꽃과 파편이 튄다.
					--  내가 직접 때린 타(따로 나가는 사출기 · 장치의 타는 빼고)에는 그림이 잠깐 멈칫한다 — gap초에 한 번만(연타가 굼떠지지 않게)
					local a = actorOf(by)
					local dir = if m.x >= (if a then a.x else state.body.x) then 1 else -1
					MobsView.hit(m, state.now, dir)
					state.cast:hurt(m, Cast.tone(tone), h.big, h.dead, dir)
					local H = RULES.hit
					if by == state.myId and not h.proc and state.now - state.holdAt >= H.gap then
						state.holdAt, state.holdNow = state.now, state.now
						state.holdT = if h.big or h.dead then H.holdBig else H.hold
					end
					-- 소리(효과음을 올린 뒤에 난다): 내가 때린 타만 — 쓰러뜨렸으면 그 소리도
					if by == state.myId then
						Music.hit(h.big)
						if h.dead then
							Music.sfx("kill")
						end
					end
				end
				-- 따로 나가는 타(사출기 · 장치): 그 직업의 이펙트가 날아가 닿는 순간에 숫자가 뜬다(달빛 도끼 · 표창 · 도깨비불 · 수정 조각 · 불티 · 불꽃).
				--  그 사람이 아직 화면에 없으면(방금 들어왔다) 숫자만 바로 띄운다
				if not (h.proc and state.cast:proc(actorOf(by), h.proc, m, h.sx, h.sy, land, h)) then
					land()
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
		state.fx:number(e.dmg, state.body.x, state.body.y - 22, Effects.HURT) -- 머리 바로 위에서 뜬다(졸개의 숫자가 발밑에서 16 위인 것과 같은 느낌)
		Music.sfx("hurt")
		state.blink = RULES.invuln
		if not state.skill then
			state.hurtT = 0.25 -- 기술을 쓰는 중이 아니면 맞는 동작을 잠깐 보인다
		end
		if e.dead then
			state.dead = true
			state.deadT = 0
			state.skill = nil
			state.fx:float("쓰러졌다", state.body.x, state.body.y - 46, Effects.PINK, 2.2)
			Music.jingle("death")
		end
	end)
	Net.OnClient("Gain", function(e)
		state.fx:float("+" .. e.xp, state.body.x, state.body.y - 34, Effects.MINT)
		if e.ups > 0 then
			state.fx:float("레벨 업! Lv." .. e.level, state.body.x, state.body.y - 48, Effects.GOLD, 1.8)
			Music.jingle("victory")
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
			elseif d.kind == "quest" or d.kind == "goods" then
				state.fx:float("+1 " .. tostring(d.name), d.x, d.y - 18, if d.kind == "quest" then Effects.GOLD else Effects.MINT, 1.2) -- 퀘스트의 물건은 노랑 · 재료와 물약은 민트
			elseif d.kind == "dust" then
				state.fx:float("+" .. Format.short(amount) .. " 달가루", d.x, d.y - 18, Effects.MINT)
			else
				state.fx:float("+" .. Format.short(amount) .. " 달돈", d.x, d.y - 18, Effects.GOLD)
			end
		end
	end)
	-- 같은 맵의 다른 사람들: 이름표 · 자리 · 기술
	Net.OnClient("Who", function(key, roster)
		if key == state.sceneKey and state.others then
			state.others:setWho(roster)
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
			if o and state.cast then
				local a = state.cast:actor(id, o.class, false)
				a.x, a.y, a.dir = x, y, dir
				state.cast:instant(a, skillId)
			end
			return
		end
		-- 2~4차의 스킬 가운데 쓰는 동작이 없는 것(열 방출)
		if COMBAT.cast[skillId] and Kitset.skill(skillId) and Kitset.skill(skillId).instant then
			local o = state.others and state.others.list[id]
			if o and state.cast then
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
			if o and def and def.type ~= "move" and state.cast then
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
			if q and not st.done and not (state.quests or {})[id] and state.fx then
				state.fx:float(("「%s」 수락"):format(q.name), state.body.x, state.body.y - 84, Effects.MINT, 2)
			end
		end
		state.quests = book
		if state.drawQuests then
			state.drawQuests()
		end
		local def = doneId and Quests.def(doneId)
		if def and state.fx and def.kind ~= "job" then -- 전직은 화면 가운데의 큰 알림이 알린다
			state.fx:float(("「%s」 완료"):format(def.name), state.body.x, state.body.y - 84, Effects.GOLD, 2.2) -- 쌓인 이름표 · 레벨 업 글씨보다 위에
			Music.jingle("complete")
		end
		-- 사제에게 첫 기술을 배웠다: 스킬 칸이 생긴다
		if lockedWas and not skillsLocked() then
			Hud.setLocked(false)
			Guide.banner("기술을 배웠다", "화면 아래에 스킬 칸이 생겼다", 4)
		end
		-- 전직 퀘스트: 받을 수 있게 됐다("달이 부른다") · 돌려줘서 전직했다
		jobCall()
		if def and def.kind == "job" and def.reward.job then
			Guide.banner(("%d차 전직"):format(def.reward.job), "스킬 창에 새 스킬이 열렸다 — 사냥기와 보스기가 새것으로 바뀌었다", 6)
			Music.jingle("victory")
		end
	end)
	Net.OnClient("Bag", function(bag)
		state.bag = bag
		Hud.setCounts() -- 퀵슬롯에 놓인 소비 아이템의 수
		Touch.setCounts()
		Windows.refresh(state.me)
	end)
	-- 물건을 다룬 결과: 안 됐으면 까닭을 머리 위에, 강화의 결과는 강화 창에
	Net.OnClient("ItemDone", function(e)
		if e.action == "enhance" and e.ok then
			state.ui.forgeResult = e.result
		elseif e.action == "dismantle" and e.ok and state.fx then
			state.fx:float("+" .. Format.short(e.result) .. " 달가루", state.body.x, state.body.y - 34, Effects.MINT)
		elseif e.action == "sell" and e.ok and state.fx then
			state.fx:float("+" .. Format.short(e.result) .. " 달돈", state.body.x, state.body.y - 34, Effects.GOLD) -- 상점에 팔았다
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
	-- 서버가 나를 다른 장면으로 옮겼다(마을로 돌아가기 · 관리 이동): 문을 지날 때와 같은 길로(막 → 그리기 → 그림 불러오기 → 막 걷기)
	Net.OnClient("Revive", function(e)
		state.dead = false
		DeathBox.hide()
		goScene(e)
	end)
	-- 소생을 받아 그 자리에서 일어났다(관리의 「체력 채우기」로 일어났을 때도)
	Net.OnClient("Raise", function(_e)
		state.dead = false
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
	preload({ "title_", "chars_", "ui_kit", "font_" }, nil)
	local first = Net.Invoke("Ready")
	if first and first.select then
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
	Hud.root.Visible = true
	assert(first and first.self, "서버에서 캐릭터를 받지 못했다")
	-- 서버가 준 캐릭터를 화면의 상태에 얹는다(처음 들어올 때 · 캐릭터 고르기 화면에서 다른 캐릭터로 들어올 때)
	local function adopt(got)
		state.me = got.self
		state.myId, state.myName = got.id, got.name
		state.quests = got.quests or {}
		state.bag = got.bag
		state.who = got.self.class
		state.dead, state.skill, state.party = false, nil, nil
		table.clear(state.cds)
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
		state.touchSlots = got.self.tslots or Quick.start(CLASSES.classes[state.who].skills) -- 스마트폰의 단추 배치(PC의 퀵슬롯과 따로 저장한다)
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
	local MAIN = { bag = true, equip = true, stat = true, skill = true, quest = true, map = true }
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
		table.insert(items, { id = "keys", name = "키 설정" })
		if isAdmin() then
			table.insert(items, { id = "admin", name = "관리" })
		end
		table.insert(items, { id = "@chars", name = "캐릭터 선택" }) -- 저장하고 캐릭터 고르기 화면으로 돌아간다
		table.insert(items, { id = "@sound", name = if Music.on then "소리 끄기" else "소리 켜기" })
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
				elseif item.id == "@sound" then
					Music.toggle()
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
			Windows.toggle(id)
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
		local menu = {}
		for _, w in Windows.list() do
			if MAIN[w.id] then
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
	-- 주민이 해 주는 일의 창을 연다(가방이 옆에 같이 뜬다). kind = merchant · store · forge · smithShop
	local function openService(kind: string)
		if kind == "forge" then
			Windows.close("shop")
			Windows.open("forge", nil)
		elseif kind == "smithShop" then
			Windows.close("forge")
			Windows.open("shop", "smith")
		elseif kind == "craft" then
			Windows.close("forge")
			Windows.open("shop", "craft") -- 대장장이의 제작(재료 → 장비)
		else
			Windows.open("shop", kind)
		end
		Windows.open("bag", nil, true) -- 가방 창이 아직 열리지 않은 레벨(Lv.1)이어도 같이 띄운다 — 창고 · 상점은 가방과 짝이다
	end
	state.openNpc = function(npc): boolean
		local kind = Items.data.NPCDO[npc.id]
		local level = state.me.level
		if kind == "hall" then
			-- 명예의 전당의 비석: 그 비석의 순위판을 연다(hall_level → "level")
			Windows.open("hall", string.match(npc.id, "^hall_(%a+)$") or "level", true)
		elseif kind == "shop" then
			openService("merchant")
		elseif kind == "smith" then
			-- 대장장이: 강화가 열린 뒤(Lv.8)에는 강화 창부터, 그 전에는 상점부터(상점에서 「제작하러 가기」로 재료 제작을 한다 — 제작은 Lv.1부터)
			openService(if level >= Items.data.OPEN.forge then "forge" else "smithShop")
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
		quests = function()
			return state.quests
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
			ForgeWindow.put(state.ui, id)
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
	drawKeyHints()

	Talk.init()
	PartyHud.init(Hud.root, function(name: string, ...)
		Net.FireServer(name, ...)
	end)
	Chat.init(Hud.root)
	QuestHud.init(Hud.root)
	BossView.init(Hud.root)
	Guide.init(Hud.root)
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
	state.guide = function()
		local me = state.me
		if not me or state.dead or not state.view or not state.body then
			return nil
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
	-- 말풍선이 떠 있는 주민의 머리 위 표시는 그동안 숨는다
	Talk.onToggle = function(npc)
		if state.view then
			state.view:setTalking(if npc then npc.id else nil)
		end
	end
	-- 퀘스트가 바뀌면: 주민 머리 위의 표시 · 알리미 · 열려 있는 창
	state.drawQuests = function()
		local level = if state.me then state.me.level else 1
		if state.view then
			state.view:setMarks(function(npcId: string)
				return Quests.mark(state.quests, level, npcId, SCENES.scenes[state.sceneKey].region)
			end)
		end
		QuestHud.set(state.quests, state.npcNames, level)
		drawSpots() -- 맵에 놓인 것 앞에서 ↑를 누르는 퀘스트의 자리
		Windows.refresh(state.me)
	end
	Input.onEnter = Chat.open

	-- 스마트폰 단추(터치 화면이면 저절로 켜진다)
	local touchMenu: Frame? = nil
	Touch.init({
		-- 칸 단추에 놓을 수 있는 것: 물약과 배운(쓸 수 있는) 스킬 — 놓을 것의 목록에 뜬다
		choices = function()
			-- 소비 아이템: 가방에 있는 것과 이미 단추에 놓아 둔 것(다 써서 0개여도 놓아 둔 것은 남는다)
			local list = {}
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
			Chat.setTouch(on)
		end,
		onChat = Chat.open,
		-- 메뉴: 창 이름이 적힌 큰 단추들
		onMenu = function()
			if touchMenu then
				touchMenu:Destroy()
				touchMenu = nil
				return
			end
			local items = Windows.list() -- 키 설정은 넣지 않는다(손가락 단추에는 바꿀 키가 없다)
			if state.me ~= nil and state.me.admin ~= nil then
				table.insert(items, { id = "admin", name = "관리" }) -- 관리자에게만
			end
			table.insert(items, { id = "@arrange", name = "단추 배치" }) -- 스킬 · 물약을 단추에 놓는다
			table.insert(items, { id = "@chars", name = "캐릭터 선택" }) -- 저장하고 캐릭터 고르기 화면으로 돌아간다
			table.insert(items, { id = "@sound", name = if Music.on then "소리 끄기" else "소리 켜기" })
				local w, rowH = 240, 40
			local h = #items * rowH + 12
			local holder = Stage.place(Stage.ui, "TouchMenu", "tc", 480 - w / 2, 60, w, h)
			holder.ZIndex = 160
			local panel = Ui.panel(holder, 0, 0, w, h)
			for i, win in items do
				Ui.button(panel, win.name, 8, 8 + (i - 1) * rowH, w - 16, function()
					holder:Destroy()
					touchMenu = nil
					if win.id == "@arrange" then
						Touch.arrange(true)
					elseif win.id == "@chars" then
						state.toSelect()
					elseif win.id == "@sound" then
						Music.toggle()
					else
						Windows.toggle(win.id)
					end
				end, { h = 36, font = "body", main = win.id == "@arrange" })
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
		Chat.close()
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
		Music.play(MUSIC.title)
		local got = Title.run(left.select, {
			skipLoading = true,
			invoke = function(action: string, a: any, b: any)
				return Net.Invoke("Chars", action, a, b)
			end,
		})
		adopt(got)
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
		Guide.step(dt)
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
		state.busy = false
	end)
	print(("[lune] 시작 — 장면 %s · 캐릭터 %s · 배율 x%s"):format(state.sceneKey, state.who, tostring(math.floor(Stage.scale * 100 + 0.5) / 100)))
end

return Boot
