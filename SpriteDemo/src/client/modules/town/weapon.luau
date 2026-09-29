-- 장착한 무기 + 무기 공격 VFX.
--  등 뒤 무기: 무기 그림(items.luau WorldIcon, 없으면 KitIcon → 도트 UI 키트 icon_*, 예: 칼날이 위로 곧게 선 목검)을
--    캐릭터 배율로 플레이어 등 뒤에 띄운다(살짝 둥실). 바라보는 방향(캐릭터 필드 Facing)에 따라 등 쪽으로 자리를 옮기고,
--    위를 볼 때(등이 보일 때)만 캐릭터 앞에, 나머지는 캐릭터 뒤에 그린다. 무기는 공격해도 움직이지 않는다.
--  베기 VFX(exports.HitSlash): 몬스터가 맞으면(서버 TownMonsterHit — 같은 씬 모두) 그 몬스터 위에 사선 베기가
--    한쪽 끝에서 반대쪽 끝으로 빠르게 그어졌다가 가늘어지며 사라진다. 색은 때린 무기의 Vfx(없으면 기본 흰/연노랑).
-- 온라인 공유: 내 캐릭터 필드 WeaponId(장착 무기) · Facing을 캐릭터 복제가 다른 사람에게 실어 보낸다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local items = require(ReplicatedStorage.shared.data.items)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local map = require(script.Parent.map)
local UI = require(script.Parent.Parent.ui.pixelUI)

local S = map.S
local CS = townAssets.CHAR_SCALE -- 캐릭터 1도트 = 화면 px(VFX 도트도 이 크기)
local ICON = 12 -- 아이콘 크기(도트)
local BOB = 1 -- 둥실 높이(바닥 도트)
local BOB_SPEED = 2.2
local FOLLOW = 10 -- 방향을 바꿀 때 등 뒤 자리로 옮겨 가는 빠르기
-- 등 뒤 자리(발 기준, 바닥 도트) — 바라보는 방향의 반대쪽
local BACK = {
	down = Vector2.new(5, -10),
	up = Vector2.new(3, -9),
	right = Vector2.new(-6, -9),
	left = Vector2.new(6, -9),
}

-- 베기 VFX(캐릭터 도트 단위)
local SLASH_LEN = 30
local SLASH_WIDTH = 2.5 -- 가운데 최대 두께(한쪽)
local SLASH_DRAW = 0.07 -- 그어지는 시간
local SLASH_HOLD = 0.05
local SLASH_FADE = 0.12 -- 가늘어지며 사라지는 시간
local DEFAULT_VFX = { core = Color3.fromRGB(255, 244, 190), edge = Color3.fromRGB(255, 255, 255) }

local exports = {}
local views = {} -- 캐릭터 오브젝트 -> { img, kit, offset, phase }
local slashFlip = false

local function makeImage(gameFrame: Instance, kit: string): ImageLabel
	local img = UI.Part(gameFrame, "icon_" .. kit, 0, 0, ICON * CS, ICON * CS)
	img.Name = "Weapon"
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	return img
end

-- 몬스터 위 베기: centerPx = 몬스터 몸 가운데(화면 px), weaponId = 때린 무기
function exports.HitSlash(centerPx: Vector2, weaponId: string?)
	local gameFrame = exports.gameFrame
	if not gameFrame then
		return
	end
	local def = items[weaponId or ""]
	local vfx = def and def.Vfx or DEFAULT_VFX
	slashFlip = not slashFlip -- 번갈아 / \ 방향
	local dir = Vector2.new(if slashFlip then 1 else -1, 0.8).Unit
	local side = Vector2.new(-dir.Y, dir.X)
	local c = centerPx / CS + Vector2.new(math.random(-3, 3), math.random(-3, 3)) -- 캐릭터 도트 좌표
	local holder = Instance.new("Frame")
	holder.Name = "HitSlash"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, 0)
	holder.ZIndex = 9300
	holder.Parent = gameFrame
	local dots, seen = {}, {}
	local steps = 40
	for i = 0, steps do
		local t = i / steps
		local w = SLASH_WIDTH * math.sin(math.pi * t)
		local p = c + dir * ((t - 0.5) * SLASH_LEN)
		for k = -math.ceil(w), math.ceil(w) do
			if math.abs(k) <= w + 0.3 then
				local q = p + side * k
				local gx, gy = math.round(q.X), math.round(q.Y)
				local key = gx .. "," .. gy
				if not seen[key] then
					seen[key] = true
					local f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.BackgroundColor3 = if k == 0 then vfx.edge else vfx.core
					f.Position = UDim2.fromOffset(gx * CS, gy * CS)
					f.Size = UDim2.fromOffset(CS, CS)
					f.ZIndex = 9300 + (if k == 0 then 1 else 0)
					f.Visible = false
					f.Parent = holder
					table.insert(dots, { frame = f, t = t, k = math.abs(k) })
				end
			end
		end
	end
	task.spawn(function()
		local clock = 0
		local total = SLASH_DRAW + SLASH_HOLD + SLASH_FADE
		while clock < total and holder.Parent do
			clock += task.wait()
			local drawn = math.clamp(clock / SLASH_DRAW, 0, 1) -- 한쪽 끝에서 반대쪽 끝으로 그어짐
			local fade = math.clamp((clock - SLASH_DRAW - SLASH_HOLD) / SLASH_FADE, 0, 1)
			local keep = SLASH_WIDTH * (1 - fade) -- 가늘어짐(가운데 줄이 마지막까지)
			for _, dot in dots do
				dot.frame.Visible = dot.t <= drawn and dot.k <= keep + 0.01 and fade < 1
			end
		end
		holder:Destroy()
	end)
end

local function update(v, character, dt: number, clock: number)
	local instance = character.Instance
	local def = items[character.WeaponId or ""]
	local kit = def and (def.WorldIcon or def.KitIcon)
	if not instance or not instance.Parent or not kit or kit == "" then
		if v.img then
			v.img.Visible = false
		end
		return
	end
	if v.kit ~= kit then
		if v.img then
			v.img:Destroy()
		end
		v.img = makeImage(exports.gameFrame, kit)
		v.kit = kit
	end
	v.img.Visible = true

	local facing = character.Facing or "down"
	local target = BACK[facing] or BACK.down
	v.offset = v.offset or target
	v.offset = v.offset:Lerp(target, 1 - math.exp(-FOLLOW * dt))
	local feet = Vector2.new(instance.Position.X.Offset, instance.Position.Y.Offset) / S
	local bob = math.sin(clock * BOB_SPEED + v.phase) * BOB
	v.img.Position = UDim2.fromOffset(math.round((feet.X + v.offset.X) * S), math.round((feet.Y + v.offset.Y + bob) * S))
	-- 등이 보일 때(위를 볼 때)만 캐릭터 앞, 나머지는 캐릭터 뒤
	v.img.ZIndex = instance.ZIndex + (if facing == "up" then 1 else -1)
end

function exports.load(scene: Scene)
	local d = map.Use(scene)
	if not d then
		return
	end
	exports.gameFrame = scene.Instance.GameFrame
	local hero = require(script.Parent.Parent.topDownHero)
	local inventory = require(script.Parent.Parent.globals.inventory)
	local clock = 0

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		clock += dt
		-- 내 캐릭터: 장착한 무기를 필드로(캐릭터 복제로 다른 사람에게도 간다)
		local mine = hero.hero
		if mine then
			local weaponId = inventory.getEquipment().Weapon or ""
			if mine.WeaponId ~= weaponId then
				mine.WeaponId = weaponId
			end
		end

		local seen = {}
		local function visit(character)
			if not character or seen[character] then
				return
			end
			seen[character] = true
			local v = views[character]
			if not v then
				v = { phase = math.random() * math.pi * 2 }
				views[character] = v
			end
			update(v, character, dt, clock)
		end
		visit(mine)
		local myId = mine and mine.Id
		for _, objects in NetworkingService.PlayersData do
			for _, other in objects do
				if other.Id ~= myId and other.Instance and other.Instance:IsDescendantOf(exports.gameFrame) then
					visit(other)
				end
			end
		end
		-- 사라진 캐릭터의 무기 정리
		for character, v in views do
			if not seen[character] then
				if v.img then
					v.img:Destroy()
				end
				views[character] = nil
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
	for character, v in views do
		if v.img then
			v.img:Destroy()
		end
		views[character] = nil
	end
	exports.gameFrame = nil
end

return exports
