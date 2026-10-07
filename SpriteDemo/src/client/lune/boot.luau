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
local Hud = require(script.Parent.hud)
local Chooser = require(script.Parent.chooser)
local Windows = require(script.Parent.ui.windows)
local StatWindow = require(script.Parent.ui.statWindow)
local SkillWindow = require(script.Parent.ui.skillWindow)
local KeysWindow = require(script.Parent.ui.keysWindow)
local Talk = require(script.Parent.ui.talk)
local Ui = require(script.Parent.ui.ui)
local Touch = require(script.Parent.touch)
local Items = require(lune.sim.items)
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
local QuestWindow = require(script.Parent.ui.questWindow)

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
	bag = nil :: any, -- 서버가 알려 준 가방 · 장비 · 창고(sim/bag.luau의 view)
	ui = { service = nil :: string?, npc = nil :: any, forgeTarget = nil :: number?, forgeMat = nil :: number?, forgeResult = nil :: string? }, -- 창들이 같이 보는 것
	openNpc = nil :: any, -- 주민이 해 주는 일(상점 · 강화 · 창고)을 여는 함수 — 열었으면 true
	dir = 1,
	clip = "idle",
	clipT = 0,
	clock = 0, -- 걸음으로 센 시간
	now = 0, -- 화면으로 센 시간(그리기 · 이어 그리기에 쓴다)
	acc = 0,
	skill = nil :: any, -- 쓰는 중인 기술 { id, def, seg, t, queued }
	cds = {} :: { [string]: number },
	busy = false, -- 문을 지나는 중
	dead = false,
	blink = 0,
	hurtT = 0, -- 맞는 동작이 남은 시간
	deadT = 0, -- 쓰러진 뒤 흐른 시간
	reportT = 0,
	pickT = 0,
	sentX = -1,
	sentY = -1,
	sentDir = 0,
}
Boot.state = state

local function preload()
	local list = {}
	for _, id in ASSETS do
		if id ~= "" then
			table.insert(list, id)
		end
	end
	if #list > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end
end

-- 장면을 바꿔 그린다. room = 서버가 준 그 방의 모습(졸개 · 떨어진 것)
local function enterScene(key: string, x: number, y: number, room)
	local scene = SCENES.scenes[key]
	assert(scene, "없는 장면 " .. tostring(key))
	if state.sprite then
		state.sprite:destroy()
	end
	if state.mobs then
		state.mobs:destroy()
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
	state.sceneKey = key
	state.over = Overlay.layer("Scene", 10)
	state.view = SceneView.new(Stage.view, key, scene, state.over)
	state.body = P.newBody(scene)
	state.body.x, state.body.y = x, y
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
	state.others:setWho(room.who or {})
	state.tag = Ui.tag(state.over, Others.tagText(if state.me then state.me.level else 1, state.myName), Ui.COLOR.text, 220, true)
	state.tagLevel = if state.me then state.me.level else 1
	PartyHud.set(state.party, state.myId, key)
	state.fx = Effects.new(state.view.topLayer, state.over, state.view.heroLayer)
	state.others.fx = state.fx -- 다른 사람의 대쉬도 같은 효과를 낸다
	for _, d in room.drops do
		state.fx:addDrop(d)
	end
	state.clip, state.clipT, state.skill = "idle", 0, nil
	state.sentX = -1
	Talk.close()
end

-- ---------- 기술 ----------
local function startSeg(id: string, seg: number)
	local def = COMBAT.skills[id]
	local sk = { id = id, def = def, seg = seg, t = 0, queued = false, vx = nil :: number?, move = 0, shown = {} }
	if seg == 1 and def.cd > 0 then
		state.cds[id] = state.clock + def.cd
	end
	-- 첫 구간과, 한 번 더 눌러 잇는 구간만 서버에 알린다(저절로 이어지는 구간은 서버가 알아서 잇는다)
	if seg == 1 or def.segs[seg].next then
		Net.FireServer("Skill", id, seg, state.body.x, state.body.y, state.dir)
	end
	if def.type == "move" then
		sk.vx = state.dir * def.speed
		sk.move = def.dist / def.speed
		-- 대쉬의 효과(시험 탭과 같다): 시작할 때 속도선, 가는 동안 잔상(stepSkill)
		state.fx:streaks(state.body.x, state.body.y, def.speed, state.dir, CLASSES.classes[state.who].tone)
	end
	state.skill = sk
end

local function trySkill(id: string)
	local def = COMBAT.skills[id]
	if not def or def.who ~= state.who or state.dead or state.busy then
		return
	end
	local sk = state.skill
	if sk then
		-- 같은 키를 한 번 더: 이어지는 구간이 있으면 예약한다
		local nextSeg = def.segs[sk.seg + 1]
		if sk.id == id and nextSeg and nextSeg.next then
			sk.queued = true
		end
		return
	end
	if (state.cds[id] or 0) > state.clock then
		return
	end
	startSeg(id, 1)
end

-- 쓰는 중인 기술을 한 걸음 진행한다. 끝났으면 nil이 된다.
local function stepSkill()
	local sk = state.skill
	if not sk then
		return
	end
	sk.t += STEP
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
		if nextSeg and (not nextSeg.next or sk.queued) then
			startSeg(sk.id, sk.seg + 1)
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
			state.busy = true
			local from = state.sceneKey
			task.spawn(function()
				local ok, result = pcall(Net.Invoke, "Travel", portal.to)
				if ok and result and state.sceneKey == from then
					enterScene(result.scene, result.x, result.y, result.room)
				end
				state.busy = false
			end)
			return
		end
		-- 주민 앞이면: 해 주는 일(상점 · 강화 · 창고)이 있으면 그 창을 열고, 없으면 말을 건다(한 번 더 누르면 다음 말)
		local npc = state.view:npcNear(body.x, body.y)
		if npc then
			local at = Quests.atNpc(state.quests, if state.me then state.me.level else 1, npc.id)
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
				if what == Quick.POTION then
					Net.FireServer("Potion")
				elseif what then
					trySkill(what)
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
	if sk then
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
	P.step(scene, body, input, STEP)
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

local function draw(dt: number)
	local body = state.body
	local char = state.sprite.char
	local sk = state.skill
	if sk then
		local segDef = sk.def.segs[sk.seg]
		local frame = segDef.from + math.min(segDef.to - segDef.from, math.floor(sk.t * segDef.fps)) + 1
		state.sprite:set(segDef.clip, frame, body.x, body.y, state.dir)
	elseif state.dead then
		-- 쓰러지는 동작을 한 번 틀고 마지막 장에서 멈춘다
		local n = #char.clips.death.frames
		state.sprite:set("death", math.min(n, math.floor(state.deadT * char.clips.death.fps) + 1), body.x, body.y, state.dir)
	elseif state.hurtT > 0 then
		local n = #char.clips.hurt.frames
		state.sprite:set("hurt", math.min(n, math.floor((0.25 - state.hurtT) * 12) + 1), body.x, body.y, state.dir)
	else
		local clip = if state.clip == "skill" then "idle" else state.clip
		state.sprite:set(clip, Sprite.frameAt(char, clip, state.clipT, clip == "jump"), body.x, body.y, state.dir)
	end
	-- 맞은 직후에는 깜빡인다
	local alpha = 0
	if not state.dead and state.blink > 0 and math.floor(state.now * 12) % 2 == 0 then
		alpha = 0.55
	end
	state.sprite.label.ImageTransparency = alpha
	state.view:update(body.x, body.y, state.now, body.ground)
	-- 스마트폰의 상호작용 단추가 지금 할 일: 떨어진 물건 → 문 → 주민의 차례로 가까운 것
	if Touch.on then
		Touch.setAct(if state.dead then nil elseif state.fx and state.fx:dropNear(body.x, body.y, RULES.pickup) then "pickup" elseif state.view:portalNear(body.x, body.y) then "portal" elseif state.view:npcNear(body.x, body.y) then "npc" else nil)
	end
	state.mobs:update(state.now)
	state.others:update(state.now, state.partySet)
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
	state.fx:update(state.now, dt)
	Talk.place() -- 말풍선은 그 주민을 따라간다
end

-- ---------- 서버가 알려 주는 것 ----------
local function listen()
	local myId = Players.LocalPlayer.UserId
	Net.OnClient("Self", function(me)
		state.me = me
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
	Net.OnClient("Hits", function(by, list)
		for _, h in list do
			local m = state.mobs and state.mobs:get(h.mob)
			if m then
				m.hp = h.hp
				-- 시험 탭과 같은 자리 · 같은 색: 발밑에서 16도트 위(우두머리는 30)에서 뜬다. 센 타격은 때린 사람 직업의 밝은 색
				state.fx:number(h.dmg, m.x, m.info.y - (if m.def.boss then 30 else 16), if h.big then Effects.BIG[toneOf(by)] else Effects.DEAL, h.big)
			end
		end
	end)
	Net.OnClient("Hurt", function(e)
		state.fx:number(e.dmg, state.body.x, state.body.y - 22, Effects.HURT) -- 머리 바로 위에서 뜬다(졸개의 숫자가 발밑에서 16 위인 것과 같은 느낌)
		state.blink = RULES.invuln
		if not state.skill then
			state.hurtT = 0.25 -- 기술을 쓰는 중이 아니면 맞는 동작을 잠깐 보인다
		end
		if e.dead then
			state.dead = true
			state.deadT = 0
			state.skill = nil
			state.fx:float("쓰러졌다", state.body.x, state.body.y - 46, Effects.PINK, 2.2)
		end
	end)
	Net.OnClient("Gain", function(e)
		state.fx:float("+" .. e.xp, state.body.x, state.body.y - 34, Effects.MINT)
		if e.ups > 0 then
			state.fx:float("레벨 업! Lv." .. e.level, state.body.x, state.body.y - 48, Effects.GOLD, 1.8)
		end
	end)
	Net.OnClient("DropAdd", function(d)
		if state.fx then
			state.fx:addDrop(d)
		end
	end)
	Net.OnClient("DropGone", function(id, taker, amount)
		local d = state.fx and state.fx:removeDrop(id)
		if d and taker == myId then
			if d.kind == "gear" then
				state.fx:float(ItemCell.label(d.item), d.x, d.y - 18, ItemCell.color(d.item), 1.6)
			elseif d.kind == "quest" then
				state.fx:float("+1 " .. tostring(d.name), d.x, d.y - 18, Effects.GOLD, 1.2)
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
	Net.OnClient("Act", function(id, skillId, seg, x, y, dir)
		if state.others then
			state.others:act(id, skillId, seg, x, y, dir, state.now)
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
		state.quests = book
		if state.drawQuests then
			state.drawQuests()
		end
		local def = doneId and Quests.def(doneId)
		if def and state.fx then
			state.fx:float(("「%s」 완료"):format(def.name), state.body.x, state.body.y - 84, Effects.GOLD, 2.2) -- 쌓인 이름표 · 레벨 업 글씨보다 위에
		end
	end)
	Net.OnClient("Bag", function(bag)
		state.bag = bag
		Windows.refresh(state.me)
	end)
	-- 물건을 다룬 결과: 안 됐으면 까닭을 머리 위에, 강화의 결과는 강화 창에
	Net.OnClient("ItemDone", function(e)
		if e.action == "enhance" and e.ok then
			state.ui.forgeResult = e.result
		elseif e.action == "dismantle" and e.ok and state.fx then
			state.fx:float("+" .. Format.short(e.result) .. " 달가루", state.body.x, state.body.y - 34, Effects.MINT)
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
	Net.OnClient("ShotEnd", function(id)
		if state.fx then
			state.fx:endShot(id)
		end
	end)
	Net.OnClient("Burst", function(e)
		if state.mobs then
			state.mobs:burst(e.mob, state.now)
		end
	end)
	Net.OnClient("Revive", function(e)
		state.dead = false
		enterScene(e.scene, e.x, e.y, e.room)
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
	Hud.init()
	preload()
	listen()

	local first = Net.Invoke("Ready")
	if first and first.choose then
		-- 처음 온 사람: 직업을 고른다. 서버가 캐릭터를 만들어 주면 이어 간다(고르는 동안 늘 보이는 화면은 숨긴다)
		Hud.root.Visible = false
		repeat
			first = Net.Invoke("Choose", Chooser.run())
		until first and first.self
		Chooser.close()
		Hud.root.Visible = true
	end
	assert(first and first.self, "서버에서 캐릭터를 받지 못했다")
	state.me = first.self
	state.myId, state.myName = first.id, first.name
	state.quests = first.quests or {}
	state.bag = first.bag
	state.who = first.self.class
	Hud.setSelf(first.self)
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
	-- 퀵슬롯: 키는 스킬이 아니라 칸에 붙는다(칸마다 하나 — 공방의 QUICK.keys). 칸에 놓인 것은 서버가 저장해 둔 것(없으면 처음 차림)
	for i, name in QUICK.keys do
		Input.bind("slot:" .. i, (Enum.KeyCode :: any)[name])
	end
	state.slots = first.self.slots or Quick.start(CLASSES.classes[state.who].skills)
	state.touchSlots = first.self.tslots or Quick.start(CLASSES.classes[state.who].skills) -- 스마트폰의 단추 배치(PC의 퀵슬롯과 따로 저장한다)

	-- 창: 능력치 · 스킬 · 키 설정. 여는 키는 공방에서 정한 것(P · K — 키 설정은 메뉴에서)
	local function keyName(action: string): string
		local key = Input.BIND[action]
		return Format.key(if key then key.Name else "-")
	end
	-- 메뉴 단추: 앞의 다섯(가방 · 장비 · 능력치 · 스킬 · 퀘스트 — 열린 것만)은 그림 단추로, 나머지 창과 키 설정은 「메뉴」 단추 안에
	local MAIN = { bag = true, equip = true, stat = true, skill = true, quest = true }
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
		local w, rowH = 132, 28
		local h = #items * rowH + 14
		local r = UI_HUD.menu
		local holder = Stage.place(Stage.ui, "More", r.at, r.x + r.w - w, r.y - h - 6, w, h)
		holder.ZIndex = 160
		local panel = Ui.panel(holder, 0, 0, w, h)
		for i, item in items do
			Ui.button(panel, item.name, 8, 8 + (i - 1) * rowH, w - 16, function()
				closeMore()
				Windows.toggle(item.id)
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
		else
			Windows.open("shop", kind)
		end
		Windows.open("bag", nil)
	end
	state.openNpc = function(npc): boolean
		local kind = Items.data.NPCDO[npc.id]
		local level = state.me.level
		if kind == "shop" then
			openService("merchant")
		elseif kind == "smith" and level >= Items.data.OPEN.forge then
			openService("forge")
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
		npcNames = function()
			return state.npcNames
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
			state.ui.service = if Windows.isOpen("forge") then "forge" elseif Windows.isOpen("shop") and Windows.argOf("shop") == "store" then "store" else nil
			if not Windows.isOpen("forge") then
				state.ui.forgeTarget, state.ui.forgeMat, state.ui.forgeResult = nil, nil, nil
			end
			local openSet = {}
			for _, w in Windows.all() do
				openSet[w.id] = Windows.isOpen(w.id)
			end
			Hud.setOpen(openSet)
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
				return Quests.mark(state.quests, level, npcId)
			end)
		end
		QuestHud.set(state.quests, state.npcNames)
		Windows.refresh(state.me)
	end
	Input.onEnter = Chat.open

	-- 스마트폰 단추(터치 화면이면 저절로 켜진다)
	local touchMenu: Frame? = nil
	Touch.init({
		-- 칸 단추에 놓을 수 있는 것: 물약과 배운(쓸 수 있는) 스킬 — 놓을 것의 목록에 뜬다
		choices = function()
			local list = { { what = Quick.POTION, name = "물약" } }
			for _, sk in mySkills do
				if quickHooks.state(sk.id) == "ok" then
					table.insert(list, { what = sk.id, name = sk.name })
				end
			end
			return list
		end,
		apply = quickHooks.apply,
		-- 누르고 있으면 이어서 쓰는 스킬: 공격 스킬(사냥기 · 보스기)
		repeats = function(id: string): boolean
			local def = COMBAT.skills[id]
			return def ~= nil and (def.type == "mob" or def.type == "boss")
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
			table.insert(items, { id = "@arrange", name = "단추 배치" }) -- 스킬 · 물약을 단추에 놓는다
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
					else
						Windows.toggle(win.id)
					end
				end, { h = 36, font = "body", main = win.id == "@arrange" })
			end
			touchMenu = holder
		end,
	})

	Touch.setPotions(first.self.potions)

	-- 내 상태가 올 때마다: 레벨이 올라 새 창이 열리면 메뉴 칸이 생기고 한 번 반짝인다 · 스마트폰 물약 단추의 남은 수
	state.afterSelf = function(me)
		local fresh = Windows.setLevel(me.level)
		if #fresh > 0 then
			drawKeyHints()
			for _, id in fresh do
				Hud.flashMenu(id)
			end
		end
		Touch.setPotions(me.potions)
	end

	enterScene(first.scene, first.x, first.y, first.room)

	local markT = 0
	RunService:BindToRenderStep("LuneFrame", Enum.RenderPriority.Camera.Value - 1, function(dt)
		state.now += dt
		state.acc = math.min(state.acc + dt, STEP * MAX_STEPS)
		while state.acc >= STEP do
			state.acc -= STEP
			step()
		end
		draw(dt)
		markT += dt
		if markT >= 0.25 then
			markT = 0
			debugMarks()
		end
	end)
	print(("[lune] 시작 — 장면 %s · 캐릭터 %s · 배율 x%s"):format(state.sceneKey, state.who, tostring(math.floor(Stage.scale * 100 + 0.5) / 100)))
end

return Boot
