-- 따라다니는 펫(M3) — GAME_DESIGN §5.
--  내 펫: 함께 다니기(파티)에 넣은 펫 전부가 내 발자취를 줄지어 따라온다(1번이 바로 뒤). 위치는 내 화면에서만 계산(서버로 안 보냄).
--  다른 사람 펫: 대표 펫(파티 1번) 한 마리만 보인다 — 내 캐릭터 필드 PetLead("종줄:방울등급")를 캐릭터 복제가 실어 보내고,
--   다른 사람 화면이 그 캐릭터 발자취를 따라 그린다.
--  그림: 몬스터 시트(대기 4장 · 걷기 4장, 왼쪽 보면 L 칸) 그대로 + 목에 맺은 방울(도트 UI 키트 icon_bell_<등급>).
--  펫은 맞지 않는다(전투 판정 없음). 스킬(패시브 추가타)은 M4.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local map = require(script.Parent.map)
local UI = require(script.Parent.Parent.ui.pixelUI)
local petBox = require(script.Parent.Parent.globals.petBox)

local world = map.world
local S = map.S
local CS = townAssets.MONSTER_SCALE
local SHEET = world.monsterSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local SPACING = 7 -- 발자취 점 몇 개마다 한 마리(점 = 2도트 이상 움직일 때마다)
local TRAIL_MAX = 60
local FOLLOW = 10
local IDLE_FRAME_TIME, WALK_FRAME_TIME = 0.3, 0.15

local exports = {}
local groups = {} -- 캐릭터 → { trail = { Vector2 }, pets = { view } , key = 파티 표시 문자열 }

local function makeView(gameFrame: Instance, row: number, tier: number, pos: Vector2)
	local label = Instance.new("ImageLabel")
	label.Name = "Pet"
	label.BackgroundTransparency = 1
	label.Image = townAssets.MONSTER_SHEETS[townWorld.MonsterSheet(row)]
	label.ImageRectSize = CELL
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.fromOffset(CELL.X * CS, CELL.Y * CS)
	label.Parent = gameFrame
	if tier and tier > 0 and UI.Has("icon_bell_" .. tier) then
		local bell = UI.Part(label, "icon_bell_" .. tier, CELL.X * CS / 2 + 4, CELL.Y * CS * 0.5, 10, 10)
		bell.ZIndex = 2
	end
	return { label = label, row = row, x = pos.X, y = pos.Y, clock = math.random(), facingLeft = false, moving = false }
end

local function clear(group)
	for _, v in group.pets do
		v.label:Destroy()
	end
	group.pets = {}
end

-- 이 캐릭터가 데리고 다닐 펫 목록 { { row, tier } }
local function wantedFor(character, isMine: boolean)
	local list = {}
	if isMine then
		local data = petBox.data
		for _, index in data.Party or {} do
			local pet = data.Box[index]
			local row = pet and petBox.SpeciesRow(pet.S)
			if row then
				table.insert(list, { row, pet.B or 1 })
			end
		end
	else
		local lead = character.PetLead
		if typeof(lead) == "string" and lead ~= "" then
			local row, tier = string.match(lead, "^(%d+):(%d+)$")
			if row then
				table.insert(list, { tonumber(row), tonumber(tier) })
			end
		end
	end
	return list
end

local function keyOf(list): string
	local parts = {}
	for _, p in list do
		table.insert(parts, p[1] .. ":" .. p[2])
	end
	return table.concat(parts, ",")
end

local function update(group, gameFrame: Instance, character, isMine: boolean, feet: Vector2, dt: number)
	-- 펫 구성이 바뀌었으면 다시 만든다
	local wanted = wantedFor(character, isMine)
	local key = keyOf(wanted)
	if key ~= group.key then
		clear(group)
		group.key = key
		for i, p in wanted do
			table.insert(group.pets, makeView(gameFrame, p[1], p[2], feet + Vector2.new(-6 * i, 2)))
		end
	end
	-- 발자취
	local trail = group.trail
	if #trail == 0 or (feet - trail[#trail]).Magnitude >= 2 then
		table.insert(trail, feet)
		if #trail > TRAIL_MAX then
			table.remove(trail, 1)
		end
	end
	local k = 1 - math.exp(-FOLLOW * dt)
	for i, v in group.pets do
		local target = trail[#trail - SPACING * i] or (feet + Vector2.new(-7 * i, 1))
		local dx, dy = target.X - v.x, target.Y - v.y
		v.x += dx * k
		v.y += dy * k
		v.moving = math.abs(dx) + math.abs(dy) > 0.6
		if math.abs(dx) > 0.3 then
			v.facingLeft = dx < 0
		end
		v.clock += dt
		local frame = if v.moving
			then math.floor(v.clock / WALK_FRAME_TIME) % 4 + 4
			else math.floor(v.clock / IDLE_FRAME_TIME) % 4
		if v.facingLeft then
			frame += 8
		end
		v.label.ImageRectOffset = townWorld.MonsterFrameOffset(v.row, frame)
		v.label.Position = UDim2.fromOffset(math.round(v.x * S), math.round((v.y + 1) * S))
		v.label.ZIndex = map.ZIndexFor(v.y)
	end
end

function exports.load(scene: Scene)
	local d = map.Use(scene)
	if not d then
		return
	end
	local gameFrame = scene.Instance.GameFrame
	local heroModule = require(script.Parent.Parent.topDownHero)

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local seen = {}
		local mine = heroModule.hero
		-- 내 대표 펫을 캐릭터 필드로(다른 사람 화면에 보이게)
		if mine then
			local lead = ""
			local index = petBox.data.Party and petBox.data.Party[1]
			local pet = index and petBox.data.Box[index]
			local row = pet and petBox.SpeciesRow(pet.S)
			if row then
				lead = ("%d:%d"):format(row, pet.B or 1)
			end
			if mine.PetLead ~= lead then
				mine.PetLead = lead
			end
			if heroModule.pos then
				seen[mine] = true
				groups[mine] = groups[mine] or { trail = {}, pets = {} }
				update(groups[mine], gameFrame, mine, true, heroModule.pos, dt)
			end
		end
		local myId = mine and mine.Id
		for _, objects in NetworkingService.PlayersData do
			for _, other in objects do
				local instance = other.Instance
				if other.Id ~= myId and instance and instance:IsDescendantOf(gameFrame) then
					seen[other] = true
					groups[other] = groups[other] or { trail = {}, pets = {} }
					local feet = Vector2.new(instance.Position.X.Offset, instance.Position.Y.Offset) / S
					update(groups[other], gameFrame, other, false, feet, dt)
				end
			end
		end
		for character, group in groups do
			if not seen[character] then
				clear(group)
				groups[character] = nil
			end
		end
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	for _, group in groups do
		clear(group)
	end
	table.clear(groups)
end

return exports
