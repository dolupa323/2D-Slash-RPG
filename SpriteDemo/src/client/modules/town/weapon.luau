-- 장착한 무기 + 맞음 이펙트.
--  등 뒤 무기: 무기 그림(팩 아이템 아이콘 — items KitIcon)을 캐릭터 배율로 플레이어 등 뒤에 띄운다(살짝 둥실).
--    바라보는 방향(캐릭터 필드 Facing)에 따라 등 쪽으로 자리를 옮기고, 위를 볼 때(등이 보일 때)만 캐릭터 앞에, 나머지는 캐릭터 뒤에 그린다.
--  맞음 이펙트(exports.HitSlash): 몬스터가 맞으면(서버 TownMonsterHit — 같은 씬 모두) 그 몬스터 위에 팩 FX/Attack 이펙트.
-- 온라인 공유: 내 캐릭터 필드 WeaponId(장착 무기) · Facing을 캐릭터 복제가 다른 사람에게 실어 보낸다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local items = require(ReplicatedStorage.shared.data.items)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local map = require(script.Parent.map)
local UI = require(script.Parent.Parent.ui.pixelUI)
local packFx = require(script.Parent.Parent.packFx)
local weapons = require(ReplicatedStorage.shared.config.weapons)

local S = map.S
local CS = 2 -- 무기 그림·베기 VFX 1도트 = 화면 2px로 고정(팩 캐릭터는 배율 4지만 무기·이펙트 그림은 옛 크기 그대로 — townAssets.CHAR_SCALE를 쓰지 않는다)
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

local exports = {}
local views = {} -- 캐릭터 오브젝트 -> { img, kit, offset, phase }
local slashFlip = false

local function makeImage(gameFrame: Instance, kit: string): ImageLabel
	-- 그림 자기 크기 그대로(착용 나무 검 16x16, 아이콘 12x12). 팩 무기(nj_*)는 팩 캐릭터와 같은 배율로 그린다.
	local scale = if string.sub(kit, 1, 3) == "nj_" then townAssets.CHAR_SCALE else CS
	local size = UI.Size("icon_" .. kit) * scale
	local img = UI.Part(gameFrame, "icon_" .. kit, 0, 0, size.X, size.Y)
	img.Name = "Weapon"
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	return img
end

-- 맞은 몬스터 위 이펙트: centerPx = 몬스터 몸 가운데(화면 px), source = 때린 무기(또는 투척 무기) 아이템 id.
--  무기 종류마다 다른 팩 이펙트(weapons.luau hitFx — 도검 = 휘어 베기, 쌍수 = 두 번 긋기, 대형 = X자, 장병기 = 찌르기, 채찍 = 둥글게, 맨손 = 할퀴기).
function exports.HitSlash(centerPx: Vector2, source: string?)
	local def = items[source or ""]
	local name = if def and def.Throw then weapons.THROW_HIT_FX else weapons.ClassOf(def).hitFx
	slashFlip = not slashFlip -- 번갈아 좌우를 뒤집어 단조롭지 않게
	local at = centerPx + Vector2.new(math.random(-3, 3), math.random(-3, 3))
	packFx.Play(exports.gameFrame, name, function()
		return at
	end, { rotation = if slashFlip then 0 else 180, zIndex = 9300 })
end

local function update(v, character, dt: number, clock: number)
	local instance = character.Instance
	local def = items[character.WeaponId or ""]
	-- 착용 모습(WorldIcon)이 키트에 아직 없으면(도트 UI 키트 재업로드 전) 아이콘으로 대신한다
	local kit = def and (if def.WorldIcon and UI.Has("icon_" .. def.WorldIcon) then def.WorldIcon else def.KitIcon)
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
