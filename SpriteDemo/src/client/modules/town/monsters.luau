-- 탑다운 씬의 몬스터 — 서버 권위(server/modules/townMonsters.luau)가 만들고 움직이는 몬스터를 그대로 그린다(온라인 공유).
--  씬에 들어오면 GetTownState로 지금 목록을 받고, 이후 같은 씬 사람 모두가 같은 이벤트를 받는다:
--   TownMonsterMoves(10Hz 위치 — 부드럽게 따라감) / TownMonsterHit(체력·데미지) / TownMonsterDied / TownMonsterSpawned.
--  머리 위: "Lv.N" + 체력 게이지(한 대라도 맞으면 보임 — 다른 사람이 때린 것도 보인다).
--  데미지 숫자는 내가 때린 건 노랑, 다른 사람이 때린 건 흰색. 맞으면 몸 위에 때린 무기에 맞는 베기 VFX(town/weapon.luau).
-- 공격은 topDownHero가 판정 프레임에 TownAttack(바라보는 방향)만 보내고, 판정·경험치·도감은 전부 서버가 한다.
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
	local m = { id = w.id, label = label, level = level, bar = bar, clock = math.random() }
	byId[w.id] = m
	return m
end

local function apply(m, w)
	m.row = w.row
	m.label.Image = townAssets.MONSTER_SHEETS[townWorld.MonsterSheet(w.row)]
	m.x, m.y, m.tx, m.ty = w.x, w.y, w.x, w.y
	m.hp, m.maxHp = w.hp, w.maxHp
	m.moving, m.dead = false, false
	m.level:SetText("Lv." .. w.level)
	m.level.Frame.Position = UDim2.fromOffset(20 - m.level.Width // 2, 0)
	m.bar:SetRatio(m.hp / m.maxHp)
	m.bar.Instance.Visible = m.hp < m.maxHp
	m.label.ImageTransparency = 0
	m.label.Visible = true
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
		m.bar.Instance.Visible = true
		damageNumbers.Show(m.label, damage, if attacker == myId then MY_HIT else OTHER_HIT)
		flash(m.label)
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
			if m.dead then
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
			label.Position = UDim2.fromOffset(math.round(m.x * S), math.round((m.y + 1) * S))
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
