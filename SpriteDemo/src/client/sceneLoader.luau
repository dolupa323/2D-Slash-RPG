-- 씬 로더(공식 SpaceFighter 예제의 src/client/sceneLoader.luau 틀). 씬이 바뀔 때마다 씬 모듈들을 load/unload한다.
--  「오문 닌자전」의 씬은 전부 탑다운 씬("town_<키>" — shared/data/townWorld.generated.luau)이고 코드로 만든다.
--  씬 모듈은 modules/town 하나를 모든 씬이 같이 쓰고, modules/globals는 씬과 상관없이 늘 도는 것(HUD · 가방 · 인술 등).
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local replicatedStorage = game:WaitForChild("ReplicatedStorage")
local packages = replicatedStorage:WaitForChild("packages")
local modules = script.Parent:WaitForChild("modules")

local setup = require(replicatedStorage.shared.util.setup)
local scenes = require(replicatedStorage.shared.config.scenes)
local townAssets = require(replicatedStorage.shared.config.townAssets)
local townIds = require(replicatedStorage.shared.config["townAssets.generated"])
local townWorld = require(replicatedStorage.shared.data.townWorld)
local upsideEngine = require(packages:WaitForChild("UpsideEngine"))
local sceneManager = upsideEngine.GetService("SceneManager")
local crossPlatformService = upsideEngine.GetService("CrossPlatformService")

local globalModules = setup.getModulesByPath(modules:WaitForChild("globals"))
local townFolder = modules:WaitForChild("town")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local activeScene = nil
local sceneContainer = Instance.new("ScreenGui")
sceneContainer.Name = "SceneContainer"
sceneContainer.Parent = playerGui
sceneContainer.IgnoreGuiInset = true

-- 플레이스의 StarterGui에 예전 편집용 씬 화면(GameFrame을 담은 ScreenGui)이 남아 있으면, 캐릭터가 스폰될 때마다 로블록스가
-- PlayerGui로 복제해 넣는다 — 우리 씬 위에 겹쳐 보이지 않게 들어오는 대로 지운다(StarterGui의 원본은 건드리지 않는다).
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

local function unloadModules()
	local sceneModules = setup.getModulesByPath(townFolder)
	setup.run(globalModules, "unload")
	setup.run(sceneModules, "unload")
end

local function loadModules(scene)
	local sceneModules = setup.getModulesByPath(townFolder)
	setup.run(globalModules, "load", scene)
	setup.run(sceneModules, "load", scene)
	setup.run(globalModules, "start", scene)
	setup.run(sceneModules, "start", scene)
end

-- 게임 시작/씬 전환 때 필요한 것들(캐릭터 생성, 저장된 레벨 적용, 그림 내려받기)이 준비되기 전에 화면이 보이면
-- "될 때도 안 될 때도 있는" 타이밍 문제가 난다 — 블랙아웃으로 가려 둔 채 준비가 다 된 걸 확인한 뒤에 걷어낸다.
local loadingScreen = require(modules.loadingScreen)
local hero = require(modules.topDownHero)
local playerStats = require(modules.globals.playerStats)

local MIN_LOADING_TIME = 0.6 -- 준비가 빨리 끝나도 최소한 이만큼은 가려둔다(복제 안정화).
local MAX_LOADING_TIME = 8 -- 뭔가 영영 준비 안 돼도 게임이 검은 화면에 갇히지 않게.
local loadToken = 0

-- 화면에 처음 보이는 순간 내려받기가 시작되면 그 사이 빈 화면/깜빡임이 생긴다 — 이 씬의 그림과 공용 시트
-- (UI 키트 · 글자판 · 캐릭터 · 몬스터 · 아이템 · 이펙트)를 로딩 화면 뒤에서 미리 받아 둔다.
local function preloadSceneAssets(scene)
	local assets = {}
	for _, descendant in scene.Instance:GetDescendants() do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			table.insert(assets, descendant)
		end
	end
	local function add(id)
		if typeof(id) == "string" and id ~= "" then
			local image = Instance.new("ImageLabel")
			image.Image = id
			table.insert(assets, image)
		end
	end
	for _, id in { townAssets.UI, townAssets.PLAYER, townAssets.NPCS, townAssets.OBJECTS, townAssets.FX, townIds.ITEMS } do
		add(id)
	end
	for _, id in townAssets.MONSTER_SHEETS do
		add(id)
	end
	for _, pages in townIds.FONT or {} do
		for _, id in pages do
			add(id)
		end
	end
	ContentProvider:PreloadAsync(assets)
end

local function finishLoading(token, scene)
	local startedAt = os.clock()
	local assetsLoaded = false
	task.spawn(function()
		preloadSceneAssets(scene)
		assetsLoaded = true
	end)

	while token == loadToken do
		local elapsed = os.clock() - startedAt
		local heroReady = hero.hero ~= nil
			and crossPlatformService.Character == hero.hero
			and hero.animationReady == true
			and playerStats.isReady()
		if elapsed >= MAX_LOADING_TIME then
			break
		end
		if elapsed >= MIN_LOADING_TIME and assetsLoaded and heroReady then
			break
		end
		task.wait()
	end
	if token == loadToken then
		loadingScreen.Hide()
	end
end

sceneManager:On("SceneLoaded", function(scene)
	loadToken += 1
	local token = loadToken
	loadingScreen.Show()

	if activeScene then
		unloadModules()
		activeScene:Disable()
		activeScene.Instance.Parent = nil
	end

	activeScene = scene
	scene.Instance.Parent = sceneContainer
	loadModules(scene)

	task.spawn(finishLoading, token, scene)
end)

-- 씬은 전부 코드로 만든다(townWorld.generated — 공방 js/ninja/maps.js). 그림·배치는 씬이 켜질 때 modules/town이 채운다.
-- 위에서 내려다보는 시점이라 중력을 끈다. 시작 씬(scenes.TOWN)을 켜고, 다른 씬은 포탈로 넘어갈 때 켜진다.
loadingScreen.Show()
for key in townWorld.data.scenes do
	local townScene = upsideEngine.new("Scene")
	townScene:SetName(townWorld.SceneName(key))
	townScene.Gravity = Vector2.zero
end
sceneManager:FindByName(scenes.TOWN):Enable()

return {}
