-- 공식 SpaceFighter 예제(notreux/SpaceFighter)의 src/client/sceneLoader.luau를 최대한 그대로
-- 재활용. 씬이 바뀔 때마다 해당 씬 폴더(modules/<sceneName>) 밑의 모듈들을 load/unload한다.
local Players = game:GetService("Players")
local replicatedStorage = game:WaitForChild("ReplicatedStorage")
local packages = replicatedStorage:WaitForChild("packages")
local modules = script.Parent:WaitForChild("modules")

local setup = require(replicatedStorage.shared.util.setup)
local upsideEngine = require(packages:WaitForChild("UpsideEngine"))
local pluginSupportService = upsideEngine.GetService("PluginSupportService")
local sceneManager = upsideEngine.GetService("SceneManager")

-- Load global modules that are used across multiple scenes.
local globalModules = setup.getModulesByPath(modules:WaitForChild("globals"))
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local activeScene = nil
local sceneContainer = Instance.new("ScreenGui")
sceneContainer.Name = "SceneContainer"
sceneContainer.Parent = playerGui
sceneContainer.IgnoreGuiInset = true

-- StarterGui에는 플러그인으로 맵을 편집할 때 쓰는 원본 ScreenGui(예: "Town")가 그대로 들어있다.
-- 그건 ResetOnSpawn이 켜져 있어서, 캐릭터가 스폰될 때마다(=respawn마다) Roblox가 자동으로
-- PlayerGui에 그 원본을 통째로 복제해 넣는다. 이 복제본은 우리 런타임 씬(SceneContainer)과
-- 똑같은 배경을 정적으로 보여주지만 카메라를 따라 움직이지 않고 히어로도 없어서, 단순히
-- DisplayOrder만 낮추는 걸로는 캐릭터가 맵 경계 부근으로 이동했을 때 이 정적 복제본과
-- 어긋나 보이거나 겹쳐 보이는 문제가 남는다. StarterGui.Town(플러그인 원본)은 절대 건드리지
-- 않고, PlayerGui에 자동으로 들어오는 복제본 인스턴스만(GameFrame을 담고 있는 ScreenGui로
-- 식별) 즉시 제거한다. 씬 이름에 의존하지 않아 respawn 타이밍과도 무관하게 항상 걸러진다.
local function destroyStrayClone(child)
	if child == sceneContainer or not child:IsA("ScreenGui") then
		return
	end
	if child:FindFirstChild("GameFrame", true) then
		child:Destroy()
	end
end

for _, child in playerGui:GetChildren() do
	destroyStrayClone(child)
end
playerGui.ChildAdded:Connect(destroyStrayClone)

-- Unload modules from the current scene.
local function unloadModules(scene)
	local path = modules:WaitForChild(scene.Name)
	local sceneModules = setup.getModulesByPath(path)

	setup.run(globalModules, "unload")
	setup.run(sceneModules, "unload")
end

-- Load and start modules for the new scene.
local function loadModules(scene)
	local path = modules:WaitForChild(scene.Name)
	local sceneModules = setup.getModulesByPath(path)

	setup.run(globalModules, "load", scene)
	setup.run(sceneModules, "load", scene)

	setup.run(globalModules, "start", scene)
	setup.run(sceneModules, "start", scene)
end

-- Listen for scene changes and reload modules accordingly.
sceneManager:On("SceneLoaded", function(scene)
	if activeScene then
		unloadModules(activeScene)
		activeScene:Disable()
		activeScene.Instance.Parent = nil
	end

	activeScene = scene
	scene.Instance.Parent = sceneContainer
	loadModules(scene)
end)

-- Load scenes from the plugin if they were created using it.
pluginSupportService:LoadPluginContent()
local myPluginScene = sceneManager:FindByName("Town")
myPluginScene:Enable()

return {}
