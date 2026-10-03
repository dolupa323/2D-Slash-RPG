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
-- 투척 무기(「오문 닌자전」, ProjectileThrown): 누군가 단축칸의 수리검·쿠나이·폭탄을 던지면 그 아이콘이 직선으로 날아간다(폭탄은 도착해서 터짐).
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
local packFx = require(script.Parent.Parent.packFx)
local capture = require(ReplicatedStorage.shared.config.capture)
local features = require(ReplicatedStorage.shared.config.features)
local items = require(ReplicatedStorage.shared.data.items)

local world = map.world
local S = map.S
local CS = townAssets.MONSTER_SCALE -- 그림 크기 배율(위치는 바닥 배율 S)
local SHEET = world.monsterSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local IDLE_FRAME_TIME = 0.3
local WALK_FRAME_TIME = 0.15
local FOLLOW = 12 -- 서버 위치를 따라가는 빠르기(클수록 바로 붙음)
local UI_SCALE = 2 -- 머리 위 글씨·게이지 배율(그림 배율과 따로 — 팩 그림은 배율 4라 글씨까지 키우면 너무 크다)
-- 「오문 닌자전」 시트(SHEET.block): 방향 번호 → 그 방향으로 1칸
local DIR_VEC = { [0] = Vector2.new(0, 1), [1] = Vector2.new(0, -1), [2] = Vector2.new(-1, 0), [3] = Vector2.new(1, 0) }
local MY_HIT = Color3.fromRGB(255, 230, 90)
local OTHER_HIT = Color3.fromRGB(255, 255, 255)
local MY_PET_HIT = Color3.fromRGB(140, 220, 255) -- 내 펫 스킬 피해(맞음 이펙트는 town/petFx)
-- 인술 상태 이상(서버 TownMonsterStatus): 그 시간 동안 몸 색이 바뀐다(느려짐 = 옅은 하늘색, 멈춤 = 푸른색)
local STATUS_TINT = { slow = Color3.fromRGB(170, 215, 255), stun = Color3.fromRGB(120, 165, 255) }
local WHITE = Color3.new(1, 1, 1)

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
	tag.Position = UDim2.new(0.5, 0, 0, if SHEET.block then -2 else 4 * CS)
	tag.Size = UDim2.fromOffset(40, 22)
	tag.Parent = label
	local tagScale = Instance.new("UIScale")
	tagScale.Scale = UI_SCALE
	tagScale.Parent = tag
	-- 씬 화면(ScreenGui)은 ZIndex 전역 정렬이라, 머리 위 글씨·게이지를 모든 월드 그림(나무·집 등) 위로 올린다
	local level = UI.Label(tag, "", 0, 0, { Color = UI.colors.white, Shadow = UI.colors.ink, ZIndex = 9005, Clamp = false })
	local bar = UI.Bar(tag, 8, 13, 24, "red")
	bar.Instance.ZIndex = 9001
	for _, g in bar.Instance:GetDescendants() do
		if g:IsA("GuiObject") then
			g.ZIndex = 9002
		end
	end
	-- 잡기 좋은 체력(capture.HINT_HP 이하)일 때만 레벨 글씨 옆 작은 방울(숫자·확률 없음)
	local hint = nil
	if features.CAPTURE and UI.Has("icon_bell_1") then
		hint = UI.Part(tag, "icon_bell_1", 32, -1, 8, 8) -- lint: optional(포획이 꺼져 있고 UI.Has로 확인한 뒤에만 그린다)
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
	m.dir = 0 -- 바라보는 방향(아래 0 · 위 1 · 왼 2 · 오 3) — 움직인 쪽으로 바뀐다
	m.level:SetText("Lv." .. w.level)
	m.level.Frame.Position = UDim2.fromOffset(20 - m.level.Width // 2, 0)
	m.bar:SetRatio(m.hp / m.maxHp)
	m.bar.Instance.Visible = m.hp < m.maxHp
	m.label.ImageTransparency = 0
	m.tintUntil = nil
	m.label.ImageColor3 = WHITE
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

-- 투척 무기 날아가기(「오문 닌자전」 — 서버 ProjectileThrown): 아이템 아이콘이 직선으로 날아간다. 좌표는 도트.
--  수리검은 빙글빙글 돌고, 쿠나이는 날 끝이 날아가는 쪽을 향한다. radius > 0(폭탄)이면 포물선으로 날아가 도착 자리에서 터진다.
local function playProjectile(gameFrame: Instance, itemId: string, x: number, y: number, dx: number, dy: number, dist: number, speed: number, radius: number)
	local def = items[itemId]
	local name = def and def.KitIcon and def.KitIcon ~= "" and "icon_" .. def.KitIcon
	if not name or not UI.Has(name) then
		return
	end
	local holder = fxHolder(gameFrame)
	local size = 10 * S
	local img = UI.Part(holder, name, 0, 0, size, size)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.ZIndex = 9302
	local spin = itemId == "Shuriken"
	local heading = math.deg(math.atan2(dy, dx))
	local flight = dist / speed
	local clock = 0
	while clock < flight and holder.Parent do
		clock += task.wait()
		local k = math.min(clock / flight, 1)
		local arc = if radius > 0 then math.sin(k * math.pi) * 10 else 0
		img.Position = UDim2.fromOffset((x + dx * dist * k) * S, (y + dy * dist * k - arc) * S)
		-- 쿠나이 그림은 날 끝이 오른쪽 위(↗)를 향한다 — 날아가는 쪽에 맞추려면 45도 더 돌린다
		img.Rotation = if spin then clock * 1080 elseif radius > 0 then clock * 360 else heading + 45
	end
	img:Destroy()
	if radius > 0 then
		-- 터짐: 팩 폭발 이펙트(도착 자리)
		local at = Vector2.new((x + dx * dist) * S, (y + dy * dist) * S)
		packFx.Play(gameFrame, "explosion", function()
			return at
		end, { zIndex = 9302 })
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

-- 지금 몸 색: 상태 이상 중이면 그 색, 아니면 원래 색
local function baseColor(m): Color3
	return if m.tintUntil and os.clock() < m.tintUntil then m.tint else WHITE
end

local function flash(m)
	local label = m.label
	label.ImageColor3 = Color3.fromRGB(255, 150, 150)
	task.delay(0.12, function()
		if label.Parent then
			label.ImageColor3 = baseColor(m)
		end
	end)
end

-- 몬스터 발 위치(화면 px)와 몸 가운데까지 높이 — 펫 스킬 연출(town/petFx)이 쓴다. 없거나 쓰러졌으면 nil.
function exports.Feet(id: number): Vector2?
	local m = byId[id]
	if not m or m.dead then
		return nil
	end
	local p = m.label.Position
	return Vector2.new(p.X.Offset, p.Y.Offset)
end
exports.BODY_PX = CELL.Y * CS / 2

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
				-- 움직인 쪽을 바라본다(가로·세로 중 더 많이 움직인 쪽)
				local dx, dy = e[2] - m.tx, e[3] - m.ty
				if math.abs(dx) + math.abs(dy) > 0.05 then
					m.dir = if math.abs(dx) >= math.abs(dy) then (if dx < 0 then 2 else 3) else (if dy < 0 then 1 else 0)
				end
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
	table.insert(conns, Net.OnClient("TownMonsterHit", function(sceneKey, id, hp, damage, attacker, source)
		local m = mine(sceneKey) and byId[id]
		if not m then
			return
		end
		-- 맞은 몬스터 몸 위에 무기에 맞는 베기 VFX(town/weapon.luau). 펫 스킬("pet:<종>")은 town/petFx가 그 펫 이펙트를 그린다.
		local byPet = typeof(source) == "string" and string.sub(source, 1, 4) == "pet:"
		local byNinjutsu = typeof(source) == "string" and string.sub(source, 1, 4) == "nin:" -- 인술: town/ninjutsuFx가 그 인술 이펙트를 그린다
		local p = m.label.Position
		if not byPet and not byNinjutsu then
			weapon.HitSlash(Vector2.new(p.X.Offset, p.Y.Offset - CELL.Y * CS / 2), source)
		end
		m.hp = hp
		m.bar:SetRatio(hp / m.maxHp)
		if m.hint then
			m.hint.Visible = hp > 0 and hp / m.maxHp <= capture.HINT_HP
		end
		m.bar.Instance.Visible = true
		damageNumbers.Show(m.label, damage, if attacker ~= myId then OTHER_HIT elseif byPet then MY_PET_HIT else MY_HIT)
		flash(m)
	end))
	-- 반격: 공격하는 순간 몸을 살짝 키웠다 돌아오며 앞으로 튀어 나간다(서버가 플레이어 피해를 따로 준다)
	table.insert(conns, Net.OnClient("TownMonsterStatus", function(sceneKey, id, kind, seconds)
		local m = mine(sceneKey) and byId[id]
		local tint = STATUS_TINT[kind]
		if not m or m.dead or not tint then
			return
		end
		m.tint, m.tintUntil = tint, os.clock() + seconds
		m.label.ImageColor3 = tint
	end))
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
	table.insert(conns, Net.OnClient("ProjectileThrown", function(sceneKey, _userId, itemId, x, y, dx, dy, dist, speed, radius)
		if not mine(sceneKey) then
			return
		end
		task.spawn(playProjectile, gameFrame, itemId, x, y, dx, dy, dist, speed, radius)
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
			if m.tintUntil and os.clock() >= m.tintUntil then
				m.tintUntil = nil -- 상태 이상이 끝남
				m.label.ImageColor3 = WHITE
			end
			m.x += (m.tx - m.x) * k
			m.y += (m.ty - m.y) * k
			local label = m.label
			local lunging = m.lungeUntil and os.clock() < m.lungeUntil
			if SHEET.block then
				-- 팩 시트: frame = 방향 * 4 + 걷기 장(서 있으면 첫 장). 공격하면 바라보는 쪽으로 3도트 튀어 나간다.
				local step = if m.moving then math.floor(m.clock / WALK_FRAME_TIME) % 4 else 0
				label.ImageRectOffset = townWorld.MonsterFrameOffset(m.row, m.dir * 4 + step)
				local push = if lunging then DIR_VEC[m.dir] * 3 else Vector2.zero
				label.Position = UDim2.fromOffset(math.round((m.x + push.X) * S), math.round((m.y + push.Y) * S))
			else
				-- 옛 시트 칸: 대기R 0~3, 걷기R 4~7, 대기L 8~11, 걷기L 12~15
				local frame = if m.moving
					then math.floor(m.clock / WALK_FRAME_TIME) % 4 + 4
					else math.floor(m.clock / IDLE_FRAME_TIME) % 4
				if m.facingLeft then
					frame += 8
				end
				label.ImageRectOffset = townWorld.MonsterFrameOffset(m.row, frame)
				-- 공방 편집기와 같은 기준: 발(그림자 아래끝)이 pos보다 1도트 아래.
				local lunge = if lunging then (if m.facingLeft then -3 else 3) else 0
				label.Position = UDim2.fromOffset(math.round((m.x + lunge) * S), math.round((m.y + 1) * S))
			end
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
