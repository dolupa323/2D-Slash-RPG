-- 탑다운 만두 마을 그리기 + 이동 판정 공용 함수.
-- 바닥은 이미지 한 장(오브젝트 그림자까지 구워져 있음), 오브젝트는 아틀라스에서 잘라 쓴다.
-- 화면 좌표 = 도트 좌표 × SCALE. 위아래 겹침은 "발 높이(y)가 클수록 앞"으로 ZIndex를 준다
-- (히어로·몬스터·다른 플레이어도 같은 규칙: exports.ZIndexFor).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local townMap = require(ReplicatedStorage.shared.data["townMap.generated"])
local townAssets = require(ReplicatedStorage.shared.config.townAssets)

local S = townAssets.SCALE
local T = townMap.tile
local Z_BASE = 100

local exports = {}
exports.S = S
exports.data = townMap

function exports.ZIndexFor(footY: number): number
	return Z_BASE + math.floor(footY)
end

-- 이 도트 좌표(칸 단위가 아니라 도트)가 걸어갈 수 있는 곳인가 — 맵 밖, 물·덤불, 오브젝트 발판은 막힘.
function exports.IsBlocked(x: number, y: number): boolean
	if x < 0 or y < 0 or x >= townMap.w * T or y >= townMap.h * T then
		return true
	end
	local row = townMap.blocked[math.floor(y / T) + 1]
	local col = math.floor(x / T) + 1
	return row:sub(col, col) == "1"
end

-- 발 상자(가운데 아래 기준, 폭 2*halfW, 높이 h)가 막힌 칸에 걸리는가.
function exports.BoxBlocked(x: number, y: number, halfW: number, h: number): boolean
	return exports.IsBlocked(x - halfW, y - h)
		or exports.IsBlocked(x + halfW, y - h)
		or exports.IsBlocked(x - halfW, y - 0.01)
		or exports.IsBlocked(x + halfW, y - 0.01)
end

local function makeImage(parent: Instance, name: string, image: string): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.Image = image
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ScaleType = Enum.ScaleType.Stretch
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Parent = parent
	return label
end

function exports.load(scene: Scene)
	local gameFrame = scene.Instance.GameFrame
	-- 맵 바깥(카메라가 가장자리에 가면 보이는 곳)은 잔디색으로 채운다.
	local outside = Instance.new("Frame")
	outside.Name = "Outside"
	outside.BackgroundColor3 = Color3.fromRGB(191, 230, 164)
	outside.BorderSizePixel = 0
	outside.Position = UDim2.fromOffset(-2000, -2000)
	outside.Size = UDim2.fromOffset(townMap.ground.w * S + 4000, townMap.ground.h * S + 4000)
	outside.ZIndex = 0
	outside.Parent = gameFrame
	exports.outside = outside

	local ground = makeImage(gameFrame, "Ground", townAssets.GROUND)
	ground.Position = UDim2.fromOffset(0, 0)
	ground.Size = UDim2.fromOffset(townMap.ground.w * S, townMap.ground.h * S)
	ground.ZIndex = 1
	exports.ground = ground

	local objects = {}
	for i, o in townMap.objects do
		local rect = townMap.rects[o.id]
		local label = makeImage(gameFrame, "Obj_" .. o.id .. "_" .. i, townAssets.OBJECTS)
		label.ImageRectOffset = Vector2.new(rect.x, rect.y)
		label.ImageRectSize = Vector2.new(rect.w, rect.h)
		label.Position = UDim2.fromOffset(o.x * S, o.y * S)
		label.Size = UDim2.fromOffset(rect.w * S, rect.h * S)
		label.ZIndex = exports.ZIndexFor(o.bottom)
		table.insert(objects, label)
	end
	exports.objects = objects
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	for _, key in { "outside", "ground" } do
		if exports[key] then
			exports[key]:Destroy()
			exports[key] = nil
		end
	end
	for _, label in exports.objects or {} do
		label:Destroy()
	end
	exports.objects = nil
end

-- 씬 로딩 화면이 미리 받을 이미지 목록.
function exports.GetImages(): { string }
	return { townAssets.GROUND, townAssets.OBJECTS, townAssets.MONSTERS, townAssets.PLAYER }
end

return exports
