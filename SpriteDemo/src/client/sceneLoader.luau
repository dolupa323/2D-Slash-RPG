-- 공식 SpaceFighter 예제(notreux/SpaceFighter)의 src/client/sceneLoader.luau를 최대한 그대로
-- 재활용. 씬이 바뀔 때마다 해당 씬 폴더(modules/<sceneName>) 밑의 모듈들을 load/unload한다.
local Players = game:GetService("Players")
local replicatedStorage = game:WaitForChild("ReplicatedStorage")
local packages = replicatedStorage:WaitForChild("packages")
local modules = script.Parent:WaitForChild("modules")

local setup = require(replicatedStorage.shared.util.setup)
local scenes = require(replicatedStorage.shared.config.scenes)
local monsters = require(replicatedStorage.shared.data.monsters)
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

-- StarterGui에는 플러그인으로 맵을 편집할 때 쓰는 원본 ScreenGui(예: "village")가 그대로 들어있다.
-- 그건 ResetOnSpawn이 켜져 있어서, 캐릭터가 스폰될 때마다(=respawn마다) Roblox가 자동으로
-- PlayerGui에 그 원본을 통째로 복제해 넣는다. 이 복제본은 우리 런타임 씬(SceneContainer)과
-- 똑같은 배경을 정적으로 보여주지만 카메라를 따라 움직이지 않고 히어로도 없어서, 단순히
-- DisplayOrder만 낮추는 걸로는 캐릭터가 맵 경계 부근으로 이동했을 때 이 정적 복제본과
-- 어긋나 보이거나 겹쳐 보이는 문제가 남는다. StarterGui.village(플러그인 원본)은 절대 건드리지
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

-- (실측 버그 이력) 게임 시작/씬 전환 때 필요한 것들(히어로 생성, 저장된 레벨 적용 등)이
-- 준비되기도 전에 화면이 바로 보이고 게임이 진행돼서 "될 때도 안 될 때도 있는" 타이밍
-- 문제가 계속 났다 — 블랙아웃으로 가려둔 채 준비가 다 된 걸 확인한 뒤에 걷어낸다.
local loadingScreen = require(modules.loadingScreen)
local heroController = require(modules.heroController)
local playerStats = require(modules.globals.playerStats)
local monsterHealthBar = require(modules.globals.monsterHealthBar)
local ContentProvider = game:GetService("ContentProvider")
local crossPlatformService = upsideEngine.GetService("CrossPlatformService")

local MIN_LOADING_TIME = 0.6 -- 준비가 빨리 끝나도 최소한 이만큼은 가려둔다(물리/복제 안정화).
local MAX_LOADING_TIME = 8 -- 뭔가 영영 준비 안 돼도 게임이 검은 화면에 갇히지 않게.
local loadToken = 0

local MONSTER_WAIT_TIME = 4 -- 몬스터가 리스폰 중이라 일부가 아직 없을 수 있어서, 몬스터만 따로 이만큼까지만 기다린다.
local MARKER_PREFIX = monsters.MARKER_PREFIX -- 서버가 스폰 마커로 쓰는 이름 접두사(shared/data/monsters.luau).

-- 이 씬에서 화면에 나와야 할 몬스터 수(마커 개수) — 죽어서 리스폰 대기 중인 자리는 더 적게
-- 보일 수 있으므로 아래에서 별도 타임아웃을 둔다.
local function countExpectedMonsters(scene)
	local count = 0
	for _, object in scene.Objects do
		local name = object.Name
		if name and name:sub(1, #MARKER_PREFIX) == MARKER_PREFIX then
			count += 1
		end
	end
	return count
end

-- 화면에 처음 보이는 순간 다운로드가 시작되면 그 사이 빈 화면/깜빡임이 생긴다(heroController.luau
-- 상단 주석의 "실측 이력" 참고) — 이 씬의 모든 이미지(맵/배경)와 몬스터 시트를 로딩 화면
-- 뒤에서 미리 받아둔다. hero 시트는 heroController가 자체적으로 미리 받는다(animationReady).
local function preloadSceneAssets(scene)
	local assets = {}
	for _, descendant in scene.Instance:GetDescendants() do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			table.insert(assets, descendant)
		end
	end
	for _, id in monsterHealthBar.GetSheetImages() do
		table.insert(assets, id)
	end
	ContentProvider:PreloadAsync(assets)
end

local function finishLoading(token, scene)
	local startedAt = os.clock()
	local expectedMonsters = countExpectedMonsters(scene)
	local assetsLoaded = false
	task.spawn(function()
		preloadSceneAssets(scene)
		assetsLoaded = true
	end)

	while token == loadToken do
		local elapsed = os.clock() - startedAt

		local character = crossPlatformService.Character
		local heroReady = heroController.hero ~= nil
			and character == heroController.hero
			and heroController.animationReady == true
			and playerStats.isReady()
		local monstersReady = monsterHealthBar.GetTrackedCount() >= expectedMonsters or elapsed >= MONSTER_WAIT_TIME

		if elapsed >= MAX_LOADING_TIME then
			break
		end
		if elapsed >= MIN_LOADING_TIME and assetsLoaded and heroReady and monstersReady then
			break
		end
		task.wait()
	end
	if token == loadToken then
		loadingScreen.Hide()
	end
end

-- Listen for scene changes and reload modules accordingly.
sceneManager:On("SceneLoaded", function(scene)
	loadToken += 1
	local token = loadToken
	loadingScreen.Show()

	if activeScene then
		unloadModules(activeScene)
		activeScene:Disable()
		activeScene.Instance.Parent = nil
	end

	activeScene = scene
	scene.Instance.Parent = sceneContainer
	loadModules(scene)

	task.spawn(finishLoading, token, scene)
end)

-- Load scenes from the plugin if they were created using it.
loadingScreen.Show()
pluginSupportService:LoadPluginContent()
local myPluginScene = sceneManager:FindByName(scenes.TOWN)
myPluginScene:Enable()

return {}
