-- 탑다운 도트 아이(플레이어) — 2026-09-28 게임 전체 탑다운 전환.
-- 예전 횡스크롤 구현(heroController.luau)은 지우지 않고 남겨뒀다(현재 미사용).
--
-- 그림: 에셋 공방의 도트 아이(townAssets.PLAYER, 셀 16x24, 줄=아래·위·왼·오, 칸=서기·걸음1·걸음2).
-- 이동: 엔진 물리(중력·충돌 클램프)는 쓰지 않는다(Anchored=true). 키 입력은 엔진
-- CrossPlatformService 이벤트(키보드 WASD/화살표, 모바일 방향 패드, 게임패드 전부 같은 액션)를
-- 받고, 위치는 여기서 직접 계산해서 town/map.luau의 막힌 칸(물·덤불·오브젝트 발판)에 걸리게 한다.
-- 축별로 따로 움직여서 벽에 비스듬히 부딪혀도 미끄러지듯 따라간다.
-- 겹침: 발 높이가 클수록 앞(map.ZIndexFor) — 나무/집 뒤로 돌아가면 가려진다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local map = require(script.Parent.town.map)

local S = map.S
local CS = townAssets.CHAR_SCALE -- 그림 크기 배율(위치는 맵 배율 S)
local SHEET = map.data.playerSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local DIR_ROW = { down = 0, up = 1, left = 2, right = 3 }
local WALK_SEQUENCE = { 2, 1, 3, 1 } -- 걸음1 → 서기 → 걸음2 → 서기
local WALK_FRAME_TIME = 0.13
local SPEED = 64 -- 도트/초
local FEET_HALF_W = 4 -- 발 상자(도트): 폭 8, 높이 4 — 머리는 건물 앞 공간에 겹쳐도 되고 발만 막는다.
local FEET_H = 4

local exports = {}

local function applyFrame(instance: ImageLabel, dir: string, col: number)
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.new((col - 1) * CELL.X, DIR_ROW[dir] * CELL.Y)
end

function exports.load(scene: Scene)
	if exports.replicationConnection then
		exports.replicationConnection:Disconnect()
		exports.replicationConnection = nil
	end
	if exports.hero then
		exports.hero:Destroy()
		exports.hero = nil
	end

	local spawn = map.data.spawn
	exports.pos = Vector2.new(spawn.x, spawn.y)

	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)
	hero.Anchored = true
	hero.GravityScale = 0
	hero.SkipCharacterCollisions = true
	hero.WalkSpeed = 0

	local instance = hero.Instance
	instance.AnchorPoint = Vector2.new(0.5, 1)
	instance.ScaleType = Enum.ScaleType.Stretch
	instance.ResampleMode = Enum.ResamplerMode.Pixelated
	instance.Image = townAssets.PLAYER
	instance.Size = UDim2.fromOffset(CELL.X * CS, CELL.Y * CS)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.Position = UDim2.fromOffset(exports.pos.X * S, exports.pos.Y * S)
	instance.ZIndex = map.ZIndexFor(exports.pos.Y)
	applyFrame(instance, "down", 1)

	CrossPlatformService.SideView = false
	-- 엔진 기본 이동/애니메이션은 끄고 아래 Heartbeat에서 직접 처리한다.
	CrossPlatformService.DefaultControllersEnabled = false
	CrossPlatformService:SetPlayerCharacter(hero)

	-- 다른 플레이어에게 내 위치·프레임을 복제(서버 replication.luau가 승인해서 브로드캐스트).
	exports.replicationConnection = NetworkingService:ReplicateOnChange(hero)
	exports.hero = hero
end

function exports.start(scene: Scene)
	local hero = exports.hero
	if not hero then
		return
	end

	local held = { up = false, down = false, left = false, right = false }
	exports.inputBeginConnection = CrossPlatformService:On("InputBegin", function(input)
		local action = input.Action and input.Action:lower()
		if action and held[action] ~= nil then
			held[action] = true
		end
	end)
	exports.inputEndConnection = CrossPlatformService:On("InputEnd", function(input)
		local action = input.Action and input.Action:lower()
		if action and held[action] ~= nil then
			held[action] = false
		end
	end)

	task.spawn(function()
		ContentProvider:PreloadAsync({ townAssets.PLAYER })
		exports.animationReady = true
	end)

	local facing = "down"
	local walkClock = 0
	exports.connection = RunService.Heartbeat:Connect(function(dt)
		local instance = hero.Instance
		if not instance then
			return
		end

		local move = Vector2.new((held.right and 1 or 0) - (held.left and 1 or 0), (held.down and 1 or 0) - (held.up and 1 or 0))
		local moving = move.Magnitude > 0
		if moving then
			-- 방향: 방금 누른 축보다 "가로가 있으면 가로"를 우선(대각선 이동 때 옆모습).
			if move.X ~= 0 then
				facing = if move.X < 0 then "left" else "right"
			else
				facing = if move.Y < 0 then "up" else "down"
			end

			local step = move.Unit * SPEED * math.min(dt, 0.1)
			local pos = exports.pos
			local nx = pos.X + step.X
			if not map.BoxBlocked(nx, pos.Y, FEET_HALF_W, FEET_H) then
				pos = Vector2.new(nx, pos.Y)
			end
			local ny = pos.Y + step.Y
			if not map.BoxBlocked(pos.X, ny, FEET_HALF_W, FEET_H) then
				pos = Vector2.new(pos.X, ny)
			end
			exports.pos = pos

			walkClock += dt
			local index = math.floor(walkClock / WALK_FRAME_TIME) % #WALK_SEQUENCE + 1
			applyFrame(instance, facing, WALK_SEQUENCE[index])
		else
			walkClock = 0
			applyFrame(instance, facing, 1)
		end

		instance.Position = UDim2.fromOffset(math.round(exports.pos.X * S), math.round(exports.pos.Y * S))
		instance.ZIndex = map.ZIndexFor(exports.pos.Y)
		-- 엔진 자동 애니메이션이 IsPlaying을 켜면 프레임(ImageRectOffset)이 복제에서 빠진다(예전 heroController 이력) — 매 프레임 끈다.
		hero.IsPlaying = false

		-- 다른 플레이어 사본도 도트가 번지지 않게, 발 높이로 겹침 순서를 맞춘다.
		local mine = hero.Id
		for _, objects in NetworkingService.PlayersData do
			for _, other in objects do
				local otherInstance = other.Instance
				if other.Id ~= mine and otherInstance and otherInstance.Parent then
					otherInstance.ResampleMode = Enum.ResamplerMode.Pixelated
					otherInstance.ZIndex = map.ZIndexFor(otherInstance.Position.Y.Offset / S)
				end
			end
		end
	end)
end

function exports.unload(scene: Scene)
	for _, key in { "connection", "inputBeginConnection", "inputEndConnection", "replicationConnection" } do
		if exports[key] then
			exports[key]:Disconnect()
			exports[key] = nil
		end
	end
	if exports.hero then
		exports.hero:Destroy()
		exports.hero = nil
	end
	exports.animationReady = false
end

return exports
