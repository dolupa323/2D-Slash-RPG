-- Client-side initialization script for the Upside Engine based 2D Game.
-- 탑다운(top-down) 시점으로 전환: 중력 없음, 4방향(상/하/좌/우) 자유 이동, 점프 없음.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.packages

-- Load Upside Engine
local UpsideEngine = require(packages.UpsideEngine)
local crossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local networkingService = UpsideEngine.GetService("NetworkingService")
local sceneManager = UpsideEngine.GetService("SceneManager")
local pluginSupportService = UpsideEngine.GetService("PluginSupportService")

local localPlayer = game:GetService("Players").LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

print("Initializing Upside Engine Client (Top-Down)...")

-- 공식 "Plugin Scripts" 가이드(tutorials/plugin-guide/PluginScripts.html) 순서:
-- LoadPluginContent → FindByName → (캐릭터 준비) → SetPlayerCharacter/SetSubject → Enable → Parent
pluginSupportService:LoadPluginContent()

local clientScene = sceneManager:FindByName("ForestGround")
assert(clientScene, "ForestGround scene not found — Tilemap Editor에서 씬이 저장되었는지 확인하세요")
clientScene.OnlyTrackVisible = false
clientScene.Gravity = Vector2.zero -- 탑다운은 중력이 없다 (Physics.luau: sideView 여부와 무관하게 매 프레임 Gravity가 가속도에 더해짐)

-- ReplicatedStorage.UpsideEngineDB 저장 스냅샷 + 플러그인 프리뷰 잔재 때문에 두 가지 문제가
-- 반복적으로 발생한다: (1) 예전 횡스크롤 타일(ForestTileset48)이 계속 되살아남, (2) 같은
-- place_tiles 호출이 누적되며 타일이 중복 생성됨. scene.Objects(엔진 등록 목록)뿐 아니라
-- GameFrame 밑 raw Instance까지 전부 훑어서, 등록된 건 object:Destroy()(등록 해제까지 처리),
-- 미등록 유령 Instance는 raw Instance:Destroy()로 제거한다.
do
	local LEGACY_TILE_IMAGES = {
		["rbxassetid://121002521524084"] = true, -- ForestTileset48 (횡스크롤용, 폐기)
	}
	local gameFrame = clientScene.Instance:FindFirstChild("GameFrame")
	if gameFrame then
		local instanceToObject = {}
		for _, object in clientScene.Objects do
			if object.Instance then
				instanceToObject[object.Instance] = object
			end
		end

		local function destroyTile(inst)
			local obj = instanceToObject[inst]
			if obj then
				obj:Destroy()
			else
				inst:Destroy()
			end
		end

		-- 마을 설계 범위(TopdownVillage48 144px 그리드, x:-720~720 y:-576~576) 밖에 있는
		-- TopdownVillage48 타일은 전부 예전 세대(288px 그리드 등)의 유령 잔재다. 플러그인이
		-- ReplicatedStorage 저장 스냅샷을 계속 되살려서(Edit 모드에서 지워도, DB를 직접 지워도
		-- 재현됨) 근본 차단이 안 되므로, 범위 밖이면 무조건 제거하는 안전장치를 둔다.
		local TOWN_BOUNDS = { minX = -750, maxX = 750, minY = -600, maxY = 600 }
		local TOPDOWN_TILE_IMAGE_FOR_BOUNDS = "rbxassetid://137290334262963"

		local seen = {}
		local removedLegacy, removedDup, removedOOB = 0, 0, 0
		for _, inst in ipairs(gameFrame:GetChildren()) do
			if inst:IsA("ImageLabel") then
				local img = tostring(inst.Image)
				if LEGACY_TILE_IMAGES[img] then
					destroyTile(inst)
					removedLegacy += 1
				elseif img == TOPDOWN_TILE_IMAGE_FOR_BOUNDS
					and (inst.Position.X.Offset < TOWN_BOUNDS.minX or inst.Position.X.Offset > TOWN_BOUNDS.maxX
						or inst.Position.Y.Offset < TOWN_BOUNDS.minY or inst.Position.Y.Offset > TOWN_BOUNDS.maxY) then
					destroyTile(inst)
					removedOOB += 1
				else
					local key = img .. ":" .. tostring(inst.Position)
					if seen[key] then
						destroyTile(inst)
						removedDup += 1
					else
						seen[key] = true
					end
				end
			end
		end
		if removedLegacy > 0 or removedDup > 0 or removedOOB > 0 then
			warn(string.format("Cleaned up tiles: %d legacy, %d duplicate, %d out-of-bounds", removedLegacy, removedDup, removedOOB))
		end

		-- Tilemap Editor 플러그인/place_tiles가 타일 크기를 세션마다 다르게(288/48/1728 등)
		-- 캐싱해서 굽는 문제가 있어(TileSize·Scale 설정을 여러 번 정확히 맞춰도 재현됨),
		-- TopdownVillage48 타일은 실제 위치(Position, AnchorPoint 0.5,0.5라 크기 조정해도
		-- 안 밀림)는 항상 정확하므로 크기만 여기서 강제로 144x144로 통일한다.
		-- (도트게임 비율에 맞게 288→144로 축소. 타일 그리드 배치 간격도 144로 맞춰야 함.)
		local TOPDOWN_TILE_IMAGE = "rbxassetid://137290334262963"
		local TOPDOWN_TILE_SIZE = UDim2.fromOffset(144, 144)
		local TOPDOWN_RECT_SIZE = Vector2.new(48, 48) -- 타일셋 원본 셀 크기(48x48). ImageRectSize도
		-- 같은 캐싱 버그로 8x8/24x24/48x48이 뒤섞여 저장돼있어(정상은 48x48뿐), 절반만 잘린 크롭이
		-- 늘어나 보이는 문제(바위가 반원으로 보이는 등)의 원인이었다. 크기와 함께 강제 통일한다.
		local fixedSize, fixedRect = 0, 0
		for _, inst in ipairs(gameFrame:GetChildren()) do
			if inst:IsA("ImageLabel") and tostring(inst.Image) == TOPDOWN_TILE_IMAGE then
				if inst.Size ~= TOPDOWN_TILE_SIZE then
					inst.Size = TOPDOWN_TILE_SIZE
					fixedSize += 1
				end
				if inst.ImageRectSize ~= TOPDOWN_RECT_SIZE then
					inst.ImageRectSize = TOPDOWN_RECT_SIZE
					fixedRect += 1
				end
			end
		end
		if fixedRect > 0 then
			warn(string.format("Force-corrected %d tile(s) ImageRectSize to 48x48 (plugin crop caching bug)", fixedRect))
		end
		if fixedSize > 0 then
			warn(string.format("Force-corrected %d tile(s) to 144x144 (plugin size caching bug)", fixedSize))
		end

		-- place_tiles가 오브젝트 ID를 재사용하면서 CanCollide 플래그가 예전 세대(Wall/Tree 등)
		-- 값 그대로 남는 버그가 있어(이미지/좌표는 새 타일로 맞게 갱신되는데 CanCollide만 stale),
		-- 잔디/길 타일이 충돌 판정을 갖고 있어 캐릭터가 안 보이는 벽에 막히는 원인이 됐다.
		-- ImageRectOffset(타일 종류의 유일하게 신뢰 가능한 값)을 기준으로 CanCollide를 강제 재계산한다.
		local fixedCollide = 0
		for _, object in clientScene.Objects do
			if object.Instance and object.Instance:IsA("ImageLabel") and tostring(object.Instance.Image) == TOPDOWN_TILE_IMAGE then
				local offsetX = object.Instance.ImageRectOffset.X
				local shouldCollide = (offsetX == 96 or offsetX == 144) -- Tree=96, Rock=144 / Grass=0, Path=48
				if object.CanCollide ~= shouldCollide then
					object.CanCollide = shouldCollide
					fixedCollide += 1
				end
			end
		end
		if fixedCollide > 0 then
			warn(string.format("Force-corrected %d tile(s) CanCollide flag (plugin ID-reuse bug)", fixedCollide))
		end
	end
end

-- hero2_topdown (sprite-gen) 4방향 idle + walk, 4x1 투명 스트립
local IDLE_DOWN  = "rbxassetid://129109122585098"
local IDLE_UP    = "rbxassetid://99515823518400"
local IDLE_LEFT  = "rbxassetid://121785879926631"
local IDLE_RIGHT = "rbxassetid://101916963029894"
local WALK_DOWN  = "rbxassetid://81811293830731"
local WALK_UP    = "rbxassetid://133393514503980"
local WALK_LEFT  = "rbxassetid://91501355997148"
local WALK_RIGHT = "rbxassetid://97282194751054"

-- Create the local player's 2D Character
local character = UpsideEngine.new("Character")
character:SetScene(clientScene)
character:Load(IDLE_DOWN)
character.SecondsPerFrame = 0.125
local SPAWN_POSITION = UDim2.fromOffset(0, 0)
character.Instance.Position = SPAWN_POSITION
character.Instance.Size = UDim2.fromOffset(200, 200)
character.Instance.ImageRectSize = Vector2.new(256, 256)
character.Instance.BackgroundTransparency = 1
character.Instance.BorderSizePixel = 0
character.Instance.ZIndex = 10
character.Mass = 50
character.WalkSpeed = 90

-- 엔진 기본 컨트롤러(CrossPlatformTracker.luau)가 요구하는 정확한 이름:
--   이동 중: "up" / "down" / "left" / "right"
--   정지 시: "idle_up" / "idle_down" / "idle_left" / "idle_right" (기본값은 idle_down)
character:SetSpriteSheet("idle_down",  IDLE_DOWN, Vector2.new(4, 1))
character:SetSpriteSheet("idle_up",    IDLE_UP, Vector2.new(4, 1))
character:SetSpriteSheet("idle_left",  IDLE_LEFT, Vector2.new(4, 1))
character:SetSpriteSheet("idle_right", IDLE_RIGHT, Vector2.new(4, 1))
character:SetSpriteSheet("down",  WALK_DOWN, Vector2.new(4, 1))
character:SetSpriteSheet("up",    WALK_UP, Vector2.new(4, 1))
character:SetSpriteSheet("left",  WALK_LEFT, Vector2.new(4, 1))
character:SetSpriteSheet("right", WALK_RIGHT, Vector2.new(4, 1))
character:SetSpriteSheet("attack", "rbxassetid://104005922638812", Vector2.new(4, 1)) -- TODO: 탑다운용 attack 애니메이션은 추후 제작

character:Play("idle_down")

-- DefaultControllersEnabled=true + SideView=false → 엔진이 8방향 정규화 이동/애니메이션 전환을
-- 자체 처리한다 (Physics.luau: sideView=false면 Y축에도 마찰 적용, 점프 로직 자체가 비활성화됨).
crossPlatformService.SideView = false
crossPlatformService.DefaultControllersEnabled = true
crossPlatformService:SetPlayerCharacter(character)
clientScene.Camera:SetSubject(character)
clientScene.Camera.FollowSubject = true

clientScene:Enable()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpsideGameGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = playerGui
clientScene.Instance.Parent = screenGui

-- 서버로부터 복제되는 오브젝트(장애물, 광원 등) 수신 리스너
networkingService:On("Build", function(object)
	print("Client: Received server object replication for class:", object.ClassName, "Name:", object.Name)
	if object:IsA("Scene") then
		return
	end
	object:SetScene(clientScene)
end)

-- TODO(multiplayer): NetworkingService:ReplicateOnChange(character)는 Instance.Changed마다
-- (이동 중이면 사실상 매 프레임) 무거운 diff+전송 로직을 동기 실행해서 "가다 멈추다" 프레임
-- 끊김의 원인이었다 (ReplicationPerSecond=15 설정이 존재하지만 ReplicateOnChange 내부에서
-- 실제로 쓰이지 않는 엔진 자체의 스로틀링 누락). 지금은 싱글플레이 테스트 단계라 꺼둔다.
-- 나중에 멀티플레이가 실제로 필요해지면 직접 스로틀링한 Replicate() 호출로 재도입한다.
-- networkingService:ReplicateOnChange(character)

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

crossPlatformService:SetDeviceKey("Keyboard", "F", "Attack")

local isPlayingOneShot = false

local function playOneShot(name)
	if isPlayingOneShot then return end
	isPlayingOneShot = true
	character:Play(name)
	task.delay(0.4, function()
		isPlayingOneShot = false
	end)
end

crossPlatformService:On("InputBegin", function(input)
	if input.Action == "Attack" then
		playOneShot("attack")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		playOneShot("attack")
	end
end)

RunService.Heartbeat:Connect(function()
	if not character or not character.Instance then return end

	local posX = character.Instance.Position.X.Offset
	local posY = character.Instance.Position.Y.Offset

	-- 맵 밖으로 나가거나 R키를 누르면 스폰 지점으로 리셋 (탑다운은 낙사 개념이 없음)
	if math.abs(posX) > 3000 or math.abs(posY) > 3000 or UserInputService:IsKeyDown(Enum.KeyCode.R) then
		character.Instance.Position = SPAWN_POSITION
		character.Velocity = Vector2.zero
	end
end)

print("Upside Engine Client Initialization Complete.")
