-- Client-side initialization script for the Upside Engine based 2D Game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.packages

-- Load Upside Engine
local UpsideEngine = require(packages.UpsideEngine)
local crossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local networkingService = UpsideEngine.GetService("NetworkingService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

print("Initializing Upside Engine Client...")

-- 1. Setup screen GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpsideGameGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 2. Create the Client 2D Scene
local clientScene = UpsideEngine.new("Scene")
clientScene.Instance.Parent = screenGui
clientScene:SetName("ClientWorld")
clientScene:Enable()

-- 3. 서버로부터 복제되는 오브젝트(바닥, 플랫폼, 장애물, 광원 등) 수신 리스너를 최상단에 배치
-- (소켓 동기화 시점에 발생하는 초기 복제 이벤트를 놓치지 않도록 방지)
networkingService:On("Build", function(object)
	print("Client: Received server object replication for class:", object.ClassName, "Name:", object.Name)
	if object:IsA("Scene") then
		return -- Scene 자체는 로컬 씬에 포함하지 않음
	end
	-- 복제된 오브젝트를 로컬 씬에 부착하여 물리 및 렌더링에 반영
	object:SetScene(clientScene)
end)

-- 4. Setup Parallax Background layers
-- Sky layer
local skyParallax = UpsideEngine.new("Parallax")
skyParallax:SetScene(clientScene)
skyParallax:SetTexture("rbxassetid://117452104173020")
skyParallax.LockToCamera = true
skyParallax.CanvasSize = Vector2.new(1.2, 1.2)
skyParallax.Instance.Size = UDim2.fromScale(1, 1)
skyParallax.Instance.ZIndex = 1

-- Midground layer (distant forest tree tops)
local midgroundParallax = UpsideEngine.new("Parallax")
midgroundParallax:SetScene(clientScene)
midgroundParallax:SetTexture("rbxassetid://85970701016589")
midgroundParallax.LockToCamera = true
midgroundParallax.CanvasSize = Vector2.new(1.8, 1.8)
midgroundParallax.Instance.Size = UDim2.fromScale(1, 1)
midgroundParallax.Instance.ZIndex = 2

-- 숲 마을 텍스처 애셋 (sprite-gen으로 hero2 픽셀아트 스타일에 맞춰 신규 제작)
local FOREST_GROUND_TEXTURE = "rbxassetid://81674042410848" -- 잔디/흙 바닥 타일 (Tile 반복)
local FOREST_PLANK_TEXTURE = "rbxassetid://94974255066165"  -- 원웨이 나무 발판

-- Create solid local Ground & Platforms (5000px wide floor)
local mainFloor = UpsideEngine.new("PhysicalObject")
mainFloor.Anchored = true
mainFloor:SetScene(clientScene)
mainFloor.Instance.BackgroundTransparency = 1
mainFloor.Instance.Image = FOREST_GROUND_TEXTURE
mainFloor.Instance.ScaleType = Enum.ScaleType.Tile
mainFloor.Instance.TileSize = UDim2.fromOffset(128, 128)
mainFloor.Instance.ZIndex = 5
mainFloor.Instance.Size = UDim2.fromOffset(5000, 200)
mainFloor.Instance.Position = UDim2.fromOffset(-1000, 700)
mainFloor.Name = "MainFloor"

local mainPlatform = UpsideEngine.new("PhysicalObject")
mainPlatform.Anchored = true
mainPlatform:SetScene(clientScene)
mainPlatform.Instance.BackgroundTransparency = 1
mainPlatform.Instance.Image = FOREST_PLANK_TEXTURE
mainPlatform.Instance.ScaleType = Enum.ScaleType.Stretch
mainPlatform.Instance.ZIndex = 5
mainPlatform.Instance.Size = UDim2.fromOffset(800, 40)
mainPlatform.Instance.Position = UDim2.fromOffset(100, 520)
mainPlatform.Name = "MainPlatform"

-- 4. Create the local player's 2D Character
local character = UpsideEngine.new("Character")
character:SetScene(clientScene)
character:Load("rbxassetid://87915890865614") -- Idle 4x1 투명 스트립 사전 로드
character.SecondsPerFrame = 0.125               -- 2D 프레임 애니메이션 속도 (8 FPS)
character.Instance.Position = UDim2.fromOffset(400, 400)
character.Instance.Size = UDim2.fromOffset(200, 200)
character.Instance.ImageRectSize = Vector2.new(256, 256)
character.Instance.BackgroundTransparency = 1  -- 캐릭터 뒤의 회색 상자를 투명하게 처리
character.Instance.BorderSizePixel = 0          -- 테두리 제거
character.Instance.ZIndex = 10                 -- 배경(ZIndex 1~2)보다 앞에 그려지도록 설정
character.Mass = 50
character.WalkSpeed = 90
character.JumpPower = 130

-- Configure animations matching transparent 4x1 motion strips (Vector2.new(4, 1))
-- Idle 4x1 transparent strips (direction-specific, generated via the sprite-gen pipeline)
character:SetSpriteSheet("idle_right", "rbxassetid://87915890865614", Vector2.new(4, 1))
character:SetSpriteSheet("idle_left",  "rbxassetid://101212687717690", Vector2.new(4, 1))

-- Attack 4x1 transparent strips (direction-specific)
character:SetSpriteSheet("attack",      "rbxassetid://104005922638812", Vector2.new(4, 1))
character:SetSpriteSheet("attack_left", "rbxassetid://111284342400551", Vector2.new(4, 1))

-- Jump 4x1 transparent strips (direction-specific)
character:SetSpriteSheet("jump",      "rbxassetid://124534863903204", Vector2.new(4, 1))
character:SetSpriteSheet("jump_left", "rbxassetid://138428010395893", Vector2.new(4, 1))

-- Walk 4x1 transparent strips, generated via the sprite-gen pipeline (anchor-locked to the idle reference, rescaled to match idle's body scale)
character:SetSpriteSheet("right",      "rbxassetid://109335894403589", Vector2.new(4, 1))
character:SetSpriteSheet("left",       "rbxassetid://85148768814567", Vector2.new(4, 1))

character:Play("idle_right")

-- 5. Link controls and camera follow via CrossPlatformService
crossPlatformService.SideView = true
crossPlatformService.DefaultControllersEnabled = false -- 디폴트 컨트롤러 비활성화 후 직접 폴링
crossPlatformService:SetPlayerCharacter(character)

-- 카메라 직접 제어를 위해 자동 추적 비활성화 (지터링 방지)
clientScene.Camera.FollowSubject = false
clientScene.Camera.Smoothness = 0.15

-- 6. Setup replication to other clients
networkingService:ReplicateOnChange(character)

-- 7. 폴링(Polling) 기반 초강력 키보드 입력 처리 및 애니메이션 스테이트 머신 제어
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local isFacingRight = true
local lastAnim = ""
local isPlayingOneShot = false -- 원샷(공격, 점프, 하단점프) 애니메이션 재생 중 여부

local function playAnim(name, isOneShot)
	if isPlayingOneShot and not isOneShot then return end
	if lastAnim == name then return end
	lastAnim = name
	character:Play(name)
	if isOneShot then
		isPlayingOneShot = true
		task.delay(0.4, function()
			isPlayingOneShot = false
			lastAnim = ""
		end)
	end
end

RunService.Heartbeat:Connect(function(dt)
	if not character or not character.Instance then return end

	local posX = character.Instance.Position.X.Offset
	local posY = character.Instance.Position.Y.Offset

	-- 1) 공격 키 처리 (F 키 또는 마우스 좌클릭)
	local attackPressed = UserInputService:IsKeyDown(Enum.KeyCode.F) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	if attackPressed then
		playAnim(isFacingRight and "attack" or "attack_left", true)
	end

	-- 2) 좌우 이동 키 상태 확인 및 속도 반영
	local moveX = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		moveX = 1
		isFacingRight = true
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		moveX = -1
		isFacingRight = false
	end

	if moveX ~= 0 then
		character.Velocity = Vector2.new(moveX * character.WalkSpeed * 5, character.Velocity.Y)
		if isFacingRight then
			playAnim("right")
		else
			playAnim("left")
		end
	else
		character.Velocity = Vector2.new(0, character.Velocity.Y)
		if isFacingRight then
			playAnim("idle_right")
		else
			playAnim("idle_left")
		end
	end

	-- 3) 점프 및 하단 플랫폼 통과 처리 (W, Space, Up / S + Space)
	local jumpPressed = UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
	local downPressed = UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)

	if jumpPressed then
		if downPressed and character.IsGrounded then
			-- 하단점프 (S + Space): 현재 딛고 있는 플랫폼의 충돌을 일시 해제하여 아래로 통과
			for id, _ in character.Collisions do
				local obj = clientScene.Objects:Get(id)
				if obj and obj.Name:match("Platform") then
					print("Dropping down from platform:", obj.Name)
					character.CollisionBlacklist[id] = true
					character.IsGrounded = false
					playAnim("down_jump", true)
					task.delay(0.3, function()
						character.CollisionBlacklist[id] = nil
					end)
					break
				end
			end
		elseif character.IsGrounded then
			print("Triggering jump!")
			character:Jump(character.JumpPower)
			playAnim(isFacingRight and "jump" or "jump_left", true)
		end
	end

	-- 4) 낙하 및 맵 탈출 방지 (자동 리셋 및 R키 수동 리셋)
	if posY > 850 or posX < -100 or posX > 2600 or UserInputService:IsKeyDown(Enum.KeyCode.R) then
		print(string.format("Resetting character from (%.1f, %.1f) to (400, 400)", posX, posY))
		character.Instance.Position = UDim2.fromOffset(400, 400)
		character.Velocity = Vector2.zero
	end

	-- 5) 수동 카메라 제어 (물리 엔진 미세 진동으로 인한 화면 지터링 방지)
	local resolution = workspace.CurrentCamera.ViewportSize
	local center = resolution / 2
	
	-- X좌표는 캐릭터를 스무스하게 추적
	local targetCamX = center.X + (center.X - posX)
	-- Y좌표는 캐릭터가 높은 위치로 이동하거나 낙하할 때만 부드럽게 따라가며, 미세 틱 진동은 스무딩(Lerp)하여 화면 튕김을 완전 방지
	local currentCamPos = clientScene.Camera.Instance.Position
	local currentCamY = currentCamPos.Y.Offset
	local targetCamY = center.Y + (center.Y - posY)
	
	-- 미세 튕김 방지를 위해 매 프레임 Lerp 적용
	local alpha = 0.15 -- 부드러운 트래킹 강도 (지터링 필터링)
	local newCamY = currentCamY + (targetCamY - currentCamY) * alpha
	local newCamX = currentCamPos.X.Offset + (targetCamX - currentCamPos.X.Offset) * alpha
	
	clientScene.Camera:SetPosition(UDim2.fromOffset(newCamX, newCamY))

	-- 6) 배경 패럴랙스 스크롤 업데이트 (움직임 시 착시 방지 및 입체감 제공)
	skyParallax.Offset = Vector2.new(posX * 0.15, 0)
	midgroundParallax.Offset = Vector2.new(posX * 0.45, 0)
end)

print("Upside Engine Client Initialization Complete.")
