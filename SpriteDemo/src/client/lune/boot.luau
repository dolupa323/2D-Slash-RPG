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
local Stage = require(script.Parent.stage)
local SceneView = require(script.Parent.sceneView)
local Sprite = require(script.Parent.sprite)
local Input = require(script.Parent.input)
local MobsView = require(script.Parent.mobsView)
local MiniMap = require(script.Parent.minimap)
local Effects = require(script.Parent.effects)
local Hud = require(script.Parent.hud)
local Chooser = require(script.Parent.chooser)
local Windows = require(script.Parent.ui.windows)
local StatWindow = require(script.Parent.ui.statWindow)
local SkillWindow = require(script.Parent.ui.skillWindow)
local KeysWindow = require(script.Parent.ui.keysWindow)
local Talk = require(script.Parent.ui.talk)
local Kit = require(script.Parent.ui.kit)
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

local Boot = {}
local mySkills = {} -- 내 직업의 기술(사냥기 · 보스기 · 이동기 차례로) { id, name, type, order, cd }

local state = {
	who = "axion",
	sceneKey = SCENES.start,
	view = nil :: any,
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
		state.view:destroy() -- 이름표(내 것 포함)는 장면의 층과 함께 사라진다
	end
	state.sceneKey = key
	state.view = SceneView.new(Stage.view, key, scene)
	state.body = P.newBody(scene)
	state.body.x, state.body.y = x, y
	state.sprite = Sprite.new(state.view.heroLayer, state.who)
	state.mobs = MobsView.new(state.view.mobLayer, room, state.view.topLayer)
	table.clear(state.npcNames)
	for _, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			state.npcNames[n.id] = n.name
		end
	end
	if state.drawQuests then
		state.drawQuests()
	end
	state.others = Others.new(state.view.heroLayer, state.view.topLayer, state.myId)
	state.others:setWho(room.who or {})
	state.tag = Kit.tag(state.view.topLayer, Others.tagText(if state.me then state.me.level else 1, state.myName), Kit.COLOR.white, 150)
	state.tagLevel = if state.me then state.me.level else 1
	PartyHud.set(state.party, state.myId, key)
	state.fx = Effects.new(state.view.topLayer)
	for _, d in room.drops do
		state.fx:addDrop(d)
	end
	state.clip, state.clipT, state.skill = "idle", 0, nil
	state.sentX = -1
	Talk.close()
	Talk.sheet = if scene.npcSheet then { image = ASSETS[scene.npcSheet] or "", w = scene.npcCell[1], h = scene.npcCell[2] } else nil
	MiniMap.setScene(scene)
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
	state.view:update(body.x, body.y, state.now)
	state.mobs:update(state.now)
	state.others:update(state.now, state.partySet)
	-- 이름표(발밑): 내 것이 먼저 자리를 잡고, 다른 사람들 · 다친 졸개의 것은 주민의 이름표와 서로를 피해 아래로 쌓인다
	local tags = state.others:tags()
	table.insert(tags, 1, { x = math.floor(body.x - state.tag.Width / 2 + 0.5), y = math.floor(body.y + 0.5) + Others.TAG_DOWN, w = state.tag.Width, frame = state.tag.Frame })
	for _, t in state.mobs:tags() do
		table.insert(tags, t)
	end
	for i, y in Tags.stack(state.view:rects(), tags, Kit.TAG_H + 1, 1) do
		tags[i].frame.Position = UDim2.fromOffset(tags[i].x, y)
	end
	-- 스킬 칸: 다시 쓰기까지 남은 시간
	for _, sk in mySkills do
		Hud.setCooldown(sk.id, (state.cds[sk.id] or 0) - state.clock, sk.cd)
	end
	state.fx:update(state.now, dt)
	MiniMap.update(body.x, body.y, state.mobs.mobs, state.now)
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
	Net.OnClient("Hits", function(_by, list)
		for _, h in list do
			local m = state.mobs and state.mobs:get(h.mob)
			if m then
				m.hp = h.hp
				state.fx:number(h.dmg, m.x, m.info.y - 30, Effects.DEAL)
			end
		end
	end)
	Net.OnClient("Hurt", function(e)
		state.fx:number(e.dmg, state.body.x, state.body.y - 34, Effects.HURT)
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

local KEYS = { Shift = Enum.KeyCode.LeftShift }

function Boot.start()
	Stage.init()
	Input.init()
	Hud.init()
	MiniMap.init(Hud.root)
	preload()
	listen()

	local first = Net.Invoke("Ready")
	if first and first.choose then
		-- 처음 온 사람: 직업을 고른다. 서버가 캐릭터를 만들어 주면 이어 간다
		repeat
			first = Net.Invoke("Choose", Chooser.run())
		until first and first.self
		Chooser.close()
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
			Input.bind("skill:" .. id, KEYS[def.key] or Enum.KeyCode[def.key])
			table.insert(mySkills, { id = id, name = def.name, type = def.type, order = order[def.type] or 9, cd = def.cd })
		end
	end
	table.sort(mySkills, function(a, b)
		return a.order < b.order
	end)

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
		local w, rowH = 74, 15
		local h = #items * rowH + 7
		local at = Hud.menuRoot.Position
		local panel = Kit.plate(Stage.view, "frame", at.X.Offset, at.Y.Offset - h - 1, w, h)
		panel.Name = "More"
		panel.ZIndex = 160
		for i, item in items do
			Kit.button(panel, item.name, 4, 4 + (i - 1) * rowH, w - 8, 14, function()
				closeMore()
				Windows.toggle(item.id)
			end).frame.Name = "More_" .. item.id
		end
		morePanel = panel
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
		for _, sk in mySkills do
			table.insert(list, { id = sk.id, key = keyName("skill:" .. sk.id), name = sk.name })
		end
		Hud.setSkills(list)
		local menu = {}
		for _, w in Windows.list() do
			if MAIN[w.id] then
				table.insert(menu, { id = w.id, name = w.name, key = keyName("win:" .. w.id) })
			end
		end
		table.insert(menu, { id = "more", name = "메뉴", key = "" })
		closeMore()
		Hud.setMenu(menu, onMenu)
		Hud.setPotionKey(keyName("potion"))
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
			Windows.refresh(state.me)
		end,
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
				{ action = "potion", name = "물약" },
			}
			for _, sk in mySkills do
				table.insert(out, { action = "skill:" .. sk.id, name = sk.name })
			end
			for _, w in Windows.list() do
				table.insert(out, { action = "win:" .. w.id, name = w.name })
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
	Talk.onToggle = QuestHud.hide
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
		skillOf = function(kind: string)
			for _, sk in mySkills do
				if sk.type == kind then
					return "skill:" .. sk.id
				end
			end
			return nil
		end,
		labelOf = function(name: string)
			local labels = { ["사냥기"] = "사냥", ["보스기"] = "보스", ["뛰기"] = "뛰기", ["대쉬"] = "대쉬", ["물약"] = "물약", ["줍기 · 말 걸기"] = "줍기", ["메뉴"] = "…" }
			return labels[name]
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
			if #items == 0 then
				return -- 아직 열린 창이 없다(Lv.1)
			end
			local panel = Kit.plate(Stage.view, "frame", 104, 30, 176, #items * 24 + 8)
			panel.ZIndex = 160
			for i, w in items do
				Kit.button(panel, w.name, 5, 5 + (i - 1) * 24, 166, 20, function()
					Windows.toggle(w.id)
					panel:Destroy()
					touchMenu = nil
				end)
			end
			touchMenu = panel
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
	print(("[lune] 시작 — 장면 %s · 캐릭터 %s · 배율 x%d"):format(state.sceneKey, state.who, Stage.scale))
end

return Boot
