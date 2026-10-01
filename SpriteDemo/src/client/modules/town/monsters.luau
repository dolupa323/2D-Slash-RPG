-- 탑다운 씬의 몬스터 — 서버 권위(server/modules/townMonsters.luau)가 만들고 움직이는 몬스터를 그대로 그린다(온라인 공유).
--  씬에 들어오면 GetTownState로 지금 목록을 받고, 이후 같은 씬 사람 모두가 같은 이벤트를 받는다:
--   TownMonsterMoves(10Hz 위치 — 부드럽게 따라감) / TownMonsterHit(체력·데미지) / TownMonsterDied / TownMonsterSpawned.
--  머리 위: "Lv.N" + 체력 게이지(한 대라도 맞으면 보임 — 다른 사람이 때린 것도 보인다).
--  데미지 숫자는 내가 때린 건 노랑, 다른 사람이 때린 건 흰색. 맞으면 몸 위에 때린 무기에 맞는 베기 VFX(town/weapon.luau).
-- 공격은 topDownHero가 판정 프레임에 TownAttack(바라보는 방향)만 보내고, 판정·기여도·보상·도감은 전부 서버가 한다.
-- 몬스터 반격(TownMonsterAttack): 공격하는 몬스터가 바라보는 쪽으로 잠깐 튀어 나간다(피해·사망은 서버 → PlayerHealthChanged).
-- 포획(M2): 누군가 단축칸 방울을 쓰면(BellThrown) 그 사람 손에서 바라보는 방향으로 방울이 직선으로 날아간다(빗나가면 떨어져 사라짐).
--  맞으면(TownCapture) 같은 씬 모두에게 같은 연출: 발밑 룬 문양 원 → 딸랑 3번(흔들림) → 성공: 반짝 + 폴짝 + 사라짐 /
--  실패: 원이 깨지고 도망 / 포획 불가(blocked — 다른 사람이 딜 1등): 방울이 튕겨 떨어짐. (공방 「방울·포획」 탭과 같은 순서)
--  체력이 capture.HINT_HP 이하인 몬스터 머리 위에는 작은 방울 표시만(숫자·확률은 전투 화면에 안 보임).
-- 이벤트의 첫 인자는 씬 키 — 씬을 옮기는 순간 늦게 도착한 다른 씬 이벤트는 버린다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local Net = require(ReplicatedStorage.shared.net.net)
local map = require(script.Parent.map)
local damageNumbers = require(script.Parent.Parent.damageNumbers)
local UI = require(script.Parent.Parent.ui.pixelUI)
local weapon = require(script.Parent.weapon)
local capture = require(ReplicatedStorage.shared.config.capture)

local world = map.world
local S = map.S
local CS = townAssets.MONSTER_SCALE -- 그림 크기 배율(위치는 바닥 배율 S)
local SHEET = world.monsterSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local IDLE_FRAME_TIME = 0.3
local WALK_FRAME_TIME = 0.15
local FOLLOW = 12 -- 서버 위치를 따라가는 빠르기(클수록 바로 붙음)
local MY_HIT = Color3.fromRGB(255, 230, 90)
local OTHER_HIT = Color3.fromRGB(255, 255, 255)

local exports = {}
local byId = {}

local function makeMonster(gameFrame: Instance, w)
	local label = Instance.new("ImageLabel")
	label.Name = "Mon_" .. w.id
	label.Image = townAssets.MONSTERS
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ScaleType = Enum.ScaleType.Stretch
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.fromOffset(CELL.X * CS, CELL.Y * CS)
	label.ImageRectSize = CELL
	label.Parent = gameFrame
	-- 머리 위: 레벨 글씨 + 체력 게이지(도트 UI, 캐릭터 배율)
	local tag = Instance.new("Frame")
	tag.Name = "Tag"
	tag.BackgroundTransparency = 1
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.new(0.5, 0, 0, 4 * CS)
	tag.Size = UDim2.fromOffset(40, 22)
	tag.Parent = label
	local tagScale = Instance.new("UIScale")
	tagScale.Scale = townAssets.CHAR_SCALE
	tagScale.Parent = tag
	-- 씬 화면(ScreenGui)은 ZIndex 전역 정렬이라, 머리 위 글씨·게이지를 모든 월드 그림(나무·집 등) 위로 올린다
	local level = UI.Label(tag, "", 0, 0, { Color = UI.colors.white, Shadow = UI.colors.ink, ZIndex = 9005 })
	local bar = UI.Bar(tag, 8, 13, 24, "red")
	bar.Instance.ZIndex = 9001
	for _, g in bar.Instance:GetDescendants() do
		if g:IsA("GuiObject") then
			g.ZIndex = 9002
		end
	end
	-- 잡기 좋은 체력(capture.HINT_HP 이하)일 때만 레벨 글씨 옆 작은 방울(숫자·확률 없음)
	local hint = nil
	if UI.Has("icon_bell_1") then
		hint = UI.Part(tag, "icon_bell_1", 32, -1, 8, 8)
		hint.ZIndex = 9006
		hint.Visible = false
	end
	local m = { id = w.id, label = label, level = level, bar = bar, hint = hint, clock = math.random() }
	byId[w.id] = m
	return m
end

local function apply(m, w)
	m.row = w.row
	m.label.Image = townAssets.MONSTER_SHEETS[townWorld.MonsterSheet(w.row)]
	m.x, m.y, m.tx, m.ty = w.x, w.y, w.x, w.y
	m.hp, m.maxHp = w.hp, w.maxHp
	m.moving, m.dead, m.capturing = false, false, false
	m.level:SetText("Lv." .. w.level)
	m.level.Frame.Position = UDim2.fromOffset(20 - m.level.Width // 2, 0)
	m.bar:SetRatio(m.hp / m.maxHp)
	m.bar.Instance.Visible = m.hp < m.maxHp
	m.label.ImageTransparency = 0
	m.label.Visible = true
	if m.hint then
		m.hint.Visible = false
	end
end

-- 방울 등급별 룬 문양 색(공방 js/bells.js의 테두리 색)
local BELL_RIM = {
	Color3.fromRGB(122, 130, 150), Color3.fromRGB(79, 158, 216), Color3.fromRGB(216, 150, 28),
	Color3.fromRGB(255, 211, 74), Color3.fromRGB(184, 156, 240),
}

local function dot(parent: Instance, color: Color3, size: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Size = UDim2.fromOffset(size, size)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = 9301
	f.Visible = false
	f.Parent = parent
	return f
end

local function bellImage(parent: Instance, tier: number, size: number): ImageLabel?
	if not UI.Has("icon_bell_" .. tier) then
		return nil
	end
	local bell = UI.Part(parent, "icon_bell_" .. tier, 0, 0, size, size)
	bell.AnchorPoint = Vector2.new(0.5, 0.5)
	bell.ZIndex = 9302
	return bell
end

local function fxHolder(gameFrame: Instance): Frame
	local holder = Instance.new("Frame")
	holder.Name = "CaptureFx"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, 0)
	holder.ZIndex = 9300
	holder.Parent = gameFrame
	return holder
end

-- 방울 날아가기(빗나가면 끝에서 떨어지며 사라짐, 맞으면 거기서 TownCapture 연출이 이어받음). 좌표는 도트.
local function playThrow(gameFrame: Instance, x: number, y: number, dx: number, dy: number, dist: number, tier: number, hit: boolean)
	local holder = fxHolder(gameFrame)
	local bell = bellImage(holder, tier, 8 * CS)
	if not bell then
		holder:Destroy()
		return
	end
	local flight = dist / capture.THROW_SPEED
	local clock = 0
	while clock < flight + (if hit then 0 else 0.35) and holder.Parent do
		clock += task.wait()
		local k = math.min(clock / flight, 1)
		local px, py = (x + dx * dist * k) * S, (y + dy * dist * k) * S - math.sin(k * math.pi) * 6
		if clock > flight then -- 빗나감: 떨어지며 사라짐
			local f = (clock - flight) / 0.35
			py += f * 10
			bell.ImageTransparency = f
		end
		bell.Position = UDim2.fromOffset(px, py)
		bell.Rotation = clock * 720
	end
	holder:Destroy()
end

-- 포획 연출(약 2초 + 결과). result = "success" | "fail" | "blocked". label = 몬스터 그림(발 기준 AnchorPoint 0.5,1)
local function playCapture(gameFrame: Instance, m, tier: number, result: string, dings: number?)
	local label = m.label
	local feet = Vector2.new(label.Position.X.Offset, label.Position.Y.Offset)
	local height = CELL.Y * CS
	local rim = BELL_RIM[tier] or BELL_RIM[1]
	local holder = fxHolder(gameFrame)
	local bellSize = 12 * CS
	local bell = bellImage(holder, tier, bellSize)
	local head = feet - Vector2.new(0, height + 4)
	if result == "blocked" then -- 튕겨 나감
		local clock = 0
		while clock < 0.6 and holder.Parent do
			clock += task.wait()
			if bell then
				bell.Position = UDim2.fromOffset(head.X + clock * 40, head.Y - math.sin(clock / 0.6 * math.pi) * 14 + clock * 30)
				bell.Rotation = clock * 600
				bell.ImageTransparency = clock / 0.6
			end
		end
		holder:Destroy()
		return
	end
	local success = result == "success"
	local ring = {}
	local RING_N = 28
	local rx, ry = 14 * CS, 5 * CS
	for i = 1, RING_N do
		ring[i] = dot(holder, rim, 2 * CS)
	end
	local runes = {}
	for i = 1, 4 do
		runes[i] = dot(holder, rim, 2 * CS)
	end
	local sparks = {}
	for i = 1, 8 do
		sparks[i] = dot(holder, rim, 2 * CS)
	end
	local clock = 0
	local labelBase = label.Position
	dings = dings or 0
	local REVEAL = capture.RevealTime(dings)
	local RING, DING = capture.RING_TIME, capture.DING_TIME
	while clock < REVEAL + 0.9 and holder.Parent and label.Parent do
		clock += task.wait()
		local spin = clock * 1.1
		-- 방울: 머리 위에서 흔들림(딸랑 3번) → 성공이면 작아져 머리에 / 실패면 떨어짐
		if bell then
			if clock < REVEAL then
				-- 딸랑: 통과한 판정 수만큼 한 번씩 크게 흔들림(사이엔 멈춤)
				local d = (clock - RING) / DING
				local swinging = clock > RING and d < dings
				bell.Position = UDim2.fromOffset(head.X, head.Y)
				bell.Rotation = if swinging then math.sin((d % 1) * math.pi * 2) * 24 else 0
			elseif success then
				local k = math.min(1, (clock - REVEAL) / 0.3)
				local size = bellSize * (1 - 0.4 * k)
				bell.Size = UDim2.fromOffset(size, size)
				bell.Rotation = 0
				bell.Position = UDim2.fromOffset(head.X + 6 * CS * k, head.Y + 6 * CS * k)
				bell.ImageTransparency = math.clamp((clock - REVEAL - 0.4) / 0.4, 0, 1)
			else
				local k = math.min(1, (clock - REVEAL) / 0.4)
				bell.Position = UDim2.fromOffset(head.X, head.Y + 50 * k)
				bell.ImageTransparency = k
			end
		end
		-- 룬 문양 원(처음 0.35초 동안 한 바퀴 그려짐, 실패하면 결과 때 깨짐)
		local sweep = math.clamp(clock / 0.35, 0, 1)
		local broken = not success and clock > REVEAL
		local fade = if clock > REVEAL + 0.4 then (clock - REVEAL - 0.4) / 0.5 else 0
		for i, f in ring do
			local a = (i / RING_N) * math.pi * 2 + spin
			f.Position = UDim2.fromOffset(feet.X + math.cos(a) * rx, feet.Y + math.sin(a) * ry)
			f.Visible = i <= RING_N * sweep and not (broken and i % 3 == 0) and fade < 1
			f.BackgroundTransparency = math.clamp(fade, 0, 1)
		end
		for i, f in runes do
			local a = (i / 4) * math.pi * 2 - spin * 0.8
			f.Position = UDim2.fromOffset(feet.X + math.cos(a) * rx * 0.55, feet.Y + math.sin(a) * ry * 0.55)
			f.Visible = sweep >= 1 and not broken and fade < 1
		end
		-- 딸랑마다 몬스터가 빠져나오려고 꿈틀
		if clock > RING and clock < REVEAL then
			local d = (clock - RING) / DING
			local wiggle = if d < dings and (d % 1) < 0.5 then math.sin((d % 1) * math.pi * 8) * 2 else 0
			label.Position = labelBase + UDim2.fromOffset(wiggle, 0)
		end
		-- 결과
		if clock > REVEAL then
			if success then
				local k = (clock - REVEAL) / 0.5
				for i, f in sparks do
					local a = (i / 8) * math.pi * 2
					local r = 8 + k * 22
					f.Position = UDim2.fromOffset(feet.X + math.cos(a) * r, feet.Y - height / 2 + math.sin(a) * r)
					f.Visible = k < 1
				end
				local hop = if clock < REVEAL + 0.4 then math.sin((clock - REVEAL) / 0.4 * math.pi) * 8 else 0
				label.Position = labelBase - UDim2.fromOffset(0, hop)
				label.ImageTransparency = math.clamp((clock - REVEAL - 0.4) / 0.4, 0, 1)
			else
				local k = math.min(1, (clock - REVEAL) / 0.8)
				label.Position = labelBase + UDim2.fromOffset(60 * k, 0)
				label.ImageTransparency = 0.3 + 0.7 * k
			end
		end
	end
	holder:Destroy()
	m.dead = true
	label.Visible = false
end

local function flash(label: ImageLabel)
	label.ImageColor3 = Color3.fromRGB(255, 150, 150)
	task.delay(0.12, function()
		if label.Parent then
			label.ImageColor3 = Color3.new(1, 1, 1)
		end
	end)
end

function exports.load(scene: Scene)
	local d = map.Use(scene)
	if not d then
		return
	end
	local key = map.key
	local gameFrame = scene.Instance.GameFrame
	table.clear(byId)
	local myId = Players.LocalPlayer.UserId

	local function mine(sceneKey)
		return sceneKey == key and exports.active
	end
	exports.active = true
	local conns = {}
	exports.conns = conns

	table.insert(conns, Net.OnClient("TownMonsterMoves", function(sceneKey, list)
		if not mine(sceneKey) then
			return
		end
		for _, e in list do
			local m = byId[e[1]]
			if m and not m.dead then
				m.tx, m.ty, m.facingLeft, m.moving = e[2], e[3], e[4], e[5]
			end
		end
	end))
	table.insert(conns, Net.OnClient("TownMonsterSpawned", function(sceneKey, w)
		if not mine(sceneKey) then
			return
		end
		apply(byId[w.id] or makeMonster(gameFrame, w), w)
	end))
	table.insert(conns, Net.OnClient("TownMonsterHit", function(sceneKey, id, hp, damage, attacker, weaponId)
		local m = mine(sceneKey) and byId[id]
		if not m then
			return
		end
		-- 맞은 몬스터 몸 위에 무기에 맞는 베기 VFX(town/weapon.luau)
		local p = m.label.Position
		weapon.HitSlash(Vector2.new(p.X.Offset, p.Y.Offset - CELL.Y * CS / 2), weaponId)
		m.hp = hp
		m.bar:SetRatio(hp / m.maxHp)
		if m.hint then
			m.hint.Visible = hp > 0 and hp / m.maxHp <= capture.HINT_HP
		end
		m.bar.Instance.Visible = true
		damageNumbers.Show(m.label, damage, if attacker == myId then MY_HIT else OTHER_HIT)
		flash(m.label)
	end))
	-- 반격: 공격하는 순간 몸을 살짝 키웠다 돌아오며 앞으로 튀어 나간다(서버가 플레이어 피해를 따로 준다)
	table.insert(conns, Net.OnClient("TownMonsterAttack", function(sceneKey, id)
		local m = mine(sceneKey) and byId[id]
		if not m or m.dead then
			return
		end
		m.lungeUntil = os.clock() + 0.15
	end))
	table.insert(conns, Net.OnClient("BellThrown", function(sceneKey, userId, x, y, dx, dy, dist, tier, hitId)
		if not mine(sceneKey) then
			return
		end
		task.spawn(playThrow, gameFrame, x, y, dx, dy, dist, tier, hitId ~= 0)
	end))
	table.insert(conns, Net.OnClient("TownCapture", function(sceneKey, id, tier, result, dings)
		local m = mine(sceneKey) and byId[id]
		if not m then
			return
		end
		if result ~= "blocked" then
			m.capturing = true -- 연출 동안 멈춤(끝나면 사라짐 — 다시 나타날 때 apply가 되돌린다)
			m.bar.Instance.Visible = false
			if m.hint then
				m.hint.Visible = false
			end
		end
		task.spawn(playCapture, gameFrame, m, tier, result, dings)
	end))
	table.insert(conns, Net.OnClient("TownMonsterDied", function(sceneKey, id)
		local m = mine(sceneKey) and byId[id]
		if not m then
			return
		end
		m.dead = true
		local label = m.label
		task.spawn(function()
			for i = 1, 5 do -- 깜빡이며 사라짐
				if not label.Parent or not m.dead then
					return
				end
				label.ImageTransparency = if i % 2 == 1 then 0.7 else 0.2
				task.wait(0.08)
			end
			if m.dead then
				label.Visible = false
			end
		end)
	end))

	-- 지금 목록(몬스터 + 땅의 아이템)
	task.spawn(function()
		local ok, state = pcall(Net.Invoke, "GetTownState")
		if not ok or typeof(state) ~= "table" or state.scene ~= key or not exports.active then
			return
		end
		for _, w in state.monsters do
			apply(byId[w.id] or makeMonster(gameFrame, w), w)
		end
		local drops = require(script.Parent.drops)
		drops.ApplyList(key, state.drops)
	end)

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		local k = 1 - math.exp(-FOLLOW * math.min(dt, 0.1))
		for _, m in byId do
			if m.dead or m.capturing then
				continue
			end
			m.clock += dt
			m.x += (m.tx - m.x) * k
			m.y += (m.ty - m.y) * k
			-- 시트 칸: 대기R 0~3, 걷기R 4~7, 대기L 8~11, 걷기L 12~15
			local frame = if m.moving
				then math.floor(m.clock / WALK_FRAME_TIME) % 4 + 4
				else math.floor(m.clock / IDLE_FRAME_TIME) % 4
			if m.facingLeft then
				frame += 8
			end
			local label = m.label
			label.ImageRectOffset = townWorld.MonsterFrameOffset(m.row, frame)
			-- 공방 편집기와 같은 기준: 발(그림자 아래끝)이 pos보다 1도트 아래.
			local lunge = if m.lungeUntil and os.clock() < m.lungeUntil then (if m.facingLeft then -3 else 3) else 0
			label.Position = UDim2.fromOffset(math.round((m.x + lunge) * S), math.round((m.y + 1) * S))
			label.ZIndex = map.ZIndexFor(m.y)
		end
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	exports.active = false
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	for _, c in exports.conns or {} do
		c:Disconnect()
	end
	exports.conns = nil
	for _, m in byId do
		m.label:Destroy()
	end
	table.clear(byId)
end

return exports
