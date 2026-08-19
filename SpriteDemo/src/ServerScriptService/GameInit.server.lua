-- Server-side initialization script for the Upside Engine based 2D Game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.packages

-- Load Upside Engine
local UpsideEngine = require(packages.UpsideEngine)
local networkingService = UpsideEngine.GetService("NetworkingService")

print("Initializing Upside Engine Server...")

-- Runtime/Networking.luau의 requestManager가 Heartbeat마다 무조건 돌면서(기본 15회/초)
-- ServerReplication=true(기본값)이면 서버의 모든 씬/오브젝트를 전부 순회하며 무거운
-- diff+전송 로직(NetworkingService.replicate())을 실행한다. 지금은 싱글플레이 테스트라
-- 실시간 서버 복제가 필요 없으므로 끈다 (클라이언트 쪽 이동 끊김의 원인 중 하나로 의심됨).
networkingService.ServerReplication = false

-- 1. Setup automatic replication approval for clients (characters, movement, etc.)
networkingService:On("ReplicationRequest", function(request)
	-- Automatically approve all incoming client replication requests
	request:Approve()
end)

-- 2. Create the server-authoritative 2D Scene
local serverScene = UpsideEngine.new("Scene")
serverScene:SetName("ServerWorld")
serverScene:Enable()

-- 지형(바닥/발판/벽)은 이제 스크립트로 하드코딩하지 않는다 — Tilemap Editor 플러그인 +
-- place_tiles로 클라이언트의 "ForestGround" 씬 안에 직접 배치한다.

-- 5. Add a static hazard/decorative block (StaticObject)
local redBox = UpsideEngine.new("StaticObject")
redBox:SetScene(serverScene)
redBox.Instance.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
redBox.Instance.BackgroundTransparency = 0
redBox.Instance.ZIndex = 5 -- 배경보다 앞에 그려지도록 설정
redBox.Instance.Size = UDim2.fromOffset(60, 60)
redBox.Instance.Position = UDim2.fromOffset(400, 0) -- 탑다운 스폰(0,0) 근처
redBox.Name = "RedHazardBox"

-- 6. Setup 2D lighting (Upside Engine Light class)
local pointLight = UpsideEngine.new("Light")
pointLight:SetScene(serverScene)
pointLight.Shape = "PointLight"
pointLight.Color = Color3.fromRGB(255, 220, 130)
pointLight.Range = 250
pointLight.Brightness = 1.2
pointLight.Instance.Position = UDim2.fromOffset(0, 0) -- 탑다운 스폰 지점
pointLight.Name = "AmbientLight"

print("Upside Engine Server Scene & Objects Created Successfully.")
