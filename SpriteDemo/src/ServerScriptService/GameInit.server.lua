-- Server-side initialization script for the Upside Engine based 2D Game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.packages

-- Load Upside Engine
local UpsideEngine = require(packages.UpsideEngine)
local networkingService = UpsideEngine.GetService("NetworkingService")

print("Initializing Upside Engine Server...")

-- 1. Setup automatic replication approval for clients (characters, movement, etc.)
networkingService:On("ReplicationRequest", function(request)
	-- Automatically approve all incoming client replication requests
	request:Approve()
end)

-- 2. Create the server-authoritative 2D Scene
local serverScene = UpsideEngine.new("Scene")
serverScene:SetName("ServerWorld")
serverScene:Enable()

-- 숲 마을 텍스처 애셋 (sprite-gen으로 hero2 픽셀아트 스타일에 맞춰 신규 제작)
local FOREST_GROUND_TEXTURE = "rbxassetid://81674042410848" -- 잔디/흙 바닥 타일 (Tile 반복)
local FOREST_PLANK_TEXTURE = "rbxassetid://94974255066165"  -- 원웨이 나무 발판
local FOREST_WALL_TEXTURE = "rbxassetid://94678474907044"   -- 경계 벽 (Tile 반복)

-- 3. Create the physical floor (Anchored PhysicalObject)
local floor = UpsideEngine.new("PhysicalObject")
floor.Anchored = true
floor:SetScene(serverScene)
floor.Instance.BackgroundTransparency = 1
floor.Instance.Image = FOREST_GROUND_TEXTURE
floor.Instance.ScaleType = Enum.ScaleType.Tile
floor.Instance.TileSize = UDim2.fromOffset(128, 128)
floor.Instance.ZIndex = 5 -- 배경(ZIndex 1~2)보다 앞에 그려지도록 설정
floor.Instance.Size = UDim2.fromOffset(2500, 120)
floor.Instance.Position = UDim2.fromOffset(0, 750)
floor.Name = "Floor"

-- 4. Create floating platforms (원웨이 나무 발판 텍스처)
local platform1 = UpsideEngine.new("PhysicalObject")
platform1.Anchored = true
platform1:SetScene(serverScene)
platform1.Instance.BackgroundTransparency = 1
platform1.Instance.Image = FOREST_PLANK_TEXTURE
platform1.Instance.ScaleType = Enum.ScaleType.Stretch
platform1.Instance.ZIndex = 5 -- 배경보다 앞에 그려지도록 설정
platform1.Instance.Size = UDim2.fromOffset(300, 40)
platform1.Instance.Position = UDim2.fromOffset(400, 580)
platform1.Name = "PlatformLeft"

local platform2 = UpsideEngine.new("PhysicalObject")
platform2.Anchored = true
platform2:SetScene(serverScene)
platform2.Instance.BackgroundTransparency = 1
platform2.Instance.Image = FOREST_PLANK_TEXTURE
platform2.Instance.ScaleType = Enum.ScaleType.Stretch
platform2.Instance.ZIndex = 5 -- 배경보다 앞에 그려지도록 설정
platform2.Instance.Size = UDim2.fromOffset(300, 40)
platform2.Instance.Position = UDim2.fromOffset(900, 450)
platform2.Name = "PlatformRight"

local platform3 = UpsideEngine.new("PhysicalObject")
platform3.Anchored = true
platform3:SetScene(serverScene)
platform3.Instance.BackgroundTransparency = 1
platform3.Instance.Image = FOREST_PLANK_TEXTURE
platform3.Instance.ScaleType = Enum.ScaleType.Stretch
platform3.Instance.ZIndex = 5 -- 배경보다 앞에 그려지도록 설정
platform3.Instance.Size = UDim2.fromOffset(200, 40)
platform3.Instance.Position = UDim2.fromOffset(1400, 320)
platform3.Name = "PlatformHigh"

-- 4b. 월드 경계 벽 (좌/우 탈출 방지, 원목 울타리 텍스처)
local leftWall = UpsideEngine.new("PhysicalObject")
leftWall.Anchored = true
leftWall:SetScene(serverScene)
leftWall.Instance.BackgroundTransparency = 1
leftWall.Instance.Image = FOREST_WALL_TEXTURE
leftWall.Instance.ScaleType = Enum.ScaleType.Tile
leftWall.Instance.TileSize = UDim2.fromOffset(96, 192)
leftWall.Instance.ZIndex = 5
leftWall.Instance.Size = UDim2.fromOffset(40, 900)
leftWall.Instance.Position = UDim2.fromOffset(-40, 350)
leftWall.Name = "BoundaryWallLeft"

local rightWall = UpsideEngine.new("PhysicalObject")
rightWall.Anchored = true
rightWall:SetScene(serverScene)
rightWall.Instance.BackgroundTransparency = 1
rightWall.Instance.Image = FOREST_WALL_TEXTURE
rightWall.Instance.ScaleType = Enum.ScaleType.Tile
rightWall.Instance.TileSize = UDim2.fromOffset(96, 192)
rightWall.Instance.ZIndex = 5
rightWall.Instance.Size = UDim2.fromOffset(40, 900)
rightWall.Instance.Position = UDim2.fromOffset(2540, 350)
rightWall.Name = "BoundaryWallRight"

-- 5. Add a static hazard/decorative block (StaticObject)
local redBox = UpsideEngine.new("StaticObject")
redBox:SetScene(serverScene)
redBox.Instance.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
redBox.Instance.BackgroundTransparency = 0
redBox.Instance.ZIndex = 5 -- 배경보다 앞에 그려지도록 설정
redBox.Instance.Size = UDim2.fromOffset(60, 60)
redBox.Instance.Position = UDim2.fromOffset(1000, 390)
redBox.Name = "RedHazardBox"

-- 6. Setup 2D lighting (Upside Engine Light class)
local pointLight = UpsideEngine.new("Light")
pointLight:SetScene(serverScene)
pointLight.Shape = "PointLight"
pointLight.Color = Color3.fromRGB(255, 220, 130)
pointLight.Range = 250
pointLight.Brightness = 1.2
pointLight.Instance.Position = UDim2.fromOffset(1000, 300)
pointLight.Name = "AmbientLight"

print("Upside Engine Server Scene & Objects Created Successfully.")
