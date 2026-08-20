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
