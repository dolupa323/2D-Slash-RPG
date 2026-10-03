-- 탑다운 씬 그리기 + 이동 판정 공용 함수. 공방에서 만든 씬 여러 개를 전부 이 모듈 하나가 그린다
-- (씬이 켜질 때 load(scene)에서 그 씬 데이터로 바꿔 끼운다).
-- 바닥은 씬마다 이미지 한 장(오브젝트 그림자까지 구워져 있음), 오브젝트는 공용 아틀라스에서 잘라 쓴다.
-- 화면 좌표 = 도트 좌표 × S. 위아래 겹침은 "발 높이(y)가 클수록 앞"(ZIndexFor) — 히어로·몬스터·다른 플레이어도 같은 규칙.
-- 크기·충돌 규칙은 공방 js/world.js에서 내보낸 그대로다(여기서 따로 고치지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)

local world = townWorld.data
local S = world.scale
local T = world.tile
local FINE = world.fine
local Z_BASE = 100

local exports = {}
exports.S = S
exports.world = world
exports.key = nil -- 지금 켜진 씬 키
exports.data = nil -- 지금 켜진 씬 데이터

function exports.ZIndexFor(footY: number): number
	return Z_BASE + math.floor(footY)
end

-- 이 도트 좌표가 막혔는가 — 맵 밖, 충돌 격자(물·덤불·충돌 O 오브젝트·충돌 칸)는 막힘.
function exports.IsBlocked(x: number, y: number): boolean
	local d = exports.data
	if not d or x < 0 or y < 0 or x >= d.w * T or y >= d.h * T then
		return true
	end
	local row = d.blocked[math.floor(y / FINE) + 1]
	local col = math.floor(x / FINE) + 1
	return row:sub(col, col) == "1"
end

-- 발 상자(가운데 아래 기준, 폭 2*halfW, 높이 h)가 막힌 곳에 걸리는가.
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

-- 이 씬의 데이터로 바꿔 끼운다. 씬 모듈(map/monsters/hero)의 load 순서가 정해져 있지 않아서
-- 누가 먼저 불려도 되게 각자 이걸 먼저 부른다(여러 번 불러도 같다).
function exports.Use(scene: Scene)
	local key = townWorld.KeyOf(scene.Name)
	local d = key and townWorld.Get(key)
	if not d then
		warn(("town/map: %s 씬 데이터가 없습니다"):format(scene.Name))
		return nil
	end
	exports.key = key
	exports.data = d
	return d
end

function exports.load(scene: Scene)
	local d = exports.Use(scene)
	if not d then
		return
	end
	local key = exports.key
	local gameFrame = scene.Instance.GameFrame

	-- 맵 바깥(카메라가 가장자리에 가면 보이는 곳)은 잔디색으로, 실내 씬은 벽 윗면 색으로 채운다.
	local outside = Instance.new("Frame")
	outside.Name = "Outside"
	outside.BackgroundColor3 = if d.indoor then Color3.fromRGB(122, 101, 136) else Color3.fromRGB(191, 230, 164)
	outside.BorderSizePixel = 0
	outside.Position = UDim2.fromOffset(-2000, -2000)
	outside.Size = UDim2.fromOffset(d.ground.w * S + 4000, d.ground.h * S + 4000)
	outside.ZIndex = 0
	outside.Parent = gameFrame
	exports.outside = outside

	local ground = makeImage(gameFrame, "Ground", townAssets.GROUNDS[key])
	ground.Position = UDim2.fromOffset(0, 0)
	ground.Size = UDim2.fromOffset(d.ground.w * S, d.ground.h * S)
	ground.ZIndex = 1
	exports.ground = ground

	local objects = {}
	for i, o in d.objects do
		local rect = world.rects[o.id]
		local label = makeImage(gameFrame, "Obj_" .. o.id .. "_" .. i, townAssets.OBJECTS)
		label.ImageRectOffset = Vector2.new(rect.x, rect.y)
		label.ImageRectSize = Vector2.new(rect.w, rect.h)
		-- 발판 기준(아래 가운데)은 바닥 배율 S, 그림 크기는 오브젝트별 배율(o.scale) — 충돌·그림자도 같은 배율.
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.fromOffset((o.x + rect.w / 2) * S, o.bottom * S)
		label.Size = UDim2.fromOffset(rect.w * o.scale, rect.h * o.scale)
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

return exports
