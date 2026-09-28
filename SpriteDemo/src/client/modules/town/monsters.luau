-- 탑다운 만두 마을의 몬스터들 — 공방 맵(townMap.generated)의 위치에서 시작해 근처를 느릿느릿
-- 돌아다닌다(울타리 몬스터는 울타리 안에서만). 공방 편집기의 "몬스터 움직임"과 같은 규칙.
-- (1단계) 각 클라이언트가 로컬로만 움직이는 장식용이다 — 플레이어마다 몬스터 위치가 조금씩 다를 수 있다.
-- 잡기/전투 같은 게임 규칙이 생기면 서버 권위(server/services)로 옮긴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local map = require(script.Parent.map)

local S = map.S
local CS = townAssets.CHAR_SCALE -- 그림 크기 배율(위치는 맵 배율 S)
local SHEET = map.data.monsterSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local IDLE_FRAME_TIME = 0.3
local WALK_FRAME_TIME = 0.15
local SPEED = 14 -- 도트/초
local WANDER_RADIUS = 40

local exports = {}

local function pickTarget(m, rng: Random)
	for _ = 1, 8 do
		local tx = m.home.X + rng:NextNumber(-WANDER_RADIUS, WANDER_RADIUS)
		local ty = m.home.Y + rng:NextNumber(-WANDER_RADIUS, WANDER_RADIUS)
		if m.pen then
			tx = math.clamp(tx, m.pen.x0 + 6, m.pen.x1 - 6)
			ty = math.clamp(ty, m.pen.y0 + 6, m.pen.y1 - 2)
		end
		if not map.BoxBlocked(tx, ty, 5, 3) then
			return Vector2.new(tx, ty)
		end
	end
	return nil
end

function exports.load(scene: Scene)
	local gameFrame = scene.Instance.GameFrame
	local rng = Random.new(map.data.w * 1000 + map.data.h)
	local list = {}
	for i, d in map.data.mons do
		local label = Instance.new("ImageLabel")
		label.Name = "Mon_" .. map.data.species[d.species].id .. "_" .. i
		label.Image = townAssets.MONSTERS
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.ScaleType = Enum.ScaleType.Stretch
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Size = UDim2.fromOffset(CELL.X * CS, CELL.Y * CS)
		label.ImageRectSize = CELL
		label.Parent = gameFrame
		table.insert(list, {
			label = label,
			row = d.species - 1,
			pos = Vector2.new(d.x, d.y),
			home = Vector2.new(d.x, d.y),
			pen = if d.pen > 0 then map.data.pens[d.pen] else nil,
			target = nil,
			wait = rng:NextNumber(0, 3),
			facingLeft = rng:NextNumber() < 0.5,
			clock = rng:NextNumber(0, 1),
		})
	end
	exports.list = list

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for _, m in list do
			m.clock += dt
			local walking = false
			if m.target then
				local delta = m.target - m.pos
				local dist = delta.Magnitude
				if dist < 1 then
					m.target = nil
					m.wait = rng:NextNumber(1.5, 5)
				else
					local nextPos = m.pos + delta.Unit * math.min(dist, SPEED * dt)
					if map.BoxBlocked(nextPos.X, nextPos.Y, 5, 3) then
						m.target = nil
						m.wait = rng:NextNumber(0.5, 2)
					else
						m.pos = nextPos
						m.facingLeft = delta.X < 0
						walking = true
					end
				end
			else
				m.wait -= dt
				if m.wait <= 0 then
					m.target = pickTarget(m, rng)
					if not m.target then
						m.wait = rng:NextNumber(1, 3)
					end
				end
			end

			-- 시트 칸: 대기R 0~3, 걷기R 4~7, 대기L 8~11, 걷기L 12~15
			local frame = if walking
				then math.floor(m.clock / WALK_FRAME_TIME) % 4 + 4
				else math.floor(m.clock / IDLE_FRAME_TIME) % 4
			if m.facingLeft then
				frame += 8
			end
			local label = m.label
			label.ImageRectOffset = Vector2.new(frame * CELL.X, m.row * CELL.Y)
			-- 공방 렌더러와 같은 기준: 발(그림자 아래끝)이 pos보다 1도트 아래.
			label.Position = UDim2.fromOffset(math.round(m.pos.X * S), math.round((m.pos.Y + 1) * S))
			label.ZIndex = map.ZIndexFor(m.pos.Y)
		end
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	for _, m in exports.list or {} do
		m.label:Destroy()
	end
	exports.list = nil
end

return exports
