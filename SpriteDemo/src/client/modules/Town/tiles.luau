-- Tile Palette 플러그인을 전혀 쓰지 않고, mapData.luau(순수 데이터) + tilesetDefs.luau
-- (스프라이트시트 정의)를 읽어서 코드에서 직접 타일 인스턴스를 만든다. 플러그인이
-- ReplicatedStorage.UpsideEngineDB에 저장했다가 로드하는 왕복 과정에서 Scale/이름/
-- CanCollide가 계속 깨지던 문제(세션 간 재현됨, 문서에도 없는 버그)를 근본적으로
-- 우회한다 — 모든 값이 이 파일과 mapData.luau에 명시적으로 코드로 존재한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))

local tilesetDefs = require(script.Parent.tilesetDefs)
local mapData = require(script.Parent.mapData)

-- 실측으로 확정된 원인: CanCollide=true 타일과 CanCollide=false 타일이 정확히 맞닿아 있으면
-- 경계에서 GJK/EPA 판정이 부동소수점 오차로 매 프레임 흔들린다(사용자가 grass-rock 경계를
-- 없앤 배치로 재현 자체가 안 되는 것까지 확인함). 코드로 직접 배치하므로 격자 사이에 이미
-- 여백을 둘 수 있지만, 방어적으로 판정 크기도 살짝 줄여둔다.
local COLLIDER_HITBOX_SCALE = 0.9

local function buildTile(entry, defaultZIndex)
	local def = tilesetDefs[entry.tileset]
	assert(def, "알 수 없는 tileset: " .. tostring(entry.tileset))
	local index = def.tiles[entry.tile]
	assert(index, string.format("tileset '%s'에 '%s' 타일이 없습니다", entry.tileset, entry.tile))

	local canCollide = entry.canCollide or false
	local object = UpsideEngine.new(canCollide and "PhysicalObject" or "StaticObject")
	object.Anchored = true
	if canCollide then
		object.CanCollide = true
		object.HitboxScale = COLLIDER_HITBOX_SCALE
	end

	local size = entry.displaySize or def.displaySize
	local instance = object.Instance
	instance.Image = def.assetId
	instance.ImageRectSize = Vector2.new(def.cellSize, def.cellSize)
	instance.ImageRectOffset = Vector2.new(index * def.cellSize, 0)
	instance.Size = UDim2.fromOffset(size, size)
	instance.Position = UDim2.fromOffset(entry.x, entry.y)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = entry.zIndex or defaultZIndex

	return object
end

local exports = {}
exports.objects = {}

function exports.load(scene: Scene)
	for _, entry in mapData.ground do
		local object = buildTile(entry, 1)
		object:SetScene(scene)
		table.insert(exports.objects, object)
	end

	for _, entry in mapData.decor do
		local object = buildTile(entry, 5)
		object:SetScene(scene)
		table.insert(exports.objects, object)
	end
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	for _, object in exports.objects do
		object.Instance:Destroy()
	end
	table.clear(exports.objects)
end

return exports
