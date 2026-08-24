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
local GRID_CELL = 96

local function buildTile(entry, defaultZIndex)
	local def = tilesetDefs[entry.tileset]
	assert(def, "알 수 없는 tileset: " .. tostring(entry.tileset))
	local index = def.tiles[entry.tile]
	assert(index, string.format("tileset '%s'에 '%s' 타일이 없습니다", entry.tileset, entry.tile))

	-- cellWidth/cellHeight가 없는 (기존) 정사각 타일셋은 cellSize로 폴백 — 바닥 타일 동작은
	-- 그대로 유지된다. 마을 소품처럼 원본 비율 그대로 쓰는 단일 이미지는 cellWidth/Height를
	-- 직접 지정한다(tilesetDefs.luau 참고).
	local cellWidth = def.cellWidth or def.cellSize
	local cellHeight = def.cellHeight or def.cellSize

	-- 바닥 타일은 격자 칸 크기와 정확히 같은 크기로 이어붙이면 소수점 반올림 때문에 타일
	-- 사이에 1px짜리 실금이 생길 수 있어서(실측 확인됨), 시각적으로는 격자 칸보다 살짝
	-- 크게(+2px) 그려서 옆 타일과 겹치게 만든다 — 겹친 부분은 같은 이미지라 티가 안 난다.
	local width = entry.displayWidth or entry.displaySize or (entry.isGround and (GRID_CELL + 2)) or def.displayWidth or def.displaySize or cellWidth
	local height = entry.displayHeight or entry.displaySize or (entry.isGround and (GRID_CELL + 2)) or def.displayHeight or def.displaySize or cellHeight

	local canCollide = entry.canCollide or false
	local object = UpsideEngine.new(canCollide and "PhysicalObject" or "StaticObject")
	object.Anchored = true
	if canCollide then
		object.CanCollide = true
		if entry.isGround then
			-- 위에서 시각적으로만 2px 키운 걸 그대로 두면 충돌 판정도 같이 커져서 옆 바닥
			-- 타일과 판정이 겹친다 — MCP로 직접 Play해서 좌우 이동이 전혀 안 되는 걸
			-- 확인하고 원인을 찾았다: 캐릭터가 타일 경계에 있을 때 양쪽 바닥의 겹친 판정에
			-- 동시에 끼어서 속도는 정상인데 위치가 전혀 안 바뀌었다. 판정 크기만 그리드
			-- 칸(96)에 정확히 맞도록 축소해서 시각적 겹침과 충돌 판정을 분리한다.
			object.HitboxScale = GRID_CELL / width
		else
			-- 장식(decor)은 CanCollide=false 이웃과 맞닿을 수 있어 경계 지터 방지용으로 줄인다.
			object.HitboxScale = COLLIDER_HITBOX_SCALE
		end
	end
	local instance = object.Instance
	instance.Image = def.assetId
	instance.ImageRectSize = Vector2.new(cellWidth, cellHeight)
	instance.ImageRectOffset = Vector2.new(index * cellWidth, 0)
	instance.Size = UDim2.fromOffset(width, height)
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
		entry.isGround = true
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
