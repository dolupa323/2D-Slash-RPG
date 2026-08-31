-- SpaceFighter 예제의 src/server/main.server.luau 부트스트랩 패턴을 재활용.
local replicatedStorage = game:WaitForChild("ReplicatedStorage")
local setup = require(replicatedStorage.shared.util.setup)
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
