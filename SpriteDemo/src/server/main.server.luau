-- SpaceFighter 예제의 src/server/main.server.luau 부트스트랩 패턴을 재활용.
local replicatedStorage = game:WaitForChild("ReplicatedStorage")
local setup = require(replicatedStorage.shared.util.setup)

-- 로블록스 기본 3D 캐릭터/TouchGui에 기대지 않는다(CrossPlatformService:Fire로 커스텀
-- 모바일 버튼(client/modules/globals/mobileControls.luau)이 직접 입력을 넣어준다).
-- 이 2D 게임엔 3D 캐릭터가 필요 없으므로 계속 꺼둔다.
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false

local modulesFolder = script.Parent:FindFirstChild("modules")
local modules = modulesFolder and setup.getModulesByPath(modulesFolder) or {}

-- UpsideEngine 설치 가이드의 "An important step" — NetworkingService 등 서비스가 서버가
-- 엔진을 최초에 require해야 정상 동작하므로, 서버 쪽에서 쓰는 게 없어도 최초 1회 require한다.
local packages = replicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
print("Upside Engine version: " .. UpsideEngine.Version)

-- Unload all modules when required.
local function unloadModules()
	setup.run(modules, "unload")
end

-- Load and start all server-side modules.
local function loadModules()
	setup.run(modules, "load")
	setup.run(modules, "start")
end

loadModules()

-- Ensure that modules are unloaded properly when the game is closing.
game:BindToClose(function()
	unloadModules()
end)
